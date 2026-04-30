CREATE OR REPLACE PROCEDURE ZLBSKCALKWTKCA(i_NTSUCHI_NO      IN  NUMBER,
--1.1.200.000
                                                     i_NNENDO          IN  NUMBER,
                                                     i_NNENDO_BUN      IN  NUMBER,
                                                     i_NSHORIBI        IN  NUMBER,
                                                     i_NDANTAI         IN  NUMBER,
                                                     i_NSETAI          IN  NUMBER,
                                                     i_NJIKKOU_KBN     IN  NUMBER,
                                                     i_NTOKU_TUKI      IN  NUMBER,
                                                     i_NCHUSHI_JIYU    IN  NUMBER,
                                                     i_VTANMATSU       IN  NVARCHAR2,
                                                     i_NTRENBAN        IN  NUMBER,
                                                     o_NFUTU           OUT NUMBER,
                                                     o_NRESULT         OUT NUMBER,
                                                     i_NKOSEIBI        IN  NUMBER)
-----------------------------------------------------------
--  業務名        ZLB(国民健康保険税)
--  PG 名         ZLBSKCALKWTKCA
--  名称          計算特徴依頼取消期別作成
--  処理概要
--  引数          i_NTSUCHI_NO             通知書番号
--                i_NNENDO                 調定年度
--                i_NNENDO_BUN             年度分
--                i_NSHORIBI               処理日
--                i_NDANTAI                算定団体コード
--                i_NSETAI                 国保世帯番号(ログ出力用)
--                i_NJIKKOU_KBN            実行区分
--                i_NTOKU_TUKI             特徴月
--                i_NCHUSHI_JIYU           中止事由
--                i_VTANMATSU              端末番号
--                i_NTRENBAN               登録連番
--                o_NFUTU                  普徴期割実施区分
--                o_NRESULT                処理結果
--                i_NKOSEIBI               更正日（入力なし:システム日付、入力あり:入力値を使用）
--  作成者         ZCZL.GUORUIHUA
--  作成日         2023/08/01
--  Version       0.2.000.000
-------------------------------------------------------------------------------------
--変更履歴
--2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
--2025/08/12 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
-----------------------------------------------------------
IS
  --定数宣言
  c_IRETOK            CONSTANT PLS_INTEGER    := 0;                               -- 処理結果区分(正常)
  c_IRETNG            CONSTANT PLS_INTEGER    := 1;                               -- 処理結果区分(異常)
  c_NSTEPNO           CONSTANT NUMBER         := 99;                              -- エラーログSTEP NO

  c_NKAMOKU_CD        CONSTANT NUMBER         := 15;                              -- 科目コード
  c_NKAMOKUS_CD       CONSTANT NUMBER         := 2;                               -- 科目詳細コード(特徴)

  c_NIDO_JIYU         CONSTANT PLS_INTEGER    := 98;
  c_FOKU_KIWARI_ARI   CONSTANT NUMBER(1)      := 0;                               -- 普徴期割実行
  c_FOKU_KIWARI_NASI  CONSTANT NUMBER(1)      := 1;                               -- 普徴期割未実施
  -- 変数宣言
  IRET                            PLS_INTEGER;                                    -- 復帰値
  BRET                            BOOLEAN;                                        -- 復帰値
  VERROR                          NVARCHAR2(256);                                 -- エラーメッセージ
  NKIBETSU_GENNEN                 NUMBER;
  NKIBETSU_YOKUNEN                NUMBER;
  NTSUKI_GENNEN                   NUMBER;
  NTSUKI_YOKUNEN                  NUMBER;
  NKINGAKU_IR_ZEN_GENNEN          NUMBER;                                         -- 現年医療全体税額
  NKINGAKU_IR_ZEN_YOKUNEN         NUMBER;                                         -- 翌年医療全体税額
  NKINGAKU_IR_TAI_GENNEN          NUMBER;                                         -- 現年医療退職税額
  NKINGAKU_IR_TAI_YOKUNEN         NUMBER;                                         -- 翌年医療退職税額
  NKINGAKU_KAI_ZEN_GENNEN         NUMBER;                                         -- 現年介護全体税額
  NKINGAKU_KAI_ZEN_YOKUNEN        NUMBER;                                         -- 翌年介護全体税額
  NKINGAKU_KAI_TAI_GENNEN         NUMBER;                                         -- 現年介護退職税額
  NKINGAKU_KAI_TAI_YOKUNEN        NUMBER;                                         -- 翌年介護退職税額
  NKINGAKU_SIEN_ZEN_GENNEN        NUMBER;                                         -- 現年支援全体税額
  NKINGAKU_SIEN_ZEN_YOKUNEN       NUMBER;                                         -- 翌年支援全体税額
  NKINGAKU_SIEN_TAI_GENNEN        NUMBER;                                         -- 現年支援退職税額
  NKINGAKU_SIEN_TAI_YOKUNEN       NUMBER;                                         -- 翌年支援退職税額
  NSYSDATE                        NUMBER;                                         -- システム日付
  NYOKUNEN_FLG                    NUMBER;                                         -- 翌年度フラグ
  NGENNEN_FLG                     NUMBER;                                         -- 現年度フラグ
  NYOKUNEN_KIHON_FLG              NUMBER;                                         -- 翌年度計算基本フラグ
  NIDOJIYU                        NUMBER;                                         -- 事由
  NCNT_IDOJIYU                    NUMBER;                                         -- 事由カウント
  NTOKU_KIBETSU                   NUMBER;                                         -- 特徴期別
  NTOKU_TSUKI                     NUMBER;                                         -- 特徴月
  NIDO_CAL_SAKUSEIBI              NUMBER;                                         -- 計算異動テーブルの作成日
  --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
  --NNUSHI_KOJIN_NO                 NUMBER(12);                                     -- 世帯主個人番号
  NNUSHI_KOJIN_NO                 NUMBER;                                     -- 世帯主個人番号
  NYOKU_TSUCHI_NO                 NUMBER;                                         -- 翌年度通知番号
--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
  NKINGAKU_KDM_ZEN_GENNEN         NUMBER;                                         -- 現年子ども全体税額
  NKINGAKU_KDM_ZEN_YOKUNEN        NUMBER;                                         -- 翌年子ども全体税額
--2025/08/12 ZCZL.WANGMING ADD END

-----------------------------------------------------------
--  時間取得
-----------------------------------------------------------
FUNCTION FUNCGETTIME RETURN NVARCHAR2 IS
BEGIN
  RETURN (TO_CHAR(SYSDATE, 'HH24:MI:SS'));
END FUNCGETTIME;
-----------------------------------------------------------
--  特徴月取得
-----------------------------------------------------------
FUNCTION FUNCGETTOKUTSUKI(i_TOKUKIBETSU IN NUMBER) RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN         PLS_INTEGER;
BEGIN
  -- 特徴期別
  IF (i_TOKUKIBETSU + 3) > 12 THEN
    IRTN := i_TOKUKIBETSU - 9;
  ELSE
    IRTN := i_TOKUKIBETSU + 3;
  END IF;
  RETURN IRTN;
END FUNCGETTOKUTSUKI;
-----------------------------------------------------------
--  内部変数初期化
-----------------------------------------------------------
FUNCTION FUNC_INIT RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN   PLS_INTEGER := c_IRETOK;

BEGIN
  BEGIN
    NYOKUNEN_FLG  := 0;
    -- 異動事由
    NIDOJIYU      := -1;
    -- システム日付
    NSYSDATE := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));

    -- 世帯主個人番号取得
    SELECT MAX(NUSHI_KOJIN_NO) INTO NNUSHI_KOJIN_NO
      FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI      -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO      -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN  -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO  -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;  -- 端末番号

    -- 翌年度通知書番号取得
    SELECT YOKU_TSUCHI_NO INTO NYOKU_TSUCHI_NO
      FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI      -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO      -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN  -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO  -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;  -- 端末番号
  EXCEPTION
      WHEN OTHERS THEN
        IRTN   := c_IRETNG;
        VERROR := 'FUNC_INIT 内部変数初期化（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM;
  END;
  RETURN IRTN;
END FUNC_INIT;

-----------------------------------------------------------
--  計算基本テーブル作成
-----------------------------------------------------------
FUNCTION FUNCMAKEKIHONCAL RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN         PLS_INTEGER := c_IRETOK;
  BRTN         BOOLEAN     := TRUE;
  NwCNT_YOKU   NUMBER      := 0;

  -- 翌年度賦課基本取得
  CURSOR CKIHON IS
    SELECT * FROM  ZLBTKIHON_N
     WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO + 1     -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1 -- 年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO  -- 翌年度通知書番号
       AND NwCNT_YOKU      = 0;               -- 翌年度存在チェックフラグ

  -- 翌年度賦課介護基本取得
  CURSOR CKAI_KIHON IS
    SELECT * FROM  ZLBTKAI_KIHON_N
     WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO + 1     -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1 -- 年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO  -- 翌年度通知書番号
       AND NwCNT_YOKU      = 0;               -- 翌年度存在チェックフラグ

  -- 翌年度賦課支援基本取得
  CURSOR CSIEN_KIHON IS
    SELECT * FROM  ZLBTSIEN_KIHON_N
     WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO + 1     -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1 -- 年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO  -- 翌年度通知書番号
       AND NwCNT_YOKU      = 0;               -- 翌年度存在チェックフラグ

  -- 翌年度賦課退職取得
  CURSOR CTAI IS
    SELECT * FROM  ZLBTTAI_N
     WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO + 1     -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1 -- 年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO  -- 翌年度通知書番号
       AND NwCNT_YOKU      = 0;               -- 翌年度存在チェックフラグ

  -- 翌年度賦課介護退職取得
  CURSOR CKAI_TAI IS
    SELECT * FROM  ZLBTKAI_TAI_N
     WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO + 1     -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1 -- 年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO  -- 翌年度通知書番号
       AND NwCNT_YOKU      = 0;               -- 翌年度存在チェックフラグ

  -- 翌年度賦課支援退職取得
  CURSOR CSIEN_TAI IS
    SELECT * FROM  ZLBTSIEN_TAI_N
     WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO + 1     -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1 -- 年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO  -- 翌年度通知書番号
       AND NwCNT_YOKU      = 0;               -- 翌年度存在チェックフラグ
--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
  -- 翌年度賦課子ども基本取得
  CURSOR CKDM_KIHON IS
    SELECT * FROM  ZLBTKDM_KIHON_N
     WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO + 1     -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1 -- 年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO  -- 翌年度通知書番号
       AND NwCNT_YOKU      = 0;               -- 翌年度存在チェックフラグ
--2025/08/12 ZCZL.WANGMING ADD END

BEGIN
  BEGIN

   -- 翌年度データ存在チェック
   -- 計算テーブルに翌年度のデータがない場合は賦課から計算へコピーを行う
   SELECT COUNT(*) INTO NwCNT_YOKU FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO + 1     -- 翌調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1 -- 翌年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO  -- 翌年度通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;     -- 端末番号

    -- 翌年度計算基本テーブル作成
    FOR CRKIHON IN CKIHON LOOP
      CRKIHON.R_NO            := CRKIHON.R_NO + 10;
      CRKIHON.SYS_TANMATSU_NO := i_VTANMATSU;
      INSERT INTO ZLBTKIHON_CAL VALUES CRKIHON;
    END LOOP;

    -- 翌年度計算介護基本テーブル作成
    FOR CRKAI_KIHON IN CKAI_KIHON LOOP
      CRKAI_KIHON.R_NO            := CRKAI_KIHON.R_NO + 10;
      CRKAI_KIHON.SYS_TANMATSU_NO := i_VTANMATSU;
      INSERT INTO ZLBTKAI_KIHON_CAL VALUES CRKAI_KIHON;
    END LOOP;

    -- 翌年度計算支援基本テーブル作成
    FOR CRSIEN_KIHON IN CSIEN_KIHON LOOP
      CRSIEN_KIHON.R_NO            := CRSIEN_KIHON.R_NO + 10;
      CRSIEN_KIHON.SYS_TANMATSU_NO := i_VTANMATSU;
      INSERT INTO ZLBTSIEN_KIHON_CAL VALUES CRSIEN_KIHON;
    END LOOP;

    -- 翌年度計算退職テーブル作成
    FOR CRTAI IN CTAI LOOP
      CRTAI.R_NO            := CRTAI.R_NO + 10;
      CRTAI.SYS_TANMATSU_NO := i_VTANMATSU;
      INSERT INTO ZLBTTAI_CAL VALUES CRTAI;
    END LOOP;

    -- 翌年度計算介護退職テーブル作成
    FOR CRKAI_TAI IN CKAI_TAI LOOP
      CRKAI_TAI.R_NO            := CRKAI_TAI.R_NO + 10;
      CRKAI_TAI.SYS_TANMATSU_NO := i_VTANMATSU;
      INSERT INTO ZLBTKAI_TAI_CAL VALUES CRKAI_TAI;
    END LOOP;

    -- 翌年度計算支援退職テーブル作成
    FOR CRSIEN_TAI IN CSIEN_TAI LOOP
      CRSIEN_TAI.R_NO            := CRSIEN_TAI.R_NO + 10;
      CRSIEN_TAI.SYS_TANMATSU_NO := i_VTANMATSU;
      INSERT INTO ZLBTSIEN_TAI_CAL VALUES CRSIEN_TAI;
    END LOOP;
--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
    --  翌年度計算子ども基本テーブル作成
    FOR CRKDM_KIHON IN CKDM_KIHON LOOP
      CRKDM_KIHON.R_NO            := CRKDM_KIHON.R_NO + 10;
      CRKDM_KIHON.SYS_TANMATSU_NO := i_VTANMATSU;
      INSERT INTO ZLBTKDM_KIHON_CAL VALUES CRKDM_KIHON;
    END LOOP;
--2025/08/12 ZCZL.WANGMING ADD END

    -- 翌年度データ有無フラグ取得
    -- 翌年度計算基本変更チェックに使用
    SELECT COUNT(R_NO) INTO NYOKUNEN_KIHON_FLG
      FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO + 1     -- 翌調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1 -- 翌年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO  -- 翌年度通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;     -- 端末番号

  EXCEPTION
    WHEN OTHERS THEN
      IRTN   := c_IRETNG;
      VERROR := 'FUNCMAKEKIHONCAL 計算基本テーブル作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM;
  END;
  RETURN IRTN;
END FUNCMAKEKIHONCAL;

-----------------------------------------------------------
--  計算期別テーブル作成
-----------------------------------------------------------
FUNCTION FUNCMAKEKIBETSUCAL RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN         PLS_INTEGER := c_IRETOK;
  BRTN         BOOLEAN     := TRUE;
  NwCNT_GEN    NUMBER      := 0;
  NwCNT_YOKU   NUMBER      := 0;

  CURSOR CKIBETSU IS
    SELECT * FROM  ZLBTKIBETSU_N
     WHERE KAMOKU_CD       = c_NKAMOKU_CD        -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD       -- 科目詳細コード
       AND KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
       AND ((NwCNT_GEN     = 0                   -- 現年度存在チェックフラグ
         AND CHOTEINENDO   = i_NNENDO            -- 調停年度
         AND NENDOBUN      = i_NNENDO_BUN        -- 年度分
         AND TSUCHI_NO     = i_NTSUCHI_NO)       -- 通知書番号
        OR  (NwCNT_YOKU    = 0                   -- 翌年度存在チェックフラグ
         AND CHOTEINENDO   = i_NNENDO + 1        -- 翌調停年度
         AND NENDOBUN      = i_NNENDO_BUN + 1    -- 翌年度分
         AND TSUCHI_NO     = NYOKU_TSUCHI_NO));  -- 翌年度通知書番号

BEGIN
  BEGIN

   -- 現年度データ存在チェック
   -- 計算テーブルに現年度のデータがない場合は賦課から計算へコピーを行う
   SELECT COUNT(*) INTO NwCNT_GEN FROM ZLBTKIBETSU_CAL
     WHERE KAMOKU_CD       = c_NKAMOKU_CD    -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD   -- 科目詳細コード
       AND KOKU_SETAI_NO   = i_NSETAI        -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
       AND CHOTEINENDO     = i_NNENDO        -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN    -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO    -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;    -- 端末番号

   -- 翌年度データ存在チェック
   -- 計算テーブルに翌年度のデータがない場合は賦課から計算へコピーを行う
   SELECT COUNT(*) INTO NwCNT_YOKU FROM ZLBTKIBETSU_CAL
     WHERE KAMOKU_CD        = c_NKAMOKU_CD       -- 科目コード
       AND KAMOKUS_CD       = c_NKAMOKUS_CD      -- 科目詳細コード
       AND KOKU_SETAI_NO    = i_NSETAI           -- 国保世帯番号
       AND SANTEIDANTAI_CD  = i_NDANTAI          -- 算定団体コード
       AND CHOTEINENDO      = i_NNENDO + 1       -- 翌調停年度
       AND NENDOBUN         = i_NNENDO_BUN + 1   -- 翌年度分
       AND TSUCHI_NO        = NYOKU_TSUCHI_NO    -- 翌年度通知書番号
       AND SYS_TANMATSU_NO  = i_VTANMATSU;       -- 端末番号

    -- 現年・翌年度計算期別テーブル作成
    FOR CRKIBETSU IN CKIBETSU LOOP
      CRKIBETSU.R_NO            := CRKIBETSU.R_NO + 10;
      CRKIBETSU.SYS_TANMATSU_NO := i_VTANMATSU;
      INSERT INTO ZLBTKIBETSU_CAL VALUES CRKIBETSU;
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      IRTN   := c_IRETNG;
      VERROR := 'FUNCMAKEKIBETSUCAL 計算期別テーブル作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM;
  END;
  RETURN IRTN;
END FUNCMAKEKIBETSUCAL;
-----------------------------------------------------------
--  計算期別更新
-----------------------------------------------------------
FUNCTION FUNCKINGAKUCLEAR RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN         PLS_INTEGER := c_IRETOK;
  BRTN         BOOLEAN     := TRUE;

BEGIN
  -- 0円クリアする開始期を設定する。
  IF i_NTOKU_TUKI = 10 THEN       -- 特徴中止月が１０月(７期)の場合
     NKIBETSU_GENNEN  := 7;
     NTSUKI_GENNEN    := 10;
     NKIBETSU_YOKUNEN := 1;
     NTSUKI_YOKUNEN   := 4;
  ELSIF i_NTOKU_TUKI = 12 THEN    -- 特徴中止月が１２月(９期)の場合
     NKIBETSU_GENNEN  := 9;
     NTSUKI_GENNEN    := 12;
     NKIBETSU_YOKUNEN := 1;
     NTSUKI_YOKUNEN   := 4;
  ELSIF i_NTOKU_TUKI = 2 THEN     -- 特徴中止月が２月(１１期)の場合
     NKIBETSU_GENNEN  := 11;
     NTSUKI_GENNEN    := 2;
     NKIBETSU_YOKUNEN := 1;
     NTSUKI_YOKUNEN   := 4;
  ELSIF i_NTOKU_TUKI = 4 THEN     -- 特徴中止月が４月(１期)の場合
     NKIBETSU_GENNEN  := 1;
     NTSUKI_GENNEN    := 4;
     NKIBETSU_YOKUNEN := 0;
     NTSUKI_YOKUNEN   := 0;
  ELSIF i_NTOKU_TUKI = 104 THEN   -- 特徴中止月が翌４月(１期)の場合
     NKIBETSU_GENNEN  := 0;
     NTSUKI_GENNEN    := 0;
     NKIBETSU_YOKUNEN := 1;
     NTSUKI_YOKUNEN   := 4;
  ELSIF i_NTOKU_TUKI = 6 THEN     -- 特徴中止月が６月(３期)の場合
     NKIBETSU_GENNEN  := 3;
     NTSUKI_GENNEN    := 6;
     NKIBETSU_YOKUNEN := 1;
     NTSUKI_YOKUNEN   := 4;
  ELSIF i_NTOKU_TUKI = 106 THEN   -- 特徴中止月が翌６月(３期)の場合
     NKIBETSU_GENNEN  := 0;
     NTSUKI_GENNEN    := 0;
     NKIBETSU_YOKUNEN := 3;
     NTSUKI_YOKUNEN   := 6;
  ELSIF i_NTOKU_TUKI = 8 THEN     -- 特徴中止月が８月(５期)の場合
     NKIBETSU_GENNEN  := 5;
     NTSUKI_GENNEN    := 8;
     NKIBETSU_YOKUNEN := 1;
     NTSUKI_YOKUNEN   := 4;
  END IF;

  BEGIN
    IF NKIBETSU_GENNEN > 0 THEN
      -- 期別情報より差額算出 ※現年度
      SELECT SUM(IR_ZEN_ZEIGAKU),      SUM(IR_TAI_ZEIGAKU),
             SUM(KAI_ZEN_ZEIGAKU),     SUM(KAI_TAI_ZEIGAKU),
             SUM(SIEN_ZEN_ZEIGAKU),    SUM(SIEN_TAI_ZEIGAKU)
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
            ,SUM(KDM_ZEN_ZEIGAKU)
        INTO NKINGAKU_IR_ZEN_GENNEN,   NKINGAKU_IR_TAI_GENNEN,
             NKINGAKU_KAI_ZEN_GENNEN,  NKINGAKU_KAI_TAI_GENNEN,
             NKINGAKU_SIEN_ZEN_GENNEN, NKINGAKU_SIEN_TAI_GENNEN
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
            ,NKINGAKU_KDM_ZEN_GENNEN
        FROM ZLBTKIBETSU_CAL                        -- 計算期別情報
       WHERE KAMOKU_CD        = c_NKAMOKU_CD        -- 科目コード
         AND KAMOKUS_CD       = c_NKAMOKUS_CD       -- 科目詳細コード・特徴
         AND KOKU_SETAI_NO    = i_NSETAI            -- 世帯番号
         AND SANTEIDANTAI_CD  = i_NDANTAI           -- 算定団体コード
         AND CHOTEINENDO      = i_NNENDO            -- 調定年度
         AND NENDOBUN         = i_NNENDO_BUN        -- 年度分
         AND TSUCHI_NO        = i_NTSUCHI_NO        -- 通知番号
         AND SYS_TANMATSU_NO  = i_VTANMATSU         -- 端末番号
         AND RONRIKIBETSU    >=  NKIBETSU_GENNEN    -- 論理期別
      ;
      -- 期別情報0円クリア ※現年分
      UPDATE ZLBTKIBETSU_CAL                        --計算・期別情報
         SET ZEN_ZEIGAKU      = 0, TAI_ZEIGAKU      = 0,
             IR_ZEN_ZEIGAKU   = 0, IR_TAI_ZEIGAKU   = 0,
             KAI_ZEN_ZEIGAKU  = 0, KAI_TAI_ZEIGAKU  = 0,
             SIEN_ZEN_ZEIGAKU = 0, SIEN_TAI_ZEIGAKU = 0
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
            ,KDM_ZEN_ZEIGAKU = 0
       WHERE KAMOKU_CD        = c_NKAMOKU_CD        -- 科目コード
         AND KAMOKUS_CD       = c_NKAMOKUS_CD       -- 科目詳細コード・特徴
         AND KOKU_SETAI_NO    = i_NSETAI            -- 世帯番号
         AND SANTEIDANTAI_CD  = i_NDANTAI           -- 算定団体コード
         AND CHOTEINENDO      = i_NNENDO            -- 調定年度
         AND NENDOBUN         = i_NNENDO_BUN        -- 年度分
         AND TSUCHI_NO        = i_NTSUCHI_NO        -- 通知番号
         AND SYS_TANMATSU_NO  = i_VTANMATSU         -- 端末番号
         AND RONRIKIBETSU    >=  NKIBETSU_GENNEN    -- 論理期別-- 論理期別
      ;
    END IF;

    IF NKIBETSU_YOKUNEN > 0 THEN
      -- 期別情報より差額算出 ※翌年度
      SELECT SUM(IR_ZEN_ZEIGAKU),       SUM(IR_TAI_ZEIGAKU),
             SUM(KAI_ZEN_ZEIGAKU),      SUM(KAI_TAI_ZEIGAKU),
             SUM(SIEN_ZEN_ZEIGAKU),     SUM(SIEN_TAI_ZEIGAKU)
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
            ,SUM(KDM_ZEN_ZEIGAKU)
        INTO NKINGAKU_IR_ZEN_YOKUNEN,   NKINGAKU_IR_TAI_YOKUNEN,
             NKINGAKU_KAI_ZEN_YOKUNEN,  NKINGAKU_KAI_TAI_YOKUNEN,
             NKINGAKU_SIEN_ZEN_YOKUNEN, NKINGAKU_SIEN_TAI_YOKUNEN
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
            ,NKINGAKU_KDM_ZEN_YOKUNEN
        FROM ZLBTKIBETSU_CAL                        -- 計算期別情報
       WHERE KAMOKU_CD        = c_NKAMOKU_CD        -- 科目コード
         AND KAMOKUS_CD       = c_NKAMOKUS_CD       -- 科目詳細コード・特徴
         AND KOKU_SETAI_NO    = i_NSETAI            -- 世帯番号
         AND SANTEIDANTAI_CD  = i_NDANTAI           -- 算定団体コード
         AND CHOTEINENDO      = (i_NNENDO + 1)      -- 調定年度
         AND NENDOBUN         = (i_NNENDO_BUN + 1)  -- 年度分
         AND TSUCHI_NO        = NYOKU_TSUCHI_NO     -- 通知番号
         AND SYS_TANMATSU_NO  = i_VTANMATSU         -- 端末番号
         AND RONRIKIBETSU    >=  NKIBETSU_YOKUNEN   -- 論理期別-- 論理期別
      ;
      -- 期別情報0円クリア ※翌年分
      UPDATE ZLBTKIBETSU_CAL
         SET ZEN_ZEIGAKU      = 0, TAI_ZEIGAKU      = 0,
             IR_ZEN_ZEIGAKU   = 0, IR_TAI_ZEIGAKU   = 0,
             KAI_ZEN_ZEIGAKU  = 0, KAI_TAI_ZEIGAKU  = 0,
             SIEN_ZEN_ZEIGAKU = 0, SIEN_TAI_ZEIGAKU = 0
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
            ,KDM_ZEN_ZEIGAKU = 0
       WHERE KAMOKU_CD        = c_NKAMOKU_CD        -- 科目コード
         AND KAMOKUS_CD       = c_NKAMOKUS_CD       -- 科目詳細コード・特徴
         AND KOKU_SETAI_NO    = i_NSETAI            -- 世帯番号
         AND SANTEIDANTAI_CD  = i_NDANTAI           -- 算定団体コード
         AND CHOTEINENDO      = (i_NNENDO + 1)      -- 調定年度
         AND NENDOBUN         = (i_NNENDO_BUN + 1)  -- 年度分
         AND TSUCHI_NO        = NYOKU_TSUCHI_NO     -- 通知番号
         AND SYS_TANMATSU_NO  = i_VTANMATSU         -- 端末番号
         AND RONRIKIBETSU    >=  NKIBETSU_YOKUNEN   -- 論理期別-- 論理期別
      ;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IRTN   := c_IRETNG;
      VERROR := 'FUNCKINGAKUCLEAR 計算期別更新（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM;
  END;
  RETURN IRTN;
END FUNCKINGAKUCLEAR;
-----------------------------------------------------------
--  計算異動テーブル作成
-----------------------------------------------------------
FUNCTION FUNCMAKEIDOCAL RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN            PLS_INTEGER := c_IRETOK;
  BRTN            BOOLEAN     := TRUE;
  NTOKU           NUMBER;
  NR_NO           NUMBER(3) := -1;
  NCOUNT          NUMBER;
  RTOKUIDOCAL     ZLBTTOKU_IDO_CAL%ROWTYPE;

BEGIN
  BEGIN
    -- 特徴異動データ存在チェック
    SELECT COUNT(KOJIN_NO) INTO NCOUNT
      FROM ZLBTTOKU_IDO
     WHERE SYORI_FLG     = 1                     -- 処理フラグ
       AND KOKU_SETAI_NO = i_NSETAI              -- 国保世帯番号
       AND KOJIN_NO      = NNUSHI_KOJIN_NO       -- 主個人番号
       AND R_NO = (SELECT MAX(R_NO) FROM ZLBTTOKU_IDO
                    WHERE SYORI_FLG     = 1                 -- 処理フラグ
                      AND KOKU_SETAI_NO = i_NSETAI          -- 国保世帯番号
                      AND KOJIN_NO      = NNUSHI_KOJIN_NO); -- 主個人番号
    IF NCOUNT > 0 THEN
      -- 特徴異動データ取得
      SELECT * INTO RTOKUIDOCAL
        FROM ZLBTTOKU_IDO
       WHERE SYORI_FLG     = 1                   -- 処理フラグ
         AND KOKU_SETAI_NO = i_NSETAI            -- 国保世帯番号
         AND KOJIN_NO      = NNUSHI_KOJIN_NO     -- 主個人番号
         AND R_NO = (SELECT MAX(R_NO) FROM ZLBTTOKU_IDO
                      WHERE SYORI_FLG     = 1                 -- 処理フラグ
                        AND KOKU_SETAI_NO = i_NSETAI          -- 国保世帯番号
                        AND KOJIN_NO      = NNUSHI_KOJIN_NO); -- 主個人番号

      RTOKUIDOCAL.R_NO        := RTOKUIDOCAL.R_NO + 1;  -- 履歴番号 + 1
      RTOKUIDOCAL.CHUSHI_JIYU := i_NCHUSHI_JIYU;        -- 中止事由
      RTOKUIDOCAL.KOSEI_KBN   := 1;                     -- 処理済フラグ
      RTOKUIDOCAL.SYS_TANMATSU_NO := i_VTANMATSU;       -- 端末番号

      -- 計算特徴異動テーブル削除
      DELETE FROM ZLBTTOKU_IDO_CAL
       WHERE KOKU_SETAI_NO   = RTOKUIDOCAL.KOKU_SETAI_NO -- 国保世帯番号
         AND KOJIN_NO        = RTOKUIDOCAL.KOJIN_NO      -- 個人番号
         AND R_NO            = RTOKUIDOCAL.R_NO + 1      -- 履歴番号
         AND SYS_TANMATSU_NO = i_VTANMATSU;              -- 端末番号
      -- 計算特徴異動テーブル作成
      INSERT INTO ZLBTTOKU_IDO_CAL VALUES RTOKUIDOCAL;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IRTN   := c_IRETNG;
      VERROR := 'FUNCMAKEIDOCAL 計算異動テーブル作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM;
  END;
  RETURN IRTN;
END FUNCMAKEIDOCAL;
-----------------------------------------------------------
--  計算特徴対象者テーブル作成
-----------------------------------------------------------
PROCEDURE PROCTOKUKIHONCAL(i_NMAKENENDO     IN NUMBER,
                           i_NMAKENENDO_BUN IN NUMBER,
                           i_NSYURYOTSUKI   IN NUMBER,
                           i_NSYURYOKIBETSU IN NUMBER
                          ) IS
  -- 変数宣言
  IRTN                 PLS_INTEGER := c_IRETOK;
  BRTN                 BOOLEAN     := TRUE;

  -- 賦課特徴対象者データ取得
  CURSOR CTOKUKIHON IS
    SELECT *
      FROM ZLBTTOKU_KIHON_N
     WHERE KOKU_SETAI_NO   = i_NSETAI          -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI         -- 算定団体コード
       AND CHOTEI_NENDO    = i_NMAKENENDO      -- 調定年度
       AND NENDO_BUN       = i_NMAKENENDO_BUN  -- 年度分
       -- 現年度も翌年度も処理されるため通知書番号の分岐を行う
       AND TSUCHI_NO       = (CASE i_NMAKENENDO WHEN i_NNENDO THEN i_NTSUCHI_NO ELSE NYOKU_TSUCHI_NO END);

BEGIN
  BEGIN
    FOR CRTOKUKIHON IN CTOKUKIHON LOOP
      CRTOKUKIHON.R_NO                 := CRTOKUKIHON.R_NO + 10;  -- 履歴番号
      CRTOKUKIHON.JOTAI_KBN            := 3;                 -- 特徴状態
      CRTOKUKIHON.SHURYO_TSUKI         := i_NSYURYOTSUKI;    -- 特徴終了月
      CRTOKUKIHON.SHURYO_KIBETSU       := i_NSYURYOKIBETSU;  -- 特徴終了期別
      CRTOKUKIHON.CHUSHI_JIYU          := i_NCHUSHI_JIYU;    -- 特徴中止事由
      CRTOKUKIHON.IRAI_HIZUKE          := NSYSDATE;          -- 依頼日
      CRTOKUKIHON.SYS_SAKUSEIBI        := NULL;              -- システム作成日
      CRTOKUKIHON.SYS_KOSHINBI         := NULL;              -- システム更新日
      CRTOKUKIHON.SYS_JIKAN            := NULL;              -- システム更新時間
      CRTOKUKIHON.SYS_SHOKUINKOJIN_NO  := NULL;              -- システム更新職員個人番号
      CRTOKUKIHON.SYS_TANMATSU_NO      := i_VTANMATSU;       -- 更新端末番号

      -- 特徴対象者削除
      DELETE FROM ZLBTTOKU_KIHON_CAL
       WHERE KOKU_SETAI_NO   = i_NSETAI           -- 国保世帯番号
         AND SANTEIDANTAI_CD = i_NDANTAI          -- 算定団体コード
         AND CHOTEI_NENDO    = i_NMAKENENDO       -- 調定年度
         AND NENDO_BUN       = i_NMAKENENDO_BUN   -- 年度分
         -- 現年度も翌年度も処理されるため通知書番号の分岐を行う
         AND TSUCHI_NO       = (CASE i_NMAKENENDO WHEN i_NNENDO THEN i_NTSUCHI_NO ELSE NYOKU_TSUCHI_NO END)
         AND SYS_TANMATSU_NO = i_VTANMATSU;       -- 端末番号

      INSERT INTO ZLBTTOKU_KIHON_CAL VALUES CRTOKUKIHON;
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      IRTN   := c_IRETNG;
      VERROR := 'PROCTOKUKIHONCAL 計算特徴対象者テーブル作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM;
  END;
END PROCTOKUKIHONCAL;
-----------------------------------------------------------
--  計算特徴対象者テーブル作成（現年／翌年区分処理）
-----------------------------------------------------------
FUNCTION FUNCMAKETOKUKIHONCAL RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN                 PLS_INTEGER := c_IRETOK;
  BRTN                 BOOLEAN     := TRUE;

BEGIN
  BEGIN
    -- 特徴対象者データ作成設定
    -- 特徴月が104月又は106月の場合は翌年度分のみデータ作成
    IF i_NTOKU_TUKI = 104 OR i_NTOKU_TUKI = 106 THEN
      NGENNEN_FLG  := 0;
      NYOKUNEN_FLG := 1;
    -- 特徴月が10月、12月、2月、6月、8月の場合は現年度・翌年度分データ作成
    ELSIF i_NTOKU_TUKI = 10 OR i_NTOKU_TUKI = 12 OR i_NTOKU_TUKI = 2
       OR i_NTOKU_TUKI = 6 OR i_NTOKU_TUKI = 8 THEN
      NGENNEN_FLG  := 1;
      NYOKUNEN_FLG := 1;
    -- 特徴月が4月の場合は現年度分のみデータ作成
    ELSIF i_NTOKU_TUKI = 4 THEN
      NGENNEN_FLG  := 1;
      NYOKUNEN_FLG := 0;
    END IF;

    IF NGENNEN_FLG = 1 THEN
      -- 現年度特徴対象者データ作成
      PROCTOKUKIHONCAL(i_NNENDO, i_NNENDO_BUN, NTSUKI_GENNEN, NKIBETSU_GENNEN);
    END IF;
    IF NYOKUNEN_FLG = 1 THEN
      -- 翌年度特徴対象者データ作成
      PROCTOKUKIHONCAL(i_NNENDO + 1, i_NNENDO_BUN + 1, NTSUKI_YOKUNEN, NKIBETSU_YOKUNEN);
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IRTN   := c_IRETNG;
      VERROR := 'FUNCMAKETOKUKIHONCAL 計算特徴対象者テーブル作成（現年／翌年区分処理）（国保世帯番号='
                || i_NSETAI ||'）エラーが発生しました';
  END;
  RETURN IRTN;
END FUNCMAKETOKUKIHONCAL;
-----------------------------------------------------------
--  現年計算基本情報更新
-----------------------------------------------------------
FUNCTION FUNCUPDATEKIHONCALGEN RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN           PLS_INTEGER := c_IRETOK;
  BRTN           BOOLEAN     := TRUE;
  NKINTO_WARI                NUMBER;                                -- 均等割額
  NSEKISAN                   NUMBER;                                -- 積算税額
  NNENZEI                    NUMBER;                                -- 年税額

BEGIN
  BEGIN
    -- 計算基本更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_IR_ZEN_GENNEN != 0 THEN
       UPDATE ZLBTKIHON_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_IR_ZEN_GENNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_IR_ZEN_GENNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_IR_ZEN_GENNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
          AND CHOTEI_NENDO    = i_NNENDO            -- 調定年度
          AND NENDO_BUN       = i_NNENDO_BUN        -- 年度分
          AND TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;        -- 端末番号
    END IF;

    -- 計算介護基本更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_KAI_ZEN_GENNEN != 0 THEN
       UPDATE ZLBTKAI_KIHON_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_KAI_ZEN_GENNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_KAI_ZEN_GENNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_KAI_ZEN_GENNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
          AND CHOTEI_NENDO    = i_NNENDO            -- 調定年度
          AND NENDO_BUN       = i_NNENDO_BUN        -- 年度分
          AND TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;        -- 端末番号
    END IF;

    -- 計算支援基本更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_SIEN_ZEN_GENNEN != 0 THEN
       UPDATE ZLBTSIEN_KIHON_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_SIEN_ZEN_GENNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_SIEN_ZEN_GENNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_SIEN_ZEN_GENNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
          AND CHOTEI_NENDO    = i_NNENDO            -- 調定年度
          AND NENDO_BUN       = i_NNENDO_BUN        -- 年度分
          AND TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;        -- 端末番号
    END IF;

    -- 計算退職更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_IR_TAI_GENNEN != 0 THEN
       UPDATE ZLBTTAI_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_IR_TAI_GENNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_IR_TAI_GENNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_IR_TAI_GENNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
          AND CHOTEI_NENDO    = i_NNENDO            -- 調定年度
          AND NENDO_BUN       = i_NNENDO_BUN        -- 年度分
          AND TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;        -- 端末番号
    END IF;

    -- 計算介護退職更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_KAI_TAI_GENNEN != 0 THEN
       UPDATE ZLBTKAI_TAI_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_KAI_TAI_GENNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_KAI_TAI_GENNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_KAI_TAI_GENNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
          AND CHOTEI_NENDO    = i_NNENDO            -- 調定年度
          AND NENDO_BUN       = i_NNENDO_BUN        -- 年度分
          AND TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;        -- 端末番号
    END IF;

    -- 計算支援退職更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_SIEN_TAI_GENNEN != 0 THEN
       UPDATE ZLBTSIEN_TAI_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_SIEN_TAI_GENNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_SIEN_TAI_GENNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_SIEN_TAI_GENNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
          AND CHOTEI_NENDO    = i_NNENDO            -- 調定年度
          AND NENDO_BUN       = i_NNENDO_BUN        -- 年度分
          AND TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;        -- 端末番号
    END IF;
--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
    -- 計算子ども基本更新
    IF NKINGAKU_KDM_ZEN_GENNEN != 0 THEN
       UPDATE ZLBTKDM_KIHON_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_KDM_ZEN_GENNEN, -- 均等割額 - 変数.現年子ども全体税額
              SEKISAN    = SEKISAN    - NKINGAKU_KDM_ZEN_GENNEN, -- 積算税額 - 変数.現年子ども全体税額
              NENZEI     = NENZEI     - NKINGAKU_KDM_ZEN_GENNEN  -- 年税額   - 変数.現年子ども全体税額
        WHERE KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
          AND CHOTEI_NENDO    = i_NNENDO            -- 調定年度
          AND NENDO_BUN       = i_NNENDO_BUN        -- 年度分
          AND TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;        -- 端末番号
    END IF;
--2025/08/12 ZCZL.WANGMING ADD END

  EXCEPTION
    WHEN OTHERS THEN
      IRTN   := c_IRETNG;
      VERROR := 'FUNCUPDATEKIHONCALGEN 現年計算基本情報更新（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM;
  END;
  RETURN IRTN;
END FUNCUPDATEKIHONCALGEN;
-----------------------------------------------------------
--  翌年計算基本情報更新
-----------------------------------------------------------
FUNCTION FUNCUPDATEKIHONCALYOKU RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN                       PLS_INTEGER := c_IRETOK;
  BRTN                       BOOLEAN     := TRUE;
  NKINTO_WARI                NUMBER;                                -- 均等割額
  NSEKISAN                   NUMBER;                                -- 積算税額
  NNENZEI                    NUMBER;                                -- 年税額

BEGIN
  BEGIN
    -- 計算翌年度基本更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_IR_ZEN_YOKUNEN != 0 THEN
       UPDATE ZLBTKIHON_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_IR_ZEN_YOKUNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_IR_ZEN_YOKUNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_IR_ZEN_YOKUNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI                   -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI                  -- 算定団体コード
          AND CHOTEI_NENDO    = (i_NNENDO + 1)             -- 翌調定年度
          AND NENDO_BUN       = (i_NNENDO_BUN + 1)         -- 翌年度分
          AND TSUCHI_NO       = NYOKU_TSUCHI_NO            -- 翌年度通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;               -- 端末番号
    END IF;

    -- 計算翌年度介護基本更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_KAI_ZEN_YOKUNEN != 0 THEN
       UPDATE ZLBTKAI_KIHON_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_KAI_ZEN_YOKUNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_KAI_ZEN_YOKUNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_KAI_ZEN_YOKUNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI                   -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI                  -- 算定団体コード
          AND CHOTEI_NENDO    = (i_NNENDO + 1)             -- 翌調定年度
          AND NENDO_BUN       = (i_NNENDO_BUN + 1)         -- 翌年度分
          AND TSUCHI_NO       = NYOKU_TSUCHI_NO            -- 翌年度通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;               -- 端末番号
    END IF;

    -- 計算翌年度支援基本更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_SIEN_ZEN_YOKUNEN != 0 THEN
       UPDATE ZLBTSIEN_KIHON_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_SIEN_ZEN_YOKUNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_SIEN_ZEN_YOKUNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_SIEN_ZEN_YOKUNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI                   -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI                  -- 算定団体コード
          AND CHOTEI_NENDO    = (i_NNENDO + 1)             -- 翌調定年度
          AND NENDO_BUN       = (i_NNENDO_BUN + 1)         -- 翌年度分
          AND TSUCHI_NO       = NYOKU_TSUCHI_NO            -- 翌年度通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;               -- 端末番号
    END IF;

    -- 計算翌年度退職更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_IR_TAI_YOKUNEN != 0 THEN
       UPDATE ZLBTTAI_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_IR_TAI_YOKUNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_IR_TAI_YOKUNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_IR_TAI_YOKUNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI                   -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI                  -- 算定団体コード
          AND CHOTEI_NENDO    = (i_NNENDO + 1)             -- 翌調定年度
          AND NENDO_BUN       = (i_NNENDO_BUN + 1)         -- 翌年度分
          AND TSUCHI_NO       = NYOKU_TSUCHI_NO            -- 翌年度通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;               -- 端末番号
    END IF;

    -- 計算翌年度介護退職更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_KAI_TAI_YOKUNEN != 0 THEN
       UPDATE ZLBTKAI_TAI_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_KAI_TAI_YOKUNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_KAI_TAI_YOKUNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_KAI_TAI_YOKUNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI                   -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI                  -- 算定団体コード
          AND CHOTEI_NENDO    = (i_NNENDO + 1)             -- 翌調定年度
          AND NENDO_BUN       = (i_NNENDO_BUN + 1)         -- 翌年度分
          AND TSUCHI_NO       = NYOKU_TSUCHI_NO            -- 翌年度通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;               -- 端末番号
    END IF;

    -- 計算翌年度支援退職更新
    -- 差額がない場合は更新処理を行わない
    IF NKINGAKU_SIEN_TAI_YOKUNEN != 0 THEN
       UPDATE ZLBTSIEN_TAI_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_SIEN_TAI_YOKUNEN, -- 均等割額 - 期別より算出した差額
              SEKISAN    = SEKISAN    - NKINGAKU_SIEN_TAI_YOKUNEN, -- 積算税額 - 期別より算出した差額
              NENZEI     = NENZEI     - NKINGAKU_SIEN_TAI_YOKUNEN  -- 年税額   - 期別より算出した差額
        WHERE KOKU_SETAI_NO   = i_NSETAI                   -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI                  -- 算定団体コード
          AND CHOTEI_NENDO    = (i_NNENDO + 1)             -- 翌調定年度
          AND NENDO_BUN       = (i_NNENDO_BUN + 1)         -- 翌年度分
          AND TSUCHI_NO       = NYOKU_TSUCHI_NO            -- 翌年度通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;               -- 端末番号
    END IF;
--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
    -- 計算翌年度子ども基本更新
    -- 変数.翌年子ども全体税額が「0」でない場合
    IF NKINGAKU_KDM_ZEN_YOKUNEN != 0 THEN
       UPDATE ZLBTKDM_KIHON_CAL
          SET KINTO_WARI = KINTO_WARI - NKINGAKU_KDM_ZEN_YOKUNEN, -- 均等割額 - 変数.翌年子ども全体税額
              SEKISAN    = SEKISAN    - NKINGAKU_KDM_ZEN_YOKUNEN, -- 積算税額 - 変数.翌年子ども全体税額
              NENZEI     = NENZEI     - NKINGAKU_KDM_ZEN_YOKUNEN  -- 年税額   - 変数.翌年子ども全体税額
        WHERE KOKU_SETAI_NO   = i_NSETAI                   -- 国保世帯番号
          AND SANTEIDANTAI_CD = i_NDANTAI                  -- 算定団体コード
          AND CHOTEI_NENDO    = (i_NNENDO + 1)             -- 翌調定年度
          AND NENDO_BUN       = (i_NNENDO_BUN + 1)         -- 翌年度分
          AND TSUCHI_NO       = NYOKU_TSUCHI_NO            -- 翌年度通知書番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;               -- 端末番号
    END IF;
--2025/08/12 ZCZL.WANGMING ADD END

  EXCEPTION
    WHEN OTHERS THEN
      IRTN   := c_IRETNG;
      VERROR := 'FUNCUPDATEKIHONCALYOKU 翌年計算基本情報更新（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM;
  END;
  RETURN IRTN;
END FUNCUPDATEKIHONCALYOKU;

-----------------------------------------------------------
--  処理メイン
-----------------------------------------------------------
BEGIN
  -- 変数初期化
  IRET := c_IRETOK;
  BRET := TRUE;

  -- 内部変数初期化
  IRET := FUNC_INIT;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;

  -- 計算基本テーブル作成
  IRET := FUNCMAKEKIHONCAL;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;

  -- 計算期別テーブル作成
  IRET := FUNCMAKEKIBETSUCAL;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;

  -- 計算異動テーブル作成
  IRET := FUNCMAKEIDOCAL;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;

  -- 計算期別更新
  IRET := FUNCKINGAKUCLEAR;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;

  -- 計算特徴対象者テーブル作成
  IRET := FUNCMAKETOKUKIHONCAL;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;

  -- 計算基本テーブル存在チェック
  SELECT COUNT(IDO_JIYU) INTO NCNT_IDOJIYU
    FROM ZLBTKIHON_CAL
   WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
     AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
     AND CHOTEI_NENDO    = i_NNENDO         -- 調定年度
     AND NENDO_BUN       = i_NNENDO_BUN     -- 年度分
     AND TSUCHI_NO       = i_NTSUCHI_NO     -- 通知書番号
     AND SYS_TANMATSU_NO = i_VTANMATSU;     -- 端末番号

  IF NCNT_IDOJIYU > 0 THEN
    -- 異動事由取得
    SELECT IDO_JIYU INTO NIDOJIYU
      FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI       -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI      -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO       -- 調定年度
       AND NENDO_BUN       = i_NNENDO_BUN   -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO   -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;   -- 端末番号
  END IF;

  -- 計算基本更新
  IF NIDOJIYU = c_NIDO_JIYU THEN
    IRET := FUNCUPDATEKIHONCALGEN;
    IF IRET <> c_IRETOK THEN
      GOTO ERROR_EXIT;
    END IF;
    o_NFUTU := c_FOKU_KIWARI_NASI;
  -- 翌年度計算基本更新
  ELSE
    IF NYOKUNEN_KIHON_FLG > 0 THEN
      IRET := FUNCUPDATEKIHONCALYOKU;
      IF IRET <> c_IRETOK THEN
        GOTO ERROR_EXIT;
      END IF;
    END IF;
    o_NFUTU := c_FOKU_KIWARI_ARI;
  END IF;

  -- 処理終了
  <<ERROR_EXIT>>
  -- 正常
  IF IRET = c_IRETOK THEN
    BEGIN
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        IRET := c_IRETNG;
        VERROR := 'COMMIT発行（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM;
    END;
  END IF;
  -- 異常
  IF IRET <> c_IRETOK THEN
    BEGIN
      ROLLBACK;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END IF;

  -- ログ出力
  IF IRET <> c_IRETOK AND VERROR IS NOT NULL THEN
    BRET := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCALKWTKCA', 1, '', '','ZLBSKCALKWTKCA ' || VERROR, '', i_VTANMATSU);
  END IF;

  o_NRESULT := IRET;

END ZLBSKCALKWTKCA;
/
