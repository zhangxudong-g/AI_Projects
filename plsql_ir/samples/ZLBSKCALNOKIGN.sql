CREATE OR REPLACE PROCEDURE ZLBSKCALNOKIGN(
--1.1.200.000
                                                  i_NKOKU_SETAI_NO    IN  NUMBER,           --国保世帯番号
                                                  i_NDANTAI           IN  NUMBER,           --算定団体コード
                                                  i_NCHOTEI_NENDO     IN  NUMBER,           --調定年度
                                                  i_NNENDO_BUN        IN  NUMBER,           --年度分
                                                  i_NTSUCHI_NO        IN  NUMBER,           --通知書番号
                                                  i_NNUSHI_KOJIN_NO   IN  NUMBER,           --世帯主個人番号
                                                  i_TOTATSU_BI        IN  NUMBER,           --納通到達日（西暦）
                                                  i_KIJUN_BI          IN  NUMBER,           --基準日（西暦）
                                                  i_NTRENBAN          IN  NUMBER,           --登録連番
                                                  i_VMASIN_NO         IN  NVARCHAR2,        --端末番号
                                                  o_NRTN              OUT NUMBER            --リターンコード（計算対象区分 0:対象/1:対象外/9:異常終了）
                                                 )

------------------------------------------------------------------------------
--  業務名      ZLB (国保賦課）
--  PG名        ZLBSKCALNOKIGN.SQL
--  名称        法廷納期限計算処理
--  引き数       i_NKOKU_SETAI_NO    国保世帯番号
--               i_NDANTAI           算定団体コード
--               i_NCHOTEI_NENDO     調定年度
--               i_NNENDO_BUN        年度分
--               I_NTSUCHI_NO        通知書番号
--               I_NNUSHI_KOJIN_NO   世帯主個人番号
--               i_TOTATSU_BI        納通到達日（西暦）
--               i_KIJUN_BI          基準日（西暦）
--               i_NTRENBAN          登録連番
--               i_VMASIN_NO         端末番号
--               o_NRTN              リターンコード（計算対象区分 0:対象/1:対象外/9:異常終了）
-- 作成者   ZCZL.FUBOYU
-- 作成日   2023/08/02
--  Version     0.2.000.000
------------------------------------------------------------------------------
--  変更履歴
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
-------------------------------------------------------------------------------
IS

--計算後年税額取得
--ZLBTKIHON_CALなど計算後のテーブル
  CURSOR KIHON_CAL IS
    SELECT
          NVL(KI.NENZEI,0) AS KI_NENZEI,
          NVL(KA.NENZEI,0) AS KA_NENZEI,
          NVL(SI.NENZEI,0) AS SI_NENZEI
--  2025/08/11 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
          ,NVL(KDM.NENZEI,0) AS KDM_NENZEI
     FROM ZLBTKIHON_CAL KI,
          ZLBTKAI_KIHON_CAL KA,
          ZLBTSIEN_KIHON_CAL SI
--  2025/08/11 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
          ,ZLBTKDM_KIHON_CAL KDM
    WHERE KI.KOKU_SETAI_NO       = i_NKOKU_SETAI_NO
          AND KI.SANTEIDANTAI_CD = i_NDANTAI
          AND KI.CHOTEI_NENDO    = i_NCHOTEI_NENDO
          AND KI.NENDO_BUN       = i_NNENDO_BUN
          AND KI.SYS_TANMATSU_NO = ''''|| I_NTSUCHI_NO ||''''

          AND KA.KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
          AND KA.SANTEIDANTAI_CD = i_NDANTAI
          AND KA.CHOTEI_NENDO    = i_NCHOTEI_NENDO
          AND KA.NENDO_BUN       = i_NNENDO_BUN
          AND KA.SYS_TANMATSU_NO = ''''|| I_NTSUCHI_NO ||''''

          AND SI.KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
          AND SI.SANTEIDANTAI_CD = i_NDANTAI
          AND SI.CHOTEI_NENDO    = i_NCHOTEI_NENDO
          AND SI.NENDO_BUN       = i_NNENDO_BUN
--  2025/08/11 ZCZL.WANGMING UPDATE START 1.1.200.000:子ども子育て支援金対応
--          AND SI.SYS_TANMATSU_NO = ''''|| I_NTSUCHI_NO ||'''';
          AND SI.SYS_TANMATSU_NO = ''''|| I_NTSUCHI_NO ||''''
          AND KDM.KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
          AND KDM.SANTEIDANTAI_CD = i_NDANTAI
          AND KDM.CHOTEI_NENDO    = i_NCHOTEI_NENDO
          AND KDM.NENDO_BUN       = i_NNENDO_BUN
          AND KDM.SYS_TANMATSU_NO = ''''|| I_NTSUCHI_NO ||'''';
--  2025/08/11 ZCZL.WANGMING UPDATE END

--計算前年税額取得
--ZLBTKIHON_Nなど計算前のテーブル
  CURSOR KIHON_N IS
    SELECT NVL(KI.NENZEI,0) AS KI_NENZEI,
           NVL(KA.NENZEI,0) AS KA_NENZEI,
           NVL(SI.NENZEI,0) AS SI_NENZEI
--  2025/08/11 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
          ,NVL(KDM.NENZEI,0) AS KDM_NENZEI
    FROM   ZLBTKIHON_N  KI,
           ZLBTKAI_KIHON_N  KA,
           ZLBTSIEN_KIHON_N  SI
--  2025/08/11 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
          ,ZLBTKDM_KIHON_N KDM
    WHERE     KI.KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
          AND KI.SANTEIDANTAI_CD = i_NDANTAI
          AND KI.CHOTEI_NENDO    = i_NCHOTEI_NENDO
          AND KI.NENDO_BUN       = i_NNENDO_BUN

          AND KA.KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
          AND KA.SANTEIDANTAI_CD = i_NDANTAI
          AND KA.CHOTEI_NENDO    = i_NCHOTEI_NENDO
          AND KA.NENDO_BUN       = i_NNENDO_BUN

          AND SI.KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
          AND SI.SANTEIDANTAI_CD = i_NDANTAI
          AND SI.CHOTEI_NENDO    = i_NCHOTEI_NENDO
--  2025/08/11 ZCZL.WANGMING UPDATE START 1.1.200.000:子ども子育て支援金対応
--          AND SI.NENDO_BUN       = i_NNENDO_BUN;
          AND SI.NENDO_BUN       = i_NNENDO_BUN
          AND KDM.KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
          AND KDM.SANTEIDANTAI_CD = i_NDANTAI
          AND KDM.CHOTEI_NENDO    = i_NCHOTEI_NENDO
          AND KDM.NENDO_BUN       = i_NNENDO_BUN;
--  2025/08/11 ZCZL.WANGMING UPDATE END

--過年度計算対象年
  CURSOR JOKEN IS
    SELECT  KANENDO_TAISHO_ZO,
            KANENDO_TAISHO_GEN
      FROM  ZLBTJOKEN
     WHERE  NENDO = i_NCHOTEI_NENDO
       AND  SANTEIDANTAI_CD = i_NDANTAI;

--賦課期日
  CURSOR JOKEN_JITSU IS
    SELECT  FUKAKIJITSU
      FROM  ZLBTJOKEN
     WHERE  NENDO = i_NNENDO_BUN
       AND  SANTEIDANTAI_CD = i_NDANTAI;

  CURSOR JOKEN_NUSHI IS
    SELECT  NUSHI_KAZEI
      FROM  ZLBTJOKEN
     WHERE  NENDO = i_NNENDO_BUN
       AND  SANTEIDANTAI_CD = i_NDANTAI;

--賦課期日時点の資格有無
  CURSOR KOJIN_CAL IS
    SELECT F4_SHIK_KBN,
           NEW_SHUTOK_BI
    FROM   ZLBTKOJIN_CAL
    WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
          AND SANTEIDANTAI_CD = i_NDANTAI
          AND KOJIN_NO = I_NNUSHI_KOJIN_NO
          AND CHOTEI_NENDO    = i_NCHOTEI_NENDO
          AND NENDO_BUN       = i_NNENDO_BUN
          AND TSUCHI_NO       = I_NTSUCHI_NO
          AND SYS_TANMATSU_NO = i_VMASIN_NO;


--計算期別マスタより、期割団体コード、団体内外区分、現年過年区分を抽出する。
CURSOR KSCFKSNJKK_NOKIGEN IS
    SELECT DISTINCT
          KIWARIDANTAI_CD,
          DANTAING_KBN,
          GENNENKANEN_KBN
    FROM ZLBTKIBETSU_CAL
    WHERE KAMOKU_CD       = 15
          AND KAMOKUS_CD      = 1
          AND KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
          AND SANTEIDANTAI_CD = i_NDANTAI
          AND CHOTEINENDO     = i_NCHOTEI_NENDO
          AND NENDOBUN        = i_NNENDO_BUN
          AND TSUCHI_NO       = I_NTSUCHI_NO;


  --------------------------------------
  --テーブル宣言
  --------------------------------------
  RKIHON_CAL            KIHON_CAL%ROWTYPE;      --WK計算後年税額
  RKIHON_N              KIHON_N%ROWTYPE;        --WK計算前年税額
  RKOJIN_CAL            KOJIN_CAL%ROWTYPE;      --賦課期日時点の資格有無
  RJOKEN                JOKEN%ROWTYPE;          --過年度計算対象年
  RJOKEN_JITSU          JOKEN_JITSU%ROWTYPE;    --賦課期日

  RKSCFKSNJKK_NOKIGEN  KSCFKSNJKK_NOKIGEN%ROWTYPE;

  RSHUNOJKNK              KSCWSHUNOJKNK%ROWTYPE;
  R_02CALPASSUPD_LST      ZLBW_02CALPASSUPD_LST%ROWTYPE;    --データ格納

  --------------------------------------
  --変数宣言
  --------------------------------------

  OLD_NENZEI         NUMBER;        --WK計算後年税額
  NEW_NENZEI         NUMBER;        --WK計算前年税額
  NENZEI             BOOLEAN;       --年税額の増減判定
  IRTN               PLS_INTEGER;
  NIDX               NUMBER;
  KANENDO_TAISHO_GEN NUMBER;        --WK過年度計算対象年減額
  KANENDO_TAISHO_ZO  NUMBER;        --WK過年度計算対象年増額
  KANENDO_TAISHO_ZO2 NUMBER := 0;   --WK過年度計算対象年増額
  F4_SHIK_KBN        NUMBER;        --賦課期日時点
  FUKAKIJITSU        NUMBER;        --賦課期日
  T_YEAR_DATE        NUMBER;        --資格取得日の２年後日付の取得
  HANTEI_KBN         NUMBER;        --計算対象区分
  NOKIGEN            NUMBER;        --第一期納期限

  KIWARIDANTAI_CD    NUMBER;        --期割団体コード
  DANTAING_KBN       NUMBER;        --団体内外区分
  GENNENKANEN_KBN    NUMBER;        --現年過年区分

  FUKA_END           NUMBER;         --賦課最終
  IDO_DATE           NUMBER;         --資格異動
  NUSHIKAZEI         NUMBER;        --賦課期日

--計算対象かどうか判定
  FUNCTION FUNSUM_KBN RETURN NUMBER
  IS
    WK_YEAR_NUMBER    NUMBER;      --WK過年度年数
    IRTN_KBN          NUMBER;
  BEGIN

    WK_YEAR_NUMBER :=0;
    IRTN_KBN   := 0;

    --引数.調定年度 － 引数.年度分を[WK過年度年数]とする。
    WK_YEAR_NUMBER := i_NCHOTEI_NENDO - i_NNENDO_BUN;

    --年税額が減額の場合
    IF NENZEI = FALSE THEN
       --[WK過年度年数]＞ [WK過年度計算対象年減額]の場合。
       IF WK_YEAR_NUMBER > KANENDO_TAISHO_GEN THEN
          IRTN_KBN := 1;
       ELSE
          IRTN_KBN := 0;
       END IF;

    --年税額の増減判定で年税額が増額の場合。
    ELSE

       --で賦課期日時点で資格がある場合。
       IF F4_SHIK_KBN = 1 OR F4_SHIK_KBN = 2 THEN
          --引数.納通到達日　＜＝　[WK第一期納期限]　の場合
          IF i_TOTATSU_BI <= NOKIGEN THEN
             --[WK過年度年数]＞[WK過年度計算対象年増額]の場合
             IF WK_YEAR_NUMBER > KANENDO_TAISHO_ZO THEN
                IRTN_KBN := 1;
             ELSE
                IRTN_KBN :=0;
             END IF;
          END IF;

          --引数.納通到達日　＞　[WK第一期納期限]　の場合
          IF i_TOTATSU_BI > NOKIGEN THEN
             IF WK_YEAR_NUMBER > KANENDO_TAISHO_ZO2 THEN
                IRTN_KBN := 1;
             ELSE
                IRTN_KBN :=0;
             END IF;
          END IF;

       --で賦課期日時点で資格なし場合
       ELSE
           --引数.納通到達日　＜＝　[WK資格取得日の２年後の日付]　の場合
          IF i_TOTATSU_BI <= T_YEAR_DATE THEN
             --[WK過年度年数]＞[WK過年度計算対象年増額]の場合、
             IF WK_YEAR_NUMBER > KANENDO_TAISHO_ZO THEN
                IRTN_KBN := 1;
             ELSE
                IRTN_KBN := 0;
             END IF;
          END IF;

          --引数.納通到達日　＞　[WK資格取得日の２年後の日付]　の場合、
          IF i_TOTATSU_BI > T_YEAR_DATE THEN
             IF WK_YEAR_NUMBER > KANENDO_TAISHO_ZO2 THEN
                IRTN_KBN := 1;
             ELSE
                IRTN_KBN := 0;
             END IF;
          END IF;
       END IF;
    END IF;

    RETURN IRTN_KBN;
  END FUNSUM_KBN;

  FUNCTION FUNC_DATE_CREATE RETURN NUMBER
  ------------------------------------------------------------------------------
  --  業務名      共通
  --  業務詳細
  --  PG名        FUNC_DATE_CREATE
  --  名称        中間ファイルに編集する
  --  処理概要    中間テーブル更新
  ------------------------------------------------------------------------------

  IS
      I_RESULT  NUMBER;   --関数の実行結果
  BEGIN
      I_RESULT  := o_NRTN;

      --(計算対象区分)が0(対象)の場合
      IF I_RESULT = 0 THEN
         R_02CALPASSUPD_LST.LIST_HANTEI_KBN := 0;

      --(計算対象区分)が1(対象外)の場合
      ELSIF I_RESULT = 1 THEN
         R_02CALPASSUPD_LST.LIST_HANTEI_KBN := 1;
      END IF;

      --国保世帯番号
      R_02CALPASSUPD_LST.KOKU_SETAI_NO := i_NKOKU_SETAI_NO;
      --個人番号
      R_02CALPASSUPD_LST.KOJIN_NO := I_NNUSHI_KOJIN_NO;
      --算定団体コード
      R_02CALPASSUPD_LST.SANTEIDANTAI_CD := i_NDANTAI;
      --調定年度
      R_02CALPASSUPD_LST.CHOTEI_NENDO := i_NCHOTEI_NENDO;
      --年度分
      R_02CALPASSUPD_LST.NENDO_BUN := i_NNENDO_BUN;
      --通知書番号
      R_02CALPASSUPD_LST.TSUCHI_NO := I_NTSUCHI_NO;
      --賦課期日
      R_02CALPASSUPD_LST.FUKAKIJITU := FUKAKIJITSU;
      --納期限
      R_02CALPASSUPD_LST.NOKIGEN := NOKIGEN;
      --通知書発布日
      R_02CALPASSUPD_LST.HAPPU_BI:= i_TOTATSU_BI;
      --作成日
      R_02CALPASSUPD_LST.SAKUSEI_BI := i_KIJUN_BI;


      INSERT INTO ZLBW_02CALPASSUPD_LST VALUES R_02CALPASSUPD_LST;

      RETURN(I_RESULT);

      EXCEPTION
        WHEN OTHERS THEN
          I_RESULT := 9;
          ROLLBACK;
      RETURN(I_RESULT);
  END FUNC_DATE_CREATE;

  BEGIN
    IRTN  := 0;
    OLD_NENZEI  := 0;            --WK計算後年税額
    NEW_NENZEI  := 0;            --WK計算前年税額
    F4_SHIK_KBN := 0;            --賦課期日時点
    KANENDO_TAISHO_GEN := 0;     --WK過年度計算対象年減額
    KANENDO_TAISHO_ZO  := 0;     --WK過年度計算対象年増額
    T_YEAR_DATE        := 0;     --資格取得日の２年後日付の取得
    HANTEI_KBN         := 0;     --計算対象区分

    FUKA_END           := 0;     --賦課最終
    IDO_DATE           := 0;     --資格異動
    --計算後年税額取得
    FOR RKIHON_CAL IN KIHON_CAL LOOP
      --以下のテーブルの年税額(NENZEI)を合計する。
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--      OLD_NENZEI := RKIHON_CAL.KI_NENZEI + RKIHON_CAL.KA_NENZEI + RKIHON_CAL.SI_NENZEI;
      OLD_NENZEI := RKIHON_CAL.KI_NENZEI + RKIHON_CAL.KA_NENZEI + RKIHON_CAL.SI_NENZEI + RKIHON_CAL.KDM_NENZEI;
    END LOOP;

    --計算前年税額取得
    FOR RKIHON_N IN KIHON_N LOOP
      --以下のテーブルの年税額(NENZEI)を合計する。
--  2025/08/11 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
--      NEW_NENZEI := RKIHON_N.KI_NENZEI + RKIHON_N.KA_NENZEI + RKIHON_N.SI_NENZEI;
      NEW_NENZEI := RKIHON_N.KI_NENZEI + RKIHON_N.KA_NENZEI + RKIHON_N.SI_NENZEI + RKIHON_N.KDM_NENZEI;
    END LOOP;

    --過年度計算対象年
    FOR RJOKEN IN JOKEN LOOP
      KANENDO_TAISHO_GEN := RJOKEN.KANENDO_TAISHO_GEN;  --WK過年度計算対象年減額
      KANENDO_TAISHO_ZO  := RJOKEN.KANENDO_TAISHO_ZO;   --WK過年度計算対象年増額
    END LOOP;

    IF KANENDO_TAISHO_ZO > 0 THEN
      KANENDO_TAISHO_ZO2 := KANENDO_TAISHO_ZO - 1;
    END IF;

    --主課税条件
    FOR RJOKEN_NUSHI IN JOKEN_NUSHI LOOP
      NUSHIKAZEI := RJOKEN_NUSHI.NUSHI_KAZEI; --主課税
    END LOOP;

    --賦課期日
    FOR RJOKEN_JITSU IN JOKEN_JITSU LOOP
      FUKAKIJITSU := RJOKEN_JITSU.FUKAKIJITSU;          --賦課期日
      FUKA_END    := KKAPK0020.FDATECAL(RJOKEN_JITSU.FUKAKIJITSU,0,0,0,1);    --賦課最終
    END LOOP;

    --年税額の増減判定
    IF OLD_NENZEI >= NEW_NENZEI THEN
      --[WK計算後年税額]＞＝[WK計算前年税額]の場合、年税額が増額と判断する。
      NENZEI := TRUE;

      --年税額が増額の場合、以下の情報を取得する。
      FOR RKOJIN_CAL IN KOJIN_CAL LOOP

         FOR RKSCFKSNJKK_NOKIGEN IN KSCFKSNJKK_NOKIGEN LOOP
             KIWARIDANTAI_CD := RKSCFKSNJKK_NOKIGEN.KIWARIDANTAI_CD;   --期割団体コード
             DANTAING_KBN    := RKSCFKSNJKK_NOKIGEN.DANTAING_KBN;      --団体内外区分
             GENNENKANEN_KBN := 0;   --現年過年区分
         END LOOP;

         FOR NIDX IN 1..13 LOOP

             RSHUNOJKNK.KAMOKU_CD       := 15;
             RSHUNOJKNK.KAMOKUS_CD      := 1;
             RSHUNOJKNK.KIWARIDANTAI_CD := KIWARIDANTAI_CD;
             RSHUNOJKNK.DANTAING_KBN    := DANTAING_KBN;
             RSHUNOJKNK.CHOTEINENDO     := i_NCHOTEI_NENDO;
             RSHUNOJKNK.GENNENKANEN_KBN := GENNENKANEN_KBN;
             RSHUNOJKNK.RONRIKIBETSU    := NIDX;

             --第一期納期限を取得
             IRTN := KSCFKSNJKK(RSHUNOJKNK);

             --RSHUNOJKNK.HYOJIYOKIBETSUKが1のRSHUNOJKNK.NOKIGENを第一期納期限とする。
             --RSHUNOJKNK.HOTEINOKIGEN_KBNが1の納期限を取得する。なければ１期の納期限。
             IF RSHUNOJKNK.HOTEINOKIGEN_KBN = 1 THEN
                NOKIGEN := RSHUNOJKNK.NOKIGEN;
                IF (NOKIGEN IS NOT NULL AND NOKIGEN > 0) THEN
                  EXIT;-- 法定納期限が入れば終了
                END IF;
             END IF;
             IF (NOKIGEN IS NULL OR NOKIGEN = 0) AND RSHUNOJKNK.HYOJIYOKIBETSU = 1 THEN
                NOKIGEN := RSHUNOJKNK.NOKIGEN;
             END IF;
         END LOOP;

         IF NUSHIKAZEI = 1 THEN
           -- 世帯主課税の場合主変更日を見る
           SELECT NVL(MAX(NUSHI_TEKI_SBI),0)
             INTO IDO_DATE
             FROM ZLBTNUSHI_TMP
            WHERE SAKUJO_KBN <> 9
              AND KOKU_SETAI_NO =  i_NKOKU_SETAI_NO
              AND NUSHI_KOJIN_NO = i_NNUSHI_KOJIN_NO
              AND NUSHI_TEKI_SBI >= FUKAKIJITSU
              AND NUSHI_TEKI_SBI <  FUKA_END;
         END IF;

        --資格取得日の２年後の日付を取得する。
           IF IDO_DATE = 0 THEN
              IDO_DATE := RKOJIN_CAL.NEW_SHUTOK_BI;
           END IF;
           T_YEAR_DATE := KKAPK0020.FDATECAL(IDO_DATE,0,0,0,KANENDO_TAISHO_ZO);

        F4_SHIK_KBN := RKOJIN_CAL.F4_SHIK_KBN;         --賦課期日時点
      END LOOP;

    ELSE
      --[WK計算後年税額]＜[WK計算前年税額]の場合、年税額が減額と判断する。
      NENZEI := FALSE;
    END IF;

    --リターンコード(計算対象区分)を設定する
    o_NRTN := FUNSUM_KBN;

     --リストワークテーブル[ZLBW_02CALPASSUPD_LST]の更新
    o_NRTN := FUNC_DATE_CREATE;
  EXCEPTION
     WHEN OTHERS THEN
          o_NRTN := 9;
          ROLLBACK;
END;
/
