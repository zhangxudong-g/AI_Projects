CREATE OR REPLACE PROCEDURE ZLBSKCALKWTKST(i_NTSUCHI_NO     IN  NUMBER,
--1.1.200.000
                                                    i_NNENDO         IN  NUMBER,
                                                    i_NNENDO_BUN     IN  NUMBER,
                                                    i_NSHORIBI       IN  NUMBER,
                                                    i_NDANTAI        IN  NUMBER,
                                                    i_NSETAI         IN  NUMBER,
                                                    i_NJIKKOU_KBN    IN  NUMBER,
                                                    i_NFUTU_TUKI     IN  NUMBER,
                                                    i_NTOKU_TUKI     IN  NUMBER,
                                                    i_VTANMATSU      IN  NVARCHAR2,
                                                    i_NTRENBAN       IN  NUMBER,
                                                    o_NFUTU          OUT NUMBER,
                                                    o_NRESULT        OUT NUMBER,
                                                    i_NKOSEIBI       IN  NUMBER)
-----------------------------------------------------------
--  業務名        ZLB(国民健康保険税)
--  PG 名         ZLBSKCALKWTKST
--  名称          計算特徴開始期別作成
--  処理概要
--  引数          i_NTSUCHI_NO            通知書番号
--                i_NNENDO                調定年度
--                i_NNENDO_BUN            年度分
--                i_NSHORIBI              処理日
--                i_NDANTAI               算定団体コード
--                i_NSETAI                国保世帯番号
--                i_NJIKKOU_KBN           実行区分
--                                            0:バッチから起動 本算定
--                                            1:バッチから起動月例
--                                            9:オンライン起動 即時
--                i_NFUTU_TUKI            普徴月
--                i_NTOKU_TUKI            特徴月
--                i_VTANMATSU             端末番号
--                i_NTRENBAN              登録連番
--                o_NFUTU                 普徴期割実施区分
--                                            0:普徴期割実行
--                                            1:普徴期割未実行
--                o_NRESULT               処理結果
--                                            0:正常終了
--                                            1:異常終了
--                i_NKOSEIBI              更正日（入力なし:システム日付、入力あり:入力値を使用）
--  作成者         ZCZL.GUORUIHUA
--  作成日         2023/08/01
--  Version       0.2.000.000
-----------------------------------------------------------
-- 変更履歴
-- 2025/08/11 ZCZL.LISHUAI Update 1.1.200.000:子ども子育て支援金対応
-----------------------------------------------------------
IS
  -- 定数宣言 ---------------------------------------------
  c_IRETOK            CONSTANT PLS_INTEGER    := 0;         -- 処理結果区分(正常)
  c_IRETNG            CONSTANT PLS_INTEGER    := 1;         -- 処理結果区分(異常)

  c_NSTEPNO           CONSTANT NUMBER         := 99;        -- エラーログSTEP NO

  c_NKAMOKU_CD        CONSTANT NUMBER         := 15;        -- 科目コード
  c_NKAMOKUS_CD1      CONSTANT NUMBER         := 1;         -- 科目詳細コード
  c_NKAMOKUS_CD2      CONSTANT NUMBER         := 2;

  c_NFUTU_JIKKO       CONSTANT NUMBER         := 0;         -- 処理区分 普徴期割実行
  c_NFUTU_MIJIKKO     CONSTANT NUMBER         := 1;         --          普徴期割未実行
  c_NFUTU_JIKKO_ONLY  CONSTANT NUMBER         := 9;         --          普徴期割のみ実行

  c_NFKAZEI           CONSTANT NUMBER         := 1;         -- 不均一課税実施

  c_NDANTAI           CONSTANT NUMBER         := 1;         -- 算定団体コード 合併後算定団体

  c_NKASANTEI         CONSTANT NUMBER         := 98;        -- 更新区分 仮算定

  c_NJOTAI_NEW        CONSTANT NUMBER         := 1;         -- 特徴状態 新規
  c_NJOTAI_CONTINUE   CONSTANT NUMBER         := 2;         --          継続
  c_NJOTAI_OVER       CONSTANT NUMBER         := 3;         --          中止
  c_NJIKKOU_HONSAN    CONSTANT NUMBER         := 0;         -- 実行区分 バッチから起動 本算定
  c_NJIKKOU_GETUREI   CONSTANT NUMBER         := 1;         --          バッチから起動月例
  c_NJIKKOU_ONLINE    CONSTANT NUMBER         := 9;         --          オンライン起動 即時

  -- 変数宣言 --------------------------------------------
  IRET                PLS_INTEGER;                          -- 復帰値
  BRET                BOOLEAN;                              -- 復帰値
  VERROR              NVARCHAR2(256);                       -- エラーメッセージ
  NKIWARIDANTAI_CD    NUMBER;
  NFUTU_KIBETSU       NUMBER;                               -- 普徴期別
  NTOKU_KIBETSU       NUMBER;                               -- 特徴期別
  NGENNEN_KIBETSU     NUMBER;                               -- 現年分開始期別
  NGENNEN_TUKI        NUMBER;                               -- 現年分開始月
  NYOKUNEN_KIBETSU    NUMBER;                               -- 翌年分開始期別
  NYOKUNEN_TUKI       NUMBER;                               -- 翌年分開始月
  NKISU               NUMBER;                               -- 期割期数
  NSYSDATE            NUMBER;                               -- システム日付
  NKOSEIBI            NUMBER;                               -- 更正日
  NGENRNO             NUMBER;                               -- 現年度履歴番号
  NYOKURNO            NUMBER;                               -- 翌年度履歴番号
  NYOKU_TSUCHI_NO     NUMBER;                               -- 翌年度通知書番号

  RTOKUHOSOKU         ZLBT_TOKU_HOSOKU%ROWTYPE;              -- 特徴補足情報
  RKIHONCAL           ZLBTKIHON_CAL%ROWTYPE;                -- 計算基本
  RKAIKIHONCAL        ZLBTKAI_KIHON_CAL%ROWTYPE;            -- 計算介護基本
  RSIENKIHONCAL       ZLBTSIEN_KIHON_CAL%ROWTYPE;           -- 計算支援基本
  RTAICAL             ZLBTTAI_CAL%ROWTYPE;                  -- 計算退職
  RKAITAICAL          ZLBTKAI_TAI_CAL%ROWTYPE;              -- 計算介護退職
  RSIENTAICAL         ZLBTSIEN_TAI_CAL%ROWTYPE;             -- 計算支援退職
  RKIHONN             ZLBTKIHON_N%ROWTYPE;                  -- 賦課基本
  RKAIKIHONN          ZLBTKAI_KIHON_N%ROWTYPE;              -- 賦課介護基本
  RSIENKIHONN         ZLBTSIEN_KIHON_N%ROWTYPE;             -- 賦課支援基本
-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
  RKDMKIHONCAL        ZLBTKDM_KIHON_CAL%ROWTYPE;            --計算子ども基本
  RKDMKIHONN          ZLBTKDM_KIHON_N%ROWTYPE;              --賦課子ども基本(最新)
-- 2025/08/11 ZCZL.LISHUAI ADD END
  RTAIN               ZLBTTAI_N%ROWTYPE;                    -- 賦課退職
  RKAITAIN            ZLBTKAI_TAI_N%ROWTYPE;                -- 賦課介護退職
  RSIENTAIN           ZLBTSIEN_TAI_N%ROWTYPE;               -- 賦課支援退職

-----------------------------------------------------------
--  3-5 期割団体コードセット
-----------------------------------------------------------
FUNCTION FUNCGETKIWARIDANTAI RETURN NUMBER IS
  NwFUKI_KAZEI        NUMBER;                               -- 不均一課税
  NwKIWARIDANTAICD    NUMBER;                               -- 算定団体コード

BEGIN
  -- システム条件取得
  SELECT FUKI_KAZEI INTO NwFUKI_KAZEI FROM ZLBTJOKEN
   WHERE NENDO = i_NNENDO AND SANTEIDANTAI_CD  = c_NDANTAI;

  -- 期割団体コード判定
  IF NwFUKI_KAZEI = c_NFKAZEI THEN
    -- 不均一課税を行なう
    NwKIWARIDANTAICD := i_NDANTAI;     -- ﾊﾟﾗﾒｰﾀの算定団体コード
  ELSE
    -- 不均一課税を行わない
    NwKIWARIDANTAICD := c_NDANTAI;     -- 合併後の算定団体コード
  END IF;

  RETURN NwKIWARIDANTAICD;
END FUNCGETKIWARIDANTAI;

-----------------------------------------------------------
--  3-4,5-2,8-8A 世帯主個人番号取得
-----------------------------------------------------------
FUNCTION FUNCGETNUSHI_KOJIN_NO(o_NwNUSHI_KOJIN_NO OUT NUMBER) RETURN PLS_INTEGER IS
  IwRTN             PLS_INTEGER := c_IRETOK;                -- 戻り値
  NwNUSHI_KOJIN_NO  NUMBER;                                 -- 世帯主個人番号
  NwFLG             NUMBER := 0;                            -- 1:取得失敗

BEGIN
  IF i_NTOKU_TUKI = 8 THEN
  -- 特徴月＝8月の場合、ZLBTKIHON_CALにデータが存在しない場合がある。その時は、世帯主管理より取得する。
    BEGIN
      SELECT NUSHI_KOJIN_NO INTO NwNUSHI_KOJIN_NO FROM ZLBTKIHON_CAL
       WHERE KOKU_SETAI_NO   = i_NSETAI        -- 国保世帯番号
         AND SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
         AND CHOTEI_NENDO    = i_NNENDO        -- 調停年度
         AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
         AND TSUCHI_NO       = i_NTSUCHI_NO    -- 通知書番号
         AND SYS_TANMATSU_NO = i_VTANMATSU;    -- 端末番号
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NwFLG := 1;                                         -- 取得失敗
      WHEN OTHERS THEN
        IwRTN := c_IRETNG;
        VERROR := VERROR ||'FUNCGETNUSHI_KOJIN_NO 世帯主宛名番号取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
        RETURN IwRTN;
    END;
    IF NwFLG = 1 THEN
      -- 前年度の通知書番号が不明なので主管理から処理日時点の主を取得
      BEGIN
        SELECT NUSHI_KOJIN_NO INTO NwNUSHI_KOJIN_NO
          FROM KHSTNUSHI
         WHERE KOKU_SETAI_NO   = i_NSETAI    -- 国保世帯番号
           AND NUSHI_TEKI_SBI  = (SELECT MAX(NUSHI_TEKI_SBI) FROM KHSTNUSHI
                                   WHERE KOKU_SETAI_NO   = i_NSETAI     -- 国保世帯番号
                                     AND NUSHI_TEKI_SBI <= i_NSHORIBI   -- 世帯主適用開始日
                                     AND SAKUJO_KBN      = 0)           -- 削除区分
           AND SAKUJO_KBN      = 0;          -- 削除区分
      EXCEPTION
        WHEN OTHERS THEN
          NwNUSHI_KOJIN_NO := 0;
      END;
    END IF;
  ELSE

  -- 特徴月≠8月の場合、ZLBTKIHON_CALより取得する。
    SELECT NUSHI_KOJIN_NO INTO NwNUSHI_KOJIN_NO FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI        -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO        -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO    -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;    -- 端末番号

  END IF;
  o_NwNUSHI_KOJIN_NO := NVL(NwNUSHI_KOJIN_NO, 0);

  RETURN IwRTN;
END FUNCGETNUSHI_KOJIN_NO;

-----------------------------------------------------------
--  異動テーブルのNEXT履歴番号取得
-----------------------------------------------------------
FUNCTION FUNCGETR_NO(i_NwKOJIN_NO IN NUMBER) RETURN NUMBER IS
  NwR_NO  NUMBER;

BEGIN
  SELECT MAX(R_NO) INTO NwR_NO FROM ZLBTTOKU_IDO
   WHERE KOJIN_NO      = i_NwKOJIN_NO  -- 個人番号
     AND KOKU_SETAI_NO = i_NSETAI;     -- 国保世帯番号

  NwR_NO := NVL(NwR_NO, 0) + 1;

  RETURN NwR_NO;
END FUNCGETR_NO;

-----------------------------------------------------------
--  特徴状態取得
-----------------------------------------------------------
FUNCTION FUNCGETJOTAI_KBN(i_NwFCHOTEINENDO  IN  NUMBER,
                          i_NwFNENDOBUN     IN  NUMBER,
                          o_NwJOTAI_KBN     OUT NUMBER) RETURN PLS_INTEGER IS
  IwRTN  PLS_INTEGER := c_IRETOK;
  NwZEN_ZEIGAKU NUMBER;

BEGIN
  -- 特徴状態に新規をセット
  o_NwJOTAI_KBN := c_NJOTAI_NEW;

  -- 特徴月＝10月で、計算期別5期の特徴金額＞\0データがありの場合は、特徴状態に継続をセット
  IF i_NTOKU_TUKI = 10 THEN
    BEGIN
      SELECT NVL(ZEN_ZEIGAKU, 0) INTO NwZEN_ZEIGAKU FROM ZLBTKIBETSU_CAL
       WHERE KAMOKU_CD       = c_NKAMOKU_CD      -- 科目コード
         AND KAMOKUS_CD      = c_NKAMOKUS_CD2    -- 科目詳細コード【特徴】
         AND KOKU_SETAI_NO   = i_NSETAI          -- 国保世帯番号
         AND SANTEIDANTAI_CD = i_NDANTAI         -- 算定団体コード
         -- 現年度も翌年度も処理されるため通知書番号の分岐を行う
         AND ((i_NwFCHOTEINENDO =  i_NNENDO AND TSUCHI_NO = i_NTSUCHI_NO) OR
              (i_NwFCHOTEINENDO <> i_NNENDO AND TSUCHI_NO = NYOKU_TSUCHI_NO))
         AND CHOTEINENDO     = i_NwFCHOTEINENDO  -- 調停年度
         AND NENDOBUN        = i_NwFNENDOBUN     -- 年度分
         AND RONRIKIBETSU    = 5                 -- 論理期別【５期】
         AND SYS_TANMATSU_NO = i_VTANMATSU;      -- 端末番号
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN IwRTN;
      WHEN OTHERS THEN
        IwRTN := c_IRETNG;
        VERROR := VERROR || 'FUNCGETNEWTSUCHI 新規通知書番号取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
        RETURN IwRTN;
    END;
    IF NwZEN_ZEIGAKU >0 THEN
      o_NwJOTAI_KBN := c_NJOTAI_CONTINUE;
    END IF;
  END IF;

  RETURN IwRTN;
END FUNCGETJOTAI_KBN;

-----------------------------------------------------------
--  8-10 期割団体コード更新
-----------------------------------------------------------
FUNCTION FUNCMAKEKIWARIDANTAI RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN  PLS_INTEGER := c_IRETOK;                           -- 戻り値

BEGIN
  BEGIN
    -- 現年分の計算期別TBLの期割団体コード更新
    UPDATE ZLBTKIBETSU_CAL SET KIWARIDANTAI_CD = NKIWARIDANTAI_CD
     WHERE KAMOKU_CD       = c_NKAMOKU_CD       -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD2     -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI           -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI          -- 算定団体コード
       AND CHOTEINENDO     = i_NNENDO           -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN       -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO       -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;       -- 端末番号
    -- 翌年分の計算期別TBLの期割団体コード更新
    UPDATE ZLBTKIBETSU_CAL SET KIWARIDANTAI_CD = NKIWARIDANTAI_CD
     WHERE KAMOKU_CD       = c_NKAMOKU_CD       -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD2     -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI           -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI          -- 算定団体コード
       AND CHOTEINENDO     = i_NNENDO + 1       -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN + 1   -- 年度分
       -- 翌年度通知書番号はいらないのか？？
       AND SYS_TANMATSU_NO = i_VTANMATSU;       -- 端末番号
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKEKIWARIDANTAI 期割団体コード更新（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKEKIWARIDANTAI;

-----------------------------------------------------------
--  8-11A 新規通知書番号取得処理
-----------------------------------------------------------
FUNCTION FUNCGETNEWTSUCHI(o_NwTSUCHI_NO OUT NUMBER) RETURN PLS_INTEGER IS
  IwRTN          PLS_INTEGER := c_IRETOK;                   -- 戻り値
  NwMAXTSUCHI_NO NUMBER;                                    -- 最大通知書番号
  NwRNO          NUMBER;                                    -- 取得通知書番号

BEGIN
  -- オンライン経由の起動は、最大通知書番号=0固定
  -- バッチ経由の起動は作成済みのZLBTKIHON_MIDから最大通知書番号を取得
  IF i_NJIKKOU_KBN = c_NJIKKOU_ONLINE THEN
    NwMAXTSUCHI_NO := 0;
  ELSE
    -- 調定年度で最大の通知書番号を取得
    BEGIN
      SELECT NVL(MAX(TSUCHI_NO), 0) INTO NwMAXTSUCHI_NO
        FROM ZLBTKIHON_MID
       WHERE CHOTEI_NENDO = i_NNENDO + 1;   -- 調停年度
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NwMAXTSUCHI_NO := 0;
      WHEN OTHERS THEN
        IwRTN := c_IRETNG;
        VERROR := VERROR || 'FUNCGETNEWTSUCHI 新規通知書番号取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
        RETURN IwRTN;
    END;
  END IF;

  -- 通知書番号取得
  IwRTN := ZLBFKGETTCH(i_NSETAI,                   -- IN :国保世帯番号
                         i_NDANTAI,                  --     算定団体コード
                         i_NNENDO + 1,               --     調定年度
                         i_NNENDO_BUN + 1,           --     年度分
                         RKIHONCAL.SEISAN_KBN,       --     清算区分
                         RTOKUHOSOKU.TOKU_KOJIN_NO,  --     世帯主個人番号
                         NwMAXTSUCHI_NO,             --     比較用通知書番号
                         o_NwTSUCHI_NO,              -- OUT:通知書番号
                         NwRNO);                     --     履歴番号
  IF IwRTN != c_IRETOK THEN
    IwRTN := c_IRETNG;
  END IF;
  RETURN IwRTN;
END FUNCGETNEWTSUCHI;

-----------------------------------------------------------
--  8-11B,D?P 通知書番号更新
-----------------------------------------------------------
FUNCTION FUNCUPDATETSUCHI(i_VwTBL_NAME    IN NVARCHAR2,
                          i_NwTSUCHINO    IN NUMBER,
                          i_NwCHOTEINENDO IN NUMBER,
                          i_NwNENDOBUN    IN NUMBER) RETURN PLS_INTEGER IS
  IwRTN    PLS_INTEGER := c_IRETOK;                         -- 戻り値
  NwECUR   NUMBER;                                          -- カーソルオープンハンドル
  IwCOUNT  PLS_INTEGER;                                     -- SQL実行結果
  VwSQL    VARCHAR2(3000);                                  -- SQL文字列

BEGIN
  BEGIN
    VwSQL := 'UPDATE ' || i_VwTBL_NAME || ' SET TSUCHI_NO = ' || i_NwTSUCHINO;
    VwSQL := VwSQL     || ' WHERE KOKU_SETAI_NO = ' || i_NSETAI;
    VwSQL := VwSQL     || ' AND SANTEIDANTAI_CD = ' || i_NDANTAI;
    VwSQL := VwSQL     || ' AND CHOTEI_NENDO = '    || i_NwCHOTEINENDO;
    VwSQL := VwSQL     || ' AND NENDO_BUN = '       || i_NwNENDOBUN;
    VwSQL := VwSQL     || ' AND ((' || i_NNENDO || ' =  ' || i_NwCHOTEINENDO || ' AND TSUCHI_NO = ' || i_NTSUCHI_NO || ') OR';
    VwSQL := VwSQL     || '      (' || i_NNENDO || ' != ' || i_NwCHOTEINENDO || ' AND TSUCHI_NO = ' || NYOKU_TSUCHI_NO || '))';
    VwSQL := VwSQL     || ' AND SYS_TANMATSU_NO = ' || '''' || i_VTANMATSU || '''';

    NwECUR := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(NwECUR, VwSQL, DBMS_SQL.NATIVE);
    IwCOUNT := DBMS_SQL.EXECUTE(NwECUR);
    COMMIT;
    DBMS_SQL.CLOSE_CURSOR(NwECUR);

  EXCEPTION
    WHEN OTHERS THEN
    -- カーソルをクローズ
    IF DBMS_SQL.IS_OPEN(NwECUR) THEN
      DBMS_SQL.CLOSE_CURSOR(NwECUR);
    END IF;
    IwRTN   := c_IRETNG;
    VERROR := VERROR || 'FUNCUPDATETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCUPDATETSUCHI;

-----------------------------------------------------------
--  8-11 通知書番号更新
-----------------------------------------------------------
FUNCTION FUNCMAKETSUCHI RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN        PLS_INTEGER := c_IRETOK;                     -- 戻り値
  NwTSUCHI_NO  NUMBER;                                      -- 通知書番号

BEGIN
  BEGIN
    -- 8-11A 翌年度用通知書番号取得
    IwRTN := FUNCGETNEWTSUCHI(NwTSUCHI_NO);
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    IF i_NTOKU_TUKI != 8 THEN
      -- 8-11C 計算基本の翌年度通知書番号更新(現年分)
      UPDATE ZLBTKIHON_CAL SET YOKU_TSUCHI_NO = NwTSUCHI_NO
       WHERE KOKU_SETAI_NO   = i_NSETAI        -- 国保世帯番号
         AND SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
         AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
         AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
         AND TSUCHI_NO       = i_NTSUCHI_NO    -- 通知書番号
         AND SYS_TANMATSU_NO = i_VTANMATSU;    -- 端末番号
    END IF;

    -- 8-11D 計算基本の通知書番号更新(翌年分)
    IwRTN := FUNCUPDATETSUCHI('ZLBTKIHON_CAL',      -- 更新テーブル
                              NwTSUCHI_NO,          -- 翌年度通知書番号
                              i_NNENDO + 1,         -- 調停年度
                              i_NNENDO_BUN + 1);    -- 年度分
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-11F 計算介護基本の通知書番号更新(翌年分)
    IwRTN := FUNCUPDATETSUCHI('ZLBTKAI_KIHON_CAL',  -- 更新テーブル
                              NwTSUCHI_NO,          -- 翌年度通知書番号
                              i_NNENDO + 1,         -- 調停年度
                              i_NNENDO_BUN + 1);    -- 年度分
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-11H 計算支援基本の通知書番号更新(翌年分)
    IwRTN := FUNCUPDATETSUCHI('ZLBTSIEN_KIHON_CAL', -- 更新テーブル
                             NwTSUCHI_NO,           -- 翌年度通知書番号
                             i_NNENDO + 1,          -- 調停年度
                             i_NNENDO_BUN + 1);     -- 年度分
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-11J 計算退職の通知書番号更新(翌年分)
    IwRTN := FUNCUPDATETSUCHI('ZLBTTAI_CAL',        -- 更新テーブル
                             NwTSUCHI_NO,           -- 翌年度通知書番号
                             i_NNENDO + 1,          -- 調停年度
                             i_NNENDO_BUN + 1);     -- 年度分
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-11L 計算介護退職の通知書番号更新(翌年分)
    IwRTN := FUNCUPDATETSUCHI('ZLBTKAI_TAI_CAL',    -- 更新テーブル
                             NwTSUCHI_NO,           -- 翌年度通知書番号
                             i_NNENDO + 1,          -- 調停年度
                             i_NNENDO_BUN + 1);     -- 年度分
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-11N 計算支援退職の通知書番号更新(翌年分)
    IwRTN := FUNCUPDATETSUCHI('ZLBTSIEN_TAI_CAL',   -- 更新テーブル
                             NwTSUCHI_NO,           -- 翌年度通知書番号
                             i_NNENDO + 1,          -- 調停年度
                             i_NNENDO_BUN + 1);     -- 年度分
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-11P 計算特徴対象者の通知書番号更新(翌年分)
    IwRTN := FUNCUPDATETSUCHI('ZLBTTOKU_KIHON_CAL', -- 更新テーブル
                             NwTSUCHI_NO,           -- 翌年度通知書番号
                             i_NNENDO + 1,          -- 調停年度
                             i_NNENDO_BUN + 1);     -- 年度分
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-11R 計算期別の通知書番号更新(翌年分)
    UPDATE ZLBTKIBETSU_CAL SET TSUCHI_NO = NwTSUCHI_NO
     WHERE KAMOKU_CD       = c_NKAMOKU_CD          -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD2        -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI              -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI             -- 算定団体コード
       AND CHOTEINENDO     = i_NNENDO + 1          -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN + 1      -- 年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO       -- 翌年度通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;          -- 端末番号
-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
    IwRTN := FUNCUPDATETSUCHI ('ZLBTKDM_KIHON_CAL', -- 更新テーブル
                             NwTSUCHI_NO,           -- 翌年度通知書番号
                             i_NNENDO + 1,          -- 調停年度
                             i_NNENDO_BUN + 1);     -- 年度分
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;
-- 2025/08/11 ZCZL.LISHUAI ADD END

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKETSUCHI 通知書番号更新（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKETSUCHI;

-----------------------------------------------------------
--  ④ 計算期別テーブル作成
-----------------------------------------------------------
FUNCTION FUNCMAKEKIBETSUCAL RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN  PLS_INTEGER := c_IRETOK;                           -- 戻り値

  -- 最新期別TBL
  CURSOR CKIBETSU_N IS
    SELECT * FROM ZLBTKIBETSU_N
     WHERE KAMOKU_CD       = c_NKAMOKU_CD      -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD2    -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI          -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI         -- 算定団体コード
       -- 現年度も翌年度も処理されるため通知書番号の分岐を行う
       AND ((TSUCHI_NO       = i_NTSUCHI_NO    AND CHOTEINENDO = i_NNENDO     AND NENDOBUN = i_NNENDO_BUN) OR
            (TSUCHI_NO       = NYOKU_TSUCHI_NO AND CHOTEINENDO = i_NNENDO + 1 AND NENDOBUN = i_NNENDO_BUN + 1));
  -- 計算期別TBL
  CURSOR CKIBETSU_CAL(p_NNENDO        IN NUMBER,
                      p_NNENDO_BUN    IN NUMBER,
                      p_NRONRIKIBETSU IN NUMBER,
                      p_NTSUCHI_NO    IN NUMBER) IS
    SELECT * FROM ZLBTKIBETSU_CAL
     WHERE KAMOKU_CD       = c_NKAMOKU_CD    -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD2  -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI        -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
       AND TSUCHI_NO       = p_NTSUCHI_NO    -- 通知書番号
       AND CHOTEINENDO     = p_NNENDO        -- 調停年度
       AND NENDOBUN        = p_NNENDO_BUN    -- 年度分
       AND RONRIKIBETSU    = p_NRONRIKIBETSU -- 論理期別
       AND SYS_TANMATSU_NO = i_VTANMATSU;    -- 端末番号

  RKIBETSU_CAL CKIBETSU_CAL%ROWTYPE;

BEGIN
  BEGIN
    -- 最新期別TBLの内容で計算期別TBLを作成する
    FOR CRKIBETSU_N IN CKIBETSU_N LOOP
      IF CRKIBETSU_N.CHOTEINENDO = i_NNENDO THEN
      -- 現年度期別
        OPEN CKIBETSU_CAL(CRKIBETSU_N.CHOTEINENDO,  -- 調停年度
                          CRKIBETSU_N.NENDOBUN,     -- 年度分
                          CRKIBETSU_N.RONRIKIBETSU, -- 論理期別
                          i_NTSUCHI_NO);            -- 通知書番号
      ELSE
      -- 翌年度期別
        OPEN CKIBETSU_CAL(CRKIBETSU_N.CHOTEINENDO,  -- 調停年度
                          CRKIBETSU_N.NENDOBUN,     -- 年度分
                          CRKIBETSU_N.RONRIKIBETSU, -- 論理期別
                          NYOKU_TSUCHI_NO);         -- 翌年度通知書番号
      END IF;

      FETCH CKIBETSU_CAL INTO RKIBETSU_CAL;
        IF CKIBETSU_CAL%NOTFOUND THEN
          CRKIBETSU_N.R_NO            := CRKIBETSU_N.R_NO + 10;
          CRKIBETSU_N.SYS_TANMATSU_NO := i_VTANMATSU;

          INSERT INTO ZLBTKIBETSU_CAL VALUES CRKIBETSU_N;
        END IF;
      CLOSE CKIBETSU_CAL;
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKEKIBETSUCAL 計算期別テーブル作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKEKIBETSUCAL;

-----------------------------------------------------------
--  5 計算異動テーブル作成
-----------------------------------------------------------
FUNCTION FUNCMAKEIDOCAL RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN          PLS_INTEGER := c_IRETOK;                   -- 戻り値
  NwKOJIN_NO     NUMBER;                                    -- 世帯主個人番号
  RwTOKU_IDO_CAL ZLBTTOKU_IDO_CAL%ROWTYPE;                  -- 計算異動作成用ワーク

  -- 異動TBL(未処理データ)
  CURSOR CTOKUIDO IS
    SELECT A.* FROM ZLBTTOKU_IDO A,
          (SELECT MAX(R_NO) AS R_NO, KOJIN_NO
             FROM ZLBTTOKU_IDO
            WHERE KOKU_SETAI_NO = i_NSETAI   -- 国保世帯番号
         GROUP BY KOJIN_NO) B
     WHERE A.KOKU_SETAI_NO = i_NSETAI        -- 国保世帯番号
       AND A.SYORI_FLG     = 0               -- 処理フラグ
       AND A.R_NO          = B.R_NO          -- 履歴番号
       AND A.KOJIN_NO      = B.KOJIN_NO;     -- 個人番号
  -- 計算異動TBL(世帯全員)
  CURSOR CTOKUIDO_CAL IS
    SELECT * FROM ZLBTTOKU_IDO_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI        -- 国保世帯番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;    -- 端末番号
  -- 計算異動TBL(世帯主)
  CURSOR CTOKUIDOCAL(p_NKOJIN_NO IN NUMBER) IS
    SELECT * FROM ZLBTTOKU_IDO_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI        -- 国保世帯番号
       AND KOJIN_NO        = p_NKOJIN_NO     -- 個人番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;    -- 端末番号

  RwTOKUIDO_CAL CTOKUIDO_CAL%ROWTYPE;                       -- 計算異動(世帯全員)取得ワーク
  RwTOKUIDOCAL  CTOKUIDOCAL%ROWTYPE;                        -- 計算異動(世帯主)  取得ワーク

BEGIN
  BEGIN
    -- 5-1 計算異動TBL(未処理分)の該当世帯のデータを処理済に変更
    OPEN CTOKUIDO_CAL;
    FETCH CTOKUIDO_CAL INTO RwTOKUIDO_CAL;
      IF CTOKUIDO_CAL%NOTFOUND THEN
        FOR CRTOKUIDO IN CTOKUIDO LOOP
          CRTOKUIDO.R_NO := CRTOKUIDO.R_NO + 1;       -- 処理フラグ
          CRTOKUIDO.SYORI_FLG := 1;                   -- 処理フラグ
          CRTOKUIDO.SYS_TANMATSU_NO := i_VTANMATSU;   -- 端末番号

          INSERT INTO ZLBTTOKU_IDO_CAL VALUES CRTOKUIDO;
        END LOOP;
      END IF;
    CLOSE CTOKUIDO_CAL;

    -- 5-2 作成した計算異動TBLに世帯主の情報が存在しない場合は新規にレコードを作成
    IwRTN := FUNCGETNUSHI_KOJIN_NO(NwKOJIN_NO);
    IF IwRTN <> c_IRETOK THEN
      RETURN IwRTN;
    END IF;
    OPEN CTOKUIDOCAL(NwKOJIN_NO);
    FETCH CTOKUIDOCAL INTO RwTOKUIDOCAL;
      IF CTOKUIDOCAL%NOTFOUND THEN
        RwTOKU_IDO_CAL.KOKU_SETAI_NO       := i_NSETAI;                   -- 国保世帯番号
        RwTOKU_IDO_CAL.KOJIN_NO            := NwKOJIN_NO;                 -- 個人番号
        RwTOKU_IDO_CAL.R_NO                := FUNCGETR_NO(NwKOJIN_NO);    -- MAX履歴番号
        RwTOKU_IDO_CAL.KOSEI_KBN           := 2;                          -- 更正区分・開始
        RwTOKU_IDO_CAL.TOKU_KIBETSU_CD     := NTOKU_KIBETSU;              -- 期別コード
        RwTOKU_IDO_CAL.SYORI_FLG           := 1;                          -- 処理済フラグ
        RwTOKU_IDO_CAL.CHUSHI_JIYU         := 0;                          -- 中止事由
        RwTOKU_IDO_CAL.SYS_SAKUSEIBI       := NULL;                       -- 作成日
        RwTOKU_IDO_CAL.SYS_KOSHINBI        := NULL;                       -- 更新日
        RwTOKU_IDO_CAL.SYS_JIKAN           := NULL;                       -- システム時間
        RwTOKU_IDO_CAL.SYS_SHOKUINKOJIN_NO := NULL;                       -- 職員番号
        RwTOKU_IDO_CAL.SYS_TANMATSU_NO     := i_VTANMATSU;                -- 端末番号

        INSERT INTO ZLBTTOKU_IDO_CAL VALUES RwTOKU_IDO_CAL;
      END IF;
    CLOSE CTOKUIDOCAL;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKEIDOCAL 計算異動テーブル作成（国保世帯番号='|| i_NSETAI ||
                          ' 宛名番号=' || NwKOJIN_NO          ||
                          ' 履歴番号=' || RwTOKU_IDO_CAL.R_NO ||
                          ' 端末番号=' || i_VTANMATSU         ||
                          '）'         || SQLERRM             || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKEIDOCAL;
----------------------------------------------------------
-- 6-1 年金支給日の算出処理                                --
----------------------------------------------------------
FUNCTION FUNCNENREIKIJUNBI(i_NwTUKI IN NUMBER,o_NwSIKYUUBI OUT NUMBER) RETURN PLS_INTEGER IS
  IwRTN             NUMBER := c_IRETOK;                     -- 戻り値
  NwHANTEI_YMD      NUMBER      := 0;                       -- 年金支給判定日
  IwYOUBI_KBN       PLS_INTEGER := 0;                       -- 曜日区分(1:日曜日～7:土曜日)
  IwSYUKUJITU_KBN   PLS_INTEGER := 0;                       -- 祝日区分(1:祝日以外、2:祝日)
  VwSYUKUJITU_NAME  NVARCHAR2(6):= '';                      -- 祝日名称(祝日区分=2の場合は祝日名称)
  IwKINYU_KBN       PLS_INTEGER := 0;                       -- 金融機関休日区分(1:営業日、2:休日)
  IwKANKOCHOU_KBN   PLS_INTEGER := 0;                       -- 官公庁休日区分(1:勤務を要する日、2:勤務を要しない日)

BEGIN
  BEGIN
    -- 依頼通知年月の15日で曜日、休日判定
    -- 月が2月の場合は翌年なので年度+1
    IF (i_NwTUKI = 2) THEN
      NwHANTEI_YMD := ((i_NNENDO +1) * 10000) + (i_NwTUKI*100) + 15;
    ELSE
      NwHANTEI_YMD := (i_NNENDO * 10000) + (i_NwTUKI*100) + 15;
    END IF;

    --曜日、休日判定
    LOOP
      IwRTN := KKAPK0020.FYOUBI(NwHANTEI_YMD, 0,
                 IwYOUBI_KBN, IwSYUKUJITU_KBN, VwSYUKUJITU_NAME, IwKINYU_KBN, IwKANKOCHOU_KBN);
      IF IwRTN = c_IRETNG THEN
        EXIT;
      END IF;

     --(土曜、日曜、祝日)以外の場合
      IF IwYOUBI_KBN NOT IN (1, 7) AND IwSYUKUJITU_KBN = 1 THEN
        o_NwSIKYUUBI := NwHANTEI_YMD;
        EXIT;
      END IF;

      --判定日の前日
      NwHANTEI_YMD := KKAPK0020.FDATECAL(NwHANTEI_YMD, 0, -1, 0, 0);

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCNENREIKIJUNBI 特徴支給日の算出処理（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCNENREIKIJUNBI;

-----------------------------------------------------------
--  6 開始期と期割期数取得
-----------------------------------------------------------
FUNCTION FUNCGETKISU RETURN PLS_INTEGER IS
  IwRTN        NUMBER := c_IRETOK;
  NwSEINENGAPI NUMBER;
  NwNENKINBI   NUMBER;
  N75AGE_BIRTH NUMBER;
BEGIN
  -- 世帯主生年月日取得
  BEGIN
    SELECT B.SEINENGAPI INTO NwSEINENGAPI
      FROM ZLBTKIHON_CAL  A,
           GABTATENAKIHON B
     WHERE A.KOKU_SETAI_NO   = i_NSETAI        -- 国保世帯番号
       AND A.SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
       AND A.CHOTEI_NENDO    = i_NNENDO        -- 調停年度
       AND A.NENDO_BUN       = i_NNENDO_BUN    -- 年度分
       AND A.TSUCHI_NO       = i_NTSUCHI_NO    -- 通知書番号
       AND A.SYS_TANMATSU_NO = i_VTANMATSU     -- 端末番号
       AND B.KOJIN_NO        = A.NUSHI_KOJIN_NO;
    EXCEPTION
      WHEN OTHERS THEN
        IwRTN := c_IRETNG;
        VERROR := VERROR || 'FUNCGETKISU 世帯主生年月日取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
        RETURN IwRTN;
    END;

    -- 75歳の誕生日取得
    N75AGE_BIRTH := KKAPK0020.FDATECAL(NwSEINENGAPI, 0, 0, 0, 75);

    -- 誕生日＞調停年度の3月31日 OR 特徴月=8,104,106
    IF(N75AGE_BIRTH > ((i_NNENDO + 1)*10000+331) OR i_NTOKU_TUKI IN (108,104,106)) THEN

    IF i_NTOKU_TUKI = 10 THEN                               -- 特徴月=10月
      NGENNEN_KIBETSU  := 7;                                --  現年 期別 = 7期
      NGENNEN_TUKI     := 10;                               --         月 =10月
      NYOKUNEN_KIBETSU := 1;                                --  翌年 期別 = 1期
      NYOKUNEN_TUKI    := 4;                                --         月 = 4月
      NKISU            := 3;                                --  残期数    = 3
    ELSIF i_NTOKU_TUKI = 12 THEN                            -- 特徴月=12月
      NGENNEN_KIBETSU  := 9;                                --  現年 期別 = 9期
      NGENNEN_TUKI     := 12;                               --         月 =12月
      NYOKUNEN_KIBETSU := 1;                                --  翌年 期別 = 1期
      NYOKUNEN_TUKI    := 4;                                --         月 = 4月
      NKISU            := 2;                                --  残期数    = 2
    ELSIF i_NTOKU_TUKI = 2 THEN                             -- 特徴月= 2月
      NGENNEN_KIBETSU  := 11;                               --  現年 期別 =11期
      NGENNEN_TUKI     := 2;                                --         月 = 2月
      NYOKUNEN_KIBETSU := 1;                                --  翌年 期別 = 1期
      NYOKUNEN_TUKI    := 4;                                --         月 = 4月
      NKISU            := 1;                                --  残期数    = 1
    ELSIF i_NTOKU_TUKI = 104 THEN                           -- 特徴月=翌4月
      NGENNEN_KIBETSU  := 0;                                --  現年 期別 =なし
      NGENNEN_TUKI     := 0;                                --         月 =なし
      NYOKUNEN_KIBETSU := 1;                                --  翌年 期別 = 1期
      NYOKUNEN_TUKI    := 4;                                --         月 = 4月
      NKISU            := 0;                                --  残期数    =なし
    ELSIF i_NTOKU_TUKI = 106 THEN                           -- 特徴月=翌6月
      NGENNEN_KIBETSU  := 0;                                --  現年 期別 =なし
      NGENNEN_TUKI     := 0;                                --         月 =なし
      NYOKUNEN_KIBETSU := 3;                                --  翌年 期別 = 3期
      NYOKUNEN_TUKI    := 6;                                --         月 = 6月
      NKISU            := 0;                                --  残期数    =なし
    ELSIF i_NTOKU_TUKI = 8 THEN                             -- 特徴月=8月
      NGENNEN_KIBETSU  := 5;                                --  現年 期別 = 5期
      NGENNEN_TUKI     := 8;                                --         月 = 8月
      NYOKUNEN_KIBETSU := 0;                                --  翌年 期別 =なし
      NYOKUNEN_TUKI    := 0;                                --         月 =なし
      NKISU            := 1;                                --  残期数    = 1
    ELSIF i_NTOKU_TUKI = 108 THEN                           -- 特徴月=翌8月
      NGENNEN_KIBETSU  := 0;                                --  現年 期別 =なし
      NGENNEN_TUKI     := 0;                                --         月 =なし
      NYOKUNEN_KIBETSU := 5;                                --  翌年 期別 = 5期
      NYOKUNEN_TUKI    := 8;                                --         月 = 8月
      NKISU            := 0;                                --  残期数    =なし
    END IF;
    ELSE -- 年度内に75歳到達

      -- 年度内に75歳到達する場合は、翌年度期別は作成しない
      NYOKUNEN_KIBETSU := 0; --  翌年 期別 = なし
      NYOKUNEN_TUKI    := 0; --         月 = なし

      /********************/
      /* 年金支給日を取得 */
      /********************/
      IwRTN := FUNCNENREIKIJUNBI(i_NTOKU_TUKI , NwNENKINBI);
      IF IwRTN = c_IRETOK THEN
        -- 年金支給日＞75歳到達日
        IF NwNENKINBI > N75AGE_BIRTH THEN
          CASE
            WHEN i_NTOKU_TUKI = 10 THEN  -- 特徴月=10月
              NGENNEN_KIBETSU  := 7;     --  現年 期別 = 7期
              NGENNEN_TUKI     := 10;    --         月 =10月
            WHEN i_NTOKU_TUKI = 12 THEN  -- 特徴月=12月
              NGENNEN_KIBETSU  := 9;     --  現年 期別 = 9期
              NGENNEN_TUKI     := 12;    --         月 =12月
            ELSE                         -- 特徴月=2月
              NGENNEN_KIBETSU  := 11;    --  現年 期別 =11期
              NGENNEN_TUKI     := 2;     --         月 = 2月
              NULL;
          END CASE;
          NYOKUNEN_KIBETSU := 0; --  翌年 期別 = なし
          NYOKUNEN_TUKI    := 0; --         月 = なし
          NKISU            := 0; --  残期数    = なし

        ELSIF i_NTOKU_TUKI = 10 THEN  -- 特徴月10月
          /**************************/
          /* 年金支給日を取得(12月) */
          /**************************/
          IwRTN := FUNCNENREIKIJUNBI(12 , NwNENKINBI);
            IF IwRTN = c_IRETOK THEN
              -- 年金支給日＞75歳到達日
              IF NwNENKINBI > N75AGE_BIRTH THEN
                NGENNEN_KIBETSU  := 7;  --  現年 期別 = 7期
                NGENNEN_TUKI     := 10; --         月 = 10月
                NYOKUNEN_KIBETSU := 0;  --  翌年 期別 = なし
                NYOKUNEN_TUKI    := 0;  --         月 = なし
                NKISU            := 1;  --  残期数    = 1
              ELSE
                /**************************/
                /* 年金支給日を取得(2月) */
                /**************************/
                IwRTN := FUNCNENREIKIJUNBI(2 , NwNENKINBI);
                IF IwRTN = c_IRETOK THEN
                  -- 年金支給日＞75歳到達日
                  IF NwNENKINBI > N75AGE_BIRTH THEN
                    NGENNEN_KIBETSU  := 7;  --  現年 期別 = 7期
                    NGENNEN_TUKI     := 10; --         月 = 10月
                    NYOKUNEN_KIBETSU := 0;  --  翌年 期別 = なし
                    NYOKUNEN_TUKI    := 0;  --         月 = なし
                    NKISU            := 2;  --  残期数    = 2
                  ELSE
                    NGENNEN_KIBETSU  := 7;  --  現年 期別 = 7期
                    NGENNEN_TUKI     := 10; --         月 =10月
                    NKISU            := 3;  --  残期数    = 3
                  END IF;
                ELSE
                  IwRTN := c_IRETNG;
                  VERROR := VERROR || 'FUNCGETKISU 年金支給日を取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
                  RETURN IwRTN;
                END IF;
              END IF;
          ELSE
            IwRTN := c_IRETNG;
            VERROR := VERROR || 'FUNCGETKISU 年金支給日を取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
            RETURN IwRTN;
          END IF;

        ELSIF i_NTOKU_TUKI = 12 THEN  -- 特徴月12月
          /**************************/
          /* 年金支給日を取得(2月) */
          /**************************/
          IwRTN := FUNCNENREIKIJUNBI(2 , NwNENKINBI);
          IF IwRTN = c_IRETOK THEN
            -- 年金支給日＞75歳到達日
            IF NwNENKINBI > N75AGE_BIRTH THEN
              NGENNEN_KIBETSU  := 9;  --  現年 期別 = 9期
              NGENNEN_TUKI     := 12; --         月 = 12月
              NYOKUNEN_KIBETSU := 0;  --  翌年 期別 = なし
              NYOKUNEN_TUKI    := 0;  --         月 = なし
              NKISU            := 1;  --  残期数    = 1
            ELSE
              NGENNEN_KIBETSU  := 9;  --  現年 期別 = 9期
              NGENNEN_TUKI     := 12; --         月 =12月
              NKISU            := 2;  --  残期数    = 2
            END IF;
          ELSE
            IwRTN := c_IRETNG;
            VERROR := VERROR || 'FUNCGETKISU 年金支給日を取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
            RETURN IwRTN;
          END IF;

        ELSE  -- 特徴月2月
          NGENNEN_KIBETSU  := 11; --  現年 期別 = 11期
          NGENNEN_TUKI     := 2;  --         月 = 2月
          NKISU            := 1;  --  残期数    = 1
        END IF;
      ELSE
        IwRTN := c_IRETNG;
        VERROR := VERROR || 'FUNCGETKISU 年金支給日を取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
        RETURN IwRTN;
      END IF;
    END IF;

  RETURN IwRTN;
END FUNCGETKISU;

-----------------------------------------------------------
--  7-1,2 計算特徴対象者テーブルセット ※現年も翌年も呼ばれる
-----------------------------------------------------------
FUNCTION FUNCSETTOKUKIHONCAL(i_NwFCHOTEINENDO  IN NUMBER,
                             i_NwFNENDOBUN     IN NUMBER,
                             i_NwTUKI          IN NUMBER,
                             i_NwKIBETSU       IN NUMBER) RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN                PLS_INTEGER := c_IRETOK;             -- 戻り値
  NwJOTAI_KBN          NUMBER;                              -- 特徴状態
  NwTOKU_GIMUSHA_CD_4  NUMBER;                              -- 特徴義務者コード4月～8月
  NwNENKIN_CD_4        NUMBER;                              -- 年金コード４月～８月
  NwTOKU_GIMUSHA_CD_10 NUMBER;                              -- 特徴義務者コード10月～２月
  NwNENKIN_CD_10       NUMBER;                              -- 年金コード10月～２月
  NwR_NO               NUMBER;                              -- 履歴番号
  NwIRAI_HIZUKE        NUMBER;                              -- 依頼日
  RwTOKUKIHONCAL       ZLBTTOKU_KIHON_CAL%ROWTYPE;          -- 計算特徴対象者

  -- 計算特徴対象者
  CURSOR CTOKUKIHON_CAL IS
    SELECT * FROM  ZLBTTOKU_KIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI           -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI          -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwFCHOTEINENDO   -- 調定年度
       AND NENDO_BUN       = i_NwFNENDOBUN      -- 年度分
       -- 現年度も翌年度も処理されるため通知書番号の分岐を行う
       AND ((i_NwFCHOTEINENDO =  i_NNENDO AND TSUCHI_NO = i_NTSUCHI_NO) OR
            (i_NwFCHOTEINENDO <> i_NNENDO AND TSUCHI_NO = NYOKU_TSUCHI_NO))
       AND SYS_TANMATSU_NO = i_VTANMATSU;       -- 端末番号

  RTOKUKIHON_CAL CTOKUKIHON_CAL%ROWTYPE;

BEGIN
  BEGIN

    BEGIN
      SELECT R_NO INTO NwR_NO FROM ZLBTKIHON_CAL
       WHERE KOKU_SETAI_NO   = i_NSETAI        -- 国保世帯番号
         AND SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
         AND CHOTEI_NENDO    = i_NwFCHOTEINENDO        -- 調定年度
         AND NENDO_BUN       = i_NwFNENDOBUN    -- 年度分
       -- 現年度も翌年度も処理されるため通知書番号の分岐を行う
       AND ((i_NwFCHOTEINENDO =  i_NNENDO AND TSUCHI_NO = i_NTSUCHI_NO) OR
            (i_NwFCHOTEINENDO <> i_NNENDO AND TSUCHI_NO = NYOKU_TSUCHI_NO))
         AND SYS_TANMATSU_NO = i_VTANMATSU;    -- 端末番号
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NwR_NO := 10;
      WHEN OTHERS THEN
        IwRTN := c_IRETNG;
        VERROR := VERROR || 'FUNCSETTOKUKIHONCAL 計算特徴対象者テーブルセット（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
        RETURN IwRTN;
    END;

    -- 計算特徴対象者TBLにレコードが存在しない場合は新規に作成、存在する場合は内容を更新する
    OPEN CTOKUKIHON_CAL;
    FETCH CTOKUKIHON_CAL INTO RTOKUKIHON_CAL;
      IF CTOKUKIHON_CAL%NOTFOUND THEN
      -- 計算特徴対象者TBLにレコードが存在しない(Insert)
        RwTOKUKIHONCAL.KOKU_SETAI_NO        := i_NSETAI;                        -- 国保世帯番号
        RwTOKUKIHONCAL.SANTEIDANTAI_CD      := i_NDANTAI;                       -- 算定団体コード
        RwTOKUKIHONCAL.CHOTEI_NENDO         := i_NwFCHOTEINENDO;                -- 調定年度
        RwTOKUKIHONCAL.NENDO_BUN            := i_NwFNENDOBUN;                   -- 年度分
        RwTOKUKIHONCAL.R_NO                 := NwR_NO;                          -- 履歴番号
        IF(i_NwFCHOTEINENDO = i_NNENDO AND i_NwFNENDOBUN = i_NNENDO_BUN) THEN   -- 通知書番号
          -- 現年度作成時
          RwTOKUKIHONCAL.TSUCHI_NO          := i_NTSUCHI_NO;
        ELSE
          -- 翌年度作成時
          RwTOKUKIHONCAL.TSUCHI_NO          := NYOKU_TSUCHI_NO;
        END IF;
        RwTOKUKIHONCAL.HOSOKU_NENDO         := RTOKUHOSOKU.HOSOKU_NENDO;        -- 補足年度
        RwTOKUKIHONCAL.TOKU_KOJIN_NO        := RTOKUHOSOKU.TOKU_KOJIN_NO;       -- 特徴対象者個人番号
        IF (i_NNENDO_BUN <> i_NwFNENDOBUN) AND (i_NTOKU_TUKI IN(10,12,2)) THEN
          RwTOKUKIHONCAL.JOTAI_KBN            := c_NJOTAI_CONTINUE;
        ELSE
          RwTOKUKIHONCAL.JOTAI_KBN            := c_NJOTAI_NEW;
        END IF;
        RwTOKUKIHONCAL.KISO_NENKIN_NO       := RTOKUHOSOKU.KISO_NENKIN_NO;      -- 基礎年金番号
        RwTOKUKIHONCAL.TOKU_GIMUSHA_CD      := RTOKUHOSOKU.TOKU_GIMUSHA_CD;     -- 特徴徴収義務者コード
        RwTOKUKIHONCAL.NENKIN_CD            := RTOKUHOSOKU.NENKIN_CD;           -- 年金コード
        RwTOKUKIHONCAL.KAISHI_TSUKI         := i_NwTUKI;                        -- 特徴開始月
        RwTOKUKIHONCAL.KAISHI_KIBETSU       := i_NwKIBETSU;                     -- 特徴開始期別
        RwTOKUKIHONCAL.SHURYO_TSUKI         := 0;                               -- 特徴終了月
        RwTOKUKIHONCAL.SHURYO_KIBETSU       := 0;                               -- 特徴終了期別
        RwTOKUKIHONCAL.CHUSHI_JIYU          := 0;                               -- 中止事由
        RwTOKUKIHONCAL.KARIHENKO_KBN1       := 0;                               -- 仮徴収額変更区分1
        RwTOKUKIHONCAL.KARIHENKO_KBN2       := 0;                               -- 仮徴収額変更区分2
        RwTOKUKIHONCAL.KARIHENKO_KBN3       := 0;                               -- 仮徴収額変更区分3
        IF i_NwTUKI IN(4,6,8) THEN                                              -- 特徴義務者コード４~８月、年金コード４~８月
          RwTOKUKIHONCAL.TOKU_GIMUSHA_CD_4  := RTOKUHOSOKU.TOKU_GIMUSHA_CD;
          RwTOKUKIHONCAL.NENKIN_CD_4        := RTOKUHOSOKU.NENKIN_CD;
        ELSE
          RwTOKUKIHONCAL.TOKU_GIMUSHA_CD_4  := 0;
          RwTOKUKIHONCAL.NENKIN_CD_4        := 0;
        END IF;
        IF i_NwTUKI IN(10,12,2) THEN                                            -- 特徴義務者コード10~２月、年金コード10~２月
          RwTOKUKIHONCAL.TOKU_GIMUSHA_CD_10 := RTOKUHOSOKU.TOKU_GIMUSHA_CD;
          RwTOKUKIHONCAL.NENKIN_CD_10       := RTOKUHOSOKU.NENKIN_CD;
        ELSE
          RwTOKUKIHONCAL.TOKU_GIMUSHA_CD_10 := 0;
          RwTOKUKIHONCAL.NENKIN_CD_10       := 0;
        END IF;
        IF i_NNENDO = i_NwFCHOTEINENDO THEN                                     -- 依頼日
          -- 現年度作成時
          IF i_NTOKU_TUKI IN(4,6) THEN
            RwTOKUKIHONCAL.IRAI_HIZUKE := NSYSDATE;
          ELSE
            RwTOKUKIHONCAL.IRAI_HIZUKE := 0;
          END IF;
        ELSE
          -- 翌年度作成時
          IF i_NTOKU_TUKI IN(104,106,108) THEN
            RwTOKUKIHONCAL.IRAI_HIZUKE        := 0;
          ELSE
            RwTOKUKIHONCAL.IRAI_HIZUKE        := NSYSDATE;
          END IF;
        END IF;
        RwTOKUKIHONCAL.SYS_SAKUSEIBI        := NULL;         -- 作成日
        RwTOKUKIHONCAL.SYS_KOSHINBI         := NULL;         -- 更新日
        RwTOKUKIHONCAL.SYS_JIKAN            := NULL;         -- システム時間
        RwTOKUKIHONCAL.SYS_SHOKUINKOJIN_NO  := NULL;         -- 職員番号
        RwTOKUKIHONCAL.SYS_TANMATSU_NO      := i_VTANMATSU;  -- 端末番号

        -- 削除後、追加。但し、削除時の翌年度通知書番号は不明である為、個人番号指定で削除
        DELETE FROM ZLBTTOKU_KIHON_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI                       -- 国保世帯番号
           AND SANTEIDANTAI_CD = i_NDANTAI                      -- 算定団体コード
           AND TOKU_KOJIN_NO   = RTOKUHOSOKU.TOKU_KOJIN_NO      -- 個人番号
           AND CHOTEI_NENDO    = i_NwFCHOTEINENDO               -- 調定年度
           AND NENDO_BUN       = i_NwFNENDOBUN                  -- 年度分
           AND SYS_TANMATSU_NO = i_VTANMATSU;                   -- 端末番号
        INSERT INTO ZLBTTOKU_KIHON_CAL VALUES RwTOKUKIHONCAL;

      ELSE
      -- 計算特徴対象者TBLにレコードが存在する(Update)
        -- 特徴状態 取得
        IwRTN := FUNCGETJOTAI_KBN(i_NwFCHOTEINENDO, i_NwFNENDOBUN, NwJOTAI_KBN);
        IF IwRTN <> c_IRETOK THEN
          RETURN IwRTN;
        END IF;

        -- 特徴義務者コード４～８月、年金コード４～８月
        IF i_NwTUKI IN(4,6,8) THEN
          NwTOKU_GIMUSHA_CD_4  := RTOKUHOSOKU.TOKU_GIMUSHA_CD;
          NwNENKIN_CD_4        := RTOKUHOSOKU.NENKIN_CD;
        ELSE
          NwTOKU_GIMUSHA_CD_4  := RTOKUKIHON_CAL.TOKU_GIMUSHA_CD_4;
          NwNENKIN_CD_4        := RTOKUKIHON_CAL.NENKIN_CD_4;
        END IF;
        -- 特徴義務者コード10～２月、年金コード10～２月
        IF i_NwTUKI IN(10,12,2) THEN
          NwTOKU_GIMUSHA_CD_10 := RTOKUHOSOKU.TOKU_GIMUSHA_CD;
          NwNENKIN_CD_10       := RTOKUHOSOKU.NENKIN_CD;
        ELSE
          NwTOKU_GIMUSHA_CD_10 := RTOKUKIHON_CAL.TOKU_GIMUSHA_CD_10;
          NwNENKIN_CD_10       := RTOKUKIHON_CAL.NENKIN_CD_10;
        END IF;
        -- 依頼日
        IF i_NNENDO = i_NwFCHOTEINENDO THEN
          -- 現年度作成時
          IF i_NTOKU_TUKI IN(4,6) THEN
            NwIRAI_HIZUKE        := NSYSDATE;
          ELSE
            NwIRAI_HIZUKE          := 0;
          END IF;
        ELSE
          -- 翌年度作成時
          IF i_NTOKU_TUKI IN(104,106,108) THEN
            NwIRAI_HIZUKE        := 0;
          ELSE
            NwIRAI_HIZUKE        := NSYSDATE;
          END IF;
        END IF;

        UPDATE ZLBTTOKU_KIHON_CAL
           SET HOSOKU_NENDO        = RTOKUHOSOKU.HOSOKU_NENDO,        -- 補足年度
               TOKU_KOJIN_NO       = RTOKUHOSOKU.TOKU_KOJIN_NO,       -- 特徴対象者個人番号
               JOTAI_KBN           = NwJOTAI_KBN,                     -- 特徴状態
               KISO_NENKIN_NO      = RTOKUHOSOKU.KISO_NENKIN_NO,      -- 基礎年金番号
               TOKU_GIMUSHA_CD     = RTOKUHOSOKU.TOKU_GIMUSHA_CD,     -- 特徴対象者義務者コード
               NENKIN_CD           = RTOKUHOSOKU.NENKIN_CD,           -- 年金コード
               KAISHI_TSUKI        = i_NwTUKI,                        -- 特徴開始月
               KAISHI_KIBETSU      = i_NwKIBETSU,                     -- 特徴開始期別
               TOKU_GIMUSHA_CD_4   = NwTOKU_GIMUSHA_CD_4,             -- 特徴義務者コード４～８月
               NENKIN_CD_4         = NwNENKIN_CD_4,                   -- 年金コード４～８月
               TOKU_GIMUSHA_CD_10  = NwTOKU_GIMUSHA_CD_10,            -- 特徴義務者コード10～２月
               NENKIN_CD_10        = NwNENKIN_CD_10,                  -- 年金コード10～２月
               IRAI_HIZUKE         = NwIRAI_HIZUKE,                   -- 依頼日
               SHURYO_TSUKI	       = 0,                               -- 特徴終了月
               SHURYO_KIBETSU	   = 0,                               -- 特徴終了期別
               CHUSHI_JIYU	       = 0,                               -- 中止事由
               SYS_SAKUSEIBI       = NULL,                            -- 作成日
               SYS_KOSHINBI        = NULL,                            -- 更新日
               SYS_JIKAN           = NULL,                            -- システム時間
               SYS_SHOKUINKOJIN_NO = NULL,                            -- 職員番号
               SYS_TANMATSU_NO     = i_VTANMATSU                      -- 端末番号
         WHERE KOKU_SETAI_NO   = i_NSETAI                             -- 国保世帯番号
           AND SANTEIDANTAI_CD = i_NDANTAI                            -- 算定団体コード
           AND CHOTEI_NENDO    = i_NwFCHOTEINENDO                     -- 調定年度
           AND NENDO_BUN       = i_NwFNENDOBUN                        -- 年度分
           -- 現年度も翌年度も処理されるため通知書番号の分岐を行う
           AND ((i_NwFCHOTEINENDO =  i_NNENDO AND TSUCHI_NO = i_NTSUCHI_NO) OR
                (i_NwFCHOTEINENDO <> i_NNENDO AND TSUCHI_NO = NYOKU_TSUCHI_NO))
           AND SYS_TANMATSU_NO = i_VTANMATSU;                         -- 端末番号
      END IF;
    CLOSE CTOKUKIHON_CAL;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCSETTOKUKIHONCAL 計算特徴対象者テーブルセット（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCSETTOKUKIHONCAL;

-----------------------------------------------------------
--  7 計算特徴対象者テーブル作成
-----------------------------------------------------------
FUNCTION FUNCMAKETOKUKIHONCAL RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN  PLS_INTEGER := c_IRETOK;                           -- 戻り値

BEGIN
  BEGIN
    -- 7-1 現年分作成
    IF NGENNEN_KIBETSU <> 0 THEN
      IwRTN := FUNCSETTOKUKIHONCAL(i_NNENDO,
                                  i_NNENDO_BUN,
                                  NGENNEN_TUKI,
                                  NGENNEN_KIBETSU);
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCMAKETOKUKIHONCAL 計算特徴対象者テーブル作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
    END IF;
    -- 7-2 翌年分作成
    IF NYOKUNEN_KIBETSU <> 0 THEN
      IwRTN := FUNCSETTOKUKIHONCAL(i_NNENDO + 1,
                                  i_NNENDO_BUN + 1,
                                  NYOKUNEN_TUKI,
                                  NYOKUNEN_KIBETSU);
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCMAKETOKUKIHONCAL 計算特徴対象者テーブル作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKETOKUKIHONCAL 計算特徴対象者テーブル作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKETOKUKIHONCAL;

-----------------------------------------------------------
--  8-1A,8-2A,8-5 計算テーブル取得
-----------------------------------------------------------
FUNCTION FUNCGETCAL(i_NwCHOTEINENDO IN  NUMBER,
                    i_NwNENDOBUN    IN  NUMBER) RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN  PLS_INTEGER := c_IRETOK;                           -- 戻り値

BEGIN
  -- 計算基本取得
  BEGIN
    SELECT * INTO RKIHONCAL FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI           -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI          -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO    -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN       -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO       -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;       -- 端末番号
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETCAL 計算基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

  -- 計算退職取得
  BEGIN
    SELECT * INTO RTAICAL FROM ZLBTTAI_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI          -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI         -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO   -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN      -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO      -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;      -- 端末番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RTAICAL.NENZEI        := 0;
      RTAICAL.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETCAL 計算退職取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

  -- 計算介護基本取得
  BEGIN
    SELECT * INTO RKAIKIHONCAL FROM ZLBTKAI_KIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI          -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI         -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO   -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN      -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO      -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;      -- 端末番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RKAIKIHONCAL.NENZEI        := 0;
      RKAIKIHONCAL.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETCAL 計算介護基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

  -- 計算介護退職取得
  BEGIN
    SELECT * INTO RKAITAICAL FROM ZLBTKAI_TAI_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO     -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN        -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;        -- 端末番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RKAITAICAL.NENZEI        := 0;
      RKAITAICAL.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETCAL 計算介護退職取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

  -- 計算支援基本取得
  BEGIN
    SELECT * INTO RSIENKIHONCAL FROM ZLBTSIEN_KIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI           -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI          -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO    -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN       -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO       -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;       -- 端末番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RSIENKIHONCAL.NENZEI        := 0;
      RSIENKIHONCAL.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETCAL 計算支援基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

  -- 計算支援退職取得
  BEGIN
    SELECT * INTO RSIENTAICAL FROM ZLBTSIEN_TAI_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI             -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI            -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO      -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN         -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO         -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;         -- 端末番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RSIENTAICAL.NENZEI        := 0;
      RSIENTAICAL.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETCAL 計算支援退職取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
  -- 計算子ども基本取得
  BEGIN
    SELECT * INTO RKDMKIHONCAL FROM ZLBTKDM_KIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI             -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI            -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO      -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN         -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO         -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;         -- 端末番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RKDMKIHONCAL.NENZEI        := 0;
      RKDMKIHONCAL.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETCAL 計算子ども基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;
-- 2025/08/11 ZCZL.LISHUAI ADD END
  --処理終了
  <<ERROR_INIT>>
  RETURN IwRTN;
END FUNCGETCAL;

-----------------------------------------------------------
--  8-8A  前年度の賦課基本テーブル取得 ※現在の主個人番号で取得
-----------------------------------------------------------
FUNCTION FUNCGETN(i_NwCHOTEINENDO IN  NUMBER,
                  i_NwNENDOBUN    IN  NUMBER) RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN                PLS_INTEGER := c_IRETOK;             -- 戻り値
  NwKOJIN_NO           NUMBER;                              -- 世帯主個人番号

BEGIN
  -- 世帯主個人番号 取得
  IwRTN := FUNCGETNUSHI_KOJIN_NO(NwKOJIN_NO);
  IF IwRTN <> c_IRETOK THEN
    IwRTN := c_IRETNG;
    VERROR := VERROR || 'FUNCGETN 賦課基本取得（国保世帯番号='|| i_NSETAI ||' FUNCGETNUSHI_KOJIN_NO ERR）';
    GOTO ERROR_INIT;
  END IF;

  -- 賦課基本取得
  BEGIN
    SELECT * INTO RKIHONN FROM ZLBTKIHON_N
     WHERE KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO     -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN        -- 年度分
       AND NUSHI_KOJIN_NO  = NwKOJIN_NO;         -- 個人番号
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETN 賦課基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

  -- 賦課退職基本取得
  BEGIN
    SELECT * INTO RTAIN FROM ZLBTTAI_N
     WHERE KOKU_SETAI_NO   = i_NSETAI               -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI              -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO        -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN           -- 年度分
       AND TSUCHI_NO       = RKIHONN.TSUCHI_NO;     -- 通知書番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RTAIN.NENZEI        := 0;
      RTAIN.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETN 賦課退職基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

  -- 賦課介護基本取得
  BEGIN
    SELECT * INTO RKAIKIHONN FROM ZLBTKAI_KIHON_N
     WHERE KOKU_SETAI_NO   = i_NSETAI               -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI              -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO        -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN           -- 年度分
       AND TSUCHI_NO       = RKIHONN.TSUCHI_NO;     -- 通知書番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RKAIKIHONN.NENZEI        := 0;
      RKAIKIHONN.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETN 賦課介護基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

  -- 賦課介護退職基本取得
  BEGIN
    SELECT * INTO RKAITAIN FROM ZLBTKAI_TAI_N
     WHERE KOKU_SETAI_NO   = i_NSETAI               -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI              -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO        -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN           -- 年度分
       AND TSUCHI_NO       = RKIHONN.TSUCHI_NO;     -- 通知書番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RKAITAIN.NENZEI        := 0;
      RKAITAIN.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETN 賦課介護退職基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

  -- 賦課支援基本取得
  BEGIN
    SELECT * INTO RSIENKIHONN FROM ZLBTSIEN_KIHON_N
     WHERE KOKU_SETAI_NO   = i_NSETAI                 -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI                -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO          -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN             -- 年度分
       AND TSUCHI_NO       = RKIHONN.TSUCHI_NO;       -- 通知書番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RSIENKIHONN.NENZEI        := 0;
      RSIENKIHONN.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETN 賦課支援基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

  -- 賦課支援退職基本取得
  BEGIN
    SELECT * INTO RSIENTAIN FROM ZLBTSIEN_TAI_N
     WHERE KOKU_SETAI_NO   = i_NSETAI              -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI             -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO       -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN          -- 年度分
       AND TSUCHI_NO       = RKIHONN.TSUCHI_NO;    -- 通知書番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RSIENTAIN.NENZEI        := 0;
      RSIENTAIN.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETN 計算支援退職基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;

-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
  -- 賦課子ども基本取得
  BEGIN
    SELECT * INTO RKDMKIHONN FROM ZLBTKDM_KIHON_N
     WHERE KOKU_SETAI_NO   = i_NSETAI              -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI             -- 算定団体コード
       AND CHOTEI_NENDO    = i_NwCHOTEINENDO       -- 調定年度
       AND NENDO_BUN       = i_NwNENDOBUN          -- 年度分
       AND TSUCHI_NO       = RKIHONN.TSUCHI_NO;    -- 通知書番号
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RKDMKIHONN.NENZEI        := 0;
      RKDMKIHONN.TSUKIWARI_GEN := 0;
    WHEN OTHERS THEN
      IwRTN := c_IRETNG;
      VERROR := VERROR || 'FUNCGETN 賦課子ども基本取得（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
      GOTO ERROR_INIT;
  END;
-- 2025/08/11 ZCZL.LISHUAI ADD END
  --処理終了
  <<ERROR_INIT>>
  RETURN IwRTN;
END FUNCGETN;

-----------------------------------------------------------
--  8-3C 翌年度期別作成(特徴11期存在した場合)
-----------------------------------------------------------
FUNCTION FUNCMAKEKIBETSU_ARI(i_NwZEN_ZEIGAKU  IN  NUMBER,
                             i_NwTAI_ZEIGAKU  IN  NUMBER) RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN        PLS_INTEGER := c_IRETOK;                     -- 戻り値
  RwKIBETSUCAL ZLBTKIBETSU_CAL%ROWTYPE;               -- 計算期別作成用ワーク

BEGIN
  BEGIN
    -- 計算期別レコードInsert
    RwKIBETSUCAL.KAMOKU_CD            := c_NKAMOKU_CD;                   -- 科目コード
    RwKIBETSUCAL.KAMOKUS_CD           := c_NKAMOKUS_CD2;                 -- 科目詳細コード【特徴】
    RwKIBETSUCAL.KOKU_SETAI_NO        := RKIHONCAL.KOKU_SETAI_NO;        -- 国保世帯番号
    RwKIBETSUCAL.SANTEIDANTAI_CD      := RKIHONCAL.SANTEIDANTAI_CD;      -- 算定団体コード
    RwKIBETSUCAL.KIWARIDANTAI_CD      := 0;                              -- 期割団体コード
    RwKIBETSUCAL.DANTAING_KBN         := 0;                              -- 団体内外区分
    RwKIBETSUCAL.GENNENKANEN_KBN      := 0;                              -- 現年過年区分
    RwKIBETSUCAL.CHOTEINENDO          := RKIHONCAL.CHOTEI_NENDO + 1;     -- 調停年度
    RwKIBETSUCAL.NENDOBUN             := RKIHONCAL.NENDO_BUN + 1;        -- 年度分
    RwKIBETSUCAL.TSUCHI_NO            := NYOKU_TSUCHI_NO;                -- 翌年度通知書番号
    RwKIBETSUCAL.R_NO                 := NYOKURNO;                       -- 履歴番号
    RwKIBETSUCAL.NUSHI_KOJIN_NO       := RTOKUHOSOKU.TOKU_KOJIN_NO;      -- 納税義務者個人番号
    RwKIBETSUCAL.KOSEI_BI             := NKOSEIBI;                       -- 更正日
    RwKIBETSUCAL.ZEN_ZEIGAKU          := i_NwZEN_ZEIGAKU;                -- 全体税額
    RwKIBETSUCAL.TAI_ZEIGAKU          := i_NwTAI_ZEIGAKU;                -- 退職税額
    RwKIBETSUCAL.IR_ZEN_ZEIGAKU       := 0;                              -- 医療全体税額
    RwKIBETSUCAL.IR_TAI_ZEIGAKU       := 0;                              -- 医療退職税額
    RwKIBETSUCAL.KAI_ZEN_ZEIGAKU      := 0;                              -- 介護全体税額
    RwKIBETSUCAL.KAI_TAI_ZEIGAKU      := 0;                              -- 介護退職税額
    RwKIBETSUCAL.SIEN_ZEN_ZEIGAKU     := 0;                              -- 支援全体税額
    RwKIBETSUCAL.SIEN_TAI_ZEIGAKU     := 0;                              -- 支援退職税額
    RwKIBETSUCAL.IR_ZEN_FNKSNGAKU     := 0;                              -- 不能欠損額（医療全体）
    RwKIBETSUCAL.IR_TAI_FNKSNGAKU     := 0;                              -- 不能欠損額（医療退職）
    RwKIBETSUCAL.KAI_ZEN_FNKSNGAKU    := 0;                              -- 不能欠損額（介護全体）
    RwKIBETSUCAL.KAI_TAI_FNKSNGAKU    := 0;                              -- 不能欠損額（介護退職）
    RwKIBETSUCAL.SIEN_ZEN_FNKSNGAKU   := 0;                              -- 不能欠損額（支援全体）
    RwKIBETSUCAL.SIEN_TAI_FNKSNGAKU   := 0;                              -- 不能欠損額（支援退職）
    RwKIBETSUCAL.KOJISOTATSU_KBN      := 0;                              -- 公示送達区分
    RwKIBETSUCAL.SYS_SAKUSEIBI        := NULL;                           -- 作成日
    RwKIBETSUCAL.SYS_KOSHINBI         := NULL;                           -- 更新日
    RwKIBETSUCAL.SYS_JIKAN            := NULL;                           -- システム時間
    RwKIBETSUCAL.SYS_SHOKUINKOJIN_NO  := NULL;                           -- 職員番号
    RwKIBETSUCAL.SYS_TANMATSU_NO      := i_VTANMATSU;                    -- 端末番号
-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
    RwKIBETSUCAL.KDM_ZEN_ZEIGAKU      := 0;                              --子ども全体税額
    RwKIBETSUCAL.KDM_ZEN_FNKSNGAKU    := 0;                              --不能欠損額（子ども全体）
-- 2025/08/11 ZCZL.LISHUAI ADD END

    IF i_NTOKU_TUKI IN(10,12,2,104) THEN
      FOR NIX IN 1..3 LOOP
        DELETE FROM ZLBTKIBETSU_CAL
          WHERE KAMOKU_CD       = c_NKAMOKU_CD                 -- 科目コード
            AND KAMOKUS_CD      = c_NKAMOKUS_CD2               -- 科目詳細コード【特徴】
            AND KOKU_SETAI_NO   = RKIHONCAL.KOKU_SETAI_NO      -- 国保世帯番号
            AND SANTEIDANTAI_CD = RKIHONCAL.SANTEIDANTAI_CD    -- 算定団体コード
            AND CHOTEINENDO     = RKIHONCAL.CHOTEI_NENDO + 1   -- 調停年度
            AND NENDOBUN        = RKIHONCAL.NENDO_BUN + 1      -- 年度分
-- 主変更されて同一年度内に新主で昨朝開始する際、Deleteレコードは旧主になっている
            AND RONRIKIBETSU    = NIX * 2 - 1
            AND SYS_TANMATSU_NO = i_VTANMATSU;
        RwKIBETSUCAL.RONRIKIBETSU     := NIX * 2 - 1;
        RwKIBETSUCAL.NENGETSU         := (RKIHONCAL.CHOTEI_NENDO + 1) * 100 + (NIX + 1) * 2;
        INSERT INTO ZLBTKIBETSU_CAL VALUES RwKIBETSUCAL;
      END LOOP;
    ELSIF i_NTOKU_TUKI = 106 THEN
      FOR NIX IN 1..2 LOOP
        DELETE FROM ZLBTKIBETSU_CAL
          WHERE KAMOKU_CD       = c_NKAMOKU_CD                 -- 科目コード
            AND KAMOKUS_CD      = c_NKAMOKUS_CD2               -- 科目詳細コード【特徴】
            AND KOKU_SETAI_NO   = RKIHONCAL.KOKU_SETAI_NO      -- 国保世帯番号
            AND SANTEIDANTAI_CD = RKIHONCAL.SANTEIDANTAI_CD    -- 算定団体コード
            AND CHOTEINENDO     = RKIHONCAL.CHOTEI_NENDO + 1   -- 調停年度
            AND NENDOBUN        = RKIHONCAL.NENDO_BUN + 1      -- 年度分
-- 主変更されて同一年度内に新主で昨朝開始する際、Deleteレコードは旧主になっている
            AND RONRIKIBETSU    = NIX * 2 + 1
            AND SYS_TANMATSU_NO = i_VTANMATSU;
        RwKIBETSUCAL.RONRIKIBETSU     := NIX * 2 + 1;
        RwKIBETSUCAL.NENGETSU         := (RKIHONCAL.CHOTEI_NENDO + 1) * 100 + (NIX + 2) * 2;
        INSERT INTO ZLBTKIBETSU_CAL VALUES RwKIBETSUCAL;
      END LOOP;
    ELSIF i_NTOKU_TUKI = 108 THEN
      FOR NIX IN 2..2 LOOP
        DELETE FROM ZLBTKIBETSU_CAL
          WHERE KAMOKU_CD       = c_NKAMOKU_CD                 -- 科目コード
            AND KAMOKUS_CD      = c_NKAMOKUS_CD2               -- 科目詳細コード【特徴】
            AND KOKU_SETAI_NO   = RKIHONCAL.KOKU_SETAI_NO      -- 国保世帯番号
            AND SANTEIDANTAI_CD = RKIHONCAL.SANTEIDANTAI_CD    -- 算定団体コード
            AND CHOTEINENDO     = RKIHONCAL.CHOTEI_NENDO + 1   -- 調定年度
            AND NENDOBUN        = RKIHONCAL.NENDO_BUN + 1      -- 年度分
            AND RONRIKIBETSU    = NIX * 2 + 1
            AND SYS_TANMATSU_NO = i_VTANMATSU;
        RwKIBETSUCAL.RONRIKIBETSU     := NIX * 2 + 1;
        RwKIBETSUCAL.NENGETSU         := (RKIHONCAL.CHOTEI_NENDO + 1) * 100 + (NIX + 2) * 2;
        INSERT INTO ZLBTKIBETSU_CAL VALUES RwKIBETSUCAL;
      END LOOP;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKEKIBETSU_ARI 翌年度期別作成(特徴11期存在した場合)（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKEKIBETSU_ARI;

-----------------------------------------------------------
--  8-3B 翌年度期別作成(特徴11期存在しない場合)
-----------------------------------------------------------
FUNCTION FUNCMAKEKIBETSU_NASI(i_NwZEN_ZEIGAKU  IN  NUMBER) RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN          PLS_INTEGER := c_IRETOK;                   -- 戻り値
  RwKIBETSUCAL   ZLBTKIBETSU_CAL%ROWTYPE;             -- 計算期別作成用ワーク
  NwZEN_KIWARI   NUMBER;                                    -- 全体年税額
  NwTAI_KIWARI   NUMBER;                                    -- 退職年税額
  NwZEN_ZEIGAKU  NUMBER;                                    -- 1期分 全体額
  NwTAI_ZEIGAKU  NUMBER;                                    --       退職額
  NKIWARIKEISU   NUMBER(2):= 6;                             -- 期割係数
  NFFJKN2        NUMBER:= 0;
BEGIN
  BEGIN
  NFFJKN2 := ZLBPK00010.FCFFJKN2(91);
 IF  NFFJKN2 = 1 AND i_NTOKU_TUKI = 106 THEN
   NKIWARIKEISU := 5;
 ELSIF NFFJKN2 = 1 AND i_NTOKU_TUKI = 108 THEN
   NKIWARIKEISU := 4;
 END IF;
    -- 全体年税額 算出
  IF i_NwZEN_ZEIGAKU = 0 THEN --10月の金額がない＝捕捉用
    NwZEN_KIWARI  := RKIHONCAL.NENZEI
                   + RKAIKIHONCAL.NENZEI
-- 2025/08/11 ZCZL.LISHUAI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                    + RSIENKIHONCAL.NENZEI;
                   + RSIENKIHONCAL.NENZEI
                   + RKDMKIHONCAL.NENZEI;
-- 2025/08/11 ZCZL.LISHUAI UPDATE END
    -- 1期分 全体額算出
    NwZEN_ZEIGAKU := TRUNC(ROUND(NwZEN_KIWARI / NKIWARIKEISU) / 100) * 100;
    -- 退職年税額 算出
    NwTAI_KIWARI  := RTAICAL.NENZEI
                   + RKAITAICAL.NENZEI
                   + RSIENTAICAL.NENZEI;
    -- 1期分 退職額算出
    NwTAI_ZEIGAKU := TRUNC(ROUND(NwTAI_KIWARI / NKIWARIKEISU) / 100) * 100;
  ELSE --7期の金額があって11期の金額がない＝300円未満
    NwZEN_ZEIGAKU := 0;
    NwTAI_ZEIGAKU := 0;
  END IF;
    -- 計算期別レコードInsert
    RwKIBETSUCAL.KAMOKU_CD            := c_NKAMOKU_CD;                  -- 科目コード
    RwKIBETSUCAL.KAMOKUS_CD           := c_NKAMOKUS_CD2;                -- 科目詳細コード【特徴】
    RwKIBETSUCAL.KOKU_SETAI_NO        := RKIHONCAL.KOKU_SETAI_NO;       -- 国保世帯番号
    RwKIBETSUCAL.SANTEIDANTAI_CD      := RKIHONCAL.SANTEIDANTAI_CD;     -- 算定団体コード
    RwKIBETSUCAL.KIWARIDANTAI_CD      := 0;                             -- 期割団体コード
    RwKIBETSUCAL.DANTAING_KBN         := 0;                             -- 団体内外区分
    RwKIBETSUCAL.GENNENKANEN_KBN      := 0;                             -- 現年過年区分
    RwKIBETSUCAL.CHOTEINENDO          := RKIHONCAL.CHOTEI_NENDO + 1;    -- 調停年度
    RwKIBETSUCAL.NENDOBUN             := RKIHONCAL.NENDO_BUN + 1;       -- 年度分
    RwKIBETSUCAL.TSUCHI_NO            := NYOKU_TSUCHI_NO;               -- 翌年度通知書番号
    RwKIBETSUCAL.R_NO                 := NYOKURNO;                      -- 履歴番号
    RwKIBETSUCAL.NUSHI_KOJIN_NO       := RTOKUHOSOKU.TOKU_KOJIN_NO;     -- 納税義務者個人番号
    RwKIBETSUCAL.KOSEI_BI             := NKOSEIBI;                      -- 更正日
    RwKIBETSUCAL.ZEN_ZEIGAKU          := NwZEN_ZEIGAKU;                 -- 全体税額
    RwKIBETSUCAL.TAI_ZEIGAKU          := NwTAI_ZEIGAKU;                 -- 退職税額
    RwKIBETSUCAL.IR_ZEN_ZEIGAKU       := 0;                             -- 医療全体税額
    RwKIBETSUCAL.IR_TAI_ZEIGAKU       := 0;                             -- 医療退職税額
    RwKIBETSUCAL.KAI_ZEN_ZEIGAKU      := 0;                             -- 介護全体税額
    RwKIBETSUCAL.KAI_TAI_ZEIGAKU      := 0;                             -- 介護退職税額
    RwKIBETSUCAL.SIEN_ZEN_ZEIGAKU     := 0;                             -- 支援全体税額
    RwKIBETSUCAL.SIEN_TAI_ZEIGAKU     := 0;                             -- 支援退職税額
    RwKIBETSUCAL.IR_ZEN_FNKSNGAKU     := 0;                             -- 不能欠損額（医療全体）
    RwKIBETSUCAL.IR_TAI_FNKSNGAKU     := 0;                             -- 不能欠損額（医療退職）
    RwKIBETSUCAL.KAI_ZEN_FNKSNGAKU    := 0;                             -- 不能欠損額（介護全体）
    RwKIBETSUCAL.KAI_TAI_FNKSNGAKU    := 0;                             -- 不能欠損額（介護退職）
    RwKIBETSUCAL.SIEN_ZEN_FNKSNGAKU   := 0;                             -- 不能欠損額（支援全体）
    RwKIBETSUCAL.SIEN_TAI_FNKSNGAKU   := 0;                             -- 不能欠損額（支援退職）
    RwKIBETSUCAL.KOJISOTATSU_KBN      := 0;                             -- 公示送達区分
    RwKIBETSUCAL.SYS_SAKUSEIBI        := NULL;                          -- 作成日
    RwKIBETSUCAL.SYS_KOSHINBI         := NULL;                          -- 更新日
    RwKIBETSUCAL.SYS_JIKAN            := NULL;                          -- システム時間
    RwKIBETSUCAL.SYS_SHOKUINKOJIN_NO  := NULL;                          -- 職員番号
    RwKIBETSUCAL.SYS_TANMATSU_NO      := i_VTANMATSU;                   -- 端末番号
-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
    RwKIBETSUCAL.KDM_ZEN_ZEIGAKU      := 0;                             --子ども全体税額
    RwKIBETSUCAL.KDM_ZEN_FNKSNGAKU    := 0;                             --不能欠損額（子ども全体）
-- 2025/08/11 ZCZL.LISHUAI ADD END

    IF i_NTOKU_TUKI IN(10,12,2,104) THEN
      FOR NIX IN 1..3 LOOP
        DELETE FROM ZLBTKIBETSU_CAL
          WHERE KAMOKU_CD       = c_NKAMOKU_CD                  -- 科目コード
            AND KAMOKUS_CD      = c_NKAMOKUS_CD2                -- 科目詳細コード【特徴】
            AND KOKU_SETAI_NO   = RKIHONCAL.KOKU_SETAI_NO       -- 国保世帯番号
            AND SANTEIDANTAI_CD = RKIHONCAL.SANTEIDANTAI_CD     -- 算定団体コード
            AND CHOTEINENDO     = RKIHONCAL.CHOTEI_NENDO + 1    -- 調停年度
            AND NENDOBUN        = RKIHONCAL.NENDO_BUN + 1       -- 年度分
-- 主変更されて同一年度内に新主で昨朝開始する際、Deleteレコードは旧主になっている
            AND RONRIKIBETSU    = NIX * 2 - 1
            AND SYS_TANMATSU_NO = i_VTANMATSU;
        RwKIBETSUCAL.RONRIKIBETSU     := NIX * 2 - 1;
        RwKIBETSUCAL.NENGETSU         := (RKIHONCAL.CHOTEI_NENDO + 1) * 100 + (NIX + 1) * 2;

        INSERT INTO ZLBTKIBETSU_CAL VALUES RwKIBETSUCAL;

      END LOOP;
    ELSIF i_NTOKU_TUKI = 106 THEN
      FOR NIX IN 1..2 LOOP
        DELETE FROM ZLBTKIBETSU_CAL
          WHERE KAMOKU_CD       = c_NKAMOKU_CD                  -- 科目コード
            AND KAMOKUS_CD      = c_NKAMOKUS_CD2                -- 科目詳細コード【特徴】
            AND KOKU_SETAI_NO   = RKIHONCAL.KOKU_SETAI_NO       -- 国保世帯番号
            AND SANTEIDANTAI_CD = RKIHONCAL.SANTEIDANTAI_CD     -- 算定団体コード
            AND CHOTEINENDO     = RKIHONCAL.CHOTEI_NENDO + 1    -- 調停年度
            AND NENDOBUN        = RKIHONCAL.NENDO_BUN + 1       -- 年度分
-- 主変更されて同一年度内に新主で昨朝開始する際、Deleteレコードは旧主になっている
            AND RONRIKIBETSU    = NIX * 2 + 1
            AND SYS_TANMATSU_NO = i_VTANMATSU;
        RwKIBETSUCAL.RONRIKIBETSU     := NIX * 2 + 1;
        RwKIBETSUCAL.NENGETSU         := (RKIHONCAL.CHOTEI_NENDO + 1) * 100 + (NIX + 2) * 2;

        INSERT INTO ZLBTKIBETSU_CAL VALUES RwKIBETSUCAL;
      END LOOP;
    ELSIF i_NTOKU_TUKI = 108 THEN
      FOR NIX IN 2..2 LOOP
        DELETE FROM ZLBTKIBETSU_CAL
          WHERE KAMOKU_CD       = c_NKAMOKU_CD                 -- 科目コード
            AND KAMOKUS_CD      = c_NKAMOKUS_CD2               -- 科目詳細コード【特徴】
            AND KOKU_SETAI_NO   = RKIHONCAL.KOKU_SETAI_NO      -- 国保世帯番号
            AND SANTEIDANTAI_CD = RKIHONCAL.SANTEIDANTAI_CD    -- 算定団体コード
            AND CHOTEINENDO     = RKIHONCAL.CHOTEI_NENDO + 1   -- 調定年度
            AND NENDOBUN        = RKIHONCAL.NENDO_BUN + 1      -- 年度分
            AND RONRIKIBETSU    = NIX * 2 + 1
            AND SYS_TANMATSU_NO = i_VTANMATSU;
        RwKIBETSUCAL.RONRIKIBETSU     := NIX * 2 + 1;
        RwKIBETSUCAL.NENGETSU         := (RKIHONCAL.CHOTEI_NENDO + 1) * 100 + (NIX + 2) * 2;
        INSERT INTO ZLBTKIBETSU_CAL VALUES RwKIBETSUCAL;
      END LOOP;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKEKIBETSU_NASI 翌年度期別作成(特徴11期存在しない場合)（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKEKIBETSU_NASI;

-----------------------------------------------------------
--  8-3,6 翌年度期別作成
-----------------------------------------------------------
FUNCTION FUNCMAKEKIBETSU_YOKU RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN              PLS_INTEGER := c_IRETOK;               -- 戻り値

  CURSOR CKIBETSU_CAL IS
    SELECT * FROM  ZLBTKIBETSU_CAL
     WHERE KAMOKU_CD       = c_NKAMOKU_CD         -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD2       -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI             -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI            -- 算定団体コード
       AND CHOTEINENDO     = i_NNENDO             -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN         -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO         -- 通知書番号
       AND RONRIKIBETSU    = 11                   -- 論理期別
       AND SYS_TANMATSU_NO = i_VTANMATSU;         -- 端末番号

  RKIBETSU_CAL CKIBETSU_CAL%ROWTYPE;                        -- 計算期別取得用ワーク
  NwZEN_ZEIGAKU  NUMBER := 0;                   --1期分全体額
BEGIN
  BEGIN
    SELECT ZEN_ZEIGAKU into NwZEN_ZEIGAKU
      FROM  ZLBTKIBETSU_CAL
     WHERE KAMOKU_CD       = c_NKAMOKU_CD         -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD2       -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI             -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI            -- 算定団体コード
       AND CHOTEINENDO     = i_NNENDO             -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN         -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO         -- 通知書番号
       AND RONRIKIBETSU    = 7                    -- 論理期別
       AND SYS_TANMATSU_NO = i_VTANMATSU;         -- 端末番号
    --8-3A 翌年度通知書番号 取得
    SELECT NVL(MAX(R_NO),0)+10 INTO NYOKURNO
      FROM ZLBTKIHON_N
     WHERE KOKU_SETAI_NO   = i_NSETAI                   -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI                  -- 算定団体コード
-- 翌年度指定になっていない
       AND CHOTEI_NENDO    = i_NNENDO     + 1           -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1           -- 年度分
       AND TSUCHI_NO       = RKIHONCAL.YOKU_TSUCHI_NO;  -- 通知書番号

    OPEN CKIBETSU_CAL;
    FETCH CKIBETSU_CAL INTO RKIBETSU_CAL;
      IF CKIBETSU_CAL%NOTFOUND OR RKIBETSU_CAL.ZEN_ZEIGAKU = 0 THEN
        -- 8-3B 翌年度期別作成(特徴11期存在しない場合)
        IwRTN := FUNCMAKEKIBETSU_NASI(NwZEN_ZEIGAKU);
        IF IwRTN <> c_IRETOK THEN
          VERROR := VERROR || 'FUNCMAKEKIBETSU_YOKU 翌年度期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
          RETURN IwRTN;
        END IF;
      ELSE
        -- 8-3C 翌年度期別作成(特徴11期存在した場合)
        IwRTN := FUNCMAKEKIBETSU_ARI(RKIBETSU_CAL.ZEN_ZEIGAKU,
                                    RKIBETSU_CAL.TAI_ZEIGAKU);
        IF IwRTN <> c_IRETOK THEN
          VERROR := VERROR || 'FUNCMAKEKIBETSU_YOKU 翌年度期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
          RETURN IwRTN;
        END IF;
      END IF;
    CLOSE CKIBETSU_CAL;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKEKIBETSU_YOKU 翌年度期別作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKEKIBETSU_YOKU;

-----------------------------------------------------------
--  8-4D,8-9D  計算基本への書込み ※現年or翌年度作成
-----------------------------------------------------------
FUNCTION FUNCINSERTCAL(i_NwCHOTEI_NENDO IN  NUMBER,
                       i_NwNENDOBUN     IN  NUMBER,
                       i_NwIRY_ZEI      IN  NUMBER,
                       i_NwIRY_TAI_ZEI  IN  NUMBER,
                       i_NwKAI_ZEI      IN  NUMBER,
                       i_NwKAI_TAI_ZEI  IN  NUMBER,
                       i_NwSIEN_ZEI     IN  NUMBER,
                       i_NwSIEN_TAI_ZEI IN  NUMBER,
-- 2025/08/11 ZCZL.LISHUAI ADD 1.1.200.000:子ども子育て支援金対応
                       i_NwKDM_ZEI      IN  NUMBER,
                       i_NwRNO          IN  NUMBER) RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN       PLS_INTEGER := c_IRETOK;                      -- 戻り値
  RwKIHON_CAL ZLBTKIHON_CAL%ROWTYPE;                        -- 計算基本    出力用ワーク
  RwKAIKIHON_CAL ZLBTKAI_KIHON_CAL%ROWTYPE;                 -- 計算介護基本出力用ワーク
  RwSIENKIHON_CAL ZLBTSIEN_KIHON_CAL%ROWTYPE;               -- 計算支援基本出力用ワーク
-- 2025/08/11 ZCZL.LISHUAI ADD 1.1.200.000:子ども子育て支援金対応
  RwKDMKIHON_CAL   ZLBTKDM_KIHON_CAL%ROWTYPE;               -- 計算子ども基本出力用ワーク
  RwTAI_CAL   ZLBTTAI_CAL%ROWTYPE;                          -- 計算退職    出力用ワーク

BEGIN
  BEGIN
    -- 計算基本 作成
    RwKIHON_CAL.KOKU_SETAI_NO        := i_NSETAI;           -- 国保世帯番号
    RwKIHON_CAL.SANTEIDANTAI_CD      := i_NDANTAI;          -- 算定団体コード
    RwKIHON_CAL.CHOTEI_NENDO         := i_NwCHOTEI_NENDO;   -- 調停年度
    RwKIHON_CAL.NENDO_BUN            := i_NwNENDOBUN;       -- 年度分
    RwKIHON_CAL.R_NO                 := i_NwRNO;            -- 履歴番号
    IF i_NwCHOTEI_NENDO = i_NNENDO THEN
      -- 現年処理
      RwKIHON_CAL.TSUCHI_NO            := i_NTSUCHI_NO;     -- 通知書番号
    ELSE
      -- 翌年処理
      RwKIHON_CAL.TSUCHI_NO            := NYOKU_TSUCHI_NO;
    END IF;
    IF i_NwCHOTEI_NENDO = i_NNENDO THEN
      -- 現年処理
      RwKIHON_CAL.YOKU_TSUCHI_NO     := NYOKU_TSUCHI_NO;
    ELSE
      -- 翌年処理
      RwKIHON_CAL.YOKU_TSUCHI_NO     := 0;
    END IF;
    RwKIHON_CAL.IDO_JIYU             := c_NKASANTEI;        -- 事由
    RwKIHON_CAL.KOSEI_BI             := NKOSEIBI;           -- 更正日
    RwKIHON_CAL.KOSHIN_KBN           := 1;                  -- 更新区分
    RwKIHON_CAL.SHINKOKU_KBN         := 0;                  -- 申告区分
    RwKIHON_CAL.SHU_SHOTOKU_KBN      := 0;                  -- 主所得区分
    RwKIHON_CAL.GENZON_KBN           := 0;                  -- 現存区分
    RwKIHON_CAL.GISEI_KBN            := 0;                  -- 擬制区分
    RwKIHON_CAL.FUKA_KEIGEN_KBN      := 0;                  -- 賦課期日軽減区分
    RwKIHON_CAL.J_KAZEI_KBN          := 0;                  -- 住民税課税区分
    RwKIHON_CAL.JOTO_S_KBN           := 0;                  -- 譲渡世帯区分
    RwKIHON_CAL.ROJIN_S_KBN          := 0;                  -- 老人世帯区分
    RwKIHON_CAL.SENJU_S_KBN          := 0;                  -- 専従世帯区分
    RwKIHON_CAL.KEIGEN_SHINSEI_KBN   := 0;                  -- 軽減申請区分
    RwKIHON_CAL.SEISAN_KBN           := 0;                  -- 清算区分
    RwKIHON_CAL.KEIGEN_SHOTOKU       := 0;                  -- 軽減判定所得
    RwKIHON_CAL.YU_SHOTOKU_CNT       := 0;                  -- 有所得人員
    RwKIHON_CAL.SHOTOKU              := 0;                  -- 所得額
    RwKIHON_CAL.KAHYO                := 0;                  -- 課税標準額
    RwKIHON_CAL.SHOTOKU_WARI         := 0;                  -- 所得割額
    RwKIHON_CAL.SHISANZEI            := 0;                  -- 資産税額
    RwKIHON_CAL.SHISAN_WARI          := 0;                  -- 資産割額
    RwKIHON_CAL.BYODO_WARI           := 0;                  -- 平等割額
    RwKIHON_CAL.GENDO_CHOKA          := 0;                  -- 限度超過額
    RwKIHON_CAL.KEIGEN_K_WARI        := 0;                  -- 軽減均等割額
    RwKIHON_CAL.KEIGEN_B_WARI        := 0;                  -- 軽減平等割額
    RwKIHON_CAL.KEIGEN_K_6           := 0;                  -- 軽減均等6
    RwKIHON_CAL.KEIGEN_B_6           := 0;                  -- 軽減平等6
    RwKIHON_CAL.KEIGEN_K_4           := 0;                  -- 軽減均等4
    RwKIHON_CAL.KEIGEN_B_4           := 0;                  -- 軽減平等4
    RwKIHON_CAL.KEIGEN_K_2           := 0;                  -- 軽減均等2
    RwKIHON_CAL.KEIGEN_B_2           := 0;                  -- 軽減平等2
    RwKIHON_CAL.TSUKIWARI_GEN        := 0;                  -- 月割減額
    RwKIHON_CAL.HASU                 := 0;                  -- 端数
    RwKIHON_CAL.GENGAKU_KEI          := 0;                  -- 減額合計
    RwKIHON_CAL.GENMEN               := 0;                  -- 減免額
    RwKIHON_CAL.KANENDO              := 0;                  -- 過年度分
    RwKIHON_CAL.KEIGEN_4             := 0;                  -- 軽減4月
    RwKIHON_CAL.KEIGEN_5             := 0;                  -- 軽減5月
    RwKIHON_CAL.KEIGEN_6             := 0;                  -- 軽減6月
    RwKIHON_CAL.KEIGEN_7             := 0;                  -- 軽減7月
    RwKIHON_CAL.KEIGEN_8             := 0;                  -- 軽減8月
    RwKIHON_CAL.KEIGEN_9             := 0;                  -- 軽減9月
    RwKIHON_CAL.KEIGEN_10            := 0;                  -- 軽減10月
    RwKIHON_CAL.KEIGEN_11            := 0;                  -- 軽減11月
    RwKIHON_CAL.KEIGEN_12            := 0;                  -- 軽減12月
    RwKIHON_CAL.KEIGEN_1             := 0;                  -- 軽減1月
    RwKIHON_CAL.KEIGEN_2             := 0;                  -- 軽減2月
    RwKIHON_CAL.KEIGEN_3             := 0;                  -- 軽減3月
    RwKIHON_CAL.SYS_SAKUSEIBI        := NULL;               -- 作成日
    RwKIHON_CAL.SYS_KOSHINBI         := NULL;               -- 更新日
    RwKIHON_CAL.SYS_JIKAN            := NULL;               -- 更新時間
    RwKIHON_CAL.SYS_SHOKUINKOJIN_NO  := '0';                -- 更新職員個人番号
    RwKIHON_CAL.SYS_TANMATSU_NO      := i_VTANMATSU;        -- 更新端末番号
    IF i_NwIRY_TAI_ZEI = 0 THEN
      RwKIHON_CAL.SETAI_KBN          := 0; -- 一般世帯
    ELSIF i_NwIRY_TAI_ZEI <> 0 AND i_NwIRY_ZEI = i_NwIRY_TAI_ZEI THEN
      RwKIHON_CAL.SETAI_KBN          := 1; -- 退職単独世帯
    ELSIF i_NwIRY_TAI_ZEI <> 0 AND i_NwIRY_ZEI <> i_NwIRY_TAI_ZEI THEN
      RwKIHON_CAL.SETAI_KBN          := 2; -- 退職混合世帯
    ELSE
      RwKIHON_CAL.SETAI_KBN          := 0;
    END IF;
    RwKIHON_CAL.KINTO_WARI           := i_NwIRY_ZEI;        -- 均等割額
    RwKIHON_CAL.SEKISAN              := i_NwIRY_ZEI;        -- 積算税額
    RwKIHON_CAL.NENZEI               := i_NwIRY_ZEI;        -- 年税額

    -- 特徴月が8月の場合、前年度の賦課基本データをセット(現年度分の計算基本作成)
    IF (i_NTOKU_TUKI = 8) THEN
      RwKIHON_CAL.NUSHI_KOJIN_NO       := RKIHONN.NUSHI_KOJIN_NO;   -- 世帯主個人番号
      RwKIHON_CAL.FUKA_KIJITSU_CNT     := RKIHONN.FUKA_KIJITSU_CNT; -- 賦課期日人員
      RwKIHON_CAL.KINTO_CNT            := RKIHONN.KINTO_CNT;        -- 均等割額
      RwKIHON_CAL.GENZAI_CNT           := RKIHONN.GENZAI_CNT;       -- 現在人員
    ELSE --特徴月が8月以外は現年度の計算基本データをセット(翌年度分の計算基本作成)
      RwKIHON_CAL.NUSHI_KOJIN_NO       := RKIHONCAL.NUSHI_KOJIN_NO;   -- 世帯主個人番号
      RwKIHON_CAL.FUKA_KIJITSU_CNT     := RKIHONCAL.FUKA_KIJITSU_CNT; -- 賦課期日人員
      RwKIHON_CAL.KINTO_CNT            := RKIHONCAL.KINTO_CNT;        -- 均等割額
      RwKIHON_CAL.GENZAI_CNT           := RKIHONCAL.GENZAI_CNT;       -- 現在人員
    END IF;

    DELETE FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO   = RwKIHON_CAL.KOKU_SETAI_NO
       AND SANTEIDANTAI_CD = RwKIHON_CAL.SANTEIDANTAI_CD
       AND CHOTEI_NENDO    = RwKIHON_CAL.CHOTEI_NENDO
       AND NENDO_BUN       = RwKIHON_CAL.NENDO_BUN
       AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO
       AND SYS_TANMATSU_NO = RwKIHON_CAL.SYS_TANMATSU_NO;
    INSERT INTO ZLBTKIHON_CAL VALUES RwKIHON_CAL;

      -- 計算介護基本 作成
      RwKAIKIHON_CAL.KOKU_SETAI_NO        := i_NSETAI;            -- 国保世帯番号
      RwKAIKIHON_CAL.SANTEIDANTAI_CD      := i_NDANTAI;           -- 算定団体コード
      RwKAIKIHON_CAL.CHOTEI_NENDO         := i_NwCHOTEI_NENDO;    -- 調停年度
      RwKAIKIHON_CAL.NENDO_BUN            := i_NwNENDOBUN;        -- 年度分
      RwKAIKIHON_CAL.R_NO                 := i_NwRNO;             -- 履歴番号
      IF i_NwCHOTEI_NENDO = i_NNENDO THEN
        -- 現年処理
        RwKAIKIHON_CAL.TSUCHI_NO          := i_NTSUCHI_NO;        -- 通知書番号
      ELSE
        -- 翌年処理
        RwKAIKIHON_CAL.TSUCHI_NO          := NYOKU_TSUCHI_NO;
      END IF;
      RwKAIKIHON_CAL.IDO_JIYU             := c_NKASANTEI;         -- 事由
      RwKAIKIHON_CAL.KOSEI_BI             := NKOSEIBI;            -- 更正日
      RwKAIKIHON_CAL.KOSHIN_KBN           := 1;                   -- 更新区分
      RwKAIKIHON_CAL.SHINKOKU_KBN         := 0;                   -- 申告区分
      RwKAIKIHON_CAL.SHU_SHOTOKU_KBN      := 0;                   -- 主所得区分
      RwKAIKIHON_CAL.GENZON_KBN           := 0;                   -- 現存区分
      RwKAIKIHON_CAL.GISEI_KBN            := 0;                   -- 擬制区分
      RwKAIKIHON_CAL.J_KAZEI_KBN          := 0;                   -- 住民税課税区分
      RwKAIKIHON_CAL.JOTO_S_KBN           := 0;                   -- 譲渡世帯区分
      RwKAIKIHON_CAL.ROJIN_S_KBN          := 0;                   -- 老人世帯区分
      RwKAIKIHON_CAL.SENJU_S_KBN          := 0;                   -- 専従世帯区分
      RwKAIKIHON_CAL.KEIGEN_SHINSEI_KBN   := 0;                   -- 軽減申請区分
      RwKAIKIHON_CAL.KEIGEN_SHOTOKU       := 0;                   -- 軽減判定所得
      RwKAIKIHON_CAL.YU_SHOTOKU_CNT       := 0;                   -- 有所得人員
      RwKAIKIHON_CAL.SHOTOKU              := 0;                   -- 所得額
      RwKAIKIHON_CAL.KAHYO                := 0;                   -- 課税標準額
      RwKAIKIHON_CAL.SHOTOKU_WARI         := 0;                   -- 所得割額
      RwKAIKIHON_CAL.SHISANZEI            := 0;                   -- 資産税額
      RwKAIKIHON_CAL.SHISAN_WARI          := 0;                   -- 資産割額
      RwKAIKIHON_CAL.BYODO_WARI           := 0;                   -- 平等割額
      RwKAIKIHON_CAL.GENDO_CHOKA          := 0;                   -- 限度超過額
      RwKAIKIHON_CAL.KEIGEN_K_WARI        := 0;                   -- 軽減均等割額
      RwKAIKIHON_CAL.KEIGEN_B_WARI        := 0;                   -- 軽減平等割額
      RwKAIKIHON_CAL.KEIGEN_K_6           := 0;                   -- 軽減均等6
      RwKAIKIHON_CAL.KEIGEN_B_6           := 0;                   -- 軽減平等6
      RwKAIKIHON_CAL.KEIGEN_K_4           := 0;                   -- 軽減均等4
      RwKAIKIHON_CAL.KEIGEN_B_4           := 0;                   -- 軽減平等4
      RwKAIKIHON_CAL.KEIGEN_K_2           := 0;                   -- 軽減均等2
      RwKAIKIHON_CAL.KEIGEN_B_2           := 0;                   -- 軽減平等2
      RwKAIKIHON_CAL.TSUKIWARI_GEN        := 0;                   -- 月割減額
      RwKAIKIHON_CAL.HASU                 := 0;                   -- 端数
      RwKAIKIHON_CAL.GENGAKU_KEI          := 0;                   -- 減額合計
      RwKAIKIHON_CAL.GENMEN               := 0;                   -- 減免額
      RwKAIKIHON_CAL.KANENDO              := 0;                   -- 過年度分
      RwKAIKIHON_CAL.KEIGEN_4             := 0;                   -- 軽減4月
      RwKAIKIHON_CAL.KEIGEN_5             := 0;                   -- 軽減5月
      RwKAIKIHON_CAL.KEIGEN_6             := 0;                   -- 軽減6月
      RwKAIKIHON_CAL.KEIGEN_7             := 0;                   -- 軽減7月
      RwKAIKIHON_CAL.KEIGEN_8             := 0;                   -- 軽減8月
      RwKAIKIHON_CAL.KEIGEN_9             := 0;                   -- 軽減9月
      RwKAIKIHON_CAL.KEIGEN_10            := 0;                   -- 軽減10月
      RwKAIKIHON_CAL.KEIGEN_11            := 0;                   -- 軽減11月
      RwKAIKIHON_CAL.KEIGEN_12            := 0;                   -- 軽減12月
      RwKAIKIHON_CAL.KEIGEN_1             := 0;                   -- 軽減1月
      RwKAIKIHON_CAL.KEIGEN_2             := 0;                   -- 軽減2月
      RwKAIKIHON_CAL.KEIGEN_3             := 0;                   -- 軽減3月
      RwKAIKIHON_CAL.SYS_SAKUSEIBI        := NULL;                -- 作成日
      RwKAIKIHON_CAL.SYS_KOSHINBI         := NULL;                -- 更新日
      RwKAIKIHON_CAL.SYS_JIKAN            := NULL;                -- 更新時間
      RwKAIKIHON_CAL.SYS_SHOKUINKOJIN_NO  := '0';                 -- 更新職員個人番号
      RwKAIKIHON_CAL.SYS_TANMATSU_NO      := i_VTANMATSU;         -- 更新端末番号
      IF i_NwKAI_TAI_ZEI = 0 THEN
        RwKAIKIHON_CAL.SETAI_KBN          := 0; -- 一般世帯
      ELSIF i_NwKAI_TAI_ZEI <> 0 AND i_NwKAI_ZEI = i_NwKAI_TAI_ZEI THEN
        RwKAIKIHON_CAL.SETAI_KBN          := 1; -- 退職単独世帯
      ELSIF i_NwKAI_TAI_ZEI <> 0 AND i_NwKAI_ZEI <> i_NwKAI_TAI_ZEI THEN
        RwKAIKIHON_CAL.SETAI_KBN          := 2; -- 退職混合世帯
      ELSE
        RwKAIKIHON_CAL.SETAI_KBN          := 0;
      END IF;
      RwKAIKIHON_CAL.KINTO_WARI           := i_NwKAI_ZEI;         -- 均等割額
      RwKAIKIHON_CAL.SEKISAN              := i_NwKAI_ZEI;         -- 積算税額
      RwKAIKIHON_CAL.NENZEI               := i_NwKAI_ZEI;         -- 年税額

      -- 特徴月が8月の場合、前年度の賦課介護データをセット(現年度分の計算介護作成)
      IF (i_NTOKU_TUKI = 8) THEN
        RwKAIKIHON_CAL.NUSHI_KOJIN_NO       := NVL(RKAIKIHONN.NUSHI_KOJIN_NO, 0);      -- 世帯主個人番号
        RwKAIKIHON_CAL.FUKA_KIJITSU_CNT     := NVL(RKAIKIHONN.FUKA_KIJITSU_CNT, 0);    -- 賦課期日人員
        RwKAIKIHON_CAL.KINTO_CNT            := NVL(RKAIKIHONN.KINTO_CNT, 0);           -- 均等割額
        RwKAIKIHON_CAL.GENZAI_CNT           := NVL(RKAIKIHONN.GENZAI_CNT, 0);          -- 現在人員
      ELSE --特徴月が8月以外は現年度の計算介護データをセット(翌年度分の計算介護作成)
        RwKAIKIHON_CAL.NUSHI_KOJIN_NO       := NVL(RKAIKIHONCAL.NUSHI_KOJIN_NO, 0);    -- 世帯主個人番号
        RwKAIKIHON_CAL.FUKA_KIJITSU_CNT     := NVL(RKAIKIHONCAL.FUKA_KIJITSU_CNT, 0);  -- 賦課期日人員
        RwKAIKIHON_CAL.KINTO_CNT            := NVL(RKAIKIHONCAL.KINTO_CNT, 0);         -- 均等割額
        RwKAIKIHON_CAL.GENZAI_CNT           := NVL(RKAIKIHONCAL.GENZAI_CNT, 0);        -- 現在人員
      END IF;

      DELETE FROM ZLBTKAI_KIHON_CAL
       WHERE KOKU_SETAI_NO   = RwKIHON_CAL.KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = RwKIHON_CAL.SANTEIDANTAI_CD
         AND CHOTEI_NENDO    = RwKIHON_CAL.CHOTEI_NENDO
         AND NENDO_BUN       = RwKIHON_CAL.NENDO_BUN
         AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO
         AND SYS_TANMATSU_NO = RwKIHON_CAL.SYS_TANMATSU_NO;
      INSERT INTO ZLBTKAI_KIHON_CAL VALUES RwKAIKIHON_CAL;

      -- 計算支援基本 作成
      RwSIENKIHON_CAL.KOKU_SETAI_NO        := i_NSETAI;              -- 国保世帯番号
      RwSIENKIHON_CAL.SANTEIDANTAI_CD      := i_NDANTAI;             -- 算定団体コード
      RwSIENKIHON_CAL.CHOTEI_NENDO         := i_NwCHOTEI_NENDO;      -- 調停年度
      RwSIENKIHON_CAL.NENDO_BUN            := i_NwNENDOBUN;          -- 年度分
      RwSIENKIHON_CAL.R_NO                 := i_NwRNO;               -- 履歴番号
      IF i_NwCHOTEI_NENDO = i_NNENDO THEN
        -- 現年処理
        RwSIENKIHON_CAL.TSUCHI_NO          := i_NTSUCHI_NO;          -- 通知書番号
      ELSE
        -- 翌年処理
        RwSIENKIHON_CAL.TSUCHI_NO          := NYOKU_TSUCHI_NO;
      END IF;
      RwSIENKIHON_CAL.IDO_JIYU             := c_NKASANTEI;           -- 事由
      RwSIENKIHON_CAL.KOSEI_BI             := NKOSEIBI;              -- 更正日
      RwSIENKIHON_CAL.KOSHIN_KBN           := 1;                     -- 更新区分
      RwSIENKIHON_CAL.SHINKOKU_KBN         := 0;                     -- 申告区分
      RwSIENKIHON_CAL.SHU_SHOTOKU_KBN      := 0;                     -- 主所得区分
      RwSIENKIHON_CAL.GENZON_KBN           := 0;                     -- 現存区分
      RwSIENKIHON_CAL.GISEI_KBN            := 0;                     -- 擬制区分
      RwSIENKIHON_CAL.J_KAZEI_KBN          := 0;                     -- 住民税課税区分
      RwSIENKIHON_CAL.JOTO_S_KBN           := 0;                     -- 譲渡世帯区分
      RwSIENKIHON_CAL.ROJIN_S_KBN          := 0;                     -- 老人世帯区分
      RwSIENKIHON_CAL.SENJU_S_KBN          := 0;                     -- 専従世帯区分
      RwSIENKIHON_CAL.KEIGEN_SHINSEI_KBN   := 0;                     -- 軽減申請区分
      RwSIENKIHON_CAL.KEIGEN_SHOTOKU       := 0;                     -- 軽減判定所得
      RwSIENKIHON_CAL.YU_SHOTOKU_CNT       := 0;                     -- 有所得人員
      RwSIENKIHON_CAL.SHOTOKU              := 0;                     -- 所得額
      RwSIENKIHON_CAL.KAHYO                := 0;                     -- 課税標準額
      RwSIENKIHON_CAL.SHOTOKU_WARI         := 0;                     -- 所得割額
      RwSIENKIHON_CAL.SHISANZEI            := 0;                     -- 資産税額
      RwSIENKIHON_CAL.SHISAN_WARI          := 0;                     -- 資産割額
      RwSIENKIHON_CAL.BYODO_WARI           := 0;                     -- 平等割額
      RwSIENKIHON_CAL.GENDO_CHOKA          := 0;                     -- 限度超過額
      RwSIENKIHON_CAL.KEIGEN_K_WARI        := 0;                     -- 軽減均等割額
      RwSIENKIHON_CAL.KEIGEN_B_WARI        := 0;                     -- 軽減平等割額
      RwSIENKIHON_CAL.KEIGEN_K_6           := 0;                     -- 軽減均等6
      RwSIENKIHON_CAL.KEIGEN_B_6           := 0;                     -- 軽減平等6
      RwSIENKIHON_CAL.KEIGEN_K_4           := 0;                     -- 軽減均等4
      RwSIENKIHON_CAL.KEIGEN_B_4           := 0;                     -- 軽減平等4
      RwSIENKIHON_CAL.KEIGEN_K_2           := 0;                     -- 軽減均等2
      RwSIENKIHON_CAL.KEIGEN_B_2           := 0;                     -- 軽減平等2
      RwSIENKIHON_CAL.TSUKIWARI_GEN        := 0;                     -- 月割減額
      RwSIENKIHON_CAL.HASU                 := 0;                     -- 端数
      RwSIENKIHON_CAL.GENGAKU_KEI          := 0;                     -- 減額合計
      RwSIENKIHON_CAL.GENMEN               := 0;                     -- 減免額
      RwSIENKIHON_CAL.KANENDO              := 0;                     -- 過年度分
      RwSIENKIHON_CAL.KEIGEN_4             := 0;                     -- 軽減4月
      RwSIENKIHON_CAL.KEIGEN_5             := 0;                     -- 軽減5月
      RwSIENKIHON_CAL.KEIGEN_6             := 0;                     -- 軽減6月
      RwSIENKIHON_CAL.KEIGEN_7             := 0;                     -- 軽減7月
      RwSIENKIHON_CAL.KEIGEN_8             := 0;                     -- 軽減8月
      RwSIENKIHON_CAL.KEIGEN_9             := 0;                     -- 軽減9月
      RwSIENKIHON_CAL.KEIGEN_10            := 0;                     -- 軽減10月
      RwSIENKIHON_CAL.KEIGEN_11            := 0;                     -- 軽減11月
      RwSIENKIHON_CAL.KEIGEN_12            := 0;                     -- 軽減12月
      RwSIENKIHON_CAL.KEIGEN_1             := 0;                     -- 軽減1月
      RwSIENKIHON_CAL.KEIGEN_2             := 0;                     -- 軽減2月
      RwSIENKIHON_CAL.KEIGEN_3             := 0;                     -- 軽減3月
      RwSIENKIHON_CAL.SYS_SAKUSEIBI        := NULL;                  -- 作成日
      RwSIENKIHON_CAL.SYS_KOSHINBI         := NULL;                  -- 更新日
      RwSIENKIHON_CAL.SYS_JIKAN            := NULL;                  -- 更新時間
      RwSIENKIHON_CAL.SYS_SHOKUINKOJIN_NO  := '0';                   -- 更新職員個人番号
      RwSIENKIHON_CAL.SYS_TANMATSU_NO      := i_VTANMATSU;           -- 更新端末番号
      IF i_NwSIEN_TAI_ZEI = 0 THEN
        RwSIENKIHON_CAL.SETAI_KBN          := 0; -- 一般世帯
      ELSIF i_NwSIEN_TAI_ZEI <> 0 AND i_NwSIEN_ZEI = i_NwSIEN_TAI_ZEI THEN
        RwSIENKIHON_CAL.SETAI_KBN          := 1; -- 退職単独世帯
      ELSIF i_NwSIEN_TAI_ZEI <> 0 AND i_NwSIEN_ZEI <> i_NwSIEN_TAI_ZEI THEN
        RwSIENKIHON_CAL.SETAI_KBN          := 2; -- 退職混合世帯
      ELSE
        RwSIENKIHON_CAL.SETAI_KBN          := 0;
      END IF;
      RwSIENKIHON_CAL.KINTO_WARI           := i_NwSIEN_ZEI;          -- 均等割額
      RwSIENKIHON_CAL.SEKISAN              := i_NwSIEN_ZEI;          -- 積算税額
      RwSIENKIHON_CAL.NENZEI               := i_NwSIEN_ZEI;          -- 年税額

      -- 特徴月が8月の場合、前年度の賦課支援データをセット(現年度分の計算支援基本作成)
      IF (i_NTOKU_TUKI = 8) THEN
        RwSIENKIHON_CAL.NUSHI_KOJIN_NO       := NVL(RSIENKIHONN.NUSHI_KOJIN_NO, 0);       -- 世帯主個人番号
        RwSIENKIHON_CAL.FUKA_KIJITSU_CNT     := NVL(RSIENKIHONN.FUKA_KIJITSU_CNT, 0);     -- 賦課期日人員
        RwSIENKIHON_CAL.KINTO_CNT            := NVL(RSIENKIHONN.KINTO_CNT, 0);            -- 均等割額
        RwSIENKIHON_CAL.GENZAI_CNT           := NVL(RSIENKIHONN.GENZAI_CNT, 0);           -- 現在人員
      ELSE --特徴月が8月以外は現年度の計算支援データをセット(翌年度分の計算支援基本作成)
        RwSIENKIHON_CAL.NUSHI_KOJIN_NO       := NVL(RSIENKIHONCAL.NUSHI_KOJIN_NO, 0);     -- 世帯主個人番号
        RwSIENKIHON_CAL.FUKA_KIJITSU_CNT     := NVL(RSIENKIHONCAL.FUKA_KIJITSU_CNT, 0);   -- 賦課期日人員
        RwSIENKIHON_CAL.KINTO_CNT            := NVL(RSIENKIHONCAL.KINTO_CNT, 0);          -- 均等割額
        RwSIENKIHON_CAL.GENZAI_CNT           := NVL(RSIENKIHONCAL.GENZAI_CNT, 0);         -- 現在人員
      END IF;

      DELETE FROM ZLBTSIEN_KIHON_CAL
       WHERE KOKU_SETAI_NO   = RwKIHON_CAL.KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = RwKIHON_CAL.SANTEIDANTAI_CD
         AND CHOTEI_NENDO    = RwKIHON_CAL.CHOTEI_NENDO
         AND NENDO_BUN       = RwKIHON_CAL.NENDO_BUN
         AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO
         AND SYS_TANMATSU_NO = RwKIHON_CAL.SYS_TANMATSU_NO;
      INSERT INTO ZLBTSIEN_KIHON_CAL VALUES RwSIENKIHON_CAL;

      -- 退職共通項目セット
      RwTAI_CAL.KOKU_SETAI_NO          := i_NSETAI;            -- 国保世帯番号
      RwTAI_CAL.SANTEIDANTAI_CD        := i_NDANTAI;           -- 算定団体コード
      RwTAI_CAL.CHOTEI_NENDO           := i_NwCHOTEI_NENDO;    -- 調停年度
      RwTAI_CAL.NENDO_BUN              := i_NwNENDOBUN;        -- 年度分
      RwTAI_CAL.R_NO                   := i_NwRNO;             -- 履歴番号
      IF i_NwCHOTEI_NENDO = i_NNENDO THEN
        -- 現年処理
        RwTAI_CAL.TSUCHI_NO            := i_NTSUCHI_NO;        -- 通知書番号
      ELSE
        -- 翌年処理
        RwTAI_CAL.TSUCHI_NO            := NYOKU_TSUCHI_NO;
      END IF;
      RwTAI_CAL.KEIGEN_SHOTOKU         := 0;                   -- 軽減判定所得
      RwTAI_CAL.YU_SHOTOKU_CNT         := 0;                   -- 有所得人員
      RwTAI_CAL.SHOTOKU                := 0;                   -- 所得額
      RwTAI_CAL.KAHYO                  := 0;                   -- 課税標準額
      RwTAI_CAL.SHOTOKU_WARI           := 0;                   -- 所得割額
      RwTAI_CAL.SHISANZEI              := 0;                   -- 資産税額
      RwTAI_CAL.SHISAN_WARI            := 0;                   -- 資産割額
      RwTAI_CAL.BYODO_WARI             := 0;                   -- 平等割額
      RwTAI_CAL.GENDO_CHOKA            := 0;                   -- 限度超過額
      RwTAI_CAL.KEIGEN_K_WARI          := 0;                   -- 軽減均等割額
      RwTAI_CAL.KEIGEN_B_WARI          := 0;                   -- 軽減平等割額
      RwTAI_CAL.KEIGEN_K_6             := 0;                   -- 軽減均等6
      RwTAI_CAL.KEIGEN_B_6             := 0;                   -- 軽減平等6
      RwTAI_CAL.KEIGEN_K_4             := 0;                   -- 軽減均等4
      RwTAI_CAL.KEIGEN_B_4             := 0;                   -- 軽減平等4
      RwTAI_CAL.KEIGEN_K_2             := 0;                   -- 軽減均等2
      RwTAI_CAL.KEIGEN_B_2             := 0;                   -- 軽減平等2
      RwTAI_CAL.TSUKIWARI_GEN          := 0;                   -- 月割減額
      RwTAI_CAL.HASU                   := 0;                   -- 端数
      RwTAI_CAL.GENGAKU_KEI            := 0;                   -- 減額合計
      RwTAI_CAL.GENMEN                 := 0;                   -- 減免額
      RwTAI_CAL.KANENDO                := 0;                   -- 過年度分
      RwTAI_CAL.SYS_SAKUSEIBI          := NULL;                -- 作成日
      RwTAI_CAL.SYS_KOSHINBI           := NULL;                -- 更新日
      RwTAI_CAL.SYS_JIKAN              := NULL;                -- 更新時間
      RwTAI_CAL.SYS_SHOKUINKOJIN_NO    := '0';                 -- 更新職員個人番号
      RwTAI_CAL.SYS_TANMATSU_NO        := i_VTANMATSU;         -- 更新端末番号

      -- 計算退職 作成
      RwTAI_CAL.KINTO_WARI             := i_NwIRY_TAI_ZEI;     -- 均等割額
      RwTAI_CAL.SEKISAN                := i_NwIRY_TAI_ZEI;     -- 積算税額
      RwTAI_CAL.NENZEI                 := i_NwIRY_TAI_ZEI;     -- 年税額

      -- 特徴月が8月の場合、前年度の賦課退職データをセット(現年度分の計算退職基本作成)
      IF (i_NTOKU_TUKI = 8) THEN
        RwTAI_CAL.FUKA_KIJITSU_CNT       := NVL(RTAIN.FUKA_KIJITSU_CNT, 0);      -- 賦課期日人員
        RwTAI_CAL.KINTO_CNT              := NVL(RTAIN.KINTO_CNT, 0);             -- 均等割額
        RwTAI_CAL.GENZAI_CNT             := NVL(RTAIN.GENZAI_CNT, 0);            -- 現在人員
      ELSE --特徴月が8月以外は現年度の計算退職データをセット(翌年度分の計算退職作成)
        RwTAI_CAL.FUKA_KIJITSU_CNT       := NVL(RTAICAL.FUKA_KIJITSU_CNT, 0);    -- 賦課期日人員
        RwTAI_CAL.KINTO_CNT              := NVL(RTAICAL.KINTO_CNT, 0);           -- 均等割額
        RwTAI_CAL.GENZAI_CNT             := NVL(RTAICAL.GENZAI_CNT, 0);          -- 現在人員
      END IF;

      DELETE FROM ZLBTTAI_CAL
       WHERE KOKU_SETAI_NO   = RwKIHON_CAL.KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = RwKIHON_CAL.SANTEIDANTAI_CD
         AND CHOTEI_NENDO    = RwKIHON_CAL.CHOTEI_NENDO
         AND NENDO_BUN       = RwKIHON_CAL.NENDO_BUN
         AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO
         AND SYS_TANMATSU_NO = RwKIHON_CAL.SYS_TANMATSU_NO;
      INSERT INTO ZLBTTAI_CAL VALUES RwTAI_CAL;

      -- 計算介護退職 作成
      RwTAI_CAL.KINTO_WARI             := i_NwKAI_TAI_ZEI;      -- 均等割額
      RwTAI_CAL.SEKISAN                := i_NwKAI_TAI_ZEI;      -- 積算税額
      RwTAI_CAL.NENZEI                 := i_NwKAI_TAI_ZEI;      -- 年税額
      -- 特徴月が8月の場合、前年度の賦課介護退職データをセット(現年度分の計算介護退職作成)
      IF (i_NTOKU_TUKI = 8) THEN
        RwTAI_CAL.FUKA_KIJITSU_CNT       := NVL(RKAITAIN.FUKA_KIJITSU_CNT, 0);    -- 賦課期日人員
        RwTAI_CAL.KINTO_CNT              := NVL(RKAITAIN.KINTO_CNT, 0);           -- 均等割額
        RwTAI_CAL.GENZAI_CNT             := NVL(RKAITAIN.GENZAI_CNT, 0);          -- 現在人員
      ELSE --特徴月が8月以外は現年度の計算介護退職データをセット(翌年度分の計算介護退職作成)
        RwTAI_CAL.FUKA_KIJITSU_CNT       := NVL(RKAITAICAL.FUKA_KIJITSU_CNT, 0);  -- 賦課期日人員
        RwTAI_CAL.KINTO_CNT              := NVL(RKAITAICAL.KINTO_CNT, 0);         -- 均等割額
        RwTAI_CAL.GENZAI_CNT             := NVL(RKAITAICAL.GENZAI_CNT, 0);        -- 現在人員
      END IF;

      DELETE FROM ZLBTKAI_TAI_CAL
       WHERE KOKU_SETAI_NO   = RwKIHON_CAL.KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = RwKIHON_CAL.SANTEIDANTAI_CD
         AND CHOTEI_NENDO    = RwKIHON_CAL.CHOTEI_NENDO
         AND NENDO_BUN       = RwKIHON_CAL.NENDO_BUN
         AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO
         AND SYS_TANMATSU_NO = RwKIHON_CAL.SYS_TANMATSU_NO;
      INSERT INTO ZLBTKAI_TAI_CAL VALUES RwTAI_CAL;

      -- 計算支援退職 作成
      RwTAI_CAL.KINTO_WARI             := i_NwSIEN_TAI_ZEI;      -- 均等割額
      RwTAI_CAL.SEKISAN                := i_NwSIEN_TAI_ZEI;      -- 積算税額
      RwTAI_CAL.NENZEI                 := i_NwSIEN_TAI_ZEI;      -- 年税額
      -- 特徴月が8月の場合、前年度の賦課支援退職データをセット(現年度分の計算支援退職基本作成)
      IF (i_NTOKU_TUKI = 8) THEN
        RwTAI_CAL.FUKA_KIJITSU_CNT       := NVL(RSIENTAIN.FUKA_KIJITSU_CNT, 0);     -- 賦課期日人員
        RwTAI_CAL.KINTO_CNT              := NVL(RSIENTAIN.KINTO_CNT, 0);            -- 均等割額
        RwTAI_CAL.GENZAI_CNT             := NVL(RSIENTAIN.GENZAI_CNT, 0);           -- 現在人員
      ELSE --特徴月が8月以外は現年度の計算支援退職データをセット(翌年度分の計算支援退職作成)
        RwTAI_CAL.FUKA_KIJITSU_CNT       := NVL(RSIENTAICAL.FUKA_KIJITSU_CNT, 0);   -- 賦課期日人員
        RwTAI_CAL.KINTO_CNT              := NVL(RSIENTAICAL.KINTO_CNT, 0);          -- 均等割額
        RwTAI_CAL.GENZAI_CNT             := NVL(RSIENTAICAL.GENZAI_CNT, 0);         -- 現在人員
      END IF;

      DELETE FROM ZLBTSIEN_TAI_CAL
       WHERE KOKU_SETAI_NO   = RwKIHON_CAL.KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = RwKIHON_CAL.SANTEIDANTAI_CD
         AND CHOTEI_NENDO    = RwKIHON_CAL.CHOTEI_NENDO
         AND NENDO_BUN       = RwKIHON_CAL.NENDO_BUN
         AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO
         AND SYS_TANMATSU_NO = RwKIHON_CAL.SYS_TANMATSU_NO;
      INSERT INTO ZLBTSIEN_TAI_CAL VALUES RwTAI_CAL;
-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
      --国保世帯番号
      RwKDMKIHON_CAL.KOKU_SETAI_NO := i_NSETAI;
      --算定団体コード
      RwKDMKIHON_CAL.SANTEIDANTAI_CD := i_NDANTAI;
      --調定年度
      RwKDMKIHON_CAL.CHOTEI_NENDO := i_NwCHOTEI_NENDO;
      --年度分
      RwKDMKIHON_CAL.NENDO_BUN := i_NwNENDOBUN;
      --履歴番号
      RwKDMKIHON_CAL.R_NO := i_NwRNO;
      --通知書番号
      IF i_NwCHOTEI_NENDO = i_NNENDO THEN
        -- 現年処理
        RwKDMKIHON_CAL.TSUCHI_NO := i_NTSUCHI_NO;
      ELSE
        -- 翌年処理
        RwKDMKIHON_CAL.TSUCHI_NO := NYOKU_TSUCHI_NO;
      END IF;
      --世帯主宛名番号
      IF (i_NTOKU_TUKI = 8) THEN
        RwKDMKIHON_CAL.NUSHI_KOJIN_NO := NVL (RKDMKIHONN.NUSHI_KOJIN_NO, 0);
      ELSE
        RwKDMKIHON_CAL.NUSHI_KOJIN_NO := NVL (RKDMKIHONCAL.NUSHI_KOJIN_NO, 0);
      END IF;
      --事由
      RwKDMKIHON_CAL.IDO_JIYU := c_NKASANTEI;
      --更正日
      RwKDMKIHON_CAL.KOSEI_BI := NKOSEIBI;
      --更新区分
      RwKDMKIHON_CAL.KOSHIN_KBN := 1;
      --申告区分
      RwKDMKIHON_CAL.SHINKOKU_KBN := 0;
      --主所得区分
      RwKDMKIHON_CAL.SHU_SHOTOKU_KBN := 0;
      --現存区分
      RwKDMKIHON_CAL.GENZON_KBN := 0;
      --世帯区分
      RwKDMKIHON_CAL.SETAI_KBN := 0;
      --擬制区分
      RwKDMKIHON_CAL.GISEI_KBN := 0;
      --住民税課税区分
      RwKDMKIHON_CAL.J_KAZEI_KBN := 0;
      --譲渡世帯区分
      RwKDMKIHON_CAL.JOTO_S_KBN := 0;
      --老人世帯区分
      RwKDMKIHON_CAL.ROJIN_S_KBN := 0;
      --専従世帯区分
      RwKDMKIHON_CAL.SENJU_S_KBN := 0;
      --軽減申請区分
      RwKDMKIHON_CAL.KEIGEN_SHINSEI_KBN := 0;
      --軽減判定所得
      RwKDMKIHON_CAL.KEIGEN_SHOTOKU := 0;
      IF (i_NTOKU_TUKI = 8) THEN
        --賦課期日人員
        RwKDMKIHON_CAL.FUKA_KIJITSU_CNT := NVL (RKDMKIHONN.FUKA_KIJITSU_CNT, 0);
        --均等人員
        RwKDMKIHON_CAL.KINTO_CNT := NVL (RKDMKIHONN.KINTO_CNT, 0);
        --現在人員
        RwKDMKIHON_CAL.GENZAI_CNT := NVL (RKDMKIHONN.GENZAI_CNT, 0);
      ELSE
        --賦課期日人員
        RwKDMKIHON_CAL.FUKA_KIJITSU_CNT := NVL (RKDMKIHONCAL.FUKA_KIJITSU_CNT, 0);
        --均等人員
        RwKDMKIHON_CAL.KINTO_CNT := NVL (RKDMKIHONCAL.KINTO_CNT, 0);
        --現在人員
        RwKDMKIHON_CAL.GENZAI_CNT := NVL (RKDMKIHONCAL.GENZAI_CNT, 0);
      END IF ;
      --有所得人員
      RwKDMKIHON_CAL.YU_SHOTOKU_CNT := 0;
      --所得額
      RwKDMKIHON_CAL.SHOTOKU := 0;
      --課税標準額
      RwKDMKIHON_CAL.KAHYO := 0;
      --所得割額
      RwKDMKIHON_CAL.SHOTOKU_WARI := 0;
      --資産税額
      RwKDMKIHON_CAL.SHISANZEI := 0;
      --資産割額
      RwKDMKIHON_CAL.SHISAN_WARI := 0;
      --均等割額
      RwKDMKIHON_CAL.KINTO_WARI := i_NwKDM_ZEI;
      --平等割額
      RwKDMKIHON_CAL.BYODO_WARI := 0;
      --積算税額
      RwKDMKIHON_CAL.SEKISAN := i_NwKDM_ZEI;
      --限度超過額
      RwKDMKIHON_CAL.GENDO_CHOKA := 0;
      --軽減均等割額
      RwKDMKIHON_CAL.KEIGEN_K_WARI := 0;
      --軽減平等割額
      RwKDMKIHON_CAL.KEIGEN_B_WARI := 0;
      --軽減均等6
      RwKDMKIHON_CAL.KEIGEN_K_6 := 0;
      --軽減平等6
      RwKDMKIHON_CAL.KEIGEN_B_6 := 0;
      --軽減均等4
      RwKDMKIHON_CAL.KEIGEN_K_4 := 0;
      --軽減平等4
      RwKDMKIHON_CAL.KEIGEN_B_4 := 0;
      --軽減均等2
      RwKDMKIHON_CAL.KEIGEN_K_2 := 0;
      --軽減平等2
      RwKDMKIHON_CAL.KEIGEN_B_2 := 0;
      --月割減額
      RwKDMKIHON_CAL.TSUKIWARI_GEN := 0;
      --端数
      RwKDMKIHON_CAL.HASU := 0;
      --減額合計
      RwKDMKIHON_CAL.GENGAKU_KEI := 0;
      --減免額
      RwKDMKIHON_CAL.GENMEN := 0;
      --過年度分
      RwKDMKIHON_CAL.KANENDO := 0;
      --年税額
      RwKDMKIHON_CAL.NENZEI := i_NwKDM_ZEI;
      --軽減4月
      RwKDMKIHON_CAL.KEIGEN_4 := 0;
      --軽減5月
      RwKDMKIHON_CAL.KEIGEN_5 := 0;
      --軽減6月
      RwKDMKIHON_CAL.KEIGEN_6 := 0;
      --軽減7月
      RwKDMKIHON_CAL.KEIGEN_7 := 0;
      --軽減8月
      RwKDMKIHON_CAL.KEIGEN_8 := 0;
      --軽減9月
      RwKDMKIHON_CAL.KEIGEN_9 := 0;
      --軽減10月
      RwKDMKIHON_CAL.KEIGEN_10 := 0;
      --軽減11月
      RwKDMKIHON_CAL.KEIGEN_11 := 0;
      --軽減12月
      RwKDMKIHON_CAL.KEIGEN_12 := 0;
      --軽減1月
      RwKDMKIHON_CAL.KEIGEN_1 := 0;
      --軽減2月
      RwKDMKIHON_CAL.KEIGEN_2 := 0;
      --軽減3月
      RwKDMKIHON_CAL.KEIGEN_3 := 0;
      --作成日
      RwKDMKIHON_CAL.SYS_SAKUSEIBI := NULL;
      --更新日
      RwKDMKIHON_CAL.SYS_KOSHINBI := NULL;
      --更新時間
      RwKDMKIHON_CAL.SYS_JIKAN := NULL;
      --更新職員宛名番号
      RwKDMKIHON_CAL.SYS_SHOKUINKOJIN_NO := '0';
      --更新端末番号
      RwKDMKIHON_CAL.SYS_TANMATSU_NO := i_VTANMATSU;
      --18歳以上均等人員
      RwKDMKIHON_CAL.KINTO_CNT_KDM18 := 0;
      --子ども18歳以上均等割額
      RwKDMKIHON_CAL.KINTO_KDM18 := 0;
      DELETE FROM ZLBTKDM_KIHON_CAL
       WHERE KOKU_SETAI_NO   = RwKIHON_CAL.KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = RwKIHON_CAL.SANTEIDANTAI_CD
         AND CHOTEI_NENDO    = RwKIHON_CAL.CHOTEI_NENDO
         AND NENDO_BUN       = RwKIHON_CAL.NENDO_BUN
         AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO
         AND SYS_TANMATSU_NO = RwKIHON_CAL.SYS_TANMATSU_NO;

      INSERT INTO ZLBTKDM_KIHON_CAL VALUES RwKDMKIHON_CAL;
-- 2025/08/11 ZCZL.LISHUAI ADD END

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCINSERTCAL 計算基本への書込み（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCINSERTCAL;

-----------------------------------------------------------
--  8-9Ea7 金額更新
-----------------------------------------------------------
FUNCTION FUNCUPDATEKINGAKU(i_VwTBL_NAME IN NVARCHAR2,
                           i_NwZEI      IN NUMBER) RETURN PLS_INTEGER IS
  IwRTN    PLS_INTEGER := c_IRETOK;                         -- 戻り値
  NwECUR   NUMBER;                                          -- カーソルオープンハンドル
  IwCOUNT  PLS_INTEGER;                                     -- SQL実行結果
  VwSQL    VARCHAR2(3000);                                  -- SQL文字列

BEGIN
  BEGIN
    VwSQL := 'UPDATE '|| i_VwTBL_NAME || ' SET KINTO_WARI = KINTO_WARI + ' || i_NwZEI;
    VwSQL := VwSQL || ' ,SEKISAN = SEKISAN + '  || i_NwZEI;
    VwSQL := VwSQL || ' ,NENZEI = NENZEI + '    || i_NwZEI;
    VwSQL := VwSQL || ' WHERE KOKU_SETAI_NO = ' || i_NSETAI;
    VwSQL := VwSQL || ' AND SANTEIDANTAI_CD = ' || i_NDANTAI;
    VwSQL := VwSQL || ' AND CHOTEI_NENDO = '    || i_NNENDO;
    VwSQL := VwSQL || ' AND NENDO_BUN = '       || i_NNENDO_BUN;
    VwSQL := VwSQL || ' AND TSUCHI_NO = '       || i_NTSUCHI_NO;
    VwSQL := VwSQL || ' AND SYS_TANMATSU_NO = ' || '''' || i_VTANMATSU || '''';

    NwECUR := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(NwECUR, VwSQL, DBMS_SQL.NATIVE);
    IwCOUNT := DBMS_SQL.EXECUTE(NwECUR);
    COMMIT;
    DBMS_SQL.CLOSE_CURSOR(NwECUR);

  EXCEPTION
    WHEN OTHERS THEN
    -- カーソルをクローズ
    IF DBMS_SQL.IS_OPEN(NwECUR) THEN
      DBMS_SQL.CLOSE_CURSOR(NwECUR);
    END IF;
    IwRTN   := c_IRETNG;
    VERROR := VERROR || 'FUNCUPDATEKINGAKU 金額更新（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCUPDATEKINGAKU;

-----------------------------------------------------------
--  8-9E 計算基本への更新 ※現年処理
-----------------------------------------------------------
FUNCTION FUNCUPDATECAL(i_NwIRY_ZEI      IN  NUMBER,
                       i_NwIRY_TAI_ZEI  IN  NUMBER,
                       i_NwKAI_ZEI      IN  NUMBER,
                       i_NwKAI_TAI_ZEI  IN  NUMBER,
                       i_NwSIEN_ZEI     IN  NUMBER,
-- 2025/08/11 ZCZL.LISHUAI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                        i_NwSIEN_TAI_ZEI IN  NUMBER) RETURN PLS_INTEGER IS
                       i_NwSIEN_TAI_ZEI IN  NUMBER,
                       i_NwKDM_ZEI      IN  NUMBER) RETURN PLS_INTEGER IS
-- 2025/08/11 ZCZL.LISHUAI UPDATE END
  -- 変数宣言
  IwRTN  PLS_INTEGER := c_IRETOK;                           -- 戻り値

BEGIN
  BEGIN

    -- 8-9Ea 計算基本 金額更新
    IwRTN := FUNCUPDATEKINGAKU('ZLBTKIHON_CAL',
                               i_NwIRY_ZEI);
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCUPDATECAL 計算基本更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;
    IF i_NwIRY_TAI_ZEI > 0 THEN
    -- 8-9Eb 計算退職 金額更新
      IwRTN := FUNCUPDATEKINGAKU('ZLBTTAI_CAL',
                                i_NwIRY_TAI_ZEI);
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCUPDATECAL 計算退職更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
    END IF;
    IF i_NwKAI_ZEI > 0 THEN
    -- 8-9Ec 計算介護基本 金額更新
      IwRTN := FUNCUPDATEKINGAKU('ZLBTKAI_KIHON_CAL',
                                i_NwKAI_ZEI);
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCUPDATECAL 計算介護基本更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
    END IF;
    IF i_NwKAI_TAI_ZEI > 0 THEN
    -- 8-9Ed 計算介護退職 金額更新
      IwRTN := FUNCUPDATEKINGAKU('ZLBTKAI_TAI_CAL',
                                i_NwKAI_TAI_ZEI);
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCUPDATECAL 計算介護退職更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
    END IF;
    IF i_NwSIEN_ZEI > 0 THEN
    -- 8-9Ee 計算支援基本 金額更新
      IwRTN := FUNCUPDATEKINGAKU('ZLBTSIEN_KIHON_CAL',
                                i_NwSIEN_ZEI);
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCUPDATECAL 計算支援基本更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
    END IF;
    IF i_NwSIEN_TAI_ZEI > 0 THEN
    -- 8-9Ef 計算支援退職 金額更新
      IwRTN := FUNCUPDATEKINGAKU('ZLBTSIEN_TAI_CAL',
                                i_NwSIEN_TAI_ZEI);
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCUPDATECAL 計算支援退職更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
    END IF;
-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
    IF i_NwKDM_ZEI > 0 THEN
      IwRTN := FUNCUPDATEKINGAKU('ZLBTKDM_KIHON_CAL',
                                i_NwKDM_ZEI);
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCUPDATECAL 計算子ども基本更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
    END IF;
-- 2025/08/11 ZCZL.LISHUAI ADD END

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCUPDATECAL 計算基本への更新（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCUPDATECAL;

-----------------------------------------------------------
--  8-4,7 翌年度計算基本作成
-----------------------------------------------------------
FUNCTION FUNCMAKECAL_YOKU RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN            PLS_INTEGER := c_IRETOK;                 -- 戻り値
  NwZEN_ZEIGAKU    NUMBER := 0;                             -- 全体税額
  NwTAI_ZEIGAKU    NUMBER := 0;                             -- 退職税額
  NwIRY_ZEI        NUMBER := 0;                             -- 医療全体税額
  NwIRY_TAI_ZEI    NUMBER := 0;                             -- 医療退職税額
  NwKAI_ZEI        NUMBER := 0;                             -- 介護全体税額
  NwKAI_TAI_ZEI    NUMBER := 0;                             -- 介護退職税額
  NwSIEN_ZEI       NUMBER := 0;                             -- 支援全体税額
  NwSIEN_TAI_ZEI   NUMBER := 0;                             -- 支援退職税額
-- 2025/08/11 ZCZL.LISHUAI ADD 1.1.200.000:子ども子育て支援金対応
  NwKDM_ZEI        NUMBER := 0;                             --子ども全体税額

  CURSOR CwKIHON_CAL IS
    SELECT B.TSUCHI_NO
      FROM ZLBTKIHON_CAL A,ZLBTKIHON_CAL B
     WHERE A.KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
       AND A.SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
       AND A.CHOTEI_NENDO    = i_NNENDO            -- 調停年度
       AND A.NENDO_BUN       = i_NNENDO_BUN        -- 年度分
       AND A.TSUCHI_NO       = i_NTSUCHI_NO        -- 通知書番号
       AND A.SYS_TANMATSU_NO = i_VTANMATSU         -- 更新端末番号
       AND B.KOKU_SETAI_NO   = i_NSETAI            -- 国保世帯番号
       AND B.SANTEIDANTAI_CD = i_NDANTAI           -- 算定団体コード
       AND B.CHOTEI_NENDO    = i_NNENDO     + 1    -- 調停年度
       AND B.NENDO_BUN       = i_NNENDO_BUN + 1    -- 年度分
       AND B.NUSHI_KOJIN_NO  = A.NUSHI_KOJIN_NO    -- 個人番号
       AND B.SYS_TANMATSU_NO = i_VTANMATSU;        -- 更新端末番号
  RwKIHON_CAL      CwKIHON_CAL%ROWTYPE;                     -- 通知書番号取得用ワーク

BEGIN
  BEGIN
    -- 8-4A 翌年度計算期別の特徴データ1期～5期の全体税額、退職税額の合計
    SELECT NVL(SUM(ZEN_ZEIGAKU),0), NVL(SUM(TAI_ZEIGAKU),0)  INTO NwZEN_ZEIGAKU, NwTAI_ZEIGAKU FROM  ZLBTKIBETSU_CAL
     WHERE KAMOKU_CD       = c_NKAMOKU_CD       -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD2     -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI           -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI          -- 算定団体コード
       AND CHOTEINENDO     = i_NNENDO + 1       -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN + 1   -- 年度分
       AND SYS_TANMATSU_NO = i_VTANMATSU        -- 端末番号
       AND (RONRIKIBETSU BETWEEN 1 AND 5);      -- 論理期別

    -- 8-4B 全体税額算出
    -- 介護全体税額算出
    NwKAI_ZEI := ROUND(NwZEN_ZEIGAKU * ((RKAIKIHONCAL.NENZEI  + RKAIKIHONCAL.TSUKIWARI_GEN) /
                                        (RKIHONCAL.NENZEI     + RKIHONCAL.TSUKIWARI_GEN     +
                                         RKAIKIHONCAL.NENZEI  + RKAIKIHONCAL.TSUKIWARI_GEN  +
-- 2025/08/11 ZCZL.LISHUAI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                                          RSIENKIHONCAL.NENZEI + RSIENKIHONCAL.TSUKIWARI_GEN )));
                                         RSIENKIHONCAL.NENZEI + RSIENKIHONCAL.TSUKIWARI_GEN +
                                         RKDMKIHONCAL.NENZEI + RKDMKIHONCAL.TSUKIWARI_GEN )));
-- 2025/08/11 ZCZL.LISHUAI UPDATE END
    -- 支援全体税額算出
    NwSIEN_ZEI := ROUND((NwZEN_ZEIGAKU - NwKAI_ZEI) * ((RSIENKIHONCAL.NENZEI + RSIENKIHONCAL.TSUKIWARI_GEN) /
                                                       (RKIHONCAL.NENZEI     + RKIHONCAL.TSUKIWARI_GEN      +
-- 2025/08/11 ZCZL.LISHUAI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                                                         RSIENKIHONCAL.NENZEI + RSIENKIHONCAL.TSUKIWARI_GEN  )));
                                                        RSIENKIHONCAL.NENZEI + RSIENKIHONCAL.TSUKIWARI_GEN +
                                                        RKDMKIHONCAL.NENZEI  + RKDMKIHONCAL.TSUKIWARI_GEN  )));
    NwKDM_ZEI :=  ROUND((NwZEN_ZEIGAKU - NwKAI_ZEI - NwSIEN_ZEI) * ((RKDMKIHONCAL.NENZEI  + RKDMKIHONCAL.TSUKIWARI_GEN) /
                                                       (RKIHONCAL.NENZEI     + RKIHONCAL.TSUKIWARI_GEN      +
                                                        RKDMKIHONCAL.NENZEI  + RKDMKIHONCAL.TSUKIWARI_GEN  )));
-- 2025/08/11 ZCZL.LISHUAI UPDATE END

    -- 医療全体算出
-- 2025/08/11 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応
--     NwIRY_ZEI := NwZEN_ZEIGAKU - NwKAI_ZEI - NwSIEN_ZEI;
    NwIRY_ZEI := NwZEN_ZEIGAKU - NwKAI_ZEI - NwSIEN_ZEI - NwKDM_ZEI;

    -- 8-4C 退職税額算出
    IF RTAICAL.NENZEI <> 0 THEN
       -- 年税が存在する時だけ処理を行う
       -- 介護退職算出
       NwKAI_TAI_ZEI := ROUND(NwTAI_ZEIGAKU * ((RKAITAICAL.NENZEI  + RKAITAICAL.TSUKIWARI_GEN) /
                                               (RTAICAL.NENZEI     + RTAICAL.TSUKIWARI_GEN     +
                                                RKAITAICAL.NENZEI  + RKAITAICAL.TSUKIWARI_GEN  +
                                                RSIENTAICAL.NENZEI + RSIENTAICAL.TSUKIWARI_GEN )));
       -- 支援退職算出
       NwSIEN_TAI_ZEI := ROUND((NwTAI_ZEIGAKU - NwKAI_TAI_ZEI) * ((RSIENTAICAL.NENZEI + RSIENTAICAL.TSUKIWARI_GEN) /
                                                                  (RTAICAL.NENZEI     + RTAICAL.TSUKIWARI_GEN      +
                                                                   RSIENTAICAL.NENZEI + RSIENTAICAL.TSUKIWARI_GEN  )));
    ELSE
      NwKAI_TAI_ZEI  := 0;
      NwSIEN_TAI_ZEI := 0;
    END IF;

    -- 医療退職算出
    NwIRY_TAI_ZEI := NwTAI_ZEIGAKU - NwKAI_TAI_ZEI - NwSIEN_TAI_ZEI;

    -- 8-4D 計算基本への書込み
    BEGIN
      OPEN CwKIHON_CAL;
      FETCH CwKIHON_CAL INTO RwKIHON_CAL;
        IF CwKIHON_CAL%FOUND THEN
          -- 計算基本削除
          DELETE FROM ZLBTKIHON_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI                -- 国保世帯番号
             AND SANTEIDANTAI_CD = i_NDANTAI               -- 算定団体コード
             AND CHOTEI_NENDO    = i_NNENDO     + 1        -- 調停年度
             AND NENDO_BUN       = i_NNENDO_BUN + 1        -- 年度分
             AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO   -- 通知書番号
             AND SYS_TANMATSU_NO = i_VTANMATSU;            -- 更新端末番号
          -- 計算退職基本削除
          DELETE FROM ZLBTTAI_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI                -- 国保世帯番号
             AND SANTEIDANTAI_CD = i_NDANTAI               -- 算定団体コード
             AND CHOTEI_NENDO    = i_NNENDO     + 1        -- 調停年度
             AND NENDO_BUN       = i_NNENDO_BUN + 1        -- 年度分
             AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO   -- 通知書番号
             AND SYS_TANMATSU_NO = i_VTANMATSU;            -- 更新端末番号
          -- 計算介護基本削除
          DELETE FROM ZLBTKAI_KIHON_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI                -- 国保世帯番号
             AND SANTEIDANTAI_CD = i_NDANTAI               -- 算定団体コード
             AND CHOTEI_NENDO    = i_NNENDO     + 1        -- 調停年度
             AND NENDO_BUN       = i_NNENDO_BUN + 1        -- 年度分
             AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO   -- 通知書番号
             AND SYS_TANMATSU_NO = i_VTANMATSU;            -- 更新端末番号
          -- 計算介護退職削除
          DELETE FROM ZLBTKAI_TAI_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI                -- 国保世帯番号
             AND SANTEIDANTAI_CD = i_NDANTAI               -- 算定団体コード
             AND CHOTEI_NENDO    = i_NNENDO     + 1        -- 調停年度
             AND NENDO_BUN       = i_NNENDO_BUN + 1        -- 年度分
             AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO   -- 通知書番号
             AND SYS_TANMATSU_NO = i_VTANMATSU;            -- 更新端末番号
          -- 計算支援基本削除
          DELETE FROM ZLBTSIEN_KIHON_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI                -- 国保世帯番号
             AND SANTEIDANTAI_CD = i_NDANTAI               -- 算定団体コード
             AND CHOTEI_NENDO    = i_NNENDO     + 1        -- 調停年度
             AND NENDO_BUN       = i_NNENDO_BUN + 1        -- 年度分
             AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO   -- 通知書番号
             AND SYS_TANMATSU_NO = i_VTANMATSU;            -- 更新端末番号
          -- 計算支援退職削除
          DELETE FROM ZLBTSIEN_TAI_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI                -- 国保世帯番号
             AND SANTEIDANTAI_CD = i_NDANTAI               -- 算定団体コード
             AND CHOTEI_NENDO    = i_NNENDO     + 1        -- 調停年度
             AND NENDO_BUN       = i_NNENDO_BUN + 1        -- 年度分
             AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO   -- 通知書番号
             AND SYS_TANMATSU_NO = i_VTANMATSU;            -- 更新端末番号
-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
          -- 計算子ども基本
          DELETE FROM ZLBTKDM_KIHON_CAL
           WHERE KOKU_SETAI_NO   = i_NSETAI                -- 国保世帯番号
             AND SANTEIDANTAI_CD = i_NDANTAI               -- 算定団体コード
             AND CHOTEI_NENDO    = i_NNENDO     + 1        -- 調停年度
             AND NENDO_BUN       = i_NNENDO_BUN + 1        -- 年度分
             AND TSUCHI_NO       = RwKIHON_CAL.TSUCHI_NO   -- 通知書番号
             AND SYS_TANMATSU_NO = i_VTANMATSU;            -- 更新端末番号
-- 2025/08/11 ZCZL.LISHUAI ADD END
        END IF;
      CLOSE CwKIHON_CAL;
    EXCEPTION
      WHEN OTHERS THEN
        IwRTN   := c_IRETNG;
        VERROR := VERROR || 'FUNCMAKECAL_YOKU 翌年度計算基本作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
        RETURN IwRTN;
    END;
    IwRTN := FUNCINSERTCAL(i_NNENDO + 1,
                           i_NNENDO_BUN + 1,
                           NwIRY_ZEI,
                           NwIRY_TAI_ZEI,
                           NwKAI_ZEI,
                           NwKAI_TAI_ZEI,
                           NwSIEN_ZEI,
                           NwSIEN_TAI_ZEI,
-- 2025/08/11 ZCZL.LISHUAI ADD 1.1.200.000:子ども子育て支援金対応
                           NwKDM_ZEI,
                           NYOKURNO);
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKECAL 計算基本への書込み（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKECAL_YOKU 翌年度計算基本作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKECAL_YOKU;

-----------------------------------------------------------
--  8-9 現年度計算基本作成
-----------------------------------------------------------
FUNCTION FUNCMAKECAL_GEN(o_BwKIBETSU OUT BOOLEAN) RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN           PLS_INTEGER := c_IRETOK;                  -- 戻り値
  NwZEN_ZEIGAKU   NUMBER := 0;                              -- 全体税額
  NwTAI_ZEIGAKU   NUMBER := 0;                              -- 退職税額
  NwIRY_ZEI       NUMBER := 0;                              -- 医療全体税額
  NwIRY_TAI_ZEI   NUMBER := 0;                              -- 医療退職税額
  NwKAI_ZEI       NUMBER := 0;                              -- 介護全体税額
  NwKAI_TAI_ZEI   NUMBER := 0;                              -- 介護退職税額
  NwSIEN_ZEI      NUMBER := 0;                              -- 支援全体税額
-- 2025/08/11 ZCZL.LISHUAI ADD 1.1.200.000:子ども子育て支援金対応
  NwKDM_ZEI       NUMBER := 0;                              --子ども全体税額
  NwSIEN_TAI_ZEI  NUMBER := 0;                              -- 支援退職税額

  CURSOR CKIHON_CAL IS
    SELECT * FROM ZLBTKIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO         -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN     -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO     -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;     -- 更新端末番号

  RKIHON_CAL CKIHON_CAL%ROWTYPE;

BEGIN
  BEGIN
    -- 8-9A 計算期別の特徴データ5期の全体税額、退職税額の合計 取得
    SELECT NVL(SUM(ZEN_ZEIGAKU),0), NVL(SUM(TAI_ZEIGAKU),0) INTO NwZEN_ZEIGAKU, NwTAI_ZEIGAKU  FROM  ZLBTKIBETSU_CAL
     WHERE KAMOKU_CD       = c_NKAMOKU_CD     -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD2   -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI         -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI        -- 算定団体コード
       AND CHOTEINENDO     = i_NNENDO         -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN     -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO     -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU      -- 更新端末番号
       AND RONRIKIBETSU = 5;

    -- 8-9B 全体税額算出
    -- 介護全体 算出
    NwKAI_ZEI := ROUND(NwZEN_ZEIGAKU * ((RKAIKIHONN.NENZEI  + RKAIKIHONN.TSUKIWARI_GEN) /
                                        (RKIHONN.NENZEI     + RKIHONN.TSUKIWARI_GEN     +
                                         RKAIKIHONN.NENZEI  + RKAIKIHONN.TSUKIWARI_GEN  +
-- 2025/08/11 ZCZL.LISHUAI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                                          RSIENKIHONN.NENZEI + RSIENKIHONN.TSUKIWARI_GEN )));
                                         RSIENKIHONN.NENZEI + RSIENKIHONN.TSUKIWARI_GEN  +
                                         RKDMKIHONN.NENZEI + RKDMKIHONN.TSUKIWARI_GEN )));
-- 2025/08/11 ZCZL.LISHUAI UPDATE END
    -- 支援全体 算出
    NwSIEN_ZEI := ROUND((NwZEN_ZEIGAKU - NwKAI_ZEI) * ((RSIENKIHONN.NENZEI + RSIENKIHONN.TSUKIWARI_GEN) /
                                                       (RKIHONN.NENZEI     + RKIHONN.TSUKIWARI_GEN      +
-- 2025/08/11 ZCZL.LISHUAI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                                                         RSIENKIHONN.NENZEI + RSIENKIHONN.TSUKIWARI_GEN  )));
                                                        RSIENKIHONN.NENZEI  + RSIENKIHONN.TSUKIWARI_GEN +
                                                        RKDMKIHONN.NENZEI + RKDMKIHONN.TSUKIWARI_GEN  )));
    NwKDM_ZEI := ROUND((NwZEN_ZEIGAKU - NwKAI_ZEI - NwSIEN_ZEI) * ((RKDMKIHONN.NENZEI  + RKDMKIHONN.TSUKIWARI_GEN) /
                                                       (RKIHONN.NENZEI      + RKIHONN.TSUKIWARI_GEN      +
                                                        RKDMKIHONN.NENZEI + RKDMKIHONN.TSUKIWARI_GEN  )));
-- 2025/08/11 ZCZL.LISHUAI UPDATE END

    -- 医療全体 算出
-- 2025/08/11 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応
--     NwIRY_ZEI := NwZEN_ZEIGAKU - NwKAI_ZEI - NwSIEN_ZEI;
    NwIRY_ZEI := NwZEN_ZEIGAKU - NwKAI_ZEI - NwSIEN_ZEI - NwKDM_ZEI;

    -- 8-9C 退職税額算出
    IF RTAIN.NENZEI <> 0 THEN
       -- 年税が存在する時だけ処理を行う
       -- 介護退職 算出
       NwKAI_TAI_ZEI := ROUND(NwTAI_ZEIGAKU * ((RKAITAIN.NENZEI  + RKAITAIN.TSUKIWARI_GEN) /
                                               (RTAIN.NENZEI     + RTAIN.TSUKIWARI_GEN     +
                                                RKAITAIN.NENZEI  + RKAITAIN.TSUKIWARI_GEN  +
                                                RSIENTAIN.NENZEI + RSIENTAIN.TSUKIWARI_GEN )));

       -- 支援退職 算出
       NwSIEN_TAI_ZEI := ROUND((NwTAI_ZEIGAKU - NwKAI_TAI_ZEI) * ((RSIENTAIN.NENZEI + RSIENTAIN.TSUKIWARI_GEN) /
                                                                  (RTAIN.NENZEI     + RTAIN.TSUKIWARI_GEN      +
                                                                   RSIENTAIN.NENZEI + RSIENTAIN.TSUKIWARI_GEN  )));
    ELSE
      NwKAI_TAI_ZEI  := 0;
      NwSIEN_TAI_ZEI := 0;
    END IF;

    -- 医療退職 算出
    NwIRY_TAI_ZEI := NwTAI_ZEIGAKU - NwKAI_TAI_ZEI - NwSIEN_TAI_ZEI;

    OPEN CKIHON_CAL;
    FETCH CKIHON_CAL INTO RKIHON_CAL;
      IF CKIHON_CAL%NOTFOUND THEN
        -- 8-9D 計算基本への書込み
        IwRTN := FUNCINSERTCAL(i_NNENDO,
                              i_NNENDO_BUN,
                              NwIRY_ZEI,
                              NwIRY_TAI_ZEI,
                              NwKAI_ZEI,
                              NwKAI_TAI_ZEI,
                              NwSIEN_ZEI,
                              NwSIEN_TAI_ZEI,
-- 2025/08/11 ZCZL.LISHUAI ADD 1.1.200.000:子ども子育て支援金対応
                              NwKDM_ZEI,
                              NGENRNO);
        IF IwRTN <> c_IRETOK THEN
          VERROR := VERROR || 'FUNCINSERTCAL 計算基本への書込み（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
          RETURN IwRTN;
        END IF;
      ELSE
        IF RKIHON_CAL.IDO_JIYU = c_NKASANTEI THEN
        -- 8-9E 計算基本への更新
          IwRTN := FUNCUPDATECAL(NwIRY_ZEI,
                                NwIRY_TAI_ZEI,
                                NwKAI_ZEI,
                                NwKAI_TAI_ZEI,
                                NwSIEN_ZEI,
-- 2025/08/11 ZCZL.LISHUAI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                                 NwSIEN_TAI_ZEI);
                                NwSIEN_TAI_ZEI,
                                NwKDM_ZEI);
-- 2025/08/11 ZCZL.LISHUAI UPDATE END
          IF IwRTN <> c_IRETOK THEN
            VERROR := VERROR || 'FUNCUPDATECAL 計算基本への更新（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
            RETURN IwRTN;
          END IF;
        ELSE
          o_BwKIBETSU := TRUE;
          RETURN IwRTN;
        END IF;
      END IF;
    CLOSE CKIHON_CAL;

    o_BwKIBETSU := FALSE;
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKECAL_GEN 現年度計算基本作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKECAL_GEN;
-----------------------------------------------------------
--  8-0 現年度特徴中止情報作成
-----------------------------------------------------------
FUNCTION FUNCSTOPTOKUKIHONCAL RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN             PLS_INTEGER := c_IRETOK;                -- 戻り値
  NwJOTAI_KBN       NUMBER;                                 -- 計算特徴対象者の特徴状態

BEGIN
  BEGIN
    -- 計算特徴対象者から特徴状態を取得
    SELECT JOTAI_KBN INTO NwJOTAI_KBN FROM ZLBTTOKU_KIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI                       -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI                      -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO                       -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN                   -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO                   -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;                   -- 更新端末番号

    IF NwJOTAI_KBN = c_NJOTAI_CONTINUE THEN
    -- 特徴状態＝継続の場合→計算特徴対象者TBLを中止状態に更新
      UPDATE ZLBTTOKU_KIHON_CAL SET JOTAI_KBN      = c_NJOTAI_OVER,  --特徴状態(中止)
                                    SHURYO_TSUKI   = NGENNEN_TUKI,   -- 特徴終了月(特徴開始期)
                                    SHURYO_KIBETSU = NGENNEN_KIBETSU,-- 特徴終了期別(特徴開始期別)
                                    CHUSHI_JIYU    = 39,             -- 特徴中止事由(後期高齢該当)
                                    IRAI_HIZUKE    = i_NSHORIBI      -- 依頼日
       WHERE KOKU_SETAI_NO   = i_NSETAI                     -- 国保世帯番号
         AND SANTEIDANTAI_CD = i_NDANTAI                    -- 算定団体コード
         AND CHOTEI_NENDO    = i_NNENDO                     -- 調停年度
         AND NENDO_BUN       = i_NNENDO_BUN                 -- 年度分
         AND TSUCHI_NO       = i_NTSUCHI_NO                 -- 通知書番号
         AND SYS_TANMATSU_NO = i_VTANMATSU;                 -- 更新端末番号
    ELSE
    -- 特徴状態＝新規の場合→計算特徴対象者TBLを削除
      DELETE FROM ZLBTTOKU_KIHON_CAL
       WHERE KOKU_SETAI_NO   = i_NSETAI                     -- 国保世帯番号
         AND SANTEIDANTAI_CD = i_NDANTAI                    -- 算定団体コード
         AND CHOTEI_NENDO    = i_NNENDO                     -- 調停年度
         AND NENDO_BUN       = i_NNENDO_BUN                 -- 年度分
         AND TSUCHI_NO       = i_NTSUCHI_NO                 -- 通知書番号
         AND SYS_TANMATSU_NO = i_VTANMATSU;                 -- 更新端末番号
    END IF;

    -- 翌年度分の計算特徴対象者は無条件に削除
    DELETE FROM ZLBTTOKU_KIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI               -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI              -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO + 1           -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN + 1       -- 年度分
       AND TSUCHI_NO       = NYOKU_TSUCHI_NO        -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;           -- 更新端末番号

    --計算異動の中止事由(後期高齢該当)をセット
    UPDATE ZLBTTOKU_IDO_CAL SET CHUSHI_JIYU = 39
     WHERE KOKU_SETAI_NO   = i_NSETAI                  -- 国保世帯番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;              -- 更新端末番号


  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCSTOPTOKUKIHONCAL 現年度特徴中止情報作成（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCSTOPTOKUKIHONCAL;

-----------------------------------------------------------
--  8-1 現年度期別作成(特徴月=10月)
-----------------------------------------------------------
FUNCTION FUNCMAKEKIBETSU_10(o_BwKIBETSU OUT BOOLEAN) RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN             PLS_INTEGER := c_IRETOK;                -- 戻り値
  BwSTOP            BOOLEAN     := FALSE;                   -- TRUE:特徴開始不可能
  NwJOTAI_KBN       NUMBER := 0;                            -- 計算特徴対象者の特徴状態
  NwZEN_KIWARI      NUMBER := 0;                            -- 期割対象額     全体
  NwTAI_KIWARI      NUMBER := 0;                            --                退職
  NwZEN_ZEIGAKU     NUMBER := 0;                            -- 特徴１期分     全体額
  NwTAI_ZEIGAKU     NUMBER := 0;                            --                退職額
  NwZEN_HASU        NUMBER := 0;                            -- 特徴の端数合計 全体
  NwTAI_HASU        NUMBER := 0;                            --                退職
  NwZEN_ZEIGAKU_CAL NUMBER := 0;                            -- 現在の全体税額(4月～9月)
  NwTAI_ZEIGAKU_CAL NUMBER := 0;                            -- 現在の退職税額(4月～9月)
  RwKIBETSUCAL      ZLBTKIBETSU_CAL%ROWTYPE;          -- 計算期別 insert用変数
  NwIX              NUMBER;                                 -- Loop Index

BEGIN
  BEGIN
    -- 8-1A 現年度の計算基本(医療、介護、支援、子ども)取得
    IwRTN := FUNCGETCAL(i_NNENDO,
                        i_NNENDO_BUN);
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKEKIBETSU_10 現年度期別作成(特徴月=10月)（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-1B 計算期別から現在の税額を取得
    SELECT NVL(SUM(ZEN_ZEIGAKU),0), NVL(SUM(TAI_ZEIGAKU),0) INTO NwZEN_ZEIGAKU_CAL, NwTAI_ZEIGAKU_CAL FROM ZLBTKIBETSU_N
     WHERE KAMOKU_CD       = c_NKAMOKU_CD                        -- 科目コード
       AND KAMOKUS_CD      IN(c_NKAMOKUS_CD1, c_NKAMOKUS_CD2)    -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI                            -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI                           -- 算定団体コード
       AND TSUCHI_NO       = i_NTSUCHI_NO                        -- 通知書番号
       AND CHOTEINENDO     = i_NNENDO                            -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN                        -- 年度分
--無条件にZLBTKIBETSU_Nの?９月までを取得していたのを現在期前まで取得に変更
       AND ((KAMOKUS_CD = c_NKAMOKUS_CD1 AND (RONRIKIBETSU >= 1 AND RONRIKIBETSU < NFUTU_KIBETSU)) OR
            (KAMOKUS_CD = c_NKAMOKUS_CD2 AND (RONRIKIBETSU BETWEEN 1 AND 6))
           );                                                    -- 論理期別

    -- 8-1C 計算特徴対象者から特徴状態を取得
    SELECT NVL(JOTAI_KBN,0) INTO NwJOTAI_KBN FROM ZLBTTOKU_KIHON_CAL
     WHERE KOKU_SETAI_NO   = i_NSETAI                            -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI                           -- 算定団体コード
       AND CHOTEI_NENDO    = i_NNENDO                            -- 調停年度
       AND NENDO_BUN       = i_NNENDO_BUN                        -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO                        -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU;                        -- 更新端末番号

    -- 8-1D 全体期別金額算出
    IF NwJOTAI_KBN = c_NJOTAI_NEW THEN
    -- 特徴状態＝新規の場合→年税÷６で算出して均等額で徴収
      NwZEN_KIWARI  := RKIHONCAL.NENZEI
                     + RKAIKIHONCAL.NENZEI
-- 2025/08/11 ZCZL.LISHUAI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                      + RSIENKIHONCAL.NENZEI;
                     + RSIENKIHONCAL.NENZEI
                     + RKDMKIHONCAL.NENZEI;
-- 2025/08/11 ZCZL.LISHUAI UPDATE END
      NwZEN_ZEIGAKU := TRUNC(ROUND(NwZEN_KIWARI / 6) / 100) * 100;
      NwZEN_HASU    := NwZEN_KIWARI - 6 * NwZEN_ZEIGAKU;

      -- 端数が300円以上の時は端数を300円以下にする
      IF NwZEN_HASU >= 300 THEN
         NwZEN_ZEIGAKU := NwZEN_ZEIGAKU +100;
         NwZEN_HASU := NwZEN_HASU -300;
      END IF;

      -- 均等額で徴収可能か?
      IF (NwZEN_ZEIGAKU_CAL  >=  3 * NwZEN_ZEIGAKU) OR           -- 現在の全体税額(4月～9月)＞(算出金額×３)
         (((NwZEN_ZEIGAKU * 3) + NwZEN_HASU + NwZEN_ZEIGAKU_CAL) -- 期別金額>年税額
-- 2025/08/11 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応
--            > RKIHONCAL.NENZEI + RKAIKIHONCAL.NENZEI + RSIENKIHONCAL.NENZEI ) THEN
           > RKIHONCAL.NENZEI + RKAIKIHONCAL.NENZEI + RSIENKIHONCAL.NENZEI + RKDMKIHONCAL.NENZEI ) THEN
      -- 徴収不可能→再計算(未徴収金額÷残期数で算出して徴収)
-- 2025/08/11 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応
--         NwZEN_KIWARI  := RKIHONCAL.NENZEI + RKAIKIHONCAL.NENZEI + RSIENKIHONCAL.NENZEI - NwZEN_ZEIGAKU_CAL;
        NwZEN_KIWARI  := RKIHONCAL.NENZEI + RKAIKIHONCAL.NENZEI + RSIENKIHONCAL.NENZEI + RKDMKIHONCAL.NENZEI - NwZEN_ZEIGAKU_CAL;
        NwZEN_ZEIGAKU := TRUNC(ROUND(NwZEN_KIWARI / 3) / 100) * 100;
        NwZEN_HASU    := NwZEN_KIWARI - 3 * NwZEN_ZEIGAKU;
        IF NwZEN_ZEIGAKU <= 0 THEN 
        --徴収金額マイナス→還付発生。特徴開始不可能
           BwSTOP := TRUE;
        END IF;
      END IF;
    ELSE
    -- 特徴状態＝継続の場合→未徴収金額÷残期数で算出して徴収 ※未徴収金額に納期未到来の納付済み金額は含む。
-- 2025/08/11 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応
--       NwZEN_KIWARI  := RKIHONCAL.NENZEI + RKAIKIHONCAL.NENZEI + RSIENKIHONCAL.NENZEI - NwZEN_ZEIGAKU_CAL;
      NwZEN_KIWARI  := RKIHONCAL.NENZEI + RKAIKIHONCAL.NENZEI + RSIENKIHONCAL.NENZEI + RKDMKIHONCAL.NENZEI - NwZEN_ZEIGAKU_CAL;
      NwZEN_ZEIGAKU := TRUNC(ROUND(NwZEN_KIWARI / NKISU) / 100) * 100;
      NwZEN_HASU    := NwZEN_KIWARI - NKISU * NwZEN_ZEIGAKU;
      IF NwZEN_ZEIGAKU < 0 OR (NwZEN_ZEIGAKU = 0 AND (NwZEN_KIWARI <> NwZEN_HASU AND NwZEN_KIWARI > 0)) THEN --端数＝期割は300円未満で特徴可能
      -- 徴収金額マイナス→還付発生。特徴開始不可能
         BwSTOP := TRUE;
      END IF;
    END IF;
    -- 8-1E 特徴開始不可能時、特徴継続予定であれば計算特徴対象者TBLを中止状態に変更
    -- 特徴新規予定であれば計算特徴対象者TBLを削除
    IF BwSTOP = TRUE THEN
       -- 計算特徴対象者
       IF NwJOTAI_KBN = c_NJOTAI_CONTINUE THEN
       -- 特徴状態＝継続の場合→計算特徴対象者TBLを中止状態に更新
          UPDATE ZLBTTOKU_KIHON_CAL SET JOTAI_KBN      = c_NJOTAI_OVER, --特徴状態(中止)
                                        SHURYO_TSUKI   = 10,            -- 特徴終了月
                                        SHURYO_KIBETSU = 7,             -- 特徴終了期別
                                        CHUSHI_JIYU    = 1,             -- 特徴中止事由(減額更正)
                                        IRAI_HIZUKE    = i_NSHORIBI     -- 依頼日
             WHERE KOKU_SETAI_NO   = i_NSETAI             -- 国保世帯番号
               AND SANTEIDANTAI_CD = i_NDANTAI            -- 算定団体コード
               AND CHOTEI_NENDO    = i_NNENDO             -- 調停年度
               AND NENDO_BUN       = i_NNENDO_BUN         -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO         -- 通知書番号
               AND SYS_TANMATSU_NO = i_VTANMATSU;         -- 更新端末番号
       ELSE
       -- 特徴状態＝新規の場合→計算特徴対象者TBLを削除
          DELETE FROM ZLBTTOKU_KIHON_CAL
                WHERE KOKU_SETAI_NO   = i_NSETAI          -- 国保世帯番号
                  AND SANTEIDANTAI_CD = i_NDANTAI         -- 算定団体コード
                  AND CHOTEI_NENDO    = i_NNENDO          -- 調停年度
                  AND NENDO_BUN       = i_NNENDO_BUN      -- 年度分
                  AND TSUCHI_NO       = i_NTSUCHI_NO      -- 通知書番号
                  AND SYS_TANMATSU_NO = i_VTANMATSU;      -- 更新端末番号
       END IF;
       -- 翌年度分の計算特徴対象者は無条件に削除
       DELETE FROM ZLBTTOKU_KIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI             -- 国保世帯番号
               AND SANTEIDANTAI_CD = i_NDANTAI            -- 算定団体コード
               AND CHOTEI_NENDO    = i_NNENDO + 1         -- 調停年度
               AND NENDO_BUN       = i_NNENDO_BUN + 1     -- 年度分
               AND TSUCHI_NO       = NYOKU_TSUCHI_NO      -- 通知書番号
               AND SYS_TANMATSU_NO = i_VTANMATSU;         -- 更新端末番号
       --計算異動の中止事由(減額更正)をセット
       UPDATE ZLBTTOKU_IDO_CAL SET CHUSHI_JIYU = 1
        WHERE KOKU_SETAI_NO   = i_NSETAI                  -- 国保世帯番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;              -- 更新端末番号

       o_BwKIBETSU := FALSE;
       RETURN IwRTN;
    END IF;

    BwSTOP := FALSE;

    -- 8-1F 退職期別金額算出
    IF NwJOTAI_KBN = c_NJOTAI_NEW THEN
    -- 特徴状態＝新規の場合
      NwTAI_KIWARI  := RTAICAL.NENZEI
                     + RKAITAICAL.NENZEI
                     + RSIENTAICAL.NENZEI;
      NwTAI_ZEIGAKU := TRUNC(ROUND(NwTAI_KIWARI / 6) / 100) * 100;
      NwTAI_HASU    := NwTAI_KIWARI - 6 * NwTAI_ZEIGAKU;

      -- 端数が300円以上の時は端数を300円以下にする
      IF NwTAI_HASU > 300 THEN
         NwTAI_ZEIGAKU := NwTAI_ZEIGAKU +100;
         NwTAI_HASU := NwTAI_HASU -300;
      END IF;

      -- 再計算
      IF NwTAI_ZEIGAKU_CAL  >=  3 * NwTAI_ZEIGAKU THEN
        NwTAI_KIWARI  := RTAICAL.NENZEI + RKAITAICAL.NENZEI + RSIENTAICAL.NENZEI - NwTAI_ZEIGAKU_CAL;
        NwTAI_ZEIGAKU := TRUNC(ROUND(NwTAI_KIWARI / 3) / 100) * 100;
        NwTAI_HASU    := NwTAI_KIWARI - 3 * NwTAI_ZEIGAKU;
        IF NwTAI_ZEIGAKU < 0 THEN                           -- 退職税額は0＝の場合は特徴中止にしない
           NwTAI_ZEIGAKU := 0;
        END IF;
      END IF;
    ELSE
    -- 特徴状態＝継続の場合
      NwTAI_KIWARI := RTAICAL.NENZEI + RKAITAICAL.NENZEI + RSIENTAICAL.NENZEI - NwTAI_ZEIGAKU_CAL;
      NwTAI_ZEIGAKU := TRUNC(ROUND(NwTAI_KIWARI / NKISU) / 100) * 100;
      NwTAI_HASU    := NwTAI_KIWARI - NKISU * NwTAI_ZEIGAKU;

      IF NwTAI_ZEIGAKU < 0 THEN                             -- 退職税額は0＝の場合は特徴中止にしない
         NwTAI_ZEIGAKU := 0;
      END IF;
    END IF;

   -- 8-1G 計算期別レコードInsert
    FOR NwIX IN 1..NKISU LOOP

      -- 年度内に特徴中止⇒特徴開始となった場合のためにDELETEしておく(現状、実運用では有り得ない)
      DELETE FROM ZLBTKIBETSU_CAL
        WHERE KAMOKU_CD       = c_NKAMOKU_CD                 -- 科目コード
          AND KAMOKUS_CD      = c_NKAMOKUS_CD2               -- 科目詳細コード【特徴】
          AND KOKU_SETAI_NO   = RKIHONCAL.KOKU_SETAI_NO      -- 国保世帯番号
          AND SANTEIDANTAI_CD = RKIHONCAL.SANTEIDANTAI_CD    -- 算定団体コード
          AND CHOTEINENDO     = RKIHONCAL.CHOTEI_NENDO       -- 調停年度
          AND NENDOBUN        = RKIHONCAL.NENDO_BUN          -- 年度分
          AND TSUCHI_NO       = RKIHONCAL.TSUCHI_NO          -- 通知書番号
          AND RONRIKIBETSU    = (NwIX + 2) * 2 + 1
          AND SYS_TANMATSU_NO = i_VTANMATSU;

      -- 計算期別TBL作成
      RwKIBETSUCAL.KAMOKU_CD            := c_NKAMOKU_CD;                -- 科目コード
      RwKIBETSUCAL.KAMOKUS_CD           := c_NKAMOKUS_CD2;              -- 科目詳細コード【特徴】
      RwKIBETSUCAL.KOKU_SETAI_NO        := RKIHONCAL.KOKU_SETAI_NO;     -- 国保世帯番号
      RwKIBETSUCAL.SANTEIDANTAI_CD      := RKIHONCAL.SANTEIDANTAI_CD;   -- 算定団体コード
      RwKIBETSUCAL.KIWARIDANTAI_CD      := 0;                           -- 期割団体コード
      RwKIBETSUCAL.DANTAING_KBN         := 0;                           -- 団体内外区分
      RwKIBETSUCAL.GENNENKANEN_KBN      := 0;                           -- 現年過年区分
      RwKIBETSUCAL.CHOTEINENDO          := RKIHONCAL.CHOTEI_NENDO;      -- 調停年度
      RwKIBETSUCAL.NENDOBUN             := RKIHONCAL.NENDO_BUN;         -- 年度分
      RwKIBETSUCAL.TSUCHI_NO            := RKIHONCAL.TSUCHI_NO;         -- 翌年度通知書番号
      RwKIBETSUCAL.RONRIKIBETSU         := (NwIX + 2) * 2 + 1;          -- 論理期別
      RwKIBETSUCAL.R_NO                 := RKIHONCAL.R_NO;              -- 履歴番号
      IF (NwIX + 4) * 2 > 12 THEN
        RwKIBETSUCAL.NENGETSU           := i_NNENDO * 100 + (NwIX - 2) * 2;
      ELSE
        RwKIBETSUCAL.NENGETSU           := i_NNENDO * 100 + (NwIX + 4) * 2;
      END IF;
      RwKIBETSUCAL.NUSHI_KOJIN_NO       := RTOKUHOSOKU.TOKU_KOJIN_NO;   -- 納税義務者個人番号
      RwKIBETSUCAL.KOSEI_BI             := NKOSEIBI;                    -- 更正日
      RwKIBETSUCAL.IR_ZEN_ZEIGAKU       := 0;                           -- 医療全体税額
      RwKIBETSUCAL.IR_TAI_ZEIGAKU       := 0;                           -- 医療退職税額
      RwKIBETSUCAL.KAI_ZEN_ZEIGAKU      := 0;                           -- 介護全体税額
      RwKIBETSUCAL.KAI_TAI_ZEIGAKU      := 0;                           -- 介護退職税額
      RwKIBETSUCAL.SIEN_ZEN_ZEIGAKU     := 0;                           -- 支援全体税額
      RwKIBETSUCAL.SIEN_TAI_ZEIGAKU     := 0;                           -- 支援退職税額
      RwKIBETSUCAL.IR_ZEN_FNKSNGAKU     := 0;                           -- 不能欠損額（医療全体）
      RwKIBETSUCAL.IR_TAI_FNKSNGAKU     := 0;                           -- 不能欠損額（医療退職）
      RwKIBETSUCAL.KAI_ZEN_FNKSNGAKU    := 0;                           -- 不能欠損額（介護全体）
      RwKIBETSUCAL.KAI_TAI_FNKSNGAKU    := 0;                           -- 不能欠損額（介護退職）
      RwKIBETSUCAL.SIEN_ZEN_FNKSNGAKU   := 0;                           -- 不能欠損額（支援全体）
      RwKIBETSUCAL.SIEN_TAI_FNKSNGAKU   := 0;                           -- 不能欠損額（支援退職）
      RwKIBETSUCAL.KOJISOTATSU_KBN      := 0;                           -- 公示送達区分
      RwKIBETSUCAL.SYS_SAKUSEIBI        := NULL;                        -- 作成日
      RwKIBETSUCAL.SYS_KOSHINBI         := NULL;                        -- 更新日
      RwKIBETSUCAL.SYS_JIKAN            := NULL;                        -- システム時間
      RwKIBETSUCAL.SYS_SHOKUINKOJIN_NO  := NULL;                        -- 職員番号
      RwKIBETSUCAL.SYS_TANMATSU_NO      := i_VTANMATSU;                 -- 端末番号
      IF NwIX = 1 THEN
        RwKIBETSUCAL.ZEN_ZEIGAKU        := NwZEN_ZEIGAKU + NwZEN_HASU;  -- 全体税額
        RwKIBETSUCAL.TAI_ZEIGAKU        := NwTAI_ZEIGAKU + NwTAI_HASU;  -- 退職税額
      ELSE
        RwKIBETSUCAL.ZEN_ZEIGAKU        := NwZEN_ZEIGAKU;               -- 全体税額
        RwKIBETSUCAL.TAI_ZEIGAKU        := NwTAI_ZEIGAKU;               -- 退職税額
      END IF;

-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
      RwKIBETSUCAL.KDM_ZEN_ZEIGAKU      := 0;
      RwKIBETSUCAL.KDM_ZEN_FNKSNGAKU    := 0;
-- 2025/08/11 ZCZL.LISHUAI ADD END
      INSERT INTO ZLBTKIBETSU_CAL VALUES RwKIBETSUCAL;

    END LOOP;
    -- 翌年度データ作成判定
    IF NKISU = 3 THEN
      o_BwKIBETSU := TRUE;  -- 翌年度作成
    ELSE
      o_BwKIBETSU := FALSE; -- 年度途中に75歳到達なので翌年度未作成
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKEKIBETSU_10 現年度期別作成(特徴月=10月)（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKEKIBETSU_10;

-----------------------------------------------------------
--  8-2 現年度期別作成(特徴月=12月or2月)
-----------------------------------------------------------
FUNCTION FUNCMAKEKIBETSU_12(o_BwKIBETSU OUT BOOLEAN, o_BwTOKUOK OUT BOOLEAN) RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN              PLS_INTEGER := c_IRETOK;               -- 戻り値
  NwZEN_ZEIGAKU_CAL  NUMBER := 0;                           -- 現在の特徴税額(4月～9月) 全体
  NwTAI_ZEIGAKU_CAL  NUMBER := 0;                           --                          退職
  NwZEN_ZEIGAKU_N    NUMBER := 0;                           -- 納期到来期別の普徴期別額 全体
  NwTAI_ZEIGAKU_N    NUMBER := 0;                           --                          退職
  NwSHUNOGAKU_ZEN    NUMBER := 0;                           -- 納期未到来期別の普徴期の納付済み額 全体
  NwSHUNOGAKU_TAI    NUMBER := 0;                           --                                    退職
  NwZEN_KIWARI       NUMBER := 0;                           -- 期割対象額 全体
  NwTAI_KIWARI       NUMBER := 0;                           --            退職
  NwZEN_ZEIGAKU      NUMBER := 0;                           -- 特徴１期分 全体額
  NwTAI_ZEIGAKU      NUMBER := 0;                           --            退職
  RwKIBETSUCAL       ZLBTKIBETSU_CAL%ROWTYPE;         -- 計算期別 insert用変数
BEGIN
  BEGIN
  o_BwTOKUOK         := TRUE;

    -- 8-2A 現年度の計算基本(医療、介護、支援、子ども)取得
    IwRTN := FUNCGETCAL(i_NNENDO,
                        i_NNENDO_BUN);
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKEKIBETSU_12 現年度期別作成(特徴月=12月or２月)（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-2B 計算期別 １期?特徴開始期-1の特徴期別データの全体税額、退職税額の合計 取得
    SELECT NVL(SUM(ZEN_ZEIGAKU),0), NVL(SUM(TAI_ZEIGAKU),0) INTO NwZEN_ZEIGAKU_CAL, NwTAI_ZEIGAKU_CAL FROM  ZLBTKIBETSU_CAL
     WHERE KAMOKU_CD       = c_NKAMOKU_CD                      -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD2                    -- 科目詳細コード【特徴】
       AND KOKU_SETAI_NO   = i_NSETAI                          -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI                         -- 算定団体コード
       AND CHOTEINENDO     = i_NNENDO                          -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN                      -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO                      -- 通知書番号
       AND SYS_TANMATSU_NO = i_VTANMATSU                       -- 端末番号
       AND (RONRIKIBETSU BETWEEN 1 AND NGENNEN_KIBETSU-1);     -- 論理期別

    -- 8-2C 賦課期別 納期到来期別の普徴期別データの全体税額、退職税額の合計 取得
    SELECT NVL(SUM(ZEN_ZEIGAKU),0), NVL(SUM(TAI_ZEIGAKU),0) INTO NwZEN_ZEIGAKU_N, NwTAI_ZEIGAKU_N FROM  ZLBTKIBETSU_N
     WHERE KAMOKU_CD       = c_NKAMOKU_CD                      -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD1                    -- 科目詳細コード【普徴】
       AND KOKU_SETAI_NO   = i_NSETAI                          -- 国保世帯番号
       AND SANTEIDANTAI_CD = i_NDANTAI                         -- 算定団体コード
       AND CHOTEINENDO     = i_NNENDO                          -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN                      -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO                      -- 通知書番号
       AND RONRIKIBETSU    < NGENNEN_KIBETSU;                  -- 論理期別(特徴月-1期)

    -- 8-2D 収納期別 納期未到来期別の普徴期別データの納付済み金額(全体の場合) 取得
    SELECT NVL(SUM(SHUNOGAKU),0) INTO NwSHUNOGAKU_ZEN FROM ZLBTSHUNO
     WHERE KAMOKU_CD       = c_NKAMOKU_CD                      -- 科目コード
       AND KAMOKUS_CD      = c_NKAMOKUS_CD1                    -- 科目詳細コード【普徴】
       AND KIWARIDANTAI_CD = NKIWARIDANTAI_CD                  -- 期割団体コード
       AND CHOTEINENDO     = i_NNENDO                          -- 調停年度
       AND NENDOBUN        = i_NNENDO_BUN                      -- 年度分
       AND TSUCHI_NO       = i_NTSUCHI_NO                      -- 通知書番号
       AND YUSEN_KBN       = 0                                 --優先区分
       AND RONRIKIBETSU    >= NGENNEN_KIBETSU;                 -- 論理期別(特徴月以降)

    -- 8-2E 収納期別 納期未到来期別の普徴期別データの納付済み金額(退職の場合) 取得
    SELECT NVL(SUM(TRUNC(A.SHUNOGAKU * (B.TAI_ZEIGAKU / B.ZEN_ZEIGAKU))),0) INTO NwSHUNOGAKU_TAI FROM ZLBTSHUNO A,ZLBTKIBETSU_N B
     WHERE A.KAMOKU_CD       = c_NKAMOKU_CD                    -- 科目コード
       AND A.KAMOKUS_CD      = c_NKAMOKUS_CD1                  -- 科目詳細コード
       AND A.KIWARIDANTAI_CD = NKIWARIDANTAI_CD                -- 期割団体コード
       AND A.CHOTEINENDO     = i_NNENDO                        -- 調停年度
       AND A.NENDOBUN        = i_NNENDO_BUN                    -- 年度分
       AND A.TSUCHI_NO       = i_NTSUCHI_NO                    -- 通知書番号
       AND A.YUSEN_KBN       = 0                               --優先区分
       AND A.RONRIKIBETSU    >= NGENNEN_KIBETSU                -- 論理期別(特徴月以降)
       AND B.KAMOKU_CD       = A.KAMOKU_CD                     -- 科目コード
       AND B.KAMOKUS_CD      = A.KAMOKUS_CD                    -- 科目詳細コード
       AND B.KIWARIDANTAI_CD = A.KIWARIDANTAI_CD               -- 期割団体コード
       AND B.CHOTEINENDO     = A.CHOTEINENDO                   -- 調停年度
       AND B.NENDOBUN        = A.NENDOBUN                      -- 年度分
       AND B.TSUCHI_NO       = A.TSUCHI_NO                     -- 通知書番号
       AND B.RONRIKIBETSU    = A.RONRIKIBETSU;                 -- 論理期別

    -- 8-2F 全体期別金額算出
    -- 未徴収金額÷残期数で算出して徴収 ※未徴収金額に納期未到来の納付済み金額は含まない
-- 2025/08/11 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応
--     NwZEN_KIWARI := RKIHONCAL.NENZEI + RKAIKIHONCAL.NENZEI + RSIENKIHONCAL.NENZEI
    NwZEN_KIWARI := RKIHONCAL.NENZEI + RKAIKIHONCAL.NENZEI + RSIENKIHONCAL.NENZEI + RKDMKIHONCAL.NENZEI
                 - NwZEN_ZEIGAKU_CAL - NwZEN_ZEIGAKU_N      - NwSHUNOGAKU_ZEN;
    NwZEN_ZEIGAKU := TRUNC(ROUND(NwZEN_KIWARI / NKISU) / 100) * 100;

    -- 8-2G 特徴開始不可能時、計算特徴対象者TBLを削除
    IF NwZEN_ZEIGAKU <= 0 THEN
      -- 計算特徴対象者 削除
      DELETE FROM ZLBTTOKU_KIHON_CAL
       WHERE KOKU_SETAI_NO   = i_NSETAI           -- 国保世帯番号
         AND SANTEIDANTAI_CD = i_NDANTAI          -- 算定団体コード
         AND TSUCHI_NO       = i_NTSUCHI_NO       -- 通知書番号
         -- 現年度も翌年度も処理されるため通知書番号の分岐を行う
         AND ((TSUCHI_NO       = i_NTSUCHI_NO    AND CHOTEI_NENDO  = i_NNENDO     AND NENDO_BUN = i_NNENDO_BUN) OR
              (TSUCHI_NO       = NYOKU_TSUCHI_NO AND CHOTEI_NENDO  = i_NNENDO + 1 AND NENDO_BUN = i_NNENDO_BUN + 1))
         AND SYS_TANMATSU_NO = i_VTANMATSU;       -- 更新端末番号

       --計算異動の中止事由(減額更正)をセット
       UPDATE ZLBTTOKU_IDO_CAL SET CHUSHI_JIYU = 1
        WHERE KOKU_SETAI_NO   = i_NSETAI      -- 国保世帯番号
          AND SYS_TANMATSU_NO = i_VTANMATSU;  -- 更新端末番号
      o_BwKIBETSU := FALSE;
      o_BwTOKUOK := FALSE;
      RETURN IwRTN;
    END IF;

    -- 8-2H 退職期別金額算出
    NwTAI_KIWARI := RTAICAL.NENZEI   + RKAITAICAL.NENZEI + RSIENTAICAL.NENZEI
                 - NwTAI_ZEIGAKU_CAL - NwTAI_ZEIGAKU_N    - NwSHUNOGAKU_TAI;
    NwTAI_ZEIGAKU := TRUNC(ROUND(NwTAI_KIWARI / NKISU) / 100) * 100;

    IF NwTAI_ZEIGAKU < 0 THEN
      NwTAI_ZEIGAKU := 0;
    END IF;

   -- 8-2I 計算期別レコードInsert
    RwKIBETSUCAL.KAMOKU_CD            := c_NKAMOKU_CD;                  -- 科目コード
    RwKIBETSUCAL.KAMOKUS_CD           := c_NKAMOKUS_CD2;                -- 科目詳細コード【特徴】
    RwKIBETSUCAL.KOKU_SETAI_NO        := RKIHONCAL.KOKU_SETAI_NO;       -- 国保世帯番号
    RwKIBETSUCAL.SANTEIDANTAI_CD      := RKIHONCAL.SANTEIDANTAI_CD;     -- 算定団体コード
    RwKIBETSUCAL.KIWARIDANTAI_CD      := 0;                             -- 期割団体コード
    RwKIBETSUCAL.DANTAING_KBN         := 0;                             -- 団体内外区分
    RwKIBETSUCAL.GENNENKANEN_KBN      := 0;                             -- 現年過年区分
    RwKIBETSUCAL.CHOTEINENDO          := RKIHONCAL.CHOTEI_NENDO;        -- 調停年度
    RwKIBETSUCAL.NENDOBUN             := RKIHONCAL.NENDO_BUN;           -- 年度分
    RwKIBETSUCAL.TSUCHI_NO            := RKIHONCAL.TSUCHI_NO;           -- 翌年度通知書番号
    RwKIBETSUCAL.R_NO                 := RKIHONCAL.R_NO;                -- 履歴番号
    RwKIBETSUCAL.NUSHI_KOJIN_NO       := RTOKUHOSOKU.TOKU_KOJIN_NO;     -- 納税義務者個人番号
    RwKIBETSUCAL.KOSEI_BI             := NKOSEIBI;                      -- 更正日
    RwKIBETSUCAL.ZEN_ZEIGAKU          := NwZEN_ZEIGAKU;                 -- 全体税額
    RwKIBETSUCAL.TAI_ZEIGAKU          := NwTAI_ZEIGAKU;                 -- 退職税額
    RwKIBETSUCAL.IR_ZEN_ZEIGAKU       := 0;                             -- 医療全体税額
    RwKIBETSUCAL.IR_TAI_ZEIGAKU       := 0;                             -- 医療退職税額
    RwKIBETSUCAL.KAI_ZEN_ZEIGAKU      := 0;                             -- 介護全体税額
    RwKIBETSUCAL.KAI_TAI_ZEIGAKU      := 0;                             -- 介護退職税額
    RwKIBETSUCAL.SIEN_ZEN_ZEIGAKU     := 0;                             -- 支援全体税額
    RwKIBETSUCAL.SIEN_TAI_ZEIGAKU     := 0;                             -- 支援退職税額
    RwKIBETSUCAL.IR_ZEN_FNKSNGAKU     := 0;                             -- 不能欠損額（医療全体）
    RwKIBETSUCAL.IR_TAI_FNKSNGAKU     := 0;                             -- 不能欠損額（医療退職）
    RwKIBETSUCAL.KAI_ZEN_FNKSNGAKU    := 0;                             -- 不能欠損額（介護全体）
    RwKIBETSUCAL.KAI_TAI_FNKSNGAKU    := 0;                             -- 不能欠損額（介護退職）
    RwKIBETSUCAL.SIEN_ZEN_FNKSNGAKU   := 0;                             -- 不能欠損額（支援全体）
    RwKIBETSUCAL.SIEN_TAI_FNKSNGAKU   := 0;                             -- 不能欠損額（支援退職）
    RwKIBETSUCAL.KOJISOTATSU_KBN      := 0;                             -- 公示送達区分
    RwKIBETSUCAL.SYS_SAKUSEIBI        := NULL;                          -- 作成日
    RwKIBETSUCAL.SYS_KOSHINBI         := NULL;                          -- 更新日
    RwKIBETSUCAL.SYS_JIKAN            := NULL;                          -- システム時間
    RwKIBETSUCAL.SYS_SHOKUINKOJIN_NO  := NULL;                          -- 職員番号
    RwKIBETSUCAL.SYS_TANMATSU_NO      := i_VTANMATSU;                   -- 端末番号

    -- 12月レコード作成
    IF i_NTOKU_TUKI = 12 THEN
      -- 年度内に特徴中止⇒特徴開始となった場合のためにDELETEしておく(現状、実運用では有り得ない)
      DELETE FROM ZLBTKIBETSU_CAL
        WHERE KAMOKU_CD       = c_NKAMOKU_CD                -- 科目コード
          AND KAMOKUS_CD      = c_NKAMOKUS_CD2              -- 科目詳細コード【特徴】
          AND KOKU_SETAI_NO   = RKIHONCAL.KOKU_SETAI_NO     -- 国保世帯番号
          AND SANTEIDANTAI_CD = RKIHONCAL.SANTEIDANTAI_CD   -- 期割団体コード
          AND CHOTEINENDO     = RKIHONCAL.CHOTEI_NENDO      -- 調停年度
          AND NENDOBUN        = RKIHONCAL.NENDO_BUN         -- 年度分
          AND TSUCHI_NO       = RKIHONCAL.TSUCHI_NO         -- 通知書番号
          AND RONRIKIBETSU    = NTOKU_KIBETSU               -- 論理期別
          AND SYS_TANMATSU_NO = i_VTANMATSU;                -- 端末番号
      -- 9期(12月)の計算期別TBLのレコードを作成する
      RwKIBETSUCAL.RONRIKIBETSU       := NTOKU_KIBETSU;
      RwKIBETSUCAL.NENGETSU           := i_NNENDO * 100 + i_NTOKU_TUKI;
      INSERT INTO ZLBTKIBETSU_CAL VALUES RwKIBETSUCAL;
    END IF;

    -- 2月レコード作成
    -- 年度内に特徴中止⇒特徴開始となった場合のためにDELETEしておく(現状、実運用では有り得ない)
    DELETE FROM ZLBTKIBETSU_CAL
      WHERE KAMOKU_CD       = c_NKAMOKU_CD                -- 科目コード
        AND KAMOKUS_CD      = c_NKAMOKUS_CD2              -- 科目詳細コード【特徴】
        AND KOKU_SETAI_NO   = RKIHONCAL.KOKU_SETAI_NO     -- 国保世帯番号
        AND SANTEIDANTAI_CD = RKIHONCAL.SANTEIDANTAI_CD   -- 期割団体コード
        AND CHOTEINENDO     = RKIHONCAL.CHOTEI_NENDO      -- 調停年度
        AND NENDOBUN        = RKIHONCAL.NENDO_BUN         -- 年度分
        AND TSUCHI_NO       = RKIHONCAL.TSUCHI_NO         -- 通知書番号
        AND RONRIKIBETSU    = 11                          -- 論理期別
        AND SYS_TANMATSU_NO = i_VTANMATSU;                -- 端末番号
    -- 11期(2月)の計算期別TBLのレコードを作成する
    RwKIBETSUCAL.RONRIKIBETSU         := 11;
    RwKIBETSUCAL.NENGETSU             := (i_NNENDO + 1) * 100 + 2;
-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
    RwKIBETSUCAL.KDM_ZEN_ZEIGAKU      := 0;
    RwKIBETSUCAL.KDM_ZEN_FNKSNGAKU    := 0;
-- 2025/08/11 ZCZL.LISHUAI ADD END
    INSERT INTO ZLBTKIBETSU_CAL VALUES RwKIBETSUCAL;

    -- 翌年度データ作成判定
    IF NGENNEN_KIBETSU = 9 AND NKISU = 1 THEN
      o_BwKIBETSU := FALSE; -- 年度途中に75歳到達なので翌年度未作成
    ELSE
      o_BwKIBETSU := TRUE;  -- 翌年度作成
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKEKIBETSU_12 現年度期別作成(特徴月=12月or2月)（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKEKIBETSU_12;

-----------------------------------------------------------
--  8-8 現年度期別作成(特徴月=8月)
-----------------------------------------------------------
FUNCTION FUNCMAKEKIBETSU_8 RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN          PLS_INTEGER := c_IRETOK;                   -- 戻り値
  RwKIBETSUCAL   ZLBTKIBETSU_CAL%ROWTYPE;             -- 計算期別出力用ワーク
  NwZEN_KIWARI   NUMBER := 0;                               -- 期割対象額 全体
  NwTAI_KIWARI   NUMBER := 0;                               --            退職
  NwZEN_ZEIGAKU  NUMBER := 0;                               -- 特徴１期分 全体額
  NwTAI_ZEIGAKU  NUMBER := 0;                               --            退職
  NKIWARIKEISU   NUMBER(2):= 6;                             -- 期割係数
  NFFJKN2        NUMBER:= 0;

BEGIN
  BEGIN
    NFFJKN2 := ZLBPK00010.FCFFJKN2(91);
    IF NFFJKN2 = 1 THEN
      NKIWARIKEISU := 4;
    END IF;
    -- 8-8A 前年度の賦課基本取得
    IwRTN := FUNCGETN(i_NNENDO - 1,
                     i_NNENDO_BUN - 1);
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCMAKEKIBETSU_8 ★FUNCGETN★ 現年度期別作成(特徴月=8月)（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-8B 現年度計算基本の履歴番号取得
    BEGIN
      SELECT R_NO INTO NGENRNO FROM ZLBTKIHON_CAL
       WHERE KOKU_SETAI_NO   = i_NSETAI          -- 国保世帯番号
         AND SANTEIDANTAI_CD = i_NDANTAI         -- 算定団体コード
         AND CHOTEI_NENDO    = i_NNENDO          -- 調停年度
         AND NENDO_BUN       = i_NNENDO_BUN      -- 年度分
         AND TSUCHI_NO       = i_NTSUCHI_NO      -- 通知書番号
         AND SYS_TANMATSU_NO = i_VTANMATSU;      -- 更新端末番号
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NGENRNO := 10;
      WHEN OTHERS THEN
        IwRTN := c_IRETNG;
        VERROR := VERROR || 'FUNCMAKEKIBETSU_8 ★現年度計算基本の履歴番号取得★ 現年度期別作成(特徴月=8月)（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
    END;

    -- 期割対象額 全体 算出
    NwZEN_KIWARI  := RKIHONN.NENZEI
                  + RKAIKIHONN.NENZEI
-- 2025/08/11 ZCZL.LISHUAI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                   + RSIENKIHONN.NENZEI;
                  + RSIENKIHONN.NENZEI
                  + RKDMKIHONN.NENZEI;
-- 2025/08/11 ZCZL.LISHUAI UPDATE END
    -- 特徴１期分 全体額
    NwZEN_ZEIGAKU := TRUNC(ROUND(NwZEN_KIWARI / NKIWARIKEISU) / 100) * 100;

    -- 期割対象額 退職 算出
    NwTAI_KIWARI  := RTAIN.NENZEI
                  + RKAITAIN.NENZEI
                  + RSIENTAIN.NENZEI;
    -- 特徴１期分 退職額
    NwTAI_ZEIGAKU := TRUNC(ROUND(NwTAI_KIWARI / NKIWARIKEISU) / 100) * 100;

    -- 年度内に特徴中止⇒特徴開始となった場合のためにDELETEしておく(現状、実運用では有り得ない)
    DELETE FROM ZLBTKIBETSU_CAL
      WHERE KAMOKU_CD       = c_NKAMOKU_CD               -- 科目コード
        AND KAMOKUS_CD      = c_NKAMOKUS_CD2             -- 科目詳細コード【特徴】
        AND KOKU_SETAI_NO   = RKIHONN.KOKU_SETAI_NO      -- 国保世帯番号
        AND SANTEIDANTAI_CD = RKIHONN.SANTEIDANTAI_CD    -- 期割団体コード
        AND CHOTEINENDO     = i_NNENDO                   -- 調停年度
        AND NENDOBUN        = i_NNENDO_BUN               -- 年度分
        AND TSUCHI_NO       = i_NTSUCHI_NO               -- 通知書番号
        AND RONRIKIBETSU    = 5                          -- 論理期別
        AND SYS_TANMATSU_NO = i_VTANMATSU;               -- 端末番号

    -- 計算期別TBL 作成
    RwKIBETSUCAL.KAMOKU_CD            := c_NKAMOKU_CD;                 -- 科目コード
    RwKIBETSUCAL.KAMOKUS_CD           := c_NKAMOKUS_CD2;               -- 科目詳細コード【特徴】
    RwKIBETSUCAL.KOKU_SETAI_NO        := RKIHONN.KOKU_SETAI_NO;        -- 国保世帯番号
    RwKIBETSUCAL.SANTEIDANTAI_CD      := RKIHONN.SANTEIDANTAI_CD;      -- 算定団体コード
    RwKIBETSUCAL.KIWARIDANTAI_CD      := 0;                            -- 期割団体コード
    RwKIBETSUCAL.DANTAING_KBN         := 0;                            -- 団体内外区分
    RwKIBETSUCAL.GENNENKANEN_KBN      := 0;                            -- 現年過年区分
    RwKIBETSUCAL.CHOTEINENDO          := i_NNENDO;                     -- 調停年度
    RwKIBETSUCAL.NENDOBUN             := i_NNENDO_BUN;                 -- 年度分
    RwKIBETSUCAL.TSUCHI_NO            := i_NTSUCHI_NO;                 -- 翌年度通知書番号
    RwKIBETSUCAL.RONRIKIBETSU         := 5;                            -- 履歴番号
    RwKIBETSUCAL.R_NO                 := NGENRNO;                      -- 履歴番号
    RwKIBETSUCAL.NENGETSU             := i_NNENDO * 100 + 8;           -- 年月
    RwKIBETSUCAL.NUSHI_KOJIN_NO       := RTOKUHOSOKU.TOKU_KOJIN_NO;    -- 納税義務者個人番号
    RwKIBETSUCAL.KOSEI_BI             := NKOSEIBI;                     -- 更正日
    RwKIBETSUCAL.ZEN_ZEIGAKU          := NwZEN_ZEIGAKU;                -- 全体税額
    RwKIBETSUCAL.TAI_ZEIGAKU          := NwTAI_ZEIGAKU;                -- 退職税額
    RwKIBETSUCAL.IR_ZEN_ZEIGAKU       := 0;                            -- 医療全体税額
    RwKIBETSUCAL.IR_TAI_ZEIGAKU       := 0;                            -- 医療退職税額
    RwKIBETSUCAL.KAI_ZEN_ZEIGAKU      := 0;                            -- 介護全体税額
    RwKIBETSUCAL.KAI_TAI_ZEIGAKU      := 0;                            -- 介護退職税額
    RwKIBETSUCAL.SIEN_ZEN_ZEIGAKU     := 0;                            -- 支援全体税額
    RwKIBETSUCAL.SIEN_TAI_ZEIGAKU     := 0;                            -- 支援退職税額
    RwKIBETSUCAL.IR_ZEN_FNKSNGAKU     := 0;                            -- 不能欠損額（医療全体）
    RwKIBETSUCAL.IR_TAI_FNKSNGAKU     := 0;                            -- 不能欠損額（医療退職）
    RwKIBETSUCAL.KAI_ZEN_FNKSNGAKU    := 0;                            -- 不能欠損額（介護全体）
    RwKIBETSUCAL.KAI_TAI_FNKSNGAKU    := 0;                            -- 不能欠損額（介護退職）
    RwKIBETSUCAL.SIEN_ZEN_FNKSNGAKU   := 0;                            -- 不能欠損額（支援全体）
    RwKIBETSUCAL.SIEN_TAI_FNKSNGAKU   := 0;                            -- 不能欠損額（支援退職）
    RwKIBETSUCAL.KOJISOTATSU_KBN      := 0;                            -- 公示送達区分
    RwKIBETSUCAL.SYS_SAKUSEIBI        := NULL;                         -- 作成日
    RwKIBETSUCAL.SYS_KOSHINBI         := NULL;                         -- 更新日
    RwKIBETSUCAL.SYS_JIKAN            := NULL;                         -- システム時間
    RwKIBETSUCAL.SYS_SHOKUINKOJIN_NO  := NULL;                         -- 職員番号
    RwKIBETSUCAL.SYS_TANMATSU_NO      := i_VTANMATSU;                  -- 端末番号
-- 2025/08/11 ZCZL.LISHUAI ADD START 1.1.200.000:子ども子育て支援金対応
    RwKIBETSUCAL.KDM_ZEN_ZEIGAKU      := 0;                            --子ども全体税額
    RwKIBETSUCAL.KDM_ZEN_FNKSNGAKU    := 0;                            --不能欠損額（子ども全体）
-- 2025/08/11 ZCZL.LISHUAI ADD END

    INSERT INTO ZLBTKIBETSU_CAL VALUES RwKIBETSUCAL;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCMAKEKIBETSU_8 ★DELETEorINSERT★ 現年度期別作成(特徴月=8月)（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCMAKEKIBETSU_8;

-----------------------------------------------------------
--  8 期割処理メイン
-----------------------------------------------------------
FUNCTION FUNCKIWARIMAIN RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN   PLS_INTEGER := c_IRETOK;                          -- 戻り値
  BwJIKKO BOOLEAN;                                          -- TRUE:翌年データ作成
  BwTOKUOK BOOLEAN;                                          -- 0:特徴データ作成

BEGIN
  BEGIN

    -- 現年 期別作成
    -- 現年 期別作成
    IF i_NTOKU_TUKI IN(10, 12, 2) THEN
      -- 期割対象期数なし
      IF NKISU = 0 THEN
        -- 8-0 現年度特徴中止情報作成
        BwJIKKO := FALSE;    -- 翌年度データ未作成
        IwRTN   := FUNCSTOPTOKUKIHONCAL;
      ELSIF i_NTOKU_TUKI = 10 THEN
        -- 8-1 現年度期別作成(特徴月=10月)
        IwRTN := FUNCMAKEKIBETSU_10( BwJIKKO );
        IF IwRTN <> c_IRETOK THEN
          VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン1（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
          RETURN IwRTN;
        END IF;
      ELSE
        IF NKISU > 0 THEN
          -- 8-2 現年度期別作成(特徴月=10月)
         IwRTN := FUNCMAKEKIBETSU_12( BwJIKKO, BwTOKUOK );
         IF IwRTN <> c_IRETOK THEN
            VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン2（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
            RETURN IwRTN;
          END IF;
         -- 特徴開始できなかった
         IF BwJIKKO = FALSE AND BwTOKUOK = FALSE THEN
            o_NFUTU := c_NFUTU_JIKKO_ONLY;
            RETURN IwRTN;
         END IF;
        END IF;
      END IF;
      -- 残期割無し AND 年度内に75歳到達の場合
      IF BwJIKKO AND NYOKUNEN_TUKI != 0 THEN

        -- 8-3 翌年度期別作成
        IwRTN := FUNCMAKEKIBETSU_YOKU;
        IF IwRTN <> c_IRETOK THEN
          VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン3（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
          RETURN IwRTN;
        END IF;
        -- 8-4 翌年度計算基本作成
        IwRTN := FUNCMAKECAL_YOKU;
        IF IwRTN <> c_IRETOK THEN
          VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン4（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
          RETURN IwRTN;
        END IF;
      ELSE
        o_NFUTU := c_NFUTU_JIKKO;
        RETURN IwRTN;
      END IF;
    -- 翌年 期別作成
     ELSIF i_NTOKU_TUKI = 104 OR i_NTOKU_TUKI = 106 OR i_NTOKU_TUKI = 108 THEN   
      -- 8-5 現年度の計算基本(医療、介護、支援、子ども)取得
      IwRTN := FUNCGETCAL(i_NNENDO,
                         i_NNENDO_BUN);
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン5（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
      -- 8-6 翌年度期別作成
      IwRTN := FUNCMAKEKIBETSU_YOKU;
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン6（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
      -- 8-7 翌年度計算基本作成
      IwRTN := FUNCMAKECAL_YOKU;
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン7（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
      BwJIKKO := TRUE;
    ELSIF i_NTOKU_TUKI = 8 THEN
      -- 8-8 現年度期別作成(特徴月=8月)
      IwRTN := FUNCMAKEKIBETSU_8;
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン8（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;

      -- 8-9 現年度計算基本作成
      IwRTN := FUNCMAKECAL_GEN( BwJIKKO );
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン9（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
    END IF;

    -- 8-10 期割団体コード更新
    IwRTN := FUNCMAKEKIWARIDANTAI;
    IF IwRTN <> c_IRETOK THEN
      VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン10（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
      RETURN IwRTN;
    END IF;

    -- 8-11 通知書番号更新
    IF NYOKU_TSUCHI_NO = 0 THEN
      IwRTN := FUNCMAKETSUCHI;
      IF IwRTN <> c_IRETOK THEN
        VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン11（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました ';
        RETURN IwRTN;
      END IF;
    END IF;

    IF BwJIKKO THEN
      o_NFUTU := c_NFUTU_JIKKO;
    ELSE
      o_NFUTU := c_NFUTU_MIJIKKO;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN   := c_IRETNG;
      VERROR := VERROR || 'FUNCKIWARIMAIN 期割処理メイン（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
  END;
  RETURN IwRTN;
END FUNCKIWARIMAIN;

-----------------------------------------------------------
--  3 初期化
-----------------------------------------------------------
FUNCTION FUNC_INIT RETURN PLS_INTEGER IS
  -- 変数宣言
  IwRTN      PLS_INTEGER := c_IRETOK;                       -- 戻り値
  NwKOJIN_NO NUMBER;                                        -- 世帯主個人番号

BEGIN
  -- 3-1 特徴 論理期別 作成
  IF i_NTOKU_TUKI = 104 THEN
    NTOKU_KIBETSU := 1;
  ELSIF i_NTOKU_TUKI = 106 THEN
    NTOKU_KIBETSU := 3;
  ELSIF (i_NTOKU_TUKI - 3) <= 0 THEN
    NTOKU_KIBETSU := i_NTOKU_TUKI + 9;
  ELSIF i_NTOKU_TUKI = 108 THEN
    NTOKU_KIBETSU := 5;
  ELSE
    NTOKU_KIBETSU := i_NTOKU_TUKI - 3;
  END IF;

  -- 3-2 普徴 論理期別 作成
  IF (i_NFUTU_TUKI - 3) <= 0 THEN
    NFUTU_KIBETSU := i_NFUTU_TUKI + 9;
  ELSE
    NFUTU_KIBETSU := i_NFUTU_TUKI - 3;
  END IF;

  -- 3-3 更正日 作成
  IF NVL(i_NKOSEIBI, 0) > 0 THEN
    NKOSEIBI      := i_NKOSEIBI;                            -- 引数をセット
  ELSE
    NKOSEIBI      := NSYSDATE;                              -- システム日付をセット
  END IF;

  -- 3-4 特徴補足情報 取得
  IwRTN := FUNCGETNUSHI_KOJIN_NO(NwKOJIN_NO);               -- 世帯主個人番号取得
  IF IwRTN <> c_IRETOK THEN
    RETURN IwRTN;
  END IF;
  SELECT * INTO RTOKUHOSOKU FROM ZLBTTOKU_HOSOKU
   WHERE TOKU_KOJIN_NO = NwKOJIN_NO
     AND SAKUSEI_BI = (SELECT MAX(SAKUSEI_BI) FROM ZLBTTOKU_HOSOKU WHERE TOKU_KOJIN_NO = NwKOJIN_NO);
  -- 3-5 期割団体コード 取得
  NKIWARIDANTAI_CD := FUNCGETKIWARIDANTAI;

  -- 3-6 翌年度通知書番号 取得
  SELECT NVL(YOKU_TSUCHI_NO,0) INTO NYOKU_TSUCHI_NO
    FROM ZLBTKIHON_CAL
   WHERE KOKU_SETAI_NO   = i_NSETAI       -- 国保世帯番号
     AND SANTEIDANTAI_CD = i_NDANTAI      -- 算定団体コード
     AND CHOTEI_NENDO    = i_NNENDO       -- 調停年度
     AND NENDO_BUN       = i_NNENDO_BUN   -- 年度分
     AND TSUCHI_NO       = i_NTSUCHI_NO   -- 通知書番号
     AND SYS_TANMATSU_NO = i_VTANMATSU;   -- 更新端末番号

  RETURN IwRTN;
END FUNC_INIT;

-----------------------------------------------------------
--  主処理メイン
-----------------------------------------------------------
BEGIN
  VERROR := '';

  -- 1 変数初期化
  IRET := c_IRETOK;
  BRET := TRUE;

  -- 2 システム日付
  NSYSDATE := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));

  -- 3 初期化

  IRET := FUNC_INIT;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;
  -- 4 計算期別作成
  IRET := FUNCMAKEKIBETSUCAL;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;

  -- 5 計算異動作成

  IRET := FUNCMAKEIDOCAL;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;

  -- 6 開始期と期割期数取得
  IRET := FUNCGETKISU;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;

  -- 7 計算特徴対象者作成
  IRET := FUNCMAKETOKUKIHONCAL;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;
  -- 8期割処理メイン
  IRET := FUNCKIWARIMAIN;
  IF IRET <> c_IRETOK THEN
    GOTO ERROR_EXIT;
  END IF;

  -- 9処理終了
  <<ERROR_EXIT>>
  -- 正常
  IF IRET = c_IRETOK THEN
    BEGIN
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        IRET := c_IRETNG;
        VERROR := VERROR || 'COMMIT発行（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM || ' ';
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
    IF SQLCODE = 0 THEN
        IF i_NTRENBAN = 0 THEN
          BRET := KKBPK5551.FSETOLOG (i_VTANMATSU,TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'),'ZLBSKCALKWTKST',1,0,'','',VERROR);
        ELSE
          BRET := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKCALKWTKST', 1, '', '', 'ZLBSKCALKWTKST ' || VERROR, '', i_VTANMATSU);
        END IF;
      ELSE
        IF i_NTRENBAN = 0 THEN
          BRET := KKBPK5551.FSETOLOG (i_VTANMATSU,TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'),'ZLBSKCALKWTKST',1,0,SQLCODE, SQLERRM,VERROR);
        ELSE
          BRET := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKCALKWTKST', 1, SQLCODE, SQLERRM, 'ZLBSKCALKWTKST ' || VERROR, '', i_VTANMATSU);
        END IF;
      END IF;
  END IF;

  o_NRESULT := IRET;

END ZLBSKCALKWTKST;
/