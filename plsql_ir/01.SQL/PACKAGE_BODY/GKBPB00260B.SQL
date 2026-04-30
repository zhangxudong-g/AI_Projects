CREATE OR REPLACE PACKAGE BODY GKBPB00260
--1.0.404.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 宛名ラベル
--  機能概要      : 宛名ラベルと発送者一覧を作成する
--                  宛名は保護者と児童生徒のどちらにするか選択する事が可能
--                  保護者宛を作成する場合は児童生徒名を表示するかどうかを指定することが可能
--                  保護者が世帯主でない場合は、世帯主名を表示する
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--  2024/08/05 ZCZL.wangqiwei Update 0.3.000.001:検収指摘No.359の対応
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開とIT_GKB_00088の横展開
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00429対応横展開
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/20 YAMANI.SASAKI UPDATE 0.3.000.005:仕様変更　IT_GKB_00650対応
--  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応
--  2025/05/22 CTC.LIZIZHONG UPDATE 1.0.006.000:QA14807対応　
--  2025/12/17 CTC.HJF UPDATE 1.0.404.000:GKB_QA17301対応
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
-- 2024/06/11 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
    g_sSHIMEIJKN_CHOHYO  A_CONS_PRM;        -- インデックス番号
    g_sEQSHIMEI          A_CONS_PRM;        --本名・通称名　出力制御
    g_sATENA             NVARCHAR2(100);    --宛名ラベル_出力制御
    g_nGKB010_INDEX      NUMBER;
-- 2024/06/11 ZCZL.wangqiwei Add end

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;
    o_NBREAK         NUMBER(2):= 0;
    --パラメータ変数
    VMSG NVARCHAR2(4000);
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
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- 処理結果
    c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    c_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし
    -- 正常メッセージの値
    c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '宛名ラベル作成処理が正常終了しました。';
    -- エラーメッセージの値
    c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '宛名ラベル作成処理が異常終了しました。';
    -- 宛名マスタ
    c_VTABLE       CONSTANT  NVARCHAR2(128) := 'GKBWALABEL';
    -- １頁の最大行数
    c_IMAXROWS     CONSTANT  PLS_INTEGER := 15;
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    ISAKUSEIBI         PLS_INTEGER;
    RG                 GKBTGAKUREIBO%ROWTYPE;
    RA1                GABTATENAKIHON%ROWTYPE;
    RB1                GABTATENAKIHON%ROWTYPE;
    RB2                GABTSOFUSAKI%ROWTYPE;
    RA2                GABTSOFUSAKI%ROWTYPE;
    RB1_NULL           GABTATENAKIHON%ROWTYPE;
    RB2_NULL           GABTSOFUSAKI%ROWTYPE;
    -- 処理条件（画面からの引数）
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
    --g_VJYOUKEN01       NVARCHAR2(500);
    --g_VJYOUKEN02       NVARCHAR2(500);
    --g_VJYOUKEN03       NVARCHAR2(500);
    --g_VJYOUKEN04       NVARCHAR2(500);
    g_VJYOUKEN01       NVARCHAR2(3000);
    g_VJYOUKEN02       NVARCHAR2(3000);
    g_VJYOUKEN03       NVARCHAR2(3000);
    g_VJYOUKEN04       NVARCHAR2(3000);
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
    g_VJYOUKEN05       NVARCHAR2(500);
    g_VJYOUKEN06       NVARCHAR2(500);
    g_VJYOUKEN07       NVARCHAR2(500);
    g_VJYOUKEN08       NVARCHAR2(500);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
    --VSYOGAKO_CD        NVARCHAR2(100);            --小学校コード
    --VTYUGAKO_CD        NVARCHAR2(100);            --中学校コード
    --VKUIKIGAI_CD       NVARCHAR2(100);            --小学校コード   
    --VYOGOGAKO_CD       NVARCHAR2(100);            --盲聾養護学校コード
    VSYOGAKO_CD        NVARCHAR2(3000);            --小学校コード
    VTYUGAKO_CD        NVARCHAR2(3000);            --中学校コード
    VKUIKIGAI_CD       NVARCHAR2(3000);            --区域外学校コード
    VYOGOGAKO_CD       NVARCHAR2(3000);            --盲聾養護学校コード
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
--  2025/12/17 CTC.HJF UPDATE START 1.0.404.000:GKB_QA17301対応
    g_VJYOUKEN09       NVARCHAR2(500);
    VKUNISHIRITSU_CD   NVARCHAR2(3000);            --国私立学校コード
--  2025/12/17 CTC.HJF UPDATE END
    VGAKUNEN           NVARCHAR2(100);            --学年
    VRENBAN            NVARCHAR2(100);            --帳票連番使用有無
    VHAKOBI            NVARCHAR2(100);            --発行日
    IGAKUNEN           PLS_INTEGER;               --学年
    NRENBAN            NUMBER(1);                 --帳票連番使用有無
    NHAKOBI            NUMBER(16);                --発行日
-- 2024/06/05 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発
--     VNINIBIT           NVARCHAR2(100);            --任意ビット項目
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開とIT_GKB_00088の横展開
    --INUSHI_NO                     PLS_INTEGER;
    INUSHI_NO                     NUMBER;
    VNUSHI_NM                     NVARCHAR2(180);
    IMAX                          BINARY_INTEGER;
    ICNTM                         BINARY_INTEGER :=0;        -- 宛名レコードカウント
    VHOGOSHA_ZOKUGARA             NVARCHAR2(30);
    I_RTN_VHOGOSHA_ZOKUGARAHERR   PLS_INTEGER;
    VJIDO_ZOKUGARA                NVARCHAR2(30);
    I_RTN_VJIDO_ZOKUGARAHERR      PLS_INTEGER;
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN                     BOOLEAN;
    B_RTN                    BOOLEAN;
    I_RTN                    PLS_INTEGER;
    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWALABEL%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK               MTJIDO_TYPE;
    -- 宛名作成のレコード
    TYPE MTATENA_REC IS RECORD
    (
        KAIPEJI_CD            NVARCHAR2(500),
        YUBIN_NO              NVARCHAR2(10),
        CHOMEI                NVARCHAR2(40),
        BANCHI                NVARCHAR2(40),
        KATAGAKI              NVARCHAR2(60),
        NUSI_SHIMEI_KANJI     NVARCHAR2(110),
        ATENA_JODAN           NVARCHAR2(110),
        ATENA_GEDAN           NVARCHAR2(110),
        YUBIN_NOBC            NVARCHAR2(30),
        HYOJI_CHOHYO_NO       NVARCHAR2(90),
        YUBIN_NO2             NVARCHAR2(10),
        CHOMEI2               NVARCHAR2(40),
        BANCHI2               NVARCHAR2(40),
        KATAGAKI2             NVARCHAR2(60),
        NUSI_SHIMEI_KANJI2    NVARCHAR2(110),
        ATENA_JODAN2          NVARCHAR2(110),
        ATENA_GEDAN2          NVARCHAR2(110),
        YUBIN_NOBC2           NVARCHAR2(30),
        HYOJI_CHOHYO_NO2      NVARCHAR2(90)
    );
    MATENA_REC           MTATENA_REC;
    -- 宛名作成のレコード
    TYPE MTATENA__A_ITIRAN_REC IS RECORD
    (
         KAIPEJI_CD            NVARCHAR2(500),
         KAIPEJI               NVARCHAR2(500),
         RENBAN                NUMBER(6),
         GAKOKUMEI             NVARCHAR2(20),
         GAKOKUCD              NUMBER(5),
         SAKUSEIBI             NVARCHAR2(30),
         GYOSEIKUMEI           NVARCHAR2(20),
         JIDO_SHIMEI_JODAN     NVARCHAR2(100),
         JIDO_SHIMEI_GEDAN     NVARCHAR2(100),
--  2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--         JIDO_KOJIN_NO         NUMBER(12),
         JIDO_KOJIN_NO         NUMBER(15),
         HYOJI_SEINENGAPI      NVARCHAR2(11),
         HYOJI_SEIBETSU        NVARCHAR2(2),
-- 2024/06/05 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--         JIDO_CHOMEI           NVARCHAR2(40),
--         JIDO_BANCHI           NVARCHAR2(40),
--         JIDO_KATAGAKI         NVARCHAR2(60),
         JIDO_CHOMEI           NVARCHAR2(136),
         JIDO_BANCHI           NVARCHAR2(50),
         JIDO_KATAGAKI         NVARCHAR2(300),
-- 2024/06/05 ZCZL.wangqiwei Update end
         JIDO_YUBIN_NO         NVARCHAR2(10),
         HOGOSHA_SHIMEI_JODAN  NVARCHAR2(100),
         HOGOSHA_SHIMEI_GEDAN  NVARCHAR2(100),
         HOGOSHA_ZOKUGARAMEI   NVARCHAR2(30),
         JIDO_ZOKUGARAMEI      NVARCHAR2(30),
-- 2024/06/05 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--         HOGOSHA_CHOMEI        NVARCHAR2(40),
--         HOGOSHA_BANCHI        NVARCHAR2(40),
--         HOGOSHA_KATAGAKI      NVARCHAR2(60),
         HOGOSHA_CHOMEI        NVARCHAR2(136),
         HOGOSHA_BANCHI        NVARCHAR2(50),
         HOGOSHA_KATAGAKI      NVARCHAR2(30),
-- 2024/06/05 ZCZL.wangqiwei Update end
         HOGOSHA_YUBIN_NO      NVARCHAR2(10),
         KON_JUSHO_JODAN       NVARCHAR2(120),
         KON_JUSHO_GEDAN       NVARCHAR2(120),
         KIJUN_BI              NVARCHAR2(16),
         SEINENGAPI_KAISI      NVARCHAR2(2),
         SEINENGAPI_SYURYO     NVARCHAR2(2),
         JINKAKU_KBN           NUMBER(1)
    );
    MATENA_A_ITIRAN_REC           MTATENA__A_ITIRAN_REC;
    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    IWAREKI          PLS_INTEGER;
    ISEIREKI         PLS_INTEGER;
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
    -- 宛名ラベルの氏名出力制御用変数(KKAPK0030.FPRMSHUTOKU)
    ACONSPRM_ATENA              A_CONS_PRM;
    NLENGTH                     NUMBER;
    IRTN_ATENA                  PLS_INTEGER;
    NSHORIBI                    NUMBER;
    -- 旧自治体名称取得用変数(GAAPK0030.FJICHINAME)
    i_ISAN_CD  PLS_INTEGER;
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00429対応横展開
--    o_VSAN_KJ  NVARCHAR2(15);
    o_VSAN_KJ  GKBWALABEL.SANTEIDANTAIMEI%TYPE;
    -- 行政区名取得用変数(GAAPK0030.FGYOSEIKUMEI)
    i_SANTEIDANTAI_CD  PLS_INTEGER;
    i_GYOSEIKU_CD      PLS_INTEGER;
    VGYOSEIKU_MEI      NVARCHAR2(100);
    -- 基準日取得用変数(GKBPK00010.GKBFKJBGET)
    o_NISAKUSEIBI      NUMBER(8,0);           ------基準日
    -- 帳票連番印字項目の制御を取得する
    ACONSPRM_RENBAN             A_CONS_PRM;
    IRTN_RENBAN                 PLS_INTEGER;
    -- 処理条件チェック用戻る値
    IRTN                  PLS_INTEGER;
    ACONSPRM_SHIMEI       A_CONS_PRM;
    NLENGTH1              NUMBER;
    IRTN_SHIMEI           NUMBER;
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        v_cmbGakunen                DBMS_UTILITY.MAXNAME_ARRAY;
        v_cmbChohyoRenbanShiyoUmu   DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
        objShogakkoCd               DBMS_UTILITY.MAXNAME_ARRAY;
        objChugakkoCd               DBMS_UTILITY.MAXNAME_ARRAY;
        objKuikigaiGakkoCd          DBMS_UTILITY.MAXNAME_ARRAY;
        objTokubetsuShienGakkoCd    DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/14 ZCZL.WANGYUNING ADD END
--  2025/12/17 CTC.HJF UPDATE START 1.0.404.000:GKB_QA17301対応
        objKuniShiritsuGakkoCd    DBMS_UTILITY.MAXNAME_ARRAY; --国私立学校配列
--  2025/12/17 CTC.HJF UPDATE END
    BEGIN
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_VJYOUKEN01 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShogakkoCd');           --小学校コード
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtShogakkoCd');
        g_VJYOUKEN01 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShogakkoCd',0, objShogakkoCd);
        --g_VJYOUKEN02 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtChugakkoCd');           --中学校コード
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtChugakkoCd');
        g_VJYOUKEN02 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtChugakkoCd',0, objChugakkoCd);
        --g_VJYOUKEN03 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKuikigaiGakkoCd');      --区域外学校コード
        objKuikigaiGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKuikigaiGakkoCd');
        g_VJYOUKEN03 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuikigaiGakkoCd',0, objKuikigaiGakkoCd);
        --g_VJYOUKEN04 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtTokubetsuShienGakkoCd');--特別支援学校コード
        objTokubetsuShienGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtTokubetsuShienGakkoCd');
        g_VJYOUKEN04 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtTokubetsuShienGakkoCd',0, objTokubetsuShienGakkoCd);
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
        v_cmbGakunen  := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbGakunen');
        g_VJYOUKEN05 := v_cmbGakunen(1);                                          --学年
        v_cmbChohyoRenbanShiyoUmu  := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbChohyoRenbanShiyoUmu');
        g_VJYOUKEN06 := v_cmbChohyoRenbanShiyoUmu(1);                             --帳票連番使用有無
        g_VJYOUKEN07 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKijunBi');               --基準日
        g_VJYOUKEN08 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNiniBit');               --任意ビット
--  2025/12/17 CTC.HJF UPDATE START 1.0.404.000:GKB_QA17301対応
        --国私立学校
        objKuniShiritsuGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKuniShiritsuGakkoCd');
        g_VJYOUKEN09 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuniShiritsuGakkoCd',0, objKuniShiritsuGakkoCd);
--  2025/12/17 CTC.HJF UPDATE END
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
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
    --（発行日）日付チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2, i_IRENBAN IN NVARCHAR2) RETURN NUMBER IS
    IRET PLS_INTEGER;
    BRET BOOLEAN;
    TEMP_DATE DATE;
    BEGIN
      IRET := 0;
      --日付
      BEGIN
        IF i_IRENBAN = '1' AND i_VHIZUKE IS NOT NULL THEN
           IF LENGTH(i_VHIZUKE) <> 7 THEN
              IRET := 1;
           ELSE
              IWAREKIHIDUKEIO  := TO_NUMBER(i_VHIZUKE);
              ISEIREKIHIDUKEIO := 0;
           END IF;
        END IF;

      IF IRET = 0 AND LENGTH(IWAREKIHIDUKEIO) = 7 AND i_IRENBAN = '1'  THEN
        BRET := KKAPK0020.FDAYEDIT(IWAREKIHIDUKEIO, ISEIREKIHIDUKEIO,
                                    VEDIT1O, VEDIT2O, VEDIT3O,
                                    VGENGOKANJIO, VGENGOKIGOO,
                                    IWAREKINENO, ISEIREKINENO,
                                    IWAREKINENGETUO, ITUKIO, IDAYO,
                                    IWAREKIHIDUKEO, ISEIREKIHIDUKEO);
          TEMP_DATE := TO_DATE(ISEIREKIHIDUKEIO,'YYYYMMDD');
        IF BRET = FALSE THEN
          IRET := 1;
        END IF;
      END IF;

      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      RETURN(IRET);
    END;
    ----------------------------------------------------------------------------------------------------
    --任意ビット項目チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCNINIBITCHK( i_NINIBIT IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    NINIBITSU PLS_INTEGER;
    GAKO_CD NUMBER;
    BEGIN
      IRET := 0;
      BEGIN
        IF i_NINIBIT IS NOT NULL THEN
                 NINIBITSU := LENGTH(i_NINIBIT)/4;
                 IF (LENGTH(i_NINIBIT)-NINIBITSU*4) <> 0 THEN
                    IRET := 1;
                 ELSE
                   FOR K IN 1..NINIBITSU LOOP
                     GAKO_CD := TO_NUMBER(SUBSTR(i_NINIBIT,4*K-3,4));
                   END LOOP;
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
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

--  2024/11/14 ZCZL.WANGYUNING DALETE START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
        --条件１のチェック
        --IRTN := GKBPK00010.FGCODCHK( g_VJYOUKEN01 );
        --IF IRTN <> 0 THEN
        --    VMSG := VMSG || 'GKB,99999,小学校コードが正しくありません。,;';
        --END IF;
--
        ----条件２のチェック
        --IRTN := GKBPK00010.FGCODCHK( g_VJYOUKEN02 );
        --IF IRTN <> 0 THEN
        --    VMSG := VMSG || 'GKB,99999,中学校コードが正しくありません。,;';
        --END IF;
--
        ----条件３のチェック
        --IRTN := GKBPK00010.FGCODCHK( g_VJYOUKEN03 );
        --IF IRTN <> 0 THEN
        --    --'条件３：区域外コードが正しくありません。'
        --    VMSG := VMSG || 'GKB,99999,区域外学校コードが正しくありません。,;';
        --END IF;
--
        ----条件４のチェック
        --IRTN := GKBPK00010.FGCODCHK( g_VJYOUKEN04 );
        --IF IRTN <> 0 THEN
        --    --'条件４：盲聾養護コードが正しくありません。'
        --    VMSG := VMSG || 'GKB,99999,特別支援学校コードが正しくありません。,;';
        --END IF;
--  2024/11/14 ZCZL.WANGYUNING DALETE END

        --条件５のチェック
        IRTN := GKBPK00010.FGKNCHK( g_VJYOUKEN05 );
        IF IRTN <> 0 THEN
            VMSG := VMSG || 'GKB,99999,学年が正しくありません。,;';
        END IF;

        --条件６のチェック
        IRTN := GKBPK00010.FRBCHK( g_VJYOUKEN06 );
        IF IRTN <> 0 THEN
            VMSG := VMSG || 'GKB,99999,帳票連番使用有無が正しくありません。,;';
        END IF;

        --条件７のチェック
        IRTN := FUNCHIZUKECHK( g_VJYOUKEN07,g_VJYOUKEN06 );
        IF IRTN <> 0 THEN
            VMSG := VMSG || 'GKB,99999,発行日が正しくありません。,;';
        END IF;

        --条件８のチェック
        IRTN := FUNCNINIBITCHK( g_VJYOUKEN08 );
        IF IRTN <> 0 THEN
            VMSG := VMSG || 'GKB,99999,任意ビットが正しくありません。,;';
        END IF;
        o_vRESULT := VMSG;

    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
    --------------------------------------------------------
    --  機能概要      : 処理ログ出力
    --  パラメータ      : i_sGAKOCD       編集前学校コード
    --              : o_sGAKOCD       編集後学校コード
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.001
    --  作成者／作成日: ZCZL.WANGQIWEI   2024/08/02
    --------------------------------------------------------
-- 2024/08/05 ZCZL.WANGQIWEI Add start 0.3.000.001:検収指摘No.359の対応
    FUNCTION FUNC_GET_GAKOCD(i_sGAKOCD IN NVARCHAR2, o_sGAKOCD OUT NVARCHAR2) RETURN BOOLEAN
    IS
        aGAKOCD           KKBPK5551.tySPLIT_tbl;      -- 業務コード（リスト）
--  2024/11/14 ZCZL.WANGYUNING ADD 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
        nGAKOUCD_TMP  NUMBER; --学校コード
    BEGIN
        -- 入力引数を分解して配列にセットする
        -- 引数の業務コード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
        -- 処理ステップを取得
        --FOR i IN 1..aGAKOCD.COUNT LOOP
        --  IF MOD(i - 1, 2) = 0 AND aGAKOCD.COUNT > 2 THEN
        --    IF i = aGAKOCD.COUNT - 1 THEN
        --      o_sGAKOCD := o_sGAKOCD || aGAKOCD(i);
        --    ELSE
        --      o_sGAKOCD := o_sGAKOCD || aGAKOCD(i) || ',';
        --    END IF;
        --  ELSIF aGAKOCD.COUNT = 2 THEN
        --    o_sGAKOCD := aGAKOCD(1);
        --  ELSE
        --    NULL;
        --  END IF;
        --END LOOP;
        o_sGAKOCD := '';
        FOR i IN 1..aGAKOCD.COUNT LOOP
            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
            IF nGAKOUCD_TMP IS NOT NULL THEN
                IF i = aGAKOCD.COUNT THEN
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP ;
                ELSE
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP || ',';
                END IF;
            END IF;
        END LOOP;
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_GET_GAKOCD;
-- 2024/08/05 ZCZL.WANGQIWEI Add end
    --------------------------------------------------------
    --  機能概要      : バッチジョブステップテーブルの更新処理
    --  パラメータ    : i_UPD_KBN       更新区分
    --                : i_STEPRTNCODE   実行結果コード
    --                : i_CSV_RCNT      CSV出力件数
    --                : i_CSVFILENAME   CSVファイル名
    --                : i_PRTFILENAME   出力ファイル名
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
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
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 4 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 5 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 6 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSE
        NSEIGYO_OUT_FLG := 4;
      END IF;
       <<SHORI>>
      IF NSEIGYO_OUT_FLG = 1 THEN
        IF  VHONMYO_DATA IS NOT NULL THEN
           VRETURN := VHONMYO_DATA;
        ELSE
           VRETURN := VSHIMEI_DATA;
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
    --------------------------------------------------------------------------------
    -- 宛名ラベルワーク中間（GKBWALABEL）レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;           -- 戻り値
        ICNT                BINARY_INTEGER;        -- 戻り値
        NPRTN               NUMBER;
        I_RTN               PLS_INTEGER;
        BRTN                BOOLEAN;
        IRET                PLS_INTEGER;
        NNINIBIT_KISU       NUMBER(2);             ------任意ビット項目の数量
        NNINIBIT_SYUBETU    NUMBER(2);             ------任意ﾋﾞｯﾄ種別(Xより値が変わる)
        NNINIBIT_ATAI       NUMBER(2);             ------任意ﾋﾞｯﾄ値(Xより値が変わる)
        X                   NUMBER(2);             ------[NINIBITX]のX
        NTIMES              NUMBER(2);             ------任意ビットの文字列を分割するためのLOOP回数
        KOJIN_NO            GABTATENAKIHON.KOJIN_NO%TYPE;
        RIREKI_RENBAN       GABTATENAKIHON.RIREKI_RENBAN%TYPE;
-- 2024/06/05 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発の標準化対応 
        RIREKI_RENBAN_EDA   GKBTGAKUREIBO.RIREKI_RENBAN_EDA%TYPE;
        VSQLSEL             VARCHAR2(2000);
        VGAKOMEI            NVARCHAR2(60);
        NHAKOBI2            NUMBER(16);            --発行日
-- 2024/06/05 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--        VKON_JUSHO          NVARCHAR2(140);        ----住所
        VKON_JUSHO          NVARCHAR2(486);        ----住所
        VKON_JUSHO_JODAN    NVARCHAR2(20);         ----住所上段
        VKON_JUSHO_GEDAN    NVARCHAR2(120);        ----住所下段
        NSHIMEI_KANJI       NVARCHAR2(110);        ----氏名漢字
        N_NAIYO_CD_JIDO             GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;
        N_INUSHI_JINGAKU            NUMBER := 0;
        VEDIT_GO_DATA               NVARCHAR2(1000) := '';
        RA                          GABTATENAKIHON%ROWTYPE;
        RASO                        GABTSOFUSAKI%ROWTYPE;
        IRTN                        NUMBER := 1;
        NKOJIN_NO                   NUMBER;
        o_RATENA_REC   GABTATENAKIHON%ROWTYPE;
        o_RSOFU_REC    GABTSOFUSAKI%ROWTYPE;
        TYPE TYPECURSOR  IS REF CURSOR;
        CRATENA            TYPECURSOR;
-- 2024/06/05 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発の標準化対応 
        o_sSHIMEIKANA           NVARCHAR2(100); --氏名カナ
        o_sSHIMEI               NVARCHAR2(100); --氏名漢字
        o_sBIRTHDAY             NVARCHAR2(100); --生年月日
        o_SHIMEIKANA            NVARCHAR2(100); --氏名カナ
        o_SHIMEI                NVARCHAR2(100); --氏名漢字
        o_BIRTHDAY              NVARCHAR2(100); --生年月日
        o_HOGOSHA_SHIMEI_KANA   NVARCHAR2(100); --保護者氏名かな
        --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
        o_HOGOSHA_SHIMEI_KANJI  NVARCHAR2(100); --保護者氏名漢字
        --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
        o_NUSI_SHIMEI_KANJI     NVARCHAR2(110); --世帯主氏名漢字
-- 2024/06/11 ZCZL.wangqiwei Add end
    BEGIN
        IFRET := c_INOTFOUND;               -- 該当なし
        NSHIMEI_KANJI := NULL;              --氏名漢字
        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        ICNT := 0;
        -- 処理条件の学年に該当する個人番号を学年リンクより検索
        BEGIN
          -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
          ISEIREKI := NULL;
          IWAREKI := NHAKOBI;
          BRTN := KKAPK0020.FDAYEDIT(IWAREKI,  ISEIREKI,
                                  VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                  VEDIT_GYYMMDD3, VKJ_GENGO,
                                  VKG_GENGO,      IWAREKI_YY,
                                  ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                  IMM,            IDD,
                                  IWAREKIHIZUKE,  ISEIREKIHIZUKE );
          NHAKOBI2 := ISEIREKI;
          I_RTN := GKBPK00010.FKJBGET(NHAKOBI2,NRENBAN,o_NISAKUSEIBI);
          IF I_RTN = 1 THEN
              -- 処理ログの出力
              B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 0, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
              RETURN IFRET;
          END IF;
          ISAKUSEIBI := o_NISAKUSEIBI;
          NTIMES := 0;
          X := 0;
          VSQLSEL := '';
          VSQLSEL := VSQLSEL || 'SELECT ';
          VSQLSEL := VSQLSEL || 'A.KOJIN_NO, ';
          VSQLSEL := VSQLSEL || 'A.RIREKI_RENBAN ';
-- 2024/06/26 ZCZL.wangqiwei Add  0.3.000.000:新WizLIFE2次開発の標準化対応
          VSQLSEL := VSQLSEL || ' ,A.RIREKI_RENBAN_EDA ';
          VSQLSEL := VSQLSEL || 'FROM ';
          VSQLSEL := VSQLSEL || 'GKBTGAKUREIBO A, ';
-- 2024/06/26 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発の標準化対応
--           VSQLSEL := VSQLSEL || 'GKBTNINIBIT B,';
          VSQLSEL := VSQLSEL || '(SELECT KOJIN_NO,MAX(RIREKI_RENBAN) AS RIREKI_RENBAN ';
          VSQLSEL := VSQLSEL || 'FROM GKBTGAKUREIBO ';
          VSQLSEL := VSQLSEL || 'WHERE SHORIBI<='|| ISAKUSEIBI;
          VSQLSEL := VSQLSEL || ' GROUP BY KOJIN_NO) C ';
          VSQLSEL := VSQLSEL || ' WHERE  ';
          VSQLSEL := VSQLSEL || 'C.KOJIN_NO =A.KOJIN_NO ';
          VSQLSEL := VSQLSEL || 'AND C.RIREKI_RENBAN =A.RIREKI_RENBAN ';
-- 2024/06/26 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発の標準化対応
--           VSQLSEL := VSQLSEL || 'AND C.KOJIN_NO =B.KOJIN_NO ';
--           VSQLSEL := VSQLSEL || 'AND C.RIREKI_RENBAN =B.RIREKI_RENBAN ';
-- 2024/06/26 ZCZL.wangqiwei Delete end 
          VSQLSEL := VSQLSEL || 'AND A.GAKUNEN ='|| IGAKUNEN;
          IF VSYOGAKO_CD IS NOT NULL OR VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR
--  2025/12/17 CTC.HJF UPDATE START 1.0.404.000:GKB_QA17301対応
             --VYOGOGAKO_CD IS NOT NULL THEN
             VYOGOGAKO_CD IS NOT NULL OR VKUNISHIRITSU_CD IS NOT NULL THEN
--  2025/12/17 CTC.HJF UPDATE END
            VSQLSEL := VSQLSEL || ' AND (';
            IF VSYOGAKO_CD IS NOT NULL THEN
               IF VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR  VYOGOGAKO_CD IS NOT NULL THEN
                    VSQLSEL := VSQLSEL || 'A.SYOGAKO_CD IN ('|| VSYOGAKO_CD ||')  OR ';
               ELSE
                    VSQLSEL := VSQLSEL || 'A.SYOGAKO_CD IN ('|| VSYOGAKO_CD ||')';
               END IF;
            END IF;
            IF VTYUGAKO_CD IS NOT NULL THEN
               IF VKUIKIGAI_CD IS NOT NULL OR   VYOGOGAKO_CD IS NOT NULL THEN
                    VSQLSEL := VSQLSEL || 'A.TYUGAKO_CD IN ('|| VTYUGAKO_CD ||') OR ';
               ELSE
                    VSQLSEL := VSQLSEL || 'A.TYUGAKO_CD IN ('|| VTYUGAKO_CD ||')';
               END IF;
            END IF;
            IF VKUIKIGAI_CD IS NOT NULL THEN
               IF VYOGOGAKO_CD IS NOT NULL THEN
                    VSQLSEL := VSQLSEL || 'A.KUIKIGAI_CD IN ('|| VKUIKIGAI_CD ||') OR ';
               ELSE
                    VSQLSEL := VSQLSEL || 'A.KUIKIGAI_CD IN ('|| VKUIKIGAI_CD ||')';
               END IF;
            END IF;
            IF VYOGOGAKO_CD IS NOT NULL THEN
                VSQLSEL := VSQLSEL || 'A.YOGOGAKO_CD IN ('|| VYOGOGAKO_CD ||') ';
            END IF;
--  2025/12/17 CTC.HJF UPDATE START 1.0.404.000:GKB_QA17301対応
            IF VKUNISHIRITSU_CD IS NOT NULL THEN
                    VSQLSEL := VSQLSEL || ' OR A.KUNISHIRITSU_CD IN ('|| VKUNISHIRITSU_CD ||') ';
            END IF;
--  2025/12/17 CTC.HJF UPDATE END
            VSQLSEL := VSQLSEL || ' )';
          END IF;
-- 2024/06/05 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発の標準化対応 
--           IF VNINIBIT IS NOT NULL THEN
--              NNINIBIT_KISU := LENGTH(VNINIBIT)/4;        ------任意ビット項目の数量を取得
--              NNINIBIT_SYUBETU := TO_NUMBER(SUBSTR(VNINIBIT,1,2));     ----上2桁(種別)
--              NNINIBIT_ATAI := TO_NUMBER(SUBSTR(VNINIBIT,3,2));        ----下2桁（値）
--              X := NNINIBIT_SYUBETU+1;
--                  FOR NTIMES IN 1..NNINIBIT_KISU LOOP
--               NNINIBIT_SYUBETU := TO_NUMBER(SUBSTR(VNINIBIT,4*NTIMES-3,2));
--               NNINIBIT_ATAI := TO_NUMBER(SUBSTR(VNINIBIT,4*NTIMES-1,2));
--                       X := NNINIBIT_SYUBETU+1;
--                        IF NTIMES = 1 THEN
--                            VSQLSEL := VSQLSEL || ' AND ( B.NINIBIT'||X||' = ' || NNINIBIT_ATAI;
--                        ELSE
--                            VSQLSEL := VSQLSEL || ' OR  B.NINIBIT'||X||' = ' || NNINIBIT_ATAI;
--                        END IF;
--              END LOOP;
--           VSQLSEL :=  VSQLSEL ||')';
--           END IF;
-- 2024/06/05 ZCZL.wangqiwei Delete end
            OPEN CRATENA  FOR VSQLSEL;
            LOOP
-- 2024/06/05 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応 
--                 FETCH  CRATENA INTO KOJIN_NO,RIREKI_RENBAN;
                FETCH  CRATENA INTO KOJIN_NO,RIREKI_RENBAN,RIREKI_RENBAN_EDA;
                EXIT WHEN CRATENA%NOTFOUND;
                  -- 児童生徒個人番号より学齢簿情報を検索 RIREKI_RENBAN_EDA
-- 2024/06/05 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応 
--               GKBSKJDOG2(KOJIN_NO,RIREKI_RENBAN ,RG,NPRTN); 
               GKBSKJDOG2(KOJIN_NO,RIREKI_RENBAN ,RIREKI_RENBAN_EDA ,RG,NPRTN);
              IF NPRTN = 0 AND
                 RG.GEN_JIYU_CD = 0 THEN
                     -- 児童生徒個人番号より宛名情報取得
                          I_RTN := GAAPK0030.FGETATENA( KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RA1,
                                                RA2 );
                     IF RG.HOGOSYA_KOJIN_NO <> 0 THEN
                       I_RTN := GAAPK0030.FGETATENA( RG.HOGOSYA_KOJIN_NO,
                                                  'GKB',
                                                  ISAKUSEIBI,
                                                  RB1,
                                                  RB2 );
                     ELSE
                              RB1 := RB1_NULL;
                              RB2 := RB2_NULL;
                              VNUSHI_NM := '';
                          RB1.SHIMEI_KANA := NULL;
                          RB1.CHOMEI := NULL;
                          RB1.BANCHI := NULL;
                          RB1.KATAGAKI := NULL;
                          RB1.SHIMEI_KANJI := NULL;
                     END IF;
                             IF  ACONSPRM_ATENA(1) IN (1,3) THEN
                                -- 保護者個人番号から世帯主情報を取得
                              IRET := JIAPK0030.FGETNUSHI(ISAKUSEIBI, KOJIN_NO, INUSHI_NO, VNUSHI_NM);
                              IF IRET <> c_ISUCCESS THEN
                                 INUSHI_NO := '0';
                                   VNUSHI_NM := '';
                               END IF;
                              ELSE
                                 -- 児童生徒個人番号から世帯主情報を取得
                                  IRET := JIAPK0030.FGETNUSHI(ISAKUSEIBI, RG.HOGOSYA_KOJIN_NO, INUSHI_NO, VNUSHI_NM);
                                  IF IRET <> c_ISUCCESS THEN
                                     INUSHI_NO := '0';
                                     VNUSHI_NM := '';
                             END IF;
                           END IF;
 -- 2024/06/11 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
               -- 本名使用制御判定のOUT引数を取得
               IF GKBFKHMCTRL(RG.KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_sATENA, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN 
                  o_SHIMEIKANA := o_sSHIMEIKANA;
                  o_SHIMEI     := o_sSHIMEI;
                  o_BIRTHDAY   := o_sBIRTHDAY;
               END IF;
               IF GKBFKHMCTRL(RG.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_sATENA, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN 
                  o_HOGOSHA_SHIMEI_KANA := o_sSHIMEIKANA;
                  --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
                  o_HOGOSHA_SHIMEI_KANJI := o_sSHIMEI;
                  --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
               END IF;
               IF GKBFKHMCTRL(INUSHI_NO, g_rJSTP.CHOHYOID, 1, g_sATENA, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN 
               --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
                 IF o_sSHIMEI IS NOT NULL THEN
               --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
                  o_NUSI_SHIMEI_KANJI := o_sSHIMEI;
               --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
                 ELSE
                   o_NUSI_SHIMEI_KANJI := VNUSHI_NM;
                 END IF;
               --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
               END IF;
-- 2024/06/11 ZCZL.wangqiwei Add end
                                     --児童の制御情報を取得
                               BEGIN
                                 NKOJIN_NO := KOJIN_NO;
                                 SELECT NAIYO_CD INTO N_NAIYO_CD_JIDO FROM GKBTSHIMEIJKN
                                  WHERE KOJIN_NO = NKOJIN_NO AND CHOHYO_ID = 'GKB230R001';
                               EXCEPTION
                                 WHEN OTHERS THEN
                                  N_NAIYO_CD_JIDO := 0;
                               END;
                                --世帯主KOJIN_NOで人格区分を取得
                                BEGIN
                                  IRTN := GAAPK0030.FGETATENA(INUSHI_NO,
                                                                    'GKB',
                                                                    ISAKUSEIBI,
                                                                    RA,
                                                                    RASO);
                                N_INUSHI_JINGAKU := RA.JINKAKU_KBN;
                                EXCEPTION
                                 WHEN OTHERS THEN
                                   NULL;
                                END;
                        IF RG.SYOGAKO_CD <> 0 AND
                           RG.SYOGAKO_TENGAKU_BI = 0 AND
                           RG.SYOGAKO_SOTSUGYO_BI = 0 THEN
                                MJIDO_WORK(ICNT).GAKO_CD := RG.SYOGAKO_CD;
                                MJIDO_WORK(ICNT).GAKO_KBN := 1;
                        ELSIF
                                RG.TYUGAKO_CD <> 0 AND
                                RG.TYUGAKO_TENGAKU_BI = 0 AND
                                RG.TYUGAKO_SOTSUGYO_BI = 0 THEN
                                 MJIDO_WORK(ICNT).GAKO_CD := RG.TYUGAKO_CD;
                                     MJIDO_WORK(ICNT).GAKO_KBN := 2;
                        ELSIF
                               RG.KUIKIGAI_CD <> 0 AND
                               RG.KUIKIGAI_TENGAKU_BI = 0 AND
                               RG.KUIKIGAI_TAIGAKU_BI = 0 AND
                               RG.KUIKIGAI_SOTSUGYO_BI = 0 THEN
                                     MJIDO_WORK(ICNT).GAKO_CD := RG.KUIKIGAI_CD;
                                     MJIDO_WORK(ICNT).GAKO_KBN := 3;
                        ELSIF
                               RG.YOGOGAKO_CD <> 0 AND
                               RG.YOGOGAKO_TENGAKU_BI = 0 AND
                               RG.YOGOGAKO_TAIGAKU_BI = 0 AND
                               RG.YOGOGAKO_SOTSUGYO_BI = 0 THEN
                                 MJIDO_WORK(ICNT).GAKO_CD := RG.YOGOGAKO_CD;
                                     MJIDO_WORK(ICNT).GAKO_KBN := 4;
--  2025/12/17 CTC.HJF UPDATE START 1.0.404.000:GKB_QA17301対応
                        ELSIF
                               RG.KUNISHIRITSU_CD <> 0 AND
                               RG.KUNISHIRITSU_TENGAKU_BI = 0 AND
                               RG.KUNISHIRITSU_TAIGAKU_BI = 0 AND
                               RG.KUNISHIRITSU_SOTSUGYO_BI = 0 THEN
                                 MJIDO_WORK(ICNT).GAKO_CD := RG.KUNISHIRITSU_CD;
                                     MJIDO_WORK(ICNT).GAKO_KBN := 5;
--  2025/12/17 CTC.HJF UPDATE END
                        ELSE
                                     MJIDO_WORK(ICNT).GAKO_CD := NULL;
                                     MJIDO_WORK(ICNT).GAKO_KBN := 0;
                        END IF;
                     MJIDO_WORK(ICNT).GYOSEIKU_CD := RA1.GYOSEIKU_CD;
                     MJIDO_WORK(ICNT).HAN_CD := RA1.HAN_CD;
                     MJIDO_WORK(ICNT).SANTEIDANTAI_CD := RA1.SANTEIDANTAI_CD;
-- 2024/06/11 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--                      MJIDO_WORK(ICNT).SHIMEI_KANA := RA1.SHIMEI_KANA;
                     MJIDO_WORK(ICNT).SHIMEI_KANA := o_SHIMEIKANA;
-- 2024/06/11 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--                      MJIDO_WORK(ICNT).SEINENGAPI := RA1.SEINENGAPI; 
--  2024/11/20 YAMANI.SASAKI UPDATE START 0.3.000.005:仕様変更　IT_GKB_00650対応
--                     MJIDO_WORK(ICNT).SEINENGAPI := o_BIRTHDAY;
                     MJIDO_WORK(ICNT).SEINENGAPI := RA1.SEINENGAPI; 
--  2024/11/20 YAMANI.SASAKI UPDATE END
                     MJIDO_WORK(ICNT).SEIBETSU := RA1.SEIBETSU;
                     MJIDO_WORK(ICNT).SETAI_NO := RA1.SETAI_NO;
-- 2024/06/11 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
                     MJIDO_WORK(ICNT).OAZA_CD := RA1.OAZA_CD; --大字コード
                     MJIDO_WORK(ICNT).HONBAN  := RA1.HONBAN;  --本番
-- 2024/06/11 ZCZL.wangqiwei Add end
-- 2024/06/26 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発の標準化対応
--                          IF RB1.JINKAKU_KBN = 1 THEN
--                            VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
--                                       TRIM(RB1.SHIMEI_KANA),TRIM(RB1.HONMYO_KANA));
--                            MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA  := VEDIT_GO_DATA;
--                          ELSE
-- 2024/06/26 ZCZL.wangqiwei Delete end
-- 2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                      MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RB1.SHIMEI_KANA; 
                     MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := o_HOGOSHA_SHIMEI_KANA;
-- 2024/06/26 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発の標準化対応
--                          END IF;
                         MJIDO_WORK(ICNT).KAIPEJI :=' ';
                     NSHORIBI := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
                     -- 処理日（表示用）
                     ISEIREKI := NSHORIBI;
                     IWAREKI := NULL;
                     BRTN := KKAPK0020.FDAYEDIT(IWAREKI,  ISEIREKI,
                                                VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                                VEDIT_GYYMMDD3, VKJ_GENGO,
                                                VKG_GENGO,      IWAREKI_YY,
                                            ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                                IMM,            IDD,
                                                IWAREKIHIZUKE,  ISEIREKIHIZUKE );
                     MJIDO_WORK(ICNT).SAKUSEIBI :=VEDIT_GYYMMDD3;
                         MJIDO_WORK(ICNT).RENBAN := '';
                         MJIDO_WORK(ICNT).HYOJI_RENBAN := '';
                         IF RB1.JINKAKU_KBN = 1 THEN
                           VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                            TRIM(RB1.SHIMEI_KANA),TRIM(RB1.HONMYO_KANA));
                           MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := VEDIT_GO_DATA;
                           VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                            TRIM(RB1.SHIMEI_KANJI),TRIM(RB1.HONMYO_KANJI));
                           MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN := VEDIT_GO_DATA;
                         ELSE
                          MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := RB1.SHIMEI_KANA;
                          MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN := RB1.SHIMEI_KANJI;
                         END IF;
                         IF RA1.JINKAKU_KBN = 1 THEN
                           VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                            TRIM(RA1.SHIMEI_KANA),TRIM(RA1.HONMYO_KANA));
                           MJIDO_WORK(ICNT).JIDO_SHIMEI_JODAN := VEDIT_GO_DATA;
                           VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                            TRIM(RA1.SHIMEI_KANJI),TRIM(RA1.HONMYO_KANJI));
                           MJIDO_WORK(ICNT).JIDO_SHIMEI_GEDAN := VEDIT_GO_DATA;
                         ELSE
                           MJIDO_WORK(ICNT).JIDO_SHIMEI_JODAN := RA1.SHIMEI_KANA;
                           MJIDO_WORK(ICNT).JIDO_SHIMEI_GEDAN := RA1.SHIMEI_KANJI;
                         END IF;
                         ISEIREKI := RA1.SEINENGAPI;
                         IWAREKI := NULL;
                         BRTN := KKAPK0020.FDAYEDIT(IWAREKI,  ISEIREKI,
                                            VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                            VEDIT_GYYMMDD3, VKJ_GENGO,
                                            VKG_GENGO,      IWAREKI_YY,
                                            ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                            IMM,            IDD,
                                            IWAREKIHIZUKE,  ISEIREKIHIZUKE );
                        IF RA1.JINKAKU_KBN = 1 THEN
                           IF FUNC_SET_SEIGYO_SEINENGAPI(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO) = 1 THEN
                             IF ISEIREKIHIZUKE <> 0 THEN
                               MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := TO_CHAR(TO_DATE(ISEIREKIHIZUKE,'YYYYMMDD'),'YYYY.MM.DD');
                             ELSE
                               MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := '';
                             END IF;
                           ELSE
                             MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VEDIT_GYYMMDD1;
                           END IF;
                        ELSE
                           MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VEDIT_GYYMMDD1;
                        END IF;
                         IF RA1.SEIBETSU = 1 THEN
                            MJIDO_WORK(ICNT).HYOJI_SEIBETSU := '男';
                     ELSIF RA1.SEIBETSU = 2 THEN
                           MJIDO_WORK(ICNT).HYOJI_SEIBETSU :=  '女';
                     END IF;
                         i_GYOSEIKU_CD  :=RA1.GYOSEIKU_CD;
                     i_SANTEIDANTAI_CD :=RA1.SANTEIDANTAI_CD;
                     VGYOSEIKU_MEI :=  GAAPK0030.FGYOSEIKUMEI(i_SANTEIDANTAI_CD,i_GYOSEIKU_CD);
                         MJIDO_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;
                          IF MJIDO_WORK(ICNT).GAKO_KBN = 1 THEN
                            BEGIN
                          SELECT SYOGAKOMEI INTO VGAKOMEI
                          FROM GKBTSHOGAKKO
                          WHERE SYOGAKO_CD = MJIDO_WORK(ICNT).GAKO_CD;
                            EXCEPTION
                             WHEN NO_DATA_FOUND THEN
                                  DBMS_OUTPUT.PUT_LINE('該当小学校なし　'||RG.SYOGAKO_CD||' '||KOJIN_NO);
                                  VGAKOMEI := ' ';
                            END;
                      END IF;
                      IF MJIDO_WORK(ICNT).GAKO_KBN = 2 THEN
                            BEGIN
                           SELECT TYUGAKOMEI INTO VGAKOMEI
                           FROM GKBTCHUGAKKO
                           WHERE TYUGAKO_CD = MJIDO_WORK(ICNT).GAKO_CD;
                            EXCEPTION
                               WHEN NO_DATA_FOUND THEN
                                    DBMS_OUTPUT.PUT_LINE('該当中学校なし　'||RG.TYUGAKO_CD||' '||KOJIN_NO);
                                    VGAKOMEI := ' ';
                            END;
                      END IF;
                      IF MJIDO_WORK(ICNT).GAKO_KBN = 3 THEN
                             BEGIN
                            SELECT KUIKIGAIMEI INTO VGAKOMEI
                            FROM GKBTKUIKIGAI
                            WHERE KUIKIGAI_CD = MJIDO_WORK(ICNT).GAKO_CD;
                             EXCEPTION
                               WHEN NO_DATA_FOUND THEN
                                    DBMS_OUTPUT.PUT_LINE('該当区域外学校なし　'||RG.KUIKIGAI_CD||' '||KOJIN_NO);
                                    VGAKOMEI := ' ';
                            END;
                      END IF;
                      IF MJIDO_WORK(ICNT).GAKO_KBN = 4 THEN
                              BEGIN
                              SELECT YOGOGAKOMEI INTO VGAKOMEI
                              FROM GKBTYOGOGAKKO
                              WHERE YOGOGAKO_CD = MJIDO_WORK(ICNT).GAKO_CD;
                              EXCEPTION
                              WHEN NO_DATA_FOUND THEN
                                   DBMS_OUTPUT.PUT_LINE('該当盲聾養護学校なし　'||RG.YOGOGAKO_CD||' '||KOJIN_NO);
                                   VGAKOMEI := ' ';
                              END;
                      END IF;
--  2025/12/17 CTC.HJF UPDATE START 1.0.404.000:GKB_QA17301対応
                      IF MJIDO_WORK(ICNT).GAKO_KBN = 5 THEN
                              BEGIN
                              SELECT KUNISHIRITSUGAKKOMEI INTO VGAKOMEI
                              FROM GKBTKUNISIRITSUGAKKO
                              WHERE KUNISHIRITSUGAKKO_CD = MJIDO_WORK(ICNT).GAKO_CD;
                              EXCEPTION
                              WHEN NO_DATA_FOUND THEN
                                   DBMS_OUTPUT.PUT_LINE('該当国・私立学校なし　'||RG.KUNISHIRITSU_CD||' '||KOJIN_NO);
                                   VGAKOMEI := ' ';
                              END;
                      END IF;
--  2025/12/17 CTC.HJF UPDATE END
                         IF MJIDO_WORK(ICNT).GAKO_KBN = 0 THEN
                            VGAKOMEI := ' ';
                         END IF;
                         MJIDO_WORK(ICNT).GAKOKUMEI := VGAKOMEI;
                         i_ISAN_CD := MJIDO_WORK(ICNT).SANTEIDANTAI_CD;
                         I_RTN :=  GAAPK0030.FJICHINAME(i_ISAN_CD,o_VSAN_KJ);
                         MJIDO_WORK(ICNT).SANTEIDANTAIMEI := o_VSAN_KJ;
                  IF (RA2.KOJIN_NO IS NOT NULL) AND
                         (RA2.TEKIYO_BI <= ISAKUSEIBI) AND
                         (RA2.SHURYO_BI >= ISAKUSEIBI OR RA2.SHURYO_BI = 0) THEN
                        MJIDO_WORK(ICNT).JIDO_YUBIN_NO := RA2.YUBIN_NO;
                        MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC := RA2.YUBIN_NOBC;
                        MJIDO_WORK(ICNT).JIDO_CHOMEI := RA2.CHOMEI;
                        MJIDO_WORK(ICNT).JIDO_BANCHI := RA2.BANCHI;
                        MJIDO_WORK(ICNT).JIDO_KATAGAKI :=RA2.KATAGAKI;
                  ELSE
                        MJIDO_WORK(ICNT).JIDO_YUBIN_NO := RA1.YUBIN_NO;
                        MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC:= RA1.YUBIN_NOBC;
                        MJIDO_WORK(ICNT).JIDO_CHOMEI:= RA1.CHOMEI;
                        MJIDO_WORK(ICNT).JIDO_BANCHI:= RA1.BANCHI;
                        MJIDO_WORK(ICNT).JIDO_KATAGAKI:= RA1.KATAGAKI;
                  END IF;
                  IF (RB2.KOJIN_NO IS NOT NULL)  AND
                         (RB2.TEKIYO_BI <= ISAKUSEIBI) AND
                         (RB2.SHURYO_BI >= ISAKUSEIBI OR
                          RB2.SHURYO_BI = 0) THEN
                         MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO := RB2.YUBIN_NO;
                         MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NOBC := RB2.YUBIN_NOBC;
                         MJIDO_WORK(ICNT).HOGOSHA_CHOMEI := RB2.CHOMEI;
                         MJIDO_WORK(ICNT).HOGOSHA_BANCHI := RB2.BANCHI;
                         MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI := RB2.KATAGAKI;
                  ELSE
                         MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO := RB1.YUBIN_NO;
                     MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NOBC :=  RB1.YUBIN_NOBC;
                         MJIDO_WORK(ICNT).HOGOSHA_CHOMEI := RB1.CHOMEI;
                         MJIDO_WORK(ICNT).HOGOSHA_BANCHI := RB1.BANCHI;
                         MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI := RB1.KATAGAKI;
                  END IF;
                         I_RTN := GKBFKZKGMGET(2,
                                           RG.HOGOSYA_ZOKUGARA1,
                                           RG.HOGOSYA_ZOKUGARA2,
                                           RG.HOGOSYA_ZOKUGARA3,
                                           RG.HOGOSYA_ZOKUGARA4,
                                           VHOGOSHA_ZOKUGARA,
                                           I_RTN_VHOGOSHA_ZOKUGARAHERR);
                         I_RTN := GKBFKZKGMGET(1,
                                           RG.ZOKUGARA1,
                                           RG.ZOKUGARA2,
                                           RG.ZOKUGARA3,
                                           RG.ZOKUGARA4,
                                           VJIDO_ZOKUGARA,
                                           I_RTN_VJIDO_ZOKUGARAHERR);
                         MJIDO_WORK(ICNT).HOGOSHA_ZOKUGARAMEI := VHOGOSHA_ZOKUGARA;
                         MJIDO_WORK(ICNT).JIDO_ZOKUGARAMEI := VJIDO_ZOKUGARA;
                            MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := '';
                         ISEIREKI := ISAKUSEIBI;
                     IWAREKI := NULL;
                     BRTN := KKAPK0020.FDAYEDIT(IWAREKI,       ISEIREKI,
                                                VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                                VEDIT_GYYMMDD3, VKJ_GENGO,
                                                VKG_GENGO,      IWAREKI_YY,
                                            ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                                IMM,            IDD,
                                                IWAREKIHIZUKE,  ISEIREKIHIZUKE );
                         MJIDO_WORK(ICNT).KIJUN_BI := VEDIT_GYYMMDD3;
                         MJIDO_WORK(ICNT).CHOHYO_NO := RG.CHOHYO_NO;
                  IF ACONSPRM_ATENA(1) IN (1,3) THEN
                  IF (RA2.KOJIN_NO IS NOT NULL) AND
                         (RA2.TEKIYO_BI <= ISAKUSEIBI) AND
                         (RA2.SHURYO_BI >= ISAKUSEIBI OR RA2.SHURYO_BI = 0) THEN
                         IF RA2.SHIMEI_KANJI IS NOT NULL THEN
                            NSHIMEI_KANJI := RA2.SHIMEI_KANJI;
                         ELSE
                           IF RA1.JINKAKU_KBN = 1 THEN
                              VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                            TRIM(RA1.SHIMEI_KANJI),TRIM(RA1.HONMYO_KANJI));
                              NSHIMEI_KANJI  := VEDIT_GO_DATA;
                           ELSE
                              NSHIMEI_KANJI := RA1.SHIMEI_KANJI;
                           END IF;
                         END IF;
                      ELSE
                       IF RA1.JINKAKU_KBN = 1 THEN
                         VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                            TRIM(RA1.SHIMEI_KANJI),TRIM(RA1.HONMYO_KANJI));
                         NSHIMEI_KANJI  := VEDIT_GO_DATA;
                       ELSE
                         NSHIMEI_KANJI := RA1.SHIMEI_KANJI;
                       END IF;
                      END IF;
                           IF LENGTH(MJIDO_WORK(ICNT).JIDO_YUBIN_NO) > 0 AND
                         KOJIN_NO <> 0 THEN
                             MJIDO_WORK(ICNT).YUBIN_NO  := SUBSTR(MJIDO_WORK(ICNT).JIDO_YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNT).JIDO_YUBIN_NO,4);
                           ELSE
                                 MJIDO_WORK(ICNT).YUBIN_NO  := NULL;
                           END IF;
                       MJIDO_WORK(ICNT).CHOMEI := MJIDO_WORK(ICNT).JIDO_CHOMEI;
                       MJIDO_WORK(ICNT).BANCHI := MJIDO_WORK(ICNT).JIDO_BANCHI;
                           MJIDO_WORK(ICNT).KATAGAKI := MJIDO_WORK(ICNT).JIDO_KATAGAKI;
                           IF ACONSPRM_ATENA(4) = 1 THEN
                          IF LENGTH(VNUSHI_NM) > 0 THEN
                                  IF N_INUSHI_JINGAKU = 1 THEN
                                    VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                              TRIM(RA.SHIMEI_KANJI),TRIM(RA.HONMYO_KANJI));
                                    VNUSHI_NM  := VEDIT_GO_DATA;
                                  END IF;
-- 2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                                  MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI:= VNUSHI_NM||'　様方';
               --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
                                 --MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI:= o_NUSI_SHIMEI_KANJI;
                                 MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI:= o_NUSI_SHIMEI_KANJI||'　様方';
               --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
                          ELSE
                             MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI := NULL;
                          END IF;
                           ELSE
                                 MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI := NULL;
                           END IF;
                       IF LENGTH(NSHIMEI_KANJI) > 0 THEN
                          IF ACONSPRM_ATENA(3) = 1 THEN
                          --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
                         --         MJIDO_WORK(ICNT).ATENA_JODAN:= ' (' ||NSHIMEI_KANJI||'　様) ';
                         --     ELSE
                         --         MJIDO_WORK(ICNT).ATENA_JODAN:= NSHIMEI_KANJI||'　様';
                              IF o_SHIMEI IS NOT NULL THEN
                                  MJIDO_WORK(ICNT).ATENA_JODAN:= ' (' ||o_SHIMEI||'　様) ';
                                ELSE
                                  MJIDO_WORK(ICNT).ATENA_JODAN := NULL;
                                END IF;
                              ELSE
                                  MJIDO_WORK(ICNT).ATENA_JODAN:= o_SHIMEI||'　様';
                          --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
                              END IF;
                           ELSE
                               MJIDO_WORK(ICNT).ATENA_JODAN := NULL;
                       END IF;
                             MJIDO_WORK(ICNT).YUBIN_NOBC :=  MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC;
                ELSE
                  IF (RB2.KOJIN_NO IS NOT NULL)
                         AND (RB2.TEKIYO_BI <= ISAKUSEIBI)
                         AND (RB2.SHURYO_BI >= ISAKUSEIBI
                         OR RB2.SHURYO_BI = 0) THEN
                         IF RB2.SHIMEI_KANJI IS NOT NULL THEN
                            NSHIMEI_KANJI := RB2.SHIMEI_KANJI;
                         ELSE
                          IF RB1.JINKAKU_KBN = 1 THEN
                           VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                                TRIM(RB1.SHIMEI_KANJI),TRIM(RB1.HONMYO_KANJI));
                           NSHIMEI_KANJI  := VEDIT_GO_DATA;
                          ELSE
                           NSHIMEI_KANJI := RB1.SHIMEI_KANJI;
                          END IF;
                         END IF;
                      ELSE
                          NSHIMEI_KANJI := RB1.SHIMEI_KANJI;
                      END IF;
                            IF LENGTH(MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO) > 0 AND
                           RG.HOGOSYA_KOJIN_NO <> 0 THEN
                               MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO,4);
                             ELSE
                                 MJIDO_WORK(ICNT).YUBIN_NO := NULL;
                             END IF;
                            MJIDO_WORK(ICNT).CHOMEI := MJIDO_WORK(ICNT).HOGOSHA_CHOMEI;
                        MJIDO_WORK(ICNT).BANCHI := MJIDO_WORK(ICNT).HOGOSHA_BANCHI;
                        MJIDO_WORK(ICNT).KATAGAKI := MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI;
                            IF ACONSPRM_ATENA(4) = 1 THEN
                           IF RB1.KOJIN_NO = INUSHI_NO THEN
                             MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI:= '';
                           ELSE
                             IF LENGTH(VNUSHI_NM) > 0 THEN
                                  IF N_INUSHI_JINGAKU = 1 THEN
                                    VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                              TRIM(RA.SHIMEI_KANJI),TRIM(RA.HONMYO_KANJI));
                                    VNUSHI_NM  := VEDIT_GO_DATA;
                                  END IF;
-- 2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                                     MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI:= VNUSHI_NM||'　様方';
                                    MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI:= o_NUSI_SHIMEI_KANJI;
                             ELSE
                                MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI := NULL;
                             END IF;
                           END IF;
                            ELSE
                                  MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI := NULL;
                            END IF;
                       IF LENGTH(NSHIMEI_KANJI) > 0 THEN
                              IF ACONSPRM_ATENA(2) = 1 THEN
                          --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
                         --        MJIDO_WORK(ICNT).ATENA_JODAN := ' ( '||NSHIMEI_KANJI||'　様)';
                         -- ELSE
                         --        MJIDO_WORK(ICNT).ATENA_JODAN:= NSHIMEI_KANJI||'　様';
                                IF o_SHIMEI IS NOT NULL THEN
                                  MJIDO_WORK(ICNT).ATENA_JODAN := ' ( '||o_SHIMEI||'　様)';
                                ELSE
                                  MJIDO_WORK(ICNT).ATENA_JODAN  := NULL;
                                END IF;
                          ELSE
                                 MJIDO_WORK(ICNT).ATENA_JODAN:= o_SHIMEI||'　様';
                          --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
                              END IF;
                           ELSE
                                 MJIDO_WORK(ICNT).ATENA_JODAN  := NULL;
                       END IF;
                MJIDO_WORK(ICNT).YUBIN_NOBC := MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NOBC;
                END IF;
                    IF ACONSPRM_ATENA(1) = 2 THEN
                  IF (RA2.KOJIN_NO IS NOT NULL) AND
                         (RA2.TEKIYO_BI <= ISAKUSEIBI) AND
                         (RA2.SHURYO_BI >= ISAKUSEIBI OR RA2.SHURYO_BI = 0) THEN
                         IF RA2.SHIMEI_KANJI IS NOT NULL THEN
                            NSHIMEI_KANJI := RA2.SHIMEI_KANJI;
                         ELSE
                           IF RA1.JINKAKU_KBN = 1 THEN
                             VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                       TRIM(RA1.SHIMEI_KANJI),TRIM(RA1.HONMYO_KANJI));
                              NSHIMEI_KANJI  := VEDIT_GO_DATA;
                           ELSE
                              NSHIMEI_KANJI := RA1.SHIMEI_KANJI;
                           END IF;
                         END IF;
                      ELSE
                       IF RA1.JINKAKU_KBN = 1 THEN
                          VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                     TRIM(RA1.SHIMEI_KANJI),TRIM(RA1.HONMYO_KANJI));
                           NSHIMEI_KANJI  := VEDIT_GO_DATA;
                       ELSE
                           NSHIMEI_KANJI := RA1.SHIMEI_KANJI;
                       END IF;
                      END IF;
                IF ACONSPRM_ATENA(3) = 1 THEN
                       IF LENGTH(NSHIMEI_KANJI) > 0 THEN
-- 2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                              MJIDO_WORK(ICNT).ATENA_GEDAN  := '（' ||NSHIMEI_KANJI||'　様）';
                          --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
                          --   MJIDO_WORK(ICNT).ATENA_GEDAN  := o_SHIMEI ;
--  2025/05/22 CTC.LIZIZHONG UPDATE 1.0.006.000:QA14807対応 Start                          
                          --  IF o_HOGOSHA_SHIMEI_KANJI IS NOT NULL THEN
                           IF o_HOGOSHA_SHIMEI_KANJI IS NOT NULL AND REPLACE(MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI, '　様方') <> o_HOGOSHA_SHIMEI_KANJI THEN
--  2025/05/22 CTC.LIZIZHONG UPDATE 1.0.006.000:QA14807対応 End                             
                             MJIDO_WORK(ICNT).ATENA_GEDAN  := '（' ||o_HOGOSHA_SHIMEI_KANJI||'　様）' ;
                           ELSE
                             MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
                           END IF;
                          --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
                       ELSE
                         MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
                       END IF;
                    ELSE
                           IF LENGTH(NSHIMEI_KANJI) > 0 THEN
-- 2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                              MJIDO_WORK(ICNT).ATENA_GEDAN:= NSHIMEI_KANJI||'　様';
                         --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
                             --MJIDO_WORK(ICNT).ATENA_GEDAN:= o_SHIMEI;
--  2025/05/22 CTC.LIZIZHONG UPDATE 1.0.006.000:QA14807対応 Start                          
                          --  IF o_HOGOSHA_SHIMEI_KANJI IS NOT NULL THEN
                           IF o_HOGOSHA_SHIMEI_KANJI IS NOT NULL AND REPLACE(MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI, '　様方') <> o_HOGOSHA_SHIMEI_KANJI THEN
--  2025/05/22 CTC.LIZIZHONG UPDATE 1.0.006.000:QA14807対応 End  
                             MJIDO_WORK(ICNT).ATENA_GEDAN:= o_HOGOSHA_SHIMEI_KANJI||'　様';
                           ELSE
                             MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
                           END IF;
                         --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
                           ELSE
                         MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
                       END IF;
                         END IF;
                     ELSIF  ACONSPRM_ATENA(1) = 3 THEN
                  IF (RB2.KOJIN_NO IS NOT NULL)
                         AND (RB2.TEKIYO_BI <= ISAKUSEIBI)
                         AND (RB2.SHURYO_BI >= ISAKUSEIBI
                         OR RB2.SHURYO_BI = 0) THEN
                         IF RB2.SHIMEI_KANJI IS NOT NULL THEN
                            NSHIMEI_KANJI := RB2.SHIMEI_KANJI;
                         ELSE
                          IF RB1.JINKAKU_KBN = 1 THEN
                            VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                                 TRIM(RB1.SHIMEI_KANJI),TRIM(RB1.HONMYO_KANJI));
                            NSHIMEI_KANJI  := VEDIT_GO_DATA;
                          ELSE
                            NSHIMEI_KANJI := RB1.SHIMEI_KANJI;
                          END IF;
                         END IF;
                      ELSE
                          IF RB1.JINKAKU_KBN = 1 THEN
                            VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                                 TRIM(RB1.SHIMEI_KANJI),TRIM(RB1.HONMYO_KANJI));
                            NSHIMEI_KANJI  := VEDIT_GO_DATA;
                          ELSE
                            NSHIMEI_KANJI := RB1.SHIMEI_KANJI;
                          END IF;
                      END IF;
                            IF ACONSPRM_ATENA(2) = 1 THEN
                           IF LENGTH(NSHIMEI_KANJI) > 0 THEN
-- 2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                                   MJIDO_WORK(ICNT).ATENA_GEDAN:= '（'||NSHIMEI_KANJI||'　様）';
                             --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
                                 -- MJIDO_WORK(ICNT).ATENA_GEDAN:= o_SHIMEI;
--  2025/05/22 CTC.LIZIZHONG UPDATE 1.0.006.000:QA14807対応 Start                          
                          --  IF o_HOGOSHA_SHIMEI_KANJI IS NOT NULL THEN
                            IF o_HOGOSHA_SHIMEI_KANJI IS NOT NULL AND REPLACE(MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI, '　様方') <> o_HOGOSHA_SHIMEI_KANJI THEN
--  2025/05/22 CTC.LIZIZHONG UPDATE 1.0.006.000:QA14807対応 End  
                                  MJIDO_WORK(ICNT).ATENA_GEDAN:= '（'||o_HOGOSHA_SHIMEI_KANJI||'　様）';
                                ELSE
                                  MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
                                END IF;
                             --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
                           ELSE
                              MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
                           END IF;
                            ELSE
                                 IF LENGTH(NSHIMEI_KANJI) > 0 THEN
-- 2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                                   MJIDO_WORK(ICNT).ATENA_GEDAN:= '（'||NSHIMEI_KANJI||'　様）';
                           --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 Start
                               --   MJIDO_WORK(ICNT).ATENA_GEDAN:= o_SHIMEI;
--  2025/05/22 CTC.LIZIZHONG UPDATE 1.0.006.000:QA14807対応 Start                          
                          --  IF o_HOGOSHA_SHIMEI_KANJI IS NOT NULL THEN
                           IF o_HOGOSHA_SHIMEI_KANJI IS NOT NULL AND REPLACE(MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI, '　様方') <> o_HOGOSHA_SHIMEI_KANJI THEN
--  2025/05/22 CTC.LIZIZHONG UPDATE 1.0.006.000:QA14807対応 End  
                                  MJIDO_WORK(ICNT).ATENA_GEDAN:= '（'||o_HOGOSHA_SHIMEI_KANJI||'　様）';
                                ELSE
                                  MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
                                END IF;
                           --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:仕様変更　ST_GKB_TMP00009対応 End
                           ELSE
                              MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
                           END IF;
                         END IF;
                     ELSE
                         MJIDO_WORK(ICNT).ATENA_GEDAN := '';
                     END IF;
                     VKON_JUSHO := MJIDO_WORK(ICNT).HOGOSHA_CHOMEI||MJIDO_WORK(ICNT).HOGOSHA_BANCHI||MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI;
                     IF LENGTH(VKON_JUSHO) > 20 THEN
                    VKON_JUSHO_JODAN := SUBSTR(VKON_JUSHO,1,20);
                    VKON_JUSHO_GEDAN := SUBSTR(VKON_JUSHO,21);
                        MJIDO_WORK(ICNT).KON_JUSHO_JODAN := VKON_JUSHO_JODAN;
                        MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := VKON_JUSHO_GEDAN;
                     END IF;
                     IF LENGTH(VKON_JUSHO) = 0 THEN
                        MJIDO_WORK(ICNT).KON_JUSHO_JODAN := NULL;
                        MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := NULL;
                        END IF;
                     IF LENGTH(VKON_JUSHO) BETWEEN 1 AND 20 THEN
                        MJIDO_WORK(ICNT).KON_JUSHO_JODAN := VKON_JUSHO;
                        MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := NULL;
                     END IF;
                         MJIDO_WORK(ICNT).JIDO_KOJIN_NO := KOJIN_NO;
                     IF  MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN IS NULL OR MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN IS NULL THEN
                         MJIDO_WORK(ICNT).JIDO_ZOKUGARAMEI := '';
                         MJIDO_WORK(ICNT).HOGOSHA_ZOKUGARAMEI := '';
                     END IF;
                     MJIDO_WORK(ICNT).KAIPEJI_CD := '';
                         I_RTN := GAAPK0030.FGETATENA(KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), o_RATENA_REC, o_RSOFU_REC);
                         MJIDO_WORK(ICNT).JINKAKU_KBN := o_RATENA_REC.JINKAKU_KBN;
                     ICNT := ICNT + 1;               -- カウントアップ
                     IFRET := c_ISUCCESS;              -- 正常終了
                 ELSE
                NULL;
             END IF;
               END LOOP;
            CLOSE CRATENA;
        EXCEPTION
            WHEN OTHERS THEN
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD START 0.3.000.002:8月1日認識合わせの横展開とIT_GKB_00088の横展開
                IF CRATENA%ISOPEN THEN
                    CLOSE CRATENA;
                END IF;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, SUBSTR(SQLERRM, 1, 250), g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        -- その他エラー
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------------------------------
    --  宛名ラベルワーク（GKBWALABEL）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_INSERT_JIDO_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- 戻り値
        IMAX                BINARY_INTEGER;             -- 戻り値
        IMIN                BINARY_INTEGER;             -- 戻り値
    BEGIN
        IFRET := c_ISUCCESS;                  -- 正常終了
        -- ワーク領域の最終位置を取得
        IMAX := MJIDO_WORK.LAST;
        -- ワーク領域の先頭位置を取得
        IMIN := MJIDO_WORK.FIRST;
        BEGIN
            -- ワーク領域の件数分繰り返し処理を行う
            FOR ICNT IN IMIN..IMAX LOOP
                INSERT INTO
                GKBWALABEL
                (
                 GAKO_CD,
                 GYOSEIKU_CD,
                 HAN_CD,
                 SANTEIDANTAI_CD,
                 SHIMEI_KANA,
                 SEINENGAPI,
                 SEIBETSU,
                 SETAI_NO,
                 HOGOSHA_SHIMEI_KANA,
                 YUBIN_NO,
                 CHOMEI,
                 BANCHI,
                 KATAGAKI,
                 NUSI_SHIMEI_KANJI,
                 ATENA_JODAN,
                 ATENA_GEDAN,
                 KAIPEJI_CD,
                 YUBIN_NOBC,
                 GAKO_KBN,
                 KAIPEJI,
                 SAKUSEIBI,
                 RENBAN,
                 HYOJI_RENBAN,
                 HOGOSHA_SHIMEI_JODAN,
                 HOGOSHA_SHIMEI_GEDAN,
                 JIDO_SHIMEI_JODAN,
                 JIDO_SHIMEI_GEDAN,
                 HYOJI_SEINENGAPI,
                 HYOJI_SEIBETSU,
                 GYOSEIKUMEI,
                 GAKOKUMEI,
                 SANTEIDANTAIMEI,
                 JIDO_YUBIN_NO,
                 JIDO_YUBIN_NOBC,
                 JIDO_CHOMEI,
                 JIDO_BANCHI,
                 JIDO_KATAGAKI,
                 HOGOSHA_YUBIN_NO,
                 HOGOSHA_YUBIN_NOBC,
                 HOGOSHA_CHOMEI,
                 HOGOSHA_BANCHI,
                 HOGOSHA_KATAGAKI,
                 KON_JUSHO_JODAN,
                 KON_JUSHO_GEDAN,
                 JIDO_KOJIN_NO,
                 HOGOSHA_ZOKUGARAMEI,
                 JIDO_ZOKUGARAMEI,
                 HYOJI_CHOHYO_NO,
                 KIJUN_BI,
                 CHOHYO_NO,
                 JINKAKU_KBN
-- 2024/06/11 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
                 ,OAZA_CD,
                 HONBAN
-- 2024/06/11 ZCZL.wangqiwei Add end
                )
                VALUES
                (
                 MJIDO_WORK(ICNT).GAKO_CD,
                 MJIDO_WORK(ICNT).GYOSEIKU_CD,
                 MJIDO_WORK(ICNT).HAN_CD,
                 MJIDO_WORK(ICNT).SANTEIDANTAI_CD,
                 MJIDO_WORK(ICNT).SHIMEI_KANA,
                 MJIDO_WORK(ICNT).SEINENGAPI,
                 MJIDO_WORK(ICNT).SEIBETSU,
                 MJIDO_WORK(ICNT).SETAI_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
                 MJIDO_WORK(ICNT).YUBIN_NO,
                 MJIDO_WORK(ICNT).CHOMEI,
                 MJIDO_WORK(ICNT).BANCHI,
                 MJIDO_WORK(ICNT).KATAGAKI,
                 MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI,
                 MJIDO_WORK(ICNT).ATENA_JODAN,
                 MJIDO_WORK(ICNT).ATENA_GEDAN,
                 MJIDO_WORK(ICNT).KAIPEJI_CD,
                 MJIDO_WORK(ICNT).YUBIN_NOBC,
                 MJIDO_WORK(ICNT).GAKO_KBN,
                 MJIDO_WORK(ICNT).KAIPEJI,
                 MJIDO_WORK(ICNT).SAKUSEIBI,
                 MJIDO_WORK(ICNT).RENBAN,
                 MJIDO_WORK(ICNT).HYOJI_RENBAN,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN,
                 MJIDO_WORK(ICNT).JIDO_SHIMEI_JODAN,
                 MJIDO_WORK(ICNT).JIDO_SHIMEI_GEDAN,
                 MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,
                 MJIDO_WORK(ICNT).HYOJI_SEIBETSU,
                 MJIDO_WORK(ICNT).GYOSEIKUMEI,
                 MJIDO_WORK(ICNT).GAKOKUMEI,
                 MJIDO_WORK(ICNT).SANTEIDANTAIMEI,
                 MJIDO_WORK(ICNT).JIDO_YUBIN_NO,
                 MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC,
                 MJIDO_WORK(ICNT).JIDO_CHOMEI,
                 MJIDO_WORK(ICNT).JIDO_BANCHI,
                 MJIDO_WORK(ICNT).JIDO_KATAGAKI,
                 MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NOBC,
                 MJIDO_WORK(ICNT).HOGOSHA_CHOMEI,
                 MJIDO_WORK(ICNT).HOGOSHA_BANCHI,
                 MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI,
                 MJIDO_WORK(ICNT).KON_JUSHO_JODAN,
                 MJIDO_WORK(ICNT).KON_JUSHO_GEDAN,
                 MJIDO_WORK(ICNT).JIDO_KOJIN_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_ZOKUGARAMEI,
                 MJIDO_WORK(ICNT).JIDO_ZOKUGARAMEI,
                 MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO,
                 MJIDO_WORK(ICNT).KIJUN_BI,
                 MJIDO_WORK(ICNT).CHOHYO_NO,
                 MJIDO_WORK(ICNT).JINKAKU_KBN
-- 2024/06/11 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
                 ,MJIDO_WORK(ICNT).OAZA_CD,
                 MJIDO_WORK(ICNT).HONBAN
-- 2024/06/11 ZCZL.wangqiwei Add end
                 );
            END LOOP;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;       -- 処理前に戻す
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
    -- その他エラー
        WHEN OTHERS THEN
            ROLLBACK;       -- 処理前に戻す
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------------------------------
    -- -- 宛名ラベル中間データ作成（ＣＳＶ用）
    --------------------------------------------------------------------------------
    FUNCTION FUNCGET_JIDO_WK_CSV RETURN NUMBER IS
        IFRET               PLS_INTEGER;                   -- 戻り値
        ICNT                BINARY_INTEGER;                -- カウント
        VSQL                NVARCHAR2(10000);              -- ＳＱＬ文
        VSQLSEL             NVARCHAR2(9000);               -- ＳＱＬのソート以外
        VSQLORDER           NVARCHAR2(1000);               -- ＳＱＬの［ORDER BY］句
        ICUR                PLS_INTEGER;                   -- カーソル
        RREC                GKBWALABEL%ROWTYPE;            -- 宛名中間レコード変数
        NROWS               NUMBER;
        IPAGECNT            PLS_INTEGER;                   -- 頁数
        IGYOCNT             PLS_INTEGER;                   -- 行番号
        IGYORENBAN          PLS_INTEGER;                   -- 行連番
        VPAGENAME           NVARCHAR2(1000);               -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(1000);               -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(1000);               -- 改頁項目値のワーク
        VHYOJI_RENBAN2      NVARCHAR2(6);                  -- ZZZZ9表示連番
        VGAKO_CD            NVARCHAR2(5);                  -- ZZZZ9学校コード
    BEGIN
        IFRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IPAGECNT := 0;
        IGYOCNT := 0;
        ICNT := 0;
        IGYORENBAN := 0;
        MJIDO_WORK.DELETE;                   -- ワーク領域の初期化
        -- ソート条件取得
        IF NRENBAN = 0 THEN
          VSQLORDER := ' GAKO_KBN,GAKO_CD,GYOSEIKU_CD,CHOHYO_NO ';
        ELSE
          IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
            VSQLORDER := g_rJSTP.Orderbyclause;
          END IF;
        END IF;
        -- ［ORDER BY］句を付加
        IF KKAPK0010.FTrim(VSQLORDER) IS NOT NULL THEN
           VSQLORDER := ' ORDER BY ' || VSQLORDER;
        ELSE
           VSQLORDER :='';
        END IF;
        
        VPAGEFD :='GAKO_KBN||GAKO_CD';
        VPAGENM :='GAKOKUMEI';

        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'GAKO_KBN, ';
            VSQLSEL := VSQLSEL || 'GAKO_CD, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
            VSQLSEL := VSQLSEL || 'HAN_CD, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
            VSQLSEL := VSQLSEL || 'SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'CHOMEI, ';
            VSQLSEL := VSQLSEL || 'BANCHI, ';
            VSQLSEL := VSQLSEL || 'KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'NUSI_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'ATENA_JODAN, ';
            VSQLSEL := VSQLSEL || 'ATENA_GEDAN, ';
            VSQLSEL := VSQLSEL || 'HYOJI_CHOHYO_NO, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            IF NRENBAN =0 THEN
               IF ACONSPRM_RENBAN(1) IN (1,2,3) THEN
                  VSQLSEL := VSQLSEL || ' GAKO_KBN || GAKO_CD '|| ' PAGE_FIELD, ';          -- 改頁値を設定
               ELSIF ACONSPRM_RENBAN(1) IN (4,5) THEN
                  VSQLSEL := VSQLSEL || ' GAKO_KBN || GAKO_CD || GYOSEIKU_CD '|| ' PAGE_FIELD, ';     -- 改頁値を設定
               ELSE
                  VSQLSEL := VSQLSEL || ' NULL AS PAGE_FIELD, ';                            -- 改頁値を設定
               END IF;
            ELSE
                  VSQLSEL := VSQLSEL ||  VPAGEFD || ' PAGE_FIELD, ';     -- 改頁値を設定
            END IF;
            VSQLSEL := VSQLSEL || 'YUBIN_NOBC, ';
            VSQLSEL := VSQLSEL || 'GAKOKUMEI,  ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || 'CHOHYO_NO ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWALABEL ';
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;
           -- カーソルのオープン
            ICUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(ICUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(ICUR,  1, RREC.GAKO_KBN);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  2, RREC.GAKO_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  3, RREC.GYOSEIKU_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  4, RREC.HAN_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  5, RREC.SANTEIDANTAI_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  6, RREC.SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  7, RREC.SEINENGAPI);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  8, RREC.SEIBETSU);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  9, RREC.SETAI_NO);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  10, RREC.HOGOSHA_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  11, RREC.YUBIN_NO, 10);
-- 2024/06/11 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--            DBMS_SQL.DEFINE_COLUMN(ICUR,  12, RREC.CHOMEI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR,  13, RREC.BANCHI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR,  14, RREC.KATAGAKI, 60);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  12, RREC.CHOMEI, 136);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  13, RREC.BANCHI, 50);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  14, RREC.KATAGAKI, 300);
-- 2024/06/11 ZCZL.wangqiwei Update end
            DBMS_SQL.DEFINE_COLUMN(ICUR,  15, RREC.NUSI_SHIMEI_KANJI, 110);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  16, RREC.ATENA_JODAN, 110);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  17, RREC.ATENA_GEDAN, 110);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  18, RREC.HYOJI_CHOHYO_NO, 60);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  19, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  20, VPAGEFD,500 );
            DBMS_SQL.DEFINE_COLUMN(ICUR,  21, RREC.YUBIN_NOBC,30 );
            DBMS_SQL.DEFINE_COLUMN(ICUR,  22, RREC.GAKOKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  23, RREC.GYOSEIKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  24, RREC.CHOHYO_NO);
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(ICUR);
            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(ICUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(ICUR,  1, MJIDO_WORK(ICNT).GAKO_KBN);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  2, MJIDO_WORK(ICNT).GAKO_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  3, MJIDO_WORK(ICNT).GYOSEIKU_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  4, MJIDO_WORK(ICNT).HAN_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  5, MJIDO_WORK(ICNT).SANTEIDANTAI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  6, MJIDO_WORK(ICNT).SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  7, MJIDO_WORK(ICNT).SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  8, MJIDO_WORK(ICNT).SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  9, MJIDO_WORK(ICNT).SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  10, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  11, MJIDO_WORK(ICNT).YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  12, MJIDO_WORK(ICNT).CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  13, MJIDO_WORK(ICNT).BANCHI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  14, MJIDO_WORK(ICNT).KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  15, MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  16, MJIDO_WORK(ICNT).ATENA_JODAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  17, MJIDO_WORK(ICNT).ATENA_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  18, MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  19, MJIDO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  20, VPAGEFIELD );
                    DBMS_SQL.COLUMN_VALUE(ICUR,  21, MJIDO_WORK(ICNT).YUBIN_NOBC );
                    DBMS_SQL.COLUMN_VALUE(ICUR,  22, MJIDO_WORK(ICNT).GAKOKUMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  23, MJIDO_WORK(ICNT).GYOSEIKUMEI );
                    DBMS_SQL.COLUMN_VALUE(ICUR,  24, MJIDO_WORK(ICNT).CHOHYO_NO );
                    IF VPAGEWORK = VPAGEFIELD THEN
                        -- 以前の改頁項目値と同じ
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
                    MJIDO_WORK(ICNT).RENBAN := IGYORENBAN;
                    MJIDO_WORK(ICNT).HYOJI_RENBAN := TO_CHAR(MJIDO_WORK(ICNT).RENBAN);
                    VHYOJI_RENBAN2 := TO_CHAR(MJIDO_WORK(ICNT).CHOHYO_NO);
                    VHYOJI_RENBAN2 := LPAD(VHYOJI_RENBAN2,5,' ');
                    IF MJIDO_WORK(ICNT).GAKO_CD IS NOT NULL THEN
                       VGAKO_CD := TRIM(TO_CHAR(MJIDO_WORK(ICNT).GAKO_CD));
                       VGAKO_CD := LPAD(MJIDO_WORK(ICNT).GAKO_CD,5,' ');
                    ELSE
                       VGAKO_CD := NULL;
                    END IF;
                    IF ACONSPRM_RENBAN(1) = 0 THEN
                       MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := ' ';
                    ELSIF ACONSPRM_RENBAN(1) = 1 THEN
                       MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := VHYOJI_RENBAN2;
                    ELSIF ACONSPRM_RENBAN(1) = 2 THEN
                       MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := LTRIM(MJIDO_WORK(ICNT).GAKOKUMEI)||'-'||VHYOJI_RENBAN2;
                    ELSIF ACONSPRM_RENBAN(1) = 3 THEN
                               MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := VGAKO_CD||'-'||VHYOJI_RENBAN2;
                    ELSIF ACONSPRM_RENBAN(1) = 4 THEN
                               MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := LTRIM(MJIDO_WORK(ICNT).GAKOKUMEI)||'-'||LTRIM(MJIDO_WORK(ICNT).GYOSEIKUMEI)||'-'||VHYOJI_RENBAN2;
                    ELSIF ACONSPRM_RENBAN(1) = 5 THEN
                               MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := VGAKO_CD||'-'||LTRIM(MJIDO_WORK(ICNT).GYOSEIKUMEI)||'-'||VHYOJI_RENBAN2;
                    ELSE
                       MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := ' ';
                    END IF;
                    MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEFIELD;  -- 改頁コード

                ELSE
                    -- 全件読み込み終了
                    EXIT;
                END IF;
                ICNT := ICNT + 1;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- 処理ログの出力
                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCGET_JIDO_WK_CSV;
    --------------------------------------------------------------------------------
    -- 宛名レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_REC_ATENA(MATENA_REC OUT MTATENA_REC) RETURN NUMBER IS
        VHANTEI_CD          NVARCHAR2(500);
        IFRET               NUMBER;
    BEGIN
        IFRET := 0;
        --宛名作成レコード初期化
        MATENA_REC.YUBIN_NO := ' ';
        MATENA_REC.CHOMEI := ' ';
        MATENA_REC.BANCHI := ' ';
        MATENA_REC.KATAGAKI := ' ';
        MATENA_REC.NUSI_SHIMEI_KANJI := ' ';
        MATENA_REC.ATENA_JODAN := ' ';
        MATENA_REC.ATENA_GEDAN := ' ';
        MATENA_REC.YUBIN_NOBC := ' ';
        MATENA_REC.HYOJI_CHOHYO_NO := ' ';
        MATENA_REC.YUBIN_NO2 := ' ';
        MATENA_REC.CHOMEI2 := ' ';
        MATENA_REC.BANCHI2 := ' ';
        MATENA_REC.KATAGAKI2 := ' ';
        MATENA_REC.NUSI_SHIMEI_KANJI2 := ' ';
        MATENA_REC.ATENA_JODAN2 := ' ';
        MATENA_REC.ATENA_GEDAN2 := ' ';
        MATENA_REC.KAIPEJI_CD := ' ';
        MATENA_REC.YUBIN_NOBC2 := ' ';
        MATENA_REC.HYOJI_CHOHYO_NO2 := ' ';
        MATENA_REC.KAIPEJI_CD := MJIDO_WORK(ICNTM).KAIPEJI_CD;
        MATENA_REC.YUBIN_NO := MJIDO_WORK(ICNTM).YUBIN_NO;
        MATENA_REC.CHOMEI := MJIDO_WORK(ICNTM).CHOMEI;
        MATENA_REC.BANCHI := MJIDO_WORK(ICNTM).BANCHI;
        MATENA_REC.KATAGAKI := MJIDO_WORK(ICNTM).KATAGAKI;
        MATENA_REC.NUSI_SHIMEI_KANJI := MJIDO_WORK(ICNTM).NUSI_SHIMEI_KANJI;
        MATENA_REC.ATENA_JODAN := MJIDO_WORK(ICNTM).ATENA_JODAN;
        MATENA_REC.ATENA_GEDAN := MJIDO_WORK(ICNTM).ATENA_GEDAN;
        VHANTEI_CD := MJIDO_WORK(ICNTM).KAIPEJI_CD;
        MATENA_REC.YUBIN_NOBC := MJIDO_WORK(ICNTM).YUBIN_NOBC;
        IF NRENBAN = 0 THEN
           MATENA_REC.HYOJI_CHOHYO_NO := MJIDO_WORK(ICNTM).HYOJI_CHOHYO_NO;
        ELSE
           MATENA_REC.HYOJI_CHOHYO_NO := MJIDO_WORK(ICNTM).RENBAN;
        END IF;
        ICNTM := ICNTM + 1;
        IF ICNTM > IMAX THEN
          RETURN IFRET;
        END IF;
        IF VHANTEI_CD <> MJIDO_WORK(ICNTM).KAIPEJI_CD THEN
          RETURN IFRET;
        ELSE
          MATENA_REC.YUBIN_NO2 := MJIDO_WORK(ICNTM).YUBIN_NO;
          MATENA_REC.CHOMEI2 := MJIDO_WORK(ICNTM).CHOMEI;
          MATENA_REC.BANCHI2 := MJIDO_WORK(ICNTM).BANCHI;
          MATENA_REC.KATAGAKI2 := MJIDO_WORK(ICNTM).KATAGAKI;
          MATENA_REC.NUSI_SHIMEI_KANJI2 := MJIDO_WORK(ICNTM).NUSI_SHIMEI_KANJI;
          MATENA_REC.ATENA_JODAN2 := MJIDO_WORK(ICNTM).ATENA_JODAN;
          MATENA_REC.ATENA_GEDAN2 := MJIDO_WORK(ICNTM).ATENA_GEDAN;
          VHANTEI_CD := MJIDO_WORK(ICNTM).KAIPEJI_CD;
          MATENA_REC.YUBIN_NOBC2 := MJIDO_WORK(ICNTM).YUBIN_NOBC;
        IF NRENBAN = 0 THEN
           MATENA_REC.HYOJI_CHOHYO_NO2 := MJIDO_WORK(ICNTM).HYOJI_CHOHYO_NO;
        ELSE
           MATENA_REC.HYOJI_CHOHYO_NO2 := MJIDO_WORK(ICNTM).RENBAN;
        END IF;
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
    --------------------------------------------------------------------------------------------------
    -- 宛名ラベルＣＳＶファイル作成
    --------------------------------------------------------------------------------------------------
    FUNCTION FUNCSET_JIDO_WK_CSVFILE RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        I_RTN               PLS_INTEGER;                -- 戻り値
        IMIN                PLS_INTEGER;                -- 最小値（出力件数）
        MATENA_REC          MTATENA_REC;
        VYUBIN_NO           NVARCHAR2(60);              --郵便番号編集用
        r_WKRECORD001       GKBWL230R001%ROWTYPE;
        n_ROWNO             NUMBER := 0;
    BEGIN
        IFRET := c_ISUCCESS;               -- 正常終了
        IMAX := MJIDO_WORK.LAST;           -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;          -- ワーク領域の件数の最小値

        -- 取得した件数分繰り返す
        LOOP
          EXIT WHEN ICNTM > IMAX;
            I_RTN := FUNC_REC_ATENA(MATENA_REC);
            n_ROWNO := n_ROWNO + 1;
            r_WKRECORD001 := NULL;
            --ソート順
            r_WKRECORD001.NO := n_ROWNO;
            --郵便番号
            IF (MATENA_REC.YUBIN_NO IS NOT NULL) AND LENGTH(MATENA_REC.YUBIN_NO) > 0 AND TRIM(MATENA_REC.YUBIN_NO) <> '0' THEN
               VYUBIN_NO := TRANSLATE( MATENA_REC.YUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
               r_WKRECORD001.YUBIN_NO := VYUBIN_NO;
            ELSE
               r_WKRECORD001.YUBIN_NO := MATENA_REC.YUBIN_NO;
            END IF;
            --町名番地
            r_WKRECORD001.CHOMEI_BANCHI     := MATENA_REC.CHOMEI||MATENA_REC.BANCHI;
            --方書
            r_WKRECORD001.KATAGAKI          := MATENA_REC.KATAGAKI;
            --世帯主名
            r_WKRECORD001.SHIMEI_KANJI      := MATENA_REC.NUSI_SHIMEI_KANJI;
            --宛名上段
            r_WKRECORD001.ATENA_JODAN       := MATENA_REC.ATENA_JODAN;
            --宛名下段
            r_WKRECORD001.ATENA_GEDAN       := MATENA_REC.ATENA_GEDAN;
            --カスタマバーコード
            r_WKRECORD001.BC_NO             := MATENA_REC.YUBIN_NOBC;
            --表示帳票連番
            r_WKRECORD001.HYOJI_CHOHYO_NO   := MATENA_REC.HYOJI_CHOHYO_NO;
            --郵便番号２
            IF LENGTH(MATENA_REC.YUBIN_NO2) > 0  THEN
               VYUBIN_NO := TRANSLATE( MATENA_REC.YUBIN_NO2, '1234567890-', '１２３４５６７８９０－' );
               r_WKRECORD001.YUBIN_NO2 := VYUBIN_NO;
            ELSE
               r_WKRECORD001.YUBIN_NO2 := MATENA_REC.YUBIN_NO2;
            END IF;
            --町名番地２
            r_WKRECORD001.CHOMEI_BANCHI2    := MATENA_REC.CHOMEI2||MATENA_REC.BANCHI2;
            --方書２
            r_WKRECORD001.KATAGAKI2         := MATENA_REC.KATAGAKI2;
            --世帯主名２
            r_WKRECORD001.SHIMEI_KANJI2     := MATENA_REC.NUSI_SHIMEI_KANJI2;
            --宛名上段２
            r_WKRECORD001.ATENA_JODAN2      := MATENA_REC.ATENA_JODAN2;
            --宛名下段２
            r_WKRECORD001.ATENA_GEDAN2      := MATENA_REC.ATENA_GEDAN2;
            --改頁コード
            r_WKRECORD001.KAIPAGE_CD        := MATENA_REC.KAIPEJI_CD;
            --カスタマバーコード２
            r_WKRECORD001.YUBIN_NOBC2       := MATENA_REC.YUBIN_NOBC2;
            --表示帳票連番２
            r_WKRECORD001.HYOJI_CHOHYO_NO2  := MATENA_REC.HYOJI_CHOHYO_NO2;
            --改ページキー
            r_WKRECORD001.BREAK_NO          := MATENA_REC.KAIPEJI_CD;
            --端末番号
            r_WKRECORD001.WSNUM             := g_sWSNUM;
            --即時バッチ区分
            r_WKRECORD001.BATCHKBN          := c_BATCH;
            --ジョブNO
            r_WKRECORD001.JOBNUM            := g_nJOBNUM;

            INSERT INTO GKBWL230R001 VALUES r_WKRECORD001;
        END LOOP;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_CSVFILE', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCSET_JIDO_WK_CSVFILE;
    --------------------------------------------------------------------------------
    -- 宛名ラベル中間データ作成（ＣＳＶ用)
    --------------------------------------------------------------------------------
    FUNCTION FUNCGET_JIDO_WK_ITIRAN_CSV RETURN NUMBER IS
        IFRET               PLS_INTEGER;                   -- 戻り値
        ICNT                BINARY_INTEGER;                -- カウント
        VSQL                NVARCHAR2(10000);              -- ＳＱＬ文
        VSQLSEL             NVARCHAR2(9000);               -- ＳＱＬのソート以外
        VSQLORDER           NVARCHAR2(1000);               -- ＳＱＬの［ORDER BY］句
        ICUR                PLS_INTEGER;                   -- カーソル
        RREC                GKBWALABEL%ROWTYPE;            -- 宛名中間レコード変数
        NROWS               NUMBER;
        IPAGECNT            PLS_INTEGER;                   -- 頁数
        IGYOCNT             PLS_INTEGER;                   -- 行番号
        IGYORENBAN          PLS_INTEGER;                   -- 行連番
        VPAGENM             NVARCHAR2(1000);               -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(1000);               -- 改頁項目値のワーク
        VPAGEFD             NVARCHAR2(1000);               -- 改頁項目値のワーク
    BEGIN
        IFRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IPAGECNT := 0;
        IGYOCNT := 0;
        ICNT := 0;
        IGYORENBAN := 0;
        MJIDO_WORK.DELETE;                   -- ワーク領域の初期化
        -- ソート条件取得
        IF NRENBAN = 0 THEN
           VSQLORDER := ' GAKO_KBN,GAKO_CD,GYOSEIKU_CD,CHOHYO_NO ';
        ELSE
          IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
            VSQLORDER := g_rJSTP.Orderbyclause;
          END IF;
        END IF;
        -- ［ORDER BY］句を付加
        IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
            VSQLORDER := ' ORDER BY ' || VSQLORDER;
        ELSE
            VSQLORDER := '';
        END IF;
        
        VPAGEFD :='GAKO_KBN||GAKO_CD';
        VPAGENM :='GAKOKUMEI';

        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'GAKO_KBN, ';
            VSQLSEL := VSQLSEL || 'GAKO_CD, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
            VSQLSEL := VSQLSEL || 'HAN_CD, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
            VSQLSEL := VSQLSEL || 'SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
            IF NRENBAN =0 THEN
               IF ACONSPRM_RENBAN(1) IN (1,2,3) THEN
                  VSQLSEL := VSQLSEL || ' GAKO_KBN || GAKO_CD '|| ' PAGE_FIELD, ';          -- 改頁値を設定
                  VSQLSEL := VSQLSEL || ' GAKOKUMEI '|| ' PAGE_NAME, ';                     -- 改頁名を設定
               ELSIF ACONSPRM_RENBAN(1) IN (4,5) THEN
                  VSQLSEL := VSQLSEL || ' GAKO_KBN || GAKO_CD || GYOSEIKU_CD '|| ' PAGE_FIELD, ';     -- 改頁値を設定
                  VSQLSEL := VSQLSEL || ' GAKOKUMEI || '' '' || GYOSEIKUMEI '|| ' PAGE_NAME, ';      -- 改頁名を設定
               ELSE
                  VSQLSEL := VSQLSEL || ' NULL AS PAGE_FIELD, ';                            -- 改頁値を設定
                  VSQLSEL := VSQLSEL || ' NULL AS PAGE_NAME, ';                            -- 改頁名を設定
               END IF;
            ELSE
                  VSQLSEL := VSQLSEL ||  VPAGEFD || ' PAGE_FIELD, ';     -- 改頁値を設定
                  VSQLSEL := VSQLSEL ||  VPAGENM || ' PAGE_NAME, ';      -- 改頁名を設定
            END IF;
            VSQLSEL := VSQLSEL || 'RENBAN, ';
            VSQLSEL := VSQLSEL || 'GAKOKUMEI, ';
            VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_JODAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_GEDAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_KOJIN_NO, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'JIDO_CHOMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_BANCHI, ';
            VSQLSEL := VSQLSEL || 'JIDO_KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'JIDO_YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_ZOKUGARAMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_ZOKUGARAMEI, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_CHOMEI, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_BANCHI, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN, ';
            VSQLSEL := VSQLSEL || 'KIJUN_BI, ';
            VSQLSEL := VSQLSEL || 'CHOHYO_NO ';   --帳票連番
            VSQLSEL := VSQLSEL || ',JINKAKU_KBN ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWALABEL ';
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;
            -- カーソルのオープン
            ICUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(ICUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
                DBMS_SQL.DEFINE_COLUMN(ICUR,  1, RREC.GAKO_KBN);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  2, RREC.GAKO_CD);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  3, RREC.GYOSEIKU_CD);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  4, RREC.HAN_CD);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  5, RREC.SANTEIDANTAI_CD);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  6, RREC.SHIMEI_KANA, 100);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  7, RREC.SEINENGAPI);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  8, RREC.SEIBETSU);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  9, RREC.SETAI_NO);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  10, RREC.HOGOSHA_SHIMEI_KANA, 100);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  11, RREC.KAIPEJI_CD, 500);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  12, RREC.KAIPEJI, 500);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  13, VPAGEFD, 500);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  14, VPAGENM, 500);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  15, RREC.RENBAN);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  16, RREC.GAKOKUMEI, 20);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  17, RREC.SAKUSEIBI, 30);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  18, RREC.GYOSEIKUMEI, 20);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  19, RREC.JIDO_SHIMEI_JODAN, 100);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  20, RREC.JIDO_SHIMEI_GEDAN, 100);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  21, RREC.JIDO_KOJIN_NO);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  22, RREC.HYOJI_SEINENGAPI,11 );
                DBMS_SQL.DEFINE_COLUMN(ICUR,  23, RREC.HYOJI_SEIBETSU,2 );
-- 2024/06/11 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--                DBMS_SQL.DEFINE_COLUMN(ICUR,  24, RREC.JIDO_CHOMEI, 40);
--                DBMS_SQL.DEFINE_COLUMN(ICUR,  25, RREC.JIDO_BANCHI, 40);
--                DBMS_SQL.DEFINE_COLUMN(ICUR,  26, RREC.JIDO_KATAGAKI, 60);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  24, RREC.JIDO_CHOMEI, 136);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  25, RREC.JIDO_BANCHI, 50);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  26, RREC.JIDO_KATAGAKI, 300);
-- 2024/06/11 ZCZL.wangqiwei Update end
                DBMS_SQL.DEFINE_COLUMN(ICUR,  27, RREC.JIDO_YUBIN_NO, 10);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  28, RREC.HOGOSHA_SHIMEI_JODAN, 100);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  29, RREC.HOGOSHA_SHIMEI_GEDAN, 100);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  30, RREC.HOGOSHA_ZOKUGARAMEI, 30);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  31, RREC.JIDO_ZOKUGARAMEI, 30);
-- 2024/06/11 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--                DBMS_SQL.DEFINE_COLUMN(ICUR,  32, RREC.HOGOSHA_CHOMEI, 40);
--                DBMS_SQL.DEFINE_COLUMN(ICUR,  33, RREC.HOGOSHA_BANCHI,40);
--                DBMS_SQL.DEFINE_COLUMN(ICUR,  34, RREC.HOGOSHA_KATAGAKI,60 );
                DBMS_SQL.DEFINE_COLUMN(ICUR,  32, RREC.HOGOSHA_CHOMEI, 136);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  33, RREC.HOGOSHA_BANCHI,50);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  34, RREC.HOGOSHA_KATAGAKI,300 );
-- 2024/06/11 ZCZL.wangqiwei Update end
                DBMS_SQL.DEFINE_COLUMN(ICUR,  35, RREC.HOGOSHA_YUBIN_NO, 10);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  36, RREC.KON_JUSHO_JODAN,120);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  37, RREC.KON_JUSHO_GEDAN,120);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  38, RREC.KIJUN_BI,16);
                DBMS_SQL.DEFINE_COLUMN(ICUR,  39, RREC.CHOHYO_NO);   --帳票連番
                DBMS_SQL.DEFINE_COLUMN(ICUR,  40, RREC.JINKAKU_KBN);
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(ICUR);
            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(ICUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(ICUR,  1, MJIDO_WORK(ICNT).GAKO_KBN);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  2, MJIDO_WORK(ICNT).GAKO_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  3, MJIDO_WORK(ICNT).GYOSEIKU_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  4, MJIDO_WORK(ICNT).HAN_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  5, MJIDO_WORK(ICNT).SANTEIDANTAI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  6, MJIDO_WORK(ICNT).SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  7, MJIDO_WORK(ICNT).SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  8, MJIDO_WORK(ICNT).SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  9, MJIDO_WORK(ICNT).SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  10, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  11, MJIDO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  12, MJIDO_WORK(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  13, VPAGEFD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  14, VPAGENM);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  15, MJIDO_WORK(ICNT).RENBAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  16, MJIDO_WORK(ICNT).GAKOKUMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  17, MJIDO_WORK(ICNT).SAKUSEIBI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  18, MJIDO_WORK(ICNT).GYOSEIKUMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  19, MJIDO_WORK(ICNT).JIDO_SHIMEI_JODAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  20, MJIDO_WORK(ICNT).JIDO_SHIMEI_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  21, MJIDO_WORK(ICNT).JIDO_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  22, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  23, MJIDO_WORK(ICNT).HYOJI_SEIBETSU );
                    DBMS_SQL.COLUMN_VALUE(ICUR,  24, MJIDO_WORK(ICNT).JIDO_CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  25, MJIDO_WORK(ICNT).JIDO_BANCHI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  26, MJIDO_WORK(ICNT).JIDO_KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  27, MJIDO_WORK(ICNT).JIDO_YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  28, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  29, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  30, MJIDO_WORK(ICNT).HOGOSHA_ZOKUGARAMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  31, MJIDO_WORK(ICNT).JIDO_ZOKUGARAMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  32, MJIDO_WORK(ICNT).HOGOSHA_CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  33, MJIDO_WORK(ICNT).HOGOSHA_BANCHI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  34, MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  35, MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  36, MJIDO_WORK(ICNT).KON_JUSHO_JODAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  37, MJIDO_WORK(ICNT).KON_JUSHO_GEDAN );
                    DBMS_SQL.COLUMN_VALUE(ICUR,  38, MJIDO_WORK(ICNT).KIJUN_BI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  39, MJIDO_WORK(ICNT).CHOHYO_NO);   --帳票連番
                    DBMS_SQL.COLUMN_VALUE(ICUR,  40, MJIDO_WORK(ICNT).JINKAKU_KBN);
                    IF VPAGEWORK = VPAGENM OR (VPAGEWORK IS NULL AND VPAGENM IS NULL)THEN
                    -- 以前の改頁項目値と同じ
                         IGYOCNT := IGYOCNT + 1;
                         IGYORENBAN := IGYORENBAN + 1;
                    ELSE
                    -- 改頁必要
                         IPAGECNT := IPAGECNT + 1;
                         IGYOCNT := 1;
                         IGYORENBAN := 1;
                         VPAGEWORK := VPAGENM;
                    END IF;
                    IF NRENBAN = 0 THEN
                       MJIDO_WORK(ICNT).RENBAN := MJIDO_WORK(ICNT).CHOHYO_NO;
                    ELSE
                       MJIDO_WORK(ICNT).RENBAN := IGYORENBAN;
                    END IF;
                    MJIDO_WORK(ICNT).HYOJI_RENBAN := TO_CHAR(MJIDO_WORK(ICNT).RENBAN);
                    -- 再セットする項目
                    MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEFD;  -- 改頁コード
                    MJIDO_WORK(ICNT).KAIPEJI:= VPAGENM;  -- 改頁名

                ELSE
                    -- 全件読み込み終了
                    EXIT;
                END IF;
                ICNT := ICNT + 1;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- 処理ログの出力
                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_ITIRAN_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_ITIRAN_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCGET_JIDO_WK_ITIRAN_CSV;
    --------------------------------------------------------------------------------------------------
    -- 宛名ラベルＣＳＶファイル作成
    --------------------------------------------------------------------------------------------------
    FUNCTION FUNCSET_JIDO_WK_ITIRAN_CSVFILE RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        IMIN                PLS_INTEGER;                -- 最小値（出力件数）
        VHOGOSHA_YUBIN_NO   NVARCHAR2(60);              -- 郵便番号編集用
        r_WKRECORD002       GKBWL230R002%ROWTYPE;
        n_ROWNO             NUMBER := 0;
    BEGIN
        ICNTM := 0;
        IFRET := c_ISUCCESS;               -- 正常終了
        IMAX := MJIDO_WORK.LAST;           -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;          -- ワーク領域の件数の最小値

        -- 取得した件数分繰り返す
        LOOP
            EXIT WHEN ICNTM > IMAX;
              MATENA_A_ITIRAN_REC.KAIPEJI_CD :=  MJIDO_WORK(ICNTM).KAIPEJI_CD;
              MATENA_A_ITIRAN_REC.KAIPEJI :=  MJIDO_WORK(ICNTM).KAIPEJI;
              MATENA_A_ITIRAN_REC.RENBAN :=  MJIDO_WORK(ICNTM).RENBAN;
              MATENA_A_ITIRAN_REC.GAKOKUMEI :=  MJIDO_WORK(ICNTM).GAKOKUMEI;
              MATENA_A_ITIRAN_REC.GAKOKUCD :=  MJIDO_WORK(ICNTM).GAKO_CD;
              MATENA_A_ITIRAN_REC.SAKUSEIBI :=  MJIDO_WORK(ICNTM).SAKUSEIBI;
              MATENA_A_ITIRAN_REC.GYOSEIKUMEI :=  MJIDO_WORK(ICNTM).GYOSEIKUMEI;
              MATENA_A_ITIRAN_REC.JIDO_SHIMEI_JODAN :=  MJIDO_WORK(ICNTM).JIDO_SHIMEI_JODAN;
              MATENA_A_ITIRAN_REC.JIDO_SHIMEI_GEDAN :=  MJIDO_WORK(ICNTM).JIDO_SHIMEI_GEDAN;
              MATENA_A_ITIRAN_REC.JIDO_KOJIN_NO :=  MJIDO_WORK(ICNTM).JIDO_KOJIN_NO;
              MATENA_A_ITIRAN_REC.HYOJI_SEINENGAPI :=  MJIDO_WORK(ICNTM).HYOJI_SEINENGAPI;
              MATENA_A_ITIRAN_REC.HYOJI_SEIBETSU :=  MJIDO_WORK(ICNTM).HYOJI_SEIBETSU;
              MATENA_A_ITIRAN_REC.JIDO_CHOMEI :=  MJIDO_WORK(ICNTM).JIDO_CHOMEI;
              MATENA_A_ITIRAN_REC.JIDO_BANCHI :=  MJIDO_WORK(ICNTM).JIDO_BANCHI;
              MATENA_A_ITIRAN_REC.JIDO_KATAGAKI :=  MJIDO_WORK(ICNTM).JIDO_KATAGAKI;
              MATENA_A_ITIRAN_REC.JIDO_YUBIN_NO :=  MJIDO_WORK(ICNTM).JIDO_YUBIN_NO;
              MATENA_A_ITIRAN_REC.HOGOSHA_SHIMEI_JODAN :=  MJIDO_WORK(ICNTM).HOGOSHA_SHIMEI_JODAN;
              MATENA_A_ITIRAN_REC.HOGOSHA_SHIMEI_GEDAN :=  MJIDO_WORK(ICNTM).HOGOSHA_SHIMEI_GEDAN;
              MATENA_A_ITIRAN_REC.HOGOSHA_ZOKUGARAMEI :=  MJIDO_WORK(ICNTM).HOGOSHA_ZOKUGARAMEI;
              MATENA_A_ITIRAN_REC.JIDO_ZOKUGARAMEI :=  MJIDO_WORK(ICNTM).JIDO_ZOKUGARAMEI;
              MATENA_A_ITIRAN_REC.HOGOSHA_CHOMEI :=  MJIDO_WORK(ICNTM).HOGOSHA_CHOMEI;
              MATENA_A_ITIRAN_REC.HOGOSHA_BANCHI :=  MJIDO_WORK(ICNTM).HOGOSHA_BANCHI;
              MATENA_A_ITIRAN_REC.HOGOSHA_KATAGAKI :=  MJIDO_WORK(ICNTM).HOGOSHA_KATAGAKI;
              MATENA_A_ITIRAN_REC.HOGOSHA_YUBIN_NO :=  MJIDO_WORK(ICNTM).HOGOSHA_YUBIN_NO;
              MATENA_A_ITIRAN_REC.KON_JUSHO_JODAN := MJIDO_WORK(ICNTM).KON_JUSHO_JODAN;
              MATENA_A_ITIRAN_REC.KON_JUSHO_GEDAN := MJIDO_WORK(ICNTM).KON_JUSHO_GEDAN;
              MATENA_A_ITIRAN_REC.KIJUN_BI:=  MJIDO_WORK(ICNTM).KIJUN_BI;
              MATENA_A_ITIRAN_REC.SEINENGAPI_KAISI := ' ';
              MATENA_A_ITIRAN_REC.SEINENGAPI_SYURYO := ' ';
              MATENA_A_ITIRAN_REC.JINKAKU_KBN := MJIDO_WORK(ICNTM).JINKAKU_KBN;

              n_ROWNO := n_ROWNO + 1;
              r_WKRECORD002 := NULL;
              --ソート順
              r_WKRECORD002.NO                           := n_ROWNO;
              --改頁コード
              r_WKRECORD002.KAIPAGE_CD                   := MATENA_A_ITIRAN_REC.KAIPEJI_CD;
              --改頁名
              r_WKRECORD002.KAIPAGE_MEI                  := MATENA_A_ITIRAN_REC.KAIPEJI;
              --No
              r_WKRECORD002.NUM                          := MATENA_A_ITIRAN_REC.RENBAN;
              --学校名
              r_WKRECORD002.GAKKO_MEI                    := MATENA_A_ITIRAN_REC.GAKOKUMEI;
              --学校コード
              r_WKRECORD002.GAKKO_CD                     := MATENA_A_ITIRAN_REC.GAKOKUCD;
              --作成日
              r_WKRECORD002.SAKUSEIBI                    := MATENA_A_ITIRAN_REC.SAKUSEIBI;
              --行政区
              r_WKRECORD002.GYOSEIKU                     := MATENA_A_ITIRAN_REC.GYOSEIKUMEI;
              --児童氏名かな
              r_WKRECORD002.JIDO_SHIMEI_KANA             := MATENA_A_ITIRAN_REC.JIDO_SHIMEI_JODAN;
              --児童氏名漢字
              r_WKRECORD002.JIDO_SHIMEI_KANJI            := MATENA_A_ITIRAN_REC.JIDO_SHIMEI_GEDAN;
              --児童個人番号
              r_WKRECORD002.JIDO_KOJIN_NO                := MATENA_A_ITIRAN_REC.JIDO_KOJIN_NO;
              --生年月日
              r_WKRECORD002.SEINENGAPI                   := MATENA_A_ITIRAN_REC.HYOJI_SEINENGAPI;
              --性別
              r_WKRECORD002.SEIBETSU                     := MATENA_A_ITIRAN_REC.HYOJI_SEIBETSU;
              --児童町名番地方書
              r_WKRECORD002.JIDO_CHOMEI_BANCHI_KATAGAKI  := MATENA_A_ITIRAN_REC.JIDO_CHOMEI ||MATENA_A_ITIRAN_REC.JIDO_BANCHI ||MATENA_A_ITIRAN_REC.JIDO_KATAGAKI;
              --児童郵便番号
              r_WKRECORD002.JIDO_YUBIN_NO                := MATENA_A_ITIRAN_REC.JIDO_YUBIN_NO;
              --保護者氏名上段
              r_WKRECORD002.HOGOSHA_SHIMEI_JODAN         := MATENA_A_ITIRAN_REC.HOGOSHA_SHIMEI_JODAN;
              --保護者氏名下段
              r_WKRECORD002.HOGOSHA_SHIMEI_GEDAN         := MATENA_A_ITIRAN_REC.HOGOSHA_SHIMEI_GEDAN;
              --保護者続柄名
              r_WKRECORD002.HOGOSHA_ZOKUGARAMEI          := MATENA_A_ITIRAN_REC.HOGOSHA_ZOKUGARAMEI;
              --児童続柄名
              r_WKRECORD002.JIDO_ZOKUGARAMEI             := MATENA_A_ITIRAN_REC.JIDO_ZOKUGARAMEI;
              --保護者町名番地方書
              r_WKRECORD002.HOGOSHA_JUSHO                := MATENA_A_ITIRAN_REC.HOGOSHA_CHOMEI || MATENA_A_ITIRAN_REC.HOGOSHA_BANCHI || MATENA_A_ITIRAN_REC.HOGOSHA_KATAGAKI;
              --保護者郵便番号
              IF LENGTH(MATENA_A_ITIRAN_REC.HOGOSHA_YUBIN_NO) > 0 AND TRIM(MATENA_A_ITIRAN_REC.HOGOSHA_YUBIN_NO) <> '0' THEN
                VHOGOSHA_YUBIN_NO := SUBSTR(MATENA_A_ITIRAN_REC.HOGOSHA_YUBIN_NO,1,3)||'-'||SUBSTR(MATENA_A_ITIRAN_REC.HOGOSHA_YUBIN_NO,4);
                r_WKRECORD002.HOGOSHA_YUBIN_NO := VHOGOSHA_YUBIN_NO;
              ELSE
                r_WKRECORD002.HOGOSHA_YUBIN_NO := '';
              END IF;
              --保護者住所上段
              r_WKRECORD002.HOGOSHA_JUSHO_JODAN          := MATENA_A_ITIRAN_REC.KON_JUSHO_JODAN;
              --保護者住所下段
              r_WKRECORD002.HOGOSHA_JUSHO_GEDAN          := MATENA_A_ITIRAN_REC.KON_JUSHO_GEDAN;
              --基準日
              r_WKRECORD002.KIJUNBI                      := MATENA_A_ITIRAN_REC.KIJUN_BI;
              --生年月日開始
              r_WKRECORD002.SEINENGAPI_KAISHI            := MATENA_A_ITIRAN_REC.SEINENGAPI_KAISI;
              --生年月日終了
              r_WKRECORD002.SEINENGAPI_SHURYO            := MATENA_A_ITIRAN_REC.SEINENGAPI_SYURYO;
              --人格区分
              r_WKRECORD002.JINKAKU_KBN                  := MATENA_A_ITIRAN_REC.JINKAKU_KBN;
              --改ページキー
              r_WKRECORD002.BREAK_NO                     := NULL;
              --端末番号
              r_WKRECORD002.WSNUM                        := g_sWSNUM;
              --即時バッチ区分
              r_WKRECORD002.BATCHKBN                     := c_BATCH;
              --ジョブNO
              r_WKRECORD002.JOBNUM                       := g_nJOBNUM;

              INSERT INTO GKBWL230R002 VALUES r_WKRECORD002;
            --１レコードのイメージをセット
            ICNTM :=ICNTM+1;
        END LOOP;
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_ITIRAN_CSVFILE', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCSET_JIDO_WK_ITIRAN_CSVFILE;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        ERR              EXCEPTION;
-- 2024/06/05 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発の標準化対応
        o_tITEM       A_CONS_PRM;
        nRTN              NUMBER;
        g_aSHIMEIPRM  A_CONS_PRM;    
-- 2024/06/05 ZCZL.wangqiwei Add end
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        --帳票IDに関連な変数にIF内で書く
        IF g_nSTEP_INDEX = 1 THEN

           -- 取得した条件をそれぞれの変数へセット
-- 2024/08/05 ZCZL.wangqiwei Update start 0.3.000.001:検収指摘No.359の対応
--            IRTN := GKBPK00010.FGKOCDTR(g_VJYOUKEN01,VSYOGAKO_CD);  --小学校コード
--            IRTN := GKBPK00010.FGKOCDTR(g_VJYOUKEN02,VTYUGAKO_CD);  --中学校コード
--            IRTN := GKBPK00010.FGKOCDTR(g_VJYOUKEN03,VKUIKIGAI_CD);  --区域外学校コード
--            IRTN := GKBPK00010.FGKOCDTR(g_VJYOUKEN04,VYOGOGAKO_CD);  --盲聾養護学校コード
           bRTN := FUNC_GET_GAKOCD(g_VJYOUKEN01,VSYOGAKO_CD);  --小学校コード
           bRTN := FUNC_GET_GAKOCD(g_VJYOUKEN02,VTYUGAKO_CD);  --中学校コード
           bRTN := FUNC_GET_GAKOCD(g_VJYOUKEN03,VKUIKIGAI_CD);  --区域外学校コード
           bRTN := FUNC_GET_GAKOCD(g_VJYOUKEN04,VYOGOGAKO_CD);  --盲聾養護学校コード
--  2025/12/17 CTC.HJF UPDATE START 1.0.404.000:GKB_QA17301対応
           bRTN := FUNC_GET_GAKOCD(g_VJYOUKEN09,VKUNISHIRITSU_CD);  --国私立学校コード
--  2025/12/17 CTC.HJF UPDATE END
-- 2024/08/05 ZCZL.wangqiwei Update end
           VGAKUNEN := g_VJYOUKEN05;                 --学年
           VRENBAN := g_VJYOUKEN06;                  --帳票連番使用有無
           VHAKOBI := g_VJYOUKEN07;                  --発行日
-- 2024/06/05 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発の標準化対応
--            VNINIBIT := g_VJYOUKEN08;                 --任意ビット項目
           IGAKUNEN := TO_NUMBER(VGAKUNEN);    -- 学年
           NRENBAN := TO_NUMBER(VRENBAN);      --帳票連番使用有無
           NHAKOBI:= TO_NUMBER(VHAKOBI);       --発行日

           IRTN_ATENA := KKAPK0030.FPRMSHUTOKU('GKB','00ATENA',0,ACONSPRM_ATENA,NLENGTH);
           IF IRTN_ATENA = 1 THEN
              ACONSPRM_ATENA := A_CONS_PRM();
              ACONSPRM_ATENA.EXTEND;
              ACONSPRM_ATENA.EXTEND;
              ACONSPRM_ATENA(1) := 0;
              ACONSPRM_ATENA.EXTEND;
              ACONSPRM_ATENA(2) := 0;
              ACONSPRM_ATENA.EXTEND;
              ACONSPRM_ATENA(3) := 0;
              ACONSPRM_ATENA.EXTEND;
              ACONSPRM_ATENA(4) := 0;
           ELSE
              WHILE (NLENGTH < 4) LOOP
                 ACONSPRM_ATENA.EXTEND;
                 ACONSPRM_ATENA(NLENGTH+1) := 0;
                 NLENGTH := NLENGTH + 1;
              END LOOP;
           END IF;
           IRTN_RENBAN := KKAPK0030.FPRMSHUTOKU('GKB','00RENBAN',0,ACONSPRM_RENBAN,NLENGTH);
           IF IRTN_RENBAN =1 THEN
              ACONSPRM_RENBAN := A_CONS_PRM();
              ACONSPRM_RENBAN.EXTEND;
              ACONSPRM_RENBAN.EXTEND;
              ACONSPRM_RENBAN(1) := 0;
           ELSE
             WHILE (NLENGTH < 1) LOOP
                ACONSPRM_RENBAN.EXTEND;
                ACONSPRM_RENBAN(NLENGTH+1) := 0;
                NLENGTH := NLENGTH + 1;
             END LOOP;
           END IF;
           --制御情報を取得
           IRTN_SHIMEI := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,ACONSPRM_SHIMEI,NLENGTH1);
           IF IRTN_SHIMEI =1 THEN
                     ACONSPRM_SHIMEI := A_CONS_PRM();
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(1) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(2) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(3) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(4) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(5) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(6) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(7) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(8) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(9) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(10) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(11) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(12) := 0;
                     ACONSPRM_SHIMEI.EXTEND;
                     ACONSPRM_SHIMEI(13) := 0;
           ELSE
             WHILE (NLENGTH1 < 14) LOOP
               ACONSPRM_SHIMEI.EXTEND;
               ACONSPRM_SHIMEI(NLENGTH1+1) := 0;
               NLENGTH1 := NLENGTH1 + 1;
             END LOOP;
           END IF;
-- 2024/06/11 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応 
        I_RTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, o_tITEM);
        IF I_RTN = 0 THEN
            FOR j IN 1..o_tITEM.COUNT LOOP
                IF o_tITEM(j) = 'GKB230R001' THEN
                    g_nGKB010_INDEX := j;
                    EXIT;
                END IF;
            END LOOP;
        END IF;
        -- 本名・通称名　出力制御
        I_RTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, o_tITEM);
        IF I_RTN = 0 AND g_nGKB010_INDEX <= o_tITEM.COUNT THEN
            g_sATENA := o_tITEM(g_nGKB010_INDEX);
        END IF;
-- 2024/06/11 ZCZL.wangqiwei Add end
           
--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
         END IF; 
           -- 宛名ラベルワーク（GKBWALABEL）のデータ全件削除
           I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
           IF I_RTN = c_INOT_SUCCESS THEN
           -- エラーで帰ってきた場合
               B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
               RAISE ERR;
           END IF;
-- 2024/06/26 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発の標準化対応
            DELETE FROM GKBWALABEL;
           -- 宛名ラベルワーク中間データ作成
           I_RTN := FUNC_GET_JIDO_WK;
           IF I_RTN <> c_ISUCCESS THEN
           -- エラーで帰ってきた場合
               IF I_RTN = c_INOTFOUND THEN
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--                  B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
                 GOTO END_EXIT;
               END IF;
               RAISE ERR;
           END IF;
           -- 宛名ラベルワーク作成
           I_RTN := FUNC_INSERT_JIDO_WK;
           IF I_RTN = c_INOT_SUCCESS THEN
           -- エラーで帰ってきた場合
               RAISE ERR;
           END IF;
--  2024/04/22 ZCZL.WUCAO DELETE 0.2.000.001:512_GKB_00027対応
--        END IF;

        --帳票出力CSVの作成
        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB230R001' THEN
            --ワークテーブルのデータを削除する
            DELETE FROM GKBWL230R001 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
            -- 宛名ラベル中間データ作成（ＣＳＶ用）
            I_RTN := FUNCGET_JIDO_WK_CSV;
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            -- ※ 終了処理は処理の内部で行っています
                RAISE ERR;
            END IF;
            -- 宛名ラベル中間ＣＳＶファイル作成
            I_RTN := FUNCSET_JIDO_WK_CSVFILE;
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            -- ※ 終了処理は処理の内部で行っています
                RAISE ERR;
            END IF;
            bRTN :=FUNC_B11CSV('GKBWL230R001');
          WHEN 'GKB230R002' THEN
            --ワークテーブルのデータを削除する
            DELETE FROM GKBWL230R002 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
             -- 宛名ラベル中間データ作成（ＣＳＶ用）
            I_RTN := FUNCGET_JIDO_WK_ITIRAN_CSV;
            IF I_RTN <> c_ISUCCESS THEN
                RAISE ERR;
            END IF;
            -- 宛名ラベル中間ＣＳＶファイル作成
            I_RTN := FUNCSET_JIDO_WK_ITIRAN_CSVFILE;
            IF I_RTN <> c_ISUCCESS THEN
                RAISE ERR;
            END IF;
            bRTN :=FUNC_B11CSV('GKBWL230R002');
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
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
    --  作成者／作成日: ZCZL.WANGZHICHAO   2024/1/2
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
END GKBPB00260;
/
