CREATE OR REPLACE PACKAGE BODY GKBPC00120
--1.0.107.001-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 住記異動情報連携処理
--  機能概要      : 処理条件の住記異動更新日の範囲内及び処理日から求める対象者の
--                 生年月日の範囲内に該当する住記異動情報を抽出し、学齢簿情報の
--                 更新と住記異動更新対象者一覧を作成する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.ZHANGLEI 2024/01/02
--------------------------------------------------------
--  変更履歴
--  2024/04/19 ZCZL.LIKEWEN UPDATE 0.2.000.001:512_GKB_00018対応
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--  2024/09/02 ZCZL.WANGQIWEI UPDATE 0.3.030.000:フェーズ4対応
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.030.001:仕様変更　IT_GKB_00017対応
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.030.002:IT_GKB_00286横展開対応
--  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610対応
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.030.004:IT_GKB_00704対応
--  2025/01/15 JPJYS.SONGSHIHAO UPDATE 0.3.030.005:学校区マスタ対応（GKBTMSGAKKUを使用しないように）
--  2025/02/03 JPJYS.LIZIZHON GST_GKB_TMP00029  0.3.030.006 UPDATE
--  2025/02/14 JPJYS.GONGYANYAN ST_GKB_00002 0.3.030.007対応
--  2025/09/30 JPJYS.LIUJUNHAO UPDATE 1.0.107.001:GKB_QA_SBS372_異常終了対応
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

--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発(標準化)
    g_sJUKI_IDO_CODE        NVARCHAR2(1000);  --住記異動コード
    g_nGAKKU_KBN            NUMBER;           --学区管理区分
    g_nSOGYOU_SHORI_FLG     NUMBER;           --進級卒業処理フラグ
    g_nIDO_NENDO            NUMBER;           --MAX(年度)
    g_nGKB450R001_INDEX     NUMBER;           --住記異動更新対象者一覧_インデックス番号
    g_nGKB450R001_CTL       NUMBER;           --住記異動更新対象者一覧_出力制御
    g_sSYS_TANMATU_BASHO    NVARCHAR2(1000);  --共通パラメータの入力場所
--  2024/07/01 ZCZL.YANGXINYU ADD END

    --パラメータ変数
    g_vJOKEN1         NVARCHAR2(1000);
    g_vJOKEN2         NVARCHAR2(1000);
    g_vJOKEN3         NVARCHAR2(1000);
    g_vJOKEN4         NVARCHAR2(1000);
    g_vJOKEN5         NVARCHAR2(1000);
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- 処理結果
    C_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
    C_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    C_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし

    -- 住記連携ワーク
    C_VTABLE       CONSTANT  NVARCHAR2(128) := 'GKBWJUKIRENKEI';

    -- １頁の最大行数
    C_IMAXROWS     CONSTANT  PLS_INTEGER := 15;

    -- 異動種別
    C_IDO_JIYU_2   CONSTANT  NVARCHAR2(60) := '児童氏名変更　旧氏名：';    -- 異動種別=2の事由
    C_IDO_JIYU_3   CONSTANT  NVARCHAR2(60) := '保護者氏名変更　旧氏名：';  -- 異動種別=3の事由

    C_RENKEI_ID    CONSTANT  NVARCHAR2(3) := '999';  -- 連携ID

    -- システム条件:「児童との関係」判定条件
    c_ISYS_J_KANKEI  CONSTANT  PLS_INTEGER := 120;
    -- システム条件: 定数.新入学児童削除方法の条件連番
    c_ISYS_J_NUMBER  CONSTANT  PLS_INTEGER := 121;
--2024/11/02 ZCZL.WANGYUNING UPDATE START 0.3.000.004:IT_GKB_00286横展開対応
    o_sEINENGAPI1                    GKAPK00020.SEINENGAPI_REC;           --生年月日
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    -- エラー処理用
    N_SQL_CODE            NUMBER;             -- SQLエラーコード
    V_SQL_MSG             NVARCHAR2(255);     -- SQLエラーメッセージ

    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    B_RTN                 BOOLEAN;
    I_RTN                 PLS_INTEGER;

    --　システム日付
    ISAKUSEIBI            NUMBER;          -- システム日付
    VSAKUSEIBI            NVARCHAR2(11);   -- システム日付
    NSYSTIME              NUMBER;          -- システム時間

--  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 START
--件数作成用
     g_nINDEX              NUMBER := 0;
     NCINT                 NUMBER; 
     SCINT                 NUMBER;
     VLOG        NVARCHAR2(500);
--  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 END
    -- テーブル更新
    NRENBAN               NUMBER(5);       -- CSV連番
    NKAISHIBI             NUMBER(8);       -- 抽出開始住記異動更新日
    NSHURYOBI             NUMBER(8);       -- 抽出終了住記異動更新日
    NHOGOSHA_KBN          NUMBER(1);       -- 保護者判定区分
    NKOSHIN_KBN           NUMBER(1);       -- 学齢簿更新区分
    NSORT_KBN             NUMBER(1);       -- 改頁・ソート区分
    NSHORINENDO_S         NUMBER(4);       -- 処理年度(西暦)
    NSHORINENDO_W         NUMBER(3);       -- 処理年度(和暦)
    NSEINENGAPI_S         NUMBER(8);       -- 抽出対象生年月日(自)
    NSEINENGAPI_E         NUMBER(8);       -- 抽出対象生年月日(至)
    NCNT                  NUMBER(8);       -- カウント用
    NIDO_KBN              NUMBER(1);       -- 異動区分
    NGAIKOKUJIN_KBN       NUMBER(1);       -- 外国人区分
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--    NH_KOJIN_NO           NUMBER(12);      -- 保護者個人番号
    NH_KOJIN_NO           NUMBER(15);      -- 保護者個人番号
    NH_SEIBETSU           NUMBER(1);       -- 保護者性別
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--    NKYU_H_KOJIN_NO       NUMBER(12);      -- 旧保護者個人番号
    NKYU_H_KOJIN_NO       NUMBER(15);      -- 旧保護者個人番号
    NERRCODE              NUMBER(1);       -- エラーコード
    NNENDO_LASTDAY        NUMBER(8);       -- 年度末日
    NNENREI               NUMBER(3);       -- 年齢
    NGAKO_KBN             NUMBER(1);       -- 学校区分
    NGAKOKU               NUMBER(5);       -- 学校区
    NKYUGAKOKU            NUMBER(5);       --旧学校区
    NIDO_SHUBETSU         NUMBER(1);       -- 異動種別
    NSHORIBI_KEY          NUMBER(8);       -- 処理日キー
    NJUSHO_REN            NUMBER(3);       -- 住所連番
    NTAISHO_FLG           NUMBER(1);       -- 処理対象フラグ(0:対象、1:対象外)
    NGAK_RIREKI_RENBAN    NUMBER(3);       -- 学齢簿テーブル用履歴連番
    NGAK_NENREI           NUMBER(2);       -- 学齢簿テーブル用年齢
    NNUM                  NUMBER(2);       -- NUM
    NNYUGAKU_BI           NUMBER(8);       -- 入学年月日
    VKAISHIBI             NVARCHAR2(11);   -- 抽出開始住記異動更新日
    VSHURYOBI             NVARCHAR2(11);   -- 抽出終了住記異動更新日
    VSHIMEI_KANA          NVARCHAR2(100);  -- 氏名かな
    VSHIMEI_KANJI         NVARCHAR2(100);  -- 氏名漢字
    VKYU_SHIMEI_KANA      NVARCHAR2(100);  -- 旧氏名かな
    VKYU_SHIMEI_KANJI     NVARCHAR2(100);  -- 旧氏名漢字
    VJ_KYU_SHIMEI_KANA    NVARCHAR2(100);  -- 児童旧氏名かな
    VJ_KYU_SHIMEI_KANJI   NVARCHAR2(100);  -- 児童旧氏名漢字
    VH_SHIMEI_KANA        NVARCHAR2(100);  -- 保護者氏名かな
    VH_SHIMEI_KANJI       NVARCHAR2(100);  -- 保護者氏名漢字
    VH_KYU_SHIMEI_KANA    NVARCHAR2(100);  -- 保護者旧氏名かな
    VH_KYU_SHIMEI_KANJI   NVARCHAR2(100);  -- 保護者旧氏名漢字
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
    VH_HOGOSHA_RIREKI_RENBAN      NUMBER;  -- 保護者の宛名基本履歴連番
    VKYU_H_SHIMEI_KANA    NVARCHAR2(100);  -- 旧保護者氏名かな
    VKYU_H_SHIMEI_KANJI   NVARCHAR2(100);  -- 旧保護者氏名漢字
    VCHOMEI               NVARCHAR2(40);   -- 町名
    VBANCHI               NVARCHAR2(40);   -- 番地
    VKATAGAKI             NVARCHAR2(60);   -- 方書
    VIDO_BI_NAME          NVARCHAR2(10);   -- 異動日項目名
    VIDO_JIYU_NAME        NVARCHAR2(10);   -- 異動事由項目名
    VIDO_BI_NAME_NEXT     NVARCHAR2(10);   -- 異動日項目名NEXT
    VIDO_JIYU_NAME_NEXT   NVARCHAR2(10);   -- 異動事由項目名NEXT
    VW_KYU_ZOKUGARA       NVARCHAR2(30);   --更新前学齢簿続柄名

    VPAGENM               NVARCHAR2(500);  -- 改頁項目名
    VPAGEFD               NVARCHAR2(500);  -- 改頁項目値
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--    VSQLSEL               VARCHAR(3000);   -- 動的SQL
    VSQLSEL               VARCHAR(32767);   -- 動的SQL

    -- パラメータ配列
    o_RENBAN_PRM          A_CONS_PRM;      -- パラメータの配列
    o_LENGTH              NUMBER;          -- パラメータの配列の長さ

    -- 取得したデータのワーク領域
    TYPE MTJRENKEI_TYPE IS TABLE OF GKBWJUKIRENKEI%ROWTYPE INDEX BY BINARY_INTEGER;
    MJRENKEI_WORK MTJRENKEI_TYPE;

    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    IO_WAREKIHIZUKE   PLS_INTEGER;
    IO_SEIREKIHIZUKE  PLS_INTEGER;
    VEDIT_GYYMMDD1    NVARCHAR2(20);
    VEDIT_GYYMMDD2    NVARCHAR2(20);
    VEDIT_GYYMMDD3    NVARCHAR2(20);
    VKJ_GENGO         NVARCHAR2(20);
    VKG_GENGO         NVARCHAR2(20);
    IWAREKI_YY        PLS_INTEGER;
    ISEIREKI_YYYY     PLS_INTEGER;
    IWAREKI_GYYMM     PLS_INTEGER;
    IMM               PLS_INTEGER;
    IDD               PLS_INTEGER;
    IWAREKIHIZUKE     PLS_INTEGER;
    ISEIREKIHIZUKE    PLS_INTEGER;

    -- 抽出データ格納用
    TYPE CRJUKIIDO IS RECORD
    (
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--        KOJIN_NO                  NUMBER(12),      -- GABTJUKIIDO.個人番号
--        SETAI_NO                  NUMBER(7),       -- GABTJUKIIDO.世帯番号
        KOJIN_NO                  NUMBER(15),      -- GABTJUKIIDO.個人番号
        SETAI_NO                  NUMBER(15),       -- GABTJUKIIDO.世帯番号
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
        GENZON_KBN                NUMBER(1),       -- GABTJUKIIDO.現存区分
        JINKAKU_KBN               NUMBER(1),       -- GABTJUKIIDO.人格区分
        GYOSEIKU_CD               NUMBER(5),       -- GABTJUKIIDO.行政区コード
        HAN_CD                    NUMBER(15),      -- GABTJUKIIDO.班コード
        SHOGAKU_CD                NUMBER(5),       -- GABTJUKIIDO.小学校区コード
        CHUGAKU_CD                NUMBER(5),       -- GABTJUKIIDO.中学校区コード
        SANTEIDANTAI_CD           NUMBER(2),       -- GABTJUKIIDO.算定団体コード
        SEINENGAPI                NUMBER(8),       -- GABTJUKIIDO.生年月日
        SEIBETSU                  NUMBER(1),       -- GABTJUKIIDO.性別
        KISAI_JUNI                NUMBER(3),       -- GABTJUKIIDO.記載順位
        IDO_BI                    NUMBER(8),       -- GABTJUKIIDO.異動日
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--        IDO_JIYU                  NUMBER(2),       -- GABTJUKIIDO.異動事由
        IDO_JIYU                  NUMBER(3),       -- GABTJUKIIDO.異動事由
        IDO_TODOKE_BI             NUMBER(8),       -- GABTJUKIIDO.異動届出日
        GENJUSHO_REN              NUMBER(3),       -- GABTJUKIIDO.現住所連番
        ZENJUSHO_REN              NUMBER(3),       -- GABTJUKIIDO.前住所連番
        TENNYUMAE_REN             NUMBER(3),       -- GABTJUKIIDO.転入前住所連番
        TENSHUTSU_YOTEI_REN       NUMBER(3),       -- GABTJUKIIDO.転出予定地連番
        TENSHUTSU_KAKUTEI_REN     NUMBER(3),       -- GABTJUKIIDO.転出確定地連番
        SHIMEI_KANA               NVARCHAR2(100),  -- GABTJUKIIDO.氏名かな
        SHIMEI_KANJI              NVARCHAR2(100),  -- GABTJUKIIDO.氏名漢字
        KYU_SHIMEI_KANA           NVARCHAR2(100),  -- GABTJUKIIDO.旧氏名かな
        KYU_SHIMEI_KANJI          NVARCHAR2(100),  -- GABTJUKIIDO.旧氏名漢字
        SHORIBI_KEY               NUMBER(8),       -- GABTJUKIIDO.処理日キー
        SHORI_JIKAN_KEY           NUMBER(6),       -- GABTJUKIIDO.処理時間キー
        --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 START
--        SHORI_KBN_KEY             NUMBER(2),       -- GABTJUKIIDO.処理区分キー
        SHORI_KBN_KEY             NUMBER(3),       -- GABTJUKIIDO.処理区分キー
        --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 END
        ZENBU_ICHIBU_KEY          NUMBER(1),       -- GABTJUKIIDO.全部一部キー
        SHOKUINKOJIN_NO_KEY       CHAR(12),        -- GABTJUKIIDO.職員番号キー
        RIREKI_RENBAN             NUMBER(5),       -- GAAVRENKEIATENA.履歴連番
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--        HOGOSYA_KOJIN_NO          NUMBER(12),      -- GKBTGAKUREIBO.保護者個人番号
        HOGOSYA_KOJIN_NO          NUMBER(15),      -- GKBTGAKUREIBO.保護者個人番号
        SHORIBI                   NUMBER(8),       -- GKBTGAKUREIBO.処理日
        SYOGAKO_CD                NUMBER(3),       -- GKBTGAKUREIBO.小学校コード
        TYUGAKO_CD                NUMBER(3)        -- GKBTGAKUREIBO.中学校コード
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--        ,GAKUREIBO_KOJIN_NO        NUMBER(12)       -- GKBTGAKUREIBO.宛名番号
        ,GAKUREIBO_KOJIN_NO        NUMBER(15)       -- GKBTGAKUREIBO.宛名番号
        ,GAKUREIBO_ZOKUGARA1                NUMBER(2)       -- GKBTGAKUREIBO.続柄１
        ,GAKUREIBO_ZOKUGARA2                NUMBER(2)       -- GKBTGAKUREIBO.続柄２
        ,GAKUREIBO_ZOKUGARA3                NUMBER(2)       -- GKBTGAKUREIBO.続柄３
        ,GAKUREIBO_ZOKUGARA4                NUMBER(2)       -- GKBTGAKUREIBO.続柄４
        ,GAKUREIBO_HOGOSYA_ZOKUGARA1        NUMBER(2)       -- GKBTGAKUREIBO.保護者続柄１
        ,GAKUREIBO_HOGOSYA_ZOKUGARA2        NUMBER(2)       -- GKBTGAKUREIBO.保護者続柄２
        ,GAKUREIBO_HOGOSYA_ZOKUGARA3        NUMBER(2)       -- GKBTGAKUREIBO.保護者続柄３
        ,GAKUREIBO_HOGOSYA_ZOKUGARA4        NUMBER(2)       -- GKBTGAKUREIBO.保護者続柄４
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        ,JUKIATENA_SHOGAKKOKU_CD            NVARCHAR2(5)  -- 住記・宛名_小学校区コード
        ,JUKIATENA_CHUGAKKOKU_CD            NVARCHAR2(5)  -- 住記・宛名_中学校区コード
        ,JUKIATENA_SHITEI_SHOGAKKO_CD        NUMBER(3)     -- 住記・宛名_就学指定校_小学校
        ,JUKIATENA_SHITEI_CHUGAKKO_CD        NUMBER(3)     -- 住記・宛名_就学指定校_中学校
        ,GAKUREIBO_GAKKO_KBN                NUMBER(1)     -- 学齢簿_学校区分
        ,GAKUREIBO_SHOGAKKOKU_CD            NVARCHAR2(5)  -- 学齢簿_小学校区コード
        ,GAKUREIBO_CHUGAKKOKU_CD            NVARCHAR2(5)  -- 学齢簿_中学校区コード
        ,GAKUREIBO_SHITEI_SHOGAKKO_CD        NUMBER(3)     -- 学齢簿_就学指定校_小学校
        ,GAKUREIBO_SHITEI_CHUGAKKO_CD        NUMBER(3)     -- 学齢簿_就学指定校_中学校
--  2024/07/01 ZCZL.YANGXINYU ADD END
    );
    JUKIIDO_REC  CRJUKIIDO;

    -- 学齢簿現最新履歴データ格納用
    RGAKUREIBO   GKBTGAKUREIBO%ROWTYPE;
--  2024/07/01 ZCZL.YANGXINYU DELETE 0.3.000.000:新WizLIFE２次開発
--    RNINIBIT     GKBTNINIBIT%ROWTYPE;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
    g_rSHUGAKURIREKI GKBTSHUGAKURIREKI%ROWTYPE;            -- 就学履歴現最新履歴データ格納用
    g_nGAKUREIBO_RIREKI_RENBAN        NUMBER(3);           -- 学齢簿最新履歴連番
    g_nSHUGAKURIREKI_RIREKI_RENBAN    NUMBER(3);           -- 就学履歴最新履歴連番
    g_nGAKUNENRIREKI_RIREKI_RENBAN    NUMBER(3);           -- 学年履歴最新履歴連番
--  2024/07/01 ZCZL.YANGXINYU ADD END



    -- データインサート用
    TYPE MTWORK_REC IS RECORD
    (
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--        KOJIN_NO                  NUMBER(12),      -- 学齢簿宛名番号
        KOJIN_NO                  NUMBER(15),      -- 学齢簿宛名番号
        GENZON_KBN                NUMBER(1),       -- 現存区分
        RIREKI_RENBAN             NUMBER(5),       -- 履歴連番
        IDO_KBN                   NUMBER(1),       -- 異動区分
        IDO_SHUBETSU              NUMBER(1)        -- 異動種別
    );
    TYPE MTWORK_TYPE IS TABLE OF MTWORK_REC INDEX BY BINARY_INTEGER;
    MWORK MTWORK_TYPE;

    -- CSVファイル出力用
    TYPE MTCSV_REC IS RECORD
    (
        KAIPEJI_CD                NVARCHAR2(500),  -- 改ページコード
        KAIPEJI                   NVARCHAR2(500),  -- 改ページ
        RENBAN                    NUMBER(5),       -- 連番
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--        JIDO_KOJIN_NO             NUMBER(12),       -- GKBWJUKIRENKEI.児童宛名番号
        JIDO_KOJIN_NO             NUMBER(15),       -- GKBWJUKIRENKEI.児童宛名番号
        JIDO_SHIMEI_KANA          NVARCHAR2(100),  -- GKBWJUKIRENKEI.児童氏名かな
        JIDO_SHIMEI_KANJI         NVARCHAR2(100),  -- GKBWJUKIRENKEI.児童氏名漢字
        HYOJI_SEINENGAPI          NVARCHAR2(11),   -- GKBWJUKIRENKEI.表示用生年月日
        HYOJI_SEIBETSU            NVARCHAR2(2),    -- GKBWJUKIRENKEI.表示用性別
        ZOKUGARAMEI1              NVARCHAR2(30),   -- GKBWJUKIRENKEI.保護者との関係
        GAKOKU_CD                 NUMBER(3),       -- GKBWJUKIRENKEI.学校区コード
        GAKOKUMEI                 NVARCHAR2(60),   -- GKBWJUKIRENKEI.学校区名
        GAKUNEN_CD                NUMBER(2),       -- GKBWJUKIRENKEI.学年コード
        GAKUNENMEI                NVARCHAR2(20),   -- GKBWJUKIRENKEI.学年名
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--        SETAI_NO                  NUMBER(7),       -- GKBWJUKIRENKEI.世帯番号
--        HOGOSHA_KOJIN_NO          NUMBER(12),      -- GKBWJUKIRENKEI.保護者個人番号
        SETAI_NO                  NUMBER(15),       -- GKBWJUKIRENKEI.世帯番号
        HOGOSHA_KOJIN_NO          NUMBER(15),      -- GKBWJUKIRENKEI.保護者個人番号
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
        HOGOSHA_SHIMEI_KANJI      NVARCHAR2(100),  -- GKBWJUKIRENKEI.保護者旧氏名漢字
        HYOJI_IDO_BI              NVARCHAR2(11),   -- GKBWJUKIRENKEI.表示用異動日
        HYOJI_IDO_TODOKE_BI       NVARCHAR2(11),   -- GKBWJUKIRENKEI.表示用異動届出日
        HYOJI_IDO_JIYU            NVARCHAR2(30),   -- GKBWJUKIRENKEI.表示用異動事由
        SIN_JUSHO                 NVARCHAR2(420),  -- GKBWJUKIRENKEI.新住所
        ZEN_JUSHO                 NVARCHAR2(420),  -- GKBWJUKIRENKEI.前住所
        GYOSEIKUMEI               NVARCHAR2(20),   -- GKBWJUKIRENKEI.行政区名
        GAIKOKUJIN_KBN            NVARCHAR2(1),    -- GKBWJUKIRENKEI.外国人区分
        BIKO                      NVARCHAR2(500)   -- GKBWJUKIRENKEI.備考
        ,ZOKUGARAMEI2             NVARCHAR2(30)    --GKBWJUKIRENKEI.児童との関係
    );
    TYPE MTCSV_TYPE IS TABLE OF MTCSV_REC INDEX BY BINARY_INTEGER;
    MCSV MTCSV_TYPE;

    I_SYSTEMJOKEN        PLS_INTEGER;        -- システム条件取得用
    I_SYSTEM_HAU         PLS_INTEGER;        -- 変数.新入学児童削除方法
    NH_ZOKUGARACD1       NUMBER(2);          -- 保護者.続柄1
    NH_ZOKUGARACD2       NUMBER(2);          -- 保護者.続柄2
    NH_ZOKUGARACD3       NUMBER(2);          -- 保護者.続柄3
    NH_ZOKUGARACD4       NUMBER(2);          -- 保護者.続柄4
    NJ_ZOKUGARACD1       NUMBER(2);          -- 児童.続柄1
    NJ_ZOKUGARACD2       NUMBER(2);          -- 児童.続柄2
    NJ_ZOKUGARACD3       NUMBER(2);          -- 児童.続柄3
    NJ_ZOKUGARACD4       NUMBER(2);          -- 児童.続柄4

    VMSG NVARCHAR2(4000);
    BCHKARI BOOLEAN;
    IRTN PLS_INTEGER ;
    ICHK1 PLS_INTEGER ;
    ICHK2 PLS_INTEGER ;
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
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
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
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
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
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        cmbHogoshaHanteiKbn    DBMS_UTILITY.MAXNAME_ARRAY;
        cmbGakureiBoKoshinKbn  DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        g_vJOKEN1 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtJuKiIdoKoshinBiStart');                 --抽出開始住記異動更新日 期間(開始)
        g_vJOKEN2 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtJuKiIdoKoshinBiEnd');                   --抽出終了住記異動更新日 期間(終了)
        cmbHogoshaHanteiKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbHogoshaHanteiKbn');
        g_vJOKEN3 := cmbHogoshaHanteiKbn(1);                                                  --保護者判定区分
        cmbGakureiBoKoshinKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbGakureiBoKoshinKbn');
        g_vJOKEN4 := cmbGakureiBoKoshinKbn(1);                                                --学齢簿更新区分
        g_vJOKEN5 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKaipageSortKbn');                       --改頁・ソート区分
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
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
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
    --  パラメータ    : i_VHIZUKE
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    BRET BOOLEAN ;
    TEMP_DATE DATE;
    BEGIN
      IRET := 0 ;
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

      IF IRET = 0 THEN
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

      RETURN(IRET) ;
    END ;
    --------------------------------------------------------
    --  機能概要      : 日付の大小チェック
    --  パラメータ    : i_VHIDUKE1
    --               i_VHIDUKE2
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNCHIKAKUCHK( i_VHIDUKE1 IN NVARCHAR2, i_VHIDUKE2 IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
      HIDUKE1 NUMBER ;
      HIDUKE2 NUMBER ;

    BEGIN
      IRET := 0 ;
      BEGIN
       HIDUKE1  := TO_NUMBER( i_VHIDUKE1 );
       HIDUKE2  := TO_NUMBER( i_VHIDUKE2 );
      --大小チェック
      IF i_VHIDUKE1 > i_VHIDUKE2 THEN
        IRET := 1;
      END IF;

      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      RETURN(IRET) ;
    END ;
    --------------------------------------------------------
    --  機能概要      : 保護者判定区分チェック
    --  パラメータ    : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNCHOGOSHAKUBUN( i_IRENBAN IN NVARCHAR2 ) RETURN NUMBER IS
      IRET PLS_INTEGER ;
      IRENBAN NUMBER ;
    BEGIN
      IRET := 0 ;

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

      RETURN(IRET) ;
    END ;
    --------------------------------------------------------
    --  機能概要      : 更新区分チェック
    --  パラメータ    : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNCKOSHINKUBUN( i_IRENBAN IN NVARCHAR2 ) RETURN NUMBER IS
      IRET PLS_INTEGER ;
      IRENBAN NUMBER ;
    BEGIN
      IRET := 0 ;

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

      RETURN(IRET) ;
    END ;
    --------------------------------------------------------
    --  機能概要      : 改頁・ソート区分チェック
    --  パラメータ    : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNCKAISORTKUBUN( i_IRENBAN IN NVARCHAR2 ) RETURN NUMBER IS
      IRET PLS_INTEGER ;
      IRENBAN NUMBER ;
    BEGIN
      IRET := 0 ;

      BEGIN

       IF  i_IRENBAN IS NULL THEN
                 IRET := 1;
       ELSE
          IRENBAN := TO_NUMBER(i_IRENBAN);
              IF NOT IRENBAN IN (0,1,2,3) THEN
                 IRET := 1;
              END IF;
       END IF;
     EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      RETURN(IRET) ;
    END ;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
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
        VMSG  := '' ;
        BCHKARI:=FALSE;
        IRTN  := 0 ;
        ICHK1 := 0 ;
        ICHK2 := 0 ;

        --条件１のチェック
        IRTN := FUNCHIZUKECHK( g_vJOKEN1 ) ;
        IF IRTN <> 0 THEN
           ICHK1 := 1 ;
            VMSG := VMSG || 'GKB,99999,更新日（自）が正しくありません。,' ;
            BCHKARI:=TRUE;
        END IF ;
        --条件２のチェック
        IRTN := FUNCHIZUKECHK( g_vJOKEN2 ) ;
        IF IRTN <> 0 THEN
          IF BCHKARI THEN
            VMSG := VMSG || ';' ;
          END IF;
           ICHK2 := 1 ;
            VMSG := VMSG || 'GKB,99999,更新日（至）が正しくありません。,' ;
          BCHKARI:=TRUE;
        END IF ;
       --条件１と条件２の大小チェック
        IF ICHK1 = 0 AND ICHK2 = 0 THEN
          IRTN := FUNCHIKAKUCHK( g_vJOKEN1, g_vJOKEN2 ) ;
          IF BCHKARI THEN
            VMSG := VMSG || ';' ;
          END IF;
          IF IRTN <> 0 THEN
            VMSG := VMSG || 'GKB,99999,更新日（自）と更新日（至）の大小関係が誤っています。,' ;
          END IF ;
          BCHKARI:=TRUE;
        END IF ;
       --保護者判定区分チェック
        IRTN := FUNCHOGOSHAKUBUN( g_vJOKEN3 ) ;
        IF IRTN <> 0 THEN
          IF BCHKARI THEN
            VMSG := VMSG || ';' ;
          END IF;
            VMSG := VMSG || 'GKB,99999,保護者判定区分が正しくありません。,' ;
            BCHKARI:=TRUE;
         END IF;
       --更新区分チェック
        IRTN := FUNCKOSHINKUBUN( g_vJOKEN4 ) ;
        IF IRTN <> 0 THEN
          IF BCHKARI THEN
            VMSG := VMSG || ';' ;
          END IF;
            VMSG := VMSG || 'GKB,99999,更新区分が正しくありません。,' ;
            BCHKARI:=TRUE;
         END IF;
       --改頁・ソート区分チェック
        IRTN := FUNCKAISORTKUBUN( g_vJOKEN5 ) ;
        IF IRTN <> 0 THEN
          IF BCHKARI THEN
            VMSG := VMSG || ';' ;
          END IF;
            VMSG := VMSG || 'GKB,99999,改頁・ソート区分が正しくありません。,' ;
            BCHKARI:=TRUE;
         END IF;
        IF VMSG IS NOT NULL THEN
          o_vRESULT := VMSG || ';' ;
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
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
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
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
    
    --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 START
        ---------------------------------------------------------------
    --  機能概要      : 件数表の作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: JPJYS 2024/01/02
    ---------------------------------------------------------------
      FUNCTION FUNC_KENSUUTEPURU_MAKE RETURN BOOLEAN
      IS 
        BRTN        BOOLEAN;
        IMAX        PLS_INTEGER;
        IMIN        PLS_INTEGER;
        NCOUNT      PLS_INTEGER;
      BEGIN                              
        --  入力件数の作成
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NCINT,'入力　住記異動情報連携処理入力件数',1);
        -- 出力件数の作成
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(SCINT,'出力　住記異動情報連携処理出力件数',2);

        RETURN TRUE;
      EXCEPTION
        WHEN OTHERS THEN
          VLOG := '件数表の作成が異常終了しました。';
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_KENSUUTEPURU_MAKE', 1,SQLCODE, SQLERRM, VLOG, g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
      END FUNC_KENSUUTEPURU_MAKE;

--  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 END
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
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
    --  機能概要      : 学齢簿/就学履歴現最新履歴データ格納用のレコード初期化
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    PROCEDURE PROC_RGAKUREIBO_SHOKIKA IS
    BEGIN
        RGAKUREIBO.KOJIN_NO                     := 0;
        RGAKUREIBO.RIREKI_RENBAN                := 0;
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO.RIREKI_RENBAN_EDA            := 0;
        RGAKUREIBO.GENZON_KBN                   := 0;
        RGAKUREIBO.SAISHIN_KBN                  := 0;
        RGAKUREIBO.ZO_JIYU_CD                   := 0;
        RGAKUREIBO.ZO_NENGAPI                   := 0;
        RGAKUREIBO.GEN_JIYU_CD                  := 0;
        RGAKUREIBO.GEN_NENGAPI                  := 0;
        RGAKUREIBO.ZOKUGARA1                    := 0;
        RGAKUREIBO.ZOKUGARA2                    := 0;
        RGAKUREIBO.ZOKUGARA3                    := 0;
        RGAKUREIBO.ZOKUGARA4                    := 0;
        RGAKUREIBO.HOGOSYA_KOJIN_NO             := 0;
        RGAKUREIBO.HOGOSYA_ZOKUGARA1            := 0;
        RGAKUREIBO.HOGOSYA_ZOKUGARA2            := 0;
        RGAKUREIBO.HOGOSYA_ZOKUGARA3            := 0;
        RGAKUREIBO.HOGOSYA_ZOKUGARA4            := 0;
        RGAKUREIBO.SYOGAKO_CD                   := 0;
        RGAKUREIBO.SYOGAKO_NYUGAKU_BI           := 0;
        RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI        := 0;
        RGAKUREIBO.SYOGAKO_TENGAKU_BI           := 0;
        RGAKUREIBO.SYOGAKO_SOTSUGYO_BI          := 0;
        RGAKUREIBO.TYUGAKO_CD                   := 0;
        RGAKUREIBO.TYUGAKO_NYUGAKU_BI           := 0;
        RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI        := 0;
        RGAKUREIBO.TYUGAKO_TENGAKU_BI           := 0;
        RGAKUREIBO.TYUGAKO_SOTSUGYO_BI          := 0;
        RGAKUREIBO.TOKUSOKU_BI1                 := 0;
        RGAKUREIBO.TOKUSOKU_BI2                 := 0;
        RGAKUREIBO.TOKUSOKU_NAIYO1              := NULL;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO.TOKUSOKU_JIYU1               := 0;
        RGAKUREIBO.TOKUSOKU_JURI_BI1            := 0;
--  2024/07/01 ZCZL.YANGXINYU ADD END
        RGAKUREIBO.TOKUSOKU_NAIYO2              := NULL;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO.TOKUSOKU_JIYU2               := 0;
        RGAKUREIBO.TOKUSOKU_JURI_BI2            := 0;
--  2024/07/01 ZCZL.YANGXINYU ADD END
        RGAKUREIBO.TOKUSOKU_BI3                 := 0;
        RGAKUREIBO.TOKUSOKU_NAIYO3              := NULL;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO.TOKUSOKU_JIYU3               := 0;
        RGAKUREIBO.TOKUSOKU_JURI_BI3            := 0;
--  2024/07/01 ZCZL.YANGXINYU ADD END
        RGAKUREIBO.TOKUSOKU_BI4                 := 0;
        RGAKUREIBO.TOKUSOKU_NAIYO4              := NULL;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO.TOKUSOKU_JIYU4               := 0;
        RGAKUREIBO.TOKUSOKU_JURI_BI4            := 0;
--  2024/07/01 ZCZL.YANGXINYU ADD END
        RGAKUREIBO.TOKUSOKU_BI5                 := 0;
        RGAKUREIBO.TOKUSOKU_NAIYO5              := NULL;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO. TOKUSOKU_JIYU5              := 0;
        RGAKUREIBO. TOKUSOKU_JURI_BI5           := 0;
        RGAKUREIBO. TOKUSOKU_BI6                := 0;
        RGAKUREIBO. TOKUSOKU_NAIYO6             := NULL;
        RGAKUREIBO. TOKUSOKU_JIYU6              := 0;
        RGAKUREIBO. TOKUSOKU_JURI_BI6           := 0;
        RGAKUREIBO. TOKUSOKU_BI7                := 0;
        RGAKUREIBO. TOKUSOKU_NAIYO7             := NULL;
        RGAKUREIBO. TOKUSOKU_JIYU7              := 0;
        RGAKUREIBO. TOKUSOKU_JURI_BI7           := 0;
        RGAKUREIBO. TOKUSOKU_BI8                := 0;
        RGAKUREIBO. TOKUSOKU_NAIYO8             := NULL;
        RGAKUREIBO. TOKUSOKU_JIYU8              := 0;
        RGAKUREIBO. TOKUSOKU_JURI_BI8           := 0;
        RGAKUREIBO. TOKUSOKU_BI9                := 0;
        RGAKUREIBO. TOKUSOKU_NAIYO9             := NULL;
        RGAKUREIBO. TOKUSOKU_JIYU9              := 0;
        RGAKUREIBO. TOKUSOKU_JURI_BI9           := 0;
        RGAKUREIBO. TOKUSOKU_BI10               := 0;
        RGAKUREIBO. TOKUSOKU_NAIYO10            := NULL;
        RGAKUREIBO. TOKUSOKU_JIYU10             := 0;
        RGAKUREIBO. TOKUSOKU_JURI_BI10          := 0;
--  2024/07/01 ZCZL.YANGXINYU ADD END
        RGAKUREIBO.KUIKIGAI_CD                  := 0;
        RGAKUREIBO.KUIKIGAI_SETISYA             := NULL;
        RGAKUREIBO.KUIKIGAI_NYUGAKU_BI          := 0;
        RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI       := 0;
        RGAKUREIBO.KUIKIGAI_TENGAKU_BI          := 0;
        RGAKUREIBO.KUIKIGAI_TAIGAKU_BI          := 0;
        RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI         := 0;
        RGAKUREIBO.YOGOGAKO_CD                  := 0;
        RGAKUREIBO.YOGOGAKO_SETISYA             := NULL;
        RGAKUREIBO.YOGOGAKO_NYUGAKU_BI          := 0;
        RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI       := 0;
        RGAKUREIBO.YOGOGAKO_TENGAKU_BI          := 0;
        RGAKUREIBO.YOGOGAKO_TAIGAKU_BI          := 0;
        RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI         := 0;
        RGAKUREIBO.YUYO_KYOKA_BI                := 0;
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO.YUYO_JIYU_CD                 := 0;
        RGAKUREIBO.YUYO_JIYU                    := NULL;
        RGAKUREIBO.YUYO_KAISI_BI                := 0;
        RGAKUREIBO.YUYO_SYURYO_BI               := 0;
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO.YUYO_NENSU                   := 0;
        RGAKUREIBO.YUYO_FUKUGAKU_BI             := 0;
        RGAKUREIBO.MENJO_KYOKA_BI               := 0;
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO.MENJO_JIYU_CD                := 0;
        RGAKUREIBO.MENJO_JIYU                   := NULL;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO.MENJO_KAISI_BI       := 0;
        RGAKUREIBO.MENJO_SYURYO_BI        := 0;
        RGAKUREIBO.MENJO_NENSU          := 0;
--  2024/07/01 ZCZL.YANGXINYU END
        RGAKUREIBO.MENJO_FUKUGAKU_BI            := 0;
        RGAKUREIBO.IDO_BI1                      := 0;
        RGAKUREIBO.IDO_JIYU1                    := NULL;
        RGAKUREIBO.IDO_BI2                      := 0;
        RGAKUREIBO.IDO_JIYU2                    := NULL;
        RGAKUREIBO.IDO_BI3                      := 0;
        RGAKUREIBO.IDO_JIYU3                    := NULL;
        RGAKUREIBO.IDO_BI4                      := 0;
        RGAKUREIBO.IDO_JIYU4                    := NULL;
        RGAKUREIBO.IDO_BI5                      := 0;
        RGAKUREIBO.IDO_JIYU5                    := NULL;
        RGAKUREIBO.IDO_BI6                      := 0;
        RGAKUREIBO.IDO_JIYU6                    := NULL;
        RGAKUREIBO.IDO_BI7                      := 0;
        RGAKUREIBO.IDO_JIYU7                    := NULL;
        RGAKUREIBO.IDO_BI8                      := 0;
        RGAKUREIBO.IDO_JIYU8                    := NULL;
        RGAKUREIBO.IDO_BI9                      := 0;
        RGAKUREIBO.IDO_JIYU9                    := NULL;
        RGAKUREIBO.IDO_BI10                     := 0;
        RGAKUREIBO.IDO_JIYU10                   := NULL;
        RGAKUREIBO.SYS_SAKUSEIBI                := 0;
        RGAKUREIBO.SYS_KOSHINBI                 := 0;
        RGAKUREIBO.SYS_JIKAN                    := 0;
        RGAKUREIBO.SYS_SHOKUINKOJIN_NO          := 0;
        RGAKUREIBO.SYS_TANMATU_NO               := NULL;
        RGAKUREIBO.GAKUNEN                      := 0;
        RGAKUREIBO.SHORIBI                      := 0;
        RGAKUREIBO.SHUGAKU                      := NULL;
        RGAKUREIBO.IDOJIKO                      := NULL;
        RGAKUREIBO.CHOHYO_NO                    := 0;
        RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN   := 0;
        RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN      := 0;
        RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN   := 0;
        RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN      := 0;
        RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN  := 0;
        RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN     := 0;
        RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN     := 0;
        RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN  := 0;
        RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN     := 0;
        RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN     := 0;
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
        RGAKUREIBO.GAKKO_KBN_CD                 := 0;
        RGAKUREIBO.GAKUKYU_CD                   := 0;
        RGAKUREIBO.SEIBETSU                     := 0;
        RGAKUREIBO.JOTAI                        := 0;
        RGAKUREIBO.TENNYUMAE_GAKKO_KBN          := 0;
        RGAKUREIBO.TENNYUMAE_GAKKO_CD           := 0;
        RGAKUREIBO.TENNYUMAE_GAKUNEN            := 0;
        RGAKUREIBO.GENKYURYUCHI_FLG             := 0;
        RGAKUREIBO.GENKYURYUCHI_KETTEI_BI       := 0;
        RGAKUREIBO.GENKYURYUCHI_KAISI_BI        := 0;
        RGAKUREIBO.GENKYURYUCHI_SYURYOBI        := 0;
        RGAKUREIBO.GENKYURYUCHI_RIYU            := 0;
        RGAKUREIBO.SHITEI_SYOGAKO_CD            := 0;
        RGAKUREIBO.SHITEI_TYUGAKO_CD            := 0;
        RGAKUREIBO.HENKO_GAKUNEN_SYOGAKO        := 0;
        RGAKUREIBO.HENKO_GAKUNEN_TYUGAKO        := 0;
        RGAKUREIBO.HENKO_SHINSEI_BI             := 0;
        RGAKUREIBO.HENKO_KYOKA_BI               := 0;
        RGAKUREIBO.HENKO_KBN                    := 0;
        RGAKUREIBO.HENKO_KAISI_BI               := 0;
        RGAKUREIBO.HENKO_SYURYO_BI              := 0;
        RGAKUREIBO.HENKO_KYOKA_RIYU             := 0;
        RGAKUREIBO.HENKO_JIYU                   := 0;
        RGAKUREIBO.HENKO_HUKYOKA_RIYU           := NULL;
        RGAKUREIBO.KIBO_GAKKO_KBN_CD            := 0;
        RGAKUREIBO.KIBO_SYOGAKKO_CD             := 0;
        RGAKUREIBO.KIBO_TYUGAKKO_CD             := 0;
        RGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO     := 0;
        RGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO     := 0;
        RGAKUREIBO.KUIKIGAISHUGAKU_FLG          := 0;
        RGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI   := 0;
        RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI     := 0;
        RGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI     := 0;
        RGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI    := 0;
        RGAKUREIBO.KUIKIGAISHUGAKU_JIYU         := 0;
        RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU   := 0;
        RGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU := NULL;
        RGAKUREIBO.HUSHUGAKU_KAISI_BI           := 0;
        RGAKUREIBO.HUSHUGAKU_SYURYO_BI          := 0;
        RGAKUREIBO.HUSHUGAKU_RIYU               := 0;
        RGAKUREIBO.KUNISHIRITSU_CD              := 0;
        RGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI      := 0;
        RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI   := 0;
        RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN  := 0;
        RGAKUREIBO.KUNISHIRITSU_TENGAKU_BI      := 0;
        RGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN := 0;
        RGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI      := 0;
        RGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN := 0;
        RGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI     := 0;
        RGAKUREIBO.KUNISHIRITSU_KAISI_BI        := 0;
        RGAKUREIBO.KUNISHIRITSU_SYURYO_BI       := 0;
        RGAKUREIBO.TSUSHOMEI_KANA               := NULL;
        RGAKUREIBO.TSUSHOMEI_KANJI              := NULL;
        RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA       := NULL;
        RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI      := NULL;
        RGAKUREIBO.GRB_HENKO_TODOKEDE_BI        := 0;
        RGAKUREIBO.GRB_HENKO_BI                 := 0;
        RGAKUREIBO.GRB_HENKO_JIYU               := 0;
        RGAKUREIBO.BIKO                         := NULL;
        RGAKUREIBO.IDO_BI                       := 0;
        RGAKUREIBO.TODOKEDE_BI                  := 0;
        RGAKUREIBO.SHINSEI_KANRI_RENBAN         := 0;
        RGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN    := 0;
        RGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN  := 0;
        RGAKUREIBO.SHOGAKKOKU_CD                := NULL;
        RGAKUREIBO.CHUGAKKOKU_CD                := NULL;
        RGAKUREIBO.SAKUJO_FLG                   := 0;
        RGAKUREIBO.SYS_TANMATU_BASHO            := NULL;

--        RNINIBIT.KOJIN_NO                       := 0;
--        RNINIBIT.RIREKI_RENBAN                  := 0;
--        RNINIBIT.NINIBIT1                       := 0;
--        RNINIBIT.NINIBIT2                       := 0;
--        RNINIBIT.NINIBIT3                       := 0;
--        RNINIBIT.NINIBIT4                       := 0;
--        RNINIBIT.NINIBIT5                       := 0;
--        RNINIBIT.NINIBIT6                       := 0;
--        RNINIBIT.NINIBIT7                       := 0;
--        RNINIBIT.NINIBIT8                       := 0;
--        RNINIBIT.NINIBIT9                       := 0;
--        RNINIBIT.NINIBIT10                      := 0;
--        RNINIBIT.NINIBIT11                      := 0;
--        RNINIBIT.NINIBIT12                      := 0;
--        RNINIBIT.NINIBIT13                      := 0;
--        RNINIBIT.NINIBIT14                      := 0;
--        RNINIBIT.NINIBIT15                      := 0;
--        RNINIBIT.NINIBIT16                      := 0;
--        RNINIBIT.NINIBIT17                      := 0;
--        RNINIBIT.NINIBIT18                      := 0;
--        RNINIBIT.NINIBIT19                      := 0;
--        RNINIBIT.NINIBIT20                      := 0;
--        RNINIBIT.SYS_SAKUSEIBI                  := 0;
--        RNINIBIT.SYS_KOSHINBI                   := 0;
--        RNINIBIT.SYS_JIKAN                      := 0;
--        RNINIBIT.SYS_SHOKUINKOJIN_NO            := 0;
--        RNINIBIT.SYS_TANMATU_NO                 := NULL;

        -- 就学履歴現最新履歴データ格納用 を下記の内容で初期化する。
        g_rSHUGAKURIREKI.KOJIN_NO                       := 0;
        g_rSHUGAKURIREKI.NENDO                          := 0;
        g_rSHUGAKURIREKI.KOJIN_RIREKI_RENBAN            := 0;
        g_rSHUGAKURIREKI.SHUGAKU_RIREKI_RENBAN          := 0;
        g_rSHUGAKURIREKI.SAISHIN_FLG                    := 0;
        g_rSHUGAKURIREKI.S_CD                           := 0;
        g_rSHUGAKURIREKI.S_NYUGAKU_BI                   := 0;
        g_rSHUGAKURIREKI.S_TENNYU_BI                    := 0;
        g_rSHUGAKURIREKI.S_TENNYU_GAKUNEN               := 0;
        g_rSHUGAKURIREKI.S_TENGAKU_BI                   := 0;
        g_rSHUGAKURIREKI.S_TENGAKU_GAKUNEN              := 0;
        g_rSHUGAKURIREKI.S_TAIGAKU_BI                   := 0;
        g_rSHUGAKURIREKI.S_TAIGAKU_GAKUNEN              := 0;
        g_rSHUGAKURIREKI.S_SOTSUGYO_BI                  := 0;
        g_rSHUGAKURIREKI.T_CD                           := 0;
        g_rSHUGAKURIREKI.T_NYUGAKU_BI                   := 0;
        g_rSHUGAKURIREKI.T_TENNYU_BI                    := 0;
        g_rSHUGAKURIREKI.T_TENNYU_GAKUNEN               := 0;
        g_rSHUGAKURIREKI.T_TENGAKU_BI                   := 0;
        g_rSHUGAKURIREKI.T_TENGAKU_GAKUNEN              := 0;
        g_rSHUGAKURIREKI.T_TAIGAKU_BI                   := 0;
        g_rSHUGAKURIREKI.T_TAIGAKU_GAKUNEN              := 0;
        g_rSHUGAKURIREKI.T_SOTSUGYO_BI                  := 0;
        g_rSHUGAKURIREKI.SHIEN_BU_CD                    := 0;
        g_rSHUGAKURIREKI.SHIEN_S_CD                     := 0;
        g_rSHUGAKURIREKI.SHIEN_S_HUKUSEKI_CD            := 0;
        g_rSHUGAKURIREKI.SHIEN_S_NYUGAKU_BI             := 0;
        g_rSHUGAKURIREKI.SHIEN_S_TENNYU_BI              := 0;
        g_rSHUGAKURIREKI.SHIEN_S_TENNYU_GAKUNEN         := 0;
        g_rSHUGAKURIREKI.SHIEN_S_TENGAKU_BI             := 0;
        g_rSHUGAKURIREKI.SHIEN_S_TENGAKU_GAKUNEN        := 0;
        g_rSHUGAKURIREKI.SHIEN_S_TAIGAKU_BI             := 0;
        g_rSHUGAKURIREKI.SHIEN_S_TAIGAKU_GAKUNEN        := 0;
        g_rSHUGAKURIREKI.SHIEN_S_SOTSUGYO_BI            := 0;
        g_rSHUGAKURIREKI.SHIEN_T_CD                     := 0;
        g_rSHUGAKURIREKI.SHIEN_T_HUKUSEKI_CD            := 0;
        g_rSHUGAKURIREKI.SHIEN_T_NYUGAKU_BI             := 0;
        g_rSHUGAKURIREKI.SHIEN_T_TENNYU_BI              := 0;
        g_rSHUGAKURIREKI.SHIEN_T_TENNYU_GAKUNEN         := 0;
        g_rSHUGAKURIREKI.SHIEN_T_TENGAKU_BI             := 0;
        g_rSHUGAKURIREKI.SHIEN_T_TENGAKU_GAKUNEN        := 0;
        g_rSHUGAKURIREKI.SHIEN_T_TAIGAKU_BI             := 0;
        g_rSHUGAKURIREKI.SHIEN_T_TAIGAKU_GAKUNEN        := 0;
        g_rSHUGAKURIREKI.SHIEN_T_SOTSUGYO_BI            := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_CD                  := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_KAISHI_GAKUNEN      := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_NYUGAKU_BI          := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_TENNYU_BI           := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_TENNYU_GAKUNEN      := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_TENGAKU_BI          := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_TENGAKU_GAKUNEN     := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_TAIGAKU_BI          := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_TAIGAKU_GAKUNEN     := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_SOTSUGYO_BI         := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_KAISHI_BI           := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_SHURYO_BI           := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_S_KAIJO_BI            := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_CD                  := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_KAISHI_GAKUNEN      := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_NYUGAKU_BI          := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_TENNYU_BI           := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_TENNYU_GAKUNEN      := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_TENGAKU_BI          := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_TENGAKU_GAKUNEN     := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_TAIGAKU_BI          := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_TAIGAKU_GAKUNEN     := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_SOTSUGYO_BI         := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_KAISHI_BI           := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_SHURYO_BI           := 0;
        g_rSHUGAKURIREKI.KUIKIGAI_T_KAIJO_BI            := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_CD              := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_NYUGAKU_BI      := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENNYU_BI       := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENNYU_GAKUNEN  := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENGAKU_BI      := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENGAKU_GAKUNEN := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_TAIGAKU_BI      := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_TAIGAKU_GAKUNEN := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_SOTSUGYO_BI     := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_KAISHI_BI       := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_S_SHURYO_BI       := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_CD              := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_NYUGAKU_BI      := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENNYU_BI       := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENNYU_GAKUNEN  := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENGAKU_BI      := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENGAKU_GAKUNEN := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_TAIGAKU_BI      := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_TAIGAKU_GAKUNEN := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_SOTSUGYO_BI     := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_KAISHI_BI       := 0;
        g_rSHUGAKURIREKI.KUNISHIRITSU_T_SHURYO_BI       := 0;
        g_rSHUGAKURIREKI.SAKUJO_FLG                     := 0;
        g_rSHUGAKURIREKI.SYS_SAKUSEIBI                  := 0;
        g_rSHUGAKURIREKI.SYS_KOSHINBI                   := 0;
        g_rSHUGAKURIREKI.SYS_JIKAN                      := 0;
        g_rSHUGAKURIREKI.SYS_SHOKUINKOJIN_NO            :=NULL;
        g_rSHUGAKURIREKI.SYS_TANMATU_NO                 :=NULL;
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
    END PROC_RGAKUREIBO_SHOKIKA;
    --------------------------------------------------------
    --  機能概要      : システム条件取得
    --  パラメータ    : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : I_VALUE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_GET_SYSJOKEN(i_IRENBAN IN PLS_INTEGER) RETURN PLS_INTEGER IS
        I_VALUE    PLS_INTEGER;    -- システム条件設定値
        TACONSPRM  A_CONS_PRM;       --戻るパラメータ配列
        NLENGTH    NUMBER;           --配列件数
    BEGIN
        IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      i_IRENBAN,         --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
        IF NLENGTH <> 0 THEN
        --レコードが取得できた場合
          I_VALUE := TACONSPRM(1);
        ELSE
        --レコードが取得できない場合
          I_VALUE := 0;
        END IF;
        RETURN I_VALUE;
    END FUNC_GET_SYSJOKEN;
    --------------------------------------------------------
    --  機能概要      : 住記連携ワークレコードの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_GET_JRENKEI_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;
        ------------------------------------------------------------------------------
        --  カーソル定義
        ------------------------------------------------------------------------------
        TYPE TYPECURSOR  IS REF CURSOR;
        CJUKIIDO            TYPECURSOR;
    BEGIN
        IFRET := C_INOTFOUND;  -- 該当なし

        -- ワーク領域の初期化
        MJRENKEI_WORK.DELETE;
        MWORK.DELETE;
        ICNT := 0;

        BEGIN
            -- ２．データ抽出処理
            -- ２－１
            VSQLSEL := '';
            --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 START
            VSQLSEL := VSQLSEL || 'WITH GAKUREIBO_MAX AS ( ';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'KOJIN_NO, ';
            VSQLSEL := VSQLSEL || 'MAX(RIREKI_RENBAN) AS RIREKI_RENBAN ';
            VSQLSEL := VSQLSEL || 'FROM GKBTGAKUREIBO ';
            VSQLSEL := VSQLSEL || 'WHERE SAKUJO_FLG = 0 ';
            VSQLSEL := VSQLSEL || 'GROUP BY KOJIN_NO ';
            VSQLSEL := VSQLSEL || '), ';
            VSQLSEL := VSQLSEL || 'GAK AS ( ';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'GAK1.* ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBTGAKUREIBO GAK1 ';
            VSQLSEL := VSQLSEL || 'INNER JOIN GAKUREIBO_MAX GAK2 ';
            VSQLSEL := VSQLSEL || 'ON GAK1.KOJIN_NO = GAK2.KOJIN_NO ';
            VSQLSEL := VSQLSEL || 'AND GAK1.RIREKI_RENBAN = GAK2.RIREKI_RENBAN ';
            VSQLSEL := VSQLSEL || ') ';
            
            VSQLSEL := VSQLSEL || 'SELECT REN.KOJIN_NO, ';
            VSQLSEL := VSQLSEL ||        'REN.SETAI_NO, ';
            VSQLSEL := VSQLSEL ||        'REN.GENZON_KBN, ';
            VSQLSEL := VSQLSEL ||        'REN.JINKAKU_KBN, ';
            VSQLSEL := VSQLSEL ||        'REN.GYOSEIKU_CD, ';
            VSQLSEL := VSQLSEL ||        'REN.HAN_CD, ';
            VSQLSEL := VSQLSEL ||        'REN.SHOGAKU_CD, ';
            VSQLSEL := VSQLSEL ||        'REN.CHUGAKU_CD, ';
            VSQLSEL := VSQLSEL ||        'REN.SANTEIDANTAI_CD, ';
            VSQLSEL := VSQLSEL ||        'REN.SEINENGAPI, ';
            VSQLSEL := VSQLSEL ||        'REN.SEIBETSU, ';
            VSQLSEL := VSQLSEL ||        'REN.KISAI_JUNI, ';
            VSQLSEL := VSQLSEL ||        'REN.IDO_BI, ';
            VSQLSEL := VSQLSEL ||        'REN.IDO_JIYU, ';
            VSQLSEL := VSQLSEL ||        'REN.IDO_TODOKE_BI, ';
            VSQLSEL := VSQLSEL ||        'REN.GENJUSHO_REN, ';
            VSQLSEL := VSQLSEL ||        'REN.ZENJUSHO_REN, ';
            VSQLSEL := VSQLSEL ||        'REN.TENNYUMAE_REN, ';
            VSQLSEL := VSQLSEL ||        'REN.TENSHUTSU_YOTEI_REN, ';
            VSQLSEL := VSQLSEL ||        'REN.TENSHUTSU_KAKUTEI_REN, ';
            VSQLSEL := VSQLSEL ||        'REN.SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL ||        'REN.SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL ||        'REN.KYU_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL ||        'REN.KYU_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL ||        'REN.SHORIBI_KEY, ';
            VSQLSEL := VSQLSEL ||        'REN.SHORI_JIKAN_KEY, ';
            VSQLSEL := VSQLSEL ||        'REN.SHORI_KBN_KEY, ';
            VSQLSEL := VSQLSEL ||        'REN.ZENBU_ICHIBU_KEY, ';
            VSQLSEL := VSQLSEL ||        'REN.SHOKUINKOJIN_NO_KEY, ';
            VSQLSEL := VSQLSEL ||        'REN.RIREKI_RENBAN, ';
            VSQLSEL := VSQLSEL ||        'NVL(GAK.HOGOSYA_KOJIN_NO, 0) AS HOGOSYA_KOJIN_NO, ';
            VSQLSEL := VSQLSEL ||        'NVL(GAK.SHORIBI,0) AS SHORIBI, ';
            VSQLSEL := VSQLSEL ||        'NVL(GAK.SYOGAKO_CD,0) AS SYOGAKO_CD, ';
            VSQLSEL := VSQLSEL ||        'NVL(GAK.TYUGAKO_CD,0) AS TYUGAKO_CD, ';
            -- 学齢簿宛名番号の追加
            VSQLSEL := VSQLSEL ||        '  NVL(GAK.KOJIN_NO,0) AS GAKUREIBO_KOJIN_NO ';
            VSQLSEL := VSQLSEL ||        ', NVL(GAK.ZOKUGARA1,0) AS GAKUREIBO_ZOKUGARA1 ';
            VSQLSEL := VSQLSEL ||        ', NVL(GAK.ZOKUGARA2,0) AS GAKUREIBO_ZOKUGARA2 ';
            VSQLSEL := VSQLSEL ||        ', NVL(GAK.ZOKUGARA3,0) AS GAKUREIBO_ZOKUGARA3 ';
            VSQLSEL := VSQLSEL ||        ', NVL(GAK.ZOKUGARA4,0) AS GAKUREIBO_ZOKUGARA4 ';
            VSQLSEL := VSQLSEL ||        ', NVL(GAK.HOGOSYA_ZOKUGARA1,0) AS GAKUREIBO_HOGOSYA_ZOKUGARA1 ';
            VSQLSEL := VSQLSEL ||        ', NVL(GAK.HOGOSYA_ZOKUGARA2,0) AS GAKUREIBO_HOGOSYA_ZOKUGARA2 ';
            VSQLSEL := VSQLSEL ||        ', NVL(GAK.HOGOSYA_ZOKUGARA3,0) AS GAKUREIBO_HOGOSYA_ZOKUGARA3 ';
            VSQLSEL := VSQLSEL ||        ', NVL(GAK.HOGOSYA_ZOKUGARA4,0) AS GAKUREIBO_HOGOSYA_ZOKUGARA4 ';
            --  2025/01/15 JPJYS.SONGSHIHAO UPDATE 0.3.030.005:学校区マスタ対応（GKBTMSGAKKUを使用しないように） Start
            /*
            -- 小学校区コード
            VSQLSEL := VSQLSEL ||        ', ( ';
            VSQLSEL := VSQLSEL ||        '    SELECT ';
            VSQLSEL := VSQLSEL ||        '        NVL(GKBTMSGAKKU.GAKKOKU_CD, 0)  ';
            VSQLSEL := VSQLSEL ||        '    FROM ';
            VSQLSEL := VSQLSEL ||        '         GKBTMSGAKKU ';
            VSQLSEL := VSQLSEL ||        '    WHERE ';
            VSQLSEL := VSQLSEL ||        '    GKBTMSGAKKU.GAKKO_KBN_CD     = 1 ';
            VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.SAISHIN_FLG  = 0 ';
            VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.SAKUJO_FLG   = 0 ';
            IF g_nGAKKU_KBN = 0 THEN
                --変数.学区管理区分 が 0:住所 の場合、下記の条件を追記する。
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.OAZA_CD      = REN.OAZA_CD ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.HONBAN_FR   <= REN.HONBAN ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.HONBAN_TO   >= REN.HONBAN ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN1_FR  <= REN.EDABAN1 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN1_TO  >= REN.EDABAN1 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN2_FR  <= REN.EDABAN2 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN2_TO  >= REN.EDABAN2 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN3_FR  <= REN.EDABAN3 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN3_TO  >= REN.EDABAN3 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GAIKU_FR    <= REN.GAIKU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GAIKU_TO    >= REN.GAIKU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.TOU_FR      <= REN.TOU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.TOU_TO      >= REN.TOU ';
            ELSIF g_nGAKKU_KBN = 1 THEN
                --変数.学区管理区分が 1:行政区 の場合、下記の条件を追記する。
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GYOSEIKU_CD  = REN.GYOSEIKU_CD ';
            END IF;
            VSQLSEL := VSQLSEL ||        ') ';
            VSQLSEL := VSQLSEL ||        'AS JUKIATENA_SHOGAKKOKU_CD ';
            -- 中学校区コード
            VSQLSEL := VSQLSEL ||        ', ( ';
            VSQLSEL := VSQLSEL ||        '    SELECT ';
            VSQLSEL := VSQLSEL ||        '        NVL(GKBTMSGAKKU.GAKKOKU_CD, 0)  ';
            VSQLSEL := VSQLSEL ||        '    FROM ';
            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU ';
            VSQLSEL := VSQLSEL ||        '    WHERE ';
            VSQLSEL := VSQLSEL ||        '    GKBTMSGAKKU.GAKKO_KBN_CD     = 2 ';
            VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.SAISHIN_FLG  = 0 ';
            VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.SAKUJO_FLG   = 0 ';
            IF g_nGAKKU_KBN = 0 THEN
                --変数.学区管理区分 が 0:住所 の場合、下記の条件を追記する。
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.OAZA_CD      = REN.OAZA_CD ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.HONBAN_FR   <= REN.HONBAN ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.HONBAN_TO   >= REN.HONBAN ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN1_FR  <= REN.EDABAN1 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN1_TO  >= REN.EDABAN1 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN2_FR  <= REN.EDABAN2 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN2_TO  >= REN.EDABAN2 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN3_FR  <= REN.EDABAN3 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN3_TO  >= REN.EDABAN3 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GAIKU_FR    <= REN.GAIKU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GAIKU_TO    >= REN.GAIKU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.TOU_FR      <= REN.TOU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.TOU_TO      >= REN.TOU ';    
            ELSIF g_nGAKKU_KBN = 1 THEN
                --変数.学区管理区分が 1:行政区 の場合、下記の条件を追記する。
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GYOSEIKU_CD  = REN.GYOSEIKU_CD ';
            END IF;   
            VSQLSEL := VSQLSEL ||        ') ';
            VSQLSEL := VSQLSEL ||        'AS JUKIATENA_CHUGAKKOKU_CD ';
            -- 就学指定校(小学校)取得
            VSQLSEL := VSQLSEL ||        ', ( ';
            VSQLSEL := VSQLSEL ||        '    SELECT ';
            VSQLSEL := VSQLSEL ||        '        NVL(GKBTSHOGAKKO.SYOGAKO_CD, 0)  ';
            VSQLSEL := VSQLSEL ||        '    FROM ';
            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU, GKBTSHOGAKKO  ';
            VSQLSEL := VSQLSEL ||        '    WHERE ';
            VSQLSEL := VSQLSEL ||        '    GKBTMSGAKKU.GAKKO_KBN_CD     = 1 ';
            VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.SAISHIN_FLG  = 0 ';
            VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.SAKUJO_FLG   = 0 ';
            IF g_nGAKKU_KBN = 0 THEN
                --変数.学区管理区分 が 0:住所 の場合、下記の条件を追記する。
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.OAZA_CD      = REN.OAZA_CD ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.HONBAN_FR   <= REN.HONBAN ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.HONBAN_TO   >= REN.HONBAN ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN1_FR  <= REN.EDABAN1 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN1_TO  >= REN.EDABAN1 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN2_FR  <= REN.EDABAN2 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN2_TO  >= REN.EDABAN2 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN3_FR  <= REN.EDABAN3 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN3_TO  >= REN.EDABAN3 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GAIKU_FR    <= REN.GAIKU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GAIKU_TO    >= REN.GAIKU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.TOU_FR      <= REN.TOU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.TOU_TO      >= REN.TOU ';    
            ELSIF g_nGAKKU_KBN = 1 THEN
                --変数.学区管理区分が 1:行政区 の場合、下記の条件を追記する。
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GYOSEIKU_CD  = REN.GYOSEIKU_CD ';
            END IF;   
            VSQLSEL := VSQLSEL ||        '    AND GKBTSHOGAKKO.GAKKOKU_CD = GKBTMSGAKKU.GAKKOKU_CD ';
            VSQLSEL := VSQLSEL ||        '    AND GKBTSHOGAKKO.SAKUJO_FLG = 0 ';
            VSQLSEL := VSQLSEL ||        ') ';
            VSQLSEL := VSQLSEL ||        'AS JUKIATENA_SHITEI_SHOGAKKO_CD ';
            -- 就学指定校(中学校)取得
            VSQLSEL := VSQLSEL ||        ', ( ';
            VSQLSEL := VSQLSEL ||        '    SELECT ';
            VSQLSEL := VSQLSEL ||        '        NVL(GKBTCHUGAKKO.TYUGAKO_CD, 0)  ';
            VSQLSEL := VSQLSEL ||        '    FROM ';
            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU, GKBTCHUGAKKO';
            VSQLSEL := VSQLSEL ||        '    WHERE ';
            VSQLSEL := VSQLSEL ||        '    GKBTMSGAKKU.GAKKO_KBN_CD     = 2 ';
            VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.SAISHIN_FLG  = 0 ';
            VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.SAKUJO_FLG   = 0 ';
            IF g_nGAKKU_KBN = 0 THEN
                --変数.学区管理区分 が 0:住所 の場合、下記の条件を追記する。
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.OAZA_CD      = REN.OAZA_CD ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.HONBAN_FR   <= REN.HONBAN ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.HONBAN_TO   >= REN.HONBAN ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN1_FR  <= REN.EDABAN1 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN1_TO  >= REN.EDABAN1 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN2_FR  <= REN.EDABAN2 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN2_TO  >= REN.EDABAN2 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN3_FR  <= REN.EDABAN3 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.EDABAN3_TO  >= REN.EDABAN3 ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GAIKU_FR    <= REN.GAIKU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GAIKU_TO    >= REN.GAIKU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.TOU_FR      <= REN.TOU ';
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.TOU_TO      >= REN.TOU ';    
            ELSIF g_nGAKKU_KBN = 1 THEN
                --変数.学区管理区分が 1:行政区 の場合、下記の条件を追記する。
                VSQLSEL := VSQLSEL ||        '    AND GKBTMSGAKKU.GYOSEIKU_CD  = REN.GYOSEIKU_CD ';
            END IF;   
            VSQLSEL := VSQLSEL ||        '    AND GKBTCHUGAKKO.GAKKOKU_CD = GKBTMSGAKKU.GAKKOKU_CD ';
            VSQLSEL := VSQLSEL ||        '    AND GKBTCHUGAKKO.SAKUJO_FLG = 0 ';
            VSQLSEL := VSQLSEL ||        ') ';
            VSQLSEL := VSQLSEL ||        'AS JUKIATENA_SHITEI_CHUGAKKO_CD ';
            
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
            -- 小学校区コード
--            VSQLSEL := VSQLSEL ||        ', ( ';
--            VSQLSEL := VSQLSEL ||        '    SELECT ';
--            VSQLSEL := VSQLSEL ||        '        NVL(GAKKOKU_CD, 0)  ';
--            VSQLSEL := VSQLSEL ||        '    FROM ';
--            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU  ';
--            VSQLSEL := VSQLSEL ||        '    WHERE ';
--            VSQLSEL := VSQLSEL ||        '        GAKKO_KBN_CD = 1  ';
--            VSQLSEL := VSQLSEL ||        '        AND SAISHIN_FLG = 0  ';
--            VSQLSEL := VSQLSEL ||        '        AND SAKUJO_FLG = 0 ';
--            IF g_nGAKKU_KBN = 0 THEN
                --変数.学区管理区分 が 0:住所 の場合、下記の条件を追記する。
--                VSQLSEL := VSQLSEL ||        '        AND OAZA_CD      = REN.OAZA_CD';
--                VSQLSEL := VSQLSEL ||        '        AND HONBAN_FR   <= REN.HONBAN';
--                VSQLSEL := VSQLSEL ||        '        AND HONBAN_TO   >= REN.HONBAN';
--                VSQLSEL := VSQLSEL ||        '        AND EDABAN1_FR  <= REN.EDABAN1';
--                VSQLSEL := VSQLSEL ||        '        AND EDABAN1_TO  >= REN.EDABAN1';
--                VSQLSEL := VSQLSEL ||        '        AND EDABAN2_FR  <= REN.EDABAN2';
--                VSQLSEL := VSQLSEL ||        '        AND EDABAN2_TO  >= REN.EDABAN2';
--                VSQLSEL := VSQLSEL ||        '        AND EDABAN3_FR  <= REN.EDABAN3';
--                VSQLSEL := VSQLSEL ||        '        AND EDABAN3_TO  >= REN.EDABAN3';
--                VSQLSEL := VSQLSEL ||        '        AND GAIKU_FR    <= REN.GAIKU';
--                VSQLSEL := VSQLSEL ||        '        AND GAIKU_TO    >= REN.GAIKU';
--                VSQLSEL := VSQLSEL ||        '        AND TOU_FR      <= REN.TOU';
--                VSQLSEL := VSQLSEL ||        '        AND TOU_TO      >= REN.TOU';
--            ELSIF g_nGAKKU_KBN = 1 THEN
                --変数.学区管理区分が 1:行政区 の場合、下記の条件を追記する。
--                VSQLSEL := VSQLSEL ||        '        AND GYOSEIKU_CD  = REN.GYOSEIKU_CD';
--            END IF;
--            VSQLSEL := VSQLSEL ||        ') AS JUKIATENA_SHOGAKKOKU_CD ';
            -- 中学校区コード
--            VSQLSEL := VSQLSEL ||        ', ( ';
--            VSQLSEL := VSQLSEL ||        '    SELECT ';
--            VSQLSEL := VSQLSEL ||        '        NVL(GAKKOKU_CD, 0)  ';
--            VSQLSEL := VSQLSEL ||        '    FROM ';
--            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU  ';
--            VSQLSEL := VSQLSEL ||        '    WHERE ';
--            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU.GAKKO_KBN_CD = 2  ';
--            VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAISHIN_FLG = 0  ';
--            VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAKUJO_FLG = 0 ';
--            IF g_nGAKKU_KBN = 0 THEN
                --変数.学区管理区分 が 0:住所 の場合、下記の条件を追記する。
--                VSQLSEL := VSQLSEL ||     '       JOIN GAAVRENKEIATENA REN ';
--                VSQLSEL := VSQLSEL ||     '       ON GKBTMSGAKKU.OAZA_CD = REN.OAZA_CD ';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.OAZA_CD      = REN.OAZA_CD';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.HONBAN_FR   <= REN.HONBAN';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.HONBAN_TO   >= REN.HONBAN';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.EDABAN1_FR  <= REN.EDABAN1';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.EDABAN1_TO  >= REN.EDABAN1';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.EDABAN2_FR  <= REN.EDABAN2';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.EDABAN2_TO  >= REN.EDABAN2';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.EDABAN3_FR  <= REN.EDABAN3';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.EDABAN3_TO  >= REN.EDABAN3';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.GAIKU_FR    <= REN.GAIKU';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.GAIKU_TO    >= REN.GAIKU';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.TOU_FR      <= REN.TOU';
--                VSQLSEL := VSQLSEL ||     '       AND GKBTMSGAKKU.TOU_TO      >= REN.TOU';
--                VSQLSEL := VSQLSEL ||        '    WHERE ';
--            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU.GAKKO_KBN_CD = 2  ';
--            VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAISHIN_FLG = 0  ';
--            VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAKUJO_FLG = 0 ';
--            ELSIF g_nGAKKU_KBN = 1 THEN
                --変数.学区管理区分が 1:行政区 の場合、下記の条件を追記する。
--                VSQLSEL := VSQLSEL ||        '    WHERE ';
--                VSQLSEL := VSQLSEL ||        '      GKBTMSGAKKU.GAKKO_KBN_CD = 2  ';
--                VSQLSEL := VSQLSEL ||     '        AND GKBTMSGAKKU.GYOSEIKU_CD  = REN.GYOSEIKU_CD';
--            VSQLSEL := VSQLSEL ||        '         AND GKBTMSGAKKU.SAISHIN_FLG = 0  ';
--            VSQLSEL := VSQLSEL ||        '         AND GKBTMSGAKKU.SAKUJO_FLG = 0 ';
--            END IF;
--            VSQLSEL := VSQLSEL ||        ') AS JUKIATENA_CHUGAKKOKU_CD ';
            -- 就学指定校(小学校)取得
--            VSQLSEL := VSQLSEL ||        ', ( ';
--            VSQLSEL := VSQLSEL ||        '    SELECT ';
--            VSQLSEL := VSQLSEL ||        '        NVL(SYOGAKO_CD, 0)  ';
--            VSQLSEL := VSQLSEL ||        '    FROM ';
--            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU, GKBTSHOGAKKO  ';
--            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU ';
--            VSQLSEL := VSQLSEL ||        '    WHERE ';
--            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU.GAKKO_KBN_CD = 1  ';
--            VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAISHIN_FLG = 0  ';
--            VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAKUJO_FLG = 0 ';
--            IF g_nGAKKU_KBN = 0 THEN
                --変数.学区管理区分 が 0:住所 の場合、下記の条件を追記する。
--                VSQLSEL := VSQLSEL ||    '       JOIN GAAVRENKEIATENA REN ';
--                VSQLSEL := VSQLSEL ||    '       ON GKBTMSGAKKU.OAZA_CD = REN.OAZA_CD';                
--              VSQLSEL := VSQLSEL ||    '      AND GKBTMSGAKKU.OAZA_CD      = REN.OAZA_CD';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.HONBAN_FR   <= REN.HONBAN';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.HONBAN_TO   >= REN.HONBAN';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN1_FR  <= REN.EDABAN1';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN1_TO  >= REN.EDABAN1';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN2_FR  <= REN.EDABAN2';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN2_TO  >= REN.EDABAN2';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN3_FR  <= REN.EDABAN3';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN3_TO  >= REN.EDABAN3';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.GAIKU_FR    <= REN.GAIKU';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.GAIKU_TO    >= REN.GAIKU';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.TOU_FR      <= REN.TOU';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.TOU_TO      >= REN.TOU';
--                VSQLSEL := VSQLSEL ||    '         LEFT JOIN GKBTSHOGAKKO ON GKBTSHOGAKKO.GAKKOKU_CD = GKBTMSGAKKU.GAKKOKU_CD ';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTSHOGAKKO.SAKUJO_FLG = 0';
--                VSQLSEL := VSQLSEL ||        '    WHERE ';
--                VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU.GAKKO_KBN_CD = 1  ';
--                VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAISHIN_FLG = 0  ';
--                VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAKUJO_FLG = 0 ';
                
--            ELSIF g_nGAKKU_KBN = 1 THEN
                --変数.学区管理区分が 1:行政区 の場合、下記の条件を追記する。
--                VSQLSEL := VSQLSEL ||        '    WHERE ';
--                VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU.GAKKO_KBN_CD = 1  ';
--                VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAISHIN_FLG = 0  ';
--                VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAKUJO_FLG = 0 ';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.GYOSEIKU_CD  = REN.GYOSEIKU_CD';
--            END IF;
--            VSQLSEL := VSQLSEL ||        '        AND GKBTSHOGAKKO.GAKKOKU_CD(+) = GKBTMSGAKKU.GAKKOKU_CD';
--            VSQLSEL := VSQLSEL ||        '        AND GKBTSHOGAKKO.SAKUJO_FLG(+) = 0 ';
--            VSQLSEL := VSQLSEL ||        ') AS JUKIATENA_SHITEI_SHOGAKKO_CD ';
            --就学指定校(中学校)取得
--            VSQLSEL := VSQLSEL ||        ', ( ';
--            VSQLSEL := VSQLSEL ||        '    SELECT ';
--            VSQLSEL := VSQLSEL ||        '        NVL(TYUGAKO_CD, 0)  ';
--            VSQLSEL := VSQLSEL ||        '    FROM ';
--            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU, GKBTCHUGAKKO  ';
--            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU';
--            VSQLSEL := VSQLSEL ||        '    WHERE ';
--            VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU.GAKKO_KBN_CD = 2  ';
--            VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAISHIN_FLG = 0  ';
--            VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAKUJO_FLG = 0 ';
--            IF g_nGAKKU_KBN = 0 THEN
                --変数.学区管理区分 が 0:住所 の場合、下記の条件を追記する。
--                VSQLSEL := VSQLSEL ||    '        JOIN GAAVRENKEIATENA REN ON GKBTMSGAKKU.OAZA_CD = REN.OAZA_CD';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.OAZA_CD      = REN.OAZA_CD';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.HONBAN_FR   <= REN.HONBAN';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.HONBAN_TO   >= REN.HONBAN';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN1_FR  <= REN.EDABAN1';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN1_TO  >= REN.EDABAN1';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN2_FR  <= REN.EDABAN2';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN2_TO  >= REN.EDABAN2';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN3_FR  <= REN.EDABAN3';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.EDABAN3_TO  >= REN.EDABAN3';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.GAIKU_FR    <= REN.GAIKU';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.GAIKU_TO    >= REN.GAIKU';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.TOU_FR      <= REN.TOU';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.TOU_TO      >= REN.TOU';
--               VSQLSEL := VSQLSEL ||    ' LEFT JOIN GKBTCHUGAKKO ';
--               VSQLSEL := VSQLSEL ||    ' ON GKBTCHUGAKKO.GAKKOKU_CD = GKBTMSGAKKU.GAKKOKU_CD ';
--               VSQLSEL := VSQLSEL ||      '   AND GKBTCHUGAKKO.SAKUJO_FLG = 0';                          
--               VSQLSEL := VSQLSEL ||        '    WHERE ';
--               VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU.GAKKO_KBN_CD = 2  ';
--               VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAISHIN_FLG = 0  ';
--               VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAKUJO_FLG = 0 ';
--            ELSIF g_nGAKKU_KBN = 1 THEN
                --変数.学区管理区分が 1:行政区 の場合、下記の条件を追記する。
--                VSQLSEL := VSQLSEL ||        '    WHERE ';
--               VSQLSEL := VSQLSEL ||        '        GKBTMSGAKKU.GAKKO_KBN_CD = 2  ';
--               VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAISHIN_FLG = 0  ';
--               VSQLSEL := VSQLSEL ||        '        AND GKBTMSGAKKU.SAKUJO_FLG = 0 ';
--                VSQLSEL := VSQLSEL ||    '        AND GKBTMSGAKKU.GYOSEIKU_CD  = REN.GYOSEIKU_CD';
--            END IF;
--            VSQLSEL := VSQLSEL ||        '        AND GKBTCHUGAKKO.GAKKOKU_CD(+) = GKBTMSGAKKU.GAKKOKU_CD';
--            VSQLSEL := VSQLSEL ||        '        AND GKBTCHUGAKKO.SAKUJO_FLG(+) = 0 ';
--            VSQLSEL := VSQLSEL ||        ') AS JUKIATENA_SHITEI_CHUGAKKO_CD ';            
            */
            VSQLSEL := VSQLSEL ||        ', REN.SHOGAKU_CD        AS JUKIATENA_SHOGAKKOKU_CD ';
            VSQLSEL := VSQLSEL ||        ', REN.CHUGAKU_CD        AS JUKIATENA_CHUGAKKOKU_CD ';
            VSQLSEL := VSQLSEL ||        ', REN.SHOGAKU_CD        AS JUKIATENA_SHITEI_SHOGAKKO_CD ';
            VSQLSEL := VSQLSEL ||        ', REN.CHUGAKU_CD        AS JUKIATENA_SHITEI_CHUGAKKO_CD ';
            --  2025/01/15 JPJYS.SONGSHIHAO UPDATE 0.3.030.005:学校区マスタ対応（GKBTMSGAKKUを使用しないように） End
            VSQLSEL := VSQLSEL ||        ', GAK.GAKKO_KBN_CD      AS GAKUREIBO_GAKKO_KBN ';
            VSQLSEL := VSQLSEL ||        ', GAK.SHOGAKKOKU_CD     AS GAKUREIBO_SHOGAKKOKU_CD ';
            VSQLSEL := VSQLSEL ||        ', GAK.CHUGAKKOKU_CD     AS GAKUREIBO_CHUGAKKOKU_CD ';
            VSQLSEL := VSQLSEL ||        ', GAK.SHITEI_SYOGAKO_CD AS GAKUREIBO_SHITEI_SHOGAKKO_CD ';
            VSQLSEL := VSQLSEL ||        ', GAK.SHITEI_TYUGAKO_CD AS GAKUREIBO_SHITEI_CHUGAKKO_CD ';
            
            VSQLSEL := VSQLSEL ||   'FROM GAAVRENKEIATENA REN ';
            VSQLSEL := VSQLSEL ||   'LEFT JOIN GAK ';
            VSQLSEL := VSQLSEL ||   'ON REN.KOJIN_NO = GAK.KOJIN_NO ';
            VSQLSEL := VSQLSEL ||   'WHERE REN.SHORIBI_KEY BETWEEN ' || NKAISHIBI || ' AND ' || NSHURYOBI || ' ';
            VSQLSEL := VSQLSEL ||   'AND REN.SEINENGAPI BETWEEN ' || NSEINENGAPI_S || ' AND ' || NSEINENGAPI_E || ' ';
            VSQLSEL := VSQLSEL ||   'AND REN.IDO_JIYU IN ('|| g_sJUKI_IDO_CODE ||') ';
            VSQLSEL := VSQLSEL ||   'ORDER BY REN.KOJIN_NO,REN.RIREKI_RENBAN';

                         
--  2024/07/01 ZCZL.YANGXINYU ADD END
--            VSQLSEL := VSQLSEL ||   'FROM GAAVRENKEIATENA REN, ';
--            VSQLSEL := VSQLSEL ||        '(SELECT GAK1.KOJIN_NO, GAK1.HOGOSYA_KOJIN_NO, GAK1.SHORIBI, GAK1.SYOGAKO_CD, GAK1.TYUGAKO_CD';
--            VSQLSEL := VSQLSEL ||        ', GAK1.ZOKUGARA1, GAK1.ZOKUGARA2, GAK1.ZOKUGARA3, GAK1.ZOKUGARA4, GAK1.HOGOSYA_ZOKUGARA1, GAK1.HOGOSYA_ZOKUGARA2, GAK1.HOGOSYA_ZOKUGARA3, GAK1.HOGOSYA_ZOKUGARA4 ';
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
--            VSQLSEL := VSQLSEL ||        ', GAK1.GAKKO_KBN_CD , GAK1.SHOGAKKOKU_CD , GAK1.CHUGAKKOKU_CD , GAK1.SHITEI_SYOGAKO_CD , GAK1.SHITEI_TYUGAKO_CD ';
--            VSQLSEL := VSQLSEL ||           'FROM GKBTGAKUREIBO GAK1, ';
--            VSQLSEL := VSQLSEL ||                '(SELECT KOJIN_NO, MAX(RIREKI_RENBAN) RIREKI_RENBAN ';
--            VSQLSEL := VSQLSEL ||                   'FROM GKBTGAKUREIBO ';
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
--            VSQLSEL := VSQLSEL ||                   'WHERE SAKUJO_FLG = 0 ';
--            VSQLSEL := VSQLSEL ||                  'GROUP BY KOJIN_NO) GAK2 ';
--            VSQLSEL := VSQLSEL ||          'WHERE GAK1.KOJIN_NO = GAK2.KOJIN_NO ';
--            VSQLSEL := VSQLSEL ||            'AND GAK1.RIREKI_RENBAN = GAK2.RIREKI_RENBAN) GAK ';
--            VSQLSEL := VSQLSEL ||  'WHERE REN.SHORIBI_KEY BETWEEN ' || NKAISHIBI || ' AND ' || NSHURYOBI || ' ';
--            VSQLSEL := VSQLSEL ||    'AND REN.SEINENGAPI BETWEEN ' || NSEINENGAPI_S || ' AND ' || NSEINENGAPI_E || ' ';
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--            VSQLSEL := VSQLSEL ||    'AND REN.IDO_JIYU NOT IN (51, 52) ';
--            VSQLSEL := VSQLSEL ||    'AND REN.IDO_JIYU BETWEEN 11 AND 54 ';
--            VSQLSEL := VSQLSEL ||    'AND REN.IDO_JIYU BETWEEN 110 AND 450 ';
--            VSQLSEL := VSQLSEL ||    'AND REN.IDO_JIYU IN ('|| g_sJUKI_IDO_CODE ||') ';
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
--            VSQLSEL := VSQLSEL ||    'AND REN.KOJIN_NO = GAK.KOJIN_NO(+) ';
--            VSQLSEL := VSQLSEL ||  'ORDER BY REN.KOJIN_NO,REN.RIREKI_RENBAN';

--  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 END
            -- カーソルオープン
            OPEN CJUKIIDO FOR VSQLSEL;
            -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
            LOOP
                FETCH CJUKIIDO INTO JUKIIDO_REC;
                EXIT WHEN CJUKIIDO%NOTFOUND;

                -- ２－２
                -- １－４で取得した学齢簿更新判定区分が０で
                -- 学齢簿テーブルの処理日≧住記異動テーブルの処理日キーのデータは処理対象外とする
                IF o_RENBAN_PRM(1) = 0 AND JUKIIDO_REC.SHORIBI >= JUKIIDO_REC.SHORIBI_KEY THEN
                    NULL;
                -- １－４で取得した学齢簿更新判定区分が０で
                -- 学齢簿テーブルの処理日＜住記異動テーブルの処理日キーのデータ
                -- または１－４で取得した学齢簿更新判定区分が１の場合は処理対象とする
                ELSE
                    -- 初期化
                    VSHIMEI_KANA        := NULL;  -- 氏名かな
                    VSHIMEI_KANJI       := NULL;  -- 氏名漢字
                    VKYU_SHIMEI_KANA    := NULL;  -- 旧氏名かな
                    VKYU_SHIMEI_KANJI   := NULL;  -- 旧氏名漢字
                    VJ_KYU_SHIMEI_KANA  := NULL;  -- 児童旧氏名かな
                    VJ_KYU_SHIMEI_KANJI := NULL;  -- 児童旧氏名漢字
                    VH_SHIMEI_KANA      := NULL;  -- 保護者氏名かな
                    VH_SHIMEI_KANJI     := NULL;  -- 保護者氏名漢字
                    VH_KYU_SHIMEI_KANA  := NULL;  -- 保護者旧氏名かな
                    VH_KYU_SHIMEI_KANJI := NULL;  -- 保護者旧氏名漢字
                    VKYU_H_SHIMEI_KANA  := NULL;  -- 旧保護者氏名かな
                    VKYU_H_SHIMEI_KANJI := NULL;  -- 旧保護者氏名漢字
                    NH_ZOKUGARACD1      := 0;
                    NH_ZOKUGARACD2      := 0;
                    NH_ZOKUGARACD3      := 0;
                    NH_ZOKUGARACD4      := 0;
                    NJ_ZOKUGARACD1      := 0;
                    NJ_ZOKUGARACD2      := 0;
                    NJ_ZOKUGARACD3      := 0;
                    NJ_ZOKUGARACD4      := 0;
                    -- ３．データ編集処理
                    -- ３－１異動区分の設定
                    CASE
                        -- 減異動
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--                        WHEN (JUKIIDO_REC.IDO_JIYU BETWEEN 21 AND 28) OR JUKIIDO_REC.IDO_JIYU IN (45, 46, 48) THEN
                        WHEN JUKIIDO_REC.IDO_JIYU BETWEEN 210 AND 292 THEN
                            NIDO_KBN := 1;
                        -- 増異動
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--                        WHEN (JUKIIDO_REC.IDO_JIYU BETWEEN 11 AND 13) OR JUKIIDO_REC.IDO_JIYU IN (15, 16, 18, 54) THEN
                        WHEN JUKIIDO_REC.IDO_JIYU BETWEEN 110 AND 192 THEN
                            NIDO_KBN := 2;
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--                        -- 転出取消
--                        WHEN JUKIIDO_REC.IDO_JIYU IN (14, 17) THEN
--                            NIDO_KBN := 3;
                        -- 転居
--                        WHEN JUKIIDO_REC.IDO_JIYU BETWEEN 31 AND 34 THEN
                        WHEN JUKIIDO_REC.IDO_JIYU BETWEEN 310 AND 340 THEN
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
                            NIDO_KBN := 4;
                        -- 他異動
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--                        WHEN (JUKIIDO_REC.IDO_JIYU BETWEEN 35 AND 44) OR JUKIIDO_REC.IDO_JIYU IN (47, 48) THEN
                        WHEN (JUKIIDO_REC.IDO_JIYU BETWEEN 350 AND 370) OR JUKIIDO_REC.IDO_JIYU IN (410, 450) THEN
                            NIDO_KBN := 5;
--  2024/07/01 ZCZL.YANGXINYU DELETE START 0.3.000.000:新WizLIFE２次開発
--                        -- 他異動
--                        ELSE
--                            NIDO_KBN := 5;
--  2025/09/30 JPJYS.LIUJUNHAO UPDATE START 1.0.107.001:GKB_QA_SBS372_異常終了対応
                        ELSE
                            NIDO_KBN := 5;
--  2025/09/30 JPJYS.LIUJUNHAO UPDATE END 1.0.107.001:GKB_QA_SBS372_異常終了対応
--  2024/07/01 ZCZL.YANGXINYU DELETE END
                    END CASE;

                    -- 外国人区分の設定
                    IF JUKIIDO_REC.JINKAKU_KBN = 0 THEN
                        NGAIKOKUJIN_KBN := 0;
                    ELSIF JUKIIDO_REC.JINKAKU_KBN = 1 THEN
                        NGAIKOKUJIN_KBN := 1;
                    END IF;

                    --児童旧氏名の設定
                    SELECT SHIMEI_KANA, SHIMEI_KANJI
                        INTO VSHIMEI_KANA, VSHIMEI_KANJI
                        FROM GAAVRENKEIATENA
                        WHERE KOJIN_NO = JUKIIDO_REC.KOJIN_NO
                        AND  RIREKI_RENBAN = JUKIIDO_REC.RIREKI_RENBAN;
                    IF JUKIIDO_REC.RIREKI_RENBAN > 10 THEN
                        SELECT SHIMEI_KANA, SHIMEI_KANJI
                          INTO VKYU_SHIMEI_KANA, VKYU_SHIMEI_KANJI
                          FROM GAAVRENKEIATENA
                         WHERE KOJIN_NO = JUKIIDO_REC.KOJIN_NO
                          AND  RIREKI_RENBAN = JUKIIDO_REC.RIREKI_RENBAN - 10;
                    END IF;

                    -- 氏名漢字と旧氏名漢字（ＮＵＬＬ以外）が違う場合
                    IF VKYU_SHIMEI_KANJI IS NOT NULL AND VSHIMEI_KANJI <> VKYU_SHIMEI_KANJI THEN
                        VJ_KYU_SHIMEI_KANA  := VKYU_SHIMEI_KANA;
                        VJ_KYU_SHIMEI_KANJI := VKYU_SHIMEI_KANJI;
                    -- 氏名漢字と旧氏名漢字が同じ場合または旧氏名漢字＝ＮＵＬＬ
                    ELSE
                        VJ_KYU_SHIMEI_KANA  := VSHIMEI_KANA;
                        VJ_KYU_SHIMEI_KANJI := VSHIMEI_KANJI;
                    END IF;

                    --保護者個人番号の設定
                    IF NHOGOSHA_KBN = 1 AND NGAIKOKUJIN_KBN = 1 THEN
                        -- 保護者判定区分1で外国人の場合は保護者判定をしない。
                        NH_KOJIN_NO     := 0;
                        NH_SEIBETSU     := 0;
                        VH_SHIMEI_KANA  := NULL;
                        VH_SHIMEI_KANJI := NULL;
                    ELSE
                        IF NGAIKOKUJIN_KBN = 1 THEN
                            I_RTN := GKBPK00010.FGKJHGS(JUKIIDO_REC.IDO_BI,JUKIIDO_REC.KOJIN_NO,NH_KOJIN_NO, VH_SHIMEI_KANJI);
                        ELSE
                            I_RTN := GKBPK00010.FHOGOSHA(JUKIIDO_REC.IDO_BI, JUKIIDO_REC.KOJIN_NO, NH_KOJIN_NO);
                        END IF;
                    END IF;

                    -- 保護者個人番号が0以外の場合
                    IF NH_KOJIN_NO <> 0 THEN
                        SELECT SHIMEI_KANA, SHIMEI_KANJI, SEIBETSU
                               , ZOKUGARACD1, ZOKUGARACD2, ZOKUGARACD3, ZOKUGARACD4
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
                               , RIREKI_RENBAN
                            INTO VH_SHIMEI_KANA, VH_SHIMEI_KANJI, NH_SEIBETSU
                                 , NH_ZOKUGARACD1, NH_ZOKUGARACD2, NH_ZOKUGARACD3, NH_ZOKUGARACD4
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
                                 , VH_HOGOSHA_RIREKI_RENBAN
                            FROM GABTATENAKIHON
                            WHERE KOJIN_NO = NH_KOJIN_NO;
                    ELSE
                        IF JUKIIDO_REC.HOGOSYA_KOJIN_NO > 0 THEN
                            NH_KOJIN_NO     := JUKIIDO_REC.HOGOSYA_KOJIN_NO;
                            SELECT SHIMEI_KANA, SHIMEI_KANJI, SEIBETSU
                                   , ZOKUGARACD1, ZOKUGARACD2, ZOKUGARACD3, ZOKUGARACD4
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
                                   , RIREKI_RENBAN
                                INTO VH_SHIMEI_KANA, VH_SHIMEI_KANJI, NH_SEIBETSU
                                   , NH_ZOKUGARACD1, NH_ZOKUGARACD2, NH_ZOKUGARACD3, NH_ZOKUGARACD4
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
                                   , VH_HOGOSHA_RIREKI_RENBAN
                                FROM GABTATENAKIHON
                                WHERE KOJIN_NO = JUKIIDO_REC.HOGOSYA_KOJIN_NO;
                        ELSE
                            NH_KOJIN_NO     := 0;
                            NH_SEIBETSU     := 0;
                            VH_SHIMEI_KANA  := NULL;
                            VH_SHIMEI_KANJI := NULL;
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
                            VH_HOGOSHA_RIREKI_RENBAN := 0;
                            NH_ZOKUGARACD1   := 0;
                            NH_ZOKUGARACD2   := 0;
                            NH_ZOKUGARACD3   := 0;
                            NH_ZOKUGARACD4   := 0;
                        END IF;
                    END IF;

                    BEGIN
                        SELECT ZOKUGARACD1, ZOKUGARACD2, ZOKUGARACD3, ZOKUGARACD4
                          INTO NJ_ZOKUGARACD1, NJ_ZOKUGARACD2, NJ_ZOKUGARACD3, NJ_ZOKUGARACD4
                          FROM GABTATENAKIHON
                         WHERE KOJIN_NO = JUKIIDO_REC.KOJIN_NO;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NJ_ZOKUGARACD1  := 0;
                            NJ_ZOKUGARACD2  := 0;
                            NJ_ZOKUGARACD3  := 0;
                            NJ_ZOKUGARACD4  := 0;
                    END;

                    -- 判定用続柄コードを変換
                    IF NJ_ZOKUGARACD1 BETWEEN 11 AND 29 OR NJ_ZOKUGARACD1 IN( 71,72,89 ) THEN
                        NJ_ZOKUGARACD1 := 10;    -- 子を再セット
                    END IF;

                    -- 異動区分が４と５の場合
                    IF NIDO_KBN IN (4, 5) THEN
                        IF JUKIIDO_REC.HOGOSYA_KOJIN_NO <> 0 THEN
                            -- ３－５保護者の旧氏名の設定
                            -- 保護者個人番号と学齢簿テーブルの保護者個人番号が一致する場合
                            IF NH_KOJIN_NO = JUKIIDO_REC.HOGOSYA_KOJIN_NO THEN
                                SELECT SHIMEI_KANA, SHIMEI_KANJI, KYU_SHIMEI_KANA, KYU_SHIMEI_KANJI, SHORIBI_KEY
                                  INTO VSHIMEI_KANA, VSHIMEI_KANJI, VKYU_SHIMEI_KANA, VKYU_SHIMEI_KANJI, NSHORIBI_KEY
                                  FROM GABVATENAALL
                                  WHERE KOJIN_NO = JUKIIDO_REC.HOGOSYA_KOJIN_NO
                                  AND RIREKI_RENBAN = 999;

                                -- 処理条件1と2の更新日内の異動である場合
                                IF NSHORIBI_KEY >= NKAISHIBI AND NSHORIBI_KEY <= NSHURYOBI THEN
                                    -- 氏名漢字に変更がある場合
                                    IF VKYU_SHIMEI_KANJI IS NOT NULL AND VSHIMEI_KANJI <> VKYU_SHIMEI_KANJI THEN
                                        VH_KYU_SHIMEI_KANA  := VKYU_SHIMEI_KANA;
                                        VH_KYU_SHIMEI_KANJI := VKYU_SHIMEI_KANJI;
                                    -- 氏名漢字に変更がない場合
                                    ELSE
                                        VH_KYU_SHIMEI_KANA  := VSHIMEI_KANA;
                                        VH_KYU_SHIMEI_KANJI := VSHIMEI_KANJI;
                                    END IF;
                                -- 処理条件1と2の更新日内の異動でない場合
                                ELSE
                                    VH_KYU_SHIMEI_KANA  := VSHIMEI_KANA;
                                    VH_KYU_SHIMEI_KANJI := VSHIMEI_KANJI;
                                END IF;

                                -- 初期値設定
                                NKYU_H_KOJIN_NO := 0;         -- 旧保護者個人番号
                                VKYU_H_SHIMEI_KANA  := NULL;  -- 旧保護者氏名かな
                                VKYU_H_SHIMEI_KANJI := NULL;  -- 旧保護者氏名漢字

                            -- 旧保護者個人番号の設定
                            -- 保護者個人番号と学齢簿テーブルの保護者個人番号が一致しない場合
                            ELSE
                                -- 初期値設定
                                VH_KYU_SHIMEI_KANA  := NULL;  -- 保護者旧氏名かな
                                VH_KYU_SHIMEI_KANJI := NULL;  -- 保護者旧氏名漢字

                                NKYU_H_KOJIN_NO := JUKIIDO_REC.HOGOSYA_KOJIN_NO;  -- 旧保護者個人番号

                                -- 同じ児童で履歴が複数存在する場合、旧履歴の保護者個人番号をセットする。
                                IF ICNT>0 THEN
                                  IF MJRENKEI_WORK(ICNT-1).JIDO_KOJIN_NO = JUKIIDO_REC.KOJIN_NO THEN
                                    NKYU_H_KOJIN_NO := MJRENKEI_WORK(ICNT-1).HOGOSHA_KOJIN_NO;
                                  END IF;
                                END IF;

                                SELECT SHIMEI_KANA, SHIMEI_KANJI
                                  INTO VKYU_H_SHIMEI_KANA, VKYU_H_SHIMEI_KANJI
                                  FROM GABTATENAKIHON
                                 WHERE KOJIN_NO = NKYU_H_KOJIN_NO;
                            END IF;
                        ELSE
                            VH_KYU_SHIMEI_KANA  := NULL;
                            VH_KYU_SHIMEI_KANJI := NULL;
                            NKYU_H_KOJIN_NO := 0;
                            VKYU_H_SHIMEI_KANA  := NULL;
                            VKYU_H_SHIMEI_KANJI := NULL;
                        END IF;
                    ELSE
                        VH_KYU_SHIMEI_KANA  := NULL;
                        VH_KYU_SHIMEI_KANJI := NULL;
                        NKYU_H_KOJIN_NO := 0;
                        VKYU_H_SHIMEI_KANA  := NULL;
                        VKYU_H_SHIMEI_KANJI := NULL;
                    END IF;

                    -- 学校区分の設定
                    -- 年度末日
                    IF TO_NUMBER(TO_CHAR(SYSDATE,'MM')) >= 4 THEN
                        NNENDO_LASTDAY := (TO_NUMBER(TO_CHAR(SYSDATE,'YYYY')) + 1) * 10000 + 331 ;
                    ELSE
                        NNENDO_LASTDAY := TO_NUMBER(TO_CHAR(SYSDATE,'YYYY')) * 10000 + 331;
                    END IF;
                    -- 年齢計算
                    IF JUKIIDO_REC.SEINENGAPI = 0 THEN
                      NNENREI := NULL;
                    ELSE
                      NNENREI := KKAPK0020.FAgeGet(TO_CHAR(JUKIIDO_REC.SEINENGAPI), TO_CHAR(NNENDO_LASTDAY));
                    END IF;


                    IF NNENREI < 13 THEN
                        NGAKO_KBN := 1;  -- 小学校
                    ELSE
                        NGAKO_KBN := 2;  -- 中学校
                    END IF;

                    -- 学校区の設定
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--                    IF NGAKO_KBN = 1 THEN
--                        -- 新学校区のセット
--                        -- 異動区分5の場合は学校区のチェックを行わない（NGAKOKUに学齢簿の学校区をセット）
--                        IF NIDO_KBN = 5 THEN
--                            NGAKOKU := JUKIIDO_REC.SYOGAKO_CD;
--                        ELSE
--                            NGAKOKU := JUKIIDO_REC.SHOGAKU_CD;
--                        END IF;
--
--                        --旧学校区のセット
--                        NKYUGAKOKU := JUKIIDO_REC.SYOGAKO_CD;
--                        -- 同じ児童で履歴が複数存在する場合、学齢簿ではなく、旧履歴の学校区をセットする。
--                        IF ICNT>0 THEN
--                            IF MJRENKEI_WORK(ICNT-1).JIDO_KOJIN_NO = JUKIIDO_REC.KOJIN_NO THEN
--                                NKYUGAKOKU := MJRENKEI_WORK(ICNT-1).GAKOKU_CD;
--                            END IF;
--                        END IF;
--                    ELSE
--                        -- 新学校区のセット
--                        -- 異動区分5の場合は学校区のチェックを行わない（NGAKOKUに学齢簿の学校区をセット）
--                        IF NIDO_KBN = 5 THEN
--                            NGAKOKU := JUKIIDO_REC.TYUGAKO_CD;
--                        ELSE
--                            NGAKOKU := JUKIIDO_REC.CHUGAKU_CD;
--                        END IF;
--
--                        --旧学校区のセット
--                        NKYUGAKOKU := JUKIIDO_REC.TYUGAKO_CD;
--                        -- 同じ児童で履歴が複数存在する場合、学齢簿ではなく、旧履歴の学校区をセットする。
--                        IF ICNT>0 THEN
--                            IF MJRENKEI_WORK(ICNT-1).JIDO_KOJIN_NO = JUKIIDO_REC.KOJIN_NO THEN
--                                NKYUGAKOKU := MJRENKEI_WORK(ICNT-1).GAKOKU_CD;
--                            END IF;
--                        END IF;
--                    END IF;
                    IF NGAKO_KBN = 1 THEN
                        --変数.学校区分 = 1:小学校 の場合
                        NGAKOKU := JUKIIDO_REC.JUKIATENA_SHITEI_SHOGAKKO_CD;    -- 学校区
                        NKYUGAKOKU := JUKIIDO_REC.GAKUREIBO_SHITEI_SHOGAKKO_CD; -- 旧学校区
                    ELSIF NGAKO_KBN = 2 THEN
                        --変数.学校区分 = 2:中学校 の場合
                        NGAKOKU := JUKIIDO_REC.JUKIATENA_SHITEI_CHUGAKKO_CD;    -- 学校区
                        NKYUGAKOKU := JUKIIDO_REC.GAKUREIBO_SHITEI_CHUGAKKO_CD; -- 旧学校区
                    END IF;
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
                    -- 処理対象の判定２
                    IF NIDO_KBN IN (4, 5) THEN
                        
                        
                        NTAISHO_FLG := 1;
                        
                        -- 現住所連番≠前住所連番（ゼロ，ＮＵＬＬ以外）かつ新学校区≠旧学校区の場合
                        IF  (JUKIIDO_REC.GENJUSHO_REN <> JUKIIDO_REC.ZENJUSHO_REN AND NVL(JUKIIDO_REC.ZENJUSHO_REN, 0) <> 0)
                        AND (NGAKOKU <> NKYUGAKOKU) THEN
                            NTAISHO_FLG := 0;
                        END IF;

                        -- 保護者個人番号≠学齢簿テーブルの保護者個人番号の場合
                        IF NH_KOJIN_NO <> NKYU_H_KOJIN_NO AND NKYU_H_KOJIN_NO > 0 THEN
                            NTAISHO_FLG := 0;
                        END IF;
                        -- 児童氏名漢字≠児童旧氏名漢字の場合
                        IF JUKIIDO_REC.SHIMEI_KANJI <> VJ_KYU_SHIMEI_KANJI THEN
                            NTAISHO_FLG := 0;
                        END IF;
                        -- 保護者氏名漢字≠保護者旧氏名漢字の場合
                        IF VH_SHIMEI_KANJI <> VH_KYU_SHIMEI_KANJI THEN
                            NTAISHO_FLG := 0;
                        END IF;
                    ELSE
                        NTAISHO_FLG := 0;
                    END IF;

                    -- 異動種別の設定
                    IF NIDO_KBN IN (4, 5) THEN
                        NIDO_SHUBETSU := 0;
                        -- 学校区分が１で小学校区≠学齢簿テーブルの小学校区の場合
                        IF NGAKO_KBN = 1 AND NGAKOKU <> JUKIIDO_REC.SYOGAKO_CD THEN
                            NIDO_SHUBETSU := 1;
                        -- 学校区分が２で中学校区≠学齢簿テーブルの中学校区の場合
                        ELSIF NGAKO_KBN = 2 AND NGAKOKU <> JUKIIDO_REC.TYUGAKO_CD THEN
                            NIDO_SHUBETSU := 1;
                        END IF;

                        -- 保護者個人番号＝旧保護者個人番号の場合
                        IF NH_KOJIN_NO = NKYU_H_KOJIN_NO AND JUKIIDO_REC.SHIMEI_KANJI <> VJ_KYU_SHIMEI_KANJI THEN
                            -- 下記２と３両方に該当する場合
                            IF NH_KOJIN_NO = NKYU_H_KOJIN_NO AND VH_SHIMEI_KANJI <> VH_KYU_SHIMEI_KANJI THEN
                                NIDO_SHUBETSU := 4;
                            -- 保護者個人番号＝旧保護者個人番号で児童氏名漢字≠児童旧氏名漢字の場合
                            ELSE
                                NIDO_SHUBETSU := 2;
                            END IF;
                        -- 保護者個人番号＝旧保護者個人番号で保護者氏名漢字≠保護者旧氏名漢字の場合
                        ELSIF NH_KOJIN_NO = NKYU_H_KOJIN_NO AND VH_SHIMEI_KANJI <> VH_KYU_SHIMEI_KANJI THEN
                            NIDO_SHUBETSU := 3;
                        END IF;
                        -- 保護者個人番号≠旧保護者個人番号の場合
                        IF NH_KOJIN_NO <> NKYU_H_KOJIN_NO AND NKYU_H_KOJIN_NO <> 0 THEN
                            -- 上記１にも該当する場合
                            IF NIDO_SHUBETSU = 1 THEN
                                NIDO_SHUBETSU := 6;
                            ELSE
                                NIDO_SHUBETSU := 5;
                            END IF;
                        END IF;
                    ELSE
                        NIDO_SHUBETSU := 0;
                    END IF;

                    -- 処理対象の判定２で処理対象のデータのみ実施
                    IF NTAISHO_FLG = 0 THEN
                        -- 中間ファイル（GKBWJUKIRENKEI）の編集
                        -- 児童個人番号
                        MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO := JUKIIDO_REC.KOJIN_NO;
                        -- 児童氏名かな
                        MJRENKEI_WORK(ICNT).JIDO_SHIMEI_KANA := JUKIIDO_REC.SHIMEI_KANA;
                        -- 児童氏名漢字
                        MJRENKEI_WORK(ICNT).JIDO_SHIMEI_KANJI := JUKIIDO_REC.SHIMEI_KANJI;
                        -- 児童旧氏名かな
                        MJRENKEI_WORK(ICNT).JIDO_KYU_SHIMEI_KANA := VJ_KYU_SHIMEI_KANA;
                        -- 児童旧氏名漢字
                        MJRENKEI_WORK(ICNT).JIDO_KYU_SHIMEI_KANJI := VJ_KYU_SHIMEI_KANJI;
                        -- 生年月日
                        MJRENKEI_WORK(ICNT).SEINENGAPI := JUKIIDO_REC.SEINENGAPI;
                        -- 表示用生年月日
                        IO_WAREKIHIZUKE := 0;
                        IO_SEIREKIHIZUKE := JUKIIDO_REC.SEINENGAPI;
                        B_RTN := KKAPK0020.FDAYEDIT(IO_WAREKIHIZUKE,
                                                     IO_SEIREKIHIZUKE,
                                                     VEDIT_GYYMMDD1,
                                                     VEDIT_GYYMMDD2,
                                                     VEDIT_GYYMMDD3,
                                                     VKJ_GENGO,
                                                     VKG_GENGO,
                                                     IWAREKI_YY,
                                                     ISEIREKI_YYYY,
                                                     IWAREKI_GYYMM,
                                                     IMM,
                                                     IDD,
                                                     IWAREKIHIZUKE,
                                                     ISEIREKIHIZUKE);
                        MJRENKEI_WORK(ICNT).HYOJI_SEINENGAPI := VEDIT_GYYMMDD1;
                        -- 性別
                        MJRENKEI_WORK(ICNT).SEIBETSU := JUKIIDO_REC.SEIBETSU;
                        -- 表示用性別
                        IF JUKIIDO_REC.SEIBETSU = 1 THEN
                            MJRENKEI_WORK(ICNT).HYOJI_SEIBETSU := '男';
                        ELSIF JUKIIDO_REC.SEIBETSU = 2 THEN
                            MJRENKEI_WORK(ICNT).HYOJI_SEIBETSU := '女';
                        END IF;
                        -- 保護者との関係
                        MJRENKEI_WORK(ICNT).ZOKUGARAMEI1 := '子';
                        -- 外国人区分
                        IF NGAIKOKUJIN_KBN = 1 THEN
                            MJRENKEI_WORK(ICNT).GAIKOKUJIN_KBN := '*';
                        ELSE
                            MJRENKEI_WORK(ICNT).GAIKOKUJIN_KBN := ' ';
                        END IF;
                        -- 世帯番号
                        MJRENKEI_WORK(ICNT).SETAI_NO := JUKIIDO_REC.SETAI_NO;
                        -- 表示用世帯番号
                        MJRENKEI_WORK(ICNT).HYOJI_SETAI_NO := KKAPK0010.FMULTIBYTEHENKAN(JUKIIDO_REC.SETAI_NO,1);
--  2024/09/02 ZCZL.WANGQIWEI UPDATE START 0.3.030.000:フェーズ4対応
                        -- 保護者個人番号
--                      MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO := NH_KOJIN_NO;
                        -- 保護者個人番号
                        IF JUKIIDO_REC.HOGOSYA_KOJIN_NO > 0 THEN
                          MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO := JUKIIDO_REC.HOGOSYA_KOJIN_NO;
                        ELSIF JUKIIDO_REC.HOGOSYA_KOJIN_NO <> 1 THEN
                          MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO := NH_KOJIN_NO;
                        END IF;
--  2024/09/02 ZCZL.WANGQIWEI UPDATE END
                        -- 保護者氏名かな
                        MJRENKEI_WORK(ICNT).HOGOSHA_SHIMEI_KANA := VH_SHIMEI_KANA;
                        -- 保護者氏名漢字
                        MJRENKEI_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := VH_SHIMEI_KANJI;
                        -- 保護者旧氏名かな
                        MJRENKEI_WORK(ICNT).HOGOSHA_KYU_SHIMEI_KANA := VH_KYU_SHIMEI_KANA;
                        -- 保護者旧氏名漢字
                        MJRENKEI_WORK(ICNT).HOGOSHA_KYU_SHIMEI_KANJI := VH_KYU_SHIMEI_KANJI;
                        -- 児童生徒との関係
                        IF I_SYSTEMJOKEN = 1 THEN
                            IF ( NH_ZOKUGARACD1 = 1 AND NH_ZOKUGARACD2 = 0 AND NH_ZOKUGARACD3 = 0 AND NH_ZOKUGARACD4 = 0 )       -- 保護者の続柄（住記）が「世帯主」のみ
                                AND  ( NJ_ZOKUGARACD1 = 10 AND NJ_ZOKUGARACD2 = 0 AND NJ_ZOKUGARACD3 = 0 AND NJ_ZOKUGARACD4 = 0 ) THEN -- 児童の続柄（住記）が「子」のみ
                                IF NH_SEIBETSU = 1 THEN
                                    I_RTN := GKBFKZKGMGET(2, 4, 0, 0, 0, MJRENKEI_WORK(ICNT).ZOKUGARAMEI2, NERRCODE);
                                ELSIF NH_SEIBETSU = 2 THEN
                                    I_RTN := GKBFKZKGMGET(2, 5, 0, 0, 0, MJRENKEI_WORK(ICNT).ZOKUGARAMEI2, NERRCODE);
                                ELSE
                                    MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 := NULL;
                                END IF;
                            ELSE
                                MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 := NULL;
                            END IF;
                        ELSE
                            IF NH_SEIBETSU = 1 THEN
                                I_RTN := GKBFKZKGMGET(2, 4, 0, 0, 0, MJRENKEI_WORK(ICNT).ZOKUGARAMEI2, NERRCODE);
                            ELSIF NH_SEIBETSU = 2 THEN
                                I_RTN := GKBFKZKGMGET(2, 5, 0, 0, 0, MJRENKEI_WORK(ICNT).ZOKUGARAMEI2, NERRCODE);
                            ELSE
                                MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 := NULL;
                            END IF;
                        END IF;
                        -- 旧保護者個人番号
                        MJRENKEI_WORK(ICNT).KYU_HOGOSHA_KOJIN_NO := NKYU_H_KOJIN_NO;
                        -- 旧保護者氏名かな
                        MJRENKEI_WORK(ICNT).KYU_HOGOSHA_SHIMEI_KANA := VKYU_H_SHIMEI_KANA;
                        -- 旧保護者氏名漢字
                        MJRENKEI_WORK(ICNT).KYU_HOGOSHA_SHIMEI_KANJI := VKYU_H_SHIMEI_KANJI;
                        -- 異動日
                        MJRENKEI_WORK(ICNT).IDO_BI := JUKIIDO_REC.IDO_BI;
                        -- 表示用異動日
                        IO_WAREKIHIZUKE := 0;
                        IO_SEIREKIHIZUKE := JUKIIDO_REC.IDO_BI;
                        B_RTN := KKAPK0020.FDAYEDIT(IO_WAREKIHIZUKE,
                                                     IO_SEIREKIHIZUKE,
                                                     VEDIT_GYYMMDD1,
                                                     VEDIT_GYYMMDD2,
                                                     VEDIT_GYYMMDD3,
                                                     VKJ_GENGO,
                                                     VKG_GENGO,
                                                     IWAREKI_YY,
                                                     ISEIREKI_YYYY,
                                                     IWAREKI_GYYMM,
                                                     IMM,
                                                     IDD,
                                                     IWAREKIHIZUKE,
                                                     ISEIREKIHIZUKE);
                        MJRENKEI_WORK(ICNT).HYOJI_IDO_BI := VEDIT_GYYMMDD1;
                        -- 異動届出日
                        MJRENKEI_WORK(ICNT).IDO_TODOKE_BI := JUKIIDO_REC.IDO_TODOKE_BI;
                        -- 表示用異動届出日
                        IO_WAREKIHIZUKE := 0;
                        IO_SEIREKIHIZUKE := JUKIIDO_REC.IDO_TODOKE_BI;
                        B_RTN := KKAPK0020.FDAYEDIT(IO_WAREKIHIZUKE,
                                                     IO_SEIREKIHIZUKE,
                                                     VEDIT_GYYMMDD1,
                                                     VEDIT_GYYMMDD2,
                                                     VEDIT_GYYMMDD3,
                                                     VKJ_GENGO,
                                                     VKG_GENGO,
                                                     IWAREKI_YY,
                                                     ISEIREKI_YYYY,
                                                     IWAREKI_GYYMM,
                                                     IMM,
                                                     IDD,
                                                     IWAREKIHIZUKE,
                                                     ISEIREKIHIZUKE);
                        MJRENKEI_WORK(ICNT).HYOJI_IDO_TODOKE_BI := VEDIT_GYYMMDD1;
                        -- 異動事由
                        MJRENKEI_WORK(ICNT).IDO_JIYU := JUKIIDO_REC.IDO_JIYU;
                        -- 表示用異動事由
                        SELECT IDO_JIYU_MEI
                          INTO MJRENKEI_WORK(ICNT).HYOJI_IDO_JIYU
                          FROM GABTIDOJIYU
                         WHERE IDO_JIYU_CD = JUKIIDO_REC.IDO_JIYU;
                        -- 学校区分
                        MJRENKEI_WORK(ICNT).GAKO_KBN := NGAKO_KBN;
                        -- 学年コード
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
                        --IF NGAKO_KBN = 1 THEN
                        --    MJRENKEI_WORK(ICNT).GAKUNEN_CD := NNENREI - 6;
                        --ELSE
                        --    MJRENKEI_WORK(ICNT).GAKUNEN_CD := NNENREI - 12;
                        --END IF;
                        IF g_nSOGYOU_SHORI_FLG = 0 THEN
                            MJRENKEI_WORK(ICNT).GAKUNEN_CD := NNENREI - 7;
                        ELSIF g_nSOGYOU_SHORI_FLG = 1 THEN
                        --  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.030.004:IT_GKB_00704対応 START
                            --MJRENKEI_WORK(ICNT).GAKUNEN_CD := NNENREI - 6;
                            MJRENKEI_WORK(ICNT).GAKUNEN_CD := NNENREI - 7;
						--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.030.004:IT_GKB_00704対応 END
                        END IF;
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
                        -- 学年名
                        MJRENKEI_WORK(ICNT).GAKUNENMEI := '年生';

                        -- 学校区コード

                        MJRENKEI_WORK(ICNT).GAKOKU_CD := NGAKOKU;
                        -- 学校区名
                        BEGIN
                            IF NGAKO_KBN = 1 THEN
                                SELECT SYOGAKOMEI
                                  INTO MJRENKEI_WORK(ICNT).GAKOKUMEI
                                  FROM GKBTSHOGAKKO
                                 WHERE SYOGAKO_CD = NGAKOKU;
                            ELSE
                                SELECT TYUGAKOMEI
                                  INTO MJRENKEI_WORK(ICNT).GAKOKUMEI
                                  FROM GKBTCHUGAKKO
                                 WHERE TYUGAKO_CD = NGAKOKU;
                            END IF;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                MJRENKEI_WORK(ICNT).GAKOKUMEI := NULL;
                        END;
                        -- 行政区コード
                        MJRENKEI_WORK(ICNT).GYOSEIKU_CD := JUKIIDO_REC.GYOSEIKU_CD;
                        -- 行政区名
                        MJRENKEI_WORK(ICNT).GYOSEIKUMEI := GAAPK0030.FGYOSEIKUMEI(JUKIIDO_REC.SANTEIDANTAI_CD, JUKIIDO_REC.GYOSEIKU_CD);
                        -- 班コード
                        MJRENKEI_WORK(ICNT).HAN_CD := JUKIIDO_REC.HAN_CD;
                        -- 班名
                        MJRENKEI_WORK(ICNT).HANMEI := GAAPK0030.FHANMEI(JUKIIDO_REC.SANTEIDANTAI_CD, JUKIIDO_REC.HAN_CD);
                        -- 算定団体コード
                        MJRENKEI_WORK(ICNT).SANTEIDANTAI_CD := JUKIIDO_REC.SANTEIDANTAI_CD;
                        -- 算定団体名
                        MJRENKEI_WORK(ICNT).SANTEIDANTAIMEI := GAAPK0030.FJICHINAME2(JUKIIDO_REC.SANTEIDANTAI_CD);
                        -- 新郵便番号／新住所
                        -- 住所連番の設定
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--                        IF JUKIIDO_REC.IDO_JIYU = 21 THEN
--                            NJUSHO_REN := JUKIIDO_REC.TENSHUTSU_YOTEI_REN;
--                        ELSIF JUKIIDO_REC.IDO_JIYU = 45 THEN
--                            NJUSHO_REN := JUKIIDO_REC.TENSHUTSU_KAKUTEI_REN;
--                        ELSE
--                            NJUSHO_REN := JUKIIDO_REC.GENJUSHO_REN;
--                        END IF;
                        IF JUKIIDO_REC.IDO_JIYU = 210 THEN
                            NJUSHO_REN := JUKIIDO_REC.TENSHUTSU_YOTEI_REN;
                        ELSIF JUKIIDO_REC.IDO_JIYU = 211 THEN
                            NJUSHO_REN := 0;
                        ELSIF JUKIIDO_REC.IDO_JIYU = 450 THEN
                            NJUSHO_REN := JUKIIDO_REC.TENSHUTSU_KAKUTEI_REN;
                        ELSE
                            NJUSHO_REN := JUKIIDO_REC.GENJUSHO_REN;
                        END IF;
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
                        IF NJUSHO_REN <> 0 THEN
                            -- 郵便番号、町名、番地、方書の取得
                            SELECT YUBIN_NO, CHOMEI, BANCHI, KATAGAKI
                              INTO MJRENKEI_WORK(ICNT).SIN_YUBIN_NO, VCHOMEI, VBANCHI, VKATAGAKI
                              FROM GABTJUKIJUSHO
                             WHERE KOJIN_NO = JUKIIDO_REC.KOJIN_NO
                               AND JUSHO_REN = NJUSHO_REN;
                            -- 住所
                            IF VKATAGAKI IS NOT NULL THEN
                                MJRENKEI_WORK(ICNT).SIN_JUSHO := VCHOMEI || VBANCHI || '　' || VKATAGAKI;
                            ELSE
                                MJRENKEI_WORK(ICNT).SIN_JUSHO := VCHOMEI || VBANCHI;
                            END IF;
                        ELSE
                            MJRENKEI_WORK(ICNT).SIN_YUBIN_NO := NULL;
                            MJRENKEI_WORK(ICNT).SIN_JUSHO := NULL;
                        END IF;
                        -- 前郵便番号／前住所
                        -- 住所連番の設定
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--                        IF JUKIIDO_REC.IDO_JIYU = 11 THEN
--                            NJUSHO_REN := JUKIIDO_REC.TENNYUMAE_REN;
--                        ELSIF JUKIIDO_REC.IDO_JIYU IN (31, 32, 33, 34) THEN
--                            NJUSHO_REN := JUKIIDO_REC.ZENJUSHO_REN;
--                        ELSE
--                            NJUSHO_REN := 0;
--                        END IF;
                        IF JUKIIDO_REC.IDO_JIYU = 110 THEN
                            NJUSHO_REN := JUKIIDO_REC.TENNYUMAE_REN;
                        ELSIF JUKIIDO_REC.IDO_JIYU = 111 THEN
                            NJUSHO_REN := 0;
                        ELSIF JUKIIDO_REC.IDO_JIYU IN (310, 320, 330, 340) THEN
                            NJUSHO_REN := JUKIIDO_REC.ZENJUSHO_REN;
                        ELSE
                            NJUSHO_REN := 0;
                        END IF;
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
                        IF NJUSHO_REN <> 0 THEN
                            -- 郵便番号、町名、番地、方書の取得
                            SELECT YUBIN_NO, CHOMEI, BANCHI, KATAGAKI
                              INTO MJRENKEI_WORK(ICNT).ZEN_YUBIN_NO, VCHOMEI, VBANCHI, VKATAGAKI
                              FROM GABTJUKIJUSHO
                             WHERE KOJIN_NO = JUKIIDO_REC.KOJIN_NO
                               AND JUSHO_REN = NJUSHO_REN;
                            -- 住所
                            IF VKATAGAKI IS NOT NULL THEN
                                MJRENKEI_WORK(ICNT).ZEN_JUSHO := VCHOMEI || VBANCHI || '　' || VKATAGAKI;
                            ELSE
                                MJRENKEI_WORK(ICNT).ZEN_JUSHO := VCHOMEI || VBANCHI;
                            END IF;
                        ELSE
                            MJRENKEI_WORK(ICNT).ZEN_YUBIN_NO := NULL;
                            MJRENKEI_WORK(ICNT).ZEN_JUSHO := NULL;
                        END IF;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
                        -- 就学指定校就学フラグ
                        IF NGAKO_KBN = 1 THEN
                            IF JUKIIDO_REC.GAKUREIBO_GAKKO_KBN <> 1 OR JUKIIDO_REC.SYOGAKO_CD <> JUKIIDO_REC.GAKUREIBO_SHITEI_SHOGAKKO_CD THEN
                                MJRENKEI_WORK(ICNT).SHITEIKO_SHUGAKU_FLG := 0;
                            ELSE
                                MJRENKEI_WORK(ICNT).SHITEIKO_SHUGAKU_FLG := 1;
                            END IF;
                        ELSIF NGAKO_KBN = 2 THEN
                            IF JUKIIDO_REC.GAKUREIBO_GAKKO_KBN <> 2 OR JUKIIDO_REC.TYUGAKO_CD <> JUKIIDO_REC.GAKUREIBO_SHITEI_CHUGAKKO_CD THEN
                                MJRENKEI_WORK(ICNT).SHITEIKO_SHUGAKU_FLG := 0;
                            ELSE
                                MJRENKEI_WORK(ICNT).SHITEIKO_SHUGAKU_FLG := 1;
                            END IF;
                        END IF;

                        -- 学校区変更フラグ
                        IF NGAKO_KBN = 1 THEN
                            IF JUKIIDO_REC.GAKUREIBO_SHOGAKKOKU_CD = JUKIIDO_REC.JUKIATENA_SHOGAKKOKU_CD  THEN
                                MJRENKEI_WORK(ICNT).GAKKOKU_HENKO_FLG := 0;
                            ELSE
                                MJRENKEI_WORK(ICNT).GAKKOKU_HENKO_FLG := 1;
                            END IF;
                        ELSIF NGAKO_KBN = 2 THEN
                            IF JUKIIDO_REC.GAKUREIBO_CHUGAKKOKU_CD = JUKIIDO_REC.JUKIATENA_CHUGAKKOKU_CD  THEN
                                MJRENKEI_WORK(ICNT).GAKKOKU_HENKO_FLG := 0;
                            ELSE
                                MJRENKEI_WORK(ICNT).GAKKOKU_HENKO_FLG := 1;
                            END IF;
                        END IF;

                        -- 保護者相違フラグ
--  2024/09/02 ZCZL.WANGQIWEI UPDATE 0.3.030.000:フェーズ4対応
--                         IF NH_KOJIN_NO <> JUKIIDO_REC.HOGOSYA_KOJIN_NO THEN
                        IF (NH_KOJIN_NO <> JUKIIDO_REC.HOGOSYA_KOJIN_NO) AND (JUKIIDO_REC.HOGOSYA_KOJIN_NO > 0) THEN
                            MJRENKEI_WORK(ICNT).HOGOSHA_SOI_FLG := 1;
                        ELSE
                            MJRENKEI_WORK(ICNT).HOGOSHA_SOI_FLG := 0;
                        END IF;
--  2024/07/01 ZCZL.YANGXINYU ADD END
                        -- 備考
                        MJRENKEI_WORK(ICNT).BIKO := NULL;
                        -- 児童氏名変更の場合
                        IF VJ_KYU_SHIMEI_KANJI <> MJRENKEI_WORK(ICNT).JIDO_SHIMEI_KANJI THEN
                            MJRENKEI_WORK(ICNT).BIKO := '児童氏名変更　' || VJ_KYU_SHIMEI_KANJI;
                            -- ＋保護者氏名変更の場合
                            IF VH_KYU_SHIMEI_KANJI <> MJRENKEI_WORK(ICNT).HOGOSHA_SHIMEI_KANJI THEN
                                MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '、' || '保護者氏名変更　' || VH_KYU_SHIMEI_KANJI;
                                -- ＋保護者変更の場合
                                IF NH_KOJIN_NO <> NKYU_H_KOJIN_NO AND NKYU_H_KOJIN_NO <> 0 THEN
                                    MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '、' || '保護者変更　' || NKYU_H_KOJIN_NO || VKYU_H_SHIMEI_KANJI;
                                END IF;
                            -- ＋保護者変更の場合
                            ELSIF NH_KOJIN_NO <> NKYU_H_KOJIN_NO AND NKYU_H_KOJIN_NO <> 0 THEN
                                MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '、' || '保護者変更　' || NKYU_H_KOJIN_NO || VKYU_H_SHIMEI_KANJI;
                            END IF;
                        -- 保護者氏名変更の場合
                        ELSIF VH_KYU_SHIMEI_KANJI <> MJRENKEI_WORK(ICNT).HOGOSHA_SHIMEI_KANJI THEN
                                MJRENKEI_WORK(ICNT).BIKO := '保護者氏名変更　' || VH_KYU_SHIMEI_KANJI;
                                -- ＋保護者変更の場合
                                IF NH_KOJIN_NO <> NKYU_H_KOJIN_NO AND NKYU_H_KOJIN_NO <> 0 THEN
                                    MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '、' || '保護者変更　' || NKYU_H_KOJIN_NO || VKYU_H_SHIMEI_KANJI;
                                END IF;
                        -- 保護者変更の場合
                        ELSIF NH_KOJIN_NO <> NKYU_H_KOJIN_NO AND NKYU_H_KOJIN_NO <> 0 THEN
                                MJRENKEI_WORK(ICNT).BIKO := '保護者変更　' || NKYU_H_KOJIN_NO || VKYU_H_SHIMEI_KANJI;
                        END IF;
                        -- 児童続柄変更メッセージ
                        IF JUKIIDO_REC.GAKUREIBO_ZOKUGARA1 > 0 AND JUKIIDO_REC.GAKUREIBO_ZOKUGARA1 <> 10 THEN
                          VW_KYU_ZOKUGARA := NULL;
                          I_RTN := GKBFKZKGMGET(1, JUKIIDO_REC.GAKUREIBO_ZOKUGARA1, JUKIIDO_REC.GAKUREIBO_ZOKUGARA2, JUKIIDO_REC.GAKUREIBO_ZOKUGARA3, JUKIIDO_REC.GAKUREIBO_ZOKUGARA4, VW_KYU_ZOKUGARA, NERRCODE);
                          IF MJRENKEI_WORK(ICNT).BIKO IS NULL THEN
                            MJRENKEI_WORK(ICNT).BIKO :=  MJRENKEI_WORK(ICNT).BIKO ||'更新前児童続柄　'|| VW_KYU_ZOKUGARA;
                          ELSE
                            MJRENKEI_WORK(ICNT).BIKO :=  MJRENKEI_WORK(ICNT).BIKO ||'、更新前児童続柄　'|| VW_KYU_ZOKUGARA;
                          END IF;
                        END IF;
                        -- 保護者続柄変更メッセージ
                        IF JUKIIDO_REC.GAKUREIBO_HOGOSYA_ZOKUGARA1 > 0 AND JUKIIDO_REC.GAKUREIBO_HOGOSYA_ZOKUGARA1 NOT IN (4, 5) THEN
                          VW_KYU_ZOKUGARA := NULL;
                          I_RTN := GKBFKZKGMGET(2, JUKIIDO_REC.GAKUREIBO_HOGOSYA_ZOKUGARA1, JUKIIDO_REC.GAKUREIBO_HOGOSYA_ZOKUGARA2, JUKIIDO_REC.GAKUREIBO_HOGOSYA_ZOKUGARA3, JUKIIDO_REC.GAKUREIBO_HOGOSYA_ZOKUGARA4, VW_KYU_ZOKUGARA, NERRCODE);
                          IF MJRENKEI_WORK(ICNT).BIKO IS NULL THEN
                            MJRENKEI_WORK(ICNT).BIKO :=  MJRENKEI_WORK(ICNT).BIKO ||'更新前保護者続柄　'|| VW_KYU_ZOKUGARA;
                          ELSE
                            MJRENKEI_WORK(ICNT).BIKO :=  MJRENKEI_WORK(ICNT).BIKO ||'、更新前保護者続柄　'|| VW_KYU_ZOKUGARA;
                          END IF;
                        END IF;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
                        -- 学齢簿存在チェックメッセージ
                        IF NIDO_KBN <> 2 AND JUKIIDO_REC.GAKUREIBO_KOJIN_NO = 0 THEN
                            IF MJRENKEI_WORK(ICNT).BIKO IS NULL THEN
                                MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '学齢簿が存在しないため更新対象外　';
                            ELSE
                                MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '、学齢簿が存在しないため更新対象外　';
                            END IF;
                        END IF;

                        -- 就学校チェックメッセージ
                        IF NIDO_KBN <> 2 AND MJRENKEI_WORK(ICNT).SHITEIKO_SHUGAKU_FLG = 0 THEN
                            IF NIDO_KBN = 1 THEN
                                IF MJRENKEI_WORK(ICNT).BIKO IS NULL THEN
                                    MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '就学指定校以外に就学中のため処理対象外　';
                                ELSE
                                    MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '、就学指定校以外に就学中のため処理対象外　';
                                END IF;
                            ELSE
                                IF MJRENKEI_WORK(ICNT).BIKO IS NULL THEN
                                    MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '就学指定校以外に就学中のため処理対象外　';
                                ELSE
                                    MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '、就学指定校以外に就学中のため処理対象外　';
                                END IF;
                            END IF;
                        END IF;

                        -- 保護者変更チェックメッセージ
                        IF MJRENKEI_WORK(ICNT).HOGOSHA_SOI_FLG = 1 THEN
                            IF MJRENKEI_WORK(ICNT).BIKO IS NULL THEN
                                MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '保護者宛名番号に相違あり　';
                            ELSE
                                MJRENKEI_WORK(ICNT).BIKO := MJRENKEI_WORK(ICNT).BIKO || '、保護者宛名番号に相違あり　' ;
                            END IF;
                        END IF;
--  2024/07/01 ZCZL.YANGXINYU ADD END
                        -- 処理日KEY
                        MJRENKEI_WORK(ICNT).SHORIBI_KEY := JUKIIDO_REC.SHORIBI_KEY;
                        -- 処理時間KEY
                        MJRENKEI_WORK(ICNT).SHORI_JIKAN_KEY := JUKIIDO_REC.SHORI_JIKAN_KEY;
                        -- 処理区分KEY
                        MJRENKEI_WORK(ICNT).SHORI_KBN_KEY := JUKIIDO_REC.SHORI_KBN_KEY;
                        -- 全部一部KEY
                        MJRENKEI_WORK(ICNT).ZENBU_ICHIBU_KEY := JUKIIDO_REC.ZENBU_ICHIBU_KEY;
                        -- 記載順位
                        MJRENKEI_WORK(ICNT).KISAI_JUNI := JUKIIDO_REC.KISAI_JUNI;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
                        -- 児童履歴連番
                        MJRENKEI_WORK(ICNT).JIDO_RIREKI_RENBAN := JUKIIDO_REC.RIREKI_RENBAN;
                        -- 保護者履歴連番
                        MJRENKEI_WORK(ICNT).HOGOSHA_RIREKI_RENBAN := VH_HOGOSHA_RIREKI_RENBAN;
                        -- 住記・宛名_小学校区コード
                        MJRENKEI_WORK(ICNT).JUKIATENA_SHOGAKKOKU_CD := JUKIIDO_REC.JUKIATENA_SHOGAKKOKU_CD;
                        -- 住記・宛名_中学校区コード
                        MJRENKEI_WORK(ICNT).JUKIATENA_CHUGAKKOKU_CD := JUKIIDO_REC.JUKIATENA_CHUGAKKOKU_CD;
                        -- 住記・宛名_就学指定校_小学校
                        MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD := JUKIIDO_REC.JUKIATENA_SHITEI_SHOGAKKO_CD;
                        -- 住記・宛名_就学指定校_中学校
                        MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD := JUKIIDO_REC.JUKIATENA_SHITEI_CHUGAKKO_CD;
                        -- 学齢簿_小学校区コード
                        MJRENKEI_WORK(ICNT).GAKUREIBO_SHOGAKKOKU_CD := JUKIIDO_REC.GAKUREIBO_SHOGAKKOKU_CD;
                        -- 学齢簿_中学校区コード
                        MJRENKEI_WORK(ICNT).GAKUREIBO_CHUGAKKOKU_CD := JUKIIDO_REC.GAKUREIBO_CHUGAKKOKU_CD;
--  2024/07/01 ZCZL.YANGXINYU ADD END
                        -- データインサート時に使用する項目のセット
                        -- GABTJUKIIDOの現存区分
                        MWORK(ICNT).GENZON_KBN := JUKIIDO_REC.GENZON_KBN;
                        -- GAAVRENKEIATENAの履歴連番
                        MWORK(ICNT).RIREKI_RENBAN := JUKIIDO_REC.RIREKI_RENBAN;
                        -- 異動区分
                        MWORK(ICNT).IDO_KBN := NIDO_KBN;
                        -- 異動種別
                        MWORK(ICNT).IDO_SHUBETSU := NIDO_SHUBETSU;

                        -- 学齢簿宛名番号

                        ICNT := ICNT + 1;     -- カウントアップ
                        IFRET := C_ISUCCESS;  -- 正常終了
                    END IF;
                END IF;
            END LOOP;
            --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 START
            NCINT := ICNT;
            --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 END
            --カーソルクローズ
            IF CJUKIIDO%ISOPEN THEN
              CLOSE CJUKIIDO;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IFRET := C_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := C_INOT_SUCCESS;  -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            --カーソルクローズ
            IF CJUKIIDO%ISOPEN THEN
              CLOSE CJUKIIDO;
            END IF;
        RETURN IFRET;
    END FUNC_GET_JRENKEI_WK;

--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------
    --  機能概要      : 異動事由の設定
    --  パラメータ    : データのワーク領域
    --  モジュール区分: 内部関数
    --  戻り値        : 異動事由
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_GRB_HENKO_JIYU(ICNT IN BINARY_INTEGER)  RETURN NVARCHAR2 IS
        sSQLVAL               NVARCHAR2(100);                -- 戻り値
    BEGIN
        CASE
            WHEN MJRENKEI_WORK(ICNT).IDO_JIYU BETWEEN 110 AND 192 THEN
                IF g_nSOGYOU_SHORI_FLG = 0 THEN
                    IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 OR MJRENKEI_WORK(ICNT).GAKUNEN_CD = 6 THEN
                        sSQLVAL :=  '1';
                    ELSE
                        IF MJRENKEI_WORK(ICNT).IDO_JIYU IN (111, 150, 160) THEN
                            sSQLVAL :=  '3';
                        ELSE
                            sSQLVAL :=  '2';
                        END IF;
                    END IF;
                ELSIF g_nSOGYOU_SHORI_FLG = 1 THEN
                    IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 THEN
                        sSQLVAL :=  '1';
                    ELSE
                        IF MJRENKEI_WORK(ICNT).IDO_JIYU IN (111, 150, 160) THEN
                            sSQLVAL :=  '3';
                        ELSE
                            sSQLVAL :=  '2';
                        END IF;
                    END IF;
                ELSE
                    sSQLVAL :=  'NULL';
                END IF;
            WHEN MJRENKEI_WORK(ICNT).IDO_JIYU BETWEEN 210 AND 292 THEN
                IF MJRENKEI_WORK(ICNT).IDO_JIYU IN (210, 211) THEN
                    sSQLVAL :=  '5';
                ELSIF MJRENKEI_WORK(ICNT).IDO_JIYU BETWEEN 220 AND 292 THEN
                    sSQLVAL :=  '99';
                ELSE
                    sSQLVAL :=  'NULL';
                END IF;
            WHEN MJRENKEI_WORK(ICNT).IDO_JIYU BETWEEN 310 AND 340 THEN
                IF MJRENKEI_WORK(ICNT).GAKKOKU_HENKO_FLG = 1 AND MJRENKEI_WORK(ICNT).SHITEIKO_SHUGAKU_FLG = 1 THEN
                    sSQLVAL :=  '4';
                ELSE
                    sSQLVAL :=  '11';
                END IF;
            WHEN (MJRENKEI_WORK(ICNT).IDO_JIYU BETWEEN 350 AND 412) OR MJRENKEI_WORK(ICNT).IDO_JIYU = 418 OR (MJRENKEI_WORK(ICNT).IDO_JIYU BETWEEN 430 AND 450)  THEN
                sSQLVAL :=  '99';
            WHEN MJRENKEI_WORK(ICNT).IDO_JIYU BETWEEN 413 AND 417 THEN
                sSQLVAL :=  '12';
            WHEN MJRENKEI_WORK(ICNT).IDO_JIYU = 418 THEN
                sSQLVAL :=  '11';
            ELSE
                sSQLVAL :=  'NULL';
        END CASE;
        RETURN sSQLVAL;
    END FUNC_GET_GRB_HENKO_JIYU;

    --------------------------------------------------------
    --  機能概要      : 減事由の設定
    --  パラメータ    : データのワーク領域
    --  モジュール区分: 内部関数
    --  戻り値        : 異動事由
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_GEN_JIYU_CD(ICNT IN BINARY_INTEGER)  RETURN NVARCHAR2 IS
        sSQLVAL               NVARCHAR2(100);                -- 戻り値
    BEGIN
        CASE
            WHEN MJRENKEI_WORK(ICNT).IDO_JIYU IN (210, 211) THEN
                sSQLVAL := '21';
            WHEN MJRENKEI_WORK(ICNT).IDO_JIYU = 220 THEN
                sSQLVAL := '22';
            WHEN MJRENKEI_WORK(ICNT).IDO_JIYU IN (230, 291, 292) THEN
                sSQLVAL := '23';
            WHEN MJRENKEI_WORK(ICNT).IDO_JIYU = 240 OR (MJRENKEI_WORK(ICNT).IDO_JIYU BETWEEN 260 AND 280) THEN
                sSQLVAL := '24';
            WHEN MJRENKEI_WORK(ICNT).IDO_JIYU = 250 THEN
                sSQLVAL := '25';
            ELSE
                sSQLVAL := 'NULL';
        END CASE;
        RETURN sSQLVAL;
    END FUNC_GET_GEN_JIYU_CD;

    --------------------------------------------------------
    --  機能概要      : 学齢簿更新SQL
    --  パラメータ    :　なし
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := ' UPDATE GKBTGAKUREIBO ';
        sSQL := sSQL || ' SET GKBTGAKUREIBO.SAISHIN_KBN = 1,';
        sSQL := sSQL || ' GKBTGAKUREIBO.SYS_KOSHINBI = '|| ISAKUSEIBI ||',';
        sSQL := sSQL || ' GKBTGAKUREIBO.SYS_JIKAN = '||NSYSTIME||',';
        sSQL := sSQL || ' GKBTGAKUREIBO.SYS_SHOKUINKOJIN_NO = '''||g_sTANTOCODE||''',';
        sSQL := sSQL || ' GKBTGAKUREIBO.SYS_TANMATU_NO = ''' || g_sWSNUM || '''';
        sSQL := sSQL || ' WHERE GKBTGAKUREIBO.KOJIN_NO = '|| RGAKUREIBO.KOJIN_NO ;
        sSQL := sSQL || ' AND GKBTGAKUREIBO.SAISHIN_KBN = 0';
        RETURN sSQL;
    END FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;

    --------------------------------------------------------
    --  機能概要      : 就学履歴更新SQL
    --  パラメータ    :　なし
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_UPDATE_GKBTSHUGAKURIREKI_SQL RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := ' UPDATE GKBTSHUGAKURIREKI ';
        sSQL := sSQL || ' SET GKBTSHUGAKURIREKI.SAISHIN_FLG = 1,';
        sSQL := sSQL || ' GKBTSHUGAKURIREKI.SYS_KOSHINBI = '|| ISAKUSEIBI ||',';
        sSQL := sSQL || ' GKBTSHUGAKURIREKI.SYS_JIKAN = '||NSYSTIME||',';
        sSQL := sSQL || ' GKBTSHUGAKURIREKI.SYS_SHOKUINKOJIN_NO = '''||g_sTANTOCODE||''',';
        sSQL := sSQL || ' GKBTSHUGAKURIREKI.SYS_TANMATU_NO = ''' || g_sWSNUM || '''';
        sSQL := sSQL || ' WHERE GKBTSHUGAKURIREKI.KOJIN_NO = '|| RGAKUREIBO.KOJIN_NO ;
        sSQL := sSQL || ' AND GKBTSHUGAKURIREKI.SAISHIN_FLG = 0';

        RETURN sSQL;
    END FUNC_GET_UPDATE_GKBTSHUGAKURIREKI_SQL;

    --------------------------------------------------------
    --  機能概要      : 学年履歴更新SQL
    --  パラメータ    :　なし
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_UPDATE_GKBTGAKUNENRIREKI_SQL RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := ' UPDATE GKBTGAKUNENRIREKI ';
        sSQL := sSQL || ' SET GKBTGAKUNENRIREKI.SAISIN_FLG = 1,';
        sSQL := sSQL || ' GKBTGAKUNENRIREKI.SYS_KOSHINBI = '|| ISAKUSEIBI ||',';
        sSQL := sSQL || ' GKBTGAKUNENRIREKI.SYS_JIKAN = '||NSYSTIME||',';
        sSQL := sSQL || ' GKBTGAKUNENRIREKI.SYS_SHOKUINKOJIN_NO = '''||g_sTANTOCODE||''',';
        sSQL := sSQL || ' GKBTGAKUNENRIREKI.SYS_TANMATU_NO = ''' || g_sWSNUM || '''';
        sSQL := sSQL || ' WHERE GKBTGAKUNENRIREKI.KOJIN_NO = '|| RGAKUREIBO.KOJIN_NO ;
        sSQL := sSQL || ' AND GKBTGAKUNENRIREKI.SAISIN_FLG = 0';
        RETURN sSQL;
    END FUNC_GET_UPDATE_GKBTGAKUNENRIREKI_SQL;

    --------------------------------------------------------
    --  機能概要      : 学年履歴新規SQL
    --  パラメータ    :　なし
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTGAKUNENRIREKI_SQL(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTGAKUNENRIREKI ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        IF g_nIDO_NENDO = 0 THEN
            -- 変数.異動年度 = 0 の場合
            IF SUBSTR (MJRENKEI_WORK(ICNT).IDO_BI, 5, 2) < 4 THEN
                -- 住記連携ワーク領域レコード.異動日 の月(MM) < 4 の場合
                sSQL := sSQL || SUBSTR (MJRENKEI_WORK(ICNT).IDO_BI, 1, 4) - 1 || ', ';
            ELSE
                sSQL := sSQL || SUBSTR (MJRENKEI_WORK(ICNT).IDO_BI, 1, 4) || ', ';
            END IF;
        ELSE
            sSQL := sSQL || KKAPK0020.FNENDO (g_nIDO_NENDO,2) || ', ';
        END IF;
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || g_nSHUGAKURIREKI_RIREKI_RENBAN || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKO_KBN ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
        ELSIF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || 'NULL, ';
        END IF;
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTGAKUNENRIREKI_SQL;
    --------------------------------------------------------
    --  機能概要      : 学齢簿新規SQL[減事由(新規(Insert))]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_1_1(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTGAKUREIBO ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENZON_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_NENGAPI ), 'NULL' ) || ', ';
        -- 減事由の設定
        sSQL := sSQL || FUNC_GET_GEN_JIYU_CD(ICNT) ||', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAI_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YOGOGAKO_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YUYO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.MENJO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYS_SAKUSEIBI ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHUGAKU || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.IDOJIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.CHOHYO_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUKYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SEIBETSU ), 'NULL' ) || ', ';
        sSQL := sSQL || '5, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KETTEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_SYURYOBI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHITEI_SYOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHITEI_TYUGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.HENKO_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_GAKKO_KBN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_SYOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_TYUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        -- 異動事由の設定
        sSQL := sSQL || FUNC_GET_GRB_HENKO_JIYU(ICNT) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.BIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHINSEI_KANRI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).HOGOSHA_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHOGAKKOKU_CD || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.CHUGAKKOKU_CD || ''',';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '''' || g_sSYS_TANMATU_BASHO || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_1_1;

    --------------------------------------------------------
    --  機能概要      : 学齢簿新規SQL[減事由(新規(Insert)) ※新入学児童以外]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_1_2(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTGAKUREIBO ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_NENGAPI ), 'NULL' ) || ', ';
        sSQL := sSQL || FUNC_GET_GEN_JIYU_CD(ICNT) ||', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN  = 1 THEN
            -- 住記連携ワーク領域レコード.学校区分 = 1 の場合
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN  = 2 THEN
            -- 住記連携ワーク領域レコード.学校区分 = 2 の場合
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAI_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YOGOGAKO_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YUYO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.MENJO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYS_SAKUSEIBI ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHUGAKU || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.IDOJIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.CHOHYO_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN  = 1 THEN
            -- 住記連携ワーク領域レコード.学校区分 = 1 の場合
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN  = 2 THEN
            -- 住記連携ワーク領域レコード.学校区分 = 2 の場合
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUKYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SEIBETSU ), 'NULL' ) || ', ';
        sSQL := sSQL || '5, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KETTEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_SYURYOBI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHITEI_SYOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHITEI_TYUGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.HENKO_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_GAKKO_KBN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_SYOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_TYUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || FUNC_GET_GRB_HENKO_JIYU(ICNT) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.BIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHINSEI_KANRI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).HOGOSHA_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHOGAKKOKU_CD || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.CHUGAKKOKU_CD || ''',';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '''' || g_sSYS_TANMATU_BASHO || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_1_2;

    --------------------------------------------------------
    --  機能概要      : 就学履歴[転入学を伴わない転学(新規(Insert))]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_1(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTSHUGAKURIREKI ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        IF g_nIDO_NENDO = 0 THEN
            -- 変数.異動年度 = 0 の場合
            IF SUBSTR (MJRENKEI_WORK(ICNT).IDO_BI, 5, 2) < 4 THEN
                -- 住記連携ワーク領域レコード.異動日 の月(MM) < 4 の場合
                sSQL := sSQL || SUBSTR (MJRENKEI_WORK(ICNT).IDO_BI, 1, 4) - 1 || ', ';
            ELSE
                sSQL := sSQL || SUBSTR (MJRENKEI_WORK(ICNT).IDO_BI, 1, 4) || ', ';
            END IF;
        ELSE
            sSQL := sSQL || KKAPK0020.FNENDO (g_nIDO_NENDO,2) || ', ';
        END IF;
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || g_nSHUGAKURIREKI_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        ELSIF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        ELSIF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_BU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_HUKUSEKI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_HUKUSEKI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_KAISHI_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_KAIJO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_KAISHI_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_KAIJO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE|| ''',';
        sSQL := sSQL || '''' || g_sWSNUM || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_1;

    --------------------------------------------------------
    --  機能概要      : 就学履歴[転入学を伴う転学(新規(Insert))]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_2(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTSHUGAKURIREKI ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.NENDO ), 'NULL' ) || ', ';
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || g_nSHUGAKURIREKI_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '1, ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        ELSIF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        ELSIF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_BU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_HUKUSEKI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_HUKUSEKI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_KAISHI_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_KAIJO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_KAISHI_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_KAIJO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_2;

    --------------------------------------------------------
    --  機能概要      : 就学履歴[転入学(新規(Insert))]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_3(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTSHUGAKURIREKI ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        IF g_nIDO_NENDO = 0 THEN
            -- 変数.異動年度 = 0 の場合
            IF SUBSTR (MJRENKEI_WORK(ICNT).IDO_BI, 5, 2) < 4 THEN
                -- 住記連携ワーク領域レコード.異動日 の月(MM) < 4 の場合
                sSQL := sSQL || SUBSTR (MJRENKEI_WORK(ICNT).IDO_BI, 1, 4) - 1 || ', ';
            ELSE
                sSQL := sSQL || SUBSTR (MJRENKEI_WORK(ICNT).IDO_BI, 1, 4) || ', ';
            END IF;
        ELSE
            sSQL := sSQL || KKAPK0020.FNENDO (g_nIDO_NENDO,2) || ', ';
        END IF;
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || g_nSHUGAKURIREKI_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '0, ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_NYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENNYU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TAIGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        ELSIF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_NYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENNYU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TAIGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.S_SOTSUGYO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
            sSQL := sSQL || 'NULL, ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_BU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_HUKUSEKI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_HUKUSEKI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.SHIEN_T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_KAISHI_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_S_KAIJO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_KAISHI_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUIKIGAI_T_KAIJO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_S_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENNYU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENNYU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_KAISHI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(g_rSHUGAKURIREKI.KUNISHIRITSU_T_SHURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_3;

    --------------------------------------------------------
    --  機能概要      : 学齢簿[増事由(新規(Insert))※新入学児童]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_2_1(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTGAKUREIBO ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENZON_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_NENGAPI ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO <> 0 THEN
            sSQL := sSQL || '10, ';
        ELSE
            sSQL := sSQL || '0, ';
        END IF;
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '父' THEN
            sSQL := sSQL || '4, ';
        ELSIF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '母' THEN
            sSQL := sSQL || '5, ';
        ELSE
            sSQL := sSQL || '0, ';
        END IF;
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        END IF;

        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAI_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YOGOGAKO_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YUYO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.MENJO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU10 || ''',';
        IF RGAKUREIBO.SYS_SAKUSEIBI = 0 THEN
            sSQL := sSQL || ISAKUSEIBI || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYS_SAKUSEIBI ), 'NULL' ) || ', ';
        END IF;

        IF RGAKUREIBO.SYS_KOSHINBI = 0 THEN
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || ISAKUSEIBI || ', ';
        END IF;
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHUGAKU || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.IDOJIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.CHOHYO_NO ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        END IF;

        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).SEIBETSU ), 'NULL' ) || ', ';
        sSQL := sSQL || '1, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KETTEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_SYURYOBI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.HENKO_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_GAKKO_KBN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_SYOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_TYUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || FUNC_GET_GRB_HENKO_JIYU(ICNT) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.BIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHINSEI_KANRI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).HOGOSHA_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || MJRENKEI_WORK(ICNT).JUKIATENA_SHOGAKKOKU_CD || ''',';
        sSQL := sSQL || '''' || MJRENKEI_WORK(ICNT).JUKIATENA_CHUGAKKOKU_CD || ''',';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '''' || g_sSYS_TANMATU_BASHO || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_2_1;

    --------------------------------------------------------
    --  機能概要      : 学齢簿[増事由(新規(Insert))※新入学児童以外]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_2_2(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTGAKUREIBO ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENZON_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_NENGAPI ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO <> 0 THEN
            sSQL := sSQL || '10, ';
        ELSE
            sSQL := sSQL || '0, ';
        END IF;
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '父' THEN
            sSQL := sSQL || '4, ';
        ELSIF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '母' THEN
            sSQL := sSQL || '5, ';
        ELSE
            sSQL := sSQL || '0, ';
        END IF;
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '0, ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        END IF;

        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
        ELSE
            IF MJRENKEI_WORK(ICNT).GAKO_KBN = 6 THEN
                sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
            ELSE
                sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_CD ), 'NULL' ) || ', ';
            END IF;
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAI_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YOGOGAKO_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YUYO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.MENJO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU10 || ''',';
        IF RGAKUREIBO.SYS_SAKUSEIBI = 0 THEN
            sSQL := sSQL || ISAKUSEIBI || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYS_SAKUSEIBI ), 'NULL' ) || ', ';
        END IF;

        IF RGAKUREIBO.SYS_KOSHINBI = 0 THEN
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || ISAKUSEIBI || ', ';
        END IF;
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHUGAKU || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.IDOJIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.CHOHYO_NO ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        END IF;

        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).SEIBETSU ), 'NULL' ) || ', ';
        sSQL := sSQL || '2, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KETTEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_SYURYOBI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.HENKO_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_GAKKO_KBN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_SYOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_TYUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || FUNC_GET_GRB_HENKO_JIYU(ICNT) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.BIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHINSEI_KANRI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).HOGOSHA_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || MJRENKEI_WORK(ICNT).JUKIATENA_SHOGAKKOKU_CD || ''',';
        sSQL := sSQL || '''' || MJRENKEI_WORK(ICNT).JUKIATENA_CHUGAKKOKU_CD || ''',';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '''' || g_sSYS_TANMATU_BASHO || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_2_2;

    --------------------------------------------------------
    --  機能概要      : 学齢簿新規SQL[転居・他異動(新規(Insert)) ※学校区変更なしまたは、就学指定校以外に就学中・就学予定の場合]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_1(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTGAKUREIBO ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENZON_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_NENGAPI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_NENGAPI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAI_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YOGOGAKO_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YUYO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.MENJO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYS_SAKUSEIBI ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHUGAKU || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.IDOJIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.CHOHYO_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUKYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SEIBETSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.JOTAI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KETTEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_SYURYOBI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.HENKO_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_GAKKO_KBN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_SYOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_TYUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || FUNC_GET_GRB_HENKO_JIYU(ICNT) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.BIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHINSEI_KANRI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).HOGOSHA_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || MJRENKEI_WORK(ICNT).JUKIATENA_SHOGAKKOKU_CD || ''',';
        sSQL := sSQL || '''' || MJRENKEI_WORK(ICNT).JUKIATENA_CHUGAKKOKU_CD || ''',';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '''' || g_sSYS_TANMATU_BASHO || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_1;

    --------------------------------------------------------
    --  機能概要      : 学齢簿新規SQL[転居・他異動(新規(Insert)) ※学校区変更あり かつ、新入学児童]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_2(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTGAKUREIBO ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENZON_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_NENGAPI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_NENGAPI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA4 ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_CD ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_CD ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAI_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YOGOGAKO_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YUYO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.MENJO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYS_SAKUSEIBI ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHUGAKU || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.IDOJIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.CHOHYO_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUKYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SEIBETSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.JOTAI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KETTEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_SYURYOBI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.HENKO_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_GAKKO_KBN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_SYOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_TYUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || FUNC_GET_GRB_HENKO_JIYU(ICNT) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.BIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHINSEI_KANRI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).HOGOSHA_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || MJRENKEI_WORK(ICNT).JUKIATENA_SHOGAKKOKU_CD || ''',';
        sSQL := sSQL || '''' || MJRENKEI_WORK(ICNT).JUKIATENA_CHUGAKKOKU_CD || ''',';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '''' || g_sSYS_TANMATU_BASHO || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_2;

    --------------------------------------------------------
    --  機能概要      : 学齢簿新規SQL[転居・他異動(新規(Insert)) ※学校区変更あり かつ、新入学児童以外の場合の転学]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_3(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTGAKUREIBO ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENZON_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || '1, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_NENGAPI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_NENGAPI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAI_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YOGOGAKO_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YUYO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.MENJO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYS_SAKUSEIBI ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHUGAKU || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.IDOJIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.CHOHYO_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUKYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SEIBETSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.JOTAI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KETTEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_SYURYOBI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHITEI_SYOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHITEI_TYUGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.HENKO_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_GAKKO_KBN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_SYOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_TYUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || FUNC_GET_GRB_HENKO_JIYU(ICNT) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.BIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHINSEI_KANRI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHOGAKKOKU_CD || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.CHUGAKKOKU_CD || ''',';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '''' || g_sSYS_TANMATU_BASHO || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_3;

    --------------------------------------------------------
    --  機能概要      : 学齢簿新規SQL[転居・他異動(新規(Insert)) ※学校区変更あり かつ、新入学児童以外の場合の転入学]
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : SQL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_4(ICNT IN BINARY_INTEGER) RETURN NVARCHAR2 IS
        sSQL               NVARCHAR2(32767);                -- 戻り値
    BEGIN
        sSQL := '';
        sSQL := 'INSERT INTO GKBTGAKUREIBO ';
        sSQL := sSQL || 'VALUES(';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || g_nGAKUREIBO_RIREKI_RENBAN || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENZON_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZO_NENGAPI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GEN_NENGAPI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.ZOKUGARA4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_KOJIN_NO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HOGOSYA_ZOKUGARA4 ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        END IF;

        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JIYU10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TOKUSOKU_JURI_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAI_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YOGOGAKO_SETISYA || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.YUYO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YUYO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_JIYU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.MENJO_JIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_NENSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.MENJO_FUKUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI1 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU1 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI2 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU2 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI3 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU3 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI4 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU4 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI5 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU5 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI6 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU6 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI7 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU7 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI8 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU8 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI9 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU9 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.IDO_BI10 ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.IDO_JIYU10 || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYS_SAKUSEIBI ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || NSYSTIME || ', ';
        sSQL := sSQL || '''' || g_sTANTOCODE || ''',';
        sSQL := sSQL || '''' || g_sWSNUM || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || ISAKUSEIBI || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.SHUGAKU || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.IDOJIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.CHOHYO_NO ), 'NULL' ) || ', ';
        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        END IF;

        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
            sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKUNEN_CD ), 'NULL' ) || ', ';
            sSQL := sSQL || '0, ';
        ELSE
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
            sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        END IF;
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).GAKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SEIBETSU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.JOTAI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.TENNYUMAE_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KETTEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_SYURYOBI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.GENKYURYUCHI_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_SHOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JUKIATENA_SHITEI_CHUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_GAKUNEN_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KBN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HENKO_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.HENKO_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_GAKKO_KBN_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_SYOGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_TYUGAKKO_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_FLG ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_JIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU || ''',';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.HUSHUGAKU_RIYU ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_CD ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_KAISI_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.KUNISHIRITSU_SYURYO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA || ''',';
        sSQL := sSQL || '''' || RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || FUNC_GET_GRB_HENKO_JIYU(ICNT) || ', ';
        sSQL := sSQL || '''' || RGAKUREIBO.BIKO || ''',';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).IDO_TODOKE_BI ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(RGAKUREIBO.SHINSEI_KANRI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).JIDO_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || NVL(TO_CHAR(MJRENKEI_WORK(ICNT).HOGOSHA_RIREKI_RENBAN ), 'NULL' ) || ', ';
        sSQL := sSQL || '''' || MJRENKEI_WORK(ICNT).JUKIATENA_SHOGAKKOKU_CD || ''',';
        sSQL := sSQL || '''' || MJRENKEI_WORK(ICNT).JUKIATENA_CHUGAKKOKU_CD || ''',';
        sSQL := sSQL || '0, ';
        sSQL := sSQL || '''' || g_sSYS_TANMATU_BASHO || '''';
        sSQL := sSQL || ')';
        RETURN sSQL;
    END FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_4;

    --------------------------------------------------------
    --  機能概要      : 学齢簿現最新履歴取得
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    PROCEDURE FUNC_GET_LATEST_GKBTGAKUREIBO(ICNT IN BINARY_INTEGER) IS
    BEGIN
      -- 学齢簿現最新履歴取得
        BEGIN
            SELECT *
              INTO RGAKUREIBO
              FROM GKBTGAKUREIBO
             WHERE KOJIN_NO    = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO
               AND SAISHIN_KBN = 0
               AND SAKUJO_FLG = 0;
        EXCEPTION
--  2024/09/02 ZCZL.WANGQIWEI UPDATE 0.3.030.000:フェーズ4対応
--            WHEN NO_DATA_FOUND THEN
            WHEN OTHERS THEN
                NUll;
        END;
        -- 学齢簿最新履歴番号取得
        SELECT NVL (MAX(RIREKI_RENBAN), 0)
            INTO g_nGAKUREIBO_RIREKI_RENBAN
            FROM GKBTGAKUREIBO
            WHERE KOJIN_NO    = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
    END FUNC_GET_LATEST_GKBTGAKUREIBO;

    --------------------------------------------------------
    --  機能概要      : 就学履歴現最新履歴取得
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    PROCEDURE FUNC_GET_LATEST_GKBTSHUGAKURIREKI(ICNT IN BINARY_INTEGER) IS
    BEGIN
        -- 就学履歴現最新履歴取得
        BEGIN
            SELECT *
              INTO g_rSHUGAKURIREKI
              FROM GKBTSHUGAKURIREKI
             WHERE KOJIN_NO    = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO
               AND SAISHIN_FLG = 0
               AND SAKUJO_FLG = 0;
        EXCEPTION
--  2024/09/02 ZCZL.WANGQIWEI UPDATE 0.3.030.000:フェーズ4対応
--            WHEN NO_DATA_FOUND THEN
            WHEN OTHERS THEN
                NUll;
        END;
        -- 就学最新履歴番号取得
        SELECT NVL (MAX(SHUGAKU_RIREKI_RENBAN), 0)
            INTO g_nSHUGAKURIREKI_RIREKI_RENBAN
            FROM GKBTSHUGAKURIREKI
            WHERE KOJIN_NO    = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
    END FUNC_GET_LATEST_GKBTSHUGAKURIREKI;

    --------------------------------------------------------
    --  機能概要      : 学年履歴現最新履歴取得
    --  パラメータ    :　レーコド
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    PROCEDURE FUNC_GET_LATEST_GKBTGAKUNENRIREKI(ICNT IN BINARY_INTEGER) IS
    BEGIN
        -- 学年履歴現最新履歴取得
        SELECT NVL (MAX(GAKUNEN_RIREKI_RENBAN), 0)
            INTO g_nGAKUNENRIREKI_RIREKI_RENBAN
            FROM GKBTGAKUNENRIREKI
            WHERE KOJIN_NO    = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
    END FUNC_GET_LATEST_GKBTGAKUNENRIREKI;

    --------------------------------------------------------
    --  機能概要      : ログ内容編集(最大256文字）
    --  パラメータ    : ログ内容
    --  モジュール区分: 内部関数
    --  戻り値        : ログ内容
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_GET_LOG(i_VLOG IN NVARCHAR2) RETURN NVARCHAR2
    IS
    BEGIN
        --出力するログ情報(最大256文字）
        RETURN SUBSTR( i_VLOG, 0, 256);
    END;

    --------------------------------------------------------
    --  機能概要      : 排他制御クリア
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU   2024/07/01
    --------------------------------------------------------
    PROCEDURE FUNC_GKBFKHTCLR IS
          VLOG             NVARCHAR2(256);
          bRTN             BOOLEAN;          --戻り値
    BEGIN
        IF GKBFKHTCLR(2 ,'999999999999') <> 0 THEN
            -- 処理ログの出力を行う。
            VLOG := FUNC_GET_LOG('排他解除が異常終了しました。');
--  2024/08/30 ZCZL.WANGQIWEI UPDATE 0.3.030.000:フェーズ4対応
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GKBFKHTCLR', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
        END IF;
    END FUNC_GKBFKHTCLR;
--  2024/07/01 ZCZL.YANGXINYU ADD END

    --------------------------------------------------------
    --  機能概要      : 減事由の設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_INSERT_JRENKEI_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;
        IMAX                BINARY_INTEGER;
        IMIN                BINARY_INTEGER;
        IKOSHINFLG          PLS_INTEGER;
    BEGIN
        IFRET := C_ISUCCESS;  -- 正常終了

        -- ワーク領域の最終位置を取得
        IMAX := MJRENKEI_WORK.LAST;
        -- ワーク領域の先頭位置を取得
        IMIN := MJRENKEI_WORK.FIRST;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        -- 入力場所取得
        BEGIN
            SELECT
                BUKANAME INTO g_sSYS_TANMATU_BASHO
            FROM
                KKNTBK
            WHERE
                BUKACODE = (
                    SELECT
                        BUKACODE
                    FROM
                        KKNTWS
                    WHERE
                        WSNUM = g_sWSNUM
                )
            ORDER BY
                KKNTBK.YUKOKIKANFR DESC FETCH FIRST 1 ROWS ONLY;
        EXCEPTION
--  2024/09/02 ZCZL.WANGQIWEI UPDATE 0.3.030.000:フェーズ4対応
--            WHEN NO_DATA_FOUND THEN
            WHEN OTHERS THEN
                g_sSYS_TANMATU_BASHO := '';
        END;
--  2024/07/01 ZCZL.YANGXINYU ADD END
        BEGIN
            -- ワーク領域の件数分繰り返し処理を行う
            FOR ICNT IN IMIN..IMAX LOOP
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
                -- 住記連携ワークテーブルにレコードを追加
                INSERT INTO GKBWJUKIRENKEI VALUES MJRENKEI_WORK(ICNT);
                -- 処理条件.更新区分 <> 1 の場合
                IF NKOSHIN_KBN <> 1 THEN
                    CONTINUE;
                END IF;
                -- 宛名・住記連携済み管理テーブル(GAATRENKEIATENAZUMI)から対象者の宛名番号、履歴連番が一致するデータ件数を取得する。
                SELECT COUNT(*)
                  INTO NCNT
                  FROM GAATRENKEIATENAZUMI
                 WHERE JOBID          = C_RENKEI_ID
                   AND KOJIN_NO       = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO
                   AND ZUMI_MAX_RIREI = MWORK(ICNT).RIREKI_RENBAN;

                IF NCNT <> 0 THEN
                    CONTINUE;
                END IF;
--  2024/09/02 ZCZL.WANGQIWEI DELETE START 0.3.030.000:フェーズ4対応
                -- 住記連携ワーク領域レコード.保護者相違フラグ = 1:相違あり の場合
--                 IF MJRENKEI_WORK(ICNT).HOGOSHA_SOI_FLG = 1 THEN
--                     CONTINUE;
--                 END IF;
--  2024/09/02 ZCZL.WANGQIWEI DELETE END 
                -- 現最新履歴格納用の初期化
                PROC_RGAKUREIBO_SHOKIKA;
                -- 学齢簿現最新履歴取得と学齢簿最新履歴番号取得
                FUNC_GET_LATEST_GKBTGAKUREIBO(ICNT);
                -- 就学履歴現最新履歴取得と就学最新履歴番号取得
                FUNC_GET_LATEST_GKBTSHUGAKURIREKI(ICNT);
                -- 学年履歴現最新履歴取得
                FUNC_GET_LATEST_GKBTGAKUNENRIREKI(ICNT);
                -- 住記連携ワーク領域レコード.異動区分 <> 2 かつ、変数.学齢簿最新履歴連番 = 0 の場合
                IF MWORK(ICNT).IDO_KBN <> 2 AND g_nGAKUREIBO_RIREKI_RENBAN = 0 THEN
                    CONTINUE;
                END IF;
                -- 学齢簿、就学履歴、学年履歴の更新
                CASE
                    -- 異動区分 = 1:減事由 の場合
                    WHEN MWORK(ICNT).IDO_KBN = 1 THEN
                        IF g_nSOGYOU_SHORI_FLG = 0 THEN
                            -- 変数.進級卒業処理フラグ = 0:処理前 の場合
                            IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 OR MJRENKEI_WORK(ICNT).GAKUNEN_CD = 6 THEN
                                -- 学年 が 0 または 6 の場合
                                -- ①学齢簿の現在新履歴の最新区分を変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ②学齢簿の履歴を作成する。
                                g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_1_1(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                            ELSE
                                -- 学年 が 0 または 6 以外の場合
                                -- ①学齢簿の現最新履歴の更新区分を変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ②就学履歴の現最新履歴の更新フラグを変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTSHUGAKURIREKI_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ③学齢簿の履歴を作成する。
                                VSQLSEL := '';
                                g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_1_2(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ④就学履歴の履歴を作成する。
                                g_nSHUGAKURIREKI_RIREKI_RENBAN := g_nSHUGAKURIREKI_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_1(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                            END IF;
                        ELSIF g_nSOGYOU_SHORI_FLG = 1 THEN
                            -- 変数.進級卒業処理フラグ = 1:処理後 の場合
                            IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 THEN
                                -- 学年 が 0 の場合
                                -- ①学齢簿の現最新履歴の最新区分を変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ②学理簿の履歴を作成する。
                                g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_1_1(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                            ELSE
                                --学年 が 0 以外の場合
                                -- ①学齢簿の現最新履歴の最新区分を変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ②就学履歴の現最新履歴の最新フラグを変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTSHUGAKURIREKI_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ③学齢簿の履歴を作成する。
                                VSQLSEL := '';
                                g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_1_2(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ④就学履歴の履歴を作成する。
                                g_nSHUGAKURIREKI_RIREKI_RENBAN := g_nSHUGAKURIREKI_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_1(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                            END IF;
                        ELSE
                            NULL;
                        END IF;
                    -- 異動区分 = 2:増事由 の場合
                    WHEN MWORK(ICNT).IDO_KBN = 2 THEN
                        IF g_nSOGYOU_SHORI_FLG = 0 THEN
                            -- 変数.進級卒業処理フラグ = 0:処理前 の場合
                            IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 OR MJRENKEI_WORK(ICNT).GAKUNEN_CD = 6 THEN
                                -- ①対象者の学齢簿のうち、最新区分 = 0 のデータの最新区分を変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ②学齢簿の履歴を作成する。
                                g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_2_1(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                            ELSE
                                -- 学年 が 0 または 6 以外の場合
                                -- ①対象者の学齢簿のうち、最新区分 = 0 のデータの最新区分を変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ②対象者の就学履歴のうち、最新フラグ = 0 のデータの最新フラグを変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTSHUGAKURIREKI_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ③対象者の学年履歴のうち、最新フラグ = 0 のデータの最新フラグを変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUNENRIREKI_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ④学齢簿の履歴を作成する。
                                g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_2_2(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ⑤就学履歴の履歴を作成する。
                                g_nSHUGAKURIREKI_RIREKI_RENBAN := g_nSHUGAKURIREKI_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_3(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ⑥学年履歴の履歴を作成する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUNENRIREKI_SQL(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                            END IF;
                        ELSIF g_nSOGYOU_SHORI_FLG = 1 THEN
                            -- 変数.進級卒業処理フラグ = 1:処理後 の場合
                            IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 THEN
                                -- 学年が 0 の場合
                                -- ①対象者の学齢簿のうち、最新区分 = 0 のデータの最新区分を変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ②学齢簿の履歴を作成する。
                                g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_2_1(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                            ELSE
                                -- 学年 が 0 以外の場合
                                -- ①対象者の学齢簿のうち、最新区分 = 0 のデータの最新区分を変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ②対象者の就学履歴のうち、最新フラグ = 0 のデータの最新フラグを変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTSHUGAKURIREKI_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ③対象者の学年履歴のうち、最新フラグ = 0 のデータの最新フラグを変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUNENRIREKI_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ④学齢簿の履歴を作成する。
                                g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_2_2(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ⑤就学履歴の履歴を作成する。
                                g_nSHUGAKURIREKI_RIREKI_RENBAN := g_nSHUGAKURIREKI_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_3(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ⑥学年履歴の履歴を作成する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUNENRIREKI_SQL(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                            END IF;
                        ELSE
                            NULL;
                        END IF;
                    -- 異動区分 IN (4, 5) の場合
                    WHEN MWORK(ICNT).IDO_KBN IN (4, 5) THEN
                        IF g_nSOGYOU_SHORI_FLG = 0 THEN
                            -- 変数.進級卒業処理フラグ = 0:処理前 の場合
                            IF MJRENKEI_WORK(ICNT).GAKKOKU_HENKO_FLG = 0 THEN
                                -- 変数.学校区変更フラグ = 0:変更なし の場合
                                -- ①学齢簿の現最新履歴の最新区分を変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ②学齢簿の履歴を作成する。
                                g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_1(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                            ELSIF MJRENKEI_WORK(ICNT).GAKKOKU_HENKO_FLG = 1 THEN
                                -- 変数.学校区変更フラグ = 1:変更あり の場合
                                IF MJRENKEI_WORK(ICNT).SHITEIKO_SHUGAKU_FLG = 1 THEN
                                    -- 変数.就学指定校就学フラグ = 1:就学指定校に就学中または、就学予定 の場合
                                    IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 OR MJRENKEI_WORK(ICNT).GAKUNEN_CD = 6 THEN
                                        -- 学年 が 0 または 6 の場合
                                        -- ①学齢簿の現最新履歴の最新区分を変更する。
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ②学齢簿の履歴を作成する。
                                        g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_2(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                    ELSE
                                        -- 学年 が 0 または 6 以外の場合
                                        -- ①学齢簿の現最新履歴の最新区分を変更する。
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ②就学履歴の現最新履歴の最新フラグを変更する。
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_UPDATE_GKBTSHUGAKURIREKI_SQL;
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ③学年履歴の現最新履歴の最新フラグを変更する。
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUNENRIREKI_SQL;
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ④学齢簿の転学履歴を作成する。
                                        g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_3(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ⑤就学履歴の転学履歴を作成する。
                                        g_nSHUGAKURIREKI_RIREKI_RENBAN := g_nSHUGAKURIREKI_RIREKI_RENBAN + 10;
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_2(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ⑥学齢簿の現最新履歴を再取得する。
                                        FUNC_GET_LATEST_GKBTGAKUREIBO(ICNT);
                                        -- ⑦学年履歴の現最新履歴を再取得する。
                                        FUNC_GET_LATEST_GKBTGAKUNENRIREKI(ICNT);
                                        -- ⑧学齢簿の転入学履歴を作成する。
                                        g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_4(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ⑨就学履歴の転入学履歴を作成する。
                                        g_nSHUGAKURIREKI_RIREKI_RENBAN := g_nSHUGAKURIREKI_RIREKI_RENBAN + 10;
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_3(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ⑩学年履歴の転入学履歴を作成する。
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTGAKUNENRIREKI_SQL(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                    END IF;
                                ELSIF MJRENKEI_WORK(ICNT).SHITEIKO_SHUGAKU_FLG = 0 THEN
                                    -- 変数.就学指定校就学フラグ = 0:就学指定校以外に就学予定または、就学予定 の場合
                                    -- ①学齢簿の現最新履歴の最新区分を変更する。
                                    VSQLSEL := '';
                                    VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                    EXECUTE IMMEDIATE VSQLSEL;
                                    -- ②学齢簿の履歴を作成する。
                                    g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                    VSQLSEL := '';
                                    VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_1(ICNT);
                                    EXECUTE IMMEDIATE VSQLSEL;
                                ELSE
                                    NULL;
                                END IF;
                            ELSE
                                NULL;
                            END IF;
                        ELSIF g_nSOGYOU_SHORI_FLG = 1 THEN
                            -- 変数.進級卒業処理フラグ = 1:処理後
                            IF MJRENKEI_WORK(ICNT).GAKKOKU_HENKO_FLG = 0 THEN
                                -- 変数.学校区変更フラグ = 0:変更なし の場合
                                -- ①学齢簿の現最新履歴の最新区分を変更する。
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                EXECUTE IMMEDIATE VSQLSEL;
                                -- ②学齢簿の履歴を作成する。
                                g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                VSQLSEL := '';
                                VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_1(ICNT);
                                EXECUTE IMMEDIATE VSQLSEL;
                            ELSIF MJRENKEI_WORK(ICNT).GAKKOKU_HENKO_FLG = 1 THEN
                                -- 変数.学校区変更フラグ = 1:変更あり の場合
                                IF MJRENKEI_WORK(ICNT).SHITEIKO_SHUGAKU_FLG = 1 THEN
                                    -- 変数.就学指定校フラグ = 1:就学指定校に就学中または、就学予定 の場合
                                    IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 THEN
                                        -- 学年 が 0 の場合
                                        -- ①学齢簿の現最新履歴の最新区分を変更する。
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ②学齢簿の履歴を作成する。
                                        g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_2(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                    ELSE
                                        -- 学年 が 0 以外の場合
                                        -- ①学齢簿の現最新履歴の最新区分を変更する。
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ②就学履歴の現最新履歴の最新フラグを変更する。
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_UPDATE_GKBTSHUGAKURIREKI_SQL;
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ③学年履歴の現最新履歴の最新フラグを変更する。
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUNENRIREKI_SQL;
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ④学齢簿の転学履歴を作成する。
                                        g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_3(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ⑤就学履歴の転学履歴を作成する。
                                        g_nSHUGAKURIREKI_RIREKI_RENBAN := g_nSHUGAKURIREKI_RIREKI_RENBAN + 10;
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_2(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ⑥学齢簿の現最新履歴を再取得する。
                                        FUNC_GET_LATEST_GKBTGAKUREIBO(ICNT);
                                        -- ⑦学年履歴の現最新履歴を再取得する。
                                        FUNC_GET_LATEST_GKBTGAKUNENRIREKI(ICNT);
                                        -- ⑧学齢簿の転入学履歴を作成する。
                                        g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_4(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ⑨就学履歴の転入学履歴を作成する。
                                        g_nSHUGAKURIREKI_RIREKI_RENBAN := g_nSHUGAKURIREKI_RIREKI_RENBAN + 10;
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTSHUGAKURIREKI_SQL_3(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                        -- ⑩学年履歴の転入学履歴を作成する。
                                        VSQLSEL := '';
                                        VSQLSEL := FUNC_GET_INSERT_GKBTGAKUNENRIREKI_SQL(ICNT);
                                        EXECUTE IMMEDIATE VSQLSEL;
                                    END IF;
                                ELSIF MJRENKEI_WORK(ICNT).SHITEIKO_SHUGAKU_FLG = 0 THEN
                                    -- 変数.就学指定校フラグ = 0:就学指定校以外に就学中または、就学予定 の場合
                                    -- ①学齢簿の現最新履歴の最新区分を変更する。
                                    VSQLSEL := '';
                                    VSQLSEL := FUNC_GET_UPDATE_GKBTGAKUREIBO_SQL;
                                    EXECUTE IMMEDIATE VSQLSEL;
                                    -- ②学齢簿の履歴を作成する。
                                    g_nGAKUREIBO_RIREKI_RENBAN := g_nGAKUREIBO_RIREKI_RENBAN + 10;
                                    VSQLSEL := '';
                                    VSQLSEL := FUNC_GET_INSERT_GKBTGAKUREIBO_SQL_3_1(ICNT);
                                    EXECUTE IMMEDIATE VSQLSEL;
                                ELSE
                                    NULL;
                                END IF;
                            ELSE
                                NULL;
                            END IF;
                        ELSE
                            NULL;
                        END IF;
                    ELSE
                        NULL;
                END CASE;

                -- 学年リンクデータの削除および、更新処理
                -- 新入学児童で異動区分=1の減異動の場合
                IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 AND MWORK(ICNT).IDO_KBN = 1 THEN
                    -- 学年リンクデータの削除
                    DELETE FROM GKBTGAKUNENLNK
                        WHERE KOJIN_NO = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
                ELSE
                    -- 学年リンクテーブルの更新
                    IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 OR MWORK(ICNT).IDO_KBN = 2 THEN
                        -- 登録件数のカウント
                        SELECT COUNT(*)
                            INTO NCNT
                            FROM GKBTGAKUNENLNK
                            WHERE KOJIN_NO = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;

                        -- データが存在しない場合は追加
                        IF NCNT = 0 THEN
                            INSERT INTO GKBTGAKUNENLNK
                                (KOJIN_NO,
                                    GAKUNEN_CD,
                                    SYS_SAKUSEIBI,
                                    SYS_KOSHINBI,
                                    SYS_JIKAN,
                                    SYS_SHOKUINKOJIN_NO,
                                    SYS_TANMATU_NO)
                            VALUES
                                (MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO,
                                    NNENREI - 6,
                                    ISAKUSEIBI,
                                    0,
                                    NSYSTIME,
                                    g_sTANTOCODE,
                                    g_sWSNUM);
                        -- データが存在する場合は更新
                        ELSE
                            UPDATE GKBTGAKUNENLNK
                                SET GAKUNEN_CD          = NNENREI - 6,
                                    SYS_KOSHINBI        = ISAKUSEIBI,
                                    SYS_JIKAN           = NSYSTIME,
                                    SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                    SYS_TANMATU_NO      = g_sWSNUM
                                WHERE KOJIN_NO =MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
                        END IF;
                    END IF;
                END IF;

                -- 宛名連携テーブルの更新
                -- 登録件数のカウント
                SELECT COUNT(*)
                    INTO NCNT
                    FROM GAATRENKEIATENAZUMI
                    WHERE JOBID  = C_RENKEI_ID
                    AND KOJIN_NO   = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;

                -- データが存在しない場合は追加
                IF NCNT = 0 THEN
                    INSERT INTO GAATRENKEIATENAZUMI
                        (
                            JOBID,
                            KOJIN_NO,
                            ZUMI_MAX_RIREI,
                            GENZON_KBN)
                    VALUES
                        (
                            C_RENKEI_ID,
                            MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO,
                            MWORK(ICNT).RIREKI_RENBAN,
                            MWORK(ICNT).GENZON_KBN);
                -- データが存在する場合は更新
                ELSE
                    UPDATE GAATRENKEIATENAZUMI
                        SET ZUMI_MAX_RIREI = MWORK(ICNT).RIREKI_RENBAN,
                            GENZON_KBN     = MWORK(ICNT).GENZON_KBN
                        WHERE  JOBID     = C_RENKEI_ID
                        AND KOJIN_NO   = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
                END IF;
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
--  2024/07/01 ZCZL.YANGXINYU DELETE START 0.3.000.000:新WizLIFE２次開発
--                -- 住記異動連携中間テーブルに追加
--                INSERT INTO GKBWJUKIRENKEI VALUES MJRENKEI_WORK(ICNT);
--
--                -- 学齢簿更新区分=1の時、学齢簿テーブル、学年リンクテーブル、宛名連携テーブルを更新する
--                IF NKOSHIN_KBN = 1 THEN
--                    -- 年齢再設定
--                    IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                        NNENREI := MJRENKEI_WORK(ICNT).GAKUNEN_CD + 6;
--                    ELSE
--                        NNENREI := MJRENKEI_WORK(ICNT).GAKUNEN_CD + 12;
--                    END IF;
--
--                    -- 履歴番号で連携済みか判断
--                    SELECT COUNT(*)
--                      INTO NCNT
--                      FROM GAATRENKEIATENAZUMI
--                     WHERE JOBID          = C_RENKEI_ID
--                       AND KOJIN_NO       = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO
--                       AND ZUMI_MAX_RIREI = MWORK(ICNT).RIREKI_RENBAN;
--
--                    -- 宛名連携済みの場合は学齢簿を更新しない（件数が0件の場合は更新）
--                    IF NCNT = 0 THEN
--                        -- 学齢簿テーブルの更新
--                        IKOSHINFLG := 1;
--                        -- 学齢簿現最新履歴データ格納用の初期化
--                        PROC_RGAKUREIBO_SHOKIKA;
--                        -- 現最新履歴レコードを取得
--                        BEGIN
--                            SELECT *
--                              INTO RGAKUREIBO
--                              FROM GKBTGAKUREIBO
--                             WHERE KOJIN_NO    = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO
--                               AND SAISHIN_KBN = 0;
--                        EXCEPTION
--                            WHEN NO_DATA_FOUND THEN
--                                RGAKUREIBO.KOJIN_NO := MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
--                                RGAKUREIBO.RIREKI_RENBAN := 0;
--                                IKOSHINFLG := 0;
--                        END;
--
--                        -- 現最新任意ビットレコードを取得.
--                        BEGIN
--                            SELECT *
--                              INTO RNINIBIT
--                              FROM GKBTNINIBIT
--                             WHERE KOJIN_NO     = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO
--                               AND RIREKI_RENBAN = RGAKUREIBO.RIREKI_RENBAN;
--                        EXCEPTION
--                            WHEN NO_DATA_FOUND THEN
--                                RNINIBIT.KOJIN_NO := MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
--                                RNINIBIT.RIREKI_RENBAN := 0;
--                        END;
--                        -- INSERT用にセット
--                        NGAK_RIREKI_RENBAN := RGAKUREIBO.RIREKI_RENBAN + 10;
--                        NGAK_NENREI := NNENREI - 6;
--
--                        -- 新入学児童の場合
--                        IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 THEN
--                            -- 異動区分で処理を分岐
--                            CASE
--                                -- 異動区分=1(転出等)
--                                WHEN MWORK(ICNT).IDO_KBN = 1 THEN
--                                    --１ 変数.新入学児童削除方法=1の場合
--                                    IF I_SYSTEM_HAU = 1 THEN
--                                      VSQLSEL := '';
--                                      VSQLSEL := ' UPDATE GKBTGAKUREIBO ';
--                                      VSQLSEL := VSQLSEL || ' SET GKBTGAKUREIBO.GENZON_KBN = 1,';
--                                      VSQLSEL := VSQLSEL || ' GKBTGAKUREIBO.GEN_JIYU_CD ='|| MJRENKEI_WORK(ICNT).IDO_JIYU ||',';
--                                      VSQLSEL := VSQLSEL || ' GKBTGAKUREIBO.GEN_NENGAPI = GKBTGAKUREIBO.SYOGAKO_NYUGAKU_BI,';
--                                      VSQLSEL := VSQLSEL || ' GKBTGAKUREIBO.SYS_KOSHINBI = '|| ISAKUSEIBI ||',';
--                                      VSQLSEL := VSQLSEL || ' GKBTGAKUREIBO.SYS_JIKAN = '||NSYSTIME||',';
--                                      VSQLSEL := VSQLSEL || ' GKBTGAKUREIBO.SYS_SHOKUINKOJIN_NO = '''||g_sTANTOCODE||''',';
--                                      VSQLSEL := VSQLSEL || ' GKBTGAKUREIBO.SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                      VSQLSEL := VSQLSEL || ' GKBTGAKUREIBO.SHORIBI = '||ISAKUSEIBI;
--                                      VSQLSEL := VSQLSEL || ' WHERE GKBTGAKUREIBO.KOJIN_NO = '|| RGAKUREIBO.KOJIN_NO ;
--                                      VSQLSEL := VSQLSEL || ' AND GKBTGAKUREIBO.RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN ;
--                                      EXECUTE IMMEDIATE VSQLSEL;
--                                    --変数.新入学児童削除方法<>1の場合
--                                    ELSE
--                                    -- 学齢簿データの削除
--                                    DELETE FROM GKBTGAKUREIBO
--                                     WHERE KOJIN_NO = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
--                                    END IF;
--                                    DELETE FROM GKBTNINIBIT
--                                     WHERE KOJIN_NO = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
--                                -- 異動区分=2(転入等)、3(転出取消)
--                                WHEN MWORK(ICNT).IDO_KBN IN (2, 3) THEN
--                                    IF RGAKUREIBO.RIREKI_RENBAN > 0 THEN
--                                        VSQLSEL := '';
--                                        VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                        VSQLSEL := VSQLSEL || 'SET ';
--                                        VSQLSEL := VSQLSEL || 'SYOGAKO_CD = ' || MJRENKEI_WORK(ICNT).GAKOKU_CD || ', ';
--                                        VSQLSEL := VSQLSEL || 'GEN_JIYU_CD = 0, ';
--                                        VSQLSEL := VSQLSEL || 'GEN_NENGAPI = 0, ';
--                                        VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                        VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                        VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                        VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                        VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                        VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                        VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                        EXECUTE IMMEDIATE VSQLSEL;
--                                    ELSE
--                                        -- 最新レコードの追加･･･「新入学児童学齢簿作成処理」で作成される学齢簿データを参考に設定
--                                        VSQLSEL := '';
--                                        VSQLSEL := 'INSERT INTO GKBTGAKUREIBO ';
--                                        VSQLSEL := VSQLSEL || 'VALUES(';
--                                        VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO || ', ';
--                                        VSQLSEL := VSQLSEL || NGAK_RIREKI_RENBAN || ', ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || NNYUGAKU_BI || ', ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        IF MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO <> 0 THEN
--                                            VSQLSEL := VSQLSEL || '10, ';
--                                        ELSE
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                        END IF;
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO || ', ';
--                                        IF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '父' THEN
--                                            VSQLSEL := VSQLSEL || '4, ';
--                                        ELSIF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '母' THEN
--                                            VSQLSEL := VSQLSEL || '5, ';
--                                        ELSE
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                        END IF;
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).GAKOKU_CD || ', ';
--                                        VSQLSEL := VSQLSEL || NNYUGAKU_BI || ', ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || NSYSTIME || ', ';
--                                        VSQLSEL := VSQLSEL || '''' || g_sTANTOCODE || ''', ';
--                                        VSQLSEL := VSQLSEL || '''' || g_sWSNUM || ''', ';
--                                        VSQLSEL := VSQLSEL || NGAK_NENREI || ', ';
--                                        VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || 'NULL, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, '; -- 学校区分コード
--                                        VSQLSEL := VSQLSEL || '0)';  -- 学級コード
--                                        EXECUTE IMMEDIATE VSQLSEL;
--
--                                        -- 任意ビットの登録
--                                        IF RNINIBIT.RIREKI_RENBAN = 0 THEN
--                                            VSQLSEL := '';
--                                            VSQLSEL := 'INSERT INTO GKBTNINIBIT ';
--                                            VSQLSEL := VSQLSEL || 'VALUES(';
--                                            VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO || ', ';    -- KOJIN_NO
--                                            VSQLSEL := VSQLSEL || NGAK_RIREKI_RENBAN || ', ';                   -- RIREKI_RENBAN
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT1
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT2
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT3
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT4
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT5
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT6
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT7
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT8
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT9
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT10
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT11
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT12
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT13
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT14
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT15
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT16
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT17
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT18
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT19
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT20
--                                            VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';                           -- SYS_SAKUSEIBI
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- SYS_KOSHINBI
--                                            VSQLSEL := VSQLSEL || NSYSTIME || ', ';                             -- SYS_JIKAN
--                                            VSQLSEL := VSQLSEL || '''' || g_sTANTOCODE || ''', ';              -- SYS_SHOKUINKOJIN_NO
--                                            VSQLSEL := VSQLSEL || '''' || g_sWSNUM || ''') ';             -- SYS_TANMATU_NO
--                                            EXECUTE IMMEDIATE VSQLSEL;
--                                        END IF;
--                                    END IF;
--                                -- 異動区分=4(転居)、5(他異動)
--                                WHEN MWORK(ICNT).IDO_KBN IN (4, 5) THEN
--                                    -- 異動種別で処理を分岐
--                                    CASE
--                                        WHEN MWORK(ICNT).IDO_SHUBETSU = 1 THEN
--                                            -- 現最新履歴レコードの更新
--                                            IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                                VSQLSEL := '';
--                                                VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                                VSQLSEL := VSQLSEL || 'SET ';
--                                                VSQLSEL := VSQLSEL || 'SYOGAKO_CD = ' || MJRENKEI_WORK(ICNT).GAKOKU_CD || ', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                                VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                                VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                                VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                                EXECUTE IMMEDIATE VSQLSEL;
--                                            END IF;
--                                        WHEN MWORK(ICNT).IDO_SHUBETSU IN (2, 3, 4) THEN
--                                            -- IDO_BI1～10で未使用の項目を検索
--                                            IF NVL(RGAKUREIBO.IDO_BI1, 0) = 0 THEN
--                                                NNUM := 1;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI2, 0) = 0 THEN
--                                                NNUM := 2;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI3, 0) = 0 THEN
--                                                NNUM := 3;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI4, 0) = 0 THEN
--                                                NNUM := 4;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI5, 0) = 0 THEN
--                                                NNUM := 5;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI6, 0) = 0 THEN
--                                                NNUM := 6;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI7, 0) = 0 THEN
--                                                NNUM := 7;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI8, 0) = 0 THEN
--                                                NNUM := 8;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI9, 0) = 0 THEN
--                                                NNUM := 9;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI10, 0) = 0 THEN
--                                                NNUM := 10;
--                                            ELSE
--                                                NNUM := 11;
--                                            END IF;
--
--                                            IF NNUM > 10 THEN
--                                                -- IDO_BI10まで使用されている場合、未セット
--                                                NULL;
--                                            ELSIF NNUM = 10 THEN
--                                                -- 現最新履歴レコードの更新
--                                                IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                                    VSQLSEL := '';
--                                                    VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                                    VSQLSEL := VSQLSEL || 'SET ';
--                                                    VSQLSEL := VSQLSEL || 'IDO_BI10 = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                    IF MWORK(ICNT).IDO_SHUBETSU = 3 THEN
--                                                        VSQLSEL := VSQLSEL || 'IDO_JIYU10 = ''' || C_IDO_JIYU_3 || MJRENKEI_WORK(ICNT).JIDO_KYU_SHIMEI_KANJI || ''', ';
--                                                    ELSE
--                                                        VSQLSEL := VSQLSEL || 'IDO_JIYU10 = ''' || C_IDO_JIYU_2 || MJRENKEI_WORK(ICNT).HOGOSHA_KYU_SHIMEI_KANJI || ''', ';
--                                                    END IF;
--                                                    VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                                    VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                                    VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                                    VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                                    VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                                    VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                                    VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                                    EXECUTE IMMEDIATE VSQLSEL;
--                                                END IF;
--                                            ELSE
--                                                -- 項目名のセット
--                                                VIDO_BI_NAME        := 'IDO_BI'   || TO_CHAR(NNUM);
--                                                VIDO_JIYU_NAME      := 'IDO_JIYU' || TO_CHAR(NNUM);
--                                                VIDO_BI_NAME_NEXT   := 'IDO_BI'   || TO_CHAR(NNUM + 1);
--                                                VIDO_JIYU_NAME_NEXT := 'IDO_JIYU' || TO_CHAR(NNUM + 1);
--
--                                                IF MWORK(ICNT).IDO_SHUBETSU IN (2, 3) THEN
--                                                    -- 現最新履歴レコードの更新
--                                                    IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                                        VSQLSEL := '';
--                                                        VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                                        VSQLSEL := VSQLSEL || 'SET ';
--                                                        VSQLSEL := VSQLSEL || VIDO_BI_NAME || ' = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                        IF MWORK(ICNT).IDO_SHUBETSU = 3 THEN
--                                                            VSQLSEL := VSQLSEL || VIDO_JIYU_NAME || ' = ''' || C_IDO_JIYU_3 || MJRENKEI_WORK(ICNT).HOGOSHA_KYU_SHIMEI_KANJI || ''', ';
--                                                        ELSE
--                                                            VSQLSEL := VSQLSEL || VIDO_JIYU_NAME || ' = ''' || C_IDO_JIYU_2 || MJRENKEI_WORK(ICNT).JIDO_KYU_SHIMEI_KANJI || ''', ';
--                                                        END IF;
--                                                        VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                                        VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                                        VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                                        VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                                        EXECUTE IMMEDIATE VSQLSEL;
--                                                    END IF;
--                                                ELSE
--                                                    -- 現最新履歴レコードの更新
--                                                    IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                                        VSQLSEL := '';
--                                                        VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                                        VSQLSEL := VSQLSEL || 'SET ';
--                                                        VSQLSEL := VSQLSEL || VIDO_BI_NAME || ' = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                        VSQLSEL := VSQLSEL || VIDO_BI_NAME_NEXT || ' = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                        VSQLSEL := VSQLSEL || VIDO_JIYU_NAME || ' = ''' || C_IDO_JIYU_2 || MJRENKEI_WORK(ICNT).JIDO_KYU_SHIMEI_KANJI || ''', ';
--                                                        VSQLSEL := VSQLSEL || VIDO_JIYU_NAME_NEXT || ' = ''' || C_IDO_JIYU_3 || MJRENKEI_WORK(ICNT).HOGOSHA_KYU_SHIMEI_KANJI || ''', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                                        VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                                        VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                                        VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                                        EXECUTE IMMEDIATE VSQLSEL;
--                                                    END IF;
--                                                END IF;
--                                            END IF;
--                                        WHEN MWORK(ICNT).IDO_SHUBETSU IN (5, 6) THEN
--                                            -- 現最新履歴レコードの更新
--                                            IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                                VSQLSEL := '';
--                                                VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                                VSQLSEL := VSQLSEL || 'SET ';
--                                                IF MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO <> 0 THEN
--                                                    VSQLSEL := VSQLSEL || 'ZOKUGARA1 = 10, ';
--                                                ELSE
--                                                    VSQLSEL := VSQLSEL || 'ZOKUGARA1 = 0, ';
--                                                END IF;
--                                                VSQLSEL := VSQLSEL || 'HOGOSYA_KOJIN_NO = ' || MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO || ', ';
--                                                IF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '父' THEN
--                                                    VSQLSEL := VSQLSEL || 'HOGOSYA_ZOKUGARA1 = 4, ';
--                                                ELSIF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '母' THEN
--                                                    VSQLSEL := VSQLSEL || 'HOGOSYA_ZOKUGARA1 = 5, ';
--                                                ELSE
--                                                    VSQLSEL := VSQLSEL || 'HOGOSYA_ZOKUGARA1 = 0, ';
--                                                END IF;
--                                                IF MWORK(ICNT).IDO_SHUBETSU = 6 THEN
--                                                    VSQLSEL := VSQLSEL || 'SYOGAKO_CD = ' || MJRENKEI_WORK(ICNT).GAKOKU_CD || ', ';
--                                                END IF;
--                                                VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                                VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                                VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                                VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                                EXECUTE IMMEDIATE VSQLSEL;
--                                            END IF;
--                                        ELSE
--                                            NULL;
--                                    END CASE;
--                            ELSE
--                                NULL;
--                            END CASE;
--                        ELSE
--                            -- 新入学児童以外の場合
--                            -- 新履歴作成判断
--                            IF IKOSHINFLG = 1 THEN
--                                -- 在籍判断
--                                IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                    IF NOT ((RGAKUREIBO.SYOGAKO_NYUGAKU_BI > 0 OR RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI > 0) AND RGAKUREIBO.SYOGAKO_TENGAKU_BI = 0 AND RGAKUREIBO.SYOGAKO_SOTSUGYO_BI = 0) THEN
--                                        -- 最新履歴で小学校に在籍していない場合、異動区分=1(転出等)、異動区分=4(転居)、5(他異動)の処理を行わない。
--                                        IF MWORK(ICNT).IDO_KBN <> 3 THEN
--                                            IKOSHINFLG := 0;
--                                        ELSE
--                                            -- 最新履歴で小学校に在籍していない場合、かつ区域外、特別支援に在籍している場合は、異動区分=3(転出取消)の処理を行わない。
--                                            IF ((RGAKUREIBO.KUIKIGAI_NYUGAKU_BI > 0 OR RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI > 0) AND RGAKUREIBO.KUIKIGAI_TENGAKU_BI = 0 AND RGAKUREIBO.KUIKIGAI_TAIGAKU_BI = 0 AND RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI = 0) OR
--                                               ((RGAKUREIBO.YOGOGAKO_NYUGAKU_BI > 0 OR RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI > 0) AND RGAKUREIBO.YOGOGAKO_TENGAKU_BI = 0 AND RGAKUREIBO.YOGOGAKO_TAIGAKU_BI = 0 AND RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI = 0) THEN
--                                               IKOSHINFLG := 0;
--                                            END IF;
--                                        END IF;
--                                    END IF;
--                                ELSIF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                    IF NOT ((RGAKUREIBO.TYUGAKO_NYUGAKU_BI > 0 OR RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI > 0) AND RGAKUREIBO.TYUGAKO_TENGAKU_BI = 0 AND RGAKUREIBO.TYUGAKO_SOTSUGYO_BI = 0) THEN
--                                        -- 最新履歴で中学校に在籍していない場合、異動区分=1(転出等)、異動区分=4(転居)、5(他異動)の処理を行わない。
--                                        IF MWORK(ICNT).IDO_KBN <> 3 THEN
--                                            IKOSHINFLG := 0;
--                                        ELSE
--                                            -- 最新履歴で小学校に在籍していない場合、かつ区域外、特別支援に在籍している場合は、異動区分=3(転出取消)の処理を行わない。
--                                            IF ((RGAKUREIBO.KUIKIGAI_NYUGAKU_BI > 0 OR RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI > 0) AND RGAKUREIBO.KUIKIGAI_TENGAKU_BI = 0 AND RGAKUREIBO.KUIKIGAI_TAIGAKU_BI = 0 AND RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI = 0) OR
--                                               ((RGAKUREIBO.YOGOGAKO_NYUGAKU_BI > 0 OR RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI > 0) AND RGAKUREIBO.YOGOGAKO_TENGAKU_BI = 0 AND RGAKUREIBO.YOGOGAKO_TAIGAKU_BI = 0 AND RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI = 0) THEN
--                                               IKOSHINFLG := 0;
--                                            END IF;
--                                        END IF;
--                                    END IF;
--                                END IF;
--                            END IF;
--
--                            -- 異動区分で処理を分岐
--                            CASE
--                                -- 異動区分=1(転出等)
--                                WHEN MWORK(ICNT).IDO_KBN = 1 AND IKOSHINFLG = 1 THEN
--                                    -- 現最新履歴レコードの更新
--                                    IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                        VSQLSEL := '';
--                                        VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                        VSQLSEL := VSQLSEL || 'SET ';
--                                        VSQLSEL := VSQLSEL || 'GENZON_KBN = 1, ';
--                                        VSQLSEL := VSQLSEL || 'GEN_JIYU_CD = ' || MJRENKEI_WORK(ICNT).IDO_JIYU || ', ';
--                                        VSQLSEL := VSQLSEL || 'GEN_NENGAPI = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                            VSQLSEL := VSQLSEL || 'SYOGAKO_TENGAKU_BI = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                            VSQLSEL := VSQLSEL || 'SYOGAKO_TENGAKU_GAKUNEN = ' || (NNENREI - 6) || ', ';
--                                        ELSIF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                            VSQLSEL := VSQLSEL || 'TYUGAKO_TENGAKU_BI = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                            VSQLSEL := VSQLSEL || 'TYUGAKO_TENGAKU_GAKUNEN = ' || (NNENREI - 12) || ', ';
--                                        END IF;
--                                        VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                        VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                        VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                        VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                        VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                        VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                        VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                        EXECUTE IMMEDIATE VSQLSEL;
--                                    END IF;
--
--                                -- 異動区分=2(転入等)
--                                WHEN MWORK(ICNT).IDO_KBN = 2 THEN
--                                    -- 最新レコードの追加
--                                    VSQLSEL := '';
--                                    VSQLSEL := 'INSERT INTO GKBTGAKUREIBO ';
--                                    VSQLSEL := VSQLSEL || 'VALUES(';
--                                    VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO || ', ';
--                                    VSQLSEL := VSQLSEL || NGAK_RIREKI_RENBAN || ', ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).IDO_JIYU || ', ';
--                                    VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    IF MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO <> 0 THEN
--                                        VSQLSEL := VSQLSEL || '10, ';
--                                    ELSE
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                    END IF;
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO || ', ';
--                                    IF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '父' THEN
--                                        VSQLSEL := VSQLSEL || '4, ';
--                                    ELSIF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '母' THEN
--                                        VSQLSEL := VSQLSEL || '5, ';
--                                    ELSE
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                    END IF;
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                        VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).GAKOKU_CD || ', ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                    ELSE
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                    END IF;
--                                    IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                        VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).GAKOKU_CD || ', ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                    ELSE
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                    END IF;
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || NSYSTIME || ', ';
--                                    VSQLSEL := VSQLSEL || '''' || g_sTANTOCODE || ''', ';
--                                    VSQLSEL := VSQLSEL || '''' || g_sWSNUM || ''', ';
--                                    VSQLSEL := VSQLSEL || NGAK_NENREI || ', ';
--                                    VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || 'NULL, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                        VSQLSEL := VSQLSEL || (NNENREI - 6) || ', ';
--                                    ELSE
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                    END IF;
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                        VSQLSEL := VSQLSEL || (NNENREI - 12) || ', ';
--                                    ELSE
--                                        VSQLSEL := VSQLSEL || '0, ';
--                                    END IF;
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || '0, ';
--                                    VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).GAKO_KBN ||', '; -- 学校区分コード
--                                    VSQLSEL := VSQLSEL || '0)';                                -- 学級コード
--                                    EXECUTE IMMEDIATE VSQLSEL;
--
--                                    -- 任意ビットの登録
--                                    IF RNINIBIT.RIREKI_RENBAN = 0 THEN
--                                        VSQLSEL := '';
--                                        VSQLSEL := 'INSERT INTO GKBTNINIBIT ';
--                                        VSQLSEL := VSQLSEL || 'VALUES(';
--                                        VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO || ', ';    -- KOJIN_NO
--                                        VSQLSEL := VSQLSEL || NGAK_RIREKI_RENBAN || ', ';                   -- RIREKI_RENBAN
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT1
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT2
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT3
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT4
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT5
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT6
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT7
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT8
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT9
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT10
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT11
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT12
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT13
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT14
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT15
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT16
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT17
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT18
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT19
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- NINIBIT20
--                                        VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';                           -- SYS_SAKUSEIBI
--                                        VSQLSEL := VSQLSEL || '0, ';                                        -- SYS_KOSHINBI
--                                        VSQLSEL := VSQLSEL || NSYSTIME || ', ';                             -- SYS_JIKAN
--                                        VSQLSEL := VSQLSEL || '''' || g_sTANTOCODE || ''', ';              -- SYS_SHOKUINKOJIN_NO
--                                        VSQLSEL := VSQLSEL || '''' || g_sWSNUM || ''') ';             -- SYS_TANMATU_NO
--                                        EXECUTE IMMEDIATE VSQLSEL;
--                                    END IF;
--
--                                    -- 現最新履歴レコードの更新
--                                    IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                        UPDATE GKBTGAKUREIBO
--                                           SET SAISHIN_KBN         = 1,
--                                               SYS_KOSHINBI        = ISAKUSEIBI,
--                                               SYS_JIKAN           = NSYSTIME,
--                                               SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                               SYS_TANMATU_NO      = g_sWSNUM,
--                                               SHORIBI             = ISAKUSEIBI
--                                         WHERE KOJIN_NO      = RGAKUREIBO.KOJIN_NO
--                                           AND RIREKI_RENBAN = RGAKUREIBO.RIREKI_RENBAN;
--                                    END IF;
--
--                                -- 異動区分=3(転出取消)
--                                WHEN MWORK(ICNT).IDO_KBN = 3 AND IKOSHINFLG = 1 THEN
--                                    -- 現最新履歴レコードの更新
--                                    IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                        VSQLSEL := '';
--                                        VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                        VSQLSEL := VSQLSEL || 'SET ';
--                                        VSQLSEL := VSQLSEL || 'GENZON_KBN = 0, ';
--                                        VSQLSEL := VSQLSEL || 'GEN_JIYU_CD = 0, ';
--                                        VSQLSEL := VSQLSEL || 'GEN_NENGAPI = 0, ';
--                                        IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                            VSQLSEL := VSQLSEL || 'SYOGAKO_TENGAKU_BI = 0, ';
--                                            VSQLSEL := VSQLSEL || 'SYOGAKO_TENGAKU_GAKUNEN = 0, ';
--                                        ELSIF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                            VSQLSEL := VSQLSEL || 'TYUGAKO_TENGAKU_BI = 0, ';
--                                            VSQLSEL := VSQLSEL || 'TYUGAKO_TENGAKU_GAKUNEN = 0, ';
--                                        END IF;
--                                        VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                        VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                        VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                        VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                        VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                        VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                        VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                        EXECUTE IMMEDIATE VSQLSEL;
--                                    END IF;
--
--                                -- 異動区分=4(転居)、5(他異動)
--                                WHEN MWORK(ICNT).IDO_KBN IN (4, 5) AND IKOSHINFLG = 1 THEN
--                                    -- 異動種別で処理を分岐
--                                    CASE
--                                        WHEN MWORK(ICNT).IDO_SHUBETSU = 1 THEN
--                                            -- 最新レコードの追加
--                                            VSQLSEL := '';
--                                            VSQLSEL := 'INSERT INTO GKBTGAKUREIBO ';
--                                            VSQLSEL := VSQLSEL || 'VALUES(';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KOJIN_NO || ', ';
--                                            VSQLSEL := VSQLSEL || NGAK_RIREKI_RENBAN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.GENZON_KBN || ', ';
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.ZO_JIYU_CD || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.ZO_NENGAPI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.GEN_JIYU_CD || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.GEN_NENGAPI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.ZOKUGARA1 || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.ZOKUGARA2 || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.ZOKUGARA3 || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.ZOKUGARA4 || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.HOGOSYA_KOJIN_NO || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.HOGOSYA_ZOKUGARA1 || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.HOGOSYA_ZOKUGARA2 || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.HOGOSYA_ZOKUGARA3 || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.HOGOSYA_ZOKUGARA4 || ', ';
--                                            IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                                VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).GAKOKU_CD || ', ';
--                                                VSQLSEL := VSQLSEL || '0, ';
--                                                VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_TENGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_SOTSUGYO_BI || ', ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_CD || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_NYUGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_TENGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_SOTSUGYO_BI || ', ';
--                                            END IF;
--                                            IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                                VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).GAKOKU_CD || ', ';
--                                                VSQLSEL := VSQLSEL || '0, ';
--                                                VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_TENGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_SOTSUGYO_BI || ', ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_CD || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_NYUGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_TENGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_SOTSUGYO_BI || ', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TOKUSOKU_BI1 || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TOKUSOKU_BI2 || ', ';
--                                            IF RGAKUREIBO.TOKUSOKU_NAIYO1 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO1 || ''', ';
--                                            END IF;
--                                            IF RGAKUREIBO.TOKUSOKU_NAIYO2 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO2 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TOKUSOKU_BI3 || ', ';
--                                            IF RGAKUREIBO.TOKUSOKU_NAIYO3 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO3 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TOKUSOKU_BI4 || ', ';
--                                            IF RGAKUREIBO.TOKUSOKU_NAIYO4 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO4 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TOKUSOKU_BI5 || ', ';
--                                            IF RGAKUREIBO.TOKUSOKU_NAIYO5 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO5 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_CD || ', ';
--                                            IF RGAKUREIBO.KUIKIGAI_SETISYA IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.KUIKIGAI_SETISYA || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_NYUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TENGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TAIGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_CD || ', ';
--                                            IF RGAKUREIBO.YOGOGAKO_SETISYA IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.YOGOGAKO_SETISYA || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_NYUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TENGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TAIGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YUYO_KYOKA_BI || ', ';
--                                            IF RGAKUREIBO.YUYO_JIYU IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.YUYO_JIYU || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YUYO_KAISI_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YUYO_SYURYO_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YUYO_FUKUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.MENJO_KYOKA_BI || ', ';
--                                            IF RGAKUREIBO.MENJO_JIYU IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.MENJO_JIYU || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.MENJO_FUKUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI1 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU1 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU1 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI2 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU2 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU2 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI3 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU3 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU3 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI4 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU4 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU4 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI5 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU5 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU5 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI6 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU6 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU6 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI7 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU7 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU7 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI8 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU8 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU8 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI9 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU9 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU9 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI10 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU10 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU10 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                            VSQLSEL := VSQLSEL || NSYSTIME || ', ';
--                                            VSQLSEL := VSQLSEL || g_sTANTOCODE || ', ';
--                                            VSQLSEL := VSQLSEL || '''' || g_sWSNUM || ''', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';
--                                            IF RGAKUREIBO.SHUGAKU IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.SHUGAKU || ''', ';
--                                            END IF;
--                                            IF RGAKUREIBO.IDOJIKO IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDOJIKO || ''', ';
--                                            END IF;
--                                            IF RGAKUREIBO.CHOHYO_NO IS NULL THEN
--                                                VSQLSEL := VSQLSEL || '0, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.CHOHYO_NO || ', ';
--                                            END IF;
--                                            IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                                VSQLSEL := VSQLSEL || (NNENREI - 6) || ', ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN || ', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN || ', ';
--                                            IF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                                VSQLSEL := VSQLSEL || (NNENREI - 12) || ', ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN || ', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).GAKO_KBN ||', '; -- 学校区分コード
--                                            VSQLSEL := VSQLSEL || '0)';                                -- 学級コード
--                                            EXECUTE IMMEDIATE VSQLSEL;
--
--                                            -- 任意ビットの登録
--                                            IF RNINIBIT.RIREKI_RENBAN = 0 THEN
--                                                VSQLSEL := '';
--                                                VSQLSEL := 'INSERT INTO GKBTNINIBIT ';
--                                                VSQLSEL := VSQLSEL || 'VALUES(';
--                                                VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO || ', ';    -- KOJIN_NO
--                                                VSQLSEL := VSQLSEL || NGAK_RIREKI_RENBAN || ', ';                   -- RIREKI_RENBAN
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT1 || ', ';                    -- NINIBIT1
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT2 || ', ';                    -- NINIBIT2
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT3 || ', ';                    -- NINIBIT3
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT4 || ', ';                    -- NINIBIT4
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT5 || ', ';                    -- NINIBIT5
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT6 || ', ';                    -- NINIBIT6
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT7 || ', ';                    -- NINIBIT7
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT8 || ', ';                    -- NINIBIT8
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT9 || ', ';                    -- NINIBIT9
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT10 || ', ';                   -- NINIBIT10
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT11 || ', ';                   -- NINIBIT11
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT12 || ', ';                   -- NINIBIT12
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT13 || ', ';                   -- NINIBIT13
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT14 || ', ';                   -- NINIBIT14
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT15 || ', ';                   -- NINIBIT15
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT16 || ', ';                   -- NINIBIT16
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT17 || ', ';                   -- NINIBIT17
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT18 || ', ';                   -- NINIBIT18
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT19 || ', ';                   -- NINIBIT19
--                                                VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT20 || ', ';                   -- NINIBIT20
--                                                VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';                           -- SYS_SAKUSEIBI
--                                                VSQLSEL := VSQLSEL || '0, ';                                        -- SYS_KOSHINBI
--                                                VSQLSEL := VSQLSEL || NSYSTIME || ', ';                             -- SYS_JIKAN
--                                                VSQLSEL := VSQLSEL || '''' || g_sTANTOCODE || ''', ';              -- SYS_SHOKUINKOJIN_NO
--                                                VSQLSEL := VSQLSEL || '''' || g_sWSNUM || ''') ';             -- SYS_TANMATU_NO
--                                                EXECUTE IMMEDIATE VSQLSEL;
--                                            END IF;
--
--                                            -- 現最新履歴レコードの更新
--                                            IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                                VSQLSEL := '';
--                                                VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                                VSQLSEL := VSQLSEL || 'SET ';
--                                                VSQLSEL := VSQLSEL || 'SAISHIN_KBN = 1, ';
--                                                IF MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                                    VSQLSEL := VSQLSEL || 'SYOGAKO_TENGAKU_BI = ' || KKAPK0020.FDATECAL(MJRENKEI_WORK(ICNT).IDO_BI,0,-1,0,0) || ', ';
--                                                    VSQLSEL := VSQLSEL || 'SYOGAKO_TENGAKU_GAKUNEN = ' || (NNENREI - 6) || ', ';
--                                                ELSIF MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                                    VSQLSEL := VSQLSEL || 'TYUGAKO_TENGAKU_BI = ' || KKAPK0020.FDATECAL(MJRENKEI_WORK(ICNT).IDO_BI,0,-1,0,0) || ', ';
--                                                    VSQLSEL := VSQLSEL || 'TYUGAKO_TENGAKU_GAKUNEN = ' || (NNENREI - 12) || ', ';
--                                                END IF;
--                                                IF  MWORK(ICNT).IDO_KBN = 4 THEN
--                                                    VSQLSEL := VSQLSEL || 'GEN_JIYU_CD = ' || MJRENKEI_WORK(ICNT).IDO_JIYU || ', ';
--                                                    VSQLSEL := VSQLSEL || 'GEN_NENGAPI = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                END IF;
--                                                VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                                VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                                VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                                VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                                EXECUTE IMMEDIATE VSQLSEL;
--                                            END IF;
--
--                                        WHEN MWORK(ICNT).IDO_SHUBETSU IN (2, 3, 4) THEN
--                                            -- IDO_BI1～10で未使用の項目を検索
--                                            IF NVL(RGAKUREIBO.IDO_BI1, 0) = 0 THEN
--                                                NNUM := 1;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI2, 0) = 0 THEN
--                                                NNUM := 2;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI3, 0) = 0 THEN
--                                                NNUM := 3;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI4, 0) = 0 THEN
--                                                NNUM := 4;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI5, 0) = 0 THEN
--                                                NNUM := 5;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI6, 0) = 0 THEN
--                                                NNUM := 6;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI7, 0) = 0 THEN
--                                                NNUM := 7;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI8, 0) = 0 THEN
--                                                NNUM := 8;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI9, 0) = 0 THEN
--                                                NNUM := 9;
--                                            ELSIF NVL(RGAKUREIBO.IDO_BI10, 0) = 0 THEN
--                                                NNUM := 10;
--                                            ELSE
--                                                NNUM := 11;
--                                            END IF;
--
--                                            IF NNUM > 10 THEN
--                                                -- IDO_BI10まで使用されている場合、未セット
--                                                NULL;
--                                            ELSIF NNUM = 10 THEN
--                                                -- 現最新履歴レコードの更新
--                                                IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                                    VSQLSEL := '';
--                                                    VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                                    VSQLSEL := VSQLSEL || 'SET ';
--                                                    VSQLSEL := VSQLSEL || 'IDO_BI10 = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                    IF MWORK(ICNT).IDO_SHUBETSU = 3 THEN
--                                                        VSQLSEL := VSQLSEL || 'IDO_JIYU10 = ''' || C_IDO_JIYU_3 || MJRENKEI_WORK(ICNT).JIDO_KYU_SHIMEI_KANJI || ''', ';
--                                                    ELSE
--                                                        VSQLSEL := VSQLSEL || 'IDO_JIYU10 = ''' || C_IDO_JIYU_2 || MJRENKEI_WORK(ICNT).HOGOSHA_KYU_SHIMEI_KANJI || ''', ';
--                                                    END IF;
--                                                    VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                                    VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                                    VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                                    VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                                    VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                                    VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                                    VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                                    EXECUTE IMMEDIATE VSQLSEL;
--                                                END IF;
--                                            ELSE
--                                                -- 項目名のセット
--                                                VIDO_BI_NAME        := 'IDO_BI'   || TO_CHAR(NNUM);
--                                                VIDO_JIYU_NAME      := 'IDO_JIYU' || TO_CHAR(NNUM);
--                                                VIDO_BI_NAME_NEXT   := 'IDO_BI'   || TO_CHAR(NNUM + 1);
--                                                VIDO_JIYU_NAME_NEXT := 'IDO_JIYU' || TO_CHAR(NNUM + 1);
--
--                                                IF MWORK(ICNT).IDO_SHUBETSU IN (2, 3) THEN
--                                                    -- 現最新履歴レコードの更新
--                                                    IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                                        VSQLSEL := '';
--                                                        VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                                        VSQLSEL := VSQLSEL || 'SET ';
--                                                        VSQLSEL := VSQLSEL || VIDO_BI_NAME || ' = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                        IF MWORK(ICNT).IDO_SHUBETSU = 3 THEN
--                                                            VSQLSEL := VSQLSEL || VIDO_JIYU_NAME || ' = ''' || C_IDO_JIYU_3 || MJRENKEI_WORK(ICNT).HOGOSHA_KYU_SHIMEI_KANJI || ''', ';
--                                                        ELSE
--                                                            VSQLSEL := VSQLSEL || VIDO_JIYU_NAME || ' = ''' || C_IDO_JIYU_2 || MJRENKEI_WORK(ICNT).JIDO_KYU_SHIMEI_KANJI || ''', ';
--                                                        END IF;
--                                                        VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                                        VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                                        VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                                        VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                                        EXECUTE IMMEDIATE VSQLSEL;
--                                                    END IF;
--                                                ELSE
--                                                    -- 現最新履歴レコードの更新
--                                                    IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                                        VSQLSEL := '';
--                                                        VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                                        VSQLSEL := VSQLSEL || 'SET ';
--                                                        VSQLSEL := VSQLSEL || VIDO_BI_NAME || ' = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                        VSQLSEL := VSQLSEL || VIDO_BI_NAME_NEXT || ' = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                        VSQLSEL := VSQLSEL || VIDO_JIYU_NAME || ' = ''' || C_IDO_JIYU_2 || MJRENKEI_WORK(ICNT).JIDO_KYU_SHIMEI_KANJI || ''', ';
--                                                        VSQLSEL := VSQLSEL || VIDO_JIYU_NAME_NEXT || ' = ''' || C_IDO_JIYU_3 || MJRENKEI_WORK(ICNT).HOGOSHA_KYU_SHIMEI_KANJI || ''', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                                        VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                                        VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                                        VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                                        VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                                        EXECUTE IMMEDIATE VSQLSEL;
--                                                    END IF;
--                                                END IF;
--                                            END IF;
--
--                                        WHEN MWORK(ICNT).IDO_SHUBETSU IN (5, 6) THEN
--                                            -- 最新レコードの追加
--                                            VSQLSEL := '';
--                                            VSQLSEL := 'INSERT INTO GKBTGAKUREIBO ';
--                                            VSQLSEL := VSQLSEL || 'VALUES(';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KOJIN_NO || ', ';
--                                            VSQLSEL := VSQLSEL || NGAK_RIREKI_RENBAN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.GENZON_KBN || ', ';
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.ZO_JIYU_CD || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.ZO_NENGAPI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.GEN_JIYU_CD || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.GEN_NENGAPI || ', ';
--                                            IF MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO <> 0 THEN
--                                                VSQLSEL := VSQLSEL || '10, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '0, ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                            VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).HOGOSHA_KOJIN_NO || ', ';
--                                            IF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '父' THEN
--                                                VSQLSEL := VSQLSEL || '4, ';
--                                            ELSIF MJRENKEI_WORK(ICNT).ZOKUGARAMEI2 = '母' THEN
--                                                VSQLSEL := VSQLSEL || '5, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '0, ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                            IF  MWORK(ICNT).IDO_SHUBETSU = 6 AND MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                                VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).GAKOKU_CD || ', ';
--                                                VSQLSEL := VSQLSEL || '0, ';
--                                                VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_TENGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_SOTSUGYO_BI || ', ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_CD || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_NYUGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_TENGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_SOTSUGYO_BI || ', ';
--                                            END IF;
--                                            IF  MWORK(ICNT).IDO_SHUBETSU = 6 AND MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                                VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).GAKOKU_CD || ', ';
--                                                VSQLSEL := VSQLSEL || '0, ';
--                                                VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_TENGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_SOTSUGYO_BI || ', ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_CD || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_NYUGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_TENGAKU_BI || ', ';
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_SOTSUGYO_BI || ', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TOKUSOKU_BI1 || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TOKUSOKU_BI2 || ', ';
--                                            IF RGAKUREIBO.TOKUSOKU_NAIYO1 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO1 || ''', ';
--                                            END IF;
--                                            IF RGAKUREIBO.TOKUSOKU_NAIYO2 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO2 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TOKUSOKU_BI3 || ', ';
--                                            IF RGAKUREIBO.TOKUSOKU_NAIYO3 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO3 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TOKUSOKU_BI4 || ', ';
--                                            IF RGAKUREIBO.TOKUSOKU_NAIYO4 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO4 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TOKUSOKU_BI5 || ', ';
--                                            IF RGAKUREIBO.TOKUSOKU_NAIYO5 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.TOKUSOKU_NAIYO5 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_CD || ', ';
--                                            IF RGAKUREIBO.KUIKIGAI_SETISYA IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.KUIKIGAI_SETISYA || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_NYUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TENGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TAIGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_CD || ', ';
--                                            IF RGAKUREIBO.YOGOGAKO_SETISYA IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.YOGOGAKO_SETISYA || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_NYUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TENGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TAIGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YUYO_KYOKA_BI || ', ';
--                                            IF RGAKUREIBO.YUYO_JIYU IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.YUYO_JIYU || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YUYO_KAISI_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YUYO_SYURYO_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YUYO_FUKUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.MENJO_KYOKA_BI || ', ';
--                                            IF RGAKUREIBO.MENJO_JIYU IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.MENJO_JIYU || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.MENJO_FUKUGAKU_BI || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI1 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU1 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU1 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI2 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU2 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU2 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI3 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU3 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU3 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI4 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU4 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU4 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI5 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU5 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU5 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI6 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU6 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU6 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI7 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU7 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU7 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI8 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU8 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU8 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI9 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU9 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU9 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.IDO_BI10 || ', ';
--                                            IF RGAKUREIBO.IDO_JIYU10 IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDO_JIYU10 || ''', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';
--                                            VSQLSEL := VSQLSEL || '0, ';
--                                            VSQLSEL := VSQLSEL || NSYSTIME || ', ';
--                                            VSQLSEL := VSQLSEL || g_sTANTOCODE || ', ';
--                                            VSQLSEL := VSQLSEL || '''' || g_sWSNUM || ''', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';
--                                            IF RGAKUREIBO.SHUGAKU IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.SHUGAKU || ''', ';
--                                            END IF;
--                                            IF RGAKUREIBO.IDOJIKO IS NULL THEN
--                                                VSQLSEL := VSQLSEL || 'NULL, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || '''' || RGAKUREIBO.IDOJIKO || ''', ';
--                                            END IF;
--                                            IF RGAKUREIBO.CHOHYO_NO IS NULL THEN
--                                                VSQLSEL := VSQLSEL || '0, ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.CHOHYO_NO || ', ';
--                                            END IF;
--                                            IF MWORK(ICNT).IDO_SHUBETSU = 6 AND MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                                VSQLSEL := VSQLSEL || (NNENREI - 6) || ', ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN || ', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN || ', ';
--                                            IF MWORK(ICNT).IDO_SHUBETSU = 6 AND MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                                VSQLSEL := VSQLSEL || (NNENREI - 12) || ', ';
--                                            ELSE
--                                                VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN || ', ';
--                                            END IF;
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN || ', ';
--                                            VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).GAKO_KBN ||', '; -- 学校区分コード
--                                            VSQLSEL := VSQLSEL || '0)';                                -- 学級コード
--                                            EXECUTE IMMEDIATE VSQLSEL;
--
--                                            -- 任意ビットの登録
--                                            VSQLSEL := '';
--                                            VSQLSEL := 'INSERT INTO GKBTNINIBIT ';
--                                            VSQLSEL := VSQLSEL || 'VALUES(';
--                                            VSQLSEL := VSQLSEL || MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO || ', ';    -- KOJIN_NO
--                                            VSQLSEL := VSQLSEL || NGAK_RIREKI_RENBAN || ', ';                   -- RIREKI_RENBAN
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT1 || ', ';                    -- NINIBIT1
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT2 || ', ';                    -- NINIBIT2
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT3 || ', ';                    -- NINIBIT3
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT4 || ', ';                    -- NINIBIT4
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT5 || ', ';                    -- NINIBIT5
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT6 || ', ';                    -- NINIBIT6
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT7 || ', ';                    -- NINIBIT7
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT8 || ', ';                    -- NINIBIT8
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT9 || ', ';                    -- NINIBIT9
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT10 || ', ';                   -- NINIBIT10
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT11 || ', ';                   -- NINIBIT11
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT12 || ', ';                   -- NINIBIT12
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT13 || ', ';                   -- NINIBIT13
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT14 || ', ';                   -- NINIBIT14
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT15 || ', ';                   -- NINIBIT15
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT16 || ', ';                   -- NINIBIT16
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT17 || ', ';                   -- NINIBIT17
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT18 || ', ';                   -- NINIBIT18
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT19 || ', ';                   -- NINIBIT19
--                                            VSQLSEL := VSQLSEL || RNINIBIT.NINIBIT20 || ', ';                   -- NINIBIT20
--                                            VSQLSEL := VSQLSEL || ISAKUSEIBI || ', ';                           -- SYS_SAKUSEIBI
--                                            VSQLSEL := VSQLSEL || '0, ';                                        -- SYS_KOSHINBI
--                                            VSQLSEL := VSQLSEL || NSYSTIME || ', ';                             -- SYS_JIKAN
--                                            VSQLSEL := VSQLSEL || '''' || g_sTANTOCODE || ''', ';              -- SYS_SHOKUINKOJIN_NO
--                                            VSQLSEL := VSQLSEL || '''' || g_sWSNUM || ''') ';             -- SYS_TANMATU_NO
--                                            EXECUTE IMMEDIATE VSQLSEL;
--
--                                            -- 現最新履歴レコードの更新
--                                            IF RGAKUREIBO.RIREKI_RENBAN <> 0 THEN
--                                                VSQLSEL := '';
--                                                VSQLSEL := 'UPDATE GKBTGAKUREIBO ';
--                                                VSQLSEL := VSQLSEL || 'SET ';
--                                                VSQLSEL := VSQLSEL || 'SAISHIN_KBN = 1, ';
--                                                IF MWORK(ICNT).IDO_SHUBETSU = 6 AND MJRENKEI_WORK(ICNT).GAKO_KBN = 1 THEN
--                                                    VSQLSEL := VSQLSEL || 'SYOGAKO_TENGAKU_BI = ' || KKAPK0020.FDATECAL(MJRENKEI_WORK(ICNT).IDO_BI,0,-1,0,0) || ', ';
--                                                    VSQLSEL := VSQLSEL || 'SYOGAKO_TENGAKU_GAKUNEN = ' || (NNENREI - 6) || ', ';
--                                                ELSIF MWORK(ICNT).IDO_SHUBETSU = 6 AND MJRENKEI_WORK(ICNT).GAKO_KBN = 2 THEN
--                                                    VSQLSEL := VSQLSEL || 'TYUGAKO_TENGAKU_BI = ' || KKAPK0020.FDATECAL(MJRENKEI_WORK(ICNT).IDO_BI,0,-1,0,0) || ', ';
--                                                    VSQLSEL := VSQLSEL || 'TYUGAKO_TENGAKU_GAKUNEN = ' || (NNENREI - 12) || ', ';
--                                                END IF;
--                                                IF MWORK(ICNT).IDO_SHUBETSU = 6 THEN
--                                                    VSQLSEL := VSQLSEL || 'GEN_JIYU_CD = ' || MJRENKEI_WORK(ICNT).IDO_JIYU || ', ';
--                                                    VSQLSEL := VSQLSEL || 'GEN_NENGAPI = ' || MJRENKEI_WORK(ICNT).IDO_BI || ', ';
--                                                END IF;
--                                                VSQLSEL := VSQLSEL || 'SYS_KOSHINBI = ' || ISAKUSEIBI || ', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_JIKAN = ' || NSYSTIME || ', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''', ';
--                                                VSQLSEL := VSQLSEL || 'SYS_TANMATU_NO = ''' || g_sWSNUM || ''', ';
--                                                VSQLSEL := VSQLSEL || 'SHORIBI = ' || ISAKUSEIBI || ' ';
--                                                VSQLSEL := VSQLSEL || 'WHERE KOJIN_NO = ' || RGAKUREIBO.KOJIN_NO || ' ';
--                                                VSQLSEL := VSQLSEL || 'AND RIREKI_RENBAN = ' || RGAKUREIBO.RIREKI_RENBAN;
--                                                EXECUTE IMMEDIATE VSQLSEL;
--                                            END IF;
--                                    ELSE
--                                        NULL;
--                                    END CASE;
--                                ELSE
--                                    NULL;
--                            END CASE;
--                        END IF;
--                        -- 新入学児童で異動区分=1の減異動の場合
--                        IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 AND MWORK(ICNT).IDO_KBN = 1 THEN
--                            -- 学年リンクデータの削除
--                            DELETE FROM GKBTGAKUNENLNK
--                             WHERE KOJIN_NO = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
--                        ELSE
--                            -- 学年リンクテーブルの更新
--                            IF MJRENKEI_WORK(ICNT).GAKUNEN_CD = 0 OR MWORK(ICNT).IDO_KBN = 2 OR IKOSHINFLG = 1 THEN
--                                -- 登録件数のカウント
--                                SELECT COUNT(*)
--                                  INTO NCNT
--                                  FROM GKBTGAKUNENLNK
--                                 WHERE KOJIN_NO = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
--
--                                -- データが存在しない場合は追加
--                                IF NCNT = 0 THEN
--                                    INSERT INTO GKBTGAKUNENLNK
--                                        (KOJIN_NO,
--                                         GAKUNEN_CD,
--                                         SYS_SAKUSEIBI,
--                                         SYS_KOSHINBI,
--                                         SYS_JIKAN,
--                                         SYS_SHOKUINKOJIN_NO,
--                                         SYS_TANMATU_NO)
--                                    VALUES
--                                        (MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO,
--                                         NNENREI - 6,
--                                         ISAKUSEIBI,
--                                         0,
--                                         NSYSTIME,
--                                         g_sTANTOCODE,
--                                         g_sWSNUM);
--                                -- データが存在する場合は更新
--                                ELSE
--                                    UPDATE GKBTGAKUNENLNK
--                                       SET GAKUNEN_CD          = NNENREI - 6,
--                                           SYS_KOSHINBI        = ISAKUSEIBI,
--                                           SYS_JIKAN           = NSYSTIME,
--                                           SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                           SYS_TANMATU_NO      = g_sWSNUM
--                                     WHERE KOJIN_NO =MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
--                                END IF;
--                        END IF;
--                    END IF;
--
--                    -- 宛名連携テーブルの更新
--                    -- 登録件数のカウント
--                    SELECT COUNT(*)
--                      INTO NCNT
--                      FROM GAATRENKEIATENAZUMI
--                     WHERE JOBID  = C_RENKEI_ID
--                       AND KOJIN_NO   = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
--
--                    -- データが存在しない場合は追加
--                    IF NCNT = 0 THEN
--                        INSERT INTO GAATRENKEIATENAZUMI
--                            (
--                             JOBID,
--                             KOJIN_NO,
--                             ZUMI_MAX_RIREI,
--                             GENZON_KBN)
--                        VALUES
--                            (
--                             C_RENKEI_ID,
--                             MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO,
--                             MWORK(ICNT).RIREKI_RENBAN,
--                             MWORK(ICNT).GENZON_KBN);
--                    -- データが存在する場合は更新
--                    ELSE
--                        UPDATE GAATRENKEIATENAZUMI
--                           SET ZUMI_MAX_RIREI = MWORK(ICNT).RIREKI_RENBAN,
--                               GENZON_KBN     = MWORK(ICNT).GENZON_KBN
--                         WHERE  JOBID     = C_RENKEI_ID
--                           AND KOJIN_NO   = MJRENKEI_WORK(ICNT).JIDO_KOJIN_NO;
--                    END IF;
--                  END IF;
--                END IF;
--  2024/07/01 ZCZL.YANGXINYU DELETE END
            END LOOP;
            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;       -- 処理前に戻す
                IFRET := C_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);

        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;       -- 処理前に戻す
            IFRET := C_INOT_SUCCESS;  -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        RETURN IFRET;
    END FUNC_INSERT_JRENKEI_WK;
--  2024/09/02 ZCZL.WANGQIWEI ADD START 0.3.030.000:フェーズ4対応
    --------------------------------------------------------
    --  機能概要      : 保護者のみ異動する児童生徒分の住記連携ワーク(GKCWJUKIRENKEI)テーブルの作成および学齢簿テーブルの更新
    --  パラメータ      : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.030.000
    --  作成者／作成日: ZCZL.WANGQIWEI   2024/09/02
    --------------------------------------------------------
    FUNCTION FUNC_INSERT_JUKIRENKEI_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        VSQLSE              NVARCHAR2(30000);           -- ＳＱＬ文
        IBRTN               NUMBER;
        o_VZOKUGARAMEI      NVARCHAR2(50);              -- 続柄
        o_IHERR             BINARY_INTEGER;             -- 続柄コード
        ------------------------------------------------------------------------------
        --  カーソル定義
        ------------------------------------------------------------------------------
        TYPE MC_CURSOR IS REF CURSOR;
        cCURSOR            MC_CURSOR;
        -- テーブル定義
        rTGAKUREIBO      GKBTGAKUREIBO%ROWTYPE;
        rWJUKIRENKEI     GKBWJUKIRENKEI%ROWTYPE;
        vSYOGAKOMEI        NVARCHAR2(1000);
        n_ZUMICOUNT         NUMBER;
        n_ZUMICOUNT_1       NUMBER;
        sBUKACODE           NVARCHAR2(63);             --部課コード(BUKACODE)
        -- レコード
        TYPE ENKEIATENA_REC IS RECORD(
            JIDO_KOJIN_NO         NUMBER,
            JIDO_SHIMEI_KANA      GABVATENAALL_B.SHIMEI_KANA%TYPE,
            JIDO_SHIMEI_KANJI     GABVATENAALL_B.SHIMEI_KANJI%TYPE,
            SEINENGAPI            GABVATENAALL_B.SEINENGAPI%TYPE,
            SEIBETSU              GABVATENAALL_B.SEIBETSU%TYPE,
            ZOKUGARACD1           GABVATENAALL_B.ZOKUGARA_CD1%TYPE,
            ZOKUGARACD2           GABVATENAALL_B.ZOKUGARA_CD2%TYPE,
            ZOKUGARACD3           GABVATENAALL_B.ZOKUGARA_CD3%TYPE,
            ZOKUGARACD4           GABVATENAALL_B.ZOKUGARA_CD4%TYPE,
            JINKAKU_KBN           GABVATENAALL_B.JINKAKU_KBN%TYPE,
            SETAI_NO              GABVATENAALL_B.SETAI_NO%TYPE,
            HOGOSHA_KOJIN_NO      GAAVRENKEIATENA.KOJIN_NO%TYPE,
            HOGOSHA_SHIMEI_KANA   GAAVRENKEIATENA.SHIMEI_KANA%TYPE,
            HOGOSHA_SHIMEI_KANJI  GAAVRENKEIATENA.SHIMEI_KANJI%TYPE,
            HOGOSHA_SEIBETSU      GAAVRENKEIATENA.SEIBETSU%TYPE,
            HOGOSHA_ZOKUGARACD1   GAAVRENKEIATENA.ZOKUGARA_CD1%TYPE,
            HOGOSHA_ZOKUGARACD2   GAAVRENKEIATENA.ZOKUGARA_CD2%TYPE,
            HOGOSHA_ZOKUGARACD3   GAAVRENKEIATENA.ZOKUGARA_CD3%TYPE,
            HOGOSHA_ZOKUGARACD4   GAAVRENKEIATENA.ZOKUGARA_CD4%TYPE,
            IDO_BI                GAAVRENKEIATENA.IDO_BI%TYPE,
            IDO_TODOKE_BI         GAAVRENKEIATENA.IDO_TODOKE_BI%TYPE,
            IDO_JIYU              GAAVRENKEIATENA.IDO_JIYU%TYPE,
            GAKO_KBN              GKBTGAKUREIBO.GAKKO_KBN_CD%TYPE,
            GAKUNEN_CD            GKBTGAKUREIBO.GAKUNEN%TYPE,
            SHUGAKUSHITEI_SHO     GKBTGAKUREIBO.SHITEI_SYOGAKO_CD%TYPE,
            SHUGAKUSHITEI_CHU     GKBTGAKUREIBO.SHITEI_TYUGAKO_CD%TYPE,
            GYOSEIKU_CD           GABVATENAALL_B.GYOSEIKU_CD%TYPE,
            SANTEIDANTAI_CD       GABVATENAALL_B.SANTEIDANTAI_CD%TYPE,
            JUSHO                 NVARCHAR2(1000),
            SHORIBI_KEY           GAAVRENKEIATENA.SHORIBI_KEY%TYPE,
            SHORI_JIKAN_KEY       GAAVRENKEIATENA.SHORI_JIKAN_KEY%TYPE,
            SHORI_KBN_KEY         GAAVRENKEIATENA.SHORI_KBN_KEY%TYPE,
            ZENBU_ICHIBU_KEY      GAAVRENKEIATENA.ZENBU_ICHIBU_KEY%TYPE,
            KISAI_JUNI            GAAVRENKEIATENA.KISAI_JUNI%TYPE,
            JIDO_RIREKI_RENBAN    GABVATENAALL_B.RIREKI_RENBAN%TYPE,
            HOGOSHA_RIREKI_RENBAN NUMBER,
            GENZON_KBN            GAAVRENKEIATENA.GENZON_KBN%TYPE
        );
        rENKEIATENA_REC       ENKEIATENA_REC;
    BEGIN
        VSQLSE := '';
        VSQLSE := VSQLSE || ' SELECT                                                                                ';
        VSQLSE := VSQLSE || '  A.JIDO_KOJIN_NO AS JIDO_KOJIN_NO                                                     ';
        VSQLSE := VSQLSE || ', GVB.SHIMEI_KANA AS JIDO_SHIMEI_KANA                                                  ';
        VSQLSE := VSQLSE || ', GVB.SHIMEI_KANJI AS JIDO_SHIMEI_KANJI                                                ';
        VSQLSE := VSQLSE || ', GVB.SEINENGAPI AS SEINENGAPI                                                         ';
        VSQLSE := VSQLSE || ', GVB.SEIBETSU AS SEIBETSU                                                             ';
        VSQLSE := VSQLSE || ', GVB.ZOKUGARA_CD1 AS ZOKUGARACD1                                                      ';
        VSQLSE := VSQLSE || ', GVB.ZOKUGARA_CD2 AS ZOKUGARACD2                                                      ';
        VSQLSE := VSQLSE || ', GVB.ZOKUGARA_CD3 AS ZOKUGARACD3                                                      ';
        VSQLSE := VSQLSE || ', GVB.ZOKUGARA_CD4 AS ZOKUGARACD4                                                      ';
        VSQLSE := VSQLSE || ', GVB.JINKAKU_KBN AS JINKAKU_KBN                                                       ';
        VSQLSE := VSQLSE || ', GVB.SETAI_NO AS SETAI_NO                                                             ';
        VSQLSE := VSQLSE || ', GA.KOJIN_NO AS HOGOSHA_KOJIN_NO                                                      ';
        VSQLSE := VSQLSE || ', GA.SHIMEI_KANA AS HOGOSHA_SHIMEI_KANA                                                ';
        VSQLSE := VSQLSE || ', GA.SHIMEI_KANJI AS HOGOSHA_SHIMEI_KANJI                                              ';
        VSQLSE := VSQLSE || ', GA.SEIBETSU AS HOGOSHA_SEIBETSU                                                      ';
        VSQLSE := VSQLSE || ', GA.ZOKUGARA_CD1 AS HOGOSHA_ZOKUGARACD1                                               ';
        VSQLSE := VSQLSE || ', GA.ZOKUGARA_CD2 AS HOGOSHA_ZOKUGARACD2                                               ';
        VSQLSE := VSQLSE || ', GA.ZOKUGARA_CD3 AS HOGOSHA_ZOKUGARACD3                                               ';
        VSQLSE := VSQLSE || ', GA.ZOKUGARA_CD4 AS HOGOSHA_ZOKUGARACD4                                               ';
        VSQLSE := VSQLSE || ', GA.IDO_BI AS IDO_BI                                                                  ';
        VSQLSE := VSQLSE || ', GA.IDO_TODOKE_BI AS IDO_TODOKE_BI                                                    ';
        VSQLSE := VSQLSE || ', GA.IDO_JIYU AS IDO_JIYU                                                              ';
        VSQLSE := VSQLSE || ', GBO.GAKKO_KBN_CD AS GAKO_KBN                                                         ';
        VSQLSE := VSQLSE || ', GBO.GAKUNEN AS GAKUNEN_CD                                                            ';
        VSQLSE := VSQLSE || ', GBO.SHITEI_SYOGAKO_CD AS SHUGAKUSHITEI_SHO                                           ';
        VSQLSE := VSQLSE || ', GBO.SHITEI_TYUGAKO_CD AS SHUGAKUSHITEI_CHU                                           ';
        VSQLSE := VSQLSE || ', GVB.GYOSEIKU_CD AS GYOSEIKU_CD                                                       ';
        VSQLSE := VSQLSE || ', GVB.SANTEIDANTAI_CD AS SANTEIDANTAI_CD                                               ';
        VSQLSE := VSQLSE || ', GVB.CHOMEI || GVB.BANCHI ||''　''|| GVB.KATAGAKI AS JUSHO                             ';
        VSQLSE := VSQLSE || ', GA.SHORIBI_KEY AS SHORIBI_KEY                                                        ';
        VSQLSE := VSQLSE || ', GA.SHORI_JIKAN_KEY AS SHORI_JIKAN_KEY                                                ';
        VSQLSE := VSQLSE || ', GA.SHORI_KBN_KEY AS SHORI_KBN_KEY                                                    ';
        VSQLSE := VSQLSE || ', GA.ZENBU_ICHIBU_KEY AS ZENBU_ICHIBU_KEY                                              ';
        VSQLSE := VSQLSE || ', GA.KISAI_JUNI AS KISAI_JUNI                                                          ';
        VSQLSE := VSQLSE || ', GVB.RIREKI_RENBAN AS JIDO_RIREKI_RENBAN                                              ';
        VSQLSE := VSQLSE || ', A.HOGOSHA_RIREKI_RENBAN AS HOGOSHA_RIREKI_                                           ';
        VSQLSE := VSQLSE || ', GA.GENZON_KBN AS GENZON_KBN                                                          ';
        VSQLSE := VSQLSE || '  FROM                                                                                 ';
        VSQLSE := VSQLSE || '  GAAVRENKEIATENA  GA                                                                  ';
        VSQLSE := VSQLSE || ', GABVATENAALL_B  GVB                                                                  ';
        VSQLSE := VSQLSE || ', GKBTGAKUREIBO   GBO                                                                  ';
        VSQLSE := VSQLSE || ', (                                                                                    ';
        VSQLSE := VSQLSE || '    SELECT                                                                             ';
        VSQLSE := VSQLSE || '        GVBS.KOJIN_NO AS HOGOSHA_KOJIN_NO                                              ';
        VSQLSE := VSQLSE || '        , GBOS.KOJIN_NO AS JIDO_KOJIN_NO                                               ';
        VSQLSE := VSQLSE || '        , (SELECT MAX(RIREKI_RENBAN) FROM GAAVRENKEIATENA) AS HOGOSHA_RIREKI_RENBAN    ';
        VSQLSE := VSQLSE || '    FROM                                                                               ';
        VSQLSE := VSQLSE || '        GKBTGAKUREIBO  GBOS                                                            ';
        VSQLSE := VSQLSE || '        , GAAVRENKEIATENA  GVBS                                                        ';
        VSQLSE := VSQLSE || '        , GABVATENAALL_B GVBS_B                                                        ';
        VSQLSE := VSQLSE || '    WHERE                                                                              ';
        VSQLSE := VSQLSE || '        ' || NKAISHIBI || ' <= GVBS.SHORIBI_KEY                                        ';
        VSQLSE := VSQLSE || '        AND GVBS.SHORIBI_KEY <= ' ||NSHURYOBI|| '                                      ';
        VSQLSE := VSQLSE || '        AND 110 <= GVBS.IDO_JIYU                                                       ';
        VSQLSE := VSQLSE || '        AND GVBS.IDO_JIYU <= 450                                                       ';
        VSQLSE := VSQLSE || '        AND GVBS.IDO_JIYU IN (' || g_sJUKI_IDO_CODE || ')                              ';
        VSQLSE := VSQLSE || '        AND GBOS.SAISHIN_KBN = 0                                                       ';
        VSQLSE := VSQLSE || '        AND GBOS.SAKUJO_FLG = 0                                                        ';
        VSQLSE := VSQLSE || '        AND GBOS.HOGOSYA_KOJIN_NO = GVBS.KOJIN_NO                                      ';
        VSQLSE := VSQLSE || '        AND GBOS.HOGOSYA_IDOJI_RIREKI_RENBAN < GVBS.RIREKI_RENBAN                      ';
        VSQLSE := VSQLSE || '        AND GVBS.KOJIN_NO = GBOS.KOJIN_NO                                              ';
        VSQLSE := VSQLSE || '        AND GVBS.RIREKI_RENBAN = GBOS.IDOJI_ATENA_RIREKI_RENBAN                        ';
        VSQLSE := VSQLSE || '        AND ' || NSEINENGAPI_S || ' <= GVBS_B.SEINENGAPI                               ';
        VSQLSE := VSQLSE || '        AND GVBS_B.SEINENGAPI <= ' ||NSEINENGAPI_E|| '                                 ';
        VSQLSE := VSQLSE || '    GROUP BY                                                                           ';
        VSQLSE := VSQLSE || '        GVBS.KOJIN_NO                                                                  ';
        VSQLSE := VSQLSE || '        , GBOS.KOJIN_NO                                                                ';
        VSQLSE := VSQLSE || '    ORDER BY                                                                           ';
        VSQLSE := VSQLSE || '        GVBS.KOJIN_NO                                                                  ';
        VSQLSE := VSQLSE || '        , GBOS.KOJIN_NO                                                                ';
        VSQLSE := VSQLSE || ' ) A                                                                                   ';
        VSQLSE := VSQLSE || ' WHERE                                                                                 ';
        VSQLSE := VSQLSE || '  GA.KOJIN_NO = A.HOGOSHA_KOJIN_NO                                                     ';
        VSQLSE := VSQLSE || '  AND GA.RIREKI_RENBAN = A.HOGOSHA_RIREKI_RENBAN                                       ';
        VSQLSE := VSQLSE || '  AND GBO.KOJIN_NO = A.JIDO_KOJIN_NO                                                   ';
        VSQLSE := VSQLSE || '  AND GBO.SAISHIN_KBN = 0                                                              ';
        VSQLSE := VSQLSE || '  AND GBO.SAKUJO_FLG = 0                                                               ';
        VSQLSE := VSQLSE || '  AND GVB.KOJIN_NO = A.JIDO_KOJIN_NO                                                   ';
        VSQLSE := VSQLSE || '  AND GVB.RIREKI_RENBAN = GBO.IDOJI_ATENA_RIREKI_RENBAN                                ';
        VSQLSE := VSQLSE || ' ORDER BY                                                                              ';
        VSQLSE := VSQLSE || '  GVB.KOJIN_NO                                                                         ';
        VSQLSE := VSQLSE || ', GBO.KOJIN_NO                                                                         ';
        OPEN cCURSOR FOR VSQLSE;
          LOOP
           FETCH cCURSOR INTO rENKEIATENA_REC;
           EXIT WHEN cCURSOR%NOTFOUND; 
            -- 住基連携ワーク(GKBWJUKIRENKEI)にデータを追加
            rWJUKIRENKEI := NULL;
            rWJUKIRENKEI.JIDO_KOJIN_NO             := rENKEIATENA_REC.JIDO_KOJIN_NO;                                                --児童宛名番号
            rWJUKIRENKEI.JIDO_SHIMEI_KANA          := rENKEIATENA_REC.JIDO_SHIMEI_KANA;                                             -- 児童氏名カナ
            rWJUKIRENKEI.JIDO_SHIMEI_KANJI         := rENKEIATENA_REC.JIDO_SHIMEI_KANJI;                                            -- 児童氏名漢字
            rWJUKIRENKEI.JIDO_KYU_SHIMEI_KANA      := NULL;                                                                         -- 児童旧氏名カナ
            rWJUKIRENKEI.JIDO_KYU_SHIMEI_KANJI     := NULL;                                                                         -- 児童旧氏名漢字
            rWJUKIRENKEI.SEINENGAPI                := NULL;                                                                         -- 生年月日
--2024/11/02 ZCZL.WANGYUNING UPDATE START 0.3.000.004:IT_GKB_00286横展開対応
            --rWJUKIRENKEI.HYOJI_SEINENGAPI          := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(rENKEIATENA_REC.SEINENGAPI),'YYYY/MM/DD'),3);       -- 表示用生年月日
            GKAPK00020.FGETSEINENGHYOUJI(rENKEIATENA_REC.SEINENGAPI,o_sEINENGAPI1);
            rWJUKIRENKEI.HYOJI_SEINENGAPI          := KKAPK0020.FDateFmt(o_sEINENGAPI1.o_vYYYYMMDD_BACKSLASH,3);       -- 表示用生年月日
--2024/11/02 ZCZL.WANGYUNING UPDATE END
            rWJUKIRENKEI.SEIBETSU                  := rENKEIATENA_REC.SEIBETSU;                                                     -- 性別
            IF rWJUKIRENKEI.SEIBETSU = 1 THEN 
               rWJUKIRENKEI.HYOJI_SEIBETSU         :=  '男';                                                                         -- 表示用性別
            ELSIF rWJUKIRENKEI.SEIBETSU = 2 THEN 
               rWJUKIRENKEI.HYOJI_SEIBETSU         :=  '女';                                                                         -- 表示用性別
            END IF;
            rWJUKIRENKEI.ZOKUGARAMEI1              := '子';                                                                          -- 保護者との関係
            IF rENKEIATENA_REC.JINKAKU_KBN = 0 THEN
              rWJUKIRENKEI.GAIKOKUJIN_KBN          := ' ';                                                                          -- 外国人区分
            ELSIF rENKEIATENA_REC.JINKAKU_KBN = 1 THEN
              rWJUKIRENKEI.GAIKOKUJIN_KBN          := '*';                                                                          -- 外国人区分
            END IF;
            rWJUKIRENKEI.SETAI_NO                  := rENKEIATENA_REC.SETAI_NO;                                                     -- 世帯番号
            rWJUKIRENKEI.HYOJI_SETAI_NO            :=  rENKEIATENA_REC.SETAI_NO;                                                    -- 表示用世帯番号
            rWJUKIRENKEI.HOGOSHA_KOJIN_NO          := rENKEIATENA_REC.HOGOSHA_KOJIN_NO;                                             -- 保護者宛名番号
            rWJUKIRENKEI.HOGOSHA_SHIMEI_KANA       := rENKEIATENA_REC.HOGOSHA_SHIMEI_KANA;                                          -- 保護者氏名カナ
            rWJUKIRENKEI.HOGOSHA_SHIMEI_KANJI      := rENKEIATENA_REC.HOGOSHA_SHIMEI_KANJI;                                         -- 保護者氏名漢字
            rWJUKIRENKEI.HOGOSHA_KYU_SHIMEI_KANA   := NULL;                                                                         -- 保護者旧氏名カナ
            rWJUKIRENKEI.HOGOSHA_KYU_SHIMEI_KANJI  := NULL;                                                                         -- 保護者旧氏名漢字
            -- 児童生徒との関係取得
            -- 2-1.変数の設定
            IF (rENKEIATENA_REC.ZOKUGARACD1 >= 11 AND rENKEIATENA_REC.ZOKUGARACD1 <= 29) OR 
                (rENKEIATENA_REC.ZOKUGARACD1 = 71 OR rENKEIATENA_REC.ZOKUGARACD1 = 72 OR rENKEIATENA_REC.ZOKUGARACD1 = 89) THEN
               NJ_ZOKUGARACD1 :=  10;                                       -- 児童.続柄1
            ELSE
               NJ_ZOKUGARACD1 := rENKEIATENA_REC.ZOKUGARACD1;               -- 児童.続柄1
            END IF;
            NJ_ZOKUGARACD2 := rENKEIATENA_REC.ZOKUGARACD2;                  -- 児童.続柄2
            NJ_ZOKUGARACD3 := rENKEIATENA_REC.ZOKUGARACD3;                  -- 児童.続柄3
            NJ_ZOKUGARACD4 := rENKEIATENA_REC.ZOKUGARACD4;                  -- 児童.続柄4
            NH_ZOKUGARACD1 := rENKEIATENA_REC.HOGOSHA_ZOKUGARACD1;          -- 保護者.続柄1
            NH_ZOKUGARACD2 := rENKEIATENA_REC.HOGOSHA_ZOKUGARACD2;          -- 保護者.続柄2
            NH_ZOKUGARACD3 := rENKEIATENA_REC.HOGOSHA_ZOKUGARACD3;          -- 保護者.続柄3
            NH_ZOKUGARACD4 := rENKEIATENA_REC.HOGOSHA_ZOKUGARACD4;          -- 保護者.続柄4
            -- 2-2.変数.システム条件取得用(I_SYSTEMJOKEN) = 1 の場合
            IF I_SYSTEMJOKEN = 1 THEN 
              IF (NH_ZOKUGARACD1 = 1 AND NH_ZOKUGARACD2 = 0 AND NH_ZOKUGARACD3 = 3 AND NH_ZOKUGARACD4 = 0) AND
                 (NJ_ZOKUGARACD1 = 10 AND NJ_ZOKUGARACD2 = 0 AND NJ_ZOKUGARACD3 = 0 AND NJ_ZOKUGARACD4 = 0) THEN
                 -- 2-2-1-1.保護者住記異動カーソル.保護者性別 = 1 の場合
                 IF rENKEIATENA_REC.HOGOSHA_SEIBETSU = 1 THEN 
                   -- 教育システム用続柄名取得(GKBFKZKGMGET)を使用して児童生徒との関係の続柄名称を取得し、OUT引数.続柄名称を該当箇所に設定する。
                    IBRTN := GKBFKZKGMGET(2, 4, 0, 0, 0, o_VZOKUGARAMEI, o_IHERR);
                    rWJUKIRENKEI.ZOKUGARAMEI2 := o_VZOKUGARAMEI;     -- 児童生徒との関係
                 ELSIF rENKEIATENA_REC.HOGOSHA_SEIBETSU = 2 THEN
                    IBRTN := GKBFKZKGMGET(2, 5, 0, 0, 0, o_VZOKUGARAMEI, o_IHERR);
                    rWJUKIRENKEI.ZOKUGARAMEI2 := o_VZOKUGARAMEI;     -- 児童生徒との関係
                 ELSE
                    rWJUKIRENKEI.ZOKUGARAMEI2 := NULL;     -- 児童生徒との関係
                 END IF;
              ELSE
                 rWJUKIRENKEI.ZOKUGARAMEI2 := NULL;     -- 児童生徒との関係
              END IF;
            ELSE
               -- 2-2に当てはまらない場合
                 -- 2-3-1.保護者住記異動カーソル.保護者性別 = 1 の場合
               IF rENKEIATENA_REC.HOGOSHA_SEIBETSU = 1 THEN 
                   -- 教育システム用続柄名取得(GKBFKZKGMGET)を使用して児童生徒との関係の続柄名称を取得し、OUT引数.続柄名称を該当箇所に設定する。
                    IBRTN := GKBFKZKGMGET(2, 4, 0, 0, 0, o_VZOKUGARAMEI, o_IHERR);
                    rWJUKIRENKEI.ZOKUGARAMEI2 := o_VZOKUGARAMEI;     -- 児童生徒との関係
                 ELSIF rENKEIATENA_REC.HOGOSHA_SEIBETSU = 2 THEN
                    IBRTN := GKBFKZKGMGET(2, 5, 0, 0, 0, o_VZOKUGARAMEI, o_IHERR);
                    rWJUKIRENKEI.ZOKUGARAMEI2 := o_VZOKUGARAMEI;     -- 児童生徒との関係
                 ELSE
                    rWJUKIRENKEI.ZOKUGARAMEI2 := NULL;     -- 児童生徒との関係
                 END IF;
            END IF;
            rWJUKIRENKEI.KYU_HOGOSHA_KOJIN_NO      := NULL;                                                                         -- 旧保護者宛名番号
            rWJUKIRENKEI.KYU_HOGOSHA_SHIMEI_KANA   := NULL;                                                                         -- 旧保護者氏名カナ
            rWJUKIRENKEI.KYU_HOGOSHA_SHIMEI_KANJI  := NULL;                                                                         -- 旧保護者氏名漢字
            rWJUKIRENKEI.IDO_BI                    := rENKEIATENA_REC.IDO_BI;                                                       -- 異動日
--2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00286横展開対応            
            --rWJUKIRENKEI.HYOJI_IDO_BI              := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(rENKEIATENA_REC.IDO_BI),'YYYY/MM/DD'),3);           -- 表示用異動日
            rWJUKIRENKEI.HYOJI_IDO_BI              := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(rENKEIATENA_REC.IDO_BI),3);           -- 表示用異動日
            rWJUKIRENKEI.IDO_TODOKE_BI             := rENKEIATENA_REC.IDO_TODOKE_BI;                                                -- 異動届出日
--2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00286横展開対応
            --rWJUKIRENKEI.HYOJI_IDO_TODOKE_BI       := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(rENKEIATENA_REC.IDO_TODOKE_BI),'YYYY/MM/DD'),3);    -- 表示用異動届出日
            rWJUKIRENKEI.HYOJI_IDO_TODOKE_BI       := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(rENKEIATENA_REC.IDO_TODOKE_BI),3);    -- 表示用異動届出日
            rWJUKIRENKEI.IDO_JIYU                  := rENKEIATENA_REC.IDO_JIYU;                                                     -- 異動事由
            rWJUKIRENKEI.HYOJI_IDO_JIYU            := '保護者：'|| GKBFKIDOJYGET(rENKEIATENA_REC.IDO_JIYU);                           -- 表示用異動事由
            rWJUKIRENKEI.GAKO_KBN                  := rENKEIATENA_REC.GAKO_KBN;                                                      -- 学校区分
            rWJUKIRENKEI.GAKUNEN_CD                := rENKEIATENA_REC.GAKUNEN_CD;                                                    -- 学年コード
            rWJUKIRENKEI.GAKUNENMEI                := '年生';                                                                        -- 学年名
            IF rWJUKIRENKEI.GAKUNEN_CD >= 0 AND rWJUKIRENKEI.GAKUNEN_CD <= 6 THEN 
              rWJUKIRENKEI.GAKOKU_CD               :=  rENKEIATENA_REC.SHUGAKUSHITEI_SHO;                                             -- 学校区コード
            ELSIF rWJUKIRENKEI.GAKUNEN_CD >= 7 AND rWJUKIRENKEI.GAKUNEN_CD <= 9 THEN
               rWJUKIRENKEI.GAKOKU_CD              :=  rENKEIATENA_REC.SHUGAKUSHITEI_CHU;                                             -- 学校区コード
            END IF;
            IF rWJUKIRENKEI.GAKUNEN_CD >= 0 AND rWJUKIRENKEI.GAKUNEN_CD <= 6 THEN 
              BEGIN
                SELECT
                    SYOGAKOMEI 
                INTO vSYOGAKOMEI 
                FROM
                    GKBTSHOGAKKO 
                WHERE
                    SYOGAKO_CD = rENKEIATENA_REC.SHUGAKUSHITEI_SHO;
              EXCEPTION 
                WHEN OTHERS THEN 
                  vSYOGAKOMEI := NULL; 
              END;
            ELSIF rWJUKIRENKEI.GAKUNEN_CD >= 7 AND rWJUKIRENKEI.GAKUNEN_CD <= 9 THEN
              BEGIN
                SELECT
                    TYUGAKOMEI 
                INTO vSYOGAKOMEI 
                FROM
                    GKBTCHUGAKKO 
                WHERE
                    TYUGAKO_CD = rENKEIATENA_REC.SHUGAKUSHITEI_CHU;
             EXCEPTION 
                WHEN OTHERS THEN 
                  vSYOGAKOMEI := NULL; 
             END;
            END IF;
            rWJUKIRENKEI.GAKOKUMEI :=  vSYOGAKOMEI;                                                                            -- 学校区名
            rWJUKIRENKEI.GYOSEIKU_CD                    := rENKEIATENA_REC.GYOSEIKU_CD;                                        -- 行政区コード
            rWJUKIRENKEI.GYOSEIKUMEI                    := GAAPK0030.FGYOSEIKUMEI(rENKEIATENA_REC.SANTEIDANTAI_CD, rENKEIATENA_REC.GYOSEIKU_CD); -- 行政区名
            rWJUKIRENKEI.HAN_CD                         := NULL;                                                               -- 班コード
            rWJUKIRENKEI.HANMEI                         := NULL;                                                               -- 班名
            rWJUKIRENKEI.SANTEIDANTAI_CD                := rENKEIATENA_REC.SANTEIDANTAI_CD;                                    -- 算定団体コード
            rWJUKIRENKEI.SANTEIDANTAIMEI                := NULL;                                                               -- 算定団体名
            rWJUKIRENKEI.SIN_YUBIN_NO                   := NULL;                                                               -- 新郵便番号
            rWJUKIRENKEI.SIN_JUSHO                      := rENKEIATENA_REC.JUSHO;                                              -- 新住所
            rWJUKIRENKEI.ZEN_YUBIN_NO                   := NULL;                                                               -- 前郵便番号
            rWJUKIRENKEI.ZEN_JUSHO                      := rENKEIATENA_REC.JUSHO;                                              -- 前住所
            rWJUKIRENKEI.BIKO                           := '保護者の異動を反映';                                                 -- 備考
            rWJUKIRENKEI.SHORIBI_KEY                    := rENKEIATENA_REC.SHORIBI_KEY;                                        -- 処理日KEY
            rWJUKIRENKEI.SHORI_JIKAN_KEY                := rENKEIATENA_REC.SHORI_JIKAN_KEY;                                    -- 処理時間KEY
            rWJUKIRENKEI.SHORI_KBN_KEY                  := rENKEIATENA_REC.SHORI_KBN_KEY;                                      -- 処理区分KEY
            rWJUKIRENKEI.ZENBU_ICHIBU_KEY               := rENKEIATENA_REC.ZENBU_ICHIBU_KEY;                                   -- 全部一部KEY
            rWJUKIRENKEI.KISAI_JUNI                     := rENKEIATENA_REC.KISAI_JUNI;                                         -- 記載順位
            rWJUKIRENKEI.JIDO_RIREKI_RENBAN             := rENKEIATENA_REC.JIDO_RIREKI_RENBAN;                                 -- 児童履歴連番
            rWJUKIRENKEI.HOGOSHA_RIREKI_RENBAN          := rENKEIATENA_REC.HOGOSHA_RIREKI_RENBAN;                              -- 保護者履歴連番
            rWJUKIRENKEI.JUKIATENA_SHOGAKKOKU_CD        := NULL;                                                               -- 住記・宛名_小学校区コード
            rWJUKIRENKEI.JUKIATENA_CHUGAKKOKU_CD        := NULL;                                                               -- 住記・宛名_中学校区コード
            rWJUKIRENKEI.JUKIATENA_SHITEI_SHOGAKKO_CD   := NULL;                                                               -- 住記・宛名_就学指定校_小学校
            rWJUKIRENKEI.JUKIATENA_SHITEI_CHUGAKKO_CD   := NULL;                                                               -- 住記・宛名_就学指定校_中学校
            rWJUKIRENKEI.GAKUREIBO_SHOGAKKOKU_CD        := NULL;                                                               -- 学齢簿_小学校区コード
            rWJUKIRENKEI.GAKUREIBO_CHUGAKKOKU_CD        := NULL;                                                               -- 学齢簿_中学校区コード
            rWJUKIRENKEI.SHITEIKO_SHUGAKU_FLG           := NULL;                                                               -- 就学指定校就学フラグ
            rWJUKIRENKEI.GAKKOKU_HENKO_FLG              := NULL;                                                               -- 学校区変更フラグ
            rWJUKIRENKEI.HOGOSHA_SOI_FLG                := NULL;                                                               -- 保護者相違フラグ

            INSERT INTO GKBWJUKIRENKEI VALUES rWJUKIRENKEI;
            -- 宛名・住記連携済み管理テーブル(GAATRENKEIATENAZUMI)から対象者の宛名番号、履歴連番が一致するデータ件数を取得
              SELECT COUNT(*)
                 INTO n_ZUMICOUNT 
                 FROM GAATRENKEIATENAZUMI
              WHERE JOBID = C_RENKEI_ID
                AND KOJIN_NO = rENKEIATENA_REC.HOGOSHA_KOJIN_NO
                AND ZUMI_MAX_RIREI = rENKEIATENA_REC.HOGOSHA_RIREKI_RENBAN;
             -- 取得した件数 <> 0 の場合
             IF n_ZUMICOUNT <> 0 THEN
                CONTINUE;
             END IF;
             -- 学齢簿テーブルの更新
             -- 6-4-1.学齢簿現最新履歴格納用の初期化
             PROC_RGAKUREIBO_SHOKIKA;
             -- 6-4-2.学齢簿現最新履歴の取得
             BEGIN
              SELECT * 
                 INTO RGAKUREIBO
                 FROM GKBTGAKUREIBO
              WHERE KOJIN_NO = rENKEIATENA_REC.HOGOSHA_KOJIN_NO
                AND SAISHIN_KBN = 0 
                AND SAKUJO_FLG  = 0;
             EXCEPTION 
              WHEN OTHERS THEN 
                RGAKUREIBO := NULL; 
            END;
            -- 6-4-3.学齢簿の現最新履歴の最新区分を変更
            UPDATE GKBTGAKUREIBO
               SET SAISHIN_KBN = 1 ,
                   SYS_KOSHINBI = ISAKUSEIBI ,
                   SYS_JIKAN = NSYSTIME ,
                   SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                   SYS_TANMATU_NO = g_sWSNUM
             WHERE KOJIN_NO = rENKEIATENA_REC.JIDO_KOJIN_NO
               AND SAISHIN_KBN = 0;
            -- 学齢簿の履歴を作成
            rTGAKUREIBO := NULL;
            rTGAKUREIBO.KOJIN_NO                       := RGAKUREIBO.KOJIN_NO;                                          -- 宛名番号
            rTGAKUREIBO.RIREKI_RENBAN                  := RGAKUREIBO.RIREKI_RENBAN + 10;                                -- 履歴連番
            rTGAKUREIBO.RIREKI_RENBAN_EDA              := 0;                                                            -- 児童生徒_個人履歴番号枝番
            rTGAKUREIBO.GENZON_KBN                     := RGAKUREIBO.GENZON_KBN;                                        -- 現存区分
            rTGAKUREIBO.SAISHIN_KBN                    := 0;                                                            -- 最新区分
            rTGAKUREIBO.ZO_JIYU_CD                     := RGAKUREIBO.ZO_JIYU_CD;                                        -- 増事由コード
            rTGAKUREIBO.ZO_NENGAPI                     := RGAKUREIBO.ZO_NENGAPI;                                        -- 増年月日
            rTGAKUREIBO.GEN_JIYU_CD                    := RGAKUREIBO.GEN_JIYU_CD;                                       -- 減事由コード
            rTGAKUREIBO.GEN_NENGAPI                    := RGAKUREIBO.GEN_NENGAPI;                                       -- 減年月日
            rTGAKUREIBO.ZOKUGARA1                      := RGAKUREIBO.ZOKUGARA1;                                         -- 続柄１
            rTGAKUREIBO.ZOKUGARA2                      := RGAKUREIBO.ZOKUGARA2;                                         -- 続柄２
            rTGAKUREIBO.ZOKUGARA3                      := RGAKUREIBO.ZOKUGARA3;                                         -- 続柄３
            rTGAKUREIBO.ZOKUGARA4                      := RGAKUREIBO.ZOKUGARA4;                                         -- 続柄４
            rTGAKUREIBO.HOGOSYA_KOJIN_NO               := RGAKUREIBO.HOGOSYA_KOJIN_NO;                                  -- 保護者宛名番号
            rTGAKUREIBO.HOGOSYA_ZOKUGARA1              := RGAKUREIBO.HOGOSYA_ZOKUGARA1;                                 -- 保護者続柄１
            rTGAKUREIBO.HOGOSYA_ZOKUGARA2              := RGAKUREIBO.HOGOSYA_ZOKUGARA2;                                 -- 保護者続柄２
            rTGAKUREIBO.HOGOSYA_ZOKUGARA3              := RGAKUREIBO.HOGOSYA_ZOKUGARA3;                                 -- 保護者続柄３
            rTGAKUREIBO.HOGOSYA_ZOKUGARA4              := RGAKUREIBO.HOGOSYA_ZOKUGARA4;                                 -- 保護者続柄４
            rTGAKUREIBO.SYOGAKO_CD                     := RGAKUREIBO.SYOGAKO_CD;                                        -- 小学校コード
            rTGAKUREIBO.SYOGAKO_NYUGAKU_BI             := RGAKUREIBO.SYOGAKO_NYUGAKU_BI;                                -- 小学校入学年月日
            rTGAKUREIBO.SYOGAKO_TENNYUGAKU_BI          := RGAKUREIBO.SYOGAKO_TENNYUGAKU_BI;                             -- 小学校転入学年月日
            rTGAKUREIBO.SYOGAKO_TENGAKU_BI             := RGAKUREIBO.SYOGAKO_TENGAKU_BI;                                -- 小学校転学年月日
            rTGAKUREIBO.SYOGAKO_SOTSUGYO_BI            := RGAKUREIBO.SYOGAKO_SOTSUGYO_BI;                               -- 小学校卒業年月日
            rTGAKUREIBO.TYUGAKO_CD                     := RGAKUREIBO.TYUGAKO_CD;                                        -- 中学校コード
            rTGAKUREIBO.TYUGAKO_NYUGAKU_BI             := RGAKUREIBO.TYUGAKO_NYUGAKU_BI;                                -- 中学校入学年月日
            rTGAKUREIBO.TYUGAKO_TENNYUGAKU_BI          := RGAKUREIBO.TYUGAKO_TENNYUGAKU_BI;                             -- 中学校転入学年月日
            rTGAKUREIBO.TYUGAKO_TENGAKU_BI             := RGAKUREIBO.TYUGAKO_TENGAKU_BI;                                -- 中学校転学年月日
            rTGAKUREIBO.TYUGAKO_SOTSUGYO_BI            := RGAKUREIBO.TYUGAKO_SOTSUGYO_BI;                               -- 中学校卒業年月日
            rTGAKUREIBO.TOKUSOKU_BI1                   := RGAKUREIBO.TOKUSOKU_BI1;                                      -- 督促年月日1
            rTGAKUREIBO.TOKUSOKU_NAIYO1                := RGAKUREIBO.TOKUSOKU_NAIYO1;                                   -- 督促内容1
            rTGAKUREIBO.TOKUSOKU_JIYU1                 := RGAKUREIBO.TOKUSOKU_JIYU1;                                    -- 督促事由１
            rTGAKUREIBO.TOKUSOKU_JURI_BI1              := RGAKUREIBO.TOKUSOKU_JURI_BI1;                                 -- 督促受理年月日１
            rTGAKUREIBO.TOKUSOKU_BI2                   := RGAKUREIBO.TOKUSOKU_BI2;                                      -- 督促年月日２
            rTGAKUREIBO.TOKUSOKU_NAIYO2                := RGAKUREIBO.TOKUSOKU_NAIYO2;                                   -- 督促内容２
            rTGAKUREIBO.TOKUSOKU_JIYU2                 := RGAKUREIBO.TOKUSOKU_JIYU2;                                    -- 督促事由2
            rTGAKUREIBO.TOKUSOKU_JURI_BI2              := RGAKUREIBO.TOKUSOKU_JURI_BI2;                                 -- 督促受理年月日2
            rTGAKUREIBO.TOKUSOKU_BI3                   := RGAKUREIBO.TOKUSOKU_BI3;                                      -- 督促年月日３
            rTGAKUREIBO.TOKUSOKU_NAIYO3                := RGAKUREIBO.TOKUSOKU_NAIYO3;                                   -- 督促内容３
            rTGAKUREIBO.TOKUSOKU_JIYU3                 := RGAKUREIBO.TOKUSOKU_JIYU3;                                    -- 督促事由3
            rTGAKUREIBO.TOKUSOKU_JURI_BI3              := RGAKUREIBO.TOKUSOKU_JURI_BI3;                                 -- 督促受理年月日3
            rTGAKUREIBO.TOKUSOKU_BI4                   := RGAKUREIBO.TOKUSOKU_BI4;                                      -- 督促年月日４
            rTGAKUREIBO.TOKUSOKU_NAIYO4                := RGAKUREIBO.TOKUSOKU_NAIYO4;                                   -- 督促内容４
            rTGAKUREIBO.TOKUSOKU_JIYU4                 := RGAKUREIBO.TOKUSOKU_JIYU4;                                    -- 督促事由4
            rTGAKUREIBO.TOKUSOKU_JURI_BI4              := RGAKUREIBO.TOKUSOKU_JURI_BI4;                                 -- 督促受理年月日4
            rTGAKUREIBO.TOKUSOKU_BI5                   := RGAKUREIBO.TOKUSOKU_BI5;                                      -- 督促年月日５
            rTGAKUREIBO.TOKUSOKU_NAIYO5                := RGAKUREIBO.TOKUSOKU_NAIYO5;                                   -- 督促内容５
            rTGAKUREIBO.TOKUSOKU_JIYU5                 := RGAKUREIBO.TOKUSOKU_JIYU5;                                    -- 督促事由5
            rTGAKUREIBO.TOKUSOKU_JURI_BI5              := RGAKUREIBO.TOKUSOKU_JURI_BI5;                                 -- 督促受理年月日5
            rTGAKUREIBO.TOKUSOKU_BI6                   := RGAKUREIBO.TOKUSOKU_BI6;                                      -- 督促年月日6
            rTGAKUREIBO.TOKUSOKU_NAIYO6                := RGAKUREIBO.TOKUSOKU_NAIYO6;                                   -- 督促内容6
            rTGAKUREIBO.TOKUSOKU_JIYU6                 := RGAKUREIBO.TOKUSOKU_JIYU6;                                    -- 督促事由6
            rTGAKUREIBO.TOKUSOKU_JURI_BI6              := RGAKUREIBO.TOKUSOKU_JURI_BI6;                                 -- 督促受理年月日6
            rTGAKUREIBO.TOKUSOKU_BI7                   := RGAKUREIBO.TOKUSOKU_BI7;                                      -- 督促年月日7
            rTGAKUREIBO.TOKUSOKU_NAIYO7                := RGAKUREIBO.TOKUSOKU_NAIYO7;                                   -- 督促内容7
            rTGAKUREIBO.TOKUSOKU_JIYU7                 := RGAKUREIBO.TOKUSOKU_JIYU7;                                    -- 督促事由7
            rTGAKUREIBO.TOKUSOKU_JURI_BI7              := RGAKUREIBO.TOKUSOKU_JURI_BI7;                                 -- 督促受理年月日7
            rTGAKUREIBO.TOKUSOKU_BI8                   := RGAKUREIBO.TOKUSOKU_BI8;                                      -- 督促年月日8
            rTGAKUREIBO.TOKUSOKU_NAIYO8                := RGAKUREIBO.TOKUSOKU_NAIYO8;                                   -- 督促内容8
            rTGAKUREIBO.TOKUSOKU_JIYU8                 := RGAKUREIBO.TOKUSOKU_JIYU8;                                    -- 督促事由8
            rTGAKUREIBO.TOKUSOKU_JURI_BI8              := RGAKUREIBO.TOKUSOKU_JURI_BI8;                                 -- 督促受理年月日8
            rTGAKUREIBO.TOKUSOKU_BI9                   := RGAKUREIBO.TOKUSOKU_BI9;                                      -- 督促年月日9
            rTGAKUREIBO.TOKUSOKU_NAIYO9                := RGAKUREIBO.TOKUSOKU_NAIYO9;                                   -- 督促内容9
            rTGAKUREIBO.TOKUSOKU_JIYU9                 := RGAKUREIBO.TOKUSOKU_JIYU9;                                    -- 督促事由9
            rTGAKUREIBO.TOKUSOKU_JURI_BI9              := RGAKUREIBO.TOKUSOKU_JURI_BI9;                                 -- 督促受理年月日9
            rTGAKUREIBO.TOKUSOKU_BI10                  := RGAKUREIBO.TOKUSOKU_BI10;                                     -- 督促年月日10
            rTGAKUREIBO.TOKUSOKU_NAIYO10               := RGAKUREIBO.TOKUSOKU_NAIYO10;                                  -- 督促内容10
            rTGAKUREIBO.TOKUSOKU_JIYU10                := RGAKUREIBO.TOKUSOKU_JIYU10;                                   -- 督促事由10
            rTGAKUREIBO.TOKUSOKU_JURI_BI10             := RGAKUREIBO.TOKUSOKU_JURI_BI10;                                -- 督促受理年月日10
            rTGAKUREIBO.KUIKIGAI_CD                    := RGAKUREIBO.KUIKIGAI_CD;                                       -- 区域外学校コード
            rTGAKUREIBO.KUIKIGAI_SETISYA               := RGAKUREIBO.KUIKIGAI_SETISYA;                                  -- 区域外設置者名
            rTGAKUREIBO.KUIKIGAI_NYUGAKU_BI            := RGAKUREIBO.KUIKIGAI_NYUGAKU_BI;                               -- 区域外入学年月日
            rTGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI         := RGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI;                            -- 区域外転入学年月日
            rTGAKUREIBO.KUIKIGAI_TENGAKU_BI            := RGAKUREIBO.KUIKIGAI_TENGAKU_BI;                               -- 区域外転学年月日
            rTGAKUREIBO.KUIKIGAI_TAIGAKU_BI            := RGAKUREIBO.KUIKIGAI_TAIGAKU_BI;                               -- 区域外退学年月日
            rTGAKUREIBO.KUIKIGAI_SOTSUGYO_BI           := RGAKUREIBO.KUIKIGAI_SOTSUGYO_BI;                              -- 区域外卒業年月日
            rTGAKUREIBO.YOGOGAKO_CD                    := RGAKUREIBO.YOGOGAKO_CD;                                       -- 盲聾養護学校コード
            rTGAKUREIBO.YOGOGAKO_SETISYA               := RGAKUREIBO.YOGOGAKO_SETISYA;                                  -- 盲聾養護設置者名
            rTGAKUREIBO.YOGOGAKO_NYUGAKU_BI            := RGAKUREIBO.YOGOGAKO_NYUGAKU_BI;                               -- 盲聾養護学校入学年月日
            rTGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI         := RGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI;                            -- 盲聾養護学校転入学年月日
            rTGAKUREIBO.YOGOGAKO_TENGAKU_BI            := RGAKUREIBO.YOGOGAKO_TENGAKU_BI;                               -- 盲聾養護学校転学年月日
            rTGAKUREIBO.YOGOGAKO_TAIGAKU_BI            := RGAKUREIBO.YOGOGAKO_TAIGAKU_BI;                               -- 盲聾養護学校退学年月日
            rTGAKUREIBO.YOGOGAKO_SOTSUGYO_BI           := RGAKUREIBO.YOGOGAKO_SOTSUGYO_BI;                              -- 盲聾養護学校卒業年月日
            rTGAKUREIBO.YUYO_KYOKA_BI                  := RGAKUREIBO.YUYO_KYOKA_BI;                                     -- 就学猶予許可年月日
            rTGAKUREIBO.YUYO_JIYU_CD                   := RGAKUREIBO.YUYO_JIYU_CD;                                      -- 就学猶予事由コード
            rTGAKUREIBO.YUYO_JIYU                      := RGAKUREIBO.YUYO_JIYU;                                         -- 就学猶予事由
            rTGAKUREIBO.YUYO_KAISI_BI                  := RGAKUREIBO.YUYO_KAISI_BI;                                     -- 就学猶予開始年月日
            rTGAKUREIBO.YUYO_SYURYO_BI                 := RGAKUREIBO.YUYO_SYURYO_BI;                                    -- 就学猶予終了年月日
            rTGAKUREIBO.YUYO_NENSU                     := RGAKUREIBO.YUYO_NENSU;                                        -- 就学猶予_年数
            rTGAKUREIBO.YUYO_FUKUGAKU_BI               := RGAKUREIBO.YUYO_FUKUGAKU_BI;                                  -- 就学猶予復学年月日
            rTGAKUREIBO.MENJO_KYOKA_BI                 := RGAKUREIBO.MENJO_KYOKA_BI;                                    -- 就学免除許可年月日
            rTGAKUREIBO.MENJO_JIYU_CD                  := RGAKUREIBO.MENJO_JIYU_CD;                                     -- 就学免除事由コード
            rTGAKUREIBO.MENJO_JIYU                     := RGAKUREIBO.MENJO_JIYU;                                        -- 就学免除事由
            rTGAKUREIBO.MENJO_KAISI_BI                 := RGAKUREIBO.MENJO_KAISI_BI;                                    -- 就学免除_開始年月日
            rTGAKUREIBO.MENJO_SYURYO_BI                := RGAKUREIBO.MENJO_SYURYO_BI;                                   -- 就学免除_終了年月日
            rTGAKUREIBO.MENJO_NENSU                    := RGAKUREIBO.MENJO_NENSU;                                       -- 就学免除_年数
            rTGAKUREIBO.MENJO_FUKUGAKU_BI              := RGAKUREIBO.MENJO_FUKUGAKU_BI;                                 -- 就学免除復学年月日
            rTGAKUREIBO.IDO_BI1                        := RGAKUREIBO.IDO_BI1;                                           -- 異動日1
            rTGAKUREIBO.IDO_JIYU1                      := RGAKUREIBO.IDO_JIYU1;                                         -- 異動事由1
            rTGAKUREIBO.IDO_BI2                        := RGAKUREIBO.IDO_BI2;                                           -- 異動日２
            rTGAKUREIBO.IDO_JIYU2                      := RGAKUREIBO.IDO_JIYU2;                                         -- 異動事由２
            rTGAKUREIBO.IDO_BI3                        := RGAKUREIBO.IDO_BI3;                                           -- 異動日３
            rTGAKUREIBO.IDO_JIYU3                      := RGAKUREIBO.IDO_JIYU3;                                         -- 異動事由３
            rTGAKUREIBO.IDO_BI4                        := RGAKUREIBO.IDO_BI4;                                           -- 異動日４
            rTGAKUREIBO.IDO_JIYU4                      := RGAKUREIBO.IDO_JIYU4;                                         -- 異動事由４
            rTGAKUREIBO.IDO_BI5                        := RGAKUREIBO.IDO_BI5;                                           -- 異動日５
            rTGAKUREIBO.IDO_JIYU5                      := RGAKUREIBO.IDO_JIYU5;                                         -- 異動事由５
            rTGAKUREIBO.IDO_BI6                        := RGAKUREIBO.IDO_BI6;                                           -- 異動日６
            rTGAKUREIBO.IDO_JIYU6                      := RGAKUREIBO.IDO_JIYU6;                                         -- 異動事由６
            rTGAKUREIBO.IDO_BI7                        := RGAKUREIBO.IDO_BI7;                                           -- 異動日７
            rTGAKUREIBO.IDO_JIYU7                      := RGAKUREIBO.IDO_JIYU7;                                         -- 異動事由７
            rTGAKUREIBO.IDO_BI8                        := RGAKUREIBO.IDO_BI8;                                           -- 異動日８
            rTGAKUREIBO.IDO_JIYU8                      := RGAKUREIBO.IDO_JIYU8;                                         -- 異動事由８
            rTGAKUREIBO.IDO_BI9                        := RGAKUREIBO.IDO_BI9;                                           -- 異動日９
            rTGAKUREIBO.IDO_JIYU9                      := RGAKUREIBO.IDO_JIYU9;                                         -- 異動事由９
            rTGAKUREIBO.IDO_BI10                       := RGAKUREIBO.IDO_BI10;                                          -- 異動日１０
            rTGAKUREIBO.IDO_JIYU10                     := RGAKUREIBO.IDO_JIYU10;                                        -- 異動事由１０
            rTGAKUREIBO.SYS_SAKUSEIBI                  := RGAKUREIBO.SYS_SAKUSEIBI;                                     -- 作成日
            rTGAKUREIBO.SYS_KOSHINBI                   := ISAKUSEIBI;                                                   -- 更新日
            rTGAKUREIBO.SYS_JIKAN                      := NSYSTIME;                                                     -- 更新時間
            rTGAKUREIBO.SYS_SHOKUINKOJIN_NO            := g_sTANTOCODE;                                                 -- 更新職員宛名番号
            rTGAKUREIBO.SYS_TANMATU_NO                 := g_sWSNUM;                                                     -- 更新端末番号
            rTGAKUREIBO.GAKUNEN                        := RGAKUREIBO.GAKUNEN;                                           -- 学年
            rTGAKUREIBO.SHORIBI                        := ISAKUSEIBI;                                                   -- 処理日
            rTGAKUREIBO.SHUGAKU                        := RGAKUREIBO.SHUGAKU;                                           -- 就学状況
            rTGAKUREIBO.IDOJIKO                        := RGAKUREIBO.IDOJIKO;                                           -- 異動事項
            rTGAKUREIBO.CHOHYO_NO                      := RGAKUREIBO.CHOHYO_NO;                                         -- 帳票連番
            rTGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN     := RGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN;                        -- 小学校転入学 学年
            rTGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN        := RGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN;                           -- 小学校転学 学年
            rTGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN     := RGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN;                        -- 中学校転入学 学年
            rTGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN        := RGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN;                           -- 中学校転学 学年
            rTGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN    := RGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN;                       -- 区域外転入学 学年
            rTGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN       := RGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN;                          -- 区域外転学 学年
            rTGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN       := RGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN;                          -- 区域外退学 学年
            rTGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN    := RGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN;                       -- 盲聾養護学校転入学 学年
            rTGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN       := RGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN;                          -- 盲聾養護学校転学 学年
            rTGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN       := RGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN;                          -- 盲聾養護学校退学 学年
            rTGAKUREIBO.GAKKO_KBN_CD                   := RGAKUREIBO.GAKKO_KBN_CD;                                      -- 学校区分コード
            rTGAKUREIBO.GAKUKYU_CD                     := RGAKUREIBO.GAKUKYU_CD;                                        -- 学級コード
            rTGAKUREIBO.SEIBETSU                       := RGAKUREIBO.SEIBETSU;                                          -- 児童生徒_性別
            rTGAKUREIBO.JOTAI                          := RGAKUREIBO.JOTAI;                                             -- 状態
            rTGAKUREIBO.TENNYUMAE_GAKKO_KBN            := RGAKUREIBO.TENNYUMAE_GAKKO_KBN;                               -- 転入前学校区分
            rTGAKUREIBO.TENNYUMAE_GAKKO_CD             := RGAKUREIBO.TENNYUMAE_GAKKO_CD;                                -- 転入前学校
            rTGAKUREIBO.TENNYUMAE_GAKUNEN              := RGAKUREIBO.TENNYUMAE_GAKUNEN;                                 -- 転入前学年
            rTGAKUREIBO.GENKYURYUCHI_FLG               := RGAKUREIBO.GENKYURYUCHI_FLG;                                  -- 原級留置_対象者フラグ
            rTGAKUREIBO.GENKYURYUCHI_KETTEI_BI         := RGAKUREIBO.GENKYURYUCHI_KETTEI_BI;                            -- 原級留置_決定年月日
            rTGAKUREIBO.GENKYURYUCHI_KAISI_BI          := RGAKUREIBO.GENKYURYUCHI_KAISI_BI;                             -- 原級留置_開始年月日
            rTGAKUREIBO.GENKYURYUCHI_SYURYOBI          := RGAKUREIBO.GENKYURYUCHI_SYURYOBI;                             -- 原級留置_終了年月日
            rTGAKUREIBO.GENKYURYUCHI_RIYU              := RGAKUREIBO.GENKYURYUCHI_RIYU;                                 -- 原級留置_理由
            rTGAKUREIBO.SHITEI_SYOGAKO_CD              := RGAKUREIBO.SHITEI_SYOGAKO_CD;                                 -- 就学指定校_小学校
            rTGAKUREIBO.SHITEI_TYUGAKO_CD              := RGAKUREIBO.SHITEI_TYUGAKO_CD;                                 -- 就学指定校_中学校
            rTGAKUREIBO.HENKO_GAKUNEN_SYOGAKO          := RGAKUREIBO.HENKO_GAKUNEN_SYOGAKO;                             -- 就学校変更_開始学年_小学校
            rTGAKUREIBO.HENKO_GAKUNEN_TYUGAKO          := RGAKUREIBO.HENKO_GAKUNEN_TYUGAKO;                             -- 就学校変更_開始学年_中学校
            rTGAKUREIBO.HENKO_SHINSEI_BI               := RGAKUREIBO.HENKO_SHINSEI_BI;                                  -- 就学校変更_申請年月日
            rTGAKUREIBO.HENKO_KYOKA_BI                 := RGAKUREIBO.HENKO_KYOKA_BI;                                    -- 就学校変更_許可年月日
            rTGAKUREIBO.HENKO_KBN                      := RGAKUREIBO.HENKO_KBN;                                         -- 就学校変更_区分
            rTGAKUREIBO.HENKO_KAISI_BI                 := RGAKUREIBO.HENKO_KAISI_BI;                                    -- 就学校変更_開始年月日
            rTGAKUREIBO.HENKO_SYURYO_BI                := RGAKUREIBO.HENKO_SYURYO_BI;                                   -- 就学校変更_終了年月日
            rTGAKUREIBO.HENKO_KYOKA_RIYU               := RGAKUREIBO.HENKO_KYOKA_RIYU;                                  -- 就学校変更_許可理由
            rTGAKUREIBO.HENKO_JIYU                     := RGAKUREIBO.HENKO_JIYU;                                        -- 就学校変更_事由
            rTGAKUREIBO.HENKO_HUKYOKA_RIYU             := RGAKUREIBO.HENKO_HUKYOKA_RIYU;                                -- 就学校変更_不許可理由
            rTGAKUREIBO.KIBO_GAKKO_KBN_CD              := RGAKUREIBO.KIBO_GAKKO_KBN_CD;                                 -- 希望就学校_学校区分コード
            rTGAKUREIBO.KIBO_SYOGAKKO_CD               := RGAKUREIBO.KIBO_SYOGAKKO_CD;                                  -- 希望就学校_小学校
            rTGAKUREIBO.KIBO_TYUGAKKO_CD               := RGAKUREIBO.KIBO_TYUGAKKO_CD;                                  -- 希望就学校_中学校
            rTGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO       := RGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO;                          -- 希望就学校_受付年月日_小学校
            rTGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO       := RGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO;                          -- 希望就学校_受付年月日_中学校
            rTGAKUREIBO.KUIKIGAISHUGAKU_FLG            := RGAKUREIBO.KUIKIGAISHUGAKU_FLG;                               -- 区域外就学フラグ
            rTGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI     := RGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI;                        -- 区域外就学_申請年月日
            rTGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI       := RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI;                          -- 区域外就学_許可年月日
            rTGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI       := RGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI;                          -- 区域外就学_開始年月日
            rTGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI      := RGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI;                         -- 区域外就学_終了年月日
            rTGAKUREIBO.KUIKIGAISHUGAKU_JIYU           := RGAKUREIBO.KUIKIGAISHUGAKU_JIYU;                              -- 区域外就学_事由
            rTGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU     := RGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU;                        -- 区域外就学_許可理由
            rTGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU   := RGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU;                      -- 区域外就学_不許可理由
            rTGAKUREIBO.HUSHUGAKU_KAISI_BI             := RGAKUREIBO.HUSHUGAKU_KAISI_BI;                                -- 不就学_開始年月日
            rTGAKUREIBO.HUSHUGAKU_SYURYO_BI            := RGAKUREIBO.HUSHUGAKU_SYURYO_BI;                               -- 不就学_終了年月日
            rTGAKUREIBO.HUSHUGAKU_RIYU                 := RGAKUREIBO.HUSHUGAKU_RIYU;                                    -- 不就学_理由
            rTGAKUREIBO.KUNISHIRITSU_CD                := RGAKUREIBO.KUNISHIRITSU_CD;                                   -- 国私立学校コード
            rTGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI        := RGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI;                           -- 国私立入学年月日
            rTGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI     := RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI;                        -- 国私立転入学年月日
            rTGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN:= RGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN;                   -- 国私立転入学 学年
            rTGAKUREIBO.KUNISHIRITSU_TENGAKU_BI        := RGAKUREIBO.KUNISHIRITSU_TENGAKU_BI;                           -- 国私立転学年月日
            rTGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN   := RGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN;                      -- 国私立転学 学年
            rTGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI        := RGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI;                           -- 国私立退学年月日
            rTGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN   := RGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN;                      -- 国私立退学 学年
            rTGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI       := RGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI;                          -- 国私立卒業年月日
            rTGAKUREIBO.KUNISHIRITSU_KAISI_BI          := RGAKUREIBO.KUNISHIRITSU_KAISI_BI;                             -- 国私立開始年月日
            rTGAKUREIBO.KUNISHIRITSU_SYURYO_BI         := RGAKUREIBO.KUNISHIRITSU_SYURYO_BI;                            -- 国私立終了年月日
            rTGAKUREIBO.TSUSHOMEI_KANA                 := RGAKUREIBO.TSUSHOMEI_KANA;                                    -- 通称名カナ
            rTGAKUREIBO.TSUSHOMEI_KANJI                := RGAKUREIBO.TSUSHOMEI_KANJI;                                   -- 通称名
            rTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA         := RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA;                            -- 保護者通称名カナ
            rTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI        := RGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI;                           -- 保護者通称名
            rTGAKUREIBO.GRB_HENKO_TODOKEDE_BI          := rENKEIATENA_REC.IDO_BI ;                                      -- 学齢簿変更_届出年月日
            rTGAKUREIBO.GRB_HENKO_BI                   := rENKEIATENA_REC.IDO_TODOKE_BI ;                               -- 学齢簿変更_年月日
            rTGAKUREIBO.GRB_HENKO_JIYU                 := 99;                                                           -- 学齢簿変更_事由
            rTGAKUREIBO.BIKO                           := RGAKUREIBO.BIKO;                                              -- 備考
            rTGAKUREIBO.IDO_BI                         := rENKEIATENA_REC.IDO_BI;                                       -- 異動年月日
            rTGAKUREIBO.TODOKEDE_BI                    := rENKEIATENA_REC.IDO_TODOKE_BI;                                -- 届出年月日
            rTGAKUREIBO.SHINSEI_KANRI_RENBAN           := RGAKUREIBO.SHINSEI_KANRI_RENBAN;                              -- 申請管理連番
            rTGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN      := RGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN;                         -- 異動時宛名基本履歴連番
            rTGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN    := rENKEIATENA_REC.HOGOSHA_RIREKI_RENBAN;                        -- 異動時保護者宛名基本履歴連番
            rTGAKUREIBO.SHOGAKKOKU_CD                  := RGAKUREIBO.SHOGAKKOKU_CD;                                     -- 小学校区コード
            rTGAKUREIBO.CHUGAKKOKU_CD                  := RGAKUREIBO.CHUGAKKOKU_CD;                                     -- 中学校区コード
            rTGAKUREIBO.SAKUJO_FLG                     := 0;                                                            -- 削除フラグ
             BEGIN
                  SELECT
                    BUKACODE
                  INTO sBUKACODE
                  FROM
                    KKNTWS
                  WHERE
                    KKNTWS.WSNUM = g_sWSNUM;
                EXCEPTION
                  WHEN OTHERS THEN
                    sBUKACODE := NULL;
                END;
                BEGIN
                  SELECT
                        A.BUKANAME INTO rTGAKUREIBO.SYS_TANMATU_BASHO -- 入力端末_入力場所
                  FROM
                    (
                    SELECT
                      KKNTBK.BUKANAME
                      , ROW_NUMBER() OVER (ORDER BY YUKOKIKANFR DESC) AS ROWNO 
                  FROM
                      KKNTBK 
                  WHERE BUKACODE = sBUKACODE
                    ) A
                  WHERE
                    A.ROWNO = 1;
                EXCEPTION
                  WHEN OTHERS THEN
                    rTGAKUREIBO.SYS_TANMATU_BASHO := NULL;
                END;
                
            INSERT INTO GKBTGAKUREIBO VALUES rTGAKUREIBO;
            --宛名・住記連携済み管理テーブルの更新
            --6-5-1.データの件数取得
            SELECT COUNT(*)
                   INTO n_ZUMICOUNT_1
              FROM GAATRENKEIATENAZUMI
             WHERE JOBID = C_RENKEI_ID
               AND KOJIN_NO = rENKEIATENA_REC.HOGOSHA_KOJIN_NO;
            --6-5-2. 6-5-1で取得した件数 = 0 の場合
            -- 宛名・住記連携済み管理テーブルにデータをInsert
            IF n_ZUMICOUNT_1 = 0 THEN 
              INSERT INTO GAATRENKEIATENAZUMI
                    (
                        JOBID,
                        KOJIN_NO,
                        ZUMI_MAX_RIREI,
                        GENZON_KBN)
                VALUES
                    (
                        C_RENKEI_ID,
                        rENKEIATENA_REC.HOGOSHA_KOJIN_NO,
                        rENKEIATENA_REC.HOGOSHA_RIREKI_RENBAN,
                        rENKEIATENA_REC.GENZON_KBN);
            --6-5-3. 6-5-2に当てはまらない場合
            --宛名・住記連携済み管理テーブルの該当するデータをUpdate
            ELSE
                UPDATE GAATRENKEIATENAZUMI
                    SET ZUMI_MAX_RIREI = rENKEIATENA_REC.HOGOSHA_RIREKI_RENBAN,
                        GENZON_KBN     = rENKEIATENA_REC.GENZON_KBN
                  WHERE JOBID          = C_RENKEI_ID
                    AND KOJIN_NO       = rENKEIATENA_REC.HOGOSHA_KOJIN_NO;
            END IF;
        END LOOP;
        CLOSE cCURSOR;
        IFRET := C_ISUCCESS;  -- 正常終了
        RETURN IFRET;        
    EXCEPTION
        WHEN OTHERS THEN
            IF cCURSOR%ISOPEN THEN
              CLOSE cCURSOR;
            END IF;
            IFRET := C_INOT_SUCCESS;  -- 異常終了
            RETURN IFRET;
    END FUNC_INSERT_JUKIRENKEI_WK;
--  2024/09/02 ZCZL.WANGQIWEI ADD END
    --------------------------------------------------------
    --  機能概要      : 住記連携ワークＣＳＶテーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_GET_JRENKEI_WK_CSV RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        VSQL                NVARCHAR2(10000);           -- ＳＱＬ文
        VSQLORDER           NVARCHAR2(1000);            -- ＳＱＬの［ORDER BY］句
        I_CUR               PLS_INTEGER;                -- カーソル
        RREC                GKBWJUKIRENKEI%ROWTYPE;  -- 住記連携ワークのレコード変数
        NROWS               NUMBER;                     --
        IPAGECNT            PLS_INTEGER;                -- 頁数
        IGYOCNT             PLS_INTEGER;                -- 行番号
        IGYORENBAN          PLS_INTEGER;                -- 行連番
        VPAGENAME           NVARCHAR2(500);             -- 改頁項目名のワーク
        VPAGEFIELD          NVARCHAR2(500);             -- 改頁項目値のワーク
        VPAGEWORK           NVARCHAR2(500);             -- 改頁項目値のワーク

    BEGIN
        IFRET := C_ISUCCESS;  -- 正常終了

        -- ワーク領域の初期化
        MCSV.DELETE;
        VPAGEWORK := '';
        IGYOCNT := 0;
        ICNT := 0;

        -- ソート条件取得
        CASE NSORT_KBN
            WHEN 0 THEN
                VSQLORDER := 'GAKO_KBN, GAKOKU_CD, IDO_JIYU, SHORIBI_KEY, SHORI_JIKAN_KEY, SHORI_KBN_KEY, ZENBU_ICHIBU_KEY, SETAI_NO, KISAI_JUNI';
            WHEN 1 THEN
                VSQLORDER := 'GAKO_KBN, GAKOKU_CD, IDO_JIYU, IDO_TODOKE_BI, SETAI_NO, KISAI_JUNI';
            WHEN 2 THEN
                VSQLORDER := 'GAKO_KBN, GAKOKU_CD, IDO_TODOKE_BI, SETAI_NO, KISAI_JUNI';
            WHEN 3 THEN
                VSQLORDER := 'GAKO_KBN, GAKOKU_CD, IDO_JIYU, SEINENGAPI, JIDO_SHIMEI_KANA';
            ELSE
                IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
                  VSQLORDER := g_rJSTP.Orderbyclause;
                END IF;
        END CASE;
        IF I_RTN = C_INOT_SUCCESS THEN
        -- エラーの場合、処理を脱出
            IFRET := C_INOT_SUCCESS;  -- 異常終了
            RETURN IFRET;             -- 終了
        END IF;
        -- ［ORDER BY］句を付加
        IF VSQLORDER IS NOT NULL THEN
           VSQLORDER := 'ORDER BY ' || VSQLORDER;
        END IF;
        -- 改頁条件取得
        CASE
            WHEN NSORT_KBN IN (0,1) THEN
                -- 学校区分・学校区・異動事由で改頁
                VPAGENM := 'GAKOKUMEI || ''  '' ||  HYOJI_IDO_JIYU';
                VPAGEFD := 'GAKO_KBN || GAKOKU_CD || IDO_JIYU';
            WHEN NSORT_KBN IN (2,3) THEN
                -- 学校区分・学校区で改頁
                VPAGENM := 'GAKOKUMEI';
                VPAGEFD := 'GAKO_KBN || GAKOKU_CD';
            ELSE
                VPAGENM := 'GAKOKUMEI';
                VPAGEFD := 'GAKO_KBN || GAKOKU_CD';
        END CASE;

        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'NULL KAIPEJI_CD, ';         -- 再セットするため初期値を設定
            VSQLSEL := VSQLSEL || 'NULL KAIPEJI, ';            -- 再セットするため初期値を設定
            VSQLSEL := VSQLSEL || '0 RENBAN, ';                -- 再セットするため初期値を設定
            VSQLSEL := VSQLSEL || 'JIDO_KOJIN_NO, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1, ';
            VSQLSEL := VSQLSEL || 'GAKOKU_CD, ';
            VSQLSEL := VSQLSEL || 'GAKOKUMEI, ';
            VSQLSEL := VSQLSEL || 'GAKUNEN_CD, ';
            VSQLSEL := VSQLSEL || 'GAKUNENMEI, ';
            VSQLSEL := VSQLSEL || 'SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_KOJIN_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_IDO_BI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_IDO_TODOKE_BI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_IDO_JIYU, ';
            VSQLSEL := VSQLSEL || 'SIN_JUSHO, ';
            VSQLSEL := VSQLSEL || 'ZEN_JUSHO, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || 'GAIKOKUJIN_KBN, ';
            VSQLSEL := VSQLSEL || 'BIKO, ';
            VSQLSEL := VSQLSEL || VPAGEFD || ' PAGE_FIELD, ';  -- 改頁値を設定
            VSQLSEL := VSQLSEL || VPAGENM || ' PAGE_NAME ';    -- 改頁名を設定
            VSQLSEL := VSQLSEL || ', ZOKUGARAMEI2 ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWJUKIRENKEI ';

            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;
            -- カーソルのオープン
            I_CUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(I_CUR, VSQL, DBMS_SQL.NATIVE);

            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, VPAGENM, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, NRENBAN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.JIDO_KOJIN_NO);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.JIDO_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.JIDO_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.HYOJI_SEINENGAPI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.HYOJI_SEIBETSU, 2);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.ZOKUGARAMEI1, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.GAKOKU_CD);
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.GAKOKUMEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.GAKOKUMEI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.GAKUNEN_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.GAKUNENMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.SETAI_NO);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.HOGOSHA_KOJIN_NO);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.HOGOSHA_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.HYOJI_IDO_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.HYOJI_IDO_TODOKE_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.HYOJI_IDO_JIYU, 30);
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.SIN_JUSHO, 420);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.ZEN_JUSHO, 420);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.SIN_JUSHO, 486);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.ZEN_JUSHO, 486);
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.GYOSEIKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.GAIKOKUJIN_KBN, 1);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.BIKO, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, VPAGENM, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.ZOKUGARAMEI2, 30);

            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(I_CUR);

            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(I_CUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  1, MCSV(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  2, MCSV(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  3, MCSV(ICNT).RENBAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  4, MCSV(ICNT).JIDO_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  5, MCSV(ICNT).JIDO_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  6, MCSV(ICNT).JIDO_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  7, MCSV(ICNT).HYOJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MCSV(ICNT).HYOJI_SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  9, MCSV(ICNT).ZOKUGARAMEI1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MCSV(ICNT).GAKOKU_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MCSV(ICNT).GAKOKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MCSV(ICNT).GAKUNEN_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MCSV(ICNT).GAKUNENMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MCSV(ICNT).SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MCSV(ICNT).HOGOSHA_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MCSV(ICNT).HOGOSHA_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MCSV(ICNT).HYOJI_IDO_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 18, MCSV(ICNT).HYOJI_IDO_TODOKE_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 19, MCSV(ICNT).HYOJI_IDO_JIYU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 20, MCSV(ICNT).SIN_JUSHO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 21, MCSV(ICNT).ZEN_JUSHO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 22, MCSV(ICNT).GYOSEIKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 23, MCSV(ICNT).GAIKOKUJIN_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 24, MCSV(ICNT).BIKO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 25, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 26, VPAGENAME);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 27, MCSV(ICNT).ZOKUGARAMEI2);

                    -- 改頁の指定がある場合
                    IF VPAGEWORK = VPAGENAME THEN
                    -- 以前の改頁項目名と同じ
                        IGYOCNT    := IGYOCNT + 1;
                        IGYORENBAN := IGYORENBAN + 1;
                        IF IGYOCNT > C_IMAXROWS THEN
                        -- １頁内の最大行数を超えた
                            IPAGECNT  := IPAGECNT + 1;
                            IGYOCNT   := 1;
                            VPAGEWORK := VPAGENAME;
                        END IF;
                    ELSE
                    -- 改頁必要
                        IPAGECNT   := IPAGECNT + 1;
                        IGYOCNT    := 1;
                        IGYORENBAN := 1;
                        VPAGEWORK  := VPAGENAME;
                    END IF;
                    -- 再セットする項目
                    MCSV(ICNT).KAIPEJI_CD := VPAGEFIELD;  -- 改頁コード
                    MCSV(ICNT).KAIPEJI    := VPAGENAME;   -- 改頁名
                    MCSV(ICNT).RENBAN     := IGYORENBAN;  -- 連番
                ELSE
                    -- 全件読み込み終了
                    EXIT;
                END IF;
                ICNT := ICNT + 1;
            END LOOP;
            --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 START
            SCINT:= ICNT;
            --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 END
        EXCEPTION
            WHEN OTHERS THEN
                IFRET := C_INOT_SUCCESS;  -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        END;
        RETURN IFRET;
    END FUNC_GET_JRENKEI_WK_CSV;
    --------------------------------------------------------
    --  機能概要      : 住記連携ワークＣＳＶの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_SET_JRENKEI_WK_CSVFILE RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        rRECODE             GKBWL450R001%ROWTYPE;
        nROWNUM             NUMBER;
        bRTN                BOOLEAN;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        o_sSHIMEIKANA   NVARCHAR2(100); --氏名カナ
        o_sSHIMEI       NVARCHAR2(100); --氏名漢字
        o_sBIRTHDAY     NVARCHAR2(100); --生年月日
--  2024/07/01 ZCZL.YANGXINYU ADD END
--  2024/09/05 ZCZL.WANGQIWEI ADD 0.3.030.000:フェーズ4対応
        v_GAKUNENMEI    NVARCHAR2(60);
    BEGIN
        IFRET := C_ISUCCESS;  -- 正常終了
        nROWNUM := 0;
        IMAX := MCSV.LAST;    -- ワーク領域の件数の最大値
        IMIN := MCSV.FIRST;   -- ワーク領域の件数の最小値
--  2024/07/01 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--        DELETE FROM GKBWL450R001 WHERE  WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
        DELETE FROM GKBWL450R001 WHERE  WSNUM = g_sWSNUM AND BATCHKBN = 2;
        -- 取得した件数分繰り返す
        FOR ICNT IN IMIN..IMAX LOOP
          nROWNUM := nROWNUM + 1;
          rRECODE := NULL;
--  2024/07/01 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--          rRECODE.NO                  :=      nROWNUM;                                                  --ソート順
--          rRECODE.KAISHIBI            :=      NKAISHIBI;                                                --期間自
--          rRECODE.SHURYOBI            :=      NSHURYOBI;                                                --期間至
--          rRECODE.HYOJI_KAISHIBI      :=      VKAISHIBI;                                                --表示期間自
--          rRECODE.HYOJI_SHURYOBI      :=      VSHURYOBI;                                                --表示期間至
--          rRECODE.KAIPAGE_CD          :=      MCSV(ICNT).KAIPEJI_CD;                                    --改ページコード
--          rRECODE.KAIPAGE             :=      MCSV(ICNT).KAIPEJI;                                       --改ページ
--          rRECODE.SAKUSEIBI           :=      ISAKUSEIBI;                                               --作成日
--          rRECODE.HYOJI_SAKUSEIBI     :=      VSAKUSEIBI;                                               --表示作成日
--          rRECODE.RENBAN              :=      MCSV(ICNT).RENBAN;                                        --連番
--          rRECODE.JIDO_KOJIN_NO       :=      MCSV(ICNT).JIDO_KOJIN_NO;                                 --児童個人番号
--          rRECODE.JIDO_SHIMEI_KANA    :=      MCSV(ICNT).JIDO_SHIMEI_KANA;                              --児童氏名かな
--          rRECODE.JIDO_SHIMEI_KANJI   :=      MCSV(ICNT).JIDO_SHIMEI_KANJI;                             --児童氏名漢字
--          rRECODE.HYOJI_SEINENGAPI    :=      MCSV(ICNT).HYOJI_SEINENGAPI;                              --表示生年月日
--          rRECODE.HYOJI_SEIBETSU      :=      MCSV(ICNT).HYOJI_SEIBETSU;                                --表示性別
--          rRECODE.ZOKUGARAMEI         :=      MCSV(ICNT).ZOKUGARAMEI1;                                  --続柄名
--          rRECODE.GAKKOKU_CD          :=      MCSV(ICNT).GAKOKU_CD;                                     --学校区コード
--          rRECODE.GAKKO_MEI           :=      MCSV(ICNT).GAKOKUMEI;                                     --学校名
--          rRECODE.GAKUNEN             :=      MCSV(ICNT).GAKUNEN_CD||MCSV(ICNT).GAKUNENMEI;             --学年
--          rRECODE.SETAI_NO            :=      MCSV(ICNT).SETAI_NO;                                      --世帯番号
--          rRECODE.HOGOSHA_KOJIN_NO    :=      MCSV(ICNT).HOGOSHA_KOJIN_NO;                              --保護者個人番号
--          rRECODE.HOGOSHA_SHIMEI_KANJI:=      MCSV(ICNT).HOGOSHA_SHIMEI_KANJI;                          --保護者氏名漢字
--          rRECODE.HYOJI_IDO_BI        :=      MCSV(ICNT).HYOJI_IDO_BI;                                  --表示異動年月日
--          rRECODE.HYOJI_IDO_TODOKE_BI :=      MCSV(ICNT).HYOJI_IDO_TODOKE_BI;                           --表示届出年月日
--          rRECODE.HYOJI_IDO_JIYU      :=      MCSV(ICNT).HYOJI_IDO_JIYU;                                --表示異動事由
--          rRECODE.NEW_JUSHO           :=      MCSV(ICNT).SIN_JUSHO;                                     --新住所
--          rRECODE.OLD_JUSHO           :=      MCSV(ICNT).ZEN_JUSHO;                                     --旧住所
--          rRECODE.GYOSEIKU_MEI        :=      MCSV(ICNT).GYOSEIKUMEI;                                   --行政区名
--          rRECODE.GAIKOKUJIN_KBN      :=      MCSV(ICNT).GAIKOKUJIN_KBN;                                --外国人区分
--          rRECODE.HOGOSHA_ZOKUGARAMEI :=      MCSV(ICNT).ZOKUGARAMEI2;                                  --保護者続柄名
--          rRECODE.BIKO                :=      MCSV(ICNT).BIKO;                                          --備考
--          rRECODE.BREAK_NO            :=      MCSV(ICNT).KAIPEJI_CD;                                    --改ページキー
--          rRECODE.WSNUM               :=      g_sWSNUM;                                                 --端末番号
--          rRECODE.BATCHKBN            :=      c_BATCH;                                                  --即時バッチ区分
--          rRECODE.JOBNUM              :=      g_nJOBNUM;                                                --ジョブNO
          rRECODE.NO                  :=      nROWNUM;                                                  --ソート順
          rRECODE.KAISHIBI            :=      NKAISHIBI;                                                --期間自
          rRECODE.SHURYOBI            :=      NSHURYOBI;                                                --期間至
          rRECODE.HYOJI_KAISHIBI      :=      VKAISHIBI;                                                --表示期間自
          rRECODE.HYOJI_SHURYOBI      :=      VSHURYOBI;                                                --表示期間至
          rRECODE.KAIPAGE_CD          :=      MCSV(ICNT).KAIPEJI_CD;                                    --改ページコード
          rRECODE.KAIPAGE             :=      MCSV(ICNT).KAIPEJI;                                       --改ページ
          rRECODE.SAKUSEIBI           :=      ISAKUSEIBI;                                               --作成日
          rRECODE.HYOJI_SAKUSEIBI     :=      VSAKUSEIBI;                                               --表示作成日
          rRECODE.RENBAN              :=      MCSV(ICNT).RENBAN;                                        --連番
          rRECODE.JIDO_KOJIN_NO       :=      MCSV(ICNT).JIDO_KOJIN_NO;                                 --児童個人番号
          IF GKBFKHMCTRL(MCSV(ICNT).JIDO_KOJIN_NO, g_rJSTP.Chohyoid, 0, g_nGKB450R001_CTL,o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN
                rRECODE.JIDO_SHIMEI_KANA  := o_sSHIMEIKANA;                                          -- 児童氏名かな
                rRECODE.JIDO_SHIMEI_KANJI := o_sSHIMEI;                                              -- 児童氏名漢字
                rRECODE.HYOJI_SEINENGAPI  := o_sBIRTHDAY;                                            --漢字生年月日
          END IF;
          rRECODE.HYOJI_SEIBETSU      :=      MCSV(ICNT).HYOJI_SEIBETSU;                                --表示性別
          rRECODE.ZOKUGARAMEI         :=      MCSV(ICNT).ZOKUGARAMEI1;                                  --続柄名
          rRECODE.GAKKOKU_CD          :=      MCSV(ICNT).GAKOKU_CD;                                     --学校区コード
          rRECODE.GAKKO_MEI           :=      MCSV(ICNT).GAKOKUMEI;                                     --学校名
--  2024/09/05 ZCZL.WANGQIWEI UPDATE START 0.3.030.000:フェーズ4対応
--           rRECODE.GAKUNEN             :=      MCSV(ICNT).GAKUNEN_CD||MCSV(ICNT).GAKUNENMEI;             --学年
          BEGIN 
            SELECT 
               GAKUNENMEI
             INTO v_GAKUNENMEI
            FROM GKBTGAKUNEN
            WHERE GAKUNEN_CD = MCSV(ICNT).GAKUNEN_CD;
          EXCEPTION
             WHEN OTHERS THEN
                 v_GAKUNENMEI := NULL;
          END;
          rRECODE.GAKUNEN             :=      v_GAKUNENMEI;             --学年
--  2024/09/05 ZCZL.WANGQIWEI UPDATE END
          rRECODE.SETAI_NO            :=      MCSV(ICNT).SETAI_NO;                                      --世帯番号
          rRECODE.HOGOSHA_KOJIN_NO    :=      MCSV(ICNT).HOGOSHA_KOJIN_NO;                              --保護者個人番号
--  2025/02/14 JPJYS.GONGYANYAN ST_GKB_00002 0.3.030.007対応 START
          IF GKBFKHMCTRL(MCSV(ICNT).HOGOSHA_KOJIN_NO, g_rJSTP.Chohyoid, 0, g_nGKB450R001_CTL,o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN        
          --IF GKBFKHMCTRL(MCSV(ICNT).JIDO_KOJIN_NO, g_rJSTP.Chohyoid, 1, g_nGKB450R001_CTL,o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN
--  2025/02/14 JPJYS.GONGYANYAN ST_GKB_00002 0.3.030.007対応 END
--  2025/02/03 JPJYS.LIZIZHON GST_GKB_TMP00029  0.3.030.006 UPDATE STR             
            --rRECODE.HOGOSHA_SHIMEI_KANJI :=      o_sSHIMEIKANA;                                         --保護者氏名漢字
            rRECODE.HOGOSHA_SHIMEI_KANJI :=      o_sSHIMEI;   
--  2025/02/03 JPJYS.LIZIZHON GST_GKB_TMP00029  0.3.030.006 UPDATE STR             
          END IF;
          rRECODE.HYOJI_IDO_BI        :=      MCSV(ICNT).HYOJI_IDO_BI;                                  --表示異動年月日
          rRECODE.HYOJI_IDO_TODOKE_BI :=      MCSV(ICNT).HYOJI_IDO_TODOKE_BI;                           --表示届出年月日
          rRECODE.HYOJI_IDO_JIYU      :=      MCSV(ICNT).HYOJI_IDO_JIYU;                                --表示異動事由
          rRECODE.NEW_JUSHO           :=      MCSV(ICNT).SIN_JUSHO;                                     --新住所
          rRECODE.OLD_JUSHO           :=      MCSV(ICNT).ZEN_JUSHO;                                     --旧住所
          rRECODE.GYOSEIKU_MEI        :=      MCSV(ICNT).GYOSEIKUMEI;                                   --行政区名
          rRECODE.GAIKOKUJIN_KBN      :=      MCSV(ICNT).GAIKOKUJIN_KBN;                                --外国人区分
          rRECODE.HOGOSHA_ZOKUGARAMEI :=      MCSV(ICNT).ZOKUGARAMEI2;                                  --保護者続柄名
          rRECODE.BIKO                :=      MCSV(ICNT).BIKO;                                          --備考
          rRECODE.BREAK_NO            :=      NULL;                                                     --改ページキー
          rRECODE.WSNUM               :=      g_sWSNUM;                                                 --端末番号
          rRECODE.BATCHKBN            :=      2;                                                        --即時バッチ区分
          rRECODE.JOBNUM              :=      g_nJOBNUM;                                                --ジョブNO
--  2024/07/01 ZCZL.YANGXINYU UPDATE END
          INSERT INTO GKBWL450R001 VALUES rRECODE;

        END LOOP;
        bRTN := FUNC_B11CSV('GKBWL450R001');
        -- 終了
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := C_INOT_SUCCESS;  -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        RETURN IFRET;
    END FUNC_SET_JRENKEI_WK_CSVFILE;

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        ERR              EXCEPTION;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発(標準化)
        nMAX_NENDO       NUMBER;          --MAX(年度)
        VLOG             NVARCHAR2(256);
        aOUT_PRM         A_CONS_PRM;      -- パラメータの配列
        nOUTLENGTH       NUMBER;          -- パラメータの配列の長さ
--  2024/07/01 ZCZL.YANGXINYU ADD END
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        -- １．初期処理
        -- 取得した条件をそれぞれの変数へセット
        IO_WAREKIHIZUKE := g_vJOKEN1;
        IO_SEIREKIHIZUKE := 0;
        B_RTN := KKAPK0020.FDAYEDIT(IO_WAREKIHIZUKE,
                                     IO_SEIREKIHIZUKE,
                                     VEDIT_GYYMMDD1,
                                     VEDIT_GYYMMDD2,
                                     VEDIT_GYYMMDD3,
                                     VKJ_GENGO,
                                     VKG_GENGO,
                                     IWAREKI_YY,
                                     ISEIREKI_YYYY,
                                     IWAREKI_GYYMM,
                                     IMM,
                                     IDD,
                                     IWAREKIHIZUKE,
                                     ISEIREKIHIZUKE);
        NKAISHIBI    := ISEIREKIHIZUKE;           -- 抽出開始住記異動更新日
        VKAISHIBI    := VEDIT_GYYMMDD3;           -- 抽出開始住記異動更新日

        IO_WAREKIHIZUKE := g_vJOKEN2;
        IO_SEIREKIHIZUKE := 0;
        B_RTN := KKAPK0020.FDAYEDIT(IO_WAREKIHIZUKE,
                                     IO_SEIREKIHIZUKE,
                                     VEDIT_GYYMMDD1,
                                     VEDIT_GYYMMDD2,
                                     VEDIT_GYYMMDD3,
                                     VKJ_GENGO,
                                     VKG_GENGO,
                                     IWAREKI_YY,
                                     ISEIREKI_YYYY,
                                     IWAREKI_GYYMM,
                                     IMM,
                                     IDD,
                                     IWAREKIHIZUKE,
                                     ISEIREKIHIZUKE);
        NSHURYOBI    := ISEIREKIHIZUKE;           -- 抽出終了住記異動更新日
        VSHURYOBI    := VEDIT_GYYMMDD3;           -- 抽出終了住記異動更新日

        NHOGOSHA_KBN := TO_NUMBER(g_vJOKEN3);  -- 保護者判定区分
        NKOSHIN_KBN  := TO_NUMBER(g_vJOKEN4);  -- 学齢簿更新区分
        NSORT_KBN    := TO_NUMBER(g_vJOKEN5);  -- 改頁・ソート区分

        -- 住記異動連携中間テーブル（GKBWJUKIRENKEI）のクリア
        I_RTN := KKAPK3000.FTRUNCATE(C_VTABLE, V_SQL_MSG);
        -- エラーで帰ってきた場合
        IF I_RTN = C_INOT_SUCCESS THEN
            RAISE ERR;
        END IF;

        -- 学齢簿更新判定の制御を取得
        o_RENBAN_PRM := A_CONS_PRM();
        I_RTN := KKAPK0030.FPRMSHUTOKU('GKB', '00JUKIRENDO', 0, o_RENBAN_PRM, o_LENGTH);
        IF I_RTN = 1 THEN
          o_RENBAN_PRM := A_CONS_PRM();
          o_RENBAN_PRM.EXTEND;
          o_RENBAN_PRM(1) := 0;
        ELSE
          WHILE (o_LENGTH < 1) LOOP
            o_RENBAN_PRM.EXTEND;
            o_RENBAN_PRM(o_LENGTH + 1) := 0;
            o_LENGTH := o_LENGTH + 1;
          END LOOP;
        END IF;

        -- 処理年度(和暦)の取得
        IF TO_NUMBER(TO_CHAR(SYSDATE,'MM')) >= 4 THEN
            NSHORINENDO_S := TO_NUMBER(TO_CHAR(SYSDATE,'YYYY'));
        ELSE
            NSHORINENDO_S := TO_NUMBER(TO_CHAR(SYSDATE,'YYYY')) - 1;
        END IF;
        IO_WAREKIHIZUKE := 0;
        IO_SEIREKIHIZUKE := NSHORINENDO_S * 10000 + 401;
        IO_SEIREKIHIZUKE := KKAPK0020.FDATECAL(IO_SEIREKIHIZUKE,0,0,0,1);

        B_RTN := KKAPK0020.FDAYEDIT(IO_WAREKIHIZUKE,
                                     IO_SEIREKIHIZUKE,
                                     VEDIT_GYYMMDD1,
                                     VEDIT_GYYMMDD2,
                                     VEDIT_GYYMMDD3,
                                     VKJ_GENGO,
                                     VKG_GENGO,
                                     IWAREKI_YY,
                                     ISEIREKI_YYYY,
                                     IWAREKI_GYYMM,
                                     IMM,
                                     IDD,
                                     IWAREKIHIZUKE,
                                     ISEIREKIHIZUKE);
        NSHORINENDO_W := IWAREKI_YY;

        -- 入学年月日の設定
        NNYUGAKU_BI := (NSHORINENDO_S + 1) * 10000 + 401;

        -- ６抽出対象者の生年月日の取得
        -- 更新ログテーブルを検索
        SELECT COUNT(*)
          INTO NCNT
          FROM GKBTKOSHINLOG
         WHERE NENDO   = NSHORINENDO_W
--  2024/09/26 ZCZL.WANGMING UPDATE START 0.3.030.001:仕様変更　IT_GKB_00017対応
--           AND SHORIID = 'GKBPC00400';
           AND GYOMU_SUBCD = 0
           AND GROUPKEY = 1
           AND RENBAN = 2
           AND SHORI_RENBAN = 1;
--  2024/09/26 ZCZL.WANGMING UPDATE END
        -- データが存在する場合は新入学児童を対象とする
        IF NCNT > 0 THEN
            NSEINENGAPI_E := (NSHORINENDO_S - 5) * 10000 + 401;  -- 抽出対象生年月日(至)
        -- データが存在しない場合は新入学児童を対象としない
        ELSE
            NSEINENGAPI_E := (NSHORINENDO_S - 6) * 10000 + 401;  -- 抽出対象生年月日(至)
        END IF;
        NSEINENGAPI_S := (NSHORINENDO_S - 15) * 10000 + 402;     -- 抽出対象生年月日(自)

        --システム条件取得（「児童との関係」判定処理）
        I_SYSTEMJOKEN := 0;
        I_SYSTEMJOKEN := FUNC_GET_SYSJOKEN(c_ISYS_J_KANKEI);
        -- システム条件取得ファンクションを呼び出し、新入学児童削除方法のパラメータ値を取得し、変数.新入学児童削除方法にセットする。
        I_SYSTEM_HAU := FUNC_GET_SYSJOKEN(c_ISYS_J_NUMBER);
        ISAKUSEIBI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        NSYSTIME   := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS'));
        -- システム日付の設定
        IO_WAREKIHIZUKE := 0;
        IO_SEIREKIHIZUKE := ISAKUSEIBI;
        B_RTN := KKAPK0020.FDAYEDIT(IO_WAREKIHIZUKE,
                                     IO_SEIREKIHIZUKE,
                                     VEDIT_GYYMMDD1,
                                     VEDIT_GYYMMDD2,
                                     VEDIT_GYYMMDD3,
                                     VKJ_GENGO,
                                     VKG_GENGO,
                                     IWAREKI_YY,
                                     ISEIREKI_YYYY,
                                     IWAREKI_GYYMM,
                                     IMM,
                                     IDD,
                                     IWAREKIHIZUKE,
                                     ISEIREKIHIZUKE);
        VSAKUSEIBI    := VEDIT_GYYMMDD3;
--  2024/07/01 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発(標準化)
        -- 連携対象住記異動事由コード取得
        I_RTN := KKAPK0030.FPRMSHUTOKU('GKB', 'RENKEIIDOJIYU', 0, aOUT_PRM, nOUTLENGTH);
        -- 連携対象の住記異動コードが取得できなかった場合、ログを出力し、終了処理に入る。
        IF I_RTN = 1 THEN
            VLOG := FUNC_GET_LOG('連携対象住記異動事由コードが取得できませんでした。');
--  2024/08/30 ZCZL.WANGQIWEI UPDATE 0.3.030.000:フェーズ4対応
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_B10SAKUHYO1', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
            RAISE ERR;
        END IF;

        g_sJUKI_IDO_CODE := '';
        FOR i IN 1..aOUT_PRM.count LOOP
            IF i = 1 THEN
                IF aOUT_PRM(i) IS NOT NULL THEN
                   g_sJUKI_IDO_CODE := aOUT_PRM(i);
                END IF;
            ELSE
                 IF aOUT_PRM(i) IS NOT NULL THEN
                   g_sJUKI_IDO_CODE := g_sJUKI_IDO_CODE || ',' || aOUT_PRM(i);
                 END IF;
            END IF;
        END LOOP;

        -- 学区管理区分取得
        I_RTN := KKAPK0030.FCTGetR('GKB', '00GAKKU_KANRI', '0000', 0, aOUT_PRM);
        IF I_RTN = 0 THEN
            g_nGAKKU_KBN := aOUT_PRM(1);
        ELSE
            g_nGAKKU_KBN := 0;
        END IF;

        -- 進級・卒業処理の処理状況取得と年度設定
        SELECT MAX(NENDO) INTO nMAX_NENDO FROM GKBTKOSHINLOG WHERE SHORIID = 'GKBPC00100';
        IF nMAX_NENDO IS NULL THEN
            g_nSOGYOU_SHORI_FLG := 1;
            g_nIDO_NENDO := 0;
        ELSE
            g_nIDO_NENDO := nMAX_NENDO;
            IF nMAX_NENDO < KKAPK0020.FNENDO(TO_CHAR(SYSDATE,'YYYY'),0) THEN
                g_nSOGYOU_SHORI_FLG := 0;
            ELSIF KKAPK0020.FNENDO(TO_CHAR(SYSDATE,'YYYY'),0) = nMAX_NENDO THEN
                g_nSOGYOU_SHORI_FLG := 1;
            END IF;
        END IF;

        -- システム制御設定を取得
        -- 住記異動更新対象者一覧_インデックス番号
        I_RTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aOUT_PRM);
        IF I_RTN = 0 THEN
            FOR j IN 1..aOUT_PRM.COUNT LOOP
                IF aOUT_PRM(j) = 'GKB450R001' THEN
                    g_nGKB450R001_INDEX := j;
                    EXIT;
                END IF;
            END LOOP;
        END IF;

        -- 本名・通称名　出力制御
        I_RTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aOUT_PRM);
        IF I_RTN = 0 AND g_nGKB450R001_INDEX <= aOUT_PRM.COUNT THEN
            g_nGKB450R001_CTL := aOUT_PRM(g_nGKB450R001_INDEX);
        END IF;

        -- 排他制御処理
        I_RTN := GKBFKHTSET(2, '999999999999', '全件', ISAKUSEIBI, g_sTANTOCODE, g_sWSNUM, g_nTIME);
        IF I_RTN = 1 THEN
            VLOG := FUNC_GET_LOG('排他がかかっているデータが存在するため、処理を実行できませんでした。');
--  2024/08/30 ZCZL.YANGXINYU UPDATE START 0.3.030.000:フェーズ4対応
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
--            RETURN FALSE;
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_B10SAKUHYO1', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
            RAISE ERR;
--  2024/08/30 ZCZL.YANGXINYU UPDATE END             
        ELSIF I_RTN <> 0 AND I_RTN <> 1 THEN
            VLOG := FUNC_GET_LOG('排他制御処理で異常終了しました。');
--  2024/08/30 ZCZL.YANGXINYU UPDATE START 0.3.030.000:フェーズ4対応
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
--            RETURN FALSE;
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_B10SAKUHYO1', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
            RAISE ERR;
--  2024/08/30 ZCZL.YANGXINYU UPDATE END             
        END IF;
--  2024/07/01 ZCZL.YANGXINYU ADD END
        -- 住記連携ワークデータ作成
        I_RTN := FUNC_GET_JRENKEI_WK;
        -- エラーで帰ってきた場合
        IF I_RTN <> C_ISUCCESS THEN
            --  2024/04/19 ZCZL.LIKEWEN ADD START 0.2.000.001:512_GKB_00018対応
            IF I_RTN = c_INOTFOUND THEN
              --対象データ無しの場合は異常終了させない
              GOTO NODATA_EXIT;
            END IF;
            --  2024/04/19 ZCZL.LIKEWEN ADD END
            RAISE ERR;
        END IF;

        -- 住記連携ワークテーブル作成
        I_RTN := FUNC_INSERT_JRENKEI_WK;
        IF I_RTN = C_INOT_SUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE ERR;
        END IF;
--  2024/09/02 ZCZL.WANGQIWEI ADD START 0.3.030.000:フェーズ4対応
        -- 保護者のみ異動する児童生徒分の住記連携ワーク(GKCWJUKIRENKEI)テーブルの作成および学齢簿テーブルの更新
        I_RTN := FUNC_INSERT_JUKIRENKEI_WK;
        IF I_RTN = C_INOT_SUCCESS THEN
            -- エラーで帰ってきた場合
            RAISE ERR;
        END IF;
--  2024/09/02 ZCZL.WANGQIWEI ADD END
        -- 住記連携ワークデータ作成（ＣＳＶ用）
        I_RTN := FUNC_GET_JRENKEI_WK_CSV;
        IF I_RTN <> C_ISUCCESS THEN
        -- エラーで帰ってきた場合
           RAISE ERR;
        END IF;

        -- 住記連携ワークＣＳＶファイル作成
        I_RTN := FUNC_SET_JRENKEI_WK_CSVFILE;
        IF I_RTN <> C_ISUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE ERR;
        END IF;
        
        --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 START
        -- 件数表の作成
        BRTN := FUNC_KENSUUTEPURU_MAKE;
        IF NOT BRTN THEN
            RAISE ERR;
        END IF;
        --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.030.003:IT_GKB_00610開対応 END
        
        --  2024/04/19 ZCZL.LIKEWEN ADD START 0.2.000.001:512_GKB_00018対応
        <<NODATA_EXIT>>
        --  2024/04/19 ZCZL.LIKEWEN ADD END
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);
        -- 排他制御クリア
--  2024/08/30 ZCZL.YANGXINYU ADD 0.3.030.000:フェーズ4対応
        FUNC_GKBFKHTCLR;
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
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
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
    --  作成者／作成日: ZCZL.ZHANGLEI   2024/01/02
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
--  2024/08/30 ZCZL.YANGXINYU UPDATE START 0.3.030.000:フェーズ4対応
--        -- 排他制御クリア
----  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
--        FUNC_GKBFKHTCLR;
--  2024/08/30 ZCZL.YANGXINYU UPDATE END        
    EXCEPTION
        WHEN ePRMEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            -- 排他制御クリア
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
            FUNC_GKBFKHTCLR;
        WHEN eSHORIEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
            -- 排他制御クリア
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
            FUNC_GKBFKHTCLR;
        WHEN OTHERS THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
            -- 排他制御クリア
--  2024/07/01 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
            FUNC_GKBFKHTCLR;
    END PBATCH;
END GKBPC00120;
/