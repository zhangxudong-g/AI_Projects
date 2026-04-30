CREATE OR REPLACE PACKAGE BODY GKBPC00190
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 保護者判定
--  機能概要      : 児童生徒の保護者を自動判定しマスタを更新する
--              また、その結果一覧表を作成する
--              一覧表は、保護者新規登録者一覧、保護者既存登録者一覧
--              保護者既存登録者（要確認）一覧、保護者不明者の４種類
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
--------------------------------------------------------
--  変更履歴
--  2024/03/19 ZCZL.WUCAO Update 0.2.000.001:512_GKB_00003対応
--  2024/04/19 ZCZL.LIKEWEN UPDATE 0.2.000.002:512_GKB_00018対応
--  2024/04/28 ZCZL.WUCAO Update 0.2.000.003:512_GKB_00033対応
--  2024/06/06 ZCZL.GUANHONG Update 0.3.000.000:新WizLIFE２次開発
--  2024/08/29 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--  2024/09/24 ZCZL.WANGMING UPDATE 0.3.000.002:仕様変更　ID：IT_GKB_00065対応
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00429対応横展開
--------------------------------------------------------
IS
    -- 全処理必須パラメータ
    c_BATCH                       CONSTANT PLS_INTEGER := 2;   --バッチ
    c_OK                          CONSTANT PLS_INTEGER := 0;   --正常
    c_ERR                         CONSTANT PLS_INTEGER := -1;  --異常
    g_nJOBNUM                     NUMBER;                      --ジョブナンバー
    g_sTANTOCODE                  CHAR(12);                    --担当者コード
    g_sWSNUM                      NVARCHAR2(63);               --端末番号
    g_nSAKUHYOLOGSEQ              NUMBER := 0;                 --作表ログ連番
    g_nUPDLOGSEQ                  NUMBER := 0;                 --更新ログ連番
    g_sMESSAGE                    NVARCHAR2(4000);             --メッセージ返却用
    g_rJSTP                       KKBTJSTP%ROWTYPE;            --バッチジョブステップ情報
    g_sSHORIID                    KKBTJCTL.SHORIID%TYPE;       --処理ID
    g_sGYOUMUCODE                 NVARCHAR2(3);                --業務コード
    g_oKENSU_LIST                 GKBEKENSU_LIST := GKBEKENSU_LIST();

    g_nTIME NUMBER;  --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;
    nCOUNT        NUMBER := 0;
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
        CURSOR CJIDO(p_GAKUNEN_CD IN NUMBER,
                     p_SYURYOGAKUNEN_CD IN NUMBER) IS
            SELECT KOJIN_NO,
                   GAKUNEN_CD
              FROM GKBTGAKUNENLNK
             WHERE GAKUNEN_CD BETWEEN p_GAKUNEN_CD AND p_SYURYOGAKUNEN_CD;
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
        -- ERROR関連 --
    -- デバック
        N_SQL_CODE      NUMBER;             -- SQLエラーコード
        V_SQL_MSG       NVARCHAR2(255);     -- SQLエラーメッセージ
        c_BERROR        CONSTANT  BOOLEAN :=  FALSE;
        -- 処理結果
        c_ISUCCESS      CONSTANT  PLS_INTEGER := 0;         -- 正常
        c_INOT_SUCCESS  CONSTANT  PLS_INTEGER := -1;        -- 異常
        c_INOTFOUND     CONSTANT  PLS_INTEGER := -9;        -- 該当なし
        -- 保護者ワーク
        c_VTABLE        CONSTANT  NVARCHAR2(128) := 'GKBWHOGOSHAJUDGE';
        -- １頁の最大行数
        c_IMAXROWS      CONSTANT  PLS_INTEGER := 15;

        -- システム条件:「児童との関係」判定条件
        c_ISYS_J_KANKEI  CONSTANT  PLS_INTEGER := 120;

    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
        NSYSTIME            NUMBER;       -- システム時間
        ISAKUSEIBI          PLS_INTEGER;
        RG                  GKBTGAKUREIBO%ROWTYPE;
        RA                  GABTATENAKIHON%ROWTYPE;
        RB                  GABTATENAKIHON%ROWTYPE;
        RC                  GABTSOFUSAKI%ROWTYPE;
        RASO                GABTSOFUSAKI%ROWTYPE;
        VSHIMEI_KANJI       NVARCHAR2(300);
        VJINKAKU_KBN        NUMBER;
        IGAKO_CD            PLS_INTEGER;
        VGAKOMEI            NVARCHAR2(60);      
        VSEINENGAPI         NVARCHAR2(11);
        VSEIBETSU           NVARCHAR2(2);
--  2024/06/06 ZCZL.GUANHONG Update 0.3.000.000:新WizLIFE２次開発
--        VSETAI_NO           NVARCHAR2(7);
        VSETAI_NO           NVARCHAR2(15);
        VGYOSEIKU_MEI       NVARCHAR2(20);
        VHAN_MEI            NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00429対応横展開
--        VSANTEIDANTAI_MEI   NVARCHAR2(20);
        VSANTEIDANTAI_MEI   GKBWHOGOSHAJUDGE.SANTEIDANTAIMEI%TYPE;
        VSASKUSEIBI         NVARCHAR2(30);
        VHOGOSHA_SHIMEI_JODAN     NVARCHAR2(100);
        VHOGOSHA_SHIMEI_GEDAN     NVARCHAR2(100);
        VCNT                NVARCHAR2(6);
        VZOKUGARAMEI1       NVARCHAR2(30);
        VZOKUGARAMEI2       NVARCHAR2(30);
        VGAKUNENMEI         NVARCHAR2(20);
        NGAKUNENSEI         NUMBER;
        VGAKUNENSEI         NVARCHAR2(20);
        IHOGOSHA_KOJIN_NO   NUMBER;
        IHANTEI_KBNI        PLS_INTEGER;
        IHOGOSHA_ZOKUGARA   PLS_INTEGER;
        VHANTEI_KBNI        NVARCHAR2(26);
        -- 関数用戻り値変数（外部関数からの戻り値をセット）
        BRTN                BOOLEAN;
        B_RTN               BOOLEAN;
        I_RTN               PLS_INTEGER;
        -- 処理条件（画面からの引数）
        VGAKUNEN            NVARCHAR2(15);      -- 学年
        VSYURYOGAKUNEN      NVARCHAR2(15);      -- 終了学年
        -- 取得したデータのワーク領域
        TYPE MTHOGOSHA_TYPE IS TABLE OF GKBWHOGOSHAJUDGE%ROWTYPE INDEX BY BINARY_INTEGER;
        MHOGOSHA_WORK MTHOGOSHA_TYPE;
        
        o_NBREAK         NUMBER(2);
        -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
        IWAREKIHIZUKE                  PLS_INTEGER;
        VEDIT_GYYMMDD2                 NVARCHAR2(20);
        VEDIT_GYYMMDD3                 NVARCHAR2(20);
        VKJ_GENGO                      NVARCHAR2(20);
        VKG_GENGO                      NVARCHAR2(20);
        IWAREKI_YY                     PLS_INTEGER;
        ISEIREKI_YYYY                  PLS_INTEGER;
        IWAREKI_GYYMM                  PLS_INTEGER;
        IMM                            PLS_INTEGER;
        IDD                            PLS_INTEGER;
        IOWAREKIHIZUKE                 PLS_INTEGER;
        ISEIREKIHIZUKE                 PLS_INTEGER;
        VSQLERRM         NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
        VPAGENM          NVARCHAR2(500);    -- 改頁項目名
        VPAGEFD          NVARCHAR2(500);    -- 改頁項目値
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
       ISTEP_NO         PLS_INTEGER;            --ステップ番号
       VLOG             NVARCHAR2(256);
       BHAITA_FLAG                        BOOLEAN := FALSE;       --w排他中
--  2024/06/06 ZCZL.GUANHONG Add end 
        I_SYSTEMJOKEN    PLS_INTEGER;        -- システム条件取得用
        NJ_ZOKUGARACD1   NUMBER(2);          -- 児童.続柄1
        ERR              EXCEPTION;
    
    --パラメータ変数
        g_vJYOUKEN01                      NVARCHAR2(1000);
        g_vJYOUKEN02                      NVARCHAR2(1000);
        VMSG NVARCHAR2(4000);
        IRTN PLS_INTEGER ;
        ICHK1 PLS_INTEGER ;
        ICHK2 PLS_INTEGER ;
      ----------------------------------------------------------------------------------------------------
      --開始学年と終了学年の大小チェック
      ----------------------------------------------------------------------------------------------------
      FUNCTION FUNCHIKAKUCHK( i_VGAKUNEN1 IN NVARCHAR2, i_VGAKUNEN2 IN NVARCHAR2 ) RETURN NUMBER IS
      IRET PLS_INTEGER ;
      SGAKUNEN PLS_INTEGER ;
      EGAKUNEN PLS_INTEGER ;
      BEGIN
        IRET := 0 ;
        SGAKUNEN  := TO_NUMBER( i_VGAKUNEN1 );
        EGAKUNEN  := TO_NUMBER( i_VGAKUNEN2 );
        --開始学年と終了学年の大小チェック
        IF SGAKUNEN > EGAKUNEN THEN
            IRET := 1;
        END IF;
        RETURN(IRET) ;
      END ;
      ----------------------------------------------------------------------------------------------------
      --学年チェック
      ----------------------------------------------------------------------------------------------------
      FUNCTION FUNCGAKUNENCHK( i_VGAKUNEN IN NVARCHAR2 ) RETURN NUMBER IS
      IRET PLS_INTEGER ;
      GAKUNEN PLS_INTEGER ;
      BEGIN
        IRET := 0 ;
        --学年
        BEGIN
          IF i_VGAKUNEN IS NULL THEN
            IRET := 1;
          ELSE
            GAKUNEN  := TO_NUMBER(i_VGAKUNEN);
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            IRET := 1;
        END;

        IF IRET = 0 THEN
          IF GAKUNEN > 9 THEN
            IRET := 1;
          END IF;
        END IF;

        RETURN(IRET) ;
      END ;
    --------------------------------------------------------
    --  機能概要      : 処理ログ出力
    --  パラメータ    : i_vSTEP_NANE       処理単位に任意に付したステップ名
    --                : i_nJOHOKBN         ステータス（0:正常,1:異常）
    --                : i_sSQLCODE         異常ログ出力時のSQLCODE
    --                : i_sSQLERRM         異常ログ出力時のSQLERRM
    --                : i_sLOGMSG          エラーログとして出力する文字列
    --                : i_TANTOCODE        担当者コード
    --                : i_WSNUM            端末番号
    --                : i_nSHORIKBN        処理区分（1：作表処理, 2：更新処理, 0：カスタマイズログ内容）
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_SETLOG(i_sSTEP_NAME IN  NVARCHAR2,
                         i_nJOHOKBN   IN  NUMBER,
                         i_sSQLCODE   IN  NVARCHAR2,
                         i_sSQLERRM   IN  NVARCHAR2,
                         i_sLOGMSG    IN  NVARCHAR2,
                         i_TANTOCODE  IN  NVARCHAR2,
                         i_WSNUM      IN  NVARCHAR2,
                         i_nSHORIKBN  IN  NUMBER DEFAULT 0) RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;          --戻り値
        sSTEP_NAME                    NVARCHAR2(100);   --ステップ名
        sLOGMSG                       NVARCHAR2(1000);  --エラーログ
    BEGIN
        IF i_nSHORIKBN = 1 THEN
            sSTEP_NAME := i_sSTEP_NAME || g_nSAKUHYOLOGSEQ;
            sLOGMSG := i_sLOGMSG;
        ELSIF i_nSHORIKBN = 2 THEN
            sSTEP_NAME := i_sSTEP_NAME || g_nUPDLOGSEQ;
            sLOGMSG := i_sLOGMSG;
        ELSIF i_nSHORIKBN = 0 THEN
            sSTEP_NAME := i_sSTEP_NAME;
            sLOGMSG := i_sLOGMSG;
        ELSE
            NULL;
        END IF;

        --ログ出力
        bRTN := KKBPK5551.FSETBLOG (g_nJOBNUM,
                                    sSTEP_NAME,
                                    i_nJOHOKBN,
                                    i_sSQLCODE,
                                    i_sSQLERRM,
                                    sLOGMSG,
                                    i_TANTOCODE,
                                    i_WSNUM);
        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_SETLOG;
    --------------------------------------------------------
    --  機能概要      : バッチ初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B00INIT
        RETURN BOOLEAN
    IS
        bRTN          BOOLEAN;           --戻り値
        rJCTL         KKBTJCTL%ROWTYPE;  --バッチジョブ情報
    BEGIN
        --初期処理
        bRTN := KKBPK5551.INITIAL (g_nJOBNUM);
        --バッチパラメータ取得
        bRTN := KKBPK5551.FJCTLGet (g_nJOBNUM, rJCTL);
        g_sTANTOCODE := rJCTL.LOGIN_TANTOCODE;  --担当者コード
        g_sWSNUM     := rJCTL.LOGIN_WSNUM;      --端末番号
        g_sSHORIID   := rJCTL.SHORIID;          --処理ID
        g_sGYOUMUCODE   := rJCTL.GYOUMUCODE;    --業務コード

        g_nTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));--時分秒

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B00INIT;
    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        cmbGakunenStart          DBMS_UTILITY.MAXNAME_ARRAY;
        cmbGakunenEnd            DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        --開始学年 範囲(開始)
        cmbGakunenStart := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGakunenStart');
        g_vJYOUKEN01 := cmbGakunenStart(1);
        --終了学年 範囲(終了)
        cmbGakunenEnd := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGakunenEnd');
        g_vJYOUKEN02 := cmbGakunenEnd(1);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B01PINIT;
    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得（帳票）
    --  パラメータ    : i_STEPSEQ     バッチジョブステップ連番
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B02PINIT(i_STEPSEQ IN NUMBER)
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;  --戻り値
    BEGIN
        --ステップ情報クリア
        g_rJSTP := NULL;
        --ステップ情報の取得
        bRTN := KKBPK5551.FJSTPGet (g_nJOBNUM, i_STEPSEQ, g_rJSTP);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B02PINIT;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
    BEGIN
        --ジョブナンバーをセット

        g_nJOBNUM := i_nJOBNUM;

        --バッチ初期処理
        bRTN := FUNC_B00INIT;
        IF NOT bRTN THEN
            o_vRESULT := g_sMESSAGE;
            RETURN;
        END IF;

        -- バッチ入力値取得
        bRTN := FUNC_B01PINIT;
        
      VMSG := '' ;
      IRTN := 0 ;
      ICHK1 := 0 ;
      ICHK2 := 0 ;

      --条件１のチェック
      IRTN := FUNCGAKUNENCHK( g_vJYOUKEN01 ) ;
      IF IRTN <> 0 THEN
        ICHK1 := 1 ;
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,開始学年が正しくありません。,;';
      END IF ;

      --条件２のチェック
      IRTN := FUNCGAKUNENCHK( g_vJYOUKEN02 ) ;
      IF IRTN <> 0 THEN
        ICHK2 := 1 ;
        VMSG := VMSG || g_sGYOUMUCODE || ',99999,終了学年が正しくありません。,;';
      END IF ;

      --条件１と条件２の大小チェックを行う。
      IF ICHK1 = 0 AND ICHK2 = 0 THEN
        IRTN := FUNCHIKAKUCHK( g_vJYOUKEN01, g_vJYOUKEN02 ) ;
        IF IRTN <> 0 THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,開始学年と終了学年の大小関係が誤っています。,;';
        END IF ;
      END IF ;

      o_vRESULT := VMSG ;

    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
    --------------------------------------------------------
    --  機能概要      : バッチジョブステップテーブルの更新処理
    --  パラメータ    : i_UPD_KBN       更新区分
    --                : i_STEPRTNCODE   実行結果コード
    --                : i_CSV_RCNT      CSV出力件数
    --                : i_CSVFILENAME   CSVファイル名
    --                : i_PRTFILENAME   出力ファイル名
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    PROCEDURE PROC_JSTPSTAUTSUPD(i_UPD_KBN     IN  NUMBER,
                                 i_STEPRTNCODE IN  NUMBER DEFAULT 0,
                                 i_CSV_RCNT    IN  NUMBER DEFAULT 0,
                                 i_CSVFILENAME IN  NVARCHAR2 DEFAULT '',
                                 i_PRTFILENAME IN  NVARCHAR2 DEFAULT '')
    IS
        bRTN                          BOOLEAN;                  --戻り値
        aCOLNAME_TBL                  KKBPK5551.tyCOLNAME_Tbl;  --テーブル項目名リスト
    BEGIN
        --開始状態
        IF i_UPD_KBN = 1 THEN
            aCOLNAME_TBL := KKBPK5551.tyCOLNAME_Tbl ('STEPSTARTTIME');
            g_rJSTP.STEPSTARTTIME := TO_CHAR (SYSTIMESTAMP, 'YYYY/MM/DD HH24:MI:SS.FF3');
            bRTN := KKBPK5551.FJSTPPut (g_rJSTP, aCOLNAME_TBL);
        --終了状態
        ELSIF i_UPD_KBN = 2 THEN
            aCOLNAME_TBL := KKBPK5551.tyCOLNAME_Tbl ('STEPENDTIME', 'STEPRTNCODE');
            g_rJSTP.STEPENDTIME := TO_CHAR (SYSTIMESTAMP, 'YYYY/MM/DD HH24:MI:SS.FF3');
            g_rJSTP.STEPRTNCODE := i_STEPRTNCODE;
            bRTN := KKBPK5551.FJSTPPut (g_rJSTP, aCOLNAME_TBL);
        --ＣＳＶ出力状態
        ELSIF i_UPD_KBN = 3 THEN
            aCOLNAME_TBL := KKBPK5551.tyCOLNAME_Tbl ('SHORIRECCNT', 'CSVFILENAME', 'PRTFILENAME');
            g_rJSTP.SHORIRECCNT := i_CSV_RCNT;
            g_rJSTP.CSVFILENAME := i_CSVFILENAME;
            g_rJSTP.PRTFILENAME := i_PRTFILENAME;
            bRTN := KKBPK5551.FJSTPPut (g_rJSTP, aCOLNAME_TBL);
        --その他
        ELSE
            NULL;
        END IF;
    END PROC_JSTPSTAUTSUPD;
    --------------------------------------------------------
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B11CSV(i_TBLNAME IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;          --戻り値
        nCSV_RCNT                     NUMBER;           --CSVファイル出力件数
        sCSVFILENAME                  NVARCHAR2(1000);  --CSVファイル名
        sPRTFILENAME                  NVARCHAR2(1000);  --印刷ファイル名
    BEGIN
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        --CSV出力処理
        bRTN := KKBPK5551.FCSVPUT (g_nJOBNUM,
                                   g_sGYOUMUCODE,
                                   g_sWSNUM,
                                   c_BATCH,
                                   i_TBLNAME,
                                   g_rJSTP.CHOHYOID,
                                   g_rJSTP.CHOHYOFORM,
                                   g_rJSTP.PRTFILEKBN,
                                   g_rJSTP.TEIKEIBUNNUM_LIST,
                                   nCSV_RCNT,
                                   sCSVFILENAME,
                                   sPRTFILENAME);

        --バッチジョブステップ情報を更新
        PROC_JSTPSTAUTSUPD (3, 0, nCSV_RCNT, sCSVFILENAME, sPRTFILENAME);

        --関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_B11CSV;
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
        FOR i in 1..g_oKENSU_LIST.COUNT LOOP
            bRTN:= KKBPK5551.FSETCNT(
                                     g_nJOBNUM,                  --ジョブナンバー
                                     i,                          --件数連番
                                     g_oKENSU_LIST(i).NAIYOU,    --件数名称
                                     g_oKENSU_LIST(i).KBN,       --件数区分
                                     g_oKENSU_LIST(i).CNT,       --件数
                                     g_sTANTOCODE,               --担当者コード
                                     g_sWSNUM                    --端末番号
                                     );
            IF NOT bRTN THEN
              RAISE eEXCEPTION;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END PROC_KENSUSET;
  --------------------------------------------------------
    --  6.終了処理
    -------------------------------------------------------------------------------------
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
    PROCEDURE FUNC_HAITAI_CLEAR 
    IS
    IRTN                          NUMBER;
    BEGIN
      --変数.リターンコード := 排他制御クリア関数（GKBFKHTCLR）を使用し、排他の解除を行う。
      IF BHAITA_FLAG THEN
        -- 排他制御クリア関数（GKBFKHTCLR）を使用し、排他の解除を行う。
        IRTN := GKBFKHTCLR(2 ,'999999999999');
        IF IRTN <> 0 THEN 
           VLOG := '排他解除が異常終了しました。';
--  2024/08/29 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--           bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 1); 
           bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_HAITAI_CLEAR', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
        END IF;
      END IF;
    END FUNC_HAITAI_CLEAR;
--  2024/06/06 ZCZL.GUANHONG Add end 
    --------------------------------------------------------------------------------
    -- システム条件取得
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_SYSJOKEN(i_IRENBAN IN PLS_INTEGER) RETURN PLS_INTEGER IS
        I_VALUE    PLS_INTEGER;    -- システム条件設定値
        TACONSPRM  A_CONS_PRM;       --戻るパラメータ配列
        NLENGTH    NUMBER;           --配列件数
    BEGIN

        BEGIN
          IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      i_IRENBAN,          --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
          IF NLENGTH <> 0 THEN
          --レコードが取得できた場合
            I_VALUE := TACONSPRM(1);
          ELSE
          --レコードが取得できない場合
            I_VALUE := 0;
          END IF;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            I_VALUE := 0;
        END;

        RETURN I_VALUE;
    END FUNC_GET_SYSJOKEN;
    --------------------------------------------------------------------------------
    -- 保護者ワーク中間（GKBWHOGOSHAJUDGE）レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        IFRET                PLS_INTEGER;                -- 戻り値
        NGAKUNEN_CD              NUMBER;                -- 学年コード
        NSYURYOGAKUNEN_CD   NUMBER;                     -- 終了学年コード
        IRTN               PLS_INTEGER;
        ICNT                BINARY_INTEGER;             -- 戻り値
        IRTNZOKUGARAHERR1    PLS_INTEGER;
        IRTNZOKUGARAHERR2    PLS_INTEGER;
        NPRTN                NUMBER;
        BRTN                 BOOLEAN;
--  2024/09/24 ZCZL.WANGMING ADD 0.3.000.002:仕様変更　ID：IT_GKB_00065対応
        rGKBTGAKUREIBO       GKBTGAKUREIBO%ROWTYPE;
    BEGIN
        IFRET := c_INOTFOUND;                 -- 該当なし
        NGAKUNEN_CD := TO_NUMBER(VGAKUNEN);          -- 学年
        NSYURYOGAKUNEN_CD := TO_NUMBER(VSYURYOGAKUNEN);          -- 学年
        ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        NSYSTIME   := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS'));   -- システム時間（テーブル更新用）
        -- ワーク領域の初期化
        MHOGOSHA_WORK.DELETE;
        ICNT := 0;
        BEGIN
            -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
            FOR CRJIDO IN CJIDO(NGAKUNEN_CD,NSYURYOGAKUNEN_CD) LOOP
        VCNT :=  TO_CHAR(ICNT);
            GKBSKJDOG(CRJIDO.KOJIN_NO,RG,NPRTN);

          IF NPRTN = 0 AND
             RG.GEN_JIYU_CD = 0 AND
             RG.SAISHIN_KBN = 0 THEN
             IRTN := GAAPK0030.FGETATENA(  CRJIDO.KOJIN_NO,
                                          'GKB',
                                          ISAKUSEIBI,
                                          RA,
                                          RASO);
            VJINKAKU_KBN := RA.JINKAKU_KBN;
            -- 保護者を判定する
            -- 学齢簿に保護者が設定されている場合（保護者個人番号が0でない）
            IF RG.HOGOSYA_KOJIN_NO <> 0 THEN

               IF RA.JINKAKU_KBN = 1 THEN
                  IRTN := GKBPK00010.FGKJHGS(ISAKUSEIBI,
                                                        RG.KOJIN_NO,
                                                        IHOGOSHA_KOJIN_NO,
                                                        VSHIMEI_KANJI);
               ELSE
               -- 学齢簿の個人番号をインプットして、保護者取得サブルーチンを呼ぶ
                  IRTN := GKBPK00010.FHOGOSHA(ISAKUSEIBI,
                                              RG.KOJIN_NO,
                                              IHOGOSHA_KOJIN_NO);           
               END IF;

               -- 学齢簿の保護者個人番号をインプットして、宛名情報取得サブルーチンを呼ぶ
               IRTN := GAAPK0030.FGETATENA(  RG.HOGOSYA_KOJIN_NO,
                                             'GKB',
                                             ISAKUSEIBI,
                                             RB,
                                             RC);

               IHOGOSHA_KOJIN_NO := COALESCE(IHOGOSHA_KOJIN_NO,0);

               IRTN := GKBFKZKGMGET(1,
                                    RG.ZOKUGARA1,
                                    RG.ZOKUGARA2,
                                    RG.ZOKUGARA3,
                                    RG.ZOKUGARA4,
                                    VZOKUGARAMEI1,
                                    IRTNZOKUGARAHERR1);

               IRTN := GKBFKZKGMGET(2,
                                    RG.HOGOSYA_ZOKUGARA1,
                                    RG.HOGOSYA_ZOKUGARA2,
                                    RG.HOGOSYA_ZOKUGARA3,
                                    RG.HOGOSYA_ZOKUGARA4,
                                    VZOKUGARAMEI2,
                                    IRTNZOKUGARAHERR2);

               VHOGOSHA_SHIMEI_JODAN := RB.SHIMEI_KANA;
               VHOGOSHA_SHIMEI_GEDAN := RB.SHIMEI_KANJI;
               -- 保護者取得サブルーチンOUTの保護者個人番号と学齢簿の保護者個人番号が一致するか判定する
               -- 不一致の場合
               IF IHOGOSHA_KOJIN_NO <> RG.HOGOSYA_KOJIN_NO THEN
                  -- 児童世帯番号と保護者世帯番号が不一致である
                  IF RA.SETAI_NO <> RB.SETAI_NO OR
                     -- 現存区分がゼロ以外が、転出者を含む喪失者
                     RB.GENZON_KBN <> 0 THEN
                       -- 保護者判定区分を、3【要確認】とする
                       IHANTEI_KBNI := 3;
                       IHOGOSHA_KOJIN_NO := RG.HOGOSYA_KOJIN_NO;
                  ELSE
                       IHANTEI_KBNI := 2;
                       IHOGOSHA_KOJIN_NO := RG.HOGOSYA_KOJIN_NO;
                  END IF;
               ELSE
                     IHANTEI_KBNI := 2;
                     IHOGOSHA_KOJIN_NO := RG.HOGOSYA_KOJIN_NO;
               END IF;
            ELSE
               IF RA.JINKAKU_KBN = 1 THEN
                  IRTN := GKBPK00010.FGKJHGS(ISAKUSEIBI,
                                                        RG.KOJIN_NO,
                                                        IHOGOSHA_KOJIN_NO,
                                                        VSHIMEI_KANJI);
               ELSE
               -- 学齢簿の個人番号をインプットして、保護者取得サブルーチンを呼ぶ
                  IRTN := GKBPK00010.FHOGOSHA(ISAKUSEIBI,
                                              RG.KOJIN_NO,
                                              IHOGOSHA_KOJIN_NO);           
               END IF;
                  IHOGOSHA_KOJIN_NO := COALESCE(IHOGOSHA_KOJIN_NO,0);

                  -- 保護者個人番号が０のときはNULL
                  IF IHOGOSHA_KOJIN_NO = 0 THEN
                     IHANTEI_KBNI := 4;
                     MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANA := NULL;
                     MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := NULL;
                     VZOKUGARAMEI1 := NULL;
                     VZOKUGARAMEI2 := NULL;
                     VHOGOSHA_SHIMEI_JODAN := NULL;
                     VHOGOSHA_SHIMEI_GEDAN := NULL;
                  ELSE
                     IHANTEI_KBNI := 1;
                     IRTN := GAAPK0030.FGETATENA(  IHOGOSHA_KOJIN_NO,
                                                 'GKB',
                                                 ISAKUSEIBI,
                                                 RB,
                                                 RC);
                     BEGIN
                       SELECT SHIMEI_KANA
                         INTO VHOGOSHA_SHIMEI_JODAN
                         FROM GABTATENAKIHON
                        WHERE KOJIN_NO = IHOGOSHA_KOJIN_NO;
                     EXCEPTION
                       WHEN NO_DATA_FOUND THEN
                            DBMS_OUTPUT.PUT_LINE('保護者氏名かな不明　'||IHOGOSHA_KOJIN_NO);
                     END;
                     BEGIN
                       SELECT SHIMEI_KANJI
                         INTO VHOGOSHA_SHIMEI_GEDAN
                         FROM GABTATENAKIHON
                        WHERE KOJIN_NO = IHOGOSHA_KOJIN_NO;
                     EXCEPTION
                       WHEN NO_DATA_FOUND THEN
                            DBMS_OUTPUT.PUT_LINE('保護者氏名漢字不明　'||IHOGOSHA_KOJIN_NO);
                     END;
                     -- 判定用続柄コードを変換
                     --- 初期化
                     IHOGOSHA_ZOKUGARA := 0;
                     NJ_ZOKUGARACD1    := 0;
                     IF RA.ZOKUGARACD1 BETWEEN 10 AND 29 OR RA.ZOKUGARACD1 IN( 71,72,89 ) THEN
                         NJ_ZOKUGARACD1 := 10;            -- 子を再セット
                     END IF;

                     IF I_SYSTEMJOKEN = 1 THEN
                         IF ( RB.ZOKUGARACD1 = 1 AND RB.ZOKUGARACD2 = 0 AND RB.ZOKUGARACD3 = 0 AND RB.ZOKUGARACD4 = 0 )       -- 保護者の続柄（住記）が「世帯主」のみ
                          AND  ( NJ_ZOKUGARACD1 = 10 AND RA.ZOKUGARACD2 = 0 AND RA.ZOKUGARACD3 = 0 AND RA.ZOKUGARACD4 = 0 ) THEN -- 児童の続柄（住記）が「子」のみ
                             IF RB.SEIBETSU = 1 THEN
                                IHOGOSHA_ZOKUGARA := 4;
                             ELSIF  RB.SEIBETSU = 2 THEN
                                IHOGOSHA_ZOKUGARA := 5;
                             END IF;
                         ELSE
                            IHOGOSHA_ZOKUGARA := 0;
                         END IF;
                     ELSE
                         IF RB.SEIBETSU = 1 THEN
                            IHOGOSHA_ZOKUGARA := 4;
                         ELSIF  RB.SEIBETSU = 2 THEN
                            IHOGOSHA_ZOKUGARA := 5;
                         END IF;
                     END IF; 
                     UPDATE GKBTGAKUREIBO
                     --2024/12/27 JIP.Y.SATO UPD ST
                        --SET HOGOSYA_KOJIN_NO = IHOGOSHA_KOJIN_NO,
                        --    HOGOSYA_ZOKUGARA1 = IHOGOSHA_ZOKUGARA,
                        --    HOGOSYA_ZOKUGARA2 = 0,
                        --    HOGOSYA_ZOKUGARA3 = 0,
                        --   HOGOSYA_ZOKUGARA4 = 0,
                        SET
                           --2024/12/27 JIP.Y.SATO UPD ED
--  2024/06/06 ZCZL.GUANHONG Update Start 0.3.000.000:新WizLIFE２次開発
--                            SYS_KOSHINBI = ISAKUSEIBI,
--                            SYS_JIKAN = NSYSTIME,
--                            SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                            SYS_TANMATU_NO = g_sWSNUM
--                      WHERE KOJIN_NO = RG.KOJIN_NO
--                        AND RIREKI_RENBAN = RG.RIREKI_RENBAN;  
                           SAISHIN_KBN = 1,
                           SYS_KOSHINBI = ISAKUSEIBI,
                           SYS_JIKAN = NSYSTIME,
                           SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                           SYS_TANMATU_NO = g_sWSNUM
                     WHERE SAISHIN_KBN = 0
                       AND KOJIN_NO = RG.KOJIN_NO
                       AND RIREKI_RENBAN = RG.RIREKI_RENBAN  
                       AND RIREKI_RENBAN_EDA = RG.RIREKI_RENBAN_EDA;
--  2024/06/06 ZCZL.GUANHONG Update end 
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
--  2024/09/24 ZCZL.WANGMING UPDATE START 0.3.000.002:仕様変更　ID：IT_GKB_00065対応
                     BEGIN
                       SELECT
                           *
                       INTO
                          rGKBTGAKUREIBO
                       FROM
                          GKBTGAKUREIBO
                       WHERE
                       --2024/12/27 JIP.Y.SATO UPD ST
                          --SAISHIN_KBN = 1
                          --AND KOJIN_NO = RG.KOJIN_NO
                          --AND RIREKI_RENBAN = RG.RIREKI_RENBAN 
                          --AND RIREKI_RENBAN_EDA = RG.RIREKI_RENBAN_EDA
                          --AND SYS_KOSHINBI = ISAKUSEIBI
                          --AND SYS_JIKAN = NSYSTIME
                          --AND SYS_SHOKUINKOJIN_NO = g_sTANTOCODE
                          --AND SYS_TANMATU_NO = g_sWSNUM;
                              KOJIN_NO = RG.KOJIN_NO
                          AND RIREKI_RENBAN = RG.RIREKI_RENBAN 
                          AND RIREKI_RENBAN_EDA = RG.RIREKI_RENBAN_EDA;
                       --2024/12/27 JIP.Y.SATO UPD ED
                     EXCEPTION
                        WHEN OTHERS THEN
                          rGKBTGAKUREIBO := NULL;
                     END;
--                     INSERT INTO GKBTGAKUREIBO
--                     (SELECT 
--                     KOJIN_NO,
--                     RIREKI_RENBAN+10,
--                     RIREKI_RENBAN_EDA,
--                     GENZON_KBN,
--                     0,
--                     ZO_JIYU_CD,
--                     ZO_NENGAPI,
--                     GEN_JIYU_CD,
--                     GEN_NENGAPI,
--                     ZOKUGARA1,
--                     ZOKUGARA2,
--                     ZOKUGARA3,
--                     ZOKUGARA4,
--                     HOGOSYA_KOJIN_NO,
--                     HOGOSYA_ZOKUGARA1,
--                     HOGOSYA_ZOKUGARA2,
--                     HOGOSYA_ZOKUGARA3,
--                     HOGOSYA_ZOKUGARA4,
--                     SYOGAKO_CD,
--                     SYOGAKO_NYUGAKU_BI,
--                     SYOGAKO_TENNYUGAKU_BI,
--                     SYOGAKO_TENGAKU_BI,
--                     SYOGAKO_SOTSUGYO_BI,
--                     TYUGAKO_CD,
--                     TYUGAKO_NYUGAKU_BI,
--                     TYUGAKO_TENNYUGAKU_BI,
--                     TYUGAKO_TENGAKU_BI,
--                     TYUGAKO_SOTSUGYO_BI,
--                     TOKUSOKU_BI1,
--                     TOKUSOKU_NAIYO1,
--                     TOKUSOKU_JIYU1,
--                     TOKUSOKU_JURI_BI1,
--                     TOKUSOKU_BI2,
--                     TOKUSOKU_NAIYO2,
--                     TOKUSOKU_JIYU2,
--                     TOKUSOKU_JURI_BI2,
--                     TOKUSOKU_BI3,
--                     TOKUSOKU_NAIYO3,
--                     TOKUSOKU_JIYU3,
--                     TOKUSOKU_JURI_BI3,
--                     TOKUSOKU_BI4,
--                     TOKUSOKU_NAIYO4,
--                     TOKUSOKU_JIYU4,
--                     TOKUSOKU_JURI_BI4,
--                     TOKUSOKU_BI5,
--                     TOKUSOKU_NAIYO5,
--                     TOKUSOKU_JIYU5,
--                     TOKUSOKU_JURI_BI5,
--                     TOKUSOKU_BI6,
--                     TOKUSOKU_NAIYO6,
--                     TOKUSOKU_JIYU6,
--                     TOKUSOKU_JURI_BI6,
--                     TOKUSOKU_BI7,
--                     TOKUSOKU_NAIYO7,
--                     TOKUSOKU_JIYU7,
--                     TOKUSOKU_JURI_BI7,
--                     TOKUSOKU_BI8,
--                     TOKUSOKU_NAIYO8,
--                     TOKUSOKU_JIYU8,
--                     TOKUSOKU_JURI_BI8,
--                     TOKUSOKU_BI9,
--                     TOKUSOKU_NAIYO9,
--                     TOKUSOKU_JIYU9,
--                     TOKUSOKU_JURI_BI9,
--                     TOKUSOKU_BI10,
--                     TOKUSOKU_NAIYO10,
--                     TOKUSOKU_JIYU10,
--                     TOKUSOKU_JURI_BI10,
--                     KUIKIGAI_CD,
--                     KUIKIGAI_SETISYA,
--                     KUIKIGAI_NYUGAKU_BI,
--                     KUIKIGAI_TENNYUGAKU_BI,
--                     KUIKIGAI_TENGAKU_BI,
--                     KUIKIGAI_TAIGAKU_BI,
--                     KUIKIGAI_SOTSUGYO_BI,
--                     YOGOGAKO_CD,
--                     YOGOGAKO_SETISYA,
--                     YOGOGAKO_NYUGAKU_BI,
--                     YOGOGAKO_TENNYUGAKU_BI,
--                     YOGOGAKO_TENGAKU_BI,
--                     YOGOGAKO_TAIGAKU_BI,
--                     YOGOGAKO_SOTSUGYO_BI,
--                     YUYO_KYOKA_BI,
--                     YUYO_JIYU_CD,
--                     YUYO_JIYU,
--                     YUYO_KAISI_BI,
--                     YUYO_SYURYO_BI,
--                     YUYO_NENSU,
--                     YUYO_FUKUGAKU_BI,
--                     MENJO_KYOKA_BI,
--                     MENJO_JIYU_CD,
--                     MENJO_JIYU,
--                     MENJO_KAISI_BI,
--                     MENJO_SYURYO_BI,
--                     MENJO_NENSU,
--                     MENJO_FUKUGAKU_BI,
--                     IDO_BI1,
--                     IDO_JIYU1,
--                     IDO_BI2,
--                     IDO_JIYU2,
--                     IDO_BI3,
--                     IDO_JIYU3,
--                     IDO_BI4,
--                     IDO_JIYU4,
--                     IDO_BI5,
--                     IDO_JIYU5,
--                     IDO_BI6,
--                     IDO_JIYU6,
--                     IDO_BI7,
--                     IDO_JIYU7,
--                     IDO_BI8,
--                     IDO_JIYU8,
--                     IDO_BI9,
--                     IDO_JIYU9,
--                     IDO_BI10,
--                     IDO_JIYU10,
--                     SYS_SAKUSEIBI,
--                     SYS_KOSHINBI,
--                     SYS_JIKAN,
--                     SYS_SHOKUINKOJIN_NO,
--                     SYS_TANMATU_NO,
--                     GAKUNEN,
--                     SHORIBI,
--                     SHUGAKU,
--                     IDOJIKO,
--                     CHOHYO_NO,
--                     SYOGAKO_TENNYUGAKU_GAKUNEN,
--                     SYOGAKO_TENGAKU_GAKUNEN,
--                     TYUGAKO_TENNYUGAKU_GAKUNEN,
--                     TYUGAKO_TENGAKU_GAKUNEN,
--                     KUIKIGAI_TENNYUGAKU_GAKUNEN,
--                     KUIKIGAI_TENGAKU_GAKUNEN,
--                     KUIKIGAI_TAIGAKU_GAKUNEN,
--                     YOGOGAKO_TENNYUGAKU_GAKUNEN,
--                     YOGOGAKO_TENGAKU_GAKUNEN,
--                     YOGOGAKO_TAIGAKU_GAKUNEN,
--                     GAKKO_KBN_CD,
--                     GAKUKYU_CD,
--                     SEIBETSU,
--                     JOTAI,
--                     TENNYUMAE_GAKKO_KBN,
--                     TENNYUMAE_GAKKO_CD,
--                     TENNYUMAE_GAKUNEN,
--                     GENKYURYUCHI_FLG,
--                     GENKYURYUCHI_KETTEI_BI,
--                     GENKYURYUCHI_KAISI_BI,
--                     GENKYURYUCHI_SYURYOBI,
--                     GENKYURYUCHI_RIYU,
--                     SHITEI_SYOGAKO_CD,
--                     SHITEI_TYUGAKO_CD,
--                     HENKO_GAKUNEN_SYOGAKO,
--                     HENKO_GAKUNEN_TYUGAKO,
--                     HENKO_SHINSEI_BI,
--                     HENKO_KYOKA_BI,
--                     HENKO_KBN,
--                     HENKO_KAISI_BI,
--                     HENKO_SYURYO_BI,
--                     HENKO_KYOKA_RIYU,
--                     HENKO_JIYU,
--                     HENKO_HUKYOKA_RIYU,
--                     KIBO_GAKKO_KBN_CD,
--                     KIBO_SYOGAKKO_CD,
--                     KIBO_TYUGAKKO_CD,
--                     KIBO_UKETSUKE_BI_SYOGAKO,
--                     KIBO_UKETSUKE_BI_TYUGAKO,
--                     KUIKIGAISHUGAKU_FLG,
--                     KUIKIGAISHUGAKU_SHINSEI_BI,
--                     KUIKIGAISHUGAKU_KYOKA_BI,
--                     KUIKIGAISHUGAKU_KAISI_BI,
--                     KUIKIGAISHUGAKU_SYURYO_BI,
--                     KUIKIGAISHUGAKU_JIYU,
--                     KUIKIGAISHUGAKU_KYOKA_RIYU,
--                     KUIKIGAISHUGAKU_HUKYOKA_RIYU,
--                     HUSHUGAKU_KAISI_BI,
--                     HUSHUGAKU_SYURYO_BI,
--                     HUSHUGAKU_RIYU,
--                     KUNISHIRITSU_CD,
--                     KUNISHIRITSU_NYUGAKU_BI,
--                     KUNISHIRITSU_TENNYUGAKU_BI,
--                     KUNISHIRITSU_TENNYUGAKU_GAKUNEN,
--                     KUNISHIRITSU_TENGAKU_BI,
--                     KUNISHIRITSU_TENGAKU_GAKUNEN,
--                     KUNISHIRITSU_TAIGAKU_BI,
--                     KUNISHIRITSU_TAIGAKU_GAKUNEN,
--                     KUNISHIRITSU_SOTSUGYO_BI,
--                     KUNISHIRITSU_KAISI_BI,
--                     KUNISHIRITSU_SYURYO_BI,
--                     TSUSHOMEI_KANA,
--                     TSUSHOMEI_KANJI,
--                     HOGOSYA_TSUSHOMEI_KANA,
--                     HOGOSYA_TSUSHOMEI_KANJI,
--                     GRB_HENKO_TODOKEDE_BI,
--                     GRB_HENKO_BI,
--                     13,
--                     BIKO,
--                     IDO_BI,
--                     TODOKEDE_BI,
--                     SHINSEI_KANRI_RENBAN,
--                     IDOJI_ATENA_RIREKI_RENBAN,
--                     HOGOSYA_IDOJI_RIREKI_RENBAN,
--                     SHOGAKKOKU_CD,
--                     CHUGAKKOKU_CD,
--                     SAKUJO_FLG,
--                     SYS_TANMATU_BASHO
--                     FROM 
--                     GKBTGAKUREIBO
--                     WHERE 
--                     SAISHIN_KBN = 1
--                     AND KOJIN_NO = RG.KOJIN_NO
--                     AND RIREKI_RENBAN = RG.RIREKI_RENBAN 
--                     AND RIREKI_RENBAN_EDA = RG.RIREKI_RENBAN_EDA
--                     AND SYS_KOSHINBI = ISAKUSEIBI
--                     AND SYS_JIKAN = NSYSTIME
--                     AND SYS_SHOKUINKOJIN_NO = g_sTANTOCODE
--                     AND SYS_TANMATU_NO = g_sWSNUM );
                     INSERT INTO GKBTGAKUREIBO
                       (
                       KOJIN_NO
                       ,RIREKI_RENBAN
                       ,RIREKI_RENBAN_EDA
                       ,GENZON_KBN
                       ,SAISHIN_KBN
                       ,ZO_JIYU_CD
                       ,ZO_NENGAPI
                       ,GEN_JIYU_CD
                       ,GEN_NENGAPI
                       ,ZOKUGARA1
                       ,ZOKUGARA2
                       ,ZOKUGARA3
                       ,ZOKUGARA4
                       ,HOGOSYA_KOJIN_NO
                       ,HOGOSYA_ZOKUGARA1
                       ,HOGOSYA_ZOKUGARA2
                       ,HOGOSYA_ZOKUGARA3
                       ,HOGOSYA_ZOKUGARA4
                       ,SYOGAKO_CD
                       ,SYOGAKO_NYUGAKU_BI
                       ,SYOGAKO_TENNYUGAKU_BI
                       ,SYOGAKO_TENGAKU_BI
                       ,SYOGAKO_SOTSUGYO_BI
                       ,TYUGAKO_CD
                       ,TYUGAKO_NYUGAKU_BI
                       ,TYUGAKO_TENNYUGAKU_BI
                       ,TYUGAKO_TENGAKU_BI
                       ,TYUGAKO_SOTSUGYO_BI
                       ,TOKUSOKU_BI1
                       ,TOKUSOKU_NAIYO1
                       ,TOKUSOKU_JIYU1
                       ,TOKUSOKU_JURI_BI1
                       ,TOKUSOKU_BI2
                       ,TOKUSOKU_NAIYO2
                       ,TOKUSOKU_JIYU2
                       ,TOKUSOKU_JURI_BI2
                       ,TOKUSOKU_BI3
                       ,TOKUSOKU_NAIYO3
                       ,TOKUSOKU_JIYU3
                       ,TOKUSOKU_JURI_BI3
                       ,TOKUSOKU_BI4
                       ,TOKUSOKU_NAIYO4
                       ,TOKUSOKU_JIYU4
                       ,TOKUSOKU_JURI_BI4
                       ,TOKUSOKU_BI5
                       ,TOKUSOKU_NAIYO5
                       ,TOKUSOKU_JIYU5
                       ,TOKUSOKU_JURI_BI5
                       ,TOKUSOKU_BI6
                       ,TOKUSOKU_NAIYO6
                       ,TOKUSOKU_JIYU6
                       ,TOKUSOKU_JURI_BI6
                       ,TOKUSOKU_BI7
                       ,TOKUSOKU_NAIYO7
                       ,TOKUSOKU_JIYU7
                       ,TOKUSOKU_JURI_BI7
                       ,TOKUSOKU_BI8
                       ,TOKUSOKU_NAIYO8
                       ,TOKUSOKU_JIYU8
                       ,TOKUSOKU_JURI_BI8
                       ,TOKUSOKU_BI9
                       ,TOKUSOKU_NAIYO9
                       ,TOKUSOKU_JIYU9
                       ,TOKUSOKU_JURI_BI9
                       ,TOKUSOKU_BI10
                       ,TOKUSOKU_NAIYO10
                       ,TOKUSOKU_JIYU10
                       ,TOKUSOKU_JURI_BI10
                       ,KUIKIGAI_CD
                       ,KUIKIGAI_SETISYA
                       ,KUIKIGAI_NYUGAKU_BI
                       ,KUIKIGAI_TENNYUGAKU_BI
                       ,KUIKIGAI_TENGAKU_BI
                       ,KUIKIGAI_TAIGAKU_BI
                       ,KUIKIGAI_SOTSUGYO_BI
                       ,YOGOGAKO_CD
                       ,YOGOGAKO_SETISYA
                       ,YOGOGAKO_NYUGAKU_BI
                       ,YOGOGAKO_TENNYUGAKU_BI
                       ,YOGOGAKO_TENGAKU_BI
                       ,YOGOGAKO_TAIGAKU_BI
                       ,YOGOGAKO_SOTSUGYO_BI
                       ,YUYO_KYOKA_BI
                       ,YUYO_JIYU_CD
                       ,YUYO_JIYU
                       ,YUYO_KAISI_BI
                       ,YUYO_SYURYO_BI
                       ,YUYO_NENSU
                       ,YUYO_FUKUGAKU_BI
                       ,MENJO_KYOKA_BI
                       ,MENJO_JIYU_CD
                       ,MENJO_JIYU
                       ,MENJO_KAISI_BI
                       ,MENJO_SYURYO_BI
                       ,MENJO_NENSU
                       ,MENJO_FUKUGAKU_BI
                       ,IDO_BI1
                       ,IDO_JIYU1
                       ,IDO_BI2
                       ,IDO_JIYU2
                       ,IDO_BI3
                       ,IDO_JIYU3
                       ,IDO_BI4
                       ,IDO_JIYU4
                       ,IDO_BI5
                       ,IDO_JIYU5
                       ,IDO_BI6
                       ,IDO_JIYU6
                       ,IDO_BI7
                       ,IDO_JIYU7
                       ,IDO_BI8
                       ,IDO_JIYU8
                       ,IDO_BI9
                       ,IDO_JIYU9
                       ,IDO_BI10
                       ,IDO_JIYU10
                       ,SYS_SAKUSEIBI
                       ,SYS_KOSHINBI
                       ,SYS_JIKAN
                       ,SYS_SHOKUINKOJIN_NO
                       ,SYS_TANMATU_NO
                       ,GAKUNEN
                       ,SHORIBI
                       ,SHUGAKU
                       ,IDOJIKO
                       ,CHOHYO_NO
                       ,SYOGAKO_TENNYUGAKU_GAKUNEN
                       ,SYOGAKO_TENGAKU_GAKUNEN
                       ,TYUGAKO_TENNYUGAKU_GAKUNEN
                       ,TYUGAKO_TENGAKU_GAKUNEN
                       ,KUIKIGAI_TENNYUGAKU_GAKUNEN
                       ,KUIKIGAI_TENGAKU_GAKUNEN
                       ,KUIKIGAI_TAIGAKU_GAKUNEN
                       ,YOGOGAKO_TENNYUGAKU_GAKUNEN
                       ,YOGOGAKO_TENGAKU_GAKUNEN
                       ,YOGOGAKO_TAIGAKU_GAKUNEN
                       ,GAKKO_KBN_CD
                       ,GAKUKYU_CD
                       ,SEIBETSU
                       ,JOTAI
                       ,TENNYUMAE_GAKKO_KBN
                       ,TENNYUMAE_GAKKO_CD
                       ,TENNYUMAE_GAKUNEN
                       ,GENKYURYUCHI_FLG
                       ,GENKYURYUCHI_KETTEI_BI
                       ,GENKYURYUCHI_KAISI_BI
                       ,GENKYURYUCHI_SYURYOBI
                       ,GENKYURYUCHI_RIYU
                       ,SHITEI_SYOGAKO_CD
                       ,SHITEI_TYUGAKO_CD
                       ,HENKO_GAKUNEN_SYOGAKO
                       ,HENKO_GAKUNEN_TYUGAKO
                       ,HENKO_SHINSEI_BI
                       ,HENKO_KYOKA_BI
                       ,HENKO_KBN
                       ,HENKO_KAISI_BI
                       ,HENKO_SYURYO_BI
                       ,HENKO_KYOKA_RIYU
                       ,HENKO_JIYU
                       ,HENKO_HUKYOKA_RIYU
                       ,KIBO_GAKKO_KBN_CD
                       ,KIBO_SYOGAKKO_CD
                       ,KIBO_TYUGAKKO_CD
                       ,KIBO_UKETSUKE_BI_SYOGAKO
                       ,KIBO_UKETSUKE_BI_TYUGAKO
                       ,KUIKIGAISHUGAKU_FLG
                       ,KUIKIGAISHUGAKU_SHINSEI_BI
                       ,KUIKIGAISHUGAKU_KYOKA_BI
                       ,KUIKIGAISHUGAKU_KAISI_BI
                       ,KUIKIGAISHUGAKU_SYURYO_BI
                       ,KUIKIGAISHUGAKU_JIYU
                       ,KUIKIGAISHUGAKU_KYOKA_RIYU
                       ,KUIKIGAISHUGAKU_HUKYOKA_RIYU
                       ,HUSHUGAKU_KAISI_BI
                       ,HUSHUGAKU_SYURYO_BI
                       ,HUSHUGAKU_RIYU
                       ,KUNISHIRITSU_CD
                       ,KUNISHIRITSU_NYUGAKU_BI
                       ,KUNISHIRITSU_TENNYUGAKU_BI
                       ,KUNISHIRITSU_TENNYUGAKU_GAKUNEN
                       ,KUNISHIRITSU_TENGAKU_BI
                       ,KUNISHIRITSU_TENGAKU_GAKUNEN
                       ,KUNISHIRITSU_TAIGAKU_BI
                       ,KUNISHIRITSU_TAIGAKU_GAKUNEN
                       ,KUNISHIRITSU_SOTSUGYO_BI
                       ,KUNISHIRITSU_KAISI_BI
                       ,KUNISHIRITSU_SYURYO_BI
                       ,TSUSHOMEI_KANA
                       ,TSUSHOMEI_KANJI
                       ,HOGOSYA_TSUSHOMEI_KANA
                       ,HOGOSYA_TSUSHOMEI_KANJI
                       ,GRB_HENKO_TODOKEDE_BI
                       ,GRB_HENKO_BI
                       ,GRB_HENKO_JIYU
                       ,BIKO
                       ,IDO_BI
                       ,TODOKEDE_BI
                       ,SHINSEI_KANRI_RENBAN
                       ,IDOJI_ATENA_RIREKI_RENBAN
                       ,HOGOSYA_IDOJI_RIREKI_RENBAN
                       ,SHOGAKKOKU_CD
                       ,CHUGAKKOKU_CD
                       ,SAKUJO_FLG
                       ,SYS_TANMATU_BASHO
                       )
                    VALUES
                       (
                       rGKBTGAKUREIBO.KOJIN_NO
                       ,rGKBTGAKUREIBO.RIREKI_RENBAN+10
                       ,rGKBTGAKUREIBO.RIREKI_RENBAN_EDA
                       ,rGKBTGAKUREIBO.GENZON_KBN
                       ,0
                       ,rGKBTGAKUREIBO.ZO_JIYU_CD
                       ,rGKBTGAKUREIBO.ZO_NENGAPI
                       ,rGKBTGAKUREIBO.GEN_JIYU_CD
                       ,rGKBTGAKUREIBO.GEN_NENGAPI
                       ,rGKBTGAKUREIBO.ZOKUGARA1
                       ,rGKBTGAKUREIBO.ZOKUGARA2
                       ,rGKBTGAKUREIBO.ZOKUGARA3
                       ,rGKBTGAKUREIBO.ZOKUGARA4
                       --2024/12/27 JIP.Y.SATO UPD ST
                       --,rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO
                       ,IHOGOSHA_KOJIN_NO
                       --2024/12/27 JIP.Y.SATO UPD ED
                       ,IHOGOSHA_ZOKUGARA
                       ,0
                       ,0
                       ,0
                       ,rGKBTGAKUREIBO.SYOGAKO_CD
                       ,rGKBTGAKUREIBO.SYOGAKO_NYUGAKU_BI
                       ,rGKBTGAKUREIBO.SYOGAKO_TENNYUGAKU_BI
                       ,rGKBTGAKUREIBO.SYOGAKO_TENGAKU_BI
                       ,rGKBTGAKUREIBO.SYOGAKO_SOTSUGYO_BI
                       ,rGKBTGAKUREIBO.TYUGAKO_CD
                       ,rGKBTGAKUREIBO.TYUGAKO_NYUGAKU_BI
                       ,rGKBTGAKUREIBO.TYUGAKO_TENNYUGAKU_BI
                       ,rGKBTGAKUREIBO.TYUGAKO_TENGAKU_BI
                       ,rGKBTGAKUREIBO.TYUGAKO_SOTSUGYO_BI
                       ,rGKBTGAKUREIBO.TOKUSOKU_BI1
                       ,rGKBTGAKUREIBO.TOKUSOKU_NAIYO1
                       ,rGKBTGAKUREIBO.TOKUSOKU_JIYU1
                       ,rGKBTGAKUREIBO.TOKUSOKU_JURI_BI1
                       ,rGKBTGAKUREIBO.TOKUSOKU_BI2
                       ,rGKBTGAKUREIBO.TOKUSOKU_NAIYO2
                       ,rGKBTGAKUREIBO.TOKUSOKU_JIYU2
                       ,rGKBTGAKUREIBO.TOKUSOKU_JURI_BI2
                       ,rGKBTGAKUREIBO.TOKUSOKU_BI3
                       ,rGKBTGAKUREIBO.TOKUSOKU_NAIYO3
                       ,rGKBTGAKUREIBO.TOKUSOKU_JIYU3
                       ,rGKBTGAKUREIBO.TOKUSOKU_JURI_BI3
                       ,rGKBTGAKUREIBO.TOKUSOKU_BI4
                       ,rGKBTGAKUREIBO.TOKUSOKU_NAIYO4
                       ,rGKBTGAKUREIBO.TOKUSOKU_JIYU4
                       ,rGKBTGAKUREIBO.TOKUSOKU_JURI_BI4
                       ,rGKBTGAKUREIBO.TOKUSOKU_BI5
                       ,rGKBTGAKUREIBO.TOKUSOKU_NAIYO5
                       ,rGKBTGAKUREIBO.TOKUSOKU_JIYU5
                       ,rGKBTGAKUREIBO.TOKUSOKU_JURI_BI5
                       ,rGKBTGAKUREIBO.TOKUSOKU_BI6
                       ,rGKBTGAKUREIBO.TOKUSOKU_NAIYO6
                       ,rGKBTGAKUREIBO.TOKUSOKU_JIYU6
                       ,rGKBTGAKUREIBO.TOKUSOKU_JURI_BI6
                       ,rGKBTGAKUREIBO.TOKUSOKU_BI7
                       ,rGKBTGAKUREIBO.TOKUSOKU_NAIYO7
                       ,rGKBTGAKUREIBO.TOKUSOKU_JIYU7
                       ,rGKBTGAKUREIBO.TOKUSOKU_JURI_BI7
                       ,rGKBTGAKUREIBO.TOKUSOKU_BI8
                       ,rGKBTGAKUREIBO.TOKUSOKU_NAIYO8
                       ,rGKBTGAKUREIBO.TOKUSOKU_JIYU8
                       ,rGKBTGAKUREIBO.TOKUSOKU_JURI_BI8
                       ,rGKBTGAKUREIBO.TOKUSOKU_BI9
                       ,rGKBTGAKUREIBO.TOKUSOKU_NAIYO9
                       ,rGKBTGAKUREIBO.TOKUSOKU_JIYU9
                       ,rGKBTGAKUREIBO.TOKUSOKU_JURI_BI9
                       ,rGKBTGAKUREIBO.TOKUSOKU_BI10
                       ,rGKBTGAKUREIBO.TOKUSOKU_NAIYO10
                       ,rGKBTGAKUREIBO.TOKUSOKU_JIYU10
                       ,rGKBTGAKUREIBO.TOKUSOKU_JURI_BI10
                       ,rGKBTGAKUREIBO.KUIKIGAI_CD
                       ,rGKBTGAKUREIBO.KUIKIGAI_SETISYA
                       ,rGKBTGAKUREIBO.KUIKIGAI_NYUGAKU_BI
                       ,rGKBTGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI
                       ,rGKBTGAKUREIBO.KUIKIGAI_TENGAKU_BI
                       ,rGKBTGAKUREIBO.KUIKIGAI_TAIGAKU_BI
                       ,rGKBTGAKUREIBO.KUIKIGAI_SOTSUGYO_BI
                       ,rGKBTGAKUREIBO.YOGOGAKO_CD
                       ,rGKBTGAKUREIBO.YOGOGAKO_SETISYA
                       ,rGKBTGAKUREIBO.YOGOGAKO_NYUGAKU_BI
                       ,rGKBTGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI
                       ,rGKBTGAKUREIBO.YOGOGAKO_TENGAKU_BI
                       ,rGKBTGAKUREIBO.YOGOGAKO_TAIGAKU_BI
                       ,rGKBTGAKUREIBO.YOGOGAKO_SOTSUGYO_BI
                       ,rGKBTGAKUREIBO.YUYO_KYOKA_BI
                       ,rGKBTGAKUREIBO.YUYO_JIYU_CD
                       ,rGKBTGAKUREIBO.YUYO_JIYU
                       ,rGKBTGAKUREIBO.YUYO_KAISI_BI
                       ,rGKBTGAKUREIBO.YUYO_SYURYO_BI
                       ,rGKBTGAKUREIBO.YUYO_NENSU
                       ,rGKBTGAKUREIBO.YUYO_FUKUGAKU_BI
                       ,rGKBTGAKUREIBO.MENJO_KYOKA_BI
                       ,rGKBTGAKUREIBO.MENJO_JIYU_CD
                       ,rGKBTGAKUREIBO.MENJO_JIYU
                       ,rGKBTGAKUREIBO.MENJO_KAISI_BI
                       ,rGKBTGAKUREIBO.MENJO_SYURYO_BI
                       ,rGKBTGAKUREIBO.MENJO_NENSU
                       ,rGKBTGAKUREIBO.MENJO_FUKUGAKU_BI
                       ,rGKBTGAKUREIBO.IDO_BI1
                       ,rGKBTGAKUREIBO.IDO_JIYU1
                       ,rGKBTGAKUREIBO.IDO_BI2
                       ,rGKBTGAKUREIBO.IDO_JIYU2
                       ,rGKBTGAKUREIBO.IDO_BI3
                       ,rGKBTGAKUREIBO.IDO_JIYU3
                       ,rGKBTGAKUREIBO.IDO_BI4
                       ,rGKBTGAKUREIBO.IDO_JIYU4
                       ,rGKBTGAKUREIBO.IDO_BI5
                       ,rGKBTGAKUREIBO.IDO_JIYU5
                       ,rGKBTGAKUREIBO.IDO_BI6
                       ,rGKBTGAKUREIBO.IDO_JIYU6
                       ,rGKBTGAKUREIBO.IDO_BI7
                       ,rGKBTGAKUREIBO.IDO_JIYU7
                       ,rGKBTGAKUREIBO.IDO_BI8
                       ,rGKBTGAKUREIBO.IDO_JIYU8
                       ,rGKBTGAKUREIBO.IDO_BI9
                       ,rGKBTGAKUREIBO.IDO_JIYU9
                       ,rGKBTGAKUREIBO.IDO_BI10
                       ,rGKBTGAKUREIBO.IDO_JIYU10
                       ,ISAKUSEIBI
                       ,rGKBTGAKUREIBO.SYS_KOSHINBI
                       ,NSYSTIME
                       ,g_sTANTOCODE
                       ,g_sWSNUM
                       ,rGKBTGAKUREIBO.GAKUNEN
                       --2024/12/27 JIP.Y.SATO UPD ST
                       --,rGKBTGAKUREIBO.SHORIBI
                       ,ISAKUSEIBI
                       --2024/12/27 JIP.Y.SATO UPD ED
                       ,rGKBTGAKUREIBO.SHUGAKU
                       ,rGKBTGAKUREIBO.IDOJIKO
                       ,rGKBTGAKUREIBO.CHOHYO_NO
                       ,rGKBTGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.GAKKO_KBN_CD
                       ,rGKBTGAKUREIBO.GAKUKYU_CD
                       ,rGKBTGAKUREIBO.SEIBETSU
                       ,rGKBTGAKUREIBO.JOTAI
                       ,rGKBTGAKUREIBO.TENNYUMAE_GAKKO_KBN
                       ,rGKBTGAKUREIBO.TENNYUMAE_GAKKO_CD
                       ,rGKBTGAKUREIBO.TENNYUMAE_GAKUNEN
                       ,rGKBTGAKUREIBO.GENKYURYUCHI_FLG
                       ,rGKBTGAKUREIBO.GENKYURYUCHI_KETTEI_BI
                       ,rGKBTGAKUREIBO.GENKYURYUCHI_KAISI_BI
                       ,rGKBTGAKUREIBO.GENKYURYUCHI_SYURYOBI
                       ,rGKBTGAKUREIBO.GENKYURYUCHI_RIYU
                       ,rGKBTGAKUREIBO.SHITEI_SYOGAKO_CD
                       ,rGKBTGAKUREIBO.SHITEI_TYUGAKO_CD
                       ,rGKBTGAKUREIBO.HENKO_GAKUNEN_SYOGAKO
                       ,rGKBTGAKUREIBO.HENKO_GAKUNEN_TYUGAKO
                       ,rGKBTGAKUREIBO.HENKO_SHINSEI_BI
                       ,rGKBTGAKUREIBO.HENKO_KYOKA_BI
                       ,rGKBTGAKUREIBO.HENKO_KBN
                       ,rGKBTGAKUREIBO.HENKO_KAISI_BI
                       ,rGKBTGAKUREIBO.HENKO_SYURYO_BI
                       ,rGKBTGAKUREIBO.HENKO_KYOKA_RIYU
                       ,rGKBTGAKUREIBO.HENKO_JIYU
                       ,rGKBTGAKUREIBO.HENKO_HUKYOKA_RIYU
                       ,rGKBTGAKUREIBO.KIBO_GAKKO_KBN_CD
                       ,rGKBTGAKUREIBO.KIBO_SYOGAKKO_CD
                       ,rGKBTGAKUREIBO.KIBO_TYUGAKKO_CD
                       ,rGKBTGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO
                       ,rGKBTGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO
                       ,rGKBTGAKUREIBO.KUIKIGAISHUGAKU_FLG
                       ,rGKBTGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI
                       ,rGKBTGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI
                       ,rGKBTGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI
                       ,rGKBTGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI
                       ,rGKBTGAKUREIBO.KUIKIGAISHUGAKU_JIYU
                       ,rGKBTGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU
                       ,rGKBTGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU
                       ,rGKBTGAKUREIBO.HUSHUGAKU_KAISI_BI
                       ,rGKBTGAKUREIBO.HUSHUGAKU_SYURYO_BI
                       ,rGKBTGAKUREIBO.HUSHUGAKU_RIYU
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_CD
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_TENGAKU_BI
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_KAISI_BI
                       ,rGKBTGAKUREIBO.KUNISHIRITSU_SYURYO_BI
                       ,rGKBTGAKUREIBO.TSUSHOMEI_KANA
                       ,rGKBTGAKUREIBO.TSUSHOMEI_KANJI
                       ,rGKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA
                       ,rGKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI
                       --2024/12/27 JIP.Y.SATO UPD ST
                       --,rGKBTGAKUREIBO.GRB_HENKO_TODOKEDE_BI
                       --,rGKBTGAKUREIBO.GRB_HENKO_BI
                       ,ISAKUSEIBI
                       ,ISAKUSEIBI
                       --2024/12/27 JIP.Y.SATO UPD ED
                       ,13
                       ,rGKBTGAKUREIBO.BIKO
                       --2024/12/27 JIP.Y.SATO UPD ST
                       --,rGKBTGAKUREIBO.IDO_BI
                       --,rGKBTGAKUREIBO.TODOKEDE_BI
                       ,ISAKUSEIBI
                       ,ISAKUSEIBI
                       --2024/12/27 JIP.Y.SATO UPD ED
                       ,rGKBTGAKUREIBO.SHINSEI_KANRI_RENBAN
                       ,rGKBTGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN
                       ,rGKBTGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN
                       ,rGKBTGAKUREIBO.SHOGAKKOKU_CD
                       ,rGKBTGAKUREIBO.CHUGAKKOKU_CD
                       ,rGKBTGAKUREIBO.SAKUJO_FLG
                       ,rGKBTGAKUREIBO.SYS_TANMATU_BASHO
                       );
--  2024/09/24 ZCZL.WANGMING UPDATE END
--  2024/06/06 ZCZL.GUANHONG Add end 

                     IRTN := GKBFKZKGMGET(1,
                                          RG.ZOKUGARA1,
                                          RG.ZOKUGARA2,
                                          RG.ZOKUGARA3,
                                          RG.ZOKUGARA4,
                                          VZOKUGARAMEI1,
                                          IRTNZOKUGARAHERR1);
                     IRTN := GKBFKZKGMGET(2,
                                          IHOGOSHA_ZOKUGARA,
                                          0,
                                          0,
                                          0,
                                          VZOKUGARAMEI2,
                                          IRTNZOKUGARAHERR2);
                  END IF;
            END IF;
            
            
            IF IHANTEI_KBNI = 1 THEN
               VHANTEI_KBNI := '保護者新規登録者';
            ELSIF IHANTEI_KBNI = 2 THEN
                  VHANTEI_KBNI := '保護者既存登録者';
            ELSIF IHANTEI_KBNI = 3 THEN
                  VHANTEI_KBNI := '保護者既存登録者（要確認）';
            ELSIF IHANTEI_KBNI = 4 THEN
                  VHANTEI_KBNI := '保護者不明者';
            END IF;
            IWAREKIHIZUKE := 0;  
            BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                         RA.SEINENGAPI,
                                         VSEINENGAPI,
                                         VEDIT_GYYMMDD2,
                                         VEDIT_GYYMMDD3,
                                         VKJ_GENGO,
                                         VKG_GENGO,
                                         IWAREKI_YY,
                                         ISEIREKI_YYYY,
                                         IWAREKI_GYYMM,
                                         IMM,
                                         IDD,
                                         IOWAREKIHIZUKE,
                                         ISEIREKIHIZUKE);
            IF RA.SEIBETSU = 1 THEN
               VSEIBETSU := '男';
            ELSIF RA.SEIBETSU = 2 THEN
               VSEIBETSU := '女';
            END IF;

            --学校ｺｰﾄﾞ、学校名の初期化
            IGAKO_CD := 0;          
            VGAKOMEI := '';         

            BEGIN
              IF RG.SYOGAKO_CD <> 0 AND RG.SYOGAKO_TENGAKU_BI = 0 AND RG.SYOGAKO_SOTSUGYO_BI = 0 THEN  
                 SELECT SYOGAKO_CD,
                        SYOGAKOMEI
                   INTO IGAKO_CD,
                        VGAKOMEI
                   FROM GKBTSHOGAKKO
                   WHERE SYOGAKO_CD = RG.SYOGAKO_CD;
                   VGAKUNENSEI := TO_CHAR(CRJIDO.GAKUNEN_CD);
                   VGAKUNENMEI := VGAKUNENSEI || '年生';
              --区域外在学
              ELSIF RG.KUIKIGAI_CD <> 0 AND RG.KUIKIGAI_TENGAKU_BI = 0 AND RG.KUIKIGAI_TAIGAKU_BI = 0 AND RG.KUIKIGAI_SOTSUGYO_BI = 0 THEN
                 SELECT KUIKIGAI_CD,
                        KUIKIGAIMEI
                   INTO IGAKO_CD,
                        VGAKOMEI
                   FROM GKBTKUIKIGAI
                   WHERE KUIKIGAI_CD = RG.KUIKIGAI_CD;
                   VGAKUNENSEI := TO_CHAR(CRJIDO.GAKUNEN_CD);
                   VGAKUNENMEI := VGAKUNENSEI || '年生';
              --特別支援学校在学
              ELSIF RG.YOGOGAKO_CD <> 0 AND RG.YOGOGAKO_TENGAKU_BI = 0 AND RG.YOGOGAKO_TAIGAKU_BI = 0 AND RG.YOGOGAKO_SOTSUGYO_BI = 0 THEN
                 SELECT YOGOGAKO_CD,
                        YOGOGAKOMEI
                   INTO IGAKO_CD,
                        VGAKOMEI
                   FROM GKBTYOGOGAKKO
                   WHERE YOGOGAKO_CD = RG.YOGOGAKO_CD;
                   VGAKUNENSEI := TO_CHAR(CRJIDO.GAKUNEN_CD);
                   VGAKUNENMEI := VGAKUNENSEI || '年生';
--  2024/06/06 ZCZL.GUANHONG Add　Start 0.3.000.000:新WizLIFE２次開発
              ELSIF RG.KUNISHIRITSU_CD <> 0 AND RG.KUNISHIRITSU_TENGAKU_BI = 0 AND RG.KUNISHIRITSU_TAIGAKU_BI = 0 AND RG.KUNISHIRITSU_SOTSUGYO_BI = 0 THEN
                   BEGIN   
                     SELECT KUNISHIRITSUGAKKO_CD,
                            KUNISHIRITSUGAKKOMEI
                       INTO IGAKO_CD,
                            VGAKOMEI
                     FROM GKBTKUNISIRITSUGAKKO
                     WHERE KUNISHIRITSUGAKKO_CD = RG.KUNISHIRITSU_CD;
                     VGAKUNENSEI := TO_CHAR(CRJIDO.GAKUNEN_CD);
                     VGAKUNENMEI := VGAKUNENSEI || '年生';
                   EXCEPTION
--  2024/08/29 ZCZL.WANGMING Update Start 0.3.000.001:8月1日認識合わせの横展開
--                       WHEN NO_DATA_FOUND THEN
--                           DBMS_OUTPUT.PUT_LINE('国私立学校コード不明と国私立学校名'||IHOGOSHA_KOJIN_NO);
                       WHEN OTHERS THEN
                            IGAKO_CD := NULL;
                            VGAKOMEI := NULL;
--  2024/08/29 ZCZL.WANGMING Update End
                   END;                   
--  2024/06/06 ZCZL.GUANHONG Add end         
              ELSE
                 SELECT TYUGAKO_CD,
                        TYUGAKOMEI
                   INTO IGAKO_CD,
                        VGAKOMEI
                   FROM GKBTCHUGAKKO
                   WHERE TYUGAKO_CD = RG.TYUGAKO_CD;
                   NGAKUNENSEI := NGAKUNEN_CD - 6;
                   VGAKUNENSEI := TO_CHAR(CRJIDO.GAKUNEN_CD);
                   VGAKUNENMEI := VGAKUNENSEI || '年生';
              END IF;
                    EXCEPTION
              WHEN NO_DATA_FOUND THEN
                   DBMS_OUTPUT.PUT_LINE('学校名不明　'||RG.KOJIN_NO);
            END;
            VGYOSEIKU_MEI := GAAPK0030.FGYOSEIKUMEI(RA.SANTEIDANTAI_CD,RA.GYOSEIKU_CD);

            VHAN_MEI := GAAPK0030.FHANMEI(RA.SANTEIDANTAI_CD,
                                           RA.HAN_CD);
            IRTN := GAAPK0030.FJICHINAME(RA.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);
            IWAREKIHIZUKE := 0;  
            BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                         ISAKUSEIBI,
                                         VEDIT_GYYMMDD3,
                                         VEDIT_GYYMMDD2,
                                         VSASKUSEIBI,
                                         VKJ_GENGO,
                                         VKG_GENGO,
                                         IWAREKI_YY,
                                         ISEIREKI_YYYY,
                                         IWAREKI_GYYMM,
                                         IMM,
                                         IDD,
                                         IOWAREKIHIZUKE,
                                         ISEIREKIHIZUKE);

            VSETAI_NO :=  TO_CHAR(RA.SETAI_NO);
                    MHOGOSHA_WORK(ICNT).HANTEI_KBNI := IHANTEI_KBNI;
                    MHOGOSHA_WORK(ICNT).HYOJI_HANTEI_KBNI := VHANTEI_KBNI;
                    MHOGOSHA_WORK(ICNT).JIDO_KOJIN_NO := RG.KOJIN_NO;
                    MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA := RA.SHIMEI_KANA;
                    MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI := RA.SHIMEI_KANJI;
                    MHOGOSHA_WORK(ICNT).SEINENGAPI := RA.SEINENGAPI;
                    MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI := VSEINENGAPI;
                    MHOGOSHA_WORK(ICNT).SEIBETSU := RA.SEIBETSU;
                    MHOGOSHA_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;
                    MHOGOSHA_WORK(ICNT).ZOKUGARAMEI1 := VZOKUGARAMEI1;
                    MHOGOSHA_WORK(ICNT).JIDO_SETAI_NO := RA.SETAI_NO;
                    MHOGOSHA_WORK(ICNT).HYOJI_JIDO_SETAI_NO := VSETAI_NO;
                    MHOGOSHA_WORK(ICNT).HOGOSHA_KOJIN_NO := IHOGOSHA_KOJIN_NO;

                    MHOGOSHA_WORK(ICNT).ZOKUGARAMEI2 := VZOKUGARAMEI2;
                    MHOGOSHA_WORK(ICNT).HOGOSHA_SETAI_NO := ' ';
                    MHOGOSHA_WORK(ICNT).SOSHITSU_JIYU := ' ';
                    MHOGOSHA_WORK(ICNT).IDO_NENGAPI := ' ';
                    MHOGOSHA_WORK(ICNT).GAKUNEN_CD := CRJIDO.GAKUNEN_CD;
                    MHOGOSHA_WORK(ICNT).GAKUNENMEI := ' ';
                    MHOGOSHA_WORK(ICNT).GAKOKU_CD := IGAKO_CD;
                    MHOGOSHA_WORK(ICNT).GAKOKUMEI := VGAKOMEI;
                    MHOGOSHA_WORK(ICNT).GYOSEIKU_CD := RA.GYOSEIKU_CD;
                    MHOGOSHA_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;
                    MHOGOSHA_WORK(ICNT).HAN_CD := RA.HAN_CD;
                    MHOGOSHA_WORK(ICNT).HANMEI := VHAN_MEI;
                    MHOGOSHA_WORK(ICNT).SANTEIDANTAI_CD := RA.SANTEIDANTAI_CD;
                    MHOGOSHA_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;

                    MHOGOSHA_WORK(ICNT).KAIPEJI_CD := ' ';
                    MHOGOSHA_WORK(ICNT).KAIPEJI := ' ';
                    MHOGOSHA_WORK(ICNT).SAKUSEIBI := VSASKUSEIBI;
                    MHOGOSHA_WORK(ICNT).RENBAN := ICNT + 1;
                    MHOGOSHA_WORK(ICNT).HYOJI_RENBAN := ' ';
                    MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := VHOGOSHA_SHIMEI_JODAN;
                    MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN := VHOGOSHA_SHIMEI_GEDAN;
                    MHOGOSHA_WORK(ICNT).KON_JUSHO_JODAN := ' ';
                    MHOGOSHA_WORK(ICNT).KON_JUSHO_GEDAN := ' ';
                    MHOGOSHA_WORK(ICNT).JINKAKU_KBN := VJINKAKU_KBN;

                    ICNT := ICNT + 1;               -- カウントアップ
                    IFRET := c_ISUCCESS;              -- 正常終了

                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                RAISE ERR;
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        /* その他エラー */
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            RAISE ERR;
        RETURN IFRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 保護者ワーク中間（GKBWHOGOSHAJUDGE）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_INSERT_JIDO_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- 戻り値
        IMAX                BINARY_INTEGER;             -- 戻り値
        IMIN                BINARY_INTEGER;             -- 戻り値
    BEGIN
        IFRET := c_ISUCCESS;                  -- 正常終了
        -- ワーク領域の最終位置を取得
        IMAX := MHOGOSHA_WORK.LAST;
        -- ワーク領域の先頭位置を取得
        IMIN := MHOGOSHA_WORK.FIRST;
        BEGIN
            -- ワーク領域の件数分繰り返し処理を行う
            FOR ICNT IN IMIN..IMAX LOOP
                INSERT INTO
                GKBWHOGOSHAJUDGE
                (
                 HANTEI_KBNI,
                 HYOJI_HANTEI_KBNI,
                 JIDO_KOJIN_NO,
                 JIDO_SHIMEI_KANA,
                 JIDO_SHIMEI_KANJI,
                 SEINENGAPI,
                 HYOJI_SEINENGAPI,
                 SEIBETSU,
                 HYOJI_SEIBETSU,
                 ZOKUGARAMEI1,
                 JIDO_SETAI_NO,
                 HYOJI_JIDO_SETAI_NO,
                 HOGOSHA_KOJIN_NO,
                 HOGOSHA_SHIMEI_KANA,
                 HOGOSHA_SHIMEI_KANJI,
                 ZOKUGARAMEI2,
                 HOGOSHA_SETAI_NO,
                 SOSHITSU_JIYU,
                 IDO_NENGAPI,
                 GAKUNEN_CD,
                 GAKUNENMEI,
                 GAKOKU_CD,
                 GAKOKUMEI,
                 GYOSEIKU_CD,
                 GYOSEIKUMEI,
                 HAN_CD,
                 HANMEI,
                 SANTEIDANTAI_CD,
                 SANTEIDANTAIMEI,
                 KAIPEJI_CD,
                 KAIPEJI,
                 SAKUSEIBI,
                 RENBAN,
                 HYOJI_RENBAN,
                 HOGOSHA_SHIMEI_JODAN,
                 HOGOSHA_SHIMEI_GEDAN,
                 KON_JUSHO_JODAN,
                 KON_JUSHO_GEDAN,
                 JINKAKU_KBN
                )
                VALUES
                (
                 MHOGOSHA_WORK(ICNT).HANTEI_KBNI,
                 MHOGOSHA_WORK(ICNT).HYOJI_HANTEI_KBNI,
                 MHOGOSHA_WORK(ICNT).JIDO_KOJIN_NO,
                 MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA,
                 MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI,
                 MHOGOSHA_WORK(ICNT).SEINENGAPI,
                 MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI,
                 MHOGOSHA_WORK(ICNT).SEIBETSU,
                 MHOGOSHA_WORK(ICNT).HYOJI_SEIBETSU,
                 MHOGOSHA_WORK(ICNT).ZOKUGARAMEI1,
                 MHOGOSHA_WORK(ICNT).JIDO_SETAI_NO,
                 MHOGOSHA_WORK(ICNT).HYOJI_JIDO_SETAI_NO,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_KOJIN_NO,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANJI,
                 MHOGOSHA_WORK(ICNT).ZOKUGARAMEI2,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_SETAI_NO,
                 MHOGOSHA_WORK(ICNT).SOSHITSU_JIYU,
                 MHOGOSHA_WORK(ICNT).IDO_NENGAPI,
                 MHOGOSHA_WORK(ICNT).GAKUNEN_CD,
                 MHOGOSHA_WORK(ICNT).GAKUNENMEI,
                 MHOGOSHA_WORK(ICNT).GAKOKU_CD,
                 MHOGOSHA_WORK(ICNT).GAKOKUMEI,
                 MHOGOSHA_WORK(ICNT).GYOSEIKU_CD,
                 MHOGOSHA_WORK(ICNT).GYOSEIKUMEI,
                 MHOGOSHA_WORK(ICNT).HAN_CD,
                 MHOGOSHA_WORK(ICNT).HANMEI,
                 MHOGOSHA_WORK(ICNT).SANTEIDANTAI_CD,
                 MHOGOSHA_WORK(ICNT).SANTEIDANTAIMEI,
                 MHOGOSHA_WORK(ICNT).KAIPEJI_CD,
                 MHOGOSHA_WORK(ICNT).KAIPEJI,
                 MHOGOSHA_WORK(ICNT).SAKUSEIBI,
                 MHOGOSHA_WORK(ICNT).RENBAN,
                 MHOGOSHA_WORK(ICNT).HYOJI_RENBAN,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_JODAN,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN,
                 MHOGOSHA_WORK(ICNT).KON_JUSHO_JODAN,
                 MHOGOSHA_WORK(ICNT).KON_JUSHO_GEDAN,
                 MHOGOSHA_WORK(ICNT).JINKAKU_KBN
                );
            END LOOP;
            -- コミット（確定）
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;       -- 処理前に戻す
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                RAISE ERR;
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        /* その他エラー */
        WHEN OTHERS THEN
            ROLLBACK;       -- 処理前に戻す
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            RAISE ERR;
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 保護者ワーク中間（GKBWHOGOSHAJUDGE）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        VSQL                NVARCHAR2(10000);           -- ＳＱＬ文
        VSQLSEL             NVARCHAR2(9000);            -- ＳＱＬのソート以外
        VSQLORDER           NVARCHAR2(1000);            -- ＳＱＬの［ORDER BY］句
        I_CUR               PLS_INTEGER;                -- カーソル
        RREC                GKBWHOGOSHAJUDGE%ROWTYPE;      -- 入学通知台帳のレコード変数
        NROWS               NUMBER;                     --
        IPAGECNT            PLS_INTEGER;                -- 頁数
        IGYOCNT             PLS_INTEGER;                -- 行番号
        IGYORENBAN          PLS_INTEGER;                -- 行連番
        VPAGENAME           NVARCHAR2(500);             -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(500);             -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(500);             -- 改頁項目値のワーク
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IGYOCNT := 0;
        ICNT := 0;
        MHOGOSHA_WORK.DELETE;                   -- ワーク領域の初期化
        -- ［ORDER BY］句を付加
        IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
          VSQLORDER := ' ORDER BY HANTEI_KBNI, ' || g_rJSTP.ORDERBYCLAUSE;
        ELSE
          VSQLORDER := ' ORDER BY HANTEI_KBNI ';
        END IF;
        
        VPAGEFD := 'GAKOKU_CD||GAKUNEN_CD';
        VPAGENM := 'GAKOKUMEI';
        
        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'HANTEI_KBNI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_HANTEI_KBNI, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
            VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
            VSQLSEL := VSQLSEL || 'RENBAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAIMEI, ';
            VSQLSEL := VSQLSEL || VPAGEFD || ' KAIPEJI_CD, ';            -- 改頁値を設定
            VSQLSEL := VSQLSEL || VPAGENM || ' KAIPEJI ';            -- 改頁名を設定
            VSQLSEL := VSQLSEL || ',JINKAKU_KBN '; 
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWHOGOSHAJUDGE ';
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;
            -- カーソルのオープン
            I_CUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(I_CUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, RREC.HANTEI_KBNI);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, RREC.HYOJI_HANTEI_KBNI, 26);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.KAIPEJI, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.SAKUSEIBI, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.RENBAN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.JIDO_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.JIDO_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.HYOJI_SEINENGAPI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.HYOJI_SEIBETSU, 2);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.ZOKUGARAMEI1, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.HOGOSHA_SHIMEI_JODAN, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.HOGOSHA_SHIMEI_GEDAN, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.ZOKUGARAMEI2, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.GYOSEIKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.JIDO_SETAI_NO);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.SANTEIDANTAIMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, VPAGENM, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.JINKAKU_KBN); 
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(I_CUR);
            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(I_CUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  1, MHOGOSHA_WORK(ICNT).HANTEI_KBNI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  2, MHOGOSHA_WORK(ICNT).HYOJI_HANTEI_KBNI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  3, MHOGOSHA_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  4, MHOGOSHA_WORK(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  5, MHOGOSHA_WORK(ICNT).SAKUSEIBI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  7, MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  9, MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MHOGOSHA_WORK(ICNT).HYOJI_SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MHOGOSHA_WORK(ICNT).ZOKUGARAMEI1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_JODAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MHOGOSHA_WORK(ICNT).ZOKUGARAMEI2);


                    DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MHOGOSHA_WORK(ICNT).GYOSEIKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MHOGOSHA_WORK(ICNT).JIDO_SETAI_NO);

                    DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MHOGOSHA_WORK(ICNT).SANTEIDANTAIMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 18, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 19, VPAGENAME);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 20, MHOGOSHA_WORK(ICNT).JINKAKU_KBN);
--  2024/04/28 ZCZL.WUCAO Update 0.2.000.003:512_GKB_00033対応
--                    IF VPAGEFD <> '' THEN
                      IF VPAGEFD IS NOT NULL THEN
                        -- 改頁の指定がある場合
                        IF VPAGEWORK = VPAGENAME THEN
                        -- 以前の改頁項目名と同じ
                            IGYOCNT := IGYOCNT + 1;
                            IGYORENBAN := IGYORENBAN + 1;

                            IF IGYOCNT > c_IMAXROWS THEN
                            -- １頁内の最大行数を超えた
                                IPAGECNT := IPAGECNT + 1;
                                IGYOCNT := 1;
                                VPAGEWORK := VPAGENAME;
                            END IF;
                        ELSE
                        -- 改頁必要
                            IPAGECNT := IPAGECNT + 1;
                            IGYOCNT := 1;
                            IGYORENBAN := 1;
                            VPAGEWORK := VPAGENAME;
                        END IF;
                        -- 再セットする項目
                        MHOGOSHA_WORK(ICNT).RENBAN := IGYORENBAN;    -- 連番
                        MHOGOSHA_WORK(ICNT).KAIPEJI := VPAGENAME;    -- 改頁名
                        MHOGOSHA_WORK(ICNT).KAIPEJI_CD := VPAGEWORK; -- 改頁コード
                    ELSE
                        -- 再セットする項目
                        MHOGOSHA_WORK(ICNT).RENBAN := ICNT + 1;     -- 連番
                        MHOGOSHA_WORK(ICNT).KAIPEJI := '';   -- 改頁名
                        MHOGOSHA_WORK(ICNT).KAIPEJI_CD := ''; -- 改頁コード
                    END IF;
                ELSE
                    -- 全件読み込み終了
                    EXIT;
                END IF;
                ICNT := ICNT + 1;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                FRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                RAISE ERR;
        END;
        RETURN FRET;
    END FUNC_GET_JIDO_WK_CSV;
    --------------------------------------------------------------------------------
    -- 保護者ワーク中間（GKBWHOGOSHAJUDGE）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        r_CHOHYO_001        GKBWL100R001%ROWTYPE;
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        IMAX := MHOGOSHA_WORK.LAST;             -- ワーク領域の件数の最大値
        IMIN := MHOGOSHA_WORK.FIRST;            -- ワーク領域の件数の最小値  
        -- 取得した件数分繰り返す
        FOR ICNT IN IMIN..IMAX LOOP
           nCOUNT                                  := nCOUNT + 1;
           r_CHOHYO_001                            := NULL;  
           r_CHOHYO_001.NO                         := nCOUNT                                                                ;-- ソート順
           r_CHOHYO_001.HANTEI_KBN                 := MHOGOSHA_WORK(ICNT).HANTEI_KBNI                                       ;-- 判定区分
           r_CHOHYO_001.HANTEI_KBNMEI              := MHOGOSHA_WORK(ICNT).HYOJI_HANTEI_KBNI                                 ;-- 判定区分名
           r_CHOHYO_001.KAIPAGE_CD                 := MHOGOSHA_WORK(ICNT).HANTEI_KBNI ||MHOGOSHA_WORK(ICNT).KAIPEJI         ;-- 改頁コード
           r_CHOHYO_001.KAIPAGE_HYOJI              := MHOGOSHA_WORK(ICNT).KAIPEJI                                           ;-- 改頁表示用
           r_CHOHYO_001.GENZAIBI                   := MHOGOSHA_WORK(ICNT).SAKUSEIBI                                         ;-- 現在日
           r_CHOHYO_001.NUM                        := MHOGOSHA_WORK(ICNT).RENBAN                                            ;-- No
           r_CHOHYO_001.SHIMEI_KANA                := MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA                                  ;-- 氏名カナ
           r_CHOHYO_001.SHIMEI                     := MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI                                 ;-- 氏名
           r_CHOHYO_001.SEINENGAPI                 := MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI                                  ;-- 生年月日
           r_CHOHYO_001.SEIBETSU                   := MHOGOSHA_WORK(ICNT).HYOJI_SEIBETSU                                    ;-- 性別
           r_CHOHYO_001.HOGOSHA_KANKEI             := MHOGOSHA_WORK(ICNT).ZOKUGARAMEI1                                      ;-- 保護者との関係
           r_CHOHYO_001.HOGOSHA_SHIMEI_JODAN       := MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_JODAN                              ;-- 保護者氏名上
           r_CHOHYO_001.HOGOSHA_SHIMEI             := MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN                              ;-- 保護者
           r_CHOHYO_001.JIDO_ZOKUGARAMEI           := MHOGOSHA_WORK(ICNT).ZOKUGARAMEI2                                      ;-- 児童との関係
           r_CHOHYO_001.GYOSEIKU                   := MHOGOSHA_WORK(ICNT).GYOSEIKUMEI                                       ;-- 行政区
           r_CHOHYO_001.SETAI_NO                   := MHOGOSHA_WORK(ICNT).JIDO_SETAI_NO                                     ;-- 世帯番号
           r_CHOHYO_001.BIKO                       := MHOGOSHA_WORK(ICNT).SANTEIDANTAIMEI                                   ;-- 備考
           r_CHOHYO_001.JINKAKU_KBN                := MHOGOSHA_WORK(ICNT).JINKAKU_KBN                                       ;-- 人格区分
           --  2024/03/19 ZCZL.WUCAO Update 0.2.000.001:512_GKB_00003対応
           --r_CHOHYO_001.BREAK_NO                   := MHOGOSHA_WORK(ICNT).HANTEI_KBNI ||MHOGOSHA_WORK(ICNT).KAIPEJ                                           ;-- 改ページキー
           r_CHOHYO_001.BREAK_NO                   := MHOGOSHA_WORK(ICNT).HANTEI_KBNI ||MHOGOSHA_WORK(ICNT).KAIPEJI         ;-- 改ページキー
           r_CHOHYO_001.WSNUM                      := g_sWSNUM                                                              ;-- 端末番号
           r_CHOHYO_001.BATCHKBN                   := c_BATCH                                                               ;-- 即時バッチ区分
           r_CHOHYO_001.JOBNUM                     := g_nJOBNUM                                                             ;-- ジョブNO

           INSERT INTO GKBWL100R001 VALUES r_CHOHYO_001;
        
        END LOOP;
        -- 終了
        RETURN FRET;
    EXCEPTION
        WHEN OTHERS THEN
            FRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE;
    -------------------------------------------------------------------------------------
    --  １.排他処理
    -------------------------------------------------------------------------------------
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
    FUNCTION FUNC_HAITAI_SET RETURN PLS_INTEGER
    IS
        bRTN                          BOOLEAN;    --戻り値
        NRTN                          NUMBER;
    BEGIN

        NRTN := GKBFKHTSET(2,'999999999999','全件',TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),g_sTANTOCODE,g_sWSNUM,g_nTIME);
        IF NRTN = 1 THEN
            VLOG := '排他がかかっているデータが存在するため、処理を実行できませんでした。';
--  2024/08/29 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_HAITAI_SET', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
            RETURN 1;
        ELSIF NRTN <> 0 AND NRTN <> 1 THEN
            VLOG := '排他制御処理で異常終了しました。';
--  2024/08/29 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_HAITAI_SET', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
            RETURN 1;
        ELSE
            BHAITA_FLAG := TRUE;
        END IF;     

      RETURN 0;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 1;
    END FUNC_HAITAI_SET;
--  2024/06/06 ZCZL.GUANHONG Add end 
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        ERR              EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        DELETE FROM GKBWL100R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
        COMMIT; 
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
        --１.排他処理
        I_RTN := FUNC_HAITAI_SET;
        IF I_RTN <> 0 THEN
--  2024/08/29 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--            RETURN FALSE;
           RAISE ERR;
        END IF;
--  2024/06/06 ZCZL.GUANHONG Add end 
        -- 取得した条件をそれぞれの変数へセット

        VGAKUNEN        := g_vJYOUKEN01;        -- 学年
        VSYURYOGAKUNEN  := g_vJYOUKEN02;        -- 終了学年

        -- 保護者ワーク（GKBWHOGOSHAJUDGE）のデータ全件削除
        I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
        IF B_RTN = c_BERROR THEN
          RAISE  ERR;
        END IF;

        I_SYSTEMJOKEN := 0;
        I_SYSTEMJOKEN := FUNC_GET_SYSJOKEN(c_ISYS_J_KANKEI);

        -- 保護者ワーク中間データ作成
        I_RTN := FUNC_GET_JIDO_WK;
        IF I_RTN <> c_ISUCCESS THEN
            --  2024/04/19 ZCZL.LIKEWEN ADD START 0.2.000.002:512_GKB_00018対応
            IF I_RTN = c_INOTFOUND THEN
              --対象データ無しの場合は異常終了させない
              GOTO NODATA_EXIT;
            END IF;
            --  2024/04/19 ZCZL.LIKEWEN ADD END
            RAISE  ERR;
        END IF;
        -- 保護者ワークテーブル作成
        I_RTN := FUNC_INSERT_JIDO_WK;
        IF I_RTN = c_INOT_SUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE  ERR;
        END IF;
        -- 保護者ワークデータ作成（ＣＳＶ用）
        I_RTN := FUNC_GET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE  ERR;
        END IF;
        -- 保護者ワークＣＳＶファイル作成
        I_RTN := FUNC_SET_JIDO_WK_CSVFILE;
        IF I_RTN <> c_ISUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE  ERR;
        END IF;
        --帳票出力CSVの作成
        bRTN :=FUNC_B11CSV('GKBWL100R001');
        --  2024/04/19 ZCZL.LIKEWEN ADD START 0.2.000.002:512_GKB_00018対応
        <<NODATA_EXIT>>
        --  2024/04/19 ZCZL.LIKEWEN ADD END

        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);

        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE;
    END FUNC_B10SAKUHYO1; 
    --------------------------------------------------------
    --  機能概要      : 更新処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;  --戻り値
    BEGIN
        g_nUPDLOGSEQ := g_nUPDLOGSEQ + 1;
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 2);
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 2);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
    END FUNC_B20UPDATE1;
    --------------------------------------------------------
    --  機能概要      : バッチ処理の呼出
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_nRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    PROCEDURE PBATCH(i_nJOBNUM  IN  NUMBER,
                     o_nRESULT  OUT NUMBER)
    IS
        ePRMEXCEPTION                 EXCEPTION;                --パラメータ取得異常タイプ
        eSHORIEXCEPTION               EXCEPTION;                --処理異常タイプ
        bRTN                          BOOLEAN;                  --戻り値
        aSTEPSEQ_TBL                  KKBPK5551.tySTEPSEQ_Tbl;  --処理ステップ連番
        nSTEPSEQ_MAX                  NUMBER;                   --処理ステップレコード数

    BEGIN
        --戻り値
        o_nRESULT := c_OK;
        --ジョブナンバーをセット
        g_nJOBNUM := i_nJOBNUM;
        --バッチ初期処理
        bRTN := FUNC_B00INIT;
        IF NOT bRTN THEN
            RAISE ePRMEXCEPTION;
        END IF;
        --バッチ入力値取得
        bRTN := FUNC_B01PINIT;
        IF NOT bRTN THEN
            RAISE ePRMEXCEPTION;
        END IF;

        --処理ステップを取得
        bRTN := KKBPK5551.FJSTGetStep (g_nJOBNUM, aSTEPSEQ_TBL, nSTEPSEQ_MAX);
        g_nSTEP_MAX  := nSTEPSEQ_MAX;
        --処理ステップ連番が終了するまで繰り返す
        FOR i IN 1..nSTEPSEQ_MAX LOOP

            g_nSTEP_INDEX := i;
            --バッチステップ処理パラメータ取得
            bRTN := FUNC_B02PINIT (aSTEPSEQ_TBL(i));
            IF NOT bRTN THEN
                RAISE ePRMEXCEPTION;
            END IF;

            --バッチジョブステップ情報を更新
            PROC_JSTPSTAUTSUPD(1);
            --メイン処理
            CASE g_rJSTP.SHORIKBN
                WHEN 0 THEN
                    --作表処理
                    bRTN := FUNC_B10SAKUHYO1;
                    IF NOT bRTN THEN
                        o_nRESULT := c_ERR;
                    END IF;
                WHEN 1 THEN
                    --更新処理
                    bRTN := FUNC_B20UPDATE1;
                    IF NOT bRTN THEN
                        o_nRESULT := c_ERR;
                    END IF;
                ELSE
                    NULL;
            END CASE;
            --異常処理へ
            IF o_nRESULT <> 0 THEN
                RAISE eSHORIEXCEPTION;
            END IF;

            --バッチジョブステップ情報を更新
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);

        END LOOP;

        --件数表出力
        PROC_KENSUSET;

        --終了処理
        bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
        COMMIT;
--  2024/06/06 ZCZL.GUANHONG Start 0.3.000.000:新WizLIFE２次開発
        FUNC_HAITAI_CLEAR;
    EXCEPTION
        WHEN ePRMEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
--  2024/06/06 ZCZL.GUANHONG Start 0.3.000.000:新WizLIFE２次開発
            FUNC_HAITAI_CLEAR;
        WHEN eSHORIEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
--  2024/06/06 ZCZL.GUANHONG Start 0.3.000.000:新WizLIFE２次開発
            FUNC_HAITAI_CLEAR;
        WHEN OTHERS THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
--  2024/06/06 ZCZL.GUANHONG Start 0.3.000.000:新WizLIFE２次開発
            FUNC_HAITAI_CLEAR;
    END PBATCH;
END GKBPC00190;
/
