CREATE OR REPLACE PROCEDURE ZLBSCH4CALPACK (
--1.1.200.000
                                        i_CHOTEI_NENDO         IN  NUMBER,
                                        i_NENDO_BUN            IN  NUMBER,
                                        i_SYS_SHOKUINKOJIN_NO  IN  CHAR,
                                        i_KIJUN_NENGAPPI       IN  NUMBER,
                                        i_MASIN_NO             IN  NVARCHAR2,
                                        i_NTRENBAN             IN  NUMBER,
                                        o_RTN                  OUT NUMBER
                                               ) IS

------------------------------------------------------------------------------
--  業務名       ZLB（国民健康保険税）
--  PG 名        ZLBSCH4CALPACK
--  名称         H4賦課期日時点課税計算
--  処理概要     該当年度の賦課個人を読み込み、賦課期日に資格のある人のみ
--               (擬主含む)で課税計算を行う。
--  引数         i_CHOTEI_NENDO         調定年度
--               i_NENDO_BUN            年度分
--               i_SYS_SHOKUINKOJIN_NO  更新職員番号
--               i_KIJUN_NENGAPPI       基準日
--               i_MASIN_NO             端末番号
--               i_NTRENBAN             登録連番
--               o_RTN                  処理結果
--  作成者       ZCZL.HUANGFUCHENGMING
--  作成日       2023/08/02
--  Version     0.2.000.000
------------------------------------------------------------------------------
--  修正履歴
--  2024/05/07 ZCZL.LYF UPDATE 0.3.000.100:国保2次にマージ作業
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--  2025/12/03 ZCZL.XIESHUN ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
-- =========================================================================
-- コンスト定義
-- =========================================================================

    -- 戻り値
    c_NRTN_0          NUMBER(2)   := 0;        -- 正常
    c_NRTN_9          NUMBER(2)   := 9;        -- 異常
    c_NRTN_1          NUMBER(2)   := 1;        -- 排他エラー

    -- ログ連番
    c_LOG_99          NUMBER(2)   := 99;       -- エラー用

    c_F4_SHIK_KBN_NO  NUMBER(2)   := 0;        -- 賦課期日資格区分 (0:資格無し

    c_GINUSHI_SHIRYO_NO  NUMBER(2)   := 1;     -- 資料用擬主 (1:擬主を被保数に含めない

    c_GISEI_KBN_GISEI    NUMBER(2)   := 1;     -- 擬制区分 (1:擬制世帯

    -- 資格区分
    c_SHIK_KBN_SETAINUSI      NUMBER(2)   := 1;  -- 世帯主
    c_SHIK_KBN_GINUSI         NUMBER(2)   := 2;  -- 疑主
    c_SHIK_KBN_SETAIIN        NUMBER(2)   := 3;  -- 世帯員
    c_SHIK_KBN_SETAINUSIX     NUMBER(2)   := 7;  -- 世帯主喪失
    c_SHIK_KBN_GINUSIX        NUMBER(2)   := 8;  -- 疑主喪失
    c_SHIK_KBN_SETAIINX       NUMBER(2)   := 9;  -- 世帯員喪失
    c_SHIK_KBN_SETAINUSI_TAI  NUMBER(2)   := 11; -- 世帯主(退職)
    c_SHIK_KBN_SETAIIN_TAI    NUMBER(2)   := 13; -- 世帯員(退職)
    c_SHIK_KBN_TOKUTEI        NUMBER(2)   := 5;  -- 特定同一

    -- 退職区分
    c_TAI_KBN_NO              NUMBER(2)   := 0;  -- 退職していない
    c_TAI_KBN_HONNIN          NUMBER(2)   := 1;  -- 退職本人
    c_TAI_KBN_HIFUYO          NUMBER(2)   := 2;  -- 退職被扶養

    c_R_NO            NUMBER(2)   := 10;       -- 履歴番号

    c_JIKKOU_KBN_BA   NUMBER(2)   := 0;        -- 実行区分(0:バッチ処理

    c_CAL_KBN_F4      NUMBER(2)   := 2;        -- 呼出区分(2:H4/C4処理

    -- 算定団体コード
    c_SANTEIDANTAI_CD NUMBER(2)   := 1;        -- システム条件固定読込値

    -- 不均一課税
    c_FUKI_KAZEI_NO   NUMBER(2)   := 0;        -- する
    c_FUKI_KAZEI_YES  NUMBER(2)   := 1;        -- しない


-- =========================================================================
-- ローカル変数
-- =========================================================================

    IlRTN            PLS_INTEGER;      -- 戻り値
    BlRTN            BOOLEAN;          -- 戻り値

    NlCNT            NUMBER(1);        -- カウント用

    NlCNT_MAIN       NUMBER(10);       -- メイン処理件数カウント用

    VlERRBUF         NVARCHAR2(100);   -- エラー

    VlSQL            VARCHAR2(1000);   -- sql文

    NlSYSDATE              NUMBER(8);       -- システム日付
    NlSYSTIME              NUMBER(6);       -- システム時間

    -- 履歴保持用
    TlSANTEIDANTAI_CD   ZLBTKOJIN_MID.SANTEIDANTAI_CD%TYPE;    -- 算定団体コード
    TISANTEIDANTAI_SAVE ZLBTKOJIN_MID.SANTEIDANTAI_CD%TYPE;    --算定団体コード保持
    TlKOKU_SETAI_NO     ZLBTKOJIN_MID.KOKU_SETAI_NO%TYPE;      -- 国保世帯番号
    TlNUSHI_KOJIN_NO    KHSTSETAI.NUSHI_KOJIN_NO%TYPE;         -- 最新の世帯主

    -- 個人登録用
    TlNEW_SHIK_KBN      ZLBTKOJIN_MID.NEW_SHIK_KBN%TYPE;       -- 最新資格区分
    TlNEW_KAI_SHIK_KBN  ZLBTKOJIN_MID.NEW_KAI_SHIK_KBN%TYPE;   -- 最新介護資格区分
    TlNEW_TAI_KBN       ZLBTKOJIN_MID.NEW_TAI_KBN%TYPE;        -- 最新退職区分
    TlSHIK_4            ZLBTKOJIN_MID.SHIK_4%TYPE;             -- 資格４月
    TlSHIK_5            ZLBTKOJIN_MID.SHIK_5%TYPE;             -- 資格５月
    TlSHIK_6            ZLBTKOJIN_MID.SHIK_6%TYPE;             -- 資格６月
    TlSHIK_7            ZLBTKOJIN_MID.SHIK_7%TYPE;             -- 資格７月
    TlSHIK_8            ZLBTKOJIN_MID.SHIK_8%TYPE;             -- 資格８月
    TlSHIK_9            ZLBTKOJIN_MID.SHIK_9%TYPE;             -- 資格９月
    TlSHIK_10           ZLBTKOJIN_MID.SHIK_10%TYPE;            -- 資格１０月
    TlSHIK_11           ZLBTKOJIN_MID.SHIK_11%TYPE;            -- 資格１１月
    TlSHIK_12           ZLBTKOJIN_MID.SHIK_12%TYPE;            -- 資格１２月
    TlSHIK_1            ZLBTKOJIN_MID.SHIK_1%TYPE;             -- 資格１月
    TlSHIK_2            ZLBTKOJIN_MID.SHIK_2%TYPE;             -- 資格２月
    TlSHIK_3            ZLBTKOJIN_MID.SHIK_3%TYPE;             -- 資格３月
    TlKAI_SHIK_4        ZLBTKOJIN_MID.KAI_SHIK_4%TYPE;         -- 介護資格４月
    TlKAI_SHIK_5        ZLBTKOJIN_MID.KAI_SHIK_5%TYPE;         -- 介護資格５月
    TlKAI_SHIK_6        ZLBTKOJIN_MID.KAI_SHIK_6%TYPE;         -- 介護資格６月
    TlKAI_SHIK_7        ZLBTKOJIN_MID.KAI_SHIK_7%TYPE;         -- 介護資格７月
    TlKAI_SHIK_8        ZLBTKOJIN_MID.KAI_SHIK_8%TYPE;         -- 介護資格８月
    TlKAI_SHIK_9        ZLBTKOJIN_MID.KAI_SHIK_9%TYPE;         -- 介護資格９月
    TlKAI_SHIK_10       ZLBTKOJIN_MID.KAI_SHIK_10%TYPE;        -- 介護資格１０月
    TlKAI_SHIK_11       ZLBTKOJIN_MID.KAI_SHIK_11%TYPE;        -- 介護資格１１月
    TlKAI_SHIK_12       ZLBTKOJIN_MID.KAI_SHIK_12%TYPE;        -- 介護資格１２月
    TlKAI_SHIK_1        ZLBTKOJIN_MID.KAI_SHIK_1%TYPE;         -- 介護資格１月
    TlKAI_SHIK_2        ZLBTKOJIN_MID.KAI_SHIK_2%TYPE;         -- 介護資格２月
    TlKAI_SHIK_3        ZLBTKOJIN_MID.KAI_SHIK_3%TYPE;         -- 介護資格３月
    TlKAHYO             ZLBTKOJIN_MID.KAHYO%TYPE;              -- 課税標準額
    TlNEW_SHITSU_KBN    ZLBTKOJIN_MID.NEW_SHITSU_KBN%TYPE;     -- 最新失業者資格区分
    TlSHITSU_4          ZLBTKOJIN_MID.SHITSU_4%TYPE;           -- 失業者資格4月
    TlSHITSU_5          ZLBTKOJIN_MID.SHITSU_5%TYPE;           -- 失業者資格5月
    TlSHITSU_6          ZLBTKOJIN_MID.SHITSU_6%TYPE;           -- 失業者資格6月
    TlSHITSU_7          ZLBTKOJIN_MID.SHITSU_7%TYPE;           -- 失業者資格7月
    TlSHITSU_8          ZLBTKOJIN_MID.SHITSU_8%TYPE;           -- 失業者資格8月
    TlSHITSU_9          ZLBTKOJIN_MID.SHITSU_9%TYPE;           -- 失業者資格9月
    TlSHITSU_10         ZLBTKOJIN_MID.SHITSU_10%TYPE;          -- 失業者資格10月
    TlSHITSU_11         ZLBTKOJIN_MID.SHITSU_11%TYPE;          -- 失業者資格11月
    TlSHITSU_12         ZLBTKOJIN_MID.SHITSU_12%TYPE;          -- 失業者資格12月
    TlSHITSU_1          ZLBTKOJIN_MID.SHITSU_1%TYPE;           -- 失業者資格1月
    TlSHITSU_2          ZLBTKOJIN_MID.SHITSU_2%TYPE;           -- 失業者資格2月
    TlSHITSU_3          ZLBTKOJIN_MID.SHITSU_3%TYPE;           -- 失業者資格3月
    TlSHITSU_GAI_BI         ZLBTKOJIN_MID.SHITSU_GAI_BI%TYPE;          -- 失業軽減該当日
    TlSHITSU_HIGAI_BI       ZLBTKOJIN_MID.SHITSU_HIGAI_BI%TYPE;        -- 失業軽減非該当日
    TlSHITSU_SHOTOKU        ZLBTKOJIN_MID.SHITSU_SHOTOKU%TYPE;         -- 失業軽減適用後所得額
    TlSHITSU_KAHYO          ZLBTKOJIN_MID.SHITSU_KAHYO%TYPE;           -- 失業軽減適用後課税標準額
    TlSHITSU_KEIGEN_SHOTOKU ZLBTKOJIN_MID.SHITSU_KEIGEN_SHOTOKU%TYPE;  -- 失業軽減適用後軽減判定所得
    -- レコードセット
    RJOKEN                ZLBTJOKEN%ROWTYPE;             -- システム条件

    vSQL      VARCHAR2(4000);

-- =========================================================================
-- パラメータ変数
-- =========================================================================

    NlCHOTEI_NENDO         NUMBER(4);
    NlNENDO_BUN            NUMBER(4);
    NlSYS_SHOKUINKOJIN_NO  CHAR(12);
    NlKIJUN_NENGAPPI       NUMBER(8);
    VlMASIN_NO             NVARCHAR2(63);
    NlNTRENBAN             NUMBER(15);

-- =========================================================================
-- カーソルの定義
-- =========================================================================

    -- 賦課個人
    -- 賦課期日に資格がある個人検索
    CURSOR CKOJIN_MID is
        SELECT * FROM ZLBTKOJIN_MID
         WHERE CHOTEI_NENDO =  NlCHOTEI_NENDO     -- 調停年度
           AND NENDO_BUN    =  NlCHOTEI_NENDO     -- 年度分
           AND F4_SHIK_KBN  != c_F4_SHIK_KBN_NO   -- 賦課期日資格区分
         ORDER BY SANTEIDANTAI_CD                      -- 算定団体コード
                 ,KOKU_SETAI_NO                        -- 国保世帯番号
                 ,KOJIN_NO                             -- 個人番号
    ;

    RKOJIN_MID           CKOJIN_MID%ROWTYPE;               -- 賦課個人


------------------------------------------------------------------------------
--  08 世帯主取得                                                           --
------------------------------------------------------------------------------
FUNCTION FUNC_GET_NUSHI( i_KOKU_SETAI_NO   IN  NUMBER
                        ,o_NUSHI_KOJIN_NO  OUT NUMBER
                        ,o_VlERRBUF        OUT NVARCHAR2
                          ) RETURN NUMBER IS

    IwRTN            PLS_INTEGER;          -- 戻り値
    IwCNT            NUMBER(3);            -- カウント

  BEGIN

    -- 初期化
    IwRTN := c_NRTN_0;

    BEGIN
      -- 計算個人より賦課期日時点の世帯主取得
      SELECT COUNT(*) INTO IwCNT
         FROM  ZLBTKOJIN_CAL                -- 計算個人
         WHERE F4_SHIK_KBN  IN  ( c_SHIK_KBN_SETAINUSI    -- 賦課期日資格区分 (世帯主
                                 ,c_SHIK_KBN_GINUSI    )  --                  (擬主
           AND SYS_TANMATSU_NO = VlMASIN_NO
      ;
    EXCEPTION
      WHEN OTHERS THEN
        IwRTN       := c_NRTN_9;
        o_VlERRBUF  := 'ZLBTKOJIN_CAL読込エラー ' ||SQLCODE||SQLERRM;
    END;

    IF IwRTN = c_NRTN_0 THEN
      -- 1件のみ→計算個人の個人番号を世帯主とする
      IF IwCNT = 1 THEN
        BEGIN
          -- 計算個人より賦課期日時点の世帯主取得
          SELECT KOJIN_NO INTO o_NUSHI_KOJIN_NO
             FROM  ZLBTKOJIN_CAL                -- 計算個人
             WHERE F4_SHIK_KBN  IN  ( c_SHIK_KBN_SETAINUSI   -- 賦課期日資格区分 (世帯主
                                     ,c_SHIK_KBN_GINUSI    ) --                  (擬主
               AND SYS_TANMATSU_NO = VlMASIN_NO
          ;
        EXCEPTION
          WHEN OTHERS THEN
            IwRTN       := c_NRTN_9;
            o_VlERRBUF  := 'ZLBTKOJIN_CAL読込エラー ' ||SQLCODE||SQLERRM;
        END;

      ELSE
      -- 取得しようが無いので、世帯基本より取得
        BEGIN
          -- 世帯基本より最新の世帯主取得
          SELECT NUSHI_KOJIN_NO INTO o_NUSHI_KOJIN_NO
             FROM  KHSTSETAI                  -- 世帯基本
             WHERE KOKU_SETAI_NO     = i_KOKU_SETAI_NO    -- 国保世帯番号
          ;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            IwRTN       := c_NRTN_9;
            o_VlERRBUF  := 'KHSTSETAI該当データ無し'
                           ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
          WHEN OTHERS THEN
            IwRTN       := c_NRTN_9;
            o_VlERRBUF  := 'KHSTSETAI読込エラー ' ||SQLCODE||SQLERRM
                           ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
        END;
      END IF;

    END IF;


    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNC_GET_NUSHI;

------------------------------------------------------------------------------
--  06 個人処理                                                             --
------------------------------------------------------------------------------
FUNCTION FUNCKOJIN_SYORI( o_VlERRBUF OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN            PLS_INTEGER;          -- 戻り値

  BEGIN

    -- 初期化
    IwRTN := c_NRTN_0;

    TlKAHYO := 0;

    -- 賦課個人より
    TlNEW_SHIK_KBN  := RKOJIN_MID.NEW_SHIK_KBN;
    TlNEW_TAI_KBN   := RKOJIN_MID.NEW_TAI_KBN;
    TlSHIK_4        := RKOJIN_MID.SHIK_4;
    TlSHIK_5        := RKOJIN_MID.SHIK_5;
    TlSHIK_6        := RKOJIN_MID.SHIK_6;
    TlSHIK_7        := RKOJIN_MID.SHIK_7;
    TlSHIK_8        := RKOJIN_MID.SHIK_8;
    TlSHIK_9        := RKOJIN_MID.SHIK_9;
    TlSHIK_10       := RKOJIN_MID.SHIK_10;
    TlSHIK_11       := RKOJIN_MID.SHIK_11;
    TlSHIK_12       := RKOJIN_MID.SHIK_12;
    TlSHIK_1        := RKOJIN_MID.SHIK_1;
    TlSHIK_2        := RKOJIN_MID.SHIK_2;
    TlSHIK_3        := RKOJIN_MID.SHIK_3;
    TlKAHYO         := RKOJIN_MID.KAHYO;

    -- 賦課期日資格区分
    -- ［擬主］
    -- 擬主セット
    IF RKOJIN_MID.F4_SHIK_KBN = c_SHIK_KBN_GINUSI THEN
      TlNEW_SHIK_KBN := c_SHIK_KBN_GINUSI;
      TlNEW_TAI_KBN  := 0;
      TlSHIK_4       := c_SHIK_KBN_GINUSI;
      TlSHIK_5       := c_SHIK_KBN_GINUSI;
      TlSHIK_6       := c_SHIK_KBN_GINUSI;
      TlSHIK_7       := c_SHIK_KBN_GINUSI;
      TlSHIK_8       := c_SHIK_KBN_GINUSI;
      TlSHIK_9       := c_SHIK_KBN_GINUSI;
      TlSHIK_10      := c_SHIK_KBN_GINUSI;
      TlSHIK_11      := c_SHIK_KBN_GINUSI;
      TlSHIK_12      := c_SHIK_KBN_GINUSI;
      TlSHIK_1       := c_SHIK_KBN_GINUSI;
      TlSHIK_2       := c_SHIK_KBN_GINUSI;
      TlSHIK_3       := c_SHIK_KBN_GINUSI;

    -- ［世帯主・世帯員-退職していない-］
    -- 賦課期日資格区分セット
    ELSIF RKOJIN_MID.F4_SHIK_KBN IN ( c_SHIK_KBN_SETAINUSI
                                   ,c_SHIK_KBN_TOKUTEI
                                   ,c_SHIK_KBN_SETAIIN   ) AND
          RKOJIN_MID.F4_TAI_KBN = c_TAI_KBN_NO      THEN
      TlNEW_SHIK_KBN := RKOJIN_MID.F4_SHIK_KBN;
      TlNEW_TAI_KBN  := 0;
      TlSHIK_4       := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_5       := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_6       := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_7       := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_8       := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_9       := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_10      := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_11      := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_12      := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_1       := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_2       := RKOJIN_MID.F4_SHIK_KBN;
      TlSHIK_3       := RKOJIN_MID.F4_SHIK_KBN;

    -- ［世帯主・世帯員-退職している-］
    ELSIF RKOJIN_MID.F4_SHIK_KBN IN ( c_SHIK_KBN_SETAINUSI
                                   ,c_SHIK_KBN_SETAIIN   ) AND
          RKOJIN_MID.F4_TAI_KBN IN  ( c_TAI_KBN_HONNIN
                                   ,c_TAI_KBN_HIFUYO   ) THEN

      TlNEW_SHIK_KBN := RKOJIN_MID.F4_SHIK_KBN;
      TlNEW_TAI_KBN  := RKOJIN_MID.F4_TAI_KBN;

      -- ［世帯主］
      -- 世帯主(退職)セット
      IF RKOJIN_MID.F4_SHIK_KBN = c_SHIK_KBN_SETAINUSI THEN
        TlSHIK_4       := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_5       := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_6       := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_7       := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_8       := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_9       := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_10      := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_11      := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_12      := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_1       := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_2       := c_SHIK_KBN_SETAINUSI_TAI;
        TlSHIK_3       := c_SHIK_KBN_SETAINUSI_TAI;
      -- ［世帯員］
      -- 世帯員(退職)セット
      ELSE
        TlSHIK_4       := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_5       := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_6       := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_7       := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_8       := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_9       := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_10      := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_11      := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_12      := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_1       := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_2       := c_SHIK_KBN_SETAIIN_TAI;
        TlSHIK_3       := c_SHIK_KBN_SETAIIN_TAI;
      END IF;

    END IF;

    -- 介護
    TlNEW_KAI_SHIK_KBN := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_4       := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_5       := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_6       := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_7       := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_8       := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_9       := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_10      := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_11      := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_12      := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_1       := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_2       := RKOJIN_MID.F4_KAI_KBN;
    TlKAI_SHIK_3       := RKOJIN_MID.F4_KAI_KBN;
    TlNEW_SHITSU_KBN := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_4       := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_5       := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_6       := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_7       := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_8       := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_9       := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_10      := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_11      := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_12      := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_1       := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_2       := RKOJIN_MID.F4_SHITSU_KBN;
    TlSHITSU_3       := RKOJIN_MID.F4_SHITSU_KBN;
    IF TlNEW_SHITSU_KBN = 1 THEN
      TlSHITSU_GAI_BI         := RKOJIN_MID.SHITSU_GAI_BI;
      TlSHITSU_HIGAI_BI       := RKOJIN_MID.SHITSU_HIGAI_BI;
      TlSHITSU_SHOTOKU        := RKOJIN_MID.SHITSU_SHOTOKU;
      TlSHITSU_KAHYO          := RKOJIN_MID.SHITSU_KAHYO;
      TlSHITSU_KEIGEN_SHOTOKU := RKOJIN_MID.SHITSU_KEIGEN_SHOTOKU;
    ELSE
      TlSHITSU_GAI_BI         := 0;
      TlSHITSU_HIGAI_BI       := 0;
      TlSHITSU_SHOTOKU        := 0;
      TlSHITSU_KAHYO          := 0;
      TlSHITSU_KEIGEN_SHOTOKU := 0;
    END IF;
    -- 《計算個人登録》
    BEGIN
      INSERT INTO ZLBTKOJIN_CAL VALUES (
          RKOJIN_MID.KOKU_SETAI_NO    ,
          RKOJIN_MID.KOJIN_NO         ,
          RKOJIN_MID.SANTEIDANTAI_CD  ,
          RKOJIN_MID.CHOTEI_NENDO     ,
          RKOJIN_MID.NENDO_BUN        ,
          RKOJIN_MID.R_NO             ,
          RKOJIN_MID.TSUCHI_NO        ,
          TlNEW_SHIK_KBN     ,
          TlNEW_KAI_SHIK_KBN ,
          TlNEW_TAI_KBN      ,
          RKOJIN_MID.F4_SHIK_KBN      ,
          RKOJIN_MID.F4_KAI_KBN       ,
          RKOJIN_MID.F4_TAI_KBN       ,
          RKOJIN_MID.FUKA_SHIK_KBN    ,
          RKOJIN_MID.FUKA_KAI_KBN     ,
          RKOJIN_MID.KEIGEN_HANT_KBN  ,
          TlSHIK_4           ,
          TlSHIK_5           ,
          TlSHIK_6           ,
          TlSHIK_7           ,
          TlSHIK_8           ,
          TlSHIK_9           ,
          TlSHIK_10          ,
          TlSHIK_11          ,
          TlSHIK_12          ,
          TlSHIK_1           ,
          TlSHIK_2           ,
          TlSHIK_3           ,
          TlKAI_SHIK_4       ,
          TlKAI_SHIK_5       ,
          TlKAI_SHIK_6       ,
          TlKAI_SHIK_7       ,
          TlKAI_SHIK_8       ,
          TlKAI_SHIK_9       ,
          TlKAI_SHIK_10      ,
          TlKAI_SHIK_11      ,
          TlKAI_SHIK_12      ,
          TlKAI_SHIK_1       ,
          TlKAI_SHIK_2       ,
          TlKAI_SHIK_3       ,
          RKOJIN_MID.SHOTOKU          ,
          TlKAHYO            ,
          RKOJIN_MID.SHOTOKU_WARI     ,
          RKOJIN_MID.KAI_SHOTOKU_WARI ,
          RKOJIN_MID.SIEN_SHOTOKU_WARI,
          RKOJIN_MID.KEIGEN_SHOTOKU   ,
          RKOJIN_MID.SHISANZEI        ,
          RKOJIN_MID.SHISAN_WARI      ,
          RKOJIN_MID.KAI_SHISAN_WARI  ,
          RKOJIN_MID.SIEN_SHISAN_WARI ,
          RKOJIN_MID.SENJU_KBN        ,
          RKOJIN_MID.RONEN_KBN        ,
          RKOJIN_MID.SHINKOKU_KBN     ,
          RKOJIN_MID.SHU_SHOTOKU_KBN  ,
          RKOJIN_MID.J_KAZEI_KBN      ,
          RKOJIN_MID.J_SHOTOKU_WARI   ,
          RKOJIN_MID.J_KINTO_WARI     ,
          RKOJIN_MID.NEW_SHUTOK_BI    ,
          RKOJIN_MID.NEW_SOSHITSU_BI  ,
          RKOJIN_MID.NEW_ZOKU         ,
          RKOJIN_MID.KAI_GAI_BI       ,
          RKOJIN_MID.KAI_HIGAI_BI     ,
          RKOJIN_MID.TANJO_65         ,
          RKOJIN_MID.KOSEI_BI         ,
          RKOJIN_MID.JIYU             ,
          RKOJIN_MID.KAI_KOSEI_BI     ,
          RKOJIN_MID.KAI_JIYU         ,
          RKOJIN_MID.KEIGEN_BI        ,
          RKOJIN_MID.SEKISAN_GAI_KBN  ,
          RKOJIN_MID.KOJIN_NENZEI     ,
          RKOJIN_MID.ZOKU_NAME        ,
          RKOJIN_MID.SHIK_R_NO        ,
          RKOJIN_MID.SYS_SAKUSEIBI    ,
          RKOJIN_MID.SYS_KOSHINBI     ,
          RKOJIN_MID.SYS_JIKAN        ,
          RKOJIN_MID.SYS_SHOKUINKOJIN_NO ,
          VlMASIN_NO     ,
          -- ↓以下、CALのみ存在している項目
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          RKOJIN_MID.CUST_1,
          RKOJIN_MID.CUST_2,
          RKOJIN_MID.CUST_3
          ,TlNEW_SHITSU_KBN
          ,RKOJIN_MID.F4_SHITSU_KBN
          ,TlSHITSU_4
          ,TlSHITSU_5
          ,TlSHITSU_6
          ,TlSHITSU_7
          ,TlSHITSU_8
          ,TlSHITSU_9
          ,TlSHITSU_10
          ,TlSHITSU_11
          ,TlSHITSU_12
          ,TlSHITSU_1
          ,TlSHITSU_2
          ,TlSHITSU_3
          ,TlSHITSU_GAI_BI
          ,TlSHITSU_HIGAI_BI
          ,TlSHITSU_SHOTOKU
          ,TlSHITSU_KAHYO
          ,TlSHITSU_KEIGEN_SHOTOKU
          ,RKOJIN_MID.KYUYO_SHOTOKU_KBN    --給与所得者等該当区分
--2024/05/07 ZCZL.LYF Add START 0.3.000.100:国保2次にマージ作業
          ,RKOJIN_MID.NEW_SAN_KBN          -- 最新産前産後資格区分
          ,RKOJIN_MID.F4_SAN_KBN           -- 賦課期日産前産後資格区分
          ,RKOJIN_MID.SAN_4                -- 産前産後4月
          ,RKOJIN_MID.SAN_5                -- 産前産後5月
          ,RKOJIN_MID.SAN_6                -- 産前産後6月
          ,RKOJIN_MID.SAN_7                -- 産前産後7月
          ,RKOJIN_MID.SAN_8                -- 産前産後8月
          ,RKOJIN_MID.SAN_9                -- 産前産後9月
          ,RKOJIN_MID.SAN_10               -- 産前産後10月
          ,RKOJIN_MID.SAN_11               -- 産前産後11月
          ,RKOJIN_MID.SAN_12               -- 産前産後12月
          ,RKOJIN_MID.SAN_1                -- 産前産後1月
          ,RKOJIN_MID.SAN_2                -- 産前産後2月
          ,RKOJIN_MID.SAN_3                -- 産前産後3月
          ,RKOJIN_MID.SAN_GAI_BI           -- 産前産後該当日
          ,RKOJIN_MID.SAN_HIGAI_BI         -- 産前産後非該当日
          ,0                               -- 医療産前産後均等割軽減額
          ,0                               -- 医療産前産後所得割軽減額
          ,0                               -- 介護産前産後均等割軽減額
          ,0                               -- 介護産前産後所得割軽減額
          ,0                               -- 支援産前産後均等割軽減額
          ,0                               -- 支援産前産後所得割軽減額
--  2025/08/11 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
          ,0
          ,RKOJIN_MID.KDM_SHOTOKU_WARI
          ,RKOJIN_MID.KDM_SHISAN_WARI
          ,0
          ,0
          ,0
          ,0
          ,0
          ,0
--  2025/08/11 ZCZL.WANGMING ADD END
--2024/05/07 ZCZL.LYF Add END
--2025/12/03 ZCZL.XIESHUN ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
          ,RKOJIN_MID.KDM_KODOMO_KEIGEN_KITO   -- 子ども均等割軽減額（未就学児）
          ,RKOJIN_MID.KDM_KINTO                -- 子ども均等割額
          ,RKOJIN_MID.KDM_KINTO18              -- 子ども18歳以上均等割額
--2025/12/03 ZCZL.XIESHUN ADD END
         )
      ;
    EXCEPTION
      WHEN OTHERS THEN
        IwRTN        := c_NRTN_9;
        o_VlERRBUF   := 'ZLBTKIHON_CAL 登録エラー ' ||SQLCODE||SQLERRM
                ||' 国保世帯番号='||RKOJIN_MID.KOKU_SETAI_NO ;
    END;

    IF IwRTN  = c_NRTN_0  THEN

      -- 《計算所得登録》
      -- 該当個人データ
      -- MID → CAL
      BEGIN
        INSERT INTO ZLBTSHOTOKU_CAL
          SELECT *
          FROM ZLBTSHOTOKU_MID
          WHERE KOKU_SETAI_NO    =  RKOJIN_MID.KOKU_SETAI_NO
            AND KOJIN_NO         =  RKOJIN_MID.KOJIN_NO
            AND SANTEIDANTAI_CD  =  RKOJIN_MID.SANTEIDANTAI_CD
            AND CHOTEI_NENDO     =  RKOJIN_MID.CHOTEI_NENDO
            AND NENDO_BUN        =  RKOJIN_MID.NENDO_BUN
            AND R_NO             =  RKOJIN_MID.R_NO
            AND TSUCHI_NO        =  RKOJIN_MID.TSUCHI_NO
          ;
      EXCEPTION
        WHEN OTHERS THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := 'ZLBTSHOTOKU_CAL 登録エラー ' ||SQLCODE||SQLERRM
                          ||' 国保世帯番号='||RKOJIN_MID.KOKU_SETAI_NO ;
      END;

    END IF;

    RETURN( IwRTN );

END FUNCKOJIN_SYORI ;

------------------------------------------------------------------------------
--  05 更新処理                                                             --
------------------------------------------------------------------------------
FUNCTION FUNCUPDATE( i_KOKU_SETAI_NO  IN  NUMBER
                    ,o_VlERRBUF       OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN            PLS_INTEGER;          -- 戻り値

    TlGENZON_KBN           ZLBTKIHON_CAL.GENZON_KBN%TYPE;        -- 現存区分
    TlGISEI_KBN            ZLBTKIHON_CAL.GISEI_KBN%TYPE;         -- 擬制区分
    TlFUKA_KIJITSU_CNT     ZLBTKIHON_CAL.FUKA_KIJITSU_CNT%TYPE;  -- 全体賦課期日人員
    TlNENZEI               ZLBTKIHON_CAL.NENZEI%TYPE;            -- 全体年税額
    TlFUKA_KIJITSU_CNT_TAI ZLBTTAI_CAL.FUKA_KIJITSU_CNT%TYPE;    -- 退職賦課期日人員
    TlKINTO_CNT            ZLBTTAI_CAL.KINTO_CNT%TYPE;           -- 均等人員
    VSHO_NO                ZLBTKIHON_H4.SHO_NO%TYPE;             --証番号
    IOLD_JICHI_KBN         PLS_INTEGER;                          --旧自治体区分
    NNUSHI_KOJIN_NO        NUMBER := 0;                          --個人番号
    RATENA                GABTATENAKIHON%ROWTYPE;                --宛名基本データ
    RSOFU                 GABTSOFUSAKI%ROWTYPE;                  --送付先データ
    TlGYOSEIKU_CD         ZLBTKIHON_H4.GYOSEIKU_CD%TYPE;         --行政区コード

    --記号番号カーソル（証番号・旧自治体区分取得用）
    CURSOR CKIGONO IS
      SELECT OLD_JICHI_KBN, SHO_NO
        FROM KHSTKIGONO
        WHERE KOKU_SETAI_NO = i_KOKU_SETAI_NO
          AND SHO_NO_TEKI_SBI <= i_KIJUN_NENGAPPI
          AND SAKUJO_KBN = 0
        ORDER BY SHO_NO_TEKI_SBI DESC, IDO_RENBAN DESC;

  BEGIN

    -- 初期化
    IwRTN := c_NRTN_0;
    VSHO_NO        := NULL;  --証番号
    IOLD_JICHI_KBN := 0;     --旧自治体区分

    --<全体> ----------------------------------------------------------------↓
    -- 計算基本,計算退職読込(1件しか登録されていない)
    BEGIN
      SELECT KIHON_CAL.GENZON_KBN
            ,KIHON_CAL.GISEI_KBN
            ,NVL(KIHON_CAL.FUKA_KIJITSU_CNT,0)
            ,NVL(KIHON_CAL.NENZEI,0)
            ,NVL(TAI_CAL.FUKA_KIJITSU_CNT,0)
            ,NVL(KIHON_CAL.KINTO_CNT,0)
            ,KIHON_CAL.NUSHI_KOJIN_NO
      INTO   TlGENZON_KBN                  -- 現存区分
            ,TlGISEI_KBN                   -- 擬制区分
            ,TlFUKA_KIJITSU_CNT            -- 全体賦課期日人員
            ,TlNENZEI                      -- 全体年税額
            ,TlFUKA_KIJITSU_CNT_TAI        -- 退職賦課期日人員
            ,TlKINTO_CNT                   -- 全体均等人員
            ,NNUSHI_KOJIN_NO               --世帯主個人番号

      FROM   ZLBTKIHON_CAL KIHON_CAL ,     -- 計算基本
             ZLBTTAI_CAL   TAI_CAL         -- 退職基本(無くてもok)
      WHERE  KIHON_CAL.KOKU_SETAI_NO     = TAI_CAL.KOKU_SETAI_NO(+)
      AND    KIHON_CAL.SANTEIDANTAI_CD   = TAI_CAL.SANTEIDANTAI_CD(+)
      AND    KIHON_CAL.CHOTEI_NENDO      = TAI_CAL.CHOTEI_NENDO(+)
      AND    KIHON_CAL.NENDO_BUN         = TAI_CAL.NENDO_BUN(+)
      AND    KIHON_CAL.TSUCHI_NO         = TAI_CAL.TSUCHI_NO(+)
      AND    KIHON_CAL.SYS_TANMATSU_NO   = VlMASIN_NO
      AND    TAI_CAL.SYS_TANMATSU_NO     = VlMASIN_NO
      ;
    EXCEPTION
      WHEN OTHERS THEN
        IwRTN        := c_NRTN_9;
        o_VlERRBUF   := 'ZLBTKIHON_CAL 検索エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
    END;

    IF IwRTN = c_NRTN_0  THEN

      IF TlNENZEI != 0 THEN

        -- システム日付
        NlSYSDATE := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
        -- システム時間
        NlSYSTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MMSS'));

        -- 擬主を被保数に含めない,擬制世帯
        IF RJOKEN.GINUSHI_SHIRYO = c_GINUSHI_SHIRYO_NO AND
           TlGISEI_KBN = c_GISEI_KBN_GISEI THEN

          -- 全体賦課期日人員>0 AND
          -- 全体賦課期日人員 = 退職賦課期日人員
          IF TlFUKA_KIJITSU_CNT != 0 AND
             TlFUKA_KIJITSU_CNT = TlFUKA_KIJITSU_CNT_TAI THEN
            TlFUKA_KIJITSU_CNT_TAI := TlFUKA_KIJITSU_CNT_TAI + 1;   -- 退職賦課期日人員ｶｳﾝﾄup
          END IF;

          TlFUKA_KIJITSU_CNT := TlFUKA_KIJITSU_CNT + 1;   -- 全体賦課期日人員ｶｳﾝﾄup
        END IF;

        -- 《計算個人更新》
        BEGIN
          UPDATE ZLBTKOJIN_CAL SET
            R_NO                = c_R_NO,                    -- 履歴番号(10固定)
            SYS_SAKUSEIBI       = NlSYSDATE ,                -- 作成日
            SYS_KOSHINBI        = NlSYSDATE ,                -- 更新日
            SYS_JIKAN           = NlSYSTIME ,                -- 更新時間
            SYS_SHOKUINKOJIN_NO = NlSYS_SHOKUINKOJIN_NO ,    -- 更新職員個人番号
            SYS_TANMATSU_NO     = VlMASIN_NO                 -- 更新端末番号
          WHERE SYS_TANMATSU_NO = VlMASIN_NO
          ;
        EXCEPTION
          WHEN OTHERS THEN
            IwRTN        := c_NRTN_9;
            o_VlERRBUF   := 'ZLBTKOJIN_CAL 更新エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
        END;

        IF IwRTN = c_NRTN_0  THEN
          -- 《計算所得更新》
          BEGIN
            UPDATE ZLBTSHOTOKU_CAL SET
              R_NO                = c_R_NO,                    -- 履歴番号(10固定)
              TSUCHI_NO           = TlNUSHI_KOJIN_NO,          -- 通知書番号
              SYS_SAKUSEIBI       = NlSYSDATE ,                -- 作成日
              SYS_KOSHINBI        = NlSYSDATE ,                -- 更新日
              SYS_JIKAN           = NlSYSTIME ,                -- 更新時間
              SYS_SHOKUINKOJIN_NO = NlSYS_SHOKUINKOJIN_NO ,    -- 更新職員個人番号
              SYS_TANMATSU_NO     = VlMASIN_NO                 -- 更新端末番号
            WHERE SYS_TANMATSU_NO = VlMASIN_NO
            ;
          EXCEPTION
            WHEN OTHERS THEN
              IwRTN        := c_NRTN_9;
              o_VlERRBUF   := 'ZLBTSHOTOKU_CAL 更新エラー ' ||SQLCODE||SQLERRM
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
          END;
        END IF;

        IF IwRTN = c_NRTN_0  THEN
          -- 《計算基本更新》
          BEGIN
            UPDATE ZLBTKIHON_CAL SET
              R_NO                = c_R_NO,                    -- 履歴番号(10固定)
              FUKA_KIJITSU_CNT    = TlFUKA_KIJITSU_CNT ,       -- 全体賦課期日人員
              SYS_SAKUSEIBI       = NlSYSDATE ,                -- 作成日
              SYS_KOSHINBI        = NlSYSDATE ,                -- 更新日
              SYS_JIKAN           = NlSYSTIME ,                -- 更新時間
              SYS_SHOKUINKOJIN_NO = NlSYS_SHOKUINKOJIN_NO ,    -- 更新職員個人番号
              SYS_TANMATSU_NO     = VlMASIN_NO                 -- 更新端末番号
            WHERE SYS_TANMATSU_NO = VlMASIN_NO
            ;
          EXCEPTION
            WHEN OTHERS THEN
              IwRTN        := c_NRTN_9;
              o_VlERRBUF   := 'ZLBTKIHON_CAL 更新エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
          END;
        END IF;

        IF IwRTN = c_NRTN_0  THEN
          -- 《計算退職更新》
          BEGIN
            UPDATE ZLBTTAI_CAL SET
              R_NO                = c_R_NO,                    -- 履歴番号(10固定)
              FUKA_KIJITSU_CNT    = TlFUKA_KIJITSU_CNT_TAI ,   -- 退職賦課期日人員
              SYS_SAKUSEIBI       = NlSYSDATE ,                -- 作成日
              SYS_KOSHINBI        = NlSYSDATE ,                -- 更新日
              SYS_JIKAN           = NlSYSTIME ,                -- 更新時間
              SYS_SHOKUINKOJIN_NO = NlSYS_SHOKUINKOJIN_NO ,    -- 更新職員個人番号
              SYS_TANMATSU_NO     = VlMASIN_NO                 -- 更新端末番号
            WHERE SYS_TANMATSU_NO = VlMASIN_NO
            ;
          EXCEPTION
            WHEN OTHERS THEN
              IwRTN        := c_NRTN_9;
              o_VlERRBUF   := 'ZLBTTAI_CAL 更新エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
          END;
        END IF;

        IF IwRTN = c_NRTN_0  THEN
          -- 《計算拡張更新》
          BEGIN
            UPDATE ZLBTEXT_CAL SET
              R_NO                = c_R_NO,                    -- 履歴番号(10固定)
              SYS_SAKUSEIBI       = NlSYSDATE ,                -- 作成日
              SYS_KOSHINBI        = NlSYSDATE ,                -- 更新日
              SYS_JIKAN           = NlSYSTIME ,                -- 更新時間
              SYS_SHOKUINKOJIN_NO = NlSYS_SHOKUINKOJIN_NO ,    -- 更新職員個人番号
              SYS_TANMATSU_NO     = VlMASIN_NO                 -- 更新端末番号
            WHERE SYS_TANMATSU_NO = VlMASIN_NO
            ;
          EXCEPTION
            WHEN OTHERS THEN
              IwRTN        := c_NRTN_9;
              o_VlERRBUF   := 'ZLBTEXT_CAL 更新エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
          END;
        END IF;

        IF IwRTN = c_NRTN_0  THEN
          -- 全体均等人員＞0
          IF TlKINTO_CNT > 0 THEN
              -- 《証番号、旧自治体区分 取得》
              FOR CREC IN CKIGONO LOOP
                IOLD_JICHI_KBN := CREC.OLD_JICHI_KBN;
                VSHO_NO        := CREC.SHO_NO;
                EXIT;
              END LOOP;
              IF GAAPK0030.FGETATENA(NNUSHI_KOJIN_NO, 'ZLB', NlKIJUN_NENGAPPI, RATENA,RSOFU) = c_NRTN_0 THEN
                TlGYOSEIKU_CD         := RATENA.GYOSEIKU_CD;
              END IF;
          END IF;
        END IF;

        IF IwRTN = c_NRTN_0  THEN
          -- 全体均等人員＞0
          IF TlKINTO_CNT > 0 THEN

            -- 《H4基本登録》
            BEGIN
              INSERT INTO ZLBTKIHON_H4
                SELECT VSHO_NO, IOLD_JICHI_KBN, ZLBTKIHON_CAL.*, TlGYOSEIKU_CD FROM ZLBTKIHON_CAL
                WHERE SYS_TANMATSU_NO = VlMASIN_NO
              ;
            EXCEPTION
              WHEN OTHERS THEN
                IwRTN        := c_NRTN_9;
                o_VlERRBUF   := 'ZLBTKIHON_H4 登録エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
            END;

            IF IwRTN = c_NRTN_0  THEN

              -- 《H4退職登録》
              BEGIN
                INSERT INTO ZLBTTAI_H4 SELECT * FROM ZLBTTAI_CAL
                WHERE SYS_TANMATSU_NO = VlMASIN_NO
                ;
              EXCEPTION
                WHEN OTHERS THEN
                  IwRTN        := c_NRTN_9;
                  o_VlERRBUF   := 'ZLBTTAI_H4 登録エラー ' ||SQLCODE||SQLERRM
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
              END;

            END IF;

            IF IwRTN = c_NRTN_0  THEN

              -- 《H4所得登録》
              BEGIN
                INSERT INTO ZLBTSHOTOKU_H4 SELECT * FROM ZLBTSHOTOKU_CAL
                WHERE SYS_TANMATSU_NO = VlMASIN_NO
                ;
              EXCEPTION
                WHEN OTHERS THEN
                  IwRTN        := c_NRTN_9;
                  o_VlERRBUF   := 'ZLBTSHOTOKU_H4 登録エラー ' ||SQLCODE||SQLERRM
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
              END;

            END IF;

            IF IwRTN = c_NRTN_0  THEN

              -- 《H4個人登録》
              BEGIN
                INSERT INTO ZLBTKOJIN_H4
                  SELECT
                    VSHO_NO          ,
                    IOLD_JICHI_KBN   ,
                    KOKU_SETAI_NO    ,
                    KOJIN_NO         ,
                    SANTEIDANTAI_CD  ,
                    CHOTEI_NENDO     ,
                    NENDO_BUN        ,
                    R_NO             ,
                    TSUCHI_NO        ,
                    NEW_SHIK_KBN     ,
                    NEW_KAI_SHIK_KBN ,
                    NEW_TAI_KBN      ,
                    F4_SHIK_KBN      ,
                    F4_KAI_KBN       ,
                    F4_TAI_KBN       ,
                    FUKA_SHIK_KBN    ,
                    FUKA_KAI_KBN     ,
                    KEIGEN_HANT_KBN  ,
                    SHIK_4           ,
                    SHIK_5           ,
                    SHIK_6           ,
                    SHIK_7           ,
                    SHIK_8           ,
                    SHIK_9           ,
                    SHIK_10          ,
                    SHIK_11          ,
                    SHIK_12          ,
                    SHIK_1           ,
                    SHIK_2           ,
                    SHIK_3           ,
                    KAI_SHIK_4       ,
                    KAI_SHIK_5       ,
                    KAI_SHIK_6       ,
                    KAI_SHIK_7       ,
                    KAI_SHIK_8       ,
                    KAI_SHIK_9       ,
                    KAI_SHIK_10      ,
                    KAI_SHIK_11      ,
                    KAI_SHIK_12      ,
                    KAI_SHIK_1       ,
                    KAI_SHIK_2       ,
                    KAI_SHIK_3       ,
                    SHOTOKU          ,
                    KAHYO            ,
                    SHOTOKU_WARI     ,
                    KAI_SHOTOKU_WARI ,
                    SIEN_SHOTOKU_WARI,
                    KEIGEN_SHOTOKU   ,
                    SHISANZEI        ,
                    SHISAN_WARI      ,
                    KAI_SHISAN_WARI  ,
                    SIEN_SHISAN_WARI,
                    SENJU_KBN        ,
                    RONEN_KBN        ,
                    SHINKOKU_KBN     ,
                    SHU_SHOTOKU_KBN  ,
                    J_KAZEI_KBN      ,
                    J_SHOTOKU_WARI   ,
                    J_KINTO_WARI     ,
                    NEW_SHUTOK_BI    ,
                    NEW_SOSHITSU_BI  ,
                    NEW_ZOKU         ,
                    KAI_GAI_BI       ,
                    KAI_HIGAI_BI     ,
                    TANJO_65         ,
                    KOSEI_BI         ,
                    JIYU             ,
                    KAI_KOSEI_BI     ,
                    KAI_JIYU         ,
                    KEIGEN_BI        ,
                    SEKISAN_GAI_KBN  ,
                    KOJIN_NENZEI     ,
                    ZOKU_NAME        ,
                    SHIK_R_NO        ,
                    SYS_SAKUSEIBI    ,
                    SYS_KOSHINBI     ,
                    SYS_JIKAN        ,
                    SYS_SHOKUINKOJIN_NO  ,
                    SYS_TANMATSU_NO
                    ,NEW_SHITSU_KBN
                    ,F4_SHITSU_KBN
                    ,SHITSU_4
                    ,SHITSU_5
                    ,SHITSU_6
                    ,SHITSU_7
                    ,SHITSU_8
                    ,SHITSU_9
                    ,SHITSU_10
                    ,SHITSU_11
                    ,SHITSU_12
                    ,SHITSU_1
                    ,SHITSU_2
                    ,SHITSU_3
                    ,SHITSU_GAI_BI
                    ,SHITSU_HIGAI_BI
                    ,SHITSU_SHOTOKU
                    ,SHITSU_KAHYO
                    ,SHITSU_KEIGEN_SHOTOKU
                    ,KYUYO_SHOTOKU_KBN     --給与所得者等該当区分
--2024/05/07 ZCZL.LYF Add START 0.3.000.100:国保2次にマージ作業
                    ,NEW_SAN_KBN          -- 最新産前産後資格区分
                    ,F4_SAN_KBN           -- 賦課期日産前産後資格区分
                    ,SAN_4                -- 産前産後4月
                    ,SAN_5                -- 産前産後5月
                    ,SAN_6                -- 産前産後6月
                    ,SAN_7                -- 産前産後7月
                    ,SAN_8                -- 産前産後8月
                    ,SAN_9                -- 産前産後9月
                    ,SAN_10               -- 産前産後10月
                    ,SAN_11               -- 産前産後11月
                    ,SAN_12               -- 産前産後12月
                    ,SAN_1                -- 産前産後1月
                    ,SAN_2                -- 産前産後2月
                    ,SAN_3                -- 産前産後3月
                    ,SAN_GAI_BI           -- 産前産後該当日
                    ,SAN_HIGAI_BI         -- 産前産後非該当日
                    ,SAN_IRYO_GEN_KINTO   -- 医療産前産後均等割軽減額
                    ,SAN_IRYO_GEN_SHOTOKU -- 医療産前産後所得割軽減額
                    ,SAN_KAI_GEN_KINTO    -- 介護産前産後均等割軽減額
                    ,SAN_KAI_GEN_SHOTOKU  -- 介護産前産後所得割軽減額
                    ,SAN_SIEN_GEN_KINTO   -- 支援産前産後均等割軽減額
                    ,SAN_SIEN_GEN_SHOTOKU -- 支援産前産後所得割軽減額
--  2025/08/11 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
                    ,KDM_18_KBN  --子ども18歳以上該当区分
                    ,KDM_SHOTOKU_WARI --子ども所得割額
                    ,KDM_SHISAN_WARI --子ども資産割額
                    ,KDM_KEIGEN_KITO --子ども均等割軽減額
                    ,KDM_KEIGEN_KITO18 --子ども18歳以上均等割軽減額
                    ,KDM_SAN_GEN_KINTO --子ども産前産後均等割軽減額
                    ,KDM_SAN_GEN_SHOTOKU --子ども産前産後所得割軽減額
                    ,KDM_SAN_GEN_KINTO18 --子ども産前産後18歳以上均等割軽減額
                    ,KDM18UN_KEIGEN_KITO --子ども18歳未満均等割軽減額
--  2025/08/11 ZCZL.WANGMING ADD END
--2024/05/07 ZCZL.LYF Add END
--2025/12/03 ZCZL.XIESHUN ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
                    ,KDM_KODOMO_KEIGEN_KITO   -- 子ども均等割軽減額（未就学児）
                    ,KDM_KINTO                -- 子ども均等割額
                    ,KDM_KINTO18              -- 子ども18歳以上均等割額
--2025/12/03 ZCZL.XIESHUN ADD END
                  FROM ZLBTKOJIN_CAL
                  WHERE SYS_TANMATSU_NO = VlMASIN_NO
                ;
              EXCEPTION
                WHEN OTHERS THEN
                  IwRTN        := c_NRTN_9;
                  o_VlERRBUF   := 'ZLBTKIHON_H4 登録エラー ' ||SQLCODE||SQLERRM
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
              END;

            END IF;

            IF IwRTN = c_NRTN_0  THEN

              -- 《H4拡張登録》
              BEGIN
                INSERT INTO ZLBTEXT_H4 SELECT * FROM ZLBTEXT_CAL
                WHERE SYS_TANMATSU_NO = VlMASIN_NO
                ;
              EXCEPTION
                WHEN OTHERS THEN
                  IwRTN        := c_NRTN_9;
                  o_VlERRBUF   := 'ZLBTEXT_H4 登録エラー ' ||SQLCODE||SQLERRM
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
              END;

            END IF;
          END IF;
        END IF;

      END IF;    --年税額<>0if

    END IF;

    --<全体> ----------------------------------------------------------------↑

    --<介護> ----------------------------------------------------------------↓
    IF IwRTN = c_NRTN_0  THEN

      -- 計算介護基本,計算介護退職読込(1件しか登録されていない)
      BEGIN
        SELECT KAI_KIHON_CAL.GENZON_KBN
              ,KAI_KIHON_CAL.GISEI_KBN
              ,NVL(KAI_KIHON_CAL.FUKA_KIJITSU_CNT,0)
              ,NVL(KAI_KIHON_CAL.NENZEI,0)
              ,NVL(KAI_TAI_CAL.FUKA_KIJITSU_CNT,0)
              ,NVL(KAI_KIHON_CAL.KINTO_CNT,0)
        INTO   TlGENZON_KBN                  -- 現存区分
              ,TlGISEI_KBN                   -- 擬制区分
              ,TlFUKA_KIJITSU_CNT            -- 全体賦課期日人員
              ,TlNENZEI                      -- 全体年税額
              ,TlFUKA_KIJITSU_CNT_TAI        -- 退職賦課期日人員
              ,TlKINTO_CNT                   -- 全体均等人員

        FROM   ZLBTKAI_KIHON_CAL KAI_KIHON_CAL ,     -- 計算介護基本
               ZLBTKAI_TAI_CAL   KAI_TAI_CAL         -- 退職介護基本(無くてもok)
        WHERE  KAI_KIHON_CAL.KOKU_SETAI_NO     = KAI_TAI_CAL.KOKU_SETAI_NO(+)
        AND    KAI_KIHON_CAL.SANTEIDANTAI_CD   = KAI_TAI_CAL.SANTEIDANTAI_CD(+)
        AND    KAI_KIHON_CAL.CHOTEI_NENDO      = KAI_TAI_CAL.CHOTEI_NENDO(+)
        AND    KAI_KIHON_CAL.NENDO_BUN         = KAI_TAI_CAL.NENDO_BUN(+)
        AND    KAI_KIHON_CAL.TSUCHI_NO         = KAI_TAI_CAL.TSUCHI_NO(+)
        AND    KAI_KIHON_CAL.SYS_TANMATSU_NO   = VlMASIN_NO
        AND    KAI_TAI_CAL.SYS_TANMATSU_NO     = VlMASIN_NO
        ;
      EXCEPTION
        WHEN OTHERS THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := 'ZLBTKAI_KIHON_CAL 検索エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
      END;

      IF IwRTN = c_NRTN_0  THEN

        IF TlNENZEI != 0 THEN

          -- システム日付
          NlSYSDATE := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
          -- システム時間
          NlSYSTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MMSS'));

          -- 擬主を被保数に含めない,擬制世帯
          IF RJOKEN.GINUSHI_SHIRYO = c_GINUSHI_SHIRYO_NO AND
             TlGISEI_KBN = c_GISEI_KBN_GISEI THEN

            -- 全体賦課期日人員>0 AND
            -- 全体賦課期日人員 = 退職賦課期日人員
            IF TlFUKA_KIJITSU_CNT != 0 AND
               TlFUKA_KIJITSU_CNT = TlFUKA_KIJITSU_CNT_TAI THEN
              TlFUKA_KIJITSU_CNT_TAI := TlFUKA_KIJITSU_CNT_TAI + 1;   -- 退職賦課期日人員ｶｳﾝﾄup
            END IF;

            TlFUKA_KIJITSU_CNT := TlFUKA_KIJITSU_CNT + 1;   -- 全体賦課期日人員ｶｳﾝﾄup
          END IF;

          -- 《計算介護基本更新》
          BEGIN
            UPDATE ZLBTKAI_KIHON_CAL SET
              R_NO                = c_R_NO,                    -- 履歴番号(10固定)
              FUKA_KIJITSU_CNT    = TlFUKA_KIJITSU_CNT ,       -- 全体賦課期日人員
              SYS_SAKUSEIBI       = NlSYSDATE ,                -- 作成日
              SYS_KOSHINBI        = NlSYSDATE ,                -- 更新日
              SYS_JIKAN           = NlSYSTIME ,                -- 更新時間
              SYS_SHOKUINKOJIN_NO = NlSYS_SHOKUINKOJIN_NO ,    -- 更新職員個人番号
              SYS_TANMATSU_NO     = VlMASIN_NO                 -- 更新端末番号
            WHERE SYS_TANMATSU_NO = VlMASIN_NO
            ;
          EXCEPTION
            WHEN OTHERS THEN
              IwRTN        := c_NRTN_9;
              o_VlERRBUF   := 'ZLBTKAI_KIHON_CAL 更新エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
          END;

          IF IwRTN = c_NRTN_0  THEN
            -- 《計算介護退職更新》
            BEGIN
              UPDATE ZLBTKAI_TAI_CAL SET
                R_NO                = c_R_NO,                    -- 履歴番号(10固定)
                FUKA_KIJITSU_CNT    = TlFUKA_KIJITSU_CNT_TAI ,   -- 退職賦課期日人員
                SYS_SAKUSEIBI       = NlSYSDATE ,                -- 作成日
                SYS_KOSHINBI        = NlSYSDATE ,                -- 更新日
                SYS_JIKAN           = NlSYSTIME ,                -- 更新時間
                SYS_SHOKUINKOJIN_NO = NlSYS_SHOKUINKOJIN_NO ,    -- 更新職員個人番号
                SYS_TANMATSU_NO     = VlMASIN_NO                 -- 更新端末番号
              WHERE SYS_TANMATSU_NO = VlMASIN_NO
              ;
            EXCEPTION
              WHEN OTHERS THEN
                IwRTN        := c_NRTN_9;
                o_VlERRBUF   := 'ZLBTKAI_TAI_CAL 更新エラー ' ||SQLCODE||SQLERRM
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
            END;
          END IF;

          IF IwRTN = c_NRTN_0  THEN
            -- 全体均等人員＞0
            IF TlKINTO_CNT > 0 THEN

              -- 《H4介護基本登録》
              BEGIN
                INSERT INTO ZLBTKAI_KIHON_H4
                  SELECT VSHO_NO, IOLD_JICHI_KBN, ZLBTKAI_KIHON_CAL.* FROM ZLBTKAI_KIHON_CAL
                  WHERE SYS_TANMATSU_NO = VlMASIN_NO
                ;
              EXCEPTION
                WHEN OTHERS THEN
                  IwRTN        := c_NRTN_9;
                  o_VlERRBUF   := 'ZLBTKAI_KIHON_H4 登録エラー ' ||SQLCODE||SQLERRM
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
              END;

              IF IwRTN = c_NRTN_0  THEN

                -- 《H4介護退職登録》
                BEGIN
                  INSERT INTO ZLBTKAI_TAI_H4 SELECT * FROM ZLBTKAI_TAI_CAL
                  WHERE SYS_TANMATSU_NO = VlMASIN_NO
                  ;
                EXCEPTION
                  WHEN OTHERS THEN
                    IwRTN        := c_NRTN_9;
                    o_VlERRBUF   := 'ZLBTKAI_TAI_H4 登録エラー ' ||SQLCODE||SQLERRM
                            ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
                END;

              END IF;

            END IF;
          END IF;

        END IF;    --年税額<>0if
      END IF;

    END IF;
    --<介護> ----------------------------------------------------------------↑
    --<支援> ----------------------------------------------------------------↓
    IF IwRTN = c_NRTN_0  THEN

      -- 計算支援基本,計算支援退職読込(1件しか登録されていない)
      BEGIN
        SELECT SIEN_KIHON_CAL.GENZON_KBN
              ,SIEN_KIHON_CAL.GISEI_KBN
              ,NVL(SIEN_KIHON_CAL.FUKA_KIJITSU_CNT,0)
              ,NVL(SIEN_KIHON_CAL.NENZEI,0)
              ,NVL(SIEN_TAI_CAL.FUKA_KIJITSU_CNT,0)
              ,NVL(SIEN_KIHON_CAL.KINTO_CNT,0)
        INTO   TlGENZON_KBN                  -- 現存区分
              ,TlGISEI_KBN                   -- 擬制区分
              ,TlFUKA_KIJITSU_CNT            -- 全体賦課期日人員
              ,TlNENZEI                      -- 全体年税額
              ,TlFUKA_KIJITSU_CNT_TAI        -- 退職賦課期日人員
              ,TlKINTO_CNT                   -- 全体均等人員

        FROM   ZLBTSIEN_KIHON_CAL SIEN_KIHON_CAL ,     -- 計算支援基本
               ZLBTSIEN_TAI_CAL   SIEN_TAI_CAL         -- 退職支援基本(無くてもok)
        WHERE  SIEN_KIHON_CAL.KOKU_SETAI_NO     = SIEN_TAI_CAL.KOKU_SETAI_NO(+)
        AND    SIEN_KIHON_CAL.SANTEIDANTAI_CD   = SIEN_TAI_CAL.SANTEIDANTAI_CD(+)
        AND    SIEN_KIHON_CAL.CHOTEI_NENDO      = SIEN_TAI_CAL.CHOTEI_NENDO(+)
        AND    SIEN_KIHON_CAL.NENDO_BUN         = SIEN_TAI_CAL.NENDO_BUN(+)
        AND    SIEN_KIHON_CAL.TSUCHI_NO         = SIEN_TAI_CAL.TSUCHI_NO(+)
        AND    SIEN_KIHON_CAL.SYS_TANMATSU_NO   = VlMASIN_NO
        AND    SIEN_TAI_CAL.SYS_TANMATSU_NO     = VlMASIN_NO
        ;
      EXCEPTION
        WHEN OTHERS THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := 'ZLBTSIEN_KIHON_CAL 検索エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
      END;

      IF IwRTN = c_NRTN_0  THEN

        IF TlNENZEI != 0 THEN

          -- システム日付
          NlSYSDATE := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
          -- システム時間
          NlSYSTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MMSS'));

          -- 擬主を被保数に含めない,擬制世帯
          IF RJOKEN.GINUSHI_SHIRYO = c_GINUSHI_SHIRYO_NO AND
             TlGISEI_KBN = c_GISEI_KBN_GISEI THEN

            -- 全体賦課期日人員>0 AND
            -- 全体賦課期日人員 = 退職賦課期日人員
            IF TlFUKA_KIJITSU_CNT != 0 AND
               TlFUKA_KIJITSU_CNT = TlFUKA_KIJITSU_CNT_TAI THEN
              TlFUKA_KIJITSU_CNT_TAI := TlFUKA_KIJITSU_CNT_TAI + 1;   -- 退職賦課期日人員ｶｳﾝﾄup
            END IF;

            TlFUKA_KIJITSU_CNT := TlFUKA_KIJITSU_CNT + 1;   -- 全体賦課期日人員ｶｳﾝﾄup
          END IF;

          -- 《計算支援基本更新》
          BEGIN
            UPDATE ZLBTSIEN_KIHON_CAL SET
              R_NO                = c_R_NO,                    -- 履歴番号(10固定)
              FUKA_KIJITSU_CNT    = TlFUKA_KIJITSU_CNT ,       -- 全体賦課期日人員
              SYS_SAKUSEIBI       = NlSYSDATE ,                -- 作成日
              SYS_KOSHINBI        = NlSYSDATE ,                -- 更新日
              SYS_JIKAN           = NlSYSTIME ,                -- 更新時間
              SYS_SHOKUINKOJIN_NO = NlSYS_SHOKUINKOJIN_NO ,    -- 更新職員個人番号
              SYS_TANMATSU_NO     = VlMASIN_NO                 -- 更新端末番号
            WHERE SYS_TANMATSU_NO = VlMASIN_NO
            ;
          EXCEPTION
            WHEN OTHERS THEN
              IwRTN        := c_NRTN_9;
              o_VlERRBUF   := 'ZLBTSIEN_KIHON_CAL 更新エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
          END;

          IF IwRTN = c_NRTN_0  THEN
            -- 《計算支援退職更新》
            BEGIN
              UPDATE ZLBTSIEN_TAI_CAL SET
                R_NO                = c_R_NO,                    -- 履歴番号(10固定)
                FUKA_KIJITSU_CNT    = TlFUKA_KIJITSU_CNT_TAI ,   -- 退職賦課期日人員
                SYS_SAKUSEIBI       = NlSYSDATE ,                -- 作成日
                SYS_KOSHINBI        = NlSYSDATE ,                -- 更新日
                SYS_JIKAN           = NlSYSTIME ,                -- 更新時間
                SYS_SHOKUINKOJIN_NO = NlSYS_SHOKUINKOJIN_NO ,    -- 更新職員個人番号
                SYS_TANMATSU_NO     = VlMASIN_NO                 -- 更新端末番号
              WHERE SYS_TANMATSU_NO = VlMASIN_NO
              ;
            EXCEPTION
              WHEN OTHERS THEN
                IwRTN        := c_NRTN_9;
                o_VlERRBUF   := 'ZLBTSIEN_TAI_CAL 更新エラー ' ||SQLCODE||SQLERRM
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
            END;
          END IF;

          IF IwRTN = c_NRTN_0  THEN
            -- 全体均等人員＞0
            IF TlKINTO_CNT > 0 THEN

              -- 《H4支援基本登録》
              BEGIN
                INSERT INTO ZLBTSIEN_KIHON_H4
                  SELECT VSHO_NO, IOLD_JICHI_KBN, ZLBTSIEN_KIHON_CAL.* FROM ZLBTSIEN_KIHON_CAL
                  WHERE SYS_TANMATSU_NO = VlMASIN_NO
                ;
              EXCEPTION
                WHEN OTHERS THEN
                  IwRTN        := c_NRTN_9;
                  o_VlERRBUF   := 'ZLBTSIEN_KIHON_H4 登録エラー ' ||SQLCODE||SQLERRM
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
              END;

              IF IwRTN = c_NRTN_0  THEN

                -- 《H4支援退職登録》
                BEGIN
                  INSERT INTO ZLBTSIEN_TAI_H4 SELECT * FROM ZLBTSIEN_TAI_CAL
                  WHERE SYS_TANMATSU_NO = VlMASIN_NO
                  ;
                EXCEPTION
                  WHEN OTHERS THEN
                    IwRTN        := c_NRTN_9;
                    o_VlERRBUF   := 'ZLBTSIEN_TAI_H4 登録エラー ' ||SQLCODE||SQLERRM
                            ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
                END;

              END IF;

            END IF;
          END IF;

        END IF;    --年税額<>0if
      END IF;

    END IF;
    --<支援> ----------------------------------------------------------------↑

--  2025/08/11 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
    IF IwRTN = c_NRTN_0  THEN
      --「退職賦課期日人員（TlFUKA_KIJITSU_CNT_TAI）=0」を設定
      TlFUKA_KIJITSU_CNT_TAI := 0;
      --計算子ども基本読込
      BEGIN
        SELECT GENZON_KBN
              ,GISEI_KBN
              ,NVL(FUKA_KIJITSU_CNT, 0)
              ,NVL(NENZEI, 0)
              ,NVL(KINTO_CNT, 0)
        INTO   TlGENZON_KBN                  -- 現存区分
              ,TlGISEI_KBN                   -- 擬制区分
              ,TlFUKA_KIJITSU_CNT            -- 賦課期日人員
              ,TlNENZEI                      -- 年税額
              ,TlKINTO_CNT                   -- 均等人員

        FROM   ZLBTKDM_KIHON_CAL             -- 計算子ども基本
        WHERE  SYS_TANMATSU_NO   = VlMASIN_NO;
      EXCEPTION
        WHEN OTHERS THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := 'ZLBTKDM_KIHON_CAL 検索エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
      END;
      IF IwRTN = c_NRTN_0  THEN
        --全体年税額 ≠ 0 の場合
        IF TlNENZEI != 0 THEN
          -- システム日付
          NlSYSDATE := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
          -- システム時間
          NlSYSTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MMSS'));
          -- 擬主を被保数に含めない,擬制世帯
          -- 資料用擬主が(1:擬主を被保数に含めない）　かつ　擬制区分が(1:擬制世帯）の場合
          IF RJOKEN.GINUSHI_SHIRYO = c_GINUSHI_SHIRYO_NO AND
             TlGISEI_KBN = c_GISEI_KBN_GISEI THEN

            TlFUKA_KIJITSU_CNT := TlFUKA_KIJITSU_CNT + 1;   -- 全体賦課期日人員ｶｳﾝﾄup
          END IF;
          -- 《計算子ども基本更新》
          BEGIN
            UPDATE ZLBTKDM_KIHON_CAL SET
              R_NO                = c_R_NO,                    -- 履歴番号(10固定)
              FUKA_KIJITSU_CNT    = TlFUKA_KIJITSU_CNT ,       -- 全体賦課期日人員
              SYS_SAKUSEIBI       = NlSYSDATE ,                -- 作成日
              SYS_KOSHINBI        = NlSYSDATE ,                -- 更新日
              SYS_JIKAN           = NlSYSTIME ,                -- 更新時間
              SYS_SHOKUINKOJIN_NO = NlSYS_SHOKUINKOJIN_NO ,    -- 更新職員個人番号
              SYS_TANMATSU_NO     = VlMASIN_NO                 -- 更新端末番号
            WHERE SYS_TANMATSU_NO = VlMASIN_NO;
          EXCEPTION
            WHEN OTHERS THEN
              IwRTN        := c_NRTN_9;
              o_VlERRBUF   := 'ZLBTKDM_KIHON_CAL 更新エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
          END;
          --上記③-4-5戻り値　= 固定値「0：正常」の場合
          IF IwRTN = c_NRTN_0  THEN
            -- 全体均等人員＞0
            IF TlKINTO_CNT > 0 THEN
                -- 《H4子ども基本登録》
                BEGIN
                  INSERT INTO
                       ZLBTKDM_KIHON_H4
                  SELECT
                       VSHO_NO
                      ,IOLD_JICHI_KBN
                      ,A.*
                  FROM
                       ZLBTKDM_KIHON_CAL A
                  WHERE
                       SYS_TANMATSU_NO = VlMASIN_NO;
                EXCEPTION
                  WHEN OTHERS THEN
                    IwRTN        := c_NRTN_9;
                    o_VlERRBUF   := 'ZLBTKDM_KIHON_H4 登録エラー ' ||SQLCODE||SQLERRM
                            ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
                END;
            END IF;
          END IF;
        END IF;
      END IF;
    END IF;
--  2025/08/11 ZCZL.WANGMING ADD END

    RETURN( IwRTN );

END FUNCUPDATE ;

------------------------------------------------------------------------------
--  04 課税計算                                                             --
------------------------------------------------------------------------------
FUNCTION FUNCKIHON_SYORI( i_KOKU_SETAI_NO   IN  NUMBER
                         ,i_SANTEIDANTAI_CD IN  NUMBER
                         ,o_VlERRBUF        OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN            PLS_INTEGER;          -- 戻り値
    -- ダミー（実態調査[世帯票]でのみ使用のため）
    NwDUMMY         NUMBER;

  BEGIN

    -- 初期化
    IwRTN := c_NRTN_0;

    -- 08 世帯主取得
    IwRTN := FUNC_GET_NUSHI( i_KOKU_SETAI_NO
                            ,TlNUSHI_KOJIN_NO    -- 最新の世帯主取得
                            ,VlERRBUF );

    IF IwRTN != c_NRTN_0  THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := ' FUNC_GET_NUSHI 世帯主取得' || VlERRBUF
                      ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
    END IF;

    -- ※ZLBSKCALMAIN,ZLBSKCALMKAIの抽出条件に、通知書番号＝世帯主個人番号が
    --   がある為、更新しておく

    IF IwRTN = c_NRTN_0  THEN

      -- 《計算個人更新》
      BEGIN
        UPDATE ZLBTKOJIN_CAL SET
          TSUCHI_NO           = TlNUSHI_KOJIN_NO                  -- 通知書番号
        WHERE SYS_TANMATSU_NO = VlMASIN_NO
        ;
      EXCEPTION
        WHEN OTHERS THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := 'ZLBTKOJIN_CAL 更新エラー ' ||SQLCODE||SQLERRM
                      ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
      END;

    END IF;

    IF IwRTN = c_NRTN_0  THEN

      -- 《計算軽減判定日削除・登録》
      BEGIN

        DELETE FROM ZLBTKEIGENHANTEI_CAL
         WHERE SYS_TANMATSU_NO = VlMASIN_NO;

        INSERT INTO ZLBTKEIGENHANTEI_CAL (KOKU_SETAI_NO
                                         ,HANTEI_4
                                         ,SYS_TANMATSU_NO)
                                  VALUES (i_KOKU_SETAI_NO
                                         ,NlCHOTEI_NENDO * 10000 + 0401
                                         ,VlMASIN_NO);

        -- 軽減判定
        ZLBSKCALKG(i_KOKU_SETAI_NO,    -- IN:国保世帯番号
                      i_SANTEIDANTAI_CD,  -- IN:算定団体コード
-- I/F変更対応
                      TlNUSHI_KOJIN_NO,   -- IN:世帯主個人番号
                      NlCHOTEI_NENDO,     -- IN:調定年度
                      NlNENDO_BUN,        -- IN:年度分
                      c_JIKKOU_KBN_BA,    -- IN:実行区分
                      VlMASIN_NO,         -- IN:端末番号
                      NlNTRENBAN,         -- IN:登録連番
                      IwRTN,              -- 軽減判定(0:OK 9:NG)
                      NwDUMMY);           -- ダミー（実態調査[世帯票]でのみ使用）

      EXCEPTION
        WHEN OTHERS THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := 'ZLBTKEIGENHANTEI_CAL 削除/登録エラー ' ||SQLCODE||SQLERRM
                      ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
      END;
    END IF;

    IF IwRTN = c_NRTN_0  THEN

      -- 被扶養者判定(計算緩和個人TBL作成・更新)
      ZLBSKCLKWR(i_KOKU_SETAI_NO,    -- IN:国保世帯番号
                        i_SANTEIDANTAI_CD,  -- IN:算定団体コード
                        TlNUSHI_KOJIN_NO,   -- IN:世帯主個人番号
                        NlCHOTEI_NENDO,     -- IN:調定年度
                        NlNENDO_BUN,        -- IN:年度分
                        c_JIKKOU_KBN_BA,    -- IN:実行区分
                        VlMASIN_NO,         -- IN:端末番号
                        NlNTRENBAN,         -- IN:登録連番
                        1,                  -- 処理モード(1:基準日時点[H4/HH/C4])
                        NlCHOTEI_NENDO * 10000 + 0401, -- 判定基準日
                        IwRTN);

      IF IwRTN != c_NRTN_0  THEN
        IwRTN        := c_NRTN_9;
        o_VlERRBUF   := ' ZLBSKCLKWR 被扶養者判定' || VlERRBUF
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
      END IF;

      IF IwRTN = c_NRTN_0  THEN
        -- 《計算緩和個人更新》
        BEGIN

        UPDATE ZLBTKANWA_KOJIN_CAL
        SET OUNOU_5 =OUNOU_4, OUNOU_6 =OUNOU_4, OUNOU_7 =OUNOU_4,
            OUNOU_8 =OUNOU_4, OUNOU_9 =OUNOU_4, OUNOU_10=OUNOU_4,
            OUNOU_11=OUNOU_4, OUNOU_12=OUNOU_4, OUNOU_1 =OUNOU_4,
            OUNOU_2 =OUNOU_4, OUNOU_3 =OUNOU_4,
            OUEKI_5 =OUEKI_4, OUEKI_6 =OUEKI_4, OUEKI_7 =OUEKI_4,
            OUEKI_8 =OUEKI_4, OUEKI_9 =OUEKI_4, OUEKI_10=OUEKI_4,
            OUEKI_11=OUEKI_4, OUEKI_12=OUEKI_4, OUEKI_1 =OUEKI_4,
            OUEKI_2 =OUEKI_4, OUEKI_3 =OUEKI_4
        WHERE SYS_TANMATSU_NO = VlMASIN_NO
        ;
        EXCEPTION
          WHEN OTHERS THEN
            IwRTN        := c_NRTN_9;
            o_VlERRBUF   := 'ZLBTKANWA_KOJIN_CAL 更新エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
        END;
      END IF;

      IF IwRTN = c_NRTN_0  THEN

        -- 被扶養者判定(計算緩和世帯TBL作成・更新)
        ZLBSKCALKWST(
                          i_KOKU_SETAI_NO,    -- IN:国保世帯番号
                          i_SANTEIDANTAI_CD,  -- IN:算定団体コード
                          TlNUSHI_KOJIN_NO,   -- IN:世帯主個人番号
                          NlCHOTEI_NENDO,     -- IN:調定年度
                          NlNENDO_BUN,        -- IN:年度分
                          c_JIKKOU_KBN_BA,    -- IN:実行区分
                          VlMASIN_NO,         -- IN:端末番号
                          NlNTRENBAN,         -- IN:登録連番
                          1,                  -- 処理モード(1:基準日時点[H4/HH/C4])
                          NlCHOTEI_NENDO * 10000 + 0401, -- 判定基準日
                          IwRTN);

        IF IwRTN != c_NRTN_0  THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := ' ZLBSKCALKWST 被扶養者判定' || VlERRBUF
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
        END IF;
      END IF;

      IF IwRTN = c_NRTN_0  THEN
        -- 《計算緩和世帯更新》
        BEGIN

          UPDATE ZLBTKANWA_SETAI_CAL
          SET OUEKI_5 =OUEKI_4, OUEKI_6 =OUEKI_4, OUEKI_7 =OUEKI_4,
              OUEKI_8 =OUEKI_4, OUEKI_9 =OUEKI_4, OUEKI_10=OUEKI_4,
              OUEKI_11=OUEKI_4, OUEKI_12=OUEKI_4, OUEKI_1 =OUEKI_4,
              OUEKI_2 =OUEKI_4, OUEKI_3 =OUEKI_4
             ,TAISHO_KBN_5 = TAISHO_KBN_4, TAISHO_KBN_6 = TAISHO_KBN_4
             ,TAISHO_KBN_7 = TAISHO_KBN_4, TAISHO_KBN_8 = TAISHO_KBN_4
             ,TAISHO_KBN_9 = TAISHO_KBN_4, TAISHO_KBN_10= TAISHO_KBN_4
             ,TAISHO_KBN_11= TAISHO_KBN_4, TAISHO_KBN_12= TAISHO_KBN_4
             ,TAISHO_KBN_1 = TAISHO_KBN_4, TAISHO_KBN_2 = TAISHO_KBN_4
             ,TAISHO_KBN_3 = TAISHO_KBN_4
          WHERE SYS_TANMATSU_NO = VlMASIN_NO
          ;
        EXCEPTION
          WHEN OTHERS THEN
            IwRTN        := c_NRTN_9;
            o_VlERRBUF   := 'ZLBTKANWA_SETAI_CAL 更新エラー ' ||SQLCODE||SQLERRM
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
        END;
      END IF;
    END IF;

    IF IwRTN = c_NRTN_0  THEN

      -- 計算基本作成
      ZLBSKCALMAIN(NlCHOTEI_NENDO,     -- IN:調定年度
                  NlNENDO_BUN,        -- IN:年度分
                  i_KOKU_SETAI_NO,    -- IN:国保世帯番号
                  i_SANTEIDANTAI_CD,  -- IN:算定団体コード
                  TlNUSHI_KOJIN_NO,   -- IN:世帯主個人番号
                  c_JIKKOU_KBN_BA,    -- IN:実行区分
                  c_CAL_KBN_F4,       -- IN:呼出区分
                  VlMASIN_NO,         -- IN:端末番号
                  NlNTRENBAN,         -- IN:登録連番
                  IwRTN);

      IF IwRTN != c_NRTN_0  THEN
        IwRTN        := c_NRTN_9;
        o_VlERRBUF   := ' ZLBSKCALMAIN 計算基本作成' || VlERRBUF
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
      END IF;

    END IF;

    IF IwRTN = c_NRTN_0  THEN

      -- 計算介護基本作成
      ZLBSKCALMKAI(NlCHOTEI_NENDO,  -- IN:調定年度
                    NlNENDO_BUN,        -- IN:年度分
                    i_KOKU_SETAI_NO,    -- IN:国保世帯番号
                    i_SANTEIDANTAI_CD,  -- IN:算定団体コード
                    TlNUSHI_KOJIN_NO,   -- IN:世帯主個人番号
                    c_JIKKOU_KBN_BA,    -- IN:実行区分
                    c_CAL_KBN_F4,       -- IN:呼出区分
                    VlMASIN_NO,         -- IN:端末番号
                    NlNTRENBAN,         -- IN:登録連番
                    IwRTN);

      IF IwRTN != c_NRTN_0  THEN
        IwRTN        := c_NRTN_9;
        o_VlERRBUF   := ' ZLBSKCALMKAI 計算介護基本作成' || VlERRBUF
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
      END IF;

    END IF;

    IF IwRTN = c_NRTN_0  THEN

      -- 計算支援基本作成
      ZLBSKCALMSIN(NlCHOTEI_NENDO,  -- IN:調定年度
                     NlNENDO_BUN,        -- IN:年度分
                     i_KOKU_SETAI_NO,    -- IN:国保世帯番号
                     i_SANTEIDANTAI_CD,  -- IN:算定団体コード
                     TlNUSHI_KOJIN_NO,   -- IN:世帯主個人番号
                     c_JIKKOU_KBN_BA,    -- IN:実行区分
                     c_CAL_KBN_F4,       -- IN:呼出区分
                     VlMASIN_NO,         -- IN:端末番号
                     NlNTRENBAN,         -- IN:登録連番
                     IwRTN);

      IF IwRTN != c_NRTN_0  THEN
        IwRTN        := c_NRTN_9;
        o_VlERRBUF   := ' ZLBSKCALMSIN 計算支援基本作成' || VlERRBUF
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
      END IF;

    END IF;

--  2025/08/11 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
    IF IwRTN = c_NRTN_0  THEN

      -- 計算子育て基本作成
      ZLBSKCALMKDM(NlCHOTEI_NENDO,       -- IN:調定年度
                     NlNENDO_BUN,        -- IN:年度分
                     i_KOKU_SETAI_NO,    -- IN:国保世帯番号
                     i_SANTEIDANTAI_CD,  -- IN:算定団体コード
                     TlNUSHI_KOJIN_NO,   -- IN:世帯主個人番号
                     c_JIKKOU_KBN_BA,    -- IN:実行区分
                     c_CAL_KBN_F4,       -- IN:呼出区分
                     VlMASIN_NO,         -- IN:端末番号
                     NlNTRENBAN,         -- IN:登録連番
                     IwRTN);

      IF IwRTN != c_NRTN_0  THEN
        IwRTN        := c_NRTN_9;
        o_VlERRBUF   := ' ZLBSKCALMKDM 計算子育て基本作成' || VlERRBUF
                        ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
      END IF;

    END IF;
--  2025/08/11 ZCZL.WANGMING ADD END
    IF IwRTN = c_NRTN_0  THEN

      -- 05 更新処理
      IwRTN := FUNCUPDATE( i_KOKU_SETAI_NO
                          ,VlERRBUF );

      COMMIT;

        IF IwRTN != c_NRTN_0  THEN
          IwRTN        := c_NRTN_9;
          o_VlERRBUF   := ' FUNCUPDATE 更新処理' || VlERRBUF
                          ||' 国保世帯番号='||i_KOKU_SETAI_NO ;
        END IF;

    END IF;


    RETURN( IwRTN );

END FUNCKIHON_SYORI ;

------------------------------------------------------------------------------
--  03 各計算TBLの内容クリア                                                --
------------------------------------------------------------------------------
FUNCTION FUNCCALCLR( o_VlERRBUF OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN            PLS_INTEGER;          -- 戻り値

  BEGIN

    IwRTN := c_NRTN_0;

    DELETE FROM ZLBTKIHON_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;          -- 計算基本
    DELETE FROM ZLBTTAI_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;            -- 計算退職
    DELETE FROM ZLBTKAI_KIHON_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;      -- 計算介護基本
    DELETE FROM ZLBTKAI_TAI_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;        -- 計算介護退職
    DELETE FROM ZLBTKOJIN_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;          -- 計算個人
    DELETE FROM ZLBTSHOTOKU_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;        -- 計算所得
    DELETE FROM ZLBTSIEN_KIHON_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;     -- 計算支援基本
    DELETE FROM ZLBTSIEN_TAI_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;       -- 計算支援退職
    DELETE FROM ZLBTEXT_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;            -- 計算拡張
    DELETE FROM ZLBTKANWA_KOJIN_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;    -- 計算緩和個人
    DELETE FROM ZLBTKANWA_SETAI_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;    -- 計算緩和世帯
        BEGIN
          vSQL := 'DELETE FROM ZLBTGENMEN_KOJIN_CAL WHERE SYS_TANMATSU_NO = ''' || VlMASIN_NO || '''';  -- 計算減免個人
          EXECUTE IMMEDIATE vSQL;
        EXCEPTION
          WHEN OTHERS THEN
            -- テーブルがないことも考えられるので、エラーにはしない。
            NULL;
        END;
--  2025/08/11 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
    DELETE FROM ZLBTKDM_KIHON_CAL WHERE SYS_TANMATSU_NO = VlMASIN_NO;      -- 計算子ども基本
    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNCCALCLR ;

------------------------------------------------------------------------------
--  02 各H4TBLの内容クリア                                                  --
------------------------------------------------------------------------------
FUNCTION FUNCH4CLR( o_VlERRBUF OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN            PLS_INTEGER;          -- 戻り値

  BEGIN

    IwRTN := c_NRTN_0;

    IwRTN := KKAPK3000.FTRUNCATE('ZLBTKIHON_H4', o_VlERRBUF);        -- H4基本

    IF IwRTN = c_NRTN_0 THEN
      IwRTN := KKAPK3000.FTRUNCATE('ZLBTTAI_H4', o_VlERRBUF);        -- H4退職
    END IF;
    IF IwRTN = c_NRTN_0 THEN
      IwRTN := KKAPK3000.FTRUNCATE('ZLBTKAI_KIHON_H4', o_VlERRBUF);  -- H4介護基本
    END IF;
    IF IwRTN = c_NRTN_0 THEN
      IwRTN := KKAPK3000.FTRUNCATE('ZLBTKAI_TAI_H4', o_VlERRBUF);    -- H4介護退職
    END IF;
    IF IwRTN = c_NRTN_0 THEN
      IwRTN := KKAPK3000.FTRUNCATE('ZLBTKOJIN_H4', o_VlERRBUF);      -- H4個人
    END IF;
    IF IwRTN = c_NRTN_0 THEN
      IwRTN := KKAPK3000.FTRUNCATE('ZLBTSHOTOKU_H4', o_VlERRBUF);     -- H4所得
    END IF;
    IF IwRTN = c_NRTN_0 THEN
      IwRTN := KKAPK3000.FTRUNCATE('ZLBTSIEN_KIHON_H4', o_VlERRBUF);  -- H4支援基本
    END IF;
    IF IwRTN = c_NRTN_0 THEN
      IwRTN := KKAPK3000.FTRUNCATE('ZLBTSIEN_TAI_H4', o_VlERRBUF);    -- H4支援退職
    END IF;
    IF IwRTN = c_NRTN_0 THEN
      IwRTN := KKAPK3000.FTRUNCATE('ZLBTEXT_H4', o_VlERRBUF);         -- H4拡張
    END IF;
--  2025/08/11 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
    IF IwRTN = c_NRTN_0 THEN
      IwRTN := KKAPK3000.FTRUNCATE('ZLBTKDM_KIHON_H4', o_VlERRBUF);   -- H4拡張
    END IF;
--  2025/08/11 ZCZL.WANGMING ADD END

    IF IwRTN != c_NRTN_0 THEN
      IwRTN        := c_NRTN_9;
    END IF;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNCH4CLR ;

------------------------------------------------------------------------------
--  01 システム条件読み込み                                                 --
------------------------------------------------------------------------------
FUNCTION JYOKEN_READ(
                     i_NENDO   IN  NUMBER,           -- 年度
                     i_SANTEIDANTAI_CD   IN  NUMBER, -- 算定団体コード
                     o_VlERRBUF OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN            PLS_INTEGER;          -- 戻り値

  BEGIN
    IwRTN    := 0;

    -- ▼算定団体コード＝1固定で読込、不均一課税フラグ取得
    BEGIN
      SELECT   * INTO RJOKEN
      FROM     ZLBTJOKEN
      WHERE    NENDO           =  i_NENDO
        AND    SANTEIDANTAI_CD =  c_SANTEIDANTAI_CD
      ;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        IwRTN       := c_NRTN_9;
        o_VlERRBUF  := 'システム条件該当データ無し'
                       || ' 算定団体コード＝' || c_SANTEIDANTAI_CD ;
      WHEN OTHERS THEN
        IwRTN       := c_NRTN_9;
        o_VlERRBUF  := 'システム条件該当読込エラー ' ||SQLCODE||SQLERRM
                       || ' 算定団体コード＝' || c_SANTEIDANTAI_CD ;
    END;

    IF IwRTN  = c_NRTN_0   THEN

      -- 不均一課税する
      IF RJOKEN.FUKI_KAZEI = c_FUKI_KAZEI_YES THEN

        -- ▼算定団体コード指定で読込
        BEGIN
          SELECT   * INTO RJOKEN
          FROM     ZLBTJOKEN
          WHERE    NENDO           =  i_NENDO
            AND    SANTEIDANTAI_CD =  i_SANTEIDANTAI_CD
          ;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            IwRTN       := c_NRTN_9;
            o_VlERRBUF  := 'システム条件該当データ無し'
                           || ' 算定団体コード＝' || i_SANTEIDANTAI_CD ;
          WHEN OTHERS THEN
            IwRTN       := c_NRTN_9;
            o_VlERRBUF  := 'システム条件該当読込エラー ' ||SQLCODE||SQLERRM
                           || ' 算定団体コード＝' || i_SANTEIDANTAI_CD ;
        END;

      END IF;
    END IF;

    RETURN( IwRTN );

END JYOKEN_READ ;

------------------------------------------------------------------------------
--  00 メイン処理                                                           --
------------------------------------------------------------------------------
BEGIN

    -- 初期処理
    IlRTN       := 0 ;
    TlSANTEIDANTAI_CD  := NULL;
    TlKOKU_SETAI_NO    := NULL;

    NlCNT_MAIN  := 0;    -- 処理件数カウント

    -- パラメータ→変数
    NlCHOTEI_NENDO         :=  i_CHOTEI_NENDO;
    NlNENDO_BUN            :=  i_NENDO_BUN;
    NlSYS_SHOKUINKOJIN_NO  :=  i_SYS_SHOKUINKOJIN_NO;
    NlKIJUN_NENGAPPI       :=  i_KIJUN_NENGAPPI;
    VlMASIN_NO             :=  i_MASIN_NO;
    NlNTRENBAN             :=  i_NTRENBAN;


    -- 02 各H4TBLの内容クリア
    IlRTN := FUNCH4CLR( VlERRBUF );

    IF IlRTN != c_NRTN_0 THEN
      -- ログ出力
      BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSCH4CALPACK', 1, '', '',' JZLBSCH4CALPACK FUNCMIDCLR 各H4TBLの内容クリア失敗 ' ||VlERRBUF, i_SYS_SHOKUINKOJIN_NO, i_MASIN_NO);
    END IF;

    IF IlRTN = c_NRTN_0 THEN

      -- 03 各計算TBLの内容クリア
      IlRTN := FUNCCALCLR( VlERRBUF );

      IF IlRTN != c_NRTN_0 THEN
        -- ログ出力
        BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSCH4CALPACK', 1, '', '',' ZLBSCH4CALPACK FUNCCALCLR 各計算TBLの内容クリア失敗 ' ||VlERRBUF, i_SYS_SHOKUINKOJIN_NO, i_MASIN_NO);
      END IF;
    END IF;

    IF IlRTN = c_NRTN_0 THEN

      -- 賦課個人データ読み込み
      OPEN CKOJIN_MID ;    -----------------------------------------------------↓

      LOOP

        -- データ値　取得
        FETCH CKOJIN_MID INTO RKOJIN_MID ;

        EXIT WHEN CKOJIN_MID%NOTFOUND ;        -- データエンド終了

        NlCNT_MAIN   := NlCNT_MAIN + 1;

        -- 算定団体コードが変われば、システム条件読み直し
        IF TlSANTEIDANTAI_CD IS NULL OR
           TlSANTEIDANTAI_CD   != RKOJIN_MID.SANTEIDANTAI_CD  THEN

          -- 01 システム条件読込
          IlRTN := JYOKEN_READ(NlCHOTEI_NENDO ,             -- 年度
                               RKOJIN_MID.SANTEIDANTAI_CD ,   -- 算定団体コード
                               VlERRBUF );

          IF IlRTN != c_NRTN_0  THEN

            -- ログ出力
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSCH4CALPACK', 1, '', '',' ZLBSCH4CALPACK JYOKEN_READ システム条件読込失敗' || VlERRBUF, i_SYS_SHOKUINKOJIN_NO, i_MASIN_NO);

            EXIT;
          END IF;

          TlSANTEIDANTAI_CD      := RKOJIN_MID.SANTEIDANTAI_CD;   -- 比較用算定団体コード
        END IF;

        IF NlCNT_MAIN = 1 THEN
          TlKOKU_SETAI_NO      := RKOJIN_MID.KOKU_SETAI_NO;   -- 比較用国保世帯番号コード
          TISANTEIDANTAI_SAVE  := RKOJIN_MID.SANTEIDANTAI_CD; --算定団体コード保持
        END IF;

        -- 国保世帯番号毎に処理
        -- 世帯毎の個人全件処理後に、世帯処理
        IF TlKOKU_SETAI_NO IS NOT NULL AND
           TlKOKU_SETAI_NO   != RKOJIN_MID.KOKU_SETAI_NO  THEN
          -- 04 課税計算処理 (世帯毎)
          IlRTN := FUNCKIHON_SYORI( TlKOKU_SETAI_NO
                                   ,TISANTEIDANTAI_SAVE
                                   ,VlERRBUF );

          IF IlRTN != c_NRTN_0 THEN
            -- ログ出力
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSCH4CALPACK', 1, '', '',' ZLBSCH4CALPACK FUNCKIHON_SYORI 課税計算処理失敗 ' ||VlERRBUF, i_SYS_SHOKUINKOJIN_NO, i_MASIN_NO);
            EXIT;
          END IF;

          -- 03 各計算TBLの内容クリア
          IlRTN := FUNCCALCLR( VlERRBUF );

          IF IlRTN != c_NRTN_0 THEN
            -- ログ出力
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSCH4CALPACK', 1, '', '',' ZLBSCH4CALPACK FUNCCALCLR 各計算TBLの内容クリア失敗 ' ||VlERRBUF, i_SYS_SHOKUINKOJIN_NO, i_MASIN_NO);
            EXIT;
          END IF;

          TlKOKU_SETAI_NO      := RKOJIN_MID.KOKU_SETAI_NO;   -- 比較用国保世帯番号コード
          TISANTEIDANTAI_SAVE  := RKOJIN_MID.SANTEIDANTAI_CD; --算定団体コード保持

        END IF;

        -- 06 個人処理
        IlRTN := FUNCKOJIN_SYORI( VlERRBUF );

        IF IlRTN != c_NRTN_0 THEN
          -- ログ出力
          BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSCH4CALPACK', 1, '', '',' ZLBSCH4CALPACK FUNCKOJIN_SYORI 個人処理失敗 ' ||VlERRBUF, i_SYS_SHOKUINKOJIN_NO, i_MASIN_NO);
          EXIT;
        END IF;

      END LOOP;

      -- クローズ
      IF CKOJIN_MID%ISOPEN THEN
        CLOSE CKOJIN_MID ;
      END IF ;
      ------------------------------------------------------------------------↑

      IF IlRTN = c_NRTN_0 THEN

        -- 最終データで世帯処理
        IF NlCNT_MAIN != 0 THEN
          -- 04 課税計算処理 (世帯毎)
          IlRTN := FUNCKIHON_SYORI( RKOJIN_MID.KOKU_SETAI_NO
                                   ,TISANTEIDANTAI_SAVE
                                   ,VlERRBUF );

          IF IlRTN != c_NRTN_0 THEN
            -- ログ出力
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSCH4CALPACK', 1, '', '',' ZLBSCH4CALPACK FUNCKIHON_SYORI 課税計算処理失敗 ' ||VlERRBUF, i_SYS_SHOKUINKOJIN_NO, i_MASIN_NO);
          END IF;
        END IF;

      END IF;

    END IF;


    -- 確定処理
    IF IlRTN = c_NRTN_0 THEN
      BEGIN
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          IlRTN       := c_NRTN_9;
          -- ログ出力
          BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSCH4CALPACK', 1, SQLCODE, SQLERRM,' ZLBSCH4CALPACK COMMIT失敗', i_SYS_SHOKUINKOJIN_NO, i_MASIN_NO);

      END;
    ELSE
      BEGIN
        ROLLBACK;
      EXCEPTION
        WHEN OTHERS THEN
          IlRTN       := c_NRTN_9;
          -- ログ出力
          BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSCH4CALPACK', 1, SQLCODE, SQLERRM,' ZLBSCH4CALPACK ROLLBACK失敗', i_SYS_SHOKUINKOJIN_NO, i_MASIN_NO);

      END;
    END IF;


    o_RTN := IlRTN;

------------------------------------------------------------------------------
--  99 例外処理                                                             --
------------------------------------------------------------------------------
EXCEPTION

    /******************************************************/
    -- その他エラー
    /******************************************************/
    WHEN OTHERS THEN

      -- 異常終了
      IlRTN       := c_NRTN_9;

      -- 異常終了
      -- ログ出力
      BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSCH4CALPACK', 1, SQLCODE, SQLERRM,' ZLBSCH4CALPACK 例外エラー ' ||SQLCODE||SQLERRM, i_SYS_SHOKUINKOJIN_NO, i_MASIN_NO);

    o_RTN := IlRTN;

END ZLBSCH4CALPACK ;
/
