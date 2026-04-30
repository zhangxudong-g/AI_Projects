CREATE OR REPLACE PACKAGE BODY GKBPK00010 IS
--1.0.450.000-02.02-02.02
-----------------------------------------------------------------------------------------------------------
--  業務名      GKB（教育）
--  PG名        GKBPK00010
--  名称        総合行政システム  教育共通サブルーチンパッケージ
--  作成者      ZCZL.GUOXU
--  作成日      2024/01/22
--  VERSION     0.3.000.000
-----------------------------------------------------------------------------------------------------------
--  変更履歴
--  2024/06/03 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--  2024/08/29 ZCZL.WANGMING Update 0.3.000.001:IT_GKB_00051対応
--  2024/09/02 ZCZL.WANGMING Update 0.3.000.002:IT_GKB_00051対応_2回目
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
--  2024/11/11 BOK.GoHou Update 1.0.400.000:標準入出力機能開発(出力分)
--  2025/06/05 BOK.GoHou Update 1.0.400.000:標準入出力機能開発(出力分)
-----------------------------------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --  機能概要      : 制御住所
    --  モジュール区分: 内部関数
    --  戻り値        : 住所マスク文字列  NVARCHAR2(100)
    --  バージョン    : Ver 1.0.106.000
    --  作成者／作成日: CTC.XIAOMINGBO 2025/09/18
    --------------------------------------------------------------------------------
FUNCTION FGETJUSHOMSG RETURN NVARCHAR2
IS
  aCONSPRM    A_CONS_PRM;  -- 変数.項目内容配列
  vCTLPRM    NVARCHAR2(100);  -- 住所マスク文字列
  nRTN       NUMBER;
BEGIN

    vCTLPRM := '';           -- 住所マスク文字列

    --住所マスク文字列を取得
    nRTN := KKAPK0030.FCTGetR ('GKB', '00DV_DSP', '0000', 8, aCONSPRM);
    IF nRTN = 0 THEN
        vCTLPRM := SUBSTR(RTRIM(aCONSPRM(1),' '), 1, 15);
    END IF;
    --レコードは取得できたが、CTLPRMがNULLの場合、'KKA'で取り直す
    IF vCTLPRM IS NULL OR RTRIM (RTRIM (vCTLPRM, ' '), '　') IS NULL THEN
        BEGIN

            nRTN := KKAPK0030.FCTGetR ('KKA', '00DV_DSP',  '0000', 8, aCONSPRM);
            IF nRTN = 0 THEN
                vCTLPRM := SUBSTR(RTRIM(aCONSPRM(1),' '), 1, 15);
            END IF;
            IF vCTLPRM IS NULL OR RTRIM (RTRIM (vCTLPRM, ' '), '　') IS NULL THEN
                vCTLPRM := '';
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                vCTLPRM := '';
        END;
    END IF;
    --  変数.住所マスク文字列をリターンする
    RETURN vCTLPRM;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        --業務コードでレコードが取得できなかった場合、'KKA'で取り直す
        BEGIN
            nRTN := KKAPK0030.FCTGetR ('KKA', '00DV_DSP', '0000', 8, aCONSPRM);
            IF nRTN = 0 THEN
                vCTLPRM := SUBSTR(RTRIM(aCONSPRM(1),' '), 1, 15);
            END IF;
            IF vCTLPRM IS NULL OR RTRIM (RTRIM (vCTLPRM, ' '), '　') IS NULL THEN
                vCTLPRM := '';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                vCTLPRM := '';
        END;
        --  の変数.住所マスク文字列をリターン
        RETURN vCTLPRM;
END FGETJUSHOMSG;
-----------------------------------------------------------------------------------------------------------
--学校コードチェック
FUNCTION FGCODCHK( i_GAKO_CD IN NVARCHAR2 ) RETURN NUMBER IS
IRET PLS_INTEGER ;
GAKO_CD NUMBER ;
GAKO_CD2 NUMBER ;
VGAKO_CD  NVARCHAR2(3);
i_TEMP_GAKO_CD NVARCHAR2(100):=i_GAKO_CD ;
BEGIN
  IRET := 0 ;
  BEGIN
    IF i_GAKO_CD IS NOT NULL THEN 
       IF SUBSTR(i_TEMP_GAKO_CD,-1,1) = ',' OR SUBSTR(i_TEMP_GAKO_CD,1,1) = ','  OR SUBSTR(i_TEMP_GAKO_CD,-1,1) = '.' THEN
          IRET := 1;
       ELSE
           IF INSTR(i_GAKO_CD,',',1,1) = 0 THEN
                   GAKO_CD := TO_NUMBER(i_TEMP_GAKO_CD);
                   GAKO_CD2 := CEIL(TO_NUMBER(i_TEMP_GAKO_CD));
                   IF GAKO_CD < 0 OR GAKO_CD <> GAKO_CD2  OR LENGTH(i_TEMP_GAKO_CD) <> 3   THEN
                   IRET := 1;
                   END IF;
           ELSE  LOOP 
                     VGAKO_CD := SUBSTR(i_TEMP_GAKO_CD,1,INSTR(i_TEMP_GAKO_CD,',',1,1)-1);
                     GAKO_CD := TO_NUMBER(SUBSTR(i_TEMP_GAKO_CD,1,INSTR(i_TEMP_GAKO_CD,',',1,1)-1));
                     GAKO_CD2 := CEIL(TO_NUMBER(SUBSTR(i_TEMP_GAKO_CD,1,INSTR(i_TEMP_GAKO_CD,',',1,1)-1)));
                     IF GAKO_CD < 0 OR GAKO_CD <> GAKO_CD2  OR LENGTH(VGAKO_CD) <> 3  THEN
                   	IRET := 1;
                     END IF;
                     i_TEMP_GAKO_CD := SUBSTR(i_TEMP_GAKO_CD,INSTR(i_TEMP_GAKO_CD,',',1,1)+1);
                     IF SUBSTR(i_TEMP_GAKO_CD,1,1) = ',' THEN 
                        IRET := 1;
                     END IF;
                  EXIT  WHEN INSTR(i_TEMP_GAKO_CD,',',1,1) = 0 ;
                  END LOOP;
               VGAKO_CD := i_TEMP_GAKO_CD;
               GAKO_CD := TO_NUMBER(i_TEMP_GAKO_CD);
               GAKO_CD2 := TO_NUMBER(i_TEMP_GAKO_CD);
               IF GAKO_CD < 0 OR GAKO_CD <> GAKO_CD2  OR LENGTH(VGAKO_CD) <> 3  THEN
                   IRET := 1;
               END IF;

           END IF;
      END IF;
     END IF;
  
 EXCEPTION
    WHEN OTHERS THEN
      IRET := 1;
  END;

  RETURN(IRET) ;
END ;

----------------------------------------------------------------------------------------------------
--帳票連番使用有無チェック
----------------------------------------------------------------------------------------------------
FUNCTION FRBCHK( i_IRENBAN IN NVARCHAR2 ) RETURN NUMBER IS
IRET PLS_INTEGER ;
IRENBAN PLS_INTEGER ;
BEGIN
  IRET := 0 ;
  
  BEGIN

   IF  i_IRENBAN IS NOT NULL THEN
      IRENBAN := TO_NUMBER(i_IRENBAN);
          IF NOT IRENBAN IN (0,1) THEN
             IRET := 1;
          END IF;
   END IF;
 EXCEPTION
    WHEN OTHERS THEN
      IRET := 1;
  END;

  RETURN(IRET) ;
END ;
----------------------------------------------------------------------------------------------------
--学年チェック
----------------------------------------------------------------------------------------------------
FUNCTION FGKNCHK( i_IGAKUNEN IN NVARCHAR2) RETURN NUMBER IS
IRET PLS_INTEGER ;
IGAKUNEN NUMBER ;
BEGIN
  IRET := 0 ;
  --学年
  BEGIN
  IGAKUNEN := TO_NUMBER(i_IGAKUNEN);
    IF i_IGAKUNEN IS NULL OR IGAKUNEN < 0 THEN
      IRET := 1;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IRET := 1;
  END;

  IF IRET = 0 THEN
    IF IGAKUNEN > 9 THEN
      IRET := 1;
    END IF;
  END IF;

  RETURN(IRET) ;
END ;

----------------------------------------------------------------------------------------------------
--基準日取得１
----------------------------------------------------------------------------------------------------
FUNCTION FKJBGET(i_NHAKOUBI IN NUMBER,i_NRENBAN_FLG IN NUMBER,	
	o_NKIJUNBI OUT NUMBER) RETURN NUMBER IS
BEGIN
  IF i_NRENBAN_FLG = 0 THEN
    IF i_NHAKOUBI IS NOT NULL  AND i_NHAKOUBI <> 0 THEN   
      o_NKIJUNBI :=i_NHAKOUBI;
    ELSE                                                  
     SELECT GKBTKOSHINLOG.JOKEN1 INTO o_NKIJUNBI 
       FROM GKBTKOSHINLOG
      WHERE GKBTKOSHINLOG.GYOMU_SUBCD =0 
      AND   GKBTKOSHINLOG.GROUPKEY=1 
      AND   GKBTKOSHINLOG.RENBAN=1 
      AND   GKBTKOSHINLOG.SHORI_RENBAN=2 
      AND   GKBTKOSHINLOG.NENDO=(SELECT MAX(GKBTKOSHINLOG.NENDO)
                                   FROM GKBTKOSHINLOG
                                  WHERE GKBTKOSHINLOG.GYOMU_SUBCD =0 
                                  AND   GKBTKOSHINLOG.GROUPKEY=1
                                  AND   GKBTKOSHINLOG.RENBAN=1
                                  AND   GKBTKOSHINLOG.SHORI_RENBAN=2);
    END IF;                          
  ELSIF i_NRENBAN_FLG = 1 THEN
     IF i_NHAKOUBI IS NOT NULL  AND i_NHAKOUBI <> 0 THEN
        o_NKIJUNBI :=i_NHAKOUBI;
     ELSE
        o_NKIJUNBI :=TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));
     END IF;
  ELSE
     o_NKIJUNBI :=TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));
  END IF;
RETURN 0;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
     o_NKIJUNBI := TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));
     RETURN 0;            -- 正常終了

  WHEN OTHERS THEN
    RETURN 1;      -- 異常終了

END FKJBGET;

----------------------------------------------------------------------------------------------------
--基準日取得２
----------------------------------------------------------------------------------------------------
FUNCTION FKJBGET2(i_NHAKOUBI IN NUMBER,i_NRENBAN_FLG IN NUMBER,	
	i_NTAISYOUNENDO IN NUMBER,o_NKIJUNBI OUT NUMBER) RETURN NUMBER 
IS
BEGIN
  IF i_NRENBAN_FLG = 0 THEN                
    IF i_NHAKOUBI IS NOT NULL  AND i_NHAKOUBI <> 0 THEN 
      o_NKIJUNBI :=i_NHAKOUBI;
    ELSE                                                
     SELECT GKBTKOSHINLOG.JOKEN1 INTO o_NKIJUNBI 
       FROM GKBTKOSHINLOG
      WHERE GKBTKOSHINLOG.GYOMU_SUBCD =0 
      AND   GKBTKOSHINLOG.GROUPKEY=1 
      AND   GKBTKOSHINLOG.RENBAN=1 
      AND   GKBTKOSHINLOG.SHORI_RENBAN=2 
      AND   GKBTKOSHINLOG.NENDO = i_NTAISYOUNENDO;
    END IF;                                             
  ELSIF i_NRENBAN_FLG = 1 THEN
     IF i_NHAKOUBI IS NOT NULL  AND i_NHAKOUBI <> 0 THEN
        o_NKIJUNBI :=i_NHAKOUBI;
     ELSE
        o_NKIJUNBI :=TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));
     END IF;
  ELSE
     o_NKIJUNBI :=TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));
  END IF;
RETURN 0;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
       o_NKIJUNBI :=TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));
       RETURN 0;          -- 正常終了
  WHEN OTHERS THEN
    RETURN 1;      -- 異常終了


END FKJBGET2;
--------------------------------------------------------------------------------
--学校コード変換
--------------------------------------------------------------------------------
FUNCTION FGKOCDTR( i_GAKO_CD IN NVARCHAR2 ,o_TEMP_GAKO_CD OUT NVARCHAR2) RETURN NUMBER IS
IRET PLS_INTEGER ;
N PLS_INTEGER;
NGAKOSU NUMBER ;
GAKO_CD NUMBER ;
VGAKO_CD NVARCHAR2(3);
VGAKO_CD2 NVARCHAR2(100);
BEGIN
  IRET := 0 ;
  o_TEMP_GAKO_CD  := NULL;
  VGAKO_CD2 := i_GAKO_CD;
    IF i_GAKO_CD IS NOT NULL THEN 
       IF  LENGTH(i_GAKO_CD)=3 THEN
           o_TEMP_GAKO_CD := TO_CHAR(TO_NUMBER(i_GAKO_CD));
           RETURN IRET ;
       ELSIF LENGTH(i_GAKO_CD)>3 THEN 
                NGAKOSU :=(LENGTH(VGAKO_CD2)+1)/4;
           FOR  N IN 0 .. NGAKOSU-1 LOOP
                GAKO_CD := TO_NUMBER(SUBSTR(VGAKO_CD2,1,3));
                VGAKO_CD :=TO_CHAR(GAKO_CD);
              IF N  = 0 THEN
                 o_TEMP_GAKO_CD  := VGAKO_CD;
              ELSE
                 o_TEMP_GAKO_CD :=o_TEMP_GAKO_CD || ',';
                 o_TEMP_GAKO_CD :=o_TEMP_GAKO_CD || VGAKO_CD;
              END IF;
              IF N < NGAKOSU-1 THEN
                VGAKO_CD2 :=SUBSTR(VGAKO_CD2,5);
               END IF;
           END LOOP;
        END IF;
     END IF;
    RETURN IRET ;
 EXCEPTION
    WHEN OTHERS THEN
      IRET := 1;
  RETURN IRET ;
END FGKOCDTR;

--------------------------------------------------------------------------------
-- 外国人生年月日フォーマット変換
--------------------------------------------------------------------------------
FUNCTION FYMDEDT1(i_SEINENGAPI IN PLS_INTEGER, o_YMD1 OUT NVARCHAR2, o_YMD2 OUT NVARCHAR2)
RETURN NUMBER IS

  IO_WAREKIHIZUKE   PLS_INTEGER:=0;
  IO_SEIREKIHIZUKE  PLS_INTEGER:=0;
  O_EDIT_GYYMMDD1   NVARCHAR2(9);
  O_EDIT_GYYMMDD2   NVARCHAR2(9);
  O_EDIT_GYYMMDD3   NVARCHAR2(11);
  O_KJ_GENGO        NVARCHAR2(2);
  O_KG_GENGO        NVARCHAR2(1);
  O_WAREKI_YY       PLS_INTEGER;
  O_SEIREKI_YYYY    PLS_INTEGER;
  O_WAREKI_GYYMM    PLS_INTEGER;
  O_MM              PLS_INTEGER;
  O_DD              PLS_INTEGER;
  O_IWAREKIHIZUKE   PLS_INTEGER;
  O_ISEIREKIHIZUKE  PLS_INTEGER;

--  2024/08/29 ZCZL.WANGMING DELETE 0.3.000.001:IT_GKB_00051対応
--  R_EGT_KIHON       EGT_KIHON%ROWTYPE;
  P_SEINENGAPI      PLS_INTEGER;
  B_RTN             BOOLEAN;
  N_LENGTH          NUMBER;
  N_RTN             NUMBER;
  N_BIRTH_SEIGYO    NUMBER;
  M_KKTJCONS        A_CONS_PRM;

BEGIN

--共通コンスタント取得
  M_KKTJCONS := A_CONS_PRM();
  N_RTN := KKAPK0030.FPRMSHUTOKU('GKB','00SEINENGAPI',0,M_KKTJCONS,N_LENGTH);
  IF N_LENGTH > 0 THEN
      N_BIRTH_SEIGYO := M_KKTJCONS(1);
  ELSE
      N_BIRTH_SEIGYO := 0;
  END IF;

--生年月日形式変換
  IO_SEIREKIHIZUKE := i_SEINENGAPI;
  B_RTN:=KKAPK0020.FDAYEDIT(IO_WAREKIHIZUKE,
                            IO_SEIREKIHIZUKE,
                            O_EDIT_GYYMMDD1,
                            O_EDIT_GYYMMDD2,
                            O_EDIT_GYYMMDD3,
                            O_KJ_GENGO,
                            O_KG_GENGO,
                            O_WAREKI_YY,
                            O_SEIREKI_YYYY,
                            O_WAREKI_GYYMM,
                            O_MM,
                            O_DD,
                            O_IWAREKIHIZUKE,
                            O_ISEIREKIHIZUKE);

  IF B_RTN THEN
    IF N_BIRTH_SEIGYO = 0 THEN
      o_YMD1 := O_SEIREKI_YYYY||'.'||LPAD(O_MM,2)||'.'||LPAD(O_DD,2);
      o_YMD2 := O_SEIREKI_YYYY||'年'||LPAD(O_MM,2)||'月'||LPAD(O_DD,2)||'日';
    ELSE
      o_YMD1 := O_EDIT_GYYMMDD1;
      o_YMD2 := O_EDIT_GYYMMDD3;
    END IF;
  ELSE
    o_YMD1 := ' ';
    o_YMD2 := ' ';
  END IF;
  RETURN 0;
END FYMDEDT1;
--2024/06/03 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
--任意ビット名称取得
----------------------------------------------------------------------------------------------------
-- FUNCTION FGETNMS( i_NCTLCONS_SEQ IN NUMBER ,o_TITLE OUT NVARCHAR2,
--                               o_NINIMEISHO OUT A_CONS_PRM) RETURN NUMBER IS
-- IRET      PLS_INTEGER:= 0;
-- ININIBIT  PLS_INTEGER;
-- ACONSPRM_NINIBIT     A_CONS_PRM;
-- NLENGTH   NUMBER;
-- BEGIN
--   ACONSPRM_NINIBIT := A_CONS_PRM();
--   o_NINIMEISHO := A_CONS_PRM(); 
--   o_TITLE := ' ';
--   o_NINIMEISHO.EXTEND;
--   FOR I IN 1..20 LOOP
--       o_NINIMEISHO.EXTEND;
--       o_NINIMEISHO(I) := ' ';
--   END LOOP;
--  ININIBIT := KKAPK0030.FPRMSHUTOKU('GKB','NINIBIT',i_NCTLCONS_SEQ,ACONSPRM_NINIBIT,NLENGTH);
-- 
--  IF ININIBIT = 0 THEN
--     IF LENGTH(NLENGTH) > 0 THEN
--        o_TITLE := ACONSPRM_NINIBIT(1);
--        IF NLENGTH > 1 THEN
--           FOR I IN 1..NLENGTH-1 LOOP
--               o_NINIMEISHO(I) :=  ACONSPRM_NINIBIT(I+1);
--           END LOOP;
--        END IF;
--     END IF;
--  END IF;
-- 
--  RETURN IRET ; 
--  EXCEPTION
--     WHEN OTHERS THEN
--       IRET := 0;
--   RETURN IRET ;
-- END FGETNMS;
--2024/06/03 ZCZL.muzl Delete end
----------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 生年月日フォーマット変換
--------------------------------------------------------------------------------
PROCEDURE FYMDEDT2(i_SEINENGAPI IN NVARCHAR2, o_YMD OUT NVARCHAR2, o_RTN OUT PLS_INTEGER)
IS

  IO_WAREKIHIZUKE   PLS_INTEGER:=0;
  IO_SEIREKIHIZUKE  PLS_INTEGER:=0;
  O_EDIT_GYYMMDD1   NVARCHAR2(9);
  O_EDIT_GYYMMDD2   NVARCHAR2(9);
  O_EDIT_GYYMMDD3   NVARCHAR2(11);
  O_KJ_GENGO        NVARCHAR2(2);
  O_KG_GENGO        NVARCHAR2(1);
  O_WAREKI_YY       PLS_INTEGER;
  O_SEIREKI_YYYY    PLS_INTEGER;
  O_WAREKI_GYYMM    PLS_INTEGER;
  O_MM              PLS_INTEGER;
  O_DD              PLS_INTEGER;
  O_IWAREKIHIZUKE   PLS_INTEGER;
  O_ISEIREKIHIZUKE  PLS_INTEGER;

--  2024/08/29 ZCZL.WANGMING DELETE 0.3.000.001:IT_GKB_00051対応
--  R_EGT_KIHON       EGT_KIHON%ROWTYPE;
  P_SEINENGAPI      PLS_INTEGER;
  B_RTN             BOOLEAN;
  N_LENGTH          NUMBER;
  N_RTN             NUMBER;
  N_BIRTH_SEIGYO    NUMBER;
  M_KKTJCONS        A_CONS_PRM;
  P_JINKAKU_KBN     PLS_INTEGER;  --人格区分

BEGIN

--共通コンスタント取得
  M_KKTJCONS := A_CONS_PRM();
  N_RTN := KKAPK0030.FPRMSHUTOKU('GKB','00SEINENGAPI',0,M_KKTJCONS,N_LENGTH);
  IF N_LENGTH > 0 THEN
      N_BIRTH_SEIGYO := M_KKTJCONS(1);
  ELSE
      N_BIRTH_SEIGYO := 0;
  END IF;

--人格区分と生年月日分割
  P_JINKAKU_KBN := TO_NUMBER(SUBSTR(i_SEINENGAPI,1,1)) ;
  P_SEINENGAPI  := TO_NUMBER(SUBSTR(i_SEINENGAPI,2,8)) ;

--生年月日変換

  IO_SEIREKIHIZUKE := P_SEINENGAPI;
  B_RTN:=KKAPK0020.FDAYEDIT(IO_WAREKIHIZUKE,
                            IO_SEIREKIHIZUKE,
                            O_EDIT_GYYMMDD1,
                            O_EDIT_GYYMMDD2,
                            O_EDIT_GYYMMDD3,
                            O_KJ_GENGO,
                            O_KG_GENGO,
                            O_WAREKI_YY,
                            O_SEIREKI_YYYY,
                            O_WAREKI_GYYMM,
                            O_MM,
                            O_DD,
                            O_IWAREKIHIZUKE,
                            O_ISEIREKIHIZUKE);

  IF B_RTN THEN
      IF P_JINKAKU_KBN = 0 THEN
          o_YMD := O_EDIT_GYYMMDD3;
      ELSE
          IF N_BIRTH_SEIGYO = 0 THEN
              o_YMD := O_SEIREKI_YYYY||'年'||LPAD(O_MM,2)||'月'||LPAD(O_DD,2)||'日';
          ELSE
              o_YMD := O_EDIT_GYYMMDD3;
          END IF;
      END IF;
  ELSE
    o_YMD := ' ';
  END IF;
  o_RTN := 0;
END FYMDEDT2;

----------------------------------------------------------------------------------------------------
--児童が外国人の世帯の保護者取得
----------------------------------------------------------------------------------------------------
FUNCTION FGKJHGS( i_IKIJYUNBI IN NUMBER,i_NJIDO_NO IN NUMBER,
                                o_NHOGOSHA_NO OUT NUMBER, o_VHOGOSHA_NM OUT NVARCHAR2 ) 
RETURN PLS_INTEGER IS
  ATENAKIHON_REC  GABTATENAKIHON%ROWTYPE;
  JUKIIDO_REC     GABTJUKIIDO%ROWTYPE;
  CNT             NUMBER := 0;
 BEGIN
  BEGIN
    SELECT SETAI_NO INTO ATENAKIHON_REC.SETAI_NO FROM GABTATENAKIHON 
      WHERE KOJIN_NO = i_NJIDO_NO AND GENZON_KBN = 0
        AND TEKIYO_BI <= i_IKIJYUNBI;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;             -- 異常終了
  END;

  BEGIN
    SELECT COUNT(*) INTO CNT
      FROM GABTATENAKIHON a,GABTJUKIIDO b
        WHERE   a.SETAI_NO = ATENAKIHON_REC.SETAI_NO
                AND a.KOJIN_NO = b.KOJIN_NO
                AND a.KOJIN_NO <> i_NJIDO_NO
                AND a.GENZON_KBN = 0
                AND b.NUSHI_KBN = 1
                AND a.TEKIYO_BI <= i_IKIJYUNBI;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;             -- 異常終了
  END;

  IF CNT = 1 THEN
  BEGIN
    SELECT b.KOJIN_NO,b.SHIMEI_KANJI INTO JUKIIDO_REC.KOJIN_NO,JUKIIDO_REC.SHIMEI_KANJI
      FROM GABTATENAKIHON a,GABTJUKIIDO b
        WHERE   a.SETAI_NO = ATENAKIHON_REC.SETAI_NO
                AND a.KOJIN_NO = b.KOJIN_NO
                AND a.KOJIN_NO <> i_NJIDO_NO
                AND a.GENZON_KBN = 0
                AND b.NUSHI_KBN = 1
                AND a.TEKIYO_BI <= i_IKIJYUNBI;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;             -- 異常終了
  END;
     o_NHOGOSHA_NO := JUKIIDO_REC.KOJIN_NO;    --保護者個人番号
     o_VHOGOSHA_NM := JUKIIDO_REC.SHIMEI_KANJI;--保護者漢字氏名
     RETURN 0;
  ELSE
     o_NHOGOSHA_NO := 0;    --保護者個人番号
     o_VHOGOSHA_NM := '';   --保護者漢字氏名
     RETURN 1;
  END IF;
END FGKJHGS;
----------------------------------------------------------------------------
--  名称       テーブルデータ件数カウント
--             FTCOUNT／KHKPK0010.GKBFTCOUNTより流用新規
--  処理概要   対象TBLから対象の条件で件数を取得する
--  引き数
--  INPUT      i_FROM    件数を取得するテーブル
--  INPUT      i_WHERE   抽出条件
--  戻り値     NCOUNT    データ件数
--  作成者     ZCZL.GUOXU
--  作成日     2024/01/22
--  Version    0.2.000.000
----------------------------------------------------------------------------
FUNCTION FTCOUNT(i_FROM IN  NVARCHAR2,
                        i_WHERE IN NVARCHAR2
                        )RETURN NUMBER IS
NCOUNT NUMBER;
VSQL   NVARCHAR2(2000);
TYPE CCOUNT IS REF CURSOR;
C_COUNT CCOUNT;

BEGIN
     NCOUNT := 0;
     VSQL := '';

     VSQL := VSQL || ' SELECT COUNT(*) FROM ' || i_FROM;
     IF i_WHERE IS NOT NULL THEN
       VSQL := VSQL || ' WHERE ' || i_WHERE;
     END IF;

     OPEN C_COUNT FOR TO_CHAR(VSQL);
     FETCH C_COUNT INTO NCOUNT;

     IF C_COUNT%ISOPEN THEN
        CLOSE C_COUNT;
     END IF;

     RETURN NCOUNT;

EXCEPTION
   WHEN OTHERS THEN
     RETURN -1;
END FTCOUNT;

  ------------------------------------------------------------------
  --  保護者情報取得
  --    児童個人番号、基準日を基に保護者を検索する
  ------------------------------------------------------------------
  FUNCTION  FHOGOSHA(    i_IKIJYUNBI     IN  PLS_INTEGER,
                            i_NJIDO_NO      IN  NUMBER,
                            o_NHOGOSHA_NO   OUT NUMBER) RETURN  PLS_INTEGER IS
  IRTNCD  PLS_INTEGER;

  --  対象者検索
  CURSOR  CDATA_TAISYO  IS
      SELECT  1 AS KUBUN,A.TEKIYO_BI,B.SETAI_NO,B.SEIBETSU,
              NVL(B.ZOKUGARA_CD1,0) ZOKUGARA_CD1,NVL(B.ZOKUGARA_CD2,0) ZOKUGARA_CD2,
              NVL(B.ZOKUGARA_CD3,0) ZOKUGARA_CD3,NVL(B.ZOKUGARA_CD4,0) ZOKUGARA_CD4,NVL(NUSHI_HITTOSYA,'') NUSHI_HITTOSYA
        FROM  GABTATENAKIHON A,GABTJUKIIDO B,GABTJUKIJUSHO C
      WHERE A.KOJIN_NO  = i_NJIDO_NO
        AND B.GENZON_KBN = 0
        AND A.TEKIYO_BI <= i_IKIJYUNBI
        AND A.KOJIN_NO = B.KOJIN_NO
        AND A.KOJIN_NO = C.KOJIN_NO
        AND B.HONSEKI_REN = C.JUSHO_REN
      UNION
      SELECT  2 AS KUBUN,A.TEKIYO_BI,A.SETAI_NO,A.SEIBETSU,
              NVL(ZOKUGARA_CD1,0) ZOKUGARA_CD1,NVL(ZOKUGARA_CD2,0) ZOKUGARA_CD2,
              NVL(ZOKUGARA_CD3,0) ZOKUGARA_CD3,NVL(ZOKUGARA_CD4,0) ZOKUGARA_CD4,NVL(NUSHI_HITTOSYA,'') NUSHI_HITTOSYA
        FROM  GABTATENARIREKI A,GABTJUKIJUSHO B
      WHERE A.KOJIN_NO  = i_NJIDO_NO
        AND A.GENZON_KBN = 0
        AND A.RIREKI_RENBAN= (SELECT MAX(RIREKI_RENBAN) FROM GABTATENARIREKI
                              WHERE KOJIN_NO =A.KOJIN_NO
                                AND GENZON_KBN = 0 AND TEKIYO_BI <= i_IKIJYUNBI )
        AND A.KOJIN_NO = B.KOJIN_NO
        AND A.HONSEKI_REN = B.JUSHO_REN
      ORDER BY 1;

  --  世帯内候補者検索
  CURSOR  CDATA_KOUHO( p_ISETAI_NO PLS_INTEGER, p_NUSHI_KBN PLS_INTEGER )  IS
      SELECT  1 AS KUBUN,A.TEKIYO_BI,A.KOJIN_NO,A.SETAI_NO,B.SEIBETSU,
              NVL(B.ZOKUGARA_CD1,0) ZOKUGARA_CD1,NVL(B.ZOKUGARA_CD2,0) ZOKUGARA_CD2,
              NVL(B.ZOKUGARA_CD3,0) ZOKUGARA_CD3,NVL(B.ZOKUGARA_CD4,0) ZOKUGARA_CD4,NVL(NUSHI_HITTOSYA,'') NUSHI_HITTOSYA
        FROM  GABTATENAKIHON A,GABTJUKIIDO B,GABTJUKIJUSHO C
      WHERE (A.KOJIN_NO < i_NJIDO_NO OR A.KOJIN_NO > i_NJIDO_NO )
          AND A.SETAI_NO = p_ISETAI_NO
          AND NVL(B.ZOKUGARA_CD1,0) = DECODE( p_NUSHI_KBN,0,NVL(B.ZOKUGARA_CD1,0),1 )
          AND B.GENZON_KBN = 0
          AND A.TEKIYO_BI <= i_IKIJYUNBI
          AND A.KOJIN_NO = B.KOJIN_NO
          AND A.KOJIN_NO = C.KOJIN_NO
          AND B.HONSEKI_REN = C.JUSHO_REN
      UNION
      SELECT  2 AS KUBUN,A.TEKIYO_BI,A.KOJIN_NO,A.SETAI_NO,A.SEIBETSU,
              NVL(A.ZOKUGARA_CD1,0) ZOKUGARA_CD1,NVL(A.ZOKUGARA_CD2,0) ZOKUGARA_CD2,
              NVL(A.ZOKUGARA_CD3,0) ZOKUGARA_CD3,NVL(A.ZOKUGARA_CD4,0) ZOKUGARA_CD4,NVL(NUSHI_HITTOSYA,'') NUSHI_HITTOSYA
        FROM GABTATENARIREKI A,GABTJUKIJUSHO B,GABTJUKIIDO J
      WHERE (A.KOJIN_NO < i_NJIDO_NO OR A.KOJIN_NO > i_NJIDO_NO )
        AND A.SETAI_NO = p_ISETAI_NO
        AND A.GENZON_KBN = 0
        AND A.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) FROM GABTATENARIREKI
                                WHERE KOJIN_NO <> i_NJIDO_NO
                                  AND KOJIN_NO =A.KOJIN_NO
                                    AND SYS_SAKUSEIBI <= i_IKIJYUNBI )
        AND NVL(A.ZOKUGARA_CD1,0) = DECODE( p_NUSHI_KBN,0,NVL(A.ZOKUGARA_CD1,0),1 )
        AND A.KOJIN_NO = B.KOJIN_NO
        AND A.HONSEKI_REN = B.JUSHO_REN
        AND A.KOJIN_NO = J.KOJIN_NO
        AND J.SYS_SAKUSEIBI > i_IKIJYUNBI
      ORDER BY 1;

  TYPE  MTZOKUGARA_CNT    IS TABLE OF NUMBER(2)     INDEX BY PLS_INTEGER;
  TYPE  MTSEIBETU_CNT     IS TABLE OF NUMBER(1)     INDEX BY PLS_INTEGER;
  TYPE  MTHITUTOUSYA_CNT  IS TABLE OF NVARCHAR2(100)     INDEX BY PLS_INTEGER;
  --  2024/09/02 ZCZL.WANGMING Update 0.3.000.002:IT_GKB_00051対応_2回目
  --TYPE  MTKOJIN_CNT       IS TABLE OF NUMBER(12)      INDEX BY PLS_INTEGER;
  TYPE  MTKOJIN_CNT       IS TABLE OF NUMBER      INDEX BY PLS_INTEGER;

  IZOKUGARA   MTZOKUGARA_CNT;

  NSETAI_KOJIN_NO   MTKOJIN_CNT;
  VSETAI_HITUTOUSYA MTHITUTOUSYA_CNT;
  ISETAI_SEIBETSU   MTSEIBETU_CNT;
  ISETAI_ZOKUGARA1  MTZOKUGARA_CNT;
  ISETAI_ZOKUGARA2  MTZOKUGARA_CNT;
  ISETAI_ZOKUGARA3  MTZOKUGARA_CNT;
  ISETAI_ZOKUGARA4  MTZOKUGARA_CNT;
  ISETAI_KOHOSYA    MTSEIBETU_CNT;

  ITAISYO_CNT PLS_INTEGER;

  ISETAI_NO   PLS_INTEGER;
  ISEIBETSU   PLS_INTEGER;
  --  2024/09/02 ZCZL.WANGMING Update 0.3.000.002:IT_GKB_00051対応_2回目
  --NKOJIN_NO   NUMBER(12);
  NKOJIN_NO   NUMBER;
  VHITUTOUSYA NVARCHAR2(100);

  IZOKU1        PLS_INTEGER;
  IZOKU2        PLS_INTEGER;
  IZOKU3        PLS_INTEGER;
  IZOKU4        PLS_INTEGER;

  c_INASI       CONSTANT  REAL  :=  0;  --  世帯主
  c_ISETAINUSI  CONSTANT  REAL  :=  1;  --  世帯主
  c_ITUMA       CONSTANT  REAL  :=  2;  --  妻
  c_IOTUTO      CONSTANT  REAL  :=  3;  --  夫
  c_ICHICHI     CONSTANT  REAL  :=  4;  --  父
  c_IHAHA       CONSTANT  REAL  :=  5;  --  母
  c_IKO         CONSTANT  REAL  :=  10; --  子
  c_IOJI_2      CONSTANT  REAL  :=  83; --  叔父
  c_IOBA_2      CONSTANT  REAL  :=  84; --  叔母
  c_IOJI_3      CONSTANT  REAL  :=  81; --  伯父
  c_IOBA_3      CONSTANT  REAL  :=  82; --  伯母

  c_IKO_NO_OTUTO  CONSTANT  REAL  :=  96; --  （子の夫）
  c_IKO_NO_TUMA   CONSTANT  REAL  :=  97; --  （子の妻）
  c_IKO_NO_KO_NO_OTUTO  CONSTANT  REAL  :=  98; --  （子の子の夫）
  c_IKO_NO_KO_NO_TUMA   CONSTANT  REAL  :=  99; --  （子の子の妻）

  ------------------------------------------------------------------
  --  判定用続柄コード変換
  ------------------------------------------------------------------
  FUNCTION FUNCZOKUGARA_HENKAN(i_IZOKU IN  PLS_INTEGER) RETURN PLS_INTEGER IS
    IZOKU    PLS_INTEGER;
  BEGIN
    IF i_IZOKU BETWEEN 11 AND 29 OR i_IZOKU IN( 71,72,89 ) THEN
      IZOKU := 10;  -- 子
    ELSIF i_IZOKU BETWEEN 31 AND 39 THEN
      IZOKU := 30;  -- 兄
    ELSIF i_IZOKU BETWEEN 41 AND 49 THEN
      IZOKU := 40;  -- 弟
    ELSIF i_IZOKU BETWEEN 51 AND 59 THEN
      IZOKU := 50;  -- 姉
    ELSIF i_IZOKU BETWEEN 61 AND 69 THEN
      IZOKU := 60;  -- 妹
    ELSE
      IZOKU := i_IZOKU;
    END IF;
    RETURN IZOKU;
  END FUNCZOKUGARA_HENKAN;
  ------------------------------------------------------------------
  --  児童の続柄(１０～２９，７１，７２)チェック。
  ------------------------------------------------------------------
  FUNCTION  FUNCJIDO_ZOKU_CHECK( i_IZOKUGARA  IN  PLS_INTEGER ) RETURN  BOOLEAN  IS
  BRTN  BOOLEAN;
  BEGIN
    BRTN := FALSE;
    IF i_IZOKUGARA BETWEEN 10 AND 29 OR i_IZOKUGARA IN( 71,72,89 ) THEN
       BRTN := TRUE;
    END IF;
    RETURN( BRTN );
  END FUNCJIDO_ZOKU_CHECK;

  ------------------------------------------------------------------
  --  指定位置の続柄コードを返す。
  ------------------------------------------------------------------
  PROCEDURE PROCZOKU_SITEIICHI( i_IHANTEI_ICHI  IN  PLS_INTEGER,
                                i_IIDX          IN  PLS_INTEGER,
                                o_IZOKU1        OUT PLS_INTEGER,
                                o_IZOKU2        OUT PLS_INTEGER ) IS
  BEGIN
    IF i_IHANTEI_ICHI = 1 THEN
      o_IZOKU1  :=  ISETAI_ZOKUGARA1(i_IIDX);
      o_IZOKU2:=  ISETAI_ZOKUGARA2(i_IIDX);
    ELSIF i_IHANTEI_ICHI = 2 THEN
      o_IZOKU1  :=  ISETAI_ZOKUGARA2(i_IIDX);
      o_IZOKU2:=  ISETAI_ZOKUGARA3(i_IIDX);
    ELSIF i_IHANTEI_ICHI = 3 THEN
      o_IZOKU1  :=  ISETAI_ZOKUGARA3(i_IIDX);
      o_IZOKU2:=  ISETAI_ZOKUGARA4(i_IIDX);
    ELSIF i_IHANTEI_ICHI = 4 THEN
      o_IZOKU1  :=  ISETAI_ZOKUGARA4(i_IIDX);
      o_IZOKU2:=  0;
    END IF;
  END PROCZOKU_SITEIICHI;

  ------------------------------------------------------------------
  --  指定位置の続柄コードの判定を行い、続柄コードが一致したら個人番号を返す。
  ------------------------------------------------------------------
  FUNCTION  FUNCZOKU_CHECK( i_IHANTEI_ICHI  IN  PLS_INTEGER,
                            i_IZUKUGARA     IN  PLS_INTEGER,
                            i_ITAISYO_KBN   IN  PLS_INTEGER ) RETURN  NUMBER  IS
  NHOGOSHA  NUMBER;
  BEGIN
    NHOGOSHA  :=  0;

    IF i_ITAISYO_KBN = 0 THEN
      --  指定した続柄を対象者より探す
      FOR IIDX IN 1..ITAISYO_CNT  LOOP
        PROCZOKU_SITEIICHI(i_IHANTEI_ICHI,IIDX,IZOKU1,IZOKU2);
        IF IZOKU1 = i_IZUKUGARA THEN
          NHOGOSHA  := NSETAI_KOJIN_NO(IIDX);
        END IF;
        EXIT  WHEN( NHOGOSHA <> 0 );
      END LOOP;
    ELSIF i_ITAISYO_KBN = 1 THEN
      --  同一続柄対象者より指定した続柄を対象者より探す
      FOR IIDX IN 1..ITAISYO_CNT  LOOP
        IF ISETAI_KOHOSYA(IIDX) = 1 THEN  --  対象者
          PROCZOKU_SITEIICHI(i_IHANTEI_ICHI,IIDX,IZOKU1,IZOKU2);
          IF IZOKU1 = i_IZUKUGARA THEN
            NHOGOSHA  := NSETAI_KOJIN_NO(IIDX);
          END IF;
        END IF;
        EXIT  WHEN( NHOGOSHA <> 0 );
      END LOOP;
    END IF;
    RETURN( NHOGOSHA );

  END FUNCZOKU_CHECK;

  ------------------------------------------------------------------
  --  メイン処理
  ------------------------------------------------------------------
  BEGIN

    IRTNCD  := 0;

    -- 対象児童個人番号チェック
    IF NVL(i_NJIDO_NO,0) = 0 THEN
      IRTNCD  :=  9;
      RETURN( IRTNCD );
    END IF;

    -- 対象者の取得
    IRTNCD  :=  9;
    FOR CRREC_TAISYO  IN  CDATA_TAISYO  LOOP
      IRTNCD  :=  0;
      ISETAI_NO   :=  CRREC_TAISYO.SETAI_NO;
      ISEIBETSU   :=  CRREC_TAISYO.SEIBETSU;
      IZOKUGARA(1) := FUNCZOKUGARA_HENKAN( CRREC_TAISYO.ZOKUGARA_CD1 );
      IZOKUGARA(2) := FUNCZOKUGARA_HENKAN( CRREC_TAISYO.ZOKUGARA_CD2 );
      IZOKUGARA(3) := FUNCZOKUGARA_HENKAN( CRREC_TAISYO.ZOKUGARA_CD3 );
      IZOKUGARA(4) := FUNCZOKUGARA_HENKAN( CRREC_TAISYO.ZOKUGARA_CD4 );
      VHITUTOUSYA :=  CRREC_TAISYO.NUSHI_HITTOSYA;
      EXIT;
    END LOOP;


    IF  IRTNCD  = 9 THEN
      RETURN( IRTNCD );
    END IF;

    --  世帯員の抽出
    ITAISYO_CNT :=  0;
    NKOJIN_NO   :=  0;

    FOR CRREC_KOUHO IN  CDATA_KOUHO( ISETAI_NO,0 )  LOOP
      IF NKOJIN_NO <> CRREC_KOUHO.KOJIN_NO AND VHITUTOUSYA = CRREC_KOUHO.NUSHI_HITTOSYA THEN
        ITAISYO_CNT :=  ITAISYO_CNT + 1;
        NSETAI_KOJIN_NO(ITAISYO_CNT)          :=  CRREC_KOUHO.KOJIN_NO;
        VSETAI_HITUTOUSYA(ITAISYO_CNT)  :=  CRREC_KOUHO.NUSHI_HITTOSYA;
        ISETAI_SEIBETSU(ITAISYO_CNT)    :=  CRREC_KOUHO.SEIBETSU;
        ISETAI_ZOKUGARA1(ITAISYO_CNT) := FUNCZOKUGARA_HENKAN( CRREC_KOUHO.ZOKUGARA_CD1 );
        ISETAI_ZOKUGARA2(ITAISYO_CNT) := FUNCZOKUGARA_HENKAN( CRREC_KOUHO.ZOKUGARA_CD2 );
        ISETAI_ZOKUGARA3(ITAISYO_CNT) := FUNCZOKUGARA_HENKAN( CRREC_KOUHO.ZOKUGARA_CD3 );
        ISETAI_ZOKUGARA4(ITAISYO_CNT) := FUNCZOKUGARA_HENKAN( CRREC_KOUHO.ZOKUGARA_CD4 );
        NKOJIN_NO :=  CRREC_KOUHO.KOJIN_NO;

      END IF;
    END LOOP;

    --  対象者の１～４階層目の続柄判定
  NKOJIN_NO :=  0;

    IF IZOKUGARA(4) <> 0 THEN       --  4階層目まで使用
      IF FUNCJIDO_ZOKU_CHECK( IZOKUGARA(1) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(2) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(3) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(4) ) THEN   --  子の子の子の子の場合
        --  １,２,３階層の続柄と同じ続柄のデータを候補者より抽出
        FOR IIDX IN 1..ITAISYO_CNT  LOOP
          PROCZOKU_SITEIICHI(1,IIDX,IZOKU1,IZOKU2);
          PROCZOKU_SITEIICHI(3,IIDX,IZOKU3,IZOKU4);
          ISETAI_KOHOSYA(IIDX)  := 0;
          IF IZOKUGARA(1) = IZOKU1 AND IZOKUGARA(2) = IZOKU2 AND IZOKUGARA(3) = IZOKU3 THEN
            ISETAI_KOHOSYA(IIDX)  := 1;
          END IF;
        END LOOP;
        NKOJIN_NO :=  FUNCZOKU_CHECK( 4,c_IOTUTO,1 );
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 4,c_IKO_NO_OTUTO,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 4,c_INASI,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 4,c_ITUMA,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 4,c_IKO_NO_TUMA,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          --  世帯主を探す
          FOR CRREC_KOUHO IN  CDATA_KOUHO( ISETAI_NO,1 )  LOOP
              IF NKOJIN_NO <> CRREC_KOUHO.KOJIN_NO AND VHITUTOUSYA = CRREC_KOUHO.NUSHI_HITTOSYA THEN
                 NKOJIN_NO          :=  CRREC_KOUHO.KOJIN_NO;
              END IF;
          END LOOP;
        END IF;
      END IF;

    ELSIF IZOKUGARA(3) <> 0 THEN    --  3階層目まで使用
      IF FUNCJIDO_ZOKU_CHECK( IZOKUGARA(1) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(2) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(3) ) THEN    --  子の子の子の場合
        --  １階層の続柄と同じ続柄のデータを候補者より抽出
        FOR IIDX IN 1..ITAISYO_CNT  LOOP
          PROCZOKU_SITEIICHI(1,IIDX,IZOKU1,IZOKU2);
          ISETAI_KOHOSYA(IIDX)  := 0;
          IF IZOKUGARA(1) = IZOKU1 AND IZOKUGARA(2) = IZOKU2 THEN
            ISETAI_KOHOSYA(IIDX)  := 1;
          END IF;
        END LOOP;
        NKOJIN_NO :=  FUNCZOKU_CHECK( 3,c_IOTUTO,1 );
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 3,c_IKO_NO_OTUTO,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 3,c_INASI,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 3,c_ITUMA,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 3,c_IKO_NO_TUMA,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          --  世帯主を探す
          FOR CRREC_KOUHO IN  CDATA_KOUHO( ISETAI_NO,1 )  LOOP
              IF NKOJIN_NO <> CRREC_KOUHO.KOJIN_NO AND VHITUTOUSYA = CRREC_KOUHO.NUSHI_HITTOSYA THEN
                 NKOJIN_NO          :=  CRREC_KOUHO.KOJIN_NO;
              END IF;
          END LOOP;
        END IF;
      END IF;
    ELSIF IZOKUGARA(2) <> 0 THEN    --  2階層目まで使用

      IF FUNCJIDO_ZOKU_CHECK( IZOKUGARA(1) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(2) ) THEN   --  子の子の場合
        --  １階層の続柄と同じ続柄のデータを候補者より抽出
        FOR IIDX IN 1..ITAISYO_CNT  LOOP
          PROCZOKU_SITEIICHI(1,IIDX,IZOKU1,IZOKU2);
          ISETAI_KOHOSYA(IIDX)  := 0;
          IF IZOKUGARA(1) = IZOKU1 THEN
            ISETAI_KOHOSYA(IIDX)  := 1;
          END IF;
        END LOOP;
        NKOJIN_NO :=  FUNCZOKU_CHECK( 2,c_IOTUTO,1 );
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 2,c_IKO_NO_OTUTO,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 2,c_INASI,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 2,c_ITUMA,1 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          NKOJIN_NO :=  FUNCZOKU_CHECK( 2,c_IKO_NO_TUMA,1 );
        END IF;
        -- 該当する対象者が存在しない場合は、世帯主を保護者とする
        IF NKOJIN_NO = 0 THEN
          --  世帯主を探す
          FOR CRREC_KOUHO IN  CDATA_KOUHO( ISETAI_NO,1 )  LOOP
              IF NKOJIN_NO <> CRREC_KOUHO.KOJIN_NO AND VHITUTOUSYA = CRREC_KOUHO.NUSHI_HITTOSYA THEN
                 NKOJIN_NO          :=  CRREC_KOUHO.KOJIN_NO;
              END IF;
          END LOOP;
        END IF;
      END IF;
    ELSIF IZOKUGARA(1) <> 0 THEN    --  1階層目まで使用
      IF FUNCJIDO_ZOKU_CHECK( IZOKUGARA(1) ) THEN    --  子の場合
        --  夫を探す
        NKOJIN_NO :=  FUNCZOKU_CHECK( 1,c_IOTUTO,0 );
        IF NKOJIN_NO = 0 THEN
          --  （子の夫）を探す
          NKOJIN_NO :=  FUNCZOKU_CHECK( 1,c_IKO_NO_OTUTO,0 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          --  世帯主を探す
          NKOJIN_NO :=  FUNCZOKU_CHECK( 1,c_ISETAINUSI,0 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          --  妻を探す
          NKOJIN_NO :=  FUNCZOKU_CHECK( 1,c_ITUMA,0 );
        END IF;
        IF NKOJIN_NO = 0 THEN
          --  （子の妻）を探す
          NKOJIN_NO :=  FUNCZOKU_CHECK( 1,c_IKO_NO_TUMA,0 );
        END IF;
      END IF;
    END IF;

    IF  NKOJIN_NO <> 0 THEN
      o_NHOGOSHA_NO :=  NKOJIN_NO;
    ELSE
      o_NHOGOSHA_NO :=  0;
      IRTNCD  :=  1;
    END IF;
    RETURN( IRTNCD );
  END FHOGOSHA;

  ------------------------------------------------------------------
  --  保護者情報取得（OUT　保護者名付き）
  --    児童個人番号、基準日を基に保護者を検索する
  ------------------------------------------------------------------
  FUNCTION  FHOGOSHA2( i_IKIJYUNBI     IN  PLS_INTEGER,
                          i_NJIDO_NO      IN  NUMBER,
                          o_NHOGOSHA_NO   OUT NUMBER,
                          o_VHOGOSHA_NM   OUT NVARCHAR2 ) RETURN  PLS_INTEGER IS

  IRTNCD  PLS_INTEGER;
  RTNRTN  PLS_INTEGER;

  --  対象者検索
  CURSOR  CDATA_TAISYO  IS
      SELECT  1 AS KUBUN,A.TEKIYO_BI,B.SETAI_NO,B.SEIBETSU,
              NVL(B.ZOKUGARA_CD1,0) ZOKUGARA_CD1,NVL(B.ZOKUGARA_CD2,0) ZOKUGARA_CD2,
              NVL(B.ZOKUGARA_CD3,0) ZOKUGARA_CD3,NVL(B.ZOKUGARA_CD4,0) ZOKUGARA_CD4,NVL(NUSHI_HITTOSYA,'') NUSHI_HITTOSYA
              ,A.GENZON_KBN
        FROM  GABTATENAKIHON A,GABTJUKIIDO B,GABTJUKIJUSHO C
      WHERE A.KOJIN_NO  = i_NJIDO_NO
        AND B.GENZON_KBN = 0
        AND A.TEKIYO_BI <= i_IKIJYUNBI
        AND A.KOJIN_NO = B.KOJIN_NO
        AND A.KOJIN_NO = C.KOJIN_NO
        AND B.HONSEKI_REN = C.JUSHO_REN
      UNION
      SELECT  2 AS KUBUN,A.TEKIYO_BI,A.SETAI_NO,A.SEIBETSU,
              NVL(ZOKUGARA_CD1,0) ZOKUGARA_CD1,NVL(ZOKUGARA_CD2,0) ZOKUGARA_CD2,
              NVL(ZOKUGARA_CD3,0) ZOKUGARA_CD3,NVL(ZOKUGARA_CD4,0) ZOKUGARA_CD4,NVL(NUSHI_HITTOSYA,'') NUSHI_HITTOSYA
              ,A.GENZON_KBN
        FROM  GABTATENARIREKI A,GABTJUKIJUSHO B
      WHERE A.KOJIN_NO  = i_NJIDO_NO
        AND A.GENZON_KBN = 0
        AND A.RIREKI_RENBAN= (SELECT MAX(RIREKI_RENBAN) FROM GABTATENARIREKI
                              WHERE KOJIN_NO =A.KOJIN_NO
                                AND GENZON_KBN = 0 AND TEKIYO_BI <= i_IKIJYUNBI )
        AND A.KOJIN_NO = B.KOJIN_NO
        AND A.HONSEKI_REN = B.JUSHO_REN
      ORDER BY 1;

  --  世帯内候補者検索
  CURSOR  CDATA_KOUHO( p_ISETAI_NO PLS_INTEGER, p_NUSHI_KBN PLS_INTEGER,p_ITEKIYO_BI PLS_INTEGER )  IS
      SELECT  1 AS KUBUN,A.TEKIYO_BI,A.KOJIN_NO,A.SETAI_NO,B.SEIBETSU, A.SHIMEI_KANJI,
              NVL(B.ZOKUGARA_CD1,0) ZOKUGARA_CD1,NVL(B.ZOKUGARA_CD2,0) ZOKUGARA_CD2,
              NVL(B.ZOKUGARA_CD3,0) ZOKUGARA_CD3,NVL(B.ZOKUGARA_CD4,0) ZOKUGARA_CD4,NVL(NUSHI_HITTOSYA,'') NUSHI_HITTOSYA
        FROM  GABTATENAKIHON A,GABTJUKIIDO B,GABTJUKIJUSHO C
      WHERE (A.KOJIN_NO < i_NJIDO_NO OR A.KOJIN_NO > i_NJIDO_NO )
          AND A.SETAI_NO = p_ISETAI_NO
          AND NVL(B.ZOKUGARA_CD1,0) = DECODE( p_NUSHI_KBN,0,NVL(B.ZOKUGARA_CD1,0),1 )
          AND B.GENZON_KBN = 0
          AND A.TEKIYO_BI <= p_ITEKIYO_BI
          AND A.KOJIN_NO = B.KOJIN_NO
          AND A.KOJIN_NO = C.KOJIN_NO
          AND B.HONSEKI_REN = C.JUSHO_REN
      UNION
      SELECT  2 AS KUBUN,A.TEKIYO_BI,A.KOJIN_NO,A.SETAI_NO,A.SEIBETSU, A.SHIMEI_KANJI,
              NVL(A.ZOKUGARA_CD1,0) ZOKUGARA_CD1,NVL(A.ZOKUGARA_CD2,0) ZOKUGARA_CD2,
              NVL(A.ZOKUGARA_CD3,0) ZOKUGARA_CD3,NVL(A.ZOKUGARA_CD4,0) ZOKUGARA_CD4,NVL(NUSHI_HITTOSYA,'') NUSHI_HITTOSYA
        FROM GABTATENARIREKI A,GABTJUKIJUSHO B
      WHERE (A.KOJIN_NO < i_NJIDO_NO OR A.KOJIN_NO > i_NJIDO_NO )
        AND A.SETAI_NO = p_ISETAI_NO
        AND A.GENZON_KBN = 0
        AND A.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) FROM GABTATENARIREKI
                                WHERE KOJIN_NO <> i_NJIDO_NO
                                  AND KOJIN_NO =A.KOJIN_NO
                                    AND TEKIYO_BI <= p_ITEKIYO_BI)
        AND NVL(A.ZOKUGARA_CD1,0) = DECODE( p_NUSHI_KBN,0,NVL(A.ZOKUGARA_CD1,0),1 )
        AND A.KOJIN_NO = B.KOJIN_NO
        AND A.HONSEKI_REN = B.JUSHO_REN
      ORDER BY 1;

  --  適用日検索
  CURSOR CDATA_TEKIYOBI IS
    SELECT A.TEKIYO_BI AS TEKIYO_BI
      FROM GABVATENAALL A
     WHERE A.KOJIN_NO = i_NJIDO_NO
       AND A.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) FROM GABVATENAALL
                               WHERE KOJIN_NO = A.KOJIN_NO
                                 AND GENZON_KBN = 1
                                 AND TEKIYO_BI  <= i_IKIJYUNBI);

  TYPE  MTZOKUGARA_CNT    IS TABLE OF NUMBER(2)     INDEX BY PLS_INTEGER;
  TYPE  MTSEIBETU_CNT     IS TABLE OF NUMBER(1)     INDEX BY PLS_INTEGER;
  TYPE  MTHITUTOUSYA_CNT  IS TABLE OF NVARCHAR2(100)     INDEX BY PLS_INTEGER;
  --  2024/09/02 ZCZL.WANGMING Update 0.3.000.002:IT_GKB_00051対応_2回目
  --TYPE  MTKOJIN_CNT       IS TABLE OF NUMBER(12)      INDEX BY PLS_INTEGER;
  TYPE  MTKOJIN_CNT       IS TABLE OF NUMBER      INDEX BY PLS_INTEGER;
  TYPE  MTKOJIN_NM_CNT    IS TABLE OF NVARCHAR2(100)      INDEX BY PLS_INTEGER;  -- GABTATENAKIHON.SHIMEI_KANJIとの整合性を取るため個人名の項目長を拡張

  IZOKUGARA   MTZOKUGARA_CNT;

  NSETAI_KOJIN_NO   MTKOJIN_CNT;
  VSETAI_HITUTOUSYA MTHITUTOUSYA_CNT;
  ISETAI_SEIBETSU   MTSEIBETU_CNT;
  ISETAI_ZOKUGARA1  MTZOKUGARA_CNT;
  ISETAI_ZOKUGARA2  MTZOKUGARA_CNT;
  ISETAI_ZOKUGARA3  MTZOKUGARA_CNT;
  ISETAI_ZOKUGARA4  MTZOKUGARA_CNT;
  ISETAI_KOHOSYA    MTSEIBETU_CNT;



  ITAISYO_CNT PLS_INTEGER;
  VSETAI_KOJIN_NM   MTKOJIN_NM_CNT;

  ISETAI_NO   PLS_INTEGER;
  ISEIBETSU   PLS_INTEGER;
  --  2024/09/02 ZCZL.WANGMING Update 0.3.000.002:IT_GKB_00051対応_2回目
  --NKOJIN_NO   NUMBER(12);
  NKOJIN_NO   NUMBER;
  VHITUTOUSYA NVARCHAR2(100);
  VKOJIN_NM   NVARCHAR2(100);  -- GABTATENAKIHON.SHIMEI_KANJIとの整合性を取るため個人名の項目長を拡張

  ITEKIYO_BI  PLS_INTEGER;
  IGENZON_KBN PLS_INTEGER;


  IZOKU1        PLS_INTEGER;
  IZOKU2        PLS_INTEGER;
  IZOKU3        PLS_INTEGER;
  IZOKU4        PLS_INTEGER;

  c_INASI       CONSTANT  REAL  :=  0;  --  世帯主
  c_ISETAINUSI  CONSTANT  REAL  :=  1;  --  世帯主
  c_ITUMA       CONSTANT  REAL  :=  2;  --  妻
  c_IOTUTO      CONSTANT  REAL  :=  3;  --  夫
  c_ICHICHI     CONSTANT  REAL  :=  4;  --  父
  c_IHAHA       CONSTANT  REAL  :=  5;  --  母
  c_IKO         CONSTANT  REAL  :=  10; --  子
  c_IOJI_2      CONSTANT  REAL  :=  83; --  叔父
  c_IOBA_2      CONSTANT  REAL  :=  84; --  叔母
  c_IOJI_3      CONSTANT  REAL  :=  81; --  伯父
  c_IOBA_3      CONSTANT  REAL  :=  82; --  伯母

  c_IKO_NO_OTUTO  CONSTANT  REAL  :=  96; --  （子の夫）
  c_IKO_NO_TUMA   CONSTANT  REAL  :=  97; --  （子の妻）
  c_IKO_NO_KO_NO_OTUTO  CONSTANT  REAL  :=  98; --  （子の子の夫）
  c_IKO_NO_KO_NO_TUMA   CONSTANT  REAL  :=  99; --  （子の子の妻）

  ------------------------------------------------------------------
  --  判定用続柄コード変換
  ------------------------------------------------------------------
  FUNCTION FUNCZOKUGARA_HENKAN(i_IZOKU IN  PLS_INTEGER) RETURN PLS_INTEGER IS
    IZOKU    PLS_INTEGER;
  BEGIN
    IF i_IZOKU BETWEEN 11 AND 29 OR i_IZOKU IN( 71,72,89 ) THEN
      IZOKU := 10;  -- 子
    ELSIF i_IZOKU BETWEEN 31 AND 39 THEN
      IZOKU := 30;  -- 兄
    ELSIF i_IZOKU BETWEEN 41 AND 49 THEN
      IZOKU := 40;  -- 弟
    ELSIF i_IZOKU BETWEEN 51 AND 59 THEN
      IZOKU := 50;  -- 姉
    ELSIF i_IZOKU BETWEEN 61 AND 69 THEN
      IZOKU := 60;  -- 妹
    ELSE
      IZOKU := i_IZOKU;
    END IF;
    RETURN IZOKU;
  END FUNCZOKUGARA_HENKAN;
  ------------------------------------------------------------------
  --  児童の続柄(１０～２９，７１，７２)チェック。
  ------------------------------------------------------------------
  FUNCTION  FUNCJIDO_ZOKU_CHECK( i_IZOKUGARA  IN  PLS_INTEGER ) RETURN  BOOLEAN  IS
  BRTN  BOOLEAN;
  BEGIN
    BRTN := FALSE;
    IF i_IZOKUGARA BETWEEN 10 AND 29 OR i_IZOKUGARA IN( 71,72,89 ) THEN
       BRTN := TRUE;
    END IF;
    RETURN( BRTN );
  END FUNCJIDO_ZOKU_CHECK;

  ------------------------------------------------------------------
  --  指定位置の続柄コードを返す。
  ------------------------------------------------------------------
  PROCEDURE PROCZOKU_SITEIICHI( i_IHANTEI_ICHI  IN  PLS_INTEGER,
                                i_IIDX          IN  PLS_INTEGER,
                                o_IZOKU1        OUT PLS_INTEGER,
                                o_IZOKU2        OUT PLS_INTEGER ) IS
  BEGIN
    IF i_IHANTEI_ICHI = 1 THEN
      o_IZOKU1  :=  ISETAI_ZOKUGARA1(i_IIDX);
      o_IZOKU2:=  ISETAI_ZOKUGARA2(i_IIDX);
    ELSIF i_IHANTEI_ICHI = 2 THEN
      o_IZOKU1  :=  ISETAI_ZOKUGARA2(i_IIDX);
      o_IZOKU2:=  ISETAI_ZOKUGARA3(i_IIDX);
    ELSIF i_IHANTEI_ICHI = 3 THEN
      o_IZOKU1  :=  ISETAI_ZOKUGARA3(i_IIDX);
      o_IZOKU2:=  ISETAI_ZOKUGARA4(i_IIDX);
    ELSIF i_IHANTEI_ICHI = 4 THEN
      o_IZOKU1  :=  ISETAI_ZOKUGARA4(i_IIDX);
      o_IZOKU2:=  0;
    END IF;
  END PROCZOKU_SITEIICHI;

  ------------------------------------------------------------------
  --  指定位置の続柄コードの判定を行い、続柄コードが一致したら個人番号を返す。
  ------------------------------------------------------------------
  FUNCTION  FUNCZOKU_CHECK( i_IHANTEI_ICHI  IN  PLS_INTEGER,
                            i_IZUKUGARA     IN  PLS_INTEGER,
                            i_ITAISYO_KBN   IN  PLS_INTEGER,
                            o_NHOGOSHA_NO    OUT NUMBER,
                            o_VHOGOSHA_NM     OUT NVARCHAR2 )  RETURN  NUMBER IS
  NHOGOSHA  NUMBER;
  VHOGOSHA_NM NVARCHAR2(100);

  BEGIN
    NHOGOSHA  :=  0;

    IF i_ITAISYO_KBN = 0 THEN
      --  指定した続柄を対象者より探す
      FOR IIDX IN 1..ITAISYO_CNT  LOOP
        PROCZOKU_SITEIICHI(i_IHANTEI_ICHI,IIDX,IZOKU1,IZOKU2);
        IF IZOKU1 = i_IZUKUGARA THEN
          NHOGOSHA  := NSETAI_KOJIN_NO(IIDX);
          VHOGOSHA_NM  := VSETAI_KOJIN_NM(IIDX);
        END IF;
        EXIT  WHEN( NHOGOSHA <> 0 );
      END LOOP;
    ELSIF i_ITAISYO_KBN = 1 THEN
      --  同一続柄対象者より指定した続柄を対象者より探す
      FOR IIDX IN 1..ITAISYO_CNT  LOOP
        IF ISETAI_KOHOSYA(IIDX) = 1 THEN  --  対象者
          PROCZOKU_SITEIICHI(i_IHANTEI_ICHI,IIDX,IZOKU1,IZOKU2);
          IF IZOKU1 = i_IZUKUGARA THEN
            NHOGOSHA  := NSETAI_KOJIN_NO(IIDX);
            VHOGOSHA_NM  := VSETAI_KOJIN_NM(IIDX);
          END IF;
        END IF;
        EXIT  WHEN( NHOGOSHA <> 0 );
      END LOOP;
    END IF;

    o_NHOGOSHA_NO := NHOGOSHA;
    o_VHOGOSHA_NM  := VHOGOSHA_NM;

    RETURN( 1 );

  END FUNCZOKU_CHECK;

  ------------------------------------------------------------------
  --  メイン処理
  ------------------------------------------------------------------
  BEGIN

    IRTNCD  := 0;

    -- 対象児童個人番号チェック
    IF NVL(i_NJIDO_NO,0) = 0 THEN
      IRTNCD  :=  9;
      RETURN( IRTNCD );
    END IF;

    -- 対象者の取得
    IRTNCD  :=  9;
    FOR CRREC_TAISYO  IN  CDATA_TAISYO  LOOP
      IRTNCD  :=  0;
      ISETAI_NO   :=  CRREC_TAISYO.SETAI_NO;
      ISEIBETSU   :=  CRREC_TAISYO.SEIBETSU;
      IZOKUGARA(1) := FUNCZOKUGARA_HENKAN( CRREC_TAISYO.ZOKUGARA_CD1 );
      IZOKUGARA(2) := FUNCZOKUGARA_HENKAN( CRREC_TAISYO.ZOKUGARA_CD2 );
      IZOKUGARA(3) := FUNCZOKUGARA_HENKAN( CRREC_TAISYO.ZOKUGARA_CD3 );
      IZOKUGARA(4) := FUNCZOKUGARA_HENKAN( CRREC_TAISYO.ZOKUGARA_CD4 );
      VHITUTOUSYA :=  CRREC_TAISYO.NUSHI_HITTOSYA;
      IGENZON_KBN :=  CRREC_TAISYO.GENZON_KBN;
      EXIT;
    END LOOP;


    IF  IRTNCD  = 9 THEN
      RETURN( IRTNCD );
    END IF;
    --現存の場合、入力の基準日
    IF IGENZON_KBN = 0 THEN
      ITEKIYO_BI := i_IKIJYUNBI;
    --非現存の場合、非現存前の適用日を取得
    ELSE
      FOR CRREC_TEKIYO IN CDATA_TEKIYOBI LOOP
        --非現存時の適用日をマイナス１する
        ITEKIYO_BI := KKAPK0020.FDATECAL(CRREC_TEKIYO.TEKIYO_BI,0,-1,0,0);
        EXIT;
      END LOOP;
    END IF;
    --  世帯員の抽出
    ITAISYO_CNT :=  0;
    NKOJIN_NO   :=  0;

    FOR CRREC_KOUHO IN  CDATA_KOUHO( ISETAI_NO,0,ITEKIYO_BI)  LOOP

      IF NKOJIN_NO <> CRREC_KOUHO.KOJIN_NO AND VHITUTOUSYA = CRREC_KOUHO.NUSHI_HITTOSYA THEN
        ITAISYO_CNT :=  ITAISYO_CNT + 1;
        NSETAI_KOJIN_NO(ITAISYO_CNT)          :=  CRREC_KOUHO.KOJIN_NO;
        VSETAI_KOJIN_NM(ITAISYO_CNT)    :=  CRREC_KOUHO.SHIMEI_KANJI;
        VSETAI_HITUTOUSYA(ITAISYO_CNT)  :=  CRREC_KOUHO.NUSHI_HITTOSYA;
        ISETAI_SEIBETSU(ITAISYO_CNT)    :=  CRREC_KOUHO.SEIBETSU;
        ISETAI_ZOKUGARA1(ITAISYO_CNT) := FUNCZOKUGARA_HENKAN( CRREC_KOUHO.ZOKUGARA_CD1 );
        ISETAI_ZOKUGARA2(ITAISYO_CNT) := FUNCZOKUGARA_HENKAN( CRREC_KOUHO.ZOKUGARA_CD2 );
        ISETAI_ZOKUGARA3(ITAISYO_CNT) := FUNCZOKUGARA_HENKAN( CRREC_KOUHO.ZOKUGARA_CD3 );
        ISETAI_ZOKUGARA4(ITAISYO_CNT) := FUNCZOKUGARA_HENKAN( CRREC_KOUHO.ZOKUGARA_CD4 );

        NKOJIN_NO :=  CRREC_KOUHO.KOJIN_NO;

      END IF;
    END LOOP;

    --  対象者の１～４階層目の続柄判定
  NKOJIN_NO :=  0;

    IF IZOKUGARA(4) <> 0 THEN       --  4階層目まで使用
      IF FUNCJIDO_ZOKU_CHECK( IZOKUGARA(1) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(2) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(3) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(4) ) THEN   --  子の子の子の子の場合
        --  １,２,３階層の続柄と同じ続柄のデータを候補者より抽出
        FOR IIDX IN 1..ITAISYO_CNT  LOOP
          PROCZOKU_SITEIICHI(1,IIDX,IZOKU1,IZOKU2);
          PROCZOKU_SITEIICHI(3,IIDX,IZOKU3,IZOKU4);
          ISETAI_KOHOSYA(IIDX)  := 0;
          IF IZOKUGARA(1) = IZOKU1 AND IZOKUGARA(2) = IZOKU2 AND IZOKUGARA(3) = IZOKU3 THEN
            ISETAI_KOHOSYA(IIDX)  := 1;
          END IF;
        END LOOP;
        RTNRTN :=  FUNCZOKU_CHECK( 4,c_IOTUTO,1, NKOJIN_NO,VKOJIN_NM );
        IF NKOJIN_NO = 0 THEN
          RTNRTN := FUNCZOKU_CHECK( 4,c_IKO_NO_OTUTO,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          RTNRTN := FUNCZOKU_CHECK( 4,c_INASI,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          RTNRTN := FUNCZOKU_CHECK( 4,c_ITUMA,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          RTNRTN :=  FUNCZOKU_CHECK( 4,c_IKO_NO_TUMA,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          --  世帯主を探す
          FOR CRREC_KOUHO IN  CDATA_KOUHO( ISETAI_NO,1,ITEKIYO_BI )  LOOP
              IF NKOJIN_NO <> CRREC_KOUHO.KOJIN_NO AND VHITUTOUSYA = CRREC_KOUHO.NUSHI_HITTOSYA THEN
                 NKOJIN_NO          :=  CRREC_KOUHO.KOJIN_NO;
                 VKOJIN_NM  :=  CRREC_KOUHO.SHIMEI_KANJI;
              END IF;
          END LOOP;
        END IF;
      END IF;

    ELSIF IZOKUGARA(3) <> 0 THEN    --  3階層目まで使用
      IF FUNCJIDO_ZOKU_CHECK( IZOKUGARA(1) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(2) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(3) ) THEN    --  子の子の子の場合
        --  １階層の続柄と同じ続柄のデータを候補者より抽出
        FOR IIDX IN 1..ITAISYO_CNT  LOOP
          PROCZOKU_SITEIICHI(1,IIDX,IZOKU1,IZOKU2);
          ISETAI_KOHOSYA(IIDX)  := 0;
          IF IZOKUGARA(1) = IZOKU1 AND IZOKUGARA(2) = IZOKU2 THEN
            ISETAI_KOHOSYA(IIDX)  := 1;
          END IF;
        END LOOP;
        RTNRTN :=  FUNCZOKU_CHECK( 3,c_IOTUTO,1, NKOJIN_NO,VKOJIN_NM );
        IF NKOJIN_NO = 0 THEN
          RTNRTN :=  FUNCZOKU_CHECK( 3,c_IKO_NO_OTUTO,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          RTNRTN :=  FUNCZOKU_CHECK( 3,c_INASI,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          RTNRTN :=  FUNCZOKU_CHECK( 3,c_ITUMA,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          RTNRTN :=  FUNCZOKU_CHECK( 3,c_IKO_NO_TUMA,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          --  世帯主を探す
          FOR CRREC_KOUHO IN  CDATA_KOUHO( ISETAI_NO,1,ITEKIYO_BI )  LOOP
              IF NKOJIN_NO <> CRREC_KOUHO.KOJIN_NO AND VHITUTOUSYA = CRREC_KOUHO.NUSHI_HITTOSYA THEN
                 NKOJIN_NO          :=  CRREC_KOUHO.KOJIN_NO;
                 VKOJIN_NM  :=  CRREC_KOUHO.SHIMEI_KANJI;
              END IF;
          END LOOP;
        END IF;
      END IF;
    ELSIF IZOKUGARA(2) <> 0 THEN    --  2階層目まで使用

      IF FUNCJIDO_ZOKU_CHECK( IZOKUGARA(1) ) AND
         FUNCJIDO_ZOKU_CHECK( IZOKUGARA(2) ) THEN   --  子の子の場合
        --  １階層の続柄と同じ続柄のデータを候補者より抽出
        FOR IIDX IN 1..ITAISYO_CNT  LOOP
          PROCZOKU_SITEIICHI(1,IIDX,IZOKU1,IZOKU2);
          ISETAI_KOHOSYA(IIDX)  := 0;
          IF IZOKUGARA(1) = IZOKU1 THEN
            ISETAI_KOHOSYA(IIDX)  := 1;
          END IF;
        END LOOP;
        RTNRTN :=  FUNCZOKU_CHECK( 2,c_IOTUTO,1, NKOJIN_NO,VKOJIN_NM );
        IF NKOJIN_NO = 0 THEN
          RTNRTN :=  FUNCZOKU_CHECK( 2,c_IKO_NO_OTUTO,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          RTNRTN :=  FUNCZOKU_CHECK( 2,c_INASI,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          RTNRTN :=  FUNCZOKU_CHECK( 2,c_ITUMA,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          RTNRTN :=  FUNCZOKU_CHECK( 2,c_IKO_NO_TUMA,1, NKOJIN_NO,VKOJIN_NM );
        END IF;
        -- 該当する対象者が存在しない場合は、世帯主を保護者とする
        IF NKOJIN_NO = 0 THEN
          --  世帯主を探す
          FOR CRREC_KOUHO IN  CDATA_KOUHO( ISETAI_NO,1,ITEKIYO_BI )  LOOP
              IF NKOJIN_NO <> CRREC_KOUHO.KOJIN_NO AND VHITUTOUSYA = CRREC_KOUHO.NUSHI_HITTOSYA THEN
                 NKOJIN_NO  :=  CRREC_KOUHO.KOJIN_NO;
                 VKOJIN_NM  :=  CRREC_KOUHO.SHIMEI_KANJI;
              END IF;
          END LOOP;
        END IF;
      END IF;
    ELSIF IZOKUGARA(1) <> 0 THEN    --  1階層目まで使用
      IF FUNCJIDO_ZOKU_CHECK( IZOKUGARA(1) ) THEN    --  子の場合
        --  夫を探す
        RTNRTN :=  FUNCZOKU_CHECK( 1,c_IOTUTO,0, NKOJIN_NO,VKOJIN_NM );
        IF NKOJIN_NO = 0 THEN
          --  （子の夫）を探す
          RTNRTN :=  FUNCZOKU_CHECK( 1,c_IKO_NO_OTUTO,0, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          --  世帯主を探す
          RTNRTN :=  FUNCZOKU_CHECK( 1,c_ISETAINUSI,0, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          --  妻を探す
          RTNRTN :=  FUNCZOKU_CHECK( 1,c_ITUMA,0, NKOJIN_NO,VKOJIN_NM );
        END IF;
        IF NKOJIN_NO = 0 THEN
          --  （子の妻）を探す
          RTNRTN :=  FUNCZOKU_CHECK( 1,c_IKO_NO_TUMA,0, NKOJIN_NO,VKOJIN_NM );
        END IF;
      END IF;
    END IF;

    IF  NKOJIN_NO <> 0 THEN
      o_NHOGOSHA_NO :=  NKOJIN_NO;
      o_VHOGOSHA_NM :=  VKOJIN_NM;
    ELSE
      o_NHOGOSHA_NO :=  0;
      o_VHOGOSHA_NM := '';
      IRTNCD  :=  1;
    END IF;
    RETURN( IRTNCD );

  END FHOGOSHA2;

-- 2024/11/11 BOK.GoHou Add start 1.0.400.000:標準入出力機能開発(出力分)
--------------------------------------------------------
--  名称          : 仮学校コード・名称取得
--  機能概要      : 引数による分岐に基づきOUTパラメータ(仮学校コード・名称)へ値を設定する。
--  パラメータ    : i_NTYUGAKO_NYUGAKU_BI             中学校_入学年月日
--                : i_NTYUGAKO_TENNYUGAKU_BI          中学校_転入学年月日
--                : i_NKARIGAKO_S_FLG                 仮学校フラグ(小学校)
--                : i_NKARIGAKO_T_FLG                 仮学校フラグ(中学校)
--                : i_VMONBUKAGAKUSHO_GAKOCODE_S      文部科学省学校コード(小学校)
--                : i_VMONBUKAGAKUSHO_GAKOCODE_T      文部科学省学校コード(中学校)
--                : i_VSGAKONAME                      小学校名
--                : i_VTGAKONAME                      中学校名
--                : o_VKARIGAKOCODE                   仮学校コード
--                : o_VKARIGAKONAME                   仮学校名
--  モジュール区分: PUBLIC(外部関数)
--  戻り値        : 引数をNUMBER型にした数字データ
--  バージョン    : Ver 1.0.400.000
--  作成者／作成日: BOK GoHou   2024/11/11
--------------------------------------------------------
    FUNCTION FGETKARIGAKKO(i_NTYUGAKO_NYUGAKU_BI        IN  NUMBER,
                           i_NTYUGAKO_TENNYUGAKU_BI     IN  NUMBER,
                           i_NKARIGAKO_S_FLG            IN  NUMBER,
                           i_NKARIGAKO_T_FLG            IN  NUMBER,
                           i_VMONBUKAGAKUSHO_GAKOCODE_S IN  NVARCHAR2,
                           i_VMONBUKAGAKUSHO_GAKOCODE_T IN  NVARCHAR2,
                           i_VSGAKONAME                 IN  NVARCHAR2,
                           i_VTGAKONAME                 IN  NVARCHAR2,
                           o_VKARIGAKOCODE              OUT NVARCHAR2,
                           o_VKARIGAKONAME              OUT NVARCHAR2) RETURN NUMBER
    IS
    BEGIN
      -- 引数.中学校_入学年月日≠0、または引数.中学校_転入学年月日≠0の場合、かつ引数.仮学校フラグ(中学校) ＝ 1 の場合
      IF (i_NTYUGAKO_NYUGAKU_BI <> 0 OR i_NTYUGAKO_TENNYUGAKU_BI <> 0) AND i_NKARIGAKO_T_FLG = 1 THEN
        o_VKARIGAKOCODE := i_VMONBUKAGAKUSHO_GAKOCODE_T;
        o_VKARIGAKONAME := i_VTGAKONAME;
        RETURN 0;
      ELSIF i_NTYUGAKO_NYUGAKU_BI = 0 AND i_NTYUGAKO_TENNYUGAKU_BI = 0 AND i_NKARIGAKO_S_FLG = 1 THEN
      -- 引数.中学校_入学年月日=0、かつ引数.中学校_転入学年月日=0、かつ引数.仮学校フラグ(小学校) ＝ 1 の場合
        o_VKARIGAKOCODE := i_VMONBUKAGAKUSHO_GAKOCODE_S;
        o_VKARIGAKONAME := i_VSGAKONAME;
        RETURN 0;
      ELSE
      -- 上記以外の場合
        o_VKARIGAKOCODE := NULL;
        o_VKARIGAKONAME := NULL;
        RETURN 0;
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        RETURN 1;
    END FGETKARIGAKKO;
-- 2024/11/11 BOK.GoHou Add end
-- 2025/06/05 BOK.GoHou Add start 1.0.400.000:標準入出力機能開発(出力分)
    --------------------------------------------------------
    --  名称          : 学校区分コード・学校等コード取得
    --  機能概要      : 引数として渡された文部科学省学校コードから学校区分コードと学校等コードを取得する。
    --  パラメータ    : i_VMGAKKO_CD             文部科学省学校コード
    --                : o_NGAKOUKUBUN           学校区分コード
    --                : o_NGAKOUNADO_CD         学校等コード
    --  モジュール区分: PUBLIC(外部関数)
    --  戻り値        : 引数をNUMBER型にした数字データ（正常:0、異常:1）
    --  バージョン    : Ver 1.0.400.000
    --  作成者／作成日: BOK GoHou   2025/06/05
    --------------------------------------------------------
    FUNCTION FGETGAKKO_KBN_CD(i_VMGAKKO_CD     IN  NVARCHAR2,
                           o_NGAKOUKUBUN      OUT  NUMBER,
                           o_NGAKOUNADO_CD   OUT NUMBER) RETURN  NUMBER
    IS
    ------------------------------------------------------------------------------
    --  変数宣言
      sGAKKOUSYURUI   NVARCHAR2(10);    --学校種
      sSECHIKBN       NVARCHAR2(10);    --設置区分
      nGAKOUNADO_CD   NUMBER;           --学校等コード
      nKUIKIGAI_FLG   NUMBER;           --区域外フラグ
    ------------------------------------------------------------------------------
    BEGIN
        --変数のクリア
        nGAKOUNADO_CD := '';
        sGAKKOUSYURUI := SUBSTR(TRIM(i_VMGAKKO_CD),1,2);
        sSECHIKBN := SUBSTR(TRIM(i_VMGAKKO_CD),5,1);
        
        --区域外学校かの判定
        SELECT COUNT(*) INTO nKUIKIGAI_FLG
        FROM   GKBTKUIKIGAI
        WHERE  MGAKKO_CD = i_VMGAKKO_CD;
        --区域外学校以外の場合
          IF nKUIKIGAI_FLG = 0 THEN
            BEGIN
              IF sGAKKOUSYURUI = 'B1' AND sSECHIKBN = '2' THEN
                  --小学校(公立)の場合
                  SELECT SYOGAKO_CD INTO nGAKOUNADO_CD
                  FROM   GKBTSHOGAKKO
                  WHERE  MGAKKO_CD = i_VMGAKKO_CD
                  AND KAIKO_BI = (SELECT MAX(KAIKO_BI) FROM GKBTSHOGAKKO WHERE  MGAKKO_CD = i_VMGAKKO_CD);
                  o_NGAKOUKUBUN := 1;
              ELSIF sGAKKOUSYURUI = 'C1' AND sSECHIKBN = '2' THEN
                  --中学校(公立)の場合
                  SELECT TYUGAKO_CD INTO nGAKOUNADO_CD
                  FROM   GKBTCHUGAKKO
                  WHERE  MGAKKO_CD = i_VMGAKKO_CD
                  AND KAIKO_BI = (SELECT MAX(KAIKO_BI) FROM GKBTCHUGAKKO WHERE  MGAKKO_CD = i_VMGAKKO_CD);
                  o_NGAKOUKUBUN := 2;
              ELSIF sGAKKOUSYURUI = 'E1' THEN
                  --盲聾養護学校の場合
                  SELECT YOGOGAKO_CD INTO nGAKOUNADO_CD
                  FROM   GKBTYOGOGAKKO
                  WHERE  MGAKKO_CD = i_VMGAKKO_CD
                  AND KAIKO_BI = (SELECT MAX(KAIKO_BI) FROM GKBTYOGOGAKKO WHERE  MGAKKO_CD = i_VMGAKKO_CD);
                  o_NGAKOUKUBUN := 3;
              ELSIF sSECHIKBN = '1' OR sSECHIKBN = '3' THEN
                  --国・私立学校の場合
                  SELECT KUNISHIRITSUGAKKO_CD INTO nGAKOUNADO_CD
                  FROM   GKBTKUNISIRITSUGAKKO
                  WHERE  MGAKKO_CD = i_VMGAKKO_CD
                  AND KAIKO_BI = (SELECT MAX(KAIKO_BI) FROM GKBTKUNISIRITSUGAKKO WHERE  MGAKKO_CD = i_VMGAKKO_CD);
                  o_NGAKOUKUBUN := 5;
              ELSE
                  o_NGAKOUKUBUN := 0;
              END IF;
            EXCEPTION
              WHEN OTHERS THEN
                RETURN 1;
            END;
          ELSE
            BEGIN
              --区域外学校の場合
              SELECT KUIKIGAI_CD INTO nGAKOUNADO_CD
              FROM   GKBTKUIKIGAI
              WHERE  MGAKKO_CD = i_VMGAKKO_CD
              AND KAIKO_BI = (SELECT MAX(KAIKO_BI) FROM GKBTKUIKIGAI WHERE  MGAKKO_CD = i_VMGAKKO_CD);
              o_NGAKOUKUBUN := 4;
            EXCEPTION
              WHEN OTHERS THEN
                BEGIN
                  IF sGAKKOUSYURUI = 'B1' AND sSECHIKBN = '2' THEN
                      --小学校(公立)の場合
                      SELECT SYOGAKO_CD INTO nGAKOUNADO_CD
                      FROM   GKBTSHOGAKKO
                      WHERE  MGAKKO_CD = i_VMGAKKO_CD
                      AND KAIKO_BI = (SELECT MAX(KAIKO_BI) FROM GKBTSHOGAKKO WHERE  MGAKKO_CD = i_VMGAKKO_CD);
                      o_NGAKOUKUBUN := 1;
                  ELSIF sGAKKOUSYURUI = 'C1' AND sSECHIKBN = '2' THEN
                      --中学校(公立)の場合
                      SELECT TYUGAKO_CD INTO nGAKOUNADO_CD
                      FROM   GKBTCHUGAKKO
                      WHERE  MGAKKO_CD = i_VMGAKKO_CD
                      AND KAIKO_BI = (SELECT MAX(KAIKO_BI) FROM GKBTCHUGAKKO WHERE  MGAKKO_CD = i_VMGAKKO_CD);
                      o_NGAKOUKUBUN := 2;
                  ELSIF sGAKKOUSYURUI = 'E1' THEN
                      --特別支援学校の場合
                      SELECT YOGOGAKO_CD INTO nGAKOUNADO_CD
                      FROM   GKBTYOGOGAKKO
                      WHERE  MGAKKO_CD = i_VMGAKKO_CD
                      AND KAIKO_BI = (SELECT MAX(KAIKO_BI) FROM GKBTYOGOGAKKO WHERE  MGAKKO_CD = i_VMGAKKO_CD);
                      o_NGAKOUKUBUN := 3;
                  ELSIF sSECHIKBN = '1' OR sSECHIKBN = '3' THEN
                      --国・私立学校の場合
                      SELECT KUNISHIRITSUGAKKO_CD INTO nGAKOUNADO_CD
                      FROM   GKBTKUNISIRITSUGAKKO
                      WHERE  MGAKKO_CD = i_VMGAKKO_CD
                      AND KAIKO_BI = (SELECT MAX(KAIKO_BI) FROM GKBTYOGOGAKKO WHERE  MGAKKO_CD = i_VMGAKKO_CD);
                      o_NGAKOUKUBUN := 5;
                  ELSE
                      o_NGAKOUKUBUN := 0;
                  END IF;
                EXCEPTION
                  WHEN OTHERS THEN
                    RETURN 1;
                END;
            END;
          END IF;
        o_NGAKOUNADO_CD := nGAKOUNADO_CD;
        RETURN 0;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
          RETURN 1;
        WHEN OTHERS THEN
          RETURN 1;
    END FGETGAKKO_KBN_CD;
-- 2025/06/05 BOK.GoHou Add end

END GKBPK00010;
/
