CREATE OR REPLACE PROCEDURE ZLBSKCALPACK(i_NCHOTEI_NENDO         IN  NUMBER,
--1.1.200.000
                                        i_NNENDO_BUN            IN  NUMBER,
                                        i_NSYS_SHOKUINKOJIN_NO  IN  CHAR,
                                        i_NKIJUNBI              IN  NUMBER,
                                        i_NNOUKI_KBN            IN  NUMBER,
                                        i_NJIKKOU_KBN           IN  NUMBER,
                                        i_VMASIN_NO             IN  NVARCHAR2,
                                        i_NTRENBAN              IN  NUMBER,
                                        o_NRESULT               OUT NUMBER,
                                        i_SHORI_NENGETSU        IN  NUMBER := 0,  --期割のために処理月（省略可）
                                        i_TOTATSU_BI            IN  NUMBER DEFAULT NULL
)
-------------------------------------------------------------------------------
-- 業務名   ZLB（国保税）
-- ＰＧ名   ZLBSKCALPACK
-- 名称     課税計算
-- 処理概要 課税計算の一連の処理をコントロールし、中間基本・中間介護基本・
--          中間個人・中間所得・中間期別のデータを作成する。
-- 引き数   i_NCHOTEI_NENDO         調定年度
--          i_NNEDO_BUN             年度分
--          i_NSYS_SHOKUINKOJIN_NO  更新職員番号
--          i_NKIJUNBI              基準日
--          i_NNOUKI_KBN            納期区分
--          i_NJIKKOU_KBN           実行区分(0:バッチから起動 本算定/月例...
--                                           1:オンライン起動 即時
--                                           2:オンライン起動 税額試算
--                                           3:バッチから起動課税状況用課税計算)
--                                           4:バッチから起動実態調査（世帯表）用課税計算
--                                           5:優先区分(5-世帯／未到来期別)の計算機能を追加する。
--          i_VMASIN_NO             端末番号
--          i_NTRENBAN              登録連番
--          o_NRESULT               処理結果(0:正常終了、9:異常終了)
-- 作成者   ZCZL.BAOZEXIN
-- 作成日   2023/08/03
-- Version  0.2.000.000
------------------------------------------------------------------------------
--変更履歴
--2024/05/07 ZCZL.ZHANGLEI UPDATE 0.3.000.100:国保２次にマージ作業
--2024/09/23 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00020
--2025/08/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応
--2025/12/02 ZCZL.LIUYANG UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--2025/12/10 JIP.SUZUKI UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00106 処理ID誤り修正
------------------------------------------------------------------------------
IS

    TYPE MTVARARRAY IS TABLE OF NVARCHAR2(50) INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY3  IS TABLE OF NUMBER(3)  INDEX BY BINARY_INTEGER;

-------------------------------------------------------------------------------
-- コンストの定義
-------------------------------------------------------------------------------
    -- 戻り値  定数
    c_NOK            CONSTANT NUMBER(1) := 0;        -- 正常
    c_NERR           CONSTANT NUMBER(1) := 9;        -- 異常

    -- STEPログ
    c_NSTEPNO       CONSTANT NUMBER    := 99;

    -- 現年・過年区分
    c_NGENNEN       CONSTANT NUMBER(1) := 0;        -- 現年
    c_NKANEN        CONSTANT NUMBER(1) := 1;        -- 過年

    -- 合併後算定団体
    c_NDANTAI       CONSTANT NUMBER(2) := 1;        -- 合併後算定団体

    -- 不均一課税
    c_NFKAZEI       CONSTANT NUMBER := 1;           -- 不均一課税を行なう

    -- 実行区分
    c_NBATCH        CONSTANT NUMBER(1) := 0;        -- バッチから起動
    c_NONLNIN       CONSTANT NUMBER(1) := 1;        -- オンライン起動
    c_NONLNIN_SISAN CONSTANT NUMBER(1) := 2;        --オンライン起動（税額試算）
    c_KAZEIJOKYO    CONSTANT NUMBER(1) := 3;        --課税状況から起動
    c_JITTAI_SETAI  CONSTANT NUMBER(1) := 4;        --実態調査（世帯票）から起動
    c_JITTAI_CD     CONSTANT NUMBER(1) := 5;
    -- 計算対象読込み件数
    c_NMAX_NUM      CONSTANT NUMBER(4) := 1000;     -- 読込み最大件数

    -- 納期区分
    c_NNOUKI_HONSAN CONSTANT NUMBER(1) := 2;        -- 本算定
    c_NNOUKI_KARISAN CONSTANT NUMBER(1) := 1;       --仮算定

    -- 事由
    c_NJIYU_ETC         CONSTANT NUMBER(2) := 99;   -- その他内容変更（66は個人情報変更）
    c_NJIYU_SHOKAI      CONSTANT NUMBER(2) := 71;   -- 照会
    c_NJIYU_KYOSEI      CONSTANT NUMBER(2) := 85;   -- 強制変更
    c_NJIYU_SHOTOKKOSEI CONSTANT NUMBER(2) := 91;   -- 所得更正
    c_NJIYU_SHISANKOSEI CONSTANT NUMBER(2) := 92;   -- 資産更正
    c_NJIYU_HONSAN      CONSTANT NUMBER(2) := 95;   -- 本算定
    c_NJIYU_KIBETUKOSEI CONSTANT NUMBER(2) := 93;   -- 期別更正
  c_NJIYU_KEIGENKOSEI CONSTANT NUMBER(2) := 90;   --軽減変更
    c_NJIYU_GENMEN      CONSTANT NUMBER(2) := 94;   --減免

    -- 老年者区分
    c_NRONENKBN_4       CONSTANT NUMBER(1) := 4;    -- 住民税ﾏｽﾀになく65歳以上

    -- 老年者判定
    c_NRONEN_NENREI     CONSTANT NUMBER(3) := 65;   -- 65歳

    -- 按分処理(ZLBSBKIANBUN)
    c_NANBUN_SA         CONSTANT NUMBER(1) := 1;    -- 差額按分

    c_NKAMOKU_CD        CONSTANT NUMBER(3)  := 15;  -- 科目コード
    c_NKAMOKUS_CD       CONSTANT NUMBER(2)  := 1;   -- 科目詳細コード

    -- ZLBSKKOTGET用
    c_GYOMU_CD          CONSTANT NVARCHAR2(4) := 'ZLB';   -- 業務コード(不明)

    -- 基本/介護基本作成処理(ZLBSKCALMAIN/ZLBSKCALMKAI)
    c_CAL_KBN_TU        CONSTANT NUMBER(2) := 0;    -- 呼出区分(通常処理)
    c_CAL_KBN_FK        CONSTANT NUMBER(2) := 1;    --(1:賦課期日時点処理

  -- 所得区分
    c_SHOTOKU_MISHINKOKU  CONSTANT PLS_INTEGER := 99; -- 未申告
  -- 申告区分
    c_SHINKOKU_MISHINKOKU CONSTANT PLS_INTEGER := 7;  -- 未申告

    ISHICHOSON_CD                  PLS_INTEGER; --市町村コード
    c_UWAJIMA             CONSTANT PLS_INTEGER := 38203;  -- 宇和島市
    c_MURORAN             CONSTANT PLS_INTEGER :=  1205;  -- 室蘭市

    c_KYUYO_SHUNYU_IPN      CONSTANT PLS_INTEGER := 29;  --給与収入(一般)
    c_KYUYO_SHUNYU_SENJU    CONSTANT PLS_INTEGER := 30;  --給与収入(専従)
    c_KOTEKINEN_SHUNYU      CONSTANT PLS_INTEGER := 32;  --公的年金収入
    c_KOTEKINEN_KOUJYO      CONSTANT PLS_INTEGER := -9;  --年金控除額

    c_KOKI_START            CONSTANT NUMBER(8) := 20080401;  -- 後期高齢施行開始日

    -- 実行区分(ZLBFKKIWARIHT)
    c_KH_BTHONSAN           CONSTANT NUMBER(1) := 0;        -- バッチ起動 本算定
    c_KH_BTGETSU            CONSTANT NUMBER(1) := 1;        -- バッチ起動 月例
    c_KH_ONLINE             CONSTANT NUMBER(1) := 9;        -- オンライン起動

    -- 計算区分
    c_NKEISAN_KBN_3         CONSTANT PLS_INTEGER := 3;   -- 特徴中止
    c_NFUTSU_KEISAN         CONSTANT NUMBER := 1;        -- 普徴更正(金額調整)
    c_NFUTSU_KEISAN_STOP    CONSTANT PLS_INTEGER := 4;   --普徴更正(特徴中止)
    c_NFUTSU_KEISAN_CANCEL  CONSTANT PLS_INTEGER := 11;  --特徴キャンセル

    -- 対象区分(ZLBTKANWA_TAISHO_TMP)
    c_TAISHO_KBN1         CONSTANT NUMBER(1) := 1;       -- 特定同一
    c_TAISHO_KBN8         CONSTANT NUMBER(1) := 8;       --特定同一(2)

    c_SHOTOKU_HBN         CONSTANT NUMBER(1) := 1;

-------------------------------------------------------------------------------
-- ワークエリアの定義
-------------------------------------------------------------------------------
    -- 戻り値用
    NlRTN                   NUMBER;         -- Return値
    BlRTN                   BOOLEAN;        -- LOG採取結果
    VlMSG               VARCHAR2(256);

    NlTSUCHI_NO             NUMBER(12);     -- 通知書番号
    NlMAX_TSUCHI_NO         NUMBER(12);     -- 最大通知書番号
    NlFUKAKIJITU            NUMBER(8);      -- 賦課期日
    NlSHOTOKU_IRY           NUMBER(5,2);    -- 所得割率(医療)
    NlSHISANWARI_IRY        NUMBER(5,2);    -- 資産割率(医療)
    NlSHOTOKU_KAI           NUMBER(5,2);    -- 所得割率(介護)
    NlSHISANWARI_KAI        NUMBER(5,2);    -- 資産割率(介護)
    NlKISOKOJO              NUMBER(7);      -- 基礎控除
    NlKISOKOJO_S            NUMBER(7);      -- 基礎控除(非自発的失業者)
    NlFUKI_KAZEI            NUMBER;         -- 不均一課税
    NlNENDO_BUN             NUMBER(4);      -- 年度分
    NlGENKA_KBN             NUMBER(1);      -- 現年・過年区分
    NlTAISHO_NENDO          NUMBER;         -- 過年度課税計算対象年度
    NlNENDO_ZO              NUMBER;         -- 過年度計算対象年（増額）
    NlNENDO_GEN             NUMBER;         -- 過年度計算対象年（減額）
    NlSHOTOKU_IRY_OVER      NUMBER(5,2);    --所得割率判定額超(医療)
    NlSHOTOKU_KAI_OVER      NUMBER(5,2);    --所得割率判定額超(介護)
    NlSHOTOKU_HANTEI_GAKU   NUMBER(12);     --所得割判定額
    NlSHOTOKU_2DANKAI       NUMBER(1,0);    --所得割2段階
    ISHOKAICHU              PLS_INTEGER;    --所得照会中所得取扱
    NlSHOTOKU_SIEN          NUMBER(5,2);    --所得割率(支援)
    NlSHISANWARI_SIEN       NUMBER(5,2);    --資産割率(支援)
    NlSHOTOKU_SIEN_OVER     NUMBER(5,2);    --所得割率判定額超(支援)
    IZAN_MODE          PLS_INTEGER;     -- 0:通常 1:仮算定中
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
    NlSHOTOKU_KDM           NUMBER(5,2);    --所得割率(子ども)
    NlSHISANWARI_KDM        NUMBER(5,2);    --資産割率(子ども)
    NlSHOTOKU_KDM_OVER      NUMBER(5,2);    --所得割率判定額超(子ども)
--2025/08/11 ZCZL.LIUHUAJUN ADD END

    -- 計算対象カーソル用ワーク
    NlKOKU_SETAI_NO         NUMBER;
    NlKOKU_SETAI_NO_W       NUMBER;
    IlIDX                   PLS_INTEGER;    -- ループ用カウンタ
    IlMAX                   PLS_INTEGER;

    NlKOSEI_FLG             NUMBER;         --更正日更新フラグ

--日付変換用レコード型定義
  TYPE MTAAPFDAYEDIT IS RECORD( VEDIT_GYYMMDD1 NVARCHAR2(9),
                                VEDIT_GYYMMDD2 NVARCHAR2(9),
                                VEDIT_GYYMMDD3 NVARCHAR2(11),
                                VKJ_GENGO      NVARCHAR2(2),
                                VKG_GENGO      NVARCHAR2(1),
                                IWAREKI_YY     PLS_INTEGER,
                                ISEIREKI_YYYY  PLS_INTEGER,
                                IWAREKI_GYYMM  PLS_INTEGER,
                                IMM            PLS_INTEGER,
                                IDD            PLS_INTEGER,
                                IWAREKIHIZUKE  PLS_INTEGER,
                                ISEIREKIHIZUKE PLS_INTEGER);
    -- 合併初年度フラグ(0:合併年度以前、1:合併年度以降)
    NlGAPEINENDO            PLS_INTEGER := 0;
  IKAHYO_HASU_KBN           PLS_INTEGER := 0;
    vSQL      VARCHAR2(4000);
    NlNUSHI_KAZEI           NUMBER;         --過年度計算対象年（減額）
   NlSHOTOKU_HOSHIKI        NUMBER;         --所得割方式
-------------------------------------------------------------------------------
-- 計算TBL不足分作成(特徴分)
--    賦課TBLに存在し計算TBLに存在しない情報を作成する
--    ①最新の特徴対象者情報(ZLBTTOKU_KIHON_N)から計算TBL(ZLBTTOKU_KIHON_CAL)を作成
--    ②期割判定(ZLBFKKIWARIHT)を呼び出して特徴中止情報の作成要否を判断
--    ③特徴中止情報作成要の場合、計算特徴中止期別作成(ZLBSKCALKWTKSP)を
--      呼び出して以下の情報を作成させる。
--      《現年度》
--        計算特徴対象者情報 ZLBTTOKU_KIHON_CAL ※中止
--      《翌年度》
--        計算基本情報       ZLBTKIHON_CAL      ※年税\0
--                           ZLBTTAI_CAL        ※年税\0
--                           ZLBTKAI_KIHON_CAL  ※年税\0
--                           ZLBTKAI_TAI_CAL    ※年税\0
--                           ZLBTSIEN_KIHON_CAL ※年税\0
--                           ZLBTSIEN_TAI_CAL)  ※年税\0
--        計算期別情報       ZLBTKIBETSU_CAL    ※税額\0
--        計算特徴対象者情報 ZLBTTOKU_KIHON_CAL ※中止
--      《年度共通》
--        計算特徴異動情報   ZLBTTOKU_IDO_CAL)
-------------------------------------------------------------------------------
FUNCTION funcMakeCal_Toku(i_RKIHONN  IN ZLBTKIHON_N %ROWTYPE
                        , i_SYSDATE IN NUMBER
                        , i_SYSTIME IN NUMBER
                        ) RETURN NUMBER IS
  NwRTN             NUMBER;
  IwKIWARI_KIJUNBI  PLS_INTEGER;                  -- 期割のための基準日
  NwJIKKOU_KBN      NUMBER;                       -- 実行区分(ZLBSKCALKWTKSP)
  NwJIKKOU_KBN_KH   NUMBER;                       -- 実行区分(ZLBFKKIWARIHT)
  NwKEISAN_KBN1     NUMBER;                       -- 計算区分1
  NwKEISAN_KBN2     NUMBER;                       -- 計算区分2
  NwKEISAN_KBN3     NUMBER;                       -- 計算区分3
  NwFUTU_TUKI       NUMBER;                       -- 普徴月
  NwTOKU_TUKI       NUMBER;                       -- 特徴月
  NwYOKU_HYOUJI_KBN NUMBER;                       -- 翌年度表示区分
  VwHYOUJI_JYOUHO   NVARCHAR2(200);               -- 表示情報
  NwCHUSHI_JIYU     NUMBER;                       -- 中止事由
  NwFUTU            NUMBER;
  RwTOKU_KIHON      ZLBTTOKU_KIHON_N %ROWTYPE;  -- 特徴対象者

  -- 賦課特徴対象者カーソル
  CURSOR CwTOKU_KIHONN IS
    SELECT * FROM ZLBTTOKU_KIHON_N
     WHERE KOKU_SETAI_NO   =  i_RKIHONN.KOKU_SETAI_NO
       AND SANTEIDANTAI_CD =  i_RKIHONN.SANTEIDANTAI_CD
       AND CHOTEI_NENDO    =  i_RKIHONN.CHOTEI_NENDO
       AND NENDO_BUN       =  i_RKIHONN.NENDO_BUN
       AND TSUCHI_NO       =  i_RKIHONN.TSUCHI_NO;
BEGIN
  NwRTN := c_NOK;

  FOR RwTOKU_KIHON IN CwTOKU_KIHONN LOOP       -- 特徴対象者(最新)
    -- ①賦課TBL(ZLBTTOKU_KIHON_N)の情報から計算TBL(ZLBTTOKU_KIHON_CAL)を作成
    BEGIN
      INSERT INTO ZLBTTOKU_KIHON_CAL  VALUES(
        RwTOKU_KIHON.KOKU_SETAI_NO ,RwTOKU_KIHON.SANTEIDANTAI_CD   ,RwTOKU_KIHON.CHOTEI_NENDO     ,
        RwTOKU_KIHON.NENDO_BUN     ,RwTOKU_KIHON.R_NO + 10         ,RwTOKU_KIHON.TSUCHI_NO        ,
        RwTOKU_KIHON.HOSOKU_NENDO  ,RwTOKU_KIHON.TOKU_KOJIN_NO     ,RwTOKU_KIHON.JOTAI_KBN        ,
        RwTOKU_KIHON.KISO_NENKIN_NO,RwTOKU_KIHON.TOKU_GIMUSHA_CD   ,RwTOKU_KIHON.NENKIN_CD        ,
        RwTOKU_KIHON.KAISHI_TSUKI  ,RwTOKU_KIHON.KAISHI_KIBETSU    ,RwTOKU_KIHON.SHURYO_TSUKI     ,
        RwTOKU_KIHON.SHURYO_KIBETSU,RwTOKU_KIHON.CHUSHI_JIYU       ,RwTOKU_KIHON.KARIHENKO_KBN1   ,
        RwTOKU_KIHON.KARIHENKO_KBN2,RwTOKU_KIHON.KARIHENKO_KBN3    ,RwTOKU_KIHON.TOKU_GIMUSHA_CD_4,
        RwTOKU_KIHON.NENKIN_CD_4   ,RwTOKU_KIHON.TOKU_GIMUSHA_CD_10,RwTOKU_KIHON.NENKIN_CD_10     ,
        RwTOKU_KIHON.IRAI_HIZUKE   ,
        i_SYSDATE,                   -- 作成日
        i_SYSDATE,                   -- 更新日
        i_SYSTIME,                   -- 更新時間
        i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
        i_VMASIN_NO                  -- 端末番号
      );
    EXCEPTION
      WHEN OTHERS THEN
        NwRTN     := c_NERR;
        VlMSG := 'funcMakeCal_Toku 特徴対象者情報登録失敗' ||
                 '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                 ')' || SQLERRM;
        EXIT;
    END;
    -- ②期割判定(ZLBFKKIWARIHT)呼び出し
    -- 基準日セット
    IwKIWARI_KIJUNBI := i_NKIJUNBI;  -- 引数の基準日をそのままセット
    IF NVL(i_SHORI_NENGETSU, 0) > 0 THEN
      IF LENGTH(i_SHORI_NENGETSU) = 6 THEN
        IwKIWARI_KIJUNBI := i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
      ELSE
        IF i_SHORI_NENGETSU > 3 THEN
          -- 随時４月更正の場合
          IF TRUNC(i_NKIJUNBI, -4) / 10000 <> i_NCHOTEI_NENDO AND i_SHORI_NENGETSU = 4 THEN
            IwKIWARI_KIJUNBI := (i_NCHOTEI_NENDO + 1) * 10000 + i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
          ELSE
            IwKIWARI_KIJUNBI := i_NCHOTEI_NENDO * 10000 + i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
          END IF;
        ELSE
          IwKIWARI_KIJUNBI := (i_NCHOTEI_NENDO + 1) * 10000 + i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
        END IF;
      END IF;
      IF LENGTH(IwKIWARI_KIJUNBI) != 8 THEN
        IwKIWARI_KIJUNBI := i_NKIJUNBI;  -- 西暦８桁ない場合は、引数の基準日をそのままセット
      END IF;
    END IF;
    -- 実行区分をセット
    IF i_NJIKKOU_KBN = c_NBATCH AND i_NNOUKI_KBN = c_NNOUKI_HONSAN THEN
      NwJIKKOU_KBN_KH := c_KH_BTHONSAN;   -- バッチ起動 本算定
    ELSIF i_NJIKKOU_KBN = c_NONLNIN THEN
      NwJIKKOU_KBN_KH := c_KH_ONLINE;     -- オンライン起動
    ELSE
      NwJIKKOU_KBN_KH := c_KH_BTGETSU;    -- バッチ起動 月例
    END IF;

    NwRTN := ZLBFKKIWARIHT (i_RKIHONN.KOKU_SETAI_NO,     -- 国保世帯番号
                               i_RKIHONN.SANTEIDANTAI_CD,   -- 算定団体コード
                               i_RKIHONN.CHOTEI_NENDO,      -- 調定年度
                               i_RKIHONN.NENDO_BUN,         -- 年度分
                               i_RKIHONN.TSUCHI_NO,         -- 通知書番号
                               IwKIWARI_KIJUNBI,          -- 処理日
                               NwJIKKOU_KBN_KH,           -- 実行区分
                               i_VMASIN_NO,               -- 端末番号
                               i_NTRENBAN,                -- 登録連番
                               NwKEISAN_KBN1,             -- 計算区分1
                               NwKEISAN_KBN2,             -- 計算区分2
                               NwKEISAN_KBN3,             -- 計算区分3
                               NwFUTU_TUKI,               -- 普徴月
                               NwTOKU_TUKI,               -- 特徴月
                               NwYOKU_HYOUJI_KBN,         -- 翌年度表示区分
                               VwHYOUJI_JYOUHO,           -- 表示情報
                               NwCHUSHI_JIYU);            -- 中止事由
    IF NwRTN != c_NOK THEN
      NwRTN := c_NERR;
      VlMSG := 'funcMakeCal_Toku 期割判定' ||
               '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
               ')ZLBFKKIWARIHT:失敗';
      EXIT;
    END IF;

    IF NwKEISAN_KBN1 <> c_NKEISAN_KBN_3 THEN
      -- 特徴中止時のみ③実行
      EXIT;
    END IF;

    -- ③計算特徴中止期別作成(ZLBSKCALKWTKSP)呼び出し
    -- 実行区分をセット
    IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
      NwJIKKOU_KBN := c_NBATCH;
    ELSE
      NwJIKKOU_KBN := i_NJIKKOU_KBN;
    END IF;

    ZLBSKCALKWTKSP (i_RKIHONN.TSUCHI_NO,             -- 通知書番号
                           i_RKIHONN.CHOTEI_NENDO,          -- 年度
                           i_RKIHONN.NENDO_BUN,             -- 年度分
                           IwKIWARI_KIJUNBI,              -- 処理日
                           i_RKIHONN.SANTEIDANTAI_CD,       -- 算定団体コード
                           i_RKIHONN.KOKU_SETAI_NO,         -- 国保世帯番号
                           NwJIKKOU_KBN,                  -- 実行区分
                           NwTOKU_TUKI,                   -- 特徴月
                           NwCHUSHI_JIYU,                 -- 中止事由
                           i_VMASIN_NO,                   -- 端末NO
                           i_NTRENBAN,                    -- 登録連番
                           NwFUTU,                        -- 普徴期割実施区分
                           NwRTN,                         -- 戻り値
                           i_NKIJUNBI);                   -- 更正日
    IF NwRTN != c_NOK THEN
      NwRTN := c_NERR;
      VlMSG := 'funcMakeCal_Toku 特徴中止' ||
               '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
               ')ZLBSKCALKWTKSP:失敗';
    END IF;

    EXIT;
  END LOOP;

  RETURN(NwRTN);
EXCEPTION
  WHEN OTHERS THEN
    NwRTN := c_NERR;
    VlMSG := 'funcMakeCal_Toku 国保世帯番号 ' || i_RKIHONN.KOKU_SETAI_NO || ' ' || SQLERRM;
    RETURN(NwRTN);
END funcMakeCal_Toku;

------------------------------------------------------------------------------
--  合併年度取得
------------------------------------------------------------------------------
FUNCTION FUNCGETGAPPEIBI(I_KIJUNBI IN PLS_INTEGER) RETURN PLS_INTEGER IS
  BRTN        BOOLEAN := TRUE;
  IRTN        PLS_INTEGER;
  N_GAPPEIBI  PLS_INTEGER := 0;
  V_DAMMY1    NVARCHAR2(200);
  V_DAMMY2    NVARCHAR2(200);
  V_DAMMY3    NVARCHAR2(200);
  V_DAMMY4    NVARCHAR2(200);
  V_DAMMY5    NVARCHAR2(200);
  V_DAMMY6    NVARCHAR2(200);
  V_DAMMY7    NVARCHAR2(200);
  V_DAMMY8    NVARCHAR2(200);
  V_DAMMY9    NVARCHAR2(200);
  V_DAMMY10   NVARCHAR2(200);
  V_DAMMY11   NVARCHAR2(200);
  V_DAMMY12   NVARCHAR2(200);
  V_DAMMY13   NVARCHAR2(200);
  V_DAMMY14   NVARCHAR2(200);
  V_DAMMY15   NVARCHAR2(200);
  V_DAMMY16   NVARCHAR2(200);
  V_DAMMY17   NVARCHAR2(200);
  V_DAMMY18   NVARCHAR2(200);
  V_DAMMY19   NVARCHAR2(200);
  V_DAMMY20   NVARCHAR2(200);
  V_DAMMY21   NVARCHAR2(200);
  V_DAMMY22   NVARCHAR2(200);
  V_DAMMY23   NVARCHAR2(200);
  N_DAMMY1    PLS_INTEGER;
  N_DAMMY2    PLS_INTEGER;
  N_DAMMY3    PLS_INTEGER;
  N_DAMMY4    PLS_INTEGER;
  N_DAMMY5    PLS_INTEGER;
  N_DAMMY6    PLS_INTEGER;
  N_DAMMY7    PLS_INTEGER;
  N_DAMMY8    PLS_INTEGER;
  N_DAMMY9    PLS_INTEGER;
  L_DAMMY1    BLOB;
  L_DAMMY2    BLOB;
  L_DAMMY3    BLOB;
  L_DAMMY4    BLOB;
  L_DAMMY5    BLOB;
  L_DAMMY6    BLOB;
  MAAPFDAYEDIT  MTAAPFDAYEDIT;
BEGIN
  IRTN := KKAPK0030.FKYOTU(I_KIJUNBI, N_DAMMY1, N_DAMMY3, N_GAPPEIBI, N_DAMMY4, V_DAMMY2, V_DAMMY3, V_DAMMY4,
                           V_DAMMY1, V_DAMMY5,  V_DAMMY8,  V_DAMMY9,   V_DAMMY10);
  --日付編集（外部）
  MAAPFDAYEDIT.ISEIREKI_YYYY := KKAPK0020.FDAYNENDO(N_GAPPEIBI,1);

  RETURN(MAAPFDAYEDIT.ISEIREKI_YYYY);
END FUNCGETGAPPEIBI;
-------------------------------------------------------------------------------
-- 15-2 各算定団体の過年度課税計算対象年度の判定
-------------------------------------------------------------------------------
    FUNCTION funcChkNendo(i_NwKOKU_SETAI_NO IN NUMBER,  -- 国保世帯番号
                          i_NwDANTAI IN NUMBER,         -- 算定団体コード
                          i_NwCHOTEI_NENDO IN NUMBER,   -- 調定年度
                          i_NwNENDO_BUN IN NUMBER,      --年度分
                          i_NwTSUCHI_NO IN NUMBER       --通知書番号
                         ) RETURN NUMBER IS

        NwKANENDO_TAISHO_ZO     NUMBER;  -- 増額対象年数
        NwKANENDO_TAISHO_GEN    NUMBER;  -- 減額対象年数
        NwRtn                   NUMBER;  -- 0:OK,1:対象外,9:NG
        NwCNT                   NUMBER;  --調定年度≠年度分で税額減件数--
    BEGIN
        -- 初期値
        NwRtn := 1;
        NwKANENDO_TAISHO_ZO := 0;
        NwKANENDO_TAISHO_GEN := 0;

        BEGIN
            -- システム条件を調定年度(引数),最小算定団体コードで読込み
            SELECT KANENDO_TAISHO_ZO,  KANENDO_TAISHO_GEN
              INTO NwKANENDO_TAISHO_ZO,NwKANENDO_TAISHO_GEN
              FROM ZLBTJOKEN
             WHERE NENDO           = i_NCHOTEI_NENDO -- 引数の調定年度
               AND SANTEIDANTAI_CD = i_NwDANTAI;
        EXCEPTION
            WHEN OTHERS THEN
              RETURN(c_NERR);
        END;

        IF i_NwCHOTEI_NENDO = i_NwNENDO_BUN THEN
            -- 減の場合(現在の調定年度と比較する）
            IF i_NwNENDO_BUN + NwKANENDO_TAISHO_GEN >= i_NCHOTEI_NENDO THEN
                NwRtn := c_NOK;
            END IF;
        ELSE
            -- 調定年度≠年度分で税額減になる件数を取得する
            BEGIN
                SELECT COUNT(*) INTO NwCNT
                FROM
                      (SELECT KAMOKU_CD,
                              KOKU_SETAI_NO,
                              SANTEIDANTAI_CD,
                              CHOTEINENDO,
                              NENDOBUN,
                              TSUCHI_NO,
                              SUM(ZEN_ZEIGAKU) ZEN_ZEIGAKU,
                              SUM(TAI_ZEIGAKU) TAI_ZEIGAKU
                       FROM   ZLBTKIBETSU_N
                       WHERE  KAMOKU_CD       = c_NKAMOKU_CD
                         AND  KOKU_SETAI_NO   = i_NwKOKU_SETAI_NO
                         AND  SANTEIDANTAI_CD = i_NwDANTAI
                         AND  CHOTEINENDO     = i_NwCHOTEI_NENDO
                         AND  NENDOBUN        = i_NwNENDO_BUN
                         AND  TSUCHI_NO       = i_NwTSUCHI_NO
                       GROUP  BY
                              KAMOKU_CD,
                              KOKU_SETAI_NO,
                              SANTEIDANTAI_CD,
                              CHOTEINENDO,
                              NENDOBUN,
                              TSUCHI_NO) A,
                      (SELECT KAMOKU_CD,
                              KOKU_SETAI_NO,
                              SANTEIDANTAI_CD,
                              CHOTEINENDO,
                              NENDOBUN,
                              TSUCHI_NO,
                              SUM(ZEN_ZEIGAKU) ZEN_ZEIGAKU,
                              SUM(TAI_ZEIGAKU) TAI_ZEIGAKU
                       FROM   ZLBTKIBETSU_CAL
                       WHERE  KAMOKU_CD       = c_NKAMOKU_CD
                         AND  KOKU_SETAI_NO   = i_NwKOKU_SETAI_NO
                         AND  SANTEIDANTAI_CD = i_NwDANTAI
                         AND  CHOTEINENDO     = i_NwCHOTEI_NENDO
                         AND  NENDOBUN        = i_NwNENDO_BUN
                         AND  TSUCHI_NO       = i_NwTSUCHI_NO
                       GROUP  BY
                              KAMOKU_CD,
                              KOKU_SETAI_NO,
                              SANTEIDANTAI_CD,
                              CHOTEINENDO,
                              NENDOBUN,
                              TSUCHI_NO) B
                WHERE  A.KAMOKU_CD       = B.KAMOKU_CD
                  AND  A.SANTEIDANTAI_CD = B.SANTEIDANTAI_CD
                  AND  A.CHOTEINENDO     = B.CHOTEINENDO
                  AND  A.NENDOBUN        = B.NENDOBUN
                  AND  A.TSUCHI_NO       = B.TSUCHI_NO
                  AND  A.KOKU_SETAI_NO   = B.KOKU_SETAI_NO
                  AND (A.ZEN_ZEIGAKU     > B.ZEN_ZEIGAKU
                   OR  A.TAI_ZEIGAKU     > B.TAI_ZEIGAKU);
            EXCEPTION
                WHEN OTHERS THEN
                   NwCNT := 0;
            END;
            IF NwCNT > 0 THEN
                -- 減の場合(現在の調定年度と比較する）
                IF i_NwNENDO_BUN + NwKANENDO_TAISHO_GEN >= i_NCHOTEI_NENDO THEN
                    NwRtn := c_NOK;
                END IF;
            ELSE
                -- 増の場合(現在の調定年度と比較する）
                IF i_NwNENDO_BUN + NwKANENDO_TAISHO_ZO >= i_NCHOTEI_NENDO THEN
                    NwRtn := c_NOK;
                END IF;
            END IF;
        END IF;

        RETURN(NwRtn);
    EXCEPTION
        WHEN OTHERS THEN
            NwRtn := c_NERR;
            VlMSG := 'funcChkNendo 国保世帯番号 ' || i_NwKOKU_SETAI_NO || ' ' || SQLERRM;
            RETURN(NwRtn);
    END funcChkNendo;
-------------------------------------------------------------------------------
-- 20 各計算TBLの更新(作成日/更新日/時間/職員番号)
-------------------------------------------------------------------------------
    PROCEDURE subDateUpdate IS

        NwDATE          NUMBER;
        NwTIME          NUMBER;
        NwCNT           NUMBER;

      -- 計算拡張ｶｰｿﾙ
      CURSOR CwEXT IS
        SELECT *
        FROM ZLBTEXT_CAL
          WHERE  SYS_TANMATSU_NO = i_VMASIN_NO;

    BEGIN

        NwDATE := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        NwTIME := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MIDD'));

        -- 計算基本
        UPDATE ZLBTKIHON_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                 SYS_KOSHINBI        = NwDATE,
                                 SYS_JIKAN           = NwTIME,
                                 SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算退職
        UPDATE ZLBTTAI_CAL SET SYS_SAKUSEIBI       = NwDATE,
                               SYS_KOSHINBI        = NwDATE,
                               SYS_JIKAN           = NwTIME,
                               SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算介護基本
        UPDATE ZLBTKAI_KIHON_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                     SYS_KOSHINBI        = NwDATE,
                                     SYS_JIKAN           = NwTIME,
                                     SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算介護退職
        UPDATE ZLBTKAI_TAI_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                   SYS_KOSHINBI        = NwDATE,
                                   SYS_JIKAN           = NwTIME,
                                   SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算支援基本
        UPDATE ZLBTSIEN_KIHON_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                      SYS_KOSHINBI        = NwDATE,
                                      SYS_JIKAN           = NwTIME,
                                      SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算支援退職
        UPDATE ZLBTSIEN_TAI_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                    SYS_KOSHINBI        = NwDATE,
                                    SYS_JIKAN           = NwTIME,
                                    SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
        -- 計算子ども基本
        UPDATE ZLBTKDM_KIHON_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                     SYS_KOSHINBI        = NwDATE,
                                     SYS_JIKAN           = NwTIME,
                                     SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
        -- 計算個人
        UPDATE ZLBTKOJIN_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                 SYS_KOSHINBI        = NwDATE,
                                 SYS_JIKAN           = NwTIME,
                                 SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算期別
        UPDATE ZLBTKIBETSU_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                   SYS_KOSHINBI        = NwDATE,
                                   SYS_JIKAN           = NwTIME,
                                   SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算所得
        UPDATE ZLBTSHOTOKU_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                   SYS_KOSHINBI        = NwDATE,
                                   SYS_JIKAN           = NwTIME,
                                   SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算拡張
        UPDATE ZLBTEXT_CAL SET SYS_SAKUSEIBI       = NwDATE,
                               SYS_KOSHINBI        = NwDATE,
                               SYS_JIKAN           = NwTIME,
                               SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算異動
        UPDATE ZLBTTOKU_IDO_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                    SYS_KOSHINBI        = NwDATE,
                                    SYS_JIKAN           = NwTIME,
                                    SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算特徴対象者
        UPDATE ZLBTTOKU_KIHON_CAL SET SYS_SAKUSEIBI       = NwDATE,
                                      SYS_KOSHINBI        = NwDATE,
                                      SYS_JIKAN           = NwTIME,
                                      SYS_SHOKUINKOJIN_NO = i_NSYS_SHOKUINKOJIN_NO
         WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 計算減免個人
        BEGIN
          vSQL := 'UPDATE ZLBTGENMEN_KOJIN_CAL SET SYS_SAKUSEIBI       = ' || NwDATE || ',' ||
                                                  'SYS_KOSHINBI        = ' || NwDATE || ',' ||
                                                  'SYS_JIKAN           = ' || NwTIME || ',' ||
                                                  'SYS_SHOKUINKOJIN_NO = ' || i_NSYS_SHOKUINKOJIN_NO || ' ' ||
                  'WHERE SYS_TANMATSU_NO = ''' || i_VMASIN_NO || '''';
          EXECUTE IMMEDIATE vSQL;
        EXCEPTION
          WHEN OTHERS THEN
            -- テーブルがないことも考えられるので、エラーにはしない。
            NULL;
        END;

        --計算拡張ＴＢＬの項番7～17までが全て0なら削除
        FOR RwEXT IN CwEXT LOOP
          IF  RwEXT.SHOGAI_SHOTOKU       = 0 AND
              RwEXT.SHOGAI_RITSU         = 0 AND
              RwEXT.GENMEN_KBN           = 0 AND
              RwEXT.GENMEN_RITSU         = 0 AND
              RwEXT.IRYO_NENREI_KEIGEN   = 0 AND
              RwEXT.IRYO_SHOGAI_GENMEN   = 0 AND
              RwEXT.IRYO_NENREI_KEIGEN_T = 0 AND
              RwEXT.IRYO_SHOGAI_GENMEN_T = 0 AND
              RwEXT.KAI_NENREI_KEIGEN    = 0 AND
              RwEXT.KAI_SHOGAI_GENMEN    = 0 AND
              RwEXT.KAI_NENREI_KEIGEN_T  = 0 AND
              RwEXT.KAI_SHOGAI_GENMEN_T  = 0 AND
              RwEXT.SHI_NENREI_KEIGEN   = 0 AND
              RwEXT.SHI_SHOGAI_GENMEN   = 0 AND
              RwEXT.SHI_NENREI_KEIGEN_T = 0 AND
              RwEXT.SHI_SHOGAI_GENMEN_T = 0 AND
              RwEXT.IRYO_KEIKA_H_SHOTOKU      = 0 AND
              RwEXT.IRYO_KEIKA_H_SHOTOKU_T    = 0 AND
              RwEXT.KAI_KEIKA_H_SHOTOKU       = 0 AND
              RwEXT.KAI_KEIKA_H_SHOTOKU_T     = 0 AND
              RwEXT.SIEN_KEIKA_H_SHOTOKU      = 0 AND
              RwEXT.SIEN_KEIKA_H_SHOTOKU_T    = 0 AND
              RwEXT.IRYO_KEIKA_H_SHISAN       = 0 AND
              RwEXT.IRYO_KEIKA_H_SHISAN_T     = 0 AND
              RwEXT.KAI_KEIKA_H_SHISAN        = 0 AND
              RwEXT.KAI_KEIKA_H_SHISAN_T      = 0 AND
              RwEXT.SIEN_KEIKA_H_SHISAN       = 0 AND
              RwEXT.SIEN_KEIKA_H_SHISAN_T     = 0 AND
              RwEXT.IRYO_KEIKA_H_KINTOWARI    = 0 AND
              RwEXT.IRYO_KEIKA_H_KINTOWARI_T  = 0 AND
              RwEXT.KAI_KEIKA_H_KINTOWARI     = 0 AND
              RwEXT.KAI_KEIKA_H_KINTOWARI_T   = 0 AND
              RwEXT.SIEN_KEIKA_H_KINTOWARI    = 0 AND
              RwEXT.SIEN_KEIKA_H_KINTOWARI_T  = 0 AND
              RwEXT.IRYO_KEIKA_BYODOWARI    = 0 AND
              RwEXT.IRYO_KEIKA_BYODOWARI_T  = 0 AND
              RwEXT.KAI_KEIKA_BYODOWARI     = 0 AND
              RwEXT.KAI_KEIKA_BYODOWARI_T   = 0 AND
              RwEXT.SIEN_KEIKA_BYODOWARI    = 0 AND
              RwEXT.SIEN_KEIKA_BYODOWARI_T  = 0
          AND RwEXT.H_KBN  = 0
          AND NVL(RwEXT.NEW_KODOMO_CNT,0) = 0
          AND NVL(RwEXT.F4_KODOMO_CNT,0) = 0
          AND NVL(RwEXT.FUKA_KODOMO_CNT,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_4,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_5,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_6,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_7,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_8,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_9,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_10,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_11,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_12,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_1,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_2,0) = 0
          AND NVL(RwEXT.KODOMO_CNT_3,0) = 0
          AND NVL(RwEXT.IRYO_KEIGEN_K_KINTOWARI,0) = 0
          AND NVL(RwEXT.IRYO_KEIGEN_K_KINTOWARI_T,0) = 0
          AND NVL(RwEXT.SIEN_KEIGEN_K_KINTOWARI,0) = 0
          AND NVL(RwEXT.SIEN_KEIGEN_K_KINTOWARI_T,0) = 0
          --  2024/05/07 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
          AND NVL(RwEXT.SAN_IRYO_GEN_K_KEI,0) = 0
          AND NVL(RwEXT.SAN_IRYO_GEN_S_KEI,0) = 0
          AND NVL(RwEXT.SAN_KAI_GEN_K_KEI,0) = 0
          AND NVL(RwEXT.SAN_KAI_GEN_S_KEI,0) = 0
          AND NVL(RwEXT.SAN_SIEN_GEN_K_KEI,0) = 0
          AND NVL(RwEXT.SAN_SIEN_GEN_S_KEI,0) = 0
          --  2024/05/07 ZCZL.ZHANGLEI ADD END
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
          AND RwEXT.KDM_NENREI_KEIGEN = 0
          AND RwEXT.KDM_SHOGAI_GENMEN = 0
          AND RwEXT.KDM_KEIKA_H_SHOTOKU = 0
          AND RwEXT.KDM_KEIKA_H_SHISAN = 0
          AND RwEXT.KDM_KEIKA_H_KINTOWARI = 0
          AND RwEXT.KDM_KEIKA_BYODOWARI = 0
          AND RwEXT.KDM_KEIGEN_K_KINTOWARI = 0
          AND NVL(RwEXT.KDM_SAN_GEN_K_KEI, 0) = 0
          AND NVL(RwEXT.KDM_SAN_GEN_S_KEI, 0) = 0
          AND NVL(RwEXT.NEW_KDM18_CNT, 0) = 0
          AND NVL(RwEXT.KDM18_F4_CNT, 0) = 0
          AND NVL(RwEXT.KDM18_FUKA_CNT, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_4, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_5, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_6, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_7, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_8, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_9, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_10, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_11, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_12, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_1, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_2, 0) = 0
          AND NVL(RwEXT.KDM18_CNT_3, 0) = 0
          AND NVL(RwEXT.KDM18_KEIGEN_KINTOWARI, 0) = 0
          AND NVL(RwEXT.NEW_KDM18UN_CNT, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_4, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_5, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_6, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_7, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_8, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_9, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_10, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_11, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_12, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_1, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_2, 0) = 0
          AND NVL(RwEXT.KDM18UN_CNT_3, 0) = 0
          AND NVL(RwEXT.KDM18UN_KEIGEN_KINTOWARI, 0) = 0
--2025/08/11 ZCZL.LIUHUAJUN ADD END
          THEN

            -- 前履歴にH_KBN > 0が存在するか
            SELECT COUNT(*) INTO NwCNT
            FROM   ZLBTEXT_N
            WHERE  KOKU_SETAI_NO   = RwEXT.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwEXT.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO    = RwEXT.CHOTEI_NENDO
              AND  NENDO_BUN       = RwEXT.NENDO_BUN
              AND  TSUCHI_NO       = RwEXT.TSUCHI_NO
              AND  H_KBN           > 0;
            -- 存在しない場合のみ削除する
            IF NwCNT = 0 THEN
              -- 計算拡張ＴＢＬデータを削除
              DELETE FROM ZLBTEXT_CAL
                WHERE KOKU_SETAI_NO   = RwEXT.KOKU_SETAI_NO
                  AND SANTEIDANTAI_CD = RwEXT.SANTEIDANTAI_CD
                  AND CHOTEI_NENDO    = RwEXT.CHOTEI_NENDO
                  AND NENDO_BUN       = RwEXT.NENDO_BUN
                  AND TSUCHI_NO       = RwEXT.TSUCHI_NO
                  AND SYS_TANMATSU_NO = RwEXT.SYS_TANMATSU_NO;
            END IF;
          END IF;
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subDateUpdate システム項目更新' ||
                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                     ')' || SQLERRM;
    END subDateUpdate;
-------------------------------------------------------------------------------
-- 19 各中間TBLの更新
--      即時の場合は未使用
-------------------------------------------------------------------------------
    PROCEDURE subUpdate(i_NKOKU_SETAI_NO IN NUMBER) IS
        NNEDO_HOUHOU  NUMBER;      --過年度一括計算方法
        -- 計算基本ｶｰｿﾙ
        CURSOR CwKIHON IS
            SELECT * FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO;

        NlRTN NUMBER;
        BTOKU_IDO_FLG BOOLEAN := FALSE;

    BEGIN
        --市区町村条件の”過年度一括計算方法”を取得する
        NNEDO_HOUHOU := ZLBPK00010.FCFFJKN2(402);
        FOR RwKIHON IN CwKIHON LOOP
            --過年度課税計算バッチメインからの起動の場合
            IF NlGENKA_KBN = c_NKANEN AND i_NJIKKOU_KBN = 0 AND NNEDO_HOUHOU = 1 THEN
              --法廷納期限計算処理(ZLBSKCALNOKIGN)の呼出
              ZLBSKCALNOKIGN(RwKIHON.KOKU_SETAI_NO,   --国保世帯番号
                             RwKIHON.SANTEIDANTAI_CD, --算定団体コード
                             RwKIHON.CHOTEI_NENDO,    --調定年度
                             RwKIHON.NENDO_BUN,       --年度分
                             RwKIHON.TSUCHI_NO,       --通知書番号
                             RwKIHON.NUSHI_KOJIN_NO,  --世帯主個人番号
                             i_TOTATSU_BI,            --納通到達日（西暦）
                             i_NKIJUNBI,              --基準日（西暦）
                             i_NTRENBAN,              --登録連番
                             i_VMASIN_NO,             --端末番号
                             NlRTN                    --リターンコード
                             );
              IF NlRTN = c_NERR THEN
                  EXIT;
              END IF;
            ELSE
              -- 過年度の時だけ
              IF NlGENKA_KBN = c_NKANEN THEN
                -- 過年度計算対象年度を判定
                NlRTN := funcChkNendo(RwKIHON.KOKU_SETAI_NO,
                                      RwKIHON.SANTEIDANTAI_CD,
                                      RwKIHON.CHOTEI_NENDO,
                                      RwKIHON.NENDO_BUN,
                                      RwKIHON.TSUCHI_NO);
                IF NlRTN = c_NERR THEN
                    EXIT;
                END IF;
              ELSE
                NlRTN := c_NOK;
              END IF;
            END IF;
          IF NlRTN = c_NOK THEN

            BEGIN
                -- 中間基本登録
                INSERT INTO ZLBTKIHON_MID
                    (SELECT * FROM ZLBTKIHON_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間基本登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;

            BEGIN
                -- 中間退職登録
                INSERT INTO ZLBTTAI_MID
                    (SELECT * FROM ZLBTTAI_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間退職登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;

            BEGIN
                -- 中間介護基本登録
                INSERT INTO ZLBTKAI_KIHON_MID
                    (SELECT * FROM ZLBTKAI_KIHON_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間介護基本登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;

            BEGIN
                -- 中間介護退職登録
                INSERT INTO ZLBTKAI_TAI_MID
                    (SELECT * FROM ZLBTKAI_TAI_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間介護退職登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;

            BEGIN
                -- 中間支援基本登録
                INSERT INTO ZLBTSIEN_KIHON_MID
                    (SELECT * FROM ZLBTSIEN_KIHON_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間支援基本登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;

            BEGIN
                -- 中間支援退職登録
                INSERT INTO ZLBTSIEN_TAI_MID
                    (SELECT * FROM ZLBTSIEN_TAI_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間支援退職登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;

--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
            BEGIN
                -- 中間子ども基本登録
                INSERT INTO ZLBTKDM_KIHON_MID
                    (SELECT * FROM ZLBTKDM_KIHON_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間子ども基本登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
            BEGIN
                -- 中間個人登録
                INSERT INTO ZLBTKOJIN_MID
                    (SELECT KOKU_SETAI_NO, KOJIN_NO, SANTEIDANTAI_CD,
                            CHOTEI_NENDO, NENDO_BUN, R_NO, TSUCHI_NO,
                            NEW_SHIK_KBN, NEW_KAI_SHIK_KBN, NEW_TAI_KBN,
                            F4_SHIK_KBN, F4_KAI_KBN, F4_TAI_KBN, FUKA_SHIK_KBN,
                            FUKA_KAI_KBN, KEIGEN_HANT_KBN, SHIK_4, SHIK_5,
                            SHIK_6, SHIK_7, SHIK_8, SHIK_9, SHIK_10, SHIK_11,
                            SHIK_12, SHIK_1, SHIK_2, SHIK_3, KAI_SHIK_4,
                            KAI_SHIK_5, KAI_SHIK_6, KAI_SHIK_7, KAI_SHIK_8,
                            KAI_SHIK_9, KAI_SHIK_10, KAI_SHIK_11, KAI_SHIK_12,
                            KAI_SHIK_1, KAI_SHIK_2, KAI_SHIK_3, SHOTOKU,
                            KAHYO, SHOTOKU_WARI, KAI_SHOTOKU_WARI, SIEN_SHOTOKU_WARI, KEIGEN_SHOTOKU,
                            SHISANZEI, SHISAN_WARI, KAI_SHISAN_WARI, SIEN_SHISAN_WARI, SENJU_KBN,
                            RONEN_KBN, SHINKOKU_KBN, SHU_SHOTOKU_KBN, J_KAZEI_KBN,
                            J_SHOTOKU_WARI, J_KINTO_WARI, NEW_SHUTOK_BI,
                            NEW_SOSHITSU_BI, NEW_ZOKU, KAI_GAI_BI, KAI_HIGAI_BI,
                            TANJO_65, KOSEI_BI, JIYU, KAI_KOSEI_BI, KAI_JIYU,
                            KEIGEN_BI, SEKISAN_GAI_KBN, KOJIN_NENZEI, ZOKU_NAME,
                            SHIK_R_NO, SYS_SAKUSEIBI, SYS_KOSHINBI, SYS_JIKAN,
                            SYS_SHOKUINKOJIN_NO, SYS_TANMATSU_NO,
                            CUST_1, CUST_2, CUST_3
                           ,NEW_SHITSU_KBN, F4_SHITSU_KBN, SHITSU_4, SHITSU_5,
                            SHITSU_6, SHITSU_7, SHITSU_8, SHITSU_9, SHITSU_10,
                            SHITSU_11, SHITSU_12, SHITSU_1, SHITSU_2, SHITSU_3,
                            SHITSU_GAI_BI, SHITSU_HIGAI_BI, SHITSU_SHOTOKU,
                            SHITSU_KAHYO, SHITSU_KEIGEN_SHOTOKU
                           ,KYUYO_SHOTOKU_KBN
                           --  2024/05/07 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                           ,NEW_SAN_KBN, F4_SAN_KBN
                           ,SAN_4, SAN_5, SAN_6, SAN_7, SAN_8, SAN_9
                           ,SAN_10, SAN_11, SAN_12, SAN_1, SAN_2, SAN_3
                           ,SAN_GAI_BI, SAN_HIGAI_BI
                           ,SAN_IRYO_GEN_KINTO, SAN_IRYO_GEN_SHOTOKU
                           ,SAN_KAI_GEN_KINTO, SAN_KAI_GEN_SHOTOKU
                           ,SAN_SIEN_GEN_KINTO, SAN_SIEN_GEN_SHOTOKU
                           --  2024/05/07 ZCZL.ZHANGLEI ADD END
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                           , KDM_18_KBN, KDM_SHOTOKU_WARI, KDM_SHISAN_WARI
                           , KDM_KEIGEN_KITO, KDM_KEIGEN_KITO18
                           , KDM_SAN_GEN_KINTO, KDM_SAN_GEN_SHOTOKU
                           , KDM_SAN_GEN_KINTO18, KDM18UN_KEIGEN_KITO
--2025/08/11 ZCZL.LIUHUAJUN ADD END
-- 2025/12/02 ZCZL.LIUYANG ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
                           , KDM_KODOMO_KEIGEN_KITO       -- 子ども均等割軽減額（未就学児）
                           , KDM_KINTO                    -- 子ども均等割額
                           , KDM_KINTO18                  -- 子ども18歳以上均等割額
-- 2025/12/02 ZCZL.LIUYANG ADD END
                       FROM ZLBTKOJIN_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間個人登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;

            BEGIN
                -- 中間期別登録
                INSERT INTO ZLBTKIBETSU_MID
                    (SELECT * FROM ZLBTKIBETSU_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEINENDO     = RwKIHON.CHOTEI_NENDO
                        AND NENDOBUN        = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間期別登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;

            BEGIN
                -- 中間所得登録
                INSERT INTO ZLBTSHOTOKU_MID
                    (SELECT * FROM ZLBTSHOTOKU_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間個人/期別/所得登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 中間拡張登録
                INSERT INTO ZLBTEXT_MID
                    (SELECT * FROM ZLBTEXT_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間拡張登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;

            IF BTOKU_IDO_FLG = FALSE THEN

            BEGIN
                -- 中間異動登録
                INSERT INTO ZLBTTOKU_IDO_MID
                    (SELECT * FROM ZLBTTOKU_IDO_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND KOJIN_NO        = RwKIHON.NUSHI_KOJIN_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
               BTOKU_IDO_FLG := TRUE;

            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間異動登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;
            END IF;

            BEGIN
                -- 中間特徴対象者登録
                INSERT INTO ZLBTTOKU_KIHON_MID
                    (SELECT * FROM ZLBTTOKU_KIHON_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate 中間特徴対象者登録' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 中間減免個人登録
                vSQL := 'INSERT INTO ZLBTGENMEN_KOJIN_MID'      ||
                        ' SELECT * FROM ZLBTGENMEN_KOJIN_CAL'   ||
                         ' WHERE KOKU_SETAI_NO   = '   || RwKIHON.KOKU_SETAI_NO   ||
                           ' AND SANTEIDANTAI_CD = '   || RwKIHON.SANTEIDANTAI_CD ||
                           ' AND NENDO_BUN       = '   || RwKIHON.NENDO_BUN       ||
                           ' AND SYS_TANMATSU_NO = ''' || i_VMASIN_NO || '''';
                EXECUTE IMMEDIATE vSQL;
            EXCEPTION
                WHEN OTHERS THEN
                    -- テーブルがないことも考えられるので、エラーにはしない。
                    NULL;
            END;

          END IF;
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subUpdate 計算基本取得' ||
                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                     ')' || SQLERRM;
    END subUpdate;

-------------------------------------------------------------------------------
--  中間異動TBLの更新
-------------------------------------------------------------------------------
    PROCEDURE subUpdate2(i_NKOKU_SETAI_NO IN NUMBER) IS

        -- 計算基本ｶｰｿﾙ
        CURSOR CwKIHON IS
            SELECT * FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO;

        NlRTN NUMBER;
    BEGIN

        FOR RwKIHON IN CwKIHON LOOP

          BEGIN
              -- 中間基本登録
              INSERT INTO ZLBTTOKU_KIHON_MID
                  (SELECT * FROM ZLBTTOKU_KIHON_CAL
                    WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                      AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                      AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                      AND NENDO_BUN       = RwKIHON.NENDO_BUN
                      AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                      AND SYS_TANMATSU_NO = i_VMASIN_NO);
          EXCEPTION
              WHEN OTHERS THEN
                  NlRTN := c_NERR;
                  VlMSG := 'subUpdate2 中間異動登録' ||
                           '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                           ')' || SQLERRM;
                  EXIT;
          END;

        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subUpdate2 計算基本取得' ||
                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                     ')' || SQLERRM;
    END subUpdate2;

-------------------------------------------------------------------------------
-- 19 各課税状況用TBLの更新
-------------------------------------------------------------------------------
    PROCEDURE subUpdate_KJ(i_NKOKU_SETAI_NO IN NUMBER) IS
        -- 計算基本ｶｰｿﾙ
        CURSOR CwKIHON IS
            SELECT * FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO;
    BEGIN
        FOR RwKIHON IN CwKIHON LOOP
            BEGIN
                -- 課税状況用基本登録
                INSERT INTO ZLBTKIHON_KJ
                    (SELECT * FROM ZLBTKIHON_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用基本登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 課税状況用退職登録
                INSERT INTO ZLBTTAI_KJ
                    (SELECT * FROM ZLBTTAI_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用退職登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 課税状況用介護基本登録
                INSERT INTO ZLBTKAI_KIHON_KJ
                    (SELECT * FROM ZLBTKAI_KIHON_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用介護基本登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 課税状況用介護退職登録
                INSERT INTO ZLBTKAI_TAI_KJ
                    (SELECT * FROM ZLBTKAI_TAI_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用介護退職登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 課税状況用支援基本登録
                INSERT INTO ZLBTSIEN_KIHON_KJ
                    (SELECT * FROM ZLBTSIEN_KIHON_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用支援基本登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 課税状況用支援退職登録
                INSERT INTO ZLBTSIEN_TAI_KJ
                    (SELECT * FROM ZLBTSIEN_TAI_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用支援退職登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
            BEGIN
                -- 課税状況用子ども基本登録
                INSERT INTO ZLBTKDM_KIHON_KJ
                    (SELECT * FROM ZLBTKDM_KIHON_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用子ども登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
            BEGIN
                -- 課税状況用個人登録
                INSERT INTO ZLBTKOJIN_KJ
                    (SELECT KOKU_SETAI_NO, KOJIN_NO, SANTEIDANTAI_CD,
                            CHOTEI_NENDO, NENDO_BUN, R_NO, TSUCHI_NO,
                            NEW_SHIK_KBN, NEW_KAI_SHIK_KBN, NEW_TAI_KBN,
                            F4_SHIK_KBN, F4_KAI_KBN, F4_TAI_KBN, FUKA_SHIK_KBN,
                            FUKA_KAI_KBN, KEIGEN_HANT_KBN, SHIK_4, SHIK_5,
                            SHIK_6, SHIK_7, SHIK_8, SHIK_9, SHIK_10, SHIK_11,
                            SHIK_12, SHIK_1, SHIK_2, SHIK_3, KAI_SHIK_4,
                            KAI_SHIK_5, KAI_SHIK_6, KAI_SHIK_7, KAI_SHIK_8,
                            KAI_SHIK_9, KAI_SHIK_10, KAI_SHIK_11, KAI_SHIK_12,
                            KAI_SHIK_1, KAI_SHIK_2, KAI_SHIK_3, SHOTOKU,
                            KAHYO, SHOTOKU_WARI, KAI_SHOTOKU_WARI, SIEN_SHOTOKU_WARI, KEIGEN_SHOTOKU,
                            SHISANZEI, SHISAN_WARI, KAI_SHISAN_WARI, SIEN_SHISAN_WARI, SENJU_KBN,
                            RONEN_KBN, SHINKOKU_KBN, SHU_SHOTOKU_KBN, J_KAZEI_KBN,
                            J_SHOTOKU_WARI, J_KINTO_WARI, NEW_SHUTOK_BI,
                            NEW_SOSHITSU_BI, NEW_ZOKU, KAI_GAI_BI, KAI_HIGAI_BI,
                            TANJO_65, KOSEI_BI, JIYU, KAI_KOSEI_BI, KAI_JIYU,
                            KEIGEN_BI, SEKISAN_GAI_KBN, KOJIN_NENZEI, ZOKU_NAME,
                            SHIK_R_NO, SYS_SAKUSEIBI, SYS_KOSHINBI, SYS_JIKAN,
                            SYS_SHOKUINKOJIN_NO, SYS_TANMATSU_NO,
                            CUST_1, CUST_2, CUST_3
                           ,NEW_SHITSU_KBN, F4_SHITSU_KBN, SHITSU_4, SHITSU_5,
                            SHITSU_6, SHITSU_7, SHITSU_8, SHITSU_9, SHITSU_10,
                            SHITSU_11, SHITSU_12, SHITSU_1, SHITSU_2, SHITSU_3,
                            SHITSU_GAI_BI, SHITSU_HIGAI_BI, SHITSU_SHOTOKU,
                            SHITSU_KAHYO, SHITSU_KEIGEN_SHOTOKU
                           ,KYUYO_SHOTOKU_KBN
                           --  2024/05/07 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                           ,NEW_SAN_KBN, F4_SAN_KBN
                           ,SAN_4, SAN_5, SAN_6, SAN_7, SAN_8, SAN_9
                           ,SAN_10, SAN_11, SAN_12, SAN_1, SAN_2, SAN_3
                           ,SAN_GAI_BI, SAN_HIGAI_BI
                           ,SAN_IRYO_GEN_KINTO, SAN_IRYO_GEN_SHOTOKU
                           ,SAN_KAI_GEN_KINTO, SAN_KAI_GEN_SHOTOKU
                           ,SAN_SIEN_GEN_KINTO, SAN_SIEN_GEN_SHOTOKU
                           --  2024/05/07 ZCZL.ZHANGLEI ADD END
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                           , KDM_18_KBN, KDM_SHOTOKU_WARI, KDM_SHISAN_WARI
                           , KDM_KEIGEN_KITO, KDM_KEIGEN_KITO18
                           , KDM_SAN_GEN_KINTO, KDM_SAN_GEN_SHOTOKU
                           , KDM_SAN_GEN_KINTO18, KDM18UN_KEIGEN_KITO
--2025/08/11 ZCZL.LIUHUAJUN ADD END
-- 2025/12/02 ZCZL.LIUYANG ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
                           , KDM_KODOMO_KEIGEN_KITO       -- 子ども均等割軽減額（未就学児）
                           , KDM_KINTO                    -- 子ども均等割額
                           , KDM_KINTO18                  -- 子ども18歳以上均等割額
-- 2025/12/02 ZCZL.LIUYANG ADD END
                       FROM ZLBTKOJIN_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用個人登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 課税状況用拡張登録
                INSERT INTO ZLBTEXT_KJ
                    (SELECT * FROM ZLBTEXT_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用拡張登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 課税状況用緩和世帯登録
                INSERT INTO ZLBTKANWA_SETAI_KJ
                    (SELECT * FROM ZLBTKANWA_SETAI_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用緩和世帯登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 課税状況用緩和個人登録
                INSERT INTO ZLBTKANWA_KOJIN_KJ
                    (SELECT * FROM ZLBTKANWA_KOJIN_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用緩和個人登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 課税状況用所得登録
                INSERT INTO ZLBTSHOTOKU_KJ
                    (SELECT * FROM ZLBTSHOTOKU_CAL
                      WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                        AND NENDO_BUN       = RwKIHON.NENDO_BUN
                        AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                        AND SYS_TANMATSU_NO = i_VMASIN_NO);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subUpdate_KJ 課税状況用所得登録(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
                    EXIT;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subUpdate_KJ (国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
    END subUpdate_KJ;
-------------------------------------------------------------------------------
-- 18 計算所得削除
-------------------------------------------------------------------------------
    PROCEDURE subDelShotoku IS
    BEGIN
        -- 通知書番号0の計算所得データを削除
        DELETE FROM ZLBTSHOTOKU_CAL
         WHERE TSUCHI_NO       =  0
           AND SYS_TANMATSU_NO =  i_VMASIN_NO;
    EXCEPTION
        WHEN OTHERS THEN
            VlMSG := 'subDelShotoku 計算所得削除' ||
                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                     ')' || SQLERRM;
    END subDelShotoku;
-------------------------------------------------------------------------------
-- 17 計算所得コピー
-------------------------------------------------------------------------------
    FUNCTION funcCpyShotoku(i_NwSANTEIDANTAI_CD  IN  NUMBER,
                            i_NwKOKU_SETAI_NO    IN  NUMBER,
                            i_NwNUSI_KOJIN_NO    IN  NUMBER) RETURN NUMBER IS
    BEGIN

        -- 通知書番号0の計算所得データをコピー
        INSERT INTO ZLBTSHOTOKU_CAL
            SELECT i_NwKOKU_SETAI_NO,           -- 国保世帯番号
                   KOJIN_NO,
                   i_NwSANTEIDANTAI_CD,         -- 算定団体コード
                   CHOTEI_NENDO,
                   NENDO_BUN,
                   REN_NO,
                   R_NO+10,
                   i_NwNUSI_KOJIN_NO,           -- 通知書番号
                   SHOTOKU_KBN,
                   SHOTOKU_KINGAKU,
                   JOBUN,
                   SYS_SAKUSEIBI,
                   SYS_KOSHINBI,
                   SYS_JIKAN,
                   SYS_SHOKUINKOJIN_NO,
                   SYS_TANMATSU_NO
              FROM ZLBTSHOTOKU_CAL
             WHERE TSUCHI_NO       =  0
               AND SYS_TANMATSU_NO =  i_VMASIN_NO;

            RETURN(c_NOK);

    EXCEPTION
        WHEN OTHERS THEN
            VlMSG := 'funcCpyShotoku 計算所得登録' ||
                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                     ')' || SQLERRM;
            RETURN(c_NERR);
    END funcCpyShotoku;
-------------------------------------------------------------------------------
-- 17 計算所得更新（税システム条件の所得照会中所得取扱で更新）
-------------------------------------------------------------------------------
    FUNCTION funcUpdateShotoku(i_NwSANTEIDANTAI_CD  IN  NUMBER,
                               i_NwKOKU_SETAI_NO    IN  NUMBER,
                               i_NwNUSI_KOJIN_NO    IN  NUMBER,
                               i_SHOKAICHU          IN  PLS_INTEGER
                               ) RETURN NUMBER IS
        IlRTN       PLS_INTEGER;
        IHAKKO_KBN  PLS_INTEGER;
        CURSOR CCAL IS
          SELECT *
            FROM ZLBTSHOTOKU_CAL
            WHERE KOKU_SETAI_NO   = i_NwKOKU_SETAI_NO
              AND SANTEIDANTAI_CD = i_NwSANTEIDANTAI_CD
              AND TSUCHI_NO       = i_NwNUSI_KOJIN_NO
              AND SYS_TANMATSU_NO = i_VMASIN_NO
              AND SHOTOKU_KBN     = 0  --住民税データなし
            ORDER BY KOJIN_NO;
    BEGIN
        FOR CREC IN CCAL LOOP
          --所得照会のチェック
          IlRTN := KHSFKSHOTSKCHK(CREC.NENDO_BUN, CREC.KOJIN_NO, IHAKKO_KBN);
          IF NVL(IHAKKO_KBN, 0) > 0 THEN
            --所得照会発行中
            IF i_SHOKAICHU = 1 THEN
              --所得照会中所得取扱（1:未申告とする）

              UPDATE ZLBTSHOTOKU_CAL  --所得ＣＡＬ
                SET SHOTOKU_KBN = c_SHOTOKU_MISHINKOKU
                WHERE KOKU_SETAI_NO   = i_NwKOKU_SETAI_NO
                  AND KOJIN_NO        = CREC.KOJIN_NO
                  AND SANTEIDANTAI_CD = i_NwSANTEIDANTAI_CD
                  AND CHOTEI_NENDO    = CREC.CHOTEI_NENDO
                  AND NENDO_BUN       = CREC.NENDO_BUN
                  AND REN_NO          = CREC.REN_NO
                  AND TSUCHI_NO       = i_NwNUSI_KOJIN_NO
                  AND SYS_TANMATSU_NO = i_VMASIN_NO;

              UPDATE ZLBTKOJIN_CAL    --個人ＣＡＬ
                 SET SHINKOKU_KBN     = c_SHINKOKU_MISHINKOKU  -- 申告区分　（未申告）
                   , SHU_SHOTOKU_KBN  = c_SHOTOKU_MISHINKOKU   -- 主所得区分（未申告）
               WHERE KOKU_SETAI_NO   = i_NwKOKU_SETAI_NO
                 AND KOJIN_NO        = CREC.KOJIN_NO
                 AND SANTEIDANTAI_CD = i_NwSANTEIDANTAI_CD
                 AND CHOTEI_NENDO    = CREC.CHOTEI_NENDO
                 AND NENDO_BUN       = CREC.NENDO_BUN
                 AND TSUCHI_NO       = i_NwNUSI_KOJIN_NO
                 AND SYS_TANMATSU_NO = i_VMASIN_NO;
            ELSE
              --所得照会中所得取扱（0:所得なしとする）
              NULL;  --そのまま何もしない
            END IF;
          END IF;
        END LOOP;

        RETURN(c_NOK);
    EXCEPTION
        WHEN OTHERS THEN
            VlMSG := 'funcUpdateShotoku 計算所得更新(国保世帯番号=' || NlKOKU_SETAI_NO_W || ')' || SQLERRM;
            RETURN(c_NERR);
    END funcUpdateShotoku;
-------------------------------------------------------------------------------
-- 16 計算TBL不足分作成
--    賦課TBLに存在し計算TBLに存在しない情報を作成する
-------------------------------------------------------------------------------
    FUNCTION funcMakeCal(i_NKOKU_SETAI_NO IN NUMBER) RETURN NUMBER IS

        NwRTN           NUMBER;
        NwCNT           NUMBER;
        NwR_NO          NUMBER;     -- 履歴番号
        NwDATE          NUMBER;
        NwSYSDATE       NUMBER;
        NwSYSTIME       NUMBER;

        RwKIHONN        ZLBTKIHON_N%ROWTYPE;        -- 賦課基本(最新)
        RwKIHONC        ZLBTKIHON_CAL%ROWTYPE;      -- 計算基本

        NwCNT2          NUMBER;
        NwNENZEI_KAI    NUMBER;
        NwNENZEI_SIEN   NUMBER;
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
        NwNENZEI_KDM    NUMBER;

        -- 賦課基本ｶｰｿﾙ
        CURSOR CwKIHONN IS
            SELECT * FROM ZLBTKIHON_N
             WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
               AND NENDO_BUN     = NlNENDO_BUN;

    BEGIN
        NwRTN := 0;

        NwSYSDATE := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        NwSYSTIME := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MIDD'));
        IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時

            -- 更正日としてシステム日付を使用
            NwDATE := i_NKIJUNBI;  -- 更正日として基準日を使用

        ELSE                                -- オンライン起動時

            -- 更正日として基準日を使用
            NwDATE := i_NKIJUNBI;

        END IF;

    -- 賦課TBLに存在し計算TBLに存在しない情報を作成する
        BEGIN
            FOR RwKIHONN IN CwKIHONN LOOP       -- 賦課基本(最新)
              --介護分、支援分の年税額用変数の初期化
              NwNENZEI_KAI  := 0;
              NwNENZEI_SIEN := 0;
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
              NwNENZEI_KDM  := 0;
                IF i_NCHOTEI_NENDO = i_NNENDO_BUN THEN
                  -- 現年課税計算
                  -- 計算基本に存在するか
                  BEGIN
                      SELECT COUNT(*) INTO NwCNT FROM ZLBTKIHON_CAL
                       WHERE KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                         AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                         AND CHOTEI_NENDO    =  RwKIHONN.CHOTEI_NENDO
                         AND NENDO_BUN       =  RwKIHONN.NENDO_BUN
                         AND TSUCHI_NO       =  RwKIHONN.TSUCHI_NO
                         AND SYS_TANMATSU_NO =  i_VMASIN_NO;
                  EXCEPTION
                      WHEN OTHERS THEN
                          NwRTN := c_NERR;
                          VlMSG := 'funcMakeCal 計算基本件数取得' ||
                                   '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                   ')' || SQLERRM;
                          EXIT;
                  END;
                ELSE
                  -- 過年課税計算
                  -- 計算基本に過年度分で存在するか
                  BEGIN
                      -- 世帯主課税の場合
                      IF NlNUSHI_KAZEI <> 0 THEN
                          -- 存在チェックに世帯主個人番号を追加する
                          SELECT COUNT(*) INTO NwCNT FROM ZLBTKIHON_CAL
                           WHERE KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                             AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                             -- 現年度分賦課は同一の年度分のレコードがあればOK⇒ここで調定年度は見ず後で０円更正が必要かどうか判定
                             AND NENDO_BUN       =  NLNENDO_BUN
                             AND NUSHI_KOJIN_NO  =  RwKIHONN.NUSHI_KOJIN_NO
                             AND SYS_TANMATSU_NO =  i_VMASIN_NO;
                      ELSE
                          SELECT COUNT(*) INTO NwCNT FROM ZLBTKIHON_CAL
                           WHERE KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                             AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                             AND NENDO_BUN       =  NLNENDO_BUN
                             AND SYS_TANMATSU_NO =  i_VMASIN_NO;
                      END IF;
                  EXCEPTION
                      WHEN OTHERS THEN
                          NwRTN := c_NERR;
                          VlMSG := 'funcMakeCal 計算基本件数取得' ||
                                   '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                   ')' || SQLERRM;
                          EXIT;
                  END;
                  -- 以下を満たす場合、(金額0,区分0)の賦課データを作成する
                  -- 1.年度分の賦課データが存在する
                  -- 2.調定年度≠年度分の賦課データである
                  -- 3.更正前年税額＞0である

                  --介護分の年税額を取得
                  BEGIN
                      SELECT NENZEI INTO NwNENZEI_KAI FROM ZLBTKAI_KIHON_N
                       WHERE KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                         AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                         AND CHOTEI_NENDO    =  RwKIHONN.CHOTEI_NENDO
                         AND NENDO_BUN       =  RwKIHONN.NENDO_BUN
                         AND TSUCHI_NO       =  RwKIHONN.TSUCHI_NO;
                  EXCEPTION
                      WHEN OTHERS THEN
                          NwRTN := c_NERR;
                          VlMSG := 'funcMakeCal 賦課介護基本の年税額取得' ||
                                   '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                   ')' || SQLERRM;
                          EXIT;
                  END;
                  --支援分の年税額を取得
                  BEGIN
                      SELECT NENZEI INTO NwNENZEI_SIEN FROM ZLBTSIEN_KIHON_N
                       WHERE KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                         AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                         AND CHOTEI_NENDO    =  RwKIHONN.CHOTEI_NENDO
                         AND NENDO_BUN       =  RwKIHONN.NENDO_BUN
                         AND TSUCHI_NO       =  RwKIHONN.TSUCHI_NO;
                  EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                          NwNENZEI_SIEN := 0;
                      WHEN OTHERS THEN
                          NwRTN := c_NERR;
                          VlMSG := 'funcMakeCal 賦課支援基本の年税額取得' ||
                                   '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                   ')' || SQLERRM;
                          EXIT;
                  END;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                  --子ども分の年税額を取得する
                  BEGIN
                      SELECT NENZEI INTO NwNENZEI_KDM FROM ZLBTKDM_KIHON_N
                       WHERE KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                         AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                         AND CHOTEI_NENDO    =  RwKIHONN.CHOTEI_NENDO
                         AND NENDO_BUN       =  RwKIHONN.NENDO_BUN
                         AND TSUCHI_NO       =  RwKIHONN.TSUCHI_NO;
                  EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                          NwNENZEI_KDM := 0;
                      WHEN OTHERS THEN
                          NwRTN := c_NERR;
                          VlMSG := 'funcMakeCal 賦課子ども基本の年税額取得' ||
                                   '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                   ')' || SQLERRM;
                          EXIT;
                  END;
--2025/08/11 ZCZL.LIUHUAJUN ADD END

--2025/08/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応
--                  IF NwCNT > 0 AND RwKIHONN.CHOTEI_NENDO <> RwKIHONN.NENDO_BUN AND (RwKIHONN.NENZEI + NwNENZEI_KAI + NwNENZEI_SIEN) > 0 THEN
                  IF NwCNT > 0 AND RwKIHONN.CHOTEI_NENDO <> RwKIHONN.NENDO_BUN AND (RwKIHONN.NENZEI + NwNENZEI_KAI + NwNENZEI_SIEN + NwNENZEI_KDM) > 0 THEN
                      -- 4.該当年度に有資格者がいない
                      BEGIN
                          SELECT COUNT(*) INTO NwCNT2
                            FROM ZLBTSHIKAKU_TMP  A,
                                 (SELECT MAX(TAI_R_NO) AS TAI_R_NO,
                                         KOKU_SETAI_NO,
                                         KOJIN_NO,
                                         R_NO
                                    FROM ZLBTSHIKAKU_TMP
                                   WHERE KOKU_SETAI_NO   = RwKIHONN.KOKU_SETAI_NO
                                     AND SAKUJO_KBN      = 0
                                     AND SYS_TANMATSU_NO = i_VMASIN_NO
                                   GROUP BY KOKU_SETAI_NO,KOJIN_NO,R_NO
                                 ) B
                           WHERE A.KOKU_SETAI_NO  = B.KOKU_SETAI_NO
                             AND A.KOJIN_NO       = B.KOJIN_NO
                             AND A.R_NO           = B.R_NO
                             AND A.TAI_R_NO       = B.TAI_R_NO
                             --賦課期日以前から資格ありの場合は、資格喪失なしまたは賦課期日翌日以降の喪失
                             AND ((A.Z_SHUTOKU_BI < NlFUKAKIJITU AND (A.Z_SOSHITSU_BI = 0 OR A.Z_SOSHITSU_BI > NlFUKAKIJITU))
                             --賦課期日以降に資格取得の場合は、賦課期日の１年後以前の取得である かつ資格喪失なしまたは賦課期日以降の喪失
                              OR  (A.Z_SHUTOKU_BI >= NlFUKAKIJITU AND A.Z_SHUTOKU_BI < NlFUKAKIJITU + 10000))  --取得日が賦課の年度内であれば喪失日は見ない
                             -- 同日の取得喪失を除く
                             AND A.SHUTOKU_BI != A.SOSHITSU_BI
                             AND A.SYS_TANMATSU_NO = i_VMASIN_NO;
                          -- 4-1.主課税で該当年度の世帯主が遡及喪失し該当通番をゼロ円更正したい
                          IF NlNUSHI_KAZEI <> 0 AND NwCNT2 > 0 THEN
                            SELECT COUNT(*) INTO NwCNT2
                              FROM ZLBTSHIKAKU_TMP  A,
                                   (SELECT MAX(TAI_R_NO) AS TAI_R_NO,
                                           KOKU_SETAI_NO,
                                           KOJIN_NO,
                                           R_NO
                                      FROM ZLBTSHIKAKU_TMP
                                     WHERE KOKU_SETAI_NO   = RwKIHONN.KOKU_SETAI_NO
                                       and kojin_no = RwKIHONN.NUSHI_KOJIN_NO
                                       AND SAKUJO_KBN      = 0
                                       AND SYS_TANMATSU_NO = i_VMASIN_NO
                                     GROUP BY KOKU_SETAI_NO,KOJIN_NO,R_NO
                                   ) B
                             WHERE A.KOKU_SETAI_NO  = B.KOKU_SETAI_NO
                               AND A.KOJIN_NO       = B.KOJIN_NO
                               AND A.R_NO           = B.R_NO
                               AND A.TAI_R_NO       = B.TAI_R_NO
                               --賦課期日以前から資格ありの場合は、資格喪失なしまたは賦課期日翌日以降の喪失
                               AND ((A.Z_SHUTOKU_BI < NlFUKAKIJITU AND (A.Z_SOSHITSU_BI = 0 OR A.Z_SOSHITSU_BI > NlFUKAKIJITU))
                               --賦課期日以降に資格取得の場合は、賦課期日の１年後以前の取得である かつ資格喪失なしまたは賦課期日以降の喪失
                                OR  (A.Z_SHUTOKU_BI >= NlFUKAKIJITU AND A.Z_SHUTOKU_BI < NlFUKAKIJITU + 10000))  --取得日が賦課の年度内であれば喪失日は見ない
                               -- 同日の取得喪失を除く
                               AND A.SHUTOKU_BI != A.SOSHITSU_BI
                               AND A.SYS_TANMATSU_NO = i_VMASIN_NO;
                          END IF;
                      EXCEPTION
                          WHEN OTHERS THEN
                              NwRTN := c_NERR;
                              VlMSG := 'funcMakeCal 計算基本過年度有資格件数取得' ||
                                       '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                       ')' || SQLERRM;
                              EXIT;
                      END;
                      IF NwCNT2 = 0 THEN
                          -- 5.対象年度の計算賦課データが作成されていない
                          -- 同じ主個人番号で０円データが作成されていない場合、ここで０円にする！
                          BEGIN
                              SELECT COUNT(*) INTO NwCNT FROM ZLBTKIHON_CAL
                               WHERE KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                                 AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                                 AND (RwKIHONN.CHOTEI_NENDO = RwKIHONN.NENDO_BUN OR
                                      CHOTEI_NENDO = RwKIHONN.CHOTEI_NENDO)
                                 AND NUSHI_KOJIN_NO  =  RwKIHONN.NUSHI_KOJIN_NO
                                 AND NENDO_BUN       =  NLNENDO_BUN
                                 AND SYS_TANMATSU_NO =  i_VMASIN_NO;
                          EXCEPTION
                              WHEN OTHERS THEN
                                  NwRTN := c_NERR;
                                  VlMSG := 'funcMakeCal 計算基本過年度件数取得' ||
                                           '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                           ')' || SQLERRM;
                                  EXIT;
                          END;
                      END IF;
                  END IF;
                END IF;

                IF NwCNT = 0 THEN

                    -- 存在しなければ計算基本を作成(金額0,区分0)
                    BEGIN
                        INSERT INTO ZLBTKIHON_CAL
                           VALUES (RwKIHONN.KOKU_SETAI_NO, RwKIHONN.SANTEIDANTAI_CD,
                                   RwKIHONN.CHOTEI_NENDO,  RwKIHONN.NENDO_BUN,
                                   RwKIHONN.R_NO + 10,     RwKIHONN.TSUCHI_NO,
                                   RwKIHONN.YOKU_TSUCHI_NO,
                                   RwKIHONN.NUSHI_KOJIN_NO,
                                   c_NJIYU_KIBETUKOSEI,     -- 事由(93:期別更正)
                                   NwDATE,      -- 更正日
                                   1,           -- 更新区分
                                   0,           -- 申告区分
                                   0,           -- 主所得区分
                                   1,           -- 現存区分
                                   0,           -- 世帯区分
                                   0,           -- 擬制区分
                                   0,           -- 賦課期日軽減区分
                                   0,           -- 住民税課税区分
                                   0,           -- 譲渡世帯区分
                                   0,           -- 老人世帯区分
                                   0,           -- 専従世帯区分
                                   0,           -- 軽減申請区分
                                   RwKIHONN.SEISAN_KBN,     -- 清算区分
                                   0,           -- 軽減判定所得
                                   0,           -- 賦課期日人員
                                   0,           -- 均等人員
                                   0,           -- 現在人員
                                   0,           -- 有所得人員
                                   0,           -- 所得額
                                   0,           -- 課税評価額
                                   0,           -- 所得割額
                                   0,           -- 資産税額
                                   0,           -- 資産割額
                                   0,           -- 均等割額
                                   0,           -- 平等割額
                                   0,           -- 積算税額
                                   0,           -- 限度超過額
                                   0,           -- 軽減均等割額
                                   0,           -- 軽減平等割額
                                   0,           -- 軽減均等6
                                   0,           -- 軽減平等6
                                   0,           -- 軽減均等4
                                   0,           -- 軽減平等4
                                   0,           -- 軽減均等2
                                   0,           -- 軽減平等2
                                   0,           -- 月割減額
                                   0,           -- 端数
                                   0,           -- 減額合計
                                   0,           -- 減免額
                                   0,           -- 過年度分
                                   0,           -- 年税額
                                   0,           -- 軽減4月
                                   0,           -- 軽減5月
                                   0,           -- 軽減6月
                                   0,           -- 軽減7月
                                   0,           -- 軽減8月
                                   0,           -- 軽減9月
                                   0,           -- 軽減10月
                                   0,           -- 軽減11月
                                   0,           -- 軽減12月
                                   0,           -- 軽減1月
                                   0,           -- 軽減2月
                                   0,           -- 軽減3月
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO);    -- 端末番号
                    EXCEPTION
                        WHEN OTHERS THEN
                            NwRTN     := c_NERR;
                            VlMSG := 'funcMakeCal 計算基本登録' ||
                                         '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                         ')' || SQLERRM;
                            EXIT;
                    END;

                    -- 存在しなければ計算退職を作成(金額0)
                    BEGIN
                        INSERT INTO ZLBTTAI_CAL
                           VALUES (RwKIHONN.KOKU_SETAI_NO, RwKIHONN.SANTEIDANTAI_CD,
                                   RwKIHONN.CHOTEI_NENDO, RwKIHONN.NENDO_BUN,
                                   RwKIHONN.R_NO + 10, RwKIHONN.TSUCHI_NO,
                                   0,           -- 軽減判定所得
                                   0,           -- 賦課期日人員
                                   0,           -- 均等人員
                                   0,           -- 現在人員
                                   0,           -- 有所得人員
                                   0,           -- 所得額
                                   0,           -- 課税評価額
                                   0,           -- 所得割額
                                   0,           -- 資産税額
                                   0,           -- 資産割額
                                   0,           -- 均等割額
                                   0,           -- 平等割額
                                   0,           -- 積算税額
                                   0,           -- 限度超過額
                                   0,           -- 軽減均等割額
                                   0,           -- 軽減平等割額
                                   0,           -- 軽減均等6
                                   0,           -- 軽減平等6
                                   0,           -- 軽減均等4
                                   0,           -- 軽減平等4
                                   0,           -- 軽減均等2
                                   0,           -- 軽減平等2
                                   0,           -- 月割減額
                                   0,           -- 端数
                                   0,           -- 減額合計
                                   0,           -- 減免額
                                   0,           -- 過年度分
                                   0,           -- 年税額
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO);    -- 端末番号
                    EXCEPTION
                        WHEN OTHERS THEN
                            NwRTN := c_NERR;
                            VlMSG := 'funcMakeCal 計算退職登録' ||
                                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                     ')' || SQLERRM;
                            EXIT;
                    END;

                    -- 存在しなければ計算介護基本を作成(金額0)
                    BEGIN
                        INSERT INTO ZLBTKAI_KIHON_CAL
                           VALUES (RwKIHONN.KOKU_SETAI_NO, RwKIHONN.SANTEIDANTAI_CD,
                                   RwKIHONN.CHOTEI_NENDO, RwKIHONN.NENDO_BUN,
                                   RwKIHONN.R_NO + 10, RwKIHONN.TSUCHI_NO,
                                   RwKIHONN.NUSHI_KOJIN_NO,
                                   c_NJIYU_KIBETUKOSEI,     -- 事由(93:期別更正)
                                   NwDATE,      -- 更正日
                                   1,           -- 更新区分
                                   0,           -- 申告区分
                                   0,           -- 主所得区分
                                   1,           -- 現存区分
                                   0,           -- 世帯区分
                                   0,           -- 擬制区分
                                   0,           -- 住民税課税区分
                                   0,           -- 譲渡世帯区分
                                   0,           -- 老人世帯区分
                                   0,           -- 専従世帯区分
                                   0,           -- 軽減申請区分
                                   0,           -- 軽減判定所得
                                   0,           -- 賦課期日人員
                                   0,           -- 均等人員
                                   0,           -- 現在人員
                                   0,           -- 有所得人員
                                   0,           -- 所得額
                                   0,           -- 課税評価額
                                   0,           -- 所得割額
                                   0,           -- 資産税額
                                   0,           -- 資産割額
                                   0,           -- 均等割額
                                   0,           -- 平等割額
                                   0,           -- 積算税額
                                   0,           -- 限度超過額
                                   0,           -- 軽減均等割額
                                   0,           -- 軽減平等割額
                                   0,           -- 軽減均等6
                                   0,           -- 軽減平等6
                                   0,           -- 軽減均等4
                                   0,           -- 軽減平等4
                                   0,           -- 軽減均等2
                                   0,           -- 軽減平等2
                                   0,           -- 月割減額
                                   0,           -- 端数
                                   0,           -- 減額合計
                                   0,           -- 減免額
                                   0,           -- 過年度分
                                   0,           -- 年税額
                                   0,           -- 軽減4月
                                   0,           -- 軽減5月
                                   0,           -- 軽減6月
                                   0,           -- 軽減7月
                                   0,           -- 軽減8月
                                   0,           -- 軽減9月
                                   0,           -- 軽減10月
                                   0,           -- 軽減11月
                                   0,           -- 軽減12月
                                   0,           -- 軽減1月
                                   0,           -- 軽減2月
                                   0,           -- 軽減3月
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO);    -- 端末番号
                    EXCEPTION
                        WHEN OTHERS THEN
                            NwRTN := c_NERR;
                            VlMSG := 'funcMakeCal 計算介護基本登録' ||
                                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                     ')' || SQLERRM;
                            EXIT;
                    END;

                    -- 存在しなければ計算介護退職を作成(金額0)
                    BEGIN
                        INSERT INTO ZLBTKAI_TAI_CAL
                           VALUES (RwKIHONN.KOKU_SETAI_NO, RwKIHONN.SANTEIDANTAI_CD,
                                   RwKIHONN.CHOTEI_NENDO, RwKIHONN.NENDO_BUN,
                                   RwKIHONN.R_NO + 10, RwKIHONN.TSUCHI_NO,
                                   0,           -- 軽減判定所得
                                   0,           -- 賦課期日人員
                                   0,           -- 均等人員
                                   0,           -- 現在人員
                                   0,           -- 有所得人員
                                   0,           -- 所得額
                                   0,           -- 課税評価額
                                   0,           -- 所得割額
                                   0,           -- 資産税額
                                   0,           -- 資産割額
                                   0,           -- 均等割額
                                   0,           -- 平等割額
                                   0,           -- 積算税額
                                   0,           -- 限度超過額
                                   0,           -- 軽減均等割額
                                   0,           -- 軽減平等割額
                                   0,           -- 軽減均等6
                                   0,           -- 軽減平等6
                                   0,           -- 軽減均等4
                                   0,           -- 軽減平等4
                                   0,           -- 軽減均等2
                                   0,           -- 軽減平等2
                                   0,           -- 月割減額
                                   0,           -- 端数
                                   0,           -- 減額合計
                                   0,           -- 減免額
                                   0,           -- 過年度分
                                   0,           -- 年税額
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO);    -- 端末番号
                    EXCEPTION
                        WHEN OTHERS THEN
                            NwRTN := c_NERR;
                            VlMSG := 'funcMakeCal 計算介護退職登録' ||
                                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                     ')' || SQLERRM;
                            EXIT;
                    END;

                    -- 存在しなければ計算支援基本を作成(金額0)
                    BEGIN
                        INSERT INTO ZLBTSIEN_KIHON_CAL
                           VALUES (RwKIHONN.KOKU_SETAI_NO, RwKIHONN.SANTEIDANTAI_CD,
                                   RwKIHONN.CHOTEI_NENDO, RwKIHONN.NENDO_BUN,
                                   RwKIHONN.R_NO + 10, RwKIHONN.TSUCHI_NO,
                                   RwKIHONN.NUSHI_KOJIN_NO,
                                   c_NJIYU_KIBETUKOSEI,     -- 事由(93:期別更正)
                                   NwDATE,      -- 更正日
                                   1,           -- 更新区分
                                   0,           -- 申告区分
                                   0,           -- 主所得区分
                                   1,           -- 現存区分
                                   0,           -- 世帯区分
                                   0,           -- 擬制区分
                                   0,           -- 住民税課税区分
                                   0,           -- 譲渡世帯区分
                                   0,           -- 老人世帯区分
                                   0,           -- 専従世帯区分
                                   0,           -- 軽減申請区分
                                   0,           -- 軽減判定所得
                                   0,           -- 賦課期日人員
                                   0,           -- 均等人員
                                   0,           -- 現在人員
                                   0,           -- 有所得人員
                                   0,           -- 所得額
                                   0,           -- 課税評価額
                                   0,           -- 所得割額
                                   0,           -- 資産税額
                                   0,           -- 資産割額
                                   0,           -- 均等割額
                                   0,           -- 平等割額
                                   0,           -- 積算税額
                                   0,           -- 限度超過額
                                   0,           -- 軽減均等割額
                                   0,           -- 軽減平等割額
                                   0,           -- 軽減均等6
                                   0,           -- 軽減平等6
                                   0,           -- 軽減均等4
                                   0,           -- 軽減平等4
                                   0,           -- 軽減均等2
                                   0,           -- 軽減平等2
                                   0,           -- 月割減額
                                   0,           -- 端数
                                   0,           -- 減額合計
                                   0,           -- 減免額
                                   0,           -- 過年度分
                                   0,           -- 年税額
                                   0,           -- 軽減4月
                                   0,           -- 軽減5月
                                   0,           -- 軽減6月
                                   0,           -- 軽減7月
                                   0,           -- 軽減8月
                                   0,           -- 軽減9月
                                   0,           -- 軽減10月
                                   0,           -- 軽減11月
                                   0,           -- 軽減12月
                                   0,           -- 軽減1月
                                   0,           -- 軽減2月
                                   0,           -- 軽減3月
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO);    -- 端末番号
                    EXCEPTION
                        WHEN OTHERS THEN
                            NwRTN := c_NERR;
                            VlMSG := 'funcMakeCal 計算支援基本登録' ||
                                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                     ')' || SQLERRM;
                            EXIT;
                    END;

                    -- 存在しなければ計算支援退職を作成(金額0)
                    BEGIN
                        INSERT INTO ZLBTSIEN_TAI_CAL
                           VALUES (RwKIHONN.KOKU_SETAI_NO, RwKIHONN.SANTEIDANTAI_CD,
                                   RwKIHONN.CHOTEI_NENDO, RwKIHONN.NENDO_BUN,
                                   RwKIHONN.R_NO + 10, RwKIHONN.TSUCHI_NO,
                                   0,           -- 軽減判定所得
                                   0,           -- 賦課期日人員
                                   0,           -- 均等人員
                                   0,           -- 現在人員
                                   0,           -- 有所得人員
                                   0,           -- 所得額
                                   0,           -- 課税評価額
                                   0,           -- 所得割額
                                   0,           -- 資産税額
                                   0,           -- 資産割額
                                   0,           -- 均等割額
                                   0,           -- 平等割額
                                   0,           -- 積算税額
                                   0,           -- 限度超過額
                                   0,           -- 軽減均等割額
                                   0,           -- 軽減平等割額
                                   0,           -- 軽減均等6
                                   0,           -- 軽減平等6
                                   0,           -- 軽減均等4
                                   0,           -- 軽減平等4
                                   0,           -- 軽減均等2
                                   0,           -- 軽減平等2
                                   0,           -- 月割減額
                                   0,           -- 端数
                                   0,           -- 減額合計
                                   0,           -- 減免額
                                   0,           -- 過年度分
                                   0,           -- 年税額
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO);    -- 端末番号
                    EXCEPTION
                        WHEN OTHERS THEN
                            NwRTN := c_NERR;
                            VlMSG := 'funcMakeCal 計算支援退職登録' ||
                                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                     ')' || SQLERRM;
                            EXIT;
                    END;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                    -- 存在しなければ計算子ども基本を作成(金額0)
                    BEGIN
                        INSERT INTO ZLBTKDM_KIHON_CAL
                           VALUES (RwKIHONN.KOKU_SETAI_NO, RwKIHONN.SANTEIDANTAI_CD,
                                   RwKIHONN.CHOTEI_NENDO, RwKIHONN.NENDO_BUN,
                                   RwKIHONN.R_NO + 10, RwKIHONN.TSUCHI_NO,
                                   RwKIHONN.NUSHI_KOJIN_NO,
                                   c_NJIYU_KIBETUKOSEI, -- 軽減判定所得
                                   NwDATE,      -- 更正日
                                   1,           -- 更新区分
                                   0,           -- 申告区分
                                   0,           -- 主所得区分
                                   1,           -- 現存区分
                                   0,           -- 世帯区分
                                   0,           -- 擬制区分
                                   0,           -- 住民税課税区分
                                   0,           -- 譲渡世帯区分
                                   0,           -- 老人世帯区分
                                   0,           -- 専従世帯区分
                                   0,           -- 軽減申請区分
                                   0,           -- 軽減判定所得
                                   0,           -- 賦課期日人員
                                   0,           -- 均等人員
                                   0,           -- 現在人員
                                   0,           -- 有所得人員
                                   0,           -- 所得額
                                   0,           -- 課税標準額
                                   0,           -- 所得割額
                                   0,           -- 資産税額
                                   0,           -- 資産割額
                                   0,           -- 均等割額
                                   0,           -- 平等割額
                                   0,           -- 積算税額
                                   0,           -- 限度超過額
                                   0,           -- 軽減均等割額
                                   0,           -- 軽減平等割額
                                   0,           -- 軽減均等6
                                   0,           -- 軽減平等6
                                   0,           -- 軽減均等4
                                   0,           -- 軽減平等4
                                   0,           -- 軽減均等2
                                   0,           -- 軽減平等2
                                   0,           -- 月割減額
                                   0,           -- 端数
                                   0,           -- 減額合計
                                   0,           -- 減免額
                                   0,           -- 過年度分
                                   0,           -- 年税額
                                   0,           -- 軽減4月
                                   0,           -- 軽減5月
                                   0,           -- 軽減6月
                                   0,           -- 軽減7月
                                   0,           -- 軽減8月
                                   0,           -- 軽減9月
                                   0,           -- 軽減10月
                                   0,           -- 軽減11月
                                   0,           -- 軽減12月
                                   0,           -- 軽減1月
                                   0,           -- 軽減2月
                                   0,           -- 軽減3月
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO, -- 端末番号
                                   0,           -- 18歳以上均等人員
                                   0            -- 子ども18歳以上均等割額
                                   );    
                    EXCEPTION
                        WHEN OTHERS THEN
                            NwRTN := c_NERR;
                            VlMSG := 'funcMakeCal 計算子ども基本登録' ||
                                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                     ')' || SQLERRM;
                            EXIT;
                    END;
--2025/08/11 ZCZL.LIUHUAJUN ADD END

                    -- 存在しなければ計算個人を作成(金額0)
                    BEGIN
                        INSERT INTO ZLBTKOJIN_CAL
                            SELECT KOKU_SETAI_NO, KOJIN_NO, SANTEIDANTAI_CD,
                                   CHOTEI_NENDO, NENDO_BUN, R_NO + 10, TSUCHI_NO,
                                   0,           -- 最新資格区分
                                   0,           -- 最新介護資格区分
                                   0,           -- 最新退職区分
                                   0,           -- 賦課期日資格区分
                                   0,           -- 賦課期日介護資格区分
                                   0,           -- 賦課期日退職区分
                                   0,           -- 賦課発生時資格区分
                                   0,           -- 賦課発生時介護資格区分
                                   0,           -- 軽減判定区分
                                   0,           -- 資格4月
                                   0,           -- 資格5月
                                   0,           -- 資格6月
                                   0,           -- 資格7月
                                   0,           -- 資格8月
                                   0,           -- 資格9月
                                   0,           -- 資格10月
                                   0,           -- 資格11月
                                   0,           -- 資格12月
                                   0,           -- 資格1月
                                   0,           -- 資格2月
                                   0,           -- 資格3月
                                   0,           -- 介護資格4月
                                   0,           -- 介護資格5月
                                   0,           -- 介護資格6月
                                   0,           -- 介護資格7月
                                   0,           -- 介護資格8月
                                   0,           -- 介護資格9月
                                   0,           -- 介護資格10月
                                   0,           -- 介護資格11月
                                   0,           -- 介護資格12月
                                   0,           -- 介護資格1月
                                   0,           -- 介護資格2月
                                   0,           -- 介護資格3月
                                   0,           -- 所得額
                                   0,           -- 課税評価額
                                   0,           -- 所得割額
                                   0,           -- 介護所得割額
                                   0,           -- 支援所得割額
                                   0,           -- 軽減判定所得
                                   0,           -- 資産税額
                                   0,           -- 資産割額
                                   0,           -- 介護資産割額
                                   0,           -- 支援資産割額
                                   0,           -- 専従区分
                                   0,           -- 老年者区分
                                   0,           -- 申告区分
                                   0,           -- 主所得区分
                                   0,           -- 住民税課税区分
                                   0,           -- 住民税所得割額
                                   0,           -- 住民税均等割額
                                   0,           -- 最新資格取得日
                                   0,           -- 最新資格喪失日
                                   0,           -- 最新続柄
                                   0,           -- 介護該当日
                                   0,           -- 介護非該当日
                                   0,           -- 誕生日65歳
                                   NwDATE,      -- 更正日
                                   c_NJIYU_KIBETUKOSEI,     -- 事由(93:期別更正)
                                   NwDATE,      -- 介護更正日
                                   c_NJIYU_KIBETUKOSEI,     -- 介護事由(93:期別更正)
                                   0,           -- 軽減判定取得日
                                   0,           -- 積算該当区分
                                   0,           -- 個人年税額
                                   NULL,        -- 続柄名称
                                   0,           -- 資格履歴番号
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO, -- 端末番号
                                   0,           -- 清算区分
                                   0,           -- 対象4月
                                   0,           -- 対象5月
                                   0,           -- 対象6月
                                   0,           -- 対象7月
                                   0,           -- 対象8月
                                   0,           -- 対象9月
                                   0,           -- 対象10月
                                   0,           -- 対象11月
                                   0,           -- 対象12月
                                   0,           -- 対象1月
                                   0,           -- 対象2月
                                   0,           -- 対象3月
                                   0,           -- 独自項目1
                                   0,           -- 独自項目2
                                   0            -- 独自項目3
                                 , 0,           -- 最新失業者資格区分
                                   0,           -- 賦課期日失業者資格区分
                                   0,           -- 失業者資格4月
                                   0,           -- 失業者資格5月
                                   0,           -- 失業者資格6月
                                   0,           -- 失業者資格7月
                                   0,           -- 失業者資格8月
                                   0,           -- 失業者資格9月
                                   0,           -- 失業者資格10月
                                   0,           -- 失業者資格11月
                                   0,           -- 失業者資格12月
                                   0,           -- 失業者資格1月
                                   0,           -- 失業者資格2月
                                   0,           -- 失業者資格3月
                                   0,           -- 失業軽減該当日
                                   0,           -- 失業軽減非該当日
                                   0,           -- 失業軽減適用後所得額
                                   0,           -- 失業軽減適用後課税標準額
                                   0            -- 失業軽減適用後軽減判定所得
                                  ,0            --給与所得者等該当区分
                                  --  2024/05/07 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                                  ,0            --最新産前産後資格区分
                                  ,0            --賦課期日産前産後資格区分
                                  ,0            --産前産後4月
                                  ,0            --産前産後5月
                                  ,0            --産前産後6月
                                  ,0            --産前産後7月
                                  ,0            --産前産後8月
                                  ,0            --産前産後9月
                                  ,0            --産前産後10月
                                  ,0            --産前産後11月
                                  ,0            --産前産後12月
                                  ,0            --産前産後1月
                                  ,0            --産前産後2月
                                  ,0            --産前産後3月
                                  ,0            --産前産後該当日
                                  ,0            --産前産後非該当日
                                  ,0            --医療産前産後均等割軽減額
                                  ,0            --医療産前産後所得割軽減額
                                  ,0            --介護産前産後均等割軽減額
                                  ,0            --介護産前産後所得割軽減額
                                  ,0            --支援産前産後均等割軽減額
                                  ,0            --支援産前産後所得割軽減額
                                  --  2024/05/07 ZCZL.ZHANGLEI ADD END
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                                  ,0            --子ども18歳以上該当区分
                                  ,0            --子ども所得割額
                                  ,0            --子ども資産割額
                                  ,0            --子ども均等割軽減額
                                  ,0            --子ども18歳以上均等割軽減額
                                  ,0            --子ども産前産後均等割軽減額
                                  ,0            --子ども産前産後所得割軽減額
                                  ,0            --子ども産前産後18歳以上均等割軽減額
                                  ,0            --子ども18歳未満均等割軽減額
-- 2025/12/02 ZCZL.LIUYANG ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
                                  ,0            -- 子ども均等割軽減額（未就学児）
                                  ,0            -- 子ども均等割額
                                  ,0            -- 子ども18歳以上均等割額
-- 2025/12/02 ZCZL.LIUYANG ADD END
--2025/08/11 ZCZL.LIUHUAJUN ADD END
                              FROM ZLBTKOJIN_N
                             WHERE KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                               AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                               AND CHOTEI_NENDO    =  RwKIHONN.CHOTEI_NENDO
                               AND NENDO_BUN       =  RwKIHONN.NENDO_BUN
                               AND TSUCHI_NO       =  RwKIHONN.TSUCHI_NO;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NULL;
                        WHEN OTHERS THEN
                            NwRTN := c_NERR;
                            VlMSG := 'funcMakeCal 計算個人登録' ||
                                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                     ')' || SQLERRM;
                            EXIT;
                    END;

                    -- 存在しなければ計算期別を作成(金額0)
                    BEGIN
                        INSERT INTO ZLBTKIBETSU_CAL
                            SELECT KAMOKU_CD,       KAMOKUS_CD,         KOKU_SETAI_NO,
                                   SANTEIDANTAI_CD, KIWARIDANTAI_CD,    DANTAING_KBN,
                                   GENNENKANEN_KBN, CHOTEINENDO,        NENDOBUN,
                                   TSUCHI_NO,       RONRIKIBETSU,       R_NO + 10,
                                   NENGETSU,        NUSHI_KOJIN_NO,
                                   NwDATE,      -- 更正日
                                   0,           -- 全体税額
                                   0,           -- 退職税額
                                   0,           -- 医療全体税額
                                   0,           -- 医療退職税額
                                   0,           -- 介護全体税額
                                   0,           -- 介護退職税額
                                   0,           -- 支援全体税額
                                   0,           -- 支援退職税額
                                   0,           -- 不能欠損額（医療全体）
                                   0,           -- 不能欠損額（医療退職）
                                   0,           -- 不能欠損額（介護全体）
                                   0,           -- 不能欠損額（介護退職）
                                   0,           -- 不能欠損額（支援全体）
                                   0,           -- 不能欠損額（支援退職）
                                   0,           -- 公示送達区分
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO  -- 端末番号
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                                  ,0            -- 子ども全体税額
                                  ,0            -- 不能欠損額（子ども全体）
--2025/08/11 ZCZL.LIUHUAJUN ADD END
                              FROM ZLBTKIBETSU_N
                             WHERE KAMOKU_CD       =  c_NKAMOKU_CD
                               AND KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                               AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                               AND CHOTEINENDO     =  RwKIHONN.CHOTEI_NENDO
                               AND NENDOBUN        =  RwKIHONN.NENDO_BUN
                               AND TSUCHI_NO       =  RwKIHONN.TSUCHI_NO;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NULL;
                        WHEN OTHERS THEN
                            NwRTN     := c_NERR;
                            VlMSG := 'funcMakeCal 計算期別登録' ||
                                         '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                         ')' || SQLERRM;
                            EXIT;
                    END;

                    -- 存在しなければ計算所得を作成(金額0)
                    BEGIN
                        INSERT INTO ZLBTSHOTOKU_CAL
                            SELECT KOKU_SETAI_NO,   KOJIN_NO,       SANTEIDANTAI_CD,
                                   CHOTEI_NENDO,    NENDO_BUN,      REN_NO,
                                   R_NO + 10,       TSUCHI_NO,      SHOTOKU_KBN,
                                   0,           -- 所得金額
                                   JOBUN,
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO  -- 端末番号
                              FROM ZLBTSHOTOKU_N
                             WHERE KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                               AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                               AND CHOTEI_NENDO    =  RwKIHONN.CHOTEI_NENDO
                               AND NENDO_BUN       =  RwKIHONN.NENDO_BUN
                               AND TSUCHI_NO       =  RwKIHONN.TSUCHI_NO;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NULL;
                        WHEN OTHERS THEN
                            NwRTN     := c_NERR;
                            VlMSG := 'funcMakeCal 計算所得登録' ||
                                         '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                         ')' || SQLERRM;
                            EXIT;
                    END;

                    -- 存在しなければ計算拡張を作成(金額0)
                    BEGIN
                        INSERT INTO ZLBTEXT_CAL
                            SELECT KOKU_SETAI_NO,   SANTEIDANTAI_CD,    CHOTEI_NENDO,
                                   NENDO_BUN,       R_NO + 10,          TSUCHI_NO,
                                   0,           -- 身障減免判定所得
                                   0,           -- 身障減免率
                                   0,           -- 減免区分
                                   0,           -- 減免率
                                   0,           -- 医療年齢軽減
                                   0,           -- 医療身障減免
                                   0,           -- 医療年齢軽減（退職）
                                   0,           -- 医療身障減免（退職）
                                   0,           -- 介護年齢軽減
                                   0,           -- 介護身障減免
                                   0,           -- 介護年齢軽減（退職）
                                   0,           -- 介護身障減免（退職）
                                   0,           -- 支援年齢軽減
                                   0,           -- 支援身障減免
                                   0,           -- 支援年齢軽減（退職）
                                   0,           -- 支援身障減免（退職）
                                   NwSYSDATE,   -- 作成日
                                   NwSYSDATE,   -- 更新日
                                   NwSYSTIME,   -- 更新時間
                                   i_NSYS_SHOKUINKOJIN_NO,      -- 更新職員番号
                                   i_VMASIN_NO, -- 端末番号
                                   0,           -- 医療所得割積算軽減額(被扶養者)
                                   0,           -- 医療所得割積算軽減額(被扶養者)(退職)
                                   0,           -- 介護所得割積算軽減額(被扶養者)
                                   0,           -- 介護所得割積算軽減額(被扶養者)(退職)
                                   0,           -- 支援所得割積算軽減額(被扶養者)
                                   0,           -- 支援所得割積算軽減額(被扶養者)(退職)
                                   0,           -- 医療資産割積算軽減額(被扶養者)
                                   0,           -- 医療資産割積算軽減額(被扶養者)(退職)
                                   0,           -- 介護資産割積算軽減額(被扶養者)
                                   0,           -- 介護資産割積算軽減額(被扶養者)(退職)
                                   0,           -- 介護資産割積算軽減額(被扶養者)
                                   0,           -- 介護資産割積算軽減額(被扶養者)(退職)
                                   0,           -- 医療均等割積算軽減額(被扶養者)
                                   0,           -- 医療均等割積算軽減額(被扶養者)(退職)
                                   0,           -- 介護均等割積算軽減額(被扶養者)
                                   0,           -- 介護均等割積算軽減額(被扶養者)(退職)
                                   0,           -- 支援均等割積算軽減額(被扶養者)
                                   0,           -- 支援均等割積算軽減額(被扶養者)(退職)
                                   0,           -- 医療平等割積算軽減額(被扶養者/特定同一)
                                   0,           -- 医療平等割積算軽減額(被扶養者/特定同一)(退職)
                                   0,           -- 介護平等割積算軽減額(被扶養者/特定同一)
                                   0,           -- 介護平等割積算軽減額(被扶養者/特定同一)(退職)
                                   0,           -- 支援平等割積算軽減額(被扶養者/特定同一)
                                   0,           -- 支援平等割積算軽減額(被扶養者/特定同一)(退職)
                                   0,           -- 特定同一軽減該当区分
                                   0,           -- 特定同一平等割該当区分
                                   0            -- 旧被扶養者該当区分
                                  ,0            --未就学児人数最新
                                  ,0            --未就学児人数賦課期日
                                  ,0            --未就学児人数賦課発生時
                                  ,0            --未就学児人数4月
                                  ,0            --未就学児人数5月
                                  ,0            --未就学児人数6月
                                  ,0            --未就学児人数7月
                                  ,0            --未就学児人数8月
                                  ,0            --未就学児人数9月
                                  ,0            --未就学児人数10月
                                  ,0            --未就学児人数11月
                                  ,0            --未就学児人数12月
                                  ,0            --未就学児人数1月
                                  ,0            --未就学児人数2月
                                  ,0            --未就学児人数3月
                                  ,0            --医療均等割軽減額(未就学児)
                                  ,0            --医療均等割軽減額(未就学児)(退職)
                                  ,0            --支援均等割軽減額(未就学児)
                                  ,0            --支援均等割軽減額(未就学児)(退職)
                                  --  2024/05/07 ZCZL.ZHANGLEI ADD START 0.3.000.100:国保２次にマージ作業
                                  ,0            --医療産前産後均等割軽減額計
                                  ,0            --医療産前産後所得割軽減額計
                                  ,0            --介護産前産後均等割軽減額計
                                  ,0            --介護産前産後所得割軽減額計
                                  ,0            --支援産前産後均等割軽減額計
                                  ,0            --支援産前産後所得割軽減額計
                                  --  2024/05/07 ZCZL.ZHANGLEI ADD END
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                                  ,0            -- 子ども年齢軽減
                                  ,0            -- 子ども身障減免
                                  ,0            -- 子ども所得割積算軽減額(被扶養者)
                                  ,0            -- 子ども資産割積算軽減額(被扶養者)
                                  ,0            -- 子ども均等割積算軽減額(被扶養者)
                                  ,0            -- 子ども平等割積算軽減額(被扶養者/特定同一)
                                  ,0            -- 子ども均等割軽減額(未就学児)
                                  ,0            -- 子ども産前産後均等割軽減額計
                                  ,0            -- 子ども産前産後所得割軽減額計
                                  ,0            -- 18歳以上人数最新
                                  ,0            -- 18歳以上人数賦課期日
                                  ,0            -- 18歳以上人数賦課発生時
                                  ,0            -- 18歳以上人数4月
                                  ,0            -- 18歳以上人数5月
                                  ,0            -- 18歳以上人数6月
                                  ,0            -- 18歳以上人数7月
                                  ,0            -- 18歳以上人数8月
                                  ,0            -- 18歳以上人数9月
                                  ,0            -- 18歳以上人数10月
                                  ,0            -- 18歳以上人数11月
                                  ,0            -- 18歳以上人数12月
                                  ,0            -- 18歳以上人数1月
                                  ,0            -- 18歳以上人数2月
                                  ,0            -- 18歳以上人数3月
                                  ,0            -- 18歳以上均等割軽減額
                                  ,0            -- 18歳未満人数最新
                                  ,0            -- 18歳未満人数4月
                                  ,0            -- 18歳未満人数5月
                                  ,0            -- 18歳未満人数6月
                                  ,0            -- 18歳未満人数7月
                                  ,0            -- 18歳未満人数8月
                                  ,0            -- 18歳未満人数9月
                                  ,0            -- 18歳未満人数10月
                                  ,0            -- 18歳未満人数11月
                                  ,0            -- 18歳未満人数12月
                                  ,0            -- 18歳未満人数1月
                                  ,0            -- 18歳未満人数2月
                                  ,0            -- 18歳未満人数3月
                                  ,0            -- 18歳未満均等割軽減額
--2025/08/11 ZCZL.LIUHUAJUN ADD END
                              FROM ZLBTEXT_N
                             WHERE KOKU_SETAI_NO   =  RwKIHONN.KOKU_SETAI_NO
                               AND SANTEIDANTAI_CD =  RwKIHONN.SANTEIDANTAI_CD
                               AND CHOTEI_NENDO    =  RwKIHONN.CHOTEI_NENDO
                               AND NENDO_BUN       =  RwKIHONN.NENDO_BUN
                               AND TSUCHI_NO       =  RwKIHONN.TSUCHI_NO;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NULL;
                        WHEN OTHERS THEN
                            NwRTN     := c_NERR;
                            VlMSG := 'funcMakeCal 計算拡張登録' ||
                                         '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                         ')' || SQLERRM;
                            EXIT;
                    END;

                    --現年度処理で特徴実施中であれば特徴中止情報の作成および翌年度仮徴収のクリア
                    NwRTN := funcMakeCal_Toku(RwKIHONN, NwSYSDATE, NwSYSTIME);
                    IF NwRTN = c_NERR THEN
                      EXIT;
                    END IF;
                END IF;

            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                NwRTN := c_NERR;
                VlMSG := 'funcMakeCal 賦課基本取得' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
        END;

        RETURN(NwRTN);

    END funcMakeCal;
-------------------------------------------------------------------------------
-- 15-3 システム条件の読込み(税率条件取得)
-------------------------------------------------------------------------------
    FUNCTION funcJokenSel2(i_NwDANTAI IN NUMBER) RETURN NUMBER IS

        NwDANTAI        NUMBER;

    BEGIN

        -- 不均一課税か否か判定
        IF NlFUKI_KAZEI = c_NFKAZEI THEN        -- 不均一課税を行なう
            -- パラメータの算定団体で取得する
            NwDANTAI := i_NwDANTAI;
        ELSE
            -- 算定団体'1'で取得する
            NwDANTAI := c_NDANTAI;
        END IF;

        -- システム条件より税率条件を取得
        SELECT SHOTOKU_IRY,     -- 医療所得割率
               SHISAN_IRY,      -- 医療資産割率
               SHOTOKU_KAI,     -- 介護所得割率
               SHISAN_KAI,      -- 介護資産割率
               SHOKAICHU,             -- 所得照会中所得取扱
               SHOTOKU_IRY_OVER,      -- 医療所得割率(判定額超)
               SHOTOKU_KAI_OVER,      -- 介護所得割率(判定額超)
               SHOTOKU_HANTEI_GAKU,   -- 所得割判定額
               SHOTOKU_2DANKAI        -- 所得割2段階
               ,
               SHOTOKU_SIEN,          -- 支援所得割率
               SHISAN_SIEN,           -- 支援資産割率
               SHOTOKU_SIEN_OVER      -- 支援所得割率(判定額超)
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
               , NVL(SHOTOKU_KDM, 0)
               , NVL(SHISAN_KDM, 0)
               , NVL(SHOTOKU_KDM_OVER, 0)
--2025/08/11 ZCZL.LIUHUAJUN ADD END
               ,NUSHI_KAZEI           --主課税
               ,SHOTOKU_HOSHIKI     --所得割方式
          INTO NlSHOTOKU_IRY,
               NlSHISANWARI_IRY,
               NlSHOTOKU_KAI,
               NlSHISANWARI_KAI,
               ISHOKAICHU,            -- 所得照会中所得取扱
               NlSHOTOKU_IRY_OVER,    -- 医療所得割率(判定額超)
               NlSHOTOKU_KAI_OVER,    -- 介護所得割率(判定額超)
               NlSHOTOKU_HANTEI_GAKU, -- 所得割判定額
               NlSHOTOKU_2DANKAI      -- 所得割2段階*/
               ,
               NlSHOTOKU_SIEN,        -- 支援所得割率
               NlSHISANWARI_SIEN,     -- 支援資産割率
               NlSHOTOKU_SIEN_OVER    -- 支援所得割率(判定額超)
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
               , NlSHOTOKU_KDM
               , NlSHISANWARI_KDM
               , NlSHOTOKU_KDM_OVER
--2025/08/11 ZCZL.LIUHUAJUN ADD END
               ,NlNUSHI_KAZEI         --主課税
               ,NlSHOTOKU_HOSHIKI     --所得割方式
          FROM ZLBTJOKEN
             WHERE NENDO           = NlNENDO_BUN
               AND SANTEIDANTAI_CD = NwDANTAI;
        RETURN(c_NOK);
    EXCEPTION
        WHEN OTHERS THEN
            VlMSG := 'funcJokenSel2 システム条件の取得' ||
                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                     ')' || SQLERRM;
            RETURN(c_NERR);
    END funcJokenSel2;
-------------------------------------------------------------------------------
-- 15-2 システム条件の読込み(賦課期日と不均一課税取得)
-------------------------------------------------------------------------------
    PROCEDURE subJokenSel IS
    BEGIN
        SELECT FUKAKIJITSU,     -- 賦課期日
               FUKI_KAZEI,      -- 不均一課税
               KISOKOJO         -- 基礎控除
          INTO NlFUKAKIJITU,
               NlFUKI_KAZEI,
               NlKISOKOJO
          FROM ZLBTJOKEN
         WHERE NENDO = NlNENDO_BUN
           AND SANTEIDANTAI_CD = c_NDANTAI;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subJokenSel システム条件の取得 ' || SQLERRM || ' ' || NlNENDO_BUN;
    END subJokenSel;
-------------------------------------------------------------------------------
-- 15-1 システム条件の読込み(過年度課税計算対象年度算出)
-------------------------------------------------------------------------------
    PROCEDURE subGetNendo IS

        NwKANENDO_TAISHO_ZO     NUMBER;         -- 増額対象年数
        NwKANENDO_TAISHO_GEN    NUMBER;         -- 減額対象年数

    BEGIN
        -- システム条件を調定年度,最小算定団体コードで読込み

        SELECT MAX(KANENDO_TAISHO_ZO),
               MAX(KANENDO_TAISHO_GEN)
          INTO NwKANENDO_TAISHO_ZO,
               NwKANENDO_TAISHO_GEN
          FROM ZLBTJOKEN
         WHERE NENDO           = i_NCHOTEI_NENDO;

        -- 増額対象年度,減額対象年度,対象年度を算出
        NlNENDO_ZO  := i_NCHOTEI_NENDO - NwKANENDO_TAISHO_ZO;     -- 増額対象年度
        NlNENDO_GEN := i_NCHOTEI_NENDO - NwKANENDO_TAISHO_GEN;    -- 減額対象年度

        -- 対象年度は上記算出年度の小さい方
        IF NlNENDO_ZO < NlNENDO_GEN THEN

            NlTAISHO_NENDO := NlNENDO_ZO;

        ELSE

            NlTAISHO_NENDO := NlNENDO_GEN;

        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subGetNendo 対象年度取得 ' || SQLERRM;
    END subGetNendo;
-------------------------------------------------------------------------------
-- 14 年齢算出
-------------------------------------------------------------------------------
    FUNCTION funcNenrei(i_NTANJO    IN NUMBER) RETURN NUMBER IS

        NwNENREI        NUMBER(3);

    BEGIN

       IF i_NTANJO > 0 THEN
           NwNENREI := KKAPK0020.FAgeGet(TO_CHAR(i_NTANJO),TO_CHAR(i_NKIJUNBI));   -- 年齢取得
       ELSE
           NwNENREI := NULL;
       END IF;

        IF NwNENREI IS NULL THEN
            NwNENREI := 0;
        END IF;

        RETURN(NwNENREI);

    END funcNenrei;
-------------------------------------------------------------------------------
-- 13 更正日取得(固定資産)
-------------------------------------------------------------------------------
    PROCEDURE subKoteiGet(i_NKOJIN_NO        IN      NUMBER,
                          io_NJIYU           IN OUT  NUMBER,
                          io_NKOSEI          IN OUT  NUMBER,
                          i_NSHISANWARI      IN      NUMBER,
                          i_NKAI_SHISANWARI  IN      NUMBER,
                          i_NSIEN_SHISANWARI IN      NUMBER,
                          i_NKOKU_SETAI_NO   IN      NUMBER,
                          i_NSANTEIDANTAI_CD IN      NUMBER,
--2025/08/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応
--                          i_NlTSUCHI_NO      IN      NUMBER) IS
                          i_NlTSUCHI_NO      IN      NUMBER
                          ,i_NKDM_SHISANWARI IN      NUMBER
                          ) IS
--2025/08/11 ZCZL.LIUHUAJUN UPDATE END

        NwKOSEI           NUMBER(8);
    NwSHISANWARI_S    NUMBER;
    NwKAI_SHISANWARI_S  NUMBER;
    NwSIEN_SHISANWARI_S  NUMBER;
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
    NwKDM_SHISANWARI_S   NUMBER;
    BEGIN

    NwSHISANWARI_S := 0;
    NwKAI_SHISANWARI_S := 0;
    NwSIEN_SHISANWARI_S := 0;
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
    NwKDM_SHISANWARI_S := 0;

    BEGIN
      -- 賦課個人より資産割取得
--2025/08/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応
--            SELECT SHISAN_WARI, KAI_SHISAN_WARI, SIEN_SHISAN_WARI INTO NwSHISANWARI_S, NwKAI_SHISANWARI_S, NwSIEN_SHISANWARI_S
            SELECT SHISAN_WARI, KAI_SHISAN_WARI, SIEN_SHISAN_WARI, KDM_SHISAN_WARI 
              INTO NwSHISANWARI_S, NwKAI_SHISANWARI_S, NwSIEN_SHISANWARI_S, NwKDM_SHISANWARI_S
--2025/08/11 ZCZL.LIUHUAJUN UPDATE END
              FROM ZLBTKOJIN_N
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND KOJIN_NO        = i_NKOJIN_NO
               AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
               AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NlTSUCHI_NO;
        EXCEPTION
            WHEN OTHERS THEN
        NULL;
        END;

    IF i_NSHISANWARI <> NwSHISANWARI_S OR i_NKAI_SHISANWARI <> NwKAI_SHISANWARI_S
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
                                            OR i_NKDM_SHISANWARI <> NwKDM_SHISANWARI_S
                                            OR i_NSIEN_SHISANWARI <> NwSIEN_SHISANWARI_S THEN
          -- 課税基本より更正日の最大を取得
          BEGIN
            IF NlNENDO_BUN < 2006 THEN
              SELECT MAX(KOSEI_BI) INTO NwKOSEI
	              FROM ZEBTFKAZEIKIHONJL
               WHERE CHOTEI_NENDO     = i_NCHOTEI_NENDO       -- 調定年度
                 AND NENDOBUN         = NlNENDO_BUN           -- 年度分
                 AND GIMUSHA_KOJIN_NO = i_NKOJIN_NO           -- 義務者個人番号
                 AND SAKUJO_KBN       = 0                     -- 削除区分
                 AND KOSEI_BI         <= i_NKIJUNBI;
            ELSE
              SELECT MAX(KOSEI_BI) INTO NwKOSEI
	              FROM ZEBTFKAZEIKIHON
               WHERE CHOTEI_NENDO     = i_NCHOTEI_NENDO       -- 調定年度
                 AND NENDOBUN         = NlNENDO_BUN           -- 年度分
                 AND GIMUSHA_KOJIN_NO = i_NKOJIN_NO           -- 義務者個人番号
                 AND SAKUJO_KBN       = 0                     -- 削除区分
                 AND KOSEI_BI         <= i_NKIJUNBI;
            END IF;
          EXCEPTION
              WHEN OTHERS THEN
                  NwKOSEI := 0;
          END;

          IF io_NKOSEI < NwKOSEI THEN
              io_NKOSEI := NwKOSEI;
              io_NJIYU  := c_NJIYU_SHISANKOSEI;       -- 「資産更正」
              NlKOSEI_FLG := 2; --資産更正に該当
          END IF;
    END IF;

    END subKoteiGet;
-------------------------------------------------------------------------------
-- 12 異動日取得(所得)
-------------------------------------------------------------------------------
    PROCEDURE subShotokuGet(i_NKOJIN_NO IN      NUMBER,
                            io_NJIYU    IN OUT  NUMBER,
                            io_NKOSEI   IN OUT  NUMBER) IS

        NwKOSEI         NUMBER(8);
        NwKOSEI2        NUMBER(8);
    BEGIN

        -- 異動累計より異動日の最大を取得
        BEGIN
            SELECT MAX(IDO_BI) INTO NwKOSEI
              FROM ZABTIDORUIKEI
             WHERE NENDOBUN = NlNENDO_BUN
               AND KOJIN_NO = i_NKOJIN_NO
               AND IDO_BI  <= i_NKIJUNBI;
        EXCEPTION
            WHEN OTHERS THEN
                NwKOSEI := 0;
        END;

        -- 他部門より異動日の最大を取得
        BEGIN
            SELECT MAX(A.IDO_BI) INTO NwKOSEI2
            FROM (
                  SELECT IDO_BI FROM ZABTTABUMON C
                  WHERE KOJIN_NO = i_NKOJIN_NO
                    AND NENDOBUN = NlNENDO_BUN
                    AND GYOMU_CD = 'ZLB'
                  UNION ALL
                  SELECT IDO_BI FROM ZABTTABUMON_R D
                   WHERE KOJIN_NO = i_NKOJIN_NO
                     AND NENDOBUN = NlNENDO_BUN
                     AND GYOMU_CD = 'ZLB'
                 ) A
            WHERE A.IDO_BI  <= i_NKIJUNBI;
        EXCEPTION
            WHEN OTHERS THEN
                NwKOSEI2 := 0;
        END;

        -- 更正日が大きい方をセットする。
        IF NVL(NwKOSEI,0) < NVL(NwKOSEI2,0) THEN
            NwKOSEI := NwKOSEI2;
        END IF;

        IF io_NKOSEI < NwKOSEI THEN
            io_NKOSEI := NwKOSEI;
            io_NJIYU  := c_NJIYU_SHOTOKKOSEI;       -- 「所得更正」
            NlKOSEI_FLG := 1;  --所得更正に該当
        END IF;

    END subShotokuGet;

-------------------------------------------------------------------------------
-- xx 清算区分設定 清算フラグを立てる必要があるかチェックを行い必要であれば更新する。
-------------------------------------------------------------------------------
    FUNCTION funcSeisanSet(i_NKOKU_SETAI_NO   IN  NUMBER,
                           i_NSANTEIDANTAI_CD IN  NUMBER,
                           i_NNUSI_KOJIN_NO   IN  NUMBER) RETURN NUMBER IS

        NwRTN          NUMBER;       -- リターン値
        NwCOUNT        NUMBER;       -- カウンタ
        NwCOUNT_FUKA   NUMBER;       --カウンタ
        NwCOUNT_NUSI   NUMBER;       --カウンタ
        NwDATE_END     NUMBER(8);    -- 期末日(3/31)
        NwSEISAN       NUMBER;       -- 清算フラグ
        VERRMSN        NVARCHAR2(256);
    BEGIN
        NwRTN    := c_NOK;
        NwSEISAN := 0;

        BEGIN
            -- 計算基本の清算フラグを取得
            SELECT SEISAN_KBN INTO NwSEISAN FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
               AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
               AND NENDO_BUN       = NlNENDO_BUN
               AND TSUCHI_NO       = i_NNUSI_KOJIN_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
            WHEN OTHERS THEN
                NwRTN := c_NERR;
                VlMSG := 'funcSeisanSet 現在清算フラグ取得' ||
                         '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                         ')' || SQLERRM;
        END;

        IF NwRTN = 0 THEN
            NwCOUNT  := 0;

            -- 清算フラグが0ならば一応チェックしてみる。
            IF NwSEISAN = 0 THEN
                BEGIN
                    NwDATE_END := TO_NUMBER(TO_CHAR(NlNENDO_BUN + 1) || '0331'); -- 翌年+0331

                    -- 清算区分取得
                    SELECT COUNT(*) INTO NwCOUNT FROM ZLBTNUSHI_TMP
                    WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
                    AND NUSHI_KOJIN_NO = i_NNUSI_KOJIN_NO
                    AND NUSHI_TEKI_SBI = (
                        SELECT MAX(NUSHI_TEKI_SBI) FROM ZLBTNUSHI_TMP
                        WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
                        AND NUSHI_KOJIN_NO = i_NNUSI_KOJIN_NO
                        AND NUSHI_TEKI_SBI   <= NwDATE_END
                        AND SYS_TANMATSU_NO = i_VMASIN_NO)
                    AND SEISAN_FLAG = 1
                    AND SYS_TANMATSU_NO = i_VMASIN_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCALPACK',1, SQLCODE, SQLERRM,'funcSeisanSet 清算フラグ件数取得' ||'(国保世帯番号=' || i_NKOKU_SETAI_NO ||')' || SQLERRM, i_NSYS_SHOKUINKOJIN_NO, i_VMASIN_NO);
                END;
            END IF;

            IF NwCOUNT > 0 THEN
                -- 主課税の場合
                NwCOUNT_FUKA := 0;
                NwCOUNT_NUSI := 0;
                BEGIN
                    -- その年度の賦課基本が存在するか
                    SELECT COUNT(*) INTO NwCOUNT_FUKA
                    FROM ZLBTKIHON_N
                    WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
                    AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
                    AND NENDO_BUN       = NlNENDO_BUN;
                EXCEPTION
                    WHEN OTHERS THEN
                        NwRTN := c_NERR;
                        VlMSG := 'funcSeisanSet 賦課基本件数取得' ||
                                 '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                 ')' || SQLERRM;
                END;

                IF NwCOUNT_FUKA > 0 THEN
                    BEGIN
                        -- 該当の世帯主が賦課基本に存在するか？
                        SELECT COUNT(*) INTO NwCOUNT_NUSI
                        FROM ZLBTKIHON_N
                        WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
                        AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
                        AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
                        AND NENDO_BUN       = NlNENDO_BUN
                        AND NUSHI_KOJIN_NO   = i_NNUSI_KOJIN_NO;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NwRTN := c_NERR;
                            VlMSG := 'funcSeisanSet 賦課基本参照' ||
                                     '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                     ')' || SQLERRM;
                    END;
                END IF;

                IF NwCOUNT_FUKA > 0 AND NwCOUNT_NUSI = 0 THEN

                    -- 賦課基本に存在しなけば新規の主として清算フラグを立てる。
                    BEGIN
                        -- 計算基本を更新
                        UPDATE ZLBTKIHON_CAL SET SEISAN_KBN = 1
                         WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                           AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
                           AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
                           AND NENDO_BUN       = NlNENDO_BUN
                           AND TSUCHI_NO       = i_NNUSI_KOJIN_NO
                           AND SYS_TANMATSU_NO = i_VMASIN_NO;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NwRTN := c_NERR;
                            VlMSG := 'funcSeisanSet 清算フラグ更新' ||
                                     '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                     ')' || SQLERRM;
                    END;
                END IF;
            END IF;
        END IF;

        RETURN(NwRTN);

    END funcSeisanSet;
-------------------------------------------------------------------------------
-- 11 通知書番号取得
-------------------------------------------------------------------------------
    FUNCTION funcTsuchiGet(i_NKOKU_SETAI_NO   IN  NUMBER,
                           i_NSANTEIDANTAI_CD IN  NUMBER,
                           i_NNUSI_KOJIN_NO   IN  NUMBER) RETURN NUMBER IS

        NwRTN           NUMBER;
        NwRNO           NUMBER;
        NwYOKU_TSUCHI_NO  NUMBER;
        RwKIHON         ZLBTKIHON_CAL%ROWTYPE;
        NGENMEN_CNT     NUMBER;
        NGENMEN_KJN_CNT NUMBER;

    BEGIN
        NwRTN       := 0;
        NlTSUCHI_NO := 0;

        IF NlNUSHI_KAZEI = 1 THEN  -- 主課税する場合は、チェックを通す 2009/08/31
          -- 清算フラグチェック＆更新
          NwRTN := funcSeisanSet(i_NKOKU_SETAI_NO, i_NSANTEIDANTAI_CD, i_NNUSI_KOJIN_NO);
        ELSE
          NwRTN := c_NOK;
        END IF;

        IF NwRTN = c_NOK THEN

        BEGIN
            -- 計算基本を取得
            SELECT * INTO RwKIHON FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
               AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
               AND NENDO_BUN       = NlNENDO_BUN
               AND TSUCHI_NO       = i_NNUSI_KOJIN_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO;

            -- 通知書番号振付
            NwRTN := ZLBFKGETTCH(RwKIHON.KOKU_SETAI_NO,       -- IN :国保世帯番号
                                   RwKIHON.SANTEIDANTAI_CD,     --     算定団体コード
                                   RwKIHON.CHOTEI_NENDO,        --     調定年度
                                   RwKIHON.NENDO_BUN,           --     年度分
                                   RwKIHON.SEISAN_KBN,          --     清算区分
                                   RwKIHON.NUSHI_KOJIN_NO,      --     世帯主個人番号
                                   NlMAX_TSUCHI_NO,             --     比較用通知書番号
                                   NlTSUCHI_NO,                 -- OUT:通知書番号
                                   NwRNO);                      --     履歴番号
            IF NwRTN != c_NOK THEN
                NwRTN := c_NERR;
                VlMSG := 'funcTsuchiGet 通知書番号取得' ||
                         '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                         ')ZLBFKGETTCH:取得失敗';
            END IF;

            -- 最大通知書番号を退避
            IF NwRTN = c_NOK AND NlMAX_TSUCHI_NO < NlTSUCHI_NO THEN
                NlMAX_TSUCHI_NO := NlTSUCHI_NO;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                NwRTN := c_NERR;
                VlMSG := 'funcTsuchiGet 通知書番号取得' ||
                         '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                         ')' || SQLERRM;
        END;

        END IF;

    -- 通知書番号の更新
        IF NwRTN = c_NOK THEN
            BEGIN
                -- 計算基本
                -- 翌年度分の通知書番号が既に設定されていれば、取得しセット
                BEGIN
                  SELECT YOKU_TSUCHI_NO INTO NwYOKU_TSUCHI_NO
                        FROM ZLBTKIHON_N
                        WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                          AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                          AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
                          AND NENDO_BUN       = i_NNENDO_BUN
                          AND TSUCHI_NO       = NlTSUCHI_NO;

                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                       NwYOKU_TSUCHI_NO := 0;
                  WHEN OTHERS THEN
                      NwRTN := c_NERR;
                      VlMSG := 'funcTsuchiGet 賦課基本ＴＢＬより翌年通知書番号取得' ||
                               '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                               ')' || SQLERRM;
                END;

                UPDATE ZLBTKIHON_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       YOKU_TSUCHI_NO = NwYOKU_TSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;

                -- 計算退職
                UPDATE ZLBTTAI_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;

                -- 計算介護基本
                UPDATE ZLBTKAI_KIHON_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;

                -- 計算介護退職
                UPDATE ZLBTKAI_TAI_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;

                -- 計算支援基本
                UPDATE ZLBTSIEN_KIHON_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;

                -- 計算支援退職
                UPDATE ZLBTSIEN_TAI_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;

--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                -- 計算子ども基本
                UPDATE ZLBTKDM_KIHON_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
                -- 計算個人
                UPDATE ZLBTKOJIN_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;

                -- 計算所得
                UPDATE ZLBTSHOTOKU_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
                -- 計算拡張
                UPDATE ZLBTEXT_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
                UPDATE ZLBTKANWA_KOJIN_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
                UPDATE ZLBTKANWA_SETAI_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO,
                       R_NO      = NwRNO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    NwRTN := c_NERR;
                    VlMSG := 'funcTsuchiGet 計算テーブル更新' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
            END;

        END IF;

    -- 減免個人通知書番号の更新
        NGENMEN_CNT := 0;
        IF NwRTN = c_NOK THEN
          BEGIN
            SELECT COUNT(*) INTO NGENMEN_CNT
              FROM ZLBTGENMEN_KOJIN_CAL
             WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
               AND SYS_TANMATSU_NO = i_VMASIN_NO;
          EXCEPTION
            WHEN OTHERS THEN
              NGENMEN_CNT := 0;
          END;
          IF  NGENMEN_CNT  > 0 THEN
             --計算減免個人データが存在する場合
            BEGIN
              SELECT COUNT(*) INTO NGENMEN_KJN_CNT
                FROM ZLBTGENMEN_KOJIN_CAL
               WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                 AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                 AND SYS_TANMATSU_NO = i_VMASIN_NO
--2024/09/23 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00020
                 --AND TEKIYO_KBN = 1
                 AND TEKIYO_KBN IN (1, 3)
                 AND YUSEN_KBN = 0;
            EXCEPTION
              WHEN OTHERS THEN
                NGENMEN_KJN_CNT := 0;
            END;

            IF NGENMEN_KJN_CNT > 0 THEN
            --優先区分＝0（個人/率/応能応益）の場合
              BEGIN
                UPDATE ZLBTGENMEN_KOJIN_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
              EXCEPTION
                WHEN OTHERS THEN
                  --減免個人が存在しない場合エラーとならないようにする。
                   NULL;
              END;
            ELSE
            --優先区分!＝0（個人/率/応能応益）以外の場合
              BEGIN
                UPDATE ZLBTGENMEN_KOJIN_CAL
                   SET TSUCHI_NO = NlTSUCHI_NO
                 WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                   AND TSUCHI_NO       = RwKIHON.NUSHI_KOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
              EXCEPTION
                WHEN OTHERS THEN
                  --減免個人が存在しない場合エラーとならないようにする。
                   NULL;
              END;
            END IF;
          END IF;
        END IF;

        RETURN(NwRTN);

    END funcTsuchiGet;
-------------------------------------------------------------------------------
-- 10 固定資産税額セット
-------------------------------------------------------------------------------
    FUNCTION funcKoteiSet(i_NKOKU_SETAI_NO IN NUMBER) RETURN NUMBER IS

        NwRTN               NUMBER;
        NwDANTAI            NUMBER;
        NwSHISANZEI         NUMBER;
        NwISHISANWARI       NUMBER;     -- 医療資産割額
        NwKSHISANWARI       NUMBER;     -- 介護資産割額
        NwSHOTOKU_WARI      NUMBER;     -- 所得割額
        NwKAI_SHOTOKU_WARI  NUMBER;     -- 介護所得割額
        NwSSHISANWARI       NUMBER;     -- 支援資産割額
        NwSIEN_SHOTOKU_WARI NUMBER;     -- 支援所得割額
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
        NwKDM_SHISAN_WARI   NUMBER;     -- 子ども資産割額
        NwKDM_SHOTOKU_WARI  NUMBER;     -- 子ども所得割額
--2025/08/11 ZCZL.LIUHUAJUN ADD END
        -- 計算個人カーソル
        CURSOR CwKOJIN IS
            SELECT * FROM ZLBTKOJIN_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO
             ORDER BY SANTEIDANTAI_CD, KOJIN_NO;

    BEGIN
        NwRTN    := c_NOK;
        NwDANTAI := 0;          -- 算定団体

        FOR RwKOJIN IN CwKOJIN LOOP

            NwSHISANZEI        := 0;
            NwISHISANWARI      := 0;
            NwKSHISANWARI      := 0;
            NwSHOTOKU_WARI     := 0;
            NwKAI_SHOTOKU_WARI := 0;
            NwSSHISANWARI      := 0;
            NwSIEN_SHOTOKU_WARI := 0;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
            NwKDM_SHISAN_WARI  := 0;
            NwKDM_SHOTOKU_WARI := 0;
--2025/08/11 ZCZL.LIUHUAJUN ADD END

            -- 算定団体コードが変わったらシステム条件を再取得
            IF RwKOJIN.SANTEIDANTAI_CD != NwDANTAI THEN

                -- システム条件取得2(税率条件取得)
                NwRTN := funcJokenSel2(RwKOJIN.SANTEIDANTAI_CD);    -- 15-3 システム条件取得

                NwDANTAI := RwKOJIN.SANTEIDANTAI_CD;        -- 取得した算定団体を保持

            END IF;

            -- 所得割額を算出
            IF NwRTN = c_NOK THEN
                -- 所得２段階の場合は、個人税額は０とする。
                IF NlSHOTOKU_2DANKAI = 1 THEN -- 所得割2段階対応する
                  NwSHOTOKU_WARI     := 0;  -- 医療
                  NwKAI_SHOTOKU_WARI := 0;  -- 介護
                  NwSIEN_SHOTOKU_WARI := 0; -- 支援
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
                  NwKDM_SHOTOKU_WARI := 0;  -- 子ども
                ELSE
                  NwSHOTOKU_WARI     := TRUNC(RwKOJIN.KAHYO * (NlSHOTOKU_IRY / 100));   -- 医療
                  NwKAI_SHOTOKU_WARI := TRUNC(RwKOJIN.KAHYO * (NlSHOTOKU_KAI / 100));   -- 介護
                  NwSIEN_SHOTOKU_WARI := TRUNC(RwKOJIN.KAHYO * (NlSHOTOKU_SIEN / 100)); -- 支援
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
                  NwKDM_SHOTOKU_WARI := TRUNC(RwKOJIN.KAHYO * (NlSHOTOKU_KDM / 100));   -- 子ども
                END IF;

            END IF;

            IF NwRTN = c_NOK AND NlSHISANWARI_IRY > 0 THEN        -- 資産割率(医療)を判断
              IF i_NNOUKI_KBN = c_NNOUKI_KARISAN THEN
                -- 資産税編集読込み
                ZLBSKKOTGET(c_GYOMU_CD,                -- 業務コード(固定)
                             RwKOJIN.KOJIN_NO,          -- 個人番号
                             NlNENDO_BUN -1 ,           -- 年度分
                             RwKOJIN.SANTEIDANTAI_CD,   -- 算定団体コード
                             i_NKIJUNBI,                -- 基準日
                             NwSHISANZEI,
                             NwRTN);            -- 資産税編集読込み(1:OK etc:NG)
              ELSE
                -- 資産税編集読込み
                ZLBSKKOTGET(c_GYOMU_CD,                -- 業務コード(固定)
                             RwKOJIN.KOJIN_NO,          -- 個人番号
                             NlNENDO_BUN,               -- 年度分
                             RwKOJIN.SANTEIDANTAI_CD,   -- 算定団体コード
                             i_NKIJUNBI,                -- 基準日
                             NwSHISANZEI,
                             NwRTN);            -- 資産税編集読込み(1:OK etc:NG)
              END IF;

                IF NwRTN = 1 THEN       -- 1が正常
                    NwRTN := c_NOK;
                    NwSHISANZEI := NVL(NwSHISANZEI, 0);
                ELSE
                    NwRTN := c_NERR;
                END IF;

                -- 各項目の編集
                IF NwRTN = c_NOK THEN
                    -- 資産割額
                    NwISHISANWARI := TRUNC(NwSHISANZEI * NlSHISANWARI_IRY / 100);

                    -- 介護資産割額
                    IF NlSHISANWARI_KAI > 0 THEN        -- 資産割率(介護)を判断
                        NwKSHISANWARI := TRUNC(NwSHISANZEI * NlSHISANWARI_KAI / 100);
                    END IF;

                    -- 支援資産割額
                    IF NlSHISANWARI_SIEN > 0 THEN        -- 資産割率(支援)を判断
                        NwSSHISANWARI := TRUNC(NwSHISANZEI * NlSHISANWARI_SIEN / 100);
                    END IF;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                    -- 子ども資産割額
                    IF NlSHISANWARI_KDM > 0 THEN        -- 資産割率(子ども)を判断
                        NwKDM_SHISAN_WARI := TRUNC(NwSHISANZEI * NlSHISANWARI_KDM / 100);
                    END IF;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
                END IF;

            END IF;

            -- 計算個人更新
            IF NwRTN = c_NOK THEN
                BEGIN
                    UPDATE ZLBTKOJIN_CAL SET
                           SHOTOKU_WARI     = NwSHOTOKU_WARI,       -- 所得割額
                           KAI_SHOTOKU_WARI = NwKAI_SHOTOKU_WARI,   -- 介護所得割額
                           SHISANZEI        = NwSHISANZEI,          -- 資産税額
                           SHISAN_WARI      = NwISHISANWARI,        -- 資産割額
                           KAI_SHISAN_WARI  = NwKSHISANWARI,         -- 介護資産割額
                           SIEN_SHOTOKU_WARI = NwSIEN_SHOTOKU_WARI,  -- 支援所得割額
                           SIEN_SHISAN_WARI  = NwSSHISANWARI         -- 支援資産割額
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                           , KDM_SHOTOKU_WARI = NwKDM_SHOTOKU_WARI  -- 子ども所得割額
                           , KDM_SHISAN_WARI  = NwKDM_SHISAN_WARI   -- 子ども資産割額
--2025/08/11 ZCZL.LIUHUAJUN ADD END
                     WHERE KOKU_SETAI_NO   = RwKOJIN.KOKU_SETAI_NO
                       AND KOJIN_NO        = RwKOJIN.KOJIN_NO
                       AND SANTEIDANTAI_CD = RwKOJIN.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKOJIN.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKOJIN.NENDO_BUN
                       AND TSUCHI_NO       = RwKOJIN.TSUCHI_NO
                       AND SYS_TANMATSU_NO = RwKOJIN.SYS_TANMATSU_NO;
                EXCEPTION
                    WHEN OTHERS THEN
                        NwRTN := c_NERR;
                        VlMSG := 'funcKoteiSet 計算個人更新' ||
                                 '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                 ')' || SQLERRM;
                END;
            END IF;

            EXIT WHEN NwRTN != c_NOK;

        END LOOP;

        RETURN(NwRTN);

    EXCEPTION
        WHEN OTHERS THEN
            VlMSG := 'funcKoteiSet 計算個人更新(固定資産)' ||
                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                     ')' || SQLERRM;
            RETURN(c_NERR);
    END funcKoteiSet;
-------------------------------------------------------------------------------
-- 09 本算定判定
--     ①本算定時、更正日・事由を再セット
--     ②老人の判定(65歳以上)をして計算個人の老年者区分を更新
-------------------------------------------------------------------------------
    FUNCTION funcEtcSet(i_NKOKU_SETAI_NO    IN  NUMBER,
                        i_NKOJIN_NO         IN  NUMBER) RETURN NUMBER IS

        NwRTN                   NUMBER(1);
        NwTANJOBI               NUMBER(8);  -- 誕生日
        NwNENREI                NUMBER(3);  -- 年齢
        NwKOSEI_BI              NUMBER(8);
        NwJIYU                  NUMBER(2);
        NwKAI_KOSEI_BI          NUMBER(8);
        NwKAI_JIYU              NUMBER(2);
        NwRONEN_KBN             NUMBER(3);
        NwKAI_GAI_BI            NUMBER(8);  -- 介護該当日
        NwKAI_HIGAI_BI          NUMBER(8);  -- 介護非該当日

        -- 計算個人カーソル
        CURSOR CwKOJIN IS
            SELECT DISTINCT KOSEI_BI, JIYU, KAI_KOSEI_BI, KAI_JIYU, RONEN_KBN,
                   KAI_GAI_BI, KAI_HIGAI_BI,TSUCHI_NO
              FROM ZLBTKOJIN_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND KOJIN_NO        = i_NKOJIN_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO;
    BEGIN
      NwRTN     := c_NOK;

      FOR RwKOJIN IN CwKOJIN LOOP
        NwTANJOBI := 0;
        NwNENREI  := 0;

        NwKOSEI_BI := RwKOJIN.KOSEI_BI;
        NwJIYU := RwKOJIN.JIYU;
        NwKAI_KOSEI_BI := RwKOJIN.KAI_KOSEI_BI;
        NwKAI_JIYU := RwKOJIN.KAI_JIYU;
        NwRONEN_KBN := RwKOJIN.RONEN_KBN;
        NwKAI_GAI_BI := RwKOJIN.KAI_GAI_BI;
        NwKAI_HIGAI_BI := RwKOJIN.KAI_HIGAI_BI;

        IF NwRTN = c_NOK THEN
            -- 本算定時のみ更正事由の変更
            IF i_NNOUKI_KBN = c_NNOUKI_HONSAN THEN      -- 本算定
                IF NwKAI_GAI_BI = 0 AND NwKAI_HIGAI_BI = 0 THEN     -- 介護なし

                    NwKOSEI_BI   := i_NKIJUNBI;         -- 更正日←基準日
                    NwJIYU       := c_NJIYU_HONSAN;     -- 更正事由←「本算定」

                ELSE                                                -- 介護含む

                    NwKOSEI_BI     := i_NKIJUNBI;         -- 更正日←基準日
                    NwJIYU         := c_NJIYU_HONSAN;     -- 更正事由←「本算定」
                    NwKAI_KOSEI_BI := i_NKIJUNBI;         -- 介護更正日←基準日
                    NwKAI_JIYU     := c_NJIYU_HONSAN;     -- 介護更正事由←「本算定」

                END IF;
            END IF;

            -- 老人判定
            BEGIN
                -- 個人番号で宛名基本を参照し生年月日を取得
                SELECT SEINENGAPI INTO NwTANJOBI FROM GABTATENAKIHON
                 WHERE KOJIN_NO = i_NKOJIN_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    NwTANJOBI := 0;
            END;

            NwNENREI := funcNenrei(NwTANJOBI);      -- 14 年齢算出

            IF NwNENREI >= c_NRONEN_NENREI THEN
                NwRONEN_KBN := c_NRONENKBN_4;         -- 老年区分変更
            END IF;

            BEGIN
                UPDATE ZLBTKOJIN_CAL
                   SET KOSEI_BI     = NwKOSEI_BI,
                       JIYU         = NwJIYU,
                       KAI_KOSEI_BI = NwKAI_KOSEI_BI,
                       KAI_JIYU     = NwKAI_JIYU,
                       RONEN_KBN    = NwRONEN_KBN
                 WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                   AND KOJIN_NO        = i_NKOJIN_NO
                   AND TSUCHI_NO    = RwKOJIN.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    NwRTN := c_NERR;
                    VlMSG := 'funcEtcSet 計算個人更新' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
            END;
        END IF;

        EXIT WHEN NwRTN != c_NOK;
      END LOOP;

        RETURN(NwRTN);

    END funcEtcSet;
-------------------------------------------------------------------------------
-- 08 事由セット
-------------------------------------------------------------------------------
    FUNCTION funcJiyuSet(i_NKOKU_SETAI_NO   IN  NUMBER,
                         i_NKOJIN_NO        IN  NUMBER) RETURN NUMBER IS

        NwRTN                   NUMBER(1);
        NwKAI_GAI_BI            NUMBER(8);      -- 介護該当日
        NwKAI_HIGAI_BI          NUMBER(8);      -- 介護非該当日
        NwKAI_KOSEI             NUMBER(8);      -- 介護更正日(計算TBL)
        NwZ_SHUTOKU_BI          NUMBER(8);      -- 取得日
        NwSHUTOKU_JIYU          NUMBER(2);      -- 取得事由
        NwSHUTOKU_TODOKE_BI     NUMBER(8);      -- 取得届出日
        NwZ_SOSHITSU_BI         NUMBER(8);      -- 喪失日
        NwSOSHITSU_JIYU         NUMBER(2);      -- 喪失事由
        NwSOSHITSU_TODOKE_BI    NUMBER(8);      -- 喪失届出日
        NwIDO_BI                NUMBER(8);      -- 異動日
        NwNEW_JIYU              NUMBER(2);      -- 最新事由
        NwNEW_TODOKE_BI         NUMBER(8);      -- 最新届出日
        NwSHIKAKU_JIYU          NUMBER(2);      -- 資格事由
        NwTODOKE_BI             NUMBER(8);      -- 届出日
        NwCAL_KOSEI             NUMBER(8);      -- 計算更正日
        NwCAL_JIYU              NUMBER(2);      -- 計算事由
        NwCAL_KOSEI_KAI         NUMBER(8);      -- 計算介護更正日
        NwCAL_JIYU_KAI          NUMBER(2);      -- 計算介護事由
        NwUP_KOSEI              NUMBER(8);      -- 変更更正日
        NwUP_JIYU               NUMBER(8);      -- 変更事由
        NwSHIKAKU_KOSEI         NUMBER;         --資格異動日
    NwR_NO          NUMBER;     -- 履歴No
    NwTAI_R_NO        NUMBER;     -- 退職履歴No

        -- 計算個人カーソル
        CURSOR CwKOJIN IS
            SELECT SHISAN_WARI, KAI_SHISAN_WARI, SIEN_SHISAN_WARI, SANTEIDANTAI_CD, TSUCHI_NO
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
                   ,KDM_SHISAN_WARI
              FROM ZLBTKOJIN_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND KOJIN_NO        = i_NKOJIN_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO;
    BEGIN
      NwRTN      := c_NOK;

      FOR RwKOJIN IN CwKOJIN LOOP
        NwUP_KOSEI := 0;        -- 変更更正日
        NwUP_JIYU  := 0;        -- 変更事由
        NlKOSEI_FLG := 0;       --更正フラグ

        -- 計算個人より介護該当日,介護非該当日,介護更正日を取得
        BEGIN
            SELECT DISTINCT KAI_GAI_BI,   KAI_HIGAI_BI,   KAI_KOSEI_BI
              INTO NwKAI_GAI_BI, NwKAI_HIGAI_BI, NwKAI_KOSEI
              FROM ZLBTKOJIN_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND KOJIN_NO        = i_NKOJIN_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO
               AND SANTEIDANTAI_CD = RwKOJIN.SANTEIDANTAI_CD
               AND TSUCHI_NO       = RwKOJIN.TSUCHI_NO;
        EXCEPTION
            WHEN OTHERS THEN
                NwKAI_GAI_BI   := 0;
                NwKAI_HIGAI_BI := 0;
                NwKAI_KOSEI    := 0;
        END;

        BEGIN
            NwR_NO := 0;
            NwTAI_R_NO := 0;
            -- ZLBTSHIKAKU_TMPから最新の資格履歴、退職資格履歴を取得する
            -- FIRST FETCH ROWのみ
            FOR vRec IN (SELECT R_NO, TAI_R_NO
                         FROM   ZLBTSHIKAKU_TMP
                         WHERE  KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                           AND  KOJIN_NO        = i_NKOJIN_NO
                           AND  SAKUJO_KBN      = 0
                           AND  SYS_TANMATSU_NO = i_VMASIN_NO
                         ORDER  BY R_NO DESC) LOOP
                NwR_NO := vRec.R_NO;
                NwTAI_R_NO := vRec.TAI_R_NO;
                EXIT;
            END LOOP;
            -- KHSTTAISHOKUから最新の退職資格履歴を再取得する
            -- FIRST FETCH ROWのみ
            FOR vRec IN (SELECT R_NO
                         FROM   KHSTTAISHOKU
                         WHERE  KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                           AND  KOJIN_NO        = i_NKOJIN_NO
                           AND  SHIK_R_NO       = NwR_NO
                           AND  SAKUJO_KBN      = 0
                           AND  SYS_TANMATSU_NO = i_VMASIN_NO
                         ORDER  BY R_NO DESC) LOOP
                NwTAI_R_NO := vRec.R_NO;
                EXIT;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
            NwR_NO := 0;
            NwTAI_R_NO := 0;
        END;

        -- 資格基本より最新の取得年月日,喪失年月日,事由を取得
        BEGIN
            SELECT Z_SHUTOKU_BI,    SHUTOKU_JIYU,    SHUTOKU_TODOKE_BI,
                   Z_SOSHITSU_BI,   SOSHITSU_JIYU,   SOSHITSU_TODOKE_BI,
                   IDO_BI,          JIYU,            TODOKE_BI
              INTO NwZ_SHUTOKU_BI,  NwSHUTOKU_JIYU,  NwSHUTOKU_TODOKE_BI,
                   NwZ_SOSHITSU_BI, NwSOSHITSU_JIYU, NwSOSHITSU_TODOKE_BI,
                   NwIDO_BI,        NwNEW_JIYU,      NwNEW_TODOKE_BI
              FROM ZLBTSHIKAKU_TMP
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND KOJIN_NO        = i_NKOJIN_NO
               AND R_NO            = NwR_NO
               AND TAI_R_NO        = NwTAI_R_NO
               AND SAKUJO_KBN      = 0
               AND SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
            WHEN OTHERS THEN
                NwZ_SHUTOKU_BI       := 0;
                NwSHUTOKU_JIYU       := 0;
                NwSHUTOKU_TODOKE_BI  := 0;
                NwZ_SOSHITSU_BI      := 0;
                NwSOSHITSU_JIYU      := 0;
                NwSOSHITSU_TODOKE_BI := 0;
                NwIDO_BI             := 0;
                NwNEW_JIYU           := 0;
                NwNEW_TODOKE_BI      := 0;
        END;

        -- 取得事由,喪失事由のセット
        IF NwSOSHITSU_TODOKE_BI = 0 THEN

            NwTODOKE_BI    := NwSHUTOKU_TODOKE_BI;      -- 届出日←取得届出日
            NwSHIKAKU_JIYU := NwSHUTOKU_JIYU;           -- 資格事由←取得事由
-- ①個人TBLの取得日・取得事由を住民税・固定資産税の事由取得用ワークにセット
            NwUP_JIYU  := NwSHIKAKU_JIYU;               -- 変更事由←取得事由
            NwUP_KOSEI := NwSHUTOKU_TODOKE_BI;               -- 変更更正日←取得届出日
            NwSHIKAKU_KOSEI := NwZ_SHUTOKU_BI;          --変更更正日←取得日

        ELSE

            NwTODOKE_BI    := NwSOSHITSU_TODOKE_BI;     -- 届出日←喪失届出日
            NwSHIKAKU_JIYU := NwSOSHITSU_JIYU;          -- 資格事由←喪失事由
-- ①個人TBLの喪失日・喪失事由を住民税・固定資産税の事由取得用ワークにセット
            NwUP_JIYU  := NwSOSHITSU_JIYU;              -- 変更事由←取得事由
            NwUP_KOSEI := NwSOSHITSU_TODOKE_BI;              -- 変更更正日←喪失届出日
            NwSHIKAKU_KOSEI := NwZ_SOSHITSU_BI;          --変更更正日←取得日

        END IF;

        IF i_NKIJUNBI <= NwTODOKE_BI THEN

            IF NwSOSHITSU_TODOKE_BI = NwTODOKE_BI THEN
                NwCAL_KOSEI := NwZ_SOSHITSU_BI;         -- 計算更正日←喪失日
            ELSE
                NwCAL_KOSEI := NwZ_SHUTOKU_BI;          -- 計算更正日←取得日
            END IF;
            NwCAL_JIYU := NwSHIKAKU_JIYU;               -- 計算事由←資格事由

        ELSIF i_NKIJUNBI <= NwNEW_TODOKE_BI AND
              NwNEW_JIYU >= c_NJIYU_SHOKAI  AND
              NwNEW_JIYU <= c_NJIYU_KYOSEI  THEN

            NwCAL_JIYU  := c_NJIYU_ETC;                 -- 計算事由←「その他内容変更」
            NwCAL_KOSEI := NwNEW_TODOKE_BI;             -- 計算更正日←最新届出日

        ELSE
            -- 所得税のデータより更正日を取得
            subShotokuGet(i_NKOJIN_NO,
                          NwUP_JIYU,
                          NwUP_KOSEI);  -- 12 異動日取得(所得)

            -- システム条件取得2(税率条件取得)
            IF RwKOJIN.SANTEIDANTAI_CD > 0 THEN
                NwRTN := funcJokenSel2(RwKOJIN.SANTEIDANTAI_CD);
            END IF;

            -- 賦課条件の資産割が0以上ならば資産税の更正を取得
            IF NlSHISANWARI_IRY > 0 OR NlSHISANWARI_KAI > 0 THEN
                 subKoteiGet(i_NKOJIN_NO,
                            NwUP_JIYU,
                            NwUP_KOSEI,
                            RwKOJIN.SHISAN_WARI,
                            RwKOJIN.KAI_SHISAN_WARI,
                            RwKOJIN.SIEN_SHISAN_WARI,
                            i_NKOKU_SETAI_NO,
                            RwKOJIN.SANTEIDANTAI_CD,
--2025/08/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応
--                            RwKOJIN.TSUCHI_NO);
                            RwKOJIN.TSUCHI_NO
                            ,RwKOJIN.KDM_SHISAN_WARI
                            );
--2025/08/11 ZCZL.LIUHUAJUN UPDATE END
            END IF;

            NwCAL_JIYU  := NwUP_JIYU;       -- 計算事由←「所得更正」or「資産更正」or0
            IF NlKOSEI_FLG = 0 THEN
              NwCAL_KOSEI := NwSHIKAKU_KOSEI;
            ELSE
              NwCAL_KOSEI := NwUP_KOSEI;
            END IF;
        END IF;

        IF NwCAL_KOSEI < NwIDO_BI AND NwCAL_KOSEI < NwNEW_TODOKE_BI THEN
          --ここまでで、取得した更正日より、異動日・届出日が新しい場合
            IF NwNEW_TODOKE_BI <= i_NKIJUNBI AND NwNEW_JIYU IN (51, 52, 53, 54, 55, 56) THEN
              --さらに基準日以前に届けられて、事由が退職・介護・適用除外　該当非該当の場合
                NwCAL_JIYU  := NwNEW_JIYU;                  -- 計算事由  ←異動事由そのまま
                NwCAL_KOSEI := NwNEW_TODOKE_BI;             -- 計算更正日←最新届出日
            END IF;
        END IF;

        -- 介護分
        IF NwKAI_GAI_BI = 0 AND NwKAI_HIGAI_BI = 0 THEN
            NwCAL_JIYU_KAI  := 0;               -- 計算介護更正事由
            NwCAL_KOSEI_KAI := 0;               -- 計算介護更正日
        -- 資格異動日>計算介護異動日であれば入替え
        ELSIF NwCAL_KOSEI > NwKAI_KOSEI THEN
            NwCAL_JIYU_KAI  := NwCAL_JIYU;      -- 計算介護更正事由←計算更正事由
            NwCAL_KOSEI_KAI := NwCAL_KOSEI;     -- 計算介護更正日←計算更正日
        END IF;

        -- 計算個人の更新
        IF NwCAL_KOSEI_KAI != 0 AND NwCAL_JIYU_KAI != 0 THEN
            -- 介護分も更新する
            BEGIN
                UPDATE ZLBTKOJIN_CAL
                   SET KOSEI_BI     = NwCAL_KOSEI,
                       JIYU         = NwCAL_JIYU,
                       KAI_KOSEI_BI = NwCAL_KOSEI_KAI,
                       KAI_JIYU     = NwCAL_JIYU_KAI
                 WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                   AND KOJIN_NO        = i_NKOJIN_NO
                   AND TSUCHI_NO       = RwKOJIN.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    NwRTN := c_NERR;
                    VlMSG := 'funcJiyuSet 計算個人更新(介護含む)' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
            END;
        ELSE
            -- 介護分は更新しない
            BEGIN
                UPDATE ZLBTKOJIN_CAL
                   SET KOSEI_BI = NwCAL_KOSEI,
                       JIYU     = NwCAL_JIYU
                 WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                   AND KOJIN_NO        = i_NKOJIN_NO
                   AND TSUCHI_NO       = RwKOJIN.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    NwRTN := c_NERR;
                    VlMSG := 'funcJiyuSet 計算個人更新' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
            END;
        END IF;

        IF NwRTN = c_NOK THEN
            BEGIN
                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                    NwRTN := c_NERR;
                    VlMSG := 'funcJiyuSet COMMIT発行' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
            END;
        END IF;
        IF NwRTN != c_NOK THEN
            BEGIN
                ROLLBACK;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
        END IF;

        EXIT WHEN NwRTN != c_NOK;
      END LOOP;

        RETURN(NwRTN);

    END funcJiyuSet;
-------------------------------------------------------------------------------
-- 07 所得セット
-------------------------------------------------------------------------------
    FUNCTION funcShotokuSet(i_NKOKU_SETAI_NO    IN  NUMBER,
                            i_NKOJIN_NO         IN  NUMBER,
                            i_NNEW_SHITSU_KBN   IN  NUMBER) RETURN NUMBER IS

        NwRTN                   NUMBER;
        NwSENJU_KBN             NUMBER;         -- 専従区分
        NwRONENSHA_KBN          NUMBER;         -- 老年者区分
        NwSHINKOKU_KBN          NUMBER;         -- 申告区分
        NwMINZEI_KAZEI_KBN      NUMBER;         -- 住民税課税区分
        NwMINZEI_SHOTOKUWARI    NUMBER;         -- 住民税所得割
        NwMINZEI_KINTOWARI      NUMBER;         -- 住民税均等割
        NwKOSEIBI               NUMBER;         -- 更正日
        NwKOKUHO_SHOTOKU        NUMBER;         -- 国保用所得
        NwKEIGENHANTEI_SHOTOKU  NUMBER;         -- 軽減判定所得
        NwKAHYO                 NUMBER;         -- 課税標準額
        NwSHU_SHOTOKU_KBN       NUMBER;         -- 主所得区分
        NwSHU_SHOTOKU           NUMBER;         -- 主所得額
        NwJIKKOU_KBN            NUMBER;         --実行区分
        NwKOKUHO_SHOTOKU_SHITSU       NUMBER;   -- 失業軽減適用後国保用所得
        NwKEIGENHANTEI_SHOTOKU_SHITSU NUMBER;   -- 失業軽減適用後軽減判定所得
        NwKAHYO_SHITSU                NUMBER;   -- 失業軽減適用後課税標準額

        NwKOJO_GOKEI                  NUMBER;
        NwSANTEIDANTAI_CD             NUMBER;   --算定団体コード
        NwSANTEIDANTAI_CD_4           NUMBER;   --算定団体コード４月
        NwSANTEIDANTAI_CD_9           NUMBER;   --算定団体コード９月
        NwSANTEIDANTAI_CD_3           NUMBER;   --算定団体コード３月
        IwKIWARI_KIJUNBI        PLS_INTEGER;    -- 期割のための基準日
        NKYUYO_SHOTOKU_KBN      NUMBER;         -- 給与所得者等該当区分
        NKISO_KOJO_SHOTOKU      NUMBER;         -- 基礎控除額取得用所得
        NRTN                    NUMBER;
        NKISO_KOJO_SHOTOKU_S    NUMBER;         -- 基礎控除額取得用所得(非自発的失業者)

        -- 計算所得カーソル
        CURSOR CwSHOTOKU IS
            SELECT * FROM ZLBTSHOTOKU_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND KOJIN_NO        = i_NKOJIN_NO
               AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
               AND NENDO_BUN       = NlNENDO_BUN
               AND SYS_TANMATSU_NO = i_VMASIN_NO
               AND SHOTOKU_KBN NOT IN (c_KYUYO_SHUNYU_IPN, c_KYUYO_SHUNYU_SENJU, c_KOTEKINEN_SHUNYU  --収入を省く
                                     , c_KOTEKINEN_KOUJYO)  --年金控除額も省く
             ORDER BY SHOTOKU_KINGAKU DESC;

    BEGIN
        NwRTN := c_NOK;
        IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
          --課税状況の場合
          NwJIKKOU_KBN := c_NBATCH;  --バッチから起動
        ELSE
          NwJIKKOU_KBN := i_NJIKKOU_KBN;
        END IF;
        BEGIN
          SELECT SANTEI_4, SANTEI_9, SANTEI_3
            INTO NwSANTEIDANTAI_CD_4, NwSANTEIDANTAI_CD_9, NwSANTEIDANTAI_CD_3
            FROM ZLBTSANTEI_CAL
           WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
             AND SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
            NwRTN := c_NERR;
            VlMSG := 'funcShotokuSet 計算算定団体所得' ||
                     '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                     ')' || SQLERRM;
            RETURN(NwRTN);
        END;
        -- 課税状況から起動
        IF i_NJIKKOU_KBN = c_KAZEIJOKYO THEN
          NwSANTEIDANTAI_CD := NwSANTEIDANTAI_CD_3; -- 算定団体コード3月
        -- 実態調査（世帯票）から起動
        ELSIF i_NJIKKOU_KBN = c_JITTAI_SETAI THEN
          NwSANTEIDANTAI_CD := NwSANTEIDANTAI_CD_9; -- 算定団体コード9月
        ELSE
          NwSANTEIDANTAI_CD := NwSANTEIDANTAI_CD_4; -- 算定団体コード4月
        END IF;
        -- システム条件取得2(税率条件取得)
        IF NwSANTEIDANTAI_CD > 0 THEN
            NwRTN := funcJokenSel2(NwSANTEIDANTAI_CD);
        END IF;
      -- 仮算定異動計算機能がオンの場合、仮算定開始期別を基準日とする
      IF i_NJIKKOU_KBN = c_NONLNIN AND ZLBPK00010.FCFFJKN2(411) = 1 THEN
        IwKIWARI_KIJUNBI := i_NKIJUNBI;  -- 引数の基準日をそのままセット
        IF NVL(i_SHORI_NENGETSU, 0) > 0 THEN
          --期割のために処理日をセット
          IF LENGTH(i_SHORI_NENGETSU) = 6 THEN
            IwKIWARI_KIJUNBI := i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
          ELSE
            IF i_SHORI_NENGETSU > 3 THEN
              IwKIWARI_KIJUNBI := i_NCHOTEI_NENDO * 10000 + i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
            ELSE
              IwKIWARI_KIJUNBI := (i_NCHOTEI_NENDO + 1) * 10000 + i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
            END IF;
          END IF;
          IF LENGTH(IwKIWARI_KIJUNBI) != 8 THEN
            IwKIWARI_KIJUNBI := i_NKIJUNBI;  -- 西暦８桁ない場合は、引数の基準日をそのままセット
          END IF;
        END IF;
      ELSE
        IwKIWARI_KIJUNBI := i_NKIJUNBI;  -- 引数の基準日をそのままセット
      END IF;
      IF NlSHOTOKU_HOSHIKI = c_SHOTOKU_HBN AND i_NJIKKOU_KBN IN(c_NBATCH ,c_NONLNIN , c_NONLNIN_SISAN)THEN
        -- 所得税編集読込み
        ZLBSKCALSTKHBN(i_NKOKU_SETAI_NO,
                       i_NKOJIN_NO,
                       i_NCHOTEI_NENDO,
                       NlNENDO_BUN,
                       NwJIKKOU_KBN,         -- 実行区分
                       i_VMASIN_NO,          -- 端末番号
                       i_NTRENBAN,
                       IwKIWARI_KIJUNBI,
                       NwSENJU_KBN,
                       NwRONENSHA_KBN,
                       NwSHINKOKU_KBN,
                       NwMINZEI_KAZEI_KBN,
                       NwMINZEI_SHOTOKUWARI,
                       NwMINZEI_KINTOWARI,
                       NwKOSEIBI,
                       NwKOKUHO_SHOTOKU,
                       NwKEIGENHANTEI_SHOTOKU,
                       NwKOKUHO_SHOTOKU_SHITSU,
                       NwKEIGENHANTEI_SHOTOKU_SHITSU,
                       NwKOJO_GOKEI,
                       NwRTN                      -- 所得編集読込み(0:OK 1:NG)
                      ,NKYUYO_SHOTOKU_KBN         -- 給与所得者等該当区分
                      ,NKISO_KOJO_SHOTOKU         -- 基礎控除額取得用所得
                      ,NKISO_KOJO_SHOTOKU_S       -- 基礎控除額取得用所得(非自発的失業者)
                      );
      ELSE
        -- 所得税編集読込み
        ZLBSKCALSTK(i_NKOKU_SETAI_NO,
                       i_NKOJIN_NO,
                       i_NCHOTEI_NENDO,
                       NlNENDO_BUN,
                       NwJIKKOU_KBN,         -- 実行区分
                       i_VMASIN_NO,          -- 端末番号
                       i_NTRENBAN,
                       IwKIWARI_KIJUNBI,
                       NwSENJU_KBN,
                       NwRONENSHA_KBN,
                       NwSHINKOKU_KBN,
                       NwMINZEI_KAZEI_KBN,
                       NwMINZEI_SHOTOKUWARI,
                       NwMINZEI_KINTOWARI,
                       NwKOSEIBI,
                       NwKOKUHO_SHOTOKU,
                       NwKEIGENHANTEI_SHOTOKU,
                       NwKOKUHO_SHOTOKU_SHITSU,             -- 2.2.100.000 JIP.Tsuji insert
                       NwKEIGENHANTEI_SHOTOKU_SHITSU,       -- 2.2.100.000 JIP.Tsuji insert
                       NwRTN                      -- 所得編集読込み(0:OK 1:NG)
                      ,NKYUYO_SHOTOKU_KBN         -- 給与所得者等該当区分
                      ,NKISO_KOJO_SHOTOKU         -- 基礎控除額取得用所得
                      ,NKISO_KOJO_SHOTOKU_S       -- 基礎控除額取得用所得(非自発的失業者)
                      );
        END IF;
        IF NwRTN = c_NOK THEN
          --st 仮算定は年度分-1
          IF NwJIKKOU_KBN = 1 THEN
            IF ZLBPK00010.FCFFJKN2(411) = 1 THEN
              IZAN_MODE := ZLBPK00010.FCZANMODE_ONL(i_NCHOTEI_NENDO, NlNENDO_BUN, IwKIWARI_KIJUNBI);
            ELSE
              IZAN_MODE := 0;
            END IF;
          ELSE
            IZAN_MODE := ZLBPK00010.FCZANMODE(i_NCHOTEI_NENDO, NlNENDO_BUN);
          END IF;
          IF IZAN_MODE = 1 THEN
            NlNENDO_BUN := NlNENDO_BUN - 1;
          END IF;

          --グローバル変数.年度分が2021年度以降の場合、基礎控除額の取得を行う
          IF NlNENDO_BUN >= 2021 THEN
            --基礎控除額の取得
            --国保税の「課税計算パッケージ.基礎控除算出関数」を呼び出し、基礎控除額を取得する
            NRTN := ZLBPK00020.FCCALKISOKOJO(NlNENDO_BUN                  -- 年度分
                                           , NKISO_KOJO_SHOTOKU          -- 合計所得金額
                                           , NlKISOKOJO);                -- 基礎控除額
            IF NRTN <> 0 THEN
              NwRTN := c_NERR;
              VlMSG := 'funcShotokuSet にて基礎控除額の取得エラー（年度分：' || NlNENDO_BUN ||
                       '、国保世帯番号：' || i_NKOKU_SETAI_NO ||
                       '、宛名番号：' || i_NKOJIN_NO || ')';
            ELSE
              --基礎控除(非自発的失業者)の取得
              --国保税の「課税計算パッケージ.基礎控除算出関数」を呼び出し、基礎控除額を取得する
              NRTN := ZLBPK00020.FCCALKISOKOJO(NlNENDO_BUN                -- 年度分
                                            , NKISO_KOJO_SHOTOKU_S       -- 基礎控除額取得用所得(非自発的失業者)
                                            , NlKISOKOJO_S);             -- 基礎控除(非自発的失業者)
              IF NRTN <> 0 THEN
                NwRTN := c_NERR;
                VlMSG := 'funcShotokuSet にて基礎控除額(非自発的失業者)の取得エラー（年度分：' || NlNENDO_BUN ||
                         '、国保世帯番号：' || i_NKOKU_SETAI_NO ||
                         '、宛名番号：' || i_NKOJIN_NO || ')';
              END IF;
            END IF;
            --ST 年度分を戻す
          ELSE
            -- 2020年度までは非自発的失業者の基礎控除は一般の基礎控除と同じ
            NlKISOKOJO_S := NlKISOKOJO;
          END IF;
          IF IZAN_MODE = 1 THEN
            NlNENDO_BUN := NlNENDO_BUN + 1;
          END IF;
        END IF;
        -- 各項目の編集
        IF NwRTN = c_NOK THEN

            NwSHU_SHOTOKU     := 0;
            NwSHU_SHOTOKU_KBN := 0;

            BEGIN
                -- 主所得区分
                FOR RwSHOTOKU IN CwSHOTOKU LOOP

                        NwSHU_SHOTOKU     := RwSHOTOKU.SHOTOKU_KINGAKU;
                        NwSHU_SHOTOKU_KBN := RwSHOTOKU.SHOTOKU_KBN;

                        EXIT;
                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN    -- エラー処理
                    NwRTN := c_NERR;
                    VlMSG := 'funcShotokuSet 計算所得取得' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
            END;

        END IF;

        IF NwRTN = c_NOK THEN

          IF NlSHOTOKU_HOSHIKI = c_SHOTOKU_HBN AND i_NJIKKOU_KBN IN(c_NBATCH ,c_NONLNIN , c_NONLNIN_SISAN)THEN
            -- 課税標準額
            NwKAHYO := NVL(NwKOKUHO_SHOTOKU, 0) - NlKISOKOJO - NwKOJO_GOKEI;   -- 所得額-基礎控除-控除合計
            IF NwKAHYO < 0 THEN
                NwKAHYO := 0;
            END IF;
          ELSE
            -- 課税標準額
            NwKAHYO := NVL(NwKOKUHO_SHOTOKU, 0) - NlKISOKOJO;   -- 所得額-基礎控除
            IF NwKAHYO < 0 THEN
                NwKAHYO := 0;
            END IF;
          END IF;
            NwKAHYO_SHITSU := NVL(NwKOKUHO_SHOTOKU_SHITSU, 0) - NlKISOKOJO_S;     -- 所得額-基礎控除(非自発的失業者)
            IF NwKAHYO_SHITSU < 0 THEN
                NwKAHYO_SHITSU := 0;
            END IF;

            --課税標準額 1000円未満切捨て
            IF IKAHYO_HASU_KBN = 1 AND NwKAHYO <> 0 THEN
              NwKAHYO := TRUNC(NwKAHYO / 1000) * 1000;
            ELSIF IKAHYO_HASU_KBN = 2 AND NwKAHYO <> 0 THEN
              NwKAHYO := TRUNC(NwKAHYO / 100) * 100;
            END IF;
            IF IKAHYO_HASU_KBN = 1 AND NwKAHYO_SHITSU <> 0 THEN
              NwKAHYO_SHITSU := TRUNC(NwKAHYO_SHITSU / 1000) * 1000;
            END IF;

        END IF;

        -- 計算個人の更新
        IF NwRTN = c_NOK THEN
            -- 失業者資格がない場合
            IF NVL(i_NNEW_SHITSU_KBN, 0) <= 0 THEN
                -- 失業軽減適用後エリアの初期化
                NwKOKUHO_SHOTOKU_SHITSU       := 0;
                NwKAHYO_SHITSU                := 0;
            END IF;
            BEGIN
                UPDATE ZLBTKOJIN_CAL
                   SET SHOTOKU          = NVL(NwKOKUHO_SHOTOKU, 0),         -- 所得額
                       KAHYO            = NwKAHYO,                          -- 課税標準額
                       KEIGEN_SHOTOKU   = NVL(NwKEIGENHANTEI_SHOTOKU, 0),   -- 軽減判定所得
                       SENJU_KBN        = NVL(NwSENJU_KBN,    0),           -- 専従区分
                       RONEN_KBN        = NVL(NwRONENSHA_KBN, 0),           -- 老年者区分
                       SHINKOKU_KBN     = NVL(NwSHINKOKU_KBN, 0),           -- 申告区分
                       SHU_SHOTOKU_KBN  = NwSHU_SHOTOKU_KBN,                -- 主所得区分
                       J_KAZEI_KBN      = NVL(NwMINZEI_KAZEI_KBN, 0),       -- 住民税課税区分
                       J_SHOTOKU_WARI   = NVL(NwMINZEI_SHOTOKUWARI, 0),     -- 住民税所得割額
                       J_KINTO_WARI     = NVL(NwMINZEI_KINTOWARI, 0)        -- 住民税均等割額
                     , SHITSU_SHOTOKU         = NVL(NwKOKUHO_SHOTOKU_SHITSU, 0),        -- 失業軽減適用後所得額
                       SHITSU_KAHYO           = NwKAHYO_SHITSU,                         -- 失業軽減適用後課税標準額
                       SHITSU_KEIGEN_SHOTOKU  = NVL(NwKEIGENHANTEI_SHOTOKU_SHITSU, 0)   -- 失業軽減適用後軽減判定所得
                       ,KYUYO_SHOTOKU_KBN     = NKYUYO_SHOTOKU_KBN                      -- 給与所得者等該当区分
                 WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                   AND KOJIN_NO        = i_NKOJIN_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
            EXCEPTION
                WHEN OTHERS THEN    -- エラー処理
                    NwRTN := c_NERR;
                    VlMSG := 'funcShotokuSet 計算個人更新(所得)' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
            END;
        END IF;

        RETURN(NwRTN);

    END funcShotokuSet;
-------------------------------------------------------------------------------
-- 06 計算期別作成
-------------------------------------------------------------------------------
    FUNCTION funcKibetsu RETURN NUMBER IS

        NwRTN             NUMBER;
        IwKIWARI_KIJUNBI  PLS_INTEGER;  --期割のための基準日
        NwJIKKOU_KBN      NUMBER;       --実行区分
        NwJIKKOU_KBN_KH   NUMBER;       -- 実行区分(ZLBFKKIWARIHT)

        NKEISAN_KBN1      NUMBER;       -- 計算区分1
        NKEISAN_KBN2      NUMBER;       -- 計算区分2
        NKEISAN_KBN3      NUMBER;       -- 計算区分3
        NFUTU_TUKI        NUMBER;       -- 普徴月
        NTOKU_TUKI        NUMBER;       -- 特徴月
        NYOKU_HYOUJI_KBN  NUMBER;       -- 翌年度表示区分
        VHYOUJI_JYOUHO    NVARCHAR2(200);   -- 表示情報
        NCHUSHI_JIYU      NUMBER;       -- 中止事由
        NTSUCHI_NO        NUMBER;       -- 通知書番号
        NwCNT             NUMBER;       -- 件数 -- 2009/12/25
        -- 計算基本ｶｰｿﾙ
        CURSOR CwKIHON IS
            SELECT * FROM ZLBTKIHON_CAL
             WHERE SYS_TANMATSU_NO = i_VMASIN_NO
             ORDER BY CHOTEI_NENDO DESC;

    BEGIN
        NwRTN := c_NOK;

        IwKIWARI_KIJUNBI := i_NKIJUNBI;  -- 引数の基準日をそのままセット

        IF NVL(i_SHORI_NENGETSU, 0) > 0 THEN
          --期割のために処理日をセット
          IF LENGTH(i_SHORI_NENGETSU) = 6 THEN
            IwKIWARI_KIJUNBI := i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
          ELSE
            IF i_SHORI_NENGETSU > 3 THEN
              -- 随時４月更正の場合
              IF TRUNC(i_NKIJUNBI, -4) / 10000 <> i_NCHOTEI_NENDO AND i_SHORI_NENGETSU = 4 THEN
                IwKIWARI_KIJUNBI := (i_NCHOTEI_NENDO + 1) * 10000 + i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
              ELSE
                IwKIWARI_KIJUNBI := i_NCHOTEI_NENDO * 10000 + i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
              END IF;
            ELSE
              IwKIWARI_KIJUNBI := (i_NCHOTEI_NENDO + 1) * 10000 + i_SHORI_NENGETSU * 100 + 1;  --処理基準日として１日の日付変換
            END IF;
          END IF;
          IF LENGTH(IwKIWARI_KIJUNBI) != 8 THEN
            IwKIWARI_KIJUNBI := i_NKIJUNBI;  -- 西暦８桁ない場合は、引数の基準日をそのままセット
          END IF;
        END IF;

        IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
          --課税状況の場合
          NwJIKKOU_KBN := c_NBATCH;  --バッチから起動
        ELSE
          NwJIKKOU_KBN := i_NJIKKOU_KBN;
        END IF;

        FOR RwKIHON IN CwKIHON LOOP


          -- 実行区分をセット
          IF i_NJIKKOU_KBN = c_NBATCH AND i_NNOUKI_KBN = c_NNOUKI_HONSAN THEN
            NwJIKKOU_KBN_KH := c_KH_BTHONSAN;   -- バッチ起動 本算定
          ELSIF i_NJIKKOU_KBN = c_NONLNIN THEN
            NwJIKKOU_KBN_KH := c_KH_ONLINE;     -- オンライン起動
          ELSE
            NwJIKKOU_KBN_KH := c_KH_BTGETSU;    -- バッチ起動 月例
          END IF;

          -- 最新特徴対象TBLから計算特徴対象TBLを作成(バッチは既に作成済)
          BEGIN
              -- 計算特徴対象登録
              INSERT INTO ZLBTTOKU_KIHON_CAL
                  (SELECT KOKU_SETAI_NO,
                          SANTEIDANTAI_CD,
                          CHOTEI_NENDO,
                          NENDO_BUN,
                          R_NO + 10 ,
                          TSUCHI_NO,
                          HOSOKU_NENDO,
                          TOKU_KOJIN_NO,
                          JOTAI_KBN,
                          KISO_NENKIN_NO,
                          TOKU_GIMUSHA_CD,
                          NENKIN_CD,
                          KAISHI_TSUKI,
                          KAISHI_KIBETSU,
                          SHURYO_TSUKI,
                          SHURYO_KIBETSU,
                          CHUSHI_JIYU,
                          KARIHENKO_KBN1,
                          KARIHENKO_KBN2,
                          KARIHENKO_KBN3,
                          TOKU_GIMUSHA_CD_4,
                          NENKIN_CD_4,
                          TOKU_GIMUSHA_CD_10,
                          NENKIN_CD_10,
                          IRAI_HIZUKE,
                          SYS_SAKUSEIBI,
                          SYS_KOSHINBI,
                          SYS_JIKAN,
                          SYS_SHOKUINKOJIN_NO,
                          i_VMASIN_NO
                    FROM ZLBTTOKU_KIHON_N
                    WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                      AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                      AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO
                      AND NENDO_BUN       = RwKIHON.NENDO_BUN
                      AND TSUCHI_NO       = RwKIHON.TSUCHI_NO
                      AND R_NO = (SELECT MAX(R_NO) FROM ZLBTTOKU_KIHON_N
                                     WHERE KOKU_SETAI_NO  = RwKIHON.KOKU_SETAI_NO
                                     AND SANTEIDANTAI_CD  = RwKIHON.SANTEIDANTAI_CD
                                     AND CHOTEI_NENDO     = RwKIHON.CHOTEI_NENDO
                                     AND NENDO_BUN        = RwKIHON.NENDO_BUN
                                     AND TSUCHI_NO        = RwKIHON.TSUCHI_NO ));

              -- 翌年度通知書番号取得
              -- 計算特徴対象登録
              INSERT INTO ZLBTTOKU_KIHON_CAL
                  (SELECT KOKU_SETAI_NO,
                          SANTEIDANTAI_CD,
                          CHOTEI_NENDO,
                          NENDO_BUN,
                          R_NO+10,
                          TSUCHI_NO,
                          HOSOKU_NENDO,
                          TOKU_KOJIN_NO,
                          JOTAI_KBN,
                          KISO_NENKIN_NO,
                          TOKU_GIMUSHA_CD,
                          NENKIN_CD,
                          KAISHI_TSUKI,
                          KAISHI_KIBETSU,
                          SHURYO_TSUKI,
                          SHURYO_KIBETSU,
                          CHUSHI_JIYU,
                          KARIHENKO_KBN1,
                          KARIHENKO_KBN2,
                          KARIHENKO_KBN3,
                          TOKU_GIMUSHA_CD_4,
                          NENKIN_CD_4,
                          TOKU_GIMUSHA_CD_10,
                          NENKIN_CD_10,
                          IRAI_HIZUKE,
                          SYS_SAKUSEIBI,
                          SYS_KOSHINBI,
                          SYS_JIKAN,
                          SYS_SHOKUINKOJIN_NO,
                          i_VMASIN_NO
                    FROM ZLBTTOKU_KIHON_N
                    WHERE KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                      AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                      AND CHOTEI_NENDO    = RwKIHON.CHOTEI_NENDO+1
                      AND NENDO_BUN       = RwKIHON.NENDO_BUN+1
                      AND TSUCHI_NO       = RwKIHON.YOKU_TSUCHI_NO
                      AND R_NO = (SELECT MAX(R_NO) FROM ZLBTTOKU_KIHON_N
                                     WHERE KOKU_SETAI_NO  = RwKIHON.KOKU_SETAI_NO
                                     AND SANTEIDANTAI_CD  = RwKIHON.SANTEIDANTAI_CD
                                     AND CHOTEI_NENDO     = RwKIHON.CHOTEI_NENDO+1
                                     AND NENDO_BUN        = RwKIHON.NENDO_BUN+1
                                     AND TSUCHI_NO        = RwKIHON.YOKU_TSUCHI_NO ));

          EXCEPTION
              WHEN NO_DATA_FOUND THEN
                  NULL;
              WHEN OTHERS THEN
                  NlRTN := c_NERR;
                  VlMSG := 'funcKibetsu 計算特徴対象登録' ||
                           '(国保世帯番号=' || RwKIHON.KOKU_SETAI_NO ||
                           ')' || SQLERRM;
                  EXIT;
          END;

          -- 期割判定
          NwRTN := ZLBFKKIWARIHT(RwKIHON.KOKU_SETAI_NO,     -- 国保世帯番号
                                     RwKIHON.SANTEIDANTAI_CD,   -- 算定団体コード
                                     RwKIHON.CHOTEI_NENDO,      -- 調定年度
                                     RwKIHON.NENDO_BUN,         -- 年度分
                                     RwKIHON.TSUCHI_NO,         -- 通知書番号
                                     IwKIWARI_KIJUNBI,          -- 処理日
                                     NwJIKKOU_KBN_KH,           -- 実行区分
                                     i_VMASIN_NO,               -- 端末番号
                                     i_NTRENBAN,                -- 登録連番
                                     NKEISAN_KBN1,              -- 計算区分1
                                     NKEISAN_KBN2,              -- 計算区分2
                                     NKEISAN_KBN3,              -- 計算区分3
                                     NFUTU_TUKI,                -- 普徴月
                                     NTOKU_TUKI,                -- 特徴月
                                     NYOKU_HYOUJI_KBN,          -- 翌年度表示区分
                                     VHYOUJI_JYOUHO,            -- 表示情報
                                     NCHUSHI_JIYU);             -- 中止事由
          IF NwRTN != c_NOK THEN
            NwRTN := c_NERR;
            VlMSG := 'funcKibetsu 計算期別作成' ||
                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                     ')ZLBFKKIWARIHT:失敗';
            EXIT;
          END IF;
          -- 実行区分オンライン起動時＆計算区分1＝特徴開始は普徴期割を行う
          IF  i_NJIKKOU_KBN = c_NONLNIN  AND NKEISAN_KBN1 = 2 THEN
              NKEISAN_KBN1 := c_NFUTSU_KEISAN;
          END IF;


      IF NlGENKA_KBN = c_NGENNEN THEN
          -- 特徴中止以外は０をセット
          IF (NKEISAN_KBN1 != c_NKEISAN_KBN_3 AND NKEISAN_KBN2 != c_NKEISAN_KBN_3
                                              AND NKEISAN_KBN1 != c_NFUTSU_KEISAN_STOP AND NKEISAN_KBN1 != c_NFUTSU_KEISAN_CANCEL) THEN
              IF NCHUSHI_JIYU <> 0 THEN
                 NCHUSHI_JIYU := 0;
              END IF;
          END IF;
              -- 計算期別作成
              ZLBSKCALKW(NlGENKA_KBN,              -- 現年過年区分
                            RwKIHON.TSUCHI_NO,        -- 通知書番号
                            RwKIHON.CHOTEI_NENDO,     -- 調定年度
                            RwKIHON.NENDO_BUN,        -- 年度分
                            IwKIWARI_KIJUNBI,         -- 処理日
                            RwKIHON.SANTEIDANTAI_CD,  -- 算定団体コード
                            RwKIHON.KOKU_SETAI_NO,    -- 国保世帯番号
                            NwJIKKOU_KBN_KH,          -- 実行区分
                            NFUTU_TUKI,               -- 普徴月
                            NTOKU_TUKI,               -- 特徴月
                            NKEISAN_KBN1,             -- 計算区分
                            NCHUSHI_JIYU,             -- 中止事由
                            i_VMASIN_NO,              -- 端末番号
                            i_NTRENBAN,               -- 登録連番
                            NwRTN,                    -- 計算期別作成(0:OK 1:NG)
                            i_NKIJUNBI);              -- 更正日（基準日を渡す）
      ELSE
              -- 計算期別作成(過年度分)
              ZLBSKCALKWPASS(NlGENKA_KBN,          -- 現年過年区分
                            RwKIHON.TSUCHI_NO,    -- 通知書番号
                            RwKIHON.CHOTEI_NENDO, -- 調定年度
                            RwKIHON.NENDO_BUN,    -- 年度分
                            IwKIWARI_KIJUNBI,     -- 基準日
                            RwKIHON.SANTEIDANTAI_CD,  -- 算定団体コード
                            RwKIHON.KOKU_SETAI_NO,    -- 国保世帯番号
                            NwJIKKOU_KBN,         -- 実行区分
                            i_VMASIN_NO,          -- 端末番号
                            i_NTRENBAN,           -- 登録連番
                            NwRTN,                -- 計算期別作成(0:OK 1:NG)
                            i_NKIJUNBI);          --更正日（基準日を渡す）
      END IF;
            IF NwRTN != c_NOK THEN
                NwRTN := c_NERR;
            END IF;

            IF NwRTN = c_NOK THEN
                -- 退職税額編集
                ZLBSKCALTZEI(RwKIHON.SANTEIDANTAI_CD,  -- 算定団体コード
                              RwKIHON.TSUCHI_NO,        -- 通知書番号
                              RwKIHON.KOKU_SETAI_NO,    -- 国保世帯番号
                            --i_NJIKKOU_KBN,            -- 実行区分
                              NwJIKKOU_KBN,             -- 実行区分
                              i_VMASIN_NO,              -- 端末番号
                              i_NTRENBAN,               -- 登録連番
                              RwKIHON.CHOTEI_NENDO,     -- 調定年度
                              RwKIHON.NENDO_BUN,        -- 年度分
                              NwRTN);       -- 退職税額編集(0:OK 1:NG)
                IF NwRTN != c_NOK THEN
                    NwRTN := c_NERR;
                END IF;
            END IF;

            -- 計算期別内訳作成
            IF NwRTN = c_NOK THEN
             ZLBSBKIANBUN(c_NANBUN_SA,                -- 差額按分
                            IwKIWARI_KIJUNBI,           -- 基準日
                            RwKIHON.TSUCHI_NO,          -- 通知書番号
                            RwKIHON.SANTEIDANTAI_CD,    -- 算定団体コード
                            RwKIHON.KOKU_SETAI_NO,      -- 国保世帯番号
                            NwJIKKOU_KBN,               -- 実行区分
                            i_VMASIN_NO,                -- 端末番号
                            i_NTRENBAN,                 -- 登録連番
                            NwRTN,                      -- 計算期別内訳作成(0:OK 1:NG)
                            RwKIHON.CHOTEI_NENDO,       --調定年度
                            RwKIHON.NENDO_BUN);         --年度分
                IF NwRTN != c_NOK THEN
                    NwRTN := c_NERR;
                END IF;
            END IF;

            IF NwRTN = c_NOK THEN
                -- 全体期別税額＜退職期別税額が存在するか
                BEGIN
                    SELECT COUNT(*) INTO NwCNT FROM ZLBTKIBETSU_CAL
                     WHERE KOKU_SETAI_NO   =  RwKIHON.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD =  RwKIHON.SANTEIDANTAI_CD
                       AND TSUCHI_NO       =  RwKIHON.TSUCHI_NO
                       AND CHOTEINENDO     =  RwKIHON.CHOTEI_NENDO
                       AND NENDOBUN        =  RwKIHON.NENDO_BUN
                       AND SYS_TANMATSU_NO =  i_VMASIN_NO
                       AND (ZEN_ZEIGAKU < TAI_ZEIGAKU
                        OR  IR_ZEN_ZEIGAKU < IR_TAI_ZEIGAKU
                        OR  KAI_ZEN_ZEIGAKU < KAI_TAI_ZEIGAKU
                        OR  SIEN_ZEN_ZEIGAKU < SIEN_TAI_ZEIGAKU);
                EXCEPTION
                    WHEN OTHERS THEN
                        NwRTN := c_NERR;
                        VlMSG := 'funcKibetsu 計算期別作成' ||
                                 '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                 ')' || SQLERRM;
                        EXIT;
                END;
                IF NwCNT = 0 THEN
                    -- 退職期別税額≠医療退職期別税額＋介護退職期別税額＋支援退職期別税額が存在するか
                    BEGIN
                        SELECT COUNT(*) INTO NwCNT FROM ZLBTKIBETSU_CAL
                         WHERE KOKU_SETAI_NO   =  RwKIHON.KOKU_SETAI_NO
                           AND SANTEIDANTAI_CD =  RwKIHON.SANTEIDANTAI_CD
                           AND TSUCHI_NO       =  RwKIHON.TSUCHI_NO
                           AND CHOTEINENDO     =  RwKIHON.CHOTEI_NENDO
                           AND NENDOBUN        =  RwKIHON.NENDO_BUN
                           AND SYS_TANMATSU_NO =  i_VMASIN_NO
                           AND TAI_ZEIGAKU <> IR_TAI_ZEIGAKU + KAI_TAI_ZEIGAKU + SIEN_TAI_ZEIGAKU;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NwRTN := c_NERR;
                            VlMSG := 'funcKibetsu 計算期別作成②' ||
                                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                     ')' || SQLERRM;
                            EXIT;
                    END;
                END IF;
                -- 存在する場合
                IF NwCNT > 0 THEN
                    -- 退職税額編集（医療・介護・支援）
                    ZLBSKCALTZEI2(RwKIHON.SANTEIDANTAI_CD,  -- 算定団体コード
                                   RwKIHON.TSUCHI_NO,        -- 通知書番号
                                   RwKIHON.KOKU_SETAI_NO,    -- 国保世帯番号
                                   NwJIKKOU_KBN,             -- 実行区分
                                   i_VMASIN_NO,              -- 端末番号
                                   i_NTRENBAN,               -- 登録連番
                                   RwKIHON.CHOTEI_NENDO,     -- 調定年度
                                   RwKIHON.NENDO_BUN,        -- 年度分
                                   NwRTN);       -- 退職税額編集(0:OK 1:NG)
                    IF NwRTN != c_NOK THEN
                        NwRTN := c_NERR;
                    END IF;
                END IF;
            END IF;

            IF NwRTN = c_NOK THEN
                -- 全体期別税額≠医療全体期別税額＋介護全体期別税額＋支援全体期別税額が存在するか
                BEGIN
                    SELECT COUNT(*) INTO NwCNT FROM ZLBTKIBETSU_CAL
                     WHERE KOKU_SETAI_NO   =  RwKIHON.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD =  RwKIHON.SANTEIDANTAI_CD
                       AND TSUCHI_NO       =  RwKIHON.TSUCHI_NO
                       AND CHOTEINENDO     =  RwKIHON.CHOTEI_NENDO
                       AND NENDOBUN        =  RwKIHON.NENDO_BUN
                       AND SYS_TANMATSU_NO =  i_VMASIN_NO
--2025/08/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応
--                       AND ZEN_ZEIGAKU <> IR_ZEN_ZEIGAKU + KAI_ZEN_ZEIGAKU + SIEN_ZEN_ZEIGAKU;
                       AND ZEN_ZEIGAKU <> IR_ZEN_ZEIGAKU + KAI_ZEN_ZEIGAKU + SIEN_ZEN_ZEIGAKU + KDM_ZEN_ZEIGAKU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NwRTN := c_NERR;
                        VlMSG := 'funcKibetsu 計算期別作成③' ||
                                 '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                 ')' || SQLERRM;
                        EXIT;
                END;
                -- 存在する場合
                IF NwCNT > 0 THEN
                    -- 計算期別内訳作成（全期按分により内訳を作成）
                    ZLBSBKIANBUN(0,                          -- 全期按分
                                IwKIWARI_KIJUNBI,           -- 基準日
                                RwKIHON.TSUCHI_NO,          -- 通知書番号
                                RwKIHON.SANTEIDANTAI_CD,    -- 算定団体コード
                                RwKIHON.KOKU_SETAI_NO,      -- 国保世帯番号
                                NwJIKKOU_KBN,               -- 実行区分
                                i_VMASIN_NO,                -- 端末番号
                                i_NTRENBAN,                 -- 登録連番
                                NwRTN,                      -- 計算期別内訳作成(0:OK 1:NG)
                                RwKIHON.CHOTEI_NENDO,       -- 調定年度
                                RwKIHON.NENDO_BUN);         -- 年度分
                    IF NwRTN != c_NOK THEN
                        NwRTN := c_NERR;
                    END IF;
                END IF;
            END IF;

            IF NwRTN = c_NOK AND
               NlGENKA_KBN = c_NGENNEN THEN
              BEGIN
                SELECT DISTINCT TSUCHI_NO INTO NTSUCHI_NO FROM ZLBTKIBETSU_CAL
                  WHERE KAMOKU_CD       = 15
                    AND KOKU_SETAI_NO   = RwKIHON.KOKU_SETAI_NO
                    AND SANTEIDANTAI_CD = RwKIHON.SANTEIDANTAI_CD
                    AND CHOTEINENDO     = RwKIHON.CHOTEI_NENDO + 1
                    AND NENDOBUN        = RwKIHON.NENDO_BUN + 1
                    AND NUSHI_KOJIN_NO  = RwKIHON.NUSHI_KOJIN_NO
                    AND SYS_TANMATSU_NO = i_VMASIN_NO;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  NTSUCHI_NO := 0;
                WHEN OTHERS THEN
                  NwRTN := c_NERR;
              END;

              IF NwRTN = c_NOK THEN
                IF NTSUCHI_NO > 0 THEN
                  -- 退職税額編集
                  ZLBSKCALTZEI(RwKIHON.SANTEIDANTAI_CD,  -- 算定団体コード
                                NTSUCHI_NO,               -- 通知書番号
                                RwKIHON.KOKU_SETAI_NO,    -- 国保世帯番号
                                NwJIKKOU_KBN,             -- 実行区分
                                i_VMASIN_NO,              -- 端末番号
                                i_NTRENBAN,               -- 登録連番
                                i_NCHOTEI_NENDO + 1,      -- 調定年度
                                i_NNENDO_BUN + 1,         -- 年度分
                                NwRTN);                   -- 退職税額編集(0:OK 1:NG)
                  IF NwRTN != c_NOK THEN
                    NwRTN := c_NERR;
                  END IF;

                  -- 計算期別内訳作成
                  IF NwRTN = c_NOK THEN
                    ZLBSBKIANBUN(c_NANBUN_SA,                -- 差額按分
                                IwKIWARI_KIJUNBI,           -- 基準日
                                NTSUCHI_NO,                 -- 通知書番号
                                RwKIHON.SANTEIDANTAI_CD,    -- 算定団体コード
                                RwKIHON.KOKU_SETAI_NO,      -- 国保世帯番号
                                NwJIKKOU_KBN,               -- 実行区分
                                i_VMASIN_NO,                -- 端末番号
                                i_NTRENBAN,                 -- 登録連番
                                NwRTN,                      -- 計算期別内訳作成(0:OK 1:NG)
                                i_NCHOTEI_NENDO + 1,        -- 調定年度
                                i_NNENDO_BUN + 1);          -- 年度分
                    IF NwRTN != c_NOK THEN
                      NwRTN := c_NERR;
                    END IF;
                  END IF;
                END IF;
              END IF;
            END IF;

            EXIT WHEN NwRTN != c_NOK;

        END LOOP;

        RETURN(NwRTN);

    EXCEPTION
        WHEN OTHERS THEN
            VlMSG := 'funcKibetsu 計算期別作成' ||
                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                     ')' || SQLERRM;
            RETURN(c_NERR);
    END funcKibetsu;
-------------------------------------------------------------------------------
-- 計算基本と賦課基本で比較、税額差が１００円以下の場合は、計算基本を賦課基本で更新
-------------------------------------------------------------------------------
    PROCEDURE PROC_UpCheck_KIHON(i_SETAI      IN  NUMBER,       -- 国保世帯番号
                                 i_DANTAI     IN  PLS_INTEGER,  -- 算定団体コード
                                 i_NENDO      IN  PLS_INTEGER,  -- 調定年度
                                 i_NENDO_BUN  IN  PLS_INTEGER,  -- 年度分
                                 i_TSUCHI_NO  IN  NUMBER,       -- 通知書番号
                                 i_TANMATSU   IN  NVARCHAR2) IS -- 端末番号
        NSAGAKU  NUMBER := 0;
        wIRYO_NENREI_KEIGEN  NUMBER(12,0);
        wIRYO_SHOGAI_GENMEN  NUMBER(12,0);

        CURSOR CCAL IS
          SELECT NENZEI FROM ZLBTKIHON_CAL
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO
              AND SYS_TANMATSU_NO = i_TANMATSU;
        CURSOR CNOW IS
          SELECT * FROM ZLBTKIHON_N
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO;
    BEGIN
        --税額が１００円以内の差額かどうかをチェック
        FOR CREC_N IN CNOW LOOP
          FOR CREC_C IN CCAL LOOP
            NSAGAKU := ABS(CREC_C.NENZEI - CREC_N.NENZEI);
            IF 0 < NSAGAKU AND NSAGAKU <= 100 THEN
              --税額の差額が１円以上で１００円以内の場合は、ＮをＣＡＬへコピー
              UPDATE ZLBTKIHON_CAL
                SET KEIGEN_SHOTOKU     = CREC_N.KEIGEN_SHOTOKU       --軽減判定所得
                  , SHOTOKU            = CREC_N.SHOTOKU              --所得額
                  , KAHYO              = CREC_N.KAHYO                --課税標準額
                  , SHOTOKU_WARI       = CREC_N.SHOTOKU_WARI         --所得割額
                  , SHISANZEI          = CREC_N.SHISANZEI            --資産税額
                  , SHISAN_WARI        = CREC_N.SHISAN_WARI          --資産割額
                  , KINTO_WARI         = CREC_N.KINTO_WARI           --均等割額
                  , BYODO_WARI         = CREC_N.BYODO_WARI           --平等割額
                  , SEKISAN            = CREC_N.SEKISAN              --積算税額
                  , GENDO_CHOKA        = CREC_N.GENDO_CHOKA          --限度超過額
                  , KEIGEN_K_WARI      = CREC_N.KEIGEN_K_WARI        --軽減均等割額
                  , KEIGEN_B_WARI      = CREC_N.KEIGEN_B_WARI        --軽減平等割額
                  , KEIGEN_K_6         = CREC_N.KEIGEN_K_6           --軽減均等6
                  , KEIGEN_B_6         = CREC_N.KEIGEN_B_6           --軽減平等6
                  , KEIGEN_K_4         = CREC_N.KEIGEN_K_4           --軽減均等4
                  , KEIGEN_B_4         = CREC_N.KEIGEN_B_4           --軽減平等4
                  , KEIGEN_K_2         = CREC_N.KEIGEN_K_2           --軽減均等2
                  , KEIGEN_B_2         = CREC_N.KEIGEN_B_2           --軽減平等2
                  , TSUKIWARI_GEN      = CREC_N.TSUKIWARI_GEN        --月割減額
                  , HASU               = CREC_N.HASU                 --端数
                  , GENGAKU_KEI        = CREC_N.GENGAKU_KEI          --減額合計
                  , GENMEN             = CREC_N.GENMEN               --減免額
                  , KANENDO            = CREC_N.KANENDO              --過年度分
                  , NENZEI             = CREC_N.NENZEI               --年税額
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;

--	拡張TBL更新(医療年齢軽減、障害軽減)
              SELECT NVL(b.IRYO_NENREI_KEIGEN,0) ,NVL(b.IRYO_SHOGAI_GENMEN,0)
                       INTO wIRYO_NENREI_KEIGEN,wIRYO_SHOGAI_GENMEN
                FROM ZLBTKIHON_N  a,
                     ZLBTEXT_N    b
                WHERE a.KOKU_SETAI_NO   = i_SETAI
                  AND a.SANTEIDANTAI_CD = i_DANTAI
                  AND a.CHOTEI_NENDO    = i_NENDO
                  AND a.NENDO_BUN       = i_NENDO_BUN
                  AND a.TSUCHI_NO       = i_TSUCHI_NO
                  AND b.KOKU_SETAI_NO(+)   = a.KOKU_SETAI_NO
                  AND b.SANTEIDANTAI_CD(+) = a.SANTEIDANTAI_CD
                  AND b.CHOTEI_NENDO(+)    = a.CHOTEI_NENDO
                  AND b.NENDO_BUN(+)       = a.NENDO_BUN
                  AND b.TSUCHI_NO(+)       = a.TSUCHI_NO;

               UPDATE ZLBTEXT_CAL
                 SET IRYO_NENREI_KEIGEN = wIRYO_NENREI_KEIGEN,
                     IRYO_SHOGAI_GENMEN = wIRYO_SHOGAI_GENMEN
                 WHERE KOKU_SETAI_NO   = i_SETAI
                   AND SANTEIDANTAI_CD = i_DANTAI
                   AND CHOTEI_NENDO    = i_NENDO
                   AND NENDO_BUN       = i_NENDO_BUN
                   AND TSUCHI_NO       = i_TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_TANMATSU;
            END IF;
            EXIT;
          END LOOP;
          EXIT;
        END LOOP;
    END PROC_UpCheck_KIHON;
-------------------------------------------------------------------------------
-- 計算介護と賦課介護で比較、税額差が１００円以下の場合は、計算介護を賦課介護で更新
-------------------------------------------------------------------------------
    PROCEDURE PROC_UpCheck_KAI(i_SETAI      IN  NUMBER,       -- 国保世帯番号
                               i_DANTAI     IN  PLS_INTEGER,  -- 算定団体コード
                               i_NENDO      IN  PLS_INTEGER,  -- 調定年度
                               i_NENDO_BUN  IN  PLS_INTEGER,  -- 年度分
                               i_TSUCHI_NO  IN  NUMBER,       -- 通知書番号
                               i_TANMATSU   IN  NVARCHAR2) IS -- 端末番号
        NSAGAKU  NUMBER := 0;
        wKAI_NENREI_KEIGEN  NUMBER(12,0);
        wKAI_SHOGAI_GENMEN  NUMBER(12,0);

        CURSOR CCAL IS
          SELECT NENZEI FROM ZLBTKAI_KIHON_CAL
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO
              AND SYS_TANMATSU_NO = i_TANMATSU;
        CURSOR CNOW IS
          SELECT * FROM ZLBTKAI_KIHON_N
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO;
    BEGIN
        --税額が１００円以内の差額かどうかをチェック
        FOR CREC_N IN CNOW LOOP
          FOR CREC_C IN CCAL LOOP
            NSAGAKU := ABS(CREC_C.NENZEI - CREC_N.NENZEI);
            IF 0 < NSAGAKU AND NSAGAKU <= 100 THEN
              --税額の差額が１円以上で１００円以内の場合は、ＮをＣＡＬへコピー
              UPDATE ZLBTKAI_KIHON_CAL
                SET KEIGEN_SHOTOKU     = CREC_N.KEIGEN_SHOTOKU       --軽減判定所得
                  , SHOTOKU            = CREC_N.SHOTOKU              --所得額
                  , KAHYO              = CREC_N.KAHYO                --課税標準額
                  , SHOTOKU_WARI       = CREC_N.SHOTOKU_WARI         --所得割額
                  , SHISANZEI          = CREC_N.SHISANZEI            --資産税額
                  , SHISAN_WARI        = CREC_N.SHISAN_WARI          --資産割額
                  , KINTO_WARI         = CREC_N.KINTO_WARI           --均等割額
                  , BYODO_WARI         = CREC_N.BYODO_WARI           --平等割額
                  , SEKISAN            = CREC_N.SEKISAN              --積算税額
                  , GENDO_CHOKA        = CREC_N.GENDO_CHOKA          --限度超過額
                  , KEIGEN_K_WARI      = CREC_N.KEIGEN_K_WARI        --軽減均等割額
                  , KEIGEN_B_WARI      = CREC_N.KEIGEN_B_WARI        --軽減平等割額
                  , KEIGEN_K_6         = CREC_N.KEIGEN_K_6           --軽減均等6
                  , KEIGEN_B_6         = CREC_N.KEIGEN_B_6           --軽減平等6
                  , KEIGEN_K_4         = CREC_N.KEIGEN_K_4           --軽減均等4
                  , KEIGEN_B_4         = CREC_N.KEIGEN_B_4           --軽減平等4
                  , KEIGEN_K_2         = CREC_N.KEIGEN_K_2           --軽減均等2
                  , KEIGEN_B_2         = CREC_N.KEIGEN_B_2           --軽減平等2
                  , TSUKIWARI_GEN      = CREC_N.TSUKIWARI_GEN        --月割減額
                  , HASU               = CREC_N.HASU                 --端数
                  , GENGAKU_KEI        = CREC_N.GENGAKU_KEI          --減額合計
                  , GENMEN             = CREC_N.GENMEN               --減免額
                  , KANENDO            = CREC_N.KANENDO              --過年度分
                  , NENZEI             = CREC_N.NENZEI               --年税額
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;

              -- 拡張TBL更新(介護年齢軽減、介護障害軽減)
              SELECT NVL(b.KAI_NENREI_KEIGEN,0) ,NVL(b.KAI_SHOGAI_GENMEN,0)
                    INTO wKAI_NENREI_KEIGEN,wKAI_SHOGAI_GENMEN
                FROM ZLBTKAI_KIHON_N  a,
                     ZLBTEXT_N    b
                WHERE a.KOKU_SETAI_NO   = i_SETAI
                  AND a.SANTEIDANTAI_CD = i_DANTAI
                  AND a.CHOTEI_NENDO    = i_NENDO
                  AND a.NENDO_BUN       = i_NENDO_BUN
                  AND a.TSUCHI_NO       = i_TSUCHI_NO
                  AND b.KOKU_SETAI_NO(+)   = a.KOKU_SETAI_NO
                  AND b.SANTEIDANTAI_CD(+) = a.SANTEIDANTAI_CD
                  AND b.CHOTEI_NENDO(+)    = a.CHOTEI_NENDO
                  AND b.NENDO_BUN(+)       = a.NENDO_BUN
                  AND b.TSUCHI_NO(+)       = a.TSUCHI_NO;

              UPDATE ZLBTEXT_CAL
                SET KAI_NENREI_KEIGEN = wKAI_NENREI_KEIGEN,
                    KAI_SHOGAI_GENMEN = wKAI_SHOGAI_GENMEN
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;
            END IF;
            EXIT;
          END LOOP;
          EXIT;
        END LOOP;
    END PROC_UpCheck_KAI;

-------------------------------------------------------------------------------
-- 計算支援と賦課支援で比較、税額差が１００円以下の場合は、計算支援を賦課支援で更新
-------------------------------------------------------------------------------
    PROCEDURE PROC_UpCheck_SIEN(i_SETAI      IN  NUMBER,       -- 国保世帯番号
                               i_DANTAI     IN  PLS_INTEGER,  -- 算定団体コード
                               i_NENDO      IN  PLS_INTEGER,  -- 調定年度
                               i_NENDO_BUN  IN  PLS_INTEGER,  -- 年度分
                               i_TSUCHI_NO  IN  NUMBER,       -- 通知書番号
                               i_TANMATSU   IN  NVARCHAR2) IS -- 端末番号
        NSAGAKU  NUMBER := 0;
        wSIEN_NENREI_KEIGEN  NUMBER(12,0);
        wSIEN_SHOGAI_GENMEN  NUMBER(12,0);

        CURSOR CCAL IS
          SELECT NENZEI FROM ZLBTSIEN_KIHON_CAL
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO
              AND SYS_TANMATSU_NO = i_TANMATSU;
        CURSOR CNOW IS
          SELECT * FROM ZLBTSIEN_KIHON_N
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO;
    BEGIN
        --税額が１００円以内の差額かどうかをチェック
        FOR CREC_N IN CNOW LOOP
          FOR CREC_C IN CCAL LOOP
            NSAGAKU := ABS(CREC_C.NENZEI - CREC_N.NENZEI);
            IF 0 < NSAGAKU AND NSAGAKU <= 100 THEN
              --税額の差額が１円以上で１００円以内の場合は、ＮをＣＡＬへコピー
              UPDATE ZLBTSIEN_KIHON_CAL
                SET KEIGEN_SHOTOKU     = CREC_N.KEIGEN_SHOTOKU       --軽減判定所得
                  , SHOTOKU            = CREC_N.SHOTOKU              --所得額
                  , KAHYO              = CREC_N.KAHYO                --課税標準額
                  , SHOTOKU_WARI       = CREC_N.SHOTOKU_WARI         --所得割額
                  , SHISANZEI          = CREC_N.SHISANZEI            --資産税額
                  , SHISAN_WARI        = CREC_N.SHISAN_WARI          --資産割額
                  , KINTO_WARI         = CREC_N.KINTO_WARI           --均等割額
                  , BYODO_WARI         = CREC_N.BYODO_WARI           --平等割額
                  , SEKISAN            = CREC_N.SEKISAN              --積算税額
                  , GENDO_CHOKA        = CREC_N.GENDO_CHOKA          --限度超過額
                  , KEIGEN_K_WARI      = CREC_N.KEIGEN_K_WARI        --軽減均等割額
                  , KEIGEN_B_WARI      = CREC_N.KEIGEN_B_WARI        --軽減平等割額
                  , KEIGEN_K_6         = CREC_N.KEIGEN_K_6           --軽減均等6
                  , KEIGEN_B_6         = CREC_N.KEIGEN_B_6           --軽減平等6
                  , KEIGEN_K_4         = CREC_N.KEIGEN_K_4           --軽減均等4
                  , KEIGEN_B_4         = CREC_N.KEIGEN_B_4           --軽減平等4
                  , KEIGEN_K_2         = CREC_N.KEIGEN_K_2           --軽減均等2
                  , KEIGEN_B_2         = CREC_N.KEIGEN_B_2           --軽減平等2
                  , TSUKIWARI_GEN      = CREC_N.TSUKIWARI_GEN        --月割減額
                  , HASU               = CREC_N.HASU                 --端数
                  , GENGAKU_KEI        = CREC_N.GENGAKU_KEI          --減額合計
                  , GENMEN             = CREC_N.GENMEN               --減免額
                  , KANENDO            = CREC_N.KANENDO              --過年度分
                  , NENZEI             = CREC_N.NENZEI               --年税額
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;

              -- 拡張TBL更新(支援年齢軽減、支援障害軽減)
              SELECT NVL(b.SHI_NENREI_KEIGEN,0) ,NVL(b.SHI_SHOGAI_GENMEN,0)
                    INTO wSIEN_NENREI_KEIGEN,wSIEN_SHOGAI_GENMEN
                FROM ZLBTSIEN_KIHON_N  a,
                     ZLBTEXT_N    b
                WHERE a.KOKU_SETAI_NO   = i_SETAI
                  AND a.SANTEIDANTAI_CD = i_DANTAI
                  AND a.CHOTEI_NENDO    = i_NENDO
                  AND a.NENDO_BUN       = i_NENDO_BUN
                  AND a.TSUCHI_NO       = i_TSUCHI_NO
                  AND b.KOKU_SETAI_NO(+)   = a.KOKU_SETAI_NO
                  AND b.SANTEIDANTAI_CD(+) = a.SANTEIDANTAI_CD
                  AND b.CHOTEI_NENDO(+)    = a.CHOTEI_NENDO
                  AND b.NENDO_BUN(+)       = a.NENDO_BUN
                  AND b.TSUCHI_NO(+)       = a.TSUCHI_NO;

              UPDATE ZLBTEXT_CAL
                SET SHI_NENREI_KEIGEN = wSIEN_NENREI_KEIGEN,
                    SHI_SHOGAI_GENMEN = wSIEN_SHOGAI_GENMEN
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;
            END IF;
            EXIT;
          END LOOP;
          EXIT;
        END LOOP;
    END PROC_UpCheck_SIEN;

-------------------------------------------------------------------------------
-- 計算退職と賦課退職で比較、税額差が１００円以下の場合は、計算退職を賦課退職で更新
-------------------------------------------------------------------------------
    PROCEDURE PROC_UpCheck_TAI(i_SETAI      IN  NUMBER,       -- 国保世帯番号
                               i_DANTAI     IN  PLS_INTEGER,  -- 算定団体コード
                               i_NENDO      IN  PLS_INTEGER,  -- 調定年度
                               i_NENDO_BUN  IN  PLS_INTEGER,  -- 年度分
                               i_TSUCHI_NO  IN  NUMBER,       -- 通知書番号
                               i_TANMATSU   IN  NVARCHAR2) IS -- 端末番号
        NSAGAKU  NUMBER := 0;
        wIRYO_NENREI_KEIGEN_T  NUMBER(12,0);
        wIRYO_SHOGAI_GENMEN_T  NUMBER(12,0);

        CURSOR CCAL IS
          SELECT NENZEI FROM ZLBTTAI_CAL
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO
              AND SYS_TANMATSU_NO = i_TANMATSU;
        CURSOR CNOW IS
          SELECT * FROM ZLBTTAI_N
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO;
    BEGIN
        --税額が１００円以内の差額かどうかをチェック
        FOR CREC_N IN CNOW LOOP
          FOR CREC_C IN CCAL LOOP
            NSAGAKU := ABS(CREC_C.NENZEI - CREC_N.NENZEI);
            IF 0 < NSAGAKU AND NSAGAKU <= 100 THEN
              --税額の差額が１円以上で１００円以内の場合は、ＮをＣＡＬへコピー
              UPDATE ZLBTTAI_CAL
                SET KEIGEN_SHOTOKU      = CREC_N.KEIGEN_SHOTOKU       --軽減判定所得
                  , SHOTOKU             = CREC_N.SHOTOKU              --所得額
                  , KAHYO               = CREC_N.KAHYO                --課税標準額
                  , SHOTOKU_WARI        = CREC_N.SHOTOKU_WARI         --所得割額
                  , SHISANZEI           = CREC_N.SHISANZEI            --資産税額
                  , SHISAN_WARI         = CREC_N.SHISAN_WARI          --資産割額
                  , KINTO_WARI          = CREC_N.KINTO_WARI           --均等割額
                  , BYODO_WARI          = CREC_N.BYODO_WARI           --平等割額
                  , SEKISAN             = CREC_N.SEKISAN              --積算税額
                  , GENDO_CHOKA         = CREC_N.GENDO_CHOKA          --限度超過額
                  , KEIGEN_K_WARI       = CREC_N.KEIGEN_K_WARI        --軽減均等割額
                  , KEIGEN_B_WARI       = CREC_N.KEIGEN_B_WARI        --軽減平等割額
                  , KEIGEN_K_6          = CREC_N.KEIGEN_K_6           --軽減均等6
                  , KEIGEN_B_6          = CREC_N.KEIGEN_B_6           --軽減平等6
                  , KEIGEN_K_4          = CREC_N.KEIGEN_K_4           --軽減均等4
                  , KEIGEN_B_4          = CREC_N.KEIGEN_B_4           --軽減平等4
                  , KEIGEN_K_2          = CREC_N.KEIGEN_K_2           --軽減均等2
                  , KEIGEN_B_2          = CREC_N.KEIGEN_B_2           --軽減平等2
                  , TSUKIWARI_GEN       = CREC_N.TSUKIWARI_GEN        --月割減額
                  , HASU                = CREC_N.HASU                 --端数
                  , GENGAKU_KEI         = CREC_N.GENGAKU_KEI          --減額合計
                  , GENMEN              = CREC_N.GENMEN               --減免額
                  , KANENDO             = CREC_N.KANENDO              --過年度分
                  , NENZEI              = CREC_N.NENZEI               --年税額
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;

              --拡張TBL更新(医療年齢軽減(退職)、障害軽減(退職))
              SELECT NVL(b.IRYO_NENREI_KEIGEN_T,0) ,NVL(b.IRYO_SHOGAI_GENMEN_T,0)
                    INTO wIRYO_NENREI_KEIGEN_T,wIRYO_SHOGAI_GENMEN_T
                FROM ZLBTKIHON_N  a,
                     ZLBTEXT_N    b
                WHERE a.KOKU_SETAI_NO   = i_SETAI
                  AND a.SANTEIDANTAI_CD = i_DANTAI
                  AND a.CHOTEI_NENDO    = i_NENDO
                  AND a.NENDO_BUN       = i_NENDO_BUN
                  AND a.TSUCHI_NO       = i_TSUCHI_NO
                  AND b.KOKU_SETAI_NO(+)   = a.KOKU_SETAI_NO
                  AND b.SANTEIDANTAI_CD(+) = a.SANTEIDANTAI_CD
                  AND b.CHOTEI_NENDO(+)    = a.CHOTEI_NENDO
                  AND b.NENDO_BUN(+)       = a.NENDO_BUN
                  AND b.TSUCHI_NO(+)       = a.TSUCHI_NO;

              UPDATE ZLBTEXT_CAL
                SET IRYO_NENREI_KEIGEN_T = wIRYO_NENREI_KEIGEN_T,
                    IRYO_SHOGAI_GENMEN_T = wIRYO_SHOGAI_GENMEN_T
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;
            END IF;
            EXIT;
          END LOOP;
          EXIT;
        END LOOP;
    END PROC_UpCheck_TAI;
-------------------------------------------------------------------------------
-- 計算介護退職と賦課介護退職で比較、税額差が１００円以下の場合は、計算介護退職を賦課介護退職で更新
-------------------------------------------------------------------------------
    PROCEDURE PROC_UpCheck_KAITAI(i_SETAI      IN  NUMBER,       -- 国保世帯番号
                                  i_DANTAI     IN  PLS_INTEGER,  -- 算定団体コード
                                  i_NENDO      IN  PLS_INTEGER,  -- 調定年度
                                  i_NENDO_BUN  IN  PLS_INTEGER,  -- 年度分
                                  i_TSUCHI_NO  IN  NUMBER,       -- 通知書番号
                                  i_TANMATSU   IN  NVARCHAR2) IS -- 端末番号
        NSAGAKU  NUMBER := 0;
        wKAI_NENREI_KEIGEN_T  NUMBER(12,0);
        wKAI_SHOGAI_GENMEN_T  NUMBER(12,0);

        CURSOR CCAL IS
          SELECT NENZEI FROM ZLBTKAI_TAI_CAL
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO
              AND SYS_TANMATSU_NO = i_TANMATSU;
        CURSOR CNOW IS
          SELECT * FROM ZLBTKAI_TAI_N
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO;
    BEGIN
        --税額が１００円以内の差額かどうかをチェック
        FOR CREC_N IN CNOW LOOP
          FOR CREC_C IN CCAL LOOP
            NSAGAKU := ABS(CREC_C.NENZEI - CREC_N.NENZEI);
            IF 0 < NSAGAKU AND NSAGAKU <= 100 THEN
              --税額の差額が１円以上で１００円以内の場合は、ＮをＣＡＬへコピー
              UPDATE ZLBTKAI_TAI_CAL
                SET KEIGEN_SHOTOKU      = CREC_N.KEIGEN_SHOTOKU       --軽減判定所得
                  , SHOTOKU             = CREC_N.SHOTOKU              --所得額
                  , KAHYO               = CREC_N.KAHYO                --課税標準額
                  , SHOTOKU_WARI        = CREC_N.SHOTOKU_WARI         --所得割額
                  , SHISANZEI           = CREC_N.SHISANZEI            --資産税額
                  , SHISAN_WARI         = CREC_N.SHISAN_WARI          --資産割額
                  , KINTO_WARI          = CREC_N.KINTO_WARI           --均等割額
                  , BYODO_WARI          = CREC_N.BYODO_WARI           --平等割額
                  , SEKISAN             = CREC_N.SEKISAN              --積算税額
                  , GENDO_CHOKA         = CREC_N.GENDO_CHOKA          --限度超過額
                  , KEIGEN_K_WARI       = CREC_N.KEIGEN_K_WARI        --軽減均等割額
                  , KEIGEN_B_WARI       = CREC_N.KEIGEN_B_WARI        --軽減平等割額
                  , KEIGEN_K_6          = CREC_N.KEIGEN_K_6           --軽減均等6
                  , KEIGEN_B_6          = CREC_N.KEIGEN_B_6           --軽減平等6
                  , KEIGEN_K_4          = CREC_N.KEIGEN_K_4           --軽減均等4
                  , KEIGEN_B_4          = CREC_N.KEIGEN_B_4           --軽減平等4
                  , KEIGEN_K_2          = CREC_N.KEIGEN_K_2           --軽減均等2
                  , KEIGEN_B_2          = CREC_N.KEIGEN_B_2           --軽減平等2
                  , TSUKIWARI_GEN       = CREC_N.TSUKIWARI_GEN        --月割減額
                  , HASU                = CREC_N.HASU                 --端数
                  , GENGAKU_KEI         = CREC_N.GENGAKU_KEI          --減額合計
                  , GENMEN              = CREC_N.GENMEN               --減免額
                  , KANENDO             = CREC_N.KANENDO              --過年度分
                  , NENZEI              = CREC_N.NENZEI               --年税額
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;

              --拡張TBL更新(介護年齢軽減(退職)、介護障害軽減(退職))
              SELECT NVL(b.KAI_NENREI_KEIGEN_T,0) ,NVL(b.KAI_SHOGAI_GENMEN_T,0)
                    INTO wKAI_NENREI_KEIGEN_T,wKAI_SHOGAI_GENMEN_T
                FROM ZLBTKAI_KIHON_N  a,
                     ZLBTEXT_N    b
                WHERE a.KOKU_SETAI_NO   = i_SETAI
                  AND a.SANTEIDANTAI_CD = i_DANTAI
                  AND a.CHOTEI_NENDO    = i_NENDO
                  AND a.NENDO_BUN       = i_NENDO_BUN
                  AND a.TSUCHI_NO       = i_TSUCHI_NO
                  AND b.KOKU_SETAI_NO(+)   = a.KOKU_SETAI_NO
                  AND b.SANTEIDANTAI_CD(+) = a.SANTEIDANTAI_CD
                  AND b.CHOTEI_NENDO(+)    = a.CHOTEI_NENDO
                  AND b.NENDO_BUN(+)       = a.NENDO_BUN
                  AND b.TSUCHI_NO(+)       = a.TSUCHI_NO;

              UPDATE ZLBTEXT_CAL
                SET KAI_NENREI_KEIGEN_T = wKAI_NENREI_KEIGEN_T,
                     KAI_SHOGAI_GENMEN_T = wKAI_SHOGAI_GENMEN_T
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;
            END IF;
            EXIT;
          END LOOP;
          EXIT;
        END LOOP;
    END PROC_UpCheck_KAITAI;

-------------------------------------------------------------------------------
-- 計算支援退職と賦課支援退職で比較、税額差が１００円以下の場合は、計算支援退職を賦課支援退職で更新
-------------------------------------------------------------------------------
    PROCEDURE PROC_UpCheck_SIENTAI(i_SETAI      IN  NUMBER,       -- 国保世帯番号
                                  i_DANTAI     IN  PLS_INTEGER,  -- 算定団体コード
                                  i_NENDO      IN  PLS_INTEGER,  -- 調定年度
                                  i_NENDO_BUN  IN  PLS_INTEGER,  -- 年度分
                                  i_TSUCHI_NO  IN  NUMBER,       -- 通知書番号
                                  i_TANMATSU   IN  NVARCHAR2) IS -- 端末番号
        NSAGAKU  NUMBER := 0;
        wSIEN_NENREI_KEIGEN_T  NUMBER(12,0);
        wSIEN_SHOGAI_GENMEN_T  NUMBER(12,0);

        CURSOR CCAL IS
          SELECT NENZEI FROM ZLBTSIEN_TAI_CAL
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO
              AND SYS_TANMATSU_NO = i_TANMATSU;
        CURSOR CNOW IS
          SELECT * FROM ZLBTSIEN_TAI_N
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO;
    BEGIN
        --税額が１００円以内の差額かどうかをチェック
        FOR CREC_N IN CNOW LOOP
          FOR CREC_C IN CCAL LOOP
            NSAGAKU := ABS(CREC_C.NENZEI - CREC_N.NENZEI);
            IF 0 < NSAGAKU AND NSAGAKU <= 100 THEN
              --税額の差額が１円以上で１００円以内の場合は、ＮをＣＡＬへコピー
              UPDATE ZLBTSIEN_TAI_CAL
                SET KEIGEN_SHOTOKU      = CREC_N.KEIGEN_SHOTOKU       --軽減判定所得
                  , SHOTOKU             = CREC_N.SHOTOKU              --所得額
                  , KAHYO               = CREC_N.KAHYO                --課税標準額
                  , SHOTOKU_WARI        = CREC_N.SHOTOKU_WARI         --所得割額
                  , SHISANZEI           = CREC_N.SHISANZEI            --資産税額
                  , SHISAN_WARI         = CREC_N.SHISAN_WARI          --資産割額
                  , KINTO_WARI          = CREC_N.KINTO_WARI           --均等割額
                  , BYODO_WARI          = CREC_N.BYODO_WARI           --平等割額
                  , SEKISAN             = CREC_N.SEKISAN              --積算税額
                  , GENDO_CHOKA         = CREC_N.GENDO_CHOKA          --限度超過額
                  , KEIGEN_K_WARI       = CREC_N.KEIGEN_K_WARI        --軽減均等割額
                  , KEIGEN_B_WARI       = CREC_N.KEIGEN_B_WARI        --軽減平等割額
                  , KEIGEN_K_6          = CREC_N.KEIGEN_K_6           --軽減均等6
                  , KEIGEN_B_6          = CREC_N.KEIGEN_B_6           --軽減平等6
                  , KEIGEN_K_4          = CREC_N.KEIGEN_K_4           --軽減均等4
                  , KEIGEN_B_4          = CREC_N.KEIGEN_B_4           --軽減平等4
                  , KEIGEN_K_2          = CREC_N.KEIGEN_K_2           --軽減均等2
                  , KEIGEN_B_2          = CREC_N.KEIGEN_B_2           --軽減平等2
                  , TSUKIWARI_GEN       = CREC_N.TSUKIWARI_GEN        --月割減額
                  , HASU                = CREC_N.HASU                 --端数
                  , GENGAKU_KEI         = CREC_N.GENGAKU_KEI          --減額合計
                  , GENMEN              = CREC_N.GENMEN               --減免額
                  , KANENDO             = CREC_N.KANENDO              --過年度分
                  , NENZEI              = CREC_N.NENZEI               --年税額
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;

              --拡張TBL更新(支援年齢軽減(退職)、支援障害軽減(退職))
              SELECT NVL(b.SHI_NENREI_KEIGEN_T,0) ,NVL(b.SHI_SHOGAI_GENMEN_T,0)
                    INTO wSIEN_NENREI_KEIGEN_T,wSIEN_SHOGAI_GENMEN_T
                FROM ZLBTSIEN_KIHON_N  a,
                     ZLBTEXT_N    b
                WHERE a.KOKU_SETAI_NO   = i_SETAI
                  AND a.SANTEIDANTAI_CD = i_DANTAI
                  AND a.CHOTEI_NENDO    = i_NENDO
                  AND a.NENDO_BUN       = i_NENDO_BUN
                  AND a.TSUCHI_NO       = i_TSUCHI_NO
                  AND b.KOKU_SETAI_NO(+)   = a.KOKU_SETAI_NO
                  AND b.SANTEIDANTAI_CD(+) = a.SANTEIDANTAI_CD
                  AND b.CHOTEI_NENDO(+)    = a.CHOTEI_NENDO
                  AND b.NENDO_BUN(+)       = a.NENDO_BUN
                  AND b.TSUCHI_NO(+)       = a.TSUCHI_NO;

              UPDATE ZLBTEXT_CAL
                SET SHI_NENREI_KEIGEN_T = wSIEN_NENREI_KEIGEN_T,
                     SHI_SHOGAI_GENMEN_T = wSIEN_SHOGAI_GENMEN_T
                WHERE KOKU_SETAI_NO   = i_SETAI
                  AND SANTEIDANTAI_CD = i_DANTAI
                  AND CHOTEI_NENDO    = i_NENDO
                  AND NENDO_BUN       = i_NENDO_BUN
                  AND TSUCHI_NO       = i_TSUCHI_NO
                  AND SYS_TANMATSU_NO = i_TANMATSU;
            END IF;
            EXIT;
          END LOOP;
          EXIT;
        END LOOP;
    END PROC_UpCheck_SIENTAI;

--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
-------------------------------------------------------------------------------
-- 計算子どもと賦課子どもで比較、税額差が１００円以下の場合は、計算子どもを賦課子どもで更新
-------------------------------------------------------------------------------
    PROCEDURE PROC_UpCheck_KDM(i_SETAI      IN  NUMBER,       -- 国保世帯番号
                               i_DANTAI     IN  PLS_INTEGER,  -- 算定団体コード
                               i_NENDO      IN  PLS_INTEGER,  -- 調定年度
                               i_NENDO_BUN  IN  PLS_INTEGER,  -- 年度分
                               i_TSUCHI_NO  IN  NUMBER,       -- 通知書番号
                               i_TANMATSU   IN  NVARCHAR2) IS -- 端末番号
        NSAGAKU  NUMBER := 0;
        wKDM_NENREI_KEIGEN  NUMBER(12,0);
        wKDM_SHOGAI_GENMEN  NUMBER(12,0);

        CURSOR CCAL IS
          SELECT NENZEI FROM ZLBTKDM_KIHON_CAL
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO
              AND SYS_TANMATSU_NO = i_TANMATSU;
        CURSOR CNEW IS
          SELECT * FROM ZLBTKDM_KIHON_N
            WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO;
    BEGIN
        --税額が１００円以内の差額かどうかをチェック
        FOR CREC_N IN CNEW LOOP
            FOR CREC_C IN CCAL LOOP
                NSAGAKU := ABS(CREC_C.NENZEI - CREC_N.NENZEI);
                IF 0 < NSAGAKU AND NSAGAKU <= 100 THEN
                    --税額の差額が１円以上で１００円以内の場合は、ＮをＣＡＬへコピー
                    UPDATE ZLBTKDM_KIHON_CAL
                       SET KEIGEN_SHOTOKU      = CREC_N.KEIGEN_SHOTOKU       --軽減判定所得
                         , SHOTOKU             = CREC_N.SHOTOKU              --所得額
                         , KAHYO               = CREC_N.KAHYO                --課税標準額
                         , SHOTOKU_WARI        = CREC_N.SHOTOKU_WARI         --所得割額
                         , SHISANZEI           = CREC_N.SHISANZEI            --資産税額
                         , SHISAN_WARI         = CREC_N.SHISAN_WARI          --資産割額
                         , KINTO_WARI          = CREC_N.KINTO_WARI           --均等割額
                         , BYODO_WARI          = CREC_N.BYODO_WARI           --平等割額
                         , SEKISAN             = CREC_N.SEKISAN              --積算税額
                         , GENDO_CHOKA         = CREC_N.GENDO_CHOKA          --限度超過額
                         , KEIGEN_K_WARI       = CREC_N.KEIGEN_K_WARI        --軽減均等割額
                         , KEIGEN_B_WARI       = CREC_N.KEIGEN_B_WARI        --軽減平等割額
                         , KEIGEN_K_6          = CREC_N.KEIGEN_K_6           --軽減均等6
                         , KEIGEN_B_6          = CREC_N.KEIGEN_B_6           --軽減平等6
                         , KEIGEN_K_4          = CREC_N.KEIGEN_K_4           --軽減均等4
                         , KEIGEN_B_4          = CREC_N.KEIGEN_B_4           --軽減平等4
                         , KEIGEN_K_2          = CREC_N.KEIGEN_K_2           --軽減均等2
                         , KEIGEN_B_2          = CREC_N.KEIGEN_B_2           --軽減平等2
                         , TSUKIWARI_GEN       = CREC_N.TSUKIWARI_GEN        --月割減額
                         , HASU                = CREC_N.HASU                 --端数
                         , GENGAKU_KEI         = CREC_N.GENGAKU_KEI          --減額合計
                         , GENMEN              = CREC_N.GENMEN               --減免額
                         , KANENDO             = CREC_N.KANENDO              --過年度分
                         , NENZEI              = CREC_N.NENZEI               --年税額
                         , KINTO_KDM18         = CREC_N.KINTO_KDM18          --子ども18歳以上均等割額
                     WHERE KOKU_SETAI_NO   = i_SETAI
                       AND SANTEIDANTAI_CD = i_DANTAI
                       AND CHOTEI_NENDO    = i_NENDO
                       AND NENDO_BUN       = i_NENDO_BUN
                       AND TSUCHI_NO       = i_TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_TANMATSU;
                    
                    --拡張TBL更新(子ども年齢軽減、子ども身障減免)
                    SELECT NVL(b.KDM_NENREI_KEIGEN, 0), NVL(b.KDM_SHOGAI_GENMEN, 0)
                      INTO wKDM_NENREI_KEIGEN, wKDM_SHOGAI_GENMEN
                      FROM ZLBTKDM_KIHON_N  a,
                           ZLBTEXT_N  b
                     WHERE a.KOKU_SETAI_NO   = i_SETAI
                       AND a.SANTEIDANTAI_CD = i_DANTAI
                       AND a.CHOTEI_NENDO    = i_NENDO
                       AND a.NENDO_BUN       = i_NENDO_BUN
                       AND a.TSUCHI_NO       = i_TSUCHI_NO
                       AND b.KOKU_SETAI_NO(+)   = a.KOKU_SETAI_NO
                       AND b.SANTEIDANTAI_CD(+) = a.SANTEIDANTAI_CD
                       AND b.CHOTEI_NENDO(+)    = a.CHOTEI_NENDO
                       AND b.NENDO_BUN(+)       = a.NENDO_BUN
                       AND b.TSUCHI_NO(+)       = a.TSUCHI_NO;
                    
                    UPDATE ZLBTEXT_CAL
                       SET KDM_NENREI_KEIGEN = wKDM_NENREI_KEIGEN,
                           KDM_SHOGAI_GENMEN = wKDM_SHOGAI_GENMEN
                     WHERE KOKU_SETAI_NO   = i_SETAI
                       AND SANTEIDANTAI_CD = i_DANTAI
                       AND CHOTEI_NENDO    = i_NENDO
                       AND NENDO_BUN       = i_NENDO_BUN
                       AND TSUCHI_NO       = i_TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_TANMATSU;
                END IF;
                EXIT;
            END LOOP;
            EXIT;
        END LOOP;
    END PROC_UpCheck_KDM;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
-------------------------------------------------------------------------------
-- 計算基本と賦課基本で比較、積算税額が同じ、月割減額が同じ、年税額が違う場合
-------------------------------------------------------------------------------
    PROCEDURE PROC_Keigen_Gaitou(i_SETAI      IN  NUMBER,       -- 国保世帯番号
                                 i_DANTAI     IN  PLS_INTEGER,  -- 算定団体コード
                                 i_NENDO      IN  PLS_INTEGER,  -- 調定年度
                                 i_NENDO_BUN  IN  PLS_INTEGER,  -- 年度分
                                 i_TSUCHI_NO  IN  NUMBER,       -- 通知書番号
                                 i_TANMATSU   IN  NVARCHAR2) IS -- 端末番号
    -- 計算基本
      CURSOR CCAL IS
        SELECT SEKISAN, TSUKIWARI_GEN, NENZEI, SHISAN_WARI, IDO_JIYU, GENMEN FROM ZLBTKIHON_CAL
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO
            AND SYS_TANMATSU_NO = i_TANMATSU;

    -- 賦課基本
      CURSOR CNOW IS
        SELECT SEKISAN, TSUKIWARI_GEN, NENZEI, SHISAN_WARI, IDO_JIYU, GENMEN FROM ZLBTKIHON_N
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO;

    -- 介護計算基本
      CURSOR CKAI_CAL IS
        SELECT SEKISAN, TSUKIWARI_GEN, NENZEI, SHISAN_WARI, IDO_JIYU, GENMEN FROM ZLBTKAI_KIHON_CAL
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO
            AND SYS_TANMATSU_NO = i_TANMATSU;

    -- 介護賦課基本
      CURSOR CKAI_NOW IS
        SELECT SEKISAN, TSUKIWARI_GEN, NENZEI, SHISAN_WARI, IDO_JIYU, GENMEN FROM ZLBTKAI_KIHON_N
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO;

    -- 支援計算基本
      CURSOR CSIEN_CAL IS
        SELECT SEKISAN, TSUKIWARI_GEN, NENZEI, SHISAN_WARI, IDO_JIYU, GENMEN FROM ZLBTSIEN_KIHON_CAL
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO
            AND SYS_TANMATSU_NO = i_TANMATSU;

    -- 支援賦課基本
      CURSOR CSIEN_NOW IS
        SELECT SEKISAN, TSUKIWARI_GEN, NENZEI, SHISAN_WARI, IDO_JIYU, GENMEN FROM ZLBTSIEN_KIHON_N
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
    -- 計算子ども基本
      CURSOR CKDM_CAL IS
        SELECT SEKISAN, TSUKIWARI_GEN, NENZEI, SHISAN_WARI, IDO_JIYU, GENMEN FROM ZLBTKDM_KIHON_CAL
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO
            AND SYS_TANMATSU_NO = i_TANMATSU;

    -- 賦課子ども基本(最新)
      CURSOR CKDM_NEW IS
        SELECT SEKISAN, TSUKIWARI_GEN, NENZEI, SHISAN_WARI, IDO_JIYU, GENMEN FROM ZLBTKDM_KIHON_N
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
    -- 計算拡張
      CURSOR CEXT_CAL IS
        SELECT  H_KBN
           FROM ZLBTEXT_CAL
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO
            AND SYS_TANMATSU_NO = i_TANMATSU;

    -- 賦課拡張
      CURSOR CEXT_NOW IS
        SELECT  H_KBN
           FROM ZLBTEXT_N
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO;

    -- 計算個人
      CURSOR CKOJIN_CAL IS
        SELECT  NEW_KAI_SHIK_KBN, NEW_SHITSU_KBN
           FROM ZLBTKOJIN_CAL
          WHERE KOKU_SETAI_NO   = i_SETAI
            AND SANTEIDANTAI_CD = i_DANTAI
            AND CHOTEI_NENDO    = i_NENDO
            AND NENDO_BUN       = i_NENDO_BUN
            AND TSUCHI_NO       = i_TSUCHI_NO
            AND SYS_TANMATSU_NO = i_TANMATSU;

    NwJiyu      NUMBER; -- 異動事由
    NwSHINSEI_BI  NUMBER; -- 更正日
    BEGIN
    NwJiyu := 0;
    NwSHINSEI_BI := 0;

    -- 賦課基本ループ
    FOR CREC_N IN CNOW LOOP
       -- 計算基本ループ
      FOR CREC_C IN CCAL LOOP
        NwJiyu := CREC_C.IDO_JIYU;

        -- 更正事由が資産割なら世帯も比較する。
        IF CREC_C.IDO_JIYU = c_NJIYU_SHISANKOSEI AND
           CREC_N.SHISAN_WARI = CREC_C.SHISAN_WARI THEN

          -- 事由更新
          BEGIN
            UPDATE ZLBTKIHON_CAL
              SET IDO_JIYU = 0
              WHERE KOKU_SETAI_NO = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO
              AND SYS_TANMATSU_NO = i_TANMATSU;
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;
        END IF;

        --積算税額が同じ、月割減額が同じ、年税額が違う場合
        --軽減に該当したと見なす。
        IF CREC_N.SEKISAN = CREC_C.SEKISAN AND
          CREC_N.TSUKIWARI_GEN = CREC_C.TSUKIWARI_GEN AND
          CREC_N.NENZEI <> CREC_C.NENZEI THEN

          NwJiyu := c_NJIYU_KEIGENKOSEI;
          NwSHINSEI_BI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));

          -- 更正日取得
          BEGIN
            SELECT SHINSEI_BI INTO NwSHINSEI_BI
            FROM ZLBTKEIGEN
            WHERE NENDO = i_NENDO_BUN
            AND KOKU_SETAI_NO   = i_SETAI;
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;

          -- 事由更新
          BEGIN
            UPDATE ZLBTKIHON_CAL
            SET IDO_JIYU = c_NJIYU_KEIGENKOSEI
              WHERE KOKU_SETAI_NO   = i_SETAI
              AND SANTEIDANTAI_CD = i_DANTAI
              AND CHOTEI_NENDO    = i_NENDO
              AND NENDO_BUN       = i_NENDO_BUN
              AND TSUCHI_NO       = i_TSUCHI_NO
              AND SYS_TANMATSU_NO = i_TANMATSU;
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;
        END IF;

        EXIT;
      END LOOP;
      EXIT;
    END LOOP;

    -- 医療が軽減該当及び資産更正ならば
    IF NwJiyu = c_NJIYU_KEIGENKOSEI OR NwJiyu = c_NJIYU_SHISANKOSEI THEN
      -- 介護賦課基本ループ
      FOR CRECKAI_N IN CKAI_NOW LOOP
         -- 介護計算基本ループ
        FOR CRECKAI_C IN CKAI_CAL LOOP
          -- 更正事由が資産割なら世帯も比較する。
          IF CRECKAI_C.IDO_JIYU = c_NJIYU_SHISANKOSEI AND
             CRECKAI_N.SHISAN_WARI = CRECKAI_C.SHISAN_WARI THEN
            -- 事由更新
            BEGIN
              UPDATE ZLBTKAI_KIHON_CAL
                SET IDO_JIYU = 0
                WHERE KOKU_SETAI_NO = i_SETAI
                AND SANTEIDANTAI_CD = i_DANTAI
                AND CHOTEI_NENDO    = i_NENDO
                AND NENDO_BUN       = i_NENDO_BUN
                AND TSUCHI_NO       = i_TSUCHI_NO
                AND SYS_TANMATSU_NO = i_TANMATSU;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF;

          NwSHINSEI_BI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));

          --積算税額が同じ、月割減額が同じ、年税額が違う場合
          --軽減に該当したと見なす。
          IF CRECKAI_N.SEKISAN = CRECKAI_C.SEKISAN AND
            CRECKAI_N.TSUKIWARI_GEN = CRECKAI_C.TSUKIWARI_GEN AND
            CRECKAI_N.NENZEI <> CRECKAI_C.NENZEI THEN

            -- 更正日取得
            BEGIN
              SELECT SHINSEI_BI INTO NwSHINSEI_BI
                FROM ZLBTKEIGEN
                WHERE NENDO = i_NENDO_BUN
                AND KOKU_SETAI_NO   = i_SETAI;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;

            -- 事由更新
            BEGIN
              UPDATE ZLBTKAI_KIHON_CAL
                SET IDO_JIYU = c_NJIYU_KEIGENKOSEI
                WHERE KOKU_SETAI_NO = i_SETAI
                AND SANTEIDANTAI_CD = i_DANTAI
                AND CHOTEI_NENDO    = i_NENDO
                AND NENDO_BUN       = i_NENDO_BUN
                AND TSUCHI_NO       = i_TSUCHI_NO
                AND SYS_TANMATSU_NO = i_TANMATSU;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF;
          EXIT;
        END LOOP;
        EXIT;
      END LOOP;

      -- 支援賦課基本ループ
      FOR CRECSIEN_N IN CSIEN_NOW LOOP
         -- 支援計算基本ループ
        FOR CRECSIEN_C IN CSIEN_CAL LOOP
          -- 更正事由が資産割なら世帯も比較する。
          IF CRECSIEN_C.IDO_JIYU = c_NJIYU_SHISANKOSEI AND
             CRECSIEN_N.SHISAN_WARI = CRECSIEN_C.SHISAN_WARI THEN
            -- 事由更新
            BEGIN
              UPDATE ZLBTSIEN_KIHON_CAL
                SET IDO_JIYU = 0
                WHERE KOKU_SETAI_NO = i_SETAI
                AND SANTEIDANTAI_CD = i_DANTAI
                AND CHOTEI_NENDO    = i_NENDO
                AND NENDO_BUN       = i_NENDO_BUN
                AND TSUCHI_NO       = i_TSUCHI_NO
                AND SYS_TANMATSU_NO = i_TANMATSU;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF;

          -- システム日付セット
          NwSHINSEI_BI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));

          --積算税額が同じ、月割減額が同じ、年税額が違う場合
          --軽減に該当したと見なす。
          IF CRECSIEN_N.SEKISAN = CRECSIEN_C.SEKISAN AND
            CRECSIEN_N.TSUKIWARI_GEN = CRECSIEN_C.TSUKIWARI_GEN AND
            CRECSIEN_N.NENZEI <> CRECSIEN_C.NENZEI THEN

            -- 更正日取得
            BEGIN
              SELECT SHINSEI_BI INTO NwSHINSEI_BI
                FROM ZLBTKEIGEN
                WHERE NENDO = i_NENDO_BUN
                AND KOKU_SETAI_NO   = i_SETAI;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;

            -- 事由更新
            BEGIN
              UPDATE ZLBTSIEN_KIHON_CAL
                SET IDO_JIYU = c_NJIYU_KEIGENKOSEI
                WHERE KOKU_SETAI_NO = i_SETAI
                AND SANTEIDANTAI_CD = i_DANTAI
                AND CHOTEI_NENDO    = i_NENDO
                AND NENDO_BUN       = i_NENDO_BUN
                AND TSUCHI_NO       = i_TSUCHI_NO
                AND SYS_TANMATSU_NO = i_TANMATSU;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF;
          EXIT;
        END LOOP;
        EXIT;
      END LOOP;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
      -- 子ども賦課基本ループ
      FOR CRECKDM_N IN CKDM_NEW LOOP
          -- 子ども計算基本ループ
          FOR CRECKDM_C IN CKDM_CAL LOOP
              -- 更正事由が資産割なら世帯も比較する。
              IF CRECKDM_C.IDO_JIYU = c_NJIYU_SHISANKOSEI AND
                 CRECKDM_N.SHISAN_WARI = CRECKDM_C.SHISAN_WARI THEN
                  -- 事由更新
                  BEGIN
                      UPDATE ZLBTKDM_KIHON_CAL
                         SET IDO_JIYU = 0
                       WHERE KOKU_SETAI_NO   = i_SETAI
                         AND SANTEIDANTAI_CD = i_DANTAI
                         AND CHOTEI_NENDO    = i_NENDO
                         AND NENDO_BUN       = i_NENDO_BUN
                         AND TSUCHI_NO       = i_TSUCHI_NO
                         AND SYS_TANMATSU_NO = i_TANMATSU;
                  EXCEPTION
                      WHEN OTHERS THEN
                          NULL;
                  END;
              END IF;

              -- システム日付セット
              NwSHINSEI_BI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));

              --積算税額が同じ、月割減額が同じ、年税額が違う場合
              --軽減に該当したと見なす。
              IF CRECKDM_N.SEKISAN = CRECKDM_C.SEKISAN AND
                 CRECKDM_N.TSUKIWARI_GEN = CRECKDM_C.TSUKIWARI_GEN AND
                 CRECKDM_N.NENZEI <> CRECKDM_C.NENZEI THEN

                  -- 更正日取得
                  BEGIN
                      SELECT SHINSEI_BI INTO NwSHINSEI_BI
                        FROM ZLBTKEIGEN
                       WHERE NENDO = i_NENDO_BUN
                         AND KOKU_SETAI_NO = i_SETAI;
                  EXCEPTION
                      WHEN OTHERS THEN
                          NULL;
                  END;

                  -- 事由更新
                  BEGIN
                      UPDATE ZLBTKDM_KIHON_CAL
                         SET IDO_JIYU = c_NJIYU_KEIGENKOSEI
                       WHERE KOKU_SETAI_NO   = i_SETAI
                         AND SANTEIDANTAI_CD = i_DANTAI
                         AND CHOTEI_NENDO    = i_NENDO
                         AND NENDO_BUN       = i_NENDO_BUN
                         AND TSUCHI_NO       = i_TSUCHI_NO
                         AND SYS_TANMATSU_NO = i_TANMATSU;
                  EXCEPTION
                      WHEN OTHERS THEN
                          NULL;
                  END;
              END IF;
              EXIT;
          END LOOP;
          EXIT;
      END LOOP;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
    END IF;

    -- 更正事由は、軽減より減免を優先させる
    -- 賦課基本ループ
    FOR CREC_N IN CNOW LOOP
       -- 計算基本ループ
      FOR CREC_C IN CCAL LOOP
        NwJiyu := CREC_C.IDO_JIYU;

        --積算税額が同じ、月割減額が同じ、年税額が違う場合
        --軽減に該当したと見なす。
        IF CREC_N.SEKISAN = CREC_C.SEKISAN AND
          CREC_N.TSUKIWARI_GEN = CREC_C.TSUKIWARI_GEN AND
          CREC_N.NENZEI <> CREC_C.NENZEI THEN

          IF CREC_N.GENMEN <> CREC_C.GENMEN THEN
            -- 事由更新
            BEGIN
              UPDATE ZLBTKIHON_CAL
              SET IDO_JIYU = c_NJIYU_GENMEN
                WHERE KOKU_SETAI_NO   = i_SETAI
                AND SANTEIDANTAI_CD = i_DANTAI
                AND CHOTEI_NENDO    = i_NENDO
                AND NENDO_BUN       = i_NENDO_BUN
                AND TSUCHI_NO       = i_TSUCHI_NO
                AND SYS_TANMATSU_NO = i_TANMATSU;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF;
        END IF;

        EXIT;
      END LOOP;
      EXIT;
    END LOOP;

    -- 介護賦課基本ループ
    FOR CRECKAI_N IN CKAI_NOW LOOP
       -- 介護計算基本ループ
      FOR CRECKAI_C IN CKAI_CAL LOOP
        --積算税額が同じ、月割減額が同じ、年税額が違う場合
        --軽減に該当したと見なす。
        IF CRECKAI_N.SEKISAN = CRECKAI_C.SEKISAN AND
          CRECKAI_N.TSUKIWARI_GEN = CRECKAI_C.TSUKIWARI_GEN AND
          CRECKAI_N.NENZEI <> CRECKAI_C.NENZEI THEN

          IF CRECKAI_N.GENMEN <> CRECKAI_C.GENMEN THEN
            -- 事由更新
            BEGIN
              UPDATE ZLBTKAI_KIHON_CAL
                SET IDO_JIYU = c_NJIYU_GENMEN
                WHERE KOKU_SETAI_NO = i_SETAI
                AND SANTEIDANTAI_CD = i_DANTAI
                AND CHOTEI_NENDO    = i_NENDO
                AND NENDO_BUN       = i_NENDO_BUN
                AND TSUCHI_NO       = i_TSUCHI_NO
                AND SYS_TANMATSU_NO = i_TANMATSU;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF;
        END IF;
        EXIT;
      END LOOP;
      EXIT;
    END LOOP;

    -- 支援賦課基本ループ
    FOR CRECSIEN_N IN CSIEN_NOW LOOP
       -- 支援計算基本ループ
      FOR CRECSIEN_C IN CSIEN_CAL LOOP
        --積算税額が同じ、月割減額が同じ、年税額が違う場合
        --軽減に該当したと見なす。
        IF CRECSIEN_N.SEKISAN = CRECSIEN_C.SEKISAN AND
          CRECSIEN_N.TSUKIWARI_GEN = CRECSIEN_C.TSUKIWARI_GEN AND
          CRECSIEN_N.NENZEI <> CRECSIEN_C.NENZEI THEN

          IF CRECSIEN_N.GENMEN <> CRECSIEN_C.GENMEN THEN
            -- 事由更新
            BEGIN
              UPDATE ZLBTSIEN_KIHON_CAL
                SET IDO_JIYU = c_NJIYU_GENMEN
                WHERE KOKU_SETAI_NO = i_SETAI
                AND SANTEIDANTAI_CD = i_DANTAI
                AND CHOTEI_NENDO    = i_NENDO
                AND NENDO_BUN       = i_NENDO_BUN
                AND TSUCHI_NO       = i_TSUCHI_NO
                AND SYS_TANMATSU_NO = i_TANMATSU;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF;
        END IF;
        EXIT;
      END LOOP;
      EXIT;
    END LOOP;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
    -- 子ども賦課基本ループ
    FOR CRECKDM_N IN CKDM_NEW LOOP
        -- 子ども計算基本ループ
        FOR CRECKDM_C IN CKDM_CAL LOOP
            --積算税額が同じ、月割減額が同じ、年税額が違う場合
            --軽減に該当したと見なす。
            IF CRECKDM_N.SEKISAN = CRECKDM_C.SEKISAN AND
               CRECKDM_N.TSUKIWARI_GEN = CRECKDM_C.TSUKIWARI_GEN AND
               CRECKDM_N.NENZEI <> CRECKDM_C.NENZEI THEN
            
                IF CRECKDM_N.GENMEN <> CRECKDM_C.GENMEN THEN
                    -- 事由更新
                    BEGIN
                        UPDATE ZLBTKDM_KIHON_CAL
                           SET IDO_JIYU = c_NJIYU_GENMEN
                         WHERE KOKU_SETAI_NO   = i_SETAI
                           AND SANTEIDANTAI_CD = i_DANTAI
                           AND CHOTEI_NENDO    = i_NENDO
                           AND NENDO_BUN       = i_NENDO_BUN
                           AND TSUCHI_NO       = i_TSUCHI_NO
                           AND SYS_TANMATSU_NO = i_TANMATSU;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NULL;
                    END;
                END IF;
            END IF;
            EXIT;
        END LOOP;
        EXIT;
    END LOOP;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
    -- 賦課拡張ループ
    FOR CRECEXT_N IN CEXT_NOW LOOP
      -- 計算拡張ループ
      FOR CRECEXT_C IN CEXT_CAL LOOP
        -- 更正前の旧被扶養該当区分が2または3以外で
        -- 更正後の旧被扶養該当区分が2または3の場合
        IF CRECEXT_N.H_KBN NOT IN (2, 3) AND
           CRECEXT_C.H_KBN     IN (2, 3) THEN
          -- 事由更新
          UPDATE ZLBTKIHON_CAL
             SET IDO_JIYU        = c_NJIYU_KEIGENKOSEI
           WHERE KOKU_SETAI_NO   = i_SETAI
             AND SANTEIDANTAI_CD = i_DANTAI
             AND CHOTEI_NENDO    = i_NENDO
             AND NENDO_BUN       = i_NENDO_BUN
             AND TSUCHI_NO       = i_TSUCHI_NO
             AND SYS_TANMATSU_NO = i_TANMATSU;
          -- 事由更新
          UPDATE ZLBTSIEN_KIHON_CAL
             SET IDO_JIYU        = c_NJIYU_KEIGENKOSEI
           WHERE KOKU_SETAI_NO   = i_SETAI
             AND SANTEIDANTAI_CD = i_DANTAI
             AND CHOTEI_NENDO    = i_NENDO
             AND NENDO_BUN       = i_NENDO_BUN
             AND TSUCHI_NO       = i_TSUCHI_NO
             AND SYS_TANMATSU_NO = i_TANMATSU;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
          -- 事由更新
          UPDATE ZLBTKDM_KIHON_CAL
             SET IDO_JIYU        = c_NJIYU_KEIGENKOSEI
           WHERE KOKU_SETAI_NO   = i_SETAI
             AND SANTEIDANTAI_CD = i_DANTAI
             AND CHOTEI_NENDO    = i_NENDO
             AND NENDO_BUN       = i_NENDO_BUN
             AND TSUCHI_NO       = i_TSUCHI_NO
             AND SYS_TANMATSU_NO = i_TANMATSU;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
          -- 計算個人ループ
          FOR CRECKOJIN_C IN CKOJIN_CAL LOOP
            -- 最新介護資格区分が1で最新失業者資格区分が>0の場合
            IF CRECKOJIN_C.NEW_KAI_SHIK_KBN = 1 AND
               CRECKOJIN_C.NEW_SHITSU_KBN   > 0 THEN
              -- 事由更新
              UPDATE ZLBTKAI_KIHON_CAL
                 SET IDO_JIYU        = c_NJIYU_KEIGENKOSEI
               WHERE KOKU_SETAI_NO   = i_SETAI
                 AND SANTEIDANTAI_CD = i_DANTAI
                 AND CHOTEI_NENDO    = i_NENDO
                 AND NENDO_BUN       = i_NENDO_BUN
                 AND TSUCHI_NO       = i_TSUCHI_NO
                 AND SYS_TANMATSU_NO = i_TANMATSU;
              EXIT;
            END IF;
          END LOOP;
        -- 更正前の旧被扶養該当区分が1または3以外で
        -- 更正後の旧被扶養該当区分が1または3の場合
        ELSIF CRECEXT_N.H_KBN NOT IN (1, 3) AND
              CRECEXT_C.H_KBN     IN (1, 3) THEN
          -- 事由更新
          UPDATE ZLBTKIHON_CAL
             SET IDO_JIYU        = c_NJIYU_GENMEN
           WHERE KOKU_SETAI_NO   = i_SETAI
             AND SANTEIDANTAI_CD = i_DANTAI
             AND CHOTEI_NENDO    = i_NENDO
             AND NENDO_BUN       = i_NENDO_BUN
             AND TSUCHI_NO       = i_TSUCHI_NO
             AND SYS_TANMATSU_NO = i_TANMATSU;
          -- 事由更新
          UPDATE ZLBTSIEN_KIHON_CAL
             SET IDO_JIYU        = c_NJIYU_GENMEN
           WHERE KOKU_SETAI_NO   = i_SETAI
             AND SANTEIDANTAI_CD = i_DANTAI
             AND CHOTEI_NENDO    = i_NENDO
             AND NENDO_BUN       = i_NENDO_BUN
             AND TSUCHI_NO       = i_TSUCHI_NO
             AND SYS_TANMATSU_NO = i_TANMATSU;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
          -- 事由更新
          UPDATE ZLBTKDM_KIHON_CAL
             SET IDO_JIYU        = c_NJIYU_GENMEN
           WHERE KOKU_SETAI_NO   = i_SETAI
             AND SANTEIDANTAI_CD = i_DANTAI
             AND CHOTEI_NENDO    = i_NENDO
             AND NENDO_BUN       = i_NENDO_BUN
             AND TSUCHI_NO       = i_TSUCHI_NO
             AND SYS_TANMATSU_NO = i_TANMATSU;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
        END IF;

        EXIT;
      END LOOP;
      EXIT;
    END LOOP;

    END PROC_Keigen_Gaitou;

-------------------------------------------------------------------------------
-- 05 計算基本・計算介護基本作成
-------------------------------------------------------------------------------
    FUNCTION funcKihon(i_NKOKU_SETAI_NO   IN  NUMBER,
                       i_NSANTEIDANTAI_CD IN  NUMBER,
                       i_NNUSI_KOJIN_NO   IN  NUMBER) RETURN NUMBER IS

        NwRTN           NUMBER(1);
        NwKEIGEN_BI     NUMBER(8);
        NwJIKKOU_KBN    NUMBER;     --実行区分
        NwCAL_KBN       NUMBER;     --呼出区分
        NwCnt           NUMBER;
        NwCnt2          NUMBER;
        -- 軽減判定被保険者数（実態調査[世帯票]でのみ使用）
        NwHIHO_SU       NUMBER;
        NwJIKKOU_KBN_BK NUMBER;     --実行区分（退避用）
        Nw_N25SISAN     NUMBER;     --5割軽減判定人数
        Nw_IZAN_MODE    NUMBER;     --FCZANMODE_ONLの戻り値
    BEGIN
        NwRTN       := c_NOK;
        NwKEIGEN_BI := 0;

        IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
          --課税状況の場合
          NwJIKKOU_KBN := c_NBATCH;      --バッチから起動
          NwCAL_KBN    := c_CAL_KBN_FK;  --1:賦課期日時点処理
        ELSE
          NwJIKKOU_KBN := i_NJIKKOU_KBN;
          NwCAL_KBN    := c_CAL_KBN_TU;  --0:通常処理
        END IF;
        -- 《計算軽減判定日削除・登録》
        BEGIN
          IF i_NJIKKOU_KBN = c_JITTAI_SETAI THEN
            DELETE FROM ZLBTKEIGENHANTEI_CAL
             WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

            INSERT INTO ZLBTKEIGENHANTEI_CAL (KOKU_SETAI_NO
                                             ,HANTEI_4
                                             ,SYS_TANMATSU_NO)
                                      VALUES (i_NKOKU_SETAI_NO
                                             ,NlNENDO_BUN * 10000 + 0930
                                             ,i_VMASIN_NO);
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            NwRTN := c_NERR;
            VlMSG := 'ZLBTKEIGENHANTEI_CAL 削除/登録エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_NKOKU_SETAI_NO ;
        END;
      --平成26年度仮算定、及び仮算定異動処理で市町村条件(86)が '1’の場合は、世帯主を含まない
       IF NlNENDO_BUN > 2013 THEN
         Nw_N25SISAN := 1;
        IF NlNENDO_BUN = 2014 THEN
          IF i_NNOUKI_KBN = c_NNOUKI_KARISAN THEN
            IF ZLBPK00010.FCFFJKN2(86) = 1 THEN
              Nw_N25SISAN := 0;
            END IF;
          END IF;
          IF ZLBPK00010.FCFFJKN2(411) = 1 THEN
            IF i_NJIKKOU_KBN IN (c_NONLNIN, c_NONLNIN_SISAN) THEN
              Nw_IZAN_MODE := ZLBPK00010.FCZANMODE_ONL(i_NCHOTEI_NENDO, NlNENDO_BUN, i_NKIJUNBI);
            ELSE
              Nw_IZAN_MODE := ZLBPK00010.FCZANMODE(i_NCHOTEI_NENDO, NlNENDO_BUN);
            END IF;
            IF Nw_IZAN_MODE = 1 AND ZLBPK00010.FCFFJKN2(86) = 1 THEN
              Nw_N25SISAN := 0;
            END IF;
          END IF;
        END IF;
       ELSE
          Nw_N25SISAN := 0;
       END IF;
        -- 軽減判定区分セット
        ZLBSKCALKG(i_NKOKU_SETAI_NO,     -- 国保世帯番号
                      i_NSANTEIDANTAI_CD,   -- 算定団体コード
                      i_NNUSI_KOJIN_NO,     -- 世帯主個人番号
                      i_NCHOTEI_NENDO,      -- 調定年度
                      NlNENDO_BUN,          -- 年度分
                      NwJIKKOU_KBN,         -- 実行区分
                      i_VMASIN_NO,          -- 端末番号
                      i_NTRENBAN,           -- 登録連番
                      NwRTN,                -- 軽減判定(0:OK 9:NG)
                      NwHIHO_SU,           -- 軽減判定被保険者数（実態調査[世帯票]でのみ使用）
                      Nw_N25SISAN);         -- ５割軽減処理条件

        IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
          --課税状況の場合
          UPDATE ZLBTKEIGEN_CAL
            SET KEIGEN_4  = KEIGEN_3, KEIGEN_5 = KEIGEN_3, KEIGEN_6  = KEIGEN_3, KEIGEN_7  = KEIGEN_3
              , KEIGEN_8  = KEIGEN_3, KEIGEN_9 = KEIGEN_3, KEIGEN_10 = KEIGEN_3, KEIGEN_11 = KEIGEN_3
              , KEIGEN_12 = KEIGEN_3, KEIGEN_1 = KEIGEN_3, KEIGEN_2  = KEIGEN_3, KEIGEN_3  = KEIGEN_3
              , FUKA_KEIGEN_KBN	=	KEIGEN_3
            WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
              AND SYS_TANMATSU_NO = i_VMASIN_NO;
        END IF;

        IF NwRTN = c_NOK THEN
          -- 緩和措置個人作成
          IF i_NJIKKOU_KBN != c_JITTAI_SETAI THEN
            -- 実態調査(世帯票)以外
            ZLBSKCLKWR (i_NKOKU_SETAI_NO,   -- 国保世帯番号
                              i_NSANTEIDANTAI_CD, -- 算定団体コード
                              i_NNUSI_KOJIN_NO,   -- 世帯主個人番号
                              i_NCHOTEI_NENDO,    -- 調定年度
                              NlNENDO_BUN,        -- 年度分
                              NwJIKKOU_KBN,       -- 実行区分
                              i_VMASIN_NO,        -- 端末番号
                              i_NTRENBAN,         -- 登録連番
                              0,                  -- 処理モード(0:通常)
                              0,                  -- 判定基準日
                              NwRTN);             -- 戻り値(0:OK 1:NG）
          ELSE
            -- 実態調査(世帯票)
            ZLBSKCLKWR (i_NKOKU_SETAI_NO,   -- 国保世帯番号
                              i_NSANTEIDANTAI_CD, -- 算定団体コード
                              i_NNUSI_KOJIN_NO,   -- 世帯主個人番号
                              i_NCHOTEI_NENDO,    -- 調定年度
                              NlNENDO_BUN,        -- 年度分
                              NwJIKKOU_KBN,       -- 実行区分
                              i_VMASIN_NO,        -- 端末番号
                              i_NTRENBAN,         -- 登録連番
                              1,                  -- 処理モード(1:基準日時点[H4/HH/C4])
                              i_NCHOTEI_NENDO * 10000 + 0930, -- 判定基準日
                              NwRTN);             -- 戻り値(0:OK 1:NG）
          END IF;
          IF NwRTN != c_NOK THEN
            NwRTN := c_NERR;
          ELSE
            IF i_NJIKKOU_KBN = c_JITTAI_SETAI THEN
              -- 《計算緩和個人更新》
              BEGIN
                UPDATE ZLBTKANWA_KOJIN_CAL
                   SET OUNOU_4 = OUNOU_9, OUNOU_5 = OUNOU_9, OUNOU_6 = OUNOU_9,
                       OUNOU_7 = OUNOU_9, OUNOU_8 = OUNOU_9,
                       OUNOU_10= OUNOU_9, OUNOU_11= OUNOU_9, OUNOU_12= OUNOU_9,
                       OUNOU_1 = OUNOU_9, OUNOU_2 = OUNOU_9, OUNOU_3 = OUNOU_9,
                       OUEKI_4 = OUEKI_9, OUEKI_5 = OUEKI_9, OUEKI_6 = OUEKI_9,
                       OUEKI_7 = OUEKI_9, OUEKI_8 = OUEKI_9,
                       OUEKI_10= OUEKI_9, OUEKI_11= OUEKI_9, OUEKI_12= OUEKI_9,
                       OUEKI_1 = OUEKI_9, OUEKI_2 = OUEKI_9, OUEKI_3 = OUEKI_9
                 WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
              EXCEPTION
                WHEN OTHERS THEN
                  NwRTN := c_NERR;
                  VlMSG := 'ZLBTKANWA_KOJIN_CAL  更新エラー ' ||SQLCODE||SQLERRM
                           ||' 国保世帯番号='||i_NKOKU_SETAI_NO ;
              END;
            END IF;
          END IF;
        END IF;

        IF NwRTN = c_NOK THEN
          -- 緩和措置世帯作成
          IF i_NJIKKOU_KBN != c_JITTAI_SETAI THEN
            -- 実態調査(世帯票)以外
            IF i_NNOUKI_KBN = c_NNOUKI_KARISAN THEN
              NwJIKKOU_KBN_BK  := NwJIKKOU_KBN;    -- 実行区分を退避
              NwJIKKOU_KBN     := 4;               -- 実行区分に「仮算定」をセット
            END IF;
            ZLBSKCALKWST (i_NKOKU_SETAI_NO,   -- 国保世帯番号
                              i_NSANTEIDANTAI_CD, -- 算定団体コード
                              i_NNUSI_KOJIN_NO,   -- 世帯主個人番号
                              i_NCHOTEI_NENDO,    -- 調定年度
                              NlNENDO_BUN,        -- 年度分
                              NwJIKKOU_KBN,       -- 実行区分
                              i_VMASIN_NO,        -- 端末番号
                              i_NTRENBAN,         -- 登録連番
                              0,                  -- 処理モード(0:通常)
                              0,                  -- 判定基準日
                              NwRTN);             -- 戻り値(0:OK 1:NG）
            IF i_NNOUKI_KBN = c_NNOUKI_KARISAN THEN
              NwJIKKOU_KBN     := NwJIKKOU_KBN_BK; -- 退避した実行区分を戻す
            END IF;
          ELSE
            -- 実態調査(世帯票)
            ZLBSKCALKWST (i_NKOKU_SETAI_NO,   -- 国保世帯番号
                              i_NSANTEIDANTAI_CD, -- 算定団体コード
                              i_NNUSI_KOJIN_NO,   -- 世帯主個人番号
                              i_NCHOTEI_NENDO,    -- 調定年度
                              NlNENDO_BUN,        -- 年度分
                              NwJIKKOU_KBN,       -- 実行区分
                              i_VMASIN_NO,        -- 端末番号
                              i_NTRENBAN,         -- 登録連番
                              1,                  -- 処理モード(1:基準日時点[H4/HH/C4])
                              i_NCHOTEI_NENDO * 10000 + 0930, -- 判定基準日
                              NwRTN);             -- 戻り値(0:OK 1:NG）
          END IF;
          IF NwRTN != c_NOK THEN
            NwRTN := c_NERR;
          ELSE
            IF i_NJIKKOU_KBN = c_JITTAI_SETAI THEN
              -- 《計算緩和世帯更新》
              BEGIN
                UPDATE ZLBTKANWA_SETAI_CAL
                   SET TAISHO_KBN_4 = TAISHO_KBN_9, TAISHO_KBN_5 = TAISHO_KBN_9,
                       TAISHO_KBN_6 = TAISHO_KBN_9, TAISHO_KBN_7 = TAISHO_KBN_9,
                       TAISHO_KBN_8 = TAISHO_KBN_9,
                       TAISHO_KBN_10= TAISHO_KBN_9, TAISHO_KBN_11= TAISHO_KBN_9,
                       TAISHO_KBN_12= TAISHO_KBN_9, TAISHO_KBN_1 = TAISHO_KBN_9,
                       TAISHO_KBN_2 = TAISHO_KBN_9, TAISHO_KBN_3 = TAISHO_KBN_9,
                       OUEKI_4 = OUEKI_9, OUEKI_5 = OUEKI_9, OUEKI_6 = OUEKI_9,
                       OUEKI_7 = OUEKI_9, OUEKI_8 = OUEKI_9,
                       OUEKI_10= OUEKI_9, OUEKI_11= OUEKI_9, OUEKI_12= OUEKI_9,
                       OUEKI_1 = OUEKI_9, OUEKI_2 = OUEKI_9, OUEKI_3 = OUEKI_9
                 WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
              EXCEPTION
                WHEN OTHERS THEN
                  NwRTN := c_NERR;
                  VlMSG := 'ZLBTKANWA_SETAI_CAL  更新エラー ' ||SQLCODE||SQLERRM
                         ||' 国保世帯番号='||i_NKOKU_SETAI_NO ;
              END;
            END IF;
          END IF;
        END IF;

        -- 計算基本・計算介護基本作成
        IF NwRTN = c_NOK THEN
            ZLBSKCALMAIN(i_NCHOTEI_NENDO,    -- 調定年度
                        NlNENDO_BUN,        -- 年度分
                        i_NKOKU_SETAI_NO,   -- 国保世帯番号
                        i_NSANTEIDANTAI_CD, -- 算定団体コード
                        i_NNUSI_KOJIN_NO,   -- 世帯主個人番号
                        NwJIKKOU_KBN,       -- 実行区分
                        NwCAL_KBN,          -- 呼出区分
                        i_VMASIN_NO,        -- 端末番号
                        i_NTRENBAN,         -- 登録連番
                        NwRTN,              -- 計算基本作成(0:OK 1:NG)
                        i_NKIJUNBI);        --更正日（基準日を渡す）
            IF NwRTN != c_NOK THEN
                NwRTN := c_NERR;
            END IF;

                ZLBSKCALMKAI(i_NCHOTEI_NENDO,         -- 調定年度
                               NlNENDO_BUN,             -- 年度分
                               i_NKOKU_SETAI_NO,        -- 国保世帯番号
                               i_NSANTEIDANTAI_CD,      -- 算定団体コード
                               i_NNUSI_KOJIN_NO,        -- 世帯主個人番号
                                NwJIKKOU_KBN,           -- 実行区分
                                NwCAL_KBN,              -- 呼出区分
                               i_VMASIN_NO,             -- 端末番号
                               i_NTRENBAN,              -- 登録連番
                               NwRTN,                   -- 計算介護基本作成(0:OK 1:NG)
                               i_NKIJUNBI);             --更正日（基準日を渡す）
                IF NwRTN != c_NOK THEN
                    NwRTN := c_NERR;
                END IF;
                    ZLBSKCALMSIN(i_NCHOTEI_NENDO,         -- 調定年度
                                   NlNENDO_BUN,             -- 年度分
                                   i_NKOKU_SETAI_NO,        -- 国保世帯番号
                                   i_NSANTEIDANTAI_CD,      -- 算定団体コード
                                   i_NNUSI_KOJIN_NO,        -- 世帯主個人番号
                                    NwJIKKOU_KBN,           -- 実行区分
                                    NwCAL_KBN,              -- 呼出区分
                                   i_VMASIN_NO,             -- 端末番号
                                   i_NTRENBAN,              -- 登録連番
                                   NwRTN,                   -- 計算支援基本作成(0:OK 1:NG)
                                   i_NKIJUNBI);             -- 更正日（基準日を渡す
                    IF NwRTN != c_NOK THEN
                        NwRTN := c_NERR;
                    END IF;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
            ZLBSKCALMKDM(i_NCHOTEI_NENDO,    -- 調定年度
                         NlNENDO_BUN,        -- 年度分
                         i_NKOKU_SETAI_NO,   -- 国保世帯番号
                         i_NSANTEIDANTAI_CD, -- 算定団体コード
                         i_NNUSI_KOJIN_NO,   -- 世帯主個人番号
                         NwJIKKOU_KBN,       -- 実行区分
                         NwCAL_KBN,          -- 呼出区分
                         i_VMASIN_NO,        -- 端末番号
                         i_NTRENBAN,         -- 登録連番
                         NwRTN,              -- 計算基本作成(0:OK 1:NG)
                         i_NKIJUNBI);        -- 更正日（基準日を渡す）
            IF NwRTN != c_NOK THEN
                NwRTN := c_NERR;
            END IF;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
        END IF;

        -- 通知書番号設定
        IF NwRTN = c_NOK THEN
            NwRTN := funcTsuchiGet(i_NKOKU_SETAI_NO,
                                   i_NSANTEIDANTAI_CD,
                                   i_NNUSI_KOJIN_NO);   -- 11 通知書番号取得
        END IF;

        -- 過年度課税計算の場合
        IF NwRTN = c_NOK AND NlGENKA_KBN = c_NKANEN THEN
            ZLBSKCALMAINP(i_NKOKU_SETAI_NO,       -- 国保世帯番号
                            i_NSANTEIDANTAI_CD,     -- 算定団体コード
                            i_NCHOTEI_NENDO,        -- 調定年度
                            NlNENDO_BUN,            -- 年度分
                            NlTSUCHI_NO,            -- 通知書番号
                            i_NSYS_SHOKUINKOJIN_NO, -- 職員個人番号
                            NwJIKKOU_KBN,           -- 実行区分
                            i_VMASIN_NO,            -- 端末番号
                            i_NTRENBAN,             -- 登録連番
                            NwRTN);  -- 過年度分年税額算出(0:OK 9:NG)
        END IF;

        IF NwRTN = c_NOK THEN
          BEGIN
              -- 計算基本の清算フラグを取得
              SELECT COUNT(*) INTO NwCNT FROM ZLBTKIHON_CAL
               WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                 AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
                 AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
                 AND NENDO_BUN       = NlNENDO_BUN
                 AND TSUCHI_NO       = NlTSUCHI_NO
                 AND SEISAN_KBN      = 1
                 AND SYS_TANMATSU_NO = i_VMASIN_NO;
          EXCEPTION
              WHEN OTHERS THEN
                  NwRTN := c_NERR;
                  VlMSG := 'ZLBTKIHON_CAL 清算フラグ 取得エラー ' ||SQLCODE||SQLERRM
                         ||' 国保世帯番号='||i_NKOKU_SETAI_NO ;
          END;
          -- 清算フラグが設定されている場合
          IF NwCNT > 0 THEN
            BEGIN
                -- 該当年度内全て同一世帯主かどうか
                SELECT COUNT(*) INTO NwCNT2
                FROM  ZLBTSEISAN_CAL
                WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
                AND   NUSHI_4 = NUSHI_5
                AND   NUSHI_4 = NUSHI_6
                AND   NUSHI_4 = NUSHI_7
                AND   NUSHI_4 = NUSHI_8
                AND   NUSHI_4 = NUSHI_9
                AND   NUSHI_4 = NUSHI_10
                AND   NUSHI_4 = NUSHI_11
                AND   NUSHI_4 = NUSHI_12
                AND   NUSHI_4 = NUSHI_1
                AND   NUSHI_4 = NUSHI_2
                AND   NUSHI_4 = NUSHI_3
                AND   SYS_TANMATSU_NO = i_VMASIN_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    NwRTN := c_NERR;
                    VlMSG := 'ZLBTSEISAN_CAL 同一世帯主 取得エラー ' ||SQLCODE||SQLERRM
                           ||' 国保世帯番号='||i_NKOKU_SETAI_NO ;
            END;
            IF NwCNT2 > 0 THEN
              -- 該当期間内全て同一世帯主の場合は清算フラグを0にする
              BEGIN
                  -- 計算基本を更新
                  UPDATE ZLBTKIHON_CAL SET SEISAN_KBN = 0
                   WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                     AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
                     AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
                     AND NENDO_BUN       = NlNENDO_BUN
                     AND TSUCHI_NO       = NlTSUCHI_NO
                     AND SYS_TANMATSU_NO = i_VMASIN_NO;
              EXCEPTION
                  WHEN OTHERS THEN
                      NwRTN := c_NERR;
                      VlMSG := 'ZLBTKIHON_CAL 清算フラグ 更新エラー ' ||SQLCODE||SQLERRM
                             ||' 国保世帯番号='||i_NKOKU_SETAI_NO ;
              END;
            END IF;
          END IF;
          --実態調査（世帯票）の場合
          IF i_NJIKKOU_KBN = c_JITTAI_SETAI THEN
            -- 軽減判定被保険者数を賦課期日人員に更新する
            -- 実態調査（世帯票）では、FUKA_KIJITSU_CNTを軽減判定被保険者数として使用する
            BEGIN
                -- 計算基本を更新
                UPDATE ZLBTKIHON_CAL SET FUKA_KIJITSU_CNT = NwHIHO_SU
                 WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
                   AND NENDO_BUN       = NlNENDO_BUN
                   AND TSUCHI_NO       = NlTSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    NwRTN := c_NERR;
                    VlMSG := 'ZLBTKIHON_CAL 軽減判定被保険者数 更新エラー ' ||SQLCODE||SQLERRM
                           ||' 国保世帯番号='||i_NKOKU_SETAI_NO ;
            END;
          END IF;
        END IF;

        RETURN(NwRTN);

    END funcKihon;
-------------------------------------------------------------------------------
--個人の各月毎資格区分を更新（課税状況用課税計算でのみ使用）ADD
-------------------------------------------------------------------------------
    FUNCTION funcKJ_Update_Kojin(i_NKOKU_SETAI_NO IN NUMBER, i_NKOJIN_NO IN NUMBER) RETURN NUMBER IS
        NwRTN  NUMBER := 0;
    BEGIN
        BEGIN
          IF i_NJIKKOU_KBN = c_KAZEIJOKYO THEN
            --課税状況の場合、各月毎資格区分を更新
            UPDATE ZLBTKOJIN_CAL
              SET SHIK_4  = SHIK_3, SHIK_5 = SHIK_3, SHIK_6  = SHIK_3, SHIK_7  = SHIK_3
                , SHIK_8  = SHIK_3, SHIK_9 = SHIK_3, SHIK_10 = SHIK_3, SHIK_11 = SHIK_3
                , SHIK_12 = SHIK_3, SHIK_1 = SHIK_3, SHIK_2  = SHIK_3
                , KAI_SHIK_4  = KAI_SHIK_3, KAI_SHIK_5  = KAI_SHIK_3, KAI_SHIK_6  = KAI_SHIK_3
                , KAI_SHIK_7  = KAI_SHIK_3, KAI_SHIK_8  = KAI_SHIK_3, KAI_SHIK_9  = KAI_SHIK_3
                , KAI_SHIK_10 = KAI_SHIK_3, KAI_SHIK_11 = KAI_SHIK_3, KAI_SHIK_12 = KAI_SHIK_3
                , KAI_SHIK_1  = KAI_SHIK_3, KAI_SHIK_2  = KAI_SHIK_3
                , SHITSU_4    = SHITSU_3,   SHITSU_5    = SHITSU_3,   SHITSU_6    = SHITSU_3
                , SHITSU_7    = SHITSU_3,   SHITSU_8    = SHITSU_3,   SHITSU_9    = SHITSU_3
                , SHITSU_10   = SHITSU_3,   SHITSU_11   = SHITSU_3,   SHITSU_12   = SHITSU_3
                , SHITSU_1    = SHITSU_3,   SHITSU_2    = SHITSU_3
              WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                AND KOJIN_NO        = i_NKOJIN_NO
                AND SYS_TANMATSU_NO = i_VMASIN_NO;
          ELSIF i_NJIKKOU_KBN = c_JITTAI_SETAI THEN
            --実態調査（世帯票）の場合、各月毎資格区分を更新
            UPDATE ZLBTKOJIN_CAL
              SET SHIK_4  = SHIK_9, SHIK_5 = SHIK_9, SHIK_6  = SHIK_9, SHIK_7  = SHIK_9
                , SHIK_8  = SHIK_9, SHIK_10 = SHIK_9, SHIK_11 = SHIK_9, SHIK_12 = SHIK_9
                , SHIK_1  = SHIK_9, SHIK_2 = SHIK_9, SHIK_3  = SHIK_9
                , KAI_SHIK_4  = KAI_SHIK_9, KAI_SHIK_5  = KAI_SHIK_9, KAI_SHIK_6  = KAI_SHIK_9
                , KAI_SHIK_7  = KAI_SHIK_9, KAI_SHIK_8  = KAI_SHIK_9, KAI_SHIK_10 = KAI_SHIK_9
                , KAI_SHIK_11 = KAI_SHIK_9, KAI_SHIK_12 = KAI_SHIK_9, KAI_SHIK_1  = KAI_SHIK_9
                , KAI_SHIK_2  = KAI_SHIK_9, KAI_SHIK_3  = KAI_SHIK_9
                , SHITSU_4    = SHITSU_9,   SHITSU_5    = SHITSU_9,   SHITSU_6    = SHITSU_9
                , SHITSU_7    = SHITSU_9,   SHITSU_8    = SHITSU_9,   SHITSU_10   = SHITSU_9
                , SHITSU_11   = SHITSU_9,   SHITSU_12   = SHITSU_9,   SHITSU_1    = SHITSU_9
                , SHITSU_2    = SHITSU_9,   SHITSU_3    = SHITSU_9
              WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                AND KOJIN_NO        = i_NKOJIN_NO
                AND SYS_TANMATSU_NO = i_VMASIN_NO;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            NwRTN := c_NERR;
            VlMSG := 'funcKJ_Update_Kojin 各月毎資格区分を更新' || '(国保世帯番号=' || i_NKOKU_SETAI_NO || ')' || SQLERRM;
        END;
        RETURN(NwRTN);
    END funcKJ_Update_Kojin;
-------------------------------------------------------------------------------
--世帯で使用する項目を更新（課税状況用課税計算でのみ使用）ADD
-------------------------------------------------------------------------------
    FUNCTION funcKJ_Update_Setai(i_NKOKU_SETAI_NO IN NUMBER) RETURN NUMBER IS
        NwRTN  NUMBER := 0;
    BEGIN
        BEGIN
          IF i_NJIKKOU_KBN = c_KAZEIJOKYO THEN
            --課税状況の場合、計算精算区分ＣＡＬと計算算定団体ＣＡＬを更新
            UPDATE ZLBTSEISAN_CAL
              SET NUSHI_4 = NUSHI_3, NUSHI_5 = NUSHI_3, NUSHI_6 = NUSHI_3, NUSHI_7 = NUSHI_3
                , NUSHI_8 = NUSHI_3, NUSHI_9 = NUSHI_3, NUSHI_10 = NUSHI_3, NUSHI_11 = NUSHI_3
                , NUSHI_12 = NUSHI_3, NUSHI_1 = NUSHI_3, NUSHI_2 = NUSHI_3, NUSHI_3 = NUSHI_3
              WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
                AND SYS_TANMATSU_NO = i_VMASIN_NO;

            UPDATE ZLBTSANTEI_CAL
              SET SANTEI_4 = SANTEI_3, SANTEI_5 = SANTEI_3, SANTEI_6 = SANTEI_3, SANTEI_7 = SANTEI_3
                , SANTEI_8 = SANTEI_3, SANTEI_9 = SANTEI_3, SANTEI_10 = SANTEI_3, SANTEI_11 = SANTEI_3
                , SANTEI_12 = SANTEI_3, SANTEI_1 = SANTEI_3, SANTEI_2 = SANTEI_3, SANTEI_3 = SANTEI_3
              WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
                AND SYS_TANMATSU_NO = i_VMASIN_NO;
          ELSIF i_NJIKKOU_KBN = c_JITTAI_SETAI THEN
            --課税状況の場合、計算精算区分ＣＡＬと計算算定団体ＣＡＬを更新
            UPDATE ZLBTSEISAN_CAL
              SET NUSHI_4 = NUSHI_9, NUSHI_5 = NUSHI_9,  NUSHI_6 = NUSHI_9,  NUSHI_7 = NUSHI_9
                , NUSHI_8 = NUSHI_9, NUSHI_10 = NUSHI_9, NUSHI_11 = NUSHI_9, NUSHI_12 = NUSHI_9
                , NUSHI_1 = NUSHI_9, NUSHI_2 = NUSHI_9,  NUSHI_3 = NUSHI_9
              WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
                AND SYS_TANMATSU_NO = i_VMASIN_NO;

            UPDATE ZLBTSANTEI_CAL
              SET SANTEI_4 = SANTEI_9, SANTEI_5 = SANTEI_9,  SANTEI_6 = SANTEI_9,  SANTEI_7 = SANTEI_9
                , SANTEI_8 = SANTEI_9, SANTEI_10 = SANTEI_9, SANTEI_11 = SANTEI_9, SANTEI_12 = SANTEI_9
                , SANTEI_1 = SANTEI_9, SANTEI_2 = SANTEI_9,  SANTEI_3 = SANTEI_9
              WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
                AND SYS_TANMATSU_NO = i_VMASIN_NO;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            NwRTN := c_NERR;
            VlMSG := 'funcKJ_Update_Setai 各月毎資格区分を更新' || '(国保世帯番号=' || i_NKOKU_SETAI_NO || ')' || SQLERRM;
        END;
        RETURN(NwRTN);
    END funcKJ_Update_Setai;

-------------------------------------------------------------------------------
-- 喪失チェック('擬主'単独月の資格を'喪失'に変換)
-------------------------------------------------------------------------------
    FUNCTION funcSoshitsuChk(i_NKOKU_SETAI_NO IN  NUMBER
                                          ) RETURN NUMBER IS

      -- カーソル定義
    -- 計算個人
      CURSOR CwKOJIN_CAL IS
        SELECT KOJIN_NO,TSUCHI_NO,SANTEIDANTAI_CD FROM ZLBTKOJIN_CAL
          WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
            AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
            AND NENDO_BUN       = NlNENDO_BUN
            AND SYS_TANMATSU_NO = i_VMASIN_NO;

      TYPE TwCNT IS REF CURSOR;
      CGINUSHICNT  TwCNT;
      CINCNT       TwCNT;

      NwRTN               NUMBER:=0;         -- 戻り値
      NwGINUSHICNT        NUMBER:=0;         -- 擬主数
      NwINCNT             NUMBER:=0;         -- 世帯員数
      VwSQL               VARCHAR2(2000); -- 可変SQL文字列
      IwCUR               PLS_INTEGER;    -- カーソル用
      IwPRC               PLS_INTEGER;    -- カーソル用
      NwCNT               NUMBER(2):=0;         -- 特定同一該当チェック 0:非該当
      NwSHIK              NUMBER(2):=0;         -- 更新用資格
      NwSTR_BI            NUMBER(8):=0;         -- 開始日
      NwEND_BI            NUMBER(8):=0;         -- 終了日
      NwSHIKAKU_KBN       NUMBER(2):=0;         -- 資格区分

    BEGIN

      BEGIN
        -- 月ループ(1→12)
        FOR IwX IN 1..12 LOOP

          -- 擬主数取得
          VwSQL := 'SELECT COUNT(*) AS GINUSHI';
          VwSQL := VwSQL || ' FROM ZLBTKOJIN_CAL';
          VwSQL := VwSQL || ' WHERE SHIK_' || IwX || ' = 2';
          VwSQL := VwSQL || ' AND KOKU_SETAI_NO = '     || i_NKOKU_SETAI_NO;
          VwSQL := VwSQL || ' AND CHOTEI_NENDO = '      || i_NCHOTEI_NENDO;
          VwSQL := VwSQL || ' AND NENDO_BUN = '         || NlNENDO_BUN;
          VwSQL := VwSQL || ' AND SYS_TANMATSU_NO = ''' || i_VMASIN_NO || '''';

          -- 擬主数変数初期化
          NwGINUSHICNT := 0;

          -- カーソルOPEN
          OPEN CGINUSHICNT FOR VwSQL;

          -- 疑主数を取得
          LOOP
            FETCH CGINUSHICNT INTO NwGINUSHICNT;
            EXIT;
          END LOOP;

          -- カーソルCLOSE
          IF CGINUSHICNT%ISOPEN THEN
              CLOSE CGINUSHICNT;
          END IF;

          -- 擬主数判定
          IF NwGINUSHICNT > 0 THEN

            -- SQL作成
            VwSQL := 'SELECT COUNT(*)';
            VwSQL := VwSQL || ' FROM ZLBTKOJIN_CAL';
            VwSQL := VwSQL || ' WHERE';
            VwSQL := VwSQL || ' SHIK_' || IwX || ' IN (1,3,11,13) ';
            VwSQL := VwSQL || ' AND KOKU_SETAI_NO = '     || i_NKOKU_SETAI_NO;
            VwSQL := VwSQL || ' AND CHOTEI_NENDO = '      || i_NCHOTEI_NENDO;
            VwSQL := VwSQL || ' AND NENDO_BUN = '         || NlNENDO_BUN;
            VwSQL := VwSQL || ' AND SYS_TANMATSU_NO = ''' || i_VMASIN_NO || '''';

            -- 員数変数初期化
            NwINCNT := 0;

            -- カーソルOPEN
            OPEN CINCNT FOR VwSQL;

            -- 世帯員数を取得
            LOOP
              FETCH CINCNT INTO NwINCNT;
              EXIT;
            END LOOP;

            -- カーソルCLOSE
            IF CINCNT%ISOPEN THEN
                CLOSE CINCNT;
            END IF;

            -- 世帯員数判定
            IF NwINCNT = 0 THEN
              -- 特定同一該当チェック
              CASE IwX                -- 1～12⇒4月～3月
                WHEN 4 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 501;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 501;
                WHEN 5 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 601;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 601;
                WHEN 6 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 701;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 701;
                WHEN 7 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 801;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 801;
                WHEN 8 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 901;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 901;
                WHEN 9 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 1001;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 1001;
                WHEN 10 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 1101;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 1101;
                WHEN 11 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 1201;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 1201;
                WHEN 12 THEN                             -- 次年分は年をたす
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 10101;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 10101;
                WHEN 1 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 10201;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 10201;
                WHEN 2 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 10301;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 10301;
                WHEN 3 THEN
                  NwSTR_BI := i_NNENDO_BUN * 10000 + 10401;
                  NwEND_BI := i_NNENDO_BUN * 10000 + 10401;
              END CASE;

              FOR RwKOJIN_CAL IN CwKOJIN_CAL LOOP
                BEGIN
                  SELECT COUNT(1) INTO NwCNT FROM ZLBTKANWA_TAISHO_TMP
                   WHERE KOJIN_NO      =  RwKOJIN_CAL.KOJIN_NO
                     AND TAISHO_KBN    IN (1, 8)
                     AND TEKIJOGAI_SBI <  NwSTR_BI
                     AND TEKIJOGAI_EBI >= NwEND_BI
                     AND KOKU_SETAI_NO      = i_NKOKU_SETAI_NO
                     AND SAKUJO_KBN    = 0;

                  IF NwCNT > 0 THEN
                    NwSHIK := 5;                            -- 特定同一該当
                  ELSE
                    NwSHIK := 0;                            -- 特定同一非該当
                  END IF;

                  VwSQL := 'UPDATE ZLBTKOJIN_CAL ';
                  VwSQL := VwSQL || ' SET SHIK_'   || IwX || ' = ' || NwSHIK;
                  VwSQL := VwSQL || ' WHERE SHIK_' || IwX || ' = 2 ';
                  VwSQL := VwSQL || ' AND KOKU_SETAI_NO = '     || i_NKOKU_SETAI_NO;
                  VwSQL := VwSQL || ' AND KOJIN_NO = '          || RwKOJIN_CAL.KOJIN_NO;
                  VwSQL := VwSQL || ' AND SANTEIDANTAI_CD = '   || RwKOJIN_CAL.SANTEIDANTAI_CD;
                  VwSQL := VwSQL || ' AND CHOTEI_NENDO = '      || i_NCHOTEI_NENDO;
                  VwSQL := VwSQL || ' AND NENDO_BUN = '         || NlNENDO_BUN;
                  VwSQL := VwSQL || ' AND TSUCHI_NO = '         || RwKOJIN_CAL.TSUCHI_NO;
                  VwSQL := VwSQL || ' AND SYS_TANMATSU_NO = ''' || i_VMASIN_NO || '''';

                  -- ZLBTKOJIN_CAL更新処理
                  IwCUR := DBMS_SQL.OPEN_CURSOR;
                  DBMS_SQL.PARSE(IwCUR, VwSQL, DBMS_SQL. NATIVE);
                  IwPRC := DBMS_SQL.EXECUTE(IwCUR);
                  DBMS_SQL.CLOSE_CURSOR(IwCUR);
                EXCEPTION
                  WHEN OTHERS THEN
                    NwRTN   := c_NERR;
                    VlMSG   := 'funcSoshitsuChk ZLBTKOJIN_CAL更新エラー' || SQLERRM;
                END;
              END LOOP;

            END IF;
          END IF;
        END LOOP;

      EXCEPTION
        WHEN OTHERS THEN
          NwRTN := c_NERR;
          VlMSG := 'funcSoshitsuChk エラー' || '(国保世帯番号=' || i_NKOKU_SETAI_NO || ')' || SQLERRM;
      END;

      RETURN(NwRTN);
    END funcSoshitsuChk;

-------------------------------------------------------------------------------
-- 全喪チェック('同'単独月の資格を'喪失'に変換)
-------------------------------------------------------------------------------
    FUNCTION funcZensoChk(i_NKOKU_SETAI_NO IN NUMBER ) RETURN NUMBER IS

      NwRTN               NUMBER(1)  :=0;         -- 戻り値
      MwlSHIK_CNT         MTNUMARRAY3;            -- 各月資格区分
      VwSQL               VARCHAR2(2000);         -- 可変SQL文字列
      IwCUR               PLS_INTEGER;            -- カーソル用
      IwPRC               PLS_INTEGER;            -- カーソル用

    BEGIN
      -- 変数初期化
      FOR IwX IN 0..12 LOOP
        MwlSHIK_CNT(IwX) := 0;
      END LOOP;

      -- 各月有資格人員取得
      BEGIN
        SELECT NVL(SUM(CASE WHEN SHIK_4  IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_5  IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_6  IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_7  IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_8  IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_9  IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_10 IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_11 IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_12 IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_1  IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_2  IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN SHIK_3  IN (1,3,11,13) THEN 1 ELSE 0 END),9)
              ,NVL(SUM(CASE WHEN F4_SHIK_KBN  IN (1,3,11,13) THEN 1 ELSE 0 END),9)
          INTO MwlSHIK_CNT(4) ,MwlSHIK_CNT(5) ,MwlSHIK_CNT(6) ,MwlSHIK_CNT(7)
              ,MwlSHIK_CNT(8) ,MwlSHIK_CNT(9) ,MwlSHIK_CNT(10),MwlSHIK_CNT(11)
              ,MwlSHIK_CNT(12),MwlSHIK_CNT(1) ,MwlSHIK_CNT(2) ,MwlSHIK_CNT(3)
              ,MwlSHIK_CNT(0)
          FROM ZLBTKOJIN_CAL
         WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
           AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
           AND NENDO_BUN       = NlNENDO_BUN
           AND SYS_TANMATSU_NO =i_VMASIN_NO;
      EXCEPTION
        WHEN OTHERS THEN
          NwRTN := c_NERR;
          VlMSG := 'funcZensouChk 各月有資格人員取得エラー' || '(国保世帯番号=' || i_NKOKU_SETAI_NO || ')' || SQLERRM;
      END;

      IF NwRTN = c_NOK THEN
        -- 月ループ(1→12)
        FOR IwX IN 0..12 LOOP
          -- 各月有資格人員チェック
          IF IwX = 0 THEN
            IF MwlSHIK_CNT(IwX) = 0 THEN
              -- ZLBTKOJIN_CAL更新処理
              BEGIN
                UPDATE ZLBTKOJIN_CAL
                   SET F4_SHIK_KBN = 0
                 WHERE F4_SHIK_KBN = 5
                   AND KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                   AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
                   AND NENDO_BUN       = NlNENDO_BUN
                   AND SYS_TANMATSU_NO = i_VMASIN_NO;
              EXCEPTION
                WHEN OTHERS THEN
                  NwRTN   := c_NERR;
                  VlMSG   := 'funcZensouChk ZLBTKOJIN_CAL更新エラー' || '(国保世帯番号=' || i_NKOKU_SETAI_NO || ')' || SQLERRM;
                  EXIT;
              END;
            END IF;
          ELSE
            IF MwlSHIK_CNT(IwX) = 0 THEN
              -- 該当月資格区分=5(特定同一)設定者の値を0に更新
              VwSQL :=          'UPDATE ZLBTKOJIN_CAL ';
              VwSQL := VwSQL || ' SET SHIK_'   || IwX || ' = 0';
              VwSQL := VwSQL || ' WHERE SHIK_' || IwX || ' = 5 ';
              VwSQL := VwSQL || ' AND KOKU_SETAI_NO = '     || i_NKOKU_SETAI_NO;
              VwSQL := VwSQL || ' AND CHOTEI_NENDO = '      || i_NCHOTEI_NENDO;
              VwSQL := VwSQL || ' AND NENDO_BUN = '         || NlNENDO_BUN;
              VwSQL := VwSQL || ' AND SYS_TANMATSU_NO = ''' || i_VMASIN_NO || '''';

              -- ZLBTKOJIN_CAL更新処理
              BEGIN
                IwCUR := DBMS_SQL.OPEN_CURSOR;
                DBMS_SQL.PARSE(IwCUR, VwSQL, DBMS_SQL. NATIVE);
                IwPRC := DBMS_SQL.EXECUTE(IwCUR);
                DBMS_SQL.CLOSE_CURSOR(IwCUR);
              EXCEPTION
                WHEN OTHERS THEN
                  NwRTN   := c_NERR;
                  VlMSG   := 'funcZensouChk ZLBTKOJIN_CAL更新エラー' || '(国保世帯番号=' || i_NKOKU_SETAI_NO || ')' || SQLERRM;
                  EXIT;
              END;
            END IF;
          END IF;
        END LOOP;
      END IF;

      RETURN(NwRTN);
    END funcZensoChk;
-------------------------------------------------------------------------------
-- 優先区分(5-世帯／未到来期別)の計算機能を追加する。
-------------------------------------------------------------------------------
  PROCEDURE  subInsertKbn (i_NKOKU_SETAI_NO   IN NUMBER,  -- 国保世帯番号
                           i_NSANTEIDANTAI_CD IN NUMBER,  -- 算定団体コード
                           i_NCHOTEI_NENDO    IN NUMBER,  -- 調定年度
                           i_VMASIN_NO        IN NVARCHAR2,  -- 更新端末番号
                           i_NlTSUCHI_NO      IN NUMBER,  -- 通知書番号
                           i_SHINSEI_BI       IN NUMBER)  -- 申請日
  IS
    N_RONRIKIBETSU    NUMBER(2,0);    -- 論理期別
    N_ZEN_ZEIGAKU       NUMBER := 0;  -- 全体税額
    N_TAI_ZEIGAKU       NUMBER := 0;  -- 退職税額
    N_IR_ZEN_ZEIGAKU    NUMBER := 0;  -- 医療全体税額
    N_IR_TAI_ZEIGAKU    NUMBER := 0;  -- 医療退職税額
    N_KAI_ZEN_ZEIGAKU   NUMBER := 0;  -- 介護全体税額
    N_KAI_TAI_ZEIGAKU   NUMBER := 0;  -- 介護退職税額
    N_SIEN_ZEN_ZEIGAKU  NUMBER := 0;  -- 支援全体税額
    N_SIEN_TAI_ZEIGAKU  NUMBER := 0;  -- 援退職税額
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
    N_KDM_ZEN_ZEIGAKU   NUMBER := 0;  -- 子ども全体税額
    B_UPDATE_FLG        BOOLEAN := FALSE;

    CURSOR COR_JLTTAICAL IS
      SELECT NVL(ZEN_ZEIGAKU, 0) ZEN_ZEIGAKU,
             NVL(TAI_ZEIGAKU, 0) TAI_ZEIGAKU,
             NVL(IR_ZEN_ZEIGAKU, 0) IR_ZEN_ZEIGAKU,
             NVL(IR_TAI_ZEIGAKU, 0) IR_TAI_ZEIGAKU,
             NVL(KAI_ZEN_ZEIGAKU, 0) KAI_ZEN_ZEIGAKU,
             NVL(KAI_TAI_ZEIGAKU, 0) KAI_TAI_ZEIGAKU,
             NVL(SIEN_ZEN_ZEIGAKU, 0) SIEN_ZEN_ZEIGAKU,
             NVL(SIEN_TAI_ZEIGAKU, 0) SIEN_TAI_ZEIGAKU
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
             , NVL(KDM_ZEN_ZEIGAKU, 0) KDM_ZEN_ZEIGAKU
        FROM ZLBTKIBETSU_CAL
       WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
         AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
         AND CHOTEINENDO     = i_NCHOTEI_NENDO
         AND NENDOBUN        = NlNENDO_BUN
         AND TSUCHI_NO       = i_NlTSUCHI_NO
         AND SYS_TANMATSU_NO = i_VMASIN_NO
         AND RONRIKIBETSU    >= N_RONRIKIBETSU;

    -- 論理期別
    CURSOR COR_JLTSHUNOJKNK1 IS
      SELECT RONRIKIBETSU
        FROM  ZLBTSHUNOJKNK
       WHERE NOKIGEN         >= i_SHINSEI_BI
         AND KAMOKU_CD         = 15
         AND KAMOKUS_CD        = 1
         AND KIWARIDANTAI_CD   = i_NSANTEIDANTAI_CD
         AND DANTAING_KBN      = 0
         AND CHOTEINENDO       = i_NCHOTEI_NENDO
         AND GENNENKANEN_KBN   = NlGENKA_KBN
         ORDER BY NOKIGEN;

  BEGIN
        --論理期別を取得する
        FOR C_JLTSHUNOJKNK IN COR_JLTSHUNOJKNK1 LOOP
          --減免申請日から直近の納期限（減免申請日≦納期限）であるレコードの論理期別を取得する。
          N_RONRIKIBETSU := C_JLTSHUNOJKNK.RONRIKIBETSU;
          --計算期別作成後のZLBTKIBETSU_CALより、上記1-1.で取得した論理期別以降のある項目を集計する
          FOR C_JLTTAICAL IN COR_JLTTAICAL LOOP
            N_ZEN_ZEIGAKU      := N_ZEN_ZEIGAKU + C_JLTTAICAL.ZEN_ZEIGAKU;           -- 全体税額     集計
            N_TAI_ZEIGAKU      := N_TAI_ZEIGAKU + C_JLTTAICAL.TAI_ZEIGAKU;           -- 退職税額     集計
            N_IR_ZEN_ZEIGAKU   := N_IR_ZEN_ZEIGAKU + C_JLTTAICAL.IR_ZEN_ZEIGAKU;     -- 医療全体税額 集計
            N_IR_TAI_ZEIGAKU   := N_IR_TAI_ZEIGAKU + C_JLTTAICAL.IR_TAI_ZEIGAKU;     -- 医療退職税額 集計
            N_KAI_ZEN_ZEIGAKU  := N_KAI_ZEN_ZEIGAKU + C_JLTTAICAL.KAI_ZEN_ZEIGAKU;   -- 介護全体税額 集計
            N_KAI_TAI_ZEIGAKU  := N_KAI_TAI_ZEIGAKU + C_JLTTAICAL.KAI_TAI_ZEIGAKU;   -- 介護退職税額 集計
            N_SIEN_ZEN_ZEIGAKU := N_SIEN_ZEN_ZEIGAKU + C_JLTTAICAL.SIEN_ZEN_ZEIGAKU; -- 支援全体税額 集計
            N_SIEN_TAI_ZEIGAKU := N_SIEN_TAI_ZEIGAKU + C_JLTTAICAL.SIEN_TAI_ZEIGAKU; -- 援退職税額   集計
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
            N_KDM_ZEN_ZEIGAKU  := N_KDM_ZEN_ZEIGAKU + C_JLTTAICAL.KDM_ZEN_ZEIGAKU;   -- 子ども全体税額   集計
            B_UPDATE_FLG := TRUE;
          END LOOP;
          EXIT;
        END LOOP;
        IF B_UPDATE_FLG THEN
          -- ZLBTKIHON_CAL年税額に減免額分を反映する。
          UPDATE ZLBTKIHON_CAL
             SET GENMEN = N_IR_ZEN_ZEIGAKU,
                   NENZEI = NENZEI - N_IR_ZEN_ZEIGAKU
             WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO    -- 国保世帯番号
               AND SANTEIDANTAI_CD   = i_NSANTEIDANTAI_CD  -- 算定団体コード
               AND CHOTEI_NENDO      = i_NCHOTEI_NENDO     -- 調定年度
               AND NENDO_BUN         = NlNENDO_BUN         -- 年度分
               AND TSUCHI_NO         = i_NlTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO   = i_VMASIN_NO;        -- 更新端末番号
          -- ZLBTTAI_CAL年税額に減免額分を反映する。
          UPDATE ZLBTTAI_CAL
             SET GENMEN = N_IR_TAI_ZEIGAKU,
                   NENZEI = NENZEI - N_IR_TAI_ZEIGAKU
             WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO    -- 国保世帯番号
               AND SANTEIDANTAI_CD   = i_NSANTEIDANTAI_CD  -- 算定団体コード
               AND CHOTEI_NENDO      = i_NCHOTEI_NENDO     -- 調定年度
               AND NENDO_BUN         = NlNENDO_BUN         -- 年度分
               AND TSUCHI_NO         = i_NlTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO   = i_VMASIN_NO;        -- 更新端末番号
            -- ZLBTKAI_KIHON_CAL年税額に減免額分を反映する。
          UPDATE ZLBTKAI_KIHON_CAL
             SET GENMEN = N_KAI_ZEN_ZEIGAKU,
                   NENZEI =  NENZEI - N_KAI_ZEN_ZEIGAKU
             WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO    -- 国保世帯番号
               AND SANTEIDANTAI_CD   = i_NSANTEIDANTAI_CD  -- 算定団体コード
               AND CHOTEI_NENDO      = i_NCHOTEI_NENDO     -- 調定年度
               AND NENDO_BUN         = NlNENDO_BUN         -- 年度分
               AND TSUCHI_NO         = i_NlTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO   = i_VMASIN_NO;        -- 更新端末番号
            -- ZLBTKAI_TAI_CAL年税額に減免額分を反映する。
          UPDATE ZLBTKAI_TAI_CAL
             SET GENMEN =  N_KAI_TAI_ZEIGAKU,
                   NENZEI =  NENZEI - N_KAI_TAI_ZEIGAKU
             WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO    -- 国保世帯番号
               AND SANTEIDANTAI_CD   = i_NSANTEIDANTAI_CD  -- 算定団体コード
               AND CHOTEI_NENDO      = i_NCHOTEI_NENDO     -- 調定年度
               AND NENDO_BUN         = NlNENDO_BUN         -- 年度分
               AND TSUCHI_NO         = i_NlTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO   = i_VMASIN_NO;        -- 更新端末番号
            -- ZLBTSIEN_KIHON_CAL年税額に減免額分を反映する。
          UPDATE ZLBTSIEN_KIHON_CAL
             SET GENMEN =  N_SIEN_ZEN_ZEIGAKU,
                   NENZEI =  NENZEI - N_SIEN_ZEN_ZEIGAKU
             WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO    -- 国保世帯番号
               AND SANTEIDANTAI_CD   = i_NSANTEIDANTAI_CD  -- 算定団体コード
               AND CHOTEI_NENDO      = i_NCHOTEI_NENDO     -- 調定年度
               AND NENDO_BUN         = NlNENDO_BUN         -- 年度分
               AND TSUCHI_NO         = i_NlTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO   = i_VMASIN_NO;        -- 更新端末番号
            -- ZLBTSIEN_TAI_CAL年税額に減免額分を反映する。
          UPDATE  ZLBTSIEN_TAI_CAL
             SET GENMEN =  N_SIEN_TAI_ZEIGAKU,
                  NENZEI =  NENZEI - N_SIEN_TAI_ZEIGAKU
             WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO    -- 国保世帯番号
               AND SANTEIDANTAI_CD   = i_NSANTEIDANTAI_CD  -- 算定団体コード
               AND CHOTEI_NENDO      = i_NCHOTEI_NENDO     -- 調定年度
               AND NENDO_BUN         = NlNENDO_BUN         -- 年度分
               AND TSUCHI_NO         = i_NlTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO   = i_VMASIN_NO;        -- 更新端末番号
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
            -- ZLBTKDM_KIHON_CAL年税額に減免額分を反映する。
            UPDATE ZLBTKDM_KIHON_CAL
               SET GENMEN = N_KDM_ZEN_ZEIGAKU,
                   NENZEI = NENZEI - N_KDM_ZEN_ZEIGAKU
             WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO    -- 国保世帯番号
               AND SANTEIDANTAI_CD   = i_NSANTEIDANTAI_CD  -- 算定団体コード
               AND CHOTEI_NENDO      = i_NCHOTEI_NENDO     -- 調定年度
               AND NENDO_BUN         = NlNENDO_BUN         -- 年度分
               AND TSUCHI_NO         = i_NlTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO   = i_VMASIN_NO;        -- 更新端末番号
--2025/08/11 ZCZL.LIUHUAJUN ADD END
          --取得した論理期別以降のZLBTKIBETSU_CALについて、全体税額などに０をセットする。
          UPDATE  ZLBTKIBETSU_CAL
          SET  ZEN_ZEIGAKU = 0,
               TAI_ZEIGAKU = 0,
               IR_ZEN_ZEIGAKU = 0,
               IR_TAI_ZEIGAKU = 0,
               KAI_ZEN_ZEIGAKU = 0,
               KAI_TAI_ZEIGAKU = 0,
               SIEN_ZEN_ZEIGAKU = 0,
               SIEN_TAI_ZEIGAKU = 0
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
               , KDM_ZEN_ZEIGAKU = 0
          WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
             AND SANTEIDANTAI_CD = i_NSANTEIDANTAI_CD
             AND CHOTEINENDO     = i_NCHOTEI_NENDO
             AND NENDOBUN        = i_NNENDO_BUN
             AND TSUCHI_NO       = i_NlTSUCHI_NO
             AND SYS_TANMATSU_NO = i_VMASIN_NO
             AND RONRIKIBETSU    >= N_RONRIKIBETSU;
       END IF;
  END subInsertKbn;
-------------------------------------------------------------------------------
-- 04 計算個人作成
-------------------------------------------------------------------------------
    FUNCTION funcKojin(i_NKOKU_SETAI_NO IN  NUMBER) RETURN NUMBER IS

        NwRTN                   NUMBER;
        NwJIKKOU_KBN    NUMBER;     --実行区分
        NwNewShitsuKbn          NUMBER;

        -- 個人番号取得カーソル
        CURSOR CwKOJIN IS
            SELECT DISTINCT KOJIN_NO FROM ZLBTSHIKAKU_TMP
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO
            UNION
             SELECT DISTINCT KOJIN_NO FROM ZLBTKANWA_TAISHO_TMP
              WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                AND TAISHO_KBN      IN (c_TAISHO_KBN1, c_TAISHO_KBN8)
                AND SYS_TANMATSU_NO = i_VMASIN_NO;

        -- 個人番号取得カーソル２
        CURSOR CwKOJIN2 IS
            SELECT DISTINCT KOJIN_NO FROM ZLBTSHIKAKU_TMP
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO;

    BEGIN
        NwRTN := c_NOK;
        IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
          --課税状況の場合
          NwJIKKOU_KBN := c_NBATCH;  --バッチから起動
        ELSE
          NwJIKKOU_KBN := i_NJIKKOU_KBN;
        END IF;

        BEGIN
            -- 指定世帯の各員の個人番号を取得し個別に課税計算
            FOR RwKOJIN IN CwKOJIN LOOP

                -- 計算個人の元データ作成
                ZLBSKCALSHK(i_NCHOTEI_NENDO,      -- 調定年度
                              NlNENDO_BUN,          -- 年度分
                              i_NKOKU_SETAI_NO,     -- 国保世帯番号
                              RwKOJIN.KOJIN_NO,     -- 個人番号
                              NlFUKAKIJITU,         -- 賦課期日
                              i_NKIJUNBI,           -- 基準日
                              NwJIKKOU_KBN,         -- 実行区分
                              i_VMASIN_NO,          -- 端末番号
                              i_NTRENBAN,           -- 登録連番
                              NwRTN);           -- 計算個人作成(0:OK 9:NG)
                -- 計算個人の最新失業区分を取得
                BEGIN
                  SELECT NEW_SHITSU_KBN INTO NwNewShitsuKbn
                    FROM ZLBTKOJIN_CAL
                   WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                     AND KOJIN_NO        = RwKOJIN.KOJIN_NO
                     AND SYS_TANMATSU_NO = i_VMASIN_NO;
                EXCEPTION
                  WHEN OTHERS THEN
                    NwNewShitsuKbn  := 0;
                END;

                -- 個人の各所得をセット
                IF NwRTN = c_NOK THEN
                    NwRTN := funcShotokuSet(i_NKOKU_SETAI_NO,
                                            RwKOJIN.KOJIN_NO,
                                            NwNewShitsuKbn);    -- 07 所得セット
                END IF;

                IF NwRTN = c_NOK THEN
                    NwRTN := funcKJ_Update_Kojin(i_NKOKU_SETAI_NO, RwKOJIN.KOJIN_NO);
                END IF;
            END LOOP;
            IF NwRTN = c_NOK THEN
                NwRTN := funcKJ_Update_Setai(i_NKOKU_SETAI_NO);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NwRTN := c_NERR;
                VlMSG := 'funcKojin 計算個人取得' ||
                         '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                         ')' || SQLERRM;
        END;

        -- 喪失チェック(’擬主’単独月の資格を’喪失’に変換)
        IF NwRTN = c_NOK THEN
            NwRTN := funcSoshitsuChk(i_NKOKU_SETAI_NO   -- 国保世帯番号
                                     );
        END IF;

        -- 全喪チェック(’同’単独月の資格を’喪失’に変換)
        IF NwRTN = c_NOK THEN
            NwRTN := funcZensoChk(i_NKOKU_SETAI_NO   -- 国保世帯番号
                                     );
        END IF;
        -- 計算個人の分割
        IF NwRTN = c_NOK THEN
            ZLBSBKJDIV(NlGENKA_KBN,           -- 現年過年区分
                         i_NKOKU_SETAI_NO,      -- 国保世帯番号
                         NlFUKAKIJITU,          -- 賦課期日
                         i_NKIJUNBI,            -- 基準日
                         NwJIKKOU_KBN,          -- 実行区分
                         i_VMASIN_NO,           -- 端末番号
                         i_NTRENBAN,            -- 登録連番
                         NwRTN);            -- 計算個人分割(0:OK 1:NG)
        END IF;

        -- 計算個人更新(所得割額,固定資産税)
        IF NwRTN = c_NOK THEN
            NwRTN := funcKoteiSet(i_NKOKU_SETAI_NO);    -- 10 固定資産税セット
        END IF;

        -- 指定世帯の各員の個人番号を取得し個別に事由セット
       FOR RwKOJIN IN CwKOJIN2 LOOP
          -- 事由をセット
          IF NwRTN = c_NOK THEN
              NwRTN := funcJiyuSet(i_NKOKU_SETAI_NO, RwKOJIN.KOJIN_NO);     -- 08 事由セット
          END IF;
          -- 本算定時の事由の更新および老年者区分の更新を行う
          IF NwRTN = c_NOK THEN
              NwRTN := funcEtcSet(i_NKOKU_SETAI_NO,  RwKOJIN.KOJIN_NO);      -- 09 本算定判定
          END IF;
        END LOOP;

        RETURN(NwRTN);

    END funcKojin;
-------------------------------------------------------------------------------
-- 03 １世帯分のデータ作成
-------------------------------------------------------------------------------
    FUNCTION funcSetaiSet(i_RTAISHO IN ZLBTKEISAN_TAISHO%ROWTYPE) RETURN NUMBER IS

        NwRTN               NUMBER;
        NwNUSI_KOJIN_NO     NUMBER;
        IwSHOTOKU_SHOKAI_KBN PLS_INTEGER := 0;
        IwSANTEIDANTAI_CD    PLS_INTEGER := 0;
        NwJIKKOU_KBN        NUMBER;     --実行区分

        -- 計算個人カーソル
        CURSOR CwSETAI IS
            SELECT DISTINCT KOKU_SETAI_NO, SANTEIDANTAI_CD, TSUCHI_NO
              FROM ZLBTKOJIN_CAL
             WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

        NYUSEN_KBN   NUMBER;   --優先区分
        NSHINSEI_BI  NUMBER;   --申請日
        -- 計算個人カーソル
        CURSOR CwKOJIN3(i_NKOKU_SETAI_NO IN NUMBER) IS
            SELECT * FROM ZLBTKOJIN_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO
             ORDER BY SANTEIDANTAI_CD, KOJIN_NO;

    BEGIN
        NwRTN := c_NOK;
        IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
          --課税状況の場合
          NwJIKKOU_KBN := c_NBATCH;  --バッチから起動
        ELSE
          NwJIKKOU_KBN := i_NJIKKOU_KBN;
        END IF;

        -- 軽減判定日抽出
        ZLBSBKGBSEI(NlNENDO_BUN,               -- 年度分
                        i_RTAISHO.KOKU_SETAI_NO,    -- 国保世帯番号
                        NwJIKKOU_KBN,               -- 実行区分
                        i_VMASIN_NO,                -- 端末番号
                        i_NTRENBAN,                 -- 登録連番
                        NwRTN);             -- 軽減判定日抽出(0:OK 9:NG)

        IF NwRTN = c_NOK THEN
            -- 世帯主清算区分抽出
            ZLBSKNSSKBNSEL(NlNENDO_BUN,             -- 年度分
                              i_RTAISHO.KOKU_SETAI_NO,  -- 国保世帯番号
                              NwJIKKOU_KBN,             -- 実行区分
                              i_VMASIN_NO,              -- 端末番号
                              i_NTRENBAN,               -- 登録連番
                              NwRTN);           -- 世帯主清算区分抽出(0:OK 9:NG)
        END IF;

        IF NwRTN = c_NOK THEN
            -- 算定団体抽出
            ZLBSKSTSEL(NlNENDO_BUN,             -- 年度分
                          i_RTAISHO.KOKU_SETAI_NO,  -- 国保世帯番号
                          NwJIKKOU_KBN,             -- 実行区分
                          i_VMASIN_NO,              -- 端末番号
                          i_NTRENBAN,               -- 登録連番
                          NwRTN);               -- 算定団体抽出(0:OK 9:NG)
        END IF;

        IF NwRTN = c_NOK THEN
            NwRTN := funcKojin(i_RTAISHO.KOKU_SETAI_NO);    -- 04 計算個人・計算取得作成
        END IF;

        -- 世帯の各員の情報を取り纏める
        IF NwRTN = c_NOK THEN
            BEGIN
                FOR RwSETAI IN CwSETAI LOOP

                    NwNUSI_KOJIN_NO := RwSETAI.TSUCHI_NO;

                    -- 計算所得作成
                    NwRTN := funcCpyShotoku(RwSETAI.SANTEIDANTAI_CD,
                                            RwSETAI.KOKU_SETAI_NO,
                                            NwNUSI_KOJIN_NO);       -- 17 計算所得を分割単位にコピー

                    IF IwSANTEIDANTAI_CD != RwSETAI.SANTEIDANTAI_CD THEN
                      IwSANTEIDANTAI_CD := RwSETAI.SANTEIDANTAI_CD;
                      NwRTN := funcJokenSel2(IwSANTEIDANTAI_CD);  --所得照会中所得取扱は、ISHOKAICHUへセット
                    END IF;
                    -- 所得照会中所得取扱で計算所得を更新
                    NwRTN := funcUpdateShotoku(RwSETAI.SANTEIDANTAI_CD, RwSETAI.KOKU_SETAI_NO, NwNUSI_KOJIN_NO, ISHOKAICHU);

                    -- 計算基本作成
                    NwRTN := funcKihon(RwSETAI.KOKU_SETAI_NO,
                                       RwSETAI.SANTEIDANTAI_CD,
                                       NwNUSI_KOJIN_NO);            -- 05 計算基本・計算介護基本作成

                    EXIT WHEN NwRTN != c_NOK;

                    IF NOT i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
                      IF i_NNOUKI_KBN <> c_NNOUKI_HONSAN THEN
                        IF NlGAPEINENDO >= i_NNENDO_BUN THEN

                        IF ISHICHOSON_CD = c_UWAJIMA THEN  -- 宇和島市
                          --判定しない。del
                          NULL;
                        ELSE
                          PROC_UpCheck_KIHON(RwSETAI.KOKU_SETAI_NO, RwSETAI.SANTEIDANTAI_CD,
                                           i_NCHOTEI_NENDO, NlNENDO_BUN,NlTSUCHI_NO, i_VMASIN_NO);
                          PROC_UpCheck_KAI(RwSETAI.KOKU_SETAI_NO, RwSETAI.SANTEIDANTAI_CD,
                                           i_NCHOTEI_NENDO, NlNENDO_BUN,NlTSUCHI_NO, i_VMASIN_NO);
                          PROC_UpCheck_TAI(RwSETAI.KOKU_SETAI_NO, RwSETAI.SANTEIDANTAI_CD,
                                           i_NCHOTEI_NENDO, NlNENDO_BUN,NlTSUCHI_NO, i_VMASIN_NO);
                          PROC_UpCheck_KAITAI(RwSETAI.KOKU_SETAI_NO, RwSETAI.SANTEIDANTAI_CD,
                                           i_NCHOTEI_NENDO, NlNENDO_BUN,NlTSUCHI_NO, i_VMASIN_NO);
                          PROC_UpCheck_SIEN(RwSETAI.KOKU_SETAI_NO, RwSETAI.SANTEIDANTAI_CD,
                                           i_NCHOTEI_NENDO, NlNENDO_BUN,NlTSUCHI_NO, i_VMASIN_NO);
                          PROC_UpCheck_SIENTAI(RwSETAI.KOKU_SETAI_NO, RwSETAI.SANTEIDANTAI_CD,
                                           i_NCHOTEI_NENDO, NlNENDO_BUN,NlTSUCHI_NO, i_VMASIN_NO);
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
                          PROC_UpCheck_KDM(RwSETAI.KOKU_SETAI_NO, RwSETAI.SANTEIDANTAI_CD,
                                           i_NCHOTEI_NENDO, NlNENDO_BUN,NlTSUCHI_NO, i_VMASIN_NO);
--2025/08/11 ZCZL.LIUHUAJUN ADD END

                        END IF;

                        END IF;
                      END IF;
                    END IF;

          -- 軽減該当判定
                  IF NwRTN = c_NOK THEN
                    IF NOT i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
                    PROC_Keigen_Gaitou(RwSETAI.KOKU_SETAI_NO, RwSETAI.SANTEIDANTAI_CD,
                                    i_NCHOTEI_NENDO, NlNENDO_BUN,NlTSUCHI_NO, i_VMASIN_NO);
            END IF;
          END IF;
                END LOOP;

                -- 計算期別作成
                IF NwRTN = c_NOK THEN
                  IF NOT i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
                    NwRTN := funcKibetsu;      -- 06 計算期別作成
                    BEGIN
                    SELECT
                      YUSEN_KBN,
                      SHINSEI_BI
                    INTO
                      NYUSEN_KBN,
                      NSHINSEI_BI
                    FROM
                      ZLBTGENMEN_KOJIN
                    WHERE
                      KOKU_SETAI_NO = i_RTAISHO.KOKU_SETAI_NO
                    AND NENDO_BUN = NlNENDO_BUN
--2024/09/23 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00020
                    --AND TEKIYO_KBN = 1
                    AND TEKIYO_KBN IN (1, 3)
                    AND ROWNUM = 1;
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                        NULL;
                    END;

                    IF NYUSEN_KBN = c_JITTAI_CD THEN
                      FOR CwKOJIN IN CwKOJIN3(i_RTAISHO.KOKU_SETAI_NO) LOOP
                        IF NwRTN = c_NOK THEN
                          subInsertKbn(i_RTAISHO.KOKU_SETAI_NO
                                      ,CwKOJIN.SANTEIDANTAI_CD
                                      ,i_NCHOTEI_NENDO
                                      ,CwKOJIN.SYS_TANMATSU_NO
                                      ,CwKOJIN.TSUCHI_NO
                                      ,NSHINSEI_BI);
                        END IF;
                        EXIT;
                      END LOOP;
                    END IF;
                  END IF;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    NwRTN := c_NERR;
                    VlMSG := 'funcSetaiSet 計算個人取得' ||
                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                             ')' || SQLERRM;
            END;

        END IF;

        RETURN(NwRTN);

    END funcSetaiSet;
-------------------------------------------------------------------------------
-- 02 各計算TBLの内容クリア(DELETE文 端末番号指定)
-------------------------------------------------------------------------------
    PROCEDURE subCalClear IS
    BEGIN

        DELETE FROM ZLBTKIHON_CAL     WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算基本
        DELETE FROM ZLBTTAI_CAL       WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算退職
        DELETE FROM ZLBTKAI_KIHON_CAL WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算介護基本
        DELETE FROM ZLBTKAI_TAI_CAL   WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算介護退職
        DELETE FROM ZLBTKOJIN_CAL     WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算個人
        DELETE FROM ZLBTSHOTOKU_CAL   WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算所得
        DELETE FROM ZLBTKIBETSU_CAL   WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算期別
        DELETE FROM ZLBTSIEN_KIHON_CAL WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算支援基本
        DELETE FROM ZLBTSIEN_TAI_CAL   WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算支援退職
        DELETE FROM ZLBTEXT_CAL       WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算拡張
        DELETE FROM ZLBTTOKU_IDO_CAL   WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算異動
        DELETE FROM ZLBTTOKU_KIHON_CAL WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算特徴対象者
        DELETE FROM ZLBTKANWA_SETAI_CAL WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算緩和世帯
        DELETE FROM ZLBTKANWA_KOJIN_CAL WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算緩和個人
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
        DELETE FROM ZLBTKDM_KIHON_CAL WHERE SYS_TANMATSU_NO = i_VMASIN_NO;  -- 計算子ども基本
        BEGIN
          vSQL := 'DELETE FROM ZLBTGENMEN_KOJIN_CAL WHERE SYS_TANMATSU_NO = ''' || i_VMASIN_NO || '''';  -- 計算減免個人
          EXECUTE IMMEDIATE vSQL;
        EXCEPTION
          WHEN OTHERS THEN
            -- テーブルがないことも考えられるので、エラーにはしない。
            NULL;
        END;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subCalClear 計算削除' ||
                     '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                     ')' || SQLERRM;

    END subCalClear;
-------------------------------------------------------------------------------
-- 01 中間・計算TBLの内容クリア
--      ﾊﾞｯﾁの場合のみ使用
-------------------------------------------------------------------------------
    PROCEDURE subTruncateTbl IS

        NwIX            NUMBER;
        MwTBLNAME       MTVARARRAY;     -- TBL名

    BEGIN
      IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
        -- 課税状況用TBL名セット
        MwTBLNAME(1)  := 'ZLBTKIHON_KJ ';
        MwTBLNAME(2)  := 'ZLBTTAI_KJ';
        MwTBLNAME(3)  := 'ZLBTKAI_KIHON_KJ';
        MwTBLNAME(4)  := 'ZLBTKAI_TAI_KJ';
        MwTBLNAME(5)  := 'ZLBTKOJIN_KJ';
        MwTBLNAME(6)  := 'ZLBTEXT_KJ';
        MwTBLNAME(7)  := 'ZLBTSIEN_KIHON_KJ';
        MwTBLNAME(8)  := 'ZLBTSIEN_TAI_KJ';
        MwTBLNAME(9)  := 'ZLBTKANWA_SETAI_KJ';
        MwTBLNAME(10) := 'ZLBTKANWA_KOJIN_KJ';
        MwTBLNAME(11) := 'ZLBTSHOTOKU_KJ';
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
        MwTBLNAME(12) := 'ZLBTKDM_KIHON_KJ';
      ELSE

        -- 中間TBL名セット
        MwTBLNAME(1)  := 'ZLBTKIHON_MID';
        MwTBLNAME(2)  := 'ZLBTTAI_MID';
        MwTBLNAME(3)  := 'ZLBTKAI_KIHON_MID';
        MwTBLNAME(4)  := 'ZLBTKAI_TAI_MID';
        MwTBLNAME(5)  := 'ZLBTKOJIN_MID';
        MwTBLNAME(6)  := 'ZLBTSHOTOKU_MID';
        MwTBLNAME(7)  := 'ZLBTKIBETSU_MID';
        MwTBLNAME(8)  := 'ZLBTEXT_MID';
        MwTBLNAME(9)  := 'ZLBTSIEN_KIHON_MID';
        MwTBLNAME(10)  := 'ZLBTSIEN_TAI_MID';
        MwTBLNAME(11) := 'ZLBTTOKU_IDO_MID';
        MwTBLNAME(12) := 'ZLBTTOKU_KIHON_MID';
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
        MwTBLNAME(13) := 'ZLBTKDM_KIHON_MID';
      END IF;
        -- 計算TBL名セット

--2025/08/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応
--        MwTBLNAME(13)  := 'ZLBTKIHON_CAL';
--        MwTBLNAME(14) := 'ZLBTTAI_CAL';
--        MwTBLNAME(15) := 'ZLBTKAI_KIHON_CAL';
--        MwTBLNAME(16) := 'ZLBTKAI_TAI_CAL';
--        MwTBLNAME(17) := 'ZLBTKOJIN_CAL';
--        MwTBLNAME(18) := 'ZLBTSHOTOKU_CAL';
--        MwTBLNAME(19) := 'ZLBTKIBETSU_CAL';
--        MwTBLNAME(20) := 'ZLBTSANTEI_CAL';
--        MwTBLNAME(21) := 'ZLBTSEISAN_CAL';
--        MwTBLNAME(22) := 'ZLBTKEIGEN_CAL';
--        MwTBLNAME(23) := 'ZLBTKEIGENHANTEI_CAL';
--        MwTBLNAME(24)  := 'ZLBTEXT_CAL';
--        MwTBLNAME(25) := 'ZLBTSIEN_KIHON_CAL';
--        MwTBLNAME(26) := 'ZLBTSIEN_TAI_CAL';
--        MwTBLNAME(27) := 'ZLBTTOKU_IDO_CAL';
--        MwTBLNAME(28) := 'ZLBTTOKU_KIHON_CAL';
--        MwTBLNAME(29) := 'ZLBTKANWA_SETAI_CAL';
--        MwTBLNAME(30) := 'ZLBTKANWA_KOJIN_CAL';
--        FOR NwIX IN 1..30 LOOP
        MwTBLNAME(14) := 'ZLBTKIHON_CAL';
        MwTBLNAME(15) := 'ZLBTTAI_CAL';
        MwTBLNAME(16) := 'ZLBTKAI_KIHON_CAL';
        MwTBLNAME(17) := 'ZLBTKAI_TAI_CAL';
        MwTBLNAME(18) := 'ZLBTKOJIN_CAL';
        MwTBLNAME(19) := 'ZLBTSHOTOKU_CAL';
        MwTBLNAME(20) := 'ZLBTKIBETSU_CAL';
        MwTBLNAME(21) := 'ZLBTSANTEI_CAL';
        MwTBLNAME(22) := 'ZLBTSEISAN_CAL';
        MwTBLNAME(23) := 'ZLBTKEIGEN_CAL';
        MwTBLNAME(24) := 'ZLBTKEIGENHANTEI_CAL';
        MwTBLNAME(25) := 'ZLBTEXT_CAL';
        MwTBLNAME(26) := 'ZLBTSIEN_KIHON_CAL';
        MwTBLNAME(27) := 'ZLBTSIEN_TAI_CAL';
        MwTBLNAME(28) := 'ZLBTTOKU_IDO_CAL';
        MwTBLNAME(29) := 'ZLBTTOKU_KIHON_CAL';
        MwTBLNAME(30) := 'ZLBTKANWA_SETAI_CAL';
        MwTBLNAME(31) := 'ZLBTKANWA_KOJIN_CAL';
        MwTBLNAME(32) := 'ZLBTKDM_KIHON_CAL';
        FOR NwIX IN 1..32 LOOP
--2025/08/11 ZCZL.LIUHUAJUN UPDATE END
          IF MwTBLNAME.EXISTS(NwIX) THEN
            IF KKAPK3000.FTRUNCATE(MwTBLNAME(NwIX), VlMSG) != 0 THEN
                NlRTN := c_NERR;
                VlMSG := 'KKAPK3000.FTRUNCATE TBL削除(' || MwTBLNAME(NwIX) ||
                         ')' || VlMSG;
                EXIT;
            END IF;
          END IF;
        END LOOP;
        BEGIN
          vSQL := 'TRUNCATE TABLE ZLBTGENMEN_KOJIN_MID';
          EXECUTE IMMEDIATE vSQL;
        EXCEPTION
          WHEN OTHERS THEN
            -- テーブルがないことも考えられるので、エラーにはしない。
            NULL;
        END;
        BEGIN
          vSQL := 'TRUNCATE TABLE ZLBTGENMEN_KOJIN_CAL';
          EXECUTE IMMEDIATE vSQL;
        EXCEPTION
          WHEN OTHERS THEN
            -- テーブルがないことも考えられるので、エラーにはしない。
            NULL;
        END;
        vSQL := 'TRUNCATE TABLE ZLBTCALLOG';
        EXECUTE IMMEDIATE vSQL;

    END subTruncateTbl;
-------------------------------------------------------------------------------
-- 資格TMP存在チェック
-------------------------------------------------------------------------------
    FUNCTION FUNCSHIKAKU_CHECK(i_SETAI_NO IN NUMBER) RETURN BOOLEAN IS
      ICNT          PLS_INTEGER := 0;
      IFUKA_1NENGO  PLS_INTEGER := NlFUKAKIJITU + 10000;  --賦課期日の１年後
      CURSOR CTMP IS
        SELECT COUNT(*) CNT
          FROM ZLBTSHIKAKU_TMP  A,
               (SELECT MAX(TAI_R_NO) AS TAI_R_NO,
                       KOKU_SETAI_NO,
                       KOJIN_NO,
                       R_NO
                  FROM ZLBTSHIKAKU_TMP
                 WHERE KOKU_SETAI_NO   = i_SETAI_NO
                   AND SAKUJO_KBN      = 0
                   AND SYS_TANMATSU_NO = i_VMASIN_NO
                 GROUP BY KOKU_SETAI_NO,KOJIN_NO,R_NO
               ) B
         WHERE A.KOKU_SETAI_NO  = B.KOKU_SETAI_NO
           AND A.KOJIN_NO       = B.KOJIN_NO
           AND A.R_NO           = B.R_NO
           AND A.TAI_R_NO       = B.TAI_R_NO
           --賦課期日以前から資格ありの場合は、資格喪失なしまたは賦課期日以降の喪失
           AND ((A.Z_SHUTOKU_BI < NlFUKAKIJITU AND (A.Z_SOSHITSU_BI = 0 OR A.Z_SOSHITSU_BI >= NlFUKAKIJITU))
           --賦課期日以降に資格取得の場合は、賦課期日の１年後以前の取得である かつ資格喪失なしまたは賦課期日以降の喪失
            OR  (A.Z_SHUTOKU_BI >= NlFUKAKIJITU AND A.Z_SHUTOKU_BI < IFUKA_1NENGO))  --取得日が賦課の年度内であれば喪失日は見ない
           -- 同日の取得喪失を除く
           AND A.SHUTOKU_BI != A.SOSHITSU_BI
           AND A.SYS_TANMATSU_NO = i_VMASIN_NO;
    BEGIN
        FOR CREC IN CTMP LOOP
            ICNT := CREC.CNT;
            EXIT;
        END LOOP;
        RETURN (ICNT > 0);
    END FUNCSHIKAKU_CHECK;
-------------------------------------------------------------------------------
-- 00-3 過年度分メイン(オンライン)
-------------------------------------------------------------------------------
    PROCEDURE subKanenSokuji IS

        RwTAISHO            ZLBTKEISAN_TAISHO%ROWTYPE;

    BEGIN
        NlMAX_TSUCHI_NO := 0;               -- 最大通知書番号
        NlKOKU_SETAI_NO := 0;               -- 計算対象取得用ワーク
        NlNENDO_BUN     := i_NNENDO_BUN;    -- パラメータの年度分を保持

        -- 賦課期日を取得
        subJokenSel;                -- 15-2 システム条件(賦課期日)取得

        IF NlRTN = c_NOK THEN

            BEGIN
                -- 計算対象取得
                SELECT * INTO RwTAISHO FROM ZLBTKEISAN_TAISHO
                     WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

                NlKOKU_SETAI_NO_W := RwTAISHO.KOKU_SETAI_NO;

                -- １世帯分のデータを作成する
                NlRTN := funcSetaiSet(RwTAISHO);  -- 03 １世帯分のデータ作成

                -- 不足データ(賦課にあって計算に存在しないデータ)を作成
                IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
                  NULL;  --課税状況の場合は、計算TBL不足分作成は行わない
                ELSE
                  IF NlRTN = c_NOK THEN
                      NlRTN := funcMakeCal(RwTAISHO.KOKU_SETAI_NO);   -- 16 計算TBL不足分作成
                  END IF;
                END IF;

                -- 不用な計算所得(通知書番号0)を削除
                IF NlRTN = c_NOK THEN
                    subDelShotoku;      -- 18 計算所得削除
                END IF;

                -- 作成したレコードの日付/時刻をあわせる
                IF NlRTN = c_NOK THEN
                    subDateUpdate;      -- 20 日付/時刻の更新
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := '計算対象取得 ' || SQLERRM;
            END;

        END IF;

    END subKanenSokuji;
-------------------------------------------------------------------------------
-- ログ処理
-------------------------------------------------------------------------------
  PROCEDURE PROC_LOG_SHORI(I_KOKU_SETAI_NO IN ZLBTKEISAN_TAISHO.KOKU_SETAI_NO%TYPE,I_NENDO IN ZLBTKEISAN_TAISHO.NENDO%TYPE,
                           I_NENDO_BUN IN ZLBTKEISAN_TAISHO.NENDO_BUN%TYPE,VIERRMSN IN NVARCHAR2)
   IS
   VERRMSN   NVARCHAR2(1000);
   BEGIN
     IF VIERRMSN IS NULL THEN
       SELECT TRIM(LOGMSG) INTO VERRMSN
       FROM   KKBTJLOG
       WHERE  JOBNUM = i_NTRENBAN
         AND  STEPNUM = 99;
     ELSE
       VERRMSN := SUBSTR(VIERRMSN,1,256);
     END IF;
     INSERT INTO ZLBTCALLOG VALUES (I_KOKU_SETAI_NO,I_NENDO,I_NENDO_BUN,i_NTRENBAN,VERRMSN,
                                                 TO_CHAR(SYSDATE,'YYYYMMDD'),TO_CHAR(SYSDATE,'YYYYMMDD'),TO_CHAR(SYSDATE,'HH24MISS'),
                                                 i_NSYS_SHOKUINKOJIN_NO,i_VMASIN_NO);
     DELETE FROM KKBTJLOG WHERE JOBNUM = i_NTRENBAN AND STEPNUM = 99;
     subCalClear;
   EXCEPTION
      WHEN OTHERS THEN
       NULL;
  END PROC_LOG_SHORI;
-------------------------------------------------------------------------------
-- 賦課決定期間の制限対象候補世帯判定処理
-------------------------------------------------------------------------------
  FUNCTION FUNC_SEIGEN_KOHO_HANTEI(i_NTRENBAN             IN NUMBER,
                                   i_NCHOTEI_NENDO        IN NUMBER,
                                   i_NSYS_SHOKUINKOJIN_NO IN CHAR,
                                   i_VMASIN_NO            IN NVARCHAR2) RETURN PLS_INTEGER
  IS
    VSHORI_ID            NVARCHAR2(40);  --処理ID
    NNENDO_HANI          NUMBER;         --年度範囲
    IRTN                 PLS_INTEGER;    --戻り値
  BEGIN
    --引数の登録連番より一括処理情報管理テーブルから処理IDを取得する
     SELECT SHORIID INTO VSHORI_ID
     FROM KKBTJCTL
     WHERE JOBNUM = i_NTRENBAN;

    --取得した処理ID（VSHORI_ID）が’ZLBPB13010’の場合、以下の処理を実行する
-- 2025/12/10 JIP.SUZUKI UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00106 処理ID誤り修正
--    IF VSHORI_ID = 'ZLBPB13010' THEN
    IF VSHORI_ID = 'ZLBB1301' THEN
      --共通関数　市区町村条件取得より市区町村条件一覧の設定値を取得する
      NNENDO_HANI := ZLBPK00010.FCFFJKN2(4302);
      IF NNENDO_HANI > 0 THEN
        --賦課決定期間の制限対象候補世帯判定処理を実行する
        ZLBSCSGKHHT(i_NTRENBAN,
                               i_NCHOTEI_NENDO,
                               NNENDO_HANI,
                               i_NSYS_SHOKUINKOJIN_NO,
                               i_VMASIN_NO,
                               IRTN);
        IF IRTN <> 0 THEN
          RETURN 1;
        END IF;
      END IF;
    END IF;

    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;
  END FUNC_SEIGEN_KOHO_HANTEI;
-------------------------------------------------------------------------------
-- 00-2 過年度分メイン(バッチ)
-------------------------------------------------------------------------------
    PROCEDURE subKanenMain IS

        NwIX            NUMBER;

        -- 計算対象カーソル
        CURSOR CwTAISHO IS
            SELECT *
              FROM (SELECT * FROM ZLBTKEISAN_TAISHO
                      WHERE NENDO_BUN       = NlNENDO_BUN
                        AND KOKU_SETAI_NO   >= NlKOKU_SETAI_NO
                        AND SYS_TANMATSU_NO =  i_VMASIN_NO
                      ORDER BY KOKU_SETAI_NO)
             WHERE ROWNUM <= c_NMAX_NUM
             ORDER BY KOKU_SETAI_NO;
      NKOKU_SETAI_NO    ZLBTKEISAN_TAISHO.KOKU_SETAI_NO%TYPE;
      NNENDO            ZLBTKEISAN_TAISHO.NENDO%TYPE;
      NNENDO_BUN        ZLBTKEISAN_TAISHO.NENDO_BUN%TYPE;
    BEGIN
        NlMAX_TSUCHI_NO := 0;               -- 最大通知書番号

        -- 計算対象年度を算出
        subGetNendo;        -- 15-1 システム条件の読込み(過年度課税計算対象年度算出)

        IF NlRTN = c_NOK THEN
            FOR NwIX IN NlTAISHO_NENDO..i_NCHOTEI_NENDO - 1 LOOP

                NlNENDO_BUN := NwIX;

                -- 賦課期日を取得
                subJokenSel;                -- 15-2 システム条件(賦課期日)取得
                EXIT WHEN NlRTN != c_NOK;

                -- 計算対象件数取得
                BEGIN
                    SELECT COUNT(*) INTO IlMAX FROM ZLBTKEISAN_TAISHO
                     WHERE NENDO_BUN       = NlNENDO_BUN
                       AND SYS_TANMATSU_NO =  i_VMASIN_NO;
                EXCEPTION
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := '計算対象件数取得 ' || SQLERRM;
                        EXIT;
                END;

                NlKOKU_SETAI_NO := 0;               -- 計算対象取得用ワーク

                IF IlMAX > 0 THEN
                    FOR IlIDX IN 1..TRUNC(IlMAX / c_NMAX_NUM) + 1 LOOP

                        BEGIN
                            -- 計算対象世帯を全件読込む(MAX1000件)
                            FOR RwTAISHO IN CwTAISHO LOOP

                                NlKOKU_SETAI_NO_W := RwTAISHO.KOKU_SETAI_NO;
                                NKOKU_SETAI_NO    := RwTAISHO.KOKU_SETAI_NO;
                                NNENDO            := RwTAISHO.NENDO;
                                NNENDO_BUN        := RwTAISHO.NENDO_BUN;
                                --資格TMPの存在チェック
                                IF FUNCSHIKAKU_CHECK(NlKOKU_SETAI_NO_W) THEN
                                  -- １世帯分のデータを作成する
                                  NlRTN := funcSetaiSet(RwTAISHO);  -- 03 １世帯分のデータ作成
                                END IF;

                                -- 不足データ(賦課にあって計算に存在しないデータ)を作成
                                IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
                                  NULL;  --課税状況の場合は、計算TBL不足分作成は行わない
                                ELSE
                                  IF NlRTN = c_NOK THEN
                                      NlRTN := funcMakeCal(RwTAISHO.KOKU_SETAI_NO);   -- 16 計算TBL不足分作成
                                  END IF;
                                END IF;

                                -- 不用な計算所得(通知書番号0)を削除
                                IF NlRTN = c_NOK THEN
                                    subDelShotoku;      -- 18 計算所得削除
                                END IF;

                                -- 作成したレコードの日付/時刻をあわせる
                                IF NlRTN = c_NOK THEN
                                    subDateUpdate;      -- 20 日付/時刻の更新
                                END IF;

                                -- 中間TBLに出力する
                                IF NlRTN = c_NOK THEN
                                    IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
                                      NlRTN := 0;  --課税状況用の場合は全て出力する
                                    ELSE
                                      NlRTN := FUNC_SEIGEN_KOHO_HANTEI(i_NTRENBAN,
                                                                       i_NCHOTEI_NENDO,
                                                                       i_NSYS_SHOKUINKOJIN_NO,
                                                                       i_VMASIN_NO);
                                      IF NlRTN <> 0 THEN
                                        NlRTN := 9;
                                        VlMSG := '賦課決定期間の制限対象候補世帯判定処理　国保世帯番号=　' || NKOKU_SETAI_NO || ' ' || SQLERRM;
                                        PROC_LOG_SHORI(NKOKU_SETAI_NO,
                                                       NNENDO,
                                                       NNENDO_BUN,
                                                       VlMSG);
                                      ELSE
                                        -- 出力判定
                                        ZLBSBUPCHK(c_NKANEN,
                                                    RwTAISHO.KOKU_SETAI_NO,
                                                    i_NCHOTEI_NENDO,
                                                    NlNENDO_BUN,
                                                    i_NSYS_SHOKUINKOJIN_NO,
                                                    i_NJIKKOU_KBN,
                                                    i_VMASIN_NO,
                                                    i_NTRENBAN,
                                                    NlRTN);     -- 出力判定(0:OK 1:NG 9:変更内容なし)
                                      END IF;
                                    END IF;

                                    -- 出力判定の戻り値で処理を分岐
                                    IF NlRTN = 1 THEN       -- 異常
                                        NlRTN := c_NERR;
                                    ELSIF NlRTN = 0 THEN    -- 正常
                                        NlRTN := c_NOK;
                                        IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
                                          --課税状況用課税計算の場合
                                          subUpdate_KJ(RwTAISHO.KOKU_SETAI_NO);  -- 19 計算TBLを課税状況用TBLにコピー
                                        ELSE
                                          -- 計算TBL→中間TBL
                                          subUpdate(RwTAISHO.KOKU_SETAI_NO);
                                                              -- 19 計算TBLを中間TBLにコピー
                                        END IF;
                                    ELSIF NlRTN = 9 THEN    -- 中間出力対象外
                                        NlRTN := c_NOK;
                                    END IF;
                                END IF;

                                IF NlRTN = 8 THEN    -- 減額処理不可能
                                  NlRTN := c_NOK;
                                END IF;

                                -- 計算TBLクリア
                                IF NlRTN = c_NOK THEN
                                    subCalClear;            -- 02 各計算TBLの内容クリア
                                END IF;
                                IF NlRTN = c_NERR THEN
                                 PROC_LOG_SHORI(NKOKU_SETAI_NO,NNENDO,NNENDO_BUN,VlMSG);
                                END IF;
                                -- １世帯分のデータ作成完了
                                BEGIN
                                    COMMIT;
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        NlRTN := c_NERR;
                                        VlMSG := 'funcSetaiSet COMMIT発行' ||
                                                 '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                                 ')' || SQLERRM;
                                        PROC_LOG_SHORI(NKOKU_SETAI_NO,NNENDO,NNENDO_BUN,VlMSG);
                                END;

                            END LOOP;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NlRTN := c_NERR;
                                VlMSG := '計算対象取得' ||
                                         '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                         ')' || SQLERRM;
                                PROC_LOG_SHORI(NKOKU_SETAI_NO,NNENDO,NNENDO_BUN,VlMSG);

                        END;
                        IF NlRTN = c_NERR THEN
                          PROC_LOG_SHORI(NKOKU_SETAI_NO,NNENDO,NNENDO_BUN,VlMSG);
                        END IF;
                        -- 次に取得する国保世帯番号を算出
                        NlKOKU_SETAI_NO := NlKOKU_SETAI_NO_W + 1;

                    END LOOP;
                END IF;
               IF NlRTN = c_NERR THEN
                NlRTN := 0;
                PROC_LOG_SHORI(NKOKU_SETAI_NO,NNENDO,NNENDO_BUN,VlMSG);
               END IF;
            END LOOP;
        END IF;

    END subKanenMain;

-------------------------------------------------------------------------------
-- 00-1 現年分メイン
-------------------------------------------------------------------------------
    PROCEDURE subGennenMain IS

        NwRTN           NUMBER;

        -- 計算対象カーソル
        CURSOR CwTAISHO IS
            SELECT *
              FROM (SELECT * FROM ZLBTKEISAN_TAISHO
                      WHERE KOKU_SETAI_NO   >= NlKOKU_SETAI_NO
                        AND SYS_TANMATSU_NO =  i_VMASIN_NO
                      ORDER BY KOKU_SETAI_NO)
             WHERE ROWNUM <= c_NMAX_NUM
             ORDER BY KOKU_SETAI_NO;
      NKOKU_SETAI_NO    ZLBTKEISAN_TAISHO.KOKU_SETAI_NO%TYPE;
      NNENDO            ZLBTKEISAN_TAISHO.NENDO%TYPE;
      NNENDO_BUN        ZLBTKEISAN_TAISHO.NENDO_BUN%TYPE;
    BEGIN

        NlMAX_TSUCHI_NO := 0;               -- 最大通知書番号
        NlKOKU_SETAI_NO := 0;               -- 計算対象取得用ワーク
        NlNENDO_BUN     := i_NNENDO_BUN;    -- パラメータの年度分を保持

        -- 賦課期日を取得
        subJokenSel;                -- 15-2 システム条件(賦課期日)取得

        -- 計算対象件数取得
        IF NlRTN = c_NOK THEN

            -- 計算対象の件数取得
            BEGIN
                SELECT COUNT(*) INTO IlMAX FROM ZLBTKEISAN_TAISHO
                 WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := '計算対象件数取得 ' || SQLERRM;
            END;

        END IF;

        IF NlRTN = c_NOK AND IlMAX > 0 THEN

            FOR IlIDX IN 1..TRUNC(IlMAX / c_NMAX_NUM) + 1 LOOP

                BEGIN
                    -- 計算対象世帯を全件読込む(MAX1000件)
                    FOR RwTAISHO IN CwTAISHO LOOP

                        NlKOKU_SETAI_NO_W := RwTAISHO.KOKU_SETAI_NO;
                        NKOKU_SETAI_NO    := RwTAISHO.KOKU_SETAI_NO;
                        NNENDO            := RwTAISHO.NENDO;
                        NNENDO_BUN        := RwTAISHO.NENDO_BUN;
                        --資格TMPの存在チェック
                        IF FUNCSHIKAKU_CHECK(NlKOKU_SETAI_NO_W) THEN
                          -- １世帯分のデータを作成する
                          NlRTN := funcSetaiSet(RwTAISHO);  -- 03 １世帯分のデータ作成
                        END IF;

                        -- 不足データ(賦課にあって計算に存在しないデータ)を作成
                        IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
                          NULL;  --課税状況の場合は、計算TBL不足分作成は行わない
                        ELSE
                          IF NlRTN = c_NOK THEN
                              NlRTN := funcMakeCal(RwTAISHO.KOKU_SETAI_NO);   -- 16 計算TBL不足分作成
                          END IF;
                        END IF;

                        -- 不用な計算所得(通知書番号0)を削除
                        IF NlRTN = c_NOK THEN
                            subDelShotoku;      -- 18 計算所得削除
                        END IF;

                        -- 作成したレコードの日付/時刻をあわせる
                        IF NlRTN = c_NOK THEN
                            subDateUpdate;      -- 20 日付/時刻の更新
                        END IF;

                        -- バッチ処理の場合、中間TBLに出力する
                        IF NlRTN = c_NOK AND i_NJIKKOU_KBN IN (c_NBATCH, c_KAZEIJOKYO, c_JITTAI_SETAI) THEN    --バッチ起動時

                            IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) OR i_NNOUKI_KBN = c_NNOUKI_HONSAN THEN
                            --課税状況・実態調査・本算定納期の時はすべて出力する！
                              NlRTN := 0;  --課税状況用の場合は全て出力する
                            ELSE
                              -- 出力判定
                              ZLBSBUPCHK(c_NGENNEN,
                                          RwTAISHO.KOKU_SETAI_NO,
                                          i_NCHOTEI_NENDO,
                                          NlNENDO_BUN,
                                          i_NSYS_SHOKUINKOJIN_NO,
                                          i_NJIKKOU_KBN,
                                          i_VMASIN_NO,
                                          i_NTRENBAN,
                                          NlRTN);     -- 出力判定(0:OK 1:NG 9:変更内容なし)
                            END IF;

                            -- 出力判定の戻り値で処理を分岐
                            IF NlRTN = 1 THEN       -- 異常
                                NlRTN := c_NERR;
                            ELSIF NlRTN = 0 THEN    -- 正常
                                NlRTN := c_NOK;
                                IF i_NJIKKOU_KBN IN(c_KAZEIJOKYO, c_JITTAI_SETAI) THEN
                                  --課税状況用課税計算の場合
                                  subUpdate_KJ(RwTAISHO.KOKU_SETAI_NO);  -- 19 計算TBLを課税状況用TBLにコピー
                                ELSE
                                  -- 計算TBL→中間TBL
                                  subUpdate(RwTAISHO.KOKU_SETAI_NO);  -- 19 計算TBLを中間TBLにコピー
                                END IF;

                            ELSIF NlRTN = 9 THEN    -- 中間出力対象外
                                NlRTN := c_NOK;
                                -- 計算異動TBL→中間異動TBL
                                subUpdate2(RwTAISHO.KOKU_SETAI_NO);   -- 計算異動TBLを中間異動TBLにコピー
                            END IF;

                            -- 計算TBLクリア
                            IF NlRTN = c_NOK THEN
                                subCalClear;            -- 02 各計算TBLの内容クリア
                            END IF;

                        END IF;
                        IF NlRTN = c_NERR THEN
                         PROC_LOG_SHORI(NKOKU_SETAI_NO,NNENDO,NNENDO_BUN,VlMSG);
                        END IF;
                        -- １世帯分のデータ作成完了
                        BEGIN
                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NlRTN := c_NERR;
                                VlMSG := 'funcSetaiSet COMMIT発行' ||
                                             '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                             ')' || SQLERRM;
                                PROC_LOG_SHORI(NKOKU_SETAI_NO,NNENDO,NNENDO_BUN,VlMSG);
                        END;

                    END LOOP;
                EXCEPTION
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := '計算対象取得' ||
                                 '(国保世帯番号=' || NlKOKU_SETAI_NO_W ||
                                 ')' || SQLERRM;
                       PROC_LOG_SHORI(NKOKU_SETAI_NO,NNENDO,NNENDO_BUN,VlMSG);
                END;
                IF NlRTN = c_NERR THEN
                 NlRTN := 0;
                 PROC_LOG_SHORI(NKOKU_SETAI_NO,NNENDO,NNENDO_BUN,VlMSG);
                END IF;
                -- 次に取得する国保世帯番号を算出
                NlKOKU_SETAI_NO := NlKOKU_SETAI_NO_W + 1;

            END LOOP;

        END IF;

    END subGennenMain;
-------------------------------------------------------------------------------
-- 00 メイン
-------------------------------------------------------------------------------
BEGIN
----- 初期処理 -----
    NlRTN := c_NOK;
    VlMSG := NULL;

    --所得割基準総所得 端数条件取得
    IKAHYO_HASU_KBN := ZLBPK00010.FCFFJKN2(51);

    -- 現年・過年判定
    IF i_NCHOTEI_NENDO = i_NNENDO_BUN THEN

        -- 調定年度＝年度分の場合は「現年」
        NlGENKA_KBN := c_NGENNEN;

    ELSIF i_NCHOTEI_NENDO > i_NNENDO_BUN THEN

        -- 調定年度＞年度分の場合は「過年」
        NlGENKA_KBN := c_NKANEN;

    ELSE    -- 上記以外は計算不可
        NlRTN := c_NERR;
        VlMSG := 'パラメータ異常(調定年度:' || i_NCHOTEI_NENDO ||
                 ' 年度分= ' || i_NNENDO_BUN || ')';
    END IF;

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

    --合併年度取得
    NlGAPEINENDO := FUNCGETGAPPEIBI(i_NKIJUNBI);

    -- 中間・計算TBLクリア
    IF NlRTN = c_NOK AND i_NJIKKOU_KBN IN (c_NBATCH, c_KAZEIJOKYO, c_JITTAI_SETAI) THEN

        -- ﾊﾞｯﾁの場合は中間/計算TBLを全削除
        subTruncateTbl;             -- 01 中間・計算TBL内容のクリア

    ELSE

        DELETE FROM ZLBTCALLOG WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
        -- ｵﾝﾗｲﾝの場合は端末番号指定で計算TBLのみ削除
        subCalClear;                -- 02 各計算TBLの内容クリア

    END IF;

----- 主処理 -----
    IF NlRTN = c_NOK THEN
        IF NlGENKA_KBN = c_NGENNEN THEN     -- 現年

            subGennenMain;          -- 00-1 現年課税計算メイン

        ELSE                                -- 過年
            IF i_NJIKKOU_KBN IN (c_NBATCH, c_KAZEIJOKYO, c_JITTAI_SETAI) THEN    --過年度ﾊﾞｯﾁ

                subKanenMain;       -- 00-2 過年度課税計算バッチメイン

            ELSE                                -- 過年度ｵﾝﾗｲﾝ

                subKanenSokuji;     -- 00-3 過年度課税計算オンラインメイン

            END IF;
        END IF;

    END IF;
----- 終了処理 -----
    IF NlRTN = c_NOK THEN        -- 正常に処理完了
        BEGIN
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'COMMIT発行 ' || SQLERRM;
        END;
    END IF;

    IF NlRTN != c_NOK THEN       -- 処理異常
        BEGIN
            NlRTN := c_NERR;
            ROLLBACK;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END IF;

    -- ログ出力
    IF NlRTN != c_NOK AND VlMSG IS NOT NULL THEN

        IF i_NJIKKOU_KBN IN (c_NBATCH, c_KAZEIJOKYO, c_JITTAI_SETAI) THEN    --バッチ起動時
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCALPACK', 1, '', '', 'ZLBSKCALPACK ' || VlMSG, i_NSYS_SHOKUINKOJIN_NO, i_VMASIN_NO);
        ELSIF i_NTRENBAN = -1 THEN
            -- テストの時のみ有効
            DBMS_OUTPUT.PUT_LINE('ZLBSKCALPACK ' || VlMSG);
        END IF;
    END IF;

    o_NRESULT := NlRTN;

END ZLBSKCALPACK;
/
