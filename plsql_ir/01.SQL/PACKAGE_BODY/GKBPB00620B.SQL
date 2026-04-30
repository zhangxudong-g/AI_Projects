CREATE OR REPLACE PACKAGE BODY GKBPB00620
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 原級留置対象者一覧作成
--  機能概要      : 原級留置対象者一覧(一括処理)できる。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.muzl 2024/06/13
--------------------------------------------------------
--  変更履歴
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00286横展開対応
--------------------------------------------------------
IS
    -- 全処理必須パラメータ
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
    c_BATCH                       CONSTANT PLS_INTEGER := 2;   --バッチ
    rGKBTGAKUREIBO                GKBTGAKUREIBO%ROWTYPE;       --学齢簿
    rGKBWGENKYURYUCHI             GKBWGENKYURYUCHI%ROWTYPE;    --原級留置対象者一覧中間ワーク
    g_vJYOUKEN                    NVARCHAR2(500);              --条件
    g_vBASEDATEYMD                NUMBER;                      -- 基準日
    g_nINDEX                      NUMBER := 0;
    g_nTIME NUMBER;  --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --------------------------------------------------------------------
    --  変数宣言
    --------------------------------------------------------------------
    g_nSORT                     NUMBER := 0;                 --ソート順
    -- 集計用変数
    BRTN                        BOOLEAN;            -- ステータス
    VSQLERRM                    NVARCHAR2(256);     -- エラーメッセージ
    nCOUNT                      NUMBER;             -- 件数
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--    nCOUNT1                     NUMBER;             -- CSV出力件数
    nCOUNT1                     NUMBER:= 0;           -- CSV出力件数
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
    --  作成者／作成日: ZCZL.muzl 2024/06/14
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
        bRTN := KKBPK5551.FSETBLOG (g_nJOBNUM,sSTEP_NAME,i_nJOHOKBN,i_sSQLCODE,i_sSQLERRM,sLOGMSG,i_TANTOCODE,i_WSNUM);
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.muzl 2024/06/14
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
    --  作成者／作成日: ZCZL.muzl 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
    BEGIN
        -- 基準日
        g_vJYOUKEN := KKBPK5551.GETPARMS(g_nJOBNUM,'txtBaseDateYmd');
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
    --  バージョン    : Ver 0.3.000.00
    --  作成者／作成日: ZCZL.muzl 2024/06/13
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.muzl 2025/06/13
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
        VMSG                          NVARCHAR2(4000);
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

        -- 処理結果を空白で初期化する。
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--        o_vRESULT := '';
        VMSG := '';
       --基準日の日付チェック
        bRTN := kKAPK0010.FISNUMERIC(g_vJYOUKEN);
        IF NOT bRTN THEN
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.001:8月1日認識合わせの横展開
--            VMSG := o_vRESULT || ',99999,基準日が正しくありません。,;' ;
            VMSG := g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;' ;
        ELSE
            bRTN := KKAPK0020.FISDATEW(g_vJYOUKEN);
            IF NOT bRTN THEN
               VMSG := g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
            END IF;
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE END
        END IF ;
--  2024/09/04 ZCZL.LIUCHANGQUAN DELETE START 0.3.000.001:8月1日認識合わせの横展開
--        bRTN := KKAPK0020.FISDATEW(g_vJYOUKEN);
--        IF bRTN <> TRUE THEN
--            VMSG := o_vRESULT || g_sMESSAGE ;
--        END IF ;
--  2024/09/04 ZCZL.LIUCHANGQUAN DELETE END
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD START 0.3.000.001:8月1日認識合わせの横展開
        IF VMSG IS NOT NULL THEN
          o_vRESULT := VMSG;
        END IF;
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD END

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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.muzl 2024/06/14
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;          --戻り値
        sSQL                          VARCHAR2(5000);
        nRTN                          INTEGER;          --戻り値
        rGABTATENAKIHON               GABTATENAKIHON%ROWTYPE;  -- 児童生徒の宛名基本
        rGABTSOFUSAKI                 GABTSOFUSAKI%ROWTYPE;    -- 児童生徒の送付先基本
        rGABTATENAKIHON1              GABTATENAKIHON%ROWTYPE;  -- 保護者の宛名基本
        rGABTSOFUSAKI1                GABTSOFUSAKI%ROWTYPE;    -- 保護者の送付先基本
        rGKBWL713R001                 GKBWL713R001%ROWTYPE;    -- 原級留置対象者一覧ワーク
        sMEISHO                       NVARCHAR2(1000);         --名称
        sMEISHOKANA                   NVARCHAR2(1000);         --名称カナ
        sYOBI                         NVARCHAR2(1000);         --予備
        vZOKUGARAMEI                  NVARCHAR2(1000);         --続柄名称
        nIHERR                        PLS_INTEGER;             --エラーコード
        sKOKUMEI_KANA                 NVARCHAR2(1000);         --国名カナ
        sKOKUMEI                      NVARCHAR2(1000);         --国名
        sKOKUMEI_ALPHABET             NVARCHAR2(1000);         --国名アルファベット
        TYPE MC_CURSOR IS REF         CURSOR;                  --カーソルタイプ定義
        cCURSOR                       MC_CURSOR;
    BEGIN

     IF g_rJSTP.Chohyoid = 'GKB713R001' THEN
      -- 学齢簿から児童生徒の情報を取得する学齢簿カーソル
      sSQL := '';
      sSQL := 'SELECT KOJIN_NO             '; 
      sSQL := sSQL || ',SEIBETSU             '; 
      sSQL := sSQL || ',HOGOSYA_ZOKUGARA1    '; 
      sSQL := sSQL || ',HOGOSYA_ZOKUGARA2    '; 
      sSQL := sSQL || ',HOGOSYA_ZOKUGARA3    '; 
      sSQL := sSQL || ',HOGOSYA_ZOKUGARA4    '; 
      sSQL := sSQL || ',SYOGAKO_CD           '; 
      sSQL := sSQL || ',TYUGAKO_CD           '; 
      sSQL := sSQL || ',KUIKIGAI_CD          '; 
      sSQL := sSQL || ',KUNISHIRITSU_CD      '; 
      sSQL := sSQL || ',YOGOGAKO_CD          '; 
      sSQL := sSQL || ',GAKKO_KBN_CD         '; 
      sSQL := sSQL || ',TENNYUMAE_GAKKO_KBN  '; 
      sSQL := sSQL || ',GAKUNEN              '; 
      sSQL := sSQL || ',GENKYURYUCHI_KETTEI_BI'; 
      sSQL := sSQL || ',GENKYURYUCHI_KAISI_BI'; 
      sSQL := sSQL || ',GENKYURYUCHI_SYURYOBI'; 
      sSQL := sSQL || ',GENKYURYUCHI_RIYU    '; 
      sSQL := sSQL || ',SEIBETSU             '; 
      sSQL := sSQL || ',HOGOSYA_KOJIN_NO     ';
      sSQL := sSQL || ' FROM GKBTGAKUREIBO   '; 
      sSQL := sSQL || ' WHERE SAISHIN_KBN = 0 '; 
      sSQL := sSQL || ' AND GEN_NENGAPI = 0 '; 
      sSQL := sSQL || ' AND SAKUJO_FLG = 0 '; 
      sSQL := sSQL || ' AND GENKYURYUCHI_KAISI_BI <= ' || g_vBASEDATEYMD ; 
      sSQL := sSQL || ' AND GENKYURYUCHI_SYURYOBI >= ' || g_vBASEDATEYMD ; 
      OPEN cCURSOR FOR sSQL;
        LOOP
          FETCH cCURSOR INTO rGKBTGAKUREIBO.KOJIN_NO
                             ,rGKBTGAKUREIBO.SEIBETSU
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA1
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA2
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA3
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA4
                             ,rGKBTGAKUREIBO.SYOGAKO_CD
                             ,rGKBTGAKUREIBO.TYUGAKO_CD
                             ,rGKBTGAKUREIBO.KUIKIGAI_CD
                             ,rGKBTGAKUREIBO.KUNISHIRITSU_CD
                             ,rGKBTGAKUREIBO.YOGOGAKO_CD
                             ,rGKBTGAKUREIBO.GAKKO_KBN_CD
                             ,rGKBTGAKUREIBO.TENNYUMAE_GAKKO_KBN
                             ,rGKBTGAKUREIBO.GAKUNEN
                             ,rGKBTGAKUREIBO.GENKYURYUCHI_KETTEI_BI
                             ,rGKBTGAKUREIBO.GENKYURYUCHI_KAISI_BI
                             ,rGKBTGAKUREIBO.GENKYURYUCHI_SYURYOBI
                             ,rGKBTGAKUREIBO.GENKYURYUCHI_RIYU
                             ,rGKBTGAKUREIBO.SEIBETSU
                             ,rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO;
          EXIT WHEN cCURSOR%NOTFOUND;
          rGKBWGENKYURYUCHI := NULL;
          rGKBWGENKYURYUCHI.SYS_SAKUSEIBI        := KKAPK0020.FDateFmt(TO_CHAR(SYSDATE,'YYYY/MM/DD'),12);     -- 作成日

          -- 児童生徒の基本情報
          nRTN := GAAPK0030.FGETATENA(rGKBTGAKUREIBO.KOJIN_NO,'GKB',TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),rGABTATENAKIHON,rGABTSOFUSAKI);
          rGKBWGENKYURYUCHI.JIDO_SHIMEI_KANA     := rGABTATENAKIHON.SHIMEI_KANA;     -- 児童生徒氏名カナ
          rGKBWGENKYURYUCHI.JIDO_SHIMEI_KANJI    := rGABTATENAKIHON.SHIMEI_KANJI;    -- 児童生徒氏名

          -- 保護者の基本情報
          nRTN := GAAPK0030.FGETATENA(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO,'GKB',TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),rGABTATENAKIHON1,rGABTSOFUSAKI1);
          rGKBWGENKYURYUCHI.HOGOSHA_SHIMEI_KANA  := rGABTATENAKIHON1.SHIMEI_KANA;    -- 保護者氏名カナ
          rGKBWGENKYURYUCHI.HOGOSHA_SHIMEI_KANJI := rGABTATENAKIHON1.SHIMEI_KANJI;   -- 保護者氏名

          rGKBWGENKYURYUCHI.SEINENGAPI           := rGABTATENAKIHON.HYOJI_SEINENGAPI;     -- 生年月日

          --性別名取得
          IF KKAPK0030.FCDGetR('GKB', '021', '0001', rGKBTGAKUREIBO.SEIBETSU, sMEISHO, sMEISHOKANA, sYOBI) = 0 THEN
            rGKBWGENKYURYUCHI.SEIBETSU             := sMEISHO;     -- 性別
          END IF;

          --柄名称取得
          nRTN := GKBFKZKGMGET(2, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA1, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA2, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA3, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA4, vZOKUGARAMEI, nIHERR);
          IF nRTN = 0 THEN
            rGKBWGENKYURYUCHI.JIDO_KANKEI          := vZOKUGARAMEI;     -- 児童生徒との関係
          END IF;

          --国名取得
          nRTN := GKAFKKKMGET(rGABTATENAKIHON.KOKUSEKI_CD, sKOKUMEI_KANA, sKOKUMEI, sKOKUMEI_ALPHABET);
          rGKBWGENKYURYUCHI.JIDO_KOKUSEKI        := sKOKUMEI;     -- 児童生徒国籍
          nRTN := GKAFKKKMGET(rGABTATENAKIHON1.KOKUSEKI_CD, sKOKUMEI_KANA, sKOKUMEI, sKOKUMEI_ALPHABET);
          rGKBWGENKYURYUCHI.HOGOSHA_KOKUSEKI     := sKOKUMEI;     -- 保護者国籍

          rGKBWGENKYURYUCHI.GAKKO_KBN_CD         := rGKBTGAKUREIBO.GAKKO_KBN_CD;     -- 学校区分コード

          IF rGKBTGAKUREIBO.GAKKO_KBN_CD = 1 THEN
            rGKBWGENKYURYUCHI.GAKKO_CD           := rGKBTGAKUREIBO.SYOGAKO_CD;      -- 学校コード
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 2 THEN
            rGKBWGENKYURYUCHI.GAKKO_CD           := rGKBTGAKUREIBO.TYUGAKO_CD;      -- 学校コード
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 3 THEN
            rGKBWGENKYURYUCHI.GAKKO_CD           := rGKBTGAKUREIBO.YOGOGAKO_CD;     -- 学校コード
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 4 THEN
            rGKBWGENKYURYUCHI.GAKKO_CD           := rGKBTGAKUREIBO.KUIKIGAI_CD;     -- 学校コード
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 5 THEN
            rGKBWGENKYURYUCHI.GAKKO_CD           := rGKBTGAKUREIBO.KUNISHIRITSU_CD; -- 学校コード
          ELSE
            NULL;
          END IF;
          rGKBWGENKYURYUCHI.GAKOMEI              := GKAFKGKOGTEQ(rGKBWGENKYURYUCHI.GAKKO_KBN_CD,rGKBWGENKYURYUCHI.GAKKO_CD);     -- 学校名
          rGKBWGENKYURYUCHI.GAKUNEN              := rGKBTGAKUREIBO.GAKUNEN ;     -- 学年
--  2024/11/02 ZCZL.WANGYUNING UPDATE START 0.3.000.002:IT_GKB_00286横展開対応
          --rGKBWGENKYURYUCHI.KETTEI_BI            := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(rGKBTGAKUREIBO.GENKYURYUCHI_KETTEI_BI),'YYYY/MM/DD'),1);     -- 決定年月日
          --rGKBWGENKYURYUCHI.KAISI_BI             := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(rGKBTGAKUREIBO.GENKYURYUCHI_KAISI_BI),'YYYY/MM/DD'),1);     -- 開始年月日
          --rGKBWGENKYURYUCHI.SYURYOBI             := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(rGKBTGAKUREIBO.GENKYURYUCHI_SYURYOBI),'YYYY/MM/DD'),1);     -- 終了年月日
          rGKBWGENKYURYUCHI.KETTEI_BI            := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(rGKBTGAKUREIBO.GENKYURYUCHI_KETTEI_BI),1);     -- 決定年月日
          rGKBWGENKYURYUCHI.KAISI_BI             := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(rGKBTGAKUREIBO.GENKYURYUCHI_KAISI_BI),1);     -- 開始年月日
          rGKBWGENKYURYUCHI.SYURYOBI             := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(rGKBTGAKUREIBO.GENKYURYUCHI_SYURYOBI),1);     -- 終了年月日
--  2024/11/02 ZCZL.WANGYUNING UPDATE END
          IF KKAPK0030.FCDGetR('GKB', '030', '0001', rGKBTGAKUREIBO.GENKYURYUCHI_RIYU, sMEISHO, sMEISHOKANA, sYOBI) = 0 THEN
            rGKBWGENKYURYUCHI.RIYU                 := sMEISHO;     -- 理由
          END IF;
          rGKBWGENKYURYUCHI.JIDO_KOJIN_NO        := rGKBTGAKUREIBO.KOJIN_NO;     -- 児童宛名番号（ソート用）
          rGKBWGENKYURYUCHI.SEIBETSU_SORT        := rGKBTGAKUREIBO.SEIBETSU;     -- 性別（ソート用）

          --登録中間ワークテーブル
 
              INSERT INTO GKBWGENKYURYUCHI VALUES rGKBWGENKYURYUCHI;

          END LOOP;
      CLOSE cCURSOR;
      
       -- 初期処理
      nCOUNT := GKBFKTBLCNT('GKBWGENKYURYUCHI',NULL);
      
      -- 中間ワークからデータを取得
      sSQL := '';
      sSQL := 'SELECT * FROM GKBWGENKYURYUCHI '; 
      IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL OR KKAPK0010.FTrim(g_rJSTP.Orderbyclause) <> '' THEN
        sSQL := sSQL || ' ORDER BY ' || g_rJSTP.Orderbyclause ;
      END IF; 
      OPEN cCURSOR FOR sSQL;
        LOOP
          FETCH cCURSOR INTO rGKBWGENKYURYUCHI;
          EXIT WHEN cCURSOR%NOTFOUND;
          g_nSORT := g_nSORT + 1;
          rGKBWL713R001.NO := g_nSORT;                                                    -- ソート順
          rGKBWL713R001.SYS_SAKUSEIBI         := rGKBWGENKYURYUCHI.SYS_SAKUSEIBI;         -- 作成日
          rGKBWL713R001.SHIMEI_KANA           := rGKBWGENKYURYUCHI.JIDO_SHIMEI_KANA;      -- 児童生徒氏名カナ
          rGKBWL713R001.SHIMEI_KANJI          := rGKBWGENKYURYUCHI.JIDO_SHIMEI_KANJI;          -- 児童生徒氏名
          rGKBWL713R001.HOGOSHA_SHIMEI_KANA   := rGKBWGENKYURYUCHI.HOGOSHA_SHIMEI_KANA;   -- 保護者氏名カナ
          rGKBWL713R001.HOGOSHA_SHIMEI_KANJI  := rGKBWGENKYURYUCHI.HOGOSHA_SHIMEI_KANJI;  -- 保護者氏名
          rGKBWL713R001.SEINENGAPI            := rGKBWGENKYURYUCHI.SEINENGAPI;            -- 生年月日
          rGKBWL713R001.SEIBETSU              := rGKBWGENKYURYUCHI.SEIBETSU;              -- 性別
          rGKBWL713R001.JIDO_KANKEI           := rGKBWGENKYURYUCHI.JIDO_KANKEI;           -- 児童生徒との関係
          rGKBWL713R001.JIDO_KOKUSEKI         := rGKBWGENKYURYUCHI.JIDO_KOKUSEKI;         -- 児童生徒国籍
          rGKBWL713R001.HOGOSHA_KOKUSEKI      := rGKBWGENKYURYUCHI.HOGOSHA_KOKUSEKI;      -- 保護者国籍
          rGKBWL713R001.GAKOMEI               := rGKBWGENKYURYUCHI.GAKOMEI;               -- 学校名
          rGKBWL713R001.GAKUNEN               := GKAFKGKNGTEQ(rGKBWGENKYURYUCHI.GAKUNEN); -- 学年
          rGKBWL713R001.KETTEI_BI             := rGKBWGENKYURYUCHI.KETTEI_BI;             -- 決定年月日
          rGKBWL713R001.KAISI_BI              := rGKBWGENKYURYUCHI.KAISI_BI;              -- 開始年月日
          rGKBWL713R001.SYURYOBI              := rGKBWGENKYURYUCHI.SYURYOBI;              -- 終了年月日
          rGKBWL713R001.RIYU                  := rGKBWGENKYURYUCHI.RIYU;                  -- 理由
          rGKBWL713R001.BREAK_NO              := CEIL(g_nSORT/10);                         -- 改ページキー
          rGKBWL713R001.WSNUM                 := g_sWSNUM;                                -- 端末番号
          rGKBWL713R001.BATCHKBN              := 2;                                       -- 即時バッチ区分
          rGKBWL713R001.JOBNUM                := g_nJOBNUM;                               -- ジョブNO
          --登録ワークテーブル
           
             INSERT INTO GKBWL713R001 VALUES rGKBWL713R001;
          
          nCOUNT1 := nCOUNT1 + 1;       -- CSV出力件数
        END LOOP;
      CLOSE cCURSOR;
      END IF;

      --抑止対象者一覧対象件数
      g_nINDEX := g_nINDEX + 1;
      g_oKENSU_LIST.EXTEND(1);
      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT,'入力 原級留置対象者一覧対象件数',1);
      --抑止対象者一覧対象件数
      g_nINDEX := g_nINDEX + 1;
      g_oKENSU_LIST.EXTEND(1);
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT1,'出力  原級留置対象者一覧ＣＳＶ',1);
      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT1,'出力  原級留置対象者一覧ＣＳＶ',2);
       --関数終了
      bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV作成処理', 0, '', '', '原級留置対象者一覧ＣＳＶ' || nCOUNT1 ||'件を出力しました', g_sTANTOCODE, g_sWSNUM, 1);
      RETURN TRUE;

    EXCEPTION
        WHEN OTHERS THEN
            IF cCURSOR%ISOPEN THEN
            CLOSE cCURSOR;
            END IF;
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 1, SQLCODE, SQLERRM, 'ＣＳＶファイルの書き出し処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_CSV_CREATE;
    --------------------------------------------------------
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.muzl 2024/06/14
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
        bRTN := KKBPK5551.FCSVPUT (g_nJOBNUM,g_sGYOUMUCODE,g_sWSNUM,c_BATCH,i_TBLNAME,g_rJSTP.CHOHYOID,g_rJSTP.CHOHYOFORM,g_rJSTP.PRTFILEKBN,g_rJSTP.TEIKEIBUNNUM_LIST,nCSV_RCNT,sCSVFILENAME,sPRTFILENAME);

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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.muzl 2024/06/13
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
    --  機能概要      : 条件取得処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.muzl 2024/06/13
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET
        RETURN BOOLEAN
    IS
    BEGIN

        -- 処理条件の日付を西暦変換する。
        g_vBASEDATEYMD := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD 0.3.000.001:8月1日認識合わせの横展開
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JYOKEN_GET', 1, SQLCODE, SQLERRM, '処理条件の取得が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_JYOKEN_GET;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.muzl 2024/06/13
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        eException       EXCEPTION;
        IRTN             NUMBER;   --戻り値
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        -- 条件取得処理を呼び出す。
        bRTN := FUNC_JYOKEN_GET;
        IF NOT bRTN THEN
            RAISE eException;
        END IF;

        -- 初期処理
        -- 原級留置対象者一覧中間ワークファイルをクリアする。
        IRTN := KKAPK3000.FTRUNCATE( 'GKBWGENKYURYUCHI', VSQLERRM );
        IF IRTN <> 0 THEN
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('中間ファイル削除処理が異常終了しました。' || VSQLERRM, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '初期処理が異常終了しました', g_sTANTOCODE, g_sWSNUM, 1);
          RAISE eException;
        END IF;

        -- 原級留置対象者一覧ワークテーブル初期化
        CASE g_rJSTP.CHOHYOID 
          WHEN 'GKB713R001' THEN
           DELETE FROM GKBWL713R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
        ELSE
           NULL;
        END CASE;
        
        -- ＣＳＶファイル作成処理
        bRTN := FUNC_CSV_CREATE;
        IF bRTN <> TRUE THEN
          RAISE eException;
        END IF;

        -- CSV出力処理を呼び出す
        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB713R001' THEN
            bRTN := FUNC_B11CSV('GKBWL713R001');
          ELSE
            NULL;
        END CASE;

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
    --  作成者／作成日: ZCZL.muzl 2024/06/14
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
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新表処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
    END FUNC_B20UPDATE1;
    --------------------------------------------------------
    --  機能概要      : バッチ処理の呼出
    --                 指定した期限内の原級留置対象者一覧表を作成する。
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_nRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.muzl 2024/06/14
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

    EXCEPTION
        WHEN ePRMEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
        WHEN eSHORIEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
        WHEN OTHERS THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;

    END PBATCH;
END GKBPB00620;
/
