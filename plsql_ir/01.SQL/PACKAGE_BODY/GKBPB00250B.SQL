CREATE OR REPLACE PACKAGE BODY GKBPB00250
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名  : GKB（教育）
--  プログラム名    : 教育異動者一覧
--  機能概要        : 教育異動者一覧を作成する
--  バージョン      : Ver 0.3.000.000
--  作成者／作成日  : ZCZL.DINGHOGNRUI 2024/01/04
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/06/13 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.001:IT_GKB_00075対応
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.004:IT_GKB_00429対応横展開
--  2024/11/11 ZCZL.WANGMING Update 0.3.000.005:IT_GKB_00266対応
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00665対応
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00693対応
--  2025/01/27 JPJYS.LIZIZHONG Update 0.3.000.008 ST_GKB_TMP00016 障害対応   
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
    g_nCOUNT NUMBER;
    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;
    CURSOR CJIDO(p_START IN NUMBER,
                 p_END IN NUMBER) IS
        SELECT
            JOKEN1,JOKEN2
        FROM
            GKBTKOSHINLOG
        WHERE
            GYOMU_SUBCD = 0
            AND GROUPKEY = 1
            AND ( RENBAN = 2
            AND SHORI_RENBAN = 1
                OR  RENBAN = 1
            AND SHORI_RENBAN = 2 )
            AND JOKEN1 BETWEEN  p_START AND p_END;
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- ERROR関連 --
    -- デバック
    N_SQL_CODE     NUMBER;             -- SQLエラーコード
    V_SQL_MSG      NVARCHAR2(255);     -- SQLエラーメッセージ
    -- 処理結果
    c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    c_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし
    -- 正常メッセージの値
    c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '教育異動者一覧作成処理が正常終了しました。';
    -- エラーメッセージの値
    c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '教育異動者一覧作成処理が異常終了しました。';
    -- 教育異動者一覧マスタ
    c_VTABLE       CONSTANT  NVARCHAR2(128) := 'GKBWKYOIKUIDO';
    -- １頁の最大行数
    c_IMAXROWS     CONSTANT  PLS_INTEGER    := 7;
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    ISAKUSEIBI               PLS_INTEGER;
    RG                       GKBTGAKUREIBO%ROWTYPE;
    RHOGO_ATENA              GABTATENAKIHON%ROWTYPE;
    RHOGO_SOFU               GABTSOFUSAKI%ROWTYPE;
    RJIDO_ATENA              GABTATENAKIHON%ROWTYPE;
    RJIDO_SOFU               GABTSOFUSAKI%ROWTYPE;
    -- 処理条件（画面からの引数）
    VKAISHI_WAREKI           NVARCHAR2(15);  -- 抽出開始日
    VSHURYO_WAREKI           NVARCHAR2(15);  -- 抽出終了日
    VKUBUN                   NVARCHAR2(15);  -- 処理区分
    IKBN                     PLS_INTEGER;    -- 処理区分

    IHOGOSHA_ZOKUGARA1       PLS_INTEGER;
    IMAX                     BINARY_INTEGER;
    ICNTM                    BINARY_INTEGER :=0;             -- レコードカウント
    VSEIBETSU                NVARCHAR2(2);
    IHOGOSHA_ZOKUGARA1       PLS_INTEGER;
    VZOKUGARAMEI1            NVARCHAR2(30);
    VZOKUGARAMEI2            NVARCHAR2(30);
    IGAKO_CD                 PLS_INTEGER;
    VGAKOMEI                 NVARCHAR2(60);
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN                     BOOLEAN;
    B_RTN                    BOOLEAN;
    I_RTN                    PLS_INTEGER;

    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWKYOIKUIDO%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK               MTJIDO_TYPE;
    -- 教育異動者一覧作成のレコード(GKBWKYOIKUIDO_CSV用)
    TYPE MTKYOIKUIDO_REC IS RECORD
    (
        IDO_KAISI                    NVarchar2(30),
        IDO_SYURYO                   NVarchar2(30),
        SAKUSEIBI                    NVarchar2(30),
        JIDO_SHIMEI_KANA             NVarchar2(100),
        JIDO_SHIMEI_KANJI            NVarchar2(100),
--  2024/06/13 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--        JIDO_KOJIN_NO                NUMBER(12),
        JIDO_KOJIN_NO                NUMBER(15),
        HOGOSHA_SHIMEI_KANA          NVarchar2(100),
        HOGOSHA_SHIMEI_KANJI         NVarchar2(100),
--  2024/06/13 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--        HOGOSHA_KOJIN_NO             NUMBER(12),
        HOGOSHA_KOJIN_NO             NUMBER(15),
        HYOJI_SEINENGAPI             NVarchar2(11),
        HYOJI_SEIBETSU               NVarchar2(2),
        ZOKUGARAMEI1                 NVarchar2(30),
        ZOKUGARAMEI2                 NVarchar2(30),
        SHORIBI                      NVarchar2(20),
        GAKOMEI                      NVarchar2(60),
        TENNYUGAKU_BI                NVarchar2(20),
        TENNYUGAKU_GAKUNEN           NUMBER(1),
        TENGAKU_BI                   NVarchar2(20),
        TENGAKU_GAKUNEN              NUMBER(1),
        TAIGAKU_BI                   NVarchar2(20),
        TAIGAKU_GAKUNEN              NUMBER(1),
        SOTSUGYO_BI                  NVarchar2(20),
        HOGOSHA_YUBIN_NO             NVarchar2(10),
        HOGOSHA_CHOMEI               NVarchar2(40),
        HOGOSHA_BANCHI               NVarchar2(40),
        HOGOSHA_KATAGAKI             NVarchar2(60),
        JIDO_YUBIN_NO                NVarchar2(10),
        JIDO_CHOMEI                  NVarchar2(40),
        JIDO_BANCHI                  NVarchar2(40),
        JIDO_KATAGAKI                NVarchar2(60),
        SHUGAKU_ZYOKYO               NVarchar2(300),
        IDO_JIKO                     NVarchar2(300),
        KAIPEJI_CD                   NVarchar2(500),
        KAIPEJI                      NVarchar2(500)
        ,JINKAKU_KBN                 NUMBER(1)
-- 2024/06/24 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
         ,KAISIIDOBI                    NUMBER(11), 
         SYURYOIDOBI                    NUMBER(11), 
         MAE_JIDOJUSHO                  NVARCHAR2(140), 
         MAE_JIDO_KOKUSEKI              NVARCHAR2(60), 
         MAE_HOGOSYA_KOKUSEKI           NVARCHAR2(60), 
         MAE_NUSHI_SHIMEI_KANJI         NVARCHAR2(100), 
         HENKO_BI                       NUMBER(8), 
         HENKO_TODOKEDE_BI              NUMBER(8), 
         HENKO_JIYU                     NVARCHAR2(15), 
         MAE_GAKUNEN                    NUMBER(2), 
         SHIMEI_KANA                    NVARCHAR2(100), 
         SHIMEI_KANJI                   NVARCHAR2(100), 
         HOGOSHA_SHIMEI_KANA_HENKOUGO   NVARCHAR2(100), 
         HOGOSHA_SHIMEI_KANJI_HENKOUGO  NVARCHAR2(100), 
         SEINENGAPI_HENKOUGO            NUMBER(8), 
         SEIBETSU_HENKOUGO              NUMBER(1), 
         JIDO_KANKEI                    NVARCHAR2(30), 
         JIDO_KOKUSEKI                  NVARCHAR2(60), 
         HOGOSYA_KOKUSEKI               NVARCHAR2(60), 
         NUSHI_SHIMEI_KANJI_HENKOUGO    NVARCHAR2(100), 
         GAKUNEN                        NUMBER(2), 
         GAKO_KBN_CD_HENKOUGO           NUMBER(1), 
         GAKO_CD_HENKOUGO               NUMBER(5), 
         GAKOMEI_HENKOUGO               NVARCHAR2(60), 
         JIDOJUSHO                      NVARCHAR2(140), 
         BIKO                           NVARCHAR2(300), 
         HENKO_TODOKEDE_BI_KAISHI       NVARCHAR2(11), 
         HENKO_TODOKEDE_BI_SHURYO       NVARCHAR2(11), 
         HENKO_BI_KAISHI                NVARCHAR2(11), 
         HENKO_BI_SHURYO                NVARCHAR2(11)
-- 2024/06/24 ZCZL.wangqiwei Add end
    );
    MAKYOIKUIDO_REC           MTKYOIKUIDO_REC;
-- 2024/06/24 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
       TYPE MTKYOIKUIDO_REC1 IS RECORD
    (   
        MAE_SHIMEI_KANA                 NVARCHAR2(1000),
        MAE_SHIMEI_KANJI                NVARCHAR2(1000),
        MAE_HOGOSHA_SHIMEI_KANA         NVARCHAR2(1000),
        MAE_HOGOSHA_SHIMEI_KANJI        NVARCHAR2(1000),
        MAE_SEINENGAPI                  NVARCHAR2(1000),
        MAE_SEIBETSU                    NVARCHAR2(1000),
        MAE_JIDO_KANKEI                 NVARCHAR2(1000),
        MAE_JIDO_KOKUSEKI               NVARCHAR2(1000),
        MAE_HOGOSYA_KOKUSEKI            NVARCHAR2(1000),
        MAE_GAKOMEI                     NVARCHAR2(1000),
        MAE_GAKUNEN                     NVARCHAR2(1000),
        MAE_JIDOJUSHO                   NVARCHAR2(1000),
        MAE_NUSHI_SHIMEI_KANJI          NVARCHAR2(1000),
        HENKO_TODOKEDE_BI               NVARCHAR2(1000),
        HENKO_BI                        NVARCHAR2(1000),
        JIDO_KOKUSEKI                   NVARCHAR2(1000),
        HOGOSYA_KOKUSEKI                NVARCHAR2(1000),
        GAKOMEI                         NVARCHAR2(1000),
        GAKUNEN                         NVARCHAR2(1000),
        NUSHI_SHIMEI_KANJI_HENKOUGO     NVARCHAR2(1000),
        HENKO_JIYU                      NVARCHAR2(1000),
        HENKO_TODOKEDE_BI_KAISHI        NVARCHAR2(1000),
        HENKO_TODOKEDE_BI_SHURYO        NVARCHAR2(1000),
        HENKO_BI_KAISHI                 NVARCHAR2(1000),
        HENKO_BI_SHURYO                 NVARCHAR2(1000),
        BREAK_NO                        NVARCHAR2(1000)
    );
    MAKYOIKUIDO_REC1           MTKYOIKUIDO_REC1;
-- 2024/06/24 ZCZL.wangqiwei Add end
-- 2024/06/17 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
    TYPE CSVCONT_REC IS RECORD
    (
        KOJIN_NO                     GKBTGAKUREIBO.KOJIN_NO%TYPE,
        RIREKI_RENBAN                GKBTGAKUREIBO.RIREKI_RENBAN%TYPE,
        RIREKI_RENBAN_EDA            GKBTGAKUREIBO.RIREKI_RENBAN_EDA%TYPE,
        SYOGAKO_CD                   GKBTGAKUREIBO.SYOGAKO_CD%TYPE,
        TYUGAKO_CD                   GKBTGAKUREIBO.TYUGAKO_CD%TYPE,
        KUIKIGAI_CD                  GKBTGAKUREIBO.KUIKIGAI_CD%TYPE,
        YOGOGAKO_CD                  GKBTGAKUREIBO.YOGOGAKO_CD%TYPE,
        KUNISHIRITSU_CD              GKBTGAKUREIBO.KUNISHIRITSU_CD%TYPE,
        GK_SEIBETSU                  GKBTGAKUREIBO.SEIBETSU%TYPE,
        GRB_HENKO_TODOKEDE_BI        GKBTGAKUREIBO.GRB_HENKO_TODOKEDE_BI%TYPE,
        GRB_HENKO_BI                 GKBTGAKUREIBO.GRB_HENKO_BI%TYPE,
        GRB_HENKO_JIYU               GKBTGAKUREIBO.GRB_HENKO_JIYU%TYPE,
        GAKUNEN                      GKBTGAKUREIBO.GAKUNEN%TYPE,
        HOGOSYA_ZOKUGARA1            GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1%TYPE,
        HOGOSYA_ZOKUGARA2            GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2%TYPE,
        HOGOSYA_ZOKUGARA3            GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3%TYPE,
        HOGOSYA_ZOKUGARA4            GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4%TYPE,
        HOGOSYA_KOJIN_NO             GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE,
        GAKKO_KBN_CD                 GKBTGAKUREIBO.GAKKO_KBN_CD%TYPE,
        BIKO                         GKBTGAKUREIBO.BIKO%TYPE,
        IDOJI_ATENA_RIREKI_RENBAN    GKBTGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN%TYPE,
        HOGOSYA_IDOJI_RIREKI_RENBAN  GKBTGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN%TYPE,
        GJ_SHIMEI_KANA               GABVATENAALL.SHIMEI_KANA%TYPE,
        GJ_SHIMEI_KANJI              GABVATENAALL.SHIMEI_KANJI%TYPE,
        GJ_SEINENGAPI                GABVATENAALL.SEINENGAPI%TYPE,
        GJ_KOKUSEKI_CD               GABVATENAALL.KOKUSEKI_CD%TYPE,
        GJ_CHOMEI                    GABVATENAALL.CHOMEI%TYPE,
        GJ_BANCHI                    GABVATENAALL.BANCHI%TYPE,
        GJ_KOJIN_NO                  GABVATENAALL.KOJIN_NO%TYPE,
        GJ_KATAGAKI                  GABVATENAALL.KATAGAKI%TYPE,
        GJ_NUSHI_SHIMEI_KANJI        GABVATENAALL.NUSHI_SHIMEI_KANJI%TYPE,
        GJ_SEIBETSU                  GABVATENAALL.SEIBETSU%TYPE,
        GH_SHIMEI_KANA               GABVATENAALL.SHIMEI_KANA%TYPE,
        GH_SHIMEI_KANJI              GABVATENAALL.SHIMEI_KANJI%TYPE,
        GH_KOKUSEKI_CD               GABVATENAALL.KOKUSEKI_CD%TYPE,
        GH_CHOMEI                    GABVATENAALL.CHOMEI%TYPE,
        GH_BANCHI                    GABVATENAALL.BANCHI%TYPE,
        GH_KOJIN_NO                  GABVATENAALL.KOJIN_NO%TYPE,
        GH_KATAGAKI                  GABVATENAALL.KATAGAKI%TYPE,
        GH_NUSHI_SHIMEI_KANJI        GABVATENAALL.NUSHI_SHIMEI_KANJI%TYPE,
        GH_SEIBETSU                  GABVATENAALL.SEIBETSU%TYPE
    );
    TYPE CSVCONTS_REC1 IS TABLE OF CSVCONT_REC INDEX BY BINARY_INTEGER;
    YOIKUIDO_WK  CSVCONTS_REC1;
-- 2024/06/17 ZCZL.wangqiwei Add end
    --パラメータ変数
    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    IWAREKIHIZUKE    PLS_INTEGER;
    VEDIT_GYYMMDD1   NVARCHAR2(20);
    VEDIT_GYYMMDD2   NVARCHAR2(20);
    VEDIT_GYYMMDD3   NVARCHAR2(20);
    VKJ_GENGO        NVARCHAR2(20);
    VKG_GENGO        NVARCHAR2(20);
    IWAREKI_YY       PLS_INTEGER;
    ISEIREKI_YYYY    PLS_INTEGER;
    IWAREKI_GYYMM    PLS_INTEGER;
    IMM              PLS_INTEGER;
    IDD              PLS_INTEGER;
    ISEIREKIHIZUKE   PLS_INTEGER;
    VSQLERRM         NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
    VPAGENM          NVARCHAR2(500);    -- 改頁項目名
    VPAGEFD          NVARCHAR2(500);    -- 改頁項目値
    --  旧自治体名称取得用変数(GAAPK0030.FJICHINAME)
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.004:IT_GKB_00429対応横展開
--    VSANTEIDANTAI_MEI  NVARCHAR2(15);
    VSANTEIDANTAI_MEI  GKBWKYOIKUIDO.SANTEIDANTAIMEI%TYPE;
    --  行政区名取得用変数(GAAPK0030.FGYOSEIKUMEI)
-- 2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--     VSQLSEL             VARCHAR2(2000);
    VSQLSEL             VARCHAR2(30000);
-- 2024/06/11 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
--  2024/08/30 ZCZL.WANGMING Delete 0.3.000.001:IT_GKB_00075対応
    --VSQLSEL1             VARCHAR2(2000);
    VMSG NVARCHAR2(4000);
    IRTN PLS_INTEGER;
    ICHK1 PLS_INTEGER;
    ICHK2 PLS_INTEGER;
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

    g_vJYOUKEN01     NVARCHAR2(1000);
    g_vJYOUKEN02     NVARCHAR2(1000);
    g_vJYOUKEN03     NVARCHAR2(1000);
-- 2024/06/12 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
    g_vJYOUKEN04     NVARCHAR2(1000);
    g_vJYOUKEN05     NVARCHAR2(1000);
    g_vJYOUKEN06     NVARCHAR2(1000);
    g_vJYOUKEN07     NVARCHAR2(1000);
    g_vJYOUKEN08     NVARCHAR2(1000);
    g_vJYOUKEN09     NVARCHAR2(1000);
-- 2024/06/12 ZCZL.wangqiwei Add end
    nCOUNT           NUMBER := 0;

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
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
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
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
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
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        v_cmbShoriKbn             DBMS_UTILITY.MAXNAME_ARRAY;
-- 2024/08/30 ZCZL.WANGMING Add 0.3.000.001:IT_GKB_00075対応
        v_txtKaiPageKbn           DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        -- 抽出開始異動日 期間(開始)
        g_vJYOUKEN01 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtIdoKikanStart');
        -- 抽出終了異動日 期間(終了)
        g_vJYOUKEN02 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtIdoKikanEnd');
        -- 処理区分
        v_cmbShoriKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbShoriKbn');
        g_vJYOUKEN03 := v_cmbShoriKbn(1);
-- 2024/06/12 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        -- 学年
        g_vJYOUKEN04 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtGakunen');
        -- 学齢簿変更届出年月日_期間(開始)
        g_vJYOUKEN05 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHenkokukanStartDate');
        -- 学齢簿変更届出年月日_期間(終了)
        g_vJYOUKEN06 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHenkokukanEndDate');
        -- 学齢簿変更年月日_期間(開始)
        g_vJYOUKEN07 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHenkoStartDate');
        -- 学齢簿変更年月日_期間(終了)
        g_vJYOUKEN08 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHenkoEndDate');
        -- 改頁区分
-- 2024/08/30 ZCZL.WANGMING Update start 0.3.000.001:IT_GKB_00075対応
--        g_vJYOUKEN09 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKaiPageKbn');
        v_txtKaiPageKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtKaiPageKbn');
        g_vJYOUKEN09 := v_txtKaiPageKbn(1);
-- 2024/08/30 ZCZL.WANGMING Update end
-- 2024/06/12 ZCZL.wangqiwei Add end
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
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
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
    --  機能概要      : 日付チェック
    --  パラメータ      : i_VHIZUKE  日付
    --  モジュール区分  : 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン      : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
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
-- 2024/06/13 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
--          IRET := 1;
          IRET := 2;
        ELSE
          IWAREKIHIDUKEIO  := TO_NUMBER(i_VHIZUKE);
          ISEIREKIHIDUKEIO := 0;
        END IF;

        IF IRET = 0 THEN
          BRET := KKAPK0020.FDAYEDIT(IWAREKIHIDUKEIO, ISEIREKIHIDUKEIO,
                                      VEDIT1O, VEDIT2O, VEDIT3O,
                                      VGENGOKANJIO, VGENGOKIGOO,
                                      IWAREKINENO, ISEIREKINENO,
                                      IWAREKINENGETUO, ITUKIO, IDAYO,
                                      IWAREKIHIDUKEO, ISEIREKIHIDUKEO);
          IF BRET = FALSE THEN
-- 2024/06/13 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
--            IRET := 1;
            IRET := 2;
          END IF;
        END IF;

      EXCEPTION
        WHEN OTHERS THEN
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--          IRET := 1;
          IRET := 2;
      END;

      RETURN(IRET);
    END FUNCHIZUKECHK;

    --------------------------------------------------------
    --  機能概要      : 日付の大小チェック
    --  パラメータ      : i_VHIDUKE1  日付1
    --                 i_VHIDUKE2  日付2
    --  モジュール区分  : 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン      : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNCHIKAKUCHK( i_VHIDUKE1 IN NVARCHAR2, i_VHIDUKE2 IN NVARCHAR2 ) RETURN NUMBER IS
      IRET PLS_INTEGER;
      HIDUKE1 NUMBER;
      HIDUKE2 NUMBER;
    BEGIN
      IRET := 0;
      BEGIN
        HIDUKE1  := TO_NUMBER( i_VHIDUKE1 );
        HIDUKE2  := TO_NUMBER( i_VHIDUKE2 );
        --大小チェック
        IF HIDUKE1 > HIDUKE2 THEN
          IRET := 1;
        END IF;

        EXCEPTION
          WHEN OTHERS THEN
            IRET := 1;
        END;

      RETURN(IRET);
    END FUNCHIKAKUCHK;

    --------------------------------------------------------
    --  機能概要      : 処理区分チェック
    --  パラメータ      : i_IRENBAN  処理区分
    --  モジュール区分  : 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン      : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNCSYORIKUBUN( i_IRENBAN IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    IRENBAN NUMBER;
    BEGIN
      IRET := 0;

      BEGIN

       IF  i_IRENBAN IS NULL THEN
                 IRET := 1;
       ELSE
          IRENBAN := TO_NUMBER(i_IRENBAN);
              IF NOT IRENBAN IN (0,1) THEN
                 IRET := 1;
              END IF;
       END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      RETURN(IRET);
    END FUNCSYORIKUBUN;

    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
-- 2024/06/13 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
        VERRTMPMSG                    NVARCHAR2(3000);
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
        bRTN  := FUNC_B01PINIT;
        VMSG  := '';
        IRTN  := 0;
        ICHK1 := 0;
        ICHK2 := 0;
        --条件１のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN01 );
-- 2024/06/13 ZCZL.wangqiwei UPDATE 0.3.000.000:新WizLIFE2次開発
--        IF IRTN <> 0 THEN
        IF IRTN = 1 THEN
-- 2024/06/13 ZCZL.wangqiwei ADD START 0.3.000.000:新WizLIFE2次開発
          ICHK1 := 1;
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--          VMSG  := VMSG || g_sGYOUMUCODE || ',99999,抽出開始異動日 期間(開始)が未入力されません。,;';
          VMSG  := VMSG || g_sGYOUMUCODE || ',99999,抽出開始異動日 期間(開始)が入力されていません。,;';
        ELSIF IRTN = 2 THEN
-- 2024/06/13 ZCZL.wangqiwei ADD END
          ICHK1 := 1;
          VMSG  := VMSG || g_sGYOUMUCODE || ',99999,抽出開始異動日が正しくありません。,;';
        END IF;
        --条件２のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN02 );
-- 2024/06/13 ZCZL.wangqiwei UPDATE 0.3.000.000:新WizLIFE2次開発
--        IF IRTN <> 0 THEN
        IF IRTN = 1 THEN
-- 2024/06/13 ZCZL.wangqiwei ADD START
          ICHK2 := 1;
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--          VMSG  := VMSG || g_sGYOUMUCODE || ',99999,抽出終了異動日 期間(終了)が未入力されません。,;';
          VMSG  := VMSG || g_sGYOUMUCODE || ',99999,抽出終了異動日 期間(終了)が入力されていません。,;';
        ELSIF IRTN = 2 THEN
-- 2024/06/13 ZCZL.wangqiwei ADD END
          ICHK2 := 1;
          VMSG  := VMSG || g_sGYOUMUCODE || ',99999,抽出終了異動日が正しくありません。,;';
        END IF;

        --条件１と条件２の大小チェックを行う。
        IF ICHK1 = 0 AND ICHK2 = 0 THEN
          IRTN := FUNCHIKAKUCHK( g_vJYOUKEN01, g_vJYOUKEN02 );
          IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,抽出開始異動日と抽出終了異動日の大小関係が誤っています。,;';
          END IF;
        END IF;
        --処理区分チェック
        IRTN := FUNCSYORIKUBUN( g_vJYOUKEN03 );
        IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,処理区分が正しくありません。,;';
        END IF;
-- 2024/06/13 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        VERRTMPMSG  := '';
        ICHK1 := 0;
        ICHK2 := 0;
        -- 処理条件.学齢簿変更届出年月日_期間(開始)
        IRTN := FUNCHIZUKECHK(g_vJYOUKEN05);
        IF IRTN = 1 THEN
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出年月日_期間(開始)が未入力されません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出年月日_期間(開始)が入力されていません。,;';
          VMSG := VMSG || VERRTMPMSG;
          ICHK2 := 1;
        ELSIF IRTN = 2 THEN
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出年月日_期間(開始)が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
          ICHK2 := 1;
        END IF ;
        -- 処理条件.学齢簿変更届出年月日_期間(終了)
        IRTN := FUNCHIZUKECHK(g_vJYOUKEN06);
        IF IRTN = 1 THEN
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出年月日_期間(終了)が未入力されません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出年月日_期間(終了)が入力されていません。,;';
          VMSG := VMSG || VERRTMPMSG;
          ICHK2 := 1;
        ELSIF IRTN = 2 THEN
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出年月日_期間(終了)が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
          ICHK2 := 1;
        END IF ;
        --条件５と条件６の大小チェックを行う。
        IF ICHK1 = 0 AND ICHK2 = 0 THEN
          IRTN := FUNCHIKAKUCHK( g_vJYOUKEN05, g_vJYOUKEN06 );
          IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,学齢簿変更届出年月日_期間(開始)、学齢簿変更届出年月日_期間(終了)の関係が正しくありません。,;';
          END IF;
        END IF;
        ICHK1 := 0;
        ICHK2 := 0;
        -- 処理条件.学齢簿変更年月日_期間(開始)
        IRTN := FUNCHIZUKECHK(g_vJYOUKEN07);
        IF IRTN = 1 THEN
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更年月日_期間(開始)が未入力されません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更年月日_期間(開始)が入力されていません。,;';
          VMSG := VMSG || VERRTMPMSG;
          ICHK2 := 1;
        ELSIF IRTN = 2 THEN
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更年月日_期間(開始)が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
          ICHK2 := 1;
        END IF ;
        -- 処理条件.学齢簿変更年月日_期間(終了)
        IRTN := FUNCHIZUKECHK(g_vJYOUKEN08) ;
        IF IRTN = 1 THEN
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更年月日_期間(終了)が未入力されません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更年月日_期間(終了)が入力されていません。,;';
          VMSG := VMSG || VERRTMPMSG;
          ICHK2 := 1;
        ELSIF IRTN = 2 THEN
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更年月日_期間(終了)が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
          ICHK2 := 1;
        END IF ;
        --条件７と条件８の大小チェックを行う。
        IF ICHK1 = 0 AND ICHK2 = 0 THEN
          IRTN := FUNCHIKAKUCHK( g_vJYOUKEN07, g_vJYOUKEN08 );
          IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,学齢簿変更年月日_期間(開始)、学齢簿変更年月日_期間(終了)の関係が正しくありません。,;';
          END IF;
        END IF;
        --改頁区分チェック
        IF g_vJYOUKEN09 IS NULL THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,改頁区分が未入力されません。,;';
        END IF;
-- 2024/06/13 ZCZL.wangqiwei Add end
        o_vRESULT := VMSG;

    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
    --------------------------------------------------------
    --  機能概要       : バッチジョブステップテーブルの更新処理
    --  パラメータ       : i_UPD_KBN       更新区分
    --                : i_STEPRTNCODE   実行結果コード
    --                : i_CSV_RCNT      CSV出力件数
    --                : i_CSVFILENAME   CSVファイル名
    --                : i_PRTFILENAME   出力ファイル名
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
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
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
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
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
      nCNT                          NUMBER;
    BEGIN
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        nCNT := GKBFKTBLCNT('GKBWKYOIKUIDO', NULL);
        g_oKENSU_LIST.EXTEND(2);
        g_oKENSU_LIST(1) := GKBEKENSU_RECORD(nCNT, '入力教育異動対象件数', 1);
        g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nCOUNT, '出力 教育異動一覧ＣＳＶ', 2);
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
    --------------------------------------------------------
    --  機能概要      : 教育異動者一覧ワーク中間（GKBWKYOIKUIDO）レコードの作成
    --  パラメータ      : なし
    --  モジュール区分  : 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン      : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_GET_WK RETURN NUMBER IS
        IFRET                PLS_INTEGER;                -- 戻り値
        ISTART               PLS_INTEGER;                -- 開始異動日
        IEND                 PLS_INTEGER;                -- 終了異動日
        ICNT                 BINARY_INTEGER;             -- 戻り値
        IRTNZOKUGARA1        PLS_INTEGER;
        IRTNZOKUGARAHERR1    PLS_INTEGER;
        IRTNZOKUGARA2        PLS_INTEGER;
        IRTNZOKUGARAHERR2    PLS_INTEGER;
        NPRTN                NUMBER;
        I_RTN                PLS_INTEGER;
        BRTN                 BOOLEAN;
        KOJIN_NO             GKBTGAKUREIBO.KOJIN_NO%TYPE;
        RIREKI_RENBAN        GKBTGAKUREIBO.RIREKI_RENBAN%TYPE;
        RIREKI_RENBAN_EDA    GKBTGAKUREIBO.RIREKI_RENBAN_EDA%TYPE;
        BSYORIA              BOOLEAN;
        o_RATENA_REC         GABTATENAKIHON%ROWTYPE;
        o_RSOFU_REC          GABTSOFUSAKI%ROWTYPE;
        TYPE TYPECURSOR  IS REF CURSOR;
        CRATENA              TYPECURSOR;
-- 2024/06/20 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
        sMGAKKO_CD            NVARCHAR2(1000);
        sGAKO_CD_HENKOUGO     NVARCHAR2(1000);
        vJYOUKEN05            NVARCHAR2(1000);
        vJYOUKEN06            NVARCHAR2(1000);
        o_sMEISHO             NVARCHAR2(100);
        o_sMEISHOKANA         NVARCHAR2(100);
        o_sYOBI               NVARCHAR2(100);
        o_kOKUME              NVARCHAR2(100);
        o_kOKUMEKANA          NVARCHAR2(100);
        o_kOKUMEEG            NVARCHAR2(100);
        o_kAGAKU              NVARCHAR2(100);
        GIMUKYOIKU_GAKUNENMEI NVARCHAR2(100);
        GAKUNENMEI            NVARCHAR2(100);
-- 2024/06/20 ZCZL.wangqiwei Add end
    BEGIN
         IFRET := c_INOTFOUND;                       -- 該当なし
         ISEIREKIHIZUKE := NULL;
         IWAREKIHIZUKE := TO_NUMBER(VKAISHI_WAREKI);
         BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                    VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                    VEDIT_GYYMMDD3, VKJ_GENGO,
                                    VKG_GENGO,      IWAREKI_YY,
                                    ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                    IMM,            IDD,
                                    IWAREKIHIZUKE,  ISEIREKIHIZUKE );
         ISTART := ISEIREKIHIZUKE;        -- 抽出開始異動日
         ISEIREKIHIZUKE := NULL;
         IWAREKIHIZUKE := TO_NUMBER(VSHURYO_WAREKI);
         BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                    VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                    VEDIT_GYYMMDD3, VKJ_GENGO,
                                    VKG_GENGO,      IWAREKI_YY,
                                    ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                    IMM,            IDD,
                                    IWAREKIHIZUKE,  ISEIREKIHIZUKE );
        IEND := ISEIREKIHIZUKE;            -- 抽出終了異動日
        IKBN := TO_NUMBER(VKUBUN);         -- 処理区分
        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        ICNT := 0;
        BSYORIA := FALSE;
        -- 処理条件の抽出開始異動日と抽出終了異動日と処理区分に該当するデータを検索
        BEGIN
-- 2024/06/20 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--         VSQLSEL := '';
--         VSQLSEL := VSQLSEL || 'SELECT ';
--         VSQLSEL := VSQLSEL || 'KOJIN_NO, ';
--         VSQLSEL := VSQLSEL || 'RIREKI_RENBAN ';
--         VSQLSEL := VSQLSEL || 'FROM ';
--         VSQLSEL := VSQLSEL || 'GKBTGAKUREIBO ';
--         VSQLSEL := VSQLSEL || '   WHERE  ';
--         VSQLSEL := VSQLSEL || ' SYS_KOSHINBI BETWEEN  '|| ISTART ||' AND   '|| IEND;
-- 
--         IF IKBN = 0 THEN
--             FOR CRJIDO IN CJIDO(ISTART,IEND) LOOP
--                 IF BSYORIA = FALSE THEN
--                     VSQLSEL := VSQLSEL ||' AND NOT (   SYS_KOSHINBI = ' || CRJIDO.JOKEN1;
--                     VSQLSEL := VSQLSEL || ' AND SYS_JIKAN = ' || CRJIDO.JOKEN2;
--                 ELSE
--                     VSQLSEL := VSQLSEL ||' OR  SYS_KOSHINBI = ' || CRJIDO.JOKEN1;
--                     VSQLSEL := VSQLSEL || ' AND SYS_JIKAN = ' || CRJIDO.JOKEN2;
--                 END IF;
--                 BSYORIA := TRUE;
--             END LOOP;
--             IF BSYORIA = TRUE THEN
--                 VSQLSEL := VSQLSEL ||  ')';
--             END IF;
--         END IF;
--         VSQLSEL1 := '';
--         VSQLSEL1 := VSQLSEL1 || 'SELECT ';
--         VSQLSEL1 := VSQLSEL1 || 'KOJIN_NO, ';
--         VSQLSEL1 := VSQLSEL1 || 'RIREKI_RENBAN, ';
--         VSQLSEL1 := VSQLSEL1 || 'RIREKI_RENBAN_EDA ';
--         VSQLSEL1 := VSQLSEL1 || 'FROM ';
--         VSQLSEL1 := VSQLSEL1 || 'GKBTGAKUREIBO ';
--         VSQLSEL1 := VSQLSEL1 || '   WHERE  ';
--         VSQLSEL1 := VSQLSEL1 || ' SYS_KOSHINBI BETWEEN  '|| ISTART ||' AND   '|| IEND;
        --和暦日付を西暦日付に変換する
        vJYOUKEN05 := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vJYOUKEN05));
        vJYOUKEN06 := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vJYOUKEN06));
        VSQLSEL := '';
        VSQLSEL := VSQLSEL || '    SELECT ';
        VSQLSEL := VSQLSEL || '    GKBTGAKUREIBO.KOJIN_NO AS GK_KOJIN_NO ';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.RIREKI_RENBAN ';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.RIREKI_RENBAN_EDA ';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.SYOGAKO_CD';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.TYUGAKO_CD';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.KUIKIGAI_CD';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.YOGOGAKO_CD';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.KUNISHIRITSU_CD';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.SEIBETSU AS GK_SEIBETSU ';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.GRB_HENKO_TODOKEDE_BI';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.GRB_HENKO_BI';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.GRB_HENKO_JIYU';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.GAKUNEN ';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.HOGOSYA_KOJIN_NO';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.GAKKO_KBN_CD';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.BIKO';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN';
        VSQLSEL := VSQLSEL || '  , GKBTGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN';
        VSQLSEL := VSQLSEL || '  , GJ.SHIMEI_KANA AS GJ_SHIMEI_KANA ';
        VSQLSEL := VSQLSEL || '  , GJ.SHIMEI_KANJI AS GJ_SHIMEI_KANJI ';
        VSQLSEL := VSQLSEL || '  , GJ.SEINENGAPI AS GJ_SEINENGAPI ';
        VSQLSEL := VSQLSEL || '  , GJ.KOKUSEKI_CD AS GJ_KOKUSEKI_CD ';
        VSQLSEL := VSQLSEL || '  , GJ.CHOMEI AS GJ_CHOMEI ';
        VSQLSEL := VSQLSEL || '  , GJ.BANCHI AS GJ_BANCHI ';
        VSQLSEL := VSQLSEL || '  , GJ.KOJIN_NO AS GJ_KOJIN_NO ';
        VSQLSEL := VSQLSEL || '  , GJ.KATAGAKI AS GJ_KATAGAKI ';
        VSQLSEL := VSQLSEL || '  , GJ.NUSHI_SHIMEI_KANJI AS GJ_NUSHI_SHIMEI_KANJI ';
        VSQLSEL := VSQLSEL || '  , GJ.SEIBETSU AS GJ_SEIBETSU ';
        VSQLSEL := VSQLSEL || '  , GH.SHIMEI_KANA AS GH_SHIMEI_KANA ';
        VSQLSEL := VSQLSEL || '  , GH.SHIMEI_KANJI AS GH_SHIMEI_KANJI ';
        VSQLSEL := VSQLSEL || '  , GH.KOKUSEKI_CD AS GH_KOKUSEKI_CD ';
        VSQLSEL := VSQLSEL || '  , GH.CHOMEI AS GH_CHOMEI ';
        VSQLSEL := VSQLSEL || '  , GH.BANCHI AS GH_BANCHI ';
        VSQLSEL := VSQLSEL || '  , GH.KOJIN_NO AS GH_KOJIN_NO ';
        VSQLSEL := VSQLSEL || '  , GH.KATAGAKI AS GH_KATAGAKI ';
        VSQLSEL := VSQLSEL || '  , GH.NUSHI_SHIMEI_KANJI AS GH_NUSHI_SHIMEI_KANJI ';
        VSQLSEL := VSQLSEL || '  , GH.SEIBETSU AS GH_SEIBETSU ';
        VSQLSEL := VSQLSEL || '    FROM';
        VSQLSEL := VSQLSEL || '    GKBTGAKUREIBO';
--  2024/09/25 ZCZL.WANGMING Update START 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--        VSQLSEL := VSQLSEL || '  , GABVATENAALL GJ';
--        VSQLSEL := VSQLSEL || '  , GABVATENAALL GH ';
        VSQLSEL := VSQLSEL || '    ,(SELECT ';
        VSQLSEL := VSQLSEL || '    KOJIN_NO ';
        VSQLSEL := VSQLSEL || '  , RIREKI_RENBAN ';
        VSQLSEL := VSQLSEL || '  , KOKUSEKI_CD ';
        VSQLSEL := VSQLSEL || '  , SEIBETSU';
        VSQLSEL := VSQLSEL || '  , SHIMEI_KANA';
        VSQLSEL := VSQLSEL || '  , SHIMEI_KANJI';
        VSQLSEL := VSQLSEL || '  , CHOMEI';
        VSQLSEL := VSQLSEL || '  , BANCHI';
        VSQLSEL := VSQLSEL || '  , KATAGAKI ';
        VSQLSEL := VSQLSEL || '  , NUSHI_SHIMEI_KANJI';
        VSQLSEL := VSQLSEL || '  , SEINENGAPI';
        VSQLSEL := VSQLSEL || '    FROM';
        VSQLSEL := VSQLSEL || '    GABTATENARIREKI';
        VSQLSEL := VSQLSEL || '    UNION ALL';
        VSQLSEL := VSQLSEL || '    SELECT ';
        VSQLSEL := VSQLSEL || '    GABTATENAKIHON.KOJIN_NO ';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.RIREKI_RENBAN ';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.KOKUSEKI_CD ';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.SEIBETSU';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.SHIMEI_KANA';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.SHIMEI_KANJI';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.CHOMEI';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.BANCHI';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.KATAGAKI ';
        VSQLSEL := VSQLSEL || '  , GABTJUKIIDO.NUSHI_SHIMEI_KANJI';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.SEINENGAPI';
        VSQLSEL := VSQLSEL || '    FROM';
        VSQLSEL := VSQLSEL || '    GABTATENAKIHON';
        VSQLSEL := VSQLSEL || '    ,GABTJUKIIDO';
        VSQLSEL := VSQLSEL || '    WHERE';
        VSQLSEL := VSQLSEL || '    GABTATENAKIHON.KOJIN_NO = GABTJUKIIDO.KOJIN_NO(+) ';
        VSQLSEL := VSQLSEL || '    ) GJ ';
        VSQLSEL := VSQLSEL || '    ,(SELECT ';
        VSQLSEL := VSQLSEL || '    KOJIN_NO ';
        VSQLSEL := VSQLSEL || '  , RIREKI_RENBAN ';
        VSQLSEL := VSQLSEL || '  , KOKUSEKI_CD ';
        VSQLSEL := VSQLSEL || '  , SEIBETSU';
        VSQLSEL := VSQLSEL || '  , SHIMEI_KANA';
        VSQLSEL := VSQLSEL || '  , SHIMEI_KANJI';
        VSQLSEL := VSQLSEL || '  , CHOMEI';
        VSQLSEL := VSQLSEL || '  , BANCHI';
        VSQLSEL := VSQLSEL || '  , KATAGAKI ';
        VSQLSEL := VSQLSEL || '  , NUSHI_SHIMEI_KANJI';
        VSQLSEL := VSQLSEL || '  , SEINENGAPI';
        VSQLSEL := VSQLSEL || '    FROM';
        VSQLSEL := VSQLSEL || '    GABTATENARIREKI';
        VSQLSEL := VSQLSEL || '    UNION ALL';
        VSQLSEL := VSQLSEL || '    SELECT ';
        VSQLSEL := VSQLSEL || '    GABTATENAKIHON.KOJIN_NO ';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.RIREKI_RENBAN ';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.KOKUSEKI_CD ';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.SEIBETSU';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.SHIMEI_KANA';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.SHIMEI_KANJI';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.CHOMEI';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.BANCHI';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.KATAGAKI ';
        VSQLSEL := VSQLSEL || '  , GABTJUKIIDO.NUSHI_SHIMEI_KANJI';
        VSQLSEL := VSQLSEL || '  , GABTATENAKIHON.SEINENGAPI';
        VSQLSEL := VSQLSEL || '    FROM';
        VSQLSEL := VSQLSEL || '    GABTATENAKIHON';
        VSQLSEL := VSQLSEL || '    ,GABTJUKIIDO';
        VSQLSEL := VSQLSEL || '    WHERE';
        VSQLSEL := VSQLSEL || '    GABTATENAKIHON.KOJIN_NO = GABTJUKIIDO.KOJIN_NO(+) ';
        VSQLSEL := VSQLSEL || '    ) GH ';
--  2024/09/25 ZCZL.WANGMING Update END
        VSQLSEL := VSQLSEL || '    WHERE';
        VSQLSEL := VSQLSEL || ' GKBTGAKUREIBO.SYS_KOSHINBI BETWEEN  '|| ISTART ||' AND   '|| IEND;
        VSQLSEL := VSQLSEL || '    AND GKBTGAKUREIBO.KOJIN_NO = GJ.KOJIN_NO ';
        VSQLSEL := VSQLSEL || '    AND GKBTGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN = GJ.RIREKI_RENBAN ';
        VSQLSEL := VSQLSEL || '    AND GKBTGAKUREIBO.HOGOSYA_KOJIN_NO = GH.KOJIN_NO ';
        VSQLSEL := VSQLSEL || '    AND GKBTGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN = GH.RIREKI_RENBAN ';
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00693対応 START
        IF g_vJYOUKEN04 IS NOT NULL THEN
          VSQLSEL := VSQLSEL || '    AND GKBTGAKUREIBO.GAKUNEN = ' || g_vJYOUKEN04 ;
        END IF;
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00693対応 END
        VSQLSEL := VSQLSEL || '    AND GKBTGAKUREIBO.SAKUJO_FLG = 0 ';
        VSQLSEL := VSQLSEL || ' AND ( ';
        VSQLSEL := VSQLSEL || '( ';
        VSQLSEL := VSQLSEL || '  NVL(GKBTGAKUREIBO.SYS_SAKUSEIBI,GKBTGAKUREIBO.SYS_KOSHINBI) >= ' || ISTART ;
        VSQLSEL := VSQLSEL || '   AND NVL(GKBTGAKUREIBO.SYS_SAKUSEIBI,GKBTGAKUREIBO.SYS_KOSHINBI) <= '|| IEND ;
        VSQLSEL := VSQLSEL || '   ) ';
        VSQLSEL := VSQLSEL || '   OR ( ';
        VSQLSEL := VSQLSEL || '      GKBTGAKUREIBO.GRB_HENKO_TODOKEDE_BI >= ' || vJYOUKEN05 ;
        VSQLSEL := VSQLSEL || '      AND GKBTGAKUREIBO.GRB_HENKO_TODOKEDE_BI <= ' || vJYOUKEN06 ;
        VSQLSEL := VSQLSEL || '   ) ';
        VSQLSEL := VSQLSEL || '   OR ( ';
        VSQLSEL := VSQLSEL || '      GKBTGAKUREIBO.GRB_HENKO_BI >= ' || vJYOUKEN05 ;
        VSQLSEL := VSQLSEL || '       AND GKBTGAKUREIBO.GRB_HENKO_BI <=' || vJYOUKEN06 ;
        VSQLSEL := VSQLSEL || '      )';
        VSQLSEL := VSQLSEL || '   ) ';
        IF IKBN = 0 THEN
            FOR CRJIDO IN CJIDO(ISTART,IEND) LOOP
                IF BSYORIA = FALSE THEN
                    VSQLSEL := VSQLSEL ||' AND NOT (   GKBTGAKUREIBO.SYS_KOSHINBI = ' || CRJIDO.JOKEN1;
                    VSQLSEL := VSQLSEL || ' AND GKBTGAKUREIBO.SYS_JIKAN = ' || CRJIDO.JOKEN2;
                ELSE
                    VSQLSEL := VSQLSEL ||' OR  GKBTGAKUREIBO.SYS_KOSHINBI = ' || CRJIDO.JOKEN1;
                    VSQLSEL := VSQLSEL || ' AND GKBTGAKUREIBO.SYS_JIKAN = ' || CRJIDO.JOKEN2;
                END IF;
                BSYORIA := TRUE;
            END LOOP;
            IF BSYORIA = TRUE THEN
--  2024/08/30 ZCZL.WANGMING Update Start 0.3.000.001:IT_GKB_00075対応
                --VSQLSEL1 := VSQLSEL1 ||  ')';
                VSQLSEL := VSQLSEL ||  ')';
--  2024/08/30 ZCZL.WANGMING Update End
            END IF;
        END IF;
        VSQLSEL := VSQLSEL || '  ORDER BY ';
--  2024/08/30 ZCZL.WANGMING Update Start 0.3.000.001:IT_GKB_00075対応
        --VSQLSEL := VSQLSEL || '  GKBTGAKUREIBO.KOJIN_NO , GKBTGAKUREIBO.RIREKI_RENBAN ASC';
        VSQLSEL := VSQLSEL || '  GKBTGAKUREIBO.KOJIN_NO , GKBTGAKUREIBO.RIREKI_RENBAN DESC';
--  2024/08/30 ZCZL.WANGMING Update End
-- 2024/06/20 ZCZL.wangqiwei Update end
            OPEN CRATENA  FOR VSQLSEL;
            LOOP
-- 2024/07/02 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--                FETCH  CRATENA INTO KOJIN_NO, RIREKI_RENBAN;
                FETCH  CRATENA INTO YOIKUIDO_WK(ICNT);
                EXIT WHEN CRATENA%NOTFOUND;
-- 2024/07/02 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--                    GKBSKJDOG2(KOJIN_NO,RIREKI_RENBAN,RG,NPRTN);
                    KOJIN_NO := YOIKUIDO_WK(ICNT).KOJIN_NO;
                    GKBSKJDOG2(KOJIN_NO,YOIKUIDO_WK(ICNT).RIREKI_RENBAN,YOIKUIDO_WK(ICNT).RIREKI_RENBAN_EDA,RG,NPRTN);
-- 2024/07/02 ZCZL.wangqiwei Update end
                    ISAKUSEIBI := RG.SYS_KOSHINBI;
                    I_RTN := GAAPK0030.FGETATENA( KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RJIDO_ATENA,
                                                RJIDO_SOFU );
                    MJIDO_WORK(ICNT).JIDO_KOJIN_NO := KOJIN_NO;
-- 2024/07/02 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
--                     MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := RJIDO_ATENA.SHIMEI_KANA;
--                     MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
                    IF ICNT >= 1 AND MJIDO_WORK(ICNT-1).JIDO_KOJIN_NO = KOJIN_NO THEN
                      MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := YOIKUIDO_WK(ICNT-1).GJ_SHIMEI_KANA;              --児童氏名かな
                      MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := YOIKUIDO_WK(ICNT-1).GJ_SHIMEI_KANJI;            --児童氏名漢字
                      MJIDO_WORK(ICNT).SEINENGAPI := YOIKUIDO_WK(ICNT-1).GJ_SEINENGAPI;    --生年月日
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.001:IT_GKB_00075対応
--                      MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := KKAPK0020.FDAYEDIT20 (YOIKUIDO_WK(ICNT-1).GJ_SEINENGAPI, 0, 3, 0, ' *'); -- 表示用生年月日
                      MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := KKAPK0020.FDAYEDIT20 (YOIKUIDO_WK(ICNT-1).GJ_SEINENGAPI, 0, 3, 0, '*'); -- 表示用生年月日
                      MJIDO_WORK(ICNT).SEIBETSU := YOIKUIDO_WK(ICNT-1).GJ_SEIBETSU;                         --性別
                      I_RTN := KKAPK0030.FCDGetR('GKB', '021', '0001', YOIKUIDO_WK(ICNT-1).GJ_SEIBETSU , o_sMEISHO, o_sMEISHOKANA, o_sYOBI);
                      MJIDO_WORK(ICNT).HYOJI_SEIBETSU := o_sMEISHO; -- 表示用性別
                      --小学校文部科学省学校コード
                      IF YOIKUIDO_WK(ICNT-1).GAKKO_KBN_CD = 1 THEN
                        I_RTN := GKAFKMBKKSCDGET(YOIKUIDO_WK(ICNT-1).GAKKO_KBN_CD,YOIKUIDO_WK(ICNT-1).SYOGAKO_CD,sMGAKKO_CD);
                        MJIDO_WORK(ICNT).GAKOMEI := GKAFKGKOGTEQ(1 ,YOIKUIDO_WK(ICNT-1).SYOGAKO_CD);    --学校名
                      --中学校文部科学省学校コード
                      ELSIF YOIKUIDO_WK(ICNT-1).GAKKO_KBN_CD = 2 THEN
                        I_RTN := GKAFKMBKKSCDGET(YOIKUIDO_WK(ICNT-1).GAKKO_KBN_CD,YOIKUIDO_WK(ICNT-1).TYUGAKO_CD,sMGAKKO_CD);
                        MJIDO_WORK(ICNT).GAKOMEI := GKAFKGKOGTEQ(2 ,YOIKUIDO_WK(ICNT-1).TYUGAKO_CD);    --学校名
                      --特別支援学校文部科学省学校コード
                      ELSIF YOIKUIDO_WK(ICNT-1).GAKKO_KBN_CD = 3 THEN
                        I_RTN := GKAFKMBKKSCDGET(YOIKUIDO_WK(ICNT-1).GAKKO_KBN_CD,YOIKUIDO_WK(ICNT-1).YOGOGAKO_CD,sMGAKKO_CD);
                        MJIDO_WORK(ICNT).GAKOMEI := GKAFKGKOGTEQ(3 ,YOIKUIDO_WK(ICNT-1).YOGOGAKO_CD);    --学校名
                      --区域外就学文部科学省学校コード
                      ELSIF YOIKUIDO_WK(ICNT-1).GAKKO_KBN_CD = 4 THEN
                        I_RTN := GKAFKMBKKSCDGET(YOIKUIDO_WK(ICNT-1).GAKKO_KBN_CD,YOIKUIDO_WK(ICNT-1).KUIKIGAI_CD,sMGAKKO_CD);
                        MJIDO_WORK(ICNT).GAKOMEI := GKAFKGKOGTEQ(4 ,YOIKUIDO_WK(ICNT-1).KUIKIGAI_CD);    --学校名
                      --国・私立学校文部科学省学校コード
                      ELSIF YOIKUIDO_WK(ICNT-1).GAKKO_KBN_CD = 5 THEN
                        I_RTN := GKAFKMBKKSCDGET(YOIKUIDO_WK(ICNT-1).GAKKO_KBN_CD,YOIKUIDO_WK(ICNT-1).KUNISHIRITSU_CD,sMGAKKO_CD);
                        MJIDO_WORK(ICNT).GAKOMEI := GKAFKGKOGTEQ(5 ,YOIKUIDO_WK(ICNT-1).KUNISHIRITSU_CD);    --学校名
                      END IF;
                      --変更前住所
                      MJIDO_WORK(ICNT).MAE_JIDOJUSHO := GAAPK0010.FADDRESSEDIT(1,NULL,YOIKUIDO_WK(ICNT-1).GJ_CHOMEI,YOIKUIDO_WK(ICNT-1).GJ_BANCHI,YOIKUIDO_WK(ICNT-1).GJ_KATAGAKI,NULL);
                      I_RTN := GKAFKKKMGET(YOIKUIDO_WK(ICNT-1).GJ_KOKUSEKI_CD ,o_kOKUMEKANA , o_kOKUME , o_kOKUMEEG);
                      MJIDO_WORK(ICNT).MAE_JIDO_KOKUSEKI := o_kOKUME ;                                      --変更前児童生徒国籍
                      I_RTN := GKAFKKKMGET(YOIKUIDO_WK(ICNT-1).GH_KOKUSEKI_CD ,o_kOKUMEKANA , o_kOKUME , o_kOKUMEEG);
                      MJIDO_WORK(ICNT).MAE_HOGOSYA_KOKUSEKI := o_kOKUME ;                                   --変更前保護者国籍
                      MJIDO_WORK(ICNT).MAE_NUSHI_SHIMEI_KANJI := YOIKUIDO_WK(ICNT-1).GJ_NUSHI_SHIMEI_KANJI ;     --変更前世帯主氏名
                      BEGIN 
                        SELECT GIMUKYOIKU_GAKUNENMEI,GAKUNENMEI INTO GIMUKYOIKU_GAKUNENMEI,GAKUNENMEI FROM GKBTGAKUNEN WHERE YOIKUIDO_WK(ICNT-1).GAKUNEN = GAKUNEN_CD;
                      EXCEPTION
                        WHEN OTHERS THEN
                          GIMUKYOIKU_GAKUNENMEI := NULL;
                          GAKUNENMEI := NULL;
                      END;
                      IF SUBSTR(sMGAKKO_CD,1,2) = 'C2' THEN
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00693対応 START
--                        MJIDO_WORK(ICNT).MAE_GAKUNEN := GIMUKYOIKU_GAKUNENMEI || '年生';            --変更前学年
                        MJIDO_WORK(ICNT).MAE_GAKUNEN := GIMUKYOIKU_GAKUNENMEI;            --変更前学年
                      ELSE
--                        MJIDO_WORK(ICNT).MAE_GAKUNEN := GAKUNENMEI || '年生';                       --変更前学年
                        MJIDO_WORK(ICNT).MAE_GAKUNEN := GAKUNENMEI;                       --変更前学年
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00693対応 END
                      END IF;
                    END IF;
-- 2024/07/02 ZCZL.wangqiwei Add end
                    IWAREKIHIZUKE := NULL;
                    ISEIREKIHIZUKE := RJIDO_ATENA.SEINENGAPI;
                    BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                                VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                                VEDIT_GYYMMDD3, VKJ_GENGO,
                                                VKG_GENGO,      IWAREKI_YY,
                                                ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                                IMM,            IDD,
                                                IWAREKIHIZUKE,  ISEIREKIHIZUKE );
-- 2024/07/02 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--                    MJIDO_WORK(ICNT).SEINENGAPI := RJIDO_ATENA.SEINENGAPI;
--                     MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VEDIT_GYYMMDD1;
--                     IF RJIDO_ATENA.SEIBETSU = 1 THEN
--                         VSEIBETSU := '男';
--                     ELSIF RJIDO_ATENA.SEIBETSU = 2 THEN
--                         VSEIBETSU := '女';
--                     END IF;
--                     MJIDO_WORK(ICNT).SEIBETSU := RJIDO_ATENA.SEIBETSU;
--                    MJIDO_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;
-- 2024/07/02 ZCZL.wangqiwei Delete end
                    MJIDO_WORK(ICNT).HYOJI_SEIBETSU := o_sMEISHO;
                    MJIDO_WORK(ICNT).SETAI_NO := RJIDO_ATENA.SETAI_NO;
                    MJIDO_WORK(ICNT).HYOJI_SETAI_NO := TO_CHAR(MJIDO_WORK(ICNT).SETAI_NO);
                    IF RG.HOGOSYA_KOJIN_NO IS NOT NULL THEN
                        I_RTN := GAAPK0030.FGETATENA( RG.HOGOSYA_KOJIN_NO,
                                                    'GKB',
                                                    ISAKUSEIBI,
                                                    RHOGO_ATENA,
                                                    RHOGO_SOFU);
-- 2024/07/02 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--                                                     MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RHOGO_ATENA.SHIMEI_KANA;
--                                                     MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
-- 2024/07/02 ZCZL.wangqiwei Delete end
                                                    IRTNZOKUGARA1 := GKBFKZKGMGET(1,
                                                    RG.ZOKUGARA1,
                                                    RG.ZOKUGARA2,
                                                    RG.ZOKUGARA3,
                                                    RG.ZOKUGARA4,
                                                    VZOKUGARAMEI1,
                                                    IRTNZOKUGARAHERR1);

                        MJIDO_WORK(ICNT).ZOKUGARAMEI1 := VZOKUGARAMEI1;
-- 2024/07/02 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--                         IRTNZOKUGARA2 := GKBFKZKGMGET(2,
--                                                       RG.HOGOSYA_ZOKUGARA1,
--                                                       RG.HOGOSYA_ZOKUGARA2,
--                                                       RG.HOGOSYA_ZOKUGARA3,
--                                                       RG.HOGOSYA_ZOKUGARA4,
--                                                       VZOKUGARAMEI2,
--                                                       IRTNZOKUGARAHERR2);
--                         MJIDO_WORK(ICNT).ZOKUGARAMEI2 := VZOKUGARAMEI2;
                        IF ICNT >= 1 AND MJIDO_WORK(ICNT-1).JIDO_KOJIN_NO = KOJIN_NO THEN
                          MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := YOIKUIDO_WK(ICNT-1).GH_SHIMEI_KANA;     --保護者氏名かな
                          MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := YOIKUIDO_WK(ICNT-1).GH_SHIMEI_KANJI;   --保護者氏名漢字
                          IRTNZOKUGARA2 := GKBFKZKGMGET(2,
                                                        YOIKUIDO_WK(ICNT-1).HOGOSYA_ZOKUGARA1,
                                                        YOIKUIDO_WK(ICNT-1).HOGOSYA_ZOKUGARA2,
                                                        YOIKUIDO_WK(ICNT-1).HOGOSYA_ZOKUGARA3,
                                                        YOIKUIDO_WK(ICNT-1).HOGOSYA_ZOKUGARA4,
                                                        VZOKUGARAMEI2,
                                                        IRTNZOKUGARAHERR2);
                          MJIDO_WORK(ICNT).ZOKUGARAMEI2 := VZOKUGARAMEI2;                                 --児童生徒との関係
                        END IF;
-- 2024/07/02 ZCZL.wangqiwei Update end
                        MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO := RG.HOGOSYA_KOJIN_NO;
                    ELSE
                        MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := NULL;
                        MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := NULL;
                        MJIDO_WORK(ICNT).ZOKUGARAMEI1 := NULL;
                        MJIDO_WORK(ICNT).ZOKUGARAMEI2 :=  NULL;
                        DBMS_OUTPUT.PUT_LINE('該当保護者なし   '||RG.HOGOSYA_KOJIN_NO||' '||KOJIN_NO);
                    END IF;
                         MJIDO_WORK(ICNT).SHORIBI := RG.SHORIBI;
                         MJIDO_WORK(ICNT).GAKUNEN_CD := RG.GAKUNEN;

                         IF RG.SYOGAKO_CD <> 0 AND
                            RG.SYOGAKO_TENGAKU_BI = 0 AND
                            RG.SYOGAKO_SOTSUGYO_BI = 0 THEN
                             MJIDO_WORK(ICNT).TENNYUGAKU_BI := RG.SYOGAKO_TENNYUGAKU_BI;
                             MJIDO_WORK(ICNT).TENNYUGAKU_GAKUNEN := RG.SYOGAKO_TENNYUGAKU_GAKUNEN;
                             MJIDO_WORK(ICNT).TENGAKU_BI := RG.SYOGAKO_TENGAKU_BI;
                             MJIDO_WORK(ICNT).TENGAKU_GAKUNEN := RG.SYOGAKO_TENGAKU_GAKUNEN;
                             MJIDO_WORK(ICNT).TAIGAKU_BI := NULL;
                             MJIDO_WORK(ICNT).TAIGAKU_GAKUNEN := NULL;
                             MJIDO_WORK(ICNT).SOTSUGYO_BI :=  RG.SYOGAKO_SOTSUGYO_BI;
                             MJIDO_WORK(ICNT).GAKO_KBN :=  1;
                             MJIDO_WORK(ICNT).GAKO_CD :=  RG.SYOGAKO_CD;
                       BEGIN
                         SELECT SYOGAKO_CD,
                                SYOGAKOMEI
                           INTO IGAKO_CD,
                                VGAKOMEI
                           FROM GKBTSHOGAKKO
                           WHERE SYOGAKO_CD = RG.SYOGAKO_CD;
                       EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                             DBMS_OUTPUT.PUT_LINE('該当小学校なし   '||RG.SYOGAKO_CD||' '||KOJIN_NO);
                             IGAKO_CD := RG.SYOGAKO_CD;
                             VGAKOMEI := ' ';
                       END;
                       ELSIF
                          RG.TYUGAKO_CD <> 0 AND
                          RG.TYUGAKO_TENGAKU_BI = 0 AND
                          RG.TYUGAKO_SOTSUGYO_BI = 0 THEN
                             MJIDO_WORK(ICNT).TENNYUGAKU_BI := RG.TYUGAKO_TENNYUGAKU_BI;
                             MJIDO_WORK(ICNT).TENNYUGAKU_GAKUNEN := RG.TYUGAKO_TENNYUGAKU_GAKUNEN;
                             MJIDO_WORK(ICNT).TENGAKU_BI := RG.TYUGAKO_TENGAKU_BI;
                             MJIDO_WORK(ICNT).TENGAKU_GAKUNEN := RG.TYUGAKO_TENGAKU_GAKUNEN;
                             MJIDO_WORK(ICNT).TAIGAKU_BI := NULL;
                             MJIDO_WORK(ICNT).TAIGAKU_GAKUNEN := NULL;
                             MJIDO_WORK(ICNT).SOTSUGYO_BI :=  RG.TYUGAKO_SOTSUGYO_BI;
                             MJIDO_WORK(ICNT).GAKO_KBN :=  2;
                             MJIDO_WORK(ICNT).GAKO_CD :=  RG.TYUGAKO_CD;
                       BEGIN
                         SELECT TYUGAKO_CD,
                                TYUGAKOMEI
                           INTO IGAKO_CD,
                                VGAKOMEI
                           FROM GKBTCHUGAKKO
                           WHERE TYUGAKO_CD = RG.TYUGAKO_CD;
                       EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                             DBMS_OUTPUT.PUT_LINE('該当中学校なし   '||RG.TYUGAKO_CD||' '||KOJIN_NO);
                             IGAKO_CD := RG.TYUGAKO_CD;
                             VGAKOMEI := ' ';
                       END;
                       ELSIF
                         RG.KUIKIGAI_CD <> 0 AND
                         RG.KUIKIGAI_TENGAKU_BI = 0 AND
                         RG.KUIKIGAI_TAIGAKU_BI = 0 AND
                         RG.KUIKIGAI_SOTSUGYO_BI = 0 THEN
                             MJIDO_WORK(ICNT).TENNYUGAKU_BI := RG.KUIKIGAI_TENNYUGAKU_BI;
                             MJIDO_WORK(ICNT).TENNYUGAKU_GAKUNEN := RG.KUIKIGAI_TENNYUGAKU_GAKUNEN;
                             MJIDO_WORK(ICNT).TENGAKU_BI := RG.KUIKIGAI_TENGAKU_BI;
                             MJIDO_WORK(ICNT).TENGAKU_GAKUNEN := RG.KUIKIGAI_TENGAKU_GAKUNEN;
                             MJIDO_WORK(ICNT).TAIGAKU_BI := RG.KUIKIGAI_TAIGAKU_BI;
                             MJIDO_WORK(ICNT).TAIGAKU_GAKUNEN := RG.KUIKIGAI_TAIGAKU_GAKUNEN;
                             MJIDO_WORK(ICNT).SOTSUGYO_BI :=  RG.KUIKIGAI_SOTSUGYO_BI;
                             MJIDO_WORK(ICNT).GAKO_KBN :=  3;
                             MJIDO_WORK(ICNT).GAKO_CD :=  RG.KUIKIGAI_CD;
                       BEGIN
                         SELECT KUIKIGAI_CD,
                                KUIKIGAIMEI
                           INTO IGAKO_CD,
                                VGAKOMEI
                           FROM GKBTKUIKIGAI
                           WHERE KUIKIGAI_CD = RG.KUIKIGAI_CD;
                       EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                             DBMS_OUTPUT.PUT_LINE('該当区域外学校なし   '||RG.KUIKIGAI_CD||' '||KOJIN_NO);
                             IGAKO_CD := RG.KUIKIGAI_CD;
                             VGAKOMEI := ' ';
                       END;
                       ELSIF
                               RG.YOGOGAKO_CD <> 0 AND
                               RG.YOGOGAKO_TENGAKU_BI = 0 AND
                               RG.YOGOGAKO_TAIGAKU_BI = 0 AND
                               RG.YOGOGAKO_SOTSUGYO_BI = 0 THEN
                             MJIDO_WORK(ICNT).TENNYUGAKU_BI := RG.YOGOGAKO_TENNYUGAKU_BI;
                             MJIDO_WORK(ICNT).TENNYUGAKU_GAKUNEN := RG.YOGOGAKO_TENNYUGAKU_GAKUNEN;
                             MJIDO_WORK(ICNT).TENGAKU_BI := RG.YOGOGAKO_TENGAKU_BI;
                             MJIDO_WORK(ICNT).TENGAKU_GAKUNEN := RG.YOGOGAKO_TENGAKU_GAKUNEN;
                             MJIDO_WORK(ICNT).TAIGAKU_BI := RG.YOGOGAKO_TAIGAKU_BI;
                             MJIDO_WORK(ICNT).TAIGAKU_GAKUNEN := RG.YOGOGAKO_TAIGAKU_GAKUNEN;
                             MJIDO_WORK(ICNT).SOTSUGYO_BI :=  RG.YOGOGAKO_SOTSUGYO_BI;
                             MJIDO_WORK(ICNT).GAKO_KBN :=  4;
                             MJIDO_WORK(ICNT).GAKO_CD :=  RG.YOGOGAKO_CD;
                             BEGIN
                               SELECT YOGOGAKO_CD,
                                      YOGOGAKOMEI
                                 INTO IGAKO_CD,
                                      VGAKOMEI
                                 FROM GKBTYOGOGAKKO
                                 WHERE YOGOGAKO_CD = RG.YOGOGAKO_CD;
                             EXCEPTION
                                 WHEN NO_DATA_FOUND THEN
                                   DBMS_OUTPUT.PUT_LINE('該当盲聾養護学校なし   '||RG.YOGOGAKO_CD||' '||KOJIN_NO);
                                   IGAKO_CD := RG.YOGOGAKO_CD;
                                   VGAKOMEI := ' ';
                             END;
                        ELSE
                             MJIDO_WORK(ICNT).TENNYUGAKU_BI := NULL;
                             MJIDO_WORK(ICNT).TENNYUGAKU_GAKUNEN := NULL;
                             MJIDO_WORK(ICNT).TENGAKU_BI := NULL;
                             MJIDO_WORK(ICNT).TENGAKU_GAKUNEN := NULL;
                             MJIDO_WORK(ICNT).TAIGAKU_BI := NULL;
                             MJIDO_WORK(ICNT).TAIGAKU_GAKUNEN := NULL;
                             MJIDO_WORK(ICNT).SOTSUGYO_BI :=  0;
                             MJIDO_WORK(ICNT).GAKO_KBN :=  NULL;
                             IGAKO_CD := NULL;
                             VGAKOMEI := NULL;
                        END IF;
                            MJIDO_WORK(ICNT).GAKO_CD := IGAKO_CD;
-- 2024/07/02 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発
--                             MJIDO_WORK(ICNT).GAKOMEI := VGAKOMEI;
                            MJIDO_WORK(ICNT).GYOSEIKU_CD := RJIDO_ATENA.GYOSEIKU_CD;
                            MJIDO_WORK(ICNT).GYOSEIKUMEI := GAAPK0030.FGYOSEIKUMEI(RJIDO_ATENA.SANTEIDANTAI_CD,RJIDO_ATENA.GYOSEIKU_CD);    -- 行政区名
                            MJIDO_WORK(ICNT).HAN_CD := RJIDO_ATENA.HAN_CD;
                            MJIDO_WORK(ICNT).HANMEI := GAAPK0030.FHANMEI(RJIDO_ATENA.SANTEIDANTAI_CD, RJIDO_ATENA.HAN_CD);                  -- 班名
                            MJIDO_WORK(ICNT).SANTEIDANTAI_CD := RJIDO_ATENA.SANTEIDANTAI_CD;
                            I_RTN := GAAPK0030.FJICHINAME(RJIDO_ATENA.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);
                            MJIDO_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;                                           -- 旧自治体名

                        IF RJIDO_SOFU.KOJIN_NO IS NOT NULL AND
                           (RJIDO_SOFU.TEKIYO_BI <= MJIDO_WORK(ICNT).SHORIBI) AND
                           (RJIDO_SOFU.SHURYO_BI >= MJIDO_WORK(ICNT).SHORIBI OR
                            RJIDO_SOFU.SHURYO_BI = 0) THEN
                              MJIDO_WORK(ICNT).JIDO_YUBIN_NO := RJIDO_SOFU.YUBIN_NO;
                              MJIDO_WORK(ICNT).JIDO_CHOMEI := RJIDO_SOFU.CHOMEI;
                              MJIDO_WORK(ICNT).JIDO_BANCHI := RJIDO_SOFU.BANCHI;
                              MJIDO_WORK(ICNT).JIDO_KATAGAKI := RJIDO_SOFU.KATAGAKI;
                        ELSE
                              MJIDO_WORK(ICNT).JIDO_YUBIN_NO := RJIDO_ATENA.YUBIN_NO;
                              MJIDO_WORK(ICNT).JIDO_CHOMEI := RJIDO_ATENA.CHOMEI;
                              MJIDO_WORK(ICNT).JIDO_BANCHI := RJIDO_ATENA.BANCHI;
                              MJIDO_WORK(ICNT).JIDO_KATAGAKI := RJIDO_ATENA.KATAGAKI;
                        END IF;

                        IF RHOGO_SOFU.KOJIN_NO IS NOT NULL AND
                             (RHOGO_SOFU.TEKIYO_BI <= MJIDO_WORK(ICNT).SHORIBI) AND
                             (RHOGO_SOFU.SHURYO_BI >= MJIDO_WORK(ICNT).SHORIBI OR
                              RHOGO_SOFU.SHURYO_BI = 0) THEN
                             MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO := RHOGO_SOFU.YUBIN_NO;
                             MJIDO_WORK(ICNT).HOGOSHA_CHOMEI := RHOGO_SOFU.CHOMEI;
                             MJIDO_WORK(ICNT).HOGOSHA_BANCHI := RHOGO_SOFU.BANCHI;
                             MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI := RHOGO_SOFU.KATAGAKI;
                        ELSE
                             MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO := RHOGO_ATENA.YUBIN_NO;
                             MJIDO_WORK(ICNT).HOGOSHA_CHOMEI := RHOGO_ATENA.CHOMEI;
                             MJIDO_WORK(ICNT).HOGOSHA_BANCHI := RHOGO_ATENA.BANCHI;
                             MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI := RHOGO_ATENA.KATAGAKI;
                        END IF;

                        MJIDO_WORK(ICNT).SHUGAKU_ZYOKYO := RG.SHUGAKU;
                        MJIDO_WORK(ICNT).IDO_JIKO := RG.IDOJIKO;
                        ISEIREKIHIZUKE := TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));
                        IWAREKIHIZUKE := NULL;
                        BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                                   VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                                   VEDIT_GYYMMDD3, VKJ_GENGO,
                                                   VKG_GENGO,      IWAREKI_YY,
                                                   ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                                   IMM,            IDD,
                                                   IWAREKIHIZUKE,  ISEIREKIHIZUKE );
-- 2024/07/02 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--                        MJIDO_WORK(ICNT).SAKUSEIBI :=VEDIT_GYYMMDD3;
                        MJIDO_WORK(ICNT).SAKUSEIBI := KKAPK0020.FDAYEDIT20(TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), 0, 3, 0, '*');  --作成日
                        MJIDO_WORK(ICNT).SYS_SAKUSEIBI := RG.SYS_SAKUSEIBI;
                        MJIDO_WORK(ICNT).SYS_KOSHINBI := RG.SYS_KOSHINBI;
                        MJIDO_WORK(ICNT).SYS_JIKAN := RG.SYS_JIKAN;
                        MJIDO_WORK(ICNT).SYS_SHOKUINKOJIN_NO := RG.SYS_SHOKUINKOJIN_NO;
                        MJIDO_WORK(ICNT).SYS_TANMATU_NO := RG.SYS_TANMATU_NO;
-- 2024/07/02 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--                         MJIDO_WORK(ICNT).KAIPEJI_CD := '0';
--                         MJIDO_WORK(ICNT).KAIPEJI := ' ';
                        --小学校文部科学省学校コード
                        IF YOIKUIDO_WK(ICNT).GAKKO_KBN_CD = 1 THEN
                          sGAKO_CD_HENKOUGO := YOIKUIDO_WK(ICNT).SYOGAKO_CD;
                          I_RTN := GKAFKMBKKSCDGET(YOIKUIDO_WK(ICNT).GAKKO_KBN_CD,YOIKUIDO_WK(ICNT).SYOGAKO_CD,sMGAKKO_CD);
                          MJIDO_WORK(ICNT).GAKOMEI_HENKOUGO := GKAFKGKOGTEQ(1 ,YOIKUIDO_WK(ICNT).SYOGAKO_CD);    --変更後学校名
                        --中学校文部科学省学校コード
                        ELSIF YOIKUIDO_WK(ICNT).GAKKO_KBN_CD = 2 THEN
                          sGAKO_CD_HENKOUGO := YOIKUIDO_WK(ICNT).TYUGAKO_CD;
                          I_RTN := GKAFKMBKKSCDGET(YOIKUIDO_WK(ICNT).GAKKO_KBN_CD,YOIKUIDO_WK(ICNT).TYUGAKO_CD,sMGAKKO_CD);
                          MJIDO_WORK(ICNT).GAKOMEI_HENKOUGO := GKAFKGKOGTEQ(2 ,YOIKUIDO_WK(ICNT).TYUGAKO_CD);    --変更後学校名
                        --特別支援学校文部科学省学校コード
                        ELSIF YOIKUIDO_WK(ICNT).GAKKO_KBN_CD = 3 THEN
                          sGAKO_CD_HENKOUGO := YOIKUIDO_WK(ICNT).YOGOGAKO_CD;
                          I_RTN := GKAFKMBKKSCDGET(YOIKUIDO_WK(ICNT).GAKKO_KBN_CD,YOIKUIDO_WK(ICNT).YOGOGAKO_CD,sMGAKKO_CD);
                          MJIDO_WORK(ICNT).GAKOMEI_HENKOUGO := GKAFKGKOGTEQ(3 ,YOIKUIDO_WK(ICNT).YOGOGAKO_CD);    --変更後学校名
                        --区域外就学文部科学省学校コード
                        ELSIF YOIKUIDO_WK(ICNT).GAKKO_KBN_CD = 4 THEN
                          sGAKO_CD_HENKOUGO := YOIKUIDO_WK(ICNT).KUIKIGAI_CD;
                          I_RTN := GKAFKMBKKSCDGET(YOIKUIDO_WK(ICNT).GAKKO_KBN_CD,YOIKUIDO_WK(ICNT).KUIKIGAI_CD,sMGAKKO_CD);
                          MJIDO_WORK(ICNT).GAKOMEI_HENKOUGO := GKAFKGKOGTEQ(4 ,YOIKUIDO_WK(ICNT).KUIKIGAI_CD);    --変更後学校名
                        --国・私立学校文部科学省学校コード
                        ELSIF YOIKUIDO_WK(ICNT).GAKKO_KBN_CD = 5 THEN
                          sGAKO_CD_HENKOUGO := YOIKUIDO_WK(ICNT).KUNISHIRITSU_CD;
                          I_RTN := GKAFKMBKKSCDGET(YOIKUIDO_WK(ICNT).GAKKO_KBN_CD,YOIKUIDO_WK(ICNT).KUNISHIRITSU_CD,sMGAKKO_CD);
                          MJIDO_WORK(ICNT).GAKOMEI_HENKOUGO := GKAFKGKOGTEQ(5 ,YOIKUIDO_WK(ICNT).KUNISHIRITSU_CD);    --変更後学校名
                        END IF;
                        MJIDO_WORK(ICNT).GAKO_CD_HENKOUGO := sGAKO_CD_HENKOUGO;      --変更後学校コード
                        MJIDO_WORK(ICNT).GAKO_KBN_CD_HENKOUGO := YOIKUIDO_WK(ICNT).GAKKO_KBN_CD;      --変更後学校区分コード
                        BEGIN 
                          SELECT GIMUKYOIKU_GAKUNENMEI,GAKUNENMEI INTO GIMUKYOIKU_GAKUNENMEI,GAKUNENMEI FROM GKBTGAKUNEN WHERE YOIKUIDO_WK(ICNT).GAKUNEN = GAKUNEN_CD;
                        EXCEPTION
                          WHEN OTHERS THEN
                            GIMUKYOIKU_GAKUNENMEI := NULL;
                            GAKUNENMEI := NULL;
                        END;
                        IF SUBSTR(sMGAKKO_CD,1,2) = 'C2' THEN
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00693対応 START
--                          MJIDO_WORK(ICNT).GAKUNEN := GIMUKYOIKU_GAKUNENMEI || '年生';            --変更後学年
                          MJIDO_WORK(ICNT).GAKUNEN := GIMUKYOIKU_GAKUNENMEI;            --変更後学年
                        ELSE
--                          MJIDO_WORK(ICNT).GAKUNEN := GAKUNENMEI || '年生';                       --変更後学年
                          MJIDO_WORK(ICNT).GAKUNEN := GAKUNENMEI;                       --変更後学年
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00693対応 END
                        END IF;
                        IF g_vJYOUKEN09 = 1 THEN
                           MJIDO_WORK(ICNT).KAIPEJI_CD := LPAD(MJIDO_WORK(ICNTM).GAKO_KBN,1,0) || LPAD(MJIDO_WORK(ICNTM).GAKO_CD,5,0);  --改ページコード
                           MJIDO_WORK(ICNT).KAIPEJI    :=  MJIDO_WORK(ICNT).GAKOMEI;    --改ページ
                        ELSIF g_vJYOUKEN09 = 2 THEN 
                           MJIDO_WORK(ICNT).KAIPEJI_CD := LPAD(MJIDO_WORK(ICNTM).GAKO_KBN_CD_HENKOUGO,1,0) || LPAD(MJIDO_WORK(ICNTM).GAKO_CD_HENKOUGO,5,0); --改ページコード
                           MJIDO_WORK(ICNT).KAIPEJI    := MJIDO_WORK(ICNT).GAKOMEI_HENKOUGO ;    --改ページ
                        END IF;
                        MJIDO_WORK(ICNT).KAISIIDOBI := KKAPK0020.FDAYEDIT20(ISTART, 0, 3, 0, '*');  --抽出開始異動日
                        MJIDO_WORK(ICNT).SYURYOIDOBI := KKAPK0020.FDAYEDIT20(IEND, 0, 3, 0, '*');  --抽出終了異動日
                        MJIDO_WORK(ICNT).HENKO_BI := KKAPK0020.FDAYEDIT20(YOIKUIDO_WK(ICNT).GRB_HENKO_BI, 0, 3, 0, '*');  --学齢簿変更年月日
                        MJIDO_WORK(ICNT).HENKO_TODOKEDE_BI := KKAPK0020.FDAYEDIT20(YOIKUIDO_WK(ICNT).GRB_HENKO_TODOKEDE_BI, 0, 3, 0, '*');  --学齢簿変更届出年月日
                        I_RTN := KKAPK0030.FCDGetR('GKB', '026', '0001', YOIKUIDO_WK(ICNT).GRB_HENKO_JIYU ,o_sMEISHO ,o_sMEISHOKANA ,o_sYOBI );
--  2025/01/27 JPJYS.LIZIZHONG Update 0.3.000.008 ST_GKB_TMP00016 障害対応 START                        
                        MJIDO_WORK(ICNT).HENKO_JIYU := o_sMEISHO;                                      --学齢簿変更事由
--                      MJIDO_WORK(ICNT).HENKO_JIYU := o_sYOBI;                                      --学齢簿変更事由
--  2025/01/27 JPJYS.LIZIZHONG Update 0.3.000.008 ST_GKB_TMP00016 障害対応 END   
                        MJIDO_WORK(ICNT).SHIMEI_KANA := YOIKUIDO_WK(ICNT).GJ_SHIMEI_KANA;            --変更後児童氏名カナ
                        MJIDO_WORK(ICNT).SHIMEI_KANJI := YOIKUIDO_WK(ICNT).GJ_SHIMEI_KANJI;          --変更後児童氏名漢字
                        MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA_HENKOUGO := YOIKUIDO_WK(ICNT).GH_SHIMEI_KANA;          --変更後保護者氏名カナ
                        MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI_HENKOUGO := YOIKUIDO_WK(ICNT).GH_SHIMEI_KANJI;        --変更後保護者氏名漢字
                        MJIDO_WORK(ICNT).SEINENGAPI_HENKOUGO := KKAPK0020.FDAYEDIT20(YOIKUIDO_WK(ICNT).GJ_SEINENGAPI, 0, 3, 0, '*');     --変更後生年月日
                        I_RTN := KKAPK0030.FCDGetR('GKB', '021', '0001', YOIKUIDO_WK(ICNT).GJ_SEIBETSU , o_sMEISHO, o_sMEISHOKANA, o_sYOBI);
                        MJIDO_WORK(ICNT).SEIBETSU_HENKOUGO := o_sMEISHO;                                               --性別
                        IRTNZOKUGARA2 := GKBFKZKGMGET(2,
                                                      YOIKUIDO_WK(ICNT).HOGOSYA_ZOKUGARA1,
                                                      YOIKUIDO_WK(ICNT).HOGOSYA_ZOKUGARA2,
                                                      YOIKUIDO_WK(ICNT).HOGOSYA_ZOKUGARA3,
                                                      YOIKUIDO_WK(ICNT).HOGOSYA_ZOKUGARA4,
                                                      VZOKUGARAMEI2,
                                                      IRTNZOKUGARAHERR2);
                        MJIDO_WORK(ICNT).JIDO_KANKEI := VZOKUGARAMEI2;            --変更後児童生徒との関係
                        I_RTN := GKAFKKKMGET(YOIKUIDO_WK(ICNT).GJ_KOKUSEKI_CD ,o_kOKUMEKANA , o_kOKUME , o_kOKUMEEG); 
                        MJIDO_WORK(ICNT).JIDO_KOKUSEKI := o_kOKUME;               --変更後児童生徒国籍
                        I_RTN := GKAFKKKMGET(YOIKUIDO_WK(ICNT).GH_KOKUSEKI_CD ,o_kOKUMEKANA , o_kOKUME , o_kOKUMEEG);
                        MJIDO_WORK(ICNT).HOGOSYA_KOKUSEKI := o_kOKUME;            --変更後保護者国籍
                        MJIDO_WORK(ICNT).NUSHI_SHIMEI_KANJI_HENKOUGO := YOIKUIDO_WK(ICNT).GJ_NUSHI_SHIMEI_KANJI;            --変更後世帯主氏名
                        --変更後児童生徒住所
                        MJIDO_WORK(ICNT).JIDOJUSHO := GAAPK0010.FADDRESSEDIT(1,NULL,YOIKUIDO_WK(ICNT).GJ_CHOMEI,YOIKUIDO_WK(ICNT).GJ_BANCHI,YOIKUIDO_WK(ICNT).GJ_KATAGAKI,NULL);
--  2024/11/11 ZCZL.WANGMING Update 0.3.000.005:IT_GKB_00266対応
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00665対応 START
                        MJIDO_WORK(ICNT).BIKO := YOIKUIDO_WK(ICNT).BIKO;         --備考
--                        MJIDO_WORK(ICNT).BIKO := TO_CLOB(YOIKUIDO_WK(ICNT).BIKO);         --備考
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00665対応 END
                        MJIDO_WORK(ICNT).HENKO_TODOKEDE_BI_KAISHI := KKAPK0020.FDAYEDIT20(g_vJYOUKEN05, 0, 3, 0, '*');
                        MJIDO_WORK(ICNT).HENKO_TODOKEDE_BI_SHURYO := KKAPK0020.FDAYEDIT20(g_vJYOUKEN06, 0, 3, 0, '*');
                        MJIDO_WORK(ICNT).HENKO_BI_KAISHI := KKAPK0020.FDAYEDIT20(g_vJYOUKEN07, 0, 3, 0, '*');
                        MJIDO_WORK(ICNT).HENKO_BI_SHURYO := KKAPK0020.FDAYEDIT20(g_vJYOUKEN08, 0, 3, 0, '*');
-- 2024/07/02 ZCZL.wangqiwei Update end
                        I_RTN := GAAPK0030.FGETATENA(KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), o_RATENA_REC, o_RSOFU_REC);
                        MJIDO_WORK(ICNT).JINKAKU_KBN := o_RATENA_REC.JINKAKU_KBN;
                        ICNT := ICNT + 1;               -- カウントアップ
                        IFRET := c_ISUCCESS;              -- 正常終了
               END LOOP;
            CLOSE CRATENA;
        EXCEPTION
            WHEN OTHERS THEN
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD START 0.3.000.002:8月1日認識合わせの横展開
                IF CRATENA%ISOPEN THEN
                    CLOSE CRATENA;
                END IF;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        -- その他エラー
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_GET_WK;

    --------------------------------------------------------
    --  機能概要      : 教育異動者一覧ワーク（GKBWKYOIKUIDO）テーブルの作成
    --  パラメータ      : なし
    --  モジュール区分  : 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン      : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_INSERT_WK RETURN NUMBER IS
    IFRET               PLS_INTEGER;                -- 戻り値
    ICNT                BINARY_INTEGER;             -- 戻り値
    IMAX                BINARY_INTEGER;             -- 戻り値
    IMIN                BINARY_INTEGER;             -- 戻り値

    BEGIN
        IFRET := c_ISUCCESS;                  -- 正常終了

--         ワーク領域の最終位置を取得
        IMAX := MJIDO_WORK.LAST;
--         ワーク領域の先頭位置を取得
        IMIN := MJIDO_WORK.FIRST;
        BEGIN
--             ワーク領域の件数分繰り返し処理を行う
            FOR ICNT IN IMIN..IMAX LOOP
                INSERT INTO
                GKBWKYOIKUIDO
                (
                 JIDO_KOJIN_NO,
                 JIDO_SHIMEI_KANA,
                 JIDO_SHIMEI_KANJI,
                 SEINENGAPI,
                 HYOJI_SEINENGAPI,
                 SEIBETSU,
                 HYOJI_SEIBETSU,
                 ZOKUGARAMEI1,
                 SETAI_NO,
                 HYOJI_SETAI_NO,
                 HOGOSHA_KOJIN_NO,
                 HOGOSHA_SHIMEI_KANA,
                 HOGOSHA_SHIMEI_KANJI,
                 ZOKUGARAMEI2,
                 SHORIBI,
                 TENNYUGAKU_BI,
                 TENNYUGAKU_GAKUNEN,
                 TENGAKU_BI,
                 TENGAKU_GAKUNEN,
                 TAIGAKU_BI,
                 TAIGAKU_GAKUNEN,
                 SOTSUGYO_BI,
                 GAKUNEN_CD,
                 GAKO_KBN,
                 GAKO_CD,
                 GAKOMEI,
                 GYOSEIKU_CD,
                 GYOSEIKUMEI,
                 HAN_CD,
                 HANMEI,
                 SANTEIDANTAI_CD,
                 SANTEIDANTAIMEI,
                 JIDO_YUBIN_NO,
                 JIDO_CHOMEI,
                 JIDO_BANCHI,
                 JIDO_KATAGAKI,
                 HOGOSHA_YUBIN_NO,
                 HOGOSHA_CHOMEI,
                 HOGOSHA_BANCHI,
                 HOGOSHA_KATAGAKI,
                 SHUGAKU_ZYOKYO,
                 IDO_JIKO,
                 SAKUSEIBI,
                 SYS_SAKUSEIBI,
                 SYS_KOSHINBI,
                 SYS_JIKAN,
                 SYS_SHOKUINKOJIN_NO,
                 SYS_TANMATU_NO,
                 KAIPEJI_CD,
                 KAIPEJI,
                 JINKAKU_KBN
-- 2024/06/24 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 ,KAISIIDOBI,
                 SYURYOIDOBI,
                 MAE_JIDOJUSHO,
                 MAE_JIDO_KOKUSEKI,
                 MAE_HOGOSYA_KOKUSEKI,
                 MAE_NUSHI_SHIMEI_KANJI,
                 HENKO_BI,
                 HENKO_TODOKEDE_BI,
                 HENKO_JIYU,
                 MAE_GAKUNEN,
                 SHIMEI_KANA,
                 SHIMEI_KANJI,
                 HOGOSHA_SHIMEI_KANA_HENKOUGO,
                 HOGOSHA_SHIMEI_KANJI_HENKOUGO,
                 SEINENGAPI_HENKOUGO,
                 SEIBETSU_HENKOUGO,
                 JIDO_KANKEI,
                 JIDO_KOKUSEKI,
                 HOGOSYA_KOKUSEKI,
                 NUSHI_SHIMEI_KANJI_HENKOUGO,
                 GAKUNEN,
                 GAKO_KBN_CD_HENKOUGO,
                 GAKO_CD_HENKOUGO,
                 GAKOMEI_HENKOUGO,
                 JIDOJUSHO,
                 BIKO,
                 HENKO_TODOKEDE_BI_KAISHI,
                 HENKO_TODOKEDE_BI_SHURYO,
                 HENKO_BI_KAISHI,
                 HENKO_BI_SHURYO
-- 2024/06/24 ZCZL.wangqiwei Add end
                )
                VALUES 
                (
                 MJIDO_WORK(ICNT).JIDO_KOJIN_NO,
                 MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA,
                 MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI,
                 MJIDO_WORK(ICNT).SEINENGAPI ,
                 MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,
                 MJIDO_WORK(ICNT).SEIBETSU,
                 MJIDO_WORK(ICNT).HYOJI_SEIBETSU,
                 MJIDO_WORK(ICNT).ZOKUGARAMEI1,
                 MJIDO_WORK(ICNT).SETAI_NO,
                 MJIDO_WORK(ICNT).HYOJI_SETAI_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI,
                 MJIDO_WORK(ICNT).ZOKUGARAMEI2,
                 MJIDO_WORK(ICNT).SHORIBI,
                 MJIDO_WORK(ICNT).TENNYUGAKU_BI,
                 MJIDO_WORK(ICNT).TENNYUGAKU_GAKUNEN,
                 MJIDO_WORK(ICNT).TENGAKU_BI,
                 MJIDO_WORK(ICNT).TENGAKU_GAKUNEN,
                 MJIDO_WORK(ICNT).TAIGAKU_BI,
                 MJIDO_WORK(ICNT).TAIGAKU_GAKUNEN,
                 MJIDO_WORK(ICNT).SOTSUGYO_BI,
                 MJIDO_WORK(ICNT).GAKUNEN_CD,
                 MJIDO_WORK(ICNT).GAKO_KBN,
                 MJIDO_WORK(ICNT).GAKO_CD,
                 MJIDO_WORK(ICNT).GAKOMEI,
                 MJIDO_WORK(ICNT).GYOSEIKU_CD,
                 MJIDO_WORK(ICNT).GYOSEIKUMEI,
                 MJIDO_WORK(ICNT).HAN_CD,
                 MJIDO_WORK(ICNT).HANMEI,
                 MJIDO_WORK(ICNT).SANTEIDANTAI_CD,
                 MJIDO_WORK(ICNT).SANTEIDANTAIMEI,
                 MJIDO_WORK(ICNT).JIDO_YUBIN_NO,
                 MJIDO_WORK(ICNT).JIDO_CHOMEI,
                 MJIDO_WORK(ICNT).JIDO_BANCHI,
                 MJIDO_WORK(ICNT).JIDO_KATAGAKI,
                 MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_CHOMEI,
                 MJIDO_WORK(ICNT).HOGOSHA_BANCHI,
                 MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI,
                 MJIDO_WORK(ICNT).SHUGAKU_ZYOKYO,
                 MJIDO_WORK(ICNT).IDO_JIKO,
                 MJIDO_WORK(ICNT).SAKUSEIBI,
                 MJIDO_WORK(ICNT).SYS_SAKUSEIBI,
                 MJIDO_WORK(ICNT).SYS_KOSHINBI,
                 MJIDO_WORK(ICNT).SYS_JIKAN,
                 MJIDO_WORK(ICNT).SYS_SHOKUINKOJIN_NO,
                 MJIDO_WORK(ICNT).SYS_TANMATU_NO,
                 MJIDO_WORK(ICNT).KAIPEJI_CD,
                 MJIDO_WORK(ICNT).KAIPEJI,
                 MJIDO_WORK(ICNT).JINKAKU_KBN
-- 2024/06/24 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 , MJIDO_WORK(ICNT).KAISIIDOBI,
                  MJIDO_WORK(ICNT).SYURYOIDOBI,
                  MJIDO_WORK(ICNT).MAE_JIDOJUSHO,
                  MJIDO_WORK(ICNT).MAE_JIDO_KOKUSEKI,
                  MJIDO_WORK(ICNT).MAE_HOGOSYA_KOKUSEKI,
                  MJIDO_WORK(ICNT).MAE_NUSHI_SHIMEI_KANJI,
                  MJIDO_WORK(ICNT).HENKO_BI,
                  MJIDO_WORK(ICNT).HENKO_TODOKEDE_BI,
                  MJIDO_WORK(ICNT).HENKO_JIYU,
                  MJIDO_WORK(ICNT).MAE_GAKUNEN,
                  MJIDO_WORK(ICNT).SHIMEI_KANA,
                  MJIDO_WORK(ICNT).SHIMEI_KANJI,
                  MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA_HENKOUGO,
                  MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI_HENKOUGO,
                  MJIDO_WORK(ICNT).SEINENGAPI_HENKOUGO,
                  MJIDO_WORK(ICNT).SEIBETSU_HENKOUGO,
                  MJIDO_WORK(ICNT).JIDO_KANKEI,
                  MJIDO_WORK(ICNT).JIDO_KOKUSEKI,
                  MJIDO_WORK(ICNT).HOGOSYA_KOKUSEKI,
                  MJIDO_WORK(ICNT).NUSHI_SHIMEI_KANJI_HENKOUGO,
                  MJIDO_WORK(ICNT).GAKUNEN,
                  MJIDO_WORK(ICNT).GAKO_KBN_CD_HENKOUGO,
                  MJIDO_WORK(ICNT).GAKO_CD_HENKOUGO,
                  MJIDO_WORK(ICNT).GAKOMEI_HENKOUGO,
                  MJIDO_WORK(ICNT).JIDOJUSHO,
                  MJIDO_WORK(ICNT).BIKO,
                  MJIDO_WORK(ICNT).HENKO_TODOKEDE_BI_KAISHI,
                  MJIDO_WORK(ICNT).HENKO_TODOKEDE_BI_SHURYO,
                  MJIDO_WORK(ICNT).HENKO_BI_KAISHI,
                  MJIDO_WORK(ICNT).HENKO_BI_SHURYO
-- 2024/06/24 ZCZL.wangqiwei Add end
                 );
            END LOOP;
            commit;

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;       -- 処理前に戻す

               IFRET := c_INOT_SUCCESS;      -- 異常終了
--                 SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
--                 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
--         終了
        RETURN IFRET;
    EXCEPTION
--     その他エラー
        WHEN OTHERS THEN
            ROLLBACK;       -- 処理前に戻す
           IFRET := c_INOT_SUCCESS;      -- 異常終了
--             SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
--             処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_INSERT_WK;

    --------------------------------------------------------
    --  機能概要      : 宛名ラベル中間データ作成（ＣＳＶ用)
    --  パラメータ      : なし
    --  モジュール区分  : 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン      : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNCGET_WK_KYOIKUIDO_CSV RETURN NUMBER IS
        IFRET               PLS_INTEGER;                   -- 戻り値
        ICNT                BINARY_INTEGER;                -- カウント
        VSQL                NVARCHAR2(10000);              -- ＳＱＬ文
        VSQLSEL             NVARCHAR2(9000);               -- ＳＱＬのソート以外
        VSQLORDER           NVARCHAR2(1000);               -- ＳＱＬの［ORDER BY］句
        ICUR                PLS_INTEGER;                   -- カーソル
        RREC                GKBWKYOIKUIDO%ROWTYPE;         -- 宛名中間レコード変数
        NROWS               NUMBER;                        --
        IPAGECNT            PLS_INTEGER;                   -- 頁数
        IGYOCNT             PLS_INTEGER;                   -- 行番号
        IGYORENBAN          PLS_INTEGER;                   -- 行連番
        VPAGENAME           NVARCHAR2(1000);               -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(1000);               -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(1000);               -- 改頁項目値のワーク
-- 2024/07/02 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
        TYPE TYPECURSOR  IS REF CURSOR;
        CRATENA2              TYPECURSOR;
-- 2024/07/02 ZCZL.wangqiwei Add end
    BEGIN

        IFRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IPAGECNT := 0;
        IGYOCNT := 0;
        ICNT := 0;
        IGYORENBAN := 0;
        MJIDO_WORK.DELETE;                   -- ワーク領域の初期化

        IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
          VSQLORDER := ' ORDER BY ' || g_rJSTP.Orderbyclause;
        END IF;
        
        VPAGEFD := 'SYS_KOSHINBI';
        VPAGENM := 'SYS_KOSHINBI';

        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
-- 2024/06/11 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--             VSQLSEL := VSQLSEL || 'SYS_KOSHINBI, ';
--             VSQLSEL := VSQLSEL || 'SYS_JIKAN, ';
--             VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
--             VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
--             VSQLSEL := VSQLSEL || 'SEIBETSU, ';
--             VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
--             VSQLSEL := VSQLSEL || 'GAKO_KBN, ';
--             VSQLSEL := VSQLSEL || 'GAKO_CD, ';
--             VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
--             VSQLSEL := VSQLSEL || 'HAN_CD, ';
--             VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
--             VSQLSEL := VSQLSEL ||  VPAGEFD || ' PAGE_FIELD, ';     -- 改頁値を設定
--             VSQLSEL := VSQLSEL ||  VPAGENM || ' PAGE_NAME, ';      -- 改頁名を設定
--             VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
--             VSQLSEL := VSQLSEL || 'KAIPEJI, ';
--             VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
--             VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
--             VSQLSEL := VSQLSEL || 'JIDO_KOJIN_NO, ';
--             VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANJI, ';
--             VSQLSEL := VSQLSEL || 'HOGOSHA_KOJIN_NO, ';
--             VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
--             VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
--             VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1, ';
--             VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
--             VSQLSEL := VSQLSEL || 'SHORIBI, ';
--             VSQLSEL := VSQLSEL || 'GAKOMEI, ';
--             VSQLSEL := VSQLSEL || 'TENNYUGAKU_BI, ';
--             VSQLSEL := VSQLSEL || 'TENNYUGAKU_GAKUNEN, ';
--             VSQLSEL := VSQLSEL || 'TENGAKU_BI, ';
--             VSQLSEL := VSQLSEL || 'TENGAKU_GAKUNEN,';
--             VSQLSEL := VSQLSEL || 'TAIGAKU_BI, ';
--             VSQLSEL := VSQLSEL || 'TAIGAKU_GAKUNEN, ';
--             VSQLSEL := VSQLSEL || 'SOTSUGYO_BI, ';
--             VSQLSEL := VSQLSEL || 'HOGOSHA_YUBIN_NO, ';
--             VSQLSEL := VSQLSEL || 'HOGOSHA_CHOMEI, ';
--             VSQLSEL := VSQLSEL || 'HOGOSHA_BANCHI, ';
--             VSQLSEL := VSQLSEL || 'HOGOSHA_KATAGAKI, ';
--             VSQLSEL := VSQLSEL || 'JIDO_YUBIN_NO, ';
--             VSQLSEL := VSQLSEL || 'JIDO_CHOMEI, ';
--             VSQLSEL := VSQLSEL || 'JIDO_BANCHI, ';
--             VSQLSEL := VSQLSEL || 'JIDO_KATAGAKI, ';
--             VSQLSEL := VSQLSEL || 'SHUGAKU_ZYOKYO, ';
--             VSQLSEL := VSQLSEL || 'IDO_JIKO ';
--             VSQLSEL := VSQLSEL || ',JINKAKU_KBN ';
            VSQLSEL := VSQLSEL || ' * ';
-- 2024/06/11 ZCZL.wangqiwei Update end
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWKYOIKUIDO ';
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;

-- 2024/07/02 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
            -- カーソルのオープン
--             ICUR := DBMS_SQL.OPEN_CURSOR;
--            --ＳＱＬ文の解析
--             DBMS_SQL.PARSE(ICUR, VSQL, DBMS_SQL.NATIVE);
--            --取得する列の定義
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  1, RREC.SYS_KOSHINBI);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  2, RREC.SYS_JIKAN);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  3, RREC.JIDO_SHIMEI_KANA,100);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  4, RREC.SEINENGAPI);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  5, RREC.SEIBETSU);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  6, RREC.HOGOSHA_SHIMEI_KANA,100);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  7, RREC.GAKO_KBN);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  8, RREC.GAKO_CD);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  9, RREC.GYOSEIKU_CD);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  10, RREC.HAN_CD);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  11, RREC.SANTEIDANTAI_CD);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  12, VPAGEFD, 500);        -- 改頁値を設定
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  13, VPAGENM, 500);        -- 改頁名を設定
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  14, RREC.KAIPEJI_CD,500);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  15, RREC.KAIPEJI,500);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  16, RREC.SAKUSEIBI,30);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  17, RREC.JIDO_SHIMEI_KANJI,100);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  18, RREC.JIDO_KOJIN_NO);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  19, RREC.HOGOSHA_SHIMEI_KANJI,100);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  20, RREC.HOGOSHA_KOJIN_NO);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  21, RREC.HYOJI_SEINENGAPI,11);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  22, RREC.HYOJI_SEIBETSU,2);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  23, RREC.ZOKUGARAMEI1,30);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  24, RREC.ZOKUGARAMEI2,30);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  25, RREC.SHORIBI);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  26, RREC.GAKOMEI,60);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  27, RREC.TENNYUGAKU_BI);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  28, RREC.TENNYUGAKU_GAKUNEN);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  29, RREC.TENGAKU_BI);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  30, RREC.TENGAKU_GAKUNEN);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  31, RREC.TAIGAKU_BI);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  32, RREC.TAIGAKU_GAKUNEN);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  33, RREC.SOTSUGYO_BI);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  34, RREC.HOGOSHA_YUBIN_NO,10);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  35, RREC.HOGOSHA_CHOMEI,40);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  36, RREC.HOGOSHA_BANCHI,40);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  37, RREC.HOGOSHA_KATAGAKI,60);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  38, RREC.JIDO_YUBIN_NO,10);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  39, RREC.JIDO_CHOMEI,40);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  40, RREC.JIDO_BANCHI,40);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  41, RREC.JIDO_KATAGAKI,60);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  42, RREC.SHUGAKU_ZYOKYO,300);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  43, RREC.IDO_JIKO,300);
--             DBMS_SQL.DEFINE_COLUMN(ICUR,  44, RREC.JINKAKU_KBN);
--            --ＳＱＬ実行
--             NROWS := DBMS_SQL.EXECUTE(ICUR);
-- 
--             LOOP
--                --FETCH（行の取り出し）
--                 IF DBMS_SQL.FETCH_ROWS(ICUR) > 0 THEN
                    --ワーク領域へセット
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  1, MJIDO_WORK(ICNT).SYS_KOSHINBI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  2, MJIDO_WORK(ICNT).SYS_JIKAN);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  3, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  4, MJIDO_WORK(ICNT).SEINENGAPI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  5, MJIDO_WORK(ICNT).SEIBETSU);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  6, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  7, MJIDO_WORK(ICNT).GAKO_KBN);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  8, MJIDO_WORK(ICNT).GAKO_CD);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  9, MJIDO_WORK(ICNT).GYOSEIKU_CD);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  10, MJIDO_WORK(ICNT).HAN_CD);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  11, MJIDO_WORK(ICNT).SANTEIDANTAI_CD);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  12, VPAGEFIELD);      -- 改頁値を設定
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  13, VPAGENAME);       -- 改頁名を設定
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  14, MJIDO_WORK(ICNT).KAIPEJI_CD);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  15, MJIDO_WORK(ICNT).KAIPEJI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  16, MJIDO_WORK(ICNT).SAKUSEIBI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  17, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  18, MJIDO_WORK(ICNT).JIDO_KOJIN_NO);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  19, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  20, MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  21, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  22, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  23, MJIDO_WORK(ICNT).ZOKUGARAMEI1);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  24, MJIDO_WORK(ICNT).ZOKUGARAMEI2);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  25, MJIDO_WORK(ICNT).SHORIBI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  26, MJIDO_WORK(ICNT).GAKOMEI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  27, MJIDO_WORK(ICNT).TENNYUGAKU_BI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  28, MJIDO_WORK(ICNT).TENNYUGAKU_GAKUNEN);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  29, MJIDO_WORK(ICNT).TENGAKU_BI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  30, MJIDO_WORK(ICNT).TENGAKU_GAKUNEN);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  31, MJIDO_WORK(ICNT).TAIGAKU_BI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  32, MJIDO_WORK(ICNT).TAIGAKU_GAKUNEN);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  33, MJIDO_WORK(ICNT).SOTSUGYO_BI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  34, MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  35, MJIDO_WORK(ICNT).HOGOSHA_CHOMEI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  36, MJIDO_WORK(ICNT).HOGOSHA_BANCHI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  37, MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  38, MJIDO_WORK(ICNT).JIDO_YUBIN_NO);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  39, MJIDO_WORK(ICNT).JIDO_CHOMEI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  40, MJIDO_WORK(ICNT).JIDO_BANCHI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  41, MJIDO_WORK(ICNT).JIDO_KATAGAKI);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  42, MJIDO_WORK(ICNT).SHUGAKU_ZYOKYO);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  43, MJIDO_WORK(ICNT).IDO_JIKO);
--                     DBMS_SQL.COLUMN_VALUE(ICUR,  44, MJIDO_WORK(ICNT).JINKAKU_KBN);
            OPEN CRATENA2  FOR VSQL;
            LOOP
                FETCH  CRATENA2 INTO MJIDO_WORK(ICNT);
                EXIT WHEN CRATENA2%NOTFOUND;
                VPAGEFIELD := MJIDO_WORK(ICNT).SYS_KOSHINBI;
                VPAGENAME := MJIDO_WORK(ICNT).SYS_KOSHINBI;
-- 2024/07/02 ZCZL.wangqiwei Update end
                    -- 改頁の指定がある場合
                    IF VPAGEWORK = VPAGEFIELD THEN
                    -- 以前の改頁項目名と同じ
                        IGYOCNT := IGYOCNT + 1;
                        IGYORENBAN := IGYORENBAN + 1;
                        IF IGYOCNT > c_IMAXROWS THEN
                        -- １頁内の最大行数を超えた
                            IPAGECNT := IPAGECNT + 1;
                            IGYOCNT := 1;
                            VPAGEWORK := VPAGEFIELD;
                        END IF;
                    ELSE
                    -- 改頁必要
                        IPAGECNT := IPAGECNT + 1;
                        IGYOCNT := 1;
                        IGYORENBAN := 1;
                        VPAGEWORK := VPAGEFIELD;
                    END IF;

                    MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEFIELD;  -- 改頁コード
                    MJIDO_WORK(ICNT).KAIPEJI:= VPAGENAME;  -- 改頁名
-- 2024/07/02 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--                 ELSE
--                    --全件読み込み終了
--                     EXIT; 
--                 END IF;
-- 2024/07/02 ZCZL.wangqiwei Delete end
                ICNT := ICNT + 1;
            END LOOP;
-- 2024/07/02 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
        CLOSE CRATENA2;

        EXCEPTION
            WHEN OTHERS THEN
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD START 0.3.000.002:8月1日認識合わせの横展開
                IF CRATENA2%ISOPEN THEN
                    CLOSE CRATENA2;
                END IF;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                -- 処理ログの出力
                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_WK_KYOIKUIDO_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;

        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_WK_KYOIKUIDO_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCGET_WK_KYOIKUIDO_CSV;

    --------------------------------------------------------
    --  機能概要      : 教育異動者一覧レコードの作成
    --  パラメータ      : MAKYOIKUIDO_REC
    --                 MTKYOIKUIDO_REC
    --  モジュール区分  : 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン      : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_REC_KYOIKUIDO(MAKYOIKUIDO_REC OUT MTKYOIKUIDO_REC) RETURN NUMBER IS
        IFRET               NUMBER;
    BEGIN
        IFRET := 0;
        --教育異動者一覧作成レコード初期化
        MAKYOIKUIDO_REC.IDO_KAISI := '';
        MAKYOIKUIDO_REC.IDO_SYURYO := '';
        MAKYOIKUIDO_REC.SAKUSEIBI := '';
        MAKYOIKUIDO_REC.JIDO_SHIMEI_KANA := '';
        MAKYOIKUIDO_REC.JIDO_SHIMEI_KANJI := '';
        MAKYOIKUIDO_REC.HOGOSHA_SHIMEI_KANA := '';
        MAKYOIKUIDO_REC.HOGOSHA_SHIMEI_KANJI := '';
        MAKYOIKUIDO_REC.HOGOSHA_KOJIN_NO := '';
        MAKYOIKUIDO_REC.HYOJI_SEINENGAPI := '';
        MAKYOIKUIDO_REC.HYOJI_SEIBETSU := '';
        MAKYOIKUIDO_REC.ZOKUGARAMEI1 := '';
        MAKYOIKUIDO_REC.ZOKUGARAMEI2 := '';
        MAKYOIKUIDO_REC.SHORIBI := '';
        MAKYOIKUIDO_REC.GAKOMEI := '';
        MAKYOIKUIDO_REC.TENNYUGAKU_BI := '';
        MAKYOIKUIDO_REC.TENNYUGAKU_GAKUNEN := '';
        MAKYOIKUIDO_REC.TENGAKU_BI := '';
        MAKYOIKUIDO_REC.TENGAKU_GAKUNEN := '';
        MAKYOIKUIDO_REC.TAIGAKU_BI := '';
        MAKYOIKUIDO_REC.TAIGAKU_GAKUNEN := '';
        MAKYOIKUIDO_REC.SOTSUGYO_BI := '';
        MAKYOIKUIDO_REC.HOGOSHA_YUBIN_NO := '';
        MAKYOIKUIDO_REC.HOGOSHA_CHOMEI := '';
        MAKYOIKUIDO_REC.HOGOSHA_BANCHI := '';
        MAKYOIKUIDO_REC.HOGOSHA_KATAGAKI := '';
        MAKYOIKUIDO_REC.JIDO_YUBIN_NO := '';
        MAKYOIKUIDO_REC.JIDO_CHOMEI := '';
        MAKYOIKUIDO_REC.JIDO_BANCHI := '';
        MAKYOIKUIDO_REC.JIDO_KATAGAKI := '';
        MAKYOIKUIDO_REC.SHUGAKU_ZYOKYO := '';
        MAKYOIKUIDO_REC.IDO_JIKO := '';
        MAKYOIKUIDO_REC.KAIPEJI_CD := '';
        MAKYOIKUIDO_REC.KAIPEJI := '';

       ISEIREKIHIZUKE := NULL;
       IWAREKIHIZUKE  := TO_NUMBER(VKAISHI_WAREKI);
       BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                  VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                  VEDIT_GYYMMDD3, VKJ_GENGO,
                                  VKG_GENGO,      IWAREKI_YY,
                                  ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                  IMM,            IDD,
                                  IWAREKIHIZUKE,  ISEIREKIHIZUKE );
-- 2024/06/25 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--        MAKYOIKUIDO_REC.IDO_KAISI := VEDIT_GYYMMDD3;
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--       MAKYOIKUIDO_REC.IDO_KAISI := KKAPK0020.FDAYEDIT20(MJIDO_WORK(ICNTM).KAISIIDOBI, 0, 3, 0, '*');
       MAKYOIKUIDO_REC.IDO_KAISI := MJIDO_WORK(ICNTM).KAISIIDOBI;
       ISEIREKIHIZUKE := NULL;
       IWAREKIHIZUKE  := TO_NUMBER(VSHURYO_WAREKI);
       BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                  VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                  VEDIT_GYYMMDD3, VKJ_GENGO,
                                  VKG_GENGO,      IWAREKI_YY,
                                  ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                  IMM,            IDD,
                                  IWAREKIHIZUKE,  ISEIREKIHIZUKE );
-- 2024/06/25 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--         MAKYOIKUIDO_REC.IDO_SYURYO := VEDIT_GYYMMDD3;
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--        MAKYOIKUIDO_REC.IDO_SYURYO := KKAPK0020.FDAYEDIT20(MJIDO_WORK(ICNTM).SYURYOIDOBI, 0, 3, 0, '*');
        MAKYOIKUIDO_REC.IDO_SYURYO := MJIDO_WORK(ICNTM).SYURYOIDOBI;
        MAKYOIKUIDO_REC.SAKUSEIBI := MJIDO_WORK(ICNTM).SAKUSEIBI;
-- 2024/06/25 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--  2025/01/27 JPJYS.LIZIZHONG Update 0.3.000.008 ST_GKB_TMP00016 障害対応 START  
--         MAKYOIKUIDO_REC.JIDO_SHIMEI_KANA := MJIDO_WORK(ICNTM).JIDO_SHIMEI_KANA; 　
--  2025/01/27 JPJYS.LIZIZHONG Update 0.3.000.008 ST_GKB_TMP00016 障害対応 END           
        MAKYOIKUIDO_REC.JIDO_SHIMEI_KANA := MJIDO_WORK(ICNTM).SHIMEI_KANA;
-- 2024/06/25 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--         MAKYOIKUIDO_REC.JIDO_SHIMEI_KANJI := MJIDO_WORK(ICNTM).JIDO_SHIMEI_KANJI;
        MAKYOIKUIDO_REC.JIDO_SHIMEI_KANJI := MJIDO_WORK(ICNTM).SHIMEI_KANJI;
        MAKYOIKUIDO_REC.JIDO_KOJIN_NO := MJIDO_WORK(ICNTM).JIDO_KOJIN_NO;
-- 2024/06/25 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--         MAKYOIKUIDO_REC.HOGOSHA_SHIMEI_KANA := MJIDO_WORK(ICNTM).HOGOSHA_SHIMEI_KANA;
--         MAKYOIKUIDO_REC.HOGOSHA_SHIMEI_KANJI := MJIDO_WORK(ICNTM).HOGOSHA_SHIMEI_KANJI;
        MAKYOIKUIDO_REC.HOGOSHA_SHIMEI_KANA := MJIDO_WORK(ICNTM).HOGOSHA_SHIMEI_KANA_HENKOUGO;
        MAKYOIKUIDO_REC.HOGOSHA_SHIMEI_KANJI := MJIDO_WORK(ICNTM).HOGOSHA_SHIMEI_KANJI_HENKOUGO;
-- 2024/06/25 ZCZL.wangqiwei Update end 
        MAKYOIKUIDO_REC.HOGOSHA_KOJIN_NO := MJIDO_WORK(ICNTM).HOGOSHA_KOJIN_NO;
-- 2024/06/25 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--         MAKYOIKUIDO_REC.HYOJI_SEINENGAPI := MJIDO_WORK(ICNTM).HYOJI_SEINENGAPI; 
--         MAKYOIKUIDO_REC.HYOJI_SEIBETSU := MJIDO_WORK(ICNTM).HYOJI_SEIBETSU;
--  2024/09/25 ZCZL.WANGMING Update 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--        MAKYOIKUIDO_REC.HYOJI_SEINENGAPI :=  KKAPK0020.FDAYEDIT20(MJIDO_WORK(ICNTM).SEINENGAPI_HENKOUGO, 0, 3, 0, '*');
        MAKYOIKUIDO_REC.HYOJI_SEINENGAPI :=  MJIDO_WORK(ICNTM).SEINENGAPI_HENKOUGO;
        MAKYOIKUIDO_REC.HYOJI_SEIBETSU := MJIDO_WORK(ICNTM).SEIBETSU_HENKOUGO;
-- 2024/06/25 ZCZL.wangqiwei Update end 
        MAKYOIKUIDO_REC.ZOKUGARAMEI1 := MJIDO_WORK(ICNTM).ZOKUGARAMEI1;
-- 2024/06/25 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--         MAKYOIKUIDO_REC.ZOKUGARAMEI2 := MJIDO_WORK(ICNTM).ZOKUGARAMEI2;
--  2024/09/25 ZCZL.WANGMING DELETE 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--  2025/01/27 JPJYS.LIZIZHONG Update 0.3.000.008 ST_GKB_TMP00016障害対応 START    
        MAKYOIKUIDO_REC.ZOKUGARAMEI2 := MJIDO_WORK(ICNTM).ZOKUGARAMEI2;
--  2025/01/27 JPJYS.LIZIZHONG Update 0.3.000.008 ST_GKB_TMP00016障害対応 END           
-- 2024/06/25 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
        MAKYOIKUIDO_REC.JIDOJUSHO := MJIDO_WORK(ICNTM).JIDOJUSHO;
        VEDIT_GYYMMDD1 := NULL;
        IWAREKIHIZUKE  := NULL;
        ISEIREKIHIZUKE := MJIDO_WORK(ICNTM).SHORIBI;
        BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                   VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                   VEDIT_GYYMMDD3, VKJ_GENGO,
                                   VKG_GENGO,      IWAREKI_YY,
                                   ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                   IMM,            IDD,
                                   IWAREKIHIZUKE,  ISEIREKIHIZUKE );
        MAKYOIKUIDO_REC.SHORIBI := VEDIT_GYYMMDD1;
        MAKYOIKUIDO_REC.GAKOMEI := MJIDO_WORK(ICNTM).GAKOMEI;
        VEDIT_GYYMMDD1 := NULL;
        IWAREKIHIZUKE  := NULL;
        ISEIREKIHIZUKE := MJIDO_WORK(ICNTM).TENNYUGAKU_BI;
        BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                  VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                  VEDIT_GYYMMDD3, VKJ_GENGO,
                                  VKG_GENGO,      IWAREKI_YY,
                                  ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                  IMM,            IDD,
                                  IWAREKIHIZUKE,  ISEIREKIHIZUKE );
        MAKYOIKUIDO_REC.TENNYUGAKU_BI := VEDIT_GYYMMDD1;
        MAKYOIKUIDO_REC.TENNYUGAKU_GAKUNEN := MJIDO_WORK(ICNTM).TENNYUGAKU_GAKUNEN;
        VEDIT_GYYMMDD1 := NULL;
        IWAREKIHIZUKE := NULL;
        ISEIREKIHIZUKE := MJIDO_WORK(ICNTM).TENGAKU_BI;
        BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                  VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                  VEDIT_GYYMMDD3, VKJ_GENGO,
                                  VKG_GENGO,      IWAREKI_YY,
                                  ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                  IMM,            IDD,
                                  IWAREKIHIZUKE,  ISEIREKIHIZUKE );
        MAKYOIKUIDO_REC.TENGAKU_BI := VEDIT_GYYMMDD1;
        VEDIT_GYYMMDD1 := NULL;
        IWAREKIHIZUKE := NULL;
        ISEIREKIHIZUKE := MJIDO_WORK(ICNTM).TAIGAKU_BI;
        BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                  VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                  VEDIT_GYYMMDD3, VKJ_GENGO,
                                  VKG_GENGO,      IWAREKI_YY,
                                  ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                  IMM,            IDD,
                                  IWAREKIHIZUKE,  ISEIREKIHIZUKE );
        MAKYOIKUIDO_REC.TAIGAKU_BI := VEDIT_GYYMMDD1;
        MAKYOIKUIDO_REC.TENGAKU_GAKUNEN := MJIDO_WORK(ICNTM).TENGAKU_GAKUNEN;
        MAKYOIKUIDO_REC.TAIGAKU_GAKUNEN := MJIDO_WORK(ICNTM).TAIGAKU_GAKUNEN;
        VEDIT_GYYMMDD1 := NULL;
        IWAREKIHIZUKE := NULL;
        ISEIREKIHIZUKE := MJIDO_WORK(ICNTM).SOTSUGYO_BI;
        BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                  VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                  VEDIT_GYYMMDD3, VKJ_GENGO,
                                  VKG_GENGO,      IWAREKI_YY,
                                  ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                  IMM,            IDD,
                                  IWAREKIHIZUKE,  ISEIREKIHIZUKE );
        MAKYOIKUIDO_REC.SOTSUGYO_BI := VEDIT_GYYMMDD1;
        MAKYOIKUIDO_REC.HOGOSHA_YUBIN_NO := MJIDO_WORK(ICNTM).HOGOSHA_YUBIN_NO;
        MAKYOIKUIDO_REC.HOGOSHA_CHOMEI := MJIDO_WORK(ICNTM).HOGOSHA_CHOMEI;
        MAKYOIKUIDO_REC.HOGOSHA_BANCHI := MJIDO_WORK(ICNTM).HOGOSHA_BANCHI;
        MAKYOIKUIDO_REC.HOGOSHA_KATAGAKI := MJIDO_WORK(ICNTM).HOGOSHA_KATAGAKI;
        MAKYOIKUIDO_REC.JIDO_YUBIN_NO := MJIDO_WORK(ICNTM).JIDO_YUBIN_NO;
        MAKYOIKUIDO_REC.JIDO_CHOMEI := MJIDO_WORK(ICNTM).JIDO_CHOMEI;
        MAKYOIKUIDO_REC.JIDO_BANCHI := MJIDO_WORK(ICNTM).JIDO_BANCHI;
        MAKYOIKUIDO_REC.JIDO_KATAGAKI := MJIDO_WORK(ICNTM).JIDO_KATAGAKI;
        MAKYOIKUIDO_REC.SHUGAKU_ZYOKYO := MJIDO_WORK(ICNTM).SHUGAKU_ZYOKYO;
        MAKYOIKUIDO_REC.IDO_JIKO := MJIDO_WORK(ICNTM).IDO_JIKO;
-- 2024/07/15 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
        MAKYOIKUIDO_REC.KAIPEJI_CD := MJIDO_WORK(ICNTM).KAIPEJI_CD;
        MAKYOIKUIDO_REC.KAIPEJI := MJIDO_WORK(ICNTM).KAIPEJI;
-- 2024/07/15 ZCZL.wangqiwei end 
        MAKYOIKUIDO_REC.JINKAKU_KBN := MJIDO_WORK(ICNTM).JINKAKU_KBN;
-- 2024/06/25 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
--  2024/09/25 ZCZL.WANGMING Update START 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--        MAKYOIKUIDO_REC1.MAE_SHIMEI_KANA := MJIDO_WORK(ICNTM).JIDO_KOJIN_NO;
        MAKYOIKUIDO_REC1.MAE_SHIMEI_KANA := MJIDO_WORK(ICNTM).JIDO_SHIMEI_KANA;
        MAKYOIKUIDO_REC1.MAE_SHIMEI_KANJI := MJIDO_WORK(ICNTM).JIDO_SHIMEI_KANJI;
        MAKYOIKUIDO_REC1.MAE_HOGOSHA_SHIMEI_KANA := MJIDO_WORK(ICNTM).HOGOSHA_SHIMEI_KANA;
        MAKYOIKUIDO_REC1.MAE_HOGOSHA_SHIMEI_KANJI := MJIDO_WORK(ICNTM).HOGOSHA_SHIMEI_KANJI;
        MAKYOIKUIDO_REC1.MAE_SEINENGAPI := MJIDO_WORK(ICNTM).SEINENGAPI;
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00665対応 START
--        MAKYOIKUIDO_REC1.MAE_SEIBETSU := MJIDO_WORK(ICNTM).SEIBETSU;
        MAKYOIKUIDO_REC1.MAE_SEIBETSU := MJIDO_WORK(ICNTM).HYOJI_SEIBETSU;
--  2024/11/26 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00665対応 END
        MAKYOIKUIDO_REC1.MAE_JIDO_KANKEI := MJIDO_WORK(ICNTM).ZOKUGARAMEI2;
        MAKYOIKUIDO_REC1.MAE_JIDO_KOKUSEKI := MJIDO_WORK(ICNTM).MAE_JIDO_KOKUSEKI;
        MAKYOIKUIDO_REC1.MAE_HOGOSYA_KOKUSEKI := MJIDO_WORK(ICNTM).MAE_HOGOSYA_KOKUSEKI;
        MAKYOIKUIDO_REC1.MAE_GAKOMEI := MJIDO_WORK(ICNTM).GAKOMEI;
        MAKYOIKUIDO_REC1.MAE_GAKUNEN := MJIDO_WORK(ICNTM).MAE_GAKUNEN;
        MAKYOIKUIDO_REC1.MAE_JIDOJUSHO := MJIDO_WORK(ICNTM).MAE_JIDOJUSHO;
        MAKYOIKUIDO_REC1.MAE_NUSHI_SHIMEI_KANJI := MJIDO_WORK(ICNTM).MAE_NUSHI_SHIMEI_KANJI;
--  2024/09/25 ZCZL.WANGMING Update START 0.3.000.003:IT_GKB_00127、IT_GKB_00134対応
--        MAKYOIKUIDO_REC1.HENKO_TODOKEDE_BI := KKAPK0020.FDAYEDIT20(MJIDO_WORK(ICNTM).HENKO_TODOKEDE_BI, 0, 3, 0, '*');
--        MAKYOIKUIDO_REC1.HENKO_BI := KKAPK0020.FDAYEDIT20(MJIDO_WORK(ICNTM).HENKO_BI, 0, 3, 0, '*');
        MAKYOIKUIDO_REC1.HENKO_TODOKEDE_BI := MJIDO_WORK(ICNTM).HENKO_TODOKEDE_BI;
        MAKYOIKUIDO_REC1.HENKO_BI := MJIDO_WORK(ICNTM).HENKO_BI;
--  2024/09/25 ZCZL.WANGMING Update END
        MAKYOIKUIDO_REC1.JIDO_KOKUSEKI := MJIDO_WORK(ICNTM).JIDO_KOKUSEKI;
        MAKYOIKUIDO_REC1.HOGOSYA_KOKUSEKI := MJIDO_WORK(ICNTM).HOGOSYA_KOKUSEKI;
        MAKYOIKUIDO_REC1.GAKOMEI := MJIDO_WORK(ICNTM).GAKOMEI_HENKOUGO;
        MAKYOIKUIDO_REC1.GAKUNEN := MJIDO_WORK(ICNTM).GAKUNEN;
        MAKYOIKUIDO_REC1.NUSHI_SHIMEI_KANJI_HENKOUGO := MJIDO_WORK(ICNTM).NUSHI_SHIMEI_KANJI_HENKOUGO;
        MAKYOIKUIDO_REC1.HENKO_JIYU := MJIDO_WORK(ICNTM).HENKO_JIYU;
        MAKYOIKUIDO_REC1.HENKO_TODOKEDE_BI_KAISHI := MJIDO_WORK(ICNTM).HENKO_TODOKEDE_BI_KAISHI;
        MAKYOIKUIDO_REC1.HENKO_TODOKEDE_BI_SHURYO := MJIDO_WORK(ICNTM).HENKO_TODOKEDE_BI_SHURYO;
        MAKYOIKUIDO_REC1.HENKO_BI_KAISHI := MJIDO_WORK(ICNTM).HENKO_BI_KAISHI;
        MAKYOIKUIDO_REC1.HENKO_BI_SHURYO := MJIDO_WORK(ICNTM).HENKO_BI_SHURYO;
-- 2024/06/25 ZCZL.wangqiwei Add end
        ICNTM := ICNTM +1;
        IF ICNTM > IMAX THEN
          RETURN IFRET;
        END IF;
      RETURN IFRET;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN IFRET;
    END FUNC_REC_KYOIKUIDO;

    --------------------------------------------------------
    --  機能概要      : 宛名ラベルＣＳＶファイル作成
    --  パラメータ      : なし
    --  モジュール区分  : 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン      : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNCSET_WK_KYOIKUIDO_CSVFILE RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        I_RTN               PLS_INTEGER;                -- 戻り値
        IMIN                PLS_INTEGER;                -- 最小値（出力件数）
        VHOGOSHA_YUBIN_NO   NVARCHAR2(60);              -- 郵便番号編集用
        VJIDO_YUBIN_NO      NVARCHAR2(60);              -- 郵便番号編集用
        VJUSHO              NVARCHAR2(150);
        rRECODE             GKBWL340R001%ROWTYPE;
    BEGIN
        IFRET := c_ISUCCESS;               -- 正常終了
        IMAX  := MJIDO_WORK.LAST;           -- ワーク領域の件数の最大値
        IMIN  := MJIDO_WORK.FIRST;          -- ワーク領域の件数の最小値

        nCOUNT := 0;
        
        -- 取得した件数分繰り返す
        LOOP
            EXIT WHEN ICNTM > IMAX;
            I_RTN := FUNC_REC_KYOIKUIDO(MAKYOIKUIDO_REC);
            nCOUNT := nCOUNT + 1;
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
            g_nCOUNT := nCOUNT ; 
            rRECODE                                := NULL;
            rRECODE.NO                             := nCOUNT;
            rRECODE.IDO_KAISHI                     := MAKYOIKUIDO_REC.IDO_KAISI;
            rRECODE.IDO_SHURYO                     := MAKYOIKUIDO_REC.IDO_SYURYO;
            rRECODE.SAKUSEIBI                      := MAKYOIKUIDO_REC.SAKUSEIBI;
            rRECODE.JIDO_SHIMEI_KANA               := MAKYOIKUIDO_REC.JIDO_SHIMEI_KANA;
            rRECODE.JIDO_SHIMEI_KANJI              := MAKYOIKUIDO_REC.JIDO_SHIMEI_KANJI;
            rRECODE.JIDO_KOJIN_NO                  := MAKYOIKUIDO_REC.JIDO_KOJIN_NO;
            rRECODE.HOGOSHA_SHIMEI_KANA            := MAKYOIKUIDO_REC.HOGOSHA_SHIMEI_KANA;
            rRECODE.HOGOSHA_SHIMEI_KANJI           := MAKYOIKUIDO_REC.HOGOSHA_SHIMEI_KANJI;
            rRECODE.HOGOSHA_KOJIN_NO               := MAKYOIKUIDO_REC.HOGOSHA_KOJIN_NO;
            rRECODE.SEINENGAPI                     := MAKYOIKUIDO_REC.HYOJI_SEINENGAPI;
            rRECODE.SEIBETSU                       := MAKYOIKUIDO_REC.HYOJI_SEIBETSU;
            rRECODE.HOGOSHA_KANKEI                 := MAKYOIKUIDO_REC.ZOKUGARAMEI1;
            rRECODE.JIDO_ZOKUGARAMEI               := MAKYOIKUIDO_REC.ZOKUGARAMEI2;
            rRECODE.SHORIBI                        := MAKYOIKUIDO_REC.SHORIBI;
            rRECODE.GAKKO_MEI                      := MAKYOIKUIDO_REC.GAKOMEI;
            rRECODE.TENNYUGAKU_BI                  := MAKYOIKUIDO_REC.TENNYUGAKU_BI;
            IF MAKYOIKUIDO_REC.TENNYUGAKU_GAKUNEN > 0 THEN
              rRECODE.TENNYUGAKU_GAKUNEN           := MAKYOIKUIDO_REC.TENNYUGAKU_GAKUNEN;
            ELSE
              rRECODE.TENNYUGAKU_GAKUNEN           := '';
            END IF;
            rRECODE.TENGAKU_BI                     := MAKYOIKUIDO_REC.TENGAKU_BI;
            IF MAKYOIKUIDO_REC.TENGAKU_GAKUNEN > 0 THEN
              rRECODE.TENGAKU_GAKUNEN              := MAKYOIKUIDO_REC.TENGAKU_GAKUNEN;
            ELSE
              rRECODE.TENGAKU_GAKUNEN              := '';
            END IF;
            rRECODE.TAIGAKU_BI                     := MAKYOIKUIDO_REC.TAIGAKU_BI;
            IF MAKYOIKUIDO_REC.TAIGAKU_GAKUNEN > 0 THEN
              rRECODE.TAIGAKU_GAKUNEN              := MAKYOIKUIDO_REC.TAIGAKU_GAKUNEN;
            ELSE
              rRECODE.TAIGAKU_GAKUNEN              := '';
            END IF;
            rRECODE.SOTSUGYO_BI                    := MAKYOIKUIDO_REC.SOTSUGYO_BI;
            IF MAKYOIKUIDO_REC.HOGOSHA_YUBIN_NO IS NOT NULL AND LENGTH(MAKYOIKUIDO_REC.HOGOSHA_YUBIN_NO) > 3 THEN
              VHOGOSHA_YUBIN_NO := SUBSTR(MAKYOIKUIDO_REC.HOGOSHA_YUBIN_NO,1,3)||'-'||SUBSTR(MAKYOIKUIDO_REC.HOGOSHA_YUBIN_NO,4);
              rRECODE.YUBIN_NO                     := '〒' || VHOGOSHA_YUBIN_NO;
            ELSE
              rRECODE.YUBIN_NO                     := '';
            END IF;
            VJUSHO := '';
            VJUSHO := GAAPK0010.FADDRESSEDIT( 1, '',  MAKYOIKUIDO_REC.HOGOSHA_CHOMEI, MAKYOIKUIDO_REC.HOGOSHA_BANCHI, MAKYOIKUIDO_REC.HOGOSHA_KATAGAKI, '');
            rRECODE.JUSHO                          := VJUSHO;
            IF MAKYOIKUIDO_REC.JIDO_YUBIN_NO IS NOT NULL AND LENGTH(MAKYOIKUIDO_REC.JIDO_YUBIN_NO) > 3 THEN
                VJIDO_YUBIN_NO := SUBSTR(MAKYOIKUIDO_REC.JIDO_YUBIN_NO,1,3)||'-'||SUBSTR(MAKYOIKUIDO_REC.JIDO_YUBIN_NO,4);
              rRECODE.JIDO_YUBIN_NO                := '〒' || VJIDO_YUBIN_NO;
            ELSE
              rRECODE.JIDO_YUBIN_NO                := '';
            END IF;
            VJUSHO := '';
            VJUSHO := GAAPK0010.FADDRESSEDIT( 1, '',  MAKYOIKUIDO_REC.JIDO_CHOMEI, MAKYOIKUIDO_REC.JIDO_BANCHI, MAKYOIKUIDO_REC.JIDO_KATAGAKI, '');
-- 2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--             rRECODE.JIDO_JUSHO                     := VJUSHO;
            rRECODE.JIDO_JUSHO                     := MAKYOIKUIDO_REC.JIDOJUSHO;
            rRECODE.SHUGAKU                        := MAKYOIKUIDO_REC.SHUGAKU_ZYOKYO;
            rRECODE.IDO_JIKO                       := MAKYOIKUIDO_REC.IDO_JIKO;
            rRECODE.KAIPAGE_CD                     := MAKYOIKUIDO_REC.KAIPEJI_CD;
            rRECODE.KAIPAGE_MEI                    := MAKYOIKUIDO_REC.KAIPEJI;
            rRECODE.JINKAKU_KBN                    := MAKYOIKUIDO_REC.JINKAKU_KBN;
-- 2024/06/25 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
--  2025/01/27 JPJYS.LIZIZHONG Update 0.3.000.008 ST_GKB_TMP00016障害対応 START    
            rRECODE.MAE_SHIMEI_KANA                := MAKYOIKUIDO_REC1.MAE_SHIMEI_KANA;
--  2025/01/27 JPJYS.LIZIZHONG Update 0.3.000.008 ST_GKB_TMP00016障害対応 END               
            rRECODE.MAE_SHIMEI_KANJI               := MAKYOIKUIDO_REC1.MAE_SHIMEI_KANJI;
            rRECODE.MAE_HOGOSHA_SHIMEI_KANA        := MAKYOIKUIDO_REC1.MAE_HOGOSHA_SHIMEI_KANA;
            rRECODE.MAE_HOGOSHA_SHIMEI_KANJI       := MAKYOIKUIDO_REC1.MAE_HOGOSHA_SHIMEI_KANJI;
            rRECODE.MAE_SEINENGAPI                 := MAKYOIKUIDO_REC1.MAE_SEINENGAPI;
            rRECODE.MAE_SEIBETSU                   := MAKYOIKUIDO_REC1.MAE_SEIBETSU;
            rRECODE.MAE_JIDO_KANKEI                := MAKYOIKUIDO_REC1.MAE_JIDO_KANKEI;
            rRECODE.MAE_JIDO_KOKUSEKI              := MAKYOIKUIDO_REC1.MAE_JIDO_KOKUSEKI;
            rRECODE.MAE_HOGOSYA_KOKUSEKI           := MAKYOIKUIDO_REC1.MAE_HOGOSYA_KOKUSEKI;
            rRECODE.MAE_GAKOMEI                    := MAKYOIKUIDO_REC1.MAE_GAKOMEI;
--  2024/08/30 ZCZL.WANGMING Update START 0.3.000.001:IT_GKB_00075対応
--            rRECODE.MAE_GAKUNEN                    := MAKYOIKUIDO_REC1.MAE_SHIMEI_KANJI;
--            rRECODE.MAE_JIDOJUSHO                  := MAKYOIKUIDO_REC1.MAE_SHIMEI_KANJI;
--            rRECODE.MAE_NUSHI_SHIMEI_KANJI         := MAKYOIKUIDO_REC1.MAE_SHIMEI_KANJI;
--            rRECODE.HENKO_TODOKEDE_BI              := MAKYOIKUIDO_REC1.MAE_SHIMEI_KANJI;
            rRECODE.MAE_GAKUNEN                    := MAKYOIKUIDO_REC1.MAE_GAKUNEN;
            rRECODE.MAE_JIDOJUSHO                  := MAKYOIKUIDO_REC1.MAE_JIDOJUSHO;
            rRECODE.MAE_NUSHI_SHIMEI_KANJI         := MAKYOIKUIDO_REC1.MAE_NUSHI_SHIMEI_KANJI;
            rRECODE.HENKO_TODOKEDE_BI              := MAKYOIKUIDO_REC1.HENKO_TODOKEDE_BI;
--  2024/08/30 ZCZL.WANGMING Update END
            rRECODE.HENKO_BI                       := MAKYOIKUIDO_REC1.HENKO_BI;
            rRECODE.JIDO_KOKUSEKI                  := MAKYOIKUIDO_REC1.JIDO_KOKUSEKI;
            rRECODE.HOGOSYA_KOKUSEKI               := MAKYOIKUIDO_REC1.HOGOSYA_KOKUSEKI;
            rRECODE.GAKOMEI                        := MAKYOIKUIDO_REC1.GAKOMEI;
            rRECODE.GAKUNEN                        := MAKYOIKUIDO_REC1.GAKUNEN;
            rRECODE.NUSHI_SHIMEI_KANJI_HENKOUGO    := MAKYOIKUIDO_REC1.NUSHI_SHIMEI_KANJI_HENKOUGO;
            rRECODE.HENKO_JIYU                     := MAKYOIKUIDO_REC1.HENKO_JIYU;
            rRECODE.HENKO_TODOKEDE_BI_KAISHI       := MAKYOIKUIDO_REC1.HENKO_TODOKEDE_BI_KAISHI;
            rRECODE.HENKO_TODOKEDE_BI_SHURYO       := MAKYOIKUIDO_REC1.HENKO_TODOKEDE_BI_SHURYO;
            rRECODE.HENKO_BI_KAISHI                := MAKYOIKUIDO_REC1.HENKO_BI_KAISHI;
            rRECODE.HENKO_BI_SHURYO                := MAKYOIKUIDO_REC1.HENKO_BI_SHURYO;
-- 2024/06/25 ZCZL.wangqiwei Add end
            rRECODE.BREAK_NO                       := NULL;
            rRECODE.WSNUM                          := g_sWSNUM;
            rRECODE.BATCHKBN                       := c_BATCH;
            rRECODE.JOBNUM                         := g_nJOBNUM;

            INSERT INTO GKBWL340R001 VALUES rRECODE;
        END LOOP;

        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- 処理ログの出力 デバッグ用
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_WK_KYOIKUIDO_CSVFILE', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCSET_WK_KYOIKUIDO_CSVFILE;

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        eEXCEPTION       EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        DELETE FROM GKBWL340R001  WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
-- 2024/06/26 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
        DELETE FROM GKBWKYOIKUIDO ;
        -- 取得した条件をそれぞれの変数へセット
        VKAISHI_WAREKI := g_vJYOUKEN01;              -- 抽出開始日
        VSHURYO_WAREKI := g_vJYOUKEN02;              -- 抽出終了日
        VKUBUN         := g_vJYOUKEN03;              -- 処理区分

        -- 教育異動者一覧ワークのデータ全件削除
        I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
        IF I_RTN = c_INOT_SUCCESS THEN
            -- エラーで帰ってきた場合
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
            RAISE eEXCEPTION;
        END IF;
        -- 教育異動者一覧ラベルワーク中間データ作成
        I_RTN := FUNC_GET_WK;
        IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            IF I_RTN = c_INOTFOUND THEN
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
              GOTO END_EXIT;
            END IF;
            RAISE eEXCEPTION;
        END IF;

          -- 教育異動者一覧ラベルワーク作成
        I_RTN := FUNC_INSERT_WK;
        IF I_RTN = c_INOT_SUCCESS THEN
            -- エラーで帰ってきた場合
            RAISE eEXCEPTION;
        END IF;
        -- 教育異動者一覧中間データ作成（ＣＳＶ用）
        I_RTN := FUNCGET_WK_KYOIKUIDO_CSV;
        IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            -- ※ 終了処理は処理の内部で行っています
            RAISE eEXCEPTION;
        END IF;

        -- 教育異動者一覧中間ＣＳＶファイル作成
        I_RTN := FUNCSET_WK_KYOIKUIDO_CSVFILE;
        IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            -- ※ 終了処理は処理の内部で行っています
            RAISE eEXCEPTION;
        END IF;
        BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);

        --帳票出力CSVの作成
        CASE g_rJSTP.Chohyoid
          WHEN 'GKB340R001' THEN
            bRTN := FUNC_B11CSV('GKBWL340R001');
          ELSE
            NULL;
        END CASE;
--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
       <<END_EXIT>>
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
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
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
    --  作成者／作成日: ZCZL.DINGHOGNRUI 2024/01/04
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
END GKBPB00250;
/