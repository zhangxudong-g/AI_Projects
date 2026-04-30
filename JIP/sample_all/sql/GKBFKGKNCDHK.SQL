--  2024/09/29 ZCZL.yangshuai Update start 0.3.000.001:仕様変更 IT_GKB_00073対応
CREATE OR REPLACE FUNCTION GKBFKGKNCDHK(i_GAKUNENCD      IN  NUMBER,
-- CREATE OR REPLACE FUNCTION GKBFKGKNCDHK(i_IGAKURUI_GAKUNENCD      IN  NUMBER,
--  2024/09/29 ZCZL.yangshuai Update end
--1.0.000.000-02.02-02.02
                                        o_IKIHON_GAKUNENCD        OUT NVARCHAR2 )  RETURN  NUMBER
------------------------------------------------------------------------------
--  業務名      GKB（教育）
--  PG名        GKBFKGKNCDHK
--  名称        学年コード変換
--  処理概要    引数として渡された学齢簿の学年コードから基本データリストの学年コードを転換する。
--  引き数       i_IGAKURUI_GAKUNENCD          学齢簿の学年コード
--              o_IKIHON_GAKUNENCD            基本データリストの学年コード
--  作成者      ZCZL.WANGQIWEI
--  作成日      2024/06/03
--  VERSION    0.3.000.000
------------------------------------------------------------------------------
--  変更履歴
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.001:仕様変更 IT_GKB_00073対応
------------------------------------------------------------------------------
IS
  CNORMAL_END      CONSTANT   PLS_INTEGER  := 0;        -- 正常終了
  CABNORMAL_END    CONSTANT   PLS_INTEGER  := 1;        -- 異常終了
BEGIN
        CASE 
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.001:仕様変更 IT_GKB_00073対応
--            -- 学校区分コード＝0（小学０年）の場合
--            WHEN i_IGAKURUI_GAKUNENCD = 0
--                THEN  o_IKIHON_GAKUNENCD := 'E3';
--            -- 学校区分コード＝1（小学1年）の場合
--            WHEN i_IGAKURUI_GAKUNENCD = 1
--                THEN  o_IKIHON_GAKUNENCD := 'P1';
--            -- 学校区分コード＝2（小学2年）の場合
--            WHEN i_IGAKURUI_GAKUNENCD = 2
--                THEN  o_IKIHON_GAKUNENCD := 'P2';
--            -- 学校区分コード＝3（小学3年）の場合
--            WHEN i_IGAKURUI_GAKUNENCD = 3
--                THEN  o_IKIHON_GAKUNENCD := 'P3';
--            -- 学校区分コード＝4（小学4年）の場合
--            WHEN i_IGAKURUI_GAKUNENCD = 4
--                THEN  o_IKIHON_GAKUNENCD := 'P4';
--            -- 学校区分コード＝5（小学5年）の場合
--            WHEN i_IGAKURUI_GAKUNENCD = 5
--                THEN  o_IKIHON_GAKUNENCD := 'P5';
--            -- .学校区分コード＝6（小学０年）の場合
--            WHEN i_IGAKURUI_GAKUNENCD = 6
--                THEN  o_IKIHON_GAKUNENCD := 'P6';
--            -- 学校区分コード＝7（中学１年）の場合
--            WHEN i_IGAKURUI_GAKUNENCD = 7
--                THEN  o_IKIHON_GAKUNENCD := 'J1';
--            -- 学校区分コード＝7（中学2年）の場合
--            WHEN i_IGAKURUI_GAKUNENCD = 8
--                THEN  o_IKIHON_GAKUNENCD := 'J2';
--            -- 学校区分コード＝7（中学3年）の場合
--            WHEN i_IGAKURUI_GAKUNENCD = 9
--                THEN  o_IKIHON_GAKUNENCD := 'J3';
            -- 学年コード＝0（小学０年）の場合
            WHEN i_GAKUNENCD = 0
                THEN  o_IKIHON_GAKUNENCD := 'E3';
            -- 学年コード＝1（小学1年）の場合
            WHEN i_GAKUNENCD = 1
                THEN  o_IKIHON_GAKUNENCD := 'P1';
            -- 学年コード＝2（小学2年）の場合
            WHEN i_GAKUNENCD = 2
                THEN  o_IKIHON_GAKUNENCD := 'P2';
            -- 学年コード＝3（小学3年）の場合
            WHEN i_GAKUNENCD = 3
                THEN  o_IKIHON_GAKUNENCD := 'P3';
            -- 学年コード＝4（小学4年）の場合
            WHEN i_GAKUNENCD = 4
                THEN  o_IKIHON_GAKUNENCD := 'P4';
            -- 学年コード＝5（小学5年）の場合
            WHEN i_GAKUNENCD = 5
                THEN  o_IKIHON_GAKUNENCD := 'P5';
            -- 学年コード＝6（小学０年）の場合
            WHEN i_GAKUNENCD = 6
                THEN  o_IKIHON_GAKUNENCD := 'P6';
            -- 学年コード＝7（中学１年）の場合
            WHEN i_GAKUNENCD = 7
                THEN  o_IKIHON_GAKUNENCD := 'J1';
            -- 学年コード＝8（中学2年）の場合
            WHEN i_GAKUNENCD = 8
                THEN  o_IKIHON_GAKUNENCD := 'J2';
            -- 学年コード＝9（中学3年）の場合
            WHEN i_GAKUNENCD = 9
                THEN  o_IKIHON_GAKUNENCD := 'J3';
--  2024/09/29 ZCZL.yangshuai Update end
         ELSE
           -- データが取得できなかった場合 処理を終了する
            RETURN CABNORMAL_END;
         END CASE ;
       -- 正常終了 : 0 
       RETURN CNORMAL_END;
        EXCEPTION
          WHEN OTHERS THEN
             -- 異常終了 : 1 
             RETURN CABNORMAL_END;
END GKBFKGKNCDHK;
/