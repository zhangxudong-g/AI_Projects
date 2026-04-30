CREATE OR REPLACE PACKAGE BODY GKBPB00330
--1.0.452.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 成人式
--  機能概要   : 成人式案内状／成人式案内状発送者一覧表を作成する
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE 0.3.000.000:新WizLIFE２次開発
--  2024/08/20 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00018対応
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00075対応
--  2024/09/09 ZCZL.WANGMING UPDATE 0.3.000.003:8月1日認識合わせの横展開
--  2024/09/29 ZCZL.YUCHUFEI UPDATE 0.3.000.004:仕様変更 IT_GKB_00074対応
--  2024/10/28 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00323の対応
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00429対応横展開
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.007:IT_GKB_00286横展開対応
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.008:仕様変更　ID：IT_GKB_00187、IT_GKB_00376対応
--  2024/11/21 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKC_00329横展開対応
--  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.000.010:仕様変更IT_GKB_00701の対応
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10158、IT_GKB_10159、IT_GKB_10160対応
--  2025/01/15 JPJYS.LIJINGHUI UPDATE 0.3.000.012:学校区マスタ対応
--  2025/02/07 JPJYS.SONGSHIHAO UPDATE 0.3.000.013:ST_GKB_TMP00047対応
--  2025/05/07 CTC.HUANG UPDATE 1.0.003.000 GK_QA13762_成人式案内状発送者一覧表の送付先氏名に氏名カナが印字されるを対応
--  2025/05/15 CTC.LIUJUNHAO UPDATE 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
--  2025/05/28 CTC.HJF UPDATE 1.0.006.000:GKB_QA14364_未登録外字で登録した対象者が文字切れリストに表示されない対応
--  2025/06/04 CTC.LIUJUNHAO UPDATE 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
--  2025/07/28 CTC.HJF UPDATE 1.0.010.002:GKB_QA18860対応
--  2025/07/30 CTC.HJF UPDATE 1.0.011.000:GKB_QA18860+対応
--  2025/07/16 CTC.Wang UPDATE 1.0.100.000:新WizLIFE開発_帳票アウトソーシング連番対応
--  2025/11/18 CTC.HJF UPDATE 1.0.301.000:GKB_QA22670対応
--  2026/01/05 CTC.HJF UPDATE 1.0.451.000:GKB_QA25074対応
--  2026/01/06 CTC.XW UPDATE 1.0.452.000:GKB_QA24989対応
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
    g_nINDEX                      NUMBER := 0;

    g_nTIME NUMBER;  --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --パラメータ変数
    g_vJYOUKEN1         NVARCHAR2(1000);
    g_vJYOUKEN2         NVARCHAR2(1000);
    g_vJYOUKEN3         NVARCHAR2(1000);
    g_vJYOUKEN4         NVARCHAR2(1000);
    g_vJYOUKEN5         NVARCHAR2(1000);
    o_vKOINFILENAME     NVARCHAR2(1000);
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
    g_vJYOUKEN6         NVARCHAR2(1000);
    g_vJYOUKEN7         NVARCHAR2(1000);
    g_vJYOUKEN8         NVARCHAR2(1000);
    g_vJYOUKEN9         NVARCHAR2(1000);
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
    VMSG NVARCHAR2(4000);
    IRTN PLS_INTEGER;
    o_NBREAK         NUMBER(2);
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
    VDUMMY           NVARCHAR2(500);
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
    CURSOR CJIDO(p_NENDO IN NUMBER,
                p_IKBN  IN PLS_INTEGER,
                p_ISANTEIDANTAI_CD IN PLS_INTEGER
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
                ,p_ISEINENGAPIFROM IN PLS_INTEGER,
                p_ISEINENGAPITO    IN PLS_INTEGER
--  2024/07/01 ZCZL.GUANJINGHENG ADD  END
               ) IS
          SELECT NENDO,
                 SEIRI_NO,
                 KOJIN_CD,
                 SHIMEI_KANA,
                 SHIMEI_KANJI,
                 SEINENGAPI,
                 SEIBETU,
                 TYUGAKO_KU,
                 GYOSEI_KU,
                 YUBIN_NO,
                 CHOMEI,
                 BANCHI,
                 KATAGAKI,
                 TEL_NO,
                 SANTEIDANTAI_CD
                ,SHOGAKO_KU_CD
                ,TYUGAKO_KU_CD
                ,GYOSEI_KU_CD
            FROM GKBTSEIJINSHA
           WHERE NENDO = p_NENDO
             AND ((p_ISANTEIDANTAI_CD <> 0 AND SANTEIDANTAI_CD = p_ISANTEIDANTAI_CD) OR
                   p_ISANTEIDANTAI_CD = 0)
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発
--             AND SYUKETSU_KBN = DECODE(p_IKBN,1,1,DECODE(p_IKBN,2,0,SYUKETSU_KBN));
             AND SYUKETSU_KBN = DECODE(p_IKBN,1,1,DECODE(p_IKBN,2,0,SYUKETSU_KBN))
             AND ((p_ISEINENGAPIFROM <> 0 AND SEINENGAPI >= p_ISEINENGAPIFROM) OR p_ISEINENGAPIFROM = 0)
             AND ((p_ISEINENGAPITO <> 0 AND SEINENGAPI <= p_ISEINENGAPITO) OR p_ISEINENGAPITO = 0);
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE  END
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- 処理結果
    c_ISUCCESS      CONSTANT  PLS_INTEGER := 0;        -- 正常
    c_INOT_SUCCESS  CONSTANT  PLS_INTEGER := -1;       -- 異常
    c_INOTFOUND     CONSTANT  PLS_INTEGER := -9;       -- 該当なし
    -- エラーメッセージの値
    c_VERR_MSG01    CONSTANT  NVARCHAR2(256) := '成人式処理が異常終了しました。';
    -- 成人者マスタ
    c_VTABLE        CONSTANT  NVARCHAR2(128) := 'GKBWSEIJINSHA';
    -- １頁の最大行数
    c_IMAXROWS      CONSTANT  PLS_INTEGER := 15;
    -- 帳票区分
    c_CHOHYO_KBN    CONSTANT NUMBER(2) := 1;
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    IKBN                     PLS_INTEGER;
    VKBN                     NVARCHAR2(15);
    ISAKUSEIBI               PLS_INTEGER;
    RA                       GABTATENAKIHON%ROWTYPE;
    RASO                     GABTSOFUSAKI%ROWTYPE;
    RAS                      GABTATENAKIHON%ROWTYPE;  -- 世帯主用
    RASOS                    GABTSOFUSAKI%ROWTYPE;    -- 世帯主用
    VSHIMEI_KANA             NVARCHAR2(100);
    VSHIMEI_KANJI            NVARCHAR2(100);
    VZOKUGARAMEI             NVARCHAR2(30);
    VSEINENGAPI              NVARCHAR2(11);
    VSEIBETSU                NVARCHAR2(2);
    VHAN_MEI                 NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00429対応横展開
--    VSANTEIDANTAI_MEI        NVARCHAR2(20);
    VSANTEIDANTAI_MEI        GKBWSEIJINSHA.SANTEIDANTAIMEI%TYPE;
    VSAKUSEIBI               NVARCHAR2(30);
    VJUSHO_JODAN             NVARCHAR2(100);
    VJUSHO_GEDAN             NVARCHAR2(100);
    VTYUGAKOMEI              NVARCHAR2(30);
    VSHOGAKOMEI              NVARCHAR2(30);
    IMAX                     BINARY_INTEGER;
    VSYUHATU_MEI             NVARCHAR2(20);
    VSYUHATU_NO              NVARCHAR2(12);
    VHASOBI                  NVARCHAR2(11);
    VUSERMEI                 NVARCHAR2(40);
    VKENUSERMEI              NVARCHAR2(40);
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応 
    --VSHUCHOKATAGAKI          NVARCHAR2(40);
    VSHUCHOKATAGAKI          NVARCHAR2(1000);
    --VSHUCHOMEI               NVARCHAR2(40);
    VSHUCHOMEI               NVARCHAR2(1000);
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
    VSHUCHOKATAGAKI2         NVARCHAR2(40);
    IDATE1                   PLS_INTEGER;
    VDATE1                   NVARCHAR2(11);
    IDATE2                   PLS_INTEGER;
    VDATE2                   NVARCHAR2(11);
    IDATE3                   PLS_INTEGER;
    VDATE3                   NVARCHAR2(11);
    IDATE4                   PLS_INTEGER;
    VDATE4                   NVARCHAR2(11);
    IDATE5                   PLS_INTEGER;
    VDATE5                   NVARCHAR2(11);
    VKOMOKU1                 NVARCHAR2(120);
    VKOMOKU2                 NVARCHAR2(120);
    VKOMOKU3                 NVARCHAR2(120);
    VKOMOKU4                 NVARCHAR2(120);
    VKOMOKU5                 NVARCHAR2(120);
    VKOMOKU6                 NVARCHAR2(120);
    VKOMOKU7                 NVARCHAR2(120);
    VKOMOKU8                 NVARCHAR2(120);
    VKOMOKU9                 NVARCHAR2(120);
    VKOMOKU10                NVARCHAR2(120);
    VSHUCHONINSHOBUN2        NVARCHAR2(100);
    VSHUCHOMEI2              NVARCHAR2(40);
    VSHUCHONINSHOBUN3        NVARCHAR2(100);
    VSHUCHOMEI3              NVARCHAR2(40);
    o_nNINSHODAIRIFLG        NVARCHAR2(100);
    o_sNINSHOKATAGAKI1       NVARCHAR2(100);
    o_sNINSHOKATAGAKI2       NVARCHAR2(100);
    NWAREKINENDO             NUMBER(3);
--  2024/11/02 ZCZL.WANGMING UPDATE START 0.3.000.007:IT_GKB_00286横展開対応
    o_sEINENGAPI1                    GKAPK00020.SEINENGAPI_REC;           --生年月日
    o_sEINENGAPI2                    GKAPK00020.SEINENGAPI_REC;           --生年月日
--  2024/11/02 ZCZL.WANGMING UPDATE END

    --首長公印
    VSHUCHO_KOIN             NVARCHAR2(100);
    VSHUCHO_KOIN2            NVARCHAR2(100);

    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN                     BOOLEAN;
    B_RTN                    BOOLEAN;
    I_RTN                    PLS_INTEGER;
    -- 処理条件（画面からの引数）
    VNENDO                   NVARCHAR2(15);      -- 対象年度
    VSANTEIDANTAI_CD         NVARCHAR2(2);       -- 算定団体コード
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
    ISEINENGAPIFROM          PLS_INTEGER;        -- 生年月日(自)
    ISEINENGAPITO            PLS_INTEGER;        -- 生年月日(至)
    o_SHOGAKU_CD             NVARCHAR2(1000);    -- 小学校区コード
    o_SHOGAKU_MEI            NVARCHAR2(1000);    -- 小学校区名
    o_CHUGAKU_CD             NVARCHAR2(1000);    -- 中学校区コード
    o_CHUGAKU_MEI            NVARCHAR2(1000);    -- 中学校区名
    rSEIJIN                  GKBTTSUCHISHOKANRISEIJIN%ROWTYPE;    --通知書管理(成人式)ﾃｰﾌﾞﾙ
    sYOSHIKI                 NVARCHAR2(1000);    -- 様式文
    sTOIAWASESAKI1           NVARCHAR2(1000);    -- お問い合わせ先１
    sTOIAWASESAKI2           NVARCHAR2(1000);    -- お問い合わせ先２
    sTOIAWASESAKI3           NVARCHAR2(1000);    -- お問い合わせ先３
    g_rBUNNUMSRCINF          KKAPK0040.MR_BUNNUMSRCINF;      --文書番号情報（構造体）
    g_rBUNNUMEDITKEKA        KKAPK0040.MR_BUNNUMEDITKEKA;    --文書番号編集結果
    g_cBUNNUM                NVARCHAR2(100);
--  2024/11/21 ZCZL.ZHANGLEI UPDATE 0.3.000.003:IT_GKC_00329横展開対応
    g_nBUNSHOBANGO           NVARCHAR2(1000);                         --文書番号
    o_nDAIRIKBN              NUMBER;                         --認証者の本人・代理区分
    o_sKATAGAKI1             NVARCHAR2(1000);                --認証者の肩書上段
    o_sKATAGAKI2             NVARCHAR2(1000);                --認証者の肩書下段
    o_sSHIMEI                NVARCHAR2(1000);                --認証者の氏名
    o_sKOINFILENAME          NVARCHAR2(1000);                --公印ファイル名
    TYPE MR_BUNNUM IS RECORD(
        KOJINNUM             NUMBER,                          --宛名番号
        BUNNUM               NVARCHAR2(1000)                  --文書番号
    );
    TYPE MR_BUNNUM_REC IS TABLE OF MR_BUNNUM INDEX BY BINARY_INTEGER;
    g_rBUNNUM                MR_BUNNUM_REC;                   --変数.文書番号リスト
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
    IKISAI_JUNI              PLS_INTEGER;
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE 0.3.000.000:新WizLIFE２次開発
--    NNUSHIKOJINNO            NUMBER(12);
    NNUSHIKOJINNO            NUMBER;
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 STR
    sYUBIN_NO             NVARCHAR2(20);
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 END
--  2026/01/05 CTC.HJF UPDATE START 1.0.451.000:GKB_QA25074対応
    IHOGOSHA_KOJIN_NO            NUMBER;
--  2026/01/05 CTC.HJF UPDATE END
    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWSEIJINSHA%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK               MTJIDO_TYPE;

    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    IWAREKIHIZUKE               PLS_INTEGER;
    VEDIT_GYYMMDD1              NVARCHAR2(20);
    VEDIT_GYYMMDD2              NVARCHAR2(20);
    VEDIT_GYYMMDD3              NVARCHAR2(20);
    VKJ_GENGO                   NVARCHAR2(20);
    VKG_GENGO                   NVARCHAR2(20);
    IWAREKI_YY                  PLS_INTEGER;
    ISEIREKI_YYYY               PLS_INTEGER;
    IWAREKI_GYYMM               PLS_INTEGER;
    IMM                         PLS_INTEGER;
    IDD                         PLS_INTEGER;
    IOWAREKIHIZUKE              PLS_INTEGER;
    ISEIREKIHIZUKE              PLS_INTEGER;
    -- 共通情報取得用変数(KKAPK0030.FKYOTU)
    o_IUSER_ID                  PLS_INTEGER;      -- 市町村コード
    o_IGAPPEI_BI                PLS_INTEGER;      -- 合併日付
    o_IJICHI_CD                 PLS_INTEGER;      -- 自治コード
    o_IUSER_KBN                 PLS_INTEGER;      -- 市町村区分
    o_VKENMEI                   NVARCHAR2(30);    -- 県名
    o_VGUNSHIMEI                NVARCHAR2(30);    -- 郡市名
    o_VUSERMEI                  NVARCHAR2(40);    -- 市町村名
    o_VSHUCHOMEI                NVARCHAR2(40);    -- 首長名
    o_VSHUCHONINSHOBUN          NVARCHAR2(100);   -- 首長認証文
    o_VYUBIN_NO                 NVARCHAR2(10);    -- 郵便番号
    o_VSHOZAICHI                NVARCHAR2(200);   -- 所在地
    o_VTEL_NO                   NVARCHAR2(20);    -- 代表電話番号

    VSQLERRM                    NVARCHAR2(256);   -- 外部関数から返ってくるエラーメッセージ
    VPAGENM                     NVARCHAR2(500);   -- 改頁項目名
    VPAGEFD                     NVARCHAR2(500);   -- 改頁項目値
    -- 教育委員会情報取得用変数(KKAPK0030.FPRMSHUTOKU)
    ACONSPRM           A_CONS_PRM;
    NLENGTH            NUMBER;
    IRTN_KYOIKUKAI     PLS_INTEGER;
    o_ACONSPRM         A_CONS_PRM;
    o_NLENGTH          NUMBER;
    IRTN_SEIJINANNAI   PLS_INTEGER;
    NKENSU             NUMBER;    --対象者件数
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        cmbSakuseiKbn DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/09/03 ZCZL.WANGMING ADD START 0.3.000.002:IT_GKB_00075対応
        cmbtxtShienSochi   DBMS_UTILITY.MAXNAME_ARRAY;
        cmboptHakkoRireki  DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/09/03 ZCZL.WANGMING ADD END
    BEGIN
        -- 対象年度
        g_vJYOUKEN1   := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNendo');
        -- 文書発送番号
--  2024/07/01 ZCZL.GUANJINGHENG DELETE 0.3.000.000:新WizLIFE２次開発
--        g_vJYOUKEN2   := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtBunshoHassoNo');
        -- 発送日
        g_vJYOUKEN3   := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHassoBi');
        -- 作成区分
        cmbSakuseiKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbSakuseiKbn');
        g_vJYOUKEN4 := cmbSakuseiKbn(1);
        -- 算定団体
        g_vJYOUKEN5   := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSanteiDantai');
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発
        -- 生年月日(開始)
        g_vJYOUKEN6   := KKBPK5551.GETPARMS(g_nJOBNUM,'txtBirStartYmd');
        -- 生年月日(終了)
        g_vJYOUKEN7   := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtBirEndYmd');
--  2024/09/03 ZCZL.WANGMING UPDATE START 0.3.000.002:IT_GKB_00075対応
        -- 支援措置対象者マスク
--        g_vJYOUKEN8   := KKBPK5551.GETPARMS(g_nJOBNUM,'txtShienSochi');
        cmbtxtShienSochi := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtShienSochi');
        g_vJYOUKEN8 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtShienSochi', 0, cmbtxtShienSochi);
        -- 発行履歴
--        g_vJYOUKEN9   := KKBPK5551.GETPARMS(g_nJOBNUM,'optHakkoRireki');
        cmboptHakkoRireki := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'optHakkoRireki');
        g_vJYOUKEN9 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'optHakkoRireki', 0, cmboptHakkoRireki);
--  2024/09/03 ZCZL.WANGMING UPDATE END
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE END
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
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
    --作成区分チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCKUBUNCHK( i_VKUBUN IN NVARCHAR2 ) RETURN NUMBER IS
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
        IF KUBUN < 1 OR KUBUN > 3 THEN
          IRET := 1;
        END IF;
      END IF;

      RETURN(IRET);
    END FUNCKUBUNCHK;
    ----------------------------------------------------------------------------------------------------
    --日付チェック
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
    --発送番号チェック
    ----------------------------------------------------------------------------------------------------
--  2024/07/01 ZCZL.GUANJINGHENG DELETE START 0.3.000.000:新WizLIFE２次開発
--    FUNCTION FUNCHASOBANGOCHK( i_VHASOBANGO IN NVARCHAR2 ) RETURN NUMBER IS
--      IRET PLS_INTEGER;
--      IHASOBANGO PLS_INTEGER;
--    BEGIN
--      IRET := 0;
--      --発送番号
--      BEGIN
--        IF i_VHASOBANGO IS NULL THEN
--          IRET := 1;
--        ELSIF LENGTH(i_VHASOBANGO) > 5 THEN
--          IRET := 1;
--        ELSE
--          IHASOBANGO  := TO_NUMBER(i_VHASOBANGO);
--        END IF;
--      EXCEPTION
--        WHEN OTHERS THEN
--          IRET := 1;
--      END;
--
--      RETURN(IRET);
--    END FUNCHASOBANGOCHK;
--  2024/07/01 ZCZL.GUANJINGHENG DELETE END
    ----------------------------------------------------------------------------------------------------
    --学年チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCGAKUNENCHK( i_VGAKUNEN IN NVARCHAR2 ) RETURN NUMBER IS
      IRET PLS_INTEGER;
      GAKUNEN PLS_INTEGER;
    BEGIN
      IRET := 0;
      --学年
      BEGIN
        IF i_VGAKUNEN IS NULL THEN
          IRET := 1;
        ELSE
          GAKUNEN  := TO_NUMBER(i_VGAKUNEN);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      IF IRET = 0 THEN
        IF GAKUNEN > 9 THEN
          IRET := 1;
        ELSE
          IRET := 0;
        END IF;
      END IF;

      RETURN(IRET);
    END FUNCGAKUNENCHK;
    ----------------------------------------------------------------------------------------------------
    --年度チェック
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
        ICHK1                         NUMBER := 0;
        ICHK2                         NUMBER := 0;
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
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

        --条件１のチェック
        IRTN := FUNCNENDOCHK( g_vJYOUKEN1 );
        IF IRTN <> 0 THEN
            VMSG := g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
        END IF;
--  2024/07/01 ZCZL.GUANJINGHENG DELETE START 0.3.000.000:新WizLIFE２次開発
--        --条件２のチェック
--        IRTN := FUNCHASOBANGOCHK( g_vJYOUKEN2 );
--        IF IRTN <> 0 THEN
--            VMSG := VMSG || g_sGYOUMUCODE || ',99999,発送番号が正しくありません。,;';
--        END IF;
--  2024/07/01 ZCZL.GUANJINGHENG DELETE END
        --条件３のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN3 );
        IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,発送日が正しくありません。,;';
        END IF;

        --条件４のチェック
        IRTN := FUNCKUBUNCHK( g_vJYOUKEN4 );
        IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,作成区分が正しくありません。,;';
        END IF;

--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
       IF KKAPK0010.FISNUMERIC(g_vJYOUKEN6) = FALSE THEN
         VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（開始）が正しくありません。,;';
         ICHK1 := 1;
       ELSE
          --日付チェック
          BRTN := KKAPK0020.FISDATEW(g_vJYOUKEN6);
          IF NOT bRTN THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（開始）が正しくありません。,;';
            ICHK1 := 1;
          END IF;
       END IF;
       IF KKAPK0010.FISNUMERIC(g_vJYOUKEN7) = FALSE THEN
         VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（終了）が正しくありません。,;';
         ICHK2 := 1;
       ELSE
          --日付チェック
          BRTN := KKAPK0020.FISDATEW(g_vJYOUKEN7);
          IF NOT bRTN THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（終了）が正しくありません。,;';
            ICHK1 := 1;
          END IF;
       END IF;
       -- 変数.生年月日（開始） > 変数.生年月日（終了）の場合
       IF ICHK1 = 0 AND ICHK2 = 0 THEN
         IF g_vJYOUKEN6 > g_vJYOUKEN7 THEN
           VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（開始）、生年月日（終了）の関係が正しくありません。,;';
         END IF;
       END IF;
       -- 支援措置対象者マスク 入力値が0,1以外の場合
       IF g_vJYOUKEN8 <> 0 AND g_vJYOUKEN8 <> 1 THEN
         VMSG := VMSG || g_sGYOUMUCODE || ',99999,支援措置対象者マスクが正しくありません。,;';
       END IF;
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発

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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
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
    --------------------------------------------------------------------------------------------------
    -- 処理条件の設定
    --------------------------------------------------------------------------------------------------
    PROCEDURE PROCHAISET IS
        IWAREKI  PLS_INTEGER;
        ISEIREKI PLS_INTEGER;
        EXCEPT   EXCEPTION;
        --  2024/04/22 ZCZL.WUCAO ADD START 0.2.000.001:512_GKB_00027対応
        n_KFNAME_Flg number := 0;  --公印取得の判定フラグ
--  2024/08/20 ZCZL.WANGMING ADD Start 0.3.000.001:IT_GKB_00018対応
        o_sKATAGAKI1            NVARCHAR2(1000);              --認証者の肩書上段
        o_sKATAGAKI2            NVARCHAR2(1000);              --認証者の肩書下段
--  2024/08/20 ZCZL.WANGMING ADD End
    BEGIN
        -- 市町村名等の設定
        IRTN := KKAPK0030.FKYOTU(ISAKUSEIBI, o_IUSER_ID, o_IJICHI_CD, o_IGAPPEI_BI,
                             o_IUSER_KBN, o_VGUNSHIMEI, o_VUSERMEI, o_VSHUCHOMEI,
                             o_VKENMEI,o_VSHUCHONINSHOBUN, o_VYUBIN_NO, o_VSHOZAICHI, o_VTEL_NO);
        VUSERMEI    := o_VUSERMEI;
        VKENUSERMEI := o_VKENMEI || o_VGUNSHIMEI || o_VUSERMEI;
        VSHUCHOMEI  := o_VSHUCHOMEI;

        -- 発送日の設定
        IWAREKI  := TO_NUMBER(VHASOBI);
        ISEIREKI := 0;
        BRTN := KKAPK0020.FDAYEDIT( IWAREKI,
                                     ISEIREKI,
                                     VEDIT_GYYMMDD3,
                                     VEDIT_GYYMMDD2,
                                     VHASOBI,
                                     VKJ_GENGO,
                                     VKG_GENGO,
                                     IWAREKI_YY,
                                     ISEIREKI_YYYY,
                                     IWAREKI_GYYMM,
                                     IMM,
                                     IDD,
                                     IOWAREKIHIZUKE,
                                     ISEIREKIHIZUKE);

        --市町村名取得（稼働ユーザ情報取得サブルーチン）
--  2024/08/20 ZCZL.WANGMING UPDATE Start 0.3.000.001:IT_GKB_00018対応
--        KKAPK0030.SNinshGet(ISEIREKIHIZUKE, o_nNINSHODAIRIFLG, VSHUCHOMEI2, o_sNINSHOKATAGAKI1, o_sNINSHOKATAGAKI2, VSHUCHONINSHOBUN2);
        BRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE, 0), g_sWSNUM, TO_DATE(ISEIREKIHIZUKE,'YYYYMMDD'), o_nDAIRIKBN, o_sKATAGAKI1, o_sKATAGAKI2, o_sSHIMEI, VDUMMY);

        --  2024/04/22 ZCZL.WUCAO ADD START 0.2.000.001:512_GKB_00027対応
        BEGIN
            SELECT
                KOINFILENAME
            INTO
                o_vKOINFILENAME
            FROM (
                SELECT
                    KOINFILENAME
                FROM
                    KKNTDK
                WHERE (NINSHOCODE = NVL(g_rJSTP.NINSHOCODE, 0))
                AND (KOINGRP = ( SELECT KOINGRP
                                   FROM KKNTWS
                                  WHERE WSNUM = g_sWSNUM ))
                AND (TO_CHAR (YUKOKIKANFR, 'YYYY/MM/DD')
                   <= TO_CHAR (TO_DATE(ISEIREKIHIZUKE,'YYYYMMDD'), 'YYYY/MM/DD'))
                AND ((TO_CHAR (YUKOKIKANTO, 'YYYY/MM/DD')
                   >= TO_CHAR (TO_DATE(ISEIREKIHIZUKE,'YYYYMMDD'), 'YYYY/MM/DD')) OR
                           (YUKOKIKANTO IS NULL))
                     ORDER BY YUKOKIKANFR DESC )
             WHERE ROWNUM = 1;
             n_KFNAME_Flg := 0;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                n_KFNAME_Flg := 1;
            WHEN OTHERS THEN
                n_KFNAME_Flg := 2;
        END;
        --  2024/04/22 ZCZL.WUCAO ADD END

        BRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE, 0),
                                     g_sWSNUM,
                                     TO_DATE(ISEIREKIHIZUKE,'YYYYMMDD'),
                                     VDUMMY,
                                     VDUMMY,
                                     VDUMMY,
                                     VDUMMY,
                                     o_vKOINFILENAME);
        IF NOT BRTN THEN
          --  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
          IF n_KFNAME_Flg = 2 THEN
            RETURN;
          --  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
          END IF;
        END IF;

--  2024/08/20 ZCZL.WANGMING UPDATE Start 0.3.000.001:IT_GKB_00018対応
--        VSHUCHOKATAGAKI := VSHUCHONINSHOBUN2;
--        VSHUCHOMEI := VSHUCHOMEI2;
        VSHUCHOKATAGAKI := o_sKATAGAKI1 || o_sKATAGAKI2;
        VSHUCHOMEI := o_sSHIMEI;
--  2024/08/20 ZCZL.WANGMING UPDATE End
        VSHUCHO_KOIN := o_vKOINFILENAME;

--  2024/08/20 ZCZL.WANGMING DELETE 0.3.000.001:IT_GKB_00018対応
--        KKAPK0030.SNinshGet(ISEIREKIHIZUKE, o_nNINSHODAIRIFLG, VSHUCHOMEI3, o_sNINSHOKATAGAKI1, o_sNINSHOKATAGAKI2, VSHUCHONINSHOBUN3);

        IRTN_SEIJINANNAI := KKAPK0030.FPRMSHUTOKU(g_sGYOUMUCODE,'00SEIJINANNAI',0,o_ACONSPRM,o_NLENGTH);
        IF IRTN_SEIJINANNAI = 1 THEN
           o_ACONSPRM := A_CONS_PRM();
           o_ACONSPRM.EXTEND;
           o_ACONSPRM.EXTEND;
           o_ACONSPRM(1) := 0;
           o_ACONSPRM.EXTEND;
           o_ACONSPRM(2) := 0;
           o_ACONSPRM.EXTEND;
           o_ACONSPRM(3) := 0;
           o_ACONSPRM.EXTEND;
           o_ACONSPRM(4) := 0;
        ELSE
          WHILE (o_NLENGTH < 4) LOOP
                       o_ACONSPRM.EXTEND;
           o_ACONSPRM(o_NLENGTH+1) := 0;
           o_NLENGTH := o_NLENGTH + 1;
         END LOOP;
        END IF;

        IF o_ACONSPRM(1) = 0 THEN
--  2024/08/20 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00018対応
--           VSHUCHOKATAGAKI2 := VSHUCHONINSHOBUN3;
           VSHUCHOKATAGAKI2 := o_sKATAGAKI1 || o_sKATAGAKI2;
        ELSE
           VSHUCHOKATAGAKI2 := NULL;
        END IF;
        IF o_ACONSPRM(2) = 0 THEN
--  2024/08/20 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00018対応
--           VSHUCHOMEI2 := VSHUCHOMEI3;
           VSHUCHOMEI2 := o_sSHIMEI;
        ELSE
           VSHUCHOMEI2 := NULL;
        END IF;
        VSHUCHO_KOIN2 := o_vKOINFILENAME;

    END PROCHAISET;

    --------------------------------------------------------------------------------
    -- 成人者ワーク中間レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        IFRET                PLS_INTEGER;                -- 戻り値
        INENDO               PLS_INTEGER;                -- 年度
        ICNT                 BINARY_INTEGER;             -- 戻り値
        IRTN                 PLS_INTEGER;                -- 呼出関数の戻り値
        BRTN                 BOOLEAN;
        IWAREKI              PLS_INTEGER;
        IATENA_FLG           PLS_INTEGER;                -- 宛名フラグ（[0]:宛名情報あり、[1]:宛名情報なし）
        ISANTEIDANTAI_CD     PLS_INTEGER;                -- 算定団体コード
        NKYOIKUIINKAI_CD     NUMBER(2,0);                -- 教育委員会
        o_RATENA_REC   GABTATENAKIHON%ROWTYPE;
        o_RSOFU_REC    GABTSOFUSAKI%ROWTYPE;
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
        aPRM                    A_CONS_PRM;
        sJUSHO                  NVARCHAR2(1000);
        vCHOMEI_BANCHI          NVARCHAR2(1000);         -- 住所マスク文字列
        nPRMCTL                 NUMBER;
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
    BEGIN
        IFRET  := c_INOTFOUND;                           -- 該当なし
        INENDO := TO_NUMBER(VNENDO);                     -- 年度
        IKBN   := TO_NUMBER(VKBN);                       -- 作成区分
        IF VSANTEIDANTAI_CD IS NOT NULL THEN
          ISANTEIDANTAI_CD := TO_NUMBER(VSANTEIDANTAI_CD);  -- 算定団体コード
        ELSE
          ISANTEIDANTAI_CD := 0;
        END IF;
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
        -- 通知書管理(成人式)から通知文を取得する。
        BEGIN
          SELECT TSUCHIBUN
                ,YOSHIKI_BANGO_SETTOGO
                ,YOSHIKI_BANGO
                ,YOSHIKI_BANGO_SETSUBIGO
                ,KOIN_SHORYAKU
                ,KOIN_CHUSHAKU
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10159対応 STR
                ,CHOHYO_MEI
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10159対応 END
            INTO rSEIJIN.TSUCHIBUN                                 -- 通知文
                ,rSEIJIN.YOSHIKI_BANGO_SETTOGO                     -- 様式番号接頭語
                ,rSEIJIN.YOSHIKI_BANGO                             -- 様式番号
                ,rSEIJIN.YOSHIKI_BANGO_SETSUBIGO                   -- 様式番号接尾語
                ,rSEIJIN.KOIN_SHORYAKU                             -- 公印省略
                ,rSEIJIN.KOIN_CHUSHAKU                             -- 公印注釈
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10159対応 STR
                ,rSEIJIN.CHOHYO_MEI                                --帳票名
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10159対応 END
            FROM GKBTTSUCHISHOKANRISEIJIN
           WHERE CHOHYO_KBN = '1';

           sYOSHIKI := rSEIJIN.YOSHIKI_BANGO_SETTOGO  || rSEIJIN.YOSHIKI_BANGO || rSEIJIN.YOSHIKI_BANGO_SETSUBIGO;
        EXCEPTION
--  2024/09/09 ZCZL.WANGMING UPDATE 0.3.000.003:8月1日認識合わせの横展開
--          WHEN NO_DATA_FOUND THEN
          WHEN OTHERS THEN
               rSEIJIN.TSUCHIBUN      := NULL;
               rSEIJIN.YOSHIKI_BANGO  := NULL;
               rSEIJIN.KOIN_SHORYAKU  := NULL;
               rSEIJIN.KOIN_CHUSHAKU  := NULL;
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10159対応 STR
               rSEIJIN.CHOHYO_MEI     := NULL;
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10159対応 END
               sYOSHIKI               := NULL;
        END;
--  2024/11/12 ZCZL.WANGMING ADD 0.3.000.008:仕様変更　ID：IT_GKB_00187対応
        IF g_rJSTP.Chohyoid = 'GKB400R001' THEN
          -- 文書番号情報を取得する
          BRTN := KKBPK5551.FJBNSGet(g_nJOBNUM, g_rJSTP.STEPSEQ, g_rBUNNUMSRCINF);
          -- 戻り値がFALSEの場合
          IF BRTN = FALSE THEN
              BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK１', 1, '', '', '文書番号情報を取得する時に共通関数(KKBPK5551.FJBNSGet)を行った際に、エラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
          END IF;
          --文書番号編集結果を取得
          g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
          g_cBUNNUM := g_rBUNNUMEDITKEKA.NUM;   --文書番号
--  2024/11/12 ZCZL.WANGMING ADD 0.3.000.008:仕様変更　ID：IT_GKB_00187対応
        END IF;
        -- 公印情報を取得する
        BRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE,0),
                                     g_sWSNUM,
                                     SYSDATE,
                                     o_nDAIRIKBN,
                                     o_sKATAGAKI1,
                                     o_sKATAGAKI2,
                                     o_sSHIMEI,
                                     o_sKOINFILENAME);
        -- 戻り値がFALSEの場合
        IF BRTN = FALSE THEN
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK2', 1, '', '', '公印情報を取得する時に共通関数(KKBPK5551.FNINSHOGet)を行った際に、エラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
        END IF;
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
        --処理条件の和暦年度（数字のみ）を保存
        NWAREKINENDO := INENDO;

        -- 対象年度を西暦に変換
        INENDO := KKAPK0020.FNENDO(INENDO,1);

        VNENDO := KKAPK0020.FNENDOEDIT(1,
                                        INENDO,
                                        3);
        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        ICNT := 0;
        -- 処理条件の年度に該当する成人者を検索
        BEGIN
          -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
            FOR CRS IN CJIDO(INENDO
                            ,IKBN
                            ,ISANTEIDANTAI_CD
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
                            ,ISEINENGAPIFROM     -- 生年月日(自)
                            ,ISEINENGAPITO       -- 生年月日(至)
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
                            ) LOOP
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
              -- 教育委員会情報
              aPRM := A_CONS_PRM();
              IRTN := KKAPK0030.FPRMSHUTOKU('GKB',         --業務コード
                                        '00SEIJINANNAI',   --制御コンスタントコード
                                        1,                 --制御コンスタント連番
                                        aPRM,
                                        NLENGTH);
              -- 戻り値が1の場合
              IF IRTN = 1 THEN
                  BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK１', 1, '', '', '教育委員会情報を取得する時に共通関数(KKAPK0030.FPRMSHUTOKU)を行った際に、エラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
              END IF;
              -- お問い合わせ先１
              sTOIAWASESAKI1 := aPRM(1);
              -- お問い合わせ先２
              sTOIAWASESAKI2 := aPRM(6);
              -- お問い合わせ先３
              sTOIAWASESAKI3 := aPRM(7);
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
              -- 成人者の個人番号より宛名情報取得
              IRTN := GAAPK0030.FGETATENA(CRS.KOJIN_CD,
                                        'GKB',
                                        ISAKUSEIBI,
                                        RA,
                                        RASO);
              IATENA_FLG := 1;    -- 宛名情報なし
              IF CRS.KOJIN_CD <> 0 AND
                 IRTN = 0 THEN
                 -- 個人番号(GKBTSEIJINSHA:KOJIN_NO)がゼロでなく、その個人番号で宛名情報が取得できた場合
                 IATENA_FLG := 0;    -- 宛名情報あり
              END IF;

              -- 個人番号より住基異動の実続柄名取得
              BEGIN
                SELECT ZOKUGARA_MEI
                  INTO VZOKUGARAMEI
                  FROM GABTJUKIIDO
                 WHERE KOJIN_NO = CRS.KOJIN_CD;
              EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                  VZOKUGARAMEI := ' ';
              END;

              --世帯主取得
              NNUSHIKOJINNO := 0;
              VSHIMEI_KANA  := ' ';
              VSHIMEI_KANJI := ' ';
              -- 世帯主取得共通サブルーチンから世帯主名を取得する
              IRTN := JIAPK0030.FGETNUSHI( ISAKUSEIBI,
                                              CRS.KOJIN_CD,
                                              NNUSHIKOJINNO,
                                              VSHIMEI_KANJI);

              --世帯主が取得できたとき
              IF IRTN <> 9 THEN
                 -- 世帯主の宛名情報を取得
                 IRTN := GAAPK0030.FGETATENA( NNUSHIKOJINNO,
                                            g_sGYOUMUCODE,
                                            ISAKUSEIBI,
                                            RAS,
                                            RASOS);
                 VSHIMEI_KANA := RAS.SHIMEI_KANA;
                 VSHIMEI_KANJI := RAS.SHIMEI_KANJI;
              ELSE
                 NNUSHIKOJINNO := 0;
                 VSHIMEI_KANA  := ' ';
                 VSHIMEI_KANJI  := ' ';
              END IF;

              --行政区名取得
              --宛名情報があるとき
              IF IATENA_FLG = 0 THEN
                MJIDO_WORK(ICNT).GYOSEIKU_CD := RA.GYOSEIKU_CD;
                MJIDO_WORK(ICNT).GYOSEIKUMEI := GAAPK0030.FGYOSEIKUMEI(RA.SANTEIDANTAI_CD,RA.GYOSEIKU_CD);
              ELSE
                MJIDO_WORK(ICNT).GYOSEIKU_CD := CRS.GYOSEI_KU_CD;
                MJIDO_WORK(ICNT).GYOSEIKUMEI := CRS.GYOSEI_KU;
              END IF;
              VHAN_MEI := GAAPK0030.FHANMEI(RA.SANTEIDANTAI_CD,
                                             RA.HAN_CD);

              IF CRS.SEIBETU = 1 THEN
                 VSEIBETSU := '男';
              ELSIF CRS.SEIBETU = 2 THEN
                    VSEIBETSU := '女';
              END IF;

              IWAREKIHIZUKE := 0;
              BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                           ISAKUSEIBI,
                                           VEDIT_GYYMMDD1,
                                           VEDIT_GYYMMDD2,
                                           VSAKUSEIBI,
                                           VKJ_GENGO,
                                           VKG_GENGO,
                                           IWAREKI_YY,
                                           ISEIREKI_YYYY,
                                           IWAREKI_GYYMM,
                                           IMM,
                                           IDD,
                                           IOWAREKIHIZUKE,
                                           ISEIREKIHIZUKE );

              MJIDO_WORK(ICNT).NENDO := VNENDO;
              MJIDO_WORK(ICNT).KAIPEJI_CD := ' ';
              MJIDO_WORK(ICNT).KAIPEJI := ' ';
              MJIDO_WORK(ICNT).HAN_CD := RA.HAN_CD;
              MJIDO_WORK(ICNT).HANMEI := VHAN_MEI;
              MJIDO_WORK(ICNT).SHIMEI_KANA := CRS.SHIMEI_KANA;
              MJIDO_WORK(ICNT).SEINENGAPI := CRS.SEINENGAPI;
              IF CRS.SEINENGAPI = 0 THEN
                 VSEINENGAPI := ' ';
              ELSE
                 IWAREKIHIZUKE := 0;
                 BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                              CRS.SEINENGAPI,
                                              VSEINENGAPI,
                                              VEDIT_GYYMMDD2,
                                              VEDIT_GYYMMDD3,
                                              VKJ_GENGO,
                                              VKG_GENGO,
                                              IWAREKI_YY,
                                              ISEIREKI_YYYY,
                                              IWAREKI_GYYMM,
                                              IMM,
                                              IDD,
                                              IOWAREKIHIZUKE,
                                              ISEIREKIHIZUKE);
              END IF;
              MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VSEINENGAPI;
              MJIDO_WORK(ICNT).SEIBETSU := CRS.SEIBETU;
              MJIDO_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;
              MJIDO_WORK(ICNT).SETAI_NO := RA.SETAI_NO;
              MJIDO_WORK(ICNT).SAKUSEIBI := VSAKUSEIBI;
              MJIDO_WORK(ICNT).RENBAN := 0;
              MJIDO_WORK(ICNT).SHIMEI_KANJI := CRS.SHIMEI_KANJI;
              MJIDO_WORK(ICNT).ZOKUGARAMEI := VZOKUGARAMEI;

              IF IATENA_FLG = 0 THEN
                 -- 宛名情報がある場合
                 MJIDO_WORK(ICNT).CHOMEI := RA.CHOMEI;
                 MJIDO_WORK(ICNT).SHIMEI_KANJI := RA.SHIMEI_KANJI;
                 MJIDO_WORK(ICNT).SHIMEI_KANA  := RA.SHIMEI_KANA;
                 MJIDO_WORK(ICNT).BANCHI := RA.BANCHI;
                 MJIDO_WORK(ICNT).KATAGAKI := RA.KATAGAKI;
                 MJIDO_WORK(ICNT).YUBIN_NO := RA.YUBIN_NO;
                 VJUSHO_JODAN := SUBSTR (RA.CHOMEI||RA.BANCHI||RA.KATAGAKI,1,100);
                 VJUSHO_GEDAN := SUBSTR (RA.CHOMEI||RA.BANCHI||RA.KATAGAKI,101,200);

                 --中学校区／小学校区
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発
                 -- 共通関数（GKBFKGKKUGET）より学齢簿学校区を取得する。
                 IRTN := GKBFKGKKUGET(CRS.KOJIN_CD,RA.RIREKI_RENBAN,o_SHOGAKU_CD,o_SHOGAKU_MEI,o_CHUGAKU_CD,o_CHUGAKU_MEI);
                 -- 戻り値が1の場合
                 IF IRTN = 1 THEN
                     BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK１', 1, '', '', '[成人式案内通知]共通関数(GKBFKGKKUGET)でエラーが発生しました。　宛名番号 ： ' || RA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
                 END IF;
                 MJIDO_WORK(ICNT).CHUGAKOKU_CD := o_CHUGAKU_CD;
                 MJIDO_WORK(ICNT).SHOGAKOKU_CD := o_SHOGAKU_CD;
--  2025/01/15 JPJYS.LIJINGHUI UPDATE 0.3.000.011:学校区マスタ対応  Start                 
                 MJIDO_WORK(ICNT).CHUGAKOKU_CD := RA.CHUGAKU_CD;
--                 MJIDO_WORK(ICNT).CHUGAKOMEI   := GAAPK0030.FCHUGAKUMEI(RA.SANTEIDANTAI_CD,RA.CHUGAKU_CD);
                 MJIDO_WORK(ICNT).SHOGAKOKU_CD := RA.SHOGAKU_CD;
--                 MJIDO_WORK(ICNT).SHOGAKOMEI   := GAAPK0030.FSHOGAKUMEI(RA.SANTEIDANTAI_CD,RA.SHOGAKU_CD);
--  2025/01/15 JPJYS.LIJINGHUI UPDATE 0.3.000.011:学校区マスタ対応  End 
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE END
                 MJIDO_WORK(ICNT).YUHEN_KBN := RA.YUHEN_KBN;      --郵返区分
                 MJIDO_WORK(ICNT).OAZA_CD := RA.OAZA_CD;          --大字コード
                 MJIDO_WORK(ICNT).HONBAN := RA.HONBAN;            --本番
                 MJIDO_WORK(ICNT).EDABAN1 := RA.EDABAN1;          --枝１
                 MJIDO_WORK(ICNT).EDABAN2 := RA.EDABAN2;          --枝２
                 MJIDO_WORK(ICNT).EDABAN3 := RA.EDABAN3;          --枝３
                 MJIDO_WORK(ICNT).GAIKU := RA.GAIKU;              --街区
                 MJIDO_WORK(ICNT).TOU := RA.TOU;                  --棟
                 MJIDO_WORK(ICNT).GOU := RA.GOU;                  --号
                 MJIDO_WORK(ICNT).GENZON_KBN := RA.GENZON_KBN;    --現存区分
                 IKISAI_JUNI := 0;
                 BEGIN
                   SELECT KISAI_JUNI INTO IKISAI_JUNI
                     FROM GABTJUKIIDO
                    WHERE KOJIN_NO = RA.KOJIN_NO;
                 EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     IKISAI_JUNI := 0;
                 END;
                 MJIDO_WORK(ICNT).KISAI_JUNI := IKISAI_JUNI;      --記載順位
                 MJIDO_WORK(ICNT).SANTEIDANTAI_CD := RA.SANTEIDANTAI_CD;
                 IRTN := GAAPK0030.FJICHINAME(RA.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);
                 MJIDO_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;
                 MJIDO_WORK(ICNT).YUBIN_NOBC := RA.YUBIN_NOBC;

                 --送付先住所の設定があるときは上書きする
                 IF RASO.KOJIN_NO IS NOT NULL
                    AND (RASO.TEKIYO_BI <= ISAKUSEIBI)
                    AND (RASO.SHURYO_BI >= ISAKUSEIBI OR RASO.SHURYO_BI = 0) THEN

                   MJIDO_WORK(ICNT).CHOMEI := RASO.CHOMEI;
                   IF RASO.SHIMEI_KANJI IS NOT NULL THEN
                      MJIDO_WORK(ICNT).SHIMEI_KANJI := RASO.SHIMEI_KANJI;
                   ELSE
                      MJIDO_WORK(ICNT).SHIMEI_KANJI := RA.SHIMEI_KANJI;
                   END IF;
                   IF RASO.SHIMEI_KANA IS NOT NULL THEN
                      MJIDO_WORK(ICNT).SHIMEI_KANA := RASO.SHIMEI_KANA;
                   ELSE
                      MJIDO_WORK(ICNT).SHIMEI_KANA := RA.SHIMEI_KANA;
                   END IF;
                   MJIDO_WORK(ICNT).BANCHI := RASO.BANCHI;
                   MJIDO_WORK(ICNT).KATAGAKI := RASO.KATAGAKI;
                   MJIDO_WORK(ICNT).YUBIN_NO := RASO.YUBIN_NO;
                   MJIDO_WORK(ICNT).YUBIN_NOBC := RASO.YUBIN_NOBC;
                   VJUSHO_JODAN := SUBSTR (RASO.CHOMEI||RASO.BANCHI||RASO.KATAGAKI,1,100);
                   VJUSHO_GEDAN := SUBSTR (RASO.CHOMEI||RASO.BANCHI||RASO.KATAGAKI,101,200);

                   MJIDO_WORK(ICNT).YUHEN_KBN := RASO.YUHEN_KBN;      --郵返区分
                   MJIDO_WORK(ICNT).OAZA_CD := RASO.OAZA_CD;          --大字コード
                   MJIDO_WORK(ICNT).HONBAN := RASO.HONBAN;            --本番
                   MJIDO_WORK(ICNT).EDABAN1 := RASO.EDABAN1;          --枝１
                   MJIDO_WORK(ICNT).EDABAN2 := RASO.EDABAN2;          --枝２
                   MJIDO_WORK(ICNT).EDABAN3 := RASO.EDABAN3;          --枝３
                   MJIDO_WORK(ICNT).GAIKU := RASO.GAIKU;              --街区
                   MJIDO_WORK(ICNT).TOU := RASO.TOU;                  --棟
                   MJIDO_WORK(ICNT).GOU := RASO.GOU;                  --号
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
                   sJUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  RASO.CHOMEI , RASO.BANCHI , NULL, NULL);
                   MJIDO_WORK(ICNT).JUSHO := sJUSHO;                  --住所
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
              ELSE
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 STR
                   sJUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  RA.CHOMEI , RA.BANCHI , NULL, NULL);
                   MJIDO_WORK(ICNT).JUSHO := sJUSHO;                  --住所
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 END
                 --宛名情報がないときは成人者マスタを使用
                 MJIDO_WORK(ICNT).CHOMEI := CRS.CHOMEI;
                 MJIDO_WORK(ICNT).BANCHI := CRS.BANCHI;
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 STR
--               MJIDO_WORK(ICNT).KATAGAKI := CRS.KATAGAKI;
                 MJIDO_WORK(ICNT).KATAGAKI := RA.KATAGAKI;
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 END
--  2025/07/28 CTC.HJF UPDATE Start 1.0.010.002:GKB_QA18860対応
                 --MJIDO_WORK(ICNT).YUBIN_NO := CRS.YUBIN_NO;
                 MJIDO_WORK(ICNT).YUBIN_NO := RA.YUBIN_NO;
--  2025/07/28 CTC.HJF UPDATE END
                 --カスタマバーコードを取得する
                 MJIDO_WORK(ICNT).YUBIN_NOBC := GAAPK0010.FCUSTOM_BC(CRS.YUBIN_NO,
                                                              CRS.CHOMEI,
                                                              CRS.BANCHI,
                                                              CRS.KATAGAKI);
                 VJUSHO_JODAN := SUBSTR (CRS.CHOMEI||CRS.BANCHI||CRS.KATAGAKI,1,100);
                 VJUSHO_GEDAN := SUBSTR (CRS.CHOMEI||CRS.BANCHI||CRS.KATAGAKI,101,200);

                 --中学校区／小学校区
                 MJIDO_WORK(ICNT).CHUGAKOKU_CD := CRS.TYUGAKO_KU_CD;
                 BEGIN
                   SELECT TYUGAKOMEI
                     INTO VTYUGAKOMEI
                     FROM GKBTCHUGAKKO
                    WHERE TYUGAKO_CD = CRS.TYUGAKO_KU_CD;
                 EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     VTYUGAKOMEI := ' ';
                 END;
                 MJIDO_WORK(ICNT).CHUGAKOMEI   := VTYUGAKOMEI;
                 MJIDO_WORK(ICNT).SHOGAKOKU_CD := CRS.SHOGAKO_KU_CD;
                 BEGIN
                   SELECT SYOGAKOMEI
                     INTO VSHOGAKOMEI
                     FROM GKBTSHOGAKKO
                    WHERE SYOGAKO_CD = CRS.SHOGAKO_KU_CD;
                 EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     VSHOGAKOMEI := ' ';
                 END;
                 MJIDO_WORK(ICNT).SHOGAKOMEI   := VSHOGAKOMEI;

                 MJIDO_WORK(ICNT).YUHEN_KBN := 9;     --郵返区分
                 MJIDO_WORK(ICNT).OAZA_CD := 999999;  --大字コード
                 MJIDO_WORK(ICNT).HONBAN := '99999';    --本番
                 MJIDO_WORK(ICNT).EDABAN1 := '99999';   --枝１
                 MJIDO_WORK(ICNT).EDABAN2 := '99999';   --枝２
                 MJIDO_WORK(ICNT).EDABAN3 := '99999';   --枝３
                 MJIDO_WORK(ICNT).GAIKU := '99999';     --街区
                 MJIDO_WORK(ICNT).TOU := '99999';       --棟
                 MJIDO_WORK(ICNT).GOU := '99999';       --号
                 MJIDO_WORK(ICNT).GENZON_KBN := 9;    --現存区分
                 MJIDO_WORK(ICNT).KISAI_JUNI := 99;   --記載順位
                 MJIDO_WORK(ICNT).SANTEIDANTAI_CD := CRS.SANTEIDANTAI_CD;
                 IRTN := GAAPK0030.FJICHINAME(CRS.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);
                 MJIDO_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;
--  2024/07/01 ZCZL.GUANJINGHENG ADD 0.3.000.000:新WizLIFE２次開発
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 STR
--               MJIDO_WORK(ICNT).JUSHO := NULL;                  --住所
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 END
              END IF;
               END IF;
                   -- 「支援措置対象マスク」＝1(有)の場合
--  2024/09/29 ZCZL.YUCHUFEI UPDATE 0.3.000.004:仕様変更 IT_GKB_00074対応
--                    IF g_vJYOUKEN8 = 0 THEN
                   IF g_vJYOUKEN8 = 1 THEN
                         -- 2026/01/06 CTC.XW UPDATE START 1.0.452.000:GKB_QA24989対応
                         --vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', RASO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sJUSHO, nPRMCTL, 2);
                         IF RASO.KOJIN_NO is null THEN
                            vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', RA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sJUSHO, nPRMCTL, 2);
                         ELSE
                            vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', RASO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sJUSHO, nPRMCTL, 2);
                         END IF;
                         -- 2026/01/06 CTC.XW UPDATE END
                     
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 STR
                      ELSE
                        -- 2026/01/06 CTC.XW UPDATE START 1.0.452.000:GKB_QA24989対応
                         --vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', RA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sJUSHO, nPRMCTL, 2);
                         vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', RASO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sJUSHO, nPRMCTL, 2);
                      -- 2026/01/06 CTC.XW UPDATE END
                      END IF;
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 END
                         IF nPRMCTL = 1 THEN
                          MJIDO_WORK(ICNT).KATAGAKI := NULL;                         --方書
                          MJIDO_WORK(ICNT).JUSHO := vCHOMEI_BANCHI;                  --住所
                         END IF;
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
              MJIDO_WORK(ICNT).TSUCHIBUN := rSEIJIN.TSUCHIBUN;                  --通知文
              MJIDO_WORK(ICNT).TOIAWASESAKI := sTOIAWASESAKI1;                  --お問い合わせ先
              MJIDO_WORK(ICNT).TOIAWASE_JUSHO := sTOIAWASESAKI2;                --お問い合わせ先住所
              MJIDO_WORK(ICNT).TOIAWASE_TEL := sTOIAWASESAKI3;                  --お問い合わせ先電話番号
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
              MJIDO_WORK(ICNT).JUSHO_JODAN := VJUSHO_JODAN;
              MJIDO_WORK(ICNT).JUSHO_GEDAN:= VJUSHO_GEDAN;
              MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA := VSHIMEI_KANA;
              MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI:= VSHIMEI_KANJI;
              MJIDO_WORK(ICNT).NUSHI_KOJIN_NO := NNUSHIKOJINNO;

              BEGIN
                SELECT NVL(DATE1,0), NVL(DATE2,0), NVL(DATE3,0), NVL(DATE4,0), NVL(DATE5,0),
                       NVL(KOMOKU1,' '), NVL(KOMOKU2,' '), NVL(KOMOKU3,' '), NVL(KOMOKU4,' '), NVL(KOMOKU5,' '),
                       NVL(KOMOKU6,' '), NVL(KOMOKU7,' '), NVL(KOMOKU8,' '), NVL(KOMOKU9,' '), NVL(KOMOKU10,' ')
                  INTO IDATE1, IDATE2, IDATE3, IDATE4, IDATE5,
                       VKOMOKU1, VKOMOKU2, VKOMOKU3, VKOMOKU4, VKOMOKU5,
                       VKOMOKU6, VKOMOKU7, VKOMOKU8, VKOMOKU9, VKOMOKU10
                  FROM GKBTTSUCHISHOJKNSEIJIN
                 WHERE CHOHYO_KBN = c_CHOHYO_KBN
                   AND DANTAI_CD = MJIDO_WORK(ICNT).SANTEIDANTAI_CD;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  IDATE1 := 0;
                  IDATE2 := 0;
                  IDATE3 := 0;
                  IDATE4 := 0;
                  IDATE5 := 0;
                  VKOMOKU1 := ' ';
                  VKOMOKU2 := ' ';
                  VKOMOKU3 := ' ';
                  VKOMOKU4 := ' ';
                  VKOMOKU5 := ' ';
                  VKOMOKU6 := ' ';
                  VKOMOKU7 := ' ';
                  VKOMOKU8 := ' ';
                  VKOMOKU9 := ' ';
                  VKOMOKU10 := ' ';
              END;
              IF IDATE1 <> 0 THEN
                IWAREKI := 0;
                BRTN := KKAPK0020.FDAYEDIT( IWAREKI,
                                             IDATE1,
                                             VEDIT_GYYMMDD3,
                                             VEDIT_GYYMMDD2,
                                             VDATE1,
                                             VKJ_GENGO,
                                             VKG_GENGO,
                                             IWAREKI_YY,
                                             ISEIREKI_YYYY,
                                             IWAREKI_GYYMM,
                                             IMM,
                                             IDD,
                                             IOWAREKIHIZUKE,
                                             ISEIREKIHIZUKE );
              ELSE
                VDATE1 := ' ';
              END IF;
              IF IDATE2 <> 0 THEN
                IWAREKI := 0;
                BRTN := KKAPK0020.FDAYEDIT( IWAREKI,
                                             IDATE2,
                                             VEDIT_GYYMMDD3,
                                             VEDIT_GYYMMDD2,
                                             VDATE2,
                                             VKJ_GENGO,
                                             VKG_GENGO,
                                             IWAREKI_YY,
                                             ISEIREKI_YYYY,
                                             IWAREKI_GYYMM,
                                             IMM,
                                             IDD,
                                             IOWAREKIHIZUKE,
                                             ISEIREKIHIZUKE);
              ELSE
                VDATE2 := ' ';
              END IF;
              IF IDATE3 <> 0 THEN
                IWAREKI := 0;
                BRTN := KKAPK0020.FDAYEDIT( IWAREKI,
                                             IDATE3,
                                             VEDIT_GYYMMDD3,
                                             VEDIT_GYYMMDD2,
                                             VDATE3,
                                             VKJ_GENGO,
                                             VKG_GENGO,
                                             IWAREKI_YY,
                                             ISEIREKI_YYYY,
                                             IWAREKI_GYYMM,
                                             IMM,
                                             IDD,
                                             IOWAREKIHIZUKE,
                                             ISEIREKIHIZUKE);
              ELSE
                VDATE3 := ' ';
              END IF;
              IF IDATE4 <> 0 THEN
                IWAREKI := 0;
                BRTN := KKAPK0020.FDAYEDIT( IWAREKI,
                                             IDATE4,
                                             VEDIT_GYYMMDD3,
                                             VEDIT_GYYMMDD2,
                                             VDATE4,
                                             VKJ_GENGO,
                                             VKG_GENGO,
                                             IWAREKI_YY,
                                             ISEIREKI_YYYY,
                                             IWAREKI_GYYMM,
                                             IMM,
                                             IDD,
                                             IOWAREKIHIZUKE,
                                             ISEIREKIHIZUKE);
              ELSE
                VDATE4 := ' ';
              END IF;
              IF IDATE5 <> 0 THEN
                IWAREKI := 0;
                BRTN := KKAPK0020.FDAYEDIT( IWAREKI,
                                             IDATE5,
                                             VEDIT_GYYMMDD3,
                                             VEDIT_GYYMMDD2,
                                             VDATE5,
                                             VKJ_GENGO,
                                             VKG_GENGO,
                                             IWAREKI_YY,
                                             ISEIREKI_YYYY,
                                             IWAREKI_GYYMM,
                                             IMM,
                                             IDD,
                                             IOWAREKIHIZUKE,
                                             ISEIREKIHIZUKE);
              ELSE
                VDATE5 := ' ';
              END IF;
              MJIDO_WORK(ICNT).DATE1 := VDATE1;
              MJIDO_WORK(ICNT).DATE2 := VDATE2;
              MJIDO_WORK(ICNT).DATE3 := VDATE3;
              MJIDO_WORK(ICNT).DATE4 := VDATE4;
              MJIDO_WORK(ICNT).DATE5 := VDATE5;
              MJIDO_WORK(ICNT).KOMOKU1 := VKOMOKU1;
              MJIDO_WORK(ICNT).KOMOKU2 := VKOMOKU2;
              MJIDO_WORK(ICNT).KOMOKU3 := VKOMOKU3;
              MJIDO_WORK(ICNT).KOMOKU4 := VKOMOKU4;
              MJIDO_WORK(ICNT).KOMOKU5 := VKOMOKU5;
              MJIDO_WORK(ICNT).KOMOKU6 := VKOMOKU6;
              MJIDO_WORK(ICNT).KOMOKU7 := VKOMOKU7;
              MJIDO_WORK(ICNT).KOMOKU8 := VKOMOKU8;
              MJIDO_WORK(ICNT).KOMOKU9 := VKOMOKU9;
              MJIDO_WORK(ICNT).KOMOKU10 := VKOMOKU10;
              MJIDO_WORK(ICNT).SEIRI_NO := CRS.SEIRI_NO;  --整理番号
              MJIDO_WORK(ICNT).KOJIN_CD := CRS.KOJIN_CD;  --個人番号
             BEGIN
               SELECT NVL(KYOIKUIINKAI_CD,0)
                 INTO NKYOIKUIINKAI_CD
                 FROM GKBTCHUGAKKO A
                WHERE A.TYUGAKO_CD = MJIDO_WORK(ICNT).CHUGAKOKU_CD;
             EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                      NKYOIKUIINKAI_CD := NULL;
             END;
             IF NKYOIKUIINKAI_CD IS NOT NULL THEN
                IRTN_KYOIKUKAI := KKAPK0030.FPRMSHUTOKU(g_sGYOUMUCODE,'00KYOIKUKAI',NKYOIKUIINKAI_CD,ACONSPRM,NLENGTH);
                IF IRTN_KYOIKUKAI = 1 THEN
                   ACONSPRM := A_CONS_PRM();
                   ACONSPRM.EXTEND;
                   ACONSPRM.EXTEND;
                   ACONSPRM(1) := ' ';
                   ACONSPRM.EXTEND;
                   ACONSPRM(2) := ' ';
                   ACONSPRM.EXTEND;
                   ACONSPRM(3) := ' ';
                   ACONSPRM.EXTEND;
                   ACONSPRM(4) := ' ';
                   ACONSPRM.EXTEND;
                   ACONSPRM(5) := ' ';
                   ACONSPRM.EXTEND;
                   ACONSPRM(6) := ' ';
                   ACONSPRM.EXTEND;
                   ACONSPRM(7) := ' ';
                   ACONSPRM.EXTEND;
                   ACONSPRM(8) := ' ';
                ELSE
                   WHILE (NLENGTH < 8) LOOP
                     ACONSPRM.EXTEND;
                     ACONSPRM(NLENGTH+1) := ' ';
                     NLENGTH := NLENGTH + 1;
                   END LOOP;
                END IF;
                MJIDO_WORK(ICNT).KYOIKUKAI_MEI           := ACONSPRM(1);         --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(１)
                MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI    := ACONSPRM(2);         --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(２)
                MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI      := ACONSPRM(3);         --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(３)
                MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI        := ACONSPRM(4);         --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(４)
                MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO         := ACONSPRM(5);         --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(５)
                MJIDO_WORK(ICNT).KYOIKU_JUSHO            := ACONSPRM(6);         --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(６)
                MJIDO_WORK(ICNT).KYOIKU_TEL              := ACONSPRM(7);         --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(７)
                MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN       := ACONSPRM(8);         --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(８)
             ELSE
                MJIDO_WORK(ICNT).KYOIKUKAI_MEI           := ' ';                 --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(１)
                MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI    := ' ';                 --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(２)
                MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI      := ' ';                 --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(３)
                MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI        := ' ';                 --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(４)
                MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO         := ' ';                 --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(５)
                MJIDO_WORK(ICNT).KYOIKU_JUSHO            := ' ';                 --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(６)
                MJIDO_WORK(ICNT).KYOIKU_TEL              := ' ';                 --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(７)
                MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN       := ' ';                 --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(８)
             END IF;
             IRTN := GAAPK0030.FGETATENA(CRS.KOJIN_CD, g_sGYOUMUCODE, TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), o_RATENA_REC, o_RSOFU_REC);
             MJIDO_WORK(ICNT).JINKAKU_KBN := o_RATENA_REC.JINKAKU_KBN;

             ICNT := ICNT + 1;             -- カウントアップ
             IFRET := c_ISUCCESS;          -- 正常終了

           END LOOP;
         EXCEPTION
           WHEN OTHERS THEN
             IFRET := c_INOT_SUCCESS;      -- 異常終了
             -- 処理ログの出力
             B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, '成人者マスタ作成処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
         END;

         -- 終了
         RETURN IFRET;
    EXCEPTION
        -- その他エラー
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, '成人者マスタ作成処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_GET_JIDO_WK;

    --------------------------------------------------------------------------------
    -- 成人者ワーク（GKBWSEIJINSHA）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_INSERT_JIDO_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- 戻り値
        IMAX                BINARY_INTEGER;             -- 戻り値
        IMIN                BINARY_INTEGER;             -- 戻り値
    BEGIN
        IFRET := c_ISUCCESS;                            -- 正常終了
        -- ワーク領域の最終位置を取得
        IMAX := MJIDO_WORK.LAST;
        -- ワーク領域の先頭位置を取得
        IMIN := MJIDO_WORK.FIRST;

        BEGIN
            -- ワーク領域の件数分繰り返し処理を行う
            FOR ICNT IN IMIN..IMAX LOOP
                INSERT INTO
                GKBWSEIJINSHA
                (
                 NENDO,
                 KAIPEJI_CD,
                 KAIPEJI,
                 GYOSEIKU_CD,
                 GYOSEIKUMEI,
                 HAN_CD,
                 HANMEI,
                 SANTEIDANTAI_CD,
                 SANTEIDANTAIMEI,
                 SHIMEI_KANA,
                 SEINENGAPI,
                 HYOJI_SEINENGAPI,
                 SEIBETSU,
                 HYOJI_SEIBETSU,
                 SETAI_NO,
                 SAKUSEIBI,
                 RENBAN,
                 SHIMEI_KANJI,
                 ZOKUGARAMEI,
                 CHOMEI,
                 BANCHI,
                 KATAGAKI,
                 JUSHO_JODAN,
                 JUSHO_GEDAN,
                 NUSI_SHIMEI_KANA,
                 NUSI_SHIMEI_KANJI,
                 YUBIN_NO,
                 DATE1,
                 DATE2,
                 DATE3,
                 DATE4,
                 DATE5,
                 KOMOKU1,
                 KOMOKU2,
                 KOMOKU3,
                 KOMOKU4,
                 KOMOKU5,
                 KOMOKU6,
                 KOMOKU7,
                 KOMOKU8,
                 KOMOKU9,
                 KOMOKU10
                ,CHUGAKOKU_CD
                ,CHUGAKOMEI
                ,SHOGAKOKU_CD
                ,SHOGAKOMEI
                ,SEIRI_NO
                ,KOJIN_CD
                ,YUHEN_KBN
                ,OAZA_CD
                ,HONBAN
                ,EDABAN1
                ,EDABAN2
                ,EDABAN3
                ,GAIKU
                ,TOU
                ,GOU
                ,GENZON_KBN
                ,KISAI_JUNI
                ,YUBIN_NOBC
                ,NUSHI_KOJIN_NO
                ,KYOIKUKAI_MEI
                ,KYOIKU_YAKUSHOKU_MEI
                ,KYOIKU_SHUTHOU_MEI
                ,KYOIKU_RITSU_MEI
                ,KYOIKU_YUBIN_NO
                ,KYOIKU_JUSHO
                ,KYOIKU_TEL
                ,KYOIKU_TEL_NAISEN
                ,JINKAKU_KBN
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
                ,JUSHO
                ,TSUCHIBUN
                ,TOIAWASESAKI
                ,TOIAWASE_JUSHO
                ,TOIAWASE_TEL
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
                )
                VALUES
                (
                 MJIDO_WORK(ICNT).NENDO,
                 MJIDO_WORK(ICNT).KAIPEJI_CD,
                 MJIDO_WORK(ICNT).KAIPEJI,
                 MJIDO_WORK(ICNT).GYOSEIKU_CD,
                 MJIDO_WORK(ICNT).GYOSEIKUMEI,
                 MJIDO_WORK(ICNT).HAN_CD,
                 MJIDO_WORK(ICNT).HANMEI,
                 MJIDO_WORK(ICNT).SANTEIDANTAI_CD,
                 MJIDO_WORK(ICNT).SANTEIDANTAIMEI,
                 MJIDO_WORK(ICNT).SHIMEI_KANA,
                 MJIDO_WORK(ICNT).SEINENGAPI,
                 MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,
                 MJIDO_WORK(ICNT).SEIBETSU,
                 MJIDO_WORK(ICNT).HYOJI_SEIBETSU,
                 MJIDO_WORK(ICNT).SETAI_NO,
                 MJIDO_WORK(ICNT).SAKUSEIBI,
                 MJIDO_WORK(ICNT).RENBAN,
                 MJIDO_WORK(ICNT).SHIMEI_KANJI,
                 MJIDO_WORK(ICNT).ZOKUGARAMEI,
                 MJIDO_WORK(ICNT).CHOMEI,
                 MJIDO_WORK(ICNT).BANCHI,
                 MJIDO_WORK(ICNT).KATAGAKI,
                 MJIDO_WORK(ICNT).JUSHO_JODAN,
                 MJIDO_WORK(ICNT).JUSHO_GEDAN,
                 MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA,
                 MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI,
                 MJIDO_WORK(ICNT).YUBIN_NO,
                 MJIDO_WORK(ICNT).DATE1,
                 MJIDO_WORK(ICNT).DATE2,
                 MJIDO_WORK(ICNT).DATE3,
                 MJIDO_WORK(ICNT).DATE4,
                 MJIDO_WORK(ICNT).DATE5,
                 MJIDO_WORK(ICNT).KOMOKU1,
                 MJIDO_WORK(ICNT).KOMOKU2,
                 MJIDO_WORK(ICNT).KOMOKU3,
                 MJIDO_WORK(ICNT).KOMOKU4,
                 MJIDO_WORK(ICNT).KOMOKU5,
                 MJIDO_WORK(ICNT).KOMOKU6,
                 MJIDO_WORK(ICNT).KOMOKU7,
                 MJIDO_WORK(ICNT).KOMOKU8,
                 MJIDO_WORK(ICNT).KOMOKU9,
                 MJIDO_WORK(ICNT).KOMOKU10
                ,MJIDO_WORK(ICNT).CHUGAKOKU_CD
                ,MJIDO_WORK(ICNT).CHUGAKOMEI
                ,MJIDO_WORK(ICNT).SHOGAKOKU_CD
                ,MJIDO_WORK(ICNT).SHOGAKOMEI
                ,MJIDO_WORK(ICNT).SEIRI_NO
                ,MJIDO_WORK(ICNT).KOJIN_CD
                ,MJIDO_WORK(ICNT).YUHEN_KBN
                ,MJIDO_WORK(ICNT).OAZA_CD
                ,MJIDO_WORK(ICNT).HONBAN
                ,MJIDO_WORK(ICNT).EDABAN1
                ,MJIDO_WORK(ICNT).EDABAN2
                ,MJIDO_WORK(ICNT).EDABAN3
                ,MJIDO_WORK(ICNT).GAIKU
                ,MJIDO_WORK(ICNT).TOU
                ,MJIDO_WORK(ICNT).GOU
                ,MJIDO_WORK(ICNT).GENZON_KBN
                ,MJIDO_WORK(ICNT).KISAI_JUNI
                ,MJIDO_WORK(ICNT).YUBIN_NOBC
                ,MJIDO_WORK(ICNT).NUSHI_KOJIN_NO
                ,MJIDO_WORK(ICNT).KYOIKUKAI_MEI
                ,MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI
                ,MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI
                ,MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI
                ,MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO
                ,MJIDO_WORK(ICNT).KYOIKU_JUSHO
                ,MJIDO_WORK(ICNT).KYOIKU_TEL
                ,MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN
                ,MJIDO_WORK(ICNT).JINKAKU_KBN
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
                ,MJIDO_WORK(ICNT).JUSHO
                ,MJIDO_WORK(ICNT).TSUCHIBUN
                ,MJIDO_WORK(ICNT).TOIAWASESAKI
                ,MJIDO_WORK(ICNT).TOIAWASE_JUSHO
                ,MJIDO_WORK(ICNT).TOIAWASE_TEL
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
               );
            END LOOP;
            COMMIT;

            NKENSU := GKBPK00010.FTCOUNT('GKBWSEIJINSHA',NULL);
            g_nINDEX := g_nINDEX + 1;
            g_oKENSU_LIST.EXTEND(1);
            g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NKENSU,'入力　対象者件数',1);

        EXCEPTION
          WHEN OTHERS THEN
            ROLLBACK;                 -- 処理前に戻す
            IFRET := c_INOT_SUCCESS;  -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
    -- その他エラー
        WHEN OTHERS THEN
            ROLLBACK;                 -- 処理前に戻す
            IFRET := c_INOT_SUCCESS;  -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 成人式中間データ作成（ＣＳＶ用）
    --------------------------------------------------------------------------------
    FUNCTION FUNCGET_JIDO_WK_CSV RETURN NUMBER IS
        IFRET               PLS_INTEGER;                   -- 戻り値
        ICNT                BINARY_INTEGER;                -- カウント
        VSQLSEL             NVARCHAR2(10000);              -- ＳＱＬ文
        ICUR                PLS_INTEGER;                   -- カーソル
        RREC                GKBWSEIJINSHA%ROWTYPE;         -- 成人式中間のレコード変数
        NROWS               NUMBER;                        --
        IPAGECNT            PLS_INTEGER;                   -- 頁数
        IGYOCNT             PLS_INTEGER;                   -- 行番号
        IGYORENBAN          PLS_INTEGER;                   -- 行連番
        VPAGENAME           NVARCHAR2(500);               -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(500);               -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(500);               -- 改頁項目値のワーク

    BEGIN
        IFRET := c_ISUCCESS;                          -- 正常終了
        VPAGEWORK := '';
        IPAGECNT := 0;
        IGYOCNT := 0;
        ICNT := 0;
        IGYORENBAN := 0;
        MJIDO_WORK.DELETE;                            -- ワーク領域の初期化
        --改頁
        VPAGENM := ' GYOSEIKUMEI ';
        VPAGEFD := ' GYOSEIKU_CD ';

        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'NENDO, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || 'HAN_CD, ';
            VSQLSEL := VSQLSEL || 'HANMEI, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAIMEI, ';
            VSQLSEL := VSQLSEL || 'SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
            VSQLSEL := VSQLSEL || 'RENBAN, ';
            VSQLSEL := VSQLSEL || 'SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI, ';
            VSQLSEL := VSQLSEL || 'CHOMEI, ';
            VSQLSEL := VSQLSEL || 'BANCHI, ';
            VSQLSEL := VSQLSEL || 'KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'JUSHO_JODAN, ';
            VSQLSEL := VSQLSEL || 'JUSHO_GEDAN, ';
            VSQLSEL := VSQLSEL || 'NUSI_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'NUSI_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'DATE1, ';
            VSQLSEL := VSQLSEL || 'DATE2, ';
            VSQLSEL := VSQLSEL || 'DATE3, ';
            VSQLSEL := VSQLSEL || 'DATE4, ';
            VSQLSEL := VSQLSEL || 'DATE5, ';
            VSQLSEL := VSQLSEL || 'KOMOKU1, ';
            VSQLSEL := VSQLSEL || 'KOMOKU2, ';
            VSQLSEL := VSQLSEL || 'KOMOKU3, ';
            VSQLSEL := VSQLSEL || 'KOMOKU4, ';
            VSQLSEL := VSQLSEL || 'KOMOKU5, ';
            VSQLSEL := VSQLSEL || 'KOMOKU6, ';
            VSQLSEL := VSQLSEL || 'KOMOKU7, ';
            VSQLSEL := VSQLSEL || 'KOMOKU8, ';
            VSQLSEL := VSQLSEL || 'KOMOKU9, ';
            VSQLSEL := VSQLSEL || 'KOMOKU10, ';
            VSQLSEL := VSQLSEL || VPAGENM || 'PAGE_NAME, ';            -- 改頁名を設定
            VSQLSEL := VSQLSEL || VPAGEFD || 'PAGE_FIELD ';            -- 改頁値を設定
            VSQLSEL := VSQLSEL || ', ';
            VSQLSEL := VSQLSEL || 'CHUGAKOKU_CD, ';
            VSQLSEL := VSQLSEL || 'CHUGAKOMEI, ';
            VSQLSEL := VSQLSEL || 'SHOGAKOKU_CD, ';
            VSQLSEL := VSQLSEL || 'SHOGAKOMEI, ';
            VSQLSEL := VSQLSEL || 'SEIRI_NO, ';
            VSQLSEL := VSQLSEL || 'KOJIN_CD  ';
            VSQLSEL := VSQLSEL || ', ';
            VSQLSEL := VSQLSEL || 'YUBIN_NOBC ';
            VSQLSEL := VSQLSEL || ', ';
            VSQLSEL := VSQLSEL || 'NUSHI_KOJIN_NO ';
            VSQLSEL := VSQLSEL || ', ';
            VSQLSEL := VSQLSEL || 'KYOIKUKAI_MEI, ';
            VSQLSEL := VSQLSEL || 'KYOIKU_YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'KYOIKU_JUSHO, ';
            VSQLSEL := VSQLSEL || 'KYOIKU_TEL ';
            VSQLSEL := VSQLSEL || ',KYOIKU_SHUTHOU_MEI ';
            VSQLSEL := VSQLSEL || ',JINKAKU_KBN ';
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
            VSQLSEL := VSQLSEL || ',JUSHO ';
            VSQLSEL := VSQLSEL || ',TSUCHIBUN ';
            VSQLSEL := VSQLSEL || ',TOIAWASESAKI ';
            VSQLSEL := VSQLSEL || ',TOIAWASE_JUSHO ';
            VSQLSEL := VSQLSEL || ',TOIAWASE_TEL ';
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
-- 2025/07/16 CTC.Wang Add Start 1.0.100.000:新WizLIFE開発_帳票アウトソーシング連番対応
            VSQLSEL := VSQLSEL || ',YUHEN_KBN ';
-- 2025/07/16 CTC.Wang Add End
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWSEIJINSHA ';

            -- ひとつのＳＱＬ文にする
            IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
                VSQLSEL := VSQLSEL || ' ORDER BY ' || g_rJSTP.ORDERBYCLAUSE;
            END IF;
            -- カーソルのオープン
            ICUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(ICUR, VSQLSEL, DBMS_SQL.NATIVE);

            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(ICUR,  1, RREC.NENDO, 10);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  2, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  3, RREC.KAIPEJI, 500);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  4, RREC.GYOSEIKU_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  5, RREC.GYOSEIKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  6, RREC.HAN_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  7, RREC.HANMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  8, RREC.SANTEIDANTAI_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  9, RREC.SANTEIDANTAIMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 10, RREC.SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 11, RREC.SEINENGAPI);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 12, RREC.HYOJI_SEINENGAPI, 11);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 13, RREC.SEIBETSU);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 14, RREC.HYOJI_SEIBETSU, 2);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 15, RREC.SETAI_NO);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 16, RREC.SAKUSEIBI, 30);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 17, RREC.RENBAN);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 18, RREC.SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 19, RREC.ZOKUGARAMEI, 30);
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 20, RREC.CHOMEI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 21, RREC.BANCHI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 22, RREC.KATAGAKI, 60);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 20, RREC.CHOMEI, 136);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 21, RREC.BANCHI, 50);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 22, RREC.KATAGAKI, 300);
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
            DBMS_SQL.DEFINE_COLUMN(ICUR, 23, RREC.JUSHO_JODAN, 30);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 24, RREC.JUSHO_GEDAN, 30);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 25, RREC.NUSI_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 26, RREC.NUSI_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 27, RREC.YUBIN_NO, 10);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 28, RREC.DATE1, 11);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 29, RREC.DATE2, 11);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 30, RREC.DATE3, 11);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 31, RREC.DATE4, 11);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 32, RREC.DATE5, 11);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 33, RREC.KOMOKU1, 120);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 34, RREC.KOMOKU2, 120);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 35, RREC.KOMOKU3, 120);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 36, RREC.KOMOKU4, 120);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 37, RREC.KOMOKU5, 120);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 38, RREC.KOMOKU6, 120);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 39, RREC.KOMOKU7, 120);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 40, RREC.KOMOKU8, 120);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 41, RREC.KOMOKU9, 120);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 42, RREC.KOMOKU10, 120);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 43, VPAGENM,500 );
            DBMS_SQL.DEFINE_COLUMN(ICUR, 44, VPAGEFD,500 );
            DBMS_SQL.DEFINE_COLUMN(ICUR, 45, RREC.CHUGAKOKU_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 46, RREC.CHUGAKOMEI,30);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 47, RREC.SHOGAKOKU_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 48, RREC.SHOGAKOMEI,30);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 49, RREC.SEIRI_NO);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 50, RREC.KOJIN_CD);
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応          
            --DBMS_SQL.DEFINE_COLUMN(ICUR, 51, RREC.YUBIN_NOBC,30);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 51, RREC.YUBIN_NOBC,100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 52, RREC.NUSHI_KOJIN_NO);
            /*DBMS_SQL.DEFINE_COLUMN(ICUR, 53, RREC.KYOIKUKAI_MEI,60);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 54, RREC.KYOIKU_YUBIN_NO,10);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 55, RREC.KYOIKU_JUSHO,100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 56, RREC.KYOIKU_TEL,20);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 57, RREC.KYOIKU_SHUTHOU_MEI,60);*/
            DBMS_SQL.DEFINE_COLUMN(ICUR, 53, RREC.KYOIKUKAI_MEI,150);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 54, RREC.KYOIKU_YUBIN_NO,150);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 55, RREC.KYOIKU_JUSHO,250);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 56, RREC.KYOIKU_TEL,150);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 57, RREC.KYOIKU_SHUTHOU_MEI,150);
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
            DBMS_SQL.DEFINE_COLUMN(ICUR, 58, RREC.JINKAKU_KBN);
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
            DBMS_SQL.DEFINE_COLUMN(ICUR, 59, RREC.JUSHO,100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 60, RREC.TSUCHIBUN,300);
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
            /*DBMS_SQL.DEFINE_COLUMN(ICUR, 61, RREC.TOIAWASESAKI,45);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 62, RREC.TOIAWASE_JUSHO,45);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 63, RREC.TOIAWASE_TEL,45);*/
            DBMS_SQL.DEFINE_COLUMN(ICUR, 61, RREC.TOIAWASESAKI,150);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 62, RREC.TOIAWASE_JUSHO,150);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 63, RREC.TOIAWASE_TEL,150);
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
-- 2025/07/16 CTC.Wang Add Start 1.0.100.000:新WizLIFE開発_帳票アウトソーシング連番対応
            DBMS_SQL.DEFINE_COLUMN(ICUR, 64, RREC.YUHEN_KBN);
-- 2025/07/16 CTC.Wang Add End
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(ICUR);
            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(ICUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(ICUR,  1, MJIDO_WORK(ICNT).NENDO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  2, MJIDO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  3, MJIDO_WORK(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  4, MJIDO_WORK(ICNT).GYOSEIKU_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  5, MJIDO_WORK(ICNT).GYOSEIKUMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  6, MJIDO_WORK(ICNT).HAN_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  7, MJIDO_WORK(ICNT).HANMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  8, MJIDO_WORK(ICNT).SANTEIDANTAI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  9, MJIDO_WORK(ICNT).SANTEIDANTAIMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 10, MJIDO_WORK(ICNT).SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 11, MJIDO_WORK(ICNT).SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 12, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 13, MJIDO_WORK(ICNT).SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 14, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 15, MJIDO_WORK(ICNT).SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 16, MJIDO_WORK(ICNT).SAKUSEIBI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 17, MJIDO_WORK(ICNT).RENBAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 18, MJIDO_WORK(ICNT).SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 19, MJIDO_WORK(ICNT).ZOKUGARAMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 20, MJIDO_WORK(ICNT).CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 21, MJIDO_WORK(ICNT).BANCHI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 22, MJIDO_WORK(ICNT).KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 23, MJIDO_WORK(ICNT).JUSHO_JODAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 24, MJIDO_WORK(ICNT).JUSHO_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 25, MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 26, MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 27, MJIDO_WORK(ICNT).YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 28, MJIDO_WORK(ICNT).DATE1);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 29, MJIDO_WORK(ICNT).DATE2);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 30, MJIDO_WORK(ICNT).DATE3);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 31, MJIDO_WORK(ICNT).DATE4);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 32, MJIDO_WORK(ICNT).DATE5);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 33, MJIDO_WORK(ICNT).KOMOKU1);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 34, MJIDO_WORK(ICNT).KOMOKU2);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 35, MJIDO_WORK(ICNT).KOMOKU3);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 36, MJIDO_WORK(ICNT).KOMOKU4);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 37, MJIDO_WORK(ICNT).KOMOKU5);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 38, MJIDO_WORK(ICNT).KOMOKU6);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 39, MJIDO_WORK(ICNT).KOMOKU7);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 40, MJIDO_WORK(ICNT).KOMOKU8);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 41, MJIDO_WORK(ICNT).KOMOKU9);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 42, MJIDO_WORK(ICNT).KOMOKU10);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 43, VPAGENAME);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 44, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 45, MJIDO_WORK(ICNT).CHUGAKOKU_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 46, MJIDO_WORK(ICNT).CHUGAKOMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 47, MJIDO_WORK(ICNT).SHOGAKOKU_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 48, MJIDO_WORK(ICNT).SHOGAKOMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 49, MJIDO_WORK(ICNT).SEIRI_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 50, MJIDO_WORK(ICNT).KOJIN_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 51, MJIDO_WORK(ICNT).YUBIN_NOBC);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 52, MJIDO_WORK(ICNT).NUSHI_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 53, MJIDO_WORK(ICNT).KYOIKUKAI_MEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 54, MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 55, MJIDO_WORK(ICNT).KYOIKU_JUSHO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 56, MJIDO_WORK(ICNT).KYOIKU_TEL);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 57, MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 58, MJIDO_WORK(ICNT).JINKAKU_KBN);
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
                    DBMS_SQL.COLUMN_VALUE(ICUR, 59, MJIDO_WORK(ICNT).JUSHO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 60, MJIDO_WORK(ICNT).TSUCHIBUN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 61, MJIDO_WORK(ICNT).TOIAWASESAKI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 62, MJIDO_WORK(ICNT).TOIAWASE_JUSHO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 63, MJIDO_WORK(ICNT).TOIAWASE_TEL);
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
-- 2025/07/16 CTC.Wang Add Start 1.0.100.000:新WizLIFE開発_帳票アウトソーシング連番対応
                    DBMS_SQL.COLUMN_VALUE(ICUR, 64, MJIDO_WORK(ICNT).YUHEN_KBN);
-- 2025/07/16 CTC.Wang Add End

                    -- 改頁の指定がある場合
                    IF NVL(VPAGEWORK,' ') = NVL(VPAGENAME,' ') THEN
                    -- 以前の改頁項目名と同じ
                        IGYOCNT := IGYOCNT + 1;
                        IGYORENBAN := IGYORENBAN + 1;

                        IF IGYOCNT > c_IMAXROWS THEN
                        -- １頁内の最大行数を超えた
                            IPAGECNT := IPAGECNT + 1;
                            IGYOCNT := 1;
                            VPAGEWORK := VPAGENAME;
                        END IF;
                    ELSE
                    -- 改頁必要
                        IPAGECNT := IPAGECNT + 1;
                        IGYOCNT := 1;
                        IGYORENBAN := 1;
                        VPAGEWORK := VPAGENAME;
                    END IF;
                    -- 再セットする項目
                    MJIDO_WORK(ICNT).RENBAN := IGYORENBAN;    -- 連番
                    MJIDO_WORK(ICNT).KAIPEJI := VPAGENAME;    -- 改頁名
                    MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEWORK; -- 改頁コード

                ELSE
                    -- 全件読み込み終了
                    EXIT;
                END IF;
                ICNT := ICNT + 1;
            END LOOP;

            DBMS_SQL.CLOSE_CURSOR(ICUR);
        EXCEPTION
            WHEN OTHERS THEN
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCGET_JIDO_WK_CSV;
    --------------------------------------------------------------------------------------------------
    -- 成人式案内状ＣＳＶファイル作成
    --------------------------------------------------------------------------------------------------
    FUNCTION FUNCSET_JIDO_WK_CSVFILE1 RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 STR
        nRTN                NUMBER;
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 END
        ICNT                PLS_INTEGER;                -- カウント
        IMAX                PLS_INTEGER;                -- 最大値（出力件数）
        IMIN                PLS_INTEGER;                -- 最小値（出力件数）
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
        --VKYOIKU_CHO         NVARCHAR2(30);              -- 教育長名
        VKYOIKU_CHO         NVARCHAR2(150);              -- 教育長名
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
        VYUBIN_NO           NVARCHAR2(60);              -- 郵便番号編集用
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
        --VKYOIKUYUBINNO      NVARCHAR2(60);              -- 教育郵便番号編集用
        VKYOIKUYUBINNO      NVARCHAR2(150);              -- 教育郵便番号編集用
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
        ICNT_1              BINARY_INTEGER := 0;        -- カウント
        r_WKRECORD001       GKBWL400R001%ROWTYPE;
        nROWNO              NUMBER := 0;
        TACONSPRM           A_CONS_PRM;       --戻るパラメータ配列
        NLENGTH             NUMBER;           --配列件数
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
        IRTN                PLS_INTEGER;                -- 呼出関数の戻り値
        nPRMCTL             NUMBER;
        sSHIMEI_KANJI       NVARCHAR2(1000);            -- 氏名漢字
        vCHOMEI_BANCHI      NVARCHAR2(1000);            -- 住所マスク文字列
        nKENSAKU            NUMBER;                     -- 出力件数
        nMAEMOJILEN         NUMBER;
        nUSHIROMOJILEN      NUMBER;
        nNUMLENGTH          NUMBER;
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
    BEGIN

        IFRET := c_ISUCCESS;                -- 正常終了

        -- 収発名を取得する
        BEGIN
          SELECT SHUHATS_MEI
            INTO VSYUHATU_MEI
            FROM GKBTTSUCHISHOKANRISEIJIN
           WHERE CHOHYO_KBN = c_CHOHYO_KBN;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
               VSYUHATU_MEI := '';
        END;

        -- システム条件テーブル、教育委員会の電話番号・郵便番号・住所・教育長名を取得します
        BEGIN
            IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      5,          --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
            IF NLENGTH <> 0 THEN
            --レコードが取得できた場合
              VKYOIKU_CHO := TACONSPRM(1);
            ELSE
            --レコードが取得できない場合
              VKYOIKU_CHO := '';
            END IF;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
               VKYOIKU_CHO := '';

        END;

        IMAX := MJIDO_WORK.LAST;           -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;          -- ワーク領域の件数の最小値

        -- 取得した件数分繰り返す
        FOR ICNT IN IMIN..IMAX LOOP
            ICNT_1 := ICNT_1 + 1;
            nROWNO := nROWNO + 1;
            r_WKRECORD001 := NULL;
-- 2025/07/16 CTC.Wang Add Start 1.0.100.000:新WizLIFE開発_帳票アウトソーシング連番対応
            r_WKRECORD001.KYOTSU_TSUSU_RENBAN           := LPAD(nROWNO, 6, '0');                                 -- 業務共通_通数連番
            r_WKRECORD001.KYOTSU_PAGE_RENBAN            := NULL;                                                 -- 業務共通_頁連番
            r_WKRECORD001.KYOTSU_DOFU_RENBAN            := NULL;                                                 -- 業務共通_同封内連番
            r_WKRECORD001.KYOTSU_DOFU_MAISU             := NULL;                                                 -- 業務共通_同封内枚数
            r_WKRECORD001.KYOTSU_YUBIN_K_KBN            := NULL;                                                 -- 業務共通_郵便局区分
            r_WKRECORD001.KYOTSU_YUHEN_KBN              := MJIDO_WORK(ICNT).YUHEN_KBN;                           -- 業務共通_郵返区分
            r_WKRECORD001.KYOTSU_CHOSHU_KBN             := NULL;                                                 -- 業務共通_徴収区分
            r_WKRECORD001.KYOTSU_GAKKO_KBN              := NULL;                                                 -- 業務共通_学校区分
            r_WKRECORD001.KYOTSU_YOBI_AREA1             := NULL;                                                 -- 業務共通_予備エリア1
            r_WKRECORD001.KYOTSU_YOBI_AREA2             := NULL;                                                 -- 業務共通_予備エリア2
            r_WKRECORD001.KYOTSU_YOBI_AREA3             := NULL;                                                 -- 業務共通_予備エリア3
            r_WKRECORD001.KYOTSU_YOBI_AREA4             := NULL;                                                 -- 業務共通_予備エリア4
            r_WKRECORD001.KYOTSU_YOBI_AREA5             := NULL;                                                 -- 業務共通_予備エリア5
            r_WKRECORD001.KYOTSU_YOBI_AREA6             := NULL;                                                 -- 業務共通_予備エリア6
            r_WKRECORD001.KYOTSU_YOBI_AREA7             := NULL;                                                 -- 業務共通_予備エリア7
            r_WKRECORD001.KYOTSU_YOBI_AREA8             := NULL;                                                 -- 業務共通_予備エリア8
            r_WKRECORD001.KYOTSU_YOBI_AREA9             := NULL;                                                 -- 業務共通_予備エリア9
            r_WKRECORD001.KYOTSU_YOBI_AREA10            := NULL;                                                 -- 業務共通_予備エリア10
            r_WKRECORD001.KYOTSU_YOBI_AREA11            := NULL;                                                 -- 業務共通_予備エリア11
            r_WKRECORD001.KYOTSU_YOBI_AREA12            := NULL;                                                 -- 業務共通_予備エリア12
-- 2025/07/16 CTC.Wang Add End
            r_WKRECORD001.NO := nROWNO;                                                                          --ソート順
            r_WKRECORD001.NENDO                         := MJIDO_WORK(ICNT).NENDO||'年度';                       --年度
            r_WKRECORD001.KAIPAGE_CD                    := MJIDO_WORK(ICNT).KAIPEJI_CD;                          --改頁コード
            r_WKRECORD001.KAIPAGE_MEI                   := MJIDO_WORK(ICNT).KAIPEJI;                             --改頁名
            r_WKRECORD001.GYOSEIKU_MEI                  := MJIDO_WORK(ICNT).GYOSEIKUMEI;                         --行政区名
            r_WKRECORD001.SANTEIDANTAI_MEI              := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;                     --算定団体名
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発
--            r_WKRECORD001.SHIMEI_KANA                   := MJIDO_WORK(ICNT).SHIMEI_KANA;                         --氏名かな
--            r_WKRECORD001.SEINENGAPI                    := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;                    --生年月日
            -- 成人者の個人番号より宛名情報取得
            IRTN := GAAPK0030.FGETATENA(MJIDO_WORK(ICNT).KOJIN_CD,
                                      'GKB',
                                      ISAKUSEIBI,
                                      RA,
                                      RASO);
            IF MJIDO_WORK(ICNT).KOJIN_CD IS NOT NULL THEN
                IF RASO.SHIMEI_KANA IS NOT NULL THEN
                  r_WKRECORD001.SHIMEI_KANA              := RASO.SHIMEI_KANA;                                    --氏名かな
                ELSE
                  r_WKRECORD001.SHIMEI_KANA              := RA.SHIMEI_KANA;                                      --氏名かな
                END IF;
                IF MJIDO_WORK(ICNT).JINKAKU_KBN <> 1 THEN
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.007:IT_GKB_00286横展開対応
--                  r_WKRECORD001.SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(RA.SEINENGAPI,'YYYY/MM/DD'),'YYYY/MM/DD'),1);        --生年月日
                  GKAPK00020.FGETSEINENGHYOUJI(RA.SEINENGAPI,o_sEINENGAPI1);
                  r_WKRECORD001.SEINENGAPI := o_sEINENGAPI1.o_vEDIT_GYYMMDD3;        --生年月日
                ELSE
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.007:IT_GKB_00286横展開対応
--                  r_WKRECORD001.SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(RA.SEINENGAPI,'YYYY/MM/DD'),'YYYY/MM/DD'),6);        --生年月日
                  GKAPK00020.FGETSEINENGHYOUJI(RA.SEINENGAPI,o_sEINENGAPI1);
                  r_WKRECORD001.SEINENGAPI := o_sEINENGAPI1.o_vSEINEN_UMIGAI;        --生年月日
                END IF;
            ELSE
                r_WKRECORD001.SHIMEI_KANA                  := MJIDO_WORK(ICNT).SHIMEI_KANA;                       --氏名かな
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.007:IT_GKB_00286横展開対応
--                r_WKRECORD001.SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(MJIDO_WORK(ICNT).SEINENGAPI,'YYYY/MM/DD'),'YYYY/MM/DD'),1);    --生年月日
                GKAPK00020.FGETSEINENGHYOUJI(MJIDO_WORK(ICNT).SEINENGAPI,o_sEINENGAPI1);
                r_WKRECORD001.SEINENGAPI := o_sEINENGAPI1.o_vEDIT_GYYMMDD3;    --生年月日
            END IF;

--  2024/07/01 ZCZL.GUANJINGHENG UPDATE END
            r_WKRECORD001.SEIBETSU                      := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;                      --性別
            r_WKRECORD001.SAKUSEIBI                     := MJIDO_WORK(ICNT).SAKUSEIBI;                           --作成日
            r_WKRECORD001.RENBAN                        := MJIDO_WORK(ICNT).RENBAN;                              --連番
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発
--            r_WKRECORD001.SHIMEI_KANJI                  := MJIDO_WORK(ICNT).SHIMEI_KANJI;                        --氏名漢字
            IF MJIDO_WORK(ICNT).KOJIN_CD IS NOT NULL THEN
                IF RASO.SHIMEI_KANJI IS NOT NULL THEN
                  r_WKRECORD001.SHIMEI_KANJI              := RASO.SHIMEI_KANJI;                                    --氏名漢字
                  sSHIMEI_KANJI              := RASO.SHIMEI_KANJI;
                ELSE
                  r_WKRECORD001.SHIMEI_KANJI              := RA.SHIMEI_KANJI;                                      --氏名漢字
                  sSHIMEI_KANJI              := RA.SHIMEI_KANJI;
                END IF;
            ELSE
                r_WKRECORD001.SHIMEI_KANJI                  := MJIDO_WORK(ICNT).SHIMEI_KANJI;                        --氏名漢字
                sSHIMEI_KANJI              := MJIDO_WORK(ICNT).SHIMEI_KANJI;
            END IF;
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE END
            r_WKRECORD001.ZOKUGARAMEI                   := MJIDO_WORK(ICNT).ZOKUGARAMEI;                         --続柄名
            r_WKRECORD001.KATAGAKI                      := MJIDO_WORK(ICNT).KATAGAKI;                            --方書
            r_WKRECORD001.JUSHO_JODAN                   := MJIDO_WORK(ICNT).JUSHO_JODAN;                         --住所上
            r_WKRECORD001.JUSHO_GEDAN                   := MJIDO_WORK(ICNT).JUSHO_GEDAN;                         --住所下
            r_WKRECORD001.NUSHI_SHIMEI_KANA             := MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA;                    --氏名かな主
            r_WKRECORD001.NUSHI_SHIMEI_KANJI            := MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI;                   --氏名漢字主
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発
--            IF LENGTH(MJIDO_WORK(ICNT).YUBIN_NO) > 0 AND
--               (MJIDO_WORK(ICNT).YUBIN_NO <> '0') THEN
--              VYUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO,4);
--              VYUBIN_NO := TRANSLATE( VYUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
--              r_WKRECORD001.YUBIN_NO                    := VYUBIN_NO;                                            --郵便番号
--            ELSE
--              r_WKRECORD001.YUBIN_NO                    := ' ';
--            END IF;
--            r_WKRECORD001.JUSHO                         := MJIDO_WORK(ICNT).CHOMEI ||MJIDO_WORK(ICNT).BANCHI;    --住所
--            r_WKRECORD001.SHIMEI                        := MJIDO_WORK(ICNT).SHIMEI_KANJI ||'　様';               --氏名
--            r_WKRECORD001.SYUHATU_NO                    := VSYUHATU_MEI  ||  '第'  ||  VSYUHATU_NO ||  '号';     --収発番号
            -- 「支援措置対象マスク」＝1(有)の場合
--  2024/09/29 ZCZL.YUCHUFEI UPDATE 0.3.000.004:仕様変更 IT_GKB_00074対応
--             IF g_vJYOUKEN8 = 0 THEN
            IF g_vJYOUKEN8 = 1 THEN
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 STR
--             r_WKRECORD001.YUBIN_NO := MJIDO_WORK(ICNT).YUBIN_NO;                                              --郵便番号
               nRTN := KKAPK0010.FYUBINHENSHU(MJIDO_WORK(ICNT).YUBIN_NO, sYUBIN_NO);
               r_WKRECORD001.YUBIN_NO :=  KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO, 0);                              --郵便番号
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 END
               vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', MJIDO_WORK(ICNT).KOJIN_CD, g_sTANTOCODE, g_sWSNUM, MJIDO_WORK(ICNT).JUSHO, nPRMCTL, 2);
               IF nPRMCTL = 1 THEN
                   r_WKRECORD001.YUBIN_NO := NULL;                                                               --郵便番号
               END IF;
            ELSE
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 STR
--             r_WKRECORD001.YUBIN_NO := MJIDO_WORK(ICNT).YUBIN_NO;                                              --郵便番号
               nRTN := KKAPK0010.FYUBINHENSHU(MJIDO_WORK(ICNT).YUBIN_NO, sYUBIN_NO);
               r_WKRECORD001.YUBIN_NO :=  KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO, 0);                              --郵便番号
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10160対応 END
            END IF;
            r_WKRECORD001.JUSHO := MJIDO_WORK(ICNT).JUSHO;                                                        --住所
            r_WKRECORD001.SHIMEI                        := sSHIMEI_KANJI || '　様';                               --氏名
            IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10158対応 STR
--             r_WKRECORD001.SYUHATU_NO                 := g_cBUNNUM;                                            --収発番号
               r_WKRECORD001.SYUHATU_NO                 := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_cBUNNUM, 0),' ',''),'　','');    --収発番号
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10158対応 END
            ELSE
               r_WKRECORD001.SYUHATU_NO                 := NULL;                                                 --収発番号
            END IF;
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE END
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10158対応 STR
--          r_WKRECORD001.HASSOBI                       := VHASOBI;                                              --発送日
            r_WKRECORD001.HASSOBI                       := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(VHASOBI, 0),' ',''),'　','');    --発送日
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10158対応 END
            r_WKRECORD001.SHIKUCHOSON_KATAGAKI          := VSHUCHOKATAGAKI2;                                     --市長名称
            r_WKRECORD001.SHIKUCHOSON_CHOMEI            := VSHUCHOMEI2;                                          --市長名
            IF o_ACONSPRM(3)=0 THEN
              IF MJIDO_WORK(ICNT).KYOIKUKAI_MEI IS NOT NULL THEN
                  VSHUCHOKATAGAKI := MJIDO_WORK(ICNT).KYOIKUKAI_MEI;
              ELSE
                  VSHUCHOKATAGAKI := ' ';
              END IF;
            ELSE
              VSHUCHOKATAGAKI := NULL;
            END IF;
            IF o_ACONSPRM(4)=0 THEN
              IF MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI IS NOT NULL THEN
                  VSHUCHOMEI := MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI;
              ELSE
                  VSHUCHOMEI := ' ';
              END IF;
            ELSE
              VSHUCHOMEI := NULL;
            END IF;

            r_WKRECORD001.KYOIKU_KAI_MEI     := VSHUCHOKATAGAKI;                                                 --教育長名称
            r_WKRECORD001.KYOIKU_SHUCHO_MEI  := VSHUCHOMEI;                                                      --教育長名
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10159対応 STR
--          r_WKRECORD001.TITLE              := VUSERMEI ||'成人式の開催について（ご案内）';                     --タイトル
            r_WKRECORD001.TITLE              := rSEIJIN.CHOHYO_MEI;                                      --タイトル
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10159対応 END
            r_WKRECORD001.SHIKUCHOSON_MEI    := VUSERMEI;                                                        --市町村名
            r_WKRECORD001.BC_NO              := MJIDO_WORK(ICNT).YUBIN_NOBC;                                     --カスタマバーコード
            IF LENGTH(MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO) > 3 THEN
                  VKYOIKUYUBINNO := SUBSTR(MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO,4);
                  VKYOIKUYUBINNO := TRANSLATE( VKYOIKUYUBINNO, '1234567890-', '１２３４５６７８９０－' );
                  r_WKRECORD001.KYOIKU_YUBIN_NO        := VKYOIKUYUBINNO;                                        --委員会郵便番号
            ELSE
                  r_WKRECORD001.KYOIKU_YUBIN_NO        := ' ';
            END IF;
            IF MJIDO_WORK(ICNT).KYOIKUKAI_MEI  IS NOT NULL THEN
               r_WKRECORD001.KYOIKU_JUSHO              := MJIDO_WORK(ICNT).KYOIKU_JUSHO;                         --委員会住所
            ELSE
               r_WKRECORD001.KYOIKU_JUSHO              := ' ';
            END IF;
            IF MJIDO_WORK(ICNT).KYOIKU_TEL  IS NOT NULL THEN
               r_WKRECORD001.KYOIKU_TEL                := MJIDO_WORK(ICNT).KYOIKU_TEL;                           --委員会電話番号
            ELSE
               r_WKRECORD001.KYOIKU_TEL                := ' ';
            END IF;
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10158対応 STR
--          r_WKRECORD001.DATE1                        := MJIDO_WORK(ICNT).DATE1;                                --日付１
            r_WKRECORD001.DATE1                        := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(MJIDO_WORK(ICNT).DATE1, 0),' ',''),'　','');     --日付１
--  2025/01/10 JPJYS.YANGXIHAN UPDATE 0.3.000.011:IT_GKB_10158対応 END
            r_WKRECORD001.DATE2                        := MJIDO_WORK(ICNT).DATE2;                                --日付２
            r_WKRECORD001.DATE3                        := MJIDO_WORK(ICNT).DATE3;                                --日付３
            r_WKRECORD001.DATE4                        := MJIDO_WORK(ICNT).DATE4;                                --日付４
            r_WKRECORD001.DATE5                        := MJIDO_WORK(ICNT).DATE5;                                --日付５
            r_WKRECORD001.KOMOKU1                      := MJIDO_WORK(ICNT).KOMOKU1;                              --項目１
            r_WKRECORD001.KOMOKU2                      := MJIDO_WORK(ICNT).KOMOKU2;                              --項目２
            r_WKRECORD001.KOMOKU3                      := MJIDO_WORK(ICNT).KOMOKU3;                              --項目３
            r_WKRECORD001.KOMOKU4                      := MJIDO_WORK(ICNT).KOMOKU4;                              --項目４
            r_WKRECORD001.KOMOKU5                      := MJIDO_WORK(ICNT).KOMOKU5;                              --項目５
            r_WKRECORD001.KOMOKU6                      := MJIDO_WORK(ICNT).KOMOKU6;                              --項目６
            r_WKRECORD001.KOMOKU7                      := MJIDO_WORK(ICNT).KOMOKU7;                              --項目７
            r_WKRECORD001.KOMOKU8                      := MJIDO_WORK(ICNT).KOMOKU8;                              --項目８
            r_WKRECORD001.KOMOKU9                      := MJIDO_WORK(ICNT).KOMOKU9;                              --項目９
            r_WKRECORD001.KOMOKU10                     := MJIDO_WORK(ICNT).KOMOKU10 ;                            --項目１０
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE 0.3.000.000:新WizLIFE２次開発
--            r_WKRECORD001.SHUCHO_KOIN                  := VSHUCHO_KOIN;                                          --首長公印
            r_WKRECORD001.SHUCHO_KOIN                  := o_sKOINFILENAME;                                          --首長公印
            r_WKRECORD001.WAREKI_NENDO                 := SUBSTR(NWAREKINENDO,2,2);                              --和暦年度
            r_WKRECORD001.SEIRI_BANGO                  := MJIDO_WORK(ICNT).SEIRI_NO;                             --整理番号
            --成人者と世帯主が違う場合のみ表示用世帯主名を出力
            IF MJIDO_WORK(ICNT).KOJIN_CD <> MJIDO_WORK(ICNT).NUSHI_KOJIN_NO AND
               MJIDO_WORK(ICNT).NUSHI_KOJIN_NO <> 0 THEN
              r_WKRECORD001.SETAINUSHIMEI              := MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI || '　様方';        --表示用世帯主名
            ELSE
              r_WKRECORD001.SETAINUSHIMEI              := '';
            END IF;
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発
--  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.000.010:仕様変更IT_GKB_00701の対応 START
            --r_WKRECORD001.KOIN_SHORYAKU                := rSEIJIN.KOIN_SHORYAKU;                               --公印省略
            --r_WKRECORD001.KOIN_CHUSHAKU                := rSEIJIN.KOIN_CHUSHAKU;                               --公印注釈
            IF o_vKOINFILENAME IS NOT NULL THEN
              r_WKRECORD001.KOIN_SHORYAKU                := NULL;                                                --公印省略
              r_WKRECORD001.KOIN_CHUSHAKU                := rSEIJIN.KOIN_CHUSHAKU;                               --公印注釈
            ELSE
              r_WKRECORD001.KOIN_SHORYAKU                := rSEIJIN.KOIN_SHORYAKU;                               --公印省略
              r_WKRECORD001.KOIN_CHUSHAKU                := NULL;                                                --公印注釈
            END IF;
--  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.000.010:仕様変更IT_GKB_00701の対応 END
            --  2025/02/07 JPJYS.SONGSHIHAO UPDATE 0.3.000.013:ST_GKB_TMP00047対応　Start
            --r_WKRECORD001.TSUCHIBUN                    := MJIDO_WORK(ICNT).TSUCHIBUN;   --通知文
            r_WKRECORD001.TSUCHIBUN                    := REPLACE(MJIDO_WORK(ICNT).TSUCHIBUN, chr(13)||chr(10),'#');   --通知文
            --  2025/02/07 JPJYS.SONGSHIHAO UPDATE 0.3.000.013:ST_GKB_TMP00047対応　End
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応            
            /*r_WKRECORD001.TOIAWASESAKI                 := MJIDO_WORK(ICNT).TOIAWASESAKI;                         --お問い合わせ先
            r_WKRECORD001.TOIAWASE_JUSHO               := MJIDO_WORK(ICNT).TOIAWASE_JUSHO;                       --お問い合わせ先住所
            r_WKRECORD001.TOIAWASE_TEL                 := MJIDO_WORK(ICNT).TOIAWASE_TEL;                         --お問い合わせ先電話番号*/
--  2025/11/18 CTC.HJF UPDATE START 1.0.301.000:GKB_QA22670対応
            --r_WKRECORD001.TOIAWASESAKI                 := MJIDO_WORK(ICNT).KYOIKUKAI_MEI;                         --お問い合わせ先
            --r_WKRECORD001.TOIAWASE_JUSHO               := MJIDO_WORK(ICNT).KYOIKU_JUSHO;                       --お問い合わせ先住所
            --r_WKRECORD001.TOIAWASE_TEL                 := MJIDO_WORK(ICNT).KYOIKU_TEL;                         --お問い合わせ先電話番号
            r_WKRECORD001.TOIAWASESAKI                 := MJIDO_WORK(ICNT).TOIAWASESAKI;                         --お問い合わせ先
            r_WKRECORD001.TOIAWASE_JUSHO               := MJIDO_WORK(ICNT).TOIAWASE_JUSHO;                       --お問い合わせ先住所
            r_WKRECORD001.TOIAWASE_TEL                 := MJIDO_WORK(ICNT).TOIAWASE_TEL;                         --お問い合わせ先電話番号
--  2025/11/18 CTC.HJF UPDATE END
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
            r_WKRECORD001.YOSHIKI_NO                   := sYOSHIKI;                                              --様式番号
            r_WKRECORD001.KOJIN_NO                     := MJIDO_WORK(ICNT).KOJIN_CD;                             --宛名番号
            r_WKRECORD001.HOGOSYA_KOJIN_NO             := MJIDO_WORK(ICNT).NUSHI_KOJIN_NO;                       --世帯主宛名番号
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE END
            r_WKRECORD001.BREAK_NO                     := NULL;                                                  --改ページキー
            r_WKRECORD001.WSNUM                        := g_sWSNUM;                                              --端末番号
            r_WKRECORD001.BATCHKBN                     := c_BATCH;                                               --バッチ区分
            r_WKRECORD001.JOBNUM                       := g_nJOBNUM;                                             --ジョブNO

            INSERT INTO GKBWL400R001 VALUES r_WKRECORD001;

            IF MJIDO_WORK(ICNT).KOJIN_CD IS NOT NULL THEN
                IF g_vJYOUKEN9 = 0 THEN
--  2026/01/05 CTC.HJF UPDATE START 1.0.451.000:GKB_QA25074対応
               -- 学齢簿の個人番号をインプットして、保護者取得サブルーチンを呼ぶ
                  IRTN := GKBPK00010.FHOGOSHA(ISAKUSEIBI,
                                              MJIDO_WORK(ICNT).KOJIN_CD, 
                                              IHOGOSHA_KOJIN_NO); 
--  2026/01/05 CTC.HJF UPDATE END

                    --文書番号（編集前文字）の LENGTH
                    nMAEMOJILEN := LENGTH(g_rBUNNUMSRCINF.MAEMOJI);
                    --文書番号（後ろ文字）の LENGTH
                    nUSHIROMOJILEN := LENGTH(g_rBUNNUMSRCINF.USHIROMOJI);
                    --文書番号（編集前）の LENGTH
                    nNUMLENGTH := LENGTH(g_cBUNNUM) - nUSHIROMOJILEN - nMAEMOJILEN;
                    --文書番号（編集前）の取得
--  2024/11/21 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKC_00329横展開対応
                    --g_nBUNSHOBANGO := TO_NUMBER(KKAPK0010.FSTRCNV(SUBSTR(g_cBUNNUM, nMAEMOJILEN+1, nNUMLENGTH),1));
                    g_nBUNSHOBANGO := KKAPK0010.FSTRCNV(SUBSTR(g_cBUNNUM, nMAEMOJILEN+1, nNUMLENGTH),1);
                    --発行履歴レコード作成
                    IRTN := GKAFKHAKKOR('GKB',                                                                   --業務コード
                                        MJIDO_WORK(ICNT).KOJIN_CD,                                               --宛名番号
                                        g_rJSTP.CHOHYONUM,                                                       --帳票コード
                                        TO_NUMBER(SUBSTR(ISAKUSEIBI,1,4)),                                       --年度
                                        1,                                                                       --処理区分（0：即時、1：一括）
                                        g_rJSTP.CHOHYONAME,                                                      --通知書種別
                                        TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),                                  --発行日
                                        g_nTIME,                                                                 --発行時間
                                        1,                                                                       --発行枚数
                                        g_sTANTOCODE,                                                            --発行職員宛名番号
                                        KKAPK0020.FNENDOHENKAN(g_vJYOUKEN3),                                     --送付日
                                        NULL,                                                                    --通知場所
                                        g_rBUNNUMSRCINF.MAEMOJI,                                                 --文書番号接頭語
                                        g_nBUNSHOBANGO,                                                          --文書番号
                                        g_rBUNNUMSRCINF.USHIROMOJI,                                              --文書番号接尾語
--  2026/01/05 CTC.HJF UPDATE START 1.0.451.000:GKB_QA25074対応
                                        --MJIDO_WORK(ICNT).KOJIN_CD,                                               --通知対象者宛名番号
                                        IHOGOSHA_KOJIN_NO,                                                       --通知対象者宛名番号
--  2026/01/05 CTC.HJF UPDATE END
                                        NULL,                                                                    --転出先自治体コード
                                        g_sWSNUM                                                                 --更新端末番号
                                        );
                     -- 戻り値が1の場合
                     IF IRTN = 1 THEN
                         BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_CSVFILE1１', 1, '', '', '[成人式案内通知]共通関数(帳票発行履歴作成)(GKAFKHAKKOR)でエラーが発生しました。　宛名番号： ' || RA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
                     END IF;
                END IF;
            END IF;
            IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (g_rBUNNUMSRCINF.NUMINCTYPE = 1 OR g_rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
              KKAPK0040.SBunNumIc(g_rBUNNUMSRCINF, g_rBUNNUMEDITKEKA);
              --文書番号（編集済み）
              g_cBUNNUM := g_rBUNNUMEDITKEKA.NUM;
            END IF;
            -- 文書番号保管
            g_rBUNNUM(ICNT).KOJINNUM := MJIDO_WORK(ICNT).KOJIN_CD;       -- 宛名番号
            g_rBUNNUM(ICNT).BUNNUM := g_cBUNNUM;                         -- 文書番号
-- 2025/05/28 CTC.HJF DELETE Start 1.0.006.000:GKB_QA14364対応
--            --発送者文字切れリストの作成
--            BRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM,g_sWSNUM,g_sTANTOCODE,'GKB400R001',1,nKENSAKU);
--            -- 戻り値がFALSEの場合
--            IF BRTN = FALSE THEN
--                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_CSVFILE1２', 1, '', '', '[成人式案内通知]共通関数(各種通知書発送者文字切れリスト(GKAPK00010.FKMJGRLST)でエラーが発生しました。　宛名番号 ： ' || RA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
--            END IF;
-- 2025/05/28 CTC.HJF DELETE End
        END LOOP;
-- 2025/05/28 CTC.HJF ADD Start 1.0.006.000:GKB_QA14364対応
            --発送者文字切れリストの作成
            BRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM,g_sWSNUM,g_sTANTOCODE,'GKB400R001',1,nKENSAKU);
            -- 戻り値がFALSEの場合
            IF BRTN = FALSE THEN
                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_CSVFILE1２', 1, '', '', '[成人式案内通知]共通関数(各種通知書発送者文字切れリスト(GKAPK00010.FKMJGRLST)でエラーが発生しました。　宛名番号 ： ' || RA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
            END IF;
-- 2025/05/28 CTC.ADD UPDATE End
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(ICNT_1,'出力　成人式案内状CSV',2);

        -- 終了
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_CSVFILE1', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCSET_JIDO_WK_CSVFILE1;
    --------------------------------------------------------------------------------------------------
    -- 成人式案内状発送者一覧表ＣＳＶファイル作成
    --------------------------------------------------------------------------------------------------
    FUNCTION FUNCSET_JIDO_WK_CSVFILE2 RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                PLS_INTEGER;                -- カウント
        IMAX                PLS_INTEGER;                -- 最大値（出力件数）
        IMIN                PLS_INTEGER;                -- 最小値（出力件数）
        ICNT_1              BINARY_INTEGER := 0;        -- カウント
        r_WKRECORD002       GKBWL400R002%ROWTYPE;
        nROWNO              NUMBER := 0;
        -- 2026/01/06 CTC.XW UPDATE START 1.0.452.000:GKB_QA24989対応
        nPRMCTL  NUMBER;
        -- 2026/01/06 CTC.XW UPDATE END
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
        IRTN                PLS_INTEGER;                -- 呼出関数の戻り値
        o_YUBIN_NO          NVARCHAR2(1000);            -- 郵便番号
        sSOFUSAKI_JUSHO     NVARCHAR2(1000);            -- 送付先住所
        sZOKUGARA_MEI       NVARCHAR2(1000);            -- 続柄名
        nKOJINSETAIKBN      NUMBER;                     --個人世帯区分（0：個人、1：世帯）
        nYOKUSHIKBN         NUMBER;                     --抑止区分（1：支援措置、2：仮支援措置、4：その他抑止）
        nIDOYOKUSHIKBN      NUMBER;                     --異動抑止区分（0：非該当、1：警告、2：論理）
        nHAKKOYOKUSHIKBN    NUMBER;                     --発行抑止区分（0：非該当、1：警告、2：論理）
        nSHOKAIYOKUSHIKBN   NUMBER;                     --照会抑止区分（0：非該当、1：警告、2：論理）
        vSHORICHUIKBN       NVARCHAR2(1000);            --処理注意区分（任意設定）
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
    BEGIN

        IFRET := c_ISUCCESS;               -- 正常終了

        IMAX := MJIDO_WORK.LAST;           -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;          -- ワーク領域の件数の最小値

        -- 取得した件数分繰り返す
        FOR ICNT IN IMIN..IMAX LOOP

            ICNT_1 := ICNT_1 + 1;
            nROWNO := nROWNO + 1;
            r_WKRECORD002 := NULL;
            r_WKRECORD002.NO := nROWNO;                                                                  --ソート順
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発
--            r_WKRECORD002.NENDO                   := MJIDO_WORK(ICNT).NENDO||'年度';                     --年度
--            r_WKRECORD002.KAIPAGE_CD              := MJIDO_WORK(ICNT).KAIPEJI_CD;                        --改頁コード
--            r_WKRECORD002.KAIPAGE_MEI             := MJIDO_WORK(ICNT).KAIPEJI;                           --改頁名
--            r_WKRECORD002.GYOSEIKU_MEI            := MJIDO_WORK(ICNT).GYOSEIKUMEI;                       --行政区名
--            r_WKRECORD002.SANTEIDANTAI_MEI        := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;                   --算定団体名
--            r_WKRECORD002.SHIMEI_KANA             := MJIDO_WORK(ICNT).SHIMEI_KANA;                       --氏名カナ
--            r_WKRECORD002.SEINENGAPI              := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;                  --生年月日
--            r_WKRECORD002.SEIBETSU                := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;                    --性別
--            r_WKRECORD002.GENZAIBI                := MJIDO_WORK(ICNT).SAKUSEIBI;                         --現在日
--            r_WKRECORD002.NUM                     := MJIDO_WORK(ICNT).RENBAN;                            --No
--            r_WKRECORD002.SHIMEI                  := MJIDO_WORK(ICNT).SHIMEI_KANJI;                      --氏名
--            r_WKRECORD002.ZOKUGARA                := MJIDO_WORK(ICNT).ZOKUGARAMEI;                       --続柄
--            r_WKRECORD002.KATAGAKI                := MJIDO_WORK(ICNT).KATAGAKI;                          --方書
--            r_WKRECORD002.JUSHO_JODAN             := MJIDO_WORK(ICNT).JUSHO_JODAN;                       --住所上
--            r_WKRECORD002.JUSHO_GEDAN             := MJIDO_WORK(ICNT).JUSHO_GEDAN;                       --住所下
--            r_WKRECORD002.NUSHI_SHIMEI_KANA       := MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA;                  --世帯主氏名カナ
--            r_WKRECORD002.NUSHI_SHIMEI_KANJI      := MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI;                 --世帯主氏名
--            IF MJIDO_WORK(ICNT).YUBIN_NO IS NOT NULL THEN
--              r_WKRECORD002.YUBIN_NO              := SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO,4);
--            ELSE
--              r_WKRECORD002.YUBIN_NO              := '';
--            END IF;
--            r_WKRECORD002.CHOMEI_BANCHI           := MJIDO_WORK(ICNT).CHOMEI ||MJIDO_WORK(ICNT).BANCHI;  --町名番地
--            r_WKRECORD002.SHIMEI_KANJI_SAMA       := MJIDO_WORK(ICNT).SHIMEI_KANJI ||'　様';              --氏名漢字様
--            r_WKRECORD002.BIKO                    := MJIDO_WORK(ICNT).SEIRI_NO;                          --備考
--            r_WKRECORD002.JINKAKU_KBN             := MJIDO_WORK(ICNT).JINKAKU_KBN;                       --人格区分
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.007:IT_GKB_00286横展開対応
--            r_WKRECORD002.SAKUSEI_YMD             := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(ISAKUSEIBI, 'YYYY/MM/DD'),'YYYY/MM/DD'),1);   --作成年月日
            r_WKRECORD002.SAKUSEI_YMD             := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(ISAKUSEIBI),1);   --作成年月日
            r_WKRECORD002.TITLE                   := '成人式案内状発送者一覧表';                                --タイトル
            IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
              --文書番号
              FOR i IN 1..g_rBUNNUM.COUNT LOOP
                IF g_rBUNNUM(i-1).KOJINNUM = MJIDO_WORK(ICNT).KOJIN_CD THEN
                  r_WKRECORD002.BUNSHO_NO       :=  g_rBUNNUM(i-1).BUNNUM;                                    --文書番号
                  EXIT;
                END IF;
              END LOOP;
            END IF;
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.007:IT_GKB_00286横展開対応
--            r_WKRECORD002.HAKKO_YMD               := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(ISAKUSEIBI, 'YYYY/MM/DD'),'YYYY/MM/DD'),1);   --作成年月日
            r_WKRECORD002.HAKKO_YMD               := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(ISAKUSEIBI),1);   --作成年月日
            -- 成人者の個人番号より宛名情報取得
            IRTN := GAAPK0030.FGETATENA(MJIDO_WORK(ICNT).KOJIN_CD, 'GKB', ISAKUSEIBI, RA, RASO);
            -- カーソル.宛名番号＜＞NULL
            IF MJIDO_WORK(ICNT).KOJIN_CD IS NOT NULL THEN
                -- 成人者の送付先基本.宛名番号<>NULLの場合
                
-- 2026/01/06 CTC.XW UPDATE START 1.0.452.000:GKB_QA24989対応            
             if  g_vJYOUKEN8=0 then  
-- 2026/01/06 CTC.XW UPDATE END
                IF RASO.KOJIN_NO IS NOT NULL THEN
                  -- 2025/05/07 CTC.HUANG Update start 1.0.003.000 GK_QA13762_成人式案内状発送者一覧表の送付先氏名に氏名カナが印字されるを対応
                  r_WKRECORD002.SOFUSAKI_SHIMEI              := RASO.SHIMEI_KANJI || ' 様';                      --送付先氏名
                  -- 2025/05/07 CTC.HUANG Update end
                  IRTN := KKAPK0010.FYUBINHENSHU(RASO.YUBIN_NO,r_WKRECORD002.SOFUSAKI_YUBIN_NO);
                  r_WKRECORD002.SOFUSAKI_YUBIN_NO            := KKAPK0010.FMULTIBYTEHENKAN(r_WKRECORD002.SOFUSAKI_YUBIN_NO,0);       --送付先郵便番号
-- 2025/07/30 CTC.HJF UPDATE Start 1.0.011.000:GKB_QA18860+対応
                  --sSOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  RASO.CHOMEI , RASO.BANCHI , NULL, NULL);
                  sSOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  RASO.CHOMEI , RASO.BANCHI , RASO.KATAGAKI, NULL);
-- 2025/07/30 CTC.HJF UPDATE End
                  r_WKRECORD002.SOFUSAKI_JUSHO := sSOFUSAKI_JUSHO;                                              --送付先住所
                ELSE
                  -- 2025/05/07 CTC.HUANG Update start 1.0.003.000 GK_QA13762_成人式案内状発送者一覧表の送付先氏名に氏名カナが印字されるを対応
                  r_WKRECORD002.SOFUSAKI_SHIMEI              := RA.SHIMEI_KANJI || ' 様';                        --送付先氏名
                  -- 2025/05/07 CTC.HUANG Update end
                  IRTN := KKAPK0010.FYUBINHENSHU(RA.YUBIN_NO,r_WKRECORD002.SOFUSAKI_YUBIN_NO);
                  r_WKRECORD002.SOFUSAKI_YUBIN_NO            := KKAPK0010.FMULTIBYTEHENKAN(r_WKRECORD002.SOFUSAKI_YUBIN_NO,0);       --送付先郵便番号
-- 2025/07/30 CTC.HJF UPDATE Start 1.0.011.000:GKB_QA18860+対応
                  --sSOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  RA.CHOMEI , RA.BANCHI , NULL, NULL);
                  sSOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  RA.CHOMEI , RA.BANCHI , RA.KATAGAKI, NULL);
-- 2025/07/30 CTC.HJF UPDATE End
                  r_WKRECORD002.SOFUSAKI_JUSHO := sSOFUSAKI_JUSHO;                                              --送付先住所
                END IF;
-- 2026/01/06 CTC.XW UPDATE START 1.0.452.000:GKB_QA24989対応
             ELSE   
                 IF RASO.KOJIN_NO is NOT NULL THEN
                     r_WKRECORD002.SOFUSAKI_SHIMEI := RASO.SHIMEI_KANJI || ' 様';                      --送付先氏名
                     IRTN := KKAPK0010.FYUBINHENSHU(RASO.YUBIN_NO,r_WKRECORD002.SOFUSAKI_YUBIN_NO);
                     r_WKRECORD002.SOFUSAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(r_WKRECORD002.SOFUSAKI_YUBIN_NO,0);       --送付先郵便番号
                     sSOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  RASO.CHOMEI , RASO.BANCHI , RASO.KATAGAKI, NULL);
                     r_WKRECORD002.SOFUSAKI_JUSHO  := GAAPK0030.FDVJUSHO('GKB', RASO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sSOFUSAKI_JUSHO, nPRMCTL, 2);
                     IF nPRMCTL = 1 THEN
                         r_WKRECORD002.SOFUSAKI_YUBIN_NO := NULl;
                     END IF;
                  ELSE
                     r_WKRECORD002.SOFUSAKI_SHIMEI := RA.SHIMEI_KANJI || ' 様';                        --送付先氏名
                     IRTN := KKAPK0010.FYUBINHENSHU(RA.YUBIN_NO,r_WKRECORD002.SOFUSAKI_YUBIN_NO);
                     r_WKRECORD002.SOFUSAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(r_WKRECORD002.SOFUSAKI_YUBIN_NO,0);       --送付先郵便番号
                     sSOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  RA.CHOMEI , RA.BANCHI , RA.KATAGAKI, NULL);
                     r_WKRECORD002.SOFUSAKI_JUSHO  := GAAPK0030.FDVJUSHO('GKB', RA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sSOFUSAKI_JUSHO, nPRMCTL, 2);
                  END IF;
                  IF nPRMCTL = 1 THEN
                      r_WKRECORD002.SOFUSAKI_YUBIN_NO := NULl;
                  END if;
               ENd if; 
-- 2026/01/06 CTC.XW UPDATE END
                IF RASO.SHIMEI_KANA IS NOT NULL THEN
                  r_WKRECORD002.JIDO_SHIMEI_KANA             := RASO.SHIMEI_KANA;                               --児童生徒氏名カナ
                ELSE
                  r_WKRECORD002.JIDO_SHIMEI_KANA             := RA.SHIMEI_KANA;                                 --児童生徒氏名カナ
                END IF;
                IF RASO.SHIMEI_KANJI IS NOT NULL THEN
                  r_WKRECORD002.JIDO_SHIMEI_KANJI            := RASO.SHIMEI_KANJI;                              --児童生徒氏名漢字
                ELSE
                  r_WKRECORD002.JIDO_SHIMEI_KANJI            := RA.SHIMEI_KANJI;                                --児童生徒氏名漢字
                END IF;
                -- カーソル.人格区分 <> 1（外国人）の場合は
                IF MJIDO_WORK(ICNT).JINKAKU_KBN <> 1 THEN
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.007:IT_GKB_00286横展開対応
--                  r_WKRECORD002.SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(RA.SEINENGAPI, 'YYYY/MM/DD'),'YYYY/MM/DD'),1);        --生年月日
                  GKAPK00020.FGETSEINENGHYOUJI(RA.SEINENGAPI,o_sEINENGAPI2);
                  r_WKRECORD002.SEINENGAPI := o_sEINENGAPI2.o_vEDIT_GYYMMDD3;        --生年月日
                ELSE
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.007:IT_GKB_00286横展開対応
--                  r_WKRECORD002.SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(RA.SEINENGAPI, 'YYYY/MM/DD'),'YYYY/MM/DD'),6);        --生年月日
                  GKAPK00020.FGETSEINENGHYOUJI(RA.SEINENGAPI,o_sEINENGAPI2);
                  r_WKRECORD002.SEINENGAPI := o_sEINENGAPI2.o_vSEINEN_UMIGAI;        --生年月日
                END IF;
            ELSE
                r_WKRECORD002.SOFUSAKI_SHIMEI         := MJIDO_WORK(ICNT).SHIMEI_KANJI || ' 様';                       --送付先氏名
                IRTN := KKAPK0010.FYUBINHENSHU(MJIDO_WORK(ICNT).YUBIN_NO,r_WKRECORD002.SOFUSAKI_YUBIN_NO);
                r_WKRECORD002.SOFUSAKI_YUBIN_NO            := KKAPK0010.FMULTIBYTEHENKAN(r_WKRECORD002.SOFUSAKI_YUBIN_NO,0);       --送付先郵便番号
-- 2025/07/30 CTC.HJF UPDATE Start 1.0.011.000:GKB_QA18860+対応
                --sSOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  MJIDO_WORK(ICNT).CHOMEI , MJIDO_WORK(ICNT).BANCHI , NULL, NULL);
                sSOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  MJIDO_WORK(ICNT).CHOMEI , MJIDO_WORK(ICNT).BANCHI , MJIDO_WORK(ICNT).KATAGAKI, NULL);
-- 2025/07/30 CTC.HJF UPDATE End
                r_WKRECORD002.SOFUSAKI_JUSHO := sSOFUSAKI_JUSHO;                                                          --送付先住所
                r_WKRECORD002.JIDO_SHIMEI_KANA             := MJIDO_WORK(ICNT).SHIMEI_KANA;                               --児童生徒氏名カナ
                r_WKRECORD002.JIDO_SHIMEI_KANJI            := MJIDO_WORK(ICNT).SHIMEI_KANJI;                              --児童生徒氏名漢字
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.007:IT_GKB_00286横展開対応
--                r_WKRECORD002.SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(MJIDO_WORK(ICNT).SEINENGAPI, 'YYYY/MM/DD'),'YYYY/MM/DD'),1);    --生年月日
                GKAPK00020.FGETSEINENGHYOUJI(MJIDO_WORK(ICNT).SEINENGAPI,o_sEINENGAPI2);
                r_WKRECORD002.SEINENGAPI := o_sEINENGAPI2.o_vEDIT_GYYMMDD3;    --生年月日
            END IF;
            IF MJIDO_WORK(ICNT).SEIBETSU = '1' THEN
              r_WKRECORD002.SEIBETSU := '男';                                                                              --性別
            ELSIF MJIDO_WORK(ICNT).SEIBETSU = '2' THEN
              r_WKRECORD002.SEIBETSU := '女';                                                                              --性別
            END IF;

            --世帯主取得
            NNUSHIKOJINNO := 0;
            VSHIMEI_KANA  := ' ';
            VSHIMEI_KANJI := ' ';
            -- 世帯主取得共通サブルーチンから世帯主名を取得する
            IRTN := JIAPK0030.FGETNUSHI( ISAKUSEIBI, MJIDO_WORK(ICNT).KOJIN_CD, NNUSHIKOJINNO, VSHIMEI_KANJI);
            --世帯主が取得できたとき
            IF IRTN <> 9 THEN
               -- 世帯主の宛名情報を取得
               IRTN := GAAPK0030.FGETATENA( NNUSHIKOJINNO, g_sGYOUMUCODE, ISAKUSEIBI, RAS, RASOS);
               VSHIMEI_KANA := RAS.SHIMEI_KANA;
               VSHIMEI_KANJI := RAS.SHIMEI_KANJI;
            ELSE
               NNUSHIKOJINNO := 0;
               VSHIMEI_KANA  := ' ';
               VSHIMEI_KANJI  := ' ';
            END IF;
            -- 続柄名が取得する
            BEGIN
              SELECT ZOKUGARA_MEI
                INTO sZOKUGARA_MEI
                FROM JIBTJUKIIDO
               WHERE KOJIN_NO = MJIDO_WORK(ICNT).KOJIN_CD;
            EXCEPTION
--  2024/09/09 ZCZL.WANGMING UPDATE 0.3.000.003:8月1日認識合わせの横展開
--              WHEN NO_DATA_FOUND THEN
              WHEN OTHERS THEN
                   sZOKUGARA_MEI := '';
            END;
            --成人者_支援措置
            IRTN := GAAPK0030.FGETDV(MJIDO_WORK(ICNT).KOJIN_CD,
                                     RAS.SETAI_NO,
                                     ISAKUSEIBI,
                                     'GKB',
                                     0,
                                     nKOJINSETAIKBN,
                                     nYOKUSHIKBN,
                                     nIDOYOKUSHIKBN,
                                     nHAKKOYOKUSHIKBN,
                                     nSHOKAIYOKUSHIKBN,
                                     vSHORICHUIKBN);
-- 2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
            --IF nYOKUSHIKBN = 1 THEN
            IF 0 < nYOKUSHIKBN AND nYOKUSHIKBN < 99 THEN
-- 2025/06/04 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
              r_WKRECORD002.JIDO_SHIENSOCHI := '対象';                                                   --児童生徒_支援措置
            ELSE
              r_WKRECORD002.JIDO_SHIENSOCHI := ' ';                                                      --児童生徒_支援措置
            END IF;
            r_WKRECORD002.HOGOSHA_SHIMEI_KANA     := VSHIMEI_KANA;                                       --保護者氏名カナ
            r_WKRECORD002.HOGOSHA_SHIMEI_KANJI    := VSHIMEI_KANJI;                                      --保護者氏名漢字
            r_WKRECORD002.HOGOSHA_ZOKUGARA        := sZOKUGARA_MEI;                                      --児童生徒との関係
            --世帯主_支援措置
            IRTN := GAAPK0030.FGETDV(NNUSHIKOJINNO,
                                     RAS.SETAI_NO,
                                     ISAKUSEIBI,
                                     'GKB',
                                     0,
                                     nKOJINSETAIKBN,
                                     nYOKUSHIKBN,
                                     nIDOYOKUSHIKBN,
                                     nHAKKOYOKUSHIKBN,
                                     nSHOKAIYOKUSHIKBN,
                                     vSHORICHUIKBN);
-- 2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
            --IF nYOKUSHIKBN = 1 THEN
            IF 0 < nYOKUSHIKBN AND nYOKUSHIKBN < 99 THEN  
-- 2025/06/04 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
              r_WKRECORD002.HOGOSHA_SHIENSOCHI := '対象';                                                   --保護者_支援措置
            ELSE
              r_WKRECORD002.HOGOSHA_SHIENSOCHI := ' ';                                                      --保護者_支援措置
            END IF;
            r_WKRECORD002.GAKKO_MEI               := NULL;                                               --学校名
            r_WKRECORD002.KENSU                   := g_nINDEX;                                           --件数
            r_WKRECORD002.GAKKO_CD                := NULL;                                               --学校コード
            r_WKRECORD002.JIDO_SHIMEI_LABEL       := '氏名';                                             --児童生徒氏名_ラベル
            r_WKRECORD002.HOGOSHA_SHIMEI_LABEL    := '世帯主氏名';                                       --保護者氏名_ラベル
            r_WKRECORD002.GAKKO_GYOSEIKU_LABEL    := '行政区';                                           --学校/行政区_ラベル
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE END
            r_WKRECORD002.BREAK_NO                := NULL;                                               --改ページキー
            r_WKRECORD002.WSNUM                   := g_sWSNUM;                                           --端末番号
            r_WKRECORD002.BATCHKBN                := c_BATCH;                                            --バッチ区分
            r_WKRECORD002.JOBNUM                  := g_nJOBNUM;                                          --ジョブNO

            INSERT INTO GKBWL400R002 VALUES r_WKRECORD002;
        END LOOP;
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(ICNT_1,'出力　成人式案内状発送者一覧表CSV',2);

        -- 終了
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_CSVFILE2', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCSET_JIDO_WK_CSVFILE2;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
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

        --複数な帳票の場合、該当ロジックあり
        --変数の初期について、該当処理内作成しますか？判断要
        --帳票IDに関連な変数にIF内で書く
--  2024/04/22 ZCZL.WUCAO DELETE 0.2.000.001:512_GKB_00027対応
--        IF g_nSTEP_INDEX = 1 THEN
--  2024/10/28 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00323の対応
           --ワークテーブルのデータを削除する
         CASE g_rJSTP.Chohyoid
          WHEN 'GKB400R001' THEN
           DELETE FROM GKBWL400R001 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
          WHEN 'GKB130R002' THEN
           DELETE FROM GKBWL400R002 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
          ELSE
            NULL;
         END CASE;
--  2024/10/28 ZCZL.WANGYUNING UPDATE END
--  2024/07/01 ZCZL.GUANJINGHENG DELETE 0.3.000.000:新WizLIFE２次開発
--            COMMIT;
           -- システム日付を西暦数値（YYYYMMDD形式）にする
           ISAKUSEIBI := TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));

           -- 取得した条件をそれぞれの変数へセット
           VNENDO           := g_vJYOUKEN1;               -- 年度
--  2024/07/01 ZCZL.GUANJINGHENG DELETE START 0.3.000.000:新WizLIFE２次開発
--           VSYUHATU_NO      := g_vJYOUKEN2;               -- 収発番号
           VHASOBI          := g_vJYOUKEN3;               -- 発送日
           VKBN             := g_vJYOUKEN4;               -- 作成区分
           VSANTEIDANTAI_CD := g_vJYOUKEN5;               -- 算定団体コード
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
           ISEINENGAPIFROM  := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN6);               -- 生年月日（開始）
           ISEINENGAPITO    := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN7);               -- 生年月日（終了）
--  2024/07/01 ZCZL.GUANJINGHENG ADD END

           -- 処理条件の設定
           PROCHAISET;

           -- 成人者ワーク（GKBWSEIJINSHA）のデータ全件削除
           I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
           IF I_RTN = c_INOT_SUCCESS THEN
           -- エラーで帰ってきた場合
               B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
               RAISE ERR;
           END IF;

           -- 成人者ワーク中間データ作成
           I_RTN := FUNC_GET_JIDO_WK;
           IF I_RTN <> c_ISUCCESS THEN
           -- エラーで帰ってきた場合
               IF I_RTN = c_INOTFOUND THEN
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--                   B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
                 GOTO END_EXIT;
               END IF;
               RAISE ERR;
           END IF;

           -- 成人者ワーク作成
           I_RTN := FUNC_INSERT_JIDO_WK;
           IF I_RTN = c_INOT_SUCCESS THEN
           -- エラーで帰ってきた場合
               RAISE ERR;
           END IF;
--  2024/04/22 ZCZL.WUCAO DELETE 0.2.000.001:512_GKB_00027対応
--        END IF;

        -- 成人式中間データ作成（ＣＳＶ用）
        I_RTN := FUNCGET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
           -- エラーで帰ってきた場合
           -- ※ 終了処理は処理の内部で行っています
           RAISE ERR;
        END IF;

        --帳票出力CSVの作成
        CASE g_rJSTP.Chohyoid
          WHEN 'GKB400R001' THEN
            -- 成人式案内状ＣＳＶファイル作成
            I_RTN := FUNCSET_JIDO_WK_CSVFILE1;
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            -- ※ 終了処理は処理の内部で行っています
                RAISE ERR;
            END IF;

            bRTN :=FUNC_B11CSV('GKBWL400R001');
--  2024/10/28 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00323の対応
          --WHEN 'GKB400R002' THEN
          WHEN 'GKB130R002' THEN
              -- 成人式案内状発送者一覧表ＣＳＶファイル作成
            I_RTN := FUNCSET_JIDO_WK_CSVFILE2;
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            -- ※ 終了処理は処理の内部で行っています
                RAISE ERR;
            END IF;

            bRTN :=FUNC_B11CSV('GKBWL400R002');
          ELSE
            NULL;
        END CASE;

        --最後ロジックの実行
        --ROLLBACKの処理、と件数表の値、既存の最後更新、削除処理等
        IF g_nSTEP_INDEX = g_nSTEP_MAX THEN
           IF I_RTN <> 0 THEN
             RAISE ERR;
           END IF;
        END IF;
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/4
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
END GKBPB00330;
/