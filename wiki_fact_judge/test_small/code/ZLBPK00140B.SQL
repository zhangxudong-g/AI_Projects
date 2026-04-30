CREATE OR REPLACE PACKAGE BODY ZLBPK00140 IS
--1.1.200.000
--------------------------------------------------------------------------------
--  業務名      ZLB_国民健康保険税
--  PG名        ZLBPK00140
--  名称        子ども判定パッケージ
--  処理概要    国保子ども子育て支援金均等割減額対応
--  引数        なし
--  戻り値      なし
--  作成者      ZCZL.HAODAPENG
--  VERSION     1.1.200.00
--------------------------------------------------------------------------------
--  変更履歴
--  2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--  FUNCTION名     FCKDM_HANTEI
--  名称           子ども人数の取得
--  処理概要       共通部品仕様（子ども人数の取得）
--  引数           i_NKOKU_SETAI_NO             国保世帯番号
--                 i_NNENDOBUN                  年度分
--                 i_NKIJUNBI                   基準日
--                 i_NKOJIN_NO                  宛名番号
--                 o_NKDM_CNT                   子ども人数
--                 i_VSYS_TANMATSU_NO            端末番号
--  戻り値         処理結果（0：正常  1：異常）
--  作成者         ZCZL.HAODAPENG 2025/08/11
--  VERSION        1.1.200.000
--------------------------------------------------------------------------------
  FUNCTION FCKDM_HANTEI (
                         i_NKOKU_SETAI_NO            IN   NUMBER,  -- 国保世帯番号
                         i_NNENDOBUN                 IN   NUMBER,  -- 年度分
                         i_NKIJUNBI                  IN   NUMBER,  -- 基準日
                         i_NKOJIN_NO                 IN   NUMBER,   -- 宛名番号
                         o_NKDM_CNT                  OUT  NUMBER,   -- 子ども人数
                         i_VSYS_TANMATSU_NO          IN   NVARCHAR2   -- 端末番号
                         ) RETURN NUMBER
  IS
    NSHORI_KEKKA_RTN  NUMBER(1);   --処理結果（0：正常  1：異常）
    INENREI_RTN       PLS_INTEGER; --年齢
    INENREI_KIJUN_BI  PLS_INTEGER; --年齢基準日
    c_NNENREI_18      CONSTANT NUMBER := 18; --年齢18（定数）
    ISEINENGAPI       PLS_INTEGER; --生年月日
  BEGIN
    --初期処理
    o_NKDM_CNT := 0;
    NSHORI_KEKKA_RTN := 0;
    INENREI_KIJUN_BI := (i_NNENDOBUN+1)*10000 + 331;
    --生年月日取得
    BEGIN
      --宛名基本から生年月日を取得する。
      SELECT NVL(SEINENGAPI,0)
        INTO ISEINENGAPI
        FROM GABTATENAKIHON
       WHERE KOJIN_NO = i_NKOJIN_NO;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        BEGIN
          --世帯員追加ワークから生年月日を取得する。
          SELECT NVL(SEINENGAPI,0)
            INTO ISEINENGAPI
            FROM ZLBWSETAIIN
           WHERE
                 NENDO_BUN = i_NNENDOBUN
             AND KOJIN_NO = i_NKOJIN_NO
             AND SYS_TANMATSU_NO = i_VSYS_TANMATSU_NO;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            ISEINENGAPI := 0;
        END;
    END;
    --生年月日 > 0 の場合
    IF ISEINENGAPI > 0 THEN
      INENREI_RTN := KKAPK0020.FAgeGet(ISEINENGAPI,
                                       INENREI_KIJUN_BI
                                       );
      -- 年齢 <= 年齢18（定数）の場合、引数.子ども人数を＋1する。
      IF INENREI_RTN <= c_NNENREI_18 THEN
        o_NKDM_CNT := o_NKDM_CNT + 1;
      END IF;
    END IF;
    RETURN NSHORI_KEKKA_RTN;
  EXCEPTION
    WHEN OTHERS THEN
       --エラーの場合
       RETURN 1;
  END FCKDM_HANTEI;
--------------------------------------------------------------------------------
--  FUNCTION名     FCSETAIKDM_HANTEI
--  名称           18歳以上人数、18歳未満人数の取得
--  処理概要       共通部品仕様（18歳以上人数、18歳未満人数の取得）
--  引数           i_NKOKU_SETAI_NO             国保世帯番号
--                 i_NNENDOBUN                  年度分
--                 i_NKIJUNBI                   基準日
--                 i_NSHORIKBN                  処理区分
--                 i_VSYS_TANMATSU_NO           端末番号
--                 o_N18IJYO_CNT                18歳以上人数
--                 o_N18SITA_CNT                18歳未満人数
--                 i_VTABLENAME                 テーブル名
--                 i_NCHOTEI_NENDO              調定年度
--                 i_NTSUCHI_NO                 通知書番号
--  戻り値         処理結果（0：正常  1：異常）
--  作成者         ZCZL.HAODAPENG 2025/08/11
--  VERSION        1.1.200.000
--------------------------------------------------------------------------------
  FUNCTION FCSETAIKDM_HANTEI (
                         i_NKOKU_SETAI_NO            IN   NUMBER,  -- 国保世帯番号
                         i_NNENDOBUN                 IN   NUMBER,  -- 年度分
                         i_NKIJUNBI                  IN   NUMBER,  -- 基準日
                         i_NSHORIKBN                 IN   NUMBER,  -- 処理区分
                         i_VSYS_TANMATSU_NO          IN   NVARCHAR2,   -- 端末番号
                         o_V18IJYO_CNT               OUT  NVARCHAR2,   -- 18歳以上人数
                         o_V18SITA_CNT               OUT  NVARCHAR2,   -- 18歳未満人数
                         i_VTABLENAME                IN   NVARCHAR2,   -- テーブル名
                         i_NCHOTEI_NENDO             IN   NUMBER,   -- 調定年度
                         i_NTSUCHI_NO                IN   NUMBER    -- 通知書番号
                         ) RETURN NUMBER
  IS
    TYPE MT_18_NINSU IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
    TYPE MTKOJIN IS REF CURSOR;
    TYPE R_RKOJIN_REC IS RECORD (
       KOJIN_NO        NUMBER
      ,NEW_SHIK_KBN    NUMBER(1)
      ,F4_SHIK_KBN     NUMBER(2)
      ,FUKA_SHIK_KBN   NUMBER(1)
      ,SHIK_4        NUMBER(2)
      ,SHIK_5        NUMBER(2)
      ,SHIK_6        NUMBER(2)
      ,SHIK_7        NUMBER(2)
      ,SHIK_8        NUMBER(2)
      ,SHIK_9        NUMBER(2)
      ,SHIK_10       NUMBER(2)
      ,SHIK_11       NUMBER(2)
      ,SHIK_12       NUMBER(2)
      ,SHIK_1        NUMBER(2)
      ,SHIK_2        NUMBER(2)
      ,SHIK_3        NUMBER(2)
    );
    NSHORI_KEKKA_RTN NUMBER(1);   --処理結果（0：正常  1：異常）
    INENREI_RTN      PLS_INTEGER; --年齢
    INENREI_KIJUN_BI PLS_INTEGER; --年齢基準日
    c_NNENREI_18     CONSTANT NUMBER := 18;  --年齢18（定数）
    ISEINENGAPI      PLS_INTEGER; --生年月日
    MUNDER_18_NINSU  MT_18_NINSU; --18歳未満人数リスト
    MOVER_18_NINSU   MT_18_NINSU; --18歳以上人数リスト
    CKOJIN           MTKOJIN;     --カーソル
    RKOJIN           R_RKOJIN_REC;  --個人情報リスト
    VSQL VARCHAR2(32000);  --編集用SQL文
  BEGIN
    --変数.18歳未満人数リスト(1)〜(15)、変数.18歳以上人数リスト(1)〜(15)を「0」で初期化する。
    FOR INDX IN 1..15 LOOP
      MUNDER_18_NINSU(INDX) := 0;
      MOVER_18_NINSU(INDX)  := 0;
    END LOOP;
    NSHORI_KEKKA_RTN := 0;
    INENREI_KIJUN_BI := (i_NNENDOBUN+1)*10000 + 331;
    --個人情報取得
    VSQL := VSQL || ' SELECT';
    VSQL := VSQL || ' KOJIN_NO';         --宛名番号
    VSQL := VSQL || ' ,NEW_SHIK_KBN';    --最新資格区分
    VSQL := VSQL || ' ,F4_SHIK_KBN';     --賦課期日資格区分
    VSQL := VSQL || ' ,FUKA_SHIK_KBN';   --賦課発生時資格区分
    VSQL := VSQL || ' ,SHIK_4';    --資格4月
    VSQL := VSQL || ' ,SHIK_5';    --資格5月
    VSQL := VSQL || ' ,SHIK_6';    --資格6月
    VSQL := VSQL || ' ,SHIK_7';    --資格7月
    VSQL := VSQL || ' ,SHIK_8';    --資格8月
    VSQL := VSQL || ' ,SHIK_9';    --資格9月
    VSQL := VSQL || ' ,SHIK_10';   --資格10月
    VSQL := VSQL || ' ,SHIK_11';   --資格11月
    VSQL := VSQL || ' ,SHIK_12';   --資格12月
    VSQL := VSQL || ' ,SHIK_1';    --資格1月
    VSQL := VSQL || ' ,SHIK_2';    --資格2月
    VSQL := VSQL || ' ,SHIK_3';    --資格3月
    IF i_VTABLENAME IS NULL THEN
      IF i_NSHORIKBN = 0 THEN
         VSQL := VSQL || ' FROM ZLBTKOJIN_CAL ';
      ELSE
         VSQL := VSQL || ' FROM ZLBTKOJIN_ZER ';
      END IF;
    ELSE
      VSQL := VSQL || ' FROM ' || i_VTABLENAME;
    END IF;
    --条件
    VSQL := VSQL || ' WHERE ';
    VSQL := VSQL || ' KOKU_SETAI_NO = ' || i_NKOKU_SETAI_NO;
    VSQL := VSQL || ' AND NENDO_BUN = ' || i_NNENDOBUN;
    IF i_VTABLENAME IS NULL AND i_NSHORIKBN = 0 THEN
      VSQL := VSQL || ' AND SYS_TANMATSU_NO = ''' || i_VSYS_TANMATSU_NO || '''';
    END IF;
    IF i_NCHOTEI_NENDO > 0 THEN
      VSQL := VSQL || ' AND CHOTEI_NENDO = ' || i_NCHOTEI_NENDO;
      VSQL := VSQL || ' AND TSUCHI_NO = ' || i_NTSUCHI_NO;
    END IF;
    OPEN CKOJIN FOR VSQL;
    LOOP
        FETCH CKOJIN INTO RKOJIN;
        EXIT WHEN CKOJIN%NOTFOUND;
            --生年月日取得
            BEGIN
              --宛名基本2から生年月日を取得する。
              SELECT NVL(SEINENGAPI,0)
                INTO ISEINENGAPI
                FROM GABTATENAKIHON
               WHERE KOJIN_NO = RKOJIN.KOJIN_NO;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                BEGIN
                  --世帯員追加ワークから生年月日を取得する。
                  SELECT NVL(SEINENGAPI,0)
                    INTO ISEINENGAPI
                    FROM ZLBWSETAIIN
                   WHERE
                         NENDO_BUN = i_NNENDOBUN
                     AND KOJIN_NO = RKOJIN.KOJIN_NO
                     AND SYS_TANMATSU_NO = i_VSYS_TANMATSU_NO;
                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                    ISEINENGAPI := 0;
                END;
            END;
            --生年月日 > 0 の場合
            IF ISEINENGAPI > 0 THEN
              INENREI_RTN := KKAPK0020.FAgeGet(ISEINENGAPI,
                                               INENREI_KIJUN_BI
                                               );
              -- 年齢 >= 18の場合
              IF INENREI_RTN > c_NNENREI_18 THEN
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_4 > 0 AND RKOJIN.SHIK_4 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_4 > 0 AND RKOJIN.SHIK_4 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(1) := MOVER_18_NINSU(1) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_5 > 0 AND RKOJIN.SHIK_5 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_5 > 0 AND RKOJIN.SHIK_5 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(2) := MOVER_18_NINSU(2) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_6 > 0 AND RKOJIN.SHIK_6 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_6 > 0 AND RKOJIN.SHIK_6 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(3) := MOVER_18_NINSU(3) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_7 > 0 AND RKOJIN.SHIK_7 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_7 > 0 AND RKOJIN.SHIK_7 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(4) := MOVER_18_NINSU(4) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_8 > 0 AND RKOJIN.SHIK_8 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_8 > 0 AND RKOJIN.SHIK_8 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(5) := MOVER_18_NINSU(5) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_9 > 0 AND RKOJIN.SHIK_9 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_9 > 0 AND RKOJIN.SHIK_9 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(6) := MOVER_18_NINSU(6) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_10 > 0 AND RKOJIN.SHIK_10 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_10 > 0 AND RKOJIN.SHIK_10 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(7) := MOVER_18_NINSU(7) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_11 > 0 AND RKOJIN.SHIK_11 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_11 > 0 AND RKOJIN.SHIK_11 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(8) := MOVER_18_NINSU(8) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_12 > 0 AND RKOJIN.SHIK_12 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_12 > 0 AND RKOJIN.SHIK_12 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(9) := MOVER_18_NINSU(9) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_1 > 0 AND RKOJIN.SHIK_1 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_1 > 0 AND RKOJIN.SHIK_1 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(10) := MOVER_18_NINSU(10) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_2 > 0 AND RKOJIN.SHIK_2 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_2 > 0 AND RKOJIN.SHIK_2 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(11) := MOVER_18_NINSU(11) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_3 > 0 AND RKOJIN.SHIK_3 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_3 > 0 AND RKOJIN.SHIK_3 NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(12) := MOVER_18_NINSU(12) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.NEW_SHIK_KBN > 0 AND RKOJIN.NEW_SHIK_KBN NOT IN (2,7,8,9) THEN
                 IF RKOJIN.NEW_SHIK_KBN > 0 AND RKOJIN.NEW_SHIK_KBN NOT IN (2,5,7,8,9) THEN
                   MOVER_18_NINSU(13) := MOVER_18_NINSU(13) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.F4_SHIK_KBN > 0 AND RKOJIN.F4_SHIK_KBN NOT IN (2,32,42) THEN
                 IF RKOJIN.F4_SHIK_KBN > 0 AND RKOJIN.F4_SHIK_KBN NOT IN (2,5,30,32,40,42) THEN
                   MOVER_18_NINSU(14) := MOVER_18_NINSU(14) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.FUKA_SHIK_KBN > 0 AND RKOJIN.FUKA_SHIK_KBN NOT IN (2,7,8,9) THEN
                 IF RKOJIN.FUKA_SHIK_KBN > 0 AND RKOJIN.FUKA_SHIK_KBN NOT IN (2,5,7,8,9) THEN
                   MOVER_18_NINSU(15) := MOVER_18_NINSU(15) + 1;
                 END IF;
              ELSE
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_4 > 0 AND RKOJIN.SHIK_4 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_4 > 0 AND RKOJIN.SHIK_4 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(1) := MUNDER_18_NINSU(1) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_5 > 0 AND RKOJIN.SHIK_5 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_5 > 0 AND RKOJIN.SHIK_5 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(2) := MUNDER_18_NINSU(2) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_6 > 0 AND RKOJIN.SHIK_6 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_6 > 0 AND RKOJIN.SHIK_6 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(3) := MUNDER_18_NINSU(3) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_7 > 0 AND RKOJIN.SHIK_7 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_7 > 0 AND RKOJIN.SHIK_7 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(4) := MUNDER_18_NINSU(4) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_8 > 0 AND RKOJIN.SHIK_8 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_8 > 0 AND RKOJIN.SHIK_8 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(5) := MUNDER_18_NINSU(5) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_9 > 0 AND RKOJIN.SHIK_9 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_9 > 0 AND RKOJIN.SHIK_9 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(6) := MUNDER_18_NINSU(6) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_10 > 0 AND RKOJIN.SHIK_10 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_10 > 0 AND RKOJIN.SHIK_10 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(7) := MUNDER_18_NINSU(7) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_11 > 0 AND RKOJIN.SHIK_11 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_11 > 0 AND RKOJIN.SHIK_11 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(8) := MUNDER_18_NINSU(8) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_12 > 0 AND RKOJIN.SHIK_12 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_12 > 0 AND RKOJIN.SHIK_12 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(9) := MUNDER_18_NINSU(9) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_1 > 0 AND RKOJIN.SHIK_1 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_1 > 0 AND RKOJIN.SHIK_1 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(10) := MUNDER_18_NINSU(10) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_2 > 0 AND RKOJIN.SHIK_2 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_2 > 0 AND RKOJIN.SHIK_2 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(11) := MUNDER_18_NINSU(11) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.SHIK_3 > 0 AND RKOJIN.SHIK_3 NOT IN (2,32,42) THEN
                 IF RKOJIN.SHIK_3 > 0 AND RKOJIN.SHIK_3 NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(12) := MUNDER_18_NINSU(12) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.NEW_SHIK_KBN > 0 AND RKOJIN.NEW_SHIK_KBN NOT IN (2,7,8,9) THEN
                 IF RKOJIN.NEW_SHIK_KBN > 0 AND RKOJIN.NEW_SHIK_KBN NOT IN (2,5,7,8,9) THEN
                   MUNDER_18_NINSU(13) := MUNDER_18_NINSU(13) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.F4_SHIK_KBN > 0 AND RKOJIN.F4_SHIK_KBN NOT IN (2,32,42) THEN
                 IF RKOJIN.F4_SHIK_KBN > 0 AND RKOJIN.F4_SHIK_KBN NOT IN (2,5,30,32,40,42) THEN
                   MUNDER_18_NINSU(14) := MUNDER_18_NINSU(14) + 1;
                 END IF;
--2025/10/16 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応_受入検証_仕様変更
--                 IF RKOJIN.FUKA_SHIK_KBN > 0 AND RKOJIN.FUKA_SHIK_KBN NOT IN (2,7,8,9) THEN
                 IF RKOJIN.FUKA_SHIK_KBN > 0 AND RKOJIN.FUKA_SHIK_KBN NOT IN (2,5,7,8,9) THEN
                   MUNDER_18_NINSU(15) := MUNDER_18_NINSU(15) + 1;
                 END IF;
              END IF;
            END IF;
    END LOOP;
    IF CKOJIN%ISOPEN THEN
      CLOSE CKOJIN;
    END IF;
    --変数.18歳以上人数リスト(1)〜(15)を2桁（前ゼロ埋め）に変換して連結した文字列を、引数.18歳以上人数に設定する。
    --変数.18歳未満人数リスト(1)〜(15)を2桁（前ゼロ埋め）に変換して連結した文字列を、引数.18歳未満人数に設定する。
    o_V18IJYO_CNT := ''; -- 18歳以上人数
    o_V18SITA_CNT := ''; -- 18歳未満人数
    FOR INDX IN 1..15 LOOP
      o_V18IJYO_CNT := o_V18IJYO_CNT || LPAD(MOVER_18_NINSU(INDX), 2, '0');
      o_V18SITA_CNT := o_V18SITA_CNT || LPAD(MUNDER_18_NINSU(INDX), 2, '0');
    END LOOP;
    --処理結果をリターンする
    RETURN NSHORI_KEKKA_RTN;

  EXCEPTION
    WHEN OTHERS THEN
       IF CKOJIN%ISOPEN THEN
         CLOSE CKOJIN;
       END IF;
       --エラーの場合
       RETURN 1;
  END FCSETAIKDM_HANTEI;
--------------------------------------------------------------------------------
--  FUNCTION名     FCKDM_SNENDO
--  名称           開始年度の取得
--  処理概要       共通部品仕様（開始年度の取得）
--  引数           o_KAISHI_NENDO             開始年度
--  戻り値         処理結果（0：正常  1：異常）
--  作成者         ZCZL.HAODAPENG 2025/08/11
--  VERSION        1.1.200.000
--------------------------------------------------------------------------------
  FUNCTION FCKDM_SNENDO (
                         o_KAISHI_NENDO            OUT   NUMBER  -- 開始年度
                         ) RETURN NUMBER
  IS
    NSHORI_KEKKA_RTN  NUMBER(1);   --処理結果（0：正常  1：異常）
    KAISHINENDO       PLS_INTEGER; --開始年度
  BEGIN
    --初期処理
    NSHORI_KEKKA_RTN := 0;
    o_KAISHI_NENDO := 0;
    --子ども・子育て支援金分（子ども分）の開始年度を取得する。
    SELECT 
      CASE NVL(MIN(NENDO),0)
        WHEN 0 THEN 9999
        ELSE MIN(NENDO)
      END
      INTO KAISHINENDO
      FROM ZLBTJOKEN
     WHERE NVL(KINTO_KDM18,0) <> 0;
    o_KAISHI_NENDO := KAISHINENDO;
    RETURN NSHORI_KEKKA_RTN;
  EXCEPTION
    WHEN OTHERS THEN
       --エラーの場合
       o_KAISHI_NENDO := 9999;
       RETURN 1;
  END FCKDM_SNENDO;
END ZLBPK00140;
/
