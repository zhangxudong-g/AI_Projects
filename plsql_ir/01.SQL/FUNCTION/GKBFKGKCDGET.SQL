CREATE OR REPLACE FUNCTION GKBFKGKCDGET(
--1.0.000.000-02.02-02.02
  i_nGAKO_KBN               IN  NUMBER, --学校区分（1：小学校、 2：中学校）
  i_nKOJIN_NO               IN  NUMBER, --宛名番号
  i_nATENA_RIREKI_RENBAN    IN NUMBER   --宛名履歴連番 (999で最新履歴を指定可能)
) RETURN  NUMBER
------------------------------------------------------------------------------
--  業務名      GKB（教育）
--  PG名        GKBFKGKCDGET
--  名称        学校コード取得
--  処理概要    引数として渡された宛名番号の児童生徒の住所等から対象の学校コードを取得する。
--  引き数       i_nGAKO_KBN          学校区分（1：小学校、 2：中学校）
--              i_nKOJIN_NO          宛名番号
--              i_nATENA_RIREKI_RENBAN        宛名履歴連番 (999で最新履歴を指定可能)
--  作成者      ZCZL.WANGYUNHAN
--  作成日      2024/06/03
--  VERSION    0.3.000.000
----------------------------------------------------------------------
--  変更履歴
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.001:仕様変更　IT_GKB_00041 横展開
----------------------------------------------------------------------
IS
------------------------------------------------------------------------------
--  変数宣言
------------------------------------------------------------------------------
  g_nERR                 NUMBER := -1;        --戻りエラー値
  g_nRETURN_CODE         NUMBER;              --戻り値
  g_nGAKKU_KBN           NUMBER := 0;         --学区管理区分
  g_vSQL                 NVARCHAR2(1000);     --SQL文
  g_nRTN                 PLS_INTEGER;
  g_tITEM                A_CONS_PRM;
--  2024/10/11 ZCZL.WANGMING ADD START 0.3.000.001:仕様変更　IT_GKB_00041 横展開
  iRenBAN              NUMBER;          -- 変数.検索用履歴連番
  rexists              NUMBER;          --宛名基本情報件数
--  2024/10/11 ZCZL.WANGMING ADD END
BEGIN
--   学区管理区分を取得する。（0：住所、 1：行政区）
    g_nRTN := KKAPK0030.FCTGetR('GKB','00GAKKU_KANRI','0000',0,g_tITEM);
    IF g_nRTN = 0 THEN
        g_nGAKKU_KBN := g_tITEM(1);
    ELSE
      RETURN g_nERR;
    END IF;
--  2024/10/11 ZCZL.WANGMING ADD START 0.3.000.001:仕様変更　IT_GKB_00041 横展開
      --宛名基本から履歴連番を取得する
      BEGIN
          SELECT COUNT(*)
            INTO rexists
          FROM GABTATENAKIHON
          WHERE  
             KOJIN_NO = i_nKOJIN_NO
             AND RIREKI_RENBAN = i_nATENA_RIREKI_RENBAN;
      EXCEPTION
          WHEN OTHERS THEN
             rexists := 0;
      END;
      --変数.検索用履歴連番を設定する
      --2-2-1.で宛名基本が存在する場合
      IF rexists <> 0 THEN
         iRenBAN := 999;
      ELSE
         iRenBAN := i_nATENA_RIREKI_RENBAN;
      END IF;
--  2024/10/11 ZCZL.WANGMING ADD END
--   学区管理情報、小、中学校名テーブルから学校コードを取得する。
    g_vSQL :=' ';
    g_vSQL := g_vSQL || ' SELECT ';
    IF i_nGAKO_KBN = 1 THEN 
      g_vSQL := g_vSQL || '    SYOGAKO_CD  FROM GKBTSHOGAKKO '; --小学校
    ELSIF i_nGAKO_KBN = 2 THEN 
      g_vSQL := g_vSQL || '    TYUGAKO_CD  FROM GKBTCHUGAKKO';  --中学校
    ELSE 
      RETURN g_nERR;
    END IF;
    g_vSQL := g_vSQL || '     , GABVATENAALL ';  --宛名管理他業務参照
    g_vSQL := g_vSQL || '     , GKBTMSGAKKU  ';  --学区管理情報
    g_vSQL := g_vSQL || ' WHERE ';
    g_vSQL := g_vSQL || '     GABVATENAALL.KOJIN_NO = '|| i_nKOJIN_NO ||'';
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.001:仕様変更　IT_GKB_00041 横展開
--    g_vSQL := g_vSQL || ' AND GABVATENAALL.RIREKI_RENBAN = '||i_nATENA_RIREKI_RENBAN ||'';
    g_vSQL := g_vSQL || ' AND GABVATENAALL.RIREKI_RENBAN = '||iRenBAN ||'';
--   学区管理情報、小学校名テーブルから学校コードを取得する。
    IF g_nGAKKU_KBN = 0 THEN 
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.OAZA_CD = GABVATENAALL.OAZA_CD';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.HONBAN_FR <= GABVATENAALL.HONBAN';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.HONBAN_TO >= GABVATENAALL.HONBAN';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.EDABAN1_FR <= GABVATENAALL.EDABAN1';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.EDABAN1_TO >= GABVATENAALL.EDABAN1';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.EDABAN2_FR <= GABVATENAALL.EDABAN2';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.EDABAN2_TO >= GABVATENAALL.EDABAN2';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.EDABAN3_FR <= GABVATENAALL.EDABAN3';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.EDABAN3_TO >= GABVATENAALL.EDABAN3';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.GAIKU_FR <= GABVATENAALL.GAIKU';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.GAIKU_TO >= GABVATENAALL.GAIKU';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.TOU_FR <= GABVATENAALL.TOU';
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.TOU_TO >= GABVATENAALL.TOU';
    ELSIF g_nGAKKU_KBN = 1 THEN 
        g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.GYOSEIKU_CD = GABVATENAALL.GYOSEIKU_CD';
    END IF;
    g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.GAKKO_KBN_CD = '|| i_nGAKO_KBN ||'';
    g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.SAISHIN_FLG = 0';
    g_vSQL := g_vSQL || ' AND GKBTMSGAKKU.SAKUJO_FLG = 0';
    IF i_nGAKO_KBN = 1 THEN 
      g_vSQL := g_vSQL || ' AND GKBTSHOGAKKO.GAKKOKU_CD(+)  = GKBTMSGAKKU.GAKKOKU_CD';
      g_vSQL := g_vSQL || ' AND GKBTSHOGAKKO.SAKUJO_FLG(+) = 0';
    ELSIF i_nGAKO_KBN = 2 THEN 
      g_vSQL := g_vSQL || ' AND GKBTCHUGAKKO.GAKKOKU_CD(+)  = GKBTMSGAKKU.GAKKOKU_CD';
      g_vSQL := g_vSQL || ' AND GKBTCHUGAKKO.SAKUJO_FLG(+) = 0';
    END IF;
    EXECUTE IMMEDIATE g_vSQL INTO g_nRETURN_CODE;
        RETURN g_nRETURN_CODE;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
      RETURN g_nERR;
    WHEN OTHERS THEN
      RETURN g_nERR;
END GKBFKGKCDGET;
/