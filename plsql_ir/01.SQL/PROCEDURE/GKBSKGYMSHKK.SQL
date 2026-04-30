CREATE OR REPLACE PROCEDURE          GKBSKGYMSHKK(
--1.0.000.000-02.02-02.02
                                   i_NKOJIN_NO      IN NUMBER,     --個人番号
                                   i_NKIJYUN_BI     IN NUMBER,     --基準日
                                   o_NSHIKAKU       OUT NUMBER,    -- 1.資格
                                   o_OUT2           OUT NVARCHAR2, -- 2.
                                   o_OUT3           OUT NVARCHAR2, -- 3.
                                   o_OUT4           OUT NVARCHAR2, -- 4.
                                   o_OUT5           OUT NVARCHAR2, -- 5.
                                   o_OUT6           OUT NVARCHAR2, -- 6.
                                   o_OUT7           OUT NVARCHAR2, -- 7.
                                   o_OUT8           OUT NVARCHAR2, -- 8.
                                   o_OUT9           OUT NVARCHAR2, -- 9.
                                   o_NRTN           OUT NUMBER)    --10.リターン値
--------------------------------------------------------------------------
--  業務名        GKB（教育）
--  PG 名         GKBSKGYMSHKK
--  名称          資格情報取得（共通）
--  処理概要      指定された個人の基準日時点の資格状況を取得
--                リターン値（0：正常　以外：異常）
--  作成者        ZCZL.LIKEWEN
--  作成日        2024/01/06
--  Version       0.2.000.000
--------------------------------------------------------------------------
IS
--カーソル定義
--学齢簿
CURSOR CGAKUREIBO IS
      SELECT A.* FROM GKBTGAKUREIBO A
     WHERE ( A.KOJIN_NO = i_NKOJIN_NO OR A.HOGOSYA_KOJIN_NO = i_NKOJIN_NO)
       ORDER BY A.KOJIN_NO,A.RIREKI_RENBAN DESC;

--成人式対象者
CURSOR CSEIJIN IS
      SELECT A.* FROM GKBTSEIJINSHA A
       WHERE A.KOJIN_CD = i_NKOJIN_NO
    ORDER BY A.NENDO DESC;

--ワーク変数
  RGAKUREIBO  GKBTGAKUREIBO%ROWTYPE;
  RSEIJIN     GKBTSEIJINSHA%ROWTYPE;

  INENDO            PLS_INTEGER := 0;
  ITSUKI            PLS_INTEGER := 0;
  NDOTEIMOTO        NUMBER := 0;
  IRTN              NUMBER;

--------------------------------------------------------------------------
--    資格有無検索
--------------------------------------------------------------------------
FUNCTION FUNCMAIN RETURN NUMBER IS
  NRTN NUMBER;
  ICOUNT NUMBER;
  IGEN_NENGAPI NUMBER;
  c_EXIST  CONSTANT REAL := 1;
  c_EXISTARI  CONSTANT REAL := 2;

BEGIN
  NRTN := 0;
  ICOUNT := 0;

  --児童、保護者で使っているか
  FOR CRGAKUREIBO IN CGAKUREIBO LOOP
    ICOUNT := ICOUNT + 1;
      IF CRGAKUREIBO.GEN_NENGAPI = 0 THEN
         IGEN_NENGAPI := 99999999;
      ELSE
         IGEN_NENGAPI := CRGAKUREIBO.GEN_NENGAPI;
      END IF;

      IF i_NKIJYUN_BI BETWEEN CRGAKUREIBO.ZO_NENGAPI AND IGEN_NENGAPI THEN
         NRTN := c_EXISTARI;
      ELSE
         NRTN := c_EXIST;
      END IF;
      EXIT;
  END LOOP;

  RETURN NRTN;

END FUNCMAIN;
--------------------------------------------------------------------------
--    日付の編集
--------------------------------------------------------------------------
FUNCTION FUNCDAYEDIT( i_NSEIREKI IN NUMBER ) RETURN NVARCHAR2 IS
  VEDIT_DAY     NVARCHAR2(9);
  BRTN          BOOLEAN;
  --FDAYEDIT用変数
  IWAREKIHIZUKE   PLS_INTEGER := 0;
  ISEIREKIHIZUKE  PLS_INTEGER := i_NSEIREKI;
  VEDIT_GYYMMDD1  NVARCHAR2(9);
  VEDIT_GYYMMDD2  NVARCHAR2(9);
  VEDIT_GYYMMDD3  NVARCHAR2(11);
  VKJ_GENGO       NVARCHAR2(2);
  VKG_GENGO       NVARCHAR2(1);
  IWAREKI_YY      PLS_INTEGER;
  ISEIREKI_YYYY   PLS_INTEGER;
  IWAREKI_GYYMM   PLS_INTEGER;
  IMM             PLS_INTEGER;
  IDD             PLS_INTEGER;
  IWAREKIHIZUKE2  PLS_INTEGER;
  ISEIREKIHIZUKE2 PLS_INTEGER;
BEGIN
  BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                               ISEIREKIHIZUKE,
                               VEDIT_GYYMMDD1,
                               VEDIT_GYYMMDD2,
                               VEDIT_GYYMMDD3,
                               VKJ_GENGO,
                               VKG_GENGO,
                               IWAREKI_YY,
                               ISEIREKI_YYYY,
                               IWAREKI_GYYMM,
                               IMM,
                               IDD,
                               IWAREKIHIZUKE2,
                               ISEIREKIHIZUKE2 );
  IF BRTN THEN
    VEDIT_DAY := IMM;
  ELSE
    VEDIT_DAY := '';
  END IF;

  RETURN( VEDIT_DAY );
END FUNCDAYEDIT;
--------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  処理概要    同定元個人番号取得
--  引数        i_NKOJIN_NO     個人番号
--  戻り値      同定元個人番号（存在しない場合は０とする）
--------------------------------------------------------------------------------
  FUNCTION FUNC_DOTEIMOTO_GET ( i_NKOJIN_NO   IN  NUMBER
                              ) RETURN NUMBER IS
    NRTN                NUMBER := 0;
  BEGIN
    SELECT KOJIN_NO
      INTO NRTN
      FROM GABTATENAKIHON
     WHERE JUFUKU_KOJIN_NO  = i_NKOJIN_NO;

    RETURN(NRTN);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN(0);
    WHEN OTHERS THEN
      RETURN(-1);
  END FUNC_DOTEIMOTO_GET;

--------------------------------------------------------------------------
-- ＭＡＩＮ
--------------------------------------------------------------------------
BEGIN
--初期値のセット--
  o_NSHIKAKU       := 9;
  o_OUT2     := '';
  o_OUT3   := '';
  o_OUT4   := '';
  o_OUT5   := '';
  o_OUT6         := '';
  o_OUT7         := '';
  o_OUT8         := '';
  o_OUT9         := '';
  o_NRTN           := 0;
  IRTN     :=0;

  --判定日の年度取得
  INENDO := KKAPK0020.FDAYNENDO(i_NKIJYUN_BI, 0);
  ITSUKI := FUNCDAYEDIT(i_NKIJYUN_BI);

  IRTN := FUNCMAIN;

  IF IRTN = 0 THEN
  --同定元の個人番号を取得
    NDOTEIMOTO := FUNC_DOTEIMOTO_GET(i_NKOJIN_NO);
    IF NDOTEIMOTO > 0 THEN
       IRTN := FUNCMAIN;
    ELSIF NDOTEIMOTO = -1 THEN
       IRTN := 9;
    END IF;
  END IF;

  IF IRTN = 1 THEN
    o_NSHIKAKU := 1;  -- 現在資格なし
  ELSIF IRTN = 2 THEN
    o_NSHIKAKU := 2;  -- 資格あり
  ELSIF IRTN = 9 THEN
    o_NSHIKAKU := 9;  -- 異常
  ELSIF IRTN = 0 THEN
    o_NSHIKAKU := 0;
  END IF;


EXCEPTION
  WHEN OTHERS THEN
    o_NRTN := 9;
END GKBSKGYMSHKK;
/
