CREATE OR REPLACE PACKAGE BODY GKBPB00570
--1.0.106.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 学齢簿・住基差異チェックリスト作成
--  機能概要      : 住民基本台帳と学齢簿で差異があった対象者に、学齢簿・住記差異チェックリストを作成します。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.lwy   2024/07/01
--------------------------------------------------------
--  変更履歴
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00075対応
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00114対応の横展開
--  2024/10/16 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更　ID：IT_GKB_00081対応
--  2024/10/25 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00213対応
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.006:IT_GKB_00286横展開対応
--  2025/09/19 CTC.GL UPDATE 1.0.106.000:GKB_QA20705対応
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
    g_sGROUPCODE                  NVARCHAR2(1000);             --グループコード
    g_sSHORINAME                  NVARCHAR2(1000);             --処理名
    g_nTIME                       NUMBER;                      --システム時間
    g_nREBAN                      NUMBER := 0;                 --連番
    g_nINDEX                      NUMBER := 0;
    g_oKENSU_LIST                 GKBEKENSU_LIST := GKBEKENSU_LIST();
    eSHORIEXCEPTION               EXCEPTION;                   --処理異常タイプ
    eFILEPUT                      EXCEPTION;

    --変数宣言
    g_nSORT                       NUMBER := 0;                 --ソート順
    g_nJYOUKEN01                  NUMBER;                      --処理開始日 期間(開始)（西暦）
    g_nJYOUKEN02                  NUMBER;                      --処理終了日 期間(終了)（西暦）
    g_nJYOUKEN03                  NUMBER;                      --抽出開始生年月日 期間(開始)（西暦）
    g_nJYOUKEN04                  NUMBER;                      --抽出終了生年月日 期間(終了)（西暦）
    g_nJYOUKEN05                  NUMBER;                      --人格区分
    
    --画面入力条件
    g_vJYOUKEN01                  NVARCHAR2(1000);
    g_vJYOUKEN02                  NVARCHAR2(1000);
    g_vJYOUKEN03                  NVARCHAR2(1000);
    g_vJYOUKEN04                  NVARCHAR2(1000);
    g_vJYOUKEN05                  NVARCHAR2(1000);
--2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.006:IT_GKB_00286横展開対応
    o_sEINENGAPI1                    GKAPK00020.SEINENGAPI_REC;           --生年月日

    --パラメータ変数
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
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
        g_nTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));   --システム時間

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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
--  2024/09/03 ZCZL.WANGMING ADD 0.3.000.001:IT_GKB_00075対応
        cmbtxtJinkakuKbn       DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        --処理開始日 期間(開始)
        g_vJYOUKEN01 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtStartYmd');
        --処理終了日 期間(終了)
        g_vJYOUKEN02 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtEndYmd');
        --抽出開始生年月日 期間(開始)
        g_vJYOUKEN03 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtExtractStartYmd');
        --抽出終了生年月日 期間(終了)
        g_vJYOUKEN04 := KKBPK5551.GETPARMS(g_nJOBNUM,'txExtractEndYmd');
        --人格区分
--  2024/09/03 ZCZL.WANGMING UPDATE START 0.3.000.001:IT_GKB_00075対応
--        g_vJYOUKEN05 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtJinkakuKbn');
        cmbtxtJinkakuKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'txtJinkakuKbn');
        g_vJYOUKEN05 := cmbtxtJinkakuKbn(1);
--  2024/09/03 ZCZL.WANGMING UPDATE END

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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
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
    --  作成者／作成日: ZCZL.lwy   2024/07/01
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN       BOOLEAN;          --戻り値
        VMSG       NVARCHAR2(4000);  --エラーメッセージ
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
       --入力値チェック
       --処理開始日 期間(開始)チェック
--  2024/09/20 ZCZL.WANGMING UPDATE START 0.3.000.003:IT_GKB_00114対応の横展開
         bRTN := kKAPK0010.FISNUMERIC(g_vJYOUKEN01);
         IF bRTN THEN
             bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN01));
             IF NOT bRTN THEN
--               o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ', 99999, 処理開始日 期間(開始)が正しくありません。,;';
               o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,処理開始日 期間(開始)が正しくありません。,;';
             END IF;
         ELSE
             o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,処理開始日 期間(開始)が正しくありません。,;';
         END IF;
--  2024/09/20 ZCZL.WANGMING UPDATE END
       --処理終了日 期間(終了)チェック
--  2024/09/20 ZCZL.WANGMING UPDATE START 0.3.000.003:IT_GKB_00114対応の横展開
         bRTN := kKAPK0010.FISNUMERIC(g_vJYOUKEN02);
         IF bRTN THEN
             bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN02));
             IF NOT bRTN THEN
--               o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ', 99999, 処理終了日 期間(終了)が正しくありません。,;';
               o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,処理終了日 期間(終了)が正しくありません。,;';
             END IF;
         ELSE
             o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,処理終了日 期間(終了)が正しくありません。,;';
         END IF;
--  2024/09/20 ZCZL.WANGMING UPDATE END
       --抽出開始生年月日 期間(開始)チェック
--  2024/09/20 ZCZL.WANGMING UPDATE START 0.3.000.003:IT_GKB_00114対応の横展開
         bRTN := kKAPK0010.FISNUMERIC(g_vJYOUKEN03);
         IF bRTN THEN
             bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN03));
             IF NOT bRTN THEN
--             o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ', 99999, 抽出開始生年月日 期間(開始)が正しくありません。,;';
               o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,抽出開始生年月日 期間(開始)が正しくありません。,;';
             END IF;
         ELSE
             o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,抽出開始生年月日 期間(開始)が正しくありません。,;';
         END IF;
--  2024/09/20 ZCZL.WANGMING UPDATE END
       --抽出終了生年月日 期間(終了)チェック
--  2024/09/20 ZCZL.WANGMING UPDATE START 0.3.000.003:IT_GKB_00114対応の横展開
         bRTN := kKAPK0010.FISNUMERIC(g_vJYOUKEN04);
         IF bRTN THEN
             bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN04));
             IF NOT bRTN THEN
--              o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ', 99999, 抽出終了生年月日 期間(終了)が正しくありません。,;';
               o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,抽出終了生年月日 期間(終了)が正しくありません。,;';
             END IF;
         ELSE
             o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,抽出終了生年月日 期間(終了)が正しくありません。,;';
         END IF;
--  2024/09/20 ZCZL.WANGMING UPDATE END
         IF o_vRESULT IS NULL THEN
           -- 変数.処理開始日 > 変数.処理終了日の場合
           IF g_vJYOUKEN01 > g_vJYOUKEN02 THEN
             o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,処理開始日、処理終了日の関係が正しくありません。,;';
           END IF;
           -- 変数.抽出開始生年月日 > 変数.抽出終了生年月日の場合
           IF g_vJYOUKEN03 > g_vJYOUKEN04 THEN
           o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,抽出開始生年月日、抽出終了生年月日の関係が正しくありません。,;';
           END IF;
         END IF;
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
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
    --  機能概要      : 条件取得処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET
        RETURN BOOLEAN
    IS
        bRTN              BOOLEAN;    --戻り値
        ERR               EXCEPTION;
    BEGIN
      --処理開始日 期間(開始)(和暦日付を西暦日付に変換する)
      g_nJYOUKEN01 := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vJYOUKEN01));
      --処理終了日 期間(終了)(和暦日付を西暦日付に変換する)
      g_nJYOUKEN02 := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vJYOUKEN02));
      --抽出開始生年月日 期間(開始)(和暦日付を西暦日付に変換する)
      g_nJYOUKEN03 := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vJYOUKEN03));
      --抽出終了生年月日 期間(終了)(和暦日付を西暦日付に変換する)
      g_nJYOUKEN04 := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vJYOUKEN04));
      --人格区分
      g_nJYOUKEN05 := TO_NUMBER(g_vJYOUKEN05);
      
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_JYOKEN_GET;
    --------------------------------------------------------
    --  機能概要      : 初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_INIT
        RETURN BOOLEAN
    IS
        bRTN                    BOOLEAN;                    --戻り値
        nRTN                    PLS_INTEGER;                --戻る値
        aITEM                   A_CONS_PRM;                 --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        sINDEXNO                NUMBER;                     --変数.抑止対象者一覧表_インデックス番号
        v_SQL_MSG               VARCHAR(255);     -- SQLエラーメッセージ
    BEGIN
      --学齢簿・住基差異チェック中間ワークファイルをクリアする
      nRTN := KKAPK3000.FTRUNCATE('GKBWGKRBJKSAI',v_SQL_MSG);
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_INIT;
    --------------------------------------------------------
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE
        RETURN NUMBER
    IS
        bRTN                            BOOLEAN;                               --戻り値
        nRTN                            PLS_INTEGER;                           --戻る値
        nCOUNT                          PLS_INTEGER;                           --抽出件数
        nCOUNT1                         NUMBER;                                -- CSV出力件数
        sSQL                            NVARCHAR2(30000);
        sSQL1                           NVARCHAR2(30000);
        sSQL2                           NVARCHAR2(30000);
        sSQL3                           NVARCHAR2(30000);
        sSQL4                           NVARCHAR2(30000);
        TYPE MC_CURSOR IS REF           CURSOR;                                --カーソルタイプ定義
        cCURSOR                         MC_CURSOR;
        cCURSOR1                        MC_CURSOR;
        cCURSORWL                       MC_CURSOR;
        sMEISHO                         NVARCHAR2(1000);                       --名称
        sMEISHOKANA                     NVARCHAR2(1000);                       --名称カナ
        sYOBI                           NVARCHAR2(1000);                       --予備
        vIDOJIYUCD                      NVARCHAR2(1000);                       --異動事由コード
--  2024/10/16 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更　ID：IT_GKB_00081対応
--        rRECORD                         GABVATENAALL%ROWTYPE;                  --宛名管理他業務参照　AJ（児童生徒）レコード
        rRECORD                         GABVATENAALL_B%ROWTYPE;                  --宛名管理他業務参照Bレコード
        nGKBTGAKUREIBOCT                PLS_INTEGER;                           --学齢簿情報件数
--  2024/10/16 ZCZL.WANGMING UPDATE START 0.3.000.004:仕様変更　ID：IT_GKB_00081対応
--        A1                              GABVATENAALL%ROWTYPE;                  --宛名管理他業務参照　A1（変更前）                                                                                   
--        A2                              GABVATENAALL%ROWTYPE;                  --宛名管理他業務参照　A2（変更前）
        A1                              GABVATENAALL_B%ROWTYPE;                  --宛名管理他業務参照B　A1（変更前）                                                                                   
        A2                              GABVATENAALL_B%ROWTYPE;                  --宛名管理他業務参照B　A2（変更前）
--  2024/10/16 ZCZL.WANGMING UPDATE END
        B1                              JIBTJUKIIDO%ROWTYPE;                   --住記異動_住記B1
        B2                              JIBTJUKIIDO%ROWTYPE;                   --住記異動_住記B2                                                                                  
        rGKBTGAKUREIBO                  GKBTGAKUREIBO%ROWTYPE;                 --学齢簿
        nGAKUREIBOCOUNT                 PLS_INTEGER;                           --学齢簿情報件数
        rGKBWGKRBJKSAI                  GKBWGKRBJKSAI%ROWTYPE;                 --学齢簿・住基差異チェック中間ワーク
        o_sWAREKIDATE                   NVARCHAR2(1000);                       --和暦日付（GYYMMDD）                              
        rDATA                           GKBWGKRBJKSAI%ROWTYPE;                 --中間ワークカーソルデータ
        sOUTDATA                        NVARCHAR2(1000); 
        w_sBUFF                         NVARCHAR2(2000);
--  2024/10/25 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00213対応
        w_sBUFF_HEAD                    NVARCHAR2(2000);
        io_nRIREKISEQ                   NUMBER := 0;
        o_tITEM                         A_CONS_PRM;

    BEGIN
      --初期処理
      --異動事由
      nRTN := KKAPK0030.FCTGetR('GKB', 'IDOJIYU', '0000', 1, o_tITEM);
      IF nRTN = 0 THEN
        FOR i IN 1..o_tITEM.COUNT LOOP
          IF i = 1 THEN
            vIDOJIYUCD := o_tITEM(i);
          ELSE
            vIDOJIYUCD := vIDOJIYUCD  ||','|| o_tITEM(i);
          END IF;
        END LOOP;
      END IF;
      --学齢簿データ抽出(現存区分＝０、１、２の対象児童生徒を抽出する)    
      sSQL1 := '';
--  2024/10/16 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更　ID：IT_GKB_00081対応
--      sSQL1 := sSQL1 || ' SELECT * FROM GABVATENAALL AJ'; 
      sSQL1 := sSQL1 || ' SELECT * FROM GABVATENAALL_B AJ'; 
--  2025/09/19 CTC.GL UPDATE START 1.0.106.000:GKB_QA20705対応
      --sSQL1 := sSQL1 || ' WHERE AJ.SEINENGAPI >= '|| g_nJYOUKEN01 ||''; 
      --sSQL1 := sSQL1 || ' AND AJ.SEINENGAPI <= '|| g_nJYOUKEN02 ||'';
      sSQL1 := sSQL1 || ' WHERE AJ.SEINENGAPI >= '|| g_nJYOUKEN03 ||''; 
      sSQL1 := sSQL1 || ' AND AJ.SEINENGAPI <= '|| g_nJYOUKEN04 ||'';
      sSQL1 := sSQL1 || ' AND TEKIYO_BI BETWEEN ' || g_nJYOUKEN01 || ' AND ' || g_nJYOUKEN02;

--  2025/09/19 CTC.GL UPDATE END
      sSQL1 := sSQL1 || ' AND AJ.GENZON_KBN IN (0,1,2)';

      OPEN cCURSOR1 FOR sSQL1;
        LOOP
          FETCH cCURSOR1 INTO rRECORD;
          EXIT WHEN cCURSOR1%NOTFOUND;
          BEGIN
            SELECT COUNT(*) AS GKBTGAKUREIBOCT 
            INTO nGAKUREIBOCOUNT
            FROM GKBTGAKUREIBO 
            WHERE GKBTGAKUREIBO.SAISHIN_KBN = '0'
            AND GKBTGAKUREIBO.SAKUJO_FLG = '0'
            AND GKBTGAKUREIBO.KOJIN_NO = rRECORD.KOJIN_NO;
          EXCEPTION
            WHEN OTHERS THEN
              RAISE eSHORIEXCEPTION;
          END;
            IF nGAKUREIBOCOUNT = 0 THEN
              rGKBWGKRBJKSAI.MAE_JIDO_SHIMEI_KANJI   := rRECORD.SHIMEI_KANJI;          --変更前の児童生徒氏名
              rGKBWGKRBJKSAI.MAE_JIDO_SHIMEI_KANA    := rRECORD.SHIMEI_KANA;           -- 変更前の児童生徒氏名カナ
              rGKBWGKRBJKSAI.MAE_SEINENGAPI          := rRECORD.SEINENGAPI;            -- 変更前の生年月日
              nRTN := KKAPK0030.FCDGetR('GKB', '021', '0001', rRECORD.SEIBETSU, sMEISHO, sMEISHOKANA, sYOBI); 
              rGKBWGKRBJKSAI.MAE_SEIBETSU            := sMEISHO;                       -- 変更前の性別
              -- 変更前の児童生徒住所
              rGKBWGKRBJKSAI.MAE_JIDO_JUSHO          := GAAPK0010.FADDRESSEDIT(1, NULL, rRECORD.CHOMEI, rRECORD.BANCHI, rRECORD.KATAGAKI, NULL);
              -- 変更前の続柄
              rGKBWGKRBJKSAI.MAE_ZOKUGARA            := GKBFKZKGMGET2(1, rRECORD.ZOKUGARA_CD1, rRECORD.ZOKUGARA_CD2, rRECORD.ZOKUGARA_CD3, rRECORD.ZOKUGARA_CD4);
              rGKBWGKRBJKSAI.MAE_HOGOSHA_SHIMEI_KANJI:= NULL;                          -- 変更前の保護者氏名
              rGKBWGKRBJKSAI.MAE_HOGOSHA_SHIMEI_KANA := NULL;                          -- 変更前の保護者氏名カナ
              rGKBWGKRBJKSAI.MAE_HOGOSHA_ZOKUGARA    := NULL;                          -- 変更前の保護者と児童生徒との関係
              nRTN := KKAPK0030.FCDGetR('GKB', '023', '0001', rRECORD.SHOGAKU_CD, sMEISHO, sMEISHOKANA, sYOBI);
              rGKBWGKRBJKSAI.MAE_SHITEI_SYOGAKKOKU   := sMEISHO;                       -- 変更前の指定小学校区
              nRTN := KKAPK0030.FCDGetR('GKB', '023', '0002', rRECORD.CHUGAKU_CD, sMEISHO, sMEISHOKANA, sYOBI);      
              rGKBWGKRBJKSAI.MAE_SHITEI_CHUGAKKOKU   := sMEISHO;                       -- 変更前の指定中学校区
              rGKBWGKRBJKSAI.MAE_NUSHI_SHIMEI_KANA   := NULL;                          -- 変更前の世帯主氏名カナ
              rGKBWGKRBJKSAI.MAE_NUSHI_SHIMEI_KANJI  := NULL;                          -- 変更前の世帯主氏名
              rGKBWGKRBJKSAI.ATO_ZOKUGARA            := NULL;                          -- 変更後の続柄
              rGKBWGKRBJKSAI.ATO_JIDO_IDO_JIYU       := NULL;                          -- 変更後の児童生徒異動事由
              rGKBWGKRBJKSAI.ATO_JIDO_IDO_BI         := NULL;                          -- 変更後の児童生徒異動年月日
              rGKBWGKRBJKSAI.ATO_JIDO_TODOKEDEBI     := NULL;                          -- 変更後の児童生徒届出年月日
              rGKBWGKRBJKSAI.ATO_JIDO_JUSHO          := NULL;                          -- 変更後の児童生徒住所
              rGKBWGKRBJKSAI.ATO_SHITEI_SYOGAKKOKU   := NULL;                          -- 変更後の指定小学校区
              rGKBWGKRBJKSAI.ATO_SHITEI_CHUGAKKOKU   := NULL;                          -- 変更後の指定中学校区
              rGKBWGKRBJKSAI.ATO_NUSHI_SHIMEI_KANA   := NULL;                          -- 変更後の世帯主氏名カナ
              rGKBWGKRBJKSAI.ATO_NUSHI_SHIMEI_KANJI  := NULL;                          -- 変更後の世帯主氏名
              nRTN := KKAPK0030.FCDGetR('GKB', '041', '0000', '1', sMEISHO, sMEISHOKANA, sYOBI);
              rGKBWGKRBJKSAI.BIKO                    := sMEISHO;                       -- 備考
              rGKBWGKRBJKSAI.JIDO_KOJIN_NO_SORT      := rRECORD.KOJIN_NO;              -- 宛名番号（ソート用）
              rGKBWGKRBJKSAI.SEINENGAPI_SORT         := rRECORD.SEINENGAPI;            -- 生年月日（ソート用）
              rGKBWGKRBJKSAI.ERA_JIYU_CD             := 1;                             --エラー事由コード
              --登録中間ワークテーブル
              INSERT INTO GKBWGKRBJKSAI VALUES rGKBWGKRBJKSAI;
            ELSIF rRECORD.GENZON_KBN <> 0 THEN
              --異動累計情報取得
              sSQL3 := '';
              sSQL3 := sSQL3 || ' SELECT ';
              sSQL3 := sSQL3 || ' A1.KOJIN_NO,';
              sSQL3 := sSQL3 || ' A1.SHIMEI_KANA,';
              sSQL3 := sSQL3 || ' A1.SHIMEI_KANJI,';
              sSQL3 := sSQL3 || ' A1.SEINENGAPI,';
              sSQL3 := sSQL3 || ' A1.SEIBETSU,';
              sSQL3 := sSQL3 || ' A1.CHOMEI,';
              sSQL3 := sSQL3 || ' A1.BANCHI,';
              sSQL3 := sSQL3 || ' A1.KATAGAKI,';
              sSQL3 := sSQL3 || ' A1.ZOKUGARA_CD1,';
              sSQL3 := sSQL3 || ' A1.ZOKUGARA_CD2,';
              sSQL3 := sSQL3 || ' A1.ZOKUGARA_CD3,';
              sSQL3 := sSQL3 || ' A1.ZOKUGARA_CD4,';
              sSQL3 := sSQL3 || ' A1.SHOGAKU_CD,';
              sSQL3 := sSQL3 || ' A1.CHUGAKU_CD,';
              sSQL3 := sSQL3 || ' A2.ZOKUGARA_CD1,';
              sSQL3 := sSQL3 || ' A2.ZOKUGARA_CD2,';
              sSQL3 := sSQL3 || ' A2.ZOKUGARA_CD3,';
              sSQL3 := sSQL3 || ' A2.ZOKUGARA_CD4,';
              sSQL3 := sSQL3 || ' A2.SHOGAKU_CD,';
              sSQL3 := sSQL3 || ' A2.CHUGAKU_CD,';
              sSQL3 := sSQL3 || ' B1.NUSHI_SHIMEI_KANA,';
              sSQL3 := sSQL3 || ' B1.NUSHI_SHIMEI_KANJI,';
              sSQL3 := sSQL3 || ' B2.IDO_BI,';
              sSQL3 := sSQL3 || ' B2.IDO_JIYU,';
              sSQL3 := sSQL3 || ' B2.IDO_TODOKE_BI,';
              sSQL3 := sSQL3 || ' B2.NUSHI_SHIMEI_KANA,';
              sSQL3 := sSQL3 || ' B2.NUSHI_SHIMEI_KANJI,';
              sSQL3 := sSQL3 || ' B.HOGOSYA_TSUSHOMEI_KANA,';
              sSQL3 := sSQL3 || ' B.HOGOSYA_TSUSHOMEI_KANJI,';
              sSQL3 := sSQL3 || ' B.HOGOSYA_ZOKUGARA1,';
              sSQL3 := sSQL3 || ' B.HOGOSYA_ZOKUGARA2,';
              sSQL3 := sSQL3 || ' B.HOGOSYA_ZOKUGARA3,';
              sSQL3 := sSQL3 || ' B.HOGOSYA_ZOKUGARA4,';
              sSQL3 := sSQL3 || ' A2.CHOMEI,';
              sSQL3 := sSQL3 || ' A2.BANCHI,';
              sSQL3 := sSQL3 || ' A2.KATAGAKI,';
              sSQL3 := sSQL3 || ' A2.SHIMEI_KANA,';
              sSQL3 := sSQL3 || ' A2.SHIMEI_KANJI,';
              sSQL3 := sSQL3 || ' A2.SEINENGAPI,';
              sSQL3 := sSQL3 || ' A2.SEIBETSU';
--  2024/10/16 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更　ID：IT_GKB_00081対応
--              sSQL3 := sSQL3 || ' FROM GABVATENAALL A1, GABVATENAALL A2, JIBTJUKIIDO B1, JIBTJUKIIDO B2,';
              sSQL3 := sSQL3 || ' FROM GABVATENAALL_B A1, GABVATENAALL_B A2, JIBTJUKIIDO B1, JIBTJUKIIDO B2,';
              sSQL3 := sSQL3 || ' GKBTGAKUREIBO B';
              sSQL3 := sSQL3 || ' WHERE A1.KOJIN_NO = '|| rRECORD.KOJIN_NO ||'';
              sSQL3 := sSQL3 || ' AND A1.KOJIN_NO = B.KOJIN_NO';       
              sSQL3 := sSQL3 || ' AND A1.RIREKI_RENBAN = B.IDOJI_ATENA_RIREKI_RENBAN ';
              sSQL3 := sSQL3 || ' AND A1.KOJIN_NO = B1.KOJIN_NO';
              sSQL3 := sSQL3 || ' AND A2.KOJIN_NO = '|| rRECORD.KOJIN_NO ||'';
              sSQL3 := sSQL3 || ' AND A2.KOJIN_NO = B2.KOJIN_NO';
              sSQL3 := sSQL3 || ' AND B.GEN_NENGAPI = 0';
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00075対応
--              sSQL3 := sSQL3 || ' AND A1.RIREKI_RENBAN = 999';
              sSQL3 := sSQL3 || ' AND A2.RIREKI_RENBAN = 999';
              sSQL3 := sSQL3 || ' AND ( A1.SHIMEI_KANA <> A2.SHIMEI_KANA OR A1.SHIMEI_KANJI <> A2.SHIMEI_KANJI OR A1.SEINENGAPI <> A2.SEINENGAPI';
              sSQL3 := sSQL3 || ' OR A1.SEIBETSU <> A2.SEIBETSU OR A1.CHOMEI <> A2.CHOMEI OR A1.BANCHI <> A2.BANCHI OR A1.KATAGAKI <> A2.KATAGAKI';
              sSQL3 := sSQL3 || ' OR A1.NUSHI_SHIMEI_KANJI <> A2.NUSHI_SHIMEI_KANJI OR A1.ZOKUGARA_CD1 <> A2.ZOKUGARA_CD1 OR A1.ZOKUGARA_CD2 <> A2.ZOKUGARA_CD2 OR A1.ZOKUGARA_CD3 <> A2.ZOKUGARA_CD3  OR A1.ZOKUGARA_CD4 <> A2.ZOKUGARA_CD4';
              sSQL3 := sSQL3 || ' OR A1.SHOGAKU_CD <> A2.SHOGAKU_CD OR A1.CHUGAKU_CD <> A2.CHUGAKU_CD )';
              IF g_nJYOUKEN05 <> 2 THEN
               sSQL3 := sSQL3 || ' AND A1.JINKAKU_KBN = '|| g_nJYOUKEN05 ||'';
               sSQL3 := sSQL3 || ' AND A2.JINKAKU_KBN = '|| g_nJYOUKEN05 ||'';
              END IF;

              OPEN cCURSOR FOR sSQL3;
                LOOP
                  FETCH cCURSOR INTO A1.KOJIN_NO,
                                     A1.SHIMEI_KANA,
                                     A1.SHIMEI_KANJI,
                                     A1.SEINENGAPI,
                                     A1.SEIBETSU,
                                     A1.CHOMEI,
                                     A1.BANCHI,
                                     A1.KATAGAKI,
                                     A1.ZOKUGARA_CD1,
                                     A1.ZOKUGARA_CD2,
                                     A1.ZOKUGARA_CD3,
                                     A1.ZOKUGARA_CD4,
                                     A1.SHOGAKU_CD,
                                     A1.CHUGAKU_CD,
                                     A2.ZOKUGARA_CD1,
                                     A2.ZOKUGARA_CD2,
                                     A2.ZOKUGARA_CD3,
                                     A2.ZOKUGARA_CD4,
                                     A2.SHOGAKU_CD,
                                     A2.CHUGAKU_CD,
                                     B1.NUSHI_SHIMEI_KANA,
                                     B1.NUSHI_SHIMEI_KANJI,
                                     B2.IDO_BI,
                                     B2.IDO_JIYU,
                                     B2.IDO_TODOKE_BI,
                                     B2.NUSHI_SHIMEI_KANA,
                                     B2.NUSHI_SHIMEI_KANJI,
                                     rGKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA,
                                     rGKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI,
                                     rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA1,
                                     rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA2,
                                     rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA3,
                                     rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA4,
                                     A2.CHOMEI,
                                     A2.BANCHI,
                                     A2.KATAGAKI,
                                     A2.SHIMEI_KANA,
                                     A2.SHIMEI_KANJI,
                                     A2.SEINENGAPI,
                                     A2.SEIBETSU;        
                  EXIT WHEN cCURSOR%NOTFOUND;
                  
                  rGKBWGKRBJKSAI.MAE_JIDO_SHIMEI_KANJI   := A1.SHIMEI_KANJI;                           --変更前の児童生徒氏名
                  rGKBWGKRBJKSAI.MAE_JIDO_SHIMEI_KANA    := A1.SHIMEI_KANA;                            -- 変更前の児童生徒氏名カナ
--2024/11/02 ZCZL.WANGYUNING UPDATE START 0.3.000.006:IT_GKB_00286横展開対応
                  --rGKBWGKRBJKSAI.MAE_SEINENGAPI          :=  KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(A1.SEINENGAPI,'YYYYMMDD'), 'YYYY/MM/DD'), 12);    -- 変更前の生年月日
                  GKAPK00020.FGETSEINENGHYOUJI(A1.SEINENGAPI,o_sEINENGAPI1);
                  rGKBWGKRBJKSAI.MAE_SEINENGAPI          :=  KKAPK0020.FDateFmt(o_sEINENGAPI1.o_vYYYYMMDD_BACKSLASH, 12);    -- 変更前の生年月日
--2024/11/02 ZCZL.WANGYUNING UPDATE END
                  nRTN := KKAPK0030.FCDGetR('GKB', '021', '0001', A1.SEIBETSU, sMEISHO, sMEISHOKANA, sYOBI); 
                  rGKBWGKRBJKSAI.MAE_SEIBETSU            := sMEISHO;                                   -- 変更前の性別
                  -- 変更前の児童生徒住所
                  rGKBWGKRBJKSAI.MAE_JIDO_JUSHO          := GAAPK0010.FADDRESSEDIT(1, NULL, A1.CHOMEI, A1.BANCHI, A1.KATAGAKI, NULL);
                  -- 変更前の続柄
                  rGKBWGKRBJKSAI.MAE_ZOKUGARA            := GKBFKZKGMGET2(1, A1.ZOKUGARA_CD1, A1.ZOKUGARA_CD2, A1.ZOKUGARA_CD3, A1.ZOKUGARA_CD4);
                  IF rGKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI IS NULL THEN
                    rGKBWGKRBJKSAI.MAE_HOGOSHA_SHIMEI_KANJI:= NULL;                                    -- 変更前の保護者氏名
                  ELSE
                    rGKBWGKRBJKSAI.MAE_HOGOSHA_SHIMEI_KANJI:= rGKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI;  -- 変更前の保護者氏名
                  END IF;
                  IF rGKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA IS NULL THEN
                    rGKBWGKRBJKSAI.MAE_HOGOSHA_SHIMEI_KANA := NULL;                                    -- 変更前の保護者氏名カナ
                  ELSE
                    rGKBWGKRBJKSAI.MAE_HOGOSHA_SHIMEI_KANA := rGKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA;   -- 変更前の保護者氏名カナ;
                  END IF;
                  IF rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA1 IS NULL THEN
                    rGKBWGKRBJKSAI.MAE_HOGOSHA_ZOKUGARA    := NULL;                                    -- 変更前の保護者と児童生徒との関係
                  ELSE
                    rGKBWGKRBJKSAI.MAE_HOGOSHA_ZOKUGARA    := GKBFKZKGMGET2(2,                         -- 変更前の保護者と児童生徒との関係
                                                                            rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA1, 
                                                                            rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA2, 
                                                                            rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA3, 
                                                                            rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA4);
                  END IF;
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00075対応
--                  nRTN := KKAPK0030.FCDGetR('GKB', '021', '0001', A1.SHOGAKU_CD, sMEISHO, sMEISHOKANA, sYOBI);
                  nRTN := KKAPK0030.FCDGetR('GKB', '023', '0001', A1.SHOGAKU_CD, sMEISHO, sMEISHOKANA, sYOBI);
                  rGKBWGKRBJKSAI.MAE_SHITEI_SYOGAKKOKU   := sMEISHO;                                    -- 変更前の指定小学校区
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00075対応
--                  nRTN := KKAPK0030.FCDGetR('GKB', '021', '0002', A1.CHUGAKU_CD, sMEISHO, sMEISHOKANA, sYOBI);      
                  nRTN := KKAPK0030.FCDGetR('GKB', '023', '0002', A1.CHUGAKU_CD, sMEISHO, sMEISHOKANA, sYOBI);
                  rGKBWGKRBJKSAI.MAE_SHITEI_CHUGAKKOKU   := sMEISHO;                                    -- 変更前の指定中学校区
                  rGKBWGKRBJKSAI.MAE_NUSHI_SHIMEI_KANA   := B1.NUSHI_SHIMEI_KANA;                       -- 変更前の世帯主氏名カナ
                  rGKBWGKRBJKSAI.MAE_NUSHI_SHIMEI_KANJI  := B1.NUSHI_SHIMEI_KANJI;                      -- 変更前の世帯主氏名
                  rGKBWGKRBJKSAI.ATO_ZOKUGARA            := GKBFKZKGMGET2(1, A2.ZOKUGARA_CD1, A2.ZOKUGARA_CD2, A2.ZOKUGARA_CD3, A2.ZOKUGARA_CD4);         -- 変更後の続柄
                  rGKBWGKRBJKSAI.ATO_JIDO_IDO_JIYU       := GKBFKIDOJYGET(B2.IDO_JIYU);                 -- 変更後の児童生徒異動事由
--  2024/11/02 ZCZL.WANGYUNING UPDATE START 0.3.000.006:IT_GKB_00286横展開対応
                  --rGKBWGKRBJKSAI.ATO_JIDO_IDO_BI         :=  KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(B2.IDO_BI,'YYYYMMDD'), 'YYYY/MM/DD'), 12);         -- 変更後の児童生徒異動年月日
                  --rGKBWGKRBJKSAI.ATO_JIDO_TODOKEDEBI     :=  KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(B2.IDO_TODOKE_BI,'YYYYMMDD'), 'YYYY/MM/DD'), 12);  -- 変更後の児童生徒届出年月日
                  rGKBWGKRBJKSAI.ATO_JIDO_IDO_BI         :=  KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(B2.IDO_BI), 12);         -- 変更後の児童生徒異動年月日
                  rGKBWGKRBJKSAI.ATO_JIDO_TODOKEDEBI     :=  KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(B2.IDO_TODOKE_BI), 12);  -- 変更後の児童生徒届出年月日
--  2024/11/02 ZCZL.WANGYUNING UPDATE END
                  rGKBWGKRBJKSAI.ATO_JIDO_JUSHO          := GAAPK0010.FADDRESSEDIT(1, NULL, A2.CHOMEI, A2.BANCHI, A2.KATAGAKI, NULL);         -- 変更後の児童生徒住所
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00075対応
--                  nRTN := KKAPK0030.FCDGetR('GKB', '021', '0001', A2.SHOGAKU_CD, sMEISHO, sMEISHOKANA, sYOBI); 
                  nRTN := KKAPK0030.FCDGetR('GKB', '023', '0001', A2.SHOGAKU_CD, sMEISHO, sMEISHOKANA, sYOBI);
                  rGKBWGKRBJKSAI.ATO_SHITEI_SYOGAKKOKU   := sMEISHO;                                    -- 変更後の指定小学校区
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00075対応
--                  nRTN := KKAPK0030.FCDGetR('GKB', '021', '0002', A2.CHUGAKU_CD, sMEISHO, sMEISHOKANA, sYOBI);
                  nRTN := KKAPK0030.FCDGetR('GKB', '023', '0002', A2.CHUGAKU_CD, sMEISHO, sMEISHOKANA, sYOBI);
                  rGKBWGKRBJKSAI.ATO_SHITEI_CHUGAKKOKU   := sMEISHO;                                    -- 変更後の指定中学校区
                  rGKBWGKRBJKSAI.ATO_NUSHI_SHIMEI_KANA   := B2.NUSHI_SHIMEI_KANJI;                      -- 変更後の世帯主氏名カナ
                  rGKBWGKRBJKSAI.ATO_NUSHI_SHIMEI_KANJI  := B2.NUSHI_SHIMEI_KANA;                       -- 変更後の世帯主氏名
                  --エラー事由コードの取得
                  IF A1.SHIMEI_KANA <> A2.SHIMEI_KANA THEN
                    rGKBWGKRBJKSAI.ERA_JIYU_CD := 2;
                  ELSE
                    IF A1.SHIMEI_KANJI <> A2.SHIMEI_KANJI THEN
                      rGKBWGKRBJKSAI.ERA_JIYU_CD := 2;
                    ELSE
                      IF A1.SEINENGAPI <> A2.SEINENGAPI THEN
                        rGKBWGKRBJKSAI.ERA_JIYU_CD := 3;
                      ELSE
                        IF A1.SEIBETSU <> A2.SEIBETSU THEN
                          rGKBWGKRBJKSAI.ERA_JIYU_CD := 4;
                        ELSE
                          IF A1.CHOMEI <> A2.CHOMEI THEN
                            rGKBWGKRBJKSAI.ERA_JIYU_CD := 5;
                          ELSE
                            IF A1.BANCHI <> A2.BANCHI THEN
                              rGKBWGKRBJKSAI.ERA_JIYU_CD := 5;
                            ELSE
                              IF A1.KATAGAKI <> A2.KATAGAKI THEN
                                rGKBWGKRBJKSAI.ERA_JIYU_CD := 5;
                              ELSE
                                IF B1.NUSHI_SHIMEI_KANJI <> B2.NUSHI_SHIMEI_KANJI THEN
                                  rGKBWGKRBJKSAI.ERA_JIYU_CD := 6;
                                ELSE
                                  IF A1.ZOKUGARA_CD1 <> A2.ZOKUGARA_CD1 THEN
                                    rGKBWGKRBJKSAI.ERA_JIYU_CD := 7;
                                  ELSE
                                    IF A1.ZOKUGARA_CD2 <> A2.ZOKUGARA_CD2 THEN
                                      rGKBWGKRBJKSAI.ERA_JIYU_CD := 7;
                                    ELSE
                                      IF A1.ZOKUGARA_CD3 <> A2.ZOKUGARA_CD3 THEN
                                        rGKBWGKRBJKSAI.ERA_JIYU_CD := 7;
                                      ELSE
                                        IF A1.ZOKUGARA_CD4 <> A2.ZOKUGARA_CD4 THEN
                                          rGKBWGKRBJKSAI.ERA_JIYU_CD := 7;
                                        ELSE
                                          IF A1.SHOGAKU_CD <> A2.SHOGAKU_CD THEN
                                            rGKBWGKRBJKSAI.ERA_JIYU_CD := 8;
                                          ELSE
                                            IF A1.CHUGAKU_CD <> A2.CHUGAKU_CD THEN
                                              rGKBWGKRBJKSAI.ERA_JIYU_CD := 9;
                                            ELSE
                                              NULL;
                                            END IF;
                                          END IF;
                                        END IF;
                                      END IF;
                                    END IF;
                                  END IF;
                                END IF;
                              END IF;
                            END IF;
                          END IF;
                        END IF;
                      END IF;
                    END IF;
                  END IF;
                  nRTN := KKAPK0030.FCDGetR('GKB', '041', '0000', rGKBWGKRBJKSAI.ERA_JIYU_CD, sMEISHO, sMEISHOKANA, sYOBI);
                  rGKBWGKRBJKSAI.BIKO                    := sMEISHO;                                      -- 備考
                  rGKBWGKRBJKSAI.JIDO_KOJIN_NO_SORT      := A1.KOJIN_NO;                                  -- 宛名番号（ソート用）
                  rGKBWGKRBJKSAI.SEINENGAPI_SORT         := A1.SEINENGAPI;                                -- 生年月日（ソート用）
                  --登録中間ワークテーブル
                  INSERT INTO GKBWGKRBJKSAI VALUES rGKBWGKRBJKSAI;
                END LOOP;
              CLOSE cCURSOR;
            ELSE
              NULL;
            END IF;
        END LOOP;
      CLOSE cCURSOR1;
      --件数取得
      nCOUNT := GKBFKTBLCNT('GKBWGKRBJKSAI',NULL);
      --書込ファイルを開く
      BEGIN   
          nRTN := KKAPK0090.FDLWorkOpen ('GKBWDB005701',
                                         io_nRIREKISEQ, 
                                         1, 
                                         '学齢簿・住基差異チェックリスト',
                                         'GKRBJKSAI.csv', 
                                         '',
                                         g_sTANTOCODE,
                                         g_sWSNUM,
                                         '');
          --書込ファイル出力
          IF KKAPK0090.FDLWorkPutNC (sOutData, 'UTF8', 1) = 1 THEN
              RAISE eFILEPUT;
          END IF;
      EXCEPTION
          WHEN eFILEPUT THEN
              RAISE;
      END;
      -- ＣＳＶフィールドセット
      sSQL4 := '';
      sSQL4 := 'SELECT *';
      sSQL4 := sSQL4 || 'FROM GKBWGKRBJKSAI '; 
      sSQL4 := sSQL4 || 'ORDER BY ERA_JIYU_CD,JIDO_KOJIN_NO_SORT,SEINENGAPI_SORT ASC'; 
--  2024/10/25 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00213対応
      nCOUNT1 := 0;
      
      w_sBUFF_HEAD := '';
      w_sBUFF_HEAD := '変更前の児童生徒氏名';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の児童生徒氏名カナ';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の生年月日';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の性別';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の児童生徒住所';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の続柄';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の保護者氏名';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の保護者氏名カナ';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の保護者と児童生徒との関係';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の指定小学校区';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の指定中学校区';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の世帯主氏名カナ';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更前の世帯主氏名';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更後の続柄';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更後の児童生徒異動事由';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更後の児童生徒異動年月日';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更後の児童生徒届出年月日';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更後の児童生徒住所';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更後の指定小学校区';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更後の指定中学校区';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更後の世帯主氏名カナ';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'変更後の世帯主氏名';
      w_sBUFF_HEAD := w_sBUFF_HEAD || ',' ||'備考';

      --書込ファイル出力
      IF KKAPK0090.FDLWorkPutNC (w_sBUFF_HEAD, 'UTF8', 1) = 1 THEN
          RAISE eFILEPUT;
      END IF;
--  2024/10/25 ZCZL.WANGYUNING ADD END      

      OPEN cCURSORWL FOR sSQL4;
      LOOP
          FETCH cCURSORWL INTO rDATA;
          EXIT WHEN cCURSORWL%NOTFOUND;        
          w_sBUFF := '';
          w_sBUFF := rDATA.MAE_JIDO_SHIMEI_KANJI;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_JIDO_SHIMEI_KANA;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_SEINENGAPI;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_SEIBETSU;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_JIDO_JUSHO;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_ZOKUGARA;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_HOGOSHA_SHIMEI_KANJI;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_HOGOSHA_SHIMEI_KANA;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_HOGOSHA_ZOKUGARA;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_SHITEI_SYOGAKKOKU;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_SHITEI_CHUGAKKOKU;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_NUSHI_SHIMEI_KANA;
          w_sBUFF := w_sBUFF || ',' || rDATA.MAE_NUSHI_SHIMEI_KANJI; 
          w_sBUFF := w_sBUFF || ',' || rDATA.ATO_ZOKUGARA;
          w_sBUFF := w_sBUFF || ',' || rDATA.ATO_JIDO_IDO_JIYU;  
          w_sBUFF := w_sBUFF || ',' || rDATA.ATO_JIDO_IDO_BI;
          w_sBUFF := w_sBUFF || ',' || rDATA.ATO_JIDO_TODOKEDEBI;
          w_sBUFF := w_sBUFF || ',' || rDATA.ATO_JIDO_JUSHO;
          w_sBUFF := w_sBUFF || ',' || rDATA.ATO_SHITEI_SYOGAKKOKU;
          w_sBUFF := w_sBUFF || ',' || rDATA.ATO_SHITEI_CHUGAKKOKU;
          w_sBUFF := w_sBUFF || ',' || rDATA.ATO_NUSHI_SHIMEI_KANA;
          w_sBUFF := w_sBUFF || ',' || rDATA.ATO_NUSHI_SHIMEI_KANJI; 
          w_sBUFF := w_sBUFF || ',' || rDATA.BIKO;

          --書込ファイル出力
          IF KKAPK0090.FDLWorkPutNC (w_sBUFF, 'UTF8', 1) = 1 THEN
              RAISE eFILEPUT;
          END IF;
          nCOUNT1 := nCOUNT1 + 1;       -- CSV出力件数
      END LOOP;
      CLOSE cCURSORWL;

      IF KKAPK0090.FDLWorkClose = 1 THEN
          RAISE eFILEPUT;
      END IF;
      IF NOT KKBPK5551.FKKBVJCTLGET (g_nJOBNUM, g_sGYOUMUCODE, g_sGROUPCODE, g_sSHORINAME) THEN
          RAISE eSHORIEXCEPTION;
      END IF;
      IF KKAPK0090.FDLCtlPut (g_sGYOUMUCODE,g_sGROUPCODE, g_sSHORINAME, g_nJOBNUM) = 1 THEN
          RAISE eSHORIEXCEPTION;
      END IF;

      --学齢簿・住基差異チェックリスト件数
      g_nINDEX := g_nINDEX + 1;
      g_oKENSU_LIST.EXTEND(1);
      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT,'入力 学齢簿・住基差異チェックリスト対象件数',1);
      --学齢簿・住基差異チェックリスト件数
      g_nINDEX := g_nINDEX + 1;
      g_oKENSU_LIST.EXTEND(1);
      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT1,'出力 学齢簿・住基差異チェックリストＣＳＶ',2);

      --関数終了
      bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV作成処理', 0, '', '', '学齢簿・住基差異チェックリストＣＳＶ' || nCOUNT1 ||'件を出力しました', g_sTANTOCODE, g_sWSNUM, 1);
      RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
          IF cCURSOR%ISOPEN THEN
            CLOSE cCURSOR;
          END IF;
          IF cCURSOR1%ISOPEN THEN
            CLOSE cCURSOR1;
          END IF;
          IF cCURSORWL%ISOPEN THEN
            CLOSE cCURSORWL;
          END IF;
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV作成処理', 1, SQLCODE, SQLERRM, 'ＣＳＶファイルの書き出し処理が異常終了しました', g_sTANTOCODE, g_sWSNUM, 1);
          RETURN c_ERR;
    END FUNC_CSV_CREATE;
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu 2024/06/14
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
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;                    --戻り値
        nRTN             PLS_INTEGER;                --戻る値
        sDATE            NVARCHAR2(20);
        ERR              EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        
        --条件取得処理を呼び出す。
        bRTN := FUNC_JYOKEN_GET;
        IF NOT bRTN THEN
            RAISE ERR;
        END IF;
        
        --初期処理を呼び出す。
        bRTN := FUNC_INIT;
        IF NOT bRTN THEN
            RAISE ERR;
        END IF;
        --ワーク初期化
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--        DELETE FROM GKBWDB005701;
        --ＣＳＶファイル作成処理を呼び出す。
        nRTN := FUNC_CSV_CREATE;
        IF nRTN <> 0 THEN
          RAISE ERR;
        END IF;

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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lwy   2024/07/01
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
        --処理ステップ連番が終了するまで繰り返す
        FOR i IN 1..nSTEPSEQ_MAX LOOP

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
END GKBPB00570;
/
