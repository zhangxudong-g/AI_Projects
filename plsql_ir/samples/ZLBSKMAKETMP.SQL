CREATE OR REPLACE PROCEDURE ZLBSKMAKETMP(
--1.1.200.000
                            i_SHIME_NENGETSU IN  NUMBER,
                            i_NENDO          IN  NUMBER,
                            i_CAL_KBN        IN  NUMBER,
                            i_KARA_NENGAPPI  IN  NUMBER,
                            i_MADE_NENGAPPI  IN  NUMBER,
                            i_KIJUN_NENGAPPI IN  NUMBER,
                            i_NJIKKOU_KBN    IN  NUMBER,
                            i_VMASIN_NO      IN  NVARCHAR2,
                            i_NTRENBAN       IN  NUMBER,
                            o_RTN            OUT NUMBER,
                            i_YOBIDASHI_KBN  IN PLS_INTEGER := 0 --呼び出し区分（0:通常、1:調交時）
                                               ) IS

------------------------------------------------------------------------------
--  業務名       ZLB(国保税)                                                --
--  PG 名        ZLBSKMAKETMP                                               --
--  名称         テンポラリTBL作成                                          --
--  処理概要     計算対象に存在する国保世帯番号を有する                     --
--               世帯または個人の情報を以下のテンポラリTBLにSaveする。      --
--  引数         i_NTRENBAN         登録連番                                --
--               i_SHIME_NENGETSU   〆年月                                  --
--               i_NENDO            年度                                    --
--               i_CAL_KBN          現年過年区分 (0：現年 1：過年)          --
--               i_KARA_NENGAPPI    から日付                                --
--               i_MADE_NENGAPPI    まで日付                                --
--               i_KIJUN_NENGAPPI   基準日                                  --
--               i_NJIKKOU_KBN      実行区分(0:バッチから起動 本算定/月例...--
--                                           1:オンライン起動 即時)         --
--               i_VMASIN_NO        端末番号                                --
--               i_NTRENBAN         登録連番                                --
--               o_RTN              戻り値                                  --
--  作成者       ZCZL.BAOZEXIN                                              --
--  作成日       2023/08/02                                                 --
--  Version      0.2.000.000                                                --
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--  変更履歴
--  2024/02/05 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.000:新WizLIFE２次開発
--2024/09/23 ZCZL.TAOYAN UPDATE 0.3.000.001:国保2次故障対応_IT_ZLB_00020
--  2025/08/11 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応
------------------------------------------------------------------------------
-- =========================================================================
-- コンスト定義
-- =========================================================================

    -- 戻り値
    c_NRTN_0          NUMBER(2)   := 0;        -- 正常
    c_NRTN_9          NUMBER(2)   := 9;        -- 異常
    c_NRTN_ERRLOG     NUMBER(2)   := 1;        -- 異常（ログ用）

    -- 現年過年区分
    c_CAL_KBN_GEN     NUMBER(2)   := 0;        -- 現年
    c_CAL_KBN_KA      NUMBER(2)   := 1;        -- 過年

    -- ログ連番
    c_LOG_99          NUMBER(2)   := 99;       --

    -- 実行区分
    c_NBATCH        CONSTANT NUMBER(1) := 0;        -- バッチから起動
    c_NONLNIN       CONSTANT NUMBER(1) := 1;        -- オンライン起動

    -- 合併後算定団体
    c_NDANTAI       CONSTANT NUMBER(2) := 1;   -- 合併後算定団体

    -- 不均一課税
    c_NFKAZEI       CONSTANT NUMBER := 1;      -- 不均一課税を行なう
    -- 市町村コード
    c_MINOO         CONSTANT PLS_INTEGER := 27220;  -- 箕面市

-- =========================================================================
-- ローカル変数
-- =========================================================================

    IlRTN            PLS_INTEGER;      -- 戻り値
    BlRTN            BOOLEAN;          -- 戻り値

    VlERRBUF         NVARCHAR2(100);   -- エラー

    -- システム条件より取得
    NlSHIME_NENGETSU2 NUMBER(6);

    NlFUKI_KAZEI      NUMBER;         -- 不均一課税
    NlNUSHI_KAZEI     NUMBER;         -- 主課税条件
    IlSHICHOSON_CD    PLS_INTEGER := 0; -- 市町村コード
    vSQL      VARCHAR2(4000);

-- =========================================================================
-- パラメータ変数
-- =========================================================================

    NlSHIME_NENGETSU  NUMBER(6);
    NlNENDO           NUMBER(4);
    NlCAL_KBN         NUMBER(1);
    NlKARA_NENGAPPI   NUMBER(8);
    NlMADE_NENGAPPI   NUMBER(8);
    NlKIJUN_NENGAPPI  NUMBER(8);

    NlNTRENBAN        NUMBER(15);

-------------------------------------------------------------------------------
-- xx システム条件の読込み(主課税条件取得)
-------------------------------------------------------------------------------
    FUNCTION funcJokenSel2(i_NwKOKU_SETAI_NO IN NUMBER, o_VlERRBUF OUT NVARCHAR2) RETURN NUMBER IS
        NwDANTAI        NUMBER;
        IwRTN           PLS_INTEGER := 0;
    BEGIN
        -- 不均一課税か否か判定
        IF NlFUKI_KAZEI = c_NFKAZEI THEN        -- 不均一課税を行なう
            -- 世帯の算定団体を取得する
            BEGIN
                SELECT DISTINCT OLD_JICHI_KBN INTO NwDANTAI
                FROM KHSTSETAI
                WHERE KOKU_SETAI_NO = i_NwKOKU_SETAI_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    IwRTN        := c_NRTN_9;
                    o_VlERRBUF   := 'ZLBTNUSHI_TMP世帯算定団体取得エラー(1)'||' 国保世帯番号='||i_NwKOKU_SETAI_NO;
                RETURN(IwRTN);
            END;
        ELSE
            -- 算定団体'1'で取得する
            NwDANTAI := c_NDANTAI;
        END IF;

        -- システム条件より税率条件を取得
        SELECT NUSHI_KAZEI INTO NlNUSHI_KAZEI    -- 主課税条件
          FROM ZLBTJOKEN
             WHERE NENDO           = i_NENDO
               AND SANTEIDANTAI_CD = NwDANTAI;
        RETURN(IwRTN);
    EXCEPTION
        WHEN OTHERS THEN
            IwRTN        := c_NRTN_9;
            o_VlERRBUF   := 'ZLBTNUSHI_TMP主課税条件取得エラー(1)'||' 国保世帯番号='||i_NwKOKU_SETAI_NO;
            RETURN(IwRTN);
    END funcJokenSel2;
-------------------------------------------------------------------------------
-- xx システム条件の読込み(不均一課税取得)
-------------------------------------------------------------------------------
    FUNCTION funcJokenSel(o_VlERRBUF OUT NVARCHAR2) RETURN NUMBER IS
        IwRTN  PLS_INTEGER := 0;
    BEGIN
        SELECT FUKI_KAZEI INTO NlFUKI_KAZEI -- 不均一課税取得
          FROM ZLBTJOKEN
         WHERE NENDO = i_NENDO
           AND SANTEIDANTAI_CD = c_NDANTAI;

         RETURN( IwRTN );

    EXCEPTION
        WHEN OTHERS THEN
            IwRTN        := c_NRTN_9;
            o_VlERRBUF   := 'ZLBTNUSHI_TMP不均一課税取得エラー(1)'||' 年度分='||i_NENDO;
        RETURN( IwRTN );
    END funcJokenSel;

------------------------------------------------------------------------------
--  01 資格基本　(ZLBTSHIKAKU_TMP) 作成（退職の異動に関して全面的に修正）   --
------------------------------------------------------------------------------
FUNCTION FUNC_SHIKAKU_TMP(o_VlERRBUF OUT NVARCHAR2) RETURN NUMBER IS
    IwRTN        PLS_INTEGER := 0;  -- 戻り値
    NwSETAI_NO   NUMBER      := 0;
    NwKOJIN_NO   NUMBER      := 0;
    IwR_NO       PLS_INTEGER := 0;
    IwTAI_R_NO   PLS_INTEGER := 0;
    IwSAKUJO_KBN PLS_INTEGER := 0;
    BwINSERT     BOOLEAN;
-- KHSTTAISHOKU.SAKUJO_KBN を取得するように変更
    CURSOR CNEW IS
      SELECT S.*, NVL(T.SAKUJO_KBN,0) SAKUJO_KBN_TAI
        FROM KHSTSHIKAKU_IDOKEI S,
             ZLBTKEISAN_TAISHO  K,
             KHSTTAISHOKU       T
        WHERE S.KOKU_SETAI_NO   = K.KOKU_SETAI_NO
          AND K.SYS_TANMATSU_NO = i_VMASIN_NO
          AND S.KOKU_SETAI_NO   = T.KOKU_SETAI_NO(+)
          AND S.KOJIN_NO        = T.KOJIN_NO(+)
          AND S.TAI_R_NO        = T.R_NO(+)
        ORDER BY S.KOKU_SETAI_NO, S.KOJIN_NO, S.R_NO DESC, S.SYS_KOSHINBI DESC, S.IDO_RENBAN DESC;
  BEGIN
    FOR CREC IN CNEW LOOP
        BwINSERT := FALSE;
        IF CREC.TAISHOKU_KBN = 0 OR CREC.SAKUJO_KBN_TAI = 9 THEN 
          CREC.TAI_R_NO := 0;  --退職区分が０ならば退職履歴番号は０とする
        END IF;

        IF NwSETAI_NO = CREC.KOKU_SETAI_NO AND NwKOJIN_NO = CREC.KOJIN_NO THEN
          --国保世帯番号または個人番号が同じ場合
          IF IwR_NO = CREC.R_NO THEN
            IF IwSAKUJO_KBN = 0 THEN  
              --履歴番号が同じ場合、退職履歴番号をチェック
              IF IwTAI_R_NO != CREC.TAI_R_NO AND IwTAI_R_NO > 0 AND CREC.TAI_R_NO > 0 THEN
                IF CREC.SHORIBI <= NlKIJUN_NENGAPPI THEN  
                  IwTAI_R_NO := CREC.TAI_R_NO;
                  BwINSERT := TRUE;
                END IF;  
              END IF;
            END IF;  
          ELSE
            IF CREC.SHORIBI <= NlKIJUN_NENGAPPI THEN  
              --履歴番号が変わった場合
              IwR_NO     := CREC.R_NO;
              IwTAI_R_NO := CREC.TAI_R_NO;
              BwINSERT := TRUE;
              IwSAKUJO_KBN := CREC.SAKUJO_KBN;  
            END IF;  
          END IF;
        ELSE
          IF CREC.SHORIBI <= NlKIJUN_NENGAPPI THEN  
            --国保世帯番号または個人番号が変わった場合
            NwSETAI_NO := CREC.KOKU_SETAI_NO;
            NwKOJIN_NO := CREC.KOJIN_NO;
            IwR_NO     := CREC.R_NO;
            IwTAI_R_NO := CREC.TAI_R_NO;
            BwINSERT := TRUE;
            IwSAKUJO_KBN := CREC.SAKUJO_KBN;  
          END IF;  
        END IF;

        IF BwINSERT AND IwSAKUJO_KBN != 0 THEN
          --追加となる場合でも、削除区分が立っていれば追加しない
          BwINSERT := FALSE;
        END IF;

        IF BwINSERT THEN
            BEGIN
              INSERT INTO ZLBTSHIKAKU_TMP
                VALUES(CREC.KOKU_SETAI_NO,    CREC.OLD_JICHI_KBN,
                       CREC.KOJIN_NO,         CREC.R_NO,
                       CREC.SHIK_KBN,         CREC.KISAI_JUNI,
                       CREC.ZOKU_KBN,
                       CREC.ZOKUGARA_CD1,     CREC.ZOKUGARA_CD2,
                       CREC.ZOKUGARA_CD3,     CREC.ZOKUGARA_CD4,
                       CREC.ZOKU_NAME,        CREC.HYOJI_ZOKU,
                       CREC.SHUTOKU_BI,       CREC.Z_SHUTOKU_BI,
                       CREC.SHUTOKU_JIYU,     CREC.SHUTOKU_TODOKE_BI,
                       CREC.SOSHITSU_BI,      CREC.Z_SOSHITSU_BI,
                       CREC.SOSHITSU_JIYU,    CREC.SOSHITSU_TODOKE_BI,
                       CREC.IDO_BI,           CREC.JIYU,
                       CREC.TODOKE_BI,
                       CREC.TENKYO_KBN,       CREC.TEN_KOKU_SETAI_NO,
                       CREC.TAISHOKU_KBN,
                       CREC.GAI_BI,           CREC.Z_GAI_BI,
                       CREC.GAI_TODOKE_BI,
                       CREC.HIGAI_BI,         CREC.Z_HIGAI_BI,
                       CREC.HIGAI_TODOKE_BI,
                       CREC.JUKYUKEN_S_BI,
                       CREC.JUKYU_NENK_NAME,  CREC.JUKYU_NENK_SHU,
                       CREC.TAI_R_NO,         CREC.TAI_HONIN,
                       CREC.TAI_ZOKUGARA_CD1, CREC.TAI_ZOKUGARA_CD2,
                       CREC.TAI_ZOKUGARA_CD3, CREC.TAI_ZOKUGARA_CD4,
                       CREC.TAI_ZOKU_NAME,
                       CREC.SHIK_KOSHIN_BI,   CREC.Z_KOSHIN_BI,
                       CREC.SAKUSEI_KBN,
                       CREC.SAKUJO_KBN,
                       CREC.IDO_RENBAN,       CREC.SHORIBI,
                       CREC.SYS_SAKUSEIBI,    CREC.SYS_KOSHINBI,
                       CREC.SYS_JIKAN,        CREC.SYS_SHOKUINKOJIN_NO,
                       i_VMASIN_NO);
            EXCEPTION
              WHEN OTHERS THEN
                IwRTN        := c_NRTN_9;
                o_VlERRBUF   := 'ZLBTSHIKAKU_TMP登録エラー(1)'||' 国保世帯番号='||CREC.KOKU_SETAI_NO;
                EXIT;
            END;
        END IF;

      EXIT WHEN IwRTN != c_NRTN_0;
    END LOOP;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;
    RETURN( IwRTN );
END FUNC_SHIKAKU_TMP;

------------------------------------------------------------------------------
--  01 資格基本　(ZLBTSHIKAKU_TMP) 作成（その２）                           --
------------------------------------------------------------------------------
FUNCTION FUNC_SHIKAKU_TMP_2(o_VlERRBUF OUT NVARCHAR2) RETURN NUMBER IS

    IwRTN       PLS_INTEGER := 0;          -- 戻り値
    NwKOJIN_NO  NUMBER := 0;
    IwR_NO      PLS_INTEGER := 0;  
    IwTAI_R_NO  PLS_INTEGER := 0;  

    -- 計算対象に存在するが、資格基本TMPに存在しない国保世帯番号を抽出するカーソル
    CURSOR CTAISHO IS
      SELECT A.KOKU_SETAI_NO
        FROM ZLBTKEISAN_TAISHO A
        WHERE A.SYS_TANMATSU_NO = i_VMASIN_NO
          AND NOT EXISTS (SELECT * FROM ZLBTSHIKAKU_TMP B
                            WHERE B.KOKU_SETAI_NO = A.KOKU_SETAI_NO);

    --資格異動累計の最新を取得するカーソル
    CURSOR CNEW(p_KOKU_SETAI_NO IN NUMBER) IS
      SELECT * FROM KHSTSHIKAKU_IDOKEI
        WHERE KOKU_SETAI_NO = p_KOKU_SETAI_NO
        ORDER BY KOKU_SETAI_NO, KOJIN_NO, R_NO DESC,
                 TAI_R_NO DESC,                       
                 SYS_KOSHINBI DESC, IDO_RENBAN DESC;
  BEGIN

    FOR CRTAISHO IN CTAISHO LOOP
      NwKOJIN_NO := 0;

      FOR CRNEW IN CNEW(CRTAISHO.KOKU_SETAI_NO) LOOP
        IF NwKOJIN_NO != CRNEW.KOJIN_NO THEN
          NwKOJIN_NO := CRNEW.KOJIN_NO;
          IwR_NO := 0;
          IwTAI_R_NO := 0;  
        END IF;

        IF IwR_NO != CRNEW.R_NO OR (IwR_NO = CRNEW.R_NO AND IwTAI_R_NO != CRNEW.TAI_R_NO) THEN
          IwR_NO := CRNEW.R_NO;
          IwTAI_R_NO := CRNEW.TAI_R_NO; 

          IF CRNEW.SAKUJO_KBN = 0 THEN  

            BEGIN
              INSERT INTO ZLBTSHIKAKU_TMP
                VALUES(CRNEW.KOKU_SETAI_NO,
                       CRNEW.OLD_JICHI_KBN,
                       CRNEW.KOJIN_NO,
                       CRNEW.R_NO,
                       CRNEW.SHIK_KBN,
                       CRNEW.KISAI_JUNI,
                       CRNEW.ZOKU_KBN,
                       CRNEW.ZOKUGARA_CD1,
                       CRNEW.ZOKUGARA_CD2,
                       CRNEW.ZOKUGARA_CD3,
                       CRNEW.ZOKUGARA_CD4,
                       CRNEW.ZOKU_NAME,
                       CRNEW.HYOJI_ZOKU,
                       CRNEW.SHUTOKU_BI,
                       CRNEW.Z_SHUTOKU_BI,
                       CRNEW.SHUTOKU_JIYU,
                       CRNEW.SHUTOKU_TODOKE_BI,
                       CRNEW.SOSHITSU_BI,
                       CRNEW.Z_SOSHITSU_BI,
                       CRNEW.SOSHITSU_JIYU,
                       CRNEW.SOSHITSU_TODOKE_BI,
                       CRNEW.IDO_BI,
                       CRNEW.JIYU,
                       CRNEW.TODOKE_BI,
                       CRNEW.TENKYO_KBN,
                       CRNEW.TEN_KOKU_SETAI_NO,
                       CRNEW.TAISHOKU_KBN,
                       CRNEW.GAI_BI,
                       CRNEW.Z_GAI_BI,
                       CRNEW.GAI_TODOKE_BI,
                       CRNEW.HIGAI_BI,
                       CRNEW.Z_HIGAI_BI,
                       CRNEW.HIGAI_TODOKE_BI,
                       CRNEW.JUKYUKEN_S_BI,
                       CRNEW.JUKYU_NENK_NAME,
                       CRNEW.JUKYU_NENK_SHU,
                       CRNEW.TAI_R_NO,
                       CRNEW.TAI_HONIN,
                       CRNEW.TAI_ZOKUGARA_CD1,
                       CRNEW.TAI_ZOKUGARA_CD2,
                       CRNEW.TAI_ZOKUGARA_CD3,
                       CRNEW.TAI_ZOKUGARA_CD4,
                       CRNEW.TAI_ZOKU_NAME,
                       CRNEW.SHIK_KOSHIN_BI,
                       CRNEW.Z_KOSHIN_BI,
                       CRNEW.SAKUSEI_KBN,
                       CRNEW.SAKUJO_KBN,
                       CRNEW.IDO_RENBAN,
                       CRNEW.SHORIBI,
                       CRNEW.SYS_SAKUSEIBI,
                       CRNEW.SYS_KOSHINBI,
                       CRNEW.SYS_JIKAN,
                       CRNEW.SYS_SHOKUINKOJIN_NO,
                       i_VMASIN_NO);
            EXCEPTION
              WHEN OTHERS THEN
                IwRTN        := c_NRTN_9;
                o_VlERRBUF   := 'ZLBTSHIKAKU_TMP登録エラー(2)'||' 国保世帯番号='||CRTAISHO.KOKU_SETAI_NO;
                EXIT;
            END;
          END IF;
        END IF;

      END LOOP;

      EXIT WHEN IwRTN != c_NRTN_0;
    END LOOP;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNC_SHIKAKU_TMP_2 ;

------------------------------------------------------------------------------
--  02 適用除外　(ZLBTTEKIJOGAI_TMP)  作成                                  --
------------------------------------------------------------------------------
FUNCTION FUNC_TEKIJOGAI_TMP(
                     o_VlERRBUF OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN              PLS_INTEGER;          -- 戻り値

    -- カーソル
    -- 適用除外　(ZLBTSHIKAKU_TMP)
    -- 資格基本TMPより個人番号毎に抽出
    CURSOR CZLBTSHIKAKU_TMP is
      SELECT DISTINCT S.KOJIN_NO KOJIN_NO
        FROM ZLBTKEISAN_TAISHO K,
             ZLBTSHIKAKU_TMP   S
       WHERE K.KOKU_SETAI_NO   = S.KOKU_SETAI_NO
         AND K.SYS_TANMATSU_NO = i_VMASIN_NO
      ;

      -- レコードセット
      RZLBTSHIKAKU_TMP CZLBTSHIKAKU_TMP%ROWTYPE;

  BEGIN

    IwRTN  := 0;

    FOR RZLBTSHIKAKU_TMP IN CZLBTSHIKAKU_TMP LOOP

      BEGIN
        -- 適用除外TMP INSERT
        -- 資格基本TMPより個人番号の基準日時点までの適用除外をins
        -- ※資格基本TMPより検索している為、条件は絞られる
        INSERT INTO ZLBTTEKIJOGAI_TMP
          SELECT KOJIN_NO,
                 R_NO,
                 NEW_KBN,
                 --  2024/02/05 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.000:新WizLIFE２次開発
                 -- TODOKE_BI,
                 --TEKIJOGAI_SBI,
                 --TEKIJOGAI_EBI,
                 KAISHI_TODOKE_BI,
                 TEKIJOGAI_SBI,
                 KAISHI_JIYU,
                 SYURYO_TODOKE_BI,
                 TEKIJOGAI_EBI,
                 SYURYO_JIYU,
                 --  2024/02/05 ZCZL.LIUCHANGQUAN UPDATE END
                 SHISETSU_KBN,
                 SAKUJO_KBN,
                 SHORIBI,
                 SYS_SAKUSEIBI,
                 SYS_KOSHINBI,
                 SYS_JIKAN,
                 SYS_SHOKUINKOJIN_NO,
                 i_VMASIN_NO
            FROM KHSTTEKIJOGAI
           WHERE KOJIN_NO =  RZLBTSHIKAKU_TMP.KOJIN_NO
             AND SHORIBI  <= NlKIJUN_NENGAPPI
        ;

      EXCEPTION
      WHEN OTHERS THEN
        IwRTN        := c_NRTN_9;
        o_VlERRBUF   := 'ZLBTTEKIJOGAI_TMP登録エラー'
                        ||' 宛名番号='||RZLBTSHIKAKU_TMP.KOJIN_NO
                        ;

        EXIT;  -- ループ終了

      END;

    END LOOP;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNC_TEKIJOGAI_TMP ;

------------------------------------------------------------------------------
--  03 軽減申請　(ZLBTKEIGEN_TMP)  作成                                     --
------------------------------------------------------------------------------
FUNCTION FUNC_KEIGEN_TMP(
                     o_VlERRBUF OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN              PLS_INTEGER;          -- 戻り値

  BEGIN

    IwRTN  := 0;

    BEGIN
      -- 軽減申請TMP INSERT
      -- 軽減申請より国保世帯番号を有する基準日時点までのデータをins
      INSERT /*+ APPEND */ INTO ZLBTKEIGEN_TMP
        SELECT KEIGEN.NENDO,
               KEIGEN.KOKU_SETAI_NO,
               KEIGEN.NUSHI_KOJIN_NO,
               KEIGEN.SHINSEI_KBN,
               KEIGEN.SHINSEI_BI,
               KEIGEN.CNT,
               KEIGEN.SHOTOKU,
               KEIGEN.SHORIBI,
               KEIGEN.SYS_SAKUSEIBI,
               KEIGEN.SYS_KOSHINBI,
               KEIGEN.SYS_JIKAN,
               KEIGEN.SYS_SHOKUINKOJIN_NO,
               i_VMASIN_NO
          FROM ZLBTKEISAN_TAISHO KEISAN,
               ZLBTKEIGEN        KEIGEN
         WHERE KEIGEN.KOKU_SETAI_NO   =  KEISAN.KOKU_SETAI_NO
           AND KEIGEN.NENDO           = KEISAN.NENDO_BUN
           AND KEIGEN.SHORIBI         <= NlKIJUN_NENGAPPI
           AND KEISAN.SYS_TANMATSU_NO =  i_VMASIN_NO
      ;

    EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := 'ZLBTKEIGEN_TMP登録エラー';
    END;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNC_KEIGEN_TMP ;

------------------------------------------------------------------------------
--  04 世帯基本　(ZLBTSETAI_TMP)  作成                                      --
------------------------------------------------------------------------------
FUNCTION FUNC_SETAI_TMP(
                     o_VlERRBUF OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN              PLS_INTEGER;          -- 戻り値

  BEGIN

    IwRTN  := 0;

    BEGIN
      -- 世帯基本TMP INSERT
      -- 世帯異動累計より国保世帯番号を有するデータをins
      -- ※異動管理より処理日が取得できなくてもok
      INSERT /*+ APPEND */ INTO ZLBTSETAI_TMP
        SELECT DISTINCT S.KOKU_SETAI_NO,
               S.OLD_JICHI_KBN,
               S.SHO_NO,
               S.SETAI_KBN,
               S.NUSHI_KOJIN_NO,
               S.CHOMEI,
               S.BANCHI,
               S.KATAGAKI,
               S.GYOSEIKU_CD,
               S.HAN_CD,
               S.ZEN_CNT,
               S.TAI_CNT,
               S.IDO_BI,
               S.TODOKE_BI,
               S.JIYU,
               S.IMAGE_NO,
               S.SAKUSEI_KBN,
               S.SAKUJO_KBN,
               S.IDO_RENBAN,
               S.SYS_SAKUSEIBI,
               S.SYS_KOSHINBI,
               S.SYS_JIKAN,
               S.SYS_SHOKUINKOJIN_NO,
               i_VMASIN_NO,
               NVL(I.SHORIBI,0)
          FROM ZLBTKEISAN_TAISHO K,
               KHSTSETAI_IDOKEI  S,
               KHSTIDOKANRI      I
         WHERE S.KOKU_SETAI_NO   = K.KOKU_SETAI_NO
           AND K.SYS_TANMATSU_NO = i_VMASIN_NO
           AND S.SAKUJO_KBN      = 0
           AND S.KOKU_SETAI_NO   = I.KOKU_SETAI_NO(+)
           AND S.IDO_RENBAN      = I.IDO_RENBAN(+)
           AND S.SYS_KOSHINBI    = I.SYS_KOSHINBI(+)
      ;

    EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := 'ZLBTSETAI_TMP登録エラー';
    END;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNC_SETAI_TMP ;

------------------------------------------------------------------------------
--  05 世帯主管理(ZLBTNUSHI_TMP) 作成                                       --
------------------------------------------------------------------------------
FUNCTION FUNC_NUSHI_TMP(
                     o_VlERRBUF OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN              PLS_INTEGER;          -- 戻り値

    -- カーソル
    -- 世帯主異動累計　(KHSTNUSHI_IDOKEI)
    -- 世帯主異動累計より履歴?ｖ?に抽出
    CURSOR CKHSTNUSHI_IDOKEI is
      SELECT DISTINCT N.KOKU_SETAI_NO KOKU_SETAI_NO,
                      N.R_NO          R_NO
        FROM ZLBTKEISAN_TAISHO K,
             KHSTNUSHI  N
       WHERE K.KOKU_SETAI_NO   = N.KOKU_SETAI_NO
         AND K.SYS_TANMATSU_NO = i_VMASIN_NO
      ORDER BY N.KOKU_SETAI_NO, N.R_NO
      ;

      -- レコードセット
      RKHSTNUSHI_IDOKEI CKHSTNUSHI_IDOKEI%ROWTYPE;

    CURSOR CKHSTNUSHI_IDOKEI2(p_KOKU_SETAI_NO IN NUMBER, p_R_NO IN NUMBER, p_KIJUN_NENGAPPI IN NUMBER) IS
      SELECT N.KOKU_SETAI_NO                AS KOKU_SETAI_NO,
             N.R_NO                         AS R_NO,
             N.NUSHI_TEKI_SBI               AS NUSHI_TEKI_SBI,
             N.NUSHI_KOJIN_NO               AS NUSHI_KOJIN_NO,
             N.SEISAN_FLAG                  AS SEISAN_FLAG,
             N.SAKUSEI_KBN                  AS SAKUSEI_KBN,
             N.SAKUJO_KBN                   AS SAKUJO_KBN,
             N.IDO_RENBAN                   AS IDO_RENBAN,
             N.SYS_SAKUSEIBI                AS SYS_SAKUSEIBI,
             N.SYS_KOSHINBI                 AS SYS_KOSHINBI,
             N.SYS_JIKAN                    AS SYS_JIKAN,
             N.SYS_SHOKUINKOJIN_NO          AS SYS_SHOKUINKOJIN_NO,
             i_VMASIN_NO                    AS SYS_TANMATSU_NO,
             NVL(I.SHORIBI, N.SYS_KOSHINBI) AS SHORIBI
        FROM KHSTNUSHI N,
             KHSTIDOKANRI     I
       WHERE N.KOKU_SETAI_NO   = p_KOKU_SETAI_NO
         AND N.R_NO            = p_R_NO
         AND TO_NUMBER(TO_CHAR(NVL(I.SHORIBI, N.SYS_KOSHINBI)) ||
                       TO_CHAR(N.SYS_KOSHINBI) ||
                       TO_CHAR(N.IDO_RENBAN))
                             = (SELECT MAX(TO_NUMBER(TO_CHAR(NVL(I2.SHORIBI, N2.SYS_KOSHINBI)) ||
                                                     TO_CHAR(N2.SYS_KOSHINBI) ||
                                                     TO_CHAR(N2.IDO_RENBAN)))
                                   FROM KHSTNUSHI N2,
                                       KHSTIDOKANRI     I2
                                 WHERE N2.KOKU_SETAI_NO = p_KOKU_SETAI_NO
                                   AND N2.R_NO          = p_R_NO
                                   AND N2.KOKU_SETAI_NO = I2.KOKU_SETAI_NO(+)
                                   AND N2.IDO_RENBAN    = I2.IDO_RENBAN(+)
                                   AND N2.SYS_KOSHINBI  = I2.SYS_KOSHINBI(+)
                                   AND NVL(I2.SHORIBI,N2.SYS_KOSHINBI) <= p_KIJUN_NENGAPPI
                               )
         AND   N.KOKU_SETAI_NO = I.KOKU_SETAI_NO(+)
         AND   N.IDO_RENBAN    = I.IDO_RENBAN(+)
         AND   N.SYS_KOSHINBI  = I.SYS_KOSHINBI(+)
         AND   SAKUJO_KBN      =  0
      ORDER BY N.NUSHI_TEKI_SBI
    ;
    --  2024/02/05 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.000:新WizLIFE２次開発
    --NwNUSHI_KOJIN_NO    NUMBER(12);  -- 世帯主個人番号
    NwNUSHI_KOJIN_NO    NUMBER;  -- 世帯主個人番号
    NwSEISAN_FLAG       NUMBER(1);   -- 清算フラグ
    NwKOKU_SETAI_NO     NUMBER := 0; 
  BEGIN

    IwRTN  := 0;
    NwNUSHI_KOJIN_NO := 0;
    NwSEISAN_FLAG    := 0;

    FOR RKHSTNUSHI_IDOKEI IN CKHSTNUSHI_IDOKEI LOOP

      IF NwKOKU_SETAI_NO != RKHSTNUSHI_IDOKEI.KOKU_SETAI_NO THEN
        NwKOKU_SETAI_NO  := RKHSTNUSHI_IDOKEI.KOKU_SETAI_NO;
        NwNUSHI_KOJIN_NO := 0;
        NwSEISAN_FLAG    := 0;
      END IF;

      IwRTN := funcJokenSel2(RKHSTNUSHI_IDOKEI.KOKU_SETAI_NO, o_VlERRBUF);
      IF IwRTN != c_NRTN_0 THEN
        EXIT;
      END IF;

      FOR RKHSTNUSHI_IDOKEI2 IN CKHSTNUSHI_IDOKEI2(RKHSTNUSHI_IDOKEI.KOKU_SETAI_NO, RKHSTNUSHI_IDOKEI.R_NO, NlKIJUN_NENGAPPI) LOOP
        NwSEISAN_FLAG := RKHSTNUSHI_IDOKEI2.SEISAN_FLAG;  --清算フラグそのままセット

        --世帯主個人番号が変わった最初のレコードの清算フラグを立てる
        IF NwNUSHI_KOJIN_NO != RKHSTNUSHI_IDOKEI2.NUSHI_KOJIN_NO THEN
          IF NlNUSHI_KAZEI = 2 AND NwNUSHI_KOJIN_NO > 0 THEN  --主課税（2:無条件に主課税、1:オンラインで主課税）
              -- 主課税するなら清算フラグを1
              NwSEISAN_FLAG := 1;
          END IF;
          NwNUSHI_KOJIN_NO := RKHSTNUSHI_IDOKEI2.NUSHI_KOJIN_NO;  --MOVE 2005/07/21
        END IF;
        BEGIN
          INSERT INTO ZLBTNUSHI_TMP
            VALUES(RKHSTNUSHI_IDOKEI2.KOKU_SETAI_NO,
                   RKHSTNUSHI_IDOKEI2.R_NO,
                   RKHSTNUSHI_IDOKEI2.NUSHI_TEKI_SBI,
                   RKHSTNUSHI_IDOKEI2.NUSHI_KOJIN_NO,
                   NwSEISAN_FLAG,
                   RKHSTNUSHI_IDOKEI2.SAKUSEI_KBN,
                   RKHSTNUSHI_IDOKEI2.SAKUJO_KBN,
                   RKHSTNUSHI_IDOKEI2.IDO_RENBAN,
                   RKHSTNUSHI_IDOKEI2.SYS_SAKUSEIBI,
                   RKHSTNUSHI_IDOKEI2.SYS_KOSHINBI,
                   RKHSTNUSHI_IDOKEI2.SYS_JIKAN,
                   RKHSTNUSHI_IDOKEI2.SYS_SHOKUINKOJIN_NO,
                   RKHSTNUSHI_IDOKEI2.SYS_TANMATSU_NO,
                   RKHSTNUSHI_IDOKEI2.SHORIBI);
        EXCEPTION
          WHEN OTHERS THEN
            IwRTN        := c_NRTN_9;
            o_VlERRBUF   := 'ZLBTNUSHI_TMP登録エラー'
                            ||' 国保世帯番号='||RKHSTNUSHI_IDOKEI.KOKU_SETAI_NO
                            ;
        END;
        EXIT WHEN IwRTN != c_NRTN_0;
      END LOOP;
      EXIT WHEN IwRTN != c_NRTN_0;

    END LOOP;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNC_NUSHI_TMP ;

------------------------------------------------------------------------------
--  05 世帯主管理(ZLBTNUSHI_TMP) 作成 （その２）                            --
------------------------------------------------------------------------------
FUNCTION FUNC_NUSHI_TMP_2(o_VlERRBUF OUT NVARCHAR2) RETURN NUMBER IS

    IwRTN  PLS_INTEGER := 0;          -- 戻り値
    IR_NO  PLS_INTEGER := 0;          --履歴番号

    -- 計算対象に存在するが、世帯主TMPに存在しない国保世帯番号を抽出するカーソル
    CURSOR CTAISHO IS
      SELECT DISTINCT A.KOKU_SETAI_NO
        FROM ZLBTKEISAN_TAISHO A
        WHERE A.SYS_TANMATSU_NO = i_VMASIN_NO
          AND NOT EXISTS (SELECT * FROM ZLBTNUSHI_TMP B
                            WHERE B.KOKU_SETAI_NO = A.KOKU_SETAI_NO);

    --世帯主異動累計の最新を取得するカーソル
    CURSOR CNEW(p_KOKU_SETAI_NO IN NUMBER) IS
      SELECT * FROM KHSTNUSHI
        WHERE KOKU_SETAI_NO = p_KOKU_SETAI_NO
        ORDER BY KOKU_SETAI_NO, R_NO DESC, SYS_KOSHINBI DESC, IDO_RENBAN DESC;

    --  2024/02/05 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.000:新WizLIFE２次開発
    --NwNUSHI_KOJIN_NO    NUMBER(12) := 0;  -- 世帯主個人番号
    NwNUSHI_KOJIN_NO    NUMBER := 0;  -- 世帯主個人番号
    NwSEISAN_FLAG       NUMBER(1)  := 0;   -- 清算フラグ
    NwKOKU_SETAI_NO     NUMBER := 0; 
  BEGIN

    FOR CRTAISHO IN CTAISHO LOOP
      IR_NO := 0;  
      IF NwKOKU_SETAI_NO != CRTAISHO.KOKU_SETAI_NO THEN
        NwKOKU_SETAI_NO  := CRTAISHO.KOKU_SETAI_NO;
        NwNUSHI_KOJIN_NO := 0;
        NwSEISAN_FLAG    := 0;
      END IF;

      IwRTN := funcJokenSel2(CRTAISHO.KOKU_SETAI_NO, o_VlERRBUF);
      IF IwRTN != c_NRTN_0 THEN
        EXIT;
      END IF;

      FOR CRNEW IN CNEW(CRTAISHO.KOKU_SETAI_NO) LOOP

        IF IR_NO != CRNEW.R_NO THEN
          IR_NO := CRNEW.R_NO;

          IF CRNEW.SAKUJO_KBN = 0 THEN

            NwSEISAN_FLAG := CRNEW.SEISAN_FLAG;  --清算フラグそのままセット
            --世帯主個人番号が変わった最初のレコードの清算フラグを立てる
            IF NwNUSHI_KOJIN_NO != CRNEW.NUSHI_KOJIN_NO THEN
              IF NlNUSHI_KAZEI = 2 AND NwNUSHI_KOJIN_NO > 0 THEN  --主課税（2:無条件に主課税、1:オンラインで主課税）
                -- 主課税するなら清算フラグを1
                NwSEISAN_FLAG := 1;
              END IF;
              NwNUSHI_KOJIN_NO := CRNEW.NUSHI_KOJIN_NO;
            END IF;

            BEGIN
              INSERT INTO ZLBTNUSHI_TMP
                VALUES(CRNEW.KOKU_SETAI_NO,
                       CRNEW.R_NO,
                       CRNEW.NUSHI_TEKI_SBI,
                       CRNEW.NUSHI_KOJIN_NO,
                       NwSEISAN_FLAG,
                       CRNEW.SAKUSEI_KBN,
                       CRNEW.SAKUJO_KBN,
                       CRNEW.IDO_RENBAN,
                       CRNEW.SYS_SAKUSEIBI,
                       CRNEW.SYS_KOSHINBI,
                       CRNEW.SYS_JIKAN,
                       CRNEW.SYS_SHOKUINKOJIN_NO,
                       i_VMASIN_NO,
                       CRNEW.SYS_KOSHINBI);
            EXCEPTION
              WHEN OTHERS THEN
                IwRTN        := c_NRTN_9;
                o_VlERRBUF   := 'ZLBTNUSHI_TMP登録エラー(2)'||' 国保世帯番号='||CRTAISHO.KOKU_SETAI_NO;
            END;

          END IF;  
        END IF;    

      END LOOP;

      EXIT WHEN IwRTN != c_NRTN_0;
    END LOOP;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNC_NUSHI_TMP_2 ;
------------------------------------------------------------------------------
--  06 賦課個人TMP(ZLBTEXTKJN_TMP) 作成                                      --
------------------------------------------------------------------------------
FUNCTION FUNC_EXTKJN_TMP(o_VlERRBUF OUT NVARCHAR2) RETURN NUMBER IS
    IwRTN        PLS_INTEGER := 0;  -- 戻り値
    NwSETAI_NO   NUMBER      := 0;
    NwKOJIN_NO   NUMBER      := 0;
    IwR_NO       PLS_INTEGER := 0;
    IwTAI_R_NO   PLS_INTEGER := 0;
    IwSAKUJO_KBN PLS_INTEGER := 0;
    BwINSERT     BOOLEAN;
    ISTA         PLS_INTEGER;
    IEND         PLS_INTEGER;

    -- カーソル、個人情報マスタより計算対象テーブルに格納されている対象世帯のデータを抽出
    -- 国保資格がある人で且つ障害者と外国人のレコードが存在した時だけ賦課個人TMPにInsert
    --老人も抽出対象者とする
    CURSOR CNEW IS
      SELECT K.* FROM ZLBTKEISAN_TAISHO  T,
                      ZLBTJOKEN          J,
                      ( SELECT A.KOKU_SETAI_NO, A.KOJIN_NO, MAX(A.R_NO) R_NO
                          FROM KHSTSHIKAKU A, ZLBTKEISAN_TAISHO B
                         WHERE A.KOKU_SETAI_NO = B.KOKU_SETAI_NO
                           AND B.SYS_TANMATSU_NO = i_VMASIN_NO
                           AND B.NENDO = i_NENDO  -- 調定年度
                           AND A.SAKUJO_KBN = 0
                           AND A.SHUTOKU_BI < B.NENDO_BUN * 10000 + 10401
                           AND A.SHUTOKU_BI <> A.SOSHITSU_BI
                         GROUP BY A.KOKU_SETAI_NO, A.KOJIN_NO ) X,
                      KHSTSHIKAKU        S,
                      KHSTKOJIN          K
      WHERE T.SYS_TANMATSU_NO = i_VMASIN_NO
        AND J.SANTEIDANTAI_CD = 1
        AND J.NENDO           = T.NENDO_BUN
        AND S.KOKU_SETAI_NO   =  T.KOKU_SETAI_NO
        AND S.KOKU_SETAI_NO   = X.KOKU_SETAI_NO
        AND S.KOJIN_NO        = X.KOJIN_NO
        AND S.R_NO            = X.R_NO
        AND S.SHUTOKU_BI <= (T.NENDO_BUN * 10000 + 10331)
        AND (S.SOSHITSU_BI >= (T.NENDO_BUN * 10000 + 401) OR S.SOSHITSU_BI = 0)
        AND K.KOKU_SETAI_NO   = S.KOKU_SETAI_NO
        AND K.KOJIN_NO        = S.KOJIN_NO
        AND (
             (IlSHICHOSON_CD <> c_MINOO AND ((K.K_SHURUI = 6 AND J.SINSHO_GENMEN   = 1) OR
                                             (K.K_SHURUI = 7 AND J.GAIKOKU_RYUGAKU = 1) OR
                                             (K.K_SHURUI = 2 AND K.K_DATA_KBN      = 1)
                                            )
             ) OR
             (IlSHICHOSON_CD =  c_MINOO AND ((K.K_SHURUI = 6 AND J.SINSHO_GENMEN   = 1) OR
                                             (K.K_SHURUI = 7 AND J.GAIKOKU_RYUGAKU = 1)
                                            )
             )
            )
        AND K.K_TEKI_SBI     <= (T.NENDO_BUN * 10000 + 10331)
        AND ((T.NENDO_BUN * 10000 + 401) <= K.K_TEKI_EBI OR K.K_TEKI_EBI = 0)
       ORDER BY K.KOKU_SETAI_NO, K.KOJIN_NO;

    BEGIN


      FOR CREC IN CNEW LOOP
          BEGIN
            INSERT INTO ZLBTEXTKJN_TMP
             VALUES(CREC.KOKU_SETAI_NO,
                       CREC.KOJIN_NO,
                       CREC.K_SHURUI,
                       CREC.K_DATA_KBN,
                       CREC.K_TEKI_SBI,
                       CREC.K_TEKI_EBI,
                       CREC.SYS_SAKUSEIBI,
                       CREC.SYS_KOSHINBI,
                       CREC.SYS_JIKAN,
                       CREC.SYS_SHOKUINKOJIN_NO,
                       i_VMASIN_NO);
          EXCEPTION
            WHEN OTHERS THEN
              IwRTN        := c_NRTN_9;
              o_VlERRBUF   := 'ZLBTEXTKJN_TMP登録エラー(1)'||' 国保世帯番号='||CREC.KOKU_SETAI_NO;
              EXIT;
          END;
      END LOOP;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;
    RETURN( IwRTN );
END FUNC_EXTKJN_TMP;
------------------------------------------------------------------------------
--  07 緩和対象TMP (ZLBTKANWA_TAISHO_TMP)  作成                                     --
------------------------------------------------------------------------------
FUNCTION FUNC_KANWA_TMP(
                     o_VlERRBUF OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN              PLS_INTEGER;          -- 戻り値

  BEGIN

    IwRTN  := 0;

    BEGIN
      -- 緩和対象より国保世帯番号を有する基準日時点までのデータをINSERT
      INSERT INTO ZLBTKANWA_TAISHO_TMP
        SELECT KOJIN_NO,
               R_NO,
               TAISHO_KBN,
               NEW_KBN,
               TODOKE_BI,
               TEKIJOGAI_SBI,
               TEKIJOGAI_EBI,
               SETAI_NO,
               KOKU_SETAI_NO,
               SAKUJO_KBN,
               SHORIBI,
               SYS_SAKUSEIBI,
               SYS_KOSHINBI,
               SYS_JIKAN,
               SYS_SHOKUINKOJIN_NO,
               i_VMASIN_NO
        FROM KHSTKANWA_TAISHO
        WHERE SAKUJO_KBN = 0;

    EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := 'FUNC_KANWA_TMP登録エラー';
    END;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNC_KANWA_TMP ;

------------------------------------------------------------------------------
--  08 減免個人TMP (ZLBTGENMEN_KOJIN_TMP)  作成                             --
------------------------------------------------------------------------------
FUNCTION FUNC_GENMEN_KOJIN_TMP( o_VlERRBUF OUT NVARCHAR2 ) RETURN NUMBER IS
        IwRTN     PLS_INTEGER;          -- 戻り値
        nCNT      NUMBER;
    BEGIN

        IwRTN  := 0;

        BEGIN

            -- ZLBTGENMEN_KOJIN テーブルの存在チェック
            SELECT count(*) INTO nCNT FROM USER_OBJECTS
            WHERE OBJECT_NAME = 'ZLBTGENMEN_KOJIN'
              AND OBJECT_TYPE = 'TABLE';

            IF nCNT = 1 THEN

                -- 減免データを計算用テーブルにコピー
                vSQL := 'INSERT INTO ZLBTGENMEN_KOJIN_TMP '     ||
                            'SELECT DISTINCT B.KOKU_SETAI_NO       , SANTEIDANTAI_CD       , KOJIN_NO     ,'                         ||         
                                   'B.NENDO_BUN           , B.NENDO_BUN           , 0                     ,'                         ||
                                   'KOJIN_NO              , SHINSEI_NO            ,'                                                 ||
                                   'SHINSEI_BI            , TORIKESHI_BI          , GENMEN_JIYU           ,'                         ||
                                   'YUSEN_KBN             , TEKIYO_KBN                                    ,'                         ||
                                   '0, 0, 0, 0, 0,'   ||
                                   '0, 0, 0, 0, 0,'   ||
                                   '0, 0, 0, 0, 0,'   ||
                                   '0, 0, 0, 0, 0,'   ||
                                   '0, 0, 0, 0, 0,'   ||
                                   '0, 0, 0, 0, 0,'   ||
                                   'I_SHOTOKU_RITSU       , I_SISANZEI_RITSU      , I_KINTOWARI_RITSU     ,'                         ||
                                   'I_BYODOWARI_RITSU     , I_NENZEI_RITSU        ,'                                                 ||
                                   'K_SHOTOKU_RITSU       , K_SISANZEI_RITSU      , K_KINTOWARI_RITSU     ,'                         ||
                                   'K_BYODOWARI_RITSU     , K_NENZEI_RITSU        ,'                                                 ||
                                   'S_SHOTOKU_RITSU       , S_SISANZEI_RITSU      , S_KINTOWARI_RITSU     ,'                         ||
                                   'S_BYODOWARI_RITSU     , S_NENZEI_RITSU        ,'                                                 ||
                                   'I_SHOTOKU_GENGAKU     , I_SISANZEI_GENGAKU    , I_KINTOWARI_GENGAKU   ,'                         ||
                                   'I_BYODOWARI_GENGAKU   , I_NENZEI_GENGAKU      , 0,'                                              ||
                                   'K_SHOTOKU_GENGAKU     , K_SISANZEI_GENGAKU    , K_KINTOWARI_GENGAKU   ,'                         ||
                                   'K_BYODOWARI_GENGAKU   , K_NENZEI_GENGAKU      , 0,'                                              ||
                                   'S_SHOTOKU_GENGAKU     , S_SISANZEI_GENGAKU    , S_KINTOWARI_GENGAKU   ,'                         ||
                                   'S_BYODOWARI_GENGAKU   , S_NENZEI_GENGAKU      , 0,'                                              ||
                                   'IT_SHOTOKU_GENGAKU    , IT_SISANZEI_GENGAKU   , IT_KINTOWARI_GENGAKU  ,'                         ||
                                   'IT_BYODOWARI_GENGAKU  , IT_NENZEI_GENGAKU     , 0,'                                              ||
                                   'KT_SHOTOKU_GENGAKU    , KT_SISANZEI_GENGAKU   , KT_KINTOWARI_GENGAKU  ,'                         ||
                                   'KT_BYODOWARI_GENGAKU  , KT_NENZEI_GENGAKU     , 0,'                                              ||
                                   'ST_SHOTOKU_GENGAKU    , ST_SISANZEI_GENGAKU   , ST_KINTOWARI_GENGAKU  ,'                         ||
                                   'ST_BYODOWARI_GENGAKU  , ST_NENZEI_GENGAKU     , 0,'                                              ||
                                   'I_GENMEN_4            , I_GENMEN_5            , I_GENMEN_6            , I_GENMEN_7            ,' ||
                                   'I_GENMEN_8            , I_GENMEN_9            , I_GENMEN_10           , I_GENMEN_11           ,' ||
                                   'I_GENMEN_12           , I_GENMEN_1            , I_GENMEN_2            , I_GENMEN_3            ,' ||
                                   'K_GENMEN_4            , K_GENMEN_5            , K_GENMEN_6            , K_GENMEN_7            ,' ||
                                   'K_GENMEN_8            , K_GENMEN_9            , K_GENMEN_10           , K_GENMEN_11           ,' ||
                                   'K_GENMEN_12           , K_GENMEN_1            , K_GENMEN_2            , K_GENMEN_3            ,' ||
                                   'S_GENMEN_4            , S_GENMEN_5            , S_GENMEN_6            , S_GENMEN_7            ,' ||
                                   'S_GENMEN_8            , S_GENMEN_9            , S_GENMEN_10           , S_GENMEN_11           ,' ||
                                   'S_GENMEN_12           , S_GENMEN_1            , S_GENMEN_2            , S_GENMEN_3            ,' ||
                                   '0, 0, 0, 0,'   ||
                                   'SAKUJO_KBN                                                                                    ,' ||
                                   '0, 0, 0, 0,'   ||
                                   '0, 0, 0, 0,'   ||
                                   '0, 0, 0, 0,'   ||
                                   'SYS_SAKUSEIBI         , SYS_KOSHINBI          , SYS_JIKAN             , SYS_SHOKUINKOJIN_NO   ,' ||
                                   '''' || i_VMASIN_NO || ''' '                   ||
--2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
                                   ',0, 0, 0, 0, 0, 0,'   ||
                                   'B.KDM_SHOTOKU_RITSU  , B.KDM_SISANZEI_RITSU  , B.KDM_KINTOWARI_RITSU  , B.KDM_KINTOWARI_18_RITSU      ,' ||
                                   'B.KDM_BYODOWARI_RITSU  , B.KDM_NENZEI_RITSU  , B.KDM_SHOTOKU_GENGAKU  , B.KDM_SISANZEI_GENGAKU      ,' ||
                                   'B.KDM_KINTOWARI_GENGAKU  , B.KDM_KINTOWARI_18_GENGAKU  , B.KDM_BYODOWARI_GENGAKU  , B.KDM_NENZEI_GENGAKU      ,' ||
                                   '0  , B.KDM_GENMEN_4  , B.KDM_GENMEN_5  , B.KDM_GENMEN_6  , B.KDM_GENMEN_7  , B.KDM_GENMEN_8  , B.KDM_GENMEN_9      ,' ||
                                   'B.KDM_GENMEN_10  , B.KDM_GENMEN_11  , B.KDM_GENMEN_12  , B.KDM_GENMEN_1  , B.KDM_GENMEN_2  , B.KDM_GENMEN_3 , 0 ,0  ' ||
--2025/08/11 ZCZL.LIUDI ADD END
                            'FROM ZLBTKEISAN_TAISHO A, ZLBTGENMEN_KOJIN B ' ||
                            'WHERE A.SYS_TANMATSU_NO = ''' || i_VMASIN_NO || ''' ' ||
                            'AND   A.KOKU_SETAI_NO   = B.KOKU_SETAI_NO  ' ||
--2024/09/23 ZCZL.TAOYAN UPDATE 0.3.000.001:国保2次故障対応_IT_ZLB_00020
                            --'AND   B.TEKIYO_KBN      = 1 ' ||
                            'AND   B.TEKIYO_KBN      IN (1, 3) ' ||
                            'AND   B.SAKUJO_KBN      = 0 ';
                EXECUTE IMMEDIATE vSQL;

            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                IwRTN      := c_NRTN_9;
                o_VlERRBUF := 'FUNC_GENMEN_KOJIN_TMP登録エラー';
        END;

        RETURN(IwRTN);

    END;
------------------------------------------------------------------------------
--  09 緩和対象TMP (ZLBTKANWA_TS_EX_TMP)  作成                          --
------------------------------------------------------------------------------
FUNCTION FUNC_KANWA_EX_TMP(
                     o_VlERRBUF OUT NVARCHAR2
                    ) RETURN NUMBER IS

    IwRTN              PLS_INTEGER;          -- 戻り値

  BEGIN

    IwRTN  := 0;

    BEGIN
      -- 緩和対象応益より国保世帯番号を有する基準日時点までのデータをINSERT
      INSERT INTO ZLBTKANWA_TS_EX_TMP
        SELECT KOJIN_NO,
               R_NO,
               TAISHO_KBN,
               NEW_KBN,
               TODOKE_BI,
               TEKIJOGAI_SBI,
               TEKIJOGAI_EBI,
               SETAI_NO,
               KOKU_SETAI_NO,
               SAKUJO_KBN,
               SHORIBI,
               SYS_SAKUSEIBI,
               SYS_KOSHINBI,
               SYS_JIKAN,
               SYS_SHOKUINKOJIN_NO,
               i_VMASIN_NO
        FROM KHSTKANWA_TAISHO_EX
        WHERE SAKUJO_KBN = 0;

    EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := 'FUNC_KANWA_EX_TMP登録エラー';
    END;

    RETURN( IwRTN );

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN        := c_NRTN_9;
      o_VlERRBUF   := SQLCODE||SQLERRM;

    RETURN( IwRTN );

END FUNC_KANWA_EX_TMP ;
------------------------------------------------------------------------------
--  00 メイン処理                                                           --
--    テンポラリTBL作成                                                     --
--    ①資格基本　(ZLBTSHIKAKU_TMP)                                         --
--    ②適用除外　(ZLBTTEKIJOGAI_TMP)                                       --
--    ③軽減申請　(ZLBTKEIGEN_TMP)                                          --
--    ④世帯基本　(ZLBTSETAI_TMP)                                           --
--    ⑤世帯主管理(ZLBTNUSHI_TMP)                                           --
------------------------------------------------------------------------------
BEGIN

    -- 初期処理
    IlRTN       := 0 ;

    -- パラメータ→変数
    NlSHIME_NENGETSU  :=  i_SHIME_NENGETSU;
    NlNENDO           :=  i_NENDO;
    NlCAL_KBN         :=  i_CAL_KBN;
    NlKARA_NENGAPPI   :=  i_KARA_NENGAPPI;
    NlMADE_NENGAPPI   :=  i_MADE_NENGAPPI;
    NlKIJUN_NENGAPPI  :=  i_KIJUN_NENGAPPI;
    NlNTRENBAN        :=  i_NTRENBAN;

    -- TMPテーブル削除
    IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
      IlRTN := KKAPK3000.FTRUNCATE('ZLBTSHIKAKU_TMP', VlERRBUF);     -- 資格基本
    ELSE
      BEGIN
        DELETE FROM ZLBTSHIKAKU_TMP WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
      EXCEPTION
        WHEN OTHERS THEN
          IlRTN    := c_NRTN_9;
          VlERRBUF := SQLERRM;
      END;
    END IF;
    IF IlRTN = c_NRTN_0 THEN
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        IlRTN := KKAPK3000.FTRUNCATE('ZLBTTEKIJOGAI_TMP', VlERRBUF); -- 適用除外
      ELSE
        BEGIN
          DELETE FROM ZLBTTEKIJOGAI_TMP WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
            IlRTN    := c_NRTN_9;
            VlERRBUF := SQLERRM;
        END;
      END IF;
    END IF;
    IF IlRTN = c_NRTN_0 THEN
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        IlRTN := KKAPK3000.FTRUNCATE('ZLBTKEIGEN_TMP', VlERRBUF);    -- 軽減申請
      ELSE
        BEGIN
          DELETE FROM ZLBTKEIGEN_TMP WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
            IlRTN    := c_NRTN_9;
            VlERRBUF := SQLERRM;
        END;
      END IF;
    END IF;
    IF IlRTN = c_NRTN_0 THEN
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        IlRTN := KKAPK3000.FTRUNCATE('ZLBTSETAI_TMP', VlERRBUF);     -- 世帯基本
      ELSE
        BEGIN
          DELETE FROM ZLBTSETAI_TMP WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
            IlRTN    := c_NRTN_9;
            VlERRBUF := SQLERRM;
        END;
      END IF;
    END IF;
    IF IlRTN = c_NRTN_0 THEN
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        IlRTN := KKAPK3000.FTRUNCATE('ZLBTNUSHI_TMP', VlERRBUF);     -- 世帯主管理
      ELSE
        BEGIN
          DELETE FROM ZLBTNUSHI_TMP WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
            IlRTN    := c_NRTN_9;
            VlERRBUF := SQLERRM;
        END;
      END IF;
    END IF;
    IF IlRTN = c_NRTN_0 THEN
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        IlRTN := KKAPK3000.FTRUNCATE('ZLBTEXTKJN_TMP', VlERRBUF);     -- 賦課個人TMP
      ELSE
        BEGIN
          DELETE FROM ZLBTEXTKJN_TMP WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
            IlRTN    := c_NRTN_9;
            VlERRBUF := SQLERRM;
        END;
      END IF;
    END IF;
    IF IlRTN = c_NRTN_0 THEN
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        IlRTN := KKAPK3000.FTRUNCATE('ZLBTKANWA_TAISHO_TMP', VlERRBUF);  -- 緩和対象TMP
      ELSE
        BEGIN
          DELETE FROM ZLBTKANWA_TAISHO_TMP WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
            IlRTN    := c_NRTN_9;
            VlERRBUF := SQLERRM;
        END;
      END IF;
    END IF;
    IF IlRTN = c_NRTN_0 THEN
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        BEGIN
          vSQL := 'TRUNCATE TABLE ZLBTGENMEN_KOJIN_TMP';
          EXECUTE IMMEDIATE vSQL;
        EXCEPTION
          WHEN OTHERS THEN
            -- テーブルがないことも考えられるので、エラーにはしない。
            NULL;
        END;
      ELSE
        BEGIN
          vSQL := 'DELETE FROM ZLBTGENMEN_KOJIN_TMP WHERE SYS_TANMATSU_NO = ''' || i_VMASIN_NO || '''';
          EXECUTE IMMEDIATE vSQL;
        EXCEPTION
          WHEN OTHERS THEN
            -- テーブルがないことも考えられるので、エラーにはしない。
            NULL;
        END;
      END IF;
    END IF;
    IF IlRTN = c_NRTN_0 THEN
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        IlRTN := KKAPK3000.FTRUNCATE('ZLBTKANWA_TS_EX_TMP', VlERRBUF);  -- 緩和対象応益TMP
      ELSE
        BEGIN
          DELETE FROM ZLBTKANWA_TS_EX_TMP WHERE SYS_TANMATSU_NO = i_VMASIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
            IlRTN    := c_NRTN_9;
            VlERRBUF := SQLERRM;
        END;
      END IF;
    END IF;
  IF IlRTN = c_NRTN_0 THEN
    -- 市町村コード取得
    IlSHICHOSON_CD := ZLBPK00010.FCUSERID(KKBPK5551.FBATCHDATEGET);

    -- 00賦課条件　（ZLBTJOKEN）取得
    IlRTN := funcJokenSel(VlERRBUF);

    IF IlRTN = c_NRTN_0 THEN
      -- ①01資格基本　(ZLBTSHIKAKU_TMP) 作成 --
      IlRTN := FUNC_SHIKAKU_TMP(VlERRBUF);
      IF IlRTN = c_NRTN_0 THEN

        IF i_YOBIDASHI_KBN = 1 THEN  
          -- ①（２）資格基本　(ZLBTSHIKAKU_TMP) 作成 --
          IlRTN := FUNC_SHIKAKU_TMP_2(VlERRBUF);
        END IF;  
        IF IlRTN = c_NRTN_0 THEN

          -- ②02適用除外　(ZLBTTEKIJOGAI_TMP)  作成 --
          IlRTN := FUNC_TEKIJOGAI_TMP(VlERRBUF);
          IF IlRTN = c_NRTN_0 THEN

            -- ③03軽減申請　(ZLBTKEIGEN_TMP)  作成 --
            IlRTN := FUNC_KEIGEN_TMP(VlERRBUF);
            IF IlRTN = c_NRTN_0 THEN

              -- ④04世帯基本　(ZLBTSETAI_TMP)  作成 --
              IlRTN := FUNC_SETAI_TMP(VlERRBUF);
              IF IlRTN = c_NRTN_0 THEN

                -- ⑤05世帯主管理(ZLBTNUSHI_TMP) 作成  --
                IlRTN := FUNC_NUSHI_TMP(VlERRBUF);
                IF IlRTN = c_NRTN_0 THEN

                    -- ⑤（２）05世帯主管理(ZLBTNUSHI_TMP) 作成  --
                    IlRTN := FUNC_NUSHI_TMP_2(VlERRBUF);
                  IF IlRTN = c_NRTN_0 THEN
                    IlRTN := c_NRTN_0 ;

                    -- ⑥06賦課個人TMP(ZLBTEXTKJN_TMP)  作成 --
                    IlRTN := FUNC_EXTKJN_TMP(VlERRBUF);
                    IF IlRTN = c_NRTN_0 THEN
                      IlRTN := c_NRTN_0 ;

                      -- ⑦07緩和対象TMP(ZLBTKANWA_TAISHO_TMP)  作成 --
                      IlRTN := FUNC_KANWA_TMP(VlERRBUF);
                      IF IlRTN = c_NRTN_0 THEN
                        -- ⑧08減免個人TMP(ZLBTGENMEN_KOJIN_TMP)  作成 --
                        IlRTN := FUNC_GENMEN_KOJIN_TMP(VlERRBUF);
                        IF IlRTN = c_NRTN_0 THEN
                          -- ⑨09緩和対象応益TMP(ZLBTKANWA_TS_EX_TMP)  作成 --
                          IlRTN := FUNC_KANWA_EX_TMP(VlERRBUF);
                          IF IlRTN = c_NRTN_0 THEN
                            -- 予備ルート
                            NULL;
                          ELSE
                            -- ログ出力
                            IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                              BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                                           ' ZLBSKMAKETMP FUNC_KANWA_EX_TMP 緩和対象応益TMP作成失敗 ' ||VlERRBUF
                                                           ||' 〆年月='||NlSHIME_NENGETSU
                                                           ||' 年度='||NlNENDO
                                                           ||' から日付='||NlKARA_NENGAPPI
                                                           ||' まで日付='||NlMADE_NENGAPPI
                                                           ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
                            ELSIF i_NTRENBAN = -1 THEN
                              -- テストの時のみ有効
                              DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_KANWA_EX_TMP 緩和対象応益TMP作成失敗 ' || VlERRBUF);
                            END IF;
                          END IF;
                        ELSE
                          -- ログ出力
                          IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                                         ' ZLBSKMAKETMP FUNC_GENMEN_KOJIN_TMP 減免個人TMP作成失敗 ' ||VlERRBUF
                                                         ||' 〆年月='||NlSHIME_NENGETSU
                                                         ||' 年度='||NlNENDO
                                                         ||' から日付='||NlKARA_NENGAPPI
                                                         ||' まで日付='||NlMADE_NENGAPPI
                                                         ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
                          ELSIF i_NTRENBAN = -1 THEN
                            -- テストの時のみ有効
                            DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_KANWA_TMP 減免個人TMP作成失敗 ' || VlERRBUF);
                          END IF;
                        END IF;
                      ELSE
                        -- ログ出力
                        IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                          BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                                       ' ZLBSKMAKETMP FUNC_KANWA_TMP 緩和対象TMP作成失敗 ' ||VlERRBUF
                                                       ||' 〆年月='||NlSHIME_NENGETSU
                                                       ||' 年度='||NlNENDO
                                                       ||' から日付='||NlKARA_NENGAPPI
                                                       ||' まで日付='||NlMADE_NENGAPPI
                                                       ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
                        ELSIF i_NTRENBAN = -1 THEN
                          -- テストの時のみ有効
                          DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_KANWA_TMP 緩和対象TMP作成失敗 ' || VlERRBUF);
                        END IF;
                      END IF;

                    ELSE
                      -- ログ出力
                      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                        BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                                     ' ZLBSKMAKETMP FUNC_EXTKJN_TMP 賦課個人TMP作成 ' ||VlERRBUF
                                                     ||' 〆年月='||NlSHIME_NENGETSU
                                                     ||' 年度='||NlNENDO
                                                     ||' から日付='||NlKARA_NENGAPPI
                                                     ||' まで日付='||NlMADE_NENGAPPI
                                                     ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
                      ELSIF i_NTRENBAN = -1 THEN
                        -- テストの時のみ有効
                        DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_EXTKJN_TMP 賦課個人TMP作成敗 ' || VlERRBUF);
                      END IF;
                    END IF;
                  ELSE
                    -- ログ出力
                    IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                      BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                                   ' ZLBSKMAKETMP FUNC_NUSHI_TMP 世帯主管理TMP作成(2) ' ||VlERRBUF
                                                   ||' 〆年月='||NlSHIME_NENGETSU
                                                   ||' 年度='||NlNENDO
                                                   ||' から日付='||NlKARA_NENGAPPI
                                                   ||' まで日付='||NlMADE_NENGAPPI
                                                   ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
                    ELSIF i_NTRENBAN = -1 THEN
                      -- テストの時のみ有効
                      DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_NUSHI_TMP 世帯主管理TMP作成敗(2) ' || VlERRBUF);
                    END IF;
                  END IF;
                ELSE
                  -- ログ出力
                  IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                    BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                                 ' ZLBSKMAKETMP FUNC_NUSHI_TMP 世帯主管理TMP作成 ' ||VlERRBUF
                                                 ||' 〆年月='||NlSHIME_NENGETSU
                                                 ||' 年度='||NlNENDO
                                                 ||' から日付='||NlKARA_NENGAPPI
                                                 ||' まで日付='||NlMADE_NENGAPPI
                                                 ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
                  ELSIF i_NTRENBAN = -1 THEN
                    -- テストの時のみ有効
                    DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_NUSHI_TMP 世帯主管理TMP作成敗 ' || VlERRBUF);
                  END IF;
                END IF;
              ELSE
                -- ログ出力
                IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                  BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                               ' ZLBSKMAKETMP FUNC_SETAI_TMP 世帯基本TMP作成 ' ||VlERRBUF
                                               ||' 〆年月='||NlSHIME_NENGETSU
                                               ||' 年度='||NlNENDO
                                               ||' から日付='||NlKARA_NENGAPPI
                                               ||' まで日付='||NlMADE_NENGAPPI
                                               ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
                ELSIF i_NTRENBAN = -1 THEN
                  -- テストの時のみ有効
                  DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_SETAI_TMP 世帯基本TMP作成敗 ' || VlERRBUF);
                END IF;
              END IF;
            ELSE
              -- ログ出力
              IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                             ' ZLBSKMAKETMP FUNC_KEIGEN_TMP 軽減申請TMP作成 ' ||VlERRBUF
                                             ||' 〆年月='||NlSHIME_NENGETSU
                                             ||' 年度='||NlNENDO
                                             ||' から日付='||NlKARA_NENGAPPI
                                             ||' まで日付='||NlMADE_NENGAPPI
                                             ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
              ELSIF i_NTRENBAN = -1 THEN
                -- テストの時のみ有効
                DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_KEIGEN_TMP 軽減申請TMP作成敗 ' || VlERRBUF);
              END IF;
            END IF;
          ELSE
            -- ログ出力
            IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
              BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                           ' ZLBSKMAKETMP FUNC_TEKIJOGAI_TMP 適用除外TMP作成 ' ||VlERRBUF
                                           ||' 〆年月='||NlSHIME_NENGETSU
                                           ||' 年度='||NlNENDO
                                           ||' から日付='||NlKARA_NENGAPPI
                                           ||' まで日付='||NlMADE_NENGAPPI
                                           ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
            ELSIF i_NTRENBAN = -1 THEN
              -- テストの時のみ有効
              DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_TEKIJOGAI_TMP 適用除外TMP作成敗 ' || VlERRBUF);
            END IF;
          END IF;
        ELSE
          -- ログ出力
          IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                         ' ZLBSKMAKETMP FUNC_SHIKAKU_TMP 資格基本TMP作成(2) ' ||VlERRBUF
                                         ||' 〆年月='||NlSHIME_NENGETSU
                                         ||' 年度='||NlNENDO
                                         ||' から日付='||NlKARA_NENGAPPI
                                         ||' まで日付='||NlMADE_NENGAPPI
                                         ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
          ELSIF i_NTRENBAN = -1 THEN
            -- テストの時のみ有効
            DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_SHIKAKU_TMP 資格基本TMP作成敗 ' || VlERRBUF);
          END IF;
        END IF;
      ELSE
        -- ログ出力
        IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
          BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                       ' ZLBSKMAKETMP FUNC_SHIKAKU_TMP 資格基本TMP作成 ' ||VlERRBUF
                                       ||' 〆年月='||NlSHIME_NENGETSU
                                       ||' 年度='||NlNENDO
                                       ||' から日付='||NlKARA_NENGAPPI
                                       ||' まで日付='||NlMADE_NENGAPPI
                                       ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
        ELSIF i_NTRENBAN = -1 THEN
          -- テストの時のみ有効
          DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP FUNC_SHIKAKU_TMP 資格基本TMP作成敗 ' || VlERRBUF);
        END IF;
      END IF;
    ELSE
      -- ログ出力
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                     ' ZLBSKMAKETMP 賦課条件参照失敗 ' ||VlERRBUF
                                     ||' 〆年月='||NlSHIME_NENGETSU
                                     ||' 年度='||NlNENDO
                                     ||' から日付='||NlKARA_NENGAPPI
                                     ||' まで日付='||NlMADE_NENGAPPI
                                     ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
      ELSIF i_NTRENBAN = -1 THEN
        -- テストの時のみ有効
        DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP TMP賦課条件参照失敗 ' || VlERRBUF);
      END IF;
    END IF;
  ELSE
      -- ログ出力
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, '', '', 
                                     ' ZLBSKMAKETMP TMPテーブル削除失敗 ' ||VlERRBUF
                                     ||' 〆年月='||NlSHIME_NENGETSU
                                     ||' 年度='||NlNENDO
                                     ||' から日付='||NlKARA_NENGAPPI
                                     ||' まで日付='||NlMADE_NENGAPPI
                                     ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
      ELSIF i_NTRENBAN = -1 THEN
        -- テストの時のみ有効
        DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP TMPテーブル削除失敗 ' || VlERRBUF);
      END IF;
  END IF;

    -- 確定処理
    IF IlRTN = c_NRTN_0 THEN
      BEGIN
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          IlRTN       := c_NRTN_9;
          -- ログ出力
          IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKMAKETMP', 1, SQLCODE, SQLERRM,' ZLBSKMAKETMP COMMIT失敗', '', i_VMASIN_NO);
          ELSIF i_NTRENBAN = -1 THEN
            -- テストの時のみ有効
            DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP COMMIT失敗 ' || SQLERRM);
          END IF;
      END;
    ELSE
      BEGIN
        ROLLBACK;
      EXCEPTION
        WHEN OTHERS THEN
          IlRTN       := c_NRTN_9;
          -- ログ出力
          IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKMAKETMP', 1, SQLCODE, SQLERRM,' ZLBSKMAKETMP ROLLBACK失敗', '', i_VMASIN_NO);
          ELSIF i_NTRENBAN = -1 THEN
            -- テストの時のみ有効
            DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP ROLLBACK失敗 ' || SQLERRM);
          END IF;
      END;
    END IF;

    o_RTN := IlRTN;

------------------------------------------------------------------------------
--  99 例外処理                                                             --
------------------------------------------------------------------------------
EXCEPTION

    /******************************************************/
    -- その他エラー
    /******************************************************/
    WHEN OTHERS THEN

      -- 異常終了
      IlRTN       := c_NRTN_9;

      -- ログ出力
      IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
        BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN, 'ZLBSKMAKETMP', 1, SQLCODE, SQLERRM, 
                                     ' ZLBSKMAKETMP 例外エラー ' ||SQLCODE||SQLERRM
                                     ||' 〆年月='||NlSHIME_NENGETSU
                                     ||' 年度='||NlNENDO
                                     ||' から日付='||NlKARA_NENGAPPI
                                     ||' まで日付='||NlMADE_NENGAPPI
                                     ||' 基準日='||NlKIJUN_NENGAPPI, '', i_VMASIN_NO);
      ELSIF i_NTRENBAN = -1 THEN
        -- テストの時のみ有効
        DBMS_OUTPUT.PUT_LINE('ZLBSKMAKETMP 例外エラー ' || SQLERRM);
      END IF;

    o_RTN := IlRTN;

END ZLBSKMAKETMP ;
/
