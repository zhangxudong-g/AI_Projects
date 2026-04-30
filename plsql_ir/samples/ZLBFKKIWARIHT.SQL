CREATE OR REPLACE FUNCTION ZLBFKKIWARIHT (
--1.1.200.000
                           i_NSETAI             IN  NUMBER     --国保世帯番号
                         , i_NDANTAI            IN  NUMBER      -- 算定団体コード
                         , i_NNENDO             IN  NUMBER      -- 年度
                         , i_NNENDO_BUN         IN  NUMBER      -- 年度分
                         , i_NTSUCHI_NO         IN  NUMBER      -- 通知書番号
                         , i_NSHORIBI           IN  NUMBER      -- 処理日
                         , i_NJIKKOU_KBN        IN  NUMBER      -- 実行区分 0:バッチから起動 本算定 1:バッチから起動月例 9:オンライン起動 即時
                         , i_VTANMATSU          IN  NVARCHAR2   -- 端末番号
                         , i_NTRENBAN           IN  NUMBER      -- 登録連番 ※オンライン起動時は0セット
                         , o_NKEISAN_KBN1       OUT NUMBER      -- 計算区分 1:普徴更正(金額調整) 2:特徴更正開始 3:特徴中止
                         , o_NKEISAN_KBN2       OUT NUMBER      -- 計算区分 1:普徴更正(金額調整) 2:特徴更正開始 3:特徴中止 11:特徴依頼取消
                         , o_NKEISAN_KBN3       OUT NUMBER      -- 計算区分 11:特徴依頼取消
                         , o_NFUTU_TUKI         OUT NUMBER      -- 普徴月
                         , o_NTOKU_TUKI         OUT NUMBER      -- 特徴月
                         , o_NYOKU_HYOUJI_KBN   OUT NVARCHAR2   -- 翌年度表示区分 0:表示しない 1:表示する
                         , o_VHYOUJI_JYOUHO     OUT NVARCHAR2   -- 表示情報
                         , o_NCHUSHI_JIYU       OUT NVARCHAR2   -- 中止事由 計算区分1~3に特徴中止をセットした場合に本項目返却 未セットの場合は0を返却
) RETURN NUMBER
------------------------------------------------------------------
--  業務名     ZLB(国保税)
--  PG名       ZLBFKKIWARIHT
--  引数       i_NSETAI                     国保世帯番号
--             i_NDANTAI                    算定団体コード
--             i_NNENDO                     年度
--             i_NNENDO_BUN                 年度分
--             i_NTSUCHI_NO                 通知書番号
--             i_NSHORIBI                   処理日
--             i_NJIKKOU_KBN                実行区分 0:バッチから起動 本算定 1:バッチから起動月例 9:オンライン起動 即時
--             i_VTANMATSU                  端末番号
--             i_NTRENBAN                   登録連番 ※オンライン起動時は0セット
--             o_NKEISAN_KBN1               計算区分 1:普徴更正(金額調整) 2:特徴更正開始 3:特徴中止 11:特徴依頼取消
--             o_NKEISAN_KBN2               計算区分 1:普徴更正(金額調整) 2:特徴更正開始 3:特徴中止 11:特徴依頼取消
--             o_NKEISAN_KBN3               計算区分 11:特徴依頼取消
--             o_NFUTU_TUKI                 普徴月
--             o_NTOKU_TUKI                 特徴月
--             o_NYOKU_HYOUJI_KBN           翌年度表示区分 0:表示しない 1:表示する
--             o_VHYOUJI_JYOUHO             表示情報
--             o_NCHUSHI_JIYU               中止事由 計算区分1~3に特徴中止をセットした場合に本項目返却 未セットの場合は0を返却
--  作成者       ZCZL.WANGYUNING
--  作成日       2023/08/01
--  Version      0.2.000.000
--------------------------------------------------------------------------
--  変更履歴
--  2024/05/06 ZCZL.GUANHONG UPDATE 0.3.000.100: 国保2次にマージ作業
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--  2025/12/02 ZCZL.LIUYANG UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--------------------------------------------------------------------------
IS
  --// 定数宣言 //--
  c_SYORI_NG                   CONSTANT NUMBER := 1;              -- 処理異常
  c_SYORI_OK                   CONSTANT NUMBER := 0;              -- 処理正常

  c_NFUTSU                     CONSTANT NUMBER := 1;              -- 普徴対象
  c_NTOKUHANTEI                CONSTANT NUMBER := 2;              -- 特徴対象判定
  c_NTYUSHIHANTEI              CONSTANT NUMBER := 3;              -- 中止判定
  c_NTOKUKAISHI                CONSTANT NUMBER := 4;              -- 特徴開始
  c_NTYUSHISHORI               CONSTANT NUMBER := 5;              -- 中止処理

  c_NNASHI_KEISAN              CONSTANT NUMBER := 0;              -- なし
  c_NFUTSU_KEISAN              CONSTANT NUMBER := 1;              -- 普徴更正(金額調整)
  c_NTOKU_KEISAN               CONSTANT NUMBER := 2;              -- 特徴開始
  c_NTYUSHI_KEISAN             CONSTANT NUMBER := 3;              -- 特徴中止
  c_NFUTSU2_KEISAN             CONSTANT NUMBER := 4;              -- 普徴継続
  c_NIRAICANCEL_KEISAN         CONSTANT NUMBER := 11;             -- 特徴依頼取消

  c_NHYOJINASHI                CONSTANT NUMBER := 0;              -- 表示しない
  c_NHYOJIARI                  CONSTANT NUMBER := 1;              -- 表示する

  c_NTYUSHI_KOSEI              CONSTANT NUMBER := 1;              -- 更正区分: 中止
  c_NKAISHI_KOSEI              CONSTANT NUMBER := 2;              -- 更正区分: 開始

  c_NSHINKI_JOTAI              CONSTANT NUMBER := 1;              -- 状態区分: 新規
  c_NTUZUKI_JOTAI              CONSTANT NUMBER := 2;              -- 状態区分: 継続
  c_NTYUSHI_JOTAI              CONSTANT NUMBER := 3;              -- 状態区分: 中止

  c_NJISHI_TOKU                CONSTANT NUMBER := 0;              -- 特徴実施
  c_NJISHINAI_TOKU             CONSTANT NUMBER := 1;              -- 特徴実施しない

  c_NRET_FUTU                  CONSTANT NUMBER := 0;              -- 特徴判定/中止判定結果: 普徴
  c_NRET_TOKUSTART             CONSTANT NUMBER := 1;              -- 特徴判定/中止判定結果: 特徴開始
  c_NRET_TOKUSTOP              CONSTANT NUMBER := 2;              -- 特徴判定/中止判定結果: 特徴中止

  c_NONLINE                    CONSTANT NUMBER := 9;              -- オンライン起動

  --特徴中止事由判定用区分
  c_NCHUSHI_JIYU_NASI          CONSTANT NUMBER := 0;              -- 無し
  c_NCHUSHI_JIYU_IDO           CONSTANT NUMBER := 1;              -- 特徴異動情報による中止
  c_NCHUSHI_JIYU_ZEIZOU        CONSTANT NUMBER := 2;              -- 税額変更(増)による中止
  c_NCHUSHI_JIYU_ZEIGEN        CONSTANT NUMBER := 3;              -- 税額変更(減)による中止

  --特徴中止事由
  c_NCHUSHI_JIYU_1             CONSTANT NUMBER := 1;              -- 減額更正
  c_NCHUSHI_JIYU_2             CONSTANT NUMBER := 2;              -- 増額更正
  c_NCHUSHI_JIYU_36            CONSTANT NUMBER := 36;             -- その他喪失
  c_NCHUSHI_JIYU_90            CONSTANT NUMBER := 90;             -- 特徴捕捉情報無し
  c_NCHUSHI_JIYU_SOSITSU       CONSTANT NUMBER := 36;             -- その他喪失

  c_NIRAIZUMI                  CONSTANT NUMBER := 0;              -- 特徴依頼済
  c_NIRAIMAE                   CONSTANT NUMBER := 1;              -- 特徴依頼前

  c_NKAMOKU_CD                 CONSTANT NUMBER := 15;             -- 科目コード
  c_NKAMOKUS_CD1               CONSTANT NUMBER := 1;              -- 科目詳細コード・普徴
  c_NKAMOKUS_CD2               CONSTANT NUMBER := 2;              -- 科目詳細コード・特徴


  c_NNENREI_65                 CONSTANT NUMBER := 65;             -- 年齢65
  c_NNENREI_75                 CONSTANT NUMBER := 75;             -- 年齢75
  c_NNOKI_HON                  CONSTANT NUMBER := 2;              -- 納期区分 (2:本算定)

  -- ログ出力用
  c_DBMS_OUTPUT                CONSTANT BOOLEAN       := FALSE;               -- DBMS_OUTPUT出力有無（SQL*Plusでのテスト用）
  c_VPGNAME                    CONSTANT NVARCHAR2(30) := 'ZLBFKKIWARIHT'; -- エラーメッセージ用
  c_NSTEPNO                    CONSTANT NUMBER := 99;

  --// 変数宣言 //--
  NRETURN                      NUMBER;                            -- 処理結果(0:正常 1:異常)

  NTAISYOHANTEI                NUMBER;                            -- 対象判定(1. 普徴対象 2. 特徴対象判定 3. 中止判定)
  NKIWARIHANTEI                NUMBER;                            -- 期割済み判定(0. 期割未処理 1. 期割処理済)
  NTYUSHIHANTEI                NUMBER;                            -- 特別徴収の中止判定(0. 普徴期割 1. 中止処理)
  NGFUTU_TUKI                  NUMBER;                            -- 普徴月
  NGTOKU_TUKI                  NUMBER;                            -- 特徴月
  NGKOSEI_CD                   NUMBER;                            -- 更正区分
  NGCHUSHI_JIYU                NUMBER;                            -- 特徴中止事由
  NGTSUCHINO_Y                 NUMBER;                            -- 通知書番号（翌年度）
  NGYOKU_IDO_FLG               NUMBER := 1;                       -- OL 翌年度キー特徴異動可否フラグ
  NSAISIN_FLG                  NUMBER;                            -- 賦課管理番号最新チェック
  NJOTAI_KBN                   NUMBER;                            -- 特徴対象者情報 特徴状態
  NKAISHI_TSUKI                NUMBER;                            -- 特徴対象者情報 特徴開始月
  NSHURYO_TSUKI                NUMBER;                            -- 特徴対象者情報 終了月
  NTAISYOJOHO_KENSU            NUMBER;                            -- 特徴対象者情報 対象件数
  NKOJINCNT                    NUMBER(2);                         --計算個人有無(0:なし、0以外:有り)
  BNENDO                       BOOLEAN;                           -- 年度判断
  BRTN                         BOOLEAN;
  NlTUTI_TUKI                  NUMBER;                            --処理状態管理の通知年月の月用
  BYOKU4STOP                   BOOLEAN := FALSE;                  -- 翌４中止フラグ(T:特徴月に104を返却 F:特徴月に12or2を返却)
  NKOZAKIRIKAE                 NUMBER := 0;
  NNUSHI_KOJIN_NO              ZLBTKIHON_N.NUSHI_KOJIN_NO%TYPE;
  NwKAISHITUSKI                NUMBER := 0;    -- 普徴開始月
--1/2判定
  NHANTEI_KEKKA                 NUMBER := 0;--(0:特徴対象可(または判定無し).1:1/2判定の結果特徴不可)

  NTUTI_NENGETU                 NUMBER := 0;   -- 通知年月
  NCMP_TUKI                     NUMBER := 0;   -- 特徴中止期別用
  NTOKU_KIBETSU_CD              NUMBER := 0;   -- 特徴中止期別
  NTOKU_KIWARI_CNT              NUMBER := 0;   -- 特徴期割件数
  NTOKU_IDO_CNT                 NUMBER := 0;   -- 特徴異動件数
  NRIREKI_NO                    NUMBER := 0;   -- 履歴番号
  NINS_FLG                      NUMBER := 0;   -- INSERTフラグ
  IZAN_MODE                     PLS_INTEGER := 0; -- 0:通常 1:仮算定中

  NKOUFUTU_FLG                  NUMBER := 0;   -- 後半普徴フラグ

  -- 動的SQL
  VSQL                         VARCHAR2(2000);
  V_TBLNAME_IN                 VARCHAR2(30);
  V_TBLNAME_OUT                VARCHAR2(30);
  V_WHERE                      VARCHAR2(1000);
  V_ITEM                       VARCHAR2(1000);

  -- ログファイル用
  VMSG                         NVARCHAR2(256) := '';
-----------------------------------------------------------
--  時間取得
-----------------------------------------------------------
FUNCTION FUNCGETTIME RETURN NVARCHAR2 IS
BEGIN
  RETURN (TO_CHAR(SYSDATE, 'HH24:MI:SS'));
END FUNCGETTIME;
------------------------------------------------------------------------------
-- 特徴減額チェック
------------------------------------------------------------------------------
FUNCTION FUNCTOKUGENCHK RETURN NUMBER IS
    NHOKENRYO_A           NUMBER := 0;
    NHOKENRYO_B           NUMBER := 0;
    IHANTEI_MODE         NUMBER := 0;
    NRETURN              NUMBER := 0;

  BEGIN
    IHANTEI_MODE := ZLBPK00010.FCFFJKN2(82);
    IF IHANTEI_MODE = 1 THEN
      /************************/
      /* 年税の増減を判断する */
      /************************/
      -- 年税(A)を取得する＿計算TBL
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--      SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0)
      SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0) + NVL(D.NENZEI,0)
        INTO NHOKENRYO_A
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--        FROM ZLBTKIHON_CAL A, ZLBTKAI_KIHON_CAL B, ZLBTSIEN_KIHON_CAL C
        FROM ZLBTKIHON_CAL A, ZLBTKAI_KIHON_CAL B, ZLBTSIEN_KIHON_CAL C, ZLBTKDM_KIHON_CAL D
       WHERE A.KOKU_SETAI_NO      = i_NSETAI
         AND A.SANTEIDANTAI_CD    = i_NDANTAI
         AND A.CHOTEI_NENDO       = i_NNENDO
         AND A.NENDO_BUN          = i_NNENDO_BUN
         AND A.TSUCHI_NO          = i_NTSUCHI_NO
         AND A.SYS_TANMATSU_NO    = i_VTANMATSU
         AND B.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
         AND B.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
         AND B.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
         AND B.NENDO_BUN(+)       = A.NENDO_BUN
         AND B.TSUCHI_NO(+)       = A.TSUCHI_NO
         AND B.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO
         AND C.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
         AND C.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
         AND C.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
         AND C.NENDO_BUN(+)       = A.NENDO_BUN
         AND C.TSUCHI_NO(+)       = A.TSUCHI_NO
--  2025/08/11 ZCZL.WANGMING Update START 1.1.200.000:子ども子育て支援金対応
--         AND C.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO;
         AND C.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO
         AND D.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
         AND D.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
         AND D.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
         AND D.NENDO_BUN(+)       = A.NENDO_BUN
         AND D.TSUCHI_NO(+)       = A.TSUCHI_NO
         AND D.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO;
--  2025/08/11 ZCZL.WANGMING Update END

      -- 年税(B)を取得する＿賦課TBL
      BEGIN
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--        SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0)
        SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0) + NVL(D.NENZEI,0)
          INTO NHOKENRYO_B
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--          FROM ZLBTKIHON_N A, ZLBTKAI_KIHON_N B, ZLBTSIEN_KIHON_N C
          FROM ZLBTKIHON_N A, ZLBTKAI_KIHON_N B, ZLBTSIEN_KIHON_N C, ZLBTKDM_KIHON_N D
         WHERE A.KOKU_SETAI_NO      = i_NSETAI
           AND A.SANTEIDANTAI_CD    = i_NDANTAI
           AND A.CHOTEI_NENDO       = i_NNENDO
           AND A.NENDO_BUN          = i_NNENDO_BUN
           AND A.TSUCHI_NO          = i_NTSUCHI_NO
           AND B.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
           AND B.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
           AND B.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
           AND B.NENDO_BUN(+)       = A.NENDO_BUN
           AND B.TSUCHI_NO(+)       = A.TSUCHI_NO
           AND C.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
           AND C.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
           AND C.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
           AND C.NENDO_BUN(+)       = A.NENDO_BUN
--  2025/08/11 ZCZL.WANGMING Update START 1.1.200.000:子ども子育て支援金対応
--           AND C.TSUCHI_NO(+)       = A.TSUCHI_NO;
           AND C.TSUCHI_NO(+)       = A.TSUCHI_NO
           AND D.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
           AND D.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
           AND D.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
           AND D.NENDO_BUN(+)       = A.NENDO_BUN
           AND D.TSUCHI_NO(+)       = A.TSUCHI_NO;
--  2025/08/11 ZCZL.WANGMING Update END
      EXCEPTION
        WHEN OTHERS THEN
         NHOKENRYO_B := 0;
      END;
      IF NHOKENRYO_B > NHOKENRYO_A THEN --年税が仮徴収合計＞本算定合計になっている場合
        NRETURN := 1;--特徴中止
      END IF;
    END IF;
    RETURN(NRETURN);

  -- 異常処理
  EXCEPTION
      WHEN OTHERS THEN
        VMSG := 'FUNCTOKUGENCHK 特徴減額チェック (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        RETURN(NRETURN);
END FUNCTOKUGENCHK;
------------------------------------------------------------------------------
-- 特徴最終月算出
------------------------------------------------------------------------------
FUNCTION FUNCTOKUKEIZOKUCHK(o_NKAISHITUKI_FU OUT NUMBER) RETURN NUMBER IS
    NwCHOTEI_6           PLS_INTEGER := 0;
    NwCHOTEI_8           PLS_INTEGER := 0;

  BEGIN

    o_NKAISHITUKI_FU := NGFUTU_TUKI ;

    IF NGFUTU_TUKI < 7 THEN -- 6月以前
      SELECT NVL(COUNT(*),0)
        INTO NwCHOTEI_6
        FROM ZLBTKIBETSU_N
       WHERE KOKU_SETAI_NO     = i_NSETAI           -- 国保世帯番号
         AND SANTEIDANTAI_CD   = i_NDANTAI          -- 算定団体コード
         AND CHOTEINENDO       = i_NNENDO           -- 調定年度
         AND NENDOBUN          = i_NNENDO_BUN       -- 年度分
         AND TSUCHI_NO         = i_NTSUCHI_NO       -- 通知書番号
         AND RONRIKIBETSU      = 3                  -- 6月論理期別(3)
         AND ZEN_ZEIGAKU       > 0                  -- 金額が1円以上
         AND KAMOKU_CD         = c_NKAMOKU_CD       -- 科目コード
         AND KAMOKUS_CD        = c_NKAMOKUS_CD2;
      IF NwCHOTEI_6 > 0 THEN
        o_NKAISHITUKI_FU := 7 ; --6月特徴がある場合は、7月で上書きする
        SELECT NVL(COUNT(*),0)
          INTO NwCHOTEI_8
          FROM ZLBTKIBETSU_N
         WHERE KOKU_SETAI_NO     = i_NSETAI           -- 国保世帯番号
           AND SANTEIDANTAI_CD   = i_NDANTAI          -- 算定団体コード
           AND CHOTEINENDO       = i_NNENDO           -- 調定年度
           AND NENDOBUN          = i_NNENDO_BUN       -- 年度分
           AND TSUCHI_NO         = i_NTSUCHI_NO       -- 通知書番号
           AND RONRIKIBETSU      = 5                  -- 8月論理期別(5)
           AND ZEN_ZEIGAKU       > 0                  -- 金額が1円以上
           AND KAMOKU_CD         = c_NKAMOKU_CD       -- 科目コード
           AND KAMOKUS_CD        = c_NKAMOKUS_CD2;
        IF NwCHOTEI_8 > 0 THEN
          o_NKAISHITUKI_FU := 9 ; --8月特徴がある場合は、9月で上書きする
        END IF;
      END IF;
    ELSE -- 7,8月
      SELECT NVL(COUNT(*),0)
        INTO NwCHOTEI_8
        FROM ZLBTKIBETSU_N
       WHERE KOKU_SETAI_NO     = i_NSETAI           -- 国保世帯番号
         AND SANTEIDANTAI_CD   = i_NDANTAI          -- 算定団体コード
         AND CHOTEINENDO       = i_NNENDO           -- 調定年度
         AND NENDOBUN          = i_NNENDO_BUN       -- 年度分
         AND TSUCHI_NO         = i_NTSUCHI_NO       -- 通知書番号
         AND RONRIKIBETSU      = 5                  -- 8月論理期別(5)
         AND ZEN_ZEIGAKU       > 0                  -- 金額が1円以上
         AND KAMOKU_CD         = c_NKAMOKU_CD       -- 科目コード
         AND KAMOKUS_CD        = c_NKAMOKUS_CD2;
      IF NwCHOTEI_8 > 0 THEN
        o_NKAISHITUKI_FU := 9 ; --8月特徴がある場合は、9月で上書きする
      END IF;
    END IF;
    -- 正常終了
    RETURN(c_SYORI_OK);
  -- 異常処理
  EXCEPTION
      WHEN OTHERS THEN
        VMSG := 'FUNCTOKUKEIZOKUCHK 特徴最終月算出 (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        RETURN(c_SYORI_NG);
END FUNCTOKUKEIZOKUCHK;
------------------------------------------------------------------------------
-- 計算個人チェック
------------------------------------------------------------------------------
  FUNCTION FUNCKOJINCHK RETURN NUMBER IS
    CURSOR CKOJIN IS
      SELECT *
        FROM ZLBTKOJIN_N
       WHERE KOKU_SETAI_NO    = i_NSETAI
         AND SANTEIDANTAI_CD  = i_NDANTAI
         AND CHOTEI_NENDO     = i_NNENDO
         AND NENDO_BUN        = i_NNENDO_BUN
         AND TSUCHI_NO        = i_NTSUCHI_NO;

    CURSOR CKOJIN2 IS
      SELECT DISTINCT KOJIN_NO
        FROM KHSTSHIKAKU
       WHERE KOKU_SETAI_NO    = i_NSETAI;

    -- ZLBSBSHKKHTGET用変数
    NwSHIKAKU4      NUMBER(2); --資格区分４月
    NwSHIKAKU5      NUMBER(2); --資格区分５月
    NwSHIKAKU6      NUMBER(2); --資格区分６月
    NwSHIKAKU7      NUMBER(2); --資格区分７月
    NwSHIKAKU8      NUMBER(2); --資格区分８月
    NwSHIKAKU9      NUMBER(2); --資格区分９月
    NwSHIKAKU10     NUMBER(2); --資格区分１０月
    NwSHIKAKU11     NUMBER(2); --資格区分１１月
    NwSHIKAKU12     NUMBER(2); --資格区分１２月
    NwSHIKAKU1      NUMBER(2); --資格区分１月
    NwSHIKAKU2      NUMBER(2); --資格区分２月
    NwSHIKAKU3      NUMBER(2); --資格区分３月
    NwKAIGO4        NUMBER(2); --介護区分４月
    NwKAIGO5        NUMBER(2); --介護区分５月
    NwKAIGO6        NUMBER(2); --介護区分６月
    NwKAIGO7        NUMBER(2); --介護区分７月
    NwKAIGO8        NUMBER(2); --介護区分８月
    NwKAIGO9        NUMBER(2); --介護区分９月
    NwKAIGO10       NUMBER(2); --介護区分１０月
    NwKAIGO11       NUMBER(2); --介護区分１１月
    NwKAIGO12       NUMBER(2); --介護区分１２月
    NwKAIGO1        NUMBER(2); --介護区分１月
    NwKAIGO2        NUMBER(2); --介護区分２月
    NwKAIGO3        NUMBER(2); --介護区分３月
    NwRTN           NUMBER(2); --処理結果

  BEGIN
    -- 計算個人件数取得
    SELECT COUNT(1) INTO NKOJINCNT FROM ZLBTKOJIN_CAL
     WHERE KOKU_SETAI_NO = i_NSETAI
       AND SANTEIDANTAI_CD = i_NDANTAI
       AND CHOTEI_NENDO    = i_NNENDO
       AND NENDO_BUN       = i_NNENDO_BUN
       AND TSUCHI_NO       = i_NTSUCHI_NO
       AND SYS_TANMATSU_NO = i_VTANMATSU;
    -- オンライン賦課更正経由の場合は計算個人のデータは未存在
    -- ⇒賦課個人から計算個人を作成
    IF i_NJIKKOU_KBN = c_NONLINE AND NKOJINCNT = 0 THEN
      FOR CRKOJIN IN CKOJIN LOOP
        CRKOJIN.SYS_TANMATSU_NO := i_VTANMATSU;
        INSERT INTO ZLBTKOJIN_CAL VALUES (
          CRKOJIN.KOKU_SETAI_NO      ,CRKOJIN.KOJIN_NO           ,CRKOJIN.SANTEIDANTAI_CD    ,
          CRKOJIN.CHOTEI_NENDO       ,CRKOJIN.NENDO_BUN          ,CRKOJIN.R_NO               ,
          CRKOJIN.TSUCHI_NO          ,CRKOJIN.NEW_SHIK_KBN       ,CRKOJIN.NEW_KAI_SHIK_KBN   ,
          CRKOJIN.NEW_TAI_KBN        ,CRKOJIN.F4_SHIK_KBN        ,CRKOJIN.F4_KAI_KBN         ,
          CRKOJIN.F4_TAI_KBN         ,CRKOJIN.FUKA_SHIK_KBN      ,CRKOJIN.FUKA_KAI_KBN       ,
          CRKOJIN.KEIGEN_HANT_KBN    ,CRKOJIN.SHIK_4             ,CRKOJIN.SHIK_5             ,
          CRKOJIN.SHIK_6             ,CRKOJIN.SHIK_7             ,CRKOJIN.SHIK_8             ,
          CRKOJIN.SHIK_9             ,CRKOJIN.SHIK_10            ,CRKOJIN.SHIK_11            ,
          CRKOJIN.SHIK_12            ,CRKOJIN.SHIK_1             ,CRKOJIN.SHIK_2             ,
          CRKOJIN.SHIK_3             ,CRKOJIN.KAI_SHIK_4         ,CRKOJIN.KAI_SHIK_5         ,
          CRKOJIN.KAI_SHIK_6         ,CRKOJIN.KAI_SHIK_7         ,CRKOJIN.KAI_SHIK_8         ,
          CRKOJIN.KAI_SHIK_9         ,CRKOJIN.KAI_SHIK_10        ,CRKOJIN.KAI_SHIK_11        ,
          CRKOJIN.KAI_SHIK_12        ,CRKOJIN.KAI_SHIK_1         ,CRKOJIN.KAI_SHIK_2         ,
          CRKOJIN.KAI_SHIK_3         ,CRKOJIN.SHOTOKU            ,CRKOJIN.KAHYO              ,
          CRKOJIN.SHOTOKU_WARI       ,CRKOJIN.KAI_SHOTOKU_WARI   ,CRKOJIN.SIEN_SHOTOKU_WARI  ,
          CRKOJIN.KEIGEN_SHOTOKU     ,CRKOJIN.SHISANZEI          ,CRKOJIN.SHISAN_WARI        ,
          CRKOJIN.KAI_SHISAN_WARI    ,CRKOJIN.SIEN_SHISAN_WARI   ,CRKOJIN.SENJU_KBN          ,
          CRKOJIN.RONEN_KBN          ,CRKOJIN.SHINKOKU_KBN       ,CRKOJIN.SHU_SHOTOKU_KBN    ,
          CRKOJIN.J_KAZEI_KBN        ,CRKOJIN.J_SHOTOKU_WARI     ,CRKOJIN.J_KINTO_WARI       ,
          CRKOJIN.NEW_SHUTOK_BI      ,CRKOJIN.NEW_SOSHITSU_BI    ,CRKOJIN.NEW_ZOKU           ,
          CRKOJIN.KAI_GAI_BI         ,CRKOJIN.KAI_HIGAI_BI       ,CRKOJIN.TANJO_65           ,
          CRKOJIN.KOSEI_BI           ,CRKOJIN.JIYU               ,CRKOJIN.KAI_KOSEI_BI       ,
          CRKOJIN.KAI_JIYU           ,CRKOJIN.KEIGEN_BI          ,CRKOJIN.SEKISAN_GAI_KBN    ,
          CRKOJIN.KOJIN_NENZEI       ,CRKOJIN.ZOKU_NAME          ,CRKOJIN.SHIK_R_NO          ,
          CRKOJIN.SYS_SAKUSEIBI      ,CRKOJIN.SYS_KOSHINBI       ,CRKOJIN.SYS_JIKAN          ,
          CRKOJIN.SYS_SHOKUINKOJIN_NO,CRKOJIN.SYS_TANMATSU_NO    ,
          0,    --SEISAN_KBN
          0,    --DIV_4
          0,    --DIV_5
          0,    --DIV_6
          0,    --DIV_7
          0,    --DIV_8
          0,    --DIV_9
          0,    --DIV_10
          0,    --DIV_11
          0,    --DIV_12
          0,    --DIV_1
          0,    --DIV_2
          0,    --DIV_3
          0,    --CUST_1
          0,    --CUST_2
          0     --CUST_3
          ,CRKOJIN.NEW_SHITSU_KBN      ,CRKOJIN.F4_SHITSU_KBN       ,CRKOJIN.SHITSU_4
          ,CRKOJIN.SHITSU_5            ,CRKOJIN.SHITSU_6            ,CRKOJIN.SHITSU_7
          ,CRKOJIN.SHITSU_8            ,CRKOJIN.SHITSU_9            ,CRKOJIN.SHITSU_10
          ,CRKOJIN.SHITSU_11           ,CRKOJIN.SHITSU_12           ,CRKOJIN.SHITSU_1
          ,CRKOJIN.SHITSU_2            ,CRKOJIN.SHITSU_3            ,CRKOJIN.SHITSU_GAI_BI
          ,CRKOJIN.SHITSU_HIGAI_BI     ,CRKOJIN.SHITSU_SHOTOKU      ,CRKOJIN.SHITSU_KAHYO
          ,CRKOJIN.SHITSU_KEIGEN_SHOTOKU
          ,CRKOJIN.KYUYO_SHOTOKU_KBN        --給与所得者等該当区分
-- 2024/05/06 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
          ,CRKOJIN.NEW_SAN_KBN
          ,CRKOJIN.F4_SAN_KBN
          ,CRKOJIN.SAN_4
          ,CRKOJIN.SAN_5
          ,CRKOJIN.SAN_6
          ,CRKOJIN.SAN_7
          ,CRKOJIN.SAN_8
          ,CRKOJIN.SAN_9
          ,CRKOJIN.SAN_10
          ,CRKOJIN.SAN_11
          ,CRKOJIN.SAN_12
          ,CRKOJIN.SAN_1
          ,CRKOJIN.SAN_2
          ,CRKOJIN.SAN_3
          ,CRKOJIN.SAN_GAI_BI
          ,CRKOJIN.SAN_HIGAI_BI
          ,CRKOJIN.SAN_IRYO_GEN_KINTO
          ,CRKOJIN.SAN_IRYO_GEN_SHOTOKU
          ,CRKOJIN.SAN_KAI_GEN_KINTO
          ,CRKOJIN.SAN_KAI_GEN_SHOTOKU
          ,CRKOJIN.SAN_SIEN_GEN_KINTO
          ,CRKOJIN.SAN_SIEN_GEN_SHOTOKU
--  2025/08/11 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
          ,CRKOJIN.KDM_18_KBN
          ,CRKOJIN.KDM_SHOTOKU_WARI
          ,CRKOJIN.KDM_SHISAN_WARI
          ,CRKOJIN.KDM_KEIGEN_KITO
          ,CRKOJIN.KDM_KEIGEN_KITO18
          ,CRKOJIN.KDM_SAN_GEN_KINTO
          ,CRKOJIN.KDM_SAN_GEN_SHOTOKU
          ,CRKOJIN.KDM_SAN_GEN_KINTO18
          ,CRKOJIN.KDM18UN_KEIGEN_KITO
--  2025/08/11 ZCZL.WANGMING ADD END
-- 2024/05/06　ZCZL.GUANHONG　Add　End
-- 2025/12/02 ZCZL.LIUYANG ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
          ,CRKOJIN.KDM_KODOMO_KEIGEN_KITO       -- 子ども均等割軽減額（未就学児）
          ,CRKOJIN.KDM_KINTO                    -- 子ども均等割額
          ,CRKOJIN.KDM_KINTO18                  -- 子ども18歳以上均等割額
-- 2025/12/02 ZCZL.LIUYANG ADD END
        );
        NKOJINCNT := NKOJINCNT + 1;
      END LOOP;

    -- オンライン新規賦課の場合は最新個人のデータも未存在
    -- ⇒資格異動累計から計算個人を作成
      IF i_NJIKKOU_KBN = c_NONLINE AND NKOJINCNT = 0 THEN
        FOR CRKOJIN2 IN CKOJIN2 LOOP
          --各月資格情報取得
          ZLBSBSHKKHTGET(i_NSETAI         , --国保世帯番号
                            CRKOJIN2.KOJIN_NO, --個人番号
                            i_NNENDO_BUN     , --年度
                            NwSHIKAKU4       , --資格区分４月
                            NwSHIKAKU5       , --資格区分５月
                            NwSHIKAKU6       , --資格区分６月
                            NwSHIKAKU7       , --資格区分７月
                            NwSHIKAKU8       , --資格区分８月
                            NwSHIKAKU9       , --資格区分９月
                            NwSHIKAKU10      , --資格区分１０月
                            NwSHIKAKU11      , --資格区分１１月
                            NwSHIKAKU12      , --資格区分１２月
                            NwSHIKAKU1       , --資格区分１月
                            NwSHIKAKU2       , --資格区分２月
                            NwSHIKAKU3       , --資格区分３月
                            NwKAIGO4         , --介護区分４月
                            NwKAIGO5         , --介護区分５月
                            NwKAIGO6         , --介護区分６月
                            NwKAIGO7         , --介護区分７月
                            NwKAIGO8         , --介護区分８月
                            NwKAIGO9         , --介護区分９月
                            NwKAIGO10        , --介護区分１０月
                            NwKAIGO11        , --介護区分１１月
                            NwKAIGO12        , --介護区分１２月
                            NwKAIGO1         , --介護区分１月
                            NwKAIGO2         , --介護区分２月
                            NwKAIGO3         , --介護区分３月
                            NwRTN           ); --処理結果
          IF NwRTN = c_SYORI_OK THEN
            INSERT INTO ZLBTKOJIN_CAL VALUES (
              i_NSETAI,CRKOJIN2.KOJIN_NO,i_NDANTAI,i_NNENDO,i_NNENDO_BUN,
              0,i_NTSUCHI_NO,0,0,0,0,0,0,0,0,0,
              NwSHIKAKU4 ,NwSHIKAKU5 ,NwSHIKAKU6 ,NwSHIKAKU7 ,NwSHIKAKU8 ,
              NwSHIKAKU9 ,NwSHIKAKU10,NwSHIKAKU11,NwSHIKAKU12,NwSHIKAKU1 ,
              NwSHIKAKU2 ,NwSHIKAKU3 ,NwKAIGO4   ,NwKAIGO5   ,NwKAIGO6   ,
              NwKAIGO7   ,NwKAIGO8   ,NwKAIGO9   ,NwKAIGO10  ,NwKAIGO11  ,
              NwKAIGO12  ,NwKAIGO1   ,NwKAIGO2   ,NwKAIGO3   ,
              0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
              0,0,0,0,0,0,i_VTANMATSU,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
-- 2024/05/06 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
--              ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
              ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
--  2025/08/11 ZCZL.WANGMING UPDATE 1.1.200.000:子ども子育て支援金対応
--              ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
-- 2025/12/02 ZCZL.LIUYANG UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00084
--              ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
              ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
-- 2024/05/06　ZCZL.GUANHONG　Add　End
            NKOJINCNT := NKOJINCNT + 1;
          ELSE
            ROLLBACK;
            VMSG := 'FUNCKOJINCHK 計算個人チェック（国保世帯番号 = ' || i_NSETAI || ' ZLBSBSHKKHTGET エラー発生）';
            RETURN(c_SYORI_NG);
          END IF;
        END LOOP;
      END iF;
    END IF;
    -- 正常終了
    COMMIT;
    RETURN(c_SYORI_OK);
    -- 異常処理
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      VMSG := 'FUNCKOJINCHK 計算個人チェック（国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
      RETURN(c_SYORI_NG);
  END FUNCKOJINCHK;
------------------------------------------------------------------------------
-- 年度判断
------------------------------------------------------------------------------
  FUNCTION FUNCNENDOCHK(o_BNENDO OUT BOOLEAN) RETURN NUMBER IS
    INENDO         PLS_INTEGER;
    NKENSU         NUMBER;
  BEGIN
    -- 処理日が該当年度の3/31を超える場合
    IF i_NSHORIBI > (i_NNENDO * 10000) + 10331 THEN
        -- 8月開始の通知を送付しているかチェック
        SELECT COUNT(*) INTO NKENSU
          FROM   ZLBTSHORI_JYOTAI_KR
            WHERE  TUTI_NENGETU  = ((i_NNENDO * 10000) + 10600) / 100
              AND  SHORI_CYCLE   = 1
              AND  HOSOKU_NENDO  = i_NNENDO
              AND  HOSOKU_TUKI   = 2
              AND  SHORI_SHUBETU = 7;
        -- 送付している場合
        IF NKENSU > 0 THEN
            -- 処理日の年度を取得する
            INENDO := KKAPK0020.FDAYNENDO(i_NSHORIBI, NULL);
        -- 送付していない場合
        ELSE
            -- 処理日－１の年度を取得する
            INENDO := KKAPK0020.FDAYNENDO(i_NSHORIBI, NULL) - 1;
        END IF;
    ELSE
      -- 年度を取得する
      INENDO := KKAPK0020.FDAYNENDO(i_NSHORIBI, NULL);
    END IF;
    -- 引数の年度≧引数の処理日から判定した年度
    IF i_NNENDO >= INENDO THEN
      o_BNENDO := TRUE;
    ELSE
      o_BNENDO := FALSE;
    END IF;
    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := 'FUNCNENDOCHK 年度判断 (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        RETURN(c_SYORI_NG);
  END FUNCNENDOCHK;

------------------------------------------------------------------------------
-- パラメータ取得関数
------------------------------------------------------------------------------
FUNCTION FUNCGETW04(i_NNENDO IN NUMBER , i_NTOKUTUKI IN NUMBER) RETURN NUMBER IS
    CTLCONS_SEQ_P NUMBER;
    CTLPRM        NVARCHAR2(400);
    NlRTN         PLS_INTEGER;
    N_RTN         INTEGER;
  BEGIN
    IF i_NTOKUTUKI IN (10,12,2) THEN
      CTLCONS_SEQ_P := i_NNENDO * 100 + i_NTOKUTUKI;
    ELSIF i_NTOKUTUKI IN (4,6,8) THEN
      CTLCONS_SEQ_P := (i_NNENDO - 1) * 100 + i_NTOKUTUKI;
    ELSIF i_NTOKUTUKI IN (104,106,108) THEN
      CTLCONS_SEQ_P :=(i_NNENDO - 2) * 100 + i_NTOKUTUKI;
    ELSE
      RETURN 0;
    END IF;

    NlRTN := ZLBPK00010.FCPRMSHUTOKU('ZLB','00TOKU_W04',CTLCONS_SEQ_P,CTLPRM);
    IF NlRTN <> 0 THEN
      N_RTN := 0;
    ELSE
      BEGIN
        N_RTN := TO_NUMBER(CTLPRM) ;
      -- 異常処理
      EXCEPTION
        WHEN OTHERS THEN
          N_RTN := 0;
      END;
    END IF;
  RETURN N_RTN;
END FUNCGETW04;
------------------------------------------------------------------------------
-- 世帯員喪失判断
------------------------------------------------------------------------------
  FUNCTION FUNCSOUSHITSUHANTEI(o_BSOSHITSU_HANTAI OUT BOOLEAN) RETURN NUMBER IS
    NKOJIN_CAL_CNT          NUMBER;
    NKOJIN_N_CNT            NUMBER;
    NKOJIN_N_2_CNT          NUMBER;
    NKIHON_N_CNT            NUMBER;
    -- 更正後有資格者数
    CURSOR CKOJIN_CAL IS
      SELECT COUNT(*) CNT
        FROM ZLBTKOJIN_CAL
       WHERE KOKU_SETAI_NO    = i_NSETAI
         AND SANTEIDANTAI_CD  = i_NDANTAI
         AND CHOTEI_NENDO     = i_NNENDO
         AND NENDO_BUN        = i_NNENDO_BUN
         AND TSUCHI_NO        = i_NTSUCHI_NO
         AND ((NGFUTU_TUKI = 4 AND SHIK_4   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 5 AND SHIK_5   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 6 AND SHIK_6   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 7 AND SHIK_7   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 8 AND SHIK_8   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 9 AND SHIK_9   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 10 AND SHIK_10 IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 11 AND SHIK_11 IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 12 AND SHIK_12 IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 1 AND SHIK_1   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 2 AND SHIK_2   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 3 AND SHIK_3   IN (1,3,11,13,21,23)))
         AND SYS_TANMATSU_NO  = i_VTANMATSU;
    -- 更正前有資格者数
    CURSOR CKOJIN_N IS
      SELECT COUNT(*) CNT
        FROM ZLBTKOJIN_N
       WHERE KOKU_SETAI_NO    = i_NSETAI
         AND SANTEIDANTAI_CD  = i_NDANTAI
         AND CHOTEI_NENDO     = i_NNENDO
         AND NENDO_BUN        = i_NNENDO_BUN
         AND TSUCHI_NO        = i_NTSUCHI_NO
         AND ((NGFUTU_TUKI = 4 AND SHIK_4   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 5 AND SHIK_5   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 6 AND SHIK_6   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 7 AND SHIK_7   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 8 AND SHIK_8   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 9 AND SHIK_9   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 10 AND SHIK_10 IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 11 AND SHIK_11 IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 12 AND SHIK_12 IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 1 AND SHIK_1   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 2 AND SHIK_2   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 3 AND SHIK_3   IN (1,3,11,13,21,23)));
    -- 更正前個人データ数
    CURSOR CKOJIN_N_2 IS
      SELECT COUNT(*) CNT
        FROM ZLBTKOJIN_N
       WHERE KOKU_SETAI_NO    = i_NSETAI
         AND SANTEIDANTAI_CD  = i_NDANTAI
         AND CHOTEI_NENDO     = i_NNENDO
         AND NENDO_BUN        = i_NNENDO_BUN
         AND TSUCHI_NO        = i_NTSUCHI_NO;
    -- 更正前現在人数
    CURSOR CKIHON_N IS
      SELECT GENZAI_CNT
        FROM ZLBTKIHON_N
       WHERE KOKU_SETAI_NO    = i_NSETAI
         AND SANTEIDANTAI_CD  = i_NDANTAI
         AND CHOTEI_NENDO     = i_NNENDO
         AND NENDO_BUN        = i_NNENDO_BUN
         AND TSUCHI_NO        = i_NTSUCHI_NO;
  BEGIN
    -- 更正後有資格者数
    FOR RKOJIN_CAL IN CKOJIN_CAL LOOP
      NKOJIN_CAL_CNT := RKOJIN_CAL.CNT;
    END LOOP;
    -- 更正前有資格者数
    FOR RKOJIN_N IN CKOJIN_N LOOP
      NKOJIN_N_CNT := RKOJIN_N.CNT;
    END LOOP;
    -- 更正前有資格者数が0の場合
    IF NKOJIN_N_CNT = 0 THEN
      -- ZLBTKOJIN_Nが存在するかチェック
      FOR RKOJIN_N_2 IN CKOJIN_N_2 LOOP
        NKOJIN_N_2_CNT := RKOJIN_N_2.CNT;
      END LOOP;
      -- ZLBTKOJIN_Nが存在しない場合
      IF NKOJIN_N_2_CNT = 0 THEN
        -- ZLBTKIHON_N.GENZAI_CNTを取得する
        FOR RKIHON_N IN CKIHON_N LOOP
          NKIHON_N_CNT := RKIHON_N.GENZAI_CNT;
        END LOOP;
        IF NKIHON_N_CNT > 0 THEN
          NKOJIN_N_CNT := NKIHON_N_CNT;
        END IF;
      END IF;
    END IF;
    IF NKOJIN_CAL_CNT < NKOJIN_N_CNT THEN
      -- 世帯員喪失有り
      o_BSOSHITSU_HANTAI := FALSE;
    ELSE
      -- 世帯員喪失無し
      o_BSOSHITSU_HANTAI := TRUE;
    END IF;
    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := 'FUNCSOUSHITSUHANTEI 世帯員喪失の判断 (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        o_BSOSHITSU_HANTAI := FALSE;
        RETURN(c_SYORI_OK);
  END FUNCSOUSHITSUHANTEI;
------------------------------------------------------------------------------
-- 世帯員年齢
------------------------------------------------------------------------------
  FUNCTION FUNCSETAINENREI(o_BNENREI_HANTAI OUT BOOLEAN) RETURN NUMBER IS
    NNENREI                 PLS_INTEGER;
    NSEINENGAPI             NUMBER;
    NKOJIN_NO               NUMBER;
    NTOKU_HANTEIBI          NUMBER;
    CURSOR CKOJIN_NO IS
      SELECT *
        FROM ZLBTKOJIN_CAL
       WHERE KOKU_SETAI_NO    = i_NSETAI
         AND SANTEIDANTAI_CD  = i_NDANTAI
         AND CHOTEI_NENDO     = i_NNENDO
         AND NENDO_BUN        = i_NNENDO_BUN
         AND TSUCHI_NO        = i_NTSUCHI_NO
         AND ((NGFUTU_TUKI = 4 AND SHIK_4   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 5 AND SHIK_5   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 6 AND SHIK_6   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 7 AND SHIK_7   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 8 AND SHIK_8   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 9 AND SHIK_9   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 10 AND SHIK_10 IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 11 AND SHIK_11 IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 12 AND SHIK_12 IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 1 AND SHIK_1   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 2 AND SHIK_2   IN (1,3,11,13,21,23)) OR
              (NGFUTU_TUKI = 3 AND SHIK_3   IN (1,3,11,13,21,23)))
         AND SYS_TANMATSU_NO  = i_VTANMATSU;
  BEGIN
    FOR RKOJIN_NO IN CKOJIN_NO LOOP
      -- 生年月日を取得する
      SELECT SEINENGAPI INTO NSEINENGAPI
        FROM GABTATENAKIHON
       WHERE KOJIN_NO = RKOJIN_NO.KOJIN_NO;

      NTOKU_HANTEIBI := FUNCGETW04(i_NNENDO , NGTOKU_TUKI);
      IF NTOKU_HANTEIBI = 0 OR LENGTH(NTOKU_HANTEIBI) <> 8 THEN
         NTOKU_HANTEIBI := i_NSHORIBI;
      END IF;

      -- 年齢を取得する
      IF NSEINENGAPI > 0 THEN
          NNENREI := KKAPK0020.FAgeGet(TO_CHAR(NSEINENGAPI),TO_CHAR(NTOKU_HANTEIBI));
      ELSE
          NNENREI := NULL;
      END IF;

      -- 世帯員全員65歳未満75歳以上
      IF NNENREI < c_NNENREI_65 OR NNENREI >= c_NNENREI_75 THEN
        o_BNENREI_HANTAI := FALSE;
        RETURN(c_SYORI_OK);
      END IF;
    END LOOP;
    -- 世帯員全員65歳以上75歳未満
    o_BNENREI_HANTAI := TRUE;
    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := 'FUNCSETAINENREI 世帯員年齢の判断 (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        o_BNENREI_HANTAI := FALSE;
        RETURN(c_SYORI_OK);
  END FUNCSETAINENREI;
------------------------------------------------------------------------------
-- 世帯主年齢
------------------------------------------------------------------------------
  FUNCTION FUNCSETAIMEISHI(i_NKOJIN_NO IN NUMBER,o_NNENREI OUT NUMBER) RETURN NUMBER IS
    NSEINENGAPI           NUMBER;
    NNENREI               PLS_INTEGER;
    NNENDO                NUMBER;
    NKIJUNBI              NUMBER;
  BEGIN
    -- 生年月日を取得する
    SELECT SEINENGAPI INTO NSEINENGAPI
      FROM GABTATENAKIHON
     WHERE KOJIN_NO = i_NKOJIN_NO;

    NKIJUNBI := (i_NNENDO + 1)*10000 + 331;
    -- 年齢を取得する
    IF NSEINENGAPI > 0 THEN
        NNENREI := KKAPK0020.FAgeGet(TO_CHAR(NSEINENGAPI),TO_CHAR(NKIJUNBI));
    ELSE
        NNENREI := NULL;
    END IF;
    o_NNENREI := NNENREI;
    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := 'FUNCSETAIMEISHI 世帯主年齢の取得 (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        RETURN(c_SYORI_NG);
  END FUNCSETAIMEISHI;
------------------------------------------------------------------------------
-- 本算定の月を取得
------------------------------------------------------------------------------
  FUNCTION FUNCHONSANTEI(o_NHONSANTEI OUT NUMBER) RETURN NUMBER IS
    IRTN             PLS_INTEGER;       -- 戻り値
    NCNT             NUMBER;            -- カウント用
    CURSOR CJOKEN IS
      SELECT NOKI_1, NOKI_2, NOKI_3, NOKI_4, NOKI_5, NOKI_6, NOKI_7,
             NOKI_8, NOKI_9, NOKI_10, NOKI_11, NOKI_12, NOKI_13
        FROM ZLBTJOKEN
       WHERE NENDO = i_NNENDO
         AND SANTEIDANTAI_CD = 1;
  BEGIN
    IRTN := c_SYORI_OK;
    NCNT := 0;
    FOR RJOKEN IN CJOKEN LOOP
      -- 〆年月算出
      IF RJOKEN.NOKI_1 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('04') ;
      ELSIF RJOKEN.NOKI_2 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('05') ;
      ELSIF RJOKEN.NOKI_3 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('06') ;
      ELSIF RJOKEN.NOKI_4 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('07') ;
      ELSIF RJOKEN.NOKI_5 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('08') ;
      ELSIF RJOKEN.NOKI_6 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('09') ;
      ELSIF RJOKEN.NOKI_7 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('10') ;
      ELSIF RJOKEN.NOKI_8 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('11') ;
      ELSIF RJOKEN.NOKI_9 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('12') ;
      ELSIF RJOKEN.NOKI_10 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('01') ;
      ELSIF RJOKEN.NOKI_11 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('02') ;
      ELSIF RJOKEN.NOKI_12 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('03') ;
      ELSIF RJOKEN.NOKI_13 = c_NNOKI_HON THEN
        o_NHONSANTEI  := TO_NUMBER('04') ;
      ELSE
        -- 算定月取得失敗
        VMSG := 'FUNCHONSANTEI 本算定の月を取得 (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        IRTN := c_SYORI_NG;
      END IF;
      NCNT := NCNT + 1;
    END LOOP ;
    IF NCNT = 0 THEN
      VMSG := 'FUNCHONSANTEI 本算定の月を取得 (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
      IRTN := c_SYORI_NG;
    END IF ;
    RETURN(IRTN);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := 'FUNCHONSANTEI 本算定の月を取得 (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        IRTN := c_SYORI_NG;
        RETURN(IRTN);
  END FUNCHONSANTEI;

------------------------------------------------------------------------------
-- 期別情報(最新)存在チェック
------------------------------------------------------------------------------
FUNCTION KIBETSUCNT(o_NCNT OUT NUMBER) RETURN NUMBER IS
    NCNT            NUMBER;
    IwRTN           NUMBER;                    -- 戻り値
BEGIN
  -- 初期処理
  IwRTN := c_SYORI_OK;
  NCNT  := 0;
  BEGIN
    SELECT COUNT(1)
      INTO NCNT
      FROM ZLBTKIBETSU_N
     WHERE KAMOKU_CD        = c_NKAMOKU_CD     -- 科目コード
       AND SANTEIDANTAI_CD  = i_NDANTAI        -- 算定団体コード
       AND KOKU_SETAI_NO    = i_NSETAI         -- 世帯番号
       AND CHOTEINENDO      = i_NNENDO         -- 年度
       AND NENDOBUN         = i_NNENDO_BUN     -- 年度分
       AND TSUCHI_NO        = i_NTSUCHI_NO     -- 通知書番号
    ;
    -- 正常終了
    o_NCNT := NCNT;
    -- 異常処理
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN := c_SYORI_NG;
      VMSG := '期別情報が取得できません ' || SQLERRM;
  END;
  RETURN(IwRTN);
END KIBETSUCNT;
------------------------------------------------------------------------------
-- 普徴月判定
------------------------------------------------------------------------------
  FUNCTION FUNCFUGETSU(o_VGETSU OUT NUMBER) RETURN NUMBER IS
    VGETSU                      NVARCHAR2(20);

  BEGIN
    VGETSU   := SUBSTR(TO_CHAR(i_NSHORIBI), 5, 2);
    o_VGETSU := TO_NUMBER(VGETSU);

    -- 正常終了
    RETURN(c_SYORI_OK);

    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '処理日エラー ';
        RETURN(c_SYORI_NG);
  END FUNCFUGETSU;
------------------------------------------------------------------------------
-- 特徴異動情報から更正区分、特徴期別、中止事由を取得
------------------------------------------------------------------------------
FUNCTION FUNCKOSEIGET(o_NKOSEIKBN   OUT NUMBER
                    , o_NTOKUTUKI   OUT NUMBER
                    , o_NCHUSHIJIYU OUT NUMBER
                    ) RETURN NUMBER IS
  NKOJIN_NO             NUMBER;   -- 個人番号
  NKOSEI_KBN            NUMBER;   -- 更正区分
  NTOKU_KIBETSU_CD      NUMBER;   -- 特徴期別
  NTOKU_TUKI            NUMBER;   -- 特徴月
  NCHUSHI_JIYU          NUMBER;   -- 中止事由
  NR_NO                 NUMBER;
  NKOSEI_KBN_R          NUMBER;
  NTOKU_KIBETSU_CD_R    NUMBER;
  NCHUSHI_JIYU_R        NUMBER;

  IwRTN                 NUMBER;   -- 戻り値
  NSHORI_BI             NUMBER(8);

BEGIN
  -- 初期処理
  IwRTN := c_SYORI_OK;

  BEGIN
    -- 個人番号を取得する
    SELECT NUSHI_KOJIN_NO INTO NKOJIN_NO FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO = i_NSETAI
       AND SANTEIDANTAI_CD = i_NDANTAI
       AND CHOTEI_NENDO    = i_NNENDO
       AND NENDO_BUN       = i_NNENDO_BUN
       AND TSUCHI_NO       = i_NTSUCHI_NO
       AND SYS_TANMATSU_NO = i_VTANMATSU;
    -- 対象捕捉年度の最小処理日を取得する
    SELECT MIN(SHORI_BI)
      INTO NSHORI_BI
      FROM ZLBTSHORI_JYOTAI_KR
     WHERE HOSOKU_NENDO = (SELECT MAX(HOSOKU_NENDO)
                           FROM   ZLBTSHORI_JYOTAI_KR);
-- ①現在の世帯主で特徴開始のデータが存在しないかチェック
--   年次処理日以降の対象についてチェックを行う
    BEGIN
      SELECT KOSEI_KBN                       -- 更正区分
           , TOKU_KIBETSU_CD                 -- 特徴期別
           , CHUSHI_JIYU                     -- 中止事由
           , R_NO                            -- 履歴番号
        INTO NKOSEI_KBN
           , NTOKU_KIBETSU_CD
           , NCHUSHI_JIYU
           , NR_NO
        FROM ZLBTTOKU_IDO                     -- 異動情報
       WHERE KOKU_SETAI_NO = i_NSETAI         -- 国保世帯番号
         AND KOJIN_NO  = NKOJIN_NO            -- 世帯主個人番号
         AND KOSEI_KBN = 2                    -- 更正区分  =特徴開始
         AND SYORI_FLG = 0                    -- 処理フラグ=未処理
         AND R_NO      = (                    -- 履歴番号の最大値
                           SELECT MAX(R_NO)
                             FROM ZLBTTOKU_IDO
                            WHERE KOJIN_NO = NKOJIN_NO
                              AND KOKU_SETAI_NO  = i_NSETAI
                              AND SYS_SAKUSEIBI  >= NSHORI_BI
                         );
    EXCEPTION
      WHEN OTHERS THEN
        NKOSEI_KBN       := 0;
        NTOKU_KIBETSU_CD := 0;
        NCHUSHI_JIYU     := 0;
        NR_NO            := 0;
    END;
-- ②①でデータ取得出来なかった場合は、特徴対象者情報の特徴対象者個人番号で特徴中止のデータを取得
    IF NKOSEI_KBN = 0 THEN
--      -- 特徴対象者情報から個人番号を取得する  ※取得できない場合は異常処理へ
      -- 翌年度通知書番号>0時は、翌年度の特徴対象者情報から個人番号を取得
      --(翌年度～特徴開始の場合、個人番号が取得できない件の対応)
      IF NGTSUCHINO_Y > 0 THEN
        -- 翌年度
        SELECT TOKU_KOJIN_NO INTO NKOJIN_NO FROM ZLBTTOKU_KIHON_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NNENDO     + 1
           AND NENDO_BUN       = i_NNENDO_BUN + 1
           AND TSUCHI_NO       = NGTSUCHINO_Y
           AND SYS_TANMATSU_NO = i_VTANMATSU;
      ELSE
        -- 現年度
        SELECT TOKU_KOJIN_NO INTO NKOJIN_NO FROM ZLBTTOKU_KIHON_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NTSUCHI_NO
           AND SYS_TANMATSU_NO = i_VTANMATSU;
      END IF;
      -- 異動情報から特徴中止のデータを取得する※取得できない場合は異常処理へ
      SELECT KOSEI_KBN                       -- 更正区分
           , TOKU_KIBETSU_CD                 -- 特徴期別
           , CHUSHI_JIYU                     -- 中止事由
           , R_NO                            -- 履歴番号
        INTO NKOSEI_KBN
           , NTOKU_KIBETSU_CD
           , NCHUSHI_JIYU
           , NR_NO
        FROM ZLBTTOKU_IDO                     -- 異動情報
       WHERE KOKU_SETAI_NO = i_NSETAI         -- 国保世帯番号
         AND KOJIN_NO  = NKOJIN_NO            -- 世帯主個人番号
         AND KOSEI_KBN = 1                    -- 更正区分  =特徴中止
         AND SYORI_FLG = 0                    -- 処理フラグ=未処理
         AND R_NO      = (                    -- 履歴番号の最大値
                           SELECT MAX(R_NO)
                             FROM ZLBTTOKU_IDO
                            WHERE KOJIN_NO = NKOJIN_NO
                              AND KOKU_SETAI_NO = i_NSETAI
                         );
    END IF;

    -- 最新の中止事由が1/2判定NG＆
    -- 前履歴が徴収結果NGの場合、中止情報を置換（1/2判定NG→徴収結果NG）
    IF NCHUSHI_JIYU > 80 AND NCHUSHI_JIYU < 90 THEN
      BEGIN
        SELECT KOSEI_KBN                       -- 更正区分
             , TOKU_KIBETSU_CD                 -- 特徴期別
             , CHUSHI_JIYU                     -- 中止事由
          INTO NKOSEI_KBN_R
             , NTOKU_KIBETSU_CD_R
             , NCHUSHI_JIYU_R
          FROM ZLBTTOKU_IDO                    -- 異動情報
         WHERE KOJIN_NO  = NKOJIN_NO           -- 個人番号
           AND SYORI_FLG = 0                   -- 処理フラグ
           AND R_NO      = NR_NO - 1           -- 履歴番号の最大値-1
        ;
        IF (NCHUSHI_JIYU_R > 70 AND NCHUSHI_JIYU_R < 80) THEN
          -- 置換
          NKOSEI_KBN := NKOSEI_KBN_R;
          NTOKU_KIBETSU_CD := NTOKU_KIBETSU_CD_R;
          NCHUSHI_JIYU := NCHUSHI_JIYU_R;
        END IF;
      -- 異常処理
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    -- 特徴期別から取得し月に変換
    IF NTOKU_KIBETSU_CD IS NOT NULL THEN
      CASE NTOKU_KIBETSU_CD
        WHEN  1 THEN
          NTOKU_TUKI := 4;
        WHEN  2 THEN
          NTOKU_TUKI := 5;
        WHEN  3 THEN
          NTOKU_TUKI := 6;
        WHEN  4 THEN
          NTOKU_TUKI := 7;
        WHEN  5 THEN
          NTOKU_TUKI := 8;
        WHEN  6 THEN
          NTOKU_TUKI := 9;
        WHEN  7 THEN
          NTOKU_TUKI := 10;
        WHEN  8 THEN
          NTOKU_TUKI := 11;
        WHEN  9 THEN
          NTOKU_TUKI := 12;
        WHEN 10 THEN
          NTOKU_TUKI := 1;
        WHEN 11 THEN
          NTOKU_TUKI := 2;
        WHEN 12 THEN
          NTOKU_TUKI := 3;
        ELSE
          NTOKU_TUKI := NULL;
      END CASE;
    END IF;

    -- 正常終了(更正区分・特徴月・中止事由セット)
    o_NKOSEIKBN    := NKOSEI_KBN;
    o_NTOKUTUKI    := NTOKU_TUKI;
    o_NCHUSHIJIYU  := NCHUSHI_JIYU;

  -- 異常処理
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN := c_SYORI_NG;
      o_NKOSEIKBN        := NULL;
      o_NTOKUTUKI        := NULL;
      o_NCHUSHIJIYU      := NULL;
  END;
  RETURN(IwRTN);
END FUNCKOSEIGET;
------------------------------------------------------------------------------
-- 特徴月判定
------------------------------------------------------------------------------
  FUNCTION FUNCTOKUGETSU RETURN NUMBER IS
    NTOKUCHO_HOSOKU         NUMBER;             -- 6・8月分特徴追加補足の扱い
    NGETSU                  NUMBER;             -- 作成年月日(月)
    NSAKUSEBI               NUMBER;             -- 作成年月日
    NTUTI_NENGETU           NUMBER;             -- 通知年月
    NCMP_NENDO              NUMBER;             -- 通知年（賦課年度変換後）
    NCMP_TUKI               NUMBER;             -- 通知月
    NRTN                    NUMBER;             -- 戻り値
    NCNT                    NUMBER;             -- システム条件件数
    NNENDOBUN               NUMBER;             -- 年度分（前年度・現年度）
    NTOKU_KBN               NUMBER(1);          -- 特徴実施区分
   NwTOKU_TUKI              NUMBER(3) := 0;     -- 特徴月
   NwTOKU_TUKI_IDO          NUMBER(3) := 0;     -- 特徴月(異動情報から)
   NwTOKU_TUKI_SHORI        NUMBER(3) := 0;     -- 特徴月(処理状態から)
   IHANTEI_MODE                  NUMBER := 0;

  BEGIN
    IHANTEI_MODE := ZLBPK00010.FCFFJKN2(81);
    -- 特徴異動情報から特徴月を取得
    NRTN := FUNCKOSEIGET(NGKOSEI_CD
                       , NGTOKU_TUKI
                       , NGCHUSHI_JIYU
                       );

    BEGIN

      -- システム条件にデータがあるか確認
      SELECT COUNT(*)
        INTO NCNT
        FROM ZLBTJOKEN                       -- システム条件
       WHERE NENDO           = i_NNENDO      -- 年度
         AND SANTEIDANTAI_CD = 1;            -- 算定団体コード


      IF NCNT = 0 THEN
        -- システム条件にデータが無い場合は、前年度を設定
        NNENDOBUN := i_NNENDO_BUN - 1;
      ELSE
        -- システム条件にデータがある場合は、現年度を設定
        NNENDOBUN := i_NNENDO_BUN;
      END IF;

      -- システム条件から6・8月分特徴追加補足の扱いを取得する。
--        FROM ZLBTJOKEN                       -- システム条件
--       WHERE NENDO           = NNENDOBUN     -- 年度
--         AND SANTEIDANTAI_CD = 1;            -- 算定団体コード
      SELECT TOKUCHO_HOSOKU,TOKU_KBN
        INTO NTOKUCHO_HOSOKU,NTOKU_KBN
        FROM ZLBTJOKEN                       -- システム条件
       WHERE NENDO           = NNENDOBUN     -- 年度
         AND SANTEIDANTAI_CD = 1;            -- 算定団体コード

      -- 特徴実施区分=実施しないであれば特徴月=0で終了
      IF NTOKU_KBN = c_NJISHINAI_TOKU THEN
        NGTOKU_TUKI := 0;
        NlTUTI_TUKI := 0;
        RETURN(c_SYORI_OK);
      END IF;

        -- 処理状態管理から依頼データ作成 最新作成日（月）を取得
        SELECT MAX(TUTI_NENGETU)               -- 通知年月
          INTO NTUTI_NENGETU
          FROM ZLBTSHORI_JYOTAI_KR          -- 処理状態管理
         WHERE SHORI_SHUBETU   = 7;         -- 処理種別

        NCMP_NENDO := TO_NUMBER(SUBSTR(TO_CHAR(NTUTI_NENGETU), 1, 4));
        NCMP_TUKI  := TO_NUMBER(SUBSTR(TO_CHAR(NTUTI_NENGETU), 5, 2));
        -- ６月送付済みで本算定処理以外開始判定しない場合は特徴月=0で終了(６月本算定の６月末月例で再判定しない)
        IF IHANTEI_MODE = 1 THEN
          -- ６月送付前に本算定計算の場合は６月送付済みとして特徴開始処理する
          IF NCMP_TUKI < 6 AND i_NJIKKOU_KBN = 0 THEN
            NCMP_TUKI := 6 ;
          END IF;
          IF (i_NJIKKOU_KBN = 9  AND TO_NUMBER(SUBSTR(TO_CHAR(i_NSHORIBI), 5, 2)) = 6) AND NCMP_TUKI < 6 THEN
            NCMP_TUKI := 6 ;
          END IF;
        END IF;
        NGETSU := NCMP_TUKI;
        NlTUTI_TUKI := NCMP_TUKI; -- 通知月を外部変数にセット

    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '特徴月判定エラー ' || SQLERRM;
        RETURN(c_SYORI_NG);
    END;

-- 特徴異動情報が特徴開始の場合、処理状態管理から判定した特徴開始可能月と同じかチェックを追加
-- 処理状態管理から判定した特徴開始可能月と異なる場合は、特徴異動情報の特徴開始は無視する。
    IF NRTN = c_SYORI_OK           AND   -- 特徴異動情報取得
       NGKOSEI_CD = c_NTOKU_KEISAN THEN  -- 特徴開始
      -- 特徴開始月セーブおよび処理状態管理から特徴月を取得させる
      NwTOKU_TUKI := NGTOKU_TUKI;
      NRTN        := c_SYORI_NG;
    ELSE
      NwTOKU_TUKI := 0;
    END IF;

    -- 特徴異動情報がデータ無しの場合、処理状態管理から特徴月を取得
    IF NRTN = c_SYORI_NG THEN

      -- 初回異動データ(4月)以降は以下で設定
      CASE NGETSU
        WHEN  1 THEN
          NGTOKU_TUKI := 104;
        WHEN  2 THEN
          NGTOKU_TUKI := 106;
        WHEN  3 THEN
          NGTOKU_TUKI := 106;
        WHEN  4 THEN
          NGTOKU_TUKI := 8;
        WHEN  5 THEN
          NGTOKU_TUKI := 8;
        WHEN  6 THEN
          NGTOKU_TUKI := 10;
        WHEN  7 THEN
          NGTOKU_TUKI := 10;
        WHEN  8 THEN
          IF NTOKUCHO_HOSOKU = 0 AND BYOKU4STOP THEN
            NGTOKU_TUKI := 104;
          ELSE
            NGTOKU_TUKI := 12;
          END IF;
        WHEN  9 THEN
          IF NTOKUCHO_HOSOKU = 0 AND BYOKU4STOP THEN
            NGTOKU_TUKI := 104;
          ELSE
            NGTOKU_TUKI := 12;
          END IF;
        WHEN 10 THEN
          IF NTOKUCHO_HOSOKU = 0 AND BYOKU4STOP THEN
            NGTOKU_TUKI := 104;
          ELSE
            NGTOKU_TUKI := 2;
          END IF;
        WHEN 11 THEN
          IF NTOKUCHO_HOSOKU = 0 AND BYOKU4STOP THEN
            NGTOKU_TUKI := 104;
          ELSE
            NGTOKU_TUKI := 2;
          END IF;
        WHEN 12 THEN
          NGTOKU_TUKI := 104;
      END CASE;
    END IF;

-- 特徴異動情報が特徴開始の場合、処理状態管理から判定した特徴開始可能月と同じかチェックを追加
-- 処理状態管理から判定した特徴開始可能月と異なる場合は、特徴異動情報の特徴開始は無視する。
    IF NGKOSEI_CD  =  c_NTOKU_KEISAN AND  -- 特徴開始
       NwTOKU_TUKI <> 0              THEN -- 特徴開始月セーブ済み
      -- 翌年度月(104/106)を比較可能値(4/6)に変換
      NwTOKU_TUKI_IDO   := MOD(NwTOKU_TUKI,100);     -- 特徴月(異動情報から)
      NwTOKU_TUKI_SHORI := MOD(NGTOKU_TUKI,100);     -- 特徴月(処理状態から)
      IF NwTOKU_TUKI_IDO <> NwTOKU_TUKI_SHORI THEN
        -- 特徴異動情報の特徴開始月<>処理状態管理から判定した特徴開始可能月
        -- ->普徴とする。
        NGKOSEI_CD    := NULL;
        NGCHUSHI_JIYU := NULL;
      ELSE
        -- 特徴異動情報の特徴開始月=処理状態管理から判定した特徴開始可能月
        -- ->特徴開始とする。
        NGTOKU_TUKI := NwTOKU_TUKI;
      END IF;
    END IF;

    -- 特徴月を変換。翌年度キーで特徴異動可否区分を設定
    IF NGTOKU_TUKI IS NOT NULL THEN


        IF NCMP_TUKI >= 1 AND NCMP_TUKI <= 3 THEN
           NCMP_NENDO := NCMP_NENDO - 1;
        END IF;
      -- 特徴月を変換
      IF NGTOKU_TUKI = 4   OR NGTOKU_TUKI = 6 THEN
        -- 特徴開始の場合、特徴月を変換（4→104,6→106）
        IF NGKOSEI_CD = 2 THEN
          NGTOKU_TUKI := NGTOKU_TUKI + 100;
        -- 特徴中止、特徴依頼取消の場合、翌年度通知書番号が有（4→104,6→106）
        ELSIF NCMP_NENDO = i_NNENDO AND (NCMP_TUKI >= 8 OR NCMP_TUKI <= 3) THEN
          NGTOKU_TUKI := NGTOKU_TUKI + 100;
        ELSIF NCMP_NENDO <> i_NNENDO AND (NCMP_TUKI >= 4 AND NCMP_TUKI <= 7) THEN
          NGTOKU_TUKI := NGTOKU_TUKI + 100;
        END IF;
      ELSIF NGTOKU_TUKI = 104 OR NGTOKU_TUKI = 106 THEN
        -- 特徴中止、特徴依頼取消の場合、翌年度通知書番号が無（104→4,106→6）
        IF NCMP_NENDO <> i_NNENDO AND (NCMP_TUKI >= 8 OR NCMP_TUKI <= 3) THEN
          NGTOKU_TUKI := NGTOKU_TUKI - 100;
        ELSIF NCMP_NENDO = i_NNENDO AND (NCMP_TUKI >= 4 AND NCMP_TUKI <= 7) THEN
          NGTOKU_TUKI := NGTOKU_TUKI - 100;
        END IF;
      END IF;

      -- 翌年度キーで特徴異動可否区分を設定
      IF NCMP_NENDO < i_NNENDO THEN                     -- キーが翌年度
        NGYOKU_IDO_FLG := 0;                            -- 初期セット（翌年度の異動不可）
        IF NGTOKU_TUKI >= 4 AND NGTOKU_TUKI <= 6 THEN   -- 特徴月が４、６、８月
          IF (NCMP_TUKI >= 8 OR NCMP_TUKI <= 3) THEN    -- 期間が８月～３月まで
            NGYOKU_IDO_FLG := 1;                        -- 翌年度の異動可能
          END IF;
        END IF;
      END IF;
      -- 前年度キー＆特徴月８月の場合、特徴異動可否区分を設定
    END IF;

    -- 正常終了
    RETURN(c_SYORI_OK);
  END FUNCTOKUGETSU;
------------------------------------------------------------------------------
-- 特徴実施区分を取得
------------------------------------------------------------------------------
  FUNCTION FUNCJYOKENGET RETURN NUMBER IS
    NTOKU_KBN            NUMBER;
  BEGIN
    SELECT TOKU_KBN                         -- 特徴実施区分
      INTO NTOKU_KBN
      FROM ZLBTJOKEN                        -- システム条件
     WHERE NENDO           = i_NNENDO_BUN   -- 年度
       AND SANTEIDANTAI_CD = 1;             -- 算定団体コード

    -- 正常終了
    RETURN(NTOKU_KBN);

    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '特徴実施区分を取得できません ' || SQLERRM;
        NTOKU_KBN := -1;
        RETURN(NTOKU_KBN);
  END FUNCJYOKENGET;

------------------------------------------------------------------------------
-- 特徴中止判定
------------------------------------------------------------------------------
  FUNCTION FUNCCHUSHIHANTEI(i_NKOJIN_NO IN NUMBER) RETURN NUMBER IS
    NTSUCHI_NO_Y NUMBER;
  BEGIN
    -- 初期化
    NINS_FLG := 0;
    -- ①ZLBTSHORI_JYOTAI_KRより通知年月を取得し特徴中止期別を算出する
    SELECT MAX(TUTI_NENGETU) INTO NTUTI_NENGETU  -- 通知年月
      FROM ZLBTSHORI_JYOTAI_KR                -- 処理状態管理
     WHERE SHORI_SHUBETU   = 7;                  -- 処理種別
    -- 通知年月をセット
    NCMP_TUKI := TO_NUMBER(SUBSTR(TO_CHAR(NTUTI_NENGETU), 5, 2));
    -- 通知年月より特徴中止期別を算出する
    CASE NCMP_TUKI
      WHEN  1 THEN
        NTOKU_KIBETSU_CD := 1;
      WHEN  2 THEN
        NTOKU_KIBETSU_CD := 3;
      WHEN  3 THEN
        NTOKU_KIBETSU_CD := 3;
      WHEN  4 THEN
        NTOKU_KIBETSU_CD := 5;
      WHEN  5 THEN
        NTOKU_KIBETSU_CD := 5;
      WHEN  6 THEN
        NTOKU_KIBETSU_CD := 7;
      WHEN  7 THEN
        NTOKU_KIBETSU_CD := 7;
      WHEN  8 THEN
        NTOKU_KIBETSU_CD := 9;
      WHEN  9 THEN
        NTOKU_KIBETSU_CD := 9;
      WHEN 10 THEN
        NTOKU_KIBETSU_CD := 11;
      WHEN 11 THEN
        NTOKU_KIBETSU_CD := 11;
      WHEN 12 THEN
        NTOKU_KIBETSU_CD := 1;
    END CASE;
    -- ②特徴中止期別に特徴税額があるかどうかをチェックする
    -- 翌年度情報を参照する
    IF NTOKU_KIBETSU_CD IN (1,3,5) AND IZAN_MODE = 0 THEN
      BEGIN
        -- 翌年度通知書番号の取得
        SELECT YOKU_TSUCHI_NO INTO NTSUCHI_NO_Y
          FROM ZLBTKIHON_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NTSUCHI_NO
           AND SYS_TANMATSU_NO = i_VTANMATSU;
      -- 異常処理
      EXCEPTION
        WHEN OTHERS THEN
          NTSUCHI_NO_Y := 0;
      END;
      IF NTSUCHI_NO_Y > 0 THEN
        BEGIN
          SELECT NVL(COUNT(*),0) INTO NTOKU_KIWARI_CNT
            FROM ZLBTKIBETSU_N
           WHERE KAMOKU_CD = 15
             AND KAMOKUS_CD = 2
             AND KOKU_SETAI_NO   = i_NSETAI
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEINENDO     = i_NNENDO + 1
             AND NENDOBUN        = i_NNENDO_BUN + 1
             AND TSUCHI_NO       = NTSUCHI_NO_Y
             AND RONRIKIBETSU    = NTOKU_KIBETSU_CD
             AND ZEN_ZEIGAKU     > 0;
        -- 異常処理
        EXCEPTION
          WHEN OTHERS THEN
            NTOKU_KIWARI_CNT := 0;
        END;
      END IF;
    ELSE
      BEGIN
        SELECT NVL(COUNT(*),0) INTO NTOKU_KIWARI_CNT
          FROM ZLBTKIBETSU_N
         WHERE KAMOKU_CD = 15
           AND KAMOKUS_CD = 2
           AND KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEINENDO     = i_NNENDO
           AND NENDOBUN        = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NTSUCHI_NO
           AND RONRIKIBETSU    = NTOKU_KIBETSU_CD
           AND ZEN_ZEIGAKU     > 0;
      -- 異常処理
      EXCEPTION
        WHEN OTHERS THEN
          NTOKU_KIWARI_CNT := 0;
      END;
    END IF;
    -- ③特徴税額がある場合ZLBTTOKU_IDOにデータ登録を行う
    IF NTOKU_KIWARI_CNT > 0 THEN
      BEGIN
        -- 特徴異動テーブルに既に特徴中止情報が存在するかをチェックする
        SELECT NVL(COUNT(*),0) INTO NTOKU_IDO_CNT
          FROM ZLBTTOKU_IDO
         WHERE KOKU_SETAI_NO   = i_NSETAI             -- 国保世帯番号
           AND KOJIN_NO        = i_NKOJIN_NO          -- 世帯主個人番号
           AND KOSEI_KBN       = 1                    -- 更正区分  =特徴中止
           AND TOKU_KIBETSU_CD = NTOKU_KIBETSU_CD     -- 特徴期別
           AND SYORI_FLG       = 0                    -- 処理フラグ=未処理
           AND R_NO            =                      -- 履歴番号の最大値
              (SELECT MAX(R_NO)
                 FROM ZLBTTOKU_IDO
                WHERE KOKU_SETAI_NO = i_NSETAI
                  AND KOJIN_NO      = i_NKOJIN_NO
                  AND SYS_SAKUSEIBI  >=
                      -- 対象捕捉年度の最小処理日を取得する
                     (SELECT MIN(SHORI_BI)
                        FROM ZLBTSHORI_JYOTAI_KR
                       WHERE HOSOKU_NENDO =
                            (SELECT MAX(HOSOKU_NENDO)
                               FROM ZLBTSHORI_JYOTAI_KR)));
      EXCEPTION
        WHEN OTHERS THEN
          NTOKU_IDO_CNT := 0;
      END;
      -- 特徴中止情報が存在しない場合
      IF NTOKU_IDO_CNT = 0 THEN
        -- 最大履歴連番を取得する
        BEGIN
          SELECT NVL(MAX(R_NO),0) INTO NRIREKI_NO
            FROM ZLBTTOKU_IDO
           WHERE KOKU_SETAI_NO  = i_NSETAI
             AND KOJIN_NO       = i_NKOJIN_NO
           GROUP BY KOKU_SETAI_NO,
                    KOJIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
            NRIREKI_NO := 0;
        END;
        -- ZLBTTOKU_IDOを作成する
        INSERT INTO ZLBTTOKU_IDO
        VALUES (i_NSETAI,
                i_NKOJIN_NO,
                NRIREKI_NO + 1,
                1,
                NTOKU_KIBETSU_CD,
                0,
                3,
                TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),
                TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),
                TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS')),
                0,
                i_VTANMATSU);
        -- INSERTフラグに1をセットする
        NINS_FLG := 1;
      END IF;
    END IF;
    RETURN(c_SYORI_OK);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(c_SYORI_NG);
  END FUNCCHUSHIHANTEI;
------------------------------------------------------------------------------
-- 特徴中止判定（仮算定異動計算時）
------------------------------------------------------------------------------
  FUNCTION FUNCCHUSHIHANTEI_KARI(i_NKOJIN_NO IN NUMBER) RETURN NUMBER IS
    NSHIK_GETSU                  NUMBER;        -- 特徴月の資格
    TYPE CSHIK_GETSU             IS REF CURSOR; -- カーソル
    CRSHIK_GETSU                 CSHIK_GETSU;
    VSQL                         VARCHAR2(300);
    BNENREI_HANTAI               BOOLEAN;          -- 全員年齢判断
    BSOSHITSU_HANTAI             BOOLEAN;          -- 世帯員喪失判断
  BEGIN
    -- 世帯主が喪失しているかどうか
    VSQL := 'SELECT ' || 'SHIK_' || TO_CHAR(NGFUTU_TUKI);
    VSQL := VSQL || ' FROM ZLBTKOJIN_CAL ';
    VSQL := VSQL || ' WHERE KOKU_SETAI_NO = '  || i_NSETAI;
    VSQL := VSQL || '  AND KOJIN_NO = '        || i_NKOJIN_NO;
    VSQL := VSQL || '  AND SANTEIDANTAI_CD = ' || i_NDANTAI;
    VSQL := VSQL || '  AND CHOTEI_NENDO = '    || i_NNENDO;
    VSQL := VSQL || '  AND NENDO_BUN = '       || i_NNENDO_BUN;
    VSQL := VSQL || '  AND TSUCHI_NO = '       || i_NTSUCHI_NO;
    VSQL := VSQL || '  AND SYS_TANMATSU_NO = ' || '''' || i_VTANMATSU || '''';
    -- 各月の資格区分を取得する
    OPEN CRSHIK_GETSU FOR VSQL;
      FETCH CRSHIK_GETSU INTO NSHIK_GETSU;
    CLOSE CRSHIK_GETSU;
    -- 各月の資格区分!＝1 or 11 or 21
    IF NSHIK_GETSU NOT IN (1, 11, 21) THEN
      NRETURN := FUNCCHUSHIHANTEI(i_NKOJIN_NO);
      IF NRETURN <> c_SYORI_OK THEN
        RETURN(c_SYORI_NG);
      END IF;
    ELSE
      -- 世帯員年齢を判断する
      NRETURN := FUNCSETAINENREI(BNENREI_HANTAI);
      IF NRETURN <> c_SYORI_OK THEN
        RETURN(c_SYORI_NG);
      END IF;
      -- 世帯員全員65歳以上75歳未満
      IF BNENREI_HANTAI = FALSE THEN
        NRETURN := FUNCCHUSHIHANTEI(i_NKOJIN_NO);
        IF NRETURN <> c_SYORI_OK THEN
          RETURN(c_SYORI_NG);
        END IF;
      ELSE
        -- 世帯員が喪失しているかどうか
        NRETURN := FUNCSOUSHITSUHANTEI(BSOSHITSU_HANTAI);
        IF NRETURN <> c_SYORI_OK THEN
          RETURN(c_SYORI_NG);
        END IF;
        -- 世帯員が喪失している場合
        IF BSOSHITSU_HANTAI = FALSE THEN
          NRETURN := FUNCCHUSHIHANTEI(i_NKOJIN_NO);
          IF NRETURN <> c_SYORI_OK THEN
            RETURN(c_SYORI_NG);
          END IF;
        END IF;
      END IF;
    END IF;
    RETURN(c_SYORI_OK);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(c_SYORI_NG);
  END FUNCCHUSHIHANTEI_KARI;

------------------------------------------------------------------------------
--計算1/2判定
------------------------------------------------------------------------------
  FUNCTION FUNCHALFHANTEI(i_NKOJIN_NO IN NUMBER) RETURN NUMBER IS
    NwRTN           NUMBER(2); --処理結果
    NwHALFHANTEI    NUMBER(2);
    NwHANTEI_KEKKA  NUMBER(2) := 0; --処理結果
  BEGIN
    NwHALFHANTEI := ZLBPK00010.FCFFJKN2(70);
    IF NwHALFHANTEI = 1 THEN --1/2タイミング条件取得(1のときのみ)
--1/2判定呼び出し
      NwRTN := ZLBFCCALHALFHT (i_NSETAI,        -- 国保世帯番号
                                 i_NDANTAI,        -- 算定団体コード
                                 i_NNENDO,         -- 調定年度
                                 i_NNENDO_BUN,     -- 年度分
                                 i_NTSUCHI_NO,     -- 通知書番号
                                 i_NKOJIN_NO,      -- 個人番号
                                 i_VTANMATSU,      -- 端末番号
                                 NwHANTEI_KEKKA);  -- 判定結果（1以外は、特徴不可）
      IF NwHANTEI_KEKKA <> 1 OR NwRTN = c_SYORI_NG THEN
        NHANTEI_KEKKA := 1;
      END IF;
    END IF;
    RETURN(c_SYORI_OK);
    -- 異常処理
  EXCEPTION
    WHEN OTHERS THEN
    NHANTEI_KEKKA := 1;
    RETURN(c_SYORI_OK);
  END FUNCHALFHANTEI;

------------------------------------------------------------------------------
-- 計算特徴対象者情報を取得
------------------------------------------------------------------------------
FUNCTION FUNCTOKUJOHOGET RETURN NUMBER IS
  NwNENDO                 NUMBER;    -- 年度
  NwNENDOBUN              NUMBER;    -- 年度分
  NTSUCHI_NO              NUMBER;    -- 通知書番号
  NJOTAI_KBN_G            NUMBER(1) := 0;      -- 特徴状態(現年）
  NKAISHI_TSUKI_G         NUMBER(2) := 0;      -- 特徴開始月(現年）
  NTAISYOJOHO_KENSU_G     NUMBER(1) := 0;      -- 対象件数(現年）
  NJOTAI_KBN_Y            NUMBER(1) := 0;      -- 特徴状態(翌年）
  NKAISHI_TSUKI_Y         NUMBER(2) := 0;      -- 特徴開始月(翌年）
  NTAISYOJOHO_KENSU_Y     NUMBER(1) := 0;      -- 対象件数(翌年）
  NIRAI_HIZUKE_G          NUMBER(8) := 0;      --依頼日付(現年）----
  NRETURN                 NUMBER(2) := 0;      -- 処理結果

BEGIN
    NwNENDO := i_NNENDO;
    NwNENDOBUN := i_NNENDO_BUN;
    NTSUCHI_NO := i_NTSUCHI_NO;

  -- 現年レコード検索
  SELECT COUNT(1)
    INTO NTAISYOJOHO_KENSU_G
    FROM ZLBTTOKU_KIHON_CAL                    -- 計算・特徴対象者情報
   WHERE KOKU_SETAI_NO    = i_NSETAI           -- 国保世帯番号
     AND SANTEIDANTAI_CD  = i_NDANTAI          -- 算定団体コード
     AND CHOTEI_NENDO     = NwNENDO            -- 年度(現年)
     AND NENDO_BUN        = NwNENDOBUN         -- 年度分(現年)
     AND TSUCHI_NO        = NTSUCHI_NO         -- 通知書番号
     AND SYS_TANMATSU_NO  = i_VTANMATSU        -- 更新端末番号
  ;
  IF NTAISYOJOHO_KENSU_G = 1 THEN
     BEGIN
       SELECT JOTAI_KBN                           -- 状態区分
            , KAISHI_TSUKI                        -- 特徴開始月
            , IRAI_HIZUKE                         --特徴以来日
         INTO NJOTAI_KBN_G
            , NKAISHI_TSUKI_G
            , NIRAI_HIZUKE_G
         FROM ZLBTTOKU_KIHON_CAL                  -- 計算・特徴対象者情報
        WHERE KOKU_SETAI_NO    = i_NSETAI         -- 国保世帯番号
          AND SANTEIDANTAI_CD  = i_NDANTAI        -- 算定団体コード
          AND CHOTEI_NENDO     = NwNENDO          -- 年度(現年)
          AND NENDO_BUN        = NwNENDOBUN       -- 年度分(現年)
          AND TSUCHI_NO        = NTSUCHI_NO       -- 通知書番号
          AND SYS_TANMATSU_NO  = i_VTANMATSU      -- 更新端末番号
       ;
     -- 異常処理
     EXCEPTION
         WHEN OTHERS THEN
           VMSG := '計算特徴対象者情報が取得できません ' || SQLERRM;
           RETURN(c_SYORI_NG);
     END;
  END IF;

  BEGIN
    SELECT NUSHI_KOJIN_NO INTO NNUSHI_KOJIN_NO
    FROM ZLBTKIHON_CAL
       WHERE KOKU_SETAI_NO    = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD  = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO     = NwNENDO          -- 年度
       AND NENDO_BUN        = NwNENDOBUN       -- 年度分
       AND TSUCHI_NO        = NTSUCHI_NO       -- 通知書番号
       AND SYS_TANMATSU_NO  = i_VTANMATSU;     -- 更新端末番号
  -- 異常処理
  EXCEPTION
     WHEN OTHERS THEN
       NNUSHI_KOJIN_NO := 0;
  END;
  IF (NNUSHI_KOJIN_NO IS NOT NULL AND NNUSHI_KOJIN_NO <> 0) THEN
    BEGIN
      SELECT NVL(COUNT(*),0) INTO NKOZAKIRIKAE
      FROM ZLBTKOZAKIRIKAE
      WHERE KOJIN_NO = NNUSHI_KOJIN_NO
        AND SAKUJO_KBN = 0
        AND SHINSEI_KBN IN (1,3)
        AND R_NO = (SELECT MAX(R_NO) FROM ZLBTKOZAKIRIKAE WHERE KOJIN_NO = NNUSHI_KOJIN_NO);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        NKOZAKIRIKAE := 0;
    END;
  --口座申請無しかつ本算定期かつ現年特徴対象情報有りの人を1/2判定
    IF NKOZAKIRIKAE = 0 AND i_NJIKKOU_KBN = 0 THEN
      NRETURN := FUNCHALFHANTEI(NNUSHI_KOJIN_NO);
      IF NHANTEI_KEKKA <> 0 THEN
        NKOZAKIRIKAE := NHANTEI_KEKKA;
      END IF;
    -- 口座申請有りの場合中止判定を行う
    ELSIF NKOZAKIRIKAE > 0 THEN
      NRETURN := FUNCCHUSHIHANTEI(NNUSHI_KOJIN_NO);
      IF NRETURN = c_SYORI_NG THEN
        VMSG := '口座申請特徴中止判定に失敗しました ' || SQLERRM;
        RETURN(c_SYORI_NG);
      END IF;
    -- 仮算定異動計算時の特徴中止判定を行う
    ELSIF IZAN_MODE = 1 THEN
      NRETURN := FUNCCHUSHIHANTEI_KARI(NNUSHI_KOJIN_NO);
      IF NRETURN = c_SYORI_NG THEN
        VMSG := '仮算定異動計算時の特徴中止判定に失敗しました ' || SQLERRM;
        RETURN(c_SYORI_NG);
      END IF;
    END IF;
  END IF;
  -- 翌年度通知書番号取得
  NGTSUCHINO_Y := 0;
  SELECT YOKU_TSUCHI_NO
      INTO NGTSUCHINO_Y
      FROM ZLBTKIHON_CAL                       -- 計算・基本情報
     WHERE KOKU_SETAI_NO    = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD  = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO     = NwNENDO          -- 年度
       AND NENDO_BUN        = NwNENDOBUN       -- 年度分
       AND TSUCHI_NO        = NTSUCHI_NO       -- 通知書番号
       AND SYS_TANMATSU_NO  = i_VTANMATSU;     -- 更新端末番号
  NwNENDO    := NwNENDO + 1;
  NwNENDOBUN := NwNENDOBUN + 1;
  NTSUCHI_NO := NGTSUCHINO_Y;
  -- 翌年レコード検索
  SELECT COUNT(1)
    INTO NTAISYOJOHO_KENSU_Y
    FROM ZLBTTOKU_KIHON_CAL                    -- 計算・特徴対象者情報
   WHERE KOKU_SETAI_NO    = i_NSETAI           -- 国保世帯番号
     AND SANTEIDANTAI_CD  = i_NDANTAI          -- 算定団体コード
     AND CHOTEI_NENDO     = NwNENDO            -- 年度(翌年)
     AND NENDO_BUN        = NwNENDOBUN         -- 年度分(翌年)
     AND TSUCHI_NO        = NTSUCHI_NO         -- 通知書番号
     AND SYS_TANMATSU_NO  = i_VTANMATSU        -- 更新端末番号
  ;
  IF NTAISYOJOHO_KENSU_Y = 1 THEN
     BEGIN
       SELECT JOTAI_KBN                           -- 状態区分
            , KAISHI_TSUKI                        -- 特徴開始月
         INTO NJOTAI_KBN_Y
            , NKAISHI_TSUKI_Y
         FROM ZLBTTOKU_KIHON_CAL                  -- 計算・特徴対象者情報
        WHERE KOKU_SETAI_NO    = i_NSETAI         -- 国保世帯番号
          AND SANTEIDANTAI_CD  = i_NDANTAI        -- 算定団体コード
          AND CHOTEI_NENDO     = NwNENDO          -- 年度(翌年)
          AND NENDO_BUN        = NwNENDOBUN       -- 年度分(翌年)
          AND TSUCHI_NO        = NTSUCHI_NO       -- 通知書番号
          AND SYS_TANMATSU_NO  = i_VTANMATSU      -- 更新端末番号
       ;
     -- 異常処理
     EXCEPTION
         WHEN OTHERS THEN
           VMSG := '計算特徴対象者情報が取得できません ' || SQLERRM;
           RETURN(c_SYORI_NG);
     END;
  END IF;
  -- 特徴状態、特徴開始月の設定
  IF (NTAISYOJOHO_KENSU_G = 0 AND NTAISYOJOHO_KENSU_Y = 0) THEN
    NTAISYOJOHO_KENSU := 0;
    NJOTAI_KBN        := 0;
    NKAISHI_TSUKI     := 0;
  ELSIF (NTAISYOJOHO_KENSU_G = 0 AND NTAISYOJOHO_KENSU_Y = 1) THEN
    NTAISYOJOHO_KENSU := NTAISYOJOHO_KENSU_Y;
    NJOTAI_KBN        := NJOTAI_KBN_Y;
    NKAISHI_TSUKI     := NKAISHI_TSUKI_Y;
    BYOKU4STOP        := TRUE;
  ELSIF NTAISYOJOHO_KENSU_G = 1 AND NTAISYOJOHO_KENSU_Y = 0 THEN
    NTAISYOJOHO_KENSU := NTAISYOJOHO_KENSU_G;
    NJOTAI_KBN        := NJOTAI_KBN_G;
    NKAISHI_TSUKI     := NKAISHI_TSUKI_G;
    -- 翌年追加捕捉の依頼取消の場合
    IF NKAISHI_TSUKI  = 4 AND NIRAI_HIZUKE_G = 0 THEN
      BYOKU4STOP        := TRUE;
    ELSE
      BYOKU4STOP        := FALSE;
    END IF;
  ELSE
    IF ((NJOTAI_KBN_G IN (c_NSHINKI_JOTAI,c_NTUZUKI_JOTAI) AND NJOTAI_KBN_Y = c_NTYUSHI_JOTAI) OR
        (NJOTAI_KBN_G = c_NTYUSHI_JOTAI AND NJOTAI_KBN_Y = c_NSHINKI_JOTAI)) THEN
      NTAISYOJOHO_KENSU := NTAISYOJOHO_KENSU_Y;
      NJOTAI_KBN        := NJOTAI_KBN_Y;
      NKAISHI_TSUKI     := NKAISHI_TSUKI_Y;
      IF (NJOTAI_KBN_G = c_NTYUSHI_JOTAI AND NJOTAI_KBN_Y = c_NSHINKI_JOTAI) THEN
        BYOKU4STOP      := TRUE;
      END IF;
    ELSE
      NTAISYOJOHO_KENSU := NTAISYOJOHO_KENSU_G;
      NJOTAI_KBN        := NJOTAI_KBN_G;
      NKAISHI_TSUKI     := NKAISHI_TSUKI_G;
    END IF;
  END IF;

  -- 正常終了
  RETURN(c_SYORI_OK);

END FUNCTOKUJOHOGET;
------------------------------------------------------------------------------
-- 前年度保険料存在チェック
------------------------------------------------------------------------------
FUNCTION ZENNENKIHONCNT RETURN NUMBER IS
    NCNT            NUMBER;
BEGIN
  -- 初期処理
  NCNT := 0;
  BEGIN
    SELECT COUNT(1)
      INTO NCNT
      FROM ZLBTKIHON_N   -- 最新・前年度基本情報
     WHERE KOKU_SETAI_NO      = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD    = i_NDANTAI        -- 算定団体コード
--       AND CHOTEI_NENDO       = i_NNENDO-1       -- 年度(-1)
--       AND NENDO_BUN          = i_NNENDO_BUN-1;  -- 年度分(-1)
       AND CHOTEI_NENDO       = i_NNENDO       -- 年度
       AND NENDO_BUN          = i_NNENDO_BUN;  -- 年度分
    -- 正常終了
    RETURN(NCNT);

  -- 異常処理
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(0);
      VMSG := '前年度基本情報が取得できません ' || SQLERRM;
  END;
END ZENNENKIHONCNT;
------------------------------------------------------------------------------
-- 期割済み判定
------------------------------------------------------------------------------
  FUNCTION FUNCKIWARIZUMI(o_NKIWARIHANTEI OUT NUMBER) RETURN NUMBER IS
    NKOJIN_NO           NUMBER;         -- 個人番号
    NSYORI_FLG          NUMBER;         -- 処理フラグ
    NIRAI_HIZUKE        NUMBER;         -- 特徴依頼日
    NHOSOKU_NENDO       NUMBER;         --捕捉年度

  BEGIN

    -- 個人番号を取得する
    SELECT NUSHI_KOJIN_NO
      INTO NKOJIN_NO
      FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO    = i_NSETAI         -- 世帯番号
       AND SANTEIDANTAI_CD  = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO     = i_NNENDO         -- 年度
       AND NENDO_BUN        = i_NNENDO_BUN     -- 年度分
       AND TSUCHI_NO        = i_NTSUCHI_NO     -- 通知書番号
       AND SYS_TANMATSU_NO  = i_VTANMATSU;     -- 端末番号

    -- 特徴異動情報から処理フラグを取得する
    SELECT SYORI_FLG
      INTO NSYORI_FLG
      FROM ZLBTTOKU_IDO
     WHERE KOJIN_NO = NKOJIN_NO     -- 個人番号
       AND KOKU_SETAI_NO = i_NSETAI -- 国保世帯番号
--       AND SYS_SAKUSEIBI =          -- MAX作成日
       AND R_NO =                   -- MAX履歴番号
   (SELECT MAX(R_NO)
      FROM ZLBTTOKU_IDO
     WHERE KOJIN_NO = NKOJIN_NO
       AND KOKU_SETAI_NO = i_NSETAI);

--     WHERE TOKU_KOJIN_NO = NKOJIN_NO  -- 個人番号
--       AND SAKUSEI_BI =               -- MAX作成日
    -- 特徴月が仮徴収期間の場合、賦課年度－１で特徴補足情報を検索
    IF NGTOKU_TUKI IN (4,6,8) THEN
      NHOSOKU_NENDO:= i_NNENDO - 1;
    ELSE
      NHOSOKU_NENDO:= i_NNENDO;
    END IF;
    -- 特徴捕捉情報より、特徴依頼日を取得する
    SELECT IRAI_HIZUKE
      INTO NIRAI_HIZUKE
      FROM ZLBTTOKU_HOSOKU
     WHERE TOKU_KOJIN_NO = NKOJIN_NO      -- 個人番号
       AND HOSOKU_NENDO  = NHOSOKU_NENDO  -- 補足年度
       AND SAKUSEI_BI =                   -- MAX作成日
   (SELECT MAX(SAKUSEI_BI)
      FROM ZLBTTOKU_HOSOKU
     WHERE TOKU_KOJIN_NO = NKOJIN_NO      -- 個人番号
       AND HOSOKU_NENDO  = NHOSOKU_NENDO  -- 補足年度
    );

    -- 異動テーブルの処理フラグ＝1(期割済み) AND 特徴依頼日に日付が入っていない
    IF NSYORI_FLG = 1 AND (NIRAI_HIZUKE IS NULL OR NIRAI_HIZUKE = 0) THEN
      -- 期割処理済
      o_NKIWARIHANTEI := c_NIRAIZUMI;
    ELSE
      -- 期割未処理
      o_NKIWARIHANTEI := c_NIRAIMAE;
    END IF;

    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
      -- 期割未処理
      o_NKIWARIHANTEI := c_NIRAIMAE;
      -- 正常終了
      RETURN(c_SYORI_OK);

      WHEN OTHERS THEN
        VMSG := 'FUNCKIWARIZUMI 期割済み判定 (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        RETURN(c_SYORI_NG);

  END FUNCKIWARIZUMI;
------------------------------------------------------------------------------
-- 中止事由
------------------------------------------------------------------------------
  FUNCTION FUNCTYUSHIJIYU(i_NJIYU_CD IN NUMBER) RETURN NUMBER IS

  BEGIN

    --特徴異動情報による中止の場合、特徴異動情報の中止事由を設定
    IF i_NJIYU_CD = c_NCHUSHI_JIYU_IDO THEN
      o_NCHUSHI_JIYU := NGCHUSHI_JIYU;            --特徴中止事由

    --税額変更または資格喪失による中止の場合、被保険者情報から中止事由を決定する。
    ELSIF i_NJIYU_CD = c_NCHUSHI_JIYU_ZEIZOU  THEN
        o_NCHUSHI_JIYU     := c_NCHUSHI_JIYU_2;   -- 増額更正
    ELSIF i_NJIYU_CD = c_NCHUSHI_JIYU_ZEIGEN THEN
        o_NCHUSHI_JIYU     := c_NCHUSHI_JIYU_1;   -- 減額更正
    ELSE
        o_NCHUSHI_JIYU := c_NCHUSHI_JIYU_36;      -- その他喪失
    END IF;

    -- 正常終了
    RETURN(c_SYORI_OK);

    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '中止事由エラー ' || SQLERRM;
        RETURN(c_SYORI_NG);
  END FUNCTYUSHIJIYU;
------------------------------------------------------------------------------
-- 特別徴収の中止判定
------------------------------------------------------------------------------
  FUNCTION FUNCTYUSHIHANTEI(o_NTYUSHIHANTEI OUT NUMBER
                          , o_NCHUSHIJIYU   OUT NUMBER
                          ) RETURN NUMBER IS
    NKOJIN_NO_CAL                NUMBER;        -- 個人番号(計算)
    NKOJIN_NO_N                  NUMBER;        -- 個人番号(最新)
    NTOKU_ZOUGAKU                NUMBER;        -- 増額
    NHOKENRYO_A                  NUMBER;        -- 保険料A
    NHOKENRYO_B                  NUMBER;        -- 保険料B
    NSHIK_3                      NUMBER;        -- 3月の資格
    NSHIK_GETSU                  NUMBER;        -- 特徴月の資格
    TYPE CSHIK_GETSU             IS REF CURSOR; -- カーソル
    CRSHIK_GETSU                 CSHIK_GETSU;
    VSQL                         VARCHAR2(300);
    NGETSU                       NUMBER;        -- 処理日の月
    NRTN                         NUMBER;        -- 返す値
    NHONSANTEI                   NUMBER;        -- 本算定月
    IHANTEI_MODE                 NUMBER := 0;

  BEGIN
    -- 個人番号(計算)を取得する
    BEGIN
      SELECT NUSHI_KOJIN_NO
        INTO NKOJIN_NO_CAL
        FROM ZLBTKIHON_CAL
       WHERE KOKU_SETAI_NO   = i_NSETAI
         AND SANTEIDANTAI_CD = i_NDANTAI
         AND CHOTEI_NENDO    = i_NNENDO
         AND NENDO_BUN       = i_NNENDO_BUN
         AND TSUCHI_NO       = i_NTSUCHI_NO
         AND SYS_TANMATSU_NO = i_VTANMATSU;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := 'FUNCTYUSHIHANTEI 宛名番号(計算) (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        RETURN(c_SYORI_NG);
    END;
    -- 個人番号(最新)を取得する
    BEGIN
      SELECT NUSHI_KOJIN_NO
        INTO NKOJIN_NO_N
        FROM ZLBTKIHON_N
       WHERE KOKU_SETAI_NO   = i_NSETAI
         AND SANTEIDANTAI_CD = i_NDANTAI
         AND CHOTEI_NENDO    = i_NNENDO
         AND NENDO_BUN       = i_NNENDO_BUN
         AND TSUCHI_NO       = i_NTSUCHI_NO;
    EXCEPTION
      WHEN OTHERS THEN
        NKOJIN_NO_N := 0;
    END;
    /************************/
    /* 世帯主変更を判断する */
    /************************/
    -- 個人番号変更無し
    IF NKOJIN_NO_CAL = NKOJIN_NO_N THEN
-- 特徴開始時に年度内75歳到達する場合は、年金が支払われる月まで特徴対象としているのでここで資格を判断する必要なし
      /************************/
      /* 年税の増減を判断する */
      /************************/
      -- 年税(A)を取得する＿計算TBL
--  2025/08/11 ZCZL.WANGMING UPDATE 1.1.200.000:子ども子育て支援金対応
--      SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0)
      SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0) + NVL(D.NENZEI,0)
        INTO NHOKENRYO_A
--  2025/08/11 ZCZL.WANGMING UPDATE 1.1.200.000:子ども子育て支援金対応
--        FROM ZLBTKIHON_CAL A, ZLBTKAI_KIHON_CAL B, ZLBTSIEN_KIHON_CAL C
        FROM ZLBTKIHON_CAL A, ZLBTKAI_KIHON_CAL B, ZLBTSIEN_KIHON_CAL C, ZLBTKDM_KIHON_CAL D
       WHERE A.KOKU_SETAI_NO      = i_NSETAI
         AND A.SANTEIDANTAI_CD    = i_NDANTAI
         AND A.CHOTEI_NENDO       = i_NNENDO
         AND A.NENDO_BUN          = i_NNENDO_BUN
         AND A.TSUCHI_NO          = i_NTSUCHI_NO
         AND A.SYS_TANMATSU_NO    = i_VTANMATSU
         AND B.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
         AND B.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
         AND B.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
         AND B.NENDO_BUN(+)       = A.NENDO_BUN
         AND B.TSUCHI_NO(+)       = A.TSUCHI_NO
         AND B.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO
         AND C.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
         AND C.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
         AND C.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
         AND C.NENDO_BUN(+)       = A.NENDO_BUN
         AND C.TSUCHI_NO(+)       = A.TSUCHI_NO
--  2025/08/11 ZCZL.WANGMING UPDATE START 1.1.200.000:子ども子育て支援金対応
--         AND C.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO;
         AND C.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO
         AND D.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
         AND D.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
         AND D.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
         AND D.NENDO_BUN(+)       = A.NENDO_BUN
         AND D.TSUCHI_NO(+)       = A.TSUCHI_NO
         AND D.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO;
--  2025/08/11 ZCZL.WANGMING UPDATE END

      -- 年税(B)を取得する＿賦課TBL
      BEGIN
--  2025/08/11 ZCZL.WANGMING UPDATE 1.1.200.000:子ども子育て支援金対応
--        SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0)
        SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0) + NVL(D.NENZEI,0)
          INTO NHOKENRYO_B
--  2025/08/11 ZCZL.WANGMING UPDATE 1.1.200.000:子ども子育て支援金対応
--          FROM ZLBTKIHON_N A, ZLBTKAI_KIHON_N B, ZLBTSIEN_KIHON_N C
          FROM ZLBTKIHON_N A, ZLBTKAI_KIHON_N B, ZLBTSIEN_KIHON_N C,ZLBTKDM_KIHON_N D
         WHERE A.KOKU_SETAI_NO      = i_NSETAI
           AND A.SANTEIDANTAI_CD    = i_NDANTAI
           AND A.CHOTEI_NENDO       = i_NNENDO
           AND A.NENDO_BUN          = i_NNENDO_BUN
           AND A.TSUCHI_NO          = i_NTSUCHI_NO
           AND B.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
           AND B.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
           AND B.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
           AND B.NENDO_BUN(+)       = A.NENDO_BUN
           AND B.TSUCHI_NO(+)       = A.TSUCHI_NO
           AND C.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
           AND C.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
           AND C.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
           AND C.NENDO_BUN(+)       = A.NENDO_BUN
--  2025/08/11 ZCZL.WANGMING UPDATE START 1.1.200.000:子ども子育て支援金対応
--           AND C.TSUCHI_NO(+)       = A.TSUCHI_NO;
           AND C.TSUCHI_NO(+)       = A.TSUCHI_NO
           AND D.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
           AND D.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
           AND D.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
           AND D.NENDO_BUN(+)       = A.NENDO_BUN
           AND D.TSUCHI_NO(+)       = A.TSUCHI_NO;
--  2025/08/11 ZCZL.WANGMING UPDATE END
      EXCEPTION
        WHEN OTHERS THEN
         NHOKENRYO_B := 0;
      END;
--      -- 処理日の月を取得する
--      -- 本算定月を取得する
      -- 処理日の年月を取得する
      NGETSU := TO_NUMBER(SUBSTR(TO_CHAR(i_NSHORIBI), 1, 6));
      IHANTEI_MODE := ZLBPK00010.FCFFJKN2(81);
      IF IHANTEI_MODE = 1 THEN
        IF i_NJIKKOU_KBN = 0 THEN
          -- 処理状態管理から依頼データ作成 最新作成日（月）を取得
          SELECT MAX(TUTI_NENGETU)               -- 通知年月
            INTO NGETSU
            FROM ZLBTSHORI_JYOTAI_KR          -- 処理状態管理
           WHERE SHORI_SHUBETU   = 7;         -- 処理種別
          IF NGETSU < i_NNENDO_BUN *100 + 6 THEN
            NGETSU := i_NNENDO_BUN *100 + 6 ;
          END IF;
        END IF;
      END IF;
      -- 本算定年月を取得する
      NRTN   := FUNCHONSANTEI(NHONSANTEI);
      IF NRTN <> c_SYORI_OK THEN
        RETURN(c_SYORI_NG);
      END IF;
      NHONSANTEI := i_NNENDO_BUN *100 + NHONSANTEI;
      -- 本算定の月＜＝引数の処理日の月and A>B
      IF NHONSANTEI <= NGETSU AND NHOKENRYO_A > NHOKENRYO_B THEN
        SELECT TOKU_ZOUGAKU
          INTO NTOKU_ZOUGAKU
          FROM ZLBTJOKEN
         WHERE NENDO = i_NNENDO
           AND SANTEIDANTAI_CD = 1;

        -- 増額分を普徴
        IF NTOKU_ZOUGAKU = 0 THEN
           -- 普徴期割(金額調整)
           o_NTYUSHIHANTEI := c_NRET_FUTU;
        ELSE
          -- 中止処理
          o_NTYUSHIHANTEI := c_NRET_TOKUSTOP;         -- 特徴中止
          -- 中止事由判定用区分
          o_NCHUSHIJIYU   := c_NCHUSHI_JIYU_ZEIZOU;   -- 税額変更(増)による中止
        END IF;
      -- 本算定の月＜＝引数の処理日の月and A<B
      ELSIF NHONSANTEI <= NGETSU AND NHOKENRYO_A < NHOKENRYO_B THEN
        -- 中止処理
          o_NTYUSHIHANTEI := c_NRET_TOKUSTOP;         -- 特徴中止
          -- 特徴中止事由判定用区分
          o_NCHUSHIJIYU   := c_NCHUSHI_JIYU_ZEIGEN;   -- 税額変更(減)による中止
      -- 上記以外
      ELSE
        -- 普徴期割(金額調整)
        o_NTYUSHIHANTEI := c_NRET_FUTU;
      END IF;
    -- 主変更の場合
    ELSE
      o_NTYUSHIHANTEI := c_NRET_TOKUSTOP;             -- 特徴中止
      -- 中止事由判定用区分
      o_NCHUSHIJIYU   := c_NCHUSHI_JIYU_SOSITSU;      -- 資格喪失による中止
    END IF;
    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
  EXCEPTION
    WHEN OTHERS THEN
      VMSG := 'FUNCTYUSHIHANTEI 特別徴収の中止判定エラー (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
      RETURN(c_SYORI_NG);

  END FUNCTYUSHIHANTEI;
------------------------------------------------------------------------------
-- 特徴対象判定
------------------------------------------------------------------------------
  FUNCTION FUNCTOKUHAITEI(i_NTOKUKAISHI IN NUMBER,o_NTOKUHANTEI OUT NUMBER) RETURN NUMBER IS
    NKOJIN_NO                    NUMBER;           -- 個人番号
    NNENDO                       NUMBER;           -- 年度
    NCNT                         NUMBER;           -- 件数
    NRTN                         NUMBER;           -- 返す値
    BNENREI_HANTAI               BOOLEAN;          -- 全員年齢判断
    NNENREI                      NUMBER;           -- 世帯主年齢
    NCHOSHU_75AGE                NUMBER;           -- ７５歳到達予定者徴収方法（０：普徴 １：特徴）

  BEGIN

    -- 世帯員年齢を判断する
    NRTN := FUNCSETAINENREI(BNENREI_HANTAI);
    IF NRTN <> c_SYORI_OK THEN
      RETURN(c_SYORI_NG);
    END IF;
    -- 世帯員全員65歳以上75歳未満
    IF BNENREI_HANTAI = TRUE THEN

      -- 個人番号を取得する
      SELECT NUSHI_KOJIN_NO
        INTO NKOJIN_NO
        FROM ZLBTKIHON_CAL
       WHERE KOKU_SETAI_NO   = i_NSETAI      -- 世帯番号
         AND SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
         AND CHOTEI_NENDO    = i_NNENDO      -- 年度
         AND NENDO_BUN       = i_NNENDO_BUN  -- 年度分
         AND TSUCHI_NO       = i_NTSUCHI_NO  -- 通知書番号
         AND SYS_TANMATSU_NO = i_VTANMATSU;  -- 端末番号

      -- 世帯主年齢を取得する
      NRTN := FUNCSETAIMEISHI(NKOJIN_NO, NNENREI);
      IF NRTN <> c_SYORI_OK THEN
        RETURN(c_SYORI_NG);
      END IF;
      -- ７５歳到達予定者徴収方法を取得する
      SELECT CHOSHU_75AGE
        INTO NCHOSHU_75AGE
        FROM ZLBTJOKEN             -- システム条件
       WHERE NENDO = i_NNENDO      -- 年度
         AND SANTEIDANTAI_CD = 1;  -- 算定団体コード=1

      -- (世帯主年齢75歳未満) OR (75歳以上 AND 75歳到達者徴収方法＝1)
      IF NNENREI < 75 OR (NNENREI >= 75 AND NCHOSHU_75AGE = 1) THEN
        -- 特徴異動データによる特徴開始
        IF i_NTOKUKAISHI = c_NTOKUKAISHI THEN
            o_NTOKUHANTEI := c_NRET_TOKUSTART;  -- 特徴開始
        ELSE
        BEGIN
         -- 特徴月が8月の場合前年度の捕捉情報を参照
         IF (NGTOKU_TUKI = 8)  THEN
           NNENDO := i_NNENDO -1;
         ELSE
           NNENDO := i_NNENDO;
         END IF;

          -- 特徴捕捉情報から件数を取得する
          SELECT COUNT(1)
            INTO NCNT
            FROM ZLBTTOKU_HOSOKU                  -- 特徴捕捉情報
           WHERE TOKU_KOJIN_NO = NKOJIN_NO        -- 個人番号
             AND HOSOKU_NENDO  = NNENDO           -- 賦課年度
             AND SAKUSEI_BI    = (                -- 最新作成日
                                  SELECT MAX(SAKUSEI_BI)
                                    FROM ZLBTTOKU_HOSOKU
                                   WHERE TOKU_KOJIN_NO = NKOJIN_NO
                                       AND HOSOKU_NENDO  = NNENDO);

        -- 異常処理
        EXCEPTION
            WHEN OTHERS THEN
              VMSG := '特徴捕捉情報件数取得 ' || ' 捕捉年度= ' || i_NNENDO || ' 宛名番号= ' || NKOJIN_NO || SQLERRM;
              RETURN(c_SYORI_NG);
        END;

        -- 捕捉情報無し
        IF NCNT = 0 THEN
          o_NTOKUHANTEI := c_NRET_FUTU;         -- 普徴期割
        ELSE
--          -- 捕捉情報あり
          -- 捕捉情報ありAND処理状態管理の通知月が6月の場合
          IF NGTOKU_TUKI = 10  AND NlTUTI_TUKI = 6 THEN  -- ここに来る場合は、特異動で開始指定以外なので、捕捉有りで特徴開始できるのは10月のみ
            o_NTOKUHANTEI := c_NRET_TOKUSTART;  -- 特徴開始
          ELSE
            o_NTOKUHANTEI := c_NRET_FUTU;       -- 普徴期割
          END IF;
        END IF;
        END IF;
      ELSE
        -- 普徴期割(金額調整)
        o_NTOKUHANTEI := c_NRET_FUTU;
      END IF;
    ELSE
      -- 普徴期割(金額調整)
      o_NTOKUHANTEI := c_NRET_FUTU;
    END IF;
    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := 'FUNCTOKUHAITEI 特徴対象判定 (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
        RETURN(c_SYORI_NG);

  END FUNCTOKUHAITEI;
------------------------------------------------------------------------------
-- 普徴更正(金額調整)
------------------------------------------------------------------------------
  FUNCTION FUNCFUKIWARI RETURN NUMBER IS
    NIDOCALCNT          NUMBER;    -- 特徴異動TBLカウント

  BEGIN
    -- 計算区分セット
    o_NKEISAN_KBN1 := c_NFUTSU_KEISAN; --普徴更正（金額調整）
    o_NKEISAN_KBN2 := c_NNASHI_KEISAN; --無し
    o_NKEISAN_KBN3 := c_NNASHI_KEISAN; --無し

    -- 普徴月セット
    o_NFUTU_TUKI   := NGFUTU_TUKI;--（５）
    -- 特徴月セット
    o_NTOKU_TUKI   := 0;

    -- 計算・異動情報の有無確認
    SELECT COUNT(*)
      INTO NIDOCALCNT
      FROM ZLBTTOKU_IDO_CAL                  -- 計算・異動情報
     WHERE SYS_TANMATSU_NO = i_VTANMATSU;    -- 更新端末番号

    -- 翌年度表示区分セット
    IF NIDOCALCNT = 0 THEN
      o_NYOKU_HYOUJI_KBN := c_NHYOJINASHI;   -- 表示無し
    ELSE
      o_NYOKU_HYOUJI_KBN := c_NHYOJIARI;     -- 表示有り
    END IF;

    -- 表示情報セット
    o_VHYOUJI_JYOUHO   := '特徴対象外';
    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        RETURN(c_SYORI_NG);
  END FUNCFUKIWARI;
------------------------------------------------------------------------------
-- 普徴更正(金額調整)
------------------------------------------------------------------------------
  FUNCTION FUNCFUKIWARI2 RETURN NUMBER IS

  BEGIN
    -- 計算区分セット
    o_NKEISAN_KBN1 := c_NFUTSU2_KEISAN; --普徴継続
    o_NKEISAN_KBN2 := c_NNASHI_KEISAN;  --無し
    o_NKEISAN_KBN3 := c_NNASHI_KEISAN;  --無し

    -- 普徴月セット
    o_NFUTU_TUKI   := NGFUTU_TUKI;--（４）
    -- 特徴月セット
    o_NTOKU_TUKI   := NGTOKU_TUKI;

    -- 翌年度表示区分セット
    o_NYOKU_HYOUJI_KBN := c_NHYOJINASHI;  -- 表示無し

    -- 表示情報セット
    o_VHYOUJI_JYOUHO   := '特徴対象外';

    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        RETURN(c_SYORI_NG);
  END FUNCFUKIWARI2;
------------------------------------------------------------------------------
-- 特徴対象の共通
------------------------------------------------------------------------------
  FUNCTION FUNCTOKUKYOTSU RETURN NUMBER IS

  BEGIN
    -- オンライン起動の時
    IF i_NJIKKOU_KBN = c_NONLINE THEN
      -- 計算区分セット
      o_NKEISAN_KBN1 := c_NTOKU_KEISAN;   --特徴開始
      o_NKEISAN_KBN2 := c_NFUTSU2_KEISAN; --普徴継続
      o_NKEISAN_KBN3 := c_NNASHI_KEISAN;  --無し
    ELSE
      -- 計算区分セット
      o_NKEISAN_KBN1 := c_NTOKU_KEISAN;   --特徴開始
      o_NKEISAN_KBN2 := c_NNASHI_KEISAN;  --無し
      o_NKEISAN_KBN3 := c_NNASHI_KEISAN;  --無し
    END IF;
    -- 表示情報セット
    o_VHYOUJI_JYOUHO := '特徴対象可';
    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        RETURN(c_SYORI_NG);
  END FUNCTOKUKYOTSU;
------------------------------------------------------------------------------
-- 特徴開始処理
------------------------------------------------------------------------------
  FUNCTION FUNCTOKUSTART(i_NTOKUKAISHI IN NUMBER) RETURN NUMBER IS
    NRTN                     NUMBER;         -- 返す値
    NTOKUHANTEI              NUMBER;         -- 期割判定(0. 普徴期割 1. 特徴期割)
    NIDOCALCNT               NUMBER;         -- 計算・異動情報の件数
    NKOJIN_NO                NUMBER;         -- 個人番号
    NKOJIN_NO_CAL            NUMBER;         -- 個人番号(計算)
    NKOJIN_NO_N              NUMBER;         -- 個人番号(最新)
    NSHIK_3                  NUMBER;         -- 3月の資格
    NSHIK_GETSU              NUMBER;         -- 特徴月の資格
    TYPE CSHIK_GETSU         IS REF CURSOR;  -- カーソル
    CRSHIK_GETSU             CSHIK_GETSU;
    VSQL                     VARCHAR2(300);
  BEGIN
--    -- 特徴異動情報による特徴開始か？
--      NTOKUHANTEI      := c_NRET_TOKUSTART;  -- 特徴開始
--      -- 特徴対象判定
      NRTN := FUNCTOKUHAITEI(i_NTOKUKAISHI, NTOKUHANTEI);
      IF NRTN != c_SYORI_OK THEN
        RETURN(c_SYORI_NG);
      END IF;

    -- 特徴開始の場合
    IF NTOKUHANTEI = c_NRET_TOKUSTART THEN

      -- 個人番号(計算)を取得する
      BEGIN
        SELECT NUSHI_KOJIN_NO
          INTO NKOJIN_NO_CAL
          FROM ZLBTKIHON_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NTSUCHI_NO
           AND SYS_TANMATSU_NO = i_VTANMATSU;
      EXCEPTION
          WHEN OTHERS THEN
            VMSG := 'FUNCTOKUSTART 宛名番号(計算) (国保世帯番号 = ' || i_NSETAI || '）' || SQLERRM;
            RETURN(c_SYORI_NG);
      END;
      -- 個人番号(最新)を取得する
      BEGIN
        SELECT NUSHI_KOJIN_NO
          INTO NKOJIN_NO_N
          FROM ZLBTKIHON_N
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NTSUCHI_NO;

      EXCEPTION
        WHEN OTHERS THEN
          NKOJIN_NO_N := 0;
      END;
      -- 個人番号を判断する
      IF (NKOJIN_NO_CAL = NKOJIN_NO_N )OR (NKOJIN_NO_N = 0) THEN
        -- 世帯主に異動がなくても世帯主が資格を喪失していないかチェック
--        -- 特徴月 ＝ 104 or 106
        -- 特徴月 = 翌4月、翌6月、翌8月開始(104,106,8)
        IF NGTOKU_TUKI IN (104,106,8) THEN
          -- 3月の資格を取得する
          SELECT SHIK_3
            INTO NSHIK_3
            FROM ZLBTKOJIN_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI
             AND KOJIN_NO        = NKOJIN_NO_CAL
             AND SANTEIDANTAI_CD = i_NDANTAI
             AND CHOTEI_NENDO    = i_NNENDO
             AND NENDO_BUN       = i_NNENDO_BUN
             AND SYS_TANMATSU_NO = i_VTANMATSU
             AND TSUCHI_NO       = i_NTSUCHI_NO;

--          -- 3月の資格 !＝ 1 or 11
          -- 3月の資格 !＝ 1 or 11 or 21
          IF NSHIK_3 NOT IN (1, 11, 21) THEN
            NTOKUHANTEI   := c_NRET_FUTU;      -- 普徴更正
            -- 普徴更正(金額調整)
            NRTN := FUNCFUKIWARI2;
            o_NCHUSHI_JIYU := c_NCHUSHI_JIYU_36;  -- その他喪失
          ELSE
            -- 特徴対象の共通項目セット
            NRTN             := FUNCTOKUKYOTSU;
            -- 特徴月セット
            o_NTOKU_TUKI     := NGTOKU_TUKI;

          END IF;

        -- 特徴月 ＝ 104 or 106以外
        ELSE
          VSQL := 'SELECT ' || 'SHIK_' || TO_CHAR(NGTOKU_TUKI);
          VSQL := VSQL || ' FROM ZLBTKOJIN_CAL ';
          VSQL := VSQL || ' WHERE KOKU_SETAI_NO = '  || i_NSETAI;
          VSQL := VSQL || '  AND KOJIN_NO = '        || NKOJIN_NO_CAL;
          VSQL := VSQL || '  AND SANTEIDANTAI_CD = ' || i_NDANTAI;
          VSQL := VSQL || '  AND CHOTEI_NENDO = '    || i_NNENDO;
          VSQL := VSQL || '  AND NENDO_BUN = '       || i_NNENDO_BUN;
          VSQL := VSQL || '  AND TSUCHI_NO = '       || i_NTSUCHI_NO;
          VSQL := VSQL || '  AND SYS_TANMATSU_NO = ' || '''' || i_VTANMATSU || '''';


          -- 各月の資格区分を取得する
          OPEN CRSHIK_GETSU FOR VSQL;
            FETCH CRSHIK_GETSU INTO NSHIK_GETSU;
          CLOSE CRSHIK_GETSU;

--          -- 各月の資格区分!＝1 or 11
          -- 各月の資格区分!＝1 or 11 or 21
          IF NSHIK_GETSU NOT IN (1, 11, 21) THEN
            NTOKUHANTEI   := c_NRET_FUTU;      -- 普徴更正

            -- 特徴中止月が10月＆特徴状態が中止のときは普徴期割りへ
            IF(NSHURYO_TSUKI = 10 AND  NJOTAI_KBN = c_NTYUSHI_JOTAI   ) THEN
              -- 普徴期割
              NRETURN := FUNCFUKIWARI;
            ELSE
              -- 普徴更正(金額調整)
              NRTN := FUNCFUKIWARI2;
              o_NCHUSHI_JIYU := c_NCHUSHI_JIYU_36;  -- その他喪失
            END IF;
          ELSE
            -- 特徴対象の共通項目セット
            NRTN             := FUNCTOKUKYOTSU;
            -- 特徴月セット
            o_NTOKU_TUKI     := NGTOKU_TUKI;

          END IF;
        END IF;
      ELSE
        -- 普徴更正(金額調整)
        NRTN := FUNCFUKIWARI2;
        o_NCHUSHI_JIYU := c_NCHUSHI_JIYU_36;  -- その他喪失
      END IF;
    ELSE
      -- 特徴状態が新規 OR 継続の場合、普徴期割２
      IF NJOTAI_KBN = c_NSHINKI_JOTAI AND NKOZAKIRIKAE <> 0 THEN
        -- 計算区分セット
        o_NKEISAN_KBN1   := c_NFUTSU_KEISAN;   -- 普徴期割
        o_NKEISAN_KBN2   := c_NNASHI_KEISAN;   -- 無し
        o_NKEISAN_KBN3   := c_NNASHI_KEISAN;   -- 無し
        -- 表示情報セット
        o_VHYOUJI_JYOUHO := '特徴対象外';
        -- 特徴月セット
        o_NTOKU_TUKI     := 0;

      ELSIF NJOTAI_KBN = c_NSHINKI_JOTAI OR  NJOTAI_KBN = c_NTUZUKI_JOTAI THEN

        -- 普徴更正(金額調整)
        NRTN := FUNCFUKIWARI2;
        o_NCHUSHI_JIYU     := c_NCHUSHI_JIYU_90;  -- 捕捉情報無し
      ELSE
        -- 計算区分セット
        o_NKEISAN_KBN1   := c_NFUTSU_KEISAN;   -- 普徴期割
        o_NKEISAN_KBN2   := c_NNASHI_KEISAN;   -- 無し
        o_NKEISAN_KBN3   := c_NNASHI_KEISAN;   -- 無し
        -- 表示情報セット
        o_VHYOUJI_JYOUHO := '特徴対象外';
        -- 特徴月セット
        o_NTOKU_TUKI     := 0;
      END IF;
    END IF;
    -- 普徴月セット
    o_NFUTU_TUKI       := NGFUTU_TUKI;--（３）

    -- 計算・異動情報の有無確認
    SELECT COUNT(*)
      INTO NIDOCALCNT
      FROM ZLBTTOKU_IDO_CAL                  -- 計算・異動情報
     WHERE SYS_TANMATSU_NO = i_VTANMATSU;    -- 更新端末番号

    -- 翌年度表示区分セット
    IF NIDOCALCNT = 0 THEN
      o_NYOKU_HYOUJI_KBN := c_NHYOJINASHI;   -- 表示無し
    ELSE
      o_NYOKU_HYOUJI_KBN := c_NHYOJIARI;     -- 表示有り
    END IF;

    -- 正常終了
    RETURN(c_SYORI_OK);

    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        RETURN(c_SYORI_NG);
  END FUNCTOKUSTART;
------------------------------------------------------------------------------
-- 特徴中止処理
------------------------------------------------------------------------------
  FUNCTION FUNCTOKUSTOP(i_NTYUSHISHORI IN NUMBER) RETURN NUMBER IS
    NRTN                 NUMBER;    -- 返す値

--    NTYUSHIHANTEI        NUMBER;    -- 中止判定

    NKIWARIHANTEI        NUMBER;    -- 期割済み判定
    NCHUSHIJIYU          NUMBER;    -- 中止事由コード
  BEGIN
    NCHUSHIJIYU := 0;

    -- 特徴異動データによる中止処理
    IF i_NTYUSHISHORI = c_NTYUSHISHORI THEN
      NTYUSHIHANTEI := c_NRET_TOKUSTOP;
      NCHUSHIJIYU   := c_NCHUSHI_JIYU_IDO;   -- 特徴異動情報による中止
    ELSE
      -- 特別徴収の中止判定
      NRTN := FUNCTYUSHIHANTEI(NTYUSHIHANTEI
                             , NCHUSHIJIYU
                             );

      IF NRTN != c_SYORI_OK THEN
        RETURN(c_SYORI_NG);
      END IF;
    END IF;

    -- 特徴継続(普徴期割)の場合
    IF NTYUSHIHANTEI = c_NRET_FUTU THEN
        -- オンライン起動
        IF i_NJIKKOU_KBN = c_NONLINE THEN
          -- 国保連に特徴依頼前か？
          NRTN := FUNCKIWARIZUMI(NKIWARIHANTEI);
          IF NRTN != 0 THEN
            RETURN(c_SYORI_NG);
          END IF;

          o_NKEISAN_KBN1   := c_NFUTSU_KEISAN;       -- 普徴更正
          -- 期割済の場合、計算区分1に特徴依頼取消をセット
          IF NKIWARIHANTEI = c_NIRAIZUMI THEN
            o_NKEISAN_KBN2 := c_NIRAICANCEL_KEISAN;  -- 特徴依頼取消
          ELSE
            o_NKEISAN_KBN2 := c_NTYUSHI_KEISAN;      -- 特徴中止
          END IF;
          o_NKEISAN_KBN3   := c_NNASHI_KEISAN;       -- 無し
        ELSE
          -- 普徴更正(金額調整)
          NRTN := FUNCFUKIWARI;
          RETURN(c_SYORI_OK);                        -- Exit
        END IF;

    ELSE
      -- 計算区分セット
      o_NKEISAN_KBN1 := c_NTYUSHI_KEISAN;  -- 特徴中止
      o_NKEISAN_KBN2 := c_NNASHI_KEISAN;   -- 無し
      o_NKEISAN_KBN3 := c_NNASHI_KEISAN;   -- 無し

      -- 中止事由取得＆セット
        NRTN := FUNCTYUSHIJIYU(NCHUSHIJIYU);
        IF NRTN != c_SYORI_OK THEN
          RETURN(c_SYORI_NG);
        END IF;

      -- 国保連に特徴依頼前か？
      NRTN := FUNCKIWARIZUMI(NKIWARIHANTEI);
      IF NRTN != 0 THEN
        RETURN(c_SYORI_NG);
      END IF;
--      -- 期割済の場合、計算区分1に特徴依頼取消をセット
--        o_NKEISAN_KBN1 := c_NIRAICANCEL_KEISAN;  --特徴依頼取消

    END IF;

    o_NFUTU_TUKI       := NGFUTU_TUKI; -- 普徴月--（２）
    o_NTOKU_TUKI       := NGTOKU_TUKI; -- 特徴月
    o_NYOKU_HYOUJI_KBN := c_NHYOJIARI; -- 翌年度表示区分

    -- 表示情報セット ※計算特徴対象者の特徴状態を元に設定
    -- 0件、中止の場合
    IF NTAISYOJOHO_KENSU = 0 OR NJOTAI_KBN = c_NTYUSHI_JOTAI OR NKOZAKIRIKAE <> 0THEN
      o_VHYOUJI_JYOUHO := '特徴対象外';
    -- 新規、継続の場合
    ELSE
      o_VHYOUJI_JYOUHO := '特徴対象';
    END IF;

    -- 正常終了
    RETURN(c_SYORI_OK);

    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        RETURN(c_SYORI_NG);
  END FUNCTOKUSTOP;
  --------------------------------------------------------------------------
  --  名称        本算定処理実施判断  BY 2016/08/25
  --  戻り値      0:実施済 1:未実施
  --------------------------------------------------------------------------
  FUNCTION JLPFGET_HONMODE_ONL(i_ICHOTEI_NENDO IN PLS_INTEGER,
                               i_INENDO_BUN    IN PLS_INTEGER,
                               i_NKIJUNBI      IN PLS_INTEGER) RETURN NUMBER IS
    ICOUNT     PLS_INTEGER;
    RJOKEN     ZLBTJOKEN%ROWTYPE;
    IZAN_TSUKI PLS_INTEGER;
    IHON_TSUKI PLS_INTEGER;
    IKJN_TSUKI PLS_INTEGER;
    IZAN_CNT   PLS_INTEGER;
    IHON_CNT   PLS_INTEGER;
  BEGIN
    IF i_ICHOTEI_NENDO = i_INENDO_BUN THEN
      SELECT COUNT(*) INTO ICOUNT
        FROM ZLBTSHORI_HANI
       WHERE CHOTEI_NENDO = i_ICHOTEI_NENDO
         AND NENDO_BUN = i_INENDO_BUN;
      IF ICOUNT = 0 THEN
        RETURN 1;
      ELSE
        SELECT * INTO RJOKEN
          FROM ZLBTJOKEN
         WHERE NENDO = i_ICHOTEI_NENDO
           AND SANTEIDANTAI_CD = 1;
        CASE
          WHEN RJOKEN.NOKI_3 = 2 THEN IHON_TSUKI := 6;
          WHEN RJOKEN.NOKI_4 = 2 THEN IHON_TSUKI := 7;
          WHEN RJOKEN.NOKI_5 = 2 THEN IHON_TSUKI := 8;
        END CASE;
        SELECT COUNT(*) INTO IHON_CNT
          FROM ZLBTSHORI_HANI
         WHERE CHOTEI_NENDO = i_ICHOTEI_NENDO
           AND NENDO_BUN = i_INENDO_BUN
           AND SHIME_NENGETSU = i_ICHOTEI_NENDO * 100 + IHON_TSUKI
           AND MASTER_KOSHIN_KBN = 2;
        -- 本算定処理が未実施で基準日が設定されている場合、基準日により本算定かどうか判断する
        IF IHON_CNT = 0 AND i_NKIJUNBI > 0 THEN
          IKJN_TSUKI := TO_NUMBER(SUBSTR(i_NKIJUNBI,5,2));
          IF IKJN_TSUKI BETWEEN 1 AND 3 THEN
            IKJN_TSUKI := IKJN_TSUKI + 12;
          END IF;
          IF IKJN_TSUKI >= IHON_TSUKI THEN
            IHON_CNT := 1;
          ELSE
            IHON_CNT := 0;
          END IF;
        END IF;
        IF IHON_CNT = 0 THEN
          RETURN 1;
        ELSE
          RETURN 0;
        END IF;
      END IF;
    ELSE
      RETURN 1;
    END IF;
  END JLPFGET_HONMODE_ONL;
------------------------------------------------------------------------------
-- 特徴対象判定の要否判定
------------------------------------------------------------------------------
  FUNCTION FUNCTAISYOHAITEI(o_NTAISYOHANTEI OUT NUMBER) RETURN NUMBER IS
    NTOKU_KBN               NUMBER;                    -- 特徴実施区分
    NCNT                    NUMBER;                    -- 件数
    IHANTEI_MODE            NUMBER := 0;
    IwCOUNT                 NUMBER := 0;
    NTOKU_KIWARI_2          NUMBER;--件数
    NJOTAI_KBN_2            NUMBER;--状態区分
    HOSOKU_NENDO_G          NUMBER := 0;
    NKAISHI_KIBETSU_G       NUMBER := 0;
    NTOKU_KIBETU          NUMBER; -- 特徴中止判定期別
    NKARI_MODE            NUMBER; -- 仮算定期間判定

  BEGIN
    -- システム条件から特徴実施区分を取得
    NTOKU_KBN := FUNCJYOKENGET;

    -- 特徴実施か？
    IF NTOKU_KBN = c_NJISHI_TOKU THEN
      -- 翌年度キーによる特徴異動実施不可？
      IF NGYOKU_IDO_FLG = 0 THEN
        o_NTAISYOHANTEI := c_NFUTSU;             -- 普徴対象判定へ
      -- 特徴異動情報による特徴中止？
      ELSIF NGKOSEI_CD = c_NTYUSHI_KOSEI THEN
        o_NTAISYOHANTEI := c_NTYUSHISHORI;       -- 特徴中止処理へ

      -- 特徴異動情報による特徴開始？
      ELSIF NGKOSEI_CD = c_NKAISHI_KOSEI THEN
        IF NKOZAKIRIKAE <> 0 THEN
          o_NTAISYOHANTEI := c_NFUTSU;                   -- 普徴対象判定へ
        ELSE
        -- ８月特徴開始の場合、前年度基本情報存在チェック
        IF NGTOKU_TUKI = 8 THEN
            NCNT := ZENNENKIHONCNT;
            -- 前年度基本情報有り
            IF NCNT > 0 THEN
              -- 特徴開始
              o_NTAISYOHANTEI := c_NTOKUKAISHI;  -- 特徴開始処理へ
            -- 前年度基本情報無し
            ELSE
              o_NTAISYOHANTEI := c_NFUTSU;       -- 普徴対象判定へ
            END IF;
        ELSE
          -- 特徴開始
          o_NTAISYOHANTEI := c_NTOKUKAISHI;      -- 特徴開始処理へ
        END IF;
        END IF;
      -- 特徴異動情報無しの場合
      ELSE
        IF NKOZAKIRIKAE <> 0 THEN
          IF i_NJIKKOU_KBN = c_NONLINE THEN
             NKARI_MODE := JLPFGET_HONMODE_ONL(i_NNENDO, i_NNENDO_BUN, i_NSHORIBI);
             IF  NKARI_MODE  =  1 THEN
               NTOKU_KIBETU := 5;
              ELSE
               NTOKU_KIBETU := 11;
             END IF;
           ELSE
              NTOKU_KIBETU := 11;
          END IF;
          BEGIN
            --2月の特徴額を取得
            SELECT ZEN_ZEIGAKU INTO NTOKU_KIWARI_2
              FROM ZLBTKIBETSU_N
             WHERE KAMOKU_CD = 15
               AND KAMOKUS_CD = 2
               AND KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEINENDO     = i_NNENDO
               AND NENDOBUN        = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND RONRIKIBETSU    = NTOKU_KIBETU;
            --特徴区分を取得(1OR2)
            SELECT JOTAI_KBN INTO NJOTAI_KBN_2
              FROM ZLBTTOKU_KIHON_CAL             -- 計算・特徴対象者情報
             WHERE KOKU_SETAI_NO   = i_NSETAI     -- 国保世帯番号
               AND SANTEIDANTAI_CD = i_NDANTAI    -- 算定団体コード
               AND CHOTEI_NENDO    = i_NNENDO     -- 年度(現年)
               AND NENDO_BUN       = i_NNENDO_BUN -- 年度分(現年)
               AND TSUCHI_NO       = i_NTSUCHI_NO -- 通知書番号
               AND SYS_TANMATSU_NO = i_VTANMATSU; -- 更新端末番号
            -- 異常処理
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              NTOKU_KIWARI_2 := 0;
              NJOTAI_KBN_2 := 0;
            WHEN OTHERS THEN
              NTOKU_KIWARI_2 := 0;
              NJOTAI_KBN_2 := 0;
          END;
          --2月特徴税額があるAND状態区分が新規OR継続なら中止
          IF NTOKU_KIWARI_2 > 0 AND NJOTAI_KBN_2 IN (1,2) THEN
            o_NTAISYOHANTEI := c_NTYUSHIHANTEI;  -- 特徴中止判定へ
          --なければただの普徴期割
          ELSE
            o_NTAISYOHANTEI := c_NFUTSU;      -- 特徴対象判定へ
          END IF;
        ELSE

        -- 0件の場合
        IF NTAISYOJOHO_KENSU = 0 THEN
          o_NTAISYOHANTEI := c_NTOKUHANTEI;      -- 特徴対象判定へ

        -- 1件の場合
        ELSIF NTAISYOJOHO_KENSU = 1 THEN
          -- 捕捉年度・特徴開始期別の判定
          BEGIN
            SELECT HOSOKU_NENDO                        -- 捕捉年度
                 , KAISHI_KIBETSU                      -- 特徴開始期別
              INTO HOSOKU_NENDO_G
                 , NKAISHI_KIBETSU_G
              FROM ZLBTTOKU_KIHON_CAL                  -- 計算・特徴対象者情報
             WHERE KOKU_SETAI_NO    = i_NSETAI         -- 国保世帯番号
               AND SANTEIDANTAI_CD  = i_NDANTAI        -- 算定団体コード
               AND CHOTEI_NENDO     = i_NNENDO         -- 年度(現年)
               AND NENDO_BUN        = i_NNENDO_BUN     -- 年度分(現年)
               AND TSUCHI_NO        = i_NTSUCHI_NO     -- 通知書番号
               AND SYS_TANMATSU_NO  = i_VTANMATSU      -- 更新端末番号
            ;
          -- 異常処理
          EXCEPTION
              WHEN NO_DATA_FOUND THEN
                HOSOKU_NENDO_G := i_NNENDO_BUN;
                NKAISHI_KIBETSU_G := 0;
              WHEN OTHERS THEN
                VMSG := '計算特徴対象者情報が取得できません ' || SQLERRM;
                RETURN(c_SYORI_NG);
          END;

          IF TO_NUMBER(SUBSTR(TO_CHAR(i_NSHORIBI), 1, 6))
             >= TO_NUMBER(TO_CHAR(i_NNENDO_BUN)||'08')
            AND HOSOKU_NENDO_G <> i_NNENDO_BUN
            AND NKAISHI_KIBETSU_G < 9 THEN
              NKOUFUTU_FLG := 1;
              IF TO_NUMBER(SUBSTR(TO_CHAR(i_NSHORIBI), 5, 2)) = 8 THEN
                o_NTAISYOHANTEI := c_NTYUSHIHANTEI;  -- 特徴中止判定へ
              ELSE
                o_NTAISYOHANTEI := c_NFUTSU;         -- 普徴対象判定へ
              END IF;
          ELSE
            -- 状態区分＝新規(1)・継続(2)
            IF NJOTAI_KBN = c_NSHINKI_JOTAI  OR NJOTAI_KBN = c_NTUZUKI_JOTAI THEN
              -- 特徴月＝10月
              IF NGTOKU_TUKI = 10 THEN
                -- 特徴開始月＝10月
                IF NKAISHI_TSUKI = 10 THEN
                  o_NTAISYOHANTEI := c_NTYUSHIHANTEI;  -- 特徴中止判定へ
                -- 以外
                ELSE
                  SELECT MAX(TUTI_NENGETU) INTO NTUTI_NENGETU  -- 通知年月
                    FROM ZLBTSHORI_JYOTAI_KR                -- 処理状態管理
                   WHERE SHORI_SHUBETU   = 7;                  -- 処理種別
                  -- 通知年月をセット
                  NCMP_TUKI := TO_NUMBER(SUBSTR(TO_CHAR(NTUTI_NENGETU), 5, 2));
                  IF NlTUTI_TUKI <> NTUTI_NENGETU THEN
                  --６月本算定用に強制的に６月送付済みにしている場合、中止は間に合うため、
                  --減額の再判定を行う(８月特徴分の金額)→８月から普徴再期割を行う
                    IF FUNCTOKUGENCHK = 1 THEN
                      o_NTAISYOHANTEI := c_NTYUSHIHANTEI;    -- 特徴中止判定へ
                      NlTUTI_TUKI := 5;
                      NGTOKU_TUKI := 8;
                    ELSE
                      o_NTAISYOHANTEI := c_NTOKUHANTEI;    -- 特徴対象判定へ
                    END IF;
                  ELSE
                    o_NTAISYOHANTEI := c_NTOKUHANTEI;    -- 特徴対象判定へ
                  END IF;
                END IF;
              -- 以外
              ELSE
                o_NTAISYOHANTEI := c_NTYUSHIHANTEI;    -- 特徴中止判定へ
              END IF;
            -- 中止(3)の場合
            ELSIF NJOTAI_KBN = c_NTYUSHI_JOTAI THEN
              -- 1回目の即時計算で中止処理を行っている為（終了月に10月セットの場合は普徴期割りへ）
              IF(NSHURYO_TSUKI = 10 ) THEN
                o_NTAISYOHANTEI := c_NFUTSU;
              ELSE
                o_NTAISYOHANTEI := c_NTOKUHANTEI;        -- 特徴対象判定へ
              END IF;
            END IF;
          END IF;
        END IF;
        END IF;
      END IF;

    -- 特徴実施しない
    ELSIF NTOKU_KBN = c_NJISHINAI_TOKU THEN
      o_NTAISYOHANTEI := c_NFUTSU;                   -- 普徴対象判定へ
    ELSE
      RETURN(c_SYORI_NG);
    END IF;
    IF i_NJIKKOU_KBN <> 0 AND o_NTAISYOHANTEI = c_NTOKUHANTEI AND NlTUTI_TUKI = 6 AND NGTOKU_TUKI = 10 THEN
      IHANTEI_MODE := ZLBPK00010.FCFFJKN2(81);
      IF IHANTEI_MODE = 1 THEN
        SELECT COUNT(*) COUNT INTO IwCOUNT
          FROM ZLBTSHORI_HANI
         WHERE CHOTEI_NENDO = i_NNENDO
           AND NENDO_BUN    = i_NNENDO
           AND SHIME_NENGETSU = i_NNENDO * 100 + 06
           AND MASTER_KOSHIN_KBN    =  2;
        IF IwCOUNT > 0 THEN
          o_NTAISYOHANTEI := c_NFUTSU;                   -- 普徴対象判定へ
        END IF;
      END IF;
    END IF;
    -- 正常終了
    RETURN(c_SYORI_OK);

    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        RETURN(c_SYORI_NG);
  END FUNCTAISYOHAITEI;

------------------------------------------------------------------------------
-- 普徴期割開始月補正
------------------------------------------------------------------------------
  FUNCTION FUNCFUTUKAISHIHOSEI(
    o_NKAISHITUKI_FU OUT NUMBER  --補正後普徴期割開始月
    ) RETURN PLS_INTEGER IS
  NRTN                     NUMBER := 0;
  NNEN                     NUMBER := 0;
  NFUNENGETSU              NUMBER := 0;
  BEGIN
    --初期化
    o_NKAISHITUKI_FU := NGFUTU_TUKI;--普徴月
    IF NGFUTU_TUKI >= 4 THEN
      NNEN := i_NNENDO_BUN;
    ELSE
      NNEN := i_NNENDO_BUN + 1;
    END IF;
    NFUNENGETSU := TO_NUMBER(TO_CHAR(NNEN)||LPAD(TO_CHAR(NGFUTU_TUKI),2,'0'));
      --特徴対象判定結果が3：中止判定、もしくは5：中止処理の場合
      IF NTAISYOHANTEI IN (c_NTYUSHIHANTEI,c_NTYUSHISHORI) THEN
        --特徴中止判定結果が2：特徴中止の場合
        IF NTYUSHIHANTEI = c_NRET_TOKUSTOP THEN
          CASE NGTOKU_TUKI--特徴月
            WHEN 4 THEN
                NULL;
-- 画面OR処理条件の期割開始月が判定より大きい場合は優先する
            WHEN 6 THEN
                IF NFUNENGETSU > TO_NUMBER(TO_CHAR(i_NNENDO_BUN) || '05') THEN
                  o_NKAISHITUKI_FU := NGFUTU_TUKI;
                ELSE
                  o_NKAISHITUKI_FU := 5;
                END IF;
            WHEN 8 THEN
                IF NFUNENGETSU > TO_NUMBER(TO_CHAR(i_NNENDO_BUN) || '07') THEN
                  o_NKAISHITUKI_FU := NGFUTU_TUKI;
                ELSE
                  o_NKAISHITUKI_FU := 7;
                END IF;
            WHEN 10 THEN
                IF NFUNENGETSU > TO_NUMBER(TO_CHAR(i_NNENDO_BUN) || '09') THEN
                  o_NKAISHITUKI_FU := NGFUTU_TUKI;
                ELSE
                  -- 10月中止は8月特徴有無を判断する
                  NRTN := FUNCTOKUKEIZOKUCHK(o_NKAISHITUKI_FU);
                END IF;
            WHEN 12 THEN
                IF NFUNENGETSU > TO_NUMBER(TO_CHAR(i_NNENDO_BUN) || '11') THEN
                  o_NKAISHITUKI_FU := NGFUTU_TUKI;
                ELSE
                  o_NKAISHITUKI_FU := 11;
                END IF;
            WHEN 2 THEN
                IF NFUNENGETSU > TO_NUMBER(TO_CHAR(i_NNENDO_BUN + 1) || '01') THEN
                  o_NKAISHITUKI_FU := NGFUTU_TUKI;
                ELSE
                  o_NKAISHITUKI_FU := 1;
                END IF;
            ELSE
                NULL;
            END CASE;
                END IF;
        END IF;

    -- 正常終了
    RETURN(c_SYORI_OK);
    -- 異常処理
    EXCEPTION
      WHEN OTHERS THEN
        RETURN(c_SYORI_NG);

  END FUNCFUTUKAISHIHOSEI;

------------------------------------------------------------------------------
-- 併徴の判定
--      ※併徴の判定は、期割開始月でなく、10月以降で普徴・特徴の両方に期割額がある時とする。
--        （12月特徴中止＆期割開始月が9月の場合に対応するため）
------------------------------------------------------------------------------
  FUNCTION FUNCHEICHOCHK
    RETURN BOOLEAN IS
    NwFUTU           NUMBER := 0;
    NwTOKU           NUMBER := 0;
  BEGIN
    BEGIN
      -- １０月以降の税額を取得する（普徴）
      SELECT SUM(ZEN_ZEIGAKU)
        INTO NwFUTU
        FROM ZLBTKIBETSU_N
       WHERE KOKU_SETAI_NO     = i_NSETAI           -- 国保世帯番号
         AND SANTEIDANTAI_CD   = i_NDANTAI          -- 算定団体コード
         AND CHOTEINENDO       = i_NNENDO           -- 調定年度
         AND NENDOBUN          = i_NNENDO_BUN       -- 年度分
         AND TSUCHI_NO         = i_NTSUCHI_NO       -- 通知書番号
         AND RONRIKIBETSU     >= 7                  -- 10月論理期別(7)以降
         AND KAMOKU_CD         = c_NKAMOKU_CD       -- 科目コード
         AND KAMOKUS_CD        = c_NKAMOKUS_CD1;    -- 普徴
    EXCEPTION
      WHEN OTHERS THEN
        NwFUTU := 0;
    END;

    BEGIN
      -- １０月以降の税額を取得する（特徴）
      SELECT SUM(ZEN_ZEIGAKU)
        INTO NwTOKU
        FROM ZLBTKIBETSU_N
       WHERE KOKU_SETAI_NO     = i_NSETAI           -- 国保世帯番号
         AND SANTEIDANTAI_CD   = i_NDANTAI          -- 算定団体コード
         AND CHOTEINENDO       = i_NNENDO           -- 調定年度
         AND NENDOBUN          = i_NNENDO_BUN       -- 年度分
         AND TSUCHI_NO         = i_NTSUCHI_NO       -- 通知書番号
         AND RONRIKIBETSU     >= 7                  -- 10月論理期別(7)以降
         AND KAMOKU_CD         = c_NKAMOKU_CD       -- 科目コード
         AND KAMOKUS_CD        = c_NKAMOKUS_CD2;    -- 特徴
    EXCEPTION
      WHEN OTHERS THEN
        NwTOKU := 0;
    END;

    -- 普徴・特徴の両方に期割額があるとき、併徴と判断する
    IF NwFUTU > 0 AND NwTOKU > 0 THEN
      return TRUE;   -- 併徴である
    ELSE
      return FALSE;  -- 併徴でない
    END IF;

  END FUNCHEICHOCHK;

------------------------------------------------------------------------------
-- メイン処理
------------------------------------------------------------------------------
BEGIN
  NRETURN := c_SYORI_OK;

  -- 仮算定異動計算機能がオンの場合、仮算定中か判定を行う
  IF i_NJIKKOU_KBN = c_NONLINE THEN
    IF ZLBPK00010.FCFFJKN2(411) = 1 THEN
      -- 仮算定判断
      IZAN_MODE := ZLBPK00010.FCZANMODE_ONL(i_NNENDO, i_NNENDO_BUN, i_NSHORIBI);
    ELSE
      IZAN_MODE := 0;
    END IF;
  ELSE
    IZAN_MODE := 0;
  END IF;

  -- 計算個人 件数チェック
  NRETURN := FUNCKOJINCHK;
  IF NRETURN <> c_SYORI_OK THEN
    GOTO ERROR_MESSAGE;
  END IF;
  -- 年度判断
  NRETURN := FUNCNENDOCHK(BNENDO);
  IF NRETURN <> c_SYORI_OK THEN
    GOTO ERROR_MESSAGE;
  END IF;
  -- 計算個人存在で且つ引数の年度≧引数の処理日から判定した年度 かつ賦課年度=相当年度の場合
  IF NKOJINCNT > 0 AND BNENDO = TRUE AND i_NNENDO = i_NNENDO_BUN THEN

    -- 普徴月の判定
    NRETURN := FUNCFUGETSU(NGFUTU_TUKI);
    IF NRETURN != c_SYORI_OK THEN
      GOTO ERROR_MESSAGE;
    END IF;
    o_NFUTU_TUKI := NGFUTU_TUKI;--（１）
--  場所移動（特徴対象者情報取得後に実施する）
--    -- 特徴月判定

    -- 特徴対象者情報取得

    NRETURN := FUNCTOKUJOHOGET;
    IF NRETURN != c_SYORI_OK THEN
      GOTO ERROR_MESSAGE;
    END IF;

    -- 特徴月判定
    NRETURN := FUNCTOKUGETSU;
    IF NRETURN != c_SYORI_OK THEN
      GOTO ERROR_MESSAGE;
    END IF;

    -- 特徴対象判定の要否判定
    NRETURN := FUNCTAISYOHAITEI(NTAISYOHANTEI);
    IF NRETURN != c_SYORI_OK THEN
      GOTO ERROR_MESSAGE;
    END IF;

    -- 普徴対象判定の場合
    IF NTAISYOHANTEI = c_NFUTSU THEN
      -- 普徴期割
      NRETURN := FUNCFUKIWARI;
      IF NRETURN != c_SYORI_OK THEN
        GOTO ERROR_MESSAGE;
      END IF;

    -- 中止判定の場合
    ELSIF NTAISYOHANTEI = c_NTYUSHIHANTEI OR NTAISYOHANTEI = c_NTYUSHISHORI THEN
      -- 特徴中止処理
      NRETURN := FUNCTOKUSTOP(NTAISYOHANTEI);
      IF NRETURN != c_SYORI_OK THEN
        GOTO ERROR_MESSAGE;
      END IF;
    -- 特徴対象判定の場合
    ELSIF NTAISYOHANTEI = c_NTOKUHANTEI OR NTAISYOHANTEI = c_NTOKUKAISHI THEN
      -- 特徴開始処理
      NRETURN := FUNCTOKUSTART(NTAISYOHANTEI);
      IF NRETURN != c_SYORI_OK THEN
        GOTO ERROR_MESSAGE;
      END IF;
    END IF;

    -- 処理年と年度分が同一の場合のみ継続チェックを行う
    IF i_NNENDO_BUN = TRUNC(i_NSHORIBI, -4) / 10000 AND IZAN_MODE = 0 THEN
    IF NVL(ZLBPK00010.FCFFJKN2(423),0) = 0 THEN
      IF o_NFUTU_TUKI < 9 THEN
        NRETURN := FUNCTOKUKEIZOKUCHK(NwKAISHITUSKI);
        o_NFUTU_TUKI := NwKAISHITUSKI;
      END IF;
    ELSE
      IF o_NFUTU_TUKI < 8 THEN
        NRETURN := FUNCTOKUKEIZOKUCHK(NwKAISHITUSKI);
        o_NFUTU_TUKI := NwKAISHITUSKI;
      ELSE
        -- 併徴チェック
        IF FUNCHEICHOCHK THEN
          -- 併徴世帯の更正のときは、ZLBPK00010.FCFFJKN2(423)=0 と同じ判定とする。
          IF o_NFUTU_TUKI < 9 THEN
            NRETURN := FUNCTOKUKEIZOKUCHK(NwKAISHITUSKI);
            o_NFUTU_TUKI := NwKAISHITUSKI;
          END IF;
        ELSE
        --普徴期間開始月補正
        NRETURN := FUNCFUTUKAISHIHOSEI(NwKAISHITUSKI);
        IF NRETURN != c_SYORI_OK THEN
          GOTO ERROR_MESSAGE;
        END IF;
        o_NFUTU_TUKI := NwKAISHITUSKI;
        END IF;
      END IF;
    END IF;
    END IF;
    -- 後半普徴の対象の場合
    IF NKOUFUTU_FLG = 1 THEN
      --特徴月のクリア
      o_NTOKU_TUKI := 0;
    END IF;

    -- ZLBTTOKU_IDOのINSERTフラグが1の場合
    IF NINS_FLG = 1 THEN
      -- 作成したZLBTTOKU_IDOを削除する
      DELETE FROM ZLBTTOKU_IDO
      WHERE  KOKU_SETAI_NO = i_NSETAI
        AND  KOJIN_NO      = NNUSHI_KOJIN_NO
        AND  R_NO          = NRIREKI_NO + 1
        AND  SYORI_FLG     = 0;
    END IF;

  -- 過年度処理の場合は、普徴更正のみ。
  ELSE
    -- 普徴月の判定
    NRETURN := FUNCFUGETSU(NGFUTU_TUKI);
    o_NFUTU_TUKI := NGFUTU_TUKI;
    IF NRETURN != c_SYORI_OK THEN
      GOTO ERROR_MESSAGE;
    END IF;

    -- 普徴期割
    NRETURN := FUNCFUKIWARI;
    IF NRETURN != c_SYORI_OK THEN
      GOTO ERROR_MESSAGE;
    END IF;
  END IF;

  <<ERROR_MESSAGE>>
  -- エラーログ
  IF VMSG IS NOT NULL THEN
    VMSG  := SUBSTR(VMSG, 1, 256);
    IF SQLCODE = 0 THEN
       bRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBFKKIWARIHT', 1, '', '','ZLBFKKIWARIHT ' || VMSG, '', i_VTANMATSU);
    ELSE
       bRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBFKKIWARIHT', 1, SQLCODE, SQLERRM,'ZLBFKKIWARIHT ' || VMSG, '', i_VTANMATSU);
    END IF;
  END IF;
  RETURN(NRETURN);
END ZLBFKKIWARIHT;
/
