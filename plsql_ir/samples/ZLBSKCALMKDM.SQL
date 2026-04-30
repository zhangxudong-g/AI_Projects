CREATE OR REPLACE PROCEDURE ZLBSKCALMKDM (i_NNENDO             IN  NUMBER,
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
                                          i_NKOSEIBI           IN  NUMBER := 0,
                                          i_NSHORI_MD          IN  NUMBER DEFAULT 0)
-------------------------------------------------------------------------------
-- 業務名   ZLB（国保税）
-- ＰＧ名   ZLBSKCALMKDM
-- 名称     計算子育て基本作成
-- 処理概要 計算個人を元に課税計算を行い、計算子ども基本作成する。
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
--          i_NKOSEIBI          更正日（入力なし:システム日付、入力あり:入力値を使用）
--          i_NSHORI_MD         処理モード（入力なし:0、入力あり:入力値を使用）
-- 作成者   ZCZL.LIUHUAJUN
-- 作成日   2025/08/11
-- Version  1.1.200.000
-------------------------------------------------------------------------------
--  変更履歴
--  2025/10/09 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_No57、No60指摘対応
--  2025/10/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--  2025/10/13 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--  2025/10/15 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--  2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--  2025/11/06 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
--  2025/12/04 ZCZL.XIESHUN ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--  2025/12/10 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00104
-- 　2025/12/11 ZCZL.XIESHUN ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084(2回目)
-- 　2025/12/12 ZCZL.XIESHUN ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084(3回目)
-- 　2025/12/16 ZCZL.XIESHUN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084(4回目)
-- 　2025/12/17 ZCZL.MUZHILIN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--  2025/12/22 ZCZL.XIESHUN DELETE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00125
--  2025/12/24 ZCZL.LIUYANG UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00136
-------------------------------------------------------------------------------
IS

    -- アレイTYPE定義
    TYPE MTNUMARRAY1  IS TABLE OF NUMBER(1)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY2  IS TABLE OF NUMBER(2)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY3  IS TABLE OF NUMBER(3)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY10 IS TABLE OF NUMBER(10) INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY12 IS TABLE OF NUMBER(12) INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY15F IS TABLE OF NUMBER(12,3) INDEX BY BINARY_INTEGER;
-- 2025/12/17 ZCZL.MUZHILIN ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
    TYPE MTNUMARRAY17F IS TABLE OF NUMBER(13,4) INDEX BY BINARY_INTEGER;
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
    c_NHASU_KBN_10      CONSTANT NUMBER := 3;       -- c_NHASU_10に対応

    -- 実行区分
    c_NBATCH            CONSTANT NUMBER(1) := 0;    -- バッチから起動
    c_NBATCH_ZER        CONSTANT NUMBER(1) := 3;    --バッチ(税率試算)

    -- 呼出区分
    c_CAL_KBN_TU        CONSTANT NUMBER(2) := 0;    -- (0:通常処理
    c_CAL_KBN_FK        CONSTANT NUMBER(2) := 1;    -- (1:賦課期日時点処理
    c_CAL_KBN_F4        CONSTANT NUMBER(2) := 2;    -- (2:H4/HH/C4処理

    -- 算定団体コード
    c_NDANTAI           CONSTANT NUMBER(2)  := 1;   -- 合併後算定団体コード

    -- 不均一課税
    c_NFKAZEI           CONSTANT NUMBER     := 1;   -- 不均一課税を行なう

    -- 市町村コード
    ISHICHOSON_CD       PLS_INTEGER;                   -- 市町村コード

    TYPE TSHIK   IS TABLE OF NUMBER(2)   INDEX BY BINARY_INTEGER;
    AlSHIK                TSHIK;                      -- 月別国保資格
    TYPE TSHITSU IS TABLE OF NUMBER(2)   INDEX BY BINARY_INTEGER;
    AlSHITSU              TSHITSU;                    -- 月別失業者資格

    MJI_NINSU             MTNUMARRAY3;    -- 子ども人数ワーク
    MlSAN_KBN             MTNUMARRAY2;
    MlSANCNT              MTNUMARRAY3;
    MlSANCNT_K            MTNUMARRAY3;
    MlSANCNT18            MTNUMARRAY3;    -- 産前産後　人数(うち18歳以上)
    MlSANCNT_K18          MTNUMARRAY3;    -- 産前産後　人数(旧被扶養者 うち18歳以上)
    MlSANCNT18UN          MTNUMARRAY3;    -- 産前産後　人数(うち18歳未満)
    MlSANCNT_K18UN        MTNUMARRAY3;    -- 産前産後　人数(旧被扶養者 うち18歳未満)

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
    NlKEIGEN_KINTO          NUMBER(10,3);   -- 軽減均等
    NlKEIGEN_KINTO18        NUMBER(10,3);   -- 18歳以上均等軽減額
    NlKEIGEN_KINTO18UN      NUMBER(10,3);   -- 18歳未満均等軽減額
    NlKEIGEN_BYODO          NUMBER(10,3);   -- 軽減平等
    NlKEIGEN_K_6_ZEN        NUMBER(10,3);   -- 軽減均等6 全体
    NlKEIGEN_B_6_ZEN        NUMBER(10,3);   -- 軽減平等6 全体
    NlKEIGEN_K_4_ZEN        NUMBER(10,3);   -- 軽減均等4 全体
    NlKEIGEN_B_4_ZEN        NUMBER(10,3);   -- 軽減平等4 全体
    NlKEIGEN_K_2_ZEN        NUMBER(10,3);   -- 軽減均等2 全体
    NlKEIGEN_B_2_ZEN        NUMBER(10,3);   -- 軽減平等2 全体
--年税額
    NlNENZEIGAKU            NUMBER(12,3);     --年税額
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
    MlCNT18                 MTNUMARRAY3;    -- 人員(各月有資格者数　うち18歳以上)
    MlCNT18UN               MTNUMARRAY3;    -- 人員(各月有資格者数　うち18歳未満)
    MlZEIGAKU               MTNUMARRAY12;   -- 税額
    MlKINTO18UN             MTNUMARRAY12;   -- 18歳未満の均等割額の計
    MlZEIGAKU18             MTNUMARRAY12;   -- 年税額(産前産後限度超過計算時の年税額に関わる18歳以上均等割軽減額/18歳未満均等割軽減額)
    MlZEIGAKU218            MTNUMARRAY12;   -- 税額限度超過調整用(産前産後限度超過計算時の年税額に関わる18歳以上均等割軽減額/18歳未満均等割軽減額)
    MlZEIGAKU2              MTNUMARRAY12;   -- 税額限度超過調整用
    MlSUMI                  MTNUMARRAY1;    -- 済
    MlTUKI                  MTNUMARRAY2;    -- 月数
    MlZEIGAKU_SEKI          MTNUMARRAY12;   -- 積算算出用 税額
    MlSUMI_SEKI             MTNUMARRAY1;    -- 積算算出用 済
    MlTUKI_SEKI             MTNUMARRAY2;    -- 積算算出用 月数
    MlCHOKA_SEKI            MTNUMARRAY10;   -- 積算算出用 限度超過
    MlKAHYO_SEKI            MTNUMARRAY12;   -- 積算算出用 課標
    MlNEN_CNT_SEKI          MTNUMARRAY3;    -- 積算算出用 年齢軽減人員(各月有資格者数)

    NlNENREI_KEIGEN         NUMBER(1);      -- 年齢軽減
    NlSINSHO_GENMEN         NUMBER(1);      -- 身障減免
    NlGENMENRITU            NUMBER(1);      -- 減免率計算

    Nl22Ika_CNT             NUMBER(3);      -- 22才以下人員
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
    NlJKINTO18              NUMBER;         -- 18歳以上均等割額
    NlJKGEN118              NUMBER;         -- 18歳以上均等割　軽減均等割1(6割)
    NlJKGEN218              NUMBER;         -- 18歳以上均等割　軽減均等割2(4割)
    NlJKGEN318              NUMBER;         -- 18歳以上均等割　軽減均等割3(4割)
    NlJNUSHI                NUMBER;         --主課税条件
    NlJBGEN_T1              NUMBER;         -- 特定同一 軽減平等割1(7,6割)
    NlJBGEN_T2              NUMBER;         -- 特定同一 軽減平等割2(5,4割)
    NlJBGEN_T3              NUMBER;         -- 特定同一 軽減平等割3(2割)
    NlJBGEN2_T1             NUMBER;         -- 特定同一(2) 軽減平等割1(7,6割)
    NlJBGEN2_T2             NUMBER;         -- 特定同一(2) 軽減平等割2(5,4割)
    NlJBGEN2_T3             NUMBER;         -- 特定同一(2) 軽減平等割3(2割)
    NKODOMO_KEIGEN_WARIAI   NUMBER;         -- 子ども均等割軽減率

    -- 出力用ワーク
    RlKIHON                 ZLBTKDM_KIHON_CAL%ROWTYPE;   -- 計算子ども基本
    RlKIHON_IRY             ZLBTKIHON_CAL%ROWTYPE;       -- 計算基本
    RlEXT                   ZLBTEXT_CAL%ROWTYPE;         -- 計算賦課拡張

    NKENSAKU_TSUCHI_NO      NUMBER;         -- 減免額検索用通知書番号

    NSHOTOKU_2DANKAI        NUMBER;         -- 所得２段階有無
    NSHOTOKU_HANTEI_GAKU    NUMBER;         -- 所得割判定額
    NSSHOTOKU_KDM_OVER      NUMBER;         -- 所得割率
    NSHOTOKU_KDM            NUMBER;         -- 所得割率２
    MlNEN_CNT               MTNUMARRAY3;    -- 年齢軽減人員(各月有資格者数)
    NNENREI_KEIGEN          NUMBER;         -- 年齢軽減額
    MlKAHYO                 MTNUMARRAY12;   -- 課標
    ITSUKI_HASU_KBN         PLS_INTEGER;    -- 月割端数調整区分
    IGENDO_HASU_KBN         PLS_INTEGER;    -- 限度超過額端数調整区分
    IGENMENNUSHI_KBN        PLS_INTEGER;    -- 減免計算世帯主課税条件
    IGENMENKEISAN_KBN       PLS_INTEGER;    -- 減免計算有無
    NSHISAN_KDM             NUMBER;                       -- 子ども資産割率
    MlOUEKI                 MTNUMARRAY12;                 --応益係数
    MlOUNOU                 MTNUMARRAY12;                 --応能係数
    MlTAISHO_KBN            MTNUMARRAY1;                 -- 対象区分
    NlPER                   MTNUMARRAY3;    --応益係数 idx1=50%,idx2=70%,idx3=90%,idx4=100%
    NlCNT                   MTNUMARRAY3;    --月毎の応益係数それぞれの該当件数(ひと月4要素×12)
                                            -- idx 1～ 4：4月 ・・・ idx45～48：3月

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
        KOKU_SETAI_NO            NUMBER,
        SANTEIDANTAI_CD          NUMBER(2),
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
        SYS_TANMATSU_NO          NVARCHAR2(63),
        KDM_SHOTOKU_KISO         NUMBER(12),
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
    );
    RwGENMENKOJIN                type_ZLBTGENMEN_KOJIN_CAL;
    NwNENZEIGAKU                 NUMBER(12,3);     -- 減免前の年税額を保存
    NwHASU                       NUMBER(12,3);     -- 減免前の端数  を保存
    RlGENMEN_KOJIN  ZLBTGENMEN_KOJIN_TMP%ROWTYPE := NULL;    -- 減免個人TMP
    NwSHOTOKU_KISO_SUM           NUMBER(12);       -- 所得割基礎額
    NwSISANZEI_KISO_SUM          NUMBER(12);       -- 資産割基礎額
    NwKINTOWARI_KISO_SUM         NUMBER(12);       -- 均等割基礎額
    NwKINTOWARI_KISO_18_SUM      NUMBER(12);       -- 18歳以上均等割基礎額
    NwKINTOWARI_GENGAKU_18_SUM   NUMBER(12);       -- 18歳以上均等割減免額
    NwSHOTOKU_GENGAKU_SUM        NUMBER(12);       -- 所得割減免額
    NwSISANZEI_GENGAKU_SUM       NUMBER(12);       -- 資産割減免額
    NwKINTOWARI_GENGAKU_SUM      NUMBER(12);       -- 均等割減免額
    NwBYODOWARI_GENGAKU_SUM      NUMBER(12);       -- 平等割減免額
    NwNENZEI_GENGAKU_SUM         NUMBER(12);       -- 年税減免額

    NFUKASHIRASU                 NUMBER;           -- 当年度賦課決定支払数
    NNOKIMATUKIBETSU             NUMBER;           -- 納期未到来期期別数
    NKANYUKI                     NUMBER;           -- 加入月数
    NSHOTOKU_GENGAKU           NUMBER DEFAULT 0; -- 所得割減免額
    NSISANZEI_GENGAKU          NUMBER DEFAULT 0; -- 資産割減免額
    NKINTOWARI_GENGAKU         NUMBER DEFAULT 0; -- 均等割減免額
    NBYODOWARI_GENGAKU         NUMBER DEFAULT 0; -- 平等割減免額
    NKINTOWARI_GENGAKU_18      NUMBER DEFAULT 0; -- 18歳以上均等割減免額
    NwSANCHOKA_FLG             NUMBER DEFAULT 0; -- 産前産後かつ限度超過フラグ
    NKANYUTSUKI_CNT            NUMBER DEFAULT 0; -- 加入月数カウンタ
    NwGENDO_CHOKA              NUMBER(12,3);     -- 減免前限度超過額
-------------------------------------------------------------------------------
-- カーソルの定義
-------------------------------------------------------------------------------
    -- 計算個人
    CURSOR ClKOJIN IS
        SELECT * FROM ZLBTKOJIN_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND TSUCHI_NO       = i_NNUSHI
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
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_4 = 1 THEN
        NGENMEN := 1;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_5 = 1 THEN
        NGENMEN := 2;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_6 = 1 THEN
        NGENMEN := 3;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_7 = 1 THEN
        NGENMEN := 4;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_8 = 1 THEN
        NGENMEN := 5;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_9 = 1 THEN
        NGENMEN := 6;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_10 = 1 THEN
        NGENMEN := 7;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_11 = 1 THEN
        NGENMEN := 8;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_12 = 1 THEN
        NGENMEN := 9;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_1 = 1 THEN
        NGENMEN := 10;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_2 = 1 THEN
        NGENMEN := 11;
      END IF;
      IF NGENMEN = 0 AND RlGENMEN_KOJIN.KDM_GENMEN_3 = 1 THEN
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
         AND DANTAING_KBN = 0
         AND CHOTEINENDO = i_NNENDO
         AND GENNENKANEN_KBN = 0
         AND NOKIGEN >= RlGENMEN_KOJIN.SHINSEI_BI
         AND ROWNUM = 1;

      -- 納期月以降の有効な論理期数を[納期未到来期期別数]として取得する。
      RlGENMEN_KOJIN.KDM_GENMEN_4  := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_5  := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_6  := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_7  := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_8  := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_9  := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_10 := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_11 := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_12 := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_1  := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_2  := 0;
      RlGENMEN_KOJIN.KDM_GENMEN_3  := 0;
      FOR NLOOPCNT IN NRONRIKIBETSU..13 LOOP
        CASE NLOOPCNT
          WHEN 1 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_4 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 2 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_5 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 3 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_6 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 4 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_7 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 5 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_8 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 6 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_9 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 7 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_10 := 1;           -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 8 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_11 := 1;           -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 9 THEN                                    -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_12 := 1;           -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 10 THEN                                   -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_1 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 11 THEN                                   -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_2 := 1;            -- 納期未到来期を減免有として扱い更新を行う
            END IF;
          WHEN 12 THEN                                   -- 論理期別
            IF MlNOKI_KBN(NLOOPCNT) = 1 THEN             -- 有効な期(納期区分が2：本算定、3：納期月、4：随時)
              NNOKIMATUKIBETSU := NNOKIMATUKIBETSU + 1;  -- 納期未到来期期別数
              RlGENMEN_KOJIN.KDM_GENMEN_3 := 1;            -- 納期未到来期を減免有として扱い更新を行う
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
         SET KDM_GENMEN_4  = RlGENMEN_KOJIN.KDM_GENMEN_4,
             KDM_GENMEN_5  = RlGENMEN_KOJIN.KDM_GENMEN_5,
             KDM_GENMEN_6  = RlGENMEN_KOJIN.KDM_GENMEN_6,
             KDM_GENMEN_7  = RlGENMEN_KOJIN.KDM_GENMEN_7,
             KDM_GENMEN_8  = RlGENMEN_KOJIN.KDM_GENMEN_8,
             KDM_GENMEN_9  = RlGENMEN_KOJIN.KDM_GENMEN_9,
             KDM_GENMEN_10 = RlGENMEN_KOJIN.KDM_GENMEN_10,
             KDM_GENMEN_11 = RlGENMEN_KOJIN.KDM_GENMEN_11,
             KDM_GENMEN_12 = RlGENMEN_KOJIN.KDM_GENMEN_12,
             KDM_GENMEN_1  = RlGENMEN_KOJIN.KDM_GENMEN_1,
             KDM_GENMEN_2  = RlGENMEN_KOJIN.KDM_GENMEN_2,
             KDM_GENMEN_3  = RlGENMEN_KOJIN.KDM_GENMEN_3
       WHERE KOKU_SETAI_NO   = RlGENMEN_KOJIN.KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = RlGENMEN_KOJIN.SANTEIDANTAI_CD
         AND NENDO_BUN       = RlGENMEN_KOJIN.NENDO_BUN
         AND SYS_TANMATSU_NO = RlGENMEN_KOJIN.SYS_TANMATSU_NO;

      -- ZLBTGENMEN_KOJIN_CALの減免区分を更新する。
      UPDATE ZLBTGENMEN_KOJIN_CAL
         SET KDM_GENMEN_4  = RlGENMEN_KOJIN.KDM_GENMEN_4,
             KDM_GENMEN_5  = RlGENMEN_KOJIN.KDM_GENMEN_5,
             KDM_GENMEN_6  = RlGENMEN_KOJIN.KDM_GENMEN_6,
             KDM_GENMEN_7  = RlGENMEN_KOJIN.KDM_GENMEN_7,
             KDM_GENMEN_8  = RlGENMEN_KOJIN.KDM_GENMEN_8,
             KDM_GENMEN_9  = RlGENMEN_KOJIN.KDM_GENMEN_9,
             KDM_GENMEN_10 = RlGENMEN_KOJIN.KDM_GENMEN_10,
             KDM_GENMEN_11 = RlGENMEN_KOJIN.KDM_GENMEN_11,
             KDM_GENMEN_12 = RlGENMEN_KOJIN.KDM_GENMEN_12,
             KDM_GENMEN_1  = RlGENMEN_KOJIN.KDM_GENMEN_1,
             KDM_GENMEN_2  = RlGENMEN_KOJIN.KDM_GENMEN_2,
             KDM_GENMEN_3  = RlGENMEN_KOJIN.KDM_GENMEN_3
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
                                               - RlEXT.KDM_NENREI_KEIGEN    -- 年齢軽減
                                               - NlNENZEIGAKU;              -- 月割後の年税額

      RlKIHON.GENGAKU_KEI   :=                   RlKIHON.GENDO_CHOKA        -- 限度超過
                                               + RlKIHON.KEIGEN_K_WARI      -- 均等割り
                                               + RlKIHON.KEIGEN_B_WARI      -- 平等割
                                               + RlEXT.KDM_NENREI_KEIGEN    -- 年齢軽減
                                               + RlKIHON.TSUKIWARI_GEN;     -- 月割り減

      -- 身障減免有り
      IF NlSINSHO_GENMEN = 1  THEN

        -- 障害者が世帯に1人以上存在
        IF NlShogai_CNT > 0 THEN

          -- 障害者減免額 = 支援保険料(積算税額-減額合計)*障害減免率  (少数点切り上げ) ※障害減免率はZLBSKCALMAINでセットしている為
          IF (RlKIHON.SEKISAN - RlKIHON.GENGAKU_KEI) > 0 THEN
            RlEXT.KDM_SHOGAI_GENMEN := TRUNC((RlKIHON.SEKISAN - RlKIHON.GENGAKU_KEI) * (RlEXT.SHOGAI_RITSU/100) + 0.9);
          ELSE
            RlEXT.KDM_SHOGAI_GENMEN := 0;
          END IF;
        END IF;

      END IF;

    END subShogaiGenmen;

-------------------------------------------------------------------------------
-- 27 減免額（全体）の取得処理
-------------------------------------------------------------------------------
    PROCEDURE funcGetGenmen IS
        BFOUND  BOOLEAN := FALSE;
        CURSOR CKIHON_1ST IS
          SELECT TSUCHI_NO, GENMEN
            FROM ZLBTKDM_KIHON_N
            WHERE KOKU_SETAI_NO   = i_NSETAI      --国保世帯番号
              AND SANTEIDANTAI_CD = i_NDANTAI     --算定団体
              AND CHOTEI_NENDO    = i_NNENDO      --調定年度
              AND NENDO_BUN       = i_NNENDO_BUN  --年度分
              AND NUSHI_KOJIN_NO  = DECODE(NlJNUSHI, 0, NUSHI_KOJIN_NO, i_NNUSHI);  -- 主課税でないときは主個人番号で絞り込まない
        CURSOR CKIHON_2ND IS
          SELECT TSUCHI_NO, GENMEN
            FROM ZLBTKDM_KIHON_N
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
            VlMSG := 'funcGetGenmen 減免額（全体）の取得(国保世帯番号='||i_NSETAI||')'||SQLERRM;
    END funcGetGenmen;

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
           AND TEKIYO_KBN IN (1, 3)
           AND KOKU_SETAI_NO = i_NSETAI
           AND NENDO_BUN =i_NNENDO_BUN;

        IF nCNT = 1 THEN
          IF NlJNUSHI = 0 OR IGENMENNUSHI_KBN = 0 THEN --減免計算フラグ0の場合(既存処理)
            OPEN cur_DynamicSQL FOR 'SELECT * FROM ZLBTGENMEN_KOJIN_TMP
                                     WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                     AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                     AND   NENDO_BUN       = :NENDO_BUN
                                     AND   KOJIN_NO        = :KOJIN_NO
                                     AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO'
                                USING i_RwKOJIN.KOKU_SETAI_NO, i_RwKOJIN.SANTEIDANTAI_CD, i_RwKOJIN.NENDO_BUN, i_RwKOJIN.KOJIN_NO, i_RwKOJIN.SYS_TANMATSU_NO;
          ELSIF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN -- 世帯主課税かつ減免計算条件1の場合
            IF nCNTG > 0 THEN--優先区分0:個人/率/応能応益の件数が0より大きい場合
              OPEN cur_DynamicSQL FOR 'SELECT * FROM ZLBTGENMEN_KOJIN_TMP
                                       WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                       AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                       AND   NENDO_BUN       = :NENDO_BUN
                                       AND   KOJIN_NO        = :KOJIN_NO
                                       AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO'
                                  USING i_RwKOJIN.KOKU_SETAI_NO, i_RwKOJIN.SANTEIDANTAI_CD, i_RwKOJIN.NENDO_BUN, i_RwKOJIN.KOJIN_NO, i_RwKOJIN.SYS_TANMATSU_NO;
            ELSE--優先区分0:個人/率/応能応益のデータ登録以外の場合
              OPEN cur_DynamicSQL FOR 'SELECT * FROM ZLBTGENMEN_KOJIN_TMP
                                       WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                       AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                       AND   NENDO_BUN       = :NENDO_BUN
                                       AND   KOJIN_NO        = :KOJIN_NO
                                       AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO
                                       AND   TSUCHI_NO       = :TSUCHI_NO'
                                  USING i_RwKOJIN.KOKU_SETAI_NO, i_RwKOJIN.SANTEIDANTAI_CD, i_RwKOJIN.NENDO_BUN, i_RwKOJIN.KOJIN_NO, i_RwKOJIN.SYS_TANMATSU_NO, i_NNUSHI;
            END IF;
          END IF;
            LOOP

                FETCH cur_DynamicSQL INTO RwGENMENKOJIN;
                EXIT WHEN cur_DynamicSQL%NOTFOUND;

                nRTN := 1;
                EXIT;

            END LOOP;

            CLOSE cur_DynamicSQL;

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

        -- 年齢軽減
        IF NNENREI_KEIGEN > 0 THEN
            RlEXT.KDM_NENREI_KEIGEN := NNENREI_KEIGEN;
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
        -- 18歳以上軽減均等割額ありの場合
        IF NlKEIGEN_KINTO18 > 0 THEN
            NlKEIGEN_KINTO18 := NlKEIGEN_KINTO18 + 0.01;
            RlEXT.KDM18_KEIGEN_KINTOWARI := TRUNC(NlKEIGEN_KINTO18);
        END IF;
        -- 18歳未満軽減均等割額ありの場合
        IF NlKEIGEN_KINTO18UN > 0 THEN
            NlKEIGEN_KINTO18UN := NlKEIGEN_KINTO18UN + 0.01;
            RlEXT.KDM18UN_KEIGEN_KINTOWARI := NlKEIGEN_KINTO18UN;
        END IF;

        NlKEIGEN_KINTO := 0;
        NlKEIGEN_BYODO := 0;
        NlKEIGEN_K_6_ZEN := 0;  -- 軽減均等6 全体
        NlKEIGEN_B_6_ZEN := 0;  -- 軽減平等6 全体
        NlKEIGEN_K_4_ZEN := 0;  -- 軽減均等4 全体
        NlKEIGEN_B_4_ZEN := 0;  -- 軽減平等4 全体
        NlKEIGEN_K_2_ZEN := 0;  -- 軽減均等2 全体
        NlKEIGEN_B_2_ZEN := 0;  -- 軽減平等2 全体
        NNENREI_KEIGEN   := 0;
        NlKEIGEN_KINTO18 := 0;
        NlKEIGEN_KINTO18UN := 0;

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
            NlNENZEIGAKU := NlNENZEIGAKU +
                            ((MlZEIGAKU(NwIX) * MlTUKI(NwIX) ) / 12);
          END IF;
        END LOOP;

        IF ITSUKI_HASU_KBN = 1 THEN
          NlNENZEIGAKU := NNENZEIGAKU_2;
        END IF;

        IF ITSUKI_HASU_KBN = 3 THEN
          NlNENZEIGAKU := NlNENZEIGAKU;
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

-------------------------------------------------------------------------------
-- 産前産後限度超過計算
-------------------------------------------------------------------------------
    PROCEDURE subSanChokaCal(NwIX IN PLS_INTEGER)
    IS
      RlKANWAKOJIN          ZLBTKANWA_KOJIN_CAL%ROWTYPE; -- 計算緩和個人
      MwGENMENKOJIN         MTNUMARRAY12;                -- 対象月の減免有無
      SAN_CNT               NUMBER(2);                   -- 産前産後月数カウンタ
      SAN_18UN              NUMBER(10);                  -- 均等割額に関する18歳未満のものの産前産後軽減額
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
            -- 対象月の減免有無(1～12) = 減免個人情報.支援減免(4～3)月
            MwGENMENKOJIN(1)   := NVL(RwGENMENKOJIN.KDM_GENMEN_4,0);
            MwGENMENKOJIN(2)   := NVL(RwGENMENKOJIN.KDM_GENMEN_5,0);
            MwGENMENKOJIN(3)   := NVL(RwGENMENKOJIN.KDM_GENMEN_6,0);
            MwGENMENKOJIN(4)   := NVL(RwGENMENKOJIN.KDM_GENMEN_7,0);
            MwGENMENKOJIN(5)   := NVL(RwGENMENKOJIN.KDM_GENMEN_8,0);
            MwGENMENKOJIN(6)   := NVL(RwGENMENKOJIN.KDM_GENMEN_9,0);
            MwGENMENKOJIN(7)   := NVL(RwGENMENKOJIN.KDM_GENMEN_10,0);
            MwGENMENKOJIN(8)   := NVL(RwGENMENKOJIN.KDM_GENMEN_11,0);
            MwGENMENKOJIN(9)   := NVL(RwGENMENKOJIN.KDM_GENMEN_12,0);
            MwGENMENKOJIN(10)  := NVL(RwGENMENKOJIN.KDM_GENMEN_1,0);
            MwGENMENKOJIN(11)  := NVL(RwGENMENKOJIN.KDM_GENMEN_2,0);
            MwGENMENKOJIN(12)  := NVL(RwGENMENKOJIN.KDM_GENMEN_3,0);
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
         -- 均等割額に関する18歳未満のものの産前産後軽減額
         SAN_18UN := 0;

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
               IF RwKOJINSAN.KDM_18_KBN = 1 THEN

                 MlZEIGAKU(NwIX)   := MlZEIGAKU(NwIX)   - CEIL(NlJKINTO / 12 * SAN_CNT);
                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + CEIL(NlJKINTO18 / 12 * SAN_CNT);
               ELSE
                 SAN_18UN          := SAN_18UN + CEIL(NlJKINTO / 12 * SAN_CNT);
               END IF;
             -- 軽減6割の場合
             -- 積算算出用 税額 = 積算算出用 税額 - 切り上げ(均等割額  / 12 * 産前産後月数カウンタ)
             ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
--2025/10/11 ZCZL.LIUHUAJUN DELETE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - CEIL(NlJKINTO / 12 * SAN_CNT);
               IF RwKOJINSAN.KDM_18_KBN = 1 THEN
--2025/10/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
                 MlZEIGAKU(NwIX)   := MlZEIGAKU(NwIX) - CEIL(NlJKINTO / 12 * SAN_CNT);
                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + CEIL(NlJKINTO18 / 12 * SAN_CNT);
               ELSE
                 SAN_18UN          := SAN_18UN + CEIL(NlJKINTO / 12 * SAN_CNT);
               END IF;
             -- 軽減2割の場合
             -- 積算算出用 税額 = 積算算出用 税額 - 切り上げ(均等割額 * 70 / 100 / 12 * 産前産後月数カウンタ)
             ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
--2025/10/11 ZCZL.LIUHUAJUN DELETE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - CEIL(NlJKINTO * 70 / 100 / 12 * SAN_CNT);
               IF RwKOJINSAN.KDM_18_KBN = 1 THEN
--2025/10/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
                 MlZEIGAKU(NwIX)   := MlZEIGAKU(NwIX) - CEIL(NlJKINTO * 70 / 100 / 12 * SAN_CNT);
                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + CEIL(NlJKINTO18  * 70 / 100 / 12 * SAN_CNT);
               ELSE
                 SAN_18UN          := SAN_18UN + CEIL(NlJKINTO  * 70 / 100 / 12 * SAN_CNT);
               END IF;
             -- 上記以外の場合
             -- 積算算出用 税額 = 積算算出用 税額 - 切り上げ(均等割額 * 50 / 100 / 12 * 産前産後月数カウンタ)
             ELSE
--2025/10/11 ZCZL.LIUHUAJUN DELETE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - CEIL(NlJKINTO * 50 / 100 / 12 * SAN_CNT);
               IF RwKOJINSAN.KDM_18_KBN = 1 THEN
--2025/10/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
                 MlZEIGAKU(NwIX)   := MlZEIGAKU(NwIX) - CEIL(NlJKINTO * 50 / 100 / 12 * SAN_CNT);
                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + CEIL(NlJKINTO18  * 50 / 100 / 12 * SAN_CNT);
               ELSE
                 SAN_18UN          := SAN_18UN + CEIL(NlJKINTO  * 50 / 100 / 12 * SAN_CNT);
               END IF;
             END IF;
           -- 上記以外の場合(旧被扶養者以外)
           ELSE
             -- 計算回数カウンタが1の場合
             IF NLOOP_CNT_NOW = 1 THEN
               -- 引数.ループ回数月の失業者区分が0より大きい場合
               -- 積算算出用 税額 = 積算算出用 税額 + TRUNC(計算個人.失業軽減適用後課税標準額 * 支援所得割率２ / 100 * 引数.ループ回数月の応能係数 / 100)
               IF MlSHITSU_KBN(NwIX) > 0 THEN
                 MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC(RwKOJINSAN.SHITSU_KAHYO * NSHOTOKU_KDM / 100 * MlOUNOU(NwIX) / 100);
               -- 上記以外の場合
               -- 積算算出用 税額 = 積算算出用 税額 + TRUNC(計算個人.課税標準額 * 支援所得割率２ / 100 * 引数.ループ回数月の応能係数 / 100)
               ELSE
                  MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC(RwKOJINSAN.KAHYO * NSHOTOKU_KDM / 100 * MlOUNOU(NwIX) / 100);
               END IF;
             -- 計算回数カウンタが2の場合
             ELSIF NLOOP_CNT_NOW = 2 THEN
               -- 引数.ループ回数月の失業者区分が0より大きい場合
               -- 積算算出用 税額 = 積算算出用 税額 + TRUNC(計算個人.失業軽減適用後課税標準額 * 支援所得割率２ / 100
               --                                           - 失業軽減適用後課税標準額 * 支援所得割率２ / 100 * 引数.ループ回数月の減免有無 * 減免個人情報.所得割減免率(支援) / 100)
               IF MlSHITSU_KBN(NwIX) > 0 THEN
                 MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC( RwKOJINSAN.SHITSU_KAHYO * NSHOTOKU_KDM / 100
                                                           - RwKOJINSAN.SHITSU_KAHYO * NSHOTOKU_KDM / 100 * MwGENMENKOJIN(NwIX) * RwGENMENKOJIN.KDM_SHOTOKU_RITSU / 100);
               -- 上記以外の場合
               -- 積算算出用 税額 = 積算算出用 税額 + TRUNC(計算個人.課税標準額 * 支援所得割率２ / 100
               --                                           - 課税標準額 * 支援所得割率２ / 100 * 引数.ループ回数月の減免有無 * 減免個人情報.所得割減免率(支援) / 100)
               ELSE
                 MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC( RwKOJINSAN.KAHYO * NSHOTOKU_KDM / 100
                                                           - RwKOJINSAN.KAHYO * NSHOTOKU_KDM / 100 * MwGENMENKOJIN(NwIX) * RwGENMENKOJIN.KDM_SHOTOKU_RITSU / 100);
               END IF;
             ELSE
               NULL;
             END IF;

             -- 積算算出用 税額 = 積算算出用 税額 - 計算個人.支援産前産後所得割軽減 - 切り上げ(均等割額 / 12 * 産前産後月数カウンタ)
             IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
--2025/10/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.KDM_SAN_GEN_SHOTOKU - NlJKGEN1 - CEIL((NlJKINTO - NlJKGEN1) / 12 * SAN_CNT);
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.KDM_SAN_GEN_SHOTOKU;  -- 産前産後所得割軽減額は年齢に関わらず減額
               IF RwKOJINSAN.KDM_18_KBN = 1 THEN
--2025/10/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + CEIL((NlJKINTO18 - NlJKGEN118) / 12 * SAN_CNT);
                 MlZEIGAKU(NwIX)   := MlZEIGAKU(NwIX) - NlJKGEN1 - CEIL((NlJKINTO - NlJKGEN1) / 12 * SAN_CNT);
                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + NlJKGEN118 + CEIL((NlJKINTO18 - NlJKGEN118) / 12 * SAN_CNT);
--2025/10/11 ZCZL.LIUHUAJUN UPDATE END
               ELSE
--2025/10/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 SAN_18UN          := SAN_18UN + CEIL((NlJKINTO - NlJKGEN1) / 12 * SAN_CNT);
                 SAN_18UN          := SAN_18UN + NlJKGEN1 + CEIL((NlJKINTO - NlJKGEN1) / 12 * SAN_CNT);
               END IF;
             ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
--2025/10/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.KDM_SAN_GEN_SHOTOKU - NlJKGEN2 - CEIL((NlJKINTO - NlJKGEN2) / 12 * SAN_CNT);
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.KDM_SAN_GEN_SHOTOKU;  -- 産前産後所得割軽減額は年齢に関わらず減額
               IF RwKOJINSAN.KDM_18_KBN = 1 THEN
--2025/10/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + CEIL((NlJKINTO18 - NlJKGEN218)/ 12 * SAN_CNT);
                 MlZEIGAKU(NwIX)   := MlZEIGAKU(NwIX) - NlJKGEN2 - CEIL((NlJKINTO - NlJKGEN2) / 12 * SAN_CNT);
                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + NlJKGEN218 + CEIL((NlJKINTO18 - NlJKGEN218) / 12 * SAN_CNT);
--2025/10/11 ZCZL.LIUHUAJUN UPDATE END
               ELSE
--2025/10/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 SAN_18UN          := SAN_18UN + CEIL((NlJKINTO - NlJKGEN2) / 12 * SAN_CNT);
                 SAN_18UN          := SAN_18UN + NlJKGEN2 + CEIL((NlJKINTO - NlJKGEN2) / 12 * SAN_CNT);
               END IF;
             ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
--2025/10/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.KDM_SAN_GEN_SHOTOKU - NlJKGEN3 - CEIL((NlJKINTO - NlJKGEN3) / 12 * SAN_CNT);
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.KDM_SAN_GEN_SHOTOKU;  -- 産前産後所得割軽減額は年齢に関わらず減額
               IF RwKOJINSAN.KDM_18_KBN = 1 THEN
--2025/10/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + CEIL((NlJKINTO18 - NlJKGEN318)/ 12 * SAN_CNT);
                 MlZEIGAKU(NwIX)   := MlZEIGAKU(NwIX) - NlJKGEN3 - CEIL((NlJKINTO - NlJKGEN3) / 12 * SAN_CNT);
                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + NlJKGEN318 + CEIL((NlJKINTO18 - NlJKGEN318) / 12 * SAN_CNT);
--2025/10/11 ZCZL.LIUHUAJUN UPDATE END
               ELSE
--2025/10/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 SAN_18UN          := SAN_18UN + CEIL((NlJKINTO - NlJKGEN3) / 12 * SAN_CNT);
                 SAN_18UN          := SAN_18UN + NlJKGEN3 + CEIL((NlJKINTO - NlJKGEN3) / 12 * SAN_CNT);
               END IF;
             ELSE
--2025/10/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.KDM_SAN_GEN_SHOTOKU - CEIL(NlJKINTO / 12 * SAN_CNT);
               MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - RwKOJINSAN.KDM_SAN_GEN_SHOTOKU;  -- 産前産後所得割軽減額は年齢に関わらず減額
               IF RwKOJINSAN.KDM_18_KBN = 1 THEN
--2025/10/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
                 MlZEIGAKU(NwIX)   := MlZEIGAKU(NwIX) - CEIL(NlJKINTO / 12 * SAN_CNT);
                 MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + CEIL(NlJKINTO18 / 12 * SAN_CNT);
               ELSE
                 SAN_18UN          := SAN_18UN + CEIL(NlJKINTO / 12 * SAN_CNT);
               END IF;
             END IF;
           END IF;
         END IF;
      END LOOP;

      -- 2.産前産後者以外の均等割軽減、平等割軽減、未就学児減免を適用する。
      -- 軽減7割の場合
      IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
        -- ①対象区分 = 1 のとき、特定同一時の軽減を行う。
        IF MlTAISHO_KBN(NwIX) = 1 THEN
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割1(6割) + 特定同一 軽減平等割1(7,6割))
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN1 + NlJBGEN_T1);
        -- ②対象区分 = 8 のとき、特定同一(2)の軽減を行う。
        ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割1(6割) + 特定同一(2) 軽減平等割1(7,6割))
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN1 + NlJBGEN2_T1);
        -- ③上記以外のとき
        ELSE
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割1(6割) + 軽減平等割1(6割))
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN1 + NlJBGEN1);
        END IF;
        --18歳以上均等割額に関わる産前産後以外の軽減額(257軽減額)を累積する
        MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN118);
      -- 軽減5割の場合
      ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
        -- ①対象区分 = 1 のとき、特定同一時の軽減を行う。
        IF MlTAISHO_KBN(NwIX) = 1 THEN
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割2(4割)  + 特定同一 軽減平等割2(5,4割))
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN2 + NlJBGEN_T2);
        -- ②対象区分 = 8 のとき、特定同一(2)の軽減を行う。
        ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割2(4割) + 特定同一(2) 軽減平等割2(5,4割))
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN2 + NlJBGEN2_T2);
        -- ③上記以外のとき
        ELSE
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割2(4割) + 軽減平等割2(4割))
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN2 + NlJBGEN2);
        END IF;
        --18歳以上均等割額に関わる産前産後以外の軽減額(257軽減額)を累積する
        MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN218);
      -- 軽減2割の場合
      ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
        -- ①対象区分 = 1 のとき、特定同一時の軽減を行う。
        IF MlTAISHO_KBN(NwIX) = 1 THEN
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割3(2割)  + 特定同一 軽減平等割3(2割))
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN3 + NlJBGEN_T3);
        -- ②対象区分 = 8 のとき、特定同一(2)の軽減を行う。
        ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割3(2割) + 特定同一(2) 軽減平等割3(2割))
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN3 + NlJBGEN2_T3);
        -- ③上記以外のとき
        ELSE
          -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割3(2割) + 軽減平等割3(2割))
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN3 + NlJBGEN3);
        END IF;
        --18歳以上均等割額に関わる産前産後以外の軽減額(257軽減額)を累積する
        MlZEIGAKU18(NwIX) := MlZEIGAKU18(NwIX) + ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN318);
      END IF;

      -- 3.産前産後かつ限度超過の対象とならない場合を計算する。
      -- 積算算出用 税額－(18歳以上均等割額に関わる均等割軽減額)がシステム条件.限度額未満の場合、
      IF (MlZEIGAKU(NwIX) - MlZEIGAKU18(NwIX))< NlJGENDOGAKU THEN
        MlZEIGAKU(NwIX) := MlZEIGAKU_MOTO(NwIX);

        -- 軽減7割の場合
        IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
          -- ①対象区分 = 1 のとき、特定同一時の軽減を行う。
          IF MlTAISHO_KBN(NwIX) = 1 THEN
            -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割1(6割) + 特定同一 軽減平等割1(7,6割))
            --                                   - 各月産前産後有資格者数 * 均等割額
            --                                   - 各月旧被扶養者兼産前産後者数 * 均等割額
            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN1 + NlJBGEN_T1)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * NlJKINTO;
          -- ②対象区分 = 8 のとき、特定同一(2)の軽減を行う。
          ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
            -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割1(6割) + 特定同一(2) 軽減平等割1(7,6割))
            --                                   - 各月産前産後有資格者数 * 均等割額
            --                                   - 各月旧被扶養者兼産前産後者数 * 均等割額
            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN1 + NlJBGEN2_T1)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * NlJKINTO;
          -- ③上記以外のとき
          ELSE
            -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割1(6割) + 軽減平等割1(6割))
            --                                   - 各月産前産後有資格者数 * 均等割額
            --                                   - 各月旧被扶養者兼産前産後者数 * 均等割額
            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN1 + NlJBGEN1)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * NlJKINTO;
          END IF;
          MlZEIGAKU18(NwIX) := 0;
          MlZEIGAKU218(NwIX) := 0;
        -- 軽減5割の場合
        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
          -- ①対象区分 = 1 のとき、特定同一時の軽減を行う。
          IF MlTAISHO_KBN(NwIX) = 1 THEN
            -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割2(4割)  + 特定同一 軽減平等割2(5,4割))
            --                                   - 各月産前産後有資格者数 * 均等割額
            --                                   - 各月旧被扶養者兼産前産後者数 * 均等割額
            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN2 + NlJBGEN_T2)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * NlJKINTO;
          -- ②対象区分 = 8 のとき、特定同一(2)の軽減を行う。
          ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
            -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割2(4割) + 特定同一(2) 軽減平等割2(5,4割))
            --                                   - 各月産前産後有資格者数 * 均等割額
            --                                   - 各月旧被扶養者兼産前産後者数 * 均等割額
            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN2 + NlJBGEN2_T2)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * NlJKINTO;
          -- ③上記以外のとき
          ELSE
            -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割2(4割) + 軽減平等割2(4割))
            --                                   - 各月産前産後有資格者数 * 均等割額
            --                                   - 各月旧被扶養者兼産前産後者数 * 均等割額
            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN2 + NlJBGEN2)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * NlJKINTO;
          END IF;
          MlZEIGAKU18(NwIX) := 0;
          MlZEIGAKU218(NwIX) := 0;
        -- 軽減2割の場合
        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
          -- ①対象区分 = 1 のとき、特定同一時の軽減を行う。
          IF MlTAISHO_KBN(NwIX) = 1 THEN
            -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割3(2割)  + 特定同一 軽減平等割3(2割))
            --                                   - 各月産前産後有資格者数 * 均等割額
            --                                   - 各月旧被扶養者兼産前産後者数 * 切り上げ(均等割額 * 70 / 100)
            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN3 + NlJBGEN_T3)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * CEIL( NlJKINTO * 70 /100);
          -- ②対象区分 = 8 のとき、特定同一(2)の軽減を行う。
          ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
            -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割3(2割) + 特定同一(2) 軽減平等割3(2割))
            --                                   - 各月産前産後有資格者数 * 均等割額
            --                                   - 各月旧被扶養者兼産前産後者数 * 切り上げ(均等割額 * 70 / 100)
            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN3 + NlJBGEN2_T3)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * CEIL( NlJKINTO * 70 /100);
          -- ③上記以外のとき
          ELSE
            -- 積算算出用 税額 = 積算算出用 税額 - ((人員(各月有資格者数) - 各月産前産後有資格者数 - 各月旧被扶養者兼産前産後者数) * 軽減均等割3(2割) + 軽減平等割3(2割))
            --                                   - 各月産前産後有資格者数 * 均等割額
            --                                   - 各月旧被扶養者兼産前産後者数 * 切り上げ(均等割額 * 70 / 100)
            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN3 + NlJBGEN3)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * CEIL( NlJKINTO * 70 /100);
          END IF;
          MlZEIGAKU18(NwIX) := 0;
          MlZEIGAKU218(NwIX) := 0;
        -- 上記以外の場合
        ELSE
          -- 積算算出用 税額 = 積算算出用 税額 - 各月産前産後有資格者数 * 均等割額
          --                                   - 各月旧被扶養者兼産前産後者数 * 切り上げ(均等割額 * 50 / 100)
          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - (MlSANCNT18(NwIX) * NlJKINTO)
                                               - (MlSANCNT_K18(NwIX) * CEIL(NlJKINTO * 50 /100));
--2025/10/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
          MlZEIGAKU18(NwIX) := 0;
          MlZEIGAKU218(NwIX) := 0;
--2025/10/11 ZCZL.LIUHUAJUN ADD END
        END IF;
      --限度超過している場合の限度超過額調整用
      ELSE
        NwSANCHOKA_FLG := 1;
        MlZEIGAKU2(NwIX) := MlZEIGAKU_MOTO(NwIX);
        IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
          MlZEIGAKU2(NwIX) := MlZEIGAKU2(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN1 + NlJBGEN1)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * NlJKINTO;
          --18歳以上均等割額に関わる軽減額(257軽減/産前産後軽減)を算出し、MlZEIGAKU218(NwIX)に格納する
          MlZEIGAKU218(NwIX) := ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN118)
                                + (MlSANCNT18(NwIX) * NlJKINTO18) + (MlSANCNT_K18(NwIX) * NlJKINTO18);
        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
          MlZEIGAKU2(NwIX) := MlZEIGAKU2(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN2 + NlJBGEN2)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * NlJKINTO;
          --18歳以上均等割額に関わる軽減額(257軽減/産前産後軽減)を算出し、MlZEIGAKU218(NwIX)に格納する
          MlZEIGAKU218(NwIX) := ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN218)
                                + (MlSANCNT18(NwIX) * NlJKINTO18) + (MlSANCNT_K18(NwIX) * NlJKINTO18);
        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
          MlZEIGAKU2(NwIX) := MlZEIGAKU2(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN3 + NlJBGEN3)
                                               - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * CEIL( NlJKINTO * 70 /100);
          --18歳以上均等割額に関わる軽減額(257軽減/産前産後軽減)を算出し、MlZEIGAKU218(NwIX)に格納する
          MlZEIGAKU218(NwIX) := ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN318)
                                + (MlSANCNT18(NwIX) * NlJKINTO18) + (MlSANCNT_K18(NwIX) * CEIL(NlJKINTO18 * 70 / 100));
        ELSE
          MlZEIGAKU2(NwIX) := MlZEIGAKU2(NwIX) - MlSANCNT18(NwIX) * NlJKINTO
                                               - MlSANCNT_K18(NwIX) * CEIL(NlJKINTO * 50 /100);
          --18歳以上均等割額に関わる軽減額(257軽減/産前産後軽減)を算出し、MlZEIGAKU218(NwIX)に格納する
          MlZEIGAKU218(NwIX) := (MlSANCNT18(NwIX) * NlJKINTO18) + (MlSANCNT_K18(NwIX) * CEIL(NlJKINTO18 * 50 / 100));
        END IF;
        IF (MlZEIGAKU2(NwIX) - MlZEIGAKU218(NwIX)) >= NlJGENDOGAKU THEN
          MlZEIGAKU(NwIX) := MlZEIGAKU2(NWIX); --修正前仕様でも賦課限度の場合、限度超過額調整のため、こちらを使用
          NwSANCHOKA_FLG := 0;
          MlZEIGAKU18(NwIX) := 0;
          MlZEIGAKU218(NwIX) := 0;
        END IF;
      END IF;
    END subSanChokaCal;
-------------------------------------------------------------------------------
-- 18 月割税額セット(基本)
-------------------------------------------------------------------------------
    PROCEDURE subTukiwari IS
        NwIX            NUMBER(2);
        NKAHYO_DOWN     NUMBER;
        NKAHYO_OVER     NUMBER;
        RlKANWASETAI ZLBTKANWA_SETAI_CAL%ROWTYPE;
        MwlSUMI_K       MTNUMARRAY1;              -- 済(経過措置用)
        MwlTUKI_K       MTNUMARRAY2;              -- 月数(経過措置用)
        MwlOUEKI_KIND   MTNUMARRAY3;              -- 応益係数
        NwWORK          NUMBER(10);
        NwWORK18        NUMBER(12);            -- 18歳以上/18歳未満一時WORK
        MwGENMEN_UMU         MTNUMARRAY1;      -- 各月減免有無
        NwBYODOWARI          NUMBER(12) := 0;
        NwSHOTOKU_GENGAKU    NUMBER(12) := 0;  --計算用所得割減免額
        NwSISANZEI_GENGAKU   NUMBER(12) := 0;  --計算用資産割減免額
        NwKINTOWARI_GENGAKU  NUMBER(12) := 0;  --計算用均等割減免額
        NwKINTOWARI18_GENGAKU NUMBER(12) := 0; --計算用18歳以上均等割減免額
        NwBYODOWARI_GENGAKU  NUMBER(12) := 0;  --計算用平等割減免額
        NKODOMO_KEIGEN_GAKU   NUMBER     := 0;  -- 子ども均等割軽減額
-- 2025/12/04 ZCZL.MUZHILIN UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--         MwSAN_K_KEIGEN   MTNUMARRAY15F;          -- 各月産前産後均等割軽減額
--         MwSAN_K_KEIGEN2  MTNUMARRAY15F;          -- 各月旧被扶養者兼産前産後均等割軽減額
        MwSAN_K_KEIGEN   MTNUMARRAY17F;          -- 各月産前産後均等割軽減額
        MwSAN_K_KEIGEN2  MTNUMARRAY17F;          -- 各月旧被扶養者兼産前産後均等割軽減額
-- 2025/12/04 ZCZL.MUZHILIN UPDATE END
        NwSAN_K_GENKEI   NUMBER(15,3) := 0;      -- 産前産後均等割軽減額計
        NwSAN_K_GENKEI2  NUMBER(15,3) := 0;      -- 産前産後均等割軽減額計_計算個人
        NwSAN_SAGAKU     NUMBER(3);              -- 産前産後均等割軽減額差額
-- 2025/12/04 ZCZL.MUZHILIN UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--         MwSAN_K_KEIGEN18     MTNUMARRAY15F;      -- 各月産前産後均等割軽減額(18歳以上)
--         MwSAN_K_KEIGEN218    MTNUMARRAY15F;      -- 各月旧被扶養者兼産前産後均等割軽減額(18歳以上)
        MwSAN_K_KEIGEN18     MTNUMARRAY17F;      -- 各月産前産後均等割軽減額(18歳以上)
        MwSAN_K_KEIGEN218    MTNUMARRAY17F;      -- 各月旧被扶養者兼産前産後均等割軽減額(18歳以上)
-- 2025/12/04 ZCZL.MUZHILIN UPDATE END
        NwSAN_K_GENKEI18     NUMBER(15,3) := 0;  -- 産前産後均等割軽減額計(18歳以上)
        NwSAN_K_GENKEI218    NUMBER(15,3) := 0;  -- 産前産後均等割軽減額計_計算個人(18歳以上)
        NwSAN_SAGAKU18       NUMBER(3);          -- 産前産後均等割軽減額差額(18歳以上)
-- 2025/12/04 ZCZL.MUZHILIN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
        MwKODOMO_KEIGEN_GAKU MTNUMARRAY17F;      -- 各月未就学児軽減額
-- 2025/12/04 ZCZL.MUZHILIN UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--         Mw18UN_KEIGEN_KITO   MTNUMARRAY15F;      -- 各月18歳未満均等割軽減額
--         Mw257GEN             MTNUMARRAY15F;      -- 各月均等割額に対する257軽減(世帯員より異なる産前産後軽減、未就学児軽減による軽減を除いた額)
--         Mw257GEN18           MTNUMARRAY15F;      -- 各月18歳以上均等割額に対する257軽減(世帯員より異なる産前産後軽減による軽減を除いた額)
        Mw18UN_KEIGEN_KITO   MTNUMARRAY17F;      -- 各月18歳未満均等割軽減額
        Mw257GEN             MTNUMARRAY17F;      -- 各月均等割額に対する257軽減(世帯員より異なる産前産後軽減、未就学児軽減による軽減を除いた額)
        Mw257GEN18           MTNUMARRAY17F;      -- 各月18歳以上均等割額に対する257軽減(世帯員より異なる産前産後軽減による軽減を除いた額)
-- 2025/12/04 ZCZL.MUZHILIN UPDATE END
        NwCNT_K_MM           NUMBER(3) := 0;  --世帯内均等割月数
        NwCNT_K              NUMBER(3) := 0;  --世帯内均等割人数
        NwCNT_SAN_MM         NUMBER(3) := 0;  --世帯内産前産後月数
-- 2025/12/04 ZCZL.XIESHUN ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
        MwKEIGEN_KINTO       NUMBER(10,3);         -- 軽減均等       （一時計算用）
        MwKEIGEN_K_6_ZEN     NUMBER(10,3);         -- 軽減均等6 全体 （一時計算用）
        MwKEIGEN_K_4_ZEN     NUMBER(10,3);         -- 軽減均等4 全体 （一時計算用）
        MwKEIGEN_K_2_ZEN     NUMBER(10,3);         -- 軽減均等2 全体 （一時計算用）
        MwKEIGEN_K_N_ZEN     NUMBER(10,3);         -- 軽減均等無 全体（一時計算用）
        MwSAGAKU             NUMBER(3);            -- 汎用差額調整   （一時計算用）
-- 2025/12/04 ZCZL.XIESHUN ADD END
    BEGIN

        BEGIN
          SELECT * INTO RlKANWASETAI
            FROM ZLBTKANWA_SETAI_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI
             AND SYS_TANMATSU_NO = i_VTANMATSU;

          -- 計算緩和個人の各月応益係数を退避
          MlOUEKI(1)  := RlKANWASETAI.OUEKI_4;
          MlOUEKI(2)  := RlKANWASETAI.OUEKI_5;
          MlOUEKI(3)  := RlKANWASETAI.OUEKI_6;
          MlOUEKI(4)  := RlKANWASETAI.OUEKI_7;
          MlOUEKI(5)  := RlKANWASETAI.OUEKI_8;
          MlOUEKI(6)  := RlKANWASETAI.OUEKI_9;
          MlOUEKI(7)  := RlKANWASETAI.OUEKI_10;
          MlOUEKI(8)  := RlKANWASETAI.OUEKI_11;
          MlOUEKI(9)  := RlKANWASETAI.OUEKI_12;
          MlOUEKI(10) := RlKANWASETAI.OUEKI_1;
          MlOUEKI(11) := RlKANWASETAI.OUEKI_2;
          MlOUEKI(12) := RlKANWASETAI.OUEKI_3;
          -- 対象区分を退避
          MlTAISHO_KBN(1)  := RlKANWASETAI.TAISHO_KBN_4;
          MlTAISHO_KBN(2)  := RlKANWASETAI.TAISHO_KBN_5;
          MlTAISHO_KBN(3)  := RlKANWASETAI.TAISHO_KBN_6;
          MlTAISHO_KBN(4)  := RlKANWASETAI.TAISHO_KBN_7;
          MlTAISHO_KBN(5)  := RlKANWASETAI.TAISHO_KBN_8;
          MlTAISHO_KBN(6)  := RlKANWASETAI.TAISHO_KBN_9;
          MlTAISHO_KBN(7)  := RlKANWASETAI.TAISHO_KBN_10;
          MlTAISHO_KBN(8)  := RlKANWASETAI.TAISHO_KBN_11;
          MlTAISHO_KBN(9)  := RlKANWASETAI.TAISHO_KBN_12;
          MlTAISHO_KBN(10) := RlKANWASETAI.TAISHO_KBN_1;
          MlTAISHO_KBN(11) := RlKANWASETAI.TAISHO_KBN_2;
          MlTAISHO_KBN(12) := RlKANWASETAI.TAISHO_KBN_3;
        EXCEPTION  -- エラー時は100％をセット
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
            MlTAISHO_KBN(1)  := 0;
            MlTAISHO_KBN(2)  := 0;
            MlTAISHO_KBN(3)  := 0;
            MlTAISHO_KBN(4)  := 0;
            MlTAISHO_KBN(5)  := 0;
            MlTAISHO_KBN(6)  := 0;
            MlTAISHO_KBN(7)  := 0;
            MlTAISHO_KBN(8)  := 0;
            MlTAISHO_KBN(9)  := 0;
            MlTAISHO_KBN(10) := 0;
            MlTAISHO_KBN(11) := 0;
            MlTAISHO_KBN(12) := 0;
        END;
        --応益係数が同じ月数MwlTUKI_Kとその時点の応益係数MwlOUEKI_KINDを算出
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
        MwGENMEN_UMU(1)  := RlGENMEN_KOJIN.KDM_GENMEN_4;
        MwGENMEN_UMU(2)  := RlGENMEN_KOJIN.KDM_GENMEN_5;
        MwGENMEN_UMU(3)  := RlGENMEN_KOJIN.KDM_GENMEN_6;
        MwGENMEN_UMU(4)  := RlGENMEN_KOJIN.KDM_GENMEN_7;
        MwGENMEN_UMU(5)  := RlGENMEN_KOJIN.KDM_GENMEN_8;
        MwGENMEN_UMU(6)  := RlGENMEN_KOJIN.KDM_GENMEN_9;
        MwGENMEN_UMU(7)  := RlGENMEN_KOJIN.KDM_GENMEN_10;
        MwGENMEN_UMU(8)  := RlGENMEN_KOJIN.KDM_GENMEN_11;
        MwGENMEN_UMU(9)  := RlGENMEN_KOJIN.KDM_GENMEN_12;
        MwGENMEN_UMU(10) := RlGENMEN_KOJIN.KDM_GENMEN_1;
        MwGENMEN_UMU(11) := RlGENMEN_KOJIN.KDM_GENMEN_2;
        MwGENMEN_UMU(12) := RlGENMEN_KOJIN.KDM_GENMEN_3;
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
              MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX) + NKAHYO_OVER * NSSHOTOKU_KDM_OVER / 100;
              MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX) + NKAHYO_DOWN * NSHOTOKU_KDM / 100;
            END IF;

            NwWORK := MlZEIGAKU_SEKI(NwIX);

            -- 軽減均等・平等マイナス
            IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割の場合
              -- 特定同一時の軽減ルート
              IF MlTAISHO_KBN(NwIX) = 1 THEN
                NwWORK := NwWORK - (RlKIHON.KINTO_CNT_KDM18 * (NlJKGEN1 + NlJKGEN118) + NlJBGEN_T1);
              -- 特定同一(2)の軽減ルート
              ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
                NwWORK := NwWORK - (RlKIHON.KINTO_CNT_KDM18 * (NlJKGEN1 + NlJKGEN118) + NlJBGEN2_T1);
              ELSE
                NwWORK := NwWORK - (RlKIHON.KINTO_CNT_KDM18 * (NlJKGEN1 + NlJKGEN118)  + NlJBGEN1);
              END IF;
              --18歳未満の世帯員分は、均等割額の全額を軽減(257軽減＋未就学児+18歳未満均等割で全額が軽減となる)、
              --18歳以上均等割額は賦課しないので軽減なし
              NwWORK := NwWORK - (NlJKINTO * (RlKIHON.KINTO_CNT - RlKIHON.KINTO_CNT_KDM18));
            ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN    -- 軽減4割の場合
              -- 特定同一時の軽減ルート
              IF MlTAISHO_KBN(NwIX) = 1 THEN
                NwWORK := NwWORK - (RlKIHON.KINTO_CNT_KDM18 * (NlJKGEN2 + NlJKGEN218) + NlJBGEN_T2);
              -- 特定同一(2)の軽減ルート
              ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
                NwWORK := NwWORK - (RlKIHON.KINTO_CNT_KDM18 * (NlJKGEN2 + NlJKGEN218) + NlJBGEN2_T2);
              ELSE
                NwWORK := NwWORK - (RlKIHON.KINTO_CNT_KDM18 * (NlJKGEN2 + NlJKGEN218) + NlJBGEN2);
              END IF;
              --18歳未満の世帯員分は、均等割額の全額を軽減(257軽減＋未就学児+18歳未満均等割で全額が軽減となる)、
              --18歳以上均等割額は賦課しないので軽減なし
              NwWORK := NwWORK - (NlJKINTO * (RlKIHON.KINTO_CNT - RlKIHON.KINTO_CNT_KDM18));
            ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN    -- 軽減2割の場合
              -- 特定同一時の軽減ルート
              IF MlTAISHO_KBN(NwIX) = 1 THEN
                NwWORK := NwWORK - (RlKIHON.KINTO_CNT_KDM18 * (NlJKGEN3 + NlJKGEN318) + NlJBGEN_T3);
              -- 特定同一(2)の軽減ルート
              ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
                NwWORK := NwWORK - (RlKIHON.KINTO_CNT_KDM18 * (NlJKGEN3 + NlJKGEN318) + NlJBGEN2_T3);
              ELSE
                NwWORK := NwWORK - (RlKIHON.KINTO_CNT_KDM18 * (NlJKGEN3 + NlJKGEN318) + NlJBGEN3);
              END IF;
              --18歳未満の世帯員分は、均等割額の全額を軽減(257軽減＋未就学児+18歳未満均等割で全額が軽減となる)、
              --18歳以上均等割額は賦課しないので軽減なし
              NwWORK := NwWORK - (NlJKINTO * (RlKIHON.KINTO_CNT - RlKIHON.KINTO_CNT_KDM18));
            ELSE
                NwWORK := NwWORK - CEIL(NlJKINTO * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX);
                --18歳未満の世帯員分は、均等割額の全額を軽減(未就学児+18歳未満均等割で全額が軽減となる)、
                --18歳以上均等割額は賦課しないので軽減なし
                 NwWORK := NwWORK - (NlJKINTO * (RlKIHON.KINTO_CNT - RlKIHON.KINTO_CNT_KDM18));
            END IF;

            -- 年齢軽減月割り対応
            IF MlNEN_CNT_SEKI(NwIX) > 0 THEN
              IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
                NwWORK := NwWORK - (NlJKINTO + NlJKINTO18 - NlJKGEN1  - NlJKGEN118) / 2 * (MlNEN_CNT_SEKI(NwIX) - MlCNT18UN(NwIX));
              ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
                NwWORK := NwWORK - (NlJKINTO + NlJKINTO18 - NlJKGEN2  - NlJKGEN218) / 2 * (MlNEN_CNT_SEKI(NwIX) - MlCNT18UN(NwIX));
              ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
                NwWORK := NwWORK - (NlJKINTO + NlJKINTO18 - NlJKGEN3  - NlJKGEN318) / 2 * (MlNEN_CNT_SEKI(NwIX) - MlCNT18UN(NwIX));
              ELSE
                NwWORK := NwWORK - (NlJKINTO + NlJKINTO18) / 2 * (MlNEN_CNT_SEKI(NwIX) - MlCNT18UN(NwIX));
              END IF;
            END IF;

            IF MlCNT(NwIX) > 0 THEN         -- 対象月に有資格者あり

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
                      -- 特定同一の場合
                      IF MlTAISHO_KBN(NwIX) = 1 THEN
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN_T1)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                        NwBYODOWARI     := NwBYODOWARI
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN_T1)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                      -- 特定同一(2)の場合
                      ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2_T1)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                        NwBYODOWARI     := NwBYODOWARI
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2_T1)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                      ELSE
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN1)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                        NwBYODOWARI     := NwBYODOWARI
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN1)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                      END IF;
                    ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN    -- 軽減4割の場合
                      -- 特定同一の場合
                      IF MlTAISHO_KBN(NwIX) = 1 THEN
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN_T2)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                        NwBYODOWARI     := NwBYODOWARI
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN_T2)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                      -- 特定同一(2)の場合
                      ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2_T2)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                        NwBYODOWARI     := NwBYODOWARI
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2_T2)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                      ELSE
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                        NwBYODOWARI     := NwBYODOWARI
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                      END IF;
                    ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN    -- 軽減2割の場合
                      -- 特定同一の場合
                      IF MlTAISHO_KBN(NwIX) = 1 THEN
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN_T3)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                        NwBYODOWARI     := NwBYODOWARI
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN_T3)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                      -- 特定同一(2)の場合
                      ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2_T3)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                        NwBYODOWARI     := NwBYODOWARI
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN2_T3)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                      ELSE
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN3)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                        NwBYODOWARI     := NwBYODOWARI
                                         + TRUNC(TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                         - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100) - NlJBGEN3)
                                         * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                      END IF;
                    ELSE
                      MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                       + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
                      NwBYODOWARI     := NwBYODOWARI
                                       + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       - (TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100)
                                       * MwGENMEN_UMU(NwIX) * RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU / 100);
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
                  MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + NKAHYO_OVER * NSSHOTOKU_KDM_OVER / 100;
                  MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + NKAHYO_DOWN * NSHOTOKU_KDM / 100;
                END IF;


                IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割

                  -- 特定同一時の軽減ルート
                  IF MlTAISHO_KBN(NwIX) = 1 THEN
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN1 + NlJBGEN_T1)
                                                       - (MlSANCNT18(NwIX) * NlJKINTO) - (MlSANCNT_K18(NwIX) * NlJKINTO);
                    END IF;
                    NlKEIGEN_K_6_ZEN   := NlKEIGEN_K_6_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 / 12) + CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 / 12) + CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    -- 子ども均等割軽減額 = 子ども均等割軽減額 + 切り上げ((均等割額 ｰ 軽減均等割1(6割)) / システム条件.子ども均等割軽減率 / 100 * 子ども人数ワークの対象月人数 / 12)
                    NKODOMO_KEIGEN_GAKU  := NKODOMO_KEIGEN_GAKU +  CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN1 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO / 12 - NlJKGEN1 / 12);
                    -- 軽減平等
                    NlKEIGEN_B_6_ZEN   := NlKEIGEN_B_6_ZEN   + (NlJBGEN_T1 / 12);
                    NlKEIGEN_BYODO     := NlKEIGEN_BYODO     + (NlJBGEN_T1 / 12);
                  -- 特定同一(2)の軽減ルート
                  ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN1 + NlJBGEN2_T1)
                                                       - (MlSANCNT18(NwIX) * NlJKINTO) - (MlSANCNT_K18(NwIX) * NlJKINTO);
                    END IF;
                    NlKEIGEN_K_6_ZEN   := NlKEIGEN_K_6_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 / 12) + CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 / 12) + CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    -- 子ども均等割軽減額 = 子ども均等割軽減額 + 切り上げ((均等割額 ｰ 軽減均等割1(6割)) / システム条件.子ども均等割軽減率 / 100 * 子ども人数ワークの対象月人数 / 12)
                    NKODOMO_KEIGEN_GAKU  := NKODOMO_KEIGEN_GAKU + CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN1 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO / 12 - NlJKGEN1 / 12);
                    -- 軽減平等
                    NlKEIGEN_B_6_ZEN   := NlKEIGEN_B_6_ZEN   + (NlJBGEN2_T1 / 12);
                    NlKEIGEN_BYODO     := NlKEIGEN_BYODO     + (NlJBGEN2_T1 / 12);
                  ELSE
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN1 + NlJBGEN1)
                                                       - (MlSANCNT18(NwIX) * NlJKINTO) - (MlSANCNT_K18(NwIX) * NlJKINTO);
                    END IF;
                    NlKEIGEN_K_6_ZEN   := NlKEIGEN_K_6_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 / 12) + CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 / 12) + CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    -- 子ども均等割軽減額 = 子ども均等割軽減額 + 切り上げ((均等割額 ｰ 軽減均等割1(6割)) / システム条件.子ども均等割軽減率 / 100 * 子ども人数ワークの対象月人数 / 12)
                    NKODOMO_KEIGEN_GAKU  := NKODOMO_KEIGEN_GAKU + CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN1 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO / 12 - NlJKGEN1 / 12);
                   -- 軽減平等
                    NlKEIGEN_B_6_ZEN   := NlKEIGEN_B_6_ZEN   + (NlJBGEN1 / 12);
                    NlKEIGEN_BYODO     := NlKEIGEN_BYODO     + (NlJBGEN1 / 12);
                  END IF;
                  -- 18歳以上均等割額に関わる軽減額を算出し、各種軽減額に反映　(平等割軽減済のため、特定同一値に関わらず設定)
                  NwWORK18                := ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN118)
                                           + (MlSANCNT18(NwIX) * NlJKINTO18) + (MlSANCNT_K18(NwIX) * NlJKINTO18);
                  MlZEIGAKU(NwIX)         := MlZEIGAKU(NwIX) - NwWORK18;
                  NlKEIGEN_K_6_ZEN        := NlKEIGEN_K_6_ZEN + (NwWORK18 /12);
                  NlKEIGEN_KINTO          := NlKEIGEN_KINTO + (NwWORK18 /12);
                  NlKEIGEN_KINTO18        := NlKEIGEN_KINTO18 + (NwWORK18 /12);
                  MwSAN_K_KEIGEN18(NwIX)  := MlSANCNT18(NwIX) * (NlJKINTO18 / 12 - NlJKGEN118 / 12);
                  MwSAN_K_KEIGEN218(NwIX) := MlSANCNT_K18(NwIX) * (NlJKINTO18 / 12 - NlJKGEN118 / 12);
--2025/10/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                  Mw257GEN18(NwIX)        := NwWORK18 - MwSAN_K_KEIGEN18(NwIX) - MwSAN_K_KEIGEN218(NwIX);
--                  Mw257GEN18(NwIX)        := Mw257GEN18(NwIX) / MlCNT18(NwIX);
                  Mw257GEN18(NwIX)        := NlJKGEN118 / 12;          -- 18歳以上均等割額に関わる政令軽減(※DB反映時は産前産後対象者を除く)
--2025/10/11 ZCZL.LIUHUAJUN UPDATE END
                  -- 均等割額に関わる18歳未満軽減額を算出し、各種軽減額に反映　(平等割軽減済のため、特定同一値に関わらず設定)
                  -- (均等割額*18歳未満人数) - (18歳未満の257割均等割軽減)-(18歳未満の未就学児軽減)-(18歳未満の産前産後軽減)=賦課額(18歳未満なので、18歳未満均等割軽減額)
                  NwWORK18                := (NlJKINTO * MlCNT18UN(NwIX))
                                           - ((MlCNT18UN(NwIX) - MlSANCNT18UN(NwIX) - MlSANCNT_K18UN(NwIX)) * NlJKGEN1)
                                           - (CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX))
                                           - (MlSANCNT18UN(NwIX) * NlJKINTO ) - (MlSANCNT_K18UN(NwIX) * NlJKINTO );
                  NlKEIGEN_K_6_ZEN           := NlKEIGEN_K_6_ZEN + (NwWORK18 /12);
                  NlKEIGEN_KINTO             := NlKEIGEN_KINTO + (NwWORK18 /12);
                  NlKEIGEN_KINTO18UN         := NlKEIGEN_KINTO18UN + (NwWORK18 /12);
                  MwKODOMO_KEIGEN_GAKU(NwIX) := CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                  Mw18UN_KEIGEN_KITO(NwIX)   := (NwWORK18 /12);
                  -- 各月均等割額に対する257軽減(世帯員より異なる産前産後軽減、未就学児軽減による軽減を除いた額)を算出
--2025/10/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                  Mw257GEN(NwIX) := ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN1 / 12)
--                                  + (CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12)
--                                  + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12)
--                                  - (CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12)
--                                  - (MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN1 / 12))
--                                  - (MlSANCNT_K(NwIX) * (NlJKINTO / 12 - NlJKGEN1 / 12));
--                  Mw257GEN(NwIX)  := Mw257GEN(NwIX) / MlCNT(NwIX);
                  Mw257GEN(NwIX) := NlJKGEN1 / 12;            -- 均等割額に関わる政令軽減(※DB反映時は産前産後対象者を除く)
--2025/10/11 ZCZL.LIUHUAJUN UPDATE END
                ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN    -- 軽減4割

                  -- 特定同一時の軽減ルート
                  IF MlTAISHO_KBN(NwIX) = 1 THEN
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX)    := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN2 + NlJBGEN_T2)
                                                       - (MlSANCNT18(NwIX) * NlJKINTO) - (MlSANCNT_K18(NwIX) * NlJKINTO);
                    END IF;
                    NlKEIGEN_K_4_ZEN   := NlKEIGEN_K_4_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 / 12)+ CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 / 12)+ CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    -- 子ども均等割軽減額 = 子ども均等割軽減額 + 切り上げ((均等割額 ｰ 軽減均等割2(4割)) / システム条件.子ども均等割軽減率 / 100 * 子ども人数ワークの対象月人数 / 12)
                    NKODOMO_KEIGEN_GAKU  := NKODOMO_KEIGEN_GAKU + CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN2 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12);
                    -- 軽減平等
                    NlKEIGEN_B_4_ZEN   := NlKEIGEN_B_4_ZEN   + (NlJBGEN_T2 / 12);
                    NlKEIGEN_BYODO := NlKEIGEN_BYODO         + (NlJBGEN_T2 / 12);
                  -- 特定同一(2)の軽減ルート
                  ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX)    := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN2 + NlJBGEN2_T2)
                                                       - (MlSANCNT18(NwIX) * NlJKINTO) - (MlSANCNT_K18(NwIX) * NlJKINTO);
                    END IF;
                    NlKEIGEN_K_4_ZEN   := NlKEIGEN_K_4_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 / 12)+ CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 / 12)+ CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    -- 子ども均等割軽減額 = 子ども均等割軽減額 + 切り上げ((均等割額 ｰ 軽減均等割2(4割)) / システム条件.子ども均等割軽減率 / 100 * 子ども人数ワークの対象月人数 / 12)
                    NKODOMO_KEIGEN_GAKU  := NKODOMO_KEIGEN_GAKU + CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN2 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12);
                    -- 軽減平等
                    NlKEIGEN_B_4_ZEN   := NlKEIGEN_B_4_ZEN   + (NlJBGEN2_T2 / 12);
                    NlKEIGEN_BYODO := NlKEIGEN_BYODO         + (NlJBGEN2_T2 / 12);
                  ELSE
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX)    := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN2 + NlJBGEN2)
                                                       - (MlSANCNT18(NwIX) * NlJKINTO) - (MlSANCNT_K18(NwIX) * NlJKINTO);
                    END IF;
                    NlKEIGEN_K_4_ZEN   := NlKEIGEN_K_4_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 / 12) + CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 / 12) + CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12);
                    -- 子ども均等割軽減額 = 子ども均等割軽減額 + 切り上げ((均等割額 ｰ 軽減均等割2(4割)) / システム条件.子ども均等割軽減率 / 100 * 子ども人数ワークの対象月人数 / 12)
                    NKODOMO_KEIGEN_GAKU  := NKODOMO_KEIGEN_GAKU + CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN2 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12);
                    -- 軽減平等
                    NlKEIGEN_B_4_ZEN   := NlKEIGEN_B_4_ZEN   + (NlJBGEN2 / 12);
                    NlKEIGEN_BYODO     := NlKEIGEN_BYODO     + (NlJBGEN2 / 12);
                  END IF;
                  -- 18歳以上均等割額に関わる軽減額を算出し、各種軽減額に反映　(平等割軽減済のため、特定同一値に関わらず設定)
                  NwWORK18                := ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN218)
                                           + (MlSANCNT18(NwIX) * NlJKINTO18) + (MlSANCNT_K18(NwIX) * NlJKINTO18);
                  MlZEIGAKU(NwIX)         := MlZEIGAKU(NwIX) - NwWORK18;
                  NlKEIGEN_K_4_ZEN        := NlKEIGEN_K_4_ZEN + (NwWORK18 /12);
                  NlKEIGEN_KINTO          := NlKEIGEN_KINTO + (NwWORK18 /12);
                  NlKEIGEN_KINTO18        := NlKEIGEN_KINTO18 + (NwWORK18 /12);
                  MwSAN_K_KEIGEN18(NwIX)  := MlSANCNT18(NwIX) * (NlJKINTO18 / 12 - NlJKGEN218 / 12);
                  MwSAN_K_KEIGEN218(NwIX) := MlSANCNT_K18(NwIX) * (NlJKINTO18 * 50 / 100 / 12);
--2025/10/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                  Mw257GEN18(NwIX)        := NwWORK18 - MwSAN_K_KEIGEN18(NwIX) - MwSAN_K_KEIGEN218(NwIX);
--                  Mw257GEN18(NwIX)        := Mw257GEN18(NwIX) / MlCNT18(NwIX);
                  Mw257GEN18(NwIX)        := NlJKGEN218 / 12;          -- 18歳以上均等割額に関わる政令軽減(※DB反映時は産前産後対象者を除く)
--2025/10/11 ZCZL.LIUHUAJUN UPDATE END
                  -- 均等割額に関わる18歳未満軽減額を算出し、各種軽減額に反映　(平等割軽減済のため、特定同一値に関わらず設定)
                  -- (均等割額*18歳未満人数) - (18歳未満の257割均等割軽減)-(18歳未満の未就学児軽減)-(18歳未満の産前産後軽減)=賦課額(18歳未満なので、18歳未満均等割軽減額)
                  NwWORK18                := (NlJKINTO * MlCNT18UN(NwIX))
                                           - ((MlCNT18UN(NwIX) - MlSANCNT18UN(NwIX) - MlSANCNT_K18UN(NwIX)) * NlJKGEN2)
                                           - (CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX))
                                           - (MlSANCNT18UN(NwIX) * NlJKINTO ) - (MlSANCNT_K18UN(NwIX) * NlJKINTO);
                  NlKEIGEN_K_4_ZEN           := NlKEIGEN_K_4_ZEN + (NwWORK18 /12);
                  NlKEIGEN_KINTO             := NlKEIGEN_KINTO + (NwWORK18 /12);
                  NlKEIGEN_KINTO18UN         := NlKEIGEN_KINTO18UN + (NwWORK18 /12);
                  MwKODOMO_KEIGEN_GAKU(NwIX) := CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                  Mw18UN_KEIGEN_KITO(NwIX)   := (NwWORK18 /12);
                  -- 各月均等割額に対する257軽減(世帯員より異なる産前産後軽減、未就学児軽減による軽減を除いた額)を算出
--2025/10/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 Mw257GEN(NwIX) := ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN2 / 12)
--                                 + (CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12)
--                                 + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12)
--                                 - (CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12)
--                                 - (MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN2 / 12))
--                                 - (MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12));
--                  Mw257GEN(NwIX)  := Mw257GEN(NwIX) / MlCNT(NwIX);
                  Mw257GEN(NwIX) := NlJKGEN2 / 12;            -- 均等割額に関わる政令軽減(※DB反映時は産前産後対象者を除く)
--2025/10/11 ZCZL.LIUHUAJUN UPDATE END
                ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN    -- 軽減2割

                  -- 特定同一時の軽減ルート
                  IF MlTAISHO_KBN(NwIX) = 1 THEN
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX)    := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN3 + NlJBGEN_T3)
                                                       - (MlSANCNT18(NwIX) * NlJKINTO) - (MlSANCNT_K18(NwIX) * CEIL(NlJKINTO * 70 / 100));
                    END IF;
                    NlKEIGEN_K_2_ZEN   := NlKEIGEN_K_2_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 / 12) + CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO * 70 / 100 / 12);
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 / 12) + CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO * 70 / 100 / 12);
                    -- 子ども均等割軽減額 = 子ども均等割軽減額 + 切り上げ((均等割額 ｰ 軽減均等割3(2割)) / システム条件.子ども均等割軽減率 / 100 * 子ども人数ワークの対象月人数 / 12)
                    NKODOMO_KEIGEN_GAKU  := NKODOMO_KEIGEN_GAKU + CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN3 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12);
                    -- 軽減平等
                    NlKEIGEN_B_2_ZEN   := NlKEIGEN_B_2_ZEN   + (NlJBGEN_T3 / 12);
                    NlKEIGEN_BYODO     := NlKEIGEN_BYODO     + (NlJBGEN_T3 / 12);
                  -- 特定同一(2)の軽減ルート
                  ELSIF MlTAISHO_KBN(NwIX) = 8 THEN
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX)    := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN3 + NlJBGEN2_T3)
                                                       - (MlSANCNT18(NwIX) * NlJKINTO) - (MlSANCNT_K18(NwIX) * CEIL(NlJKINTO * 70 / 100));
                    END IF;
                    NlKEIGEN_K_2_ZEN   := NlKEIGEN_K_2_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 / 12) + CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO * 70 / 100 / 12);
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 / 12) + CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO * 70 / 100 / 12);
                    -- 子ども均等割軽減額 = 子ども均等割軽減額 + 切り上げ((均等割額 ｰ 軽減均等割3(2割)) / システム条件.子ども均等割軽減率 / 100 * 子ども人数ワークの対象月人数 / 12)
                    NKODOMO_KEIGEN_GAKU  := NKODOMO_KEIGEN_GAKU + CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN3 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12);
                    -- 軽減平等
                    NlKEIGEN_B_2_ZEN   := NlKEIGEN_B_2_ZEN   + (NlJBGEN2_T3 / 12);
                    NlKEIGEN_BYODO     := NlKEIGEN_BYODO     + (NlJBGEN2_T3 / 12);
                  ELSE
                    -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                    IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                      subSanChokaCal(NwIX);
                    ELSE
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN3 + NlJBGEN3)
                                                       - (MlSANCNT18(NwIX) * NlJKINTO) - (MlSANCNT_K18(NwIX) * CEIL(NlJKINTO * 70 / 100));
                    END IF;
                    NlKEIGEN_K_2_ZEN   := NlKEIGEN_K_2_ZEN   + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 / 12) + CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO * 70 / 100 / 12);
                    NlKEIGEN_KINTO     := NlKEIGEN_KINTO     + ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 / 12) + CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO * 70 / 100 / 12);
                    -- 子ども均等割軽減額 = 子ども均等割軽減額 + 切り上げ((均等割額 ｰ 軽減均等割3(2割)) / システム条件.子ども均等割軽減率 / 100 * 子ども人数ワークの対象月人数 / 12)
                    NKODOMO_KEIGEN_GAKU  := NKODOMO_KEIGEN_GAKU + CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                    MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN3 / 12);
                    MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12);
                    -- 軽減平等
                    NlKEIGEN_B_2_ZEN   := NlKEIGEN_B_2_ZEN   + (NlJBGEN3 / 12);
                    NlKEIGEN_BYODO     := NlKEIGEN_BYODO     + (NlJBGEN3 / 12);
                  END IF;
                  -- 18歳以上均等割額に関わる軽減額を算出し、各種軽減額に反映　(平等割軽減済のため、特定同一値に関わらず設定)
                  NwWORK18                := ((MlCNT18(NwIX) - MlSANCNT18(NwIX) - MlSANCNT_K18(NwIX)) * NlJKGEN318)
                                           + (MlSANCNT18(NwIX) * NlJKINTO18) + (MlSANCNT_K18(NwIX) * CEIL(NlJKINTO18 * 70 / 100));
                  MlZEIGAKU(NwIX)         := MlZEIGAKU(NwIX) - NwWORK18;
                  NlKEIGEN_K_2_ZEN        := NlKEIGEN_K_2_ZEN + (NwWORK18 /12);
                  NlKEIGEN_KINTO          := NlKEIGEN_KINTO + (NwWORK18 /12);
                  NlKEIGEN_KINTO18        := NlKEIGEN_KINTO18 + (NwWORK18 /12);
                  MwSAN_K_KEIGEN18(NwIX)  := MlSANCNT18(NwIX) * (NlJKINTO18 / 12 - NlJKGEN318 / 12);
                  MwSAN_K_KEIGEN218(NwIX) := MlSANCNT_K18(NwIX) * (NlJKINTO18 * 50 / 100 / 12);
--2025/10/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                  Mw257GEN18(NwIX)        := NwWORK18 - MwSAN_K_KEIGEN18(NwIX) - MwSAN_K_KEIGEN218(NwIX);
--                  Mw257GEN18(NwIX)        := Mw257GEN18(NwIX) / MlCNT18(NwIX);
                  Mw257GEN18(NwIX)        := NlJKGEN318 / 12;          -- 18歳以上均等割額に関わる政令軽減(※DB反映時は産前産後対象者を除く)
--2025/10/11 ZCZL.LIUHUAJUN UPDATE END
                  -- 均等割額に関わる18歳未満軽減額を算出し、各種軽減額に反映　(平等割軽減済のため、特定同一値に関わらず設定)
                  -- (均等割額*18歳未満人数) - (18歳未満の257割均等割軽減)-(18歳未満の未就学児軽減)-(18歳未満の産前産後軽減)=賦課額(18歳未満なので、18歳未満均等割軽減額)
                  NwWORK18                := (NlJKINTO * MlCNT18UN(NwIX))
                                           - ((MlCNT18UN(NwIX) - MlSANCNT18UN(NwIX) - MlSANCNT_K18UN(NwIX)) * NlJKGEN3)
                                           - (CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX))
                                           - (MlSANCNT18UN(NwIX) * NlJKINTO) - (MlSANCNT_K18UN(NwIX) * CEIL(NlJKINTO * 70 / 100));
                  NlKEIGEN_K_2_ZEN           := NlKEIGEN_K_2_ZEN + (NwWORK18 /12);
                  NlKEIGEN_KINTO             := NlKEIGEN_KINTO + (NwWORK18 /12);
                  NlKEIGEN_KINTO18UN         := NlKEIGEN_KINTO18UN + (NwWORK18 /12);
                  MwKODOMO_KEIGEN_GAKU(NwIX) := CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                  Mw18UN_KEIGEN_KITO(NwIX)   := (NwWORK18 /12);
                  -- 各月均等割額に対する257軽減(世帯員より異なる産前産後軽減、未就学児軽減による軽減を除いた額)を算出
--2025/10/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                  Mw257GEN(NwIX) := ((MlCNT(NwIX) - MlSANCNT(NwIX) - MlSANCNT_K(NwIX)) * NlJKGEN3 / 12)
--                                  + (CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12)
--                                  + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO / 12)
--                                  - (CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12)
--                                  - (MlSANCNT(NwIX) * (NlJKINTO / 12 - NlJKGEN3 / 12))
--                                  - (MlSANCNT_K(NwIX) * (NlJKINTO * 70 / 100 / 12));
--                  Mw257GEN(NwIX)  := Mw257GEN(NwIX) / MlCNT(NwIX);
                  Mw257GEN(NwIX) := NlJKGEN3 / 12;            -- 均等割額に関わる政令軽減(※DB反映時は産前産後対象者を除く)
--2025/10/11 ZCZL.LIUHUAJUN UPDATE END
                ELSE
                  -- 各月産前産後有資格者数+各月旧被扶養者兼産前産後者数 ＞０、かつ計算基本.積算がシステム条件.限度額より大きい場合
                  IF MlSANCNT(NwIX) + MlSANCNT_K(NwIX) > 0 AND RlKIHON.SEKISAN > NlJGENDOGAKU THEN
                    subSanChokaCal(NwIX);
                  ELSE
                  MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - (MlSANCNT18(NwIX) * NlJKINTO) - (MlSANCNT_K18(NwIX) * CEIL(NlJKINTO * 50 / 100));
                  END IF;
                  NlKEIGEN_KINTO     := NlKEIGEN_KINTO     +  CEIL(NlJKINTO  * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12
                                                             + (MlSANCNT(NwIX) * NlJKINTO / 12) + (MlSANCNT_K(NwIX) * NlJKINTO * 50 / 100 / 12);
                  -- 子ども均等割軽減額 = 子ども均等割軽減額 + 切り上げ(均等割額 / システム条件.子ども均等割軽減率 / 100 * 子ども人数ワークの対象月人数 / 12)
                  NKODOMO_KEIGEN_GAKU  := NKODOMO_KEIGEN_GAKU + CEIL(NlJKINTO * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                  MwSAN_K_KEIGEN(NwIX) := MlSANCNT(NwIX) * (NlJKINTO / 12);
                  MwSAN_K_KEIGEN2(NwIX) := MlSANCNT_K(NwIX) * (NlJKINTO * 50 / 100 / 12);
                  -- 18歳以上均等割額に関わる軽減額を算出し、各種軽減額に反映
                  NwWORK18              := (MlSANCNT18(NwIX) * NlJKINTO18) + (MlSANCNT_K18(NwIX) * CEIL(NlJKINTO18 * 50 / 100));
                  MlZEIGAKU(NwIX)       := MlZEIGAKU(NwIX) - NwWORK18;
                  NlKEIGEN_KINTO        := NlKEIGEN_KINTO + (NwWORK18 /12);
                  NlKEIGEN_KINTO18      := NlKEIGEN_KINTO18 + (NwWORK18 /12);
                  MwSAN_K_KEIGEN18(NwIX)  := MlSANCNT18(NwIX) * (NlJKINTO18 / 12);
                  MwSAN_K_KEIGEN218(NwIX) := MlSANCNT_K18(NwIX) * (NlJKINTO18 * 50 / 100 / 12);
                  Mw257GEN18(NwIX)        := 0;
                  -- 均等割額に関わる18歳未満軽減額を算出し、各種軽減額に反映
                  -- (均等割額*18歳未満人数) - (18歳未満の未就学児軽減)-(18歳未満の産前産後軽減)=賦課額(18歳未満なので、18歳未満均等割軽減額)
                  NwWORK18              := (NlJKINTO * MlCNT18UN(NwIX))
                                         - (CEIL( NlJKINTO * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX))
                                         - (MlSANCNT18UN(NwIX) * NlJKINTO) - (MlSANCNT_K18UN(NwIX) * CEIL(NlJKINTO * 50 / 100));
                  NlKEIGEN_KINTO        := NlKEIGEN_KINTO + (NwWORK18 /12);
                  NlKEIGEN_KINTO18UN    := NlKEIGEN_KINTO18UN + (NwWORK18 /12);
                  MwKODOMO_KEIGEN_GAKU(NwIX) := CEIL(NlJKINTO * NKODOMO_KEIGEN_WARIAI / 100) * MJI_NINSU(NwIX) / 12;
                  Mw18UN_KEIGEN_KITO(NwIX)   := (NwWORK18 /12);
                  --各月均等割額に対する257軽減(世帯員より異なる産前産後軽減、未就学児軽減による軽減を除いた額)を算出
                  Mw257GEN(NwIX) := 0;
                END IF;
                -- 産前産後均等割軽減額を更新
                NwSAN_K_GENKEI     := NwSAN_K_GENKEI     +  MwSAN_K_KEIGEN(NwIX) +  MwSAN_K_KEIGEN2(NwIX)
                                    + MwSAN_K_KEIGEN18(NwIX) + MwSAN_K_KEIGEN218(NwIX);
                NwSAN_K_GENKEI18   := NwSAN_K_GENKEI18 + MwSAN_K_KEIGEN18(NwIX) + MwSAN_K_KEIGEN218(NwIX);
                IF NLOOP_CNT_NOW = 1 THEN
                IF MlSANCNT(NwIX) >= 1 THEN
                  BEGIN
                    vSQL :=          'UPDATE ZLBTKOJIN_CAL';
-- 2025/12/17 ZCZL.MUZHILIN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--                     vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO + ' || MwSAN_K_KEIGEN(NwIX) / MlSANCNT(NwIX);
                    vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO + ' || TRUNC(MwSAN_K_KEIGEN(NwIX) / MlSANCNT(NwIX),3);
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
                    EXECUTE IMMEDIATE vSQL;
                    EXCEPTION
                      WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subTukiwari 計算個人更新(国保世帯番号='||
                                  i_NSETAI||')'||SQLERRM;
                  END;
                END IF;
                IF MlSANCNT_K(NwIX) >= 1 THEN
                  BEGIN
                    -- 計算個人update
                    vSQL :=          'UPDATE ZLBTKOJIN_CAL';
-- 2025/12/17 ZCZL.MUZHILIN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--                     vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO   = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO  + ' || MwSAN_K_KEIGEN2(NwIX) / MlSANCNT_K(NwIX);
                    vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO   = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO  + ' || TRUNC(MwSAN_K_KEIGEN2(NwIX) / MlSANCNT_K(NwIX),3);
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
                  -- 各月産前産後人数(うち18歳以上)が存在する場合
                  IF MlSANCNT18(NwIX) >= 1 THEN
                    BEGIN
                      -- 計算個人update
                      vSQL :=          'UPDATE ZLBTKOJIN_CAL';
-- 2025/12/04 ZCZL.XIESHUN UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--                      vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO   = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO  + ' || MwSAN_K_KEIGEN18(NwIX)  / MlSANCNT18(NwIX);
--                      vSQL := vSQL || '     ,ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18   = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18  + ' ||MwSAN_K_KEIGEN18(NwIX)  / MlSANCNT18(NwIX);
-- 2025/12/17 ZCZL.MUZHILIN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--                       vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18   = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18  + ' || MwSAN_K_KEIGEN18(NwIX) / MlSANCNT18(NwIX);
                      vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18   = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18  + ' || TRUNC(MwSAN_K_KEIGEN18(NwIX) / MlSANCNT18(NwIX),3);
-- 2025/12/04 ZCZL.XIESHUN UPDATE END
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
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.KDM_18_KBN      = 1';
                      IF NwIX < 10 THEN
                        vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SAN_' || TO_CHAR(NwIX + 3) || ' = 1';
                      ELSE
                        vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SAN_' || TO_CHAR(NwIX - 9) || ' = 1';
                      END IF;
-- 2025/12/11 ZCZL.XIESHUN ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084(2回目)
                      EXECUTE IMMEDIATE vSQL;
                    EXCEPTION
                        WHEN OTHERS THEN
                          NlRTN := c_NERR;
                          VlMSG := 'subTukiwari 計算個人更新(国保世帯番号='||
                                    i_NSETAI||')'||SQLERRM;
                    END;
                  END IF;
                  -- 各月旧被扶養者兼産前産後人数(うち18歳以上)が存在する場合
                  IF MlSANCNT_K18(NwIX) >= 1 THEN
                    BEGIN
                      -- 計算個人update
                      vSQL :=          'UPDATE ZLBTKOJIN_CAL';
-- 2025/12/04 ZCZL.XIESHUN UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--                      vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO   = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO  + ' || MwSAN_K_KEIGEN218(NwIX)  / MlSANCNT_K18(NwIX);
--                      vSQL := vSQL || '     ,ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18   = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18  + ' ||MwSAN_K_KEIGEN218(NwIX)  / MlSANCNT_K18(NwIX);
-- 2025/12/17 ZCZL.MUZHILIN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--                       vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18   = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18  + ' || MwSAN_K_KEIGEN218(NwIX)  / MlSANCNT_K18(NwIX);
                      vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18   = ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18  + ' || TRUNC(MwSAN_K_KEIGEN218(NwIX)  / MlSANCNT_K18(NwIX),3);
-- 2025/12/04 ZCZL.XIESHUN UPDATE END
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
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.KDM_18_KBN      = 1';
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
                  -- 計算個人の子ども均等割軽減額へ反映
                  IF MJI_NINSU(NwIX) >= 1 THEN
                    BEGIN
                      -- 計算個人update
                      vSQL :=          'UPDATE ZLBTKOJIN_CAL';
-- 2025/12/04 ZCZL.XIESHUN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--                      vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM_KEIGEN_KITO  + ' || MwKODOMO_KEIGEN_GAKU(NwIX) / MJI_NINSU(NwIX);
-- 2025/12/17 ZCZL.MUZHILIN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--                       vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_KODOMO_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM_KODOMO_KEIGEN_KITO  + ' || MwKODOMO_KEIGEN_GAKU(NwIX) / MJI_NINSU(NwIX);
                      vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_KODOMO_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM_KODOMO_KEIGEN_KITO  + ' || TRUNC(MwKODOMO_KEIGEN_GAKU(NwIX) / MJI_NINSU(NwIX),3);
                      vSQL := vSQL || ' WHERE ZLBTKOJIN_CAL.KOKU_SETAI_NO   = ' || i_NSETAI;
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.SANTEIDANTAI_CD = ' || i_NDANTAI;
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.CHOTEI_NENDO    = ' || i_NNENDO;
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.NENDO_BUN       = ' || i_NNENDO_BUN;
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.TSUCHI_NO       = ' || i_NNUSHI;
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.KDM_18_KBN      = 2';
                      IF NwIX < 10 THEN
                        vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SHIK_' || TO_CHAR(NwIX + 3) || ' IN (1, 3, 11, 13)';
                      ELSE
                        vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SHIK_' || TO_CHAR(NwIX - 9) || ' IN (1, 3, 11, 13)';
                      END IF;
                      EXECUTE IMMEDIATE vSQL;
                    EXCEPTION
                        WHEN OTHERS THEN
                          NlRTN := c_NERR;
                          VlMSG := 'subTukiwari 計算個人更新(国保世帯番号='||
                                    i_NSETAI||')'||SQLERRM;
                    END;
                  END IF;
                  -- 計算個人の子ども18歳未満均等割軽減額へ反映
                  IF MlCNT18UN(NwIX) >= 1 THEN
                    BEGIN
                      -- 計算個人update
                      vSQL :=          'UPDATE ZLBTKOJIN_CAL';
-- 2025/12/17 ZCZL.MUZHILIN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--                       vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM18UN_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM18UN_KEIGEN_KITO  + ' || Mw18UN_KEIGEN_KITO(NwIX) / MlCNT18UN(NwIX);
                      vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM18UN_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM18UN_KEIGEN_KITO  + ' || TRUNC(Mw18UN_KEIGEN_KITO(NwIX) / MlCNT18UN(NwIX),3);
                      vSQL := vSQL || ' WHERE ZLBTKOJIN_CAL.KOKU_SETAI_NO   = ' || i_NSETAI;
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.SANTEIDANTAI_CD = ' || i_NDANTAI;
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.CHOTEI_NENDO    = ' || i_NNENDO;
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.NENDO_BUN       = ' || i_NNENDO_BUN;
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.TSUCHI_NO       = ' || i_NNUSHI;
                      vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.KDM_18_KBN     != 1';
                      IF NwIX < 10 THEN
                        vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SHIK_' || TO_CHAR(NwIX + 3) || ' IN (1, 3, 11, 13)';
                      ELSE
                        vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SHIK_' || TO_CHAR(NwIX - 9) || ' IN (1, 3, 11, 13)';
                      END IF;
                      EXECUTE IMMEDIATE vSQL;
                    EXCEPTION
                        WHEN OTHERS THEN
                          NlRTN := c_NERR;
                          VlMSG := 'subTukiwari 計算個人更新(国保世帯番号='||
                                    i_NSETAI||')'||SQLERRM;
                    END;
                  END IF;
                  -- 計算個人の18歳以上の世帯員の子ども均等割軽減額(257軽減分)、子ども18歳以上均等割軽減額(257軽減分)の反映
                  BEGIN
                    -- 計算個人update
                    vSQL :=          'UPDATE ZLBTKOJIN_CAL';
-- 2025/12/04 ZCZL.XIESHUN UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--                    vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM_KEIGEN_KITO + ' || Mw257GEN(NwIX) || ' + ' || Mw257GEN18(NwIX);
-- 2025/12/17 ZCZL.MUZHILIN UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--                     vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM_KEIGEN_KITO + ' || Mw257GEN(NwIX);
--                     vSQL := vSQL || '    ,ZLBTKOJIN_CAL.KDM_KEIGEN_KITO18 = ZLBTKOJIN_CAL.KDM_KEIGEN_KITO18 + ' || Mw257GEN18(NwIX);
                    vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM_KEIGEN_KITO + ' ||TRUNC( Mw257GEN(NwIX),3);
                    vSQL := vSQL || '    ,ZLBTKOJIN_CAL.KDM_KEIGEN_KITO18 = ZLBTKOJIN_CAL.KDM_KEIGEN_KITO18 + ' || TRUNC(Mw257GEN18(NwIX),3);
--2025/12/17 ZCZL.MUZHILIN UPDATE END
                    vSQL := vSQL || ' WHERE ZLBTKOJIN_CAL.KOKU_SETAI_NO   = ' || i_NSETAI;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.SANTEIDANTAI_CD = ' || i_NDANTAI;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.CHOTEI_NENDO    = ' || i_NNENDO;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.NENDO_BUN       = ' || i_NNENDO_BUN;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.TSUCHI_NO       = ' || i_NNUSHI;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.KDM_18_KBN      = 1';
                    IF NwIX < 10 THEN
                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SHIK_' || TO_CHAR(NwIX + 3) || ' IN (1, 3, 11, 13)';
                    ELSE
                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SHIK_' || TO_CHAR(NwIX - 9) || ' IN (1, 3, 11, 13)';
                    END IF;
-- 2025/12/22 ZCZL.XIESHUN DELETE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00125
--2025/10/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                    IF NwIX < 10 THEN
--                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SAN_' || TO_CHAR(NwIX + 3) || ' != 1';
--                    ELSE
--                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SAN_' || TO_CHAR(NwIX - 9) || ' != 1';
--                    END IF;
--2025/10/11 ZCZL.LIUHUAJUN ADD END
-- 2025/12/22 ZCZL.XIESHUN DELETE END
                    EXECUTE IMMEDIATE vSQL;
                  EXCEPTION
                      WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subTukiwari 計算個人更新(国保世帯番号='||
                                  i_NSETAI||')'||SQLERRM;
                  END;
                  BEGIN
                    -- 計算個人update
                    vSQL :=          'UPDATE ZLBTKOJIN_CAL';
-- 2025/12/17 ZCZL.MUZHILIN UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00117
--                     vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM_KEIGEN_KITO  + ' || Mw257GEN(NwIX);
                    vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM_KEIGEN_KITO  + ' || TRUNC(Mw257GEN(NwIX),3);
                    vSQL := vSQL || ' WHERE ZLBTKOJIN_CAL.KOKU_SETAI_NO   = ' || i_NSETAI;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.SANTEIDANTAI_CD = ' || i_NDANTAI;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.CHOTEI_NENDO    = ' || i_NNENDO;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.NENDO_BUN       = ' || i_NNENDO_BUN;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.TSUCHI_NO       = ' || i_NNUSHI;
                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.KDM_18_KBN     != 1';
                    IF NwIX < 10 THEN
                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SHIK_' || TO_CHAR(NwIX + 3) || ' IN (1, 3, 11, 13)';
                    ELSE
                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SHIK_' || TO_CHAR(NwIX - 9) || ' IN (1, 3, 11, 13)';
                    END IF;
-- 2025/12/22 ZCZL.XIESHUN DELETE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00125
--2025/10/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                    IF NwIX < 10 THEN
--                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SAN_' || TO_CHAR(NwIX + 3) || ' != 1';
--                    ELSE
--                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SAN_' || TO_CHAR(NwIX - 9) || ' != 1';
--                    END IF;
--2025/10/11 ZCZL.LIUHUAJUN ADD END
-- 2025/12/22 ZCZL.XIESHUN DELETE END
                    EXECUTE IMMEDIATE vSQL;
                  EXCEPTION
                      WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subTukiwari 計算個人更新(国保世帯番号='||
                                  i_NSETAI||')'||SQLERRM;
                  END;
-- 2025/12/04 ZCZL.XIESHUN DELETE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--                  -- 計算個人の子ども均等割軽減額と子ども18歳以上均等割軽減額に、257割軽減以外の軽減(産前産後軽減）を加算する
--                  BEGIN
--                    -- 計算個人update
--                    vSQL :=          'UPDATE ZLBTKOJIN_CAL';
--                    vSQL := vSQL || ' SET ZLBTKOJIN_CAL.KDM_KEIGEN_KITO   = ZLBTKOJIN_CAL.KDM_KEIGEN_KITO + ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO';
--                    vSQL := vSQL || '                                       + ZLBTKOJIN_CAL.KDM18UN_KEIGEN_KITO';
--                    vSQL := vSQL || '    ,ZLBTKOJIN_CAL.KDM_KEIGEN_KITO18 = ZLBTKOJIN_CAL.KDM_KEIGEN_KITO18 + ZLBTKOJIN_CAL.KDM_SAN_GEN_KINTO18';
--                    vSQL := vSQL || ' WHERE ZLBTKOJIN_CAL.KOKU_SETAI_NO   = ' || i_NSETAI;
--                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.SANTEIDANTAI_CD = ' || i_NDANTAI;
--                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.CHOTEI_NENDO    = ' || i_NNENDO;
--                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.NENDO_BUN       = ' || i_NNENDO_BUN;
--                    vSQL := vSQL || ' AND   ZLBTKOJIN_CAL.TSUCHI_NO       = ' || i_NNUSHI;
--                    IF NwIX < 10 THEN
--                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SHIK_' || TO_CHAR(NwIX + 3) || ' IN (1, 3, 11, 13)';
--                    ELSE
--                      vSQL := vSQL || '  AND ZLBTKOJIN_CAL.SHIK_' || TO_CHAR(NwIX - 9) || ' IN (1, 3, 11, 13)';
--                    END IF;
--                    EXECUTE IMMEDIATE vSQL;
--                  EXCEPTION
--                      WHEN OTHERS THEN
--                        NlRTN := c_NERR;
--                        VlMSG := 'subTukiwari 計算個人更新(国保世帯番号='||
--                                  i_NSETAI||')'||SQLERRM;
--                  END;
-- 2025/12/04 ZCZL.XIESHUN DELETE END
                END IF;
                -- 年齢軽減月割り対応
                IF MlNEN_CNT(NwIX) > 0 THEN
                  IF MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - (NlJKINTO + NlJKINTO18 - NlJKGEN1 - NlJKGEN118 ) / 2 * (MlNEN_CNT(NwIX)- MlCNT18UN(NwIX));
                    NNENREI_KEIGEN  := NNENREI_KEIGEN + (NlJKINTO + NlJKINTO18 - NlJKGEN1 - NlJKGEN118 ) / 2 * (MlNEN_CNT(NwIX) - MlCNT18UN(NwIX)) / 12;
                  ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - (NlJKINTO + NlJKINTO18 - NlJKGEN2 - NlJKGEN218 ) / 2 * (MlNEN_CNT(NwIX)- MlCNT18UN(NwIX));
                    NNENREI_KEIGEN  := NNENREI_KEIGEN + (NlJKINTO + NlJKINTO18 - NlJKGEN2 - NlJKGEN218 ) / 2 * (MlNEN_CNT(NwIX) - MlCNT18UN(NwIX)) / 12;
                  ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - (NlJKINTO + NlJKINTO18 - NlJKGEN3 - NlJKGEN318 ) / 2 * (MlNEN_CNT(NwIX)- MlCNT18UN(NwIX));
                    NNENREI_KEIGEN  := NNENREI_KEIGEN + (NlJKINTO + NlJKINTO18 - NlJKGEN3 - NlJKGEN318 ) / 2 * (MlNEN_CNT(NwIX) - MlCNT18UN(NwIX)) / 12;
                  ELSE
                    MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) - (NlJKINTO + NlJKINTO18) / 2 * (MlNEN_CNT(NwIX)- MlCNT18UN(NwIX));
                    NNENREI_KEIGEN  := NNENREI_KEIGEN + (NlJKINTO + NlJKINTO18) / 2 * (MlNEN_CNT(NwIX) - MlCNT18UN(NwIX)) / 12;
                  END IF;
                END IF;

                --優先区分が「世帯／額／応能応益」
                IF RlGENMEN_KOJIN.YUSEN_KBN = 2 THEN
                  IF NLOOP_CNT_NOW = 1 THEN
                    NwBYODOWARI     := NwBYODOWARI
                                     + TRUNC(NlJBYODO * MlOUEKI(NwIX) / 100);
                  ELSIF NLOOP_CNT_NOW = 2 THEN
-- 2025/12/24 ZCZL.LIUYANG UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00136
--                    MlZEIGAKU(NwIX)     := MlZEIGAKU(NwIX) -
--                                           RlGENMEN_KOJIN.KDM_SHOTOKU_GENGAKU -
--                                           RlGENMEN_KOJIN.KDM_SISANZEI_GENGAKU -
--                                           RlGENMEN_KOJIN.KDM_KINTOWARI_GENGAKU -
--                                           RlGENMEN_KOJIN.KDM_BYODOWARI_GENGAKU -
--                                           RlGENMEN_KOJIN.KDM_KINTOWARI_18_GENGAKU;
                    MlZEIGAKU(NwIX)     := MlZEIGAKU(NwIX) -
                                           RlGENMEN_KOJIN.KDM_SHOTOKU_GENGAKU -
                                           RlGENMEN_KOJIN.KDM_SISANZEI_GENGAKU -
                                           RlGENMEN_KOJIN.KDM_KINTOWARI_GENGAKU -
                                           RlGENMEN_KOJIN.KDM_BYODOWARI_GENGAKU;
-- 2025/12/24 ZCZL.LIUYANG UPDATE END
                    NwSHOTOKU_GENGAKU   := NwSHOTOKU_GENGAKU + RlGENMEN_KOJIN.KDM_SHOTOKU_GENGAKU;     --計算用所得割減免額
                    NwSISANZEI_GENGAKU  := NwSISANZEI_GENGAKU + RlGENMEN_KOJIN.KDM_SISANZEI_GENGAKU;   --計算用資産割減免額
                    NwKINTOWARI_GENGAKU := NwKINTOWARI_GENGAKU + RlGENMEN_KOJIN.KDM_KINTOWARI_GENGAKU; --計算用均等割減免額
                    NwBYODOWARI_GENGAKU := NwBYODOWARI_GENGAKU + RlGENMEN_KOJIN.KDM_BYODOWARI_GENGAKU; --計算用平等割減免額
                    NwKINTOWARI18_GENGAKU := NwKINTOWARI18_GENGAKU + RlGENMEN_KOJIN.KDM_KINTOWARI_18_GENGAKU; --計算用18歳以上均等割減免額
                  END IF;
                END IF;
                IF MlZEIGAKU(NwIX) > NlJGENDOGAKU THEN
                  IF NwSANCHOKA_FLG = 1 THEN
                    MlCHOKA_MAE(NwIX) := MlZEIGAKU(NwIX);
                    MlZEIGAKU(NwIX) := NlJGENDOGAKU;
                    MlCHOKA_SEKI(NwIX) := -1* (MlZEIGAKU(NwIX) - (MlZEIGAKU2(NwIX) - MlZEIGAKU218(NwIX)));
                    --フラグ初期化
                    NwSANCHOKA_FLG := 0;
                    IGENDO_HASU_KBN := 1;
                  ELSE
                    MlCHOKA_SEKI(NwIX) := MlZEIGAKU(NwIX) - NlJGENDOGAKU;
                  END IF;
                    MlCHOKA_MAE(NwIX) := MlZEIGAKU(NwIX);
                    MlZEIGAKU(NwIX)   := NlJGENDOGAKU;
                END IF;
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
            END IF;
        END LOOP;
-- 2025/12/04 ZCZL.XIESHUN UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--        -- 産前産後均等割軽減額端数調整
--        IF NLOOP_CNT_NOW = 1  AND NwCNT_SAN_MM > 0 THEN
--          NlKEIGEN_KINTO := NlKEIGEN_KINTO - NwSAN_K_GENKEI;
--          NlKEIGEN_KINTO18 := NlKEIGEN_KINTO18 - NwSAN_K_GENKEI18;
--        -- ①計算個人に登録された産前産後均等割軽減額および同(18歳以上分)の小数部分を切り上げた額の合計を、変数.産前産後均等割軽減額計_計算個人に格納する。
--        SELECT NVL(SUM(CEIL(KDM_SAN_GEN_KINTO)),0)
--               , NVL(SUM(CEIL(KDM_SAN_GEN_KINTO18)),0)
--          INTO NwSAN_K_GENKEI2
--               , NwSAN_K_GENKEI218
--          FROM ZLBTKOJIN_CAL
--         WHERE KOKU_SETAI_NO   = i_NSETAI
--           AND SANTEIDANTAI_CD = i_NDANTAI
--           AND CHOTEI_NENDO    = i_NNENDO
--           AND NENDO_BUN       = i_NNENDO_BUN
--           AND TSUCHI_NO       = i_NNUSHI;
--        -- ②変数.産前産後均等割軽減額計の小数部分を切り上げる。
--        NwSAN_K_GENKEI := CEIL(NwSAN_K_GENKEI);
--        NwSAN_K_GENKEI18 := CEIL(NwSAN_K_GENKEI18);
--        -- ③変数.産前産後均等割軽減額差額 = 変数.産前産後均等割軽減額計_計算個人 - 変数.産前産後均等割軽減額計
--        NwSAN_SAGAKU := NwSAN_K_GENKEI2 - CEIL(NwSAN_K_GENKEI);
--        NwSAN_SAGAKU18 := NwSAN_K_GENKEI218 - CEIL(NwSAN_K_GENKEI18);
--        -- ④計算個人に登録された産前産後均等割軽減額の小数部分を切り上げる
--        UPDATE ZLBTKOJIN_CAL
--           SET KDM_SAN_GEN_KINTO = CEIL(KDM_SAN_GEN_KINTO)
--               , KDM_SAN_GEN_KINTO18 = CEIL(KDM_SAN_GEN_KINTO18)
--         WHERE KOKU_SETAI_NO   = i_NSETAI
--           AND SANTEIDANTAI_CD = i_NDANTAI
--           AND CHOTEI_NENDO    = i_NNENDO
--           AND NENDO_BUN       = i_NNENDO_BUN
--           AND TSUCHI_NO       = i_NNUSHI;
--        -- ⑤計算個人に登録された産前産後均等割軽減額で最大の値から変数.産前産後均等割軽減額差額を減算する。
--        UPDATE ZLBTKOJIN_CAL
--           SET KDM_SAN_GEN_KINTO = NVL(KDM_SAN_GEN_KINTO,0) - NVL(NwSAN_SAGAKU,0)
--               , KDM_SAN_GEN_KINTO18 = NVL(KDM_SAN_GEN_KINTO18,0) - NVL(NwSAN_SAGAKU18,0)
--         WHERE KOKU_SETAI_NO   = i_NSETAI
--           AND SANTEIDANTAI_CD = i_NDANTAI
--           AND CHOTEI_NENDO    = i_NNENDO
--           AND NENDO_BUN       = i_NNENDO_BUN
--           AND TSUCHI_NO       = i_NNUSHI
--           AND (KOJIN_NO, KDM_SAN_GEN_KINTO) = (SELECT KOJIN_NO, KDM_SAN_GEN_KINTO
--                                                   FROM ZLBTKOJIN_CAL A
--                                                  WHERE A.KOKU_SETAI_NO   = i_NSETAI
--                                                    AND A.SANTEIDANTAI_CD = i_NDANTAI
--                                                    AND A.CHOTEI_NENDO    = i_NNENDO
--                                                    AND A.NENDO_BUN       = i_NNENDO_BUN
--                                                    AND A.TSUCHI_NO       = i_NNUSHI
--                                               ORDER BY A.KDM_SAN_GEN_KINTO DESC
--                                                       ,A.KOJIN_NO DESC
--                                                 OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY)
--           AND ROWNUM = 1;
--         -- ⑥支援産前産後均等割軽減額計 = 変数.産前産後均等割軽減額計
--         RlEXT.KDM_SAN_GEN_K_KEI := NwSAN_K_GENKEI;
--         NlKEIGEN_KINTO := NlKEIGEN_KINTO + NwSAN_K_GENKEI;
--         NlKEIGEN_KINTO18 := NlKEIGEN_KINTO18 + NwSAN_K_GENKEI18;
--         ELSIF NLOOP_CNT_NOW = 2 AND NwCNT_SAN_MM > 0 THEN
--          NlKEIGEN_KINTO := NlKEIGEN_KINTO - NwSAN_K_GENKEI;
--          NlKEIGEN_KINTO18 := NlKEIGEN_KINTO18 - NwSAN_K_GENKEI18;
--          NwSAN_K_GENKEI := CEIL(NwSAN_K_GENKEI);
--          NwSAN_K_GENKEI18 := CEIL(NwSAN_K_GENKEI18);
--          NlKEIGEN_KINTO := NlKEIGEN_KINTO + NwSAN_K_GENKEI;
--          NlKEIGEN_KINTO18 := NlKEIGEN_KINTO18 + NwSAN_K_GENKEI18;
--         END IF;

        -- 計算個人の各軽減額を対象に端数調整と軽減額の個人毎集計、世帯集計を行う
        IF NLOOP_CNT_NOW = 1 THEN
          MwKEIGEN_KINTO     := NlKEIGEN_KINTO;     -- 軽減均等
          MwKEIGEN_K_6_ZEN   := NlKEIGEN_K_6_ZEN;   -- 軽減均等6 全体
          MwKEIGEN_K_4_ZEN   := NlKEIGEN_K_4_ZEN;   -- 軽減均等4 全体
          MwKEIGEN_K_2_ZEN   := NlKEIGEN_K_2_ZEN;   -- 軽減均等2 全体
          MwKEIGEN_K_N_ZEN   := NlKEIGEN_KINTO - NlKEIGEN_K_6_ZEN - NlKEIGEN_K_4_ZEN - NlKEIGEN_K_2_ZEN;   -- 257軽減でない月の軽減額の計
          -- 計算個人の子ども産前産後均等割軽減額と子ども産前産後18歳以上均等割軽減額を、それぞれ個別に端数調整(切上or切捨)する
          UPDATE ZLBTKOJIN_CAL
             SET KDM_SAN_GEN_KINTO = CASE
                                       WHEN KDM_SAN_GEN_KINTO = 0 THEN 0
                                       WHEN CEIL (KDM_SAN_GEN_KINTO) <= KDM_KINTO THEN CEIL (KDM_SAN_GEN_KINTO)
                                       ELSE FLOOR (KDM_SAN_GEN_KINTO)
                                     END
               , KDM_SAN_GEN_KINTO18 = CASE
                                         WHEN KDM_SAN_GEN_KINTO18 = 0 THEN 0
                                         WHEN CEIL (KDM_SAN_GEN_KINTO18) <= KDM_KINTO18 THEN CEIL (KDM_SAN_GEN_KINTO18)
                                         ELSE FLOOR (KDM_SAN_GEN_KINTO18)
                                       END
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI;
          -- 計算個人の子ども均等割軽減額と子ども18歳以上均等割軽減額を(この時点では257軽減分のみを保持)、それぞれ個別に端数調整(切上or切捨)する
          UPDATE ZLBTKOJIN_CAL
--  2025/12/10 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00104
--              SET KDM_SAN_GEN_KINTO = CASE
             SET KDM_KEIGEN_KITO = CASE
                                       WHEN KDM_KEIGEN_KITO = 0 THEN 0
                                       WHEN CEIL (KDM_KEIGEN_KITO + KDM_SAN_GEN_KINTO) <= KDM_KINTO THEN CEIL (KDM_KEIGEN_KITO)
                                       ELSE FLOOR (KDM_KEIGEN_KITO)
                                     END
--  2025/12/10 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00104
--                , KDM_SAN_GEN_KINTO18 = CASE
               , KDM_KEIGEN_KITO18 = CASE
                                         WHEN KDM_KEIGEN_KITO18 = 0 THEN 0
                                         WHEN CEIL (KDM_KEIGEN_KITO18 + KDM_SAN_GEN_KINTO18) <= KDM_KINTO18 THEN CEIL (KDM_KEIGEN_KITO18)
                                         ELSE FLOOR (KDM_KEIGEN_KITO18)
                                       END
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI;
          -- 計算個人の子ども均等割軽減額（未就学児）を、均等割額と端数調整後の産前産後軽減額/257軽減額より、再計算する
          UPDATE ZLBTKOJIN_CAL
             SET KDM_KODOMO_KEIGEN_KITO = CASE
                                            WHEN KDM_KODOMO_KEIGEN_KITO = 0 THEN 0
                                            ELSE CEIL ((KDM_KINTO - KDM_SAN_GEN_KINTO - KDM_KEIGEN_KITO) * NKODOMO_KEIGEN_WARIAI / 100)
                                          END
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI;
          -- 計算個人の子ども18歳未満均等割軽減額を、均等割額と端数調整後の産前産後軽減額/257軽減額/未就学児軽減より、再計算する
          UPDATE ZLBTKOJIN_CAL
             SET KDM18UN_KEIGEN_KITO = CASE
                                         WHEN KDM18UN_KEIGEN_KITO = 0 THEN 0
                                         ELSE KDM_KINTO -　KDM_SAN_GEN_KINTO - KDM_KEIGEN_KITO -　KDM_KODOMO_KEIGEN_KITO
                                       END
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI;
          -- 計算個人の子ども均等割軽減額・子ども18歳以上均等割軽減額・子ども産前産後均等割軽減額へ、それぞれ内数となる軽減額を加算する(軽減額の集計)
          UPDATE ZLBTKOJIN_CAL
             SET KDM_KEIGEN_KITO   = KDM_KEIGEN_KITO + KDM_KEIGEN_KITO18 + KDM_SAN_GEN_KINTO +
                                     KDM_SAN_GEN_KINTO18 + KDM18UN_KEIGEN_KITO + KDM_KODOMO_KEIGEN_KITO
                ,KDM_KEIGEN_KITO18 = KDM_KEIGEN_KITO18 + KDM_SAN_GEN_KINTO18
                ,KDM_SAN_GEN_KINTO = KDM_SAN_GEN_KINTO + KDM_SAN_GEN_KINTO18
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI;
        END IF;
        -- 計算個人の各種軽減額を世帯で集計し
        SELECT
             NVL (SUM (KDM_KEIGEN_KITO), 0)        AS NlKEIGEN_KINTO
            ,NVL (SUM (KDM_KEIGEN_KITO18), 0)      AS NlKEIGEN_KINTO18
            ,NVL (SUM (KDM_SAN_GEN_KINTO), 0)      AS NwSAN_K_GENKEI
            ,NVL (SUM (KDM_SAN_GEN_KINTO18), 0)    AS NwSAN_K_GENKEI18
            ,NVL (SUM (KDM18UN_KEIGEN_KITO), 0)    AS NlKEIGEN_KINTO18UN
            ,NVL (SUM (KDM_KODOMO_KEIGEN_KITO), 0) AS NKODOMO_KEIGEN_GAKU
        INTO 
             NlKEIGEN_KINTO
            ,NlKEIGEN_KINTO18
            ,NwSAN_K_GENKEI
            ,NwSAN_K_GENKEI18
-- 　2025/12/16 ZCZL.XIESHUN UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084(4回目)
--            ,NKODOMO_KEIGEN_GAKU
--            ,NlKEIGEN_KINTO18UN
            ,NlKEIGEN_KINTO18UN
            ,NKODOMO_KEIGEN_GAKU
-- 　2025/12/16 ZCZL.XIESHUN UPDATE END
        FROM
            ZLBTKOJIN_CAL
        WHERE
              KOKU_SETAI_NO   = i_NSETAI
          AND SANTEIDANTAI_CD = i_NDANTAI
          AND CHOTEI_NENDO    = i_NNENDO
          AND NENDO_BUN       = i_NNENDO_BUN
          AND TSUCHI_NO       = i_NNUSHI;
        IF NlKEIGEN_K_2_ZEN + NlKEIGEN_K_4_ZEN + NlKEIGEN_K_6_ZEN > 0 THEN
          -- 257軽減額の算出（端数あり）
          NlKEIGEN_K_6_ZEN := NlKEIGEN_KINTO * MwKEIGEN_K_6_ZEN / MwKEIGEN_KINTO;
          NlKEIGEN_K_4_ZEN := NlKEIGEN_KINTO * MwKEIGEN_K_4_ZEN / MwKEIGEN_KINTO;
          NlKEIGEN_K_2_ZEN := NlKEIGEN_KINTO * MwKEIGEN_K_2_ZEN / MwKEIGEN_KINTO;
          -- 小数点以下の端数切捨てと
          MwKEIGEN_K_6_ZEN := NlKEIGEN_K_6_ZEN - TRUNC (NlKEIGEN_K_6_ZEN);
          MwKEIGEN_K_4_ZEN := NlKEIGEN_K_4_ZEN - TRUNC (NlKEIGEN_K_4_ZEN);
          MwKEIGEN_K_2_ZEN := NlKEIGEN_K_2_ZEN - TRUNC (NlKEIGEN_K_2_ZEN);
          NlKEIGEN_K_6_ZEN := TRUNC (NlKEIGEN_K_6_ZEN);
          NlKEIGEN_K_4_ZEN := TRUNC (NlKEIGEN_K_4_ZEN);
          NlKEIGEN_K_2_ZEN := TRUNC (NlKEIGEN_K_2_ZEN);
          MwSAGAKU         := NlKEIGEN_KINTO - (NlKEIGEN_K_6_ZEN + NlKEIGEN_K_4_ZEN + NlKEIGEN_K_2_ZEN
                              + TRUNC (NlKEIGEN_KINTO * MwKEIGEN_K_N_ZEN / MwKEIGEN_KINTO));
          MwKEIGEN_K_N_ZEN := (NlKEIGEN_KINTO * MwKEIGEN_K_N_ZEN / MwKEIGEN_KINTO) 
                              - TRUNC (NlKEIGEN_KINTO * MwKEIGEN_K_N_ZEN / MwKEIGEN_KINTO);
          WHILE MwSAGAKU > 0 LOOP
            -- 最大の端数値を持つ場合
            IF MwKEIGEN_K_6_ZEN = GREATEST (MwKEIGEN_K_6_ZEN, MwKEIGEN_K_4_ZEN, MwKEIGEN_K_2_ZEN, MwKEIGEN_K_N_ZEN) THEN 
              NlKEIGEN_K_6_ZEN := NlKEIGEN_K_6_ZEN + 1;
              MwSAGAKU         := MwSAGAKU - 1;
              MwKEIGEN_K_6_ZEN := 0;
            ELSIF NlKEIGEN_K_4_ZEN = GREATEST (MwKEIGEN_K_6_ZEN, MwKEIGEN_K_4_ZEN, MwKEIGEN_K_2_ZEN, MwKEIGEN_K_N_ZEN) THEN 
              NlKEIGEN_K_4_ZEN := NlKEIGEN_K_4_ZEN + 1;
              MwSAGAKU         := MwSAGAKU - 1;
              MwKEIGEN_K_4_ZEN := 0;
            ELSIF NlKEIGEN_K_2_ZEN = GREATEST (MwKEIGEN_K_6_ZEN, MwKEIGEN_K_4_ZEN, MwKEIGEN_K_2_ZEN, MwKEIGEN_K_N_ZEN) THEN 
              NlKEIGEN_K_2_ZEN := NlKEIGEN_K_2_ZEN + 1;
              MwSAGAKU         := MwSAGAKU - 1;
              MwKEIGEN_K_2_ZEN := 0;
            ELSE
              MwSAGAKU         := MwSAGAKU - 1;
              MwKEIGEN_K_N_ZEN := 0;
            END IF;
          END LOOP;
        END IF;
-- 2025/12/04 ZCZL.XIESHUN UPDATE END
        -- 4.計算賦課拡張ワークの未就学児軽減、18歳未満軽減額をセット
        RlEXT.KDM_KEIGEN_K_KINTOWARI := TRUNC(NKODOMO_KEIGEN_GAKU + 0.01,0);
        RlEXT.KDM18UN_KEIGEN_KINTOWARI := NlKEIGEN_KINTO18UN;
-- 2025/12/04 ZCZL.XIESHUN ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
        RlEXT.KDM_SAN_GEN_K_KEI := NwSAN_K_GENKEI;
        --優先区分が「個人／率／応能応益」または「世帯／率／応能応益」
        IF RlGENMEN_KOJIN.YUSEN_KBN IN (0, 1) THEN
          IF NLOOP_CNT_NOW = 1 THEN
            UPDATE ZLBTGENMEN_KOJIN_CAL
              SET KDM_BYODOWARI_KISO = TRUNC(NwBYODOWARI / 12)
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
              SET KDM_BYODOWARI_GENGAKU = KDM_BYODOWARI_KISO - TRUNC(NwBYODOWARI / 12)
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
              SET KDM_BYODOWARI_KISO = TRUNC(NwBYODOWARI / 12)
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
              SET KDM_SHOTOKU_GENGAKU = TRUNC(NwSHOTOKU_GENGAKU / 12),
                  KDM_SISANZEI_GENGAKU = TRUNC(NwSISANZEI_GENGAKU / 12),
                  KDM_KINTOWARI_GENGAKU = TRUNC(NwKINTOWARI_GENGAKU / 12),
                  KDM_KINTOWARI_18_GENGAKU = TRUNC(NwKINTOWARI18_GENGAKU / 12),
                  KDM_BYODOWARI_GENGAKU = TRUNC(NwBYODOWARI_GENGAKU / 12)
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
-- 2025/11/06 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
        NwKOJINKINTOWARI18      NUMBER(12) := 0;
        NKODOMOKOJIN            MTNUMARRAY12; --各月の個人別子ども判定
        NKDMKOJIN               MTNUMARRAY12; --各月の個人別18歳以上該当区分
-- 2025/12/04 ZCZL.XIESHUN ADD SART 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
        NwKINTO_KDM             NUMBER(12) := 0;   --個人毎賦課(軽減額を考慮しない)均等割額
        NwKINTO_KDM18           NUMBER(12) := 0;   --個人毎賦課(軽減額を考慮しない)18歳以上均等割額
-- 2025/12/04 ZCZL.XIESHUN ADD END
        NRTN                    NUMBER(2);
        NNIN                    NUMBER(2);
        NwKOJINKINTOWARI_SAN    NUMBER(12) := 0;
        nKDM_18_KBN             NUMBER(2);
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
            i_RKOJIN.NEW_SHIK_KBN IN (1, 3) ) THEN --擬主を見ないように統一


            -- 計算個人の各月資格区分を退避
            MlSHIK_KBN(1)  := i_RKOJIN.SHIK_4;
            MlSHIK_KBN(2)  := i_RKOJIN.SHIK_5;
            MlSHIK_KBN(3)  := i_RKOJIN.SHIK_6;
            MlSHIK_KBN(4)  := i_RKOJIN.SHIK_7;
            MlSHIK_KBN(5)  := i_RKOJIN.SHIK_8;
            MlSHIK_KBN(6)  := i_RKOJIN.SHIK_9;
            MlSHIK_KBN(7)  := i_RKOJIN.SHIK_10;
            MlSHIK_KBN(8)  := i_RKOJIN.SHIK_11;
            MlSHIK_KBN(9)  := i_RKOJIN.SHIK_12;
            MlSHIK_KBN(10) := i_RKOJIN.SHIK_1;
            MlSHIK_KBN(11) := i_RKOJIN.SHIK_2;
            MlSHIK_KBN(12) := i_RKOJIN.SHIK_3;
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
                    MwGENMENKOJIN(1)  := NVL(RwGENMENKOJIN.KDM_GENMEN_4,0);
                    MwGENMENKOJIN(2)  := NVL(RwGENMENKOJIN.KDM_GENMEN_5,0);
                    MwGENMENKOJIN(3)  := NVL(RwGENMENKOJIN.KDM_GENMEN_6,0);
                    MwGENMENKOJIN(4)  := NVL(RwGENMENKOJIN.KDM_GENMEN_7,0);
                    MwGENMENKOJIN(5)  := NVL(RwGENMENKOJIN.KDM_GENMEN_8,0);
                    MwGENMENKOJIN(6)  := NVL(RwGENMENKOJIN.KDM_GENMEN_9,0);
                    MwGENMENKOJIN(7)  := NVL(RwGENMENKOJIN.KDM_GENMEN_10,0);
                    MwGENMENKOJIN(8)  := NVL(RwGENMENKOJIN.KDM_GENMEN_11,0);
                    MwGENMENKOJIN(9)  := NVL(RwGENMENKOJIN.KDM_GENMEN_12,0);
                    MwGENMENKOJIN(10) := NVL(RwGENMENKOJIN.KDM_GENMEN_1,0);
                    MwGENMENKOJIN(11) := NVL(RwGENMENKOJIN.KDM_GENMEN_2,0);
                    MwGENMENKOJIN(12) := NVL(RwGENMENKOJIN.KDM_GENMEN_3,0);
                END IF;

            END IF;
            --個人の子ども軽減有無をセット
            NKODOMOKOJIN(1) := 0;
            NKODOMOKOJIN(2) := 0;
            NKODOMOKOJIN(3) := 0;
            NKODOMOKOJIN(4) := 0;
            NKODOMOKOJIN(5) := 0;
            NKODOMOKOJIN(6) := 0;
            NKODOMOKOJIN(7) := 0;
            NKODOMOKOJIN(8) := 0;
            NKODOMOKOJIN(9) := 0;
            NKODOMOKOJIN(10) := 0;
            NKODOMOKOJIN(11) := 0;
            NKODOMOKOJIN(12) := 0;

            NRTN := ZLBPK00090.FCKODOMO_HANTEI(i_NSETAI,i_NNENDO_BUN,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),i_RKOJIN.KOJIN_NO,NNIN,i_VTANMATSU);
            IF NNIN != 0 AND i_RKOJIN.SHIK_4 > 0 AND i_RKOJIN.SHIK_4 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(1) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_5 > 0 AND i_RKOJIN.SHIK_5 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(2) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_6 > 0 AND i_RKOJIN.SHIK_6 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(3) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_7 > 0 AND i_RKOJIN.SHIK_7 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(4) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_8 > 0 AND i_RKOJIN.SHIK_8 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(5) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_9 > 0 AND i_RKOJIN.SHIK_9 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(6) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_10 > 0 AND i_RKOJIN.SHIK_10 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(7) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_11 > 0 AND i_RKOJIN.SHIK_11 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(8) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_12 > 0 AND i_RKOJIN.SHIK_12 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(9) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_1 > 0 AND i_RKOJIN.SHIK_1 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(10) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_2 > 0 AND i_RKOJIN.SHIK_2 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(11) := 1;
            END IF;
            IF NNIN != 0 AND i_RKOJIN.SHIK_3 > 0 AND i_RKOJIN.SHIK_3 NOT IN(2,32,42)  THEN
              NKODOMOKOJIN(12) := 1;
            END IF;

            --個人の18歳以上該当区分をセット
            NKDMKOJIN(1) := 0;
            NKDMKOJIN(2) := 0;
            NKDMKOJIN(3) := 0;
            NKDMKOJIN(4) := 0;
            NKDMKOJIN(5) := 0;
            NKDMKOJIN(6) := 0;
            NKDMKOJIN(7) := 0;
            NKDMKOJIN(8) := 0;
            NKDMKOJIN(9) := 0;
            NKDMKOJIN(10) := 0;
            NKDMKOJIN(11) := 0;
            NKDMKOJIN(12) := 0;

            NRTN := ZLBPK00140.FCKDM_HANTEI(i_NSETAI,i_NNENDO_BUN,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),i_RKOJIN.KOJIN_NO,NNIN,i_VTANMATSU);
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_4 > 0 AND i_RKOJIN.SHIK_4 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_4 > 0 AND i_RKOJIN.SHIK_4 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(1) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_5 > 0 AND i_RKOJIN.SHIK_5 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_5 > 0 AND i_RKOJIN.SHIK_5 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(2) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_6 > 0 AND i_RKOJIN.SHIK_6 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_6 > 0 AND i_RKOJIN.SHIK_6 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(3) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_7 > 0 AND i_RKOJIN.SHIK_7 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_7 > 0 AND i_RKOJIN.SHIK_7 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(4) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_8 > 0 AND i_RKOJIN.SHIK_8 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_8 > 0 AND i_RKOJIN.SHIK_8 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(5) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_9 > 0 AND i_RKOJIN.SHIK_9 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_9 > 0 AND i_RKOJIN.SHIK_9 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(6) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_10 > 0 AND i_RKOJIN.SHIK_10 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_10 > 0 AND i_RKOJIN.SHIK_10 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(7) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_11 > 0 AND i_RKOJIN.SHIK_11 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_11 > 0 AND i_RKOJIN.SHIK_11 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(8) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_12 > 0 AND i_RKOJIN.SHIK_12 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_12 > 0 AND i_RKOJIN.SHIK_12 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(9) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_1 > 0 AND i_RKOJIN.SHIK_1 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_1 > 0 AND i_RKOJIN.SHIK_1 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(10) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_2 > 0 AND i_RKOJIN.SHIK_2 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_2 > 0 AND i_RKOJIN.SHIK_2 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(11) := 1;
            END IF;
--2025/10/17 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--            IF NNIN != 0 AND i_RKOJIN.SHIK_3 > 0 AND i_RKOJIN.SHIK_3 NOT IN(2,32,42)  THEN
            IF NNIN = 0 AND i_RKOJIN.SHIK_3 > 0 AND i_RKOJIN.SHIK_3 NOT IN(2,5,30,32,40,42)  THEN
              NKDMKOJIN(12) := 1;
            END IF;

            FOR NwIX IN 1..12 LOOP
                IF i_RKOJIN.SEKISAN_GAI_KBN = 1 THEN
                    -- 資産割額と均等額を加算
                    MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX)
                                          + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KDM / 100 * MlOUNOU(NwIX) / 100);
-- 2025/12/12 ZCZL.XIESHUN DELETE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084(3回目)
-- 2025/12/04 ZCZL.XIESHUN ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--                    -- 個人毎賦課均等割額への均等割額の加算
--                    NwKINTO_KDM := NwKINTO_KDM + TRUNC (NlJKINTO * MlOUEKI(NwIX) / 100);
-- 2025/12/04 ZCZL.XIESHUN ADD END
-- 2025/12/12 ZCZL.XIESHUN DELETE END
                    -- 18歳以上の場合、均等割額および18歳以上均等割額を加算
                    IF NKDMKOJIN(NwIX) = 1 THEN
                        MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX) + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                        MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX) + TRUNC(NlJKINTO18 * MlOUEKI(NwIX) / 100);
-- 2025/12/12 ZCZL.XIESHUN DELETE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084(3回目)
-- 2025/12/04 ZCZL.XIESHUN ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--                        -- 個人毎賦課18歳以上賦課均等割額への18歳以上均等割額の加算
--                        NwKINTO_KDM18 := NwKINTO_KDM18 + TRUNC (NlJKINTO18 * MlOUEKI(NwIX) / 100);
-- 2025/12/04 ZCZL.XIESHUN ADD END
-- 2025/12/12 ZCZL.XIESHUN DELETE END
                    END IF;
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
                                              + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KDM / 100 * MlOUNOU(NwIX) / 100);
                      ELSE
                      MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX)
                                            + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KDM / 100 * MlOUNOU(NwIX) / 100);
                      END IF;
                      MlZEIGAKU_SEKI(NwIX) := MlZEIGAKU_SEKI(NwIX) - i_RKOJIN.KDM_SAN_GEN_SHOTOKU;
                    END IF;

                    IF (i_RKOJIN.SHIK_4  IN (3, 13) OR i_RKOJIN.SHIK_5  IN (3, 13) OR
                        i_RKOJIN.SHIK_6  IN (3, 13) OR i_RKOJIN.SHIK_7  IN (3, 13) OR
                        i_RKOJIN.SHIK_8  IN (3, 13) OR i_RKOJIN.SHIK_9  IN (3, 13) OR
                        i_RKOJIN.SHIK_10 IN (3, 13) OR i_RKOJIN.SHIK_11 IN (3, 13) OR
                        i_RKOJIN.SHIK_12 IN (3, 13) OR i_RKOJIN.SHIK_1  IN (3, 13) OR
                        i_RKOJIN.SHIK_2  IN (3, 13) OR i_RKOJIN.SHIK_3  IN (3, 13)) AND i_RKOJIN.CUST_3 = 1 AND NlNENREI_KEIGEN = 1 THEN
                      MlNEN_CNT_SEKI(NwIX) := MlNEN_CNT_SEKI(NwIX) + 1;
                    END IF;
                END IF;
                IF MlSHIK_KBN(NwIX) IN (1, 3, 11, 13) THEN
                    MlCNT(NwIX)     := MlCNT(NwIX) + 1;
                    -- 人員(各月有資格者数　うち18歳以上/うち18歳未満)の加算
--2025/10/13 ZCZL.LIUHUAJUN DELETE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                    IF NKDMKOJIN(NwIX) = 1 THEN
--                        MlCNT18(NwIX) := MlCNT18(NwIX) + 1;
--                    ELSE
--                        MlCNT18UN(NwIX) := MlCNT18UN(NwIX) + 1;
--                    END IF;
--2025/10/13 ZCZL.LIUHUAJUN DELETE END
                    -- 資産割額と均等額を加算
                    IF NLOOP_CNT_NOW = 1 THEN
                      MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KDM / 100 * MlOUNOU(NwIX) / 100);
-- 2025/12/12 ZCZL.XIESHUN ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084(3回目)
                      -- 個人毎賦課均等割額への均等割額の加算
                      NwKINTO_KDM := NwKINTO_KDM + TRUNC (NlJKINTO * MlOUEKI(NwIX) / 100);
-- 2025/12/12 ZCZL.XIESHUN ADD END
                      -- 18歳以上の場合、均等割額および18歳以上均等割額を加算
                      IF NKDMKOJIN(NwIX) = 1 THEN
                          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC(NlJKINTO18 * MlOUEKI(NwIX) / 100);
-- 2025/12/12 ZCZL.XIESHUN ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084(3回目)
                          -- 個人毎賦課18歳以上賦課均等割額への18歳以上均等割額の加算
                          NwKINTO_KDM18   := NwKINTO_KDM18 + TRUNC (NlJKINTO18 * MlOUEKI(NwIX) / 100);
-- 2025/12/12 ZCZL.XIESHUN ADD END
                      END IF;
                      -- 個人別の資産割額
                      NwKOJINSISANZEI  := NwKOJINSISANZEI  + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KDM / 100 * MlOUNOU(NwIX) / 100);
                      -- 個人別の均等割額
                      -- 18歳以上の場合、均等割額および18歳以上均等割額
                      IF NKDMKOJIN(NwIX) = 1 THEN
                          NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100)  + TRUNC(NlJKINTO18 * MlOUEKI(NwIX) / 100);
-- 2025/11/06 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                          NwKOJINKINTOWARI18 := NwKOJINKINTOWARI18 + TRUNC(NlJKINTO18 * MlOUEKI(NwIX) / 100);
                      END IF;
                      IF MlSAN_KBN(NwIX) > 0 AND MlCNT(NwIX) >= MlSANCNT(NwIX) THEN
                        IF MlOUNOU(NwIX) = 100 THEN
                          MlSANCNT(NwIX)    := MlSANCNT(NwIX) + 1;
                          IF NKDMKOJIN(NwIX) = 1 THEN
                              MlSANCNT18(NwIX)  := MlSANCNT18(NwIX) + 1;
                          ELSE
                              MlSANCNT18UN(NwIX) := MlSANCNT18UN(NwIX) + 1;
                          END IF;
                        ELSE
                          MlSANCNT_K(NwIX)  := MlSANCNT_K(NwIX) + 1;
                          IF NKDMKOJIN(NwIX) = 1 THEN
                              MlSANCNT_K18(NwIX)   := MlSANCNT_K18(NwIX) + 1;
                          ELSE
                              MlSANCNT_K18UN(NwIX) := MlSANCNT_K18UN(NwIX) + 1;
                          END IF;
                        END IF;
                      END IF;
                    ELSE
                      MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KDM / 100
                                                               - i_RKOJIN.SHISANZEI * NSHISAN_KDM / 100 * MwGENMENKOJIN(NwIX)
                                                               * NVL(RwGENMENKOJIN.KDM_SISANZEI_RITSU,0) / 100);
                      -- 個人別の資産割額
                      NwKOJINSISANZEI  := NwKOJINSISANZEI  + TRUNC(i_RKOJIN.SHISANZEI * NSHISAN_KDM / 100
                                                               - i_RKOJIN.SHISANZEI * NSHISAN_KDM / 100 * MwGENMENKOJIN(NwIX)
--2025/10/09 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_No57指摘対応
--                                                               * NVL(RwGENMENKOJIN.S_SISANZEI_RITSU,0) / 100);
                                                               * NVL(RwGENMENKOJIN.KDM_SISANZEI_RITSU,0) / 100);
                      -- 個人医療産前産後均等割軽減額
                      IF MlSAN_KBN(NwIX) > 0 AND MlCNT(NwIX) >= MlSANCNT(NwIX) THEN
                        MlSANCNT(NwIX)    := MlSANCNT(NwIX) + 1;
                        IF NKDMKOJIN(NwIX) = 1 THEN
                            MlSANCNT18(NwIX)   := MlSANCNT18(NwIX) + 1;
                        ELSE
                            MlSANCNT18UN(NwIX) := MlSANCNT18UN(NwIX) + 1;
                        END IF;
                        IF NGENMEN_KOJIN_KBN = 0 THEN
                          NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                          --18歳以上の場合(NKDMKOJIN(NwIX) =1)、均等割額および18歳以上均等割額を加算
                          IF NKDMKOJIN(NwIX) =1 THEN
                            NwKOJINKINTOWARI     := NwKOJINKINTOWARI + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN + TRUNC(NlJKINTO18 * MlOUEKI(NwIX) / 100);
                            NwKOJINKINTOWARI     := NwKOJINKINTOWARI + TRUNC(NlJKINTO18 * MlOUEKI(NwIX) / 100);
-- 2025/11/06 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                            NwKOJINKINTOWARI18   := NwKOJINKINTOWARI18 + TRUNC(NlJKINTO18 * MlOUEKI(NwIX) / 100);
                          END IF;
                        ELSE
                          IF    MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割の場合
                            --ただし年税額への加算は18歳以上の場合(NKDMKOJIN(NwIX) =1)とする
                            IF NKDMKOJIN(NwIX) =1 THEN
                              MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)+ TRUNC(((NlJKINTO - NlJKGEN1) * MwGENMENKOJIN(NwIX)
                                                                                               * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0))/ 100);
                            END IF;
                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                                                  + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN1 - CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100)
                                                  * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            --18歳以上の場合(NKDMKOJIN(NwIX) =1)、18歳以上257割軽減後に、18歳以上均等割減免率分を減じて加算(未就学児軽減の考慮は不要)
                            IF NKDMKOJIN(NwIX) =1 THEN
                              MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                               + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN118)* MwGENMENKOJIN(NwIX)
                                               * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
                              NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                                                    + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN118)* MwGENMENKOJIN(NwIX)
                                                    * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
                            END IF;
                          ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN       -- 軽減4割の場合
                            --ただし年税額への加算は18歳以上の場合(NKDMKOJIN(NwIX) =1)とする
                            IF NKDMKOJIN(NwIX) =1 THEN
                              MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)+ TRUNC(((NlJKINTO - NlJKGEN2) * MwGENMENKOJIN(NwIX)
                                                                                               * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0))/ 100);
                            END IF;
                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                                                 + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN2 - CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100)
                                                 * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            --18歳以上の場合(NKDMKOJIN(NwIX) =1)、18歳以上257割軽減後に、18歳以上均等割減免率分を減じて加算(未就学児軽減の考慮は不要)
                            IF NKDMKOJIN(NwIX) =1 THEN
                              MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                               + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN218)* MwGENMENKOJIN(NwIX)
                                               * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
                              NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                                                    + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN218)* MwGENMENKOJIN(NwIX)
                                                    * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
                            END IF;
                          ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN       -- 軽減2割の場合
                            --ただし年税額への加算は18歳以上の場合(NKDMKOJIN(NwIX) =1)とする
                            IF NKDMKOJIN(NwIX) =1 THEN
                              MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)+ TRUNC(((NlJKINTO - NlJKGEN3) * MwGENMENKOJIN(NwIX)
                                                                                               * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0))/ 100);
                            END IF;
                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                                                  + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN3 - CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100)
                                                  * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            --18歳以上の場合(NKDMKOJIN(NwIX) =1)、18歳以上257割軽減後に、18歳以上均等割減免率分を減じて加算(未就学児軽減の考慮は不要)
                            IF NKDMKOJIN(NwIX) =1 THEN
                              MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                               + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN318)* MwGENMENKOJIN(NwIX)
                                               * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
                              NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                                                    + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN318)* MwGENMENKOJIN(NwIX)
                                                    * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
                            END IF;
                          ELSE
                            --ただし年税額への加算は18歳以上の場合(NKDMKOJIN(NwIX) =1)とする
                            IF NKDMKOJIN(NwIX) =1 THEN
                              MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)+ TRUNC((NlJKINTO * MwGENMENKOJIN(NwIX)
                                                                  * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0))/ 100);
                            END IF;
                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                                                  + TRUNC(NlJKINTO - (NlJKINTO - CEIL(NlJKINTO * NKODOMO_KEIGEN_WARIAI / 100)
                                                  * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            --18歳以上の場合(NKDMKOJIN(NwIX) =1)、18歳以上257割軽減後に、18歳以上均等割減免率分を減じて加算(未就学児軽減の考慮は不要)
                            IF NKDMKOJIN(NwIX) =1 THEN
                              MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                               + TRUNC(NlJKINTO18 - NlJKINTO18 * MwGENMENKOJIN(NwIX)
                                               * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
                              NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                                                    + TRUNC(NlJKINTO18 - NlJKINTO18 * MwGENMENKOJIN(NwIX)
                                                    * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
                            END IF;
                          END IF;
                        END IF;
                      END IF;
                      -- 個人別の均等割額
                      IF NGENMEN_KOJIN_KBN = 0 THEN
                          --ただし18歳以上の場合(NKDMKOJIN(NwIX) =1)のみとする
                          IF NKDMKOJIN(NwIX) =1 THEN
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                            NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO * MlOUEKI(NwIX) / 100);
                            -- 18歳以上の場合(NKDMKOJIN(NwIX) =1)、18歳以上均等割額を加算
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX) + TRUNC(NlJKINTO18 * MlOUEKI(NwIX) / 100);
                            NwKOJINKINTOWARI := NwKOJINKINTOWARI + TRUNC(NlJKINTO18 * MlOUEKI(NwIX) / 100);
-- 2025/11/06 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                            NwKOJINKINTOWARI18 := NwKOJINKINTOWARI18 + TRUNC(NlJKINTO18 * MlOUEKI(NwIX) / 100);
                          END IF;
                      ELSE
                        IF    MlKEIGEN_KBN(NwIX) = NlJKEIGEN1 THEN       -- 軽減6割の場合
                          --ただし年税額への加算は18歳以上の場合(NKDMKOJIN(NwIX) =1)とする
                          IF NKDMKOJIN(NwIX) =1 THEN
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN1 - CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100)
                                             * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            NwKOJINKINTOWARI := NwKOJINKINTOWARI
                                             + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN1 - CEIL((NlJKINTO - NlJKGEN1) * NKODOMO_KEIGEN_WARIAI / 100)
                                             * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            -- 18歳以上の場合(NKDMKOJIN(NwIX) =1)、18歳以上均等割減免率分を減じて加算(未就学児軽減の考慮は不要)
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN118)* MwGENMENKOJIN(NwIX)
                                             * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
--2025/10/09 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_No60指摘対応
--                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                            NwKOJINKINTOWARI := NwKOJINKINTOWARI
                                                  + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN118)* MwGENMENKOJIN(NwIX)
                                                  * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
-- 2025/11/06 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                            NwKOJINKINTOWARI18 := NwKOJINKINTOWARI18 
                                                   + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN118)* MwGENMENKOJIN(NwIX) 
                                                   * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0 ) / 100);
-- 2025/11/06 ZCZL.LIUDI ADD END
                          END IF;
                        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN2 THEN       -- 軽減4割の場合
                          --ただし年税額への加算は18歳以上の場合(NKDMKOJIN(NwIX) =1)とする
                          IF NKDMKOJIN(NwIX) =1 THEN
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN2 - CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100)
                                             * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            NwKOJINKINTOWARI := NwKOJINKINTOWARI
                                              + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN2 - CEIL((NlJKINTO - NlJKGEN2) * NKODOMO_KEIGEN_WARIAI / 100)
                                              * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            --18歳以上の場合(NKDMKOJIN(NwIX) =1)、18歳以上257割軽減後に、18歳以上均等割減免率分を減じて加算(未就学児軽減の考慮は不要)
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN218)* MwGENMENKOJIN(NwIX)
                                             * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
--2025/10/09 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_No60指摘対応
--                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                            NwKOJINKINTOWARI := NwKOJINKINTOWARI
                                                  + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN218)* MwGENMENKOJIN(NwIX)
                                                  * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
-- 2025/11/06 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                            NwKOJINKINTOWARI18 := NwKOJINKINTOWARI18 
                                                  + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN218)* MwGENMENKOJIN(NwIX) 
                                                  * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0 ) / 100);
-- 2025/11/06 ZCZL.LIUDI ADD END
                          END IF;
                        ELSIF MlKEIGEN_KBN(NwIX) = NlJKEIGEN3 THEN       -- 軽減2割の場合
                          --ただし年税額への加算は18歳以上の場合(NKDMKOJIN(NwIX) =1)とする
                          IF NKDMKOJIN(NwIX) =1 THEN
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN3 - CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100)
                                             * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            NwKOJINKINTOWARI := NwKOJINKINTOWARI
                                              + TRUNC(NlJKINTO - (NlJKINTO - NlJKGEN3 - CEIL((NlJKINTO - NlJKGEN3) * NKODOMO_KEIGEN_WARIAI / 100)
                                              * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            --18歳以上の場合(NKDMKOJIN(NwIX) =1)、18歳以上257割軽減後に、18歳以上均等割減免率分を減じて加算(未就学児軽減の考慮は不要)
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN318)* MwGENMENKOJIN(NwIX)
                                             * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
--2025/10/09 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_No60指摘対応
--                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                            NwKOJINKINTOWARI := NwKOJINKINTOWARI
                                                  + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN318)* MwGENMENKOJIN(NwIX)
                                                  * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
-- 2025/11/06 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                            NwKOJINKINTOWARI18 := NwKOJINKINTOWARI18 
                                                  + TRUNC(NlJKINTO18 - (NlJKINTO18 - NlJKGEN318)* MwGENMENKOJIN(NwIX) 
                                                  * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0 ) / 100);
-- 2025/11/06 ZCZL.LIUDI ADD END
                          END IF;
                        ELSE
                          --ただし年税額への加算は18歳以上の場合(NKDMKOJIN(NwIX) =1)とする
                          IF NKDMKOJIN(NwIX) =1 THEN
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                               + TRUNC(NlJKINTO - (NlJKINTO - CEIL(NlJKINTO * NKODOMO_KEIGEN_WARIAI / 100)
                                               * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            NwKOJINKINTOWARI := NwKOJINKINTOWARI
                                              + TRUNC(NlJKINTO - (NlJKINTO - CEIL(NlJKINTO * NKODOMO_KEIGEN_WARIAI / 100)
                                              * NKODOMOKOJIN(NwIX)) * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_KINTOWARI_RITSU,0) / 100);
                            --18歳以上の場合(NKDMKOJIN(NwIX) =1)、18歳以上257割軽減後に、18歳以上均等割減免率分を減じて加算(未就学児軽減の考慮は不要)
                            MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                             + TRUNC(NlJKINTO18 - NlJKINTO18 * MwGENMENKOJIN(NwIX)
                                             * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
--2025/10/09 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_No60指摘対応
--                            NwKOJINKINTOWARI_SAN := NwKOJINKINTOWARI_SAN
                            NwKOJINKINTOWARI := NwKOJINKINTOWARI
                                                  + TRUNC(NlJKINTO18 - NlJKINTO18 * MwGENMENKOJIN(NwIX)
                                                  * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0)/ 100);
-- 2025/11/06 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                            NwKOJINKINTOWARI18 := NwKOJINKINTOWARI18 
                                                  + TRUNC(NlJKINTO18 -  NlJKINTO18 * MwGENMENKOJIN(NwIX) 
                                                  * NVL(RwGENMENKOJIN.KDM_KINTOWARI_18_RITSU,0 ) / 100);
-- 2025/11/06 ZCZL.LIUDI ADD END
                          END IF;
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
                       IF MlSAN_KBN(NwIX) = 0 THEN
                        IF MlSHITSU_KBN(NwIX) > 0 THEN
                          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                           + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KDM / 100 * MlOUNOU(NwIX) / 100);
                          -- 個人別の所得割額
                          NwKOJINSHOTOKU  := NwKOJINSHOTOKU + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KDM / 100 * MlOUNOU(NwIX) / 100);
                        ELSE
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KDM / 100 * MlOUNOU(NwIX) / 100);
                        -- 個人別の所得割額
                        NwKOJINSHOTOKU  := NwKOJINSHOTOKU + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KDM / 100 * MlOUNOU(NwIX) / 100);
                        END IF;
                       END IF;
                      ELSE
                       IF MlSAN_KBN(NwIX) = 0 THEN
                        IF MlSHITSU_KBN(NwIX) > 0 THEN
                          MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                           + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KDM / 100 - i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KDM / 100
                                           * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_SHOTOKU_RITSU,0) / 100);
                          -- 個人別の所得割額
                          NwKOJINSHOTOKU  := NwKOJINSHOTOKU
                                           + TRUNC(i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KDM / 100 - i_RKOJIN.SHITSU_KAHYO * NSHOTOKU_KDM / 100
                                           * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_SHOTOKU_RITSU,0) / 100);
                        ELSE
                        MlZEIGAKU(NwIX) := MlZEIGAKU(NwIX)
                                         + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KDM / 100 - i_RKOJIN.KAHYO * NSHOTOKU_KDM / 100
                                         * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_SHOTOKU_RITSU,0) / 100);
                        -- 個人別の所得割額
                        NwKOJINSHOTOKU  := NwKOJINSHOTOKU
                                         + TRUNC(i_RKOJIN.KAHYO * NSHOTOKU_KDM / 100 - i_RKOJIN.KAHYO * NSHOTOKU_KDM / 100
                                         * MwGENMENKOJIN(NwIX) * NVL(RwGENMENKOJIN.KDM_SHOTOKU_RITSU,0) / 100);
                        END IF;
                       END IF;
                      END IF;
                    END IF;

                    IF MlSHIK_KBN(NwIX) IN (3, 13) AND i_RKOJIN.CUST_3 = 1 AND NlNENREI_KEIGEN = 1 THEN
                      MlNEN_CNT(NwIX) := MlNEN_CNT(NwIX) + 1;
                    END IF;
                END IF;
            END LOOP;
          -- 計算拡張の産前産後所得割軽減額計に格納する値を更新
          IF NLOOP_CNT_NOW = 1 THEN
            RlEXT.KDM_SAN_GEN_S_KEI := RlEXT.KDM_SAN_GEN_S_KEI + i_RKOJIN.KDM_SAN_GEN_SHOTOKU;
            --計算個人の更新(18歳以上該当区分の更新)を行う
            IF NKODOMOKOJIN(1) = 1 OR NKODOMOKOJIN(2) = 1 OR NKODOMOKOJIN(3) = 1 OR NKODOMOKOJIN(4) = 1
               OR NKODOMOKOJIN(5) = 1 OR NKODOMOKOJIN(6) = 1 OR NKODOMOKOJIN(7) = 1 OR NKODOMOKOJIN(8) = 1
               OR NKODOMOKOJIN(9) = 1 OR NKODOMOKOJIN(10) = 1 OR NKODOMOKOJIN(11) = 1 OR NKODOMOKOJIN(12) = 1 THEN
              nKDM_18_KBN := 2;     -- 未就学児
            ELSIF NKDMKOJIN(1) = 1 OR NKDMKOJIN(2) = 1 OR NKDMKOJIN(3) = 1 OR NKDMKOJIN(4) = 1
               OR NKDMKOJIN(5) = 1 OR NKDMKOJIN(6) = 1 OR NKDMKOJIN(7) = 1 OR NKDMKOJIN(8) = 1
               OR NKDMKOJIN(9) = 1 OR NKDMKOJIN(10) = 1 OR NKDMKOJIN(11) = 1 OR NKDMKOJIN(12) = 1 THEN
              nKDM_18_KBN := 1;     -- 18歳以上
            ELSE
              nKDM_18_KBN := 0;     -- 18歳未満
            END IF;
            UPDATE ZLBTKOJIN_CAL
               SET KDM_18_KBN = nKDM_18_KBN
-- 2025/12/04 ZCZL.XIESHUN ADD SART 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
                  ,KDM_KINTO   = TRUNC (NwKINTO_KDM / 12)
                  ,KDM_KINTO18 = TRUNC (NwKINTO_KDM18 / 12)
-- 2025/12/04 ZCZL.XIESHUN ADD END
             WHERE KOKU_SETAI_NO   = i_RKOJIN.KOKU_SETAI_NO
               AND KOJIN_NO        = i_RKOJIN.KOJIN_NO
               AND SANTEIDANTAI_CD = i_RKOJIN.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = i_RKOJIN.CHOTEI_NENDO
               AND NENDO_BUN       = i_RKOJIN.NENDO_BUN
               AND TSUCHI_NO       = i_RKOJIN.TSUCHI_NO;
          END IF;
          IF NGENMEN_KOJIN_KBN = 1 THEN
              IF NLOOP_CNT_NOW = 1 THEN
                  -- 減免個人データを作成 insert ZLBTGENMEN_KOJIN_TMP → ZLBTGENMEN_KOJIN_CAL
                  -- 医療で既に insert しているので不要

                  vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                  vSQL := vSQL || ' SET KDM_SHOTOKU_KISO   = :SHOTOKU,';
                  vSQL := vSQL ||      'KDM_SISANZEI_KISO  = :SISANZEI,';
                  vSQL := vSQL ||      'KDM_KINTOWARI_KISO = :KINTOWARI';
-- 2025/11/06 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                  vSQL := vSQL ||      ',KDM_KINTOWARI_18_KISO = :KINTOWARI_18';
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
-- 2025/11/06 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                                                  TRUNC(NwKOJINKINTOWARI18 / 12),
                                                  RwGENMENKOJIN.KOKU_SETAI_NO,
                                                  RwGENMENKOJIN.SANTEIDANTAI_CD,
                                                  RwGENMENKOJIN.KOJIN_NO,
                                                  RwGENMENKOJIN.NENDO_BUN,
                                                  RwGENMENKOJIN.SYS_TANMATSU_NO,
                                                  RwGENMENKOJIN.TSUCHI_NO;
              ELSE
                  vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                  vSQL := vSQL || ' SET KDM_SHOTOKU_GENGAKU   = KDM_SHOTOKU_KISO   - :1,';
                  vSQL := vSQL ||      'KDM_SISANZEI_GENGAKU  = KDM_SISANZEI_KISO  - :2,';
                  vSQL := vSQL ||      'KDM_KINTOWARI_GENGAKU = KDM_KINTOWARI_KISO - :3';
-- 2025/11/06 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                  vSQL := vSQL ||      ',KDM_KINTOWARI_18_GENGAKU = KDM_KINTOWARI_18_KISO - :KINTOWARI_18';
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
-- 2025/11/06 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00009
                                                  TRUNC(NwKOJINKINTOWARI18 / 12),
                                                  RwGENMENKOJIN.KOKU_SETAI_NO,
                                                  RwGENMENKOJIN.SANTEIDANTAI_CD,
                                                  RwGENMENKOJIN.KOJIN_NO,
                                                  RwGENMENKOJIN.NENDO_BUN,
                                                  RwGENMENKOJIN.SYS_TANMATSU_NO,
                                                  RwGENMENKOJIN.TSUCHI_NO;

                  vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                  vSQL := vSQL || ' SET KDM_GENGAKU_KEI   = KDM_SHOTOKU_GENGAKU + KDM_SISANZEI_GENGAKU + KDM_KINTOWARI_GENGAKU + KDM_BYODOWARI_GENGAKU';
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

        RlKIHON.KEIGEN_K_WARI := 0;
        RlKIHON.KEIGEN_B_WARI := 0;

    END subTukiwariMae;
-------------------------------------------------------------------------------
-- 15 欠番
-- 14 欠番
-- 13 欠番
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 11 計算個人0件時セット
-------------------------------------------------------------------------------
    PROCEDURE subOutInit IS
    BEGIN

        -- 計算子ども基本クリア
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
        RlKIHON.SYS_SHOKUINKOJIN_NO := '0';
        RlKIHON.SYS_TANMATSU_NO     := i_VTANMATSU;
        RlKIHON.KINTO_CNT_KDM18     := 0;
        RlKIHON.KINTO_KDM18         := 0;

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

        RlEXT.KDM_NENREI_KEIGEN        := 0;
        RlEXT.KDM_SHOGAI_GENMEN        := 0;
        RlEXT.KDM_KEIKA_H_SHOTOKU      := 0;
        RlEXT.KDM_KEIKA_H_SHISAN       := 0;
        RlEXT.KDM_KEIKA_H_KINTOWARI    := 0;
        RlEXT.KDM_KEIKA_BYODOWARI      := 0;
        RlEXT.KDM_KEIGEN_K_KINTOWARI   := 0;
        RlEXT.KDM_SAN_GEN_K_KEI        := 0;
        RlEXT.KDM_SAN_GEN_S_KEI        := 0;
        RlEXT.NEW_KDM18_CNT            := 0;
        RlEXT.KDM18_F4_CNT             := 0;
        RlEXT.KDM18_FUKA_CNT           := 0;
        RlEXT.KDM18_CNT_4              := 0;
        RlEXT.KDM18_CNT_5              := 0;
        RlEXT.KDM18_CNT_6              := 0;
        RlEXT.KDM18_CNT_7              := 0;
        RlEXT.KDM18_CNT_8              := 0;
        RlEXT.KDM18_CNT_9              := 0;
        RlEXT.KDM18_CNT_10             := 0;
        RlEXT.KDM18_CNT_11             := 0;
        RlEXT.KDM18_CNT_12             := 0;
        RlEXT.KDM18_CNT_1              := 0;
        RlEXT.KDM18_CNT_2              := 0;
        RlEXT.KDM18_CNT_3              := 0;
        RlEXT.KDM18_KEIGEN_KINTOWARI   := 0;
        RlEXT.NEW_KDM18UN_CNT          := 0;
        RlEXT.KDM18UN_CNT_4            := 0;
        RlEXT.KDM18UN_CNT_5            := 0;
        RlEXT.KDM18UN_CNT_6            := 0;
        RlEXT.KDM18UN_CNT_7            := 0;
        RlEXT.KDM18UN_CNT_8            := 0;
        RlEXT.KDM18UN_CNT_9            := 0;
        RlEXT.KDM18UN_CNT_10           := 0;
        RlEXT.KDM18UN_CNT_11           := 0;
        RlEXT.KDM18UN_CNT_12           := 0;
        RlEXT.KDM18UN_CNT_1            := 0;
        RlEXT.KDM18UN_CNT_2            := 0;
        RlEXT.KDM18UN_CNT_3            := 0;
        RlEXT.KDM18UN_KEIGEN_KINTOWARI := 0;

    END subOutInit;

-------------------------------------------------------------------------------
-- 12 計算基本・登録
-------------------------------------------------------------------------------
    PROCEDURE subInsert IS
        NRTN                      NUMBER;
        o_nKDM_SNENDO             NUMBER;               -- 子ども分開始年度
    BEGIN
        NRTN := ZLBPK00140.FCKDM_SNENDO (o_nKDM_SNENDO);
        IF i_NNENDO_BUN < o_nKDM_SNENDO THEN
          subOutInit;
        END IF;

        -- 計算支援基本登録
        BEGIN
            INSERT INTO ZLBTKDM_KIHON_CAL VALUES RlKIHON;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subInsert 計算子ども基本登録(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
        END;

        -- 計算拡張の登録
        IF NlRTN = c_NOK  THEN
            BEGIN
                UPDATE ZLBTEXT_CAL SET KDM_NENREI_KEIGEN        = RlEXT.KDM_NENREI_KEIGEN,         -- 子ども年齢軽減
                                       KDM_SHOGAI_GENMEN        = RlEXT.KDM_SHOGAI_GENMEN,         -- 子ども身障減免
                                       KDM_KEIKA_H_SHOTOKU      = RlEXT.KDM_KEIKA_H_SHOTOKU,       -- 子ども所得割積算軽減額(被扶養者)
                                       KDM_KEIKA_H_SHISAN       = RlEXT.KDM_KEIKA_H_SHISAN,        -- 子ども資産割積算軽減額(被扶養者)
                                       KDM_KEIKA_H_KINTOWARI    = RlEXT.KDM_KEIKA_H_KINTOWARI,     -- 子ども均等割積算軽減額(被扶養者)
                                       KDM_KEIKA_BYODOWARI      = RlEXT.KDM_KEIKA_BYODOWARI,       -- 子ども平等割積算軽減額(被扶養者/特定同一)
                                       KDM_KEIGEN_K_KINTOWARI   = RlEXT.KDM_KEIGEN_K_KINTOWARI,    -- 子ども均等割軽減額(未就学児)
                                       KDM_SAN_GEN_K_KEI        = RlEXT.KDM_SAN_GEN_K_KEI,         -- 子ども産前産後均等割軽減額計
                                       KDM_SAN_GEN_S_KEI        = RlEXT.KDM_SAN_GEN_S_KEI,         -- 子ども産前産後所得割軽減額計
                                       NEW_KDM18_CNT            = RlEXT.NEW_KDM18_CNT,             -- 18歳以上人数最新
                                       KDM18_F4_CNT             = RlEXT.KDM18_F4_CNT,              -- 18歳以上人数賦課期日
                                       KDM18_FUKA_CNT           = RlEXT.KDM18_FUKA_CNT,            -- 18歳以上人数賦課発生時
                                       KDM18_CNT_4              = RlEXT.KDM18_CNT_4,               -- 18歳以上人数4月
                                       KDM18_CNT_5              = RlEXT.KDM18_CNT_5,               -- 18歳以上人数5月
                                       KDM18_CNT_6              = RlEXT.KDM18_CNT_6,               -- 18歳以上人数6月
                                       KDM18_CNT_7              = RlEXT.KDM18_CNT_7,               -- 18歳以上人数7月
                                       KDM18_CNT_8              = RlEXT.KDM18_CNT_8,               -- 18歳以上人数8月
                                       KDM18_CNT_9              = RlEXT.KDM18_CNT_9,               -- 18歳以上人数9月
                                       KDM18_CNT_10             = RlEXT.KDM18_CNT_10,              -- 18歳以上人数10月
                                       KDM18_CNT_11             = RlEXT.KDM18_CNT_11,              -- 18歳以上人数11月
                                       KDM18_CNT_12             = RlEXT.KDM18_CNT_12,              -- 18歳以上人数12月
                                       KDM18_CNT_1              = RlEXT.KDM18_CNT_1,               -- 18歳以上人数1月
                                       KDM18_CNT_2              = RlEXT.KDM18_CNT_2,               -- 18歳以上人数2月
                                       KDM18_CNT_3              = RlEXT.KDM18_CNT_3,               -- 18歳以上人数3月
                                       KDM18_KEIGEN_KINTOWARI   = RlEXT.KDM18_KEIGEN_KINTOWARI,    -- 18歳以上均等割軽減額
                                       NEW_KDM18UN_CNT          = RlEXT.NEW_KDM18UN_CNT,           -- 18歳未満人数最新
                                       KDM18UN_CNT_4            = RlEXT.KDM18UN_CNT_4,             -- 18歳未満人数4月
                                       KDM18UN_CNT_5            = RlEXT.KDM18UN_CNT_5,             -- 18歳未満人数5月
                                       KDM18UN_CNT_6            = RlEXT.KDM18UN_CNT_6,             -- 18歳未満人数6月
                                       KDM18UN_CNT_7            = RlEXT.KDM18UN_CNT_7,             -- 18歳未満人数7月
                                       KDM18UN_CNT_8            = RlEXT.KDM18UN_CNT_8,             -- 18歳未満人数8月
                                       KDM18UN_CNT_9            = RlEXT.KDM18UN_CNT_9,             -- 18歳未満人数9月
                                       KDM18UN_CNT_10           = RlEXT.KDM18UN_CNT_10,            -- 18歳未満人数10月
                                       KDM18UN_CNT_11           = RlEXT.KDM18UN_CNT_11,            -- 18歳未満人数11月
                                       KDM18UN_CNT_12           = RlEXT.KDM18UN_CNT_12,            -- 18歳未満人数12月
                                       KDM18UN_CNT_1            = RlEXT.KDM18UN_CNT_1,             -- 18歳未満人数1月
                                       KDM18UN_CNT_2            = RlEXT.KDM18UN_CNT_2,             -- 18歳未満人数2月
                                       KDM18UN_CNT_3            = RlEXT.KDM18UN_CNT_3,             -- 18歳未満人数3月
                                       KDM18UN_KEIGEN_KINTOWARI = RlEXT.KDM18UN_KEIGEN_KINTOWARI   -- 18歳未満均等割軽減額
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
                                    ':4, '                                                                     || -- SYS_TANMATSU_NO
                                    '0,0,0,0,0,0,0,0,0,0,0,'                                                   || -- KDM_SHOTOKU_KISO～KDM_BYODOWARI_RITSU １１個
                                    '0,0,0,0,0,0,0,0,0,0,0,'                                                   || -- KDM_NENZEI_RITSU～KDM_GENMEN_6        １１個
                                    '0,0,0,0,0,0,0,0,0,0,0)';                                                     -- KDM_GENMEN_7～KDM_GENGAKU             １１個
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
-- 09 税額確定処理（基本）
-------------------------------------------------------------------------------
    PROCEDURE subKakutei IS
        NwWORK          NUMBER;
    BEGIN
        --再処理用に月割年税額を保存
        IF NCNT_KAKUTEI = 0 THEN
            NlNENZEIGAKU_WK := NlNENZEIGAKU;
        END IF;
        -- 月割りで算出した年税額は、身障減免額がマイナスされていないのでここで減算
        NlNENZEIGAKU := NlNENZEIGAKU -  RlEXT.KDM_SHOGAI_GENMEN;

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

        subGenmenritsu;        -- 30 減免率(額)を算出（医療）

        --  世帯減免のみの場合
        IF  NGENMEN_EXIST_KBN = 0 AND NGENMEN_USE_SKBN = 1 THEN
            RlKIHON.GENMEN      := TRUNC(((NlNENZEIGAKU - RlKIHON.HASU) * NGENMEN_USE_SRITSU / 100), -2) ;  -- 世帯減免額の算出(基本)（年税額のXX%減免)
        ELSE
          IF NLOOP_CNT_NOW = 2 THEN
            --優先区分が「世帯／率／年額」
            IF RlGENMEN_KOJIN.YUSEN_KBN = 3 THEN
              RlKIHON.GENMEN      := CEIL(((NlNENZEIGAKU - RlKIHON.HASU) * RlGENMEN_KOJIN.KDM_NENZEI_RITSU / 100)); -- 年税減免率（年税額のXX%減免)
              RlKIHON.NENZEI      := RlKIHON.NENZEI - RlKIHON.GENMEN;
            --優先区分が「世帯／額／年額」
            ELSIF RlGENMEN_KOJIN.YUSEN_KBN = 4 THEN
              RlKIHON.GENMEN      := RlGENMEN_KOJIN.KDM_NENZEI_GENGAKU;  -- 年税減免額
              RlKIHON.NENZEI      := RlKIHON.NENZEI - RlKIHON.GENMEN;
            END IF;
          END IF;
        END IF;

        -- 月割りで算出した年税額は、減免額分がマイナスされていないのでここで減算
        IF NLOOP_CNT_NOW = 2 THEN
          --優先区分が「世帯／率／年額」、「世帯／額／年額」以外
          IF RlGENMEN_KOJIN.YUSEN_KBN NOT IN (3, 4) THEN
            RlKIHON.GENMEN := TRUNC(NwNENZEIGAKU + NwHASU + NwGENDO_CHOKA) - (RlKIHON.NENZEI + RlKIHON.HASU + RlKIHON.GENDO_CHOKA);
          END IF;
        ELSE
          IF RlKIHON.NENZEI - RlKIHON.GENMEN >= 0 THEN
              RlKIHON.NENZEI := RlKIHON.NENZEI - RlKIHON.GENMEN;
          ELSE
              RlKIHON.GENMEN := RlKIHON.NENZEI;
              RlKIHON.NENZEI := 0;
          END IF;
        END IF;

        -- 月割り減額
        RlKIHON.TSUKIWARI_GEN := RlKIHON.SEKISAN - RlKIHON.GENDO_CHOKA         -- 積算税額, 限度超過
                                                 - RlKIHON.KEIGEN_K_WARI       -- 軽減均等割
                                                 - RlKIHON.KEIGEN_B_WARI       -- 軽減平等割
                                                 - RlKIHON.HASU                -- 端数
                                                 - RlKIHON.GENMEN              -- 減免額
                                                 - RlEXT.KDM_NENREI_KEIGEN     -- 年齢軽減
                                                 - RlEXT.KDM_SHOGAI_GENMEN     -- 身障減免
                                                 - RlKIHON.NENZEI;             -- 年税額
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
                  IF RlKIHON.NENZEI >= NlJGENDOGAKU AND RlKIHON.GENDO_CHOKA > 1 THEN --年税額が限度超過している場合
                    RlKIHON.GENDO_CHOKA := RlKIHON.GENDO_CHOKA + RlKIHON.TSUKIWARI_GEN;
                    RlKIHON.TSUKIWARI_GEN := 0;
                  ELSE
                    NlNENZEIGAKU := NlNENZEIGAKU_WK + RlKIHON.TSUKIWARI_GEN;  --マイナス分を年税額から引く
                    NCNT_KAKUTEI := NCNT_KAKUTEI + 1;
                    subKakutei;               --再税額確定
                  END IF;
                END IF;
            END IF;
        END IF;
        -- 減額合計
        RlKIHON.GENGAKU_KEI   := RlKIHON.GENDO_CHOKA + RlKIHON.KEIGEN_K_WARI   -- 軽減均等割
                                                     + RlKIHON.KEIGEN_B_WARI   -- 軽減平等割
                                                     + RlKIHON.HASU            -- 端数
                                                     + RlEXT.KDM_NENREI_KEIGEN -- 年齢軽減
                                                     + RlKIHON.TSUKIWARI_GEN;  -- 月割り減額

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
        NwKEIGEN_KBN        NUMBER(1);  -- 最小対象月の軽減区分
        NwJBGEN_TMP         NUMBER;     -- 軽減平等割額WORK
        NwJBGEN_T_TMP       NUMBER;     -- 軽減平等割額WORK(特定同一)
        NwJBGEN             NUMBER;     -- 軽減平等割額計算結果
        NwJBGEN2_T_TMP      NUMBER;     --　軽減平等割額WORK(特定同一(2))

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

        IF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN1 THEN            -- 6割

            RlKIHON.KEIGEN_K_WARI := RlKIHON.KINTO_CNT * NlJKGEN1;                                  --均等割に対する257軽減
            RlKIHON.KEIGEN_K_WARI := RlKIHON.KEIGEN_K_WARI + (NlJKINTO - NlJKGEN1) * MlCNT18UN(13); --均等割に対する18歳未満軽減(未就学児軽減含む)を加算
            RlKIHON.KEIGEN_K_WARI := RlKIHON.KEIGEN_K_WARI + RlKIHON.KINTO_CNT_KDM18 * NlJKGEN118;  --18歳以上均等割に対する257軽減を加算
            NwJBGEN_TMP   := NlJBGEN1;               -- 軽減平等割額(基本)
            NwJBGEN_T_TMP := NlJBGEN_T1;             -- 軽減平等割額(特定同一)
            NwJBGEN2_T_TMP := NlJBGEN2_T1;           -- 軽減平等割額(特定同一(2))

        ELSIF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN2 THEN         -- 4割

            RlKIHON.KEIGEN_K_WARI := RlKIHON.KINTO_CNT * NlJKGEN2;                                  --均等割に対する257軽減と未就学児軽減
            RlKIHON.KEIGEN_K_WARI := RlKIHON.KEIGEN_K_WARI + (NlJKINTO - NlJKGEN2) * MlCNT18UN(13); --均等割に対する18歳未満軽減(未就学児軽減含む)を加算
            RlKIHON.KEIGEN_K_WARI := RlKIHON.KEIGEN_K_WARI + RlKIHON.KINTO_CNT_KDM18 * NlJKGEN218;  --18歳以上均等割に対する257軽減を加算
            NwJBGEN_TMP   := NlJBGEN2;               -- 軽減平等割額(基本)
            NwJBGEN_T_TMP := NlJBGEN_T2;             -- 軽減平等割額(特定同一)
            NwJBGEN2_T_TMP := NlJBGEN2_T2;           -- 軽減平等割額(特定同一(2))

        ELSIF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN3 THEN         -- 2割

            RlKIHON.KEIGEN_K_WARI := RlKIHON.KINTO_CNT * NlJKGEN3;                                  --均等割に対する257軽減と未就学児軽減
            RlKIHON.KEIGEN_K_WARI := RlKIHON.KEIGEN_K_WARI + (NlJKINTO - NlJKGEN3) * MlCNT18UN(13); --均等割に対する18歳未満軽減(未就学児軽減含む)を加算
            RlKIHON.KEIGEN_K_WARI := RlKIHON.KEIGEN_K_WARI + RlKIHON.KINTO_CNT_KDM18 * NlJKGEN318;  --18歳以上均等割に対する257軽減を加算
            NwJBGEN_TMP   := NlJBGEN3;               -- 軽減平等割額(基本)
            NwJBGEN_T_TMP := NlJBGEN_T3;             -- 軽減平等割額(特定同一)
            NwJBGEN2_T_TMP := NlJBGEN2_T3;           -- 軽減平等割額(特定同一(2))
        ELSE
            RlKIHON.KEIGEN_K_WARI := RlKIHON.KEIGEN_K_WARI + NlJKINTO * MlCNT18UN(13);              --均等割に対する18歳未満軽減(未就学児軽減含む)を加算
        END IF;

        IF NwKEIGEN_KBN IN (NlJKEIGEN1, NlJKEIGEN2, NlJKEIGEN3) THEN
          -- 特定同一の軽減額対応
          SELECT SUM(( CASE TAISHO_KBN_4  WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_5  WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_6  WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_7  WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_8  WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_9  WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_10 WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_11 WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_12 WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_1  WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_2  WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END +
                       CASE TAISHO_KBN_3  WHEN 1 THEN NwJBGEN_T_TMP WHEN 8 THEN NwJBGEN2_T_TMP ELSE NwJBGEN_TMP END) / 12)
            INTO NwJBGEN
            FROM ZLBTKANWA_SETAI_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI
             AND SYS_TANMATSU_NO = i_VTANMATSU;

           -- 軽減平等割額セット
           RlKIHON.KEIGEN_B_WARI := TRUNC(NwJBGEN);
         END IF;
-----------------------
-- 年齢軽減
-----------------------
--2025/10/15 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
        IF NlNENREI_KEIGEN = 1 THEN
          -- 支援年齢軽減(基本)を算出する
          IF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN1 THEN             -- 6割
              RlEXT.KDM_NENREI_KEIGEN := (Nl22Ika_CNT - MlCNT18UN(13)) * ((NlJKINTO + NlJKINTO18 - NlJKGEN1 - NlJKGEN118 )/2); -- 子ども年齢軽減
          ELSIF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN2 THEN          -- 4割
              RlEXT.KDM_NENREI_KEIGEN := (Nl22Ika_CNT - MlCNT18UN(13)) * ((NlJKINTO + NlJKINTO18 - NlJKGEN2 - NlJKGEN218 )/2); -- 子ども年齢軽減
          ELSIF RlKIHON_IRY.FUKA_KEIGEN_KBN = NlJKEIGEN3 THEN          -- 2割
              RlEXT.KDM_NENREI_KEIGEN := (Nl22Ika_CNT - MlCNT18UN(13)) * ((NlJKINTO + NlJKINTO18 - NlJKGEN3 - NlJKGEN318 )/2); -- 子ども年齢軽減
          ELSE
              RlEXT.KDM_NENREI_KEIGEN := (Nl22Ika_CNT - MlCNT18UN(13)) * ((NlJKINTO + NlJKINTO18 )/2);                         -- 子ども年齢軽減
          END IF;

          NwWORK := RlKIHON.SEKISAN - RlKIHON.KEIGEN_K_WARI - RlKIHON.KEIGEN_B_WARI;
          -- 年齢軽減額も積算税額より減算
          NwWORK := NwWORK - RlEXT.KDM_NENREI_KEIGEN;

          IF NwWORK > NlJGENDOGAKU THEN
              RlKIHON.GENDO_CHOKA := NwWORK - NlJGENDOGAKU;  -- 限度超過額(基本)
          END IF;

          NwWORK := RlKIHON.SEKISAN - RlKIHON.KEIGEN_K_WARI
                                    - RlKIHON.KEIGEN_B_WARI
                                    - RlKIHON.GENDO_CHOKA;
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
          END IF;
--2025/10/15 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
        ELSE
          RlEXT.KDM_NENREI_KEIGEN := 0;
        END IF;
--2025/10/15 ZCZL.LIUHUAJUN ADD END
        -- 減額合計(基本)
        RlKIHON.GENGAKU_KEI := RlKIHON.GENDO_CHOKA
                             + RlKIHON.KEIGEN_K_WARI
                             + RlKIHON.KEIGEN_B_WARI
                             + RlEXT.KDM_NENREI_KEIGEN
                             + RlKIHON.HASU;
        -- 年税額(基本)
        RlKIHON.NENZEI      := RlKIHON.SEKISAN - RlKIHON.GENGAKU_KEI;

    END subSetaiGaku;
-------------------------------------------------------------------------------
-- 05 欠番
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 子ども人数設定
-------------------------------------------------------------------------------
  PROCEDURE subKodomoSet IS
  -- 変数の定義
    IRTN                   PLS_INTEGER;     -- リターン値
    VMI_SHUGAKU_JI_NINSU   NVARCHAR2(200);  -- 未就学児人数

  BEGIN
    -- 1.各月末人数取得
    -- 1-1.未就学児判定パッケージ.世帯未就学児の判定処理（FUNCSETAIKODOMO_HANTEI）を呼び出し、各月の未就学児人数を取得する。
    IRTN := ZLBPK00090.FCSETAIKODOMO_HANTEI(i_NSETAI,
                                                 i_NNENDO_BUN,
                                                 TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),
                                                 0,
                                                 i_VTANMATSU,
                                                 VMI_SHUGAKU_JI_NINSU
                                                );

    -- 1-2.リターン値が1の場合、人数ワーク(1)~(15)に「0」を設定する。
    IF IRTN = 1 THEN
      FOR IX IN 1..15 LOOP
        MJI_NINSU(IX) := 0;
      END LOOP;
    ELSE
      -- 1-3.取得した未就学児人数を子ども人数ワークに設定する。
      MJI_NINSU(1) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,1,2));
      MJI_NINSU(2) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,3,2));
      MJI_NINSU(3) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,5,2));
      MJI_NINSU(4) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,7,2));
      MJI_NINSU(5) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,9,2));
      MJI_NINSU(6) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,11,2));
      MJI_NINSU(7) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,13,2));
      MJI_NINSU(8) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,15,2));
      MJI_NINSU(9) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,17,2));
      MJI_NINSU(10) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,19,2));
      MJI_NINSU(11) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,21,2));
      MJI_NINSU(12) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,23,2));
      MJI_NINSU(13) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,25,2));
      MJI_NINSU(14) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,27,2));
      MJI_NINSU(15) := TO_NUMBER(SUBSTR(VMI_SHUGAKU_JI_NINSU,29,2));
    END IF;
    -- 2.賦課拡張（最新）から賦課発生時の子ども人数を取得

      -- 2-1.取得できた場合、子ども人数賦課発生時を子ども人数ワーク(15)に設定する。

    -- 3.計算賦課拡張ワークに値をセットする。
    RlEXT.NEW_KODOMO_CNT           := MJI_NINSU(13);
    RlEXT.F4_KODOMO_CNT            := MJI_NINSU(14);
    RlEXT.FUKA_KODOMO_CNT          := MJI_NINSU(15);
    RlEXT.KODOMO_CNT_4             := MJI_NINSU(1);
    RlEXT.KODOMO_CNT_5             := MJI_NINSU(2);
    RlEXT.KODOMO_CNT_6             := MJI_NINSU(3);
    RlEXT.KODOMO_CNT_7             := MJI_NINSU(4);
    RlEXT.KODOMO_CNT_8             := MJI_NINSU(5);
    RlEXT.KODOMO_CNT_9             := MJI_NINSU(6);
    RlEXT.KODOMO_CNT_10            := MJI_NINSU(7);
    RlEXT.KODOMO_CNT_11            := MJI_NINSU(8);
    RlEXT.KODOMO_CNT_12            := MJI_NINSU(9);
    RlEXT.KODOMO_CNT_1             := MJI_NINSU(10);
    RlEXT.KODOMO_CNT_2             := MJI_NINSU(11);
    RlEXT.KODOMO_CNT_3             := MJI_NINSU(12);

  -- 4.異常処理
  EXCEPTION
    WHEN OTHERS THEN
      -- 4-1.戻り値 = 1 をセットする。
      NlRTN := c_NERR;
      -- 4-2.ログ出力
      VlMSG := 'subKodomoSet 子ども人数取得(国保世帯番号=' || i_NSETAI || ')' || SQLERRM;
  END subKodomoSet;

-------------------------------------------------------------------------------
-- 18歳以上 18歳以下人数設定
-------------------------------------------------------------------------------
  PROCEDURE subKDMSet IS
  -- 変数の定義
    IRTN                   PLS_INTEGER;     -- リターン値
    VMI_18_NINSU           NVARCHAR2(200);  -- 18歳以上人数
    VMI_18UN_NINSU         NVARCHAR2(200);  -- 歳未満人数

  BEGIN
    -- 1.各月末人数取得
    -- 1-1.未就学児判定パッケージ.世帯未就学児の判定処理（FCSETAIKDM_HANTEI）を呼び出し、各月の未就学児人数を取得する。
    IRTN := ZLBPK00140.FCSETAIKDM_HANTEI(i_NSETAI,
                                         i_NNENDO_BUN,
                                         TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),
                                         0,
                                         i_VTANMATSU,
                                         VMI_18_NINSU,
                                         VMI_18UN_NINSU,
                                         NULL,
                                         i_NNENDO,
                                         i_NNUSHI
                                         );

    -- 1-2.リターン値が1の場合、人数ワーク(1)~(15)に「0」を設定する。
    IF IRTN = 1 THEN
      FOR IX IN 1..15 LOOP
        MlCNT18(IX) := 0;
        MlCNT18UN(IX) := 0;
      END LOOP;
    ELSE
      -- 1-3.取得した未就学児人数を子ども人数ワークに設定する。
      MlCNT18(1)    := TO_NUMBER(SUBSTR(VMI_18_NINSU,1,2));
      MlCNT18(2)    := TO_NUMBER(SUBSTR(VMI_18_NINSU,3,2));
      MlCNT18(3)    := TO_NUMBER(SUBSTR(VMI_18_NINSU,5,2));
      MlCNT18(4)    := TO_NUMBER(SUBSTR(VMI_18_NINSU,7,2));
      MlCNT18(5)    := TO_NUMBER(SUBSTR(VMI_18_NINSU,9,2));
      MlCNT18(6)    := TO_NUMBER(SUBSTR(VMI_18_NINSU,11,2));
      MlCNT18(7)    := TO_NUMBER(SUBSTR(VMI_18_NINSU,13,2));
      MlCNT18(8)    := TO_NUMBER(SUBSTR(VMI_18_NINSU,15,2));
      MlCNT18(9)    := TO_NUMBER(SUBSTR(VMI_18_NINSU,17,2));
      MlCNT18(10)   := TO_NUMBER(SUBSTR(VMI_18_NINSU,19,2));
      MlCNT18(11)   := TO_NUMBER(SUBSTR(VMI_18_NINSU,21,2));
      MlCNT18(12)   := TO_NUMBER(SUBSTR(VMI_18_NINSU,23,2));
      MlCNT18(13)   := TO_NUMBER(SUBSTR(VMI_18_NINSU,25,2));
      MlCNT18(14)   := TO_NUMBER(SUBSTR(VMI_18_NINSU,27,2));
      MlCNT18(15)   := TO_NUMBER(SUBSTR(VMI_18_NINSU,29,2));
      MlCNT18UN(1)  := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,1,2));
      MlCNT18UN(2)  := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,3,2));
      MlCNT18UN(3)  := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,5,2));
      MlCNT18UN(4)  := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,7,2));
      MlCNT18UN(5)  := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,9,2));
      MlCNT18UN(6)  := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,11,2));
      MlCNT18UN(7)  := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,13,2));
      MlCNT18UN(8)  := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,15,2));
      MlCNT18UN(9)  := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,17,2));
      MlCNT18UN(10) := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,19,2));
      MlCNT18UN(11) := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,21,2));
      MlCNT18UN(12) := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,23,2));
      MlCNT18UN(13) := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,25,2));
      MlCNT18UN(14) := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,27,2));
      MlCNT18UN(15) := TO_NUMBER(SUBSTR(VMI_18UN_NINSU,29,2));
    END IF;
    -- 2.賦課拡張（最新）から賦課発生時の子ども人数を取得

      -- 2-1.取得できた場合、子ども人数賦課発生時を子ども人数ワーク(15)に設定する。

    -- 3.計算賦課拡張ワークに値をセットする。
    RlEXT.NEW_KDM18_CNT      := MlCNT18(13);
    RlEXT.KDM18_F4_CNT       := MlCNT18(14);
    RlEXT.KDM18_FUKA_CNT     := MlCNT18(15);
    RlEXT.KDM18_CNT_4        := MlCNT18(1);
    RlEXT.KDM18_CNT_5        := MlCNT18(2);
    RlEXT.KDM18_CNT_6        := MlCNT18(3);
    RlEXT.KDM18_CNT_7        := MlCNT18(4);
    RlEXT.KDM18_CNT_8        := MlCNT18(5);
    RlEXT.KDM18_CNT_9        := MlCNT18(6);
    RlEXT.KDM18_CNT_10       := MlCNT18(7);
    RlEXT.KDM18_CNT_11       := MlCNT18(8);
    RlEXT.KDM18_CNT_12       := MlCNT18(9);
    RlEXT.KDM18_CNT_1        := MlCNT18(10);
    RlEXT.KDM18_CNT_2        := MlCNT18(11);
    RlEXT.KDM18_CNT_3        := MlCNT18(12);
    RlEXT.NEW_KDM18UN_CNT    := MlCNT18UN(13);
    RlEXT.KDM18UN_CNT_4      := MlCNT18UN(1);
    RlEXT.KDM18UN_CNT_5      := MlCNT18UN(2);
    RlEXT.KDM18UN_CNT_6      := MlCNT18UN(3);
    RlEXT.KDM18UN_CNT_7      := MlCNT18UN(4);
    RlEXT.KDM18UN_CNT_8      := MlCNT18UN(5);
    RlEXT.KDM18UN_CNT_9      := MlCNT18UN(6);
    RlEXT.KDM18UN_CNT_10     := MlCNT18UN(7);
    RlEXT.KDM18UN_CNT_11     := MlCNT18UN(8);
    RlEXT.KDM18UN_CNT_12     := MlCNT18UN(9);
    RlEXT.KDM18UN_CNT_1      := MlCNT18UN(10);
    RlEXT.KDM18UN_CNT_2      := MlCNT18UN(11);
    RlEXT.KDM18UN_CNT_3      := MlCNT18UN(12);

  -- 4.異常処理
  EXCEPTION
    WHEN OTHERS THEN
      -- 4-1.戻り値 = 1 をセットする。
      NlRTN := c_NERR;
      -- 4-2.ログ出力
      VlMSG := 'subKDMSet .18歳以上/18歳以下人数取得(国保世帯番号=' || i_NSETAI || ')' || SQLERRM;
  END subKDMSet;

-------------------------------------------------------------------------------
-- 04 積算税額算出
-------------------------------------------------------------------------------
    PROCEDURE subSekisan IS
      NKAHYO_DOWN NUMBER;
      NKAHYO_OVER NUMBER;
      MlTSUKIKAHYO     MTNUMARRAY12;     --各月の課税標準額(４月から翌３月まで)
      NwIX1            NUMBER(2);        --ループ用カウンタ
      NwIX2            NUMBER(2);        --ループ用カウンタ
      MlKAHYO_KIND     MTNUMARRAY12;     --同額の課税標準額
      MlTSUKIZEIGAKU   MTNUMARRAY12;     --月毎の税額
      NSHOTOKUWARI_MAE NUMBER;           --経過措置前の所得割額
      NSHISANWARI_MAE  NUMBER;           --経過措置前の資産割額
      MlOUEKI_KIND     MTNUMARRAY12;     --応益係数
      NlNENGAKU        NUMBER;           --所得割二段階経過措置後の金額
      NBYODO_SOTI      NUMBER;           --経過措置後の平等割額
      NKINTO_SOTI      NUMBER;           --経過措置後の均等割額
      NPER             MTNUMARRAY12;     --応益係数
      NwCNT            MTNUMARRAY12;     --応益係数それぞれの月数
--2025/10/15 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
      NwCNT18          MTNUMARRAY12;     --18歳以上世帯員を対象とした応益係数それぞれの月数
      NNIN             NUMBER(2);        --18歳以上世帯員か否かの判定結果
      NKINTO_SOTI18    NUMBER;           --経過措置後の18歳以上均等割額
      NRTN             NUMBER;
--2025/10/15 ZCZL.LIUHUAJUN ADD END
      MlSUMI_K         MTNUMARRAY1;     -- 済(経過措置用)
      MlTUKI_K         MTNUMARRAY2;     -- 月数(経過措置用)

      CURSOR C_ZEN IS
        SELECT   B.*
        FROM     ZLBTKOJIN_CAL A,ZLBTKANWA_KOJIN_CAL B
        WHERE   A.KOKU_SETAI_NO   = i_NSETAI
        AND     A.SANTEIDANTAI_CD = i_NDANTAI
        AND     A.CHOTEI_NENDO    = i_NNENDO
        AND     A.NENDO_BUN       = i_NNENDO_BUN
        AND     A.TSUCHI_NO       = i_NNUSHI
        AND     A.SYS_TANMATSU_NO = i_VTANMATSU
        AND     (
                  ( i_CAL_KBN = c_CAL_KBN_TU AND
                    ( A.NEW_SHIK_KBN IN (1, 3, 7, 9) OR
                      (A.NEW_SHIK_KBN IN (2, 8) AND A.SEKISAN_GAI_KBN = 1)
                    )
                  ) OR
                  (  i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND A.NEW_SHIK_KBN IN (1, 3))
                )
        AND     B.KOKU_SETAI_NO   = A.KOKU_SETAI_NO
        AND     B.SANTEIDANTAI_CD = A.SANTEIDANTAI_CD
        AND     B.CHOTEI_NENDO    = A.CHOTEI_NENDO
        AND     B.NENDO_BUN       = A.NENDO_BUN
        AND     B.TSUCHI_NO       = A.TSUCHI_NO
        AND     B.SYS_TANMATSU_NO = A.SYS_TANMATSU_NO
        AND     B.KOJIN_NO        = A.KOJIN_NO;

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
          RlKIHON.SHOTOKU_WARI := NKAHYO_OVER * NSSHOTOKU_KDM_OVER / 100;
          RlKIHON.SHOTOKU_WARI := RlKIHON.SHOTOKU_WARI + NKAHYO_DOWN * NSHOTOKU_KDM / 100;

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
              AND (( i_CAL_KBN = c_CAL_KBN_TU AND
                   ( A.NEW_SHIK_KBN IN (1, 3, 7, 9) OR
                   (A.NEW_SHIK_KBN IN (2, 8) AND A.SEKISAN_GAI_KBN = 1))) OR
                   (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND A.NEW_SHIK_KBN IN (1, 3)))
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
            MlTSUKIZEIGAKU(NwIX) := NKAHYO_OVER * NSSHOTOKU_KDM_OVER / 100;
            MlTSUKIZEIGAKU(NwIX) := MlTSUKIZEIGAKU(NwIX) + NKAHYO_DOWN * NSHOTOKU_KDM / 100;
          END LOOP;

          --4 3で算出した金額と2で算出した月数と月数から年額を算出 （年額 ＝ 月毎の税額×月数÷月数12）
          NlNENGAKU := 0;
          FOR NwIX IN 1..12 LOOP
            NlNENGAKU := NlNENGAKU + MlTSUKIZEIGAKU(NwIX) * MlTUKI_K(NwIX);
          END LOOP;
          NlNENGAKU := TRUNC(NlNENGAKU/12);

          --5 経過措置前の所得割と経過措置後の差額を算出し、計算拡張出力エリアにセット
          RlEXT.KDM_KEIKA_H_SHOTOKU := RlKIHON.SHOTOKU_WARI - NlNENGAKU;
          --6 4で算出した結果を計算基本出力エリアにセット
          RlKIHON.SHOTOKU_WARI := NlNENGAKU;

        ELSE        --所得割２段階実施でない場合
          --1以下のSQLで経過措置前の所得割額を算出
          SELECT NVL(SUM(TRUNC(KAHYO*(NSHOTOKU_KDM/100))), 0)
            INTO NSHOTOKUWARI_MAE
            FROM ZLBTKOJIN_CAL
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND CHOTEI_NENDO    = i_NNENDO
              AND NENDO_BUN       = i_NNENDO_BUN
              AND TSUCHI_NO       = i_NNUSHI
              AND SYS_TANMATSU_NO = i_VTANMATSU
              -- 積算対象条件
              AND (( i_CAL_KBN = c_CAL_KBN_TU AND
                   ( NEW_SHIK_KBN IN (1, 3, 7, 9) OR
                    (NEW_SHIK_KBN IN (2, 8) AND SEKISAN_GAI_KBN = 1))) OR
                    (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND NEW_SHIK_KBN IN (1, 3)));
          --2経過措置前の所得割と経過措置後の差額を算出し、計算拡張出力エリアにセット
          RlEXT.KDM_KEIKA_H_SHOTOKU := NSHOTOKUWARI_MAE - RlKIHON.SHOTOKU_WARI;

        END IF;

        --1以下のSQLで経過措置前の資産割額を算出
        SELECT NVL(SUM(TRUNC(SHISANZEI*(NSHISAN_KDM/100))), 0)
          INTO NSHISANWARI_MAE
          FROM ZLBTKOJIN_CAL
          WHERE KOKU_SETAI_NO  = i_NSETAI
            AND SANTEIDANTAI_CD = i_NDANTAI
            AND CHOTEI_NENDO    = i_NNENDO
            AND NENDO_BUN       = i_NNENDO_BUN
            AND TSUCHI_NO       = i_NNUSHI
            AND SYS_TANMATSU_NO = i_VTANMATSU
            -- 積算対象条件
            AND (( i_CAL_KBN = c_CAL_KBN_TU AND
                 ( NEW_SHIK_KBN IN (1, 3, 7, 9) OR
                  (NEW_SHIK_KBN IN (2, 8) AND SEKISAN_GAI_KBN = 1))) OR
                  (i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND NEW_SHIK_KBN IN (1, 3)));
        --2経過措置前の所得割と経過措置後の差額を算出し、計算拡張出力エリアにセット
        RlEXT.KDM_KEIKA_H_SHISAN := NSHISANWARI_MAE - RlKIHON.SHISAN_WARI;

        RlKIHON.KINTO_WARI  := RlKIHON.KINTO_CNT * NlJKINTO;  -- 均等割額(基本)
        RlKIHON.KINTO_WARI  := RlKIHON.KINTO_WARI + (RlKIHON.KINTO_CNT_KDM18 * NlJKINTO18);  -- 18歳以上均等割額を加算
        RlKIHON.KINTO_KDM18 := RlKIHON.KINTO_CNT_KDM18 * NlJKINTO18;

        IF RlKIHON.KINTO_CNT > 0 THEN
            RlKIHON.BYODO_WARI  := NlJBYODO;      -- 平等割額(基本)
        END IF;

        --応益経過措置金額算出
        --平等割
        --1以下の計算TBL情報を取得して応益係数=100%・90%・70%・50%のそれぞれの月数を算出
        --応益係数取得
        BEGIN
          SELECT OUEKI_4 ,OUEKI_5 ,OUEKI_6 ,OUEKI_7 ,OUEKI_8 ,OUEKI_9 ,
                 OUEKI_10,OUEKI_11,OUEKI_12,OUEKI_1 ,OUEKI_2 ,OUEKI_3
            INTO MlOUEKI(1) ,MlOUEKI(2) ,MlOUEKI(3) ,MlOUEKI(4) ,MlOUEKI(5) ,MlOUEKI(6),
                 MlOUEKI(7) ,MlOUEKI(8) ,MlOUEKI(9) ,MlOUEKI(10),MlOUEKI(11),MlOUEKI(12)
            FROM ZLBTKANWA_SETAI_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NNUSHI
             AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION    -- エラー時も100%セット
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
          NBYODO_SOTI := NBYODO_SOTI + TRUNC(NlJBYODO * MlOUEKI_KIND(NwIX) / 100 * MlTUKI_K(NwIX) / 12);
        END LOOP;
        -- 均等人員 = 0 の場合は、経過措置後の平等割額=\0とする
        IF RlKIHON.KINTO_CNT = 0 THEN
            NBYODO_SOTI  := 0;
        END IF;


        --4経過措置前の金額との差額を算出し、計算拡張出力エリアにセット。
        RlEXT.KDM_KEIKA_BYODOWARI := RlKIHON.BYODO_WARI - NBYODO_SOTI;

        --4 2で算出した結果を計算基本出力エリアにセット
        --平等割
        RlKIHON.BYODO_WARI:=NBYODO_SOTI;

        --均等割
        --5以下の計算TBL情報を取得して該当世帯のトータル月数と応益係数=100%・90%・70%・50%のそれぞれの月数を算出
        NPER(1)       := 50;
        NPER(2)       := 70;
        NPER(3)       := 90;
        NPER(4)       := 100;

        FOR IDX IN 1..4 LOOP
          NwCNT(IDX) := 0;
--2025/10/15 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
          NwCNT18(IDX) := 0;
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
--2025/10/15 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
          NRTN := ZLBPK00140.FCKDM_HANTEI(i_NSETAI,i_NNENDO_BUN,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),R_KJN.KOJIN_NO,NNIN,i_VTANMATSU);
          IF NNIN = 0 THEN 
            FOR IDX2 IN 1..4 LOOP
              IF R_KJN.OUEKI_4   = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_5   = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_6   = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_7   = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_8   = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_9   = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_10  = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_11  = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_12  = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_1   = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_2   = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
              IF R_KJN.OUEKI_3   = NPER(IDX2) THEN NwCNT18(IDX2) :=  NwCNT18(IDX2) + 1; END IF;
            END LOOP;
          END IF;
--2025/10/15 ZCZL.LIUHUAJUN ADD END
        END LOOP;

        --7 以下の計算式で経過措置後の均等割の金額を応益係数の種類毎に算出
        --均等割 Ｂ＝TRUNC((RIKIHON.KINTO_CNT×システム条件の均等割額)×応益係数÷100×該当月数÷トータル月数))
        NKINTO_SOTI := 0;
--2025/10/15 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
        NKINTO_SOTI18 := 0;
        IF (NwCNT(1)+NwCNT(2)+NwCNT(3)+NwCNT(4)) <> 0 THEN
          FOR NwIX IN 1..4 LOOP
             NKINTO_SOTI := NKINTO_SOTI + TRUNC((RlKIHON.KINTO_CNT * NlJKINTO) * NPER(NwIX) / 100 * NwCNT(NwIX) / (NwCNT(1)+NwCNT(2)+NwCNT(3)+NwCNT(4)));
--2025/10/15 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--             NKINTO_SOTI := NKINTO_SOTI + TRUNC((RlKIHON.KINTO_CNT_KDM18 * NlJKINTO18) * NPER(NwIX) / 100
--                                                * NwCNT(NwIX) / (NwCNT(1)+NwCNT(2)+NwCNT(3)+NwCNT(4))); -- 18歳以上均等割額を加算
             IF RlKIHON.KINTO_CNT_KDM18 > 0 THEN
               NKINTO_SOTI := NKINTO_SOTI + TRUNC((RlKIHON.KINTO_CNT_KDM18 * NlJKINTO18) * NPER(NwIX) / 100
                                                  * NwCNT18(NwIX) / (NwCNT18(1)+NwCNT18(2)+NwCNT18(3)+NwCNT18(4)));  -- 18歳以上均等割額を加算
               NKINTO_SOTI18 := NKINTO_SOTI18 + TRUNC((RlKIHON.KINTO_CNT_KDM18 * NlJKINTO18) * NPER(NwIX) / 100
                                                  * NwCNT18(NwIX) / (NwCNT18(1)+NwCNT18(2)+NwCNT18(3)+NwCNT18(4)));  -- 経過措置後の18歳以上均等割額のみの額
             END IF;
--2025/10/15 ZCZL.LIUHUAJUN UPDATE END
          END LOOP;
          --8経過措置前の金額との差額を算出し、計算拡張出力エリアにセット。
          --均等割(被扶養者)
          RlEXT.KDM_KEIKA_H_KINTOWARI := RlKIHON.KINTO_WARI - NKINTO_SOTI;
          --9 7で算出した結果を計算基本出力エリアにセット
          --均等割
          RlKIHON.KINTO_WARI:=NKINTO_SOTI;
--2025/10/15 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
          RlKIHON.KINTO_KDM18:=NKINTO_SOTI18;
        END IF;

        --平等割
        RlKIHON.SEKISAN := RlKIHON.SHOTOKU_WARI + RlKIHON.SHISAN_WARI
                         + RlKIHON.KINTO_WARI   + RlKIHON.BYODO_WARI;       -- 積算税額(基本)

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
        NSHITSU_KBN      NUMBER;                 -- 失業軽減対象区分
        NNIN             NUMBER(2);
        NRTN             NUMBER;

    BEGIN

        IF NlMAX_TODOKEDE_BI < i_RKOJIN.KOSEI_BI
          AND i_RKOJIN.NEW_SHIK_KBN<>5 THEN

            NlMAX_TODOKEDE_BI   := i_RKOJIN.KOSEI_BI;       -- 最大届出日(Work)
            NlMAX_JIYU          := i_RKOJIN.JIYU;           -- 最大事由(Work)
        END IF;

        IF i_RKOJIN.NEW_SHIK_KBN IN (1, 2, 3) THEN
            NlGENZON_KBN    := 0;                           -- 現存区分(Work)
        END IF;


        -- ◆
        IF i_CAL_KBN = c_CAL_KBN_TU THEN
            -- 通常課税計算
            IF (i_RKOJIN.NEW_SHIK_KBN IN (1, 3, 7, 9) OR
                (i_RKOJIN.NEW_SHIK_KBN IN (2, 8) AND i_RKOJIN.SEKISAN_GAI_KBN = 1)) AND
               i_RKOJIN.F4_SHIK_KBN IN (1, 3) THEN

                RlKIHON.FUKA_KIJITSU_CNT   := RlKIHON.FUKA_KIJITSU_CNT + 1; -- 賦課期日人員(基本)
            END IF;
        ELSE
            -- 賦課期日時点
            IF i_RKOJIN.NEW_SHIK_KBN IN (1, 3) THEN

                RlKIHON.FUKA_KIJITSU_CNT   := RlKIHON.FUKA_KIJITSU_CNT + 1; -- 賦課期日人員(基本)
            END IF;
        END IF;

-- 計算個人から以下の条件を満たす人数を一般でそれぞれカウント
-- 身障減免に関しては所得額も合計
        ----------------------------
        -- 22才以下人員
        ----------------------------
        IF NlNENREI_KEIGEN = 1 THEN
          -- システム条件より年齢軽減有り
            IF i_CAL_KBN = c_CAL_KBN_TU THEN
            -- 通常課税計算
                IF (i_RKOJIN.NEW_SHIK_KBN IN (3, 9))                --最新資格区分(員)
                    THEN
                    IF i_RKOJIN.CUST_3 = 1 THEN
                        Nl22Ika_CNT   := Nl22Ika_CNT + 1;           -- 22歳以下人員
                    END IF;
                END IF;
            ELSE
            -- 賦課期日時点
                IF i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND
                   i_RKOJIN.NEW_SHIK_KBN = 3 THEN                   --最新資格区分(員)
                    IF i_RKOJIN.CUST_3 = 1 THEN
                        Nl22Ika_CNT   := Nl22Ika_CNT + 1;           -- 22歳以下人員
                    END IF;
                END IF;
            END IF;
        ELSE
            -- 年齢軽減無し
            Nl22Ika_CNT      := 0;
        END IF;

        ----------------------------
        -- 身障人員/身障減免判定所得
        ----------------------------
        IF NlSINSHO_GENMEN = 1 THEN
            -- システム条件より身障減免有り
            IF i_CAL_KBN = c_CAL_KBN_TU THEN
                -- 通常課税計算
            IF i_RKOJIN.SHIK_4  IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_5  IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_6  IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_7  IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_8  IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_9  IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_10 IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_11 IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_12 IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_1  IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_2  IN (1, 2, 3, 11, 12, 13) OR
               i_RKOJIN.SHIK_3  IN (1, 2, 3, 11, 12, 13) THEN       --最新資格区分(主or擬主or員)
              IF i_RKOJIN.NEW_SHIK_KBN IN (1, 2, 3) THEN            --実行時点で資格がある人のみ対象
                NlShotokuKei := NlShotokuKei + i_RKOJIN.SHOTOKU;   --身障減免判定所得
              END IF;
              IF i_RKOJIN.CUST_1 = 1 AND
                (i_RKOJIN.SHIK_4  IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_5  IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_6  IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_7  IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_8  IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_9  IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_10 IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_11 IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_12 IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_1  IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_2  IN (1, 3, 11, 13) OR
                 i_RKOJIN.SHIK_3  IN (1, 3, 11, 13)) THEN
                NlShogai_CNT   := NlShogai_CNT + 1;        -- 身障対象人員
              END IF;
            END IF;
          ELSE
            -- 賦課期日時点
            IF i_CAL_KBN IN (c_CAL_KBN_FK,c_CAL_KBN_F4) AND i_RKOJIN.NEW_SHIK_KBN IN (1, 3) THEN --擬主を見ないように統一
              -- 所得合計
              NlShotokuKei := NlShotokuKei + i_RKOJIN.SHOTOKU;
              IF i_RKOJIN.CUST_1 = 1  AND i_RKOJIN.NEW_SHIK_KBN IN (1, 3, 7, 9) THEN
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

            RlKIHON.KINTO_CNT := RlKIHON.KINTO_CNT + 1;                 -- 均等人員(基本)
            -- 子ども軽減(未就学児軽減)か否かの判定を行う
            NRTN := ZLBPK00140.FCKDM_HANTEI(i_NSETAI,i_NNENDO_BUN,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),i_RKOJIN.KOJIN_NO,NNIN,i_VTANMATSU);
            IF NNIN = 0 THEN
                RlKIHON.KINTO_CNT_KDM18 := RlKIHON.KINTO_CNT_KDM18 + 1; --18歳以上均等人員
            END IF;

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
            RlKIHON.SHOTOKU_WARI := RlKIHON.SHOTOKU_WARI + i_RKOJIN.KDM_SHOTOKU_WARI;
                                                                                    -- 所得割額(基本)
            RlKIHON.SHISANZEI    := RlKIHON.SHISANZEI + i_RKOJIN.SHISANZEI;     -- 資産税額(基本)
            RlKIHON.SHISAN_WARI  := RlKIHON.SHISAN_WARI + i_RKOJIN.KDM_SHISAN_WARI;
                                                                                    -- 資産割額(基本)
        END IF;
        IF i_RKOJIN.NEW_SHIK_KBN IN (1, 3) THEN
            RlKIHON.GENZAI_CNT := RlKIHON.GENZAI_CNT + 1;       -- 現在人員(基本)
        END IF;

    END subSekisanMae;
-------------------------------------------------------------------------------
-- 02 条件読込み
-------------------------------------------------------------------------------
    PROCEDURE subJokenSel IS

      TYPE MT_JOKEN IS RECORD(  GENDOGAKU_KDM       ZLBTJOKEN.GENDOGAKU_KDM%TYPE,
                                KINTO_KDM           ZLBTJOKEN.KINTO_KDM%TYPE,
                                BYODO_KDM           ZLBTJOKEN.BYODO_KDM%TYPE,
                                KEIGEN_1            ZLBTJOKEN.KEIGEN_1%TYPE,
                                KINGE_KDM_1         ZLBTJOKEN.KINGE_KDM_1%TYPE,
                                BYGE_KDM_1          ZLBTJOKEN.BYGE_KDM_1%TYPE,
                                KEIGEN_2            ZLBTJOKEN.KEIGEN_2%TYPE,
                                KINGE_KDM_2         ZLBTJOKEN.KINGE_KDM_2%TYPE,
                                BYGE_KDM_2          ZLBTJOKEN.BYGE_KDM_2%TYPE,
                                KEIGEN_3            ZLBTJOKEN.KEIGEN_3%TYPE,
                                KINGE_KDM_3         ZLBTJOKEN.KINGE_KDM_3%TYPE,
                                BYGE_KDM_3          ZLBTJOKEN.BYGE_KDM_3%TYPE,
                                HASU_KDM            ZLBTJOKEN.HASU_KDM%TYPE,
                                NUSHI_KAZEI         ZLBTJOKEN.NUSHI_KAZEI%TYPE,
                                NENREI_KEIGEN       ZLBTJOKEN.NENREI_KEIGEN%TYPE,
                                SINSHO_GENMEN       ZLBTJOKEN.SINSHO_GENMEN%TYPE,
                                GENMENRITU_KEISAN   ZLBTJOKEN.GENMENRITU_KEISAN%TYPE,
                                SHOTOKU_2DANKAI     ZLBTJOKEN.SHOTOKU_2DANKAI%TYPE,
                                SHOTOKU_HANTEI_GAKU ZLBTJOKEN.SHOTOKU_HANTEI_GAKU%TYPE,
                                SHOTOKU_KDM_OVER    ZLBTJOKEN.SHOTOKU_KDM_OVER%TYPE,
                                SHOTOKU_KDM         ZLBTJOKEN.SHOTOKU_KDM%TYPE,
                                SHISAN_KDM          ZLBTJOKEN.SHISAN_KDM%TYPE,
                                FUKI_KAZEI          ZLBTJOKEN.FUKI_KAZEI%TYPE,
                                KINTO_KDM18         ZLBTJOKEN.KINTO_KDM18%TYPE,
                                KINGE_KDM18_1       ZLBTJOKEN.KINGE_KDM18_1%TYPE,
                                KINGE_KDM18_2       ZLBTJOKEN.KINGE_KDM18_2%TYPE,
                                KINGE_KDM18_3       ZLBTJOKEN.KINGE_KDM18_3%TYPE
                              );
      RwJOKEN         MT_JOKEN;
        RwEXTJOKEN      ZLBTEXTJOKEN%ROWTYPE;

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
          SELECT  GENDOGAKU_KDM      ,KINTO_KDM          ,BYODO_KDM          ,
                  KEIGEN_1           ,KINGE_KDM_1        ,BYGE_KDM_1         ,
                  KEIGEN_2           ,KINGE_KDM_2        ,BYGE_KDM_2         ,
                  KEIGEN_3           ,KINGE_KDM_3        ,BYGE_KDM_3         ,
                  HASU_KDM           ,NUSHI_KAZEI        ,NENREI_KEIGEN      ,
                  SINSHO_GENMEN      ,GENMENRITU_KEISAN  ,SHOTOKU_2DANKAI    ,
                  SHOTOKU_HANTEI_GAKU,SHOTOKU_KDM_OVER   ,SHOTOKU_KDM        ,
                  SHISAN_KDM         ,FUKI_KAZEI         ,KINTO_KDM18        ,
                  KINGE_KDM18_1      ,KINGE_KDM18_2      ,KINGE_KDM18_3
          INTO    RwJOKEN
          FROM    ZLBTJOKEN
           WHERE NENDO           = i_NNENDO_BUN
             AND SANTEIDANTAI_CD = c_NDANTAI;

          BEGIN
          RwEXTJOKEN := NULL;
          -- 拡張条件読み込み
          SELECT *
            INTO RwEXTJOKEN
            FROM ZLBTEXTJOKEN
           WHERE NENDO           =  i_NNENDO_BUN
             AND SANTEIDANTAI_CD =  c_NDANTAI;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
                IF i_NNENDO_BUN <= 2007 THEN
                  NlJBGEN_T1 := 0;
                  NlJBGEN_T2 := 0;
                  NlJBGEN_T3 := 0;
                  NlJBGEN2_T1 := 0;
                  NlJBGEN2_T2 := 0;
                  NlJBGEN2_T3 := 0;
                ELSE
                NlRTN := c_NERR;
                VlMSG := 'subJokenSel 拡張条件取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
                END IF;
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subJokenSel 拡張条件取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
          END;
        ELSE
          SELECT  GENDOGAKU_KDM      ,KINTO_KDM          ,BYODO_KDM          ,
                  KEIGEN_1           ,KINGE_KDM_1        ,BYGE_KDM_1         ,
                  KEIGEN_2           ,KINGE_KDM_2        ,BYGE_KDM_2         ,
                  KEIGEN_3           ,KINGE_KDM_3        ,BYGE_KDM_3         ,
                  HASU_KDM           ,NUSHI_KAZEI        ,NENREI_KEIGEN      ,
                  SINSHO_GENMEN      ,GENMENRITU_KEISAN  ,SHOTOKU_2DANKAI    ,
                  SHOTOKU_HANTEI_GAKU,SHOTOKU_KDM_OVER   ,SHOTOKU_KDM        ,
                  SHISAN_KDM         ,FUKI_KAZEI         ,KINTO_KDM18        ,
                  KINGE_KDM18_1      ,KINGE_KDM18_2      ,KINGE_KDM18_3
          INTO    RwJOKEN
          FROM    ZLBTJOKEN_ZER
           WHERE NENDO           = i_NNENDO_BUN
             AND SANTEIDANTAI_CD = c_NDANTAI;

          BEGIN
          RwEXTJOKEN := NULL;
          -- 試算拡張条件読み込み
          SELECT *
            INTO RwEXTJOKEN
            FROM ZLBTEXTJOKEN_ZER
           WHERE NENDO           =  i_NNENDO_BUN
             AND SANTEIDANTAI_CD =  c_NDANTAI;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
                IF i_NNENDO_BUN <= 2007 THEN
                  NlJBGEN_T1 := 0;
                  NlJBGEN_T2 := 0;
                  NlJBGEN_T3 := 0;
                  NlJBGEN2_T1 := 0;
                  NlJBGEN2_T2 := 0;
                  NlJBGEN2_T3 := 0;
                ELSE
                NlRTN := c_NERR;
                VlMSG := 'subJokenSel 拡張条件取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
                END IF;
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subJokenSel 拡張条件取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
          END;
        END IF;
        -- 2-3.システム条件から未就学児均等割軽減率を取得
        SELECT NVL(KODOMO_KEIGEN_WARIAI , 0)
          INTO NKODOMO_KEIGEN_WARIAI
          FROM ZLBTJOKEN
         WHERE NENDO = i_NNENDO_BUN
           AND SANTEIDANTAI_CD = 1;

        -- 不均一課税を行なうか否か判定
        IF RwJOKEN.FUKI_KAZEI = c_NFKAZEI THEN
            -- 不均一課税を行なう

            -- 算定団体コード=パラメータの算定団体コードでシステム条件を再取得
            IF i_NJIKKOU_KBN  <>  c_NBATCH_ZER THEN
              SELECT  GENDOGAKU_KDM      ,KINTO_KDM          ,BYODO_KDM          ,
                      KEIGEN_1           ,KINGE_KDM_1        ,BYGE_KDM_1         ,
                      KEIGEN_2           ,KINGE_KDM_2        ,BYGE_KDM_2         ,
                      KEIGEN_3           ,KINGE_KDM_3        ,BYGE_KDM_3         ,
                      HASU_KDM           ,NUSHI_KAZEI        ,NENREI_KEIGEN      ,
                      SINSHO_GENMEN      ,GENMENRITU_KEISAN  ,SHOTOKU_2DANKAI    ,
                      SHOTOKU_HANTEI_GAKU,SHOTOKU_KDM_OVER   ,SHOTOKU_KDM        ,
                      SHISAN_KDM         ,FUKI_KAZEI         ,KINTO_KDM18        ,
                      KINGE_KDM18_1      ,KINGE_KDM18_2      ,KINGE_KDM18_3
              INTO    RwJOKEN
              FROM    ZLBTJOKEN
               WHERE NENDO           = i_NNENDO_BUN
                 AND SANTEIDANTAI_CD = i_NDANTAI;

              BEGIN
              RwEXTJOKEN := NULL;
              -- 拡張条件読み込み
              SELECT *
                INTO RwEXTJOKEN
                FROM ZLBTEXTJOKEN
               WHERE NENDO           =  i_NNENDO_BUN
                 AND SANTEIDANTAI_CD =  i_NDANTAI;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    IF i_NNENDO_BUN <= 2007 THEN
                      NlJBGEN_T1 := 0;
                      NlJBGEN_T2 := 0;
                      NlJBGEN_T3 := 0;
                      NlJBGEN2_T1 := 0;
                      NlJBGEN2_T2 := 0;
                      NlJBGEN2_T3 := 0;
                    ELSE
                    NlRTN := c_NERR;
                    VlMSG := 'subJokenSel 拡張条件取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
                    END IF;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subJokenSel 拡張条件取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
              END;
            ELSE
              SELECT  GENDOGAKU_KDM      ,KINTO_KDM          ,BYODO_KDM          ,
                      KEIGEN_1           ,KINGE_KDM_1        ,BYGE_KDM_1         ,
                      KEIGEN_2           ,KINGE_KDM_2        ,BYGE_KDM_2         ,
                      KEIGEN_3           ,KINGE_KDM_3        ,BYGE_KDM_3         ,
                      HASU_KDM           ,NUSHI_KAZEI        ,NENREI_KEIGEN      ,
                      SINSHO_GENMEN      ,GENMENRITU_KEISAN  ,SHOTOKU_2DANKAI    ,
                      SHOTOKU_HANTEI_GAKU,SHOTOKU_KDM_OVER   ,SHOTOKU_KDM        ,
                      SHISAN_KDM         ,FUKI_KAZEI         ,KINTO_KDM18        ,
                      KINGE_KDM18_1      ,KINGE_KDM18_2      ,KINGE_KDM18_3
              INTO    RwJOKEN
              FROM    ZLBTJOKEN_ZER
               WHERE NENDO           = i_NNENDO_BUN
                 AND SANTEIDANTAI_CD = i_NDANTAI;

              BEGIN
              RwEXTJOKEN := NULL;
              -- 試算拡張条件読み込み
              SELECT *
                INTO RwEXTJOKEN
                FROM ZLBTEXTJOKEN_ZER
               WHERE NENDO           =  i_NNENDO_BUN
                 AND SANTEIDANTAI_CD =  i_NDANTAI;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    IF i_NNENDO_BUN <= 2007 THEN
                      NlJBGEN_T1 := 0;
                      NlJBGEN_T2 := 0;
                      NlJBGEN_T3 := 0;
                      NlJBGEN2_T1 := 0;
                      NlJBGEN2_T2 := 0;
                      NlJBGEN2_T3 := 0;
                    ELSE
                    NlRTN := c_NERR;
                    VlMSG := 'subJokenSel 拡張条件取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
                    END IF;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subJokenSel 拡張条件取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
              END;
            END IF;
            -- 3-3.システム条件から未就学児均等割軽減率を取得
            SELECT NVL(KODOMO_KEIGEN_WARIAI , 0)
              INTO NKODOMO_KEIGEN_WARIAI
              FROM ZLBTJOKEN
             WHERE NENDO = i_NNENDO_BUN
               AND SANTEIDANTAI_CD = i_NDANTAI;

        END IF;

        --引数.処理モード=1（基盤安定）のとき
        IF i_NSHORI_MD = 1 THEN
            --システム条件から取得した子ども均等割軽減率を「0」で上書きする。
            NKODOMO_KEIGEN_WARIAI := 0;
        END IF;
        -- 作業用エリアに保持
        NlJGENDOGAKU := RwJOKEN.GENDOGAKU_KDM;          -- 限度額
        NlJKINTO     := RwJOKEN.KINTO_KDM;              -- 均等割額
        NlJBYODO     := RwJOKEN.BYODO_KDM;              -- 平等割額
        NlJKEIGEN1   := RwJOKEN.KEIGEN_1;                -- 軽減区分1(6,7割)
        NlJKGEN1     := RwJOKEN.KINGE_KDM_1;            -- 軽減均等割1(6,7割)
        NlJBGEN1     := RwJOKEN.BYGE_KDM_1;             -- 軽減平等割1(6,7割)
        NlJKEIGEN2   := RwJOKEN.KEIGEN_2;                -- 軽減区分2(4,5割)
        NlJKGEN2     := RwJOKEN.KINGE_KDM_2;            -- 軽減均等割2(4,5割)
        NlJBGEN2     := RwJOKEN.BYGE_KDM_2;             -- 軽減平等割2(4,5割)
        NlJKEIGEN3   := RwJOKEN.KEIGEN_3;                -- 軽減区分3(2割)
        NlJKGEN3     := RwJOKEN.KINGE_KDM_3;            -- 軽減均等割3(2割)
        NlJBGEN3     := RwJOKEN.BYGE_KDM_3;             -- 軽減平等割3(2割)
        NlJHASU      := RwJOKEN.HASU_KDM;               -- 端数
        NlJNUSHI     := RwJOKEN.NUSHI_KAZEI;            --主課税条件
        NlNENREI_KEIGEN    := RwJOKEN.NENREI_KEIGEN;      -- 年齢軽減
        NlSINSHO_GENMEN   := RwJOKEN.SINSHO_GENMEN;      -- 身障減免
        NlGENMENRITU      := RwJOKEN.GENMENRITU_KEISAN;  -- 減免率計算
        NSHOTOKU_2DANKAI     := RwJOKEN.SHOTOKU_2DANKAI;     --所得２段階
        NSHOTOKU_HANTEI_GAKU := RwJOKEN.SHOTOKU_HANTEI_GAKU; --所得割判定額
        NSSHOTOKU_KDM_OVER  := RwJOKEN.SHOTOKU_KDM_OVER;   --所得割率
        NSHOTOKU_KDM        := RwJOKEN.SHOTOKU_KDM;        --所得割率２
        NSHISAN_KDM          := RwJOKEN.SHISAN_KDM;        --子ども資産割率
        NlJKINTO18         := RwJOKEN.KINTO_KDM18;         --子ども18歳以上均等割額
        NlJKGEN118       := RwJOKEN.KINGE_KDM18_1;       --子ども軽減18歳以上均等１
        NlJKGEN218       := RwJOKEN.KINGE_KDM18_2;       --子ども軽減18歳以上均等２
        NlJKGEN318       := RwJOKEN.KINGE_KDM18_3;       --子ども軽減18歳以上均等３

        IF RwEXTJOKEN.NENDO IS NOT NULL THEN
          -- 特定同一軽減平等割額
          NlJBGEN_T1  := NVL(RwEXTJOKEN.BYGE_KDM_1, 0);        -- 特定同一 軽減平等割1(7,6割)
          NlJBGEN_T2  := NVL(RwEXTJOKEN.BYGE_KDM_2, 0);        -- 特定同一 軽減平等割2(5,4割)
          NlJBGEN_T3  := NVL(RwEXTJOKEN.BYGE_KDM_3, 0);        -- 特定同一 軽減平等割3(2割)
          -- 特定同一(2)軽減平等割額
          NlJBGEN2_T1 := NVL(RwEXTJOKEN.BYGE2_KDM_1, 0);      -- 特定同一(2) 軽減平等割1(7,6割)
          NlJBGEN2_T2 := NVL(RwEXTJOKEN.BYGE2_KDM_2, 0);      -- 特定同一(2) 軽減平等割2(5,4割)
          NlJBGEN2_T3 := NVL(RwEXTJOKEN.BYGE2_KDM_3, 0);      -- 特定同一(2) 軽減平等割3(2割)
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subJokenSel システム条件取得(国保世帯番号='||
                     i_NSETAI||')'||SQLERRM;
    END subJokenSel;

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
        NlKEIGEN_KINTO18    := 0;                   -- 18歳以上均等軽減額
        NlKEIGEN_KINTO18UN  := 0;                   -- 18歳未満均等軽減額
        NlKEIGEN_BYODO      := 0;                   -- 軽減平等
        NlKEIGEN_K_6_ZEN    := 0;                   -- 軽減均等6 全体
        NlKEIGEN_B_6_ZEN    := 0;                   -- 軽減平等6 全体
        NlKEIGEN_K_4_ZEN    := 0;                   -- 軽減均等4 全体
        NlKEIGEN_B_4_ZEN    := 0;                   -- 軽減平等4 全体
        NlKEIGEN_K_2_ZEN    := 0;                   -- 軽減均等2 全体
        NlKEIGEN_B_2_ZEN    := 0;                   -- 軽減平等2 全体
        NlNENZEIGAKU        := 0;                   -- 年税額
        NlSEISAN_KBN        := 0;                   -- 清算区分

        NlNENREI_KEIGEN     := 0;                   -- 年齢軽減
        NlSINSHO_GENMEN     := 0;                   -- 身障減免
        NlGENMENRITU        := 0;                   -- 減免率計算

        Nl22Ika_CNT         := 0;                   -- 22才以下人員
        NlShotokuKei        := 0;                   -- 所得合計
        NlShogai_CNT        := 0;                   -- 身障対象人員
        NNENREI_KEIGEN      := 0;                   -- 年齢軽減額

        FOR NwIX IN 1..12 LOOP
            MlSHIK_KBN(NwIX)    := 0;               -- 各月資格区分
            MlIRYSHIK_KBN(NwIX) := 0;               -- 各月資格区分(医療)
            MlSHITSU_KBN(NwIX)  := 0;               -- 各月失業資格区分
            MlCNT(NwIX)         := 0;               -- 人員(各月有資格者数)
            MlCNT18(NwIX)       := 0;               -- 人員(各月有資格者数　うち18歳以上)
            MlCNT18UN(NwIX)     := 0;               -- 人員(各月有資格者数　うち18歳未満)
            MlZEIGAKU(NwIX)     := 0;               -- 税額
            MlKINTO18UN(NwIX)   := 0;               -- 18歳未満の均等割額の計
            MlZEIGAKU18(NwIX)   := 0;               -- 年税額(産前産後限度超過計算時の年税額に関わる18歳以上均等割軽減額/18歳未満均等割軽減額)
            MlZEIGAKU218(NwIX)  := 0;               -- 税額限度超過調整用(産前産後限度超過計算時の年税額に関わる18歳以上均等割軽減額/18歳未満均等割軽減額)
            MlKEIGEN_KBN(NwIX)  := 0;               -- 各月軽減区分
            MlCHOKA_MAE(NwIX)   := 0;               -- 限度超過前
            MlSUMI(NwIX)        := 0;               -- 済
            MlTUKI(NwIX)        := 0;               -- 月数
            MlNEN_CNT(NwIX)     := 0;               -- 年齢軽減人員(各月有資格者数)
            MlKAHYO(NwIX)       := 0;               -- 課標
            MlZEIGAKU_SEKI(NwIX):= 0;               -- 積算算出用 税額
            MlSUMI_SEKI(NwIX)   := 0;               -- 積算算出用 済
            MlTUKI_SEKI(NwIX)   := 0;               -- 積算算出用 月数
            MlCHOKA_SEKI(NwIX)  := 0;               -- 積算算出用 限度超過
            MlKAHYO_SEKI(NwIX)  := 0;               -- 積算算出用 課標
            MlNEN_CNT_SEKI(NwIX):= 0;               -- 積算算出用 年齢軽減人員(各月有資格者数)
            MJI_NINSU(NwIX):= 0;                    -- 子ども人数ワーク
            MlSAN_KBN(NwIX):= 0;
            MlSANCNT(NwIX):= 0;
            MlSANCNT_K(NwIX):= 0;
            MlSANCNT18(NwIX):= 0;                   -- 産前産後　人数(うち18歳以上)
            MlSANCNT_K18(NwIX):= 0;                 -- 産前産後　人数(旧被扶養者 うち18歳以上)
            MlSANCNT18UN(NwIX):= 0;                 -- 産前産後　人数(うち18歳未満)
            MlSANCNT_K18UN(NwIX):= 0;               -- 産前産後　人数(旧被扶養者 うち18歳未満)
        END LOOP;
        --応益係数
        NlPER(1)       := 50;
        NlPER(2)       := 70;
        NlPER(3)       := 90;
        NlPER(4)       := 100;


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
         ORDER BY SHIK_3 DESC, SHIK_2 DESC, SHIK_1 DESC, SHIK_12 DESC, SHIK_11 DESC, SHIK_10 DESC,
                  SHIK_9 DESC, SHIK_8 DESC, SHIK_7 DESC, SHIK_6  DESC, SHIK_5  DESC, SHIK_4  DESC;

      VSHIK   NVARCHAR2(12);
      NSHIK   NUMBER(2) := 0;
    BEGIN
      IF RlKIHON.GENZAI_CNT = 0 AND NlShogai_CNT > 0 THEN
        FOR CRKOJIN IN CKOJIN LOOP
          VSHIK := CASE WHEN CRKOJIN.SHIK_3  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_2  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_1  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_12 > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_11 > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_10 > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_9  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_8  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_7  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_6  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_5  > 0 THEN '1' ELSE '0' END ||
                   CASE WHEN CRKOJIN.SHIK_4  > 0 THEN '1' ELSE '0' END;
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
        -- ZLBTKOJIN_CALに存在してZLBTGENMEN_KOJIN_TMPに存在しないデータの個人番号を取得
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
                    NYUSEN_KBN                            := CREC.YUSEN_KBN;
                    RlGENMEN_KOJIN.YUSEN_KBN              := CREC.YUSEN_KBN;              --優先区分
                    RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU    := CREC.KDM_BYODOWARI_RITSU;    --平等割減免率
                    RlGENMEN_KOJIN.KDM_GENMEN_4           := CREC.KDM_GENMEN_4;           --減免４月
                    RlGENMEN_KOJIN.KDM_GENMEN_5           := CREC.KDM_GENMEN_5;           --減免５月
                    RlGENMEN_KOJIN.KDM_GENMEN_6           := CREC.KDM_GENMEN_6;           --減免６月
                    RlGENMEN_KOJIN.KDM_GENMEN_7           := CREC.KDM_GENMEN_7;           --減免７月
                    RlGENMEN_KOJIN.KDM_GENMEN_8           := CREC.KDM_GENMEN_8;           --減免８月
                    RlGENMEN_KOJIN.KDM_GENMEN_9           := CREC.KDM_GENMEN_9;           --減免９月
                    RlGENMEN_KOJIN.KDM_GENMEN_10          := CREC.KDM_GENMEN_10;          --減免10月
                    RlGENMEN_KOJIN.KDM_GENMEN_11          := CREC.KDM_GENMEN_11;          --減免11月
                    RlGENMEN_KOJIN.KDM_GENMEN_12          := CREC.KDM_GENMEN_12;          --減免12月
                    RlGENMEN_KOJIN.KDM_GENMEN_1           := CREC.KDM_GENMEN_1;           --減免１月
                    RlGENMEN_KOJIN.KDM_GENMEN_2           := CREC.KDM_GENMEN_2;           --減免２月
                    RlGENMEN_KOJIN.KDM_GENMEN_3           := CREC.KDM_GENMEN_3;           --減免３月
                    RlGENMEN_KOJIN.KDM_SHOTOKU_GENGAKU    := CREC.KDM_SHOTOKU_GENGAKU;    --所得割減免額
                    RlGENMEN_KOJIN.KDM_SISANZEI_GENGAKU   := CREC.KDM_SISANZEI_GENGAKU;   --資産割減免額
                    RlGENMEN_KOJIN.KDM_KINTOWARI_GENGAKU  := CREC.KDM_KINTOWARI_GENGAKU;  --均等割減免額
                    RlGENMEN_KOJIN.KDM_BYODOWARI_GENGAKU  := CREC.KDM_BYODOWARI_GENGAKU;  --平等割減免額
                    RlGENMEN_KOJIN.KDM_NENZEI_RITSU       := CREC.KDM_NENZEI_RITSU;       --年税減免率
                    RlGENMEN_KOJIN.KDM_NENZEI_GENGAKU     := CREC.KDM_NENZEI_GENGAKU;     --年税減免額
                    RlGENMEN_KOJIN.SHINSEI_BI             := CREC.SHINSEI_BI;             --申請日
                    RlGENMEN_KOJIN.KDM_SHOTOKU_RITSU      := CREC.KDM_SHOTOKU_RITSU;      --所得割減免率(子ども)
                    RlGENMEN_KOJIN.KDM_SISANZEI_RITSU     := CREC.KDM_SISANZEI_RITSU;     --資産割減免率(子ども)
                    RlGENMEN_KOJIN.KDM_KINTOWARI_RITSU    := CREC.KDM_KINTOWARI_RITSU;    --均等割減免率(子ども)
                    RlGENMEN_KOJIN.KOKU_SETAI_NO          := CREC.KOKU_SETAI_NO;          --国保世帯番号
                    RlGENMEN_KOJIN.SANTEIDANTAI_CD        := CREC.SANTEIDANTAI_CD;        --算定団体コード
                    RlGENMEN_KOJIN.NENDO_BUN              := CREC.NENDO_BUN;              --年度分
                    RlGENMEN_KOJIN.KOJIN_NO               := CREC.KOJIN_NO;               --個人番号
                    RlGENMEN_KOJIN.SYS_TANMATSU_NO        := CREC.SYS_TANMATSU_NO;        --更新端末番号
                    RlGENMEN_KOJIN.KDM_KINTOWARI_18_RITSU := CREC.KDM_KINTOWARI_18_RITSU; --18歳以上均等割減免率(子ども)
                    RlGENMEN_KOJIN.KDM_KINTOWARI_18_GENGAKU := CREC.KDM_KINTOWARI_18_GENGAKU; --18歳以上均等割減免額(子ども)

                  --減免有を優先でセット
                  ELSIF nCNT > 1 AND CREC.YUSEN_KBN = 0 THEN
                    IF CREC.KDM_GENMEN_4  = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_4  := 1; END IF; --減免４月
                    IF CREC.KDM_GENMEN_5  = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_5  := 1; END IF; --減免５月
                    IF CREC.KDM_GENMEN_6  = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_6  := 1; END IF; --減免６月
                    IF CREC.KDM_GENMEN_7  = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_7  := 1; END IF; --減免７月
                    IF CREC.KDM_GENMEN_8  = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_8  := 1; END IF; --減免８月
                    IF CREC.KDM_GENMEN_9  = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_9  := 1; END IF; --減免９月
                    IF CREC.KDM_GENMEN_10 = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_10 := 1; END IF; --減免10月
                    IF CREC.KDM_GENMEN_11 = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_11 := 1; END IF; --減免11月
                    IF CREC.KDM_GENMEN_12 = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_12 := 1; END IF; --減免12月
                    IF CREC.KDM_GENMEN_1  = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_1  := 1; END IF; --減免１月
                    IF CREC.KDM_GENMEN_2  = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_2  := 1; END IF; --減免２月
                    IF CREC.KDM_GENMEN_3  = 1 THEN RlGENMEN_KOJIN.KDM_GENMEN_3  := 1; END IF; --減免３月
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
-- 独自減免
-------------------------------------------------------------------------------
PROCEDURE subGenmenDokuji IS
  BEGIN
        -- 所得割減免額
        NSHOTOKU_GENGAKU := TRUNC (NKANYUKI / 12 * RlKIHON.SHOTOKU_WARI
                                    * (NVL (RlGENMEN_KOJIN.KDM_SHOTOKU_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        --資産割減免額
        NSISANZEI_GENGAKU := TRUNC (NKANYUKI / 12 * RlKIHON.SHISAN_WARI
                                    * (NVL (RlGENMEN_KOJIN.KDM_SISANZEI_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        --均等割減免額
        NKINTOWARI_GENGAKU := TRUNC (NKANYUKI / 12 * (RlKIHON.KINTO_WARI - RlKIHON.KEIGEN_K_WARI)
                                    * (NVL (RlGENMEN_KOJIN.KDM_KINTOWARI_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        --均等割減免額
        NBYODOWARI_GENGAKU := TRUNC (NKANYUKI / 12 * (RlKIHON.BYODO_WARI - RlKIHON.KEIGEN_B_WARI)
                                    * (NVL (RlGENMEN_KOJIN.KDM_BYODOWARI_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        --均等割減免額_18
        NKINTOWARI_GENGAKU_18  := TRUNC (NKANYUKI / 12 * (RlKIHON.KINTO_KDM18 - RlEXT.KDM18_KEIGEN_KINTOWARI)
                                    * (NVL (RlGENMEN_KOJIN.KDM_KINTOWARI_18_RITSU, 0) / 100) * (NNOKIMATUKIBETSU / NFUKASHIRASU));
        -- 減免額合計の再セット
        UPDATE ZLBTGENMEN_KOJIN_CAL
        SET KDM_SHOTOKU_GENGAKU      = NSHOTOKU_GENGAKU,                             -- 所得割減免額(子ども)
            KDM_SISANZEI_GENGAKU     = NSISANZEI_GENGAKU,                            -- 資産割減免額(子ども)
            KDM_KINTOWARI_GENGAKU    = NKINTOWARI_GENGAKU,                           -- 均等割減免額(子ども)
            KDM_KINTOWARI_18_GENGAKU = NKINTOWARI_GENGAKU_18,                        -- 18歳以上均等割減免額(子ども)
            KDM_BYODOWARI_GENGAKU    = NBYODOWARI_GENGAKU,                           -- 平等割減免額(子ども)
-- 2025/12/24 ZCZL.LIUYANG UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00136
--            KDM_GENGAKU_KEI          = NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU
--                                       + NKINTOWARI_GENGAKU_18 + NBYODOWARI_GENGAKU, -- 減免額合計(子ども)
--            KDM_GENGAKU              = NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU
--                                       + NKINTOWARI_GENGAKU_18 + NBYODOWARI_GENGAKU, -- 減免額(端数調整前で算出)(子ども)
            KDM_GENGAKU_KEI          = NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU
                                       + NBYODOWARI_GENGAKU,                         -- 減免額合計(子ども)
            KDM_GENGAKU              = NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU
                                       + NBYODOWARI_GENGAKU,                         -- 減免額(端数調整前で算出)(子ども)
-- 2025/12/24 ZCZL.LIUYANG UPDATE END
            KDM_GENGAKU_MAE          = RlKIHON.SEKISAN,                              -- 減免前の年税額(子ども)
            KDM_SHOTOKU_KISO         = RlKIHON.SHOTOKU_WARI,                         -- 所得割基礎額(子ども)
            KDM_SISANZEI_KISO        = RlKIHON.SHISAN_WARI,                          -- 資産割基礎額(子ども)
            KDM_KINTOWARI_KISO       = RlKIHON.KINTO_WARI,                           -- 均等割基礎額(子ども)
            KDM_KINTOWARI_18_KISO    = RlKIHON.KINTO_KDM18,                          -- 18歳以上均等割基礎額(子ども)
            KDM_BYODOWARI_KISO       = RlKIHON.BYODO_WARI,                           -- 平等割基礎額(子ども)
-- 2025/12/24 ZCZL.LIUYANG UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00136
--            KDM_NENZEI_KISO          = RlKIHON.SEKISAN - RlKIHON.GENGAKU_KEI -
--                                       (NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU
--                                       + NKINTOWARI_GENGAKU_18 + NBYODOWARI_GENGAKU) -- 年税基礎額(子ども)
            KDM_NENZEI_KISO          = RlKIHON.SEKISAN - RlKIHON.GENGAKU_KEI -
                                       (NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU
                                       + NBYODOWARI_GENGAKU)                         -- 年税基礎額(子ども)
-- 2025/12/24 ZCZL.LIUYANG UPDATE END
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
        UPDATE ZLBTKDM_KIHON_CAL
-- 2025/12/24 ZCZL.LIUYANG UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00136
--        SET GENMEN = NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU +
--                     NKINTOWARI_GENGAKU_18 + NBYODOWARI_GENGAKU
        SET GENMEN = NSHOTOKU_GENGAKU + NSISANZEI_GENGAKU + NKINTOWARI_GENGAKU +
                     NBYODOWARI_GENGAKU
-- 2025/12/24 ZCZL.LIUYANG UPDATE END
            ,NENZEI = NwNENZEIGAKU - RlKIHON.HASU
            ,HASU = RlKIHON.HASU
            ,GENGAKU_KEI = GENGAKU_KEI - NwHASU + RlKIHON.HASU
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

    IF NlRTN = c_NOK THEN
        subKodomoSet;                   -- 子ども人数設定
    END IF;

    IF NlRTN = c_NOK THEN
        subKDMSet;                      -- 18歳以上/18歳以下人数設定
    END IF;
    IF NlKOJIN_CNT > 0 THEN

        IF NlRTN = c_NOK THEN
            subSetaiGaku;               -- 06 世帯税額算出
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
                NlNENZEIGAKU        := 0;                   -- 年税額
                NNENREI_KEIGEN      := 0;                   -- 年齢軽減額
                FOR NwIX2 IN 1..12 LOOP
                    MlCNT(NwIX2)         := 0;               -- 人員(各月有資格者数)
                    MlZEIGAKU(NwIX2)     := 0;               -- 税額
                    MlSUMI(NwIX2)        := 0;               -- 済
                    MlTUKI(NwIX2)        := 0;               -- 月数
                    MlCHOKA_MAE(NwIX2)   := 0;               -- 限度超過前

                    MlNEN_CNT(NwIX2)     := 0;               -- 年齢軽減人員(各月有資格者数)
                    MlKAHYO(NwIX2)       := 0;               -- 課標

                    MlZEIGAKU_SEKI(NwIX2):= 0;               -- 積算算出用 税額
                    MlSUMI_SEKI(NwIX2)   := 0;               -- 積算算出用 済
                    MlTUKI_SEKI(NwIX2)   := 0;               -- 積算算出用 月数
                    MlCHOKA_SEKI(NwIX2)  := 0;               -- 積算算出用 限度超過
                    MlKAHYO_SEKI(NwIX2)  := 0;               -- 積算算出用 課標
                    MlNEN_CNT_SEKI(NwIX2):= 0;               -- 積算算出用 年齢軽減人員(各月有資格者数)

                    MlSANCNT(NwIX2)         := 0;            -- 各月産前産後人員(各月有資格者数)
                END LOOP;
            END IF;

            IF NlRTN = c_NOK THEN
                subZenTukiwari;             -- 07 基本処理
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
                        funcGetGenmen;          -- 27 減免額（全体）の取得
                    END IF;
                END IF;
            END IF;
            IF NlRTN = c_NOK THEN
                subShogaiGenmen;            -- 29 障害者減免を算出（医療）
            END IF;

            IF NlRTN = c_NOK THEN
               subSetaiGenmenGet;          -- 08.5 世帯減免の有無を取得
            END IF;

            IF NlRTN = c_NOK THEN
                NCNT_KAKUTEI := 0;
                subKakutei;                 -- 09 税額確定処理（基本）
            END IF;

            IF NGENMEN_EXIST_KBN = 1 THEN
                IF NLOOP_CNT_NOW = 1 THEN
                    -- 減免前の年税額と端数をワークに保存
                    NwNENZEIGAKU     := RlKIHON.NENZEI;
                    NwGENDO_CHOKA    := RlKIHON.GENDO_CHOKA;
                    NwHASU           := RlKIHON.HASU;
                ELSE
                  IF RlGENMEN_KOJIN.YUSEN_KBN IN (3, 4) THEN
                    vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                    vSQL := vSQL || ' SET KDM_NENZEI_KISO    = :1,';   -- 年税基礎額
                    vSQL := vSQL || '     KDM_NENZEI_GENGAKU = :2,';   -- 年税減免額
                    vSQL := vSQL || '     KDM_GENGAKU_MAE    = :3,';   -- 減免前の年税額
                    vSQL := vSQL || '     KDM_GENGAKU        = :4';    -- 減免額(端数調整前)
                    vSQL := vSQL || ' WHERE KOKU_SETAI_NO    = :5';
                    vSQL := vSQL || ' AND   SANTEIDANTAI_CD  = :6';
                    vSQL := vSQL || ' AND   NENDO_BUN        = :7';
                    vSQL := vSQL || ' AND   SYS_TANMATSU_NO  = :8';
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    vSQL := vSQL || '  AND ((YUSEN_KBN > 0 AND TSUCHI_NO = :9 )';
                    vSQL := vSQL || '        OR (YUSEN_KBN = 0 AND NVL(TSUCHI_NO,0) != 0))';
                  ELSE
                    vSQL := vSQL || '  AND :9 IS NOT NULL';
                  END IF;

                    EXECUTE IMMEDIATE vSQL USING IN NwNENZEIGAKU,
                                                    NwNENZEIGAKU - RlKIHON.NENZEI,
                                                    NwNENZEIGAKU,
                                                    RlKIHON.GENMEN,
                                                    i_NSETAI,
                                                    i_NDANTAI,
                                                    i_NNENDO_BUN,
                                                    i_VTANMATSU,
                                                    i_NNUSHI;
                  ELSE
                    vSQL :=          'UPDATE ZLBTGENMEN_KOJIN_CAL';
                    vSQL := vSQL || ' SET KDM_GENGAKU_MAE   = :1,';   -- 減免前の年税額
                    vSQL := vSQL || '     KDM_GENGAKU       = :2';    -- 減免額(端数調整前)
                    vSQL := vSQL || ' WHERE KOKU_SETAI_NO   = :3';
                    vSQL := vSQL || ' AND   SANTEIDANTAI_CD = :4';
                    vSQL := vSQL || ' AND   NENDO_BUN       = :5';
                    vSQL := vSQL || ' AND   SYS_TANMATSU_NO = :6';
                  IF NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 THEN
                    vSQL := vSQL || '  AND ((YUSEN_KBN > 0 AND TSUCHI_NO = :7 )';
                    vSQL := vSQL || '        OR (YUSEN_KBN = 0 AND NVL(TSUCHI_NO,0) != 0))';
                  ELSE
                    vSQL := vSQL || '  AND :7 IS NOT NULL';
                  END IF;

                    EXECUTE IMMEDIATE vSQL USING IN NwNENZEIGAKU,
                                                    RlKIHON.GENMEN,
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
             SET KDM_BYODOWARI_GENGAKU = 0
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
          SELECT NVL(SUM(KDM_SHOTOKU_KISO),0),
                 NVL(SUM(KDM_SISANZEI_KISO),0),
                 NVL(SUM(KDM_KINTOWARI_KISO),0),
                 NVL(SUM(KDM_KINTOWARI_18_KISO),0),
                 NVL(SUM(KDM_SHOTOKU_GENGAKU),0),
                 NVL(SUM(KDM_SISANZEI_GENGAKU),0),
                 NVL(SUM(KDM_KINTOWARI_GENGAKU),0),
                 NVL(SUM(KDM_KINTOWARI_18_GENGAKU),0),
                 NVL(SUM(KDM_BYODOWARI_GENGAKU),0),
                 NVL(SUM(KDM_NENZEI_GENGAKU),0)
            INTO NwSHOTOKU_KISO_SUM,
                 NwSISANZEI_KISO_SUM,
                 NwKINTOWARI_KISO_SUM,
                 NwKINTOWARI_KISO_18_SUM,
                 NwSHOTOKU_GENGAKU_SUM,
                 NwSISANZEI_GENGAKU_SUM,
                 NwKINTOWARI_GENGAKU_SUM,
                 NwKINTOWARI_GENGAKU_18_SUM,
                 NwBYODOWARI_GENGAKU_SUM,
                 NwNENZEI_GENGAKU_SUM
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
             SET KDM_SHOTOKU_KISO = NwSHOTOKU_KISO_SUM,
                 KDM_SISANZEI_KISO = NwSISANZEI_KISO_SUM,
                 KDM_KINTOWARI_KISO = NwKINTOWARI_KISO_SUM,
                 KDM_KINTOWARI_18_KISO = NwKINTOWARI_KISO_18_SUM,
                 KDM_SHOTOKU_GENGAKU = NwSHOTOKU_GENGAKU_SUM,
                 KDM_SISANZEI_GENGAKU = NwSISANZEI_GENGAKU_SUM,
                 KDM_KINTOWARI_GENGAKU = NwKINTOWARI_GENGAKU_SUM,
                 KDM_KINTOWARI_18_GENGAKU = NwKINTOWARI_GENGAKU_18_SUM,
                 KDM_BYODOWARI_GENGAKU = NwBYODOWARI_GENGAKU_SUM,
                 KDM_NENZEI_GENGAKU = NwNENZEI_GENGAKU_SUM
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
          --ZLBTGENMEN_KOJIN_CALの個人番号がZLBTGENMEN_KOJINに存在しないデータを削除する
          DELETE FROM ZLBTGENMEN_KOJIN_CAL CAL
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND NENDO_BUN       = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN = 0) --世帯主課税かつ優先区分0:個人/率/応能応益かつ市区町村条件92:1に設定時
                   OR(NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 0)--市区町村条件92:0に設定時
                   OR (NlJNUSHI <> 1)
                  )
              AND SYS_TANMATSU_NO = i_VTANMATSU
              AND NOT EXISTS (SELECT KOJIN_NO FROM ZLBTGENMEN_KOJIN
                           WHERE KOKU_SETAI_NO   = CAL.KOKU_SETAI_NO
                             AND SANTEIDANTAI_CD = CAL.SANTEIDANTAI_CD
                             AND KOJIN_NO        = CAL.KOJIN_NO
                             AND NENDO_BUN       = CAL.NENDO_BUN
                             AND KOJIN_NO = CAL.TSUCHI_NO);
        END IF;
        -- 減免額合計の再セット
        UPDATE ZLBTGENMEN_KOJIN_CAL
-- 2025/12/24 ZCZL.LIUYANG UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00136
--        SET    KDM_GENGAKU_KEI = KDM_SHOTOKU_GENGAKU + KDM_SISANZEI_GENGAKU +
--                                 KDM_KINTOWARI_GENGAKU + KDM_KINTOWARI_18_GENGAKU +
--                                 KDM_BYODOWARI_GENGAKU + KDM_NENZEI_GENGAKU
        SET    KDM_GENGAKU_KEI = KDM_SHOTOKU_GENGAKU + KDM_SISANZEI_GENGAKU +
                                 KDM_KINTOWARI_GENGAKU +
                                 KDM_BYODOWARI_GENGAKU + KDM_NENZEI_GENGAKU
-- 2025/12/24 ZCZL.LIUYANG UPDATE END
        WHERE  KOKU_SETAI_NO   = i_NSETAI
          AND  SANTEIDANTAI_CD = i_NDANTAI
          AND  NENDO_BUN       = i_NNENDO_BUN
              AND ((NlJNUSHI = 1 AND IGENMENNUSHI_KBN = 1 AND YUSEN_KBN > 0 AND TSUCHI_NO = i_NNUSHI)--世帯主課税かつ優先区分0:個人/率/応能応益以外かつ市区町村条件92:1に設定時
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
        subInsert;                      -- 12 計算基本登録
    END IF;
    IF NlKOJIN_CNT > 0 AND RlGENMEN_KOJIN.YUSEN_KBN = 6 THEN
      subGenmenDokuji;
    END IF;
    -- 計算個人18歳以上該当区分正規化
    -- 前処理が正常終了なら(NlRTN = c_NOK)なら、計算個人の18歳以上該当区分の２(未就学児)を、０(18歳未満)に更新する
    IF NlRTN = c_NOK THEN
        UPDATE ZLBTKOJIN_CAL
           SET KDM_18_KBN = 0
         WHERE SYS_TANMATSU_NO = i_VTANMATSU
           AND KDM_18_KBN      = 2;     -- (未就学児)
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
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCALMKDM', 1, '', '','ZLBSKCALMKDM '||VlMSG, NULL, i_VTANMATSU);
        ELSIF i_NTRENBAN = -1 THEN
            -- テストの時のみ有効
            DBMS_OUTPUT.PUT_LINE('ZLBSKCALMKDM '||VlMSG);
        END IF;
    END IF;

    o_NRESULT := NlRTN;

END ZLBSKCALMKDM;
/