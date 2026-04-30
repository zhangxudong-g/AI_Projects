CREATE OR REPLACE FUNCTION GKBFKGKKUGET(
--1.0.000.000-02.02-02.02
  i_nKOJIN_NO                 IN  NUMBER,
  i_nATENA_RIREKI_RENBAN      IN  NUMBER,
  o_vSHOGAKU_CD               OUT NVARCHAR2,
  o_vSHOGAKU_NM               OUT NVARCHAR2,
  o_vCHUGAKU_CD               OUT NVARCHAR2,
  o_vCHUGAKU_NM               OUT NVARCHAR2
) RETURN  PLS_INTEGER
------------------------------------------------------------------------------
--  業務名      GKB（教育）
--  PG名        GKBFKGKKUGET
--  名称        学齢簿学校区取得
--  処理概要    引数として渡された宛名番号の児童生徒の住所または、行政区から学校区を取得する。
--             ※最新の宛名情報で取得したい場合は、引数の宛名履歴連番を 999 で設定して取得。
--  引き数       i_nKOJIN_NO                     個人番号
--              i_nATENA_RIREKI_RENBAN          宛名履歴連番
--              o_vSHOGAKU_CD                   小学校区コード
--              o_vSHOGAKU_NM                   小学校区名
--              o_vCHUGAKU_CD                   中学校区コード
--              o_vCHUGAKU_NM                   中学校区名
--  作成者      ZCZL.MUZHILIN
--  作成日      2024/06/03
--  VERSION     0.3.000.000
----------------------------------------------------------------------
--  変更履歴
--  2024/09/10 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.002:仕様変更　IT_GKB_00041 横展開
----------------------------------------------------------------------
IS
------------------------------------------------------------------------------
--  変数宣言
------------------------------------------------------------------------------
  g_nGAKKU_KBN         NUMBER;          -- 学区管理区分（0：住所、 1：行政区）
  g_nGAKKO_KBN_CD      NUMBER;          -- 学校区分
  g_vGAKKOKU_CD        NVARCHAR2(5);    -- 学校区コード
  g_vMEISHO            NVARCHAR2(100);  -- 名称
  g_nRTN               NUMBER;
  g_rITEM              A_CONS_PRM;
--  2024/10/11 ZCZL.WANGMING ADD START 0.3.000.002:仕様変更　IT_GKB_00041 横展開
  iRenBAN              NUMBER;          -- 変数.検索用履歴連番
  rexists              NUMBER;          --宛名基本情報件数
--  2024/10/11 ZCZL.WANGMING ADD END
  TYPE TYPECURSOR IS REF CURSOR;
  CRATENA              TYPECURSOR;
  TYPE MR_RECORDGKBTMSGAKKU IS RECORD (
        GAKKO_KBN_CD            NUMBER,
        GAKKOKU_CD              NVARCHAR2(5),
        MEISHO                  NVARCHAR2(300)
        );
  g_rDATA              MR_RECORDGKBTMSGAKKU;
  g_vSQL               NVARCHAR2(3000);
----------------------------------------------------------------------
--メイン処理
----------------------------------------------------------------------
BEGIN
  -- 変数の初期化
  g_nGAKKU_KBN     := 0;
  g_nGAKKO_KBN_CD  := 0;
  g_vGAKKOKU_CD    := NULL;
  g_vMEISHO        := NULL;

  o_vSHOGAKU_CD    := NULL;
  o_vSHOGAKU_NM    := NULL;
  o_vCHUGAKU_CD    := NULL;
  o_vCHUGAKU_NM    := NULL;
  -- 学区管理区分を取得する
  BEGIN
    g_nRTN := KKAPK0030.FCTGetR('GKB','00GAKKU_KANRI','0000',0,g_rITEM);
    IF g_nRTN = 0 THEN
       g_nGAKKU_KBN := g_rITEM(1);
    ELSE
      RETURN 1;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;
  END;

--  2024/10/11 ZCZL.WANGMING ADD START 0.3.000.002:仕様変更　IT_GKB_00041 横展開
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
-- 学区管理情報および、コード変換テーブルから学校区情報を取得する。
      g_vSQL := '';
      g_vSQL := g_vSQL || 'SELECT ';
      g_vSQL := g_vSQL || '        GKBTMSGAKKU.GAKKO_KBN_CD ';
      g_vSQL := g_vSQL || '        , GKBTMSGAKKU.GAKKOKU_CD ';
      g_vSQL := g_vSQL || '        , KKATCD.MEISHO ';
      g_vSQL := g_vSQL || '      FROM ';
      g_vSQL := g_vSQL || '          GKBTMSGAKKU, GABVATENAALL,KKATCD ';
      g_vSQL := g_vSQL || '      WHERE ';
      g_vSQL := g_vSQL || '          KOJIN_NO = ' || i_nKOJIN_NO;
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.002:仕様変更　IT_GKB_00041 横展開
--      g_vSQL := g_vSQL || '      AND RIREKI_RENBAN = ' || i_nATENA_RIREKI_RENBAN;
      g_vSQL := g_vSQL || '      AND RIREKI_RENBAN = ' || iRenBAN;
    IF g_nGAKKU_KBN = 0 THEN
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.OAZA_CD = GABVATENAALL.OAZA_CD ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.HONBAN_FR <= GABVATENAALL.HONBAN ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.HONBAN_TO >= GABVATENAALL.HONBAN ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.EDABAN1_FR <= GABVATENAALL.EDABAN1 ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.EDABAN1_TO >= GABVATENAALL.EDABAN1 ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.EDABAN2_FR <= GABVATENAALL.EDABAN2 ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.EDABAN2_TO >= GABVATENAALL.EDABAN2 ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.EDABAN3_FR <= GABVATENAALL.EDABAN3 ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.EDABAN3_TO >= GABVATENAALL.EDABAN3 ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.GAIKU_FR <= GABVATENAALL.GAIKU ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.GAIKU_TO >= GABVATENAALL.GAIKU ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.TOU_FR <= GABVATENAALL.TOU ';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.TOU_TO >= GABVATENAALL.TOU';
    END IF;
    IF g_nGAKKU_KBN = 1 THEN
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.GYOSEIKU_CD = GABVATENAALL.GYOSEIKU_CD';
    END IF;
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.SAISHIN_FLG = 0';
      g_vSQL := g_vSQL || '      AND GKBTMSGAKKU.SAKUJO_FLG = 0';
      g_vSQL := g_vSQL || '      AND KKATCD.GYOUMUCODE =''GKB''';
      g_vSQL := g_vSQL || '      AND TRIM(KKATCD.CODECODE) =''023''';
      g_vSQL := g_vSQL || '      AND KKATCD.GROUPCODE =''000'' || GKBTMSGAKKU.GAKKO_KBN_CD';
      g_vSQL := g_vSQL || '      AND TRIM(KKATCD.ANYCODE) = GKBTMSGAKKU.GAKKOKU_CD ';

    EXECUTE IMMEDIATE  g_vSQL;
      OPEN CRATENA  FOR g_vSQL;
        LOOP
          FETCH CRATENA INTO g_rDATA ;
          EXIT WHEN CRATENA%NOTFOUND;
            g_nGAKKO_KBN_CD := g_rDATA.GAKKO_KBN_CD;
            g_vGAKKOKU_CD   := g_rDATA.GAKKOKU_CD;
            g_vMEISHO       := g_rDATA.MEISHO;
            -- 小学校 の場合
            IF g_nGAKKO_KBN_CD = 1 THEN
              o_vSHOGAKU_CD := g_vGAKKOKU_CD;
              o_vSHOGAKU_NM := g_vMEISHO;
            END IF;
            --中学校 の場合
            IF g_nGAKKO_KBN_CD = 2 THEN
              o_vCHUGAKU_CD := g_vGAKKOKU_CD;
              o_vCHUGAKU_NM := g_vMEISHO;
            END IF;
        END LOOP;
      CLOSE CRATENA;

  RETURN 0;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
--  2024/09/10 ZCZL.WANGMING ADD START 0.3.000.001:8月1日認識合わせの横展開
      IF CRATENA%ISOPEN THEN
         CLOSE CRATENA;
      END IF;
--  2024/09/10 ZCZL.WANGMING ADD END
      RETURN 1;
    WHEN OTHERS THEN
--  2024/09/10 ZCZL.WANGMING ADD START 0.3.000.001:8月1日認識合わせの横展開
      IF CRATENA%ISOPEN THEN
         CLOSE CRATENA;
      END IF;
--  2024/09/10 ZCZL.WANGMING ADD END
      RETURN 1;

END GKBFKGKKUGET;
/