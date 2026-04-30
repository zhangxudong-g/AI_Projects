CREATE OR REPLACE PROCEDURE ZLBSBKJDIV(i_NGENKA_KBN       IN  NUMBER,
--1.1.200.000
                                         i_NKOKU_SETAI_NO   IN  NUMBER,
                                         i_NFUKA_KIJITU     IN  NUMBER,
                                         i_NKIJUN_BI        IN  NUMBER,
                                         i_NJIKKOU_KBN      IN  NUMBER,
                                         i_VMASIN_NO        IN  NVARCHAR2,
                                         i_NTRENBAN         IN  NUMBER,
                                         o_NRESULT          OUT NUMBER)
-------------------------------------------------------------------------------
-- 業務名   ZLB（国民健康保険税）
-- ＰＧ名   ZLBSBKJDIV
-- 名称     計算個人分割
-- 処理概要 作成した計算個人TBLの各レコードを算定団体および世帯主単位に
--          分割する。
-- 引き数   i_NGENKA_KBN        現年・過年区分(0:現年 1:過年)
--          i_NKOKU_SETAI_NO    国保世帯番号
--          i_NFUKA_KIJITU      賦課期日
--          i_NKIJUN_BI         判定基準日
--          i_NJIKKOU_KBN       実行区分(0:バッチから起動 本算定/月例...
--                                       1:オンライン起動 即時)
--          i_VMASIN_NO         端末番号
--          i_NTRENBAN          登録連番
--          o_NRESULT           処理結果(0:OK 9:NG)
--  作成者      ZCZL.LIUCHENYU
--  作成日      2023/08/04
--  VERSION     0.2.000.000
-------------------------------------------------------------------------------------
--変更履歴
--2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
--  2024/05/07 ZCZL.GUANHONG UPDATE 0.3.000.100: 国保2次にマージ作業
--  2024/09/18 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00015
--  2025/08/11 ZCZL.LIUCHENYU UPDATE 1.1.200.000:子ども子育て支援金対応
-------------------------------------------------------------------------------
IS

    TYPE MTKOJIN  IS TABLE OF ZLBTKOJIN_CAL%ROWTYPE INDEX BY BINARY_INTEGER;

    TYPE MTSANTEI IS TABLE OF NUMBER(2) INDEX BY BINARY_INTEGER;
--  2024/09/18 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00015
    --TYPE MTNUSHI  IS TABLE OF NUMBER(12) INDEX BY BINARY_INTEGER;
    TYPE MTNUSHI  IS TABLE OF NUMBER(20) INDEX BY BINARY_INTEGER;
    TYPE MTKBN    IS TABLE OF NUMBER(1) INDEX BY BINARY_INTEGER;

-------------------------------------------------------------------------------
-- ワークエリアの定義
-------------------------------------------------------------------------------

    NlRTN               NUMBER;                 -- 処理結果
    BlRTN               BOOLEAN;

    -- 分割情報(12か月分:1=4月)
    MlSANTEI            MTSANTEI;           -- 算定団体コード
    MlNUSHI             MTNUSHI;            -- 世帯主
    MlNUSHI_BI          MTNUSHI;            -- 世帯主 適用開始日
    MlNUSHI_BI2          MTNUSHI;           -- 世帯主変更月は、適用開始日をセット。以外は、各月の月末日をセットする。
    MlSEISAN            MTKBN;              -- 清算区分
    MlNEWKBN            MTKBN;              -- 最新
    MlF4KBN             MTKBN;              -- 賦課
    MlFUKAKBN           MTKBN;              -- 賦課発生
    MlNEWSHITSUKBN      MTKBN;              -- 最新失業者資格区分
    MlF4SHITSUKBN       MTKBN;              -- 賦課期日失業者資格区分

    -- カウンタ
    NlCNT               NUMBER;             -- 分割レコード数

    -- データ保持
    MlKOJIN             MTKOJIN;                    -- 分割レコード
-- 2024/05/07 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
    MlNEWSANKBN         MTKBN;              -- 各月最新産前産後資格区分
    MlF4SANKBN          MTKBN;              -- 各月賦課期日産前産後資格区分
-- 2024/05/07　ZCZL.GUANHONG　Add　End

-------------------------------------------------------------------------------
-- 定数の定義
-------------------------------------------------------------------------------

    c_NOK               CONSTANT NUMBER := 0;   -- 処理正常
    c_NERR              CONSTANT NUMBER := 9;   -- 処理異常

    -- 実行区分
    c_NBATCH        CONSTANT NUMBER(1) := 0;        -- バッチから起動
    c_NONLNIN       CONSTANT NUMBER(1) := 1;        -- オンライン起動

    -- 現年・過年区分
    c_NGENNEN       CONSTANT NUMBER(1) := 0;        -- 現年
    c_NKANEN        CONSTANT NUMBER(1) := 1;        -- 過年

    -- 資格区分(賦課期日／各月)
    c_NASHI         CONSTANT NUMBER(2) :=  0;       -- 資格なし
    c_NUSHI         CONSTANT NUMBER(2) :=  1;       -- 世帯主
    c_GINUSHI       CONSTANT NUMBER(2) :=  2;       -- 擬主
    c_SETAIIN       CONSTANT NUMBER(2) :=  3;       -- 世帯員
    c_NUSHI_TAI     CONSTANT NUMBER(2) := 11;       -- 世帯主(退職該当)
    c_SETAIIN_TAI   CONSTANT NUMBER(2) := 13;       -- 世帯員(退職該当)


-------------------------------------------------------------------------------
-- カーソルの定義
-------------------------------------------------------------------------------
    CURSOR ClKOJIN(p_NKOKU_SETAI_NO NUMBER) IS
        SELECT * FROM ZLBTKOJIN_CAL
        WHERE KOKU_SETAI_NO   = p_NKOKU_SETAI_NO
          AND SYS_TANMATSU_NO = i_VMASIN_NO;

-- 2024/05/07 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
-------------------------------------------------------------------------------
-- 産前産後区分取得
-------------------------------------------------------------------------------
    FUNCTION funcSanKbnGet(i_NIX IN NUMBER, i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) RETURN NUMBER IS
      NwSHIK    NUMBER(2);--資格区分
    BEGIN
      NwSHIK := 0;
      CASE i_NIX
       WHEN 1 THEN
         NwSHIK := i_RKOJIN.SAN_4;
       WHEN 2 THEN
         NwSHIK := i_RKOJIN.SAN_5;
       WHEN 3 THEN
         NwSHIK := i_RKOJIN.SAN_6;
       WHEN 4 THEN
         NwSHIK := i_RKOJIN.SAN_7;
       WHEN 5 THEN
         NwSHIK := i_RKOJIN.SAN_8;
       WHEN 6 THEN
         NwSHIK := i_RKOJIN.SAN_9;
       WHEN 7 THEN
         NwSHIK := i_RKOJIN.SAN_10;
       WHEN 8 THEN
         NwSHIK := i_RKOJIN.SAN_11;
       WHEN 9 THEN
         NwSHIK := i_RKOJIN.SAN_12;
       WHEN 10 THEN
         NwSHIK := i_RKOJIN.SAN_1;
       WHEN 11 THEN
         NwSHIK := i_RKOJIN.SAN_2;
       WHEN 12 THEN
         NwSHIK := i_RKOJIN.SAN_3;
       ELSE
         NULL;
      END CASE;
      RETURN NwSHIK;
    END funcSanKbnGet;
-- 2024/05/07　ZCZL.GUANHONG　Add　End
-------------------------------------------------------------------------------
-- 12 各月資格区分再セット
-------------------------------------------------------------------------------
    PROCEDURE subSikakuSaiSet IS

    -- ワークエリア -----------------------------------------------------------
--  2024/09/18 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00015
    --TYPE TwMM     IS TABLE OF NUMBER(12,0)  INDEX BY BINARY_INTEGER;
    TYPE TwMM     IS TABLE OF NUMBER(15,0)  INDEX BY BINARY_INTEGER;
    TYPE TwYYYYMM IS TABLE OF NUMBER(6)     INDEX BY BINARY_INTEGER;
    VwMM              TwMM;                         -- 各月毎の世帯主配列
    VwYYYYMM          TwYYYYMM;                     -- 更新対応年月配列
    NwNendo           NUMBER(4);                    -- 処理年度
    NwDATE_START      NUMBER(8);                    -- 期首日(4/1)
    NwDATE_END        NUMBER(8);                    -- 期末日(3/31)
    IwNUSHI_TEKI_MM   NUMBER(6);                    -- 適用開始月
    IwX               NUMBER(2);                    -- 添字
    --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
    --NwNUSHI_KOJIN_NO  NUMBER(12);                   -- 世帯主
    NwNUSHI_KOJIN_NO  NUMBER;                   -- 世帯主
    NwSHIK            NUMBER(2);                    -- 各月資格区分
    VwSQL             VARCHAR2(1000);               -- sql文
    IwCUR             PLS_INTEGER;
    IwPRC             PLS_INTEGER;

    -- カーソル ----------------------------------------------------------------
    -- 世帯主管理(ZLBTNUSHI_TMP)
    CURSOR CZLBTNUSHI_TMP is
      SELECT NUSHI_TEKI_SBI
            ,NUSHI_KOJIN_NO
        FROM ZLBTNUSHI_TMP
       WHERE KOKU_SETAI_NO    =  i_NKOKU_SETAI_NO
         AND NUSHI_TEKI_SBI   <= NwDATE_END          -- 適用開始日 <= 3/31
         AND SYS_TANMATSU_NO  =  i_VMASIN_NO
       ORDER BY NUSHI_TEKI_SBI DESC, R_NO DESC;
    -- 計算個人  (ZLBTKOJIN_CAL)
    CURSOR CZLBTKOJIN_CAL IS
        SELECT * FROM ZLBTKOJIN_CAL
        WHERE KOKU_SETAI_NO   =  i_NKOKU_SETAI_NO
          AND KOJIN_NO        <> NwNUSHI_KOJIN_NO
          AND SYS_TANMATSU_NO =  i_VMASIN_NO;

    -- レコードセット ----------------------------------------------------------
    RZLBTNUSHI_TMP CZLBTNUSHI_TMP%ROWTYPE;
    RZLBTKOJIN_CAL CZLBTKOJIN_CAL%ROWTYPE;

    BEGIN
      -- ①各月の世帯主特定 ----------------------------------------------------
      -- 賦課年度(賦課期日)の期首日と期末日算出
      NwNendo           :=  TRUNC(i_NFUKA_KIJITU/10000);               -- 賦課期日から年度算出
      NwDATE_START      :=  TO_NUMBER(TO_CHAR(NwNendo)     || '0401'); -- 年度+0401
      NwDATE_END        :=  TO_NUMBER(TO_CHAR(NwNendo + 1) || '0331'); -- 翌年+0331

      -- 各月毎の世帯主配列初期化
      FOR IwX IN 0..12 LOOP
        VwMM(IwX) := NULL;
        MlNUSHI_BI(IwX) := 0;
      END LOOP;

      -- 日付対応配列に年月セット
      VwYYYYMM(1) := SUBSTR(NwDATE_START ,1,6);
      FOR IwX IN 2..12 LOOP
        VwYYYYMM(IwX) := SUBSTR(KKAPK0020.FDATECAL( TO_NUMBER(VwYYYYMM(IwX - 1) || '01'),
0,
0,
1,
                                                    0) ,1,6) ;
                                                    -- コメント追加
                                                    --   ex. 年度 = 2016
                                                    --       ...
      END LOOP;

      -- 各月世帯主を配列にセット
      FOR RZLBTNUSHI_TMP IN CZLBTNUSHI_TMP LOOP

        -- 4月まで埋まっていれば処理終了
        IF VwMM(1) IS NOT NULL THEN
          EXIT;
        END IF;

        -- 賦課期日の世帯主を配列にセット
        IF RZLBTNUSHI_TMP.NUSHI_TEKI_SBI <= i_NFUKA_KIJITU THEN
          VwMM(0) := RZLBTNUSHI_TMP.NUSHI_KOJIN_NO;
          MlNUSHI_BI(0) := RZLBTNUSHI_TMP.NUSHI_TEKI_SBI;
        END IF;

        -- 適用開始年月取得
        IwNUSHI_TEKI_MM :=  SUBSTR(RZLBTNUSHI_TMP.NUSHI_TEKI_SBI,1,6);

        -- 3月よりカウントダウン
        FOR IwX IN REVERSE 1..12 LOOP

          -- 適用開始年月　＞　登録月　ループ終了
          IF IwNUSHI_TEKI_MM > VwYYYYMM(IwX) THEN
            EXIT;
          END IF;

          -- 既に登録済であれば、登録しない
          IF VwMM(IwX) IS NULL THEN
            -- 今回取得した世帯主設定
            VwMM(IwX) := RZLBTNUSHI_TMP.NUSHI_KOJIN_NO;
            MlNUSHI_BI(IwX) := RZLBTNUSHI_TMP.NUSHI_TEKI_SBI;
          END IF;
        END LOOP;
      END LOOP;

      -- 世帯主変更月は、適用開始日をセット。
      -- 以外は、各月の月末日をセットする。 → ただし、4月は 4/1（賦課期日）をセットする。
      FOR IwX IN 1..12 LOOP
        IF SUBSTR(MlNUSHI_BI(IwX),1,6) = VwYYYYMM(IwX) THEN
          -- 主適用日をセットする
          MlNUSHI_BI2(IwX) := MlNUSHI_BI(IwX);
        ELSE
          IF IwX = 1 THEN
            -- 4月は 4/1（賦課期日）をセットする
            MlNUSHI_BI2(IwX) := TO_NUMBER(VwYYYYMM(IwX) || '01');
          ELSE
            -- 月末日をセットする
            MlNUSHI_BI2(IwX) := TO_NUMBER(TO_CHAR(LAST_DAY(TO_DATE(VwYYYYMM(IwX) || '01', 'YYYYMMDD')), 'YYYYMMDD'));
          END IF;
        END IF;
      END LOOP;

      -- ②各月資格区分再セット ------------------------------------------------
      FOR IwX IN 0..12 LOOP
        -- 該当月の世帯主取得
        NwNUSHI_KOJIN_NO := VwMM(IwX);

        -- 該当月の世帯主が配列に未セットであれば次月処理へ
        IF NwNUSHI_KOJIN_NO IS NOT NULL THEN
          -- ②-1 該当月の世帯主以外の個人の再セット ---------------------------
          FOR RZLBTKOJIN_CAL IN CZLBTKOJIN_CAL LOOP
            -- 該当月の資格取得
            CASE IwX
              WHEN  0 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.F4_SHIK_KBN;
                VwSQL  := 'F4_SHIK_KBN = ';
              WHEN  1 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_4;
                VwSQL  := 'SHIK_4 = ';
              WHEN  2 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_5;
                VwSQL  := 'SHIK_5 = ';
              WHEN  3 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_6;
                VwSQL  := 'SHIK_6 = ';
              WHEN  4 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_7;
                VwSQL  := 'SHIK_7 = ';
              WHEN  5 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_8;
                VwSQL  := 'SHIK_8 = ';
              WHEN  6 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_9;
                VwSQL  := 'SHIK_9 = ';
              WHEN  7 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_10;
                VwSQL  := 'SHIK_10 = ';
              WHEN  8 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_11;
                VwSQL  := 'SHIK_11 = ';
              WHEN  9 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_12;
                VwSQL  := 'SHIK_12 = ';
              WHEN 10 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_1;
                VwSQL  := 'SHIK_1 = ';
              WHEN 11 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_2;
                VwSQL  := 'SHIK_2 = ';
              WHEN 12 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_3;
                VwSQL  := 'SHIK_3 = ';
            END CASE;
            -- 該当月の資格が世帯主関連であれば変更
            IF NwSHIK IN (c_NUSHI,c_GINUSHI,c_NUSHI_TAI) THEN
              CASE NwSHIK
                -- 世帯主⇒世帯員へ
                WHEN  c_NUSHI     THEN
                  VwSQL := VwSQL || c_SETAIIN;
                -- 擬主⇒資格なしへ
                WHEN  c_GINUSHI   THEN
                  VwSQL := VwSQL || c_NASHI;
                -- 世帯主(退職該当)⇒世帯員(退職該当)へ
                WHEN  c_NUSHI_TAI THEN
                  VwSQL := VwSQL || c_SETAIIN_TAI;
              END CASE;
              -- 資格区分更新
              VwSQL := 'UPDATE ZLBTKOJIN_CAL SET '          || VwSQL;
              VwSQL := VwSQL || ' WHERE KOJIN_NO = '        || RZLBTKOJIN_CAL.KOJIN_NO;
              VwSQL := VwSQL || ' AND SYS_TANMATSU_NO = ''' || i_VMASIN_NO || '''';
              BEGIN
                IwCUR := DBMS_SQL.OPEN_CURSOR;
                DBMS_SQL.PARSE(IwCUR, VwSQL, DBMS_SQL. NATIVE);
                IwPRC := DBMS_SQL.EXECUTE(IwCUR);
                DBMS_SQL.CLOSE_CURSOR(IwCUR);
              EXCEPTION
                WHEN OTHERS THEN
                  NlRTN := c_NERR;
                  IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                    BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSBKJDIV', 1, SQLCODE, SQLERRM, 'ZLBSBKJDIV subSikakuSaiSet 各月資格区分再セット資格更新' ||
                            '(国保世帯番号=' || i_NKOKU_SETAI_NO                ||
                            ' 宛名番号='     || RZLBTKOJIN_CAL.KOJIN_NO         ||
                            ')' || SQLERRM, '', i_VMASIN_NO);
                  ELSIF i_NTRENBAN = -1 THEN
                    -- テストの時のみ有効
                    DBMS_OUTPUT.PUT_LINE('ZLBSBKJDIV subSikakuSaiSet 各月資格区分再セット' ||
                                         '(国保世帯番号=' || i_NKOKU_SETAI_NO                ||
                                         ' 宛名番号='     || RZLBTKOJIN_CAL.KOJIN_NO         ||
                                         ')' || SQLERRM);
                  END IF;
              END;
            END IF;
            -- エラー発生時は処理終了
            IF NlRTN = c_NERR THEN
              EXIT;
            END IF;
          END LOOP;

          -- エラー発生時は処理終了
          IF NlRTN = c_NERR THEN
            EXIT;
          END IF;

          -- ②-2 該当月の世帯主の再セット -------------------------------------
          BEGIN
            SELECT * INTO RZLBTKOJIN_CAL FROM ZLBTKOJIN_CAL
             WHERE KOKU_SETAI_NO   =  i_NKOKU_SETAI_NO
               AND KOJIN_NO        =  NwNUSHI_KOJIN_NO
               AND SYS_TANMATSU_NO =  i_VMASIN_NO;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              NULL;  -- 該当でも抜けない。
            WHEN OTHERS THEN
              NlRTN := c_NERR;
              IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSBKJDIV', 1, SQLCODE, SQLERRM, 'ZLBSBKJDIV subSikakuSaiSet 各月資格区分再セット世帯主リセット' ||
                        '(国保世帯番号=' || i_NKOKU_SETAI_NO                ||
                        ' 宛名番号='     || NwNUSHI_KOJIN_NO        ||
                        ')' || SQLERRM, '', i_VMASIN_NO);
              ELSIF i_NTRENBAN = -1 THEN
                -- テストの時のみ有効
                DBMS_OUTPUT.PUT_LINE('ZLBSBKJDIV subSikakuSaiSet 各月資格区分再セット' ||
                                     '(国保世帯番号=' || i_NKOKU_SETAI_NO                ||
                                     ' 宛名番号='     || NwNUSHI_KOJIN_NO         ||
                                     ')' || SQLERRM);
              END IF;
          END;
          IF NlRTN = c_NOK THEN
            -- 該当月の資格取得
            CASE IwX
              WHEN  0 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.F4_SHIK_KBN;
                VwSQL  := 'F4_SHIK_KBN = ';
              WHEN  1 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_4;
                VwSQL  := 'SHIK_4 = ';
              WHEN  2 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_5;
                VwSQL  := 'SHIK_5 = ';
              WHEN  3 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_6;
                VwSQL  := 'SHIK_6 = ';
              WHEN  4 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_7;
                VwSQL  := 'SHIK_7 = ';
              WHEN  5 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_8;
                VwSQL  := 'SHIK_8 = ';
              WHEN  6 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_9;
                VwSQL  := 'SHIK_9 = ';
              WHEN  7 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_10;
                VwSQL  := 'SHIK_10 = ';
              WHEN  8 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_11;
                VwSQL  := 'SHIK_11 = ';
              WHEN  9 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_12;
                VwSQL  := 'SHIK_12 = ';
              WHEN 10 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_1;
                VwSQL  := 'SHIK_1 = ';
              WHEN 11 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_2;
                VwSQL  := 'SHIK_2 = ';
              WHEN 12 THEN
                NwSHIK :=  RZLBTKOJIN_CAL.SHIK_3;
                VwSQL  := 'SHIK_3 = ';
            END CASE;
            -- 該当月の資格が世帯員関連であれば変更
            IF NwSHIK IN (c_SETAIIN,c_SETAIIN_TAI) THEN
              CASE NwSHIK
                -- 世帯員⇒世帯主へ
                WHEN  c_SETAIIN     THEN
                  VwSQL := VwSQL || c_NUSHI;
                -- 世帯員(退職該当)⇒世帯主(退職該当)へ
                WHEN  c_SETAIIN_TAI THEN
                  VwSQL := VwSQL || c_NUSHI_TAI;
              END CASE;
              -- 資格区分更新
              VwSQL := 'UPDATE ZLBTKOJIN_CAL SET '          || VwSQL;
              VwSQL := VwSQL || ' WHERE KOJIN_NO = '        || RZLBTKOJIN_CAL.KOJIN_NO;
              VwSQL := VwSQL || ' AND SYS_TANMATSU_NO = ''' || i_VMASIN_NO || '''';
              BEGIN
                IwCUR := DBMS_SQL.OPEN_CURSOR;
                DBMS_SQL.PARSE(IwCUR, VwSQL, DBMS_SQL. NATIVE);
                IwPRC := DBMS_SQL.EXECUTE(IwCUR);
                DBMS_SQL.CLOSE_CURSOR(IwCUR);
              EXCEPTION
                WHEN OTHERS THEN
                  NlRTN := c_NERR;
                  IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                    BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSBKJDIV', 1, SQLCODE, SQLERRM, 'ZLBSBKJDIV subSikakuSaiSet 各月資格区分再セット資格更新２' ||
                            '(国保世帯番号=' || i_NKOKU_SETAI_NO                ||
                            ' 宛名番号='     || RZLBTKOJIN_CAL.KOJIN_NO         ||
                            ')' || SQLERRM, '', i_VMASIN_NO);
                  ELSIF i_NTRENBAN = -1 THEN
                    -- テストの時のみ有効
                    DBMS_OUTPUT.PUT_LINE('ZLBSBKJDIV subSikakuSaiSet 各月資格区分再セット' ||
                                         '(国保世帯番号=' || i_NKOKU_SETAI_NO                ||
                                         ' 宛名番号='     || RZLBTKOJIN_CAL.KOJIN_NO         ||
                                         ')' || SQLERRM);
                  END IF;
              END;
            END IF;
          END IF;
        END IF;
        -- エラー発生時は処理終了
        IF NlRTN = c_NERR THEN
          EXIT;
        END IF;
      END LOOP;

    END subSikakuSaiSet;

-------------------------------------------------------------------------------
-- 12 失業者区分取得
-------------------------------------------------------------------------------
    FUNCTION funcShitsuKbnGet(i_NIX IN NUMBER, i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) RETURN NUMBER IS
        NwSHIK          NUMBER(2);
    BEGIN
        NwSHIK  := 0;

        CASE i_NIX
            WHEN 1  THEN NwSHIK := i_RKOJIN.SHITSU_4;
            WHEN 2  THEN NwSHIK := i_RKOJIN.SHITSU_5;
            WHEN 3  THEN NwSHIK := i_RKOJIN.SHITSU_6;
            WHEN 4  THEN NwSHIK := i_RKOJIN.SHITSU_7;
            WHEN 5  THEN NwSHIK := i_RKOJIN.SHITSU_8;
            WHEN 6  THEN NwSHIK := i_RKOJIN.SHITSU_9;
            WHEN 7  THEN NwSHIK := i_RKOJIN.SHITSU_10;
            WHEN 8  THEN NwSHIK := i_RKOJIN.SHITSU_11;
            WHEN 9  THEN NwSHIK := i_RKOJIN.SHITSU_12;
            WHEN 10 THEN NwSHIK := i_RKOJIN.SHITSU_1;
            WHEN 11 THEN NwSHIK := i_RKOJIN.SHITSU_2;
            WHEN 12 THEN NwSHIK := i_RKOJIN.SHITSU_3;
            ELSE NULL;
        END CASE;

        RETURN(NwSHIK);

    END funcShitsuKbnGet;

-------------------------------------------------------------------------------
-- 11 介護資格区分取得
-------------------------------------------------------------------------------
    FUNCTION funcKaiShikKbnGet(i_NIX IN NUMBER, i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) RETURN NUMBER IS
        NwSHIK          NUMBER(2);
    BEGIN
        NwSHIK  := 0;

        CASE i_NIX
            WHEN 1  THEN NwSHIK := i_RKOJIN.KAI_SHIK_4;
            WHEN 2  THEN NwSHIK := i_RKOJIN.KAI_SHIK_5;
            WHEN 3  THEN NwSHIK := i_RKOJIN.KAI_SHIK_6;
            WHEN 4  THEN NwSHIK := i_RKOJIN.KAI_SHIK_7;
            WHEN 5  THEN NwSHIK := i_RKOJIN.KAI_SHIK_8;
            WHEN 6  THEN NwSHIK := i_RKOJIN.KAI_SHIK_9;
            WHEN 7  THEN NwSHIK := i_RKOJIN.KAI_SHIK_10;
            WHEN 8  THEN NwSHIK := i_RKOJIN.KAI_SHIK_11;
            WHEN 9  THEN NwSHIK := i_RKOJIN.KAI_SHIK_12;
            WHEN 10 THEN NwSHIK := i_RKOJIN.KAI_SHIK_1;
            WHEN 11 THEN NwSHIK := i_RKOJIN.KAI_SHIK_2;
            WHEN 12 THEN NwSHIK := i_RKOJIN.KAI_SHIK_3;
            ELSE NULL;
        END CASE;

        RETURN(NwSHIK);

    END funcKaiShikKbnGet;
-------------------------------------------------------------------------------
-- 10 資格区分取得
-------------------------------------------------------------------------------
    FUNCTION funcShikKbnGet(i_NIX IN NUMBER, i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) RETURN NUMBER IS
        NwSHIK          NUMBER(2);
    BEGIN
        NwSHIK  := 0;

        CASE i_NIX
            WHEN 1  THEN NwSHIK := i_RKOJIN.SHIK_4;
            WHEN 2  THEN NwSHIK := i_RKOJIN.SHIK_5;
            WHEN 3  THEN NwSHIK := i_RKOJIN.SHIK_6;
            WHEN 4  THEN NwSHIK := i_RKOJIN.SHIK_7;
            WHEN 5  THEN NwSHIK := i_RKOJIN.SHIK_8;
            WHEN 6  THEN NwSHIK := i_RKOJIN.SHIK_9;
            WHEN 7  THEN NwSHIK := i_RKOJIN.SHIK_10;
            WHEN 8  THEN NwSHIK := i_RKOJIN.SHIK_11;
            WHEN 9  THEN NwSHIK := i_RKOJIN.SHIK_12;
            WHEN 10 THEN NwSHIK := i_RKOJIN.SHIK_1;
            WHEN 11 THEN NwSHIK := i_RKOJIN.SHIK_2;
            WHEN 12 THEN NwSHIK := i_RKOJIN.SHIK_3;
            ELSE NULL;
        END CASE;

        RETURN(NwSHIK);

    END funcShikKbnGet;
-------------------------------------------------------------------------------
-- 09 該当月データセット
-------------------------------------------------------------------------------
    PROCEDURE subKojinSet(i_NIX1 IN NUMBER,
                          i_NIX2 IN NUMBER,
                          i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) IS
    BEGIN

        IF MlSANTEI(i_NIX1) = MlKOJIN(i_NIX2).SANTEIDANTAI_CD AND
           MlNUSHI(i_NIX1)  = MlKOJIN(i_NIX2).TSUCHI_NO THEN

            CASE i_NIX1
                WHEN 1  THEN
                    MlKOJIN(i_NIX2).SHIK_4      := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_4  := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_4       := 1;
                    MlKOJIN(i_NIX2).SHITSU_4    := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_4       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 2  THEN
                    MlKOJIN(i_NIX2).SHIK_5      := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_5  := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_5       := 1;
                    MlKOJIN(i_NIX2).SHITSU_5    := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_5       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 3  THEN
                    MlKOJIN(i_NIX2).SHIK_6      := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_6  := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_6       := 1;
                    MlKOJIN(i_NIX2).SHITSU_6    := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_6       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 4  THEN
                    MlKOJIN(i_NIX2).SHIK_7      := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_7  := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_7       := 1;
                    MlKOJIN(i_NIX2).SHITSU_7    := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_7       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 5  THEN
                    MlKOJIN(i_NIX2).SHIK_8      := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_8  := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_8       := 1;
                    MlKOJIN(i_NIX2).SHITSU_8    := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_8       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 6  THEN
                    MlKOJIN(i_NIX2).SHIK_9      := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_9  := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_9       := 1;
                    MlKOJIN(i_NIX2).SHITSU_9    := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_9       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 7  THEN
                    MlKOJIN(i_NIX2).SHIK_10     := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_10 := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_10      := 1;
                    MlKOJIN(i_NIX2).SHITSU_10   := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_10       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 8  THEN
                    MlKOJIN(i_NIX2).SHIK_11     := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_11 := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_11      := 1;
                    MlKOJIN(i_NIX2).SHITSU_11   := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_11       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 9  THEN
                    MlKOJIN(i_NIX2).SHIK_12     := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_12 := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_12      := 1;
                    MlKOJIN(i_NIX2).SHITSU_12   := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_12       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 10 THEN
                    MlKOJIN(i_NIX2).SHIK_1      := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_1  := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_1       := 1;
                    MlKOJIN(i_NIX2).SHITSU_1    := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_1       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 11 THEN
                    MlKOJIN(i_NIX2).SHIK_2      := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_2  := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_2       := 1;
                    MlKOJIN(i_NIX2).SHITSU_2    := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_2       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                WHEN 12 THEN
                    MlKOJIN(i_NIX2).SHIK_3      := funcShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).KAI_SHIK_3  := funcKaiShikKbnGet(i_NIX1, i_RKOJIN);
                    MlKOJIN(i_NIX2).DIV_3       := 1;
                    MlKOJIN(i_NIX2).SHITSU_3    := funcShitsuKbnGet(i_NIX1, i_RKOJIN);
-- 2024/05/07 ZCZL.GUANHONG Add 0.3.000.100: 国保2次にマージ作業
                    MlKOJIN(i_NIX2).SAN_3       := funcSanKbnGet(i_NIX1, i_RKOJIN);
                ELSE NULL;
            END CASE;

            MlKOJIN(i_NIX2).SEISAN_KBN  := MlSEISAN(i_NIX1);    -- 清算フラグ

            -- 最新
            IF MlNEWKBN(i_NIX1) = 1 THEN
                MlKOJIN(i_NIX2).NEW_SHIK_KBN        := i_RKOJIN.NEW_SHIK_KBN;
                MlKOJIN(i_NIX2).NEW_KAI_SHIK_KBN    := i_RKOJIN.NEW_KAI_SHIK_KBN;
                MlKOJIN(i_NIX2).NEW_TAI_KBN         := i_RKOJIN.NEW_TAI_KBN;
            END IF;

            -- 賦課
            IF MlF4KBN(i_NIX1) = 1 THEN
                MlKOJIN(i_NIX2).F4_SHIK_KBN         := i_RKOJIN.F4_SHIK_KBN;
                MlKOJIN(i_NIX2).F4_KAI_KBN          := i_RKOJIN.F4_KAI_KBN;
                MlKOJIN(i_NIX2).F4_TAI_KBN          := i_RKOJIN.F4_TAI_KBN;
            END IF;

            -- 賦課発生
            IF MlFUKAKBN(i_NIX1) = 1 THEN
                MlKOJIN(i_NIX2).FUKA_SHIK_KBN       := i_RKOJIN.FUKA_SHIK_KBN;
                MlKOJIN(i_NIX2).FUKA_KAI_KBN        := i_RKOJIN.FUKA_KAI_KBN;
            END IF;

            -- 最新失業者資格区分
            IF MlNEWKBN(i_NIX1) = 1 THEN
                MlKOJIN(i_NIX2).NEW_SHITSU_KBN      := i_RKOJIN.NEW_SHITSU_KBN;
            END IF;

            -- 賦課期日失業者資格区分
            IF MlF4KBN(i_NIX1) = 1 THEN
                MlKOJIN(i_NIX2).F4_SHITSU_KBN       := i_RKOJIN.F4_SHITSU_KBN;
            END IF;
-- 2024/05/07 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
            --最新産前産後資格区分
            IF MlNEWSANKBN(i_NIX1) = 1 THEN
              MlKOJIN(i_NIX2).NEW_SAN_KBN           := i_RKOJIN.NEW_SAN_KBN;
            END IF;
            --賦課期日産前産後資格区分
            IF MlF4SANKBN(i_NIX1) = 1 THEN
              MlKOJIN(i_NIX2).F4_SAN_KBN            := i_RKOJIN.F4_SAN_KBN;
            END IF;
-- 2024/05/07　ZCZL.GUANHONG　Add　End

        ELSE

            -- 最新
            IF MlNEWKBN(i_NIX1) = 1 THEN

                IF i_RKOJIN.NEW_SHIK_KBN IN (1, 2, 3) THEN
                    MlKOJIN(i_NIX2).NEW_SHIK_KBN := i_RKOJIN.NEW_SHIK_KBN + 6;
                ELSE
                    MlKOJIN(i_NIX2).NEW_SHIK_KBN := i_RKOJIN.NEW_SHIK_KBN;
                END IF;
                MlKOJIN(i_NIX2).NEW_KAI_SHIK_KBN    := i_RKOJIN.NEW_KAI_SHIK_KBN;
                MlKOJIN(i_NIX2).NEW_TAI_KBN         := i_RKOJIN.NEW_TAI_KBN;
            END IF;

            -- 賦課
            IF MlF4KBN(i_NIX1) = 1 THEN
                MlKOJIN(i_NIX2).F4_SHIK_KBN         := i_RKOJIN.F4_SHIK_KBN;
                MlKOJIN(i_NIX2).F4_KAI_KBN          := i_RKOJIN.F4_KAI_KBN;
                MlKOJIN(i_NIX2).F4_TAI_KBN          := i_RKOJIN.F4_TAI_KBN;
            END IF;

            -- 賦課発生
            IF MlFUKAKBN(i_NIX1) = 1 THEN
                MlKOJIN(i_NIX2).FUKA_SHIK_KBN       := i_RKOJIN.FUKA_SHIK_KBN;
                MlKOJIN(i_NIX2).FUKA_KAI_KBN        := i_RKOJIN.FUKA_KAI_KBN;
            END IF;

            -- 最新失業者資格区分
            IF MlNEWKBN(i_NIX1) = 1 THEN
                MlKOJIN(i_NIX2).NEW_SHITSU_KBN      := i_RKOJIN.NEW_SHITSU_KBN;
            END IF;

            -- 賦課期日失業者資格区分
            IF MlF4KBN(i_NIX1) = 1 THEN
                MlKOJIN(i_NIX2).F4_SHITSU_KBN       := i_RKOJIN.F4_SHITSU_KBN;
            END IF;
-- 2024/05/07 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
            --最新産前産後資格区分
            IF MlNEWSANKBN(i_NIX1) = 1 THEN
              MlKOJIN(i_NIX2).NEW_SAN_KBN           := i_RKOJIN.NEW_SAN_KBN;
            END IF;
            --賦課期日産前産後資格区分
            IF MlF4SANKBN(i_NIX1) = 1 THEN
              MlKOJIN(i_NIX2).F4_SAN_KBN            := i_RKOJIN.F4_SAN_KBN;
            END IF;
-- 2024/05/07　ZCZL.GUANHONG　Add　End

        END IF;

    END subKojinSet;
-------------------------------------------------------------------------------
-- 08 個人基本データセット
-------------------------------------------------------------------------------
    PROCEDURE subKojinKihonSet(i_NIX IN NUMBER, i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) IS
    BEGIN

        MlKOJIN(i_NIX) := i_RKOJIN;

        MlKOJIN(i_NIX).SANTEIDANTAI_CD  := 0;
        MlKOJIN(i_NIX).TSUCHI_NO        := 0;
        MlKOJIN(i_NIX).NEW_SHIK_KBN     := 0;
        MlKOJIN(i_NIX).NEW_KAI_SHIK_KBN := 0;
        MlKOJIN(i_NIX).NEW_TAI_KBN      := 0;
        MlKOJIN(i_NIX).F4_SHIK_KBN      := 0;
        MlKOJIN(i_NIX).F4_KAI_KBN       := 0;
        MlKOJIN(i_NIX).F4_TAI_KBN       := 0;
        MlKOJIN(i_NIX).FUKA_SHIK_KBN    := 0;
        MlKOJIN(i_NIX).FUKA_KAI_KBN     := 0;
        MlKOJIN(i_NIX).SHIK_4           := 0;
        MlKOJIN(i_NIX).SHIK_5           := 0;
        MlKOJIN(i_NIX).SHIK_6           := 0;
        MlKOJIN(i_NIX).SHIK_7           := 0;
        MlKOJIN(i_NIX).SHIK_8           := 0;
        MlKOJIN(i_NIX).SHIK_9           := 0;
        MlKOJIN(i_NIX).SHIK_10          := 0;
        MlKOJIN(i_NIX).SHIK_11          := 0;
        MlKOJIN(i_NIX).SHIK_12          := 0;
        MlKOJIN(i_NIX).SHIK_1           := 0;
        MlKOJIN(i_NIX).SHIK_2           := 0;
        MlKOJIN(i_NIX).SHIK_3           := 0;
        MlKOJIN(i_NIX).KAI_SHIK_4       := 0;
        MlKOJIN(i_NIX).KAI_SHIK_5       := 0;
        MlKOJIN(i_NIX).KAI_SHIK_6       := 0;
        MlKOJIN(i_NIX).KAI_SHIK_7       := 0;
        MlKOJIN(i_NIX).KAI_SHIK_8       := 0;
        MlKOJIN(i_NIX).KAI_SHIK_9       := 0;
        MlKOJIN(i_NIX).KAI_SHIK_10      := 0;
        MlKOJIN(i_NIX).KAI_SHIK_11      := 0;
        MlKOJIN(i_NIX).KAI_SHIK_12      := 0;
        MlKOJIN(i_NIX).KAI_SHIK_1       := 0;
        MlKOJIN(i_NIX).KAI_SHIK_2       := 0;
        MlKOJIN(i_NIX).KAI_SHIK_3       := 0;
        MlKOJIN(i_NIX).SEISAN_KBN       := 0;
        MlKOJIN(i_NIX).DIV_4            := 0;
        MlKOJIN(i_NIX).DIV_5            := 0;
        MlKOJIN(i_NIX).DIV_6            := 0;
        MlKOJIN(i_NIX).DIV_7            := 0;
        MlKOJIN(i_NIX).DIV_8            := 0;
        MlKOJIN(i_NIX).DIV_9            := 0;
        MlKOJIN(i_NIX).DIV_10           := 0;
        MlKOJIN(i_NIX).DIV_11           := 0;
        MlKOJIN(i_NIX).DIV_12           := 0;
        MlKOJIN(i_NIX).DIV_1            := 0;
        MlKOJIN(i_NIX).DIV_2            := 0;
        MlKOJIN(i_NIX).DIV_3            := 0;
        MlKOJIN(i_NIX).NEW_SHITSU_KBN   := 0;
        MlKOJIN(i_NIX).F4_SHITSU_KBN    := 0;
        MlKOJIN(i_NIX).SHITSU_4         := 0;
        MlKOJIN(i_NIX).SHITSU_5         := 0;
        MlKOJIN(i_NIX).SHITSU_6         := 0;
        MlKOJIN(i_NIX).SHITSU_7         := 0;
        MlKOJIN(i_NIX).SHITSU_8         := 0;
        MlKOJIN(i_NIX).SHITSU_9         := 0;
        MlKOJIN(i_NIX).SHITSU_10        := 0;
        MlKOJIN(i_NIX).SHITSU_11        := 0;
        MlKOJIN(i_NIX).SHITSU_12        := 0;
        MlKOJIN(i_NIX).SHITSU_1         := 0;
        MlKOJIN(i_NIX).SHITSU_2         := 0;
        MlKOJIN(i_NIX).SHITSU_3         := 0;
-- 2024/05/07 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
        MlKOJIN(i_NIX).NEW_SAN_KBN             := 0;
        MlKOJIN(i_NIX).F4_SAN_KBN              := 0;
        MlKOJIN(i_NIX).SAN_4                   := 0;
        MlKOJIN(i_NIX).SAN_5                   := 0;
        MlKOJIN(i_NIX).SAN_6                   := 0;
        MlKOJIN(i_NIX).SAN_7                   := 0;
        MlKOJIN(i_NIX).SAN_8                   := 0;
        MlKOJIN(i_NIX).SAN_9                   := 0;
        MlKOJIN(i_NIX).SAN_10                  := 0;
        MlKOJIN(i_NIX).SAN_11                  := 0;
        MlKOJIN(i_NIX).SAN_12                  := 0;
        MlKOJIN(i_NIX).SAN_1                   := 0;
        MlKOJIN(i_NIX).SAN_2                   := 0;
        MlKOJIN(i_NIX).SAN_3                   := 0;
        MlKOJIN(i_NIX).SAN_IRYO_GEN_KINTO      := 0;
        MlKOJIN(i_NIX).SAN_IRYO_GEN_SHOTOKU    := 0;
        MlKOJIN(i_NIX).SAN_KAI_GEN_KINTO       := 0;
        MlKOJIN(i_NIX).SAN_KAI_GEN_SHOTOKU     := 0;
        MlKOJIN(i_NIX).SAN_SIEN_GEN_KINTO      := 0;
        MlKOJIN(i_NIX).SAN_SIEN_GEN_SHOTOKU    := 0;
--2025/08/11 ZCZL.LIUCHENYU ADD START 1.1.200.000:子ども子育て支援金対応
        MlKOJIN(i_NIX).KDM_SAN_GEN_KINTO       := 0;
        MlKOJIN(i_NIX).KDM_SAN_GEN_SHOTOKU     := 0;
        MlKOJIN(i_NIX).KDM_SAN_GEN_KINTO18     := 0;
--2025/08/11 ZCZL.LIUCHENYU ADD END

-- 2024/05/07　ZCZL.GUANHONG　Add　End
    END subKojinKihonSet;
-------------------------------------------------------------------------------
-- 07 計算個人Delete
-------------------------------------------------------------------------------
    PROCEDURE subDelete IS
      -- 世帯主取得
      CURSOR C_NUSHI is
        SELECT KOKU_SETAI_NO,
               SANTEIDANTAI_CD,
               CHOTEI_NENDO,
               NENDO_BUN,
               TSUCHI_NO,          -- 主個人番号
               SYS_TANMATSU_NO
          FROM ZLBTKOJIN_CAL
         WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
           AND SYS_TANMATSU_NO = i_VMASIN_NO
         GROUP BY KOKU_SETAI_NO,SANTEIDANTAI_CD,CHOTEI_NENDO,NENDO_BUN,TSUCHI_NO,SYS_TANMATSU_NO;

      R_NUSHI C_NUSHI%ROWTYPE;

      -- 計算個人取得(世帯主を除く)
      CURSOR C_KOJIN(p_KOKU_SETAI_NO   NUMBER,
                     p_SANTEIDANTAI_CD NUMBER,
                     p_CHOTEI_NENDO    NUMBER,
                     p_NENDO_BUN       NUMBER,
                     p_TSUCHI_NO       NUMBER,
                     p_SYS_TANMATSU_NO VARCHAR2) is
        SELECT *
          FROM ZLBTKOJIN_CAL
         WHERE KOKU_SETAI_NO   = p_KOKU_SETAI_NO
           AND SANTEIDANTAI_CD = p_SANTEIDANTAI_CD
           AND CHOTEI_NENDO    = p_CHOTEI_NENDO
           AND NENDO_BUN       = p_NENDO_BUN
           AND TSUCHI_NO       = p_TSUCHI_NO
           AND KOJIN_NO       <> p_TSUCHI_NO
           AND SYS_TANMATSU_NO = p_SYS_TANMATSU_NO;

      TYPE MTNUMARRAY3  IS TABLE OF NUMBER(3)  INDEX BY BINARY_INTEGER;

      R_KOJIN           C_KOJIN%ROWTYPE;
      MlwTSUKIUMU       MTNUMARRAY3;     --各月有資格人数
      NwCHKIDX          NUMBER := 0;     --全喪月(配列idx)
      NwDate            NUMBER := 0;
    BEGIN
        BEGIN
            DELETE FROM ZLBTKOJIN_CAL
             WHERE SANTEIDANTAI_CD = 0
               AND TSUCHI_NO       = 0
               AND SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                    BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSBKJDIV', 1, SQLCODE, SQLERRM,
                            'ZLBSBKJDIV subDelete 計算個人削除'
                            ||'(国保世帯番号=' || i_NKOKU_SETAI_NO ||')' || SQLERRM, '', i_VMASIN_NO);
                ELSIF i_NTRENBAN = -1 THEN
                    -- テストの時のみ有効
                    DBMS_OUTPUT.PUT_LINE('ZLBSBKJDIV subDelete 計算個人削除' ||
                                         '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                         ')' || SQLERRM);
                END IF;
        END;

--新規資格取得者を主設定した場合、分割後のレコードが以下となる。
--  ・無条件に上記資格取得者のレコードが旧主のPKで作成される。
--  ・分割作成されたレコードの最新資格区分と賦課発生時資格区分
--    が不正値となっている。
--     最新資格区分=>旧主の賦課全喪月は資格未取得なのに「7」がセットされる。
--     ==>年度内で該当賦課データは全喪していないか?
--        ==>全喪していた場合、全喪月の1日<=資格取得月であれば「0」クリア
--        ※未来日取得(基準日=6/30、取得日=07/01etc)があるので基準日時点の全喪チェックにはしない。
        BEGIN
          -- 賦課PK値取得
          FOR R_NUSHI IN C_NUSHI LOOP
            --①各月の有資格人数取得
            SELECT (SUM(CASE WHEN SHIK_4  IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_5  IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_6  IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_7  IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_8  IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_9  IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_10 IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_11 IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_12 IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_1  IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_2  IN (1,3,11,13) THEN 1 ELSE 0 END)),
                   (SUM(CASE WHEN SHIK_3  IN (1,3,11,13) THEN 1 ELSE 0 END))
              INTO MlwTSUKIUMU(1) ,MlwTSUKIUMU(2) ,MlwTSUKIUMU(3) ,MlwTSUKIUMU(4) ,MlwTSUKIUMU(5) ,MlwTSUKIUMU(6) ,
                   MlwTSUKIUMU(7) ,MlwTSUKIUMU(8) ,MlwTSUKIUMU(9) ,MlwTSUKIUMU(10),MlwTSUKIUMU(11),MlwTSUKIUMU(12)
              FROM ZLBTKOJIN_CAL
             WHERE KOKU_SETAI_NO   = R_NUSHI.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = R_NUSHI.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = R_NUSHI.CHOTEI_NENDO
               AND NENDO_BUN       = R_NUSHI.NENDO_BUN
               AND TSUCHI_NO       = R_NUSHI.TSUCHI_NO
               AND SYS_TANMATSU_NO = R_NUSHI.SYS_TANMATSU_NO;
            --同月得喪世帯に係る賦課根拠の表示について、現在の世帯主のみ表示ではなく、世帯員も表示するよう変更する。(QA #9154対応)
            --そのため、不要レコード削除の条件を「主単位で集計した各月の資格がひとつきでもある場合」とする。
            IF MlwTSUKIUMU(1)  = 0 AND
               MlwTSUKIUMU(2)  = 0 AND
               MlwTSUKIUMU(3)  = 0 AND
               MlwTSUKIUMU(4)  = 0 AND
               MlwTSUKIUMU(5)  = 0 AND
               MlwTSUKIUMU(6)  = 0 AND
               MlwTSUKIUMU(7)  = 0 AND
               MlwTSUKIUMU(8)  = 0 AND
               MlwTSUKIUMU(9)  = 0 AND
               MlwTSUKIUMU(10) = 0 AND
               MlwTSUKIUMU(11) = 0 AND
               MlwTSUKIUMU(12) = 0 THEN
               NULL;
            ELSE
              --3月時点で全喪世帯
              IF MlwTSUKIUMU(12) = 0 THEN
                --②全喪月取得
                NwCHKIDX := 0;
                FOR IDX IN REVERSE 1..11 LOOP
                  IF MlwTSUKIUMU(IDX) > 0 THEN
                    NwCHKIDX := IDX + 1;
                    EXIT;
                  END IF;
                END LOOP;

                IF NwCHKIDX = 0 THEN
                  NwCHKIDX := 1;
                END IF;

                --③全喪月の1日を取得
                NwDate := KKAPK0020.FDATECAL(i_NFUKA_KIJITU, 0, 0, NwCHKIDX-1, 0);
                --計算個人取得
                FOR R_KOJIN IN C_KOJIN(R_NUSHI.KOKU_SETAI_NO,
                                       R_NUSHI.SANTEIDANTAI_CD,
                                       R_NUSHI.CHOTEI_NENDO,
                                       R_NUSHI.NENDO_BUN,
                                       R_NUSHI.TSUCHI_NO,
                                       R_NUSHI.SYS_TANMATSU_NO) LOOP
                  --④不要レコード削除(資格なしレコード)
                  IF NwDate <= R_KOJIN.NEW_SHUTOK_BI AND R_KOJIN.NEW_SHIK_KBN IN (7,8,9) THEN
                    DELETE FROM ZLBTKOJIN_CAL
                     WHERE KOKU_SETAI_NO   = R_KOJIN.KOKU_SETAI_NO
                       AND KOJIN_NO        = R_KOJIN.KOJIN_NO
                       AND SANTEIDANTAI_CD = R_KOJIN.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = R_KOJIN.CHOTEI_NENDO
                       AND NENDO_BUN       = R_KOJIN.NENDO_BUN
                       AND TSUCHI_NO       = R_KOJIN.TSUCHI_NO
                       AND F4_SHIK_KBN     = 0
                       AND SHIK_4          = 0
                       AND SHIK_5          = 0
                       AND SHIK_6          = 0
                       AND SHIK_7          = 0
                       AND SHIK_8          = 0
                       AND SHIK_9          = 0
                       AND SHIK_10         = 0
                       AND SHIK_11         = 0
                       AND SHIK_12         = 0
                       AND SHIK_1          = 0
                       AND SHIK_2          = 0
                       AND SHIK_3          = 0
                       AND SYS_TANMATSU_NO = R_KOJIN.SYS_TANMATSU_NO;
                  END IF;
                END LOOP;  --計算個人Loop
              END IF;
            --同月得喪世帯に係る賦課根拠の表示について、現在の世帯主のみ表示ではなく、世帯員も表示するよう変更する。(QA #9154対応)
            --そのため、不要レコード削除の条件を「主単位で集計した各月の資格がひとつきでもある場合」とする。
            END IF;
          END LOOP;      --賦課PK値Loop
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                    BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSBKJDIV',1, SQLCODE, SQLERRM,'ZLBSBKJDIV subDelete 計算個人削除-2' ||'(国保世帯番号=' || i_NKOKU_SETAI_NO ||')' || SQLERRM, '', i_VMASIN_NO);
                ELSIF i_NTRENBAN = -1 THEN
                    -- テストの時のみ有効
                    DBMS_OUTPUT.PUT_LINE('ZLBSBKJDIV subDelete 計算個人削除-2' ||
                                         '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                         ')' || SQLERRM);
                END IF;
        END;
    END subDelete;

-------------------------------------------------------------------------------
-- 07 計算個人Delete2
-------------------------------------------------------------------------------
    PROCEDURE subDelete2 IS

        TYPE ty_ZLBTSHIKAKU_TMP_ary   IS TABLE OF ZLBTSHIKAKU_TMP%ROWTYPE INDEX BY BINARY_INTEGER;
        rec_ZLBTSHIKAKU_TMP_ary           ty_ZLBTSHIKAKU_TMP_ary;

        nCNT                              number;
        nSHIKAKU                          number;

    BEGIN

        /*----------------------------------------------------------------
          １世帯分の資格データを配列(rec_ZLBTSHIKAKU_TMP_ary)に取得する
        ----------------------------------------------------------------*/
        nCNT := 0;
        rec_ZLBTSHIKAKU_TMP_ary.DELETE;

        FOR vRec IN (
            SELECT * FROM ZLBTSHIKAKU_TMP
            WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
              AND SAKUJO_KBN      = 0
              AND Z_SHUTOKU_BI   <> Z_SOSHITSU_BI    -- 同日得喪は抽出しない(ZLBTSHIKAKU_TMPにはないと思うけど。)
              AND SYS_TANMATSU_NO = i_VMASIN_NO
        ) LOOP

            nCNT := nCNT + 1;
            rec_ZLBTSHIKAKU_TMP_ary(nCNT) := vRec;

            -- 現存者は、喪失日にALL9をセットする
            IF rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI = 0 THEN
                rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI := 99999999;
            END IF;

        END LOOP;

        /*----------------------------------------------------------------
          ZLBTKOJIN_CAL 世帯主(TSUCHI_NO)取得する
        ----------------------------------------------------------------*/
        FOR vRec IN (
            SELECT KOKU_SETAI_NO, TSUCHI_NO, SYS_TANMATSU_NO FROM ZLBTKOJIN_CAL
            WHERE KOKU_SETAI_NO   =  i_NKOKU_SETAI_NO
              AND SYS_TANMATSU_NO =  i_VMASIN_NO
            GROUP BY KOKU_SETAI_NO, TSUCHI_NO, SYS_TANMATSU_NO
        ) LOOP

            nSHIKAKU := 0;

            /*----------------------------------------------------------------
              ZLBTKOJIN_CAL 該当世帯主(TSUCHI_NO)に属する人を取得する
            ----------------------------------------------------------------*/
            FOR vRec2 IN (
                SELECT * FROM ZLBTKOJIN_CAL
                WHERE KOKU_SETAI_NO   =  vRec.KOKU_SETAI_NO
                  AND TSUCHI_NO       =  vRec.TSUCHI_NO          -- 世帯主単位で取得する
                  AND SYS_TANMATSU_NO =  vRec.SYS_TANMATSU_NO
            ) LOOP

                --------------------------------------------------
                -- 資格有無チェック１
                --   資格有無を資格区分で判定する
                --------------------------------------------------
                IF vRec2.DIV_4  = 1 AND vRec2.SHIK_4  <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_5  = 1 AND vRec2.SHIK_5  <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_6  = 1 AND vRec2.SHIK_6  <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_7  = 1 AND vRec2.SHIK_7  <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_8  = 1 AND vRec2.SHIK_8  <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_9  = 1 AND vRec2.SHIK_9  <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_10 = 1 AND vRec2.SHIK_10 <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_11 = 1 AND vRec2.SHIK_11 <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_12 = 1 AND vRec2.SHIK_12 <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_1  = 1 AND vRec2.SHIK_1  <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_2  = 1 AND vRec2.SHIK_2  <> 0 THEN nSHIKAKU := 1; END IF;
                IF vRec2.DIV_3  = 1 AND vRec2.SHIK_3  <> 0 THEN nSHIKAKU := 1; END IF;

                -- １人でも資格があれば、LOOP終了
                IF nSHIKAKU = 1 THEN EXIT; END IF;

                --------------------------------------------------
                -- 資格有無チェック２
                --   資格有無を取得日・喪失日で判定する
                --   判定の基準日は、MlNUSHI_BI2(n) 時点とする
                --------------------------------------------------
                --     MlNUSHI_BI2() には、賦課期日(主適用日) または 月末日がセットされている
                --     月末日に資格があれば"資格あり"(SHIK_4=1 ～ SHIK_3=1)のはずなので、ここで判定しなくていいけど、
                --     ロジックを簡単にしたいので、賦課期日と一緒に判定している。
                --------------------------------------------------
                FOR nCNT IN 1..rec_ZLBTSHIKAKU_TMP_ary.COUNT LOOP

                    -- 資格レコードの件数だけチェックする
                    IF vRec2.KOJIN_NO = rec_ZLBTSHIKAKU_TMP_ary(nCNT).KOJIN_NO THEN
                        IF vRec2.DIV_4  = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(1)  AND MlNUSHI_BI2(1)  < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_5  = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(2)  AND MlNUSHI_BI2(2)  < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_6  = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(3)  AND MlNUSHI_BI2(3)  < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_7  = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(4)  AND MlNUSHI_BI2(4)  < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_8  = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(5)  AND MlNUSHI_BI2(5)  < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_9  = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(6)  AND MlNUSHI_BI2(6)  < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_10 = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(7)  AND MlNUSHI_BI2(7)  < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_11 = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(8)  AND MlNUSHI_BI2(8)  < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_12 = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(9)  AND MlNUSHI_BI2(9)  < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_1  = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(10) AND MlNUSHI_BI2(10) < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_2  = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(11) AND MlNUSHI_BI2(11) < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                        IF vRec2.DIV_3  = 1 AND rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SHUTOKU_BI <= MlNUSHI_BI2(12) AND MlNUSHI_BI2(12) < rec_ZLBTSHIKAKU_TMP_ary(nCNT).Z_SOSHITSU_BI THEN nSHIKAKU := 1; END IF;
                    END IF;

                    -- １人でも資格があれば、LOOP終了
                    IF nSHIKAKU = 1 THEN EXIT; END IF;

                END LOOP;    -- rec_ZLBTSHIKAKU_TMP_ary

                -- １人でも資格があれば、LOOP終了
                IF nSHIKAKU = 1 THEN EXIT; END IF;

            END LOOP;    -- vRec2

            -- １人も資格がないとき、世帯主単位で削除する
            IF nSHIKAKU = 0 THEN
                BEGIN
                    DELETE FROM ZLBTKOJIN_CAL
                    WHERE KOKU_SETAI_NO   = vRec.KOKU_SETAI_NO
                      AND TSUCHI_NO       = vRec.TSUCHI_NO
                      AND SYS_TANMATSU_NO = vRec.SYS_TANMATSU_NO;
                EXCEPTION
                    WHEN OTHERS THEN NULL;
                END;
            END IF;

        END LOOP;    -- vRec

    END subDelete2;

-------------------------------------------------------------------------------
-- 06 計算個人Insert
-------------------------------------------------------------------------------
    PROCEDURE subInsert IS
        NwIX1           NUMBER;
    BEGIN

        IF NlCNT = 0 THEN
            RETURN;
        END IF;

        FOR NwIX1 IN 1..NlCNT LOOP

            BEGIN
                INSERT INTO ZLBTKOJIN_CAL VALUES MlKOJIN(NwIX1);
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                        BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSBKJDIV', 1, SQLCODE, SQLERRM,'ZLBSBKJDIV subInsert 計算個人登録' ||'(国保世帯番号=' || i_NKOKU_SETAI_NO ||')' || SQLERRM, '', i_VMASIN_NO);
                    ELSIF i_NTRENBAN = -1 THEN
                        -- テストの時のみ有効
                        DBMS_OUTPUT.PUT_LINE('ZLBSBKJDIV subInsert 計算個人登録' ||
                                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                             ')' || SQLERRM);
                END IF;
                    EXIT;
            END;

        END LOOP;

    END subInsert;
-------------------------------------------------------------------------------
-- 05 計算個人分割
-------------------------------------------------------------------------------
    PROCEDURE subKojinDiv(i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) IS

        NwIX1           NUMBER(2);      -- 該当月用
        NwIX2           NUMBER;         -- 分割レコード用
        NwSET_SW        NUMBER(1);
        ICNT            PLS_INTEGER;

    BEGIN

        -- 1レコード目のデータセット
        NlCNT := 1;

        subKojinKihonSet(1, i_RKOJIN);      -- 08 個人基本情報セット
        MlKOJIN(1).SANTEIDANTAI_CD  := MlSANTEI(1);
        MlKOJIN(1).TSUCHI_NO        := MlNUSHI(1);

        FOR NwIX1 IN 1..12 LOOP                 -- ４月から３月まで

            NwSET_SW := 0;      -- 新規か既存かを判断

            FOR NwIX2 IN 1..NlCNT LOOP      -- 分割レコード数分

                IF MlSANTEI(NwIX1) = MlKOJIN(NwIX2).SANTEIDANTAI_CD AND
                   MlNUSHI(NwIX1)  = MlKOJIN(NwIX2).TSUCHI_NO THEN

                    -- 存在の有無をチェック
                    NwSET_SW := 1;      -- 既存

--                    -- 資格なしで新規レコード設定しないように２とする
                ELSIF funcShikKbnGet(NwIX1, i_RKOJIN) = 0 THEN        -- 該当月資格なし
                  IF MlNUSHI(NwIX1) <> MlKOJIN(NwIX2).TSUCHI_NO THEN  -- 主変更
                    IF MlKOJIN(NwIX2).NEW_SOSHITSU_BI <> 0                                      AND  -- 該当個人喪失日有り
                       TRUNC(MlNUSHI_BI(NwIX1)/100) = TRUNC(MlKOJIN(NwIX2).NEW_SOSHITSU_BI/100) AND  -- 主適用年月=喪失年月
                       ((NwIX1 <=9  AND NwIX1+3 = MOD(TRUNC(MlNUSHI_BI(NwIX1)/100),100)) OR          -- チェック中の月=主適用月
                        (NwIX1 >=10 AND NwIX1-9 = MOD(TRUNC(MlNUSHI_BI(NwIX1)/100),100)))       AND
                       MlNUSHI_BI(NwIX1) < MlKOJIN(NwIX2).NEW_SOSHITSU_BI THEN                       -- 主適用日<喪失日
                      -- 該当月は資格なしだか主適用月に一日でも資格があれば新規レコードを設定
                      NULL;
                    ELSE
                      -- 資格なしで新規レコード設定しないように２とする
                      NwSET_SW := 2;
                    END IF;
                  ELSE
                    -- 資格なしで新規レコード設定しないように２とする
                    NwSET_SW := 2;
                  END IF;

                END IF;

                -- 該当月の情報をセット
                subKojinSet(NwIX1, NwIX2, i_RKOJIN);      -- 09 該当月のデータセット

            END LOOP;

            IF NwSET_SW = 0 THEN

                -- 新規レコード設定
                NlCNT   := NlCNT + 1;

                subKojinKihonSet(NlCNT, i_RKOJIN);      -- 08 新規にレコード作成
                MlKOJIN(NlCNT).SANTEIDANTAI_CD  := MlSANTEI(NwIX1);
                MlKOJIN(NlCNT).TSUCHI_NO        := MlNUSHI(NwIX1);

                SELECT COUNT(*) INTO ICNT
                  FROM ZLBTKOJIN_N
                  WHERE KOKU_SETAI_NO   = i_RKOJIN.KOKU_SETAI_NO
                    AND KOJIN_NO        = i_RKOJIN.KOJIN_NO
                    AND SANTEIDANTAI_CD = i_RKOJIN.SANTEIDANTAI_CD
                    AND CHOTEI_NENDO    = i_RKOJIN.CHOTEI_NENDO
                    AND NENDO_BUN       = i_RKOJIN.NENDO_BUN
                    AND TSUCHI_NO       = MlNUSHI(NwIX1);
                IF ICNT = 0 THEN
                --賦課個人（最新）にまだ存在しない場合は、事由を「その他」として設定
                  MlKOJIN(NlCNT).JIYU := 99;        --99:その他（事由）
                  MlKOJIN(NlCNT).KOSEI_BI := i_NKIJUN_BI;
                  IF MlKOJIN(NlCNT).KAI_JIYU > 0 OR MlKOJIN(NlCNT).KAI_KOSEI_BI > 0 THEN
                    MlKOJIN(NlCNT).KAI_JIYU := 99;  --99:その他（事由）
                    MlKOJIN(NlCNT).KAI_KOSEI_BI := i_NKIJUN_BI;
                  END IF;
                END IF;

--                      分割（新規追加）する場合、その月（配列）の最新区分を１とする
                IF funcShikKbnGet(NwIX1, i_RKOJIN) > 0 THEN
                   MlNEWKBN(NwIX1) := 1;
                END IF;

                -- 最新失業者資格区分の再セット
                IF funcShitsuKbnGet(NwIX1, i_RKOJIN) > 0 THEN
                   MlNEWSHITSUKBN(NwIX1) := 1;
                END IF;
-- 2024/05/07 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
                --産前産後区分取得(NwIX1, 引数.計算個人) > 0　の場合
                IF funcSanKbnGet(NwIX1, i_RKOJIN) >0 THEN
                  --変数.各月最新産前産後資格区分(NwIX1) = 1
                  MlNEWSANKBN(NwIX1) := 1;
                END IF;
-- 2024/05/07　ZCZL.GUANHONG　Add　End

                subKojinSet(NwIX1, NlCNT, i_RKOJIN);      -- 09 該当月のデータセット

                -- 最新失業者資格区分が設定されていない場合
                IF MlKOJIN(NlCNT).NEW_SHITSU_KBN = 0 THEN
                    MlKOJIN(NlCNT).SHITSU_GAI_BI         := 0;
                    MlKOJIN(NlCNT).SHITSU_HIGAI_BI       := 0;
                    MlKOJIN(NlCNT).SHITSU_SHOTOKU        := 0;
                    MlKOJIN(NlCNT).SHITSU_KAHYO          := 0;
                    MlKOJIN(NlCNT).SHITSU_KEIGEN_SHOTOKU := 0;
                END IF;
-- 2024/05/07 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
                --最新産前産後資格区分が設定されていない場合
                IF MlKOJIN(NlCNT).NEW_SAN_KBN = 0 THEN
                  MlKOJIN(NlCNT).SAN_GAI_BI            := 0;
                  MlKOJIN(NlCNT).SAN_HIGAI_BI          := 0;
                  MlKOJIN(NlCNT).SAN_IRYO_GEN_KINTO    := 0;
                  MlKOJIN(NlCNT).SAN_IRYO_GEN_SHOTOKU  := 0;
                  MlKOJIN(NlCNT).SAN_KAI_GEN_KINTO     := 0;
                  MlKOJIN(NlCNT).SAN_KAI_GEN_SHOTOKU   := 0;
                  MlKOJIN(NlCNT).SAN_SIEN_GEN_KINTO    := 0;
                  MlKOJIN(NlCNT).SAN_SIEN_GEN_SHOTOKU  := 0;
--2025/08/11 ZCZL.LIUCHENYU ADD START 1.1.200.000:子ども子育て支援金対応
                  MlKOJIN(NlCNT).KDM_SAN_GEN_KINTO     := 0;
                  MlKOJIN(NlCNT).KDM_SAN_GEN_SHOTOKU   := 0;
                  MlKOJIN(NlCNT).KDM_SAN_GEN_KINTO18   := 0;
--2025/08/11 ZCZL.LIUCHENYU ADD END
                END IF;
-- 2024/05/07　ZCZL.GUANHONG　Add　End
            END IF;

        END LOOP;

    END subKojinDiv;
-------------------------------------------------------------------------------
-- 04 各区分セット
-------------------------------------------------------------------------------
    PROCEDURE subKbnSet(i_RKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) IS
        NwTSUKI             NUMBER(2);
        NwIX                NUMBER(2);
    BEGIN

        -- 各区分クリア
        FOR NwIX IN 1..12 LOOP
            MlNEWKBN(NwIX)      := 0;
            MlF4KBN(NwIX)       := 0;
            MlFUKAKBN(NwIX)     := 0;
            MlNEWSHITSUKBN(NwIX):= 0;
            MlF4SHITSUKBN(NwIX) := 0;
-- 2024/05/07 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
            MlNEWSANKBN(NwIX)   := 0; --各月最新産前産後資格区分
            MlF4SANKBN(NwIX)    := 0; --各月賦課期日産前産後資格区分
-- 2024/05/07　ZCZL.GUANHONG　Add　End
        END LOOP;

        -- 最新
        IF i_NKIJUN_BI > 0 THEN
            NwTSUKI := TRUNC(i_NKIJUN_BI - TRUNC(i_NKIJUN_BI, -4), -2) / 100;
            IF NwTSUKI <= 3 THEN
                NwTSUKI := NwTSUKI + 9;
            ELSE
                NwTSUKI := NwTSUKI - 3;
            END IF;
            MlNEWKBN(NwTSUKI) := 1;
        END IF;

        -- 賦課
        IF i_NFUKA_KIJITU > 0 THEN
            NwTSUKI := TRUNC(i_NFUKA_KIJITU - TRUNC(i_NFUKA_KIJITU, -4), -2) / 100;
            IF NwTSUKI <= 3 THEN
                NwTSUKI := NwTSUKI + 9;
            ELSE
                NwTSUKI := NwTSUKI - 3;
            END IF;
            MlF4KBN(NwTSUKI) := 1;
        END IF;

        -- 賦課発生
        IF i_RKOJIN.KEIGEN_BI > 0 THEN
            NwTSUKI := TRUNC(i_RKOJIN.KEIGEN_BI - TRUNC(i_RKOJIN.KEIGEN_BI, -4), -2) / 100;
            IF NwTSUKI <= 3 THEN
                NwTSUKI := NwTSUKI + 9;
            ELSE
                NwTSUKI := NwTSUKI - 3;
            END IF;
            MlFUKAKBN(NwTSUKI) := 1;
        END IF;
        -- 最新失業者資格区分
        IF i_NKIJUN_BI > 0 THEN
            NwTSUKI := TRUNC(i_NKIJUN_BI - TRUNC(i_NKIJUN_BI, -4), -2) / 100;
            IF NwTSUKI <= 3 THEN
                NwTSUKI := NwTSUKI + 9;
            ELSE
                NwTSUKI := NwTSUKI - 3;
            END IF;
            MlNEWSHITSUKBN(NwTSUKI) := 1;
        END IF;

        -- 賦課期日失業者資格区分
        IF i_NFUKA_KIJITU > 0 THEN
            NwTSUKI := TRUNC(i_NFUKA_KIJITU - TRUNC(i_NFUKA_KIJITU, -4), -2) / 100;
            IF NwTSUKI <= 3 THEN
                NwTSUKI := NwTSUKI + 9;
            ELSE
                NwTSUKI := NwTSUKI - 3;
            END IF;
            MlF4SHITSUKBN(NwTSUKI) := 1;
        END IF;
-- 2024/05/07 ZCZL.GUANHONG Add Start 0.3.000.100: 国保2次にマージ作業
        --最新産前産後資格区分
        IF i_NKIJUN_BI > 0 THEN --引数.判定基準日 > 0 の場合
          NwTSUKI := TRUNC(i_NKIJUN_BI - TRUNC(i_NKIJUN_BI, -4), -2) / 100;
          IF NwTSUKI <= 3 THEN
            NwTSUKI := NwTSUKI + 9;
          ELSE
            NwTSUKI := NwTSUKI - 3;
          END IF;
          MlNEWSANKBN(NwTSUKI) := 1;
        END IF;

        --賦課期日産前産後資格区分
        IF i_NFUKA_KIJITU > 0 THEN --引数.判定基準日 > 0 の場合
          NwTSUKI := TRUNC(i_NFUKA_KIJITU - TRUNC(i_NFUKA_KIJITU, -4), -2) / 100;
          IF NwTSUKI <= 3 THEN
            NwTSUKI := NwTSUKI + 9;
          ELSE
            NwTSUKI := NwTSUKI - 3;
          END IF;
          MlF4SANKBN(NwTSUKI) := 1;
        END IF;
-- 2024/05/07　ZCZL.GUANHONG　Add　End
    END subKbnSet;
-------------------------------------------------------------------------------
-- 03-2 清算区分設定(過年度課税計算時のみ)
-------------------------------------------------------------------------------
    PROCEDURE subKanenSet IS

        NwIX1           NUMBER(2);
        NwIX2           NUMBER(2);

        NwSANTEI        NUMBER(2);
--  2024/09/18 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00015
        --NwNUSHI         NUMBER(12);
        NwNUSHI         NUMBER(20);

    BEGIN

        NwSANTEI        := MlSANTEI(12);
        NwNUSHI         := MlNUSHI(12);

        FOR NwIX1 IN REVERSE 1..12 LOOP         -- 3月から前方に世帯主をチェック

            IF MlSANTEI(NwIX1) = NwSANTEI THEN

                -- 算定団体が前と同じ場合、世帯主も同じとする
                NULL;

            ELSE

                NwNUSHI  := MlNUSHI(NwIX1);

                -- 算定団体が前と異なる場合、これまでに同一の算定団体が存在するか？
                FOR NwIX2 IN REVERSE NwIX1+1..12 LOOP

                    IF MlSANTEI(NwIX1) = MlSANTEI(NwIX2) THEN

                        -- これまでに算定団体が同一の情報が存在すれば、同一の世帯主とする
                        NwNUSHI := MlNUSHI(NwIX2);
                        EXIT;

                    END IF;

                END LOOP;
            END IF;

            MlSEISAN(NwIX1) := 0;           -- 清算区分は常に0(清算なし)
            MlNUSHI(NwIX1)  := NwNUSHI;     -- 世帯主の設定

            NwSANTEI := MlSANTEI(NwIX1);

        END LOOP;

    END subKanenSet;
-------------------------------------------------------------------------------
-- 03 清算区分設定
-------------------------------------------------------------------------------
    PROCEDURE subSeisanSet IS

        NwIX1           NUMBER(2);
        NwIX2           NUMBER(2);

        NwSEISAN        NUMBER(1);
        NwSANTEI        NUMBER(2);
--  2024/09/18 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00015
        --NwNUSHI         NUMBER(12);
        NwNUSHI         NUMBER(20);

    BEGIN

        NwSEISAN        := 0;
        NwSANTEI        := MlSANTEI(1);
        NwNUSHI         := MlNUSHI(1);

        -- 清算区分を設定する
--先頭から順にチェックするように変更
--      FOR NwIX1 IN REVERSE 1..12 LOOP         -- 3月から前方に世帯主をチェック
        FOR NwIX1 IN 1..12 LOOP

            IF MlSANTEI(NwIX1) = NwSANTEI AND MlNUSHI(NwIX1) = NwNUSHI THEN
                NULL;       -- 前と同じ清算区分
            ELSE

                FOR NwIX2 IN 1..NwIX1-1 LOOP

                    NwSEISAN := 0;

                    -- これまでに算定団体・世帯主が同一の情報が存在
                    IF MlSANTEI(NwIX1) = MlSANTEI(NwIX2) AND
                       MlNUSHI(NwIX1) = MlNUSHI(NwIX2) THEN
                        NwSEISAN := MlSEISAN(NwIX2);
                        EXIT;

                    -- これまでに世帯主が異なる情報が存在
                    ELSIF MlSANTEI(NwIX1) = MlSANTEI(NwIX2) THEN
                        NwSEISAN := 1;
                        EXIT;

                    END IF;

                END LOOP;
            END IF;

            MlSEISAN(NwIX1) := NwSEISAN;
            NwSANTEI        := MlSANTEI(NwIX1);
            NwNUSHI         := MlNUSHI(NwIX1);

        END LOOP;

    END subSeisanSet;
-------------------------------------------------------------------------------
-- 02 計算清算区分読込み
-------------------------------------------------------------------------------
    PROCEDURE subSeisanRead IS
        RwSEISAN        ZLBTSEISAN_CAL%ROWTYPE;     -- 計算清算区分
    BEGIN

        BEGIN
            SELECT * INTO RwSEISAN FROM ZLBTSEISAN_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                    BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSBKJDIV', 1, SQLCODE, SQLERRM,'ZLBSBKJDIV funcSeisanRead 計算清算区分取得' ||'(国保世帯番号=' || i_NKOKU_SETAI_NO ||')' || SQLERRM, '', i_VMASIN_NO);
                ELSIF i_NTRENBAN = -1 THEN
                    -- テストの時のみ有効
                    DBMS_OUTPUT.PUT_LINE('ZLBSBKJDIV funcSeisanRead 計算清算区分取得' ||
                                         '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                         ')' || SQLERRM);
                END IF;
                RETURN;
        END;

        MlNUSHI(1)      := RwSEISAN.NUSHI_4;        -- 世帯主4月
        MlNUSHI(2)      := RwSEISAN.NUSHI_5;        -- 世帯主5月
        MlNUSHI(3)      := RwSEISAN.NUSHI_6;        -- 世帯主6月
        MlNUSHI(4)      := RwSEISAN.NUSHI_7;        -- 世帯主7月
        MlNUSHI(5)      := RwSEISAN.NUSHI_8;        -- 世帯主8月
        MlNUSHI(6)      := RwSEISAN.NUSHI_9;        -- 世帯主9月
        MlNUSHI(7)      := RwSEISAN.NUSHI_10;       -- 世帯主10月
        MlNUSHI(8)      := RwSEISAN.NUSHI_11;       -- 世帯主11月
        MlNUSHI(9)      := RwSEISAN.NUSHI_12;       -- 世帯主12月
        MlNUSHI(10)     := RwSEISAN.NUSHI_1;        -- 世帯主1月
        MlNUSHI(11)     := RwSEISAN.NUSHI_2;        -- 世帯主2月
        MlNUSHI(12)     := RwSEISAN.NUSHI_3;        -- 世帯主3月

    END subSeisanRead;
-------------------------------------------------------------------------------
-- 01 計算算定団体読込み
-------------------------------------------------------------------------------
    PROCEDURE subSanteiRead IS
        RwSANTEI        ZLBTSANTEI_CAL%ROWTYPE;     -- 計算算定団体
    BEGIN

        BEGIN
            SELECT * INTO RwSANTEI FROM ZLBTSANTEI_CAL
             WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                    BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSBKJDIV', 1, SQLCODE, SQLERRM,'ZLBSBKJDIV funcSanteiRead 計算算定団体取得' ||'(国保世帯番号=' || i_NKOKU_SETAI_NO ||')' || SQLERRM, '', i_VMASIN_NO);
                ELSIF i_NTRENBAN = -1 THEN
                    -- テストの時のみ有効
                    DBMS_OUTPUT.PUT_LINE('ZLBSBKJDIV funcSanteiRead 計算算定団体取得' ||
                                         '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                         ')' || SQLERRM);
                END IF;
                RETURN;
        END;

        MlSANTEI(1)     := RwSANTEI.SANTEI_4;       -- 算定団体コード4月
        MlSANTEI(2)     := RwSANTEI.SANTEI_5;       -- 算定団体コード5月
        MlSANTEI(3)     := RwSANTEI.SANTEI_6;       -- 算定団体コード6月
        MlSANTEI(4)     := RwSANTEI.SANTEI_7;       -- 算定団体コード7月
        MlSANTEI(5)     := RwSANTEI.SANTEI_8;       -- 算定団体コード8月
        MlSANTEI(6)     := RwSANTEI.SANTEI_9;       -- 算定団体コード9月
        MlSANTEI(7)     := RwSANTEI.SANTEI_10;      -- 算定団体コード10月
        MlSANTEI(8)     := RwSANTEI.SANTEI_11;      -- 算定団体コード11月
        MlSANTEI(9)     := RwSANTEI.SANTEI_12;      -- 算定団体コード12月
        MlSANTEI(10)    := RwSANTEI.SANTEI_1;       -- 算定団体コード1月
        MlSANTEI(11)    := RwSANTEI.SANTEI_2;       -- 算定団体コード2月
        MlSANTEI(12)    := RwSANTEI.SANTEI_3;       -- 算定団体コード3月

    END subSanteiRead;
-------------------------------------------------------------------------------
-- 00 メイン
-------------------------------------------------------------------------------
BEGIN
    NlRTN           := c_NOK;
    NlCNT           := 0;


    -- 計算算定団体・計算清算区分を読込み分割情報を設定
    subSanteiRead;              -- 01 計算算定団体TBL読込み

    IF NlRTN = c_NOK THEN
        subSeisanRead;          -- 02 計算清算区分TBL読込み
    END IF;

    IF NlRTN = c_NOK THEN
--            -- 現年課税計算の場合
            subSeisanSet;           -- 03 清算区分をセットする
--            -- 過年度課税計算の場合
    END IF;

    IF NlRTN = c_NOK THEN
        subSikakuSaiSet;            -- 12 各月資格区分再セット
    END IF;

    IF NlRTN = c_NOK THEN

    -- 計算個人を全件読込むまで処理する
        BEGIN
            FOR RwKOJIN IN ClKOJIN(i_NKOKU_SETAI_NO) LOOP

                subKbnSet(RwKOJIN);         -- 04 各区分セット
                subKojinDiv(RwKOJIN);       -- 05 計算個人の分割

                subInsert;          -- 06 計算個人INSERT
                EXIT WHEN NlRTN != c_NOK;

                NlCNT := 0;

            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                    BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSBKJDIV', 1, SQLCODE, SQLERRM,'ZLBSBKJDIV 計算個人取得' ||'(国保世帯番号=' || i_NKOKU_SETAI_NO ||')' || SQLERRM, '', i_VMASIN_NO);
                ELSIF i_NTRENBAN = -1 THEN
                    -- テストの時のみ有効
                    DBMS_OUTPUT.PUT_LINE('ZLBSBKJDIV 計算個人取得' ||
                                         '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                         ')' || SQLERRM);
                END IF;
        END;

    END IF;

    IF NlRTN = c_NOK THEN
        subDelete;      -- 07 計算個人DELETE
    END IF;

    IF NlRTN = c_NOK THEN
        subDelete2;      -- 07 計算個人DELETE2
    END IF;

    -- 終了処理
    IF NlRTN = c_NOK THEN        -- 正常に処理完了
        BEGIN
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                    BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSBKJDIV', 1, SQLCODE, SQLERRM,'ZLBSBKJDIV COMMIT発行' ||'(国保世帯番号=' || i_NKOKU_SETAI_NO ||')' || SQLERRM, '', i_VMASIN_NO);
                ELSIF i_NTRENBAN = -1 THEN
                    -- テストの時のみ有効
                    DBMS_OUTPUT.PUT_LINE('ZLBSBKJDIV COMMIT発行' ||
                                         '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                         ')' || SQLERRM);
                END IF;
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

    o_NRESULT := NlRTN;

END ZLBSBKJDIV;
/