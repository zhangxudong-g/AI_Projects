CREATE OR REPLACE FUNCTION ZLBFCCALHALFHT(i_NKOKU_SETAI_NO    IN NUMBER      -- 国保世帯番号
--1.1.200.000
                                                  , i_NDANTAICD         IN NUMBER      -- 算定団体コード
                                                  , i_NCHOTEINENDO      IN NUMBER      -- 年度
                                                  , i_NNENDOBUN         IN NUMBER      -- 年度分
                                                  , i_NTSUCHI_NO        IN NUMBER      -- 通知書番号
                                                  , i_NKOJIN_NO         IN NUMBER      -- 個人番号
                                                  , i_VSYS_TANMATSU_NO  IN NVARCHAR2
                                                  , o_NHANTEI_KEKKA     OUT NUMBER
                                                   )RETURN NUMBER
-------------------------------------------------------------------------------
--  業務名    ZLB（国民健康保険税）
--  PG名      ZLBFCCALHALFHT
--  名称      賦課計算1/2判定処理
--  処理概要  国保税保険料が特別徴収可能かどうか判定する。
--  引数      i_NKOKU_SETAI_NO          国保世帯番号
--            i_NDANTAICD               算定団体コード
--            i_NCHOTEINENDO            年度
--            i_NNENDOBUN               年度分
--            i_NTSUCHI_NO              通知書番号
--            i_NKOJIN_NO               個人番号
--            i_NSYS_KOSHINBI           更新日
--            i_NSYS_JIKAN              更新時間
--            i_NSYS_SHOKUINKOJIN_NO    職員個人番号
--            i_VSYS_TANMATSU_NO        端末番号
--            o_NHANTEI_KEKKA           判定結果(1:1/2以下, 2:1/2以上, 3:金額0(介護特徴中止), 4:特徴依頼保険料０円)
--  作成者        ZCZL.DUYUANYUAN
--  作成日        2023/08/01
--  Version       0.2.000.000
-------------------------------------------------------------------------------------
--  変更履歴
--  2025/08/11 ZCZL.WANGMING UPDATE 1.1.200.000: 子ども子育て支援金対応
-------------------------------------------------------------------------------------
IS
  -- コンスト定義
  c_NGYOMUCD_KOKU  CONSTANT PLS_INTEGER    := 15;                    -- 業務コード(国保税)
  c_NGYOMUSCD_TOK  CONSTANT PLS_INTEGER    := 2;                     -- 業務詳細コード(特徴)
  c_NGYOMUSCD_FU   CONSTANT PLS_INTEGER    := 1;                     -- 業務詳細コード(普徴)
  -- 処理結果定数
  c_SHORI_OK       CONSTANT NUMBER         := 0;                     -- 正常
  c_SHORI_NG       CONSTANT NUMBER         := 1;                     -- 異常
  -- 設定定数
  c_KEKKA_UNDER    CONSTANT NUMBER         := 1;                     -- 1/2以下
  c_KEKKA_OVER     CONSTANT NUMBER         := 2;                     -- 1/2以上
  c_KEKKA_ZERO     CONSTANT NUMBER         := 3;                     -- 金額0(介護特徴中止)
  c_KEKKA_HZERO    CONSTANT NUMBER         := 4;                     -- 特徴依頼保険料０円
  -- 通知内容コード
  c_TUTI_IRAI      CONSTANT NVARCHAR2(5)  := '01';                   --通知内容コード（特徴依頼情報）
  c_TUIKA_IRAI     CONSTANT NVARCHAR2(5)  := '31';                   --通知内容コード（特徴追加依頼通知）
  --------------------------------------------------------------------
  -- メインプロシージャ内変数定義
  IRTN                         PLS_INTEGER;    -- リターンコード
  NKIWARIGAKU                  NUMBER(10);     -- 期割額
  NKAIGOHOKENRYO               NUMBER(10);     -- 介護保険料
  NRETURN                      NUMBER;         -- 処理結果
  NHANTEI_KEKKA                NUMBER;         -- 判定結果
  NKISO_NENKIN_NO              NUMBER;         -- 基礎年金番号
  NKAIGOHOKENRYO1              NUMBER;         -- 介護保険料１
  NKAIGOHOKENRYO2              NUMBER;         -- 介護保険料２
  NNENKINGAKU                  NUMBER;         -- 年金受給額
--------------------------------------------------------------------------------
-- S00 初期処理
--------------------------------------------------------------------------------
FUNCTION FUNC_INIT RETURN BOOLEAN IS
  BRETURN BOOLEAN; --リターン値
BEGIN
  --項目初期化
  IRTN              := 0;                      -- 返却値
  NKIWARIGAKU       := 0;                      -- 期割額
  NKAIGOHOKENRYO    := 0;                      -- 介護保険料
  NRETURN           := c_SHORI_OK;             -- 処理結果
  NHANTEI_KEKKA     := 0;                      -- 判定結果
  NKISO_NENKIN_NO   := 0;                      -- 基礎年金番号
  NKAIGOHOKENRYO1   := 0;                      -- 介護保険料１
  NKAIGOHOKENRYO2   := 0;                      -- 介護保険料２
  BRETURN           := TRUE;
  RETURN(BRETURN);  -- 終了
EXCEPTION
  WHEN OTHERS THEN
    RETURN(FALSE);  -- 異常終了
END FUNC_INIT;
--------------------------------------------------------------------------------
-- S01 年金受給額取得
--------------------------------------------------------------------------------
FUNCTION FUNCGET_NENKINGAKU RETURN BOOLEAN IS
  BRETURN BOOLEAN;              -- リターン値

BEGIN
  BEGIN

    BRETURN := TRUE;
    -- 特徴捕捉情報より、年金受給額・基礎年金番号を取得する
    SELECT KAKUSHU_KINGAKU_3,KISO_NENKIN_NO
      INTO NNENKINGAKU,NKISO_NENKIN_NO
      FROM ZLBTTOKU_HOSOKU
     WHERE TOKU_KOJIN_NO = i_NKOJIN_NO     -- 個人番号
       AND HOSOKU_NENDO  = i_NCHOTEINENDO  -- 補足年度
       AND SAKUSEI_BI =                   -- MAX作成日
   (SELECT MAX(SAKUSEI_BI)
      FROM ZLBTTOKU_HOSOKU
     WHERE TOKU_KOJIN_NO = i_NKOJIN_NO    -- 個人番号
       AND HOSOKU_NENDO  = i_NCHOTEINENDO  -- 補足年度
    );
  EXCEPTION
    WHEN OTHERS THEN
      BRETURN := FALSE;  -- 特徴捕捉情報無し=エラーの場合、期割判定側で普徴とする。
      IRTN := c_SHORI_NG;
      RAISE;
  END;
  RETURN(BRETURN);  --終了
END FUNCGET_NENKINGAKU;
--------------------------------------------------------------------------------
-- S02 介護保険料の取得
--------------------------------------------------------------------------------
FUNCTION FUNCGET_KAIGODATA RETURN BOOLEAN IS
  BRETURN BOOLEAN; --リターン値
  -- 介護特徴結果（2007年度用）カーソル
  CURSOR CKAIGO IS
    SELECT TSUCHINAIYOU_CD, NVL(KINGAKU1, 0) AS KINGAKU1, NVL(KINGAKU2, 0) AS KINGAKU2
      FROM ZLBT_TOKUTYO_TAISHOUSHA
        WHERE KISONENKIN_BANGO  = NKISO_NENKIN_NO           -- 基礎年金番号
        ORDER BY SAKUSEIBI DESC;
  RKTBL  CKAIGO%ROWTYPE;
  NSAKUSEIBI  NUMBER(8);
BEGIN
  BEGIN
    -- カーソルのOPEN
    OPEN CKAIGO;

    --データ取得
    LOOP
      FETCH CKAIGO INTO RKTBL;
      EXIT WHEN CKAIGO%NOTFOUND;
      -- 取得データ取り出し
        NKAIGOHOKENRYO := RKTBL.KINGAKU1;                  -- 通知内容コード３１(特徴追加依頼通知：金額１)

        --介護保険料設定
        NKAIGOHOKENRYO1 := RKTBL.KINGAKU1;
        NKAIGOHOKENRYO2 := RKTBL.KINGAKU2;

        EXIT;
    END LOOP;

    --カーソルのCLOSE
    IF CKAIGO%ISOPEN THEN
      CLOSE CKAIGO;
    END IF;

    BRETURN := TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      BRETURN := FALSE;
      IRTN := c_SHORI_NG;
      --カーソルのCLOSE
      IF CKAIGO%ISOPEN THEN
        CLOSE CKAIGO;
      END IF;
      RAISE;
  END;
  RETURN(BRETURN);  --終了
END FUNCGET_KAIGODATA;
--------------------------------------------------------------------------------
-- S03 期割情報取得
--------------------------------------------------------------------------------
FUNCTION FUNCGET_KIWARIGAKU RETURN BOOLEAN IS
  BRETURN       BOOLEAN;        -- リターン値
  NwKIHON       NUMBER(10);     -- 年税医療
  NwKIHON_KAI   NUMBER(10);     -- 年税介護
  NwKIHON_SIEN  NUMBER(10);     -- 年税支援
  NwKIHON_SUM   NUMBER(10);     -- 年税合計
  NwCHOTEI_K    NUMBER(10);     -- 仮徴収（仮算定）
  NwCHOTEI_KF   NUMBER(10);     -- 仮徴収（仮算定）普徴
  NwCHOTEI_KT   NUMBER(10);     -- 仮徴収（仮算定）特徴
  NwCHOTEI_8    NUMBER(10);     -- ８月仮徴収金額
  NwKIWARIMAE   NUMBER(10);     -- 期割基準額
  NwKIWARI10    NUMBER(10);     -- 期割額
  NwKIWARITK    NUMBER(10);     -- 期割額特徴
--  2025/08/11 ZCZL.WANGMING ADD 1.1.200.000: 子ども子育て支援金対応
  NwKIHON_KDM   NUMBER(10);     -- 年税子ども
BEGIN
  BEGIN

-- �@-1計算基本（_CAL）より年税額の合計
    SELECT NENZEI
      INTO NwKIHON
      FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO           -- 国保世帯番号
       AND SANTEIDANTAI_CD   = i_NDANTAICD                -- 算定団体コード
       AND CHOTEI_NENDO      = i_NCHOTEINENDO             -- 調定年度
       AND NENDO_BUN         = i_NNENDOBUN                -- 年度分
       AND TSUCHI_NO         = i_NTSUCHI_NO               -- 通知書番号
       AND SYS_TANMATSU_NO   = i_VSYS_TANMATSU_NO;        -- 端末番号
-- �@-2計算介護基本（_CAL）より年税額の合計
    SELECT NENZEI
      INTO NwKIHON_KAI
      FROM ZLBTKAI_KIHON_CAL
     WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO           -- 国保世帯番号
       AND SANTEIDANTAI_CD   = i_NDANTAICD                -- 算定団体コード
       AND CHOTEI_NENDO      = i_NCHOTEINENDO             -- 調定年度
       AND NENDO_BUN         = i_NNENDOBUN                -- 年度分
       AND TSUCHI_NO         = i_NTSUCHI_NO               -- 通知書番号
       AND SYS_TANMATSU_NO   = i_VSYS_TANMATSU_NO;        -- 端末番号
-- �@-3計算支援基本（_CAL）より年税額の合計
    SELECT NENZEI
      INTO NwKIHON_SIEN
      FROM ZLBTSIEN_KIHON_CAL
     WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO           -- 国保世帯番号
       AND SANTEIDANTAI_CD   = i_NDANTAICD                -- 算定団体コード
       AND CHOTEI_NENDO      = i_NCHOTEINENDO             -- 調定年度
       AND NENDO_BUN         = i_NNENDOBUN                -- 年度分
       AND TSUCHI_NO         = i_NTSUCHI_NO               -- 通知書番号
       AND SYS_TANMATSU_NO   = i_VSYS_TANMATSU_NO;        -- 端末番号
--  2025/08/11 ZCZL.WANGMING ADD START 1.1.200.000: 子ども子育て支援金対応
    --計算子ども基本（_CAL）より年税額の合計
    SELECT NENZEI
      INTO NwKIHON_KDM
      FROM ZLBTKDM_KIHON_CAL
     WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO           -- 国保世帯番号
       AND SANTEIDANTAI_CD   = i_NDANTAICD                -- 算定団体コード
       AND CHOTEI_NENDO      = i_NCHOTEINENDO             -- 調定年度
       AND NENDO_BUN         = i_NNENDOBUN                -- 年度分
       AND TSUCHI_NO         = i_NTSUCHI_NO               -- 通知書番号
       AND SYS_TANMATSU_NO   = i_VSYS_TANMATSU_NO;        -- 端末番号
--  2025/08/11 ZCZL.WANGMING ADD END
-- �@-1から�@-3を合算
--  2025/08/11 ZCZL.WANGMING UPDATE 1.1.200.000: 子ども子育て支援金対応
--   NwKIWARIMAE := NwKIHON + NwKIHON_KAI + NwKIHON_SIEN;  -- 年税額合計を基準額にセット
   NwKIWARIMAE := NwKIHON + NwKIHON_KAI + NwKIHON_SIEN + NwKIHON_KDM;  -- 年税額合計を基準額にセット

-- �A仮徴収額（仮算定額）の合計
-- �A-1.仮徴収額（仮算定額）の合計 普徴分
    SELECT NVL(SUM(ZEN_ZEIGAKU),0)
      INTO NwCHOTEI_KF
      FROM ZLBTKIBETSU_N
     WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO           -- 国保世帯番号
       AND SANTEIDANTAI_CD   = i_NDANTAICD                -- 算定団体コード
       AND CHOTEINENDO       = i_NCHOTEINENDO             -- 調定年度
       AND NENDOBUN          = i_NNENDOBUN                -- 年度分
       AND TSUCHI_NO         = i_NTSUCHI_NO               -- 通知書番号
       AND KAMOKU_CD         = c_NGYOMUCD_KOKU            -- 科目コード
       AND KAMOKUS_CD        = c_NGYOMUSCD_FU;
-- �A-2.仮徴収額（仮算定額）の合計 特徴分
    SELECT NVL(SUM(ZEN_ZEIGAKU),0)
      INTO NwCHOTEI_KT
      FROM ZLBTKIBETSU_N
     WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO           -- 国保世帯番号
       AND SANTEIDANTAI_CD   = i_NDANTAICD                -- 算定団体コード
       AND CHOTEINENDO       = i_NCHOTEINENDO             -- 調定年度
       AND NENDOBUN          = i_NNENDOBUN                -- 年度分
       AND TSUCHI_NO         = i_NTSUCHI_NO               -- 通知書番号
       AND KAMOKU_CD         = c_NGYOMUCD_KOKU            -- 科目コード
       AND KAMOKUS_CD        = c_NGYOMUSCD_TOK;

   NwCHOTEI_K := NwCHOTEI_KF + NwCHOTEI_KT;

   IF NwKIWARIMAE < NwCHOTEI_K THEN
     BRETURN := FALSE;
     IRTN := c_SHORI_NG;
     RETURN(BRETURN);  -- 終了
   END IF;

-- �B-1 年税額 - 仮徴収額（仮算定額）

-- �B-2 ８月特徴金額取得
    SELECT NVL(COUNT(*),0)
      INTO NwCHOTEI_8
      FROM ZLBTKIBETSU_N
     WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO           -- 国保世帯番号
       AND SANTEIDANTAI_CD   = i_NDANTAICD                -- 算定団体コード
       AND CHOTEINENDO       = i_NCHOTEINENDO             -- 調定年度
       AND NENDOBUN          = i_NNENDOBUN                -- 年度分
       AND TSUCHI_NO         = i_NTSUCHI_NO               -- 通知書番号
       AND RONRIKIBETSU      = 5                          -- ８月論理期別(5)
       AND ZEN_ZEIGAKU       > 0                          --金額が1円以上
       AND KAMOKU_CD         = c_NGYOMUCD_KOKU            -- 科目コード
       AND KAMOKUS_CD        = c_NGYOMUSCD_TOK;           -- 科目詳細コード

-- �B-3 ８月特徴金額があるか？
    IF NwCHOTEI_8 > 0 THEN -- あれば年税額を3で割る
      NwKIWARI10 := NwKIWARIMAE - NwCHOTEI_KT - (2 * TRUNC((NwKIWARIMAE - NwCHOTEI_KT) / 3 , -2));
    ELSE                   -- なければ年税額を6で割る
      NwKIWARITK := NwKIWARIMAE - (3 * TRUNC(NwKIWARIMAE / 6 , -2));
      NwKIWARI10 := NwKIWARITK - (2 * TRUNC(NwKIWARITK / 3 , -2));
    END IF;

    NKIWARIGAKU := NwKIWARI10;

    BRETURN := TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      BRETURN := FALSE;
      IRTN := c_SHORI_NG;
      RAISE;
  END;
  RETURN(BRETURN);  --終了
END FUNCGET_KIWARIGAKU;
--------------------------------------------------------------------------------
-- S04 1/2判定
--------------------------------------------------------------------------------
FUNCTION FUNC_HANTEI RETURN BOOLEAN IS
  BRETURN     BOOLEAN;        --リターン値
  IGETSUGAKU  PLS_INTEGER;    --月額年金額
BEGIN
  -- 月額年金額の算出(小数点以下切捨て)
  IGETSUGAKU := FLOOR(((NNENKINGAKU / 6) / 2));

  -- 判定結果設定
  IF NKAIGOHOKENRYO = 0 THEN
    NHANTEI_KEKKA := c_KEKKA_ZERO;                           -- 3:介護保険料=0の場合
  ELSE
    IF (NKAIGOHOKENRYO + NKIWARIGAKU) > IGETSUGAKU THEN
      NHANTEI_KEKKA := c_KEKKA_OVER;                         -- 2:介護保険料+期割保険料＞年金保険料の場合
    ELSE
      NHANTEI_KEKKA := c_KEKKA_UNDER;                        -- 1:介護保険料+期割保険料≦年金保険料の場合
    END IF;

    IF NKIWARIGAKU = 0 THEN
      NHANTEI_KEKKA := c_KEKKA_HZERO;                        -- 4:期割保険料がゼロの場合
    END IF;
  END IF;
  BRETURN := TRUE;
  RETURN(BRETURN);  --終了
EXCEPTION
  WHEN OTHERS THEN
    RETURN(FALSE);  --異常終了
END FUNC_HANTEI;
--------------------------------------------------------------------------------
-- S05 結果データ保存
--------------------------------------------------------------------------------
FUNCTION FUNC_DATAMAKE RETURN BOOLEAN IS
  BRETURN     BOOLEAN;        --リターン値
BEGIN

  INSERT INTO ZLBWHALFHANTEI VALUES (
                                 i_NKOKU_SETAI_NO,
                                 i_NCHOTEINENDO,
                                 i_NNENDOBUN,
                                 NHANTEI_KEKKA,
                                 NKAIGOHOKENRYO,
                                 NKIWARIGAKU,
                                 NNENKINGAKU,
                                 i_NTSUCHI_NO,
                                 i_NKOJIN_NO
                                );

  BRETURN := TRUE;
  RETURN(BRETURN);  --終了
EXCEPTION
  WHEN OTHERS THEN
    RETURN(FALSE);  --異常終了
END FUNC_DATAMAKE;
--------------------------------------------------------------------------------
-- メイン処理
--------------------------------------------------------------------------------
BEGIN
  NRETURN := 0;
  /* 初期処理 */
  IF FUNC_INIT = FALSE THEN
      NRETURN := 1;
  END IF;

  /* S01 年金受給額取得 */
  IF NRETURN = 0 THEN
    IF FUNCGET_NENKINGAKU = FALSE THEN
        NRETURN := 1;
    END IF;
  END IF;

  /* S02 介護保険料取得 */
  IF NRETURN = 0 THEN
    IF FUNCGET_KAIGODATA = FALSE THEN
        NRETURN := 1;
    END IF;
  END IF;

  /* S03 期割額取得 */
  IF NRETURN = 0 THEN
    IF FUNCGET_KIWARIGAKU = FALSE THEN
        NRETURN := 1;
    END IF;
  END IF;

  /* S04 1/2判定 */
  IF NRETURN = 0 THEN
    IF FUNC_HANTEI = FALSE THEN
        NRETURN := 1;
    END IF;
  END IF;

  /* S05 結果データ保存 */
  IF NRETURN = 0 THEN
    IF FUNC_DATAMAKE = FALSE THEN
        NRETURN := 1;
    END IF;
  END IF;
  DBMS_OUTPUT.PUT_LINE('判定結果:' || NHANTEI_KEKKA);
  DBMS_OUTPUT.PUT_LINE('受給年金額:' || NNENKINGAKU);
  DBMS_OUTPUT.PUT_LINE('介護保険料:' || NKAIGOHOKENRYO);
  DBMS_OUTPUT.PUT_LINE('期割額10月:' || NKIWARIGAKU);
  -- パラメータ返却値設定
  o_NHANTEI_KEKKA    := NHANTEI_KEKKA;                -- 判定結果
  RETURN(NRETURN);
END ZLBFCCALHALFHT;
/
