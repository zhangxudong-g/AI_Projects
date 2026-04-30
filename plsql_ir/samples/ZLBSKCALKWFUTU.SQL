CREATE OR REPLACE PROCEDURE        ZLBSKCALKWFUTU(i_NGENKA_KBN            IN  NUMBER,
--1.1.200.000
                                                        i_NTSUCHI_NO            IN  NUMBER,
                                                        i_NNENDO                IN  NUMBER,
                                                        i_NNENDO_BUN            IN  NUMBER,
                                                        i_NSHORIBI              IN  NUMBER,
                                                        i_NDANTAI               IN  NUMBER,
                                                        i_NSETAI                IN  NUMBER,
                                                        i_NJIKKOU_KBN           IN  NUMBER,
                                                        i_NFUTU_TUKI            IN  NUMBER,
                                                        i_NTOKU_TUKI            IN  NUMBER,
                                                        i_NKEISAN_KBN           IN  NUMBER,
                                                        i_NCHUSHI_JIYU          IN  NUMBER,
                                                        i_VTANMATSU             IN  NVARCHAR2,
                                                        i_NTRENBAN              IN  NUMBER,
                                                        o_NRESULT               OUT NUMBER,
                                                        i_NKOSEIBI              IN  NUMBER := 0)
-------------------------------------------------------------------------------
-- 業務名   ZLB（国保税）
-- ＰＧ名   ZLBSKCALKWFUTU
-- 名称     計算普徴期別作成
-- 処理概要 賦課基本、賦課期別、計算基本を元に期割計算を行なう。
--          税額試算の場合は賦課TBLではなく更正前TBLを元に期割計算を行なう。
-- 　引き数   i_NGENKA_KBN            現年・過年区分(0:現年 1:過年)
--          i_NTSUCHI_NO            通知書番号
--          i_NNENDO                調定年度
--          i_NNENDO_BUN            年度分
--          i_NSHORIBI              処理日
--          i_NDANTAI               算定団体コード
--          i_NSETAI                国保世帯番号(ログ出力用)
--          i_NJIKKOU_KBN           実行区分(0:バッチから起動 本算定
--                                           1:バッチから起動 月例
--                                           2:オンライン起動 税額試算
--                                           3:オンライン起動 即時)
--          i_NFUTU_TUKI            普徴月
--          i_NTOKU_TUKI            特徴月
--          i_NKEISAN_KBN           計算区分(1:普徴更正(金額調整)
--                                           2:特徴開始
--                                           3:特徴中止
--                                           4:普徴更正(特徴中止)
--                                           11:特徴依頼取消)
--          i_NCHUSHI_JIYU          中止事由,
--          i_VTANMATSU             端末番号
--          i_NTRENBAN              登録連番
--          o_NRESULT               処理結果
--          i_NKOSEIBI              更正日（入力なし:システム日付、入力あり:入力値を使用）
--  作成者   ZCZL.GUORUIHUA
--  作成日   2023/08/01
--  Version 0.2.000.000
-------------------------------------------------------------------------------
--変更履歴
--  2024/09/18 ZCZL.TAOYAN UPDATE 0.3.000.001:国保2次故障対応_IT_ZLB_00018
--  2025/08/11 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応
-------------------------------------------------------------------------------

IS
    TYPE MTNUMARRAY1  IS TABLE OF NUMBER(1)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY4  IS TABLE OF NUMBER(4)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY8  IS TABLE OF NUMBER(8)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY10 IS TABLE OF NUMBER(10) INDEX BY BINARY_INTEGER;
--  2024/09/18 ZCZL.TAOYAN UPDATE 0.2.000.001:国保2次故障対応_IT_ZLB_00018
    --TYPE MTNUMARRAY12 IS TABLE OF NUMBER(12) INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY12 IS TABLE OF NUMBER(20) INDEX BY BINARY_INTEGER;
-------------------------------------------------------------------------------
-- 定数の定義
-------------------------------------------------------------------------------
    c_NOK               CONSTANT NUMBER(1)  := 0;   -- 処理正常
    c_NERR              CONSTANT NUMBER(1)  := 1;   -- 処理異常
    -- エラーログSTEP NO
    c_NSTEPNO           CONSTANT NUMBER := 99;
    c_NKAMOKU_CD        CONSTANT NUMBER(3)  := 15;  -- 科目コード
    c_NKAMOKUS_FUTU     CONSTANT NUMBER(2)  := 1;   -- 科目詳細コード：普通
    c_NKAMOKUS_TOKU     CONSTANT NUMBER(2)  := 2;   -- 科目詳細コード：特徴
    -- 端数
    c_NHASU_1           CONSTANT NUMBER := -3;
    c_NHASU_2           CONSTANT NUMBER := -2;
    c_NHASU_3           CONSTANT NUMBER := 0;
    c_NHASU_10          CONSTANT NUMBER := -1;
    c_NHASU_KBN_1       CONSTANT NUMBER := 0;       -- c_NHASU_1に対応
    c_NHASU_KBN_2       CONSTANT NUMBER := 1;       -- c_NHASU_2に対応
    c_NHASU_KBN_3       CONSTANT NUMBER := 2;       -- c_NHASU_3に対応
    c_NHASU_KBN_10      CONSTANT NUMBER := 3;
    -- 処理区分
    c_NMODE_ZEN         CONSTANT NUMBER(1) := 0;    -- 全体処理
    c_NMODE_TAI         CONSTANT NUMBER(1) := 1;    -- 退職処理
    -- 実行区分
    c_NBATCH_H          CONSTANT NUMBER(1) := 0;    -- バッチから起動 本算定
    c_NBATCH_G          CONSTANT NUMBER(1) := 1;    -- バッチから起動 月例
    c_NONL_CALZEI       CONSTANT NUMBER(1) := 2;    -- オンライン起動 税額試算
    c_NONL_SOKUJI       CONSTANT NUMBER(1) := 9;    -- オンライン起動 即時
    -- 計算区分
    c_NKEI_CHOSEI       CONSTANT NUMBER(1) := 1;    -- 普徴更正(金額調整)
    c_NKEI_STR_TOKU     CONSTANT NUMBER(1) := 2;    -- 特徴開始
    c_NKEI_STP_TOKU     CONSTANT NUMBER(1) := 3;    -- 特徴中止
    c_NKEI_CHOSEI_STP   CONSTANT NUMBER(1) := 4;    -- 普徴更正(特徴中止)
    c_NKEI_CNL_TOKU     CONSTANT NUMBER(2) := 11;   -- 特徴依頼取消
    -- 現年・過年
    c_NGENNEN           CONSTANT NUMBER(1) := 0;    -- 現年
    c_NKANEN            CONSTANT NUMBER(1) := 1;    -- 過年
    -- 算定団体
    c_NDANTAI           CONSTANT NUMBER := 1;       -- 合併後算定団体
    -- 不均一課税
    c_NFKAZEI           CONSTANT NUMBER := 1;       -- 不均一課税を行なう
    -- 市町村コード
    c_KIKUCHI           CONSTANT PLS_INTEGER := 43210;  -- 菊池市
    c_HAGI              CONSTANT PLS_INTEGER := 35204;  -- 萩市
    c_UWAJIMA           CONSTANT PLS_INTEGER := 38203;  -- 宇和島市
    c_TAMANA            CONSTANT PLS_INTEGER := 43206;  -- 玉名市
    c_KAMIAMA           CONSTANT PLS_INTEGER := 43212;  -- 上天草市
    c_YAMATO            CONSTANT PLS_INTEGER := 43447;  -- 山都町
    c_DATE              CONSTANT PLS_INTEGER := 12335;  --伊達市
    c_SASEBO            CONSTANT PLS_INTEGER := 42202;  --佐世保市
-------------------------------------------------------------------------------
-- ワークエリアの定義
-------------------------------------------------------------------------------
    NlRTN                   NUMBER(1);
    BlRTN                   BOOLEAN;
    VlMSG                   NVARCHAR2(100);
    NlTSUCHI_NO             NUMBER(12);         -- 通知書番号
    NlNENZEI                NUMBER(10);         -- 年税額
    NlGENMEN                NUMBER(10);         -- 減免額
    NlTAI_NENZEI            NUMBER(10);         -- 退年税額
    NlTAI_GENMEN            NUMBER(10);         -- 退減免額
    NlKAI_NENZEI            NUMBER(10);         -- 介護年税額
    NlKAI_TAI_NENZEI        NUMBER(10);         -- 介護退年税額
    NlNENZEI_SV             NUMBER(10);         -- 保存用年税額
    NlNENZEI_HAN            NUMBER(12);         -- 増減判定用年税額
    NlSAGAKU                NUMBER(10);         -- 差額
    NlZEN_SAGAKU            NUMBER(10);         -- 全差額
    NlZENTAI_SAGAKU         NUMBER(10);         -- 全退職差額
    NlTAI_SAGAKU            NUMBER(10);         -- 退差額
    NlKAI_SAGAKU            NUMBER(10);         -- 介護差額
    NlKAI_TAI_SAGAKU        NUMBER(10);         -- 介護退差額
    NlLOOP_FLG              NUMBER(1);
    NlCUT_COL               NUMBER;
    NlKIWARIDANTAI_CD       NUMBER;             -- 期割団体コード(過年度：収納条件取得時使用)
    NlZO_FLG                NUMBER(1);          -- 増FLG（0:減/1:増）
    MIKIWARIHOUHOU          NUMBER;             --期割方法の条件設定（0：地方税方による 1：均し）
    MIKIJYUN_KIWARIGK       NUMBER;             --最低期割基準額
    MIKIJYUN_TEKIYOU        NUMBER;             --最低期割基準適用（0：なし 1：本算定のみ ２：常に適用）
    NlSHIME_NENGETSU        NUMBER;             --本算定時処理判定
    BlSHORI_HANI_FLG BOOLEAN;                   --処理範囲中判断フラグ
    c_NNOKI_HON       NUMBER(2)   := 2;         -- 納期区分 (2:本算定
    NlSIEN_NENZEI           NUMBER(10);         -- 支援年税額
    NlSIEN_TAI_NENZEI       NUMBER(10);         -- 支援退年税額
    NlSIEN_SAGAKU           NUMBER(10);         -- 支援差額
    NlSIEN_TAI_SAGAKU       NUMBER(10);         -- 支援退差額
    MlKAMOKUS               MTNUMARRAY4;        -- 科目詳細コード
    MlNOUKI                 MTNUMARRAY1;        -- 納期区分
    MlKIBETSU               MTNUMARRAY4;        -- 期別
    MlIRY_ZEI               MTNUMARRAY8;        -- 医療全体税額
    MlIRY_TAI_ZEI           MTNUMARRAY8;        -- 医療退職税額
    MlKAI_ZEI               MTNUMARRAY8;        -- 介護全体税額
    MlKAI_TAI_ZEI           MTNUMARRAY8;        -- 介護退職税額
    MlKIZEI                 MTNUMARRAY10;       -- 期別税額
    MlTAI_KIZEI             MTNUMARRAY10;       -- 退期別税額
    MlNUSI_KOJIN_NO         MTNUMARRAY12;       -- 主個人番号
    MlSIEN_ZEI              MTNUMARRAY8;        -- 支援全体税額
    MlSIEN_TAI_ZEI          MTNUMARRAY8;        -- 支援退職税額
    MlCAL_KAMOKUS           MTNUMARRAY4;        -- 科目詳細コード
    MlCAL_CHOTEI_NENDO      MTNUMARRAY8;        -- 計算調定年度
    MlCAL_NENDO_BUN         MTNUMARRAY8;        -- 計算年度分
    MlCAL_TSUCHI_NO         MTNUMARRAY12;       -- 計算通知書番号
    MlCAL_KIBETSU           MTNUMARRAY8;        -- 計算期別
    MlCAL_NUSI_KOJIN_NO     MTNUMARRAY12;       -- 計算主個人番号
    MlCAL_ZEI               MTNUMARRAY10;       -- 計算全体税額
    MlCAL_TAI_ZEI           MTNUMARRAY10;       -- 計算退職税額
    MlCAL_NOUFU_KBN         MTNUMARRAY4;        -- 計算納付書区分
    RlKIHONCAL              ZLBTKIHON_CAL%ROWTYPE;      -- 計算基本
    RlTAICAL                ZLBTTAI_CAL%ROWTYPE;        -- 計算退職
    RlKAIKIHONCAL           ZLBTKAI_KIHON_CAL%ROWTYPE;  -- 計算介護基本
    RlKAITAICAL             ZLBTKAI_TAI_CAL%ROWTYPE;    -- 計算介護退職
    RlKIBETSUCAL            ZLBTKIBETSU_CAL%ROWTYPE;    -- 計算期別
    RlSIENKIHONCAL          ZLBTSIEN_KIHON_CAL%ROWTYPE; -- 計算支援基本
    RlSIENTAICAL            ZLBTSIEN_TAI_CAL%ROWTYPE;   -- 計算支援退職
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
    RlKDMKIHONCAL           ZLBTKDM_KIHON_CAL%ROWTYPE;  -- 計算子ども基本
    MlKDM_ZEI               MTNUMARRAY10;        -- 子ども全体税額
    NlKDM_NENZEI            NUMBER(10);         -- 子ども年税額
    NlKDM_SAGAKU            NUMBER(10);         -- 子ども差額
-- 2025/08/11 ZCZL.LIUDI ADD END
    -- 税額更正で更正後の税額が現在の期別でおさまる場合の期割のやり方
    IKIWARI_STYLE           PLS_INTEGER := 0;   --（0:現在期におめてしまう, 1:現在期以降も振り付け）
    NSHORIBI                NUMBER(8);                  -- 処理日
    NFUTU_TUKI              NUMBER(3);                  -- 普徴月
    RICTLPRM                KKATCT .CTLPRM%TYPE;  -- 共通コンスタントパラメータ
    MINOKIGEN               MTNUMARRAY8;                -- 納期限(配列)
    NDATE                   NUMBER;                     -- システム日付用
    INOKI_FROM              PLS_INTEGER;    --仮算定開始インデックス（1:４月、2:５月・・・12:３月）
    INOKI_TO                PLS_INTEGER;    --仮算定終了インデックス（1:４月、2:５月・・・12:３月）
    INOKI                   PLS_INTEGER;    --期割用納期
    IZAN_MODE               PLS_INTEGER;    -- 0:通常 1:仮算定中
    IZANTEIKIWAI_JCONS      PLS_INTEGER := 0;
    IZANTEIKIWARI_FLG       PLS_INTEGER := 0;
    IHON_GENZON_CNT         PLS_INTEGER := 0;
    NlCUT_COL_KIBETSU       NUMBER;          -- 期別税額の端数カット
    c_NONL_KIWARI           CONSTANT NUMBER(1) := 8;    -- オンライン起動 即時期割
    NlNENZEI_TOKU           NUMBER(12);         -- 増減判定用年税額・特徴

-----------------------------------------------------------
--  納期限情報取得
-----------------------------------------------------------
FUNCTION NOKIGENGET RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN         PLS_INTEGER := c_NOK;
  BRTN         BOOLEAN     := TRUE;
        -- 収納条件取得
        CURSOR CwSHUNOJKNK IS
            SELECT * FROM ZLBTSHUNOJKNK
             WHERE KAMOKU_CD       =  c_NKAMOKU_CD
               AND KAMOKUS_CD      =  c_NKAMOKUS_FUTU
               AND KIWARIDANTAI_CD =  NlKIWARIDANTAI_CD
               AND DANTAING_KBN    =  0
               AND CHOTEINENDO     =  i_NNENDO
               AND GENNENKANEN_KBN =  i_NGENKA_KBN
               AND HYOJIYOKIBETSU  >  0
             ORDER BY RONRIKIBETSU;
BEGIN
  BEGIN
    -- 配列に設定
    FOR RwSHUNOJKNK IN CwSHUNOJKNK LOOP
      MINOKIGEN(RwSHUNOJKNK.RONRIKIBETSU) := RwSHUNOJKNK.NOKIGEN;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      IRTN   := c_NERR;
  END;
  RETURN IRTN;
END NOKIGENGET;
-------------------------------------------------------------------------------
-- 納期限情報取得メイン
-------------------------------------------------------------------------------
FUNCTION FUNCNOKIGENGETMAIN RETURN NUMBER IS
  -- 変数宣言
  IRTN         PLS_INTEGER := c_NOK;
  NwIX         NUMBER(2);
BEGIN
   -- 変数初期化
   FOR NwIX IN 1..13 LOOP
     MINOKIGEN(NwIX)       := 0;       -- 納期限
   END LOOP;
   -- 納期限情報(普徴)取得
   IRTN := NOKIGENGET;
  RETURN IRTN;
END FUNCNOKIGENGETMAIN;
------------------------------------------------------------------------------
-- 特徴減額チェック  
------------------------------------------------------------------------------
FUNCTION FUNCTOKUGENCHK(i_NKOJIN_NO IN NUMBER) RETURN NUMBER IS
    NwCHOTEI_4           PLS_INTEGER := 0;
    NwCHOTEI_6           PLS_INTEGER := 0;
    NwCHOTEI_8           PLS_INTEGER := 0;
    NwCHOTEI_10          PLS_INTEGER := 0;
    NwCHOTEI_12          PLS_INTEGER := 0;
    NwCHOTEI_2           PLS_INTEGER := 0;
    NwCHOTEI_4_AF        PLS_INTEGER := 0;
    NwCHOTEI_6_AF        PLS_INTEGER := 0;
    NwCHOTEI_8_AF        PLS_INTEGER := 0;
    NwCHOTEI_10_AF       PLS_INTEGER := 0;
    NwCHOTEI_12_AF       PLS_INTEGER := 0;
    NwCHOTEI_2_AF        PLS_INTEGER := 0;
    NRETURN              NUMBER := 0;

    NHOKENRYO_B          NUMBER := 0;
    NHOKENRYO_A          NUMBER := 0;
  
    IHANTEI_MODE         NUMBER := 0;
    NJIYU                NUMBER := 0;
  
  BEGIN
        /************************/
        /* 年税の増減を判断する */
        /************************/
        -- 年税(A)を取得する＿計算TBL
-- 2025/08/11 ZCZL.LIUDI UPDATE START 1.1.200.000:子ども子育て支援金対応
        --SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0)
        --  INTO NHOKENRYO_A
        --  FROM ZLBTKIHON_CAL A, ZLBTKAI_KIHON_CAL B, ZLBTSIEN_KIHON_CAL C
        SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0) + NVL(D.NENZEI,0)
          INTO NHOKENRYO_A
          FROM ZLBTKIHON_CAL A, ZLBTKAI_KIHON_CAL B, ZLBTSIEN_KIHON_CAL C, ZLBTKDM_KIHON_CAL D
-- 2025/08/11 ZCZL.LIUDI UPDATE END
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
-- 2025/08/11 ZCZL.LIUDI UPDATE START 1.1.200.000:子ども子育て支援金対応
           --AND C.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO;
           AND C.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO
           AND D.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
           AND D.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
           AND D.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
           AND D.NENDO_BUN(+)       = A.NENDO_BUN
           AND D.TSUCHI_NO(+)       = A.TSUCHI_NO
           AND D.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO;
-- 2025/08/11 ZCZL.LIUDI UPDATE END

        -- 年税(B)を取得する＿賦課TBL
        BEGIN
-- 2025/08/11 ZCZL.LIUDI UPDATE START 1.1.200.000:子ども子育て支援金対応
          --SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0)
          --  INTO NHOKENRYO_B
          --  FROM ZLBTKIHON_N A, ZLBTKAI_KIHON_N B, ZLBTSIEN_KIHON_N C
          SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0) + NVL(D.NENZEI,0)
            INTO NHOKENRYO_B
            FROM ZLBTKIHON_N A, ZLBTKAI_KIHON_N B, ZLBTSIEN_KIHON_N C, ZLBTKDM_KIHON_N D
-- 2025/08/11 ZCZL.LIUDI UPDATE END
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
-- 2025/08/11 ZCZL.LIUDI UPDATE START 1.1.200.000:子ども子育て支援金対応
             --AND C.TSUCHI_NO(+)       = A.TSUCHI_NO;
             AND C.TSUCHI_NO(+)       = A.TSUCHI_NO
             AND D.KOKU_SETAI_NO(+)   = A.KOKU_SETAI_NO
             AND D.SANTEIDANTAI_CD(+) = A.SANTEIDANTAI_CD
             AND D.CHOTEI_NENDO(+)    = A.CHOTEI_NENDO
             AND D.NENDO_BUN(+)       = A.NENDO_BUN
             AND D.TSUCHI_NO(+)       = A.TSUCHI_NO
             AND D.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO;
-- 2025/08/11 ZCZL.LIUDI UPDATE END
        EXCEPTION
          WHEN OTHERS THEN
           NHOKENRYO_B := 0;
        END;
IF NHOKENRYO_B > NHOKENRYO_A THEN --年税が減っている場合のみ判定(税変無しOR増額は中止しない)
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_4_AF
        FROM ZLBTKIBETSU_CAL
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND SYS_TANMATSU_NO =  i_VTANMATSU 
         AND RONRIKIBETSU    = 1;
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_6_AF
        FROM ZLBTKIBETSU_CAL
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND SYS_TANMATSU_NO =  i_VTANMATSU 
         AND RONRIKIBETSU    = 3;
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_8_AF
        FROM ZLBTKIBETSU_CAL
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND SYS_TANMATSU_NO =  i_VTANMATSU 
         AND RONRIKIBETSU    = 5;
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_10_AF
        FROM ZLBTKIBETSU_CAL
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND SYS_TANMATSU_NO =  i_VTANMATSU 
         AND RONRIKIBETSU    = 7;
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_12_AF
        FROM ZLBTKIBETSU_CAL
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND SYS_TANMATSU_NO =  i_VTANMATSU 
         AND RONRIKIBETSU    = 9;
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_2_AF
        FROM ZLBTKIBETSU_CAL
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND SYS_TANMATSU_NO =  i_VTANMATSU 
         AND RONRIKIBETSU    = 11;

      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_4
        FROM ZLBTKIBETSU_N
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND RONRIKIBETSU    = 1;
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_6
        FROM ZLBTKIBETSU_N
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND RONRIKIBETSU    = 3;
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_8
        FROM ZLBTKIBETSU_N
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND RONRIKIBETSU    = 5;
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_10
        FROM ZLBTKIBETSU_N
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND RONRIKIBETSU    = 7;
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_12
        FROM ZLBTKIBETSU_N
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND RONRIKIBETSU    = 9;
      SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwCHOTEI_2
        FROM ZLBTKIBETSU_N
       WHERE KAMOKU_CD       =  c_NKAMOKU_CD
         AND KAMOKUS_CD      =  c_NKAMOKUS_TOKU
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND RONRIKIBETSU    = 11;

      IF NwCHOTEI_2 > NwCHOTEI_2_AF THEN --2月が減額になっている場合
        NRETURN := 1;--特徴中止
        RETURN(NRETURN);
      END IF;
      IF NwCHOTEI_12 > NwCHOTEI_12_AF THEN --10月が減額になっている場合
        NRETURN := 1;--特徴中止
        RETURN(NRETURN);
      END IF;
      IF NwCHOTEI_10 > NwCHOTEI_10_AF THEN --10月が減額になっている場合
        NRETURN := 1;--特徴中止
        RETURN(NRETURN);
      END IF;
      IF NwCHOTEI_8 > NwCHOTEI_8_AF THEN --8月が減額になっている場合
        NRETURN := 1;--特徴中止
        RETURN(NRETURN);
      END IF;
      IF NwCHOTEI_6 > NwCHOTEI_6_AF THEN --6月が減額になっている場合
        NRETURN := 1;--特徴中止
        RETURN(NRETURN);
      END IF;
      IF NwCHOTEI_4 > NwCHOTEI_4_AF THEN --4月が減額になっている場合
        NRETURN := 1;--特徴中止
        RETURN(NRETURN);
      END IF;
ELSE
    IHANTEI_MODE := ZLBPK00010.FCFFJKN2(83);
    IF IHANTEI_MODE = 1 THEN 
      SELECT SOSHITSU_JIYU INTO NJIYU 
        FROM KHSTSHIKAKU 
       WHERE NEW_KBN = 0 
         AND KOKU_SETAI_NO = i_NSETAI
         AND KOJIN_NO = i_NKOJIN_NO;
      IF NJIYU = 34 THEN 
        NRETURN := 1;--特徴中止
        RETURN(NRETURN);
      END IF;
    END IF;
END IF;
      RETURN(NRETURN);
  -- 異常処理
  EXCEPTION
      WHEN OTHERS THEN
        RETURN(NRETURN);
END FUNCTOKUGENCHK;
-------------------------------------------------------------------------------
-- 最大期別取得
-------------------------------------------------------------------------------
    FUNCTION funcMaxKibetsuGet(i_NwGENZAIKI IN NUMBER) RETURN NUMBER IS
        NwIX                NUMBER(2) := 0;
        NwKI                NUMBER(2);
        NwSHIK              MTNUMARRAY12;   -- 資格区分(全員)
        NwSHIK_4            NUMBER(2);
        NwSHIK_5            NUMBER(2);
        NwSHIK_6            NUMBER(2);
        NwSHIK_7            NUMBER(2);
        NwSHIK_8            NUMBER(2);
        NwSHIK_9            NUMBER(2);
        NwSHIK_10           NUMBER(2);
        NwSHIK_11           NUMBER(2);
        NwSHIK_12           NUMBER(2);
        NwSHIK_1            NUMBER(2);
        NwSHIK_2            NUMBER(2);
        NwSHIK_3            NUMBER(2);
        NwEnd               NUMBER;
        NwIDX               NUMBER := 0;
    BEGIN
        -- 計算区分が特徴開始のとき
        IF i_NKEISAN_KBN = c_NKEI_STR_TOKU THEN

            -- 特徴月が(104,106)のとき
            IF i_NTOKU_TUKI IN (104, 106) THEN
                NwKI := 13;                -- 期:13
            -- 特徴月が(1,2,3)のとき
            ELSIF i_NTOKU_TUKI < 4 THEN
                NwKI := i_NTOKU_TUKI + 9;  -- 期:特徴月+9
            ELSE
                NwKI := i_NTOKU_TUKI - 3;  -- 期:特徴月-3
            END IF;

            -- 特徴期前まででの最大納付月を取得
            FOR IDX IN REVERSE 1..(NwKI - 1) LOOP
                IF MlNOUKI(IDX) IN (2,3) THEN  
                    NwIX := IDX;
                    EXIT;
                END IF;
            END LOOP;

            -- 最大期が取得できていないときは特徴期以降での最初の納付月を取得
            IF NwIX =0 THEN
                FOR IDX IN NwKI..13 LOOP
                IF MlNOUKI(IDX) = 3 THEN
                    NwIX := IDX;
                    EXIT;
                END IF;
            END LOOP;
            END IF;

        -- 計算区分が特徴開始以外
        ELSE
            -- 全喪月チェック
            SELECT SUM(CASE WHEN SHIK_4  IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_4 ,
                   SUM(CASE WHEN SHIK_5  IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_5 ,
                   SUM(CASE WHEN SHIK_6  IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_6 ,
                   SUM(CASE WHEN SHIK_7  IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_7 ,
                   SUM(CASE WHEN SHIK_8  IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_8 ,
                   SUM(CASE WHEN SHIK_9  IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_9 ,
                   SUM(CASE WHEN SHIK_10 IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_10,
                   SUM(CASE WHEN SHIK_11 IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_11,
                   SUM(CASE WHEN SHIK_12 IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_12,
                   SUM(CASE WHEN SHIK_1  IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_1 ,
                   SUM(CASE WHEN SHIK_2  IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_2 ,
                   SUM(CASE WHEN SHIK_3  IN (1,3,11,13,21,23) THEN 1 ELSE 0 END) AS NwSHIK_3
              INTO NwSHIK(1) ,NwSHIK(2) ,NwSHIK(3) ,NwSHIK(4) ,NwSHIK(5) ,NwSHIK(6),
                   NwSHIK(7) ,NwSHIK(8) ,NwSHIK(9) ,NwSHIK(10),NwSHIK(11),NwSHIK(12)
             FROM ZLBTKOJIN_CAL
            WHERE KOKU_SETAI_NO   = i_NSETAI
              AND SANTEIDANTAI_CD = i_NDANTAI
              AND CHOTEI_NENDO    = i_NNENDO
              AND NENDO_BUN       = i_NNENDO_BUN
              AND TSUCHI_NO       = i_NTSUCHI_NO
              AND SYS_TANMATSU_NO = i_VTANMATSU;
            FOR IDX IN REVERSE 1..12 LOOP
              IF NwSHIK(IDX) > 0 THEN
                NwIDX := IDX;
                EXIT;
              END IF;
            END LOOP;
            -- 全月資格あり OR 全月資格無しの場合は+1
            IF NwIDX IN (0,12) THEN
              NwEnd := NwIDX+1;
            ELSE
              NwEnd := NwIDX;
            END IF;
            -- 仮算定期間中で仮算定全喪時期割調整を行わない場合
            -- 最終期をセットする
            IF IZAN_MODE = 1 AND ZLBPK00010.FCFFJKN2(421) = 0 THEN
              NwEnd := 13;
            END IF;
            --最終期までで最大納付月を取得
            FOR IDX IN REVERSE 1..NwEnd LOOP
              -- 仮算定期間中は暫定のみ参照
              IF IZAN_MODE = 1 THEN
                IF MlNOUKI(IDX) = 1 THEN
                    NwIX := IDX;
                    EXIT;
                END IF;
              ELSE
                IF MlNOUKI(IDX) = 3 THEN
                    NwIX := IDX;
                    EXIT;
                END IF;
              END IF;
            END LOOP;
            --Max期が引数の普徴月前であれば普徴月直近の本算定月or納期月をセット
            IF NwIX < i_NwGENZAIKI THEN
              FOR IDX IN i_NwGENZAIKI..13 LOOP
               -- 仮算定期間中は暫定のみ参照
               IF IZAN_MODE = 1 THEN
                 IF MlNOUKI(IDX) = 1 THEN
                   NwIX := IDX;
                   EXIT;
                 END IF;
               ELSE
                IF MlNOUKI(IDX) IN (2,3) THEN
                  NwIX := IDX;
                  EXIT;
                END IF;
               END IF;
              END LOOP;
            END IF;
        END IF;
        RETURN(NwIX);
    END funcMaxKibetsuGet;
-------------------------------------------------------------------------------
-- 現在期別判定
--  i_NwMODE=0:全体,1:退職 RETURN=0:到来分(処理20),1:未到来分(処理30)
-------------------------------------------------------------------------------
    FUNCTION funcGenzaiKibetsu(i_NwMODE       IN  NUMBER,
                               o_NwGENKIBETSU OUT NUMBER) RETURN NUMBER IS
        NwRTN               NUMBER;
        NwGenKibetsu        NUMBER;
        NwNEN               NUMBER;
        NwTUKI              NUMBER;
    BEGIN
        NwRTN        := 0;
        NwGenKibetsu := 0;
        -- 年と月を算出(処理日)
        NwNEN  := TRUNC(NSHORIBI, -4) / 10000;
        NwTUKI := NFUTU_TUKI;
        -- 本算定までに全部喪失チェック
        -- 全部喪失の場合は、年税額を仮算定税額とするかの判断
        IF  IZANTEIKIWAI_JCONS = 1 THEN
            IF  IHON_GENZON_CNT = 0 THEN
                IZANTEIKIWARI_FLG := 10 ;
            ELSE
                IZANTEIKIWARI_FLG := 0  ;
            END IF;
        ELSE
            IZANTEIKIWARI_FLG := 0  ;
        END IF;
        IF i_NGENKA_KBN = c_NGENNEN THEN        -- 現年
            -- 計算基本TBLの調定年度≠処理年
            IF RlKIHONCAL.CHOTEI_NENDO != NwNEN THEN
                -- 処理月＝4,5月
                IF NwTUKI IN (4, 5) THEN
                    NwGenKibetsu := 13;  --13期
                -- 処理月＝1,2,3月
                ELSIF NwTUKI IN (1, 2, 3) THEN
                    NwGenKibetsu := NwTUKI + 9; -- 処理月+9
                END IF;
            ELSE -- 以外
                -- 処理月＝1,2,3月
                IF NwTUKI IN (1, 2, 3) THEN
                    NwGenKibetsu := NwTUKI + 9; -- 処理月+9
                ELSE -- 以外
                    NwGenKibetsu := NwTUKI - 3; -- 処理月-3
                END IF;
                -- 現在期別＝1
                IF NwGenKibetsu = 1 THEN
                    IF i_NwMODE = c_NMODE_ZEN THEN     -- 処理モードが「全体」
                        NlNENZEI_SV := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0)
-- 2025/08/11 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応
                                                                     --+ NVL(RlSIENKIHONCAL.NENZEI, 0);
                                                                     + NVL(RlSIENKIHONCAL.NENZEI, 0) + NVL(RlKDMKIHONCAL.NENZEI, 0);
                    ELSE
                        NlNENZEI_SV := NVL(RlTAICAL.NENZEI, 0)   + NVL(RlKAITAICAL.NENZEI, 0)
                                                                        + NVL(RlSIENTAICAL.NENZEI, 0);
                    END IF;
                    -- 仮算定期割対応
                    IF IZAN_MODE = 1 THEN
                      NlNENZEI_TOKU := 0;
                      IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                        DECLARE
                          NNENZEI NUMBER(12);
                        BEGIN
                          -- 実行区分が即時異動期割以外の場合、仮算定額を算出する
                          IF i_NJIKKOU_KBN <> c_NONL_KIWARI THEN
                            --医療
                            ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, NwGenKibetsu,
                                                        NVL(RlKIHONCAL.NENZEI, 0),
                                                        MlIRY_ZEI(1), MlIRY_ZEI(2), MlIRY_ZEI(3), MlIRY_ZEI(4),
                                                        NNENZEI);
                            NlNENZEI_SV := NNENZEI;
                            --介護
                            ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, NwGenKibetsu,
                                                        NVL(RlKAIKIHONCAL.NENZEI, 0),
                                                        MlKAI_ZEI(1), MlKAI_ZEI(2), MlKAI_ZEI(3), MlKAI_ZEI(4),
                                                        NNENZEI);
                            NlNENZEI_SV :=  NlNENZEI_SV + NNENZEI;
                            --支援
                            ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, NwGenKibetsu,
                                                        NVL(RlSIENKIHONCAL.NENZEI, 0),
                                                        MlSIEN_ZEI(1), MlSIEN_ZEI(2), MlSIEN_ZEI(3), MlSIEN_ZEI(4),
                                                        NNENZEI);
                            NlNENZEI_SV :=  NlNENZEI_SV + NNENZEI;
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
                            --子ども
                            ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, NwGenKibetsu,
                                                        NVL(RlKDMKIHONCAL.NENZEI, 0),
                                                        MlKDM_ZEI(1), MlKDM_ZEI(2), MlKDM_ZEI(3), MlKDM_ZEI(4),
                                                        NNENZEI);
                            NlNENZEI_SV :=  NlNENZEI_SV + NNENZEI;
-- 2025/08/11 ZCZL.LIUDI ADD END
                            NlNENZEI_SV :=  TRUNC(NlNENZEI_SV,NlCUT_COL);
                          END IF;
                          -- 仮徴収額を算出する
                          FOR NwIX IN 14..19 LOOP
                            -- 納期設定判定
                            IF (MlNOUKI(NwIX) > 0)  THEN
                              NlNENZEI_TOKU := NlNENZEI_TOKU + MlKIZEI(NwIX);
                            END IF;
                          END LOOP;
                        END;
                      ELSE                            -- 退職
                        DECLARE
                          NNENZEI NUMBER(12);
                        BEGIN
                          -- 実行区分が即時異動期割以外の場合、仮算定額を算出する
                          IF i_NJIKKOU_KBN <> c_NONL_KIWARI THEN
                            --医療
                            ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, NwGenKibetsu,
                                                        NVL(RlTAICAL.NENZEI, 0),
                                                        MlIRY_TAI_ZEI(1), MlIRY_TAI_ZEI(2), MlIRY_TAI_ZEI(3), MlIRY_TAI_ZEI(4),
                                                        NNENZEI);
                            NlNENZEI_SV := NNENZEI;
                            --介護
                            ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, NwGenKibetsu,
                                                        NVL(RlKAITAICAL.NENZEI, 0),
                                                        MlKAI_TAI_ZEI(1), MlKAI_TAI_ZEI(2), MlKAI_TAI_ZEI(3), MlKAI_TAI_ZEI(4),
                                                        NNENZEI);
                            NlNENZEI_SV :=  NlNENZEI_SV + NNENZEI;
                            --支援
                            ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, NwGenKibetsu,
                                                        NVL(RlSIENTAICAL.NENZEI, 0),
                                                        MlSIEN_TAI_ZEI(1), MlSIEN_TAI_ZEI(2), MlSIEN_TAI_ZEI(3), MlSIEN_TAI_ZEI(4),
                                                        NNENZEI);
                            NlNENZEI_SV :=  NlNENZEI_SV + NNENZEI;
                            NlNENZEI_SV :=  TRUNC(NlNENZEI_SV,NlCUT_COL);
                          END IF;
                          -- 仮徴収額を算出する
                          FOR NwIX IN 14..19 LOOP
                            -- 納期設定判定
                            IF (MlNOUKI(NwIX) > 0)  THEN
                              NlNENZEI_TOKU := NlNENZEI_TOKU + MlTAI_KIZEI(NwIX);
                            END IF;
                          END LOOP;
                        END;
                      END IF;
                      -- 保存用年税額＜仮徴収額合計の場合
                      IF NlNENZEI_SV < NlNENZEI_TOKU THEN
                        -- 保存用年税額＝仮徴収額合計とする
                        NlNENZEI_SV := NlNENZEI_TOKU;
                      END IF;
                    END IF;
                    NwRTN := 1;
                END IF;
            END IF;
        ELSE    -- 過年
          --- 賦課年税＞計算年税
-- 2025/08/11 ZCZL.LIUDI UPDATE START 1.1.200.000:子ども子育て支援金対応
          --IF (NlNENZEI + NlKAI_NENZEI + NlSIEN_NENZEI) >
          --         (RlKIHONCAL.NENZEI + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0)) THEN
          IF (NlNENZEI + NlKAI_NENZEI + NlSIEN_NENZEI + NlKDM_NENZEI) >
                   (RlKIHONCAL.NENZEI + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0) + NVL(RlKDMKIHONCAL.NENZEI, 0)) THEN
-- 2025/08/11 ZCZL.LIUDI UPDATE END
              --税額「減」の場合・・・更正前年税額（医療＋介護+支援）＞更正後年税額（医療＋介護+支援）
              FOR IDX IN REVERSE 1..13 LOOP
                  --後ろの期別で有効な期別を取得
                  IF MlNOUKI(IDX) > 0 THEN
                      NwGenKibetsu := IDX;
                      EXIT;
                  END IF;
              END LOOP;
          ELSE
              --税額「増」の場合
              -- 処理月＝1,2,3月
              IF NwTUKI IN (1, 2, 3) THEN
                  NwGenKibetsu := NwTUKI + 9; -- 処理月+9
              ELSE -- 以外
                  NwGenKibetsu := NwTUKI - 3; -- 処理月-3
              END IF;
          END IF;
        END IF;
        o_NwGENKIBETSU := NwGenKibetsu;
        RETURN(NwRTN);
    END funcGenzaiKibetsu;
-------------------------------------------------------------------------------
-- 期割処理20
--  1期～現在期までの期割処理
-------------------------------------------------------------------------------
    FUNCTION funcKiwari20(i_NwMODE     IN NUMBER,
                          i_NwGENZAIKI IN NUMBER) RETURN NUMBER IS
        NwRTN               NUMBER(1);     -- 戻り値
        NwIX                NUMBER(2);     -- ループ用INDEX
        NwWK_ZEIGAKU        NUMBER;        -- マイナス直前税額
        NwWK_INDEX          NUMBER(2);     -- インデックス保持
        NwNEXT_KIBETSU      NUMBER;        -- 次期別
        NwNENZEI            NUMBER;        --計算年税
        NwSUMZEIGAKU        NUMBER;        --普徴の税額
        NwSUMZEIGAKU_TOKU   NUMBER;        --特徴の税額
    BEGIN
        -- 初期化
        NwRTN        := 0;
        NwWK_ZEIGAKU := 0;
        NlNENZEI_HAN := 0;      -- 増減判定用年税額
        NlNENZEI_SV  := 0;      -- 保存用年税額
        NwSUMZEIGAKU := 0;      
        NwSUMZEIGAKU_TOKU := 0; 
        -- 増減判定用年税額算出
        IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
-- 2025/08/11 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応
            --NlNENZEI_HAN := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0);
            NlNENZEI_HAN := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0) + NVL(RlKDMKIHONCAL.NENZEI, 0);
            NwNENZEI := NlNENZEI_HAN;  
        ELSE                            -- 退職
            NlNENZEI_HAN := NVL(RlTAICAL.NENZEI, 0) + NVL(RlKAITAICAL.NENZEI, 0) + NVL(RlSIENTAICAL.NENZEI, 0);
            NwNENZEI := NlNENZEI_HAN;  
        END IF;
        -- 本算定までに全部喪失チェック
        -- 全部喪失の場合は、年税額を仮算定税額とするかの判断
        IF  IZANTEIKIWAI_JCONS = 1 THEN
            IF  IHON_GENZON_CNT = 0 THEN
                IZANTEIKIWARI_FLG := 10 ;
            ELSE
                IZANTEIKIWARI_FLG := 0  ;
            END IF;
        ELSE
            IZANTEIKIWARI_FLG := 0  ;
        END IF;
        -- 仮算定期割対応
        IF IZAN_MODE = 1 AND i_NJIKKOU_KBN <> c_NONL_KIWARI THEN
          NlNENZEI_TOKU := 0;
          IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
            DECLARE
              NNENZEI NUMBER(12);
            BEGIN
              --医療
              ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                          NVL(RlKIHONCAL.NENZEI, 0),
                                          MlIRY_ZEI(1), MlIRY_ZEI(2), MlIRY_ZEI(3), MlIRY_ZEI(4),
                                          NNENZEI);
              NlNENZEI_HAN := NNENZEI;
              --介護
              ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                          NVL(RlKAIKIHONCAL.NENZEI, 0),
                                          MlKAI_ZEI(1), MlKAI_ZEI(2), MlKAI_ZEI(3), MlKAI_ZEI(4),
                                          NNENZEI);
              NlNENZEI_HAN :=  NlNENZEI_HAN + NNENZEI;
              --支援
              ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                          NVL(RlSIENKIHONCAL.NENZEI, 0),
                                          MlSIEN_ZEI(1), MlSIEN_ZEI(2), MlSIEN_ZEI(3), MlSIEN_ZEI(4),
                                          NNENZEI);
              NlNENZEI_HAN :=  NlNENZEI_HAN + NNENZEI;
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
              --子ども
              ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                          NVL(RlKDMKIHONCAL.NENZEI, 0),
                                          MlKDM_ZEI(1), MlKDM_ZEI(2), MlKDM_ZEI(3), MlKDM_ZEI(4),
                                          NNENZEI);
              NlNENZEI_HAN :=  NlNENZEI_HAN + NNENZEI;
-- 2025/08/11 ZCZL.LIUDI ADD END
              NlNENZEI_HAN :=  TRUNC(NlNENZEI_HAN,NlCUT_COL);
              -- 仮徴収額を算出する
              FOR NwIX IN 14..19 LOOP
                -- 納期設定判定
                IF (MlNOUKI(NwIX) > 0)  THEN
                  NlNENZEI_TOKU := NlNENZEI_TOKU + MlKIZEI(NwIX);
                END IF;
              END LOOP;
            END;
          ELSE                            -- 退職
            DECLARE
              NNENZEI NUMBER(12);
            BEGIN
              --医療
              ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                          NVL(RlTAICAL.NENZEI, 0),
                                          MlIRY_TAI_ZEI(1), MlIRY_TAI_ZEI(2), MlIRY_TAI_ZEI(3), MlIRY_TAI_ZEI(4),
                                          NNENZEI);
              NlNENZEI_HAN := NNENZEI;
              --介護
              ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                          NVL(RlKAITAICAL.NENZEI, 0),
                                          MlKAI_TAI_ZEI(1), MlKAI_TAI_ZEI(2), MlKAI_TAI_ZEI(3), MlKAI_TAI_ZEI(4),
                                          NNENZEI);
              NlNENZEI_HAN :=  NlNENZEI_HAN + NNENZEI;
              --支援
              ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                          NVL(RlSIENTAICAL.NENZEI, 0),
                                          MlSIEN_TAI_ZEI(1), MlSIEN_TAI_ZEI(2), MlSIEN_TAI_ZEI(3), MlSIEN_TAI_ZEI(4),
                                          NNENZEI);
              NlNENZEI_HAN :=  NlNENZEI_HAN + NNENZEI;
              NlNENZEI_HAN :=  TRUNC(NlNENZEI_HAN,NlCUT_COL);
              -- 仮徴収額を算出する
              FOR NwIX IN 14..19 LOOP
                -- 納期設定判定
                IF (MlNOUKI(NwIX) > 0)  THEN
                  NlNENZEI_TOKU := NlNENZEI_TOKU + MlTAI_KIZEI(NwIX);
                END IF;
              END LOOP;
            END;
          END IF;
          -- 増減判定用年税額＜仮徴収額合計の場合
          IF NlNENZEI_HAN < NlNENZEI_TOKU THEN
            -- 増減判定用年税額＝仮徴収額合計とする
            NlNENZEI_HAN := NlNENZEI_TOKU;
          END IF;
          NwNENZEI := NlNENZEI_HAN;
        END IF;
        IF NlNENZEI_HAN = 0 THEN
            NwWK_INDEX := 1;
        ELSE
        -- 最終期までで増減判断
        FOR NwIX IN 1..24 LOOP
            IF NlNENZEI_HAN < 0 THEN
                EXIT;
            ELSE
                -- 納期設定判定
                IF (NwIX >= 14  AND  MlNOUKI(NwIX) > 0) OR    -- 特徴期別ＯＲ現在期（-1期）までの、納期月
                   (NwIX <= 13 AND NwIX < i_NwGENZAIKI AND MlNOUKI(NwIX) > 0) THEN
                    NwWK_INDEX   := NwIX; --ループ用INDEXの値を保持
                    IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                        -- 期別金額が有り
                        IF MlKIZEI(NwIX) > 0 THEN
                            NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                            NlNENZEI_HAN := NlNENZEI_HAN - MlKIZEI(NwIX);      -- 増減判定用税額-期別金額
                        END IF;
                    ELSE                            -- 退職
                        IF MlTAI_KIZEI(NwIX) > 0 THEN
                            NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                            NlNENZEI_HAN := NlNENZEI_HAN - MlTAI_KIZEI(NwIX);  -- 増減判定用税額-期別金額
                        END IF;
                    END IF;
                END IF;
            END IF;
        END LOOP;
        END IF;
        -- 保存用年税額 へ (マイナス直前税額)or(現在期－１期)の税額をセット
        -- マイナス直前税額＝0
        IF (NwWK_ZEIGAKU = 0) THEN
          NlNENZEI_SV := NlNENZEI_HAN;  -- 増減判定用税額
        -- 増減判定用税額＞0
        ELSIF (NlNENZEI_HAN > 0) THEN
          NlNENZEI_SV := NlNENZEI_HAN;  -- 増減判定用税額
        -- 増減判定用税額＝0
        ELSIF(NlNENZEI_HAN = 0) THEN
          NlNENZEI_SV := NlNENZEI_HAN ; -- 増減判定用税額
        -- 以外
        ELSE
          NlNENZEI_SV := NwWK_ZEIGAKU;  -- マイナス直前税額
        END IF;
        -- 期別税額セット
        -- 年税判定額 >= 0 AND 年税>0の場合
        IF NlNENZEI_HAN >= 0 AND NwNENZEI > 0 THEN      
            -- 期別税額がプラスの場合
            FOR NwIX IN 1..24 LOOP
                -- 納期設定判定
                IF (NwIX >=14  AND MlNOUKI(NwIX) > 0) OR     -- 特徴期別ＯＲ現在期（-1期）までの、納期月
                   (NwIX <=13 AND NwIX <i_NwGENZAIKI AND MlNOUKI(NwIX) > 0) THEN
                    IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                        MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);          -- 期別更新用変数にセット
                    ELSE                            -- 退職
                        MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);  -- 期別更新用変数にセット
                    END IF;
                     -- 個人番号未セット
                    IF NlLOOP_FLG = 0 THEN
-- 普徴期別且つ現在期には更正後の世帯主をセット。特徴期別は無条件に賦課期別の個人番号をセット。
                        IF (NwIX <= 13 AND NwIX = i_NwGENZAIKI) THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;  -- 計算基本ＴＢＬ主個人番号
                        ELSE
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);      -- 賦課基本ＴＢＬ主個人番号
                        END IF;
                    END IF;
                END IF;
            END LOOP;

        ELSE
            -- 期別税額がマイナスの場合
            -- 賦課期別の10月～3月に普徴期別が存在した場合は、普徴期別(納期到来)→特徴期別の順で金額調整
            BEGIN
                IF i_NwMODE = c_NMODE_ZEN THEN
                    -- 全体
                    SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwSUMZEIGAKU FROM ZLBTKIBETSU_N
                     WHERE KAMOKU_CD       =  c_NKAMOKU_CD
                       AND KAMOKUS_CD      =  c_NKAMOKUS_FUTU
                       AND KOKU_SETAI_NO   =  i_NSETAI
                       AND SANTEIDANTAI_CD =  i_NDANTAI
                       AND CHOTEINENDO     =  i_NNENDO
                       AND NENDOBUN        =  i_NNENDO_BUN
                       AND TSUCHI_NO       =  i_NTSUCHI_NO
                       AND RONRIKIBETSU    >= 7
                       AND RONRIKIBETSU    <= 12;
                      -- セーブ値から特徴金額取得
                      -- 全体
                      NwSUMZEIGAKU_TOKU := 0;
                      FOR NwIX IN 20..24 LOOP
                          NwSUMZEIGAKU_TOKU :=  NwSUMZEIGAKU_TOKU + MlKIZEI(NwIX);
                      END LOOP;
                ELSE
                    -- 退職
                    SELECT NVL(SUM(TAI_ZEIGAKU),0) INTO NwSUMZEIGAKU FROM ZLBTKIBETSU_N
                     WHERE KAMOKU_CD       =  c_NKAMOKU_CD
                       AND KAMOKUS_CD      =  c_NKAMOKUS_FUTU
                       AND KOKU_SETAI_NO   =  i_NSETAI
                       AND SANTEIDANTAI_CD =  i_NDANTAI
                       AND CHOTEINENDO     =  i_NNENDO
                       AND NENDOBUN        =  i_NNENDO_BUN
                       AND TSUCHI_NO       =  i_NTSUCHI_NO
                       AND RONRIKIBETSU    >= 7
                       AND RONRIKIBETSU    <= 12;
                      -- セーブ値から特徴金額取得
                      -- 退職
                      NwSUMZEIGAKU_TOKU := 0;
                      FOR NwIX IN 20..24 LOOP
                          NwSUMZEIGAKU_TOKU :=  NwSUMZEIGAKU_TOKU + MlTAI_KIZEI(NwIX);
                      END LOOP;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NwRTN := c_NERR;
                    VlMSG := '賦課期別税情報取得エラー(国保世帯番号='||i_NSETAI||')'||SQLERRM;
                    RETURN(NwRTN);
            END;
            -- (10月～3月に普徴の期別データ有りOR 10月～3月に特徴の期別データ無し) AND 年税が0円以上(普徴の期別データよりマイナス)
            IF (NwSUMZEIGAKU > 0 OR NwSUMZEIGAKU_TOKU = 0) AND NwWK_INDEX != 1 THEN
                -- 増減判定用年税額再算出
                IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
-- 2025/08/11 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応
                    --NlNENZEI_HAN := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0);
                    NlNENZEI_HAN := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0) + NVL(RlKDMKIHONCAL.NENZEI, 0);
                ELSE                            -- 退職
                    NlNENZEI_HAN := NVL(RlTAICAL.NENZEI, 0) + NVL(RlKAITAICAL.NENZEI, 0) + NVL(RlSIENTAICAL.NENZEI, 0);
                END IF;
                -- 仮算定期割対応
                IF IZAN_MODE = 1 AND i_NJIKKOU_KBN <> c_NONL_KIWARI THEN
                  NlNENZEI_TOKU := 0;
                  IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                    DECLARE
                      NNENZEI NUMBER(12);
                    BEGIN
                      --医療
                      ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                                  NVL(RlKIHONCAL.NENZEI, 0),
                                                  MlIRY_ZEI(1), MlIRY_ZEI(2), MlIRY_ZEI(3), MlIRY_ZEI(4),
                                                  NNENZEI);
                      NlNENZEI_HAN := NNENZEI;
                      --介護
                      ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                                  NVL(RlKAIKIHONCAL.NENZEI, 0),
                                                  MlKAI_ZEI(1), MlKAI_ZEI(2), MlKAI_ZEI(3), MlKAI_ZEI(4),
                                                  NNENZEI);
                      NlNENZEI_HAN :=  NlNENZEI_HAN + NNENZEI;
                      --支援
                      ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                                  NVL(RlSIENKIHONCAL.NENZEI, 0),
                                                  MlSIEN_ZEI(1), MlSIEN_ZEI(2), MlSIEN_ZEI(3), MlSIEN_ZEI(4),
                                                  NNENZEI);
                      NlNENZEI_HAN :=  NlNENZEI_HAN + NNENZEI;
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
                      --子ども
                      ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                                  NVL(RlKDMKIHONCAL.NENZEI, 0),
                                                  MlKDM_ZEI(1), MlKDM_ZEI(2), MlKDM_ZEI(3), MlKDM_ZEI(4),
                                                  NNENZEI);
                      NlNENZEI_HAN :=  NlNENZEI_HAN + NNENZEI;
-- 2025/08/11 ZCZL.LIUDI ADD END
                      NlNENZEI_HAN :=  TRUNC(NlNENZEI_HAN,NlCUT_COL);
                     -- 仮徴収額を算出する
                      FOR NwIX IN 14..19 LOOP
                        -- 納期設定判定
                        IF (MlNOUKI(NwIX) > 0)  THEN
                          NlNENZEI_TOKU := NlNENZEI_TOKU + MlKIZEI(NwIX);
                        END IF;
                      END LOOP;
                    END;
                  ELSE                            -- 退職
                    DECLARE
                      NNENZEI NUMBER(12);
                    BEGIN
                      --医療
                      ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                                  NVL(RlTAICAL.NENZEI, 0),
                                                  MlIRY_TAI_ZEI(1), MlIRY_TAI_ZEI(2), MlIRY_TAI_ZEI(3), MlIRY_TAI_ZEI(4),
                                                  NNENZEI);
                      NlNENZEI_HAN := NNENZEI;
                      --介護
                      ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                                  NVL(RlKAITAICAL.NENZEI, 0),
                                                  MlKAI_TAI_ZEI(1), MlKAI_TAI_ZEI(2), MlKAI_TAI_ZEI(3), MlKAI_TAI_ZEI(4),
                                                  NNENZEI);
                      NlNENZEI_HAN :=  NlNENZEI_HAN + NNENZEI;
                      --支援
                      ZLBPK00010.PRCAL_ZANKINENZEI(i_NwMODE + IZANTEIKIWARI_FLG, RlKIHONCAL.NENDO_BUN, i_NwGENZAIKI,
                                                  NVL(RlSIENTAICAL.NENZEI, 0),
                                                  MlSIEN_TAI_ZEI(1), MlSIEN_TAI_ZEI(2), MlSIEN_TAI_ZEI(3), MlSIEN_TAI_ZEI(4),
                                                  NNENZEI);
                      NlNENZEI_HAN :=  NlNENZEI_HAN + NNENZEI;
                      NlNENZEI_HAN :=  TRUNC(NlNENZEI_HAN,NlCUT_COL);
                      -- 仮徴収額を算出する
                      FOR NwIX IN 14..19 LOOP
                        -- 納期設定判定
                        IF (MlNOUKI(NwIX) > 0)  THEN
                          NlNENZEI_TOKU := NlNENZEI_TOKU + MlTAI_KIZEI(NwIX);
                        END IF;
                      END LOOP;
                    END;
                  END IF;
                  -- 増減判定用年税額＜仮徴収額合計の場合
                  IF NlNENZEI_HAN < NlNENZEI_TOKU THEN
                    -- 増減判定用年税額＝仮徴収額合計とする
                    NlNENZEI_HAN := NlNENZEI_TOKU;
                  END IF;
                END IF;
                -- 特徴期別からまず引く
                FOR NwIX IN 14..24 LOOP
                  IF NlNENZEI_HAN < 0 THEN
                      EXIT;
                  ELSE
                      -- 納期設定判定
                      IF MlNOUKI(NwIX) > 0 THEN
                          NwWK_INDEX   := NwIX; --ループ用INDEXの値を保持
                          IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                              -- 期別金額が有り
                              IF MlKIZEI(NwIX) > 0 THEN
                                 NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                                 NlNENZEI_HAN := NlNENZEI_HAN - MlKIZEI(NwIX);      -- 増減判定用税額-期別金額
                              END IF;
                          ELSE                            -- 退職
                              IF MlTAI_KIZEI(NwIX) > 0 THEN
                                  NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                                  NlNENZEI_HAN := NlNENZEI_HAN - MlTAI_KIZEI(NwIX);  -- 増減判定用税額-期別金額
                              END IF;
                          END IF;
                      END IF;
                  END IF;
                  IF NwIX = 24 THEN
                      -- 特徴期別全てマイナスしても残額有り→普徴期別から引く
                      FOR NwIX2 IN 1..13 LOOP
                        IF NlNENZEI_HAN < 0 THEN
                            EXIT;
                        ELSE
                            -- 納期設定判定
                            IF NwIX2 <i_NwGENZAIKI AND MlNOUKI(NwIX2) > 0 THEN
                                NwWK_INDEX   := NwIX2; --ループ用INDEXの値を保持
                                IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                                    -- 期別金額が有り
                                    IF MlKIZEI(NwIX2) > 0 THEN
                                        NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                                        NlNENZEI_HAN := NlNENZEI_HAN - MlKIZEI(NwIX2);     -- 増減判定用税額-期別金額
                                    END IF;
                                ELSE                            -- 退職
                                    IF MlTAI_KIZEI(NwIX2) > 0 THEN
                                        NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                                        NlNENZEI_HAN := NlNENZEI_HAN - MlTAI_KIZEI(NwIX2); -- 増減判定用税額-期別金額
                                    END IF;
                                END IF;
                            END IF;
                        END IF;
                      END LOOP;
                  END IF;
                END LOOP;
                IF (NwWK_INDEX >= 1 AND  NwWK_INDEX <= 13) THEN
                    -- 特徴期別は変更なしで普徴期別のみで調整
                    FOR NwIX IN 1..NwWK_INDEX LOOP
                        IF i_NwMODE = c_NMODE_ZEN THEN
                            MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);          -- 期別更新用変数にセット
                        ELSE
                            MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);  -- 期別更新用変数にセット
                        END IF;
                        -- 個人番号未セット
                        IF NlLOOP_FLG = 0 THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);     -- 賦課基本ＴＢＬ主個人番号
                        END IF;
                    END LOOP;
                    FOR NwIX IN 14..24 LOOP
                        IF i_NwMODE = c_NMODE_ZEN THEN
                            MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);          -- 期別更新用変数にセット
                        ELSE
                            MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);  -- 期別更新用変数にセット
                        END IF;
                        -- 個人番号未セット
                        IF NlLOOP_FLG = 0 THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);     -- 賦課基本ＴＢＬ主個人番号
                        END IF;
                    END LOOP;
                ELSE
                    -- 普徴期別は全て\0で特徴期別で調整
                    FOR NwIX IN 14..NwWK_INDEX LOOP
                        IF i_NwMODE = c_NMODE_ZEN THEN
                            MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);          -- 期別更新用変数にセット
                        ELSE
                            MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);  -- 期別更新用変数にセット
                        END IF;
                        -- 個人番号未セット
                        IF NlLOOP_FLG = 0 THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);     -- 賦課基本ＴＢＬ主個人番号
                        END IF;
                    END LOOP;
                END IF;
                -- \0(マイナス)になった期に残額をセット
                IF i_NwMODE = c_NMODE_ZEN THEN
                    MlCAL_ZEI(NwWK_INDEX)     := NwWK_ZEIGAKU;
                ELSE
                    MlCAL_TAI_ZEI(NwWK_INDEX) := NwWK_ZEIGAKU;
                END IF;
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwWK_INDEX) := MlNUSI_KOJIN_NO(NwWK_INDEX);
                END IF;
                NwNEXT_KIBETSU := NwWK_INDEX + 1;
                -- 残りの期を\0クリア
                IF (NwWK_INDEX >= 1 AND  NwWK_INDEX <= 13) THEN -- 普徴期別のみ
                    FOR NwIX IN NwNEXT_KIBETSU..13 LOOP
                        IF i_NwMODE = c_NMODE_ZEN THEN   -- 全体
                            MlCAL_ZEI(NwIX) := 0;
                            MlIRY_ZEI(NwIX) := 0;
                            MlKAI_ZEI(NwIX) := 0;
                            MlSIEN_ZEI(NwIX) := 0;
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                            MlKDM_ZEI(NwIX) := 0;
                        ELSE                             -- 退職
                            MlCAL_TAI_ZEI(NwIX) := 0;
                            MlIRY_TAI_ZEI(NwIX) := 0;
                            MlKAI_TAI_ZEI(NwIX) := 0;
                            MlSIEN_TAI_ZEI(NwIX) := 0;
                        END IF;
                        IF NlLOOP_FLG = 0 THEN           -- 主個人番号未セット
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);
                        END IF;
                    END LOOP;
                ELSE -- 特徴+全普徴期別クリア
                    FOR NwIX IN NwNEXT_KIBETSU..24 LOOP -- 特徴期別クリア
                        IF i_NwMODE = c_NMODE_ZEN THEN   -- 全体
                            MlCAL_ZEI(NwIX) := 0;
                            MlIRY_ZEI(NwIX) := 0;
                            MlKAI_ZEI(NwIX) := 0;
                            MlSIEN_ZEI(NwIX) := 0;
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                            MlKDM_ZEI(NwIX) := 0;
                        ELSE                             -- 退職
                            MlCAL_TAI_ZEI(NwIX) := 0;
                            MlIRY_TAI_ZEI(NwIX) := 0;
                            MlKAI_TAI_ZEI(NwIX) := 0;
                            MlSIEN_TAI_ZEI(NwIX) := 0;
                        END IF;
                        IF NlLOOP_FLG = 0 THEN           -- 主個人番号未セット
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);
                        END IF;
                    END LOOP;
                    FOR NwIX IN 1..13 LOOP -- 普徴期別全クリア
                        IF i_NwMODE = c_NMODE_ZEN THEN   -- 全体
                            MlCAL_ZEI(NwIX) := 0;
                            MlIRY_ZEI(NwIX) := 0;
                            MlKAI_ZEI(NwIX) := 0;
                            MlSIEN_ZEI(NwIX) := 0;
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                            MlKDM_ZEI(NwIX) := 0;
                        ELSE                             -- 退職
                            MlCAL_TAI_ZEI(NwIX) := 0;
                            MlIRY_TAI_ZEI(NwIX) := 0;
                            MlKAI_TAI_ZEI(NwIX) := 0;
                            MlSIEN_TAI_ZEI(NwIX) := 0;
                        END IF;
                        IF NlLOOP_FLG = 0 THEN           -- 主個人番号未セット
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);
                        END IF;
                    END LOOP;
                END IF;
                NlNENZEI_SV  := 0;
                NlNENZEI_HAN := 0;
            ELSE
                FOR NwIX IN 1..NwWK_INDEX - 1 LOOP -- マイナス直前期までループ
                    IF (NwIX >=14  AND MlNOUKI(NwIX) > 0) OR     -- 特徴期別ＯＲ現在期（-1期）までの、納期月
                       (NwIX <=13 AND NwIX <i_NwGENZAIKI AND MlNOUKI(NwIX) > 0) THEN
                        IF i_NwMODE = c_NMODE_ZEN THEN
                            MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);          -- 期別更新用変数にセット
                        ELSE
                            MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);  -- 期別更新用変数にセット
                        END IF;
                        -- 個人番号未セット
                        IF NlLOOP_FLG = 0 THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);     -- 賦課基本ＴＢＬ主個人番号
                        END IF;
                    END IF;
                END LOOP;
                -- \0になった期に残額をセット
                IF i_NwMODE = c_NMODE_ZEN THEN
                    MlCAL_ZEI(NwWK_INDEX)     := NwWK_ZEIGAKU;
                ELSE
                    MlCAL_TAI_ZEI(NwWK_INDEX) := NwWK_ZEIGAKU;
                END IF;
                IF NlLOOP_FLG = 0 THEN
                    -- 現在期別前なら今までの主個人番号をセットする。
                    MlCAL_NUSI_KOJIN_NO(NwWK_INDEX) := MlNUSI_KOJIN_NO(NwWK_INDEX);
                END IF;
                NwNEXT_KIBETSU := NwWK_INDEX + 1;
                -- 残りの期をクリア
                FOR NwIX IN NwNEXT_KIBETSU..24 LOOP
                    IF i_NwMODE = c_NMODE_ZEN THEN   -- 全体
                        MlCAL_ZEI(NwIX) := 0;
                        MlIRY_ZEI(NwIX) := 0;
                        MlKAI_ZEI(NwIX) := 0;
                        MlSIEN_ZEI(NwIX) := 0;
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                        MlKDM_ZEI(NwIX) := 0;
                    ELSE                             -- 退職
                        MlCAL_TAI_ZEI(NwIX) := 0;
                        MlIRY_TAI_ZEI(NwIX) := 0;
                        MlKAI_TAI_ZEI(NwIX) := 0;
                        MlSIEN_TAI_ZEI(NwIX) := 0;
                    END IF;
                    IF NlLOOP_FLG = 0 THEN           -- 主個人番号未セット
                        MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);
                    END IF;
                END LOOP;
            END IF;
        END IF;
        IF NlNENZEI_HAN <= 0 THEN
            NwRTN := 1;
        END IF;
        RETURN(NwRTN);
    END funcKiwari20;
-------------------------------------------------------------------------------
-- 期割処理30
-------------------------------------------------------------------------------
    PROCEDURE subKiwari30(i_NwMODE     IN NUMBER,
                          i_NwGENZAIKI IN NUMBER) IS
        NwIX                NUMBER(2);
        NwZANKI_CNT         NUMBER(2);      -- 残期数
        NwMAXKI             NUMBER(2);      -- 最大期別
        NwKIZEI_AFT         NUMBER;         -- 処理後期別税額
        NwFLG               NUMBER(1);
        NwLASTKI            NUMBER(2);      -- 最終期別
        NwHASU              NUMBER;         -- 端数
        NwCHOSEIKI          NUMBER(2);      -- 調整期
    BEGIN
        NwZANKI_CNT  := 0;      -- 残期数
        NlNENZEI_HAN := 0;      -- 増減判定用年税額
        -- 納期の最大期別を取得
        NwMAXKI := funcMaxKibetsuGet(i_NwGENZAIKI);   -- 最大期別取得
	IF SUBSTR(RICTLPRM,1,1) = '1' THEN
		NwMAXKI := 13;
        END IF;
        -- 残期数計算(普通納期以外は1)
        FOR NwIX IN i_NwGENZAIKI..NwMAXKI LOOP
            IF IZAN_MODE = 0 AND MlNOUKI(NwIX) IN (1, 2, 3) OR
               IZAN_MODE = 1 AND MlNOUKI(NwIX) = 1 THEN     -- 納期区分
                NwZANKI_CNT := NwZANKI_CNT + 1;
            END IF;
        END LOOP;
        IF NwZANKI_CNT = 0 THEN
            NwZANKI_CNT := 1;
        END IF;
        -- 端数処理後期別税額セット
        NwFLG       := 0;

        IF IZAN_MODE = 1 THEN
          NwKIZEI_AFT := TRUNC((NlNENZEI_SV / NwZANKI_CNT), NlCUT_COL_KIBETSU); -- 期別税額の端数カット
        ELSE
          NwKIZEI_AFT := TRUNC((NlNENZEI_SV / NwZANKI_CNT), NlCUT_COL); -- 残税額を残期数で割る(1期分の金額算出)
        END IF;
        -- 現在期別から最大期別まで期別税額セット
        FOR NwIX IN i_NwGENZAIKI..13 LOOP
            IF (IZAN_MODE = 0 AND (NwIx <= NwMAXKI OR SUBSTR(RICTLPRM,1,1) = '1') AND
                MlNOUKI(NwIX) IN (1,2,3)) OR
               (IZAN_MODE = 1 AND MlNOUKI(NwIX) = 1) THEN
               IF INOKI = 0 OR INOKI >= NwIX THEN  
                -- 納期区分
                IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                    MlCAL_ZEI(NwIX)     := NwKIZEI_AFT;
                ELSE                                    -- 退職
                    MlCAL_TAI_ZEI(NwIX) := NwKIZEI_AFT;
                END IF;
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;

                -- 最初のループ時に調整期をセット
                IF NwFLG = 0 THEN
                    NwCHOSEIKI := NwIX;
                END IF;
                NwFLG := 1;
               END IF;  
            ELSIF MlNOUKI(NwIX) = 4 THEN           -- 納期区分
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;
            END IF;
        END LOOP;
        -- 最終期別セット 納期区分が1,2,3以外の場合のみ
        IF NwFLG = 0 THEN
            -- 最終期を求める
            NwLASTKI := i_NwGENZAIKI;
            IF NwLASTKI = i_NwGENZAIKI THEN
                -- 随時期で現在の期別税額が変更される場合
                IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                    MlCAL_ZEI(NwLASTKI)     := NwKIZEI_AFT;
                ELSE                                    -- 退職
                    MlCAL_TAI_ZEI(NwLASTKI) := NwKIZEI_AFT;
                END IF;
            ELSE
                -- 納期がない期は求めた最終期に算出した税額を足しこむ
                IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                    MlCAL_ZEI(NwLASTKI)     := MlCAL_ZEI(NwLASTKI)     + NwKIZEI_AFT;
                ELSE                                    -- 退職
                    MlCAL_TAI_ZEI(NwLASTKI) := MlCAL_TAI_ZEI(NwLASTKI) + NwKIZEI_AFT;
                END IF;
            END IF;
            -- 調整期をセット
            NwCHOSEIKI := NwLASTKI;
            IF NlLOOP_FLG = 0 THEN -- 主個人番号未セット
                MlCAL_NUSI_KOJIN_NO(NwLASTKI) := RlKIHONCAL.NUSHI_KOJIN_NO;
            END IF;
        END IF;
        -- 端数算出
        NwHASU     := (NlNENZEI_SV - (NwKIZEI_AFT * NwZANKI_CNT));
        -- 最終セット(端数の足し込み)
        IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
            MlCAL_ZEI(NwCHOSEIKI) := MlCAL_ZEI(NwCHOSEIKI) + NwHASU;
              IF RlKIHONCAL.GENZON_KBN = 1 AND SUBSTR(RICTLPRM,1,1) = '0' THEN
                MlCAL_ZEI(NwCHOSEIKI)           := NlNENZEI_SV;
                MlCAL_NUSI_KOJIN_NO(NwCHOSEIKI) := RlKIHONCAL.NUSHI_KOJIN_NO;
                NwCHOSEIKI := NwCHOSEIKI + 1;
                FOR NwIX IN NwCHOSEIKI..13 LOOP
                    MlCAL_ZEI(NwIX) := 0;
                END LOOP;
            END IF;
        ELSE                                    -- 退職
            MlCAL_TAI_ZEI(NwCHOSEIKI) := MlCAL_TAI_ZEI(NwCHOSEIKI) + NwHASU;
            IF RlKIHONCAL.SETAI_KBN = 0 THEN        -- 世帯区分
                MlCAL_TAI_ZEI(NwCHOSEIKI) := NlNENZEI_SV;
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwCHOSEIKI) := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;
                NwCHOSEIKI := NwCHOSEIKI + 1;
                FOR NwIX IN NwCHOSEIKI..13 LOOP
                    MlCAL_TAI_ZEI(NwIX) := 0;
                    IF MlCAL_TAI_ZEI(NwIX) > MlCAL_ZEI(NwIX) THEN
                        NlNENZEI_HAN        := MlCAL_TAI_ZEI(NwIX) - MlCAL_ZEI(NwIX);
                        MlCAL_TAI_ZEI(NwIX) := MlCAL_ZEI(NwIX);
                        IF NwIX < 13 THEN
                            NwCHOSEIKI := NwIX + 1;
                            MlCAL_TAI_ZEI(NwCHOSEIKI) := MlCAL_TAI_ZEI(NwCHOSEIKI) + NlNENZEI_HAN;
                        END IF;
                    END IF;
                END LOOP;
                MlCAL_TAI_ZEI(13) := NlNENZEI_HAN;
            END IF;
        END IF;
    END subKiwari30;
-------------------------------------------------------------------------------
-- 期割処理40(過年度用)
-------------------------------------------------------------------------------
    PROCEDURE subKiwari40(i_NwMODE     IN NUMBER,
                          i_NwGENZAIKI IN NUMBER) IS
        -- 収納条件取得
        CURSOR CwSHUNOJKNK IS
            SELECT * FROM ZLBTSHUNOJKNK
             WHERE KAMOKU_CD       =  c_NKAMOKU_CD
               AND KAMOKUS_CD      =  c_NKAMOKUS_FUTU
               AND KIWARIDANTAI_CD =  NlKIWARIDANTAI_CD
               AND DANTAING_KBN    =  0
               AND CHOTEINENDO     =  i_NNENDO
               AND GENNENKANEN_KBN =  c_NKANEN
               AND HYOJIYOKIBETSU  >  0
               AND RONRIKIBETSU    >= i_NwGENZAIKI
             ORDER BY RONRIKIBETSU;
    BEGIN
        -- 現在期以降の最初の納期月に税額をセットする
        FOR RwSHUNOJKNK IN CwSHUNOJKNK LOOP
            IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                MlCAL_ZEI(RwSHUNOJKNK.RONRIKIBETSU)     := NlNENZEI_SV;
            ELSE                                    -- 退職
                MlCAL_TAI_ZEI(RwSHUNOJKNK.RONRIKIBETSU) := NlNENZEI_SV;
            END IF;
            EXIT;
        END LOOP;
        NlZO_FLG := 1;
    END subKiwari40;
-------------------------------------------------------------------------------
-- 09 期割処理30NARASI
-------------------------------------------------------------------------------
    PROCEDURE subKiwari30NARASI(i_NwMODE     IN NUMBER,
                          i_NwGENZAIKI IN NUMBER) IS
        NwIX                NUMBER(2);
        NwZANKI_CNT         NUMBER(2);      -- 残期数
        NwMAXKI             NUMBER(2);      -- 最大期別
        NwKIZEI_AFT         NUMBER;         -- 処理後期別税額
        NwFLG               NUMBER(1);
        NwLASTKI            NUMBER(2);      -- 最終期別
        NwHASU              NUMBER;         -- 端数
        NwCHOSEIKI          NUMBER(2);      -- 調整期
        NwKIZEI_HANTEI      NUMBER;         -- 未到来期数変更判定
        NwIX_MI_CNT         NUMBER(2);      -- 未到来期数カウント
        WiNlCUT_COL         NUMBER;
        WKLOOPCNT           NUMBER;
    BEGIN
        NwZANKI_CNT  := 0;      -- 残期数
        NlNENZEI_HAN := 0;      -- 増減判定用年税額
        -- 納期の最大期別を取得
        NwMAXKI := funcMaxKibetsuGet(i_NwGENZAIKI);   -- 12 最大期別取得 
        -- 残期数計算(普通納期以外は1)
--特徴開始の場合は、特徴開始期前までで普徴期割するのでNwMAXKIまでLoop。
        FOR NwIX IN i_NwGENZAIKI..NwMAXKI LOOP
            IF MlNOUKI(NwIX) IN (1, 2, 3) THEN     -- 納期区分
                NwZANKI_CNT := NwZANKI_CNT + 1;
            END IF;
        END LOOP;
        IF NwZANKI_CNT = 0 THEN
            NwZANKI_CNT := 1;
        END IF;
        IF MIKIJYUN_TEKIYOU = 2 THEN
           IF NlNENZEI_SV <= MIKIJYUN_KIWARIGK THEN
--ここは、最初に見つけた期に全額セットなのでこのままでOK
              FOR NwIX IN i_NwGENZAIKI..13 LOOP
                  IF MlNOUKI(NwIX) IN (1, 2, 3 , 4) THEN     -- 納期区分
                      IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                          MlCAL_ZEI(NwIX)     := NlNENZEI_SV;
                      ELSE                                    -- 退職
                          MlCAL_TAI_ZEI(NwIX) := NlNENZEI_SV;
                      END IF;
                      EXIT;
                  END IF;
              END LOOP;
              GOTO KIJYUN_KIWARIGK_HANTEI;
           END IF;
        ELSIF MIKIJYUN_TEKIYOU = 1 THEN
--         本算定の時のみセットする。
           IF BlSHORI_HANI_FLG = TRUE AND i_NJIKKOU_KBN = 0 THEN
             IF NlNENZEI_SV <= MIKIJYUN_KIWARIGK THEN
--ここは、最初に見つけた期に全額セットなのでこのままでOK
              FOR NwIX IN i_NwGENZAIKI..13 LOOP
                  IF MlNOUKI(NwIX) IN (1, 2, 3 , 4) THEN     -- 納期区分
                      IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                          MlCAL_ZEI(NwIX)     := NlNENZEI_SV;
                      ELSE                                    -- 退職
                          MlCAL_TAI_ZEI(NwIX) := NlNENZEI_SV;
                      END IF;
                      EXIT;
                  END IF;
              END LOOP;
              GOTO KIJYUN_KIWARIGK_HANTEI;
             END IF;
           END IF;
        END IF;
--      税額セット方法判定
        NwKIZEI_HANTEI := NlNENZEI_SV / NwZANKI_CNT;
--特徴開始の場合は、特徴開始期前までで普徴期割するのでNwMAXKIまでLoop。
        FOR NwIX IN 1..NwMAXKI LOOP
            IF NlCUT_COL = c_NHASU_2 THEN
               WiNlCUT_COL := 100;
            ELSIF NlCUT_COL = c_NHASU_1 THEN
               WiNlCUT_COL := 1000;
            ELSIF NlCUT_COL = c_NHASU_3 THEN
               WiNlCUT_COL := 0;
            ELSIF NlCUT_COL = c_NHASU_10 THEN
               WiNlCUT_COL := 10;
            ELSE
               WiNlCUT_COL := 0;
            END IF;
            IF NwKIZEI_HANTEI >= WiNlCUT_COL THEN
               EXIT;
            END IF;
            NwZANKI_CNT := NwZANKI_CNT - 1;
            IF NwZANKI_CNT = 0 THEN
               NwZANKI_CNT := 1;
               EXIT;
            END IF;
            NwKIZEI_HANTEI := NlNENZEI_SV / NwZANKI_CNT;
        END LOOP;
        -- 端数処理後期別税額セット
        NwFLG       := 0;
        NwKIZEI_AFT := TRUNC((NlNENZEI_SV / NwZANKI_CNT), NlCUT_COL);
        WKLOOPCNT := 0;
--特徴開始の場合は、特徴開始期前までで普徴期割するのでNwMAXKIまでLoop。
        FOR NwIX IN i_NwGENZAIKI..NwMAXKI LOOP
            IF MlNOUKI(NwIX) IN (1, 2, 3) THEN     -- 納期区分
                WKLOOPCNT := WKLOOPCNT + 1;
                IF NwZANKI_CNT < WKLOOPCNT THEN
                   EXIT;
                END IF;
                IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                    MlCAL_ZEI(NwIX)     := NwKIZEI_AFT;
                ELSE                                    -- 退職
                    MlCAL_TAI_ZEI(NwIX) := NwKIZEI_AFT;
                END IF;
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;
                NwFLG := 1;
            ELSIF MlNOUKI(NwIX) = 4 THEN           -- 納期区分
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;
            END IF;
        END LOOP;
        -- 最終期別セット 納期区分が1,2,3以外の場合のみ
        IF NwFLG = 0 THEN
            -- 最終期を求める
            NwLASTKI := i_NwGENZAIKI;
            FOR NwIX IN i_NwGENZAIKI..13 LOOP
                IF MlNOUKI(NwIX) = 4 THEN      -- 納期区分
                    EXIT;
                ELSE
                    NwLASTKI := NwLASTKI + 1;
                    IF NwIX = 13 THEN
                        NwLASTKI := NwMAXKI;
                    END IF;
                END IF;
            END LOOP;
            IF NwLASTKI = i_NwGENZAIKI THEN
                -- 随時期で現在の期別税額が変更される場合
                IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                    MlCAL_ZEI(NwLASTKI)     := NwKIZEI_AFT;
                ELSE                                    -- 退職
                    MlCAL_TAI_ZEI(NwLASTKI) := NwKIZEI_AFT;
                END IF;
            ELSE
                -- 納期がない期は求めた最終期に算出した税額を足しこむ
                IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                    MlCAL_ZEI(NwLASTKI)     := MlCAL_ZEI(NwLASTKI)     + NwKIZEI_AFT;
                ELSE                                    -- 退職
                    MlCAL_TAI_ZEI(NwLASTKI) := MlCAL_TAI_ZEI(NwLASTKI) + NwKIZEI_AFT;
                END IF;
            END IF;
            IF NlLOOP_FLG = 0 THEN
                MlCAL_NUSI_KOJIN_NO(NwLASTKI) := RlKIHONCAL.NUSHI_KOJIN_NO;
            END IF;
        END IF;
        -- 調整期計算
        NwHASU     := (NlNENZEI_SV - (NwKIZEI_AFT * NwZANKI_CNT));  -- 端数算出
        NwCHOSEIKI := i_NwGENZAIKI;
        FOR NwIX IN i_NwGENZAIKI..13 LOOP
            IF MlNOUKI(NwIX) > 0 THEN      -- 納期区分
                EXIT;
            ELSE
                NwCHOSEIKI := NwCHOSEIKI + 1;
                IF NwCHOSEIKI = 13 THEN
                    NwCHOSEIKI := NwMAXKI;
                END IF;
            END IF;
        END LOOP;
--特徴開始の場合は、特徴開始期前までで普徴期割するのでNwMAXKIまでLoop。
        FOR NwIX IN i_NwGENZAIKI..NwMAXKI LOOP
          IF NwHASU >= WiNlCUT_COL THEN
           IF MlNOUKI(NwIX) > 0 THEN      -- 納期区分
               IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                  MlCAL_ZEI(NwIX)     := MlCAL_ZEI(NwIX)     + WiNlCUT_COL;
               ELSE                                    -- 退職
                  MlCAL_TAI_ZEI(NwIX) := MlCAL_TAI_ZEI(NwIX) + WiNlCUT_COL;
               END IF;
               NwHASU := NwHASU - WiNlCUT_COL;
           END IF;
          END IF;
        END LOOP;
        -- 最終セット(端数の足し込み)
        IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
            MlCAL_ZEI(NwCHOSEIKI) := MlCAL_ZEI(NwCHOSEIKI) + NwHASU;
            IF RlKIHONCAL.GENZON_KBN = 1 THEN       -- 現存区分
                MlCAL_ZEI(NwCHOSEIKI)           := NlNENZEI_SV;
                MlCAL_NUSI_KOJIN_NO(NwCHOSEIKI) := RlKIHONCAL.NUSHI_KOJIN_NO;
                NwCHOSEIKI := NwCHOSEIKI + 1;
                FOR NwIX IN NwCHOSEIKI..13 LOOP
                    MlCAL_ZEI(NwIX) := 0;
                END LOOP;
            END IF;
        ELSE                                    -- 退職
            MlCAL_TAI_ZEI(NwCHOSEIKI) := MlCAL_TAI_ZEI(NwCHOSEIKI) + NwHASU;
            IF RlKIHONCAL.SETAI_KBN = 0 THEN        -- 世帯区分
                MlCAL_TAI_ZEI(NwCHOSEIKI) := NlNENZEI_SV;
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwCHOSEIKI) := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;
                NwCHOSEIKI := NwCHOSEIKI + 1;
                FOR NwIX IN NwCHOSEIKI..13 LOOP
                    MlCAL_TAI_ZEI(NwIX) := 0;
                    IF MlCAL_TAI_ZEI(NwIX) > MlCAL_ZEI(NwIX) THEN
                        NlNENZEI_HAN        := MlCAL_TAI_ZEI(NwIX) - MlCAL_ZEI(NwIX);
                        MlCAL_TAI_ZEI(NwIX) := MlCAL_ZEI(NwIX);
                        IF NwIX < 13 THEN
                            NwCHOSEIKI := NwIX + 1;
                            MlCAL_TAI_ZEI(NwCHOSEIKI) := MlCAL_TAI_ZEI(NwCHOSEIKI) + NlNENZEI_HAN;
                        END IF;
                    END IF;
                END LOOP;
                MlCAL_TAI_ZEI(13) := NlNENZEI_HAN;
            END IF;
        END IF;
      <<KIJYUN_KIWARIGK_HANTEI>>
      NULL;
    END subKiwari30NARASI;
------------------------------------------------------------------------------
--  02 対象年月のマスタ更新実施確認                                         --
------------------------------------------------------------------------------
FUNCTION FNC_SHORI_HANI RETURN NUMBER IS
    IwRTN        PLS_INTEGER;      -- 戻り値
    IwCOUNT      PLS_INTEGER;      -- SELECT検索カウント
  BEGIN
    IwRTN  := 0;
    BlSHORI_HANI_FLG := FALSE;
    BEGIN
      -- 処理範囲TBLより件数取得
      SELECT  COUNT(*) COUNT INTO IwCOUNT
      FROM    ZLBTSHORI_HANI
      WHERE   CHOTEI_NENDO         =  i_NNENDO           AND
              NENDO_BUN            =  i_NNENDO_BUN       AND
              SHIME_NENGETSU       =  NlSHIME_NENGETSU   AND
              MASTER_KOSHIN_KBN    =  2;
      -- 複数件存在しなければ本算定処理 → 処理中
      IF   IwCOUNT  =  0 THEN
        BlSHORI_HANI_FLG := TRUE;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        IwRTN          := 9;
    END;
    RETURN( IwRTN );
END FNC_SHORI_HANI ;
-------------------------------------------------------------------------------
-- 特徴セーブ情報更新用セット
-------------------------------------------------------------------------------
    PROCEDURE subTokuSaveToCal(i_NwMODE IN NUMBER) IS
    BEGIN
       FOR NwIX IN 14..24 LOOP
         -- 納期設定判定
         IF (MlNOUKI(NwIX) > 0)  THEN
           IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);
            ELSE                            -- 退職
                MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);
            END IF;
         END IF;
       END LOOP;
    END subTokuSaveToCal;
-------------------------------------------------------------------------------
-- 期割処理メイン
-------------------------------------------------------------------------------
    PROCEDURE subKiwariMain(i_NwMODE IN NUMBER) IS
        NwRTN           NUMBER(1);
        NwGENZAIKI      NUMBER(2);
    BEGIN
        NwRTN      := 1;
        NwGENZAIKI := 0;
        IF funcGenzaiKibetsu(i_NwMODE, NwGENZAIKI) = 0 THEN      -- 現在期別判定
            -- １期～現在期までの処理
            NwRTN := funcKiwari20(i_NwMODE, NwGENZAIKI);         -- 期割処理20
        ELSE
            -- セーブしている特徴期別データをCAL更新用にセット
            subTokuSaveToCal(i_NwMODE);
            NwRTN := 0;
        END IF;
        IF NwRTN = 0 THEN
            IF i_NGENKA_KBN = c_NGENNEN THEN         -- 現年
                IF MIKIWARIHOUHOU = 0 THEN
                   -- 現在期～最終期までの処理
                   subKiwari30(i_NwMODE, NwGENZAIKI);   -- 09 期割処理30
                ELSE
                   subKiwari30NARASI(i_NwMODE, NwGENZAIKI);   -- 09 期割処理30
                END IF;
            ELSE                                     -- 過年
                -- 現在期～最終期までの処理(過年)
                subKiwari40(i_NwMODE, NwGENZAIKI);   -- 期割処理40
            END IF;
        END IF;
    END subKiwariMain;
-------------------------------------------------------------------------------
-- 計算期別セット
-------------------------------------------------------------------------------
    PROCEDURE subCalKibetsuSet(i_NwMODE IN NUMBER) IS
        NwRTN               NUMBER(1);
        NwIX                NUMBER(2);
        NwKIZEI             NUMBER;         -- 期別税額
        NwNUSHI_KOJIN_NO    NUMBER;         -- 主個人番号
        NwGENZAIKI          NUMBER(2);      -- 現在期別
    BEGIN
        FOR NwIX IN 1..24 LOOP
            NwKIZEI          := 0;      -- 期別税額
            NwNUSHI_KOJIN_NO := 0;      -- 主個人番号
            IF MlKIBETSU(NwIX) > 0 THEN
                IF i_NwMODE = c_NMODE_ZEN THEN     -- 全体
                    NwKIZEI := MlKIZEI(NwIX);
                    IF MlNUSI_KOJIN_NO(NwIX) = 0 THEN
                        NwNUSHI_KOJIN_NO := RlKIHONCAL.NUSHI_KOJIN_NO;
                    ELSE
                        NwNUSHI_KOJIN_NO := MlNUSI_KOJIN_NO(NwIX);
                    END IF;
                END IF;
            END IF;
            MlCAL_CHOTEI_NENDO(NwIX)  := i_NNENDO;          -- 計算調定年度
            MlCAL_TSUCHI_NO(NwIX)     := i_NTSUCHI_NO;      -- 計算通知書番号
            MlCAL_NUSI_KOJIN_NO(NwIX) := NwNUSHI_KOJIN_NO;  -- 計算主個人番号
            MlCAL_ZEI(NwIX)           := NwKIZEI;           -- 計算全体税額
            MlCAL_TAI_ZEI(NwIX)       := MlTAI_KIZEI(NwIX); -- 計算退職税額
            MlCAL_KAMOKUS(NwIX)       := MlKAMOKUS(NwIX);   -- 科目詳細コード
            IF NwIX < 14 THEN   --普徴
                MlCAL_KIBETSU(NwIX)     := NwIX;             -- 計算期別
            ELSE                --特徴
                MlCAL_KIBETSU(NwIX)     := NwIX - 13;        -- 計算期別
            END IF;
        END LOOP;
        NwRTN := funcGenzaiKibetsu(0, NwGENZAIKI);      -- 現在期別判定
        FOR NwIX IN NwGENZAIKI..24 LOOP
-- 普徴期別には更正後の世帯主をセット。特徴期別は無条件に賦課期別の個人番号をセット。
            IF NwIX < 14 THEN   --普徴
                MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO; -- 計算主個人番号
            ELSE                --特徴
                MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);     -- 賦課基本ＴＢＬ主個人番号
            END IF;
        END LOOP;
    END subCalKibetsuSet;
-------------------------------------------------------------------------------
-- 計算期別更新
-------------------------------------------------------------------------------
    PROCEDURE subInsert IS
        NwIX            NUMBER(2);
        NwSYSDATE       NUMBER(8);
        -- 収納条件取得
        CURSOR CwSHUNOJKNK IS
            SELECT * FROM ZLBTSHUNOJKNK
             WHERE KAMOKU_CD       =  c_NKAMOKU_CD
               AND KIWARIDANTAI_CD =  NlKIWARIDANTAI_CD
               AND DANTAING_KBN    =  0
               AND CHOTEINENDO     =  i_NNENDO
               AND GENNENKANEN_KBN =  c_NKANEN
               AND HYOJIYOKIBETSU  >  0
             ORDER BY KAMOKUS_CD, RONRIKIBETSU;
    BEGIN
        -- システム日付取得
        NwSYSDATE := KKBPK5551.FBATCHDATEGET;
        RlKIBETSUCAL.KAMOKU_CD       := c_NKAMOKU_CD;               -- 科目コード(固定)
        RlKIBETSUCAL.KOKU_SETAI_NO   := RlKIHONCAL.KOKU_SETAI_NO;   -- 国保世帯番号(固定)
        RlKIBETSUCAL.SANTEIDANTAI_CD := i_NDANTAI;                  -- 算定団体コード(固定)
        RlKIBETSUCAL.KIWARIDANTAI_CD := NlKIWARIDANTAI_CD;          -- 期割団体コード
        RlKIBETSUCAL.DANTAING_KBN    := 0;                          -- 団体内外区分(固定)
        IF i_NNENDO = i_NNENDO_BUN THEN     -- 課税年度と年度分が同じ場合は0
            RlKIBETSUCAL.GENNENKANEN_KBN := 0;                      -- 現年過年区分(現年)
        ELSE
            RlKIBETSUCAL.GENNENKANEN_KBN := 1;                      -- 現年過年区分(過年)
        END IF;
        RlKIBETSUCAL.CHOTEINENDO     := 0;                          -- 調定年度
        RlKIBETSUCAL.NENDOBUN        := i_NNENDO_BUN;               -- 年度分(固定)
        RlKIBETSUCAL.TSUCHI_NO       := 0;                          -- 通知書番号
        RlKIBETSUCAL.RONRIKIBETSU    := 0;                          -- 論理期別
        RlKIBETSUCAL.R_NO            := RlKIHONCAL.R_NO;            -- 履歴番号(固定)
        RlKIBETSUCAL.NENGETSU        := 0;                          -- 年月
        RlKIBETSUCAL.NUSHI_KOJIN_NO  := 0;                          -- 納税義務者個人番号
        IF NVL(i_NKOSEIBI, 0) > 0 THEN
          RlKIBETSUCAL.KOSEI_BI      := i_NKOSEIBI;                 -- 更正日(引数)
        ELSE
          RlKIBETSUCAL.KOSEI_BI      := NwSYSDATE;                  -- 更正日(システム日付)
        END IF;
        RlKIBETSUCAL.ZEN_ZEIGAKU         := 0;              -- 全体税額
        RlKIBETSUCAL.TAI_ZEIGAKU         := 0;              -- 退職税額
        RlKIBETSUCAL.IR_ZEN_ZEIGAKU      := 0;              -- 医療全体税額
        RlKIBETSUCAL.IR_TAI_ZEIGAKU      := 0;              -- 医療退職税額
        RlKIBETSUCAL.KAI_ZEN_ZEIGAKU     := 0;              -- 介護全体税額
        RlKIBETSUCAL.KAI_TAI_ZEIGAKU     := 0;              -- 介護退職税額
        RlKIBETSUCAL.IR_ZEN_FNKSNGAKU    := 0;              -- 不能欠損額(医療全体)(固定)
        RlKIBETSUCAL.IR_TAI_FNKSNGAKU    := 0;              -- 不能欠損額(医療退職)(固定)
        RlKIBETSUCAL.KAI_ZEN_FNKSNGAKU   := 0;              -- 不能欠損額(介護全体)(固定)
        RlKIBETSUCAL.KAI_TAI_FNKSNGAKU   := 0;              -- 不能欠損額(介護退職)(固定)
        RlKIBETSUCAL.SYS_SAKUSEIBI       := 0;
        RlKIBETSUCAL.SYS_KOSHINBI        := 0;
        RlKIBETSUCAL.SYS_JIKAN           := 0;
        RlKIBETSUCAL.SYS_SHOKUINKOJIN_NO := '0';
        RlKIBETSUCAL.SYS_TANMATSU_NO     := i_VTANMATSU;
        RlKIBETSUCAL.SIEN_ZEN_ZEIGAKU    := 0;              -- 支援全体税額
        RlKIBETSUCAL.SIEN_TAI_ZEIGAKU    := 0;              -- 支援退職税額
        RlKIBETSUCAL.SIEN_ZEN_FNKSNGAKU  := 0;              -- 不能欠損額(支援全体)(固定)
        RlKIBETSUCAL.SIEN_TAI_FNKSNGAKU  := 0;              -- 不能欠損額(支援退職)(固定)
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
        RlKIBETSUCAL.KDM_ZEN_ZEIGAKU     := 0;              -- 子ども全体税額
        RlKIBETSUCAL.KDM_ZEN_FNKSNGAKU   := 0;              -- 不能欠損額（子ども全体）
-- 2025/08/11 ZCZL.LIUDI ADD END
        -- 現年時 または 過年度時かつ差額減額時はシステム条件の納期区分で出力判定
        IF i_NGENKA_KBN = c_NGENNEN OR
           (i_NGENKA_KBN = c_NKANEN  AND NlZO_FLG = 0) THEN
            -- 期別計算TBLの項目セット
            FOR NwIX IN 1..24 LOOP
                IF MlNOUKI(NwIX) > 0 THEN
                    RlKIBETSUCAL.CHOTEINENDO    := MlCAL_CHOTEI_NENDO(NwIX);    -- 調定年度
                    RlKIBETSUCAL.TSUCHI_NO      := MlCAL_TSUCHI_NO(NwIX);       -- 通知書番号
                    RlKIBETSUCAL.RONRIKIBETSU   := MlCAL_KIBETSU(NwIX);         -- 論理期別
                    RlKIBETSUCAL.KAMOKUS_CD     := MlCAL_KAMOKUS(NwIX);         -- 科目詳細コード(固定)
                    IF MlKAMOKUS(NwIX) = c_NKAMOKUS_FUTU THEN  -- 普通徴収
                        IF NwIX < 10 THEN                                           -- 年月
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + (NwIX + 3);
                        ELSIF NwIX <= 13 THEN
                            RlKIBETSUCAL.NENGETSU   := (MlCAL_CHOTEI_NENDO(NwIX) + 1) * 100 + (NwIX - 9);
                        END IF;
                    ELSE     -- 普徴以外(特徴)
                        CASE NwIX
                            WHEN 14 THEN
                                RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 4;
                            WHEN 16 THEN
                                RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 6;
                            WHEN 18 THEN
                                RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 8;
                            WHEN 20 THEN
                                RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 10;
                            WHEN 22 THEN
                                RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 12;
                            WHEN 24 THEN
                                RlKIBETSUCAL.NENGETSU   := (MlCAL_CHOTEI_NENDO(NwIX) + 1) * 100 + 2;
                        END CASE;
                    END IF;
                       -- 納税義務者個人番号
                    IF MlCAL_NUSI_KOJIN_NO(NwIX) != 0 THEN
                        RlKIBETSUCAL.NUSHI_KOJIN_NO := MlCAL_NUSI_KOJIN_NO(NwIX);
                    ELSE
                        RlKIBETSUCAL.NUSHI_KOJIN_NO := RlKIHONCAL.NUSHI_KOJIN_NO;
                    END IF;
                    RlKIBETSUCAL.ZEN_ZEIGAKU     := MlCAL_ZEI(NwIX);            -- 全体税額
                    RlKIBETSUCAL.TAI_ZEIGAKU     := MlCAL_TAI_ZEI(NwIX);        -- 退職税額
                    RlKIBETSUCAL.IR_ZEN_ZEIGAKU  := MlIRY_ZEI(NwIX);            -- 医療全体税額
                    RlKIBETSUCAL.IR_TAI_ZEIGAKU  := MlIRY_TAI_ZEI(NwIX);        -- 医療退職税額
                    RlKIBETSUCAL.KAI_ZEN_ZEIGAKU := MlKAI_ZEI(NwIX);            -- 介護全体税額
                    RlKIBETSUCAL.KAI_TAI_ZEIGAKU := MlKAI_TAI_ZEI(NwIX);        -- 介護退職税額
                    RlKIBETSUCAL.SIEN_ZEN_ZEIGAKU  := MlSIEN_ZEI(NwIX);         -- 支援全体税額
                    RlKIBETSUCAL.SIEN_TAI_ZEIGAKU  := MlSIEN_TAI_ZEI(NwIX);     -- 支援退職税額
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                    RlKIBETSUCAL.KDM_ZEN_ZEIGAKU  := MlKDM_ZEI(NwIX);     -- 子ども全体税額
                    BEGIN
                        INSERT INTO ZLBTKIBETSU_CAL VALUES RlKIBETSUCAL;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NlRTN := c_NERR;
                            VlMSG := 'subInsert 計算期別登録(国保世帯番号='||
                                     i_NSETAI||')'||SQLERRM;
                            EXIT;
                    END;
                END IF;
            END LOOP;
        ELSE
            -- 過年度時かつ差額増額時は収納条件に存在する期すべて出力
            FOR RwSHUNOJKNK IN CwSHUNOJKNK LOOP
                NwIX := RwSHUNOJKNK.RONRIKIBETSU;
                RlKIBETSUCAL.CHOTEINENDO    := MlCAL_CHOTEI_NENDO(NwIX);    -- 調定年度
                RlKIBETSUCAL.TSUCHI_NO      := MlCAL_TSUCHI_NO(NwIX);       -- 通知書番号
                RlKIBETSUCAL.RONRIKIBETSU   := MlCAL_KIBETSU(NwIX);         -- 論理期別
                RlKIBETSUCAL.KAMOKUS_CD     := MlKAMOKUS(NwIX);             -- 科目詳細コード(固定)

                IF MlKAMOKUS(NwIX) = c_NKAMOKUS_FUTU THEN  -- 普通徴収
                    IF NwIX < 10 THEN                                           -- 年月
                        RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + (NwIX + 3);
                    ELSIF NwIX <= 13 THEN
                        RlKIBETSUCAL.NENGETSU   := (MlCAL_CHOTEI_NENDO(NwIX) + 1) * 100 + (NwIX - 9);
                    END IF;
                ELSE     -- 普徴以外(特徴)
                    -- 論理期別に13をたす
                    NwIX := NwIX + 13;

                    CASE NwIX
                        WHEN 14 THEN
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 4;
                        WHEN 16 THEN
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 6;
                        WHEN 18 THEN
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 8;
                        WHEN 20 THEN
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 10;
                        WHEN 22 THEN
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 12;
                        WHEN 24 THEN
                            RlKIBETSUCAL.NENGETSU   := (MlCAL_CHOTEI_NENDO(NwIX) + 1) * 100 + 2;
                   END CASE;
                END IF;
                -- 納税義務者個人番号
                IF MlCAL_NUSI_KOJIN_NO(NwIX) != 0 THEN
                    RlKIBETSUCAL.NUSHI_KOJIN_NO := MlCAL_NUSI_KOJIN_NO(NwIX);
                ELSE
                    RlKIBETSUCAL.NUSHI_KOJIN_NO := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;
                RlKIBETSUCAL.ZEN_ZEIGAKU      := MlCAL_ZEI(NwIX);          -- 全体税額
                RlKIBETSUCAL.TAI_ZEIGAKU      := MlCAL_TAI_ZEI(NwIX);      -- 退職税額
                RlKIBETSUCAL.IR_ZEN_ZEIGAKU   := MlIRY_ZEI(NwIX);          -- 医療全体税額
                RlKIBETSUCAL.IR_TAI_ZEIGAKU   := MlIRY_TAI_ZEI(NwIX);      -- 医療退職税額
                RlKIBETSUCAL.KAI_ZEN_ZEIGAKU  := MlKAI_ZEI(NwIX);          -- 介護全体税額
                RlKIBETSUCAL.KAI_TAI_ZEIGAKU  := MlKAI_TAI_ZEI(NwIX);      -- 介護退職税額
                RlKIBETSUCAL.SIEN_ZEN_ZEIGAKU := MlSIEN_ZEI(NwIX);         -- 支援全体税額
                RlKIBETSUCAL.SIEN_TAI_ZEIGAKU := MlSIEN_TAI_ZEI(NwIX);     -- 支援退職税額
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                RlKIBETSUCAL.KDM_ZEN_ZEIGAKU  := MlKDM_ZEI(NwIX);          -- 子ども全体税額
                BEGIN
                    INSERT INTO ZLBTKIBETSU_CAL VALUES RlKIBETSUCAL;
                EXCEPTION
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subInsert 計算期別登録(国保世帯番号='||
                                 i_NSETAI||')'||SQLERRM;
                        EXIT;
                END;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subInsert 計算期別登録(国保世帯番号='||
                     i_NSETAI||')'||SQLERRM;
    END subInsert;
-------------------------------------------------------------------------------
-- 主処理
-------------------------------------------------------------------------------
    PROCEDURE subMain IS
    BEGIN
        -- 差額により処理をコントロール
        IF (NlSAGAKU     = 0 AND NlTAI_SAGAKU     = 0) AND
           (NlZEN_SAGAKU     = 0 AND NlZENTAI_SAGAKU     = 0) AND
           (NlKAI_SAGAKU = 0 AND NlKAI_TAI_SAGAKU = 0) AND
-- 2025/08/11 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応
           --(NlSIEN_SAGAKU = 0 AND NlSIEN_TAI_SAGAKU = 0) THEN
           (NlSIEN_SAGAKU = 0 AND NlSIEN_TAI_SAGAKU = 0 AND NlKDM_SAGAKU = 0) THEN
            subCalKibetsuSet(0);    -- 07 計算期別セット  (全体)
            RlKIHONCAL.NENZEI    := NlNENZEI;           -- 全体年税額
            RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
            RlKAIKIHONCAL.NENZEI := NlKAI_NENZEI;       -- 介護全体年税額
            RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
            RlSIENKIHONCAL.NENZEI := NlSIEN_NENZEI;     -- 支援全体年税額
            RlSIENTAICAL.NENZEI   := NlSIEN_TAI_NENZEI; -- 支援退職年税額
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
           RlKDMKIHONCAL.NENZEI  := NlKDM_NENZEI;       -- 計算子ども基本年税額
        ELSE
            IF (NlSAGAKU     > 0 AND NlTAI_SAGAKU     > 0) OR
               (NlZEN_SAGAKU  > 0 AND NlZENTAI_SAGAKU   > 0) OR
               (NlKAI_SAGAKU > 0 AND NlKAI_TAI_SAGAKU > 0) OR
               (NlSAGAKU     > 0 AND NlKAI_TAI_SAGAKU > 0) OR
               (NlKAI_SAGAKU > 0 AND NlTAI_SAGAKU     > 0) OR
               (NlSIEN_SAGAKU     > 0 AND NlTAI_SAGAKU     > 0) OR
               (NlSIEN_SAGAKU     > 0 AND NlKAI_TAI_SAGAKU     > 0) OR
               (NlSIEN_SAGAKU     > 0 AND NlSIEN_TAI_SAGAKU     > 0) OR
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
               (NlKDM_SAGAKU     > 0 AND NlTAI_SAGAKU     > 0) OR
               (NlKDM_SAGAKU     > 0 AND NlKAI_TAI_SAGAKU     > 0) OR
               (NlKDM_SAGAKU     > 0 AND NlSIEN_TAI_SAGAKU     > 0) OR
-- 2025/08/11 ZCZL.LIUDI ADD END
               (NlSAGAKU     > 0 AND NlSIEN_TAI_SAGAKU > 0) OR
               (NlKAI_SAGAKU > 0 AND NlSIEN_TAI_SAGAKU     > 0) THEN
                subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                    NlLOOP_FLG := 1; -- 全体と退職変更有り
                    subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                END IF;
            ELSE
                IF (NlZEN_SAGAKU = 0 AND NlZENTAI_SAGAKU > 0) THEN
                    subCalKibetsuSet(0);    -- 07 計算期別セット  (全体)
                    RlKIHONCAL.NENZEI    := NlNENZEI;           -- 全体年税額
                    RlKAIKIHONCAL.NENZEI := NlKAI_NENZEI;       -- 介護全体年税額
                    RlSIENKIHONCAL.NENZEI := NlSIEN_NENZEI;     -- 支援全体年税額
                    IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                        subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                    END IF;
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                    RlKDMKIHONCAL.NENZEI := NlKDM_NENZEI;     -- 子ども年税額
                ELSE
                    IF (NlZEN_SAGAKU > 0 AND NlZENTAI_SAGAKU = 0) THEN
                        IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                            subCalKibetsuSet(1);    -- 07 計算期別セット  (退職)
                            RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
                            RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
                            RlSIENTAICAL.NENZEI  := NlSIEN_TAI_NENZEI;  -- 支援退職年税額
                        END IF;
                        subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                    ELSE
                       IF (NlSAGAKU = 0 AND NlTAI_SAGAKU > 0) THEN
                           subCalKibetsuSet(0);    -- 07 計算期別セット  (全体)
                           RlKIHONCAL.NENZEI    := NlNENZEI;           -- 全体年税額
                           RlKAIKIHONCAL.NENZEI := NlKAI_NENZEI;       -- 介護全体年税額
                           RlSIENKIHONCAL.NENZEI := NlSIEN_NENZEI;     -- 支援全体年税額
                          IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                              subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                          END IF;
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                          RlKDMKIHONCAL.NENZEI := NlKDM_NENZEI;     -- 子ども年税額
                       ELSE
                           IF (NlSAGAKU > 0 AND NlTAI_SAGAKU = 0) THEN
                               IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                                   subCalKibetsuSet(1);    -- 07 計算期別セット  (退職)
                                   RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
                                   RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
                                   RlSIENTAICAL.NENZEI  := NlSIEN_TAI_NENZEI;  -- 支援退職年税額
                               END IF;
                               subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                           ELSE
                               IF (NlKAI_SAGAKU = 0 AND NlKAI_TAI_SAGAKU > 0) THEN
                                   subCalKibetsuSet(0);    -- 07 計算期別セット  (全体)
                                   RlKIHONCAL.NENZEI    := NlNENZEI;           -- 全体年税額
                                   RlKAIKIHONCAL.NENZEI := NlKAI_NENZEI;       -- 介護全体年税額
                                   RlSIENKIHONCAL.NENZEI := NlSIEN_NENZEI;     -- 支援全体年税額
                                   IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                                       subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                                   END IF;
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                   RlKDMKIHONCAL.NENZEI := NlKDM_NENZEI;     -- 子ども年税額
                               ELSE
                                   IF (NlKAI_SAGAKU > 0 AND NlKAI_TAI_SAGAKU = 0) THEN
                                       IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                                           subCalKibetsuSet(1);    -- 07 計算期別セット  (退職)
                                           RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
                                           RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
                                           RlSIENTAICAL.NENZEI  := NlSIEN_TAI_NENZEI;  -- 支援退職年税額
                                       END IF;
                                      subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                                   ELSE

                                       IF (NlSIEN_SAGAKU = 0 AND NlSIEN_TAI_SAGAKU > 0) THEN
                                            subCalKibetsuSet(0);    -- 07 計算期別セット  (全体)
                                            RlKIHONCAL.NENZEI    := NlNENZEI;           -- 全体年税額
                                            RlKAIKIHONCAL.NENZEI := NlKAI_NENZEI;       -- 介護全体年税額
                                            RlSIENKIHONCAL.NENZEI := NlSIEN_NENZEI;     -- 支援全体年税額
                                           IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                                               subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                                           END IF;
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                           RlKDMKIHONCAL.NENZEI := NlKDM_NENZEI;     -- 子ども年税額
                                       ELSE
                                           IF (NlSIEN_SAGAKU > 0 AND NlSIEN_TAI_SAGAKU = 0) THEN
                                               IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                                                   subCalKibetsuSet(1);    -- 07 計算期別セット  (退職)
                                                   RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
                                                   RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
                                                   RlSIENTAICAL.NENZEI   := NlSIEN_TAI_NENZEI; -- 支援退職年税額
                                               END IF;
                                               subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                                            ELSE
-- 2025/08/11 ZCZL.LIUDI UPDATE START 1.1.200.000:子ども子育て支援金対応
                                                --subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                                                --IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                                                --    NlLOOP_FLG := 1;  -- 全体と退職変更有り
                                                --    subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                                                --END IF;
                                                IF NlKDM_SAGAKU > 0 THEN
                                                    IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                                                         subCalKibetsuSet(0);
                                                         RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
                                                         RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
                                                         RlSIENTAICAL.NENZEI   := NlSIEN_TAI_NENZEI; -- 支援退職年税額
                                                     END IF;
                                                     subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                                                ELSE
                                                    subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                                                    IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN    -- 「賦課試算」以外
                                                        NlLOOP_FLG := 1;  -- 全体と退職変更有り
                                                        subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                                                    END IF;
-- 2025/08/11 ZCZL.LIUDI UPDATE END
                                                END IF;
                                           END IF;
                                       END IF;
                                   END IF;
                               END IF;
                           END IF;
                       END IF;
                   END IF;
               END IF;
            END IF;
        END IF;
    END subMain;
-------------------------------------------------------------------------------
-- 賦課試算用 ワークエリア退避
-------------------------------------------------------------------------------
    PROCEDURE subWorkSaveTS IS
        NwIX                NUMBER(2);
        NwSUMZEI            NUMBER;
        -- 更正前期別(賦課試算)カーソル
        CURSOR CwKIBETSU IS
            SELECT * FROM ZLBTKIBETSU_TS
             WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
               AND CHOTEINENDO     = i_NNENDO               -- 調定年度
               AND NENDOBUN        = i_NNENDO_BUN           -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO           -- 通知書番号
               AND SYS_TANMATSU_NO = i_VTANMATSU;
        -- 賦課期別(計算)カーソル
        CURSOR CwKIBETSU_CAL IS
            SELECT * FROM ZLBTKIBETSU_CAL
             WHERE KAMOKU_CD       = c_NKAMOKU_CD     -- 科目コード
               AND KAMOKUS_CD      = c_NKAMOKUS_TOKU  -- 科目詳細コード(特徴)
               AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
               AND CHOTEINENDO     = i_NNENDO         -- 調定年度
               AND NENDOBUN        = i_NNENDO_BUN     -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO     -- 通知書番号
               AND SYS_TANMATSU_NO = i_VTANMATSU;     -- 端末番号
    BEGIN
        -- 更正前基本(賦課試算)取得
        BEGIN
            SELECT NENZEI, GENMEN INTO NlNENZEI, NlGENMEN
              FROM ZLBTKIHON_TS
             WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
               AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
               AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO           -- 通知書番号
               AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subWorkSaveTS 更正前基本取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
        END;
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
        --更正前子ども基本(賦課試算)取得
        BEGIN
                SELECT NENZEI INTO NlKDM_NENZEI
                  FROM ZLBTKDM_KIHON_TS
                 WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO           -- 通知書番号
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSaveTS 更正前子ども基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
-- 2025/08/11 ZCZL.LIUDI ADD END
        -- 更正前介護基本(賦課試算)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlKAI_NENZEI
                  FROM ZLBTKAI_KIHON_TS
                 WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO           -- 通知書番号
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSaveTS 更正前介護基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 更正前支援基本(賦課試算)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlSIEN_NENZEI
                  FROM ZLBTSIEN_KIHON_TS
                 WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO           -- 通知書番号
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSaveTS 更正前支援基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 更正前期別(賦課試算)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                FOR RwKIBETSU IN CwKIBETSU LOOP
                    NwIX := RwKIBETSU.RONRIKIBETSU;
                    -- 科目詳細コードが特徴の場合はインデックスに13をたす
                    IF RwKIBETSU.KAMOKUS_CD = c_NKAMOKUS_TOKU THEN
                        NwIX := NwIX + 13;
                    END IF;
                    MlKAMOKUS(NwIX)       := RwKIBETSU.KAMOKUS_CD;        -- 科目詳細コード
                    MlKIBETSU(NwIX)       := RwKIBETSU.RONRIKIBETSU;      -- 期別
                    MlKIZEI(NwIX)         := RwKIBETSU.ZEN_ZEIGAKU;       -- 期別税額
                    MlTAI_KIZEI(NwIX)     := RwKIBETSU.TAI_ZEIGAKU;       -- 退期別税額
                    MlNUSI_KOJIN_NO(NwIX) := RwKIBETSU.NUSHI_KOJIN_NO;    -- 主個人番号
                    MlIRY_ZEI(NwIX)       := RwKIBETSU.IR_ZEN_ZEIGAKU;    -- 医療全体税額
                    MlIRY_TAI_ZEI(NwIX)   := RwKIBETSU.IR_TAI_ZEIGAKU;    -- 医療退職税額
                    MlKAI_ZEI(NwIX)       := RwKIBETSU.KAI_ZEN_ZEIGAKU;   -- 介護全体税額
                    MlKAI_TAI_ZEI(NwIX)   := RwKIBETSU.KAI_TAI_ZEIGAKU;   -- 介護退職税額
                    MlSIEN_ZEI(NwIX)      := RwKIBETSU.SIEN_ZEN_ZEIGAKU;  -- 支援全体税額
                    MlSIEN_TAI_ZEI(NwIX)  := RwKIBETSU.SIEN_TAI_ZEIGAKU;  -- 支援退職税額
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                    MlKDM_ZEI(NwIX)       := RwKIBETSU.KDM_ZEN_ZEIGAKU;   -- 子ども全体年税額
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSaveTS 更正前期別取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        IF NlRTN = c_NOK THEN
            --特徴中止の場合は計算期別に既にレコードが作成されているので再セットする
            BEGIN
                -- 計算期別テーブル特徴レコード数取得
                SELECT COUNT(*) INTO NwIX FROM ZLBTKIBETSU_CAL
                 WHERE SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
                   AND CHOTEINENDO     = i_NNENDO            -- 調定年度
                   AND NENDOBUN        = i_NNENDO_BUN        -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
                   AND KAMOKUS_CD      = c_NKAMOKUS_TOKU     -- 特徴
                   AND SYS_TANMATSU_NO = i_VTANMATSU;        -- 端末番号;
                IF NwIX > 0 THEN
                    -- 賦課期別取得
                    BEGIN
                        FOR RwKIBETSU_CAL IN CwKIBETSU_CAL LOOP --特徴分
                            NwIX := RwKIBETSU_CAL.RONRIKIBETSU + 13;
                            MlKAMOKUS(NwIX)       := RwKIBETSU_CAL.KAMOKUS_CD;        -- 科目詳細コード
                            MlKIBETSU(NwIX)       := RwKIBETSU_CAL.RONRIKIBETSU;      -- 期別
                            MlKIZEI(NwIX)         := RwKIBETSU_CAL.ZEN_ZEIGAKU;       -- 期別税額
                            MlTAI_KIZEI(NwIX)     := RwKIBETSU_CAL.TAI_ZEIGAKU;       -- 退期別税額
                            MlNUSI_KOJIN_NO(NwIX) := RwKIBETSU_CAL.NUSHI_KOJIN_NO;    -- 主個人番号
                            MlIRY_ZEI(NwIX)       := RwKIBETSU_CAL.IR_ZEN_ZEIGAKU;    -- 医療全体税額
                            MlIRY_TAI_ZEI(NwIX)   := RwKIBETSU_CAL.IR_TAI_ZEIGAKU;    -- 医療退職税額
                            MlKAI_ZEI(NwIX)       := RwKIBETSU_CAL.KAI_ZEN_ZEIGAKU;   -- 介護全体税額
                            MlKAI_TAI_ZEI(NwIX)   := RwKIBETSU_CAL.KAI_TAI_ZEIGAKU;   -- 介護退職税額
                            MlSIEN_ZEI(NwIX)      := RwKIBETSU_CAL.SIEN_ZEN_ZEIGAKU;  -- 支援全体税額
                            MlSIEN_TAI_ZEI(NwIX)  := RwKIBETSU_CAL.SIEN_TAI_ZEIGAKU;  -- 支援退職税額
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                            MlKDM_ZEI(NwIX)       := RwKIBETSU_CAL.KDM_ZEN_ZEIGAKU;   -- 子ども全体年税額
                        END LOOP;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NULL;
                        WHEN OTHERS THEN
                            NlRTN := c_NERR;
                            VlMSG := 'subWorkSaveTS 計算期別取得(国保世帯番号='||
                               i_NSETAI||')'||SQLERRM;
                    END;
                END IF;
                IF NlRTN = c_NOK THEN
                    -- セーブした特徴計算期別を削除
                    DELETE FROM ZLBTKIBETSU_CAL
                     WHERE KAMOKU_CD       = c_NKAMOKU_CD               -- 科目コード(新規分)
                       AND KOKU_SETAI_NO   = i_NSETAI                   -- 国保世帯番号
                       AND SANTEIDANTAI_CD = i_NDANTAI                  -- 算定団体コード
                       AND CHOTEINENDO     = i_NNENDO                   -- 調定年度
                       AND NENDOBUN        = i_NNENDO_BUN               -- 年度
                       AND TSUCHI_NO       = I_NTSUCHI_NO               -- 通知書番号
                       AND SYS_TANMATSU_NO = I_VTANMATSU;               -- 端末番号
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSaveTS 更正前期別取得2(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        IF NlRTN = c_NOK THEN
-- 2025/08/11 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応
--            -- 差額算出(医療全体,医療退職(0),介護全体,介護退職(0),支援全体,支援退職(0))
            -- 差額算出(医療全体,医療退職(0),介護全体,介護退職(0),支援全体,支援退職(0),子ども全体)
            NlSAGAKU         := ABS(NlNENZEI     - RlKIHONCAL.NENZEI); --医療全体
            IF NlSAGAKU = 0 THEN                                       --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlIRY_ZEI(NwIX), 0);
                END LOOP;
                NlSAGAKU := ABS(NlNENZEI - NwSUMZEI);
            END IF;
            NlTAI_SAGAKU     := 0;
            NlKAI_SAGAKU     := ABS(NlKAI_NENZEI - RlKAIKIHONCAL.NENZEI); --介護全体
            IF NlKAI_SAGAKU = 0 THEN                                      --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlKAI_ZEI(NwIX), 0);
                END LOOP;
                NlKAI_SAGAKU := ABS(NlKAI_NENZEI - NwSUMZEI);
            END IF;
            NlKAI_TAI_SAGAKU := 0;
            NlSIEN_SAGAKU     := ABS(NlSIEN_NENZEI - RlSIENKIHONCAL.NENZEI); --支援全体
            IF NlSIEN_SAGAKU = 0 THEN                                        --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlSIEN_ZEI(NwIX), 0);
                END LOOP;
                NlSIEN_SAGAKU := ABS(NlSIEN_NENZEI - NwSUMZEI);
            END IF;
            NlSIEN_TAI_SAGAKU := 0;
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
            NlKDM_SAGAKU     := ABS(NlKDM_NENZEI - RlKDMKIHONCAL.NENZEI); --子ども全体
            IF NlKDM_SAGAKU = 0 THEN                                        --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlKDM_ZEI(NwIX), 0);
                END LOOP;
                NlKDM_SAGAKU := ABS(NlKDM_NENZEI - NwSUMZEI);
            END IF;
-- 2025/08/11 ZCZL.LIUDI ADD END
        END IF;
        
    END subWorkSaveTS;
-------------------------------------------------------------------------------
-- ワークエリア退避
-------------------------------------------------------------------------------
    PROCEDURE subWorkSave IS
        NwIX                NUMBER(2);
        NwSUMZEI            NUMBER;
        NlZEN_NENZEI        NUMBER;
        NlZENTAI_NENZEI     NUMBER;
        -- 賦課期別(最新)カーソル
        CURSOR CwKIBETSU IS
            SELECT * FROM ZLBTKIBETSU_N
             WHERE KAMOKU_CD       = c_NKAMOKU_CD  -- 科目コード
               AND SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
               AND CHOTEINENDO     = i_NNENDO      -- 調定年度
               AND NENDOBUN        = i_NNENDO_BUN  -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO;  -- 通知書番号
        -- 賦課期別(計算)カーソル
        CURSOR CwKIBETSU_CAL IS
            SELECT * FROM ZLBTKIBETSU_CAL
             WHERE KAMOKU_CD       = c_NKAMOKU_CD     -- 科目コード
               AND KAMOKUS_CD      = c_NKAMOKUS_TOKU  -- 科目詳細コード(特徴)
               AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
               AND CHOTEINENDO     = i_NNENDO         -- 調定年度
               AND NENDOBUN        = i_NNENDO_BUN     -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO     -- 通知書番号
               AND SYS_TANMATSU_NO = i_VTANMATSU;     -- 端末番号
    BEGIN
        -- 賦課基本(最新)取得
        BEGIN
            SELECT NENZEI, GENMEN INTO NlNENZEI, NlGENMEN
              FROM ZLBTKIHON_N
             WHERE SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
               AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
               AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO;   -- 通知書番号
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subWorkSave 賦課基本(最新)取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
        END;
        -- 賦課退職(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI, GENMEN INTO NlTAI_NENZEI, NlTAI_GENMEN
                  FROM ZLBTTAI_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;   -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課退職(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 賦課介護基本(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlKAI_NENZEI
                  FROM ZLBTKAI_KIHON_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;   -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課介護基本(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 賦課介護退職(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlKAI_TAI_NENZEI
                  FROM ZLBTKAI_TAI_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;   -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課介護退職(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 賦課支援基本(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlSIEN_NENZEI
                  FROM ZLBTSIEN_KIHON_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;   -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課支援基本(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
        -- 賦課子ども基本(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlKDM_NENZEI
                  FROM ZLBTKDM_KIHON_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;   -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課子ども基本(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
-- 2025/08/11 ZCZL.LIUDI ADD END
        -- 賦課支援退職(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlSIEN_TAI_NENZEI
                  FROM ZLBTSIEN_TAI_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;   -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課支援退職(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        IF i_NJIKKOU_KBN = c_NONL_SOKUJI THEN
            -- 納期限情報取得
            NlRTN := FUNCNOKIGENGETMAIN;
        END IF;
        IF NlRTN = c_NOK THEN

        -- 計算期別テーブル特徴レコード数取得
        SELECT COUNT(*) INTO NwIX FROM ZLBTKIBETSU_CAL
             WHERE SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
               AND CHOTEINENDO     = i_NNENDO            -- 調定年度
               AND NENDOBUN        = i_NNENDO_BUN        -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
               AND KAMOKUS_CD      = c_NKAMOKUS_TOKU     -- 特徴
               AND SYS_TANMATSU_NO = i_VTANMATSU;        -- 端末番号;

        IF NwIX > 0 THEN
            -- 賦課期別取得
            IF NlRTN = c_NOK THEN
                BEGIN
                    FOR RwKIBETSU_N IN CwKIBETSU LOOP
                        IF RwKIBETSU_N.KAMOKUS_CD = c_NKAMOKUS_FUTU THEN --普徴分

                            NwIX := RwKIBETSU_N.RONRIKIBETSU;
                            MlKAMOKUS(NwIX)       := RwKIBETSU_N.KAMOKUS_CD;        -- 科目詳細コード
                            MlKIBETSU(NwIX)       := RwKIBETSU_N.RONRIKIBETSU;      -- 期別
                            MlKIZEI(NwIX)         := RwKIBETSU_N.ZEN_ZEIGAKU;       -- 期別税額
                            MlTAI_KIZEI(NwIX)     := RwKIBETSU_N.TAI_ZEIGAKU;       -- 退期別税額
                            MlNUSI_KOJIN_NO(NwIX) := RwKIBETSU_N.NUSHI_KOJIN_NO;    -- 主個人番号
                            MlIRY_ZEI(NwIX)       := RwKIBETSU_N.IR_ZEN_ZEIGAKU;    -- 医療全体税額
                            MlIRY_TAI_ZEI(NwIX)   := RwKIBETSU_N.IR_TAI_ZEIGAKU;    -- 医療退職税額
                            MlKAI_ZEI(NwIX)       := RwKIBETSU_N.KAI_ZEN_ZEIGAKU;   -- 介護全体税額
                            MlKAI_TAI_ZEI(NwIX)   := RwKIBETSU_N.KAI_TAI_ZEIGAKU;   -- 介護退職税額
                            MlSIEN_ZEI(NwIX)      := RwKIBETSU_N.SIEN_ZEN_ZEIGAKU;  -- 支援全体税額
                            MlSIEN_TAI_ZEI(NwIX)  := RwKIBETSU_N.SIEN_TAI_ZEIGAKU;  -- 支援退職税額
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                            MlKDM_ZEI(NwIX)       := RwKIBETSU_N.KDM_ZEN_ZEIGAKU;   -- 子ども全体年税額
                        END IF;
                    END LOOP;
                    FOR RwKIBETSU_CAL IN CwKIBETSU_CAL LOOP --特徴分
                        NwIX := RwKIBETSU_CAL.RONRIKIBETSU + 13;
                        MlKAMOKUS(NwIX)       := RwKIBETSU_CAL.KAMOKUS_CD;        -- 科目詳細コード
                        MlKIBETSU(NwIX)       := RwKIBETSU_CAL.RONRIKIBETSU;      -- 期別
                        MlKIZEI(NwIX)         := RwKIBETSU_CAL.ZEN_ZEIGAKU;       -- 期別税額
                        MlTAI_KIZEI(NwIX)     := RwKIBETSU_CAL.TAI_ZEIGAKU;       -- 退期別税額
                        MlNUSI_KOJIN_NO(NwIX) := RwKIBETSU_CAL.NUSHI_KOJIN_NO;    -- 主個人番号
                        MlIRY_ZEI(NwIX)       := RwKIBETSU_CAL.IR_ZEN_ZEIGAKU;    -- 医療全体税額
                        MlIRY_TAI_ZEI(NwIX)   := RwKIBETSU_CAL.IR_TAI_ZEIGAKU;    -- 医療退職税額
                        MlKAI_ZEI(NwIX)       := RwKIBETSU_CAL.KAI_ZEN_ZEIGAKU;   -- 介護全体税額
                        MlKAI_TAI_ZEI(NwIX)   := RwKIBETSU_CAL.KAI_TAI_ZEIGAKU;   -- 介護退職税額
                        MlSIEN_ZEI(NwIX)      := RwKIBETSU_CAL.SIEN_ZEN_ZEIGAKU;  -- 支援全体税額
                        MlSIEN_TAI_ZEI(NwIX)  := RwKIBETSU_CAL.SIEN_TAI_ZEIGAKU;  -- 支援退職税額
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                        MlKDM_ZEI(NwIX)       := RwKIBETSU_CAL.KDM_ZEN_ZEIGAKU;     -- 子ども全体年税額
                    END LOOP;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subWorkSave 賦課期別(最新)取得(国保世帯番号='||
                                 i_NSETAI||')'||SQLERRM;
                END;
            END IF;
        ELSE
            -- 賦課期別取得
            IF NlRTN = c_NOK THEN
                BEGIN
                    FOR RwKIBETSU_N IN CwKIBETSU LOOP
                        NwIX := RwKIBETSU_N.RONRIKIBETSU;
                        -- 科目詳細コードが特徴の場合はインデックスに13をたす
                        IF RwKIBETSU_N.KAMOKUS_CD = c_NKAMOKUS_TOKU THEN
                            NwIX := NwIX + 13;
                        END IF;
                        MlKAMOKUS(NwIX)       := RwKIBETSU_N.KAMOKUS_CD;        -- 科目詳細コード
                        MlKIBETSU(NwIX)       := RwKIBETSU_N.RONRIKIBETSU;      -- 期別
                        MlKIZEI(NwIX)         := RwKIBETSU_N.ZEN_ZEIGAKU;       -- 期別税額
                        MlTAI_KIZEI(NwIX)     := RwKIBETSU_N.TAI_ZEIGAKU;       -- 退期別税額
                        MlNUSI_KOJIN_NO(NwIX) := RwKIBETSU_N.NUSHI_KOJIN_NO;    -- 主個人番号
                        MlIRY_ZEI(NwIX)       := RwKIBETSU_N.IR_ZEN_ZEIGAKU;    -- 医療全体税額
                        MlIRY_TAI_ZEI(NwIX)   := RwKIBETSU_N.IR_TAI_ZEIGAKU;    -- 医療退職税額
                        MlKAI_ZEI(NwIX)       := RwKIBETSU_N.KAI_ZEN_ZEIGAKU;   -- 介護全体税額
                        MlKAI_TAI_ZEI(NwIX)   := RwKIBETSU_N.KAI_TAI_ZEIGAKU;   -- 介護退職税額
                        MlSIEN_ZEI(NwIX)      := RwKIBETSU_N.SIEN_ZEN_ZEIGAKU;  -- 支援全体税額
                        MlSIEN_TAI_ZEI(NwIX)  := RwKIBETSU_N.SIEN_TAI_ZEIGAKU;  -- 支援退職税額
-- 2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                        MlKDM_ZEI(NwIX)       := RwKIBETSU_N.KDM_ZEN_ZEIGAKU;   -- 子ども全体年税額
                    END LOOP;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subWorkSave 賦課期別(最新)取得(国保世帯番号='||
                                 i_NSETAI||')'||SQLERRM;
                END;
            END IF;
        END IF;
        END IF;
         -- 計算期別レコードを削除
        DELETE FROM ZLBTKIBETSU_CAL
               WHERE KAMOKU_CD       = c_NKAMOKU_CD               -- 科目コード(新規分)
                 AND KOKU_SETAI_NO   = i_NSETAI                   -- 国保世帯番号
                 AND SANTEIDANTAI_CD = i_NDANTAI                  -- 算定団体コード
                 AND CHOTEINENDO     = i_NNENDO                   -- 調定年度
                 AND NENDOBUN        = i_NNENDO_BUN               -- 年度
                 AND TSUCHI_NO       = I_NTSUCHI_NO               -- 通知書番号
                 AND SYS_TANMATSU_NO = I_VTANMATSU;               -- 端末番号
        IF NlRTN = c_NOK THEN
            -- 差額算出(医療全体,医療退職,介護全体,介護退職,支援全体,支援退職)
            -- 全体の年税額
            NwSUMZEI := 0;
-- 2025/08/11 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応
            --NlZEN_NENZEI := RlKIHONCAL.NENZEI + RlKAIKIHONCAL.NENZEI + RlSIENKIHONCAL.NENZEI;
            NlZEN_NENZEI := RlKIHONCAL.NENZEI + RlKAIKIHONCAL.NENZEI + RlSIENKIHONCAL.NENZEI + RlKDMKIHONCAL.NENZEI;
            FOR NwIX IN 1..24 LOOP
                 NwSUMZEI := NwSUMZEI + NVL(MlKIZEI(NwIX), 0);
            END LOOP;
            NlZEN_SAGAKU := ABS(NlZEN_NENZEI - NwSUMZEI);
            -- 全体の退職年税額
            NwSUMZEI := 0;
            NlZENTAI_NENZEI := RlTAICAL.NENZEI + RlKAITAICAL.NENZEI + RlSIENTAICAL.NENZEI;
            FOR NwIX IN 1..24 LOOP
                 NwSUMZEI := NwSUMZEI + NVL(MlTAI_KIZEI(NwIX), 0);
            END LOOP;
            NlZENTAI_SAGAKU := ABS(NlZENTAI_NENZEI - NwSUMZEI);
            NlSAGAKU         := ABS(NlNENZEI     - RlKIHONCAL.NENZEI); --医療全体
            IF NlSAGAKU = 0 THEN                                       --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlIRY_ZEI(NwIX), 0);
                END LOOP;
                NlSAGAKU := ABS(NlNENZEI - NwSUMZEI);
            END IF;
            NlTAI_SAGAKU     := ABS(NlTAI_NENZEI - RlTAICAL.NENZEI); --医療退職
            IF NlTAI_SAGAKU = 0 THEN                                 --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlIRY_TAI_ZEI(NwIX), 0);
                END LOOP;
                NlTAI_SAGAKU := ABS(NlTAI_NENZEI - NwSUMZEI);
            END IF;
            NlKAI_SAGAKU     := ABS(NlKAI_NENZEI - RlKAIKIHONCAL.NENZEI); --介護全体
            IF NlKAI_SAGAKU = 0 THEN                                      --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlKAI_ZEI(NwIX), 0);
                END LOOP;
                NlKAI_SAGAKU := ABS(NlKAI_NENZEI - NwSUMZEI);
            END IF;
            NlKAI_TAI_SAGAKU := ABS(NlKAI_TAI_NENZEI - RlKAITAICAL.NENZEI); --介護退職
            IF NlKAI_TAI_SAGAKU = 0 THEN                                    --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlKAI_TAI_ZEI(NwIX), 0);
                END LOOP;
                NlKAI_TAI_SAGAKU := ABS(NlKAI_TAI_NENZEI - NwSUMZEI);
            END IF;
            NlSIEN_SAGAKU     := ABS(NlSIEN_NENZEI - RlSIENKIHONCAL.NENZEI); --支援全体
            IF NlSIEN_SAGAKU = 0 THEN                                        --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlSIEN_ZEI(NwIX), 0);
                END LOOP;
                NlSIEN_SAGAKU := ABS(NlSIEN_NENZEI - NwSUMZEI);
            END IF;

            NlSIEN_TAI_SAGAKU:= ABS(NlSIEN_TAI_NENZEI - RlSIENTAICAL.NENZEI); --支援退職
            IF NlSIEN_TAI_SAGAKU = 0 THEN                                     --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlSIEN_TAI_ZEI(NwIX), 0);
                END LOOP;
                NlSIEN_TAI_SAGAKU := ABS(NlSIEN_TAI_NENZEI - NwSUMZEI);
            END IF;
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
            NlKDM_SAGAKU     := ABS(NlKDM_NENZEI - RlKDMKIHONCAL.NENZEI);     --子ども
            IF NlKDM_SAGAKU = 0 THEN                                        --差額0の時
                NwSUMZEI := 0;
                FOR NwIX IN 1..24 LOOP
                    NwSUMZEI := NwSUMZEI + NVL(MlKDM_ZEI(NwIX), 0);
                END LOOP;
                NlKDM_SAGAKU := ABS(NlKDM_NENZEI - NwSUMZEI);
            END IF;
-- 2025/08/11 ZCZL.LIUDI ADD END
        END IF;
    END subWorkSave;
-------------------------------------------------------------------------------
-- 計算TBL取得
-------------------------------------------------------------------------------
    PROCEDURE subKihonSel IS
    BEGIN
        -- 個人取得
        BEGIN
            SELECT COUNT(*)  INTO IHON_GENZON_CNT FROM ZLBTKOJIN_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU
               AND SHIK_7          IN (1, 3, 11, 13);
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subKihonSel 個人取得(国保世帯番号='||
                         i_NSETAI ||')'||SQLERRM;
        END;
        -- 計算基本取得
        BEGIN
            SELECT * INTO RlKIHONCAL FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subKihonSel 計算基本取得(国保世帯番号='||
                         i_NSETAI ||')'||SQLERRM;
        END;
        -- 計算退職取得
        IF NlRTN = c_NOK AND i_NJIKKOU_KBN != c_NONL_CALZEI THEN          -- 「賦課試算」以外の場合
            BEGIN
                SELECT * INTO RlTAICAL FROM ZLBTTAI_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                   AND SANTEIDANTAI_CD = i_NDANTAI
                   AND CHOTEI_NENDO    = i_NNENDO
                   AND NENDO_BUN       = i_NNENDO_BUN
                   AND TSUCHI_NO       = i_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算退職取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 計算介護基本取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT * INTO RlKAIKIHONCAL FROM ZLBTKAI_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                   AND SANTEIDANTAI_CD = i_NDANTAI
                   AND CHOTEI_NENDO    = i_NNENDO
                   AND NENDO_BUN       = i_NNENDO_BUN
                   AND TSUCHI_NO       = i_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算介護基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 計算介護退職取得
        IF NlRTN = c_NOK AND i_NJIKKOU_KBN != c_NONL_CALZEI THEN          -- 「賦課試算」以外の場合
            BEGIN
                SELECT * INTO RlKAITAICAL FROM ZLBTKAI_TAI_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算介護退職取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 計算支援基本取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT * INTO RlSIENKIHONCAL FROM ZLBTSIEN_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                   AND SANTEIDANTAI_CD = i_NDANTAI
                   AND CHOTEI_NENDO    = i_NNENDO
                   AND NENDO_BUN       = i_NNENDO_BUN
                   AND TSUCHI_NO       = i_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算支援基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 計算支援退職取得
        IF NlRTN = c_NOK AND i_NJIKKOU_KBN != c_NONL_CALZEI THEN          -- 「賦課試算」以外の場合
            BEGIN
                SELECT * INTO RlSIENTAICAL FROM ZLBTSIEN_TAI_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算支援退職取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
-- 2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
        -- 計算子ども基本
        BEGIN
            SELECT * INTO RlKDMKIHONCAL FROM ZLBTKDM_KIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subKihonSel 計算子ども基本取得(国保世帯番号='||
                         i_NSETAI ||')'||SQLERRM;
        END;
-- 2025/08/11 ZCZL.LIUDI ADD END
    END subKihonSel;
-----------------------------------------------------------
--  履歴番号取得
-----------------------------------------------------------
FUNCTION FUNCGETR_NO(i_NKOJIN_NO IN NUMBER) RETURN NUMBER IS
  NR_NO  NUMBER;
BEGIN
    SELECT MAX(R_NO) INTO NR_NO FROM ZLBTTOKU_IDO
     WHERE KOJIN_NO = i_NKOJIN_NO
     AND KOKU_SETAI_NO = i_NSETAI;
    NR_NO := NVL(NR_NO, 0) + 1;
  RETURN NR_NO;
END FUNCGETR_NO;
-------------------------------------------------------------------------------
-- 計算異動TBL作成
-------------------------------------------------------------------------------
    PROCEDURE subIdoMake IS

        NWCNT             NUMBER;         -- 世帯数
        NTOKUKIBETSU      NUMBER;         -- 特徴期別
        NJOTAIKBN         NUMBER;         -- 状態区分
        NKOJIN_NO         NUMBER;         -- 主個人番号
        NwSYSDATE         NUMBER(8);      -- システム日付
        RTOKU_IDO_CAL ZLBTTOKU_IDO_CAL%ROWTYPE;
      BEGIN
        -- システム日付取得
        NwSYSDATE := KKBPK5551.FBATCHDATEGET;
        -- 主個人番号取得
        BEGIN
            SELECT NUSHI_KOJIN_NO INTO NKOJIN_NO FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subKihonSel 計算基本取得(国保世帯番号='||
                         i_NSETAI ||')'||SQLERRM;
        END;


        -- 特徴期別
        IF i_NTOKU_TUKI = 2 THEN
          NTOKUKIBETSU := i_NTOKU_TUKI + 9;
        ELSE
          NTOKUKIBETSU := i_NTOKU_TUKI - 3;
        END IF;
        -- 存在チェック
        SELECT COUNT(*) INTO NWCNT
          FROM ZLBTTOKU_IDO_CAL
          WHERE KOKU_SETAI_NO = i_NSETAI
          AND SYS_TANMATSU_NO = i_VTANMATSU;

        -- レコードが0件の時
        IF NWCNT = 0 THEN
            IF (i_NKEISAN_KBN = c_NKEI_CHOSEI_STP) THEN -- 計算区分＝4
              -- 計算異動テーブルにインサート
              RTOKU_IDO_CAL.KOKU_SETAI_NO        := i_NSETAI;
              RTOKU_IDO_CAL.KOJIN_NO             :=  NKOJIN_NO;
              RTOKU_IDO_CAL.R_NO                 := FUNCGETR_NO(NKOJIN_NO);
              RTOKU_IDO_CAL.KOSEI_KBN            := 2;
              RTOKU_IDO_CAL.TOKU_KIBETSU_CD      := NTOKUKIBETSU;
              RTOKU_IDO_CAL.SYORI_FLG            := 1;
              RTOKU_IDO_CAL.CHUSHI_JIYU          := i_NCHUSHI_JIYU;
              RTOKU_IDO_CAL.SYS_SAKUSEIBI        := NULL;
              RTOKU_IDO_CAL.SYS_KOSHINBI         := NULL;
              RTOKU_IDO_CAL.SYS_JIKAN            := NULL;
              RTOKU_IDO_CAL.SYS_SHOKUINKOJIN_NO  := NULL;
              RTOKU_IDO_CAL.SYS_TANMATSU_NO      := i_VTANMATSU;
              INSERT INTO ZLBTTOKU_IDO_CAL   VALUES RTOKU_IDO_CAL;

            -- バッチ処理のみ
            ELSIF i_NJIKKOU_KBN = c_NBATCH_H OR i_NJIKKOU_KBN = c_NBATCH_G THEN
                -- 計算異動テーブルにインサート
                INSERT INTO ZLBTTOKU_IDO_CAL
                  SELECT A.KOKU_SETAI_NO,
                         A.KOJIN_NO,
                         A.R_NO + 1,                  -- 履歴に1を加える
                         A.KOSEI_KBN,
                         A.TOKU_KIBETSU_CD,
                         DECODE(A.SYORI_FLG, 0, 1),   -- 処理フラグを1に変換(1固定と同義)
                         A.CHUSHI_JIYU,
                         A.SYS_SAKUSEIBI,
                         A.SYS_KOSHINBI,
                         A.SYS_JIKAN,
                         A.SYS_SHOKUINKOJIN_NO,
                         i_VTANMATSU
                  FROM ZLBTTOKU_IDO A,
                       (SELECT MAX(R_NO) AS R_NO,KOJIN_NO
                        FROM ZLBTTOKU_IDO
                        WHERE KOKU_SETAI_NO = i_NSETAI
                        GROUP BY KOJIN_NO) B
                  WHERE A.SYORI_FLG = 0
                    AND A.KOKU_SETAI_NO = i_NSETAI
                    AND A.KOJIN_NO      = B.KOJIN_NO
                    AND A.R_NO          = B.R_NO;

            END IF;
        ELSIF (i_NKEISAN_KBN = c_NKEI_CHOSEI_STP) THEN -- 既に計算特徴異動ＴＢＬ有り＆計算区分＝4
            UPDATE ZLBTTOKU_IDO_CAL                        --計算・保険料情報
              SET  KOSEI_KBN          = 2                  -- 更正区分・中止
                 , TOKU_KIBETSU_CD    = NTOKUKIBETSU       -- 特徴期別コード
                 , SYORI_FLG          = 1                  --処理フラグ
                 , CHUSHI_JIYU        = i_NCHUSHI_JIYU     -- 中止事由由
              WHERE SYORI_FLG = 0
                  AND KOKU_SETAI_NO   = i_NSETAI
                  AND KOJIN_NO        = NKOJIN_NO
                  AND SYS_TANMATSU_NO = i_VTANMATSU;
        END IF;
        -- 計算区分＝4
        IF(i_NKEISAN_KBN = c_NKEI_CHOSEI_STP OR ((i_NKEISAN_KBN = 1 OR i_NKEISAN_KBN = 3) AND FUNCTOKUGENCHK(NKOJIN_NO) = 1 AND i_NTOKU_TUKI > 0)) THEN
            BEGIN
              -- 特徴対象者情報の更新
              SELECT JOTAI_KBN
                INTO NJOTAIKBN
                FROM ZLBTTOKU_KIHON_CAL
                WHERE KOKU_SETAI_NO         = i_NSETAI           -- 世帯番号
                  AND SANTEIDANTAI_CD       = i_NDANTAI          -- 算定団体コード
                  AND TOKU_KOJIN_NO         = NKOJIN_NO          -- 個人番号
                  AND CHOTEI_NENDO          = i_NNENDO           -- 調停年度
                  AND NENDO_BUN             = i_NNENDO_BUN       -- 年度分
                  AND TSUCHI_NO             = i_NTSUCHI_NO       -- 通知書番号
                  AND SYS_TANMATSU_NO       = i_VTANMATSU        -- 更新端末番号
                ;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
              NJOTAIKBN := 0;
            END;
            IF NJOTAIKBN = 1 OR NJOTAIKBN = 2 THEN
                UPDATE ZLBTTOKU_KIHON_CAL                     --計算・保険料情報
                  SET JOTAI_KBN          = 3                  -- 処理状態・中止
                    , SHURYO_TSUKI       = i_NTOKU_TUKI       -- 特徴終了月
                    , SHURYO_KIBETSU     = NTOKUKIBETSU       -- 特徴終了期別
                    , CHUSHI_JIYU        = i_NCHUSHI_JIYU     -- 中止事由由
                    , IRAI_HIZUKE        = DECODE(i_NKOSEIBI, 0, NwSYSDATE,i_NKOSEIBI) -- 特徴依頼日(0ならシステム日付)
                  WHERE KOKU_SETAI_NO    = i_NSETAI           -- 世帯番号
                  AND SANTEIDANTAI_CD    = i_NDANTAI          -- 算定団体コード
                  AND TOKU_KOJIN_NO      = NKOJIN_NO          -- 個人番号
                  AND CHOTEI_NENDO       = i_NNENDO           -- 調停年度
                  AND NENDO_BUN          = i_NNENDO_BUN       -- 年度分
                  AND TSUCHI_NO          = i_NTSUCHI_NO       -- 通知書番号
                  AND SYS_TANMATSU_NO    = i_VTANMATSU        -- 更新端末番号
                  ;
            END IF;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subIdoMake 計算異動TBL作成(国保世帯番号='||
                     i_NSETAI||')'||SQLERRM;

    END subIdoMake;

-------------------------------------------------------------------------------
-- システム条件取得
-------------------------------------------------------------------------------
    PROCEDURE subJokenSel IS
        NwFUKI_KAZEI        ZLBTJOKEN.FUKI_KAZEI%TYPE;
        RwJOKEN             ZLBTJOKEN%ROWTYPE;
    BEGIN
        -- システム条件より不均一課税を取得(年度分)
        SELECT FUKI_KAZEI INTO NwFUKI_KAZEI FROM ZLBTJOKEN
         WHERE NENDO            = i_NNENDO_BUN
           AND SANTEIDANTAI_CD  = c_NDANTAI;
        -- 不均一課税か否か
        IF NwFUKI_KAZEI = c_NFKAZEI THEN        -- 不均一課税を行なう
            -- 算定団体コード
            NlKIWARIDANTAI_CD := i_NDANTAI;     -- ﾊﾟﾗﾒｰﾀの算定団体コード
        ELSE
            NlKIWARIDANTAI_CD := c_NDANTAI;     -- 合併後の算定団体コード
        END IF;
        -- システム条件より端数、納期区分を取得(年度分)
        SELECT * INTO RwJOKEN FROM ZLBTJOKEN
          WHERE NENDO           = i_NNENDO_BUN
            AND SANTEIDANTAI_CD = NlKIWARIDANTAI_CD;
        IF IZAN_MODE = 1 THEN
          -- 月次端数処理の保存
          -- 年税額の端数カット（医療分の条件に合わせる）
          CASE RwJOKEN.HASU_IRY
              WHEN c_NHASU_KBN_1  THEN NlCUT_COL := c_NHASU_2;       -- 100単位
              WHEN c_NHASU_KBN_2  THEN NlCUT_COL := c_NHASU_1;       -- 1000単位
              WHEN c_NHASU_KBN_3  THEN NlCUT_COL := c_NHASU_3;       -- 行なわない
              WHEN c_NHASU_KBN_10 THEN NlCUT_COL := c_NHASU_10;      -- 10単位
              ELSE NULL;
          END CASE;
          -- 期別税額の端数カット
          CASE RwJOKEN.TSUKIWARI_HASU
              WHEN c_NHASU_KBN_2  THEN NlCUT_COL_KIBETSU := c_NHASU_2;       -- 100単位
              WHEN c_NHASU_KBN_1  THEN NlCUT_COL_KIBETSU := c_NHASU_1;       -- 1000単位
              WHEN c_NHASU_KBN_3  THEN NlCUT_COL_KIBETSU := c_NHASU_3;       -- 行なわない
              WHEN c_NHASU_KBN_10 THEN NlCUT_COL_KIBETSU := c_NHASU_10;      -- 10単位
              ELSE NULL;
          END CASE;
        ELSE
          -- 月次端数処理の保存
          CASE RwJOKEN.TSUKIWARI_HASU
              WHEN c_NHASU_KBN_2  THEN NlCUT_COL := c_NHASU_2;       -- 100単位
              WHEN c_NHASU_KBN_1  THEN NlCUT_COL := c_NHASU_1;       -- 1000単位
              WHEN c_NHASU_KBN_3  THEN NlCUT_COL := c_NHASU_3;       -- 行なわない
              WHEN c_NHASU_KBN_10 THEN NlCUT_COL := c_NHASU_10;      -- 10単位
              ELSE NULL;
          END CASE;
        END IF;
        -- 納期区分の保存
        MlNOUKI(1)  := RwJOKEN.NOKI_1;      -- 納期4月
        MlNOUKI(2)  := RwJOKEN.NOKI_2;      -- 納期5月
        MlNOUKI(3)  := RwJOKEN.NOKI_3;      -- 納期6月
        MlNOUKI(4)  := RwJOKEN.NOKI_4;      -- 納期7月
        MlNOUKI(5)  := RwJOKEN.NOKI_5;      -- 納期8月
        MlNOUKI(6)  := RwJOKEN.NOKI_6;      -- 納期9月
        MlNOUKI(7)  := RwJOKEN.NOKI_7;      -- 納期10月
        MlNOUKI(8)  := RwJOKEN.NOKI_8;      -- 納期11月
        MlNOUKI(9)  := RwJOKEN.NOKI_9;      -- 納期12月
        MlNOUKI(10) := RwJOKEN.NOKI_10;     -- 納期1月
        MlNOUKI(11) := RwJOKEN.NOKI_11;     -- 納期2月
        MlNOUKI(12) := RwJOKEN.NOKI_12;     -- 納期3月
        MlNOUKI(13) := RwJOKEN.NOKI_13;     -- 納期4月
        MlNOUKI(14) := 3;                   -- 特徴1期
        MlNOUKI(15) := 0;                   -- 空
        MlNOUKI(16) := 3;                   -- 特徴3期
        MlNOUKI(17) := 0;                   -- 空
        MlNOUKI(18) := 3;                   -- 特徴5期
        MlNOUKI(19) := 0;                   -- 空
        MlNOUKI(20) := 3;                   -- 特徴7期
        MlNOUKI(21) := 0;                   -- 空
        MlNOUKI(22) := 3;                   -- 特徴10期
        MlNOUKI(23) := 0;                   -- 空
        MlNOUKI(24) := 3;                   -- 特徴12期
        -- 共通コンスタントパラメータの取得
        NlRTN := ZLBPK00010.FCPRMSHUTOKU('ZLB','00ZENSOCAL',i_NNENDO_BUN,RICTLPRM);
        MIKIWARIHOUHOU          := NVL(RwJOKEN.KIWARIHOUHOU,0);    --期割方法の条件（0:地方税法による、1:均し）
        MIKIJYUN_KIWARIGK       := NVL(RwJOKEN.KIJYUN_KIWARIGK,0); --最低期割基準額
        MIKIJYUN_TEKIYOU        := NVL(RwJOKEN.KIJYUN_TEKIYOU,0);  --最低期割基準額適用（0:なし、1:本算定のみ、2:常に適用）
--バッチ処理の場合、本算定時の処理なのか判定用
        -- 〆年月算出
        IF RwJOKEN.NOKI_1 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO) || '04') ;
        ELSIF RwJOKEN.NOKI_2 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO) || '05') ;
        ELSIF RwJOKEN.NOKI_3 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO) || '06') ;
        ELSIF RwJOKEN.NOKI_4 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO) || '07') ;
        ELSIF RwJOKEN.NOKI_5 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO) || '08') ;
        ELSIF RwJOKEN.NOKI_6 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO) || '09') ;
        ELSIF RwJOKEN.NOKI_7 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO) || '10') ;
        ELSIF RwJOKEN.NOKI_8 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO) || '11') ;
        ELSIF RwJOKEN.NOKI_9 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO) || '12') ;
        ELSIF RwJOKEN.NOKI_10 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO + 1) || '01') ;
        ELSIF RwJOKEN.NOKI_11 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO + 1) || '02') ;
        ELSIF RwJOKEN.NOKI_12 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO + 1) || '03') ;
        ELSIF RwJOKEN.NOKI_13 = c_NNOKI_HON THEN
          NlSHIME_NENGETSU  := TO_NUMBER(TO_CHAR(i_NNENDO + 1) || '04') ;
        ELSE
           NlRTN := c_NERR;
           VlMSG := 'subJokenSel システム条件取得(本算定処理月='||
                    i_NNENDO||')'||SQLERRM;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
           NlRTN := c_NERR;
           VlMSG := 'subJokenSel システム条件取得(国保世帯番号='||
                    i_NSETAI||')'||SQLERRM;
    END subJokenSel;
-------------------------------------------------------------------------------
-- 税額更正で更正後の税額が現在の期別でおさまる場合、
-- 現在期別までの期割とするか、現在期別以降にも振り付けるかを判定
-------------------------------------------------------------------------------
    PROCEDURE SUB_KIWARI_STYLE IS
      ISHICHOSON_CD   PLS_INTEGER := 0;
      CURSOR CFFJOKEN IS
        SELECT SHICHOSON_CD FROM KHSTJOKEN;
    BEGIN
      IKIWARI_STYLE := 0;
      FOR CREC IN CFFJOKEN LOOP
        ISHICHOSON_CD := CREC.SHICHOSON_CD;
        EXIT;
      END LOOP;
      IF IZAN_MODE = 1 AND ZLBPK00010.FCFFJKN2(411) = 1 THEN
        IF INOKI > 0 THEN
          IKIWARI_STYLE := 0;  --期割振り分け判定（0:現在期におさめてしまう）
        ELSE
          IKIWARI_STYLE := 1;  --期割振り分け判定（1:現在期以降も振り付け）
        END IF;
      ELSE
      -- 佐世保市を追加
      IF ISHICHOSON_CD IN (c_KIKUCHI, c_HAGI, c_UWAJIMA, c_TAMANA, c_KAMIAMA, c_YAMATO, c_DATE, c_SASEBO) THEN
        IKIWARI_STYLE := 1;  --期割振り分け判定（1:現在期以降も振り付け）
      ELSE
        IKIWARI_STYLE := 0;  --期割振り分け判定（0:現在期におさめてしまう）
      END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NlRTN := c_NERR;
        VlMSG := 'SUB_KIWARI_STYLE '||SQLERRM;
    END SUB_KIWARI_STYLE;
-------------------------------------------------------------------------------
-- 初期化
-------------------------------------------------------------------------------
    PROCEDURE subInit IS
        NwIX                NUMBER(2);
    BEGIN
        NlNENZEI            := 0;           -- 年税額
        NlGENMEN            := 0;           -- 減免額
        NlTAI_NENZEI        := 0;           -- 退年税額
        NlTAI_GENMEN        := 0;           -- 退減免額
        NlKAI_NENZEI        := 0;           -- 介護年税額
        NlKAI_TAI_NENZEI    := 0;           -- 介護退年税額
        NlNENZEI_SV         := 0;           -- 保存用年税額
        NlSAGAKU            := 0;           -- 差額
        NlTAI_SAGAKU        := 0;           -- 退差額
        NlKAI_SAGAKU        := 0;           -- 介護差額
        NlKAI_TAI_SAGAKU    := 0;           -- 介護退差額
        NlSIEN_NENZEI       := 0;           -- 支援年税額
        NlSIEN_TAI_NENZEI   := 0;           -- 支援退年税額
        NlSIEN_SAGAKU       := 0;           -- 支援差額
        NlSIEN_TAI_SAGAKU   := 0;           -- 支援退差額
        NlLOOP_FLG          := 0;
        NlCUT_COL           := 0;
        NlZO_FLG            := 0;
--  2025/08/11 ZCZL.LIUDI UPDATE START 1.1.200.000:子ども子育て支援金対応
        NlKDM_NENZEI        := 0;           -- 子ども年税額
        NlKDM_SAGAKU        := 0;           -- 子ども差額
--  2025/08/11 ZCZL.LIUDI UPDATE END
        FOR NwIX IN 1..24 LOOP
            -- 賦課期別用ワーク
            MlNOUKI(NwIX)               := 0;       -- 納期区分
            MlKIBETSU(NwIX)             := 0;       -- 期別
            MlIRY_ZEI(NwIX)             := 0;       -- 医療全体税額
            MlIRY_TAI_ZEI(NwIX)         := 0;       -- 医療退職税額
            MlKAI_ZEI(NwIX)             := 0;       -- 介護全体税額
            MlKAI_TAI_ZEI(NwIX)         := 0;       -- 介護退職税額
            MlSIEN_ZEI(NwIX)            := 0;       -- 支援全体税額
            MlSIEN_TAI_ZEI(NwIX)        := 0;       -- 支援退職税額
            MlKIZEI(NwIX)               := 0;       -- 期別税額
            MlTAI_KIZEI(NwIX)           := 0;       -- 退期別税額
            MlNUSI_KOJIN_NO(NwIX)       := 0;       -- 主個人番号
--  2025/08/11 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応
            MlKDM_ZEI(NwIX)             := 0;       -- 子ども全体税額配列
            -- 計算期別用ワーク
            MlCAL_CHOTEI_NENDO(NwIX)    := i_NNENDO;        -- 計算調定年度
            MlCAL_NENDO_BUN(NwIX)       := i_NNENDO_BUN;    -- 計算年度分
            MlCAL_TSUCHI_NO(NwIX)       := i_NTSUCHI_NO;    -- 計算通知書番号
            MlCAL_NUSI_KOJIN_NO(NwIX)   := 0;               -- 計算主個人番号
            MlCAL_ZEI(NwIX)             := 0;               -- 計算全体税額
            MlCAL_TAI_ZEI(NwIX)         := 0;               -- 計算退職税額
            MlCAL_NOUFU_KBN(NwIX)       := 0;               -- 計算納付書区分
            IF NwIX < 14 THEN   --普徴
                MlCAL_KIBETSU(NwIX)     := NwIX;             -- 計算期別
                MlKAMOKUS(NwIX)         := c_NKAMOKUS_FUTU;  -- 科目詳細コード
                MlCAL_KAMOKUS(NwIX)     := c_NKAMOKUS_FUTU;  -- 科目詳細コード
            ELSE                --特徴
                MlCAL_KIBETSU(NwIX)     := NwIX - 13;        -- 計算期別
                MlKAMOKUS(NwIX)         := c_NKAMOKUS_TOKU;  -- 科目詳細コード
                MlCAL_KAMOKUS(NwIX)     := c_NKAMOKUS_TOKU;  -- 科目詳細コード
            END IF;
        END LOOP;
    END subInit;
-------------------------------------------------------------------------------
-- 喪失予定判定、更新
-- 　後期該当による喪失の判定及び計算個人への補正を行う
-------------------------------------------------------------------------------
    FUNCTION funcSoshitsuHantei(o_IwSOSHITSU_IDX     OUT PLS_INTEGER) RETURN NUMBER IS
    --資格区分配列
    TYPE MTSHIK IS TABLE OF ZLBTKOJIN_CAL.SHIK_4%TYPE INDEX BY PLS_INTEGER;
    --個人レコード
    TYPE R_KOJIN IS RECORD
      (KOJIN_NO        ZLBTKOJIN_CAL.KOJIN_NO%TYPE,        --個人番号
       SHIK_KBN        MTSHIK,                             --資格区分配列
       SOU_IDX         PLS_INTEGER);                       --喪失月のインデックス
    --個人レコード配列（個人番号：１次元、資格区分：２次元）
    TYPE MTKOJIN IS TABLE OF R_KOJIN INDEX BY PLS_INTEGER;
    RKOJIN MTKOJIN;

    IIDX_R          PLS_INTEGER := 0;  --レコードのインデックス
    IIDX_C          PLS_INTEGER := 0;  --資格区分のインデックス
    ISOSHITSU_CNT   PLS_INTEGER := 0;  --喪失人数
    ISO_KARI_CNT    PLS_INTEGER := 0;  --仮算定期間内の喪失人数
    ISO_MAX_IDX     PLS_INTEGER := 0;  --喪失した月の最大インデックス

      -- 計算個人カーソル
      CURSOR CwSETAI IS
        SELECT KOJIN_NO,
               SHIK_4,  SHIK_5,  SHIK_6,  SHIK_7, SHIK_8, SHIK_9,
               SHIK_10, SHIK_11, SHIK_12, SHIK_1, SHIK_2, SHIK_3
          FROM ZLBTKOJIN_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NTSUCHI_NO
           AND SYS_TANMATSU_NO = i_VTANMATSU;

    BEGIN
      --出力引数クリア
      o_IwSOSHITSU_IDX := 0;
      --個人レコード配列クリア
      RKOJIN.DELETE;
      --世帯内の個人分ループ
      FOR RwSETAI IN CwSETAI LOOP
        IIDX_R := IIDX_R + 1;
        IIDX_C := 0;
        RKOJIN(IIDX_R).KOJIN_NO         := RwSETAI.KOJIN_NO;        --個人番号
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_4;          --資格４月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_5;          --資格５月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_6;          --資格６月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_7;          --資格７月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_8;          --資格８月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_9;          --資格９月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_10;         --資格10月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_11;         --資格11月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_12;         --資格12月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_1;          --資格１月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_2;          --資格２月
        IIDX_C := IIDX_C + 1;
        RKOJIN(IIDX_R).SHIK_KBN(IIDX_C) := RwSETAI.SHIK_3;          --資格３月
        RKOJIN(IIDX_R).SOU_IDX          := 0;                       --喪失月のインデックス
      END LOOP;

      --個人レコードが１件も存在しない場合はエラーを返却
      IF RKOJIN.COUNT = 0 THEN
        VlMSG := 'funcSoshitsuHantei 喪失予定判定' ||
                 '(国保世帯番号=' || i_NSETAI ||
                 ')' || '個人レコードが１件も存在しません';
        RETURN(c_NERR);
      END IF;

      --喪失予定の判定
      --全個人レコード分喪失月を取得
      FOR IDX_R IN 1..RKOJIN.LAST LOOP
        --資格区分を３月→４月の順に判定を行う
        FOR IDX_C IN REVERSE 1..12 LOOP
          --喪失月が設定された時点で以降の判定を行わない
          --喪失月のインデックスが、0：既に個人資格は喪失している、1～11：4月～2月で喪失予定、12：喪失予定なし
          IF RKOJIN(IDX_R).SOU_IDX = 0 AND RKOJIN(IDX_R).SHIK_KBN(IDX_C) IN (1, 3, 11, 13) THEN
            RKOJIN(IDX_R).SOU_IDX := IDX_C;
          END IF;
        END LOOP;
        --喪失判定
        --世帯内の喪失予定人数をカウント
        IF RKOJIN(IDX_R).SOU_IDX < 12 THEN
          ISOSHITSU_CNT := ISOSHITSU_CNT + 1;
        END IF;
        --仮算定期間内の喪失予定人数をカウント
        IF RKOJIN(IDX_R).SOU_IDX = 0 OR
          (RKOJIN(IDX_R).SOU_IDX > 0 AND           
           RKOJIN(IDX_R).SOU_IDX <= INOKI_FROM) OR 
          (RKOJIN(IDX_R).SOU_IDX >= INOKI_FROM AND
           RKOJIN(IDX_R).SOU_IDX <= INOKI_TO) THEN
          ISO_KARI_CNT := ISO_KARI_CNT + 1;
        END IF;
        --世帯内の最大喪失月インデックスを取得
        IF RKOJIN(IDX_R).SOU_IDX < 12 AND
           RKOJIN(IDX_R).SOU_IDX > ISO_MAX_IDX THEN
          ISO_MAX_IDX := RKOJIN(IDX_R).SOU_IDX;
          IF RKOJIN(IDX_R).SOU_IDX < INOKI_FROM THEN
            ISO_MAX_IDX := INOKI_FROM;
          END IF;
        END IF;
      END LOOP;

      --仮算定期間内に全喪する世帯の場合、全喪する月のインデックスをセット
      IF RKOJIN.COUNT = ISOSHITSU_CNT AND  --全喪世帯の判定
         RKOJIN.COUNT = ISO_KARI_CNT THEN  --仮算定期間内の全喪世帯の判定
        --世帯内の最大喪失月インデックスを喪失月インデックスにセット
        o_IwSOSHITSU_IDX := ISO_MAX_IDX;
      END IF;

      RETURN(c_NOK);

    EXCEPTION
      WHEN OTHERS THEN
        VlMSG := 'funcSoshitsuHantei 喪失予定判定' ||
                 '(国保世帯番号=' || i_NSETAI ||
                 ')' || SQLERRM;
        RETURN(c_NERR);
    END funcSoshitsuHantei;
-------------------------------------------------------------------------------
-- システム条件取得
-- 　仮算定期間を取得する
-------------------------------------------------------------------------------
    PROCEDURE subJokenSel2 IS

    TYPE MTNUMARRAY  IS TABLE OF NUMBER(1)  INDEX BY PLS_INTEGER;
    MINOKI              MTNUMARRAY;        -- 納期区分
    RwJOKEN             ZLBTJOKEN%ROWTYPE;

    BEGIN
        -- システム条件より納期区分を取得
        SELECT * INTO RwJOKEN FROM ZLBTJOKEN
          WHERE NENDO           = i_NNENDO
            AND SANTEIDANTAI_CD = c_NDANTAI;

        -- 納期区分の保存
        MINOKI(1)  := RwJOKEN.NOKI_1;      -- 納期4月
        MINOKI(2)  := RwJOKEN.NOKI_2;      -- 納期5月
        MINOKI(3)  := RwJOKEN.NOKI_3;      -- 納期6月
        MINOKI(4)  := RwJOKEN.NOKI_4;      -- 納期7月
        MINOKI(5)  := RwJOKEN.NOKI_5;      -- 納期8月
        MINOKI(6)  := RwJOKEN.NOKI_6;      -- 納期9月
        MINOKI(7)  := RwJOKEN.NOKI_7;      -- 納期10月
        MINOKI(8)  := RwJOKEN.NOKI_8;      -- 納期11月
        MINOKI(9)  := RwJOKEN.NOKI_9;      -- 納期12月
        MINOKI(10) := RwJOKEN.NOKI_10;     -- 納期1月
        MINOKI(11) := RwJOKEN.NOKI_11;     -- 納期2月
        MINOKI(12) := RwJOKEN.NOKI_12;     -- 納期3月

        INOKI_FROM := 0;
        INOKI_TO   := 0;
        --仮算定の開始・終了納期を取得
        FOR IDX IN 1..12 LOOP
          --最初に1が現れたインデックスを取得
          IF INOKI_FROM = 0 AND
             MINOKI(IDX) = 1 THEN
            INOKI_FROM := IDX;
          END IF;
          --最後に1が現れたインデックスを取得
          IF MINOKI(IDX) = 1 THEN
            INOKI_TO := IDX;
          END IF;
        END LOOP;
        IF INOKI_FROM = 0 OR INOKI_TO = 0 THEN
          NlRTN := c_NERR;
          VlMSG := 'subJokenSel2 システム条件取得 仮算定期間が登録されていません';
        ELSE
          --仮算定の終了納期を取得
          FOR IDX IN INOKI_FROM..INOKI_TO LOOP
            --1が連続していること
            IF MINOKI(IDX) != 1 THEN
              NlRTN := c_NERR;
              VlMSG := 'subJokenSel2 システム条件取得 仮算定期間が連続していません';
              EXIT;
            END IF;
          END LOOP;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
           NlRTN := c_NERR;
           VlMSG := 'subJokenSel2 システム条件取得 ' || SQLERRM;
    END subJokenSel2;
-------------------------------------------------------------------------------
-- メイン
-------------------------------------------------------------------------------
BEGIN
    NlRTN := 0;
    VlMSG := NULL;
    NDATE := i_NSHORIBI; --処理日

    -- 仮算定中か判定
    IF i_NJIKKOU_KBN IN (c_NONL_CALZEI, c_NONL_KIWARI, c_NONL_SOKUJI) THEN
      IF ZLBPK00010.FCFFJKN2(411) = 1 THEN
        IZAN_MODE := ZLBPK00010.FCZANMODE_ONL(i_NNENDO, i_NNENDO_BUN, i_NSHORIBI);
      ELSE
        IZAN_MODE := 0;
      END IF;
    ELSE
      IZAN_MODE := ZLBPK00010.FCZANMODE(i_NNENDO, i_NNENDO_BUN);
    END IF;
    INOKI := 0;
    -- 仮算定期間中で仮算定全喪時期割調整を行う場合
    IF IZAN_MODE = 1 AND ZLBPK00010.FCFFJKN2(421) = 1 THEN
      --システム条件取得
      subJokenSel2;
      -- 喪失予定判定、更新
      NlRTN := funcSoshitsuHantei(INOKI);
    END IF;

--  特徴中止→特徴開始の場合、
--  入力した普徴月が特徴開始10月以降の場合、9月に置換（9月までの普徴金額を作成する）
        -- 計算区分が特徴開始のとき
        NSHORIBI := i_NSHORIBI;
        IF i_NKEISAN_KBN = c_NKEI_STR_TOKU AND
           i_NTOKU_TUKI = 10               AND i_NFUTU_TUKI IN (10,11,12,1,2,3,4) THEN
           IF i_NFUTU_TUKI IN (1,2,3,4)  THEN
             NSHORIBI := i_NSHORIBI - 10000;
           END IF;
           NFUTU_TUKI := 9;
        ELSE
           NFUTU_TUKI := i_NFUTU_TUKI;
        END IF;
----- 初期処理 -----
    subInit;                        -- 初期化
    SUB_KIWARI_STYLE;               -- 期割のやり方
    subJokenSel;                    -- システム条件取得
    -- 処理範囲テーブル検索
    NlRTN := FNC_SHORI_HANI;
    -- 実行区分が賦課試算
    IF NlRTN = c_NOK AND i_NJIKKOU_KBN != c_NONL_CALZEI THEN
        subIdoMake;                 -- 計算異動テーブルの作成
    END IF;
    IF NlRTN = c_NOK THEN
        subKihonSel;                -- 計算テーブル取得
    END IF;
    IF NlRTN = c_NOK THEN
        -- 実行区分が「賦課試算」以外
        IF i_NJIKKOU_KBN != c_NONL_CALZEI THEN
            subWorkSave;            -- ワークエリア退避
        -- 実行区分が「賦課試算」
        ELSE
            subWorkSaveTS;          -- 賦課試算用 ワークエリア退避
        END IF;
    END IF;
----- 主処理 -----
    IF NlRTN = c_NOK THEN
        subMain;                    -- 主処理
    END IF;
    IF NlRTN = c_NOK THEN
        subInsert;                  -- 計算期別更新
    END IF;
----- 終了処理 -----
    IF NlRTN = c_NOK THEN           -- 正常
        BEGIN
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'COMMIT発行(国保世帯番号='||i_NSETAI||')'||SQLERRM;
        END;
    END IF;
    IF NlRTN != c_NOK THEN          -- 異常
        BEGIN
            ROLLBACK;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END IF;
    -- ログ出力
    IF NlRTN != c_NOK AND VlMSG IS NOT NULL THEN
        IF i_NJIKKOU_KBN <= c_NBATCH_G THEN    -- バッチ起動時
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCALKWFUTU', 1, '', '','ZLBSKCALKWFUTU ' || VlMSG, '', i_VTANMATSU);
        ELSIF i_NTRENBAN = -1 THEN
            -- テストの時のみ有効
            DBMS_OUTPUT.PUT_LINE('ZLBSKCALKWFUTU ' || VlMSG);
        END IF;
    END IF;
    o_NRESULT := NlRTN;
END ZLBSKCALKWFUTU;
/
