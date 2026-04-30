CREATE OR REPLACE PACKAGE BODY GKBPB00510
--1.0.102.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 区域外就学者一覧作成
--  機能概要      : 区域外就学者一覧を出力すること。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.LISHUAI   2024/07/10
--------------------------------------------------------
--  変更履歴
--  2024/09/25 ZCZL.WANGMING UPDATE 0.3.000.001:仕様変更　ID：IT_GKB_00009対応
--  2024/11/11 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00515対応
--  2024/11/13 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00535対応
--  2024/11/21 JPJYS.JH UPDATE 0.3.000.004:IT_GKB_00598仕様変更対応
--  2025/05/17 ZCZL.WANGMING UPDATE 1.0.006.000: GKB_QA13966(保守2234)_区域外就学事由に前ゼロを付加対応
--  2025/08/21 CTC.HJF UPDATE 1.0.102.000: GKB_QA19873対応
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

    g_nTIME                       NUMBER;                      --時分秒

    g_sShinseiStartYmd            NVARCHAR2(10);               --区域外就学申請年月日（開始）
    g_sShinseiEndYmd              NVARCHAR2(10);               --区域外就学申請年月日（終了）
    g_sKyokaStartYmd              NVARCHAR2(10);               --区域外就学許可年月日（開始）
    g_sKyokaEndYmd                NVARCHAR2(10);               --区域外就学許可年月日（終了）
    g_sKYO_TCL                    NVARCHAR2(1000);             --区域外就学者一覧_出力制御

--  2024/11/13 ZCZL.WANGMING ADD START 0.3.000.003:仕様変更　ID：IT_GKB_00535対応
    oShinseiStartYmd              NUMBER;               --区域外就学申請年月日（開始）
    oShinseiEndYmd                NUMBER;               --区域外就学申請年月日（終了）
    oKyokaStartYmd                NUMBER;               --区域外就学許可年月日（開始）
    oKyokaEndYmd                  NUMBER;               --区域外就学許可年月日（終了）
--  2024/11/13 ZCZL.WANGMING ADD END
    g_nCSVCNT                     NUMBER := 0;                 --CSV出力件数
    g_nCNT                        NUMBER := 0;                 --件数

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

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
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
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
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
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
    --  機能概要      : 初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : BOOLEAN
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
    --------------------------------------------------------
    FUNCTION FUNC_INIT
        RETURN BOOLEAN
    IS
      bRTN                          BOOLEAN;                        --戻り値
      nRTN                          NUMBER;                         --戻り値
      sVSG                          NVARCHAR2(1000);                --戻り値
      aPRM                          A_CONS_PRM;
      nINDEXNO                      NUMBER;                         --インデックス番号
      ERR                           EXCEPTION;
    BEGIN
        --区域外就学者一覧中間ワークをクリアする。
        nRTN := KKAPK3000.FTRUNCATE('GKBWKUIKIGAIICHIRAN', sVSG);
        IF nRTN = c_ERR THEN
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '初期処理', 0, '', '', SUBSTR(sVSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          RAISE ERR;
        END IF;
        --変数セット
        --システム制御設定を取得する。 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する。
        aPRM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aPRM);
        --「GKB672R001」が格納されている箇所のインデックス番号
        IF nRTN = 0 THEN
          FOR i IN 1..aPRM.COUNT LOOP
                IF aPRM(i) = 'GKB672R001' THEN
                  nINDEXNO := i;    --学校入学者名簿_インデックス番号
                  EXIT;
                END IF;
            END LOOP;
        END IF;
        nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aPRM);
        IF nRTN = 0 AND nINDEXNO <= aPRM.COUNT THEN
            g_sKYO_TCL := aPRM(nINDEXNO);    --学校入学者名簿_出力制御
        END IF;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_INIT;
    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
    BEGIN
        --バッチ処理条件の入力値をグローバル変数にセットする。
        --区域外就学申請年月日（開始）
        g_sShinseiStartYmd := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShinseiStartYmd');
--  2024/11/11 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00515対応
--        g_sShinseiStartYmd := KKAPK0020.FDAYEDIT20(g_sShinseiStartYmd, 0, 0);
        --区域外就学申請年月日（終了）
        g_sShinseiEndYmd := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShinseiEndYmd');
--  2024/11/11 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00515対応
--        g_sShinseiEndYmd := KKAPK0020.FDAYEDIT20(g_sShinseiEndYmd, 0, 0);
        --区域外就学許可年月日（開始）
        g_sKyokaStartYmd := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKyokaStartYmd');
--  2024/11/11 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00515対応
--        g_sKyokaStartYmd := KKAPK0020.FDAYEDIT20(g_sKyokaStartYmd, 0, 0);
        --区域外就学許可年月日（終了）
        g_sKyokaEndYmd := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKyokaEndYmd');
--  2024/11/11 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00515対応
--        g_sKyokaEndYmd := KKAPK0020.FDAYEDIT20(g_sKyokaEndYmd, 0, 0);
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
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
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
    --  2024/11/21 JPJYS.JH ADD 0.3.000.004:IT_GKB_00598仕様変更対応 Start
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
    --  2024/11/21 JPJYS.JH ADD 0.3.000.004:IT_GKB_00598仕様変更対応 End
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;                    --戻り値
--  2024/11/11 ZCZL.WANGMING ADD START 0.3.000.002:IT_GKB_00515対応
        ICHK1                        NUMBER := 0;
        ICHK2                        NUMBER := 0;
        ICHK3                        NUMBER := 0;
        ICHK4                        NUMBER := 0;
--  2024/11/11 ZCZL.WANGMING ADD END
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
        o_vRESULT := '';
        --入力値チェック
        IF (TRIM(g_sShinseiStartYmd) = '' OR g_sShinseiStartYmd IS NULL) AND
           (TRIM(g_sShinseiEndYmd) = ''   OR g_sShinseiEndYmd IS NULL) AND
           (TRIM(g_sKyokaStartYmd) = ''   OR g_sKyokaStartYmd IS NULL) AND
           (TRIM(g_sKyokaEndYmd) = ''     OR g_sKyokaEndYmd IS NULL) THEN
          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,抽出条件が入力されていません。,;';
        END IF;
        
--  2025/08/21 CTC.HJF UPDATE START 1.0.102.000: GKB_QA19873対応
        --IF ((TRIM(g_sShinseiStartYmd) <> '' OR g_sShinseiStartYmd IS NOT NULL) AND (TRIM(g_sShinseiEndYmd) = '' OR g_sShinseiEndYmd IS NULL)) OR
        --   ((TRIM(g_sShinseiStartYmd) = '' OR g_sShinseiStartYmd IS NULL) AND (TRIM(g_sShinseiEndYmd) <> '' OR g_sShinseiEndYmd IS NOT NULL)) THEN
        --   o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請年月日（開始）と区域外就学申請年月日（終了）の指定が必要です。,;';
        --END IF;
        --IF ((TRIM(g_sKyokaStartYmd) <> '' OR g_sKyokaStartYmd IS NOT NULL) AND (TRIM(g_sKyokaEndYmd) = '' OR g_sKyokaEndYmd IS NULL)) OR
        --   ((TRIM(g_sKyokaStartYmd) = '' OR g_sKyokaStartYmd IS NULL) AND (TRIM(g_sKyokaEndYmd) <> '' OR g_sKyokaEndYmd IS NOT NULL)) THEN
        --   o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可年月日（開始）と区域外就学許可年月日（終了）の指定が必要です。,;';
        --END IF;
        IF ((TRIM(g_sShinseiStartYmd) = '' OR g_sShinseiStartYmd IS NULL) OR (TRIM(g_sShinseiEndYmd) = '' OR g_sShinseiEndYmd IS NULL)) AND
           ((TRIM(g_sKyokaStartYmd) = '' OR g_sKyokaStartYmd IS  NULL) AND (TRIM(g_sKyokaEndYmd) = '' OR  g_sKyokaEndYmd IS NULL)) THEN
           o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請年月日（開始）と区域外就学申請年月日（終了）の指定が必要です。,;';
        END IF;
        IF ((TRIM(g_sKyokaStartYmd) = '' OR g_sKyokaStartYmd IS NULL) OR (TRIM(g_sKyokaEndYmd) = '' OR g_sKyokaEndYmd IS NULL)) AND
           ((TRIM(g_sShinseiStartYmd) = '' OR g_sShinseiStartYmd IS NULL) AND (TRIM(g_sShinseiEndYmd) = '' OR g_sShinseiEndYmd IS NULL)) THEN
           o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可年月日（開始）と区域外就学許可年月日（終了）の指定が必要です。,;';
        END IF;
-- 2025/08/21 CTC.HJF UPDATE END
--  2024/11/11 ZCZL.WANGMING UPDATE START 0.3.000.002:IT_GKB_00515対応
--        --処理条件.区域外就学申請年月日（開始）
--        bRTN := KKAPK0020.FISDATEW(g_sShinseiStartYmd);
--        IF NOT bRTN THEN
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請開始年月日が正しくありません。,;';
--        END IF;
--        --処理条件.区域外就学申請年月日（終了）
--        bRTN := KKAPK0020.FISDATEW(g_sShinseiEndYmd);
--        IF NOT bRTN THEN
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請終了年月日が正しくありません。,;';
--        END IF;
--        --処理条件.区域外就学許可年月日（開始）
--        bRTN := KKAPK0020.FISDATEW(g_sKyokaStartYmd);
--        IF NOT bRTN THEN
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可開始年月日が正しくありません。,;';
--        END IF;
--        --処理条件.区域外就学許可年月日（終了）
--        bRTN := KKAPK0020.FISDATEW(g_sKyokaEndYmd);
--        IF NOT bRTN THEN
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可終了年月日が正しくありません。,;';
--        END IF;
--        --処理条件.区域外就学申請年月日（開始）
--        bRTN := KKAPK0010.FISNUMERIC(g_sShinseiStartYmd);
--        IF NOT bRTN THEN
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請開始年月日が正しくありません。,;';
--        END IF;
--        --処理条件.区域外就学申請年月日（終了）
--        bRTN := KKAPK0010.FISNUMERIC(g_sShinseiEndYmd);
--        IF NOT bRTN THEN
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請終了年月日が正しくありません。,;';
--        END IF;
--        --処理条件.区域外就学許可年月日（開始）
--        bRTN := KKAPK0010.FISNUMERIC(g_sKyokaStartYmd);
--        IF NOT bRTN THEN
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可開始年月日が正しくありません。,;';
--        END IF;
--        --処理条件.区域外就学許可年月日（終了）
--        bRTN := KKAPK0010.FISNUMERIC(g_sKyokaEndYmd);
--        IF NOT bRTN THEN
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可終了年月日が正しくありません。,;';
--        END IF;
--        IF o_vRESULT IS NULL THEN
--          --処理条件.区域外就学申請年月日（開始） >処理条件.区域外就学申請年月日（終了）
--          IF g_sShinseiStartYmd > g_sShinseiEndYmd THEN
--            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請開始、終了年月日の関係が正しくありません。,;';
--          END IF;
--          --処理条件.区域外就学許可年月日（開始） >処理条件.区域外就学許可年月日（終了）
--          IF g_sKyokaStartYmd > g_sKyokaEndYmd THEN
--            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可開始、終了年月日の関係が正しくありません。,;';
--          END IF;
--        END IF;
--  2024/11/21 JPJYS.JH UPDATE 0.3.000.004:IT_GKB_00598仕様変更対応 Start
--       --処理条件.区域外就学申請年月日（開始）
--       IF KKAPK0010.FISNUMERIC(g_sShinseiStartYmd) = FALSE THEN 
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請開始年月日が正しくありません。,;';
--          ICHK1 := 1;
--        ELSE
--           --日付チェック
--           IF g_sShinseiStartYmd IS NOT NULL THEN
--               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_sShinseiStartYmd));
--               IF NOT bRTN THEN
--                   o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請開始年月日が正しくありません。,;';
--                   ICHK1 := 1;
--               END IF;
--           END IF;
--        END IF;
--        --処理条件.区域外就学申請年月日（終了）
--        IF KKAPK0010.FISNUMERIC(g_sShinseiEndYmd) = FALSE THEN 
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請終了年月日が正しくありません。,;';
--          ICHK2 := 1;
--        ELSE
--           --日付チェック
--           IF g_sShinseiEndYmd IS NOT NULL THEN
--               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_sShinseiEndYmd));
--              IF NOT bRTN THEN
--                   o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請終了年月日が正しくありません。,;';
--                   ICHK2 := 1;
--               END IF;
--           END IF;
--        END IF;
        --処理条件.区域外就学申請年月日（開始）
        ICHK1 := FUNCHIZUKECHK( g_sShinseiStartYmd);
        IF ICHK1 <> 0 THEN
            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請年月日（開始）が正しくありません。,;' ;
        END IF;
        --処理条件.区域外就学申請年月日（終了）
        ICHK2 := FUNCHIZUKECHK( g_sShinseiEndYmd);
        IF ICHK2 <> 0 THEN
            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請年月日（終了）が正しくありません。,;' ;
        END IF;
--  2024/11/21 JPJYS.JH UPDATE 0.3.000.004:IT_GKB_00598仕様変更対応 End
        IF ICHK1 = 0 AND ICHK2 = 0 THEN 
          IF g_sShinseiStartYmd > g_sShinseiEndYmd THEN 
            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学申請開始、終了年月日の関係が正しくありません。,;';
          END IF;
        END IF;
--  2024/11/21 JPJYS.JH UPDATE 0.3.000.004:IT_GKB_00598仕様変更対応 Start
        --処理条件.区域外就学許可年月日（開始）
--        IF KKAPK0010.FISNUMERIC(g_sKyokaStartYmd) = FALSE THEN 
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可開始年月日が正しくありません。,;';
--          ICHK3 := 1;
--        ELSE
--           --日付チェック
--           IF g_sKyokaStartYmd IS NOT NULL THEN
--               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_sKyokaStartYmd));
--               IF NOT bRTN THEN
--                   o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可開始年月日が正しくありません。,;';
--                   ICHK3 := 1;
--               END IF;
--           END IF;
--        END IF;
--        --処理条件.区域外就学許可年月日（終了）
--        IF KKAPK0010.FISNUMERIC(g_sKyokaEndYmd) = FALSE THEN 
--          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可終了年月日が正しくありません。,;';
--          ICHK4 := 1;
--        ELSE
--           --日付チェック
--           IF g_sKyokaEndYmd IS NOT NULL THEN
--               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_sKyokaEndYmd));
--               IF NOT bRTN THEN
--                   o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可終了年月日が正しくありません。,;';
--                   ICHK4 := 1;
--               END IF;
--           END IF;
--        END IF;
        ICHK3 := FUNCHIZUKECHK( g_sKyokaStartYmd);
        IF ICHK3 <> 0 THEN
            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可年月日（開始）が正しくありません。,;' ;
        END IF;
        --処理条件.区域外就学申請年月日（終了）
        ICHK4 := FUNCHIZUKECHK( g_sKyokaEndYmd);
        IF ICHK4 <> 0 THEN
            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可年月日（終了）が正しくありません。,;' ;
        END IF;
--  2024/11/21 JPJYS.JH UPDATE 0.3.000.004:IT_GKB_00598仕様変更対応 End       
        IF ICHK3 = 0 AND ICHK4 = 0 THEN
          IF g_sKyokaStartYmd > g_sKyokaEndYmd THEN 
            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,区域外就学許可開始、終了年月日の関係が正しくありません。,;';
          END IF;
        END IF;
--  2024/11/11 ZCZL.WANGMING UPDATE END
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
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
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
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
        g_oKENSU_LIST.EXTEND(2);
        g_oKENSU_LIST(1) := GKBEKENSU_RECORD(g_nCNT, '入力 区域外就学者一覧', 1);
        g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nCSVCNT, '出力 区域外就学者一覧ＣＳＶ', 2);
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
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE
        RETURN NUMBER
    IS
      bRTN                          BOOLEAN;                        --戻り値
      sSQL                          NVARCHAR2(1000);                --SQL文
      TYPE MC_CURSOR IS REF CURSOR;
      cCURSOR                       MC_CURSOR;

      TYPE MR_GKBWKUIKIGAIICHIRAN IS RECORD(
          SAKUSEI_YMD              GKBWKUIKIGAIICHIRAN.SAKUSEI_YMD%TYPE,
          JIDO_SHIMEI_KANA         GKBWKUIKIGAIICHIRAN.JIDO_SHIMEI_KANA%TYPE,
          JIDO_SHIMEI_KANJI        GKBWKUIKIGAIICHIRAN.JIDO_SHIMEI_KANJI%TYPE,
          HOGOSYA_SHIMEI_KANA      GKBWKUIKIGAIICHIRAN.HOGOSYA_SHIMEI_KANA%TYPE,
          HOGOSYA_SHIMEI_KANJI     GKBWKUIKIGAIICHIRAN.HOGOSYA_SHIMEI_KANJI%TYPE,
          SEINENGAPPI              GKBWKUIKIGAIICHIRAN.SEINENGAPPI%TYPE,
          SEIBETSU                 GKBWKUIKIGAIICHIRAN.SEIBETSU%TYPE,
          HOGOSHA_ZOKUGARA         GKBWKUIKIGAIICHIRAN.HOGOSHA_ZOKUGARA%TYPE,
          JIDO_KOKUSEKI            GKBWKUIKIGAIICHIRAN.JIDO_KOKUSEKI%TYPE,
          HOGOSYA_KOKUSEKI         GKBWKUIKIGAIICHIRAN.HOGOSYA_KOKUSEKI%TYPE,
          GAKKO_MEI                GKBWKUIKIGAIICHIRAN.GAKKO_MEI%TYPE,
          GAKUNEN                  GKBWKUIKIGAIICHIRAN.GAKUNEN%TYPE,
          SETISYAMEI               GKBWKUIKIGAIICHIRAN.SETISYAMEI%TYPE,
          JIYU                     GKBWKUIKIGAIICHIRAN.JIYU%TYPE,
          SHINSEI_YMD_HYOJI        GKBWKUIKIGAIICHIRAN.SHINSEI_YMD_HYOJI%TYPE,
          KYOKA_YMD                GKBWKUIKIGAIICHIRAN.KYOKA_YMD%TYPE,
          KAISHI_YMD               GKBWKUIKIGAIICHIRAN.KAISHI_YMD%TYPE,
          SHURYO_YMD               GKBWKUIKIGAIICHIRAN.SHURYO_YMD%TYPE,
          JIDO_KOJIN_NO            GKBWKUIKIGAIICHIRAN.JIDO_KOJIN_NO%TYPE,
          SEINENGAPPI_SORT         GKBWKUIKIGAIICHIRAN.SEINENGAPPI_SORT%TYPE,
          GAKKO_KBN_CD             GKBWKUIKIGAIICHIRAN.GAKKO_KBN_CD%TYPE,
          GAKKO_CD                 GKBWKUIKIGAIICHIRAN.GAKKO_CD%TYPE,
          GAKUNEN_CD               GKBWKUIKIGAIICHIRAN.GAKUNEN_CD%TYPE,
          SHINSEI_YMD_SORT         GKBWKUIKIGAIICHIRAN.SHINSEI_YMD_SORT%TYPE,
          KYOKA_YMD_SORT           GKBWKUIKIGAIICHIRAN.KYOKA_YMD_SORT%TYPE
      );
      rGKBWKUIKIGAIICHIRAN          MR_GKBWKUIKIGAIICHIRAN;         --区域外就学者一覧中間ワークカーソル
      rGKBWL672R001_I               GKBWL672R001%ROWTYPE;           --区域外就学者一覧ワーク
      nINDEX                        NUMBER := 0;
    BEGIN
        g_nCNT := GKBFKTBLCNT('GKBWKUIKIGAIICHIRAN', NULL);
        sSQL := '';
        sSQL := sSQL || 'SELECT * ';
        sSQL := sSQL || 'FROM GKBWKUIKIGAIICHIRAN ';
        IF g_rJSTP.ORDERBYCLAUSE IS NOT NULL THEN
          sSQL := sSQL || 'ORDER BY '|| g_rJSTP.ORDERBYCLAUSE;
        END IF;
        OPEN cCURSOR FOR sSQL;
        LOOP
            FETCH cCURSOR INTO rGKBWKUIKIGAIICHIRAN;
            EXIT WHEN cCURSOR%NOTFOUND;
            IF g_rJSTP.CHOHYOID = 'GKB672R001' THEN
              nINDEX := nINDEX + 1;
              rGKBWL672R001_I.NO                    := nINDEX;
              rGKBWL672R001_I.SAKUSEI_YMD           := rGKBWKUIKIGAIICHIRAN.SAKUSEI_YMD;
              rGKBWL672R001_I.JIDO_SHIMEI_KANA      := rGKBWKUIKIGAIICHIRAN.JIDO_SHIMEI_KANA;
              rGKBWL672R001_I.JIDO_SHIMEI_KANJI     := rGKBWKUIKIGAIICHIRAN.JIDO_SHIMEI_KANJI;
              rGKBWL672R001_I.HOGOSHA_SHIMEI_KANA   := rGKBWKUIKIGAIICHIRAN.HOGOSYA_SHIMEI_KANA;
              rGKBWL672R001_I.HOGOSHA_SHIMEI_KANJI  := rGKBWKUIKIGAIICHIRAN.HOGOSYA_SHIMEI_KANJI;
              rGKBWL672R001_I.SEINENGAPI            := rGKBWKUIKIGAIICHIRAN.SEINENGAPPI;
              rGKBWL672R001_I.SEIBETSU              := rGKBWKUIKIGAIICHIRAN.SEIBETSU;
              rGKBWL672R001_I.HOGOSHA_ZOKUGARA      := rGKBWKUIKIGAIICHIRAN.HOGOSHA_ZOKUGARA;
              rGKBWL672R001_I.JIDO_KOKUSEKI         := rGKBWKUIKIGAIICHIRAN.JIDO_KOKUSEKI;
              rGKBWL672R001_I.HOGOSHA_KOKUSEKI      := rGKBWKUIKIGAIICHIRAN.HOGOSYA_KOKUSEKI;
              rGKBWL672R001_I.GAKKO_MEI             := rGKBWKUIKIGAIICHIRAN.GAKKO_MEI;
              rGKBWL672R001_I.GAKUNEN               := rGKBWKUIKIGAIICHIRAN.GAKUNEN;
              rGKBWL672R001_I.SETISYAMEI            := rGKBWKUIKIGAIICHIRAN.SETISYAMEI;
              rGKBWL672R001_I.JIYU                  := rGKBWKUIKIGAIICHIRAN.JIYU;
              rGKBWL672R001_I.SHINSEI_YMD           := rGKBWKUIKIGAIICHIRAN.SHINSEI_YMD_HYOJI;
              rGKBWL672R001_I.KYOKA_YMD             := rGKBWKUIKIGAIICHIRAN.KYOKA_YMD;
              rGKBWL672R001_I.KAISHI_YMD            := rGKBWKUIKIGAIICHIRAN.KAISHI_YMD;
              rGKBWL672R001_I.SHURYO_YMD            := rGKBWKUIKIGAIICHIRAN.SHURYO_YMD;
              rGKBWL672R001_I.BREAK_NO              := LPAD(rGKBWKUIKIGAIICHIRAN.GAKKO_CD, 3, 0);
              rGKBWL672R001_I.WSNUM                 := g_sWSNUM;
              rGKBWL672R001_I.BATCHKBN              := 2;
              rGKBWL672R001_I.JOBNUM                := g_nJOBNUM;
              INSERT INTO GKBWL672R001 VALUES rGKBWL672R001_I;
              g_nCSVCNT := g_nCSVCNT + 1;
            END IF;
        END LOOP;
        IF cCURSOR%ISOPEN THEN
          CLOSE cCURSOR;
        END IF;
        bRTN := FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 0, '', '', '区域外就学者一覧[' || g_nCSVCNT || ']件を出力しました。', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
            IF cCURSOR%ISOPEN THEN
              CLOSE cCURSOR;
            END IF;
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 1, SQLCODE, SQLERRM, 'ＣＳＶファイルの書き出し処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN c_ERR;
    END FUNC_CSV_CREATE;
    --------------------------------------------------------
    --  機能概要      : 条件取得処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET
        RETURN BOOLEAN
    IS
      bRTN                          BOOLEAN;                        --戻り値
      sVSG                          NVARCHAR2(1000);                --戻り値
    BEGIN
--  2025/08/21 CTC.HJF UPDATE START 1.0.102.000: GKB_QA19873対応
        ----区域外就学申請年月日（開始）
        --bRTN := KKAPK0010.FISNUMERIC(g_sShinseiStartYmd);
        --IF NOT bRTN THEN
        --  RETURN FALSE;
        --END IF;
        ----処理条件.区域外就学申請年月日（終了）
        --bRTN := KKAPK0010.FISNUMERIC(g_sShinseiEndYmd);
        --IF NOT bRTN THEN
        --  RETURN FALSE;
        --END IF;
        ----処理条件.区域外就学許可年月日（開始）
        --bRTN := KKAPK0010.FISNUMERIC(g_sKyokaStartYmd);
        --IF NOT bRTN THEN
        --  RETURN FALSE;
        --END IF;
        ----処理条件.区域外就学許可年月日（終了）
        --bRTN := KKAPK0010.FISNUMERIC(g_sKyokaEndYmd);
        --IF NOT bRTN THEN
        --  RETURN FALSE;
        --END IF;
-- 2025/08/21 CTC.HJF UPDATE END
--  2024/11/13 ZCZL.WANGMING ADD START 0.3.000.003:仕様変更　ID：IT_GKB_00535対応
        oShinseiStartYmd := KKAPK0020.FNENDOHENKAN(g_sShinseiStartYmd);
        oShinseiEndYmd := KKAPK0020.FNENDOHENKAN(g_sShinseiEndYmd);
        oKyokaStartYmd := KKAPK0020.FNENDOHENKAN(g_sKyokaStartYmd);
        oKyokaEndYmd := KKAPK0020.FNENDOHENKAN(g_sKyokaEndYmd);
--  2024/11/13 ZCZL.WANGMING ADD END
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_JYOKEN_GET;
    --------------------------------------------------------
    --  機能概要      : 区域外就学者一覧中間ワーク作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
    --------------------------------------------------------
    FUNCTION FUNC_GKBWKUIKIGAIICHIRANSAKUJIXYO
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                             --戻り値
        nRTN                          NUMBER;                              --戻り値
        sSQL                          NVARCHAR2(32767);                    --SQL文
        TYPE MC_CURSOR IS REF CURSOR;
        cCURSOR                       MC_CURSOR;
        TYPE MR_GKBTGAKUREIBO IS RECORD(
          GAKUNEN                     GKBTGAKUREIBO.GAKUNEN%TYPE,
          KUIKIGAI_SETISYA            GKBTGAKUREIBO.KUIKIGAI_SETISYA%TYPE,
          KUIKIGAISHUGAKU_SHINSEI_BI  GKBTGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI%TYPE,
          KUIKIGAISHUGAKU_KYOKA_BI    GKBTGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI%TYPE,
          KUIKIGAISHUGAKU_KAISI_BI    GKBTGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI%TYPE,
          KUIKIGAISHUGAKU_SYURYO_BI   GKBTGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI%TYPE,
          KUIKIGAISHUGAKU_JIYU        GKBTGAKUREIBO.KUIKIGAISHUGAKU_JIYU%TYPE,
          ZOKUGARA1                   GKBTGAKUREIBO.ZOKUGARA1%TYPE,
          ZOKUGARA2                   GKBTGAKUREIBO.ZOKUGARA2%TYPE,
          ZOKUGARA3                   GKBTGAKUREIBO.ZOKUGARA3%TYPE,
          ZOKUGARA4                   GKBTGAKUREIBO.ZOKUGARA4%TYPE,
          GAKKO_KBN_CD                GKBTGAKUREIBO.GAKKO_KBN_CD%TYPE,
          GAKUKYU_CD                  GKBTGAKUREIBO.GAKUKYU_CD%TYPE,
          KUIKIGAI_CD                 GKBTGAKUREIBO.KUIKIGAI_CD%TYPE,
          HOGOSYA_KOJIN_NO            GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE,
          RIREKI_RENBAN               GKBTGAKUREIBO.RIREKI_RENBAN%TYPE,
          SAKUJO_FLG                  GKBTGAKUREIBO.SAKUJO_FLG%TYPE,
          KOJIN_NO                    GKBTGAKUREIBO.KOJIN_NO%TYPE
        );
        rGKBTGAKUREIBO                MR_GKBTGAKUREIBO;                    --区域外就学者一覧中間ワークカーソル
        rGKBWKUIKIGAIICHIRAN_I        GKBWKUIKIGAIICHIRAN%ROWTYPE;         --区域外就学者一覧中間ワーク
        SEINENGAPPI                   NVARCHAR2(10);
        sMEISHO                       NVARCHAR2(1000);                     --名称
        sMEISHOKANA                   NVARCHAR2(1000);                     --名称カナ
        sYOBI                         NVARCHAR2(1000);                     --予備
        rGABTATENAKIHON               GABTATENAKIHON%ROWTYPE;              --児童生徒の宛名基本
        rGABTSOFUSAKI                 GABTSOFUSAKI%ROWTYPE;                --児童生徒の送付先基本
        rGABTATENAKIHON_HOGOSYA       GABTATENAKIHON%ROWTYPE;              --保護者の宛名基本
        rGABTSOFUSAKI_HOGOSYA         GABTSOFUSAKI%ROWTYPE;                --保護者の送付先基本
        nERRCODE                      NUMBER;                              --エラーコード
        sKOKUMEI_KANA                 NVARCHAR2(1000);                     --国名カナ
        sKOKUMEI_ALPHABET             NVARCHAR2(1000);                     --国名アルファベット
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外就学者一覧中間ワーク作成', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        --区域外就学者一覧中間ワークをクリアする。
        sSQL := '';
        sSQL := sSQL || 'SELECT GAKUNEN,';
        sSQL := sSQL || '       KUIKIGAI_SETISYA,';
        sSQL := sSQL || '       KUIKIGAISHUGAKU_SHINSEI_BI,';
        sSQL := sSQL || '       KUIKIGAISHUGAKU_KYOKA_BI,';
        sSQL := sSQL || '       KUIKIGAISHUGAKU_KAISI_BI,';
        sSQL := sSQL || '       KUIKIGAISHUGAKU_SYURYO_BI,';
        sSQL := sSQL || '       KUIKIGAISHUGAKU_JIYU,';
        sSQL := sSQL || '       ZOKUGARA1,';
        sSQL := sSQL || '       ZOKUGARA2,';
        sSQL := sSQL || '       ZOKUGARA3,';
        sSQL := sSQL || '       ZOKUGARA4,';
        sSQL := sSQL || '       GAKKO_KBN_CD,';
        sSQL := sSQL || '       GAKUKYU_CD,';
        sSQL := sSQL || '       KUIKIGAI_CD,';
        sSQL := sSQL || '       HOGOSYA_KOJIN_NO,';
        sSQL := sSQL || '       RIREKI_RENBAN,';
        sSQL := sSQL || '       SAKUJO_FLG,';
        sSQL := sSQL || '       KOJIN_NO ';
        sSQL := sSQL || 'FROM GKBTGAKUREIBO ';
        sSQL := sSQL || 'WHERE ';
--  2024/11/13 ZCZL.WANGMING ADD UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00535対応
--        IF g_sShinseiStartYmd IS NOT NULL THEN
--          sSQL := sSQL || 'KUIKIGAISHUGAKU_SHINSEI_BI >= ' || KKAPK0020.FNENDOHENKAN(g_sShinseiStartYmd) || ' AND ';
-- 2025/08/21 CTC.HJF UPDATE START 1.0.102.000: GKB_QA19873対応
        --IF oShinseiStartYmd IS NOT NULL THEN
        IF oShinseiStartYmd IS NOT NULL AND oShinseiStartYmd <> 0 THEN
-- 2025/08/21 CTC.HJF UPDATE END
          sSQL := sSQL || 'KUIKIGAISHUGAKU_SHINSEI_BI >= ' || oShinseiStartYmd || ' AND ';
        END IF;
--        IF g_sShinseiEndYmd IS NOT NULL THEN
--          sSQL := sSQL || 'KUIKIGAISHUGAKU_SHINSEI_BI <= ' || KKAPK0020.FNENDOHENKAN(g_sShinseiEndYmd) || ' AND ';
-- 2025/08/21 CTC.HJF UPDATE START 1.0.102.000: GKB_QA19873対応
        --IF oShinseiEndYmd IS NOT NULL THEN
        IF oShinseiEndYmd IS NOT NULL  AND oShinseiEndYmd <> 0 THEN
-- 2025/08/21 CTC.HJF UPDATE END
          sSQL := sSQL || 'KUIKIGAISHUGAKU_SHINSEI_BI <= ' || oShinseiEndYmd || ' AND ';
        END IF;
--        IF g_sKyokaStartYmd IS NOT NULL THEN
--          sSQL := sSQL || 'KUIKIGAISHUGAKU_KYOKA_BI >= ' || KKAPK0020.FNENDOHENKAN(g_sKyokaStartYmd) || ' AND ';
-- 2025/08/21 CTC.HJF UPDATE START 1.0.102.000: GKB_QA19873対応
        --IF oKyokaStartYmd IS NOT NULL THEN
        IF oKyokaStartYmd IS NOT NULL  AND oKyokaStartYmd <> 0 THEN
-- 2025/08/21 CTC.HJF UPDATE END
          sSQL := sSQL || 'KUIKIGAISHUGAKU_KYOKA_BI >= ' || oKyokaStartYmd || ' AND ';
        END IF;
--        IF g_sKyokaEndYmd IS NOT NULL THEN
--          sSQL := sSQL || 'KUIKIGAISHUGAKU_KYOKA_BI <= ' || KKAPK0020.FNENDOHENKAN(g_sKyokaEndYmd) || ' AND ';
-- 2025/08/21 CTC.HJF UPDATE START 1.0.102.000: GKB_QA19873対応
        --IF oKyokaEndYmd IS NOT NULL THEN
        IF oKyokaEndYmd IS NOT NULL  AND oKyokaEndYmd <> 0 THEN
-- 2025/08/21 CTC.HJF UPDATE END
          sSQL := sSQL || 'KUIKIGAISHUGAKU_KYOKA_BI <= ' || oKyokaEndYmd || ' AND ';
        END IF;
--  2024/11/13 ZCZL.WANGMING ADD UPDATE END
        sSQL := sSQL || 'SAKUJO_FLG = 0 AND ';
--  2024/09/25 ZCZL.WANGMING UPDATE 0.3.000.001:仕様変更　ID：IT_GKB_00009対応
--        sSQL := sSQL || 'SAISHIN_KBN >= 0 AND ';
        sSQL := sSQL || 'SAISHIN_KBN = 0 AND ';
        sSQL := sSQL || 'GEN_NENGAPI = 0';
        OPEN cCURSOR FOR sSQL;
        LOOP
            FETCH cCURSOR INTO rGKBTGAKUREIBO;
            EXIT WHEN cCURSOR%NOTFOUND;
            --児童生徒の基本情報
            nRTN := GAAPK0030.FGETATENA(rGKBTGAKUREIBO.KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), rGABTATENAKIHON, rGABTSOFUSAKI);
            IF nRTN = 1 THEN
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '共通関数（GAAPK0030.FGETATENA）', 1, SQLCODE, SQLERRM, '共通関数(GAAPK0030.FGETATENA)を行った際にエラーが発生しました。宛名情報レコード未存在。宛名番号：' || rGKBTGAKUREIBO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
              RETURN FALSE;
            ELSIF nRTN = 2 THEN
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '共通関数（GAAPK0030.FGETATENA）', 1, SQLCODE, SQLERRM, '共通関数(GAAPK0030.FGETATENA)を行った際にエラーが発生しました。その他のエラー。宛名番号：' || rGKBTGAKUREIBO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
              RETURN FALSE;
            ELSE
              NULL;
            END IF;
            --保護者の基本情報
            nRTN := GAAPK0030.FGETATENA(rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), rGABTATENAKIHON_HOGOSYA, rGABTSOFUSAKI_HOGOSYA);
            IF nRTN = 1 THEN
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '共通関数（GAAPK0030.FGETATENA）', 1, SQLCODE, SQLERRM, '共通関数(GAAPK0030.FGETATENA)を行った際にエラーが発生しました。宛名情報レコード未存在。宛名番号：' || rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
              RETURN FALSE;
            ELSIF nRTN = 2 THEN
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '共通関数（GAAPK0030.FGETATENA）', 1, SQLCODE, SQLERRM, '共通関数(GAAPK0030.FGETATENA)を行った際にエラーが発生しました。その他のエラー。宛名番号：' || rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
              RETURN FALSE;
            ELSE
              NULL;
            END IF;
            rGKBWKUIKIGAIICHIRAN_I.SAKUSEI_YMD          := KKAPK0020.FDAYEDIT20(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), 0, 3, 0, '*');
            --児童生徒の本名使用制御判定
            nRTN := GKBFKHMCTRL(rGKBTGAKUREIBO.KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_sKYO_TCL, rGKBWKUIKIGAIICHIRAN_I.JIDO_SHIMEI_KANA, rGKBWKUIKIGAIICHIRAN_I.JIDO_SHIMEI_KANJI, rGKBWKUIKIGAIICHIRAN_I.SEINENGAPPI);
            --保護者の本名使用制御判定
            nRTN := GKBFKHMCTRL(rGKBTGAKUREIBO.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_sKYO_TCL, rGKBWKUIKIGAIICHIRAN_I.HOGOSYA_SHIMEI_KANA, rGKBWKUIKIGAIICHIRAN_I.HOGOSYA_SHIMEI_KANJI, SEINENGAPPI);
            --性別名取得
            nRTN := KKAPK0030.FCDGetR('GKB', '021', '0001', rGABTATENAKIHON.SEIBETSU, rGKBWKUIKIGAIICHIRAN_I.SEIBETSU, sMEISHOKANA, sYOBI);
            nRTN := GKBFKZKGMGET(2, rGABTATENAKIHON_HOGOSYA.ZOKUGARACD1, rGABTATENAKIHON_HOGOSYA.ZOKUGARACD2, rGABTATENAKIHON_HOGOSYA.ZOKUGARACD3,rGABTATENAKIHON_HOGOSYA.ZOKUGARACD4, rGKBWKUIKIGAIICHIRAN_I.HOGOSHA_ZOKUGARA, nERRCODE);
            nRTN := GKAFKKKMGET(rGABTATENAKIHON.KOKUSEKI_CD, sKOKUMEI_KANA, rGKBWKUIKIGAIICHIRAN_I.JIDO_KOKUSEKI, sKOKUMEI_ALPHABET);
            nRTN := GKAFKKKMGET(rGABTATENAKIHON_HOGOSYA.KOKUSEKI_CD, sKOKUMEI_KANA, rGKBWKUIKIGAIICHIRAN_I.HOGOSYA_KOKUSEKI, sKOKUMEI_ALPHABET);
            rGKBWKUIKIGAIICHIRAN_I.GAKKO_MEI            := GKAFKGKOGTEQ(rGKBTGAKUREIBO.GAKKO_KBN_CD, rGKBTGAKUREIBO.KUIKIGAI_CD);
            rGKBWKUIKIGAIICHIRAN_I.GAKUNEN := GKAFKGKNGTEQ(rGKBTGAKUREIBO.GAKUNEN);
            rGKBWKUIKIGAIICHIRAN_I.SETISYAMEI           := rGKBTGAKUREIBO.KUIKIGAI_SETISYA;
--  2025/05/17 ZCZL.WANGMING UPDATE 1.0.006.000: GKB_QA13966(保守2234)_区域外就学事由に前ゼロを付加対応
--            nRTN := KKAPK0030.FCDGetR('GKB', '028', '0001', rGKBTGAKUREIBO.KUIKIGAISHUGAKU_JIYU, rGKBWKUIKIGAIICHIRAN_I.JIYU, sMEISHOKANA, sYOBI);
            nRTN := KKAPK0030.FCDGetR('GKB', '028', '0001', LPAD(rGKBTGAKUREIBO.KUIKIGAISHUGAKU_JIYU, 2, '0'), rGKBWKUIKIGAIICHIRAN_I.JIYU, sMEISHOKANA, sYOBI);
            rGKBWKUIKIGAIICHIRAN_I.SHINSEI_YMD_HYOJI    := rGKBTGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI;
            rGKBWKUIKIGAIICHIRAN_I.KYOKA_YMD            := rGKBTGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI;
            rGKBWKUIKIGAIICHIRAN_I.KAISHI_YMD           := rGKBTGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI;
            rGKBWKUIKIGAIICHIRAN_I.SHURYO_YMD           := rGKBTGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI;
            rGKBWKUIKIGAIICHIRAN_I.JIDO_KOJIN_NO        := rGKBTGAKUREIBO.KOJIN_NO;
            rGKBWKUIKIGAIICHIRAN_I.SEINENGAPPI_SORT     := rGABTATENAKIHON.SEINENGAPI;
            rGKBWKUIKIGAIICHIRAN_I.GAKKO_KBN_CD         := rGKBTGAKUREIBO.GAKKO_KBN_CD;
            rGKBWKUIKIGAIICHIRAN_I.GAKKO_CD             := rGKBTGAKUREIBO.KUIKIGAI_CD;
            rGKBWKUIKIGAIICHIRAN_I.GAKUNEN_CD           := rGKBTGAKUREIBO.GAKUNEN;
            rGKBWKUIKIGAIICHIRAN_I.SHINSEI_YMD_SORT     := rGKBTGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI;
            rGKBWKUIKIGAIICHIRAN_I.KYOKA_YMD_SORT       := rGKBTGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI;
            INSERT INTO GKBWKUIKIGAIICHIRAN VALUES rGKBWKUIKIGAIICHIRAN_I;
        END LOOP;
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外就学者一覧中間ワーク作成', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外就学者一覧中間ワーク作成', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_GKBWKUIKIGAIICHIRANSAKUJIXYO;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;                     --戻り値
        eERR             EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        --条件取得処理を呼び出す。
        IF NOT FUNC_JYOKEN_GET THEN
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
        END IF;
        --初期処理を呼び出す。
        IF NOT FUNC_INIT THEN
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
        END IF;
        --区域外就学者一覧中間ワーク作成
        IF NOT FUNC_GKBWKUIKIGAIICHIRANSAKUJIXYO THEN
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
        END IF;
        --ＣＳＶファイル作成処理
        IF g_rJSTP.CHOHYOID = 'GKB672R001' THEN
          --区域外就学者一覧テーブルをクリアする。
          BEGIN
            DELETE FROM GKBWL672R001
            WHERE WSNUM = g_sWSNUM
            AND BATCHKBN = c_BATCH;
          EXCEPTION
            WHEN OTHERS THEN
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理１', 1, SQLCODE, SQLERRM, '区域外就学者一覧テーブルのデータを削除した際に異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
              RETURN FALSE;
          END;
          --ＣＳＶファイル作成処理を呼び出す。
          IF FUNC_CSV_CREATE = c_ERR THEN
            RAISE eERR;
          END IF;
          --CSV出力処理を呼び出す。
          bRTN := FUNC_B11CSV('GKBWL672R001');
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
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                             --戻り値
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
    --  作成者／作成日: ZCZL.LISHUAI   2024/07/10
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
END GKBPB00510;
/