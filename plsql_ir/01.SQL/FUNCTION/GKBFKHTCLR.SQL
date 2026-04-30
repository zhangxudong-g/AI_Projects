CREATE OR REPLACE FUNCTION GKBFKHTCLR (i_NHAITA_KBN_CD IN  NUMBER       --排他制御区分コード（1:即時　2:一括）
--1.0.000.000-02.02-02.02
                                        ,i_VHAITA_KEY    IN  NVARCHAR2    --排他制御キー
                                        ) RETURN INTEGER
-----------------------------------------------------------------------
--  業務名        GKB（教育）
--  PG 名         GKBFKHTCLR
--  名称          排他制御クリア
--  処理概要      排他制御の解除を行う。
--  引数          i_NHAITA_KBN_CD         排他制御区分コード
--                i_VHAITA_KEY            排他制御キー
--  戻り値        処理結果区分（0：正常終了、　9：異常終了）
--  作成者        ZCZL.GUANHONG
--  作成日        2024/06/03
--  VERSION       0.3.000.000
----------------------------------------------------------------------- 
IS
  -- 戻り値
  c_NRTN_NORMAL     CONSTANT  NUMBER  := 0;        -- 正常
  c_NRTN_ABEND      CONSTANT  NUMBER  := 9;        -- 異常
  -- ローカル変数
  NRTN              PLS_INTEGER  :=  0 ;      -- 戻り値
  -- 自律型トランザクション
  PRAGMA            AUTONOMOUS_TRANSACTION;  -- バッチからも呼ぶため
-----------------------------------------------------------------------
--  2-3.引数のチェック                                             
-----------------------------------------------------------------------
FUNCTION FUNCPCHK RETURN NUMBER IS
BEGIN

  -- ①引数.排他制御区分コードがNULL、または1～2以外の場合
  IF i_NHAITA_KBN_CD IS NULL OR i_NHAITA_KBN_CD NOT IN (1,2) THEN
    RETURN c_NRTN_ABEND;
  END IF;

  -- ②引数.排他制御キーがNULLの場合
  IF i_VHAITA_KEY IS NULL THEN
    RETURN c_NRTN_ABEND;
  END IF;

  RETURN c_NRTN_NORMAL;

END FUNCPCHK;
-----------------------------------------------------------------------
--  2-4.排他解除                                               
-----------------------------------------------------------------------
FUNCTION FUNCHAITACLR RETURN NUMBER IS
  NRTN            PLS_INTEGER;      -- 戻り値
BEGIN
  --初期化
  NRTN := c_NRTN_NORMAL;
    
  BEGIN
    DELETE FROM GKBTHAITA
     WHERE HAITA_KBN_CD = i_NHAITA_KBN_CD
       AND HAITA_KEY    = i_VHAITA_KEY;
  EXCEPTION
    WHEN OTHERS THEN
      -- 異常
      NRTN := c_NRTN_ABEND;
  END;

  RETURN ( NRTN );
END FUNCHAITACLR;
-----------------------------------------------------------------------
--  メイン処理                                                       --
-----------------------------------------------------------------------
BEGIN
  -- 1.排他制御テーブルをロックする。
  LOCK TABLE GKBTHAITA IN EXCLUSIVE MODE;

  -- 2.変数のクリア
  NRTN := c_NRTN_NORMAL;

  -- 3.引数のチェック
  NRTN := FUNCPCHK;

  -- 4.排他解除
  IF NRTN = c_NRTN_NORMAL THEN
    NRTN := FUNCHAITACLR;
  END IF;

  -- 5.終了処理
  IF NRTN = c_NRTN_NORMAL THEN
    COMMIT;
  ELSE
    ROLLBACK;
  END IF;

  RETURN NRTN;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RETURN c_NRTN_ABEND;
END GKBFKHTCLR;
/
