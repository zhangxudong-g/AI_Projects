CREATE OR REPLACE PACKAGE BODY GKBPB00210
--1.0.006.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 教育異動通知のバッチ処理
--  機能概要      : 任意の抽出期間により転入学、転出学、学校区内異動の通知を印刷する
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
--------------------------------------------------------
--  修正履歴
--  2024/07/01 ZCZL.lwy Update 0.3.000.000:新WizLIFE２次開発
--  2024/08/06 ZCZL.LIUWEIYUAN Update 0.3.000.001:検収指摘No.128
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00075対応
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00136対応
--  2024/10/17 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更　ID：IT_GKB_00112、製造故障QA　ID：41対応
--  2024/10/28 ZCZL.WANGMING UPDATE 0.3.000.005:IT_GKB_00396対応
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00286横展開対応
--  2024/11/13 ZCZL.WANGMING UPDATE 0.3.000.007:IT_GKB_00535横展開対応
--  2024/11/21 JPJYS.JH UPDATE 0.3.000.008:IT_GKB_00549仕様変更対応
--  2024/12/17 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKC_00329横展開対応
--  2024/12/23 JPJYS.LIZIZHONG UPDATE 0.3.000.010:IT_GKB_10110対応
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
--  2025/01/10 JPJYS.LIZIZHONG UPDATE 0.3.000.012:品質強化 IT_GKB_10236
--  2025/05/08 CTC.GL UPDATE 1.0.003.000:GKB_QA13682対応
--  2025/05/15 CTC.LIUJUNHAO UPDATE 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
--  2025/05/21 CTC.HJF UPDATE 1.0.006.000:GKB_QA14364_未登録外字で登録した対象者が文字切れリストに表示されない対応
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
    --条件
    g_vJYOUKEN1  NVARCHAR2(500);
    g_vJYOUKEN2  NVARCHAR2(500);
    g_vJYOUKEN3  NVARCHAR2(500);
--  2024/10/17 ZCZL.WANGMING DELETE 0.3.000.004:仕様変更　ID：IT_GKB_00112対応
--    g_vJYOUKEN4  NVARCHAR2(500);
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
    g_vJYOUKEN5  NVARCHAR2(1000);  
    g_vJYOUKEN6  NVARCHAR2(1000);  
    g_vJYOUKEN7  NVARCHAR2(1000);  
    g_vJYOUKEN8  NVARCHAR2(1000);
    g_vJYOUKEN9          NVARCHAR2(1000);
    g_vJYOUKEN10         NVARCHAR2(1000);
    g_vJYOUKEN11         NVARCHAR2(1000);
    g_vHOGOSYAATE        NVARCHAR2(1000);                 --保護者宛
    g_vSHINGAKKOATE      NVARCHAR2(1000);                 --新学校長宛
    g_vKYUGAKKOYAATE     NVARCHAR2(1000);                 --旧学校長宛
    g_rBUNNUMSRCINF      KKAPK0040.MR_BUNNUMSRCINF;       --文書番号情報（構造体）
    g_rBUNNUMEDITKEKA    KKAPK0040.MR_BUNNUMEDITKEKA;     --文書番号編集結果
    g_rBUNOUTINF         KKAPK0040.MR_BUNOUTINF;          --文書発行記録出力情報
    g_vBUNSHO_NO         NVARCHAR2(1000);                 --文書番号
    o_nHANTEIKEKKA       PLS_INTEGER;                     --判定結果
--  2024/07/01 ZCZL.lwy Add End
    VMSG NVARCHAR2(4000);
    VERRTMPMSG NVARCHAR2(1000);
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
    W_IJOKEN3        PLS_INTEGER;    --処理条件３ワーク
--  2024/07/01 ZCZL.lwy Add 0.3.000.000:新WizLIFE２次開発
--  2024/10/28 ZCZL.WANGMING DELETE 0.3.000.005:IT_GKB_00396対応
--    W_IJOKEN8        PLS_INTEGER;    --処理条件８ワーク
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    -- ERROR関連 --
    N_SQL_CODE        NUMBER;             -- SQLエラーコード
    V_SQL_MSG         VARCHAR(255);       -- SQLエラーメッセージ
    -- ＳＱＬ文生成用
    VSQL              VARCHAR2(1024);
    --処理条件
    VKAISHI_WAREKI    NVARCHAR2(15);  -- 抽出開始日
    VSHURYO_WAREKI    NVARCHAR2(15);  -- 抽出終了日
    VKIJUNBI          NVARCHAR2(15);  -- 基準日
    NKAISHI_SEIREKI   NUMBER;         -- 抽出開始日
    NSHURYO_SEIREKI   NUMBER;         -- 抽出終了日
    NKIJUNBI          NUMBER;         -- 基準日
    NCHOHYO_KBN       NUMBER;         -- 処理条件３（帳票区分）
--  2024/10/17 ZCZL.WANGMING DELETE 0.3.000.004:仕様変更　ID：IT_GKB_00112対応
--    NTAISHO_JIDO      NUMBER;         -- 処理条件４（対象児童個人番号）
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
    GRB_HENKO_KAISHITODOKEDEBI_WAREKI  NVARCHAR2(1000);    --学齢簿変更届出開始日
    GRB_HENKO_SYURYOTODOKEDEBI_WAREKI  NVARCHAR2(1000);    --学齢簿変更届出終了日
    GRB_HENKO_KAISHIBI_WAREKI          NVARCHAR2(1000);    --学齢簿変更開始日
    GRB_HENKO_SYURYOBI_WAREKI          NVARCHAR2(1000);    --学齢簿変更終了日
--  2024/07/01 ZCZL.lwy Add End
    --関数用変数
    BRTN              BOOLEAN;
    IRTN              PLS_INTEGER;
    --抽出項目格納変数 --
    RWK_IDO           GKBWINTERNAL%ROWTYPE; --内部ワーク用変数
    VKYUCHOMEI        NVARCHAR2(40);    -- 町名
    VKYUBANCHI        NVARCHAR2(40);    -- 番地
    VKYUKATAGAKI      NVARCHAR2(60);    -- 方書
    NKYUSHOGAKU_CD    NUMBER;           -- 旧小学校コード
    NKYUCHUGAKU_CD    NUMBER;           -- 旧中学校コード
    NKYUGYOSEIKU_CD   NUMBER;           -- 旧行政区コード
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
    NKYUSHIMEI_KANA   NVARCHAR2(1000);  --氏名かな
    NKYUSHIMEI_KANJI  NVARCHAR2(1000);  --氏名漢字
    NKYUHOGOSHA_SHIMEI_KANA  NVARCHAR2(1000);  --保護者氏名かな
    NKYUHOGOSHA_SHIMEI_KANJI NVARCHAR2(1000);  --保護者氏名漢字
    NKYUGAKKO_KBN_CD         NVARCHAR2(1000);  --学校区分コード
    NKYUGAKUNEN              NVARCHAR2(1000);  --学年
--  2024/07/01 ZCZL.lwy Add End
    IKENSU_IN         PLS_INTEGER;      -- 異動累計読み込み件数
    IKENSU_OUT        PLS_INTEGER;      -- 中間テーブル書出件数
    IKENSU_TENSHUTSU  PLS_INTEGER;      -- 中間テーブル書出件数(転出票）
    IKENSU_TENNYU     PLS_INTEGER;      -- 中間テーブル書出件数(転入票）
    IKENSU_KUNAI      PLS_INTEGER;      -- 中間テーブル書出件数(学校区内異動）
    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    IO_IWAREKIHIZUKE  PLS_INTEGER := NULL;
    IO_ISEIREKIHIZUKE PLS_INTEGER := NULL;
    O_VEDIT_GYYMMDD1  NVARCHAR2(16);
    O_VEDIT_GYYMMDD2  NVARCHAR2(16);
    O_VEDIT_GYYMMDD3  NVARCHAR2(16);
    O_VKJ_GENGO       NVARCHAR2(16);
    O_VKG_GENGO       NVARCHAR2(16);
    O_IWAREKI_YY      PLS_INTEGER;
    O_ISEIREKI_YYYY   PLS_INTEGER;
    O_IWAREKI_GYYMM   PLS_INTEGER;
    O_IMM             PLS_INTEGER;
    O_IDD             PLS_INTEGER;
    O_IWAREKIHIZUKE   PLS_INTEGER;
    O_ISEIREKIHIZUKE  PLS_INTEGER;
    -- 共通情報（稼働ﾕｰｻﾞｰ情報）サブルーチン用変数(KKAPK0030.FKYOTU)
    O_IUSER_ID                PLS_INTEGER;    -- 市町村コード
    O_IGAPPEI_BI              PLS_INTEGER;    -- 合併日付
    O_IJICHI_CD               PLS_INTEGER;    -- 自治コード
    O_IUSER_KBN               PLS_INTEGER;    -- 市町村区分
    O_VKENMEI                 NVARCHAR2(30);  -- 県名
    O_VGUNSHIMEI              NVARCHAR2(30);  -- 郡市名
    O_VUSERMEI                NVARCHAR2(40);  -- 市町村名
    O_VSHUCHOMEI              NVARCHAR2(40);  -- 首長名
    O_VSHUCHONINSHOBUN        NVARCHAR2(100); -- 首長認証文
    O_VYUBIN_NO               NVARCHAR2(10);  -- 郵便番号
    O_VSHOZAICHI              NVARCHAR2(200); -- 所在地
    O_VTEL_NO                 NVARCHAR2(20);  -- 代表電話番号
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
    o_nDAIRIKBN               NVARCHAR2(1000);--認証者の本人・代理区分
    o_vKATAGAKI1              NVARCHAR2(1000);--認証者の肩書上段
    o_vKATAGAKI2              NVARCHAR2(1000);--認証者の肩書下段
    o_vSHIMEI                 NVARCHAR2(1000);--認証者の氏名
    o_vKOINFILENAME           NVARCHAR2(1000);--公印ファイル名
--  2024/07/01 ZCZL.lwy Add End
    -- 公印名情報サブルーチン用変数
    O_VKOIN_SHUCHO            NVARCHAR2(128);
    O_VKOIN_GYOMU             NVARCHAR2(128);
    NSEINENSHO_SHURYO         NUMBER(8);      -- 生年月日の範囲（小学１年生の一番遅い日）
    NSEINENCHU_KAISHI         NUMBER(8);      -- 生年月日の範囲（中学３年生の一番早い日）
    SEQ_NO                    NUMBER;         -- 中間テーブルに書き込む
    INENDO                    PLS_INTEGER;    -- 年度
    IHAKKO_KBN                PLS_INTEGER;    -- 発行区分
    IMEISYUTURYOKUSEIGYO      PLS_INTEGER;    -- 本名・通称名出力制御
    IKYOUIKUIINKAIJOUHOU      PLS_INTEGER;    -- 教育委員会情報
    IEBIDOJIYU                PLS_INTEGER;    -- 住記異動事由
    IAAMEMOKBN                PLS_INTEGER;    -- 住記異動事由
    o_MEISYUPRM               A_CONS_PRM;
    o_KYOIKUPRM               A_CONS_PRM;
    o_EBIDOJIYU               A_CONS_PRM;
    o_AAMEMOKBN               A_CONS_PRM;
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
    o_tITEM                   A_CONS_PRM;
    vCHOHYORENBAN             NVARCHAR2(1000);
    vSYSSEIGYONO              NVARCHAR2(1000);
    vCHOHYO_MEI               NVARCHAR2(1000); --帳票名
    vTSUCHIBUN                NVARCHAR2(1000); --通知文
    vKOIN_SHORYAKU            NVARCHAR2(1000); --公印省略
    vKOIN_CHUSHAKU            NVARCHAR2(1000); --公印注釈
    vYOSHIKI_BANGO_SETTOGO    NVARCHAR2(1000); --様式番号接頭語
    vYOSHIKI_BANGO            NVARCHAR2(1000); --様式番号
    vYOSHIKI_BANGO_SETSUBIGO  NVARCHAR2(1000); --様式番号接尾語
    vSYOGAKOMEI               NVARCHAR2(1000); --小学校名
    vTYUGAKOMEI               NVARCHAR2(1000); --中学校名
    vKUIKIGAIMEI              NVARCHAR2(1000); --区域外学校名
    vYOGOGAKOMEI              NVARCHAR2(1000); --盲聾養護学校名
    vKUNISHIRITSUGAKKOMEI     NVARCHAR2(1000); --国・私立学校名
    vOLDSYOGAKOMEI            NVARCHAR2(1000); --旧小学校名
    vOLDTYUGAKOMEI            NVARCHAR2(1000); --旧中学校名
    vOLDKUIKIGAIMEI           NVARCHAR2(1000); --旧区域外学校名
    vOLDYOGOGAKOMEI           NVARCHAR2(1000); --旧盲聾養護学校名
    vOLDKUNISHIRITSUGAKKOMEI  NVARCHAR2(1000); --旧国・私立学校名
    o_sSHIMEIKANA             NVARCHAR2(1000); --氏名カナ
    o_sSHIMEI                 NVARCHAR2(1000); --氏名漢字
    o_sBIRTHDAY               NVARCHAR2(1000); --生年月日
--  2024/07/01 ZCZL.lwy Add End
    o_LENGTH                  NUMBER;
    B_RTN                     BOOLEAN := TRUE;
    NKYOIKUIINKAI_CD          NUMBER(2);  --教育委員会
    RD                        GABTATENAKIHON%ROWTYPE;
    RE                        GABTSOFUSAKI%ROWTYPE;
    VSHIMEI_KANJI             NVARCHAR2(300);
    VJINKAKU_KBN              NUMBER;
    HOGOSHA_KBN               PLS_INTEGER;
--  2024/11/02 ZCZL.WANGMING ADD START 0.3.000.006:IT_GKB_00286横展開対応
    o_sEINENGAPI2                    GKAPK00020.SEINENGAPI_REC;           --生年月日2
    o_sEINENGAPI3                    GKAPK00020.SEINENGAPI_REC;           --生年月日3
--  2024/11/02 ZCZL.WANGMING ADD END

    -- 変更通知書発行対象者用のレコード（児童・保護者のみ）
    TYPE HENKOSHA_REC IS RECORD
    (
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
--      JIDO_KOJIN_NO       NUMBER(12),
--      HOGOSYA_KOJIN_NO    NUMBER(12)
      JIDO_KOJIN_NO       NUMBER(15),
      HOGOSYA_KOJIN_NO    NUMBER(15)
--  2024/07/01 ZCZL.lwy Update End
    );
    CR_HENKOSHA_REC   HENKOSHA_REC;

    -- 変更通知書発行対象者用のレコード
    TYPE IDORUIKEI_REC IS RECORD
    (
      FLG                 PLS_INTEGER,
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
--      JIDO_KOJIN_NO       NUMBER(12),
--      HOGOSYA_KOJIN_NO    NUMBER(12),
      JIDO_KOJIN_NO       NUMBER(15),
      HOGOSYA_KOJIN_NO    NUMBER(15),
--  2024/07/01 ZCZL.lwy Update End
      GAKUNEN_CD          NUMBER(2),
      RUIKEI_RENBAN       NUMBER(12),
      RIREKI_RENBAN       NUMBER(5),
      IDO_JIYU            NUMBER(2),
--  2024/07/01 ZCZL.lwy Update 0.3.000.000:新WizLIFE２次開発
--      KOJIN_NO            NUMBER(12),
      KOJIN_NO            NUMBER(15),
      SHIMEI_KANA         NVARCHAR2(100),
      SHIMEI_KANJI        NVARCHAR2(100),
      SEINENGAPI          NUMBER(8),
      SEIBETSU            NUMBER(1),
      SHOGAKU_CD          NUMBER(5),
      CHUGAKU_CD          NUMBER(5),
      CHOMEI              NVARCHAR2(40),
      BANCHI              NVARCHAR2(40),
      KATAGAKI            NVARCHAR2(60),
--  2024/07/01 ZCZL.lwy Update 0.3.000.000:新WizLIFE２次開発
--      SETAI_NO            NUMBER(7),
      SETAI_NO            NUMBER(15),
      SANTEIDANTAI_CD     NUMBER(2),
      IDO_TODOKE_BI       NUMBER(8),
      IDO_BI              NUMBER(8),
      HONMYO_KANA         NVARCHAR2(100),
      HONMYO_KANJI        NVARCHAR2(100),
      GYOSEIKU_CD         NUMBER(5),
      TENNYUMAE_REN       NUMBER(3),
      JINKAKU_KBN         NUMBER(1)
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
      ,HOGOSHA_SHIMEI_KANA NVARCHAR2(1000),
      HOGOSHA_SHIMEI_KANJI NVARCHAR2(1000),                           
      HOGOSHA_HONMYO_KANA  NVARCHAR2(1000),                         
      HOGOSHA_HONMYO_KANJI NVARCHAR2(1000),
      GAKKO_KBN_CD         NVARCHAR2(1000),
      GAKUNEN              NVARCHAR2(1000),
      GRB_HENKO_TODOKEDE_BI   NVARCHAR2(1000),
      GRB_HENKO_BI            NVARCHAR2(1000),
      TENNYUMAE_GAKKO_KBN     NVARCHAR2(1000),
      TENNYUMAE_GAKKO_CD      NVARCHAR2(1000),
      TENNYUMAE_GAKUNEN       NVARCHAR2(1000),
      GRB_HENKO_JIYU          NVARCHAR2(1000)
--  2024/07/01 ZCZL.lwy Add End
    );
    CR_IDOREC IDORUIKEI_REC;
    CR_IDOREC_HOGO IDORUIKEI_REC;
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        v_cmbTsuchisho           DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/07/01 ZCZL.lwy Add 0.3.000.000:新WizLIFE２次開発
        v_chkTsuchisho           DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/09/03 ZCZL.WANGMING ADD START 0.3.000.002:IT_GKB_00075対応
        cmbchkAtesaki      DBMS_UTILITY.MAXNAME_ARRAY;
        cmboptShiensochi   DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/09/03 ZCZL.WANGMING ADD END
    BEGIN
        -- 異動開始日 期間(開始)
        g_vJYOUKEN1              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtIdoKikanStart');
        -- 異動終了日 期間(終了)
        g_vJYOUKEN2              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtIdoKikanEnd');
--  2024/07/01 ZCZL.lwy Delete Start 0.3.000.000:新WizLIFE２次開発
        -- 通知書
--        v_cmbTsuchisho           := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbTsuchisho');
--        g_vJYOUKEN3              := v_cmbTsuchisho(1);
--  2024/07/01 ZCZL.lwy Delete End
        -- 児童宛名番号
--  2024/10/17 ZCZL.WANGMING DELETE 0.3.000.004:仕様変更　ID：IT_GKB_00112対応
--        g_vJYOUKEN4              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtJidoKojinNo');
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
        -- 学齢簿変更届出開始日
        g_vJYOUKEN5              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHenkoTodokedeKikanStart');
        -- 学齢簿変更届出終了日
        g_vJYOUKEN6              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHenkoTodokedeKikanEnd');
        -- 学齢簿変更開始日
        g_vJYOUKEN7              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHenkoKikanStart');
        -- 学齢簿変更終了日
        g_vJYOUKEN8              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHenkoKikanEnd');
        -- 宛先
--  2024/09/03 ZCZL.WANGMING UPDATE START 0.3.000.002:IT_GKB_00075対応
--        g_vJYOUKEN9              := KKBPK5551.GETPARMS(g_nJOBNUM, 'chkAtesaki');
        cmbchkAtesaki := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'chkAtesaki');
        g_vJYOUKEN9 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'chkAtesaki', 0, cmbchkAtesaki);
--  2024/09/03 ZCZL.WANGMING UPDATE END
        -- 発行日
        g_vJYOUKEN10             := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHakkobi');
        -- 支援措置対象マスク
--  2024/09/03 ZCZL.WANGMING UPDATE START 0.3.000.002:IT_GKB_00075対応
--        g_vJYOUKEN11             := KKBPK5551.GETPARMS(g_nJOBNUM, 'optShiensochi');
        cmboptShiensochi := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'optShiensochi');
        g_vJYOUKEN11 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'optShiensochi', 0, cmboptShiensochi);
--  2024/09/03 ZCZL.WANGMING UPDATE END
--  2024/07/01 ZCZL.lwy Add End

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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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

 --  2024/11/21 JPJYS.JH DEL 0.3.000.008:IT_GKB_00549仕様変更対応 Start
    ----------------------------------------------------------------------------------------------------
    --日付チェック
    ----------------------------------------------------------------------------------------------------
--    FUNCTION FUNCHIZUKECHK( I_VHIZUKE IN NVARCHAR2 ) RETURN NUMBER IS
--    IRET PLS_INTEGER ;
--    BRET BOOLEAN ;
--    BEGIN
--      IRET := 0 ;
--      --日付
--      BEGIN
--        IF I_VHIZUKE IS NULL THEN
--          IRET := 1;
--       ELSIF LENGTH(I_VHIZUKE) <> 7 THEN
--          IRET := 1;
--        ELSE
--          IWAREKIHIDUKEIO  := TO_NUMBER(I_VHIZUKE);
--          ISEIREKIHIDUKEIO := 0;
--        END IF;
--      EXCEPTION
--        WHEN OTHERS THEN
--          IRET := 1;
--      END;

--      IF IRET = 0 THEN
--        BRET := KKAPK0020.FDAYEDIT(IWAREKIHIDUKEIO, ISEIREKIHIDUKEIO,
--                                    VEDIT1O, VEDIT2O, VEDIT3O,
--                                    VGENGOKANJIO, VGENGOKIGOO,
--                                    IWAREKINENO, ISEIREKINENO,
--                                    IWAREKINENGETUO, ITUKIO, IDAYO,
--                                    IWAREKIHIDUKEO, ISEIREKIHIDUKEO);
--        IF BRET = FALSE THEN
--          IRET := 1;
--        END IF;
--      END IF;

--      RETURN(IRET) ;
--    END ;
--  2024/11/21 JPJYS.JH DEL 0.3.000.008:IT_GKB_00549仕様変更対応 Start
 --  2024/11/21 JPJYS.JH ADD 0.3.000.008:IT_GKB_00549仕様変更対応 Start
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
    --  2024/11/21 JPJYS.JH ADD 0.3.000.008:IT_GKB_00549仕様変更対応 End
    --  2024/11/21 JPJYS.JH DEL 0.3.000.008:IT_GKB_00549仕様変更対応 Start  
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
--    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
--                       o_vRESULT OUT NVARCHAR2)
--    IS
--        bRTN                          BOOLEAN;  --戻り値
--        IRTN                          NUMBER;
--   BEGIN
--        VMSG := '' ;
--        VERRTMPMSG := '' ;
--        IRTN := 0 ;
--
--        --ジョブナンバーをセット
--        g_nJOBNUM := i_nJOBNUM;
--
--        --バッチ初期処理
--        bRTN := FUNC_B00INIT;
--        IF NOT bRTN THEN
--            o_vRESULT := g_sMESSAGE;
--            RETURN;
--        END IF;
--
--        -- バッチ入力値取得
--        bRTN := FUNC_B01PINIT;
--
--        --条件１のチェック
--        IRTN := FUNCHIZUKECHK( g_vJYOUKEN1 ) ;
--        IF IRTN <> 0 THEN
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,開始異動日が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        END IF ;
--
--        --条件２のチェック
--        IRTN := FUNCHIZUKECHK( g_vJYOUKEN2 ) ;
--        IF IRTN <> 0 THEN
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,終了異動日が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        END IF ;
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
        --条件３のチェック：変更通知書
--         W_IJOKEN3 := 0;
--         W_IJOKEN3 := TO_NUMBER(NVL(g_vJYOUKEN3,0));
--         IF W_IJOKEN3 > 1 THEN
--           VERRTMPMSG := g_sGYOUMUCODE || ',99999,変更通知書が正しくありません。,;';
--           VMSG := VMSG || VERRTMPMSG;
--         END IF;
--  2024/11/13 ZCZL.WANGMING UPDATE START 0.3.000.007:IT_GKB_00535横展開対応
--        --条件５のチェック
--        bRTN := KKAPK0020.FISDATEW( g_vJYOUKEN5 ) ;
--        IF NOT bRTN THEN
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,開始学齢簿変更届出日が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        END IF ;
--        
--        --条件６のチェック
--        bRTN := KKAPK0020.FISDATEW( g_vJYOUKEN6 ) ;
--        IF NOT bRTN THEN
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,終了学齢簿変更届出日が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        END IF ;
--        
--        --条件７のチェック
--        bRTN := KKAPK0020.FISDATEW( g_vJYOUKEN7 ) ;
--        IF NOT bRTN THEN
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,開始学齢簿変更日 が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        END IF ;
--        
--        --条件８のチェック
--        bRTN := KKAPK0020.FISDATEW( g_vJYOUKEN8 ) ;
--        IF NOT bRTN THEN
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,終了学齢簿変更日 日が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        END IF ;
--       --条件５のチェック
--        IF KKAPK0010.FISNUMERIC(g_vJYOUKEN5) = FALSE THEN 
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出日 期間（開始）が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        ELSE
--           --日付チェック
--           IF g_vJYOUKEN5 IS NOT NULL THEN
--               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN5));
--               IF NOT bRTN THEN
--                   VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出日 期間（開始）が正しくありません。,;';
--                   VMSG := VMSG || VERRTMPMSG;
--               END IF;
--           END IF;
--        END IF;
--       --条件６のチェック
--        IF KKAPK0010.FISNUMERIC(g_vJYOUKEN6) = FALSE THEN 
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出日 期間（終了）が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        ELSE
--           --日付チェック
--           IF g_vJYOUKEN6 IS NOT NULL THEN
--               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN6));
--               IF NOT bRTN THEN
--                   VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出日 期間（終了）が正しくありません。,;';
--                   VMSG := VMSG || VERRTMPMSG;
--               END IF;
--           END IF;
--        END IF;
--        --条件７のチェック
--        IF KKAPK0010.FISNUMERIC(g_vJYOUKEN7) = FALSE THEN 
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更日 期間（開始）が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        ELSE
--           --日付チェック
--           IF g_vJYOUKEN7 IS NOT NULL THEN
--               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN7));
--               IF NOT bRTN THEN
--                   VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更日 期間（開始）が正しくありません。,;';
--                   VMSG := VMSG || VERRTMPMSG;
--               END IF;
--           END IF;
--        END IF;
--        --条件８のチェック
--        IF KKAPK0010.FISNUMERIC(g_vJYOUKEN8) = FALSE THEN 
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更日 期間（終了）が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        ELSE
--           --日付チェック
--           IF g_vJYOUKEN8 IS NOT NULL THEN
--               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN8));
--               IF NOT bRTN THEN
--                   VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更日 期間（終了）が正しくありません。,;';
--                   VMSG := VMSG || VERRTMPMSG;
--               END IF;
--           END IF;
--        END IF;
--  2024/11/13 ZCZL.WANGMING UPDATE END

        --条件９のチェック
--  2024/10/28 ZCZL.WANGMING UPDATE START 0.3.000.005:IT_GKB_00396対応
--        W_IJOKEN8 := 0;
--        W_IJOKEN8 := TO_NUMBER(NVL(g_vJYOUKEN9,0));
--        IF W_IJOKEN8 = 0 THEN
--        IF g_vJYOUKEN9 IS NULL THEN
--  2024/10/28 ZCZL.WANGMING UPDATE END
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,宛先を選択してください。,;';
--  2024/07/01 ZCZL.lwy Update End
--          VMSG := VMSG || VERRTMPMSG;
--        END IF;

--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
        --条件１０のチェック
--  2024/11/13 ZCZL.WANGMING UPDATE START 0.3.000.007:IT_GKB_00535横展開対応
--        bRTN := KKAPK0020.FISDATEW( g_vJYOUKEN10 ) ;
--        IF NOT bRTN THEN
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,発行日が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        END IF ;
--        --条件１０のチェック
--        IF KKAPK0010.FISNUMERIC(g_vJYOUKEN10) = FALSE THEN 
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,発行日が正しくありません。,;';
--          VMSG := VMSG || VERRTMPMSG;
--        ELSE
--           --日付チェック
--           IF g_vJYOUKEN10 IS NOT NULL THEN
--               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN10));
--               IF NOT bRTN THEN
--                   VERRTMPMSG := g_sGYOUMUCODE || ',99999,発行日が正しくありません。,;';
--                   VMSG := VMSG || VERRTMPMSG;
--               END IF;
--           END IF;
--        END IF;
--  2024/11/13 ZCZL.WANGMING UPDATE END
--  2024/07/01 ZCZL.lwy Add End
--        o_vRESULT := VMSG ;

--    EXCEPTION
--        WHEN OTHERS THEN
--            NULL;
--    END PBPRMCHK;
--  2024/11/21 JPJYS.JH DEL 0.3.000.008:IT_GKB_00549仕様変更対応 End  
--  2024/11/21 JPJYS.JH DEL 0.3.000.008:IT_GKB_00549仕様変更対応 Start      
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: JPJYS.JH 2024/11/21
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                         BOOLEAN;  --戻り値
        ICHK1                        NUMBER := 0;
        ICHK2                        NUMBER := 0;
        ICHK3                        NUMBER := 0;
        ICHK4                        NUMBER := 0;
        ICHK5                        NUMBER := 0;
        ICHK6                        NUMBER := 0;
        IRTN                         NUMBER;
    BEGIN
        VMSG := '' ;
        VERRTMPMSG := '' ;
        IRTN := 0 ;

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

        --処理条件.異動開始日 期間(開始)のチェック
        ICHK1 := FUNCHIZUKECHK( g_vJYOUKEN1 ) ;
        IF ICHK1 <> 0 THEN
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,異動開始日 期間(開始)が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF ;
        --処理条件.異動終了日 期間(終了)のチェック
        ICHK2 := FUNCHIZUKECHK( g_vJYOUKEN2 ) ;
        IF ICHK2 <> 0 THEN
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,異動終了日 期間(終了)が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF ;
        IF ICHK1 = 0 AND ICHK2 = 0 THEN 
          IF g_vJYOUKEN1 > g_vJYOUKEN2 THEN 
            VERRTMPMSG := g_sGYOUMUCODE || ',99999,異動開始日 期間開始、終了年月日の関係が正しくありません。,;';
            VMSG := VMSG || VERRTMPMSG;
          END IF;
        END IF;
        --処理条件.学齢簿変更届出日 期間(開始)のチェック
        ICHK3 := FUNCHIZUKECHK( g_vJYOUKEN5);
        IF ICHK3 <> 0 THEN
            VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出日 期間(開始)が正しくありません。,;' ;
            VMSG := VMSG || VERRTMPMSG;
        END IF;     
        --処理条件.学齢簿変更届出日 期間(終了)のチェック
        ICHK4 := FUNCHIZUKECHK( g_vJYOUKEN6);
        IF ICHK4 <> 0 THEN
            VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出日 期間(終了)が正しくありません。,;' ;
            VMSG := VMSG || VERRTMPMSG;
        END IF;          
        IF ICHK3 = 0 AND ICHK4 = 0 THEN 
          IF g_vJYOUKEN5 > g_vJYOUKEN6 THEN 
            VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更届出日 期間開始、終了年月日の関係が正しくありません。,;';
            VMSG := VMSG || VERRTMPMSG;
          END IF;
        END IF;        
        --処理条件.学齢簿変更日 期間(開始)のチェック
        ICHK5 := FUNCHIZUKECHK( g_vJYOUKEN7);
        IF ICHK5 <> 0 THEN
            VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更日 期間(開始)が正しくありません。,;' ;
            VMSG := VMSG || VERRTMPMSG;
        END IF;          
        --処理条件.学齢簿変更日 期間(終了)のチェック
        ICHK6 := FUNCHIZUKECHK( g_vJYOUKEN8);
        IF ICHK6 <> 0 THEN
            VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更日 期間(終了)が正しくありません。,;' ;
            VMSG := VMSG || VERRTMPMSG;
        END IF;          
        IF ICHK5 = 0 AND ICHK6 = 0 THEN 
          IF g_vJYOUKEN7 > g_vJYOUKEN8 THEN 
            VERRTMPMSG := g_sGYOUMUCODE || ',99999,学齢簿変更日 期間開始、終了年月日の関係が正しくありません。,;';
            VMSG := VMSG || VERRTMPMSG;
          END IF;
        END IF;         
        --処理条件.発行日のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN10);
        IF IRTN <> 0 THEN
            VERRTMPMSG := g_sGYOUMUCODE|| ',99999,発行日が正しくありません。,;';
            VMSG := VMSG || VERRTMPMSG;
        END IF;         

        o_vRESULT := VMSG ;

    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
--  2024/11/21 JPJYS.JH DEL 0.3.000.008:IT_GKB_00549仕様変更対応 End    
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
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  機能概要      : 発行区分取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    PROCEDURE PROC_GET_HAKKO_KBN
    IS
        TACONSPRM  A_CONS_PRM;       --戻るパラメータ配列
        NLENGTH    NUMBER;           --配列件数
    BEGIN
        IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      94,         --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
        IF NLENGTH <> 0 THEN
        --レコードが取得できた場合
          IHAKKO_KBN := TACONSPRM(1);
        ELSE
        --レコードが取得できない場合
          IHAKKO_KBN := 0;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            IHAKKO_KBN := 0;
    END PROC_GET_HAKKO_KBN;
    --------------------------------------------------------
    --  機能概要      : ワークテーブルにレコードを挿入する
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 成功 TRUE,失敗 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_INSERT_INTERNAL_WORK RETURN  BOOLEAN
    IS
    BEGIN
        INSERT INTO GKBWINTERNAL
             VALUES RWK_IDO;
        COMMIT;

        IKENSU_OUT := IKENSU_OUT + 1;       -- 中間テーブル書出件数
--  2024/07/01 ZCZL.lwy Delete Start 0.3.000.000:新WizLIFE２次開発
--         IF RWK_IDO.TSUCHISHO_KBN = 1 THEN
--             IKENSU_TENNYU    := IKENSU_TENNYU + 1;      -- 中間テーブル書出件数(転入票）
--         ELSIF RWK_IDO.TSUCHISHO_KBN = 2 THEN
--             IKENSU_TENSHUTSU := IKENSU_TENSHUTSU + 1;   -- 中間テーブル書出件数(転出票）
--         ELSIF RWK_IDO.TSUCHISHO_KBN = 4 THEN
--             IKENSU_KUNAI     := IKENSU_KUNAI + 1;       -- 中間テーブル書出件数(学校区内異動）
--         ELSE
--             NULL;
--         END IF;
--  2024/07/01 ZCZL.lwy Delete End
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
            RETURN FALSE;
    END FUNC_INSERT_INTERNAL_WORK;
    --------------------------------------------------------
    --  機能概要      : 小学生、中学生の対象生年月日の範囲を求める
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    PROCEDURE PROC_GET_SEINENGAPI
    IS
        W_KIJUNBI       NUMBER;
    BEGIN
        -- 中学３年生の一番早い日
        W_KIJUNBI := INENDO * 10000 + 402; -- 基準日
        NSEINENCHU_KAISHI := KKAPK0020.FDATECAL( W_KIJUNBI,
                                                  0,
                                                  0,
                                                  0,
                                                  -15 );

        -- 小学１年生の一番遅い日
        W_KIJUNBI := INENDO * 10000 + 401; -- 基準日
        NSEINENSHO_SHURYO := KKAPK0020.FDATECAL( W_KIJUNBI,
                                                  0,
                                                  0,
                                                  0,
                                                 -5 );
    END PROC_GET_SEINENGAPI;
    --------------------------------------------------------
    --  機能概要      : 対象者の旧住所、旧学校区コードを取得する
    --                  取得した値は外部変数に格納される
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 成功 TRUE,失敗 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_KYU(I_KOJIN_NO IN NUMBER,
                          I_RIREKI_RENBAN IN NUMBER) RETURN BOOLEAN
    IS
    BEGIN
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
--        SELECT A.CHOMEI,
--               A.BANCHI,
--               A.KATAGAKI,
--               A.SHOGAKU_CD,
--               A.CHUGAKU_CD,
--               A.GYOSEIKU_CD
        SELECT B.CHOMEI,
               B.BANCHI,
               B.KATAGAKI,
               CASE
                 WHEN G.GAKKO_KBN_CD = '3' THEN G.KUIKIGAI_CD
                 WHEN G.GAKKO_KBN_CD = '4' THEN G.YOGOGAKO_CD
                 WHEN G.GAKKO_KBN_CD = '5' THEN G.KUNISHIRITSU_CD
                 ELSE G.SYOGAKO_CD
               END AS SYOGAKO_CD,
               G.TYUGAKO_CD,
               B.GYOSEIKU_CD,
               B.SHIMEI_KANA,                                
               B.SHIMEI_KANJI,                              
               H.SHIMEI_KANA AS HOGOSHA_SHIMEI_KANA,                       
               H.SHIMEI_KANJI AS HOGOSHA_SHIMEI_KANJI,                              
               G.GAKKO_KBN_CD,                                 
               G.GAKUNEN
          INTO VKYUCHOMEI,
               VKYUBANCHI,
               VKYUKATAGAKI,
               NKYUSHOGAKU_CD,
               NKYUCHUGAKU_CD,
               NKYUGYOSEIKU_CD
               ,NKYUSHIMEI_KANA,
               NKYUSHIMEI_KANJI,
               NKYUHOGOSHA_SHIMEI_KANA,
               NKYUHOGOSHA_SHIMEI_KANJI,
               NKYUGAKKO_KBN_CD,
               NKYUGAKUNEN
--          FROM GABVATENAALL A
          FROM GKBTGAKUREIBO G 
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00136対応
--               INNER JOIN GABVATENAALL H
               INNER JOIN GABVATENAALL_B H
                    ON G.HOGOSYA_KOJIN_NO = H.KOJIN_NO AND G.HOGOSYA_IDOJI_RIREKI_RENBAN = H.RIREKI_RENBAN
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00136対応
--               INNER JOIN GABVATENAALL B
               INNER JOIN GABVATENAALL_B B
                    ON G.KOJIN_NO = B.KOJIN_NO AND G.IDOJI_ATENA_RIREKI_RENBAN = B.RIREKI_RENBAN
          WHERE G.SAKUJO_FLG = 0
            AND G.KOJIN_NO = I_KOJIN_NO
            AND G.RIREKI_RENBAN = ( SELECT MAX(G.RIREKI_RENBAN)
                                    FROM GKBTGAKUREIBO G 
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00136対応
--                                         INNER JOIN GABVATENAALL H
                                         INNER JOIN GABVATENAALL_B H
                                               ON G.HOGOSYA_KOJIN_NO = H.KOJIN_NO AND G.HOGOSYA_IDOJI_RIREKI_RENBAN = H.RIREKI_RENBAN
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00136対応
--                                         INNER JOIN GABVATENAALL B
                                         INNER JOIN GABVATENAALL_B B
                                               ON G.KOJIN_NO = B.KOJIN_NO AND G.IDOJI_ATENA_RIREKI_RENBAN = B.RIREKI_RENBAN
                                         WHERE G.SAKUJO_FLG = 0
                                               AND G.RIREKI_RENBAN < I_RIREKI_RENBAN);
--         WHERE A.KOJIN_NO = I_KOJIN_NO
--           AND A.RIREKI_RENBAN = (SELECT MAX(AA.RIREKI_RENBAN)
--                                    FROM GABVATENAALL AA
--                                   WHERE AA.KOJIN_NO = A.KOJIN_NO
--                                     AND AA.SYS_SAKUSEIBI < NKAISHI_SEIREKI);
--  2024/07/01 ZCZL.lwy Update End
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            VKYUCHOMEI := '';
            VKYUBANCHI := '';
            VKYUKATAGAKI := '';
            NKYUSHOGAKU_CD := 0;
            NKYUCHUGAKU_CD := 0;
            NKYUGYOSEIKU_CD := 0;
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
            NKYUSHIMEI_KANA := '';
            NKYUSHIMEI_KANJI := '';
            NKYUHOGOSHA_SHIMEI_KANA := '';
            NKYUHOGOSHA_SHIMEI_KANJI := '';
            NKYUGAKKO_KBN_CD := '';
            NKYUGAKUNEN := '';
--  2024/07/01 ZCZL.lwy Add End
            RETURN TRUE;
        WHEN OTHERS THEN
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
            RETURN FALSE;
    END FUNC_GET_KYU;

--  2024/07/01 ZCZL.lwy Delete Start 0.3.000.000:新WizLIFE２次開発
--     FUNCTION FUNC_GET_KYU2(I_KOJIN_NO IN NUMBER,
--                           I_RENBAN IN NUMBER) RETURN BOOLEAN
--     IS
--     BEGIN
--        IF I_RENBAN = 0 THEN
--          SELECT A.CHOMEI,
--                 A.BANCHI,
--                 A.KATAGAKI,
--                 A.SHOGAKU_CD,
--                 A.CHUGAKU_CD,
--                 A.GYOSEIKU_CD
--            INTO VKYUCHOMEI,
--                 VKYUBANCHI,
--                 VKYUKATAGAKI,
--                 NKYUSHOGAKU_CD,
--                 NKYUCHUGAKU_CD,
--                 NKYUGYOSEIKU_CD
--            FROM GABVATENAALL A,
--                 (SELECT KOJIN_NO, HOGOSYA_KOJIN_NO FROM GKBTGAKUREIBO D
--                  WHERE D.KOJIN_NO = I_KOJIN_NO
--                     AND D.RIREKI_RENBAN = (SELECT MAX(C.RIREKI_RENBAN)
--                                      FROM GKBTGAKUREIBO C
--                                     WHERE C.KOJIN_NO = D.KOJIN_NO
--                                       AND C.SYS_SAKUSEIBI <= NSHURYO_SEIREKI)) B
--           WHERE A.KOJIN_NO = B.HOGOSYA_KOJIN_NO
--             AND A.RIREKI_RENBAN = (SELECT MAX(AA.RIREKI_RENBAN)
--                                      FROM GABVATENAALL AA
--                                     WHERE AA.KOJIN_NO = A.KOJIN_NO
--                                       AND AA.SYS_SAKUSEIBI <= NSHURYO_SEIREKI);
--        ELSE
--          SELECT A.CHOMEI,
--                 A.BANCHI,
--                 A.KATAGAKI,
--                 A.SHOGAKU_CD,
--                 A.CHUGAKU_CD,
--                 A.GYOSEIKU_CD
--            INTO VKYUCHOMEI,
--                 VKYUBANCHI,
--                 VKYUKATAGAKI,
--                 NKYUSHOGAKU_CD,
--                 NKYUCHUGAKU_CD,
--                 NKYUGYOSEIKU_CD
--            FROM GABVATENAALL A,
--                 (SELECT KOJIN_NO, HOGOSYA_KOJIN_NO FROM GKBTGAKUREIBO D
--                  WHERE D.KOJIN_NO = I_KOJIN_NO
--                     AND D.RIREKI_RENBAN = (SELECT MAX(C.RIREKI_RENBAN)
--                                      FROM GKBTGAKUREIBO C
--                                     WHERE C.KOJIN_NO = D.KOJIN_NO
--                                       AND C.SYS_SAKUSEIBI < NKAISHI_SEIREKI)) B
--           WHERE A.KOJIN_NO = B.HOGOSYA_KOJIN_NO
--             AND A.RIREKI_RENBAN = (SELECT MAX(AA.RIREKI_RENBAN)
--                                      FROM GABVATENAALL AA
--                                     WHERE AA.KOJIN_NO = A.KOJIN_NO
--                                       AND AA.SYS_SAKUSEIBI < NKAISHI_SEIREKI);
--        END IF;
--        RETURN TRUE;
--     EXCEPTION
--        WHEN NO_DATA_FOUND THEN
--            VKYUCHOMEI := '';
--            VKYUBANCHI := '';
--            VKYUKATAGAKI := '';
--            NKYUSHOGAKU_CD := 0;
--            NKYUCHUGAKU_CD := 0;
--            NKYUGYOSEIKU_CD := 0;
--            RETURN TRUE;
--        WHEN OTHERS THEN
           -- SQL情報取得
--            N_SQL_CODE := SQLCODE;
--            V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
--            RETURN FALSE;
--     END FUNC_GET_KYU2;
--  2024/07/01 ZCZL.lwy Delete End
    --------------------------------------------------------
    --  機能概要      : 学齢簿より保護者個人番号を取得
    --  パラメータ    : ・・・
    --  モジュール区分: 内部関数
    --  戻り値        : データあり 0,その他 <>0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_HOGOSHA(I_KOJIN_NO IN NUMBER,
                              O_HOGOSHA_KOJIN_NO OUT NUMBER,O_IDOJIKO OUT NVARCHAR2,O_SHUGAKU OUT NVARCHAR2,
                              O_ZOKUGARA1 OUT NUMBER,O_ZOKUGARA2 OUT NUMBER,O_ZOKUGARA3 OUT NUMBER,O_ZOKUGARA4 OUT NUMBER,
                              O_HOGOSYA_ZOKUGARA1 OUT NUMBER,O_HOGOSYA_ZOKUGARA2 OUT NUMBER,O_HOGOSYA_ZOKUGARA3 OUT NUMBER,
                              O_HOGOSYA_ZOKUGARA4 OUT NUMBER,
                              O_SYOGAKO_TENGAKU_BI OUT NUMBER,
                              O_TYUGAKO_TENGAKU_BI OUT NUMBER,
                              O_SYOGAKO_TENNYUGAKU_BI OUT NUMBER,
                              O_TYUGAKO_TENNYUGAKU_BI OUT NUMBER
                              ) RETURN BOOLEAN IS
    BEGIN
        -- SQL情報取得
        SELECT HOGOSYA_KOJIN_NO
               ,IDOJIKO
               ,SHUGAKU
               ,ZOKUGARA1
               ,ZOKUGARA2
               ,ZOKUGARA3
               ,ZOKUGARA4
               ,HOGOSYA_ZOKUGARA1
               ,HOGOSYA_ZOKUGARA2
               ,HOGOSYA_ZOKUGARA3
               ,HOGOSYA_ZOKUGARA4
               ,SYOGAKO_TENGAKU_BI
               ,TYUGAKO_TENGAKU_BI
               ,SYOGAKO_TENNYUGAKU_BI
               ,TYUGAKO_TENNYUGAKU_BI
          INTO O_HOGOSHA_KOJIN_NO
               ,O_IDOJIKO
               ,O_SHUGAKU
               ,O_ZOKUGARA1
               ,O_ZOKUGARA2
               ,O_ZOKUGARA3
               ,O_ZOKUGARA4
               ,O_HOGOSYA_ZOKUGARA1
               ,O_HOGOSYA_ZOKUGARA2
               ,O_HOGOSYA_ZOKUGARA3
               ,O_HOGOSYA_ZOKUGARA4
               ,O_SYOGAKO_TENGAKU_BI
               ,O_TYUGAKO_TENGAKU_BI
               ,O_SYOGAKO_TENNYUGAKU_BI
               ,O_TYUGAKO_TENNYUGAKU_BI
          FROM GKBTGAKUREIBO A
         WHERE A.KOJIN_NO = I_KOJIN_NO
           AND A.RIREKI_RENBAN = (SELECT MAX(B.RIREKI_RENBAN)
                                    FROM GKBTGAKUREIBO B
                                   WHERE B.KOJIN_NO = A.KOJIN_NO
                                     AND B.SYS_SAKUSEIBI <= NSHURYO_SEIREKI);
        RETURN (B_RTN);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            O_HOGOSHA_KOJIN_NO := 0;
            O_IDOJIKO := '';
            O_SHUGAKU := '';
            O_ZOKUGARA1 := 0;
            O_ZOKUGARA2 := 0;
            O_ZOKUGARA3 := 0;
            O_ZOKUGARA4 := 0;
            O_HOGOSYA_ZOKUGARA1 := 0;
            O_HOGOSYA_ZOKUGARA2 := 0;
            O_HOGOSYA_ZOKUGARA3 := 0;
            O_HOGOSYA_ZOKUGARA4 := 0;
            O_SYOGAKO_TENGAKU_BI := 0;
            O_TYUGAKO_TENGAKU_BI := 0;
            O_SYOGAKO_TENNYUGAKU_BI := 0;
            O_TYUGAKO_TENNYUGAKU_BI := 0;
              RETURN (B_RTN);
        WHEN OTHERS THEN
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
            O_HOGOSHA_KOJIN_NO := 0;
            O_IDOJIKO := '';
            O_SHUGAKU := '';
            O_ZOKUGARA1 := 0;
            O_ZOKUGARA2 := 0;
            O_ZOKUGARA3 := 0;
            O_ZOKUGARA4 := 0;
            O_HOGOSYA_ZOKUGARA1 := 0;
            O_HOGOSYA_ZOKUGARA2 := 0;
            O_HOGOSYA_ZOKUGARA3 := 0;
            O_HOGOSYA_ZOKUGARA4 := 0;
            O_SYOGAKO_TENGAKU_BI := 0;
            O_TYUGAKO_TENGAKU_BI := 0;
            O_SYOGAKO_TENNYUGAKU_BI := 0;
            O_TYUGAKO_TENNYUGAKU_BI := 0;
            B_RTN := FALSE;
             RETURN (B_RTN);
    END FUNC_GET_HOGOSHA;
    --------------------------------------------------------
    --  機能概要      : GABTJUKIJUSHOより指定した連番の住所を取得
    --                  取得した値は外部変数に格納される
    --  パラメータ    : I_KOJIN_NO
    --                  I_RENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 成功 TRUE,失敗 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_JUSHO(I_KOJIN_NO IN NUMBER,
                            I_RENBAN IN NUMBER) RETURN BOOLEAN
    IS
    BEGIN
         SELECT CHOMEI,
                BANCHI,
                KATAGAKI
           INTO VKYUCHOMEI,
                VKYUBANCHI,
                VKYUKATAGAKI
           FROM GABTJUKIJUSHO
          WHERE KOJIN_NO = I_KOJIN_NO
            AND JUSHO_REN = I_RENBAN;
       RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            VKYUCHOMEI := '';
            VKYUBANCHI := '';
            VKYUKATAGAKI := '';
            RETURN TRUE;
        WHEN OTHERS THEN
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
            RETURN FALSE;
    END FUNC_GET_JUSHO;
    --------------------------------------------------------
    --  機能概要      : 生年月日から学年を求める
    --  パラメータ    : I_SEINENGAPI
    --  モジュール区分: 内部関数
    --  戻り値        : 1 - 6  ...  小学生
    --                  7 - 9  ...  中学生
    --                  0      ...  該当なし（発生し得ない）
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_GAKUNEN(I_SEINENGAPI IN NUMBER) RETURN NUMBER
    IS
        INENREI_KIJUNBI  PLS_INTEGER;  -- 年齢基準日
        INENREI          PLS_INTEGER;  -- 年齢
        IGAKUNEN         PLS_INTEGER;  -- 学年
    BEGIN
        INENREI_KIJUNBI := (INENDO + 1) * 10000 + 331; -- 年齢基準日
        IF I_SEINENGAPI = 0 THEN
          INENREI := NULL;
        ELSE
          INENREI := KKAPK0020.FAgeGet( TO_CHAR(I_SEINENGAPI), TO_CHAR(INENREI_KIJUNBI) );
        END IF;

        IF INENREI >= 7  AND
           INENREI <= 15 THEN
          IGAKUNEN := INENREI - 6;
        ELSE
          IGAKUNEN := 0;
        END IF;
        RETURN IGAKUNEN;
    END FUNC_GET_GAKUNEN;
    --------------------------------------------------------
    --  機能概要      : 学年番号を印字用の文字列に変換する
    --  パラメータ    : I_NGAKUNEN
    --  モジュール区分: 内部関数
    --  戻り値        : 学年の文字列
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_GAKUNEN_STR(I_NGAKUNEN IN NUMBER) RETURN NVARCHAR2
    IS
    BEGIN
        IF I_NGAKUNEN = 1 THEN
            RETURN '小１';
        ELSIF I_NGAKUNEN = 2 THEN
            RETURN '小２';
        ELSIF I_NGAKUNEN = 3 THEN
            RETURN '小３';
        ELSIF I_NGAKUNEN = 4 THEN
            RETURN '小４';
        ELSIF I_NGAKUNEN = 5 THEN
            RETURN '小５';
        ELSIF I_NGAKUNEN = 6 THEN
            RETURN '小６';
        ELSIF I_NGAKUNEN = 7 THEN
            RETURN '中１';
        ELSIF I_NGAKUNEN = 8 THEN
            RETURN '中２';
        ELSIF I_NGAKUNEN = 9 THEN
            RETURN '中３';
        ELSE
            RETURN '入学';
        END IF;
    END FUNC_GET_GAKUNEN_STR;
    --------------------------------------------------------
    --  機能概要      : 内部ワークテーブル作成
    --  パラメータ    : I_KOJIN_NO
    --                  O_KANA,O_KANJI,O_HONMYO_KANA,O_HONMYO_KANJI
    --  モジュール区分: 内部関数
    --  戻り値        : 成功 TRUE,失敗 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    PROCEDURE PROC_GET_SHIMEI(I_KOJIN_NO IN NUMBER
                             ,O_KANA     OUT NVARCHAR2
                             ,O_KANJI    OUT NVARCHAR2
                             ,O_HONMYO_KANA OUT NVARCHAR2
                             ,O_HONMYO_KANJI OUT NVARCHAR2
                              )
    IS
    BEGIN
      SELECT SHIMEI_KANA
            ,SHIMEI_KANJI
            ,HONMYO_KANA
            ,HONMYO_KANJI
        INTO O_KANA
            ,O_KANJI
            ,O_HONMYO_KANA
            ,O_HONMYO_KANJI
       FROM GABVATENAALL A
      WHERE A.KOJIN_NO = I_KOJIN_NO
        AND A.RIREKI_RENBAN = (SELECT MAX(AA.RIREKI_RENBAN)
                                 FROM GABVATENAALL AA
                                WHERE AA.KOJIN_NO = A.KOJIN_NO
                                  AND AA.SYS_SAKUSEIBI <= NSHURYO_SEIREKI);
    END PROC_GET_SHIMEI;
    --------------------------------------------------------
    --  機能概要      : 制御コンスタントのパラメータを配列に指定された区分からメモ内容を取得
    --  パラメータ    : I_JIDO_KOJIN_NO
    --  モジュール区分: 内部関数
    --  戻り値        : 成功 TRUE,失敗 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_MEMO(I_JIDO_KOJIN_NO IN NUMBER
                            ) RETURN NVARCHAR2
    IS
      VMEMO              NVARCHAR2(400);
      W_MEMOKBN          PLS_INTEGER;       --区分
      W_MEMOKBN_CHI      PLS_INTEGER;       --区分の値
      VSQL               NVARCHAR2(9000);       --  SQL文
      W_IMOJISU          PLS_INTEGER;

      -- テーブル設定
      TYPE T_AAMEMO IS REF CURSOR;
      CAAMEMO    T_AAMEMO;
      CR_AAMEMO        GADTMEMO%ROWTYPE;


    BEGIN
      --初期化
      VMEMO := '';
      W_MEMOKBN := 0;
      W_MEMOKBN_CHI := 0;
      W_IMOJISU     := 0;

      o_AAMEMOKBN := A_CONS_PRM();
      IAAMEMOKBN  := KKAPK0030.FPRMSHUTOKU('GKB' ,'00AA_MEMO',0 ,o_AAMEMOKBN ,o_LENGTH);
      IF IAAMEMOKBN = 0 THEN
        W_MEMOKBN := o_AAMEMOKBN(1);
        W_MEMOKBN_CHI := o_AAMEMOKBN(2);
      END IF;

      IF W_MEMOKBN >= 1 AND W_MEMOKBN <= 3 THEN
        --SQL作成
        VSQL := '';
        VSQL := VSQL || '';
        VSQL := VSQL || ' SELECT * FROM GADTMEMO  ';
        VSQL := VSQL || '  WHERE   KOJINNO =  '|| I_JIDO_KOJIN_NO  ;
        VSQL := VSQL || '    AND   GYOMUCD =  ' || '''' || 'GKB' || '''';
        IF W_MEMOKBN = 1 THEN
          VSQL := VSQL || '    AND   KBN1 =  '|| '''' || W_MEMOKBN_CHI || '''';
        ELSIF W_MEMOKBN = 2 THEN
          VSQL := VSQL || '    AND   KBN2 =  '|| '''' || W_MEMOKBN_CHI || '''';
        ELSE
          VSQL := VSQL || '    AND   KBN3 =  '|| '''' || W_MEMOKBN_CHI || '''';
        END IF;
        VSQL := VSQL || '  ORDER BY  RENBAN ';
        OPEN CAAMEMO FOR TO_CHAR(VSQL);
        LOOP
          FETCH CAAMEMO INTO CR_AAMEMO;
          EXIT WHEN CAAMEMO%NOTFOUND;

            IF W_IMOJISU = 0 THEN
              VMEMO := CR_AAMEMO.MEMO;
            ELSIF (400 - W_IMOJISU) >= LENGTH( CR_AAMEMO.MEMO ) THEN
              VMEMO := VMEMO || CR_AAMEMO.MEMO;
            ELSE
              EXIT;
            END IF;
            W_IMOJISU := W_IMOJISU + LENGTH( CR_AAMEMO.MEMO );
        END LOOP;
      ELSE
        VMEMO := '';
      END IF;

      RETURN VMEMO;
    EXCEPTION
      WHEN OTHERS THEN
          -- SQL情報取得
          N_SQL_CODE := SQLCODE;
          V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
          DBMS_OUTPUT.PUT_LINE('FUNC_GET_MEMO ERROR = ' || VSQL);
          RETURN '';
    END FUNC_GET_MEMO;

    --------------------------------------------------------
    --  機能概要      : 内部ワークテーブル作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 成功 TRUE,失敗 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_CREATE_INTERNAL RETURN BOOLEAN
    IS
        --------------------
        -- カーソル定義
        --------------------
        CURSOR CIDORUIKEI IS
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
--          SELECT A.RUIKEI_RENBAN,
--                 B.RIREKI_RENBAN,
--                 A.IDO_JIYU,
--                 A.KOJIN_NO,
          SELECT G.KOJIN_NO,
                 B.SHIMEI_KANA,
                 B.SHIMEI_KANJI,
                 B.SEINENGAPI,
                 G.SEIBETSU,
                 CASE
                   WHEN G.GAKKO_KBN_CD = '3' THEN G.KUIKIGAI_CD
                   WHEN G.GAKKO_KBN_CD = '4' THEN G.YOGOGAKO_CD
                   WHEN G.GAKKO_KBN_CD = '5' THEN G.KUNISHIRITSU_CD
                   ELSE G.SYOGAKO_CD
                 END AS SYOGAKO_CD,
                 G.TYUGAKO_CD,
--                 B.SEIBETSU,
--                 B.SHOGAKU_CD,
--                 B.CHUGAKU_CD,
--  2024/07/01 ZCZL.lwy Update End
                 B.CHOMEI,
                 B.BANCHI,
                 B.KATAGAKI,
                 B.SETAI_NO,
                 B.SANTEIDANTAI_CD,
                 B.IDO_TODOKE_BI,
                 B.IDO_BI,
                 B.HONMYO_KANA,
                 B.HONMYO_KANJI,
                 B.GYOSEIKU_CD,
                 B.TENNYUMAE_REN,
                 B.JINKAKU_KBN
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
                 ,H.SHIMEI_KANA AS HOGOSHA_SHIMEI_KANA,                                
                 H.SHIMEI_KANJI AS HOGOSHA_SHIMEI_KANJI,                           
                 H.HONMYO_KANA AS HOGOSHA_HONMYO_KANA,                         
                 H.HONMYO_KANJI AS HOGOSHA_HONMYO_KANJI,
                 G.RIREKI_RENBAN,
                 G.GAKKO_KBN_CD,
                 G.GAKUNEN,
                 G.HOGOSYA_KOJIN_NO,
                 G.GRB_HENKO_TODOKEDE_BI,
                 G.GRB_HENKO_BI,
                 G.TENNYUMAE_GAKKO_KBN,
                 G.TENNYUMAE_GAKKO_CD,
                 G.TENNYUMAE_GAKUNEN,
                 G.GRB_HENKO_JIYU
--            FROM JIBTIDORUIKEI A,
--                 GABVATENAALL B
            FROM GKBTGAKUREIBO G 
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00136対応
--                 INNER JOIN GABVATENAALL H
                 INNER JOIN GABVATENAALL_B H
                       ON G.HOGOSYA_KOJIN_NO = H.KOJIN_NO AND G.HOGOSYA_IDOJI_RIREKI_RENBAN = H.RIREKI_RENBAN
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00136対応
--                 INNER JOIN GABVATENAALL B
                 INNER JOIN GABVATENAALL_B B
                       ON  G.KOJIN_NO = B.KOJIN_NO AND G.IDOJI_ATENA_RIREKI_RENBAN = B.RIREKI_RENBAN 
--           WHERE A.IDO_JIYU IN (11,21,31,32,33,34,41,42)
           WHERE G.SAKUJO_FLG = 0
             AND ((G.SYS_SAKUSEIBI >= NKAISHI_SEIREKI AND G.SYS_SAKUSEIBI <= NSHURYO_SEIREKI)
                   OR
                  (G.SYS_KOSHINBI >= NKAISHI_SEIREKI AND G.SYS_KOSHINBI <= NSHURYO_SEIREKI))
             AND G.GRB_HENKO_TODOKEDE_BI >= g_vJYOUKEN5
             AND G.GRB_HENKO_TODOKEDE_BI <= g_vJYOUKEN6
             AND G.GRB_HENKO_BI >= g_vJYOUKEN7
             AND G.GRB_HENKO_BI <= g_vJYOUKEN8
           ORDER BY G.GRB_HENKO_JIYU, G.GRB_HENKO_BI, B.SETAI_NO, B.SEINENGAPI, G.KOJIN_NO, G.RIREKI_RENBAN;
--             AND A.SYS_SAKUSEIBI BETWEEN NKAISHI_SEIREKI AND NSHURYO_SEIREKI
--             AND A.KOJIN_NO = B.KOJIN_NO
--             AND B.SEINENGAPI BETWEEN NSEINENCHU_KAISHI AND NSEINENSHO_SHURYO
--             AND A.RUIKEI_RENBAN =
--                 (SELECT MAX(AA.RUIKEI_RENBAN)
--                    FROM JIBTIDORUIKEI AA
--                   WHERE AA.IDO_JIYU IN (11,21,31,32,33,34,41,42)
--                     AND AA.KOJIN_NO = A.KOJIN_NO
--                     AND AA.SYS_SAKUSEIBI BETWEEN NKAISHI_SEIREKI AND NSHURYO_SEIREKI)
--             AND B.RIREKI_RENBAN =
--                 (SELECT MAX(BB.RIREKI_RENBAN)
--                    FROM GABVATENAALL BB
--                   WHERE BB.KOJIN_NO = A.KOJIN_NO
--                     AND BB.IDO_JIYU IN  (11,21,31,32,33,34,41,42)
--                     AND BB.SYS_SAKUSEIBI = A.SYS_SAKUSEIBI)
--           ORDER BY A.IDO_JIYU, B.IDO_BI, B.SETAI_NO, B.SEINENGAPI, A.KOJIN_NO;
--  2024/07/01 ZCZL.lwy Update End
        --------------------
        -- 変数定義
        --------------------
        BRET        BOOLEAN;
        W_GROUP_NO          NUMBER;
        W_LAST_IDO_JIYU     NUMBER;
        W_LAST_SETAI_NO     NUMBER;
        W_LAST_IDO_BI       NUMBER;
        W_LAST_SHOCHU_KBN   NUMBER;
        W_HOGOSHA           NUMBER;
        W_KANA              NVARCHAR2(180);
        W_KANJI             NVARCHAR2(180);
        W_HONMYO_KANA       NVARCHAR2(180);
        W_HONMYO_KANJI      NVARCHAR2(180);
        o_VZOKUGARAMEI      NVARCHAR2(30);
        o_IHERR             PLS_INTEGER;
        IHERR               PLS_INTEGER;
        O_HOGOSHA_KOJIN_NO  NUMBER;
        O_IDOJIKO           NVARCHAR2(300);
        O_SHUGAKU           NVARCHAR2(300);
        O_ZOKUGARA1         NUMBER;
        O_ZOKUGARA2         NUMBER;
        O_ZOKUGARA3         NUMBER;
        O_ZOKUGARA4         NUMBER;
        O_HOGOSYA_ZOKUGARA1 NUMBER;
        O_HOGOSYA_ZOKUGARA2 NUMBER;
        O_HOGOSYA_ZOKUGARA3 NUMBER;
        O_HOGOSYA_ZOKUGARA4 NUMBER;
        NSYOGAKO_TENGAKU_BI     NUMBER;
        NTYUGAKO_TENGAKU_BI     NUMBER;
        NSYOGAKO_TENNYUGAKU_BI  NUMBER;
        NTYUGAKO_TENNYUGAKU_BI  NUMBER;
        W_HOGOSHA1           NUMBER;
--  2024/10/28 ZCZL.WANGMING DELETE 0.3.000.005:IT_GKB_00396対応
--        DBG PLS_INTEGER;
    BEGIN
        --------------------
        -- 基準日より、小中学生の生年月日の範囲を求める
        --------------------
        PROC_GET_SEINENGAPI;
        W_GROUP_NO        := 0;
        W_LAST_IDO_JIYU   := 0;
        W_LAST_SETAI_NO   := 0;
        W_LAST_IDO_BI     := 0;
        W_LAST_SHOCHU_KBN := 0;
        IRTN              := 0;
        FOR CR_IDOREC IN CIDORUIKEI LOOP
            IKENSU_IN := IKENSU_IN + 1;
--  2024/10/28 ZCZL.WANGMING DELETE 0.3.000.005:IT_GKB_00396対応
--            DBG := CR_IDOREC.KOJIN_NO;
            RWK_IDO :=  NULL;       -- 内部ワークテーブルレコード初期化
            -- 同一通知書内に記載するかどうかを決めるために、あらかじめ学年を取得しておく
--  2024/07/01 ZCZL.lwy Delete Start 0.3.000.000:新WizLIFE２次開発（標準化）
--            RWK_IDO.GAKUNEN     := FUNC_GET_GAKUNEN(CR_IDOREC.SEINENGAPI);
--            IF RWK_IDO.GAKUNEN <= 6 THEN
--                RWK_IDO.SHOCHU_KBN := 1;
--            ELSE
--                RWK_IDO.SHOCHU_KBN := 2;
--            END IF;
--             IF W_LAST_IDO_JIYU <> CR_IDOREC.IDO_JIYU
--                   OR W_LAST_SETAI_NO <> CR_IDOREC.SETAI_NO
--                   OR W_LAST_IDO_BI <> CR_IDOREC.IDO_BI
--                   OR W_LAST_SHOCHU_KBN  <> RWK_IDO.SHOCHU_KBN THEN
--  2024/07/01 ZCZL.lwy Delete End
                W_GROUP_NO := W_GROUP_NO + 1;
--  2024/07/01 ZCZL.lwy Delete Start 0.3.000.000:新WizLIFE２次開発（標準化）
--                W_LAST_IDO_JIYU := CR_IDOREC.IDO_JIYU;
--                W_LAST_SETAI_NO := CR_IDOREC.SETAI_NO;
--                W_LAST_IDO_BI := CR_IDOREC.IDO_BI;
--                W_LAST_SHOCHU_KBN := RWK_IDO.SHOCHU_KBN;
--             END IF;
             BRET := FUNC_GET_KYU(CR_IDOREC.KOJIN_NO, CR_IDOREC.RIREKI_RENBAN);
             IF NOT BRET THEN
                 RETURN FALSE;
             END IF;
--  2024/07/01 ZCZL.lwy Delete End
            --------------------
            -- 作成する通知書の種類を決める
            --------------------
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
            RWK_IDO.SHOCHU_KBN := SUBSTR(CR_IDOREC.GAKKO_KBN_CD,1,1);
            RWK_IDO.OLD_SHOCHU_KBN := SUBSTR(NKYUGAKKO_KBN_CD,1,1);
            IF CR_IDOREC.GRB_HENKO_JIYU BETWEEN 1 AND 3 THEN
              RWK_IDO.TSUCHISHO_KBN := 1;
            ELSIF CR_IDOREC.GRB_HENKO_JIYU BETWEEN 4 AND 5 THEN
              RWK_IDO.TSUCHISHO_KBN := 2;
            ELSIF CR_IDOREC.GRB_HENKO_JIYU = 6 THEN
              RWK_IDO.TSUCHISHO_KBN := 3;
            ELSE RWK_IDO.TSUCHISHO_KBN := 4;
            END IF;
            RWK_IDO.IDO_JIYU := CR_IDOREC.GRB_HENKO_JIYU;         
--             IF CR_IDOREC.IDO_JIYU = 11 THEN    -- 転入学
--                 RWK_IDO.TSUCHISHO_KBN := 1;
                 BRET := FUNC_GET_JUSHO(CR_IDOREC.KOJIN_NO, CR_IDOREC.TENNYUMAE_REN);
                 IF NOT BRET THEN
                     RETURN FALSE;
                 END IF;
--                 NKYUSHOGAKU_CD := 0;
--                 NKYUCHUGAKU_CD := 0;
--                 NKYUGYOSEIKU_CD := 0;
--             ELSIF CR_IDOREC.IDO_JIYU = 21 THEN  -- 転出学
--                 RWK_IDO.TSUCHISHO_KBN := 2;
--             ELSIF CR_IDOREC.IDO_JIYU BETWEEN 31 AND 34 THEN -- 転居
                --------------------
                -- 転居の場合、学校区が変わっていれば、転入、転出それぞれに記載
                -- 学校区が変わってなければ、学校区内異動
                --------------------
--                IF RWK_IDO.GAKUNEN <= 6 THEN
                    -- 小学生
--                     IF CR_IDOREC.SHOGAKU_CD <> NKYUSHOGAKU_CD THEN
--                         RWK_IDO.TSUCHISHO_KBN := 3;
--                     ELSE
--                         RWK_IDO.TSUCHISHO_KBN := 4;
--                     END IF;
--                 ELSE
                    -- 中学生
--                     IF CR_IDOREC.CHUGAKU_CD <> NKYUCHUGAKU_CD THEN
--                         RWK_IDO.TSUCHISHO_KBN := 3;
--                     ELSE
--                         RWK_IDO.TSUCHISHO_KBN := 4;
--                     END IF;
--                 END IF;
--             ELSIF CR_IDOREC.IDO_JIYU IN (41,42) THEN -- 職権修正、地番修正の場合、学校区内異動
--                 RWK_IDO.TSUCHISHO_KBN := 4;
--             END IF;
            RWK_IDO.GROUP_NO     := W_GROUP_NO;
--            RWK_IDO.IDO_JIYU     := CR_IDOREC.IDO_JIYU;
--  2024/07/01 ZCZL.lwy Update End
            RWK_IDO.KOJIN_NO     := CR_IDOREC.KOJIN_NO;
            RWK_IDO.SHIMEI_KANA  := CR_IDOREC.SHIMEI_KANA;
            RWK_IDO.SHIMEI_KANJI := CR_IDOREC.SHIMEI_KANJI;
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
            RWK_IDO.OLD_SHIMEI_KANA := NKYUSHIMEI_KANA;
            RWK_IDO.OLD_SHIMEI_KANJI := NKYUSHIMEI_KANJI;
--  2024/07/01 ZCZL.lwy Add End
            RWK_IDO.SETAI_NO     := CR_IDOREC.SETAI_NO;
            RWK_IDO.SEINENGAPI   := CR_IDOREC.SEINENGAPI;
            RWK_IDO.JINKAKU_KBN  := CR_IDOREC.JINKAKU_KBN;
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
--            RWK_IDO.GAKUNEN      := FUNC_GET_GAKUNEN(CR_IDOREC.SEINENGAPI);
            RWK_IDO.GAKUNEN      := FUNC_GET_GAKUNEN_STR(CR_IDOREC.GAKUNEN);
            IF CR_IDOREC.GRB_HENKO_JIYU = 2 THEN
              RWK_IDO.OLD_GAKUNEN := FUNC_GET_GAKUNEN_STR(CR_IDOREC.TENNYUMAE_GAKUNEN);
            ELSE
              RWK_IDO.OLD_GAKUNEN := FUNC_GET_GAKUNEN_STR(NKYUGAKUNEN);
            END IF;

--             IF CR_IDOREC.IDO_JIYU = 21 THEN
--                 RWK_IDO.SHOGAKU_CD   := 0;
--                 RWK_IDO.CHUGAKU_CD   := 0;
--             ELSE
--                 RWK_IDO.SHOGAKU_CD   := CR_IDOREC.SHOGAKU_CD;
--                 RWK_IDO.CHUGAKU_CD   := CR_IDOREC.CHUGAKU_CD;
--             END IF;
            RWK_IDO.SHOGAKU_CD   := CR_IDOREC.SYOGAKO_CD;
            RWK_IDO.CHUGAKU_CD   := CR_IDOREC.TYUGAKO_CD;
            RWK_IDO.SEIBETSU     := CR_IDOREC.SEIBETSU;
            RWK_IDO.OLD_SHOGAKU_CD := NKYUSHOGAKU_CD;
            RWK_IDO.OLD_CHUGAKU_CD := NKYUCHUGAKU_CD;
            RWK_IDO.OLD_GYOSEIKUMEI   := GAAPK0030.FGYOSEIKUMEI(1, NKYUGYOSEIKU_CD);
            RWK_IDO.CHOMEI       := CR_IDOREC.CHOMEI;
            RWK_IDO.BANCHI       := CR_IDOREC.BANCHI;
            RWK_IDO.KATAGAKI     := CR_IDOREC.KATAGAKI;
            RWK_IDO.KYUCHOMEI    := VKYUCHOMEI;
            RWK_IDO.KYUBANCHI    := VKYUBANCHI;
            RWK_IDO.KYUKATAGAKI  := VKYUKATAGAKI;
            RWK_IDO.HOGOSHA_NO    := CR_IDOREC.HOGOSYA_KOJIN_NO;
            RWK_IDO.HOGOSHA_KANA  := CR_IDOREC.HOGOSHA_SHIMEI_KANA;
            RWK_IDO.HOGOSHA_KANJI := CR_IDOREC.HOGOSHA_SHIMEI_KANJI;
            RWK_IDO.OLD_HOGOSHA_KANA := NKYUHOGOSHA_SHIMEI_KANA;
            RWK_IDO.OLD_HOGOSHA_KANJI := NKYUHOGOSHA_SHIMEI_KANJI;           
--             B_RTN := FUNC_GET_HOGOSHA(CR_IDOREC.KOJIN_NO,
--                                       O_HOGOSHA_KOJIN_NO,
--                                       O_IDOJIKO,
--                                       O_SHUGAKU,
--                                       O_ZOKUGARA1,
--                                       O_ZOKUGARA2,
--                                       O_ZOKUGARA3,
--                                       O_ZOKUGARA4,
--                                       O_HOGOSYA_ZOKUGARA1,
--                                       O_HOGOSYA_ZOKUGARA2,
--                                       O_HOGOSYA_ZOKUGARA3,
--                                       O_HOGOSYA_ZOKUGARA4,
--                                       NSYOGAKO_TENGAKU_BI,
--                                       NTYUGAKO_TENGAKU_BI,
--                                       NSYOGAKO_TENNYUGAKU_BI,
--                                       NTYUGAKO_TENNYUGAKU_BI);
--             W_HOGOSHA := O_HOGOSHA_KOJIN_NO;
            -- 保護者個人番号が登録されている場合は宛名より氏名を取得する
--             IRTN := GAAPK0030.FGETATENA(CR_IDOREC.KOJIN_NO,
--                                       'GKB',
--                                       NKIJUNBI,
--                                       RD,
--                                       RE);
--             VJINKAKU_KBN := RD.JINKAKU_KBN;
--             IF VJINKAKU_KBN = 1 THEN
--                 HOGOSHA_KBN := GKBPK00010.FGKJHGS(NKIJUNBI, CR_IDOREC.KOJIN_NO, W_HOGOSHA1,VSHIMEI_KANJI);
--             ELSE
--                 HOGOSHA_KBN := GKBPK00010.FHOGOSHA(NKIJUNBI, CR_IDOREC.KOJIN_NO, W_HOGOSHA1);
--             END IF;
--             IF W_HOGOSHA > 1 THEN
--                 RWK_IDO.HOGOSHA_NO    := W_HOGOSHA;
--                 PROC_GET_SHIMEI(W_HOGOSHA, W_KANA, W_KANJI,W_HONMYO_KANA,W_HONMYO_KANJI);
--                 RWK_IDO.HOGOSHA_KANA  := W_KANA;
--                 RWK_IDO.HOGOSHA_KANJI := W_KANJI;
--                 RWK_IDO.HOGOSHA_HONMYO_KANA := W_HONMYO_KANA;
--                 RWK_IDO.HOGOSHA_HONMYO_KANJI := W_HONMYO_KANJI;
            -- 保護者個人番号が登録されていない場合は保護者判定サブルーチンを使用
--             ELSIF HOGOSHA_KBN = 0 THEN
--                 RWK_IDO.HOGOSHA_NO    := W_HOGOSHA1;
--                 PROC_GET_SHIMEI(W_HOGOSHA1, W_KANA, W_KANJI,W_HONMYO_KANA,W_HONMYO_KANJI);
--                 RWK_IDO.HOGOSHA_KANA  := W_KANA;
--                 RWK_IDO.HOGOSHA_KANJI := W_KANJI;
--                 RWK_IDO.HOGOSHA_HONMYO_KANA := W_HONMYO_KANA;
--                 RWK_IDO.HOGOSHA_HONMYO_KANJI := W_HONMYO_KANJI;
--             ELSE
--                 RWK_IDO.HOGOSHA_NO    := 0;
--                 RWK_IDO.HOGOSHA_KANA  := '';
--                 RWK_IDO.HOGOSHA_KANJI := '';
--                 RWK_IDO.HOGOSHA_HONMYO_KANA := '';
--                 RWK_IDO.HOGOSHA_HONMYO_KANJI := '';
--             END IF;
            RWK_IDO.SANTEIDANTAI_CD := CR_IDOREC.SANTEIDANTAI_CD;

--            RWK_IDO.TODOKE_BI       := CR_IDOREC.IDO_TODOKE_BI;
--            RWK_IDO.IDO_BI          := CR_IDOREC.IDO_BI;
            RWK_IDO.TODOKE_BI       := CR_IDOREC.GRB_HENKO_TODOKEDE_BI;
            RWK_IDO.IDO_BI          := CR_IDOREC.GRB_HENKO_BI;
            RWK_IDO.HONMYO_KANA     := CR_IDOREC.HONMYO_KANA;    -- 児童氏名本名かな
            RWK_IDO.HONMYO_KANJI    := CR_IDOREC.HONMYO_KANJI;   -- 児童氏名本名漢字
            RWK_IDO.HOGOSHA_HONMYO_KANA := CR_IDOREC.HOGOSHA_HONMYO_KANA;
            RWK_IDO.HOGOSHA_HONMYO_KANJI := CR_IDOREC.HOGOSHA_HONMYO_KANJI;
--            RWK_IDO.IDOJIKO         := O_IDOJIKO;           -- 異動事項
--            RWK_IDO.SHUGAKU         := O_SHUGAKU;           -- 就学状況
--            IHERR := GKBFKZKGMGET(1,O_ZOKUGARA1,O_ZOKUGARA2,O_ZOKUGARA3,O_ZOKUGARA4,o_VZOKUGARAMEI,o_IHERR);
--            RWK_IDO.HOGOSHA_TSUDUKIGARA  := o_VZOKUGARAMEI;     -- 保護者との関係
            RWK_IDO.HOGOSHA_TSUDUKIGARA  := NULL;     -- 保護者との関係
--            IHERR := GKBFKZKGMGET(2,O_HOGOSYA_ZOKUGARA1,O_HOGOSYA_ZOKUGARA2,O_HOGOSYA_ZOKUGARA3,O_HOGOSYA_ZOKUGARA4,o_VZOKUGARAMEI,o_IHERR);
--            RWK_IDO.TSUDUKIGARA  := o_VZOKUGARAMEI;             -- 生徒との関係
            RWK_IDO.TSUDUKIGARA     := NULL;             -- 生徒との関係
            RWK_IDO.IDOJIKO         := NULL;           -- 異動事項
            RWK_IDO.SHUGAKU         := NULL;           -- 就学状況
--             IF CR_IDOREC.IDO_JIYU = 21 THEN
--                 RWK_IDO.GYOSEIKUMEI     := '';
--             ELSE
                 RWK_IDO.GYOSEIKUMEI     := GAAPK0030.FGYOSEIKUMEI(1, CR_IDOREC.GYOSEIKU_CD);
--             END IF;
--            IF IHAKKO_KBN = 1 AND
--                CR_IDOREC.IDO_JIYU BETWEEN 31 AND 34 AND
--                RWK_IDO.TSUCHISHO_KBN = 4 THEN
                -- 発行区分（しない）、転居、学校区内異動　のときは発行しない
--                NULL;
--            ELSE
                --転入学年月日
--                IF RWK_IDO.TSUCHISHO_KBN = 1 THEN
--                    RWK_IDO.TENNYUGAKU_BI_MEI := '転入学年月日';
                    RWK_IDO.TENNYUGAKU_BI_MEI := NULL;
                    RWK_IDO.TENNYUGAKU_BI     := NULL;
                    RWK_IDO.HOGOSHA_CHOMEI    := NULL;
                    RWK_IDO.HOGOSHA_BANCHI    := NULL;
                    RWK_IDO.HOGOSHA_KATAGAKI  := NULL;
                    RWK_IDO.HOGOSHA_KYUCHOMEI := NULL;
                    RWK_IDO.HOGOSHA_KYUBANCHI := NULL;
                    RWK_IDO.HOGOSHA_KYUKATAGAKI := NULL;
--                    IF RWK_IDO.SHOCHU_KBN = 1 THEN
--                      RWK_IDO.TENNYUGAKU_BI := NSYOGAKO_TENNYUGAKU_BI;
--                    ELSE
--                      RWK_IDO.TENNYUGAKU_BI := NTYUGAKO_TENNYUGAKU_BI;
--                    END IF;
                    IF NOT FUNC_INSERT_INTERNAL_WORK THEN
                      RETURN FALSE;
                    END IF;
                --転学年月日
--                ELSIF RWK_IDO.TSUCHISHO_KBN = 2 THEN
--                    RWK_IDO.TENNYUGAKU_BI_MEI := '転学年月日';
--                    IF RWK_IDO.SHOCHU_KBN = 1 THEN
--                      RWK_IDO.TENNYUGAKU_BI := NSYOGAKO_TENGAKU_BI;
--                    ELSE
--                      RWK_IDO.TENNYUGAKU_BI := NTYUGAKO_TENGAKU_BI;
--                    END IF;
--                    IF NOT FUNC_INSERT_INTERNAL_WORK THEN
--                      RETURN FALSE;
--                    END IF;
--                ELSIF RWK_IDO.TSUCHISHO_KBN = 3 THEN
                    --転入学年月日
--                    RWK_IDO.TSUCHISHO_KBN := 1;
--                    RWK_IDO.TENNYUGAKU_BI_MEI := '転入学年月日';
--                    IF RWK_IDO.SHOCHU_KBN = 1 THEN
--                      RWK_IDO.TENNYUGAKU_BI := NSYOGAKO_TENNYUGAKU_BI;
--                    ELSE
--                      RWK_IDO.TENNYUGAKU_BI := NTYUGAKO_TENNYUGAKU_BI;
--                    END IF;
--                    IF NOT FUNC_INSERT_INTERNAL_WORK THEN
--                      RETURN FALSE;
--                    END IF;
                    --転学年月日
--                    RWK_IDO.TSUCHISHO_KBN := 2;
--                    RWK_IDO.TENNYUGAKU_BI_MEI := '転学年月日';
--                    IF RWK_IDO.SHOCHU_KBN = 1 THEN
--                      RWK_IDO.TENNYUGAKU_BI := NSYOGAKO_TENGAKU_BI;
--                    ELSE
--                      RWK_IDO.TENNYUGAKU_BI := NTYUGAKO_TENGAKU_BI;
--                    END IF;
--                    IF NOT FUNC_INSERT_INTERNAL_WORK THEN
--                      RETURN FALSE;
--                    END IF;
--                ELSE
--                    RWK_IDO.TENNYUGAKU_BI_MEI := '転入学年月日';
--                    IF RWK_IDO.SHOCHU_KBN = 1 THEN
--                      RWK_IDO.TENNYUGAKU_BI := NSYOGAKO_TENNYUGAKU_BI;
--                    ELSE
--                      RWK_IDO.TENNYUGAKU_BI := NTYUGAKO_TENNYUGAKU_BI;
--                    END IF;
--                    IF NOT FUNC_INSERT_INTERNAL_WORK THEN
--                      RETURN FALSE;
--                    END IF;
--                END IF;
--            END IF;
--  2024/07/01 ZCZL.lwy Update End
        END LOOP;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
            RETURN FALSE;
    END FUNC_CREATE_INTERNAL;
/*******************************************
    V4.1.100.000
    FUNCTION    : FUNC_SQL_IDOJOHO
    COMMENT     : 内部ワークテーブル作成
    RETURN      : TRUE  ... 成功
                : FALSE ... 失敗
*******************************************/
    --------------------------------------------------------
    --  機能概要      : 内部ワークテーブル作成
    --  パラメータ    : i_KOJIN_NO
    --                  i_VEBIDOJIYU
    --                  i_FLG
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_SQL_IDOJOHO(i_KOJIN_NO   IN NUMBER,
                              i_VEBIDOJIYU IN NVARCHAR2,
                              i_FLG        IN PLS_INTEGER ) RETURN NVARCHAR2  --0:児童、1:保護者
    IS
        VSQL                    NVARCHAR2(9000);       --  SQL文
    BEGIN
        --SQL作成
        -- FLG=1:異動情報を取得
        VSQL := '';
        VSQL := VSQL || '';
        VSQL := VSQL || '       SELECT '|| 1 ||' AS FLG,       G.KOJIN_NO JIDO_KOJIN_NO,       G.HOGOSYA_KOJIN_NO, G.GAKUNEN_CD, ';
        VSQL := VSQL || '               '|| 0 ||'  AS RUIKEI_RENBAN,  A.RIREKI_RENBAN,  A.IDO_JIYU,';
        VSQL := VSQL || '              A.KOJIN_NO,       A.SHIMEI_KANA,    A.SHIMEI_KANJI,';
        VSQL := VSQL || '              A.SEINENGAPI,     A.SEIBETSU,       G.SYOGAKO_CD AS SHOGAKU_CD,';
        VSQL := VSQL || '              G.TYUGAKO_CD AS CHUGAKU_CD,     A.CHOMEI,         A.BANCHI,';
        VSQL := VSQL || '              A.KATAGAKI,       A.SETAI_NO,       A.SANTEIDANTAI_CD,';
        VSQL := VSQL || '              A.IDO_TODOKE_BI,  A.IDO_BI,         A.HONMYO_KANA,';
        VSQL := VSQL || '              A.HONMYO_KANJI,   A.GYOSEIKU_CD,    A.TENNYUMAE_REN,';
        VSQL := VSQL || '              A.JINKAKU_KBN ';
        VSQL := VSQL || '         FROM GABVATENAALL A,';
        VSQL := VSQL || '               ( SELECT GK.*, GL.GAKUNEN_CD FROM GKBTGAKUNENLNK GL, ';
        VSQL := VSQL || '                                                (SELECT * FROM GKBTGAKUREIBO GA ';
        VSQL := VSQL || '                                                  WHERE GA.RIREKI_RENBAN = ';
        VSQL := VSQL || '                                                     (SELECT MAX(GB.RIREKI_RENBAN) FROM GKBTGAKUREIBO GB ';
        VSQL := VSQL || '                                                       WHERE GA.KOJIN_NO = GB.KOJIN_NO AND GB.SYS_SAKUSEIBI <= '|| NSHURYO_SEIREKI || ')';
        VSQL := VSQL || '                                                 ) GK';
        VSQL := VSQL || '                 WHERE GL.GAKUNEN_CD >= 0 AND GL.GAKUNEN_CD <= 9 AND GK.KOJIN_NO = GL.KOJIN_NO ) G';
        VSQL := VSQL || '        WHERE ';
        VSQL := VSQL || '              A.KOJIN_NO = ' || i_KOJIN_NO;
        IF i_FLG = 0 THEN
          -- 児童
          VSQL := VSQL || '          AND A.KOJIN_NO = G.KOJIN_NO';
        ELSE
          -- 保護者
          VSQL := VSQL || '          AND A.KOJIN_NO = G.HOGOSYA_KOJIN_NO';
        END IF;
        VSQL := VSQL || '          AND A.SYS_SAKUSEIBI BETWEEN '|| NKAISHI_SEIREKI ||' AND '|| NSHURYO_SEIREKI ;
        VSQL := VSQL || '          AND A.RIREKI_RENBAN =';
        VSQL := VSQL || '              (SELECT MAX(BB.RIREKI_RENBAN)';
        VSQL := VSQL || '                 FROM GABVATENAALL BB';
        VSQL := VSQL || '                WHERE BB.KOJIN_NO = A.KOJIN_NO';
        VSQL := VSQL || '                  AND BB.SYS_SAKUSEIBI BETWEEN '|| NKAISHI_SEIREKI ||' AND '|| NSHURYO_SEIREKI || ')';
        VSQL := VSQL || ' UNION ALL';

        -- 以下は、最新情報を取得（保護者のみ異動している場合、児童の最新情報を取得するように修正）
        VSQL := VSQL || '';
        VSQL := VSQL || '       SELECT DISTINCT '|| 2 ||' AS FLG,       G.KOJIN_NO JIDO_KOJIN_NO,       G.HOGOSYA_KOJIN_NO, G.GAKUNEN_CD, ';
        VSQL := VSQL || '               '|| 0 ||'  AS RUIKEI_RENBAN,  B.RIREKI_RENBAN,  B.IDO_JIYU,';
        VSQL := VSQL || '              B.KOJIN_NO,       B.SHIMEI_KANA,    B.SHIMEI_KANJI,';
        VSQL := VSQL || '              B.SEINENGAPI,     B.SEIBETSU,       G.SYOGAKO_CD AS SHOGAKU_CD,';
        VSQL := VSQL || '              G.TYUGAKO_CD AS CHUGAKU_CD,     B.CHOMEI,         B.BANCHI,';
        VSQL := VSQL || '              B.KATAGAKI,       B.SETAI_NO,       B.SANTEIDANTAI_CD,';
        VSQL := VSQL || '              B.IDO_TODOKE_BI,  B.IDO_BI,         B.HONMYO_KANA,';
        VSQL := VSQL || '              B.HONMYO_KANJI,   B.GYOSEIKU_CD,    B.TENNYUMAE_REN,';
        VSQL := VSQL || '              B.JINKAKU_KBN ';
        VSQL := VSQL || '         FROM GABVATENAALL B, ';
        VSQL := VSQL || '               ( SELECT GK.*, GL.GAKUNEN_CD FROM GKBTGAKUNENLNK GL, ';
        VSQL := VSQL || '                                                (SELECT * FROM GKBTGAKUREIBO GA ';
        VSQL := VSQL || '                                                  WHERE GA.RIREKI_RENBAN = ';
        VSQL := VSQL || '                                                     (SELECT MAX(GB.RIREKI_RENBAN) FROM GKBTGAKUREIBO GB ';
        VSQL := VSQL || '                                                       WHERE GA.KOJIN_NO = GB.KOJIN_NO AND GB.SYS_SAKUSEIBI <= '|| NSHURYO_SEIREKI || ')';
        VSQL := VSQL || '                                                 ) GK';
        VSQL := VSQL || '                 WHERE GL.GAKUNEN_CD >= 0 AND GL.GAKUNEN_CD <= 9 AND GK.KOJIN_NO = GL.KOJIN_NO ) G';
        VSQL := VSQL || '        WHERE ';
        VSQL := VSQL || '                B.KOJIN_NO = ' || i_KOJIN_NO;
        IF i_FLG = 0 THEN
          -- 児童
          VSQL := VSQL || '          AND B.KOJIN_NO = G.KOJIN_NO';
        ELSE
          -- 保護者
          VSQL := VSQL || '          AND B.KOJIN_NO = G.HOGOSYA_KOJIN_NO';
        END IF;
        VSQL := VSQL || '          AND B.RIREKI_RENBAN =';
        VSQL := VSQL || '              (SELECT MAX(CC.RIREKI_RENBAN)';
        VSQL := VSQL || '                 FROM GABVATENAALL CC';
        VSQL := VSQL || '                WHERE CC.KOJIN_NO = B.KOJIN_NO';
        VSQL := VSQL || '                  AND CC.SYS_SAKUSEIBI BETWEEN '|| NKAISHI_SEIREKI ||' AND '|| NSHURYO_SEIREKI || ')';
        VSQL := VSQL || ' ORDER BY FLG  ';

        RETURN VSQL;
    END FUNC_SQL_IDOJOHO;

    --------------------------------------------------------
    --  機能概要      : 内部ワークテーブル作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 成功 TRUE,失敗 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
--  2024/07/01 ZCZL.lwy Delete Start 0.3.000.000:新WizLIFE２次開発
--     FUNCTION FUNC_CREATE_INTERNAL2 RETURN BOOLEAN
--     IS
        --------------------
        -- 変数定義
        --------------------
--         BRET                    BOOLEAN;
--         W_GROUP_NO              NUMBER;
--         W_HOGOSHA               NUMBER;
--         W_KANA                  NVARCHAR2(180);
--         W_KANJI                 NVARCHAR2(180);
--         W_HONMYO_KANA           NVARCHAR2(180);
--         W_HONMYO_KANJI          NVARCHAR2(180);
--         o_VZOKUGARAMEI          NVARCHAR2(30);
--         o_IHERR                 PLS_INTEGER;
--         IHERR                   PLS_INTEGER;
--         O_HOGOSHA_KOJIN_NO      NUMBER;
--         O_IDOJIKO               NVARCHAR2(300);
--         O_SHUGAKU               NVARCHAR2(300);
--         O_ZOKUGARA1             NUMBER;
--         O_ZOKUGARA2             NUMBER;
--         O_ZOKUGARA3             NUMBER;
--         O_ZOKUGARA4             NUMBER;
--         O_HOGOSYA_ZOKUGARA1     NUMBER;
--         O_HOGOSYA_ZOKUGARA2     NUMBER;
--         O_HOGOSYA_ZOKUGARA3     NUMBER;
--         O_HOGOSYA_ZOKUGARA4     NUMBER;
--         NSYOGAKO_TENGAKU_BI     NUMBER;
--         NTYUGAKO_TENGAKU_BI     NUMBER;
--         NSYOGAKO_TENNYUGAKU_BI  NUMBER;
--         NTYUGAKO_TENNYUGAKU_BI  NUMBER;
--         W_HOGOSHA1              NUMBER;
--         DBG                     PLS_INTEGER;
--         I                       PLS_INTEGER;           -- Idex
--         W_VEBIDOJIYU            NVARCHAR2(1000);       -- 除外する異動事由
--         VSQL_IDO                NVARCHAR2(32767);       -- SQL文
--         VSQL_JOHO               NVARCHAR2(32767);       -- SQL文
-- 
--         TYPE T_HENKOSHA IS REF CURSOR;
--         CHENKOSHA    T_HENKOSHA;
--         TYPE T_IDORUIKEI IS REF CURSOR;
--         CIDORUIKEI    T_IDORUIKEI;
--         TYPE T_IDORUIKEI_HOGO IS REF CURSOR;
--         CIDORUIKEI_HOGO    T_IDORUIKEI_HOGO;
-- 
--     BEGIN
        --------------------
        -- 基準日より、小中学生の生年月日の範囲を求める
        --------------------
--         PROC_GET_SEINENGAPI;

        --抽出対象外の異動事由を取得
--         W_VEBIDOJIYU := '';
--         o_EBIDOJIYU := A_CONS_PRM();
--         IEBIDOJIYU  := KKAPK0030.FPRMSHUTOKU('GKB','00EBIDO_JIYU',0 ,o_EBIDOJIYU,o_LENGTH);
--         IF IEBIDOJIYU = 0 THEN
--           FOR I in 1..o_LENGTH LOOP
--             IF I = 1 THEN
--               W_VEBIDOJIYU := o_EBIDOJIYU(I);
--             ELSE
--               IF o_EBIDOJIYU(I) IS NOT NULL THEN
--                 W_VEBIDOJIYU := W_VEBIDOJIYU || ',' || o_EBIDOJIYU(I);
--               END IF;
--             END IF;
--           END LOOP;
--         END IF;

        --------------------
        --SQL作成:児童又は保護者の異動を抽出
        --------------------
--         VSQL_IDO := '';
--         VSQL_IDO := VSQL_IDO || '';
--         VSQL_IDO := VSQL_IDO || ' SELECT IDO.* FROM ( ';
--         VSQL_IDO := VSQL_IDO || '   SELECT JD.* ';
--         VSQL_IDO := VSQL_IDO || '     FROM ( ';
--         VSQL_IDO := VSQL_IDO || '       SELECT DISTINCT G.KOJIN_NO JIDO_KOJIN_NO,       G.HOGOSYA_KOJIN_NO';
--         VSQL_IDO := VSQL_IDO || '         FROM GABVATENAALL A,';
--         VSQL_IDO := VSQL_IDO || '               ( SELECT GK.*, GL.GAKUNEN_CD FROM GKBTGAKUNENLNK GL, ';
--         VSQL_IDO := VSQL_IDO || '                                                 (SELECT * FROM GKBTGAKUREIBO GA ';
--         VSQL_IDO := VSQL_IDO || '                                                   WHERE GA.RIREKI_RENBAN = ';
--         VSQL_IDO := VSQL_IDO || '                                                      (SELECT MAX(GB.RIREKI_RENBAN) FROM GKBTGAKUREIBO GB ';
--         VSQL_IDO := VSQL_IDO || '                                                        WHERE GA.KOJIN_NO = GB.KOJIN_NO AND GB.SYS_SAKUSEIBI <= '|| NSHURYO_SEIREKI || ')';
--         VSQL_IDO := VSQL_IDO || '                                                  ) GK';
--         VSQL_IDO := VSQL_IDO || '                           WHERE GL.GAKUNEN_CD >= 0 AND GL.GAKUNEN_CD <= 9 AND GK.KOJIN_NO = GL.KOJIN_NO ) G';
--         VSQL_IDO := VSQL_IDO || '        WHERE ';
--         IF LENGTH(W_VEBIDOJIYU) <> 0 THEN
--           VSQL_IDO := VSQL_IDO || '             A.IDO_JIYU NOT IN ( ';
--           VSQL_IDO := VSQL_IDO || W_VEBIDOJIYU ;
--           VSQL_IDO := VSQL_IDO || '                                 ) AND ';
--         END IF;
--         VSQL_IDO := VSQL_IDO || '              A.SYS_SAKUSEIBI BETWEEN '|| NKAISHI_SEIREKI ||' AND '|| NSHURYO_SEIREKI ;
--         VSQL_IDO := VSQL_IDO || '          AND A.KOJIN_NO = G.KOJIN_NO';
--         VSQL_IDO := VSQL_IDO || '          AND A.SEINENGAPI BETWEEN '|| NSEINENCHU_KAISHI ||' AND '|| NSEINENSHO_SHURYO ;
--         VSQL_IDO := VSQL_IDO || '          AND A.RIREKI_RENBAN =';
--         VSQL_IDO := VSQL_IDO || '              (SELECT MAX(BB.RIREKI_RENBAN)';
--         VSQL_IDO := VSQL_IDO || '                 FROM GABVATENAALL BB';
--         VSQL_IDO := VSQL_IDO || '                WHERE BB.KOJIN_NO = A.KOJIN_NO';
--         VSQL_IDO := VSQL_IDO || '                  AND BB.IDO_JIYU = A.IDO_JIYU';
--         VSQL_IDO := VSQL_IDO || '                  AND BB.SYS_SAKUSEIBI = A.SYS_SAKUSEIBI)';
--         VSQL_IDO := VSQL_IDO || ' ) JD';
--         VSQL_IDO := VSQL_IDO || ' union ';
--         VSQL_IDO := VSQL_IDO || ' select HOGO.* from ( ';
--         VSQL_IDO := VSQL_IDO || '       SELECT DISTINCT G.KOJIN_NO JIDO_KOJIN_NO,        G.HOGOSYA_KOJIN_NO';
--         VSQL_IDO := VSQL_IDO || '         FROM GABVATENAALL A';
--         VSQL_IDO := VSQL_IDO || '              , ( SELECT GK.*, GL.GAKUNEN_CD FROM GKBTGAKUNENLNK GL, ';
--         VSQL_IDO := VSQL_IDO || '                                                 (SELECT * FROM GKBTGAKUREIBO GA ';
--         VSQL_IDO := VSQL_IDO || '                                                   WHERE GA.RIREKI_RENBAN = ';
--         VSQL_IDO := VSQL_IDO || '                                                      (SELECT MAX(GB.RIREKI_RENBAN) FROM GKBTGAKUREIBO GB ';
--         VSQL_IDO := VSQL_IDO || '                                                        WHERE GA.KOJIN_NO = GB.KOJIN_NO AND GB.SYS_SAKUSEIBI <= '|| NSHURYO_SEIREKI || ')';
--         VSQL_IDO := VSQL_IDO || '                                                  ) GK';
--         VSQL_IDO := VSQL_IDO || '                           WHERE GL.GAKUNEN_CD >= 0 AND GL.GAKUNEN_CD <= 9 AND GK.KOJIN_NO = GL.KOJIN_NO ) G';
-- 
--         VSQL_IDO := VSQL_IDO || '        WHERE ';
--         IF LENGTH(W_VEBIDOJIYU) <> 0 THEN
--           VSQL_IDO := VSQL_IDO || '             A.IDO_JIYU NOT IN ( ';
--           VSQL_IDO := VSQL_IDO || W_VEBIDOJIYU ;
--           VSQL_IDO := VSQL_IDO || '                                 ) AND ';
--         END IF;
--         VSQL_IDO := VSQL_IDO || '              A.SYS_SAKUSEIBI BETWEEN '|| NKAISHI_SEIREKI ||' AND '|| NSHURYO_SEIREKI ;
--         VSQL_IDO := VSQL_IDO || '          AND A.KOJIN_NO = G.HOGOSYA_KOJIN_NO';
--         VSQL_IDO := VSQL_IDO || '          AND A.RIREKI_RENBAN =';
--         VSQL_IDO := VSQL_IDO || '              (SELECT MAX(BB.RIREKI_RENBAN)';
--         VSQL_IDO := VSQL_IDO || '                 FROM GABVATENAALL BB';
--         VSQL_IDO := VSQL_IDO || '                WHERE BB.KOJIN_NO = A.KOJIN_NO';
--         VSQL_IDO := VSQL_IDO || '                  AND BB.IDO_JIYU = A.IDO_JIYU';
--         VSQL_IDO := VSQL_IDO || '                  AND BB.SYS_SAKUSEIBI = A.SYS_SAKUSEIBI)';
--         VSQL_IDO := VSQL_IDO || '  ) HOGO ) IDO ';
        -- 処理条件４：児童個人番号
--         IF NTAISHO_JIDO <> 0 THEN
--           VSQL_IDO := VSQL_IDO || '  WHERE IDO.JIDO_KOJIN_NO = '|| NTAISHO_JIDO;
--         END IF;
--         VSQL_IDO := VSQL_IDO || ' ORDER BY IDO.JIDO_KOJIN_NO, IDO.HOGOSYA_KOJIN_NO';
-- 
--         OPEN CHENKOSHA FOR TO_CHAR(VSQL_IDO);
--         LOOP
--           FETCH CHENKOSHA  INTO CR_HENKOSHA_REC;
--            EXIT WHEN CHENKOSHA%NOTFOUND;

          --------------------
          --詳細情報を取得SQLを生成（児童情報）
          --------------------
--           VSQL_JOHO := '';
--           VSQL_JOHO := FUNC_SQL_IDOJOHO(CR_HENKOSHA_REC.JIDO_KOJIN_NO, W_VEBIDOJIYU, 0);
-- 
--           OPEN CIDORUIKEI FOR TO_CHAR(VSQL_JOHO);
--           FETCH CIDORUIKEI INTO CR_IDOREC;
--           IF CIDORUIKEI%NOTFOUND THEN
--             NULL;
--           ELSE
--             IKENSU_IN := IKENSU_IN + 1;
--             DBG       := CR_IDOREC.JIDO_KOJIN_NO;
--             RWK_IDO   :=  NULL;       -- 内部ワークテーブルレコード初期化
--             RWK_IDO.GAKUNEN     := CR_IDOREC.GAKUNEN_CD;
--             IF RWK_IDO.GAKUNEN <= 6 THEN
--                 RWK_IDO.SHOCHU_KBN := 1;    -- 小学生
--             ELSE
--                 RWK_IDO.SHOCHU_KBN := 2;    -- 中学生
--             END IF;

            -- 旧住所取得（児童）
--             BRET := FUNC_GET_KYU(CR_IDOREC.JIDO_KOJIN_NO, CR_IDOREC.RIREKI_RENBAN);
--             IF NOT BRET THEN
--                 RETURN FALSE;
--             END IF;
            --------------------
            -- 作成する通知書の種類を決める
            --------------------
--             IF CR_IDOREC.IDO_JIYU = 11 THEN    -- 転入学
--                 RWK_IDO.TSUCHISHO_KBN := 1;
--                 BRET := FUNC_GET_JUSHO(CR_IDOREC.JIDO_KOJIN_NO, CR_IDOREC.TENNYUMAE_REN);
--                 IF NOT BRET THEN
--                     RETURN FALSE;
--                 END IF;
--                 NKYUSHOGAKU_CD  := 0;
--                 NKYUCHUGAKU_CD  := 0;
--                 NKYUGYOSEIKU_CD := 0;
--             ELSIF CR_IDOREC.IDO_JIYU = 21 THEN  -- 転出学
--                 RWK_IDO.TSUCHISHO_KBN := 2;
--             ELSIF CR_IDOREC.IDO_JIYU BETWEEN 31 AND 34 THEN -- 転居
                --------------------
                -- 転居の場合、学校区が変わっていれば、転入、転出それぞれに記載
                -- 学校区が変わってなければ、学校区内異動
                --------------------
--                 IF RWK_IDO.GAKUNEN <= 6 THEN
                    -- 小学生
--                     IF CR_IDOREC.SHOGAKU_CD <> NKYUSHOGAKU_CD THEN
--                         RWK_IDO.TSUCHISHO_KBN := 3;
--                     ELSE
--                         RWK_IDO.TSUCHISHO_KBN := 4;
--                     END IF;
--                 ELSE
                    -- 中学生
--                     IF CR_IDOREC.CHUGAKU_CD <> NKYUCHUGAKU_CD THEN
--                         RWK_IDO.TSUCHISHO_KBN := 3;
--                     ELSE
--                         RWK_IDO.TSUCHISHO_KBN := 4;
--                     END IF;
--                 END IF;
--             ELSIF CR_IDOREC.IDO_JIYU IN (41,42) THEN -- 職権修正、地番修正の場合、学校区内異動
--                 RWK_IDO.TSUCHISHO_KBN := 4;
--             END IF;
-- 
--             RWK_IDO.GROUP_NO     := W_GROUP_NO;
--             IF CR_IDOREC.FLG = 2 THEN
              --保護者だけ異動の場合
--               RWK_IDO.IDO_JIYU     := 0;         -- 異動事由
--             ELSE
--               RWK_IDO.IDO_JIYU     := CR_IDOREC.IDO_JIYU;         -- 異動事由
--             END IF;
--             RWK_IDO.KOJIN_NO     := CR_IDOREC.JIDO_KOJIN_NO;    -- 児童個人番号
--             RWK_IDO.SHIMEI_KANA  := CR_IDOREC.SHIMEI_KANA;      -- 氏名カナ（児童）
--             RWK_IDO.SHIMEI_KANJI := CR_IDOREC.SHIMEI_KANJI;     -- 氏名漢字（児童）
--             RWK_IDO.SETAI_NO     := CR_IDOREC.SETAI_NO;         -- 世帯番号
--             RWK_IDO.SEINENGAPI   := CR_IDOREC.SEINENGAPI;       -- 生年月日
--             IF CR_IDOREC.IDO_JIYU = 21 THEN  -- 転出
--               RWK_IDO.SHOGAKU_CD   := 0;
--               RWK_IDO.CHUGAKU_CD   := 0;
--             ELSE
--               RWK_IDO.SHOGAKU_CD   := CR_IDOREC.SHOGAKU_CD;     -- 小学校コード
--               RWK_IDO.CHUGAKU_CD   := CR_IDOREC.CHUGAKU_CD;     -- 中学校コード
--             END IF;
--             RWK_IDO.SEIBETSU       := CR_IDOREC.SEIBETSU;       -- 性別
--             RWK_IDO.OLD_SHOGAKU_CD := NKYUSHOGAKU_CD;           -- 小学校コード（旧）
--             RWK_IDO.OLD_CHUGAKU_CD := NKYUCHUGAKU_CD;           -- 中学校コード（旧）
--             RWK_IDO.OLD_GYOSEIKUMEI   := GAAPK0030.FGYOSEIKUMEI(1, NKYUGYOSEIKU_CD);
            -- 児童の住所
--             RWK_IDO.CHOMEI       := CR_IDOREC.CHOMEI;
--             RWK_IDO.BANCHI       := CR_IDOREC.BANCHI;
--             RWK_IDO.KATAGAKI     := CR_IDOREC.KATAGAKI;
            -- 児童の旧住所
--             RWK_IDO.KYUCHOMEI    := VKYUCHOMEI;
--             RWK_IDO.KYUBANCHI    := VKYUBANCHI;
--             RWK_IDO.KYUKATAGAKI  := VKYUKATAGAKI;

            -- 学齢簿より保護者との続柄を取得
--             B_RTN := FUNC_GET_HOGOSHA(CR_IDOREC.JIDO_KOJIN_NO,
--                                       O_HOGOSHA_KOJIN_NO,
--                                       O_IDOJIKO,
--                                       O_SHUGAKU,
--                                       O_ZOKUGARA1,
--                                       O_ZOKUGARA2,
--                                       O_ZOKUGARA3,
--                                       O_ZOKUGARA4,
--                                       O_HOGOSYA_ZOKUGARA1,
--                                       O_HOGOSYA_ZOKUGARA2,
--                                       O_HOGOSYA_ZOKUGARA3,
--                                       O_HOGOSYA_ZOKUGARA4,
--                                       NSYOGAKO_TENGAKU_BI,
--                                       NTYUGAKO_TENGAKU_BI,
--                                       NSYOGAKO_TENNYUGAKU_BI,
--                                       NTYUGAKO_TENNYUGAKU_BI);
--             W_HOGOSHA := CR_IDOREC.HOGOSYA_KOJIN_NO;

--             RWK_IDO.JINKAKU_KBN  := CR_IDOREC.JINKAKU_KBN;      -- 人格区分（児童）
--             VJINKAKU_KBN         := CR_IDOREC.JINKAKU_KBN;
--             IF VJINKAKU_KBN = 1 THEN
--               HOGOSHA_KBN := GKBPK00010.FGKJHGS(NKIJUNBI, CR_IDOREC.JIDO_KOJIN_NO, W_HOGOSHA1,VSHIMEI_KANJI);
--             ELSE
--               HOGOSHA_KBN := GKBPK00010.FHOGOSHA(NKIJUNBI, CR_IDOREC.JIDO_KOJIN_NO, W_HOGOSHA1);
--             END IF;
--             IF W_HOGOSHA > 1 THEN
--                 RWK_IDO.HOGOSHA_NO    := W_HOGOSHA;
--                 PROC_GET_SHIMEI(W_HOGOSHA, W_KANA, W_KANJI,W_HONMYO_KANA,W_HONMYO_KANJI);
--                 RWK_IDO.HOGOSHA_KANA  := W_KANA;
--                 RWK_IDO.HOGOSHA_KANJI := W_KANJI;
--                 RWK_IDO.HOGOSHA_HONMYO_KANA := W_HONMYO_KANA;
--                 RWK_IDO.HOGOSHA_HONMYO_KANJI := W_HONMYO_KANJI;
--               ELSIF HOGOSHA_KBN = 0 THEN
--                 RWK_IDO.HOGOSHA_NO    := W_HOGOSHA1;
--                 PROC_GET_SHIMEI(W_HOGOSHA1, W_KANA, W_KANJI,W_HONMYO_KANA,W_HONMYO_KANJI);
--                 RWK_IDO.HOGOSHA_KANA  := W_KANA;
--                 RWK_IDO.HOGOSHA_KANJI := W_KANJI;
--                 RWK_IDO.HOGOSHA_HONMYO_KANA := W_HONMYO_KANA;
--                 RWK_IDO.HOGOSHA_HONMYO_KANJI := W_HONMYO_KANJI;
--             ELSE
--                 RWK_IDO.HOGOSHA_NO    := 0;
--                 RWK_IDO.HOGOSHA_KANA  := '';
--                 RWK_IDO.HOGOSHA_KANJI := '';
--                 RWK_IDO.HOGOSHA_HONMYO_KANA := '';
--                 RWK_IDO.HOGOSHA_HONMYO_KANJI := '';
--             END IF;
--             RWK_IDO.SANTEIDANTAI_CD := CR_IDOREC.SANTEIDANTAI_CD;    -- 算定団体コード
--             RWK_IDO.TODOKE_BI       := CR_IDOREC.IDO_TODOKE_BI;      -- 異動届出日
--             RWK_IDO.IDO_BI          := CR_IDOREC.IDO_BI;             -- 異動日
--             RWK_IDO.HONMYO_KANA     := CR_IDOREC.HONMYO_KANA;        -- 児童氏名本名かな
--             RWK_IDO.HONMYO_KANJI    := CR_IDOREC.HONMYO_KANJI;       -- 児童氏名本名漢字
--             RWK_IDO.IDOJIKO         := O_IDOJIKO;                    -- 異動事項
--             RWK_IDO.SHUGAKU         := O_SHUGAKU;                    -- 就学状況
            -- 保護者との関係
--             IHERR := GKBFKZKGMGET(1,O_ZOKUGARA1,O_ZOKUGARA2,O_ZOKUGARA3,O_ZOKUGARA4,o_VZOKUGARAMEI,o_IHERR);
--             RWK_IDO.HOGOSHA_TSUDUKIGARA  := o_VZOKUGARAMEI;
            -- 生徒との関係
--             IHERR := GKBFKZKGMGET(2,O_HOGOSYA_ZOKUGARA1,O_HOGOSYA_ZOKUGARA2,O_HOGOSYA_ZOKUGARA3,O_HOGOSYA_ZOKUGARA4,o_VZOKUGARAMEI,o_IHERR);
--             RWK_IDO.TSUDUKIGARA  := o_VZOKUGARAMEI;
            -- 転出の場合
--             IF CR_IDOREC.IDO_JIYU = 21 THEN
--               RWK_IDO.GYOSEIKUMEI     := '';
--             ELSE
--               RWK_IDO.GYOSEIKUMEI     := GAAPK0030.FGYOSEIKUMEI(1, CR_IDOREC.GYOSEIKU_CD);
--             END IF;

            -- 保護者の住所を取得
            --詳細情報を取得（保護者情報）
--             VSQL_JOHO := '';
--             VSQL_JOHO := FUNC_SQL_IDOJOHO(CR_HENKOSHA_REC.HOGOSYA_KOJIN_NO, W_VEBIDOJIYU, 1);
-- 
--             OPEN CIDORUIKEI_HOGO FOR TO_CHAR(VSQL_JOHO);
--             FETCH CIDORUIKEI_HOGO INTO CR_IDOREC_HOGO;
--             IF CIDORUIKEI_HOGO%NOTFOUND THEN

              -- 住所取得（保護者情報）:履歴番号=1000をセットすることで、最大履歴連番=999を取得
              -- 期間内最新保護者の期間内最新住所を取得
--               BRET := FUNC_GET_KYU2(CR_HENKOSHA_REC.JIDO_KOJIN_NO, 0);
--               IF NOT BRET THEN
--                 RETURN FALSE;
--               END IF;
--               RWK_IDO.HOGOSHA_CHOMEI       := VKYUCHOMEI;
--               RWK_IDO.HOGOSHA_BANCHI       := VKYUBANCHI;
--               RWK_IDO.HOGOSHA_KATAGAKI     := VKYUKATAGAKI;

              -- 住所取得（保護者情報）:履歴番号=999をセットすることで、最新の過去履歴から取得
              -- 期間前保護者の期間前最新住所を取得
--               BRET := FUNC_GET_KYU2(CR_HENKOSHA_REC.JIDO_KOJIN_NO, 1);
--               IF NOT BRET THEN
--                 RETURN FALSE;
--               END IF;
--               RWK_IDO.HOGOSHA_KYUCHOMEI    := VKYUCHOMEI;
--               RWK_IDO.HOGOSHA_KYUBANCHI    := VKYUBANCHI;
--               RWK_IDO.HOGOSHA_KYUKATAGAKI  := VKYUKATAGAKI;
--             ELSE
              -- 保護者の住所
--               RWK_IDO.HOGOSHA_CHOMEI       := CR_IDOREC_HOGO.CHOMEI;
--               RWK_IDO.HOGOSHA_BANCHI       := CR_IDOREC_HOGO.BANCHI;
--               RWK_IDO.HOGOSHA_KATAGAKI     := CR_IDOREC_HOGO.KATAGAKI;

--               IF CR_IDOREC.IDO_JIYU = 11 THEN    -- 転入
                -- 転入連番から住所を取得
--                 BRET := FUNC_GET_JUSHO(CR_HENKOSHA_REC.HOGOSYA_KOJIN_NO, CR_IDOREC_HOGO.TENNYUMAE_REN);
--                 IF NOT BRET THEN
--                     RETURN FALSE;
--                 END IF;
--               ELSE
                -- 住所取得（保護者情報）:履歴連番の一つ前を取得する
                -- 期間前保護者の期間前最新住所を取得
--                 BRET := FUNC_GET_KYU2(CR_HENKOSHA_REC.JIDO_KOJIN_NO, 1);
--                 IF NOT BRET THEN
--                   RETURN FALSE;
--                 END IF;
--               END IF;
              -- 保護者の旧住所
--               RWK_IDO.HOGOSHA_KYUCHOMEI    := VKYUCHOMEI;
--               RWK_IDO.HOGOSHA_KYUBANCHI    := VKYUBANCHI;
--               RWK_IDO.HOGOSHA_KYUKATAGAKI  := VKYUKATAGAKI;
-- 
--             END IF;
--             CLOSE CIDORUIKEI_HOGO;
-- 
--             IF IHAKKO_KBN = 1 AND
--                CR_IDOREC.IDO_JIYU BETWEEN 31 AND 34 AND
--                RWK_IDO.TSUCHISHO_KBN = 4 THEN
                -- 発行区分（しない）、転居、学校区内異動　のときは発行しない
--                 NULL;
--             ELSE
                --転入学年月日
--                 IF RWK_IDO.TSUCHISHO_KBN = 1 THEN
--                   RWK_IDO.TENNYUGAKU_BI_MEI := '転入学年月日';
--                   IF RWK_IDO.SHOCHU_KBN = 1 THEN
--                     RWK_IDO.TENNYUGAKU_BI := NSYOGAKO_TENNYUGAKU_BI;
--                   ELSE
--                     RWK_IDO.TENNYUGAKU_BI := NTYUGAKO_TENNYUGAKU_BI;
--                   END IF;
--                   IF NOT FUNC_INSERT_INTERNAL_WORK THEN
--                     RETURN FALSE;
--                   END IF;
                --転学年月日
--                 ELSIF RWK_IDO.TSUCHISHO_KBN = 2 THEN
--                   RWK_IDO.TENNYUGAKU_BI_MEI := '転学年月日';
--                   IF RWK_IDO.SHOCHU_KBN = 1 THEN
--                     RWK_IDO.TENNYUGAKU_BI := NSYOGAKO_TENGAKU_BI;
--                   ELSE
--                     RWK_IDO.TENNYUGAKU_BI := NTYUGAKO_TENGAKU_BI;
--                   END IF;
--                   IF NOT FUNC_INSERT_INTERNAL_WORK THEN
--                     RETURN FALSE;
--                   END IF;
--                 ELSIF RWK_IDO.TSUCHISHO_KBN = 3 THEN
                  --転入学年月日
--                   RWK_IDO.TSUCHISHO_KBN := 1;
--                   RWK_IDO.TENNYUGAKU_BI_MEI := '転入学年月日';
--                   IF RWK_IDO.SHOCHU_KBN = 1 THEN
--                     RWK_IDO.TENNYUGAKU_BI := NSYOGAKO_TENNYUGAKU_BI;
--                   ELSE
--                     RWK_IDO.TENNYUGAKU_BI := NTYUGAKO_TENNYUGAKU_BI;
--                   END IF;
--                   IF NOT FUNC_INSERT_INTERNAL_WORK THEN
--                     RETURN FALSE;
--                   END IF;
                  --転学年月日
--                   RWK_IDO.TSUCHISHO_KBN := 2;
--                   RWK_IDO.TENNYUGAKU_BI_MEI := '転学年月日';
--                   IF RWK_IDO.SHOCHU_KBN = 1 THEN
--                     RWK_IDO.TENNYUGAKU_BI := NSYOGAKO_TENGAKU_BI;
--                   ELSE
--                     RWK_IDO.TENNYUGAKU_BI := NTYUGAKO_TENGAKU_BI;
--                   END IF;
--                   IF NOT FUNC_INSERT_INTERNAL_WORK THEN
--                     RETURN FALSE;
--                   END IF;
--                 ELSE
--                   RWK_IDO.TENNYUGAKU_BI_MEI := '転入学年月日';
--                   IF RWK_IDO.SHOCHU_KBN = 1 THEN
--                     RWK_IDO.TENNYUGAKU_BI := NSYOGAKO_TENNYUGAKU_BI;
--                   ELSE
--                     RWK_IDO.TENNYUGAKU_BI := NTYUGAKO_TENNYUGAKU_BI;
--                   END IF;
--                   IF NOT FUNC_INSERT_INTERNAL_WORK THEN
--                     RETURN FALSE;
--                   END IF;
--                 END IF;
--             END IF;
--           END IF;
--           CLOSE CIDORUIKEI;
--         END LOOP;
-- 
--         CLOSE CHENKOSHA;
-- 
--         RETURN TRUE;
--     EXCEPTION
--         WHEN OTHERS THEN
--             IF CHENKOSHA%ISOPEN THEN
--               CLOSE CHENKOSHA;
--             END IF;
--             IF CIDORUIKEI%ISOPEN THEN
--               CLOSE CIDORUIKEI;
--             END IF;
--             IF CIDORUIKEI_HOGO%ISOPEN THEN
--               CLOSE CIDORUIKEI_HOGO;
--             END IF;
            -- SQL情報取得
--             N_SQL_CODE := SQLCODE;
--             V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
--             RETURN FALSE;
--     END FUNC_CREATE_INTERNAL2;
--  2024/07/01 ZCZL.lwy Delete End
    --------------------------------------------------------------------------------
    -- 氏名印字制御ﾊﾟﾗﾒｰﾀの設定の編集
    --IN_PARAM NSEIGYO_IN_FLG 制御ﾊﾟﾗﾒｰﾀ
    --OUT_PARAM NSEIGYO_OUT_FLG データ編集用　1 本名　３　管理模型で編集（氏名かな/氏名漢字） ２　管理模型で編集（本名かな/本名漢字）
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_SEIGYO (NSEIGYO_IN_FLG IN NUMBER , NKANRI_FLG IN NUMBER ,
                              VSHIMEI_DATA IN NVARCHAR2 , VHONMYO_DATA IN NVARCHAR2)
      RETURN NVARCHAR2 IS
      NSEIGYO_OUT_FLG   NUMBER := 0;
      VRETURN           NVARCHAR2(1000);
    BEGIN
     NSEIGYO_OUT_FLG := 0;
      IF NSEIGYO_IN_FLG IS NULL OR NSEIGYO_IN_FLG = 0 THEN
        NSEIGYO_OUT_FLG := 4;
        GOTO  SHORI;
      END IF;
      IF NSEIGYO_IN_FLG = 1 THEN
       NSEIGYO_OUT_FLG := 1;
      ELSIF NSEIGYO_IN_FLG = 4 AND NVL(NKANRI_FLG,0) = 0 THEN
       NSEIGYO_OUT_FLG := 1;
      ELSIF NSEIGYO_IN_FLG = 6 AND NVL(NKANRI_FLG,0) = 0 THEN
       NSEIGYO_OUT_FLG := 1;
      ELSIF NSEIGYO_IN_FLG = 3 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 1;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 4 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 1;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 5 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 1;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 6 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 1;
       END IF;
      ELSE
        NSEIGYO_OUT_FLG := 4;
      END IF;
       <<SHORI>>
      IF NSEIGYO_OUT_FLG = 1 THEN
        IF  VHONMYO_DATA IS NOT NULL THEN
           VRETURN := VHONMYO_DATA;
        ELSE
           VRETURN := VSHIMEI_DATA ;
        END IF;
      ELSIF NSEIGYO_OUT_FLG = 2 THEN
        IF  VHONMYO_DATA  IS NOT NULL THEN
           VRETURN := VHONMYO_DATA;
        ELSE
           VRETURN := VSHIMEI_DATA;
        END IF;
      ELSIF NSEIGYO_OUT_FLG = 3 THEN
        IF  VSHIMEI_DATA IS NOT NULL THEN
           VRETURN := VSHIMEI_DATA;
        ELSE
           VRETURN := VHONMYO_DATA;
        END IF;
      ELSE
        IF  VSHIMEI_DATA IS NOT NULL THEN
           VRETURN := VSHIMEI_DATA;
        ELSE
           VRETURN := VHONMYO_DATA;
        END IF;
      END IF;
      RETURN VRETURN;
    END FUNC_SET_SEIGYO;
    --------------------------------------------------------------------------------
    -- 生年月日の編集
    --IN_PARAM NSEIGYO_IN_FLG 制御ﾊﾟﾗﾒｰﾀ
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_SEIGYO_SEINENGAPI (NSEIGYO_IN_FLG IN NUMBER , NKANRI_FLG IN NUMBER)
      RETURN NVARCHAR2 IS
      NSEIGYO_OUT_FLG   NUMBER := 0;
      VRETURN           NVARCHAR2(1000);
    BEGIN
    --データ編集用　1 データなし　３　西暦 　２　和暦
     NSEIGYO_OUT_FLG := 0;
      IF NSEIGYO_IN_FLG IS NULL OR NSEIGYO_IN_FLG = 0 THEN
        NSEIGYO_OUT_FLG := 4;
        GOTO  SHORI;
      END IF;
      IF NSEIGYO_IN_FLG = 4 AND NVL(NKANRI_FLG,0) = 0 THEN
       NSEIGYO_OUT_FLG := 1;
      ELSIF NSEIGYO_IN_FLG = 5 AND NVL(NKANRI_FLG,0) = 0 THEN
       NSEIGYO_OUT_FLG := 1;
      ELSIF NSEIGYO_IN_FLG = 3 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (22) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 4 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (22) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 5 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (22) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 6 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (22) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSE
        NSEIGYO_OUT_FLG := 4;
      END IF;
       <<SHORI>>
      IF NSEIGYO_OUT_FLG = 1 THEN
       VRETURN := '1';
      ELSIF NSEIGYO_OUT_FLG = 2 THEN
       VRETURN := '0';
      ELSIF NSEIGYO_OUT_FLG = 3 THEN
       VRETURN := '1';
      ELSE
       VRETURN := '0';
      END IF;
      RETURN VRETURN;
    END FUNC_SET_SEIGYO_SEINENGAPI;
    --------------------------------------------------------
    --  機能概要      : 性別名称の取得
    --  パラメータ    : I_SEIBETSU ... 性別コード
    --  モジュール区分: 内部関数
    --  戻り値        : 性別名称
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_SEIBETSU_STR(I_SEIBETSU IN NUMBER) RETURN NVARCHAR2
    IS
    BEGIN
        IF I_SEIBETSU = 1 THEN
            RETURN '男';
        ELSE
            RETURN '女';
        END IF;
    END FUNC_GET_SEIBETSU_STR;
    --------------------------------------------------------
    --  機能概要      : 異動事由名称の取得
    --  パラメータ    : I_IDOJIYU ... 異動事由コード
    --  モジュール区分: 内部関数
    --  戻り値        : 異動事由名称
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_IDOJIYUMEI(I_IDOJIYU IN NUMBER) RETURN GABTIDOJIYU.IDO_JIYU_MEI%TYPE
    IS
        W_IDOJIYU   GABTIDOJIYU.IDO_JIYU_MEI%TYPE;
    BEGIN
         SELECT IDO_JIYU_MEI
           INTO W_IDOJIYU
           FROM GABTIDOJIYU
          WHERE IDO_JIYU_CD = I_IDOJIYU;
       RETURN W_IDOJIYU;
    END FUNC_GET_IDOJIYUMEI;

    --------------------------------------------------------
    --  機能概要      : ワークテーブル作成
    --  パラメータ    : I_KBN = 1 ... 転入学通知書
    --                :         2 ... 転出学通知書
    --                :         3 ... 学校区内異動通知書
    --                :         5 ... 変更通知書と変更リスト
    --  モジュール区分: 内部関数
    --  戻り値        : 成功 TRUE,失敗 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
--  2024/07/01 ZCZL.lwy Update 0.3.000.000:新WizLIFE２次開発
--    FUNCTION FUNC_CREATE_WORK(I_KBN IN NUMBER) RETURN  BOOLEAN
    FUNCTION FUNC_CREATE_WORK RETURN  BOOLEAN
    IS
        --------------------
        -- カーソル定義
        --------------------
        CURSOR CGRPNO IS
            SELECT DISTINCT GROUP_NO
              FROM GKBWINTERNAL
             ORDER BY GROUP_NO;
        --------------------
        -- 変数定義
        --------------------
        TYPE CUR_TYPE IS REF CURSOR;
        CINTER      CUR_TYPE;
        CR_I        GKBWINTERNAL%ROWTYPE;
        RWK         GKBWIDOTSUCHI%ROWTYPE;
        N_NAIYO_CD_JIDO_1         GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;
        VEDIT_GO_DATA             NVARCHAR2(1000) := '';
        RA                        GABTATENAKIHON%ROWTYPE;
        RASO                      GABTSOFUSAKI%ROWTYPE;
        RAHOKEN                   GABTATENAKIHON%ROWTYPE;
        RASOHOKEN                 GABTSOFUSAKI%ROWTYPE;
    BEGIN
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
        BEGIN
         SELECT CHOHYO_MEI,
                TSUCHIBUN,
                KOIN_SHORYAKU,
                KOIN_CHUSHAKU,
                YOSHIKI_BANGO_SETTOGO,
                YOSHIKI_BANGO,
                YOSHIKI_BANGO_SETSUBIGO
           INTO vCHOHYO_MEI,
                vTSUCHIBUN,
                vKOIN_SHORYAKU,
                vKOIN_CHUSHAKU,
                vYOSHIKI_BANGO_SETTOGO,
                vYOSHIKI_BANGO,
                vYOSHIKI_BANGO_SETSUBIGO
           FROM GKBTTSUCHISHOKANRI
           WHERE CHOHYO_KBN = 21;
        EXCEPTION
           WHEN OTHERS THEN
             vCHOHYO_MEI := NULL;
             vTSUCHIBUN := NULL;
             vKOIN_SHORYAKU := NULL;
             vKOIN_CHUSHAKU := NULL;
             vYOSHIKI_BANGO_SETTOGO := NULL;
             vYOSHIKI_BANGO := NULL;
             vYOSHIKI_BANGO_SETSUBIGO := NULL;
        END;
--  2024/07/01 ZCZL.lwy Add End
        FOR CR_GRP IN CGRPNO LOOP
            RWK := NULL;
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
            VSQL := 'SELECT *';
            VSQL := VSQL || ' FROM GKBWINTERNAL';
--             IF I_KBN = 1 THEN
--                 VSQL := VSQL || ' WHERE TSUCHISHO_KBN IN (1)';
--             ELSIF I_KBN = 2 THEN
--                 VSQL := VSQL || ' WHERE TSUCHISHO_KBN IN (2)';
--             ELSIF I_KBN = 3 THEN
--                VSQL := VSQL || ' WHERE TSUCHISHO_KBN = 4';
--            ELSIF I_KBN = 5 THEN
--                VSQL := VSQL || ' WHERE TSUCHISHO_KBN = 5';
--             ELSE
--                 NULL;
--             END IF;
--             VSQL := VSQL || ' AND GROUP_NO = ' || TO_CHAR(CR_GRP.GROUP_NO);
            VSQL := VSQL || ' WHERE GROUP_NO = ' || TO_CHAR(CR_GRP.GROUP_NO);
            VSQL := VSQL || ' ORDER BY SEINENGAPI';
           OPEN CINTER FOR VSQL;
            FETCH CINTER INTO CR_I;
            IF CINTER%FOUND THEN
--                 IF I_KBN = 1 THEN
--                     RWK.TITLE := '転 入 学 通 知 書';
--                 ELSIF I_KBN =2 THEN
--                     RWK.TITLE := '転 出 学 通 知 書';
--                 ELSIF I_KBN =3 THEN
--                     RWK.TITLE := '学校区内異動通知書';
--                 ELSIF I_KBN =5 THEN
--                     RWK.TITLE := '変更通知書';
--                 END IF;
                RWK.TITLE := vCHOHYO_MEI;
                RWK.IDO_JIYU     := CR_I.IDO_JIYU;
--                RWK.IDO_JIYU_MEI := FUNC_GET_IDOJIYUMEI(CR_I.IDO_JIYU);
                RWK.IDO_JIYU_MEI := NULL;
                RWK.IDO_BI       := CR_I.IDO_BI;
                RWK.TODOKEDE_BI  := CR_I.TODOKE_BI;
                RWK.SETAI_NO     := CR_I.SETAI_NO;
                RWK.ALL_PAGE     := NULL;
                RWK.PAGE         := NULL;
                RWK.NEW_JUSHO    := GAAPK0010.FADDRESSEDIT(1, NULL, CR_I.CHOMEI, CR_I.BANCHI, CR_I.KATAGAKI, NULL);
                RWK.OLD_JUSHO    := GAAPK0010.FADDRESSEDIT(1, NULL, CR_I.KYUCHOMEI, CR_I.KYUBANCHI, CR_I.KYUKATAGAKI, NULL);
--                RWK.NEW_CHOMEI   := CR_I.CHOMEI;
--                RWK.NEW_BANCHI   := CR_I.BANCHI;
--                RWK.NEW_KATAGAKI := CR_I.KATAGAKI;
--                RWK.OLD_CHOMEI   := CR_I.KYUCHOMEI;
--                RWK.OLD_BANCHI   := CR_I.KYUBANCHI;
--                RWK.OLD_KATAGAKI := CR_I.KYUKATAGAKI;
--                 IF CR_I.SHOCHU_KBN =1 THEN
--                     RWK.NEW_GAKKO
--                         := GAAPK0030.FSHOGAKUMEI(CR_I.SANTEIDANTAI_CD, CR_I.SHOGAKU_CD);
--                     RWK.OLD_GAKKO
--                         := GAAPK0030.FSHOGAKUMEI(CR_I.SANTEIDANTAI_CD, CR_I.OLD_SHOGAKU_CD);
--                  BEGIN
--                   SELECT NVL(KYOIKUIINKAI_CD,0)
--                     INTO NKYOIKUIINKAI_CD
--                     FROM GKBTSHOGAKKO
--                     WHERE SYOGAKO_CD = RWK_IDO.SHOGAKU_CD;
--                  EXCEPTION
--                     WHEN OTHERS THEN
--                       NKYOIKUIINKAI_CD := NULL ;
--                  END;
--                 ELSE
--                     RWK.NEW_GAKKO
--                         := GAAPK0030.FCHUGAKUMEI(CR_I.SANTEIDANTAI_CD, CR_I.CHUGAKU_CD);
--                     RWK.OLD_GAKKO
--                         := GAAPK0030.FCHUGAKUMEI(CR_I.SANTEIDANTAI_CD, CR_I.OLD_CHUGAKU_CD);
--                  BEGIN
--                   SELECT NVL(KYOIKUIINKAI_CD,0)
--                     INTO NKYOIKUIINKAI_CD
--                     FROM GKBTCHUGAKKO
--                     WHERE TYUGAKO_CD = RWK_IDO.CHUGAKU_CD;
--                  EXCEPTION
--                     WHEN OTHERS THEN
--                       NKYOIKUIINKAI_CD := NULL ;
--                  END;
--                 END IF;
                --新学校名
                IF CR_I.SHOCHU_KBN =1 THEN	
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0),
                         SYOGAKOMEI
                    INTO NKYOIKUIINKAI_CD,
                         vSYOGAKOMEI
                    FROM GKBTSHOGAKKO
                    WHERE SYOGAKO_CD = RWK_IDO.SHOGAKU_CD;
                 EXCEPTION
                    WHEN OTHERS THEN
                      NKYOIKUIINKAI_CD := NULL ;
                      vSYOGAKOMEI      := NULL ;
                 END;
                 RWK.NEW_GAKKO  := vSYOGAKOMEI;
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                --ELSIF CR_I.SHOCHU_KBN =2 THEN 
                ELSIF CR_I.SHOCHU_KBN =2 AND NKYOIKUIINKAI_CD IS NULL THEN
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0),
                         TYUGAKOMEI
                    INTO NKYOIKUIINKAI_CD,
                         vTYUGAKOMEI
                    FROM GKBTCHUGAKKO
                    WHERE TYUGAKO_CD = RWK_IDO.SHOGAKU_CD;
                 EXCEPTION
                    WHEN OTHERS THEN
                      NKYOIKUIINKAI_CD := NULL ;
                      vTYUGAKOMEI      := NULL ;
                 END;
                 RWK.NEW_GAKKO  := vTYUGAKOMEI;
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応 
                --ELSIF CR_I.SHOCHU_KBN =3 THEN
                ELSIF CR_I.SHOCHU_KBN =3 AND NKYOIKUIINKAI_CD IS NULL THEN
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0),
                         KUIKIGAIMEI
                    INTO NKYOIKUIINKAI_CD,
                         vKUIKIGAIMEI
                    FROM GKBTKUIKIGAI
                    WHERE KUIKIGAI_CD = RWK_IDO.SHOGAKU_CD;
                 EXCEPTION
                    WHEN OTHERS THEN
                      NKYOIKUIINKAI_CD := NULL ;
                      vKUIKIGAIMEI      := NULL ;
                 END;
                 RWK.NEW_GAKKO  := vKUIKIGAIMEI;
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                --ELSIF CR_I.SHOCHU_KBN =4 THEN
                ELSIF CR_I.SHOCHU_KBN =4 AND NKYOIKUIINKAI_CD IS NULL  THEN 
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応 
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0),
                         YOGOGAKOMEI
                    INTO NKYOIKUIINKAI_CD,
                         vYOGOGAKOMEI
                    FROM GKBTYOGOGAKKO
                    WHERE YOGOGAKO_CD = RWK_IDO.SHOGAKU_CD;
                 EXCEPTION
                    WHEN OTHERS THEN
                      NKYOIKUIINKAI_CD := NULL ;
                      vYOGOGAKOMEI      := NULL ;
                 END;
                 RWK.NEW_GAKKO  := vYOGOGAKOMEI;
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                --ELSIF CR_I.SHOCHU_KBN =5 THEN
                ELSIF CR_I.SHOCHU_KBN =5 AND NKYOIKUIINKAI_CD IS NULL  THEN
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0),
                         KUNISHIRITSUGAKKOMEI
                    INTO NKYOIKUIINKAI_CD,
                         vKUNISHIRITSUGAKKOMEI
                    FROM GKBTKUNISIRITSUGAKKO
                    WHERE KUNISHIRITSUGAKKO_CD = RWK_IDO.SHOGAKU_CD;
                 EXCEPTION
                    WHEN OTHERS THEN
                      NKYOIKUIINKAI_CD := NULL ;
                      vKUNISHIRITSUGAKKOMEI      := NULL ;
                 END;
                 RWK.NEW_GAKKO  := vKUNISHIRITSUGAKKOMEI;
                ELSE
                    NULL;
                END IF;
                --旧学校名
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                --IF CR_I.SHOCHU_KBN =1 THEN
                IF CR_I.SHOCHU_KBN =1 AND NKYOIKUIINKAI_CD IS NULL    THEN
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0),
                         SYOGAKOMEI
                    INTO NKYOIKUIINKAI_CD,
                         vOLDSYOGAKOMEI
                    FROM GKBTSHOGAKKO
                    WHERE SYOGAKO_CD = RWK_IDO.OLD_SHOGAKU_CD;
                 EXCEPTION
                    WHEN OTHERS THEN
                      NKYOIKUIINKAI_CD := NULL ;
                      vOLDSYOGAKOMEI      := NULL ;
                 END;
                 RWK.OLD_GAKKO  := vOLDSYOGAKOMEI;
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                --ELSIF CR_I.SHOCHU_KBN =2 THEN
                ELSIF CR_I.SHOCHU_KBN =2 AND NKYOIKUIINKAI_CD IS NULL   THEN
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0),
                         TYUGAKOMEI
                    INTO NKYOIKUIINKAI_CD,
                         vOLDTYUGAKOMEI
                    FROM GKBTCHUGAKKO
                    WHERE TYUGAKO_CD = RWK_IDO.OLD_SHOGAKU_CD;
                 EXCEPTION
                    WHEN OTHERS THEN
                      NKYOIKUIINKAI_CD := NULL ;
                      vOLDTYUGAKOMEI      := NULL ;
                 END;
                 RWK.OLD_GAKKO  := vOLDTYUGAKOMEI;
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                --ELSIF CR_I.SHOCHU_KBN =3 THEN
                ELSIF CR_I.SHOCHU_KBN =3 AND NKYOIKUIINKAI_CD IS NULL   THEN
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応 
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0),
                         KUIKIGAIMEI
                    INTO NKYOIKUIINKAI_CD,
                         vOLDKUIKIGAIMEI
                    FROM GKBTKUIKIGAI
                    WHERE KUIKIGAI_CD = RWK_IDO.OLD_SHOGAKU_CD;
                 EXCEPTION
                    WHEN OTHERS THEN
                      NKYOIKUIINKAI_CD := NULL ;
                      vOLDKUIKIGAIMEI      := NULL ;
                 END;
                 RWK.OLD_GAKKO  := vOLDKUIKIGAIMEI;
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                --ELSIF CR_I.SHOCHU_KBN =4 THEN
                ELSIF CR_I.SHOCHU_KBN =4  AND NKYOIKUIINKAI_CD IS NULL   THEN
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0),
                         YOGOGAKOMEI
                    INTO NKYOIKUIINKAI_CD,
                         vOLDYOGOGAKOMEI
                    FROM GKBTYOGOGAKKO
                    WHERE YOGOGAKO_CD = RWK_IDO.OLD_SHOGAKU_CD;
                 EXCEPTION
                    WHEN OTHERS THEN
                      NKYOIKUIINKAI_CD := NULL ;
                      vOLDYOGOGAKOMEI      := NULL ;
                 END;
                 RWK.OLD_GAKKO  := vOLDYOGOGAKOMEI;
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                --ELSIF CR_I.SHOCHU_KBN =5 THEN
                ELSIF CR_I.SHOCHU_KBN =5   AND NKYOIKUIINKAI_CD IS NULL   THEN
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0),
                         KUNISHIRITSUGAKKOMEI
                    INTO NKYOIKUIINKAI_CD,
                         vOLDKUNISHIRITSUGAKKOMEI
                    FROM GKBTKUNISIRITSUGAKKO
                    WHERE KUNISHIRITSUGAKKO_CD = RWK_IDO.OLD_SHOGAKU_CD;
                 EXCEPTION
                    WHEN OTHERS THEN
                      NKYOIKUIINKAI_CD := NULL ;
                      vOLDKUNISHIRITSUGAKKOMEI      := NULL ;
                 END;
                 RWK.OLD_GAKKO  := vOLDKUNISHIRITSUGAKKOMEI;
                ELSE
                    NULL;
                END IF;
                RWK.IINKAI_MEI := O_VUSERMEI || '教育委員会';
--                IF I_KBN = 2 THEN
                IF CR_I.TSUCHISHO_KBN = 2 THEN
                    RWK.GAKKOCHO := RWK.OLD_GAKKO || '長';
                ELSE
                    RWK.GAKKOCHO := RWK.NEW_GAKKO || '長';
                END IF;
                RWK.GAKKO_NINSHO := '下記のとおり';
--                IF I_KBN = 1 THEN
                IF CR_I.TSUCHISHO_KBN = 1 THEN
                    RWK.GAKKO_NINSHO := RWK.GAKKO_NINSHO || '転入学';
--                ELSIF I_KBN = 2 THEN
                ELSIF CR_I.TSUCHISHO_KBN = 2 THEN
                    RWK.GAKKO_NINSHO := RWK.GAKKO_NINSHO || '転学';
                ELSE
                    RWK.GAKKO_NINSHO := RWK.GAKKO_NINSHO || '変更';
                END IF;
                RWK.GAKKO_NINSHO := RWK.GAKKO_NINSHO || 'がありましたので通知します。';
                RWK.KYOIKU_KOIN_MEI := O_VKOIN_GYOMU;
                RWK.KYOIKU_NINSHO := VKIJUNBI || '付、下記の通り異動がありましたので通知します。';
--                RWK.NINSHO_KATAGAKI := O_VSHUCHONINSHOBUN;
--                RWK.SHUCHO_MEI := O_VSHUCHOMEI;
--                RWK.SHUCHO_KOIN_MEI := O_VKOIN_SHUCHO;
                RWK.NINSHO_KATAGAKI := o_vKATAGAKI1;
                RWK.SHUCHO_MEI := o_vSHIMEI;
                RWK.SHUCHO_KOIN_MEI := o_vKOINFILENAME; 
--  2024/07/01 ZCZL.lwy Update End
                RWK.GAKKO_BIKO := NULL;
                RWK.KYOIKU_BIKO := NULL;
                RWK.SHORI_BI := NKIJUNBI;
                RWK.SHORI_JIKAN := TO_NUMBER(TO_CHAR(SYSDATE, 'HHMIDD'));
                RWK.TANMATSU_NO := g_sWSNUM;
                RWK.GYOSEIKU_CD := O_IUSER_ID;
                IF LENGTH(CR_I.GYOSEIKUMEI) > 0 THEN
                  RWK.GYOSEIKU_MEI := CR_I.GYOSEIKUMEI;
                ELSE
                  RWK.GYOSEIKU_MEI := NULL;
                END IF;
                IF LENGTH(CR_I.OLD_GYOSEIKUMEI) > 0 THEN
                  RWK.OLD_GYOSEIKU_MEI := CR_I.OLD_GYOSEIKUMEI;
                ELSE
                  RWK.OLD_GYOSEIKU_MEI := NULL;
                END IF;
                RWK.YOBI1 := NULL;
                RWK.YOBI2 := NULL;
                RWK.YOBI3 := NULL;
                RWK.YOBI4 := NULL;
                RWK.YOBI5 := NULL;
                RWK.YOBI6 := NULL;
--  2024/10/28 ZCZL.WANGMING ADD START 0.3.000.005:IT_GKB_00396対応
                o_KYOIKUPRM := A_CONS_PRM();
                o_KYOIKUPRM.EXTEND(8);
--  2024/10/28 ZCZL.WANGMING ADD END
                IF NKYOIKUIINKAI_CD IS NOT NULL THEN
--  2024/10/28 ZCZL.WANGMING DELETE 0.3.000.005:IT_GKB_00396対応
--                  o_KYOIKUPRM := A_CONS_PRM();
                    IKYOUIKUIINKAIJOUHOU       := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',NKYOIKUIINKAI_CD,o_KYOIKUPRM,o_LENGTH);
                    IF IKYOUIKUIINKAIJOUHOU = 1 THEN
                        o_KYOIKUPRM := A_CONS_PRM();
                        o_KYOIKUPRM.EXTEND;
                        o_KYOIKUPRM.EXTEND;
                        o_KYOIKUPRM(1) := ' ';
                        o_KYOIKUPRM.EXTEND;
                        o_KYOIKUPRM(2) := ' ';
                        o_KYOIKUPRM.EXTEND;
                        o_KYOIKUPRM(3) := ' ';
                        o_KYOIKUPRM.EXTEND;
                        o_KYOIKUPRM(4) := ' ';
                        o_KYOIKUPRM.EXTEND;
                        o_KYOIKUPRM(5) := ' ';
                        o_KYOIKUPRM.EXTEND;
                        o_KYOIKUPRM(6) := ' ';
                        o_KYOIKUPRM.EXTEND;
                        o_KYOIKUPRM(7) := ' ';
                        o_KYOIKUPRM.EXTEND;
                        o_KYOIKUPRM(8) := ' ';
                    ELSE
                      WHILE (o_LENGTH < 8) LOOP
                        o_KYOIKUPRM.EXTEND;
                        o_KYOIKUPRM(o_LENGTH+1) := ' ';
                        o_LENGTH := o_LENGTH + 1;
                      END LOOP;
                   END IF;
                   RWK.IDOJIKO               :=CR_I.IDOJIKO;   -- 異動事項
                   RWK.SHUGAKU               :=CR_I.SHUGAKU;   -- 就学状況
                   RWK.KYOIKUKAI_MEI         :=o_KYOIKUPRM(1);  -- 教育委員会名
                   RWK.KYOIKU_YAKUSHOKU_MEI  :=o_KYOIKUPRM(2);  -- 教育委員会役職名
                   RWK.KYOIKU_SHUTHOU_MEI    :=o_KYOIKUPRM(3);  -- 教育委員会首長名
                   RWK.KYOIKU_RITSU_MEI      :=o_KYOIKUPRM(4);  -- 教育委員会立区名
                   IF  LENGTH(RWK.KYOIKU_YUBIN_NO)>3 THEN
                       RWK.KYOIKU_YUBIN_NO := SUBSTR(o_KYOIKUPRM(5),1,3) || '-' || SUBSTR(o_KYOIKUPRM(5),4);  -- 教育委員会郵便番号
                   ELSE
                      RWK.KYOIKU_YUBIN_NO := o_KYOIKUPRM(5);  -- 教育委員会郵便番号
                   END IF;
                   RWK.KYOIKU_YUBIN_NO := TRANSLATE(RWK.KYOIKU_YUBIN_NO, '1234567890-', '１２３４５６７８９０－');
                   RWK.KYOIKU_JUSHO          :=o_KYOIKUPRM(6);  -- 教育委員会住所
                   RWK.KYOIKU_TEL            :=o_KYOIKUPRM(7);  -- 教育委員会電話番号
                   RWK.KYOIKU_TEL_NAISEN     :=o_KYOIKUPRM(8);  -- 教育委員会内線
                 ELSE
                   RWK.IDOJIKO               :=CR_I.IDOJIKO;   -- 異動事項
                   RWK.SHUGAKU               :=CR_I.SHUGAKU;   -- 就学状況
                   RWK.KYOIKUKAI_MEI         :=NULL;           -- 教育委員会名
                   RWK.KYOIKU_YAKUSHOKU_MEI  :=NULL;           -- 教育委員会役職名
                   RWK.KYOIKU_SHUTHOU_MEI    :=NULL;           -- 教育委員会首長名
                   RWK.KYOIKU_RITSU_MEI      :=NULL;           -- 教育委員会立区名
                   RWK.KYOIKU_YUBIN_NO       :=NULL;           -- 教育委員会郵便番号
                   RWK.KYOIKU_JUSHO          :=NULL;           -- 教育委員会住所
                   RWK.KYOIKU_TEL            :=NULL;           -- 教育委員会電話番号
                   RWK.KYOIKU_TEL_NAISEN     :=NULL;           -- 教育委員会内線
                END IF;
                --------------------
                -- グループ内の児童を３名ずつ転記する
                -- グループとは、異動日、世帯、異動の種類、新旧学校名が同じ児童
                -- すでに、このストアド内部のワークテーブルでグループ分けはされている
                --------------------
                LOOP
                    RWK.SEQ_NO_1 := SEQ_NO;
                    RWK.KOJIN_NO_1 := CR_I.KOJIN_NO;
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
                    --児童1の制御情報を取得
--                     BEGIN
--                      SELECT NAIYO_CD INTO N_NAIYO_CD_JIDO_1 FROM GKBTSHIMEIJKN
--                       WHERE KOJIN_NO = CR_I.KOJIN_NO AND CHOHYO_ID = 'GKB620R001';
--                     EXCEPTION
--                       WHEN OTHERS THEN
--                         N_NAIYO_CD_JIDO_1 := 0;
--                     END;
                    --KOJIN_NO_1で人格区分を取得
--                     BEGIN
--                      IRTN := GAAPK0030.FGETATENA(CR_I.KOJIN_NO,
--                                                  'GKB',
--                                                  NKIJUNBI,
--                                                  RA,
--                                                  RASO);
--                     EXCEPTION
--                       WHEN OTHERS THEN
--                         NULL;
--                     END;
                    --保護者個人番号で人格区分を取得
--                     BEGIN
--                      IRTN := GAAPK0030.FGETATENA(CR_I.HOGOSHA_NO,
--                                                  'GKB',
--                                                  NKIJUNBI,
--                                                  RAHOKEN,
--                                                  RASOHOKEN);
--                     EXCEPTION
--                       WHEN OTHERS THEN
--                         NULL;
--                     END;
                    --SHIMEI_KANA_1の編集
                    --SHIMEI_KANJI_1の編集
                    --外国人場合
--                     IF RA.JINKAKU_KBN = 1 THEN
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(RA.SHIMEI_KANA),TRIM(RA.HONMYO_KANA));
--                      RWK.SHIMEI_KANA_1 := VEDIT_GO_DATA;
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(RA.SHIMEI_KANJI),TRIM(RA.HONMYO_KANJI));
--                      RWK.SHIMEI_KANJI_1 := VEDIT_GO_DATA;
--                     ELSE
                     --外国人以外場合
--                       IF o_MEISYUPRM(3) = 1 THEN
--                         IF CR_I.HONMYO_KANA IS NOT NULL THEN
--                           RWK.SHIMEI_KANA_1 := CR_I.HONMYO_KANA;
--                         ELSE
--                           RWK.SHIMEI_KANA_1 := CR_I.SHIMEI_KANA;
--                         END IF;
--                         IF CR_I.HONMYO_KANJI IS NOT NULL THEN
--                           RWK.SHIMEI_KANJI_1 := CR_I.HONMYO_KANJI;
--                         ELSE
--                           RWK.SHIMEI_KANJI_1 := CR_I.SHIMEI_KANJI;
--                         END IF;
--                       ELSE
--                         RWK.SHIMEI_KANA_1 := CR_I.SHIMEI_KANA;
--                         RWK.SHIMEI_KANJI_1 := CR_I.SHIMEI_KANJI;
--                       END IF;
--                      END IF;
--  2025/01/10 JPJYS.LIZIZHONG UPDATE 0.3.000.012:品質強化 IT_GKB_10236 STR
--                    IRTN := GKBFKHMCTRL(RWK.KOJIN_NO_1, g_rJSTP.CHOHYOID, 0, vSYSSEIGYONO, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY);
                    IRTN := GKBFKHMCTRL(RWK.KOJIN_NO_1, g_rJSTP.CHOHYOID, 0, 0, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY);
--  2025/01/10 JPJYS.LIZIZHONG UPDATE 0.3.000.012:品質強化 IT_GKB_10236 END                    
                    RWK.SHIMEI_KANA_1  := o_sSHIMEIKANA;
                    RWK.SHIMEI_KANJI_1 := o_sSHIMEI;
                    RWK.SEIBETSU_1 := FUNC_GET_SEIBETSU_STR(CR_I.SEIBETSU);
--                     IF RA.JINKAKU_KBN = 1 THEN
--                      RWK.SEINENGAPI_1 := FUNC_SET_SEIGYO_SEINENGAPI(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1) || CR_I.SEINENGAPI;
--                     ELSE
--                      RWK.SEINENGAPI_1 := TO_CHAR(CR_I.JINKAKU_KBN) || TO_CHAR(CR_I.SEINENGAPI);
--                     END IF;
                    RWK.SEINENGAPI_1 := o_sBIRTHDAY;
                    RWK.GAKUNEN_1 := CR_I.GAKUNEN;
                    RWK.HOGOSHA_KOJIN_NO_1 := CR_I.HOGOSHA_NO;
                    --外国人場合
--                     IF RAHOKEN.JINKAKU_KBN = 1 THEN
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(CR_I.HOGOSHA_KANA),TRIM(CR_I.HOGOSHA_HONMYO_KANA));
--                      RWK.HOGOSHA_KANA_1 := VEDIT_GO_DATA;
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(CR_I.HOGOSHA_KANJI),TRIM(CR_I.HOGOSHA_HONMYO_KANJI));
--                      RWK.HOGOSHA_KANJI_1 := VEDIT_GO_DATA;
--                     ELSE
                     --外国人以外場合
--                       IF o_MEISYUPRM(3) = 1 THEN
--                         IF CR_I.HOGOSHA_HONMYO_KANA IS NOT NULL THEN
--                           RWK.HOGOSHA_KANA_1 := CR_I.HOGOSHA_HONMYO_KANA;
--                         ELSE
--                           RWK.HOGOSHA_KANA_1 := CR_I.HOGOSHA_KANA;
--                         END IF;
--                         IF CR_I.HOGOSHA_HONMYO_KANJI IS NOT NULL THEN
--                           RWK.HOGOSHA_KANJI_1 := CR_I.HOGOSHA_HONMYO_KANJI;
--                         ELSE
--                           RWK.HOGOSHA_KANJI_1 := CR_I.HOGOSHA_KANJI;
--                         END IF;
--                       ELSE
--                         RWK.HOGOSHA_KANA_1 := CR_I.HOGOSHA_KANA;
--                         RWK.HOGOSHA_KANJI_1 := CR_I.HOGOSHA_KANJI;
--                       END IF;
--                      END IF;
--  2025/01/10 JPJYS.LIZIZHONG UPDATE 0.3.000.012:品質強化 IT_GKB_10236 STR
--                    IRTN := GKBFKHMCTRL(RWK.KOJIN_NO_1, g_rJSTP.CHOHYOID, 1, vSYSSEIGYONO, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY);
                    IRTN := GKBFKHMCTRL(RWK.KOJIN_NO_1, g_rJSTP.CHOHYOID, 1, 0, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY);
--  2025/01/10 JPJYS.LIZIZHONG UPDATE 0.3.000.012:品質強化 IT_GKB_10236 END                    
                    RWK.HOGOSHA_KANA_1     := o_sSHIMEIKANA;
                    RWK.HOGOSHA_KANJI_1    := o_sSHIMEI;
                    RWK.HOGOSHA_TSUDUKIGARA_1 := CR_I.HOGOSHA_TSUDUKIGARA;
                    RWK.TSUDUKIGARA_1 := CR_I.TSUDUKIGARA;
                      IF o_MEISYUPRM(3) = 2 THEN
                        IF CR_I.HONMYO_KANJI IS NOT NULL THEN
                          RWK.SHIMEI_BIKO1 := '児童本名：' || CR_I.HONMYO_KANJI || '(' || CR_I.HONMYO_KANA || ')';
                        ELSE
                          RWK.SHIMEI_BIKO1 := NULL;
                        END IF;
                        IF CR_I.HOGOSHA_HONMYO_KANJI IS NOT NULL THEN
                          RWK.SHIMEI_BIKO2 := '保護者本名：' || CR_I.HOGOSHA_HONMYO_KANJI || '(' || CR_I.HOGOSHA_HONMYO_KANA || ')';
                        ELSE
                          RWK.SHIMEI_BIKO2 := NULL;
                        END IF;
                      ELSE
                        RWK.SHIMEI_BIKO1 := NULL;
                        RWK.SHIMEI_BIKO2 := NULL;
                      END IF;
                    RWK.TENNYUGAKU_BI_MEI := CR_I.TENNYUGAKU_BI_MEI;
                    RWK.TENNYUGAKU_BI     := CR_I.TENNYUGAKU_BI;
--                     FETCH CINTER INTO CR_I;
--                     IF CINTER%NOTFOUND THEN
--                         INSERT INTO GKBWIDOTSUCHI VALUES RWK;
--                         EXIT;
--                     END IF;
--                    RWK.SEQ_NO_2 := SEQ_NO;
--                    RWK.KOJIN_NO_2 := CR_I.KOJIN_NO;
                    RWK.SEQ_NO_2               := NULL;
                    RWK.KOJIN_NO_2             := NULL;
                    RWK.SHIMEI_KANA_2          := NULL;
                    RWK.SHIMEI_KANJI_2         := NULL;
                    RWK.SEIBETSU_2             := NULL;
                    RWK.SEINENGAPI_2           := NULL;
                    RWK.GAKUNEN_2              := NULL;
                    RWK.HOGOSHA_KOJIN_NO_2     := NULL;
                    RWK.HOGOSHA_KANA_2         := NULL;
                    RWK.HOGOSHA_KANJI_2        := NULL;
                    RWK.HOGOSHA_TSUDUKIGARA_2  := NULL;
                    RWK.TSUDUKIGARA_2          := NULL;
                    RWK.SHIMEI_BIKO3           := NULL;                
                    RWK.SHIMEI_BIKO4           := NULL;
                    --児童1の制御情報を取得
--                     BEGIN
--                      SELECT NAIYO_CD INTO N_NAIYO_CD_JIDO_1 FROM GKBTSHIMEIJKN
--                       WHERE KOJIN_NO = CR_I.KOJIN_NO AND CHOHYO_ID = 'GKB620R001';
--                     EXCEPTION
--                       WHEN OTHERS THEN
--                         N_NAIYO_CD_JIDO_1 := 0;
--                     END;
                    --KOJIN_NO_1で人格区分を取得
--                     BEGIN
--                      IRTN := GAAPK0030.FGETATENA(CR_I.KOJIN_NO,
--                                                  'GKB',
--                                                  NKIJUNBI,
--                                                  RA,
--                                                  RASO);
--                     EXCEPTION
--                       WHEN OTHERS THEN
--                         NULL;
--                     END;
                    --保険者個人番号で人格区分を取得
--                     BEGIN
--                      IRTN := GAAPK0030.FGETATENA(CR_I.HOGOSHA_NO,
--                                                  'GKB',
--                                                  NKIJUNBI,
--                                                  RAHOKEN,
--                                                  RASOHOKEN);
--                     EXCEPTION
--                       WHEN OTHERS THEN
--                         NULL;
--                     END;
                    --SHIMEI_KANA_2の編集
                    --SHIMEI_KANJI_2の編集
                    --外国人場合
--                     IF RA.JINKAKU_KBN = 1 THEN
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(CR_I.SHIMEI_KANA),TRIM(CR_I.HONMYO_KANA));
--                      RWK.SHIMEI_KANA_2 := VEDIT_GO_DATA;

--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(CR_I.SHIMEI_KANJI),TRIM(CR_I.HONMYO_KANJI));
--                      RWK.SHIMEI_KANJI_2 := VEDIT_GO_DATA;

--                     ELSE
                     --外国人以外場合
--                       IF o_MEISYUPRM(3) = 1 THEN
--                         IF CR_I.HONMYO_KANA IS NOT NULL THEN
--                           RWK.SHIMEI_KANA_2 := CR_I.HONMYO_KANA;
--                         ELSE
--                           RWK.SHIMEI_KANA_2 := CR_I.SHIMEI_KANA;
--                         END IF;
--                         IF CR_I.HONMYO_KANJI IS NOT NULL THEN
--                           RWK.SHIMEI_KANJI_2 := CR_I.HONMYO_KANJI;
--                         ELSE
--                           RWK.SHIMEI_KANJI_2 := CR_I.SHIMEI_KANJI;
--                         END IF;
--                       ELSE
--                         RWK.SHIMEI_KANA_2 := CR_I.SHIMEI_KANA;
--                         RWK.SHIMEI_KANJI_2 := CR_I.SHIMEI_KANJI;
--                       END IF;
--                     END IF;
--                    RWK.SEIBETSU_2 := FUNC_GET_SEIBETSU_STR(CR_I.SEIBETSU);
--                    IF RA.JINKAKU_KBN = 1 THEN
--                     RWK.SEINENGAPI_2 := FUNC_SET_SEIGYO_SEINENGAPI(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1) || CR_I.SEINENGAPI;
--                    ELSE
--                     RWK.SEINENGAPI_2 := TO_CHAR(CR_I.JINKAKU_KBN) || TO_CHAR(CR_I.SEINENGAPI);
--                    END IF;
--                    RWK.GAKUNEN_2 := FUNC_GET_GAKUNEN_STR(CR_I.GAKUNEN);
--                    RWK.HOGOSHA_KOJIN_NO_2 := CR_I.HOGOSHA_NO;
                    --外国人場合
--                     IF RAHOKEN.JINKAKU_KBN = 1 THEN
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(CR_I.HOGOSHA_KANA),TRIM(CR_I.HOGOSHA_HONMYO_KANA));
--                      RWK.HOGOSHA_KANA_2 := VEDIT_GO_DATA;
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(CR_I.HOGOSHA_KANJI),TRIM(CR_I.HOGOSHA_HONMYO_KANJI));
--                      RWK.HOGOSHA_KANJI_2 := VEDIT_GO_DATA;
--                     ELSE
                     --外国人以外場合
--                       IF o_MEISYUPRM(3) = 1 THEN
--                         IF CR_I.HOGOSHA_HONMYO_KANA IS NOT NULL THEN
--                           RWK.HOGOSHA_KANA_2 := CR_I.HOGOSHA_HONMYO_KANA;
--                         ELSE
--                           RWK.HOGOSHA_KANA_2 := CR_I.HOGOSHA_KANA;
--                         END IF;
--                         IF CR_I.HOGOSHA_HONMYO_KANJI IS NOT NULL THEN
--                           RWK.HOGOSHA_KANJI_2 := CR_I.HOGOSHA_HONMYO_KANJI;
--                         ELSE
--                           RWK.HOGOSHA_KANJI_2 := CR_I.HOGOSHA_KANJI;
--                         END IF;
--                       ELSE
--                         RWK.HOGOSHA_KANA_2 := CR_I.HOGOSHA_KANA;
--                         RWK.HOGOSHA_KANJI_2 := CR_I.HOGOSHA_KANJI;
--                       END IF;
--                      END IF;
--                    RWK.HOGOSHA_TSUDUKIGARA_2 := CR_I.HOGOSHA_TSUDUKIGARA;
--                    RWK.TSUDUKIGARA_2 := CR_I.TSUDUKIGARA;
--                      IF o_MEISYUPRM(3) = 2 THEN
--                        IF CR_I.HONMYO_KANJI IS NOT NULL THEN
--                          RWK.SHIMEI_BIKO3 := '児童本名：' || CR_I.HONMYO_KANJI || '(' || CR_I.HONMYO_KANA || ')';
--                        ELSE
--                          RWK.SHIMEI_BIKO3 := NULL;
--                        END IF;
--                        IF CR_I.HOGOSHA_HONMYO_KANJI IS NOT NULL THEN
--                          RWK.SHIMEI_BIKO4 := '保護者本名：' || CR_I.HOGOSHA_HONMYO_KANJI || '(' || CR_I.HOGOSHA_HONMYO_KANA || ')';
--                        ELSE
--                          RWK.SHIMEI_BIKO4 := NULL;
--                        END IF;
--                      ELSE
--                        RWK.SHIMEI_BIKO3 := NULL;
--                        RWK.SHIMEI_BIKO4 := NULL;
--                      END IF;
--                     FETCH CINTER INTO CR_I;
--                     IF CINTER%NOTFOUND THEN
--                         INSERT INTO GKBWIDOTSUCHI VALUES RWK;
--                         EXIT;
--                     END IF;
--                    RWK.SEQ_NO_3 := SEQ_NO;
--                    RWK.KOJIN_NO_3 := CR_I.KOJIN_NO;
                    RWK.SEQ_NO_3               := NULL;
                    RWK.KOJIN_NO_3             := NULL;
                    RWK.SHIMEI_KANA_3          := NULL;
                    RWK.SHIMEI_KANJI_3         := NULL;
                    RWK.SEIBETSU_3             := NULL;
                    RWK.SEINENGAPI_3           := NULL;
                    RWK.GAKUNEN_3              := NULL;
                    RWK.HOGOSHA_KOJIN_NO_3     := NULL;
                    RWK.HOGOSHA_KANA_3         := NULL;
                    RWK.HOGOSHA_KANJI_3        := NULL;
                    RWK.HOGOSHA_TSUDUKIGARA_3  := NULL;
                    RWK.TSUDUKIGARA_3          := NULL;
                    RWK.SHIMEI_BIKO5           := NULL;                
                    RWK.SHIMEI_BIKO6           := NULL;
                    --児童1の制御情報を取得
--                     BEGIN
--                      SELECT NAIYO_CD INTO N_NAIYO_CD_JIDO_1 FROM GKBTSHIMEIJKN
--                       WHERE KOJIN_NO = CR_I.KOJIN_NO AND CHOHYO_ID = 'GKB620R001';
--                     EXCEPTION
--                       WHEN OTHERS THEN
--                         N_NAIYO_CD_JIDO_1 := 0;
--                     END;
                    --KOJIN_NO_1で人格区分を取得
--                     BEGIN
--                      IRTN := GAAPK0030.FGETATENA(CR_I.KOJIN_NO,
--                                                  'GKB',
--                                                  NKIJUNBI,
--                                                  RA,
--                                                  RASO);
--                     EXCEPTION
--                       WHEN OTHERS THEN
--                         NULL;
--                     END;
                    --保険者個人番号で人格区分を取得
--                     BEGIN
--                      IRTN := GAAPK0030.FGETATENA(CR_I.HOGOSHA_NO,
--                                                  'GKB',
--                                                  NKIJUNBI,
--                                                  RAHOKEN,
--                                                  RASOHOKEN);
--                     EXCEPTION
--                       WHEN OTHERS THEN
--                         NULL;
--                     END;
                    --SHIMEI_KANA_3の編集
                    --SHIMEI_KANJI_3の編集
                    --外国人場合
--                     IF RA.JINKAKU_KBN = 1 THEN
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(CR_I.SHIMEI_KANA),TRIM(CR_I.HONMYO_KANA));
--                      RWK.SHIMEI_KANA_3 := VEDIT_GO_DATA;
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(CR_I.SHIMEI_KANJI),TRIM(CR_I.HONMYO_KANJI));
--                      RWK.SHIMEI_KANJI_3 := VEDIT_GO_DATA;
--                     ELSE
                     --外国人以外場合
--                       IF o_MEISYUPRM(3) = 1 THEN
--                         IF CR_I.HONMYO_KANA IS NOT NULL THEN
--                           RWK.SHIMEI_KANA_3 := CR_I.HONMYO_KANA;
--                         ELSE
--                           RWK.SHIMEI_KANA_3 := CR_I.SHIMEI_KANA;
--                         END IF;
--                         IF CR_I.HONMYO_KANJI IS NOT NULL THEN
--                           RWK.SHIMEI_KANJI_3 := CR_I.HONMYO_KANJI;
--                         ELSE
--                           RWK.SHIMEI_KANJI_3 := CR_I.SHIMEI_KANJI;
--                         END IF;
--                       ELSE
--                         RWK.SHIMEI_KANA_3 := CR_I.SHIMEI_KANA;
--                         RWK.SHIMEI_KANJI_3 := CR_I.SHIMEI_KANJI;
--                       END IF;
--                      END IF;
--                    RWK.SEIBETSU_3 := FUNC_GET_SEIBETSU_STR(CR_I.SEIBETSU);
--                    IF RA.JINKAKU_KBN = 1 THEN
--                     RWK.SEINENGAPI_3 := FUNC_SET_SEIGYO_SEINENGAPI(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1) || CR_I.SEINENGAPI;
--                    ELSE
--                     RWK.SEINENGAPI_3 := TO_CHAR(CR_I.JINKAKU_KBN) || TO_CHAR(CR_I.SEINENGAPI);
--                    END IF;
--                    RWK.GAKUNEN_3 := FUNC_GET_GAKUNEN_STR(CR_I.GAKUNEN);
--                    RWK.HOGOSHA_KOJIN_NO_3 := CR_I.HOGOSHA_NO;
                    --外国人場合
--                     IF RAHOKEN.JINKAKU_KBN = 1 THEN
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(CR_I.HOGOSHA_KANA),TRIM(CR_I.HOGOSHA_HONMYO_KANA));
--                      RWK.HOGOSHA_KANA_3 := VEDIT_GO_DATA;
--                      VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                       TRIM(CR_I.HOGOSHA_KANJI),TRIM(CR_I.HOGOSHA_HONMYO_KANJI));
--                      RWK.HOGOSHA_KANJI_3 := VEDIT_GO_DATA;
--                     ELSE
                     --外国人以外場合
--                       IF o_MEISYUPRM(3) = 1 THEN
--                         IF CR_I.HOGOSHA_HONMYO_KANA IS NOT NULL THEN
--                           RWK.HOGOSHA_KANA_3 := CR_I.HOGOSHA_HONMYO_KANA;
--                         ELSE
--                           RWK.HOGOSHA_KANA_3 := CR_I.HOGOSHA_KANA;
--                         END IF;
--                         IF CR_I.HOGOSHA_HONMYO_KANJI IS NOT NULL THEN
--                           RWK.HOGOSHA_KANJI_3 := CR_I.HOGOSHA_HONMYO_KANJI;
--                         ELSE
--                           RWK.HOGOSHA_KANJI_3 := CR_I.HOGOSHA_KANJI;
--                         END IF;
--                       ELSE
--                         RWK.HOGOSHA_KANA_3 := CR_I.HOGOSHA_KANA;
--                         RWK.HOGOSHA_KANJI_3 := CR_I.HOGOSHA_KANJI;
--                       END IF;
--                      END IF;
--                    RWK.HOGOSHA_TSUDUKIGARA_3 := CR_I.HOGOSHA_TSUDUKIGARA;
--                    RWK.TSUDUKIGARA_3 := CR_I.TSUDUKIGARA;
--                      IF o_MEISYUPRM(3) = 2 THEN
--                        IF CR_I.HONMYO_KANJI IS NOT NULL THEN
--                         RWK.SHIMEI_BIKO5 := '児童本名：' || CR_I.HONMYO_KANJI || '(' || CR_I.HONMYO_KANA || ')';
--                        ELSE
--                          RWK.SHIMEI_BIKO5 := NULL;
--                        END IF;
--                        IF CR_I.HOGOSHA_HONMYO_KANJI IS NOT NULL THEN
--                          RWK.SHIMEI_BIKO6 := '保護者本名：' || CR_I.HOGOSHA_HONMYO_KANJI || '(' || CR_I.HOGOSHA_HONMYO_KANA || ')';
--                        ELSE
--                          RWK.SHIMEI_BIKO6 := NULL;
--                        END IF;
--                      ELSE
--                        RWK.SHIMEI_BIKO5 := NULL;
--                        RWK.SHIMEI_BIKO6 := NULL;
--                      END IF;
--  2024/07/01 ZCZL.lwy Update End
                    RWK.TENNYUGAKU_BI_MEI := CR_I.TENNYUGAKU_BI_MEI;
                    RWK.TENNYUGAKU_BI     := CR_I.TENNYUGAKU_BI;
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
                    RWK.TSUCHISHO_KBN     := CR_I.TSUCHISHO_KBN;
                    RWK.JINKAKU_KBN       := CR_I.JINKAKU_KBN;
                    RWK.OLD_SHIMEI_KANA   := CR_I.OLD_SHIMEI_KANA;
                    RWK.OLD_SHIMEI_KANJI  := CR_I.OLD_SHIMEI_KANJI;
                    RWK.KOIN_SHORYAKU     := vKOIN_SHORYAKU;
                    RWK.KOIN_CHUSHAKU     := vKOIN_CHUSHAKU;
-- 2025/05/08 CTC.GL UPDATE Start 1.0.003.000:GKB_QA13682対応
                    --RWK.OLD_HOGOSHA_SHIMEI_KANA  :=  CR_I.OLD_SHIMEI_KANA;                                
                    --RWK.OLD_HOGOSHA_SHIMEI_KANJI := CR_I.OLD_SHIMEI_KANJI;                                  
                    RWK.OLD_HOGOSHA_SHIMEI_KANA  :=  CR_I.OLD_HOGOSHA_KANA;                                
                    RWK.OLD_HOGOSHA_SHIMEI_KANJI := CR_I.OLD_HOGOSHA_KANJI;                                  
-- 2025/05/08 CTC.GL UPDATE End
                    RWK.OLD_GAKUNEN       := CR_I.OLD_GAKUNEN;         
                    RWK.YOSHIKI_NO        := vYOSHIKI_BANGO_SETTOGO || vYOSHIKI_BANGO || vYOSHIKI_BANGO_SETSUBIGO;
                    RWK.BUNSHO_NO         := NULL;
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応    
                    --WK.HAKKO_NENGAPI     := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_vJYOUKEN10, 'YYYYMMDD'), 'YYYY/MM/DD'), 12);
                    RWK.HAKKO_NENGAPI     := KKAPK0020.FDAYEDIT20(g_vJYOUKEN10, 0, 3);
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応    
                    RWK.SOFU_YUBIN        := NULL;                                
                    RWK.SOFU_JUSHO        := NULL;                                
                    RWK.SOFU_KATAGAKI     := NULL;                               
                    RWK.SOFU_ATENA        := NULL;                               
                    RWK.YUBIN_NOBC        := NULL;                              
                    RWK.TOIAWASESAKI1     := o_KYOIKUPRM(1);
                    RWK.TOIAWASESAKI2     := o_KYOIKUPRM(6);
                    RWK.TOIAWASESAKI3     := o_KYOIKUPRM(7);
                    RWK.TSUCHIBUN         := REPLACE(vTSUCHIBUN, chr(13)||chr(10),'#');                                
--  2024/07/01 ZCZL.lwy Add End                    
                    INSERT INTO GKBWIDOTSUCHI VALUES RWK;
                    FETCH CINTER INTO CR_I;
                    IF CINTER%NOTFOUND THEN
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
            -- カーソルのクローズ
            CLOSE CINTER;
        END LOOP;
        COMMIT;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
            RETURN FALSE;
    END FUNC_CREATE_WORK;

--  2024/07/01 ZCZL.lwy Delete Start 0.3.000.000:新WizLIFE２次開発（標準化）
    --------------------------------------------------------
    --  機能概要      : ワークテーブル作成２
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 成功 TRUE,失敗 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------

--     FUNCTION FUNC_CREATE_WORK2 RETURN  BOOLEAN
--     IS
        --------------------
        -- カーソル定義
        --------------------
--         CURSOR CGRPNO IS
--             SELECT *
--               FROM GKBWINTERNAL
--              ORDER BY HOGOSHA_NO, SEINENGAPI;
-- 
--         CURSOR CATENA (N_KOJIN_NO NUMBER) IS
--             SELECT EA.* FROM GABVATENAALL EA
--              WHERE EA.KOJIN_NO = N_KOJIN_NO
--                AND EA.RIREKI_RENBAN = ( SELECT MAX(E.RIREKI_RENBAN)
--                                           FROM GABVATENAALL E
--                                          WHERE E.SYS_SAKUSEIBI < NKAISHI_SEIREKI
--                                            AND E.KOJIN_NO = N_KOJIN_NO);
-- 
--         CURSOR CGAKUREIBO (N_KOJIN_NO NUMBER) IS
--             SELECT DISTINCT G.HOGOSYA_KOJIN_NO, G.ZOKUGARA1, G.ZOKUGARA2, G.ZOKUGARA3, G.ZOKUGARA4, B.ZOKUGARA_MEI
--               FROM (SELECT * FROM GKBTGAKUREIBO GA
--                      WHERE  GA.RIREKI_RENBAN = ( SELECT MAX(GK.RIREKI_RENBAN)
--                                                    FROM GKBTGAKUREIBO GK
--                                                   WHERE GK.KOJIN_NO = GA.KOJIN_NO
--                                                     AND GK.SYS_SAKUSEIBI < NKAISHI_SEIREKI)
--                      ) G,
--                    GABVATENAALL B
--              WHERE B.KOJIN_NO = N_KOJIN_NO
--                AND G.KOJIN_NO(+) = B.KOJIN_NO
--                AND B.RIREKI_RENBAN = (SELECT MAX(A.RIREKI_RENBAN)
--                                         FROM GABVATENAALL A
--                                        WHERE A.KOJIN_NO = B.KOJIN_NO
--                                          AND A.SYS_SAKUSEIBI < NKAISHI_SEIREKI);
        --------------------
        -- 変数定義
        --------------------
--         RWK         GKBWIDOTSUCHI%ROWTYPE;
-- 
--         N_NAIYO_CD_JIDO_1         GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;
--         VEDIT_GO_DATA             NVARCHAR2(1000) := '';
--         RA                        GABTATENAKIHON%ROWTYPE;
--         RASO                      GABTSOFUSAKI%ROWTYPE;
--         RAHOKEN                   GABTATENAKIHON%ROWTYPE;
--         RASOHOKEN                 GABTSOFUSAKI%ROWTYPE;
-- 
--         W_HOGOSHA_KANA            GABTATENAKIHON.SHIMEI_KANA%TYPE;
--         W_HOGOSHA_HONMYO_KANA     GABTATENAKIHON.HONMYO_KANA%TYPE;
--         W_HOGOSHA_KANJI           GABTATENAKIHON.SHIMEI_KANJI%TYPE;
--         W_HOGOSHA_HONMYO_KANJI    GABTATENAKIHON.HONMYO_KANJI%TYPE;
--         W_HOGOSYA_KOJIN_NO        NUMBER(12);
--         W_HOGOSHA_CHOMEI          GABTATENAKIHON.CHOMEI%TYPE;
--         W_HOGOSHA_BANCHI          GABTATENAKIHON.BANCHI%TYPE;
--         W_HOGOSHA_KATAGAKI        GABTATENAKIHON.KATAGAKI%TYPE;
--         O_ZOKUGARA1               NUMBER;
--         O_ZOKUGARA2               NUMBER;
--         O_ZOKUGARA3               NUMBER;
--         O_ZOKUGARA4               NUMBER;
--         o_VZOKUGARAMEI            NVARCHAR2(30);
--         IHERR                     PLS_INTEGER;
--         o_IHERR                   PLS_INTEGER;
-- 
--         W_GAKKO_CD                NUMBER;
--         W_GAKKO_NM                NVARCHAR2(60);
-- 
--     BEGIN
--         FOR CR_I IN CGRPNO LOOP
--           RWK := NULL;
--           RWK.TITLE := '変更通知書';

--           RWK.IDO_JIYU     := CR_I.IDO_JIYU;     --異動事由
          --異動事由名称
--           IF RWK.IDO_JIYU <> 0 THEN
--             RWK.IDO_JIYU_MEI := FUNC_GET_IDOJIYUMEI(CR_I.IDO_JIYU);
--           ELSE
--             RWK.IDO_JIYU_MEI := '';
--           END IF;
--           RWK.IDO_BI       := CR_I.IDO_BI;       --異動日
--           RWK.TODOKEDE_BI  := CR_I.TODOKE_BI;    --届出日
--           RWK.SETAI_NO     := CR_I.SETAI_NO;     --世帯番号
--           RWK.ALL_PAGE     := NULL;
--           RWK.PAGE         := NULL;
--           RWK.NEW_CHOMEI   := CR_I.CHOMEI;       -- 町名
--           RWK.NEW_BANCHI   := CR_I.BANCHI;       -- 番地
--           RWK.NEW_KATAGAKI := CR_I.KATAGAKI;     -- 方書
--           RWK.OLD_CHOMEI   := CR_I.KYUCHOMEI;    -- 旧町名
--           RWK.OLD_BANCHI   := CR_I.KYUBANCHI;    -- 旧番地
--           RWK.OLD_KATAGAKI := CR_I.KYUKATAGAKI;  -- 旧方書
          -- 小学校
--           IF CR_I.SHOCHU_KBN =1 THEN
-- 
--             W_GAKKO_NM := '';
            -- 学校名称（新）を取得
--             BEGIN
--              SELECT SYOGAKOMEI
--                INTO W_GAKKO_NM
--                FROM GKBTSHOGAKKO
--                WHERE SYOGAKO_CD = CR_I.SHOGAKU_CD;
--             EXCEPTION
--                WHEN OTHERS THEN
--                  W_GAKKO_NM := '' ;
--             END;
            -- 無い場合、行政情報より取得する
--             IF W_GAKKO_NM = ''  OR W_GAKKO_NM IS NULL THEN
--                W_GAKKO_NM := GAAPK0030.FSHOGAKUMEI(CR_I.SANTEIDANTAI_CD, CR_I.SHOGAKU_CD);
--             END IF;
--             RWK.NEW_GAKKO := W_GAKKO_NM;

            -- 学校名称（旧）を取得
--             W_GAKKO_NM := '';
--             BEGIN
--               SELECT SYOGAKOMEI
--                 INTO W_GAKKO_NM
--                 FROM GKBTSHOGAKKO
--                 WHERE SYOGAKO_CD = CR_I.OLD_SHOGAKU_CD;
--             EXCEPTION
--                 WHEN OTHERS THEN
--                   W_GAKKO_NM := '' ;
--             END;
            -- 無い場合、行政情報より取得する
--             IF W_GAKKO_NM = ''  OR W_GAKKO_NM IS NULL THEN
--                W_GAKKO_NM := GAAPK0030.FSHOGAKUMEI(CR_I.SANTEIDANTAI_CD, CR_I.OLD_SHOGAKU_CD);
--             END IF;
--             RWK.OLD_GAKKO := W_GAKKO_NM;

            -- 通知書区分によって、新旧学校コードをセットする。
--             IF CR_I.TSUCHISHO_KBN = 2 THEN
--               W_GAKKO_CD := CR_I.OLD_SHOGAKU_CD;
--             ELSE
--               W_GAKKO_CD := CR_I.SHOGAKU_CD;
--             END IF;
            -- KYOIKUIINKAI_CD　取得（小学校）
--             BEGIN
--               SELECT NVL(KYOIKUIINKAI_CD,0)
--                 INTO NKYOIKUIINKAI_CD
--                 FROM GKBTSHOGAKKO
--                 WHERE SYOGAKO_CD = W_GAKKO_CD;
--             EXCEPTION
--                 WHEN OTHERS THEN
--                   NKYOIKUIINKAI_CD := NULL ;
--             END;
--           ELSE
--             W_GAKKO_NM := '';
            -- 中学校名称（新）を取得
--             BEGIN
--              SELECT TYUGAKOMEI
--                INTO W_GAKKO_NM
--                FROM GKBTCHUGAKKO
--                WHERE TYUGAKO_CD = CR_I.CHUGAKU_CD;
--             EXCEPTION
--                WHEN OTHERS THEN
--                  W_GAKKO_NM := NULL;
--             END;
-- 
--             IF W_GAKKO_NM = '' OR W_GAKKO_NM IS NULL THEN
--               W_GAKKO_NM := GAAPK0030.FCHUGAKUMEI(CR_I.SANTEIDANTAI_CD, CR_I.CHUGAKU_CD);
--             END IF;
--             RWK.NEW_GAKKO := W_GAKKO_NM;

            -- 中学校名称（旧）を取得
--             W_GAKKO_NM := '';
--             BEGIN
--              SELECT TYUGAKOMEI
--                INTO W_GAKKO_NM
--                FROM GKBTCHUGAKKO
--                WHERE TYUGAKO_CD = CR_I.OLD_CHUGAKU_CD;
--             EXCEPTION
--                WHEN OTHERS THEN
--                  W_GAKKO_NM := NULL ;
--             END;
-- 
--             IF W_GAKKO_NM = '' OR W_GAKKO_NM IS NULL THEN
--               W_GAKKO_NM := GAAPK0030.FCHUGAKUMEI(CR_I.SANTEIDANTAI_CD, CR_I.OLD_CHUGAKU_CD);
--             END IF;
--             RWK.OLD_GAKKO := W_GAKKO_NM;
            -- 通知書区分によって、新旧学校コードをセットする。
--             IF CR_I.TSUCHISHO_KBN = 2 THEN
--                   W_GAKKO_CD := CR_I.OLD_CHUGAKU_CD;
--             ELSE
--                   W_GAKKO_CD := CR_I.CHUGAKU_CD;
--             END IF;
            -- KYOIKUIINKAI_CD　取得(中学校)
--             BEGIN
--               SELECT NVL(KYOIKUIINKAI_CD,0)
--                 INTO NKYOIKUIINKAI_CD
--                 FROM GKBTCHUGAKKO
--                WHERE TYUGAKO_CD = W_GAKKO_CD;
--             EXCEPTION
--                  WHEN OTHERS THEN
--                    NKYOIKUIINKAI_CD := NULL ;
--             END;
--           END IF;
-- 
--           RWK.IINKAI_MEI := O_VUSERMEI || '教育委員会';
--           IF CR_I.TSUCHISHO_KBN = 2 THEN
--               RWK.GAKKOCHO := RWK.OLD_GAKKO;
--           ELSE
--               RWK.GAKKOCHO := RWK.NEW_GAKKO;
--           END IF;
-- 
--           RWK.GAKKO_NINSHO := '下記のとおり';
--           IF CR_I.TSUCHISHO_KBN = 1 THEN
--               RWK.GAKKO_NINSHO := RWK.GAKKO_NINSHO || '転入学';
--           ELSIF CR_I.TSUCHISHO_KBN = 2 THEN
--               RWK.GAKKO_NINSHO := RWK.GAKKO_NINSHO || '転学';
--           ELSE
--               RWK.GAKKO_NINSHO := RWK.GAKKO_NINSHO || '変更';
--           END IF;
--           RWK.GAKKO_NINSHO := RWK.GAKKO_NINSHO || 'がありましたので通知します。';
-- 
--           RWK.KYOIKU_KOIN_MEI := O_VKOIN_GYOMU;
--           RWK.KYOIKU_NINSHO   := VKIJUNBI || '付、下記の通り異動がありましたので通知します。';
--           RWK.NINSHO_KATAGAKI := O_VSHUCHONINSHOBUN;
--           RWK.SHUCHO_MEI      := O_VSHUCHOMEI;
--           RWK.SHUCHO_KOIN_MEI := O_VKOIN_SHUCHO;
--           RWK.GAKKO_BIKO      := NULL;
--           RWK.KYOIKU_BIKO     := NULL;
--           RWK.SHORI_BI        := NKIJUNBI;
--           RWK.SHORI_JIKAN     := TO_NUMBER(TO_CHAR(SYSDATE, 'HHMIDD'));
--           RWK.TANMATSU_NO     := g_sWSNUM;
--           RWK.GYOSEIKU_CD     := O_IUSER_ID;
-- 
--           IF LENGTH(CR_I.GYOSEIKUMEI) > 0 THEN
--             RWK.GYOSEIKU_MEI := CR_I.GYOSEIKUMEI;
--           ELSE
--             RWK.GYOSEIKU_MEI := NULL;
--           END IF;
--           IF LENGTH(CR_I.OLD_GYOSEIKUMEI) > 0 THEN
--             RWK.OLD_GYOSEIKU_MEI := CR_I.OLD_GYOSEIKUMEI;
--           ELSE
--             RWK.OLD_GYOSEIKU_MEI := NULL;
--           END IF;
--           RWK.YOBI1 := NKAISHI_SEIREKI;         --処理条件１：異動開始日
--           RWK.YOBI2 := NSHURYO_SEIREKI;         --処理条件２：異動終了日
--           RWK.YOBI3 := 0;                       --人格区分 格納用
--           RWK.YOBI4 := '（公印省略）';
--           RWK.YOBI5 := NULL;
--           RWK.YOBI6 := NULL;
          -- 教育委員会情報
--           IF NKYOIKUIINKAI_CD IS NOT NULL THEN
--             o_KYOIKUPRM := A_CONS_PRM();
--               IKYOUIKUIINKAIJOUHOU       := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',NKYOIKUIINKAI_CD,o_KYOIKUPRM,o_LENGTH);
--               IF IKYOUIKUIINKAIJOUHOU = 1 THEN
--                   o_KYOIKUPRM := A_CONS_PRM();
--                   o_KYOIKUPRM.EXTEND;
--                   o_KYOIKUPRM.EXTEND;
--                   o_KYOIKUPRM(1) := ' ';
--                   o_KYOIKUPRM.EXTEND;
--                   o_KYOIKUPRM(2) := ' ';
--                   o_KYOIKUPRM.EXTEND;
--                   o_KYOIKUPRM(3) := ' ';
--                   o_KYOIKUPRM.EXTEND;
--                   o_KYOIKUPRM(4) := ' ';
--                   o_KYOIKUPRM.EXTEND;
--                   o_KYOIKUPRM(5) := ' ';
--                   o_KYOIKUPRM.EXTEND;
--                   o_KYOIKUPRM(6) := ' ';
--                   o_KYOIKUPRM.EXTEND;
--                   o_KYOIKUPRM(7) := ' ';
--                   o_KYOIKUPRM.EXTEND;
--                   o_KYOIKUPRM(8) := ' ';
--               ELSE
--                 WHILE (o_LENGTH < 8) LOOP
--                   o_KYOIKUPRM.EXTEND;
--                   o_KYOIKUPRM(o_LENGTH+1) := ' ';
--                   o_LENGTH := o_LENGTH + 1;
--                 END LOOP;
--              END IF;
-- 
--              RWK.IDOJIKO               :=CR_I.IDOJIKO;   -- 異動事項
--              RWK.SHUGAKU               :=CR_I.SHUGAKU;   -- 就学状況
--              RWK.KYOIKUKAI_MEI         :=o_KYOIKUPRM(1);  -- 教育委員会名
--              RWK.KYOIKU_YAKUSHOKU_MEI  :=o_KYOIKUPRM(2);  -- 教育委員会役職名
--              RWK.KYOIKU_SHUTHOU_MEI    :=o_KYOIKUPRM(3);  -- 教育委員会首長名
--              RWK.KYOIKU_RITSU_MEI      :=o_KYOIKUPRM(4);  -- 教育委員会立区名
-- 
--              IF  LENGTH(RWK.KYOIKU_YUBIN_NO)>3 THEN
--                  RWK.KYOIKU_YUBIN_NO := SUBSTR(o_KYOIKUPRM(5),1,3) || '-' || SUBSTR(o_KYOIKUPRM(5),4);  -- 教育委員会郵便番号
--              ELSE
--                 RWK.KYOIKU_YUBIN_NO := o_KYOIKUPRM(5);  -- 教育委員会郵便番号
--              END IF;
-- 
--              RWK.KYOIKU_YUBIN_NO := TRANSLATE(RWK.KYOIKU_YUBIN_NO, '1234567890-', '１２３４５６７８９０－');
--              RWK.KYOIKU_JUSHO          :=o_KYOIKUPRM(6);  -- 教育委員会住所
--              RWK.KYOIKU_TEL            :=o_KYOIKUPRM(7);  -- 教育委員会電話番号
--              RWK.KYOIKU_TEL_NAISEN     :=o_KYOIKUPRM(8);  -- 教育委員会内線
          -- 教育委員会情報
--           ELSE
--              RWK.IDOJIKO               :=CR_I.IDOJIKO;   -- 異動事項
--              RWK.SHUGAKU               :=CR_I.SHUGAKU;   -- 就学状況
--              RWK.KYOIKUKAI_MEI         :=NULL;           -- 教育委員会名
--              RWK.KYOIKU_YAKUSHOKU_MEI  :=NULL;           -- 教育委員会役職名
--              RWK.KYOIKU_SHUTHOU_MEI    :=NULL;           -- 教育委員会首長名
--              RWK.KYOIKU_RITSU_MEI      :=NULL;           -- 教育委員会立区名
--              RWK.KYOIKU_YUBIN_NO       :=NULL;           -- 教育委員会郵便番号
--              RWK.KYOIKU_JUSHO          :=NULL;           -- 教育委員会住所
--              RWK.KYOIKU_TEL            :=NULL;           -- 教育委員会電話番号
--              RWK.KYOIKU_TEL_NAISEN     :=NULL;           -- 教育委員会内線
--           END IF;
--           SEQ_NO         := SEQ_NO + 1;
--           RWK.SEQ_NO_1   := SEQ_NO;
--           RWK.KOJIN_NO_1 := CR_I.KOJIN_NO;

          -- 氏名についての出力は制御ﾊﾟﾗﾒｰﾀの設定で制御する
          --  児童1の制御情報を取得
--           BEGIN
--            SELECT NAIYO_CD INTO N_NAIYO_CD_JIDO_1 FROM GKBTSHIMEIJKN
--             WHERE KOJIN_NO = CR_I.KOJIN_NO AND CHOHYO_ID = 'GKB620R001';
--           EXCEPTION
--             WHEN OTHERS THEN
--               N_NAIYO_CD_JIDO_1 := 0;
--           END;
           --KOJIN_NO_1で人格区分を取得
--           BEGIN
--            IRTN := GAAPK0030.FGETATENA(CR_I.KOJIN_NO,
--                                        'GKB',
--                                        NKIJUNBI,
--                                        RA,
--                                        RASO);
--           EXCEPTION
--             WHEN OTHERS THEN
--               NULL;
--           END;
          --保護者個人番号で人格区分を取得
--           BEGIN
--            IRTN := GAAPK0030.FGETATENA(CR_I.HOGOSHA_NO,
--                                        'GKB',
--                                        NKIJUNBI,
--                                        RAHOKEN,
--                                        RASOHOKEN);
--           EXCEPTION
--             WHEN OTHERS THEN
--               NULL;
--           END;
-- 
--           RWK.YOBI3 := RA.JINKAKU_KBN;

          --SHIMEI_KANA_1の編集
          --SHIMEI_KANJI_1の編集
          --外国人場合
--           IF RA.JINKAKU_KBN = 1 THEN
--             VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                              TRIM(RA.SHIMEI_KANA),TRIM(RA.HONMYO_KANA));
--             RWK.SHIMEI_KANA_1 := VEDIT_GO_DATA;
--             VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                             TRIM(RA.SHIMEI_KANJI),TRIM(RA.HONMYO_KANJI));
--             RWK.SHIMEI_KANJI_1 := VEDIT_GO_DATA;
--           ELSE
           --外国人以外場合
--             IF o_MEISYUPRM(3) = 1 THEN
--               IF CR_I.HONMYO_KANA IS NOT NULL THEN
--                 RWK.SHIMEI_KANA_1 := CR_I.HONMYO_KANA;
--               ELSE
--                 RWK.SHIMEI_KANA_1 := CR_I.SHIMEI_KANA;
--               END IF;
--               IF CR_I.HONMYO_KANJI IS NOT NULL THEN
--                 RWK.SHIMEI_KANJI_1 := CR_I.HONMYO_KANJI;
--               ELSE
--                 RWK.SHIMEI_KANJI_1 := CR_I.SHIMEI_KANJI;
--               END IF;
--             ELSE
--               RWK.SHIMEI_KANA_1 := CR_I.SHIMEI_KANA;
--               RWK.SHIMEI_KANJI_1 := CR_I.SHIMEI_KANJI;
--             END IF;
--           END IF;
-- 
--           RWK.SEIBETSU_1 := FUNC_GET_SEIBETSU_STR(CR_I.SEIBETSU);
          -- 氏名についての出力は制御ﾊﾟﾗﾒｰﾀの設定で制御する
--           RWK.SEINENGAPI_1 := CR_I.SEINENGAPI;
--           RWK.GAKUNEN_1 := FUNC_GET_GAKUNEN_STR(CR_I.GAKUNEN);
-- 
--           RWK.HOGOSHA_KOJIN_NO_1 := CR_I.HOGOSHA_NO;
          --外国人場合
--           IF RAHOKEN.JINKAKU_KBN = 1 THEN
--             VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                              TRIM(CR_I.HOGOSHA_KANA),TRIM(CR_I.HOGOSHA_HONMYO_KANA));
--             RWK.HOGOSHA_KANA_1 := VEDIT_GO_DATA;
--             VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                              TRIM(CR_I.HOGOSHA_KANJI),TRIM(CR_I.HOGOSHA_HONMYO_KANJI));
--             RWK.HOGOSHA_KANJI_1 := VEDIT_GO_DATA;
--           ELSE
            --外国人以外場合
--             IF o_MEISYUPRM(3) = 1 THEN
--               IF CR_I.HOGOSHA_HONMYO_KANA IS NOT NULL THEN
--                 RWK.HOGOSHA_KANA_1 := CR_I.HOGOSHA_HONMYO_KANA;
--               ELSE
--                 RWK.HOGOSHA_KANA_1 := CR_I.HOGOSHA_KANA;
--               END IF;
--               IF CR_I.HOGOSHA_HONMYO_KANJI IS NOT NULL THEN
--                 RWK.HOGOSHA_KANJI_1 := CR_I.HOGOSHA_HONMYO_KANJI;
--               ELSE
--                 RWK.HOGOSHA_KANJI_1 := CR_I.HOGOSHA_KANJI;
--               END IF;
--             ELSE
--               RWK.HOGOSHA_KANA_1  := CR_I.HOGOSHA_KANA;
--               RWK.HOGOSHA_KANJI_1 := CR_I.HOGOSHA_KANJI;
--             END IF;
--           END IF;
-- 
--           RWK.HOGOSHA_TSUDUKIGARA_1 := CR_I.HOGOSHA_TSUDUKIGARA;
--           RWK.TSUDUKIGARA_1         := CR_I.TSUDUKIGARA;
          -- 氏名備考１に保護者の住所（新）をセット
          -- 児童情報をセット（旧情報）
--           RWK.SHIMEI_KANA_2  := '';
--           RWK.SHIMEI_KANJI_2 := '';
-- 
--           FOR CR_ATENA IN CATENA(CR_I.KOJIN_NO) LOOP
              -- 人格区分（児童）
--               RWK.YOBI3 := CR_ATENA.JINKAKU_KBN;
              --外国人場合
--               IF CR_ATENA.JINKAKU_KBN = 1 THEN
--                 VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                  TRIM(CR_ATENA.SHIMEI_KANA),TRIM(CR_ATENA.HONMYO_KANA));
--                 RWK.SHIMEI_KANA_2 := VEDIT_GO_DATA;
--                 VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                 TRIM(CR_ATENA.SHIMEI_KANJI),TRIM(CR_ATENA.HONMYO_KANJI));
--                 RWK.SHIMEI_KANJI_2 := VEDIT_GO_DATA;
--               ELSE
               --外国人以外場合
--                 IF o_MEISYUPRM(3) = 1 THEN
--                   IF CR_ATENA.HONMYO_KANA IS NOT NULL THEN
--                     RWK.SHIMEI_KANA_2 := CR_ATENA.HONMYO_KANA;
--                   ELSE
--                     RWK.SHIMEI_KANA_2 := CR_ATENA.SHIMEI_KANA;
--                   END IF;
--                   IF CR_ATENA.HONMYO_KANJI IS NOT NULL THEN
--                     RWK.SHIMEI_KANJI_2 := CR_ATENA.HONMYO_KANJI;
--                   ELSE
--                     RWK.SHIMEI_KANJI_2 := CR_ATENA.SHIMEI_KANJI;
--                   END IF;
--                 ELSE
--                   RWK.SHIMEI_KANA_2 := CR_ATENA.SHIMEI_KANA;
--                   RWK.SHIMEI_KANJI_2 := CR_ATENA.SHIMEI_KANJI;
--                 END IF;
--               END IF;
--           END LOOP;
-- 
--           RWK.HOGOSHA_NEW_CHOMEI   := CR_I.HOGOSHA_CHOMEI;
--           RWK.HOGOSHA_NEW_BANCHI   := CR_I.HOGOSHA_BANCHI;
--           RWK.HOGOSHA_NEW_KATAGAKI := CR_I.HOGOSHA_KATAGAKI;

          -- 保護者情報をセット（旧情報）
--           RWK.HOGOSHA_KANA_2     := '';
--           RWK.HOGOSHA_KANJI_2    := '';
--           RWK.HOGOSHA_KOJIN_NO_2 := CR_I.HOGOSHA_NO;
--           W_HOGOSYA_KOJIN_NO     := 0;
-- 
--           O_ZOKUGARA1 := 0;
--           O_ZOKUGARA2 := 0;
--           O_ZOKUGARA3 := 0;
--           O_ZOKUGARA4 := 0;
--           o_VZOKUGARAMEI := '';
--           W_HOGOSHA_KANA         := '';
--           W_HOGOSHA_KANJI        := '';
--           W_HOGOSHA_HONMYO_KANA  := '';
--           W_HOGOSHA_HONMYO_KANJI := '';
          -- 学齢簿（前履歴）の保護者個人番号と最新の保護者個人番号をチェック
          -- 同時に「保護者との関係」も同時に取得
--           FOR CR_GAKUREIBO IN CGAKUREIBO(CR_I.KOJIN_NO) LOOP
--             W_HOGOSYA_KOJIN_NO := CR_GAKUREIBO.HOGOSYA_KOJIN_NO;
--             O_ZOKUGARA1        := CR_GAKUREIBO.ZOKUGARA1;
--             O_ZOKUGARA2        := CR_GAKUREIBO.ZOKUGARA2;
--             O_ZOKUGARA3        := CR_GAKUREIBO.ZOKUGARA3;
--             O_ZOKUGARA4        := CR_GAKUREIBO.ZOKUGARA4;
--             IF NVL(O_ZOKUGARA1,0) = 0 AND NVL(O_ZOKUGARA2,0) = 0 AND NVL(O_ZOKUGARA3,0) = 0 AND NVL(O_ZOKUGARA4,0) = 0 THEN
--               o_VZOKUGARAMEI := CR_GAKUREIBO.ZOKUGARA_MEI;
--             ELSE
              -- 続柄（旧）
--               IHERR := GKBFKZKGMGET(1,O_ZOKUGARA1,O_ZOKUGARA2,O_ZOKUGARA3,O_ZOKUGARA4,o_VZOKUGARAMEI,o_IHERR);
--             END IF;
--             RWK.HOGOSHA_TSUDUKIGARA_2 := o_VZOKUGARAMEI;
--           END LOOP;

          -- 保護者変更あり
--           IF W_HOGOSYA_KOJIN_NO <> 0 AND  CR_I.HOGOSHA_NO <> W_HOGOSYA_KOJIN_NO THEN
-- 
--             RWK.HOGOSHA_KOJIN_NO_2 := W_HOGOSYA_KOJIN_NO;
-- 
--              BEGIN
--               SELECT EA.CHOMEI, EA.BANCHI, EA.KATAGAKI, EA.SHIMEI_KANA, EA.SHIMEI_KANJI, EA.HONMYO_KANA, EA.HONMYO_KANJI
--                 INTO W_HOGOSHA_CHOMEI, W_HOGOSHA_BANCHI, W_HOGOSHA_KATAGAKI,
--                      W_HOGOSHA_KANA, W_HOGOSHA_KANJI, W_HOGOSHA_HONMYO_KANA, W_HOGOSHA_HONMYO_KANJI
--                 FROM GABVATENAALL EA
--                WHERE EA.KOJIN_NO = W_HOGOSYA_KOJIN_NO
--                  AND EA.RIREKI_RENBAN =
--                    (SELECT MAX(EB.RIREKI_RENBAN)
--                       FROM GABVATENAALL EB
--                      WHERE EB.KOJIN_NO = EA.KOJIN_NO
--                        AND EB.SYS_SAKUSEIBI < NKAISHI_SEIREKI);
--               EXCEPTION
--                 WHEN OTHERS THEN
--                   W_HOGOSHA_CHOMEI       := '';
--                   W_HOGOSHA_BANCHI       := '';
--                   W_HOGOSHA_KATAGAKI     := '';
--                   W_HOGOSHA_KANA         := '';
--                   W_HOGOSHA_KANJI        := '';
--                   W_HOGOSHA_HONMYO_KANA  := '';
--                   W_HOGOSHA_HONMYO_KANJI := '';
--               END;
              -- 住所（旧）
--               RWK.HOGOSHA_OLD_CHOMEI   := W_HOGOSHA_CHOMEI;
--               RWK.HOGOSHA_OLD_BANCHI   := W_HOGOSHA_BANCHI;
--               RWK.HOGOSHA_OLD_KATAGAKI := W_HOGOSHA_KATAGAKI;
-- 
--           ELSE
            -- 保護者変更が無いので、最新より一つ前の住記情報から取得
--             FOR CR_ATENA IN CATENA( CR_I.HOGOSHA_NO ) LOOP
--               W_HOGOSHA_KANA := CR_ATENA.SHIMEI_KANA;
--               W_HOGOSHA_KANJI := CR_ATENA.SHIMEI_KANJI;
--               W_HOGOSHA_HONMYO_KANA := CR_ATENA.HONMYO_KANA;
--               W_HOGOSHA_HONMYO_KANJI := CR_ATENA.HONMYO_KANJI;
-- 
--               RWK.HOGOSHA_OLD_CHOMEI   := CR_I.HOGOSHA_KYUCHOMEI;
--               RWK.HOGOSHA_OLD_BANCHI   := CR_I.HOGOSHA_KYUBANCHI;
--               RWK.HOGOSHA_OLD_KATAGAKI := CR_I.HOGOSHA_KYUKATAGAKI;
--             END LOOP;
-- 
--             RWK.HOGOSHA_TSUDUKIGARA_2 := o_VZOKUGARAMEI;
--           END IF;
-- 
--           RWK.GAKUNEN_2 := FUNC_GET_GAKUNEN_STR(CR_I.GAKUNEN);
          --外国人場合
--           IF RAHOKEN.JINKAKU_KBN = 1 THEN
--             VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                              TRIM( W_HOGOSHA_KANA ),TRIM( W_HOGOSHA_HONMYO_KANA ));
--             RWK.HOGOSHA_KANA_2 := VEDIT_GO_DATA;
--             VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                              TRIM(W_HOGOSHA_KANJI),TRIM(W_HOGOSHA_HONMYO_KANJI));
--             RWK.HOGOSHA_KANJI_2 := VEDIT_GO_DATA;
--           ELSE
            --外国人以外場合
--             IF o_MEISYUPRM(3) = 1 THEN
--               IF W_HOGOSHA_HONMYO_KANA IS NOT NULL THEN
--                 RWK.HOGOSHA_KANA_2 := W_HOGOSHA_HONMYO_KANA;
--               ELSE
--                 RWK.HOGOSHA_KANA_2 := W_HOGOSHA_KANA;
--               END IF;
--               IF W_HOGOSHA_HONMYO_KANJI IS NOT NULL THEN
--                 RWK.HOGOSHA_KANJI_2 := W_HOGOSHA_HONMYO_KANJI;
--               ELSE
--                 RWK.HOGOSHA_KANJI_2 := W_HOGOSHA_KANJI;
--               END IF;
--             ELSE
--               RWK.HOGOSHA_KANA_2  := W_HOGOSHA_KANA;
--               RWK.HOGOSHA_KANJI_2 := W_HOGOSHA_KANJI;
--             END IF;
--           END IF;
          -- 外国人世帯の保護者判定
--           RWK.TENNYUGAKU_BI_MEI := CR_I.TENNYUGAKU_BI_MEI;
--           RWK.TENNYUGAKU_BI     := CR_I.TENNYUGAKU_BI;
--           RWK.SEINENGAPI_2      := CR_I.SEINENGAPI;
--           RWK.SEQ_NO_2          := SEQ_NO;
-- 
--           IF o_MEISYUPRM(3) = 2 THEN
--             IF CR_I.HONMYO_KANJI IS NOT NULL THEN
--               RWK.SHIMEI_BIKO3 := '児童本名：' || CR_I.HONMYO_KANJI || '(' || CR_I.HONMYO_KANA || ')';
--             ELSE
--               RWK.SHIMEI_BIKO3 := NULL;
--             END IF;
--             IF CR_I.HOGOSHA_HONMYO_KANJI IS NOT NULL THEN
--               RWK.SHIMEI_BIKO4 := '保護者本名：' || CR_I.HOGOSHA_HONMYO_KANJI || '(' || CR_I.HOGOSHA_HONMYO_KANA || ')';
--             ELSE
--               RWK.SHIMEI_BIKO4 := NULL;
--             END IF;
--           ELSE
--             RWK.SHIMEI_BIKO3 := NULL;
--             RWK.SHIMEI_BIKO4 := NULL;
--           END IF;

          -- 旧保護者氏名がない場合は、続柄も空欄とする
--           IF RWK.HOGOSHA_KANJI_2 = '' OR RWK.HOGOSHA_KANJI_2 IS NULL THEN
--             RWK.HOGOSHA_TSUDUKIGARA_2 := '';
--           END IF;

          --旧児童氏名がない場合は、旧情報全て空欄とする
--           IF RWK.SHIMEI_KANJI_2 = '' OR RWK.SHIMEI_KANJI_2 IS NULL THEN
--             RWK.OLD_CHOMEI := '';
--             RWK.OLD_BANCHI := '';
--             RWK.OLD_KATAGAKI := '';
--             RWK.HOGOSHA_KANA_2 := '';
--             RWK.HOGOSHA_KANJI_2 := '';
--             RWK.HOGOSHA_OLD_CHOMEI := '';
--             RWK.HOGOSHA_OLD_BANCHI := '';
--             RWK.HOGOSHA_OLD_KATAGAKI := '';
--             RWK.HOGOSHA_TSUDUKIGARA_2 := '';
--             RWK.OLD_GAKKO := '';
--           END IF;

          --GADTMEMOより取得
          -- GAKKO_BIKOに格納
--           RWK.GAKKO_BIKO := FUNC_GET_MEMO(CR_I.KOJIN_NO);
-- 
--           INSERT INTO GKBWIDOTSUCHI VALUES RWK;
--         END LOOP;
-- 
--         COMMIT;              -- GKBWIDOTSUCHI

--         RETURN TRUE;
--     EXCEPTION
--         WHEN OTHERS THEN
            -- SQL情報取得
--             N_SQL_CODE := SQLCODE;
--             V_SQL_MSG  := SUBSTR(SQLERRM,1,100);
--             RETURN FALSE;
--     END FUNC_CREATE_WORK2;

--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------
    --  機能概要      : 異動通知書作成
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.lwy 2024/07/01
    --------------------------------------------------------
     FUNCTION FUNC_CREATE_CSV_001 
           RETURN BOOLEAN
     IS
        bRTN                      BOOLEAN;                    --戻る値
        TYPE ref_CUR              IS REF CURSOR;              --カーソル定義
        CUR_WKRE                  ref_CUR;                    --動態カーソル
        CR_WK                     GKBWIDOTSUCHI%ROWTYPE;      --カーソルのレコード
        r_WKRECORD                GKBWL090R002%ROWTYPE;
        nROWNO                    NUMBER := 0;
        i_VSQL                    NVARCHAR2(30000);           --SQL文
        I_RTN                     PLS_INTEGER;                -- 戻り値（共通）
        nRTN                      NUMBER;                     --戻る値
        vGABTATENAKIHON           GABTATENAKIHON%ROWTYPE;
        vGABTSOFUSAKI             GABTSOFUSAKI%ROWTYPE;
        o_vYUBIN_NO               NVARCHAR2(1000);
        o_nCHOHYONUM              NUMBER;
        BUNNUMEDIT                NVARCHAR2(1000);
        g_nCNT                    NUMBER;                    --出力件数
      BEGIN
        i_VSQL := 'SELECT * FROM GKBWIDOTSUCHI';
        OPEN CUR_WKRE FOR i_VSQL;
        LOOP
          FETCH CUR_WKRE INTO CR_WK;
          EXIT WHEN CUR_WKRE%NOTFOUND;
          --保護者宛名情報
          I_RTN  := GAAPK0030.FGETATENA2(CR_WK.HOGOSHA_KOJIN_NO_1, 'GKB', NKIJUNBI, vGABTATENAKIHON, vGABTSOFUSAKI);
          nROWNO := nROWNO + 1;
          r_WKRECORD := NULL;
          r_WKRECORD.NO                      := nROWNO;                       --ソート順
          r_WKRECORD.KOIN_SHUCHO             := CR_WK.KYOIKU_KOIN_MEI;        --公印１
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
         /* r_WKRECORD.SHIKUCHOSON_KATAGAKI    := CR_WK.SHUCHO_MEI;             --市町村長認証肩書
          r_WKRECORD.SHIKUCHOSON_CHOMEI      := CR_WK.NINSHO_KATAGAKI;        --市町村長名 */
          r_WKRECORD.SHIKUCHOSON_KATAGAKI    := CR_WK.NINSHO_KATAGAKI;   --市町村長認証肩書
          r_WKRECORD.SHIKUCHOSON_CHOMEI      := CR_WK.SHUCHO_MEI;        --市町村長名
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00286横展開対応
--          r_WKRECORD.SAKUSEIBI       := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(CR_WK.SHORI_BI, 'YYYYMMDD'), 'YYYY/MM/DD'), 12);  --作成日
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
          --r_WKRECORD.SAKUSEIBI       := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(CR_WK.SHORI_BI), 12);  --作成日
          r_WKRECORD.SAKUSEIBI       := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(KKAPK0020.FDAYEDIT20(CR_WK.SHORI_BI,0,3), 0),' ',''),'　','');  --作成日
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
          IF g_vKYUGAKKOYAATE = 1 AND CR_WK.TSUCHISHO_KBN = 3 THEN
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
            --r_WKRECORD.HYOJI_GAKKOCHO       := CR_WK.OLD_GAKKO || '長' || '　' || '様'; --表示用学校長名
            r_WKRECORD.HYOJI_GAKKOCHO       := CR_WK.OLD_GAKKO || '　' || '様'; --表示用学校長名
          ELSE
            --r_WKRECORD.HYOJI_GAKKOCHO       := CR_WK.GAKKOCHO || '長' || '　' || '様'; --表示用学校長名
            r_WKRECORD.HYOJI_GAKKOCHO       := CR_WK.GAKKOCHO  || '　' || '様'; --表示用学校長名
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
          END IF;
          r_WKRECORD.KYOIKU_KAI_MEI          := CR_WK.NINSHO_KATAGAKI;      --教育委員会名
          r_WKRECORD.TEKIYO                  := CR_WK.IDO_JIYU_MEI;           --摘要
          IF g_vJYOUKEN11 = '1' THEN
            r_WKRECORD.NEW_JUSHO1 := GAAPK0030.FDVJUSHO('GKB', CR_WK.KOJIN_NO_1, g_sTANTOCODE, g_sWSNUM, CR_WK.HOGOSHA_NEW_CHOMEI || CR_WK.HOGOSHA_NEW_BANCHI, o_nHANTEIKEKKA, 2); --新住所１
            r_WKRECORD.OLD_JUSHO1 := GAAPK0030.FDVJUSHO('GKB', CR_WK.KOJIN_NO_1, g_sTANTOCODE, g_sWSNUM, CR_WK.HOGOSHA_NEW_CHOMEI || CR_WK.HOGOSHA_NEW_BANCHI, o_nHANTEIKEKKA, 2); --新住所１

          ELSE
--  2024/11/21 JPJYS.JH UPDATE 0.3.000.008:IT_GKB_00549仕様変更対応 Start
--            r_WKRECORD.NEW_JUSHO1 := CR_WK.NEW_CHOMEI;             --新住所１
--            r_WKRECORD.OLD_JUSHO1 := CR_WK.OLD_CHOMEI;             --旧住所１
            r_WKRECORD.NEW_JUSHO1 := CR_WK.NEW_JUSHO;             --新住所１
            r_WKRECORD.OLD_JUSHO1 := CR_WK.OLD_JUSHO;             --旧住所１
--  2024/11/21 JPJYS.JH UPDATE 0.3.000.008:IT_GKB_00549仕様変更対応 End
          END IF;
          r_WKRECORD.NEW_JUSHO2              := NULL;             --新住所２
          r_WKRECORD.OLD_JUSHO2              := NULL;             --旧住所２
          r_WKRECORD.NEW_GAKKO               := CR_WK.NEW_GAKKO;              --新学校名
          r_WKRECORD.OLD_GAKKO_MEI           := CR_WK.OLD_GAKKO;              --旧学校名
          r_WKRECORD.SHIMEI_KANJI_1          := CR_WK.SHIMEI_KANJI_1;         --氏名漢字１
          r_WKRECORD.SHIMEI_KANA_1           := CR_WK.SHIMEI_KANA_1;          --氏名カナ１
          r_WKRECORD.SEIBETSU_1              := CR_WK.SEIBETSU_1;             --性別１
          r_WKRECORD.SEINENGAPI_1            := CR_WK.SEINENGAPI_1;           --生年月日１
          r_WKRECORD.GAKUNEN_1               := CR_WK.GAKUNEN_1;              --学年１
          r_WKRECORD.HOGOSHA_SHIMEI_KANJI_1  := CR_WK.HOGOSHA_KANJI_1;        --保護者名漢字１
          r_WKRECORD.SHIMEI_KANJI_2          := CR_WK.SHIMEI_KANJI_2;         --氏名漢字２
          r_WKRECORD.SHIMEI_KANA_2           := CR_WK.SHIMEI_KANA_2;          --氏名かな２
          r_WKRECORD.SEIBETSU_2              := CR_WK.SEIBETSU_2;             --性別２
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00286横展開対応
--          r_WKRECORD.SEINENGAPI_2            := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(CR_WK.SEINENGAPI_2, 'YYYYMMDD'), 'YYYY/MM/DD'), 12);   --生年月日２
          GKAPK00020.FGETSEINENGHYOUJI(CR_WK.SEINENGAPI_2,o_sEINENGAPI2);
          r_WKRECORD.SEINENGAPI_2            := o_sEINENGAPI2.o_vEDIT_GYYMMDD3;   --生年月日２
          r_WKRECORD.GAKUNEN_2               := CR_WK.GAKUNEN_2;              --学年２
          r_WKRECORD.HOGOSHA_SHIMEI_KANJI_2  := CR_WK.HOGOSHA_KANJI_2;        --保護者名漢字２
          r_WKRECORD.SHIMEI_KANJI_3          := CR_WK.SHIMEI_KANJI_3;         --氏名漢字３
          r_WKRECORD.SHIMEI_KANA_3           := CR_WK.SHIMEI_KANA_3;          --氏名かな３
          r_WKRECORD.SEIBETSU_3              := CR_WK.SEIBETSU_3;             --性別３
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00286横展開対応
--          r_WKRECORD.SEINENGAPI_3            := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(CR_WK.SEINENGAPI_3, 'YYYYMMDD'), 'YYYY/MM/DD'), 12);  --生年月日３
          GKAPK00020.FGETSEINENGHYOUJI(CR_WK.SEINENGAPI_3,o_sEINENGAPI3);
          r_WKRECORD.SEINENGAPI_3            := o_sEINENGAPI3.o_vEDIT_GYYMMDD3;  --生年月日３
          r_WKRECORD.GAKUNEN_3               := CR_WK.GAKUNEN_3;              --学年３
          r_WKRECORD.HOGOSHA_SHIMEI_KANJI_3  := CR_WK.HOGOSHA_KANJI_3;        --保護者名漢字３
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00286横展開対応
--          r_WKRECORD.IDO_TODOKE_BI           := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(CR_WK.TODOKEDE_BI, 'YYYYMMDD'), 'YYYY/MM/DD'), 12);   --異動届出日
--          r_WKRECORD.IDO_BI                  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(CR_WK.IDO_BI, 'YYYYMMDD'), 'YYYY/MM/DD'), 12);        --異動日
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応                              
          --r_WKRECORD.IDO_TODOKE_BI           := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(CR_WK.TODOKEDE_BI), 12);   --異動届出日
          --r_WKRECORD.IDO_BI                  := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(CR_WK.IDO_BI), 12);        --異動日
          r_WKRECORD.IDO_TODOKE_BI           := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(KKAPK0020.FDAYEDIT20(CR_WK.TODOKEDE_BI,0,3), 0),' ',''),'　','');   --異動届出日
          r_WKRECORD.IDO_BI                  := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(KKAPK0020.FDAYEDIT20(CR_WK.IDO_BI,0,3), 0),' ',''),'　','');        --異動日

--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
          r_WKRECORD.KYOIKU_BIKO             := CR_WK.KYOIKU_BIKO;             --教育委員会備考
          r_WKRECORD.IDO_JIYU_MEI            := CR_WK.GAKKO_NINSHO;            --異動事由名
          r_WKRECORD.SHUCHO_NINSHOBUN        := CR_WK.KYOIKU_NINSHO;           --首長認証
          r_WKRECORD.TITLE                   := CR_WK.TITLE;                   --表題
          r_WKRECORD.NEW_GYOSEIKU_MEI        := CR_WK.GYOSEIKU_MEI;            --新行政区名
          r_WKRECORD.OLD_GYOSEIKU_MEI        := CR_WK.OLD_GYOSEIKU_MEI;        --旧行政区名
          r_WKRECORD.PAGE_NUM                := CR_WK.PAGE;                    --ページ番号
          r_WKRECORD.HOGOSHA_SHIMEI_KANA_1   := CR_WK.HOGOSHA_KANA_1;          --保護者名かな１
          r_WKRECORD.HOGOSHA_SHIMEI_KANA_2   := CR_WK.HOGOSHA_KANA_2;          --保護者名かな２
          r_WKRECORD.HOGOSHA_SHIMEI_KANA_3   := CR_WK.HOGOSHA_KANA_3;          --保護者名かな３
          r_WKRECORD.HOGOSHA_KANKEI_1        := CR_WK.HOGOSHA_TSUDUKIGARA_1;   --保護者との関係１
          r_WKRECORD.HOGOSHA_KANKEI_2        := CR_WK.HOGOSHA_TSUDUKIGARA_2;   --保護者との関係２
          r_WKRECORD.HOGOSHA_KANKEI_3        := CR_WK.HOGOSHA_TSUDUKIGARA_3;   --保護者との関係３
          r_WKRECORD.JIDO_KANKEI_1           := CR_WK.TSUDUKIGARA_1;           --生徒との関係１
          r_WKRECORD.JIDO_KANKEI_2           := CR_WK.TSUDUKIGARA_2;           --生徒との関係２
          r_WKRECORD.JIDO_KANKEI_3           := CR_WK.TSUDUKIGARA_3;           --生徒との関係３
          r_WKRECORD.IDO_JIKO                := NULL;                          --異動事項
          r_WKRECORD.SHUGAKU                 := NULL;                          --就学状況        
          r_WKRECORD.IDO_JIKO                := NULL;                          --異動事項
          r_WKRECORD.SHUGAKU                 := NULL;                          --就学状況
          r_WKRECORD.KYOIKU_YAKUSHOKU_MEI    := CR_WK.KYOIKU_YAKUSHOKU_MEI;    --教育委員会役職名
          r_WKRECORD.KYOIKU_SHUCHO_MEI       := CR_WK.SHUCHO_MEI;              --教育委員会首長名
          r_WKRECORD.SHIMEI_BIKO1            := CR_WK.SHIMEI_BIKO1;            --氏名備考１
          r_WKRECORD.SHIMEI_BIKO2            := CR_WK.SHIMEI_BIKO2;            --氏名備考２
          r_WKRECORD.SHIMEI_BIKO3            := CR_WK.SHIMEI_BIKO3;            --氏名備考３
          r_WKRECORD.SHIMEI_BIKO4            := CR_WK.SHIMEI_BIKO4;            --氏名備考４
          r_WKRECORD.SHIMEI_BIKO5            := CR_WK.SHIMEI_BIKO5;            --氏名備考５
          r_WKRECORD.SHIMEI_BIKO6            := CR_WK.SHIMEI_BIKO6;            --氏名備考６
          r_WKRECORD.NEW_JUSHO3              := NULL;                          --新住所３
          r_WKRECORD.OLD_JUSHO3              := NULL;                          --旧住所３
          r_WKRECORD.TENNYUGAKU_BI_MEI       := CR_WK.TENNYUGAKU_BI_MEI;       --転入学年月日名
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00286横展開対応
--          r_WKRECORD.TENNYUGAKU_BI           := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(CR_WK.TENNYUGAKU_BI, 'YYYYMMDD'), 'YYYY/MM/DD'), 12); --転入学年月
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
          --r_WKRECORD.TENNYUGAKU_BI           := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(CR_WK.TENNYUGAKU_BI), 12); --転入学年月
          r_WKRECORD.TENNYUGAKU_BI           := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(KKAPK0020.FDAYEDIT20(CR_WK.TENNYUGAKU_BI,0,3), 0),' ',''),'　',''); --転入学年月
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
          --r_WKRECORD.BUNSHO_NO               := g_vBUNSHO_NO;                  --文書番号
          r_WKRECORD.BUNSHO_NO               := KKAPK0010.FMULTIBYTEHENKAN(g_vBUNSHO_NO,0);                  --文書番号
          --r_WKRECORD.HAKKO_NENGAPI           := CR_WK.HAKKO_NENGAPI;   --発行年月日
          r_WKRECORD.HAKKO_NENGAPI           := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(CR_WK.HAKKO_NENGAPI, 0),' ',''),'　','');   --発行年月日
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
          IF CR_WK.KYOIKU_KOIN_MEI IS NULL THEN
            r_WKRECORD.KOIN_SHORYAKU         := CR_WK.KOIN_SHORYAKU;   --公印（省略）
          ELSE
            r_WKRECORD.KOIN_CHUSHAKU         := CR_WK.KOIN_CHUSHAKU;   --公印（注釈）
          END IF;
          
          IF g_vHOGOSYAATE = '1' THEN
            --保護者
            I_RTN                            := KKAPK0010.FYUBINHENSHU(vGABTATENAKIHON.KOJIN_NO, o_vYUBIN_NO);
            r_WKRECORD.SOFU_YUBIN            := KKAPK0010.FMULTIBYTEHENKAN(o_vYUBIN_NO, 0);              --送付先郵便番号
            IF g_vJYOUKEN11 = '1' THEN
--  2024/08/06 ZCZL.LIUWEIYUAN Update 0.3.000.001:検収指摘No.128
--              r_WKRECORD.NEW_JUSHO1          := GAAPK0030.FDVJUSHO('GKB', CR_WK.HOGOSHA_KOJIN_NO_1, g_sTANTOCODE, g_sWSNUM, CR_WK.HOGOSHA_NEW_CHOMEI || CR_WK.HOGOSHA_NEW_BANCHI, o_nHANTEIKEKKA, 2);   --送付先住所
              r_WKRECORD.SOFU_JUSHO          := GAAPK0030.FDVJUSHO('GKB', CR_WK.HOGOSHA_KOJIN_NO_1, g_sTANTOCODE, g_sWSNUM, CR_WK.HOGOSHA_NEW_CHOMEI || CR_WK.HOGOSHA_NEW_BANCHI, o_nHANTEIKEKKA, 2);   --送付先住所            ELSE
              r_WKRECORD.SOFU_JUSHO          := GAAPK0010.FADDRESSEDIT(1, NULL, vGABTATENAKIHON.Chomei, vGABTATENAKIHON.Banchi, NULL, NULL);   --送付先住所
             ELSE 
--  2024/12/23 JPJYS.LIZIZHONG UPDATE 0.3.000.009:IT_GKB_10110対応 STR                  
          --  END IF;
          -- r_WKRECORD.SOFU_KATAGAKI         := vGABTATENAKIHON.Katagaki;     --送付先方書
          --  r_WKRECORD.YUBIN_NOBC            := vGABTATENAKIHON.YUBIN_NOBC;   --カスタマーバーコード
              IF vGABTSOFUSAKI.CHOMEI IS NOT NULL AND vGABTSOFUSAKI.BANCHI IS NOT NULL AND vGABTSOFUSAKI.YUBIN_NOBC IS NOT NULL AND vGABTSOFUSAKI.KATAGAKI IS NOT NULL THEN
            r_WKRECORD.SOFU_KATAGAKI         := vGABTSOFUSAKI.KATAGAKI;                        --送付先方書
            r_WKRECORD.SOFU_JUSHO            := vGABTSOFUSAKI.CHOMEI || vGABTSOFUSAKI.BANCHI;  --送付先住所   
            r_WKRECORD.YUBIN_NOBC            := vGABTSOFUSAKI.YUBIN_NOBC;                      --カスタマーバーコード 
              ELSE    
            r_WKRECORD.SOFU_KATAGAKI         := vGABTATENAKIHON.KATAGAKI;
            r_WKRECORD.SOFU_JUSHO            := vGABTATENAKIHON.CHOMEI || vGABTATENAKIHON.BANCHI;
            r_WKRECORD.YUBIN_NOBC            := vGABTATENAKIHON.YUBIN_NOBC;  
              END IF; 
            END IF;         
            ELSE
--  2024/12/23 JPJYS.LIZIZHONG UPDATE 0.3.000.009:IT_GKB_10110対応 END          
            --保護者以外
            r_WKRECORD.SOFU_YUBIN            := NULL;   --送付先郵便番号
            r_WKRECORD.SOFU_JUSHO            := NULL;   --送付先住所
            r_WKRECORD.SOFU_KATAGAKI         := NULL;   --送付先方書
            r_WKRECORD.YUBIN_NOBC            := NULL;   --カスタマーバーコード
          END IF;
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
          IF g_vJYOUKEN9 = '0' THEN           --宛先は保護者
          r_WKRECORD.SOFU_ATENA               := CR_WK.HOGOSHA_KANJI_1|| '　' || '様';        --送付先宛名
          ELSE                                --宛先は新/旧学校長
          r_WKRECORD.SOFU_ATENA               := r_WKRECORD.HYOJI_GAKKOCHO;        --送付先宛名
          END IF ;
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応       
          r_WKRECORD.TSUCHI_BUN              := CR_WK.TSUCHIBUN;                  --通知文
          r_WKRECORD.OLD_SHIMEI_KANA         := CR_WK.OLD_SHIMEI_KANA;            --旧氏名カナ
          r_WKRECORD.OLD_SHIMEI_KANJI        := CR_WK.OLD_SHIMEI_KANJI ;          --旧氏名漢字
          r_WKRECORD.OLD_HOGOSHA_SHIMEI_KANA  := CR_WK.OLD_HOGOSHA_SHIMEI_KANA;   --旧保護者氏名カナ
          r_WKRECORD.OLD_HOGOSHA_SHIMEI_KANJI := CR_WK.OLD_HOGOSHA_SHIMEI_KANJI;   --旧保護者氏名漢字
          r_WKRECORD.OLD_GAKUNEN             := CR_WK.OLD_GAKUNEN;                 --旧学年
          r_WKRECORD.TOIAWASESAKI1           := CR_WK.TOIAWASESAKI1;               --お問い合わせ先
          r_WKRECORD.TOIAWASESAKI2           := CR_WK.TOIAWASESAKI2;               --お問い合わせ先住所
          r_WKRECORD.TOIAWASESAKI3           := CR_WK.TOIAWASESAKI3;               --お問い合わせ先電話番号
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
          --r_WKRECORD.YOSHIKI_NO              := CR_WK.YOSHIKI_NO;                  --様式番号
          r_WKRECORD.YOSHIKI_NO              := KKAPK0010.FMULTIBYTEHENKAN(CR_WK.YOSHIKI_NO, 0);                   --様式番号
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.011:品質強化 IT_GKB_10233、IT_GKB_10234、IT_GKB_10235、IT_GKB_10236、IT_GKB_10237対応
          r_WKRECORD.KOJIN_NO                := CR_WK.KOJIN_NO_1;                  --児童生徒宛名番号                                    
          r_WKRECORD.HOGOSYA_KOJIN_NO        := CR_WK.HOGOSHA_KOJIN_NO_1;          --保護者宛名番号
          r_WKRECORD.BREAK_NO                := NULL;                              --改ページキー
          r_WKRECORD.WSNUM                   := g_sWSNUM;                          --端末番号
          r_WKRECORD.BATCHKBN                := 2;                                 --即時バッチ区分
          r_WKRECORD.JOBNUM                  := g_nJOBNUM;                         --ジョブNO

          --異動通知書（保護者）ワーク
          IF g_vHOGOSYAATE = '1' THEN
            --発行履歴作成
            BUNNUMEDIT := KKAPK0010.FSTRCNV(REPLACE(REPLACE(g_rBUNNUMEDITKEKA.NUM,g_rBUNNUMSRCINF.MAEMOJI,''),g_rBUNNUMSRCINF.USHIROMOJI,''),1);
            nRTN := GKAFKHAKKOR('GKB',
                                CR_WK.KOJIN_NO_1,
                                g_rJSTP.CHOHYONUM,
                                SUBSTR(TO_CHAR(SYSDATE, 'YYYYMMDD'), 1, 4),
                                1,
                                '教育異動通知書',
                                TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),
                                TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS')),
                                1,
                                g_sTANTOCODE,
                                g_vJYOUKEN10,
                                NULL,
                                g_rBUNNUMSRCINF.MAEMOJI,
--  2024/12/17 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKC_00329横展開対応 START
--                                TO_NUMBER(BUNNUMEDIT),
                                BUNNUMEDIT,
--  2024/12/17 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKC_00329横展開対応 END
                                g_rBUNNUMSRCINF.USHIROMOJI,
                                CR_WK.HOGOSHA_KOJIN_NO_1,
                                NULL,
                                g_sWSNUM);
            INSERT INTO GKBWL090R002 VALUES r_WKRECORD;
          END IF;
            --異動通知書（新学校）ワーク
          IF g_vSHINGAKKOATE = '1' THEN
            IF CR_WK.TSUCHISHO_KBN <> 2 THEN
            INSERT INTO GKBWL090R003 VALUES r_WKRECORD;
            END IF;
          END IF;
          --異動通知書（旧学校）ワーク
          IF g_vKYUGAKKOYAATE = '1' THEN
            IF CR_WK.TSUCHISHO_KBN = 2 OR CR_WK.TSUCHISHO_KBN = 3 THEN
            INSERT INTO GKBWL090R004 VALUES r_WKRECORD;
            END IF;
          END IF;
--  2025/05/21 CTC.HJF DELETE START 1.0.006.000:GKB_QA14364_GKB未登録外字で登録した対象者が文字切れリストに表示されない対応
          --発送者文字切れリストの作成
          --bRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE, 'GKB090R001', 1, g_nCNT);
--  2025/05/21 CTC.HJF DELETE END
        END LOOP;
--  2025/05/21 CTC.HJF UPDATE START 1.0.006.000:GKB_QA14364_GKB未登録外字で登録した対象者が文字切れリストに表示されない対応
          --発送者文字切れリストの作成
          bRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE, 'GKB090R001', 1, g_nCNT);
--  2025/05/21 CTC.HJF UPDATE END
        IF CUR_WKRE%ISOPEN THEN
          CLOSE CUR_WKRE;
        END IF;
        RETURN TRUE;
    EXCEPTION
      WHEN OTHERS THEN
        IF CUR_WKRE%ISOPEN THEN
          CLOSE CUR_WKRE;
        END IF;
        RETURN FALSE;
    END FUNC_CREATE_CSV_001;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
--  2024/07/01 ZCZL.lwy Add 0.3.000.000:新WizLIFE２次開発
        nRTN             NUMBER;  --戻り値      
        eEXCEPTION       EXCEPTION;
        vDUMMY           NVARCHAR2(100);
--  2024/07/01 ZCZL.lwy Delete 0.3.000.000:新WizLIFE２次開発
--        o_vKOINFILENAME  NVARCHAR2(500);
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        --複数な帳票の場合、該当ロジックあり
        --変数の初期について、該当処理内作成しますか？判断要
        --帳票IDに関連な変数にIF内で書く
        IF g_nSTEP_INDEX = 1 THEN

          --初期化
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
          -- 異動通知書
--          DELETE FROM GKBWL290R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
          --変更通知書
--          DELETE FROM GKBWL290R002 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
          --変更通知一覧
--          DELETE FROM GKBWL290R003 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
          --異動通知書（保護者）
          DELETE FROM GKBWL090R002 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
          --異動通知書（新学校）
          DELETE FROM GKBWL090R003 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
          --異動通知書（旧学校）
          DELETE FROM GKBWL090R004 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
--  2024/07/01 ZCZL.lwy Update End
          --------------------
          -- 中間テーブルの削除
          --------------------
          IF KKAPK3000.FTRUNCATE('GKBWIDOTSUCHI', V_SQL_MSG) <> 0 THEN
              BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('教育異動通知の作成処理が異常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          END IF;
          IF KKAPK3000.FTRUNCATE('GKBWINTERNAL', V_SQL_MSG) <> 0 THEN
              BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('教育異動通知の作成処理が異常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          END IF;
          --------------------
          -- 処理条件の取得
          --------------------
          VKAISHI_WAREKI  := g_vJYOUKEN1;    -- 抽出開始日
          VSHURYO_WAREKI  := g_vJYOUKEN2;    -- 抽出終了日
--  2024/07/01 ZCZL.lwy Delete 0.3.000.000:新WizLIFE２次開発
--          NCHOHYO_KBN     := TO_NUMBER(NVL(g_vJYOUKEN3, 0)); -- 帳票区分
--  2024/10/17 ZCZL.WANGMING DELETE 0.3.000.004:仕様変更　ID：IT_GKB_00112対応
--          NTAISHO_JIDO    := TO_NUMBER(NVL(g_vJYOUKEN4, 0)); -- 対象児童個人番号
          --------------------
          -- 日付編集（和暦→西暦）
          --------------------
          -- 抽出開始日
          IO_ISEIREKIHIZUKE   := NULL;
          IF KKAPK0020.FDAYEDIT(VKAISHI_WAREKI,
                                 IO_ISEIREKIHIZUKE,
                                 O_VEDIT_GYYMMDD1,
                                 O_VEDIT_GYYMMDD2,
                                 O_VEDIT_GYYMMDD3,
                                 O_VKJ_GENGO,
                                 O_VKG_GENGO,
                                 O_IWAREKI_YY,
                                 O_ISEIREKI_YYYY,
                                 O_IWAREKI_GYYMM,
                                 O_IMM,
                                 O_IDD,
                                 O_IWAREKIHIZUKE,
                                 O_ISEIREKIHIZUKE) THEN
              NKAISHI_SEIREKI := O_ISEIREKIHIZUKE;
          ELSE
              NKAISHI_SEIREKI := 0;
          END IF;
          -- 抽出終了日
          IO_ISEIREKIHIZUKE   := NULL;
          IF KKAPK0020.FDAYEDIT(VSHURYO_WAREKI,
                                 IO_ISEIREKIHIZUKE,
                                 O_VEDIT_GYYMMDD1,
                                 O_VEDIT_GYYMMDD2,
                                 O_VEDIT_GYYMMDD3,
                                 O_VKJ_GENGO,
                                 O_VKG_GENGO,
                                 O_IWAREKI_YY,
                                 O_ISEIREKI_YYYY,
                                 O_IWAREKI_GYYMM,
                                 O_IMM,
                                 O_IDD,
                                 O_IWAREKIHIZUKE,
                                 O_ISEIREKIHIZUKE) THEN
              NSHURYO_SEIREKI  := O_ISEIREKIHIZUKE;
          ELSE
              NSHURYO_SEIREKI := 0;
          END IF;
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
          --学齢簿変更届出開始日
          g_vJYOUKEN5 := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN5);
          --学齢簿変更届出終了日
          IF KKAPK0020.FNENDOHENKAN(g_vJYOUKEN6) = 0 THEN
            g_vJYOUKEN6 := 99999999;
          ELSE
            g_vJYOUKEN6 := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN6);
          END IF;
          --学齢簿変更開始日
          g_vJYOUKEN7 := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN7);
          --学齢簿変更終了日  
          IF KKAPK0020.FNENDOHENKAN(g_vJYOUKEN8) = 0 THEN
            g_vJYOUKEN8 := 99999999;
          ELSE
            g_vJYOUKEN8 := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN8);
          END IF;
          -- 宛先(保護者宛)
          IF INSTR(g_vJYOUKEN9, '0') > 0  THEN
            g_vHOGOSYAATE := 1;
          ELSE
            g_vHOGOSYAATE := 0;
          END IF;
          -- 宛先(新学校長宛)
          IF INSTR(g_vJYOUKEN9, '1') > 0  THEN
            g_vSHINGAKKOATE := 1;
          ELSE
            g_vSHINGAKKOATE := 0;
          END IF;
          -- 宛先(旧学校長宛)
          IF INSTR(g_vJYOUKEN9, '2') > 0  THEN
            g_vKYUGAKKOYAATE := 1;
          ELSE
            g_vKYUGAKKOYAATE := 0;
          END IF;
          -- 発行日
          IF KKAPK0020.FNENDOHENKAN(g_vJYOUKEN10) = 0 THEN
            g_vJYOUKEN10 := SYSDATE;
          ELSE
            g_vJYOUKEN10 := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN10);
          END IF;
--  2024/07/01 ZCZL.lwy Add End          
          --------------------
          -- 共通情報（稼働ﾕｰｻﾞｰ情報）の取得
          --------------------
          -- 基準日
          NKIJUNBI := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
          IO_ISEIREKIHIZUKE := NKIJUNBI;
          IO_IWAREKIHIZUKE := 0;
          IF KKAPK0020.FDAYEDIT(IO_IWAREKIHIZUKE,
                                 IO_ISEIREKIHIZUKE,
                                 O_VEDIT_GYYMMDD1,
                                 O_VEDIT_GYYMMDD2,
                                 O_VEDIT_GYYMMDD3,
                                 O_VKJ_GENGO,
                                 O_VKG_GENGO,
                                 O_IWAREKI_YY,
                                 O_ISEIREKI_YYYY,
                                 O_IWAREKI_GYYMM,
                                 O_IMM,
                                 O_IDD,
                                 O_IWAREKIHIZUKE,
                                 O_ISEIREKIHIZUKE) THEN
              VKIJUNBI := O_VEDIT_GYYMMDD3;
          ELSE
              BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('教育異動通知の作成処理が異常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
              RAISE eEXCEPTION;
          END IF;
         IF KKAPK0030.FKYOTU( NKIJUNBI,
                                   o_IUSER_ID,
                                   o_IJICHI_CD,
                                   o_IGAPPEI_BI,
                                   o_IUSER_KBN,
                                   o_VGUNSHIMEI,
                                   O_VUSERMEI,
                                   O_VSHUCHOMEI,
                                   O_VKENMEI,
                                   O_VSHUCHONINSHOBUN,
                                   O_VYUBIN_NO,
                                   O_VSHOZAICHI,
                                   O_VTEL_NO) <> 0 THEN
              BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('教育異動通知の作成処理が異常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
              RAISE eEXCEPTION;
          END IF;
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
        --文書番号情報を取得
        bRTN := KKBPK5551.FJBNSGet (g_nJOBNUM, g_rJSTP.STEPSEQ, g_rBUNNUMSRCINF);
        --文書番号編集結果を取得
        g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
        -- 文書番号印字ありの場合
        IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
          g_vBUNSHO_NO := g_rBUNNUMEDITKEKA.NUM;                 --文書番号
        ELSE
          g_vBUNSHO_NO := NULL;                                  --文書番号
        END IF;
--  2024/07/01 ZCZL.lwy Add End
          --公印取得
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
--           BRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE, 0),
--                                       g_sWSNUM,
--                                       SYSDATE,
--                                       VDUMMY,
--                                       VDUMMY,
--                                       VDUMMY,
--                                       VDUMMY,
--                                       o_vKOINFILENAME
--           );
          BRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE, 0),
                                      g_sWSNUM,
                                      SYSDATE,
                                      o_nDAIRIKBN,
                                      o_vKATAGAKI1,
                                      o_vKATAGAKI2,
                                      o_vSHIMEI,
                                      o_vKOINFILENAME
          );
--  2024/07/01 ZCZL.lwy Update End
          --首長公印ファイル名
          O_VKOIN_SHUCHO := o_vKOINFILENAME;
          --業務毎公印ファイル名
          O_VKOIN_GYOMU := o_vKOINFILENAME;
--  2024/07/01 ZCZL.lwy Add Start 0.3.000.000:新WizLIFE２次開発
          --本名使用制御の共通関数の取得に必要なパラメータを取得する。
          o_tITEM := A_CONS_PRM();
          nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, o_tITEM);
          FOR i IN 1..o_tITEM.COUNT LOOP
            IF o_tITEM(i) IS NOT NULL AND o_tITEM(i) = g_rJSTP.CHOHYOID THEN
              --変数.帳票連番
              vCHOHYORENBAN := i;
            ELSE
              NULL;
            END IF;
          END LOOP;
          --システム制御設定
--  2024/10/17 ZCZL.WANGMING UPDATE 0.3.000.004:製造故障QA　ID：41対応
--          nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 0, o_tITEM);
          nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, o_tITEM);
          vSYSSEIGYONO := o_tITEM(vCHOHYORENBAN);
--  2024/07/01 ZCZL.lwy Add End

          INENDO := KKAPK0020.FDAYNENDO( NKIJUNBI, 0 ); --年度
          PROC_GET_HAKKO_KBN;
          -- 本名・通称名出力制御を取得する
          o_MEISYUPRM := A_CONS_PRM();
          IMEISYUTURYOKUSEIGYO := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,o_MEISYUPRM,o_LENGTH);
          IF IMEISYUTURYOKUSEIGYO = 1 THEN
            o_MEISYUPRM := A_CONS_PRM();
            o_MEISYUPRM.EXTEND;
            o_MEISYUPRM.EXTEND;
            o_MEISYUPRM(1) := 0;
            o_MEISYUPRM.EXTEND;
            o_MEISYUPRM(2) := 0;
            o_MEISYUPRM.EXTEND;
            o_MEISYUPRM(3) := 0;
          ELSE
            WHILE (o_LENGTH < 4) LOOP
              o_MEISYUPRM.EXTEND;
              o_MEISYUPRM(o_LENGTH+1) := 0;
              o_LENGTH := o_LENGTH + 1;
            END LOOP;
          END IF;
          -- 教育委員会情報を取得する
          --------------------
          -- 抽出（内部ワークテーブル作成）
          --------------------
          IKENSU_IN        := 0;   -- 異動累計テーブル抽出件数
--  2024/07/01 ZCZL.lwy Delete Start 0.3.000.000:新WizLIFE２次開発
--           IKENSU_TENNYU    := 0;   -- 中間テーブル書出件数(転入票）
--           IKENSU_TENSHUTSU := 0;   -- 中間テーブル書出件数(転出票）
--           IKENSU_KUNAI     := 0;   -- 中間テーブル書出件数(学校区内異動票）
--  2024/07/01 ZCZL.lwy Delete End
--  2024/07/01 ZCZL.lwy Delete 0.3.000.000:新WizLIFE２次開発
--          IF NCHOHYO_KBN <> 1 THEN
            IF NOT FUNC_CREATE_INTERNAL THEN
                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('教育異動通知の作成処理が異常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
                RAISE eEXCEPTION;
            END IF;
--  2024/07/01 ZCZL.lwy Delete Start 0.3.000.000:新WizLIFE２次開発
--          ELSE
--            IF NOT FUNC_CREATE_INTERNAL2 THEN
--                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('教育異動通知の作成処理が異常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
--                RAISE eEXCEPTION;
--            END IF;
--          END IF;
--  2024/07/01 ZCZL.lwy Delete End
          --------------------
          -- 中間テーブル作成
          --------------------
          SEQ_NO := 0;
--  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発
--          IF NCHOHYO_KBN <> 1 THEN
--            FOR NKBN IN 1..3 LOOP   -- 転入、転出、学校区内異動
--                 IF NOT FUNC_CREATE_WORK(NKBN) THEN
                IF NOT FUNC_CREATE_WORK THEN
                    BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('教育異動通知の作成処理が異常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
                    RAISE eEXCEPTION;
                END IF;
--             END LOOP;
--           ELSE
--             IF NOT FUNC_CREATE_WORK2 THEN
--                 BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('教育異動通知の作成処理が異常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
--                 RAISE eEXCEPTION;
--             END IF;
--           END IF;
--  2024/07/01 ZCZL.lwy Update End
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', SUBSTR('中間テーブルを作成しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);

          -- 処理ログの出力
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', SUBSTR('異動累計マスタから異動データ ' || IKENSU_IN || ' 件を取得しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
--  2024/07/01 ZCZL.lwy Delete Start 0.3.000.000:新WizLIFE２次開発
--           BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', SUBSTR('転入学分の異動データ ' || IKENSU_TENNYU || ' 件数を処理しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
--           BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', SUBSTR('転出学分の異動データ ' || IKENSU_TENSHUTSU || ' 件数を処理しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
--           BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', SUBSTR('学校区内の異動データ ' || IKENSU_KUNAI || ' 件数を処理しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
--  2024/07/01 ZCZL.lwy Delete End
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', SUBSTR('教育異動通知の作成処理が正常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        END IF;

        --------------------
        -- CSVファイルの作成
        --------------------
 --  2024/07/01 ZCZL.lwy Update Start 0.3.000.000:新WizLIFE２次開発（標準化）       
        --異動通知書ワーク
        
        CASE g_rJSTP.CHOHYOID
--          WHEN 'GKB290R001' THEN
          WHEN 'GKB090R001' THEN
--            IF NCHOHYO_KBN <> 1 THEN
              -- 異動通知書
--              GKBSKIDOTCH(NKIJUNBI, g_nTIME, g_sWSNUM, g_sTANTOCODE, 'GKB290R001', NULL, g_nJOBNUM, c_BATCH);
                BRTN := FUNC_CREATE_CSV_001;
--            END IF;
--          WHEN 'GKB290R002' THEN
--            IF NCHOHYO_KBN = 1 THEN
              -- 変更通知書
--              GKBSKIDOTCH(NKIJUNBI, g_nTIME, g_sWSNUM, g_sTANTOCODE, 'GKB290R002', NULL, g_nJOBNUM, c_BATCH);
--            END IF;
--          WHEN 'GKB290R003' THEN
--            IF NCHOHYO_KBN = 1 THEN
              -- 変更通知一覧
--              GKBSKIDOTCH(NKIJUNBI, g_nTIME, g_sWSNUM, g_sTANTOCODE, 'GKB290R003', NULL, g_nJOBNUM, c_BATCH);
--            END IF;
          ELSE
            NULL;
        END CASE;

        --帳票出力CSVの作成
--         CASE g_rJSTP.CHOHYOID
--            WHEN 'GKB290R001' THEN
             --CSV出力処理
--              bRTN := FUNC_B11CSV ('GKBWL290R001');
--            WHEN 'GKB290R002' THEN
             --CSV出力処理
--              bRTN := FUNC_B11CSV ('GKBWL290R002');
--            WHEN 'GKB290R003' THEN
             --CSV出力処理
--              bRTN := FUNC_B11CSV ('GKBWL290R003');
--            ELSE
--              NULL;
--         END CASE;
        -- 異動通知書（保護者）
        IF g_vHOGOSYAATE = 1 THEN
          bRTN := FUNC_B11CSV ('GKBWL090R002');
        END IF;
        -- 異動通知書（新学校)
        IF g_vSHINGAKKOATE = 1 THEN
          bRTN := FUNC_B11CSV ('GKBWL090R003');
        END IF;
        -- 異動通知書（旧学校)
        IF g_vKYUGAKKOYAATE = 1 THEN
          bRTN := FUNC_B11CSV ('GKBWL090R004');
        END IF;
--  2024/07/01 ZCZL.lwy Update End
        --最後ロジックの実行
        --ROLLBACKの処理、と件数表の値、既存の最後更新、削除処理等
        IF g_nSTEP_INDEX = g_nSTEP_MAX THEN
          IF bRTN THEN
            COMMIT;    --データ確定
          ELSE
            ROLLBACK;
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
        --PROC_KENSUSET;

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
END GKBPB00210;
/