CREATE OR REPLACE PACKAGE BODY GKBPB00310
--1.0.200.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 成人宛名ラベル
--  機能概要      : 成人式出席対象者の宛名ラベルを作成する
--  バージョン    : Ver 1.0.200.000
--  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE 0.3.000.000:新WizLIFE２次開発
--  2024/10/14 ZCZL.WANGMING Update 0.3.000.001:仕様変更 IT_GKB_00044対応
--  2024/11/01 ZCZL.WANGYUNING Update 0.3.000.002:IT_GKB_00197対応
--  2025/01/15 JPJYS.YANGXIHAN UPDATE 0.3.000.003:学区マスタ関連修正方針対応
--  2025/09/17 CTC.Zhou UPDATE 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
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

    CURSOR CJIDO(p_NENDO IN NUMBER,
                 p_IKBN IN PLS_INTEGER,
                 p_ISANTEIDANTAI_CD IN PLS_INTEGER
--  2024/07/01 ZCZL.GUANJINGHENG ADD  START 0.3.000.000:新WizLIFE２次開発
                 ,p_ISEINENGAPIFROM IN PLS_INTEGER,
                 p_ISEINENGAPITO    IN  PLS_INTEGER
--  2024/07/01 ZCZL.GUANJINGHENG ADD  END
                ) IS

           SELECT KOJIN_CD,
                  SHIMEI_KANA,
                  SHIMEI_KANJI,
                  SEINENGAPI,
                  SEIBETU,
                  YUBIN_NO,
                  CHOMEI,
                  BANCHI,
                  KATAGAKI
                 ,SANTEIDANTAI_CD
                 ,GYOSEI_KU
                 ,SHOGAKO_KU_CD
                 ,TYUGAKO_KU_CD
                 ,GYOSEI_KU_CD
             FROM GKBTSEIJINSHA
            WHERE NENDO = p_NENDO
              AND ((p_ISANTEIDANTAI_CD <> 0 AND SANTEIDANTAI_CD = p_ISANTEIDANTAI_CD) OR
                    p_ISANTEIDANTAI_CD = 0)
--  2024/07/01 ZCZL.GUANJINGHENG DELETE  START 0.3.000.000:新WizLIFE２次開発
--              AND SYUKETSU_KBN = UPDATE(p_IKBN,1,1,DECODE(p_IKBN,2,0,SYUKETSU_KBN));
              AND SYUKETSU_KBN = DECODE(p_IKBN,1,1,DECODE(p_IKBN,2,0,SYUKETSU_KBN))
              AND ((p_ISEINENGAPIFROM <> 0 AND SEINENGAPI >= p_ISEINENGAPIFROM) OR
                    p_ISEINENGAPIFROM = 0)
              AND ((p_ISEINENGAPITO <> 0 AND SEINENGAPI <= p_ISEINENGAPITO) OR
                    p_ISEINENGAPITO = 0);
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE  END

    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- 処理結果
    c_ISUCCESS      CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS  CONSTANT  PLS_INTEGER := -1;        -- 異常
    c_INOTFOUND     CONSTANT  PLS_INTEGER := -9;        -- 該当なし
    -- 戻り値
    c_IERR          CONSTANT  PLS_INTEGER := 1;         --異常
    -- エラーメッセージの値
    c_VERR_MSG01    CONSTANT  NVARCHAR2(256) := '成人宛名ラベル作成処理が異常終了しました。';
    -- 成人者マスタ
    c_VTABLE        CONSTANT  NVARCHAR2(128) := 'GKBWSEIJINLABEL';
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    VKBN                     NVARCHAR2(15);
    IKBN                     PLS_INTEGER;
    ISAKUSEIBI               PLS_INTEGER;
    RA                       GABTATENAKIHON%ROWTYPE;
    RASO                     GABTSOFUSAKI%ROWTYPE;
    RAS                      GABTATENAKIHON%ROWTYPE;  -- 世帯主用
    RASOS                    GABTSOFUSAKI%ROWTYPE;
    IKISAI_JUNI              PLS_INTEGER;
    IMAX                     BINARY_INTEGER;
    ICNTM                    BINARY_INTEGER := 0;             -- 宛名レコードカウント
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN                     BOOLEAN;
    B_RTN                    BOOLEAN;
    I_RTN                    PLS_INTEGER;
    -- 処理条件（画面からの引数）
    VNENDO                   NVARCHAR2(15);      -- 対象年度
    VSANTEIDANTAI_CD         NVARCHAR2(2);       -- 算定団体コード
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
    VSEINENGAPIFROM          NVARCHAR2(100);     -- 生年月日(自)
    VSEINENGAPITO            NVARCHAR2(100);     -- 生年月日(至)
    ISEINENGAPIFROM          PLS_INTEGER;        -- 生年月日(自)
    ISEINENGAPITO            PLS_INTEGER;        -- 生年月日(至)
    o_SHOGAKU_CD             NVARCHAR2(1000);    -- 小学校区コード
    o_SHOGAKU_MEI            NVARCHAR2(1000);    -- 小学校区名
    o_CHUGAKU_CD             NVARCHAR2(1000);    -- 中学校区コード
    o_CHUGAKU_MEI            NVARCHAR2(1000);    -- 中学校区名
    TYPE MR_CRSEIJINSYA IS RECORD (KOJIN_CD               GKBTSEIJINSHA.KOJIN_CD%TYPE,
                                   SHIMEI_KANA            GKBTSEIJINSHA.SHIMEI_KANA%TYPE,
                                   SHIMEI_KANJI           GKBTSEIJINSHA.SHIMEI_KANJI%TYPE,
                                   SEINENGAPI             GKBTSEIJINSHA.SEINENGAPI%TYPE,
                                   SEIBETU                GKBTSEIJINSHA.SEIBETU%TYPE,
                                   YUBIN_NO               GKBTSEIJINSHA.YUBIN_NO%TYPE,
                                   CHOMEI                 GKBTSEIJINSHA.CHOMEI%TYPE,
                                   BANCHI                 GKBTSEIJINSHA.BANCHI%TYPE,
                                   KATAGAKI               GKBTSEIJINSHA.KATAGAKI%TYPE,
                                   SANTEIDANTAI_CD        GKBTSEIJINSHA.SANTEIDANTAI_CD%TYPE,
                                   GYOSEI_KU              GKBTSEIJINSHA.GYOSEI_KU%TYPE,
                                   SHOGAKO_KU_CD          GKBTSEIJINSHA.SHOGAKO_KU_CD%TYPE,
                                   TYUGAKO_KU_CD          GKBTSEIJINSHA.TYUGAKO_KU_CD%TYPE,
                                   GYOSEI_KU_CD           GKBTSEIJINSHA.GYOSEI_KU_CD%TYPE);
    CRS        MR_CRSEIJINSYA;
    g_nCOUNT      NUMBER := 0;
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
--  2024/07/01 ZCZL.GUANJINGHENG Update 0.3.000.000:新WizLIFE２次開発
--    NNUSHIKOJINNO            NUMBER(12);
    NNUSHIKOJINNO            NUMBER(15);
    VNUSHI_SHIMEI_KANA       NVARCHAR2(180);
    VNUSHI_SHIMEI_KANJI      NVARCHAR2(180);
    -- 取得したデータのワーク領域
    TYPE MRJIDO_TYPE IS RECORD
    (
      NENDO              GKBWSEIJINSHA.NENDO%TYPE,
      KAIPEJI_CD         GKBWSEIJINSHA.KAIPEJI_CD%TYPE,
      KAIPEJI            GKBWSEIJINSHA.KAIPEJI%TYPE,
      GYOSEIKU_CD        GKBWSEIJINSHA.GYOSEIKU_CD%TYPE,
      GYOSEIKUMEI        GKBWSEIJINSHA.GYOSEIKUMEI%TYPE,
      HAN_CD             GKBWSEIJINSHA.HAN_CD%TYPE,
      HANMEI             GKBWSEIJINSHA.HANMEI%TYPE,
      SANTEIDANTAI_CD    GKBWSEIJINSHA.SANTEIDANTAI_CD%TYPE,
      SANTEIDANTAIMEI    GKBWSEIJINSHA.SANTEIDANTAIMEI%TYPE,
      SHIMEI_KANA        GKBWSEIJINSHA.SHIMEI_KANA%TYPE,
      SEINENGAPI         GKBWSEIJINSHA.SEINENGAPI%TYPE,
      HYOJI_SEINENGAPI   GKBWSEIJINSHA.HYOJI_SEINENGAPI%TYPE,
      SEIBETSU           GKBWSEIJINSHA.SEIBETSU%TYPE,
      HYOJI_SEIBETSU     GKBWSEIJINSHA.HYOJI_SEIBETSU%TYPE,
      SETAI_NO           GKBWSEIJINSHA.SETAI_NO%TYPE,
      SAKUSEIBI          GKBWSEIJINSHA.SAKUSEIBI%TYPE,
      RENBAN             GKBWSEIJINSHA.RENBAN%TYPE,
      SHIMEI_KANJI       GKBWSEIJINSHA.SHIMEI_KANJI%TYPE,
      ZOKUGARAMEI        GKBWSEIJINSHA.ZOKUGARAMEI%TYPE,
      CHOMEI             GKBWSEIJINSHA.CHOMEI%TYPE,
      BANCHI             GKBWSEIJINSHA.BANCHI%TYPE,
      KATAGAKI           GKBWSEIJINSHA.KATAGAKI%TYPE,
      JUSHO_JODAN        GKBWSEIJINSHA.JUSHO_JODAN%TYPE,
      JUSHO_GEDAN        GKBWSEIJINSHA.JUSHO_GEDAN%TYPE,
      NUSI_SHIMEI_KANA   GKBWSEIJINLABEL.NUSHI_SHIMEI_KANA%TYPE,
      NUSI_SHIMEI_KANJI  GKBWSEIJINLABEL.NUSHI_SHIMEI_KANJI%TYPE,
      YUBIN_NO           GKBWSEIJINSHA.YUBIN_NO%TYPE,
      YUBIN_NOBC         GKBWSEIJINSHA.YUBIN_NOBC%TYPE,
      DATE1              GKBWSEIJINSHA.DATE1%TYPE,
      DATE2              GKBWSEIJINSHA.DATE2%TYPE,
      DATE3              GKBWSEIJINSHA.DATE3%TYPE,
      DATE4              GKBWSEIJINSHA.DATE4%TYPE,
      DATE5              GKBWSEIJINSHA.DATE5%TYPE,
      KOMOKU1            GKBWSEIJINSHA.KOMOKU1%TYPE,
      KOMOKU2            GKBWSEIJINSHA.KOMOKU2%TYPE,
      KOMOKU3            GKBWSEIJINSHA.KOMOKU3%TYPE,
      KOMOKU4            GKBWSEIJINSHA.KOMOKU4%TYPE,
      KOMOKU5            GKBWSEIJINSHA.KOMOKU5%TYPE,
      KOMOKU6            GKBWSEIJINSHA.KOMOKU6%TYPE,
      KOMOKU7            GKBWSEIJINSHA.KOMOKU7%TYPE,
      KOMOKU8            GKBWSEIJINSHA.KOMOKU8%TYPE,
      KOMOKU9            GKBWSEIJINSHA.KOMOKU9%TYPE,
      KOMOKU10           GKBWSEIJINSHA.KOMOKU10%TYPE,
      SHOGAKOKU_CD       GKBWSEIJINSHA.SHOGAKOKU_CD%TYPE,
      SHOGAKOMEI         GKBWSEIJINSHA.SHOGAKOMEI%TYPE,
      SEIRI_NO           GKBWSEIJINSHA.SEIRI_NO%TYPE,
      KOJIN_CD           GKBWSEIJINSHA.KOJIN_CD%TYPE,
      YUHEN_KBN          GKBWSEIJINSHA.YUHEN_KBN%TYPE,
      OAZA_CD            GKBWSEIJINSHA.OAZA_CD%TYPE,
      HONBAN             GKBWSEIJINSHA.HONBAN%TYPE,
      EDABAN1            GKBWSEIJINSHA.EDABAN1%TYPE,
      EDABAN2            GKBWSEIJINSHA.EDABAN2%TYPE,
      GENZON_KBN         GKBWSEIJINSHA.GENZON_KBN%TYPE,
      GENZON_KBN_MEI     GKBWSEIJINSHA.GENZON_KBN_MEI%TYPE,
      JINKAKU_KBN        GKBWSEIJINSHA.JINKAKU_KBN%TYPE,
      JINKAKU_KBN_MEI    GKBWSEIJINSHA.JINKAKU_KBN_MEI%TYPE,
      KISAI_JUNI         GKBWSEIJINSHA.KISAI_JUNI%TYPE,
      TYUGAKO_KU         GKBWSEIJINSHA.TYUGAKO_KU%TYPE,
      TEL_NO             GKBWSEIJINSHA.TEL_NO%TYPE,
      SYUKETSU_KBN       GKBWSEIJINSHA.SYUKETSU_KBN%TYPE,
      CHUGAKOKU_CD       GKBWSEIJINSHA.CHUGAKOKU_CD%TYPE,
      CHUGAKOMEI         GKBWSEIJINSHA.CHUGAKOMEI%TYPE,
      ATENA_YUBIN_NO     GKBWSEIJINSHA.ATENA_YUBIN_NO%TYPE,
      ATENA_CHOMEI       GKBWSEIJINSHA.ATENA_CHOMEI%TYPE,
      ATENA_BANCHI       GKBWSEIJINSHA.ATENA_BANCHI%TYPE,
      ATENA_KATAGAKI     GKBWSEIJINSHA.ATENA_KATAGAKI%TYPE,
      JUMIN_NAKUNARU_JIYU_MEI    GKBWSEIJINSHA.JUMIN_NAKUNARU_JIYU_MEI%TYPE,
      DOTEI_KBN                  GKBWSEIJINSHA.DOTEI_KBN%TYPE,
      NUSHI_GENZON_KBN           GKBWSEIJINSHA.NUSHI_GENZON_KBN%TYPE,
      NUSHI_KOJIN_NO             GKBWSEIJINSHA.NUSHI_KOJIN_NO%TYPE,
      KYOIKUKAI_MEI              GKBWSEIJINSHA.KYOIKUKAI_MEI%TYPE,
      KYOIKU_YAKUSHOKU_MEI       GKBWSEIJINSHA.KYOIKU_YAKUSHOKU_MEI%TYPE,
      KYOIKU_SHUTHOU_MEI         GKBWSEIJINSHA.KYOIKU_SHUTHOU_MEI%TYPE,
      KYOIKU_RITSU_MEI           GKBWSEIJINSHA.KYOIKU_RITSU_MEI%TYPE,
      KYOIKU_YUBIN_NO            GKBWSEIJINSHA.KYOIKU_YUBIN_NO%TYPE,
      KYOIKU_JUSHO               GKBWSEIJINSHA.KYOIKU_JUSHO%TYPE,
      KYOIKU_TEL                 GKBWSEIJINSHA.KYOIKU_TEL%TYPE,
      KYOIKU_TEL_NAISEN          GKBWSEIJINSHA.KYOIKU_TEL_NAISEN%TYPE,
      EDABAN3                    GKBWSEIJINSHA.EDABAN3%TYPE,
      GAIKU                      GKBWSEIJINSHA.GAIKU%TYPE,
      TOU                        GKBWSEIJINSHA.TOU%TYPE,
      GOU                        GKBWSEIJINSHA.GOU%TYPE
    );
    TYPE MTJIDO_TYPE IS TABLE OF MRJIDO_TYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK               MTJIDO_TYPE;

    -- 宛名作成のレコード
    TYPE MTATENA_REC IS RECORD
    (
     KAIPEJI_CD              NVarchar2(500),
     YUBIN_NO                NVarchar2(30),
     YUBIN_NOBC              NVarchar2(90),
--  2024/07/01 ZCZL.GUANJINGHENG Update start 0.3.000.000:新WizLIFE２次開発
--     CHOMEI                  NVarchar2(40),
--     BANCHI                  NVarchar2(40),
--     KATAGAKI                NVarchar2(60),
     CHOMEI                  NVarchar2(136),
     BANCHI                  NVarchar2(50),
     KATAGAKI                NVarchar2(300),
--  2024/07/01 ZCZL.GUANJINGHENG Update end
     NUSHI_SHIMEI_KANJI      NVarchar2(180),
     SHIMEI_KANJI            NVarchar2(110),
     YUBIN_NO2               NVarchar2(30),
     YUBIN_NOBC2             NVarchar2(90),
--  2024/07/01 ZCZL.GUANJINGHENG Update start 0.3.000.000:新WizLIFE２次開発
--     CHOMEI2                 NVarchar2(40),
--     BANCHI2                 NVarchar2(40),
--     KATAGAKI2               NVarchar2(60),
     CHOMEI2                 NVarchar2(136),
     BANCHI2                 NVarchar2(50),
     KATAGAKI2               NVarchar2(300),
--  2024/07/01 ZCZL.GUANJINGHENG Update end
     NUSHI_SHIMEI_KANJI2     NVarchar2(180),     
 -- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
--     SHIMEI_KANJI2           NVarchar2(110));
     SHIMEI_KANJI2           NVarchar2(110) ,
     YUHEN_KBN               NUMBER);
 -- 2025/09/17 CTC.Zhou Add End
     
    MATENA_REC               MTATENA_REC;

    g_VJYOUKEN01             NVARCHAR2(200);
    g_VJYOUKEN02             NVARCHAR2(200);
    g_VJYOUKEN03             NVARCHAR2(200);
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
    g_VJYOUKEN04             NVARCHAR2(200);
    g_VJYOUKEN05             NVARCHAR2(200);
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
    VSQLERRM                 NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
    VPAGEFD                  NVARCHAR2(500);    -- 改頁項目値
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        ARR DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        --対象年度
        g_VJYOUKEN01 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNendo');
        --作成区分
        ARR := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbSakuseiKbn');
        g_VJYOUKEN02 := ARR(1);
        --算定団体
        g_VJYOUKEN03 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSanteiDantai');
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
        --生年月日(自)
        g_VJYOUKEN04 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtBirStartYmd');
        --生年月日(至)
        g_VJYOUKEN05 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtBirEndYmd');
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
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
    --  機能概要      : 作成区分チェック
    --  パラメータ    : i_VKUBUN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
    --------------------------------------------------------
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
    END;
    --------------------------------------------------------
    --  機能概要      : 年度チェック
    --  パラメータ    : i_VNENDO
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
    --------------------------------------------------------
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
    END;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
        VMSG NVARCHAR2(4000);
        IRTN PLS_INTEGER;

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

        --対象年度のチェック
        IRTN := FUNCNENDOCHK( g_VJYOUKEN01 );
        IF IRTN <> 0 THEN
            VMSG := g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
        END IF;

        --作成区分のチェック
        IRTN := FUNCKUBUNCHK( g_VJYOUKEN02 );
        IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,作成区分が正しくありません。,;';
        END IF;
--  2024/10/14 ZCZL.WANGMING ADD START 0.3.000.001:仕様変更 IT_GKB_00044対応
        --生年月日(自)）の日付変換(KKAPK0020.FDateFmt)でエラーの場合
        bRTN := KKAPK0010.FISNUMERIC(g_VJYOUKEN04);
        IF bRTN THEN
          -- 生年月日(自)の日付チェック
          bRTN := KKAPK0020.FISDATEW(g_VJYOUKEN04);
          IF bRTN = FALSE THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（自）が正しくありません。,;';
          END IF;
        ELSE
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（自）が正しくありません。,;';
        END IF;

        --生年月日(至)の日付変換(KKAPK0020.FDateFmt)でエラーの場合
        bRTN := KKAPK0010.FISNUMERIC(g_VJYOUKEN05);
        IF bRTN THEN
          -- 生年月日(至)の日付チェック
          bRTN := KKAPK0020.FISDATEW(g_VJYOUKEN05);
          IF bRTN = FALSE THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（至）が正しくありません。,;';
          END IF;
        ELSE 
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（至）が正しくありません。,;';
        END IF;
        IF VMSG IS NULL THEN
           --変数.生年月日(自) > 変数.生年月日(至)の場合
           IF TO_NUMBER(g_VJYOUKEN04) > TO_NUMBER(g_VJYOUKEN05) THEN
             VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（自）、生年月日（至）の関係が正しくありません。,;';
           END IF;
        END IF;
--  2024/10/14 ZCZL.WANGMING ADD END
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
--  2024/07/01 ZCZL.GUANJINGHENG ADD 0.3.000.000:新WizLIFE２次開発
      nCNT                          NUMBER;
    BEGIN
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
        nCNT := GKBFKTBLCNT('GKBWSEIJINLABEL', NULL);
--  2024/11/01 ZCZL.WANGYUNING Update 0.3.000.002:仕様変更 IT_GKB_00044対応
        --g_oKENSU_LIST.EXTEND(2);
        g_oKENSU_LIST.EXTEND(3);
        g_oKENSU_LIST(1) := GKBEKENSU_RECORD(nCNT, '入力 成人者宛名ラベルワーク対象件数', 1);
        g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nCOUNT, '出力 成人者宛名ラベルワークＣＳＶ', 2);
--  2024/11/01 ZCZL.WANGYUNING ADD 0.3.000.002:IT_GKB_00197対応
        g_oKENSU_LIST(3) := GKBEKENSU_RECORD(MJIDO_WORK.COUNT, '出力 成人者宛名ラベルワークＣＳＶ対象件数', 2);
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
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
    --  機能概要      : 成人宛名ラベルワーク中間（GKBWSEIJINLABEL）レコードの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        IFRET             PLS_INTEGER;                -- 戻り値
        INENDO            PLS_INTEGER;                -- 年度
        ICNT              BINARY_INTEGER;             -- 戻り値
        IRTN              PLS_INTEGER;
        IATENA_FLG        PLS_INTEGER;                -- 宛名フラグ（[0]:宛名情報あり、[1]:宛名情報なし）
        ISANTEIDANTAI_CD  PLS_INTEGER;                -- 算定団体コード
    BEGIN
        IFRET := c_INOTFOUND;           -- 該当なし
        INENDO := TO_NUMBER(VNENDO);    -- 年度
        IKBN := TO_NUMBER(VKBN);        -- 作成区分
        IF VSANTEIDANTAI_CD IS NOT NULL THEN
          ISANTEIDANTAI_CD := TO_NUMBER(VSANTEIDANTAI_CD);  -- 算定団体コード
        ELSE
          ISANTEIDANTAI_CD := 0;
        END IF;
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
        ISEINENGAPIFROM := KKAPK0020.FNENDOHENKAN(VSEINENGAPIFROM);   -- 生年月日(自)
        ISEINENGAPITO := KKAPK0020.FNENDOHENKAN(VSEINENGAPITO);       -- 生年月日(至)
--  2024/07/01 ZCZL.GUANJINGHENG ADD END
        -- 対象年度を西暦に変換
        INENDO := KKAPK0020.FNENDO(INENDO,1);
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
            NNUSHIKOJINNO := 0;
            VNUSHI_SHIMEI_KANA  := ' ';
            VNUSHI_SHIMEI_KANJI := ' ';

            -- 成人者の個人番号より宛名情報取得
            IRTN := GAAPK0030.FGETATENA(CRS.KOJIN_CD,
                                      g_sGYOUMUCODE,
                                      ISAKUSEIBI,
                                      RA,
                                      RASO);
            --宛名フラグのセット
            IATENA_FLG := 1;
            IF CRS.KOJIN_CD <> 0 AND
               IRTN = 0 THEN
               -- 個人番号(GKBTSEIJINSHA:KOJIN_NO)がゼロでなく、その個人番号で宛名情報が取得できた場合
               IATENA_FLG := 0;    -- 宛名情報あり
            END IF;

            --宛名情報があるとき
            IF IATENA_FLG = 0 THEN
              MJIDO_WORK(ICNT).GYOSEIKU_CD := RA.GYOSEIKU_CD;
              MJIDO_WORK(ICNT).GYOSEIKUMEI := GAAPK0030.FGYOSEIKUMEI(RA.SANTEIDANTAI_CD,RA.GYOSEIKU_CD);
            ELSE
              MJIDO_WORK(ICNT).GYOSEIKU_CD := CRS.GYOSEI_KU_CD;
              MJIDO_WORK(ICNT).GYOSEIKUMEI := CRS.GYOSEI_KU;
            END IF;
            MJIDO_WORK(ICNT).HAN_CD := RA.HAN_CD;
            MJIDO_WORK(ICNT).SHIMEI_KANA := CRS.SHIMEI_KANA;
            MJIDO_WORK(ICNT).SEINENGAPI := CRS.SEINENGAPI;
            MJIDO_WORK(ICNT).SEIBETSU := CRS.SEIBETU;
            MJIDO_WORK(ICNT).SETAI_NO := RA.SETAI_NO;
            --宛名情報があるとき
            IF IATENA_FLG = 0 THEN
              MJIDO_WORK(ICNT).SANTEIDANTAI_CD := RA.SANTEIDANTAI_CD;
              --送付先住所の設定があるとき
              IF RASO.KOJIN_NO IS NOT NULL
                 AND (RASO.TEKIYO_BI <= ISAKUSEIBI)
                 AND (RASO.SHURYO_BI >= ISAKUSEIBI OR RASO.SHURYO_BI = 0) THEN
                IF RASO.YUBIN_NO IS NOT NULL THEN
                  MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(RASO.YUBIN_NO,1,3)||'-'||SUBSTR(RASO.YUBIN_NO,4);
                ELSE
                  MJIDO_WORK(ICNT).YUBIN_NO := NULL;
                END IF;
                MJIDO_WORK(ICNT).YUBIN_NOBC := RASO.YUBIN_NOBC;
                MJIDO_WORK(ICNT).CHOMEI := RASO.CHOMEI;
                MJIDO_WORK(ICNT).BANCHI := RASO.BANCHI;
                MJIDO_WORK(ICNT).KATAGAKI := RASO.KATAGAKI;
                IF RASO.SHIMEI_KANJI IS NOT NULL THEN
                  MJIDO_WORK(ICNT).SHIMEI_KANJI := RASO.SHIMEI_KANJI;
                ELSE
                  MJIDO_WORK(ICNT).SHIMEI_KANJI := RA.SHIMEI_KANJI;
                END IF;
                --沖縄県用ソート項目
                MJIDO_WORK(ICNT).YUHEN_KBN :=RASO.YUHEN_KBN;
                MJIDO_WORK(ICNT).OAZA_CD :=RASO.OAZA_CD;
                MJIDO_WORK(ICNT).HONBAN :=RASO.HONBAN;
                MJIDO_WORK(ICNT).EDABAN1 :=RASO.EDABAN1;
                MJIDO_WORK(ICNT).EDABAN2 :=RASO.EDABAN2;
                MJIDO_WORK(ICNT).EDABAN3 :=RASO.EDABAN3;
                MJIDO_WORK(ICNT).GAIKU   :=RASO.GAIKU;
                MJIDO_WORK(ICNT).TOU     :=RASO.TOU;
                MJIDO_WORK(ICNT).GOU     :=RASO.GOU;
              ELSE
                IF RA.YUBIN_NO IS NOT NULL THEN
                  MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(RA.YUBIN_NO,1,3)||'-'||SUBSTR(RA.YUBIN_NO,4);
                ELSE
                  MJIDO_WORK(ICNT).YUBIN_NO := NULL;
                END IF;
                MJIDO_WORK(ICNT).YUBIN_NOBC := RA.YUBIN_NOBC;
                MJIDO_WORK(ICNT).CHOMEI := RA.CHOMEI;
                MJIDO_WORK(ICNT).BANCHI := RA.BANCHI;
                MJIDO_WORK(ICNT).KATAGAKI := RA.KATAGAKI;
                MJIDO_WORK(ICNT).SHIMEI_KANJI := RA.SHIMEI_KANJI;
                --沖縄県用ソート項目
                MJIDO_WORK(ICNT).YUHEN_KBN :=RA.YUHEN_KBN;
                MJIDO_WORK(ICNT).OAZA_CD :=RA.OAZA_CD;
                MJIDO_WORK(ICNT).HONBAN :=RA.HONBAN;
                MJIDO_WORK(ICNT).EDABAN1 :=RA.EDABAN1;
                MJIDO_WORK(ICNT).EDABAN2 :=RA.EDABAN2;
                MJIDO_WORK(ICNT).EDABAN3 :=RA.EDABAN3;
                MJIDO_WORK(ICNT).GAIKU   :=RA.GAIKU;
                MJIDO_WORK(ICNT).TOU     :=RA.TOU;
                MJIDO_WORK(ICNT).GOU     :=RA.GOU;
              END IF;

              MJIDO_WORK(ICNT).GENZON_KBN :=RA.GENZON_KBN;
-- 2025/01/15 JPJYS.YANGXIHAN UPDATE 0.3.000.003:学区マスタ関連修正方針対応 STR			  
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発
                MJIDO_WORK(ICNT).CHUGAKOKU_CD := RA.CHUGAKU_CD;
                MJIDO_WORK(ICNT).SHOGAKOKU_CD := RA.SHOGAKU_CD;
              -- 共通関数（GKBFKGKKUGET）より学齢簿学校区を取得する。
--            I_RTN := GKBFKGKKUGET(RA.KOJIN_NO,RA.RIREKI_RENBAN,o_SHOGAKU_CD,o_SHOGAKU_MEI,o_CHUGAKU_CD,o_CHUGAKU_MEI);
--            IF I_RTN = 0 THEN
--                MJIDO_WORK(ICNT).CHUGAKOKU_CD := o_CHUGAKU_CD;
--                MJIDO_WORK(ICNT).SHOGAKOKU_CD := o_SHOGAKU_CD;
--            ELSE
--                MJIDO_WORK(ICNT).CHUGAKOKU_CD := NULL;
--                MJIDO_WORK(ICNT).SHOGAKOKU_CD := NULL;
--            END IF;
--  2024/07/01 ZCZL.GUANJINGHENG UPDATE END
-- 2025/01/15 JPJYS.YANGXIHAN UPDATE 0.3.000.003:学区マスタ関連修正方針対応 END
              IKISAI_JUNI := 0;
              BEGIN
                SELECT KISAI_JUNI INTO IKISAI_JUNI
                  FROM GABTJUKIIDO
                 WHERE KOJIN_NO = RA.KOJIN_NO;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  IKISAI_JUNI := 0;
              END;
              MJIDO_WORK(ICNT).KISAI_JUNI := IKISAI_JUNI;

              -- 世帯主取得共通サブルーチンから世帯主名を取得する
              IRTN := JIAPK0030.FGETNUSHI( ISAKUSEIBI,
                                              CRS.KOJIN_CD,
                                              NNUSHIKOJINNO,
                                              VNUSHI_SHIMEI_KANJI);
              --世帯主が取得できたとき
              IF IRTN <> 9 THEN
                 -- 世帯主の宛名情報を取得
                 IRTN := GAAPK0030.FGETATENA( NNUSHIKOJINNO,
                                            g_sGYOUMUCODE,
                                            ISAKUSEIBI,
                                            RAS,
                                            RASOS);
                 IF CRS.KOJIN_CD <> NNUSHIKOJINNO AND
                    NNUSHIKOJINNO <> 0 THEN
                   VNUSHI_SHIMEI_KANA  := RAS.SHIMEI_KANA;
                   VNUSHI_SHIMEI_KANJI := RAS.SHIMEI_KANJI ||'　様方';
                 ELSE
                   VNUSHI_SHIMEI_KANA  := ' ';
                   VNUSHI_SHIMEI_KANJI  := ' ';
                 END IF;
              ELSE
                 NNUSHIKOJINNO := 0;
                 VNUSHI_SHIMEI_KANA  := ' ';
                 VNUSHI_SHIMEI_KANJI  := ' ';
              END IF;
            ELSE
              MJIDO_WORK(ICNT).SANTEIDANTAI_CD := CRS.SANTEIDANTAI_CD;
              IF CRS.YUBIN_NO IS NOT NULL THEN
                MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(CRS.YUBIN_NO,1,3)||'-'||SUBSTR(CRS.YUBIN_NO,4);
              ELSE
                MJIDO_WORK(ICNT).YUBIN_NO := NULL;
              END IF;
              MJIDO_WORK(ICNT).YUBIN_NOBC := GAAPK0010.FCUSTOM_BC(CRS.YUBIN_NO,
                                                           CRS.CHOMEI,
                                                           CRS.BANCHI,
                                                           CRS.KATAGAKI);
              MJIDO_WORK(ICNT).CHOMEI := CRS.CHOMEI;
              MJIDO_WORK(ICNT).BANCHI := CRS.BANCHI;
              MJIDO_WORK(ICNT).KATAGAKI := CRS.KATAGAKI;
              MJIDO_WORK(ICNT).SHIMEI_KANJI := CRS.SHIMEI_KANJI;
              MJIDO_WORK(ICNT).CHUGAKOKU_CD := CRS.TYUGAKO_KU_CD;
              MJIDO_WORK(ICNT).SHOGAKOKU_CD := CRS.SHOGAKO_KU_CD;

              MJIDO_WORK(ICNT).YUHEN_KBN  := 9;          --郵返区分
              MJIDO_WORK(ICNT).OAZA_CD    := 999999;     --大字コード
              MJIDO_WORK(ICNT).HONBAN     := '99999';    --本番
              MJIDO_WORK(ICNT).EDABAN1    := '99999';    --枝１
              MJIDO_WORK(ICNT).EDABAN2    := '99999';    --枝２
              MJIDO_WORK(ICNT).EDABAN3    := '99999';    --枝３
              MJIDO_WORK(ICNT).GAIKU      := '99999';    --街区
              MJIDO_WORK(ICNT).TOU        := '99999';    --棟
              MJIDO_WORK(ICNT).GOU        := '99999';    --号
              MJIDO_WORK(ICNT).GENZON_KBN := 9;          --現存区分
              MJIDO_WORK(ICNT).KISAI_JUNI := 99;         --記載順位
            END IF;
            MJIDO_WORK(ICNT).KAIPEJI_CD := ' ';
            MJIDO_WORK(ICNT).NUSHI_KOJIN_NO    := NNUSHIKOJINNO;
            MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA  := VNUSHI_SHIMEI_KANA;
            MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI := VNUSHI_SHIMEI_KANJI;
            MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI := VNUSHI_SHIMEI_KANJI;
            ICNT := ICNT + 1;             -- カウントアップ
            IFRET := c_ISUCCESS;          -- 正常終了
          END LOOP;
        EXCEPTION
          WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        -- その他エラー
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------
    --  機能概要      : 成人宛名ラベルワーク（GKBWSEIJINLABEL）テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
    --------------------------------------------------------
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
        -- ワーク領域の件数分繰り返し処理を行う
        FOR ICNT IN IMIN..IMAX LOOP
            INSERT INTO
            GKBWSEIJINLABEL
            (
             GYOSEIKU_CD,
             HAN_CD,
             SANTEIDANTAI_CD,
             SHIMEI_KANA,
             SEINENGAPI,
             SEIBETSU,
             SETAI_NO,
             YUBIN_NO,
             CHOMEI,
             BANCHI,
             KATAGAKI,
             SHIMEI_KANJI,
             KAIPEJI_CD
            ,CHUGAKOKU_CD
            ,SHOGAKOKU_CD
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
            ,NUSHI_SHIMEI_KANA
            ,NUSHI_SHIMEI_KANJI
            )
            VALUES
            (
             MJIDO_WORK(ICNT).GYOSEIKU_CD,
             MJIDO_WORK(ICNT).HAN_CD,
             MJIDO_WORK(ICNT).SANTEIDANTAI_CD,
             MJIDO_WORK(ICNT).SHIMEI_KANA,
             MJIDO_WORK(ICNT).SEINENGAPI,
             MJIDO_WORK(ICNT).SEIBETSU,
             MJIDO_WORK(ICNT).SETAI_NO,
             MJIDO_WORK(ICNT).YUBIN_NO,
             MJIDO_WORK(ICNT).CHOMEI,
             MJIDO_WORK(ICNT).BANCHI,
             MJIDO_WORK(ICNT).KATAGAKI,
             MJIDO_WORK(ICNT).SHIMEI_KANJI,
             MJIDO_WORK(ICNT).KAIPEJI_CD
            ,MJIDO_WORK(ICNT).CHUGAKOKU_CD
            ,MJIDO_WORK(ICNT).SHOGAKOKU_CD
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
            ,MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA
            ,MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI
             );
        END LOOP;
        COMMIT;
        -- 終了
        RETURN IFRET;
    EXCEPTION
    -- その他エラー
        WHEN OTHERS THEN
            ROLLBACK;       -- 処理前に戻す
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------
    --  機能概要      : 成人宛名ラベル中間データ作成（ＣＳＶ用）
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
    --------------------------------------------------------
    FUNCTION FUNCGET_JIDO_WK_CSV RETURN NUMBER IS
        IFRET               PLS_INTEGER;                  -- 戻り値
        ICNT                BINARY_INTEGER;               -- カウント
        VSQLSEL             NVARCHAR2(9000);              -- ＳＱＬのソート以外
        ICUR                PLS_INTEGER;                  -- カーソル
        RREC                GKBWSEIJINSHA%ROWTYPE;        -- 成人式中間のレコード変数
        NROWS               NUMBER;
        IPAGECNT            PLS_INTEGER;                  -- 頁数
        IGYOCNT             PLS_INTEGER;                  -- 行番号
        IGYORENBAN          PLS_INTEGER;                  -- 行連番
        VPAGEWORK           NVARCHAR2(500);               -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(500);               -- 改頁項目値のワーク

    BEGIN
        IFRET := c_ISUCCESS; -- 正常終了
        VPAGEWORK := '';
        IPAGECNT := 0;
        IGYOCNT := 0;
        ICNT := 0;
        IGYORENBAN := 0;
        MJIDO_WORK.DELETE;   -- ワーク領域の初期化
        -- 改頁条件取得
        VPAGEFD :=' GYOSEIKU_CD ';
       
        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
            VSQLSEL := VSQLSEL || 'HAN_CD, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
            VSQLSEL := VSQLSEL || 'SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'CHOMEI, ';
            VSQLSEL := VSQLSEL || 'BANCHI, ';
            VSQLSEL := VSQLSEL || 'KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'CHUGAKOKU_CD, ';
            VSQLSEL := VSQLSEL || 'SHOGAKOKU_CD, ';
            VSQLSEL := VSQLSEL || VPAGEFD || ' PAGE_FIELD ';            -- 改頁値を設定
            VSQLSEL := VSQLSEL || ',YUBIN_NOBC ';
            VSQLSEL := VSQLSEL || ',NUSHI_KOJIN_NO ';
            VSQLSEL := VSQLSEL || ',NUSHI_SHIMEI_KANA ';
            VSQLSEL := VSQLSEL || ',NUSHI_SHIMEI_KANJI ';
 -- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
            VSQLSEL := VSQLSEL || ',YUHEN_KBN ';                               --郵返区分（沖縄県対応）
 -- 2025/09/17 CTC.Zhou Add End
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || c_VTABLE;
            IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
               VSQLSEL := VSQLSEL || ' ORDER BY ' || g_rJSTP.Orderbyclause;
            END IF;
            -- カーソルのオープン
            ICUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(ICUR, VSQLSEL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(ICUR,  1, RREC.GYOSEIKU_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  2, RREC.HAN_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  3, RREC.SANTEIDANTAI_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  4, RREC.SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  5, RREC.SEINENGAPI);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  6, RREC.SEIBETSU);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  7, RREC.SETAI_NO);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  8, RREC.YUBIN_NO, 30);
--  2024/07/01 ZCZL.GUANJINGHENG Update start 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(ICUR,  9, RREC.CHOMEI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 10, RREC.BANCHI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 11, RREC.KATAGAKI, 60);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  9, RREC.CHOMEI, 136);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 10, RREC.BANCHI, 50);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 11, RREC.KATAGAKI, 300);
--  2024/07/01 ZCZL.GUANJINGHENG Update end
            DBMS_SQL.DEFINE_COLUMN(ICUR, 12, RREC.SHIMEI_KANJI, 110);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 13, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 14, RREC.CHUGAKOKU_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 15, RREC.SHOGAKOKU_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 16, VPAGEFD,500 );
            DBMS_SQL.DEFINE_COLUMN(ICUR, 17, RREC.YUBIN_NOBC, 90);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 18, RREC.NUSHI_KOJIN_NO);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 19, RREC.NUSI_SHIMEI_KANA, 180);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 20, RREC.NUSI_SHIMEI_KANJI, 180);
 -- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
            DBMS_SQL.DEFINE_COLUMN(ICUR, 21, RREC.YUHEN_KBN);                             --郵返区分（沖縄県対応）
 -- 2025/09/17 CTC.Zhou Add End
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(ICUR);

            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(ICUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(ICUR,  1, MJIDO_WORK(ICNT).GYOSEIKU_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  2, MJIDO_WORK(ICNT).HAN_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  3, MJIDO_WORK(ICNT).SANTEIDANTAI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  4, MJIDO_WORK(ICNT).SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  5, MJIDO_WORK(ICNT).SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  6, MJIDO_WORK(ICNT).SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  7, MJIDO_WORK(ICNT).SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  8, MJIDO_WORK(ICNT).YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  9, MJIDO_WORK(ICNT).CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 10, MJIDO_WORK(ICNT).BANCHI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 11, MJIDO_WORK(ICNT).KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 12, MJIDO_WORK(ICNT).SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 13, MJIDO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 14, MJIDO_WORK(ICNT).CHUGAKOKU_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 15, MJIDO_WORK(ICNT).SHOGAKOKU_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 16, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 17, MJIDO_WORK(ICNT).YUBIN_NOBC);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 18, MJIDO_WORK(ICNT).NUSHI_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 19, MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 20, MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI);
 -- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
                    DBMS_SQL.COLUMN_VALUE(ICUR, 21, MJIDO_WORK(ICNT).YUHEN_KBN);              --郵返区分（沖縄県対応）
 -- 2025/09/17 CTC.Zhou Add End
                    IF VPAGEWORK = VPAGEFIELD THEN
                    -- 以前の改頁項目値と同じ
                        IGYOCNT := IGYOCNT + 1;
                        IGYORENBAN := IGYORENBAN + 1;
                    ELSE
                    -- 改頁必要
                        IPAGECNT := IPAGECNT + 1;
                        IGYOCNT := 1;
                        IGYORENBAN := 1;
                        VPAGEWORK := VPAGEFIELD;
                    END IF;
                    --改頁項目が何もない場合は何もセットしない
                    -- 再セットする項目
                    MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEFIELD;  -- 改頁コード

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
                IF DBMS_SQL.IS_OPEN(ICUR) THEN
                  DBMS_SQL.CLOSE_CURSOR(ICUR);
                END IF;
                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);  -- 処理ログの出力
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);  -- 処理ログの出力
        RETURN IFRET;
    END FUNCGET_JIDO_WK_CSV;
    --------------------------------------------------------
    --  機能概要      : 宛名レコードの作成
    --  パラメータ    : MATENA_REC
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
    --------------------------------------------------------
    FUNCTION FUNC_REC_ATENA(MATENA_REC OUT MTATENA_REC) RETURN NUMBER IS
        VHANTEI_CD          NVARCHAR2(500);
        IFRET               NUMBER;
    BEGIN
        IFRET := 0;

        -- ワーク領域の最終位置を取得
        IMAX := MJIDO_WORK.LAST;

        --宛名作成レコード初期化
        MATENA_REC.YUBIN_NO := ' ';
        MATENA_REC.CHOMEI := ' ';
        MATENA_REC.BANCHI := ' ';
        MATENA_REC.KATAGAKI := ' ';
        MATENA_REC.SHIMEI_KANJI := ' ';
        MATENA_REC.YUBIN_NO2 := ' ';
        MATENA_REC.CHOMEI2 := ' ';
        MATENA_REC.BANCHI2 := ' ';
        MATENA_REC.KATAGAKI2 := ' ';
        MATENA_REC.SHIMEI_KANJI2 := ' ';
        MATENA_REC.KAIPEJI_CD := ' ';
        MATENA_REC.YUBIN_NOBC := ' ';
        MATENA_REC.YUBIN_NOBC2 := ' ';
        MATENA_REC.NUSHI_SHIMEI_KANJI := ' ';
        MATENA_REC.NUSHI_SHIMEI_KANJI2 := ' ';

        MATENA_REC.KAIPEJI_CD := MJIDO_WORK(ICNTM).KAIPEJI_CD;
        MATENA_REC.YUBIN_NO := MJIDO_WORK(ICNTM).YUBIN_NO;
        MATENA_REC.YUBIN_NOBC := MJIDO_WORK(ICNTM).YUBIN_NOBC;
        MATENA_REC.CHOMEI := MJIDO_WORK(ICNTM).CHOMEI;
        MATENA_REC.BANCHI := MJIDO_WORK(ICNTM).BANCHI;
        MATENA_REC.KATAGAKI := MJIDO_WORK(ICNTM).KATAGAKI;
        MATENA_REC.SHIMEI_KANJI := MJIDO_WORK(ICNTM).SHIMEI_KANJI||'　様';
        MATENA_REC.NUSHI_SHIMEI_KANJI := MJIDO_WORK(ICNTM).NUSI_SHIMEI_KANJI;
        VHANTEI_CD := MJIDO_WORK(ICNTM).KAIPEJI_CD;
-- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
        MATENA_REC.YUHEN_KBN := MJIDO_WORK(ICNTM).YUHEN_KBN;
-- 2025/09/17 CTC.Zhou Add End
        ICNTM := ICNTM + 1;
        IF ICNTM > IMAX THEN
          RETURN IFRET;
        END IF;

        IF VHANTEI_CD <> MJIDO_WORK(ICNTM).KAIPEJI_CD THEN
          RETURN IFRET;
        ELSE
          MATENA_REC.YUBIN_NO2 := MJIDO_WORK(ICNTM).YUBIN_NO;
          MATENA_REC.YUBIN_NOBC2 := MJIDO_WORK(ICNTM).YUBIN_NOBC;
          MATENA_REC.CHOMEI2 := MJIDO_WORK(ICNTM).CHOMEI;
          MATENA_REC.BANCHI2 := MJIDO_WORK(ICNTM).BANCHI;
          MATENA_REC.KATAGAKI2 := MJIDO_WORK(ICNTM).KATAGAKI;
          MATENA_REC.SHIMEI_KANJI2 := MJIDO_WORK(ICNTM).SHIMEI_KANJI||'　様';
          MATENA_REC.NUSHI_SHIMEI_KANJI2 := MJIDO_WORK(ICNTM).NUSI_SHIMEI_KANJI;
          VHANTEI_CD := MJIDO_WORK(ICNTM).KAIPEJI_CD;
          ICNTM := ICNTM +1;
          IF ICNTM > IMAX THEN
            RETURN IFRET;
          END IF;
        END IF;
        RETURN IFRET;

    EXCEPTION
      WHEN OTHERS THEN
        RETURN IFRET;
    END FUNC_REC_ATENA;
    --------------------------------------------------------
    --  機能概要      : 成人宛名ラベルＣＳＶファイル作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
    --------------------------------------------------------
    FUNCTION FUNCSET_JIDO_WK_CSVFILE RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        IRTN                PLS_INTEGER;                -- 戻り値
        IMIN                PLS_INTEGER;                -- 最小値（出力件数）
        MATENA_REC          MTATENA_REC;
        rec_WL              GKBWL410R001%ROWTYPE;       --カーソルのレコード
        nROWNO              NUMBER := 0;

    BEGIN
        IFRET := c_ISUCCESS;               -- 正常終了
        IMAX := MJIDO_WORK.LAST;           -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;          -- ワーク領域の件数の最小値

        --ワークテーブルのデータを削除する
        DELETE FROM GKBWL410R001 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;

        -- 取得した件数分繰り返す
        LOOP

          IRTN := FUNC_REC_ATENA(MATENA_REC);

          rec_WL := NUll;
          nROWNO := nROWNO + 1;
--  2024/07/01 ZCZL.GUANJINGHENG ADD 0.3.000.000:新WizLIFE２次開発
          g_nCOUNT := nROWNO;
          rec_WL.NO := nROWNO;  --ソート順
 -- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
          rec_WL.KYOTSU_TSUSU_RENBAN    := LPAD(nROWNO, 6, '0');                       -- 業務共通_通数連番
          rec_WL.KYOTSU_PAGE_RENBAN     := NULL;                                       -- 業務共通_頁連番
          rec_WL.KYOTSU_DOFU_RENBAN     := NULL;                                       -- 業務共通_同封内連番
          rec_WL.KYOTSU_DOFU_MAISU      := NULL;                                       -- 業務共通_同封内枚数
          rec_WL.KYOTSU_YUBIN_K_KBN     := NULL;                                       -- 業務共通_郵便局区分
          rec_WL.KYOTSU_YUHEN_KBN       := MATENA_REC.YUHEN_KBN;                       -- 業務共通_郵返区分
          rec_WL.KYOTSU_CHOSHU_KBN      := NULL;                                       -- 業務共通_徴収区分
          rec_WL.KYOTSU_GAKKO_KBN       := NULL;                                       -- 業務共通_学校区分
          rec_WL.KYOTSU_YOBI_AREA1      := NULL;                                       -- 業務共通_予備エリア1
          rec_WL.KYOTSU_YOBI_AREA2      := NULL;                                       -- 業務共通_予備エリア2
          rec_WL.KYOTSU_YOBI_AREA3      := NULL;                                       -- 業務共通_予備エリア3
          rec_WL.KYOTSU_YOBI_AREA4      := NULL;                                       -- 業務共通_予備エリア4
          rec_WL.KYOTSU_YOBI_AREA5      := NULL;                                       -- 業務共通_予備エリア5
          rec_WL.KYOTSU_YOBI_AREA6      := NULL;                                       -- 業務共通_予備エリア6
          rec_WL.KYOTSU_YOBI_AREA7      := NULL;                                       -- 業務共通_予備エリア7
          rec_WL.KYOTSU_YOBI_AREA8      := NULL;                                       -- 業務共通_予備エリア8
          rec_WL.KYOTSU_YOBI_AREA9      := NULL;                                       -- 業務共通_予備エリア9
          rec_WL.KYOTSU_YOBI_AREA10     := NULL;                                       -- 業務共通_予備エリア10
          rec_WL.KYOTSU_YOBI_AREA11     := NULL;                                       -- 業務共通_予備エリア11
          rec_WL.KYOTSU_YOBI_AREA12     := NULL;                                       -- 業務共通_予備エリア12
-- 2025/09/17 CTC.Zhou Add End

          rec_WL.YUBIN_NO := MATENA_REC.YUBIN_NO;
          --郵便番号
          IF MATENA_REC.YUBIN_NO IS NOT NULL THEN
            rec_WL.YUBIN_NO := TRANSLATE( MATENA_REC.YUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
          ELSE
            rec_WL.YUBIN_NO := NULL;
          END IF;
          rec_WL.CHOMEI_BANCHI := MATENA_REC.CHOMEI || MATENA_REC.BANCHI;  --町名番地
          rec_WL.KATAGAKI := MATENA_REC.KATAGAKI;  --方書
          rec_WL.SHIMEI := MATENA_REC.SHIMEI_KANJI;  --氏名
          rec_WL.BC_NO := MATENA_REC.YUBIN_NOBC;  --カスタマバーコード
          rec_WL.NUSHI_SHIMEI_KANJI := MATENA_REC.NUSHI_SHIMEI_KANJI;  --世帯主氏名
          IF MATENA_REC.YUBIN_NO2 IS NOT NULL THEN
            rec_WL.YUBIN_NO2 := TRANSLATE( MATENA_REC.YUBIN_NO2, '1234567890-', '１２３４５６７８９０－' );
          ELSE
           rec_WL.YUBIN_NO2 := NULL;
          END IF;
          rec_WL.CHOMEI_BANCHI1 := MATENA_REC.CHOMEI2 || MATENA_REC.BANCHI2;  --町名番地０００１
          rec_WL.KATAGAKI2 := MATENA_REC.KATAGAKI2;  --方書０００１
          rec_WL.SHIMEI_KANJI2 := MATENA_REC.SHIMEI_KANJI2;  --氏名０００１
          rec_WL.YUBIN_NOBC2 := MATENA_REC.YUBIN_NOBC2;  --カスタマバーコード２
          rec_WL.NUSHI_SHIMEI_KANJI2 := MATENA_REC.NUSHI_SHIMEI_KANJI2;  --世帯主氏名０００１
          rec_WL.KAIPAGE_CD := MATENA_REC.KAIPEJI_CD;  --改頁コード
          rec_WL.BREAK_NO := MATENA_REC.KAIPEJI_CD;  --改ページキー
          rec_WL.WSNUM := g_sWSNUM;  --端末番号
          rec_WL.BATCHKBN := c_BATCH;  --即時バッチ区分
          rec_WL.JOBNUM := g_nJOBNUM;  --ジョブNO

          INSERT INTO GKBWL410R001 VALUES rec_WL;

          EXIT WHEN ICNTM > IMAX;
        END LOOP;

        -- 終了
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_CSVFILE', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);  -- 処理ログの出力
        RETURN IFRET;
    END FUNCSET_JIDO_WK_CSVFILE;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
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

        -- システム日付を西暦数値（YYYYMMDD形式）にする
        ISAKUSEIBI := TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));

        -- 取得した条件をそれぞれの変数へセット
        VNENDO := g_VJYOUKEN01;           -- 年度
        VKBN := g_VJYOUKEN02;             -- 作成区分
        VSANTEIDANTAI_CD := g_VJYOUKEN03; -- 算定団体コード
--  2024/07/01 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発
        VSEINENGAPIFROM := g_VJYOUKEN04;  -- 生年月日(自)
        VSEINENGAPITO := g_VJYOUKEN05;    -- 生年月日(至)
--  2024/07/01 ZCZL.GUANJINGHENG ADD END

        -- 成人宛名ラベルワーク（GKBWSEIJINLABEL）のデータ全件削除
        I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
        IF I_RTN = c_INOT_SUCCESS THEN
           GOTO ERROR_EXIT;
        END IF;

        -- 成人宛名ラベルワーク中間データ作成
        I_RTN := FUNC_GET_JIDO_WK;
--  2024/04/22 ZCZL.WUCAO UPDATE START 0.2.000.001:512_GKB_00027対応
--        IF I_RTN <> c_ISUCCESS AND I_RTN <> c_INOTFOUND THEN
        IF I_RTN <> c_ISUCCESS THEN
           IF I_RTN = c_INOTFOUND THEN
             GOTO END_EXIT;
           END IF;
--  2024/04/22 ZCZL.WUCAO UPDATE END
           GOTO ERROR_EXIT;
        END IF;

        -- 成人宛名ラベルワーク作成
        I_RTN := FUNC_INSERT_JIDO_WK;
        IF I_RTN = c_INOT_SUCCESS THEN
           GOTO ERROR_EXIT;
        END IF;

        -- 成人宛名ラベル中間データ作成（ＣＳＶ用）
        I_RTN := FUNCGET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
           GOTO ERROR_EXIT;
        END IF;

        -- 成人宛名ラベル中間ＣＳＶファイル作成
        I_RTN := FUNCSET_JIDO_WK_CSVFILE;

        <<ERROR_EXIT>>
        IF I_RTN <> c_ISUCCESS THEN
           RAISE eEXCEPTION;
        END IF;

        --帳票出力CSVの作成
        bRTN := FUNC_B11CSV('GKBWL410R001');
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/27
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
END GKBPB00310;
/
