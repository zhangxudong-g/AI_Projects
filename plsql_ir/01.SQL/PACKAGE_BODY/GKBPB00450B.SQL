CREATE OR REPLACE PACKAGE BODY GKBPB00450
--1.0.205.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB(教育)
--  プログラム名  : 校区別在学者一覧表
--  機能概要      : 学年単位で児童・生徒の一覧表を作成する。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.CONGDAN 2024/01/04
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/06/14 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--  2024/09/02 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00427対応
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00664対応
--  2025/01/20 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:ST_GKB_00001対応
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE 1.0.105.000:GKB_QA20560対応
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
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
    g_ZAIGAKUMID_INDEXNO          NUMBER;               --校区別在学者一覧_インデックス番号
    g_GAIKOKUSEKIJIDOU_INDEXNO    NUMBER;               --外国籍児童一覧_インデックス番号
    g_GAIKOKUSEKISEIYO_INDEXNO    NUMBER;               --外国籍生徒一覧_インデックス番号
    g_ZAIGAKUMIDSEIGYO            NVARCHAR2(1000);      --校区別在学者一覧_出力制御
    g_GAIKOKUSEKIJIDOUSEIGYO      NVARCHAR2(1000);      --外国籍児童一覧_出力制御
    g_GAIKOKUSEKISEIYOSEIGYO      NVARCHAR2(1000);      --外国籍生徒一覧_出力制御
    g_nINDEX                      NUMBER := 0;
-- 2024/06/12 ZCZL.wangyunhan Add end 
--  2024/09/02 ZCZL.WANGMING ADD 0.3.000.001:8月1日認識合わせの横展開
    KENSUU_COUNT                    NUMBER;             --変数.校区別在学者一覧ＣＳＶ件数
    --パラメータ変数
    VMSG NVARCHAR2(4000);
    IRTN PLS_INTEGER ;
    ICHK1 PLS_INTEGER ;
    ICHK2 PLS_INTEGER ;
    ICHK3 PLS_INTEGER ;
    IKIJUN_NENDO  PLS_INTEGER ;
    ISYS_NENDO    PLS_INTEGER ;
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
      TYPE CRATENA_TYPE IS RECORD
      (
        KOJIN_NO             GKBTGAKUREIBO.KOJIN_NO%TYPE,
        RIREKI_RENBAN        GKBTGAKUREIBO.RIREKI_RENBAN%TYPE,
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--         NINIBIT1             GKBTNINIBIT.NINIBIT1%TYPE,
--         NINIBIT2             GKBTNINIBIT.NINIBIT2%TYPE,
--         NINIBIT3             GKBTNINIBIT.NINIBIT3%TYPE,
--         NINIBIT4             GKBTNINIBIT.NINIBIT4%TYPE,
--         NINIBIT5             GKBTNINIBIT.NINIBIT5%TYPE,
--         NINIBIT6             GKBTNINIBIT.NINIBIT6%TYPE,
--         NINIBIT7             GKBTNINIBIT.NINIBIT7%TYPE,
--         NINIBIT8             GKBTNINIBIT.NINIBIT8%TYPE,
--         NINIBIT9             GKBTNINIBIT.NINIBIT9%TYPE,
--         NINIBIT10            GKBTNINIBIT.NINIBIT10%TYPE,
--         NINIBIT11            GKBTNINIBIT.NINIBIT11%TYPE,
--         NINIBIT12            GKBTNINIBIT.NINIBIT12%TYPE,
--         NINIBIT13            GKBTNINIBIT.NINIBIT13%TYPE,
--         NINIBIT14            GKBTNINIBIT.NINIBIT14%TYPE,
--         NINIBIT15            GKBTNINIBIT.NINIBIT15%TYPE,
--         NINIBIT16            GKBTNINIBIT.NINIBIT16%TYPE,
--         NINIBIT17            GKBTNINIBIT.NINIBIT17%TYPE,
--         NINIBIT18            GKBTNINIBIT.NINIBIT18%TYPE,
--         NINIBIT19            GKBTNINIBIT.NINIBIT19%TYPE,
--         NINIBIT20            GKBTNINIBIT.NINIBIT20%TYPE,
        RIREKI_RENBAN_EDA     GKBTGAKUREIBO.RIREKI_RENBAN_EDA%TYPE,
-- 2024/06/12 ZCZL.wangyunhan Update end 
        GAKUNEN              GKBTGAKUREIBO.GAKUNEN%TYPE
      );
        CRATENA_WORK CRATENA_TYPE;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        TYPE TYPECURSOR  IS REF CURSOR;
        TYPE JIDOZAIGAKU_TYPE IS RECORD
      (
        JIDO_KOJIN_NO               GKBWJIDOZAIGAKU.JIDO_KOJIN_NO%TYPE,
        JIDO_SHIMEI_KANA            GKBWJIDOZAIGAKU.JIDO_SHIMEI_KANA%TYPE,
        JIDO_SHIMEI_KANJI           GKBWJIDOZAIGAKU.JIDO_SHIMEI_KANJI%TYPE,
        SEINENGAPI                  GKBWJIDOZAIGAKU.SEINENGAPI%TYPE,
        HYOJI_SEINENGAPI            GKBWJIDOZAIGAKU.HYOJI_SEINENGAPI%TYPE,
        SEIBETSU                    GKBWJIDOZAIGAKU.SEIBETSU%TYPE,
        HYOJI_SEIBETSU              GKBWJIDOZAIGAKU.HYOJI_SEIBETSU%TYPE,
        ZOKUGARAMEI1                GKBWJIDOZAIGAKU.ZOKUGARAMEI1%TYPE,
        SETAI_NO                    GKBWJIDOZAIGAKU.SETAI_NO%TYPE,
        HYOJI_SETAI_NO              GKBWJIDOZAIGAKU.HYOJI_SETAI_NO%TYPE,
        HOGOSHA_KOJIN_NO            GKBWJIDOZAIGAKU.HOGOSHA_KOJIN_NO%TYPE,
        HOGOSHA_SHIMEI_KANA         GKBWJIDOZAIGAKU.HOGOSHA_SHIMEI_KANA%TYPE,
        HOGOSHA_SHIMEI_KANJI        GKBWJIDOZAIGAKU.HOGOSHA_SHIMEI_KANJI%TYPE,
        ZOKUGARAMEI2                GKBWJIDOZAIGAKU.ZOKUGARAMEI2%TYPE,
        GAKUNEN_CD                  GKBWJIDOZAIGAKU.GAKUNEN_CD%TYPE,
        GAKUNENMEI                  GKBWJIDOZAIGAKU.GAKUNENMEI%TYPE,
        GAKOKU_CD                   GKBWJIDOZAIGAKU.GAKOKU_CD%TYPE,
        GAKOKUMEI                   GKBWJIDOZAIGAKU.GAKOKUMEI%TYPE,
        GYOSEIKU_CD                 GKBWJIDOZAIGAKU.GYOSEIKU_CD%TYPE,
        GYOSEIKUMEI                 GKBWJIDOZAIGAKU.GYOSEIKUMEI%TYPE,
        HAN_CD                      GKBWJIDOZAIGAKU.HAN_CD%TYPE,
        HANMEI                      GKBWJIDOZAIGAKU.HANMEI%TYPE,
        SANTEIDANTAI_CD             GKBWJIDOZAIGAKU.SANTEIDANTAI_CD%TYPE,
        SANTEIDANTAIMEI             GKBWJIDOZAIGAKU.SANTEIDANTAIMEI%TYPE,
        YUBIN_NO                    GKBWJIDOZAIGAKU.YUBIN_NO%TYPE,
        CHOMEI                      GKBWJIDOZAIGAKU.CHOMEI%TYPE,
        BANCHI                      GKBWJIDOZAIGAKU.BANCHI%TYPE,
        KATAGAKI                    GKBWJIDOZAIGAKU.KATAGAKI%TYPE,
        NENDO                       GKBWJIDOZAIGAKU.NENDO%TYPE,
        KAIPEJI_CD                  GKBWJIDOZAIGAKU.KAIPEJI_CD%TYPE,
        KAIPEJI                     GKBWJIDOZAIGAKU.KAIPEJI%TYPE,
        SAKUSEIBI                   GKBWJIDOZAIGAKU.SAKUSEIBI%TYPE,
        RENBAN                      GKBWJIDOZAIGAKU.RENBAN%TYPE,
        HYOJI_RENBAN                GKBWJIDOZAIGAKU.HYOJI_RENBAN%TYPE,
        HOGOSHA_SHIMEI_JODAN        GKBWJIDOZAIGAKU.HOGOSHA_SHIMEI_JODAN%TYPE,
        HOGOSHA_SHIMEI_GEDAN        GKBWJIDOZAIGAKU.HOGOSHA_SHIMEI_GEDAN%TYPE,
        KON_JUSHO_JODAN             GKBWJIDOZAIGAKU.KON_JUSHO_JODAN%TYPE,
        KON_JUSHO_GEDAN             GKBWJIDOZAIGAKU.KON_JUSHO_GEDAN%TYPE,
        JINKAKU_KBN                 GKBWJIDOZAIGAKU.JINKAKU_KBN%TYPE,
        KIJUNBI                     GKBWJIDOZAIGAKU.KIJUNBI%TYPE,
        GAKKO_CD                    GKBWJIDOZAIGAKU.GAKKO_CD%TYPE,
        GAKKOMEI                    GKBWJIDOZAIGAKU.GAKKOMEI%TYPE,
        JIDO_KOKUSEKI               GKBWJIDOZAIGAKU.JIDO_KOKUSEKI%TYPE,
        HOGOSHA_KOKUSEKI            GKBWJIDOZAIGAKU.HOGOSHA_KOKUSEKI%TYPE,
        BIKO                        GKBWJIDOZAIGAKU.BIKO%TYPE
      );
-- 2024/06/12 ZCZL.wangyunhan Add end
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
        -- ERROR関連 --
        -- デバック
        N_SQL_CODE      NUMBER;             -- SQLエラーコード
        V_SQL_MSG       NVARCHAR2(255);     -- SQLエラーメッセージ
        -- 処理結果
        c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
        c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
        c_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし
        -- 正常メッセージの値
        c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '在学者一覧表作成処理が正常終了しました。';
        -- エラーメッセージの値
        c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '在学者一覧表作成処理が異常終了しました。';
        -- 児童生徒ワーク
        c_VTABLE      CONSTANT  NVARCHAR2(128) := 'GKBWJIDOZAIGAKU';
        -- １頁の最大行数
        c_IMAXROWS     CONSTANT  PLS_INTEGER := 15;

    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
        ISAKUSEIBI         PLS_INTEGER;
        RG                 GKBTGAKUREIBO%ROWTYPE;
        RA                 GABTATENAKIHON%ROWTYPE;
        RB                 GABTATENAKIHON%ROWTYPE;
        RC                 GABTSOFUSAKI%ROWTYPE;
        RASO               GABTSOFUSAKI%ROWTYPE;
        IGAKO_CD           PLS_INTEGER;
        VGAKOMEI           NVARCHAR2(60);
        VSEINENGAPI        NVARCHAR2(11);
        VSEIBETSU          NVARCHAR2(2);
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--        VSETAI_NO          NVARCHAR2(7);
        VSETAI_NO          NVARCHAR2(15);
        VGYOSEIKU_MEI      NVARCHAR2(20);
        VHAN_MEI           NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00427対応
--        VSANTEIDANTAI_MEI  NVARCHAR2(20);
        VSANTEIDANTAI_MEI  GKBWJIDOZAIGAKU.SANTEIDANTAIMEI%TYPE;
        VHYOUJINENDO       NVARCHAR2(10);
        VSASKUSEIBI        NVARCHAR2(30);
        KIJUNBI2           NUMBER;
        VHOGOSHA_SHIMEI_JODAN     NVARCHAR2(100);
        VHOGOSHA_SHIMEI_GEDAN     NVARCHAR2(100);
        VJUSHO_JODAN       NVARCHAR2(30);
        VJUSHO_GEDAN       NVARCHAR2(30);
        VCNT               NVARCHAR2(6);
        VZOKUGARAMEI1      NVARCHAR2(30);
        VZOKUGARAMEI2      NVARCHAR2(30);
        VGAKUNENMEI        NVARCHAR2(20);
        NGAKUNENSEI        NUMBER;
        VGAKUNENSEI        NVARCHAR2(20);
        -- 関数用戻り値変数（外部関数からの戻り値をセット）
        BRTN               BOOLEAN;
        B_RTN              BOOLEAN;
        I_RTN              PLS_INTEGER;
        -- 処理条件（画面からの引数）
        VNENDO             NVARCHAR2(15);       -- 対象年度
        VGAKUNEN           NVARCHAR2(15);       -- 学年
        VSYURYOGAKUNEN     NVARCHAR2(15);       -- 終了学年
        KIJUNBI            NUMBER;              -- 基準日
--  2024/10/30 ZCZL.WANGYUNING UPDATE START 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
        --VSYOGAKO_CD        NVARCHAR2(1000);     -- 小学校コード
        --VTYUGAKO_CD        NVARCHAR2(1000);     -- 中学校コード
        --VKUIKIGAI_CD       NVARCHAR2(1000);     -- 区域外学校コード
        --VYOGOGAKO_CD       NVARCHAR2(1000);     -- 特別支援学校コード
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        --VSIRITUGAKO_CD     NVARCHAR2(1000);     -- 国・私立学校コード
        VSYOGAKO_CD        NVARCHAR2(3000);     -- 小学校コード
        VTYUGAKO_CD        NVARCHAR2(3000);     -- 中学校コード
        VKUIKIGAI_CD       NVARCHAR2(3000);     -- 区域外学校コード
        VYOGOGAKO_CD       NVARCHAR2(3000);     -- 特別支援学校コード
        VSIRITUGAKO_CD     NVARCHAR2(3000);     -- 国・私立学校コード
--  2024/10/30 ZCZL.WANGYUNING UPDATE END
        VSYOUGAKOKUCD      NVARCHAR2(1000);     -- 小学校区
        VCYUGAKOKUCD       NVARCHAR2(1000);     -- 中学校区区
-- 2024/06/12 ZCZL.wangyunhan Add end 
        TYPE MTHIZUKE_REC IS RECORD(
          GAKO_KBN     BINARY_INTEGER, --学校区分
          GAKO_CD      PLS_INTEGER,    --学校コード
          IN_D         PLS_INTEGER,    --入学年月日OR転入学年月日
          OUT_D        PLS_INTEGER     --転学年月日OR退学年月日OR卒業年月日
        );
        TYPE MHIZUKE_TYPE IS TABLE OF MTHIZUKE_REC INDEX BY BINARY_INTEGER;
        -- 取得したデータのワーク領域
        TYPE MTJIDO_TYPE IS TABLE OF GKBWJIDOZAIGAKU%ROWTYPE INDEX BY BINARY_INTEGER;
        MJIDO_WORK MTJIDO_TYPE;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        -- 取得したデータのワーク領域
        TYPE ZAIGAKU_TYPE IS TABLE OF GKBWZAIGAKUMID%ROWTYPE INDEX BY BINARY_INTEGER;
        ZAIGAKU_WORK ZAIGAKU_TYPE;
-- 2024/06/12 ZCZL.wangyunhan Add end 
        --画面入力条件
        g_vJYOUKEN01                  NVARCHAR2(1000);
        g_vJYOUKEN02                  NVARCHAR2(1000);
        g_vJYOUKEN03                  NVARCHAR2(1000);
        g_vJYOUKEN04                  NVARCHAR2(1000);
-- 2024/06/12 ZCZL.wangyunhan Delete 0.3.000.000:新WizLIFE２次開発
--         g_vJYOUKEN05                  NVARCHAR2(1000);
--  2024/10/30 ZCZL.WANGYUNING UPDATE START 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_vJYOUKEN06                  NVARCHAR2(1000);
        --g_vJYOUKEN07                  NVARCHAR2(1000);
        --g_vJYOUKEN08                  NVARCHAR2(1000);
        --g_vJYOUKEN09                  NVARCHAR2(1000);
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        --g_vJYOUKEN10                  NVARCHAR2(1000);
        g_vJYOUKEN06                  NVARCHAR2(3000);
        g_vJYOUKEN07                  NVARCHAR2(3000);
        g_vJYOUKEN08                  NVARCHAR2(3000);
        g_vJYOUKEN09                  NVARCHAR2(3000);
        g_vJYOUKEN10                  NVARCHAR2(3000);
--  2024/10/30 ZCZL.WANGYUNING UPDATE END
        g_vJYOUKEN11                  NVARCHAR2(1000);
        g_vJYOUKEN12                  NVARCHAR2(1000);
-- 2024/06/12 ZCZL.wangyunhan Add end 
        o_NBREAK                      NUMBER(2) := 0;

        -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
        BRTNSEINENGAPI                 BOOLEAN;
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
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--         VNINIBIT           NVARCHAR2(500);            --任意ビット項目
        ININIBIT_RET       PLS_INTEGER;               --任意ビット戻る値
       BPRMFLG_001      BOOLEAN;
       BPRMFLG_002      BOOLEAN;
       BPRMFLG_003      BOOLEAN;
       BPRMFLG_004      BOOLEAN;
       o_YMD2           NVARCHAR2(30);
       N_NAIYO_CD       GKBTSHIMEIJKN.NAIYO_CD%TYPE;
       o_SHIMEIPRM      A_CONS_PRM;   --宛先の氏名出力制御
       o_LENGTH         NUMBER;
       JINKAKU_KBN      NUMBER(1,0);
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
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

    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 開始学年と終了学年の大小チェック
    --  パラメータ    : i_VGAKUNEN1
    --                  i_VGAKUNEN2
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIKAKUCHK( i_VGAKUNEN1 IN NVARCHAR2, i_VGAKUNEN2 IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    SGAKUNEN PLS_INTEGER ;
    EGAKUNEN PLS_INTEGER ;
    BEGIN
      IRET := 0 ;
      SGAKUNEN  := TO_NUMBER( i_VGAKUNEN1 );
      EGAKUNEN  := TO_NUMBER( i_VGAKUNEN2 );
      --開始学年と終了学年の大小チェック
      IF SGAKUNEN > EGAKUNEN THEN
          IRET := 1;
      END IF;
      RETURN(IRET) ;
    END FUNCHIKAKUCHK;
    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 学年チェック
    --  パラメータ    : i_VGAKUNEN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCGAKUNENCHK( i_VGAKUNEN IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    GAKUNEN PLS_INTEGER ;
    BEGIN
      IRET := 0 ;
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
        END IF;
      END IF;

      RETURN(IRET) ;
    END FUNCGAKUNENCHK;
    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 任意ビット項目チェック
    --  パラメータ    : i_NINIBIT
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    ----------------------------------------------------------------------------------------------------
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--     FUNCTION FUNCNINIBITCHK( i_NINIBIT IN NVARCHAR2 ) RETURN NUMBER IS
--     IRET PLS_INTEGER ;
--     NINIBITSU PLS_INTEGER ;
--     GAKO_CD NUMBER;
--     BEGIN
--       IRET := 0 ;
--       BEGIN
--         IF i_NINIBIT IS NOT NULL THEN
--                  NINIBITSU := LENGTH(i_NINIBIT)/4;
--                  IF (LENGTH(i_NINIBIT)-NINIBITSU*4) <> 0 THEN
--                     IRET := 1;
--                  ELSE
--                    FOR K IN 1..NINIBITSU LOOP
--                      GAKO_CD := TO_NUMBER(SUBSTR(i_NINIBIT,4*K-3,4));
--                    END LOOP;
--                  END IF;
--         END IF;
-- 
--      EXCEPTION
--         WHEN OTHERS THEN
--           IRET := 1;
--       END;
-- 
--       RETURN(IRET) ;
--     END FUNCNINIBITCHK;
-- 2024/06/12 ZCZL.wangyunhan Delete end 
    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 年度チェック
    --  パラメータ    : i_VNENDO
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCNENDOCHK( i_VNENDO IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    INENDO NUMBER ;
    BEGIN
      IRET := 0 ;
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

      RETURN(IRET) ;
    END FUNCNENDOCHK;

    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 日付チェック
    --  パラメータ    : i_VHIZUKE
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIZUKECHK(i_VHIZUKE IN NVARCHAR2)
      RETURN NUMBER IS
      IRET      PLS_INTEGER;
      BRET      BOOLEAN;
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
          IF LENGTH(i_VHIZUKE) <> 7 OR i_VHIZUKE IS NULL THEN
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

    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 学級選択チェック
    --  パラメータ    : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    ----------------------------------------------------------------------------------------------------
     FUNCTION FUNCGAKUNENCHK1(i_IRENBAN IN NVARCHAR2) RETURN NUMBER IS
        IRET PLS_INTEGER;
      BEGIN
        IRET := 0;

        BEGIN

            IF TO_NUMBER(i_IRENBAN) IN (0, 1, 2, 3, 4, 5, 6, 7, 8, 9) OR i_IRENBAN IS NULL THEN
              IRET := 0;
            ELSE
              IRET := 1;
            END IF;
        EXCEPTION
          WHEN OTHERS THEN
            IRET := 1;
        END;

        RETURN(IRET);
      END FUNCGAKUNENCHK1;

    --------------------------------------------------------------------------------
    --  機能概要      : 学年名称編集
    --  パラメータ    : i_NGAKUNEN_CD
    --  モジュール区分: 内部関数
    --  戻り値        : 文字列
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
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
    ---------------------------------------------------------------------------------
    --  機能概要      : 基準日対象チェック
    --  パラメータ    : RG
    --                  MHIZUKE
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    ---------------------------------------------------------------------------------
    PROCEDURE PROC_CHECK_KIJUN(RG IN GKBTGAKUREIBO%ROWTYPE,MHIZUKE IN OUT MHIZUKE_TYPE)
    IS
            RG_GAKO_CD VARCHAR2(3);
            RET NUMBER;
    BEGIN
        --変数初期化
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
        --FOR IDX IN 1..4 LOOP
        FOR IDX IN 1..5 LOOP
--  2025/11/06 CTC.HJF UPDATE END
          MHIZUKE(IDX).GAKO_KBN   := 0;
          MHIZUKE(IDX).IN_D       := 0;
          MHIZUKE(IDX).OUT_D      := 0;
          MHIZUKE(IDX).GAKO_CD    := 0;   
        END LOOP;
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
    ---- 条件６～条件９が全部NULL場合
      --IF  VSYOGAKO_CD IS NULL AND VTYUGAKO_CD IS NULL AND VKUIKIGAI_CD IS NULL AND VYOGOGAKO_CD IS NULL THEN
    -- 条件６～条件10が全部NULL場合
      IF  VSYOGAKO_CD IS NULL AND VTYUGAKO_CD IS NULL AND VKUIKIGAI_CD IS NULL AND VYOGOGAKO_CD IS NULL AND VSIRITUGAKO_CD IS NULL THEN
--  2025/11/06 CTC.HJF UPDATE END
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
          ELSIF  MHIZUKE(1).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(1).OUT_D OR MHIZUKE(1).OUT_D = 0) THEN
            MHIZUKE(1).GAKO_KBN := 1;
            MHIZUKE(1).GAKO_CD := RG.KUIKIGAI_CD;  
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
          ELSIF MHIZUKE(2).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(2).OUT_D OR MHIZUKE(2).OUT_D = 0) THEN
            MHIZUKE(2).GAKO_KBN := 1;
            MHIZUKE(2).GAKO_CD := RG.YOGOGAKO_CD;  
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
          ELSIF MHIZUKE(3).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(3).OUT_D OR MHIZUKE(3).OUT_D = 0) THEN
            MHIZUKE(3).GAKO_KBN := 1;
            MHIZUKE(3).GAKO_CD := RG.SYOGAKO_CD;  
          END IF;
        END IF;
        --中学校
        IF  RG.TYUGAKO_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.TYUGAKO_NYUGAKU_BI    > 0 THEN MHIZUKE(4).IN_D := RG.TYUGAKO_NYUGAKU_BI;     END IF;
          IF RG.TYUGAKO_TENNYUGAKU_BI > 0 THEN MHIZUKE(4).IN_D := RG.TYUGAKO_TENNYUGAKU_BI;  END IF;
          ----転学年月日OR卒業年月日
          IF RG.TYUGAKO_TENGAKU_BI    > 0 THEN MHIZUKE(4).OUT_D := RG.TYUGAKO_TENGAKU_BI;    END IF;
          IF RG.TYUGAKO_SOTSUGYO_BI   > 0 THEN MHIZUKE(4).OUT_D := RG.TYUGAKO_SOTSUGYO_BI;   END IF;
          --基準日時点の判定
          IF  MHIZUKE(4).IN_D = 0 AND MHIZUKE(4).OUT_D = 0 THEN
            MHIZUKE(4).GAKO_KBN := 0;
          ELSIF MHIZUKE(4).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(4).OUT_D OR MHIZUKE(4).OUT_D = 0) THEN
            MHIZUKE(4).GAKO_KBN := 1;
            MHIZUKE(4).GAKO_CD := RG.TYUGAKO_CD;  
          END IF;
        END IF;
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
        --国私立学校
        IF RG.KUNISHIRITSU_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.KUNISHIRITSU_NYUGAKU_BI    > 0 THEN MHIZUKE(5).IN_D := RG.KUNISHIRITSU_NYUGAKU_BI;   END IF;
          IF RG.KUNISHIRITSU_TENNYUGAKU_BI > 0 THEN MHIZUKE(5).IN_D := RG.KUNISHIRITSU_TENNYUGAKU_BI;END IF;
          ----転学年月日OR退学年月日OR卒業年月日
          IF RG.KUNISHIRITSU_TENGAKU_BI    > 0 THEN MHIZUKE(5).OUT_D := RG.KUNISHIRITSU_TENGAKU_BI;  END IF;
          IF RG.KUNISHIRITSU_TAIGAKU_BI    > 0 THEN MHIZUKE(5).OUT_D := RG.KUNISHIRITSU_TAIGAKU_BI;  END IF;
          IF RG.KUNISHIRITSU_SOTSUGYO_BI   > 0 THEN MHIZUKE(5).OUT_D := RG.KUNISHIRITSU_SOTSUGYO_BI; END IF;
          --基準日時点の判定
          IF  MHIZUKE(5).IN_D = 0 AND MHIZUKE(5).OUT_D = 0 THEN
            MHIZUKE(5).GAKO_KBN := 0;
          ELSIF  MHIZUKE(5).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(5).OUT_D OR MHIZUKE(5).OUT_D = 0) THEN
            MHIZUKE(5).GAKO_KBN := 1;
            MHIZUKE(5).GAKO_CD := RG.KUNISHIRITSU_CD;  
          END IF;
        END IF;
--  2025/11/06 CTC.HJF UPDATE END
      ELSE
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
      ----条件６～条件９うち、どれか選択された場合
      --条件６～条件10うち、どれか選択された場合
--  2025/11/06 CTC.HJF UPDATE END
       --  小学校 (条件６)
       IF  VSYOGAKO_CD IS NOT NULL THEN
        IF  RG.SYOGAKO_CD <> 0 THEN
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE START 1.0.105.000:GKB_QA20560対応
            --RG_GAKO_CD := TO_CHAR(RG.SYOGAKO_CD, 'FM000');
	    --RET := INSTR(VSYOGAKO_CD, RG_GAKO_CD);
	    RET := INSTR(VSYOGAKO_CD, RG.SYOGAKO_CD);
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE END
            IF RET > 0 THEN
              ----入学年月日OR転入学年月日
              IF RG.SYOGAKO_NYUGAKU_BI    > 0 THEN MHIZUKE(3).IN_D := RG.SYOGAKO_NYUGAKU_BI;     END IF;
              IF RG.SYOGAKO_TENNYUGAKU_BI > 0 THEN MHIZUKE(3).IN_D := RG.SYOGAKO_TENNYUGAKU_BI;  END IF;
              ----転学年月日OR卒業年月日
              IF RG.SYOGAKO_TENGAKU_BI    > 0 THEN MHIZUKE(3).OUT_D := RG.SYOGAKO_TENGAKU_BI;    END IF;
              IF RG.SYOGAKO_SOTSUGYO_BI   > 0 THEN MHIZUKE(3).OUT_D := RG.SYOGAKO_SOTSUGYO_BI;   END IF;
              --基準日時点の判定
              IF  MHIZUKE(3).IN_D = 0 AND MHIZUKE(3).OUT_D = 0 THEN
                MHIZUKE(3).GAKO_KBN := 0;
              ELSIF MHIZUKE(3).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(3).OUT_D OR MHIZUKE(3).OUT_D = 0) THEN
                MHIZUKE(3).GAKO_KBN := 1;
              END IF;
            END IF;
        END IF;
       END IF;
       --  中学校 (条件７)
       IF  VTYUGAKO_CD IS NOT NULL THEN
        IF  RG.TYUGAKO_CD <> 0 THEN
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE START 1.0.105.000:GKB_QA20560対応
            --RG_GAKO_CD := TO_CHAR(RG.TYUGAKO_CD, 'FM000');
            --RET := INSTR(VTYUGAKO_CD, RG_GAKO_CD);
	    RET := INSTR(VTYUGAKO_CD, RG.TYUGAKO_CD);
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE END
            IF RET > 0 THEN
              ----入学年月日OR転入学年月日
              IF RG.TYUGAKO_NYUGAKU_BI    > 0 THEN MHIZUKE(4).IN_D := RG.TYUGAKO_NYUGAKU_BI;     END IF;
              IF RG.TYUGAKO_TENNYUGAKU_BI > 0 THEN MHIZUKE(4).IN_D := RG.TYUGAKO_TENNYUGAKU_BI;  END IF;
              ----転学年月日OR卒業年月日
              IF RG.TYUGAKO_TENGAKU_BI    > 0 THEN MHIZUKE(4).OUT_D := RG.TYUGAKO_TENGAKU_BI;    END IF;
              IF RG.TYUGAKO_SOTSUGYO_BI   > 0 THEN MHIZUKE(4).OUT_D := RG.TYUGAKO_SOTSUGYO_BI;   END IF;
              --基準日時点の判定
              IF  MHIZUKE(4).IN_D = 0 AND MHIZUKE(4).OUT_D = 0 THEN
                MHIZUKE(4).GAKO_KBN := 0;
              ELSIF MHIZUKE(4).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(4).OUT_D OR MHIZUKE(4).OUT_D = 0) THEN
                MHIZUKE(4).GAKO_KBN := 1;
              END IF;
            END IF;
        END IF;
       END IF;
       --区域外 (条件８)
       IF  VKUIKIGAI_CD IS NOT NULL THEN
        IF RG.KUIKIGAI_CD <> 0 THEN
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE START 1.0.105.000:GKB_QA20560対応
            --RG_GAKO_CD := TO_CHAR(RG.KUIKIGAI_CD, 'FM000');            
	    --RET := INSTR(VKUIKIGAI_CD, RG_GAKO_CD);
            RET := INSTR(VKUIKIGAI_CD, RG.KUIKIGAI_CD);
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE END
            IF RET > 0 THEN
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
              ELSIF  MHIZUKE(1).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(1).OUT_D OR MHIZUKE(1).OUT_D = 0) THEN
                MHIZUKE(1).GAKO_KBN := 1;
              END IF;
          END IF;
        END IF;
       END IF;
       --特別支援学校 (条件９)
       IF  VYOGOGAKO_CD IS NOT NULL THEN
        IF RG.YOGOGAKO_CD <> 0 THEN
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE START 1.0.105.000:GKB_QA20560対応
            --RG_GAKO_CD := TO_CHAR(RG.YOGOGAKO_CD, 'FM000');            
	    --RET := INSTR(VYOGOGAKO_CD, RG_GAKO_CD);
            RET := INSTR(VYOGOGAKO_CD, RG.YOGOGAKO_CD);
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE END
            IF RET > 0 THEN
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
              ELSIF MHIZUKE(2).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(2).OUT_D OR MHIZUKE(2).OUT_D = 0) THEN
                MHIZUKE(2).GAKO_KBN := 1;
              END IF;
          END IF;
        END IF;
       END IF;
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
       --国私立学校 (条件10)
       IF  VSIRITUGAKO_CD IS NOT NULL THEN
        IF RG.KUNISHIRITSU_CD <> 0 THEN
            RET := INSTR(VSIRITUGAKO_CD, RG.KUNISHIRITSU_CD);
            IF RET > 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.KUNISHIRITSU_NYUGAKU_BI    > 0 THEN MHIZUKE(5).IN_D := RG.KUNISHIRITSU_NYUGAKU_BI;   END IF;
          IF RG.KUNISHIRITSU_TENNYUGAKU_BI > 0 THEN MHIZUKE(5).IN_D := RG.KUNISHIRITSU_TENNYUGAKU_BI;END IF;
          ----転学年月日OR退学年月日OR卒業年月日
          IF RG.KUNISHIRITSU_TENGAKU_BI    > 0 THEN MHIZUKE(5).OUT_D := RG.KUNISHIRITSU_TENGAKU_BI;  END IF;
          IF RG.KUNISHIRITSU_TAIGAKU_BI    > 0 THEN MHIZUKE(5).OUT_D := RG.KUNISHIRITSU_TAIGAKU_BI;  END IF;
          IF RG.KUNISHIRITSU_SOTSUGYO_BI   > 0 THEN MHIZUKE(5).OUT_D := RG.KUNISHIRITSU_SOTSUGYO_BI; END IF;
          --基準日時点の判定
          IF  MHIZUKE(5).IN_D = 0 AND MHIZUKE(5).OUT_D = 0 THEN
            MHIZUKE(5).GAKO_KBN := 0;
          ELSIF  MHIZUKE(5).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(5).OUT_D OR MHIZUKE(5).OUT_D = 0) THEN
            MHIZUKE(5).GAKO_KBN := 1;
            MHIZUKE(5).GAKO_CD := RG.KUNISHIRITSU_CD; 
              END IF;
          END IF;
        END IF;
       END IF;
--  2025/11/06 CTC.HJF UPDATE END
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END PROC_CHECK_KIJUN;
    --------------------------------------------------------------------------------
    --  機能概要      : 任意ビットが指定した条件に該当するかチェック
    --  パラメータ    : RATENA_WORK
    --                  i_NINIBIT
    --                  i_ATAI
    --                  MHIZUKE
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    --------------------------------------------------------------------------------
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--     FUNCTION FUNC_CHK_NINIBIT(RATENA_WORK IN CRATENA_TYPE,i_NINIBIT IN NUMBER,i_ATAI IN NUMBER)
--     RETURN BOOLEAN IS
--       o_BRTN    BOOLEAN;
--     BEGIN
--         o_BRTN := FALSE;
--         CASE i_NINIBIT
--           WHEN 1 THEN IF RATENA_WORK.NINIBIT1 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 2 THEN IF RATENA_WORK.NINIBIT2 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 3 THEN IF RATENA_WORK.NINIBIT3 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 4 THEN IF RATENA_WORK.NINIBIT4 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 5 THEN IF RATENA_WORK.NINIBIT5 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 6 THEN IF RATENA_WORK.NINIBIT6 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 7 THEN IF RATENA_WORK.NINIBIT7 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 8 THEN IF RATENA_WORK.NINIBIT8 = i_ATAI THEN o_BRTN := TRUE; END IF;
--           WHEN 9 THEN IF RATENA_WORK.NINIBIT9 = i_ATAI THEN o_BRTN := TRUE; END IF;
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
-- 2024/06/12 ZCZL.wangyunhan Delete end 
    --------------------------------------------------------------------------------
    --  機能概要      : 制御のフラグをセットするのを行う
    --  パラメータ    : i_KOJIN_NO
    --                  o_NAIYO_CD
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    --------------------------------------------------------------------------------
    FUNCTION FUNC_PRMFLGSET(i_KOJIN_NO IN NUMBER,o_NAIYO_CD OUT NUMBER) RETURN NUMBER IS
      NODATAFOUND_FLG    BOOLEAN;
      ZERO_FLG           BOOLEAN;
    BEGIN
      --フラグ初期化
      BPRMFLG_001      := FALSE;
      BPRMFLG_002      := FALSE;
      BPRMFLG_003      := FALSE;
      BPRMFLG_004      := FALSE;
      NODATAFOUND_FLG    := FALSE;
      ZERO_FLG           := FALSE;
      --本名使用制御管理情報の取得
      BEGIN
        SELECT NAIYO_CD
          INTO o_NAIYO_CD
          FROM GKBTSHIMEIJKN
         WHERE KOJIN_NO = i_KOJIN_NO
           AND CHOHYO_ID = 'GKB210R001';
        IF o_NAIYO_CD = 0 THEN
          ZERO_FLG  := TRUE;
        END IF;
      EXCEPTION
        --データを取得しない場合
        WHEN NO_DATA_FOUND THEN
        NODATAFOUND_FLG  := TRUE;
      END;
      --氏名印字.制御ﾊﾟﾗﾒｰﾀ(12)が1の場合
      IF o_SHIMEIPRM(12) = 1 THEN
        BPRMFLG_001  := TRUE;
      END IF;
      --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(12)が4、6場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(12) IN (4, 6) THEN
          BPRMFLG_002  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在する、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(12)が3、4、5、6場合
      IF NOT NODATAFOUND_FLG AND NOT ZERO_FLG THEN
        IF o_SHIMEIPRM(12) IN(3,4,5,6) THEN
          BPRMFLG_003  := TRUE;
        END IF;
      END IF;
        -- 本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(12)が4、5場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(12) IN (4, 5) THEN
          BPRMFLG_004  := TRUE;
        END IF;
      END IF;
    RETURN 0;
    END;
    --------------------------------------------------------------------------------
    --  機能概要      : 制御を行う
    --  パラメータ    : i_HONMYO
    --                  i_SHIMEI
    --                  o_SET
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SEIGYO_SET(i_HONMYO IN NVARCHAR2,i_SHIMEI IN NVARCHAR2, o_SET OUT NVARCHAR2) RETURN PLS_INTEGER
    IS
    BEGIN
      -- HONMYO_KANAをセット
      IF BPRMFLG_001 OR BPRMFLG_002 THEN
        o_SET := NVL(TRIM(i_HONMYO),i_SHIMEI);
      END IF;
      -- 本名使用制御管理情報の設定で編集
      IF BPRMFLG_003 THEN
        IF N_NAIYO_CD IN(11,12) THEN
          o_SET := NVL(TRIM(i_SHIMEI),i_HONMYO);
        ELSIF N_NAIYO_CD IN(21,22) THEN
          o_SET := NVL(TRIM(i_HONMYO),i_SHIMEI);
        END IF;
      END IF;
      --SHIMEI_KANAをセット
      IF NOT BPRMFLG_001 AND NOT BPRMFLG_002 AND NOT BPRMFLG_003 THEN
        o_SET := NVL(TRIM(i_SHIMEI),i_HONMYO);
      END IF;
      RETURN 0;
    END;
    --------------------------------------------------------------------------------
    --  機能概要      : 児童生徒中間（GKBWJIDOZAIGAKU）レコードの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        NNENDO              PLS_INTEGER;                -- 年度
        NGAKUNEN_CD              NUMBER;                -- 学年コード
        NSYURYOGAKUNEN_CD   NUMBER;                     -- 終了学年コード
        IRTNA               PLS_INTEGER;
        IRTNSANTEIDANTAI    PLS_INTEGER;
        IRTNAH              PLS_INTEGER;
        ICNT                BINARY_INTEGER;             -- 戻り値
        BRTNSASKUSEIBI      BOOLEAN;
        IJUSHO_NAGASA       PLS_INTEGER;
        ISHIMEINAGASA       PLS_INTEGER;
        IRTNZOKUGARA1        PLS_INTEGER;
        IRTNZOKUGARAHERR1    PLS_INTEGER;
        IRTNZOKUGARA2        PLS_INTEGER;
        IRTNZOKUGARAHERR2    PLS_INTEGER;
        NPRTN                NUMBER;
        VSQLSEL             VARCHAR2(5000);
        KIJUNBIHENKA         BOOLEAN;
        NNINIBIT_KISU      NUMBER(2);             ------任意ビット項目の数量
        NNINIBIT_SYUBETU   NUMBER(2);             ------任意ﾋﾞｯﾄ種別(Xより値が変わる)
        NNINIBIT_ATAI      NUMBER(2);             ------任意ﾋﾞｯﾄ値(Xより値が変わる)
        X                   NUMBER(2);             ------[NINIBITX]のX
        NTIMES             NUMBER(2);             ------任意ビットの文字列を分割するためのLOOP回数
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--         KOJINNO3            NUMBER(12):=0;            --個人番号 個人番号の最新と履歴を区別するため
        KOJINNO3            NUMBER(15):=0;            --個人番号 個人番号の最新と履歴を区別するため
        MHIZUKE     MHIZUKE_TYPE;  --読込レコード用
        MHIZUKE_SAV MHIZUKE_TYPE;  --保持用
        IGAKO_KBN           BINARY_INTEGER := 0 ;  --該当する学校区分
        BOUT_FLG2           BOOLEAN := FALSE;      --出力ﾌﾗｸﾞ
        BOUT_FLG3           BOOLEAN;               --出力ﾌﾗｸﾞ
        JINKAKU_KBN   GKBWJIDOZAIGAKU.JINKAKU_KBN%TYPE;
        n_YYYY               PLS_INTEGER;--生年月日変数
        n_MM                 PLS_INTEGER;
        n_DD                 PLS_INTEGER;
        v_GYYMMDD1           NVARCHAR2(20);    
        CNT_HOGOSYA         NUMBER := 0;
        TYPE TYPECURSOR     IS REF CURSOR;
        CRATENA             TYPECURSOR;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        GATENADATA          GABTATENAKIHON%ROWTYPE;
        GSOFUSAKI           GABTSOFUSAKI%ROWTYPE;
        GATENADATA1         GABTATENAKIHON%ROWTYPE;
        GSOFUSAKI1          GABTSOFUSAKI%ROWTYPE;
        oSHIMEI_KANA        NVARCHAR2(400);
        oSHIMEI_KANJI       NVARCHAR2(400);
        oSEINENGAPI         NVARCHAR2(400);
        oSHIMEI_KANA1       NVARCHAR2(400);
        oSHIMEI_KANJI1      NVARCHAR2(400);
        oSEINENGAPI1        NVARCHAR2(400);
-- 2024/06/12 ZCZL.wangyunhan Add end
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
        VSQLSEL_RIREKI         VARCHAR2(32000);
        CRATENA_OLDRIREKI      TYPECURSOR;
        CRATENA_OLDRIREKIWORK  GKBTGAKUREIBO%ROWTYPE;
--  2025/11/06 CTC.HJF UPDATE END
    BEGIN
        FRET := c_INOTFOUND;                 -- 該当なし
        NGAKUNEN_CD := TO_NUMBER(VGAKUNEN);          -- 学年
        NSYURYOGAKUNEN_CD := TO_NUMBER(VSYURYOGAKUNEN);          -- 学年
        ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        ICNT := 0;
        BEGIN
            -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
          ISEIREKIHIZUKE := 0;
          IWAREKIHIZUKE  := KIJUNBI;
                   KIJUNBIHENKA := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                                   VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                                   VEDIT_GYYMMDD3, VKJ_GENGO,
                                                   VKG_GENGO,      IWAREKI_YY,
                                               ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                                   IMM,            IDD,
                                                   IWAREKIHIZUKE,  ISEIREKIHIZUKE );
          KIJUNBI2 := ISEIREKIHIZUKE;
          VSQLSEL := '';
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
          VSQLSEL := VSQLSEL || 'SELECT ';
          VSQLSEL := VSQLSEL || 'SK.KOJIN_NO, ';
          VSQLSEL := VSQLSEL || 'SK.RIREKI_RENBAN, ';
          VSQLSEL := VSQLSEL || 'SK.RIREKI_RENBAN_EDA, ';
          VSQLSEL := VSQLSEL || 'SK.GAKUNEN ';
          VSQLSEL := VSQLSEL || 'FROM ( ';
--  2025/11/06 CTC.HJF UPDATE END
          VSQLSEL := VSQLSEL || 'SELECT ';
          VSQLSEL := VSQLSEL || 'B.KOJIN_NO, ';
          VSQLSEL := VSQLSEL || 'B.RIREKI_RENBAN, ';
-- 2024/06/12 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
          VSQLSEL := VSQLSEL || 'B.RIREKI_RENBAN_EDA, ';
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
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
-- 2024/06/12 ZCZL.wangyunhan Delete end 
          VSQLSEL := VSQLSEL || 'B.GAKUNEN ';
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
          VSQLSEL := VSQLSEL || ' , ROW_NUMBER() OVER ( ';
          VSQLSEL := VSQLSEL || '     PARTITION BY B.KOJIN_NO ';
          VSQLSEL := VSQLSEL || '     ORDER BY B.RIREKI_RENBAN DESC';
          VSQLSEL := VSQLSEL || ' ) AS RN ';
--  2025/11/06 CTC.HJF UPDATE END
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--           VSQLSEL := VSQLSEL || 'FROM GKBTGAKUREIBO B, ';
--           VSQLSEL := VSQLSEL || 'GKBTNINIBIT C ';
--           VSQLSEL := VSQLSEL || ' WHERE  C.KOJIN_NO=B.KOJIN_NO ';               
--           VSQLSEL := VSQLSEL || ' AND    C.RIREKI_RENBAN=B.RIREKI_RENBAN';      
          VSQLSEL := VSQLSEL || 'FROM GKBTGAKUREIBO B ';
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
          VSQLSEL := VSQLSEL || ', GABVATENAALL_B A, ';
          VSQLSEL := VSQLSEL || 'GKBTMSGAKUKYUCD C ';
          VSQLSEL := VSQLSEL || ' WHERE B.KOJIN_NO = A.KOJIN_NO';
          VSQLSEL := VSQLSEL || ' AND B.IDOJI_ATENA_RIREKI_RENBAN = A.RIREKI_RENBAN';
          VSQLSEL := VSQLSEL || ' AND B.GAKKO_KBN_CD = C.GAKKO_KBN_CD (+) ';
          VSQLSEL := VSQLSEL || ' AND B.GAKUKYU_CD = C.GAKUKYU_CD (+)';
          VSQLSEL := VSQLSEL || ' AND B.SAISHIN_KBN = 0';
          VSQLSEL := VSQLSEL || ' AND C.GAKKO_CD (+)  = (CASE B.GAKKO_KBN_CD ';
          VSQLSEL := VSQLSEL || ' WHEN 1 THEN B.SYOGAKO_CD ';
          VSQLSEL := VSQLSEL || ' WHEN 2 THEN B.TYUGAKO_CD ';
          VSQLSEL := VSQLSEL || ' WHEN 3 THEN B.YOGOGAKO_CD ';
          VSQLSEL := VSQLSEL || ' WHEN 4 THEN B.KUIKIGAI_CD ';
          VSQLSEL := VSQLSEL || ' WHEN 5 THEN B.KUNISHIRITSU_CD ';
          VSQLSEL := VSQLSEL || ' END) ';
          VSQLSEL := VSQLSEL || ' AND ('|| KIJUNBI2 ||' >= B.SYOGAKO_NYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' >= B.SYOGAKO_TENNYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' >= B.TYUGAKO_NYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' >= B.TYUGAKO_TENNYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' >= B.KUIKIGAI_NYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' >= B.KUIKIGAI_TENNYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' >= B.YOGOGAKO_NYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' >= B.YOGOGAKO_TENNYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' >= B.KUNISHIRITSU_NYUGAKU_BI ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' >= B.KUNISHIRITSU_TENNYUGAKU_BI ) ' ;
          VSQLSEL := VSQLSEL || ' AND ('|| KIJUNBI2 ||' < DECODE(B.SYOGAKO_SOTSUGYO_BI,0,99999999,B.SYOGAKO_SOTSUGYO_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.TYUGAKO_SOTSUGYO_BI,0,99999999,B.TYUGAKO_SOTSUGYO_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.KUIKIGAI_SOTSUGYO_BI,0,99999999,B.KUIKIGAI_SOTSUGYO_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.YOGOGAKO_SOTSUGYO_BI,0,99999999,B.YOGOGAKO_SOTSUGYO_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.KUIKIGAI_TAIGAKU_BI,0,99999999,B.KUIKIGAI_TAIGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.YOGOGAKO_TAIGAKU_BI,0,99999999,B.YOGOGAKO_TAIGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.SYOGAKO_TENGAKU_BI,0,99999999,B.SYOGAKO_TENGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.TYUGAKO_TENGAKU_BI,0,99999999,B.TYUGAKO_TENGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.KUIKIGAI_TENGAKU_BI,0,99999999,B.KUIKIGAI_TENGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.YOGOGAKO_TENGAKU_BI,0,99999999,B.YOGOGAKO_TENGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.KUNISHIRITSU_TENGAKU_BI,0,99999999,B.KUNISHIRITSU_TENGAKU_BI) ' ;
          VSQLSEL := VSQLSEL || ' OR '|| KIJUNBI2 ||' < DECODE(B.KUNISHIRITSU_TAIGAKU_BI,0,99999999,B.KUNISHIRITSU_TAIGAKU_BI)) ' ;
          VSQLSEL := VSQLSEL || ' AND (B.GEN_NENGAPI = 0 OR ' || KIJUNBI2 || ' < DECODE(B.GEN_NENGAPI, 0, 99999999, B.GEN_NENGAPI)) ';
          VSQLSEL := VSQLSEL || ' AND B.GAKUNEN NOT IN (0,99)';
          VSQLSEL := VSQLSEL || ' AND B.GAKKO_KBN_CD <> 999';
          VSQLSEL := VSQLSEL || ' AND B.GAKUNEN >= '|| NGAKUNEN_CD ||' ';
          VSQLSEL := VSQLSEL || ' AND B.GAKUNEN <= '|| NSYURYOGAKUNEN_CD ||' ';          
          --VSQLSEL := VSQLSEL || ' WHERE 1 = 1';  
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE START 1.0.105.000:GKB_QA20560対応          
          --VSQLSEL := VSQLSEL || ' AND B.SAISHIN_KBN = 0';          
--  2025/11/06 CTC.HJF UPDATE END
	  VSQLSEL := VSQLSEL || ' AND B.SAKUJO_FLG = 0';
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE END
-- 2024/06/12 ZCZL.wangyunhan Update end 
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--           IF VSYOGAKO_CD IS NOT NULL OR VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR VYOGOGAKO_CD IS NOT NULL THEN
          IF VSYOGAKO_CD IS NOT NULL OR VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR VYOGOGAKO_CD IS NOT NULL OR VSIRITUGAKO_CD IS NOT NULL OR VSYOUGAKOKUCD IS NOT NULL OR VCYUGAKOKUCD IS NOT NULL THEN
            VSQLSEL := VSQLSEL || ' AND (';
            IF VSYOGAKO_CD IS NOT NULL THEN
              IF VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR VYOGOGAKO_CD IS NOT NULL THEN
                VSQLSEL := VSQLSEL || 'B.SYOGAKO_CD IN ('|| RTRIM(VSYOGAKO_CD, ',') ||')  OR ';
              ELSE
                VSQLSEL := VSQLSEL || 'B.SYOGAKO_CD IN ('|| RTRIM(VSYOGAKO_CD, ',') ||')';
              END IF;
            END IF;
            IF VTYUGAKO_CD IS NOT NULL THEN
              IF VKUIKIGAI_CD IS NOT NULL OR VYOGOGAKO_CD IS NOT NULL THEN
                VSQLSEL := VSQLSEL || 'B.TYUGAKO_CD IN ('|| RTRIM(VTYUGAKO_CD, ',') ||') OR ';
              ELSE
                VSQLSEL := VSQLSEL || 'B.TYUGAKO_CD IN ('|| RTRIM(VTYUGAKO_CD, ',') ||')';
              END IF;
            END IF;
            IF VKUIKIGAI_CD IS NOT NULL THEN
              IF VYOGOGAKO_CD IS NOT NULL THEN
                VSQLSEL := VSQLSEL || 'B.KUIKIGAI_CD IN ('|| RTRIM(VKUIKIGAI_CD, ',') ||') OR ';
              ELSE
                VSQLSEL := VSQLSEL || 'B.KUIKIGAI_CD IN ('|| RTRIM(VKUIKIGAI_CD, ',') ||')';
              END IF;
            END IF;
            IF VYOGOGAKO_CD IS NOT NULL THEN
              VSQLSEL := VSQLSEL || 'B.YOGOGAKO_CD IN ('|| RTRIM(VYOGOGAKO_CD, ',') ||') ';
            END IF;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
            IF VSIRITUGAKO_CD IS NOT NULL THEN
              IF VSYOGAKO_CD IS NOT NULL OR VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR VYOGOGAKO_CD IS NOT NULL THEN
                VSQLSEL := VSQLSEL || 'OR B.KUNISHIRITSU_CD IN ('|| RTRIM(VSIRITUGAKO_CD, ',') ||')';
              ELSE
                VSQLSEL := VSQLSEL || 'B.KUNISHIRITSU_CD IN ('|| RTRIM(VSIRITUGAKO_CD, ',') ||') ';
              END IF;
            END IF;
            IF VSYOUGAKOKUCD IS NOT NULL THEN
              IF VSYOGAKO_CD IS NOT NULL OR VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR VYOGOGAKO_CD IS NOT NULL OR VSIRITUGAKO_CD IS NOT NULL THEN
                VSQLSEL := VSQLSEL || 'OR B.SHOGAKKOKU_CD IN ('|| RTRIM(VSYOUGAKOKUCD, ',') ||') ';
              ELSE
                VSQLSEL := VSQLSEL || 'B.SHOGAKKOKU_CD IN ('|| RTRIM(VSYOUGAKOKUCD, ',') ||') ';
              END IF;            END IF;
            IF VCYUGAKOKUCD IS NOT NULL THEN
              IF VSYOGAKO_CD IS NOT NULL OR VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR VYOGOGAKO_CD IS NOT NULL OR VSIRITUGAKO_CD IS NOT NULL OR VSYOUGAKOKUCD IS NOT NULL THEN
                VSQLSEL := VSQLSEL || 'OR B.CHUGAKKOKU_CD IN ('|| RTRIM(VCYUGAKOKUCD, ',') ||') ';
              ELSE
                VSQLSEL := VSQLSEL || 'B.CHUGAKKOKU_CD IN ('|| RTRIM(VCYUGAKOKUCD, ',') ||') ';
              END IF;  
            END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end
            VSQLSEL := VSQLSEL || ' )';
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE START 1.0.105.000:GKB_QA20560対応
            --VSQLSEL := VSQLSEL || ' AND B.SAISHIN_KBN = 0 ';
            --VSQLSEL := VSQLSEL || ' AND B.SAKUJO_FLG  = 0 ';
--  2025/09/16 JPJYS.XIAOMINGBO UPDATE END
-- 2024/06/12 ZCZL.wangyunhan Add end 
          END IF;
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
          VSQLSEL := VSQLSEL || ' ) SK ';
          VSQLSEL := VSQLSEL || 'WHERE RN = 1 ';
         --VSQLSEL := VSQLSEL || ' ORDER BY B.KOJIN_NO,B.RIREKI_RENBAN DESC ';  
         VSQLSEL := VSQLSEL || ' ORDER BY SK.KOJIN_NO,SK.RIREKI_RENBAN DESC ';  
--  2025/11/06 CTC.HJF UPDATE END 
            OPEN CRATENA  FOR VSQLSEL;
            LOOP
              FETCH  CRATENA INTO CRATENA_WORK ;
              EXIT WHEN CRATENA%NOTFOUND;
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--             GKBSKJDOG2(CRATENA_WORK.KOJIN_NO,CRATENA_WORK.RIREKI_RENBAN,RG,NPRTN);
            GKBSKJDOG2(CRATENA_WORK.KOJIN_NO,CRATENA_WORK.RIREKI_RENBAN,CRATENA_WORK.RIREKI_RENBAN_EDA,RG,NPRTN);
               /*****   チェック１：基準日判断  ここから   ******/
               --まず読込レコードが基準日時点のデータかチェック
               PROC_CHECK_KIJUN(RG,MHIZUKE);
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
              IF MHIZUKE(1).GAKO_KBN =0 AND MHIZUKE(2).GAKO_KBN =0 AND MHIZUKE(3).GAKO_KBN =0 AND MHIZUKE(4).GAKO_KBN =0  AND MHIZUKE(5).GAKO_KBN =0 THEN
                 VSQLSEL_RIREKI := 'SELECT * FROM GKBTGAKUREIBO WHERE KOJIN_NO =' || CRATENA_WORK.KOJIN_NO || 'ORDER BY RIREKI_RENBAN DESC';
                 OPEN CRATENA_OLDRIREKI  FOR VSQLSEL_RIREKI;
                  LOOP
                   FETCH  CRATENA_OLDRIREKI INTO CRATENA_OLDRIREKIWORK;
                   EXIT WHEN CRATENA_OLDRIREKI%NOTFOUND;
                     IF CRATENA_WORK.RIREKI_RENBAN  != CRATENA_OLDRIREKIWORK.RIREKI_RENBAN THEN
                        GKBSKJDOG2(CRATENA_OLDRIREKIWORK.KOJIN_NO,CRATENA_OLDRIREKIWORK.RIREKI_RENBAN,CRATENA_OLDRIREKIWORK.RIREKI_RENBAN_EDA,RG,NPRTN);
                        PROC_CHECK_KIJUN(RG,MHIZUKE);
                     END IF;
                     EXIT WHEN	 RG.GAKUNEN  > NGAKUNEN_CD  AND RG.GAKUNEN  < NSYURYOGAKUNEN_CD  AND  MHIZUKE(1).GAKO_KBN <> 0 OR MHIZUKE(2).GAKO_KBN <> 0 OR MHIZUKE(3).GAKO_KBN <> 0 OR MHIZUKE(4).GAKO_KBN <> 0 OR MHIZUKE(5).GAKO_KBN <> 0 ;
                   END LOOP;
              END IF;
--  2025/11/06 CTC.HJF UPDATE END
               --個人番号が変わる場合、保持用変数も初期化
               IF KOJINNO3 <> RG.KOJIN_NO THEN
                 KOJINNO3 := RG.KOJIN_NO;
                 IGAKO_KBN   := 0;
                 BOUT_FLG2   := FALSE;
                 BOUT_FLG3   := FALSE;
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
                 ----IDX=1:区域外、2:特別支援、3:小学校、4:中学校
                 --IDX=1:区域外、2:特別支援、3:小学校、4:中学校、5:国私立
                 --FOR IDX IN 1..4 LOOP
                 FOR IDX IN 1..5 LOOP
--  2025/11/06 CTC.HJF UPDATE END
                     MHIZUKE_SAV(IDX).GAKO_KBN   := 0;
                     MHIZUKE_SAV(IDX).GAKO_CD    := 0;
                     MHIZUKE_SAV(IDX).IN_D       := 0;
                     MHIZUKE_SAV(IDX).OUT_D      := 0;
                 END LOOP;
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
                 ----区域外、養護学校、小学校、中学校順位で基準日時点に在学したか確認
                 --区域外、養護学校、小学校、中学校、国私立順位で基準日時点に在学したか確認
                 --FOR IDX IN 1..4 LOOP
                 FOR IDX IN 1..5 LOOP
--  2025/11/06 CTC.HJF UPDATE END
                   IF MHIZUKE(IDX).GAKO_KBN > 0 THEN         --読込レコードが基準日対象の場合
                     IGAKO_KBN := IDX;                        --基準日時点のを最初に見つかったのが対象になる
                     BOUT_FLG2 := TRUE;
                   END IF;
                   EXIT WHEN BOUT_FLG2 = TRUE;
                 END LOOP;
                 MHIZUKE_SAV   := MHIZUKE;
               ELSE                                          --MAX以前の履歴の場合
                 --同じ個人番号で既に基準日対象レコードが見つかった場合、次へ飛ばす
                 --基準日には該当するが、他の条件を満たさない場合、次へ飛ばす
                 IF BOUT_FLG3 THEN GOTO continue; END IF;
                 --区域外、養護学校、小学校、中学校順位で基準日時点に在学したか確認
                 FOR IDX IN 1..4 LOOP
                   IF MHIZUKE(IDX).GAKO_KBN > 0 THEN         --読込レコードが基準日対象の場合
                     IF MHIZUKE(IDX).IN_D >= MHIZUKE_SAV(IDX).IN_D THEN  --読込レコード＞＝前回の入日付の入日付の場合、前回ので判断
                       --前回ので判断する場合、学校が変わるとスキップ
                       IF MHIZUKE_SAV(IDX).GAKO_CD = MHIZUKE(IDX).GAKO_CD
                        AND MHIZUKE_SAV(IDX).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE_SAV(IDX).OUT_D OR MHIZUKE_SAV(IDX).OUT_D = 0)
                        AND MHIZUKE(IDX).IN_D <> MHIZUKE_SAV(IDX).IN_D  
                       THEN
                         IF BOUT_FLG2 = FALSE THEN
                           IGAKO_KBN := IDX;                        --基準日時点のを最初に見つかったのが対象になる
                           BOUT_FLG2 := TRUE;
                         END IF;
                       END IF;
                     ELSE                                            --今回ので判断
                       IF MHIZUKE(IDX).IN_D <= KIJUNBI2 AND (KIJUNBI2 <= MHIZUKE(IDX).OUT_D OR MHIZUKE(IDX).OUT_D = 0)        
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
               /*****   チェック２：学年判断  ここから    ******/
               --開始学年より小さいあるいは終了学年より大きい場合、該当個人番号はスキップ
               IF BOUT_FLG2 = TRUE AND (RG.GAKUNEN < NGAKUNEN_CD OR RG.GAKUNEN > NSYURYOGAKUNEN_CD) THEN
                 BOUT_FLG3 := TRUE;
                 GOTO continue;
               END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
               /*****   チェック２：学年判断  ここまで    ******/
               /*****   チェック３：任意ビット条件の対象か判断 ここから *****/
               --任意ビットの入力がある場合、判断
--                IF BOUT_FLG2 = TRUE AND VNINIBIT IS NOT NULL THEN
--                   BOUT_FLG2 := FALSE;  --任意ビット条件がある場合、クリア
--                   NNINIBIT_KISU := LENGTH(VNINIBIT)/4;        ------任意ビット項目の数量を取得
--                   NNINIBIT_SYUBETU := TO_NUMBER(SUBSTR(VNINIBIT,1,2));     ----上2桁(種別)
--                   NNINIBIT_ATAI := TO_NUMBER(SUBSTR(VNINIBIT,3,2));        ----下2桁（値）
--                   X := NNINIBIT_SYUBETU+1;
--                   FOR NTIMES IN 1..NNINIBIT_KISU LOOP
--                        NNINIBIT_SYUBETU := TO_NUMBER(SUBSTR(VNINIBIT,4*NTIMES-3,2));
--                        NNINIBIT_ATAI := TO_NUMBER(SUBSTR(VNINIBIT,4*NTIMES-1,2));
--                        X := NNINIBIT_SYUBETU+1 ;
                       --任意ビットをチェック
--                        BOUT_FLG2 := FUNC_CHK_NINIBIT(CRATENA_WORK,X,NNINIBIT_ATAI);
--                        EXIT WHEN BOUT_FLG2 = TRUE;
--                   END LOOP ;
                  --基準日には該当するが任意ビット条件に該当しなければ、該当個人番号はスキップ
--                   IF BOUT_FLG2 = FALSE THEN
--                     BOUT_FLG3 := TRUE;
--                     GOTO continue;
--                   END IF;
--                END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete end 
               /*****   チェック３：任意ビット条件の対象か判断 ここまで *****/
               --上記のチェックが通らない場合、次のレコードへ行く
               IF BOUT_FLG2 = FALSE THEN GOTO continue;END IF;
               --条件該当レコードが一件見つかった場合、次へ行かないようにフラグを設定
               BOUT_FLG3 := TRUE;
--  2024/09/02 ZCZL.WANGMING DELETE 0.3.000.001:8月1日認識合わせの横展開
--    DBMS_OUTPUT.PUT_LINE('KOJIN_NO = ' || RG.KOJIN_NO);

            RB := NULL;           
            IF NPRTN = 0 THEN
              IF RG.HOGOSYA_KOJIN_NO <> 0 THEN
                IRTNAH := GAAPK0030.FGETATENA( RG.HOGOSYA_KOJIN_NO,
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
                SELECT COUNT(SHIMEI_KANJI)
                  INTO CNT_HOGOSYA
                  FROM GABTATENAKIHON
                 WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;

                IF CNT_HOGOSYA > 0 THEN
                  SELECT LENGTH(SHIMEI_KANJI)
                    INTO ISHIMEINAGASA
                    FROM GABTATENAKIHON
                   WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;

                  IF ISHIMEINAGASA > 15 THEN
                     SELECT SUBSTR (SHIMEI_KANJI,1,15) INTO VHOGOSHA_SHIMEI_JODAN
                       FROM GABTATENAKIHON
                      WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                     SELECT SUBSTR (SHIMEI_KANJI,16) INTO VHOGOSHA_SHIMEI_GEDAN
                       FROM GABTATENAKIHON
                      WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                  ELSE
                      SELECT SHIMEI_KANJI INTO VHOGOSHA_SHIMEI_GEDAN
                        FROM GABTATENAKIHON
                       WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                      VHOGOSHA_SHIMEI_JODAN := NULL;
                  END IF;
                ELSE
                  VHOGOSHA_SHIMEI_JODAN := NULL;
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
            IF BOUT_FLG2 AND IGAKO_KBN = 1 THEN
              --区域外
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
              IGAKO_CD := CRATENA_WORK.GAKUNEN || RG.KUIKIGAI_CD + 30000;
              VGAKUNENMEI := FUNC_EDIT_GAKUNENMEI( CRATENA_WORK.GAKUNEN );
            END IF;    
            IF BOUT_FLG2 AND IGAKO_KBN = 2 THEN
              --養護学校
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
              IGAKO_CD := CRATENA_WORK.GAKUNEN || RG.YOGOGAKO_CD + 40000;
              VGAKUNENMEI := FUNC_EDIT_GAKUNENMEI(CRATENA_WORK.GAKUNEN );
            END IF;    
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
                   IGAKO_CD := CRATENA_WORK.GAKUNEN||RG.SYOGAKO_CD;
                   VGAKUNENSEI := TO_CHAR(CRATENA_WORK.GAKUNEN);
                   VGAKUNENMEI := VGAKUNENSEI || '年生';
            END IF;    
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
                   IGAKO_CD := CRATENA_WORK.GAKUNEN||RG.TYUGAKO_CD;
                   NGAKUNENSEI := CRATENA_WORK.GAKUNEN - 6;
                   VGAKUNENSEI := TO_CHAR(NGAKUNENSEI);
                   VGAKUNENMEI := VGAKUNENSEI || '年生';
            END IF;
--  2025/11/06 CTC.HJF UPDATE START 1.0.205.000:GKB_QA22077
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
                   IGAKO_CD := CRATENA_WORK.GAKUNEN||RG.KUNISHIRITSU_CD;
                   VGAKUNENSEI := TO_CHAR(CRATENA_WORK.GAKUNEN);
                   VGAKUNENMEI := VGAKUNENSEI || '年生';
            END IF;
--  2025/11/06 CTC.HJF UPDATE END
            IRTNA := GAAPK0030.FGETATENA(  CRATENA_WORK.KOJIN_NO,
                                       'GKB',
                                       ISAKUSEIBI,
                                       RA,
                                       RASO);
            IRTNAH  := FUNC_PRMFLGSET(RA.KOJIN_NO,N_NAIYO_CD);
            IF RA.JINKAKU_KBN = 1 THEN
              IRTNAH  := FUNC_SEIGYO_SET(RA.HONMYO_KANA,RA.SHIMEI_KANA,RA.SHIMEI_KANA);
              IRTNAH  := FUNC_SEIGYO_SET(RA.HONMYO_KANJI,RA.SHIMEI_KANJI,RA.SHIMEI_KANJI);
              IRTNAH  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,RB.SHIMEI_KANA);
              IRTNAH  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,RB.SHIMEI_KANJI);
              IRTNAH  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,VHOGOSHA_SHIMEI_JODAN);    
              VHOGOSHA_SHIMEI_JODAN  := SUBSTR(VHOGOSHA_SHIMEI_JODAN,1,15);
              IRTNAH  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,VHOGOSHA_SHIMEI_GEDAN);    
              VHOGOSHA_SHIMEI_GEDAN  := SUBSTR(VHOGOSHA_SHIMEI_GEDAN,16);
            END IF;
            JINKAKU_KBN    := RA.JINKAKU_KBN;
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
            -- 生年月日の編集
            n_YYYY           := ISEIREKI_YYYY;
            n_MM             := IMM;
            n_DD             := IDD;
            v_GYYMMDD1       := VSEINENGAPI;                    
            IF RA.JINKAKU_KBN = 1 THEN
              IF BPRMFLG_004 THEN
               --GKBPK00010.GKBFYMDEDT1より取得した表示生年月日
                I_RTN := GKBPK00010.FYMDEDT1(RA.SEINENGAPI,VSEINENGAPI,o_YMD2);
              ELSIF BPRMFLG_003 THEN
                -- 和暦で表示生年月日
                IF N_NAIYO_CD IN(11,21) THEN
                  VSEINENGAPI    := VSEINENGAPI;
                  -- 西暦で表示生年月日
                ELSIF N_NAIYO_CD IN(12,22) THEN
                  VSEINENGAPI    := n_YYYY||'.'||LPAD(n_MM,2)||'.'||LPAD(n_DD,2);
                END IF;
              ELSE
              -- 「平成○年○月○日」の形式で表示
                VSEINENGAPI      := v_GYYMMDD1;    
              END IF;
            END IF;
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
               VJUSHO_JODAN := SUBSTR (RA.CHOMEI||RA.BANCHI||' '||RA.KATAGAKI,1,20);  
               VJUSHO_GEDAN :=  ' ';
            END IF;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発 TODO
            CASE g_rJSTP.Chohyonum
                WHEN '2101' THEN
                   I_RTN := GKBFKHMCTRL(RG.KOJIN_NO,g_rJSTP.CHOHYOID,0,g_ZAIGAKUMIDSEIGYO,oSHIMEI_KANA,oSHIMEI_KANJI,oSEINENGAPI);
                   I_RTN := GKBFKHMCTRL(RG.KOJIN_NO,g_rJSTP.CHOHYOID,1,g_ZAIGAKUMIDSEIGYO,oSHIMEI_KANA1,oSHIMEI_KANJI1,oSEINENGAPI1);
                WHEN '2102' THEN
                   I_RTN := GKBFKHMCTRL(RG.KOJIN_NO,g_rJSTP.CHOHYOID,0,g_GAIKOKUSEKIJIDOUSEIGYO,oSHIMEI_KANA,oSHIMEI_KANJI,oSEINENGAPI);
                   I_RTN := GKBFKHMCTRL(RG.KOJIN_NO,g_rJSTP.CHOHYOID,1,g_GAIKOKUSEKIJIDOUSEIGYO,oSHIMEI_KANA1,oSHIMEI_KANJI1,oSEINENGAPI1);
                WHEN '2103' THEN
                   I_RTN := GKBFKHMCTRL(RG.KOJIN_NO,g_rJSTP.CHOHYOID,0,g_GAIKOKUSEKISEIYOSEIGYO,oSHIMEI_KANA,oSHIMEI_KANJI,oSEINENGAPI);
                   I_RTN := GKBFKHMCTRL(RG.KOJIN_NO,g_rJSTP.CHOHYOID,1,g_GAIKOKUSEKISEIYOSEIGYO,oSHIMEI_KANA1,oSHIMEI_KANJI1,oSEINENGAPI1);
                ELSE
                   NULL;
           END CASE;
-- 2024/06/12 ZCZL.wangyunhan Add end 
            ICNT := ICNT + 1;           --位置移動
            VCNT :=  TO_CHAR(ICNT);     --位置移動
-- 2024/06/20 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
            --保護者の宛名情報を取得する
            I_RTN := GAAPK0030.FGETATENA(RG.HOGOSYA_KOJIN_NO,'GKB',KIJUNBI,GATENADATA,GSOFUSAKI);
            I_RTN := GAAPK0030.FGETATENA(RG.KOJIN_NO,'GKB',KIJUNBI,GATENADATA1,GSOFUSAKI1);
-- 2024/06/20 ZCZL.wangyunhan Add end 
                    INSERT INTO GKBWJIDOZAIGAKU VALUES (RG.KOJIN_NO,
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--                                                     RA.SHIMEI_KANA,
--                                                     RA.SHIMEI_KANJI,
--                                                     RA.SEINENGAPI,
--                                                     VSEINENGAPI,
                                                    oSHIMEI_KANA,
                                                    oSHIMEI_KANJI,
                                                    RA.SEINENGAPI,
                                                    oSEINENGAPI,
-- 2024/06/12 ZCZL.wangyunhan Update end
                                                    RA.SEIBETSU,
                                                    VSEIBETSU,
                                                    VZOKUGARAMEI1,
                                                    RA.SETAI_NO,
                                                    VSETAI_NO,
                                                    RG.HOGOSYA_KOJIN_NO,
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--                                                     RB.SHIMEI_KANA,
--                                                     RB.SHIMEI_KANJI,
                                                    oSHIMEI_KANA1,
                                                    oSHIMEI_KANJI1,
-- 2024/06/12 ZCZL.wangyunhan Update end
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
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--                                                     ,CRATENA_WORK.NINIBIT1
--                                                     ,CRATENA_WORK.NINIBIT2
--                                                     ,CRATENA_WORK.NINIBIT3
--                                                     ,CRATENA_WORK.NINIBIT4
--                                                     ,CRATENA_WORK.NINIBIT5
--                                                     ,CRATENA_WORK.NINIBIT6
--                                                     ,CRATENA_WORK.NINIBIT7
--                                                     ,CRATENA_WORK.NINIBIT8
--                                                     ,CRATENA_WORK.NINIBIT9
--                                                     ,CRATENA_WORK.NINIBIT10
--                                                     ,CRATENA_WORK.NINIBIT11
--                                                     ,CRATENA_WORK.NINIBIT12
--                                                     ,CRATENA_WORK.NINIBIT13
--                                                     ,CRATENA_WORK.NINIBIT14
--                                                     ,CRATENA_WORK.NINIBIT15
--                                                     ,CRATENA_WORK.NINIBIT16
--                                                     ,CRATENA_WORK.NINIBIT17
--                                                     ,CRATENA_WORK.NINIBIT18
--                                                     ,CRATENA_WORK.NINIBIT19
--                                                     ,CRATENA_WORK.NINIBIT20
--                                                     ,JINKAKU_KBN
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,JINKAKU_KBN
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,IGAKO_CD
                                                    ,VGAKOMEI
                                                    ,NULL
                                                    ,NULL
                                                    ,NULL
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,0
                                                    ,KIJUNBI
--                                                     ,MJIDO_WORK(ICNT).JIDO_KOKUSEKI
                                                    ,GATENADATA1.KOKUSEKI_CD
                                                    ,GATENADATA.KOKUSEKI_CD
                                                    ,NULL
-- 2024/06/12 ZCZL.wangyunhan Update end
                                                     );
              commit ;
            ELSE
              NULL;
            END IF;
            <<continue>>
              NULL;
            FRET := c_ISUCCESS;              --正常終了
            END LOOP;
            CLOSE CRATENA;
        RETURN FRET;
        EXCEPTION
            WHEN OTHERS THEN
                FRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN FRET;
    EXCEPTION
        /* その他エラー */
        WHEN OTHERS THEN
            FRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_GET_JIDO_WK;
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------------------------------
    --  機能概要      : 児童生徒中間（GKBWJIDOZAIGAKU）テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    --------------------------------------------------------------------------------
--     FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
--         FRET                PLS_INTEGER;                -- 戻り値
--         ICNT                BINARY_INTEGER;             -- カウント
--         VSQL                NVARCHAR2(10000);           -- ＳＱＬ文
--         VSQLSEL             NVARCHAR2(9000);            -- ＳＱＬのソート以外
--         VSQLORDER           NVARCHAR2(1000);            -- ＳＱＬの［ORDER BY］句
--         I_CUR               PLS_INTEGER;                -- カーソル
--         RREC                GKBWJIDOZAIGAKU%ROWTYPE;      -- 入学通知台帳のレコード変数
--         NROWS               NUMBER;                     --
--         IPAGECNT            PLS_INTEGER;                -- 頁数
--         IGYOCNT             PLS_INTEGER;                -- 行番号
--         IGYORENBAN          PLS_INTEGER;                -- 行連番
--         VPAGENAME           NVARCHAR2(500);             -- 改頁項目名のワーク
--         VPAGEWORK           NVARCHAR2(500);             -- 改頁項目値のワーク
--         VPAGEFIELD          NVARCHAR2(500);             -- 改頁項目値のワーク
--     BEGIN
--         FRET := c_ISUCCESS;                  -- 正常終了
--         VPAGEWORK := '';
--         IGYOCNT := 0;
--         ICNT := 0;
--         MJIDO_WORK.DELETE;                   -- ワーク領域の初期化
        --ソートキーが設定されている場合
--         IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
--           VSQLORDER := ' ORDER BY ' || g_rJSTP.Orderbyclause;
--         END IF;
--         
--         VPAGEFD := ' GAKUNEN_CD||GAKOKU_CD ';
--         VPAGENM := ' GAKOKUMEI ';
-- 
--         BEGIN
            -- 出力データ取得ＳＱＬの構文
--             VSQLSEL := '';
--             VSQLSEL := VSQLSEL || 'SELECT ';
--             VSQLSEL := VSQLSEL || 'NENDO, ';
--             VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
--             VSQLSEL := VSQLSEL || 'KAIPEJI, ';
--             VSQLSEL := VSQLSEL || 'GAKUNENMEI, ';
--             VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
--             VSQLSEL := VSQLSEL || 'RENBAN, ';
--             VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
--             VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
--             VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
--             VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
--             VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANJI, ';
--             VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1, ';
--             VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
--             VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
--             VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN, ';
--             VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN, ';
--             VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
--             VSQLSEL := VSQLSEL || VPAGEFD || ' KAIPEJI_CD, ';        -- 改頁値を設定
--             VSQLSEL := VSQLSEL || VPAGENM || ' KAIPEJI ';            -- 改頁名を設定
--             VSQLSEL := VSQLSEL || ',NINIBIT1, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT2, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT3, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT4, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT5, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT6, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT7, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT8, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT9, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT10, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT11, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT12, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT13, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT14, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT15, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT16, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT17, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT18, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT19, ';
--             VSQLSEL := VSQLSEL || 'NINIBIT20, ';
--             VSQLSEL := VSQLSEL || 'JINKAKU_KBN ';
--             VSQLSEL := VSQLSEL || 'FROM ';
--             VSQLSEL := VSQLSEL || 'GKBWJIDOZAIGAKU ';
            -- ひとつのＳＱＬ文にする
--             VSQL := VSQLSEL || VSQLORDER;
            -- カーソルのオープン
--             I_CUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
--             DBMS_SQL.PARSE(I_CUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
--             DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, RREC.NENDO, 10);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, RREC.KAIPEJI_CD, 500);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, RREC.KAIPEJI, 500);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.GAKUNENMEI, 20);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.SAKUSEIBI, 30);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.RENBAN, 3);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.JIDO_SHIMEI_KANA, 100);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.JIDO_SHIMEI_KANJI, 100);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.HYOJI_SEIBETSU, 2);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.HOGOSHA_SHIMEI_KANA, 100);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.HOGOSHA_SHIMEI_KANJI, 100);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.ZOKUGARAMEI1, 30);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.ZOKUGARAMEI2, 30);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.HYOJI_SEINENGAPI, 11);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.KON_JUSHO_JODAN, 30);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.KON_JUSHO_GEDAN, 30);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.GYOSEIKUMEI, 20);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, VPAGEFD, 500);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, VPAGENM, 500);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.NINIBIT1);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.NINIBIT2);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.NINIBIT3);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.NINIBIT4);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.NINIBIT5);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.NINIBIT6);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.NINIBIT7);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.NINIBIT8);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.NINIBIT9);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, RREC.NINIBIT10);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, RREC.NINIBIT11);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, RREC.NINIBIT12);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, RREC.NINIBIT13);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, RREC.NINIBIT14);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 34, RREC.NINIBIT15);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 35, RREC.NINIBIT16);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 36, RREC.NINIBIT17);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 37, RREC.NINIBIT18);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 38, RREC.NINIBIT19);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 39, RREC.NINIBIT20);
--             DBMS_SQL.DEFINE_COLUMN(I_CUR, 40, RREC.JINKAKU_KBN);
            -- ＳＱＬ実行
--             NROWS := DBMS_SQL.EXECUTE(I_CUR);
--             LOOP
                --FETCH（行の取り出し）
--                 IF DBMS_SQL.FETCH_ROWS(I_CUR) > 0 THEN
                    --ワーク領域へセット
--                     DBMS_SQL.COLUMN_VALUE(I_CUR,  1, MJIDO_WORK(ICNT).NENDO);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR,  2, MJIDO_WORK(ICNT).KAIPEJI_CD);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR,  3, MJIDO_WORK(ICNT).KAIPEJI);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR,  4, MJIDO_WORK(ICNT).GAKUNENMEI);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR,  5, MJIDO_WORK(ICNT).SAKUSEIBI);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR,  7, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR,  9, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MJIDO_WORK(ICNT).ZOKUGARAMEI1);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MJIDO_WORK(ICNT).ZOKUGARAMEI2);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MJIDO_WORK(ICNT).KON_JUSHO_JODAN);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MJIDO_WORK(ICNT).KON_JUSHO_GEDAN);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MJIDO_WORK(ICNT).GYOSEIKUMEI);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 18, VPAGEFIELD);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 19, VPAGENAME);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 20,MJIDO_WORK(ICNT).NINIBIT1 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 21,MJIDO_WORK(ICNT).NINIBIT2 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 22,MJIDO_WORK(ICNT).NINIBIT3 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 23,MJIDO_WORK(ICNT).NINIBIT4 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 24,MJIDO_WORK(ICNT).NINIBIT5 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 25,MJIDO_WORK(ICNT).NINIBIT6 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 26,MJIDO_WORK(ICNT).NINIBIT7 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 27,MJIDO_WORK(ICNT).NINIBIT8 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 28,MJIDO_WORK(ICNT).NINIBIT9 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 29,MJIDO_WORK(ICNT).NINIBIT10 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 30,MJIDO_WORK(ICNT).NINIBIT11);
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 31,MJIDO_WORK(ICNT).NINIBIT12 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 32,MJIDO_WORK(ICNT).NINIBIT13 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 33,MJIDO_WORK(ICNT).NINIBIT14 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 34,MJIDO_WORK(ICNT).NINIBIT15 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 35,MJIDO_WORK(ICNT).NINIBIT16 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 36,MJIDO_WORK(ICNT).NINIBIT17 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 37,MJIDO_WORK(ICNT).NINIBIT18 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 38,MJIDO_WORK(ICNT).NINIBIT19 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 39,MJIDO_WORK(ICNT).NINIBIT20 );
--                     DBMS_SQL.COLUMN_VALUE(I_CUR, 40,MJIDO_WORK(ICNT).JINKAKU_KBN );
-- 
--                     IF VPAGEWORK = VPAGEFIELD THEN
                    --以前の改頁項目名と同じ
--                         IGYOCNT := IGYOCNT + 1;
--                         IGYORENBAN := IGYORENBAN + 1;
--                         IF IGYOCNT > c_IMAXROWS THEN
                        -- １頁内の最大行数を超えた
--                             IPAGECNT := IPAGECNT + 1;
--                             IGYOCNT := 1;
--                             VPAGEWORK := VPAGEFIELD;
--                         END IF;
--                     ELSE
                    -- 改頁必要
--                         IPAGECNT := IPAGECNT + 1;
--                         IGYOCNT := 1;
--                         IGYORENBAN := 1;
--                         VPAGEWORK := VPAGEFIELD;
--                     END IF;
                    -- 再セットする項目
--                     MJIDO_WORK(ICNT).RENBAN := IGYORENBAN;    -- 連番
--                     MJIDO_WORK(ICNT).KAIPEJI := VPAGENAME;    -- 改頁名
--                     MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEWORK; -- 改頁コード
--                 ELSE
                    -- 全件読み込み終了
--                     EXIT;
--                 END IF;
--                 ICNT := ICNT + 1;
--             END LOOP;
--             DBMS_SQL.CLOSE_CURSOR(I_CUR);     
--         EXCEPTION
--             WHEN OTHERS THEN
--                 FRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
--                 N_SQL_CODE := SQLCODE;
--                 V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                -- 処理ログの出力
--                 B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
--         END;
--         RETURN FRET;
--     END FUNC_GET_JIDO_WK_CSV;
-- 2024/06/12 ZCZL.wangyunhan Delete end 
    --------------------------------------------------------------------------------
    --  機能概要      : 児童生徒中間（GKBWJIDOZAIGAKU）テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        o_TITLE             NVARCHAR2(400);             -- 戻りNINNIBITタイトル
        o_NINIMEISHO        A_CONS_PRM;                 -- 戻りNINNIBIT値配列
        VNINIBITMEISHO      NVARCHAR2(400);             -- 戻りNINNIBIT名称
        VNINIBIT_JOHO       NVARCHAR2(400);             -- 戻りNINNIBIT情報
        VNINIBIT_JOHOTEMP   NVARCHAR2(50);
        KIJUN_BI            NVARCHAR2(11);
-- 2024/06/12 ZCZL.wangyunhan Delete 0.3.000.000:新WizLIFE２次開発
--        ACONSPRM_NINIBIT    A_CONS_PRM;
        rRECODE             GKBWL210R001%ROWTYPE;
        nCOUNT              NUMBER := 0;
-- 2024/06/12 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
        nRTN               NUMBER;
    BEGIN
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--        ACONSPRM_NINIBIT := A_CONS_PRM();
--        ACONSPRM_NINIBIT.EXTEND;
--        FOR I IN 1..20 LOOP
--            ACONSPRM_NINIBIT.EXTEND;
--            ACONSPRM_NINIBIT(I) := NULL;
--        END LOOP;
-- 2024/06/12 ZCZL.wangyunhan Delete end 
        VNINIBIT_JOHO := NULL;
        FRET := c_ISUCCESS;                  -- 正常終了
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--         IMAX := MJIDO_WORK.LAST;             -- ワーク領域の件数の最大値
--         IMIN := MJIDO_WORK.FIRST;            -- ワーク領域の件数の最小値
        IMAX := ZAIGAKU_WORK.LAST;             -- ワーク領域の件数の最大値
        IMIN := ZAIGAKU_WORK.FIRST;            -- ワーク領域の件数の最小値
-- 2024/06/12 ZCZL.wangyunhan Update end 
        IF IMIN IS NOT NULL THEN    --データがない場合、エラーになる不具合対応

          -- 取得した件数分繰り返す
          FOR ICNT IN IMIN..IMAX LOOP
            nCOUNT := nCOUNT + 1;
            rRECODE := NULL;
            rRECODE.NO                       :=        nCOUNT;
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--             rRECODE.NENDO                    :=        MJIDO_WORK(ICNT).NENDO;                       --年度
--             rRECODE.GAKKOKU_CD               :=        MJIDO_WORK(ICNT).KAIPEJI_CD;                  --学校区コード
--             rRECODE.GAKKO_MEI_HYOJI          :=        MJIDO_WORK(ICNT).KAIPEJI;                     --学校名表示用
--             rRECODE.GAKUNEN                  :=        MJIDO_WORK(ICNT).GAKUNENMEI;                  --学年
--             rRECODE.GENZAIBI                 :=        MJIDO_WORK(ICNT).SAKUSEIBI;                   --現在日
--             rRECODE.NUM                      :=        MJIDO_WORK(ICNT).RENBAN;                      --No
--             rRECODE.SHIMEI_KANA              :=        MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;            --氏名カナ
--             rRECODE.SHIMEI                   :=        MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;           --氏名
--             rRECODE.SEIBETSU                 :=        MJIDO_WORK(ICNT).HYOJI_SEIBETSU;              --性別
--             rRECODE.HOGOSHA_SHIMEI_KANA      :=        MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;         --保護者氏名カナ
--             rRECODE.HOGOSHA_SHIMEI_KANJI     :=        MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;        --保護者氏名
--             rRECODE.ZOKUGARAMEI1             :=        MJIDO_WORK(ICNT).ZOKUGARAMEI1;                --子続柄
--             rRECODE.ZOKUGARAMEI2             :=        MJIDO_WORK(ICNT).ZOKUGARAMEI2;                --親続柄
--             rRECODE.SEINENGAPI               :=        MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;            --生年月日
--             rRECODE.JUSHO_JODAN              :=        MJIDO_WORK(ICNT).KON_JUSHO_JODAN;             --住所上
--             rRECODE.JUSHO_GEDAN              :=        MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;             --住所下
--             rRECODE.GYOSEIKU_MEI             :=        MJIDO_WORK(ICNT).GYOSEIKUMEI;                 --行政区名
--             ISEIREKIHIZUKE := 0;
--             IWAREKIHIZUKE := KIJUNBI;
--             BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
--                                       VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
--                                       VEDIT_GYYMMDD3, VKJ_GENGO,
--                                       VKG_GENGO,      IWAREKI_YY,
--                                       ISEIREKI_YYYY,  IWAREKI_GYYMM,
--                                       IMM,            IDD,
--                                       IWAREKIHIZUKE,  ISEIREKIHIZUKE );
--             KIJUN_BI := VEDIT_GYYMMDD3;
--             rRECODE.KIJUNBI                  :=        KIJUN_BI;                                     --基準日
--             ACONSPRM_NINIBIT(1)  := MJIDO_WORK(ICNT).NINIBIT1;
--             ACONSPRM_NINIBIT(2)  := MJIDO_WORK(ICNT).NINIBIT2;
--             ACONSPRM_NINIBIT(3)  := MJIDO_WORK(ICNT).NINIBIT3;
--             ACONSPRM_NINIBIT(4)  := MJIDO_WORK(ICNT).NINIBIT4;
--             ACONSPRM_NINIBIT(5)  := MJIDO_WORK(ICNT).NINIBIT5;
--             ACONSPRM_NINIBIT(6)  := MJIDO_WORK(ICNT).NINIBIT6;
--             ACONSPRM_NINIBIT(7)  := MJIDO_WORK(ICNT).NINIBIT7;
--             ACONSPRM_NINIBIT(8)  := MJIDO_WORK(ICNT).NINIBIT8;
--             ACONSPRM_NINIBIT(9)  := MJIDO_WORK(ICNT).NINIBIT9;
--             ACONSPRM_NINIBIT(10) := MJIDO_WORK(ICNT).NINIBIT10;
--             ACONSPRM_NINIBIT(11) := MJIDO_WORK(ICNT).NINIBIT11;
--             ACONSPRM_NINIBIT(12) := MJIDO_WORK(ICNT).NINIBIT12;
--             ACONSPRM_NINIBIT(13) := MJIDO_WORK(ICNT).NINIBIT13;
--             ACONSPRM_NINIBIT(14) := MJIDO_WORK(ICNT).NINIBIT14;
--             ACONSPRM_NINIBIT(15) := MJIDO_WORK(ICNT).NINIBIT15;
--             ACONSPRM_NINIBIT(16) := MJIDO_WORK(ICNT).NINIBIT16;
--             ACONSPRM_NINIBIT(17) := MJIDO_WORK(ICNT).NINIBIT17;
--             ACONSPRM_NINIBIT(18) := MJIDO_WORK(ICNT).NINIBIT18;
--             ACONSPRM_NINIBIT(19) := MJIDO_WORK(ICNT).NINIBIT19;
--             ACONSPRM_NINIBIT(20) := MJIDO_WORK(ICNT).NINIBIT20;
--             VNINIBIT_JOHO := NULL;
--             FOR N IN 1..20 LOOP
--               ININIBIT_RET := GKBPK00010.FGETNMS(N-1,o_TITLE,o_NINIMEISHO);
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
            rRECODE.NENDO                    :=        ZAIGAKU_WORK(ICNT).NENDO;                       --年度
            rRECODE.GAKKOKU_CD               :=        ZAIGAKU_WORK(ICNT).GAKOKU_CD;                   --学校区コード
            rRECODE.GAKKOKUMEI               :=        ZAIGAKU_WORK(ICNT).GAKKOKUMEI;                  --学校区
            rRECODE.GAKKO_MEI_HYOJI          :=        ZAIGAKU_WORK(ICNT).GAKOMEI;                     --学校名表示用
            rRECODE.GAKUNEN                  :=        ZAIGAKU_WORK(ICNT).GAKUNENMEI;                  --学年
            rRECODE.GENZAIBI                 :=        ZAIGAKU_WORK(ICNT).GENZAIBI;                    --現在日
            rRECODE.NUM                      :=        ZAIGAKU_WORK(ICNT).HYOJI_RENBAN;                --No
            rRECODE.SHIMEI_KANA              :=        ZAIGAKU_WORK(ICNT).JIDO_SHIMEI_KANA;            --氏名カナ
            rRECODE.SHIMEI                   :=        ZAIGAKU_WORK(ICNT).JIDO_SHIMEI_KANJI;           --氏名
            rRECODE.SEIBETSU                 :=        ZAIGAKU_WORK(ICNT).HYOJI_SEIBETSU;              --性別
            rRECODE.HOGOSHA_SHIMEI_KANA      :=        ZAIGAKU_WORK(ICNT).HOGOSHA_SHIMEI_KANA;         --保護者氏名カナ
            rRECODE.HOGOSHA_SHIMEI_KANJI     :=        ZAIGAKU_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;        --保護者氏名
            rRECODE.ZOKUGARAMEI1             :=        ZAIGAKU_WORK(ICNT).KO_ZOKUGARA;                 --子続柄
            rRECODE.ZOKUGARAMEI2             :=        ZAIGAKU_WORK(ICNT).OYA_ZOKUGARA;                --親続柄
            rRECODE.SEINENGAPI               :=        ZAIGAKU_WORK(ICNT).SEINENGAPI;                                    --生年月日
            rRECODE.JUSHO_JODAN              :=        ZAIGAKU_WORK(ICNT).JYUSYO_1;                    --住所上
            rRECODE.JUSHO_GEDAN              :=        ZAIGAKU_WORK(ICNT).JYUSYO_2;                    --住所下
            rRECODE.GYOSEIKU_MEI             :=        ZAIGAKU_WORK(ICNT).GYOSEIKUMEI;                 --行政区名
--  2025/01/20 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:ST_GKB_00001対応 Start
            --rRECODE.KIJUNBI                  :=        ZAIGAKU_WORK(ICNT).KIJUNBI;                     --基準日
            rRECODE.KIJUNBI                  :=        KKAPK0020.FDAYEDIT20(ZAIGAKU_WORK(ICNT).KIJUNBI, 0, 3);                     --基準日
--  2025/01/20 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:ST_GKB_00001対応 End
            rRECODE.NINBIT_JOHO              :=        NULL;                                           --任意ビット情報
            rRECODE.JUSHO_JODAN1             :=        NULL;                                           --住所上０００１
            rRECODE.JINKAKU_KBN              :=        ZAIGAKU_WORK(ICNT).JIINGAKU_KBN;                --人格区分
            rRECODE.JIDO_KOKUSEKI            :=        ZAIGAKU_WORK(ICNT).JIDO_KOKUSEKI;               --児童生徒国籍
            rRECODE.HOGOSHA_KOKUSEKI         :=        ZAIGAKU_WORK(ICNT).HOGOSHA_KOKUSEKI;            --保護者国籍
            rRECODE.BREAK_NO                 :=        ZAIGAKU_WORK(ICNT).KAIPEJI_CD;                  --改ページキー
            rRECODE.WSNUM                    :=        g_sWSNUM;                                       --端末番号
            rRECODE.BATCHKBN                 :=        2;                                              --即時バッチ区分
            rRECODE.JOBNUM                   :=        g_nJOBNUM;                                      --ジョブNO
-- 2024/06/12 ZCZL.wangyunhan Update end 
            INSERT INTO GKBWL210R001 VALUES rRECODE;
          END LOOP;
        END IF;   
        -- 終了
        RETURN FRET;
    EXCEPTION
        WHEN OTHERS THEN
            FRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------------------------------
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.WANGYUNHAN 2024/06/17
    --------------------------------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        VSQLSEL             VARCHAR2(5000);             -- ＳＱＬ文
        RREC                JIDOZAIGAKU_TYPE;           -- 児童生徒在学ワークレコード変数
        oJIDO_KOKUMEI       VARCHAR2(5000);             -- 児童生徒国籍
        oHOGOSHA_KOKUMEI    VARCHAR2(5000);             -- 保護者国籍
        oKOKUMEI            VARCHAR2(5000);             -- 国名漢字
        oKOKUMEI_ALPHABET   VARCHAR2(5000);             -- 国名アルファベット
        nCOUNT              NUMBER := 0;
        oSHIMEI_KANA        NVARCHAR2(400);
        oSHIMEI_KANJI       NVARCHAR2(400);
        oSEINENGAPI         NVARCHAR2(400);
        oSHIMEI_KANA1       NVARCHAR2(400);
        oSHIMEI_KANJI1      NVARCHAR2(400);
        oSEINENGAPI1        NVARCHAR2(400);
        REC                 GKBWZAIGAKUMID%ROWTYPE;    -- 校区別在学者一覧中間ワークレコード変数
        TYPE CRUSOR_REF     IS REF CURSOR;
        curDATA             CRUSOR_REF;
        nRTN                NUMBER;
        VPAGENAME           NVARCHAR2(500);             -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(500);             -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(500);             -- 改頁項目値のワーク
        IPAGECNT            PLS_INTEGER;                -- 頁数
        IGYOCNT             PLS_INTEGER;                -- 行番号
        IGYORENBAN          PLS_INTEGER;                -- 行連番
        bRTN                BOOLEAN;                    --戻り値
        vWHERE              NVARCHAR2(5000);            -- WHERE句
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IGYOCNT := 0;
        ICNT := 0;
        MJIDO_WORK.DELETE;                   -- ワーク領域の初期化
        BEGIN
            --児童生徒在学ワーク_カーソル
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'JIDO_KOJIN_NO,';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA,';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI,';
            VSQLSEL := VSQLSEL || 'SEINENGAPI,';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI,';
            VSQLSEL := VSQLSEL || 'SEIBETSU,';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU,';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1,';
            VSQLSEL := VSQLSEL || 'SETAI_NO,';
            VSQLSEL := VSQLSEL || 'HYOJI_SETAI_NO,';
            VSQLSEL := VSQLSEL || 'HOGOSHA_KOJIN_NO,';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA,';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANJI,';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2,';
            VSQLSEL := VSQLSEL || 'GAKUNEN_CD,';
            VSQLSEL := VSQLSEL || 'GAKUNENMEI,';
            VSQLSEL := VSQLSEL || 'GAKOKU_CD,';
            VSQLSEL := VSQLSEL || 'GAKOKUMEI,';
            VSQLSEL := VSQLSEL || 'GYOSEIKU_CD,';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI,';
            VSQLSEL := VSQLSEL || 'HAN_CD,';
            VSQLSEL := VSQLSEL || 'HANMEI,';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD,';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAIMEI,';
            VSQLSEL := VSQLSEL || 'YUBIN_NO,';
            VSQLSEL := VSQLSEL || 'CHOMEI,';
            VSQLSEL := VSQLSEL || 'BANCHI,';
            VSQLSEL := VSQLSEL || 'KATAGAKI,';
            VSQLSEL := VSQLSEL || 'NENDO,';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD,';
            VSQLSEL := VSQLSEL || 'KAIPEJI,';
            VSQLSEL := VSQLSEL || 'SAKUSEIBI,';
            VSQLSEL := VSQLSEL || 'RENBAN,';
            VSQLSEL := VSQLSEL || 'HYOJI_RENBAN,';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN,';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN,';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN,';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN,';
            VSQLSEL := VSQLSEL || 'JINKAKU_KBN,';
            VSQLSEL := VSQLSEL || 'KIJUNBI,';
            VSQLSEL := VSQLSEL || 'GAKKO_CD,';
            VSQLSEL := VSQLSEL || 'GAKKOMEI,';
            VSQLSEL := VSQLSEL || 'JIDO_KOKUSEKI,';
            VSQLSEL := VSQLSEL || 'HOGOSHA_KOKUSEKI,';
            VSQLSEL := VSQLSEL || 'BIKO ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWJIDOZAIGAKU ';
            IF g_rJSTP.Chohyonum = '2102' THEN 
              VSQLSEL := VSQLSEL || 'WHERE JINKAKU_KBN = 1 ';
              VSQLSEL := VSQLSEL || 'AND GAKUNEN_CD IN(1,2,3,4,5,6) ';
            ELSIF g_rJSTP.Chohyonum = '2103' THEN
              VSQLSEL := VSQLSEL || 'WHERE JINKAKU_KBN = 1 ';
              VSQLSEL := VSQLSEL || 'AND GAKUNEN_CD IN(7,8,9) ';
            END IF;
--  2024/09/02 ZCZL.WANGMING UPDATE START 0.3.000.001:8月1日認識合わせの横展開            
--            VSQLSEL := VSQLSEL || ' ORDER BY '|| g_rJSTP.Orderbyclause ||'';
            IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
               VSQLSEL := VSQLSEL || ' ORDER BY '|| g_rJSTP.ORDERBYCLAUSE ;
            END IF;
--  2024/09/02 ZCZL.WANGMING UPDATE END
            OPEN curDATA FOR VSQLSEL;
            LOOP
              FETCH curDATA INTO RREC;
              EXIT WHEN curDATA%NOTFOUND;
                  MJIDO_WORK(ICNT).JIDO_KOJIN_NO           := RREC.JIDO_KOJIN_NO;
                  MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA        := RREC.JIDO_SHIMEI_KANA;
                  MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI       := RREC.JIDO_SHIMEI_KANJI;
                  MJIDO_WORK(ICNT).SEINENGAPI              := RREC.SEINENGAPI;
                  MJIDO_WORK(ICNT).HYOJI_SEINENGAPI        := RREC.HYOJI_SEINENGAPI;
                  MJIDO_WORK(ICNT).SEIBETSU                := RREC.SEIBETSU;
                  MJIDO_WORK(ICNT).HYOJI_SEIBETSU          := RREC.HYOJI_SEIBETSU;
                  MJIDO_WORK(ICNT).ZOKUGARAMEI1            := RREC.ZOKUGARAMEI1;
                  MJIDO_WORK(ICNT).SETAI_NO                := RREC.SETAI_NO;
                  MJIDO_WORK(ICNT).HYOJI_SETAI_NO          := RREC.HYOJI_SETAI_NO;
                  MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO        := RREC.HOGOSHA_KOJIN_NO;
                  MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA     := RREC.HOGOSHA_SHIMEI_KANA;
                  MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI    := RREC.HOGOSHA_SHIMEI_KANJI;
                  MJIDO_WORK(ICNT).ZOKUGARAMEI2            := RREC.ZOKUGARAMEI2;
                  MJIDO_WORK(ICNT).GAKUNEN_CD              := RREC.GAKUNEN_CD;
                  MJIDO_WORK(ICNT).GAKUNENMEI              := RREC.GAKUNENMEI;
                  MJIDO_WORK(ICNT).GAKOKU_CD               := RREC.GAKOKU_CD;
                  MJIDO_WORK(ICNT).GAKOKUMEI               := RREC.GAKOKUMEI;
                  MJIDO_WORK(ICNT).GYOSEIKU_CD             := RREC.GYOSEIKU_CD;
                  MJIDO_WORK(ICNT).GYOSEIKUMEI             := RREC.GYOSEIKUMEI;
                  MJIDO_WORK(ICNT).HAN_CD                  := RREC.HAN_CD;
                  MJIDO_WORK(ICNT).HANMEI                  := RREC.HANMEI;
                  MJIDO_WORK(ICNT).SANTEIDANTAI_CD         := RREC.SANTEIDANTAI_CD;
                  MJIDO_WORK(ICNT).SANTEIDANTAIMEI         := RREC.SANTEIDANTAIMEI;
                  MJIDO_WORK(ICNT).YUBIN_NO                := RREC.YUBIN_NO;
                  MJIDO_WORK(ICNT).CHOMEI                  := RREC.CHOMEI;
                  MJIDO_WORK(ICNT).BANCHI                  := RREC.BANCHI;
                  MJIDO_WORK(ICNT).KATAGAKI                := RREC.KATAGAKI;
                  MJIDO_WORK(ICNT).NENDO                   := RREC.NENDO;
                  MJIDO_WORK(ICNT).KAIPEJI_CD              := RREC.KAIPEJI_CD;
                  MJIDO_WORK(ICNT).KAIPEJI                 := RREC.KAIPEJI;
                  MJIDO_WORK(ICNT).SAKUSEIBI               := RREC.SAKUSEIBI;
                  MJIDO_WORK(ICNT).RENBAN                  := RREC.RENBAN;
                  MJIDO_WORK(ICNT).HYOJI_RENBAN            := RREC.HYOJI_RENBAN;
                  MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN    := RREC.HOGOSHA_SHIMEI_JODAN;
                  MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN    := RREC.HOGOSHA_SHIMEI_GEDAN;
                  MJIDO_WORK(ICNT).KON_JUSHO_JODAN         := RREC.KON_JUSHO_JODAN;
                  MJIDO_WORK(ICNT).KON_JUSHO_GEDAN         := RREC.KON_JUSHO_GEDAN;
                  MJIDO_WORK(ICNT).JINKAKU_KBN             := RREC.JINKAKU_KBN;
                  MJIDO_WORK(ICNT).KIJUNBI                 := RREC.KIJUNBI;
                  MJIDO_WORK(ICNT).GAKKO_CD                := RREC.GAKKO_CD;
                  MJIDO_WORK(ICNT).GAKKOMEI                := RREC.GAKKOMEI;
                  MJIDO_WORK(ICNT).JIDO_KOKUSEKI           := RREC.JIDO_KOKUSEKI;
                  MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI        := RREC.HOGOSHA_KOKUSEKI;
                  MJIDO_WORK(ICNT).BIKO                    := RREC.BIKO;
                  VPAGEFIELD := RREC.GAKUNEN_CD || RREC.GAKOKU_CD;
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
                  nRTN := GKAFKKKMGET(RREC.JIDO_KOKUSEKI,oKOKUMEI,oJIDO_KOKUMEI,oKOKUMEI_ALPHABET);        --児童生徒国籍
                  nRTN := GKAFKKKMGET(RREC.HOGOSHA_KOKUSEKI,oKOKUMEI,oHOGOSHA_KOKUMEI,oKOKUMEI_ALPHABET);  --保護者国籍
                  nCOUNT := nCOUNT +1;
                  IF g_rJSTP.Chohyonum = '2101' THEN 
                      INSERT INTO GKBWZAIGAKUMID (JIDO_KOJIN_NO,
                                          HOGOSHA_KOJIN_NO,
                                          NENDO,
                                          GAKOKU_CD,
                                          GAKKOKUMEI,
                                          GAKKO_CD,
                                          GAKOMEI,
                                          GAKUNEN_CD,
                                          GAKUNENMEI,
                                          GENZAIBI,
                                          JIDO_SHIMEI_KANA,
                                          JIDO_SHIMEI_KANJI,
                                          SEIBETSU,
                                          HYOJI_SEIBETSU,
                                          HOGOSHA_SHIMEI_KANA,
                                          HOGOSHA_SHIMEI_KANJI,
                                          KO_ZOKUGARA,
                                          OYA_ZOKUGARA,
                                          SEINENGAPI,
                                          JYUSYO_1,
                                          JYUSYO_2,
                                          GYOSEIKUMEI,
                                          JIINGAKU_KBN,
                                          KIJUNBI,
                                          JIDO_KOKUSEKI,
                                          HOGOSHA_KOKUSEKI,
                                          KAIPEJI_CD,
                                          KAIPEJI,
                                          SAKUSEIBI,
                                          RENBAN,
                                          HYOJI_RENBAN
                                          )
                                    VALUES(
                                         MJIDO_WORK(ICNT).JIDO_KOJIN_NO,
                                         MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO,
                                         MJIDO_WORK(ICNT).NENDO,
                                         MJIDO_WORK(ICNT).GAKOKU_CD,
                                         MJIDO_WORK(ICNT).GAKOKUMEI,
                                         MJIDO_WORK(ICNT).GAKKO_CD,
                                         MJIDO_WORK(ICNT).GAKKOMEI,
                                         MJIDO_WORK(ICNT).GAKUNEN_CD,
                                         MJIDO_WORK(ICNT).GAKUNENMEI,
                                         MJIDO_WORK(ICNT).SAKUSEIBI,
                                         MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA,
                                         MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI,
                                         MJIDO_WORK(ICNT).SEIBETSU,
                                         MJIDO_WORK(ICNT).HYOJI_SEIBETSU,
                                         MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
                                         MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI,
                                         MJIDO_WORK(ICNT).ZOKUGARAMEI1,
                                         MJIDO_WORK(ICNT).ZOKUGARAMEI2,
--  2025/01/20 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:ST_GKB_00001対応 Start
                                         --MJIDO_WORK(ICNT).SEINENGAPI,
                                         MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,
--  2025/01/20 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:ST_GKB_00001対応 End
                                         MJIDO_WORK(ICNT).KON_JUSHO_JODAN,
                                         MJIDO_WORK(ICNT).KON_JUSHO_GEDAN,
                                         MJIDO_WORK(ICNT).GYOSEIKUMEI,
                                         MJIDO_WORK(ICNT).JINKAKU_KBN,
                                         MJIDO_WORK(ICNT).KIJUNBI,
                                         oJIDO_KOKUMEI,
                                         oHOGOSHA_KOKUMEI,
                                         MJIDO_WORK(ICNT).KAIPEJI_CD,
                                         MJIDO_WORK(ICNT).KAIPEJI,
                                         MJIDO_WORK(ICNT).SAKUSEIBI,
                                         MJIDO_WORK(ICNT).RENBAN,
                                         MJIDO_WORK(ICNT).HYOJI_RENBAN
                                    );
                  ELSIF g_rJSTP.Chohyonum = '2102' THEN 
                    INSERT INTO GKBWL210R002 (NO,
                                              SAKUSEIBI,
                                              TITLE,
                                              JIDO_SHIMEI_KANA,
                                              JIDO_SHIMEI_KANJI,
                                              HOGOSHA_SHIMEI_KANA,
                                              HOGOSHA_SHIMEI_KANJI,
                                              SEINENGAPI,
                                              SEIBETSU,
                                              JIDO_ZOKUGARAMEI,
                                              JIDO_KOKUSEKI,
                                              HOGOSYA_KOKUSEKI,
                                              GAKOMEI,
                                              GAKUNEN,
                                              BREAK_NO,
                                              WSNUM,
                                              BATCHKBN,
                                              JOBNUM)
                                       VALUES ( 
                                              nCOUNT,
                                              MJIDO_WORK(ICNT).SAKUSEIBI,
                                              '外国籍児童一覧',
                                              MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA,
                                              MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI,
                                              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
                                              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI,
                                              MJIDO_WORK(ICNT).SEINENGAPI,
                                              MJIDO_WORK(ICNT).SEIBETSU,
                                              MJIDO_WORK(ICNT).ZOKUGARAMEI2,
                                              oJIDO_KOKUMEI,
                                              oHOGOSHA_KOKUMEI,
                                              MJIDO_WORK(ICNT).GAKKOMEI,
                                              MJIDO_WORK(ICNT).GAKUNENMEI,
                                              LPAD(MJIDO_WORK(ICNT).GAKUNEN_CD,3,0),
                                              g_sWSNUM,
                                              2,
                                              g_nJOBNUM
                                       );
                  ELSIF g_rJSTP.Chohyonum = '2103' THEN 
                    INSERT INTO GKBWL210R003(NO,
                                             SAKUSEIBI,
                                             TITLE,
                                             JIDO_SHIMEI_KANA,
                                             JIDO_SHIMEI_KANJI,
                                             HOGOSHA_SHIMEI_KANA,
                                             HOGOSHA_SHIMEI_KANJI,
                                             SEINENGAPI,
                                             SEIBETSU,
                                             JIDO_ZOKUGARAMEI,
                                             JIDO_KOKUSEKI,
                                             HOGOSYA_KOKUSEKI,
                                             GAKOMEI,
                                             GAKUNEN,
                                             BREAK_NO,
                                             WSNUM,
                                             BATCHKBN,
                                             JOBNUM)
                                      VALUES ( 
                                             nCOUNT,
                                             MJIDO_WORK(ICNT).SAKUSEIBI,
                                             '外国籍生徒一覧',
                                             MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA,
                                             MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI,
                                             MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
                                             MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI,
                                             MJIDO_WORK(ICNT).SEINENGAPI,
                                             MJIDO_WORK(ICNT).SEIBETSU,
                                             MJIDO_WORK(ICNT).ZOKUGARAMEI2,
                                             oJIDO_KOKUMEI,
                                             oHOGOSHA_KOKUMEI,
                                             MJIDO_WORK(ICNT).GAKKOMEI,
                                             MJIDO_WORK(ICNT).GAKUNENMEI,
                                             LPAD(MJIDO_WORK(ICNT).GAKUNEN_CD,3,0),
                                             g_sWSNUM,
                                             2,
                                             g_nJOBNUM
                                      );
                  END IF;
                  ICNT := ICNT + 1;
            END LOOP;

            IF g_rJSTP.Chohyonum = '2101' THEN 
              ICNT := 0;
--  2024/09/02 ZCZL.WANGMING UPDATE START 0.3.000.001:8月1日認識合わせの横展開
--              VSQLSEL := 'SELECT * FROM GKBWZAIGAKUMID ORDER BY ' || g_rJSTP.Orderbyclause;
                VSQLSEL := ' SELECT * FROM GKBWZAIGAKUMID ';
                IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
                     VSQLSEL := VSQLSEL || ' ORDER BY ' || g_rJSTP.Orderbyclause;
                END IF;
--  2024/09/02 ZCZL.WANGMING UPDATE END      
                        OPEN curDATA FOR VSQLSEL;
                        LOOP
                        FETCH curDATA INTO REC;
                        EXIT WHEN curDATA%NOTFOUND;
                            ZAIGAKU_WORK(ICNT).JIDO_KOJIN_NO            := REC.JIDO_KOJIN_NO;
                            ZAIGAKU_WORK(ICNT).HOGOSHA_KOJIN_NO         := REC.HOGOSHA_KOJIN_NO;
                            ZAIGAKU_WORK(ICNT).NENDO                    := REC.NENDO;
                            ZAIGAKU_WORK(ICNT).GAKOKU_CD                := REC.GAKOKU_CD;
                            ZAIGAKU_WORK(ICNT).GAKKOKUMEI               := REC.GAKKOKUMEI;
                            ZAIGAKU_WORK(ICNT).GAKKO_CD                 := REC.GAKKO_CD;
                            ZAIGAKU_WORK(ICNT).GAKOMEI                  := REC.GAKOMEI;
                            ZAIGAKU_WORK(ICNT).GAKUNEN_CD               := REC.GAKUNEN_CD;
                            ZAIGAKU_WORK(ICNT).GAKUNENMEI               := REC.GAKUNENMEI;
                            ZAIGAKU_WORK(ICNT).GENZAIBI                 := REC.GENZAIBI;
                            ZAIGAKU_WORK(ICNT).JIDO_SHIMEI_KANA         := REC.JIDO_SHIMEI_KANA;
                            ZAIGAKU_WORK(ICNT).JIDO_SHIMEI_KANJI        := REC.JIDO_SHIMEI_KANJI;
                            ZAIGAKU_WORK(ICNT).SEIBETSU                 := REC.SEIBETSU;
                            ZAIGAKU_WORK(ICNT).HYOJI_SEIBETSU           := REC.HYOJI_SEIBETSU;
                            ZAIGAKU_WORK(ICNT).HOGOSHA_SHIMEI_KANA      := REC.HOGOSHA_SHIMEI_KANA;
                            ZAIGAKU_WORK(ICNT).HOGOSHA_SHIMEI_KANJI     := REC.HOGOSHA_SHIMEI_KANJI;
                            ZAIGAKU_WORK(ICNT).KO_ZOKUGARA              := REC.KO_ZOKUGARA;
                            ZAIGAKU_WORK(ICNT).OYA_ZOKUGARA             := REC.OYA_ZOKUGARA;
                            ZAIGAKU_WORK(ICNT).SEINENGAPI               := REC.SEINENGAPI;
                            ZAIGAKU_WORK(ICNT).JYUSYO_1                 := REC.JYUSYO_1;
                            ZAIGAKU_WORK(ICNT).JYUSYO_2                 := REC.JYUSYO_2;
                            ZAIGAKU_WORK(ICNT).GYOSEIKUMEI              := REC.GYOSEIKUMEI;
                            ZAIGAKU_WORK(ICNT).BIKO                     := REC.BIKO;
                            ZAIGAKU_WORK(ICNT).KIJUNBI                  := REC.KIJUNBI;
                            ZAIGAKU_WORK(ICNT).JIINGAKU_KBN             := REC.JIINGAKU_KBN;
                            ZAIGAKU_WORK(ICNT).JIDO_KOKUSEKI            := REC.JIDO_KOKUSEKI;
                            ZAIGAKU_WORK(ICNT).HOGOSHA_KOKUSEKI         := REC.HOGOSHA_KOKUSEKI;
                            ZAIGAKU_WORK(ICNT).KAIPEJI_CD               := REC.KAIPEJI_CD;
                            ZAIGAKU_WORK(ICNT).KAIPEJI                  := REC.KAIPEJI;
                            ZAIGAKU_WORK(ICNT).SAKUSEIBI                := REC.SAKUSEIBI;
                            ZAIGAKU_WORK(ICNT).RENBAN                   := REC.RENBAN;
                            ZAIGAKU_WORK(ICNT).HYOJI_RENBAN             := REC.HYOJI_RENBAN;
                        ICNT := ICNT + 1;
                        END LOOP;
              I_RTN := FUNC_SET_JIDO_WK_CSVFILE();
            END IF;

            vWHERE := '';
            CASE g_rJSTP.Chohyonum
              WHEN '2101' THEN
--  2024/09/02 ZCZL.WANGMING DELETE 0.3.000.001:8月1日認識合わせの横展開
--                nCOUNT := GKBFKTBLCNT('GKBWL210R001', vWHERE);
                g_nINDEX := g_nINDEX + 1;
                g_oKENSU_LIST.EXTEND(1);
                g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '入力 校区別在学者一覧対象件数', 1);
                g_nINDEX := g_nINDEX + 1;
                g_oKENSU_LIST.EXTEND(1);
--  2024/09/02 ZCZL.WANGMING UPDATE START 0.3.000.001:8月1日認識合わせの横展開
--                g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '出力　校区別在学者一覧ＣＳＶ', 2);
                KENSUU_COUNT := GKBFKTBLCNT('GKBWL210R001', ' BATCHKBN = ' || c_BATCH || ' AND WSNUM = ''' || g_sWSNUM || '''');
                g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(KENSUU_COUNT, '出力　校区別在学者一覧ＣＳＶ', 2);
--  2024/09/02 ZCZL.WANGMING UPDATE END
              WHEN '2102' THEN
--  2024/09/02 ZCZL.WANGMING UPDATE START 0.3.000.001:8月1日認識合わせの横展開
--                nCOUNT := GKBFKTBLCNT('GKBWL210R002', vWHERE);
--                g_nINDEX := g_nINDEX + 1;
--                g_oKENSU_LIST.EXTEND(1);
--                g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '入力 外国籍児童一覧対象件数', 3);
                g_nINDEX := g_nINDEX + 1;
                g_oKENSU_LIST.EXTEND(1);
--                g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '出力　外国籍児童一覧ＣＳＶ', 4);
                KENSUU_COUNT := GKBFKTBLCNT('GKBWL210R002', ' BATCHKBN = ' || c_BATCH || ' AND WSNUM = ''' || g_sWSNUM || '''');
                g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(KENSUU_COUNT, '出力　外国籍児童一覧ＣＳＶ', 2);
--  2024/09/02 ZCZL.WANGMING UPDATE END
              WHEN '2103' THEN
--  2024/09/02 ZCZL.WANGMING UPDATE START 0.3.000.001:8月1日認識合わせの横展開
--                nCOUNT := GKBFKTBLCNT('GKBWL210R003', vWHERE);
--                g_nINDEX := g_nINDEX + 1;
--                g_oKENSU_LIST.EXTEND(1);
--                g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '入力 外国籍生徒一覧対象件数', 5);
                g_nINDEX := g_nINDEX + 1;
                g_oKENSU_LIST.EXTEND(1);
--                g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '出力　外国籍生徒一覧ＣＳＶ', 6);
                KENSUU_COUNT := GKBFKTBLCNT('GKBWL210R003', ' BATCHKBN = ' || c_BATCH || ' AND WSNUM = ''' || g_sWSNUM || '''');
                g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(KENSUU_COUNT, '出力　外国籍生徒一覧ＣＳＶ', 2);
--  2024/09/02 ZCZL.WANGMING UPDATE END
              ELSE
                NULL;
            END CASE;

            --関数終了
--  2024/09/02 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶ' || nCOUNT || '件を出力しました。', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_CSV_CREATE', 0, '', '', 'ＣＳＶ' || nCOUNT || '件を出力しました。', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
        EXCEPTION
            WHEN OTHERS THEN
                FRET := c_INOT_SUCCESS;      
                -- 異常終了
--  2024/09/02 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--                bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイルの書き出し処理が異常終了しました。', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
                bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_CSV_CREATE', 1, SQLCODE, SQLERRM, 'ＣＳＶファイルの書き出し処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
        END;
        RETURN FRET;
    END FUNC_CSV_CREATE;
    
-- 2024/06/12 ZCZL.wangyunhan Add end 

    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        VcmbGakunenStart          DBMS_UTILITY.MAXNAME_ARRAY;
        VcmbGakunenEnd          DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/10/30 ZCZL.WANGYUNING ADD 0.3.000.005:学校コードリスト仕様変更IT_GKB_00090の対応
        objShogakkoCd              DBMS_UTILITY.MAXNAME_ARRAY;
        objChugakkoCd              DBMS_UTILITY.MAXNAME_ARRAY;
        objKuikigaiGakkoCd         DBMS_UTILITY.MAXNAME_ARRAY;
        objTokubetsuShienGakkoCd   DBMS_UTILITY.MAXNAME_ARRAY;
        objKokuSirituGakoCd        DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00664対応 START
        objSyougakoKuCd            DBMS_UTILITY.MAXNAME_ARRAY;
        objCyugakoKuCd             DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00664対応 END
--  2024/10/30 ZCZL.WANGYUNING ADD END
    BEGIN
        --作成年度
        g_vJYOUKEN01 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtNendo');
        --開始学年 範囲(開始)
        VcmbGakunenStart := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbGakunenStart');
        g_vJYOUKEN02 := VcmbGakunenStart(1);
        --終了学年 範囲(終了)
        VcmbGakunenEnd := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbGakunenEnd');
        g_vJYOUKEN03 := VcmbGakunenEnd(1);
        --基準日
        g_vJYOUKEN04 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKijunBi');
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
        --任意選択項目
--         g_vJYOUKEN05 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtNiniBit');
-- 2024/06/12 ZCZL.wangyunhan Delete end 
--  2024/10/30 ZCZL.WANGYUNING UPDATE START 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
        --小学校コード
        --g_vJYOUKEN06 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtShogakkoCd');
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtShogakkoCd');
        g_vJYOUKEN06 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShogakkoCd',0, objShogakkoCd);
        --中学校コード
        --g_vJYOUKEN07 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtChugakkoCd');
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtChugakkoCd');
        g_vJYOUKEN07 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtChugakkoCd',0, objChugakkoCd);
        --区域外学校コード
        --g_vJYOUKEN08 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKuikigaiGakkoCd');
        objKuikigaiGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKuikigaiGakkoCd');
        g_vJYOUKEN08 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuikigaiGakkoCd',0, objKuikigaiGakkoCd);
        --特別支援学校コード
        --g_vJYOUKEN09 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtTokubetsuShienGakkoCd');
        objTokubetsuShienGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtTokubetsuShienGakkoCd');
        g_vJYOUKEN09 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtTokubetsuShienGakkoCd',0, objTokubetsuShienGakkoCd);
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        --国・私立学校コード
        --g_vJYOUKEN10 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKokuSirituGakoCd');
        objKokuSirituGakoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKokuSirituGakoCd');
        g_vJYOUKEN10 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKokuSirituGakoCd',0, objKokuSirituGakoCd);
--  2024/10/30 ZCZL.WANGYUNING UPDATE END
        --小学校区
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00664対応 START
--        g_vJYOUKEN11 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSyougakoKuCd');
        objSyougakoKuCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtSyougakoKuCd');
        g_vJYOUKEN11 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtSyougakoKuCd',0, objSyougakoKuCd);
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00664対応 END
        --中学校区
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00664対応 START
--        g_vJYOUKEN12 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtCyugakoKuCd');
        objCyugakoKuCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtCyugakoKuCd');
        g_vJYOUKEN12 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtCyugakoKuCd',0, objCyugakoKuCd);
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00664対応 END
-- 2024/06/12 ZCZL.wangyunhan Add end 
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
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

        VMSG := '' ;
        IRTN := 0 ;
        ICHK1 := 0 ;
        ICHK2 := 0 ;
        ICHK3 := 0 ;

        --条件１のチェック
        IRTN := FUNCNENDOCHK( g_vJYOUKEN01 ) ;
        IF IRTN <> 0 THEN
          ICHK1 := 1 ;
            VMSG := g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;' ;
        END IF ;

        --条件２のチェック
        IRTN := FUNCGAKUNENCHK( g_vJYOUKEN02 ) ;
        IF IRTN <> 0 THEN
          ICHK2 := 1 ;
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,開始学年が正しくありません。,;' ;
        END IF ;

        --条件３のチェック
        IRTN := FUNCGAKUNENCHK( g_vJYOUKEN03 ) ;
        IF IRTN <> 0 THEN
          ICHK3 := 1 ;
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,終了学年が正しくありません。,;' ;
        END IF ;

        --条件２と条件３の大小チェックを行う。
        IF ICHK2 = 0 AND ICHK3 = 0 THEN
          IRTN := FUNCHIKAKUCHK( g_vJYOUKEN02, g_vJYOUKEN03 ) ;
          IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,開始学年と終了学年の大小関係が誤っています。,;' ;
          END IF ;
        END IF ;

        --条件４のチェック
        IRTN := FUNCHIZUKECHK(g_vJYOUKEN04) ;
        IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;' ;
        END IF;

        --基準日の年度がシステム日付の年度ではない場合エラー
        IKIJUN_NENDO := KKAPK0020.FDAYNENDO(0,g_vJYOUKEN04);
        IKIJUN_NENDO := KKAPK0020.FNENDO(IKIJUN_NENDO,1);
        ISYS_NENDO   := KKAPK0020.FDAYNENDO(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),0);
        IF IRTN = 0 AND IKIJUN_NENDO != ISYS_NENDO THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日には年度内を指定してください。,;' ;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
        --条件５のチェック
--         IRTN := FUNCNINIBITCHK(g_vJYOUKEN05);
--         IF IRTN <> 0 THEN
--           VMSG := VMSG || g_sGYOUMUCODE || ',99999,任意ビットが正しくありません。,;';
--         END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete end
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
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

-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------
    --  機能概要      : コード取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.wangyunhan 2024/06/12
    --------------------------------------------------------
    FUNCTION FUNC_GET_GAKOCD(i_sGAKOCD IN NVARCHAR2, o_sGAKOCD OUT NVARCHAR2) RETURN BOOLEAN
    IS
        aGAKOCD           KKBPK5551.tySPLIT_tbl;      -- コード（リスト）
--  2024/10/30 ZCZL.WANGYUNING ADD 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
        nGAKOUCD_TMP  NUMBER; --学校コード
    BEGIN
        -- 入力引数を分解して配列にセットする
        -- 引数のコード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
--  2024/10/30 ZCZL.WANGYUNING UPDATE START 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
        ---- 処理ステップを取得
        --FOR i IN 1..aGAKOCD.COUNT LOOP
        --    IF MOD(i - 1, 2) = 0 AND aGAKOCD.COUNT > 2 THEN
        --        IF i = aGAKOCD.COUNT - 1 THEN
        --            o_sGAKOCD := o_sGAKOCD || aGAKOCD(i);
        --        ELSE
        --            o_sGAKOCD := o_sGAKOCD || aGAKOCD(i) || ',';
        --        END IF;
        --    ELSIF aGAKOCD.COUNT = 2 THEN
        --        o_sGAKOCD := aGAKOCD(1);
        --        EXIT;
        --    ELSE
        --        NULL;
        --    END IF;
        --END LOOP;
        o_sGAKOCD := '';
        FOR i IN 1..aGAKOCD.COUNT LOOP
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00664対応 START
--            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
            nGAKOUCD_TMP := TO_NUMBER(aGAKOCD(i));
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00664対応 END
            IF nGAKOUCD_TMP IS NOT NULL THEN
                IF i = aGAKOCD.COUNT THEN
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP ;
                ELSE
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP || ',';
                END IF;
            END IF;
        END LOOP;
--  2024/10/30 ZCZL.WANGYUNING UPDATE END
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_GET_GAKOCD;
-- 2024/06/12 ZCZL.wangyunhan Add end

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        eEXCEPTION       EXCEPTION; 
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        EDITGAKKOKU_CD    NVARCHAR2(100);     --学校区コード
        o_sMEISHO         NVARCHAR2(20);
        o_sMEISHOKANA     NVARCHAR2(20);
        o_sYOBI           NVARCHAR2(20);
        o_tITEM          A_CONS_PRM;   --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
-- 2024/06/12 ZCZL.wangyunhan Add end 
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
--  2024/04/22 ZCZL.WUCAO DELETE 0.2.000.001:512_GKB_00027対応
--        IF g_nSTEP_INDEX = 1 THEN
-- 2024/06/12 ZCZL.wangyunhan Delete 0.3.000.000:新WizLIFE２次開発
--           DELETE FROM GKBWL210R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
--  2024/04/22 ZCZL.WUCAO DELETE 0.2.000.001:512_GKB_00027対応
--          BEGIN

              -- 取得した条件をそれぞれの変数へセット
              VNENDO := KKAPK0020.FNENDO(g_vJYOUKEN01,1);        -- 対象年度
              VGAKUNEN        := g_vJYOUKEN02;                   -- 学年
              VSYURYOGAKUNEN  := g_vJYOUKEN03;                   -- 終了学年
              KIJUNBI        := g_vJYOUKEN04;                    -- 基準日
-- 2024/06/12 ZCZL.wangyunhan Delete 0.3.000.000:新WizLIFE２次開発
--               VNINIBIT  := g_vJYOUKEN05;                         -- 任意ビット１
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--               VSYOGAKO_CD  := g_vJYOUKEN06;                      -- 小学校コード
--               VTYUGAKO_CD  := g_vJYOUKEN07;                      -- 中学校コード
--               VKUIKIGAI_CD := g_vJYOUKEN08;                      -- 区域外学校コード
--               VYOGOGAKO_CD := g_vJYOUKEN09;                      -- 特別支援学校コード
              -- 小学校コード(編集後)
              bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN06, VSYOGAKO_CD);
              -- 中学校コード(編集後)
              bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN07, VTYUGAKO_CD);
              -- 区域外学校コード(編集後)
              bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN08, VKUIKIGAI_CD);
              -- 特別支援学校コード(編集後)
              bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN09, VYOGOGAKO_CD);
              -- 国・私立学校コード(編集後)
              bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN10, VSIRITUGAKO_CD);
              -- 小学校区(編集後)
              bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN11, VSYOUGAKOKUCD);
              -- 中学校区(編集後)
              bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN12, VCYUGAKOKUCD);
-- 2024/06/12 ZCZL.wangyunhan Update end
              o_SHIMEIPRM := A_CONS_PRM();
              I_RTN := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,o_SHIMEIPRM,o_LENGTH);
              IF I_RTN = 1 THEN
                            o_SHIMEIPRM := A_CONS_PRM();
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(1) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(2) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(3) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(4) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(5) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(6) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(7) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(8) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(9) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(10) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(11) := 0;
                            o_SHIMEIPRM.EXTEND;
                            o_SHIMEIPRM(12) := 0;
              ELSE
                WHILE (o_LENGTH < 13) LOOP
                  o_SHIMEIPRM.EXTEND;
                  o_SHIMEIPRM(o_LENGTH+1) := 0;
                  o_LENGTH := o_LENGTH + 1;
                END LOOP;
              END IF;

              -- 児童生徒ワーク（GKBWJIDOZAIGAKU）のデータ全件削除
              I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
              IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
                  B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
                  RAISE eEXCEPTION;
              END IF;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
              --校区別在学者一覧中間ワーク（GKBWZAIGAKUMID）のデータ全件削除
              I_RTN := KKAPK3000.FTRUNCATE('GKBWZAIGAKUMID', VSQLERRM);
              IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
                  B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
                  RAISE eEXCEPTION;
              END IF;
              -- システム制御設定を取得する
              -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する。
              I_RTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, o_tITEM);
              IF I_RTN = 0 THEN
                FOR i IN 1..o_tITEM.COUNT LOOP
                  CASE o_tITEM(i)
                    WHEN 'GKB210R001' THEN
                      g_ZAIGAKUMID_INDEXNO := i;
                    WHEN 'GKB210R002' THEN
                      g_GAIKOKUSEKIJIDOU_INDEXNO := i;
                      g_GAIKOKUSEKISEIYO_INDEXNO := i;
                    ELSE
                      NULL;
                  END CASE;
                END LOOP;
                --「本名・通称名　出力制御」のリストを取得する。
                I_RTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, o_tITEM);
                IF I_RTN = 0 THEN
                    IF g_ZAIGAKUMID_INDEXNO <= o_tITEM.COUNT THEN
                        g_ZAIGAKUMIDSEIGYO       := o_tITEM(g_ZAIGAKUMID_INDEXNO);          --校区別在学者一覧_出力制御
                    END IF;
                    IF g_GAIKOKUSEKIJIDOU_INDEXNO <= o_tITEM.COUNT THEN
                        g_GAIKOKUSEKIJIDOUSEIGYO := o_tITEM(g_GAIKOKUSEKIJIDOU_INDEXNO);    --外国籍児童一覧_出力制御
                    END IF;
                    IF g_GAIKOKUSEKISEIYO_INDEXNO <= o_tITEM.COUNT THEN
                        g_GAIKOKUSEKISEIYOSEIGYO := o_tITEM(g_GAIKOKUSEKISEIYO_INDEXNO);    --外国籍生徒一覧_出力制御
                    END IF;
                END IF;
              END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end
              -- 児童生徒中間データ作成
              I_RTN := FUNC_GET_JIDO_WK;
              IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
                  IF I_RTN = c_INOTFOUND THEN
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--                      B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
                      GOTO END_EXIT;
                  END IF;
                  RAISE eEXCEPTION;
              END IF;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
              --帳票ワークをクリアする。
              CASE g_rJSTP.Chohyonum
                WHEN '2101' THEN
                    DELETE FROM GKBWL210R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
                WHEN '2102' THEN
                    DELETE FROM GKBWL210R002 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
                WHEN '2103' THEN
                    DELETE FROM GKBWL210R003 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
                ELSE
                    NULL;
              END CASE;
              --ＣＳＶファイル作成処理
              I_RTN := FUNC_CSV_CREATE();
              IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
                  RAISE eEXCEPTION;
              END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--              -- 児童生徒中間データ作成（ＣＳＶ用）
--              I_RTN := FUNC_GET_JIDO_WK_CSV;
--              IF I_RTN <> c_ISUCCESS THEN
--              -- エラーで帰ってきた場合
--                  RAISE eEXCEPTION;
--              END IF;
--              -- 児童生徒中間ＣＳＶファイル作成
--              I_RTN := FUNC_SET_JIDO_WK_CSVFILE;
--              IF I_RTN <> c_ISUCCESS THEN
--              -- エラーで帰ってきた場合
--                  RAISE eEXCEPTION;
--              END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete end 
--  2024/04/22 ZCZL.WUCAO DELETE START 0.2.000.001:512_GKB_00027対応
--              B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
--          EXCEPTION
--              /* その他エラー */
--              WHEN OTHERS THEN
--                  -- SQL情報取得
--                  N_SQL_CODE := SQLCODE;
--                  V_SQL_MSG  := SUBSTR(SQLERRM, 1 ,250);
                  -- 処理ログの出力
--                  B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
--                  RAISE eEXCEPTION;
--          END;
--        END IF;
--  2024/04/22 ZCZL.WUCAO DELETE END 
        --帳票出力CSVの作成
        CASE g_rJSTP.Chohyonum
          WHEN '2101' THEN
            bRTN := FUNC_B11CSV('GKBWL210R001');
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
           WHEN '2102' THEN
               bRTN := FUNC_B11CSV('GKBWL210R002');
           WHEN '2103' THEN
               bRTN := FUNC_B11CSV('GKBWL210R003');
-- 2024/06/12 ZCZL.wangyunhan Add end 
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;  --戻り値
        eEXCEPTION                    EXCEPTION; 
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/04
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
END GKBPB00450;
/
