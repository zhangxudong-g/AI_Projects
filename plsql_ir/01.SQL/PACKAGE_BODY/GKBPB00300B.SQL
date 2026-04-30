CREATE OR REPLACE PACKAGE BODY GKBPB00300
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 成人式重複者チェックリスト
--  機能概要   : 成人式重複者チェックリストを作成する
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
--------------------------------------------------------
--  変更履歴
--  2024/04/18 ZCZL.WUCAO Update 0.2.000.001:512_GKB_00017対応
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00027対応
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

    --パラメータ変数
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
    CURSOR CSEIJINSYA(p_NENDO IN NUMBER,
                      p_IKBN  IN PLS_INTEGER,
                      p_ISANTEIDANTAI_CD IN PLS_INTEGER
                      ) IS
      SELECT SEIJIN.NENDO,
             SEIJIN.SEIRI_NO,
             SEIJIN.KOJIN_CD,
             SEIJIN.SHIMEI_KANA,
             SEIJIN.SHIMEI_KANJI,
             SEIJIN.SEINENGAPI,
             SEIJIN.SEIBETU,
             SEIJIN.TYUGAKO_KU,
             SEIJIN.GYOSEI_KU,
             SEIJIN.YUBIN_NO,
             SEIJIN.CHOMEI,
             SEIJIN.BANCHI,
             SEIJIN.KATAGAKI,
             SEIJIN.TEL_NO,
             SEIJIN.SANTEIDANTAI_CD,
             SEIJIN.SYUKETSU_KBN,
             SEIJIN.SHOGAKO_KU,
             SEIJIN.SHOGAKO_KU_CD,
             SEIJIN.TYUGAKO_KU_CD,
             SEIJIN.GYOSEI_KU_CD
        FROM GKBTSEIJINSHA  SEIJIN,
       --氏名かな（名部分のみ）・生年月日でGKBWSEIJINSHAJUFUKUより抽出
             (SELECT NENDO
                    ,SHIMEI_KANA_HALF
                    ,SEINENGAPI
                FROM GKBWSEIJINSHAJUFUKU
               WHERE NENDO = p_NENDO
               GROUP BY NENDO,SHIMEI_KANA_HALF, SEINENGAPI
              HAVING COUNT(*) > 1) JUFUKU,
             GKBWSEIJINSHAJUFUKU WK_SEIJIN
       WHERE WK_SEIJIN.NENDO            = JUFUKU.NENDO
         AND WK_SEIJIN.SHIMEI_KANA_HALF = JUFUKU.SHIMEI_KANA_HALF
         AND WK_SEIJIN.SEINENGAPI       = JUFUKU.SEINENGAPI
         AND SEIJIN.NENDO               = WK_SEIJIN.NENDO
         AND SEIJIN.SHIMEI_KANA         = WK_SEIJIN.SHIMEI_KANA
         AND SEIJIN.SEINENGAPI          = WK_SEIJIN.SEINENGAPI
         AND SEIJIN.SEIRI_NO            = WK_SEIJIN.SEIRI_NO
         AND SEIJIN.SANTEIDANTAI_CD     = DECODE(p_ISANTEIDANTAI_CD, 0, SEIJIN.SANTEIDANTAI_CD, p_ISANTEIDANTAI_CD)
         AND SEIJIN.SYUKETSU_KBN        = DECODE(p_IKBN, 1, 1, 2, 0, SEIJIN.SYUKETSU_KBN)
         ;
    -----------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- 処理結果
    c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    c_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし
    -- 戻り値
    c_BOK          CONSTANT  BOOLEAN := TRUE;          -- 正常
    -- 正常メッセージの値
    c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '成人式重複者チェックリスト作成処理が正常終了しました。';
    -- エラーメッセージの値
    c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '成人式重複者チェックリスト作成処理が異常終了しました。';
    -- 成人者マスタ
    c_VTABLE       CONSTANT  NVARCHAR2(128) := 'GKBWSEIJINSHA';
    c_VTABLE2      CONSTANT  NVARCHAR2(128) := 'GKBWSEIJINSHAJUFUKU';

    -- コード条件テーブルを見る際の分類コード
    c_IBUNRUI_GENZON_KBN   CONSTANT PLS_INTEGER := 1;   -- 現存区分
    c_IBUNRUI_JINKAKU_KBN  CONSTANT PLS_INTEGER := 2;   -- 人格区分

    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    -- ERROR関連 --
    V_SQL_MSG      NVARCHAR2(255);     -- SQLエラーメッセージ

    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    B_RTN                     BOOLEAN;
    I_RTN                     PLS_INTEGER;
    -- 処理条件（画面からの引数）
    g_MJYOUKEN01              NVARCHAR2(100);
    g_MJYOUKEN02              NVARCHAR2(100);
    g_MJYOUKEN03              NVARCHAR2(100);
    I_JKN_NENDO               PLS_INTEGER;   -- 年度
    I_JKN_SAKUSEI_KBN         PLS_INTEGER;   -- 作成区分
    I_JKN_SANTEIDANTAI_CD     PLS_INTEGER;   -- 算定団体コード
    I_SYSDATE                 PLS_INTEGER;   -- 作成日

    -- 取得したデータのワーク領域
    TYPE MT_JIDO_TYPE IS TABLE OF GKBWSEIJINSHA%ROWTYPE INDEX BY BINARY_INTEGER;
    M_JIDO_WORK MT_JIDO_TYPE;

    I_NENDO          PLS_INTEGER;
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        v_cmbSakuseiKbn                DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        g_MJYOUKEN01 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNendo');                --対象年度
        v_cmbSakuseiKbn  := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbSakuseiKbn');
        g_MJYOUKEN02 := v_cmbSakuseiKbn(1);                                      --作成区分
        g_MJYOUKEN03 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSanteiDantai');         --算定団体

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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
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
    ----------------------------------------------------------------------------------------------------
    --年度チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCNENDOCHK(i_VNENDO IN NVARCHAR2) RETURN
      PLS_INTEGER
    IS
      IFRTN     PLS_INTEGER;
      INENDO    NUMBER;
    BEGIN
      IFRTN := c_ISUCCESS;

      --対象年度
      BEGIN
        INENDO := KKAPK0020.FNENDO(i_VNENDO, 1);
        IF NVL(INENDO, 0) = 0 THEN
          IFRTN := c_INOT_SUCCESS;
        END IF;

      EXCEPTION
        WHEN OTHERS THEN
          IFRTN := c_INOT_SUCCESS;
      END;

      RETURN IFRTN;
    END FUNCNENDOCHK;
    ----------------------------------------------------------------------------------------------------
    --作成区分チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCKUBUNCHK(i_VKUBUN IN NVARCHAR2)
      RETURN PLS_INTEGER
    IS
      IFRTN     PLS_INTEGER;
    BEGIN
      IFRTN := c_ISUCCESS;

      BEGIN
        IF TO_NUMBER(i_VKUBUN) NOT IN (1, 2, 3) THEN
          IFRTN := c_INOT_SUCCESS;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IFRTN := c_INOT_SUCCESS;
      END;

      RETURN IFRTN;
    END FUNCKUBUNCHK;
    ----------------------------------------------------------------------------------------------------
    --数値チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCNUMCHK(i_VNUM IN NVARCHAR2)
      RETURN PLS_INTEGER
    IS
      IFRTN     PLS_INTEGER;
      INUM   PLS_INTEGER;
    BEGIN
      IFRTN := c_ISUCCESS;

      BEGIN
        INUM := TO_NUMBER(i_VNUM);
      EXCEPTION
        WHEN OTHERS THEN
          IFRTN := c_INOT_SUCCESS;
      END;

      RETURN IFRTN;
    END FUNCNUMCHK;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
        IRTN                          NUMBER;
        o_MESSAGE                     NVARCHAR2(4000);
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

        o_MESSAGE := NULL;
        IRTN := 0;

        --条件１のチェック
        IRTN := FUNCNENDOCHK(g_MJYOUKEN01);
        IF IRTN <> c_ISUCCESS THEN
          o_MESSAGE := o_MESSAGE || 'GKB,99999,対象年度が正しくありません。,;';
        END IF;

        --条件２のチェック
        IRTN := FUNCKUBUNCHK(g_MJYOUKEN02);
        IF IRTN <> c_ISUCCESS THEN
          o_MESSAGE := o_MESSAGE || 'GKB,99999,作成区分が正しくありません。,;';
        END IF;

        --条件３のチェック
        IRTN := FUNCNUMCHK(g_MJYOUKEN03);
        IF IRTN <> c_ISUCCESS THEN
          o_MESSAGE := o_MESSAGE || 'GKB,99999,算定団体コードが正しくありません。,;';
        END IF;

        o_vRESULT := o_MESSAGE;

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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
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
    --------------------------------------------------------------------------------
    -- 日付変換
    --------------------------------------------------------------------------------
    FUNCTION FUNC_CONV_DATE(i_IDATE IN PLS_INTEGER, I_ICONV_TYPE IN PLS_INTEGER)
      RETURN NVARCHAR2
    IS
      V_FRTN    NVARCHAR2(16);

      -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
      io_IWAREKIHIZUKE  PLS_INTEGER;
      io_ISEIREKIHIZUKE PLS_INTEGER;
      o_VEDIT_GYYMMDD1  NVARCHAR2(9);
      o_VEDIT_GYYMMDD2  NVARCHAR2(9);
      o_VEDIT_GYYMMDD3  NVARCHAR2(11);
      o_VKJ_GENGO       NVARCHAR2(2);
      o_VKG_GENGO       NVARCHAR2(1);
      o_IWAREKI_YY      PLS_INTEGER;
      o_ISEIREKI_YYYY   PLS_INTEGER;
      o_IWAREKI_GYYMM   PLS_INTEGER;
      o_IMM             PLS_INTEGER;
      o_IDD             PLS_INTEGER;
      o_IWAREKIHIZUKE   PLS_INTEGER;
      o_ISEIREKIHIZUKE  PLS_INTEGER;

    BEGIN
      V_FRTN := NULL;

      BEGIN
        IF i_IDATE >= 10000000 THEN
          io_IWAREKIHIZUKE  := 0;
          io_ISEIREKIHIZUKE := i_IDATE;
        ELSE
          io_IWAREKIHIZUKE  := i_IDATE;
          io_ISEIREKIHIZUKE := 0;
        END IF;

        --日付変換
        B_RTN := KKAPK0020.FDAYEDIT(io_IWAREKIHIZUKE, io_ISEIREKIHIZUKE,
                                     o_VEDIT_GYYMMDD1, o_VEDIT_GYYMMDD2, o_VEDIT_GYYMMDD3,
                                     o_VKJ_GENGO, o_VKG_GENGO,
                                     o_IWAREKI_YY, o_ISEIREKI_YYYY, o_IWAREKI_GYYMM,
                                     o_IMM, o_IDD, o_IWAREKIHIZUKE, o_ISEIREKIHIZUKE);
        IF B_RTN = c_BOK THEN
          CASE I_ICONV_TYPE
            WHEN 0 THEN
              V_FRTN := RTRIM(LTRIM(TO_CHAR(o_ISEIREKIHIZUKE)));
            WHEN 1 THEN
              V_FRTN := o_VEDIT_GYYMMDD1;
            WHEN 2 THEN
              V_FRTN := o_VEDIT_GYYMMDD2;
            WHEN 3 THEN
              V_FRTN := o_VEDIT_GYYMMDD3;
            ELSE
              NULL;
          END CASE;
        END IF;
      END;
      RETURN V_FRTN;
    END FUNC_CONV_DATE;
    -----------------------------------------------------------------
    -- 成人者重複ワークデータを作成
    -----------------------------------------------------------------
    FUNCTION FUNC_WK_JUFUKU_CREATE(p_NENDO IN PLS_INTEGER
                                  ,p_IKBN  IN PLS_INTEGER
                                  ,p_ISANTEIDANTAI_CD IN PLS_INTEGER)RETURN PLS_INTEGER
    IS

      IRTN  PLS_INTEGER;

    BEGIN
        IRTN := 0;

        BEGIN
          INSERT INTO GKBWSEIJINSHAJUFUKU
            SELECT NENDO,
                   SEIRI_NO,
                   KOJIN_CD,
                   SHIMEI_KANA,
                   --氏名かなの空白スペース以降の文字（”名”部分）をセットする
                   SUBSTR(SHIMEI_KANA, INSTR(SHIMEI_KANA,'　') + 1 , LENGTH(SHIMEI_KANA) - INSTR(SHIMEI_KANA,'　')) SHIMEI_KANA_HALF,
                   SEINENGAPI,
                   SANTEIDANTAI_CD
              FROM GKBTSEIJINSHA
             WHERE NENDO = p_NENDO
               AND SANTEIDANTAI_CD = DECODE(p_ISANTEIDANTAI_CD, 0, SANTEIDANTAI_CD, p_ISANTEIDANTAI_CD)
               AND SYUKETSU_KBN = DECODE(p_IKBN, 1, 1, 2, 0, SYUKETSU_KBN);

        EXCEPTION
          WHEN OTHERS THEN
            IRTN := 9;
        END;

        RETURN IRTN;
    END FUNC_WK_JUFUKU_CREATE;
    --------------------------------------------------------------------------------
    -- 成人式重複者チェックリストワーク中間（GKBWSEIJINSHA）レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
      I_FRTN               PLS_INTEGER;      -- 戻り値
      I_CNT                BINARY_INTEGER;   -- ワークテーブル格納用配列インデックス
      V_HYOJI_NENDO        NVARCHAR2(8);     -- 表示用年度
      V_SAKUSEI_BI         NVARCHAR2(11);

      -- 宛名情報取得用
      R_SEIJINSYA_ATENA    GABTATENAKIHON%ROWTYPE;  -- 成人者宛名
      R_SEIJINSYA_SOFU     GABTSOFUSAKI%ROWTYPE;    -- 成人者送付先
      R_NUSHI_ATENA        GABTATENAKIHON%ROWTYPE;  -- 世帯主用宛名
      R_NUSHI_SOFU         GABTSOFUSAKI%ROWTYPE;    -- 世帯主用送付先

      -- 世帯主情報取得用
      N_NUSHI_KOJIN_NO     NUMBER;        -- 世帯主個人番号
      V_NUSHI_SHIMEI_KANA  NVARCHAR2(100); -- 世帯主氏名かな
      V_NUSHI_SHIMEI_KANJI NVARCHAR2(100); -- 世帯主氏名漢字

      I_KISAI_JUNI         PLS_INTEGER;   -- 記載順位
      V_ZOKUGARA_MEI       NVARCHAR2(30); -- 続柄名
      nRTN                 NUMBER;
      o_sMEISHO            NVARCHAR2(100);
      o_sMEISHOKANA        NVARCHAR2(100);
      o_sYOBI              NVARCHAR2(100);

    BEGIN
      I_FRTN := c_INOTFOUND;             -- 該当なし

      -- 対象年度を西暦に変換
      V_HYOJI_NENDO := KKAPK0020.FNENDOEDIT(1, I_NENDO, 3);
      V_SAKUSEI_BI  := FUNC_CONV_DATE(I_SYSDATE, 3);

      -- ワーク領域の初期化
      M_JIDO_WORK.DELETE;
      I_CNT := 0;

      -- 処理条件の年度に該当する成人者を検索
      BEGIN
        FOR CRSEIJINSYA IN CSEIJINSYA(I_NENDO,
                                      I_JKN_SAKUSEI_KBN,
                                      I_JKN_SANTEIDANTAI_CD
                                      ) LOOP

          N_NUSHI_KOJIN_NO := 0;
          V_NUSHI_SHIMEI_KANA  := ' ';
          V_NUSHI_SHIMEI_KANJI := ' ';
          V_ZOKUGARA_MEI := ' ';
          I_KISAI_JUNI := 0;

          R_SEIJINSYA_ATENA := NULL;
          R_SEIJINSYA_SOFU := NULL;
          R_NUSHI_ATENA := NULL;
          R_NUSHI_SOFU := NULL;

          IF CRSEIJINSYA.KOJIN_CD > 0 THEN
            I_RTN := GAAPK0030.FGETATENA(CRSEIJINSYA.KOJIN_CD,
                                       'GKB',
                                       I_SYSDATE,
                                       R_SEIJINSYA_ATENA,
                                       R_SEIJINSYA_SOFU);

            -- 個人番号より住基異動の続柄名・記載順位取得
            BEGIN
              SELECT ZOKUGARA_MEI,
                     KISAI_JUNI
                INTO V_ZOKUGARA_MEI,
                     I_KISAI_JUNI
                FROM GABTJUKIIDO
               WHERE KOJIN_NO = CRSEIJINSYA.KOJIN_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                NULL;
            END;

            -- 世帯主取得共通サブルーチンから世帯主名を取得する
            I_RTN := JIAPK0030.FGETNUSHI(I_SYSDATE,
                                            CRSEIJINSYA.KOJIN_CD,
                                            N_NUSHI_KOJIN_NO,
                                            V_NUSHI_SHIMEI_KANJI);
            --世帯主が取得できたとき
            --I_RTN = 0(現存世帯主)、= 8(喪失世帯主)
            IF I_RTN IN (0,8) THEN
               -- 世帯主の宛名情報を取得
              I_RTN := GAAPK0030.FGETATENA(N_NUSHI_KOJIN_NO,
                                         'GKB',
                                         I_SYSDATE,
                                         R_NUSHI_ATENA,
                                         R_NUSHI_SOFU);
              V_NUSHI_SHIMEI_KANA := R_NUSHI_ATENA.SHIMEI_KANA;
            END IF;
          END IF;

          --成人者マスタの内容をセット
          --中学校区／小学校区
          M_JIDO_WORK(I_CNT).CHUGAKOKU_CD := CRSEIJINSYA.TYUGAKO_KU_CD;
          M_JIDO_WORK(I_CNT).CHUGAKOMEI   := CRSEIJINSYA.TYUGAKO_KU;
          M_JIDO_WORK(I_CNT).SHOGAKOKU_CD := CRSEIJINSYA.SHOGAKO_KU_CD;
          M_JIDO_WORK(I_CNT).SHOGAKOMEI   := CRSEIJINSYA.SHOGAKO_KU;
          --行政区コード
          M_JIDO_WORK(I_CNT).GYOSEIKU_CD  := CRSEIJINSYA.GYOSEI_KU_CD;

          --宛名情報がある場合
          IF R_SEIJINSYA_ATENA.KOJIN_NO > 0 THEN
            M_JIDO_WORK(I_CNT).YUHEN_KBN  := R_SEIJINSYA_ATENA.YUHEN_KBN;     --郵返区分
            M_JIDO_WORK(I_CNT).OAZA_CD    := R_SEIJINSYA_ATENA.OAZA_CD;       --大字コード
            M_JIDO_WORK(I_CNT).HONBAN     := R_SEIJINSYA_ATENA.HONBAN;        --本番
            M_JIDO_WORK(I_CNT).EDABAN1    := R_SEIJINSYA_ATENA.EDABAN1;       --枝１
            M_JIDO_WORK(I_CNT).EDABAN2    := R_SEIJINSYA_ATENA.EDABAN2;       --枝２
            M_JIDO_WORK(I_CNT).EDABAN3    := R_SEIJINSYA_ATENA.EDABAN3;       --枝３
            M_JIDO_WORK(I_CNT).GAIKU    := R_SEIJINSYA_ATENA.GAIKU;           --街区
            M_JIDO_WORK(I_CNT).TOU    := R_SEIJINSYA_ATENA.TOU;               --棟
            M_JIDO_WORK(I_CNT).GOU    := R_SEIJINSYA_ATENA.GOU;               --号
            M_JIDO_WORK(I_CNT).GENZON_KBN := R_SEIJINSYA_ATENA.GENZON_KBN;    --現存区分
            nRTN  :=  KKAPK0030.FCDGetR('GKB',LPAD(c_IBUNRUI_GENZON_KBN,3,'0'),'0000',R_SEIJINSYA_ATENA.GENZON_KBN,o_sMEISHO,o_sMEISHOKANA,o_sYOBI);
            IF nRTN = 0 THEN
                M_JIDO_WORK(I_CNT).GENZON_KBN_MEI :=  o_sMEISHO;
            ELSE
                M_JIDO_WORK(I_CNT).GENZON_KBN_MEI :=  '';
            END IF;
            M_JIDO_WORK(I_CNT).JINKAKU_KBN := R_SEIJINSYA_ATENA.JINKAKU_KBN;    --人格区分
            nRTN  :=  KKAPK0030.FCDGetR('GKB',LPAD(c_IBUNRUI_JINKAKU_KBN,3,'0'),'0000',R_SEIJINSYA_ATENA.JINKAKU_KBN,o_sMEISHO,o_sMEISHOKANA,o_sYOBI);
            IF nRTN = 0 THEN
                M_JIDO_WORK(I_CNT).JINKAKU_KBN_MEI :=  o_sMEISHO;
            ELSE
                M_JIDO_WORK(I_CNT).JINKAKU_KBN_MEI :=  '';
            END IF;
            M_JIDO_WORK(I_CNT).KISAI_JUNI := I_KISAI_JUNI;      --記載順位
          ELSE
            M_JIDO_WORK(I_CNT).YUHEN_KBN  := 9;                --郵返区分
            M_JIDO_WORK(I_CNT).OAZA_CD    := 999999;             --大字コード
            M_JIDO_WORK(I_CNT).HONBAN     := '99999';            --本番
            M_JIDO_WORK(I_CNT).EDABAN1    := '99999';            --枝１
            M_JIDO_WORK(I_CNT).EDABAN2    := '99999';            --枝２
            M_JIDO_WORK(I_CNT).EDABAN3    := '99999';            --枝３
            M_JIDO_WORK(I_CNT).GAIKU      := '99999';            --街区
            M_JIDO_WORK(I_CNT).TOU        := '99999';            --棟
            M_JIDO_WORK(I_CNT).GOU        := '99999';            --号
            M_JIDO_WORK(I_CNT).GENZON_KBN := 9;                --現存区分
            M_JIDO_WORK(I_CNT).KISAI_JUNI := 99;               --記載順位
          END IF;

          M_JIDO_WORK(I_CNT).SEIRI_NO := CRSEIJINSYA.SEIRI_NO;         --整理番号
          M_JIDO_WORK(I_CNT).KOJIN_CD := CRSEIJINSYA.KOJIN_CD;         --個人番号

          M_JIDO_WORK(I_CNT).NENDO := V_HYOJI_NENDO;
          M_JIDO_WORK(I_CNT).KAIPEJI_CD := ' ';
          M_JIDO_WORK(I_CNT).KAIPEJI := ' ';
          M_JIDO_WORK(I_CNT).GYOSEIKUMEI := CRSEIJINSYA.GYOSEI_KU;
          M_JIDO_WORK(I_CNT).HAN_CD := R_SEIJINSYA_ATENA.HAN_CD;
          M_JIDO_WORK(I_CNT).HANMEI := GAAPK0030.FHANMEI(R_SEIJINSYA_ATENA.SANTEIDANTAI_CD, R_SEIJINSYA_ATENA.HAN_CD);
          M_JIDO_WORK(I_CNT).SANTEIDANTAI_CD := CRSEIJINSYA.SANTEIDANTAI_CD;
          M_JIDO_WORK(I_CNT).SANTEIDANTAIMEI := GAAPK0030.FJICHINAME2(CRSEIJINSYA.SANTEIDANTAI_CD);
          M_JIDO_WORK(I_CNT).SHIMEI_KANA := CRSEIJINSYA.SHIMEI_KANA;
          M_JIDO_WORK(I_CNT).SEINENGAPI := CRSEIJINSYA.SEINENGAPI;
          M_JIDO_WORK(I_CNT).HYOJI_SEINENGAPI := FUNC_CONV_DATE(CRSEIJINSYA.SEINENGAPI, 1);
          M_JIDO_WORK(I_CNT).SEIBETSU := CRSEIJINSYA.SEIBETU;
          CASE CRSEIJINSYA.SEIBETU
            WHEN 1 THEN
              M_JIDO_WORK(I_CNT).HYOJI_SEIBETSU := '男';
            WHEN 2 THEN
              M_JIDO_WORK(I_CNT).HYOJI_SEIBETSU := '女';
            ELSE
              NULL;
          END CASE;
          M_JIDO_WORK(I_CNT).SETAI_NO := R_SEIJINSYA_ATENA.SETAI_NO;
          M_JIDO_WORK(I_CNT).SAKUSEIBI := V_SAKUSEI_BI;
          M_JIDO_WORK(I_CNT).RENBAN := 0;
          M_JIDO_WORK(I_CNT).SHIMEI_KANJI := CRSEIJINSYA.SHIMEI_KANJI;
          M_JIDO_WORK(I_CNT).ZOKUGARAMEI := V_ZOKUGARA_MEI;

          M_JIDO_WORK(I_CNT).CHOMEI   := CRSEIJINSYA.CHOMEI;
          M_JIDO_WORK(I_CNT).BANCHI   := CRSEIJINSYA.BANCHI;
          M_JIDO_WORK(I_CNT).KATAGAKI := CRSEIJINSYA.KATAGAKI;

          M_JIDO_WORK(I_CNT).JUSHO_JODAN := SUBSTR(CRSEIJINSYA.CHOMEI||CRSEIJINSYA.BANCHI||CRSEIJINSYA.KATAGAKI,1,100);
          M_JIDO_WORK(I_CNT).JUSHO_GEDAN := SUBSTR (CRSEIJINSYA.CHOMEI||CRSEIJINSYA.BANCHI||CRSEIJINSYA.KATAGAKI,101,200);
          M_JIDO_WORK(I_CNT).NUSI_SHIMEI_KANA  := V_NUSHI_SHIMEI_KANA;
          M_JIDO_WORK(I_CNT).NUSI_SHIMEI_KANJI := V_NUSHI_SHIMEI_KANJI;

          IF CRSEIJINSYA.YUBIN_NO IS NOT NULL THEN
            M_JIDO_WORK(I_CNT).YUBIN_NO := SUBSTR(CRSEIJINSYA.YUBIN_NO,1,3)||'-'||SUBSTR(CRSEIJINSYA.YUBIN_NO,4);
          ELSE
            M_JIDO_WORK(I_CNT).YUBIN_NO := NULL;
          END IF;

          -- 宛名の住所と成人者テーブルの住所情報が違っている場合にのみ宛名住所を出力
          IF R_SEIJINSYA_ATENA.KOJIN_NO > 0 THEN
            IF NVL(CRSEIJINSYA.CHOMEI || CRSEIJINSYA.BANCHI || CRSEIJINSYA.KATAGAKI, ' ') <> NVL(R_SEIJINSYA_ATENA.CHOMEI || R_SEIJINSYA_ATENA.BANCHI || R_SEIJINSYA_ATENA.KATAGAKI, ' ') THEN
              M_JIDO_WORK(I_CNT).ATENA_CHOMEI   := R_SEIJINSYA_ATENA.CHOMEI;
              M_JIDO_WORK(I_CNT).ATENA_BANCHI   := R_SEIJINSYA_ATENA.BANCHI;
              M_JIDO_WORK(I_CNT).ATENA_KATAGAKI := R_SEIJINSYA_ATENA.KATAGAKI;
            END IF;
            IF NVL(CRSEIJINSYA.YUBIN_NO, ' ') <> NVL(R_SEIJINSYA_ATENA.YUBIN_NO, ' ') AND
               R_SEIJINSYA_ATENA.YUBIN_NO IS NOT NULL THEN
              M_JIDO_WORK(I_CNT).ATENA_YUBIN_NO := SUBSTR(R_SEIJINSYA_ATENA.YUBIN_NO, 1, 3) || '-' || SUBSTR(R_SEIJINSYA_ATENA.YUBIN_NO, 4);
            END IF;
          END IF;

          --同定されているかどうかのチェック
          IF R_SEIJINSYA_ATENA.KOJIN_NO > 0 AND
             R_SEIJINSYA_ATENA.JUFUKU_KOJIN_NO > 0 THEN
            M_JIDO_WORK(I_CNT).DOTEI_KBN := 1;
          ELSE
            M_JIDO_WORK(I_CNT).DOTEI_KBN := 0;
          END IF;

          I_CNT  := I_CNT + 1;               -- カウントアップ
          I_FRTN := c_ISUCCESS;              -- 正常終了

        END LOOP;
      EXCEPTION
        WHEN OTHERS THEN
          I_FRTN := c_INOT_SUCCESS;      -- 異常終了
          -- SQL情報取得
          V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
          -- 処理ログの出力
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, SUBSTR(c_VERR_MSG01 || V_SQL_MSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
      END;
      -- 終了
      RETURN I_FRTN;
    EXCEPTION
      -- その他エラー
      WHEN OTHERS THEN
        I_FRTN := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        -- 処理ログの出力
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, SUBSTR(c_VERR_MSG01 || V_SQL_MSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        RETURN I_FRTN;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 成人式重複者チェックリストワーク（GKBWSEIJINSHA）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_INSERT_JIDO_WK RETURN NUMBER IS
      I_FRTN              PLS_INTEGER;                -- 戻り値
      I_MAX               BINARY_INTEGER;             -- 戻り値
      I_MIN               BINARY_INTEGER;             -- 戻り値

    BEGIN
      I_FRTN := c_ISUCCESS;                  -- 正常終了
      -- ワーク領域の最終位置を取得
      I_MAX := M_JIDO_WORK.LAST;
      -- ワーク領域の先頭位置を取得
      I_MIN := M_JIDO_WORK.FIRST;

      BEGIN
        -- ワーク領域の件数分繰り返し処理を行う
        FORALL I_CNT IN I_MIN..I_MAX
          INSERT INTO GKBWSEIJINSHA VALUES M_JIDO_WORK(I_CNT);

        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;       -- 処理前に戻す
          I_FRTN := c_INOT_SUCCESS;      -- 異常終了
          V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, SUBSTR(c_VERR_MSG01 || V_SQL_MSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
      END;
      -- 終了
      RETURN I_FRTN;

    EXCEPTION
    -- その他エラー
      WHEN OTHERS THEN
        ROLLBACK;                  -- 処理前に戻す
        I_FRTN := c_INOT_SUCCESS;  -- 異常終了
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, SUBSTR(c_VERR_MSG01 || V_SQL_MSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        RETURN I_FRTN;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 成人式重複者チェックリスト中間データ作成（ＣＳＶ用）
    --------------------------------------------------------------------------------
    FUNCTION FUNCGET_JIDO_WK_CSV RETURN NUMBER IS
      I_FRTN              PLS_INTEGER;               -- 戻り値
      I_CNT               BINARY_INTEGER;            -- カウント
      V_SQLSEL            NVARCHAR2(9000);           -- ＳＱＬのソート以外
      V_SQLORDER          NVARCHAR2(1000);           -- ＳＱＬの［ORDER BY］句
      I_CUR               PLS_INTEGER;               -- カーソル
      R_WK                GKBWSEIJINSHA%ROWTYPE;     -- 成人式重複者チェックリスト中間のレコード変数
      N_ROWS              NUMBER;
      V_PAGENAME          NVARCHAR2(500);            -- 改頁項目名のワーク
      V_PAGEFIELD         NVARCHAR2(500);            -- 改頁項目値のワーク
      V_PAGENM            NVARCHAR2(500);            -- 改頁項目名
      V_PAGEFD            NVARCHAR2(500);            -- 改頁項目値

    BEGIN
      I_FRTN := c_ISUCCESS;
      I_CNT := 0;
      M_JIDO_WORK.DELETE;
--  2024/04/18 ZCZL.WUCAO Update Start 0.2.000.001:512_GKB_00017対応
--      V_PAGENM := '''';
--      V_PAGEFD := '''';
      V_PAGENM := '''''';
      V_PAGEFD := '''''';
--  2024/04/18 ZCZL.WUCAO Update End 
      -- ［ORDER BY］句を付加
      IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
        V_SQLORDER := ' ORDER BY ' || g_rJSTP.Orderbyclause;
      END IF;

      BEGIN
        -- 出力データ取得ＳＱＬの構文
        V_SQLSEL := '';
        V_SQLSEL := V_SQLSEL || 'SELECT ';
        V_SQLSEL := V_SQLSEL || 'NENDO, ';
        V_SQLSEL := V_SQLSEL || 'KAIPEJI_CD, ';
        V_SQLSEL := V_SQLSEL || 'KAIPEJI, ';
        V_SQLSEL := V_SQLSEL || 'GYOSEIKU_CD, ';
        V_SQLSEL := V_SQLSEL || 'GYOSEIKUMEI, ';
        V_SQLSEL := V_SQLSEL || 'HAN_CD, ';
        V_SQLSEL := V_SQLSEL || 'HANMEI, ';
        V_SQLSEL := V_SQLSEL || 'SANTEIDANTAI_CD, ';
        V_SQLSEL := V_SQLSEL || 'SANTEIDANTAIMEI, ';
        V_SQLSEL := V_SQLSEL || 'SHIMEI_KANA, ';
        V_SQLSEL := V_SQLSEL || 'SEINENGAPI, ';
        V_SQLSEL := V_SQLSEL || 'HYOJI_SEINENGAPI, ';
        V_SQLSEL := V_SQLSEL || 'SEIBETSU, ';
        V_SQLSEL := V_SQLSEL || 'HYOJI_SEIBETSU, ';
        V_SQLSEL := V_SQLSEL || 'SETAI_NO, ';
        V_SQLSEL := V_SQLSEL || 'SAKUSEIBI, ';
        V_SQLSEL := V_SQLSEL || 'RENBAN, ';
        V_SQLSEL := V_SQLSEL || 'SHIMEI_KANJI, ';
        V_SQLSEL := V_SQLSEL || 'ZOKUGARAMEI, ';
        V_SQLSEL := V_SQLSEL || 'CHOMEI, ';
        V_SQLSEL := V_SQLSEL || 'BANCHI, ';
        V_SQLSEL := V_SQLSEL || 'KATAGAKI, ';
        V_SQLSEL := V_SQLSEL || 'JUSHO_JODAN, ';
        V_SQLSEL := V_SQLSEL || 'JUSHO_GEDAN, ';
        V_SQLSEL := V_SQLSEL || 'NUSI_SHIMEI_KANA, ';
        V_SQLSEL := V_SQLSEL || 'NUSI_SHIMEI_KANJI, ';
        V_SQLSEL := V_SQLSEL || 'YUBIN_NO, ';
        V_SQLSEL := V_SQLSEL || V_PAGENM || ' PAGE_NAME, ';            -- 改頁名を設定
        V_SQLSEL := V_SQLSEL || V_PAGEFD || ' PAGE_FIELD, ';           -- 改頁値を設定
        V_SQLSEL := V_SQLSEL || 'SHOGAKOKU_CD, ';
        V_SQLSEL := V_SQLSEL || 'SHOGAKOMEI, ';
        V_SQLSEL := V_SQLSEL || 'CHUGAKOKU_CD, ';
        V_SQLSEL := V_SQLSEL || 'CHUGAKOMEI, ';
        V_SQLSEL := V_SQLSEL || 'SEIRI_NO, ';
        V_SQLSEL := V_SQLSEL || 'KOJIN_CD, ';
        V_SQLSEL := V_SQLSEL || 'ATENA_YUBIN_NO, ';
        V_SQLSEL := V_SQLSEL || 'ATENA_CHOMEI, ';
        V_SQLSEL := V_SQLSEL || 'ATENA_BANCHI, ';
        V_SQLSEL := V_SQLSEL || 'ATENA_KATAGAKI, ';
        V_SQLSEL := V_SQLSEL || 'GENZON_KBN, ';
        V_SQLSEL := V_SQLSEL || 'GENZON_KBN_MEI, ';
        V_SQLSEL := V_SQLSEL || 'JINKAKU_KBN, ';
        V_SQLSEL := V_SQLSEL || 'JINKAKU_KBN_MEI, ';
        V_SQLSEL := V_SQLSEL || 'DOTEI_KBN ';
        V_SQLSEL := V_SQLSEL || 'FROM ';
        V_SQLSEL := V_SQLSEL || 'GKBWSEIJINSHA ';

        -- カーソルのオープン
        I_CUR := DBMS_SQL.OPEN_CURSOR;
        -- ＳＱＬ文の解析
        DBMS_SQL.PARSE(I_CUR, V_SQLSEL || V_SQLORDER, DBMS_SQL.NATIVE);

        -- 取得する列の定義
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, R_WK.NENDO, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, R_WK.KAIPEJI_CD, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, R_WK.KAIPEJI, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, R_WK.GYOSEIKU_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, R_WK.GYOSEIKUMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, R_WK.HAN_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, R_WK.HANMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, R_WK.SANTEIDANTAI_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, R_WK.SANTEIDANTAIMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, R_WK.SHIMEI_KANA, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, R_WK.SEINENGAPI);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, R_WK.HYOJI_SEINENGAPI, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, R_WK.SEIBETSU);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, R_WK.HYOJI_SEIBETSU, 2);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, R_WK.SETAI_NO);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, R_WK.SAKUSEIBI, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, R_WK.RENBAN);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, R_WK.SHIMEI_KANJI, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, R_WK.ZOKUGARAMEI, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, R_WK.CHOMEI, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, R_WK.BANCHI, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, R_WK.KATAGAKI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, R_WK.JUSHO_JODAN, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, R_WK.JUSHO_GEDAN, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, R_WK.NUSI_SHIMEI_KANA, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, R_WK.NUSI_SHIMEI_KANJI, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, R_WK.YUBIN_NO, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, V_PAGENM,500 );
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, V_PAGEFD,500 );
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, R_WK.SHOGAKOKU_CD );
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, R_WK.SHOGAKOMEI,30 );
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, R_WK.CHUGAKOKU_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, R_WK.CHUGAKOMEI,30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 34, R_WK.SEIRI_NO);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 35, R_WK.KOJIN_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 36, R_WK.ATENA_YUBIN_NO,10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 37, R_WK.ATENA_CHOMEI,40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 38, R_WK.ATENA_BANCHI,40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 39, R_WK.ATENA_KATAGAKI,60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 40, R_WK.GENZON_KBN);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 41, R_WK.GENZON_KBN_MEI,60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 42, R_WK.JINKAKU_KBN);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 43, R_WK.JINKAKU_KBN_MEI,60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 44, R_WK.DOTEI_KBN);
        -- ＳＱＬ実行
        N_ROWS := DBMS_SQL.EXECUTE(I_CUR);
        LOOP
          --FETCH（行の取り出し）
          IF DBMS_SQL.FETCH_ROWS(I_CUR) > 0 THEN
            -- ワーク領域へセット
            DBMS_SQL.COLUMN_VALUE(I_CUR,  1, M_JIDO_WORK(I_CNT).NENDO);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  2, M_JIDO_WORK(I_CNT).KAIPEJI_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  3, M_JIDO_WORK(I_CNT).KAIPEJI);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  4, M_JIDO_WORK(I_CNT).GYOSEIKU_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  5, M_JIDO_WORK(I_CNT).GYOSEIKUMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  6, M_JIDO_WORK(I_CNT).HAN_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  7, M_JIDO_WORK(I_CNT).HANMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  8, M_JIDO_WORK(I_CNT).SANTEIDANTAI_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  9, M_JIDO_WORK(I_CNT).SANTEIDANTAIMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 10, M_JIDO_WORK(I_CNT).SHIMEI_KANA);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 11, M_JIDO_WORK(I_CNT).SEINENGAPI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 12, M_JIDO_WORK(I_CNT).HYOJI_SEINENGAPI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 13, M_JIDO_WORK(I_CNT).SEIBETSU);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 14, M_JIDO_WORK(I_CNT).HYOJI_SEIBETSU);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 15, M_JIDO_WORK(I_CNT).SETAI_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 16, M_JIDO_WORK(I_CNT).SAKUSEIBI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 17, M_JIDO_WORK(I_CNT).RENBAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 18, M_JIDO_WORK(I_CNT).SHIMEI_KANJI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 19, M_JIDO_WORK(I_CNT).ZOKUGARAMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 20, M_JIDO_WORK(I_CNT).CHOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 21, M_JIDO_WORK(I_CNT).BANCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 22, M_JIDO_WORK(I_CNT).KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 23, M_JIDO_WORK(I_CNT).JUSHO_JODAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 24, M_JIDO_WORK(I_CNT).JUSHO_GEDAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 25, M_JIDO_WORK(I_CNT).NUSI_SHIMEI_KANA);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 26, M_JIDO_WORK(I_CNT).NUSI_SHIMEI_KANJI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 27, M_JIDO_WORK(I_CNT).YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 28, V_PAGENAME);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 29, V_PAGEFIELD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 28, M_JIDO_WORK(I_CNT).KOMOKU1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 29, M_JIDO_WORK(I_CNT).KOMOKU2);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 30, M_JIDO_WORK(I_CNT).SHOGAKOKU_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 31, M_JIDO_WORK(I_CNT).SHOGAKOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 32, M_JIDO_WORK(I_CNT).CHUGAKOKU_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 33, M_JIDO_WORK(I_CNT).CHUGAKOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 34, M_JIDO_WORK(I_CNT).SEIRI_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 35, M_JIDO_WORK(I_CNT).KOJIN_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 36, M_JIDO_WORK(I_CNT).ATENA_YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 37, M_JIDO_WORK(I_CNT).ATENA_CHOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 38, M_JIDO_WORK(I_CNT).ATENA_BANCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 39, M_JIDO_WORK(I_CNT).ATENA_KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 40, M_JIDO_WORK(I_CNT).GENZON_KBN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 41, M_JIDO_WORK(I_CNT).GENZON_KBN_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 42, M_JIDO_WORK(I_CNT).JINKAKU_KBN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 43, M_JIDO_WORK(I_CNT).JINKAKU_KBN_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 44, M_JIDO_WORK(I_CNT).DOTEI_KBN);

            -- 再セットする項目
            M_JIDO_WORK(I_CNT).RENBAN := I_CNT + 1;      -- 連番
            M_JIDO_WORK(I_CNT).KAIPEJI := NULL;          -- 改頁名
            M_JIDO_WORK(I_CNT).KAIPEJI_CD := NULL;       -- 改頁コード

          ELSE
            -- 全件読み込み終了
            EXIT;
          END IF;
          I_CNT := I_CNT + 1;
        END LOOP;

        DBMS_SQL.CLOSE_CURSOR(I_CUR);
      EXCEPTION
        WHEN OTHERS THEN
          I_FRTN := c_INOT_SUCCESS;      -- 異常終了
          V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
          IF DBMS_SQL.IS_OPEN(I_CUR) THEN
            DBMS_SQL.CLOSE_CURSOR(I_CUR);
          END IF;
          -- 処理ログの出力
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, SUBSTR(c_VERR_MSG01 || V_SQL_MSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
      END;
      -- 終了
      RETURN I_FRTN;
    EXCEPTION
      WHEN OTHERS THEN
        I_FRTN := c_INOT_SUCCESS;         -- 異常終了
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);

        -- 処理ログの出力
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, SUBSTR(c_VERR_MSG01 || V_SQL_MSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        RETURN I_FRTN;
    END FUNCGET_JIDO_WK_CSV;
    --------------------------------------------------------------------------------------------------
    -- 成人式重複者チェックリストＣＳＶファイル作成
    --------------------------------------------------------------------------------------------------
    FUNCTION FUNCSET_JIDO_WK_CSVFILE RETURN NUMBER IS
      I_FRTN      PLS_INTEGER;                -- 戻り値
      I_MAX       PLS_INTEGER;                -- 最大値（出力件数）
      I_MIN       PLS_INTEGER;                -- 最小値（出力件数）
      r_WKRECORD001    GKBWL420R001%ROWTYPE;
      n_ROWNO     NUMBER := 0;

    BEGIN

      I_FRTN := c_ISUCCESS;                -- 正常終了
      I_MAX := M_JIDO_WORK.LAST;           -- ワーク領域の件数の最大値
      I_MIN := M_JIDO_WORK.FIRST;          -- ワーク領域の件数の最小値

      -- 取得した件数分繰り返す
      FOR I_CNT IN I_MIN..I_MAX LOOP
          n_ROWNO := n_ROWNO + 1;
          r_WKRECORD001 := NULL;
          --ソート順
          r_WKRECORD001.NO                    := n_ROWNO;
          --年度
          r_WKRECORD001.NENDO                 := M_JIDO_WORK(I_CNT).NENDO||'年度';
          --改頁コード
          r_WKRECORD001.KAIPAGE_CD            := M_JIDO_WORK(I_CNT).KAIPEJI_CD;
          --改頁名
          r_WKRECORD001.KAIPAGE_MEI           := M_JIDO_WORK(I_CNT).KAIPEJI;
          --行政区名
          r_WKRECORD001.GYOSEIKU_MEI          := M_JIDO_WORK(I_CNT).GYOSEIKUMEI;
          --算定団体名
          r_WKRECORD001.SANTEIDANTAI_MEI      := M_JIDO_WORK(I_CNT).SANTEIDANTAIMEI;
          --氏名カナ
          r_WKRECORD001.SHIMEI_KANA           := M_JIDO_WORK(I_CNT).SHIMEI_KANA;
          --生年月日
          r_WKRECORD001.SEINENGAPI            := M_JIDO_WORK(I_CNT).HYOJI_SEINENGAPI;
          --性別
          r_WKRECORD001.SEIBETSU              := M_JIDO_WORK(I_CNT).HYOJI_SEIBETSU;
          --現在日
          r_WKRECORD001.GENZAIBI              := M_JIDO_WORK(I_CNT).SAKUSEIBI;
          --No
          r_WKRECORD001.NUM                   := M_JIDO_WORK(I_CNT).RENBAN;
          --氏名
          r_WKRECORD001.SHIMEI                := M_JIDO_WORK(I_CNT).SHIMEI_KANJI;
          --続柄
          r_WKRECORD001.ZOKUGARA              := M_JIDO_WORK(I_CNT).ZOKUGARAMEI;
          --方書
          r_WKRECORD001.KATAGAKI              := M_JIDO_WORK(I_CNT).KATAGAKI;
          --住所上
          r_WKRECORD001.JUSHO_JODAN           := M_JIDO_WORK(I_CNT).JUSHO_JODAN;
          --住所下
          r_WKRECORD001.JUSHO_GEDAN           := M_JIDO_WORK(I_CNT).JUSHO_GEDAN;
          --世帯主氏名カナ
          r_WKRECORD001.NUSHI_SHIMEI_KANA     := M_JIDO_WORK(I_CNT).NUSI_SHIMEI_KANA;
          --世帯主氏名
          r_WKRECORD001.NUSHI_SHIMEI_KANJI    := M_JIDO_WORK(I_CNT).NUSI_SHIMEI_KANJI;
          --郵便番号
          r_WKRECORD001.YUBIN_NO              := M_JIDO_WORK(I_CNT).YUBIN_NO;
          --町名番地
          r_WKRECORD001.CHOMEI_BANCHI         := M_JIDO_WORK(I_CNT).CHOMEI || M_JIDO_WORK(I_CNT).BANCHI;
          --氏名漢字様
          r_WKRECORD001.SHIMEI_KANJI_SAMA     := M_JIDO_WORK(I_CNT).SHIMEI_KANJI ||'　様';
          --小学校コード
          r_WKRECORD001.SHOGAKKO_CD           := M_JIDO_WORK(I_CNT).SHOGAKOKU_CD;
          --小学校名
          r_WKRECORD001.SHOGAKKO_MEI          := M_JIDO_WORK(I_CNT).SHOGAKOMEI;
          --整理番号
          r_WKRECORD001.SEIRI_NO              := M_JIDO_WORK(I_CNT).SEIRI_NO;
          --個人番号
          r_WKRECORD001.KOJIN_NO              := M_JIDO_WORK(I_CNT).KOJIN_CD;
          --宛名郵便番号
          r_WKRECORD001.ATENA_YUBIN_NO        := M_JIDO_WORK(I_CNT).ATENA_YUBIN_NO;
          --宛名住所
          r_WKRECORD001.ATENA_JUSHO           := M_JIDO_WORK(I_CNT).ATENA_CHOMEI || M_JIDO_WORK(I_CNT).ATENA_BANCHI || M_JIDO_WORK(I_CNT).ATENA_KATAGAKI;
          --宛名現存区分
          r_WKRECORD001.ATENA_GENZON_KBN_MEI  := M_JIDO_WORK(I_CNT).GENZON_KBN_MEI;
          --人格区分
          IF M_JIDO_WORK(I_CNT).GENZON_KBN IN (0, 1) THEN
            r_WKRECORD001.JINKAKU_KBN := '(' || M_JIDO_WORK(I_CNT).JINKAKU_KBN_MEI || ')';
          END IF;
            r_WKRECORD001.JINKAKU_KBN := M_JIDO_WORK(I_CNT).JINKAKU_KBN;
          --改ページキー
          r_WKRECORD001.BREAK_NO              := M_JIDO_WORK(I_CNT).KAIPEJI_CD;
          --端末番号
          r_WKRECORD001.WSNUM                 := g_sWSNUM;
          --即時バッチ区分
          r_WKRECORD001.BATCHKBN              := c_BATCH;
          --ジョブNO
          r_WKRECORD001.JOBNUM                := g_nJOBNUM;

          INSERT INTO GKBWL420R001 VALUES r_WKRECORD001;
      END LOOP;

      RETURN I_FRTN;
    EXCEPTION
      WHEN OTHERS THEN
        I_FRTN := c_INOT_SUCCESS;      -- 異常終了
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        -- 処理ログの出力
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_CSVFILE', 1, SQLCODE, SQLERRM, SUBSTR(c_VERR_MSG01 || V_SQL_MSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        RETURN I_FRTN;
    END FUNCSET_JIDO_WK_CSVFILE;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
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

        --ワークテーブルのデータを削除する
        DELETE FROM GKBWL420R001 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;

        -- システム日付を西暦数値（YYYYMMDD形式）にする
        I_SYSDATE := TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));

        -- 取得した条件をそれぞれの変数へセット
        I_JKN_NENDO           := TO_NUMBER(g_MJYOUKEN01);           -- 年度
        I_JKN_SAKUSEI_KBN     := TO_NUMBER(g_MJYOUKEN02);           -- 作成区分
        I_JKN_SANTEIDANTAI_CD := TO_NUMBER(NVL(g_MJYOUKEN03, '0')); -- 算定団体コード

        --氏名かなの姓名の名部分のみでの重複判断のため、判断用のワークテーブルを作成する
        I_NENDO       := KKAPK0020.FNENDO(I_JKN_NENDO,1);

        -- 成人式重複者ワーク（GKBWSEIJINSHAJUFUKU）のデータ全件削除
        I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE2, V_SQL_MSG);
        IF I_RTN = c_INOT_SUCCESS THEN
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR(c_VERR_MSG01 || V_SQL_MSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          RAISE ERR;
        END IF;

        I_RTN := FUNC_WK_JUFUKU_CREATE(I_NENDO,
                                       I_JKN_SAKUSEI_KBN,
                                       I_JKN_SANTEIDANTAI_CD);

        -- 成人式重複者チェックリストワーク（GKBWSEIJINSHA）のデータ全件削除
        I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, V_SQL_MSG);
        IF I_RTN = c_INOT_SUCCESS THEN
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR(c_VERR_MSG01 || V_SQL_MSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          RAISE ERR;
        END IF;

        -- 成人式重複者チェックリストワーク中間データ作成
        I_RTN := FUNC_GET_JIDO_WK;
        IF I_RTN <> c_ISUCCESS THEN
          IF I_RTN = c_INOTFOUND THEN
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00027対応
--            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VOK_MSG01 || ':対象データなし', g_sTANTOCODE, g_sWSNUM, 1);
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', c_VOK_MSG01 || ':対象データなし', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN TRUE;
          ELSE
            RAISE ERR;
          END IF;
        END IF;

        -- 成人式重複者チェックリストワーク作成
        I_RTN := FUNC_INSERT_JIDO_WK;
        IF I_RTN = c_INOT_SUCCESS THEN
          RAISE ERR;
        END IF;

        -- 成人式重複者チェックリスト中間データ作成（ＣＳＶ用）
        I_RTN := FUNCGET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
          RAISE ERR;
        END IF;

        -- 成人式重複者チェックリストＣＳＶファイル作成
        I_RTN := FUNCSET_JIDO_WK_CSVFILE;
        IF I_RTN <> c_ISUCCESS THEN
          RAISE ERR;
        END IF;

        --帳票出力CSVの作成
        bRTN :=FUNC_B11CSV('GKBWL420R001');

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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/3
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
END GKBPB00300;
/
