CREATE OR REPLACE PACKAGE BODY ZLBPC10200
--1.0.200.000
--------------------------------------------------------
--  サブシステム名: ZLB(国保税)
--  プログラム名  : 本算定課税計算
--  機能概要      : 該当年度の本算定課税計算を行う
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
--------------------------------------------------------
--  変更履歴
--  2024/02/19 ZCZL.GUORUIHUA Update 0.2.000.001:TV会議対応
--  2025/12/17 JIP.SUZUKI UPDATE 1.1.200.000:子ども子育て支援金対応_既存バグ対応No56 テスト処理連続実行異常終了の修正
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

    --パラメータ変数
    g_vJOKEN1                     NVARCHAR2(1000);
    g_vJOKEN2                     NVARCHAR2(1000);
    g_vJOKEN3                     NVARCHAR2(1000);
    g_vJOKEN4                     NVARCHAR2(1000);
    g_nTIME                       NUMBER;
    g_oKENSU_LIST                 ZLBEKENSU_LIST := ZLBEKENSU_LIST();
    g_nINDEX                      NUMBER         := 0;
    -- 戻り値
    c_NRTN_0          NUMBER(2)   := 0;        -- 正常
    c_NRTN_9          NUMBER(2)   := 9;        -- 異常
    c_NRTN_1          NUMBER(2)   := 1;        -- 排他エラー
    c_NRTN_8          NUMBER(2)   := 8;        -- パラメータエラー

    c_NNOKI_HON       NUMBER(2)   := 2;        -- 納期区分 (2:本算定

    c_NMODE_1         NUMBER(2)   := 1;        -- 課税計算開始
    c_NMODE_2         NUMBER(2)   := 2;        -- 課税計算正常終了
    c_NMODE_3         NUMBER(2)   := 3;        -- 課税計算異常終了

    -- 実行区分
    c_NBATCH        CONSTANT NUMBER(1) := 0;        -- バッチから起動

    -- 算定団体コード
    c_SANTEIDANTAI_CD NUMBER(2)   := 1;        -- システム条件固定読込値

-- =========================================================================
-- ローカル変数
-- =========================================================================

    IlRTN            PLS_INTEGER;      -- 戻り値
    BlRTN            BOOLEAN;          -- 戻り値

    IlRTN2           PLS_INTEGER;      -- 戻り値
    o_RTN            PLS_INTEGER;      -- 戻り値

    NlCNT            NUMBER(1);        -- カウント用

    VlERRBUF         NVARCHAR2(100);   -- エラー

    NlSHIME_NENGETSU NUMBER(8);        -- 〆年月

    NlCHOTEI_NENDO   NUMBER(4);        -- 調定年度
    NlKIJUN_NENGAPPI NUMBER(8);        -- 基準日

    NlMODE           NUMBER(1);        -- 処理範囲更新モード

    BlHAITA          BOOLEAN;          -- 排他セット


    BlSHORI_HANI_FLG BOOLEAN;        -- 処理範囲中判断フラグ

    -- KKAPK0020.FDAYEDIT2呼び出し用変数
    IWAREKIHIZUKE  PLS_INTEGER;
    ISEIREKIHIZUKE PLS_INTEGER;
    VEDIT_GYYMMDD1 NVARCHAR2(15);
    VEDIT_GYYMMDD2 NVARCHAR2(15);
    VEDIT_GYYMMDD3 NVARCHAR2(15);
    VKJ_GENGO      NVARCHAR2(15);
    VKG_GENGO      NVARCHAR2(15);
    IWAREKI_YY     PLS_INTEGER;
    ISEIREKI_YYYY  PLS_INTEGER;
    IWAREKI_GYYMM  PLS_INTEGER;
    IMM            PLS_INTEGER;
    IDD            PLS_INTEGER;
    TEST_MODE      PLS_INTEGER := 0;
    BRTN           BOOLEAN;               --復帰値

-- =========================================================================
-- パラメータ変数
-- =========================================================================

    NlNTRENBAN        NUMBER(15);
    NlKOJIN_NO        CHAR(12);
    VlMASIN_NO        NVARCHAR2(63);
    NlTIME            NUMBER(6);
    VMSG              NVARCHAR2(2000);
-- =========================================================================
-- カーソル定義
-- =========================================================================
    CURSOR CKANWA IS
      SELECT * FROM  ZLBTKANWA_TAISHO_TMP
       WHERE SYS_TANMATSU_NO = VlMASIN_NO;
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
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
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
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
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
        g_nTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));
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
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        vShoriKubun            DBMS_UTILITY.MAXNAME_ARRAY;

    BEGIN
        g_vJOKEN1 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtChoteiNendo');
        g_vJOKEN2 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKijunHi');
        vShoriKubun := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbShoriKubun');
        g_vJOKEN3 := vShoriKubun(1);
        g_vJOKEN4 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKazeiTaishoRisutoSakuseiUmu');
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
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
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
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                        BOOLEAN;  --戻り値
        VMSG                        NVARCHAR2(2000);
        VERRMSG                     NVARCHAR2(1000);
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
        VMSG := '';
        --調定年度
        VERRMSG := KKBPK5551.FJOKENDATECHK ('ZLB',g_sSHORIID, 0,  1, 1, g_vJOKEN1);
        IF VERRMSG IS NOT NULL THEN
          VMSG := VERRMSG;
        END IF;
        --基準日
        VERRMSG := KKBPK5551.FJOKENDATECHK ('ZLB',g_sSHORIID, 0,  2, 1, g_vJOKEN2);
        IF VERRMSG IS NOT NULL THEN
          VMSG := VMSG || VERRMSG;
        END IF;

        o_vRESULT := VMSG;

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
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
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
    --  作成者/作成日  ZCZL.ZHANGLEI 2023/08/07
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
    --  機能概要      : 03 各月資格区分変更
    --  パラメータ    :  i_NKOKU_SETAI_NO
    --                i_NKOJIN_NO
    --                o_VlERRBUF
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 9
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
    --------------------------------------------------------
    FUNCTION KOJIN_CHENGEKBN(
                             i_NKOKU_SETAI_NO      IN  NUMBER,
                             i_NKOJIN_NO           IN  NUMBER,
                             o_VlERRBUF OUT NVARCHAR2
                             ) RETURN NUMBER IS

        IwRTN            PLS_INTEGER;          -- 戻り値
        NlRTN            NUMBER;             -- 処理結果

        -- カーソル宣言
        /*******************************************************
         中間個人TBL READ
                    国保世帯番号           ＝ P:国保世帯番号
                    個人番号               ＝ P:個人番号
                    端末番号               ＝ P:端末番号
         *******************************************************/
        CURSOR CKOJIN IS

            SELECT * FROM  ZLBTKOJIN_MID
             WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
              AND  KOJIN_NO      = i_NKOJIN_NO
              AND  SYS_TANMATSU_NO = VlMASIN_NO;

            CRKOJIN      CKOJIN%ROWTYPE;  -- 中間個人rec

      BEGIN
        IwRTN  := 0;
        NlCNT  := 0;

        FOR CRKOJIN IN  CKOJIN LOOP

            ZLBSKCALCGKBN(CRKOJIN.CHOTEI_NENDO,   -- 調定年度
                             CRKOJIN.NENDO_BUN,      -- 年度分
                             CRKOJIN.KOKU_SETAI_NO,  -- 国保世帯番号
                             CRKOJIN.KOJIN_NO,       -- 個人番号
                             CRKOJIN.TSUCHI_NO,      -- 通知書番号
                             c_NBATCH,               -- 実行区分(バッチ)
                             VlMASIN_NO,             -- 端末番号
                             NlNTRENBAN,             -- 登録連番
                             NlRTN);                 -- 戻り値(0:OK 1:Error)
            IF NlRTN != c_NRTN_0 THEN
                bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'KOJIN_CHENGEKBN', 1, '', '',' ZLBPC10200 ZLBSKCALCGKBN 各月資格区分変更 異常 宛名番号= '|| CRKOJIN.KOJIN_NO , g_sTANTOCODE, g_sWSNUM, 1);
                IwRTN := c_NRTN_9;
                RETURN( IwRTN );
            END IF;

        END LOOP ;

        RETURN( IwRTN );

      EXCEPTION
        WHEN OTHERS THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := SQLCODE||SQLERRM;

        RETURN( IwRTN );

    END KOJIN_CHENGEKBN ;
    --------------------------------------------------------
    --  機能概要      : 02 対象年月のマスタ更新実施確認
    --  パラメータ    :  o_VlERRBUF
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 9
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
    --------------------------------------------------------
    FUNCTION FNC_SHORI_HANI(  o_VlERRBUF       OUT NVARCHAR2
                     ) RETURN NUMBER IS

        IwRTN        PLS_INTEGER;      -- 戻り値
        IwCOUNT      PLS_INTEGER;      -- SELECT検索カウント

      BEGIN
        IwRTN  := 0;
        BlSHORI_HANI_FLG := FALSE;

        BEGIN
          -- 処理範囲TBLより件数取得
          SELECT  COUNT(*) COUNT INTO IwCOUNT
          FROM    ZLBTSHORI_HANI
          WHERE   CHOTEI_NENDO         =  NlCHOTEI_NENDO     AND
                  NENDO_BUN            =  NlCHOTEI_NENDO     AND
                  SHIME_NENGETSU       =  NlSHIME_NENGETSU   AND
                  MASTER_KOSHIN_KBN    =  2
          ;
          -- 複数件存在すればERR → 処理済
          IF   IwCOUNT  >  0 THEN
            BlSHORI_HANI_FLG := TRUE;
          END IF;

        EXCEPTION
          WHEN OTHERS THEN
            IwRTN          := c_NRTN_9;
            o_VlERRBUF     := SQLCODE||SQLERRM;
        END;
        RETURN( IwRTN );

    END FNC_SHORI_HANI ;

    --------------------------------------------------------
    --  機能概要      : 01 システム条件読み込み
    --  パラメータ    : i_NENDO
    --               o_VlERRBUF
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 9
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
    --------------------------------------------------------
    FUNCTION JYOKEN_READ(
                         i_NENDO   IN  NUMBER,
                         o_VlERRBUF OUT NVARCHAR2
                        ) RETURN NUMBER IS

        IwRTN            PLS_INTEGER;          -- 戻り値

        -- カーソル宣言
        /*******************************************************
         システム条件 READ
                    年度                   ＝ P:年度
                    算定団体コード         ＝ 1(固定)
         *******************************************************/
        CURSOR CZLBTJOKEN IS
          SELECT   NOKI_1
                  ,NOKI_2
                  ,NOKI_3
                  ,NOKI_4
                  ,NOKI_5
                  ,NOKI_6
                  ,NOKI_7
                  ,NOKI_8
                  ,NOKI_9
                  ,NOKI_10
                  ,NOKI_11
                  ,NOKI_12
                  ,NOKI_13
          FROM     ZLBTJOKEN
          WHERE    NENDO           =  i_NENDO
          AND      SANTEIDANTAI_CD = c_SANTEIDANTAI_CD
          ;

        RZLBTJOKEN      CZLBTJOKEN%ROWTYPE;  -- システム条件rec

      BEGIN
        IwRTN  := 0;
        NlCNT  := 0;

        FOR RZLBTJOKEN IN CZLBTJOKEN LOOP

          NlCNT  := NlCNT + 1;

          -- 〆年月算出
          IF RZLBTJOKEN.NOKI_1 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO) || '04') ;
          ELSIF RZLBTJOKEN.NOKI_2 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO) || '05') ;
          ELSIF RZLBTJOKEN.NOKI_3 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO) || '06') ;
          ELSIF RZLBTJOKEN.NOKI_4 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO) || '07') ;
          ELSIF RZLBTJOKEN.NOKI_5 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO) || '08') ;
          ELSIF RZLBTJOKEN.NOKI_6 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO) || '09') ;
          ELSIF RZLBTJOKEN.NOKI_7 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO) || '10') ;
          ELSIF RZLBTJOKEN.NOKI_8 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO) || '11') ;
          ELSIF RZLBTJOKEN.NOKI_9 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO) || '12') ;
          ELSIF RZLBTJOKEN.NOKI_10 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO + 1) || '01') ;
          ELSIF RZLBTJOKEN.NOKI_11 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO + 1) || '02') ;
          ELSIF RZLBTJOKEN.NOKI_12 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO + 1) || '03') ;
          ELSIF RZLBTJOKEN.NOKI_13 = c_NNOKI_HON THEN
            NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NENDO + 1) || '04') ;

          ELSE
            -- 算定月取得失敗
            IwRTN     := c_NRTN_9;
            o_VlERRBUF  := '算定月の取得エラー';
          END IF;

        END LOOP ;

        IF NlCNT = 0 THEN
          IwRTN       := c_NRTN_9;
          o_VlERRBUF  := 'システム条件該当データ無し';
        END IF ;

        RETURN( IwRTN );

      EXCEPTION
        WHEN OTHERS THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := SQLCODE||SQLERRM;

        RETURN( IwRTN );

    END JYOKEN_READ ;

    --------------------------------------------------------
    --  機能概要      : 計算テストモード⇒確認対象からのみ計算
    --  パラメータ    : i_NENDO
    --               o_VlERRBUF
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 9
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
    --------------------------------------------------------
    FUNCTION FUNC_TESTCAL(i_NENDO   IN  NUMBER, o_VlERRBUF OUT NVARCHAR2
                        ) RETURN NUMBER IS

        IwRTN            PLS_INTEGER;          -- 戻り値
        NwCNT            NUMBER(1);            -- カウント

        -- カーソル
        CURSOR CJLT_KAKUNIN IS
          SELECT DISTINCT KOKU_SETAI_NO
          FROM   ZLBTKAKUNINTAISHO;

      BEGIN
        IwRTN := 0;
        NwCNT := 0;
          DELETE FROM ZLBTKEISAN_TAISHO
           WHERE SYS_TANMATSU_NO = g_sWSNUM;
--2025/12/17 JIP.SUZUKI ADD 1.1.200.000:子ども子育て支援金対応_既存バグ対応No56 テスト処理連続実行異常終了の修正
        KHSPK00100.STRUNCATE('ZLBWKAZEITAISHO');
        
        FOR RwCJLT_KAKUNIN IN CJLT_KAKUNIN LOOP

          BEGIN
            -- 計算対象存在チェック
            SELECT COUNT(*) INTO NwCNT FROM ZLBTKEISAN_TAISHO
              WHERE KOKU_SETAI_NO   = RwCJLT_KAKUNIN.KOKU_SETAI_NO
                AND SYS_TANMATSU_NO = g_sWSNUM;
          EXCEPTION
            WHEN OTHERS THEN
              IwRTN        := c_NRTN_9;
              o_VlERRBUF   := 'ZLBTKEISAN_TAISHO検索エラー'
                              ||' 国保世帯番号='|| RwCJLT_KAKUNIN.KOKU_SETAI_NO;
            EXIT;
          END;

          IF NwCNT = 0 THEN
            BEGIN
              -- 計算対象テーブルにINSERT
              INSERT INTO ZLBTKEISAN_TAISHO VALUES (
                RwCJLT_KAKUNIN.KOKU_SETAI_NO,   -- 国保世帯番号
                i_NENDO,                        -- 年度
                i_NENDO,                        -- 年度分
                g_sWSNUM                     -- 端末番号
              );
            EXCEPTION
              WHEN OTHERS THEN
                IwRTN        := c_NRTN_9;
                o_VlERRBUF   := 'ZLBTKEISAN_TAISHO登録エラー'
                                ||' 国保世帯番号='|| RwCJLT_KAKUNIN.KOKU_SETAI_NO;
              EXIT;
            END;
          END IF;
        END LOOP;

        RETURN( IwRTN );

      EXCEPTION
        WHEN OTHERS THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := SQLCODE||SQLERRM;
        RETURN( IwRTN );
    END FUNC_TESTCAL;
    --------------------------------------------------------
    --  機能概要      : 01 計算時点バックアップ
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 9
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
    --------------------------------------------------------
    FUNCTION FUNC_BACKUP RETURN NUMBER IS
        NlRTN        NUMBER := 0;
        TYPE MTCHAR  IS TABLE OF NVARCHAR2(100);
        --ZEBTFKAZEIKIHONは後続PRJ「ZEB固定資産税」のテーブル
        VTABLE_NAME  MTCHAR := MTCHAR('ZLBTSHIKAKU_TMP','ZLBTTEKIJOGAI_TMP','ZLBTKEIGEN_TMP'
                                     ,'ZLBTSETAI_TMP','ZLBTNUSHI_TMP','ZLBTEXTKJN_TMP','ZLBTKANWA_TAISHO_TMP'
                                     ,'ZEBTFKAZEIKIHON','ZABTKAZEI','ZABTTABUMON','ZABTFUYO','GABTATENAKIHON'
                                     ,'ZLBTKANWA_TS_EX_TMP');

        VBACKUP_NAME NVARCHAR2(100);
        VSQL         NVARCHAR2(1024);
        BTABLE       BOOLEAN;
        CURSOR CTABLE(p_TABLE_NAME IN NVARCHAR2) IS
          SELECT TABLE_NAME
            FROM USER_TABLES
           WHERE TABLE_NAME = p_TABLE_NAME;
      BEGIN
        BEGIN
          FOR IDX IN VTABLE_NAME.FIRST..VTABLE_NAME.LAST LOOP
            --バックアップテーブル名作成（テーブル名＿西暦年度）
            VBACKUP_NAME := VTABLE_NAME(IDX) || '_' || NlCHOTEI_NENDO;
            --バックアップテーブル存在チェック
            BTABLE := FALSE;
            FOR CREC IN CTABLE(VBACKUP_NAME) LOOP
              BTABLE := TRUE;
              EXIT;
            END LOOP;
            --バックアップ実行
            IF BTABLE THEN
              --テーブルが存在
              VSQL := 'TRUNCATE TABLE ' || VBACKUP_NAME;
              EXECUTE IMMEDIATE TO_CHAR(VSQL);  --データ削除
              VSQL := 'INSERT INTO ' || VBACKUP_NAME || ' SELECT * FROM ' || VTABLE_NAME(IDX);
            ELSE
              --テーブルが存在しない
              VSQL := 'CREATE TABLE ' || VBACKUP_NAME || ' TABLESPACE ZL_DATA AS SELECT * FROM ' || VTABLE_NAME(IDX);
            END IF;
            --ZEBTFKAZEIKIHONは後続PRJ「ZEB固定資産税」のテーブル
            IF VTABLE_NAME(IDX) IN ('ZEBTFKAZEIKIHON','ZABTKAZEI','ZABTTABUMON','ZABTFUYO') THEN
                VSQL := VSQL || ' WHERE NENDOBUN = ' || NlCHOTEI_NENDO;
            END IF;
              EXECUTE IMMEDIATE TO_CHAR(VSQL);  --データ追加・作成
          END LOOP;
        EXCEPTION
          WHEN OTHERS THEN
            NlRTN := c_NRTN_9;
            VlERRBUF := 'FUNC_BACKUP 例外エラー ' || SQLERRM;
        END;
        RETURN(NlRTN);
    END FUNC_BACKUP;
    -------------------------------------------------------------
    --  機能概要:   件数表で対応メッセージが含めか
    --  パラメータ:   i_vKENSUU_NAIYOU
    --  モジュール区分: 内部関数
    --  戻り値        : 含める TRUE,　含めいない FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/7
    -------------------------------------------------------------
    FUNCTION FUNC_CHECK_KENSUU(i_vKENSUU_NAIYOU VARCHAR2,i_nCNT NUMBER) RETURN BOOLEAN
    IS

    BEGIN
        IF g_oKENSU_LIST IS NULL OR g_oKENSU_LIST.COUNT()=0 THEN
          RETURN FALSE;
        END IF;
        FOR i IN 1..g_oKENSU_LIST.COUNT() LOOP
          --同じタイトルを含めて、一つを設定する
          IF g_oKENSU_LIST(i).NAIYOU = i_vKENSUU_NAIYOU AND g_oKENSU_LIST(i).CNT = 0 THEN
            g_oKENSU_LIST(i).CNT := i_nCNT;
            RETURN TRUE;
          END IF;
        END LOOP;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END FUNC_CHECK_KENSUU;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        sDATE            NVARCHAR2(20);
        eEXCEPTION       EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        -- 初期処理
        IlRTN       := 0 ;

        BlHAITA     := FALSE ;          -- 排他セット

        -- パラメータ→変数
        NlNTRENBAN        :=  g_nJOBNUM;
        NlKOJIN_NO        :=  g_sTANTOCODE;
        VlMASIN_NO        :=  g_sWSNUM;
        NlTIME            :=  g_nTIME;


        IF IlRTN   = c_NRTN_0 THEN

          -- 調定年度
          NlCHOTEI_NENDO   := KKAPK0020.FNENDO(TO_NUMBER(g_vJOKEN1), 1);

          -- 基準日
          IWAREKIHIZUKE  := TO_NUMBER(SUBSTR(g_vJOKEN2,1,7));
          ISEIREKIHIZUKE := 0;
          IlRTN          := KKAPK0020.FDAYEDIT2(IWAREKIHIZUKE,  ISEIREKIHIZUKE, VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                                 VEDIT_GYYMMDD3, VKJ_GENGO,      VKG_GENGO,      IWAREKI_YY,
                                                 ISEIREKI_YYYY,  IWAREKI_GYYMM,  IMM,            IDD,
                                                 IWAREKIHIZUKE,  ISEIREKIHIZUKE);
          NlKIJUN_NENGAPPI := ISEIREKIHIZUKE;

          -- テストモード追加/**条件3に1を入れると確認対象のみから計算します**/
          TEST_MODE := NVL(g_vJOKEN3,0);
          /****************************************/
          /* システム条件読込                     */
          /****************************************/

          IlRTN := JYOKEN_READ( NlCHOTEI_NENDO,           -- IN(調定年度
                               VlERRBUF                  -- OUT(エラー
                             );

          -- 戻り値判定
          IF IlRTN != c_NRTN_0 THEN
            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 JYOKEN_READ システム条件読込失敗 ' ||VlERRBUF, g_sTANTOCODE, g_sWSNUM, 1);
          ELSE
            -- ログ出力
            --  2024/02/19 ZCZL.GUORUIHUA Update 0.2.000.001:TV会議対応
            --bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 JYOKEN_READ システム条件読込 正常 ', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 JYOKEN_READ システム条件読込 正常 ', g_sTANTOCODE, g_sWSNUM, 1);
          END IF;

        END IF;
        IF IlRTN   = c_NRTN_0 THEN

          /****************************************/
          /* 処理範囲更新 ZLBFCCALSRUPD      */
          /****************************************/

          IlRTN := ZLBFCCALSRUPD( c_NMODE_1,       -- IN(モード 1:課税計算開始
                                      NlCHOTEI_NENDO,   -- IN(調定年度
                                      NlSHIME_NENGETSU, -- IN(〆年月
                                      0,                -- IN(から日付
                                      0,                -- IN(まで日付
                                      NlKIJUN_NENGAPPI, -- IN(基準日
                                      NlNTRENBAN        -- IN(登録連番
                                    );

          -- 戻り値判定
          CASE IlRTN
            -- 正常
            WHEN c_NRTN_0    THEN
              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBFCCALSRUPD 処理範囲更新 正常' , g_sTANTOCODE, g_sWSNUM, 1);
            -- 処理済
            WHEN c_NRTN_1    THEN
              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBFCCALSRUPD 処理範囲更新 処理済' , g_sTANTOCODE, g_sWSNUM, 1);
            -- 異常
            WHEN c_NRTN_9      THEN
              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBFCCALSRUPD 処理範囲更新 異常' , g_sTANTOCODE, g_sWSNUM, 1);
          END CASE;

        END IF;

        IF IlRTN   = c_NRTN_0 THEN

          -- 処理範囲テーブル検索
          IlRTN := FNC_SHORI_HANI( VlERRBUF ) ;

          IF IlRTN   = c_NRTN_0 THEN
            -- 処理中でなければ
            IF BlSHORI_HANI_FLG = FALSE THEN

              /****************************************/
              /* 排他制御クリア ZLBFKHAITACLR          */
              /****************************************/
              IlRTN := ZLBFKHAITACLR( 0,               -- IN(国保世帯番号
                                    VlMASIN_NO,       -- IN(端末番号
                                    NlKOJIN_NO        -- IN(職員個人番号
                                  );

              -- 戻り値判定
              CASE IlRTN
                WHEN c_NRTN_0      THEN

                  -- ログ出力
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBFKHAITACLR 排他制御クリア 正常' , g_sTANTOCODE, g_sWSNUM, 1);
                -- パラメータエラー
                WHEN c_NRTN_8      THEN
                  -- ログ出力
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBFKHAITACLR 排他制御クリア パラメータエラー' , g_sTANTOCODE, g_sWSNUM, 1);
                -- 異常
                WHEN c_NRTN_9      THEN
                  -- ログ出力
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBFKHAITACLR 排他制御クリア 異常' , g_sTANTOCODE, g_sWSNUM, 1);

              END CASE;

            END IF;

          ELSE

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 FNC_SHORI_HANI 処理範囲テーブル検索 異常 '||VlERRBUF , g_sTANTOCODE, g_sWSNUM, 1);
          END IF;

        END IF;

        IF IlRTN   = c_NRTN_0 THEN

          /****************************************/
          /* 排他制御セット ZLBFKHAITASET          */
          /****************************************/

          IlRTN := ZLBFKHAITASET( 0,               -- IN(国保世帯番号
                                NlCHOTEI_NENDO,   -- IN(調定年度
                                NlCHOTEI_NENDO,   -- IN(年度分
                                VlMASIN_NO,       -- IN(端末番号
                                NlKOJIN_NO,       -- IN(職員個人番号
                                2                -- IN(照会更新区分 2;バッチ
                              );

          -- 戻り値判定
          CASE IlRTN
            WHEN c_NRTN_0      THEN

              BlHAITA     := TRUE ;          -- 排他セット

              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBFKHAITASET 排他制御セット 正常',  g_sTANTOCODE, g_sWSNUM, 1);
            -- 排他エラー
            WHEN c_NRTN_1      THEN
              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBFKHAITASET 排他制御セット 排他エラー',  g_sTANTOCODE, g_sWSNUM, 1);
            -- パラメータエラー
            WHEN c_NRTN_8      THEN
              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBFKHAITASET 排他制御セット パラメータエラー',  g_sTANTOCODE, g_sWSNUM, 1);
            -- 異常
            WHEN c_NRTN_9      THEN
              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBFKHAITASET 排他制御セット 異常', g_sTANTOCODE, g_sWSNUM, 1);
          END CASE;

        END IF;
        /****************************************/
        /* 本算定時１/２判定結果ワークを消す
        /****************************************/
        BEGIN
          DELETE FROM ZLBWHALFHANTEI
           WHERE CHOTEINENDO = NlCHOTEI_NENDO
             AND NENDOBUN = NlCHOTEI_NENDO;
        EXCEPTION
          WHEN OTHERS THEN
            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, ' ZLBPC10200 ZLBWHALFHANTEI １／２判定削除エラー', g_sTANTOCODE, g_sWSNUM, 1);
        END;

        IF IlRTN   = c_NRTN_0 THEN

          /****************************************/
          /* 計算対象抽出 ZLBSCMKCALTSY       */
          /****************************************/
          IF TEST_MODE <> 0 THEN
              IlRTN := FUNC_TESTCAL( NlCHOTEI_NENDO,           -- IN(調定年度
                                     VlERRBUF                  -- OUT(エラー
                                   );
          ELSE
              ZLBSCMKCALTSY( NlSHIME_NENGETSU,       -- IN(〆年月
                                 NlCHOTEI_NENDO,         -- IN(年度
                                 0,                      -- IN(現年過年区分 0：現年
                                 0,                      -- IN(から日付
                                 0,                      -- IN(まで日付0
                                 NlKIJUN_NENGAPPI,       -- IN(基準日
                                 g_sWSNUM,             -- IN(端末番号
                                 NlNTRENBAN,             -- IN(登録連番
                                 0,                      -- IN(処理区分
                                 0,                      -- IN(算定団体コード-未使用-
                                 IlRTN                   -- OUT(戻り値
                                 ,SUBSTR(g_vJOKEN4,3,1)  --処理区分コード_保留
                               );
              g_nINDEX := g_oKENSU_LIST.COUNT();
              IF NOT FUNC_CHECK_KENSUU('入力　計算対象テーブル件数', ZLBFKTBLCNT('ZLBTKEISAN_TAISHO','SYS_TANMATSU_NO = '''||g_sWSNUM||'''')) THEN
                g_nINDEX := g_nINDEX + 1;
                g_oKENSU_LIST.EXTEND(1);
                g_oKENSU_LIST(g_nINDEX) := ZLBEKENSU_RECORD(ZLBFKTBLCNT('ZLBTKEISAN_TAISHO','SYS_TANMATSU_NO = '''||g_sWSNUM||''''), '入力　計算対象テーブル件数', 1);
              END IF;

          END IF;
          -- 戻り値判定
          IF IlRTN = c_NRTN_0 THEN

            -- ログ出力
             bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBSCMKCALTSY 計算対象抽出 正常',  g_sTANTOCODE, g_sWSNUM, 1);
          ELSE

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBSCMKCALTSY 計算対象抽出 異常',  g_sTANTOCODE, g_sWSNUM, 1);
          END IF;

        END IF;


        IF IlRTN   = c_NRTN_0 THEN

          /****************************************/
          /* テンポラリTBL作成 ZLBSKMAKETMP        */
          /****************************************/

          ZLBSKMAKETMP( NlSHIME_NENGETSU,       -- IN(〆年月
                             NlCHOTEI_NENDO,         -- IN(年度
                             0,                      -- IN(現年過年区分 0：現年
                             0,                      -- IN(から日付
                             0,                      -- IN(まで日付0
                             NlKIJUN_NENGAPPI,       -- IN(基準日
                             c_NBATCH,               -- IN(実行区分 0:ﾊﾞｯﾁ
                             g_sWSNUM,             -- IN(端末番号
                             NlNTRENBAN,             -- IN(登録連番
                             IlRTN                   -- OUT(戻り値
                           );
          -- 戻り値判定
          IF IlRTN = c_NRTN_0 THEN

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBSKMAKETMP テンポラリTBL作成 正常',  g_sTANTOCODE, g_sWSNUM, 1);
          ELSE

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBSKMAKETMP テンポラリTBL作成 異常',  g_sTANTOCODE, g_sWSNUM, 1);
          END IF;

        END IF;


        IF IlRTN   = c_NRTN_0 THEN

          /****************************************/
          /* 計算時点バックアップ                 */
          /****************************************/
          IlRTN := FUNC_BACKUP;

          IF IlRTN = c_NRTN_0 THEN
            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 FUNC_BACKUP 計算時点バックアップ 正常',  g_sTANTOCODE, g_sWSNUM, 1);
          ELSE
            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 FUNC_BACKUP 計算時点バックアップ 異常',  g_sTANTOCODE, g_sWSNUM, 1);
          END IF;

        END IF;

        IF IlRTN   = c_NRTN_0 THEN

          /****************************************/
          /* 課税計算 ZLBSKCALPACK                 */
          /****************************************/

          ZLBSKCALPACK( NlCHOTEI_NENDO,        -- IN(調定年度

                       NlCHOTEI_NENDO,        -- IN(年度分
                       NlKOJIN_NO,            -- IN(更新職員番号
                       NlKIJUN_NENGAPPI,      -- IN(基準日
                       2,                     -- IN(納期区分 2:本算定
                       c_NBATCH,              -- IN(実行区分 0:ﾊﾞｯﾁ
                       VlMASIN_NO,            -- IN(端末番号
                       NlNTRENBAN,            -- IN(登録連番
                       IlRTN                  -- OUT(戻り値
                     );

          -- 戻り値判定
          IF IlRTN = c_NRTN_0 THEN

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBSKCALPACK 課税計算 正常',  g_sTANTOCODE, g_sWSNUM, 1);
          ELSE

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBSKCALPACK 課税計算 異常',  g_sTANTOCODE, g_sWSNUM, 1);
          END IF;

        END IF;

        IF IlRTN   = c_NRTN_0 THEN

          /****************************************/
          /* 賦課期日時点課税計算 ZLBSCH4CALPACK   */
          /****************************************/
          ZLBSCH4CALPACK( NlCHOTEI_NENDO,        -- IN(調定年度
                       NlCHOTEI_NENDO,        -- IN(年度分
                       NlKOJIN_NO,            -- IN(更新職員番号
                       NlKIJUN_NENGAPPI,      -- IN(基準日
                       VlMASIN_NO,            -- IN(端末番号
                       NlNTRENBAN,            -- IN(登録連番
                       IlRTN                  -- OUT(戻り値
                     );

          -- 戻り値判定
          IF IlRTN = c_NRTN_0 THEN

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBSCH4CALPACK 賦課期日時点課税計算 正常',  g_sTANTOCODE, g_sWSNUM, 1);
          ELSE

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBSCH4CALPACK 賦課期日時点課税計算 異常',  g_sTANTOCODE, g_sWSNUM, 1);
          END IF;

        END IF;

        IF IlRTN   = c_NRTN_0 THEN

          /****************************************/
          /* 基準日時点課税計算 ZLBSCHHCALPACK     */
          /****************************************/
          ZLBSCHHCALPACK( NlCHOTEI_NENDO,        -- IN(調定年度
                       NlCHOTEI_NENDO,        -- IN(年度分
                       NlKOJIN_NO,            -- IN(更新職員番号
                       NlKIJUN_NENGAPPI,      -- IN(基準日
                       VlMASIN_NO,            -- IN(端末番号
                       NlNTRENBAN,            -- IN(登録連番
                       IlRTN                  -- OUT(戻り値
                     );

          -- 戻り値判定
          IF IlRTN = c_NRTN_0 THEN

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBSCHHCALPACK 基準日時点課税計算 正常',  g_sTANTOCODE, g_sWSNUM, 1);
          ELSE

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBSCHHCALPACK 基準日時点課税計算 異常',  g_sTANTOCODE, g_sWSNUM, 1);
          END IF;

        END IF;

        IF IlRTN   = c_NRTN_0 THEN
            FOR CRKANWA IN CKANWA LOOP
                -- 個人TBLの各月資格区分変更
                IlRTN := KOJIN_CHENGEKBN( CRKANWA.KOKU_SETAI_NO,    -- IN(調定年度
                                          CRKANWA.KOJIN_NO,         -- IN(個人番号
                                          VlERRBUF                  -- OUT(エラー
                                          );
                -- 戻り値判定
                IF IlRTN != c_NRTN_0 THEN
                   -- ログ出力
                   bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 KOJIN_CHENGEKBN 各月資格区分変更処理異常 ' ||VlERRBUF,  g_sTANTOCODE, g_sWSNUM, 1);
                END IF;
            END LOOP;
        END IF;

        -- 処理範囲更新モード設定
        IF IlRTN   = c_NRTN_0 THEN
          NlMODE  := c_NMODE_2;         -- 課税計算正常終了
        ELSE
          NlMODE  := c_NMODE_3;         -- 課税計算異常終了
        END IF;

        -- ！注：ココでの戻り値は、既にエラーになっている場合もある為、
        --       別変数(IlRTN2)へ返す。

        /****************************************/
        /* 処理範囲更新 ZLBFCCALSRUPD      */
        /****************************************/

        IlRTN2 := ZLBFCCALSRUPD( NlMODE,          -- IN(モード
                                      NlCHOTEI_NENDO,   -- IN(調定年度
                                      NlSHIME_NENGETSU, -- IN(〆年月
                                      0,                -- IN(から日付
                                      0,                -- IN(まで日付
                                      NlKIJUN_NENGAPPI, -- IN(基準日
                                      NlNTRENBAN        -- IN(登録連番
                                    );

        -- 戻り値判定
        CASE IlRTN2
          -- 処理済
          WHEN c_NRTN_0      THEN
            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBFCCALSRUPD 処理範囲更新 正常',  g_sTANTOCODE, g_sWSNUM, 1);

          -- 異常
          WHEN c_NRTN_9      THEN

            -- 異常時のみ変数返却
            IlRTN  := IlRTN2 ;

            -- ログ出力
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBFCCALSRUPD 処理範囲更新 異常',  g_sTANTOCODE, g_sWSNUM, 1);
        END CASE;
        IF IlRTN   = c_NRTN_0 THEN
          IF SUBSTR(g_vJOKEN4,1,1) = 1 OR SUBSTR(g_vJOKEN4,3,1) = 1 OR SUBSTR(g_vJOKEN4,5,1) = 1 THEN

             ZLBSBKZTSHLST(g_nJOBNUM,
                                 g_sTANTOCODE,
                                 g_sWSNUM,
                                 g_nTIME,
                                 0,
                                 0,
                                 NlKIJUN_NENGAPPI,
                                 SUBSTR(g_vJOKEN4,1,1),
                                 SUBSTR(g_vJOKEN4,5,1),
                                 o_RTN);

            -- 戻り値判定
            IF o_RTN = c_NRTN_0 THEN

              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBSBKZTSHLST 計算対象世帯一覧の一括作成処理 正常',  g_sTANTOCODE, g_sWSNUM, 1);
            ELSE

              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBSBKZTSHLST 計算対象世帯一覧の一括作成処理 異常',  g_sTANTOCODE, g_sWSNUM, 1);
            END IF;
            DELETE FROM ZLBWL102R001
                  WHERE  WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
            ZLBSBKZTSHLCSV(g_nJOBNUM,
                                   g_sTANTOCODE,
                                   g_sWSNUM,
                                   g_nTIME,
                                   o_RTN,
                                   c_BATCH,
                                   g_rJSTP.Chohyoid,
                                   g_rJSTP.Orderbyclause);

            -- 戻り値判定
            IF o_RTN = c_NRTN_0 THEN
              bRTN := FUNC_B11CSV('ZLBWL102R001');
              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBSBKZTSHLCSV 計算対象世帯一覧ＣＳＶ作成処理 正常',  g_sTANTOCODE, g_sWSNUM, 1);
            ELSE

              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBSBKZTSHLCSV 計算対象世帯一覧ＣＳＶ作成処理 異常',  g_sTANTOCODE, g_sWSNUM, 1);
            END IF;
          END IF;
        END IF;
        -- 異常終了時、排他がかかっていれば、クリアする
        IF BlHAITA THEN
          /****************************************/
          /* 排他制御クリア ZLBFKHAITACLR          */
          /****************************************/
          IlRTN2 := ZLBFKHAITACLR( 0,               -- IN(国保世帯番号
                                    VlMASIN_NO,       -- IN(端末番号
                                    NlKOJIN_NO        -- IN(職員個人番号
                                );

          -- 戻り値判定
          CASE IlRTN2
            WHEN c_NRTN_0      THEN
              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', ' ZLBPC10200 ZLBFKHAITACLR 排他制御クリア 正常',  g_sTANTOCODE, g_sWSNUM, 1);
            -- パラメータエラー
            WHEN c_NRTN_8      THEN
              -- 異常時のみ変数返却
              IlRTN  := IlRTN2 ;
              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBFKHAITACLR 排他制御クリア パラメータエラー',  g_sTANTOCODE, g_sWSNUM, 1);
            -- 異常
            WHEN c_NRTN_9      THEN
              -- 異常時のみ変数返却
              IlRTN  := IlRTN2 ;
              -- ログ出力
              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', ' ZLBPC10200 ZLBFKHAITACLR 排他制御クリア 異常',  g_sTANTOCODE, g_sWSNUM, 1);
          END CASE;

        END IF;
        g_nINDEX := g_oKENSU_LIST.COUNT();
        IF NOT FUNC_CHECK_KENSUU('出力　計算処理件数', ZLBFKTBLCNT('ZLBTKIHON_MID','SYS_TANMATSU_NO = '''||g_sWSNUM||'''')) THEN
          g_nINDEX := g_nINDEX + 1;
          g_oKENSU_LIST.EXTEND(1);
          g_oKENSU_LIST(g_nINDEX) := ZLBEKENSU_RECORD(ZLBFKTBLCNT('ZLBTKIHON_MID','SYS_TANMATSU_NO = '''||g_sWSNUM||''''),'出力　計算処理件数',2);
        END IF;

        -- 戻り値判定
        IF IlRTN <>0 THEN
          RAISE eEXCEPTION;
        END IF;
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);

        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            -- 異常終了時、排他がかかっていれば、クリアする
            IF BlHAITA = TRUE    THEN

              /****************************************/
              /* 排他制御クリア ZLBFKHAITACLR          */
              /****************************************/
              IlRTN2 := ZLBFKHAITACLR( 0,               -- IN(国保世帯番号
                                    VlMASIN_NO,       -- IN(端末番号
                                    NlKOJIN_NO        -- IN(職員個人番号
                                );

              -- 戻り値判定
              CASE IlRTN2
                WHEN c_NRTN_0      THEN
                  -- ログ出力
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, ' ZLBPC10200 ZLBFKHAITACLR(異常時) 排他制御クリア 正常',  g_sTANTOCODE, g_sWSNUM, 1);
                -- パラメータエラー
                WHEN c_NRTN_8      THEN
                  -- ログ出力
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, ' ZLBPC10200 ZLBFKHAITACLR(異常時) 排他制御クリア パラメータエラー',  g_sTANTOCODE, g_sWSNUM, 1);
                -- 異常
                WHEN c_NRTN_9      THEN
                  -- ログ出力
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, ' ZLBPC10200 ZLBFKHAITACLR(異常時) 排他制御クリア 異常',  g_sTANTOCODE, g_sWSNUM, 1);
              END CASE;

            END IF;
            RAISE;
    END FUNC_B10SAKUHYO1;
    --------------------------------------------------------
    --  機能概要      : 更新処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
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
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
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
    --  機能概要      : バッチ処理の呼出
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_nRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2023/08/07
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
END ZLBPC10200;
/
