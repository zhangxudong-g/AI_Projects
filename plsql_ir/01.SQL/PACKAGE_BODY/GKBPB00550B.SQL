CREATE OR REPLACE PACKAGE BODY GKBPB00550
--1.0.403.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 支援措置対象者一覧作成
--  機能概要      : 「支援措置対象者一覧」を出力する処理を追加する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.lujian   2024/06/28
--------------------------------------------------------
--  変更履歴
--  2024/09/03 ZCZL.WANGMING Add 0.3.000.001:IT_GKB_00075対応
--  2024/09/05 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00114対応の横展開
--  2024/10/28 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00316仕様変更対応
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00286横展開対応
--  2024/11/11 ZCZL.ZHANGLEI UPDATE 0.3.000.006:IT_GKB_00449仕様変更対応
--  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.007:IT_GKB_00603仕様変更対応
--  2025/01/27 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:ST_GKB_TMP00015仕様変更対応
--  2025/06/27 CTC.GL UPDATE 1.0.010.000:GKB_QA17602対応
--  2025/09/17 CTC.GL UPDATE 1.0.105.001:GKB_QA20944対応
--  2025/12/15 CTC.GL UPDATE 1.0.403.000:GKB_QA22980対応
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
    g_nTIME                       NUMBER;                      --システム時間
    g_nREBAN                      NUMBER := 0;                 --連番
    g_nINDEX                      NUMBER := 0;
    g_oKENSU_LIST                 GKBEKENSU_LIST := GKBEKENSU_LIST();

    --変数宣言
    g_nSORT                       NUMBER := 0;                 --ソート順
    g_sSEYIGYO                    NVARCHAR2(1000);            --支援措置対象一覧表_出力制御
    -- ERROR関連 --
    VSQLERRM                      VARCHAR(255);       -- SQLエラーメッセージ
    --画面入力条件
    g_vJYOUKEN01                  NVARCHAR2(1000);
    g_vJYOUKEN02                  NVARCHAR2(1000);
    g_nJYOUKEN02                  PLS_INTEGER;        -- 変数.基準日
--  2025/12/15 CTC.GL UPDATE START 1.0.403.000:GKB_QA22980対応
    V_ORDERBY                     NVARCHAR2(4000);
--  2025/12/15 CTC.GL UPDATE END
    --DB・ファイル等更新説明書（学齢簿_カーソル)
    TYPE R_KOJIN_NO IS RECORD ( SETAIYOKUSHIKBN         GACTKANRI_SONOTAGYOMU.SETAIYOKUSHIKBN%TYPE,
                                TOROKU_GYOMU            GACTKANRI_SONOTAGYOMU.TOROKU_GYOMU%TYPE,
                                SHIENSOCHIKBN           GACTKANRI_SONOTAGYOMU.SHIENSOCHIKBN%TYPE,
                                SHIENSOCHISHURYOKBN     GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN%TYPE,
                                SHIENSOCHIKAISHIBI      NUMBER,
                                SHIENSOCHISHURYOBI      NUMBER,
                                TAISHOSHAKBN            GACTKANRI_MOUSHIDE.TAISHOSHAKBN%TYPE,
                                KARISHIENSOCHIKAISHIBI  GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI%TYPE,
                                KARISHIENSOCHISHURYOBI  GACTKANRI_MOUSHIDE.KARISHIENSOCHISHURYOBI%TYPE,
                                SHIENSOCHIKAIJOBI       GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI%TYPE
                                ); 
    --DB・ファイル等更新説明書（保護者_S) 
    TYPE R_HOGOSHA_KOJIN_NO IS RECORD ( 
                                SETAIYOKUSHIKBN         GACTKANRI_SONOTAGYOMU.SETAIYOKUSHIKBN%TYPE,
                                TOROKU_GYOMU            GACTKANRI_SONOTAGYOMU.TOROKU_GYOMU%TYPE,
                                SHIENSOCHIKBN           GACTKANRI_SONOTAGYOMU.SHIENSOCHIKBN%TYPE,
                                SHIENSOCHISHURYOKBN     GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN%TYPE,
                                SHIENSOCHIKAISHIBI      NUMBER,
                                SHIENSOCHISHURYOBI      NUMBER,
                                TAISHOSHAKBN            GACTKANRI_MOUSHIDE.TAISHOSHAKBN%TYPE,
                                KARISHIENSOCHIKAISHIBI  GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI%TYPE,
                                KARISHIENSOCHISHURYOBI  GACTKANRI_MOUSHIDE.KARISHIENSOCHISHURYOBI%TYPE,
                                SHIENSOCHIKAIJOBI       GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI%TYPE
                                ); 
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
    --  作成者／作成日: ZCZL.lujian   2024/06/28
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
    --  作成者／作成日: ZCZL.lujian   2024/06/28
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
    --  作成者／作成日: ZCZL.lujian   2024/06/28
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
--  2024/09/03 ZCZL.WANGMING ADD 0.3.000.001:IT_GKB_00075対応
      cmbSakuseiKbn     DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        --抽出対象
--  2024/09/03 ZCZL.WANGMING UPDATE START 0.3.000.001:IT_GKB_00075対応
--        g_vJYOUKEN01 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtTakeObject');
        cmbSakuseiKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'txtTakeObject');
        g_vJYOUKEN01 := cmbSakuseiKbn(1);
--  2024/09/03 ZCZL.WANGMING UPDATE END
        --基準日
        g_vJYOUKEN02 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtBaseDateYmd');
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
    --  作成者／作成日: ZCZL.lujian   2024/06/28
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
    --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.007:IT_GKB_00603仕様変更対応 Start
    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 日付チェック
    --  パラメータ    : i_VHIZUKE
    --            : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 ,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: JPJYS 2024/11/18
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIZUKECHK(i_VHIZUKE IN NVARCHAR2)
    RETURN NUMBER IS
    IRET PLS_INTEGER;
    BRET BOOLEAN;
    TEMP_DATE DATE;
      --日付変換パラメータ
      IWAREKIHIDUKEIO  PLS_INTEGER;
      ISEIREKIHIDUKEIO PLS_INTEGER;
      VEDIT1O          NVARCHAR2(20);
      VEDIT2O          NVARCHAR2(20);
      VEDIT3O          NVARCHAR2(20);
      VGENGOKANJIO     NVARCHAR2(10);
      VGENGOKIGOO      NVARCHAR2(10);
      IWAREKINENO      PLS_INTEGER;
      ISEIREKINENO     PLS_INTEGER;
      IWAREKINENGETUO  PLS_INTEGER;
      ITUKIO           PLS_INTEGER;
      IDAYO            PLS_INTEGER;
      IWAREKIHIDUKEO   PLS_INTEGER;
      ISEIREKIHIDUKEO  PLS_INTEGER;
    BEGIN
      IRET := 0;
      --日付
      BEGIN
          IF LENGTH(i_VHIZUKE) <> 7 THEN
            IRET := 1;
          ELSE
            IWAREKIHIDUKEIO  := TO_NUMBER(i_VHIZUKE);
            ISEIREKIHIDUKEIO := 0;
          END IF;

        IF IRET = 0 AND LENGTH(IWAREKIHIDUKEIO) = 7 THEN
          BRET      := KKAPK0020.FDAYEDIT(IWAREKIHIDUKEIO,
                                           ISEIREKIHIDUKEIO,
                                           VEDIT1O,
                                           VEDIT2O,
                                           VEDIT3O,
                                           VGENGOKANJIO,
                                           VGENGOKIGOO,
                                           IWAREKINENO,
                                           ISEIREKINENO,
                                           IWAREKINENGETUO,
                                           ITUKIO,
                                           IDAYO,
                                           IWAREKIHIDUKEO,
                                           ISEIREKIHIDUKEO);
          TEMP_DATE := TO_DATE(ISEIREKIHIDUKEIO, 'YYYYMMDD');
          IF BRET = FALSE THEN
            IRET := 1;
          END IF;
        END IF;

      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      RETURN(IRET);
    END FUNCHIZUKECHK;
    --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.007:IT_GKB_00603仕様変更対応 End
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lujian   2024/06/28
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN       BOOLEAN;          --戻り値
        VMSG       NVARCHAR2(4000);  --エラーメッセージ
        --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.007:IT_GKB_00603仕様変更対応 Start
        IRTN       PLS_INTEGER;
        --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.007:IT_GKB_00603仕様変更対応 End
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
-- 2024/09/03 ZCZL.WANGMING Add 0.3.000.001:IT_GKB_00075対応
        VMSG := '';
        --入力値チェック
        --基準日の数値型変換ﾁｪｯｸ
--  2024/09/20 ZCZL.WANGMING UPDATE START 0.3.000.003:IT_GKB_00114対応の横展開
--        IF g_vJYOUKEN02 IS NOT NULL THEN
--  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.007:IT_GKB_00603仕様変更対応 Start
          --bRTN := kKAPK0010.FISNUMERIC(g_vJYOUKEN02);
          --IF NOT bRTN THEN
          --    VMSG := g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;' ;
          --ELSE
          --    bRTN := KKAPK0020.FISDATEW(g_vJYOUKEN02);
          --    IF NOT bRTN THEN
          --       VMSG := g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
          --    END IF;
          --END IF ;
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN02);
        IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;' ;
        END IF;
--  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.007:IT_GKB_00603仕様変更対応 End
--          bRTN := KKAPK0020.FISDATEW(g_vJYOUKEN02);
--          IF NOT bRTN THEN
--            VMSG := VMSG || g_sGYOUMUCODE || ',99999, 基準日が正しくありません。,;';
--          END IF;
--          bRTN := KKAPK0010.FISNUMERIC(g_vJYOUKEN02);
--          IF NOT bRTN THEN
--            VMSG := VMSG || g_sGYOUMUCODE || ', 99999, 基準日が正しくありません。,;';
--          END IF;
--        END IF;
--  2024/09/20 ZCZL.WANGMING UPDATE END
        IF VMSG IS NOT NULL THEN
          o_vRESULT := VMSG;
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
    --  作成者／作成日: ZCZL.lujian   2024/06/28
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lujian   2024/06/28
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
    --  機能概要      : 条件取得処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lujian   2024/06/28
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET
        RETURN BOOLEAN
    IS
    BEGIN
      --戻り値を変数.基準日に設定する。
      g_nJYOUKEN02 := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN02);
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
    --  作成者／作成日: ZCZL.lujian   2024/06/28
    --------------------------------------------------------
    FUNCTION FUNC_INIT
        RETURN BOOLEAN
    IS
        nRTN                    PLS_INTEGER;                --戻る値
        aITEM                   A_CONS_PRM;                 --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        sINDEXNO                NUMBER;                     --変数.支援措置対象一覧表_インデックス番号
    BEGIN
      --共通関数（テーブルデータ削除プロシジャ）(KKAPK3000.FTRUNCATE)を呼び出し、支援措置対象者一覧中間ワークファイルをクリアする。
      nRTN := KKAPK3000.FTRUNCATE('GKAWSHIENTAISHOSHA', VSQLERRM);
      
      --システム制御設定を取得する
        -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aITEM);
        --「GKA000R002」が格納されている箇所のインデックス番号
        IF nRTN = 0 THEN
          FOR i IN 1..aITEM.COUNT LOOP
            IF aITEM(i) = 'GKA000R002' THEN
              sINDEXNO := i;
              EXIT;
            END IF;
          END LOOP;
          -- 「本名・通称名　出力制御」のリストを取得する
          nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aITEM);
          IF nRTN = 0 THEN
            g_sSEYIGYO := aITEM(sINDEXNO);
          END IF;
        END IF;
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
    --  作成者／作成日: ZCZL.lujian   2024/06/28
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE
        RETURN NUMBER
    IS
        bRTN                            BOOLEAN;                               --戻り値
        nRTN                            PLS_INTEGER;                           --戻る値
        nCOUNT                          PLS_INTEGER;                           --抽出件数
        sSQL                            VARCHAR2(5000);
        sSQL2                           VARCHAR2(5000);
        sSQL3                           VARCHAR2(5000);
        sSQL4                           VARCHAR2(5000);
        TYPE MC_CURSOR IS REF           CURSOR;                                --カーソルタイプ定義
        cCURSOR                         MC_CURSOR;
        cCURSORSQL2                     MC_CURSOR;
        cCURSORSQL3                     MC_CURSOR;
        cCURSORWL                       MC_CURSOR;
        rGKAWSHIENTAISHOSHA             GKAWSHIENTAISHOSHA%ROWTYPE;            --支援措置対象者一覧中間ワーク
        rWLTBL                          GKAWL000R002%ROWTYPE;                  --支援措置対象者一覧ワーク
        rGKBTGAKUREIBO                  GKBTGAKUREIBO%ROWTYPE;                 --学齢簿
        sMEISHO                         NVARCHAR2(1000);                       --名称
        sMEISHOKANA                     NVARCHAR2(1000);                       --名称カナ
        sYOBI                           NVARCHAR2(1000);                       --予備
        sMEISHO1                        NVARCHAR2(1000);                       --名称
        sMEISHOKANA1                    NVARCHAR2(1000);                       --名称カナ
        sYOBI1                          NVARCHAR2(1000);                       --予備
        vZOKUGARAMEI                    NVARCHAR2(1000);                       --続柄名称
        nIHERR                          PLS_INTEGER;                           --エラーコード
        sKOKUMEI_KANA                   NVARCHAR2(1000);                       --国名カナ
        sKOKUMEI                        NVARCHAR2(1000);                       --国名
        sKOKUMEI_ALPHABET               NVARCHAR2(1000);                       --国名アルファベット
        sKOKUMEI_KANA1                  NVARCHAR2(1000);                       --国名カナ
        sKOKUMEI1                       NVARCHAR2(1000);                       --国名
        sKOKUMEI_ALPHABET1              NVARCHAR2(1000);                       --国名アルファベット
        nJYOUKEN02                      PLS_INTEGER;                           --基準日
        o_RCK                           R_KOJIN_NO;
        o_RCHK                          R_HOGOSHA_KOJIN_NO;
        o_sWAREKIDATE                   NVARCHAR2(1000);
        vSHIMEI_KANA                    NVARCHAR2(100);
        vSHIMEI_KANJI                   NVARCHAR2(100);
        vSEINENGAPI                     NVARCHAR2(100);
        vSHIMEI_KANA1                   NVARCHAR2(100);
        vSHIMEI_KANJI1                  NVARCHAR2(100);
        vSEINENGAPI1                    NVARCHAR2(100);
        -- 宛名情報取得用
        RATENA_HOGOSHA                  GABTATENAKIHON%ROWTYPE;
        RSOFU_HOGOSHA                   GABTSOFUSAKI%ROWTYPE;
        -- 児童宛名情報取得用
        RATENA_JIDO                     GABTATENAKIHON%ROWTYPE;
        RSOFU_JIDO                      GABTSOFUSAKI%ROWTYPE;
        JIDO_ISFLG                      PLS_INTEGER;                           --児童有効フラグ
        HOGOSHA_ISFLG                   PLS_INTEGER;                           --保護者有効
--2025/09/17 CTC.GL UPDATE START 1.0.105.001:GKB_QA20944対応
        v_JIDO_START_NUM                PLS_INTEGER := 0;       -- 児童生徒支援措置開始年月日
        v_JIDO_END_NUM                  PLS_INTEGER := 0;       -- 児童生徒支援措置終了年月日
        v_HOGOSHA_START_NUM             PLS_INTEGER := 0;       -- 保護者支援措置開始年月日
        v_HOGOSHA_END_NUM               PLS_INTEGER := 0;       -- 保護者支援措置終了年月日
        JIDO_FLG                        BOOLEAN;
        HOGOSHA_FLG                     BOOLEAN;
--2025/09/17 CTC.GL UPDATE END
    BEGIN
      --変数.基準日（未入力の場合、システム日付）
      IF g_nJYOUKEN02 IS NULL THEN
        nJYOUKEN02 := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
      ELSE
        nJYOUKEN02 := g_nJYOUKEN02;
      END IF;
      --DB・ファイル等更新説明書（学齢簿_カーソル)
      sSQL := '';
      sSQL := 'SELECT';
      sSQL := sSQL || ' GKBTGAKUREIBO.KOJIN_NO';
      sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_KOJIN_NO';
      sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1';
      sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2';
      sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3';
      sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4';
      sSQL := sSQL || ',GKBTGAKUREIBO.SEIBETSU';
      sSQL := sSQL || ',GKBTGAKUREIBO.SYOGAKO_CD';
      sSQL := sSQL || ',GKBTGAKUREIBO.TYUGAKO_CD';
      sSQL := sSQL || ',GKBTGAKUREIBO.KUIKIGAI_CD';
      sSQL := sSQL || ',GKBTGAKUREIBO.YOGOGAKO_CD';
      sSQL := sSQL || ',GKBTGAKUREIBO.KUNISHIRITSU_CD';
      sSQL := sSQL || ',GKBTGAKUREIBO.GAKKO_KBN_CD';
      sSQL := sSQL || ',GKBTGAKUREIBO.TENNYUMAE_GAKKO_KBN';
      sSQL := sSQL || ',GKBTGAKUREIBO.GAKUNEN';
      sSQL := sSQL || ' FROM GKBTGAKUREIBO ';
      --  2024/11/11 ZCZL.ZHANGLEI UPDATE 0.3.000.006:IT_GKB_00449仕様変更対応
      --sSQL := sSQL || ' WHERE GKBTGAKUREIBO.GEN_NENGAPI IS NULL';
      sSQL := sSQL || ' WHERE NVL(GKBTGAKUREIBO.GEN_NENGAPI,0) = 0';
      sSQL := sSQL || ' AND GKBTGAKUREIBO.SAISHIN_KBN = 0';
      sSQL := sSQL || ' AND GKBTGAKUREIBO.SAKUJO_FLG = 0';

      OPEN cCURSOR FOR sSQL;
        LOOP
          FETCH cCURSOR INTO rGKBTGAKUREIBO.KOJIN_NO
                             ,rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA1
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA2
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA3
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA4
                             ,rGKBTGAKUREIBO.SEIBETSU
                             ,rGKBTGAKUREIBO.SYOGAKO_CD
                             ,rGKBTGAKUREIBO.TYUGAKO_CD
                             ,rGKBTGAKUREIBO.KUIKIGAI_CD
                             ,rGKBTGAKUREIBO.YOGOGAKO_CD
                             ,rGKBTGAKUREIBO.KUNISHIRITSU_CD
                             ,rGKBTGAKUREIBO.GAKKO_KBN_CD
                             ,rGKBTGAKUREIBO.TENNYUMAE_GAKKO_KBN
                             ,rGKBTGAKUREIBO.GAKUNEN;
          EXIT WHEN cCURSOR%NOTFOUND;
          --DB・ファイル等更新説明書（児童_S)
          o_RCK := NULL;
          sSQL2 := '';
          sSQL2 := 'SELECT';
          sSQL2 := sSQL2 || ' GACTKANRI_SONOTAGYOMU.SETAIYOKUSHIKBN AS SETAIYOKUSHIKBN';
          sSQL2 := sSQL2 || ',GACTKANRI_SONOTAGYOMU.TOROKU_GYOMU AS TOROKU_GYOMU';
          sSQL2 := sSQL2 || ',GACTKANRI_SONOTAGYOMU.SHIENSOCHIKBN AS SHIENSOCHIKBN';
          sSQL2 := sSQL2 || ',GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN AS SHIENSOCHISHURYOKBN';
          sSQL2 := sSQL2 || ',GACTKANRI_SONOTAGYOMU.SHIENSOCHIKAISHIBI AS SHIENSOCHIKAISHIBI';
          sSQL2 := sSQL2 || ',GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOBI AS SHIENSOCHISHURYOBI';
          sSQL2 := sSQL2 || ',NULL AS TAISHOSHAKBN';
          sSQL2 := sSQL2 || ',NULL AS KARISHIENSOCHIKAISHIBI';
          sSQL2 := sSQL2 || ',NULL AS KARISHIENSOCHISHURYOBI';
          sSQL2 := sSQL2 || ',NULL AS SHIENSOCHIKAIJOBI';
          sSQL2 := sSQL2 || ' FROM GACTKANRI_SONOTAGYOMU ';
          sSQL2 := sSQL2 || ' WHERE GACTKANRI_SONOTAGYOMU.TOROKU_GYOMU = ''GKB'' ';
          sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.KOJIN_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
          -- ①変数.抽出対象　＝　0（支援中のみ）　の場合
          IF g_vJYOUKEN01 = '0' THEN
            sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHIKBN IN (1, 2) ';
            --  2024/10/28 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00316仕様変更対応
            --sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN <> 3 ';
            sSQL2 := sSQL2 || ' AND NVL(GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN,0) <> 3 ';
            sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.RIREKI_NO = ( ';
            sSQL2 := sSQL2 || ' SELECT MAX(GACTKANRI_SONOTAGYOMU.RIREKI_NO) ';
            sSQL2 := sSQL2 || ' FROM GACTKANRI_SONOTAGYOMU ';
            sSQL2 := sSQL2 || ' WHERE GACTKANRI_SONOTAGYOMU.TOROKU_GYOMU = ''GKB'' ';
            sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.KOJIN_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
            sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHIKBN IN (1, 2) ';
            --  2024/10/28 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00316仕様変更対応
            --sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN <> 3) ';
            sSQL2 := sSQL2 || ' AND NVL(GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN,0) <> 3) ';
          END IF;
          --②変数.抽出対象　＝　1（支援措置終了含む）　の場合
          IF g_vJYOUKEN01 = '1' THEN
            sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.RIREKI_NO = ( ';
            sSQL2 := sSQL2 || ' SELECT MAX(GACTKANRI_SONOTAGYOMU.RIREKI_NO) ';
            sSQL2 := sSQL2 || ' FROM GACTKANRI_SONOTAGYOMU ';
            sSQL2 := sSQL2 || ' WHERE GACTKANRI_SONOTAGYOMU.TOROKU_GYOMU = ''GKB'' ';
            sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.KOJIN_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
            sSQL2 := sSQL2 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02 || ')';
          END IF;
          sSQL2 := sSQL2 || ' UNION ALL ';
          sSQL2 := sSQL2 || 'SELECT';
          sSQL2 := sSQL2 || ' NULL AS SETAIYOKUSHIKBN';
          sSQL2 := sSQL2 || ',NULL AS TOROKU_GYOMU';
          sSQL2 := sSQL2 || ',NULL AS SHIENSOCHIKBN';
          sSQL2 := sSQL2 || ',NULL AS SHIENSOCHISHURYOKBN';
          sSQL2 := sSQL2 || ',GACTKANRI_MOUSHIDE.SHIENSOCHIKAISHIBI AS SHIENSOCHIKAISHIBI';
          sSQL2 := sSQL2 || ',GACTKANRI_MOUSHIDE.SHIENSOCHISHURYOBI AS SHIENSOCHISHURYOBI';
          sSQL2 := sSQL2 || ',GACTKANRI_MOUSHIDE.TAISHOSHAKBN AS TAISHOSHAKBN';
          sSQL2 := sSQL2 || ',GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI AS KARISHIENSOCHIKAISHIBI';
          sSQL2 := sSQL2 || ',GACTKANRI_MOUSHIDE.KARISHIENSOCHISHURYOBI AS KARISHIENSOCHISHURYOBI';
          sSQL2 := sSQL2 || ',GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI AS SHIENSOCHIKAIJOBI';
          sSQL2 := sSQL2 || ' FROM ';
          sSQL2 := sSQL2 || 'GACTKANRI_MOUSHIDE ';
          sSQL2 := sSQL2 || 'WHERE ';
          -- ①変数.抽出対象　＝　0（支援中のみ）　の場合
          IF g_vJYOUKEN01 = '0' THEN
            sSQL2 := sSQL2 || ' GACTKANRI_MOUSHIDE.KOJIN_NO IN ( ';
            sSQL2 := sSQL2 || ' SELECT KOJIN_NO FROM( ';
            sSQL2 := sSQL2 || '   SELECT GM.KOJIN_NO ,GM.TAISHOSHAKBN ,GM.TAISHO_ATENA_NO';
            sSQL2 := sSQL2 || '   FROM GACTKANRI_MOUSHIDE GM';
            sSQL2 := sSQL2 || '   WHERE GM.TAISHO_ATENA_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
            sSQL2 := sSQL2 || '   AND GM.TAISHOSHAKBN = 1';
            sSQL2 := sSQL2 || '   UNION ALL';
            sSQL2 := sSQL2 || '   SELECT GM.KOJIN_NO ,GM.TAISHOSHAKBN ,GM.TAISHO_ATENA_NO';
            sSQL2 := sSQL2 || '   FROM GACTKANRI_MOUSHIDE GM';
            sSQL2 := sSQL2 || '   WHERE GM.KOJIN_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
            sSQL2 := sSQL2 || '   AND GM.TAISHOSHAKBN = 0))';
            sSQL2 := sSQL2 || ' AND GACTKANRI_MOUSHIDE.TAISHOSHAKBN = 0 ';
            sSQL2 := sSQL2 || ' AND((GACTKANRI_MOUSHIDE.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL2 := sSQL2 || '  AND ( CASE WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NOT NULL THEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI ';
            sSQL2 := sSQL2 || '  WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NULL THEN NVL(GACTKANRI_MOUSHIDE.SHIENSOCHISHURYOBI,99999999) END >= ' || nJYOUKEN02 || ')) ';
            sSQL2 := sSQL2 || ' OR (GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL2 := sSQL2 || ' AND (CASE WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NOT NULL THEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI ';
            sSQL2 := sSQL2 || ' WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NULL THEN NVL(GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI,99999999) END >= ' || nJYOUKEN02 || ' ))) ';
            sSQL2 := sSQL2 || ' AND GACTKANRI_MOUSHIDE.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) FROM GACTKANRI_MOUSHIDE WHERE ';
            sSQL2 := sSQL2 || ' GACTKANRI_MOUSHIDE.KOJIN_NO IN ( ';
            sSQL2 := sSQL2 || ' SELECT KOJIN_NO FROM( ';
            sSQL2 := sSQL2 || '   SELECT GM.KOJIN_NO ,GM.TAISHOSHAKBN ,GM.TAISHO_ATENA_NO';
            sSQL2 := sSQL2 || '   FROM GACTKANRI_MOUSHIDE GM';
            sSQL2 := sSQL2 || '   WHERE GM.TAISHO_ATENA_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
            sSQL2 := sSQL2 || '   AND GM.TAISHOSHAKBN = 1';
            sSQL2 := sSQL2 || '   UNION ALL';
            sSQL2 := sSQL2 || '   SELECT GM.KOJIN_NO ,GM.TAISHOSHAKBN ,GM.TAISHO_ATENA_NO';
            sSQL2 := sSQL2 || '   FROM GACTKANRI_MOUSHIDE GM';
            sSQL2 := sSQL2 || '   WHERE GM.KOJIN_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
            sSQL2 := sSQL2 || '   AND GM.TAISHOSHAKBN = 0))';
            sSQL2 := sSQL2 || ' AND GACTKANRI_MOUSHIDE.TAISHOSHAKBN = 0 ';
            sSQL2 := sSQL2 || ' AND((GACTKANRI_MOUSHIDE.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL2 := sSQL2 || '  AND ( CASE WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NOT NULL THEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI ';
            sSQL2 := sSQL2 || '  WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NULL THEN NVL(GACTKANRI_MOUSHIDE.SHIENSOCHISHURYOBI,99999999) END >= ' || nJYOUKEN02 || ')) ';
            sSQL2 := sSQL2 || ' OR (GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL2 := sSQL2 || ' AND (CASE WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NOT NULL THEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI ';
            sSQL2 := sSQL2 || ' WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NULL THEN NVL(GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI,99999999) END >= ' || nJYOUKEN02 || ' ))) ';
            sSQL2 := sSQL2 || '  ) ';
          END IF;
          -- ②変数.抽出対象　＝　1（支援措置終了含む）　の場合
          IF g_vJYOUKEN01 = '1' THEN
            sSQL2 := sSQL2 || ' (GACTKANRI_MOUSHIDE.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL2 := sSQL2 || ' OR GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI <= ' || nJYOUKEN02 || ') ';
            sSQL2 := sSQL2 || '  AND GACTKANRI_MOUSHIDE.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) FROM GACTKANRI_MOUSHIDE WHERE ';
            sSQL2 := sSQL2 || ' (GACTKANRI_MOUSHIDE.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL2 := sSQL2 || ' OR GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI <= ' || nJYOUKEN02 || ') ';
--2025/09/17 CTC.GL UPDATE START 1.0.105.001:GKB_QA20944対応
            sSQL2 := sSQL2 || ' AND GACTKANRI_MOUSHIDE.KOJIN_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
--2025/09/17 CTC.GL UPDATE END
            sSQL2 := sSQL2 || '  ) ';
          END IF;
          OPEN cCURSORSQL2 FOR sSQL2;
          LOOP
            FETCH cCURSORSQL2 INTO o_RCK;
            EXIT WHEN cCURSORSQL2%NOTFOUND;
          END LOOP;
          CLOSE cCURSORSQL2;
          
          --DB・ファイル等更新説明書（保護者_S) 
          o_RCHK := NULL;
          sSQL3 := '';
          sSQL3 := 'SELECT';
          sSQL3 := sSQL3 || ' GACTKANRI_SONOTAGYOMU.SETAIYOKUSHIKBN AS SETAIYOKUSHIKBN';
          sSQL3 := sSQL3 || ',GACTKANRI_SONOTAGYOMU.TOROKU_GYOMU AS TOROKU_GYOMU';
          sSQL3 := sSQL3 || ',GACTKANRI_SONOTAGYOMU.SHIENSOCHIKBN AS SHIENSOCHIKBN';
          sSQL3 := sSQL3 || ',GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN AS SHIENSOCHISHURYOKBN';
          sSQL3 := sSQL3 || ',GACTKANRI_SONOTAGYOMU.SHIENSOCHIKAISHIBI AS SHIENSOCHIKAISHIBI';
          sSQL3 := sSQL3 || ',GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOBI AS SHIENSOCHISHURYOBI';
          sSQL3 := sSQL3 || ',NULL AS TAISHOSHAKBN';
          sSQL3 := sSQL3 || ',NULL AS KARISHIENSOCHIKAISHIBI';
          sSQL3 := sSQL3 || ',NULL AS KARISHIENSOCHISHURYOBI';
          sSQL3 := sSQL3 || ',NULL AS SHIENSOCHIKAIJOBI';
          sSQL3 := sSQL3 || ' FROM GACTKANRI_SONOTAGYOMU ';
          sSQL3 := sSQL3 || ' WHERE GACTKANRI_SONOTAGYOMU.TOROKU_GYOMU = ''GKB'' ';
--  2025/06/27 CTC.GL UPDATE Start 1.0.010.000:GKB_QA17602対応
          --sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.KOJIN_NO = ' || rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO;
          sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.KOJIN_NO = ' || NVL(TO_CHAR(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO), '0');
--  2025/06/27 CTC.GL UPDATE End
          -- ①変数.抽出対象　＝　0（支援中のみ）　の場合
          IF g_vJYOUKEN01 = '0' THEN
            sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHIKBN IN (1, 2) ';
            --  2024/10/28 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00316仕様変更対応
            --sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN <> 3 ';
            sSQL3 := sSQL3 || ' AND NVL(GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN,0) <> 3 ';
            sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.RIREKI_NO = ( ';
            sSQL3 := sSQL3 || ' SELECT MAX(GACTKANRI_SONOTAGYOMU.RIREKI_NO) ';
            sSQL3 := sSQL3 || ' FROM GACTKANRI_SONOTAGYOMU ';
            sSQL3 := sSQL3 || ' WHERE GACTKANRI_SONOTAGYOMU.TOROKU_GYOMU = ''GKB'' ';
--  2025/06/27 CTC.GL UPDATE Start 1.0.010.000:GKB_QA17602対応
            --sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.KOJIN_NO = ' || rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO;
            sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.KOJIN_NO = ' || NVL(TO_CHAR(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO), '0');
--  2025/06/27 CTC.GL UPDATE End
            sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHIKBN IN (1, 2) ';
            --  2024/10/28 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00316仕様変更対応
            --sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN <> 3) ';
            sSQL3 := sSQL3 || ' AND NVL(GACTKANRI_SONOTAGYOMU.SHIENSOCHISHURYOKBN,0) <> 3) ';
          END IF;
          --②変数.抽出対象　＝　1（支援措置終了含む）　の場合
          IF g_vJYOUKEN01 = '1' THEN
            sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.RIREKI_NO = ( ';
            sSQL3 := sSQL3 || ' SELECT MAX(GACTKANRI_SONOTAGYOMU.RIREKI_NO) ';
            sSQL3 := sSQL3 || ' FROM GACTKANRI_SONOTAGYOMU ';
            sSQL3 := sSQL3 || ' WHERE GACTKANRI_SONOTAGYOMU.TOROKU_GYOMU = ''GKB'' ';
--  2025/06/27 CTC.GL UPDATE Start 1.0.010.000:GKB_QA17602対応
            --sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.KOJIN_NO = ' || rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO;
            sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.KOJIN_NO = ' || NVL(TO_CHAR(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO), '0');
--  2025/06/27 CTC.GL UPDATE End
            sSQL3 := sSQL3 || ' AND GACTKANRI_SONOTAGYOMU.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02 || ')';
          END IF;
          sSQL3 := sSQL3 || ' UNION ALL ';
          sSQL3 := sSQL3 || 'SELECT';
          sSQL3 := sSQL3 || ' NULL AS SETAIYOKUSHIKBN';
          sSQL3 := sSQL3 || ',NULL AS TOROKU_GYOMU';
          sSQL3 := sSQL3 || ',NULL AS SHIENSOCHIKBN';
          sSQL3 := sSQL3 || ',NULL AS SHIENSOCHISHURYOKBN';
          sSQL3 := sSQL3 || ',GACTKANRI_MOUSHIDE.SHIENSOCHIKAISHIBI AS SHIENSOCHIKAISHIBI';
          sSQL3 := sSQL3 || ',GACTKANRI_MOUSHIDE.SHIENSOCHISHURYOBI AS SHIENSOCHISHURYOBI';
          sSQL3 := sSQL3 || ',GACTKANRI_MOUSHIDE.TAISHOSHAKBN AS TAISHOSHAKBN';
          sSQL3 := sSQL3 || ',GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI AS KARISHIENSOCHIKAISHIBI';
          sSQL3 := sSQL3 || ',GACTKANRI_MOUSHIDE.KARISHIENSOCHISHURYOBI AS KARISHIENSOCHISHURYOBI';
          sSQL3 := sSQL3 || ',GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI AS SHIENSOCHIKAIJOBI';
          sSQL3 := sSQL3 || ' FROM ';
          sSQL3 := sSQL3 || 'GACTKANRI_MOUSHIDE ';
          sSQL3 := sSQL3 || 'WHERE ';
          -- ①変数.抽出対象　＝　0（支援中のみ）　の場合
          IF g_vJYOUKEN01 = '0' THEN
            sSQL3 := sSQL3 || ' GACTKANRI_MOUSHIDE.KOJIN_NO IN ( ';
            sSQL3 := sSQL3 || ' SELECT KOJIN_NO FROM( ';
            sSQL3 := sSQL3 || '   SELECT GM.KOJIN_NO ,GM.TAISHOSHAKBN ,GM.TAISHO_ATENA_NO';
            sSQL3 := sSQL3 || '   FROM GACTKANRI_MOUSHIDE GM';
--2025/09/17 CTC.GL UPDATE START 1.0.105.001:GKB_QA20944対応
            --sSQL3 := sSQL3 || '   WHERE GM.TAISHO_ATENA_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
            sSQL3 := sSQL3 || '   WHERE GM.TAISHO_ATENA_NO = ' || NVL(TO_CHAR(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO), '0');
            sSQL3 := sSQL3 || '   AND GM.TAISHOSHAKBN = 1';
            sSQL3 := sSQL3 || '   UNION ALL';
            sSQL3 := sSQL3 || '   SELECT GM.KOJIN_NO ,GM.TAISHOSHAKBN ,GM.TAISHO_ATENA_NO';
            sSQL3 := sSQL3 || '   FROM GACTKANRI_MOUSHIDE GM';
            --sSQL3 := sSQL3 || '   WHERE GM.KOJIN_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
            sSQL3 := sSQL3 || '   WHERE GM.KOJIN_NO = ' || NVL(TO_CHAR(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO), '0');
            sSQL3 := sSQL3 || '   AND GM.TAISHOSHAKBN = 0))';
            sSQL3 := sSQL3 || ' AND GACTKANRI_MOUSHIDE.TAISHOSHAKBN = 0 ';
            sSQL3 := sSQL3 || ' AND((GACTKANRI_MOUSHIDE.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL3 := sSQL3 || '  AND ( CASE WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NOT NULL THEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI ';
            sSQL3 := sSQL3 || '  WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NULL THEN NVL(GACTKANRI_MOUSHIDE.SHIENSOCHISHURYOBI,99999999) END >= ' || nJYOUKEN02 || ')) ';
            sSQL3 := sSQL3 || ' OR (GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL3 := sSQL3 || ' AND (CASE WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NOT NULL THEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI ';
            sSQL3 := sSQL3 || ' WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NULL THEN NVL(GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI,99999999) END >= ' || nJYOUKEN02 || ' ))) ';
            sSQL3 := sSQL3 || ' AND GACTKANRI_MOUSHIDE.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) FROM GACTKANRI_MOUSHIDE WHERE ';
            sSQL3 := sSQL3 || ' GACTKANRI_MOUSHIDE.KOJIN_NO IN ( ';
            sSQL3 := sSQL3 || ' SELECT KOJIN_NO FROM( ';
            sSQL3 := sSQL3 || '   SELECT GM.KOJIN_NO ,GM.TAISHOSHAKBN ,GM.TAISHO_ATENA_NO';
            sSQL3 := sSQL3 || '   FROM GACTKANRI_MOUSHIDE GM';
            --sSQL3 := sSQL3 || '   WHERE GM.TAISHO_ATENA_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
            sSQL3 := sSQL3 || '   WHERE GM.TAISHO_ATENA_NO = ' || NVL(TO_CHAR(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO), '0');
            sSQL3 := sSQL3 || '   AND GM.TAISHOSHAKBN = 1';
            sSQL3 := sSQL3 || '   UNION ALL';
            sSQL3 := sSQL3 || '   SELECT GM.KOJIN_NO ,GM.TAISHOSHAKBN ,GM.TAISHO_ATENA_NO';
            sSQL3 := sSQL3 || '   FROM GACTKANRI_MOUSHIDE GM';
            --sSQL3 := sSQL3 || '   WHERE GM.KOJIN_NO = ' || rGKBTGAKUREIBO.KOJIN_NO;
            sSQL3 := sSQL3 || '   WHERE GM.KOJIN_NO = ' || NVL(TO_CHAR(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO), '0');
--2025/09/17 CTC.GL UPDATE END
            sSQL3 := sSQL3 || '   AND GM.TAISHOSHAKBN = 0))';
            sSQL3 := sSQL3 || ' AND GACTKANRI_MOUSHIDE.TAISHOSHAKBN = 0 ';
            sSQL3 := sSQL3 || ' AND((GACTKANRI_MOUSHIDE.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL3 := sSQL3 || '  AND ( CASE WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NOT NULL THEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI ';
            sSQL3 := sSQL3 || '  WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NULL THEN NVL(GACTKANRI_MOUSHIDE.SHIENSOCHISHURYOBI,99999999) END >= ' || nJYOUKEN02 || ')) ';
            sSQL3 := sSQL3 || ' OR (GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL3 := sSQL3 || ' AND (CASE WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NOT NULL THEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI ';
            sSQL3 := sSQL3 || ' WHEN GACTKANRI_MOUSHIDE.SHIENSOCHIKAIJOBI IS NULL THEN NVL(GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI,99999999) END >= ' || nJYOUKEN02 || ' ))) ';
            sSQL3 := sSQL3 || '  ) ';
          END IF;
          -- ②変数.抽出対象　＝　1（支援措置終了含む）　の場合
          IF g_vJYOUKEN01 = '1' THEN
            sSQL3 := sSQL3 || ' (GACTKANRI_MOUSHIDE.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL3 := sSQL3 || ' OR GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI <= ' || nJYOUKEN02 || ') ';
            sSQL3 := sSQL3 || '  AND GACTKANRI_MOUSHIDE.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) FROM GACTKANRI_MOUSHIDE WHERE ';
            sSQL3 := sSQL3 || ' (GACTKANRI_MOUSHIDE.SHIENSOCHIKAISHIBI <= ' || nJYOUKEN02;
            sSQL3 := sSQL3 || ' OR GACTKANRI_MOUSHIDE.KARISHIENSOCHIKAISHIBI <= ' || nJYOUKEN02 || ') ';
--2025/09/17 CTC.GL UPDATE START 1.0.105.001:GKB_QA20944対応
            sSQL3 := sSQL3 || ' AND GACTKANRI_MOUSHIDE.KOJIN_NO = ' || NVL(TO_CHAR(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO), '0');
--2025/09/17 CTC.GL UPDATE END
            sSQL3 := sSQL3 || '  ) ';
          END IF;
          OPEN cCURSORSQL3 FOR sSQL3;
          LOOP
            FETCH cCURSORSQL3 INTO o_RCHK;
            EXIT WHEN cCURSORSQL3%NOTFOUND;
          END LOOP;
          CLOSE cCURSORSQL3;
          
          rGKAWSHIENTAISHOSHA.TITLE := '支援措置対象者一覧';                      --タイトル
          rGKAWSHIENTAISHOSHA.ENJOHI_KBN1 := NULL;                               --援助費区分1
          rGKAWSHIENTAISHOSHA.ENJOHI_KBN2 := NULL;                               --援助費区分2
          rGKAWSHIENTAISHOSHA.GAKKO_KBN_CD := rGKBTGAKUREIBO.GAKKO_KBN_CD;       --学校区分コード
          --学校コード
          --1.学齢薄カーソル.学校区分コード ＝ 1 の場合、
          IF rGKBTGAKUREIBO.GAKKO_KBN_CD = 1 THEN
            rGKAWSHIENTAISHOSHA.GAKKO_CD := rGKBTGAKUREIBO.SYOGAKO_CD;
          END IF;
          --2.学齢薄カーソル.学校区分コード ＝ 2 の場合、
          IF rGKBTGAKUREIBO.GAKKO_KBN_CD = 2 THEN
            rGKAWSHIENTAISHOSHA.GAKKO_CD := rGKBTGAKUREIBO.TYUGAKO_CD;
          END IF;
          --3.学齢薄カーソル.学校区分コード ＝ 3 の場合、
          IF rGKBTGAKUREIBO.GAKKO_KBN_CD = 3 THEN
            rGKAWSHIENTAISHOSHA.GAKKO_CD := rGKBTGAKUREIBO.YOGOGAKO_CD;
          END IF;
          --4.学齢薄カーソル.学校区分コード ＝ 4 の場合、
          IF rGKBTGAKUREIBO.GAKKO_KBN_CD = 4 THEN
            rGKAWSHIENTAISHOSHA.GAKKO_CD := rGKBTGAKUREIBO.KUIKIGAI_CD;
          END IF;
          --5.学齢薄カーソル.学校区分コード ＝ 5 の場合、
          IF rGKBTGAKUREIBO.GAKKO_KBN_CD = 5 THEN
            rGKAWSHIENTAISHOSHA.GAKKO_CD := rGKBTGAKUREIBO.KUNISHIRITSU_CD;
          END IF;
          rGKAWSHIENTAISHOSHA.GAKOMEI := GKAFKGKOGTEQ(rGKAWSHIENTAISHOSHA.GAKKO_KBN_CD, rGKAWSHIENTAISHOSHA.GAKKO_CD);  --学校名
          rGKAWSHIENTAISHOSHA.KIJUNBI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_nJYOUKEN02, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);            --基準日
          rGKAWSHIENTAISHOSHA.SAKUSEIBI := KKAPK0020.FDateFmt(TO_CHAR(SYSDATE,'YYYY/MM/DD'), 12);               --作成日
          rGKAWSHIENTAISHOSHA.TL_HOGOSHA_SHIMEI := '保護者氏名';                           --タイトル‐保護者氏名
          rGKAWSHIENTAISHOSHA.TL_HOGOSHA_JUSHO :='保護者住所';                             --タイトル‐保護者住所
          rGKAWSHIENTAISHOSHA.TL_JIDO_KANKEI := '児童生徒との関係';                          --タイトル‐児童生徒との関係
          rGKAWSHIENTAISHOSHA.TL_HOGOSHA_KOJIN_NO := '保護者宛名番号';                      --タイトル‐保護者宛名番号
          rGKAWSHIENTAISHOSHA.TL_HOGOSHA_SETAI_NO := '保護者世帯番号';                      --タイトル‐保護者世帯番号
          
          nRTN := GKBFKHMCTRL(rGKBTGAKUREIBO.KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_sSEYIGYO, vSHIMEI_KANA, vSHIMEI_KANJI, vSEINENGAPI);
          rGKAWSHIENTAISHOSHA.JIDO_SHIMEI_KANA := vSHIMEI_KANA;                            --児童生徒氏名カナ
          rGKAWSHIENTAISHOSHA.JIDO_SHIMEI_KANJI := vSHIMEI_KANJI;                          --児童生徒氏名
          
          nRTN := GKBFKHMCTRL(rGKBTGAKUREIBO.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_sSEYIGYO, vSHIMEI_KANA1, vSHIMEI_KANJI1, vSEINENGAPI1);
          rGKAWSHIENTAISHOSHA.HOGOSHA_SHIMEI_KANA := vSHIMEI_KANA1;                        --保護者氏名カナ
          rGKAWSHIENTAISHOSHA.HOGOSHA_SHIMEI_KANJI := vSHIMEI_KANJI1;                      --保護者氏名
          --児童生徒
          nRTN := GAAPK0030.FGETATENA(rGKBTGAKUREIBO.KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), RATENA_JIDO, RSOFU_JIDO);
          rGKAWSHIENTAISHOSHA.JIDO_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, RATENA_JIDO.CHOMEI, RATENA_JIDO.BANCHI, RATENA_JIDO.KATAGAKI, NULL);    --児童生徒住所
          --保護者
          nRTN := GAAPK0030.FGETATENA(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), RATENA_HOGOSHA, RSOFU_HOGOSHA);
          rGKAWSHIENTAISHOSHA.HOGOSHA_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, RATENA_HOGOSHA.CHOMEI, RATENA_HOGOSHA.BANCHI, RATENA_HOGOSHA.KATAGAKI, NULL);    --保護者住所
          --児童生徒生年月日
          rGKAWSHIENTAISHOSHA.JIDO_SEINENGAPPI := vSEINENGAPI;                                
          --性別名取得
          nRTN := KKAPK0030.FCDGetR('GKB', '021', '0001', rGKBTGAKUREIBO.SEIBETSU, sMEISHO, sMEISHOKANA, sYOBI); 
          rGKAWSHIENTAISHOSHA.JIDO_SEIBETSU := sMEISHO;                                       --児童生徒性別
          
          rGKAWSHIENTAISHOSHA.GAKUNEN := rGKBTGAKUREIBO.GAKUNEN;                                                --学年
          rGKAWSHIENTAISHOSHA.HOGOSHA_SEINENGAPPI := vSEINENGAPI1; --保護者生年月日
          
          --性別名取得
          nRTN := KKAPK0030.FCDGetR('GKB', '021', '0001', RATENA_HOGOSHA.SEIBETSU, sMEISHO1, sMEISHOKANA1, sYOBI1); 
          rGKAWSHIENTAISHOSHA.HOGOSHA_SEIBETSU := sMEISHO1;--保護者性別
          
          --続柄
          nRTN := GKBFKZKGMGET(2, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA1, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA2, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA3, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA4, vZOKUGARAMEI, nIHERR);
          IF nIHERR <> 0 THEN
            rGKAWSHIENTAISHOSHA.JIDO_KANKEI := NULL;        --児童生徒との関係/続柄
          ELSE
            rGKAWSHIENTAISHOSHA.JIDO_KANKEI := vZOKUGARAMEI;--児童生徒との関係/続柄
          END IF;
          --児童生徒国籍
          nRTN := GKAFKKKMGET(RATENA_JIDO.KOKUSEKI_CD, sKOKUMEI_KANA, sKOKUMEI, sKOKUMEI_ALPHABET);
          rGKAWSHIENTAISHOSHA.JIDO_KOKUSEKI := sKOKUMEI;--児童生徒国籍
          --保護者国籍
          nRTN := GKAFKKKMGET(RATENA_HOGOSHA.KOKUSEKI_CD, sKOKUMEI_KANA1, sKOKUMEI1, sKOKUMEI_ALPHABET1);
          rGKAWSHIENTAISHOSHA.HOGOSHA_KOKUSEKI := sKOKUMEI1;--保護者国籍
          
          rGKAWSHIENTAISHOSHA.JIDO_KOJIN_NO := RATENA_JIDO.KOJIN_NO;                   --児童生徒宛名番号
          rGKAWSHIENTAISHOSHA.JIDO_SETAI_NO := RATENA_JIDO.SETAI_NO;                   --児童生徒世帯番号
          rGKAWSHIENTAISHOSHA.HOGOSHA_KOJIN_NO := RATENA_HOGOSHA.KOJIN_NO;             --保護者宛名番号
          rGKAWSHIENTAISHOSHA.HOGOSHA_SETAI_NO := RATENA_HOGOSHA.SETAI_NO;             --保護者世帯番号
          rGKAWSHIENTAISHOSHA.JIDO_TAISHOSHA_KBN := '併せて支援を求める者';               --児童生徒支援措置対象者区分
          rGKAWSHIENTAISHOSHA.HOGOSHA_TAISHOSHA_KBN := '申出者';                       --保護者支援措置対象者区分
          --支援措置申出者管理_申出者情報に児童生徒の情報を登録されている場合、
          --  2025/01/27 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:ST_GKB_TMP00015仕様変更対応 Start
          /*
          IF o_RCK.TAISHOSHAKBN IS NOT NULL THEN
            IF g_vJYOUKEN01 = '0' THEN
              JIDO_ISFLG := 1;
            ELSE
              JIDO_ISFLG := 0;
            END IF;
          ELSE
            --  2024/10/28 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00316仕様変更対応
            --IF g_vJYOUKEN01 = '0' OR o_RCK.SHIENSOCHISHURYOKBN = 3  THEN
            IF (g_vJYOUKEN01 = '0' OR o_RCK.SHIENSOCHISHURYOKBN IS NULL)OR o_RCK.SHIENSOCHISHURYOKBN = 3  THEN
              JIDO_ISFLG := 1;
            END IF;
          END IF;
          IF JIDO_ISFLG = 1 THEN
            rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := '有効';--児童生徒有効状態
          END IF;
          IF JIDO_ISFLG = 0 THEN
            rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := NULL; --児童生徒有効状態
          END IF;
          */
          BEGIN
          SELECT KOJIN_NO 
          INTO JIDO_ISFLG
          FROM GACTKANRI_MOUSHIDE
          WHERE KOJIN_NO = rGKBTGAKUREIBO.KOJIN_NO;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
        JIDO_ISFLG := NULL;
            WHEN OTHERS THEN
        JIDO_ISFLG := NULL;
         END;
--2025/09/17 CTC.GL UPDATE START 1.0.105.001:GKB_QA20944対応
        rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := NULL;
        rGKAWSHIENTAISHOSHA.HOGOSHA_YUKOJOTAI := NULL;
--2025/09/17 CTC.GL UPDATE END
        IF JIDO_ISFLG IS NULL THEN
          IF o_RCK.SHIENSOCHIKAIJOBI IS NOT NULL THEN
            IF o_RCK.SHIENSOCHIKAIJOBI >= g_nJYOUKEN02 THEN
              rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := '有効';--児童生徒有効状態
            END IF;
          ELSE IF o_RCK.SHIENSOCHIKAIJOBI IS NULL THEN
            IF o_RCK.SHIENSOCHISHURYOBI >= g_nJYOUKEN02 THEN
              rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := '有効';--児童生徒有効状態
            ELSIF o_RCK.KARISHIENSOCHISHURYOBI >= g_nJYOUKEN02 THEN
              rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := '有効';--児童生徒有効状態 
--2025/09/17 CTC.GL UPDATE START 1.0.105.001:GKB_QA20944対応
            ELSIF o_RCK.SHIENSOCHIKAISHIBI IS NOT NULL AND o_RCK.SHIENSOCHISHURYOBI IS NULL THEN
              rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := '有効';--児童生徒有効状態 
--2025/09/17 CTC.GL UPDATE END
            END IF;
          ELSE
              rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := NULL; --児童生徒有効状態
            END IF;
          END IF;

        ELSE
          IF o_RCK.SHIENSOCHIKBN IN (1,2)
            AND (o_RCK.SHIENSOCHISHURYOKBN >= 3
                 OR o_RCK.SHIENSOCHISHURYOKBN IS NULL)THEN
                  rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := '有効';--児童生徒有効状態
          ELSIF o_RCK.SHIENSOCHISHURYOKBN = 3 THEN 
             rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := '有効';--児童生徒有効状態
          ELSE 
             rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := NULL;--児童生徒有効状態
          END IF;
        END IF;
          --保護者有効状態
          /*
          IF o_RCHK.TAISHOSHAKBN IS NOT NULL THEN
            IF g_vJYOUKEN01 = '0' THEN
              HOGOSHA_ISFLG := 1;
            ELSE
              HOGOSHA_ISFLG := 0;
            END IF;
          ELSE
            --  2024/10/28 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00316仕様変更対応
            --IF g_vJYOUKEN01 = '0' OR o_RCK.SHIENSOCHISHURYOKBN = 3 THEN
            IF (g_vJYOUKEN01 = '0' OR o_RCK.SHIENSOCHISHURYOKBN IS NULL) OR o_RCK.SHIENSOCHISHURYOKBN = 3 THEN
              HOGOSHA_ISFLG := 1;
            END IF;
          END IF;
          IF HOGOSHA_ISFLG = 1 THEN
            rGKAWSHIENTAISHOSHA.HOGOSHA_YUKOJOTAI := '有効';--保護者有効状態
          END IF;
          IF HOGOSHA_ISFLG = 0 THEN
            rGKAWSHIENTAISHOSHA.HOGOSHA_YUKOJOTAI := NULL; --保護者有効状態
          END IF;
          */
          BEGIN
          SELECT KOJIN_NO 
          INTO HOGOSHA_ISFLG
          FROM GACTKANRI_MOUSHIDE
          WHERE KOJIN_NO = rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO;
          EXCEPTION
          WHEN NO_DATA_FOUND THEN
        HOGOSHA_ISFLG := NULL;
            WHEN OTHERS THEN
        HOGOSHA_ISFLG := NULL;
         END;
        IF HOGOSHA_ISFLG IS NULL THEN
          
          IF o_RCHK.SHIENSOCHIKAIJOBI IS NOT NULL THEN
            IF o_RCHK.SHIENSOCHIKAIJOBI >= g_nJYOUKEN02 THEN
              rGKAWSHIENTAISHOSHA.HOGOSHA_YUKOJOTAI := '有効';--児童生徒有効状態
            END IF;
          ELSE IF o_RCHK.SHIENSOCHIKAIJOBI IS NULL THEN
            IF o_RCHK.SHIENSOCHISHURYOBI >= g_nJYOUKEN02 THEN
              rGKAWSHIENTAISHOSHA.HOGOSHA_YUKOJOTAI := '有効';--児童生徒有効状態
            ELSIF o_RCHK.KARISHIENSOCHISHURYOBI >= g_nJYOUKEN02 THEN
              rGKAWSHIENTAISHOSHA.HOGOSHA_YUKOJOTAI := '有効';--児童生徒有効状態 
--2025/09/17 CTC.GL UPDATE START 1.0.105.001:GKB_QA20944対応
            ELSIF o_RCHK.SHIENSOCHIKAISHIBI IS NOT NULL AND o_RCHK.SHIENSOCHISHURYOBI IS NULL THEN
              rGKAWSHIENTAISHOSHA.HOGOSHA_YUKOJOTAI := '有効';
--2025/09/17 CTC.GL UPDATE END
            END IF;
          ELSE
              rGKAWSHIENTAISHOSHA.HOGOSHA_YUKOJOTAI := NULL; --児童生徒有効状態
            END IF;
          END IF;
          
        ELSE
          IF o_RCHK.SHIENSOCHIKBN IN (1,2)
            AND (o_RCHK.SHIENSOCHISHURYOKBN >= 3
                 OR o_RCHK.SHIENSOCHISHURYOKBN IS NULL)THEN
                  rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := '有効';--児童生徒有効状態
          ELSIF o_RCHK.SHIENSOCHISHURYOKBN = 3 THEN 
             rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := '有効';--児童生徒有効状態
          ELSE 
             rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI := NULL;--児童生徒有効状態
          END IF;
        END IF;
          --  2025/01/27 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:ST_GKB_TMP00015仕様変更対応 End
          --支援措置申出者管理_申出者情報に児童生徒の情報を登録されている場合、
          IF o_RCK.TAISHOSHAKBN IS NOT NULL THEN
            rGKAWSHIENTAISHOSHA.JIDO_TOROKUGYOMU := '住民記録';--児童生徒登録業務
            rGKAWSHIENTAISHOSHA.JIDO_KOJINSETAI := NULL;       --児童生徒個人世帯
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00286横展開対応
            --rGKAWSHIENTAISHOSHA.JIDO_SHIEN_KARA := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_RCK.SHIENSOCHIKAISHIBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--児童生徒支援措置開始年月日
            rGKAWSHIENTAISHOSHA.JIDO_SHIEN_KARA := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(o_RCK.SHIENSOCHIKAISHIBI), 12);--児童生徒支援措置開始年月日
            IF o_RCK.SHIENSOCHIKAIJOBI IS NOT NULL THEN
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00286横展開対応
              --rGKAWSHIENTAISHOSHA.JIDO_SHIEN_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_RCK.SHIENSOCHIKAIJOBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--児童生徒支援措置終了年月日
              rGKAWSHIENTAISHOSHA.JIDO_SHIEN_MADE := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(o_RCK.SHIENSOCHIKAIJOBI), 12);--児童生徒支援措置終了年月日
            END IF;
            IF o_RCK.SHIENSOCHIKAIJOBI IS NULL AND o_RCK.SHIENSOCHISHURYOBI <> 99999999 THEN
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00286横展開対応
              --rGKAWSHIENTAISHOSHA.JIDO_SHIEN_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_RCK.SHIENSOCHISHURYOBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--児童生徒支援措置終了年月日
              rGKAWSHIENTAISHOSHA.JIDO_SHIEN_MADE := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(o_RCK.SHIENSOCHISHURYOBI), 12);--児童生徒支援措置終了年月日
            END IF;
            IF o_RCK.SHIENSOCHIKAIJOBI IS NULL AND o_RCK.SHIENSOCHISHURYOBI = 99999999 THEN
              rGKAWSHIENTAISHOSHA.JIDO_SHIEN_MADE := NULL;                                 --児童生徒支援措置終了年月日
            END IF;
          ELSE --支援措置申出者管理_その他業務に児童生徒の情報を登録されている場合、
            rGKAWSHIENTAISHOSHA.JIDO_TOROKUGYOMU := '教育';--児童生徒登録業務
            IF o_RCK.SETAIYOKUSHIKBN = 0 THEN
              rGKAWSHIENTAISHOSHA.JIDO_KOJINSETAI := '個人';--児童生徒個人世帯
            ELSIF o_RCK.SETAIYOKUSHIKBN = 1 THEN
              rGKAWSHIENTAISHOSHA.JIDO_KOJINSETAI := '世帯';--児童生徒個人世帯
            END IF;
--  2024/11/02 ZCZL.WANGYUNING UPDATE START 0.3.000.005:IT_GKB_00286横展開対応
            --rGKAWSHIENTAISHOSHA.JIDO_SHIEN_KARA := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_RCK.SHIENSOCHIKAISHIBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--児童生徒支援措置開始年月日
            rGKAWSHIENTAISHOSHA.JIDO_SHIEN_KARA := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(o_RCK.SHIENSOCHIKAISHIBI), 12);--児童生徒支援措置開始年月日
            
            --rGKAWSHIENTAISHOSHA.JIDO_SHIEN_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_RCK.SHIENSOCHISHURYOBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--児童生徒支援措置終了年月日
            rGKAWSHIENTAISHOSHA.JIDO_SHIEN_MADE := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(o_RCK.SHIENSOCHISHURYOBI), 12);--児童生徒支援措置終了年月日
--  2024/11/02 ZCZL.WANGYUNING UPDATE END
          END IF;

          IF o_RCHK.TAISHOSHAKBN IS NOT NULL THEN
            rGKAWSHIENTAISHOSHA.HOGOSHA_TOROKUGYOMU := '住民記録';--保護者登録業務
            rGKAWSHIENTAISHOSHA.HOGOSHA_KOJINSETAI := NULL; --保護者個人世帯
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00286横展開対応
            --rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_KARA := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_RCHK.SHIENSOCHIKAISHIBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--保護者支援措置開始年月日
            rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_KARA := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(o_RCHK.SHIENSOCHIKAISHIBI), 12);--保護者支援措置開始年月日
            
            IF o_RCHK.SHIENSOCHIKAIJOBI IS NOT NULL THEN
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00286横展開対応 
              --rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_RCHK.SHIENSOCHIKAIJOBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--保護者支援措置終了年月日
              rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_MADE := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(o_RCHK.SHIENSOCHIKAIJOBI), 12);--保護者支援措置終了年月日
            END IF;
            IF o_RCHK.SHIENSOCHIKAIJOBI IS NULL AND o_RCHK.SHIENSOCHISHURYOBI <> 99999999 THEN
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00286横展開対応
              --rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_RCHK.SHIENSOCHISHURYOBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--保護者支援措置終了年月日
              rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_MADE := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(o_RCHK.SHIENSOCHISHURYOBI), 12);--保護者支援措置終了年月日
            END IF;
            IF o_RCHK.SHIENSOCHIKAIJOBI IS NULL AND o_RCHK.SHIENSOCHISHURYOBI = 99999999 THEN
              rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_MADE := NULL;                                 --保護者支援措置終了年月日
            END IF;
          ELSE
            rGKAWSHIENTAISHOSHA.HOGOSHA_TOROKUGYOMU := '教育';--保護者登録業務
            IF o_RCHK.SETAIYOKUSHIKBN = 0 THEN
              rGKAWSHIENTAISHOSHA.HOGOSHA_KOJINSETAI := '個人';--保護者個人世帯
            ELSIF o_RCHK.SETAIYOKUSHIKBN = 1 THEN
              rGKAWSHIENTAISHOSHA.HOGOSHA_KOJINSETAI := '世帯';--保護者個人世帯
            END IF;
--  2024/11/02 ZCZL.WANGYUNING UPDATE START 0.3.000.005:IT_GKB_00286横展開対応
            --rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_KARA := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_RCHK.SHIENSOCHIKAISHIBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--保護者支援措置開始年月日
            
            --rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_RCHK.SHIENSOCHISHURYOBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--児童生徒支援措置終了年月日
            rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_KARA := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(o_RCHK.SHIENSOCHIKAISHIBI), 12);--保護者支援措置開始年月日
            
            rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_MADE := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(o_RCHK.SHIENSOCHISHURYOBI), 12);--児童生徒支援措置終了年月日
--  2024/11/02 ZCZL.WANGYUNING UPDATE END
          END IF;
--2025/09/17 CTC.GL UPDATE START 1.0.105.001:GKB_QA20944対応
        ----------------------------------------------------------------
        -- 児童生徒：支援措置開始・終了年月日
        ----------------------------------------------------------------
        JIDO_FLG := FALSE;
        HOGOSHA_FLG := FALSE;
        IF o_RCK.SHIENSOCHIKAISHIBI IS NULL OR o_RCK.SHIENSOCHIKAISHIBI = 0 THEN
            JIDO_FLG := TRUE;
        ELSE
            v_JIDO_START_NUM := o_RCK.SHIENSOCHIKAISHIBI;
            IF o_RCK.SHIENSOCHIKAIJOBI IS NOT NULL THEN
                v_JIDO_END_NUM := o_RCK.SHIENSOCHIKAIJOBI;
            ELSIF o_RCK.SHIENSOCHISHURYOBI IS NOT NULL THEN
                IF o_RCK.SHIENSOCHISHURYOBI = 99999999 THEN
                    v_JIDO_END_NUM := 99999999;
                ELSE
                    v_JIDO_END_NUM := o_RCK.SHIENSOCHISHURYOBI;
                END IF;
            ELSE
                v_JIDO_END_NUM := 99999999;
            END IF;
        END IF;
        ----------------------------------------------------------------
        -- 保護者：支援措置開始・終了年月日
        ----------------------------------------------------------------
        IF o_RCHK.SHIENSOCHIKAISHIBI IS NULL OR o_RCHK.SHIENSOCHIKAISHIBI = 0 THEN
            HOGOSHA_FLG := TRUE;
        ELSE
            v_HOGOSHA_START_NUM := o_RCHK.SHIENSOCHIKAISHIBI;
            IF o_RCHK.SHIENSOCHIKAIJOBI IS NOT NULL THEN
                v_HOGOSHA_END_NUM := o_RCHK.SHIENSOCHIKAIJOBI;
            ELSIF o_RCHK.SHIENSOCHISHURYOBI IS NOT NULL THEN
                IF o_RCHK.SHIENSOCHISHURYOBI = 99999999 THEN
                    v_HOGOSHA_END_NUM := 99999999;
                ELSE
                    v_HOGOSHA_END_NUM := o_RCHK.SHIENSOCHISHURYOBI;
                END IF;
            ELSE
                v_HOGOSHA_END_NUM := 99999999;
            END IF;
        END IF;
        ----------------------------------------------------------------
        -- 児童生徒の支援条件チェック
        ----------------------------------------------------------------
          -- 支援中のみ（g_vJYOUKEN01 = '0'）の場合の条件チェック
          IF g_vJYOUKEN01 = '0' THEN
             -- 条件：基準日 >= 開始日 AND 基準日 <= 終了日
             IF NOT (nJYOUKEN02 >= v_JIDO_START_NUM AND nJYOUKEN02 <= v_JIDO_END_NUM) THEN
              JIDO_FLG := TRUE;
          END IF;

          -- 支援終了含む（g_vJYOUKEN01 = '1'）の場合の条件チェック
          ELSIF g_vJYOUKEN01 = '1' THEN
              -- 条件：基準日 >= 開始日
              IF NOT (nJYOUKEN02 >= v_JIDO_START_NUM) THEN
                JIDO_FLG := TRUE;
          END IF;
        END IF;
        ----------------------------------------------------------------
        -- 保護者の支援条件チェック
        ----------------------------------------------------------------
        IF g_vJYOUKEN01 = '0' THEN
          -- 条件：基準日 >= 開始日 AND 基準日 <= 終了日
          IF NOT (nJYOUKEN02 >= v_HOGOSHA_START_NUM AND nJYOUKEN02 <= v_HOGOSHA_END_NUM) THEN
            HOGOSHA_FLG := TRUE;
          END IF;

        ELSIF g_vJYOUKEN01 = '1' THEN
          -- 条件：基準日 >= 開始日
          IF NOT (nJYOUKEN02 >= v_HOGOSHA_START_NUM) THEN
            HOGOSHA_FLG := TRUE;
          END IF;
        END IF;

        IF JIDO_FLG AND HOGOSHA_FLG THEN
            -- 条件を満たす場合は以降の処理をスキップし、次のループに進む
            CONTINUE;
        END IF;
--2025/09/17 CTC.GL UPDATE END
          --登録中間ワークテーブル
          INSERT INTO GKAWSHIENTAISHOSHA VALUES rGKAWSHIENTAISHOSHA;
        END LOOP;
--  2024/09/05 ZCZL.LIUCHANGQUAN ADD 0.3.000.002:8月1日認識合わせの横展開
        CLOSE cCURSOR;
--  2025/12/15 CTC.GL UPDATE START 1.0.403.000:GKB_QA22980対応
      BEGIN
        SELECT ORDERBYCLAUSE_LIST
          INTO V_ORDERBY
          FROM KKBTSPRT
         WHERE CHOHYOID = 'GKA000R002'
         AND CHOHYONUM = 5501;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          V_ORDERBY := NULL;
      END;
        sSQL4 := '';
        sSQL4 := 'SELECT *';
        sSQL4 := sSQL4 || 'FROM GKAWSHIENTAISHOSHA '; 
--        IF KKAPK0010.FTrim(g_rJSTP.ORDERBY) IS NOT NULL THEN
--           sSQL4 := sSQL4 || ' ORDER BY ' || g_rJSTP.ORDERBY;
        IF V_ORDERBY IS NOT NULL THEN
           sSQL4 := sSQL4 || ' ORDER BY ' || V_ORDERBY;
        END IF;
--  2025/12/15 CTC.GL UPDATE END
        OPEN cCURSORWL FOR sSQL4;
        LOOP
          FETCH cCURSORWL INTO rGKAWSHIENTAISHOSHA;
          EXIT WHEN cCURSORWL%NOTFOUND;
          g_nSORT := g_nSORT + 1;
          rWLTBL.NO := g_nSORT;                                                  --ソート順
          rWLTBL.TITLE := rGKAWSHIENTAISHOSHA.TITLE;                             --タイトル
          rWLTBL.ENJOHI_KBN1 := rGKAWSHIENTAISHOSHA.ENJOHI_KBN1;                 --援助費区分1
          rWLTBL.ENJOHI_KBN2 := rGKAWSHIENTAISHOSHA.ENJOHI_KBN2;                 --援助費区分2
          rWLTBL.GAKOMEI := rGKAWSHIENTAISHOSHA.GAKOMEI;                         --学校名
          rWLTBL.KIJUNBI := rGKAWSHIENTAISHOSHA.KIJUNBI;                         --基準日
          rWLTBL.SAKUSEIBI := rGKAWSHIENTAISHOSHA.SAKUSEIBI;                     --作成日
          rWLTBL.TL_HOGOSHA_SHIMEI := rGKAWSHIENTAISHOSHA.TL_HOGOSHA_SHIMEI;     --タイトル‐保護者/申請者氏名
          rWLTBL.TL_HOGOSHA_JUSHO := rGKAWSHIENTAISHOSHA.TL_HOGOSHA_JUSHO;       --タイトル‐保護者/申請者住所
          rWLTBL.TL_JIDO_KANKEI := rGKAWSHIENTAISHOSHA.TL_JIDO_KANKEI;           --タイトル‐児童生徒との関係/続柄
          rWLTBL.TL_HOGOSHA_KOJIN_NO := rGKAWSHIENTAISHOSHA.TL_HOGOSHA_KOJIN_NO; --タイトル‐保護者/申請者宛名番号
          rWLTBL.TL_HOGOSHA_SETAI_NO := rGKAWSHIENTAISHOSHA.TL_HOGOSHA_SETAI_NO; --タイトル‐保護者/申請者世帯番号
          rWLTBL.JIDO_SHIMEI_KANA := rGKAWSHIENTAISHOSHA.JIDO_SHIMEI_KANA;       --児童生徒氏名カナ
          rWLTBL.JIDO_SHIMEI_KANJI := rGKAWSHIENTAISHOSHA.JIDO_SHIMEI_KANJI;     --児童生徒氏名
          rWLTBL.HOGOSHA_SHIMEI_KANA := rGKAWSHIENTAISHOSHA.HOGOSHA_SHIMEI_KANA; --保護者氏名カナ
          rWLTBL.HOGOSHA_SHIMEI_KANJI := rGKAWSHIENTAISHOSHA.HOGOSHA_SHIMEI_KANJI;--保護者氏名
          rWLTBL.JIDO_JUSHO := rGKAWSHIENTAISHOSHA.JIDO_JUSHO;                   --児童生徒住所
          rWLTBL.HOGOSHA_JUSHO := rGKAWSHIENTAISHOSHA.HOGOSHA_JUSHO;             --保護者住所
          rWLTBL.JIDO_SEINENGAPPI := rGKAWSHIENTAISHOSHA.JIDO_SEINENGAPPI;       --児童生徒生年月日
          rWLTBL.JIDO_SEIBETSU := rGKAWSHIENTAISHOSHA.JIDO_SEIBETSU;             --児童生徒性別
          rWLTBL.GAKUNEN := rGKAWSHIENTAISHOSHA.GAKUNEN;                         --学年
          rWLTBL.HOGOSHA_SEINENGAPPI := rGKAWSHIENTAISHOSHA.HOGOSHA_SEINENGAPPI; --保護者生年月日
          rWLTBL.HOGOSHA_SEIBETSU := rGKAWSHIENTAISHOSHA.HOGOSHA_SEIBETSU;       --保護者性別
          rWLTBL.JIDO_KANKEI := rGKAWSHIENTAISHOSHA.JIDO_KANKEI;                 --児童生徒との関係/続柄
          rWLTBL.JIDO_KOKUSEKI := rGKAWSHIENTAISHOSHA.JIDO_KOKUSEKI;             --児童生徒国籍
          rWLTBL.HOGOSHA_KOKUSEKI := rGKAWSHIENTAISHOSHA.HOGOSHA_KOKUSEKI;       --保護者国籍
          rWLTBL.JIDO_KOJIN_NO := rGKAWSHIENTAISHOSHA.JIDO_KOJIN_NO;             --児童生徒宛名番号
          rWLTBL.JIDO_SETAI_NO := rGKAWSHIENTAISHOSHA.JIDO_SETAI_NO;             --児童生徒世帯番号
          rWLTBL.HOGOSHA_KOJIN_NO := rGKAWSHIENTAISHOSHA.HOGOSHA_KOJIN_NO;       --保護者宛名番号
          rWLTBL.HOGOSHA_SETAI_NO := rGKAWSHIENTAISHOSHA.HOGOSHA_SETAI_NO;       --保護者世帯番号
          rWLTBL.JIDO_TAISHOSHA_KBN := rGKAWSHIENTAISHOSHA.JIDO_TAISHOSHA_KBN;   --児童生徒支援措置対象者区分
          rWLTBL.HOGOSHA_TAISHOSHA_KBN := rGKAWSHIENTAISHOSHA.HOGOSHA_TAISHOSHA_KBN;--保護者支援措置対象者区分
          rWLTBL.JIDO_YUKOJOTAI := rGKAWSHIENTAISHOSHA.JIDO_YUKOJOTAI;           --児童生徒有効状態
          rWLTBL.HOGOSHA_YUKOJOTAI := rGKAWSHIENTAISHOSHA.HOGOSHA_YUKOJOTAI;     --保護者有効状態
          rWLTBL.JIDO_TOROKUGYOMU := rGKAWSHIENTAISHOSHA.JIDO_TOROKUGYOMU;       --児童生徒登録業務
          rWLTBL.JIDO_KOJINSETAI := rGKAWSHIENTAISHOSHA.JIDO_KOJINSETAI;         --児童生徒個人世帯
          rWLTBL.HOGOSHA_TOROKUGYOMU := rGKAWSHIENTAISHOSHA.HOGOSHA_TOROKUGYOMU; --保護者登録業務
          rWLTBL.HOGOSHA_KOJINSETAI := rGKAWSHIENTAISHOSHA.HOGOSHA_KOJINSETAI;   --保護者個人世帯
          rWLTBL.JIDO_SHIEN_KARA := rGKAWSHIENTAISHOSHA.JIDO_SHIEN_KARA;         --児童生徒支援措置開始年月日
          rWLTBL.JIDO_SHIEN_MADE := rGKAWSHIENTAISHOSHA.JIDO_SHIEN_MADE;         --児童生徒支援措置終了年月日
          rWLTBL.HOGOSHA_SHIEN_KARA := rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_KARA;   --保護者支援措置開始年月日
          rWLTBL.HOGOSHA_SHIEN_MADE := rGKAWSHIENTAISHOSHA.HOGOSHA_SHIEN_MADE;   --保護者支援措置終了年月日
          rWLTBL.BREAK_NO := LPAD(rGKAWSHIENTAISHOSHA.GAKKO_CD, 3,'0');                                                            --改ページキー
          rWLTBL.WSNUM := g_sWSNUM;                                                                       --端末番号
          rWLTBL.BATCHKBN := 2;                                                                           --即時バッチ区分
          rWLTBL.JOBNUM := g_nJOBNUM;                                                                     --ジョブNO
          --登録ワークテーブル
          INSERT INTO GKAWL000R002 VALUES rWLTBL;
          g_nREBAN := g_nREBAN + 1;                                                                       --CSV出力件数
        END LOOP;
        CLOSE cCURSORWL;
--  2024/09/05 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--        nCOUNT := GKBFKTBLCNT('GKAWL000R002',NULL);
        nCOUNT := GKBFKTBLCNT('GKAWSHIENTAISHOSHA',NULL);
        --支援措置対象一覧対象件数
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '入力 支援措置対象者一覧件数', 1);
        --支援措置対象一覧ＣＳＶ件数
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_nREBAN, '出力 支援措置対象者一覧ＣＳＶ', 2);
        --関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV作成処理', 0, '', '', '支援措置対象者一覧ＣＳＶ' || g_nREBAN ||'件を出力しました', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/09/05 ZCZL.LIUCHANGQUAN ADD START 0.3.000.002:8月1日認識合わせの横展開
          IF cCURSORSQL2%ISOPEN THEN
              CLOSE cCURSORSQL2;
          END IF;
          IF cCURSORSQL3%ISOPEN THEN
              CLOSE cCURSORSQL3;
          END IF;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
          IF cCURSOR%ISOPEN THEN
            CLOSE cCURSOR;
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
    --  作成者／作成日: ZCZL.lujian 2024/06/28
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
    --  作成者／作成日: ZCZL.lujian   2024/06/28
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
        --帳票出力CSVの作成
        CASE g_rJSTP.CHOHYOID
          WHEN 'GKA000R002' THEN
            --支援措置対象者一覧ワーク
            DELETE FROM GKAWL000R002 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
            --ＣＳＶファイル作成処理を呼び出す。
            nRTN := FUNC_CSV_CREATE;
            IF nRTN <> 0 THEN
              RAISE ERR;
            END IF;
            bRTN := FUNC_B11CSV('GKAWL000R002');
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lujian   2024/06/28
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
    --  作成者／作成日: ZCZL.lujian   2024/06/28
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
END GKBPB00550;
/
