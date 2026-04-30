CREATE OR REPLACE FUNCTION GKBFKHTSET (i_NHAITA_KBN_CD         IN  NUMBER       --排他制御区分コード（1:即時　2:一括  3:校外活動・修学旅行　4:職場実習・交流及び共同学習）
--1.0.000.000-02.02-02.02
                                        ,i_VHAITA_KEY            IN  NVARCHAR2    --排他制御キー
                                        ,i_VHAITA_TAISHOSHA_MEI  IN  NVARCHAR2    --排他制御対象者
                                        ,i_NSHORI_YMD            IN  NUMBER       --処理開始日
                                        ,i_NSYS_SHOKUINKOJIN_NO  IN  NVARCHAR2    --職員宛名番号
                                        ,i_VSYS_TANMATSU_NO      IN  NVARCHAR2    --端末番号
                                        ,i_NSHORI_HMS            IN  NUMBER       --処理時間
                                        ) RETURN INTEGER
-----------------------------------------------------------------------
--  業務名        GKB（教育）
--  PG 名         GKBFKHTSET
--  名称          排他制御セット
--  処理概要      排他チェックおよび排他セットを行う。
--  引数          i_NHAITA_KBN_CD         排他制御区分コード（1:即時　2:一括）
--                i_VHAITA_KEY            排他制御キー
--                i_VHAITA_TAISHOSHA_MEI  排他制御対象者
--                i_NSHORI_YMD            処理開始日
--                i_NSYS_SHOKUINKOJIN_NO  職員宛名番号
--                i_VSYS_TANMATSU_NO      端末番号
--                i_NSYS_JIKAN            処理時間
--  戻り値        処理結果区分（0：正常終了、　1：更新中、　9：異常終了）
--  作成者        ZCZL.GUANHONG
--  作成日        2024/06/03
--  VERSION       0.3.000.000
-----------------------------------------------------------------------
IS
  -- 戻り値
  c_NRTN_NORMAL     CONSTANT  NUMBER  := 0;        -- 正常
  c_NRTN_HAITA      CONSTANT  NUMBER  := 1;        -- 排他中
  c_NRTN_ABEND      CONSTANT  NUMBER  := 9;        -- 異常
  -- ローカル変数
  NRTN              PLS_INTEGER  :=  0 ;           -- 戻り値
  -- 自律型トランザクション
  PRAGMA            AUTONOMOUS_TRANSACTION;        -- バッチからも呼ぶため
-----------------------------------------------------------------------
--  3.引数のチェック                                                 --
-----------------------------------------------------------------------
FUNCTION FUNCPCHK RETURN NUMBER IS
BEGIN

  -- ①引数.排他制御区分コードがNULL、または1、2以外の場合
  IF i_NHAITA_KBN_CD IS NULL OR i_NHAITA_KBN_CD NOT IN (1,2) THEN
    RETURN c_NRTN_ABEND;
  END IF;

  -- ②引数.排他制御キーがNULLの場合
  IF i_VHAITA_KEY IS NULL THEN
    RETURN c_NRTN_ABEND;
  END IF;

  -- ③引数.排他制御対象者がNULLの場合
  IF i_VHAITA_TAISHOSHA_MEI IS NULL THEN
    RETURN c_NRTN_ABEND;
  END IF;

  -- ④引数.処理開始日がNULLの場合
  IF i_NSHORI_YMD IS NULL THEN
    RETURN c_NRTN_ABEND;
  END IF;

  -- ⑤引数.職員宛名番号がNULLの場合
  IF i_NSYS_SHOKUINKOJIN_NO IS NULL THEN
    RETURN c_NRTN_ABEND;
  END IF;

  -- ⑥引数.端末番号がNULLの場合
  IF i_VSYS_TANMATSU_NO IS NULL THEN
    RETURN c_NRTN_ABEND;
  END IF;

  -- ⑦引数.処理時間がNULLの場合
  IF i_NSHORI_HMS IS NULL THEN
    RETURN c_NRTN_ABEND;
  END IF;

  RETURN c_NRTN_NORMAL;

END FUNCPCHK;
------------------------------------------------------------------------
--  4.排他チェック                                                    --
------------------------------------------------------------------------
FUNCTION FUNCHAITACHK RETURN NUMBER IS
  NRTN            PLS_INTEGER;      -- 戻り値
  NCNT            NUMBER;           -- カウント
BEGIN
  --初期化
  NRTN := c_NRTN_NORMAL;
  
  IF i_NHAITA_KBN_CD = 2 THEN    
    -- 排他制御　検索
    -- 条件：なし
    --排他制御テーブルに、以下のいずれかに当てはまるデータが存在した場合、変数.戻り値に1をセットし
    BEGIN
      SELECT COUNT(*) INTO NCNT
        FROM GKBTHAITA;

      IF NCNT > 0 THEN
        NRTN := c_NRTN_HAITA;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        -- 異常
        NRTN := c_NRTN_ABEND;
    END;

  -- 排他制御区分により処理判定
  ELSIF i_NHAITA_KBN_CD = 1 THEN    
    -- 排他制御　検索
    -- 条件：排他制御区分コードが2の場合
    -- 条件：排他制御区分コードが1、かつ排他制御キーが引数.排他制御キーと一致する場合
    BEGIN
      SELECT COUNT(*) INTO NCNT
        FROM GKBTHAITA
       WHERE HAITA_KBN_CD = 2
          OR ( HAITA_KBN_CD = 1 AND HAITA_KEY = i_VHAITA_KEY );

      IF NCNT > 0 THEN
        NRTN := c_NRTN_HAITA;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        -- 異常
        NRTN := c_NRTN_ABEND;
    END;
  END IF;
  RETURN ( NRTN );

END FUNCHAITACHK;
------------------------------------------------------------------------------
--  5.排他制御                                                          --
-----------------------------------------------------------------------------
FUNCTION FUNCHAITASET RETURN NUMBER IS
  NRTN            PLS_INTEGER;      -- 戻り値
BEGIN
  --初期化
  NRTN := c_NRTN_NORMAL;

  -- 5-1.排他制御テーブルにデータを追加する。
  BEGIN
    INSERT INTO GKBTHAITA VALUES (i_NHAITA_KBN_CD          --排他制御区分コード
                                  ,i_VHAITA_KEY            --排他制御キー
                                  ,i_VHAITA_TAISHOSHA_MEI  --排他制御対象者
                                  ,i_NSHORI_YMD            --処理開始日
                                  ,i_NSHORI_HMS            --処理時間
                                  ,i_NSYS_SHOKUINKOJIN_NO  --職員宛名番号
                                  ,i_VSYS_TANMATSU_NO      --端末番号
                                  ,0                       --処理端末番号枝番
                                  ,i_NSHORI_YMD            --作成日
                                  ,i_NSHORI_YMD            --更新日
                                  ,i_NSHORI_HMS            --処理時間
                                  ,i_NSYS_SHOKUINKOJIN_NO  --職員宛名番号
                                  ,i_VSYS_TANMATSU_NO      --端末番号
                                 );
  EXCEPTION
    WHEN OTHERS THEN
      -- 異常
      NRTN := c_NRTN_ABEND;
  END;

  RETURN ( NRTN );
END FUNCHAITASET;
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

  -- 4.排他チェック
  IF NRTN = c_NRTN_NORMAL THEN
    NRTN := FUNCHAITACHK;
  END IF;

  -- 5.排他制御
  IF NRTN = c_NRTN_NORMAL THEN
    NRTN := FUNCHAITASET;
  END IF;

  -- 6.終了処理
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
END GKBFKHTSET;
/
