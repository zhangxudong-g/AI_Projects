CREATE OR REPLACE FUNCTION GKBFKZKGMGET(i_IKUBUN      IN  PLS_INTEGER,
--1.0.000.000-02.02-02.02
                                        i_IZOKUGARA_CD1 IN  PLS_INTEGER,
                                        i_IZOKUGARA_CD2 IN  PLS_INTEGER,
                                        i_IZOKUGARA_CD3 IN  PLS_INTEGER,
                                        i_IZOKUGARA_CD4 IN  PLS_INTEGER,
                                        o_VZOKUGARAMEI OUT NVARCHAR2,
                                        o_IHERR        OUT PLS_INTEGER )  RETURN  PLS_INTEGER IS
------------------------------------------------------------------------------
--  業務名      GKB（教育）
--  PG名        GKBFKZKGMGET
--  名称        教育システム用続柄名取得ファンクション
--  処理概要    与えられた続柄コードの続柄名称（教育システム用）を戻り値として返す。
--  作成者      ZCZL.GUOXU
--  作成日      2024/01/22
--  VERSION     0.2.000.000
------------------------------------------------------------------------------
  IRTN          PLS_INTEGER;
  IFHERR        PLS_INTEGER;
  I_ZOKUGARA_CD PLS_INTEGER;
  TEMP_MEI      NVARCHAR2(10);
  ZOKUGARA_AF   NVARCHAR2(50);

  BEGIN
      IRTN := 1;
      IFHERR := 0;
      o_VZOKUGARAMEI := ' ';

      FOR IIDX IN 1..4 LOOP
                  CASE IIDX
                          WHEN 1 THEN I_ZOKUGARA_CD := i_IZOKUGARA_CD1;
                          WHEN 2 THEN I_ZOKUGARA_CD := i_IZOKUGARA_CD2;
                          WHEN 3 THEN I_ZOKUGARA_CD := i_IZOKUGARA_CD3;
                          WHEN 4 THEN I_ZOKUGARA_CD := i_IZOKUGARA_CD4;
                  END CASE;
                  IF I_ZOKUGARA_CD > 0 THEN
                     BEGIN
                          SELECT ZOKUGARAMEI
                            INTO TEMP_MEI
                            FROM GKBTZOKUGARA
                           WHERE ZOKUGARA_CD  = I_ZOKUGARA_CD
                             AND ZOKUGARA_KBN = i_IKUBUN;
                           IF IRTN = 1 THEN
                                  ZOKUGARA_AF := TEMP_MEI;
                           ELSE
                                  ZOKUGARA_AF := ZOKUGARA_AF || 'の' || TEMP_MEI;
                           END IF;
                           IRTN := 0;
                     EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                             IRTN := 1;
                             IFHERR := 1;
                             EXIT;
                           WHEN OTHERS THEN
                             IRTN := 1;
                             IFHERR := 2;
                             EXIT;
                     END;
                  END IF;
      END LOOP;
      o_VZOKUGARAMEI := ZOKUGARA_AF;
      o_IHERR := IFHERR;
      RETURN(IRTN);

  EXCEPTION
    WHEN OTHERS THEN
      RETURN(IRTN);

  END;
/
