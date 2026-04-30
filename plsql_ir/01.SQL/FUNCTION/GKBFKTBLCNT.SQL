CREATE OR REPLACE FUNCTION GKBFKTBLCNT (
--1.0.000.000-02.02-02.02
                                           i_FROM  IN NVARCHAR2,  -- テーブル名
                                           i_WHERE IN NVARCHAR2   -- WHERE句
) RETURN NUMBER

------------------------------------------------------------------------------
--  業務名        GKB（教育）
--  PG名          GKBFKTBLCNT
--  名称          件数カウント計算 
--  処理概要      引数として渡されたテーブル、条件に一致するデータ件数を取得する。
--  引数          i_FROM   テーブル名
--                i_WHERE  WHERE句
--  戻り値        処理結果
--  作成者        ZCZL.GUOXU
--  作成日        2024/01/22
--  VERSION       0.2.000.000
------------------------------------------------------------------------------
IS
------------------------------------------------------------------------------
  -- 変数宣言  
  NCOUNT         NUMBER;
  V_SQL          NVARCHAR2(2000);
  TYPE CUR_COUNT IS REF CURSOR;
  C_COUNT        CUR_COUNT;
BEGIN
  -- 1.変数のクリア
  -- 1-1.変数.件数に0をセットする。
  NCOUNT := 0;
  
  -- 2.データ件数の取得
  -- 2-1.引数.テーブル名と引数.WHERE句より、件数カウントの動的SQLを作成する。
  V_SQL := '';
  V_SQL := V_SQL || ' SELECT COUNT(*) FROM ' || i_FROM;
  -- WHERE句追加
  IF i_WHERE IS NOT NULL THEN
    V_SQL := V_SQL || ' WHERE ' || i_WHERE;
  END IF;

  -- 2-2.カーソルを使用して動的SQLを実行し、取得した件数を変数.件数にセットする。
  OPEN C_COUNT FOR TO_CHAR(V_SQL);
  FETCH C_COUNT INTO NCOUNT;
  CLOSE C_COUNT;

  -- 3.戻り値のセット
  -- 正常終了の場合
  RETURN NCOUNT;
EXCEPTION
  WHEN OTHERS THEN
    IF C_COUNT%ISOPEN THEN
      CLOSE C_COUNT;
    END IF;
    --異常終了の場合
    RETURN -1;
END GKBFKTBLCNT;
/
