CREATE OR REPLACE PACKAGE BODY GKBPB00540
--1.0.402.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: 就学校変更対象者一覧作成
--  プログラム名  : 就学校変更対象者一覧作成
--  機能概要      : 就学校変更対象者を抽出し、就学校変更対象者一覧を作成する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.BYN 2024/07/01
--------------------------------------------------------
--  変更履歴
--  2024/08/30 ZCZL.xiaoya UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/08/30 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/11/14 JPJYS.SONGSHIHAO UPDATE 0.3.000.003:仕様変更　IT_GKB_00545対応
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00618対応
--  2025/12/03 CTC.HJF UPDATE 1.0.402.000:保守QA23724対応
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
    
    g_sSHINSEI_YMD                NVARCHAR2(1000);            -- 就学校変更申請年月日（開始）
    g_sKYOKA_YMD                  NVARCHAR2(1000);            -- 就学校変更申請年月日（終了）
    g_sKAISHI_YMD                 NVARCHAR2(1000);            -- 就学校変更許可年月日（開始）
    g_sSHURYO_YMD                 NVARCHAR2(1000);            -- 就学校変更許可年月日（終了）
    g_tITEM                       A_CONS_PRM;
    g_nGKB675_INDEX               NUMBER;                     -- 就学校変更対象者一覧_インデックス番号
    g_sSHUGAKHENKOTAISHO          NVARCHAR2(1000);            -- 就学校変更対象者一覧_出力制御
    g_nCSVCNT                     NUMBER := 0;                -- CSV出力件数
    g_nCOUNT                      NUMBER := 0;                -- 件数
    -- 学齢簿用のレコード
    TYPE GAKUREIBO_REC IS RECORD
    (
      HOGOSYA_KOJIN_NO    GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE,
      SHITEI_SYOGAKO_CD   GKBTGAKUREIBO.SHITEI_SYOGAKO_CD%TYPE,
      SHITEI_TYUGAKO_CD   GKBTGAKUREIBO.SHITEI_TYUGAKO_CD%TYPE,
      HENKO_JIYU          GKBTGAKUREIBO.HENKO_JIYU%TYPE,
      KOJIN_NO            GKBTGAKUREIBO.KOJIN_NO%TYPE,
      HOGOSYA_ZOKUGARA1   GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1%TYPE,
      HOGOSYA_ZOKUGARA2   GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2%TYPE,
      HOGOSYA_ZOKUGARA3   GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3%TYPE,
      HOGOSYA_ZOKUGARA4   GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4%TYPE,
      GAKUNEN             GKBTGAKUREIBO.GAKUNEN%TYPE,
      HENKO_SHINSEI_BI    GKBTGAKUREIBO.HENKO_SHINSEI_BI%TYPE,
      HENKO_KYOKA_BI      GKBTGAKUREIBO.HENKO_KYOKA_BI%TYPE,
      HENKO_KAISI_BI      GKBTGAKUREIBO.HENKO_KAISI_BI%TYPE,
      HENKO_SYURYO_BI     GKBTGAKUREIBO.HENKO_SYURYO_BI%TYPE,
      SHOGAKKOKU_CD       GKBTGAKUREIBO.SHOGAKKOKU_CD%TYPE,
      CHUGAKKOKU_CD       GKBTGAKUREIBO.CHUGAKKOKU_CD%TYPE,
      GAKKO_KBN_CD        GKBTGAKUREIBO.GAKKO_KBN_CD%TYPE,
      GAKUKYU_CD          GKBTGAKUREIBO.GAKUKYU_CD%TYPE,
      SYOGAKO_CD          GKBTGAKUREIBO.SYOGAKO_CD%TYPE,
      TYUGAKO_CD          GKBTGAKUREIBO.TYUGAKO_CD%TYPE
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
    --  作成者／作成日: ZCZL.BYN 2024/07/01
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
    --  作成者／作成日: ZCZL.BYN 2024/07/01
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.BYN 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
    BEGIN
        -- 就学校変更申請年月日（開始）
        g_sSHINSEI_YMD := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHenKoStartYmd');
        IF g_sSHINSEI_YMD IS NULL OR g_sSHINSEI_YMD =''THEN
            g_sSHINSEI_YMD := '0';
        END IF;
        -- 就学校変更申請年月日（終了）
        g_sKYOKA_YMD := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHenKoEndYmd');
        IF g_sKYOKA_YMD IS NULL OR g_sKYOKA_YMD ='' THEN
            g_sKYOKA_YMD := '99999999';
        END IF;
        -- 就学校変更許可年月日（開始）
        g_sKAISHI_YMD := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKyokaStartYmd');
        IF g_sKAISHI_YMD IS NULL OR g_sKAISHI_YMD ='' THEN
            g_sKAISHI_YMD := '0';
        END IF;
        -- 就学校変更許可年月日（開始）
        g_sSHURYO_YMD := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKyokaEndYmd');
        IF g_sSHURYO_YMD IS NULL OR g_sSHURYO_YMD =''THEN
            g_sSHURYO_YMD := '99999999';
        END IF;
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
    --  作成者／作成日: ZCZL.BYN 2024/07/01
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
    --  機能概要      : 条件取得処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.BYN 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET
        RETURN BOOLEAN
    IS
       bRTN          BOOLEAN; -- 戻り値
    BEGIN
        IF NOT KKAPK0010.FISNUMERIC(g_sSHINSEI_YMD) THEN
            RETURN FALSE;
        ELSIF NOT KKAPK0010.FISNUMERIC(g_sKYOKA_YMD) THEN
            RETURN FALSE;
        ELSIF NOT KKAPK0010.FISNUMERIC(g_sKAISHI_YMD) THEN
            RETURN FALSE;
        ELSIF NOT KKAPK0010.FISNUMERIC(g_sSHURYO_YMD) THEN
            RETURN FALSE;
        ELSE
            NULL;
        END IF;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/08/30 ZCZL.xiaoya UPDATE 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG ('処理条件の取得が異常終了しました。', 1, '', '', '', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JYOKEN_GET', 1, SQLCODE, SQLERRM, '処理条件の取得が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_JYOKEN_GET;    
    --------------------------------------------------------
    --  機能概要      : 初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.BYN 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_INIT
        RETURN BOOLEAN
    IS
        nRTN                          NUMBER;  --戻り値
        bRTN                          BOOLEAN; -- 戻り値
    BEGIN
        nRTN :=KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, g_tITEM); 
        IF nRTN = 0 THEN
          FOR i IN 1..g_tITEM.COUNT LOOP
            IF g_tITEM(i) = 'GKB675R001' THEN
              g_nGKB675_INDEX := i;
            END IF;
          END LOOP;
        END IF;
        nRTN :=KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, g_tITEM);
        IF nRTN = 0 AND g_tITEM.COUNT >= g_nGKB675_INDEX THEN
            g_sSHUGAKHENKOTAISHO := g_tITEM(g_nGKB675_INDEX);
        END IF;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/08/30 ZCZL.xiaoya UPDATE 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG ('初期処理が異常終了しました。', 1, '', '', '', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INIT', 1, SQLCODE, SQLERRM, '初期処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_INIT;    
    --------------------------------------------------------
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : NUMBER
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.BYN 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE
        RETURN NUMBER
    IS
        nPAGE                         NUMBER;
        nRENBAN                       NUMBER;
        VSQL                          NVARCHAR2(10000);
        rWLTBL                        GKBWSHUGAKHENKOTAISHO%ROWTYPE;
        rWL675R001TBL                 GKBWL675R001%ROWTYPE;
        sJIDOSHIMEIKANA               GABTATENAKIHON.TSUSHOMEI_KANA%TYPE;
        sJIDOSHIMEI                   GABTATENAKIHON.TSUSHOMEI_KANJI%TYPE;
        sBIRTHDAY                     NVARCHAR2(1000);
        sHOGOSHASHIMEIKANA            GABTATENAKIHON.TSUSHOMEI_KANA%TYPE;
        sHOGOSHASHIMEI                GABTATENAKIHON.TSUSHOMEI_KANJI%TYPE;
        eJIDORATENA_RECORD            GABTATENAKIHON%ROWTYPE;
        eJIDORSOFU_RECORD             GABTSOFUSAKI%ROWTYPE;
        eHOGOSHARATENA_RECORD         GABTATENAKIHON%ROWTYPE;
        eHOGOSHARSOFU_RECORD          GABTSOFUSAKI%ROWTYPE;
        sJIDOMEISHO                   KKATCD.MEISHO%TYPE;
        sJIYUMEISHO                   KKATCD.MEISHO%TYPE;
        sJIDOMEISHOKANA               KKATCD.MEISHOKANA%TYPE;
        sJIDOYOBI                     KKATCD.YOBI%TYPE;
        sZOKUGARAMEI                  NVARCHAR2(1000);
        sKOKUMEI_KANA                 GABTKOKUSEKI.KOKUMEI_KANA%TYPE;       --国名カナ
        sKOKUMEI                      GABTKOKUSEKI.KOKUMEI%TYPE;            --国名漢字
        sKOKUMEI_ALPHABET             GABTKOKUSEKI.KOKUMEI_ALPHABET%TYPE;   --国名アルファベット
        nGAKKO_KBN_CD                 NUMBER;
        nHERR                         PLS_INTEGER;
        nRTN                          NUMBER;  --戻り値
        bRTN                          BOOLEAN;
        sMEISHO                       NVARCHAR2(1000);
        sMEISHOKANA                   NVARCHAR2(1000);
        sYOBI                         NVARCHAR2(1000);
        c_GAKUREREC                   GAKUREIBO_REC;
        sSHINSEI_YMD                  NVARCHAR2(1000);            -- 就学校変更申請年月日（開始）
        sKYOKA_YMD                    NVARCHAR2(1000);            -- 就学校変更申請年月日（終了）
        sKAISHI_YMD                   NVARCHAR2(1000);            -- 就学校変更許可年月日（開始）
        sSHURYO_YMD                   NVARCHAR2(1000);            -- 就学校変更許可年月日（終了）
        CURSOR cGAKUREIBO IS
            SELECT HOGOSYA_KOJIN_NO,               --保護者宛名番号
                   SHITEI_SYOGAKO_CD,              --就学指定校_小学校
                   SHITEI_TYUGAKO_CD,              --就学指定校_中学校
                   HENKO_JIYU,                     --就学校変更_事由
                   KOJIN_NO,                       --宛名番号
                   HOGOSYA_ZOKUGARA1,              --保護者続柄１
                   HOGOSYA_ZOKUGARA2,              --保護者続柄２
                   HOGOSYA_ZOKUGARA3,              --保護者続柄３
                   HOGOSYA_ZOKUGARA4,              --保護者続柄４
                   GAKUNEN,                        --学年
                   HENKO_SHINSEI_BI,               --就学校変更_申請年月日
                   HENKO_KYOKA_BI,                 --就学校変更_許可年月日
                   HENKO_KAISI_BI,                 --就学校変更_開始年月日
                   HENKO_SYURYO_BI,                --就学校変更_終了年月日
                   SHOGAKKOKU_CD,                  --小学校区コード
                   CHUGAKKOKU_CD,                  --中学校区コード
                   GAKKO_KBN_CD,                   --学校区分コード
                   GAKUKYU_CD,                     --学級コード
                   SYOGAKO_CD,                     --小学校コード
                   TYUGAKO_CD,                     --中学校コード
                   KUIKIGAI_CD,                    --区域外学校コード
                   YOGOGAKO_CD,                    --盲聾養護学校コード
                   KUNISHIRITSU_CD                 --国私立学校コード
            FROM GKBTGAKUREIBO 
            --  2024/11/14 JPJYS.SONGSHIHAO UPDATE 0.3.000.003:仕様変更　IT_GKB_00545対応 Start
            --WHERE HENKO_SHINSEI_BI <= sKYOKA_YMD
            --AND HENKO_SHINSEI_BI >= sSHINSEI_YMD
            --AND HENKO_KAISI_BI <= sKAISHI_YMD
            --AND HENKO_SYURYO_BI >= sSHURYO_YMD
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00618対応 Start
--            WHERE HENKO_SHINSEI_BI >= sKYOKA_YMD
            WHERE HENKO_SHINSEI_BI >= sSHINSEI_YMD
--            AND HENKO_SHINSEI_BI <= sSHINSEI_YMD
            AND HENKO_SHINSEI_BI <= sKYOKA_YMD
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00618対応 End
            AND HENKO_KYOKA_BI >= sKAISHI_YMD
            AND HENKO_KYOKA_BI <= sSHURYO_YMD
            --  2024/11/14 JPJYS.SONGSHIHAO UPDATE 0.3.000.003:仕様変更　IT_GKB_00545対応 End
            AND SAKUJO_FLG = 0
            AND SAISHIN_KBN = 0
            AND NVL(GEN_NENGAPI, 0) = 0;
        rWSHUGAKHENKOTAISHO                         GKBWSHUGAKHENKOTAISHO%ROWTYPE;
        TYPE CURTYPE IS REF CURSOR;
        CDATA       CURTYPE;
            
    BEGIN
        nPAGE := 0;
        nRENBAN := 0;
        sSHINSEI_YMD := KKAPK0020.FNENDOHENKAN(g_sSHINSEI_YMD);    -- 就学校変更申請年月日（開始）
        sKYOKA_YMD := KKAPK0020.FNENDOHENKAN(g_sKYOKA_YMD);        -- 就学校変更申請年月日（終了）
        sKAISHI_YMD := KKAPK0020.FNENDOHENKAN(g_sKAISHI_YMD);      -- 就学校変更許可年月日（開始）
        sSHURYO_YMD := KKAPK0020.FNENDOHENKAN(g_sSHURYO_YMD);      -- 就学校変更許可年月日（終了）
        IF g_rJSTP.CHOHYOID = 'GKB675R001' THEN
            FOR c_GAKUREREC IN cGAKUREIBO LOOP
                -- 作成年月日
                rWLTBL.SAKUSEI_YMD := KKAPK0020.FDateFmt(TO_CHAR(SYSDATE,'YYYY/MM/DD'), 1);
                -- 児童生徒
                nRTN := GKBFKHMCTRL(c_GAKUREREC.KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_sSHUGAKHENKOTAISHO, sJIDOSHIMEIKANA, sJIDOSHIMEI, sBIRTHDAY);
                IF nRTN = 0 THEN
                    -- 児童生徒氏名カナ
                    rWLTBL.JIDO_SHIMEI_KANA := sJIDOSHIMEIKANA;
                    -- 児童生徒氏名漢字
                    rWLTBL.JIDO_SHIMEI_KANJI := sJIDOSHIMEI;
                    -- 生年月日
                    rWLTBL.SEINENGAPI := sBIRTHDAY;
                END IF;
                -- 保護者
                nRTN := GKBFKHMCTRL(c_GAKUREREC.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_sSHUGAKHENKOTAISHO, sHOGOSHASHIMEIKANA, sHOGOSHASHIMEI, sBIRTHDAY);
                IF nRTN = 0 THEN
                    -- 保護者氏名カナ
                    rWLTBL.HOGOSHA_SHIMEI_KANA := sHOGOSHASHIMEIKANA;
                    -- 保護者氏名漢字
                    rWLTBL.HOGOSHA_SHIMEI_KANJI := sHOGOSHASHIMEI;
                END IF;
                -- 児童生徒の基本情報
                nRTN := GAAPK0030.FGETATENA(TO_NUMBER(c_GAKUREREC.KOJIN_NO), 'GKB', TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), eJIDORATENA_RECORD, eJIDORSOFU_RECORD);
                IF nRTN = 0 THEN
                    nRTN := KKAPK0030.FCDGetR('GKB','021','0001', eJIDORATENA_RECORD.SEIBETSU, sJIDOMEISHO, sJIDOMEISHOKANA, sJIDOYOBI);
                    IF nRTN = 0 THEN
                        -- 性別
                        rWLTBL.SEIBETSU := sJIDOMEISHO;
                    END IF;
                    nRTN := GKAFKKKMGET(eJIDORATENA_RECORD.KOKUSEKI_CD, sKOKUMEI_KANA, sKOKUMEI, sKOKUMEI_ALPHABET);
                    IF nRTN = 0 THEN
                        --  児童生徒国籍
                        rWLTBL.JIDO_KOKUSEKI := sKOKUMEI;
                    END IF;
                ELSIF nRTN = 1 THEN
--  2024/08/30 ZCZL.xiaoya UPDATE 0.3.000.001:8月1日認識合わせの横展開
--                    bRTN := FUNC_SETLOG ('共通関数(宛名情報取得)(GAAPK0030.FGETATENA)でエラーが発生しました。'||c_GAKUREREC.KOJIN_NO , 1, '', '', '宛名情報レコード未存在', g_sTANTOCODE, g_sWSNUM, 1);
                    bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_CSV_CREATE', 1, '', '', '宛名情報レコード未存在', g_sTANTOCODE, g_sWSNUM, 1);
                ELSIF nRTN = 2 THEN
--  2024/08/30 ZCZL.xiaoya UPDATE 0.3.000.001:8月1日認識合わせの横展開
--                    bRTN := FUNC_SETLOG ('共通関数(宛名情報取得)(GAAPK0030.FGETATENA)でエラーが発生しました。'||c_GAKUREREC.KOJIN_NO , 1, '', '', 'その他のエラー', g_sTANTOCODE, g_sWSNUM, 1);
                    bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_CSV_CREATE', 1, '', '', 'その他のエラー', g_sTANTOCODE, g_sWSNUM, 1);
                ELSE
                    NULL;
                END IF;
                nRTN := GKBFKZKGMGET(2, c_GAKUREREC.HOGOSYA_ZOKUGARA1, c_GAKUREREC.HOGOSYA_ZOKUGARA2, c_GAKUREREC.HOGOSYA_ZOKUGARA3, c_GAKUREREC.HOGOSYA_ZOKUGARA4, sZOKUGARAMEI, nHERR);
                IF nRTN = 0 THEN
                    -- 児童生徒との関係 
                    rWLTBL.HOGOSHA_ZOKUGARA := sZOKUGARAMEI;
                END IF;
                -- 保護者の基本情報
                nRTN := GAAPK0030.FGETATENA(c_GAKUREREC.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), eHOGOSHARATENA_RECORD, eHOGOSHARSOFU_RECORD);
                IF nRTN = 0 THEN
                    nRTN := GKAFKKKMGET(eHOGOSHARATENA_RECORD.KOKUSEKI_CD, sKOKUMEI_KANA, sKOKUMEI, sKOKUMEI_ALPHABET);
                    IF nRTN = 0 THEN
                        -- 保護者国籍
                        rWLTBL.HOGOSHA_KOKUSEKI := sKOKUMEI;
                    END IF;
                ELSIF nRTN = 1 THEN
--  2024/08/30 ZCZL.xiaoya UPDATE 0.3.000.001:8月1日認識合わせの横展開
--                    bRTN := FUNC_SETLOG ('共通関数(宛名情報取得)(GAAPK0030.FGETATENA)でエラーが発生しました。'||c_GAKUREREC.KOJIN_NO , 1, '', '', '宛名情報レコード未存在', g_sTANTOCODE, g_sWSNUM, 1);
                    bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_CSV_CREATE', 1, '', '', '宛名情報レコード未存在', g_sTANTOCODE, g_sWSNUM, 1);
                ELSIF nRTN = 2 THEN
--  2024/08/30 ZCZL.xiaoya UPDATE 0.3.000.001:8月1日認識合わせの横展開
--                    bRTN := FUNC_SETLOG ('共通関数(宛名情報取得)(GAAPK0030.FGETATENA)でエラーが発生しました。'||c_GAKUREREC.KOJIN_NO , 1, '', '', 'その他のエラー', g_sTANTOCODE, g_sWSNUM, 1);
                    bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_CSV_CREATE', 1, '', '', 'その他のエラー', g_sTANTOCODE, g_sWSNUM, 1);
                ELSE
                    NULL;
                END IF;
                -- 学校区分コード
                nGAKKO_KBN_CD := c_GAKUREREC.GAKKO_KBN_CD;
                -- 学校名
                IF nGAKKO_KBN_CD = 1 THEN
                    --小学校コード
                    rWLTBL.GAKKO_MEI := GKAFKGKOGTEQ(nGAKKO_KBN_CD, c_GAKUREREC.SYOGAKO_CD);
                ELSIF nGAKKO_KBN_CD = 2 THEN
                    --中学校コード
                    rWLTBL.GAKKO_MEI := GKAFKGKOGTEQ(nGAKKO_KBN_CD, c_GAKUREREC.TYUGAKO_CD);
                ELSIF nGAKKO_KBN_CD = 3 THEN
                    --盲聾養護学校コード
                    rWLTBL.GAKKO_MEI := GKAFKGKOGTEQ(nGAKKO_KBN_CD, c_GAKUREREC.KUIKIGAI_CD);
                ELSIF nGAKKO_KBN_CD = 4 THEN
                    --区域外学校コード
                    rWLTBL.GAKKO_MEI := GKAFKGKOGTEQ(nGAKKO_KBN_CD, c_GAKUREREC.YOGOGAKO_CD);
                ELSIF nGAKKO_KBN_CD = 5 THEN
                    --国私立学校コード
                    rWLTBL.GAKKO_MEI := GKAFKGKOGTEQ(nGAKKO_KBN_CD, c_GAKUREREC.KUNISHIRITSU_CD);
                ELSE
                  NULL;
                END IF;
                -- 学年
                rWLTBL.GAKUNEN := GKAFKGKNGTEQ(c_GAKUREREC.GAKUNEN);
                -- 学校区
                IF nGAKKO_KBN_CD = 1 THEN
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00618対応 Start
--                    nRTN := KKAPK0030.FCDGetR('GKB', '023', '0001', c_GAKUREREC.SYOGAKO_CD, sMEISHO, sMEISHOKANA, sYOBI);
                    nRTN := KKAPK0030.FCDGetR('GKB', '023', '0001', LPAD(c_GAKUREREC.SYOGAKO_CD,5,0), sMEISHO, sMEISHOKANA, sYOBI);
                ELSIF nGAKKO_KBN_CD = 2 THEN
--                    nRTN := KKAPK0030.FCDGetR('GKB', '023', '0002', c_GAKUREREC.TYUGAKO_CD, sMEISHO, sMEISHOKANA, sYOBI);
                    nRTN := KKAPK0030.FCDGetR('GKB', '023', '0002', LPAD(c_GAKUREREC.TYUGAKO_CD,5,0), sMEISHO, sMEISHOKANA, sYOBI);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00618対応 End
                ELSE
                  NULL;
                END IF;
                IF nRTN = 0 THEN
                    rWLTBL.GAKKOKU := sMEISHO;
                END IF;
                -- 指定校名
                IF c_GAKUREREC.GAKUNEN <= 6 THEN
                    rWLTBL.SHITEIKO_MEI := GKAFKGKOGTEQ(1, c_GAKUREREC.SHITEI_SYOGAKO_CD);
                ELSIF c_GAKUREREC.GAKUNEN >= 7 THEN
                    rWLTBL.SHITEIKO_MEI := GKAFKGKOGTEQ(2, c_GAKUREREC.SHITEI_TYUGAKO_CD);
                ELSE
                    NULL;
                END IF; 
                -- 事由
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00618対応 Start
--                nRTN := KKAPK0030.FCDGetR('GKB','027','0001', c_GAKUREREC.HENKO_JIYU, sJIYUMEISHO, sJIDOMEISHOKANA, sJIDOYOBI);
                nRTN := KKAPK0030.FCDGetR('GKB','027','0001', LPAD(c_GAKUREREC.HENKO_JIYU,2,0), sJIYUMEISHO, sJIDOMEISHOKANA, sJIDOYOBI);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00618対応 End
                IF nRTN = 0 THEN
                    rWLTBL.JIYU := sJIYUMEISHO;
                END IF;
--  2025/12/03 CTC.HJF UPDATE START 1.0.402.000:保守QA23724対応
                -- 申請年月日
                --rWLTBL.SHINSEI_YMD := KKAPK0020.FDAYEDIT20(g_sSHINSEI_YMD, 0, 3);
                rWLTBL.SHINSEI_YMD := KKAPK0020.FDAYEDIT20(c_GAKUREREC.HENKO_SHINSEI_BI, 0, 3);
                -- 許可年月日
                --rWLTBL.KYOKA_YMD := KKAPK0020.FDAYEDIT20(g_sKYOKA_YMD, 0, 3);
                rWLTBL.KYOKA_YMD := KKAPK0020.FDAYEDIT20(c_GAKUREREC.HENKO_KYOKA_BI, 0, 3);
                -- 開始年月日
                --rWLTBL.KAISHI_YMD := KKAPK0020.FDAYEDIT20(g_sKAISHI_YMD, 0, 3);
                rWLTBL.KAISHI_YMD := KKAPK0020.FDAYEDIT20(c_GAKUREREC.HENKO_KAISI_BI, 0, 3);
                -- 終了年月日
                --rWLTBL.SHURYO_YMD := KKAPK0020.FDAYEDIT20(g_sSHURYO_YMD, 0, 3);
                rWLTBL.SHURYO_YMD := KKAPK0020.FDAYEDIT20(c_GAKUREREC.HENKO_SYURYO_BI, 0, 3);
--  2025/12/03 CTC.HJF UPDATE END
                INSERT INTO GKBWSHUGAKHENKOTAISHO VALUES rWLTBL;
                g_nCSVCNT := g_nCSVCNT + 1;
            END LOOP;
            -- 就学校変更対象者一覧中間ワークからデータを取得し
            VSQL := '';
            VSQL := VSQL || ' SELECT * ';
            VSQL := VSQL || ' FROM GKBWSHUGAKHENKOTAISHO ';
            IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
                VSQL := VSQL || ' ORDER BY '|| g_rJSTP.Orderbyclause ;
            END IF;
            OPEN CDATA FOR VSQL;
            LOOP
                FETCH CDATA INTO rWSHUGAKHENKOTAISHO;
                EXIT WHEN CDATA%NOTFOUND;
                nPAGE := nPAGE +1;
                nRENBAN := FLOOR(nPAGE/11) +1;
                -- 就学校変更対象者一覧ワーク編集
                rWL675R001TBL.NO := nPAGE;                                              --ソート順
--  2024/09/05 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.002:8月1日認識合わせの横展開
--                rWL675R001TBL.SAKUSEI_YMD := rWLTBL.SAKUSEI_YMD;                        --作成年月日
--                rWL675R001TBL.JIDO_SHIMEI_KANA := rWLTBL.JIDO_SHIMEI_KANA;              --児童生徒氏名カナ
--                rWL675R001TBL.JIDO_SHIMEI_KANJI := rWLTBL.JIDO_SHIMEI_KANJI;            --児童生徒氏名漢字
--                rWL675R001TBL.HOGOSHA_SHIMEI_KANA := rWLTBL.HOGOSHA_SHIMEI_KANA;        --保護者氏名カナ
--                rWL675R001TBL.HOGOSHA_SHIMEI_KANJI := rWLTBL.HOGOSHA_SHIMEI_KANJI;      --保護者氏名漢字
--                rWL675R001TBL.SEINENGAPI := rWLTBL.SEINENGAPI;                          --生年月日
--                rWL675R001TBL.SEIBETSU := rWLTBL.SEIBETSU;                              --性別
--                rWL675R001TBL.HOGOSHA_ZOKUGARA := rWLTBL.HOGOSHA_ZOKUGARA;              --児童生徒との関係
--                rWL675R001TBL.JIDO_KOKUSEKI := rWLTBL.JIDO_KOKUSEKI;                    --児童生徒国籍
--                rWL675R001TBL.HOGOSHA_KOKUSEKI := rWLTBL.HOGOSHA_KOKUSEKI;              --保護者国籍
--                rWL675R001TBL.GAKKO_MEI := rWLTBL.GAKKO_MEI;                            --学校名
--                rWL675R001TBL.GAKUNEN := rWLTBL.GAKUNEN;                                --学年
--                rWL675R001TBL.GAKKOKU := rWLTBL.GAKKOKU;                                --学校区
--                rWL675R001TBL.SHITEIKO_MEI := rWLTBL.SHITEIKO_MEI;                      --指定校名
--                rWL675R001TBL.JIYU := rWLTBL.JIYU;                                      --事由
--                rWL675R001TBL.SHINSEI_YMD := rWLTBL.SHINSEI_YMD;                        --申請年月日
--                rWL675R001TBL.KYOKA_YMD := rWLTBL.KYOKA_YMD;                            --許可年月日
--                rWL675R001TBL.KAISHI_YMD := rWLTBL.KAISHI_YMD;                          --開始年月日
--                rWL675R001TBL.SHURYO_YMD := rWLTBL.SHURYO_YMD;                          --終了年月日
		            rWL675R001TBL.SAKUSEI_YMD          := rWSHUGAKHENKOTAISHO.SAKUSEI_YMD;               --作成年月日
                rWL675R001TBL.JIDO_SHIMEI_KANA     := rWSHUGAKHENKOTAISHO.JIDO_SHIMEI_KANA;          --児童生徒氏名カナ
                rWL675R001TBL.JIDO_SHIMEI_KANJI    := rWSHUGAKHENKOTAISHO.JIDO_SHIMEI_KANJI;         --児童生徒氏名漢字
                rWL675R001TBL.HOGOSHA_SHIMEI_KANA  := rWSHUGAKHENKOTAISHO.HOGOSHA_SHIMEI_KANA;       --保護者氏名カナ
                rWL675R001TBL.HOGOSHA_SHIMEI_KANJI := rWSHUGAKHENKOTAISHO.HOGOSHA_SHIMEI_KANJI;      --保護者氏名漢字
                rWL675R001TBL.SEINENGAPI           := rWSHUGAKHENKOTAISHO.SEINENGAPI;                --生年月日
                rWL675R001TBL.SEIBETSU             := rWSHUGAKHENKOTAISHO.SEIBETSU;                  --性別
                rWL675R001TBL.HOGOSHA_ZOKUGARA     := rWSHUGAKHENKOTAISHO.HOGOSHA_ZOKUGARA;          --児童生徒との関係
                rWL675R001TBL.JIDO_KOKUSEKI        := rWSHUGAKHENKOTAISHO.JIDO_KOKUSEKI;             --児童生徒国籍
                rWL675R001TBL.HOGOSHA_KOKUSEKI     := rWSHUGAKHENKOTAISHO.HOGOSHA_KOKUSEKI;          --保護者国籍
                rWL675R001TBL.GAKKO_MEI            := rWSHUGAKHENKOTAISHO.GAKKO_MEI;                 --学校名
                rWL675R001TBL.GAKUNEN              := rWSHUGAKHENKOTAISHO.GAKUNEN;                   --学年
                rWL675R001TBL.GAKKOKU              := rWSHUGAKHENKOTAISHO.GAKKOKU;                   --学校区
                rWL675R001TBL.SHITEIKO_MEI         := rWSHUGAKHENKOTAISHO.SHITEIKO_MEI;              --指定校名
                rWL675R001TBL.JIYU                 := rWSHUGAKHENKOTAISHO.JIYU;                      --事由
                rWL675R001TBL.SHINSEI_YMD          := rWSHUGAKHENKOTAISHO.SHINSEI_YMD;               --申請年月日
                rWL675R001TBL.KYOKA_YMD            := rWSHUGAKHENKOTAISHO.KYOKA_YMD;                 --許可年月日
                rWL675R001TBL.KAISHI_YMD           := rWSHUGAKHENKOTAISHO.KAISHI_YMD;                --開始年月日
                rWL675R001TBL.SHURYO_YMD           := rWSHUGAKHENKOTAISHO.SHURYO_YMD;                --終了年月日
--  2024/09/05 ZCZL.LIUCHANGQUAN UPDATE END
                rWL675R001TBL.BREAK_NO := nRENBAN;                                      --改ページキー
                rWL675R001TBL.WSNUM := g_sWSNUM;                                        --端末番号
                rWL675R001TBL.BATCHKBN := 2;                                            --即時バッチ区分
                rWL675R001TBL.JOBNUM := g_nJOBNUM;                                      --ジョブNO
                INSERT INTO GKBWL675R001 VALUES rWL675R001TBL;
            END LOOP;
            CLOSE CDATA;
        ELSE
            NULL;
        END IF;
        -- 中間ワークテーブル件数カウント処理
        g_nCOUNT := GKBFKTBLCNT('GKBWSHUGAKHENKOTAISHO',NULL);
        -- ＣＳＶファイル作成処理(FUNC_CSV_CREATE) 正常終了の場合
--  2024/08/30 ZCZL.xiaoya UPDATE 0.3.000.001:8月1日認識合わせの横展開
--        bRTN := FUNC_SETLOG ('就学校変更者一覧ＣＳＶ'|| g_nCSVCNT ||'件を出力しました', 0, '', '', '', g_sTANTOCODE, g_sWSNUM, 1);
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_CSV_CREATE', 0, '', '', '就学校変更者一覧ＣＳＶ'|| g_nCSVCNT ||'件を出力しました', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN 0;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/08/30 ZCZL.xiaoya UPDATE 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG ('ＣＳＶファイルの書き出し処理が異常終了しました。', 1, '', '', '', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_CSV_CREATE', 1, SQLCODE, SQLERRM, 'ＣＳＶファイルの書き出し処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            CLOSE CDATA;
            RETURN SQLCODE;
    END FUNC_CSV_CREATE;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.BYN 2024/07/01
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
        bRTNKAISHI                    BOOLEAN;  --戻り値
        bRTNKYOKA                     BOOLEAN;  --戻り値
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
        IF NOT bRTN THEN
            o_vRESULT := g_sMESSAGE;
            RETURN;
        END IF;
-- 2024/08/30 ZCZL.xiaoya Add 0.3.000.001:8月1日認識合わせの横展開
        g_sMESSAGE := '';
        -- 入力値チェック
        -- 処理条件.就学校変更申請年月日（開始）
        bRTNKAISHI := KKAPK0020.FISDATEW(g_sSHINSEI_YMD);
        -- 処理条件.就学校変更申請年月日（終了）
        bRTNKYOKA := KKAPK0020.FISDATEW(g_sKYOKA_YMD);
        IF NOT bRTNKAISHI OR NOT bRTNKYOKA THEN
            g_sMESSAGE := g_sMESSAGE || g_sGYOUMUCODE || ',99999,就学校変更申請年月日（開始）、就学校変更申請年月日（終了）が入力されていない,;';
            o_vRESULT := g_sMESSAGE;
        END IF;      
        -- 処理条件.就学校変更申請年月日（開始）
        bRTNKAISHI := KKAPK0020.FISDATEW(g_sKAISHI_YMD);        
        -- 処理条件.就学校変更許可年月日（終了）
        bRTNKYOKA := KKAPK0020.FISDATEW(g_sSHURYO_YMD);
        IF NOT bRTNKAISHI OR NOT bRTNKYOKA THEN
            g_sMESSAGE := g_sMESSAGE || g_sGYOUMUCODE || ',99999,就学校変更許可年月日（開始）、就学校変更許可年月日（終了）が入力されていない,;';
            o_vRESULT := g_sMESSAGE;
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
    --  作成者／作成日: ZCZL.BYN 2024/07/01
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
    --  作成者／作成日: ZCZL.BYN 2024/07/01
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
    --  作成者／作成日: ZCZL.BYN 2024/07/01
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
        g_oKENSU_LIST := GKBEKENSU_LIST();
        g_oKENSU_LIST.EXTEND();
        g_oKENSU_LIST(1) := GKBEKENSU_RECORD(g_nCOUNT, '就学校変更者一覧', 1);
        g_oKENSU_LIST.EXTEND();
        g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nCSVCNT, '就学校変更者一覧ＣＳＶ', 2);
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
    --  作成者／作成日: ZCZL.BYN 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN               BOOLEAN;  --戻り値
        nRTN               NUMBER;
        eEXCEPTION         EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        -- 条件取得
        bRTN := FUNC_JYOKEN_GET();
        IF NOT bRTN THEN
            RAISE eEXCEPTION;
        END IF;
        -- 初期処理
        bRTN := FUNC_INIT();
        IF NOT bRTN THEN
            RAISE eEXCEPTION;
        END IF;
        --帳票出力CSVの作成
        -- 帳票IDが「就学校変更者一覧」 の場合
        IF g_rJSTP.Chohyoid = 'GKB675R001' THEN
            --ワークテーブル削除
            -- 就学校変更対象者一覧ワーク
            DELETE FROM GKBWL675R001
            WHERE WSNUM = g_sWSNUM
            AND BATCHKBN = 2;
            -- 就学校変更対象者一覧中間ワーク
            DELETE FROM GKBWSHUGAKHENKOTAISHO;
            -- ＣＳＶファイル作成処理を呼び出す
            nRTN := FUNC_CSV_CREATE();
            IF nRTN <> 0 THEN
                RAISE eEXCEPTION;
            END IF;
            --CSV出力処理
            bRTN := FUNC_B11CSV('GKBWL675R001');
            IF NOT bRTN THEN
                RAISE eEXCEPTION;
            END IF;
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
    --  作成者／作成日: ZCZL.BYN 2024/07/01
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
    --  作成者／作成日: ZCZL.BYN 2024/07/01
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
        --ログ出力
--  2024/08/30 ZCZL.xiaoya DELETE 0.3.000.001:8月1日認識合わせの横展開
--        bRTN := FUNC_SETLOG ('処理は正常に終了しました', 0, '', '', '', g_sTANTOCODE, g_sWSNUM, 1);
        COMMIT;

    EXCEPTION
        WHEN ePRMEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
--  2024/08/30 ZCZL.xiaoya DELETE 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG ('異常終了しました'|| o_nRESULT , 1, '', '', '', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
        WHEN eSHORIEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
--  2024/08/30 ZCZL.xiaoya DELETE 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG ('異常終了しました'|| o_nRESULT , 1, '', '', '', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
        WHEN OTHERS THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
--  2024/08/30 ZCZL.xiaoya DELETE 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG ('異常終了しました'|| o_nRESULT , 1, '', '', '', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;

    END PBATCH;
END GKBPB00540;
/
