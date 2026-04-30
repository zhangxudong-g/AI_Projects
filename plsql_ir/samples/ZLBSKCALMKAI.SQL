CREATE OR REPLACE PROCEDURE ZLBSKCALMKAI(i_NNENDO             IN  NUMBER,
--1.1.200.000
                                           i_NNENDO_BUN         IN  NUMBER,
                                           i_NSETAI             IN  NUMBER,
                                           i_NDANTAI            IN  NUMBER,
                                           i_NNUSHI             IN  NUMBER,
                                           i_NJIKKOU_KBN        IN  NUMBER,
                                           i_CAL_KBN            IN  NUMBER,
                                           i_VTANMATSU          IN  NVARCHAR2,
                                           i_NTRENBAN           IN  NUMBER,
                                           o_NRESULT            OUT NUMBER,
                                           i_NKOSEIBI           IN  NUMBER := 0)
-------------------------------------------------------------------------------
-- 業務名   ZLB（国保税）
-- ＰＧ名   ZLBSKCALMKAI
-- 名称     計算介護基本作成
-- 処理概要 計算個人を元に課税計算を行い、計算介護基本および計算介護退職を
--          作成する。
-- 引き数   i_NNENDO            調定年度
--          i_NNENDO_BUN        年度分
--          i_NSETAI            国保世帯番号
--          i_NDANTAI           算定団体コード
--          i_NNUSHI            世帯主個人コード
--          i_NJIKKOU_KBN       実行区分(0:バッチから起動 本算定/月例...
--                                       1:オンライン起動 即時
--                                       2:オンライン起動 税額試算)
--          i_CAL_KBN           呼出区分(0:通常処理  本算定/月例...
--                                       1:賦課期日時点処理
--          i_VTANMATSU         端末番号
--          i_NTRENBAN          登録連番
--          o_NRESULT           処理結果
-- 作成者   ZCZL.FUBOYU
-- 作成日   2023/08/01
-- Version  0.2.000.000
-------------------------------------------------------------------------------------
--変更履歴
--2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
--2024/05/06 ZCZL.ZHANGLEI UPDATE 0.3.000.100:国保２次にマージ作業
--2024/09/23 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00020
--2025/07/24 CTC.gaoqq 1.0.501.001:QA10155マージ作業
--2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
-------------------------------------------------------------------------------
IS

    -- アレイTYPE定義
    TYPE MTNUMARRAY1  IS TABLE OF NUMBER(1)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY2  IS TABLE OF NUMBER(2)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY3  IS TABLE OF NUMBER(3)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY10 IS TABLE OF NUMBER(10) INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY12 IS TABLE OF NUMBER(12) INDEX BY BINARY_INTEGER;
    --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
    TYPE MTNUMARRAY15F IS TABLE OF NUMBER(12,3) INDEX BY BINARY_INTEGER;

-------------------------------------------------------------------------------
-- 定数の定義
-------------------------------------------------------------------------------

    c_NOK               CONSTANT NUMBER(1)  := 0;   -- 処理正常
    c_NERR              CONSTANT NUMBER(1)  := 1;   -- 処理異常


    -- 所得額
    c_NSHOTOKU_LOW      CONSTANT NUMBER(12) := -99999999999;    -- 所得額(LOW VALUE)

    -- 年税額端数
    c_NHASU_1           CONSTANT NUMBER := 1000;
    c_NHASU_2           CONSTANT NUMBER := 100;
    c_NHASU_3           CONSTANT NUMBER := 1;
    c_NHASU_10          CONSTANT NUMBER := 10;
    c_NHASU_KBN_1       CONSTANT NUMBER := 1;       -- c_NHASU_1に対応
    c_NHASU_KBN_2       CONSTANT NUMBER := 0;       -- c_NHASU_2に対応
    c_NHASU_KBN_3       CONSTANT NUMBER := 2;       -- c_NHASU_3に対応
    c_NHASU_KBN_10      CONSTANT NUMBER := 3;       --c_NHASU_10に対応

    -- 実行区分
    c_NBATCH        CONSTANT NUMBER(1) := 0;        -- バッチから起動
    c_NTEST         CONSTANT NUMBER(1) := 2;        -- オンライン(税額試算)
    c_NBATCH_ZER    CONSTANT NUMBER(1)  := 3;       --バッチ(税率試算)

    -- 呼出区分
    c_CAL_KBN_TU        CONSTANT NUMBER(2) := 0;    -- (0:通常処理
    c_CAL_KBN_FK        CONSTANT NUMBER(2) := 1;    -- (1:賦課期日時点処理
    c_CAL_KBN_F4        CONSTANT NUMBER(2) := 2;    -- (2:H4/HH/C4処理

    -- 算定団体コード
    c_NDANTAI           CONSTANT NUMBER(2)  := 1;       -- 合併後算定団体コード

    -- 不均一課税
    c_NFKAZEI           CONSTANT NUMBER     := 1;       -- 不均一課税を行なう

    -- 市町村コード
    ISHICHOSON_CD                PLS_INTEGER;          -- 市町村コード
    c_KAMIINA_INA       CONSTANT PLS_INTEGER := 20209; -- 上伊那市

    N_INA_GENMEN          NUMBER := 0;                   -- 1:不均一対象
    N_INA_GENMEN_GAKU_K   NUMBER := 0;                   -- 上伊那用 減免額退避(全体)
    N_INA_GENMEN_GAKU_T   NUMBER := 0;                   -- 上伊那用 減免額退避(退職)
    N_INA_TAISHO          NUMBER := 0;                   -- 上伊那用 減免対象団体 0:高遠町, 1:長谷村
    N_INA_GENMEN_RITU     NUMBER := 0;                   -- 上伊那用 減免率

   -- 上伊那広域減免算出用
   IKINTO_CNT_20010     PLS_INTEGER;
   N_K_SHOTOKU_WARI_20010  NUMBER;
   N_K_SHISAN_WARI_20010   NUMBER;
   N_K_KINTO_WARI_20010    NUMBER;
   N_K_BYODO_WARI_20010    NUMBER;

   N_T_BYODO_WARI_20010    NUMBER;

    TYPE TSHIK   IS TABLE OF NUMBER(2)   INDEX BY BINARY_INTEGER;
    AlSHIK                TSHIK;                      -- 月別国保資格
    TYPE TSHITSU IS TABLE OF NUMBER(2)   INDEX BY BINARY_INTEGER;
    AlSHITSU              TSHITSU;                    -- 月別失業者資格
    --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
    MlSAN_KBN             MTNUMARRAY2;
    MlSANCNT              MTNUMARRAY3;
    MlSANCNT_K            MTNUMARRAY3;
    --  2024/05/06 ZCZL.ZHANGLEI ADD END

-------------------------------------------------------------------------------
-- ワークエリアの定義
-------------------------------------------------------------------------------

    NlRTN                   NUMBER(1);
    BlRTN                   BOOLEAN;
    VlMSG                   NVARCHAR2(100);

    -- 課税計算用ワーク
    NlKOJIN_CNT             NUMBER(3);      -- 計算個人件数
    NlMAX_TODOKEDE_BI       NUMBER(8);      -- 最大届出日
    NlMAX_JIYU              NUMBER(2);      -- 最大事由
    NlGENZON_KBN            NUMBER(1);      -- 現存区分
    NlGISEI_KBN             NUMBER(1);      -- 擬制区分
    NlSHOTOKU               NUMBER(12);     -- 所得
    NlROJIN                 NUMBER;         -- 老人数
    NlSENJU                 NUMBER;         -- 専従区分
    NlJOTO_KBN              NUMBER(1);      -- 譲渡区分
    NlKAZEI_KBN             NUMBER(1);      -- 課税区分
    NlMI_SHINKOKU_KBN       NUMBER(1);      -- 未申告区分
    NlCHOKA                 NUMBER(12,1);   -- 超過
    NlCHOKA2                NUMBER(15,3);   --超過
    NlKEIGEN_KINTO          NUMBER(10,3);   -- 軽減均等
    NlKEIGEN_BYODO          NUMBER(10,3);   -- 軽減平等
    NlKEIGEN_K_6_ZEN        NUMBER(10,3);   -- 軽減均等6 全体
    NlKEIGEN_B_6_ZEN        NUMBER(10,3);   -- 軽減平等6 全体
    NlKEIGEN_K_4_ZEN        NUMBER(10,3);   -- 軽減均等4 全体
    NlKEIGEN_B_4_ZEN        NUMBER(10,3);   -- 軽減平等4 全体
    NlKEIGEN_K_2_ZEN        NUMBER(10,3);   -- 軽減均等2 全体
    NlKEIGEN_B_2_ZEN        NUMBER(10,3);   -- 軽減平等2 全体
    NlKEIGEN_K_6_TAI        NUMBER(10,3);   -- 軽減均等6 退職
    NlKEIGEN_B_6_TAI        NUMBER(10,3);   -- 軽減平等6 退職
    NlKEIGEN_K_4_TAI        NUMBER(10,3);   -- 軽減均等4 退職
    NlKEIGEN_B_4_TAI        NUMBER(10,3);   -- 軽減平等4 退職
    NlKEIGEN_K_2_TAI        NUMBER(10,3);   -- 軽減均等2 退職
    NlKEIGEN_B_2_TAI        NUMBER(10,3);   -- 軽減平等2 退職
--年税額
    NlNENZEIGAKU            NUMBER(12,3);     --年税額
--退年税額--del
    NlTAINENZEIGAKU         NUMBER(12,3);     --退年税額--add
    NlSEISAN_KBN            NUMBER(1);      -- 清算区分
    NlNENZEIGAKU_WK         NUMBER(12,3);   -- 年税額ワーク
    NCNT_KAKUTEI            PLS_INTEGER;    -- 確定処理実施カウント
    NGENMINUS_NENDO         PLS_INTEGER;    -- 月割減額マイナス調整開始年度
    --コンスタント情報取得用
    ACONSPRM                A_CONS_PRM;     --パラメータの配列
    NPRMSUM                 NUMBER;         --パラメータの配列の長度
    NSTATUS                 PLS_INTEGER;    --戻り値

    MlSHIK_KBN              MTNUMARRAY2;    -- 各月資格区分
    MlIRYSHIK_KBN           MTNUMARRAY2;    -- 各月資格区分(医療)
    MlSHITSU_KBN            MTNUMARRAY2;    -- 各月失業資格区分
    MlKEIGEN_KBN            MTNUMARRAY1;    -- 各月軽減区分
    MlCHOKA_MAE             MTNUMARRAY10;   -- 限度超過前
    MlCNT                   MTNUMARRAY3;    -- 人員(各月有資格者数)
    MlZEIGAKU               MTNUMARRAY12;   -- 税額
    --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
    MlZEIGAKU2              MTNUMARRAY12;   -- 税額限度超過調整用
    MlSUMI                  MTNUMARRAY1;    -- 済
    MlTUKI                  MTNUMARRAY2;    -- 月数
    MlTAICNT                MTNUMARRAY3;    -- 退人員(各月有資格者数)
    MlTAIZEIGAKU            MTNUMARRAY12;   -- 退税額
    MlTAISUMI               MTNUMARRAY1;    -- 退済
    MlTAITUKI               MTNUMARRAY2;    -- 退月数
    MlZEIGAKU_SEKI          MTNUMARRAY12;   -- 積算算出用 税額
    MlSUMI_SEKI             MTNUMARRAY1;    -- 積算算出用 済
    MlTUKI_SEKI             MTNUMARRAY2;    -- 積算算出用 月数
    MlCHOKA_SEKI            MTNUMARRAY10;   -- 積算算出用 限度超過
    MlKAHYO_SEKI            MTNUMARRAY12;   -- 積算算出用 課標
    MlNEN_CNT_SEKI          MTNUMARRAY3;    -- 積算算出用 年齢軽減人員(各月有資格者数)
    MlTAIZEIGAKU_SEKI       MTNUMARRAY12;   -- 積算算出用 退税額
    MlTAISUMI_SEKI          MTNUMARRAY1;    -- 積算算出用 退済
    MlTAITUKI_SEKI          MTNUMARRAY2;    -- 積算算出用 退月数
    MlTAICHOKA_SEKI         MTNUMARRAY10;   -- 積算算出用 退限度超過
    MlTAIKAHYO_SEKI         MTNUMARRAY12;   -- 積算算出用 退課標
    MlTAINEN_CNT_SEKI       MTNUMARRAY3;    -- 積算算出用 退年齢軽減人員(各月有資格者数)

    NlNENREI_KEIGEN         NUMBER(1);      -- 年齢軽減
    NlSINSHO_GENMEN         NUMBER(1);      -- 身障減免
    NlGENMENRITU            NUMBER(1);      -- 減免率計算

    Nl22Ika_CNT             NUMBER(3);      -- 22才以下人員
    Nl22IkaTai_CNT          NUMBER(3);      -- 22才以下人員(退職)
    NlShotokuKei            NUMBER(12);     -- 所得合計
    NlShogai_CNT            NUMBER(3);      -- 身障対象人員

    -- システム条件
    NlJGENDOGAKU            NUMBER;         -- 限度額
    NlJKINTO                NUMBER;         -- 均等割額
    NlJBYODO                NUMBER;         -- 平等割額
    NlJKEIGEN1              NUMBER;         -- 軽減区分1(6割)
    NlJKGEN1                NUMBER;         -- 軽減均等割1(6割)
    NlJBGEN1                NUMBER;         -- 軽減平等割1(6割)
    NlJKEIGEN2              NUMBER;         -- 軽減区分2(4割)
    NlJKGEN2                NUMBER;         -- 軽減均等割2(4割)
    NlJBGEN2                NUMBER;         -- 軽減平等割2(4割)
    NlJKEIGEN3              NUMBER;         -- 軽減区分3(2割)
    NlJKGEN3                NUMBER;         -- 軽減均等割3(2割)
    NlJBGEN3                NUMBER;         -- 軽減平等割3(2割)
    NlJHASU                 NUMBER;         -- 端数
    NlJNUSHI                NUMBER;         --主課税条件

    -- 出力用ワーク
    RlKIHON                 ZLBTKAI_KIHON_CAL%ROWTYPE;  -- 計算介護基本
    RlTAI                   ZLBTKAI_TAI_CAL%ROWTYPE;    -- 計算介護退職
    RlKIHON_IRY             ZLBTKIHON_CAL%ROWTYPE;      -- 計算基本

    RlEXT                   ZLBTEXT_CAL%ROWTYPE;    -- 計算賦課拡張

    NKENSAKU_TSUCHI_NO      NUMBER;         --減免額検索用通知書番号

    NSHOTOKU_2DANKAI        NUMBER;         -- 所得２段階有無
    NSHOTOKU_HANTEI_GAKU    NUMBER;         -- 所得割判定額
    NSHOTOKU_KAI_OVER       NUMBER;         -- 所得割率
    NSHOTOKU_KAI            NUMBER;         -- 所得割率２
    MlKAHYO                 MTNUMARRAY12;   -- 課標
    MlTAIKAHYO              MTNUMARRAY12;   -- 課標退職
    ITSUKI_HASU_KBN         PLS_INTEGER;    -- 月割端数調整区分
    IGENDO_HASU_KBN         PLS_INTEGER;    -- 限度超過額端数調整区分
    IGENMENNUSHI_KBN        PLS_INTEGER;    -- 減免計算世帯主課税条件
    IGENMENKEISAN_KBN       PLS_INTEGER;    -- 減免計算有無
    NSHISAN_KAI             NUMBER;         -- 医療資産割率
    MlOUEKI                 MTNUMARRAY12;   -- 応益係数
    MlOUNOU                 MTNUMARRAY12;   -- 応能係数
    NlPER                   MTNUMARRAY3;    --応益係数 idx1=50%,idx2=70%,idx3=90%,idx4=100%
    NlCNT                   MTNUMARRAY3;    --月毎の応益係数それぞれの該当件数(ひと月4要素×12)
                                            -- idx 1- 4：4月 ・・・ idx45-48：3月

    NLOOP_CNT_NOW           NUMBER;
    NLOOP_CNT_MAX           NUMBER;
    NGENMEN_USE_KBN         NUMBER := -1;       -- ZLBTGENMEN_KOJIN に当該年度のデータが登録されているかどうか
                                                --   -1：初期値、0：なし、1：あり

    NGENMEN_USE_SKBN        NUMBER := -1;       -- ZLBTGENMEN_SETAI に当該年度のデータが登録されているかどうか
                                                --   -1：初期値、0：なし、1：あり
    NGENMEN_USE_SRITSU      NUMBER := 0;        -- 世帯減免の減免率のセット
    NGENMEN_EXIST_KBN       NUMBER;             -- ZLBTGENMEN_KOJIN に世帯員が１人以上減免データあり
    NGENMEN_KOJIN_KBN       NUMBER;             -- ZLBTGENMEN_KOJIN に減免データあり
    NGENMEN_KOJIN_KBN2      NUMBER;             -- ZLBTGENMEN_KOJIN に減免データあり ＆ その人が資格ありで計算対象になっている
                                                --  → ex.擬主に減免データがあると、計算対象でないのに２回目の減免計算を行ってしまう。
                                                --        これを防ぐためのフラグです。
    vSQL                    VARCHAR2(4000);
    type cur_type is ref    cursor;             -- カーソル変数のオブジェクト定義
    cur_DynamicSQL          cur_type;           -- カーソル変数定義
    TYPE type_ZLBTGENMEN_KOJIN_CAL IS RECORD(   -- データをセットする配列の宣言
        --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
        --KOKU_SETAI_NO            NUMBER(12),
        KOKU_SETAI_NO            NUMBER,
        SANTEIDANTAI_CD          NUMBER(2),
        --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
        --KOJIN_NO                 NUMBER(12),
        KOJIN_NO                 NUMBER,
        CHOTEI_NENDO             NUMBER(4),
        NENDO_BUN                NUMBER(4),
        R_NO                     NUMBER(5),
        TSUCHI_NO                NUMBER(12),
        SHINSEI_NO               NUMBER(12),
        SHINSEI_BI               NUMBER(8),
        TORIKESHI_BI             NUMBER(8),
        GENMEN_JIYU              NUMBER(2),
        YUSEN_KBN                NUMBER(1),
        TEKIYO_KBN               NUMBER(1),
        I_SHOTOKU_KISO           NUMBER(12),
        I_SISANZEI_KISO          NUMBER(12),
        I_KINTOWARI_KISO         NUMBER(12),
        I_BYODOWARI_KISO         NUMBER(12),
        I_NENZEI_KISO            NUMBER(12),
        K_SHOTOKU_KISO           NUMBER(12),
        K_SISANZEI_KISO          NUMBER(12),
        K_KINTOWARI_KISO         NUMBER(12),
        K_BYODOWARI_KISO         NUMBER(12),
        K_NENZEI_KISO            NUMBER(12),
        S_SHOTOKU_KISO           NUMBER(12),
        S_SISANZEI_KISO          NUMBER(12),
        S_KINTOWARI_KISO         NUMBER(12),
        S_BYODOWARI_KISO         NUMBER(12),
        S_NENZEI_KISO            NUMBER(12),
        IT_SHOTOKU_KISO          NUMBER(12),
        IT_SISANZEI_KISO         NUMBER(12),
        IT_KINTOWARI_KISO        NUMBER(12),
        IT_BYODOWARI_KISO        NUMBER(12),
        IT_NENZEI_KISO           NUMBER(12),
        KT_SHOTOKU_KISO          NUMBER(12),
        KT_SISANZEI_KISO         NUMBER(12),
        KT_KINTOWARI_KISO        NUMBER(12),
        KT_BYODOWARI_KISO        NUMBER(12),
        KT_NENZEI_KISO           NUMBER(12),
        ST_SHOTOKU_KISO          NUMBER(12),
        ST_SISANZEI_KISO         NUMBER(12),
        ST_KINTOWARI_KISO        NUMBER(12),
        ST_BYODOWARI_KISO        NUMBER(12),
        ST_NENZEI_KISO           NUMBER(12),
        I_SHOTOKU_RITSU          NUMBER(3),
        I_SISANZEI_RITSU         NUMBER(3),
        I_KINTOWARI_RITSU        NUMBER(3),
        I_BYODOWARI_RITSU        NUMBER(3),
        I_NENZEI_RITSU           NUMBER(3),
        K_SHOTOKU_RITSU          NUMBER(3),
        K_SISANZEI_RITSU         NUMBER(3),
        K_KINTOWARI_RITSU        NUMBER(3),
        K_BYODOWARI_RITSU        NUMBER(3),
        K_NENZEI_RITSU           NUMBER(3),
        S_SHOTOKU_RITSU          NUMBER(3),
        S_SISANZEI_RITSU         NUMBER(3),
        S_KINTOWARI_RITSU        NUMBER(3),
        S_BYODOWARI_RITSU        NUMBER(3),
        S_NENZEI_RITSU           NUMBER(3),
        I_SHOTOKU_GENGAKU        NUMBER(12),
        I_SISANZEI_GENGAKU       NUMBER(12),
        I_KINTOWARI_GENGAKU      NUMBER(12),
        I_BYODOWARI_GENGAKU      NUMBER(12),
        I_NENZEI_GENGAKU         NUMBER(12),
        I_GENGAKU_KEI            NUMBER(12),
        K_SHOTOKU_GENGAKU        NUMBER(12),
        K_SISANZEI_GENGAKU       NUMBER(12),
        K_KINTOWARI_GENGAKU      NUMBER(12),
        K_BYODOWARI_GENGAKU      NUMBER(12),
        K_NENZEI_GENGAKU         NUMBER(12),
        K_GENGAKU_KEI            NUMBER(12),
        S_SHOTOKU_GENGAKU        NUMBER(12),
        S_SISANZEI_GENGAKU       NUMBER(12),
        S_KINTOWARI_GENGAKU      NUMBER(12),
        S_BYODOWARI_GENGAKU      NUMBER(12),
        S_NENZEI_GENGAKU         NUMBER(12),
        S_GENGAKU_KEI            NUMBER(12),
        IT_SHOTOKU_GENGAKU       NUMBER(12),
        IT_SISANZEI_GENGAKU      NUMBER(12),
        IT_KINTOWARI_GENGAKU     NUMBER(12),
        IT_BYODOWARI_GENGAKU     NUMBER(12),
        IT_NENZEI_GENGAKU        NUMBER(12),
        IT_GENGAKU_KEI           NUMBER(12),
        KT_SHOTOKU_GENGAKU       NUMBER(12),
        KT_SISANZEI_GENGAKU      NUMBER(12),
        KT_KINTOWARI_GENGAKU     NUMBER(12),
        KT_BYODOWARI_GENGAKU     NUMBER(12),
        KT_NENZEI_GENGAKU        NUMBER(12),
        KT_GENGAKU_KEI           NUMBER(12),
        ST_SHOTOKU_GENGAKU       NUMBER(12),
        ST_SISANZEI_GENGAKU      NUMBER(12),
        ST_KINTOWARI_GENGAKU     NUMBER(12),
        ST_BYODOWARI_GENGAKU     NUMBER(12),
        ST_NENZEI_GENGAKU        NUMBER(12),
        ST_GENGAKU_KEI           NUMBER(12),
        I_GENMEN_4               NUMBER(1),
        I_GENMEN_5               NUMBER(1),
        I_GENMEN_6               NUMBER(1),
        I_GENMEN_7               NUMBER(1),
        I_GENMEN_8               NUMBER(1),
        I_GENMEN_9               NUMBER(1),
        I_GENMEN_10              NUMBER(1),
        I_GENMEN_11              NUMBER(1),
        I_GENMEN_12              NUMBER(1),
        I_GENMEN_1               NUMBER(1),
        I_GENMEN_2               NUMBER(1),
        I_GENMEN_3               NUMBER(1),
        K_GENMEN_4               NUMBER(1),
        K_GENMEN_5               NUMBER(1),
        K_GENMEN_6               NUMBER(1),
        K_GENMEN_7               NUMBER(1),
        K_GENMEN_8               NUMBER(1),
        K_GENMEN_9               NUMBER(1),
        K_GENMEN_10              NUMBER(1),
        K_GENMEN_11              NUMBER(1),
        K_GENMEN_12              NUMBER(1),
        K_GENMEN_1               NUMBER(1),
        K_GENMEN_2               NUMBER(1),
        K_GENMEN_3               NUMBER(1),
        S_GENMEN_4               NUMBER(1),
        S_GENMEN_5               NUMBER(1),
        S_GENMEN_6               NUMBER(1),
        S_GENMEN_7               NUMBER(1),
        S_GENMEN_8               NUMBER(1),
        S_GENMEN_9               NUMBER(1),
        S_GENMEN_10              NUMBER(1),
        S_GENMEN_11              NUMBER(1),
        S_GENMEN_12              NUMBER(1),
        S_GENMEN_1               NUMBER(1),
        S_GENMEN_2               NUMBER(1),
        S_GENMEN_3               NUMBER(1),
        SHIKAKU_TUKISU           NUMBER(2),
        SHIKAKU_TUKISU_K         NUMBER(2),
        GENMENGAKU_KEI           NUMBER(12),
        GENMENGAKU_T_KEI         NUMBER(12),
        SAKUJO_KBN               NUMBER(1),
        I_GENGAKU_MAE            NUMBER(12),
        I_GENGAKU                NUMBER(12),
        K_GENGAKU_MAE            NUMBER(12),
        K_GENGAKU                NUMBER(12),
        S_GENGAKU_MAE            NUMBER(12),
        S_GENGAKU                NUMBER(12),
        IT_GENGAKU_MAE           NUMBER(12),
        IT_GENGAKU               NUMBER(12),
        KT_GENGAKU_MAE           NUMBER(12),
        KT_GENGAKU               NUMBER(12),
        ST_GENGAKU_MAE           NUMBER(12),
        ST_GENGAKU               NUMBER(12),
        SYS_SAKUSEIBI            NUMBER(8),
        SYS_KOSHINBI             NUMBER(8),
        SYS_JIKAN                NUMBER(6),
        SYS_SHOKUINKOJIN_NO      CHAR(12),
        SYS_TANMATSU_NO          NVARCHAR2(63)
--2025/08/11 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
       ,KDM_SHOTOKU_KISO         NUMBER(12),
        KDM_SISANZEI_KISO        NUMBER(12),
        KDM_KINTOWARI_KISO       NUMBER(12),
        KDM_KINTOWARI_18_KISO    NUMBER(12),
        KDM_BYODOWARI_KISO       NUMBER(12),
        KDM_NENZEI_KISO          NUMBER(12),
        KDM_SHOTOKU_RITSU        NUMBER(3),
        KDM_SISANZEI_RITSU       NUMBER(3),
        KDM_KINTOWARI_RITSU      NUMBER(3),
        KDM_KINTOWARI_18_RITSU   NUMBER(3),
        KDM_BYODOWARI_RITSU      NUMBER(3),
        KDM_NENZEI_RITSU         NUMBER(3),
        KDM_SHOTOKU_GENGAKU      NUMBER(12),
        KDM_SISANZEI_GENGAKU     NUMBER(12),
        KDM_KINTOWARI_GENGAKU    NUMBER(12),
        KDM_KINTOWARI_18_GENGAKU NUMBER(12),
        KDM_BYODOWARI_GENGAKU    NUMBER(12),
        KDM_NENZEI_GENGAKU       NUMBER(12),
        KDM_GENGAKU_KEI          NUMBER(12),
        KDM_GENMEN_4             NUMBER(1),
        KDM_GENMEN_5             NUMBER(1),
        KDM_GENMEN_6             NUMBER(1),
        KDM_GENMEN_7             NUMBER(1),
        KDM_GENMEN_8             NUMBER(1),
        KDM_GENMEN_9             NUMBER(1),
        KDM_GENMEN_10            NUMBER(1),
        KDM_GENMEN_11            NUMBER(1),
        KDM_GENMEN_12            NUMBER(1),
        KDM_GENMEN_1             NUMBER(1),
        KDM_GENMEN_2             NUMBER(1),
        KDM_GENMEN_3             NUMBER(1),
        KDM_GENGAKU_MAE          NUMBER(12),
        KDM_GENGAKU              NUMBER(12)
--2025/08/11 ZCZL.WANGMING ADD END
    );
    RwGENMENKOJIN                type_ZLBTGENMEN_KOJIN_CAL;
    NwNENZEIGAKU                 NUMBER(12,3);     -- 減免前の年税額を保存
    NwHASU                       NUMBER(12,3);     -- 減免前の端数  を保存
    NwNENZEIGAKU_TAI             NUMBER(12,3);     -- 減免前の年税額を保存
    NwHASU_TAI                   NUMBER(12,3);     -- 減免前の端数  を保存
    RlGENMEN_KOJIN  ZLBTGENMEN_KOJIN_TMP%ROWTYPE := NULL;    -- 減免個人TMP
    NwSHOTOKU_KISO_SUM           NUMBER(12);       -- 所得割基礎額
    NwSISANZEI_KISO_SUM          NUMBER(12);       -- 資産割基礎額
    NwKINTOWARI_KISO_SUM         NUMBER(12);       -- 均等割基礎額
    NwTSHOTOKU_KISO_SUM          NUMBER(12);       -- 所得割基礎額（退職）
    NwTSISANZEI_KISO_SUM         NUMBER(12);       -- 資産割基礎額（退職）
    NwTKINTOWARI_KISO_SUM        NUMBER(12);       -- 均等割基礎額（退職）
    NwSHOTOKU_GENGAKU_SUM        NUMBER(12);       -- 所得割減免額
    NwSISANZEI_GENGAKU_SUM       NUMBER(12);       -- 資産割減免額
    NwKINTOWARI_GENGAKU_SUM      NUMBER(12);       -- 均等割減免額
    NwBYODOWARI_GENGAKU_SUM      NUMBER(12);       -- 平等割減免額
    NwNENZEI_GENGAKU_SUM         NUMBER(12);       -- 年税減免額
    NwTSHOTOKU_GENGAKU_SUM       NUMBER(12);       -- 所得割減免額（退職）
    NwTSISANZEI_GENGAKU_SUM      NUMBER(12);       -- 資産割減免額（退職）
    NwTKINTOWARI_GENGAKU_SUM     NUMBER(12);       -- 均等割減免額（退職）
    NwTBYODOWARI_GENGAKU_SUM     NUMBER(12);       -- 平等割減免額（退職）
    NwTNENZEI_GENGAKU_SUM        NUMBER(12);       -- 年税減免額（退職）

    NFUKASHIRASU                 NUMBER;           -- 当年度賦課決定支払数
    NNOKIMATUKIBETSU             NUMBER;           -- 納期未到来期期別数
    NKANYUKI                     NUMBER;           -- 加入月数
    NTAISHOTOKU_GENGAKU        NUMBER DEFAULT 0; -- 所得割減免額（退職）
    NTAISISANZEI_GENGAKU       NUMBER DEFAULT 0; -- 資産割減免額（退職）
    NTAIKINTOWARI_GENGAKU      NUMBER DEFAULT 0; -- 均等割減免額（退職）
    NTAIBYODOWARI_GENGAKU      NUMBER DEFAULT 0; -- 平等割減免額（退職）
    NSHOTOKU_GENGAKU           NUMBER DEFAULT 0; -- 所得割減免額
    NSISANZEI_GENGAKU          NUMBER DEFAULT 0; -- 資産割減免額
    NKINTOWARI_GENGAKU         NUMBER DEFAULT 0; -- 均等割減免額
    NBYODOWARI_GENGAKU         NUMBER DEFAULT 0; -- 平等割減免額
    --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
    NwNENZEI_MAE               NUMBER DEFAULT 0; -- 限度超過調整前年税額
    NwSANCHOKA_FLG             NUMBER DEFAULT 0; -- 産前産後かつ限度超過フラグ
    NKANYUTSUKI_CNT            NUMBER DEFAULT 0; -- 加入月数カウンタ
    NwGENDO_CHOKA              NUMBER(12,3);     -- 減免前限度超過額
    --  2024/05/06 ZCZL.ZHANGLEI ADD END
-------------------------------------------------------------------------------
-- カーソルの定義
-------------------------------------------------------------------------------
    -- 計算個人
    CURSOR ClKOJIN IS
        SELECT * FROM ZLBTKOJIN_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND TSUCHI_NO       = i_NNUSHI
           AND (F4_KAI_KBN = 1
               OR KAI_SHIK_4  = 1 OR KAI_SHIK_5  = 1 OR KAI_SHIK_6  = 1
               OR KAI_SHIK_7  = 1 OR KAI_SHIK_8  = 1 OR KAI_SHIK_9  = 1
               OR KAI_SHIK_10 = 1 OR KAI_SHIK_11 = 1 OR KAI_SHIK_12 = 1
               OR KAI_SHIK_1  = 1 OR KAI_SHIK_2  = 1 OR KAI_SHIK_3  = 1
               OR (KAI_GAI_BI   >= (i_NNENDO_BUN*10000)+401   AND
                   KAI_HIGAI_BI <  (i_NNENDO_BUN*10000)+10401 AND
                   KAI_HIGAI_BI <> 0                          AND
                   KAI_GAI_BI   <> KAI_HIGAI_BI
                  )
               )
           AND SYS_TANMATSU_NO = i_VTANMATSU;

-------------------------------------------------------------------------------
-- 優先区分(6-世帯／独自減免)の計算機能について、[当年度賦課決定支払数]、[納期未到来期期別数][加入月数]を取得する。
-------------------------------------------------------------------------------
    PROCEDURE subGetKibetsu
    IS
      NRONRIKIBETSU                NUMBER(2);              -- 論理期別
      NNOKIGENTSUKI                NUMBER(2);              -- 納期月
      RZLBTJOKEN                   ZLBTJOKEN%ROWTYPE;      -- システム条件（優先区分6用）
      CURSOR CKOJIN_CAL IS
        SELECT *
          FROM ZLBTKOJIN_CAL
         WHERE KOKU_SETAI_NO = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO = i_NNENDO
           AND NENDO_BUN = i_NNENDO_BUN
           AND TSUCHI_NO  = i_NNUSHI
           AND SYS_TANMATSU_NO = i_VTANMATSU;
      NLOOPCNT                     NUMBER;
      MlNOKI                       MTNUMARRAY1;            -- 納期
      NGENMEN                      NUMBER;                 -- 減免区分
      MlNOKI_KBN                   MTNUMARRAY1;
      MlSHIK                       MTNUMARRAY2;
      MlSHIK_FLG                   MTNUMARRAY1;
    BEGIN
      NFUKASHIRASU := 0;
      NNOKIMATUKIBETSU := 0;
      NKANYUKI := 0;
      NRONRIKIBETSU := 0;
      NNOKIGENTSUKI := 0;
      NGENMEN := 0;

      -- 減免区分の取扱い
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_4 = 1 THEN
        NGENMEN := 1;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_5 = 1 THEN
        NGENMEN := 2;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_6 = 1 THEN
        NGENMEN := 3;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_7 = 1 THEN
        NGENMEN := 4;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_8 = 1 THEN
        NGENMEN := 5;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_9 = 1 THEN
        NGENMEN := 6;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_10 = 1 THEN
        NGENMEN := 7;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_11 = 1 THEN
        NGENMEN := 8;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_12 = 1 THEN
        NGENMEN := 9;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_1 = 1 THEN
        NGENMEN := 10;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_2 = 1 THEN
        NGENMEN := 11;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.K_GENMEN_3 = 1 THEN
        NGENMEN := 12;
      END IF;

      -- [当年度賦課決定支払数]、[納期未到来期期別数]取得する。
      -- ZLBTJOKENデータを取得する。
      SELECT *
        INTO RZLBTJOKEN
        FROM ZLBTJOKEN
       WHERE NENDO = i_NNENDO
         AND SANTEIDANTAI_CD = i_NDANTAI;
      MlNOKI(1)  := RZLBTJOKEN.NOKI_1;
      MlNOKI(2)  := RZLBTJOKEN.NOKI_2;
      MlNOKI(3)  := RZLBTJOKEN.NOKI_3;
      MlNOKI(4)  := RZLBTJOKEN.NOKI_4;
      MlNOKI(5)  := RZLBTJOKEN.NOKI_5;
      MlNOKI(6)  := RZLBTJOKEN.NOKI_6;
      MlNOKI(7)  := RZLBTJOKEN.NOKI_7;
      MlNOKI(8)  := RZLBTJOKEN.NOKI_8;
      MlNOKI(9)  := RZLBTJOKEN.NOKI_9;
      MlNOKI(10) := RZLBTJOKEN.NOKI_10;
      MlNOKI(11) := RZLBTJOKEN.NOKI_11;
      MlNOKI(12) := RZLBTJOKEN.NOKI_12;
      MlNOKI(13) := RZLBTJOKEN.NOKI_13;

      -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)を取得
      FOR NIDX IN 1..13 LOOP
        IF MlNOKI(NIDX) IN (2, 3, 4) THEN
          MlNOKI_KBN(NIDX) := 1;
        ELSE
          MlNOKI_KBN(NIDX) := 0;
        END IF;
      END LOOP;

      -- ZLBTJOKENに減免区分で指定された月から有効な期別数を[当年度賦課決定支払数]として取得する。
      FOR NIDX IN NGENMEN..13 LOOP
        -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
        IF MlNOKI_KBN(NIDX) = 1 THEN
          NFUKASHIRASU := NFUKASHIRASU + 1;     -- 当年度賦課決定支払数
        END IF;
      END LOOP;

      -- ZLBTSHUNOJKNKより、論理期別、納期月を取得する。
      SELECT RONRIKIBETSU, TSUKI
        INTO NRONRIKIBETSU, NNOKIGENTSUKI
        FROM ZLBTSHUNOJKNK
       WHERE KAMOKU_CD = 15
         AND KAMOKUS_CD = 1
         AND KIWARIDANTAI_CD = i_NDANTAI
         AND DANTAING_KBN　=　0
         AND CHOTEINENDO = i_NNENDO
         AND GENNENKANEN_KBN = 0
         AND NOKIGEN >= RlGENMEN_KOJIN.SHINSEI_BI
         AND ROWNUM = 1;

      -- 納期月以降の有効な論理期数を[納期未到来期期別数]として取得する。
      RlGENMEN_KOJIN.K_GENMEN_4  := 0;
      RlGENMEN_KOJIN.K_GENMEN_5  := 0;
      RlGENMEN_KOJIN.K_GENMEN_6  := 0;
      RlGENMEN_KOJIN.K_GENMEN_7  := 0;
      RlGENMEN_KOJIN.K_GENMEN_8  := 0;
      RlGENMEN_KOJIN.K_GENMEN_9  := 0;
      RlGENMEN_KOJIN.K_GENMEN_10 := 0;
      RlGENMEN_KOJIN.K_GENMEN_11 := 0;
      RlGENMEN_KOJIN.K_GENMEN_12 := 0;
      RlGENMEN_KOJIN.K_GENMEN_1  := 0;
      RlGENMEN_KOJIN.K_GENMEN_2  := 0;
      RlGENMEN_KOJIN.K_GENMEN_3  := 0;
      FOR NLOOPCNT IN NRONRIKIBETSU..13 LOOP
        CASE NLOOPCNT
          WHEN 1 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_4 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 2 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_5 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 3 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_6 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 4 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_7 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 5 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_8 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 6 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_9 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 7 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_10 := 1;           -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 8 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_11 := 1;           -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 9 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_12 := 1;           -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 10 THEN                                   -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_1 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 11 THEN                                   -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_2 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 12 THEN                                   -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.K_GENMEN_3 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 13 THEN                                   -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
            END IF;
          ELSE
            NULL;
        END CASE;
      END LOOP;

      -- 納期未到来期を減免有として扱い更新を行う
      UPDATE ZLBTGENMEN_KOJIN_TMP
         SET K_GENMEN_4  = RlGENMEN_KOJIN.K_GENMEN_4,
             K_GENMEN_5  = RlGENMEN_KOJIN.K_GENMEN_5,
             K_GENMEN_6  = RlGENMEN_KOJIN.K_GENMEN_6,
             K_GENMEN_7  = RlGENMEN_KOJIN.K_GENMEN_7,
             K_GENMEN_8  = RlGENMEN_KOJIN.K_GENMEN_8,
             K_GENMEN_9  = RlGENMEN_KOJIN.K_GENMEN_9,
             K_GENMEN_10 = RlGENMEN_KOJIN.K_GENMEN_10,
             K_GENMEN_11 = RlGENMEN_KOJIN.K_GENMEN_11,
             K_GENMEN_12 = RlGENMEN_KOJIN.K_GENMEN_12,
             K_GENMEN_1  = RlGENMEN_KOJIN.K_GENMEN_1,
             K_GENMEN_2  = RlGENMEN_KOJIN.K_GENMEN_2,
             K_GENMEN_3  = RlGENMEN_KOJIN.K_GENMEN_3
       WHERE KOKU_SETAI_NO   = RlGENMEN_KOJIN.KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = RlGENMEN_KOJIN.SANTEIDANTAI_CD
         AND NENDO_BUN       = RlGENMEN_KOJIN.NENDO_BUN
         AND SYS_TANMATSU_NO = RlGENMEN_KOJIN.SYS_TANMATSU_NO;

      -- ZLBTGENMEN_KOJIN_CALの減免区分を更新する。
      UPDATE ZLBTGENMEN_KOJIN_CAL
         SET K_GENMEN_4  = RlGENMEN_KOJIN.K_GENMEN_4,
             K_GENMEN_5  = RlGENMEN_KOJIN.K_GENMEN_5,
             K_GENMEN_6  = RlGENMEN_KOJIN.K_GENMEN_6,
             K_GENMEN_7  = RlGENMEN_KOJIN.K_GENMEN_7,
             K_GENMEN_8  = RlGENMEN_KOJIN.K_GENMEN_8,
             K_GENMEN_9  = RlGENMEN_KOJIN.K_GENMEN_9,
             K_GENMEN_10 = RlGENMEN_KOJIN.K_GENMEN_10,
             K_GENMEN_11 = RlGENMEN_KOJIN.K_GENMEN_11,
             K_GENMEN_12 = RlGENMEN_KOJIN.K_GENMEN_12,
             K_GENMEN_1  = RlGENMEN_KOJIN.K_GENMEN_1,
             K_GENMEN_2  = RlGENMEN_KOJIN.K_GENMEN_2,
             K_GENMEN_3  = RlGENMEN_KOJIN.K_GENMEN_3
       WHERE KOKU_SETAI_NO   = RlGENMEN_KOJIN.KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = RlGENMEN_KOJIN.SANTEIDANTAI_CD
         AND NENDO_BUN       = RlGENMEN_KOJIN.NENDO_BUN
         AND SYS_TANMATSU_NO = RlGENMEN_KOJIN.SYS_TANMATSU_NO;

      -- 世帯員の加入状況を串刺しし、世帯の[加入月数]を取得する。
      FOR NIDX IN 1..12 LOOP
        MlSHIK_FLG(NIDX) := 0;
      END LOOP;
      -- ZLBTKOJIN_CALから資格区分を取得する
      FOR CREC IN CKOJIN_CAL LOOP
        MlSHIK(1) := NVL (CREC.SHIK_4, 0);
        MlSHIK(2) := NVL (CREC.SHIK_5, 0);
        MlSHIK(3) := NVL (CREC.SHIK_6, 0);
        MlSHIK(4) := NVL (CREC.SHIK_7, 0);
        MlSHIK(5) := NVL (CREC.SHIK_8, 0);
        MlSHIK(6) := NVL (CREC.SHIK_9, 0);
        MlSHIK(7) := NVL (CREC.SHIK_10, 0);
        MlSHIK(8) := NVL (CREC.SHIK_11, 0);
        MlSHIK(9) := NVL (CREC.SHIK_12, 0);
        MlSHIK(10) := NVL (CREC.SHIK_1, 0);
        MlSHIK(11) := NVL (CREC.SHIK_2, 0);
        MlSHIK(12) := NVL (CREC.SHIK_3, 0);
        FOR NIDX IN 1..12 LOOP
          -- 擬主、特同は含まない
          IF MlSHIK(NIDX) IN (1, 3, 11, 13, 21, 23) AND MlSHIK_FLG(NIDX) = 0 THEN
            MlSHIK_FLG(NIDX) := 1;
          END IF;
        END LOOP;
      END LOOP;
      -- 加入月数を取得する。
      FOR NIDX IN 1..12 LOOP
        IF MlSHIK_FLG(NIDX) = 1 THEN
          NKANYUKI := NKANYUKI + 1;
        END IF;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END subGetKibetsu;

-------------------------------------------------------------------------------
-- 31 退職減免率(額)の取得処理
-------------------------------------------------------------------------------
    PROCEDURE subGenmenritsu_TAI IS

    BEGIN
      -- システム条件・減免率が1の場合
      -- 減免区分が1
     IF NlGENMENRITU = 1 AND RlEXT.GENMEN_KBN = 1 THEN
       -- 減免額セット(退職)
       RlTAI.GENMEN := TRUNC(RlTAI.NENZEI * (RlEXT.GENMEN_RITSU/100) + 0.9);
     END IF;

    END subGenmenritsu_TAI;

-------------------------------------------------------------------------------
-- 30 減免率(額)の取得処理
-------------------------------------------------------------------------------
    PROCEDURE subGenmenritsu IS

    BEGIN
     -- システム条件・減免率が1の場合
     -- 減免区分が1
      IF NlGENMENRITU = 1 AND RlEXT.GENMEN_KBN = 1 THEN
         -- 減免額セット
          RlKIHON.GENMEN := TRUNC(RlKIHON.NENZEI * (RlEXT.GENMEN_RITSU/100) + 0.9);
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        NlRTN := c_NERR;
        VlMSG := 'subGenmenritsu 減免率取得(国保世帯番号='||i_NSETAI||')'||SQLERRM;

    END subGenmenritsu;

-------------------------------------------------------------------------------
-- 29 障害者減免の取得処理
-------------------------------------------------------------------------------
    PROCEDURE subShogaiGenmen IS

    BEGIN

      -- 減免額と端数を除いた年税額を算出させる為に減額計を暫定算出
      RlKIHON.TSUKIWARI_GEN := RlKIHON.SEKISAN - RlKIHON.GENDO_CHOKA        -- 限度超過
                                               - RlKIHON.KEIGEN_K_WARI      -- 均等割り
                                               - RlKIHON.KEIGEN_B_WARI      -- 平等割
                                               - NlNENZEIGAKU;              -- 月割後の年税額

      RlKIHON.GENGAKU_KEI   :=                   RlKIHON.GENDO_CHOKA        -- 限度超過
                                               + RlKIHON.KEIGEN_K_WARI      -- 均等割り
                                               + RlKIHON.KEIGEN_B_WARI      -- 平等割
                                               + RlEXT.KAI_NENREI_KEIGEN    -- 年齢軽減
                                               + RlKIHON.TSUKIWARI_GEN;     -- 月割り減

      RlTAI.TSUKIWARI_GEN := RlTAI.SEKISAN - RlTAI.GENDO_CHOKA              -- 限度超過
                                               - RlTAI.KEIGEN_K_WARI        -- 均等割り
                                               - RlTAI.KEIGEN_B_WARI        -- 平等割
                                               - NlTAINENZEIGAKU;           -- 月割後の年税額

      RlTAI.GENGAKU_KEI   :=                   RlTAI.GENDO_CHOKA            -- 限度超過
                                               + RlTAI.KEIGEN_K_WARI        -- 均等割り
                                               + RlTAI.KEIGEN_B_WARI        -- 平等割
                                               + RlEXT.KAI_NENREI_KEIGEN_T  -- 年齢軽減
                                               + RlTAI.TSUKIWARI_GEN;       -- 月割り減

      -- 身障減免有り
      IF NlSINSHO_GENMEN = 1  THEN

        -- 障害者が世帯に1人以上存在
        IF NlShogai_CNT > 0 THEN

          -- 障害者減免額 = 医療保険料(積算税額-減額合計)*障害減免率  (少数点切り上げ) ※障害減免率はZLBSKCALMAINでセットしている為
          IF (RlKIHON.SEKISAN - RlKIHON.GENGAKU_KEI) > 0 THEN
            RlEXT.KAI_SHOGAI_GENMEN := TRUNC((RlKIHON.SEKISAN - RlKIHON.GENGAKU_KEI) * (RlEXT.SHOGAI_RITSU/100) + 0.9);
          ELSE
            RlEXT.KAI_SHOGAI_GENMEN := 0;
          END IF;

        -- 障害者(退職)が世帯に1人以上存在
            -- 障害者減免額 = 医療保険料(積算税額-減額合計)*障害減免率  (少数点切り上げ)
            IF (RlTAI.SEKISAN - RlTAI.GENGAKU_KEI) > 0 THEN
              RlEXT.KAI_SHOGAI_GENMEN_T := TRUNC((RlTAI.SEKISAN - RlTAI.GENGAKU_KEI) * (RlEXT.SHOGAI_RITSU/100) + 0.9);
            ELSE
              RlEXT.KAI_SHOGAI_GENMEN_T := 0;
            END IF;
        END IF;
      END IF;

    END subShogaiGenmen;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
    PROCEDURE funcGetGenmen IS
        BFOUND  BOOLEAN := FALSE;
        CURSOR CKIHON_1ST IS
          SELECT TSUCHI_NO, GENMEN
            FROM ZLBTKAI_KIHON_N
            WHERE KOKU_SETAI_NO   = i_NSETAI      --国保世帯番号
              AND SANTEIDANTAI_CD = i_NDANTAI     --算定団体
              AND CHOTEI_NENDO    = i_NNENDO      --調定年度
              AND NENDO_BUN       = i_NNENDO_BUN  --年度分
              AND NUSHI_KOJIN_NO  = DECODE(NlJNUSHI, 0, NUSHI_KOJIN_NO, i_NNUSHI);  -- 主課税でないときは主個人番号で絞り込まない
        CURSOR CKIHON_2ND IS
          SELECT TSUCHI_NO, GENMEN
            FROM ZLBTKAI_KIHON_N
            WHERE KOKU_SETAI_NO   = i_NSETAI      --国保世帯番号
              AND SANTEIDANTAI_CD = i_NDANTAI     --算定団体
              AND CHOTEI_NENDO    = i_NNENDO_BUN  --調定年度（＝年度分）
              AND NENDO_BUN       = i_NNENDO_BUN  --年度分
              AND NUSHI_KOJIN_NO  = DECODE(NlJNUSHI, 0, NUSHI_KOJIN_NO, i_NNUSHI);  -- 主課税でないときは主個人番号で絞り込まない
    BEGIN
        RlKIHON.GENMEN := 0;
        NKENSAKU_TSUCHI_NO := NULL;
        FOR CREC IN CKIHON_1ST LOOP
            RlKIHON.GENMEN     := CREC.GENMEN;
            NKENSAKU_TSUCHI_NO := CREC.TSUCHI_NO;
            BFOUND := TRUE;
            EXIT;
        END LOOP;
        IF BFOUND = FALSE AND i_NNENDO != i_NNENDO_BUN THEN
          --調定年度、年度分の指定で見つからない場合は、調定年度（＝年度分）、年度分から取得
            FOR CREC IN CKIHON_2ND LOOP
                RlKIHON.GENMEN     := CREC.GENMEN;
                NKENSAKU_TSUCHI_NO := CREC.TSUCHI_NO;
                EXIT;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subGetGenmen 計算個人取得(国保世帯番号='||i_NSETAI||')'||SQLERRM;
    END funcGetGenmen;
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
    PROCEDURE funcGetGenmen_TAI IS
        BFOUND  BOOLEAN := FALSE;
        CURSOR CTAI_1ST IS
          SELECT GENMEN
            FROM ZLBTKAI_TAI_N
            WHERE KOKU_SETAI_NO   = i_NSETAI      --国保世帯番号
              AND SANTEIDANTAI_CD = i_NDANTAI     --算定団体
              AND CHOTEI_NENDO    = i_NNENDO      --調定年度
              AND NENDO_BUN       = i_NNENDO_BUN  --年度分
              AND TSUCHI_NO = NKENSAKU_TSUCHI_NO; --世帯主個人番号
        CURSOR CTAI_2ND IS
          SELECT GENMEN
            FROM ZLBTKAI_TAI_N
            WHERE KOKU_SETAI_NO   = i_NSETAI      --国保世帯番号
              AND SANTEIDANTAI_CD = i_NDANTAI     --算定団体
              AND CHOTEI_NENDO    = i_NNENDO_BUN  --調定年度（＝年度分）
              AND NENDO_BUN       = i_NNENDO_BUN  --年度分
              AND TSUCHI_NO = NKENSAKU_TSUCHI_NO; --世帯主個人番号
    BEGIN
        RlTAI.GENMEN := 0;
        FOR CREC IN CTAI_1ST LOOP
            RlTAI.GENMEN := CREC.GENMEN;
            BFOUND := TRUE;
            EXIT;
        END LOOP;
        IF BFOUND = FALSE AND i_NNENDO != i_NNENDO_BUN THEN
          --調定年度、年度分の指定で見つからない場合は、調定年度（＝年度分）、年度分から取得
            FOR CREC IN CTAI_2ND LOOP
                RlTAI.GENMEN := CREC.GENMEN;
                EXIT;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'funcGetGenmen_TAI 計算個人取得(国保世帯番号='||i_NSETAI||')'||SQLERRM;
    END funcGetGenmen_TAI;
-------------------------------------------------------------------------------
-- 26 軽減額月割端数調整(退職)
-------------------------------------------------------------------------------
    PROCEDURE subKeigenChosei_Tai IS
    BEGIN

        -- 軽減均等割額
        IF NlKEIGEN_KINTO > 0 THEN
            NlKEIGEN_KINTO      := NlKEIGEN_KINTO + 0.01;
            RlTAI.KEIGEN_K_WARI := TRUNC(NlKEIGEN_KINTO);
        END IF;

        -- 軽減平等割額
        IF NlKEIGEN_BYODO > 0 THEN
            NlKEIGEN_BYODO      := NlKEIGEN_BYODO + 0.01;
            RlTAI.KEIGEN_B_WARI := TRUNC(NlKEIGEN_BYODO);
        END IF;
        -- 軽減均等６割
        IF NlKEIGEN_K_6_TAI > 0 THEN
            NlKEIGEN_K_6_TAI := NlKEIGEN_K_6_TAI + 0.01;
            RlTAI.KEIGEN_K_6 := TRUNC(NlKEIGEN_K_6_TAI);
        END IF;
        -- 軽減均等４割
        IF NlKEIGEN_K_4_TAI > 0 THEN
            NlKEIGEN_K_4_TAI := NlKEIGEN_K_4_TAI + 0.01;
            RlTAI.KEIGEN_K_4 := TRUNC(NlKEIGEN_K_4_TAI);
        END IF;
        -- 軽減均等２割
        IF NlKEIGEN_K_2_TAI > 0 THEN
            NlKEIGEN_K_2_TAI := NlKEIGEN_K_2_TAI + 0.01;
            RlTAI.KEIGEN_K_2 := TRUNC(NlKEIGEN_K_2_TAI);
        END IF;
        -- 軽減平等６割
        IF NlKEIGEN_B_6_TAI > 0 THEN
            NlKEIGEN_B_6_TAI := NlKEIGEN_B_6_TAI + 0.01;
            RlTAI.KEIGEN_B_6 := TRUNC(NlKEIGEN_B_6_TAI);
        END IF;
        -- 軽減平等４割
        IF NlKEIGEN_B_4_TAI > 0 THEN
            NlKEIGEN_B_4_TAI := NlKEIGEN_B_4_TAI + 0.01;
            RlTAI.KEIGEN_B_4 := TRUNC(NlKEIGEN_B_4_TAI);
        END IF;
        -- 軽減平等２割
        IF NlKEIGEN_B_2_TAI > 0 THEN
            NlKEIGEN_B_2_TAI := NlKEIGEN_B_2_TAI + 0.01;
            RlTAI.KEIGEN_B_2 := TRUNC(NlKEIGEN_B_2_TAI);
        END IF;

        NlKEIGEN_KINTO := 0;
        NlKEIGEN_BYODO := 0;
        NlKEIGEN_K_6_TAI := 0;  -- 軽減均等6 退職
        NlKEIGEN_B_6_TAI := 0;  -- 軽減平等6 退職
        NlKEIGEN_K_4_TAI := 0;  -- 軽減均等4 退職
        NlKEIGEN_B_4_TAI := 0;  -- 軽減平等4 退職
        NlKEIGEN_K_2_TAI := 0;  -- 軽減均等2 退職
        NlKEIGEN_B_2_TAI := 0;  -- 軽減平等2 退職

    END subKeigenChosei_Tai;
-------------------------------------------------------------------------------
-- 25 月割年税額算出(退職)
-------------------------------------------------------------------------------
    PROCEDURE subTukiwariNenzei_Tai IS
        NwIX              NUMBER(2);
        NTAINENZEIGAKU_2  NUMBER(15,3);
        NHasuKeta         NUMBER(1);
    BEGIN
        IF ITSUKI_HASU_KBN = 1 THEN
          NTAINENZEIGAKU_2 := NlTAINENZEIGAKU;
        END IF;

        FOR NwIX IN 1..12 LOOP

          IF ITSUKI_HASU_KBN = 1 THEN
            NTAINENZEIGAKU_2 := NTAINENZEIGAKU_2 + ((MlTAIZEIGAKU(NwIX) * MlTAITUKI(NwIX)) / 12);
          ELSIF ITSUKI_HASU_KBN = 2 THEN
            NHasuKeta := CASE NlJHASU
                           WHEN c_NHASU_KBN_1  THEN -3
                           WHEN c_NHASU_KBN_2  THEN -2
                           WHEN c_NHASU_KBN_3  THEN  0
                           WHEN c_NHASU_KBN_10 THEN -1
                           ELSE                     -2
                         END;
            NlTAINENZEIGAKU := NlTAINENZEIGAKU + ((TRUNC(MlTAIZEIGAKU(NwIX), NHasuKeta) * MlTAITUKI(NwIX)) / 12);
          ELSE
            NlTAINENZEIGAKU := NlTAINENZEIGAKU + ((MlTAIZEIGAKU(NwIX) * MlTAITUKI(NwIX)) / 12);
          END IF;
        END LOOP;

        IF ITSUKI_HASU_KBN = 1 THEN
          NlTAINENZEIGAKU := TRUNC(NTAINENZEIGAKU_2);
        ELSE
          NlTAINENZEIGAKU := TRUNC(NlTAINENZEIGAKU);
        END IF;
    END subTukiwariNenzei_Tai;
-------------------------------------------------------------------------------
-- 24 同税額月数算出(退職)
-------------------------------------------------------------------------------
    PROCEDURE subDouzeiTukisu_Tai IS
        NwIX1           NUMBER(2);
        NwIX2           NUMBER(2);
    BEGIN

        FOR NwIX1 IN 1..12 LOOP
            FOR NwIX2 IN 1..12 LOOP

                IF MlTAISUMI(NwIX2) != 1 THEN
                    IF MlTAIZEIGAKU(NwIX1) = MlTAIZEIGAKU(NwIX2) THEN
                        MlTAITUKI(NwIX1) := MlTAITUKI(NwIX1) + 1;
                        MlTAISUMI(NwIX2) := 1;
                    END IF;
                END IF;

            END LOOP;
        END LOOP;

    END subDouzeiTukisu_Tai;
-------------------------------------------------------------------------------
-- 24 同税額月数算出(退職積算用)
-------------------------------------------------------------------------------
    PROCEDURE subDouzeiTukisu_Tai_SEKI IS

        NwIX1           NUMBER(2);
        NwIX2           NUMBER(2);

    BEGIN

        FOR NwIX1 IN 1..12 LOOP

            FOR NwIX2 IN 1..12 LOOP

                IF MlTAISUMI_SEKI(NwIX2) != 1 THEN
                    IF MlTAIZEIGAKU_SEKI(NwIX1) = MlTAIZEIGAKU_SEKI(NwIX2) THEN
                        MlTAITUKI_SEKI(NwIX1) := MlTAITUKI_SEKI(NwIX1) + 1;
                        MlTAISUMI_SEKI(NwIX2) := 1;
                    END IF;
                END IF;

            END LOOP;

        END LOOP;

    END subDouzeiTukisu_Tai_SEKI;
-------------------------------------------------------------------------------
-- 24 同税額月数算出(退職限度超過用)
-------------------------------------------------------------------------------
    PROCEDURE subDouzeiTukisu_Tai_CHO IS
        NwIX1           NUMBER(2);
        NwIX2           NUMBER(2);
    BEGIN
        FOR NwIX1 IN 1..12 LOOP
            MlTAISUMI(NwIX1) := 0;
            MlTAITUKI(NwIX1) := 0;
        END LOOP;

        FOR NwIX1 IN 1..12 LOOP
            FOR NwIX2 IN 1..12 LOOP

                IF MlTAISUMI(NwIX2) != 1 THEN
                    IF MlTAICHOKA_SEKI(NwIX1) = MlTAICHOKA_SEKI(NwIX2) THEN
                        MlTAITUKI(NwIX1) := MlTAITUKI(NwIX1) + 1;
                        MlTAISUMI(NwIX2) := 1;
                    END IF;
                END IF;

            END LOOP;
        END LOOP;

    END subDouzeiTukisu_Tai_CHO;
-------------------------------------------------------------------------------
-- 23 月割税額セット(退職)
-------------------------------------------------------------------------------
    PROCEDURE subTukiwari_Tai IS
        NwIX            NUMBER(2);
        NwWORK          NUMBER(12,1);
        NwWORK2         NUMBER(15,3);
        NKAHYO_OVER     NUMBER;
        NKAHYO_DOWN     NUMBER;
        MwlSUMI_K       MTNUMARRAY1;              -- 済(経過措置用)
        MwlTUKI_K       MTNUMARRAY2;              -- 月数(経過措置用)
        MwlOUEKI_KIND   MTNUMARRAY3;              -- 応益係数
        MwGENMEN_UMU         MTNUMARRAY1;      -- 各月減免有無
        NwBYODOWARI          NUMBER(12) := 0;
        NwSHOTOKU_GENGAKU    NUMBER(12) := 0;  --計算用所得割減免額
        NwSISANZEI_GENGAKU   NUMBER(12) := 0;  --計算用資産割減免額
        NwKINTOWARI_GENGAKU  NUMBER(12) := 0;  --計算用均等割減免額
        NwBYODOWARI_GENGAKU  NUMBER(12) := 0;  --計算用平等割減免額
    BEGIN

        BEGIN
--          -- 計算緩和個人の各月応益係数を退避
          SELECT CASE TAISHO_KBN_4  WHEN 2 THEN OUEKI_4  ELSE 100 END,
                 CASE TAISHO_KBN_5  WHEN 2 THEN OUEKI_5  ELSE 100 END,
                 CASE TAISHO_KBN_6  WHEN 2 THEN OUEKI_6  ELSE 100 END,
                 CASE TAISHO_KBN_7  WHEN 2 THEN OUEKI_7  ELSE 100 END,
                 CASE TAISHO_KBN_8  WHEN 2 THEN OUEKI_8  ELSE 100 END,
                 CASE TAISHO_KBN_9  WHEN 2 THEN OUEKI_9  ELSE 100 END,
                 CASE TAISHO_KBN_10 WHEN 2 THEN OUEKI_10 ELSE 100 END,
                 CASE TAISHO_KBN_11 WHEN 2 THEN OUEKI_11 ELSE 100 END,
                 CASE TAISHO_KBN_12 WHEN 2 THEN OUEKI_12 ELSE 100 END,
                 CASE TAISHO_KBN_1  WHEN 2 THEN OUEKI_1  ELSE 100 END,
                 CASE TAISHO_KBN_2  WHEN 2 THEN OUEKI_2  ELSE 100 END,
                 CASE TAISHO_KBN_3  WHEN 2 THEN OUEKI_3  ELSE 100 END
            INTO MlOUEKI(1) ,MlOUEKI(2) ,MlOUEKI(3) ,MlOUEKI(4) ,MlOUEKI(5) ,MlOUEKI(6) ,
                 MlOUEKI(7) ,MlOUEKI(8) ,MlOUEKI(9) ,MlOUEKI(10),MlOUEKI(11),MlOUEKI(12)
            FROM ZLBTKANWA_SETAI_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI
             AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
          WHEN OTHERS THEN
            MlOUEKI(1) := 100;
            MlOUEKI(2) := 100;
            MlOUEKI(3) := 100;
            MlOUEKI(4) := 100;
            MlOUEKI(5) := 100;
            MlOUEKI(6) := 100;
            MlOUEKI(7) := 100;
            MlOUEKI(8) := 100;
            MlOUEKI(9) := 100;
            MlOUEKI(10):= 100;
            MlOUEKI(11):= 100;
            MlOUEKI(12):= 100;
        END;

        -- 応益係数が同じ月数MwlTUKI_Kとその時点の応益係数MwlOUEKI_KINDを算出
        -- 配列初期化
        FOR NwIX1 IN 1..12 LOOP
          MwlSUMI_K(NwIX1)       := 0;
          MwlTUKI_K(NwIX1)       := 0;
          MwlOUEKI_KIND(NwIX1)   := 0;
        END LOOP;

        FOR NwIX1 IN 1..12 LOOP
          FOR NwIX2 IN 1..12 LOOP
            IF MwlSUMI_K(NwIX2) != 1 THEN
              IF MlOUEKI(NwIX1) = MlOUEKI(NwIX2) THEN
                MwlTUKI_K(NwIX1) := MwlTUKI_K(NwIX1) + 1;
                MwlSUMI_K(NwIX2) := 1;
                MwlOUEKI_KIND(NwIX1) := MlOUEKI(NwIX1);
              END IF;
            END IF;
          END LOOP;
        END LOOP;

        -- 各月減免有無を退避
        MwGENMEN_UMU(1)  := RlGENMEN_KOJIN.K_GENMEN_4;
        MwGENMEN_UMU(2)  := RlGENMEN_KOJIN.K_GENMEN_5;
        MwGENMEN_UMU(3)  := RlGENMEN_KOJIN.K_GENMEN_6;
        MwGENMEN_UMU(4)  := RlGENMEN_KOJIN.K_GENMEN_7;
        MwGENMEN_UMU(5)  := RlGENMEN_KOJIN.K_GENMEN_8;
        MwGENMEN_UMU(6)  := RlGENMEN_KOJIN.K_GENMEN_9;
        MwGENMEN_UMU(7)  := RlGENMEN_KOJIN.K_GENMEN_10;
        MwGENMEN_UMU(8)  := RlGENMEN_KOJIN.K_GENMEN_11;
        MwGENMEN_UMU(9)  := RlGENMEN_KOJIN.K_GENMEN_12;
        MwGENMEN_UMU(10) := RlGENMEN_KOJIN.K_GENMEN_1;
        MwGENMEN_UMU(11) := RlGENMEN_KOJIN.K_GENMEN_2;
        MwGENMEN_UMU(12) := RlGENMEN_KOJIN.K_GENMEN_3;
----
--        --応益係数が同じ月数MwlTUKI_Kとその時点の応益係数MwlOUEKI_KINDを算出
--        -- 配列初期化
--        --以下の計算式で経過措置後の平等割の金額を応益係数の種類毎に算出
--        --平等割 Ａ＝TRUNC((システム条件の平等割額)×応益係数÷100×該当月数÷12))
--        --所得割2段階
--          -- 課税標準額が同額の月数MlTUKI_Kとその時点の課税標準額MwlKAHYO_KINDを算出
--          -- 配列初期化
--          --上で算出した課税標準額が同額の月数ごとに経過措置後の所得割２段階の計算を行う。
--            -- 所得割２段階対応
--          --算出した月数から年額を算出 （年額 ＝ 月毎の税額×月数÷月数12）

        FOR NwIX IN 1..12 LOOP
            IF RlTAI.KINTO_CNT > 0 THEN
                -- 全体人員と退職人員が同じであれば平等割額を足しこむ
                IF RlKIHON.KINTO_CNT = RlTAI.KINTO_CNT THEN
                    MlTAIZEIGAKU_SEKI(NwIX) := MlTAIZEIGAKU_SEKI(NwIX)
                                             + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
                END IF;
                -- 所得割2段階の所得足し込み
                IF NSHOTOKU_2DANKAI = 1 THEN
                    IF MlKAHYO_SEKI(NwIX) > NSHOTOKU_HANTEI_GAKU THEN
                        NKAHYO_OVER := TRUNC((MlKAHYO_SEKI(NwIX) - NSHOTOKU_HANTEI_GAKU) * (MlTAIKAHYO_SEKI(NwIX) / MlKAHYO_SEKI(NwIX)));
                        NKAHYO_DOWN := TRUNC(NSHOTOKU_HANTEI_GAKU * (MlTAIKAHYO_SEKI(NwIX) / MlKAHYO_SEKI(NwIX)));
                    ELSE
                        NKAHYO_OVER := 0;
                        NKAHYO_DOWN := MlTAIKAHYO_SEKI(NwIX);
                    END IF;
                    MlTAIZEIGAKU_SEKI(NwIX) := TRUNC(MlTAIZEIGAKU_SEKI(NwIX) + NKAHYO_OVER * NSHOTOKU_KAI_OVER / 100);
                    MlTAIZEIGAKU_SEKI(NwIX) := TRUNC(MlTAIZEIGAKU_SEKI(NwIX) + NKAHYO_DOWN * NSHOTOKU_KAI / 100);
                END IF;
            END IF;
          IF MlTAICNT(NwIX) > 0 THEN

--            --該当月の均等割算出
                -- 全体人員と退職人員が同じであれば平等割額を足しこむ
                IF MlCNT(NwIX) = MlTAICNT(NwIX) THEN
                    --優先区分が「個人／率／応能応益」または「世帯／率／応能応益」
                    IF RlGENMEN_KOJIN.YUSEN_KBN IN (0, 1) THEN
                      IF NLOOP_CNT_NOW = 1 THEN
                        MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                            + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
                        NwBYODOWARI        := NwBYODOWARI
                                            + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
                      ELSIF NLOOP_CNT_NOW = 2 THEN
                        IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割の場合
                          MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                              + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                              - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN1)
                                              * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                          NwBYODOWARI        := NwBYODOWARI
                                              + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                              - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN1)
                                              * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN    -- 軽減4割の場合
                          MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                              + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                              - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2)
                                              * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                          NwBYODOWARI        := NwBYODOWARI
                                              + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                              - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2)
                                              * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN    -- 軽減2割の場合
                          MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                              + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                              - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN3)
                                              * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                          NwBYODOWARI        := NwBYODOWARI
                                              + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                              - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN3)
                                              * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                        ELSE
                          MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                              + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                              - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                              * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                          NwBYODOWARI        := NwBYODOWARI
                                              + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                              - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                              * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                        END IF;
                      END IF;
                    ELSE
                      MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                       + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
                    END IF;
                END IF;
                -- 所得割2段階の所得足し込み
                IF NSHOTOKU_2DANKAI = 1 THEN
                    IF MlKAHYO(NwIX) > NSHOTOKU_HANTEI_GAKU THEN
                        NKAHYO_OVER := TRUNC((MlKAHYO(NwIX) - NSHOTOKU_HANTEI_GAKU) * (MlTAIKAHYO(NwIX) / MlKAHYO(NwIX)));
                        NKAHYO_DOWN := TRUNC(NSHOTOKU_HANTEI_GAKU * (MlTAIKAHYO(NwIX) / MlKAHYO(NwIX)));
                    ELSE
                        NKAHYO_OVER := 0;
                        NKAHYO_DOWN := MlTAIKAHYO(NwIX);
                    END IF;
                    MlTAIZEIGAKU(NwIX) := TRUNC(MlTAIZEIGAKU(NwIX) + NKAHYO_OVER * NSHOTOKU_KAI_OVER / 100);
                    MlTAIZEIGAKU(NwIX) := TRUNC(MlTAIZEIGAKU(NwIX) + NKAHYO_DOWN * NSHOTOKU_KAI / 100);
                END IF;


                IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割

                    MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX) - (MlTAICNT(NwIX) * NlJKGEN1);
                    IF MlCNT(NwIX) = MlTAICNT(NwIX) THEN
                        MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX) - NlJBGEN1;
                        -- 軽減平等
                        NlKEIGEN_B_6_TAI   := NlKEIGEN_B_6_TAI + (NlJBGEN1 / 12);
                        NlKEIGEN_BYODO     := NlKEIGEN_BYODO   + (NlJBGEN1 / 12);
                    END IF;
                    -- 軽減均等
                    NlKEIGEN_K_6_TAI := NlKEIGEN_K_6_TAI + (MlTAICNT(NwIX) * NlJKGEN1 / 12);
                    NlKEIGEN_KINTO   := NlKEIGEN_KINTO   + (MlTAICNT(NwIX) * NlJKGEN1 / 12);

                ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN    -- 軽減4割

                    MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX) - (MlTAICNT(NwIX) * NlJKGEN2);
                    IF MlCNT(NwIX) = MlTAICNT(NwIX) THEN
                        MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX) - NlJBGEN2;
                        -- 軽減平等
                        NlKEIGEN_B_4_TAI   := NlKEIGEN_B_4_TAI + (NlJBGEN2 / 12);
                        NlKEIGEN_BYODO     := NlKEIGEN_BYODO   + (NlJBGEN2 / 12);
                    END IF;
                    -- 軽減均等
                    NlKEIGEN_K_4_TAI := NlKEIGEN_K_4_TAI + (MlTAICNT(NwIX) * NlJKGEN2 / 12);
                    NlKEIGEN_KINTO   := NlKEIGEN_KINTO   + (MlTAICNT(NwIX) * NlJKGEN2 / 12);

                ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN    -- 軽減2割

                    MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX) - (MlTAICNT(NwIX) * NlJKGEN3);
                    IF MlCNT(NwIX) = MlTAICNT(NwIX) THEN
                        MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX) - NlJBGEN3;
                        -- 軽減平等
                        NlKEIGEN_B_2_TAI   := NlKEIGEN_B_2_TAI + (NlJBGEN3 / 12);
                        NlKEIGEN_BYODO     := NlKEIGEN_BYODO   + (NlJBGEN3 / 12);
                    END IF;
                        -- 軽減均等
                    NlKEIGEN_K_2_TAI := NlKEIGEN_K_2_TAI + (MlTAICNT(NwIX) * NlJKGEN3 / 12);
                    NlKEIGEN_KINTO   := NlKEIGEN_KINTO   + (MlTAICNT(NwIX) * NlJKGEN3 / 12);

                END IF;

                --優先区分が「世帯／額／応能応益」
                IF RlGENMEN_KOJIN.YUSEN_KBN = 2 THEN
                  IF NLOOP_CNT_NOW = 1 THEN
                    NwBYODOWARI     := NwBYODOWARI
                                     + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
                  ELSIF NLOOP_CNT_NOW = 2 THEN
                    MlTAIZEIGAKU(NwIX)  := MlTAIZEIGAKU(NwIX) -
                                           RlGENMEN_KOJIN.KT_SHOTOKU_GENGAKU -
                                           RlGENMEN_KOJIN.KT_SISANZEI_GENGAKU -
                                           RlGENMEN_KOJIN.KT_KINTOWARI_GENGAKU -
                                           RlGENMEN_KOJIN.KT_BYODOWARI_GENGAKU;
                    NwSHOTOKU_GENGAKU   := NwSHOTOKU_GENGAKU + RlGENMEN_KOJIN.KT_SHOTOKU_GENGAKU;     --計算用所得割減免額
                    NwSISANZEI_GENGAKU  := NwSISANZEI_GENGAKU + RlGENMEN_KOJIN.KT_SISANZEI_GENGAKU;   --計算用資産割減免額
                    NwKINTOWARI_GENGAKU := NwKINTOWARI_GENGAKU + RlGENMEN_KOJIN.KT_KINTOWARI_GENGAKU; --計算用均等割減免額
                    NwBYODOWARI_GENGAKU := NwBYODOWARI_GENGAKU + RlGENMEN_KOJIN.KT_BYODOWARI_GENGAKU; --計算用平等割減免額
                  END IF;
                END IF;
                IF MlCHOKA_MAE(NwIX) > NlJGENDOGAKU THEN
                   IF ITSUKI_HASU_KBN = 1 THEN
                      NwWORK2 := NlJGENDOGAKU * MlTAIZEIGAKU(NwIX) / MlCHOKA_MAE(NwIX);
                      MlTAICHOKA_SEKI(NwIX) := MlTAIZEIGAKU(NwIX) - NwWORK2;
                      MlTAIZEIGAKU(NwIX) := TRUNC(NwWORK2);
                   ELSE
                      NwWORK := NlJGENDOGAKU * MlTAIZEIGAKU(NwIX) / MlCHOKA_MAE(NwIX);
                      NwWORK := NwWORK + 0.9;
                      MlTAICHOKA_SEKI(NwIX) := MlTAIZEIGAKU(NwIX) - NwWORK;
                      MlTAIZEIGAKU(NwIX) := TRUNC(NwWORK);
                   END IF;
                END IF;

            END IF;
        END LOOP;
        --優先区分が「個人／率／応能応益」または「世帯／率／応能応益」
        IF RlGENMEN_KOJIN.YUSEN_KBN IN (0, 1) THEN
          IF NLOOP_CNT_NOW = 1 THEN
            UPDATE ZLBTGENMEN_KOJIN_CAL
              SET KT_BYODOWARI_KISO    = TRUNC(NwBYODOWARI / 12)
            WHERE KOKU_SETAI_NO        = i_NSETAI
              AND SANTEIDANTAI_CD      = i_NDANTAI
              AND NENDO_BUN            = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO      = i_VTANMATSU;
          ELSIF NLOOP_CNT_NOW = 2 THEN
            UPDATE ZLBTGENMEN_KOJIN_CAL
              SET KT_BYODOWARI_GENGAKU = KT_BYODOWARI_KISO - TRUNC(NwBYODOWARI / 12)
            WHERE KOKU_SETAI_NO        = i_NSETAI
              AND SANTEIDANTAI_CD      = i_NDANTAI
              AND NENDO_BUN            = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO      = i_VTANMATSU;
          END IF;
        --優先区分が「世帯／額／応能応益」
        ELSIF RlGENMEN_KOJIN.YUSEN_KBN = 2 THEN
          IF NLOOP_CNT_NOW = 1 THEN
            UPDATE ZLBTGENMEN_KOJIN_CAL
              SET KT_BYODOWARI_KISO = TRUNC(NwBYODOWARI / 12)
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND NENDO_BUN       = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO = i_VTANMATSU;
          ELSIF NLOOP_CNT_NOW = 2 THEN
            UPDATE ZLBTGENMEN_KOJIN_CAL
              SET KT_SHOTOKU_GENGAKU   = TRUNC(NwSHOTOKU_GENGAKU / 12),
                  KT_SISANZEI_GENGAKU  = TRUNC(NwSISANZEI_GENGAKU / 12),
                  KT_KINTOWARI_GENGAKU = TRUNC(NwKINTOWARI_GENGAKU / 12),
                  KT_BYODOWARI_GENGAKU = TRUNC(NwBYODOWARI_GENGAKU / 12)
            WHERE KOKU_SETAI_NO        = i_NSETAI
              AND SANTEIDANTAI_CD      = i_NDANTAI
              AND NENDO_BUN            = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO      = i_VTANMATSU;
          END IF;
        END IF;

    END subTukiwari_Tai;
-------------------------------------------------------------------------------
-- 減免対象者か判定するため、ZLBTGENMEN_KOJIN_CAL から、対象データを取得する。
-------------------------------------------------------------------------------
    FUNCTION funcGenmenKojinGet(i_RwKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) RETURN NUMBER IS
        nCNT      NUMBER;
        nRTN      NUMBER;
        nCNTG     NUMBER;
    BEGIN

        nRTN := 0;
        RwGENMENKOJIN := NULL;

        -- ZLBTGENMEN_KOJIN テーブルの存在チェック
        nCNT := 1;

        -- ZLBTGENMEN_KOJIN 優先区分0:個人/率/応能応益のデータ存在チェック
        SELECT count(*) INTO nCNTG FROM ZLBTGENMEN_KOJIN
        WHERE YUSEN_KBN = 0
--2024/09/23 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00020
           --AND TEKIYO_KBN = 1
           AND TEKIYO_KBN IN (1, 3)
           AND KOKU_SETAI_NO = i_NSETAI
           AND NENDO_BUN =i_NNENDO_BUN;

        IF nCNT = 1 THEN
          IF NlJNUSHI = 0 OR IGENMENNUSHI_KBN = 0 THEN --減免計算フラグ0の場合(既存処理)
          -- 優先区分が「世帯／率／応能応益」「世帯／率／年額」「世帯／額／年額」の場合は
          -- 世帯単位で減免対象かどうかを判定する
            OPEN cur_DynamicSQL FOR 'SELECT * FROM ZLBTGENMEN_KOJIN_TMP
                                     WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                     AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                     AND   NENDO_BUN       = :NENDO_BUN
                                     AND   YUSEN_KBN      IN (2,3,4)
                                     AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO'
                                USING i_RwKOJIN.KOKU_SETAI_NO, i_RwKOJIN.SANTEIDANTAI_CD, i_RwKOJIN.NENDO_BUN, i_RwKOJIN.SYS_TANMATSU_NO;
            LOOP
              FETCH cur_DynamicSQL INTO RwGENMENKOJIN;
              EXIT WHEN cur_DynamicSQL%NOTFOUND;
              nRTN := 1;
              EXIT;
            END LOOP;
            CLOSE cur_DynamicSQL;
            -- 優先区分が「世帯／率／応能応益」「世帯／率／年額」「世帯／額／年額」以外の場合は
            -- 個人単位で減免対象かどうかを判定する
            IF NVL(RwGENMENKOJIN.YUSEN_KBN,0) NOT IN (2,3,4) THEN
              nRTN := 0;
              OPEN cur_DynamicSQL FOR 'SELECT * FROM ZLBTGENMEN_KOJIN_TMP
                                       WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                       AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                       AND   NENDO_BUN       = :NENDO_BUN
                                       AND   KOJIN_NO        = :KOJIN_NO
                                       AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO'
                                  USING i_RwKOJIN.KOKU_SETAI_NO, i_RwKOJIN.SANTEIDANTAI_CD, i_RwKOJIN.NENDO_BUN, i_RwKOJIN.KOJIN_NO, i_RwKOJIN.SYS_TANMATSU_NO;

              LOOP
                FETCH cur_DynamicSQL INTO RwGENMENKOJIN;
                EXIT WHEN cur_DynamicSQL%NOTFOUND;
                nRTN := 1;
                EXIT;
              END LOOP;
              CLOSE cur_DynamicSQL;
            END IF;
          ELSIF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN -- 世帯主課税かつ減免計算条件1の場合
            IF nCNTG > 0 THEN-- 優先区分0:個人/率/応能応益の件数が0より大きい場合
              nRTN := 0;
              OPEN cur_DynamicSQL FOR 'SELECT * FROM ZLBTGENMEN_KOJIN_TMP
                                       WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                       AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                       AND   NENDO_BUN       = :NENDO_BUN
                                       AND   KOJIN_NO        = :KOJIN_NO
                                       AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO'
                                  USING i_RwKOJIN.KOKU_SETAI_NO, i_RwKOJIN.SANTEIDANTAI_CD, i_RwKOJIN.NENDO_BUN, i_RwKOJIN.KOJIN_NO, i_RwKOJIN.SYS_TANMATSU_NO;
              LOOP
                FETCH cur_DynamicSQL INTO RwGENMENKOJIN;
                EXIT WHEN cur_DynamicSQL%NOTFOUND;
                nRTN := 1;
                EXIT;
              END LOOP;
              CLOSE cur_DynamicSQL;
            ELSE--優先区分0:個人/率/応能応益のデータ登録以外の場合
              OPEN cur_DynamicSQL FOR 'SELECT * FROM ZLBTGENMEN_KOJIN_TMP
                                       WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                       AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                       AND   NENDO_BUN       = :NENDO_BUN
                                       AND   KOJIN_NO        = :KOJIN_NO
                                       AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO
                                       AND   TSUCHI_NO       = :TSUCHI_NO'
                                  USING i_RwKOJIN.KOKU_SETAI_NO, i_RwKOJIN.SANTEIDANTAI_CD, i_RwKOJIN.NENDO_BUN, i_NNUSHI, i_RwKOJIN.SYS_TANMATSU_NO, i_NNUSHI;
              LOOP
                FETCH cur_DynamicSQL INTO RwGENMENKOJIN;
                EXIT WHEN cur_DynamicSQL%NOTFOUND;
                nRTN := 1;
                EXIT;
              END LOOP;
              CLOSE cur_DynamicSQL;
              -- 優先区分が「世帯／率／応能応益」「世帯／率／年額」「世帯／額／年額」以外の場合は
              -- 個人単位で減免対象かどうかを判定する
              IF NVL(RwGENMENKOJIN.YUSEN_KBN,0) NOT IN (2,3,4) THEN
                nRTN := 0;
                OPEN cur_DynamicSQL FOR 'SELECT * FROM ZLBTGENMEN_KOJIN_TMP
                                       WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                       AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                       AND   NENDO_BUN       = :NENDO_BUN
                                       AND   KOJIN_NO        = :KOJIN_NO
                                       AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO
                                       AND   TSUCHI_NO       = :TSUCHI_NO'
                                  USING i_RwKOJIN.KOKU_SETAI_NO, i_RwKOJIN.SANTEIDANTAI_CD, i_RwKOJIN.NENDO_BUN, i_RwKOJIN.KOJIN_NO, i_RwKOJIN.SYS_TANMATSU_NO, i_NNUSHI;
                LOOP
                  FETCH cur_DynamicSQL INTO RwGENMENKOJIN;
                  EXIT WHEN cur_DynamicSQL%NOTFOUND;
                  nRTN := 1;
                  EXIT;
                END LOOP;
                CLOSE cur_DynamicSQL;
              END IF;
            END IF;
          END IF;
        END IF;

        RETURN(nRTN);
    EXCEPTION
      WHEN OTHERS THEN
         IF cur_DynamicSQL%ISOPEN THEN
            CLOSE cur_DynamicSQL;
         END IF;
         RETURN 1;
    END;
-------------------------------------------------------------------------------
-- 22 月割税額算出準備(退職)
-------------------------------------------------------------------------------
    PROCEDURE subTukiwariMae_Tai(i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) IS
        NwIX                    NUMBER(2);
        RLKANWAKOJIN            ZLBTKANWA_KOJIN_CAL%ROWTYPE;
        MwGENMENKOJIN           MTNUMARRAY12;   -- 各月の減免率
        NwKOJINSHOTOKU          NUMBER(12) := 0;
        NwKOJINSISANZEI         NUMBER(12) := 0;
        NwKOJINKINTOWARI        NUMBER(12) := 0;
    BEGIN

        NGENMEN_KOJIN_KBN := funcGenmenKojinGet(i_RKOJIN);
        IF  IGENMENKEISAN_KBN = 1 THEN
            NGENMEN_KOJIN_KBN := 0;
        END IF;
        -- ◆
        -- 通常課税計算
        IF (i_CAL_KBN = c_CAL_KBN_TU AND
            (i_RKOJIN.NEW_SHIK_KBN IN (1, 3, 7, 9) OR
             (i_RKOJIN.NEW_SHIK_KBN IN (2, 8) AND i_RKOJIN.SEKISAN_GAI_KBN = 1)) ) OR
        -- 賦課期日時点
           (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND
            i_RKOJIN.NEW_SHIK_KBN IN (1, 3) ) THEN

          -- ◆
          -- 通常課税計算
          IF (i_CAL_KBN = c_CAL_KBN_TU AND
              (i_RKOJIN.NEW_KAI_SHIK_KBN IN (0, 1) OR
               (i_RKOJIN.NEW_KAI_SHIK_KBN = 2 AND i_RKOJIN.SEKISAN_GAI_KBN = 1)) ) OR
          -- 賦課期日時点
             (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND
              i_RKOJIN.NEW_KAI_SHIK_KBN IN (1, 2) ) THEN

                -- 計算個人の各月資格区分を退避
                MlSHIK_KBN(1)  := i_RKOJIN.KAI_SHIK_4;
                MlSHIK_KBN(2)  := i_RKOJIN.KAI_SHIK_5;
                MlSHIK_KBN(3)  := i_RKOJIN.KAI_SHIK_6;
                MlSHIK_KBN(4)  := i_RKOJIN.KAI_SHIK_7;
                MlSHIK_KBN(5)  := i_RKOJIN.KAI_SHIK_8;
                MlSHIK_KBN(6)  := i_RKOJIN.KAI_SHIK_9;
                MlSHIK_KBN(7)  := i_RKOJIN.KAI_SHIK_10;
                MlSHIK_KBN(8)  := i_RKOJIN.KAI_SHIK_11;
                MlSHIK_KBN(9)  := i_RKOJIN.KAI_SHIK_12;
                MlSHIK_KBN(10) := i_RKOJIN.KAI_SHIK_1;
                MlSHIK_KBN(11) := i_RKOJIN.KAI_SHIK_2;
                MlSHIK_KBN(12) := i_RKOJIN.KAI_SHIK_3;

                -- 計算個人の各月資格区分(医療)を退避
                MlIRYSHIK_KBN(1)  := i_RKOJIN.SHIK_4;
                MlIRYSHIK_KBN(2)  := i_RKOJIN.SHIK_5;
                MlIRYSHIK_KBN(3)  := i_RKOJIN.SHIK_6;
                MlIRYSHIK_KBN(4)  := i_RKOJIN.SHIK_7;
                MlIRYSHIK_KBN(5)  := i_RKOJIN.SHIK_8;
                MlIRYSHIK_KBN(6)  := i_RKOJIN.SHIK_9;
                MlIRYSHIK_KBN(7)  := i_RKOJIN.SHIK_10;
                MlIRYSHIK_KBN(8)  := i_RKOJIN.SHIK_11;
                MlIRYSHIK_KBN(9)  := i_RKOJIN.SHIK_12;
                MlIRYSHIK_KBN(10) := i_RKOJIN.SHIK_1;
                MlIRYSHIK_KBN(11) := i_RKOJIN.SHIK_2;
                MlIRYSHIK_KBN(12) := i_RKOJIN.SHIK_3;
                -- 計算個人の各月失業資格区分を退避
                IF i_RKOJIN.NEW_SHITSU_KBN > 0 THEN
                  MlSHITSU_KBN(1)  := i_RKOJIN.SHITSU_4;
                  MlSHITSU_KBN(2)  := i_RKOJIN.SHITSU_5;
                  MlSHITSU_KBN(3)  := i_RKOJIN.SHITSU_6;
                  MlSHITSU_KBN(4)  := i_RKOJIN.SHITSU_7;
                  MlSHITSU_KBN(5)  := i_RKOJIN.SHITSU_8;
                  MlSHITSU_KBN(6)  := i_RKOJIN.SHITSU_9;
                  MlSHITSU_KBN(7)  := i_RKOJIN.SHITSU_10;
                  MlSHITSU_KBN(8)  := i_RKOJIN.SHITSU_11;
                  MlSHITSU_KBN(9)  := i_RKOJIN.SHITSU_12;
                  MlSHITSU_KBN(10) := i_RKOJIN.SHITSU_1;
                  MlSHITSU_KBN(11) := i_RKOJIN.SHITSU_2;
                  MlSHITSU_KBN(12) := i_RKOJIN.SHITSU_3;
                ELSE
                  FOR NwIX IN 1..12 LOOP
                    MlSHITSU_KBN(NwIX) := 0;
                  END LOOP;
                END IF;

                BEGIN
                  SELECT *
                    INTO RLKANWAKOJIN
                    FROM ZLBTKANWA_KOJIN_CAL
                   WHERE KOKU_SETAI_NO   = i_RKOJIN.KOKU_SETAI_NO
                     AND KOJIN_NO        = i_RKOJIN.KOJIN_NO
                     AND SANTEIDANTAI_CD = i_RKOJIN.SANTEIDANTAI_CD
                     AND CHOTEI_NENDO    = i_RKOJIN.CHOTEI_NENDO
                     AND NENDO_BUN       = i_RKOJIN.NENDO_BUN
                     AND TSUCHI_NO       = i_RKOJIN.TSUCHI_NO
                     AND SYS_TANMATSU_NO = i_RKOJIN.SYS_TANMATSU_NO;

                  -- 計算緩和個人の各月応益係数を退避
                  MlOUEKI(1)  := RLKANWAKOJIN.OUEKI_4;
                  MlOUEKI(2)  := RLKANWAKOJIN.OUEKI_5;
                  MlOUEKI(3)  := RLKANWAKOJIN.OUEKI_6;
                  MlOUEKI(4)  := RLKANWAKOJIN.OUEKI_7;
                  MlOUEKI(5)  := RLKANWAKOJIN.OUEKI_8;
                  MlOUEKI(6)  := RLKANWAKOJIN.OUEKI_9;
                  MlOUEKI(7)  := RLKANWAKOJIN.OUEKI_10;
                  MlOUEKI(8)  := RLKANWAKOJIN.OUEKI_11;
                  MlOUEKI(9)  := RLKANWAKOJIN.OUEKI_12;
                  MlOUEKI(10) := RLKANWAKOJIN.OUEKI_1;
                  MlOUEKI(11) := RLKANWAKOJIN.OUEKI_2;
                  MlOUEKI(12) := RLKANWAKOJIN.OUEKI_3;

                  -- 計算緩和個人の各月応能係数を退避
                  MlOUNOU(1)  := RLKANWAKOJIN.OUNOU_4;
                  MlOUNOU(2)  := RLKANWAKOJIN.OUNOU_5;
                  MlOUNOU(3)  := RLKANWAKOJIN.OUNOU_6;
                  MlOUNOU(4)  := RLKANWAKOJIN.OUNOU_7;
                  MlOUNOU(5)  := RLKANWAKOJIN.OUNOU_8;
                  MlOUNOU(6)  := RLKANWAKOJIN.OUNOU_9;
                  MlOUNOU(7)  := RLKANWAKOJIN.OUNOU_10;
                  MlOUNOU(8)  := RLKANWAKOJIN.OUNOU_11;
                  MlOUNOU(9)  := RLKANWAKOJIN.OUNOU_12;
                  MlOUNOU(10) := RLKANWAKOJIN.OUNOU_1;
                  MlOUNOU(11) := RLKANWAKOJIN.OUNOU_2;
                  MlOUNOU(12) := RLKANWAKOJIN.OUNOU_3;
                EXCEPTION
                  WHEN OTHERS THEN
                    MlOUEKI(1) := 100;
                    MlOUEKI(2) := 100;
                    MlOUEKI(3) := 100;
                    MlOUEKI(4) := 100;
                    MlOUEKI(5) := 100;
                    MlOUEKI(6) := 100;
                    MlOUEKI(7) := 100;
                    MlOUEKI(8) := 100;
                    MlOUEKI(9) := 100;
                    MlOUEKI(10):= 100;
                    MlOUEKI(11):= 100;
                    MlOUEKI(12):= 100;
                    MlOUNOU(1) := 100;
                    MlOUNOU(2) := 100;
                    MlOUNOU(3) := 100;
                    MlOUNOU(4) := 100;
                    MlOUNOU(5) := 100;
                    MlOUNOU(6) := 100;
                    MlOUNOU(7) := 100;
                    MlOUNOU(8) := 100;
                    MlOUNOU(9) := 100;
                    MlOUNOU(10):= 100;
                    MlOUNOU(11):= 100;
                    MlOUNOU(12):= 100;
                END;


            IF NLOOP_CNT_NOW = 2 THEN

                FOR NwIX IN 1..12 LOOP
                    -- クリア
                    MwGENMENKOJIN(NwIX) := 0;
                END LOOP;

                IF NGENMEN_KOJIN_KBN = 1 THEN
                    -- 各月の減免有無をセット
                    MwGENMENKOJIN(1)  := NVL(RwGENMENKOJIN.K_GENMEN_4,0);
                    MwGENMENKOJIN(2)  := NVL(RwGENMENKOJIN.K_GENMEN_5,0);
                    MwGENMENKOJIN(3)  := NVL(RwGENMENKOJIN.K_GENMEN_6,0);
                    MwGENMENKOJIN(4)  := NVL(RwGENMENKOJIN.K_GENMEN_7,0);
                    MwGENMENKOJIN(5)  := NVL(RwGENMENKOJIN.K_GENMEN_8,0);
                    MwGENMENKOJIN(6)  := NVL(RwGENMENKOJIN.K_GENMEN_9,0);
                    MwGENMENKOJIN(7)  := NVL(RwGENMENKOJIN.K_GENMEN_10,0);
                    MwGENMENKOJIN(8)  := NVL(RwGENMENKOJIN.K_GENMEN_11,0);
                    MwGENMENKOJIN(9)  := NVL(RwGENMENKOJIN.K_GENMEN_12,0);
                    MwGENMENKOJIN(10) := NVL(RwGENMENKOJIN.K_GENMEN_1,0);
                    MwGENMENKOJIN(11) := NVL(RwGENMENKOJIN.K_GENMEN_2,0);
                    MwGENMENKOJIN(12) := NVL(RwGENMENKOJIN.K_GENMEN_3,0);
                END IF;

            END IF;


                FOR NwIX IN 1..12 LOOP
                IF (i_RKOJIN.SHIK_4  IN (11, 13) OR i_RKOJIN.SHIK_5  IN (11, 13) OR
                    i_RKOJIN.SHIK_6  IN (11, 13) OR i_RKOJIN.SHIK_7  IN (11, 13) OR
                    i_RKOJIN.SHIK_8  IN (11, 13) OR i_RKOJIN.SHIK_9  IN (11, 13) OR
                    i_RKOJIN.SHIK_10 IN (11, 13) OR i_RKOJIN.SHIK_11 IN (11, 13) OR
                    i_RKOJIN.SHIK_12 IN (11, 13) OR i_RKOJIN.SHIK_1  IN (11, 13) OR
                    i_RKOJIN.SHIK_2  IN (11, 13) OR i_RKOJIN.SHIK_3  IN (11, 13)) AND i_RKOJIN.SEKISAN_GAI_KBN = 1 THEN
                    -- 資産割額と均等額を加算
                    MlTAIZEIGAKU_SEKI(NwIX) := MlTAIZEIGAKU_SEKI(NwIX)
                                             + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 * MlOUNOU(NwIX) / 100)
                                             + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                    IF NSHOTOKU_2DANKAI = 1 THEN-- 所得2段階の所得は月割税額セットで設定する
                      IF MlOUNOU(NwIX) = 100 THEN
                        IF MlSHITSU_KBN(NwIX) > 0 THEN
                          MlTAIKAHYO_SEKI(NwIX) := MlTAIKAHYO_SEKI(NwIX) + i_RKOJIN.SHITSU_KAHYO;
                        ELSE
                        MlTAIKAHYO_SEKI(NwIX)   := MlTAIKAHYO_SEKI(NwIX) + i_RKOJIN.KAHYO;
                        END IF;
                      END IF;
                    ELSE
                      -- 所得割を加算
                      IF MlSHITSU_KBN(NwIX) > 0 THEN
                        MlTAIZEIGAKU_SEKI(NwIX) := MlTAIZEIGAKU_SEKI(NwIX)
                                                 + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                      ELSE
                      MlTAIZEIGAKU_SEKI(NwIX) := MlTAIZEIGAKU_SEKI(NwIX)
                                               + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                      END IF;
                    END IF;
                END IF;
                    IF MlIRYSHIK_KBN(NwIX) IN (11, 13) THEN
                        IF MlSHIK_KBN(NwIX) = 1 THEN
                            MlTAICNT(NwIX)     := MlTAICNT(NwIX) + 1;
--                                -- 予め計算した割額を加算
--                                -- 所得2段階の所得は月割税額セット(退職)で設定する
--                                -- 予め計算した割額を加算
--                            --均等割算出前準備
--                            --積算時と同様に世帯員全員で一括算出させる為
--                            --応益係数=100%・90%・70%・50%のそれぞれの該当件数を算出
--                              -- 資産割のみ加算
--                              -- 所得2段階の所得は月割税額セット(退職)で設定する
--                              -- 所得割と資産割を加算
                            -- 資産割額と均等額を加算
                    IF NLOOP_CNT_NOW = 1 THEN
                      MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                          + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 * MlOUNOU(NwIX) / 100)
                                          + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                      -- 個人別の資産割額
                      NwKOJINSISANZEI  := NwKOJINSISANZEI  + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 * MlOUNOU(NwIX) / 100);
                      -- 個人別の均等割額
                      NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                    ELSE
                      MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                          + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 - i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SISANZEI_RITSU,0) / 100);
                      -- 個人別の資産割額
                      NwKOJINSISANZEI  := NwKOJINSISANZEI  + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 - i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SISANZEI_RITSU,0) / 100);
                      -- 個人別の均等割額
                      IF NGENMEN_KOJIN_KBN = 0 THEN
                        MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX) + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                        NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                      ELSE
                        IF    MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割の場合
                          MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                              + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN1) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN1) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN       -- 軽減4割の場合
                          MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                              + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN2) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN2) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN       -- 軽減2割の場合
                          MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                              + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN3) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN3) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                        ELSE
                          MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                              + TRUNC(NlJKINTO - NlJKINTO * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO - NlJKINTO * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                        END IF;
                      END IF;
                    END IF;
                            IF NSHOTOKU_2DANKAI = 1 THEN-- 所得2段階の所得は月割税額セットで設定する
                              IF MlOUNOU(NwIX) = 100 THEN
                                IF MlSHITSU_KBN(NwIX) > 0 THEN
                                  MlTAIKAHYO(NwIX) := MlTAIKAHYO(NwIX) + i_RKOJIN.SHITSU_KAHYO;
                                ELSE
                                MlTAIKAHYO(NwIX)   := MlTAIKAHYO(NwIX) + i_RKOJIN.KAHYO;
                                END IF;
                              END IF;
                            ELSE
                              -- 所得割を加算
                      IF NLOOP_CNT_NOW = 1 THEN
                        IF MlSHITSU_KBN(NwIX) > 0 THEN
                          MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                              + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                          -- 個人別の所得割額
                          NwKOJINSHOTOKU  := NwKOJINSHOTOKU + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                        ELSE
                        MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                            + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                        -- 個人別の所得割額
                        NwKOJINSHOTOKU  := NwKOJINSHOTOKU + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                        END IF;
                      ELSE
                        IF MlSHITSU_KBN(NwIX) > 0 THEN
                          MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                              + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 - i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SHOTOKU_RITSU,0) / 100);
                          -- 個人別の所得割額
                          NwKOJINSHOTOKU  := NwKOJINSHOTOKU + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 - i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SHOTOKU_RITSU,0) / 100);
                        ELSE
                        MlTAIZEIGAKU(NwIX) := MlTAIZEIGAKU(NwIX)
                                            + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 - i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SHOTOKU_RITSU,0) / 100);
                        -- 個人別の所得割額
                        NwKOJINSHOTOKU  := NwKOJINSHOTOKU + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 - i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SHOTOKU_RITSU,0) / 100);
                        END IF;
                      END IF;
                            END IF;

                        END IF;
                    END IF;
                END LOOP;
          IF NGENMEN_KOJIN_KBN = 1 THEN
              IF NLOOP_CNT_NOW = 1 THEN
                  -- 減免個人データを作成 insert ZLBTGENMEN_KOJIN_TMP → ZLBTGENMEN_KOJIN_CAL
                  -- 医療で既に insert しているので不要

                  vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                  vSQL := vSQL || ' SET KT_SHOTOKU_KISO   = :SHOTOKU,';
                  vSQL := vSQL ||      'KT_SISANZEI_KISO  = :SISANZEI,';
                  vSQL := vSQL ||      'KT_KINTOWARI_KISO = :KINTOWARI';
                  vSQL := vSQL || ' WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO';
                  vSQL := vSQL || ' AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD';
                  vSQL := vSQL || ' AND   KOJIN_NO        = :KOJIN_NO';
                  vSQL := vSQL || ' AND   NENDO_BUN       = :NENDO_BUN';
                  vSQL := vSQL || ' AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO';
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    vSQL := vSQL || '  AND ((YUSEN_KBN > 0 AND TSUCHI_NO = :TSUCHI_NO )';
                    vSQL := vSQL || '        OR (YUSEN_KBN = 0 AND NVL(TSUCHI_NO,0) != 0))';
                  ELSE
                    vSQL := vSQL || '  AND :TSUCHI_NO IS NOT NULL';
                  END IF;

                  EXECUTE IMMEDIATE vSQL USING IN TRUNC(NwKOJINSHOTOKU / 12), TRUNC(NwKOJINSISANZEI / 12), TRUNC(NwKOJINKINTOWARI / 12),
                                                  RwGENMENKOJIN.KOKU_SETAI_NO,
                                                  RwGENMENKOJIN.SANTEIDANTAI_CD,
                                                  RwGENMENKOJIN.KOJIN_NO,
                                                  RwGENMENKOJIN.NENDO_BUN,
                                                  RwGENMENKOJIN.SYS_TANMATSU_NO,
                                                  RwGENMENKOJIN.TSUCHI_NO;
              ELSE
                  vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                  vSQL := vSQL || ' SET KT_SHOTOKU_GENGAKU   = KT_SHOTOKU_KISO   - :1,';
                  vSQL := vSQL ||      'KT_SISANZEI_GENGAKU  = KT_SISANZEI_KISO  - :2,';
                  vSQL := vSQL ||      'KT_KINTOWARI_GENGAKU = KT_KINTOWARI_KISO - :3';
                  vSQL := vSQL || ' WHERE KOKU_SETAI_NO   = :4';
                  vSQL := vSQL || ' AND   SANTEIDANTAI_CD = :5';
                  vSQL := vSQL || ' AND   KOJIN_NO        = :6';
                  vSQL := vSQL || ' AND   NENDO_BUN       = :7';
                  vSQL := vSQL || ' AND   SYS_TANMATSU_NO = :8';
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    vSQL := vSQL || '  AND ((YUSEN_KBN > 0 AND TSUCHI_NO = :9 )';
                    vSQL := vSQL || '        OR (YUSEN_KBN = 0 AND NVL(TSUCHI_NO,0) != 0))';
                  ELSE
                    vSQL := vSQL || '  AND :9 IS NOT NULL';
                  END IF;

                  EXECUTE IMMEDIATE vSQL USING IN TRUNC(NwKOJINSHOTOKU   / 12),
                                                  TRUNC(NwKOJINSISANZEI  / 12),
                                                  TRUNC(NwKOJINKINTOWARI / 12),
                                                  RwGENMENKOJIN.KOKU_SETAI_NO,
                                                  RwGENMENKOJIN.SANTEIDANTAI_CD,
                                                  RwGENMENKOJIN.KOJIN_NO,
                                                  RwGENMENKOJIN.NENDO_BUN,
                                                  RwGENMENKOJIN.SYS_TANMATSU_NO,
                                                  RwGENMENKOJIN.TSUCHI_NO;

                  vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                  vSQL := vSQL || ' SET KT_GENGAKU_KEI    = KT_SHOTOKU_GENGAKU + KT_SISANZEI_GENGAKU + KT_KINTOWARI_GENGAKU';
                  vSQL := vSQL || ' WHERE KOKU_SETAI_NO   = :1';
                  vSQL := vSQL || ' AND   SANTEIDANTAI_CD = :2';
                  vSQL := vSQL || ' AND   KOJIN_NO        = :3';
                  vSQL := vSQL || ' AND   NENDO_BUN       = :4';
                  vSQL := vSQL || ' AND   SYS_TANMATSU_NO = :5';
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    vSQL := vSQL || '  AND ((YUSEN_KBN > 0 AND TSUCHI_NO = :6 )';
                    vSQL := vSQL || '        OR (YUSEN_KBN = 0 AND NVL(TSUCHI_NO,0) != 0))';
                  ELSE
                    vSQL := vSQL || '  AND :6 IS NOT NULL';
                  END IF;

                  EXECUTE IMMEDIATE vSQL USING IN RwGENMENKOJIN.KOKU_SETAI_NO,
                                                  RwGENMENKOJIN.SANTEIDANTAI_CD,
                                                  RwGENMENKOJIN.KOJIN_NO,
                                                  RwGENMENKOJIN.NENDO_BUN,
                                                  RwGENMENKOJIN.SYS_TANMATSU_NO,
                                                  RwGENMENKOJIN.TSUCHI_NO;
              END IF;
          END IF;
            END IF;
        END IF;

        RlTAI.KEIGEN_K_WARI := 0;
        RlTAI.KEIGEN_B_WARI := 0;

    END subTukiwariMae_Tai;
-------------------------------------------------------------------------------
-- 21 軽減額月割端数調整(基本)
-------------------------------------------------------------------------------
    PROCEDURE subKeigenChosei IS
    BEGIN

        -- 軽減均等割額
        IF NlKEIGEN_KINTO > 0 THEN
            NlKEIGEN_KINTO := NlKEIGEN_KINTO + 0.01;
            RlKIHON.KEIGEN_K_WARI := TRUNC(NlKEIGEN_KINTO);
        END IF;

        -- 軽減平等割額
        IF NlKEIGEN_BYODO > 0 THEN
            NlKEIGEN_BYODO := NlKEIGEN_BYODO + 0.01;
            RlKIHON.KEIGEN_B_WARI := TRUNC(NlKEIGEN_BYODO);
        END IF;
        -- 軽減均等６割
        IF NlKEIGEN_K_6_ZEN > 0 THEN
            NlKEIGEN_K_6_ZEN   := NlKEIGEN_K_6_ZEN + 0.01;
            RlKIHON.KEIGEN_K_6 := TRUNC(NlKEIGEN_K_6_ZEN);
        END IF;
        -- 軽減均等４割
        IF NlKEIGEN_K_4_ZEN > 0 THEN
            NlKEIGEN_K_4_ZEN   := NlKEIGEN_K_4_ZEN + 0.01;
            RlKIHON.KEIGEN_K_4 := TRUNC(NlKEIGEN_K_4_ZEN);
        END IF;
        -- 軽減均等２割
        IF NlKEIGEN_K_2_ZEN > 0 THEN
            NlKEIGEN_K_2_ZEN   := NlKEIGEN_K_2_ZEN + 0.01;
            RlKIHON.KEIGEN_K_2 := TRUNC(NlKEIGEN_K_2_ZEN);
        END IF;
        -- 軽減平等６割
        IF NlKEIGEN_B_6_ZEN > 0 THEN
            NlKEIGEN_B_6_ZEN := NlKEIGEN_B_6_ZEN + 0.01;
            RlKIHON.KEIGEN_B_6 := TRUNC(NlKEIGEN_B_6_ZEN);
        END IF;
        -- 軽減平等４割
        IF NlKEIGEN_B_4_ZEN > 0 THEN
            NlKEIGEN_B_4_ZEN   := NlKEIGEN_B_4_ZEN + 0.01;
            RlKIHON.KEIGEN_B_4 := TRUNC(NlKEIGEN_B_4_ZEN);
        END IF;
        -- 軽減平等２割
        IF NlKEIGEN_B_2_ZEN > 0 THEN
            NlKEIGEN_B_2_ZEN   := NlKEIGEN_B_2_ZEN + 0.01;
            RlKIHON.KEIGEN_B_2 := TRUNC(NlKEIGEN_B_2_ZEN);
        END IF;

        NlKEIGEN_KINTO := 0;
        NlKEIGEN_BYODO := 0;
        NlKEIGEN_K_6_ZEN := 0;  -- 軽減均等6 全体
        NlKEIGEN_B_6_ZEN := 0;  -- 軽減平等6 全体
        NlKEIGEN_K_4_ZEN := 0;  -- 軽減均等4 全体
        NlKEIGEN_B_4_ZEN := 0;  -- 軽減平等4 全体
        NlKEIGEN_K_2_ZEN := 0;  -- 軽減均等2 全体
        NlKEIGEN_B_2_ZEN := 0;  -- 軽減平等2 全体

    END subKeigenChosei;
-------------------------------------------------------------------------------
-- 20 月割年税額算出
-------------------------------------------------------------------------------
    PROCEDURE subTukiwariNenzei IS
        NwIX            NUMBER(2);
        NNENZEIGAKU_2   NUMBER(15,3);
        NHasuKeta       NUMBER(1);
    BEGIN
        IF ITSUKI_HASU_KBN = 1 THEN
          NNENZEIGAKU_2 := NlNENZEIGAKU;
        END IF;

        FOR NwIX IN 1..12 LOOP
          IF ITSUKI_HASU_KBN = 1 THEN
            NNENZEIGAKU_2 := NNENZEIGAKU_2 +
                             (MlZEIGAKU(NwIX) * MlTUKI(NwIX) ) / 12;
          ELSIF ITSUKI_HASU_KBN = 2 THEN
            NHasuKeta := CASE NlJHASU
                           WHEN c_NHASU_KBN_1  THEN -3
                           WHEN c_NHASU_KBN_2  THEN -2
                           WHEN c_NHASU_KBN_3  THEN  0
                           WHEN c_NHASU_KBN_10 THEN -1
                           ELSE                     -2
                         END;
            NlNENZEIGAKU := TRUNC(NlNENZEIGAKU) +
                            TRUNC((TRUNC(MlZEIGAKU(NwIX), NHasuKeta) * MlTUKI(NwIX) ) / 12);
          ELSIF ITSUKI_HASU_KBN = 3 THEN
            NlNENZEIGAKU := NlNENZEIGAKU +
                            (MlZEIGAKU(NwIX) * MlTUKI(NwIX) ) / 12;
          ELSE
--2025/07/24 CTC.gaoqq Upd start 1.0.501.001:QA10155マージ作業
--            NlNENZEIGAKU := NlNENZEIGAKU +
--                            ((MlZEIGAKU(NwIX) * MlTUKI(NwIX) ) / 12);
            NlNENZEIGAKU := TRUNC(NlNENZEIGAKU) +
                            TRUNC((MlZEIGAKU(NwIX) * MlTUKI(NwIX) ) / 12);
--2025/07/24 CTC.gaoqq Upd end 1.0.501.001:QA10155マージ作業
          END IF;
        END LOOP;

        IF ITSUKI_HASU_KBN = 1 THEN
--2025/07/24 CTC.gaoqq Upd 1.0.501.001:QA10155マージ作業
--          NlNENZEIGAKU := NNENZEIGAKU_2;
          NlNENZEIGAKU := TRUNC(NNENZEIGAKU_2);
        END IF;

        IF ITSUKI_HASU_KBN = 3 THEN
--2025/07/24 CTC.gaoqq Upd 1.0.501.001:QA10155マージ作業
--          NlNENZEIGAKU := NlNENZEIGAKU;
          NlNENZEIGAKU := TRUNC(NlNENZEIGAKU);
        END IF;

    END subTukiwariNenzei;
-------------------------------------------------------------------------------
-- 19 同税額月数算出(基本)
-------------------------------------------------------------------------------
    PROCEDURE subDouzeiTukisu IS
        NwIX1           NUMBER(2);
        NwIX2           NUMBER(2);
    BEGIN

        FOR NwIX1 IN 1..12 LOOP
            FOR NwIX2 IN 1..12 LOOP

                IF MlSUMI(NwIX2) != 1 THEN
                    IF MlZEIGAKU(NwIX1) = MlZEIGAKU(NwIX2) THEN
                        MlTUKI(NwIX1) := MlTUKI(NwIX1) + 1;
                        MlSUMI(NwIX2) := 1;
                    END IF;
                END IF;

            END LOOP;
        END LOOP;

    END subDouzeiTukisu;
-------------------------------------------------------------------------------
-- 19 同税額月数算出(基本)
-------------------------------------------------------------------------------
    PROCEDURE subDouzeiTukisu_SEKI IS
        NwIX1           NUMBER(2);
        NwIX2           NUMBER(2);
    BEGIN

        FOR NwIX1 IN 1..12 LOOP

            FOR NwIX2 IN 1..12 LOOP

                IF MlSUMI_SEKI(NwIX2) != 1 THEN
                    IF MlZEIGAKU_SEKI(NwIX1) = MlZEIGAKU_SEKI(NwIX2) THEN
                        MlTUKI_SEKI(NwIX1) := MlTUKI_SEKI(NwIX1) + 1;
                        MlSUMI_SEKI(NwIX2) := 1;
                    END IF;
                END IF;

            END LOOP;

        END LOOP;

    END subDouzeiTukisu_SEKI;
-------------------------------------------------------------------------------
-- 19 同税額月数算出(基本) ※限度超過算出用
-------------------------------------------------------------------------------
    PROCEDURE subDouzeiTukisu_CHO IS
        NwIX1           NUMBER(2);
        NwIX2           NUMBER(2);
    BEGIN
        FOR NwIX1 IN 1..12 LOOP
            MlSUMI(NwIX1) := 0;
            MlTUKI(NwIX1) := 0;
        END LOOP;

        FOR NwIX1 IN 1..12 LOOP
            FOR NwIX2 IN 1..12 LOOP

                IF MlSUMI(NwIX2) != 1 THEN
                    IF MlCHOKA_SEKI(NwIX1) = MlCHOKA_SEKI(NwIX2) THEN
                        MlTUKI(NwIX1) := MlTUKI(NwIX1) + 1;
                        MlSUMI(NwIX2) := 1;
                    END IF;
                END IF;

            END LOOP;
        END LOOP;

    END subDouzeiTukisu_CHO;
--  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
-------------------------------------------------------------------------------
-- 産前産後限度超過計算
-------------------------------------------------------------------------------
    PROCEDURE subSanChokaCal(NwIX IN PLS_INTEGER)
    IS
      RlKANWAKOJIN          ZLBTKANWA_KOJIN_CAL%ROWTYPE; -- 計算緩和個人
      MwGENMENKOJIN         MTNUMARRAY12;                -- 対象月の減免有無
      SAN_CNT               NUMBER(2);                   -- 産前産後月数カウンタ
      MlZEIGAKU_MOTO        MTNUMARRAY12;                -- 積算算出用 税額元
      RwKOJINSAN            ZLBTKOJIN_CAL%ROWTYPE;       -- 計算個人
      NSAN_X                NUMBER;
      NSHIK_X               NUMBER;
      -- 各産前産後月の内容を取得する。
      PROCEDURE PROC_GET_SANX_SHIKX (i_IGETSU     IN PLS_INTEGER
                                    ,i_RwKOJINSAN IN ZLBTKOJIN_CAL%ROWTYPE)
      IS
      BEGIN
        NSAN_X  := 0;
        NSHIK_X := 0;
        CASE i_IGETSU
          WHEN 1 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_4;
            NSHIK_X := i_RwKOJINSAN.SHIK_4;
          WHEN 2 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_5;
            NSHIK_X := i_RwKOJINSAN.SHIK_5;
          WHEN 3 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_6;
            NSHIK_X := i_RwKOJINSAN.SHIK_6;
          WHEN 4 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_7;
            NSHIK_X := i_RwKOJINSAN.SHIK_7;
          WHEN 5 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_8;
            NSHIK_X := i_RwKOJINSAN.SHIK_8;
          WHEN 6 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_9;
            NSHIK_X := i_RwKOJINSAN.SHIK_9;
          WHEN 7 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_10;
            NSHIK_X := i_RwKOJINSAN.SHIK_10;
          WHEN 8 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_11;
            NSHIK_X := i_RwKOJINSAN.SHIK_11;
          WHEN 9 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_12;
            NSHIK_X := i_RwKOJINSAN.SHIK_12;
          WHEN 10 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_1;
            NSHIK_X := i_RwKOJINSAN.SHIK_1;
          WHEN 11 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_2;
            NSHIK_X := i_RwKOJINSAN.SHIK_2;
          WHEN 12 THEN
            NSAN_X  := i_RwKOJINSAN.SAN_3;
            NSHIK_X := i_RwKOJINSAN.SHIK_3;
          ELSE
            NULL;
        END CASE;

        NSAN_X  := NVL(NSAN_X,0);
        NSHIK_X := NVL(NSHIK_X,0);
      END PROC_GET_SANX_SHIKX;
    BEGIN
      -- 1.個人毎の産前産後減免額を税額に適用する。
      -- 積算算出用 税額元(引数.ループ回数) = 積算算出用 税額
      MlZEIGAKU_MOTO(NwIX) := MlZEIGAKU(NwIX);
      -- 計算個人を取得する。
      FOR RwKOJINSAN IN ClKOJIN LOOP
        -- 減免個人区分 = 減免個人取得関数を呼び出す
        NGENMEN_KOJIN_KBN := funcGenmenKojinGet(RwKOJINSAN);
        -- 減免計算区分 = 1の場合
        IF IGENMENKEISAN_KBN = 1 THEN
          NGENMEN_KOJIN_KBN := 0;
        END IF;

        -- 計算回数カウンタが2の場合
        IF NLOOP_CNT_NOW = 2 THEN
          -- 引数.ループ回数月の減免有無 = 0  (初期化)
          MwGENMENKOJIN(NwIX) := 0;
          -- 減免個人区分 = 1の場合
          IF NGENMEN_KOJIN_KBN = 1 THEN
            -- 対象月の減免有無(1～12) = 減免個人情報.介護減免(4～3)月
            MwGENMENKOJIN(1)   := NVL(RwGENMENKOJIN.K_GENMEN_4,0);
            MwGENMENKOJIN(2)   := NVL(RwGENMENKOJIN.K_GENMEN_5,0);
            MwGENMENKOJIN(3)   := NVL(RwGENMENKOJIN.K_GENMEN_6,0);
            MwGENMENKOJIN(4)   := NVL(RwGENMENKOJIN.K_GENMEN_7,0);
            MwGENMENKOJIN(5)   := NVL(RwGENMENKOJIN.K_GENMEN_8,0);
            MwGENMENKOJIN(6)   := NVL(RwGENMENKOJIN.K_GENMEN_9,0);
            MwGENMENKOJIN(7)   := NVL(RwGENMENKOJIN.K_GENMEN_10,0);
            MwGENMENKOJIN(8)   := NVL(RwGENMENKOJIN.K_GENMEN_11,0);
            MwGENMENKOJIN(9)   := NVL(RwGENMENKOJIN.K_GENMEN_12,0);
            MwGENMENKOJIN(10)  := NVL(RwGENMENKOJIN.K_GENMEN_1,0);
            MwGENMENKOJIN(11)  := NVL(RwGENMENKOJIN.K_GENMEN_2,0);
            MwGENMENKOJIN(12)  := NVL(RwGENMENKOJIN.K_GENMEN_3,0);
          END IF;
        END IF;

        -- 各月の計算個人.失業者区分を退避
        MlSHITSU_KBN(1)  := RwKOJINSAN.SHITSU_4;
        MlSHITSU_KBN(2)  := RwKOJINSAN.SHITSU_5;
        MlSHITSU_KBN(3)  := RwKOJINSAN.SHITSU_6;
        MlSHITSU_KBN(4)  := RwKOJINSAN.SHITSU_7;
        MlSHITSU_KBN(5)  := RwKOJINSAN.SHITSU_8;
        MlSHITSU_KBN(6)  := RwKOJINSAN.SHITSU_9;
        MlSHITSU_KBN(7)  := RwKOJINSAN.SHITSU_10;
        MlSHITSU_KBN(8)  := RwKOJINSAN.SHITSU_11;
        MlSHITSU_KBN(9)  := RwKOJINSAN.SHITSU_12;
        MlSHITSU_KBN(10) := RwKOJINSAN.SHITSU_1;
        MlSHITSU_KBN(11) := RwKOJINSAN.SHITSU_2;
        MlSHITSU_KBN(12) := RwKOJINSAN.SHITSU_3;

        BEGIN
          -- 計算緩和個人を取得
          SELECT *
            INTO RlKANWAKOJIN
            FROM ZLBTKANWA_KOJIN_CAL
           WHERE KOKU_SETAI_NO   = RwKOJINSAN.KOKU_SETAI_NO
             AND KOJIN_NO        = RwKOJINSAN.KOJIN_NO
             AND SANTEIDANTAI_CD = RwKOJINSAN.SANTEIDANTAI_CD
             AND CHOTEI_NENDO    = RwKOJINSAN.CHOTEI_NENDO
             AND NENDO_BUN       = RwKOJINSAN.NENDO_BUN
             AND TSUCHI_NO       = RwKOJINSAN.TSUCHI_NO
             AND SYS_TANMATSU_NO = RwKOJINSAN.SYS_TANMATSU_NO;

           -- 計算緩和個人の各月応能係数を退避する。
           MlOUNOU(1)  := RlKANWAKOJIN.OUNOU_4;
           MlOUNOU(2)  := RlKANWAKOJIN.OUNOU_5;
           MlOUNOU(3)  := RlKANWAKOJIN.OUNOU_6;
           MlOUNOU(4)  := RlKANWAKOJIN.OUNOU_7;
           MlOUNOU(5)  := RlKANWAKOJIN.OUNOU_8;
           MlOUNOU(6)  := RlKANWAKOJIN.OUNOU_9;
           MlOUNOU(7)  := RlKANWAKOJIN.OUNOU_10;
           MlOUNOU(8)  := RlKANWAKOJIN.OUNOU_11;
           MlOUNOU(9)  := RlKANWAKOJIN.OUNOU_12;
           MlOUNOU(10) := RlKANWAKOJIN.OUNOU_1;
           MlOUNOU(11) := RlKANWAKOJIN.OUNOU_2;
           MlOUNOU(12) := RlKANWAKOJIN.OUNOU_3;
         EXCEPTION
           WHEN OTHERS THEN
             MlOUNOU(1)  := 100;
             MlOUNOU(2)  := 100;
             MlOUNOU(3)  := 100;
             MlOUNOU(4)  := 100;
             MlOUNOU(5)  := 100;
             MlOUNOU(6)  := 100;
             MlOUNOU(7)  := 100;
             MlOUNOU(8)  := 100;
             MlOUNOU(9)  := 100;
             MlOUNOU(10) := 100;
             MlOUNOU(11) := 100;
             MlOUNOU(12) := 100;
         END;

         -- 産前産後月数カウンタを0で初期化する。
         SAN_CNT := 0;

         -- 計算個人.SAN_"引数.ループ回数"と計算個人.SHIK"引数.ループ回数"を取得する。
         PROC_GET_SANX_SHIKX(NwIX,RwKOJINSAN);
         -- 計算個人.SAN_"引数.ループ回数" = 1 の場合、
         IF NSAN_X = 1 THEN
           -- 計算個人.SAN4～計算個人.SAN3 = 1 である項目をカウントする。
           IF RwKOJINSAN.SAN_4 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_5 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_6 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_7 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_8 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_9 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_10 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_11 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_12 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_1 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_2 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           IF RwKOJINSAN.SAN_3 = 1 THEN
             SAN_CNT := SAN_CNT + 1;
           END IF;
           -- 計算個人.SHIK"引数.ループ回数" = 21 または23の場合  (21：世帯主(旧被扶養者)、23：世帯員(旧被扶養者))
           IF MlOUNOU(NwIX) <> 100 THEN
             -- 軽減7割の場合
             -- 積算算出用 税額 = 積算算出用 税額 - 切り上げ(均等割額  / 12 * 産前産後月数カウンタ)
             IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - CEIL(NlJKINTO / 12 * SAN_CNT);
             -- 軽減6割の場合
             -- 積算算出用 税額 = 積算算出用 税額 - 切り上げ(均等割額  / 12 * 産前産後月数カウンタ)
             ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - CEIL(NlJKINTO / 12 * SAN_CNT);
             -- 軽減2割の場合
             -- 積算算出用 税額 = 積算算出用 税額 - 切り上げ(均等割額 * 70 / 100 / 12 * 産前産後月数カウンタ)
             ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - CEIL(NlJKINTO * 70 / 100 / 12 * SAN_CNT);
             -- 上記以外の場合
             -- 積算算出用 税額 = 積算算出用 税額 - 切り上げ(均等割額 * 50 / 100 / 12 * 産前産後月数カウンタ)
             ELSE
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - CEIL(NlJKINTO * 50 / 100 / 12 * SAN_CNT);
             END IF;
           -- 上記以外の場合(旧被扶養者以外)
           ELSE
             -- 計算回数カウンタが1の場合
             IF NLOOP_CNT_NOW = 1 THEN
               -- 引数.ループ回数月の失業者区分が0より大きい場合
               -- 積算算出用 税額 = 積算算出用 税額 + TRUNC(計算個人.失業軽減適用後課税標準額 * 介護所得割率２ / 100 * 引数.ループ回数月の応能係数 / 100)
               IF MlSHITSU_KBN(NwIX) > 0 THEN
                 MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC(RwKOJINSAN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
               -- 上記以外の場合
               -- 積算算出用 税額 = 積算算出用 税額 + TRUNC(計算個人.課税標準額 * 介護所得割率２ / 100 * 引数.ループ回数月の応能係数 / 100)
               ELSE
                  MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC(RwKOJINSAN.KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
               END IF;
             -- 計算回数カウンタが2の場合
             ELSIF NLOOP_CNT_NOW = 2 THEN
               -- 引数.ループ回数月の失業者区分が0より大きい場合
               -- 積算算出用 税額 = 積算算出用 税額 + TRUNC(計算個人.失業軽減適用後課税標準額 * 介護所得割率２ / 100
               --                                           - 失業軽減適用後課税標準額 * 介護所得割率２ / 100 * 引数.ループ回数月の減免有無 * 減免個人情報.所得割減免率(介護) / 100)
               IF MlSHITSU_KBN(NwIX) > 0 THEN
                 MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC( RwKOJINSAN.SHITSU_KAHYO * NSHOTOKU_KAI / 100
                                                           - RwKOJINSAN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MwGENMENKOJIN(NwIX) * RwGENMENKOJIN.K_SHOTOKU_RITSU / 100);
               -- 上記以外の場合
               -- 積算算出用 税額 = 積算算出用 税額 + TRUNC(計算個人.課税標準額 * 介護所得割率２ / 100
               --                                           - 課税標準額 * 介護所得割率２ / 100 * 引数.ループ回数月の減免有無 * 減免個人情報.所得割減免率(介護) / 100)
               ELSE
                 MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC( RwKOJINSAN.KAHYO * NSHOTOKU_KAI / 100
                                                           - RwKOJINSAN.KAHYO * NSHOTOKU_KAI / 100 * MwGENMENKOJIN(NwIX) * RwGENMENKOJIN.K_SHOTOKU_RITSU / 100);
               END IF;
             ELSE
               NULL;
             END IF;

             -- 積算算出用 税額 = 積算算出用 税額 - 計算個人.介護産前産後所得割軽減額 - 切り上げ(均等割額 / 12 * 産前産後月数カウンタ)
             IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.SAN_KAI_GEN_SHOTOKU - NlJKGEN1 - CEIL((NlJKINTO - NlJKGEN1) / 12 * SAN_CNT);
             ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.SAN_KAI_GEN_SHOTOKU - NlJKGEN2 - CEIL((NlJKINTO - NlJKGEN2) / 12 * SAN_CNT);
             ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.SAN_KAI_GEN_SHOTOKU - NlJKGEN3 - CEIL((NlJKINTO - NlJKGEN3) / 12 * SAN_CNT);
             ELSE
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.SAN_KAI_GEN_SHOTOKU - CEIL(NlJKINTO / 12 * SAN_CNT);
             END IF;
           END IF;
         END IF;
      END LOOP;

      -- 2.産前産後者以外の均等割軽減、平等割軽減、未就学児減免を適用する。
      -- 軽減7割の場合
      IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
        -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割1(6割) + 軽減平等割1(6割))
        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 + NlJBGEN1);
      -- 軽減5割の場合
      ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
        -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割2(4割) + 軽減平等割2(4割))
        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 + NlJBGEN2);
      -- 軽減2割の場合
      ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
        -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割3(2割) + 軽減平等割3(2割))
        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 + NlJBGEN3);
      -- 上記以外の場合
      ELSE
        -- 積算算出用 税額 = 積算算出用 税額
        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX);
      END IF;

      -- 3.産前産後かつ限度超過の対象とならない場合を計算する。
      -- 積算算出用 税額がシステム条件.限度額未満の場合、
      IF MlZEIGAKU(NwIX) < NlJGENDOGAKU THEN
        MlZEIGAKU(NwIX) := MlZEIGAKU_MOTO(NwIX);

        -- 軽減7割の場合
        IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割1(6割) + 軽減平等割1(6割))
          --                                   - 各月産前産後有資格者数 * 均等割額
          --                                   - 各月旧被扶養者兼産前産後者数 * 均等割額
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 + NlJBGEN1)
                                             - MlSANCNT(NwIX) * NlJKINTO
                                             - MlSANCNT_K(NwIX) * NlJKINTO;
        -- 軽減5割の場合
        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割2(4割) + 軽減平等割2(4割))
          --                                   - 各月産前産後有資格者数 * 均等割額
          --                                   - 各月旧被扶養者兼産前産後者数 * 均等割額
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 + NlJBGEN2)
                                             - MlSANCNT(NwIX) * NlJKINTO
                                             - MlSANCNT_K(NwIX) * NlJKINTO;
        -- 軽減2割の場合
        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割3(2割) + 軽減平等割3(2割))
          --                                   - 各月産前産後有資格者数 * 均等割額
          --                                   - 各月旧被扶養者兼産前産後者数 * 切り上げ(均等割額 * 70 / 100)
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 + NlJBGEN3)
                                             - MlSANCNT(NwIX) * NlJKINTO
                                             - MlSANCNT_K(NwIX) * CEIL( NlJKINTO * 70 /100);
        -- 上記以外の場合
        ELSE
          -- 積算算出用 税額 = 積算算出用 税額 - 各月産前産後有資格者数 * 均等割額
          --                                   - 各月旧被扶養者兼産前産後者数 * 切り上げ(均等割額 * 50 / 100)
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - MlSANCNT(NwIX) * NlJKINTO
                                             - MlSANCNT_K(NwIX) * CEIL(NlJKINTO * 50 /100);
        END IF;
      --限度超過している場合の限度超過額調整用
      ELSE
        NwSANCHOKA_FLG := 1;
        MlZEIGAKU2(NwIX) := MlZEIGAKU_MOTO(NwIX);
        IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
          MlZEIGAKU2(NwIX) := MlZEIGAKU2(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 + NlJBGEN1)
                                               - MlSANCNT(NwIX) * NlJKINTO
                                               - MlSANCNT_K(NwIX) * NlJKINTO;
        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
          MlZEIGAKU2(NwIX) := MlZEIGAKU2(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 + NlJBGEN2)
                                               - MlSANCNT(NwIX) * NlJKINTO
                                               - MlSANCNT_K(NwIX) * NlJKINTO;
        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
          MlZEIGAKU2(NwIX) := MlZEIGAKU2(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 + NlJBGEN3)
                                               - MlSANCNT(NwIX) * NlJKINTO
                                               - MlSANCNT_K(NwIX) * CEIL( NlJKINTO * 70 /100);
        ELSE
          MlZEIGAKU2(NwIX) := MlZEIGAKU2(NwIX) - MlSANCNT(NwIX) * NlJKINTO
                                               - MlSANCNT_K(NwIX) * CEIL(NlJKINTO * 50 /100);
        END IF;
        IF MlZEIGAKU2(NwIX) >= NlJGENDOGAKU THEN
          MlZEIGAKU(NwIX) := MlZEIGAKU2(NWIX); --修正前仕様でも賦課限度の場合、限度超過額調整のため、こちらを使用
          NwSANCHOKA_FLG := 0;
        END IF;
      END IF;
    END subSanChokaCal;
    --  2024/05/06 ZCZL.ZHANGLEI ADD END
-------------------------------------------------------------------------------
-- 18 月割税額セット(基本)
-------------------------------------------------------------------------------
    PROCEDURE subTukiwari IS
        NwIX            NUMBER(2);
        NKAHYO_DOWN NUMBER;
        NKAHYO_OVER NUMBER;
        MwlSUMI_K       MTNUMARRAY1;              -- 済(経過措置用)
        MwlTUKI_K       MTNUMARRAY2;              -- 月数(経過措置用)
        MwlOUEKI_KIND   MTNUMARRAY3;              -- 応益係数
        NwGENMEN        NUMBER(15,3) := 0;
        NwWORK          NUMBER(10);
        MwGENMEN_UMU         MTNUMARRAY1;      -- 各月減免有無
        NwBYODOWARI          NUMBER(12) := 0;
        NwSHOTOKU_GENGAKU    NUMBER(12) := 0;  --計算用所得割減免額
        NwSISANZEI_GENGAKU   NUMBER(12) := 0;  --計算用資産割減免額
        NwKINTOWARI_GENGAKU  NUMBER(12) := 0;  --計算用均等割減免額
        NwBYODOWARI_GENGAKU  NUMBER(12) := 0;  --計算用平等割減免額
        --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
        MwSAN_K_KEIGEN  MTNUMARRAY15F;          -- 各月産前産後均等割軽減額
        MwSAN_K_KEIGEN2 MTNUMARRAY15F;          -- 各月旧被扶養者兼産前産後均等割軽減額
        NwCNT_K_MM           NUMBER(3) := 0;  --世帯内均等割月数
        NwCNT_K              NUMBER(3) := 0;  --世帯内均等割人数
        NwCNT_SAN_MM         NUMBER(3) := 0;  --世帯内産前産後月数
        NwSAN_K_GENKEI       NUMBER(15,3) := 0;  --産前産後均等割軽減額計
        NwSAN_K_GENKEI2      NUMBER(15,3) := 0;  --産前産後均等割軽減額計_計算個人
        NwSAN_SAGAKU         NUMBER(3) := 0;     --産前産後均等割軽減額差額
        --  2024/05/06 ZCZL.ZHANGLEI ADD END
    BEGIN

        BEGIN
--          -- 計算緩和個人の各月応益係数を退避
          SELECT CASE TAISHO_KBN_4  WHEN 2 THEN OUEKI_4  ELSE 100 END,
                 CASE TAISHO_KBN_5  WHEN 2 THEN OUEKI_5  ELSE 100 END,
                 CASE TAISHO_KBN_6  WHEN 2 THEN OUEKI_6  ELSE 100 END,
                 CASE TAISHO_KBN_7  WHEN 2 THEN OUEKI_7  ELSE 100 END,
                 CASE TAISHO_KBN_8  WHEN 2 THEN OUEKI_8  ELSE 100 END,
                 CASE TAISHO_KBN_9  WHEN 2 THEN OUEKI_9  ELSE 100 END,
                 CASE TAISHO_KBN_10 WHEN 2 THEN OUEKI_10 ELSE 100 END,
                 CASE TAISHO_KBN_11 WHEN 2 THEN OUEKI_11 ELSE 100 END,
                 CASE TAISHO_KBN_12 WHEN 2 THEN OUEKI_12 ELSE 100 END,
                 CASE TAISHO_KBN_1  WHEN 2 THEN OUEKI_1  ELSE 100 END,
                 CASE TAISHO_KBN_2  WHEN 2 THEN OUEKI_2  ELSE 100 END,
                 CASE TAISHO_KBN_3  WHEN 2 THEN OUEKI_3  ELSE 100 END
            INTO MlOUEKI(1) ,MlOUEKI(2) ,MlOUEKI(3) ,MlOUEKI(4) ,MlOUEKI(5) ,MlOUEKI(6) ,
                 MlOUEKI(7) ,MlOUEKI(8) ,MlOUEKI(9) ,MlOUEKI(10),MlOUEKI(11),MlOUEKI(12)
            FROM ZLBTKANWA_SETAI_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI
             AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
          WHEN OTHERS THEN
            MlOUEKI(1) := 100;
            MlOUEKI(2) := 100;
            MlOUEKI(3) := 100;
            MlOUEKI(4) := 100;
            MlOUEKI(5) := 100;
            MlOUEKI(6) := 100;
            MlOUEKI(7) := 100;
            MlOUEKI(8) := 100;
            MlOUEKI(9) := 100;
            MlOUEKI(10):= 100;
            MlOUEKI(11):= 100;
            MlOUEKI(12):= 100;
        END;

        -- 応益係数が同じ月数MwlTUKI_Kとその時点の応益係数MwlOUEKI_KINDを算出
        -- 配列初期化
        FOR NwIX1 IN 1..12 LOOP
          MwlSUMI_K(NwIX1)       := 0;
          MwlTUKI_K(NwIX1)       := 0;
          MwlOUEKI_KIND(NwIX1)   := 0;
        END LOOP;

        FOR NwIX1 IN 1..12 LOOP
          FOR NwIX2 IN 1..12 LOOP
            IF MwlSUMI_K(NwIX2) != 1 THEN
              IF MlOUEKI(NwIX1) = MlOUEKI(NwIX2) THEN
                MwlTUKI_K(NwIX1) := MwlTUKI_K(NwIX1) + 1;
                MwlSUMI_K(NwIX2) := 1;
                MwlOUEKI_KIND(NwIX1) := MlOUEKI(NwIX1);
              END IF;
            END IF;
          END LOOP;
        END LOOP;

        -- 各月減免有無を退避
        MwGENMEN_UMU(1)  := RlGENMEN_KOJIN.K_GENMEN_4;
        MwGENMEN_UMU(2)  := RlGENMEN_KOJIN.K_GENMEN_5;
        MwGENMEN_UMU(3)  := RlGENMEN_KOJIN.K_GENMEN_6;
        MwGENMEN_UMU(4)  := RlGENMEN_KOJIN.K_GENMEN_7;
        MwGENMEN_UMU(5)  := RlGENMEN_KOJIN.K_GENMEN_8;
        MwGENMEN_UMU(6)  := RlGENMEN_KOJIN.K_GENMEN_9;
        MwGENMEN_UMU(7)  := RlGENMEN_KOJIN.K_GENMEN_10;
        MwGENMEN_UMU(8)  := RlGENMEN_KOJIN.K_GENMEN_11;
        MwGENMEN_UMU(9)  := RlGENMEN_KOJIN.K_GENMEN_12;
        MwGENMEN_UMU(10) := RlGENMEN_KOJIN.K_GENMEN_1;
        MwGENMEN_UMU(11) := RlGENMEN_KOJIN.K_GENMEN_2;
        MwGENMEN_UMU(12) := RlGENMEN_KOJIN.K_GENMEN_3;
--            IF MlCNT(NwIX) > 0 THEN         -- 対象月に有資格者あり



--        -- 応益係数が同じ月数MwlTUKI_Kとその時点の応益係数MwlOUEKI_KINDを算出
--        -- 配列初期化
--        --以下の計算式で経過措置後の平等割の金額を応益係数の種類毎に算出
--        --平等割 Ａ＝TRUNC((システム条件の平等割額)×応益係数÷100×該当月数÷12))
--        --所得割2段階
--          -- 課税標準額が同額の月数MlTUKI_Kとその時点の課税標準額MwlKAHYO_KINDを算出
--          -- 配列初期化
--          --上で算出した課税標準額が同額の月数ごとに経過措置後の所得割２段階の計算を行う。
--            -- 所得割２段階対応
--          --算出した月数から年額を算出 （年額 ＝ 月毎の税額×月数÷月数12）
        --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
        NKANYUTSUKI_CNT := 0;
        FOR NwIX IN 1..12 LOOP
            MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX)
                                  + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
            -- 所得2段割の所得足し込み
            IF NSHOTOKU_2DANKAI = 1 THEN
              IF MlKAHYO_SEKI(NwIX) > NSHOTOKU_HANTEI_GAKU THEN
                NKAHYO_OVER := MlKAHYO_SEKI(NwIX) - NSHOTOKU_HANTEI_GAKU;
                NKAHYO_DOWN := NSHOTOKU_HANTEI_GAKU;
              ELSE
                NKAHYO_OVER := 0;
                NKAHYO_DOWN := MlKAHYO_SEKI(NwIX);
              END IF;
              MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX) + NKAHYO_OVER * NSHOTOKU_KAI_OVER / 100;
              MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX) + NKAHYO_DOWN * NSHOTOKU_KAI / 100;
            END IF;

            NwWORK := MlZEIGAKU_SEKI(NwIX);

            -- 軽減均等・平等マイナス
            IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割の場合
              NwWORK := NwWORK - (RlKIHON.KINTO_CNT * NlJKGEN1 + NlJBGEN1);
            ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN    -- 軽減4割の場合
              NwWORK := NwWORK - (RlKIHON.KINTO_CNT * NlJKGEN2 + NlJBGEN2);
            ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN    -- 軽減2割の場合
              NwWORK := NwWORK - (RlKIHON.KINTO_CNT * NlJKGEN3 + NlJBGEN3);
            END IF;


            IF MlCNT(NwIX) > 0 THEN         -- 対象月に有資格者あり
--                --該当月の均等割算出
                -- 平等割額を加算する
                --優先区分が「個人／率／応能応益」または「世帯／率／応能応益」
                IF RlGENMEN_KOJIN.YUSEN_KBN IN (0, 1) THEN
                  IF NLOOP_CNT_NOW = 1 THEN
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                     + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
                    NwBYODOWARI     := NwBYODOWARI
                                     + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
                  ELSIF NLOOP_CNT_NOW = 2 THEN
                    IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割の場合
                      MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                       + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN1)
                                       * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                      NwBYODOWARI     := NwBYODOWARI
                                       + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN1)
                                       * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                    ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN    -- 軽減4割の場合
                      MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                       + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2)
                                       * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                      NwBYODOWARI     := NwBYODOWARI
                                       + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2)
                                       * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                    ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN    -- 軽減2割の場合
                      MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                       + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN3)
                                       * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                      NwBYODOWARI     := NwBYODOWARI
                                       + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN3)
                                       * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                    ELSE
                      MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                       + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                      NwBYODOWARI     := NwBYODOWARI
                                       + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.K_BYODOWARI_RITSU / 100);
                    END IF;
                  END IF;
                ELSE
                  MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                   + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
                END IF;
                -- 所得2段割の所得足し込み
                IF NSHOTOKU_2DANKAI = 1 THEN
                  IF MlKAHYO(NwIX) > NSHOTOKU_HANTEI_GAKU THEN
                    NKAHYO_OVER := MlKAHYO(NwIX) - NSHOTOKU_HANTEI_GAKU;
                    NKAHYO_DOWN := NSHOTOKU_HANTEI_GAKU;
                  ELSE
                    NKAHYO_OVER := 0;
                    NKAHYO_DOWN := MlKAHYO(NwIX);
                  END IF;
                  MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + NKAHYO_OVER * NSHOTOKU_KAI_OVER / 100;
                  MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + NKAHYO_DOWN * NSHOTOKU_KAI / 100;
                END IF;

                IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割
                    --  2024/05/06 ZCZL.ZHANGLEI UPDATE START 0.3.000.100:国保２次にマージ作業
                    --MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - (MlCNT(NwIX) * NlJKGEN1 + NlJBGEN1);
                    -- 軽減均等
                    --NlKEIGEN_K_6_ZEN   := NlKEIGEN_K_6_ZEN   + (MlCNT(NwIX) * NlJKGEN1 / 12);
                    --NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + (MlCNT(NwIX) * NlJKGEN1 / 12);
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 + NlJBGEN1)
                                                       - (MlSANCNT(NwIX) * NlJKINTO) - (MlSANCNT_K(NwIX) * NlJKINTO);
                    END IF;
                    NlKEIGEN_K_6_ZEN   := NlKEIGEN_K_6_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 / 12)
                                                             + (MlSANCNT(NwIX) *(NlJKINTO / 12)) + (MlSANCNT_K(NwIX) * (NlJKINTO / 12));
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 / 12)
                                                             + (MlSANCNT(NwIX) * (NlJKINTO / 12)) + (MlSANCNT_K(NwIX) * (NlJKINTO / 12));
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN1 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO / 12 - NlJKGEN1 / 12);
                    --  2024/05/06 ZCZL.ZHANGLEI UPDATE END
                    -- 軽減平等
                    NlKEIGEN_B_6_ZEN   := NlKEIGEN_B_6_ZEN   + (NlJBGEN1 / 12);
                    NlKEIGEN_BYODO     := NlKEIGEN_BYODO     + (NlJBGEN1 / 12);

                ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN    -- 軽減4割
                    --  2024/05/06 ZCZL.ZHANGLEI UPDATE START 0.3.000.100:国保２次にマージ作業
                    --MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - (MlCNT(NwIX) * NlJKGEN2 + NlJBGEN2);
                    -- 軽減均等
                    --NlKEIGEN_K_4_ZEN   := NlKEIGEN_K_4_ZEN   + (MlCNT(NwIX) * NlJKGEN2 / 12);
                    --NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + (MlCNT(NwIX) * NlJKGEN2 / 12);
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 + NlJBGEN2)
                                                       - (MlSANCNT(NwIX) * NlJKINTO) - (MlSANCNT_K(NwIX) * NlJKINTO);
                    END IF;
                    -- 軽減均等
                    NlKEIGEN_K_4_ZEN   := NlKEIGEN_K_4_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 / 12)
                                                             + (MlSANCNT(NwIX) * (NlJKINTO / 12)) + (MlSANCNT_K(NwIX) * (NlJKINTO / 12));
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 / 12)
                                                             + (MlSANCNT(NwIX) * (NlJKINTO / 12)) + (MlSANCNT_K(NwIX) * (NlJKINTO / 12));
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN2 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12);
                    --  2024/05/06 ZCZL.ZHANGLEI UPDATE END
                    -- 軽減平等
                    NlKEIGEN_B_4_ZEN   := NlKEIGEN_B_4_ZEN   + (NlJBGEN2 / 12);
                    NlKEIGEN_BYODO     := NlKEIGEN_BYODO     + (NlJBGEN2 / 12);

                ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN    -- 軽減2割
                    --  2024/05/06 ZCZL.ZHANGLEI UPDATE START 0.3.000.100:国保２次にマージ作業
                    --MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - (MlCNT(NwIX) * NlJKGEN3 + NlJBGEN3);
                    -- 軽減均等
                    --NlKEIGEN_K_2_ZEN   := NlKEIGEN_K_2_ZEN   + (MlCNT(NwIX) * NlJKGEN3 / 12);
                    --NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + (MlCNT(NwIX) * NlJKGEN3 / 12);
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 + NlJBGEN3)
                                                       - (MlSANCNT(NwIX) * NlJKINTO) - (MlSANCNT_K(NwIX) * CEIL(NlJKINTO * 70 / 100));
                    END IF;
                    -- 軽減均等
                    NlKEIGEN_K_2_ZEN   := NlKEIGEN_K_2_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 / 12)
                                                             + (MlSANCNT(NwIX) * (NlJKINTO / 12)) + (MlSANCNT_K(NwIX) * (NlJKINTO * 70 / 100 / 12));
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 / 12)
                                                             + (MlSANCNT(NwIX) * (NlJKINTO / 12)) + (MlSANCNT_K(NwIX) * (NlJKINTO * 70 / 100 / 12));
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN3 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12);
                    --  2024/05/06 ZCZL.ZHANGLEI UPDATE END
                    -- 軽減平等
                    NlKEIGEN_B_2_ZEN   := NlKEIGEN_B_2_ZEN   + (NlJBGEN3 / 12);
                    NlKEIGEN_BYODO     := NlKEIGEN_BYODO     + (NlJBGEN3 / 12);
                --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                ELSE
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - (MlSANCNT(NwIX) * NlJKINTO) - (MlSANCNT_K(NwIX) * CEIL(NlJKINTO * 50 / 100));
                    END IF;
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + (MlSANCNT(NwIX) * (NlJKINTO / 12)) + (MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12));
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12);
                --  2024/05/06 ZCZL.ZHANGLEI ADD END
                END IF;
                --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                -- 産前産後均等割軽減額を更新
                NwSAN_K_GENKEI     := NwSAN_K_GENKEI     +  MwSAN_K_KEIGEN(NwIX) +  MwSAN_K_KEIGEN2(NwIX);
                IF NLOOP_CNT_NOW = 1 THEN
                IF MlSANCNT(NwIX) >= 1 THEN
                  BEGIN
                    vSQL :=          'UPDATE ZLBTKOJIN_CAL';
                    vSQL := vSQL || ' SET ZLBTKOJIN_CAL.SAN_KAI_GEN_KINTO   = ZLBTKOJIN_CAL.SAN_KAI_GEN_KINTO  + ' || MwSAN_K_KEIGEN(NwIX) / MlSANCNT(NwIX);
                    vSQL := vSQL || ' WHERE EXISTS( SELECT * FROM ZLBTKANWA_KOJIN_CAL WHERE';
                    vSQL := vSQL || ' ZLBTKOJIN_CAL.KOKU_SETAI_NO   = ZLBTKANWA_KOJIN_CAL.KOKU_SETAI_NO';
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.KOJIN_NO   = ZLBTKANWA_KOJIN_CAL.KOJIN_NO';
                    IF NwIX < 10 THEN
                      vSQL := vSQL || '  AND ZLBTKANWA_KOJIN_CAL.OUNOU_' || TO_CHAR(NwIX + 3) || ' = 100)';
                    ELSE
                      vSQL := vSQL || '  AND ZLBTKANWA_KOJIN_CAL.OUNOU_' || TO_CHAR(NwIX - 9) || ' = 100)';
                    END IF;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.KOKU_SETAI_NO   = ' || i_NSETAI;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.SANTEIDANTAI_CD = ' || i_NDANTAI;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.CHOTEI_NENDO    = ' || i_NNENDO;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.NENDO_BUN       = ' || i_NNENDO_BUN;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.TSUCHI_NO       = ' || i_NNUSHI;
                    IF NwIX < 10 THEN
                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SAN_' || TO_CHAR(NwIX + 3) || ' = 1';
                    ELSE
                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SAN_' || TO_CHAR(NwIX - 9) || ' = 1';
                    END IF;
                    IF NwIX < 10 THEN
                      vSQL := vSQL || '  AND KAI_SHIK_' || TO_CHAR(NwIX + 3) || ' = 1';
                    ELSE
                      vSQL := vSQL || '  AND KAI_SHIK_' || TO_CHAR(NwIX - 9) || ' = 1';
                    END IF;
                    EXECUTE IMMEDIATE vSQL;
                    EXCEPTION
                      WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subTukiwari 計算個人更新(国保世帯番号='||
                                  i_NSETAI||')'||SQLERRM;
                  END;
                END IF;
                END IF;
                IF MlSANCNT_K(NwIX) >= 1 THEN
                  BEGIN
                    -- 計算個人update
                    vSQL :=          'UPDATE ZLBTKOJIN_CAL';
                    vSQL := vSQL || ' SET ZLBTKOJIN_CAL.SAN_KAI_GEN_KINTO   = ZLBTKOJIN_CAL.SAN_KAI_GEN_KINTO  + ' || MwSAN_K_KEIGEN2(NwIX) / MlSANCNT_K(NwIX);
                    vSQL := vSQL || ' WHERE EXISTS( SELECT * FROM ZLBTKANWA_KOJIN_CAL WHERE';
                    vSQL := vSQL || ' ZLBTKOJIN_CAL.KOKU_SETAI_NO   = ZLBTKANWA_KOJIN_CAL.KOKU_SETAI_NO';
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.KOJIN_NO   = ZLBTKANWA_KOJIN_CAL.KOJIN_NO';
                    IF NwIX < 10 THEN
                      vSQL := vSQL || '  AND ZLBTKANWA_KOJIN_CAL.OUNOU_' || TO_CHAR(NwIX + 3) || ' < 100)';
                    ELSE
                      vSQL := vSQL || '  AND ZLBTKANWA_KOJIN_CAL.OUNOU_' || TO_CHAR(NwIX - 9) || ' < 100)';
                    END IF;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.KOKU_SETAI_NO   = ' || i_NSETAI;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.SANTEIDANTAI_CD = ' || i_NDANTAI;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.CHOTEI_NENDO    = ' || i_NNENDO;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.NENDO_BUN       = ' || i_NNENDO_BUN;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.TSUCHI_NO       = ' || i_NNUSHI;
                    IF NwIX < 10 THEN
                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SAN_' || TO_CHAR(NwIX + 3) || ' = 1';
                    ELSE
                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SAN_' || TO_CHAR(NwIX - 9) || ' = 1';
                    END IF;
                    EXECUTE IMMEDIATE vSQL;
                    EXCEPTION
                      WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subTukiwari 計算個人更新(国保世帯番号='||
                                  i_NSETAI||')'||SQLERRM;
                  END;
                END IF;
                --  2024/05/06 ZCZL.ZHANGLEI ADD END
                IF N_INA_GENMEN = 1 THEN
                  NwGENMEN := (trunc(MlZEIGAKU(NwIX) * (1.00 - N_INA_GENMEN_RITU)));
                  MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - NwGENMEN;
                  IF MwlTUKI_K(NwIX) > 0 THEN
                    N_INA_GENMEN_GAKU_K := N_INA_GENMEN_GAKU_K + NwGENMEN;
                  END IF;
                END IF;

                --優先区分が「世帯／額／応能応益」
                IF RlGENMEN_KOJIN.YUSEN_KBN = 2 THEN
                  IF NLOOP_CNT_NOW = 1 THEN
                    NwBYODOWARI     := NwBYODOWARI
                                     + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
                  ELSIF NLOOP_CNT_NOW = 2 THEN
                    MlZEIGAKU(NwIX)     := MlZEIGAKU(NwIX) -
                                           RlGENMEN_KOJIN.K_SHOTOKU_GENGAKU -
                                           RlGENMEN_KOJIN.K_SISANZEI_GENGAKU -
                                           RlGENMEN_KOJIN.K_KINTOWARI_GENGAKU -
                                           RlGENMEN_KOJIN.K_BYODOWARI_GENGAKU;
                    NwSHOTOKU_GENGAKU   := NwSHOTOKU_GENGAKU + RlGENMEN_KOJIN.K_SHOTOKU_GENGAKU;     --計算用所得割減免額
                    NwSISANZEI_GENGAKU  := NwSISANZEI_GENGAKU + RlGENMEN_KOJIN.K_SISANZEI_GENGAKU;   --計算用資産割減免額
                    NwKINTOWARI_GENGAKU := NwKINTOWARI_GENGAKU + RlGENMEN_KOJIN.K_KINTOWARI_GENGAKU; --計算用均等割減免額
                    NwBYODOWARI_GENGAKU := NwBYODOWARI_GENGAKU + RlGENMEN_KOJIN.K_BYODOWARI_GENGAKU; --計算用平等割減免額
                  END IF;
                END IF;
                IF MlZEIGAKU(NwIX) > NlJGENDOGAKU THEN
                  --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                  IF NwSANCHOKA_FLG = 1 THEN
                    MlCHOKA_MAE(NwIX) := MlZEIGAKU(NwIX);
                    MlZEIGAKU(NwIX) := NlJGENDOGAKU;
                    MlCHOKA_SEKI(NwIX) := -1* (MlZEIGAKU(NwIX) - MlZEIGAKU2(NwIX));
                    --フラグ初期化
                    NwSANCHOKA_FLG := 0;
                    IGENDO_HASU_KBN := 1;
                  ELSE
                  --  2024/05/06 ZCZL.ZHANGLEI ADD END
                    MlCHOKA_SEKI(NwIX) := MlZEIGAKU(NwIX) - NlJGENDOGAKU;
                  END IF;
                  MlCHOKA_MAE(NwIX) := MlZEIGAKU(NwIX);
                  MlZEIGAKU(NwIX)   := NlJGENDOGAKU;

                --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
                END IF;
                --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                NwCNT_K_MM := NwCNT_K_MM + MlCNT(NwIX);
                -- 変数.世帯内均等割人数カウンタが人員(各月有資格者数)より小さい場合
                IF NwCNT_K < MlCNT(NwIX) THEN
                  NwCNT_K := MlCNT(NwIX);
                END IF;
                -- 人員(各月有資格者数)が0より大きい場合
                IF MlCNT(NwIX) > 0 THEN
                  NKANYUTSUKI_CNT := NKANYUTSUKI_CNT + 1;
                END IF;
                NwCNT_SAN_MM := NwCNT_SAN_MM + MlSANCNT(NwIX) + MlSANCNT_K(NwIX);
                --  2024/05/06 ZCZL.ZHANGLEI ADD END
            END IF;
        END LOOP;
        --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
        IF NLOOP_CNT_NOW = 1  AND NwCNT_SAN_MM > 0 THEN
          NlKEIGEN_KINTO := NlKEIGEN_KINTO - NwSAN_K_GENKEI;
        --①計算個人に登録された産前産後均等割軽減額の小数部分を切り上げた額の合計を、変数.産前産後均等割軽減額計_計算個人に格納する。
        SELECT NVL(SUM(CEIL(SAN_KAI_GEN_KINTO)), 0)
          INTO NwSAN_K_GENKEI2
          FROM ZLBTKOJIN_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NNUSHI;
        --②変数.産前産後均等割軽減額計の小数部分を切り上げる。
        NwSAN_K_GENKEI := CEIL(NwSAN_K_GENKEI);
        --③変数.産前産後均等割軽減額差額 = 変数.産前産後均等割軽減額計_計算個人 - 変数.産前産後均等割軽減額計
        NwSAN_SAGAKU := NwSAN_K_GENKEI2 - NwSAN_K_GENKEI;
        --④計算個人に登録された産前産後均等割軽減額の小数部分を切り上げる
        UPDATE ZLBTKOJIN_CAL
           SET SAN_KAI_GEN_KINTO = NVL(CEIL(SAN_KAI_GEN_KINTO), 0)
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NNUSHI;
        --⑤計算個人に登録された産前産後均等割軽減額で最大の値から変数.産前産後均等割軽減額差額を減算する。
        UPDATE ZLBTKOJIN_CAL
           SET SAN_KAI_GEN_KINTO = NVL(SAN_KAI_GEN_KINTO, 0) - NVL(NwSAN_SAGAKU, 0)
         WHERE (KOJIN_NO, SAN_KAI_GEN_KINTO) = (SELECT KOJIN_NO, SAN_KAI_GEN_KINTO
                                                  FROM ZLBTKOJIN_CAL
                                                 WHERE KOKU_SETAI_NO   = i_NSETAI
                                                   AND SANTEIDANTAI_CD = i_NDANTAI
                                                   AND CHOTEI_NENDO    = i_NNENDO
                                                   AND NENDO_BUN       = i_NNENDO_BUN
                                                   AND TSUCHI_NO       = i_NNUSHI
                                                 ORDER BY SAN_KAI_GEN_KINTO DESC, KOJIN_NO DESC
                                                          OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY)
           AND KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NNUSHI
           AND ROWNUM          = 1;
        --⑥介護産前産後均等割軽減額計 = 変数.産前産後均等割軽減額計
        RlEXT.SAN_KAI_GEN_K_KEI := NwSAN_K_GENKEI;
        NlKEIGEN_KINTO := NlKEIGEN_KINTO + NwSAN_K_GENKEI;
        ELSIF NLOOP_CNT_NOW = 2 AND NwCNT_SAN_MM > 0 THEN
          NlKEIGEN_KINTO := NlKEIGEN_KINTO - NwSAN_K_GENKEI;
          NwSAN_K_GENKEI := CEIL(NwSAN_K_GENKEI);
          NlKEIGEN_KINTO := NlKEIGEN_KINTO + NwSAN_K_GENKEI;
        END IF;
        --  2024/05/06 ZCZL.ZHANGLEI ADD END
        --優先区分が「個人／率／応能応益」または「世帯／率／応能応益」
        IF RlGENMEN_KOJIN.YUSEN_KBN IN (0, 1) THEN
          IF NLOOP_CNT_NOW = 1 THEN
            UPDATE ZLBTGENMEN_KOJIN_CAL
              SET K_BYODOWARI_KISO = TRUNC(NwBYODOWARI / 12)
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND NENDO_BUN       = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO = i_VTANMATSU;
          ELSIF NLOOP_CNT_NOW = 2 THEN
            UPDATE ZLBTGENMEN_KOJIN_CAL
              SET K_BYODOWARI_GENGAKU = K_BYODOWARI_KISO - TRUNC(NwBYODOWARI / 12)
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND NENDO_BUN       = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO = i_VTANMATSU;
          END IF;
        --優先区分が「世帯／額／応能応益」
        ELSIF RlGENMEN_KOJIN.YUSEN_KBN = 2 THEN
          IF NLOOP_CNT_NOW = 1 THEN
            UPDATE ZLBTGENMEN_KOJIN_CAL
              SET K_BYODOWARI_KISO = TRUNC(NwBYODOWARI / 12)
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND NENDO_BUN       = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO = i_VTANMATSU;
          ELSIF NLOOP_CNT_NOW = 2 THEN
            UPDATE ZLBTGENMEN_KOJIN_CAL
              SET K_SHOTOKU_GENGAKU   = TRUNC(NwSHOTOKU_GENGAKU / 12),
                  K_SISANZEI_GENGAKU  = TRUNC(NwSISANZEI_GENGAKU / 12),
                  K_KINTOWARI_GENGAKU = TRUNC(NwKINTOWARI_GENGAKU / 12),
                  K_BYODOWARI_GENGAKU = TRUNC(NwBYODOWARI_GENGAKU / 12)
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND NENDO_BUN       = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO = i_VTANMATSU;
          END IF;
        END IF;

    END subTukiwari;
-------------------------------------------------------------------------------
-- 17 月軽減セット
-------------------------------------------------------------------------------
    PROCEDURE subTukiKeigenSave IS
    BEGIN

        MlKEIGEN_KBN(1)  := RlKIHON.KEIGEN_4;
        MlKEIGEN_KBN(2)  := RlKIHON.KEIGEN_5;
        MlKEIGEN_KBN(3)  := RlKIHON.KEIGEN_6;
        MlKEIGEN_KBN(4)  := RlKIHON.KEIGEN_7;
        MlKEIGEN_KBN(5)  := RlKIHON.KEIGEN_8;
        MlKEIGEN_KBN(6)  := RlKIHON.KEIGEN_9;
        MlKEIGEN_KBN(7)  := RlKIHON.KEIGEN_10;
        MlKEIGEN_KBN(8)  := RlKIHON.KEIGEN_11;
        MlKEIGEN_KBN(9)  := RlKIHON.KEIGEN_12;
        MlKEIGEN_KBN(10) := RlKIHON.KEIGEN_1;
        MlKEIGEN_KBN(11) := RlKIHON.KEIGEN_2;
        MlKEIGEN_KBN(12) := RlKIHON.KEIGEN_3;

    END subTukiKeigenSave;
-------------------------------------------------------------------------------
-- 16 月割税額算出準備(基本)
-------------------------------------------------------------------------------
    PROCEDURE subTukiwariMae(i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) IS
        NwIX                    NUMBER(2);
        RlKANWAKOJIN            ZLBTKANWA_KOJIN_CAL%ROWTYPE;
        MwGENMENKOJIN           MTNUMARRAY12;   -- 各月の減免率
        NwKOJINSHOTOKU          NUMBER(12) := 0;
        NwKOJINSISANZEI         NUMBER(12) := 0;
        NwKOJINKINTOWARI        NUMBER(12) := 0;
        NwKOJINSHIKAKU_TUKISU_K NUMBER(2)  := 0;
        --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
        NwKOJINKINTOWARI_SAN    NUMBER(12) := 0;
    BEGIN

        NGENMEN_KOJIN_KBN := funcGenmenKojinGet(i_RKOJIN);
        IF  IGENMENKEISAN_KBN = 1 THEN
            NGENMEN_KOJIN_KBN := 0;
        END IF;
        IF NGENMEN_KOJIN_KBN = 1 THEN
            NGENMEN_KOJIN_KBN2 := 1;
        END IF;
        -- ◆
        -- 通常課税計算
        IF (i_CAL_KBN = c_CAL_KBN_TU AND
            (i_RKOJIN.NEW_SHIK_KBN IN (1, 3, 7, 9) OR
             (i_RKOJIN.NEW_SHIK_KBN IN (2, 8) AND i_RKOJIN.SEKISAN_GAI_KBN = 1)) ) OR
        -- 賦課期日時点
           (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND
            i_RKOJIN.NEW_SHIK_KBN IN (1, 3) ) THEN

          -- ◆
          -- 通常課税計算
          IF (i_CAL_KBN = c_CAL_KBN_TU AND
              (i_RKOJIN.NEW_KAI_SHIK_KBN IN (0, 1) OR
               (i_RKOJIN.NEW_KAI_SHIK_KBN = 2 AND i_RKOJIN.SEKISAN_GAI_KBN = 1)) ) OR
          -- 賦課期日時点
             (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND
              i_RKOJIN.NEW_KAI_SHIK_KBN IN (1) ) THEN

                -- 計算個人の各月資格区分を退避
                MlSHIK_KBN(1)  := i_RKOJIN.KAI_SHIK_4;
                MlSHIK_KBN(2)  := i_RKOJIN.KAI_SHIK_5;
                MlSHIK_KBN(3)  := i_RKOJIN.KAI_SHIK_6;
                MlSHIK_KBN(4)  := i_RKOJIN.KAI_SHIK_7;
                MlSHIK_KBN(5)  := i_RKOJIN.KAI_SHIK_8;
                MlSHIK_KBN(6)  := i_RKOJIN.KAI_SHIK_9;
                MlSHIK_KBN(7)  := i_RKOJIN.KAI_SHIK_10;
                MlSHIK_KBN(8)  := i_RKOJIN.KAI_SHIK_11;
                MlSHIK_KBN(9)  := i_RKOJIN.KAI_SHIK_12;
                MlSHIK_KBN(10) := i_RKOJIN.KAI_SHIK_1;
                MlSHIK_KBN(11) := i_RKOJIN.KAI_SHIK_2;
                MlSHIK_KBN(12) := i_RKOJIN.KAI_SHIK_3;
                -- 計算個人の各月失業資格区分を退避
                IF i_RKOJIN.NEW_SHITSU_KBN > 0 THEN
                  MlSHITSU_KBN(1)  := i_RKOJIN.SHITSU_4;
                  MlSHITSU_KBN(2)  := i_RKOJIN.SHITSU_5;
                  MlSHITSU_KBN(3)  := i_RKOJIN.SHITSU_6;
                  MlSHITSU_KBN(4)  := i_RKOJIN.SHITSU_7;
                  MlSHITSU_KBN(5)  := i_RKOJIN.SHITSU_8;
                  MlSHITSU_KBN(6)  := i_RKOJIN.SHITSU_9;
                  MlSHITSU_KBN(7)  := i_RKOJIN.SHITSU_10;
                  MlSHITSU_KBN(8)  := i_RKOJIN.SHITSU_11;
                  MlSHITSU_KBN(9)  := i_RKOJIN.SHITSU_12;
                  MlSHITSU_KBN(10) := i_RKOJIN.SHITSU_1;
                  MlSHITSU_KBN(11) := i_RKOJIN.SHITSU_2;
                  MlSHITSU_KBN(12) := i_RKOJIN.SHITSU_3;
                ELSE
                  FOR NwIX IN 1..12 LOOP
                    MlSHITSU_KBN(NwIX) := 0;
                  END LOOP;
                END IF;
                --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                IF i_RKOJIN.NEW_SAN_KBN >= 1 THEN
                  MlSAN_KBN(1)  := i_RKOJIN.SAN_4;
                  MlSAN_KBN(2)  := i_RKOJIN.SAN_5;
                  MlSAN_KBN(3)  := i_RKOJIN.SAN_6;
                  MlSAN_KBN(4)  := i_RKOJIN.SAN_7;
                  MlSAN_KBN(5)  := i_RKOJIN.SAN_8;
                  MlSAN_KBN(6)  := i_RKOJIN.SAN_9;
                  MlSAN_KBN(7)  := i_RKOJIN.SAN_10;
                  MlSAN_KBN(8)  := i_RKOJIN.SAN_11;
                  MlSAN_KBN(9)  := i_RKOJIN.SAN_12;
                  MlSAN_KBN(10) := i_RKOJIN.SAN_1;
                  MlSAN_KBN(11) := i_RKOJIN.SAN_2;
                  MlSAN_KBN(12) := i_RKOJIN.SAN_3;
                ELSE
                  FOR NwIX IN 1..12 LOOP
                    MlSAN_KBN(NwIX) := 0;
                  END LOOP;
                END IF;
                --  2024/05/06 ZCZL.ZHANGLEI ADD END
                BEGIN
                  SELECT *
                    INTO RlKANWAKOJIN
                    FROM ZLBTKANWA_KOJIN_CAL
                   WHERE KOKU_SETAI_NO   = i_RKOJIN.KOKU_SETAI_NO
                     AND KOJIN_NO        = i_RKOJIN.KOJIN_NO
                     AND SANTEIDANTAI_CD = i_RKOJIN.SANTEIDANTAI_CD
                     AND CHOTEI_NENDO    = i_RKOJIN.CHOTEI_NENDO
                     AND NENDO_BUN       = i_RKOJIN.NENDO_BUN
                     AND TSUCHI_NO       = i_RKOJIN.TSUCHI_NO
                     AND SYS_TANMATSU_NO = i_RKOJIN.SYS_TANMATSU_NO;

                  -- 計算緩和個人の各月応益係数を退避
                  MlOUEKI(1)  := RlKANWAKOJIN.OUEKI_4;
                  MlOUEKI(2)  := RlKANWAKOJIN.OUEKI_5;
                  MlOUEKI(3)  := RlKANWAKOJIN.OUEKI_6;
                  MlOUEKI(4)  := RlKANWAKOJIN.OUEKI_7;
                  MlOUEKI(5)  := RlKANWAKOJIN.OUEKI_8;
                  MlOUEKI(6)  := RlKANWAKOJIN.OUEKI_9;
                  MlOUEKI(7)  := RlKANWAKOJIN.OUEKI_10;
                  MlOUEKI(8)  := RlKANWAKOJIN.OUEKI_11;
                  MlOUEKI(9)  := RlKANWAKOJIN.OUEKI_12;
                  MlOUEKI(10) := RlKANWAKOJIN.OUEKI_1;
                  MlOUEKI(11) := RlKANWAKOJIN.OUEKI_2;
                  MlOUEKI(12) := RlKANWAKOJIN.OUEKI_3;

                  -- 計算緩和個人の各月応能係数を退避
                  MlOUNOU(1)  := RlKANWAKOJIN.OUNOU_4;
                  MlOUNOU(2)  := RlKANWAKOJIN.OUNOU_5;
                  MlOUNOU(3)  := RlKANWAKOJIN.OUNOU_6;
                  MlOUNOU(4)  := RlKANWAKOJIN.OUNOU_7;
                  MlOUNOU(5)  := RlKANWAKOJIN.OUNOU_8;
                  MlOUNOU(6)  := RlKANWAKOJIN.OUNOU_9;
                  MlOUNOU(7)  := RlKANWAKOJIN.OUNOU_10;
                  MlOUNOU(8)  := RlKANWAKOJIN.OUNOU_11;
                  MlOUNOU(9)  := RlKANWAKOJIN.OUNOU_12;
                  MlOUNOU(10) := RlKANWAKOJIN.OUNOU_1;
                  MlOUNOU(11) := RlKANWAKOJIN.OUNOU_2;
                  MlOUNOU(12) := RlKANWAKOJIN.OUNOU_3;
                EXCEPTION
                  WHEN OTHERS THEN
                    MlOUEKI(1) := 100;
                    MlOUEKI(2) := 100;
                    MlOUEKI(3) := 100;
                    MlOUEKI(4) := 100;
                    MlOUEKI(5) := 100;
                    MlOUEKI(6) := 100;
                    MlOUEKI(7) := 100;
                    MlOUEKI(8) := 100;
                    MlOUEKI(9) := 100;
                    MlOUEKI(10):= 100;
                    MlOUEKI(11):= 100;
                    MlOUEKI(12):= 100;
                    MlOUNOU(1) := 100;
                    MlOUNOU(2) := 100;
                    MlOUNOU(3) := 100;
                    MlOUNOU(4) := 100;
                    MlOUNOU(5) := 100;
                    MlOUNOU(6) := 100;
                    MlOUNOU(7) := 100;
                    MlOUNOU(8) := 100;
                    MlOUNOU(9) := 100;
                    MlOUNOU(10):= 100;
                    MlOUNOU(11):= 100;
                    MlOUNOU(12):= 100;
                END;



            IF NLOOP_CNT_NOW = 2 THEN

                FOR NwIX IN 1..12 LOOP
                    -- クリア
                    MwGENMENKOJIN(NwIX) := 0;
                END LOOP;

                IF NGENMEN_KOJIN_KBN = 1 THEN
                    -- 各月の減免有無をセット
                    MwGENMENKOJIN(1)  := NVL(RwGENMENKOJIN.K_GENMEN_4,0);
                    MwGENMENKOJIN(2)  := NVL(RwGENMENKOJIN.K_GENMEN_5,0);
                    MwGENMENKOJIN(3)  := NVL(RwGENMENKOJIN.K_GENMEN_6,0);
                    MwGENMENKOJIN(4)  := NVL(RwGENMENKOJIN.K_GENMEN_7,0);
                    MwGENMENKOJIN(5)  := NVL(RwGENMENKOJIN.K_GENMEN_8,0);
                    MwGENMENKOJIN(6)  := NVL(RwGENMENKOJIN.K_GENMEN_9,0);
                    MwGENMENKOJIN(7)  := NVL(RwGENMENKOJIN.K_GENMEN_10,0);
                    MwGENMENKOJIN(8)  := NVL(RwGENMENKOJIN.K_GENMEN_11,0);
                    MwGENMENKOJIN(9)  := NVL(RwGENMENKOJIN.K_GENMEN_12,0);
                    MwGENMENKOJIN(10) := NVL(RwGENMENKOJIN.K_GENMEN_1,0);
                    MwGENMENKOJIN(11) := NVL(RwGENMENKOJIN.K_GENMEN_2,0);
                    MwGENMENKOJIN(12) := NVL(RwGENMENKOJIN.K_GENMEN_3,0);
                END IF;

            END IF;


                FOR NwIX IN 1..12 LOOP
                    IF i_RKOJIN.SEKISAN_GAI_KBN = 1 THEN
                        -- 資産割額と均等額を加算
                        MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX)
                                              + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 * MlOUNOU(NwIX) / 100)
                                              + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                        IF NSHOTOKU_2DANKAI = 1 THEN-- 所得2段階の所得は月割税額セットで設定する
                          IF MlOUNOU(NwIX) = 100 THEN
                            IF MlSHITSU_KBN(NwIX) > 0 THEN
                              MlKAHYO_SEKI(NwIX) := MlKAHYO_SEKI(NwIX) + i_RKOJIN.SHITSU_KAHYO;
                            ELSE
                            MlKAHYO_SEKI(NwIX)   := MlKAHYO_SEKI(NwIX) + i_RKOJIN.KAHYO;
                            END IF;
                          END IF;
                        ELSE
                          -- 所得割を加算
                          IF MlSHITSU_KBN(NwIX) > 0 THEN
                            MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX)
                                                  + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                          ELSE
                          MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX)
                                                + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                          END IF;
                          --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
                          MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX) - i_RKOJIN.SAN_KAI_GEN_SHOTOKU;
                        END IF;
                    END IF;
                    IF MlSHIK_KBN(NwIX) = 1 THEN
                        MlCNT(NwIX)     := MlCNT(NwIX) + 1;
--                          -- 予め計算した割額を加算
--                          -- 所得2段階の所得は月割税額セット(退職)で設定する
--                            -- 予め計算した割額を加算
--                        --均等割算出前準備
--                        --積算時と同様に世帯員全員で一括算出させる為
--                        --応益係数=100%・90%・70%・50%のそれぞれの該当件数を算出
--                          -- 資産割のみ加算
--                          -- 所得2段階の所得は月割税額セットで設定する
--                          -- 所得割と資産割を加算
                        -- 資産割額と均等額を加算
                    IF NLOOP_CNT_NOW = 1 THEN
                      MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 * MlOUNOU(NwIX) / 100)
                                         + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                      -- 個人別の資産割額
                      NwKOJINSISANZEI  := NwKOJINSISANZEI  + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 * MlOUNOU(NwIX) / 100);
                      -- 個人別の均等割額
                      NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                      --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                      IF MlSAN_KBN(NwIX) > 0 AND MlCNT(NwIX) >= MlSANCNT(NwIX) THEN
                        IF MlOUNOU(NwIX) = 100 THEN
                          MlSANCNT(NwIX)    := MlSANCNT(NwIX) + 1;
                        ELSE
                          MlSANCNT_K(NwIX)  := MlSANCNT_K(NwIX) + 1;
                        END IF;
                      END IF;
                      --  2024/05/06 ZCZL.ZHANGLEI ADD END
                    ELSE
                      MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 - i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SISANZEI_RITSU,0) / 100);
                      -- 個人別の資産割額
                      NwKOJINSISANZEI  := NwKOJINSISANZEI  + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 - i_RKOJIN.SHISANZEI * NSHISAN_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SISANZEI_RITSU,0) / 100);
                      --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                      -- 個人医療産前産後均等割軽減額
                      IF MlSAN_KBN(NwIX) > 0 AND MlCNT(NwIX) >= MlSANCNT(NwIX) THEN
                        MlSANCNT(NwIX)    := MlSANCNT(NwIX) + 1;
                        IF NGENMEN_KOJIN_KBN = 0 THEN
                          NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                        ELSE
                          IF    MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割の場合
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)+ TRUNC((NlJKINTO - NlJKGEN1) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0)/ 100);
                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN1) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN       -- 軽減4割の場合
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)+ TRUNC((NlJKINTO - NlJKGEN2) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0)/ 100);
                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN2) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN       -- 軽減2割の場合
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)+ TRUNC((NlJKINTO - NlJKGEN3) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0)/ 100);
                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN3) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          ELSE
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)+ TRUNC(NlJKINTO * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0)/ 100);
                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN + TRUNC(NlJKINTO - NlJKINTO * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          END IF;
                        END IF;
                      END IF;
                      --  2024/05/06 ZCZL.ZHANGLEI ADD END
                      -- 個人別の均等割額
                      IF NGENMEN_KOJIN_KBN = 0 THEN
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                        NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                      ELSE
                        IF    MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割の場合
                          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN1) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN1) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN       -- 軽減4割の場合
                          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN2) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN2) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN       -- 軽減2割の場合
                          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN3) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN3) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                        ELSE
                          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO - NlJKINTO * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                          NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO - NlJKINTO * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_KINTOWARI_RITSU,0) / 100);
                        END IF;
                      END IF;
                    END IF;
                        IF NSHOTOKU_2DANKAI = 1 THEN-- 所得2段階の所得は月割税額セットで設定する
                          IF MlOUNOU(NwIX) = 100 THEN
                            IF MlSHITSU_KBN(NwIX) > 0 THEN
                              MlKAHYO(NwIX) := MlKAHYO(NwIX) + i_RKOJIN.SHITSU_KAHYO;
                            ELSE
                            MlKAHYO(NwIX)   := MlKAHYO(NwIX) + i_RKOJIN.KAHYO;
                            END IF;
                          END IF;
                        ELSE
                          -- 所得割を加算
                      IF NLOOP_CNT_NOW = 1 THEN
                       --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
                       IF MlSAN_KBN(NwIX) = 0 THEN
                        IF MlSHITSU_KBN(NwIX) > 0 THEN
                          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                           + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                          -- 個人別の所得割額
                          NwKOJINSHOTOKU  := NwKOJINSHOTOKU + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                        ELSE
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                        -- 個人別の所得割額
                        NwKOJINSHOTOKU  := NwKOJINSHOTOKU + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 * MlOUNOU(NwIX) / 100);
                        END IF;
                       --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
                       END IF;
                      ELSE
                       --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
                       IF MlSAN_KBN(NwIX) = 0 THEN
                        IF MlSHITSU_KBN(NwIX) > 0 THEN
                          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                           + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 - i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SHOTOKU_RITSU,0) / 100);
                          -- 個人別の所得割額
                          NwKOJINSHOTOKU  := NwKOJINSHOTOKU + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 - i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SHOTOKU_RITSU,0) / 100);
                        ELSE
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 - i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SHOTOKU_RITSU,0) / 100);
                        -- 個人別の所得割額
                        NwKOJINSHOTOKU  := NwKOJINSHOTOKU + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 - i_RKOJIN.KAHYO * NSHOTOKU_KAI / 100 * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.K_SHOTOKU_RITSU,0) / 100);
                        END IF;
                       --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
                       END IF;
                        -- 個人別の資格月数
                        NwKOJINSHIKAKU_TUKISU_K := NwKOJINSHIKAKU_TUKISU_K + 1;
                      END IF;
                        END IF;
                    END IF;
                END LOOP;
          --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
          -- 計算拡張の産前産後所得割軽減額計に格納する値を更新
          IF NLOOP_CNT_NOW = 1 THEN
           RlEXT.SAN_KAI_GEN_S_KEI := RlEXT.SAN_KAI_GEN_S_KEI + i_RKOJIN.SAN_KAI_GEN_SHOTOKU;
          END IF;
          --  2024/05/06 ZCZL.ZHANGLEI ADD END
          IF NGENMEN_KOJIN_KBN = 1 THEN
              IF NLOOP_CNT_NOW = 1 THEN
                  -- 減免個人データを作成 insert ZLBTGENMEN_KOJIN_TMP → ZLBTGENMEN_KOJIN_CAL
                  -- 医療で既に insert しているので不要

                  vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                  vSQL := vSQL || ' SET K_SHOTOKU_KISO   = :SHOTOKU,';
                  vSQL := vSQL ||      'K_SISANZEI_KISO  = :SISANZEI,';
                  vSQL := vSQL ||      'K_KINTOWARI_KISO = :KINTOWARI';
                  vSQL := vSQL || ' WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO';
                  vSQL := vSQL || ' AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD';
                  vSQL := vSQL || ' AND   KOJIN_NO        = :KOJIN_NO';
                  vSQL := vSQL || ' AND   NENDO_BUN       = :NENDO_BUN';
                  vSQL := vSQL || ' AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO';
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    vSQL := vSQL || '  AND ((YUSEN_KBN > 0 AND TSUCHI_NO = :TSUCHI_NO )';
                    vSQL := vSQL || '        OR (YUSEN_KBN = 0 AND NVL(TSUCHI_NO,0) != 0))';
                  ELSE
                    vSQL := vSQL || '  AND :TSUCHI_NO IS NOT NULL';
                  END IF;

                  EXECUTE IMMEDIATE vSQL USING IN TRUNC(NwKOJINSHOTOKU / 12), TRUNC(NwKOJINSISANZEI / 12), TRUNC(NwKOJINKINTOWARI / 12),
                                                  RwGENMENKOJIN.KOKU_SETAI_NO,
                                                  RwGENMENKOJIN.SANTEIDANTAI_CD,
                                                  RwGENMENKOJIN.KOJIN_NO,
                                                  RwGENMENKOJIN.NENDO_BUN,
                                                  RwGENMENKOJIN.SYS_TANMATSU_NO,
                                                  RwGENMENKOJIN.TSUCHI_NO;
              ELSE
                  vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                  vSQL := vSQL || ' SET K_SHOTOKU_GENGAKU   = K_SHOTOKU_KISO   - :1,';
                  vSQL := vSQL ||      'K_SISANZEI_GENGAKU  = K_SISANZEI_KISO  - :2,';
                  vSQL := vSQL ||      'K_KINTOWARI_GENGAKU = K_KINTOWARI_KISO - :3';
                  vSQL := vSQL || ' WHERE KOKU_SETAI_NO   = :4';
                  vSQL := vSQL || ' AND   SANTEIDANTAI_CD = :5';
                  vSQL := vSQL || ' AND   KOJIN_NO        = :6';
                  vSQL := vSQL || ' AND   NENDO_BUN       = :7';
                  vSQL := vSQL || ' AND   SYS_TANMATSU_NO = :8';
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    vSQL := vSQL || '  AND ((YUSEN_KBN > 0 AND TSUCHI_NO = :9 )';
                    vSQL := vSQL || '        OR (YUSEN_KBN = 0 AND NVL(TSUCHI_NO,0) != 0))';
                  ELSE
                    vSQL := vSQL || '  AND :9 IS NOT NULL';
                  END IF;

                  EXECUTE IMMEDIATE vSQL USING IN TRUNC(NwKOJINSHOTOKU   / 12),
                                                  TRUNC(NwKOJINSISANZEI  / 12),
                                                  TRUNC(NwKOJINKINTOWARI / 12),
                                                  RwGENMENKOJIN.KOKU_SETAI_NO,
                                                  RwGENMENKOJIN.SANTEIDANTAI_CD,
                                                  RwGENMENKOJIN.KOJIN_NO,
                                                  RwGENMENKOJIN.NENDO_BUN,
                                                  RwGENMENKOJIN.SYS_TANMATSU_NO,
                                                  RwGENMENKOJIN.TSUCHI_NO;

                  vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                  vSQL := vSQL || ' SET K_GENGAKU_KEI     = K_SHOTOKU_GENGAKU + K_SISANZEI_GENGAKU + K_KINTOWARI_GENGAKU + K_BYODOWARI_GENGAKU,';
                  vSQL := vSQL ||      'SHIKAKU_TUKISU_K  = :1';
                  vSQL := vSQL || ' WHERE KOKU_SETAI_NO   = :2';
                  vSQL := vSQL || ' AND   SANTEIDANTAI_CD = :3';
                  vSQL := vSQL || ' AND   KOJIN_NO        = :4';
                  vSQL := vSQL || ' AND   NENDO_BUN       = :5';
                  vSQL := vSQL || ' AND   SYS_TANMATSU_NO = :6';
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    vSQL := vSQL || '  AND ((YUSEN_KBN > 0 AND TSUCHI_NO = :7 )';
                    vSQL := vSQL || '        OR (YUSEN_KBN = 0 AND NVL(TSUCHI_NO,0) != 0))';
                  ELSE
                    vSQL := vSQL || '  AND :7 IS NOT NULL';
                  END IF;

                  EXECUTE IMMEDIATE vSQL USING IN NwKOJINSHIKAKU_TUKISU_K,
                                                  RwGENMENKOJIN.KOKU_SETAI_NO,
                                                  RwGENMENKOJIN.SANTEIDANTAI_CD,
                                                  RwGENMENKOJIN.KOJIN_NO,
                                                  RwGENMENKOJIN.NENDO_BUN,
                                                  RwGENMENKOJIN.SYS_TANMATSU_NO,
                                                  RwGENMENKOJIN.TSUCHI_NO;
              END IF;
          END IF;

            END IF;

        END IF;

        RlKIHON.KEIGEN_K_WARI := 0;
        RlKIHON.KEIGEN_B_WARI := 0;

    END subTukiwariMae;
-------------------------------------------------------------------------------
-- 15 欠番
-- 14 欠番
-- 13 欠番
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- 12 計算基本・計算退職登録
-------------------------------------------------------------------------------
    PROCEDURE subInsert IS
    BEGIN

        -- 計算介護基本登録
        BEGIN
            INSERT INTO ZLBTKAI_KIHON_CAL VALUES RlKIHON;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subInsert 計算介護基本登録(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
        END;

        -- 計算介護退職の登録(賦課試算時は登録しない)
        IF NlRTN = c_NOK AND i_NJIKKOU_KBN != c_NTEST THEN
            BEGIN
                INSERT INTO ZLBTKAI_TAI_CAL VALUES RlTAI;
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subInsert 計算介護退職登録(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        -- 計算拡張の登録
        IF NlRTN = c_NOK  THEN
            BEGIN
                UPDATE ZLBTEXT_CAL SET KAI_NENREI_KEIGEN   = RlEXT.KAI_NENREI_KEIGEN,    --介護年齢軽減
                                       KAI_SHOGAI_GENMEN   = RlEXT.KAI_SHOGAI_GENMEN,    --介護障害減免
                                       KAI_NENREI_KEIGEN_T = RlEXT.KAI_NENREI_KEIGEN_T,  --介護年齢軽減(退職)
                                       KAI_SHOGAI_GENMEN_T = RlEXT.KAI_SHOGAI_GENMEN_T,  --介護障害減免(退職)
                                       KAI_KEIKA_H_SHOTOKU     = RlEXT.KAI_KEIKA_H_SHOTOKU,    -- 介護所得割積算軽減額(被扶養者)
                                       KAI_KEIKA_H_SHOTOKU_T   = RlEXT.KAI_KEIKA_H_SHOTOKU_T,  -- 介護所得割積算軽減額(被扶養者)(退職)
                                       KAI_KEIKA_H_SHISAN      = RlEXT.KAI_KEIKA_H_SHISAN,     -- 介護資産割積算軽減額(被扶養者)
                                       KAI_KEIKA_H_SHISAN_T    = RlEXT.KAI_KEIKA_H_SHISAN_T,   -- 介護資産割積算軽減額(被扶養者)(退職)
                                       KAI_KEIKA_H_KINTOWARI   = RlEXT.KAI_KEIKA_H_KINTOWARI,  -- 介護均等割積算軽減額(被扶養者)
                                       KAI_KEIKA_H_KINTOWARI_T = RlEXT.KAI_KEIKA_H_KINTOWARI_T,-- 介護均等割積算軽減額(被扶養者)(退職)
--                                       KAI_KEIKA_H_BYODOWARI   = RlEXT.KAI_KEIKA_H_BYODOWARI,  -- 介護平等割積算軽減額(被扶養者)
--                                       KAI_KEIKA_H_BYODOWARI_T = RlEXT.KAI_KEIKA_H_BYODOWARI_T -- 介護平等割積算軽減額(被扶養者)(退職)
                                       KAI_KEIKA_BYODOWARI     = RlEXT.KAI_KEIKA_BYODOWARI,  -- 介護平等割積算軽減額(被扶養者)
                                       KAI_KEIKA_BYODOWARI_T   = RlEXT.KAI_KEIKA_BYODOWARI_T -- 介護平等割積算軽減額(被扶養者)(退職)
                                       --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                                       , SAN_KAI_GEN_K_KEI   = RlEXT.SAN_KAI_GEN_K_KEI -- 介護産前産後均等割軽減額計
                                       , SAN_KAI_GEN_S_KEI   = RlEXT.SAN_KAI_GEN_S_KEI -- 介護産前産後所得割軽減額計
                                       --  2024/05/06 ZCZL.ZHANGLEI ADD END
                                   WHERE
                                       KOKU_SETAI_NO   = RlEXT.KOKU_SETAI_NO AND
                                       SANTEIDANTAI_CD = RlEXT.SANTEIDANTAI_CD AND
                                       CHOTEI_NENDO    = RlEXT.CHOTEI_NENDO AND
                                       NENDO_BUN       = RlEXT.NENDO_BUN AND
                                       TSUCHI_NO       = RlEXT.TSUCHI_NO AND
                                       SYS_TANMATSU_NO = RlEXT.SYS_TANMATSU_NO;
            EXCEPTION
                WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subInsert 計算拡張更新(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
            END;
        END IF;

    END subInsert;
-------------------------------------------------------------------------------
-- -- 減免個人データ  整合性チェック＆ダミーデータ作成
-------------------------------------------------------------------------------
    PROCEDURE subGenmenKojinDummyInsert IS
        nCNT      NUMBER;
        nCNT_N    NUMBER;
        nCNT_CAL  NUMBER;
    BEGIN

        -- ZLBTGENMEN_KOJIN テーブルの存在チェック
        nCNT := 1;

        IF nCNT = 1 THEN

            OPEN cur_DynamicSQL FOR 'SELECT count(*)
                                     FROM ZLBTGENMEN_KOJIN_CAL
                                     WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                     AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                     AND   NENDO_BUN       = :NENDO_BUN
                                     AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO'
                                USING i_NSETAI, i_NDANTAI, i_NNENDO_BUN, i_VTANMATSU;

            FETCH cur_DynamicSQL INTO nCNT_CAL;
            CLOSE cur_DynamicSQL;

            IF nCNT_CAL = 0 THEN

                OPEN cur_DynamicSQL FOR 'SELECT count(*)
                                         FROM ZLBTGENMEN_KOJIN_N
                                         WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                         AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                         AND   NENDO_BUN       = :NENDO_BUN
                                         AND   KOJIN_NO       <> 0'
                                    USING i_NSETAI, i_NDANTAI, i_NNENDO_BUN;

                FETCH cur_DynamicSQL INTO nCNT_N;
                CLOSE cur_DynamicSQL;

                IF nCNT_N > 0 THEN

                    vSQL := 'INSERT INTO ZLBTGENMEN_KOJIN_CAL VALUES(:1, :2, 0, 0, :3, '                       || -- KOKU_SETAI_NO～NENDO_BUN
                                    '0,0,0,0,0,0,0,0,'                                                         || -- R_NO～TEKIYO_KBN                    ８個
                                    '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'             || -- I_SHOTOKU_KISO～ST_NENZEI_KISO    ３０個
                                    '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'                                           || -- I_SHOTOKU_RITSU～S_NENZEI_RITSU   １５個
                                    '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,' || -- I_SHOTOKU_GENGAKU～ST_GENGAKU_KEI ３６個
                                    '0,0,0,0,0,0,0,0,0,0,0,0,'                                                 || -- I_GENMEN_4～I_GENMEN_3            １２個
                                    '0,0,0,0,0,0,0,0,0,0,0,0,'                                                 || -- K_GENMEN_4～K_GENMEN_3            １２個
                                    '0,0,0,0,0,0,0,0,0,0,0,0,'                                                 || -- S_GENMEN_4～S_GENMEN_3            １２個
                                    '0,0,0,0,0,'                                                               || -- SHIKAKU_TUKISU～SAKUJO_KBN          ５個
                                    '0,0,0,0,0,0,0,0,0,0,0,0,'                                                 || -- I_GENGAKU_MAE～ST_GENGAKU         １２個
                                    '0,0,0,0,'                                                                 || -- SYS_SAKUSEIBI～SYS_SHOKUINKOJIN_NO  ４個  -- ZLBSKCALPACK でセットされる
--2025/08/11 ZCZL.WANGMING UPDATE START 1.1.200.000:子ども子育て支援金対応
--                                    ':4)';                                                                        -- SYS_TANMATSU_NO
                                    ':4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)';        -- SYS_TANMATSU_NO～KDM_GENGAKU     ３４個
--2025/08/11 ZCZL.WANGMING UPDATE START 1.1.200.000:子ども子育て支援金対応

                    EXECUTE IMMEDIATE vSQL USING IN i_NSETAI,
                                                    i_NDANTAI,
                                                    i_NNENDO_BUN,
                                                    i_VTANMATSU;

                END IF;

            END IF;

        END IF;

    EXCEPTION
        WHEN OTHERS THEN
          IF cur_DynamicSQL%ISOPEN THEN
             CLOSE cur_DynamicSQL;
          END IF;
            NlRTN := c_NERR;
            VlMSG := '減免個人 ダミーデータ作成(国保世帯番号='||i_NSETAI||')'||SQLERRM;

    END subGenmenKojinDummyInsert;
-------------------------------------------------------------------------------
-- 11 計算個人0件時セット
-------------------------------------------------------------------------------
    PROCEDURE subOutInit IS
    BEGIN

        -- 計算基本クリア
        RlKIHON.KOKU_SETAI_NO       := i_NSETAI;
        RlKIHON.SANTEIDANTAI_CD     := i_NDANTAI;
        RlKIHON.CHOTEI_NENDO        := i_NNENDO;
        RlKIHON.NENDO_BUN           := i_NNENDO_BUN;
        RlKIHON.R_NO                := 0;
        RlKIHON.TSUCHI_NO           := i_NNUSHI;            -- 世帯主を仮にセット
        RlKIHON.NUSHI_KOJIN_NO      := i_NNUSHI;
        RlKIHON.IDO_JIYU            := 0;
        RlKIHON.KOSEI_BI            := 0;
        RlKIHON.KOSHIN_KBN          := 1;                   -- 更新区分(ﾊﾞｯﾁ処理)
        RlKIHON.SHINKOKU_KBN        := 0;
        RlKIHON.SHU_SHOTOKU_KBN     := 0;
        RlKIHON.GENZON_KBN          := 0;
        RlKIHON.SETAI_KBN           := 0;
        RlKIHON.GISEI_KBN           := 0;
        RlKIHON.J_KAZEI_KBN         := 0;
        RlKIHON.JOTO_S_KBN          := 0;
        RlKIHON.ROJIN_S_KBN         := 0;
        RlKIHON.SENJU_S_KBN         := 0;
        RlKIHON.KEIGEN_SHINSEI_KBN  := 0;
        RlKIHON.KEIGEN_SHOTOKU      := 0;
        RlKIHON.FUKA_KIJITSU_CNT    := 0;
        RlKIHON.KINTO_CNT           := 0;
        RlKIHON.GENZAI_CNT          := 0;
        RlKIHON.YU_SHOTOKU_CNT      := 0;
        RlKIHON.SHOTOKU             := 0;
        RlKIHON.KAHYO               := 0;
        RlKIHON.SHOTOKU_WARI        := 0;
        RlKIHON.SHISANZEI           := 0;
        RlKIHON.SHISAN_WARI         := 0;
        RlKIHON.KINTO_WARI          := 0;
        RlKIHON.BYODO_WARI          := 0;
        RlKIHON.SEKISAN             := 0;
        RlKIHON.GENDO_CHOKA         := 0;
        RlKIHON.KEIGEN_K_WARI       := 0;
        RlKIHON.KEIGEN_B_WARI       := 0;
        RlKIHON.KEIGEN_K_6          := 0;
        RlKIHON.KEIGEN_B_6          := 0;
        RlKIHON.KEIGEN_K_4          := 0;
        RlKIHON.KEIGEN_B_4          := 0;
        RlKIHON.KEIGEN_K_2          := 0;
        RlKIHON.KEIGEN_B_2          := 0;
        RlKIHON.TSUKIWARI_GEN       := 0;
        RlKIHON.HASU                := 0;
        RlKIHON.GENGAKU_KEI         := 0;
        RlKIHON.GENMEN              := 0;
        RlKIHON.KANENDO             := 0;
        RlKIHON.NENZEI              := 0;
        RlKIHON.KEIGEN_4            := 0;
        RlKIHON.KEIGEN_5            := 0;
        RlKIHON.KEIGEN_6            := 0;
        RlKIHON.KEIGEN_7            := 0;
        RlKIHON.KEIGEN_8            := 0;
        RlKIHON.KEIGEN_9            := 0;
        RlKIHON.KEIGEN_10           := 0;
        RlKIHON.KEIGEN_11           := 0;
        RlKIHON.KEIGEN_12           := 0;
        RlKIHON.KEIGEN_1            := 0;
        RlKIHON.KEIGEN_2            := 0;
        RlKIHON.KEIGEN_3            := 0;
        RlKIHON.SYS_SAKUSEIBI       := 0;
        RlKIHON.SYS_KOSHINBI        := 0;
        RlKIHON.SYS_JIKAN           := 0;
        RlKIHON.SYS_SHOKUINKOJIN_NO := NULL;
        RlKIHON.SYS_TANMATSU_NO     := i_VTANMATSU;

        -- 計算退職クリア
        RlTAI.KOKU_SETAI_NO         := i_NSETAI;
        RlTAI.SANTEIDANTAI_CD       := i_NDANTAI;
        RlTAI.CHOTEI_NENDO          := i_NNENDO;
        RlTAI.NENDO_BUN             := i_NNENDO_BUN;
        RlTAI.R_NO                  := 0;
        RlTAI.TSUCHI_NO             := i_NNUSHI;            -- 世帯主を仮にセット
        RlTAI.KEIGEN_SHOTOKU        := 0;
        RlTAI.FUKA_KIJITSU_CNT      := 0;
        RlTAI.KINTO_CNT             := 0;
        RlTAI.GENZAI_CNT            := 0;
        RlTAI.YU_SHOTOKU_CNT        := 0;
        RlTAI.SHOTOKU               := 0;
        RlTAI.KAHYO                 := 0;
        RlTAI.SHOTOKU_WARI          := 0;
        RlTAI.SHISANZEI             := 0;
        RlTAI.SHISAN_WARI           := 0;
        RlTAI.KINTO_WARI            := 0;
        RlTAI.BYODO_WARI            := 0;
        RlTAI.SEKISAN               := 0;
        RlTAI.GENDO_CHOKA           := 0;
        RlTAI.KEIGEN_K_WARI         := 0;
        RlTAI.KEIGEN_B_WARI         := 0;
        RlTAI.KEIGEN_K_6            := 0;
        RlTAI.KEIGEN_B_6            := 0;
        RlTAI.KEIGEN_K_4            := 0;
        RlTAI.KEIGEN_B_4            := 0;
        RlTAI.KEIGEN_K_2            := 0;
        RlTAI.KEIGEN_B_2            := 0;
        RlTAI.TSUKIWARI_GEN         := 0;
        RlTAI.HASU                  := 0;
        RlTAI.GENGAKU_KEI           := 0;
        RlTAI.GENMEN                := 0;
        RlTAI.KANENDO               := 0;
        RlTAI.NENZEI                := 0;
        RlTAI.SYS_SAKUSEIBI         := 0;
        RlTAI.SYS_KOSHINBI          := 0;
        RlTAI.SYS_JIKAN             := 0;
        RlTAI.SYS_SHOKUINKOJIN_NO   := '0';
        RlTAI.SYS_TANMATSU_NO       := i_VTANMATSU;

        -- ZLBSKCALMAINでセットしているZLBTEXT_CALの情報を取得
        BEGIN
            SELECT * INTO RlEXT FROM ZLBTEXT_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NNUSHI
               AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subOutInit 計算拡張取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
        END;

        RlEXT.KAI_KEIKA_H_SHOTOKU        := 0;
        RlEXT.KAI_KEIKA_H_SHOTOKU_T      := 0;
        RlEXT.KAI_KEIKA_H_SHISAN         := 0;
        RlEXT.KAI_KEIKA_H_SHISAN_T       := 0;
        RlEXT.KAI_KEIKA_H_KINTOWARI      := 0;
        RlEXT.KAI_KEIKA_H_KINTOWARI_T    := 0;
        RlEXT.KAI_KEIKA_BYODOWARI      := 0;
        RlEXT.KAI_KEIKA_BYODOWARI_T    := 0;
        --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
        RlEXT.SAN_KAI_GEN_K_KEI        := 0;
        RlEXT.SAN_KAI_GEN_S_KEI        := 0;
        --  2024/05/06 ZCZL.ZHANGLEI ADD END
    END subOutInit;
-------------------------------------------------------------------------------
-- 10 税額確定処理（退職）
-------------------------------------------------------------------------------
    PROCEDURE subKakutei_Tai IS
        NwWORK          NUMBER;
    BEGIN

        IF NlJHASU = c_NHASU_KBN_2 THEN
            NwWORK := c_NHASU_2;
        ELSIF NlJHASU = c_NHASU_KBN_1 THEN
            NwWORK := c_NHASU_1;
        ELSIF NlJHASU = c_NHASU_KBN_3 THEN
            NwWORK := c_NHASU_3;
        ELSIF NlJHASU = c_NHASU_KBN_10 THEN
            NwWORK := c_NHASU_10;
        END IF;

        IF RlTAI.KINTO_CNT > 0 THEN

            -- 月割りで算出した年税額は、年齢軽減分がマイナスされていないのでここで減算
            NlTAINENZEIGAKU := NlTAINENZEIGAKU -  RlEXT.KAI_NENREI_KEIGEN_T;
            -- 月割りで算出した年税額は、身障減免額分がマイナスされていないのでここで減算
            NlTAINENZEIGAKU := NlTAINENZEIGAKU -  RlEXT.KAI_SHOGAI_GENMEN_T;


          IF ISHICHOSON_CD = c_KAMIINA_INA AND N_INA_GENMEN = 1 THEN
            IF NlTAINENZEIGAKU  > 0 THEN
              IF NlJHASU = c_NHASU_KBN_2 THEN
                RlTAI.HASU := MOD(NlTAINENZEIGAKU , c_NHASU_2);   -- 端数
              ELSIF NlJHASU = c_NHASU_KBN_1 THEN
                RlTAI.HASU := MOD(NlTAINENZEIGAKU , c_NHASU_1);
              ELSIF NlJHASU = c_NHASU_KBN_3 THEN
                RlTAI.HASU := MOD(NlTAINENZEIGAKU , c_NHASU_3);
              ELSIF NlJHASU = c_NHASU_KBN_10 THEN
                RlTAI.HASU := MOD(NlTAINENZEIGAKU , c_NHASU_10);
              END IF;
            ELSE
              RlTAI.HASU := 0;
            END IF;
            NlTAINENZEIGAKU := NlTAINENZEIGAKU - RlTAI.HASU;          -- 年税額
          ELSE
            IF (NlNENZEIGAKU - NlTAINENZEIGAKU) < NwWORK THEN
                RlTAI.KEIGEN_SHOTOKU    := RlKIHON.KEIGEN_SHOTOKU;  -- 軽減判定所得
                RlTAI.FUKA_KIJITSU_CNT  := RlKIHON.FUKA_KIJITSU_CNT;    -- 賦課期日人員
                RlTAI.KINTO_CNT         := RlKIHON.KINTO_CNT;       -- 均等人員
                RlTAI.GENZAI_CNT        := RlKIHON.GENZAI_CNT;      -- 現在人員
                RlTAI.YU_SHOTOKU_CNT    := RlKIHON.YU_SHOTOKU_CNT;  -- 有所得人員
                RlTAI.SHOTOKU           := RlKIHON.SHOTOKU;         -- 所得額
                RlTAI.KAHYO             := RlKIHON.KAHYO;           -- 課税標準額
                RlTAI.SHOTOKU_WARI      := RlKIHON.SHOTOKU_WARI;    -- 所得割額
                RlTAI.SHISANZEI         := RlKIHON.SHISANZEI;       -- 資産税額
                RlTAI.SHISAN_WARI       := RlKIHON.SHISAN_WARI;     -- 資産割額
                RlTAI.KINTO_WARI        := RlKIHON.KINTO_WARI;      -- 均等割額
                RlTAI.BYODO_WARI        := RlKIHON.BYODO_WARI;      -- 平等割額
                RlTAI.SEKISAN           := RlKIHON.SEKISAN;         -- 積算税額
                RlTAI.GENDO_CHOKA       := RlKIHON.GENDO_CHOKA;     -- 限度超過額
                RlTAI.KEIGEN_K_WARI     := RlKIHON.KEIGEN_K_WARI;   -- 軽減均等割額
                RlTAI.KEIGEN_B_WARI     := RlKIHON.KEIGEN_B_WARI;   -- 軽減平等割額
                RlTAI.KEIGEN_K_6        := RlKIHON.KEIGEN_K_6;      -- 軽減均等6
                RlTAI.KEIGEN_B_6        := RlKIHON.KEIGEN_B_6;      -- 軽減平等6
                RlTAI.KEIGEN_K_4        := RlKIHON.KEIGEN_K_4;      -- 軽減均等4
                RlTAI.KEIGEN_B_4        := RlKIHON.KEIGEN_B_4;      -- 軽減平等4
                RlTAI.KEIGEN_K_2        := RlKIHON.KEIGEN_K_2;      -- 軽減均等2
                RlTAI.KEIGEN_B_2        := RlKIHON.KEIGEN_B_2;      -- 軽減平等2
                RlTAI.TSUKIWARI_GEN     := RlKIHON.TSUKIWARI_GEN;   -- 月割減額
                RlTAI.HASU              := RlKIHON.HASU;            -- 端数
                RlTAI.GENGAKU_KEI       := RlKIHON.GENGAKU_KEI;     -- 減額合計
                RlTAI.GENMEN            := RlKIHON.GENMEN;          -- 減免額
                RlTAI.KANENDO           := RlKIHON.KANENDO;         -- 過年度分
                RlTAI.NENZEI            := RlKIHON.NENZEI;          -- 年税額
                RlEXT.KAI_NENREI_KEIGEN_T  := RlEXT.KAI_NENREI_KEIGEN; -- 年齢軽減(介護)
                RlEXT.KAI_SHOGAI_GENMEN_T  := RlEXT.KAI_SHOGAI_GENMEN; -- 障害減免(介護)
            END IF;
          END IF;

            IF ((NlNENZEIGAKU - NlTAINENZEIGAKU) >= NwWORK) OR
               (ISHICHOSON_CD = c_KAMIINA_INA AND N_INA_GENMEN = 1) THEN
                IF NOT (ISHICHOSON_CD = c_KAMIINA_INA AND N_INA_GENMEN = 1) THEN
                  RlTAI.HASU              := 0;                   -- 端数
                END IF;
                RlTAI.NENZEI            := NlTAINENZEIGAKU;     -- 年税額

                subGenmenritsu_TAI;        -- 31 退職減免率(額)を算出（医療・退職）

--                -- 月割りで算出した年税額は、減免額分がマイナスされていないのでここで減算

                --  世帯減免のみの場合
                IF  NGENMEN_EXIST_KBN = 0 AND NGENMEN_USE_SKBN = 1 THEN
                    RlTAI.GENMEN      := CEIL(RlTAI.NENZEI * NGENMEN_USE_SRITSU / 100) ;  -- 世帯減免額の算出(基本)（年税額のXX%減免)
                ELSE
                  IF NLOOP_CNT_NOW = 2 THEN
                    --優先区分が「世帯／率／年額」
                    IF RlGENMEN_KOJIN.YUSEN_KBN = 3 THEN
                      RlTAI.GENMEN        := CEIL(RlTAI.NENZEI * RlGENMEN_KOJIN.K_NENZEI_RITSU / 100); -- 年税減免率（年税額のXX%減免)
                      RlTAI.NENZEI        := RlTAI.NENZEI - RlTAI.GENMEN;
                    --優先区分が「世帯／額／年額」
                    ELSIF RlGENMEN_KOJIN.YUSEN_KBN = 4 THEN
                      RlTAI.GENMEN        := RlGENMEN_KOJIN.KT_NENZEI_GENGAKU;  -- 年税減免額
                      RlTAI.NENZEI        := RlTAI.NENZEI - RlTAI.GENMEN;
                    END IF;
                  END IF;
                END IF;
                -- 月割りで算出した年税額は、減免額分がマイナスされていないのでここで減算
                IF ISHICHOSON_CD <> c_KAMIINA_INA THEN
                  IF NLOOP_CNT_NOW = 2 THEN
                    --優先区分が「世帯／率／年額」、「世帯／額／年額」以外
                    IF RlGENMEN_KOJIN.YUSEN_KBN NOT IN (3, 4) THEN
                      RlTAI.GENMEN := (NwNENZEIGAKU_TAI + NwHASU_TAI) - (RlTAI.NENZEI + RlTAI.HASU);
                    END IF;
                  ELSE
                    IF RlTAI.NENZEI - RlTAI.GENMEN >= 0 THEN
                        RlTAI.NENZEI := RlTAI.NENZEI - RlTAI.GENMEN;
                    ELSE
                        RlTAI.GENMEN := RlTAI.NENZEI;
                        RlTAI.NENZEI := 0;
                    END IF;
                  END IF;
                END IF;

                RlTAI.TSUKIWARI_GEN     := RlTAI.SEKISAN     - RlTAI.GENDO_CHOKA
                                                             - RlTAI.KEIGEN_K_WARI
                                                             - RlTAI.KEIGEN_B_WARI
                                                             - RlTAI.GENMEN   --減免額
                                                             - RlEXT.KAI_NENREI_KEIGEN_T  -- 年齢軽減
                                                             - RlEXT.KAI_SHOGAI_GENMEN_T  -- 身障減免
                                                             - RlTAI.HASU       --端数
                                                             - RlTAI.NENZEI;    -- 月割減額
-- 経過措置対応で\1単位の誤差が月割減額にセットされる。
-- 端数+月割減額<賦課額端数内であれば、誤差を端数にセットする。
                -- 期割端数処理しない条件時の制御
                IF  ITSUKI_HASU_KBN = 1  THEN
                    IF  ABS( RlTAI.TSUKIWARI_GEN + RlTAI.HASU ) < 10  THEN
                        RlTAI.NENZEI         :=  RlTAI.NENZEI + RlTAI.TSUKIWARI_GEN ;  -- 年額に寄せる
                        RlTAI.TSUKIWARI_GEN  :=  0 ;
                    END IF ;
                ELSE
                    --誤差調整
                    IF RlTAI.TSUKIWARI_GEN > 0 THEN
                        IF RlTAI.TSUKIWARI_GEN + RlTAI.HASU < NwWORK THEN
                            RlTAI.HASU := RlTAI.HASU + RlTAI.TSUKIWARI_GEN;
                            RlTAI.TSUKIWARI_GEN := 0;
                        END IF;
                    ELSIF RlTAI.TSUKIWARI_GEN < 0 THEN
                        IF RlTAI.HASU + RlTAI.TSUKIWARI_GEN >= 0 THEN
                            RlTAI.HASU := RlTAI.HASU + RlTAI.TSUKIWARI_GEN;
                            RlTAI.TSUKIWARI_GEN := 0;
                        END IF;
                    END IF;
                END IF ;
                RlTAI.GENGAKU_KEI       := RlTAI.GENDO_CHOKA + RlTAI.KEIGEN_K_WARI
                                                             + RlTAI.KEIGEN_B_WARI
                                                             + RlTAI.HASU
                                                             + RlEXT.KAI_NENREI_KEIGEN_T  -- 年齢軽減
                                                             + RlTAI.TSUKIWARI_GEN; -- 減額合計
            END IF;

        END IF;

    END subKakutei_Tai;
-------------------------------------------------------------------------------
-- 09 税額確定処理（基本）
-------------------------------------------------------------------------------
    PROCEDURE subKakutei IS
        NwWORK          NUMBER;
    BEGIN
        --再処理用に月割年税額を保存
        IF NCNT_KAKUTEI = 0 THEN
            NlNENZEIGAKU_WK := NlNENZEIGAKU;
        END IF;

        -- 月割りで算出した年税額は、年齢軽減分がマイナスされていないのでここで減算
        NlNENZEIGAKU := NlNENZEIGAKU -  RlEXT.KAI_NENREI_KEIGEN;
        -- 月割りで算出した年税額は、身障減免額がマイナスされていないのでここで減算
        NlNENZEIGAKU := NlNENZEIGAKU -  RlEXT.KAI_SHOGAI_GENMEN;


        IF NlNENZEIGAKU > 0 THEN
            IF NlJHASU = c_NHASU_KBN_2 THEN
                RlKIHON.HASU := MOD(NlNENZEIGAKU, c_NHASU_2);   -- 端数
            ELSIF NlJHASU = c_NHASU_KBN_1 THEN
                RlKIHON.HASU := MOD(NlNENZEIGAKU, c_NHASU_1);
            ELSIF NlJHASU = c_NHASU_KBN_3 THEN
                RlKIHON.HASU := MOD(NlNENZEIGAKU, c_NHASU_3);
            ELSIF NlJHASU = c_NHASU_KBN_10 THEN
                RlKIHON.HASU := MOD(NlNENZEIGAKU, c_NHASU_10);
            END IF;
        ELSE
            RlKIHON.HASU := 0;
        END IF;

        RlKIHON.NENZEI := NlNENZEIGAKU - RlKIHON.HASU;          -- 年税額

        subGenmenritsu;        -- 30 減免率(額)を算出（医療・退職）

        --  世帯減免のみの場合
        IF  NGENMEN_EXIST_KBN = 0 AND NGENMEN_USE_SKBN = 1 THEN
            RlKIHON.GENMEN      := TRUNC(((NlNENZEIGAKU - RlKIHON.HASU) * NGENMEN_USE_SRITSU / 100), -2) ;  -- 世帯減免額の算出(基本)（年税額のXX%減免)
        ELSE
          IF NLOOP_CNT_NOW = 2 THEN
            --優先区分が「世帯／率／年額」
            IF RlGENMEN_KOJIN.YUSEN_KBN = 3 THEN
              RlKIHON.GENMEN      := CEIL(((NlNENZEIGAKU - RlKIHON.HASU) * RlGENMEN_KOJIN.K_NENZEI_RITSU / 100)); -- 年税減免率（年税額のXX%減免)
              RlKIHON.NENZEI      := RlKIHON.NENZEI - RlKIHON.GENMEN;
            --優先区分が「世帯／額／年額」
            ELSIF RlGENMEN_KOJIN.YUSEN_KBN = 4 THEN
              RlKIHON.GENMEN      := RlGENMEN_KOJIN.K_NENZEI_GENGAKU;  -- 年税減免額
              RlKIHON.NENZEI      := RlKIHON.NENZEI - RlKIHON.GENMEN;
            END IF;
          END IF;
        END IF;
--        -- 月割りで算出した年税額は、減免額分がマイナスされていないのでここで減算

        -- 月割りで算出した年税額は、減免額分がマイナスされていないのでここで減算
        IF ISHICHOSON_CD <> c_KAMIINA_INA THEN
          IF NLOOP_CNT_NOW = 2 THEN
            --優先区分が「世帯／率／年額」、「世帯／額／年額」以外
            IF RlGENMEN_KOJIN.YUSEN_KBN NOT IN (3, 4) THEN
              --  2024/05/06 ZCZL.ZHANGLEI UPDATE 0.3.000.100:国保２次にマージ作業
              --RlKIHON.GENMEN := TRUNC(NwNENZEIGAKU + NwHASU) - (RlKIHON.NENZEI + RlKIHON.HASU);
----2025/07/24 CTC.gaoqq Upd 1.0.501.001:QA10155マージ作業
--              RlKIHON.GENMEN := TRUNC(NwNENZEIGAKU + NwHASU + NwGENDO_CHOKA) - (RlKIHON.NENZEI + RlKIHON.HASU + RlKIHON.GENDO_CHOKA);
              RlKIHON.GENMEN := (NwNENZEIGAKU + NwHASU + NwGENDO_CHOKA) - (RlKIHON.NENZEI + RlKIHON.HASU + RlKIHON.GENDO_CHOKA);
            END IF;
          ELSE
            IF RlKIHON.NENZEI - RlKIHON.GENMEN >= 0 THEN
                RlKIHON.NENZEI := RlKIHON.NENZEI - RlKIHON.GENMEN;
            ELSE
                RlKIHON.GENMEN := RlKIHON.NENZEI;
                RlKIHON.NENZEI := 0;
            END IF;
          END IF;
        END IF;



        RlKIHON.TSUKIWARI_GEN := RlKIHON.SEKISAN - RlKIHON.GENDO_CHOKA
                                                 - RlKIHON.KEIGEN_K_WARI
                                                 - RlKIHON.KEIGEN_B_WARI
                                                 - RlKIHON.HASU
                                                 - RlKIHON.GENMEN   --減免額
                                                 - RlEXT.KAI_NENREI_KEIGEN  -- 年齢軽減
                                                 - RlEXT.KAI_SHOGAI_GENMEN  -- 身障減免
                                                 - RlKIHON.NENZEI;  -- 月割減額
-- 経過措置対応で\1単位の誤差が月割減額にセットされる。
-- 端数+月割減額<賦課額端数内であれば、誤差を端数にセットする。
        --賦課額端数取得
        IF NlJHASU = c_NHASU_KBN_2 THEN
            NwWORK := c_NHASU_2;
        ELSIF NlJHASU = c_NHASU_KBN_1 THEN
            NwWORK := c_NHASU_1;
        ELSIF NlJHASU = c_NHASU_KBN_3 THEN
            NwWORK := c_NHASU_3;
        ELSIF NlJHASU = c_NHASU_KBN_10 THEN
            NwWORK := c_NHASU_10;
        END IF;
        --誤差調整
        IF RlKIHON.TSUKIWARI_GEN > 0 THEN
            IF RlKIHON.TSUKIWARI_GEN + RlKIHON.HASU < NwWORK THEN
                RlKIHON.HASU := RlKIHON.HASU + RlKIHON.TSUKIWARI_GEN;
                RlKIHON.TSUKIWARI_GEN := 0;
            END IF;
        ELSIF RlKIHON.TSUKIWARI_GEN < 0 THEN
            IF RlKIHON.HASU + RlKIHON.TSUKIWARI_GEN >= 0 THEN
                RlKIHON.HASU := RlKIHON.HASU + RlKIHON.TSUKIWARI_GEN;
                RlKIHON.TSUKIWARI_GEN := 0;
            --旧被扶養者減免等の根拠減免計算において、月割減額にマイナスが発生する不具合対応
            --減額が10未満(誤差範囲超の防止)でマイナス調整年度以降の場合
            ELSIF RlKIHON.NENDO_BUN >= NGENMINUS_NENDO  AND ABS(RlKIHON.TSUKIWARI_GEN) < 10 THEN
                 IF NCNT_KAKUTEI = 0 THEN      --初回のみ
                  --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                  IF RlKIHON.NENZEI >= NlJGENDOGAKU AND RlKIHON.GENDO_CHOKA > 1 THEN --年税額が限度超過している場合
                    RlKIHON.GENDO_CHOKA := RlKIHON.GENDO_CHOKA + RlKIHON.TSUKIWARI_GEN;
                    RlKIHON.TSUKIWARI_GEN := 0;
                  ELSE
                  --  2024/05/06 ZCZL.ZHANGLEI ADD END
                    NlNENZEIGAKU := NlNENZEIGAKU_WK + RlKIHON.TSUKIWARI_GEN;  --マイナス分を年税額から引く
                    NCNT_KAKUTEI := NCNT_KAKUTEI + 1;
                    subKakutei;               --再税額確定
                  --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
                  END IF;
                END IF;
            END IF;
        END IF;
        RlKIHON.GENGAKU_KEI   := RlKIHON.GENDO_CHOKA + RlKIHON.KEIGEN_K_WARI
                                                     + RlKIHON.KEIGEN_B_WARI
                                                     + RlKIHON.HASU
                                                     + RlEXT.KAI_NENREI_KEIGEN  -- 年齢軽減
                                                     + RlKIHON.TSUKIWARI_GEN;   -- 減額合計

    END subKakutei;

-------------------------------------------------------------------------------
-- 08.5 世帯減免情報の有無取得
-------------------------------------------------------------------------------
    PROCEDURE subSetaiGenmenGet IS

        NCNT                NUMBER(2);
        NLEN                NUMBER(2);
        RwSGenmen           ZLBTGENMEN_SETAI%ROWTYPE;
        RwKKT_JCONS         KKATCT%ROWTYPE;

    BEGIN

        VlMSG := 'subSetaiGenmenGet ZLBTGENMEN_SETAI 取得 ERR (国保世帯番号='|| i_NSETAI||')';

        -- 世帯減免情報の取得
        SELECT COUNT(*) INTO NCNT FROM ZLBTGENMEN_SETAI
         WHERE KOKU_SETAI_NO   = i_NSETAI
          AND  NENDO_BUN       = i_NNENDO_BUN
--2024/09/23 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00020
          --AND  TEKIYO_KBN      = 1;
          AND  TEKIYO_KBN      IN (1, 3);

        -- 世帯減免の有無セット
        IF NCNT = 0 THEN
           NGENMEN_USE_SKBN := 0 ;
           RETURN ;
        ELSE
           NGENMEN_USE_SKBN := 1 ;
        END IF;

        -- 世帯減免情報の取得
        SELECT * INTO RwSGenmen FROM ZLBTGENMEN_SETAI
         WHERE KOKU_SETAI_NO   = i_NSETAI
          AND  NENDO_BUN       = i_NNENDO_BUN
--2024/09/23 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00020
          --AND  TEKIYO_KBN      = 1;
          AND  TEKIYO_KBN      IN (1, 3);

        BEGIN
        VlMSG := 'subSetaiGenmenGet KKATCT XXGENMENRITSU 取得 ERR (国保世帯番号='|| i_NSETAI||')';

        -- 世帯減免率の取得
        SELECT * INTO RwKKT_JCONS FROM KKATCT
         WHERE GYOUMUCODE    = 'ZLB'
           AND TRIM(CTLPRMCODE)  = TO_CHAR(RwSGenmen.GENMEN_JIYU, 'FM00') || 'SGENMENRITSU'
           AND CTLPRMSEQ = i_NNENDO_BUN
           AND GROUPCODE = '0000';

        -- 世帯減免率の取得
        NLEN := LENGTH(RTRIM(RwKKT_JCONS.CTLPRM)) ;
        NGENMEN_USE_SRITSU := SUBSTR(RwKKT_JCONS.CTLPRM, 1, NLEN - 1);
        EXCEPTION
           WHEN NO_DATA_FOUND THEN
               -- 世帯減免率設定無し
               NGENMEN_USE_SRITSU := 0; --減免率無しで設定する。
           WHEN OTHERS THEN
               NlRTN := c_NERR;
               VlMSG := VlMSG || SQLERRM;
        END;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := VlMSG || SQLERRM;
    END subSetaiGenmenGet;
-------------------------------------------------------------------------------
-- 08 退職処理
-------------------------------------------------------------------------------
    PROCEDURE subTaiTukiwari IS

        RwKOJIN         ZLBTKOJIN_CAL%ROWTYPE;
        NwWORK          NUMBER(10):= 0; -- 計算用WORK
        NwCHOKA_TAI     NUMBER(10):= 0; -- 限度超過額(退職)

    BEGIN

        --月毎の応益係数それぞれの該当件数
        FOR NwIX IN 1..48 LOOP
            NlCNT(NwIX) := 0;
        END LOOP;

        -- 計算個人を取得し月割税額算出準備(退職)を行なう
        FOR RwKOJIN IN ClKOJIN LOOP
            subTukiwariMae_Tai(RwKOJIN);    -- 22 月割税額算出準備(退職)
        END LOOP;

        subTukiwari_Tai;            -- 23 月割税額セット(退職)
        subDouzeiTukisu_Tai;        -- 24 同税額月数算出(退職)
        subDouzeiTukisu_Tai_SEKI;   -- 24 同税額月数算出(退職積算用)
        subTukiwariNenzei_Tai;      -- 25 月割年税額算出(退職)
        subKeigenChosei_Tai;        -- 26 軽減額月割端数調整(退職)

        subDouzeiTukisu_Tai_CHO;    -- 24 同税額月数算出(退職限度額算出用)

        FOR NwIX IN 1..12 LOOP
          NwCHOKA_TAI := TRUNC(NwCHOKA_TAI) + TRUNC((MlTAICHOKA_SEKI(NwIX) * MlTAITUKI(NwIX) ) / 12);
        END LOOP;

        RlTAI.GENDO_CHOKA   := NwCHOKA_TAI;
        -- 端数切捨て差額微調整
       NwWORK := 0;
        FOR NwIX IN 1..12 LOOP
          NwWORK     := TRUNC(NwWORK)     + TRUNC((MlTAIZEIGAKU_SEKI(NwIX)     * MlTAITUKI_SEKI(NwIX) ) / 12);
        END LOOP;

        NwWORK := RlTAI.SEKISAN - NwWORK;
        IF NwWORK <> 0 AND RlTAI.GENDO_CHOKA > 0 THEN
          RlTAI.GENDO_CHOKA    := RlTAI.GENDO_CHOKA + NwWORK;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subTaiTukiwari 計算個人取得(国保世帯番号='||
                     i_NSETAI||')'||SQLERRM;
    END subTaiTukiwari;
-------------------------------------------------------------------------------
-- 07 基本処理
-------------------------------------------------------------------------------
    PROCEDURE subZenTukiwari IS

        RwKOJIN         ZLBTKOJIN_CAL%ROWTYPE;
        NwWORK          NUMBER(10):= 0; -- 端数計算用WORK
        NwCHOKA         NUMBER(15,3):= 0; --限度超過額

    BEGIN

        --月毎の応益係数それぞれの該当件数
        FOR NwIX IN 1..48 LOOP
            NlCNT(NwIX) := 0;
        END LOOP;

        subTukiKeigenSave;      -- 17 月軽減セット

        -- 計算個人を取得し月割税額算出準備を行なう
        FOR RwKOJIN IN ClKOJIN LOOP
            subTukiwariMae(RwKOJIN);    -- 16 月割税額算出準備
        END LOOP;

        subTukiwari;            -- 18 月割税額セット
        subDouzeiTukisu;        -- 19 同税額月数算出
        subDouzeiTukisu_SEKI;   -- 19 同税額月数算出(積算用)
        subTukiwariNenzei;      -- 20 月割年税額算出
        subKeigenChosei;        -- 21 軽減額月割端数調整
        subDouzeiTukisu_CHO;    -- 19 同税額月数算出(限度超過算出用)

        FOR NwIX IN 1..12 LOOP
          -- 限度超過額端数調整区分が0の場合
          IF IGENDO_HASU_KBN = 0 THEN
            -- 月毎に切り捨てて算出する
            NwCHOKA := TRUNC(NwCHOKA) + TRUNC((MlCHOKA_SEKI(NwIX) * MlTUKI(NwIX) ) / 12);
          -- 限度超過額端数調整区分が1の場合
          ELSE
            -- 端数も合算し、最後に切り捨てる
            NwCHOKA := NwCHOKA + (MlCHOKA_SEKI(NwIX) * MlTUKI(NwIX) ) / 12;
          END IF;
        END LOOP;
        IF IGENDO_HASU_KBN = 0 THEN
          RlKIHON.GENDO_CHOKA   := NwCHOKA;
        ELSE
          RlKIHON.GENDO_CHOKA   := TRUNC(NwCHOKA);
        END IF;

        -- 端数切捨て差額微調整
        NwWORK := 0;
        FOR NwIX IN 1..12 LOOP
          NwWORK     := TRUNC(NwWORK) + TRUNC((MlZEIGAKU_SEKI(NwIX) * MlTUKI_SEKI(NwIX) ) / 12);
        END LOOP;

        NwWORK := RlKIHON.SEKISAN - NwWORK;
        IF ABS(NwWORK) < 10 AND RlKIHON.GENDO_CHOKA > 0 THEN
          RlKIHON.GENDO_CHOKA    := RlKIHON.GENDO_CHOKA + NwWORK;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subZenTukiwari 計算個人取得(国保世帯番号='||
                     i_NSETAI||')'||SQLERRM;
    END subZenTukiwari;
-------------------------------------------------------------------------------
-- 06 世帯税額算出
-------------------------------------------------------------------------------
    PROCEDURE subSetaiGaku IS

        NwWORK              NUMBER;     -- 計算用WORK

    BEGIN

        -- 計算基本取得
        BEGIN
            SELECT * INTO RlKIHON_IRY FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NNUSHI
               AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subSetaiGaku 計算基本取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
        END;

        -- 以下の項目は医療と同じ
        RlKIHON.SHINKOKU_KBN    := RlKIHON_IRY.SHINKOKU_KBN;        -- 申告区分
        RlKIHON.SHU_SHOTOKU_KBN := RlKIHON_IRY.SHU_SHOTOKU_KBN;     -- 主所得区分
        RlKIHON.GISEI_KBN       := RlKIHON_IRY.GISEI_KBN;           -- 擬制区分
        RlKIHON.J_KAZEI_KBN     := RlKIHON_IRY.J_KAZEI_KBN;         -- 住民税課税区分
        RlKIHON.JOTO_S_KBN      := RlKIHON_IRY.JOTO_S_KBN;          -- 譲渡世帯区分
        RlKIHON.ROJIN_S_KBN     := RlKIHON_IRY.ROJIN_S_KBN;         -- 老人世帯区分
        RlKIHON.SENJU_S_KBN     := RlKIHON_IRY.SENJU_S_KBN;         -- 専従世帯区分
        RlKIHON.KEIGEN_SHINSEI_KBN := RlKIHON_IRY.KEIGEN_SHINSEI_KBN;   -- 軽減申請区分
        RlKIHON.KEIGEN_4        := RlKIHON_IRY.KEIGEN_4;            -- 軽減4月
        RlKIHON.KEIGEN_5        := RlKIHON_IRY.KEIGEN_5;            -- 軽減5月
        RlKIHON.KEIGEN_6        := RlKIHON_IRY.KEIGEN_6;            -- 軽減6月
        RlKIHON.KEIGEN_7        := RlKIHON_IRY.KEIGEN_7;            -- 軽減7月
        RlKIHON.KEIGEN_8        := RlKIHON_IRY.KEIGEN_8;            -- 軽減8月
        RlKIHON.KEIGEN_9        := RlKIHON_IRY.KEIGEN_9;            -- 軽減9月
        RlKIHON.KEIGEN_10       := RlKIHON_IRY.KEIGEN_10;           -- 軽減10月
        RlKIHON.KEIGEN_11       := RlKIHON_IRY.KEIGEN_11;           -- 軽減11月
        RlKIHON.KEIGEN_12       := RlKIHON_IRY.KEIGEN_12;           -- 軽減12月
        RlKIHON.KEIGEN_1        := RlKIHON_IRY.KEIGEN_1;            -- 軽減1月
        RlKIHON.KEIGEN_2        := RlKIHON_IRY.KEIGEN_2;            -- 軽減2月
        RlKIHON.KEIGEN_3        := RlKIHON_IRY.KEIGEN_3;            -- 軽減3月
        RlKIHON.KEIGEN_SHOTOKU  := RlKIHON_IRY.KEIGEN_SHOTOKU;      -- 軽減判定所得
        IF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN1 THEN             -- 6割

            RlKIHON.KEIGEN_K_WARI := RlKIHON.KINTO_CNT * NlJKGEN1;  -- 軽減均等割額(基本)
            RlKIHON.KEIGEN_B_WARI := NlJBGEN1;                      -- 軽減平等割額(基本)
            IF i_NJIKKOU_KBN != c_NTEST THEN        -- 賦課試算時は算出しない
                RlTAI.KEIGEN_K_WARI := RlTAI.KINTO_CNT * NlJKGEN1;  -- 軽減均等割額(退職)
            END IF;

        ELSIF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN2 THEN          -- 4割

            RlKIHON.KEIGEN_K_WARI := RlKIHON.KINTO_CNT * NlJKGEN2;
            RlKIHON.KEIGEN_B_WARI := NlJBGEN2;
            IF i_NJIKKOU_KBN != c_NTEST THEN        -- 賦課試算時は算出しない
                RlTAI.KEIGEN_K_WARI := RlTAI.KINTO_CNT * NlJKGEN2;
            END IF;

        ELSIF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN3 THEN          -- 2割

            RlKIHON.KEIGEN_K_WARI := RlKIHON.KINTO_CNT * NlJKGEN3;
            RlKIHON.KEIGEN_B_WARI := NlJBGEN3;
            IF i_NJIKKOU_KBN != c_NTEST THEN        -- 賦課試算時は算出しない
                RlTAI.KEIGEN_K_WARI := RlTAI.KINTO_CNT * NlJKGEN3;
            END IF;

        END IF;

-----------------------
-- 年齢軽減
-----------------------
-- 介護年齢軽減(基本、退職)を算出する
        IF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN1 THEN             -- 6割
            RlEXT.KAI_NENREI_KEIGEN := Nl22Ika_CNT * ((NlJKINTO - NlJKGEN1)/2);           -- 介護年齢軽減(基本)
            IF i_NJIKKOU_KBN != c_NTEST THEN    -- 賦課試算時は算出しない
                RlEXT.KAI_NENREI_KEIGEN_T := Nl22IkaTai_CNT * ((NlJKINTO - NlJKGEN1)/2);  -- 介護年齢軽減(退職)
            END IF;
        ELSIF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN2 THEN          -- 4割
            RlEXT.KAI_NENREI_KEIGEN := Nl22Ika_CNT * ((NlJKINTO - NlJKGEN2)/2);           -- 介護年齢軽減(基本)
            IF i_NJIKKOU_KBN != c_NTEST THEN    -- 賦課試算時は算出しない
                RlEXT.KAI_NENREI_KEIGEN_T := Nl22IkaTai_CNT * ((NlJKINTO - NlJKGEN2)/2);  -- 介護年齢軽減(退職)
            END IF;
        ELSIF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN3 THEN          -- 2割
            RlEXT.KAI_NENREI_KEIGEN := Nl22Ika_CNT * ((NlJKINTO - NlJKGEN3)/2);           -- 介護年齢軽減(基本)
            IF i_NJIKKOU_KBN != c_NTEST THEN    -- 賦課試算時は算出しない
                RlEXT.KAI_NENREI_KEIGEN_T := Nl22IkaTai_CNT * ((NlJKINTO - NlJKGEN3)/2);  -- 介護年齢軽減(退職)
            END IF;
        ELSE
            RlEXT.KAI_NENREI_KEIGEN := Nl22Ika_CNT * NlJKINTO / 2;           -- 介護年齢軽減(基本)
            IF i_NJIKKOU_KBN != c_NTEST THEN    -- 賦課試算時は算出しない
                RlEXT.KAI_NENREI_KEIGEN_T := Nl22IkaTai_CNT * NlJKINTO / 2;  -- 介護年齢軽減(退職)
            END IF;
        END IF;

        IF i_NJIKKOU_KBN     != c_NTEST AND         -- 賦課試算時は算出しない
           RlTAI.KINTO_CNT   != 0       AND
           RlKIHON.KINTO_CNT =  RlTAI.KINTO_CNT THEN

            IF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN1 THEN         -- 6割
                RlTAI.KEIGEN_B_WARI := NlJBGEN1;    -- 軽減平等割額(退職)
            ELSIF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN2 THEN      -- 4割
                RlTAI.KEIGEN_B_WARI := NlJBGEN2;
            ELSIF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN3 THEN      -- 2割
                RlTAI.KEIGEN_B_WARI := NlJBGEN3;
            END IF;

        END IF;

        NwWORK := RlKIHON.SEKISAN - RlKIHON.KEIGEN_K_WARI - RlKIHON.KEIGEN_B_WARI;
        -- 年齢軽減額も積算税額より減算
        NwWORK := NwWORK - RlEXT.KAI_NENREI_KEIGEN;

        IF NwWORK > NlJGENDOGAKU THEN
            RlKIHON.GENDO_CHOKA := NwWORK - NlJGENDOGAKU;  -- 限度超過額(基本)
            IF ITSUKI_HASU_KBN = 1 THEN
              NlCHOKA2 := (NlJGENDOGAKU *
                          (RlTAI.SEKISAN - RlTAI.KEIGEN_K_WARI - RlTAI.KEIGEN_B_WARI - RlEXT.KAI_NENREI_KEIGEN_T)) /
                          (RlKIHON.SEKISAN - RlKIHON.KEIGEN_K_WARI - RlKIHON.KEIGEN_B_WARI - RlEXT.KAI_NENREI_KEIGEN);
              NlCHOKA2 := TRUNC(NlCHOKA2);
              IF i_NJIKKOU_KBN != c_NTEST THEN        -- 賦課試算時は算出しない
                  RlTAI.GENDO_CHOKA := RlTAI.SEKISAN - RlTAI.KEIGEN_K_WARI
                                                     - RlTAI.KEIGEN_B_WARI
                                                     - RlEXT.KAI_NENREI_KEIGEN_T
                                                     - NlCHOKA2;           -- 限度超過額(退職)
              END IF;
            ELSE
              NlCHOKA := (NlJGENDOGAKU *
                          (RlTAI.SEKISAN - RlTAI.KEIGEN_K_WARI - RlTAI.KEIGEN_B_WARI )) /
                          (RlKIHON.SEKISAN - RlKIHON.KEIGEN_K_WARI - RlKIHON.KEIGEN_B_WARI);

              NlCHOKA := NlCHOKA + 0.9;
              NlCHOKA := TRUNC(NlCHOKA);
              IF i_NJIKKOU_KBN != c_NTEST THEN        -- 賦課試算時は算出しない
                  RlTAI.GENDO_CHOKA := RlTAI.SEKISAN - RlTAI.KEIGEN_K_WARI
                                                     - RlTAI.KEIGEN_B_WARI
                                                     - NlCHOKA;           -- 限度超過額(退職)
              END IF;
          END IF;
        END IF;

        NwWORK := RlKIHON.SEKISAN - RlKIHON.KEIGEN_K_WARI
                                  - RlKIHON.KEIGEN_B_WARI
                                  - RlKIHON.GENDO_CHOKA;
      --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
      IF NwWORK > 0 THEN
        IF NlJHASU = c_NHASU_KBN_2 THEN
            RlKIHON.HASU := MOD(NwWORK, c_NHASU_2);         -- 端数(基本)
        ELSIF NlJHASU = c_NHASU_KBN_1 THEN
            RlKIHON.HASU := MOD(NwWORK, c_NHASU_1);
        ELSIF NlJHASU = c_NHASU_KBN_3 THEN
            RlKIHON.HASU := MOD(NwWORK, c_NHASU_3);
        ELSIF NlJHASU = c_NHASU_KBN_10 THEN
            RlKIHON.HASU := MOD(NwWORK, c_NHASU_10);
        END IF;

        IF i_NJIKKOU_KBN != c_NTEST AND     -- 賦課試算時は算出しない
           RlKIHON.SEKISAN = RlTAI.SEKISAN THEN
            RlTAI.HASU := RlKIHON.HASU;                     -- 端数(退職)
        END IF;
      --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
      END IF;
        RlKIHON.GENGAKU_KEI := RlKIHON.GENDO_CHOKA
                             + RlKIHON.KEIGEN_K_WARI
                             + RlKIHON.KEIGEN_B_WARI
                             -- 年齢軽減額を基本の減額計に加算
                             + RlEXT.KAI_NENREI_KEIGEN
                             + RlKIHON.HASU;                -- 減額合計(基本)
        RlKIHON.NENZEI      := RlKIHON.SEKISAN - RlKIHON.GENGAKU_KEI;    -- 年税額(基本)

        IF i_NJIKKOU_KBN != c_NTEST THEN        -- 賦課試算時は算出しない
            RlTAI.GENGAKU_KEI   := RlTAI.GENDO_CHOKA
                                 + RlTAI.KEIGEN_K_WARI
                                 + RlTAI.KEIGEN_B_WARI
                             -- 年齢軽減額(退職)を基本の減額計に加算
                                 + RlEXT.KAI_NENREI_KEIGEN_T
                                 + RlTAI.HASU;                  -- 減額合計(退職)
            RlTAI.NENZEI   := RlTAI.SEKISAN   - RlTAI.GENGAKU_KEI;      -- 年税額(退職)
        END IF;

    END subSetaiGaku;
-------------------------------------------------------------------------------
-- 05 欠番
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- 04 積算税額算出
-------------------------------------------------------------------------------
    PROCEDURE subSekisan IS
      NKAHYO_DOWN NUMBER;
      NKAHYO_OVER NUMBER;
      MlTSUKIKAHYO     MTNUMARRAY12; --各月の課税標準額(４月から翌３月まで)
      MlTSUKIKAHYOTAI  MTNUMARRAY12; --退職分 各月の課税標準額(４月から翌３月まで)
      NwIX1            NUMBER(2);    --ループ用カウンタ
      NwIX2            NUMBER(2);    --ループ用カウンタ
      MlKAHYO_KIND     MTNUMARRAY12; --同額の課税標準額
      MlTSUKIZEIGAKU   MTNUMARRAY12; --月毎の税額
      MlTSUKIZEIGAKU_T MTNUMARRAY12; --月毎の税額(退職)
      NSHOTOKUWARI_MAE NUMBER;       --経過措置前の所得割額
      NSHISANWARI_MAE  NUMBER;       --経過措置前の資産割額
      MlOUEKI_KIND     MTNUMARRAY12; --応益係数
      NlNENGAKU        NUMBER;       --所得割二段階経過措置後の金額
      NBYODO_SOTI      NUMBER;       --経過措置後の平等割額
      NKINTO_SOTI      NUMBER;       --経過措置後の均等割額
      NKINTO_SOTI_TAI  NUMBER;       --経過措置後の均等割額(退職)
      NPER             MTNUMARRAY12; --応益係数
      NwCNT            MTNUMARRAY12; --応益係数それぞれの月数
      MlSUMI_K         MTNUMARRAY1; -- 済(経過措置用)
      MlTUKI_K         MTNUMARRAY2; -- 月数(経過措置用)

      CURSOR C_ZEN IS
        SELECT 	B.*
        FROM 		ZLBTKOJIN_CAL A,ZLBTKANWA_KOJIN_CAL B
        WHERE 	A.KOKU_SETAI_NO   = i_NSETAI
        AND 		A.SANTEIDANTAI_CD = i_NDANTAI
        AND 		A.CHOTEI_NENDO    = i_NNENDO
        AND 		A.NENDO_BUN       = i_NNENDO_BUN
        AND 		A.TSUCHI_NO       = i_NNUSHI
        AND 		A.SYS_TANMATSU_NO = i_VTANMATSU
        AND 		(			A.F4_KAI_KBN = 1 OR A.KAI_SHIK_4  = 1 OR A.KAI_SHIK_5  = 1 OR A.KAI_SHIK_6  = 1
        				  OR 	A.KAI_SHIK_7  = 1 OR A.KAI_SHIK_8  = 1 OR A.KAI_SHIK_9  = 1
        				  OR 	A.KAI_SHIK_10 = 1 OR A.KAI_SHIK_11 = 1 OR A.KAI_SHIK_12 = 1
        				  OR 	A.KAI_SHIK_1  = 1 OR A.KAI_SHIK_2  = 1 OR A.KAI_SHIK_3  = 1
        				)
        AND 		(
        					(  i_CAL_KBN   =   c_CAL_KBN_TU   AND A.NEW_SHIK_KBN IN (1, 3, 7, 9) AND
            		 		(A.NEW_KAI_SHIK_KBN IN (0,1) OR (A.NEW_KAI_SHIK_KBN = 2 AND A.SEKISAN_GAI_KBN = 1))
            		 	) OR
            		 (  i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND A.NEW_SHIK_KBN IN (1, 3) AND
            		  A.NEW_KAI_SHIK_KBN = 1))
        AND 		B.KOKU_SETAI_NO   = A.KOKU_SETAI_NO
        AND 		B.SANTEIDANTAI_CD = A.SANTEIDANTAI_CD
        AND 		B.CHOTEI_NENDO    = A.CHOTEI_NENDO
        AND 		B.NENDO_BUN       = A.NENDO_BUN
        AND 		B.TSUCHI_NO       = A.TSUCHI_NO
        AND 		B.SYS_TANMATSU_NO = A.SYS_TANMATSU_NO
        AND 		B.KOJIN_NO        = A.KOJIN_NO;

      CURSOR C_TAI IS
        SELECT 	B.*
        FROM 		ZLBTKOJIN_CAL A,ZLBTKANWA_KOJIN_CAL B
        WHERE 	A.KOKU_SETAI_NO   = i_NSETAI
        AND 		A.SANTEIDANTAI_CD = i_NDANTAI
        AND 		A.CHOTEI_NENDO    = i_NNENDO
        AND 		A.NENDO_BUN       = i_NNENDO_BUN
        AND 		A.TSUCHI_NO       = i_NNUSHI
        AND 		A.SYS_TANMATSU_NO = i_VTANMATSU
        AND 		(			A.F4_KAI_KBN = 1
        				  OR 	A.KAI_SHIK_4  = 1 OR A.KAI_SHIK_5  = 1 OR A.KAI_SHIK_6  = 1
        				  OR 	A.KAI_SHIK_7  = 1 OR A.KAI_SHIK_8  = 1 OR A.KAI_SHIK_9  = 1
        				  OR 	A.KAI_SHIK_10 = 1 OR A.KAI_SHIK_11 = 1 OR A.KAI_SHIK_12 = 1
        				  OR 	A.KAI_SHIK_1  = 1 OR A.KAI_SHIK_2  = 1 OR A.KAI_SHIK_3  = 1)
        AND 		(
        					( i_CAL_KBN   =   c_CAL_KBN_TU   AND A.NEW_SHIK_KBN IN (1, 3, 7, 9) AND
        						(A.NEW_KAI_SHIK_KBN IN (0,1) OR (A.NEW_KAI_SHIK_KBN = 2 AND A.SEKISAN_GAI_KBN = 1)
        						)
        					) OR
        					( i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND A.NEW_SHIK_KBN IN (1, 3) AND A.NEW_KAI_SHIK_KBN = 1)
        				)
        AND 		((KAI_SHIK_4  = 1 and SHIK_4  IN (11, 13)) OR
            		 (KAI_SHIK_5  = 1 and SHIK_5  IN (11, 13)) OR
            		 (KAI_SHIK_6  = 1 and SHIK_6  IN (11, 13)) OR
            		 (KAI_SHIK_7  = 1 and SHIK_7  IN (11, 13)) OR
            		 (KAI_SHIK_8  = 1 and SHIK_8  IN (11, 13)) OR
            		 (KAI_SHIK_9  = 1 and SHIK_9  IN (11, 13)) OR
            		 (KAI_SHIK_10 = 1 and SHIK_10 IN (11, 13)) OR
            		 (KAI_SHIK_11 = 1 and SHIK_11 IN (11, 13)) OR
            		 (KAI_SHIK_12 = 1 and SHIK_12 IN (11, 13)) OR
            		 (KAI_SHIK_1  = 1 and SHIK_1  IN (11, 13)) OR
            		 (KAI_SHIK_2  = 1 and SHIK_2  IN (11, 13)) OR
            		 (KAI_SHIK_3  = 1 and SHIK_3  IN (11, 13)))
        AND 		B.KOKU_SETAI_NO   = A.KOKU_SETAI_NO
        AND 		B.SANTEIDANTAI_CD = A.SANTEIDANTAI_CD
        AND 		B.CHOTEI_NENDO    = A.CHOTEI_NENDO
        AND 		B.NENDO_BUN       = A.NENDO_BUN
        AND 		B.TSUCHI_NO       = A.TSUCHI_NO
        AND 		B.SYS_TANMATSU_NO = A.SYS_TANMATSU_NO
        AND 		B.KOJIN_NO        = A.KOJIN_NO;
    BEGIN
        -- 所得割２段階対応
        IF NSHOTOKU_2DANKAI = 1 THEN
          IF RlKIHON.KAHYO > NSHOTOKU_HANTEI_GAKU THEN
            NKAHYO_OVER := RlKIHON.KAHYO - NSHOTOKU_HANTEI_GAKU;
            NKAHYO_DOWN := NSHOTOKU_HANTEI_GAKU;
          ELSE
            NKAHYO_OVER := 0;
            NKAHYO_DOWN := RlKIHON.KAHYO;
          END IF;
          RlKIHON.SHOTOKU_WARI := NKAHYO_OVER * NSHOTOKU_KAI_OVER / 100;
          RlKIHON.SHOTOKU_WARI := RlKIHON.SHOTOKU_WARI + NKAHYO_DOWN * NSHOTOKU_KAI / 100;

          --所得割２段階経過措置対応
          --1 以下の計算テーブル情報を取得して各月の課税標準額を算出
          SELECT (SUM(CASE B.OUNOU_4  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_5  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_6  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_7  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_8  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_9  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_10 WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_11 WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_12 WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_1  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_2  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                 (SUM(CASE B.OUNOU_3  WHEN 100 THEN A.KAHYO ELSE 0 END))
            INTO MlTSUKIKAHYO(1),MlTSUKIKAHYO(2),MlTSUKIKAHYO(3),MlTSUKIKAHYO(4),MlTSUKIKAHYO(5),MlTSUKIKAHYO(6),
                 MlTSUKIKAHYO(7),MlTSUKIKAHYO(8),MlTSUKIKAHYO(9),MlTSUKIKAHYO(10),MlTSUKIKAHYO(11),MlTSUKIKAHYO(12)
            FROM ZLBTKOJIN_CAL A,ZLBTKANWA_KOJIN_CAL B
            WHERE A.KOKU_SETAI_NO   = i_NSETAI
              AND A.SANTEIDANTAI_CD = i_NDANTAI
              AND A.CHOTEI_NENDO    = i_NNENDO
              AND A.NENDO_BUN       = i_NNENDO_BUN
              AND A.TSUCHI_NO       = i_NNUSHI
              AND A.SYS_TANMATSU_NO = i_VTANMATSU
              -- 積算対象条件
              AND (A.F4_KAI_KBN = 1
                OR A.KAI_SHIK_4  = 1 OR A.KAI_SHIK_5  = 1 OR A.KAI_SHIK_6  = 1
                OR A.KAI_SHIK_7  = 1 OR A.KAI_SHIK_8  = 1 OR A.KAI_SHIK_9  = 1
                OR A.KAI_SHIK_10 = 1 OR A.KAI_SHIK_11 = 1 OR A.KAI_SHIK_12 = 1
                OR A.KAI_SHIK_1  = 1 OR A.KAI_SHIK_2  = 1 OR A.KAI_SHIK_3  = 1)
              -- 計算緩和個人
              AND B.KOKU_SETAI_NO   = A.KOKU_SETAI_NO
              AND B.SANTEIDANTAI_CD = A.SANTEIDANTAI_CD
              AND B.CHOTEI_NENDO    = A.CHOTEI_NENDO
              AND B.NENDO_BUN       = A.NENDO_BUN
              AND B.TSUCHI_NO       = A.TSUCHI_NO
              AND B.SYS_TANMATSU_NO = A.SYS_TANMATSU_NO
              AND B.KOJIN_NO        = A.KOJIN_NO;

          --2 課税標準額が同額の月数MlTUKI_Kとその時点の課税標準額MlKAHYO_KINDを算出
          -- 配列初期化
          FOR NwIX1 IN 1..12 LOOP
            MlSUMI_K(NwIX1)       := 0;
            MlTUKI_K(NwIX1)       := 0;
            MlKAHYO_KIND(NwIX1)   := 0;
          END LOOP;

          FOR NwIX1 IN 1..12 LOOP
            FOR NwIX2 IN 1..12 LOOP
                IF MlSUMI_K(NwIX2) != 1 THEN
                  IF MlTSUKIKAHYO(NwIX1) = MlTSUKIKAHYO(NwIX2) THEN
                    MlTUKI_K(NwIX1) := MlTUKI_K(NwIX1) + 1;
                    MlSUMI_K(NwIX2) := 1;
                    MlKAHYO_KIND(NwIX1) := MlTSUKIKAHYO(NwIX1);
                  END IF;
                END IF;
            END LOOP;
          END LOOP;

          --3 2で算出した課税標準額が同額の月数ごとに経過措置後の所得割２段階の計算を行う。
          FOR NwIX IN 1..12 LOOP
            -- 所得割２段階対応
            IF MlKAHYO_KIND(NwIX) > NSHOTOKU_HANTEI_GAKU THEN
              NKAHYO_OVER := MlKAHYO_KIND(NwIX) - NSHOTOKU_HANTEI_GAKU;
              NKAHYO_DOWN := NSHOTOKU_HANTEI_GAKU;
            ELSE
              NKAHYO_OVER := 0;
              NKAHYO_DOWN := MlKAHYO_KIND(NwIX);
            END IF;
            MlTSUKIZEIGAKU(NwIX) := NKAHYO_OVER * NSHOTOKU_KAI_OVER / 100;
            MlTSUKIZEIGAKU(NwIX) := MlTSUKIZEIGAKU(NwIX) + NKAHYO_DOWN * NSHOTOKU_KAI / 100;
          END LOOP;

          --4 3で算出した金額と2で算出した月数から年額を算出 （年額 ＝ 月毎の税額×月数÷月数12）
          NlNENGAKU := 0;
          FOR NwIX IN 1..12 LOOP
            NlNENGAKU := NlNENGAKU + MlTSUKIZEIGAKU(NwIX) * MlTUKI_K(NwIX);
          END LOOP;
          NlNENGAKU := TRUNC(NlNENGAKU/12);

          --5 経過措置前の所得割と経過措置後の差額を算出し、計算拡張出力エリアにセット
          RlEXT.KAI_KEIKA_H_SHOTOKU := RlKIHON.SHOTOKU_WARI - NlNENGAKU;
          --6 4で算出した結果を計算基本出力エリアにセット
          RlKIHON.SHOTOKU_WARI := NlNENGAKU;

          IF i_NJIKKOU_KBN != c_NTEST THEN        -- 賦課試算時は算出しない
            IF RlKIHON.KAHYO > NSHOTOKU_HANTEI_GAKU THEN
              NKAHYO_OVER := TRUNC((RlKIHON.KAHYO - NSHOTOKU_HANTEI_GAKU) * (RlTAI.KAHYO / RlKIHON.KAHYO));
              NKAHYO_DOWN := TRUNC(NSHOTOKU_HANTEI_GAKU * (RlTAI.KAHYO / RlKIHON.KAHYO));
            ELSE
              NKAHYO_OVER := 0;
              NKAHYO_DOWN := RlTAI.KAHYO;
            END IF;
            RlTAI.SHOTOKU_WARI := TRUNC(NKAHYO_OVER * NSHOTOKU_KAI_OVER / 100);
            RlTAI.SHOTOKU_WARI := TRUNC(RlTAI.SHOTOKU_WARI + NKAHYO_DOWN * NSHOTOKU_KAI / 100);

            --所得２段階経過措置金額算出(退職)対応
            --1 以下の計算テーブル情報を取得して各月の課税標準額を算出
            SELECT (SUM(CASE B.OUNOU_4  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_5  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_6  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_7  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_8  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_9  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_10 WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_11 WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_12 WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_1  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_2  WHEN 100 THEN A.KAHYO ELSE 0 END)),
                   (SUM(CASE B.OUNOU_3  WHEN 100 THEN A.KAHYO ELSE 0 END))
              INTO MlTSUKIKAHYOTAI(1),MlTSUKIKAHYOTAI(2),MlTSUKIKAHYOTAI(3),MlTSUKIKAHYOTAI(4),MlTSUKIKAHYOTAI(5),MlTSUKIKAHYOTAI(6),
                   MlTSUKIKAHYOTAI(7),MlTSUKIKAHYOTAI(8),MlTSUKIKAHYOTAI(9),MlTSUKIKAHYOTAI(10),MlTSUKIKAHYOTAI(11),MlTSUKIKAHYOTAI(12)
              FROM ZLBTKOJIN_CAL A,ZLBTKANWA_KOJIN_CAL B
              WHERE A.KOKU_SETAI_NO   = i_NSETAI
                AND A.SANTEIDANTAI_CD = i_NDANTAI
                AND A.CHOTEI_NENDO    = i_NNENDO
                AND A.NENDO_BUN       = i_NNENDO_BUN
                AND A.TSUCHI_NO       = i_NNUSHI
                AND A.SYS_TANMATSU_NO = i_VTANMATSU
                -- 積算対象条件
                AND (A.F4_KAI_KBN = 1
                  OR A.KAI_SHIK_4  = 1 OR A.KAI_SHIK_5  = 1 OR A.KAI_SHIK_6  = 1
                  OR A.KAI_SHIK_7  = 1 OR A.KAI_SHIK_8  = 1 OR A.KAI_SHIK_9  = 1
                  OR A.KAI_SHIK_10 = 1 OR A.KAI_SHIK_11 = 1 OR A.KAI_SHIK_12 = 1
                  OR A.KAI_SHIK_1  = 1 OR A.KAI_SHIK_2  = 1 OR A.KAI_SHIK_3  = 1)
                AND ((i_CAL_KBN = c_CAL_KBN_TU AND A.NEW_SHIK_KBN IN (1, 3, 7, 9) AND
                     (A.NEW_KAI_SHIK_KBN IN (0,1) OR (A.NEW_KAI_SHIK_KBN = 2 AND A.SEKISAN_GAI_KBN = 1))) OR
                     (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND A.NEW_SHIK_KBN IN (1, 3) AND
                      A.NEW_KAI_SHIK_KBN = 1))
                AND ((A.KAI_SHIK_4  = 1 and A.SHIK_4  IN (11, 13)) OR
                     (A.KAI_SHIK_5  = 1 and A.SHIK_5  IN (11, 13)) OR
                     (A.KAI_SHIK_6  = 1 and A.SHIK_6  IN (11, 13)) OR
                     (A.KAI_SHIK_7  = 1 and A.SHIK_7  IN (11, 13)) OR
                     (A.KAI_SHIK_8  = 1 and A.SHIK_8  IN (11, 13)) OR
                     (A.KAI_SHIK_9  = 1 and A.SHIK_9  IN (11, 13)) OR
                     (A.KAI_SHIK_10 = 1 and A.SHIK_10 IN (11, 13)) OR
                     (A.KAI_SHIK_11 = 1 and A.SHIK_11 IN (11, 13)) OR
                     (A.KAI_SHIK_12 = 1 and A.SHIK_12 IN (11, 13)) OR
                     (A.KAI_SHIK_1  = 1 and A.SHIK_1  IN (11, 13)) OR
                     (A.KAI_SHIK_2  = 1 and A.SHIK_2  IN (11, 13)) OR
                     (A.KAI_SHIK_3  = 1 and A.SHIK_3  IN (11, 13)))
                -- 計算緩和個人
                AND B.KOKU_SETAI_NO   = A.KOKU_SETAI_NO
                AND B.SANTEIDANTAI_CD = A.SANTEIDANTAI_CD
                AND B.CHOTEI_NENDO    = A.CHOTEI_NENDO
                AND B.NENDO_BUN       = A.NENDO_BUN
                AND B.TSUCHI_NO       = A.TSUCHI_NO
                AND B.SYS_TANMATSU_NO = A.SYS_TANMATSU_NO
                AND B.KOJIN_NO        = A.KOJIN_NO;

            --2 課税標準額が同額の月数MlTUKI_Kとその時点の課税標準額MlKAHYO_KINDを算出
            -- 配列初期化
            FOR NwIX1 IN 1..12 LOOP
              MlSUMI_K(NwIX1)       := 0;
              MlTUKI_K(NwIX1)       := 0;
              MlKAHYO_KIND(NwIX1) := 0;
            END LOOP;

            FOR NwIX1 IN 1..12 LOOP
              FOR NwIX2 IN 1..12 LOOP
                IF MlSUMI_K(NwIX2) != 1 THEN
                  IF MlTSUKIKAHYOTAI(NwIX1) = MlTSUKIKAHYOTAI(NwIX2) THEN
                     MlTUKI_K(NwIX1) := MlTUKI_K(NwIX1) + 1;
                     MlSUMI_K(NwIX2) := 1;
                     MlKAHYO_KIND(NwIX1) := MlTSUKIKAHYO(NwIX1);
                  END IF;
                END IF;
              END LOOP;
            END LOOP;

            --3 2で算出した課税標準額が同額の月数ごとに経過措置後の所得割２段階の計算を行う。
            FOR NwIX IN 1..12 LOOP
              -- 所得割２段階対応
              IF MlKAHYO_KIND(NwIX) > NSHOTOKU_HANTEI_GAKU THEN
                NKAHYO_OVER := TRUNC((MlTSUKIKAHYO(NwIX) - NSHOTOKU_HANTEI_GAKU) * (MlTSUKIKAHYOTAI(NwIX) / MlTSUKIKAHYO(NwIX)));
                NKAHYO_DOWN := TRUNC(NSHOTOKU_HANTEI_GAKU * (MlTSUKIKAHYOTAI(NwIX) / MlTSUKIKAHYO(NwIX)));
              ELSE
                NKAHYO_OVER := 0;
                NKAHYO_DOWN := MlKAHYO_KIND(NwIX);
              END IF;
              MlTSUKIZEIGAKU_T(NwIX) := NKAHYO_OVER * NSHOTOKU_KAI_OVER / 100;
              MlTSUKIZEIGAKU_T(NwIX) := MlTSUKIZEIGAKU_T(NwIX) + NKAHYO_DOWN * NSHOTOKU_KAI / 100;
            END LOOP;

            --4 3で算出した金額と2で算出した月数と月数から年額を算出 （年額 ＝ 月毎の税額×月数÷月数12）
            NlNENGAKU := 0;
            FOR NwIX IN 1..12 LOOP
              NlNENGAKU := NlNENGAKU + MlTSUKIZEIGAKU_T(NwIX) * MlTUKI_K(NwIX);
            END LOOP;
            NlNENGAKU := TRUNC(NlNENGAKU/12);

            --5 経過措置前の所得割と経過措置後の差額を算出し、計算拡張出力エリアにセット
            RlEXT.KAI_KEIKA_H_SHOTOKU_T := RlTAI.SHOTOKU_WARI - NlNENGAKU;
            --6 4で算出した結果を計算基本出力エリアにセット
          END IF;
        --所得割２段階実施でない場合
        ELSE
          --1以下のSQLで経過措置前の所得割額を算出
          SELECT NVL(SUM(TRUNC(KAHYO*(NSHOTOKU_KAI/100))), 0)
            INTO NSHOTOKUWARI_MAE
            FROM ZLBTKOJIN_CAL
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND CHOTEI_NENDO    = i_NNENDO
              AND NENDO_BUN       = i_NNENDO_BUN
              AND TSUCHI_NO       = i_NNUSHI
              AND SYS_TANMATSU_NO = i_VTANMATSU
              -- 積算対象条件
              AND (F4_KAI_KBN = 1
                OR KAI_SHIK_4  = 1 OR KAI_SHIK_5  = 1 OR KAI_SHIK_6  = 1
                OR KAI_SHIK_7  = 1 OR KAI_SHIK_8  = 1 OR KAI_SHIK_9  = 1
                OR KAI_SHIK_10 = 1 OR KAI_SHIK_11 = 1 OR KAI_SHIK_12 = 1
                OR KAI_SHIK_1  = 1 OR KAI_SHIK_2  = 1 OR KAI_SHIK_3  = 1)
              AND ((i_CAL_KBN = c_CAL_KBN_TU AND NEW_SHIK_KBN IN (1, 3, 7, 9) AND
                   (NEW_KAI_SHIK_KBN IN (0,1) OR (NEW_KAI_SHIK_KBN = 2 AND SEKISAN_GAI_KBN = 1))) OR
                   (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND NEW_SHIK_KBN IN (1, 3) AND
                    NEW_KAI_SHIK_KBN = 1));
          --2経過措置前の所得割と経過措置後の差額を算出し、計算拡張出力エリアにセット
          RlEXT. KAI_KEIKA_H_SHOTOKU := NSHOTOKUWARI_MAE - RlKIHON.SHOTOKU_WARI;

          IF i_NJIKKOU_KBN != c_NTEST THEN        -- 賦課試算時は算出しない
            --1以下のSQLで経過措置前の所得割額を算出
            SELECT NVL(SUM(TRUNC(KAHYO*(NSHOTOKU_KAI/100))), 0)
              INTO NSHOTOKUWARI_MAE
              FROM ZLBTKOJIN_CAL
              WHERE KOKU_SETAI_NO   = i_NSETAI
                AND SANTEIDANTAI_CD = i_NDANTAI
                AND CHOTEI_NENDO    = i_NNENDO
                AND NENDO_BUN       = i_NNENDO_BUN
                AND TSUCHI_NO       = i_NNUSHI
                AND SYS_TANMATSU_NO = i_VTANMATSU
                -- 積算対象条件
                AND (F4_KAI_KBN = 1
                  OR KAI_SHIK_4  = 1 OR KAI_SHIK_5  = 1 OR KAI_SHIK_6  = 1
                  OR KAI_SHIK_7  = 1 OR KAI_SHIK_8  = 1 OR KAI_SHIK_9  = 1
                  OR KAI_SHIK_10 = 1 OR KAI_SHIK_11 = 1 OR KAI_SHIK_12 = 1
                  OR KAI_SHIK_1  = 1 OR KAI_SHIK_2  = 1 OR KAI_SHIK_3  = 1)
                AND ((KAI_SHIK_4  = 1 and SHIK_4  IN (11, 13)) OR
                     (KAI_SHIK_5  = 1 and SHIK_5  IN (11, 13)) OR
                     (KAI_SHIK_6  = 1 and SHIK_6  IN (11, 13)) OR
                     (KAI_SHIK_7  = 1 and SHIK_7  IN (11, 13)) OR
                     (KAI_SHIK_8  = 1 and SHIK_8  IN (11, 13)) OR
                     (KAI_SHIK_9  = 1 and SHIK_9  IN (11, 13)) OR
                     (KAI_SHIK_10 = 1 and SHIK_10 IN (11, 13)) OR
                     (KAI_SHIK_11 = 1 and SHIK_11 IN (11, 13)) OR
                     (KAI_SHIK_12 = 1 and SHIK_12 IN (11, 13)) OR
                     (KAI_SHIK_1  = 1 and SHIK_1  IN (11, 13)) OR
                     (KAI_SHIK_2  = 1 and SHIK_2  IN (11, 13)) OR
                     (KAI_SHIK_3  = 1 and SHIK_3  IN (11, 13)));

            --2経過措置前の所得割と経過措置後の差額を算出し、計算拡張出力エリアにセット
            RlEXT.KAI_KEIKA_H_SHOTOKU_T := NSHOTOKUWARI_MAE - RlTAI.SHOTOKU_WARI;
          END IF;
        END IF;

        --1以下のSQLで経過措置前の資産割額を算出
        SELECT NVL(SUM(TRUNC(SHISANZEI*(NSHISAN_KAI/100))), 0)
          INTO NSHISANWARI_MAE
          FROM ZLBTKOJIN_CAL
          WHERE KOKU_SETAI_NO  = i_NSETAI
            AND SANTEIDANTAI_CD = i_NDANTAI
            AND CHOTEI_NENDO    = i_NNENDO
            AND NENDO_BUN       = i_NNENDO_BUN
            AND TSUCHI_NO       = i_NNUSHI
            AND SYS_TANMATSU_NO = i_VTANMATSU
            -- 積算対象条件
            AND (F4_KAI_KBN = 1
              OR KAI_SHIK_4  = 1 OR KAI_SHIK_5  = 1 OR KAI_SHIK_6  = 1
              OR KAI_SHIK_7  = 1 OR KAI_SHIK_8  = 1 OR KAI_SHIK_9  = 1
              OR KAI_SHIK_10 = 1 OR KAI_SHIK_11 = 1 OR KAI_SHIK_12 = 1
              OR KAI_SHIK_1  = 1 OR KAI_SHIK_2  = 1 OR KAI_SHIK_3  = 1)
            AND ((i_CAL_KBN = c_CAL_KBN_TU AND NEW_SHIK_KBN IN (1, 3, 7, 9) AND
                 (NEW_KAI_SHIK_KBN IN (0,1) OR (NEW_KAI_SHIK_KBN = 2 AND SEKISAN_GAI_KBN = 1))) OR
                 (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND NEW_SHIK_KBN IN (1, 3) AND
                  NEW_KAI_SHIK_KBN = 1));
        --2経過措置前の所得割と経過措置後の差額を算出し、計算拡張出力エリアにセット
        RlEXT.KAI_KEIKA_H_SHISAN := NSHISANWARI_MAE - RlKIHON.SHISAN_WARI;

        IF i_NJIKKOU_KBN != c_NTEST THEN        -- 賦課試算時は算出しない
          --1以下のSQLで経過措置前の資産割額を算出
          SELECT NVL(SUM(TRUNC(SHISANZEI*(NSHISAN_KAI/100))), 0)
            INTO NSHISANWARI_MAE
            FROM ZLBTKOJIN_CAL
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND CHOTEI_NENDO    = i_NNENDO
              AND NENDO_BUN       = i_NNENDO_BUN
              AND TSUCHI_NO       = i_NNUSHI
              AND SYS_TANMATSU_NO = i_VTANMATSU
              -- 積算対象条件
              AND (F4_KAI_KBN = 1
                OR KAI_SHIK_4  = 1 OR KAI_SHIK_5  = 1 OR KAI_SHIK_6  = 1
                OR KAI_SHIK_7  = 1 OR KAI_SHIK_8  = 1 OR KAI_SHIK_9  = 1
                OR KAI_SHIK_10 = 1 OR KAI_SHIK_11 = 1 OR KAI_SHIK_12 = 1
                OR KAI_SHIK_1  = 1 OR KAI_SHIK_2  = 1 OR KAI_SHIK_3  = 1)
              AND ((i_CAL_KBN = c_CAL_KBN_TU AND NEW_SHIK_KBN IN (1, 3, 7, 9) AND
                   (NEW_KAI_SHIK_KBN IN (0,1) OR (NEW_KAI_SHIK_KBN = 2 AND SEKISAN_GAI_KBN = 1))) OR
                   (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND NEW_SHIK_KBN IN (1, 3) AND
                    NEW_KAI_SHIK_KBN = 1))
              AND ((KAI_SHIK_4  = 1 and SHIK_4  IN (11, 13)) OR
                   (KAI_SHIK_5  = 1 and SHIK_5  IN (11, 13)) OR
                   (KAI_SHIK_6  = 1 and SHIK_6  IN (11, 13)) OR
                   (KAI_SHIK_7  = 1 and SHIK_7  IN (11, 13)) OR
                   (KAI_SHIK_8  = 1 and SHIK_8  IN (11, 13)) OR
                   (KAI_SHIK_9  = 1 and SHIK_9  IN (11, 13)) OR
                   (KAI_SHIK_10 = 1 and SHIK_10 IN (11, 13)) OR
                   (KAI_SHIK_11 = 1 and SHIK_11 IN (11, 13)) OR
                   (KAI_SHIK_12 = 1 and SHIK_12 IN (11, 13)) OR
                   (KAI_SHIK_1  = 1 and SHIK_1  IN (11, 13)) OR
                   (KAI_SHIK_2  = 1 and SHIK_2  IN (11, 13)) OR
                   (KAI_SHIK_3  = 1 and SHIK_3  IN (11, 13)));

          --2経過措置前の資産割と経過措置後の差額を算出し、計算拡張出力エリアにセット
          RlEXT. KAI_KEIKA_H_SHISAN_T := NSHISANWARI_MAE - RlTAI.SHISAN_WARI;
        END IF;

        RlKIHON.KINTO_WARI  := RlKIHON.KINTO_CNT * NlJKINTO;  -- 均等割額(基本)
        RlTAI.KINTO_WARI    := RlTAI.KINTO_CNT   * NlJKINTO;  -- 均等割額(退職)

        IF RlKIHON.KINTO_CNT > 0 THEN
            RlKIHON.BYODO_WARI  := NlJBYODO;      -- 平等割額(基本)
        END IF;
        IF RlTAI.KINTO_CNT > 0 AND RlKIHON.KINTO_CNT = RlTAI.KINTO_CNT THEN
            RlTAI.BYODO_WARI    := NlJBYODO;      -- 平等割額(退職)
        END IF;

        N_K_KINTO_WARI_20010   := IKINTO_CNT_20010 * NlJKINTO;  -- 均等割額(基本)
        IF IKINTO_CNT_20010 > 0 THEN
          N_K_BYODO_WARI_20010  := NlJBYODO;      -- 平等割額(基本)
        END IF;
        IF IKINTO_CNT_20010 = RlTAI.KINTO_CNT AND RlTAI.KINTO_CNT > 0 THEN
          N_T_BYODO_WARI_20010  := NlJBYODO;      -- 平等割額(基本)
        END IF;

        IF RlKIHON.KINTO_CNT > 0 THEN
        --応益経過措置金額算出
        --平等割
        --1以下の計算TBL情報を取得して応益係数=100%・90%・70%・50%のそれぞれの月数を算出
        --応益係数取得
        BEGIN
          SELECT CASE TAISHO_KBN_4  WHEN 2 THEN OUEKI_4  ELSE 100 END,
                 CASE TAISHO_KBN_5  WHEN 2 THEN OUEKI_5  ELSE 100 END,
                 CASE TAISHO_KBN_6  WHEN 2 THEN OUEKI_6  ELSE 100 END,
                 CASE TAISHO_KBN_7  WHEN 2 THEN OUEKI_7  ELSE 100 END,
                 CASE TAISHO_KBN_8  WHEN 2 THEN OUEKI_8  ELSE 100 END,
                 CASE TAISHO_KBN_9  WHEN 2 THEN OUEKI_9  ELSE 100 END,
                 CASE TAISHO_KBN_10 WHEN 2 THEN OUEKI_10 ELSE 100 END,
                 CASE TAISHO_KBN_11 WHEN 2 THEN OUEKI_11 ELSE 100 END,
                 CASE TAISHO_KBN_12 WHEN 2 THEN OUEKI_12 ELSE 100 END,
                 CASE TAISHO_KBN_1  WHEN 2 THEN OUEKI_1  ELSE 100 END,
                 CASE TAISHO_KBN_2  WHEN 2 THEN OUEKI_2  ELSE 100 END,
                 CASE TAISHO_KBN_3  WHEN 2 THEN OUEKI_3  ELSE 100 END
            INTO MlOUEKI(1) ,MlOUEKI(2) ,MlOUEKI(3) ,MlOUEKI(4) ,MlOUEKI(5) ,MlOUEKI(6) ,
                 MlOUEKI(7) ,MlOUEKI(8) ,MlOUEKI(9) ,MlOUEKI(10),MlOUEKI(11),MlOUEKI(12)
            FROM ZLBTKANWA_SETAI_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI
             AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
          WHEN OTHERS THEN
            MlOUEKI(1)  := 100;
            MlOUEKI(2)  := 100;
            MlOUEKI(3)  := 100;
            MlOUEKI(4)  := 100;
            MlOUEKI(5)  := 100;
            MlOUEKI(6)  := 100;
            MlOUEKI(7)  := 100;
            MlOUEKI(8)  := 100;
            MlOUEKI(9)  := 100;
            MlOUEKI(10) := 100;
            MlOUEKI(11) := 100;
            MlOUEKI(12) := 100;
        END;
        FOR NwIX IN 1..12 LOOP
          MlOUEKI(NwIX) := 100;
        END LOOP;
--          --2 応益係数が同じ月数MlTUKI_Kとその時点の応益係数MlOUEKI_KINDを算出
--          -- 配列初期化
--          --3 以下の計算式で経過措置後の平等割の金額を応益係数の種類毎に算出
--          --平等割 Ａ＝TRUNC((システム条件の平等割額)×応益係数÷100×該当月数÷12))
--          --4経過措置前の金額との差額を算出し、計算拡張出力エリアにセット。
--          --1で取得した対象区分によりセットするエリア分岐
--          --平等割(被扶養者)
--          --5 2で算出した結果を計算基本出力エリアにセット
--          --平等割
--          --平等割(特定同一)介護は「特定同一世帯の経過措置対応（単身世帯）は不要」
        --2 応益係数が同じ月数MlTUKI_Kとその時点の応益係数MlOUEKI_KINDを算出
        -- 配列初期化
        FOR NwIX1 IN 1..12 LOOP
          MlSUMI_K(NwIX1)       := 0;
          MlTUKI_K(NwIX1)       := 0;
          MlOUEKI_KIND(NwIX1) := 0;
        END LOOP;

        FOR NwIX1 IN 1..12 LOOP
          FOR NwIX2 IN 1..12 LOOP
           IF MlSUMI_K(NwIX2) != 1 THEN
              IF MlOUEKI(NwIX1) = MlOUEKI(NwIX2) THEN
                 MlTUKI_K(NwIX1) := MlTUKI_K(NwIX1) + 1;
                 MlSUMI_K(NwIX2) := 1;
                 MlOUEKI_KIND(NwIX1) := MlOUEKI(NwIX1);
              END IF;
            END IF;
          END LOOP;
        END LOOP;

        --3 以下の計算式で経過措置後の平等割の金額を応益係数の種類毎に算出
        --平等割 Ａ＝TRUNC((システム条件の平等割額)×応益係数÷100×該当月数÷12))
        NBYODO_SOTI := 0;
        FOR NwIX IN 1..12 LOOP
          NBYODO_SOTI := NBYODO_SOTI + TRUNC(NlJBYODO * MlOUEKI_KIND(NwIX) / 100) * MlTUKI_K(NwIX) / 12;
        END LOOP;
        -- 均等人員 = 0 の場合は、経過措置後の平等割額=\0とする
        IF RlKIHON.KINTO_CNT = 0 THEN
            NBYODO_SOTI  := 0;
        END IF;

        --4経過措置前の金額との差額を算出し、計算拡張出力エリアにセット。
        --1で取得した対象区分によりセットするエリア分岐
        --平等割(被扶養者)
        RlEXT.KAI_KEIKA_BYODOWARI := RlKIHON.BYODO_WARI - NBYODO_SOTI;
        --5 2で算出した結果を計算基本出力エリアにセット
        --平等割
        RlKIHON.BYODO_WARI:=NBYODO_SOTI;
        N_K_BYODO_WARI_20010  := NBYODO_SOTI;
        IF IKINTO_CNT_20010 = RlTAI.KINTO_CNT AND RlTAI.KINTO_CNT > 0 THEN
          N_T_BYODO_WARI_20010  := NBYODO_SOTI;
        END IF;

        ELSE  -- 均等人数が0の時
          RlEXT.KAI_KEIKA_BYODOWARI := RlKIHON.BYODO_WARI;
        END IF;
        --均等割
        --6以下の計算TBL情報を取得して該当世帯のトータル月数と応益係数=100%・90%・70%・50%のそれぞれの月数を算出
        NPER(1)       := 50;
        NPER(2)       := 70;
        NPER(3)       := 90;
        NPER(4)       := 100;

        FOR IDX IN 1..4 LOOP
          NwCNT(IDX) := 0;
        END LOOP;

        FOR R_KJN IN C_ZEN LOOP
          FOR IDX2 IN 1..4 LOOP
            IF R_KJN.OUEKI_4   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_5   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_6   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_7   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_8   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_9   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_10  = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_11  = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_12  = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_1   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_2   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_3   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
          END LOOP;
        END LOOP;

        --7 以下の計算式で経過措置後の均等割の金額を応益係数の種類毎に算出
        --均等割 Ｂ＝TRUNC((RIKIHON.KINTO_CNT×システム条件の均等割額)×応益係数÷100×該当月数÷トータル月数))
        NKINTO_SOTI := 0;
        IF (NwCNT(1)+NwCNT(2)+NwCNT(3)+NwCNT(4)) <> 0 THEN
          FOR NwIX IN 1..4 LOOP
            NKINTO_SOTI := NKINTO_SOTI + TRUNC((RlKIHON.KINTO_CNT * NlJKINTO) * NPER(NwIX) / 100 * NwCNT(NwIX) / (NwCNT(1)+NwCNT(2)+NwCNT(3)+NwCNT(4)));
          END LOOP;
          --8経過措置前の金額との差額を算出し、計算拡張出力エリアにセット。
          --均等割(被扶養者)
          RlEXT. KAI_KEIKA_H_KINTOWARI := RlKIHON.KINTO_WARI - NKINTO_SOTI;
          --9 7で算出した結果を計算基本出力エリアにセット
          --均等割
          RlKIHON.KINTO_WARI:=NKINTO_SOTI;
        END IF;
        --平等割
        --1以下の条件を満たせば、2へ。満たさなければ4へ
        --<条件>退職均等人員>0and均等人員=退職均等人員
        IF RlTAI.KINTO_CNT > 0 AND RlKIHON.KINTO_CNT = RlTAI.KINTO_CNT THEN
--          --2全体で計算した結果をそのまま退職として計算拡張出力エリアにセット。
--            --平等割(被扶養者)
          --2全体で計算した結果をそのまま退職として計算拡張出力エリアにセット。
          --平等割(被扶養者)
          RlEXT. KAI_KEIKA_BYODOWARI_T := RlEXT.KAI_KEIKA_BYODOWARI;
          --3全体で計算した結果をそのまま退職として計算退職基本出力エリアにセット
          --平等割
          RlTAI.BYODO_WARI:= RlKIHON.BYODO_WARI;
        END IF;
        IF  RlTAI.KINTO_CNT > 0 THEN
        --均等割
        --4以下の計算TBL情報を取得して該当世帯のトータル月数と応益係数=100%・90%・70%・50%のそれぞれの月数を算出
        NPER(1)           := 50;
        NPER(2)           := 70;
        NPER(3)           := 90;
        NPER(4)           := 100;

        FOR IDX IN 1..4 LOOP
          NwCNT(IDX) := 0;
        END LOOP;

        FOR R_KJN IN C_TAI LOOP
          FOR IDX2 IN 1..4 LOOP
            IF R_KJN.OUEKI_4   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_5   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_6   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_7   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_8   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_9   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_10  = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_11  = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_12  = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_1   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_2   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
            IF R_KJN.OUEKI_3   = NPER(IDX2) THEN NwCNT(IDX2) :=  NwCNT(IDX2) + 1; END IF;
          END LOOP;
        END LOOP;

        --5 以下の計算式で経過措置後の均等割の金額を応益係数の種類毎に算出
        --均等割
        --Ｂ＝TRUNC((RITAI.KINTO_CNT×システム条件の均等割額)×応益係数÷100×該当月数÷トータル月数))
        NKINTO_SOTI_TAI := 0;
        IF (NwCNT(1)+NwCNT(2)+NwCNT(3)+NwCNT(4)) <> 0 THEN
          FOR NwIX IN 1..4 LOOP
            NKINTO_SOTI_TAI := NKINTO_SOTI_TAI + TRUNC((RlTAI.KINTO_CNT * NlJKINTO) * NPER(NwIX) / 100 * NwCNT(NwIX) / (NwCNT(1)+NwCNT(2)+NwCNT(3)+NwCNT(4)));
          END LOOP;
          --6 経過措置前の金額との差額を算出し、計算拡張出力エリアにセット。
          --均等割(被扶養者)
          RlEXT. KAI_KEIKA_H_KINTOWARI_T := RlTAI.KINTO_WARI - NKINTO_SOTI_TAI;
          --7 5で算出した結果を計算退職基本出力エリアにセット
          --均等割
          RlTAI.KINTO_WARI := NKINTO_SOTI_TAI;
        END IF;
        ELSE      -- 退職区分が0のとき
          RlEXT. KAI_KEIKA_H_KINTOWARI_T:= 0;
          RlTAI.KINTO_WARI := 0;
        END IF;

        RlKIHON.SEKISAN := RlKIHON.SHOTOKU_WARI + RlKIHON.SHISAN_WARI
                         + RlKIHON.KINTO_WARI   + RlKIHON.BYODO_WARI;       -- 積算税額(基本)
        RlTAI.SEKISAN   := RlTAI.SHOTOKU_WARI   + RlTAI.SHISAN_WARI
                         + RlTAI.KINTO_WARI     + RlTAI.BYODO_WARI;         -- 積算税額(退職)

        IF RlTAI.GENZAI_CNT = 0 THEN
            RlKIHON.SETAI_KBN := 0;                                 -- 世帯区分(基本)
        ELSIF RlTAI.GENZAI_CNT != 0 AND RlKIHON.GENZAI_CNT = RlTAI.GENZAI_CNT THEN
            RlKIHON.SETAI_KBN := 1;
        ELSIF RlTAI.GENZAI_CNT != 0 AND RlKIHON.GENZAI_CNT != RlTAI.GENZAI_CNT THEN
            RlKIHON.SETAI_KBN := 2;
        END IF;

        IF NVL(i_NKOSEIBI, 0) > 0 THEN
          RlKIHON.KOSEI_BI  := i_NKOSEIBI;                               -- 更正日(基本) 引数
        ELSE
          RlKIHON.KOSEI_BI  := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));  -- 更正日(基本) システム日付
        END IF;

        RlKIHON.IDO_JIYU    := NlMAX_JIYU;              -- 事由(基本)
        RlKIHON.GENZON_KBN  := NlGENZON_KBN;            -- 現存区分(基本)
        RlKIHON.GISEI_KBN   := NlGISEI_KBN;             -- 擬制区分(基本)

    END subSekisan;
-------------------------------------------------------------------------------
-- 03 積算税額算出準備
-------------------------------------------------------------------------------
    PROCEDURE subSekisanMae(i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) IS

        NwIX            NUMBER(2);
        IwCNT1           PLS_INTEGER := 0;       -- 失業非該当月
        IwCNT2           PLS_INTEGER := 0;       -- 失業該当月
        NwKAHYO          NUMBER(12, 3);          -- 課税標準額
        NwSHOTOKU        NUMBER(12, 3);          -- 所得額
        NwKEIGEN_SHOTOKU NUMBER(12, 3);          -- 所得額
        NSHITSU_KBN      NUMBER;                 -- 失業軽減対象区分

    BEGIN

        IF NlMAX_TODOKEDE_BI < i_RKOJIN.KAI_KOSEI_BI
         AND i_RKOJIN.NEW_SHIK_KBN<>5 THEN

            NlMAX_TODOKEDE_BI   := i_RKOJIN.KAI_KOSEI_BI;       -- 最大届出日(Work)
            NlMAX_JIYU          := i_RKOJIN.KAI_JIYU;           -- 最大事由(Work)
        END IF;

        IF i_RKOJIN.NEW_SHIK_KBN IN (1, 2, 3) THEN
            IF i_RKOJIN.NEW_KAI_SHIK_KBN = 1 THEN       -- 介護該当
                NlGENZON_KBN    := 0;                           -- 現存区分(Work)
            END IF;
        END IF;

        -- ◆
        IF i_CAL_KBN = c_CAL_KBN_TU THEN
            -- 通常課税計算
            IF (i_RKOJIN.NEW_SHIK_KBN IN (1, 3, 7, 9) OR
                (i_RKOJIN.NEW_SHIK_KBN IN (2, 8) AND i_RKOJIN.SEKISAN_GAI_KBN = 1)) AND
               i_RKOJIN.F4_SHIK_KBN IN (1, 3) THEN
                IF (i_RKOJIN.NEW_KAI_SHIK_KBN IN (0, 1) OR
                    (i_RKOJIN.NEW_KAI_SHIK_KBN = 2 AND i_RKOJIN.SEKISAN_GAI_KBN = 1)) AND
                   i_RKOJIN.F4_KAI_KBN = 1 THEN

                    RlKIHON.FUKA_KIJITSU_CNT   := RlKIHON.FUKA_KIJITSU_CNT + 1; -- 賦課期日人員(基本)

                    IF i_NJIKKOU_KBN != c_NTEST AND         -- 賦課試算時は算出しない
                       i_RKOJIN.F4_TAI_KBN IN (1, 2) THEN
                        RlTAI.FUKA_KIJITSU_CNT := RlTAI.FUKA_KIJITSU_CNT + 1;   -- 賦課期日人員(退職)
                    END IF;

                END IF;
            END IF;
        ELSE
            -- 賦課期日時点
            IF i_RKOJIN.NEW_SHIK_KBN IN (1, 3) THEN
                IF i_RKOJIN.NEW_KAI_SHIK_KBN = 1 THEN

                    RlKIHON.FUKA_KIJITSU_CNT   := RlKIHON.FUKA_KIJITSU_CNT + 1; -- 賦課期日人員(基本)

                    IF i_RKOJIN.F4_TAI_KBN IN (1, 2) THEN
                        RlTAI.FUKA_KIJITSU_CNT := RlTAI.FUKA_KIJITSU_CNT + 1;   -- 賦課期日人員(退職)
                    END IF;

                END IF;
            END IF;
        END IF;

-- 計算個人から以下の条件を満たす人数を一般と退職でそれぞれカウント
-- 身障減免に関しては所得額も合計
        ----------------------------
        -- 22才以下人員
        ----------------------------
        IF NlNENREI_KEIGEN = 1 THEN
          -- システム条件より年齢軽減有り
            IF i_CAL_KBN = c_CAL_KBN_TU THEN
                IF i_RKOJIN.NEW_SHIK_KBN IN (3, 9) AND                                         --最新資格区分(員)
                   i_RKOJIN.NEW_KAI_SHIK_KBN IN (0, 1) THEN                                     --最新介護区分(非該当or該当)
                    IF i_RKOJIN.CUST_3 = 1 THEN
                        Nl22Ika_CNT   := Nl22Ika_CNT + 1;           -- 22歳以下人員
                    END IF;

                    IF i_NJIKKOU_KBN != c_NTEST AND                 -- 賦課試算時は算出しない
                       i_RKOJIN.NEW_TAI_KBN IN (1, 2) THEN
                        IF i_RKOJIN.CUST_3 = 1 THEN
                            Nl22IkaTai_CNT   := Nl22IkaTai_CNT + 1; -- 22歳以下人員(退職)
                        END IF;
                    END IF;
                END IF;
            ELSE
            -- 賦課期日時点
                IF i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4)  AND
                   i_RKOJIN.NEW_SHIK_KBN     = 3             AND
                   i_RKOJIN.NEW_KAI_SHIK_KBN =1 THEN                --最新介護区分(該当)
                    IF i_RKOJIN.CUST_3 = 1 THEN
                        Nl22Ika_CNT   := Nl22Ika_CNT + 1;           -- 22歳以下人員
                    END IF;
                    IF i_RKOJIN.NEW_TAI_KBN IN (1, 2) THEN
                        IF i_RKOJIN.CUST_3 = 1 THEN
                            Nl22IkaTai_CNT   := Nl22IkaTai_CNT + 1; -- 22歳以下人員(退職)
                        END IF;
                    END IF;
                END IF;
            END IF;
        ELSE
            -- 年齢軽減無し
            Nl22Ika_CNT      := 0;
            Nl22IkaTai_CNT   := 0;
        END IF;

        ----------------------------
        -- 身障人員/身障減免判定所得
        ----------------------------
        IF NlSINSHO_GENMEN = 1 THEN
            -- システム条件より身障減免有り
            IF i_CAL_KBN = c_CAL_KBN_TU THEN
                -- 通常課税計算
                IF i_RKOJIN.KAI_SHIK_4 = 1 OR                                     --最新介護区分(非該当or該当)
                   i_RKOJIN.KAI_SHIK_5 = 1 OR
                   i_RKOJIN.KAI_SHIK_6 = 1 OR
                   i_RKOJIN.KAI_SHIK_7 = 1 OR
                   i_RKOJIN.KAI_SHIK_8 = 1 OR
                   i_RKOJIN.KAI_SHIK_9 = 1 OR
                   i_RKOJIN.KAI_SHIK_10 = 1 OR
                   i_RKOJIN.KAI_SHIK_11 = 1 OR
                   i_RKOJIN.KAI_SHIK_12 = 1 OR
                   i_RKOJIN.KAI_SHIK_1 = 1 OR
                   i_RKOJIN.KAI_SHIK_2 = 1 OR
                   i_RKOJIN.KAI_SHIK_3 = 1 THEN
                    IF i_RKOJIN.NEW_KAI_SHIK_KBN IN (1, 2, 3) THEN  --実行時点で資格がある人のみ対象
                       NlShotokuKei := NlShotokuKei + i_RKOJIN.SHOTOKU;   --身障減免判定所得
                    END IF;
                    IF i_RKOJIN.CUST_1 = 1 THEN
                        NlShogai_CNT   := NlShogai_CNT + 1;        -- 身障対象人員
                    END IF;
                END IF;
            ELSE
                -- 賦課期日時点
                IF i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND i_RKOJIN.NEW_KAI_SHIK_KBN =1 THEN --最新介護区分(該当)
                    -- 所得合計
                    NlShotokuKei := NlShotokuKei + i_RKOJIN.SHOTOKU;
                    IF i_RKOJIN.CUST_1 = 1 THEN
                        NlShogai_CNT   := NlShogai_CNT + 1;        -- 身障対象人員
                    END IF;
                END IF;
            END IF;
        ELSE
            -- 身障減免無し
            NlShogai_CNT      := 0;
        END IF;

        -- ◆
        -- 通常課税計算
        IF (i_CAL_KBN = c_CAL_KBN_TU AND
            (i_RKOJIN.NEW_SHIK_KBN IN (1, 3, 7, 9) OR
             (i_RKOJIN.NEW_SHIK_KBN IN (2, 8) AND i_RKOJIN.SEKISAN_GAI_KBN = 1)) ) OR
        -- 賦課期日時点
           (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND
            i_RKOJIN.NEW_SHIK_KBN IN (1, 3) ) THEN

          -- ◆
          -- 通常課税計算
          IF (i_CAL_KBN = c_CAL_KBN_TU AND
              (i_RKOJIN.NEW_KAI_SHIK_KBN IN (0, 1) OR
               (i_RKOJIN.NEW_KAI_SHIK_KBN = 2 AND i_RKOJIN.SEKISAN_GAI_KBN = 1)) ) OR
          -- 賦課期日時点
             (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND
              i_RKOJIN.NEW_KAI_SHIK_KBN IN (1) ) THEN

                RlKIHON.KINTO_CNT := RlKIHON.KINTO_CNT + 1;                 -- 均等人員(基本)
                IF i_RKOJIN.NEW_SHITSU_KBN > 0 THEN
                  IF i_RKOJIN.SHITSU_KAHYO != 0 THEN
                      RlKIHON.YU_SHOTOKU_CNT := RlKIHON.YU_SHOTOKU_CNT + 1;             -- 有所得人員(基本)
                  END IF;
                  -- 月別資格区分初期化
                  FOR NwIx IN 1..12 LOOP
                      AlSHIK(NwIx) := 0;
                  END LOOP;
                  -- 月別失業区分初期化
                  FOR NwIx IN 1..12 LOOP
                      AlSHITSU(NwIx) := 0;
                  END LOOP;
                  -- ZLBTKOJIN_CALから月別資格区分をセット
                  AlSHIK(1)  := i_RKOJIN.SHIK_4;
                  AlSHIK(2)  := i_RKOJIN.SHIK_5;
                  AlSHIK(3)  := i_RKOJIN.SHIK_6;
                  AlSHIK(4)  := i_RKOJIN.SHIK_7;
                  AlSHIK(5)  := i_RKOJIN.SHIK_8;
                  AlSHIK(6)  := i_RKOJIN.SHIK_9;
                  AlSHIK(7)  := i_RKOJIN.SHIK_10;
                  AlSHIK(8)  := i_RKOJIN.SHIK_11;
                  AlSHIK(9)  := i_RKOJIN.SHIK_12;
                  AlSHIK(10) := i_RKOJIN.SHIK_1;
                  AlSHIK(11) := i_RKOJIN.SHIK_2;
                  AlSHIK(12) := i_RKOJIN.SHIK_3;
                  -- ZLBTKOJIN_CALから月別失業区分をセット
                  AlSHITSU(1)  := i_RKOJIN.SHITSU_4;
                  AlSHITSU(2)  := i_RKOJIN.SHITSU_5;
                  AlSHITSU(3)  := i_RKOJIN.SHITSU_6;
                  AlSHITSU(4)  := i_RKOJIN.SHITSU_7;
                  AlSHITSU(5)  := i_RKOJIN.SHITSU_8;
                  AlSHITSU(6)  := i_RKOJIN.SHITSU_9;
                  AlSHITSU(7)  := i_RKOJIN.SHITSU_10;
                  AlSHITSU(8)  := i_RKOJIN.SHITSU_11;
                  AlSHITSU(9)  := i_RKOJIN.SHITSU_12;
                  AlSHITSU(10) := i_RKOJIN.SHITSU_1;
                  AlSHITSU(11) := i_RKOJIN.SHITSU_2;
                  AlSHITSU(12) := i_RKOJIN.SHITSU_3;
                  NSHITSU_KBN := 0;
                  -- 失業軽減対象かどうか判定
                  FOR NwIx IN 1..12 LOOP
                    IF AlSHITSU(NwIx) = 1 THEN
                      NSHITSU_KBN := 1;
                    END IF;
                  END LOOP;
                  FOR NwIx IN 1..12 LOOP
                    IF NSHITSU_KBN = 1 AND AlSHITSU(NwIx) = 0 THEN
                      -- 月別資格区分＝資格無しの場合、月別失業区分＝資格有りとする
                      IF AlSHIK(NwIx) NOT IN (1,3,11,13) THEN
                        AlSHITSU(NwIx) := 1;
                      END IF;
                    END IF;
                  END LOOP;
                  -- 失業該当月数、失業非該当月数のカウント
                  FOR NwIx IN 1..12 LOOP
                    IF AlSHITSU(NwIx) > 0 THEN
                      IwCNT2 := IwCNT2 + 1;
                    ELSE
                      IwCNT1 := IwCNT1 + 1;
                    END IF;
                  END LOOP;
                  -- 失業軽減適用後所得額、失業軽減適用後課税標準額の算出
                  IF IwCNT2 > 0 THEN
                    -- 所得額
                    NwSHOTOKU := TRUNC((((i_RKOJIN.SHOTOKU       ) * IwCNT1) / 12) +
                                       (((i_RKOJIN.SHITSU_SHOTOKU) * IwCNT2) / 12));
                    -- 課税標準額
                    NwKAHYO   := TRUNC((((i_RKOJIN.KAHYO         ) * IwCNT1) / 12) +
                                       (((i_RKOJIN.SHITSU_KAHYO  ) * IwCNT2) / 12));
                  ELSE
                    -- 所得額
                    NwSHOTOKU := i_RKOJIN.SHOTOKU;
                    -- 課税標準額
                    NwKAHYO   := i_RKOJIN.KAHYO;
                  END IF;
                  RlKIHON.SHOTOKU      := RlKIHON.SHOTOKU + NwSHOTOKU;    -- 所得額(基本)
                  RlKIHON.KAHYO        := RlKIHON.KAHYO   + NwKAHYO;      -- 課税標準額(基本)
                ELSE
                IF i_RKOJIN.KAHYO != 0 THEN
                    RlKIHON.YU_SHOTOKU_CNT := RlKIHON.YU_SHOTOKU_CNT + 1;   -- 有所得人員(基本)
                END IF;
                RlKIHON.SHOTOKU      := RlKIHON.SHOTOKU + i_RKOJIN.SHOTOKU;         -- 所得額(基本)
                RlKIHON.KAHYO        := RlKIHON.KAHYO + i_RKOJIN.KAHYO;             -- 課税標準額(基本)
                END IF;
                RlKIHON.SHOTOKU_WARI := RlKIHON.SHOTOKU_WARI + i_RKOJIN.KAI_SHOTOKU_WARI;
                                                                                    -- 所得割額(基本)
                RlKIHON.SHISANZEI    := RlKIHON.SHISANZEI + i_RKOJIN.SHISANZEI;     -- 資産税額(基本)
                RlKIHON.SHISAN_WARI  := RlKIHON.SHISAN_WARI + i_RKOJIN.KAI_SHISAN_WARI;
                                                                                    -- 資産割額(基本)

            IF i_RKOJIN.KAI_SHIK_4  IN (1) OR i_RKOJIN.KAI_SHIK_5  IN (1) OR
               i_RKOJIN.KAI_SHIK_6  IN (1) OR i_RKOJIN.KAI_SHIK_7  IN (1) OR
               i_RKOJIN.KAI_SHIK_8  IN (1) OR i_RKOJIN.KAI_SHIK_9  IN (1) OR
               i_RKOJIN.KAI_SHIK_10 IN (1) OR i_RKOJIN.KAI_SHIK_11 IN (1) OR
               i_RKOJIN.KAI_SHIK_12 IN (1) OR i_RKOJIN.KAI_SHIK_1  IN (1) OR
               i_RKOJIN.KAI_SHIK_2  IN (1) OR i_RKOJIN.KAI_SHIK_3  IN (1) THEN
              IKINTO_CNT_20010     := IKINTO_CNT_20010 + 1;
              N_K_SHOTOKU_WARI_20010  := N_K_SHOTOKU_WARI_20010 + i_RKOJIN.KAI_SHOTOKU_WARI;
              N_K_SHISAN_WARI_20010   := N_K_SHISAN_WARI_20010  + i_RKOJIN.KAI_SHISAN_WARI;
            END IF;


                IF i_NJIKKOU_KBN != c_NTEST AND         -- 賦課試算時は算出しない
                  (i_RKOJIN.SHIK_4  IN (11, 13) OR i_RKOJIN.SHIK_5  IN (11, 13) OR
                   i_RKOJIN.SHIK_6  IN (11, 13) OR i_RKOJIN.SHIK_7  IN (11, 13) OR
                   i_RKOJIN.SHIK_8  IN (11, 13) OR i_RKOJIN.SHIK_9  IN (11, 13) OR
                   i_RKOJIN.SHIK_10 IN (11, 13) OR i_RKOJIN.SHIK_11 IN (11, 13) OR
                   i_RKOJIN.SHIK_12 IN (11, 13) OR i_RKOJIN.SHIK_1  IN (11, 13) OR
                   i_RKOJIN.SHIK_2  IN (11, 13) OR i_RKOJIN.SHIK_3  IN (11, 13)) THEN

                    IF i_RKOJIN.NEW_SHITSU_KBN > 0 THEN
                      IF IwCNT2 > 0 THEN
                        -- 所得額
                        NwKEIGEN_SHOTOKU := TRUNC((((i_RKOJIN.KEIGEN_SHOTOKU       ) * IwCNT1) / 12) +
                                                  (((i_RKOJIN.SHITSU_KEIGEN_SHOTOKU) * IwCNT2) / 12));
                        RlTAI.KEIGEN_SHOTOKU := RlTAI.KEIGEN_SHOTOKU + NwKEIGEN_SHOTOKU;  -- 軽減判定所得(退職)
                      END IF;
                      RlTAI.KINTO_CNT      := RlTAI.KINTO_CNT + 1;                      -- 均等人員(退職)
                      IF i_RKOJIN.SHITSU_KAHYO != 0 THEN
                          RlTAI.YU_SHOTOKU_CNT := RlTAI.YU_SHOTOKU_CNT + 1;             -- 有所得人員(退職)
                      END IF;
                      RlTAI.SHOTOKU      := RlTAI.SHOTOKU + NwSHOTOKU;    -- 所得額(基本)
                      RlTAI.KAHYO        := RlTAI.KAHYO   + NwKAHYO;      -- 課税標準額(基本)
                    ELSE
                    RlTAI.KEIGEN_SHOTOKU := RlTAI.KEIGEN_SHOTOKU
                                          + i_RKOJIN.KEIGEN_SHOTOKU;        -- 軽減判定所得(退職)
                    RlTAI.KINTO_CNT      := RlTAI.KINTO_CNT + 1;            -- 均等人員(退職)
                    IF i_RKOJIN.KAHYO != 0 THEN
                        RlTAI.YU_SHOTOKU_CNT := RlTAI.YU_SHOTOKU_CNT + 1;   -- 有所得人員(退職)
                    END IF;
                    RlTAI.SHOTOKU      := RlTAI.SHOTOKU + i_RKOJIN.SHOTOKU;         -- 所得額(退職)
                    RlTAI.KAHYO        := RlTAI.KAHYO + i_RKOJIN.KAHYO;             -- 課税標準額(退職)
                    END IF;
                    RlTAI.SHOTOKU_WARI := RlTAI.SHOTOKU_WARI + i_RKOJIN.KAI_SHOTOKU_WARI;
                                                                                    --所得割額(退職)
                    RlTAI.SHISANZEI    := RlTAI.SHISANZEI + i_RKOJIN.SHISANZEI;     -- 資産税額(退職)
                    RlTAI.SHISAN_WARI  := RlTAI.SHISAN_WARI + i_RKOJIN.KAI_SHISAN_WARI;
                                                                                    -- 資産割額(退職)

                END IF;
            END IF;
        END IF;

        IF i_RKOJIN.NEW_SHIK_KBN IN (1, 3) THEN
            IF i_RKOJIN.NEW_KAI_SHIK_KBN = 1 THEN
                RlKIHON.GENZAI_CNT := RlKIHON.GENZAI_CNT + 1;       -- 現在人員(基本)
                IF i_NJIKKOU_KBN != c_NTEST AND         -- 賦課試算時は算出しない
                   i_RKOJIN.NEW_TAI_KBN IN (1, 2) THEN
                    RlTAI.GENZAI_CNT := RlTAI.GENZAI_CNT + 1;       -- 現在人員(退職)
                END IF;
            END IF;
        END IF;

    END subSekisanMae;
-------------------------------------------------------------------------------
-- 02 条件読込み
-------------------------------------------------------------------------------
    PROCEDURE subJokenSel IS

      TYPE MT_JOKEN IS RECORD(  GENDOGAKU_KAI       ZLBTJOKEN.GENDOGAKU_KAI%TYPE,
                                KINTO_KAI           ZLBTJOKEN.KINTO_KAI%TYPE,
                                BYODO_KAI           ZLBTJOKEN.BYODO_KAI%TYPE,
                                KEIGEN_1            ZLBTJOKEN.KEIGEN_1%TYPE,
                                KINGE_KAI_1         ZLBTJOKEN.KINGE_KAI_1%TYPE,
                                BYGE_KAI_1          ZLBTJOKEN.BYGE_KAI_1%TYPE,
                                KEIGEN_2            ZLBTJOKEN.KEIGEN_2%TYPE,
                                KINGE_KAI_2         ZLBTJOKEN.KINGE_KAI_2%TYPE,
                                BYGE_KAI_2          ZLBTJOKEN.BYGE_KAI_2%TYPE,
                                KEIGEN_3            ZLBTJOKEN.KEIGEN_3%TYPE,
                                KINGE_KAI_3         ZLBTJOKEN.KINGE_KAI_3%TYPE,
                                BYGE_KAI_3          ZLBTJOKEN.BYGE_KAI_3%TYPE,
                                HASU_KAI            ZLBTJOKEN.HASU_KAI%TYPE,
                                NUSHI_KAZEI         ZLBTJOKEN.NUSHI_KAZEI%TYPE,
                                NENREI_KEIGEN       ZLBTJOKEN.NENREI_KEIGEN%TYPE,
                                SINSHO_GENMEN       ZLBTJOKEN.SINSHO_GENMEN%TYPE,
                                GENMENRITU_KEISAN   ZLBTJOKEN.GENMENRITU_KEISAN%TYPE,
                                SHOTOKU_2DANKAI     ZLBTJOKEN.SHOTOKU_2DANKAI%TYPE,
                                SHOTOKU_HANTEI_GAKU ZLBTJOKEN.SHOTOKU_HANTEI_GAKU%TYPE,
                                SHOTOKU_KAI_OVER    ZLBTJOKEN.SHOTOKU_KAI_OVER%TYPE,
                                SHOTOKU_KAI         ZLBTJOKEN.SHOTOKU_KAI%TYPE,
                                SHISAN_KAI          ZLBTJOKEN.SHISAN_KAI%TYPE,
                                FUKI_KAZEI          ZLBTJOKEN.FUKI_KAZEI%TYPE
                              );
      RwJOKEN         MT_JOKEN;

    BEGIN
        -- 市町村コードの取得
        IF NlRTN = c_NOK THEN
          BEGIN
            SELECT NVL(SHICHOSON_CD, 0) INTO ISHICHOSON_CD  --市町村コード
            FROM KHSTJOKEN
            WHERE ROWNUM = 1;
          EXCEPTION
            WHEN OTHERS THEN
              NlRTN := c_NERR; -- 異常終了
              VlMSG := 'KHSTJOKEN ' || SQLERRM || ')';
          END;
        END IF;

        -- 算定団体コード=1でシステム条件を取得
        IF i_NJIKKOU_KBN  <>  c_NBATCH_ZER THEN
              SELECT  GENDOGAKU_KAI      ,KINTO_KAI          ,BYODO_KAI          ,
                  KEIGEN_1           ,KINGE_KAI_1        ,BYGE_KAI_1         ,
                  KEIGEN_2           ,KINGE_KAI_2        ,BYGE_KAI_2         ,
                  KEIGEN_3           ,KINGE_KAI_3        ,BYGE_KAI_3         ,
                  HASU_KAI           ,NUSHI_KAZEI        ,NENREI_KEIGEN      ,
                  SINSHO_GENMEN      ,GENMENRITU_KEISAN  ,SHOTOKU_2DANKAI    ,
                  SHOTOKU_HANTEI_GAKU,SHOTOKU_KAI_OVER   ,SHOTOKU_KAI        ,
                  SHISAN_KAI         ,FUKI_KAZEI
          INTO    RwJOKEN
          FROM    ZLBTJOKEN
           WHERE NENDO           = i_NNENDO_BUN
             AND SANTEIDANTAI_CD = c_NDANTAI;
        ELSE
          SELECT  GENDOGAKU_KAI      ,KINTO_KAI          ,BYODO_KAI          ,
                  KEIGEN_1           ,KINGE_KAI_1        ,BYGE_KAI_1         ,
                  KEIGEN_2           ,KINGE_KAI_2        ,BYGE_KAI_2         ,
                  KEIGEN_3           ,KINGE_KAI_3        ,BYGE_KAI_3         ,
                  HASU_KAI           ,NUSHI_KAZEI        ,NENREI_KEIGEN      ,
                  SINSHO_GENMEN      ,GENMENRITU_KEISAN  ,SHOTOKU_2DANKAI    ,
                  SHOTOKU_HANTEI_GAKU,SHOTOKU_KAI_OVER   ,SHOTOKU_KAI        ,
                  SHISAN_KAI         ,FUKI_KAZEI
          INTO    RwJOKEN
          FROM    ZLBTJOKEN_ZER
           WHERE NENDO           = i_NNENDO_BUN
             AND SANTEIDANTAI_CD = c_NDANTAI;
        END IF;

        -- 不均一課税を行なうか否か判定
        IF RwJOKEN.FUKI_KAZEI = c_NFKAZEI THEN
            -- 不均一課税を行なう

            -- 算定団体コード=パラメータの算定団体コードでシステム条件を再取得
            IF i_NJIKKOU_KBN  <>  c_NBATCH_ZER THEN
              SELECT  GENDOGAKU_KAI      ,KINTO_KAI          ,BYODO_KAI          ,
                      KEIGEN_1           ,KINGE_KAI_1        ,BYGE_KAI_1         ,
                      KEIGEN_2           ,KINGE_KAI_2        ,BYGE_KAI_2         ,
                      KEIGEN_3           ,KINGE_KAI_3        ,BYGE_KAI_3         ,
                      HASU_KAI           ,NUSHI_KAZEI        ,NENREI_KEIGEN      ,
                      SINSHO_GENMEN      ,GENMENRITU_KEISAN  ,SHOTOKU_2DANKAI    ,
                      SHOTOKU_HANTEI_GAKU,SHOTOKU_KAI_OVER   ,SHOTOKU_KAI        ,
                      SHISAN_KAI         ,FUKI_KAZEI
              INTO    RwJOKEN
              FROM    ZLBTJOKEN
               WHERE NENDO           = i_NNENDO_BUN
                 AND SANTEIDANTAI_CD = i_NDANTAI;
            ELSE
              SELECT  GENDOGAKU_KAI      ,KINTO_KAI          ,BYODO_KAI          ,
                      KEIGEN_1           ,KINGE_KAI_1        ,BYGE_KAI_1         ,
                      KEIGEN_2           ,KINGE_KAI_2        ,BYGE_KAI_2         ,
                      KEIGEN_3           ,KINGE_KAI_3        ,BYGE_KAI_3         ,
                      HASU_KAI           ,NUSHI_KAZEI        ,NENREI_KEIGEN      ,
                      SINSHO_GENMEN      ,GENMENRITU_KEISAN  ,SHOTOKU_2DANKAI    ,
                      SHOTOKU_HANTEI_GAKU,SHOTOKU_KAI_OVER   ,SHOTOKU_KAI        ,
                      SHISAN_KAI         ,FUKI_KAZEI
              INTO    RwJOKEN
              FROM    ZLBTJOKEN_ZER
               WHERE NENDO           = i_NNENDO_BUN
                 AND SANTEIDANTAI_CD = i_NDANTAI;
            END IF;

        END IF;

        -- 作業用エリアに保持
        NlJGENDOGAKU := RwJOKEN.GENDOGAKU_KAI;          -- 限度額
        NlJKINTO     := RwJOKEN.KINTO_KAI;              -- 均等割額
        NlJBYODO     := RwJOKEN.BYODO_KAI;              -- 平等割額
        NlJKEIGEN1   := RwJOKEN.KEIGEN_1;               -- 軽減区分1(6,7割)
        NlJKGEN1     := RwJOKEN.KINGE_KAI_1;            -- 軽減均等割1(6,7割)
        NlJBGEN1     := RwJOKEN.BYGE_KAI_1;             -- 軽減平等割1(6,7割)
        NlJKEIGEN2   := RwJOKEN.KEIGEN_2;               -- 軽減区分2(4,5割)
        NlJKGEN2     := RwJOKEN.KINGE_KAI_2;            -- 軽減均等割2(4,5割)
        NlJBGEN2     := RwJOKEN.BYGE_KAI_2;             -- 軽減平等割2(4,5割)
        NlJKEIGEN3   := RwJOKEN.KEIGEN_3;               -- 軽減区分3(2割)
        NlJKGEN3     := RwJOKEN.KINGE_KAI_3;            -- 軽減均等割3(2割)
        NlJBGEN3     := RwJOKEN.BYGE_KAI_3;             -- 軽減平等割3(2割)
        NlJHASU      := RwJOKEN.HASU_KAI;               -- 端数
        NlJNUSHI     := RwJOKEN.NUSHI_KAZEI;            --主課税条件
        NlNENREI_KEIGEN   := RwJOKEN.NENREI_KEIGEN;     -- 年齢軽減
        NlSINSHO_GENMEN   := RwJOKEN.SINSHO_GENMEN;     -- 身障減免
        NlGENMENRITU      := RwJOKEN.GENMENRITU_KEISAN; -- 減免率計算
        NSHOTOKU_2DANKAI     := RwJOKEN.SHOTOKU_2DANKAI;     --所得２段階
        NSHOTOKU_HANTEI_GAKU := RwJOKEN.SHOTOKU_HANTEI_GAKU; --所得割判定額
        NSHOTOKU_KAI_OVER    := RwJOKEN.SHOTOKU_KAI_OVER;    --所得割率
        NSHOTOKU_KAI         := RwJOKEN.SHOTOKU_KAI;         --所得割率２
        NSHISAN_KAI          := RwJOKEN.SHISAN_KAI;          --介護資産割率

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subJokenSel システム条件取得(国保世帯番号='||
                     i_NSETAI||')'||SQLERRM;
    END subJokenSel;

-------------------------------------------------------------------------------
-- xx 上伊那対応(減免対応)
-------------------------------------------------------------------------------
    PROCEDURE funcSetGenmen_20010 IS
      wiGENMEN_RITU   NUMBER(5,2) := 0;
      wiCNT           NUMBER := 1;
    BEGIN
      wiCNT := 1;
      N_INA_TAISHO := 0;
      N_INA_GENMEN := 0;
      N_INA_GENMEN_GAKU_K := 0;
      N_INA_GENMEN_GAKU_T := 0;
      N_INA_GENMEN_RITU := 0;


      -- 対象世帯抽出（対象者は軽減申請テーブルに格納)
      -- SHINSEI_KBN 0:高遠市, 1:長谷村
      BEGIN
        SELECT NVL(SHINSEI_KBN,0) INTO N_INA_TAISHO
          FROM ZLBTKEIGEN
         WHERE NENDO = RlKIHON.NENDO_BUN
           AND KOKU_SETAI_NO = RlKIHON.KOKU_SETAI_NO;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
            wiCNT := 0;
        WHEN OTHERS THEN
            wiCNT := 0;
            NlRTN := c_NERR;
            VlMSG := 'funcSetGenmen_20010 上伊那減免対応(国保世帯番号='||RlKIHON.KOKU_SETAI_NO||')'||SQLERRM;
      END;

      -- 対象者のみ減免対応
      IF wiCNT > 0 THEN
        N_INA_GENMEN := 1;

        -- 現状は、固定値にて減免率を設定
        IF N_INA_TAISHO = 0 THEN
          -- 高遠市
          IF RlKIHON.NENDO_BUN = 2006 THEN
            wiGENMEN_RITU := 0.70;
          ELSIF RlKIHON.NENDO_BUN = 2007 THEN
            wiGENMEN_RITU := 0.76;
          ELSIF RlKIHON.NENDO_BUN = 2008 THEN
            wiGENMEN_RITU := 0.82;
          ELSIF RlKIHON.NENDO_BUN = 2009 THEN
            wiGENMEN_RITU := 0.88;
          ELSIF RlKIHON.NENDO_BUN = 2010 THEN
            wiGENMEN_RITU := 0.94;
          ELSE
            wiGENMEN_RITU := 1.00;
          END IF;
        ELSE
          -- 長谷村
          IF RlKIHON.NENDO_BUN = 2006 THEN
            wiGENMEN_RITU := 0.80;
          ELSIF RlKIHON.NENDO_BUN = 2007 THEN
            wiGENMEN_RITU := 0.84;
          ELSIF RlKIHON.NENDO_BUN = 2008 THEN
            wiGENMEN_RITU := 0.88;
          ELSIF RlKIHON.NENDO_BUN = 2009 THEN
            wiGENMEN_RITU := 0.82;
          ELSIF RlKIHON.NENDO_BUN = 2010 THEN
            wiGENMEN_RITU := 0.86;
          ELSE
            wiGENMEN_RITU := 1.00;
          END IF;
        END IF;

        N_INA_GENMEN_RITU := wiGENMEN_RITU;

        -- 全体分
        -- 減免額の算出

        --退職区分
        -- 減免額の算出
      END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'funcSetGenmen_20010 上伊那減免対応(国保世帯番号='||RlKIHON.KOKU_SETAI_NO||')'||SQLERRM;
    END funcSetGenmen_20010;

-------------------------------------------------------------------------------
-- xx 上伊那対応(減免対応)
-------------------------------------------------------------------------------
    PROCEDURE funcSetGengaku_20010 IS
      wiGENMEN_RITU   NUMBER(5,2) := 0;
      wlNENZEI        NUMBER := 0;
      wl_K_KEIGEN_K_WARI NUMBER := 0;
      wl_K_KEIGEN_B_WARI NUMBER := 0;
      wl_T_KEIGEN_K_WARI NUMBER := 0;
      wl_T_KEIGEN_B_WARI NUMBER := 0;
      wlHASU             NUMBER := 0;
    BEGIN
      RlKIHON.GENMEN := N_INA_GENMEN_GAKU_K;
      IF N_T_BYODO_WARI_20010 > 0 AND RlTAI.BYODO_WARI = 0 THEN
        N_INA_GENMEN_GAKU_T := N_INA_GENMEN_GAKU_T - N_T_BYODO_WARI_20010;
      END IF;
      RlTAI.GENMEN := N_INA_GENMEN_GAKU_T;

      wl_K_KEIGEN_K_WARI := N_K_KINTO_WARI_20010 * (RlKIHON_IRY.FUKA_KEIGEN_KBN * 0.1);
      wl_K_KEIGEN_B_WARI := N_K_BYODO_WARI_20010 * (RlKIHON_IRY.FUKA_KEIGEN_KBN * 0.1);
      wl_T_KEIGEN_K_WARI := RlTAI.KINTO_WARI * (RlKIHON_IRY.FUKA_KEIGEN_KBN * 0.1);
      wl_T_KEIGEN_B_WARI := N_T_BYODO_WARI_20010 * (RlKIHON_IRY.FUKA_KEIGEN_KBN * 0.1);

      -- 対象者のみ減免対応
      IF N_INA_GENMEN > 0 THEN
        -- 現状は、固定値にて減免率を設定
        IF N_INA_TAISHO = 0 THEN
          -- 高遠市
          IF RlKIHON.NENDO_BUN = 2006 THEN
            wiGENMEN_RITU := 0.70;
          ELSIF RlKIHON.NENDO_BUN = 2007 THEN
            wiGENMEN_RITU := 0.76;
          ELSIF RlKIHON.NENDO_BUN = 2008 THEN
            wiGENMEN_RITU := 0.82;
          ELSIF RlKIHON.NENDO_BUN = 2009 THEN
            wiGENMEN_RITU := 0.88;
          ELSIF RlKIHON.NENDO_BUN = 2010 THEN
            wiGENMEN_RITU := 0.94;
          ELSE
            wiGENMEN_RITU := 1.00;
          END IF;
        ELSE
          -- 長谷村
          IF RlKIHON.NENDO_BUN = 2006 THEN
            wiGENMEN_RITU := 0.80;
          ELSIF RlKIHON.NENDO_BUN = 2007 THEN
            wiGENMEN_RITU := 0.84;
          ELSIF RlKIHON.NENDO_BUN = 2008 THEN
            wiGENMEN_RITU := 0.88;
          ELSIF RlKIHON.NENDO_BUN = 2009 THEN
            wiGENMEN_RITU := 0.82;
          ELSIF RlKIHON.NENDO_BUN = 2010 THEN
            wiGENMEN_RITU := 0.86;
          ELSE
            wiGENMEN_RITU := 1.00;
          END IF;
        END IF;

        -- 全体分
        -- 仮年税額の算出
        wlNENZEI := TRUNC(((N_K_SHOTOKU_WARI_20010 + N_K_SHISAN_WARI_20010 + N_K_KINTO_WARI_20010 + N_K_BYODO_WARI_20010) - wl_K_KEIGEN_K_WARI - wl_K_KEIGEN_B_WARI) * wiGENMEN_RITU,-2);

        -- 限度超過額の比較
        RlKIHON.GENDO_CHOKA := 0;
        IF wlNENZEI > NlJGENDOGAKU THEN
          -- 限度超過の場合
          RlKIHON.GENDO_CHOKA := wlNENZEI - NlJGENDOGAKU;
          wlNENZEI := NlJGENDOGAKU;
        END IF;

        wlHASU := MOD(RlKIHON.SEKISAN - RlKIHON.GENDO_CHOKA
                                        - RlKIHON.KEIGEN_K_WARI
                                        - RlKIHON.KEIGEN_B_WARI
                                        - RlKIHON.GENMEN
                                        - RlEXT.KAI_NENREI_KEIGEN
                                        - RlEXT.KAI_SHOGAI_GENMEN
                                        - wlNENZEI,100);

        --退職区分
        NlCHOKA := 0;
        IF RlKIHON.GENDO_CHOKA > 0 THEN
          NlCHOKA := (NlJGENDOGAKU *
                     ((RlTAI.SHOTOKU_WARI + RlTAI.SHISAN_WARI + RlTAI.KINTO_WARI + N_T_BYODO_WARI_20010) - wl_T_KEIGEN_K_WARI - wl_T_KEIGEN_B_WARI - RlTAI.GENMEN) /
                     ((N_K_SHOTOKU_WARI_20010 + N_K_SHISAN_WARI_20010 + N_K_KINTO_WARI_20010 + N_K_BYODO_WARI_20010) - wl_K_KEIGEN_K_WARI - wl_K_KEIGEN_B_WARI - RlKIHON.GENMEN ));
        END IF;

        -- 仮年税額の算出
        wlNENZEI := TRUNC(((RlTAI.SHOTOKU_WARI + RlTAI.SHISAN_WARI + RlTAI.KINTO_WARI + N_T_BYODO_WARI_20010) - wl_T_KEIGEN_K_WARI - wl_T_KEIGEN_B_WARI) * wiGENMEN_RITU,-2);

        -- 限度超過額の比較
        RlTAI.GENDO_CHOKA := 0;
        IF NlCHOKA > 0 THEN
          -- 限度超過の場合
          RlTAI.GENDO_CHOKA := wlNENZEI - NlCHOKA;
        END IF;
        RlTAI.HASU := wlHASU;
      END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'funcSetGengaku_20010 上伊那減額対応(国保世帯番号='||RlKIHON.KOKU_SETAI_NO||')'||SQLERRM;
    END funcSetGengaku_20010;

-------------------------------------------------------------------------------
-- 01 初期化
-------------------------------------------------------------------------------
    PROCEDURE subInit IS
        NwIX            NUMBER(2);
    BEGIN

        -- 出力用ワーククリア
        subOutInit;                         -- 11 計算個人0件時セット

        -- 計算用ワーククリア
        NlKOJIN_CNT         := 0;                   -- 計算個人件数
        NlMAX_TODOKEDE_BI   := 0;                   -- 最大届出日
        NlMAX_JIYU          := 0;                   -- 最大事由
        NlGENZON_KBN        := 1;                   -- 現存区分
        NlGISEI_KBN         := 0;                   -- 擬制区分
        NlSHOTOKU           := c_NSHOTOKU_LOW;      -- 所得
        NlROJIN             := 0;                   -- 老人数
        NlSENJU             := 0;                   -- 専従区分
        NlJOTO_KBN          := 0;                   -- 譲渡区分
        NlKAZEI_KBN         := 1;                   -- 課税区分
        NlMI_SHINKOKU_KBN   := 0;                   -- 未申告区分
        NlCHOKA             := 0;                   -- 超過
        NlKEIGEN_KINTO      := 0;                   -- 軽減均等
        NlKEIGEN_BYODO      := 0;                   -- 軽減平等
        NlKEIGEN_K_6_ZEN    := 0;                   -- 軽減均等6 全体
        NlKEIGEN_B_6_ZEN    := 0;                   -- 軽減平等6 全体
        NlKEIGEN_K_4_ZEN    := 0;                   -- 軽減均等4 全体
        NlKEIGEN_B_4_ZEN    := 0;                   -- 軽減平等4 全体
        NlKEIGEN_K_2_ZEN    := 0;                   -- 軽減均等2 全体
        NlKEIGEN_B_2_ZEN    := 0;                   -- 軽減平等2 全体
        NlKEIGEN_K_6_TAI    := 0;                   -- 軽減均等6 退職
        NlKEIGEN_B_6_TAI    := 0;                   -- 軽減平等6 退職
        NlKEIGEN_K_4_TAI    := 0;                   -- 軽減均等4 退職
        NlKEIGEN_B_4_TAI    := 0;                   -- 軽減平等4 退職
        NlKEIGEN_K_2_TAI    := 0;                   -- 軽減均等2 退職
        NlKEIGEN_B_2_TAI    := 0;                   -- 軽減平等2 退職
        NlNENZEIGAKU        := 0;                   -- 年税額
        NlTAINENZEIGAKU     := 0;                   -- 退年税額
        NlSEISAN_KBN        := 0;                   -- 清算区分

        NlNENREI_KEIGEN     := 0;                   -- 年齢軽減
        NlSINSHO_GENMEN     := 0;                   -- 身障減免
        NlGENMENRITU        := 0;                   -- 減免率計算

        Nl22Ika_CNT         := 0;                   -- 22才以下人員
        Nl22IkaTai_CNT      := 0;                   -- 22才以下人員(退職)
        NlShotokuKei        := 0;                   -- 所得合計
        NlShogai_CNT        := 0;                   -- 身障対象人員

        FOR NwIX IN 1..12 LOOP
            MlSHIK_KBN(NwIX)    := 0;               -- 各月資格区分
            MlIRYSHIK_KBN(NwIX) := 0;               -- 各月資格区分(医療)
            MlSHITSU_KBN(NwIX)  := 0;               -- 各月失業資格区分
            MlCNT(NwIX)         := 0;               -- 人員(各月有資格者数)
            MlZEIGAKU(NwIX)     := 0;               -- 税額
            MlKEIGEN_KBN(NwIX)  := 0;               -- 各月軽減区分
            MlCHOKA_MAE(NwIX)   := 0;               -- 限度超過前
            MlSUMI(NwIX)        := 0;               -- 済
            MlTUKI(NwIX)        := 0;               -- 月数
            MlTAICNT(NwIX)      := 0;               -- 退人員(各月有資格者数)
            MlTAIZEIGAKU(NwIX)  := 0;               -- 退税額
            MlTAISUMI(NwIX)     := 0;               -- 退済
            MlTAITUKI(NwIX)     := 0;               -- 退月数
            MlKAHYO(NwIX)       := 0;               -- 課標
            MlTAIKAHYO(NwIX)    := 0;               -- 課標退職
            MlZEIGAKU_SEKI(NwIX):= 0;               -- 積算算出用 税額
            MlSUMI_SEKI(NwIX)   := 0;               -- 積算算出用 済
            MlTUKI_SEKI(NwIX)   := 0;               -- 積算算出用 月数
            MlCHOKA_SEKI(NwIX)  := 0;               -- 積算算出用 限度超過
            MlKAHYO_SEKI(NwIX)  := 0;               -- 積算算出用 課標
            MlNEN_CNT_SEKI(NwIX):= 0;               -- 積算算出用 年齢軽減人員(各月有資格者数)
            MlTAIZEIGAKU_SEKI(NwIX):= 0;            -- 積算算出用 退税額
            MlTAISUMI_SEKI(NwIX)   := 0;            -- 積算算出用 退済
            MlTAITUKI_SEKI(NwIX)   := 0;            -- 積算算出用 退月数
            MlTAICHOKA_SEKI(NwIX)  := 0;            -- 積算算出用 退限度超過
            MlTAIKAHYO_SEKI(NwIX)  := 0;            -- 積算算出用 退課標
            MlTAINEN_CNT_SEKI(NwIX):= 0;            -- 積算算出用 退年齢軽減人員(各月有資格者数)
            --  2024/05/06 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
            MlSAN_KBN(NwIX):= 0;
            MlSANCNT(NwIX):= 0;
            MlSANCNT_K(NwIX):= 0;
            --  2024/05/06 ZCZL.ZHANGLEI ADD END
        END LOOP;
        --応益係数
        NlPER(1)       := 50;
        NlPER(2)       := 70;
        NlPER(3)       := 90;
        NlPER(4)       := 100;

   IKINTO_CNT_20010     := 0;
   N_K_SHOTOKU_WARI_20010  := 0;
   N_K_SHISAN_WARI_20010   := 0;
   N_K_KINTO_WARI_20010    := 0;
   N_K_BYODO_WARI_20010    := 0;

    END subInit;
-------------------------------------------------------------------------------
-- 03.05 障害減免全喪
-------------------------------------------------------------------------------
    PROCEDURE subShogaiZenso IS
      CURSOR CKOJIN IS
        SELECT * FROM ZLBTKOJIN_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND TSUCHI_NO       = i_NNUSHI
           AND SYS_TANMATSU_NO = i_VTANMATSU
           AND NEW_SHIK_KBN   <> 5
         ORDER BY KAI_SHIK_3 DESC, KAI_SHIK_2 DESC, KAI_SHIK_1 DESC, KAI_SHIK_12 DESC, KAI_SHIK_11 DESC, KAI_SHIK_10 DESC,
                  KAI_SHIK_9 DESC, KAI_SHIK_8 DESC, KAI_SHIK_7 DESC, KAI_SHIK_6  DESC, KAI_SHIK_5  DESC, KAI_SHIK_4  DESC;

      VSHIK   NVARCHAR2(12);
      NSHIK   NUMBER(2) := 0;
    BEGIN
      IF RlKIHON.GENZAI_CNT = 0 AND NlShogai_CNT > 0 THEN
        FOR CRKOJIN IN CKOJIN LOOP
          VSHIK := CASE WHEN CRKOJIN.KAI_SHIK_3  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_2  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_1  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_12 > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_11 > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_10 > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_9  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_8  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_7  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_6  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_5  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.KAI_SHIK_4  > 0 THEN '1' ELSE '0' END;
          IF NSHIK = 0 THEN
            NSHIK := INSTR(VSHIK, '1');
          END IF;

          IF NSHIK = INSTR(VSHIK, '1') THEN
            NlShotokuKei := NlShotokuKei + CRKOJIN.SHOTOKU;
          ELSE
            EXIT;
          END IF;
        END LOOP;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NlRTN := c_NERR;
        VlMSG := '計算個人取得(国保世帯番号='||i_NSETAI||')'||SQLERRM;
    END;
-------------------------------------------------------------------------------
-- 世帯内に減免対象者がいるかチェックする。
-- 対象者がいる場合、減免額を算出するため、年税額の計算を２度行う。
-------------------------------------------------------------------------------
    FUNCTION funcGenmenKojinExistChk RETURN NUMBER IS
        nCNT      NUMBER;
        nRTN      NUMBER;
        nCNTG     NUMBER;
        NYUSEN_KBN  NUMBER(1) := -1;
        RwGENMEN_KOJIN  ZLBTGENMEN_KOJIN_TMP%ROWTYPE;    -- 減免個人TMP
        -- 減免個人TMP
        CURSOR CGENMEN_KJN IS
          SELECT * FROM ZLBTGENMEN_KOJIN_TMP
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND NENDO_BUN       = i_NNENDO_BUN
             AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND nCNTG = 0 AND KOJIN_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益のデータなしかつ市区町村条件92:1に設定時
                  OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND nCNTG > 0) --世帯主課税かつ優先区分0:個人/率/応能応益のデータありかつ市区町村条件92:1に設定時
                  OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                  OR (NlJNUSHI <> 1)
                  )
             AND SYS_TANMATSU_NO = i_VTANMATSU;
        -- ZLBTKOJIN_CALに存在してZLBTGENMEN_KOJIN_TMPに存在しないデータの個人番号を取得
        CURSOR CKOJIN IS
          SELECT DISTINCT KOJIN_NO
            FROM ZLBTKOJIN_CAL CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND NENDO_BUN       = i_NNENDO_BUN
             AND SYS_TANMATSU_NO = i_VTANMATSU
             AND NOT EXISTS (SELECT KOJIN_NO FROM ZLBTGENMEN_KOJIN_TMP
                              WHERE KOKU_SETAI_NO   = CAL.KOKU_SETAI_NO
                                AND SANTEIDANTAI_CD = CAL.SANTEIDANTAI_CD
                                AND KOJIN_NO        = CAL.KOJIN_NO
                                AND NENDO_BUN       = CAL.NENDO_BUN
                                AND SYS_TANMATSU_NO = CAL.SYS_TANMATSU_NO);

        --世帯主課税で減免計算世帯主課税が主変更後は非適用の場合は、世帯主番号もキー条件とする
        CURSOR CKOJIN2 IS
          SELECT DISTINCT KOJIN_NO
            FROM ZLBTKOJIN_CAL CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND NENDO_BUN       = i_NNENDO_BUN
             AND SYS_TANMATSU_NO = i_VTANMATSU
             AND TSUCHI_NO       = i_NNUSHI
             AND NOT EXISTS (SELECT KOJIN_NO FROM ZLBTGENMEN_KOJIN_TMP
                              WHERE KOKU_SETAI_NO   = CAL.KOKU_SETAI_NO
                                AND SANTEIDANTAI_CD = CAL.SANTEIDANTAI_CD
                                AND KOJIN_NO        = CAL.KOJIN_NO
                                AND NENDO_BUN       = CAL.NENDO_BUN
                                AND SYS_TANMATSU_NO = CAL.SYS_TANMATSU_NO
                                AND TSUCHI_NO       = CAL.TSUCHI_NO);

    BEGIN

        nRTN := 0;
        RlGENMEN_KOJIN  := NULL;

        -- ZLBTGENMEN_KOJIN テーブルの存在チェック
        nCNT := 1;
        -- ZLBTGENMEN_KOJIN 優先区分0:個人/率/応能応益のデータ存在チェック
        SELECT count(*) INTO nCNTG FROM ZLBTGENMEN_KOJIN
        WHERE YUSEN_KBN = 0
--2024/09/23 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00020
           --AND TEKIYO_KBN = 1
           AND TEKIYO_KBN IN (1, 3)
           AND KOKU_SETAI_NO = i_NSETAI
           AND NENDO_BUN =i_NNENDO_BUN;

        IF nCNT = 1 THEN

            OPEN cur_DynamicSQL FOR 'SELECT count(*)
                                     FROM ZLBTGENMEN_KOJIN_TMP
                                     WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                     AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                     AND   NENDO_BUN       = :NENDO_BUN
                                     AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO'
                                USING i_NSETAI, i_NDANTAI, i_NNENDO_BUN, i_VTANMATSU;

            FETCH cur_DynamicSQL INTO nCNT;
            CLOSE cur_DynamicSQL;

            -- 減免データあり
            IF nCNT > 0 THEN
                nRTN := 1;
                nCNT := 0;
                FOR CREC IN CGENMEN_KJN LOOP
                  nCNT := nCNT + 1;
                  --最初のデータの場合のみ退避
                  IF nCNT = 1 THEN
                    --優先区分の退避
                    NYUSEN_KBN                          := CREC.YUSEN_KBN;
                    RlGENMEN_KOJIN.YUSEN_KBN            := CREC.YUSEN_KBN;                --優先区分
                    RlGENMEN_KOJIN.K_BYODOWARI_RITSU    := CREC.K_BYODOWARI_RITSU;        --平等割減免率
                    RlGENMEN_KOJIN.K_GENMEN_4           := CREC.K_GENMEN_4;               --減免４月
                    RlGENMEN_KOJIN.K_GENMEN_5           := CREC.K_GENMEN_5;               --減免５月
                    RlGENMEN_KOJIN.K_GENMEN_6           := CREC.K_GENMEN_6;               --減免６月
                    RlGENMEN_KOJIN.K_GENMEN_7           := CREC.K_GENMEN_7;               --減免７月
                    RlGENMEN_KOJIN.K_GENMEN_8           := CREC.K_GENMEN_8;               --減免８月
                    RlGENMEN_KOJIN.K_GENMEN_9           := CREC.K_GENMEN_9;               --減免９月
                    RlGENMEN_KOJIN.K_GENMEN_10          := CREC.K_GENMEN_10;              --減免10月
                    RlGENMEN_KOJIN.K_GENMEN_11          := CREC.K_GENMEN_11;              --減免11月
                    RlGENMEN_KOJIN.K_GENMEN_12          := CREC.K_GENMEN_12;              --減免12月
                    RlGENMEN_KOJIN.K_GENMEN_1           := CREC.K_GENMEN_1;               --減免１月
                    RlGENMEN_KOJIN.K_GENMEN_2           := CREC.K_GENMEN_2;               --減免２月
                    RlGENMEN_KOJIN.K_GENMEN_3           := CREC.K_GENMEN_3;               --減免３月
                    RlGENMEN_KOJIN.K_SHOTOKU_GENGAKU    := CREC.K_SHOTOKU_GENGAKU;        --所得割減免額
                    RlGENMEN_KOJIN.K_SISANZEI_GENGAKU   := CREC.K_SISANZEI_GENGAKU;       --資産割減免額
                    RlGENMEN_KOJIN.K_KINTOWARI_GENGAKU  := CREC.K_KINTOWARI_GENGAKU;      --均等割減免額
                    RlGENMEN_KOJIN.K_BYODOWARI_GENGAKU  := CREC.K_BYODOWARI_GENGAKU;      --平等割減免額
                    RlGENMEN_KOJIN.KT_SHOTOKU_GENGAKU   := CREC.KT_SHOTOKU_GENGAKU;       --所得割減免額（退職）
                    RlGENMEN_KOJIN.KT_SISANZEI_GENGAKU  := CREC.KT_SISANZEI_GENGAKU;      --資産割減免額（退職）
                    RlGENMEN_KOJIN.KT_KINTOWARI_GENGAKU := CREC.KT_KINTOWARI_GENGAKU;     --均等割減免額（退職）
                    RlGENMEN_KOJIN.KT_BYODOWARI_GENGAKU := CREC.KT_BYODOWARI_GENGAKU;     --平等割減免額（退職）
                    RlGENMEN_KOJIN.K_NENZEI_RITSU       := CREC.K_NENZEI_RITSU;           --年税減免率
                    RlGENMEN_KOJIN.K_NENZEI_GENGAKU     := CREC.K_NENZEI_GENGAKU;         --年税減免額
                    RlGENMEN_KOJIN.KT_NENZEI_GENGAKU    := CREC.KT_NENZEI_GENGAKU;        --年税減免額（退職）
                    RlGENMEN_KOJIN.SHINSEI_BI           := CREC.SHINSEI_BI;               --申請日
                    RlGENMEN_KOJIN.K_SHOTOKU_RITSU      := CREC.K_SHOTOKU_RITSU;          --所得割減免率(介護)
                    RlGENMEN_KOJIN.K_SISANZEI_RITSU     := CREC.K_SISANZEI_RITSU;         --資産割減免率(介護)
                    RlGENMEN_KOJIN.K_KINTOWARI_RITSU    := CREC.K_KINTOWARI_RITSU;        --均等割減免率(介護)
                    RlGENMEN_KOJIN.KOKU_SETAI_NO        := CREC.KOKU_SETAI_NO;            --国保世帯番号
                    RlGENMEN_KOJIN.SANTEIDANTAI_CD      := CREC.SANTEIDANTAI_CD;          --算定団体コード
                    RlGENMEN_KOJIN.NENDO_BUN            := CREC.NENDO_BUN;                --年度分
                    RlGENMEN_KOJIN.KOJIN_NO             := CREC.KOJIN_NO;                 --個人番号
                    RlGENMEN_KOJIN.SYS_TANMATSU_NO      := CREC.SYS_TANMATSU_NO;          --更新端末番号
                  --減免有を優先でセット
                  ELSIF nCNT > 1 AND CREC.YUSEN_KBN = 0 THEN
                    IF CREC.K_GENMEN_4  = 1 THEN RlGENMEN_KOJIN.K_GENMEN_4  := 1; END IF; --減免４月
                    IF CREC.K_GENMEN_5  = 1 THEN RlGENMEN_KOJIN.K_GENMEN_5  := 1; END IF; --減免５月
                    IF CREC.K_GENMEN_6  = 1 THEN RlGENMEN_KOJIN.K_GENMEN_6  := 1; END IF; --減免６月
                    IF CREC.K_GENMEN_7  = 1 THEN RlGENMEN_KOJIN.K_GENMEN_7  := 1; END IF; --減免７月
                    IF CREC.K_GENMEN_8  = 1 THEN RlGENMEN_KOJIN.K_GENMEN_8  := 1; END IF; --減免８月
                    IF CREC.K_GENMEN_9  = 1 THEN RlGENMEN_KOJIN.K_GENMEN_9  := 1; END IF; --減免９月
                    IF CREC.K_GENMEN_10 = 1 THEN RlGENMEN_KOJIN.K_GENMEN_10 := 1; END IF; --減免10月
                    IF CREC.K_GENMEN_11 = 1 THEN RlGENMEN_KOJIN.K_GENMEN_11 := 1; END IF; --減免11月
                    IF CREC.K_GENMEN_12 = 1 THEN RlGENMEN_KOJIN.K_GENMEN_12 := 1; END IF; --減免12月
                    IF CREC.K_GENMEN_1  = 1 THEN RlGENMEN_KOJIN.K_GENMEN_1  := 1; END IF; --減免１月
                    IF CREC.K_GENMEN_2  = 1 THEN RlGENMEN_KOJIN.K_GENMEN_2  := 1; END IF; --減免２月
                    IF CREC.K_GENMEN_3  = 1 THEN RlGENMEN_KOJIN.K_GENMEN_3  := 1; END IF; --減免３月
                  END IF;
                END LOOP;
                --優先区分が「世帯／率／応能応益」の場合、ZLBTKOJIN_CALに存在してZLBTGENMEN_KOJIN_TMPに存在しない
                --個人番号のデータを、存在するZLBTGENMEN_KOJIN_TMPより世帯人数分コピーして作成
                IF NYUSEN_KBN = 1 THEN
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    --世帯主課税で減免計算世帯主課税が主変更後は非適用の場合は、世帯主番号もキー条件とする
                    --ZLBTGENMEN_KOJIN_TMPデータを１件読込む
                    BEGIN
                      SELECT * INTO RwGENMEN_KOJIN
                        FROM ZLBTGENMEN_KOJIN_TMP
                       WHERE KOKU_SETAI_NO   = i_NSETAI
                         AND SANTEIDANTAI_CD = i_NDANTAI
                         AND NENDO_BUN       = i_NNENDO_BUN
                         AND TSUCHI_NO       = i_NNUSHI
                         AND SYS_TANMATSU_NO = i_VTANMATSU
                         AND ROWNUM <= 1;
                      --ZLBTKOJIN_CALに存在してZLBTGENMEN_KOJIN_TMPに存在しないデータ分繰返す
                      FOR CREC IN CKOJIN2 LOOP
                        --個人番号をセット
                        RwGENMEN_KOJIN.KOJIN_NO := CREC.KOJIN_NO;
                        --ZLBTGENMEN_KOJIN_TMPにINSERT
                        INSERT INTO ZLBTGENMEN_KOJIN_TMP VALUES RwGENMEN_KOJIN;
                      END LOOP;
                    --世帯主課税で減免計算世帯主課税が主変更後は非適用の場合、世帯主変更前の世帯主が減免該当で
                    --世帯主変更後が減免非該当の場合、ZLBTGENMEN_KOJIN_TMPからデータ取得が出来なかった場合でも
                    --エラーとしない。
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                        nRTN := 0;
                        RlGENMEN_KOJIN  := NULL;
                        RETURN(nRTN);
                      WHEN OTHERS THEN
                        nRTN := 0;
                        RlGENMEN_KOJIN  := NULL;
                        RETURN(nRTN);
                    END;
                  ELSE
                    --ZLBTGENMEN_KOJIN_TMPデータを１件読込む
                    SELECT * INTO RwGENMEN_KOJIN
                      FROM ZLBTGENMEN_KOJIN_TMP
                     WHERE KOKU_SETAI_NO   = i_NSETAI
                       AND SANTEIDANTAI_CD = i_NDANTAI
                       AND NENDO_BUN       = i_NNENDO_BUN

                       AND SYS_TANMATSU_NO = i_VTANMATSU
                       AND ROWNUM <= 1;
                    --ZLBTKOJIN_CALに存在してZLBTGENMEN_KOJIN_TMPに存在しないデータ分繰返す
                    FOR CREC IN CKOJIN LOOP
                      --個人番号をセット
                      RwGENMEN_KOJIN.KOJIN_NO := CREC.KOJIN_NO;
                      --ZLBTGENMEN_KOJIN_TMPにINSERT
                      INSERT INTO ZLBTGENMEN_KOJIN_TMP VALUES RwGENMEN_KOJIN;
                    END LOOP;
                  END IF;
                END IF;
            END IF;

        END IF;

        RETURN(nRTN);

    EXCEPTION
        WHEN OTHERS THEN
          IF cur_DynamicSQL%ISOPEN THEN
             CLOSE cur_DynamicSQL;
          END IF;
            NlRTN := c_NERR;
            VlMSG := '減免個人 初期処理(国保世帯番号='||i_NSETAI||')'||SQLERRM;
            RETURN(nRTN);
    END;
-------------------------------------------------------------------------------
-- 当該年度の減免データが作成されているかチェックする。
-- １件も作成されていない場合、減免世帯を使用していない市町村と判断する。
-------------------------------------------------------------------------------
    FUNCTION funcGenmenSetaiUseChk RETURN NUMBER IS
        nCNT      NUMBER;
        nRTN      NUMBER;
    BEGIN

        nRTN := 0;

        -- ZLBTGENMEN_SETAI テーブルの存在チェック
        nCNT := 1;

        IF nCNT = 1 THEN

            OPEN cur_DynamicSQL FOR 'SELECT count(*)
                                     FROM ZLBTGENMEN_SETAI
                                     WHERE NENDO_BUN       = :NENDO_BUN'
                                USING i_NNENDO_BUN;

            FETCH cur_DynamicSQL INTO nCNT;
            CLOSE cur_DynamicSQL;

            -- 減免データあり
            IF nCNT > 0 THEN

                nRTN := 1;

            END IF;

        END IF;

        RETURN(nRTN);

    EXCEPTION
        WHEN OTHERS THEN
          IF cur_DynamicSQL%ISOPEN THEN
            CLOSE cur_DynamicSQL;
         END IF;
            NlRTN := c_NERR;
            VlMSG := '減免世帯 当該年度データ存在チェック(国保世帯番号='||i_NNENDO||')'||SQLERRM;
            RETURN(nRTN);
    END;
-------------------------------------------------------------------------------
-- 当該年度の減免データが作成されているかチェックする。
-- １件も作成されていない場合、減免個人を使用していない市町村と判断する。
-------------------------------------------------------------------------------
    FUNCTION funcGenmenKojinUseChk RETURN NUMBER IS
        nCNT      NUMBER;
        nRTN      NUMBER;
    BEGIN

        nRTN := 0;

        -- ZLBTGENMEN_KOJIN テーブルの存在チェック
        nCNT := 1;
        IF nCNT = 1 THEN

            OPEN cur_DynamicSQL FOR 'SELECT count(*)
                                     FROM ZLBTGENMEN_KOJIN
                                     WHERE NENDO_BUN       = :NENDO_BUN'
                                USING i_NNENDO_BUN;

            FETCH cur_DynamicSQL INTO nCNT;
            CLOSE cur_DynamicSQL;

            -- 減免データあり
            IF nCNT > 0 THEN

                nRTN := 1;

            END IF;

        END IF;

        RETURN(nRTN);

    EXCEPTION
        WHEN OTHERS THEN
          IF cur_DynamicSQL%ISOPEN THEN
             CLOSE cur_DynamicSQL;
          END IF;
            NlRTN := c_NERR;
            VlMSG := '減免個人 当該年度データ存在チェック(国保世帯番号='||i_NNENDO||')'||SQLERRM;
            RETURN(nRTN);
    END;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
PROCEDURE subGenmenChosi IS
  NSAGAKU   NUMBER := 0;
  BEGIN

    IF RlTAI.GENMEN > RlKIHON.GENMEN THEN
      NSAGAKU := RlTAI.GENMEN - RlKIHON.GENMEN;
      RlKIHON.GENMEN := RlTAI.GENMEN; -- 全体を退職にあわせる。
      --月割減額と減額計を調整する。
      RlKIHON.TSUKIWARI_GEN := RlKIHON.TSUKIWARI_GEN - NSAGAKU;
      RlKIHON.GENGAKU_KEI := RlKIHON.GENGAKU_KEI - NSAGAKU;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      NlRTN := c_NERR;
      VlMSG := '減免誤差調整 介護(国保世帯番号='||i_NSETAI||')'||SQLERRM;
END;
-------------------------------------------------------------------------------
-- 独自減免
-------------------------------------------------------------------------------
PROCEDURE subGenmenDokuji IS
  BEGIN
        -- 所得割減免額
        NSHOTOKU_GENGAKU := TRUNC (NKANYUKI / 12 * RlKIHON.SHOTOKU_WARI  * (NVL (RlGENMEN_KOJIN.K_SHOTOKU_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        --資産割減免額
        NSISANZEI_GENGAKU := TRUNC (NKANYUKI / 12 * RlKIHON.SHISAN_WARI  * (NVL (RlGENMEN_KOJIN.K_SISANZEI_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        --均等割減免額
        NKINTOWARI_GENGAKU := TRUNC (NKANYUKI / 12 * (RlKIHON.KINTO_WARI - RlKIHON.KEIGEN_K_WARI)  * (NVL (RlGENMEN_KOJIN.K_KINTOWARI_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        --均等割減免額
        NBYODOWARI_GENGAKU := TRUNC (NKANYUKI / 12 * (RlKIHON.BYODO_WARI - RlKIHON.KEIGEN_B_WARI)  * (NVL (RlGENMEN_KOJIN.K_BYODOWARI_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        -- 減免額合計の再セット
        UPDATE ZLBTGENMEN_KOJIN_CAL
        SET K_SHOTOKU_GENGAKU = NSHOTOKU_GENGAKU,
            K_SISANZEI_GENGAKU = NSISANZEI_GENGAKU,
            K_KINTOWARI_GENGAKU = NKINTOWARI_GENGAKU,
            K_BYODOWARI_GENGAKU = NBYODOWARI_GENGAKU,
            K_GENGAKU_KEI = NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU + NBYODOWARI_GENGAKU,
            K_GENGAKU = NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU + NBYODOWARI_GENGAKU,
            K_GENGAKU_MAE = RlKIHON.SEKISAN,
            K_SHOTOKU_KISO = RlKIHON.SHOTOKU_WARI,
            K_SISANZEI_KISO = RlKIHON.SHISAN_WARI,
            K_KINTOWARI_KISO = RlKIHON.KINTO_WARI,
            K_BYODOWARI_KISO = RlKIHON.BYODO_WARI,
            K_NENZEI_KISO = RlKIHON.SEKISAN - RlKIHON.GENGAKU_KEI - (NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU + NBYODOWARI_GENGAKU)
        WHERE  KOKU_SETAI_NO   = i_NSETAI
          AND  SANTEIDANTAI_CD = i_NDANTAI
          AND  NENDO_BUN       = i_NNENDO_BUN
          AND  SYS_TANMATSU_NO = i_VTANMATSU;
        --端数再計算
        NwNENZEIGAKU := RlKIHON.SEKISAN - RlKIHON.GENGAKU_KEI - (NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU + NBYODOWARI_GENGAKU) + RlKIHON.HASU;
        NwHASU       := RlKIHON.HASU;
        IF NlJHASU = c_NHASU_KBN_2 THEN
            RlKIHON.HASU := MOD(NwNENZEIGAKU, c_NHASU_2);
        ELSIF NlJHASU = c_NHASU_KBN_1 THEN
            RlKIHON.HASU := MOD(NwNENZEIGAKU, c_NHASU_1);
        ELSIF NlJHASU = c_NHASU_KBN_3 THEN
            RlKIHON.HASU := MOD(NwNENZEIGAKU, c_NHASU_3);
        ELSIF NlJHASU = c_NHASU_KBN_10 THEN
            RlKIHON.HASU := MOD(NwNENZEIGAKU, c_NHASU_10);
        END IF;

        UPDATE ZLBTKAI_KIHON_CAL
        SET GENMEN = NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU + NBYODOWARI_GENGAKU
            ,NENZEI = NwNENZEIGAKU - RlKIHON.HASU
            ,HASU = RlKIHON.HASU
            ,GENGAKU_KEI = GENGAKU_KEI - NwHASU + RlKIHON.HASU
        WHERE  KOKU_SETAI_NO   = i_NSETAI
          AND  SANTEIDANTAI_CD = i_NDANTAI
          AND  NENDO_BUN       = i_NNENDO_BUN
          AND  SYS_TANMATSU_NO = i_VTANMATSU;

        -- 所得割減免額
        NTAISHOTOKU_GENGAKU := TRUNC (NKANYUKI / 12 * RlTAI.SHOTOKU_WARI * (NVL (RlGENMEN_KOJIN.K_SHOTOKU_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        -- 資産割減免額
        NTAISISANZEI_GENGAKU := TRUNC (NKANYUKI / 12 * RlTAI.SHISAN_WARI * (NVL (RlGENMEN_KOJIN.K_SISANZEI_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        -- 均等割減免額
        NTAIKINTOWARI_GENGAKU := TRUNC (NKANYUKI / 12 * (RlTAI.KINTO_WARI - RlTAI.KEIGEN_K_WARI) * (NVL (RlGENMEN_KOJIN.K_KINTOWARI_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        --均等割減免額
        NTAIBYODOWARI_GENGAKU := TRUNC (NKANYUKI / 12 * (RlTAI.BYODO_WARI- RlTAI.KEIGEN_B_WARI)  * (NVL (RlGENMEN_KOJIN.K_BYODOWARI_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        -- 減免額合計の再セット
        UPDATE ZLBTGENMEN_KOJIN_CAL
        SET KT_SHOTOKU_GENGAKU = NTAISHOTOKU_GENGAKU,
            KT_SISANZEI_GENGAKU = NTAISISANZEI_GENGAKU,
            KT_KINTOWARI_GENGAKU = NTAIKINTOWARI_GENGAKU,
            KT_BYODOWARI_GENGAKU = NTAIBYODOWARI_GENGAKU,
            KT_GENGAKU_KEI = NTAISHOTOKU_GENGAKU + NTAISISANZEI_GENGAKU + NTAIKINTOWARI_GENGAKU + NTAIBYODOWARI_GENGAKU,
            KT_GENGAKU = NTAISHOTOKU_GENGAKU + NTAISISANZEI_GENGAKU + NTAIKINTOWARI_GENGAKU + NTAIBYODOWARI_GENGAKU,
            KT_GENGAKU_MAE = RlTAI.SEKISAN,
            KT_SHOTOKU_KISO = RlTAI.SHOTOKU_WARI,
            KT_SISANZEI_KISO = RlTAI.SHISAN_WARI,
            KT_KINTOWARI_KISO = RlTAI.KINTO_WARI,
            KT_BYODOWARI_KISO = RlTAI.BYODO_WARI,
            KT_NENZEI_KISO = RlTAI.SEKISAN - RlTAI.GENGAKU_KEI - (NTAISHOTOKU_GENGAKU + NTAISISANZEI_GENGAKU + NTAIKINTOWARI_GENGAKU + NTAIBYODOWARI_GENGAKU)
        WHERE  KOKU_SETAI_NO   = i_NSETAI
          AND  SANTEIDANTAI_CD = i_NDANTAI
          AND  NENDO_BUN       = i_NNENDO_BUN
          AND  SYS_TANMATSU_NO = i_VTANMATSU;
        UPDATE ZLBTKAI_TAI_CAL
        SET GENMEN = NTAISHOTOKU_GENGAKU + NTAISISANZEI_GENGAKU + NTAIKINTOWARI_GENGAKU + NTAIBYODOWARI_GENGAKU,
            NENZEI = SEKISAN - GENGAKU_KEI - (NTAISHOTOKU_GENGAKU + NTAISISANZEI_GENGAKU + NTAIKINTOWARI_GENGAKU + NTAIBYODOWARI_GENGAKU)
        WHERE  KOKU_SETAI_NO   = i_NSETAI
          AND  SANTEIDANTAI_CD = i_NDANTAI
          AND  NENDO_BUN       = i_NNENDO_BUN
          AND  SYS_TANMATSU_NO = i_VTANMATSU;
  EXCEPTION
    WHEN OTHERS THEN
      NlRTN := c_NERR;
      VlMSG := '独自減免調整 医療(国保世帯番号='||i_NSETAI||')'||SQLERRM;
END;
-------------------------------------------------------------------------------
-- 00 メイン
-------------------------------------------------------------------------------
BEGIN
    --月割調整区分
    ITSUKI_HASU_KBN := ZLBPK00010.FCFFJKN2(52);
    -- 限度超過額端数調整区分
    IGENDO_HASU_KBN := ZLBPK00010.FCFFJKN2(424);
    -- 減免計算世帯主課税条件
    IGENMENNUSHI_KBN := ZLBPK00010.FCFFJKN2(92);
    -- 減免計算有無
    IGENMENKEISAN_KBN := ZLBPK00010.FCFFJKN2(201);
---- 初期処理 -----
    NlRTN := c_NOK;
    VlMSG := NULL;

    subInit;                    -- 01 初期化
    subJokenSel;                -- 02 条件読込み

    IF NlRTN = c_NOK THEN               --03.05
        NGENMEN_EXIST_KBN := funcGenmenKojinExistChk;       -- 世帯内に減免対象者がいるかチェックする。
        IF  IGENMENKEISAN_KBN = 1 THEN
            NGENMEN_EXIST_KBN := 0;
        END IF;
                                                            -- 対象者がいる場合、減免額を算出するため、年税額の計算を２度行う。
    END IF;
    --月割減額マイナス調整開始年度の取得
    NSTATUS := KKAPK0030.FPRMSHUTOKU('ZLB', '00GENMINUS', 0, ACONSPRM, NPRMSUM);
    IF NSTATUS = 0 THEN
      NGENMINUS_NENDO := ACONSPRM(1);
    ELSE
      NGENMINUS_NENDO := 2019;
    END IF;

    -- 処理開始
    IF NlRTN = c_NOK THEN
        BEGIN
            FOR RwKOJIN IN ClKOJIN LOOP

                NlKOJIN_CNT := NlKOJIN_CNT + 1;     -- 計算個人の件数カウント

                subSekisanMae(RwKOJIN);   -- 03 積算税額算出準備
                EXIT WHEN NlRTN != c_NOK;

            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := '計算個人取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
        END;
    END IF;

    IF NlRTN = c_NOK THEN               --03.05
      subShogaiZenso;
    END IF;

    IF NlRTN = c_NOK THEN
        subSekisan;                     -- 04 積算税額算出
    END IF;

    IF NlKOJIN_CNT > 0 THEN

        IF NlRTN = c_NOK THEN
            subSetaiGaku;               -- 06 世帯税額算出
        END IF;

        IF ISHICHOSON_CD = c_KAMIINA_INA AND i_CAL_KBN != c_CAL_KBN_F4 THEN
          IF NlRTN = c_NOK THEN
              funcSetGenmen_20010;  -- xx 上伊那対応(減免対応)
          END IF;
        END IF;

        -- 減免個人データがある場合、減免額を求めるため、減免前と減免後の年税額を計算させる。
        IF NGENMEN_EXIST_KBN = 1 THEN
            NLOOP_CNT_MAX := 2;
        ELSE
            NLOOP_CNT_MAX := 1;
        END IF;

        IF NlRTN = c_NOK AND RlGENMEN_KOJIN.YUSEN_KBN = 6 THEN
          -- [当年度賦課決定支払数]、[納期未到来期期別数][加入月数]を取得する。
          subGetKibetsu;
        END IF;


        -- 計算対象者に減免個人データがあるか判断するフラグをクリア
        NGENMEN_KOJIN_KBN2 := 0;

        FOR NwIX IN 1..NLOOP_CNT_MAX LOOP
            NLOOP_CNT_NOW := NwIX;

            IF NLOOP_CNT_NOW = 2 THEN
                -- NGENMEN_KOJIN_KBN2 は、subZenTukiwari → subTukiwariMae でセットする。
                IF NGENMEN_KOJIN_KBN2 = 0 THEN
                    -- １回目の計算時、計算対象者に減免個人データがなかった場合、
                    -- ２回目の計算は行わない。
                    EXIT;
                END IF;

                -- ワーククリア
                NlKEIGEN_KINTO      := 0;                   -- 軽減均等
                NlKEIGEN_BYODO      := 0;                   -- 軽減平等
                NlKEIGEN_K_6_ZEN    := 0;                   -- 軽減均等6 全体
                NlKEIGEN_B_6_ZEN    := 0;                   -- 軽減平等6 全体
                NlKEIGEN_K_4_ZEN    := 0;                   -- 軽減均等4 全体
                NlKEIGEN_B_4_ZEN    := 0;                   -- 軽減平等4 全体
                NlKEIGEN_K_2_ZEN    := 0;                   -- 軽減均等2 全体
                NlKEIGEN_B_2_ZEN    := 0;                   -- 軽減平等2 全体
                NlKEIGEN_K_6_TAI    := 0;                   -- 軽減均等6 退職
                NlKEIGEN_B_6_TAI    := 0;                   -- 軽減平等6 退職
                NlKEIGEN_K_4_TAI    := 0;                   -- 軽減均等4 退職
                NlKEIGEN_B_4_TAI    := 0;                   -- 軽減平等4 退職
                NlKEIGEN_K_2_TAI    := 0;                   -- 軽減均等2 退職
                NlKEIGEN_B_2_TAI    := 0;                   -- 軽減平等2 退職
                NlNENZEIGAKU        := 0;                   -- 年税額
                NlTAINENZEIGAKU     := 0;                   -- 退年税額
                FOR NwIX2 IN 1..12 LOOP
                    MlCNT(NwIX2)         := 0;               -- 人員(各月有資格者数)
                    MlZEIGAKU(NwIX2)     := 0;               -- 税額
                    MlSUMI(NwIX2)        := 0;               -- 済
                    MlTUKI(NwIX2)        := 0;               -- 月数
                    MlCHOKA_MAE(NwIX2)   := 0;               -- 限度超過前
                    MlTAICNT(NwIX2)      := 0;               -- 退人員(各月有資格者数)
                    MlTAIZEIGAKU(NwIX2)  := 0;               -- 退税額
                    MlTAISUMI(NwIX2)     := 0;               -- 退済
                    MlTAITUKI(NwIX2)     := 0;               -- 退月数

                    MlKAHYO(NwIX2)       := 0;               -- 課標
                    MlTAIKAHYO(NwIX2)    := 0;               -- 課標退職

                    MlZEIGAKU_SEKI(NwIX2):= 0;               -- 積算算出用 税額
                    MlSUMI_SEKI(NwIX2)   := 0;               -- 積算算出用 済
                    MlTUKI_SEKI(NwIX2)   := 0;               -- 積算算出用 月数
                    MlCHOKA_SEKI(NwIX2)  := 0;               -- 積算算出用 限度超過
                    MlKAHYO_SEKI(NwIX2)  := 0;               -- 積算算出用 課標
                    MlNEN_CNT_SEKI(NwIX2):= 0;               -- 積算算出用 年齢軽減人員(各月有資格者数)

                    MlTAIZEIGAKU_SEKI(NwIX2):= 0;            -- 積算算出用 退税額
                    MlTAISUMI_SEKI(NwIX2)   := 0;            -- 積算算出用 退済
                    MlTAITUKI_SEKI(NwIX2)   := 0;            -- 積算算出用 退月数
                    MlTAICHOKA_SEKI(NwIX2)  := 0;            -- 積算算出用 退限度超過
                    MlTAIKAHYO_SEKI(NwIX2)  := 0;            -- 積算算出用 退課標
                    MlTAINEN_CNT_SEKI(NwIX2):= 0;            -- 積算算出用 退年齢軽減人員(各月有資格者数)
                    --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
                    MlSANCNT(NwIX2)         := 0;            -- 各月産前産後人員(各月有資格者数)
                END LOOP;
            END IF;

            IF NlRTN = c_NOK THEN
                subZenTukiwari;             -- 07 基本処理
            END IF;

            IF NlRTN = c_NOK AND i_NJIKKOU_KBN != c_NTEST THEN      -- 賦課試算時は処理しない
                subTaiTukiwari;             -- 08 退職処理
            END IF;

            IF i_CAL_KBN = c_CAL_KBN_TU THEN
                IF NGENMEN_USE_KBN = -1 THEN
                    -- 当該年度の減免データが作成されているかチェックする。
                    -- １件も作成されていない場合、減免個人を使用していない市町村と判断する。
                    NGENMEN_USE_KBN := funcGenmenKojinUseChk;
                    IF  IGENMENKEISAN_KBN = 1 THEN
                        NGENMEN_USE_KBN := 0;
                    END IF;
                END IF;
                IF NGENMEN_USE_SKBN = -1 THEN
                    -- 当該年度の減免データが作成されているかチェックする。
                    -- １件も作成されていない場合、減免世帯を使用していない市町村と判断する。
                    NGENMEN_USE_SKBN := funcGenmenSetaiUseChk;
                    IF  IGENMENKEISAN_KBN = 1 THEN
                        NGENMEN_USE_SKBN := 0;
                    END IF;
                END IF;
                -- 減免個人/世帯減免を使用していない市町村のとき、ZLBTKIHON_N から減免額を取得する。
                IF NGENMEN_USE_KBN = 0 AND NGENMEN_USE_SKBN = 0 THEN
                    IF NlRTN = c_NOK THEN
                        funcGetGenmen;              -- 27 減免額（全体）の取得
                    END IF;
                    IF NlRTN = c_NOK AND i_NJIKKOU_KBN != c_NTEST THEN      -- 賦課試算時は処理しない
                        funcGetGenmen_TAI;          -- 28 減免額（退職）の取得
                    END IF;
                END IF;
            END IF;
            IF NlRTN = c_NOK THEN
                subShogaiGenmen;             -- 29 障害者減免を算出（医療・退職）
            END IF;

        IF ISHICHOSON_CD = c_KAMIINA_INA AND i_CAL_KBN != c_CAL_KBN_F4 THEN
              IF NlRTN = c_NOK THEN
                  funcSetGengaku_20010;  -- xx 上伊那対応(減免対応)
              END IF;
            END IF;

            IF NlRTN = c_NOK THEN
               subSetaiGenmenGet;          -- 08.5 世帯減免の有無を取得
            END IF;

            IF NlRTN = c_NOK THEN
                NCNT_KAKUTEI := 0;
                subKakutei;                 -- 09 税額確定処理（基本）
                IF i_NJIKKOU_KBN != c_NTEST THEN                    -- 賦課試算時は処理しない
                    subKakutei_Tai;         -- 10 税額確定処理（退職）
                END IF;
            END IF;

            IF NGENMEN_EXIST_KBN = 1 THEN
                IF NLOOP_CNT_NOW = 1 THEN
                    -- 減免前の年税額と端数をワークに保存
                    NwNENZEIGAKU     := RlKIHON.NENZEI;
                    --  2024/05/06 ZCZL.ZHANGLEI ADD 0.3.000.100:国保２次にマージ作業
                    NwGENDO_CHOKA    := RlKIHON.GENDO_CHOKA;
                    NwHASU           := RlKIHON.HASU;
                    NwNENZEIGAKU_TAI := RlTAI.NENZEI;
                    NwHASU_TAI       := RlTAI.HASU;
                ELSE
                  subGenmenChosi;
                  IF RlGENMEN_KOJIN.YUSEN_KBN IN (3, 4) THEN
                    vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';

                    vSQL := vSQL || ' SET K_NENZEI_KISO     = :1,';   -- 年税基礎額
                    vSQL := vSQL || '     KT_NENZEI_KISO    = :2,';   -- 年税基礎額(退職)
                    vSQL := vSQL || '     K_NENZEI_GENGAKU  = :3,';   -- 年税減免額
                    vSQL := vSQL || '     KT_NENZEI_GENGAKU = :4,';   -- 年税減免額(退職)
                    vSQL := vSQL || '     K_GENGAKU_MAE     = :5,';   -- 減免前の年税額
                    vSQL := vSQL ||      'K_GENGAKU         = :6,';   -- 減免額(端数調整前)
                    vSQL := vSQL ||      'KT_GENGAKU_MAE    = :7,';   -- 減免前の年税額(退職)
                    vSQL := vSQL ||      'KT_GENGAKU        = :8';    -- 減免額(端数調整前)(退職)
                    vSQL := vSQL || ' WHERE KOKU_SETAI_NO   = :9';
                    vSQL := vSQL || ' AND   SANTEIDANTAI_CD = :10';
                    vSQL := vSQL || ' AND   NENDO_BUN       = :11';
                    vSQL := vSQL || ' AND   SYS_TANMATSU_NO = :12';
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    vSQL := vSQL || '  AND ((YUSEN_KBN > 0 AND TSUCHI_NO = :13 )';
                    vSQL := vSQL || '        OR (YUSEN_KBN = 0 AND NVL(TSUCHI_NO,0) != 0))';
                  ELSE
                    vSQL := vSQL || '  AND :13 IS NOT NULL';
                  END IF;

                    EXECUTE IMMEDIATE vSQL USING IN NwNENZEIGAKU,
                                                    NwNENZEIGAKU_TAI,
                                                    NwNENZEIGAKU - RlKIHON.NENZEI,
                                                    NwNENZEIGAKU_TAI - RlTAI.NENZEI,
                                                    NwNENZEIGAKU,
                                                    RlKIHON.GENMEN,
                                                    NwNENZEIGAKU_TAI,
                                                    RlTAI.GENMEN,
                                                    i_NSETAI,
                                                    i_NDANTAI,
                                                    i_NNENDO_BUN,
                                                    i_VTANMATSU,
                                                    i_NNUSHI;
                  ELSE
                    vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                    vSQL := vSQL || ' SET K_GENGAKU_MAE     = :5,';   -- 減免前の年税額
                    vSQL := vSQL ||      'K_GENGAKU         = :6,';   -- 減免額(端数調整前)
                    vSQL := vSQL ||      'KT_GENGAKU_MAE    = :7,';   -- 減免前の年税額(退職)
                    vSQL := vSQL ||      'KT_GENGAKU        = :8';    -- 減免額(端数調整前)(退職)
                    vSQL := vSQL || ' WHERE KOKU_SETAI_NO   = :9';
                    vSQL := vSQL || ' AND   SANTEIDANTAI_CD = :10';
                    vSQL := vSQL || ' AND   NENDO_BUN       = :11';
                    vSQL := vSQL || ' AND   SYS_TANMATSU_NO = :12';
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    vSQL := vSQL || '  AND ((YUSEN_KBN > 0 AND TSUCHI_NO = :13 )';
                    vSQL := vSQL || '        OR (YUSEN_KBN = 0 AND NVL(TSUCHI_NO,0) != 0))';
                  ELSE
                    vSQL := vSQL || '  AND :13 IS NOT NULL';
                  END IF;

                    EXECUTE IMMEDIATE vSQL USING IN NwNENZEIGAKU,
                                                    RlKIHON.GENMEN,
                                                    NwNENZEIGAKU_TAI,
                                                    RlTAI.GENMEN,
                                                    i_NSETAI,
                                                    i_NDANTAI,
                                                    i_NNENDO_BUN,
                                                    i_VTANMATSU,
                                                    i_NNUSHI;
                  END IF;

                END IF;
            END IF;
        END LOOP;

        --優先区分が「世帯／率／応能応益」
        IF RlGENMEN_KOJIN.YUSEN_KBN = 1 THEN
          -- 世帯主以外の平等割減免額を初期化する
          UPDATE ZLBTGENMEN_KOJIN_CAL
             SET K_BYODOWARI_GENGAKU = 0,
                 KT_BYODOWARI_GENGAKU = 0
          WHERE KOKU_SETAI_NO   = i_NSETAI
            AND SANTEIDANTAI_CD = i_NDANTAI
            AND NENDO_BUN       = i_NNENDO_BUN
            AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                 OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                 OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                 OR (NlJNUSHI <> 1)
                )
            AND SYS_TANMATSU_NO = i_VTANMATSU
            AND KOJIN_NO       <> i_NNUSHI;
          --ZLBTGENMEN_KOJIN_CALの所得割減免金額、資産割減免金額、均等割減免金額、平等割減免金額、
          --年額減免金額を集計し、１レコード（個人番号がZLBTGENMEN_KOJINと同じデータ）に集約する
          SELECT NVL(SUM(K_SHOTOKU_KISO), 0),      NVL(SUM(K_SISANZEI_KISO), 0),    NVL(SUM(K_KINTOWARI_KISO), 0),
                 NVL(SUM(KT_SHOTOKU_KISO), 0),     NVL(SUM(KT_SISANZEI_KISO), 0),   NVL(SUM(KT_KINTOWARI_KISO), 0),
                 NVL(SUM(K_SHOTOKU_GENGAKU), 0),   NVL(SUM(K_SISANZEI_GENGAKU), 0), NVL(SUM(K_KINTOWARI_GENGAKU), 0),
                 NVL(SUM(K_BYODOWARI_GENGAKU), 0), NVL(SUM(K_NENZEI_GENGAKU), 0),
                 NVL(SUM(KT_SHOTOKU_GENGAKU), 0),  NVL(SUM(KT_SISANZEI_GENGAKU), 0),NVL(SUM(KT_KINTOWARI_GENGAKU), 0),
                 NVL(SUM(KT_BYODOWARI_GENGAKU), 0),NVL(SUM(KT_NENZEI_GENGAKU), 0)
            INTO NwSHOTOKU_KISO_SUM,               NwSISANZEI_KISO_SUM,             NwKINTOWARI_KISO_SUM,
                 NwTSHOTOKU_KISO_SUM,              NwTSISANZEI_KISO_SUM,            NwTKINTOWARI_KISO_SUM,
                 NwSHOTOKU_GENGAKU_SUM,            NwSISANZEI_GENGAKU_SUM,          NwKINTOWARI_GENGAKU_SUM,
                 NwBYODOWARI_GENGAKU_SUM,          NwNENZEI_GENGAKU_SUM,
                 NwTSHOTOKU_GENGAKU_SUM,           NwTSISANZEI_GENGAKU_SUM,         NwTKINTOWARI_GENGAKU_SUM,
                 NwTBYODOWARI_GENGAKU_SUM,         NwTNENZEI_GENGAKU_SUM
            FROM ZLBTGENMEN_KOJIN_CAL
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND NENDO_BUN       = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO = i_VTANMATSU;
          --ZLBTGENMEN_KOJIN_CALの個人番号がZLBTGENMEN_KOJINに存在するデータのみを更新する
          UPDATE ZLBTGENMEN_KOJIN_CAL CAL
             SET K_SHOTOKU_KISO = NwSHOTOKU_KISO_SUM,
                 K_SISANZEI_KISO = NwSISANZEI_KISO_SUM,
                 K_KINTOWARI_KISO = NwKINTOWARI_KISO_SUM,
                 KT_SHOTOKU_KISO = NwTSHOTOKU_KISO_SUM,
                 KT_SISANZEI_KISO = NwTSISANZEI_KISO_SUM,
                 KT_KINTOWARI_KISO = NwTKINTOWARI_KISO_SUM,
                 K_SHOTOKU_GENGAKU = NwSHOTOKU_GENGAKU_SUM,
                 K_SISANZEI_GENGAKU = NwSISANZEI_GENGAKU_SUM,
                 K_KINTOWARI_GENGAKU = NwKINTOWARI_GENGAKU_SUM,
                 K_BYODOWARI_GENGAKU = NwBYODOWARI_GENGAKU_SUM,
                 K_NENZEI_GENGAKU = NwNENZEI_GENGAKU_SUM,
                 KT_SHOTOKU_GENGAKU = NwTSHOTOKU_GENGAKU_SUM,
                 KT_SISANZEI_GENGAKU = NwTSISANZEI_GENGAKU_SUM,
                 KT_KINTOWARI_GENGAKU = NwTKINTOWARI_GENGAKU_SUM,
                 KT_BYODOWARI_GENGAKU = NwTBYODOWARI_GENGAKU_SUM,
                 KT_NENZEI_GENGAKU = NwTNENZEI_GENGAKU_SUM
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND NENDO_BUN       = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO = i_VTANMATSU
              AND EXISTS (SELECT KOJIN_NO FROM ZLBTGENMEN_KOJIN
                           WHERE KOKU_SETAI_NO   = CAL.KOKU_SETAI_NO
                             AND SANTEIDANTAI_CD = CAL.SANTEIDANTAI_CD
                             AND KOJIN_NO        = CAL.KOJIN_NO
                             AND NENDO_BUN       = CAL.NENDO_BUN);
--          --ZLBTGENMEN_KOJIN_CALの個人番号がZLBTGENMEN_KOJINに存在しないデータを削除する
        END IF;
        -- 減免額合計の再セット
        UPDATE ZLBTGENMEN_KOJIN_CAL
        SET    K_GENGAKU_KEI = K_SHOTOKU_GENGAKU + K_SISANZEI_GENGAKU + K_KINTOWARI_GENGAKU + K_BYODOWARI_GENGAKU + K_NENZEI_GENGAKU,
               KT_GENGAKU_KEI = KT_SHOTOKU_GENGAKU + KT_SISANZEI_GENGAKU + KT_KINTOWARI_GENGAKU + KT_BYODOWARI_GENGAKU + KT_NENZEI_GENGAKU
        WHERE  KOKU_SETAI_NO   = i_NSETAI
          AND  SANTEIDANTAI_CD = i_NDANTAI
          AND  NENDO_BUN       = i_NNENDO_BUN
          AND  ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                OR (NlJNUSHI <> 1)
               )
          AND  SYS_TANMATSU_NO = i_VTANMATSU;
    ELSE

        IF NlRTN = c_NOK THEN
            subOutInit;                 -- 11 計算個人0件時セット
        END IF;

    END IF;

    IF NlRTN = c_NOK THEN
        subInsert;                      -- 12 計算基本・計算退職登録
    END IF;
    IF NlKOJIN_CNT > 0 AND RlGENMEN_KOJIN.YUSEN_KBN = 6 THEN
      subGenmenDokuji;
    END IF;
    IF NlRTN = c_NOK THEN
        subGenmenKojinDummyInsert;      -- 減免個人データ  整合性チェック＆ダミーデータ作成
    END IF;

    -- 終了処理
    IF NlRTN = c_NOK THEN        -- 正常に処理完了
        BEGIN
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'COMMIT発行(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
        END;
    END IF;

    IF NlRTN != c_NOK THEN       -- 処理異常
        BEGIN
            ROLLBACK;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END IF;

    -- ログ出力
    IF NlRTN != c_NOK AND VlMSG IS NOT NULL THEN
        IF i_NJIKKOU_KBN IN (c_NBATCH,c_NBATCH_ZER) THEN    --バッチ起動時
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCALMKAI', 1, '', '','ZLBSKCALMKAI '||VlMSG, NULL, i_VTANMATSU);
        ELSIF i_NTRENBAN = -1 THEN
            -- テストの時のみ有効
            DBMS_OUTPUT.PUT_LINE('ZLBSKCALMKAI '||VlMSG);
        END IF;
    END IF;

    o_NRESULT := NlRTN;

END ZLBSKCALMKAI;
/
