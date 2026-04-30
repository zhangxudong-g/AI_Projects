CREATE OR REPLACE PACKAGE BODY GKBPB00230
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 学校区別人口統計表（未就学児童）
--  機能概要      : 学校区および年齢別（０歳から６歳）に人口及び世帯数の集計表を作成する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
--------------------------------------------------------
--  変更履歴
--  2024/06/04 ZCZL.WANGQIWEI Update 0.3.000.000:新WizLIFE２次開発の標準化対応
--  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.001:IT_GKB_00079仕様変更対応
--  2025/01/15 JPJYS.YANGXIHAN UPDATE 0.3.000.002:学区マスタ関連修正方針対応
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

    -- 変数宣言
    -- CSVファイル出力データ
    V_BUFFER            NVARCHAR2(4000);  -- CSV吐き出しバッファ
    N_SQL_CODE          NUMBER;           -- SQLエラーコード
    V_SQL_MSG           VARCHAR(255);     -- SQLエラーメッセージ
    -- 処理条件
    I_NENDO             NUMBER(7);        -- 年度
    V_NENDO             NVARCHAR2(16);    -- 年度
    V_KIJUNBI           NVARCHAR2(15);    -- 基準日
    V_SAKUSEIBI         NVARCHAR2(15);    -- 作成日
    V_SHUKEIKBN         NVARCHAR2(15);    -- 集計区分
    I_GAIKOKUJIN        PLS_INTEGER;      -- 外国人
    KIJUNBI             NUMBER(8);        -- 基準日 配列定義(変換前)
    V_BKIJUNBI          NVARCHAR2(11);    -- 基準日 配列定義(変換後)
    V_BSAKUSEIBI        NVARCHAR2(11);    -- 作成日 配列定義(変換後)

    TYPE T_AGE  IS TABLE OF PLS_INTEGER;     -- TABLE定義（1歳刻みカウント）
    TYPE T_VAGE IS TABLE OF NVARCHAR2(16);   -- TABLE定義（CSV出力用生年月日）

    B_IS_CHG_SHO        BOOLEAN;             -- 小学校が変わったかどうかのフラグ

    I_CUR               PLS_INTEGER;
    I_PRC               PLS_INTEGER;
    V_SQL               VARCHAR2(2000);

    V_SHUKEI_KBN          NVARCHAR2(25);
    V_SHUKEI_KBN_MEI      NVARCHAR2(25);
--  2024/06/04 ZCZL.WANGQIWEI Update 0.3.000.000:新WizLIFE２次開発の標準化対応
--    N_KOJIN_NO            NUMBER(12);
    N_KOJIN_NO            NUMBER(15);
    N_SHOGAKU_CD          NUMBER(5);
    N_SEINENGAPI          NUMBER(8);
    V_USER_MEI            NVARCHAR2(40);
    N_GYOSEIKU_CD         NUMBER(4);
    V_GYOSEIKU_MEI        NVARCHAR2(40);
    N_SECTION_CD          NUMBER(5);
    V_SECTION_MEI         NVARCHAR2(40);
    N_SEIBETSU            NUMBER(1);
    N_JINKAKU_KBN         NUMBER(1);
    N_SANTEIDANTAI_CD     PLS_INTEGER;
    N_AGE                 NUMBER(1) := 0; -- 年齢

    -- 退避用
    N_SHOGAKU_CD_OLD      NUMBER(5);
    N_GYOSEIKU_CD_OLD     NUMBER(4);
    N_SECTION_CD_OLD      NUMBER(5);
    V_USER_MEI_OLD        NVARCHAR2(40);
    V_GYOSEIKU_MEI_OLD    NVARCHAR2(40);
    V_SECTION_MEI_OLD     NVARCHAR2(40);
    N_SANTEIDANTAI_CD_OLD PLS_INTEGER;
    -- 集計用
    I_BIRTH_B           T_AGE     := T_AGE();   -- TABLE変数（生年月日開始）
    I_BIRTH_E           T_AGE     := T_AGE();   -- TABLE変数（生年月日終了）
    V_BIRTH_B           T_VAGE    := T_VAGE();  -- CSV出力用生年月日開始
    V_BIRTH_E           T_VAGE    := T_VAGE();  -- CSV出力用生年月日終了
    I_MEN_1             T_AGE     := T_AGE();   -- TABLE変数（1歳刻み男性）
    I_WOMEN_1           T_AGE     := T_AGE();   -- TABLE変数（1歳刻み女性）
    N_RECORD            NUMBER(8) :=0;          -- 処理レコード数
    N_SUM_R             NUMBER(8) :=0;          -- 総合計(処理レコード数)
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
    g_nCSVKENSAKU       NUMBER    := 0;         --CSV件数
    -- 合併フラグ
    GAPPEI_FLG          BOOLEAN := TRUE;

    -- 関数用変数
    B_RTN         BOOLEAN;
    N_RTN         NUMBER;

    V_JYOUKEN1    NVARCHAR2(1000);
    V_JYOUKEN2    NVARCHAR2(1000);
    V_JYOUKEN3    NVARCHAR2(1000);
    V_JYOUKEN4    NVARCHAR2(1000);
    V_JYOUKEN5    NVARCHAR2(1000);

    VMSG NVARCHAR2(4000);
    IRTN PLS_INTEGER;
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

    io_IWAREKIHIZUKE         PLS_INTEGER := NULL;
    io_ISEIREKIHIZUKE        PLS_INTEGER := NULL;
    o_VEDIT_GYYMMDD1         NVARCHAR2(16);
    o_VEDIT_GYYMMDD2         NVARCHAR2(16);
    o_VEDIT_GYYMMDD3         NVARCHAR2(16);
    o_VKJ_GENGO              NVARCHAR2(16);
    o_VKG_GENGO              NVARCHAR2(16);
    o_IWAREKI_YY             PLS_INTEGER;
    o_ISEIREKI_YYYY          PLS_INTEGER;
    o_IWAREKI_GYYMM          PLS_INTEGER;
    o_IMM                    PLS_INTEGER;
    o_IDD                    PLS_INTEGER;
    o_IWAREKIHIZUKE          PLS_INTEGER;
    o_ISEIREKIHIZUKE         PLS_INTEGER;
    o_IUSER_ID               PLS_INTEGER    := 0;
    o_IGAPPEI_BI             PLS_INTEGER    := 0;
    o_IJICHI_CD              PLS_INTEGER    := 0;
    o_IUSER_KBN              PLS_INTEGER    := 0;
    o_VKENMEI                NVARCHAR2(90)  := '';
    o_VGUNSHIMEI             NVARCHAR2(90)  := '';
    o_VUSERMEI               NVARCHAR2(120) := '';
    o_VSHUCHOMEI             NVARCHAR2(120) := '';
    o_VSHUCHONINSHOBUN       NVARCHAR2(100) := '';
    o_VYUBIN_NO              NVARCHAR2(30)  := '';
    o_VSHOZAICHI             NVARCHAR2(600) := '';
    o_VTEL_NO                NVARCHAR2(60)  := '';
    -- 例外部定義（パラメータエラー時）
    PARAM_ERROR              EXCEPTION;

    CURSOR C_WK IS
      SELECT A.SANTEIDANTAI_CD,
             A.SHOGAKU_CD
        FROM GKBWGAKKOJINKOTOKEI A
       GROUP BY A.SANTEIDANTAI_CD, A.SHOGAKU_CD
       ORDER BY A.SANTEIDANTAI_CD, A.SHOGAKU_CD;

    CURSOR C_WK1(p_SANTEI IN NUMBER, p_SHO IN NUMBER) IS
      SELECT CNT_MEN0,
             CNT_WOMEN0,
             CNT_MEN1,
             CNT_WOMEN1,
             CNT_MEN2,
             CNT_WOMEN2,
             CNT_MEN3,
             CNT_WOMEN3,
             CNT_MEN4,
             CNT_WOMEN4,
             CNT_MEN5,
             CNT_WOMEN5,
             CNT_MEN6,
             CNT_WOMEN6
        FROM (SELECT NVL(COUNT(*),0) CNT_MEN0
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 1
                 AND AA.NENREI = 0) MEN0,
             (SELECT NVL(COUNT(*),0) CNT_WOMEN0
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 2
                 AND AA.NENREI = 0) WOMEN0,
             (SELECT NVL(COUNT(*),0) CNT_MEN1
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 1
                 AND AA.NENREI = 1) MEN1,
             (SELECT NVL(COUNT(*),0) CNT_WOMEN1
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 2
                 AND AA.NENREI = 1) WOMEN1,
             (SELECT NVL(COUNT(*),0) CNT_MEN2
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 1
                 AND AA.NENREI = 2) MEN2,
             (SELECT NVL(COUNT(*),0) CNT_WOMEN2
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 2
                 AND AA.NENREI = 2) WOMEN2,
             (SELECT NVL(COUNT(*),0) CNT_MEN3
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 1
                 AND AA.NENREI = 3) MEN3,
             (SELECT NVL(COUNT(*),0) CNT_WOMEN3
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 2
                 AND AA.NENREI = 3) WOMEN3,
             (SELECT NVL(COUNT(*),0) CNT_MEN4
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 1
                 AND AA.NENREI = 4) MEN4,
             (SELECT NVL(COUNT(*),0) CNT_WOMEN4
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 2
                 AND AA.NENREI = 4) WOMEN4,
             (SELECT NVL(COUNT(*),0) CNT_MEN5
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 1
                 AND AA.NENREI = 5) MEN5,
             (SELECT NVL(COUNT(*),0) CNT_WOMEN5
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 2
                 AND AA.NENREI = 5) WOMEN5,
             (SELECT NVL(COUNT(*),0) CNT_MEN6
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 1
                 AND AA.NENREI = 6) MEN6,
             (SELECT NVL(COUNT(*),0) CNT_WOMEN6
                FROM GKBWGAKKOJINKOTOKEI AA
               WHERE AA.SANTEIDANTAI_CD = p_SANTEI
                 AND AA.SHOGAKU_CD = p_SHO
                 AND AA.SEIBETSU = 2
                 AND AA.NENREI = 6) WOMEN6;

    g_nTIME NUMBER;  --時分秒

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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        Vcm        DBMS_UTILITY.MAXNAME_ARRAY;
        Vcm1       DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        V_JYOUKEN1 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNendo');        --作成年度
        V_JYOUKEN2 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKijunBi');      --住民基準日
        V_JYOUKEN3 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSakuseiBi');    --作成日
        Vcm := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbShukeiKbn');     --集計区分
        V_JYOUKEN4 := Vcm(1);
        Vcm1 := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGaikokujinKbn');--外国人区分
        V_JYOUKEN5 := Vcm1(1);

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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
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
    --  機能概要      : 日付チェック
    --  パラメータ    : i_VHIZUKE
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    BRET BOOLEAN;
    BEGIN
      IRET := 0;
      --日付
      BEGIN
        IF i_VHIZUKE IS NULL THEN
          IRET := 1;
        ELSIF LENGTH(i_VHIZUKE) <> 7 THEN
          IRET := 1;
        ELSE
          IWAREKIHIDUKEIO  := TO_NUMBER(i_VHIZUKE);
          ISEIREKIHIDUKEIO := 0;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      IF IRET = 0 THEN
        BRET := KKAPK0020.FDAYEDIT(IWAREKIHIDUKEIO, ISEIREKIHIDUKEIO,
                                    VEDIT1O, VEDIT2O, VEDIT3O,
                                    VGENGOKANJIO, VGENGOKIGOO,
                                    IWAREKINENO, ISEIREKINENO,
                                    IWAREKINENGETUO, ITUKIO, IDAYO,
                                    IWAREKIHIDUKEO, ISEIREKIHIDUKEO);
        IF BRET = FALSE THEN
          IRET := 1;
        END IF;
      END IF;

      RETURN(IRET);
    END FUNCHIZUKECHK;

    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 区分チェック
    --  パラメータ    : i_VKUBUN
    --             : i_IKBN_S
    --             : i_IKBN_E
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCKUBUNCHK( i_VKUBUN IN NVARCHAR2, i_IKBN_S IN PLS_INTEGER, i_IKBN_E IN PLS_INTEGER ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    KUBUN PLS_INTEGER;
    BEGIN
      IRET := 0;
      BEGIN
        IF i_VKUBUN IS NULL THEN
          IRET := 1;
        ELSE
          KUBUN  := TO_NUMBER(i_VKUBUN);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      IF IRET = 0 THEN
        IF (KUBUN < i_IKBN_S) OR (KUBUN > i_IKBN_E) THEN
          IRET := 1;
        END IF;
      END IF;

      RETURN(IRET);
    END FUNCKUBUNCHK;

    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 年度チェック
    --  パラメータ    : i_VNENDO
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCNENDOCHK( i_VNENDO IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    INENDO NUMBER;
    BEGIN
      IRET := 0;
      --対象年度
      BEGIN
        IF i_VNENDO IS NULL THEN
          IRET := 1;
        ELSIF LENGTH(i_VNENDO) <> 3 THEN
          IRET := 1;
        ELSE
          INENDO := KKAPK0020.FNENDO(i_VNENDO,1);
          IF INENDO = 0 THEN
            IRET := 1;
          END IF;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      RETURN(IRET);
    END FUNCNENDOCHK;

    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
        --  2024/10/18 ZCZL.ZHANGLEI ADD START 0.3.000.001:IT_GKB_00079仕様変更対応
        vERRTMPMSG                    NVARCHAR2(1000);
        sWAREKINENDO                  NUMBER;
        --  2024/10/18 ZCZL.ZHANGLEI ADD END
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
        IRTN := 0;
        
        --  2024/10/18 ZCZL.ZHANGLEI ADD START 0.3.000.001:IT_GKB_00079仕様変更対応
        vERRTMPMSG := '';
        --処理条件.年度チェック
        IRTN := KKAPK0020.FNendoWS(V_JYOUKEN1,sWAREKINENDO);
        IF IRTN <> 0 THEN
          vERRTMPMSG := g_sGYOUMUCODE || ',99999,年度が正しくありません。,;';
          VMSG := VMSG || vERRTMPMSG;
        END IF;
        --処理条件.基準日の数値チェック
        bRTN := KKAPK0010.FISNUMERIC(V_JYOUKEN2);
        IF bRTN THEN
          --処理条件.基準日の日付の妥当性をチェック
          bRTN := KKAPK0020.FISDATEW(TO_NUMBER(V_JYOUKEN2));
          IF NOT bRTN THEN
            vERRTMPMSG := g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
            VMSG := VMSG || vERRTMPMSG;
          END IF;
        ELSE
          vERRTMPMSG := g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
          VMSG := VMSG || vERRTMPMSG;
        END IF;
        
        --処理条件.作成日の数値チェック
        bRTN := KKAPK0010.FISNUMERIC(V_JYOUKEN3);
        IF bRTN THEN
          --処理条件.作成日の日付の妥当性をチェック
          bRTN := KKAPK0020.FISDATEW(TO_NUMBER(V_JYOUKEN3));
          IF NOT bRTN THEN
            vERRTMPMSG := g_sGYOUMUCODE || ',99999,作成日が正しくありません。,;';
            VMSG := VMSG || vERRTMPMSG;
          END IF;
        ELSE
          vERRTMPMSG := g_sGYOUMUCODE || ',99999,作成日が正しくありません。,;';
          VMSG := VMSG || vERRTMPMSG;
        END IF;
        --  2024/10/18 ZCZL.ZHANGLEI ADD END
        
        --条件１のチェック
        IRTN := FUNCNENDOCHK( V_JYOUKEN1 );
        IF IRTN <> 0 THEN
            VMSG := g_sGYOUMUCODE || ',99999,作成年度が正しくありません。,;';
        END IF;

        --条件２のチェック
        IRTN := FUNCHIZUKECHK( V_JYOUKEN2 );
        IF IRTN <> 0 THEN
          IF VMSG = '' THEN
            VMSG := g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
          END IF;
        END IF;

        --条件３のチェックt
        IRTN := FUNCHIZUKECHK( V_JYOUKEN3 );
        IF IRTN <> 0 THEN
          IF VMSG = '' THEN
            VMSG := g_sGYOUMUCODE || ',99999,作成日が正しくありません。,;';
          END IF;
        END IF;

        --条件４のチェック
        IRTN := FUNCKUBUNCHK( V_JYOUKEN4, 0, 8 );
        IF IRTN <> 0 THEN
          IF VMSG = '' THEN
            VMSG := g_sGYOUMUCODE || ',99999,集計区分が正しくありません。,;';
          END IF;
        END IF;

        --条件５のチェック
        IRTN := FUNCKUBUNCHK( V_JYOUKEN5, 0, 1 );
        IF IRTN <> 0 THEN
          IF VMSG = '' THEN
            VMSG := g_sGYOUMUCODE || ',99999,外国人区分が正しくありません。,;';
          END IF;
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B11CSV(i_TBLNAME IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;          --戻り値
        nCSV_RCNT                     NUMBER;           --CSVファイル出力件数
        sCSVFILENAME                  NVARCHAR2(1000);  --CSVファイル名
        sPRTFILENAME                  NVARCHAR2(1000);  --印刷ファイル名
        vOUTCSVSQL                    NVARCHAR2(1000);  --SQL文
        nOUTCSVCNT                    NUMBER;           --CSV出力件数
    BEGIN
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        vOUTCSVSQL := 'SELECT COUNT(1) FROM ' || i_TBLNAME || ' WHERE ';
        vOUTCSVSQL := vOUTCSVSQL || ' JOBNUM = ' || g_nJOBNUM;
        vOUTCSVSQL := vOUTCSVSQL || ' AND WSNUM = ' || '''' || g_sWSNUM || '''';
        vOUTCSVSQL := vOUTCSVSQL || ' AND BATCHKBN = ' || c_BATCH;
        EXECUTE IMMEDIATE vOUTCSVSQL INTO nOUTCSVCNT;
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
        g_nCSVKENSAKU := nOUTCSVCNT;
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        g_oKENSU_LIST.EXTEND(2);
        g_oKENSU_LIST(1) :=GKBEKENSU_RECORD(N_RECORD,'入力 学校区別児童集計表数調べ（未就学児童）対象件数',1);
        g_oKENSU_LIST(2) :=GKBEKENSU_RECORD(g_nCSVKENSAKU,'出力 学校区別児童集計表数調べ（未就学児童）ＣＳＶ',2);
-- 2024/07/18 ZCZL.wangqiwei Add end   
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

    ----------------------------------------------------------------------------
    --  機能概要      : 合併後のユーザー情報取得
    --  パラメータ    : KIJUNBI
    --  モジュール区分: 内部関数
    --  戻り値        : 稼動ユーザ名
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    ----------------------------------------------------------------------------
    FUNCTION GETKADOJOHO(KIJUNBI IN NUMBER) RETURN NVARCHAR2 IS
        USER_NM  NVARCHAR2(40) := '';
    BEGIN
          SELECT KENMEI || GUNSHIMEI || USERMEI INTO USER_NM
            FROM KKATGAPPEIJOHO
           WHERE TEKIYO_BI = (SELECT MAX(TEKIYO_BI) FROM KKATGAPPEIJOHO
                               WHERE TEKIYO_BI <= KIJUNBI);
        RETURN (USER_NM);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '';
    END GETKADOJOHO;
    ----------------------------------------------------------------------------
    --  機能概要      : 行政情報取得
    --  パラメータ    : SANTEIDANTAI_CD
    --                : GYOSEI_CD
    --                : GYOSEI_KBN
    --  モジュール区分: 内部関数
    --  戻り値        : 行政名漢字
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    ----------------------------------------------------------------------------
    FUNCTION GETGYOSEIJOHO(SANTEIDANTAI_CD IN NUMBER,
                           GYOSEI_CD       IN NUMBER,
                           GYOSEI_KBN      IN PLS_INTEGER) RETURN NVARCHAR2
    IS
        GYOSEI_NM  NVARCHAR2(15) := '';
    BEGIN
          SELECT GYOSEI_MEI_KANJI INTO GYOSEI_NM
            FROM GABTGYOSEIJOHO
           WHERE KYU_JICHITAI_KBN = SANTEIDANTAI_CD
             AND GYOSEI_JOHO_CD   = GYOSEI_CD
             AND GYOSEI_JOHO_KBN  = GYOSEI_KBN;
        RETURN (GYOSEI_NM);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '';
    END GETGYOSEIJOHO;
    ----------------------------------------------------------------------------
    --  機能概要      : 合併情報取得
    --  パラメータ    : i_SANTEIDANTAI_CD
    --                : KIJUNBI
    --  モジュール区分: 内部関数
    --  戻り値        : 合併名漢字
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    ----------------------------------------------------------------------------
    FUNCTION GETGAPPEIJOHO(i_SANTEIDANTAI_CD IN NUMBER,
                           KIJUNBI           IN NUMBER) RETURN NVARCHAR2
    IS
        KYU_JICHITAI_NM  NVARCHAR2(15) := '';
    BEGIN
          SELECT USERMEI INTO KYU_JICHITAI_NM
            FROM KKATGAPPEIJOHO
           WHERE SANTEIDANTAI_CD = i_SANTEIDANTAI_CD
             AND TEKIYO_BI = (SELECT MAX(TEKIYO_BI)
                                FROM KKATGAPPEIJOHO
                               WHERE TEKIYO_BI      <= KIJUNBI
                                 AND SANTEIDANTAI_CD = i_SANTEIDANTAI_CD );
        RETURN (KYU_JICHITAI_NM);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '';
    END GETGAPPEIJOHO;
    ----------------------------------------------------------------------------
    --  機能概要      : 支所情報取得
    --  パラメータ    : i_SHISHO_CD
    --  モジュール区分: 内部関数
    --  戻り値        : 支所名
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    ----------------------------------------------------------------------------
    FUNCTION GETSHISHOJOHO(i_SHISHO_CD IN NUMBER) RETURN NVARCHAR2
    IS
        SHISHO_NM                NVARCHAR2(15) := '';
        o_sMEISHOKANA            NVARCHAR2(100);
        o_sYOBI                  NVARCHAR2(100);
        nRTN                     PLS_INTEGER;
    BEGIN
        nRTN := KKAPK0030.FCDGetR('KKN','001','0000',TO_CHAR(i_SHISHO_CD,'FM000'),SHISHO_NM ,o_sMEISHOKANA,o_sYOBI);

        RETURN (SHISHO_NM);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '';
    END GETSHISHOJOHO;
    ----------------------------------------------------------------------------
    --  機能概要      : 大字情報取得
    --  パラメータ    : SANTEIDANTAI_CD
    --                : i_OAZA_CD
    --  モジュール区分: 内部関数
    --  戻り値        : 大字名漢字
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    ----------------------------------------------------------------------------
    FUNCTION GETOAZANM(SANTEIDANTAI_CD IN NUMBER,
                       i_OAZA_CD       IN NUMBER) RETURN NVARCHAR2
    IS
        OAZA_NM  NVARCHAR2(30) := '';
    BEGIN
          SELECT OAZA_KANJI INTO OAZA_NM
            FROM GABTOAZA
           WHERE OAZA_CD          = i_OAZA_CD
             AND KYU_JICHITAI_KBN = SANTEIDANTAI_CD;
        RETURN (OAZA_NM);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '';
    END GETOAZANM;
    ----------------------------------------------------------------------------
    --  機能概要      : 行政名称を取得する（処理条件で分岐）
    --  パラメータ    : SANTEIDANTAI_CD
    --                : SECTION_CD
    --                : SHUKEI_KBN
    --                : KIJUNBI
    --  モジュール区分: 内部関数
    --  戻り値        : 漢字
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    ----------------------------------------------------------------------------
    FUNCTION GETSECTIONNM(SANTEIDANTAI_CD IN NUMBER,
                          SECTION_CD      IN NUMBER,
                          SHUKEI_KBN      IN PLS_INTEGER,
                          KIJUNBI         IN NUMBER) RETURN NVARCHAR2
    IS
        SECTION_NM  NVARCHAR2(30) := '';
    BEGIN
        IF SHUKEI_KBN = 0 THEN     --自治体名
            SECTION_NM := GETKADOJOHO(KIJUNBI);
        ELSIF SHUKEI_KBN = 1 THEN --旧自治体名
            SECTION_NM := GETGAPPEIJOHO(SECTION_CD, KIJUNBI);
        ELSIF SHUKEI_KBN = 2 THEN --支所名
            SECTION_NM := GETSHISHOJOHO(SECTION_CD);
        ELSIF SHUKEI_KBN = 3 THEN --地区名
            SECTION_NM := GETGYOSEIJOHO(SANTEIDANTAI_CD, SECTION_CD, 1);
        ELSIF SHUKEI_KBN = 4 THEN --行政区名
            SECTION_NM := GETGYOSEIJOHO(SANTEIDANTAI_CD, SECTION_CD, 2);
        ELSIF SHUKEI_KBN = 5 THEN --隣保班名
            SECTION_NM := GETGYOSEIJOHO(SANTEIDANTAI_CD, SECTION_CD, 3);
        ELSIF SHUKEI_KBN = 6 THEN --大字名
            SECTION_NM := GETOAZANM(SANTEIDANTAI_CD, SECTION_CD);
        END IF;
        RETURN (SECTION_NM);
    END GETSECTIONNM;

    ------------------------------------------------------------------------------
    --  機能概要      : 生年月日から年齢を求める
    --  パラメータ    : i_NBIRTH
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    ------------------------------------------------------------------------------
    FUNCTION FUNC_GET_NENREI(i_NBIRTH IN PLS_INTEGER) RETURN PLS_INTEGER
    IS
        I_CNT       PLS_INTEGER;
    BEGIN
        FOR I_CNT IN 1..7 LOOP
            IF i_NBIRTH >= I_BIRTH_B(I_CNT) AND i_NBIRTH <= I_BIRTH_E(I_CNT) THEN
                RETURN I_CNT;
            END IF;
        END LOOP;

        RETURN 0;       -- あり得ないけど、一応
    END FUNC_GET_NENREI;

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        r_CHOHYO_001     GKBWL250R001%ROWTYPE;
        nROWNUM          NUMBER:=0;
        ERR              EXCEPTION;
-- 2024/06/04 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
       o_vSHOGAKU_CD     NVARCHAR2(20);
       o_vSHOGAKU_NM     NVARCHAR2(20);
       o_vCHUGAKU_CD     NVARCHAR2(20);
       o_vCHUGAKU_NM     NVARCHAR2(20);
       o_sMEISHO         NVARCHAR2(20);
       o_sMEISHOKANA     NVARCHAR2(20);
       o_sYOBI           NVARCHAR2(20);
-- 2024/06/04 ZCZL.wangqiwei Add  end
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        BEGIN
          DELETE FROM GKBWL250R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
-- 2024/06/04 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発の標準化対応
          DELETE FROM GKBWGAKKOJINKOTOKEI;
          -- 基準日（和暦→西暦）
          B_RTN := KKAPK0020.FDAYEDIT(V_JYOUKEN2,
                                       io_ISEIREKIHIZUKE,
                                       o_VEDIT_GYYMMDD1,
                                       o_VEDIT_GYYMMDD2,
                                       o_VEDIT_GYYMMDD3,
                                       o_VKJ_GENGO,
                                       o_VKG_GENGO,
                                       o_IWAREKI_YY,
                                       o_ISEIREKI_YYYY,
                                       o_IWAREKI_GYYMM,
                                       o_IMM,
                                       o_IDD,
                                       o_IWAREKIHIZUKE,
                                       o_ISEIREKIHIZUKE);
          V_KIJUNBI         := TO_CHAR(o_ISEIREKIHIZUKE); -- 西暦変換後　　：YYYYMMDD
          KIJUNBI           := TO_NUMBER(o_ISEIREKIHIZUKE);
          V_BKIJUNBI          := o_VEDIT_GYYMMDD3; -- ＣＳＶ出力用　：平成○年○月○日

          -- 作成日（和暦→西暦）
          io_ISEIREKIHIZUKE := NULL;
          B_RTN := KKAPK0020.FDAYEDIT(V_JYOUKEN3,
                                       io_ISEIREKIHIZUKE,
                                       o_VEDIT_GYYMMDD1,
                                       o_VEDIT_GYYMMDD2,
                                       o_VEDIT_GYYMMDD3,
                                       o_VKJ_GENGO,
                                       o_VKG_GENGO,
                                       o_IWAREKI_YY,
                                       o_ISEIREKI_YYYY,
                                       o_IWAREKI_GYYMM,
                                       o_IMM,
                                       o_IDD,
                                       o_IWAREKIHIZUKE,
                                       o_ISEIREKIHIZUKE);
          V_SAKUSEIBI := TO_CHAR(o_ISEIREKIHIZUKE);  -- 西暦変換後　　：YYYYMMDD
          V_BSAKUSEIBI  := o_VEDIT_GYYMMDD3;  -- ＣＳＶ出力用　：平成○年○月○日

          I_NENDO := TO_NUMBER(V_JYOUKEN1);
          io_IWAREKIHIZUKE := I_NENDO * 10000 + 401;
          io_iSEIREKIHIZUKE := 0;
          B_RTN := KKAPK0020.FDAYEDIT(io_IWAREKIHIZUKE,
                                       io_ISEIREKIHIZUKE,
                                       o_VEDIT_GYYMMDD1,
                                       o_VEDIT_GYYMMDD2,
                                       o_VEDIT_GYYMMDD3,
                                       o_VKJ_GENGO,
                                       o_VKG_GENGO,
                                       o_IWAREKI_YY,
                                       o_ISEIREKI_YYYY,
                                       o_IWAREKI_GYYMM,
                                       o_IMM,
                                       o_IDD,
                                       o_IWAREKIHIZUKE,
                                       o_ISEIREKIHIZUKE);
          V_NENDO := o_VKJ_GENGO || MOD(o_IWAREKI_YY,100) || '年度';
          V_SHUKEIKBN  := V_JYOUKEN4;
          I_GAIKOKUJIN := TO_NUMBER(V_JYOUKEN5);

          -- ワークテーブルの削除
          N_RTN := KKAPK3000.FTRUNCATE('GKBWGAKKOJINKOTOKEI', V_SQL_MSG);

          -- 宛名テーブル検索
          -- 配列初期化（０歳～６歳）
          I_MEN_1.EXTEND(7);
          I_WOMEN_1.EXTEND(7);
          FOR INI IN 1..7 LOOP
              I_MEN_1(INI)       := 0;
              I_WOMEN_1(INI)     := 0;
          END LOOP;

          -- 稼動情報を取得
          N_RTN := KKAPK0030.FKYOTU(V_KIJUNBI,
                                     o_IUSER_ID,
                                     o_IJICHI_CD,
                                     o_IGAPPEI_BI,
                                     o_IUSER_KBN,
                                     o_VGUNSHIMEI,
                                     o_VUSERMEI,
                                     o_VSHUCHOMEI,
                                     o_VKENMEI,
                                     o_VSHUCHONINSHOBUN,
                                     o_VYUBIN_NO,
                                     o_VSHOZAICHI,
                                     o_VTEL_NO);

          IF N_RTN=0 THEN
              V_USER_MEI := o_VKENMEI || o_VGUNSHIMEI || o_VUSERMEI;
          ELSE
                   /* o_IUSER_IDを取得できなかった場合の対応
                    * 取得できないケース:
                    * AAT_KADOKIHONの適用日より古い基準日が指定された
                    * 通常はありえないが入力される可能性があるので
                    * この場合は空のイメージを表示するようにする
                    */
              RAISE PARAM_ERROR;
          END IF;

          -- 合併判定
          IF o_IGAPPEI_BI > V_KIJUNBI THEN
              GAPPEI_FLG := FALSE;
          END IF;
          --生年月日範囲（０歳～６歳）を作成
          io_IWAREKIHIZUKE := I_NENDO * 10000 + 402;
          io_ISEIREKIHIZUKE := NULL;
          B_RTN := KKAPK0020.FDAYEDIT(io_IWAREKIHIZUKE,
                                       io_ISEIREKIHIZUKE,
                                       o_VEDIT_GYYMMDD1,
                                       o_VEDIT_GYYMMDD2,
                                       o_VEDIT_GYYMMDD3,
                                       o_VKJ_GENGO,
                                       o_VKG_GENGO,
                                       o_IWAREKI_YY,
                                       o_ISEIREKI_YYYY,
                                       o_IWAREKI_GYYMM,
                                       o_IMM,
                                       o_IDD,
                                       o_IWAREKIHIZUKE,
                                       o_ISEIREKIHIZUKE);

          I_BIRTH_B.EXTEND(7);
          I_BIRTH_E.EXTEND(7);
          I_BIRTH_B(1) := o_ISEIREKIHIZUKE;
          I_BIRTH_E(1) := KKAPK0020.FDATECAL(I_BIRTH_B(1), 0, -1,0,1);
          FOR INI IN 2..7 LOOP
              I_BIRTH_B(INI) := KKAPK0020.FDATECAL(I_BIRTH_B(INI-1), 0, 0,0,-1);
              I_BIRTH_E(INI) := KKAPK0020.FDATECAL(I_BIRTH_E(INI-1), 0, 0,0,-1);
          END LOOP;
          V_BIRTH_B.EXTEND(7);
          V_BIRTH_E.EXTEND(7);

          FOR INI IN 1..7 LOOP
              io_IWAREKIHIZUKE := NULL;
              B_RTN := KKAPK0020.FDAYEDIT(io_IWAREKIHIZUKE,
                                           I_BIRTH_B(INI),
                                           o_VEDIT_GYYMMDD1,
                                           o_VEDIT_GYYMMDD2,
                                           o_VEDIT_GYYMMDD3,
                                           o_VKJ_GENGO,
                                           o_VKG_GENGO,
                                           o_IWAREKI_YY,
                                           o_ISEIREKI_YYYY,
                                           o_IWAREKI_GYYMM,
                                           o_IMM,
                                           o_IDD,
                                           o_IWAREKIHIZUKE,
                                           o_ISEIREKIHIZUKE);
              V_BIRTH_B(INI) := o_VEDIT_GYYMMDD1;

              B_RTN := KKAPK0020.FDAYEDIT(io_IWAREKIHIZUKE,
                                           I_BIRTH_E(INI),
                                           o_VEDIT_GYYMMDD1,
                                           o_VEDIT_GYYMMDD2,
                                           o_VEDIT_GYYMMDD3,
                                           o_VKJ_GENGO,
                                           o_VKG_GENGO,
                                           o_IWAREKI_YY,
                                           o_ISEIREKI_YYYY,
                                           o_IWAREKI_GYYMM,
                                           o_IMM,
                                           o_IDD,
                                           o_IWAREKIHIZUKE,
                                           o_ISEIREKIHIZUKE);
              V_BIRTH_E(INI) := o_VEDIT_GYYMMDD1;
          END LOOP;

          --SQLステートメント作成
          V_SQL := 'SELECT A.KOJIN_NO, A.SHOGAKU_CD';
          IF GAPPEI_FLG = TRUE THEN
            IF V_SHUKEIKBN = '0' THEN     -- 市町村
                V_SQL := V_SQL || ',1 AS SANTEIDANTAI_CD , ' || o_IUSER_ID || ' SECTION_CD';
            ELSIF V_SHUKEIKBN = '1' THEN  -- 旧自治体
                V_SQL := V_SQL || ', 1 AS SANTEIDANTAI_CD , A.SANTEIDANTAI_CD SECTION_CD ';
            ELSIF V_SHUKEIKBN = '2' THEN  -- 支所
                V_SQL := V_SQL || ', 1 AS SANTEIDANTAI_CD , A.SHISHO_CD SECTION_CD ';
            ELSIF V_SHUKEIKBN = '3' THEN  -- 地区
                V_SQL := V_SQL || ', 1 AS SANTEIDANTAI_CD , A.CHIKU_CD SECTION_CD ';
            ELSIF V_SHUKEIKBN = '4' THEN  -- 行政区
                V_SQL := V_SQL || ', 1 AS SANTEIDANTAI_CD , A.GYOSEIKU_CD SECTION_CD ';
            ELSIF V_SHUKEIKBN = '5' THEN  -- 隣保班
                V_SQL := V_SQL || ', 1 AS SANTEIDANTAI_CD , A.HAN_CD SECTION_CD ';
            ELSIF V_SHUKEIKBN = '6' THEN  -- 大字
                V_SQL := V_SQL || ', 1 AS SANTEIDANTAI_CD , A.OAZA_CD SECTION_CD ';
            END IF;
          ELSE
            IF V_SHUKEIKBN = '0' THEN     -- 市町村
                V_SQL := V_SQL || ',1 AS SANTEIDANTAI_CD , ' || o_IUSER_ID || ' SECTION_CD';
            ELSIF V_SHUKEIKBN = '1' THEN  -- 旧自治体
                V_SQL := V_SQL || ', A.SANTEIDANTAI_CD , A.SANTEIDANTAI_CD SECTION_CD ';
            ELSIF V_SHUKEIKBN = '2' THEN  -- 支所
                V_SQL := V_SQL || ', A.SANTEIDANTAI_CD , A.SHISHO_CD SECTION_CD ';
            ELSIF V_SHUKEIKBN = '3' THEN  -- 地区
                V_SQL := V_SQL || ', A.SANTEIDANTAI_CD , A.CHIKU_CD SECTION_CD ';
            ELSIF V_SHUKEIKBN = '4' THEN  -- 行政区
                V_SQL := V_SQL || ', A.SANTEIDANTAI_CD , A.GYOSEIKU_CD SECTION_CD ';
            ELSIF V_SHUKEIKBN = '5' THEN  -- 隣保班
                V_SQL := V_SQL || ', A.SANTEIDANTAI_CD , A.HAN_CD SECTION_CD ';
            ELSIF V_SHUKEIKBN = '6' THEN  -- 大字
                V_SQL := V_SQL || ', A.SANTEIDANTAI_CD , A.OAZA_CD SECTION_CD ';
            END IF;
          END IF;
          V_SQL := V_SQL || ' , A.SEIBETSU , A.JINKAKU_KBN , A.SEINENGAPI';
          V_SQL := V_SQL || ' FROM  GABVATENAALL A';
          V_SQL := V_SQL || ' WHERE A.SYS_SAKUSEIBI <= ' || V_KIJUNBI;
          V_SQL := V_SQL || ' AND A.RIREKI_RENBAN = (SELECT MAX(AA.RIREKI_RENBAN)
                                                       FROM GABVATENAALL AA
                                                      WHERE AA.SYS_SAKUSEIBI <= ' || V_KIJUNBI ||
                                                      ' AND AA.KOJIN_NO = A.KOJIN_NO)';
          V_SQL := V_SQL || '   AND A.GENZON_KBN = 0';

          IF I_GAIKOKUJIN = 0 THEN
              V_SQL := V_SQL || ' AND  A.JINKAKU_KBN = 0';  -- 外国人含まない
          END IF;
          V_SQL := V_SQL || ' AND A.SEINENGAPI BETWEEN ' || TO_CHAR(I_BIRTH_B(7)) || ' AND ' || TO_CHAR(I_BIRTH_E(1));
          -- 集計区分でソート順を切り替える
          IF V_SHUKEIKBN = '0' THEN  -- 市町村
              V_SQL := V_SQL || ' ORDER BY SHOGAKU_CD';
          ELSIF V_SHUKEIKBN = '1' THEN  -- 旧自治体
              V_SQL := V_SQL || ' ORDER BY SANTEIDANTAI_CD, SHOGAKU_CD, GYOSEIKU_CD';
          ELSIF V_SHUKEIKBN IN ('2', '3', '4', '5', '6') THEN  -- 支所、地区、行政区、隣保班、大字
              V_SQL := V_SQL || ' ORDER BY SANTEIDANTAI_CD,SHOGAKU_CD, SECTION_CD';  -- ここ検証要
          END IF;

          I_CUR := DBMS_SQL.OPEN_CURSOR;
          DBMS_SQL.PARSE(I_CUR, V_SQL, DBMS_SQL.NATIVE);
          DBMS_SQL.DEFINE_COLUMN(I_CUR, 1, N_KOJIN_NO);
          DBMS_SQL.DEFINE_COLUMN(I_CUR, 2, N_SHOGAKU_CD);
          DBMS_SQL.DEFINE_COLUMN(I_CUR, 3, N_SANTEIDANTAI_CD);
          DBMS_SQL.DEFINE_COLUMN(I_CUR, 4, N_SECTION_CD);
          DBMS_SQL.DEFINE_COLUMN(I_CUR, 5, N_SEIBETSU);
          DBMS_SQL.DEFINE_COLUMN(I_CUR, 6, N_JINKAKU_KBN);
          DBMS_SQL.DEFINE_COLUMN(I_CUR, 7, N_SEINENGAPI);
          I_PRC := DBMS_SQL.EXECUTE(I_CUR);

          N_SHOGAKU_CD_OLD := 0;
          B_IS_CHG_SHO := FALSE;

          LOOP
              IF DBMS_SQL.FETCH_ROWS(I_CUR) = 0 THEN
                  EXIT;
              END IF;
              DBMS_SQL.COLUMN_VALUE(I_CUR, 1 ,N_KOJIN_NO);
              DBMS_SQL.COLUMN_VALUE(I_CUR, 2 ,N_SHOGAKU_CD);
              DBMS_SQL.COLUMN_VALUE(I_CUR, 3, N_SANTEIDANTAI_CD);
              DBMS_SQL.COLUMN_VALUE(I_CUR, 4, N_SECTION_CD);
              DBMS_SQL.COLUMN_VALUE(I_CUR, 5, N_SEIBETSU);
              DBMS_SQL.COLUMN_VALUE(I_CUR, 6, N_JINKAKU_KBN);
              DBMS_SQL.COLUMN_VALUE(I_CUR, 7, N_SEINENGAPI);
              -- １行目処理
              IF N_SECTION_CD_OLD IS NULL THEN
                  IF V_SHUKEIKBN = '0' THEN     -- 全体
                      V_SECTION_MEI := '';
                  END IF;
                  N_GYOSEIKU_CD_OLD     := N_GYOSEIKU_CD;
                  N_SECTION_CD_OLD      := N_SECTION_CD;
                  N_SANTEIDANTAI_CD_OLD := N_SANTEIDANTAI_CD;
                  V_USER_MEI_OLD        := V_USER_MEI;
                  V_GYOSEIKU_MEI_OLD    := V_GYOSEIKU_MEI;
                  V_SECTION_MEI_OLD     := GETSECTIONNM(N_SANTEIDANTAI_CD_OLD, N_SECTION_CD_OLD, TO_NUMBER(V_SHUKEIKBN), KIJUNBI);
                  N_SHOGAKU_CD_OLD      := N_SHOGAKU_CD;
              END IF;
-- 2025/01/15 JPJYS.YANGXIHAN UPDATE 0.3.000.002:学区マスタ関連修正方針対応 STR        
-- 2024/06/05 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応 
--            IF GKBFKGKKUGET(N_KOJIN_NO,'999',o_vSHOGAKU_CD,o_vSHOGAKU_NM,o_vCHUGAKU_CD,o_vCHUGAKU_NM) = 0 THEN
                --小学校区
--              N_SHOGAKU_CD := o_vSHOGAKU_CD;
--            ELSE
--              N_SHOGAKU_CD := 0;
--            END IF;
-- 2024/06/05 ZCZL.wangqiwei Add end
-- 2025/01/15 JPJYS.YANGXIHAN UPDATE 0.3.000.002:学区マスタ関連修正方針対応 END
              -- 小学校のブレイク処理
              IF N_SHOGAKU_CD_OLD != N_SHOGAKU_CD THEN
                  IF N_SHOGAKU_CD_OLD <> 0 THEN
                      B_IS_CHG_SHO := TRUE;
                  END IF;
              END IF;

              -- キーブレイク判定
              IF N_SECTION_CD_OLD != N_SECTION_CD
                    OR (GAPPEI_FLG = FALSE AND N_SANTEIDANTAI_CD_OLD != N_SANTEIDANTAI_CD)
                    OR B_IS_CHG_SHO THEN
                  B_IS_CHG_SHO := FALSE;
                  -- 集計区分=6(大字)の時は算定団体コードを無視
                  IF V_SHUKEIKBN != '6'
                        OR (V_SHUKEIKBN = '6' AND N_SECTION_CD_OLD != N_SECTION_CD) THEN
                      -- 稼動ユーザ名取得（合併後は稼動基本より取得）
                      IF GAPPEI_FLG THEN
                          V_USER_MEI_OLD := GETKADOJOHO(KIJUNBI);
                      ELSE
                          V_USER_MEI_OLD := GETGAPPEIJOHO(N_SANTEIDANTAI_CD_OLD, KIJUNBI);
                      END IF;
                      --集計区分名の編集
                      IF V_SHUKEIKBN = '0' THEN
                          V_SHUKEI_KBN     := '全体';
                          V_SHUKEI_KBN_MEI := '全体';
                      ELSIF V_SHUKEIKBN = '1' THEN
                          V_SHUKEI_KBN     := V_SECTION_MEI_OLD;
                          V_SHUKEI_KBN_MEI := '旧自治体別';
                      ELSIF V_SHUKEIKBN = '2' THEN
                          V_SHUKEI_KBN     := V_SECTION_MEI_OLD;
                          V_SHUKEI_KBN_MEI := '支所別';
                      ELSIF V_SHUKEIKBN = '3' THEN
                          V_SHUKEI_KBN     := V_SECTION_MEI_OLD;
                          V_SHUKEI_KBN_MEI := '地区別';
                      ELSIF V_SHUKEIKBN = '4' THEN
                          V_SHUKEI_KBN     := V_SECTION_MEI_OLD;
                          V_SHUKEI_KBN_MEI := '行政区別';
                      ELSIF V_SHUKEIKBN = '5' THEN
                          V_SHUKEI_KBN     := V_SECTION_MEI_OLD;
                          V_SHUKEI_KBN_MEI := '隣保班別';
                      ELSIF V_SHUKEIKBN = '6' THEN
                          V_SHUKEI_KBN     := V_SECTION_MEI_OLD;
                          V_SHUKEI_KBN_MEI := '大字別';
                      END IF;
                      -- CSVデータ編集／出力
                      r_CHOHYO_001                  := NULL;
                      r_CHOHYO_001.NENDO            := V_NENDO;                                                       -- 年度
-- 2024/06/05 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応 
                       r_CHOHYO_001.KAIPAGE_MEI      := GETGYOSEIJOHO(N_SANTEIDANTAI_CD_OLD, N_SHOGAKU_CD_OLD, 4);     -- 改頁名
                      -- ST_GKB_TMP00006 JPJYS.SSH UPDATE Start
                      --IF KKAPK0030.FCDGetR('GKB', '023', '0001' ,N_SHOGAKU_CD ,o_sMEISHO ,o_sMEISHOKANA ,o_sYOBI) = 0 THEN  -- 改頁名
                      -- ST_GKB_TMP00006 JPJYS.SSH UPDATE End
-- 2024/06/05 ZCZL.wangqiwei Update end
                      r_CHOHYO_001.KIJUNBI          := V_BKIJUNBI;                                                    -- 基準日
                      r_CHOHYO_001.SAKUSEIBI        := V_BSAKUSEIBI;                                                  -- 作成日
                      -- ST_GKB_TMP00006 JPJYS.SSH UPDATE Start
                      --r_CHOHYO_001.SHUKEI_KBN       := V_SHUKEI_KBN;                                                  -- 集計区分
                      --r_CHOHYO_001.SHUKEI_KBN_MEI   := V_SHUKEI_KBN_MEI;                                              -- 集計区分名
                      r_CHOHYO_001.SHUKEI_KBN       := V_SHUKEI_KBN_MEI;                                                  -- 集計区分
                      r_CHOHYO_001.SHUKEI_KBN_MEI   := V_SHUKEI_KBN;                                              -- 集計区分名
                      -- ST_GKB_TMP00006 JPJYS.SSH UPDATE End
                      FOR CNT IN 1..7 LOOP
                         CASE CNT
                           WHEN 1 THEN
                             r_CHOHYO_001.CNT_MEN0   := I_MEN_1(CNT);
                             r_CHOHYO_001.CNT_WOMEN0 := I_WOMEN_1(CNT);
                             r_CHOHYO_001.CNT_GOKEI0 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
                           WHEN 2 THEN
                             r_CHOHYO_001.CNT_MEN1   := I_MEN_1(CNT);
                             r_CHOHYO_001.CNT_WOMEN1 := I_WOMEN_1(CNT);
                             r_CHOHYO_001.CNT_GOKEI1  := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
                           WHEN 3 THEN
                             r_CHOHYO_001.CNT_MEN2   := I_MEN_1(CNT);
                             r_CHOHYO_001.CNT_WOMEN2 := I_WOMEN_1(CNT);
                             r_CHOHYO_001.CNT_GOKEI2 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
                           WHEN 4 THEN
                             r_CHOHYO_001.CNT_MEN3   := I_MEN_1(CNT);
                             r_CHOHYO_001.CNT_WOMEN3 := I_WOMEN_1(CNT);
                             r_CHOHYO_001.CNT_GOKEI3 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
                           WHEN 5 THEN
                             r_CHOHYO_001.CNT_MEN4   := I_MEN_1(CNT);
                             r_CHOHYO_001.CNT_WOMEN4 := I_WOMEN_1(CNT);
                             r_CHOHYO_001.CNT_GOKEI4 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
                           WHEN 6 THEN
                             r_CHOHYO_001.CNT_MEN5   := I_MEN_1(CNT);
                             r_CHOHYO_001.CNT_WOMEN5 := I_WOMEN_1(CNT);
                             r_CHOHYO_001.CNT_GOKEI5 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
                           WHEN 7 THEN
                             r_CHOHYO_001.CNT_MEN6   := I_MEN_1(CNT);
                             r_CHOHYO_001.CNT_WOMEN6 := I_WOMEN_1(CNT);
                             r_CHOHYO_001.CNT_GOKEI6 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
                           ELSE
                             NULL;
                        END CASE;
                      END LOOP;
                      FOR CNT IN 1..7 LOOP
                        CASE CNT
                          WHEN 1 THEN
                            r_CHOHYO_001.SEINENGAPI_HANI0 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                          WHEN 2 THEN
                            r_CHOHYO_001.SEINENGAPI_HANI1 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                          WHEN 3 THEN
                            r_CHOHYO_001.SEINENGAPI_HANI2 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                          WHEN 4 THEN
                            r_CHOHYO_001.SEINENGAPI_HANI3 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                          WHEN 5 THEN
                            r_CHOHYO_001.SEINENGAPI_HANI4 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                          WHEN 6 THEN
                            r_CHOHYO_001.SEINENGAPI_HANI5 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                          WHEN 7 THEN
                            r_CHOHYO_001.SEINENGAPI_HANI6 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                          ELSE
                            NULL;
                        END CASE;
                      END LOOP;
                      r_CHOHYO_001.BREAK_NO := NULL;                           -- 改ページキー
                      r_CHOHYO_001.WSNUM    := g_sWSNUM;                       -- 端末番号
                      r_CHOHYO_001.BATCHKBN := c_BATCH;                        -- 即時バッチ区分
                      r_CHOHYO_001.JOBNUM   := g_nJOBNUM;                      -- ジョブNO

                      -- CSVファイルに書き込み
                      IF V_SHUKEIKBN <> '0' THEN
                        nROWNUM := nROWNUM + 1;
                        r_CHOHYO_001.NO     := nROWNUM;                        -- ソート順
                        INSERT INTO GKBWL250R001 VALUES r_CHOHYO_001;
                      END IF;

                      -- 初期化及び小学校ごとの集計
                      FOR CNT IN 1..7 LOOP
                          I_MEN_1(CNT)   := 0;
                          I_WOMEN_1(CNT) := 0;
                      END LOOP;
                      --キー項目退避
                      N_GYOSEIKU_CD_OLD     := N_GYOSEIKU_CD;
                      N_SECTION_CD_OLD      := N_SECTION_CD;
                      N_SANTEIDANTAI_CD_OLD := N_SANTEIDANTAI_CD;
                      V_USER_MEI_OLD        := V_USER_MEI;
                      V_GYOSEIKU_MEI_OLD    := V_GYOSEIKU_MEI;
                      V_SECTION_MEI_OLD     := GETSECTIONNM(N_SANTEIDANTAI_CD, N_SECTION_CD, TO_NUMBER(V_SHUKEIKBN), KIJUNBI);
                      N_SHOGAKU_CD_OLD      := N_SHOGAKU_CD;
                  END IF;
              END IF;
              -- 年齢
              N_AGE := FUNC_GET_NENREI(N_SEINENGAPI);
              -- 男性
              IF N_SEIBETSU = 1 THEN
                  I_MEN_1(N_AGE)     := I_MEN_1(N_AGE) + 1;
              -- 女性
              ELSIF N_SEIBETSU = 2 THEN
                  I_WOMEN_1(N_AGE)     := I_WOMEN_1(N_AGE) + 1;
              ELSE
                  NULL;
              END IF;
              INSERT INTO GKBWGAKKOJINKOTOKEI
                     (SHOGAKU_CD,   SANTEIDANTAI_CD,   SEIBETSU,   NENREI)
              VALUES (N_SHOGAKU_CD, N_SANTEIDANTAI_CD, N_SEIBETSU, N_AGE - 1);

              -- 処理レコード数、総合計集計
              N_RECORD := N_RECORD + 1;
              N_SUM_R  := N_SUM_R  + 1;
          END LOOP;
          ------------------------------
          -- CSVファイルに出力（最終行）
          ------------------------------
          -- 稼動ユーザ名取得（合併後は稼動基本より取得）
          IF GAPPEI_FLG THEN
              V_USER_MEI_OLD := GETKADOJOHO(KIJUNBI);
          ELSE
              V_USER_MEI_OLD := GETGAPPEIJOHO(N_SANTEIDANTAI_CD_OLD, KIJUNBI);
          END IF;
          -- 集計区分名の編集
          IF V_SHUKEIKBN = '0' THEN
              V_SHUKEI_KBN := '全体';
          ELSIF V_SHUKEIKBN IN ('1', '2', '3', '4', '5', '6') THEN
              V_SHUKEI_KBN := V_SECTION_MEI_OLD;
          END IF;
          -- CSVデータ編集／出力
          r_CHOHYO_001                  := NULL;
          r_CHOHYO_001.NENDO            := V_NENDO;                                                       -- 年度
-- 2024/06/05 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発の標準化対応 
--          r_CHOHYO_001.KAIPAGE_MEI      := GETGYOSEIJOHO(N_SANTEIDANTAI_CD_OLD, N_SHOGAKU_CD_OLD, 4);     -- 改頁名
          r_CHOHYO_001.KIJUNBI          := V_BKIJUNBI;                                                    -- 基準日
          r_CHOHYO_001.SAKUSEIBI        := V_BSAKUSEIBI;                                                  -- 作成日
          -- ST_GKB_TMP00006 JPJYS.SSH UPDATE Start
          --r_CHOHYO_001.SHUKEI_KBN       := V_SHUKEI_KBN;                                                  -- 集計区分
          --r_CHOHYO_001.SHUKEI_KBN_MEI   := V_SHUKEI_KBN_MEI;                                              -- 集計区分名
          r_CHOHYO_001.SHUKEI_KBN       := V_SHUKEI_KBN_MEI;                                                  -- 集計区分
          r_CHOHYO_001.SHUKEI_KBN_MEI   := V_SHUKEI_KBN;                                              -- 集計区分名
          -- ST_GKB_TMP00006 JPJYS.SSH UPDATE End
          FOR CNT IN 1..7 LOOP
            CASE CNT
               WHEN 1 THEN
                 r_CHOHYO_001.CNT_MEN0   := I_MEN_1(CNT);
                 r_CHOHYO_001.CNT_WOMEN0 := I_WOMEN_1(CNT);
                 r_CHOHYO_001.CNT_GOKEI0 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
               WHEN 2 THEN
                 r_CHOHYO_001.CNT_MEN1   := I_MEN_1(CNT);
                 r_CHOHYO_001.CNT_WOMEN1 := I_WOMEN_1(CNT);
                 r_CHOHYO_001.CNT_GOKEI1  := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
               WHEN 3 THEN
                 r_CHOHYO_001.CNT_MEN2   := I_MEN_1(CNT);
                 r_CHOHYO_001.CNT_WOMEN2 := I_WOMEN_1(CNT);
                 r_CHOHYO_001.CNT_GOKEI2 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
               WHEN 4 THEN
                 r_CHOHYO_001.CNT_MEN3   := I_MEN_1(CNT);
                 r_CHOHYO_001.CNT_WOMEN3 := I_WOMEN_1(CNT);
                 r_CHOHYO_001.CNT_GOKEI3 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
               WHEN 5 THEN
                 r_CHOHYO_001.CNT_MEN4   := I_MEN_1(CNT);
                 r_CHOHYO_001.CNT_WOMEN4 := I_WOMEN_1(CNT);
                 r_CHOHYO_001.CNT_GOKEI4 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
               WHEN 6 THEN
                 r_CHOHYO_001.CNT_MEN5   := I_MEN_1(CNT);
                 r_CHOHYO_001.CNT_WOMEN5 := I_WOMEN_1(CNT);
                 r_CHOHYO_001.CNT_GOKEI5 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
               WHEN 7 THEN
                 r_CHOHYO_001.CNT_MEN6   := I_MEN_1(CNT);
                 r_CHOHYO_001.CNT_WOMEN6 := I_WOMEN_1(CNT);
                 r_CHOHYO_001.CNT_GOKEI6 := (I_MEN_1(CNT) + I_WOMEN_1(CNT));
               ELSE
                 NULL;
            END CASE;
          END LOOP;

          FOR CNT IN 1..7 LOOP
            CASE CNT
              WHEN 1 THEN
                r_CHOHYO_001.SEINENGAPI_HANI0 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
              WHEN 2 THEN
                r_CHOHYO_001.SEINENGAPI_HANI1 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
              WHEN 3 THEN
                r_CHOHYO_001.SEINENGAPI_HANI2 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
              WHEN 4 THEN
                r_CHOHYO_001.SEINENGAPI_HANI3 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
              WHEN 5 THEN
                r_CHOHYO_001.SEINENGAPI_HANI4 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
              WHEN 6 THEN
                r_CHOHYO_001.SEINENGAPI_HANI5 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
              WHEN 7 THEN
                r_CHOHYO_001.SEINENGAPI_HANI6 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
              ELSE
                NULL;
            END CASE;
          END LOOP;
          r_CHOHYO_001.BREAK_NO := NULL;                           -- 改ページキー
          r_CHOHYO_001.WSNUM    := g_sWSNUM;                       -- 端末番号
          r_CHOHYO_001.BATCHKBN := c_BATCH;                        -- 即時バッチ区分
          r_CHOHYO_001.JOBNUM   := g_nJOBNUM;                      -- ジョブNO

          IF V_SHUKEIKBN <> '0' THEN
            nROWNUM := nROWNUM + 1;
            r_CHOHYO_001.NO     := nROWNUM;                        -- ソート順
            INSERT INTO GKBWL250R001 VALUES r_CHOHYO_001;
          END IF;

          -- 最後のページに小学校ごとの合計を印刷

          FOR CR_WK IN C_WK LOOP
              -- CSVデータ編集／出力
              nROWNUM := nROWNUM + 1;
              r_CHOHYO_001                  := NULL;
              r_CHOHYO_001.NO               := nROWNUM;                                                       -- ソート順
              r_CHOHYO_001.NENDO            := V_NENDO;                                                       -- 年度
              r_CHOHYO_001.KAIPAGE_MEI      := '総合計';                                                       -- 改頁名
              r_CHOHYO_001.KIJUNBI          := V_BKIJUNBI;                                                    -- 基準日
              r_CHOHYO_001.SAKUSEIBI        := V_BSAKUSEIBI;                                                  -- 作成日
              -- ST_GKB_TMP00006 JPJYS.SSH UPDATE Start
              --r_CHOHYO_001.SHUKEI_KBN       := GETGYOSEIJOHO(CR_WK.SANTEIDANTAI_CD, CR_WK.SHOGAKU_CD, 4);     -- 集計区分
              --r_CHOHYO_001.SHUKEI_KBN_MEI   := ' ';                                                           -- 集計区分名
              r_CHOHYO_001.SHUKEI_KBN       := ' ';                                                       -- 集計区分
              r_CHOHYO_001.SHUKEI_KBN_MEI   := GETGYOSEIJOHO(CR_WK.SANTEIDANTAI_CD, CR_WK.SHOGAKU_CD, 4); -- 集計区分名
              -- ST_GKB_TMP00006 JPJYS.SSH UPDATE End

              FOR CR_WK1 IN C_WK1(CR_WK.SANTEIDANTAI_CD, CR_WK.SHOGAKU_CD) LOOP
                                  /*
                                   * このカーソルは１行しか選択されないが、使用上便利なので、
                                   * FOR カーソルループを使用する
                                   */
                  r_CHOHYO_001.CNT_MEN0   := TO_CHAR(CR_WK1.CNT_MEN0);
                  r_CHOHYO_001.CNT_WOMEN0 := TO_CHAR(CR_WK1.CNT_WOMEN0);
                  r_CHOHYO_001.CNT_GOKEI0 := TO_CHAR(CR_WK1.CNT_MEN0 + CR_WK1.CNT_WOMEN0);

                  r_CHOHYO_001.CNT_MEN1   := TO_CHAR(CR_WK1.CNT_MEN1);
                  r_CHOHYO_001.CNT_WOMEN1 := TO_CHAR(CR_WK1.CNT_WOMEN1);
                  r_CHOHYO_001.CNT_GOKEI1 := TO_CHAR(CR_WK1.CNT_MEN1 + CR_WK1.CNT_WOMEN1);

                  r_CHOHYO_001.CNT_MEN2   := TO_CHAR(CR_WK1.CNT_MEN2);
                  r_CHOHYO_001.CNT_WOMEN2 := TO_CHAR(CR_WK1.CNT_WOMEN2);
                  r_CHOHYO_001.CNT_GOKEI2 := TO_CHAR(CR_WK1.CNT_MEN2 + CR_WK1.CNT_WOMEN2);

                  r_CHOHYO_001.CNT_MEN3   := TO_CHAR(CR_WK1.CNT_MEN3);
                  r_CHOHYO_001.CNT_WOMEN3 := TO_CHAR(CR_WK1.CNT_WOMEN3);
                  r_CHOHYO_001.CNT_GOKEI3 := TO_CHAR(CR_WK1.CNT_MEN3 + CR_WK1.CNT_WOMEN3);

                  r_CHOHYO_001.CNT_MEN4   := TO_CHAR(CR_WK1.CNT_MEN4);
                  r_CHOHYO_001.CNT_WOMEN4 := TO_CHAR(CR_WK1.CNT_WOMEN4);
                  r_CHOHYO_001.CNT_GOKEI4 := TO_CHAR(CR_WK1.CNT_MEN4 + CR_WK1.CNT_WOMEN4);

                  r_CHOHYO_001.CNT_MEN5   := TO_CHAR(CR_WK1.CNT_MEN5);
                  r_CHOHYO_001.CNT_WOMEN5 := TO_CHAR(CR_WK1.CNT_WOMEN5);
                  r_CHOHYO_001.CNT_GOKEI5 := TO_CHAR(CR_WK1.CNT_MEN5 + CR_WK1.CNT_WOMEN5);

                  r_CHOHYO_001.CNT_MEN6   := TO_CHAR(CR_WK1.CNT_MEN6);
                  r_CHOHYO_001.CNT_WOMEN6 := TO_CHAR(CR_WK1.CNT_WOMEN6);
                  r_CHOHYO_001.CNT_GOKEI6 := TO_CHAR(CR_WK1.CNT_MEN6 + CR_WK1.CNT_WOMEN6);
              END LOOP;

              FOR CNT IN 1..7 LOOP
                CASE CNT
                  WHEN 1 THEN
                    r_CHOHYO_001.SEINENGAPI_HANI0 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                  WHEN 2 THEN
                    r_CHOHYO_001.SEINENGAPI_HANI1 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                  WHEN 3 THEN
                    r_CHOHYO_001.SEINENGAPI_HANI2 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                  WHEN 4 THEN
                    r_CHOHYO_001.SEINENGAPI_HANI3 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                  WHEN 5 THEN
                    r_CHOHYO_001.SEINENGAPI_HANI4 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                  WHEN 6 THEN
                    r_CHOHYO_001.SEINENGAPI_HANI5 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                  WHEN 7 THEN
                    r_CHOHYO_001.SEINENGAPI_HANI6 := V_BIRTH_B(CNT) || '～' || V_BIRTH_E(CNT);
                  ELSE
                    NULL;
                END CASE;
              END LOOP;
              r_CHOHYO_001.BREAK_NO := NULL;                           -- 改ページキー
              r_CHOHYO_001.WSNUM    := g_sWSNUM;                       -- 端末番号
              r_CHOHYO_001.BATCHKBN := c_BATCH;                        -- 即時バッチ区分
              r_CHOHYO_001.JOBNUM   := g_nJOBNUM;                      -- ジョブNO
              INSERT INTO GKBWL250R001 VALUES r_CHOHYO_001;
          END LOOP;

          -- ステップログ
          IF DBMS_SQL.IS_OPEN(I_CUR) THEN
             DBMS_SQL.CLOSE_CURSOR(I_CUR);
          END IF;
          V_BUFFER := V_SHUKEI_KBN || '人口データ' || TO_CHAR(N_SUM_R) || '件を作成しました';
          B_RTN    := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', V_BUFFER, g_sTANTOCODE, g_sWSNUM, 1);
          V_BUFFER := V_SHUKEI_KBN || '分の異動データ' || N_RECORD || '件数を処理しました。';
          B_RTN    := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', V_BUFFER, g_sTANTOCODE, g_sWSNUM, 1);
          B_RTN    := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '学校区別人口統計表（未就学児童）の作成処理が正常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
          IF NOT B_RTN THEN
              RETURN FALSE;
          END IF;

        EXCEPTION
            ---------------------
            -- パラメータエラー
            ---------------------
            WHEN OTHERS THEN
                -- ステップログ
                IF DBMS_SQL.IS_OPEN(I_CUR) THEN
                   DBMS_SQL.CLOSE_CURSOR(I_CUR);
                END IF;
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);
                RAISE ERR;
        END;
        --帳票出力CSVの作成
        bRTN := FUNC_B11CSV('GKBWL250R001');

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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/02
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
END GKBPB00230;
/