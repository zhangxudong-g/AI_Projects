CREATE OR REPLACE PROCEDURE ZLBSKCALKW(i_NGENKA_KBN     IN  NUMBER,
--1.1.200.000
                                          i_NTSUCHI_NO     IN  NUMBER,
                                          i_NNENDO         IN  NUMBER,
                                          i_NNENDO_BUN     IN  NUMBER,
                                          i_NSHORIBI       IN  NUMBER,
                                          i_NDANTAI        IN  NUMBER,
                                          i_NSETAI         IN  NUMBER,
                                          i_NJIKKOU_KBN    IN  NUMBER,
                                          i_NFUTU_TUKI     IN  NUMBER,
                                          i_NTOKU_TUKI     IN  NUMBER,
                                          i_NKEISAN_KBN    IN  NUMBER,
                                          i_NCHUSHI_JIYU   IN  NUMBER,
                                          i_VTANMATSU      IN  NVARCHAR2,
                                          i_NTRENBAN       IN  NUMBER,
                                          o_NRESULT        OUT NUMBER,
                                          i_NKOSEIBI       IN  NUMBER)
-----------------------------------------------------------
--  業務名         ZLB(国民健康保険税)
--  PG 名         ZLBSKCALKW
--  名称          計算期別作成
--  処理概要
--  引数          i_NGENKA_KBN            現年・過年区分
--                                            0:現年
--                                            1:過年
--                i_NTSUCHI_NO            通知書番号
--                i_NNENDO                年度
--                i_NNENDO_BUN            年度分
--                i_NSHORIBI              処理日
--                i_NDANTAI               算定団体コード
--                i_NSETAI                国保世帯番号
--                i_NJIKKOU_KBN           実行区分
--                                            0:バッチから起動 本算定
--                                            1:バッチから起動月例
--                                            2:オンライン起動 税額試算
--                                            9:オンライン起動 即時
--                i_NFUTU_TUKI            普徴月
--                i_NTOKU_TUKI            特徴月
--                i_NKEISAN_KBN           計算区分
--                                            1:普徴更正(金額調整)
--                                            2:特徴開始
--                                            3:特徴中止
--                                            11:特徴依頼取消
--                i_NCHUSHI_JIYU          中止事由
--                                            計算区分＝特徴中止時にセット(期割判定ストアド返却値)
--                                            計算区分≠特徴中止の場合は0をセット
--                i_VTANMATSU             端末番号
--                i_NTRENBAN              登録連番
--                o_NRESULT               処理結果
--                                            0:正常
--                                            0以外:異常
--                i_NKOSEIBI              更正日（入力なし:システム日付、入力あり:入力値を使用）
--  作成者       ZCZL.LIUCHANGQUAN
--  作成日       2023/08/02
--  VERSION     0.2.000.000
-----------------------------------------------------------
--  変更履歴
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
-----------------------------------------------------------
IS
  --定数宣言
  c_IRETOK            CONSTANT PLS_INTEGER   := 0;                     -- 処理結果区分(正常)
  c_IRETNG            CONSTANT PLS_INTEGER   := 1;                     -- 処理結果区分(異常)
  bRTN                BOOLEAN;
  -- エラーログSTEP NO
  c_NSTEPNO           CONSTANT NUMBER        := 99;
  -- 現年・過年
  c_NGENNEN           CONSTANT NUMBER        := 0;                     -- 現年
  c_NKANEN            CONSTANT NUMBER        := 1;                     -- 過年
  -- 計算区分
  c_NFUTSU            CONSTANT NUMBER        := 1;                     -- 普徴更正
  c_NTOKUSTART        CONSTANT NUMBER        := 2;                     -- 特徴開始
  c_NTOKUSTOP         CONSTANT NUMBER        := 3;                     -- 特徴中止
  c_NFUTSU_4          CONSTANT NUMBER        := 4;                     --普徴更正(特徴中止)
  c_NTOKUCANCEL       CONSTANT NUMBER        := 11;                    -- 特徴依頼取消し
  -- 処理区分
  c_NFUTU_JIKKO       CONSTANT NUMBER        := 0;                     -- 普徴期割実行
  c_NFUTU_MIJIKKO     CONSTANT NUMBER        := 1;                     -- 普徴期割未実行
  -- 科目コード
  c_NFUTU_JIKKO_ONLY  CONSTANT NUMBER        := 9;                     -- 普徴期割のみ(特徴期割NG)
  -- 変数宣言
  IRET                PLS_INTEGER;                                     -- 復帰値
  BRET                BOOLEAN;                                         -- 復帰値
  VERROR              NVARCHAR2(256);                                  -- エラーメッセージ
  NFUTU               NUMBER;
  NwToku              NUMBER;
  NwKeiKbn            NUMBER;
  NTUTI_NENGETU       NUMBER;                                          -- 通知年月
  NCMP_TUKI           NUMBER;                                          -- 通知月
  NTOKU_STOP          NUMBER;                                          --特徴中止月
-----------------------------------------------------------
--  世帯主個人番号取得
-----------------------------------------------------------
FUNCTION FUNCGETNUSHI_KOJIN_NO RETURN NUMBER IS
  NNUSHI_KOJIN_NO  NUMBER;

BEGIN
  SELECT NUSHI_KOJIN_NO INTO NNUSHI_KOJIN_NO FROM ZLBTKIHON_CAL
   WHERE KOKU_SETAI_NO   = i_NSETAI
     AND SANTEIDANTAI_CD = i_NDANTAI
     AND CHOTEI_NENDO    = i_NNENDO
     AND NENDO_BUN       = i_NNENDO_BUN
     AND TSUCHI_NO       = i_NTSUCHI_NO
     AND SYS_TANMATSU_NO = i_VTANMATSU;

  NNUSHI_KOJIN_NO := NVL(NNUSHI_KOJIN_NO, 0);

  RETURN NNUSHI_KOJIN_NO;
END FUNCGETNUSHI_KOJIN_NO;
------------------------------------------------------------------------------
-- 喪失事由チェック   本算定時に中止処理(死亡の場合は８月中止)
------------------------------------------------------------------------------
FUNCTION FUNCJIYUCHK RETURN NUMBER IS
    NKOJINNO             NUMBER := 0;
    NJIYU                NUMBER := 0;
    NRETURN              NUMBER := 0;
    IHANTEI_MODE         NUMBER := 0;
    NwCHOTEI             NUMBER := 0;

  BEGIN
    IHANTEI_MODE := ZLBPK00010.FCFFJKN2(83);
    IF IHANTEI_MODE = 1 THEN

      SELECT NVL(COUNT(*),0) INTO NwCHOTEI
        FROM ZLBTKIBETSU_N
       WHERE KAMOKU_CD       =  15
         AND KAMOKUS_CD      =  2
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND ZEN_ZEIGAKU > 0;

      IF NwCHOTEI > 0 THEN --元々特徴がある人だけ判定する

        NKOJINNO := FUNCGETNUSHI_KOJIN_NO;
        SELECT SOSHITSU_JIYU INTO NJIYU
          FROM KHSTSHIKAKU
         WHERE NEW_KBN = 0
           AND KOKU_SETAI_NO = i_NSETAI
           AND KOJIN_NO = NKOJINNO;

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
END FUNCJIYUCHK;
------------------------------------------------------------------------------
-- 特徴チェック   ８月中止が間に合う場合(６月異動情報送付前)は中止
------------------------------------------------------------------------------
FUNCTION FUNCTOKUGENCHK RETURN NUMBER IS
    NwCHOTEI             NUMBER := 0;
    NHOKENRYO_B          NUMBER := 0;
    NHOKENRYO_A          NUMBER := 0;
    IHANTEI_MODE         NUMBER := 0;
    NRETURN              NUMBER := 0;
    NwKARI_AF            NUMBER := 0;
    NwKARI_BE            NUMBER := 0;
    IwCOUNT              NUMBER := 0;
    IHONSANGO_MODE       NUMBER := 0;
    NwKARI_BE6           NUMBER := 0;

  BEGIN
    IHANTEI_MODE := ZLBPK00010.FCFFJKN2(82);
    SELECT COUNT(*) COUNT INTO IwCOUNT
      FROM ZLBTSHORI_HANI
     WHERE CHOTEI_NENDO = i_NNENDO
       AND NENDO_BUN    = i_NNENDO
       AND SHIME_NENGETSU = i_NNENDO * 100 + 06
       AND MASTER_KOSHIN_KBN    =  2;
    IF IwCOUNT > 0 THEN
      IHONSANGO_MODE := 1;
    END IF;
    IF IHANTEI_MODE = 1 THEN
      SELECT NVL(COUNT(*),0) INTO NwCHOTEI
        FROM ZLBTKIBETSU_N
       WHERE KAMOKU_CD       =  15
         AND KAMOKUS_CD      =  2
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND ZEN_ZEIGAKU > 0;

      IF NwCHOTEI > 0 THEN
        -- 年税の増減を判断する
        -- 年税(A)を取得する＿計算TBL
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--        SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0)
        SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0) + NVL(D.NENZEI,0)
          INTO NHOKENRYO_A
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--          FROM ZLBTKIHON_CAL A, ZLBTKAI_KIHON_CAL B, ZLBTSIEN_KIHON_CAL C
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
--           AND C.SYS_TANMATSU_NO(+) = A.SYS_TANMATSU_NO;
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
--          SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0)
          SELECT A.NENZEI + NVL(B.NENZEI,0) + NVL(C.NENZEI,0) + NVL(D.NENZEI,0)
            INTO NHOKENRYO_B
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--            FROM ZLBTKIHON_N A, ZLBTKAI_KIHON_N B, ZLBTSIEN_KIHON_N C
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
--             AND C.TSUCHI_NO(+)       = A.TSUCHI_NO;
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
          IF IHONSANGO_MODE = 1 THEN
            SELECT NVL(SUM(ZEN_ZEIGAKU),0)
              INTO NwKARI_BE
              FROM ZLBTKIBETSU_N
             WHERE KAMOKU_CD       =  15
               AND KAMOKUS_CD      =  2
               AND KOKU_SETAI_NO   =  i_NSETAI
               AND SANTEIDANTAI_CD =  i_NDANTAI
               AND CHOTEINENDO     =  i_NNENDO
               AND NENDOBUN        =  i_NNENDO_BUN
               AND TSUCHI_NO       =  i_NTSUCHI_NO
               AND RONRIKIBETSU    <= 5  ;       -- 論理期別(8月まで)
            IF NHOKENRYO_A < NwKARI_BE THEN      --仮徴収額(8月)までと同額なら８月は中止する必要なし
              NRETURN := 1;--特徴中止
            END IF;
          ELSE
            NRETURN := 1;--特徴中止
          END IF;
        END IF;
      END IF;
    END IF;
    RETURN(NRETURN);
  -- 異常処理
  EXCEPTION
      WHEN OTHERS THEN
        RETURN(NRETURN);
END FUNCTOKUGENCHK;
------------------------------------------------------------------------------
-- 特徴チェック    更正前に特徴８月期がない時は６月から普徴期割できる
------------------------------------------------------------------------------
FUNCTION FUNCTOKU6CHK RETURN NUMBER IS
    NRETURN              NUMBER := 0;
    IwCOUNT              NUMBER := 0;
    IHONSANGO_MODE       NUMBER := 0;
    NwKARI_BE6           NUMBER := 0;

  BEGIN
    SELECT COUNT(*) COUNT INTO IwCOUNT
      FROM ZLBTSHORI_HANI
     WHERE CHOTEI_NENDO = i_NNENDO
       AND NENDO_BUN    = i_NNENDO
       AND SHIME_NENGETSU = i_NNENDO * 100 + 06
       AND MASTER_KOSHIN_KBN    =  2;
    IF IwCOUNT > 0 THEN
      IHONSANGO_MODE := 1;
    END IF;

    IF IHONSANGO_MODE = 1 THEN
      SELECT NVL(SUM(ZEN_ZEIGAKU),0)
        INTO NwKARI_BE6
        FROM ZLBTKIBETSU_N
       WHERE KAMOKU_CD       =  15
         AND KAMOKUS_CD      =  2
         AND KOKU_SETAI_NO   =  i_NSETAI
         AND SANTEIDANTAI_CD =  i_NDANTAI
         AND CHOTEINENDO     =  i_NNENDO
         AND NENDOBUN        =  i_NNENDO_BUN
         AND TSUCHI_NO       =  i_NTSUCHI_NO
         AND RONRIKIBETSU    =  5  ;       -- 論理期別(8月まで)
      IF NwKARI_BE6 = 0 THEN
        NRETURN := 1;
      END IF;
    END IF;
    RETURN(NRETURN);
  -- 異常処理
  EXCEPTION
      WHEN OTHERS THEN
        RETURN(NRETURN);
END FUNCTOKU6CHK;
-----------------------------------------------------------
--  特徴中止後の特徴開始チェック
-----------------------------------------------------------
FUNCTION FUNCTOKUCHECK RETURN PLS_INTEGER IS
  -- 変数宣言
  IRTN  PLS_INTEGER := c_IRETOK;
  BRTN  BOOLEAN     := TRUE;
  NKOJIN_NO  NUMBER;
  NTUTI_NENGETU   NUMBER;             -- 通知年月
  NCMP_TUKI       NUMBER;             -- 通知月
  NTOKU_TUKI6     NUMBER;
  NFUCHO_TUKI6    NUMBER;

  -- 特徴補足情報
  CURSOR CTOKUHOSOKU(p_NKOJIN_NO IN NUMBER) IS
    SELECT * FROM ZLBTTOKU_HOSOKU
     WHERE TOKU_KOJIN_NO = p_NKOJIN_NO
       AND SAKUSEI_BI = (SELECT MAX(SAKUSEI_BI) FROM ZLBTTOKU_HOSOKU WHERE TOKU_KOJIN_NO = p_NKOJIN_NO);

  RTOKUHOSOKU CTOKUHOSOKU%ROWTYPE;

BEGIN
  BEGIN
    IF i_NTOKU_TUKI NOT IN(6, 8) THEN
      SELECT MAX(TUTI_NENGETU)                    -- 通知年月
        INTO NTUTI_NENGETU
        FROM ZLBTSHORI_JYOTAI_KR                  -- 処理状態管理
       WHERE SHORI_SHUBETU   = 7;                 -- 処理種別
      NCMP_TUKI  := TO_NUMBER(SUBSTR(TO_CHAR(NTUTI_NENGETU), 5, 2));
      -- 処理状態管理が5月の場合は８月特徴中止を行う
      IF NCMP_TUKI = 5 AND ( FUNCTOKUGENCHK = 1 OR FUNCJIYUCHK = 1 ) THEN
        NTOKU_TUKI6 := 7;
        NFUCHO_TUKI6 := 8;
        IF FUNCTOKU6CHK = 1 THEN
          NTOKU_TUKI6 := 6;
          NFUCHO_TUKI6 := 10;
        END IF;
      -- 計算普徴期別作成
        ZLBSKCALKWFUTU(i_NGENKA_KBN,              -- 現年・過年区分
                           i_NTSUCHI_NO,          -- 通知書番号
                           i_NNENDO,              -- 年度
                           i_NNENDO_BUN,          -- 年度分
                           i_NSHORIBI,            -- 処理日
                           i_NDANTAI,             -- 算定団体コード
                           i_NSETAI,              -- 国保世帯番号
                           i_NJIKKOU_KBN,         -- 実行区分
                           NTOKU_TUKI6,           --普徴月
                           NFUCHO_TUKI6,          --特徴月
                           i_NKEISAN_KBN,         -- 計算区分
                           i_NCHUSHI_JIYU,        -- 中止事由
                           i_VTANMATSU,           -- 端末NO
                           i_NTRENBAN,            -- 登録連番
                           IRTN,                  -- 戻り値
                           i_NKOSEIBI);           -- 更正日
      ELSE
        -- 計算普徴期別作成
        ZLBSKCALKWFUTU(i_NGENKA_KBN,              -- 現年・過年区分
                           i_NTSUCHI_NO,          -- 通知書番号
                           i_NNENDO,              -- 年度
                           i_NNENDO_BUN,          -- 年度分
                           i_NSHORIBI,            -- 処理日
                           i_NDANTAI,             -- 算定団体コード
                           i_NSETAI,              -- 国保世帯番号
                           i_NJIKKOU_KBN,         -- 実行区分
                           i_NFUTU_TUKI,          -- 普徴月
                           i_NTOKU_TUKI,          -- 特徴月
                           i_NKEISAN_KBN,         -- 計算区分
                           i_NCHUSHI_JIYU,        -- 中止事由
                           i_VTANMATSU,           -- 端末NO
                           i_NTRENBAN,            -- 登録連番
                           IRTN,                  -- 戻り値
                           i_NKOSEIBI);           -- 更正日
      END IF;
      IF IRTN <> c_IRETOK THEN
        VERROR := 'FUNCTOKUCHECK 計算普徴期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
        RETURN IRTN;
      END IF;
    ELSE
      SELECT MAX(TUTI_NENGETU)               -- 通知年月
        INTO NTUTI_NENGETU
        FROM ZLBTSHORI_JYOTAI_KR             -- 処理状態管理
       WHERE SHORI_SHUBETU   = 7;            -- 処理種別

      NCMP_TUKI  := TO_NUMBER(SUBSTR(TO_CHAR(NTUTI_NENGETU), 5, 2));
      -- 処理状態管理が6月の場合は特徴開始チェックを行う
      IF NCMP_TUKI = 6 THEN
        NKOJIN_NO := FUNCGETNUSHI_KOJIN_NO;
        OPEN CTOKUHOSOKU(NKOJIN_NO);
        FETCH CTOKUHOSOKU INTO RTOKUHOSOKU;
          IF CTOKUHOSOKU%NOTFOUND THEN
            -- 計算普徴期別作成
            ZLBSKCALKWFUTU(i_NGENKA_KBN,                     -- 現年・過年区分
                               i_NTSUCHI_NO,                 -- 通知書番号
                               i_NNENDO,                     -- 年度
                               i_NNENDO_BUN,                 -- 年度分
                               i_NSHORIBI,                   -- 処理日
                               i_NDANTAI,                    -- 算定団体コード
                               i_NSETAI,                     -- 国保世帯番号
                               i_NJIKKOU_KBN,                -- 実行区分
                               i_NFUTU_TUKI,                 -- 普徴月
                               i_NTOKU_TUKI,                 -- 特徴月
                               i_NKEISAN_KBN,                -- 計算区分
                               i_NCHUSHI_JIYU,               -- 中止事由
                               i_VTANMATSU,                  -- 端末NO
                               i_NTRENBAN,                   -- 登録連番
                               IRTN,                         -- 戻り値
                               i_NKOSEIBI);                  -- 更正日
            IF IRTN <> c_IRETOK THEN
              VERROR := 'FUNCTOKUCHECK 計算普徴期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
              RETURN IRTN;
            END IF;
          ELSE
            IF RTOKUHOSOKU.HOSOKU_NENDO = i_NNENDO THEN
              -- 計算特徴開始期別作成
              ZLBSKCALKWTKST(i_NTSUCHI_NO,                   -- 通知書番号
                                      i_NNENDO,              -- 年度
                                      i_NNENDO_BUN,          -- 年度分
                                      i_NSHORIBI,            -- 処理日
                                      i_NDANTAI,             -- 算定団体コード
                                      i_NSETAI,              -- 国保世帯番号
                                      i_NJIKKOU_KBN,         -- 実行区分
                                      i_NFUTU_TUKI,          -- 普徴月
                                      10,                    -- 特徴月（固定）
                                      i_VTANMATSU,           -- 端末NO
                                      i_NTRENBAN,            -- 登録連番
                                      NFUTU,                 -- 普徴期割実施区分
                                      IRTN,                  -- 戻り値
                                      i_NKOSEIBI);           -- 更正日
              IF IRTN <> c_IRETOK THEN
                VERROR := 'FUNCTOKUCHECK 計算特徴開始期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
                RETURN IRTN;
              END IF;

              IF NFUTU = c_NFUTU_JIKKO THEN
                -- 計算普徴期別作成
                ZLBSKCALKWFUTU(i_NGENKA_KBN,                 -- 現年・過年区分
                                   i_NTSUCHI_NO,             -- 通知書番号
                                   i_NNENDO,                 -- 年度
                                   i_NNENDO_BUN,             -- 年度分
                                   i_NSHORIBI,               -- 処理日
                                   i_NDANTAI,                -- 算定団体コード
                                   i_NSETAI,                 -- 国保世帯番号
                                   i_NJIKKOU_KBN,            -- 実行区分
                                   i_NFUTU_TUKI,             -- 普徴月
                                   10,                       -- 特徴月（固定）
                                   c_NTOKUSTART,             -- 計算区分
                                   i_NCHUSHI_JIYU,           -- 中止事由
                                   i_VTANMATSU,              -- 端末NO
                                   i_NTRENBAN,               -- 登録連番
                                   IRTN,                     -- 戻り値
                                   i_NKOSEIBI);              -- 更正日
                IF IRTN <> c_IRETOK THEN
                  VERROR := 'FUNCTOKUCHECK 計算普徴期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
                  RETURN IRTN;
                END IF;
              END IF;
            ELSE
              -- 計算普徴期別作成
              ZLBSKCALKWFUTU(i_NGENKA_KBN,                  -- 現年・過年区分
                                 i_NTSUCHI_NO,              -- 通知書番号
                                 i_NNENDO,                  -- 年度
                                 i_NNENDO_BUN,              -- 年度分
                                 i_NSHORIBI,                -- 処理日
                                 i_NDANTAI,                 -- 算定団体コード
                                 i_NSETAI,                  -- 国保世帯番号
                                 i_NJIKKOU_KBN,             -- 実行区分
                                 i_NFUTU_TUKI,              -- 普徴月
                                 i_NTOKU_TUKI,              -- 特徴月
                                 i_NKEISAN_KBN,             -- 計算区分
                                 i_NCHUSHI_JIYU,            -- 中止事由
                                 i_VTANMATSU,               -- 端末NO
                                 i_NTRENBAN,                -- 登録連番
                                 IRTN,                      -- 戻り値
                                 i_NKOSEIBI);               -- 更正日
              IF IRTN <> c_IRETOK THEN
                VERROR := 'FUNCTOKUCHECK 計算普徴期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
                RETURN IRTN;
              END IF;
            END IF;
          END IF;
        CLOSE CTOKUHOSOKU;
      ELSIF NCMP_TUKI = 5 AND ( FUNCTOKUGENCHK = 1 OR FUNCJIYUCHK = 1 )THEN
        ZLBSKCALKWFUTU(i_NGENKA_KBN,                        -- 現年・過年区分
                           i_NTSUCHI_NO,                    -- 通知書番号
                           i_NNENDO,                        -- 年度
                           i_NNENDO_BUN,                    -- 年度分
                           i_NSHORIBI,                      -- 処理日
                           i_NDANTAI,                       -- 算定団体コード
                           i_NSETAI,                        -- 国保世帯番号
                           i_NJIKKOU_KBN,                   -- 実行区分
                           7,                               -- 普徴月
                           i_NTOKU_TUKI,                    -- 特徴月
                           i_NKEISAN_KBN,                   -- 計算区分
                           i_NCHUSHI_JIYU,                  -- 中止事由
                           i_VTANMATSU,                     -- 端末NO
                           i_NTRENBAN,                      -- 登録連番
                           IRTN,                            -- 戻り値
                           i_NKOSEIBI);                     -- 更正日
      ELSE
        ZLBSKCALKWFUTU(i_NGENKA_KBN,                        -- 現年・過年区分
                           i_NTSUCHI_NO,                    -- 通知書番号
                           i_NNENDO,                        -- 年度
                           i_NNENDO_BUN,                    -- 年度分
                           i_NSHORIBI,                      -- 処理日
                           i_NDANTAI,                       -- 算定団体コード
                           i_NSETAI,                        -- 国保世帯番号
                           i_NJIKKOU_KBN,                   -- 実行区分
                           i_NFUTU_TUKI,                    -- 普徴月
                           i_NTOKU_TUKI,                    -- 特徴月
                           i_NKEISAN_KBN,                   -- 計算区分
                           i_NCHUSHI_JIYU,                  -- 中止事由
                           i_VTANMATSU,                     -- 端末NO
                           i_NTRENBAN,                      -- 登録連番
                           IRTN,                            -- 戻り値
                           i_NKOSEIBI);                     -- 更正日
        IF IRTN <> c_IRETOK THEN
          VERROR := 'FUNCTOKUCHECK 計算普徴期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
          RETURN IRTN;
        END IF;
      END IF;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IRTN   := c_IRETNG;
      VERROR := 'FUNCTOKUCHECK 特徴中止後の特徴開始チェック（国保世帯番号='|| i_NSETAI ||'）' || SQLERRM;
  END;
  RETURN IRTN;
END FUNCTOKUCHECK;
-----------------------------------------------------------
--  処理メイン
-----------------------------------------------------------
BEGIN
  -- 変数初期化
  IRET := c_IRETOK;
  BRET := TRUE;
  NwKeiKbn := i_NKEISAN_KBN;

  IF i_NGENKA_KBN = c_NKANEN AND i_NKEISAN_KBN <> c_NFUTSU THEN
    IRET := c_IRETNG;
    VERROR := '過年度は普徴以外操作不可能（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
    GOTO ERROR_EXIT;
  END IF;
  SELECT MAX(TUTI_NENGETU)               -- 通知年月
    INTO NTUTI_NENGETU
    FROM ZLBTSHORI_JYOTAI_KR             -- 処理状態管理
   WHERE SHORI_SHUBETU   = 7;            -- 処理種別
  NCMP_TUKI  := TO_NUMBER(SUBSTR(TO_CHAR(NTUTI_NENGETU), 5, 2));

  IF i_NKEISAN_KBN = c_NFUTSU  OR i_NKEISAN_KBN = c_NFUTSU_4 THEN
  --計算区分が普徴期割で特徴調定がある場合は先に８月中止処理をする
    IF NCMP_TUKI = 5 AND ( FUNCTOKUGENCHK = 1 OR FUNCJIYUCHK = 1 ) THEN
       IF FUNCTOKU6CHK = 1 THEN
          NTOKU_STOP := 10;
       ELSE
          NTOKU_STOP := 8;
       END IF;
      -- 計算特徴中止期別作成
      ZLBSKCALKWTKSP(i_NTSUCHI_NO,                  -- 通知書番号
                             i_NNENDO,              -- 年度
                             i_NNENDO_BUN,          -- 年度分
                             i_NSHORIBI,            -- 処理日
                             i_NDANTAI,             -- 算定団体コード
                             i_NSETAI,              -- 国保世帯番号
                             i_NJIKKOU_KBN,         -- 実行区分
                             NTOKU_STOP,            --特徴月
                             i_NCHUSHI_JIYU,        -- 中止事由
                             i_VTANMATSU,           -- 端末NO
                             i_NTRENBAN,            -- 登録連番
                             NFUTU,                 -- 普徴期割実施区分
                             IRET,                  -- 戻り値
                             i_NKOSEIBI);           -- 更正日
      IF IRET <> c_IRETOK THEN
        VERROR := '計算特徴中止期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
        GOTO ERROR_EXIT;
      END IF;
      IRET := FUNCTOKUCHECK;
      IF IRET <> c_IRETOK THEN
        VERROR := '特徴中止後の特徴開始チェック（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
        GOTO ERROR_EXIT;
      END IF;
    ELSE
      -- 計算普徴期別作成
      ZLBSKCALKWFUTU(i_NGENKA_KBN,                  -- 現年・過年区分
                         i_NTSUCHI_NO,              -- 通知書番号
                         i_NNENDO,                  -- 年度
                         i_NNENDO_BUN,              -- 年度分
                         i_NSHORIBI,                -- 処理日
                         i_NDANTAI,                 -- 算定団体コード
                         i_NSETAI,                  -- 国保世帯番号
                         i_NJIKKOU_KBN,             -- 実行区分
                         i_NFUTU_TUKI,              -- 普徴月
                         i_NTOKU_TUKI,              -- 特徴月
                         i_NKEISAN_KBN,             -- 計算区分
                         i_NCHUSHI_JIYU,            -- 中止事由
                         i_VTANMATSU,               -- 端末NO
                         i_NTRENBAN,                -- 登録連番
                         IRET,                      -- 戻り値
                         i_NKOSEIBI);               -- 更正日
    END IF;
    IF IRET <> c_IRETOK THEN
      VERROR := '計算普徴期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
      GOTO ERROR_EXIT;
    END IF;
  ELSIF i_NKEISAN_KBN = c_NTOKUSTOP THEN
    --計算区分が普徴期割で特徴調定がある場合は先に８月中止処理をする
    IF NCMP_TUKI = 5 AND ( FUNCTOKUGENCHK = 1 OR FUNCJIYUCHK = 1 ) THEN
      -- 計算特徴中止期別作成
      ZLBSKCALKWTKSP(i_NTSUCHI_NO,                  -- 通知書番号
                             i_NNENDO,              -- 年度
                             i_NNENDO_BUN,          -- 年度分
                             i_NSHORIBI,            -- 処理日
                             i_NDANTAI,             -- 算定団体コード
                             i_NSETAI,              -- 国保世帯番号
                             i_NJIKKOU_KBN,         -- 実行区分
                             8,                     -- 特徴月
                             i_NCHUSHI_JIYU,        -- 中止事由
                             i_VTANMATSU,           -- 端末NO
                             i_NTRENBAN,            -- 登録連番
                             NFUTU,                 -- 普徴期割実施区分
                             IRET,                  -- 戻り値
                             i_NKOSEIBI);           -- 更正日
    ELSE
      -- 計算特徴中止期別作成
      ZLBSKCALKWTKSP(i_NTSUCHI_NO,                  -- 通知書番号
                             i_NNENDO,              -- 年度
                             i_NNENDO_BUN,          -- 年度分
                             i_NSHORIBI,            -- 処理日
                             i_NDANTAI,             -- 算定団体コード
                             i_NSETAI,              -- 国保世帯番号
                             i_NJIKKOU_KBN,         -- 実行区分
                             i_NTOKU_TUKI,          -- 特徴月
                             i_NCHUSHI_JIYU,        -- 中止事由
                             i_VTANMATSU,           -- 端末NO
                             i_NTRENBAN,            -- 登録連番
                             NFUTU,                 -- 普徴期割実施区分
                             IRET,                  -- 戻り値
                             i_NKOSEIBI);           -- 更正日
    END IF;
    IF IRET <> c_IRETOK THEN
      VERROR := '計算特徴中止期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
      GOTO ERROR_EXIT;
    END IF;
    IRET := FUNCTOKUCHECK;
    IF IRET <> c_IRETOK THEN
      VERROR := '特徴中止後の特徴開始チェック（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
      GOTO ERROR_EXIT;
    END IF;
  ELSIF i_NKEISAN_KBN = c_NTOKUSTART THEN
    -- 計算特徴開始期別作成
    ZLBSKCALKWTKST(i_NTSUCHI_NO,                   -- 通知書番号
                            i_NNENDO,              -- 年度
                            i_NNENDO_BUN,          -- 年度分
                            i_NSHORIBI,            -- 処理日
                            i_NDANTAI,             -- 算定団体コード
                            i_NSETAI,              -- 国保世帯番号
                            i_NJIKKOU_KBN,         -- 実行区分
                            i_NFUTU_TUKI,          -- 普徴月
                            i_NTOKU_TUKI,          -- 特徴月
                            i_VTANMATSU,           -- 端末NO
                            i_NTRENBAN,            -- 登録連番
                            NFUTU,                 -- 普徴期割実施区分
                            IRET,                  -- 戻り値
                            i_NKOSEIBI);           -- 更正日
    IF IRET <> c_IRETOK THEN
      VERROR := '計算特徴開始期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
      GOTO ERROR_EXIT;
    END IF;
    IF NFUTU IN (c_NFUTU_JIKKO , c_NFUTU_JIKKO_ONLY) THEN
      -- 特徴開始後の普徴期
      IF NFUTU = c_NFUTU_JIKKO THEN
        NwKeiKbn := i_NKEISAN_KBN;  -- 引数の特徴開始
      ELSE
        NwKeiKbn := c_NFUTSU;       -- 普徴期割
      END IF;
      -- 計算普徴期別作成
      ZLBSKCALKWFUTU(i_NGENKA_KBN,                  -- 現年・過年区分
                         i_NTSUCHI_NO,              -- 通知書番号
                         i_NNENDO,                  -- 年度
                         i_NNENDO_BUN,              -- 年度分
                         i_NSHORIBI,                -- 処理日
                         i_NDANTAI,                 -- 算定団体コード
                         i_NSETAI,                  -- 国保世帯番号
                         i_NJIKKOU_KBN,             -- 実行区分
                         i_NFUTU_TUKI,              -- 普徴月
                         i_NTOKU_TUKI,              -- 特徴月
                         NwKeiKbn,                  -- 計算区分
                         i_NCHUSHI_JIYU,            -- 中止事由
                         i_VTANMATSU,               -- 端末NO
                         i_NTRENBAN,                -- 登録連番
                         IRET,                      -- 戻り値
                         i_NKOSEIBI);               -- 更正日
      IF IRET <> c_IRETOK THEN
        VERROR := '計算普徴期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
        GOTO ERROR_EXIT;
      END IF;
    END IF;
  ELSIF i_NKEISAN_KBN = c_NTOKUCANCEL THEN
    -- 計算特徴依頼取消期別作成
    ZLBSKCALKWTKCA(i_NTSUCHI_NO,                    -- 通知書番号
                             i_NNENDO,              -- 年度
                             i_NNENDO_BUN,          -- 年度分
                             i_NSHORIBI,            -- 処理日
                             i_NDANTAI,             -- 算定団体コード
                             i_NSETAI,              -- 国保世帯番号
                             i_NJIKKOU_KBN,         -- 実行区分
                             i_NTOKU_TUKI,          -- 特徴月
                             i_NCHUSHI_JIYU,        -- 中止事由
                             i_VTANMATSU,           -- 端末NO
                             i_NTRENBAN,            -- 登録連番
                             NFUTU,                 -- 普徴期割実施区分
                             IRET,                  -- 戻り値
                             i_NKOSEIBI);           -- 更正日
    IF IRET <> c_IRETOK THEN
      VERROR := '計算特徴依頼取消期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
      GOTO ERROR_EXIT;
    END IF;

    IF NFUTU = c_NFUTU_JIKKO THEN
      -- 計算普徴期別作成
      ZLBSKCALKWFUTU(i_NGENKA_KBN,                  -- 現年・過年区分
                         i_NTSUCHI_NO,              -- 通知書番号
                         i_NNENDO,                  -- 年度
                         i_NNENDO_BUN,              -- 年度分
                         i_NSHORIBI,                -- 処理日
                         i_NDANTAI,                 -- 算定団体コード
                         i_NSETAI,                  -- 国保世帯番号
                         i_NJIKKOU_KBN,             -- 実行区分
                         i_NFUTU_TUKI,              -- 普徴月
                         i_NTOKU_TUKI,              -- 特徴月
                         i_NKEISAN_KBN,             -- 計算区分
                         i_NCHUSHI_JIYU,            -- 中止事由
                         i_VTANMATSU,               -- 端末NO
                         i_NTRENBAN,                -- 登録連番
                         IRET,                      -- 戻り値
                         i_NKOSEIBI);               -- 更正日
      IF IRET <> c_IRETOK THEN
        VERROR := '計算普徴期別作成（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
        GOTO ERROR_EXIT;
      END IF;
    END IF;
  ELSE
    VERROR := '計算区分（国保世帯番号='|| i_NSETAI ||'）エラーが発生しました';
    GOTO ERROR_EXIT;
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
  IF IRET <> c_IRETOK AND i_NTRENBAN <> 0 AND VERROR IS NOT NULL THEN
    bRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCALKW', 1, '', '','ZLBSKCALKW ' || VERROR, '', i_VTANMATSU);
  END IF;

  o_NRESULT := IRET;

END ZLBSKCALKW;
/
