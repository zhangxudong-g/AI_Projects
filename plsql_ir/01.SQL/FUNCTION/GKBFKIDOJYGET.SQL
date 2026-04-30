CREATE OR REPLACE FUNCTION GKBFKIDOJYGET(i_IDO_JIYU_CD IN  PLS_INTEGER)
--1.0.000.000-02.02-02.02
RETURN NVARCHAR2 -- 戻り値のデータ型
------------------------------------------------------------------------------
--  業務名      GKB（教育）
--  PG名        GKBFKIDOJYGET
--  名称        教育システム用異動事由名称取得ファンクション
--  処理概要    与えられた異動事由コードの異動事由名称を取得する。
--  作成者      ZCZL.GUOXU
--  作成日      2024/01/22
--  VERSION     0.2.000.000
------------------------------------------------------------------------------
IS
    VIDO_JIYU_MEI   NVARCHAR2(20);
    IRTNCD          PLS_INTEGER;
BEGIN
    VIDO_JIYU_MEI :=  '';

      SELECT IDO_JIYU_MEI INTO VIDO_JIYU_MEI
        FROM GABTIDOJIYU
       WHERE IDO_JIYU_CD = i_IDO_JIYU_CD;

  RETURN VIDO_JIYU_MEI;

EXCEPTION
    WHEN OTHERS THEN
      RETURN ('');
END GKBFKIDOJYGET;
/
