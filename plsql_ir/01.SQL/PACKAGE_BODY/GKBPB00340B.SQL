CREATE OR REPLACE PACKAGE BODY GKBPB00340
--1.0.205.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 教育児童生徒集計
--  機能概要      : 学齢簿登録者の集計表、集計一覧を作成する機能の追加
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/07/12 ZCZL.QINYUE UPDATE 0.3.000.000:新WizLIFE2次開発
--  2024/08/30 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00075対応
--  2024/09/02 ZCZL.WANGMING UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00081、IT_GKB_00101対応
--  2024/10/12 ZCZL.WANGMING Update 0.3.000.004:仕様変更 IT_GKB_00081二次対応
--  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.005:IT_GKB_00079仕様変更対応
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00416対応
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00659対応
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応
--  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:ST_GKB_TMP00008対応
--  2025/05/15 CTC.GL UPDATE 1.0.004.000:GKB_QA14730対応
--  2025/05/16 CTC.HJF UPDATE 1.0.004.000:GKB_QA12945対応
--  2025/06/11 CTC.HJF UPDATE 1.0.008.000:GKB_QA15686対応
--  2025/07/24 CTC.XMB ADD 1.0.012.000:GKC_QA19006対応
--  2025/09/25 CTC.HJF UPDATE 1.0.106.001:GKB_QA20729
--  2025/11/06 CTC.HJF UPDATE 1.0.205.000:GKB_QA22077
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

    --画面から条件
    g_vJYOUKEN1  NVARCHAR2(500);
    g_vJYOUKEN2  NVARCHAR2(500);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応    
    --g_vJYOUKEN3  NVARCHAR2(500);
    --g_vJYOUKEN4  NVARCHAR2(500);
    --g_vJYOUKEN5  NVARCHAR2(500);
    --g_vJYOUKEN6  NVARCHAR2(500);
    g_vJYOUKEN3  NVARCHAR2(3000);
    g_vJYOUKEN4  NVARCHAR2(3000);
    g_vJYOUKEN5  NVARCHAR2(3000);
    g_vJYOUKEN6  NVARCHAR2(3000);
--  --  2024/11/14 ZCZL.WANGYUNING UPDATE END
    g_vJYOUKEN7  NVARCHAR2(500);
    g_vJYOUKEN8  NVARCHAR2(500);
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応    
    --g_vJYOUKEN9  NVARCHAR2(500);
    g_vJYOUKEN9  NVARCHAR2(3000);
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
    TYPE CRATENA_TYPE IS RECORD
    (
      KOJIN_NO             GKBTGAKUREIBO.KOJIN_NO%TYPE,
      RIREKI_RENBAN        GKBTGAKUREIBO.RIREKI_RENBAN%TYPE,
-- 2024/07/12 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発の標準化対応  
--       NINIBIT1             GKBTNINIBIT.NINIBIT1%TYPE,
--       NINIBIT2             GKBTNINIBIT.NINIBIT2%TYPE,
--       NINIBIT3             GKBTNINIBIT.NINIBIT3%TYPE,
--       NINIBIT4             GKBTNINIBIT.NINIBIT4%TYPE,
--       NINIBIT5             GKBTNINIBIT.NINIBIT5%TYPE,
--       NINIBIT6             GKBTNINIBIT.NINIBIT6%TYPE,
--       NINIBIT7             GKBTNINIBIT.NINIBIT7%TYPE,
--       NINIBIT8             GKBTNINIBIT.NINIBIT8%TYPE,
--       NINIBIT9             GKBTNINIBIT.NINIBIT9%TYPE,
--       NINIBIT10            GKBTNINIBIT.NINIBIT10%TYPE,
--       NINIBIT11            GKBTNINIBIT.NINIBIT11%TYPE,
--       NINIBIT12            GKBTNINIBIT.NINIBIT12%TYPE,
--       NINIBIT13            GKBTNINIBIT.NINIBIT13%TYPE,
--       NINIBIT14            GKBTNINIBIT.NINIBIT14%TYPE,
--       NINIBIT15            GKBTNINIBIT.NINIBIT15%TYPE,
--       NINIBIT16            GKBTNINIBIT.NINIBIT16%TYPE,
--       NINIBIT17            GKBTNINIBIT.NINIBIT17%TYPE,
--       NINIBIT18            GKBTNINIBIT.NINIBIT18%TYPE,
--       NINIBIT19            GKBTNINIBIT.NINIBIT19%TYPE,
--       NINIBIT20            GKBTNINIBIT.NINIBIT20%TYPE,
--       JINKAKU_KBN     GABTATENAKIHON.JINKAKU_KBN%TYPE,
      RIREKI_RENBAN_EDA    GKBTGAKUREIBO.RIREKI_RENBAN_EDA%TYPE,
      SYOGAKO_CD           GKBTGAKUREIBO.SYOGAKO_CD%TYPE,
      TYUGAKO_CD           GKBTGAKUREIBO.TYUGAKO_CD%TYPE,
      KUIKIGAI_CD          GKBTGAKUREIBO.KUIKIGAI_CD%TYPE,
      YOGOGAKO_CD          GKBTGAKUREIBO.YOGOGAKO_CD%TYPE,
      KUNISHIRITSU_CD      GKBTGAKUREIBO.KUNISHIRITSU_CD%TYPE,
      SEIBETSU             GKBTGAKUREIBO.SEIBETSU%TYPE,
      GAKKO_KBN_CD         GKBTGAKUREIBO.GAKKO_KBN_CD%TYPE,
      GAKUNEN              GKBTGAKUREIBO.GAKUNEN%TYPE,
      SHOGAKKOKU_CD        GKBTGAKUREIBO.SHOGAKKOKU_CD%TYPE,
      CHUGAKKOKU_CD        GKBTGAKUREIBO.CHUGAKKOKU_CD%TYPE,
--  2024/09/29 ZCZL.yangshua Update 0.3.000.003:仕様変更 IT_GKB_00081対応
--       OAZA_CD              GABVATENAALL.OAZA_CD%TYPE,
--       SANTEIDANTAI_CD      GABVATENAALL.SANTEIDANTAI_CD%TYPE,
--       GYOSEIKU_CD          GABVATENAALL.GYOSEIKU_CD%TYPE,
--  2024/10/12 ZCZL.WANGMING Update START 0.3.000.004:仕様変更 IT_GKB_00081二次対応
--      OAZA_CD              GABTATENARIREKI.OAZA_CD%TYPE,
--      SANTEIDANTAI_CD      GABTATENARIREKI.SANTEIDANTAI_CD%TYPE,
--      GYOSEIKU_CD          GABTATENARIREKI.GYOSEIKU_CD%TYPE,
      OAZA_CD              GABVATENAALL_B.OAZA_CD%TYPE,
      SANTEIDANTAI_CD      GABVATENAALL_B.SANTEIDANTAI_CD%TYPE,
      GYOSEIKU_CD          GABVATENAALL_B.GYOSEIKU_CD%TYPE,
--  2024/10/12 ZCZL.WANGMING Update END
--  2024/09/29 ZCZL.yangshua Update end
      GAKUKYU_KBN          GKBTMSGAKUKYUCD.GAKUKYU_KBN%TYPE

-- 2024/07/12 ZCZL.qinyue Update end
    );

    CRATENA_WORK CRATENA_TYPE;
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- ERROR関連 --
    -- デバック
    N_SQL_CODE      NUMBER;             -- SQLエラーコード
    V_SQL_MSG       NVARCHAR2(255);     -- SQLエラーメッセージ
    c_BERROR        CONSTANT  BOOLEAN :=  FALSE;
    -- 処理結果
    c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    c_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし
    -- 処理条件数
    c_IJOKEN       CONSTANT  PLS_INTEGER := 20;        -- 処理条件取得処理から取得される項目は２０個
    -- 正常メッセージの値
    c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '教育児童生徒集計作成処理が正常終了しました。';
    -- エラーメッセージの値
    c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '教育児童生徒集計作成処理が異常終了しました。';
    -- 児童生徒ワーク
    c_VTABLE      CONSTANT  NVARCHAR2(128) := 'GKBWJIDOZAIGAKU';
    -- １頁の最大行数
    c_IMAXROWS     CONSTANT  PLS_INTEGER := 15;
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    ISAKUSEIBI          PLS_INTEGER;
    RG                  GKBTGAKUREIBO%ROWTYPE;
    RA                  GABTATENAKIHON%ROWTYPE;
    RB                  GABTATENAKIHON%ROWTYPE;
    RC                  GABTSOFUSAKI%ROWTYPE;
    RASO                GABTSOFUSAKI%ROWTYPE;
    IGAKO_CD            PLS_INTEGER;
    VGAKOMEI            NVARCHAR2(60);
    VSEINENGAPI         NVARCHAR2(11);
    VSEIBETSU           NVARCHAR2(2);
-- 2024/07/12 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--    VSETAI_NO           NVARCHAR2(7);
    VSETAI_NO           NVARCHAR2(15);
    VGYOSEIKU_MEI       NVARCHAR2(20);
    VHAN_MEI            NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00416対応
--    VSANTEIDANTAI_MEI   NVARCHAR2(20);
    VSANTEIDANTAI_MEI   GKBWJIDOZAIGAKU.SANTEIDANTAIMEI%TYPE;
    VHYOUJINENDO        NVARCHAR2(10);
    VSASKUSEIBI         NVARCHAR2(30);
    VHOGOSHA_SHIMEI_JODAN     NVARCHAR2(100);
    VHOGOSHA_SHIMEI_GEDAN     NVARCHAR2(100);
    VJUSHO_JODAN        NVARCHAR2(30);
    VJUSHO_GEDAN        NVARCHAR2(30);
    VCNT                NVARCHAR2(6);
    VZOKUGARAMEI1       NVARCHAR2(30);
    VZOKUGARAMEI2       NVARCHAR2(30);
    VGAKUNENMEI         NVARCHAR2(20);
    NGAKUNENSEI         NUMBER;
    VGAKUNENSEI         NVARCHAR2(20);
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN                BOOLEAN;
    B_RTN               BOOLEAN;
    I_RTN               PLS_INTEGER;
    IRTN                PLS_INTEGER;
    -- 処理条件（画面からの引数）
    VNENDO              NVARCHAR2(15);      -- 対象年度
    -- 処理条件の取得用変数
    TYPE MTJOKEN_TYPE IS TABLE OF NVARCHAR2(15) INDEX BY BINARY_INTEGER;  -- 処理条件の値の配列宣言
    o_MJYOUKEN      MTJOKEN_TYPE;
    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWJIDOZAIGAKU%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK MTJIDO_TYPE;
    -- 改頁条件の取得用変数
    o_NBREAK         NUMBER(2);
    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    BRTNSEINENGAPI                  BOOLEAN;
    IWAREKIHIZUKE                  PLS_INTEGER;
    VEDIT_GYYMMDD1                 NVARCHAR2(20);
    VEDIT_GYYMMDD2                 NVARCHAR2(20);
    VEDIT_GYYMMDD3                 NVARCHAR2(20);
    VKJ_GENGO                      NVARCHAR2(20);
    VKG_GENGO                      NVARCHAR2(20);
    IWAREKI_YY                     PLS_INTEGER;
    ISEIREKI_YYYY                  PLS_INTEGER;
    IWAREKI_GYYMM                  PLS_INTEGER;
    IMM                            PLS_INTEGER;
    IDD                            PLS_INTEGER;
    IOWAREKIHIZUKE                 PLS_INTEGER;
    ISEIREKIHIZUKE                 PLS_INTEGER;
    VSQLERRM         NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
    VPAGENM          NVARCHAR2(500);    -- 改頁項目名
    VPAGEFD          NVARCHAR2(500);    -- 改頁項目値

--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
    --VSYOGAKO_CD        NVARCHAR2(100);  --小学校コード
    --VTYUGAKO_CD        NVARCHAR2(100);  --中学校コード
    --VKUIKIGAI_CD       NVARCHAR2(100);  --区域外学校コード
    --VYOGOGAKO_CD       NVARCHAR2(100);  --盲聾養護学校コード
-- 2024/07/12 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
    --VKUNISHIRITSU_CD   NVARCHAR2(100);  --国私立学校コード
    VSYOGAKO_CD        NVARCHAR2(3000);  --小学校コード
    VTYUGAKO_CD        NVARCHAR2(3000);  --中学校コード
    VKUIKIGAI_CD       NVARCHAR2(3000);  --区域外学校コード
    VYOGOGAKO_CD       NVARCHAR2(3000);  --盲聾養護学校コード
    VKUNISHIRITSU_CD   NVARCHAR2(3000);  --国私立学校コード
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
    VKIJYUNBI          NVARCHAR2(100);  --基準日
    VNINIBIT           NVARCHAR2(500);  --任意ビット項目
    VFLAG              NUMBER(1);       --一覧出力フラグ（0:出力する、1:出力しない）

    -- 宛名ラベルの氏名出力制御用変数(KKAPK0030.FPRMSHUTOKU)
    ACONSPRM_CLASS              A_CONS_PRM;
    NLENGTH                     NUMBER;
    IRTN_CLASS                  PLS_INTEGER;
    IFUTSU_NINZU                PLS_INTEGER;
    ITOKU_NINZU                 PLS_INTEGER;
    KIJUN_BI                    NVARCHAR2(11);
    KIJUN_BI2                   NUMBER(8);
    TYPE MTHIZUKE_REC IS RECORD(
      GAKO_KBN     BINARY_INTEGER, --学校区分
      GAKO_CD      PLS_INTEGER,    --学校コード
      IN_D         PLS_INTEGER,    --入学年月日OR転入学年月日
      OUT_D        PLS_INTEGER     --転学年月日OR退学年月日OR卒業年月日
    );
    TYPE MHIZUKE_TYPE IS TABLE OF MTHIZUKE_REC INDEX BY BINARY_INTEGER;

    VMSG NVARCHAR2(4000);
    IJOKEN8 PLS_INTEGER;
    IKIJUN_NENDO  PLS_INTEGER;
    ISYS_NENDO    PLS_INTEGER;
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
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

--  2024/08/30 ZCZL.WANGMING ADD START 0.3.000.001:IT_GKB_00075対応
        --------------------------------------------------------
    --  機能概要      : 学校コード取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.qinyue 2024/08/29
    --------------------------------------------------------
    FUNCTION FUNC_GET_GAKOCD(i_sGAKOCD IN NVARCHAR2, o_sGAKOCD OUT NVARCHAR2) RETURN BOOLEAN
    IS
        aGAKOCD           KKBPK5551.tySPLIT_tbl;      -- 業務コード（リスト）
--  2024/11/14 ZCZL.WANGYUNING ADD 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        nGAKOUCD_TMP  NUMBER; --学校コード
    BEGIN
        -- 入力引数を分解して配列にセットする
        -- 引数の業務コード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        ---- 処理ステップを取得
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
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00659対応 START
--            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
            nGAKOUCD_TMP := TO_NUMBER(aGAKOCD(i));
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00659対応 END
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
--  2024/08/30 ZCZL.WANGMING ADD END

    --------------------------------------------------------
    --  機能概要      : バッチ初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        v_cmbIchiranOutputFlg                            DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        objShogakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
        objChugakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
        objKuikigaiCd  DBMS_UTILITY.MAXNAME_ARRAY;   
        objYogogakoCd  DBMS_UTILITY.MAXNAME_ARRAY;     
        objKunishiritsuCd  DBMS_UTILITY.MAXNAME_ARRAY;     
--  2024/11/14 ZCZL.WANGYUNING ADD END
    BEGIN
        g_vJYOUKEN1 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNendo'); --対象年度
        g_vJYOUKEN2 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKijunBi'); --基準日
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_vJYOUKEN3 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShogakkoCd'); --小学校コード
        --g_vJYOUKEN4 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtChugakkoCd'); --中学校コード
        --g_vJYOUKEN5 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKuikigaiGakkoCd'); --区域外学校コード
        --g_vJYOUKEN6 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtTokubetsuShienGakkoCd'); --特別支援学校コード
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtShogakkoCd');
        g_vJYOUKEN3 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShogakkoCd',0, objShogakkoCd);           --小学校コード
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtChugakkoCd');
        g_vJYOUKEN4 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtChugakkoCd',0, objChugakkoCd);           --中学校コード
        objKuikigaiCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKuikigaiGakkoCd');
        g_vJYOUKEN5 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuikigaiGakkoCd',0, objKuikigaiCd);      --区域外学校コード
        objYogogakoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtTokubetsuShienGakkoCd');
        g_vJYOUKEN6 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtTokubetsuShienGakkoCd',0, objYogogakoCd);--特別支援学校コード 
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
--  2024/08/30 ZCZL.WANGMING DELETE 0.3.000.001:IT_GKB_00075対応
--        g_vJYOUKEN7 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNiniBit'); --任意ビット
--  2024/08/30 ZCZL.WANGMING UPDATE START 0.3.000.001:IT_GKB_00075対応
--        g_vJYOUKEN8 := KKBPK5551.GETPARMS(g_nJOBNUM, 'cmbIchiranOutputFlg'); --一覧出力フラグ
        v_cmbIchiranOutputFlg := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbIchiranOutputFlg');
        g_vJYOUKEN8  := v_cmbIchiranOutputFlg(1);
--  2024/08/30 ZCZL.WANGMING UPDATE END
-- 2024/07/12 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_vJYOUKEN9 :=  KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKuniShiritsuGakkoCd'); --国私立学校コード
        objKunishiritsuCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKuniShiritsuGakkoCd');
        g_vJYOUKEN9 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuniShiritsuGakkoCd',0, objKunishiritsuCd);
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
-- 2024/07/12 ZCZL.qinyue Add end
--  2024/08/30 ZCZL.WANGMING ADD START 0.3.000.001:IT_GKB_00075対応
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN3, VSYOGAKO_CD);       --小学校コード
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN4, VTYUGAKO_CD);       --中学校コード
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN5, VKUIKIGAI_CD);      --区域外学校コード
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN6, VYOGOGAKO_CD);      --特別支援学校コード
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN9, VKUNISHIRITSU_CD);  --国私立学校コード
--  2024/08/30 ZCZL.WANGMING ADD END

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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
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
    --日付チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION DATE_FORMAT_CHECK(
      I_JOKEN   IN  NVARCHAR2,
      I_MODE    IN  NUMBER    --1:年、2:年月、3:年月日
    ) RETURN NUMBER
    IS
      EEXIT   EXCEPTION;
      NDATE   NUMBER;
      DDATE   DATE;
      NWAREKINEN  NUMBER;
      NRESULT   NUMBER;
    BEGIN

      IF ((I_JOKEN IS NULL) OR (I_JOKEN = '') OR (I_JOKEN < 0)) THEN
        RETURN(1);
      END IF;

      IF ((I_MODE = 1) AND (LENGTH(I_JOKEN) != 3)) THEN   --年
        RETURN(-1);
      ELSIF ((I_MODE = 2) AND (LENGTH(I_JOKEN) != 5)) THEN  --年月
        RETURN(-1);
      ELSIF ((I_MODE = 3) AND (LENGTH(I_JOKEN) != 7)) THEN  --年月日
        RETURN(-1);
      END IF;

      NWAREKINEN := TO_NUMBER(SUBSTR(I_JOKEN, 1, 3));
      NRESULT := KKAPK0020.FNENDO(NWAREKINEN, 1);     --和暦 → 西暦
      IF (NRESULT = 0) THEN
        RETURN(-1);
      END IF;

      --西暦(8桁)日付に変換
      IF (I_MODE = 1) THEN  --年
        NDATE := (NRESULT * 10000) + 0101;
      ELSIF (I_MODE = 2) THEN --年月
        NDATE := (NRESULT * 10000) + (TO_NUMBER(SUBSTR(I_JOKEN, 4, 2)) * 100) + 01;
      ELSIF (I_MODE = 3) THEN --年月日
        NDATE := (NRESULT * 10000) + TO_NUMBER(SUBSTR(I_JOKEN, 4, 4));
      END IF;
      DDATE := TO_DATE(NDATE, 'YYYYMMDD');

      RETURN(0);

    EXCEPTION
      WHEN OTHERS THEN
      RETURN(-1);

    END DATE_FORMAT_CHECK;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
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
        VMSG  := '';
        IRTN  := 0;
        --  2024/10/18 ZCZL.ZHANGLEI ADD START 0.3.000.005:IT_GKB_00079仕様変更対応
        bRTN := KKAPK0010.FISNUMERIC(g_vJYOUKEN1);
        IF bRTN THEN
        --  2024/10/18 ZCZL.ZHANGLEI ADD END
        --条件１のチェック
        IRTN := DATE_FORMAT_CHECK( g_vJYOUKEN1,1 );
        IF IRTN <> 0 THEN
          VMSG := g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
        END IF;
        --  2024/10/18 ZCZL.ZHANGLEI ADD START 0.3.000.005:IT_GKB_00079仕様変更対応
        ELSE
          VMSG := g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
        END IF;
        --  2024/10/18 ZCZL.ZHANGLEI ADD END
        --条件２のチェック
         --  2024/10/18 ZCZL.ZHANGLEI ADD START 0.3.000.005:IT_GKB_00079仕様変更対応
        bRTN := KKAPK0010.FISNUMERIC(g_vJYOUKEN2);
        IF bRTN THEN
        --  2024/10/18 ZCZL.ZHANGLEI ADD END
        IRTN := DATE_FORMAT_CHECK( g_vJYOUKEN2, 3 );
        IF IRTN <> 0 THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
        END IF;
         --  2024/10/18 ZCZL.ZHANGLEI ADD START 0.3.000.005:IT_GKB_00079仕様変更対応
        ELSE
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
        END IF;
        --  2024/10/18 ZCZL.ZHANGLEI ADD END
-- 2024/07/22 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        IF VMSG IS NULL THEN
          --基準日の年度がシステム日付の年度ではない場合エラー
          IKIJUN_NENDO := KKAPK0020.FDAYNENDO(0,g_vJYOUKEN2);
          IKIJUN_NENDO := KKAPK0020.FNENDO(IKIJUN_NENDO,1);
          ISYS_NENDO   := KKAPK0020.FDAYNENDO(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),0);
          IF IRTN = 0 AND IKIJUN_NENDO != ISYS_NENDO THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日には年度内を指定してください。,;';
          END IF;
-- 2024/07/22 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        END IF;

        --条件8のチェック
        IRTN  := 0;
        IF  g_vJYOUKEN8 IS  NULL THEN
            NULL;
        ELSE
            BEGIN
               IF LENGTH(g_vJYOUKEN8) > 1 THEN
                 IRTN := 1;
               ELSE
                IJOKEN8 := TO_NUMBER(g_vJYOUKEN8);
               END IF;
            EXCEPTION
              WHEN OTHERS THEN
                   IRTN  := 1;
            END;
            IF  IRTN  = 0  AND IJOKEN8 IN (0,1) THEN
               NULL;
            ELSE
                IRTN  := 1;
            END IF;
        END IF;

        IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,一覧出力フラグが正しくありません。,;';
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
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
    --------------------------------------------------------------------------------
    --ＣＳＶ転送用の文字変換
    --------------------------------------------------------------------------------
    FUNCTION EAPFNV2STR (i_VDATA IN NVARCHAR2 ) RETURN NVARCHAR2 IS
    VRET     NVARCHAR2(1024);
    BEGIN
        VRET := NVL(i_VDATA,'');
        RETURN(VRET);
    END EAPFNV2STR;
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
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
    -- 処理条件の値をセットする配列の初期化
    --------------------------------------------------------------------------------------------------
    PROCEDURE PROCHAICLR IS
        ICNT  PLS_INTEGER;  -- カウンタ（インデックス）
    BEGIN
        -- 処理条件
        -- ゼロから項目数分の領域を作成
        FOR ICNT IN 0..c_IJOKEN - 1 LOOP
            o_MJYOUKEN(ICNT) := ' ';
        END LOOP;
    END PROCHAICLR;

    --------------------------------------------------------------------------------
    -- 学年名称編集
    --------------------------------------------------------------------------------
    FUNCTION FUNC_EDIT_GAKUNENMEI( i_NGAKUNEN_CD IN PLS_INTEGER ) RETURN NVARCHAR2 IS
      VRTN      NVARCHAR2(20);
    BEGIN
      VRTN := NULL;
      IF i_NGAKUNEN_CD IN (1,2,3,4,5,6) THEN
        VRTN := TO_CHAR( i_NGAKUNEN_CD ) || '年生';
      ELSIF i_NGAKUNEN_CD IN (7,8,9) THEN
        VRTN := TO_CHAR( i_NGAKUNEN_CD - 6  ) || '年生';
      ELSE
        VRTN := NULL;
      END IF;
      RETURN VRTN;
    EXCEPTION
      WHEN OTHERS THEN
        VRTN := NULL;
        RETURN VRTN;
    END FUNC_EDIT_GAKUNENMEI;

    --------------------------------------------------------
    --  機能概要      : 対象学校が入力した学校条件に含まれるかチェック
    --  パラメータ    : GAKO_CD   : 対象学校コード
    --              GAKO_JOKEN: 入力した学校コード
    --  モジュール区分: 内部関数
    --  戻り値        : 1:含まれる 0:含まれない
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/03
    --------------------------------------------------------
    FUNCTION FUNC_CHECK_GAKO(GAKO_CD IN PLS_INTEGER,GAKO_JOKEN IN NVARCHAR2) RETURN PLS_INTEGER IS
    P_SQL      VARCHAR2(2000);
    I_COUNT    PLS_INTEGER;
    TYPE TYPECURSOR  IS REF CURSOR;
    CRGAKO     TYPECURSOR;
    BEGIN
      I_COUNT := 0;
      IF GAKO_JOKEN IS NOT NULL THEN
          P_SQL := 'SELECT COUNT(1) FROM DUAL ';
          P_SQL := P_SQL || 'WHERE ' || GAKO_CD || ' IN (' || GAKO_JOKEN || ')';
          EXECUTE IMMEDIATE  P_SQL;
          OPEN CRGAKO  FOR P_SQL;
          LOOP
            FETCH  CRGAKO INTO I_COUNT;
            EXIT WHEN CRGAKO%NOTFOUND;
          END LOOP;
      END IF;
      RETURN I_COUNT;
    END FUNC_CHECK_GAKO;

    ---------------------------------------------------------------------------------
    -- 期間チェック
    -- TYPE : 0:減の日付チェック
    --        1:増の日付チェック
    ---------------------------------------------------------------------------------
    FUNCTION FUNC_CHECK_KIKAN(DATE1 IN NVARCHAR2, DATE2 IN NVARCHAR2,DATE3 IN NVARCHAR2 ,KIJUNDATE IN NVARCHAR2,TYPE IN INTEGER ) RETURN BOOLEAN IS
      B_FLG   BOOLEAN;
    BEGIN
      IF TYPE = 0 THEN
        --減日が基準日より大きい場合：在籍(TRUE)
        IF DATE1 > KIJUNDATE OR DATE2 > KIJUNDATE OR DATE3 > KIJUNDATE THEN
          B_FLG := TRUE;
        --減日が0の場合：在籍(TRUE)
        ELSIF DATE1 = 0 AND DATE2 = 0 AND DATE3 = 0 THEN
          B_FLG := TRUE;
        END IF;
      ELSE
        --増日が基準日より前の場合：在籍(TRUE)
        IF DATE1 <= KIJUNDATE AND DATE2 <= KIJUNDATE AND DATE3 <= KIJUNDATE THEN
          B_FLG := TRUE;
        END IF;
      END IF;

      RETURN B_FLG;
    END FUNC_CHECK_KIKAN;
    ---------------------------------------------------------------------------------
    -- 基準日対象チェック
    ---------------------------------------------------------------------------------
    PROCEDURE PROC_CHECK_KIJUN(RG         IN GKBTGAKUREIBO%ROWTYPE,
                               i_KIJYUNBI IN NUMBER,
                               MHIZUKE    IN OUT MHIZUKE_TYPE)
    IS
    BEGIN
        --変数初期化
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 START
--        FOR IDX IN 1..4 LOOP
        FOR IDX IN 1..5 LOOP
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 END
          MHIZUKE(IDX).GAKO_KBN   := 0;
          MHIZUKE(IDX).GAKO_CD    := 0;
          MHIZUKE(IDX).IN_D       := 0;
          MHIZUKE(IDX).OUT_D      := 0;
        END LOOP;
        --区域外
        IF RG.KUIKIGAI_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.KUIKIGAI_NYUGAKU_BI    > 0 THEN MHIZUKE(1).IN_D := RG.KUIKIGAI_NYUGAKU_BI;   END IF;
          IF RG.KUIKIGAI_TENNYUGAKU_BI > 0 THEN MHIZUKE(1).IN_D := RG.KUIKIGAI_TENNYUGAKU_BI;END IF;
          ----転学年月日OR退学年月日OR卒業年月日
          IF RG.KUIKIGAI_TENGAKU_BI    > 0 THEN MHIZUKE(1).OUT_D := RG.KUIKIGAI_TENGAKU_BI;  END IF;
          IF RG.KUIKIGAI_TAIGAKU_BI    > 0 THEN MHIZUKE(1).OUT_D := RG.KUIKIGAI_TAIGAKU_BI;  END IF;
          IF RG.KUIKIGAI_SOTSUGYO_BI   > 0 THEN MHIZUKE(1).OUT_D := RG.KUIKIGAI_SOTSUGYO_BI; END IF;
          --基準日時点の判定
          IF  MHIZUKE(1).IN_D = 0 AND MHIZUKE(1).OUT_D = 0 THEN
            MHIZUKE(1).GAKO_KBN := 0;
          ELSIF  MHIZUKE(1).IN_D <= i_KIJYUNBI AND (i_KIJYUNBI <= MHIZUKE(1).OUT_D OR MHIZUKE(1).OUT_D = 0) THEN
            MHIZUKE(1).GAKO_KBN := 1;
            MHIZUKE(1).GAKO_CD  := RG.KUIKIGAI_CD;
          END IF;
        END IF;
        --特別支援学校
        IF RG.YOGOGAKO_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.YOGOGAKO_NYUGAKU_BI    > 0 THEN MHIZUKE(2).IN_D := RG.YOGOGAKO_NYUGAKU_BI;   END IF;
          IF RG.YOGOGAKO_TENNYUGAKU_BI > 0 THEN MHIZUKE(2).IN_D := RG.YOGOGAKO_TENNYUGAKU_BI;END IF;
          ----転学年月日OR退学年月日OR卒業年月日
          IF RG.YOGOGAKO_TENGAKU_BI    > 0 THEN MHIZUKE(2).OUT_D := RG.YOGOGAKO_TENGAKU_BI;  END IF;
          IF RG.YOGOGAKO_TAIGAKU_BI    > 0 THEN MHIZUKE(2).OUT_D := RG.YOGOGAKO_TAIGAKU_BI;  END IF;
          IF RG.YOGOGAKO_SOTSUGYO_BI   > 0 THEN MHIZUKE(2).OUT_D := RG.YOGOGAKO_SOTSUGYO_BI; END IF;
          --基準日時点の判定
          IF  MHIZUKE(2).IN_D = 0 AND MHIZUKE(2).OUT_D = 0 THEN
            MHIZUKE(2).GAKO_KBN := 0;
          ELSIF MHIZUKE(2).IN_D <= i_KIJYUNBI AND (i_KIJYUNBI <= MHIZUKE(2).OUT_D OR MHIZUKE(2).OUT_D = 0) THEN
            MHIZUKE(2).GAKO_KBN := 1;
            MHIZUKE(2).GAKO_CD  := RG.YOGOGAKO_CD;
          END IF;
        END IF;
        --小学校
        IF  RG.SYOGAKO_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.SYOGAKO_NYUGAKU_BI    > 0 THEN MHIZUKE(3).IN_D := RG.SYOGAKO_NYUGAKU_BI;     END IF;
          IF RG.SYOGAKO_TENNYUGAKU_BI > 0 THEN MHIZUKE(3).IN_D := RG.SYOGAKO_TENNYUGAKU_BI;  END IF;
          ----転学年月日OR卒業年月日
          IF RG.SYOGAKO_TENGAKU_BI    > 0 THEN MHIZUKE(3).OUT_D := RG.SYOGAKO_TENGAKU_BI;    END IF;
          IF RG.SYOGAKO_SOTSUGYO_BI   > 0 THEN MHIZUKE(3).OUT_D := RG.SYOGAKO_SOTSUGYO_BI;   END IF;
          --基準日時点の判定
          IF  MHIZUKE(3).IN_D = 0 AND MHIZUKE(3).OUT_D = 0 THEN
            MHIZUKE(3).GAKO_KBN := 0;
          ELSIF MHIZUKE(3).IN_D <= i_KIJYUNBI AND (i_KIJYUNBI <= MHIZUKE(3).OUT_D OR MHIZUKE(3).OUT_D = 0) THEN
            MHIZUKE(3).GAKO_KBN := 1;
            MHIZUKE(3).GAKO_CD  := RG.SYOGAKO_CD;
          END IF;
        END IF;
        --中学校
        IF  RG.TYUGAKO_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.TYUGAKO_NYUGAKU_BI    > 0 THEN MHIZUKE(4).IN_D := RG.TYUGAKO_NYUGAKU_BI;     END IF;
          IF RG.TYUGAKO_TENNYUGAKU_BI > 0 THEN MHIZUKE(4).IN_D := RG.TYUGAKO_TENNYUGAKU_BI;  END IF;
          --転学年月日OR卒業年月日
          IF RG.TYUGAKO_TENGAKU_BI    > 0 THEN MHIZUKE(4).OUT_D := RG.TYUGAKO_TENGAKU_BI;    END IF;
          IF RG.TYUGAKO_SOTSUGYO_BI   > 0 THEN MHIZUKE(4).OUT_D := RG.TYUGAKO_SOTSUGYO_BI;   END IF;
          --基準日時点の判定
          IF  MHIZUKE(4).IN_D = 0 AND MHIZUKE(4).OUT_D = 0 THEN
            MHIZUKE(4).GAKO_KBN := 0;
          ELSIF MHIZUKE(4).IN_D <= i_KIJYUNBI AND (i_KIJYUNBI <= MHIZUKE(4).OUT_D OR MHIZUKE(4).OUT_D = 0) THEN
            MHIZUKE(4).GAKO_KBN := 1;
            MHIZUKE(4).GAKO_CD  := RG.TYUGAKO_CD;
          END IF;
        END IF;
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 START
        --国私立学校
        IF  RG.KUNISHIRITSU_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.KUNISHIRITSU_NYUGAKU_BI    > 0 THEN MHIZUKE(5).IN_D := RG.KUNISHIRITSU_NYUGAKU_BI;     END IF;
          IF RG.KUNISHIRITSU_TENNYUGAKU_BI > 0 THEN MHIZUKE(5).IN_D := RG.KUNISHIRITSU_TENNYUGAKU_BI;  END IF;
          --転学年月日OR卒業年月日
          IF RG.KUNISHIRITSU_TENGAKU_BI    > 0 THEN MHIZUKE(5).OUT_D := RG.KUNISHIRITSU_TENGAKU_BI;    END IF;
          IF RG.KUNISHIRITSU_SOTSUGYO_BI   > 0 THEN MHIZUKE(5).OUT_D := RG.KUNISHIRITSU_SOTSUGYO_BI;   END IF;
          --基準日時点の判定
          IF  MHIZUKE(5).IN_D = 0 AND MHIZUKE(5).OUT_D = 0 THEN
            MHIZUKE(5).GAKO_KBN := 0;
          ELSIF MHIZUKE(5).IN_D <= i_KIJYUNBI AND (i_KIJYUNBI <= MHIZUKE(5).OUT_D OR MHIZUKE(5).OUT_D = 0) THEN
            MHIZUKE(5).GAKO_KBN := 1;
            MHIZUKE(5).GAKO_CD  := RG.KUNISHIRITSU_CD;
          END IF;
        END IF;
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 END
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END PROC_CHECK_KIJUN;
-- 2024/07/19 ZCZL.qinyue Delete start 0.3.000.000:新WizLIFE2次開発
    --------------------------------------------------------------------------------
    -- 任意ビットが指定した条件に該当するかチェック
    --------------------------------------------------------------------------------
--     FUNCTION FUNC_CHK_NINIBIT(RATENA_WORK IN CRATENA_TYPE,i_NINIBIT IN NUMBER,i_ATAI IN NUMBER)
--     RETURN BOOLEAN IS
--       o_BRTN    BOOLEAN;
--     BEGIN
--         o_BRTN := FALSE;
--         CASE i_NINIBIT
--           WHEN 1  THEN IF RATENA_WORK.NINIBIT1  = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 2  THEN IF RATENA_WORK.NINIBIT2  = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 3  THEN IF RATENA_WORK.NINIBIT3  = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 4  THEN IF RATENA_WORK.NINIBIT4  = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 5  THEN IF RATENA_WORK.NINIBIT5  = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 6  THEN IF RATENA_WORK.NINIBIT6  = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 7  THEN IF RATENA_WORK.NINIBIT7  = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 8  THEN IF RATENA_WORK.NINIBIT8  = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 9  THEN IF RATENA_WORK.NINIBIT9  = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 10 THEN IF RATENA_WORK.NINIBIT10 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 11 THEN IF RATENA_WORK.NINIBIT11 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 12 THEN IF RATENA_WORK.NINIBIT12 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 13 THEN IF RATENA_WORK.NINIBIT13 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 14 THEN IF RATENA_WORK.NINIBIT14 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 15 THEN IF RATENA_WORK.NINIBIT15 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 16 THEN IF RATENA_WORK.NINIBIT16 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 17 THEN IF RATENA_WORK.NINIBIT17 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 18 THEN IF RATENA_WORK.NINIBIT18 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 19 THEN IF RATENA_WORK.NINIBIT19 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 20 THEN IF RATENA_WORK.NINIBIT20 = i_ATAI THEN o_BRTN := TRUE; END IF;
--         END CASE;
--         RETURN o_BRTN;
--     END FUNC_CHK_NINIBIT;
-- 2024/07/19 ZCZL.qinyue Delete end
    ---------------------------------------------------------------------------------
    -- 児童生徒中間（GKBWJIDOZAIGAKU）レコードの作成
    ---------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        FRET                PLS_INTEGER;          -- 戻り値
        NNENDO              PLS_INTEGER;          -- 年度
        IRTNA               PLS_INTEGER;
        IRTNSANTEIDANTAI    PLS_INTEGER;
        IRTNAH              PLS_INTEGER;
        ICNT                BINARY_INTEGER;       -- 戻り値
        BRTNSASKUSEIBI      BOOLEAN;
        IJUSHO_NAGASA       PLS_INTEGER;
        ISHIMEINAGASA       PLS_INTEGER;
        IRTNZOKUGARA1       PLS_INTEGER;
        IRTNZOKUGARAHERR1   PLS_INTEGER;
        IRTNZOKUGARA2       PLS_INTEGER;
        IRTNZOKUGARAHERR2   PLS_INTEGER;
        NPRTN               NUMBER;
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00081対応
--         VSQLSEL             VARCHAR2(5000);
        VSQLSEL             VARCHAR2(32000);
        NNINIBIT_KISU       NUMBER(2);            --任意ビット項目の数量
        NNINIBIT_SYUBETU    NUMBER(2);            --任意ﾋﾞｯﾄ種別(Xより値が変わる)
        NNINIBIT_ATAI       NUMBER(2);            --任意ﾋﾞｯﾄ値(Xより値が変わる)
        X                   NUMBER(2);            --[NINIBITX]のX
        NTIMES              NUMBER(2);            --任意ビットの文字列を分割するためのLOOP回数
        BOUT_FLG            BOOLEAN;              --出力ﾌﾗｸﾞ
        VGAKO_JOKEN         BOOLEAN;              --学校条件
-- 2024/07/19 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--        KOJINNO1            NUMBER(12);           --個人番号
--        KOJINNO2            NUMBER(12);           --個人番号
--        KOJINNO3            NUMBER(12):=0;        --個人番号 個人番号の最新と履歴を区別するため
        KOJINNO1            NUMBER(15);           --個人番号
        KOJINNO2            NUMBER(15);           --個人番号
        KOJINNO3            NUMBER(15):=0;        --個人番号 個人番号の最新と履歴を区別するため
-- 2024/07/19 ZCZL.qinyue Update end
        MHIZUKE             MHIZUKE_TYPE;         --読込レコード用
        MHIZUKE_SAV         MHIZUKE_TYPE;         --保持用
        IGAKO_KBN           BINARY_INTEGER;       --該当する学校区分
        BOUT_FLG2           BOOLEAN;              --出力ﾌﾗｸﾞ
        BOUT_FLG3           BOOLEAN;              --出力ﾌﾗｸﾞ
        o_RATENA_REC        GABTATENAKIHON%ROWTYPE;
        o_RSOFU_REC         GABTSOFUSAKI%ROWTYPE;
        TYPE TYPECURSOR  IS REF CURSOR;
        CRATENA             TYPECURSOR;
-- 2024/07/22 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        DKIJYUNBI           NVARCHAR2(100);  --編集後基準日
-- 2024/07/22 ZCZL.qinyue Add end
--  2024/09/29 ZCZL.yangshua Add 0.3.000.003:仕様変更 IT_GKB_00081対応
        bRTN                BOOLEAN;
--  2025/06/11 CTC.HJF UPDATE Start 1.0.008.000:GKB_QA15686対応
        VSQLSEL_RIREKI VARCHAR2(32000);
        CRATENA_OLDRIREKI TYPECURSOR;
        CRATENA_OLDRIREKIWORK GKBTGAKUREIBO%ROWTYPE;
--  2025/06/11 CTC.HJF UPDATE End
    BEGIN
        FRET := c_INOTFOUND;                 -- 該当なし
        ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        ICNT := 0;
--  2024/09/29 ZCZL.yangshua Add 0.3.000.003:仕様変更 IT_GKB_00081対応
        bRTN := FALSE;
        --学校条件指定・未指定
        IF VSYOGAKO_CD IS NULL AND VTYUGAKO_CD IS NULL AND VKUIKIGAI_CD IS NULL AND VYOGOGAKO_CD IS NULL AND VKUNISHIRITSU_CD IS NULL THEN
          VGAKO_JOKEN := FALSE;
        ELSE
          VGAKO_JOKEN := TRUE;
        END IF;
        
        --編集後基準日  
        DKIJYUNBI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(VKIJYUNBI));

        BEGIN

          VSQLSEL := '';
-- 2024/07/12 ZCZL.qinyue Delete start 0.3.000.000:新WizLIFE2次開発
--           VSQLSEL := VSQLSEL || 'SELECT ';
--           VSQLSEL := VSQLSEL || 'B.KOJIN_NO, ';
--           VSQLSEL := VSQLSEL || 'B.RIREKI_RENBAN, ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT1,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT2,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT3,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT4,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT5,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT6,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT7,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT8,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT9,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT10,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT11,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT12,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT13,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT14,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT15,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT16,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT17,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT18,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT19,0), ';
--           VSQLSEL := VSQLSEL || 'NVL(C.NINIBIT20,0), ';
--           VSQLSEL := VSQLSEL || 'B.GAKUNEN, ';
--           VSQLSEL := VSQLSEL || '0 ';
--           VSQLSEL := VSQLSEL || 'FROM GKBTGAKUREIBO B, ';
--           VSQLSEL := VSQLSEL || 'GKBTNINIBIT C, ';
--           VSQLSEL := VSQLSEL || 'GKBTGAKUNENLNK D ';
--           VSQLSEL := VSQLSEL || ' WHERE    B.KOJIN_NO=C.KOJIN_NO';
--           VSQLSEL := VSQLSEL || ' AND      B.RIREKI_RENBAN=C.RIREKI_RENBAN';
--           VSQLSEL := VSQLSEL || ' AND    B.KOJIN_NO=D.KOJIN_NO';
--           VSQLSEL := VSQLSEL || ' AND    D.GAKUNEN_CD NOT IN (0,99)';
--           VSQLSEL := VSQLSEL ||' ORDER BY B.KOJIN_NO,B.RIREKI_RENBAN DESC ';
-- 2024/07/12 ZCZL.qinyue Delete end
-- 2024/07/12 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
          VSQLSEL := VSQLSEL || 'SELECT ';
          VSQLSEL := VSQLSEL || 'SK.KOJIN_NO, ';
          VSQLSEL := VSQLSEL || 'SK.RIREKI_RENBAN, ';
          VSQLSEL := VSQLSEL || 'SK.RIREKI_RENBAN_EDA, ';
          VSQLSEL := VSQLSEL || 'SK.SYOGAKO_CD, ';
          VSQLSEL := VSQLSEL || 'SK.TYUGAKO_CD, ';
          VSQLSEL := VSQLSEL || 'SK.KUIKIGAI_CD, ';
          VSQLSEL := VSQLSEL || 'SK.YOGOGAKO_CD, ';
          VSQLSEL := VSQLSEL || 'SK.KUNISHIRITSU_CD, ';
          VSQLSEL := VSQLSEL || 'SK.SEIBETSU, ';
          VSQLSEL := VSQLSEL || 'SK.GAKKO_KBN_CD, ';
          VSQLSEL := VSQLSEL || 'SK.GAKUNEN, ';
          VSQLSEL := VSQLSEL || 'SK.SHOGAKKOKU_CD, ';
          VSQLSEL := VSQLSEL || 'SK.CHUGAKKOKU_CD, ';
          VSQLSEL := VSQLSEL || 'SK.OAZA_CD, ';
          VSQLSEL := VSQLSEL || 'SK.SANTEIDANTAI_CD, ';
          VSQLSEL := VSQLSEL || 'SK.GYOSEIKU_CD, ';
          VSQLSEL := VSQLSEL || 'SK.GAKUKYU_KBN AS GAKUKYU_KBN ';
          VSQLSEL := VSQLSEL || 'FROM ( ';
--  2025/11/06 CTC.HJF UPDATE END
          VSQLSEL := VSQLSEL || 'SELECT ';
          VSQLSEL := VSQLSEL || 'B.KOJIN_NO, ';
          VSQLSEL := VSQLSEL || 'B.RIREKI_RENBAN, ';          
          VSQLSEL := VSQLSEL || 'B.RIREKI_RENBAN_EDA, ';
          VSQLSEL := VSQLSEL || 'B.SYOGAKO_CD, ';
          VSQLSEL := VSQLSEL || 'B.TYUGAKO_CD, ';
          VSQLSEL := VSQLSEL || 'B.KUIKIGAI_CD, ';
          VSQLSEL := VSQLSEL || 'B.YOGOGAKO_CD, ';
          VSQLSEL := VSQLSEL || 'B.KUNISHIRITSU_CD, ';
          VSQLSEL := VSQLSEL || 'B.SEIBETSU, ';
          VSQLSEL := VSQLSEL || 'B.GAKKO_KBN_CD, ';
          VSQLSEL := VSQLSEL || 'B.GAKUNEN, ';
          VSQLSEL := VSQLSEL || 'B.SHOGAKKOKU_CD, ';
          VSQLSEL := VSQLSEL || 'B.CHUGAKKOKU_CD, ';
          VSQLSEL := VSQLSEL || 'A.OAZA_CD, ';
          VSQLSEL := VSQLSEL || 'A.SANTEIDANTAI_CD, ';
          VSQLSEL := VSQLSEL || 'A.GYOSEIKU_CD, ';
-- 2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
          --VSQLSEL := VSQLSEL || 'C.GAKUKYU_KBN ';
-- 2025/05/16 CTC.HJF Delete End
-- 2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応
          VSQLSEL := VSQLSEL || 'NVL(C.GAKUKYU_KBN, 0) AS GAKUKYU_KBN ';
-- 2025/05/16 CTC.HJF UPDATE End
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
          VSQLSEL := VSQLSEL || ' , ROW_NUMBER() OVER ( ';
          VSQLSEL := VSQLSEL || '     PARTITION BY B.KOJIN_NO ';
          VSQLSEL := VSQLSEL || '     ORDER BY B.RIREKI_RENBAN DESC, B.RIREKI_RENBAN_EDA DESC ';
          VSQLSEL := VSQLSEL || ' ) AS RN ';
--  2025/11/06 CTC.HJF UPDATE END
          VSQLSEL := VSQLSEL || 'FROM GKBTGAKUREIBO B, ';
--  2024/09/29 ZCZL.yangshuai Update start 0.3.000.003:仕様変更 IT_GKB_00081対応
--           VSQLSEL := VSQLSEL || 'GABVATENAALL A, ';
--  2024/10/12 ZCZL.WANGMING Update START 0.3.000.004:仕様変更 IT_GKB_00081二次対応
--          VSQLSEL := VSQLSEL || ' ( SELECT                    ';
--          VSQLSEL := VSQLSEL || '     KOJIN_NO                ';
--          VSQLSEL := VSQLSEL || '     , RIREKI_RENBAN         ';
--          VSQLSEL := VSQLSEL || '     , TEKIYO_BI             ';
--          VSQLSEL := VSQLSEL || '     , TOROKU_GYOMU          ';
--          VSQLSEL := VSQLSEL || '     , SETAI_NO              ';
--          VSQLSEL := VSQLSEL || '     , GENZON_KBN            ';
--          VSQLSEL := VSQLSEL || '     , JUN_SETAI_KBN         ';
--          VSQLSEL := VSQLSEL || '     , JINKAKU_KBN           ';
--          VSQLSEL := VSQLSEL || '     , KOKUSEKI_CD           ';
--          VSQLSEL := VSQLSEL || '     , SHISHO_CD             ';
--          VSQLSEL := VSQLSEL || '     , CHIKU_CD              ';
--          VSQLSEL := VSQLSEL || '     , GYOSEIKU_CD           ';
--          VSQLSEL := VSQLSEL || '     , HAN_CD                ';
--          VSQLSEL := VSQLSEL || '     , SHOGAKU_CD            ';
--          VSQLSEL := VSQLSEL || '     , CHUGAKU_CD            ';
--          VSQLSEL := VSQLSEL || '     , TOHYOKU_CD            ';
--          VSQLSEL := VSQLSEL || '     , SANTEIDANTAI_CD       ';
--          VSQLSEL := VSQLSEL || '     , SEINENGAPI            ';
--          VSQLSEL := VSQLSEL || '     , WAREKI_SEINENGAPI     ';
--          VSQLSEL := VSQLSEL || '     , HYOJI_SEINENGAPI      ';
--          VSQLSEL := VSQLSEL || '     , SEIBETSU              ';
--          VSQLSEL := VSQLSEL || '     , USER_CD               ';
--          VSQLSEL := VSQLSEL || '     , OAZA_CD               ';
--          VSQLSEL := VSQLSEL || '     , HONBAN                ';
--          VSQLSEL := VSQLSEL || '     , EDABAN1               ';
--          VSQLSEL := VSQLSEL || '     , EDABAN2               ';
--          VSQLSEL := VSQLSEL || '     , EDABAN3               ';
--          VSQLSEL := VSQLSEL || '     , KATAGAKI_CD           ';
--          VSQLSEL := VSQLSEL || '     , GAIKU                 ';
--          VSQLSEL := VSQLSEL || '     , TOU                   ';
--          VSQLSEL := VSQLSEL || '     , GOU                   ';
--          VSQLSEL := VSQLSEL || '     , JICHI_CD              ';
--          VSQLSEL := VSQLSEL || '     , SHIMEI_KANA           ';
--          VSQLSEL := VSQLSEL || '     , SHIMEI_KANJI          ';
--          VSQLSEL := VSQLSEL || '     , YUBIN_NO              ';
--          VSQLSEL := VSQLSEL || '     , YUBIN_NOBC            ';
--          VSQLSEL := VSQLSEL || '     , CHOMEI                ';
--          VSQLSEL := VSQLSEL || '     , BANCHI                ';
--          VSQLSEL := VSQLSEL || '     , KATAGAKI              ';
--          VSQLSEL := VSQLSEL || '     , DAIHYO_KATAGAKI       ';
--          VSQLSEL := VSQLSEL || '     , DAIHYO_SHIMEI         ';
--          VSQLSEL := VSQLSEL || '     , TEL_NO                ';
--          VSQLSEL := VSQLSEL || '     , TEL_KBN               ';
--          VSQLSEL := VSQLSEL || '     , FAX_NO                ';
--          VSQLSEL := VSQLSEL || '     , MAIL_ADS              ';
--          VSQLSEL := VSQLSEL || '     , YUHEN_KBN             ';
--          VSQLSEL := VSQLSEL || '     , TOROKU_JIYU           ';
--          VSQLSEL := VSQLSEL || '     , JUMINHYO_CD           ';
--          VSQLSEL := VSQLSEL || '     , ZOKUGARA_CD1          ';
--          VSQLSEL := VSQLSEL || '     , ZOKUGARA_CD2          ';
--          VSQLSEL := VSQLSEL || '     , ZOKUGARA_CD3          ';
--          VSQLSEL := VSQLSEL || '     , ZOKUGARA_CD4          ';
--          VSQLSEL := VSQLSEL || '     , ZOKUGARA_KBN          ';
--          VSQLSEL := VSQLSEL || '     , ZOKUGARA_MEI          ';
--          VSQLSEL := VSQLSEL || '     , JITSU_ZOKUGARA_MEI    ';
--          VSQLSEL := VSQLSEL || '     , KISAI_JUNI            ';
--          VSQLSEL := VSQLSEL || '     , IDO_BI                ';
--          VSQLSEL := VSQLSEL || '     , IDO_JIYU              ';
--          VSQLSEL := VSQLSEL || '     , IDO_TODOKE_BI         ';
--          VSQLSEL := VSQLSEL || '     , IDO_TODOKE_KBN        ';
--          VSQLSEL := VSQLSEL || '     , JUTEI_BI              ';
--          VSQLSEL := VSQLSEL || '     , JUTEI_JIYU            ';
--          VSQLSEL := VSQLSEL || '     , JUTEI_TODOKEDE_BI     ';
--          VSQLSEL := VSQLSEL || '     , JUTEI_TODOKEDE_KBN    ';
--          VSQLSEL := VSQLSEL || '     , GENJUSHO_REN          ';
--          VSQLSEL := VSQLSEL || '     , ZENJUSHO_REN          ';
--          VSQLSEL := VSQLSEL || '     , TENNYUMAE_REN         ';
--          VSQLSEL := VSQLSEL || '     , TENNYU_MITODOKE_REN   ';
--          VSQLSEL := VSQLSEL || '     , HONSEKI_REN           ';
--          VSQLSEL := VSQLSEL || '     , TENSHUTSU_YOTEI_BI    ';
--          VSQLSEL := VSQLSEL || '     , TENSHUTSU_YOTEI_TODOKEDE_BI    ';
--          VSQLSEL := VSQLSEL || '     , TENSHUTSU_YOTEI_TODOKEDE_KBN   ';
--          VSQLSEL := VSQLSEL || '     , TENSHUTSU_YOTEI_REN            ';
--          VSQLSEL := VSQLSEL || '     , TENSHUTSU_KAKUTEI_BI           ';
--          VSQLSEL := VSQLSEL || '     , TENSHUTSU_KAKUTEI_TSUCHI_BI    ';
--          VSQLSEL := VSQLSEL || '     , TENSHUTSU_KAKUTEI_TODOKEDE_KBN ';
--          VSQLSEL := VSQLSEL || '     , TENSHUTSU_KAKUTEI_REN          ';
--          VSQLSEL := VSQLSEL || '     , JUMIN_NARU                     ';
--          VSQLSEL := VSQLSEL || '     , JUMIN_NARU_JIYU                ';
--          VSQLSEL := VSQLSEL || '     , JUMIN_NARU_TODOKEDE_BI         ';
--          VSQLSEL := VSQLSEL || '     , JUMIN_NARU_TODOKEDE_KBN        ';
--          VSQLSEL := VSQLSEL || '     , JUMIN_NAKUNARU                 ';
--          VSQLSEL := VSQLSEL || '     , JUMIN_NAKUNARU_JIYU            ';
--          VSQLSEL := VSQLSEL || '     , JUMIN_NAKUNARU_TODOKEDE_BI     ';
--          VSQLSEL := VSQLSEL || '     , JUMIN_NAKUNARU_TODOKEDE_KBN    ';
--          VSQLSEL := VSQLSEL || '     , SHIBOBI_FUSHO_KBN              ';
--          VSQLSEL := VSQLSEL || '     , HONMYO_KANA                    ';
--          VSQLSEL := VSQLSEL || '     , HONMYO_KANJI                   ';
--          VSQLSEL := VSQLSEL || '     , NUSHI_SHIMEI_KANA              ';
--          VSQLSEL := VSQLSEL || '     , NUSHI_SHIMEI_KANJI             ';
--          VSQLSEL := VSQLSEL || '     , BIKO                           ';
--          VSQLSEL := VSQLSEL || '     , KAISEI_BI                      ';
--          VSQLSEL := VSQLSEL || '     , KAISEI_REN                     ';
--          VSQLSEL := VSQLSEL || '     , KYU_SHIMEI_KANA                ';
--          VSQLSEL := VSQLSEL || '     , KYU_SHIMEI_KANJI               ';
--          VSQLSEL := VSQLSEL || '     , SHORIBI_KEY                    ';
--          VSQLSEL := VSQLSEL || '     , SHORI_JIKAN_KEY                ';
--          VSQLSEL := VSQLSEL || '     , SHORI_KBN_KEY                  ';
--          VSQLSEL := VSQLSEL || '     , ZENBU_ICHIBU_KEY               ';
--          VSQLSEL := VSQLSEL || '     , SHOKUINKOJIN_NO_KEY            ';
--          VSQLSEL := VSQLSEL || '     , SYS_SAKUSEIBI                  ';
--          VSQLSEL := VSQLSEL || '     , SYS_KOSHINBI                   ';
--          VSQLSEL := VSQLSEL || '     , SYS_JIKAN                      ';
--          VSQLSEL := VSQLSEL || '     , SYS_SHOKUINKOJIN_NO            ';
--          VSQLSEL := VSQLSEL || '     , SYS_TANMATSU_NO                ';
--          VSQLSEL := VSQLSEL || '     , GOMI_CD                        ';
--          VSQLSEL := VSQLSEL || '     , SINYO_CD                       ';
--          VSQLSEL := VSQLSEL || '     , KOIKIKOFU_STOP_CD              ';
--          VSQLSEL := VSQLSEL || '     , CHOMEI_KANA                    ';
--          VSQLSEL := VSQLSEL || '     , BANCHI_KANA                    ';
--          VSQLSEL := VSQLSEL || '     , KATAGAKI_KANA                  ';
--          VSQLSEL := VSQLSEL || '     , KATAGAKI_HIDE_FLG              ';
--          VSQLSEL := VSQLSEL || '     , GAIJI_FLG                      ';
--          VSQLSEL := VSQLSEL || '     , HOJINSOSHIKI_CD                ';
--          VSQLSEL := VSQLSEL || '     , JE_KOKUHOSHISANWARI_KBN        ';
--          VSQLSEL := VSQLSEL || '     , JE_JINTEKIGENMEN_KBN           ';
--          VSQLSEL := VSQLSEL || '     , JE_SHOYUSHAKEISHONIN_KBN       ';
--          VSQLSEL := VSQLSEL || '     , JE_LINK_KOJIN_NO               ';
--          VSQLSEL := VSQLSEL || '     , JE_NAYOSE_NO                   ';
--          VSQLSEL := VSQLSEL || '     , YOBI1_CD                       ';
--          VSQLSEL := VSQLSEL || '     , YOBI2_CD                       ';
--          VSQLSEL := VSQLSEL || '     , YOBI3_CD                       ';
--          VSQLSEL := VSQLSEL || '     , YOBI4_CD                       ';
--          VSQLSEL := VSQLSEL || '     , YOBI5_CD                       ';
--          VSQLSEL := VSQLSEL || '     , YOBI1_CH                       ';
--          VSQLSEL := VSQLSEL || '     , YOBI2_CH                       ';
--          VSQLSEL := VSQLSEL || '     , YOBI3_CH                       ';
--          VSQLSEL := VSQLSEL || '     , YOBI4_CH                       ';
--          VSQLSEL := VSQLSEL || '     , YOBI5_CH                       ';
--          VSQLSEL := VSQLSEL || '     , ALP_SHIMEI_KANA                ';
--          VSQLSEL := VSQLSEL || '     , ALP_SHIMEI_KANJI               ';
--          VSQLSEL := VSQLSEL || '     , GAI_SHIMEI_KANA                ';
--          VSQLSEL := VSQLSEL || '     , GAI_SHIMEI_KANJI               ';
--          VSQLSEL := VSQLSEL || '     , TSUSHOMEI_KANA                 ';
--          VSQLSEL := VSQLSEL || '     , TSUSHOMEI_KANJI                ';
--          VSQLSEL := VSQLSEL || '     , HEIKIMEI_KANA                  ';
--          VSQLSEL := VSQLSEL || '     , HEIKIMEI_KANJI                 ';
--          VSQLSEL := VSQLSEL || '     , GAIKOKU_JUMIN_NARU             ';
--          VSQLSEL := VSQLSEL || '     , ZAIRYU_NO_SHUBETSU             ';
--          VSQLSEL := VSQLSEL || '     , ZAIRYU_CARD_NO ';
--          VSQLSEL := VSQLSEL || '     , ZAIRYU_SHIKAKU_CD ';
--          VSQLSEL := VSQLSEL || '     , ZAIRYU_SHURYO_BI  ';
--          VSQLSEL := VSQLSEL || '     , ZAIRYU_KIKAN_NEN  ';
--          VSQLSEL := VSQLSEL || '     , ZAIRYU_KIKAN_TSUKI ';
--          VSQLSEL := VSQLSEL || '     , ZAIRYU_KIKAN_HI ';
--          VSQLSEL := VSQLSEL || '     , CARD_MANRYO_BI  ';
--          VSQLSEL := VSQLSEL || '     , KBN_30_45  ';
--          VSQLSEL := VSQLSEL || '     , KYOJYUCHI_UMU ';
--          VSQLSEL := VSQLSEL || '     , SEINENGAPI_FUSHO_KBN  ';
--          VSQLSEL := VSQLSEL || '     , RYOKEN_BANGO  ';
--          VSQLSEL := VSQLSEL || '     , RYOKEN_HAKKO_BI ';
--          VSQLSEL := VSQLSEL || '     , JORIKU_KYOKA_BI ';
--          VSQLSEL := VSQLSEL || '     , JUMIN_NUSHI_SHIMEI ';
--          VSQLSEL := VSQLSEL || '     , TOUGOU_NO  ';
--          VSQLSEL := VSQLSEL || '     , SEIDO_KOJIN_NO  ';
--          VSQLSEL := VSQLSEL || '     , SEIDO_HOJIN_NO  ';
--          VSQLSEL := VSQLSEL || '     , KYUUJI_KANA   ';
--          VSQLSEL := VSQLSEL || '     , KYUUJI_KANJI  ';
--          VSQLSEL := VSQLSEL || '     , FURIGANAKAKUNIN_TSUSHO  ';
--          VSQLSEL := VSQLSEL || '     , SEINENGAPI_FUSHO_HYOKI  ';
--          VSQLSEL := VSQLSEL || '     , JUGAI_SHIBOBI ';
--          VSQLSEL := VSQLSEL || '     , TOUGOU_FLG ';
--          VSQLSEL := VSQLSEL || '     , TAGYOMUSANSYO_FLG ';
--          VSQLSEL := VSQLSEL || '     , DOKUJISHISAKUID ';
--          VSQLSEL := VSQLSEL || '     , GYOMUID  ';
--          VSQLSEL := VSQLSEL || '     , HONSHITEN_KBN ';
--          VSQLSEL := VSQLSEL || '     , ZENGO_KBN  ';
--          VSQLSEL := VSQLSEL || '     , KOHYODOI ';
--          VSQLSEL := VSQLSEL || '     , HOJIN_SHUBETSU  ';
--          VSQLSEL := VSQLSEL || '     , HEISATOBI  ';
--          VSQLSEL := VSQLSEL || '     , TANTOBUSHO ';
--          VSQLSEL := VSQLSEL || '     , DAIHYO_KANA   ';
--          VSQLSEL := VSQLSEL || '     , KOKUMEI_CD ';
--          VSQLSEL := VSQLSEL || '     , KETAPRM  ';
--          VSQLSEL := VSQLSEL || '     , HOJIN_KANRI_NO  ';
--          VSQLSEL := VSQLSEL || '     , SETSURITSU_BI ';
--          VSQLSEL := VSQLSEL || '     , HEISATO_JIYU  ';
--          VSQLSEL := VSQLSEL || '     , YAGO  ';
--          VSQLSEL := VSQLSEL || ' FROM ';
--          VSQLSEL := VSQLSEL || '     GABTATENARIREKI ';
--          VSQLSEL := VSQLSEL || ' UNION ALL ';
--          VSQLSEL := VSQLSEL || ' SELECT  ';
--          VSQLSEL := VSQLSEL || '     aa.KOJIN_NO ';
--          VSQLSEL := VSQLSEL || '     , aa.RIREKI_RENBAN ';
--          VSQLSEL := VSQLSEL || '     , aa.TEKIYO_BI   ';
--          VSQLSEL := VSQLSEL || '     , aa.TOROKU_GYOMU  ';
--          VSQLSEL := VSQLSEL || '     , aa.SETAI_NO ';
--          VSQLSEL := VSQLSEL || '     , aa.GENZON_KBN  ';
--          VSQLSEL := VSQLSEL || '     , b.JUN_SETAI_KBN ';
--          VSQLSEL := VSQLSEL || '     , aa.JINKAKU_KBN ';
--          VSQLSEL := VSQLSEL || '     , aa.KOKUSEKI_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.SHISHO_CD   ';
--          VSQLSEL := VSQLSEL || '     , aa.CHIKU_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.GYOSEIKU_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.HAN_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.SHOGAKU_CD  ';
--          VSQLSEL := VSQLSEL || '     , aa.CHUGAKU_CD  ';
--          VSQLSEL := VSQLSEL || '     , aa.TOHYOKU_CD  ';
--          VSQLSEL := VSQLSEL || '     , aa.SANTEIDANTAI_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.SEINENGAPI  ';
--          VSQLSEL := VSQLSEL || '     , aa.WAREKI_SEINENGAPI ';
--          VSQLSEL := VSQLSEL || '     , aa.HYOJI_SEINENGAPI ';
--          VSQLSEL := VSQLSEL || '     , aa.SEIBETSU ';
--          VSQLSEL := VSQLSEL || '     , aa.USER_CD  ';
--          VSQLSEL := VSQLSEL || '     , aa.OAZA_CD  ';
--          VSQLSEL := VSQLSEL || '     , aa.HONBAN ';
--          VSQLSEL := VSQLSEL || '     , aa.EDABAN1  ';
--          VSQLSEL := VSQLSEL || '     , aa.EDABAN2  ';
--          VSQLSEL := VSQLSEL || '     , aa.EDABAN3  ';
--          VSQLSEL := VSQLSEL || '     , aa.KATAGAKI_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.GAIKU  ';
--          VSQLSEL := VSQLSEL || '     , aa.TOU ';
--          VSQLSEL := VSQLSEL || '     , aa.GOU ';
--          VSQLSEL := VSQLSEL || '     , aa.JICHI_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.SHIMEI_KANA ';
--          VSQLSEL := VSQLSEL || '     , aa.SHIMEI_KANJI  ';
--          VSQLSEL := VSQLSEL || '     , aa.YUBIN_NO ';
--          VSQLSEL := VSQLSEL || '     , aa.YUBIN_NOBC  ';
--          VSQLSEL := VSQLSEL || '     , aa.CHOMEI ';
--          VSQLSEL := VSQLSEL || '     , aa.BANCHI ';
--          VSQLSEL := VSQLSEL || '     , aa.KATAGAKI ';
--          VSQLSEL := VSQLSEL || '     , aa.DAIHYO_KATAGAKI ';
--          VSQLSEL := VSQLSEL || '     , aa.DAIHYO_SHIMEI ';
--          VSQLSEL := VSQLSEL || '     , aa.TEL_NO ';
--          VSQLSEL := VSQLSEL || '     , aa.TEL_KBN  ';
--          VSQLSEL := VSQLSEL || '     , aa.FAX_NO ';
--          VSQLSEL := VSQLSEL || '     , aa.MAIL_ADS ';
--          VSQLSEL := VSQLSEL || '     , aa.YUHEN_KBN   ';
--          VSQLSEL := VSQLSEL || '     , aa.TOROKU_JIYU ';
--          VSQLSEL := VSQLSEL || '     , aa.JUMINHYO_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.ZOKUGARACD1 ';
--          VSQLSEL := VSQLSEL || '     , aa.ZOKUGARACD2 ';
--          VSQLSEL := VSQLSEL || '     , aa.ZOKUGARACD3 ';
--          VSQLSEL := VSQLSEL || '     , aa.ZOKUGARACD4 ';
--          VSQLSEL := VSQLSEL || '     , aa.ZOKUGARAKBN ';
--          VSQLSEL := VSQLSEL || '     , aa.ZOKUGARAMEI ';
--          VSQLSEL := VSQLSEL || '     , aa.JITSUZOKUGARAMEI ';
--          VSQLSEL := VSQLSEL || '     , b.KISAI_JUNI  ';
--          VSQLSEL := VSQLSEL || '     , b.IDO_BI ';
--          VSQLSEL := VSQLSEL || '     , b.IDO_JIYU ';
--          VSQLSEL := VSQLSEL || '     , b.IDO_TODOKE_BI ';
--          VSQLSEL := VSQLSEL || '     , b.IDO_TODOKE_KBN  ';
--          VSQLSEL := VSQLSEL || '     , b.JUTEI_BI ';
--          VSQLSEL := VSQLSEL || '     , b.JUTEI_JIYU  ';
--          VSQLSEL := VSQLSEL || '     , b.JUTEI_TODOKEDE_BI ';
--          VSQLSEL := VSQLSEL || '     , b.JUTEI_TODOKEDE_KBN  ';
--          VSQLSEL := VSQLSEL || '     , b.GENJUSHO_REN  ';
--          VSQLSEL := VSQLSEL || '     , b.ZENJUSHO_REN  ';
--          VSQLSEL := VSQLSEL || '     , b.TENNYUMAE_REN ';
--          VSQLSEL := VSQLSEL || '     , b.TENNYU_MITODOKE_REN ';
--          VSQLSEL := VSQLSEL || '     , b.HONSEKI_REN ';
--          VSQLSEL := VSQLSEL || '     , b.TENSHUTSU_YOTEI_BI  ';
--          VSQLSEL := VSQLSEL || '     , b.TENSHUTSU_YOTEI_TODOKEDE_BI  ';
--          VSQLSEL := VSQLSEL || '     , b.TENSHUTSU_YOTEI_TODOKEDE_KBN ';
--          VSQLSEL := VSQLSEL || '     , b.TENSHUTSU_YOTEI_REN ';
--          VSQLSEL := VSQLSEL || '     , b.TENSHUTSU_KAKUTEI_BI  ';
--          VSQLSEL := VSQLSEL || '     , b.TENSHUTSU_KAKUTEI_TSUCHI_BI  ';
--          VSQLSEL := VSQLSEL || '     , b.TENSHUTSU_KAKUTEI_TODOKEDE_KBN ';
--          VSQLSEL := VSQLSEL || '     , b.TENSHUTSU_KAKUTEI_REN ';
--          VSQLSEL := VSQLSEL || '     , b.JUMIN_NARU ';
--          VSQLSEL := VSQLSEL || '     , b.JUMIN_NARU_JIYU ';
--          VSQLSEL := VSQLSEL || '     , b.JUMIN_NARU_TODOKEDE_BI  ';
--          VSQLSEL := VSQLSEL || '     , b.JUMIN_NARU_TODOKEDE_KBN ';
--          VSQLSEL := VSQLSEL || '     , b.JUMIN_NAKUNARU  ';
--          VSQLSEL := VSQLSEL || '     , b.JUMIN_NAKUNARU_JIYU ';
--          VSQLSEL := VSQLSEL || '     , b.JUMIN_NAKUNARU_TODOKEDE_BI ';
--          VSQLSEL := VSQLSEL || '     , b.JUMIN_NAKUNARU_TODOKEDE_KBN  ';
--          VSQLSEL := VSQLSEL || '     , b.SHIBOBI_FUSHO_KBN ';
--          VSQLSEL := VSQLSEL || '     , aa.HONMYO_KANA   ';
--          VSQLSEL := VSQLSEL || '     , aa.HONMYO_KANJI  ';
--          VSQLSEL := VSQLSEL || '     , b.NUSHI_SHIMEI_KANA ';
--          VSQLSEL := VSQLSEL || '     , b.NUSHI_SHIMEI_KANJI ';
--          VSQLSEL := VSQLSEL || '     , b.BIKO  ';
--          VSQLSEL := VSQLSEL || '     , b.KAISEI_BI  ';
--          VSQLSEL := VSQLSEL || '     , b.KAISEI_REN ';
--          VSQLSEL := VSQLSEL || '     , b.KYU_SHIMEI_KANA ';
--          VSQLSEL := VSQLSEL || '     , b.KYU_SHIMEI_KANJI  ';
--          VSQLSEL := VSQLSEL || '     , b.SHORIBI_KEY   ';
--          VSQLSEL := VSQLSEL || '     , b.SHORI_JIKAN_KEY ';
--          VSQLSEL := VSQLSEL || '     , b.SHORI_KBN_KEY ';
--          VSQLSEL := VSQLSEL || '     , b.ZENBU_ICHIBU_KEY  ';
--          VSQLSEL := VSQLSEL || '     , b.SHOKUINKOJIN_NO_KEY ';
--          VSQLSEL := VSQLSEL || '     , aa.SYS_SAKUSEIBI ';
--          VSQLSEL := VSQLSEL || '     , aa.SYS_KOSHINBI  ';
--          VSQLSEL := VSQLSEL || '     , aa.SYS_JIKAN  ';
--          VSQLSEL := VSQLSEL || '     , aa.SYS_SHOKUINKOJIN_NO ';
--          VSQLSEL := VSQLSEL || '     , aa.SYS_TANMATSU_NO ';
--          VSQLSEL := VSQLSEL || '     , b.GOMI_CD  ';
--          VSQLSEL := VSQLSEL || '     , b.SINYO_CD ';
--          VSQLSEL := VSQLSEL || '     , b.KOIKIKOFU_STOP_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.CHOMEI_KANA   ';
--          VSQLSEL := VSQLSEL || '     , aa.BANCHI_KANA   ';
--          VSQLSEL := VSQLSEL || '     , aa.KATAGAKI_KANA ';
--          VSQLSEL := VSQLSEL || '     , aa.KATAGAKI_HIDE_FLG ';
--          VSQLSEL := VSQLSEL || '     , aa.GAIJI_FLG  ';
--          VSQLSEL := VSQLSEL || '     , aa.HOJINSOSHIKI_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.JE_KOKUHOSHISANWARI_KBN ';
--          VSQLSEL := VSQLSEL || '     , aa.JE_JINTEKIGENMEN_KBN  ';
--          VSQLSEL := VSQLSEL || '     , aa.JE_SHOYUSHAKEISHONIN_KBN   ';
--          VSQLSEL := VSQLSEL || '     , aa.JE_LINK_KOJIN_NO  ';
--          VSQLSEL := VSQLSEL || '     , aa.JE_NAYOSE_NO  ';
--          VSQLSEL := VSQLSEL || '     , aa.YOBI1_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.YOBI2_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.YOBI3_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.YOBI4_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.YOBI5_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.YOBI1_CH ';
--          VSQLSEL := VSQLSEL || '     , aa.YOBI2_CH ';
--          VSQLSEL := VSQLSEL || '     , aa.YOBI3_CH ';
--          VSQLSEL := VSQLSEL || '     , aa.YOBI4_CH ';
--          VSQLSEL := VSQLSEL || '     , aa.YOBI5_CH ';
--          VSQLSEL := VSQLSEL || '     , b.ALP_SHIMEI_KANA ';
--          VSQLSEL := VSQLSEL || '     , b.ALP_SHIMEI_KANJI  ';
--          VSQLSEL := VSQLSEL || '     , b.GAI_SHIMEI_KANA ';
--          VSQLSEL := VSQLSEL || '     , b.GAI_SHIMEI_KANJI  ';
--          VSQLSEL := VSQLSEL || '     , b.TSUSHOMEI_KANA  ';
--          VSQLSEL := VSQLSEL || '     , b.TSUSHOMEI_KANJI ';
--          VSQLSEL := VSQLSEL || '     , b.HEIKIMEI_KANA ';
--          VSQLSEL := VSQLSEL || '     , b.HEIKIMEI_KANJI  ';
--          VSQLSEL := VSQLSEL || '     , b.GAIKOKU_JUMIN_NARU ';
--          VSQLSEL := VSQLSEL || '     , b.ZAIRYU_NO_SHUBETSU ';
--          VSQLSEL := VSQLSEL || '     , b.ZAIRYU_CARD_NO  ';
--          VSQLSEL := VSQLSEL || '     , b.ZAIRYU_SHIKAKU_CD ';
--          VSQLSEL := VSQLSEL || '     , b.ZAIRYU_SHURYO_BI  ';
--          VSQLSEL := VSQLSEL || '     , b.ZAIRYU_KIKAN_NEN  ';
--          VSQLSEL := VSQLSEL || '     , b.ZAIRYU_KIKAN_TSUKI ';
--          VSQLSEL := VSQLSEL || '     , b.ZAIRYU_KIKAN_HI ';
--          VSQLSEL := VSQLSEL || '     , b.CARD_MANRYO_BI  ';
--          VSQLSEL := VSQLSEL || '     , b.KBN_30_45  ';
--          VSQLSEL := VSQLSEL || '     , b.KYOJYUCHI_UMU ';
--          VSQLSEL := VSQLSEL || '     , b.SEINENGAPI_FUSHO_KBN  ';
--          VSQLSEL := VSQLSEL || '     , b.RYOKEN_BANGO  ';
--          VSQLSEL := VSQLSEL || '     , b.RYOKEN_HAKKO_BI ';
--          VSQLSEL := VSQLSEL || '     , b.JORIKU_KYOKA_BI ';
--          VSQLSEL := VSQLSEL || '     , b.JUMIN_NUSHI_SHIMEI ';
--          VSQLSEL := VSQLSEL || '     , aa.TOUGOU_NO  ';
--          VSQLSEL := VSQLSEL || '     , aa.SEIDO_KOJIN_NO  ';
--          VSQLSEL := VSQLSEL || '     , aa.SEIDO_HOJIN_NO  ';
--          VSQLSEL := VSQLSEL || '     , aa.KYUUJI_KANA   ';
--          VSQLSEL := VSQLSEL || '     , aa.KYUUJI_KANJI  ';
--          VSQLSEL := VSQLSEL || '     , aa.FURIGANAKAKUNIN_TSUSHO  ';
--          VSQLSEL := VSQLSEL || '     , aa.SEINENGAPI_FUSHO_HYOKI  ';
--          VSQLSEL := VSQLSEL || '     , aa.JUGAI_SHIBOBI ';
--          VSQLSEL := VSQLSEL || '     , aa.TOUGOU_FLG ';
--          VSQLSEL := VSQLSEL || '     , aa.TAGYOMUSANSYO_FLG ';
--          VSQLSEL := VSQLSEL || '     , aa.DOKUJISHISAKUID ';
--          VSQLSEL := VSQLSEL || '     , aa.GYOMUID  ';
--          VSQLSEL := VSQLSEL || '     , aa.HONSHITEN_KBN ';
--          VSQLSEL := VSQLSEL || '     , aa.ZENGO_KBN  ';
--          VSQLSEL := VSQLSEL || '     , aa.KOHYODOI ';
--          VSQLSEL := VSQLSEL || '     , aa.HOJIN_SHUBETSU  ';
--          VSQLSEL := VSQLSEL || '     , aa.HEISATOBI  ';
--          VSQLSEL := VSQLSEL || '     , aa.TANTOBUSHO ';
--          VSQLSEL := VSQLSEL || '     , aa.DAIHYO_KANA   ';
--          VSQLSEL := VSQLSEL || '     , aa.KOKUMEI_CD ';
--          VSQLSEL := VSQLSEL || '     , aa.KETAPRM  ';
--          VSQLSEL := VSQLSEL || '     , aa.HOJIN_KANRI_NO  ';
--          VSQLSEL := VSQLSEL || '     , aa.SETSURITSU_BI ';
--          VSQLSEL := VSQLSEL || '     , aa.HEISATO_JIYU  ';
--          VSQLSEL := VSQLSEL || '     , aa.YAGO  ';
--          VSQLSEL := VSQLSEL || ' FROM ';
--          VSQLSEL := VSQLSEL || '     GABTATENAKIHON aa  ';
--          VSQLSEL := VSQLSEL || '     , GABTJUKIIDO b ';
--          VSQLSEL := VSQLSEL || ' WHERE ';
--          VSQLSEL := VSQLSEL || '     aa.KOJIN_NO = b.KOJIN_NO(+) ) A, ';
          VSQLSEL := VSQLSEL || 'GABVATENAALL_B A, ';
--  2024/10/12 ZCZL.WANGMING Update END
--  2024/09/29 ZCZL.yangshuai Update end
          VSQLSEL := VSQLSEL || 'GKBTMSGAKUKYUCD C ';
          VSQLSEL := VSQLSEL || ' WHERE B.KOJIN_NO = A.KOJIN_NO';
          VSQLSEL := VSQLSEL || ' AND B.IDOJI_ATENA_RIREKI_RENBAN = A.RIREKI_RENBAN';
--  2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応
          --VSQLSEL := VSQLSEL || ' AND B.GAKKO_KBN_CD = C.GAKKO_KBN_CD';
          --VSQLSEL := VSQLSEL || ' AND B.GAKUKYU_CD = C.GAKUKYU_CD';
          VSQLSEL := VSQLSEL || ' AND B.GAKKO_KBN_CD = C.GAKKO_KBN_CD (+) ';
          VSQLSEL := VSQLSEL || ' AND B.GAKUKYU_CD = C.GAKUKYU_CD (+)';
--  2025/05/16 CTC.HJF UPDATE End
          --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:ST_GKB_TMP00008対応 Start
          VSQLSEL := VSQLSEL || ' AND B.SAISHIN_KBN = 0';
          --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:ST_GKB_TMP00008対応 End
--  2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応
          --VSQLSEL := VSQLSEL || ' AND C.GAKKO_CD = (CASE B.GAKKO_KBN_CD ';
          VSQLSEL := VSQLSEL || ' AND C.GAKKO_CD (+)  = (CASE B.GAKKO_KBN_CD ';
--  2025/05/16 CTC.HJF UPDATE End
          VSQLSEL := VSQLSEL || ' WHEN 1 THEN B.SYOGAKO_CD ';
          VSQLSEL := VSQLSEL || ' WHEN 2 THEN B.TYUGAKO_CD ';
          VSQLSEL := VSQLSEL || ' WHEN 3 THEN B.YOGOGAKO_CD ';
          VSQLSEL := VSQLSEL || ' WHEN 4 THEN B.KUIKIGAI_CD ';
          VSQLSEL := VSQLSEL || ' WHEN 5 THEN B.KUNISHIRITSU_CD ';
          VSQLSEL := VSQLSEL || ' END) ';
--  2024/08/30 ZCZL.WANGMING UPDATE START 0.3.000.001:IT_GKB_00075対応
--           VSQLSEL := VSQLSEL || ' AND ( B.SYOGAKO_CD = '|| VSYOGAKO_CD ||' ';
--           VSQLSEL := VSQLSEL || ' OR B.TYUGAKO_CD = '|| VTYUGAKO_CD ||' ';
--           VSQLSEL := VSQLSEL || ' OR B.YOGOGAKO_CD = '|| VYOGOGAKO_CD ||' ';
--           VSQLSEL := VSQLSEL || ' OR B.KUIKIGAI_CD = '|| VKUIKIGAI_CD ||' ';
--           VSQLSEL := VSQLSEL || ' OR B.KUNISHIRITSU_CD = '|| VKUNISHIRITSU_CD ||' ';
--  2024/09/29 ZCZL.yangshuai Update start 0.3.000.001:仕様変更 IT_GKB_00101対応
--           VSQLSEL := VSQLSEL || ' AND ( B.SYOGAKO_CD IN '|| '(' || VSYOGAKO_CD || ')' ;
--           VSQLSEL := VSQLSEL || ' OR B.TYUGAKO_CD IN '|| '(' || VTYUGAKO_CD || ')' ;
--           VSQLSEL := VSQLSEL || ' OR B.YOGOGAKO_CD IN '|| '(' || VYOGOGAKO_CD || ')';
--           VSQLSEL := VSQLSEL || ' OR B.KUIKIGAI_CD IN '|| '(' || VKUIKIGAI_CD || ')';
--           VSQLSEL := VSQLSEL || ' OR B.KUNISHIRITSU_CD IN '|| '(' || VKUNISHIRITSU_CD || ')';
          IF g_vJYOUKEN3 IS NOT NULL THEN
            VSQLSEL := VSQLSEL || ' AND ( B.SYOGAKO_CD IN '|| '(' || VSYOGAKO_CD || ')' ;
            bRTN := TRUE;
          END IF;
          IF g_vJYOUKEN4 IS NOT NULL THEN
            IF bRTN THEN
              VSQLSEL := VSQLSEL || ' OR B.TYUGAKO_CD IN '|| '(' || VTYUGAKO_CD || ')' ;
            ELSE
              VSQLSEL := VSQLSEL || ' AND ( B.TYUGAKO_CD IN '|| '(' || VTYUGAKO_CD || ')' ;
            END IF;
            bRTN := TRUE;
          END IF;
--  2025/05/15 CTC.GL UPDATE Start 1.0.004.000:GKB_QA14730対応
          --IF g_vJYOUKEN5 IS NOT NULL THEN
          IF g_vJYOUKEN6 IS NOT NULL THEN
--  2025/05/15 CTC.GL UPDATE End
            IF bRTN THEN
              VSQLSEL := VSQLSEL || ' OR B.YOGOGAKO_CD IN '|| '(' || VYOGOGAKO_CD || ')' ;
            ELSE
              VSQLSEL := VSQLSEL || ' AND ( B.YOGOGAKO_CD IN '|| '(' || VYOGOGAKO_CD || ')' ;
            END IF;
            bRTN := TRUE;
          END IF;
--  2025/05/15 CTC.GL UPDATE Start 1.0.004.000:GKB_QA14730対応
          --IF g_vJYOUKEN6 IS NOT NULL THEN
          IF g_vJYOUKEN5 IS NOT NULL THEN
--  2025/05/15 CTC.GL UPDATE End
            IF bRTN THEN
              VSQLSEL := VSQLSEL || ' OR B.KUIKIGAI_CD IN '|| '(' || VKUIKIGAI_CD || ')' ;
            ELSE
              VSQLSEL := VSQLSEL || ' AND ( B.KUIKIGAI_CD IN '|| '(' || VKUIKIGAI_CD || ')' ;
            END IF;
            bRTN := TRUE;
          END IF;
          IF g_vJYOUKEN9 IS NOT NULL THEN
            IF bRTN THEN
              VSQLSEL := VSQLSEL || ' OR B.KUNISHIRITSU_CD IN '|| '(' || VKUNISHIRITSU_CD || ')' ;
            ELSE
              VSQLSEL := VSQLSEL || ' AND ( B.KUNISHIRITSU_CD IN '|| '(' || VKUNISHIRITSU_CD || ')' ;
            END IF;
            bRTN := TRUE;
          END IF;
--  2024/09/29 ZCZL.yangshuai Update end
--  2024/08/30 ZCZL.WANGMING UPDATE END
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00659対応 START
          IF bRTN THEN
            VSQLSEL := VSQLSEL || ' )';
          END IF;
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00659対応 END
          VSQLSEL := VSQLSEL || ' AND ('|| DKIJYUNBI ||' >= B.SYOGAKO_NYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' >= B.SYOGAKO_TENNYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' >= B.TYUGAKO_NYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' >= B.TYUGAKO_TENNYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' >= B.KUIKIGAI_NYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' >= B.KUIKIGAI_TENNYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' >= B.YOGOGAKO_NYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' >= B.YOGOGAKO_TENNYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' >= B.KUNISHIRITSU_NYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' >= B.KUNISHIRITSU_TENNYUGAKU_BI ) ' ; 
--  2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
          --VSQLSEL := VSQLSEL || ' AND ('|| DKIJYUNBI ||' < B.SYOGAKO_SOTSUGYO_BI ' ;
          --VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < B.TYUGAKO_SOTSUGYO_BI ' ;
          --VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < B.KUIKIGAI_SOTSUGYO_BI ' ;
          --VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < B.YOGOGAKO_SOTSUGYO_BI ' ;
          --VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < B.KUIKIGAI_TAIGAKU_BI ' ;
          --VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < B.YOGOGAKO_TAIGAKU_BI ' ;
          --VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < B.KUNISHIRITSU_TAIGAKU_BI) ' ;
--  2025/05/16 CTC.HJF Delete End
--  2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応
          VSQLSEL := VSQLSEL || ' AND ('|| DKIJYUNBI ||' < DECODE(B.SYOGAKO_SOTSUGYO_BI,0,99999999,B.SYOGAKO_SOTSUGYO_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.TYUGAKO_SOTSUGYO_BI,0,99999999,B.TYUGAKO_SOTSUGYO_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.KUIKIGAI_SOTSUGYO_BI,0,99999999,B.KUIKIGAI_SOTSUGYO_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.YOGOGAKO_SOTSUGYO_BI,0,99999999,B.YOGOGAKO_SOTSUGYO_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.KUIKIGAI_TAIGAKU_BI,0,99999999,B.KUIKIGAI_TAIGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.YOGOGAKO_TAIGAKU_BI,0,99999999,B.YOGOGAKO_TAIGAKU_BI) ' ;
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.SYOGAKO_TENGAKU_BI,0,99999999,B.SYOGAKO_TENGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.TYUGAKO_TENGAKU_BI,0,99999999,B.TYUGAKO_TENGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.KUIKIGAI_TENGAKU_BI,0,99999999,B.KUIKIGAI_TENGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.YOGOGAKO_TENGAKU_BI,0,99999999,B.YOGOGAKO_TENGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.KUNISHIRITSU_TENGAKU_BI,0,99999999,B.KUNISHIRITSU_TENGAKU_BI) ' ;
--  2025/09/25 CTC.HJF UPDATE END
          VSQLSEL := VSQLSEL || ' OR '|| DKIJYUNBI ||' < DECODE(B.KUNISHIRITSU_TAIGAKU_BI,0,99999999,B.KUNISHIRITSU_TAIGAKU_BI)) ' ; 
--  2025/05/16 CTC.HJF UPDATE End

--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
          --VSQLSEL := VSQLSEL || ' AND B.GEN_NENGAPI = 0';
          VSQLSEL := VSQLSEL || ' AND (B.GEN_NENGAPI = 0 OR ' || DKIJYUNBI || ' < DECODE(B.GEN_NENGAPI, 0, 99999999, B.GEN_NENGAPI)) ';
--  2025/11/06 CTC.HJF UPDATE END
          VSQLSEL := VSQLSEL || ' AND B.GAKUNEN NOT IN (0,99)';
--  2025/09/25 CTC.HJF UPDATE END
--  2025/07/24 CTC.XMB ADD START 1.0.012.000:GKC_QA19006対応
          VSQLSEL := VSQLSEL || ' AND B.GAKKO_KBN_CD <> 999';
--  2025/07/24 CTC.XMB ADD END
-- 2024/07/12 ZCZL.qinyue Add end
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
          VSQLSEL := VSQLSEL || ' AND B.SAKUJO_FLG <> 1';
          VSQLSEL := VSQLSEL || ' ) SK ';
          VSQLSEL := VSQLSEL || 'WHERE RN = 1 ';
--  2025/11/06 CTC.HJF UPDATE END
          OPEN CRATENA  FOR VSQLSEL;
          
          LOOP
            FETCH  CRATENA INTO CRATENA_WORK;
            EXIT WHEN CRATENA%NOTFOUND;

            ICNT := ICNT+1;
            VCNT :=  TO_CHAR(ICNT);
            
-- 2024/07/12 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--             GKBSKJDOG2(CRATENA_WORK.KOJIN_NO,CRATENA_WORK.RIREKI_RENBAN,RG,NPRTN);
          GKBSKJDOG2(CRATENA_WORK.KOJIN_NO,CRATENA_WORK.RIREKI_RENBAN,CRATENA_WORK.RIREKI_RENBAN_EDA,RG,NPRTN);

            --チェック用個人番号のセット
            IF ICNT = 1 THEN
              KOJINNO1 := (RG.KOJIN_NO);
              KOJINNO2 := 0;
            ELSE
              KOJINNO2 := RG.KOJIN_NO;
            END IF;

            IF NPRTN = 0 AND KOJINNO1 <> KOJINNO2 THEN
              IF RG.HOGOSYA_KOJIN_NO <> 0 THEN
                 IRTNAH := GAAPK0030.FGETATENA(  RG.HOGOSYA_KOJIN_NO,
                                               'GKB',
                                               ISAKUSEIBI,
                                               RB,
                                               RC);
                 IRTNZOKUGARA1 := GKBFKZKGMGET(1,
                                               RG.ZOKUGARA1,
                                               RG.ZOKUGARA2,
                                               RG.ZOKUGARA3,
                                               RG.ZOKUGARA4,
                                               VZOKUGARAMEI1,
                                               IRTNZOKUGARAHERR1);
                 IRTNZOKUGARA2 := GKBFKZKGMGET(2,
                                               RG.HOGOSYA_ZOKUGARA1,
                                               RG.HOGOSYA_ZOKUGARA2,
                                               RG.HOGOSYA_ZOKUGARA3,
                                               RG.HOGOSYA_ZOKUGARA4,
                                               VZOKUGARAMEI2,
                                               IRTNZOKUGARAHERR2);
                 ISHIMEINAGASA := NVL(LENGTH(RB.SHIMEI_KANJI),0);
                 IF ISHIMEINAGASA > 15 THEN
                    SELECT SUBSTR (SHIMEI_KANJI,1,15) INTO VHOGOSHA_SHIMEI_JODAN
                      FROM GABTATENAKIHON
                     WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                    SELECT SUBSTR (SHIMEI_KANJI,16,15) INTO VHOGOSHA_SHIMEI_GEDAN
                      FROM GABTATENAKIHON
                     WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                 ELSIF ISHIMEINAGASA = 0 THEN
                     VHOGOSHA_SHIMEI_JODAN := NULL;
                     VHOGOSHA_SHIMEI_GEDAN := NULL;
                 ELSE
                     SELECT SHIMEI_KANJI INTO VHOGOSHA_SHIMEI_JODAN
                       FROM GABTATENAKIHON
                      WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                     VHOGOSHA_SHIMEI_GEDAN := NULL;
                 END IF;
              ELSE
                 RB.SHIMEI_KANA := NULL;
                 RB.SHIMEI_KANJI := NULL;
                 VZOKUGARAMEI1 := NULL;
                 VZOKUGARAMEI2 := NULL;
                 VHOGOSHA_SHIMEI_JODAN := NULL;
                 VHOGOSHA_SHIMEI_GEDAN := NULL;
              END IF;

              --出力ﾌﾗｸﾞ 初期化
              BOUT_FLG := FALSE;

              /*****   チェック１：基準日判断  ここから   ******/
              --まず読込レコードが基準日時点のデータかチェック
              PROC_CHECK_KIJUN(RG,KIJUN_BI2,MHIZUKE);
--  2025/06/11 CTC.HJF UPDATE Start 1.0.008.000:GKB_QA15686対応
              IF MHIZUKE(1).GAKO_KBN =0 AND MHIZUKE(2).GAKO_KBN =0 AND MHIZUKE(3).GAKO_KBN =0 AND MHIZUKE(4).GAKO_KBN =0 AND MHIZUKE(5).GAKO_KBN =0 THEN
                 VSQLSEL_RIREKI := 'SELECT * FROM GKBTGAKUREIBO WHERE KOJIN_NO =' || CRATENA_WORK.KOJIN_NO || 'ORDER BY RIREKI_RENBAN DESC';
                 OPEN CRATENA_OLDRIREKI  FOR VSQLSEL_RIREKI;
                  LOOP
                   FETCH  CRATENA_OLDRIREKI INTO CRATENA_OLDRIREKIWORK;
                   EXIT WHEN CRATENA_OLDRIREKI%NOTFOUND;
                     IF CRATENA_WORK.RIREKI_RENBAN  != CRATENA_OLDRIREKIWORK.RIREKI_RENBAN THEN
                        GKBSKJDOG2(CRATENA_OLDRIREKIWORK.KOJIN_NO,CRATENA_OLDRIREKIWORK.RIREKI_RENBAN,CRATENA_OLDRIREKIWORK.RIREKI_RENBAN_EDA,RG,NPRTN);
                        PROC_CHECK_KIJUN(RG,KIJUN_BI2,MHIZUKE);
                     END IF;
                     EXIT WHEN	 MHIZUKE(1).GAKO_KBN <> 0 OR MHIZUKE(2).GAKO_KBN <> 0 OR MHIZUKE(3).GAKO_KBN <> 0 OR MHIZUKE(4).GAKO_KBN <> 0 OR MHIZUKE(5).GAKO_KBN <> 0;
                   END LOOP;
              END IF;
--  2025/06/11 CTC.HJF UPDATE End
              --個人番号が変わる場合、保持用変数初期化
              IF KOJINNO3 <> RG.KOJIN_NO THEN
                KOJINNO3 := RG.KOJIN_NO;
                IGAKO_KBN   := 0;
                BOUT_FLG2   := FALSE;
                BOUT_FLG3   := FALSE;
                --変数初期化
                --IDX=1:区域外、2:特別支援、3:小学校、4:中学校
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 START
--                FOR IDX IN 1..4 LOOP
                FOR IDX IN 1..5 LOOP
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 END
                  MHIZUKE_SAV(IDX).GAKO_KBN   := 0;
                  MHIZUKE_SAV(IDX).GAKO_CD    := 0;
                  MHIZUKE_SAV(IDX).IN_D       := 0;
                  MHIZUKE_SAV(IDX).OUT_D      := 0;
                END LOOP;
                --区域外、養護学校、小学校、中学校順位で基準日時点に在学したか確認
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 START
--                FOR IDX IN 1..4 LOOP
                FOR IDX IN 1..5 LOOP
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 END
                  IF MHIZUKE(IDX).GAKO_KBN > 0 THEN         --読込レコードが基準日対象の場合
                    IGAKO_KBN := IDX;                        --基準日時点のを最初に見つかったのが対象になる
                    BOUT_FLG2 := TRUE;
                  END IF;
                  EXIT WHEN BOUT_FLG2 = TRUE;
                END LOOP;
                MHIZUKE_SAV   := MHIZUKE;
              ELSE                                            --MAX以前の履歴の場合
                --同じ個人番号で既に基準日対象レコードが見つかった場合、次へ飛ばす
                --基準日には該当するが、他の条件を満たさない場合、次へ飛ばす
                IF BOUT_FLG3 THEN GOTO continue;END IF;
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 START
--                FOR IDX IN 1..4 LOOP       --区域外、養護学校、小学校、中学校順位で基準日時点に在学したか確認
                FOR IDX IN 1..5 LOOP
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 END
                  IF MHIZUKE(IDX).GAKO_KBN > 0 THEN         --読込レコードが基準日対象の場合
                    IF MHIZUKE(IDX).IN_D >= MHIZUKE_SAV(IDX).IN_D THEN  --読込レコード＞＝前回の入日付の入日付の場合、前回ので判断
                      --前回ので判断する場合、学校が変わるとスキップ
                      IF MHIZUKE_SAV(IDX).GAKO_CD = MHIZUKE(IDX).GAKO_CD
                       AND MHIZUKE_SAV(IDX).IN_D <= KIJUN_BI2 AND (KIJUN_BI2 <= MHIZUKE_SAV(IDX).OUT_D OR MHIZUKE_SAV(IDX).OUT_D = 0)
                       AND MHIZUKE(IDX).IN_D <> MHIZUKE_SAV(IDX).IN_D
                       THEN
                        IF BOUT_FLG2 = FALSE THEN
                          IGAKO_KBN := IDX;                        --基準日時点のを最初に見つかったのが対象になる
                          BOUT_FLG2 := TRUE;
                        END IF;
                      END IF;
                    ELSE                                            --今回ので判断
                      IF MHIZUKE(IDX).IN_D <= KIJUN_BI2 AND (KIJUN_BI2 <= MHIZUKE(IDX).OUT_D OR MHIZUKE(IDX).OUT_D = 0)
                       AND ((MHIZUKE_SAV(IDX).GAKO_CD = MHIZUKE(IDX).GAKO_CD AND MHIZUKE(IDX).IN_D =  MHIZUKE_SAV(IDX).IN_D)
                            OR (MHIZUKE_SAV(IDX).GAKO_CD <> MHIZUKE(IDX).GAKO_CD))
                       THEN
                        IF BOUT_FLG2 = FALSE THEN
                          IGAKO_KBN := IDX;
                          BOUT_FLG2 := TRUE;
                        END IF;
                      END IF;
                      MHIZUKE_SAV(IDX)   := MHIZUKE(IDX);
                    END IF;
                  END IF;
                  MHIZUKE_SAV(IDX)   := MHIZUKE(IDX);
                END LOOP;
              END IF;
              /*****   チェック１：基準日判断  ここまで    ******/

              /*****   チェック２：任意ビット条件の対象か判断 ここから *****/
--               IF BOUT_FLG2 = TRUE AND VNINIBIT IS NOT NULL THEN
--                  BOUT_FLG2 := FALSE;  --任意ビット条件がある場合、クリア
--                  NNINIBIT_KISU := LENGTH(VNINIBIT)/4;        ------任意ビット項目の数量を取得
--                  NNINIBIT_SYUBETU := TO_NUMBER(SUBSTR(VNINIBIT,1,2));     ----上2桁(種別)
--                  NNINIBIT_ATAI := TO_NUMBER(SUBSTR(VNINIBIT,3,2));        ----下2桁（値）
--                  X := NNINIBIT_SYUBETU+1;
--                  FOR NTIMES IN 1..NNINIBIT_KISU LOOP
--                       NNINIBIT_SYUBETU := TO_NUMBER(SUBSTR(VNINIBIT,4*NTIMES-3,2));
--                       NNINIBIT_ATAI := TO_NUMBER(SUBSTR(VNINIBIT,4*NTIMES-1,2));
--                       X := NNINIBIT_SYUBETU+1;
--                      --任意ビットをチェック
--                       BOUT_FLG2 := FUNC_CHK_NINIBIT(CRATENA_WORK,X,NNINIBIT_ATAI);
--                       EXIT WHEN BOUT_FLG2 = TRUE;
--                  END LOOP;
--                 --基準日には該当するが任意ビット条件に該当しなければ、該当個人番号はスキップ
--                  IF BOUT_FLG2 = FALSE THEN
--                    BOUT_FLG3 := TRUE;
--                    GOTO continue;
--                  END IF;
--               END IF;
              /*****   チェック２：任意ビット条件の対象か判断 ここまで *****/

              --区域外
              --基準日には該当するが学校条件に該当しなければ、該当個人番号はスキップ
              IF IGAKO_KBN = 1 AND VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.KUIKIGAI_CD,VKUIKIGAI_CD) = 0 THEN
                BOUT_FLG3 := TRUE;
                GOTO continue;
              END IF;
              --(区域外コード<>0) AND (区域外.増年月日<=基準日) AND (区域外.減年月日>基準日 OR 区域外.減年月日すべて0)
              IF BOUT_FLG2 AND IGAKO_KBN = 1 THEN
                BEGIN
                 SELECT KUIKIGAI_CD,
                        KUIKIGAIMEI
                   INTO IGAKO_CD,
                        VGAKOMEI
                   FROM GKBTKUIKIGAI
                  WHERE KUIKIGAI_CD = RG.KUIKIGAI_CD;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     IGAKO_CD := RG.KUIKIGAI_CD;
                     VGAKOMEI := ' ';
                END;
                IGAKO_CD := RG.KUIKIGAI_CD + 30000;
                VGAKUNENMEI := FUNC_EDIT_GAKUNENMEI( CRATENA_WORK.GAKUNEN );

                --出力ﾌﾗｸﾞ=TRUE
                BOUT_FLG := TRUE;
              END IF;

              --特別支援学校
              --(養護コード<>0) AND (養護.増年月日<=基準日) AND (養護.減年月日>基準日 OR 養護.減年月日すべて0)
              --基準日には該当するが学校条件に該当しなければ、該当個人番号はスキップ
              IF IGAKO_KBN = 2 AND VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.YOGOGAKO_CD,VYOGOGAKO_CD) = 0 THEN
                BOUT_FLG3 := TRUE;
                GOTO continue;
              END IF;
              IF BOUT_FLG2 AND IGAKO_KBN = 2 THEN

                BEGIN
                SELECT YOGOGAKO_CD,
                       YOGOGAKOMEI
                  INTO IGAKO_CD,
                       VGAKOMEI
                  FROM GKBTYOGOGAKKO
                 WHERE YOGOGAKO_CD = RG.YOGOGAKO_CD;
                EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                   IGAKO_CD := RG.YOGOGAKO_CD;
                   VGAKOMEI := ' ';
                END;
                IGAKO_CD := RG.YOGOGAKO_CD + 40000;
                VGAKUNENMEI := FUNC_EDIT_GAKUNENMEI(CRATENA_WORK.GAKUNEN );
                --出力ﾌﾗｸﾞ=TRUE
                BOUT_FLG := TRUE;
              END IF;

              --小・中学校
              IF CRATENA_WORK.GAKUNEN < 7 THEN
                --小学校
                --基準日には該当するが学校条件に該当しなければ、該当個人番号はスキップ
                IF IGAKO_KBN = 3 AND VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.SYOGAKO_CD,VSYOGAKO_CD) = 0 THEN
                  BOUT_FLG3 := TRUE;
                  GOTO continue;
                END IF;
                --(小学校コード<>0) AND (小学校.増年月日<=基準日) AND (小学校.減年月日>基準日 OR 小学校.減年月日すべて0)
                IF BOUT_FLG2 AND IGAKO_KBN = 3 THEN

                  BEGIN
                  SELECT SYOGAKO_CD,
                         SYOGAKOMEI
                    INTO IGAKO_CD,
                         VGAKOMEI
                    FROM GKBTSHOGAKKO
                   WHERE SYOGAKO_CD = RG.SYOGAKO_CD;
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      IGAKO_CD := RG.SYOGAKO_CD;
                      VGAKOMEI := ' ';
                  END;
                  IGAKO_CD := RG.SYOGAKO_CD+10000;
                  VGAKUNENSEI := TO_CHAR(CRATENA_WORK.GAKUNEN);
                  VGAKUNENMEI := VGAKUNENSEI || '年生';
                  --出力ﾌﾗｸﾞ=TRUE
                  BOUT_FLG := TRUE;
                END IF;
              ELSE
                --中学校
                --基準日には該当するが学校条件に該当しなければ、該当個人番号はスキップ
                IF IGAKO_KBN = 4 AND VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.TYUGAKO_CD,VTYUGAKO_CD) = 0 THEN
                  BOUT_FLG3 := TRUE;
                  GOTO continue;
                END IF;
                --(中学校コード<>0) AND (中学校.増年月日<=基準日) AND (中学校.減年月日>基準日 OR 中学校.減年月日すべて0)
                IF BOUT_FLG2 AND IGAKO_KBN = 4 THEN
                  BEGIN
                  SELECT TYUGAKO_CD,
                         TYUGAKOMEI
                    INTO IGAKO_CD,
                         VGAKOMEI
                    FROM GKBTCHUGAKKO
                   WHERE TYUGAKO_CD = RG.TYUGAKO_CD;
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      IGAKO_CD := RG.TYUGAKO_CD;
                      VGAKOMEI := ' ';
                  END;
                  IGAKO_CD := RG.TYUGAKO_CD + 20000;
                  NGAKUNENSEI := CRATENA_WORK.GAKUNEN - 6;
                  VGAKUNENSEI := TO_CHAR(NGAKUNENSEI);
                  VGAKUNENMEI := VGAKUNENSEI || '年生';
                  --出力ﾌﾗｸﾞ=TRUE
                  BOUT_FLG := TRUE;
                END IF;
              END IF;
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 START
              --国私立学校
              --基準日には該当するが学校条件に該当しなければ、該当個人番号はスキップ
              IF IGAKO_KBN = 5 AND VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.KUNISHIRITSU_CD,VKUNISHIRITSU_CD) = 0 THEN
                BOUT_FLG3 := TRUE;
                GOTO continue;
              END IF;
              --(国私立コード<>0) AND (国私立.増年月日<=基準日) AND (国私立.減年月日>基準日 OR 国私立.減年月日すべて0)
              IF BOUT_FLG2 AND IGAKO_KBN = 5 THEN
                BEGIN
                 SELECT KUNISHIRITSUGAKKO_CD,
                        KUNISHIRITSUGAKKOMEI
                   INTO IGAKO_CD,
                        VGAKOMEI
                   FROM GKBTKUNISIRITSUGAKKO
                  WHERE KUNISHIRITSUGAKKO_CD = RG.KUNISHIRITSU_CD;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     IGAKO_CD := RG.KUNISHIRITSU_CD;
                     VGAKOMEI := ' ';
                END;
                IGAKO_CD := RG.KUNISHIRITSU_CD + 50000;
                VGAKUNENMEI := FUNC_EDIT_GAKUNENMEI(CRATENA_WORK.GAKUNEN);
                --出力ﾌﾗｸﾞ=TRUE
                BOUT_FLG := TRUE;
              END IF;
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:IT_GKB_00692対応 END
              IRTNA := GAAPK0030.FGETATENA(  CRATENA_WORK.KOJIN_NO,
                                           'GKB',
                                           ISAKUSEIBI,
                                           RA,
                                           RASO);
              IWAREKIHIZUKE := 0;
              BRTNSEINENGAPI := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                    RA.SEINENGAPI,
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

              IF RA.SEIBETSU = 1 THEN
                 VSEIBETSU := '男';
              ELSIF RA.SEIBETSU = 2 THEN
                 VSEIBETSU := '女';
              END IF;

              VSETAI_NO :=  TO_CHAR(RA.SETAI_NO);

              VGYOSEIKU_MEI := GAAPK0030.FGYOSEIKUMEI(RA.SANTEIDANTAI_CD,RA.GYOSEIKU_CD);
              VHAN_MEI := GAAPK0030.FHANMEI(RA.SANTEIDANTAI_CD,
                                             RA.HAN_CD);
              IRTNSANTEIDANTAI := GAAPK0030.FJICHINAME(RA.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);

              NNENDO := TO_NUMBER(VNENDO);          -- 年度

              VHYOUJINENDO := KKAPK0020.FNENDOEDIT(1,
                                                    NNENDO,
                                                    3);
              IWAREKIHIZUKE := 0;
              BRTNSASKUSEIBI := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                     ISAKUSEIBI,
                                                     VEDIT_GYYMMDD3,
                                                     VEDIT_GYYMMDD2,
                                                     VSASKUSEIBI,
                                                     VKJ_GENGO,
                                                     VKG_GENGO,
                                                     IWAREKI_YY,
                                                     ISEIREKI_YYYY,
                                                     IWAREKI_GYYMM,
                                                     IMM,
                                                     IDD,
                                                     IOWAREKIHIZUKE,
                                                     ISEIREKIHIZUKE);

              IJUSHO_NAGASA := LENGTH(RA.CHOMEI||RA.BANCHI||' '||RA.KATAGAKI);
              IF IJUSHO_NAGASA > 20 THEN
                 VJUSHO_JODAN := SUBSTR (RA.CHOMEI||RA.BANCHI||' '||RA.KATAGAKI,1,20);
                 VJUSHO_GEDAN := SUBSTR (RA.CHOMEI||RA.BANCHI||' '||RA.KATAGAKI,21,20);
              ELSE
                 VJUSHO_JODAN := RA.CHOMEI||RA.BANCHI||' '||RA.KATAGAKI;
                 VJUSHO_GEDAN :=  ' ';
              END IF;
              IRTN := GAAPK0030.FGETATENA(CRATENA_WORK.KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), o_RATENA_REC, o_RSOFU_REC);

              IF BOUT_FLG = TRUE THEN
                 Insert INTO GKBWJIDOZAIGAKU Values (RG.KOJIN_NO,
                                                 RA.SHIMEI_KANA,
                                                 RA.SHIMEI_KANJI,
                                                 RA.SEINENGAPI,
                                                 VSEINENGAPI,
                                                 RA.SEIBETSU,
                                                 VSEIBETSU,
                                                 VZOKUGARAMEI1,
                                                 RA.SETAI_NO,
                                                 VSETAI_NO,
                                                 RG.HOGOSYA_KOJIN_NO,
                                                 RB.SHIMEI_KANA,
                                                 RB.SHIMEI_KANJI,
                                                 VZOKUGARAMEI2,
                                                 CRATENA_WORK.GAKUNEN,
                                                 VGAKUNENMEI,
                                                 IGAKO_CD,
                                                 VGAKOMEI,
                                                 RA.GYOSEIKU_CD,
                                                 VGYOSEIKU_MEI,
                                                 RA.HAN_CD,
                                                 VHAN_MEI,
                                                 RA.SANTEIDANTAI_CD,
                                                 VSANTEIDANTAI_MEI,
                                                 RA.YUBIN_NO,
                                                 RA.CHOMEI,
                                                 RA.BANCHI,
                                                 RA.KATAGAKI,
                                                 VHYOUJINENDO,
                                                 '0',
                                                 ' ',
                                                 VSASKUSEIBI,
                                                 ICNT,
                                                 VCNT,
                                                 VHOGOSHA_SHIMEI_JODAN,
                                                 VHOGOSHA_SHIMEI_GEDAN,
                                                 VJUSHO_JODAN,
                                                 VJUSHO_GEDAN
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,NULL
                                                 ,o_RATENA_REC.JINKAKU_KBN
-- 2024/07/12 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
                                                 ,CRATENA_WORK.SYOGAKO_CD  --小学校コード
                                                 ,CRATENA_WORK.TYUGAKO_CD  --中学校コード
                                                 ,CRATENA_WORK.KUIKIGAI_CD  --区域外学校コード
                                                 ,CRATENA_WORK.YOGOGAKO_CD  --盲聾養護学校コード
                                                 ,CRATENA_WORK.KUNISHIRITSU_CD  --国私立学校コード
                                                 ,CRATENA_WORK.GAKUKYU_KBN  --学級区分
                                                 ,CRATENA_WORK.GAKKO_KBN_CD  --学校区分コード
                                                 ,'0'  --学校コード
                                                 ,NULL  --学校名
                                                 ,CRATENA_WORK.OAZA_CD  --大字コード
                                                 ,CRATENA_WORK.SHOGAKKOKU_CD  --小学校区コード
                                                 ,CRATENA_WORK.CHUGAKKOKU_CD  --中学校区コード
                                                 ,'0'  --続柄コード１
                                                 ,'0'  --続柄コード２
                                                 ,'0'　　--続柄コード３
                                                 ,'0'　　--続柄コード４　
                                                 ,'0'  --基準日
                                                 ,'0'  --児童生徒国籍
                                                 ,'0'  --保護者国籍
                                                 ,NULL  --備考
-- 2024/07/12 ZCZL.qinyue Add end
                                                  );
                commit;
                KOJINNO1 := RG.KOJIN_NO;
                FRET := c_ISUCCESS;
              END IF;
            ELSE
              NULL;
            END IF;
            <<continue>>
              NULL;
          END LOOP;
            CLOSE CRATENA;
        RETURN FRET;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;       -- 処理前に戻す
                FRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN FRET;
    EXCEPTION
        /* その他エラー */
        WHEN OTHERS THEN
            ROLLBACK;       -- 処理前に戻す
            FRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 児童生徒中間（GKBWJIDOZAIGAKU）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        VSQLSEL             NVARCHAR2(9000);            -- ＳＱＬ文
        I_CUR               PLS_INTEGER;                -- カーソル
        RREC                GKBWJIDOZAIGAKU%ROWTYPE;    -- 入学通知台帳のレコード変数
        NROWS               NUMBER;
        IPAGECNT            PLS_INTEGER;                -- 頁数
        IGYOCNT             PLS_INTEGER;                -- 行番号
        IGYORENBAN          PLS_INTEGER;                -- 行連番
        VPAGENAME           NVARCHAR2(500);             -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(500);             -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(500);             -- 改頁項目値のワーク
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IGYOCNT := 0;
        ICNT := 0;
        MJIDO_WORK.DELETE;                   -- ワーク領域の初期化

        VPAGEFD := ' GAKUNEN_CD||GAKOKU_CD ';    
        VPAGENM := ' GAKOKUMEI ';

        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'NENDO, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
            VSQLSEL := VSQLSEL || 'GAKUNENMEI, ';
            VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
            VSQLSEL := VSQLSEL || 'RENBAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || VPAGEFD || ' KAIPEJI_CD, ';            -- 改頁値を設定
            VSQLSEL := VSQLSEL || VPAGENM || ' KAIPEJI ';                -- 改頁名を設定
            VSQLSEL := VSQLSEL || ',NINIBIT1, ';
            VSQLSEL := VSQLSEL || 'NINIBIT2, ';
            VSQLSEL := VSQLSEL || 'NINIBIT3, ';
            VSQLSEL := VSQLSEL || 'NINIBIT4, ';
            VSQLSEL := VSQLSEL || 'NINIBIT5, ';
            VSQLSEL := VSQLSEL || 'NINIBIT6, ';
            VSQLSEL := VSQLSEL || 'NINIBIT7, ';
            VSQLSEL := VSQLSEL || 'NINIBIT8, ';
            VSQLSEL := VSQLSEL || 'NINIBIT9, ';
            VSQLSEL := VSQLSEL || 'NINIBIT10, ';
            VSQLSEL := VSQLSEL || 'NINIBIT11, ';
            VSQLSEL := VSQLSEL || 'NINIBIT12, ';
            VSQLSEL := VSQLSEL || 'NINIBIT13, ';
            VSQLSEL := VSQLSEL || 'NINIBIT14, ';
            VSQLSEL := VSQLSEL || 'NINIBIT15, ';
            VSQLSEL := VSQLSEL || 'NINIBIT16, ';
            VSQLSEL := VSQLSEL || 'NINIBIT17, ';
            VSQLSEL := VSQLSEL || 'NINIBIT18, ';
            VSQLSEL := VSQLSEL || 'NINIBIT19, ';
            VSQLSEL := VSQLSEL || 'NINIBIT20, ';
            VSQLSEL := VSQLSEL || 'JINKAKU_KBN ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWJIDOZAIGAKU ';
            -- ［ORDER BY］句を付加
            IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
               VSQLSEL := VSQLSEL || ' ORDER BY ' || g_rJSTP.Orderbyclause;
            END IF;
             -- カーソルのオープン
            I_CUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(I_CUR, VSQLSEL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, RREC.NENDO, 10);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, RREC.KAIPEJI, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.GAKUNENMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.SAKUSEIBI, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.RENBAN, 3);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.JIDO_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.JIDO_SHIMEI_KANJI, 100);
-- 2024/07/12 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.HYOJI_SEIBETSU, 2);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.HYOJI_SEIBETSU, 4);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.HOGOSHA_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.HOGOSHA_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.ZOKUGARAMEI1, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.ZOKUGARAMEI2, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.HYOJI_SEINENGAPI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.KON_JUSHO_JODAN, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.KON_JUSHO_GEDAN, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.GYOSEIKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, VPAGENM, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.NINIBIT1);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.NINIBIT2);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.NINIBIT3);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.NINIBIT4);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.NINIBIT5);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.NINIBIT6);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.NINIBIT7);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.NINIBIT8);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.NINIBIT9);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, RREC.NINIBIT10);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, RREC.NINIBIT11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, RREC.NINIBIT12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, RREC.NINIBIT13);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, RREC.NINIBIT14);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 34, RREC.NINIBIT15);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 35, RREC.NINIBIT16);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 36, RREC.NINIBIT17);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 37, RREC.NINIBIT18);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 38, RREC.NINIBIT19);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 39, RREC.NINIBIT20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 40, RREC.JINKAKU_KBN);
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(I_CUR);
            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(I_CUR) > 0 THEN

                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  1, MJIDO_WORK(ICNT).NENDO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  2, MJIDO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  3, MJIDO_WORK(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  4, MJIDO_WORK(ICNT).GAKUNENMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  5, MJIDO_WORK(ICNT).SAKUSEIBI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  7, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  9, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MJIDO_WORK(ICNT).ZOKUGARAMEI1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MJIDO_WORK(ICNT).ZOKUGARAMEI2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MJIDO_WORK(ICNT).KON_JUSHO_JODAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MJIDO_WORK(ICNT).KON_JUSHO_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MJIDO_WORK(ICNT).GYOSEIKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 18, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 19, VPAGENAME);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 20,MJIDO_WORK(ICNT).NINIBIT1 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 21,MJIDO_WORK(ICNT).NINIBIT2 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 22,MJIDO_WORK(ICNT).NINIBIT3 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 23,MJIDO_WORK(ICNT).NINIBIT4 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 24,MJIDO_WORK(ICNT).NINIBIT5 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 25,MJIDO_WORK(ICNT).NINIBIT6 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 26,MJIDO_WORK(ICNT).NINIBIT7 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 27,MJIDO_WORK(ICNT).NINIBIT8 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 28,MJIDO_WORK(ICNT).NINIBIT9 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 29,MJIDO_WORK(ICNT).NINIBIT10 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 30,MJIDO_WORK(ICNT).NINIBIT11);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 31,MJIDO_WORK(ICNT).NINIBIT12 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 32,MJIDO_WORK(ICNT).NINIBIT13 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 33,MJIDO_WORK(ICNT).NINIBIT14 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 34,MJIDO_WORK(ICNT).NINIBIT15 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 35,MJIDO_WORK(ICNT).NINIBIT16 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 36,MJIDO_WORK(ICNT).NINIBIT17 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 37,MJIDO_WORK(ICNT).NINIBIT18 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 38,MJIDO_WORK(ICNT).NINIBIT19 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 39,MJIDO_WORK(ICNT).NINIBIT20 );
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 40,MJIDO_WORK(ICNT).JINKAKU_KBN );
                    
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
            DBMS_SQL.CLOSE_CURSOR(I_CUR);
        EXCEPTION
            WHEN OTHERS THEN
                FRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        RETURN FRET;
    END FUNC_GET_JIDO_WK_CSV;
    --------------------------------------------------------------------------------
    -- 児童生徒中間（GKBWJIDOZAIGAKU）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        ININIBIT_RET        PLS_INTEGER;                -- 任意ビット戻る値
        o_TITLE             NVARCHAR2(1000);            -- 戻りNINNIBITタイトル
        o_NINIMEISHO        A_CONS_PRM;                 -- 戻りNINNIBIT値配列
        VNINIBITMEISHO      NVARCHAR2(1000);            -- 戻りNINNIBIT名称
        VNINIBIT_JOHO       NVARCHAR2(1000);            -- 戻りNINNIBIT情報
        VNINIBIT_JOHOTEMP   NVARCHAR2(1000);
        ACONSPRM_NINIBIT    A_CONS_PRM;
        r_WKRECORD002       GKBWL350R002%ROWTYPE;
        nROWNO              NUMBER := 0;

    BEGIN
        ACONSPRM_NINIBIT := A_CONS_PRM();
        ACONSPRM_NINIBIT.EXTEND;
        FOR I IN 1..20 LOOP
           ACONSPRM_NINIBIT.EXTEND;
           ACONSPRM_NINIBIT(I) := NULL;
        END LOOP;
        FRET := c_ISUCCESS;                  -- 正常終了
        IMAX := MJIDO_WORK.LAST;             -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;            -- ワーク領域の件数の最小値

        -- 取得した件数分繰り返す
        FOR ICNT IN IMIN..IMAX LOOP
            nROWNO                             := nROWNO+1;
            r_WKRECORD002                      := NULL;
            r_WKRECORD002.No                   := nROWNO;
            r_WKRECORD002.NENDO                := MJIDO_WORK(ICNT).NENDO;
            r_WKRECORD002.GAKKOKU_CD           := MJIDO_WORK(ICNT).KAIPEJI_CD;
            r_WKRECORD002.GAKKO_MEI_HYOJI      := MJIDO_WORK(ICNT).KAIPEJI;
            r_WKRECORD002.GAKUNEN              := MJIDO_WORK(ICNT).GAKUNENMEI;
            r_WKRECORD002.GENZAIBI             := MJIDO_WORK(ICNT).SAKUSEIBI;
            r_WKRECORD002.NUM                  := MJIDO_WORK(ICNT).RENBAN;
            r_WKRECORD002.SHIMEI_KANA          := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;
            r_WKRECORD002.SHIMEI               := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;
            r_WKRECORD002.SEIBETSU             := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;
            r_WKRECORD002.HOGOSHA_SHIMEI_KANA  := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;
            r_WKRECORD002.HOGOSHA_SHIMEI_KANJI := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;
            r_WKRECORD002.ZOKUGARAMEI1         := MJIDO_WORK(ICNT).ZOKUGARAMEI1;
            r_WKRECORD002.ZOKUGARAMEI2         := MJIDO_WORK(ICNT).ZOKUGARAMEI2;
            r_WKRECORD002.SEINENGAPI           := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;
            r_WKRECORD002.JUSHO_JODAN          := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;
            r_WKRECORD002.JUSHO_GEDAN          := MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;
            r_WKRECORD002.GYOSEIKU_MEI         := MJIDO_WORK(ICNT).GYOSEIKUMEI;
            r_WKRECORD002.KIJUNBI              := KIJUN_BI;

            ACONSPRM_NINIBIT(1)  := MJIDO_WORK(ICNT).NINIBIT1;
            ACONSPRM_NINIBIT(2)  := MJIDO_WORK(ICNT).NINIBIT2;
            ACONSPRM_NINIBIT(3)  := MJIDO_WORK(ICNT).NINIBIT3;
            ACONSPRM_NINIBIT(4)  := MJIDO_WORK(ICNT).NINIBIT4;
            ACONSPRM_NINIBIT(5)  := MJIDO_WORK(ICNT).NINIBIT5;
            ACONSPRM_NINIBIT(6)  := MJIDO_WORK(ICNT).NINIBIT6;
            ACONSPRM_NINIBIT(7)  := MJIDO_WORK(ICNT).NINIBIT7;
            ACONSPRM_NINIBIT(8)  := MJIDO_WORK(ICNT).NINIBIT8;
            ACONSPRM_NINIBIT(9)  := MJIDO_WORK(ICNT).NINIBIT9;
            ACONSPRM_NINIBIT(10) := MJIDO_WORK(ICNT).NINIBIT10;
            ACONSPRM_NINIBIT(11) := MJIDO_WORK(ICNT).NINIBIT11;
            ACONSPRM_NINIBIT(12) := MJIDO_WORK(ICNT).NINIBIT12;
            ACONSPRM_NINIBIT(13) := MJIDO_WORK(ICNT).NINIBIT13;
            ACONSPRM_NINIBIT(14) := MJIDO_WORK(ICNT).NINIBIT14;
            ACONSPRM_NINIBIT(15) := MJIDO_WORK(ICNT).NINIBIT15;
            ACONSPRM_NINIBIT(16) := MJIDO_WORK(ICNT).NINIBIT16;
            ACONSPRM_NINIBIT(17) := MJIDO_WORK(ICNT).NINIBIT17;
            ACONSPRM_NINIBIT(18) := MJIDO_WORK(ICNT).NINIBIT18;
            ACONSPRM_NINIBIT(19) := MJIDO_WORK(ICNT).NINIBIT19;
            ACONSPRM_NINIBIT(20) := MJIDO_WORK(ICNT).NINIBIT20;

            VNINIBIT_JOHO := NULL;
--             FOR N IN 1..20 LOOP
--             ININIBIT_RET := GKBPK00010.FGETNMS(N-1,o_TITLE,o_NINIMEISHO);
--               IF ACONSPRM_NINIBIT(N) > 0 THEN
--                  VNINIBITMEISHO := o_NINIMEISHO(ACONSPRM_NINIBIT(N));
--                  IF VNINIBITMEISHO IS NOT NULL AND VNINIBITMEISHO <> ' ' THEN
--                     VNINIBIT_JOHOTEMP := o_TITLE || '・' || VNINIBITMEISHO;
--                     IF VNINIBIT_JOHO IS NULL THEN
--                        VNINIBIT_JOHO := VNINIBIT_JOHOTEMP;
--                     ELSE
--                         VNINIBIT_JOHO := VNINIBIT_JOHO || ' ' || VNINIBIT_JOHOTEMP;
--                     END IF;
--                  END IF;
--                END IF;
--             END LOOP;
            r_WKRECORD002.NINBIT_JOHO          := VNINIBIT_JOHO;
            r_WKRECORD002.JINKAKU_KBN          := MJIDO_WORK(ICNT).JINKAKU_KBN;
            r_WKRECORD002.JUSHO_JODAN1         := NULL;
            r_WKRECORD002.BREAK_NO             := NULL;
            r_WKRECORD002.WSNUM                := g_sWSNUM;
            r_WKRECORD002.BATCHKBN             := c_BATCH;
            r_WKRECORD002.JOBNUM               := g_nJOBNUM;

            INSERT INTO GKBWL350R002 VALUES r_WKRECORD002;
        END LOOP;
        -- 終了
        RETURN FRET;
    EXCEPTION
        WHEN OTHERS THEN
            FRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE;
    --------------------------------------------------------------------------------
    -- 児童生徒集計表（GKBWJIDOZAIGAKU）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SEITOSHUKEI_CSV_CREATE RETURN NUMBER IS
        FRET                 PLS_INTEGER;                -- 戻り値
--  2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応     
        --NGAKOKU_CD           NUMBER:= NULL;              -- 学校コード
        --NGAKUNEN_CD          NUMBER:= NULL;              -- 学年コード
        NGAKOKU_CD           NUMBER:= 0;              -- 学校コード
        NGAKUNEN_CD          NUMBER:= 0;              -- 学年コード
--  2025/05/16 CTC.HJF UPDATE End   
-- 2024/07/12 ZCZL.qinyue Delete start 0.3.000.000:新WizLIFE2次開発
--         IBIT11CNT_1          PLS_INTEGER:= 0;         -- １年　障害・知的の数
--         IBIT12CNT_1          PLS_INTEGER:= 0;         -- １年　障害・肢体の数
--         IBIT13CNT_1          PLS_INTEGER:= 0;         -- １年　障害・病弱の数
--         IBIT14CNT_1          PLS_INTEGER:= 0;         -- １年　障害・院内の数
--         IBIT15CNT_1          PLS_INTEGER:= 0;         -- １年　障害・弱視の数
--         IBIT16CNT_1          PLS_INTEGER:= 0;         -- １年　障害・難聴の数
--         IBIT17CNT_1          PLS_INTEGER:= 0;         -- １年　障害・言語の数
--         IBIT18CNT_1          PLS_INTEGER:= 0;         -- １年　障害・情緒の数
--         IBIT2CNT_1           PLS_INTEGER:= 0;         -- １年　外国人の数
--         IBIT3CNT_1           PLS_INTEGER:= 0;         -- １年　下学年の数
--         IMALECNT_1           PLS_INTEGER:= 0;         -- １年　男子計
--         IFEMALECNT_1         PLS_INTEGER:= 0;         -- １年　女子計
--         IMALE_FEMALE_CNT1    PLS_INTEGER:= 0;         -- １年　男女計
--         IFUTSU_GAKYU_1       PLS_INTEGER:= 0;         -- １年　普通学級の数
-- 
--         IBIT11CNT_2          PLS_INTEGER:= 0;         -- 2年　障害・知的の数
--         IBIT12CNT_2          PLS_INTEGER:= 0;         -- 2年　障害・肢体の数
--         IBIT13CNT_2          PLS_INTEGER:= 0;         -- 2年　障害・病弱の数
--         IBIT14CNT_2          PLS_INTEGER:= 0;         -- 2年　障害・院内の数
--         IBIT15CNT_2          PLS_INTEGER:= 0;         -- 2年　障害・弱視の数
--         IBIT16CNT_2          PLS_INTEGER:= 0;         -- 2年　障害・難聴の数
--         IBIT17CNT_2          PLS_INTEGER:= 0;         -- 2年　障害・言語の数
--         IBIT18CNT_2          PLS_INTEGER:= 0;         -- 2年　障害・情緒の数
--         IBIT2CNT_2           PLS_INTEGER:= 0;         -- 2年　外国人の数
--         IBIT3CNT_2           PLS_INTEGER:= 0;         -- 2年　下学年の数
--         IMALECNT_2           PLS_INTEGER:= 0;         -- 2年　男子計
--         IFEMALECNT_2         PLS_INTEGER:= 0;         -- 2年　女子計
--         IMALE_FEMALE_CNT2    PLS_INTEGER:= 0;         -- 2年　男女計
--         IFUTSU_GAKYU_2       PLS_INTEGER:= 0;         -- 2年　普通学級の数
-- 
--         IBIT11CNT_3          PLS_INTEGER:= 0;         -- 3年　障害・知的の数
--         IBIT12CNT_3          PLS_INTEGER:= 0;         -- 3年　障害・肢体の数
--         IBIT13CNT_3          PLS_INTEGER:= 0;         -- 3年　障害・病弱の数
--         IBIT14CNT_3          PLS_INTEGER:= 0;         -- 3年　障害・院内の数
--         IBIT15CNT_3          PLS_INTEGER:= 0;         -- 3年　障害・弱視の数
--         IBIT16CNT_3          PLS_INTEGER:= 0;         -- 3年　障害・難聴の数
--         IBIT17CNT_3          PLS_INTEGER:= 0;         -- 3年　障害・言語の数
--         IBIT18CNT_3          PLS_INTEGER:= 0;         -- 3年　障害・情緒の数
--         IBIT2CNT_3           PLS_INTEGER:= 0;         -- 3年　外国人の数
--         IBIT3CNT_3           PLS_INTEGER:= 0;         -- 3年　下学年の数
--         IMALECNT_3           PLS_INTEGER:= 0;         -- 3年　男子計
--         IFEMALECNT_3         PLS_INTEGER:= 0;         -- 3年　女子計
--         IMALE_FEMALE_CNT3    PLS_INTEGER:= 0;         -- 3年　男女計
--         IFUTSU_GAKYU_3       PLS_INTEGER:= 0;         -- 3年　普通学級の数
-- 
--         IBIT11CNT_4          PLS_INTEGER:= 0;         -- 4年　障害・知的の数
--         IBIT12CNT_4          PLS_INTEGER:= 0;         -- 4年　障害・肢体の数
--         IBIT13CNT_4          PLS_INTEGER:= 0;         -- 4年　障害・病弱の数
--         IBIT14CNT_4          PLS_INTEGER:= 0;         -- 4年　障害・院内の数
--         IBIT15CNT_4          PLS_INTEGER:= 0;         -- 4年　障害・弱視の数
--         IBIT16CNT_4          PLS_INTEGER:= 0;         -- 4年　障害・難聴の数
--         IBIT17CNT_4          PLS_INTEGER:= 0;         -- 4年　障害・言語の数
--         IBIT18CNT_4          PLS_INTEGER:= 0;         -- 4年　障害・情緒の数
--         IBIT2CNT_4           PLS_INTEGER:= 0;         -- 4年　外国人の数
--         IBIT3CNT_4           PLS_INTEGER:= 0;         -- 4年　下学年の数
--         IMALECNT_4           PLS_INTEGER:= 0;         -- 4年　男子計
--         IFEMALECNT_4         PLS_INTEGER:= 0;         -- 4年　女子計
--         IMALE_FEMALE_CNT4    PLS_INTEGER:= 0;         -- 4年　男女計
--         IFUTSU_GAKYU_4       PLS_INTEGER:= 0;         -- 4年　普通学級の数
-- 
--         IBIT11CNT_5          PLS_INTEGER:= 0;         -- 5年　障害・知的の数
--         IBIT12CNT_5          PLS_INTEGER:= 0;         -- 5年　障害・肢体の数
--         IBIT13CNT_5          PLS_INTEGER:= 0;         -- 5年　障害・病弱の数
--         IBIT14CNT_5          PLS_INTEGER:= 0;         -- 5年　障害・院内の数
--         IBIT15CNT_5          PLS_INTEGER:= 0;         -- 5年　障害・弱視の数
--         IBIT16CNT_5          PLS_INTEGER:= 0;         -- 5年　障害・難聴の数
--         IBIT17CNT_5          PLS_INTEGER:= 0;         -- 5年　障害・言語の数
--         IBIT18CNT_5          PLS_INTEGER:= 0;         -- 5年　障害・情緒の数
--         IBIT2CNT_5           PLS_INTEGER:= 0;         -- 5年　外国人の数
--         IBIT3CNT_5           PLS_INTEGER:= 0;         -- 5年　下学年の数
--         IMALECNT_5           PLS_INTEGER:= 0;         -- 5年　男子計
--         IFEMALECNT_5         PLS_INTEGER:= 0;         -- 5年　女子計
--         IMALE_FEMALE_CNT5    PLS_INTEGER:= 0;          --5年　男女計
--         IFUTSU_GAKYU_5       PLS_INTEGER:= 0;         -- 5年　普通学級の数
-- 
--         IBIT11CNT_6          PLS_INTEGER:= 0;         -- 6年　障害・知的の数
--         IBIT12CNT_6          PLS_INTEGER:= 0;         -- 6年　障害・肢体の数
--         IBIT13CNT_6          PLS_INTEGER:= 0;         -- 6年　障害・病弱の数
--         IBIT14CNT_6          PLS_INTEGER:= 0;         -- 6年　障害・院内の数
--         IBIT15CNT_6          PLS_INTEGER:= 0;         -- 6年　障害・弱視の数
--         IBIT16CNT_6          PLS_INTEGER:= 0;         -- 6年　障害・難聴の数
--         IBIT17CNT_6          PLS_INTEGER:= 0;         -- 6年　障害・言語の数
--         IBIT18CNT_6          PLS_INTEGER:= 0;         -- 6年　障害・情緒の数
--         IBIT2CNT_6           PLS_INTEGER:= 0;         -- 6年　外国人の数
--         IBIT3CNT_6           PLS_INTEGER:= 0;         -- 6年　下学年の数
--         IMALECNT_6           PLS_INTEGER:= 0;         -- 6年　男子計
--         IFEMALECNT_6         PLS_INTEGER:= 0;         -- 6年　女子計
--         IMALE_FEMALE_CNT6    PLS_INTEGER:= 0;         -- 6年　男女計
--         IFUTSU_GAKYU_6       PLS_INTEGER:= 0;         -- 6年　普通学級の数
--         IMALECNT             PLS_INTEGER:= 0;         -- 男子計
--         IFEMALECNT           PLS_INTEGER:= 0;         -- 女子計
--         IMALE_FEMALE_CNT     PLS_INTEGER:= 0;         -- 男女計
--         IFUTSU_GAKYU         PLS_INTEGER:= 0;         -- 普通学級の合計
--         IBIT11CNT            PLS_INTEGER:= 0;         -- 障害・知的の数
--         IBIT12CNT            PLS_INTEGER:= 0;         -- 障害・肢体の数
--         IBIT13CNT            PLS_INTEGER:= 0;         -- 障害・病弱の数
--         IBIT14CNT            PLS_INTEGER:= 0;         -- 障害・院内の数
--         IBIT15CNT            PLS_INTEGER:= 0;         -- 障害・弱視の数
--         IBIT16CNT            PLS_INTEGER:= 0;         -- 障害・難聴の数
--         IBIT17CNT            PLS_INTEGER:= 0;         -- 障害・言語の数
--         IBIT18CNT            PLS_INTEGER:= 0;         -- 障害・情緒の数
--         IBIT2CNT             PLS_INTEGER:= 0;         -- 外国人合計
--         IBIT3CNT             PLS_INTEGER:= 0;         -- 下学年合計
--         IBITSUM              PLS_INTEGER:= 0;         -- 障害合計
--         IJIDOSUM             PLS_INTEGER:= 0;         -- 児童合計
--         ITOKU_GAKYU          PLS_INTEGER:= 0;         -- 障害児学級数合計
--         IFUSTUS_TOKU_SUM     PLS_INTEGER:= 0;         -- 普通、障害児学級数合計
-- 2024/07/12 ZCZL.qinyue Delete end
-- 2024/07/12 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
--  2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
           --IMALE1               PLS_INTEGER:= 0;         --１年男の数
           --IMALE2               PLS_INTEGER:= 0;         --２年男の数
           --IMALE3               PLS_INTEGER:= 0;         --３年男の数
           --IMALE4               PLS_INTEGER:= 0;         --４年男の数
           --IMALE5               PLS_INTEGER:= 0;         --５年男の数
           --IMALE6               PLS_INTEGER:= 0;         --６年男の数
           --IMALEALL             PLS_INTEGER:= 0;         --男子計
           --IFEMALE1             PLS_INTEGER:= 0;         --１年女の数
           --IFEMALE2             PLS_INTEGER:= 0;         --２年女の数
           --IFEMALE3             PLS_INTEGER:= 0;         --３年女の数
           --IFEMALE4             PLS_INTEGER:= 0;         --４年女の数
           --IFEMALE5             PLS_INTEGER:= 0;         --５年女の数
           --IFEMALE6             PLS_INTEGER:= 0;         --６年女の数
           --IFEMALEALL           PLS_INTEGER:= 0;         --女子計
           --IMALEFEMALE1         PLS_INTEGER:= 0;         --１年男女の数
           --IMALEFEMALE2         PLS_INTEGER:= 0;         --２年男女の数
           --IMALEFEMALE3         PLS_INTEGER:= 0;         --３年男女の数
           --IMALEFEMALE4         PLS_INTEGER:= 0;         --４年男女の数
           --IMALEFEMALE5         PLS_INTEGER:= 0;         --５年男女の数
           --IMALEFEMALE6         PLS_INTEGER:= 0;         --６年男女の数
--  2025/05/16 CTC.HJF Delete End
           nRTN                 NUMBER;                  --戻り値
           aPRM                 A_CONS_PRM;
           VOAZANM              NVARCHAR2(1000);         --大字名
           VGYOSEIKU            NVARCHAR2(1000);         --行政区名称 
           sMEISHO              NVARCHAR2(1000);         --名称
           sMEISHOKANA          NVARCHAR2(1000);         --名称カナ
           sYOBI                NVARCHAR2(1000);         --予備  
-- 2024/07/12 ZCZL.qinyue Add end
        NCNT                 NUMBER:= 0;              -- LOOP回数
        nROWNO               NUMBER := 0;
        r_WKRECORD001        GKBWL350R001%ROWTYPE;
--  2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応
           MALE1         NUMBER :=0;         --１年男の数
           MALE2         NUMBER :=0;         --２年男の数
           MALE3         NUMBER :=0;         --３年男の数
           MALE4         NUMBER :=0;         --４年男の数
           MALE5         NUMBER :=0;         --５年男の数
           MALE6         NUMBER :=0;         --６年男の数
           MALEALL       NUMBER :=0;         --男子計

           FEMALE1       NUMBER := 0;        --１年女の数
           FEMALE2       NUMBER := 0;        --２年女の数
           FEMALE3       NUMBER := 0;        --３年女の数
           FEMALE4       NUMBER := 0;        --４年女の数
           FEMALE5       NUMBER := 0;        --５年女の数
           FEMALE6       NUMBER := 0;        --６年女の数
           FEMALEALL     NUMBER := 0;        --女子計

           FUTSUMALE1    NUMBER := 0;        --１普通学級１年男の数
           FUTSUMALE2    NUMBER := 0;        --２普通学級２年男の数
           FUTSUMALE3    NUMBER := 0;        --３普通学級３年男の数
           FUTSUMALE4    NUMBER := 0;        --４普通学級４年男の数
           FUTSUMALE5    NUMBER := 0;        --５普通学級５年男の数
           FUTSUMALE6    NUMBER := 0;        --６普通学級６年男の数
           FUTSUMALEALL  NUMBER := 0;        --普通学級男子計

           FUTSUFEMALE1  NUMBER := 0;        --普通学級１年女の数
           FUTSUFEMALE2  NUMBER := 0;        --普通学級２年女の数
           FUTSUFEMALE3  NUMBER := 0;        --普通学級３年女の数
           FUTSUFEMALE4  NUMBER := 0;        --普通学級４年女の数
           FUTSUFEMALE5  NUMBER := 0;        --普通学級５年女の数
           FUTSUFEMALE6  NUMBER := 0;        --普通学級６年女の数
           FUTSUFEMALEALL NUMBER := 0;       --普通学級女子計

           TOKUBETSUMALE1 NUMBER := 0;       --特別支援学級１年男の数
           TOKUBETSUMALE2 NUMBER := 0;       --特別支援学級２年男の数
           TOKUBETSUMALE3 NUMBER := 0;       --特別支援学級３年男の数
           TOKUBETSUMALE4 NUMBER := 0;       --特別支援学級４年男の数
           TOKUBETSUMALE5 NUMBER := 0;       --特別支援学級５年男の数
           TOKUBETSUMALE6 NUMBER := 0;       --特別支援学級６年男の数
           TOKUBETSUMALEALL NUMBER := 0;     --特別支援学級男子計

           TOKUBETSUFEMALE1 NUMBER := 0;     --特別支援学級１年女の数
           TOKUBETSUFEMALE2 NUMBER := 0;     --特別支援学級２年女の数
           TOKUBETSUFEMALE3 NUMBER := 0;     --特別支援学級３年女の数
           TOKUBETSUFEMALE4 NUMBER := 0;     --特別支援学級４年女の数
           TOKUBETSUFEMALE5 NUMBER := 0;     --特別支援学級５年女の数
           TOKUBETSUFEMALE6 NUMBER := 0;     --特別支援学級６年女の数
           TOKUBETSUFEMALEALL NUMBER := 0;   --特別支援学級女子計

           MALEFEMALE1   NUMBER:= 0;         --１年男女の数
           MALEFEMALE2   NUMBER:= 0;         --２年男女の数
           MALEFEMALE3   NUMBER:= 0;         --３年男女の数
           MALEFEMALE4   NUMBER :=0;         --４年男女の数
           MALEFEMALE5   NUMBER:= 0;         --５年男女の数
           MALEFEMALE6   NUMBER :=0;         --６年男女の数
--  2025/05/16 CTC.HJF UPDATE End
--  2025/06/11 CTC.HJF UPDATE Start 1.0.008.000:GKB_QA15686対応
           KAIPAGEFLAG   NUMBER :=0;
--  2025/06/11 CTC.HJF UPDATE End
--  2024/09/02 ZCZL.WANGMING UPDATE START 0.3.000.002:8月1日認識合わせの横展開
--      CURSOR CUR_WK_JIDO_ZAIGAKI IS
--        SELECT
--              GAKOKU_CD                                                                  --学校コード
---- 2024/07/12 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
----              ,MAX(GAKOKUMEI) GAKOKUMEI                                                   --学校名
--             ,GAKOKUMEI
---- 2024/07/12 ZCZL.qinyue Update end
--             ,GAKUNEN_CD                                                                 --学年
---- 2024/07/12 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
--             ,OAZA_CD                -- 大字コード
--             ,SHOGAKKO_CD            -- 小学校コード
--             ,CHUGAKKO_CD            -- 中学校コード
--             ,KUIKIGAI_CD            -- 区域外学校コード
--             ,YOGOGAKO_CD            -- 盲聾養護学校コード
--             ,KUNISHIRITSU_CD        -- 国私立学校コード
--             ,GAKUKYU_KBN            -- 学級区分
--             ,GAKKO_KBN_CD           -- 学校区分コード
--             ,SHOGAKKOKU_CD          -- 小学校区コード
--             ,CHUGAKKOKU_CD          -- 中学校区コード
--             ,GYOSEIKU_CD            -- 行政区コード
--             ,SANTEIDANTAI_CD        -- 算定団体コード            
---- 2024/07/12 ZCZL.qinyue Add end     
---- 2024/07/12 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発                
----              ,SUM(DECODE(HYOJI_SEIBETSU,'男',DECODE(NINIBIT1,0,1,0),0))  MALECNT         --男の数
----              ,SUM(DECODE(HYOJI_SEIBETSU,'女',DECODE(NINIBIT1,0,1,0),0))  FEMALECNT       --女の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) AND SEIBETSU = 1)) MALE1    --１年男の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) AND SEIBETSU = 1)) MALE2    --２年男の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) AND SEIBETSU = 1)) MALE3    --３年男の数 
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 1)) MALE4                       --４年男の数    
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 1)) MALE5                       --５年男の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 1)) MALE6                       --６年男の数   
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) AND SEIBETSU = 1)) MALEALL      --男子計                     
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) AND SEIBETSU = 2)) FEMALE1    --１年女の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) AND SEIBETSU = 2)) FEMALE2    --２年女の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) AND SEIBETSU = 2)) FEMALE3    --３年女の数 
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 2)) FEMALE4                       --４年女の数    
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 2)) FEMALE5                       --５年女の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 2)) FEMALE6                       --６年女の数   
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) AND SEIBETSU = 2)) FEMALEALL      --女子計   
--             --普通学級     
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) 
--                   AND SEIBETSU = 1 AND GAKUKYU_KBN = 0 )) FUTSUMALE1    --普通学級１年男の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) 
--                   AND SEIBETSU = 1 AND GAKUKYU_KBN = 0 )) FUTSUMALE2    --普通学級２年男の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) 
--                   AND SEIBETSU = 1 AND GAKUKYU_KBN = 0 )) FUTSUMALE3    --普通学級３年男の数 
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 1 
--                   AND GAKUKYU_KBN = 0 )) FUTSUMALE4                       --普通学級４年男の数    
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 1 
--                   AND GAKUKYU_KBN = 0 )) FUTSUMALE5                       --普通学級５年男の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 1 
--                   AND GAKUKYU_KBN = 0 )) FUTSUMALE6                       --普通学級６年男の数   
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) 
--                   AND SEIBETSU = 1
--                   AND GAKUKYU_KBN = 0)) FUTSUMALEALL                          --普通学級男子計                    
--              ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) 
--                   AND SEIBETSU = 2 AND GAKUKYU_KBN = 0 )) FUTSUFEMALE1    --普通学級１年女の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) 
--                   AND SEIBETSU = 2 AND GAKUKYU_KBN = 0 )) FUTSUFEMALE2    --普通学級２年女の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) 
--                   AND SEIBETSU = 2 AND GAKUKYU_KBN = 0 )) FUTSUFEMALE3    --普通学級３年女の数 
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 2 
--                   AND GAKUKYU_KBN = 0 )) FUTSUFEMALE4                       --普通学級４年女の数    
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 2 
--                   AND GAKUKYU_KBN = 0 )) FUTSUFEMALE5                       --普通学級５年女の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 2 
--                   AND GAKUKYU_KBN = 0 )) FUTSUFEMALE6                       --普通学級６年女の数   
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) 
--                   AND SEIBETSU = 2
--                   AND GAKUKYU_KBN = 0)) FUTSUFEMALEALL                      --普通学級女子計          
--             --特別支援学級      
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) 
--                   AND SEIBETSU = 1 AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE1    --特別支援学級１年男の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) 
--                   AND SEIBETSU = 1 AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE2    --特別支援学級２年男の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) 
--                   AND SEIBETSU = 1 AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE3    --特別支援学級３年男の数 
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 1 
--                   AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE4                       --特別支援学級４年男の数    
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 1 
--                   AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE5                       --特別支援学級５年男の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 1 
--                   AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE6                       --特別支援学級６年男の数   
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) 
--                   AND SEIBETSU = 1
--                   AND GAKUKYU_KBN = 1)) TOKUBETSUMALEALL                      --特別支援学級男子計                   
--              ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) 
--                   AND SEIBETSU = 2 AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE1    --特別支援学級１年女の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) 
--                   AND SEIBETSU = 2 AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE2    --特別支援学級２年女の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) 
--                   AND SEIBETSU = 2 AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE3    --特別支援学級３年女の数 
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 2 
--                   AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE4                       --特別支援学級４年女の数    
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 2 
--                   AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE5                       --特別支援学級５年女の数
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 2 
--                   AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE6                       --特別支援学級６年女の数   
--             ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU
--                   WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) 
--                   AND SEIBETSU = 2
--                   AND GAKUKYU_KBN = 1)) TOKUBETSUFEMALEALL                      --特別支援学級女子計                              
---- 2024/07/12 ZCZL.qinyue Update end
---- 2024/07/12 ZCZL.qinyue Delete start 0.3.000.000:新WizLIFE2次開発
----              ,SUM(DECODE(NINIBIT1,1,1,0))           BIT11CNT        -- 任意ビット１＝1の数（知的）
----              ,SUM(DECODE(NINIBIT1,2,1,0))           BIT12CNT        -- 任意ビット１＝2の数（肢体）
----              ,SUM(DECODE(NINIBIT1,3,1,0))           BIT13CNT        -- 任意ビット１＝3の数（病弱）
----              ,SUM(DECODE(NINIBIT1,4,1,0))           BIT14CNT        -- 任意ビット１＝4の数（院内）
----              ,SUM(DECODE(NINIBIT1,5,1,0))           BIT15CNT        -- 任意ビット１＝5の数（弱視）
----              ,SUM(DECODE(NINIBIT1,6,1,0))           BIT16CNT        -- 任意ビット１＝6の数（難聴）
----              ,SUM(DECODE(NINIBIT1,7,1,0))           BIT17CNT        -- 任意ビット１＝7の数（言語）
----              ,SUM(DECODE(NINIBIT1,8,1,0))           BIT18CNT        -- 任意ビット１＝8の数（情緒）
----              ,SUM(DECODE(NINIBIT2,1,1,0))           BIT2CNT         -- 任意ビット２＝1の数（外国人）
----              ,SUM(DECODE(NINIBIT3,0,0,1))           BIT3CNT         -- 任意ビット３＞0の数（下学年）
---- 2024/07/12 ZCZL.qinyue Delete end
--        FROM GKBWJIDOZAIGAKU
---- 2024/07/12 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
----         GROUP BY GAKOKU_CD,GAKUNEN_CD
----         ORDER BY GAKOKU_CD,GAKUNEN_CD;
--           GROUP BY 
----  2024/09/02 ZCZL.WANGMING UPDATE Start 0.3.000.002:8月1日認識合わせの横展開
----             GAKOKU_CD                                                                  
----             ,GAKOKUMEI
----             ,GAKUNEN_CD                                                                
----             ,OAZA_CD
----             ,SHOGAKKO_CD
----             ,CHUGAKKO_CD
----             ,KUIKIGAI_CD
----             ,YOGOGAKO_CD
----             ,KUNISHIRITSU_CD
----             ,GAKUKYU_KBN
----             ,GAKKO_KBN_CD
----             ,SHOGAKKOKU_CD
----             ,CHUGAKKOKU_CD
----             ,GYOSEIKU_CD
----             ,SANTEIDANTAI_CD
--             GYOSEIKU_CD
--             ,GAKOKUMEI
--             ,SANTEIDANTAI_CD
--             ,OAZA_CD
--             ,GAKOKU_CD
--             ,SHOGAKKOKU_CD
--             ,CHUGAKKOKU_CD
--             ,GAKKO_KBN_CD
--             ,SHOGAKKO_CD
--             ,CHUGAKKO_CD
--             ,KUIKIGAI_CD
--             ,YOGOGAKO_CD
--             ,KUNISHIRITSU_CD
--             ,GAKUKYU_KBN
--             ,GAKUNEN_CD
----  2024/09/02 ZCZL.WANGMING UPDATE End
--           ORDER BY g_rJSTP.Orderbyclause;
---- 2024/07/12 ZCZL.qinyue Update end
     TYPE typeWJIDOZAIGAKU IS RECORD (
          GAKOKU_CD    GKBWJIDOZAIGAKU.GAKOKU_CD%TYPE,
          GAKOKUMEI    GKBWJIDOZAIGAKU.GAKOKUMEI%TYPE,
          GAKUNEN_CD    GKBWJIDOZAIGAKU.GAKUNEN_CD%TYPE,
          OAZA_CD    GKBWJIDOZAIGAKU.OAZA_CD%TYPE,
          SHOGAKKO_CD    GKBWJIDOZAIGAKU.SHOGAKKO_CD%TYPE,
          CHUGAKKO_CD    GKBWJIDOZAIGAKU.CHUGAKKO_CD%TYPE,
          KUIKIGAI_CD    GKBWJIDOZAIGAKU.KUIKIGAI_CD%TYPE,
          YOGOGAKO_CD    GKBWJIDOZAIGAKU.YOGOGAKO_CD%TYPE,
          KUNISHIRITSU_CD    GKBWJIDOZAIGAKU.KUNISHIRITSU_CD%TYPE,
          GAKUKYU_KBN    GKBWJIDOZAIGAKU.GAKUKYU_KBN%TYPE,
          GAKKO_KBN_CD    GKBWJIDOZAIGAKU.GAKKO_KBN_CD%TYPE,
          SHOGAKKOKU_CD    GKBWJIDOZAIGAKU.SHOGAKKOKU_CD%TYPE,
          CHUGAKKOKU_CD    GKBWJIDOZAIGAKU.CHUGAKKOKU_CD%TYPE,
          GYOSEIKU_CD    GKBWJIDOZAIGAKU.GYOSEIKU_CD%TYPE,
          SANTEIDANTAI_CD    GKBWJIDOZAIGAKU.SANTEIDANTAI_CD%TYPE
--  2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
          --MALE1  NUMBER,
          --MALE2  NUMBER,
          --MALE3  NUMBER,
          --MALE4  NUMBER,
          --MALE5  NUMBER,
          --MALE6  NUMBER,
          --MALEALL  NUMBER,
          --FEMALE1  NUMBER,
          --FEMALE2  NUMBER,
          --FEMALE3  NUMBER,
          --FEMALE4  NUMBER,
          --FEMALE5  NUMBER,
          --FEMALE6  NUMBER,
          --FEMALEALL  NUMBER,
          --FUTSUMALE1  NUMBER,
          --FUTSUMALE2  NUMBER,
          --FUTSUMALE3  NUMBER,
          --FUTSUMALE4  NUMBER,
          --FUTSUMALE5  NUMBER,
          --FUTSUMALE6  NUMBER,
          --FUTSUMALEALL  NUMBER,
          --FUTSUFEMALE1  NUMBER,
          --FUTSUFEMALE2  NUMBER,
          --FUTSUFEMALE3  NUMBER,
          --FUTSUFEMALE4  NUMBER,
          --FUTSUFEMALE5  NUMBER,
          --FUTSUFEMALE6  NUMBER,
          --FUTSUFEMALEALL  NUMBER,
          --TOKUBETSUMALE1  NUMBER,
          --TOKUBETSUMALE2  NUMBER,
          --TOKUBETSUMALE3  NUMBER,
          --TOKUBETSUMALE4  NUMBER,
          --TOKUBETSUMALE5  NUMBER,
          --TOKUBETSUMALE6  NUMBER,
          --TOKUBETSUMALEALL  NUMBER,
          --TOKUBETSUFEMALE1  NUMBER,
          --TOKUBETSUFEMALE2  NUMBER,
          --TOKUBETSUFEMALE3  NUMBER,
          --TOKUBETSUFEMALE4  NUMBER,
          --TOKUBETSUFEMALE5  NUMBER,
          --TOKUBETSUFEMALE6  NUMBER,
          --TOKUBETSUFEMALEALL NUMBER
--  2025/05/16 CTC.HJF Delete End
      ); 
      CUR1 typeWJIDOZAIGAKU;
      TYPE cur_REF IS REF CURSOR;
      CUR_WK_JIDO_ZAIGAKI    cur_REF;
      vSQL         NVARCHAR2(30000);     --SQL文
--  2024/09/02 ZCZL.WANGMING UPDATE END
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        BEGIN
          --  2024/09/02 ZCZL.WANGMING UPDATE START 0.3.000.002:8月1日認識合わせの横展開
          --FOR CUR1 IN CUR_WK_JIDO_ZAIGAKI LOOP
          vSQL := '';
          vSQL := vSQL || ' SELECT';
          vSQL := vSQL || '      GAKOKU_CD';
          vSQL := vSQL || '     ,GAKOKUMEI';
          vSQL := vSQL || '     ,GAKUNEN_CD';
          vSQL := vSQL || '     ,OAZA_CD';
          vSQL := vSQL || '     ,SHOGAKKO_CD';
          vSQL := vSQL || '     ,CHUGAKKO_CD';
          vSQL := vSQL || '     ,KUIKIGAI_CD';
          vSQL := vSQL || '     ,YOGOGAKO_CD';
          vSQL := vSQL || '     ,KUNISHIRITSU_CD';
          vSQL := vSQL || '     ,GAKUKYU_KBN';
          vSQL := vSQL || '     ,GAKKO_KBN_CD';
          vSQL := vSQL || '     ,SHOGAKKOKU_CD';
          vSQL := vSQL || '     ,CHUGAKKOKU_CD';
          vSQL := vSQL || '     ,GYOSEIKU_CD';
          vSQL := vSQL || '     ,SANTEIDANTAI_CD';
--  2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) AND SEIBETSU = 1)) MALE1';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) AND SEIBETSU = 1)) MALE2';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) AND SEIBETSU = 1)) MALE3';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 1)) MALE4';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 1)) MALE5';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 1)) MALE6';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) AND SEIBETSU = 1)) MALEALL';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) AND SEIBETSU = 2)) FEMALE1';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) AND SEIBETSU = 2)) FEMALE2';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) AND SEIBETSU = 2)) FEMALE3';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 2)) FEMALE4';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 2)) FEMALE5';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 2)) FEMALE6';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) AND SEIBETSU = 2)) FEMALEALL';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) ';
          --vSQL := vSQL || '           AND SEIBETSU = 1 AND GAKUKYU_KBN = 0 )) FUTSUMALE1';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) ';
          --vSQL := vSQL || '           AND SEIBETSU = 1 AND GAKUKYU_KBN = 0 )) FUTSUMALE2';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) ';
          --vSQL := vSQL || '           AND SEIBETSU = 1 AND GAKUKYU_KBN = 0 )) FUTSUMALE3';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 1 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 0 )) FUTSUMALE4';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 1 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 0 )) FUTSUMALE5';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 1 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 0 )) FUTSUMALE6';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) ';
          --vSQL := vSQL || '           AND SEIBETSU = 1';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 0)) FUTSUMALEALL';
          --vSQL := vSQL || '      ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) ';
          --vSQL := vSQL || '           AND SEIBETSU = 2 AND GAKUKYU_KBN = 0 )) FUTSUFEMALE1  ';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) ';
          --vSQL := vSQL || '           AND SEIBETSU = 2 AND GAKUKYU_KBN = 0 )) FUTSUFEMALE2  ';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) ';
          --vSQL := vSQL || '           AND SEIBETSU = 2 AND GAKUKYU_KBN = 0 )) FUTSUFEMALE3  ';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 2 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 0 )) FUTSUFEMALE4';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 2 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 0 )) FUTSUFEMALE5';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 2 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 0 )) FUTSUFEMALE6';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) ';
          --vSQL := vSQL || '           AND SEIBETSU = 2';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 0)) FUTSUFEMALEALL             ';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) ';
          --vSQL := vSQL || '           AND SEIBETSU = 1 AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE1';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) ';
          --vSQL := vSQL || '           AND SEIBETSU = 1 AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE2';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) ';
          --vSQL := vSQL || '           AND SEIBETSU = 1 AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE3';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 1 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE4            ';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 1 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE5            ';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 1 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 1 )) TOKUBETSUMALE6            ';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) ';
          --vSQL := vSQL || '           AND SEIBETSU = 1';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 1)) TOKUBETSUMALEALL           ';
          --vSQL := vSQL || '      ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 1 OR GAKUNEN_CD = 7) ';
          --vSQL := vSQL || '           AND SEIBETSU = 2 AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE1';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 2 OR GAKUNEN_CD = 8) ';
          --vSQL := vSQL || '           AND SEIBETSU = 2 AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE2';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ((GAKUNEN_CD = 3 OR GAKUNEN_CD = 9) ';
          --vSQL := vSQL || '           AND SEIBETSU = 2 AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE3';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 4 AND SEIBETSU = 2 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE4';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 5 AND SEIBETSU = 2 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE5 ';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD = 6 AND SEIBETSU = 2 ';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 1 )) TOKUBETSUFEMALE6 ';
          --vSQL := vSQL || '     ,(SELECT COUNT(1) FROM GKBWJIDOZAIGAKU';
          --vSQL := vSQL || '           WHERE ( GAKUNEN_CD IN(1,2,3,4,5,6,7,8,9) ';
          --vSQL := vSQL || '           AND SEIBETSU = 2';
          --vSQL := vSQL || '           AND GAKUKYU_KBN = 1)) TOKUBETSUFEMALEALL ';
--  2025/05/16 CTC.HJF Delete End
          vSQL := vSQL || ' FROM GKBWJIDOZAIGAKU ';
          vSQL := vSQL || '   GROUP BY ';
          vSQL := vSQL || '     GYOSEIKU_CD';
          vSQL := vSQL || '     ,GAKOKUMEI';
          vSQL := vSQL || '     ,SANTEIDANTAI_CD';
          vSQL := vSQL || '     ,OAZA_CD';
          vSQL := vSQL || '     ,GAKOKU_CD';
          vSQL := vSQL || '     ,SHOGAKKOKU_CD';
          vSQL := vSQL || '     ,CHUGAKKOKU_CD';
          vSQL := vSQL || '     ,GAKKO_KBN_CD';
          vSQL := vSQL || '     ,SHOGAKKO_CD';
          vSQL := vSQL || '     ,CHUGAKKO_CD';
          vSQL := vSQL || '     ,KUIKIGAI_CD';
          vSQL := vSQL || '     ,YOGOGAKO_CD';
          vSQL := vSQL || '     ,KUNISHIRITSU_CD';
          vSQL := vSQL || '     ,GAKUKYU_KBN';
          vSQL := vSQL || '     ,GAKUNEN_CD';
          IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
            vSQL := vSQL || ' ORDER BY ' || g_rJSTP.ORDERBYCLAUSE;
          END IF;
         OPEN CUR_WK_JIDO_ZAIGAKI FOR vSQL;
         LOOP
         FETCH CUR_WK_JIDO_ZAIGAKI INTO CUR1;
         EXIT WHEN CUR_WK_JIDO_ZAIGAKI%NOTFOUND;
         --  2024/09/02 ZCZL.WANGMING UPDATE END
--  2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
            --IF NCNT = 0 THEN
            --   NGAKOKU_CD := CUR1.GAKOKU_CD;
            --   NGAKUNEN_CD := CUR1.GAKUNEN_CD;
            --END IF;
--  2025/05/16 CTC.HJF Delete End
            NCNT := NCNT +1; --LOOP回数
            IF NGAKOKU_CD <> CUR1.GAKOKU_CD
--  2025/06/11 CTC.HJF UPDATE Start 1.0.008.000:GKB_QA15686対応
               AND CUR1.GAKUNEN_CD <> 0
--  2025/06/11 CTC.HJF UPDATE End
--  2025/05/16 CTC.HJF ADD Start 1.0.004.000:GKB_QA12945対応
               AND CUR1.GAKKO_KBN_CD <> 0
--  2025/05/16 CTC.HJF ADD End
--  2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
               --OR ( CUR1.GAKUNEN_CD >= 7 AND NGAKUNEN_CD <= 6 )
--  2025/05/16 CTC.HJF Delete End
               OR ( NGAKOKU_CD IS NULL AND CUR1.GAKOKU_CD IS NOT NULL )
               OR ( NGAKOKU_CD IS NOT NULL AND CUR1.GAKOKU_CD IS NULL ) THEN
               NGAKOKU_CD := CUR1.GAKOKU_CD;
               NGAKUNEN_CD := CUR1.GAKUNEN_CD;
--2024/07/12 ZCZL.qinyue Delete start 0.3.000.000:新WizLIFE2次開発
--               --データ初期化
--                IMALECNT_1   := 0;        -- １年　男子計
--                IFEMALECNT_1 := 0;        -- １年　女子計
--                IBIT11CNT_1  := 0;        -- １年　障害・知的の数
--                IBIT12CNT_1  := 0;        -- １年　障害・肢体の数
--                IBIT13CNT_1  := 0;        -- １年　障害・病弱の数
--                IBIT14CNT_1  := 0;        -- １年　障害・院内の数
--                IBIT15CNT_1  := 0;        -- １年　障害・弱視の数
--                IBIT16CNT_1  := 0;        -- １年　障害・難聴の数
--                IBIT17CNT_1  := 0;        -- １年　障害・言語の数
--                IBIT18CNT_1  := 0;        -- １年　障害・情緒の数
--                IBIT2CNT_1   := 0;        -- １年　外国人の数
--                IBIT3CNT_1   := 0;        -- １年　下学年の数
--                IMALE_FEMALE_CNT1 := 0;   -- １年　男女計
--                IFUTSU_GAKYU_1 := 0;      -- １年　普通学級の数
-- 
--                IMALECNT_2   := 0;        -- 2年　男子計
--                IFEMALECNT_2 := 0;        -- 2年　女子計
--                IBIT11CNT_2  := 0;        -- 2年　障害・知的の数
--                IBIT12CNT_2  := 0;        -- 2年　障害・肢体の数
--                IBIT13CNT_2  := 0;        -- 2年　障害・病弱の数
--                IBIT14CNT_2  := 0;        -- 2年　障害・院内の数
--                IBIT15CNT_2  := 0;        -- 2年　障害・弱視の数
--                IBIT16CNT_2  := 0;        -- 2年　障害・難聴の数
--                IBIT17CNT_2  := 0;        -- 2年　障害・言語の数
--                IBIT18CNT_2  := 0;        -- 2年　障害・情緒の数
--                IBIT2CNT_2   := 0;        -- 2年　外国人の数
--                IBIT3CNT_2   := 0;        -- 2年　下学年の数
--                IMALE_FEMALE_CNT2 := 0;   -- 2年　男女計
--                IFUTSU_GAKYU_2 := 0;      -- 2年　普通学級の数
-- 
--                IMALECNT_3   := 0;        -- 3年　男子計
--                IFEMALECNT_3 := 0;        -- 3年　女子計
--                IBIT11CNT_3  := 0;        -- 3年　障害・知的の数
--                IBIT12CNT_3  := 0;        -- 3年　障害・肢体の数
--                IBIT13CNT_3  := 0;        -- 3年　障害・病弱の数
--                IBIT14CNT_3  := 0;        -- 3年　障害・院内の数
--                IBIT15CNT_3  := 0;        -- 3年　障害・弱視の数
--                IBIT16CNT_3  := 0;        -- 3年　障害・難聴の数
--                IBIT17CNT_3  := 0;        -- 3年　障害・言語の数
--                IBIT18CNT_3  := 0;        -- 3年　障害・情緒の数
--                IBIT2CNT_3   := 0;        -- 3年　外国人の数
--                IBIT3CNT_3   := 0;        -- 3年　下学年の数
--                IMALE_FEMALE_CNT3 := 0;   -- 3年　男女計
--                IFUTSU_GAKYU_3 := 0;      -- 3年　普通学級の数
-- 
--                IMALECNT_4   := 0;        -- 4年　男子計
--                IFEMALECNT_4 := 0;        -- 4年　女子計
--                IBIT11CNT_4  := 0;        -- 4年　障害・知的の数
--                IBIT12CNT_4  := 0;        -- 4年　障害・肢体の数
--                IBIT13CNT_4  := 0;        -- 4年　障害・病弱の数
--                IBIT14CNT_4  := 0;        -- 4年　障害・院内の数
--                IBIT15CNT_4  := 0;        -- 4年　障害・弱視の数
--                IBIT16CNT_4  := 0;        -- 4年　障害・難聴の数
--                IBIT17CNT_4  := 0;        -- 4年　障害・言語の数
--                IBIT18CNT_4  := 0;        -- 4年　障害・情緒の数
--                IBIT2CNT_4   := 0;        -- 4年　外国人の数
--                IBIT3CNT_4   := 0;        -- 4年　下学年の数
--                IMALE_FEMALE_CNT4 := 0;   -- 4年　男女計
--                IFUTSU_GAKYU_4 := 0;      -- 4年　普通学級の数
-- 
--                IMALECNT_5   := 0;        -- 5年　男子計
--                IFEMALECNT_5 := 0;        -- 5年　女子計
--                IBIT11CNT_5  := 0;        -- 5年　障害・知的の数
--                IBIT12CNT_5  := 0;        -- 5年　障害・肢体の数
--                IBIT13CNT_5  := 0;        -- 5年　障害・病弱の数
--                IBIT14CNT_5  := 0;        -- 5年　障害・院内の数
--                IBIT15CNT_5  := 0;        -- 5年　障害・弱視の数
--                IBIT16CNT_5  := 0;        -- 5年　障害・難聴の数
--                IBIT17CNT_5  := 0;        -- 5年　障害・言語の数
--                IBIT18CNT_5  := 0;        -- 5年　障害・情緒の数
--                IBIT2CNT_5   := 0;        -- 5年　外国人の数
--                IBIT3CNT_5   := 0;        -- 5年　下学年の数
--                IMALE_FEMALE_CNT5 := 0;   -- 5年　男女計
--                IFUTSU_GAKYU_5 := 0;      -- 5年　普通学級の数
-- 
--                IMALECNT_6   := 0;        -- 6年　男子計
--                IFEMALECNT_6 := 0;        -- 6年　女子計
--                IBIT11CNT_6  := 0;        -- 6年　障害・知的の数
--                IBIT12CNT_6  := 0;        -- 6年　障害・肢体の数
--                IBIT13CNT_6  := 0;        -- 6年　障害・病弱の数
--                IBIT14CNT_6  := 0;        -- 6年　障害・院内の数
--                IBIT15CNT_6  := 0;        -- 6年　障害・弱視の数
--                IBIT16CNT_6  := 0;        -- 6年　障害・難聴の数
--                IBIT17CNT_6  := 0;        -- 6年　障害・言語の数
--                IBIT18CNT_6  := 0;        -- 6年　障害・情緒の数
--                IBIT2CNT_6   := 0;        -- 6年　外国人の数
--                IBIT3CNT_6   := 0;        -- 6年　下学年の数
--                IMALE_FEMALE_CNT6 := 0;   -- 6年　男女計
--                IFUTSU_GAKYU_6 := 0;      -- 6年　普通学級の数
--2024/07/12 ZCZL.qinyue Delete end
--  2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
            --END IF;
--  2025/05/16 CTC.HJF Delete End
--               IF CUR1.GAKUNEN_CD IN (1,7) THEN
--                  IMALECNT_1    := CUR1.MALECNT;          -- １年　男子計
--                  IFEMALECNT_1  := CUR1.FEMALECNT;        -- １年　女子計
--                  IMALE_FEMALE_CNT1 := IMALECNT_1 + IFEMALECNT_1;          -- 1年  男女計
--                  IFUTSU_GAKYU_1 := CEIL(IMALE_FEMALE_CNT1/IFUTSU_NINZU);  -- １年　普通学級の数
--                  IBIT11CNT_1  := CUR1.BIT11CNT;        -- １年　障害・知的の数
--                  IBIT12CNT_1  := CUR1.BIT12CNT;        -- １年　障害・肢体の数
--                  IBIT13CNT_1  := CUR1.BIT13CNT;        -- １年　障害・病弱の数
--                  IBIT14CNT_1  := CUR1.BIT14CNT;        -- １年　障害・院内の数
--                  IBIT15CNT_1  := CUR1.BIT15CNT;        -- １年　障害・弱視の数
--                  IBIT16CNT_1  := CUR1.BIT16CNT;        -- １年　障害・難聴の数
--                  IBIT17CNT_1  := CUR1.BIT17CNT;        -- １年　障害・言語の数
--                  IBIT18CNT_1  := CUR1.BIT18CNT;        -- １年　障害・情緒の数
--                  IBIT2CNT_1   := CUR1.BIT2CNT;         -- １年　外国人の数
--                  IBIT3CNT_1   := CUR1.BIT3CNT;         -- １年　下学年の数
--               END IF;

--               IF CUR1.GAKUNEN_CD IN (2,8) THEN
--                  IBIT11CNT_2 := CUR1.BIT11CNT;         -- 2 年　障害・知的の数
--                  IBIT12CNT_2  := CUR1.BIT12CNT;        -- 2 年　障害・肢体の数
--                  IBIT13CNT_2  := CUR1.BIT13CNT;        -- 2 年　障害・病弱の数
--                  IBIT14CNT_2  := CUR1.BIT14CNT;        -- 2 年　障害・院内の数
--                  IBIT15CNT_2  := CUR1.BIT15CNT;        -- 2 年　障害・弱視の数
--                  IBIT16CNT_2  := CUR1.BIT16CNT;        -- 2 年　障害・難聴の数
--                  IBIT17CNT_2  := CUR1.BIT17CNT;        -- 2 年　障害・言語の数
--                  IBIT18CNT_2  := CUR1.BIT18CNT;        -- 2 年　障害・情緒の数
--                  IBIT2CNT_2   := CUR1.BIT2CNT;         -- 2 年　外国人の数
--                  IBIT3CNT_2   := CUR1.BIT3CNT;         -- 2 年　下学年の数
--                  IMALECNT_2   := CUR1.MALECNT;         -- 2 年　男子計
--                  IFEMALECNT_2 := CUR1.FEMALECNT;       -- 2 年　女子計
--                  IMALE_FEMALE_CNT2 := IMALECNT_2 + IFEMALECNT_2;          -- 2年  男女計
--                  IFUTSU_GAKYU_2 := CEIL(IMALE_FEMALE_CNT2/IFUTSU_NINZU);  -- 2年　普通学級の数
--               END IF;
-- 
--               IF CUR1.GAKUNEN_CD IN (3,9) THEN
--                  IBIT11CNT_3 := CUR1.BIT11CNT;         -- 3 年　障害・知的の数
--                  IBIT12CNT_3  := CUR1.BIT12CNT;        -- 3 年　障害・肢体の数
--                  IBIT13CNT_3  := CUR1.BIT13CNT;        -- 3 年　障害・病弱の数
--                  IBIT14CNT_3  := CUR1.BIT14CNT;        -- 3 年　障害・院内の数
--                  IBIT15CNT_3  := CUR1.BIT15CNT;        -- 3 年　障害・弱視の数
--                  IBIT16CNT_3  := CUR1.BIT16CNT;        -- 3 年　障害・難聴の数
--                  IBIT17CNT_3  := CUR1.BIT17CNT;        -- 3 年　障害・言語の数
--                  IBIT18CNT_3  := CUR1.BIT18CNT;        -- 3 年　障害・情緒の数
--                  IBIT2CNT_3   := CUR1.BIT2CNT;         -- 3 年　外国人の数
--                  IBIT3CNT_3   := CUR1.BIT3CNT;         -- 3 年　下学年の数
--                  IMALECNT_3   := CUR1.MALECNT;         -- 3 年　男子計
--                  IFEMALECNT_3 := CUR1.FEMALECNT;       -- 3 年　女子計
--                  IMALE_FEMALE_CNT3 := IMALECNT_3 + IFEMALECNT_3;          -- 3年  男女計
--                  IFUTSU_GAKYU_3 := CEIL(IMALE_FEMALE_CNT3/IFUTSU_NINZU);  -- 3年　普通学級の数
--               END IF;
-- 
--               IF CUR1.GAKUNEN_CD = 4 THEN              --「学校区分」≠1のとき設定、「学校区分」＝1の場合はNULL設定
--                  IBIT11CNT_4 := CUR1.BIT11CNT;         -- 4 年　障害・知的の数
--                  IBIT12CNT_4  := CUR1.BIT12CNT;        -- 4 年　障害・肢体の数
--                  IBIT13CNT_4  := CUR1.BIT13CNT;        -- 4 年　障害・病弱の数
--                  IBIT14CNT_4  := CUR1.BIT14CNT;        -- 4 年　障害・院内の数
--                  IBIT15CNT_4  := CUR1.BIT15CNT;        -- 4 年　障害・弱視の数
--                  IBIT16CNT_4  := CUR1.BIT16CNT;        -- 4 年　障害・難聴の数
--                  IBIT17CNT_4  := CUR1.BIT17CNT;        -- 4 年　障害・言語の数
--                  IBIT18CNT_4  := CUR1.BIT18CNT;        -- 4 年　障害・情緒の数
--                  IBIT2CNT_4   := CUR1.BIT2CNT;         -- 4 年　外国人の数
--                  IBIT3CNT_4   := CUR1.BIT3CNT;         -- 4 年　下学年の数
--                  IMALECNT_4   := CUR1.MALECNT;         -- 4 年　男子計
--                  IFEMALECNT_4 := CUR1.FEMALECNT;       -- 4 年　女子計
--                  IMALE_FEMALE_CNT4 := IMALECNT_4 + IFEMALECNT_4;          -- 4年  男女計
--                  IFUTSU_GAKYU_4 := CEIL(IMALE_FEMALE_CNT4/IFUTSU_NINZU);  -- 4年　普通学級の数
--               END IF;
-- 
--               IF CUR1.GAKUNEN_CD = 5 THEN              --「学校区分」≠1のとき設定、「学校区分」＝1の場合はNULL設定
--                  IBIT11CNT_5 := CUR1.BIT11CNT;         -- 5 年　障害・知的の数
--                  IBIT12CNT_5  := CUR1.BIT12CNT;        -- 5 年　障害・肢体の数
--                  IBIT13CNT_5  := CUR1.BIT13CNT;        -- 5 年　障害・病弱の数
--                  IBIT14CNT_5  := CUR1.BIT14CNT;        -- 5 年　障害・院内の数
--                  IBIT15CNT_5  := CUR1.BIT15CNT;        -- 5 年　障害・弱視の数
--                  IBIT16CNT_5  := CUR1.BIT16CNT;        -- 5 年　障害・難聴の数
--                  IBIT17CNT_5  := CUR1.BIT17CNT;        -- 5 年　障害・言語の数
--                  IBIT18CNT_5  := CUR1.BIT18CNT;        -- 5 年　障害・情緒の数
--                  IBIT2CNT_5   := CUR1.BIT2CNT;         -- 5 年　外国人の数
--                  IBIT3CNT_5   := CUR1.BIT3CNT;         -- 5 年　下学年の数
--                  IMALECNT_5   := CUR1.MALECNT;         -- 5 年　男子計
--                  IFEMALECNT_5 := CUR1.FEMALECNT;       -- 5 年　女子計
--                  IMALE_FEMALE_CNT5 := IMALECNT_5 + IFEMALECNT_5;          -- 5年  男女計
--                  IFUTSU_GAKYU_5 := CEIL(IMALE_FEMALE_CNT5/IFUTSU_NINZU);  -- 5年　普通学級の数
--                END IF;
-- 
--                IF CUR1.GAKUNEN_CD = 6 THEN              --「学校区分」≠1のとき設定、「学校区分」＝1の場合はNULL設定
--                   IBIT11CNT_6 := CUR1.BIT11CNT;         -- 6 年　障害・知的の数
--                   IBIT12CNT_6  := CUR1.BIT12CNT;        -- 6 年　障害・肢体の数
--                   IBIT13CNT_6  := CUR1.BIT13CNT;        -- 6 年　障害・病弱の数
--                   IBIT14CNT_6  := CUR1.BIT14CNT;        -- 6 年　障害・院内の数
--                   IBIT15CNT_6  := CUR1.BIT15CNT;        -- 6 年　障害・弱視の数
--                   IBIT16CNT_6  := CUR1.BIT16CNT;        -- 6 年　障害・難聴の数
--                   IBIT17CNT_6  := CUR1.BIT17CNT;        -- 6 年　障害・言語の数
--                   IBIT18CNT_6  := CUR1.BIT18CNT;        -- 6 年　障害・情緒の数
--                   IBIT2CNT_6   := CUR1.BIT2CNT;         -- 6 年　外国人の数
--                   IBIT3CNT_6   := CUR1.BIT3CNT;         -- 6 年　下学年の数
--                   IMALECNT_6   := CUR1.MALECNT;         -- 6 年　男子計
--                   IFEMALECNT_6 := CUR1.FEMALECNT;       -- 6 年　女子計
--                   IMALE_FEMALE_CNT6 := IMALECNT_6 + IFEMALECNT_6;         -- 6年  男女計
--                   IFUTSU_GAKYU_6 := CEIL(IMALE_FEMALE_CNT6/IFUTSU_NINZU);      -- 6年　普通学級の数
--                 END IF;

--                 IF CUR1.GAKUNEN_CD > 6 THEN
--                    IMALECNT_4   := NULL;        -- 4年　男子計
--                    IFEMALECNT_4 := NULL;        -- 4年　女子計
--                    IBIT11CNT_4  := NULL;        -- 4年　障害・知的の数
--                    IBIT12CNT_4  := NULL;        -- 4年　障害・肢体の数
--                    IBIT13CNT_4  := NULL;        -- 4年　障害・病弱の数
--                    IBIT14CNT_4  := NULL;        -- 4年　障害・院内の数
--                    IBIT15CNT_4  := NULL;        -- 4年　障害・弱視の数
--                    IBIT16CNT_4  := NULL;        -- 4年　障害・難聴の数
--                    IBIT17CNT_4  := NULL;        -- 4年　障害・言語の数
--                    IBIT18CNT_4  := NULL;        -- 4年　障害・情緒の数
--                    IBIT2CNT_4   := NULL;        -- 4年　外国人の数
--                    IBIT3CNT_4   := NULL;        -- 4年　下学年の数
--                    IMALE_FEMALE_CNT4 := NULL;   -- 4年　男女計
--                    IFUTSU_GAKYU_4 := NULL;      -- 4年　普通学級の数
--                    IMALECNT_5   := NULL;        -- 5年　男子計
--                    IFEMALECNT_5 := NULL;        -- 5年　女子計
--                    IBIT11CNT_5  := NULL;        -- 5年　障害・知的の数
--                    IBIT12CNT_5  := NULL;        -- 5年　障害・肢体の数
--                    IBIT13CNT_5  := NULL;        -- 5年　障害・病弱の数
--                    IBIT14CNT_5  := NULL;        -- 5年　障害・院内の数
--                    IBIT15CNT_5  := NULL;        -- 5年　障害・弱視の数
--                    IBIT16CNT_5  := NULL;        -- 5年　障害・難聴の数
--                    IBIT17CNT_5  := NULL;        -- 5年　障害・言語の数
--                    IBIT18CNT_5  := NULL;        -- 5年　障害・情緒の数
--                    IBIT2CNT_5   := NULL;        -- 5年　外国人の数
--                    IBIT3CNT_5   := NULL;        -- 5年　下学年の数
--                    IMALE_FEMALE_CNT5 := NULL;   -- 5年　男女計
--                    IFUTSU_GAKYU_5 := NULL;      -- 5年　普通学級の数
--                    IMALECNT_6   := NULL;        -- 6年　男子計
--                    IFEMALECNT_6 := NULL;        -- 6年　女子計
--                    IBIT11CNT_6  := NULL;        -- 6年　障害・知的の数
--                    IBIT12CNT_6  := NULL;        -- 6年　障害・肢体の数
--                    IBIT13CNT_6  := NULL;        -- 6年　障害・病弱の数
--                    IBIT14CNT_6  := NULL;        -- 6年　障害・院内の数
--                    IBIT15CNT_6  := NULL;        -- 6年　障害・弱視の数
--                    IBIT16CNT_6  := NULL;        -- 6年　障害・難聴の数
--                    IBIT17CNT_6  := NULL;        -- 6年　障害・言語の数
--                    IBIT18CNT_6  := NULL;        -- 6年　障害・情緒の数
--                    IBIT2CNT_6   := NULL;        -- 6年　外国人の数
--                    IBIT3CNT_6   := NULL;        -- 6年　下学年の数
--                    IMALE_FEMALE_CNT6 := NULL;   -- 6年　男女計
--                    IFUTSU_GAKYU_6 := NULL;      -- 6年　普通学級の数
--                 END IF;
-- 
--                IMALECNT := IMALECNT_1 + IMALECNT_2 + IMALECNT_3 + NVL(IMALECNT_4,0) + NVL(IMALECNT_5,0) + NVL(IMALECNT_6,0);  -- 「１年　男の数」～「６年　男の数」の合計
--                IFEMALECNT := IFEMALECNT_1 + IFEMALECNT_2 + IFEMALECNT_3 + NVL(IFEMALECNT_4,0) + NVL(IFEMALECNT_5,0) + NVL(IFEMALECNT_6,0); -- 「１年　女の数」～「６年　女の数」の合計
--                IMALE_FEMALE_CNT :=  IMALE_FEMALE_CNT1 + IMALE_FEMALE_CNT2 + IMALE_FEMALE_CNT3 + NVL(IMALE_FEMALE_CNT4,0) + NVL(IMALE_FEMALE_CNT5,0) + NVL(IMALE_FEMALE_CNT6,0); -- 「男子計」＋「女子計」
--                IFUTSU_GAKYU := IFUTSU_GAKYU_1 + IFUTSU_GAKYU_2 + IFUTSU_GAKYU_3 + NVL(IFUTSU_GAKYU_4,0) + NVL(IFUTSU_GAKYU_5,0) + NVL(IFUTSU_GAKYU_6,0);  -- 「１年　普通学級の数」～「６年　普通学級の数」の合計
--                IBIT11CNT := IBIT11CNT_1 + IBIT11CNT_2 + IBIT11CNT_3 + NVL(IBIT11CNT_4,0) + NVL(IBIT11CNT_5,0) + NVL(IBIT11CNT_6,0);  --「１年　障害・知的の数」～「６年　障害・知的の数」の合計
--                IBIT12CNT := IBIT12CNT_1 + IBIT12CNT_2 + IBIT12CNT_3 + NVL(IBIT12CNT_4,0) + NVL(IBIT12CNT_5,0) + NVL(IBIT12CNT_6,0);  --「１年　障害・知的の数」～「６年　障害・知的の数」の合計
--                IBIT13CNT := IBIT13CNT_1 + IBIT13CNT_2 + IBIT13CNT_3 + NVL(IBIT13CNT_4,0) + NVL(IBIT13CNT_5,0) + NVL(IBIT13CNT_6,0);  --「１年　障害・病弱の数」～「６年　障害・病弱の数」の合計
--                IBIT14CNT := IBIT14CNT_1 + IBIT14CNT_2 + IBIT14CNT_3 + NVL(IBIT14CNT_4,0) + NVL(IBIT14CNT_5,0) + NVL(IBIT14CNT_6,0);  --「１年　障害・院内の数」～「６年　障害・院内の数」の合計
--                IBIT15CNT := IBIT15CNT_1 + IBIT15CNT_2 + IBIT15CNT_3 + NVL(IBIT15CNT_4,0) + NVL(IBIT15CNT_5,0) + NVL(IBIT15CNT_6,0);  --「１年　障害・弱視の数」～「６年　障害・弱視の数」の合計
--                IBIT16CNT := IBIT16CNT_1 + IBIT16CNT_2 + IBIT16CNT_3 + NVL(IBIT16CNT_4,0) + NVL(IBIT16CNT_5,0) + NVL(IBIT16CNT_6,0);  --「１年　障害・難聴の数」～「６年　障害・難聴の数」の合計
--                IBIT17CNT := IBIT17CNT_1 + IBIT17CNT_2 + IBIT17CNT_3 + NVL(IBIT17CNT_4,0) + NVL(IBIT17CNT_5,0) + NVL(IBIT17CNT_6,0);  --「１年　障害・言語の数」～「６年　障害・言語の数」の合計
--                IBIT18CNT := IBIT18CNT_1 + IBIT18CNT_2 + IBIT18CNT_3 + NVL(IBIT18CNT_4,0) + NVL(IBIT18CNT_5,0) + NVL(IBIT18CNT_6,0);  --「１年　障害・情緒の数」～「６年　障害・情緒の数」の合計
--                IBIT2CNT  := IBIT2CNT_1 + IBIT2CNT_2 + IBIT2CNT_3 + NVL(IBIT2CNT_4,0) + NVL(IBIT2CNT_5,0) + NVL(IBIT2CNT_6,0);        --「１年　外国人の数」～「６年　外国人の数」の合計
--                IBIT3CNT  := IBIT3CNT_1 + IBIT3CNT_2 + IBIT3CNT_3 + NVL(IBIT3CNT_4,0) + NVL(IBIT3CNT_5,0) + NVL(IBIT3CNT_6,0);        --「１年　下学年の数」～「６年　下学年の数」の合計
--                IBITSUM   := IBIT11CNT + IBIT12CNT + IBIT13CNT + IBIT14CNT + IBIT15CNT+  IBIT16CNT + IBIT17CNT+  IBIT18CNT;  -- 障害児合計
--                IJIDOSUM  := IBITSUM + IMALE_FEMALE_CNT; --  児童生徒数合計
--                ITOKU_GAKYU := CEIL(IBIT11CNT/ITOKU_NINZU) + CEIL(IBIT12CNT/ITOKU_NINZU) + CEIL((IBIT13CNT + IBIT14CNT)/ITOKU_NINZU) +
--                               CEIL(IBIT15CNT/ITOKU_NINZU) + CEIL(IBIT16CNT/ITOKU_NINZU) + CEIL(IBIT17CNT/ITOKU_NINZU) + CEIL(IBIT18CNT/ITOKU_NINZU);
--                IFUSTUS_TOKU_SUM := ITOKU_GAKYU + IFUTSU_GAKYU; --「普通学級の合計」＋「障害児学級数合計」
-- 2024/07/12 ZCZL.qinyue Delete end
-- 2024/07/12 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
--  2025/06/11 CTC.HJF UPDATE Start 1.0.008.000:GKB_QA15686対応
           MALE1          :=0;         --１年男の数
           MALE2          :=0;         --２年男の数
           MALE3          :=0;         --３年男の数
           MALE4          :=0;         --４年男の数
           MALE5          :=0;         --５年男の数
           MALE6          :=0;         --６年男の数
           MALEALL        :=0;         --男子計

           FEMALE1        := 0;        --１年女の数
           FEMALE2        := 0;        --２年女の数
           FEMALE3        := 0;        --３年女の数
           FEMALE4        := 0;        --４年女の数
           FEMALE5        := 0;        --５年女の数
           FEMALE6        := 0;        --６年女の数
           FEMALEALL      := 0;        --女子計

           FUTSUMALE1     := 0;        --１普通学級１年男の数
           FUTSUMALE2     := 0;        --２普通学級２年男の数
           FUTSUMALE3     := 0;        --３普通学級３年男の数
           FUTSUMALE4     := 0;        --４普通学級４年男の数
           FUTSUMALE5     := 0;        --５普通学級５年男の数
           FUTSUMALE6     := 0;        --６普通学級６年男の数
           FUTSUMALEALL   := 0;        --普通学級男子計

           FUTSUFEMALE1   := 0;        --普通学級１年女の数
           FUTSUFEMALE2   := 0;        --普通学級２年女の数
           FUTSUFEMALE3   := 0;        --普通学級３年女の数
           FUTSUFEMALE4   := 0;        --普通学級４年女の数
           FUTSUFEMALE5   := 0;        --普通学級５年女の数
           FUTSUFEMALE6   := 0;        --普通学級６年女の数
           FUTSUFEMALEALL  := 0;       --普通学級女子計

           TOKUBETSUMALE1  := 0;       --特別支援学級１年男の数
           TOKUBETSUMALE2  := 0;       --特別支援学級２年男の数
           TOKUBETSUMALE3  := 0;       --特別支援学級３年男の数
           TOKUBETSUMALE4  := 0;       --特別支援学級４年男の数
           TOKUBETSUMALE5  := 0;       --特別支援学級５年男の数
           TOKUBETSUMALE6  := 0;       --特別支援学級６年男の数
           TOKUBETSUMALEALL  := 0;     --特別支援学級男子計

           TOKUBETSUFEMALE1  := 0;     --特別支援学級１年女の数
           TOKUBETSUFEMALE2  := 0;     --特別支援学級２年女の数
           TOKUBETSUFEMALE3  := 0;     --特別支援学級３年女の数
           TOKUBETSUFEMALE4  := 0;     --特別支援学級４年女の数
           TOKUBETSUFEMALE5  := 0;     --特別支援学級５年女の数
           TOKUBETSUFEMALE6  := 0;     --特別支援学級６年女の数
           TOKUBETSUFEMALEALL  := 0;   --特別支援学級女子計

           MALEFEMALE1   := 0;         --１年男女の数
           MALEFEMALE2   := 0;         --２年男女の数
           MALEFEMALE3   := 0;         --３年男女の数
           MALEFEMALE4   := 0;         --４年男女の数
           MALEFEMALE5   := 0;         --５年男女の数
           MALEFEMALE6   := 0;         --６年男女の数

           KAIPAGEFLAG   :=0;


--  2025/06/11 CTC.HJF UPDATE End
--  2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応
--  2025/06/11 CTC.HJF UPDATE Start 1.0.008.000:GKB_QA15686対応
            --IF CUR1.GAKKO_KBN_CD IN (1,3,4,5)  THEN
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
            --IF CUR1.GAKKO_KBN_CD  IN (1,2,3,4,5)  THEN
            IF CUR1.GAKKO_KBN_CD  IN (0,1,2,3,4,5)  THEN
--  2025/09/25 CTC.HJF UPDATE END
                 IF CUR1.GAKUNEN_CD IN (1,2,3,4,5,6) THEN
--  2025/06/11 CTC.HJF UPDATE End
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --小学一年男生
                      --SELECT COUNT(1) INTO FUTSUMALE1     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =1 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =0;
                      --SELECT COUNT(1) INTO TOKUBETSUMALE1 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =1 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =1;
                      SELECT COUNT(1) INTO FUTSUMALE1     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =1 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =0;
                      SELECT COUNT(1) INTO TOKUBETSUMALE1 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =1 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =1;
--  2025/09/25 CTC.HJF UPDATE END
                      MALE1 :=  FUTSUMALE1 + TOKUBETSUMALE1;

                      --小学一年女生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUFEMALE1     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =1 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =0;
                      --SELECT COUNT(1) INTO TOKUBETSUFEMALE1 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =1 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =1;
                      SELECT COUNT(1) INTO FUTSUFEMALE1     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =1 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =0;
                      SELECT COUNT(1) INTO TOKUBETSUFEMALE1 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =1 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =1;
--  2025/09/25 CTC.HJF UPDATE END
                      FEMALE1 :=  FUTSUFEMALE1 + TOKUBETSUFEMALE1;
                      MALEFEMALE1 :=  MALE1 + FEMALE1;

                      --小学二年男生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUMALE2     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 2 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 0;
                      --SELECT COUNT(1) INTO TOKUBETSUMALE2 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 2 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 1;
                      SELECT COUNT(1) INTO FUTSUMALE2     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 2 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 0;
                      SELECT COUNT(1) INTO TOKUBETSUMALE2 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 2 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 1;
--  2025/09/25 CTC.HJF UPDATE END
                      MALE2 := FUTSUMALE2 + TOKUBETSUMALE2;

                      --小学二年女生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUFEMALE2     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 2 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 0;
                      --SELECT COUNT(1) INTO TOKUBETSUFEMALE2 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 2 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 1;
                      SELECT COUNT(1) INTO FUTSUFEMALE2     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 2 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 0;
                      SELECT COUNT(1) INTO TOKUBETSUFEMALE2 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 2 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 1;
--  2025/09/25 CTC.HJF UPDATE END
                      FEMALE2 := FUTSUFEMALE2 + TOKUBETSUFEMALE2;
                      MALEFEMALE2 :=  MALE2 + FEMALE2;

                      -- 小学三年男生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUMALE3     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 3 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 0;
                      --SELECT COUNT(1) INTO TOKUBETSUMALE3 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 3 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 1;
                      SELECT COUNT(1) INTO FUTSUMALE3     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 3 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 0;
                      SELECT COUNT(1) INTO TOKUBETSUMALE3 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 3 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 1;
--  2025/09/25 CTC.HJF UPDATE END
                      MALE3 := FUTSUMALE3 + TOKUBETSUMALE3;

                      -- 小学三年女生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUFEMALE3     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 3 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 0;
                      --SELECT COUNT(1) INTO TOKUBETSUFEMALE3 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 3 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 1;
                      SELECT COUNT(1) INTO FUTSUFEMALE3     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 3 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 0;
                      SELECT COUNT(1) INTO TOKUBETSUFEMALE3 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 3 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 1;
--  2025/09/25 CTC.HJF UPDATE END
                      FEMALE3 := FUTSUFEMALE3 + TOKUBETSUFEMALE3;
                      MALEFEMALE3 :=  MALE3 + FEMALE3;

                      -- 小学四年男生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUMALE4     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 4 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 0;
                      --SELECT COUNT(1) INTO TOKUBETSUMALE4 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 4 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 1;
                      SELECT COUNT(1) INTO FUTSUMALE4     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 4 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 0;
                      SELECT COUNT(1) INTO TOKUBETSUMALE4 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 4 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 1;
--  2025/09/25 CTC.HJF UPDATE END
                      MALE4 := FUTSUMALE4 + TOKUBETSUMALE4;

                      -- 小学四年女生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUFEMALE4     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 4 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 0;
                      --SELECT COUNT(1) INTO TOKUBETSUFEMALE4 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 4 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 1;
                      SELECT COUNT(1) INTO FUTSUFEMALE4     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 4 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 0;
                      SELECT COUNT(1) INTO TOKUBETSUFEMALE4 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 4 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 1;
--  2025/09/25 CTC.HJF UPDATE END
                      FEMALE4 := FUTSUFEMALE4 + TOKUBETSUFEMALE4;
                      MALEFEMALE4 :=  MALE4 + FEMALE4;

                      -- 小学五年男生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUMALE5     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 5 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 0;
                      --SELECT COUNT(1) INTO TOKUBETSUMALE5 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 5 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 1;
                      SELECT COUNT(1) INTO FUTSUMALE5     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 5 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 0;
                      SELECT COUNT(1) INTO TOKUBETSUMALE5 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 5 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 1;
--  2025/09/25 CTC.HJF UPDATE END
                      MALE5 := FUTSUMALE5 + TOKUBETSUMALE5;

                      -- 小学五年女生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUFEMALE5     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 5 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 0;
                      --SELECT COUNT(1) INTO TOKUBETSUFEMALE5 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 5 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 1;
                      SELECT COUNT(1) INTO FUTSUFEMALE5     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 5 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 0;
                      SELECT COUNT(1) INTO TOKUBETSUFEMALE5 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 5 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 1;
--  2025/09/25 CTC.HJF UPDATE END
                      FEMALE5 := FUTSUFEMALE5 + TOKUBETSUFEMALE5;
                      MALEFEMALE5 :=  MALE5 + FEMALE5;

                      -- 小学六年男生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUMALE6 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 6 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 0;
                      --SELECT COUNT(1) INTO TOKUBETSUMALE6 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 6 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 1;
                      SELECT COUNT(1) INTO FUTSUMALE6     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 6     AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 0;
                      SELECT COUNT(1) INTO TOKUBETSUMALE6 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 6     AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 1 AND GAKUKYU_KBN = 1;
--  2025/09/25 CTC.HJF UPDATE END
                      MALE6 := FUTSUMALE6 + TOKUBETSUMALE6;

                      -- 小学五年女生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUFEMALE6 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 6 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 0;
                      --SELECT COUNT(1) INTO TOKUBETSUFEMALE6 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 6 AND GAKKO_KBN_CD = CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 1;
                      SELECT COUNT(1) INTO FUTSUFEMALE6     FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 6 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 0;
                      SELECT COUNT(1) INTO TOKUBETSUFEMALE6 FROM GKBWJIDOZAIGAKU WHERE GAKUNEN_CD = 6 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU = 2 AND GAKUKYU_KBN = 1;
--  2025/09/25 CTC.HJF UPDATE END
                      FEMALE6 := FUTSUFEMALE6 + TOKUBETSUFEMALE6;
                      MALEFEMALE6 :=  MALE6 + FEMALE6;

                      FUTSUMALEALL := FUTSUMALE1 + FUTSUMALE2 +FUTSUMALE3 +FUTSUMALE4 +FUTSUMALE5 +FUTSUMALE6; 
                      TOKUBETSUMALEALL  := TOKUBETSUMALE1 + TOKUBETSUMALE2 +TOKUBETSUMALE3 +TOKUBETSUMALE4 +TOKUBETSUMALE5 +TOKUBETSUMALE6; 

                      FUTSUFEMALEALL   := FUTSUFEMALE1 + FUTSUFEMALE2 +FUTSUFEMALE3 +FUTSUFEMALE4 +FUTSUFEMALE5 +FUTSUFEMALE6; 
                      TOKUBETSUFEMALEALL := TOKUBETSUFEMALE1 + TOKUBETSUFEMALE2 +TOKUBETSUFEMALE3 +TOKUBETSUFEMALE4 +TOKUBETSUFEMALE5 +TOKUBETSUFEMALE6; 

                      MALEALL    := MALE1 + MALE2 +  MALE3 +  MALE4 +  MALE5 +  MALE6;
                      FEMALEALL  := FEMALE1 + FEMALE2 +  FEMALE3 +  FEMALE4 +  FEMALE5 +  FEMALE6;
--  2025/06/11 CTC.HJF UPDATE Start 1.0.008.000:GKB_QA15686対応
                      KAIPAGEFLAG   :=TO_NUMBER(TO_CHAR(CUR1.GAKKO_KBN_CD) || '6');
          --ELSIF CUR1.GAKKO_KBN_CD = 2 THEN
                 ELSIF CUR1.GAKUNEN_CD IN (7,8,9) THEN
--  2025/06/11 CTC.HJF UPDATE End
                      --中学生一年男生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUMALE1     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =7 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =0;
                      --SELECT COUNT(1) INTO TOKUBETSUMALE1 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =7 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =1;
                      SELECT COUNT(1) INTO FUTSUMALE1     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =7 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =0;
                      SELECT COUNT(1) INTO TOKUBETSUMALE1 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =7 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =1;
--  2025/09/25 CTC.HJF UPDATE END
                      MALE1 :=  FUTSUMALE1 + TOKUBETSUMALE1;

                      --中学生一年女生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUFEMALE1     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =7 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =0;
                      --SELECT COUNT(1) INTO TOKUBETSUFEMALE1 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =7 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =1;
                      SELECT COUNT(1) INTO FUTSUFEMALE1     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =7 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =0;
                      SELECT COUNT(1) INTO TOKUBETSUFEMALE1 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =7 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =1;
--  2025/09/25 CTC.HJF UPDATE END
                      FEMALE1 :=  FUTSUFEMALE1 + TOKUBETSUFEMALE1;
                      MALEFEMALE1 :=  MALE1 + FEMALE1;

                      --中学生二年男生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUMALE2     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =8 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =0;
                      --SELECT COUNT(1) INTO TOKUBETSUMALE2 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =8 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =1;
                      SELECT COUNT(1) INTO FUTSUMALE2     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =8 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =0;
                      SELECT COUNT(1) INTO TOKUBETSUMALE2 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =8 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =1;
--  2025/09/25 CTC.HJF UPDATE END
                      MALE2 :=  FUTSUMALE2 + TOKUBETSUMALE2;

                      --中学生二年女生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUFEMALE2     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =8 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =0;
                      --SELECT COUNT(1) INTO TOKUBETSUFEMALE2 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =8 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =1;
                      SELECT COUNT(1) INTO FUTSUFEMALE2     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =8 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =0;
                      SELECT COUNT(1) INTO TOKUBETSUFEMALE2 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =8 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =1;
--  2025/09/25 CTC.HJF UPDATE END
                      FEMALE2 :=  FUTSUFEMALE2 + TOKUBETSUFEMALE2;
                      MALEFEMALE2 :=  MALE2 + FEMALE2;

                      --中学生三年男生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUMALE3     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =9 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =0;
                      --SELECT COUNT(1) INTO TOKUBETSUMALE3 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =9 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =1;
                      SELECT COUNT(1) INTO FUTSUMALE3     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =9 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =0;
                      SELECT COUNT(1) INTO TOKUBETSUMALE3 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =9 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =1 AND GAKUKYU_KBN =1;
--  2025/09/25 CTC.HJF UPDATE END
                      MALE3 :=  FUTSUMALE3 + TOKUBETSUMALE3;

                      --中学生三年女生
--  2025/09/25 CTC.HJF UPDATE START 1.0.106.001:GKB_QA20729
                      --SELECT COUNT(1) INTO FUTSUFEMALE3     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =9 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =0;
                      --SELECT COUNT(1) INTO TOKUBETSUFEMALE3 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =9 AND GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =1;
                      SELECT COUNT(1) INTO FUTSUFEMALE3     FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =9 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =0;
                      SELECT COUNT(1) INTO TOKUBETSUFEMALE3 FROM  GKBWJIDOZAIGAKU WHERE  GAKUNEN_CD =9 AND (GAKKO_KBN_CD =CUR1.GAKKO_KBN_CD OR GAKKO_KBN_CD = 0) AND GAKOKU_CD = NGAKOKU_CD AND SEIBETSU =2 AND GAKUKYU_KBN =1;
--  2025/09/25 CTC.HJF UPDATE END
                      FEMALE3 :=  FUTSUFEMALE3 + TOKUBETSUFEMALE3;
                      MALEFEMALE3 :=  MALE3 + FEMALE3;

                      FUTSUMALEALL := FUTSUMALE1 + FUTSUMALE2 +FUTSUMALE3;
                      TOKUBETSUMALEALL  := TOKUBETSUMALE1 + TOKUBETSUMALE2 +TOKUBETSUMALE3;

                      FUTSUFEMALEALL   := FUTSUFEMALE1 + FUTSUFEMALE2 +FUTSUFEMALE3;
                      TOKUBETSUFEMALEALL := TOKUBETSUFEMALE1 + TOKUBETSUFEMALE2 +TOKUBETSUFEMALE3;

                      MALEALL    := MALE1 + MALE2 +  MALE3;
                      FEMALEALL  := FEMALE1 + FEMALE2 +  FEMALE3;
--  2025/06/11 CTC.HJF UPDATE Start 1.0.008.000:GKB_QA15686対応
                      KAIPAGEFLAG   :=TO_NUMBER(TO_CHAR(CUR1.GAKKO_KBN_CD) || '3');
                END IF;
--  2025/06/11 CTC.HJF UPDATE End
--  2025/06/11 CTC.HJF UPDATE Start 1.0.008.000:GKB_QA15686対応
          END IF;
--  2025/05/16 CTC.HJF UPDATE End
--  2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
--               IMALE1 := CUR1.MALE1;
--               IFEMALE1 := CUR1.FEMALE1;
--               IMALEFEMALE1 := IMALE1 + IFEMALE1;
--               IMALE2 := CUR1.MALE2;
--               IFEMALE2 := CUR1.FEMALE2;
--               IMALEFEMALE2 := IMALE1 + IFEMALE2;
--               IMALE3 := CUR1.MALE3;
--               IFEMALE3 := CUR1.FEMALE3;
--               IMALEFEMALE3 := IMALE1 + IFEMALE3;
--               IMALE4 := CUR1.MALE4;
--               IFEMALE4 := CUR1.FEMALE4;
--               IMALEFEMALE4 := IMALE1 + IFEMALE4;
--               IMALE5 := CUR1.MALE5;
--               IFEMALE5 := CUR1.FEMALE5;
--               IMALEFEMALE5 := IMALE1 + IFEMALE5;
--               IMALE6 := CUR1.MALE6;
--               IFEMALE6 := CUR1.FEMALE6;
--               IMALEFEMALE6 := IMALE1 + IFEMALE6;
--  2025/05/16 CTC.HJF Delete End
-- 2024/07/12 ZCZL.qinyue Add end
               nROWNO := nROWNO + 1;
               r_WKRECORD001 := NULL;
               r_WKRECORD001.NO                  := nROWNO;                   --ソート順
               r_WKRECORD001.NENDO               := NVL(VHYOUJINENDO,'');     --1.  年度
               r_WKRECORD001.SAKUSEIBI           := NVL(EAPFNV2STR(VSASKUSEIBI),'');      --2.  作成日
               r_WKRECORD001.KIJUNBI             := NVL(EAPFNV2STR(KIJUN_BI),'');         --3.  基準日
               r_WKRECORD001.GAKKOMEI           := NVL(CUR1.GAKOKUMEI,'');   --4.  学校名
-- 2024/07/12 ZCZL.qinyue Delete start 0.3.000.000:新WizLIFE2次開発
--                IF CUR1.GAKUNEN_CD > 6 THEN
--                   r_WKRECORD001.GAKKO_KBN :=  1;                              --5.  学校区分
--                ELSE
--                   r_WKRECORD001.GAKKO_KBN :=  0;                              --5.  学校区分
--                END IF;
--                r_WKRECORD001.MALECNT_1           := IMALECNT_1;               --6.  １年　男の数
--                r_WKRECORD001.FEMALECNT_1         := IFEMALECNT_1;             --7.  １年　女の数
--                r_WKRECORD001.MALE_FEMALE_CNT1    := IMALE_FEMALE_CNT1;        --8.  １年　男女の数
--                r_WKRECORD001.FUTSU_GAKYU_1       := IFUTSU_GAKYU_1;           --9.  １年　普通学級の数
--                r_WKRECORD001.BIT11CNT_1          := IBIT11CNT_1;              --10. １年　障害・知的の数
--                r_WKRECORD001.BIT12CNT_1          := IBIT12CNT_1;              --11. １年　障害・肢体の数
--                r_WKRECORD001.BIT13CNT_1          := IBIT13CNT_1;              --12. １年　障害・病弱の数
--                r_WKRECORD001.BIT14CNT_1          := IBIT14CNT_1;              --13. １年　障害・院内の数
--                r_WKRECORD001.BIT15CNT_1          := IBIT15CNT_1;              --14. １年　障害・弱視の数
--                r_WKRECORD001.BIT16CNT_1          := IBIT16CNT_1;              --15. １年　障害・難聴の数
--                r_WKRECORD001.BIT17CNT_1          := IBIT17CNT_1;              --16. １年　障害・言語の数
--                r_WKRECORD001.BIT18CNT_1          := IBIT18CNT_1;              --17. １年　障害・情緒の数
--                r_WKRECORD001.BIT2CNT_1           := IBIT2CNT_1;               --18. １年　外国人の数
--                r_WKRECORD001.BIT3CNT_1           := IBIT3CNT_1;               --19. １年　下学年の数
--                r_WKRECORD001.MALECNT_2           := IMALECNT_2;               --20.  2年　男の数
--                r_WKRECORD001.FEMALECNT_2         := IFEMALECNT_2;             --21.  2年　女の数
--                r_WKRECORD001.MALE_FEMALE_CNT2    := IMALE_FEMALE_CNT2;        --22.  2年　男女の数
--                r_WKRECORD001.FUTSU_GAKYU_2       := IFUTSU_GAKYU_2;           --23.  2年　普通学級の数
--                r_WKRECORD001.BIT11CNT_2          := IBIT11CNT_2;              --24.  2年　障害・知的の数
--                r_WKRECORD001.BIT12CNT_2          := IBIT12CNT_2;              --25.  2年　障害・肢体の数
--                r_WKRECORD001.BIT13CNT_2          := IBIT13CNT_2;              --26.  2年　障害・病弱の数
--                r_WKRECORD001.BIT14CNT_2          := IBIT14CNT_2;              --27.  2年　障害・院内の数
--                r_WKRECORD001.BIT15CNT_2          := IBIT15CNT_2;              --28.  2年　障害・弱視の数
--                r_WKRECORD001.BIT16CNT_2          := IBIT16CNT_2;              --29.  2年　障害・難聴の数
--                r_WKRECORD001.BIT17CNT_2          := IBIT17CNT_2;              --30.  2年　障害・言語の数
--                r_WKRECORD001.BIT18CNT_2          := IBIT18CNT_2;              --31.  2年　障害・情緒の数
--                r_WKRECORD001.BIT2CNT_2           := IBIT2CNT_2;               --32.  2年　外国人の数
--                r_WKRECORD001.BIT3CNT_2           := IBIT3CNT_2;               --33.  2年　下学年の数
--                r_WKRECORD001.MALECNT_3           := IMALECNT_3;               --34.  3年　男の数
--                r_WKRECORD001.FEMALECNT_3         := IFEMALECNT_3;             --35.  3年　女の数
--                r_WKRECORD001.MALE_FEMALE_CNT3    := IMALE_FEMALE_CNT3;        --36.  3年　男女の数
--                r_WKRECORD001.FUTSU_GAKYU_3       := IFUTSU_GAKYU_3;           --37.  3年　普通学級の数
--                r_WKRECORD001.BIT11CNT_3          := IBIT11CNT_3;              --38.  3年　障害・知的の数
--                r_WKRECORD001.BIT12CNT_3          := IBIT12CNT_3;              --39.  3年　障害・肢体の数
--                r_WKRECORD001.BIT13CNT_3          := IBIT13CNT_3;              --40.  3年　障害・病弱の数
--                r_WKRECORD001.BIT14CNT_3          := IBIT14CNT_3;              --41.  3年　障害・院内の数
--                r_WKRECORD001.BIT15CNT_3          := IBIT15CNT_3;              --42.  3年　障害・弱視の数
--                r_WKRECORD001.BIT16CNT_3          := IBIT16CNT_3;              --43.  3年　障害・難聴の数
--                r_WKRECORD001.BIT17CNT_3          := IBIT17CNT_3;              --44.  3年　障害・言語の数
--                r_WKRECORD001.BIT18CNT_3          := IBIT18CNT_3;              --45.  3年　障害・情緒の数
--                r_WKRECORD001.BIT2CNT_3           := IBIT2CNT_3;               --46.  3年　外国人の数
--                r_WKRECORD001.BIT3CNT_3           := IBIT3CNT_3;               --47.  3年　下学年の数
--                r_WKRECORD001.MALECNT_4           := IMALECNT_4;               --48.  4年　男の数
--                r_WKRECORD001.FEMALECNT_4         := IFEMALECNT_4;             --49.  4年　女の数
--                r_WKRECORD001.MALE_FEMALE_CNT4    := IMALE_FEMALE_CNT4;        --50.  4年　男女の数
--                r_WKRECORD001.FUTSU_GAKYU_4       := IFUTSU_GAKYU_4;           --51.  4年　普通学級の数
--                r_WKRECORD001.BIT11CNT_4          := IBIT11CNT_4;              --52.  4年　障害・知的の数
--                r_WKRECORD001.BIT12CNT_4          := IBIT12CNT_4;              --53.  4年　障害・肢体の数
--                r_WKRECORD001.BIT13CNT_4          := IBIT13CNT_4;              --54.  4年　障害・病弱の数
--                r_WKRECORD001.BIT14CNT_4          := IBIT14CNT_4;              --55.  4年　障害・院内の数
--                r_WKRECORD001.BIT15CNT_4          := IBIT15CNT_4;              --56.  4年　障害・弱視の数
--                r_WKRECORD001.BIT16CNT_4          := IBIT16CNT_4;              --57.  4年　障害・難聴の数
--                r_WKRECORD001.BIT17CNT_4          := IBIT17CNT_4;              --58.  4年　障害・言語の数
--                r_WKRECORD001.BIT18CNT_4          := IBIT18CNT_4;              --59.  4年　障害・情緒の数
--                r_WKRECORD001.BIT2CNT_4           := IBIT2CNT_4;               --60.  4年　外国人の数
--                r_WKRECORD001.BIT3CNT_4           := IBIT3CNT_4;               --61.  4年　下学年の数
--                r_WKRECORD001.MALECNT_5           := IMALECNT_5;               --62.  5年　男の数
--                r_WKRECORD001.FEMALECNT_5         := IFEMALECNT_5;             --63.  5年　女の数
--                r_WKRECORD001.MALE_FEMALE_CNT5    := IMALE_FEMALE_CNT5;        --64.  5年　男女の数
--                r_WKRECORD001.FUTSU_GAKYU_5       := IFUTSU_GAKYU_5;           --65.  5年　普通学級の数
--                r_WKRECORD001.BIT11CNT_5          := IBIT11CNT_5;              --66.  5年　障害・知的の数
--                r_WKRECORD001.BIT12CNT_5          := IBIT12CNT_5;              --67.  5年　障害・肢体の数
--                r_WKRECORD001.BIT13CNT_5          := IBIT13CNT_5;              --68.  5年　障害・病弱の数
--                r_WKRECORD001.BIT14CNT_5          := IBIT14CNT_5;              --69.  5年　障害・院内の数
--                r_WKRECORD001.BIT15CNT_5          := IBIT15CNT_5;              --70.  5年　障害・弱視の数
--                r_WKRECORD001.BIT16CNT_5          := IBIT16CNT_5;              --71.  5年　障害・難聴の数
--                r_WKRECORD001.BIT17CNT_5          := IBIT17CNT_5;              --72.  5年　障害・言語の数
--                r_WKRECORD001.BIT18CNT_5          := IBIT18CNT_5;              --73.  5年　障害・情緒の数
--                r_WKRECORD001.BIT2CNT_5           := IBIT2CNT_5;               --74.  5年　外国人の数
--                r_WKRECORD001.BIT3CNT_5           := IBIT3CNT_5;               --75.  5年　下学年の数
--                r_WKRECORD001.MALECNT_6           := IMALECNT_6;               --76.  6年　男の数
--                r_WKRECORD001.FEMALECNT_6         := IFEMALECNT_6;             --77.  6年　女の数
--                r_WKRECORD001.MALE_FEMALE_CNT6    := IMALE_FEMALE_CNT6;        --78.  6年　男女の数
--                r_WKRECORD001.FUTSU_GAKYU_6       := IFUTSU_GAKYU_6;           --79.  6年　普通学級の数
--                r_WKRECORD001.BIT11CNT_6          := IBIT11CNT_6;              --80.  6年　障害・知的の数
--                r_WKRECORD001.BIT12CNT_6          := IBIT12CNT_6;              --81.  6年　障害・肢体の数
--                r_WKRECORD001.BIT13CNT_6          := IBIT13CNT_6;              --82.  6年　障害・病弱の数
--                r_WKRECORD001.BIT14CNT_6          := IBIT14CNT_6;              --83.  6年　障害・院内の数
--                r_WKRECORD001.BIT15CNT_6          := IBIT15CNT_6;              --84.  6年　障害・弱視の数
--                r_WKRECORD001.BIT16CNT_6          := IBIT16CNT_6;              --85.  6年　障害・難聴の数
--                r_WKRECORD001.BIT17CNT_6          := IBIT17CNT_6;              --86.  6年　障害・言語の数
--                r_WKRECORD001.BIT18CNT_6          := IBIT18CNT_6;              --87.  6年　障害・情緒の数
--                r_WKRECORD001.BIT2CNT_6           := IBIT2CNT_6;               --88.  6年　外国人の数
--                r_WKRECORD001.BIT3CNT_6           := IBIT3CNT_6;               --89.  6年　下学年の数
--                r_WKRECORD001.MALECNT             := NVL(IMALECNT,0);          --90.  「１年　男の数」～「６年　男の数」の合計
--                r_WKRECORD001.FEMALECNT           := NVL(IFEMALECNT,0);        --91.  「１年　女の数」～「６年　女の数」の合計
--                r_WKRECORD001.MALE_FEMALE_CNT     := NVL(IMALE_FEMALE_CNT,0);  --92.  「男子計」＋「女子計」
--                r_WKRECORD001.FUTSU_GAKYU         := NVL(IFUTSU_GAKYU,0);      --93.  「１年　普通学級の数」～「６年　普通学級の数」の合計
--                r_WKRECORD001.BIT11CNT            := NVL(IBIT11CNT,0);         --94.  「１年　障害・知的の数」～「６年　障害・知的の数」の合計
--                r_WKRECORD001.BIT12CNT            := NVL(IBIT12CNT,0);         --95.  「１年　障害・肢体の数」～「６年　障害・肢体の数」の合計
--                r_WKRECORD001.BIT13CNT            := NVL(IBIT13CNT,0);         --96.  「１年　障害・病弱の数」～「６年　障害・病弱の数」の合計
--                r_WKRECORD001.BIT14CNT            := NVL(IBIT14CNT,0);         --97.  「１年　障害・院内の数」～「６年　障害・院内の数」の合計
--                r_WKRECORD001.BIT15CNT            := NVL(IBIT15CNT,0);         --98.  「１年　障害・弱視の数」～「６年　障害・弱視の数」の合計
--                r_WKRECORD001.BIT16CNT            := NVL(IBIT16CNT,0);         --99.  「１年　障害・難聴の数」～「６年　障害・難聴の数」の合計
--                r_WKRECORD001.BIT17CNT            := NVL(IBIT17CNT,0);         --100. 「１年　障害・言語の数」～「６年　障害・言語の数」の合計
--                r_WKRECORD001.BIT18CNT            := NVL(IBIT18CNT,0);         --101. 「１年　障害・情緒の数」～「６年　障害・情緒の数」の合計
--                r_WKRECORD001.BITSUM              := NVL(IBITSUM,0);           --102.  障害児合計
--                r_WKRECORD001.JIDO_SUM            := NVL(IJIDOSUM,0);          --103.  児童生徒数合計
--                r_WKRECORD001.TOKU_GAKYU          := NVL(ITOKU_GAKYU,0);       --104. 「障害児合計」／　特殊クラス人数
--                r_WKRECORD001.FUSTUS_TOKU_SUM     := NVL(IFUSTUS_TOKU_SUM,0);  --105. 「普通学級の合計」＋「障害児学級数合計」
--                r_WKRECORD001.BIT2CNT             := NVL(IBIT2CNT,0);          --106. 「１年　外国人の数」～「６年　外国人の数」の合計
--                r_WKRECORD001.BIT3CNT             := NVL(IBIT3CNT,0);          --107. 「１年　下学年の数」～「６年　下学年の数」の合計
-- 2024/07/12 ZCZL.qinyue Delete end
-- 2024/07/12 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
               r_WKRECORD001.GAKUKYU1            := '１年';
               r_WKRECORD001.GAKUKYU2            := '２年';
               r_WKRECORD001.GAKUKYU3            := '３年';
               IF CUR1.GAKUNEN_CD IN(7,8,9) THEN
                 r_WKRECORD001.GAKUKYU4          := NULL;
                 r_WKRECORD001.GAKUKYU5          := NULL;
                 r_WKRECORD001.GAKUKYU6          := NULL;
--  2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応
               r_WKRECORD001.MALE1               := MALE1;
               r_WKRECORD001.MALE2               := MALE2;
               r_WKRECORD001.MALE3               := MALE3;
               r_WKRECORD001.MALEALL             := MALEALL;
               r_WKRECORD001.FEMALE1             := FEMALE1;
               r_WKRECORD001.FEMALE2             := FEMALE2;
               r_WKRECORD001.FEMALE3             := FEMALE3;
               r_WKRECORD001.FEMALEALL           := FEMALEALL;
               r_WKRECORD001.FEMALE1             := FEMALE1;
               r_WKRECORD001.FEMALE2             := FEMALE2;
               r_WKRECORD001.FEMALE3             := FEMALE3;
               r_WKRECORD001.FEMALEALL           := FEMALEALL;
               r_WKRECORD001.MALEFEMALE1         := MALEFEMALE1;
               r_WKRECORD001.MALEFEMALE2         := MALEFEMALE2;
               r_WKRECORD001.MALEFEMALE3         := MALEFEMALE3;
               r_WKRECORD001.FUTSUMALE1          := FUTSUMALE1;
               r_WKRECORD001.FUTSUMALE2          := FUTSUMALE2;
               r_WKRECORD001.FUTSUMALE3          := FUTSUMALE3;
               r_WKRECORD001.FUTSUMALEALL        := FUTSUMALEALL;
               r_WKRECORD001.FUTSUFEMALE1        := FUTSUFEMALE1;
               r_WKRECORD001.FUTSUFEMALE2        := FUTSUFEMALE2;
               r_WKRECORD001.FUTSUFEMALE3        := FUTSUFEMALE3;
               r_WKRECORD001.FUTSUFEMALEALL      := FUTSUFEMALEALL;
               r_WKRECORD001.TOKUBETSUMALE1      := TOKUBETSUMALE1;
               r_WKRECORD001.TOKUBETSUMALE2      := TOKUBETSUMALE2;
               r_WKRECORD001.TOKUBETSUMALE3      := TOKUBETSUMALE3;
               r_WKRECORD001.TOKUBETSUMALEALL    := TOKUBETSUMALEALL;
               r_WKRECORD001.TOKUBETSUFEMALE1    := TOKUBETSUFEMALE1;
               r_WKRECORD001.TOKUBETSUFEMALE2    := TOKUBETSUFEMALE2;
               r_WKRECORD001.TOKUBETSUFEMALE3    := TOKUBETSUFEMALE3;
               r_WKRECORD001.TOKUBETSUFEMALEALL  := TOKUBETSUFEMALEALL;
--  2025/05/16 CTC.HJF UPDATE End
               ELSE
                 r_WKRECORD001.GAKUKYU4          := '４年';
                 r_WKRECORD001.GAKUKYU5          := '５年';
                 r_WKRECORD001.GAKUKYU6          := '６年';
--  2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応
               r_WKRECORD001.MALE1               := MALE1;
               r_WKRECORD001.MALE2               := MALE2;
               r_WKRECORD001.MALE3               := MALE3;
               r_WKRECORD001.MALE4               := MALE4;
               r_WKRECORD001.MALE5               := MALE5;
               r_WKRECORD001.MALE6               := MALE6;
               r_WKRECORD001.MALEALL             := MALEALL;
               
               r_WKRECORD001.FEMALE1             := FEMALE1;
               r_WKRECORD001.FEMALE2             := FEMALE2;
               r_WKRECORD001.FEMALE3             := FEMALE3;
               r_WKRECORD001.FEMALE4             := FEMALE4;
               r_WKRECORD001.FEMALE5             := FEMALE5;
               r_WKRECORD001.FEMALE6             := FEMALE6;
               r_WKRECORD001.FEMALEALL           := FEMALEALL;
               
               r_WKRECORD001.FEMALE1             := FEMALE1;
               r_WKRECORD001.FEMALE2             := FEMALE2;
               r_WKRECORD001.FEMALE3             := FEMALE3;
               r_WKRECORD001.FEMALE4             := FEMALE4;
               r_WKRECORD001.FEMALE5             := FEMALE5;
               r_WKRECORD001.FEMALE6             := FEMALE6;
               r_WKRECORD001.FEMALEALL           := FEMALEALL;
               
               r_WKRECORD001.MALEFEMALE1         := MALEFEMALE1;
               r_WKRECORD001.MALEFEMALE2         := MALEFEMALE2;
               r_WKRECORD001.MALEFEMALE3         := MALEFEMALE3;
               r_WKRECORD001.MALEFEMALE4         := MALEFEMALE4;
               r_WKRECORD001.MALEFEMALE5         := MALEFEMALE5;
               r_WKRECORD001.MALEFEMALE6         := MALEFEMALE6;
               
               r_WKRECORD001.FUTSUMALE1          := FUTSUMALE1;
               r_WKRECORD001.FUTSUMALE2          := FUTSUMALE2;
               r_WKRECORD001.FUTSUMALE3          := FUTSUMALE3;
               r_WKRECORD001.FUTSUMALE4          := FUTSUMALE4;
               r_WKRECORD001.FUTSUMALE5          := FUTSUMALE5;
               r_WKRECORD001.FUTSUMALE6          := FUTSUMALE6;
               r_WKRECORD001.FUTSUMALEALL        := FUTSUMALEALL;

               r_WKRECORD001.FUTSUFEMALE1        := FUTSUFEMALE1;
               r_WKRECORD001.FUTSUFEMALE2        := FUTSUFEMALE2;
               r_WKRECORD001.FUTSUFEMALE3        := FUTSUFEMALE3;
               r_WKRECORD001.FUTSUFEMALE4        := FUTSUFEMALE4;
               r_WKRECORD001.FUTSUFEMALE5        := FUTSUFEMALE5;
               r_WKRECORD001.FUTSUFEMALE6        := FUTSUFEMALE6;
               r_WKRECORD001.FUTSUFEMALEALL      := FUTSUFEMALEALL;
               
               r_WKRECORD001.TOKUBETSUMALE1      := TOKUBETSUMALE1;
               r_WKRECORD001.TOKUBETSUMALE2      := TOKUBETSUMALE2;
               r_WKRECORD001.TOKUBETSUMALE3      := TOKUBETSUMALE3;
               r_WKRECORD001.TOKUBETSUMALE4      := TOKUBETSUMALE4;
               r_WKRECORD001.TOKUBETSUMALE5      := TOKUBETSUMALE5;
               r_WKRECORD001.TOKUBETSUMALE6      := TOKUBETSUMALE6;

               r_WKRECORD001.TOKUBETSUMALEALL    := TOKUBETSUMALEALL;
               r_WKRECORD001.TOKUBETSUFEMALE1    := TOKUBETSUFEMALE1;
               r_WKRECORD001.TOKUBETSUFEMALE2    := TOKUBETSUFEMALE2;
               r_WKRECORD001.TOKUBETSUFEMALE3    := TOKUBETSUFEMALE3;
               r_WKRECORD001.TOKUBETSUFEMALE4    := TOKUBETSUFEMALE4;
               r_WKRECORD001.TOKUBETSUFEMALE5    := TOKUBETSUFEMALE5;
               r_WKRECORD001.TOKUBETSUFEMALE6    := TOKUBETSUFEMALE6;
               r_WKRECORD001.TOKUBETSUFEMALEALL  := TOKUBETSUFEMALEALL;
--  2025/05/16 CTC.HJF UPDATE End
               END IF;
--  2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
               --r_WKRECORD001.MALE1               := CUR1.MALE1;
               --r_WKRECORD001.MALE2               := CUR1.MALE2;
               --r_WKRECORD001.MALE3               := CUR1.MALE3;
               --r_WKRECORD001.MALE4               := CUR1.MALE4;
               --r_WKRECORD001.MALE5               := CUR1.MALE5;
               --r_WKRECORD001.MALE6               := CUR1.MALE6;
               --r_WKRECORD001.MALEALL             := CUR1.MALEALL;
               --r_WKRECORD001.FEMALE1             := CUR1.FEMALE1;
               --r_WKRECORD001.FEMALE2             := CUR1.FEMALE2;
               --r_WKRECORD001.FEMALE3             := CUR1.FEMALE3;
               --r_WKRECORD001.FEMALE4             := CUR1.FEMALE4;
               --r_WKRECORD001.FEMALE5             := CUR1.FEMALE5;
               --r_WKRECORD001.FEMALE6             := CUR1.FEMALE6;
               --r_WKRECORD001.FEMALEALL           := CUR1.FEMALEALL;
               --r_WKRECORD001.FEMALE1             := CUR1.FEMALE1;
               --r_WKRECORD001.FEMALE2             := CUR1.FEMALE2;
               --r_WKRECORD001.FEMALE3             := CUR1.FEMALE3;
               --r_WKRECORD001.FEMALE4             := CUR1.FEMALE4;
               --r_WKRECORD001.FEMALE5             := CUR1.FEMALE5;
               --r_WKRECORD001.FEMALE6             := CUR1.FEMALE6;
               --r_WKRECORD001.FEMALEALL           := CUR1.FEMALEALL;
               --r_WKRECORD001.MALEFEMALE1         := IMALEFEMALE1;
               --r_WKRECORD001.MALEFEMALE2         := IMALEFEMALE2;
               --r_WKRECORD001.MALEFEMALE3         := IMALEFEMALE3;
               --r_WKRECORD001.MALEFEMALE4         := IMALEFEMALE4;
               --r_WKRECORD001.MALEFEMALE5         := IMALEFEMALE5;
               --r_WKRECORD001.MALEFEMALE6         := IMALEFEMALE6;
               --r_WKRECORD001.FUTSUMALE1          := CUR1.FUTSUMALE1;
               --r_WKRECORD001.FUTSUMALE2          := CUR1.FUTSUMALE2;
               --r_WKRECORD001.FUTSUMALE3          := CUR1.FUTSUMALE3;
               --r_WKRECORD001.FUTSUMALE4          := CUR1.FUTSUMALE4;
               --r_WKRECORD001.FUTSUMALE5          := CUR1.FUTSUMALE5;
               --r_WKRECORD001.FUTSUMALE6          := CUR1.FUTSUMALE6;
               --r_WKRECORD001.FUTSUMALEALL        := CUR1.FUTSUMALEALL;
               --r_WKRECORD001.FUTSUFEMALE1        := CUR1.FUTSUFEMALE1;
               --r_WKRECORD001.FUTSUFEMALE2        := CUR1.FUTSUFEMALE2;
               --r_WKRECORD001.FUTSUFEMALE3        := CUR1.FUTSUFEMALE3;
               --r_WKRECORD001.FUTSUFEMALE4        := CUR1.FUTSUFEMALE4;
               --r_WKRECORD001.FUTSUFEMALE5        := CUR1.FUTSUFEMALE5;
               --r_WKRECORD001.FUTSUFEMALE6        := CUR1.FUTSUFEMALE6;
               --r_WKRECORD001.FUTSUFEMALEALL      := CUR1.FUTSUFEMALEALL;
               --r_WKRECORD001.TOKUBETSUMALE1      := CUR1.TOKUBETSUMALE1;
               --r_WKRECORD001.TOKUBETSUMALE2      := CUR1.TOKUBETSUMALE2;
               --r_WKRECORD001.TOKUBETSUMALE3      := CUR1.TOKUBETSUMALE3;
               --r_WKRECORD001.TOKUBETSUMALE4      := CUR1.TOKUBETSUMALE4;
               --r_WKRECORD001.TOKUBETSUMALE5      := CUR1.TOKUBETSUMALE5;
               --r_WKRECORD001.TOKUBETSUMALE6      := CUR1.TOKUBETSUMALE6;
               --r_WKRECORD001.TOKUBETSUMALEALL    := CUR1.TOKUBETSUMALEALL;
               --r_WKRECORD001.TOKUBETSUFEMALE1    := CUR1.TOKUBETSUFEMALE1;
               --r_WKRECORD001.TOKUBETSUFEMALE2    := CUR1.TOKUBETSUFEMALE2;
               --r_WKRECORD001.TOKUBETSUFEMALE3    := CUR1.TOKUBETSUFEMALE3;
               --r_WKRECORD001.TOKUBETSUFEMALE4    := CUR1.TOKUBETSUFEMALE4;
               --r_WKRECORD001.TOKUBETSUFEMALE5    := CUR1.TOKUBETSUFEMALE5;
               --r_WKRECORD001.TOKUBETSUFEMALE6    := CUR1.TOKUBETSUFEMALE6;
               --r_WKRECORD001.TOKUBETSUFEMALEALL  := CUR1.TOKUBETSUFEMALEALL;
--  2025/05/16 CTC.HJF Delete End
               IF CUR1.GAKKO_KBN_CD = 1 THEN
               --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:ST_GKB_TMP00008対応 Start
                 --IF KKAPK0030.FCDGetR('GKB', '023', '0001', CUR1.SHOGAKKO_CD, sMEISHO, sMEISHOKANA, sYOBI) = 0 THEN
                 IF KKAPK0030.FCDGetR('GKB', '023', '0001', LPAD(CUR1.SHOGAKKO_CD, 5, '0'), sMEISHO, sMEISHOKANA, sYOBI) = 0 THEN
               --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:ST_GKB_TMP00008対応 End
                   r_WKRECORD001.GAKKU := sMEISHO;
                 END IF;
               ELSIF CUR1.GAKKO_KBN_CD = 2 THEN
               --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:ST_GKB_TMP00008対応 Start
                 --IF KKAPK0030.FCDGetR('GKB', '023', '0002', CUR1.CHUGAKKOKU_CD, sMEISHO, sMEISHOKANA, sYOBI) = 0 THEN
                 IF KKAPK0030.FCDGetR('GKB', '023', '0002', LPAD(CUR1.CHUGAKKOKU_CD, 5, '0'), sMEISHO, sMEISHOKANA, sYOBI) = 0 THEN
               --  2025/02/04 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:ST_GKB_TMP00008対応 End
                   r_WKRECORD001.GAKKU := sMEISHO;
                 END IF;                 
               ELSE
                 r_WKRECORD001.GAKKU := NULL;
               END IF;
               
               IF CRATENA_WORK.OAZA_CD IS NULL OR CRATENA_WORK.GYOSEIKU_CD IS NULL THEN
                 r_WKRECORD001.CHIIKIMEI := NULL;
               ELSE
                 nRTN := KKAPK0030.FCTGetR('GKB', '00GAKKU_KANRI', '0000', 0, aPRM);
                 IF nRTN = 0 THEN
                   FOR i IN 1..aPRM.COUNT LOOP
                     IF aPRM(i) = '0' THEN
                       VOAZANM := GAAPK0030.FOAZAMEI(CRATENA_WORK.SANTEIDANTAI_CD,CRATENA_WORK.OAZA_CD);
                       r_WKRECORD001.CHIIKIMEI := VOAZANM;                  
                     ELSIF aPRM(i) = '1' THEN
                       VGYOSEIKU := GAAPK0030.FGYOSEIKUMEI(CRATENA_WORK.SANTEIDANTAI_CD,CRATENA_WORK.GYOSEIKU_CD);
                       r_WKRECORD001.CHIIKIMEI := VGYOSEIKU;  
                     END IF;
                   END LOOP;
                 END IF;
               END IF;
               r_WKRECORD001.GAKKU_CD            := CUR1.GAKOKU_CD;
               IF CUR1.GAKKO_KBN_CD = 1 THEN
                  r_WKRECORD001.GAKKOU_CD         := CUR1.SHOGAKKO_CD;
               END IF;
               IF CUR1.GAKKO_KBN_CD = 2 THEN
                  r_WKRECORD001.GAKKOU_CD         := CUR1.CHUGAKKO_CD;
               END IF;
               IF CUR1.GAKKO_KBN_CD = 3 THEN
                  r_WKRECORD001.GAKKOU_CD         := CUR1.KUIKIGAI_CD;
               END IF;
               IF CUR1.GAKKO_KBN_CD = 4 THEN
                  r_WKRECORD001.GAKKOU_CD         := CUR1.YOGOGAKO_CD;
               END IF;
               IF CUR1.GAKKO_KBN_CD = 5 THEN
                  r_WKRECORD001.GAKKOU_CD         := CUR1.KUNISHIRITSU_CD;
               END IF;    
               r_WKRECORD001.CHIIKI_CD           := CUR1.GYOSEIKU_CD;
-- 2024/07/12 ZCZL.qinyue Add end
-- 2024/07/12 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--                r_WKRECORD001.BREAK_NO            := NULL;
--  2024/09/02 ZCZL.WANGMING UPDATE 0.3.000.002:8月1日認識合わせの横展開
--               r_WKRECORD001.BREAK_NO            := CUR1.GAKOKU_CD || LPAD(CUR1.GAKOKU_CD, 5, '0');
--  2025/05/16 CTC.HJF Delete Start 1.0.004.000:GKB_QA12945対応
               --r_WKRECORD001.BREAK_NO            := LPAD(CUR1.GAKOKU_CD, 5, '0');
--  2025/05/16 CTC.HJF Delete End
--  2025/06/11 CTC.HJF UPDATE Start 1.0.008.000:GKB_QA15686対応
--  2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応
               --r_WKRECORD001.BREAK_NO            := LPAD(CUR1.GAKKO_KBN_CD, 5, '0');
               r_WKRECORD001.BREAK_NO            := LPAD(KAIPAGEFLAG, 5, '0');
--  2025/05/16 CTC.HJF UPDATE End
--  2025/06/11 CTC.HJF UPDATE End
               r_WKRECORD001.WSNUM               := g_sWSNUM;
               r_WKRECORD001.BATCHKBN            := c_BATCH;
               r_WKRECORD001.JOBNUM              := g_nJOBNUM;
               INSERT INTO GKBWL350R001 VALUES r_WKRECORD001;
--  2025/05/16 CTC.HJF UPDATE Start 1.0.004.000:GKB_QA12945対応
END IF;
--  2025/05/16 CTC.HJF UPDATE End
          END LOOP;
          --  2024/09/02 ZCZL.WANGMING ADD 0.3.000.002:8月1日認識合わせの横展開
          CLOSE CUR_WK_JIDO_ZAIGAKI;
        EXCEPTION
            WHEN OTHERS THEN
                --  2024/09/02 ZCZL.WANGMING ADD START 0.3.000.002:8月1日認識合わせの横展開
                IF CUR_WK_JIDO_ZAIGAKI%ISOPEN THEN
                    CLOSE CUR_WK_JIDO_ZAIGAKI;
                END IF;
                --  2024/09/02 ZCZL.WANGMING ADD END
                FRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SEITOSHUKEI_CSV_CREATE', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        RETURN FRET;
    END FUNC_SEITOSHUKEI_CSV_CREATE;
  
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        EXCP             EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        --複数な帳票の場合、該当ロジックあり
        --変数の初期について、該当処理内作成しますか？判断要
        --帳票IDに関連な変数にIF内で書く
        IF g_nSTEP_INDEX = 1 THEN
          IRTN  := 0;
          --------------------------------------------------------------------------------
          -- メイン処理                                                                 --
          --------------------------------------------------------------------------------
--  2024/04/22 ZCZL.WUCAO DELETE 0.2.000.001:512_GKB_00027対応
--          BEGIN
              DELETE FROM GKBWL350R001 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
              DELETE FROM GKBWL350R002 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
              -- 処理条件のワーク領域を初期化
              PROCHAICLR;
              -- 取得した条件をそれぞれの変数へセット
              VNENDO := KKAPK0020.FNENDO(g_vJYOUKEN1,1);                 -- 対象年度
              VKIJYUNBI := g_vJYOUKEN2;                                  -- 基準日
--  2024/11/14 ZCZL.WANGYUNING DELETE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応              
              --IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN3,VSYOGAKO_CD);      -- 小学校コード
              --IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN4,VTYUGAKO_CD);      -- 中学校コード
              --IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN5,VKUIKIGAI_CD);     -- 区域外学校コード
              --IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN6,VYOGOGAKO_CD);     -- 盲聾養護学校コード
-- 2024/07/12 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
              --IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN9,VKUNISHIRITSU_CD);     -- 国私立学校コード
--  2024/11/14 ZCZL.WANGYUNING DELETE END
-- 2024/07/12 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
              IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN9,VKUNISHIRITSU_CD);     -- 国私立学校コード
              VNINIBIT := g_vJYOUKEN7;                                   -- 任意ビット項目
              VFLAG := TO_NUMBER(g_vJYOUKEN8);                           -- 一覧出力フラグ

              ISEIREKIHIZUKE := 0;
              IWAREKIHIZUKE := VKIJYUNBI;
              BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                          VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                          VEDIT_GYYMMDD3, VKJ_GENGO,
                                          VKG_GENGO,      IWAREKI_YY,
                                          ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                          IMM,            IDD,
                                          IWAREKIHIZUKE,  ISEIREKIHIZUKE );
              KIJUN_BI := VEDIT_GYYMMDD3;
              KIJUN_BI2 := ISEIREKIHIZUKE;
--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応    
        END IF;
              -- 児童生徒ワーク（GKBWJIDOZAIGAKU）のデータ全件削除
              I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
              IF B_RTN = c_BERROR THEN
                  -- エラーで帰ってきた場合
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
                  RETURN FALSE;
              END IF;

              IRTN_CLASS := KKAPK0030.FPRMSHUTOKU('GKB','00NINZU',0,ACONSPRM_CLASS,NLENGTH);
              IF IRTN_CLASS = 1 THEN
                 ACONSPRM_CLASS := A_CONS_PRM();
                 ACONSPRM_CLASS.EXTEND;
                 ACONSPRM_CLASS.EXTEND;
                 ACONSPRM_CLASS(1) := 40;
                 ACONSPRM_CLASS.EXTEND;
                 ACONSPRM_CLASS(2) := 8;
              ELSIF NLENGTH = 0 THEN
                 ACONSPRM_CLASS.EXTEND;
                 ACONSPRM_CLASS.EXTEND;
                 ACONSPRM_CLASS(1) := 40;
                 ACONSPRM_CLASS.EXTEND;
                 ACONSPRM_CLASS(2) := 8;
                 NLENGTH := 2;
              ELSIF NLENGTH = 1 THEN
                 ACONSPRM_CLASS.EXTEND;
                 ACONSPRM_CLASS(2) := 8;
                 NLENGTH := 2;
              END IF;
              IFUTSU_NINZU := ACONSPRM_CLASS(1);
              ITOKU_NINZU := ACONSPRM_CLASS(2);

              -- 児童生徒中間データ作成
              I_RTN := FUNC_GET_JIDO_WK;
              IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
                  IF I_RTN = c_INOTFOUND THEN
                      -- 対象データ無しの場合は異常終了させない
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--                       bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
                       GOTO PGM_SHORI_END;
                  END IF;
                  RAISE EXCP;
              END IF;
--  2024/04/22 ZCZL.WUCAO DELETE START 0.2.000.001:512_GKB_00027対応
--              bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
--          EXCEPTION
--              /* その他エラー */
--              WHEN OTHERS THEN
--                  -- SQL情報取得
--                  N_SQL_CODE := SQLCODE;
--                  V_SQL_MSG  := SUBSTR(SQLERRM, 1 ,250);
--                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
--                  IRTN := c_ERR;
--                  GOTO PGM_SHORI_ERR;
--          END;
--        END IF;
--  2024/04/22 ZCZL.WUCAO DELETE END
        -- 児童生徒中間データ作成（ＣＳＶ用）
        I_RTN := FUNC_GET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
           -- エラーで帰ってきた場合
          RAISE EXCP;
        END IF;
              
        --CSVデータの作成
        CASE g_rJSTP.Chohyoid
          WHEN 'GKB350R001' THEN
              --ワークテーブルのデータを削除する
              -- 生徒集計表ＣＳＶデータ作成
              I_RTN := FUNC_SEITOSHUKEI_CSV_CREATE;
              IF I_RTN <> c_ISUCCESS THEN
                  -- エラーで帰ってきた場合
                  RAISE EXCP;
              END IF;
          WHEN 'GKB350R002' THEN
              --ワークテーブルのデータを削除する
              -- 児童生徒中間ＣＳＶデータ作成(一覧)
              IF VFLAG = 0 THEN
                 I_RTN := FUNC_SET_JIDO_WK_CSVFILE;
              END IF;
              IF I_RTN <> c_ISUCCESS THEN
                  -- エラーで帰ってきた場合
                  RAISE EXCP;
              END IF;
          ELSE
            NULL;
        END CASE;
        --異常の場合、この標示に移動する
        <<PGM_SHORI_ERR>>
        --帳票出力CSVの作成
        CASE g_rJSTP.Chohyoid
          WHEN 'GKB350R001' THEN
            bRTN := FUNC_B11CSV('GKBWL350R001');
          WHEN 'GKB350R002' THEN
            bRTN := FUNC_B11CSV('GKBWL350R002');
          ELSE
            NULL;
        END CASE;
        --最後ロジックの実行
        --ROLLBACKの処理、と件数表の値、既存の最後更新、削除処理等
        IF g_nSTEP_INDEX = g_nSTEP_MAX THEN
          IF IRTN = c_OK THEN
             COMMIT;
          ELSE
            RAISE EXCP;
          END IF;
        END IF;
--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
       <<PGM_SHORI_END>>
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/03
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
END GKBPB00340;
/
