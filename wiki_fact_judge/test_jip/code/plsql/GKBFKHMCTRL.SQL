CREATE OR REPLACE FUNCTION GKBFKHMCTRL( i_nKOJIN_NO IN NUMBER,
--1.0.205.000-02.02-02.02
                                           i_sCHOHYOID    IN  NVARCHAR2,
                                           i_nHOGOSYA_KAN IN  NUMBER,
                                           i_nSYS_KAN     IN  NUMBER,
                                           o_sSHIMEIKANA  OUT NVARCHAR2,
                                           o_sSHIMEI      OUT NVARCHAR2,
                                           o_sBIRTHDAY    OUT NVARCHAR2,
--  2025/11/10 CTC.GL UPDATE START 1.0.205.000:GKB_QA22992対応
                                           i_nRIREKI_RENBAN  IN NUMBER DEFAULT 0
--  2025/11/10 CTC.GL UPDATE END
                                           )RETURN PLS_INTEGER
----------------------------------------------------------------------
--  業務名      GKB_教育
--  PG名        GKBFKHMCTRL
--  名称        本名使用制御判定
--  処理概要    宛名番号、システム制御設定、帳票IDは引数として渡し、氏名印字制御パラメータまたは本名使用制御設定により編集後の児童生徒氏名・生年月日を取得する 
--  引数        i_nKOJIN_NO           宛名番号
--              i_sCHOHYOID          帳票ID
--              i_nHOGOSYA_KAN       保護者区分　（0:保護者制御ではない、1:保護者制御する）
--              i_nSYS_KAN            システム制御設定
--              o_sSHIMEIKANA        氏名カナ
--              o_sSHIMEI            氏名漢字
--              o_sBIRTHDAY          生年月日
--  作成者       ZCZL.WANGYUNING
--  作成日       2024/06/03
--  VERSION     0.3.000.000
----------------------------------------------------------------------
--  変更履歴
--  2024/08/12 ZCZL.QINYUE UPDATE 0.3.000.001:検収指摘No.111の対応
--  2024/09/02 ZCZL.GUANHONG UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--  2024/10/10 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00277の対応
--  2024/10/18 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更：IT_GKB_00267対応
--  2024/11/01 ZCZL.WANGMING UPDATE 0.3.000.005:仕様変更：IT_GKB_00451対応
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00286横展開対応
--  2024/11/18 YAMANI.SASAKI UPDATE 0.3.000.007:仕様変更：IT_GKB_00611対応
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10058対応
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応
--  2025/11/10 CTC.GL UPDATE 1.0.205.000:GKB_QA22992対応
----------------------------------------------------------------------
IS
  --変数設定
  g_nRTN                             PLS_INTEGER := 0;                               --処理結果
  g_nCHOHYO_NO                       NUMBER := 0;                                     --帳票連番
  g_nSYS_KAN                         NUMBER := 0;                                     --システム制御設定
  g_nHONMYO_KAN                      NUMBER := 0;                                     --本名使用制御管理設定
  g_rSEINENGAPI                      NVARCHAR2(1000) := 0;                            --宛名基本-西暦生年月日
  g_rWAREKI_SEINENGAPI               NVARCHAR2(1000) := 0;                            --宛名基本-和暦生年月日
  g_rSHIMEI_KANA                     GABTATENAKIHON.SHIMEI_KANA%TYPE := NULL;            --宛名基本-氏名カナ
  g_rSHIMEI_KANJI                    GABTATENAKIHON.SHIMEI_KANJI%TYPE := NULL;           --宛名基本-氏名漢字
  g_rHONMYO_KANA                     GABTATENAKIHON.HONMYO_KANA%TYPE := NULL;            --宛名基本-本名カナ
  g_rHONMYO_KANJI                    GABTATENAKIHON.HONMYO_KANJI%TYPE := NULL;           --宛名基本-本名漢字
  g_rALP_SHIMEI_KANJI                GABTATENAKIHON.ALP_SHIMEI_KANJI%TYPE := NULL;       --宛名基本-アルファベット氏名漢字
  g_rGAI_SHIMEI_KANJI                GABTATENAKIHON.GAI_SHIMEI_KANJI%TYPE := NULL;       --宛名基本-外国人氏名漢字
  g_rTSUSHOMEI_KANA_KIHON            GABTATENAKIHON.TSUSHOMEI_KANA%TYPE := NULL;         --宛名基本-通称名カナ
  g_rTSUSHOMEI_KANJI_KIHON           GABTATENAKIHON.TSUSHOMEI_KANJI%TYPE := NULL;        --宛名基本-通称名漢字
  g_rTSUSHOMEI_KANA_KIIDO            GABTJUKIIDO.TSUSHOMEI_KANA%TYPE := NULL;            --住基異動-通称名カナ
  g_rTSUSHOMEI_KANJI_KIIDO           GABTJUKIIDO.TSUSHOMEI_KANJI%TYPE := NULL;           --住基異動-通称名漢字
  g_rTSUSHOMEI_KANA_REIBO            GKBTGAKUREIBO.TSUSHOMEI_KANA%TYPE := NULL;          --学齢簿-通称名
  g_rTSUSHOMEI_KANJI_REIBO           GKBTGAKUREIBO.TSUSHOMEI_KANJI%TYPE := NULL;         --学齢簿-通称名漢字
  g_rHOGOSYA_TSUSHOMEI_KANA_REIBO    GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA%TYPE := NULL;  --学齢簿-保護者通称名カナ
  g_rHOGOSYA_TSUSHOMEI_KANJI_REIBO   GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI%TYPE := NULL; --学齢簿-保護者通称名
  g_rJINKAKU_KBN                     GABTATENAKIHON.JINKAKU_KBN%TYPE;            --人格区分
  g_nHOGOSYA_KAN                     NUMBER := 0;                                     --保護者区分 
  g_nFCRTN                           NUMBER;                                          --FUNCTION処理結果
  g_eOTHERS                          EXCEPTION;
--  2024/08/12 ZCZL.QINYUE ADD START
  g_NAIYO_CD                         NUMBER;                                       --設定内容コード
--  2024/11/02 ZCZL.WANGMING UPDATE START 0.3.000.006:IT_GKB_00286横展開対応
    o_sEINENGAPI1                    GKAPK00020.SEINENGAPI_REC;           --生年月日
    o_sEINENGAPI2                    GKAPK00020.SEINENGAPI_REC;           --生年月日
--  2024/11/02 ZCZL.WANGMING UPDATE END

  -----------------------------------------------------------
  --  2.メイン処理
  -----------------------------------------------------------
  FUNCTION FUNC_MAIN RETURN NUMBER IS
    NRTN       NUMBER := 0;
    sSQL                              VARCHAR2(2000);
    TYPE MC_CURSOR IS REF CURSOR;
    cCURSOR                           MC_CURSOR;
    TYPE MR_PRINTPRM IS RECORD(
        v_KIHON_JINKAKU_KBN               GABTATENAKIHON.JINKAKU_KBN%TYPE,              --宛名基本.人格区分
        v_KIHON_SEINENGAPI                GABTATENAKIHON.SEINENGAPI%TYPE,               --宛名基本.生年月日
        v_KIHON_SHIMEI_KANA               GABTATENAKIHON.SHIMEI_KANA%TYPE,              --宛名基本.氏名カナ
        v_KIHON_SHIMEI_KANJI              GABTATENAKIHON.SHIMEI_KANJI%TYPE,             --宛名基本.氏名漢字
        v_KIHON_HONMYO_KANA               GABTATENAKIHON.HONMYO_KANA%TYPE,              --宛名基本.本名カナ
        v_KIHON_HONMYO_KANJI              GABTATENAKIHON.HONMYO_KANJI%TYPE,             --宛名基本.本名漢字
        v_KIHON_ALP_SHIMEI_KANJI          GABTATENAKIHON.ALP_SHIMEI_KANJI%TYPE,         --宛名基本.アルファベット
        v_KIHON_GAI_SHIMEI_KANJI          GABTATENAKIHON.GAI_SHIMEI_KANJI%TYPE,         --宛名基本.外国人氏名漢字
        v_KIHON_TSUSHOMEI_KANA            GABTATENAKIHON.TSUSHOMEI_KANA%TYPE,           --宛名基本.通称名カナ
        v_KIHON_TSUSHOMEI_KANJI           GABTATENAKIHON.TSUSHOMEI_KANJI%TYPE,          --宛名基本.通称名漢字
        v_KIIDO_TSUSHOMEI_KANA            GABTJUKIIDO.TSUSHOMEI_KANA%TYPE,              --住基異動.通称名カナ
        v_KIIDO_TSUSHOMEI_KANJI           GABTJUKIIDO.TSUSHOMEI_KANJI%TYPE,             --住基異動.通称名漢字
        v_REIBO_TSUSHOMEI_KANA            GKBTGAKUREIBO.TSUSHOMEI_KANA%TYPE,            --学齢簿.通称名カナ
        v_REIBO_TSUSHOMEI_KANJI           GKBTGAKUREIBO.TSUSHOMEI_KANJI%TYPE,           --学齢簿.通称名漢字
        v_REIBO_HOGOSYA_TSUSHOMEI_KANA    GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA%TYPE,    --学齢簿.保護者通称名カナ
        v_REIBO_HOGOSYA_TSUSHOMEI_KANJI   GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI%TYPE    --学齢簿.保護者通称名
    );
    rDATA                             MR_PRINTPRM;
--  2024/08/12 ZCZL.QINYUE ADD DELETE START
--    n_NAIYO_CD                        NUMBER;                                       --設定内容コード
  BEGIN
    BEGIN
        --  2-1.児童生徒の基本情報を取得する。
        --2-1-1.宛名基本、学齢簿、住基異動から児童生徒の基本情報を取得する。
          --'1-1.引数.保護者区分　＝　０（0：保護者制御しない）の場合、児童生徒の住基異動情報を取得する。
          
          sSQL:= '';
          sSQL := sSQL || ' SELECT  GABTATENAKIHON.JINKAKU_KBN,';    --宛名基本.人格区分
          sSQL := sSQL || ' GABTATENAKIHON.SEINENGAPI,';             --宛名基本.生年月日
          sSQL := sSQL || ' GABTATENAKIHON.SHIMEI_KANA,';            --宛名基本.氏名カナ
          sSQL := sSQL || ' GABTATENAKIHON.SHIMEI_KANJI,';           --宛名基本.氏名漢字
          sSQL := sSQL || ' GABTATENAKIHON.HONMYO_KANA,';            --宛名基本.本名カナ
          sSQL := sSQL || ' GABTATENAKIHON.HONMYO_KANJI,';           --宛名基本.本名漢字
          sSQL := sSQL || ' GABTATENAKIHON.ALP_SHIMEI_KANJI,';       --宛名基本.アルファベット氏名漢字
          sSQL := sSQL || ' GABTATENAKIHON.GAI_SHIMEI_KANJI,';       --宛名基本.外国人氏名漢字
          sSQL := sSQL || ' GABTATENAKIHON.TSUSHOMEI_KANA,';         --宛名基本.通称名カナ
          sSQL := sSQL || ' GABTATENAKIHON.TSUSHOMEI_KANJI,';        --宛名基本.通称名漢字
          sSQL := sSQL || ' GABTJUKIIDO.TSUSHOMEI_KANA,';            --住基異動.通称名カナ
          sSQL := sSQL || ' GABTJUKIIDO.TSUSHOMEI_KANJI,';           --住基異動.通称名漢字
          sSQL := sSQL || ' GKBTGAKUREIBO.TSUSHOMEI_KANA,';          --学齢簿.通称名カナ
          sSQL := sSQL || ' GKBTGAKUREIBO.TSUSHOMEI_KANJI,';         --学齢簿.通称名漢字
          sSQL := sSQL || ' GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA,';  --学齢簿.保護者通称名カナ
          sSQL := sSQL || ' GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI';  --学齢簿.保護者通称名
          sSQL := sSQL || ' FROM GABTATENAKIHON, ';  ---宛名基本
          sSQL := sSQL || ' GABTJUKIIDO, ';  --住基異動
          sSQL := sSQL || ' GKBTGAKUREIBO ';  --学齢簿                         
          IF i_nHOGOSYA_KAN = 0 THEN
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応　START
            --sSQL := sSQL || '  WHERE GABTATENAKIHON.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO';
            sSQL := sSQL || '  WHERE GABTATENAKIHON.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO(+)';
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応　END
--  2024/10/18 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更：IT_GKB_00267対応
--            sSQL := sSQL || '   AND GABTATENAKIHON.KOJIN_NO = GABTJUKIIDO.KOJIN_NO';
            sSQL := sSQL || '   AND GABTATENAKIHON.KOJIN_NO = GABTJUKIIDO.KOJIN_NO(+)';
            sSQL := sSQL || '   AND GABTATENAKIHON.KOJIN_NO =''' || i_nKOJIN_NO ||'''';
            sSQL := sSQL || '   AND GABTATENAKIHON.RIREKI_RENBAN = ( SELECT' ;
            sSQL := sSQL || '   MAX(RIREKI_RENBAN)' ;
            sSQL := sSQL || '   FROM GABTATENAKIHON ' ;
            sSQL := sSQL || '   WHERE KOJIN_NO = ''' || i_nKOJIN_NO || ''' )';
--  2024/10/18 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更：IT_GKB_00267対応
--            sSQL := sSQL || '   AND GABTJUKIIDO.KOJIN_NO = ''' || i_nKOJIN_NO|| '''';
            sSQL := sSQL || '   AND GABTJUKIIDO.KOJIN_NO(+) = ''' || i_nKOJIN_NO|| '''';
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応 START
            sSQL := sSQL || '   AND GKBTGAKUREIBO.KOJIN_NO(+) = ''' || i_nKOJIN_NO|| '''';
            sSQL := sSQL || '   AND GKBTGAKUREIBO.SAISHIN_KBN(+) = 0';
            --sSQL := sSQL || '   AND GKBTGAKUREIBO.KOJIN_NO = ''' || i_nKOJIN_NO|| '''';
            --sSQL := sSQL || '   AND GKBTGAKUREIBO.SAISHIN_KBN = 0';
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応 END
            --1-2.引数.保護者区分　＝　1（1：保護者制御する）の場合、保護者の住基異動情報を取得する。        
          ELSIF i_nHOGOSYA_KAN = 1 THEN
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応　START
            --sSQL := sSQL || '  WHERE GABTATENAKIHON.KOJIN_NO = GKBTGAKUREIBO.HOGOSYA_KOJIN_NO';
            sSQL := sSQL || '  WHERE GABTATENAKIHON.KOJIN_NO = GKBTGAKUREIBO.HOGOSYA_KOJIN_NO(+)';
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応　END
--  2024/09/02 ZCZL.GUANHONG Add 0.3.000.001:8月1日認識合わせの横展開
--  2024/10/18 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更：IT_GKB_00267対応
--            sSQL := sSQL || '   AND GABTATENAKIHON.KOJIN_NO = GABTJUKIIDO.KOJIN_NO';
            sSQL := sSQL || '   AND GABTATENAKIHON.KOJIN_NO = GABTJUKIIDO.KOJIN_NO(+)';
            sSQL := sSQL || '   AND GKBTGAKUREIBO.KOJIN_NO =''' || i_nKOJIN_NO ||'''';
--  2025/11/10 CTC.GL UPDATE START 1.0.205.000:GKB_QA22992対応
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応 START
            --sSQL := sSQL || '   AND GABTATENAKIHON.RIREKI_RENBAN = NVL(( SELECT' ;
            --sSQL := sSQL || '   AND GABTATENAKIHON.RIREKI_RENBAN = ( SELECT' ;
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応 END
            --sSQL := sSQL || '   MAX(RIREKI_RENBAN)' ;
            --sSQL := sSQL || '   FROM GABTATENAKIHON ' ;
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応 START
            --sSQL := sSQL || '   WHERE KOJIN_NO = GKBTGAKUREIBO.HOGOSYA_KOJIN_NO ),GABTATENAKIHON.RIREKI_RENBAN)';
            --sSQL := sSQL || '   WHERE KOJIN_NO = GKBTGAKUREIBO.HOGOSYA_KOJIN_NO )';
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応 END
--  2025/11/10 CTC.GL UPDATE END
--  2024/10/18 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更：IT_GKB_00267対応
--            sSQL := sSQL || '   AND GABTJUKIIDO.KOJIN_NO = GKBTGAKUREIBO.HOGOSYA_KOJIN_NO';
            sSQL := sSQL || '   AND GABTJUKIIDO.KOJIN_NO(+) = GKBTGAKUREIBO.HOGOSYA_KOJIN_NO';
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応 START
            --sSQL := sSQL || '   AND GKBTGAKUREIBO.SAISHIN_KBN = 0';
--  2025/11/10 CTC.GL UPDATE START 1.0.205.000:GKB_QA22992対応
--            sSQL := sSQL || '   AND GKBTGAKUREIBO.SAISHIN_KBN(+) = 0'; 
              IF i_nRIREKI_RENBAN = 0 THEN
                  sSQL := sSQL || ' AND GKBTGAKUREIBO.SAISHIN_KBN = 0';
              ELSE
                  sSQL := sSQL || ' AND GKBTGAKUREIBO.RIREKI_RENBAN = ' || i_nRIREKI_RENBAN;
              END IF;
--  2025/11/10 CTC.GL UPDATE END
--  2025/02/13 JPJYS.GONGYANYAN UPDATE 0.3.000.009:ST障害対応：ST_GKB_TMP00029対応 END               
          ELSE
                NULL;
          END IF;
          OPEN cCURSOR FOR sSQL;
          BEGIN
          LOOP
              FETCH cCURSOR INTO rDATA;
              EXIT WHEN cCURSOR%NOTFOUND;
              --2-1-2.2-1-1で取得した児童生徒の基本情報は変数をセットする。
                --①-2.①-1で取得した変換後の西暦生年月日を変数.宛名基本-西暦生年月日にセットする。
                IF rDATA.v_KIHON_SEINENGAPI <> 0 THEN
--  2024/11/02 ZCZL.WANGMING UPDATE START 0.3.000.006:IT_GKB_00286横展開対応
--                  g_rSEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(rDATA.v_KIHON_SEINENGAPI),'YYYY/MM/DD'), 6);--宛名基本-西暦生年月日
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10058対応 START
--                  GKAPK00020.FGETSEINENGHYOUJI(rDATA.v_KIHON_SEINENGAPI,o_sEINENGAPI1);
--                  g_rSEINENGAPI := KKAPK0020.FDateFmt(o_sEINENGAPI1.o_vYYYYMMDD_BACKSLASH, 6);--宛名基本-西暦生年月日
                  g_rSEINENGAPI := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(rDATA.v_KIHON_SEINENGAPI,1,3),' ',''));--宛名基本-西暦生年月日
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10058対応 END
--  2024/11/02 ZCZL.WANGMING UPDATE END
                ELSE
                  g_rSEINENGAPI := 0;
                END IF;
                --②-2.②-1で取得した変換後生年月日を変数.宛名基本-和暦生年月日にセットする。
                IF rDATA.v_KIHON_SEINENGAPI <> 0 THEN
--  2024/11/02 ZCZL.WANGMING UPDATE START 0.3.000.006:IT_GKB_00286横展開対応
--                  g_rWAREKI_SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(rDATA.v_KIHON_SEINENGAPI),'YYYY/MM/DD'), 12);--宛名基本-和暦生年月日
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10058対応 START
--                  GKAPK00020.FGETSEINENGHYOUJI(rDATA.v_KIHON_SEINENGAPI,o_sEINENGAPI2);  
--                  g_rWAREKI_SEINENGAPI := KKAPK0020.FDateFmt(o_sEINENGAPI2.o_vYYYYMMDD_BACKSLASH, 12);--宛名基本-和暦生年月日
                  g_rWAREKI_SEINENGAPI := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(rDATA.v_KIHON_SEINENGAPI,0,3),' ',''));--宛名基本-和暦生年月日
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10058対応 END
--  2024/11/02 ZCZL.WANGMING UPDATE END
                ELSE
                  g_rWAREKI_SEINENGAPI := 0;
                END IF;
                --③宛名基本.氏名カナを変数.宛名基本-氏名カナにセットする。
                g_rSHIMEI_KANA            := rDATA.v_KIHON_SHIMEI_KANA ;   --宛名基本-氏名カナ
                --④宛名基本.氏名漢字を変数.宛名基本-氏名漢字にセットする。
                g_rSHIMEI_KANJI           := rDATA.v_KIHON_SHIMEI_KANJI ;   --宛名基本-氏名漢字
                --⑤宛名基本.本名カナを変数.宛名基本-本名カナにセットする。
--  2024/11/18 YAMANI.SASAKI UPDATE START 0.3.000.007:IT_GKB_00611対応
--                g_rHONMYO_KANA            := rDATA.v_KIHON_HONMYO_KANA ;   --宛名基本-本名カナ
                IF rDATA.v_KIHON_HONMYO_KANA IS NULL THEN
                   g_rHONMYO_KANA            := rDATA.v_KIHON_SHIMEI_KANA ;   --宛名基本-本名カナ
                ELSE
                   g_rHONMYO_KANA            := rDATA.v_KIHON_HONMYO_KANA ;   --宛名基本-本名カナ
                END IF;
--  2024/11/18 YAMANI.SASAKI UPDATE END
                --⑥宛名基本.本名漢字を変数.宛名基本-本名漢字にセットする。
--  2024/11/18 YAMANI.SASAKI UPDATE START 0.3.000.007:IT_GKB_00611対応
--                g_rHONMYO_KANJI           := rDATA.v_KIHON_HONMYO_KANJI ;   --宛名基本-本名漢字
                IF rDATA.v_KIHON_HONMYO_KANJI IS NULL THEN
                   g_rHONMYO_KANJI           := rDATA.v_KIHON_SHIMEI_KANJI ;   --宛名基本-本名漢字
                ELSE
                   g_rHONMYO_KANJI           := rDATA.v_KIHON_HONMYO_KANJI ;   --宛名基本-本名漢字
                END IF;
--  2024/11/18 YAMANI.SASAKI UPDATE END
                --⑦宛名基本.アルファベット氏名漢字を変数.宛名基本-アルファベット氏名漢字にセットする。
                --宛名基本.アルファベット氏名漢字　＝　NULLの場合、宛名基本.氏名漢字を変数.宛名基本-アルファベット氏名漢字にセットする。
                IF rDATA.v_KIHON_ALP_SHIMEI_KANJI IS NULL THEN
                   g_rALP_SHIMEI_KANJI       := rDATA.v_KIHON_SHIMEI_KANJI ;   --宛名基本-アルファベット氏名漢字
                ELSE
                   g_rALP_SHIMEI_KANJI       := rDATA.v_KIHON_ALP_SHIMEI_KANJI ;   --宛名基本-アルファベット氏名漢字
                END IF;
                --⑧宛名基本.外国人氏名漢字を変数.宛名基本-外国人氏名漢字にセットする。
                --宛名基本.外国人氏名漢字　＝　NULLの場合、宛名基本.氏名漢字を変数.宛名基本-外国人氏名漢字にセットする。
                IF rDATA.v_KIHON_GAI_SHIMEI_KANJI IS NULL THEN
                   g_rGAI_SHIMEI_KANJI       := rDATA.v_KIHON_SHIMEI_KANJI ;   --宛名基本-外国人氏名漢字
                ELSE
                   g_rGAI_SHIMEI_KANJI       := rDATA.v_KIHON_GAI_SHIMEI_KANJI ;   --宛名基本-外国人氏名漢字
                END IF;    
                --⑨宛名基本.通称名カナを変数.宛名基本-通称名カナにセットする。
                --宛名基本.通称名カナ　＝　NULLの場合、宛名基本.氏名カナを変数.宛名基本-通称名カナにセットする。
                IF rDATA.v_KIHON_TSUSHOMEI_KANA IS NULL THEN
                   g_rTSUSHOMEI_KANA_KIHON   := rDATA.v_KIHON_SHIMEI_KANA ;   --宛名基本-通称名カナ
                ELSE
                   g_rTSUSHOMEI_KANA_KIHON   := rDATA.v_KIHON_TSUSHOMEI_KANA ;   --宛名基本-通称名カナ
                END IF;
                --⑩宛名基本.通称名漢字を変数.宛名基本-通称名漢字にセットする。
                --宛名基本.通称名漢字　＝　NULLの場合、宛名基本.氏名漢字を変数.宛名基本-通称名漢字にセットする。
                IF rDATA.v_KIHON_TSUSHOMEI_KANJI IS NULL THEN
                   g_rTSUSHOMEI_KANJI_KIHON  := rDATA.v_KIHON_SHIMEI_KANJI ;   --宛名基本-通称名漢字
                ELSE
                   g_rTSUSHOMEI_KANJI_KIHON  := rDATA.v_KIHON_TSUSHOMEI_KANJI ;   --宛名基本-通称名漢字
                END IF;
                --⑪引数.保護者区分　＝　0の場合、
                IF i_nHOGOSYA_KAN =  0 THEN
                    --住基異動.通称名カナを変数.児童生徒住基異動-通称名カナにセットする。
                    --住基異動.通称名カナ　＝　NULLの場合、宛名基本.氏名カナを変数.児童生徒住基異動-通称名カナにセットする。
                    IF rDATA.v_KIIDO_TSUSHOMEI_KANA IS NULL THEN
                       g_rTSUSHOMEI_KANA_KIIDO   := rDATA.v_KIHON_SHIMEI_KANA ;   --住基異動-通称名カナ
                    ELSE
                       g_rTSUSHOMEI_KANA_KIIDO   := rDATA.v_KIIDO_TSUSHOMEI_KANA ;   --住基異動-通称名カナ
                    END IF;
                    --住基異動.通称名漢字を変数.児童生徒住基異動-通称名漢字にセットする。  
                    --住基異動.通称名漢字　＝　NULLの場合、宛名基本.氏名漢字を変数.児童生徒住基異動-通称名漢字にセットする。  
                    IF rDATA.v_KIIDO_TSUSHOMEI_KANJI IS NULL THEN
                       g_rTSUSHOMEI_KANJI_KIIDO  := rDATA.v_KIHON_SHIMEI_KANJI ;   --住基異動-通称名漢字
                    ELSE
                       g_rTSUSHOMEI_KANJI_KIIDO  := rDATA.v_KIIDO_TSUSHOMEI_KANJI ;   --住基異動-通称名漢字
                    END IF;
                    --学齢簿.通称名カナを変数.学齢簿-通称名カナにセットする。  
                    --学齢簿.通称名カナ　＝　NULLの場合、宛名基本.氏名カナを変数.学齢簿-通称名カナにセットする。  
                    IF rDATA.v_REIBO_TSUSHOMEI_KANA IS NULL THEN
                       g_rTSUSHOMEI_KANA_REIBO   := rDATA.v_KIHON_SHIMEI_KANA ;   --学齢簿-通称名
                    ELSE
                       g_rTSUSHOMEI_KANA_REIBO   := rDATA.v_REIBO_TSUSHOMEI_KANA ;   --学齢簿-通称名
                    END IF;
                    --学齢簿.通称名漢字を変数.学齢簿-通称名漢字にセットする。  
                    --学齢簿.通称名漢字　＝　NULLの場合、宛名基本.氏名漢字を変数.学齢簿-通称名漢字にセットする。  
                    IF rDATA.v_REIBO_TSUSHOMEI_KANJI IS NULL THEN
                       g_rTSUSHOMEI_KANJI_REIBO  := rDATA.v_KIHON_SHIMEI_KANJI ;   --学齢簿-通称名漢字
                    ELSE
                       g_rTSUSHOMEI_KANJI_REIBO  := rDATA.v_REIBO_TSUSHOMEI_KANJI ;   --学齢簿-通称名漢字
                    END IF;
                --⑯引数.保護者区分　＝　1の場合、
                ELSIF i_nHOGOSYA_KAN = 1 THEN
                    --住基異動.通称名カナを変数.保護者住基異動-通称名カナにセットする。
                    --住基異動.通称名カナ　＝　NULLの場合、宛名基本.氏名カナを変数.保護者住基異動-通称名カナにセットする。
                    IF rDATA.v_KIIDO_TSUSHOMEI_KANA IS NULL THEN
                       g_rTSUSHOMEI_KANA_KIIDO  := rDATA.v_KIHON_SHIMEI_KANA ;   --住基異動-通称名カナ
                    ELSE
                       g_rTSUSHOMEI_KANA_KIIDO  := rDATA.v_KIIDO_TSUSHOMEI_KANA ;   --住基異動-通称名カナ
                    END IF;
                    --住基異動.通称名漢字を変数.保護者住基異動-通称名漢字にセットする。
                    --住基異動.通称名漢字　＝　NULLの場合、宛名基本.氏名漢字を変数.保護者住基異動-通称名漢字にセットする。
                    IF rDATA.v_KIIDO_TSUSHOMEI_KANJI IS NULL THEN
                       g_rTSUSHOMEI_KANJI_KIIDO  := rDATA.v_KIHON_SHIMEI_KANJI ;   --住基異動-通称名漢字
                    ELSE
                       g_rTSUSHOMEI_KANJI_KIIDO  := rDATA.v_KIIDO_TSUSHOMEI_KANJI ;   --住基異動-通称名漢字
                    END IF;
                    --学齢簿.保護者通称名カナを変数.学齢簿-保護者通称名カナにセットする。
                    --学齢簿.保護者通称名カナ　＝　NULLの場合、宛名基本.氏名カナを変数.学齢簿-保護者通称名カナにセットする。
                    IF rDATA.v_REIBO_HOGOSYA_TSUSHOMEI_KANA IS NULL THEN
                       g_rHOGOSYA_TSUSHOMEI_KANA_REIBO  := rDATA.v_KIHON_SHIMEI_KANA ;   --学齢簿-保護者通称名カナ
                    ELSE
                       g_rHOGOSYA_TSUSHOMEI_KANA_REIBO  := rDATA.v_REIBO_HOGOSYA_TSUSHOMEI_KANA ;   --学齢簿-保護者通称名カナ
                    END IF;
                    --学齢簿.保護者通称名を変数.学齢簿-保護者通称名漢字にセットする。  
                    --学齢簿.保護者通称名　＝　NULLの場合、宛名基本.氏名漢字を変数.学齢簿-保護者通称名漢字にセットする。  
                    IF rDATA.v_REIBO_HOGOSYA_TSUSHOMEI_KANJI IS NULL THEN
                       g_rHOGOSYA_TSUSHOMEI_KANJI_REIBO  := rDATA.v_KIHON_SHIMEI_KANJI ;   --学齢簿.保護者通称名
                    ELSE
                       g_rHOGOSYA_TSUSHOMEI_KANJI_REIBO  := rDATA.v_REIBO_HOGOSYA_TSUSHOMEI_KANJI ;   --学齢簿.保護者通称名
                    END IF;
                ELSE
                    NULL;
                END IF;
                --⑮宛名基本.人格区分を変数,人格区分にセットする。
                g_rJINKAKU_KBN := rDATA.v_KIHON_JINKAKU_KBN ;--宛名基本-人格区分
              END LOOP;
             CLOSE cCURSOR;
          END;
            
--  2024/11/01 ZCZL.WANGMING UPDATE START 0.3.000.005:仕様変更：IT_GKB_00451対応
--        --2-2.IN引数.システム制御設定　>　２の場合、本名使用制御管理情報を取得する。 
--        IF i_nSYS_KAN > 2 THEN
        --2-2.本名使用制御管理情報を取得する。 
--  2024/11/01 ZCZL.WANGMING UPDATE END
            --2-2-1.本名使用制御管理から設定内容コードを取得する。
            BEGIN
                SELECT 
                    NAIYO_CD
                INTO
--  2024/08/12 ZCZL.QINYUE UPDATE START
--                    n_NAIYO_CD
                    g_NAIYO_CD
                FROM  
                    GKBTSHIMEIJKN
                WHERE
                    KOJIN_NO = i_nKOJIN_NO
                    AND CHOHYO_ID = i_sCHOHYOID;
            --2-2-2.2-2-1で取得した設定内容コードを変数.本名使用制御管理設定をセットする。 
            --2-2-1で取得した設定内容コード　＝　NULLの場合、変数.本名使用制御管理設定　＝　０をセットする。
--            IF n_NAIYO_CD = 0 THEN
            IF g_NAIYO_CD = 0 THEN
                g_nHONMYO_KAN := 0;  --本名使用制御管理設定
            ELSE
--                g_nHONMYO_KAN := n_NAIYO_CD;  --本名使用制御管理設定
                g_nHONMYO_KAN := g_NAIYO_CD;  --本名使用制御管理設定
--  2024/08/12 ZCZL.QINYUE UPDATE END
            END IF;
            EXCEPTION
              WHEN OTHERS THEN
                  g_nHONMYO_KAN := 0;  --本名使用制御管理設定
            END; 
--  2024/11/01 ZCZL.WANGMING DELETE 0.3.000.005:仕様変更：IT_GKB_00451対応
--        END IF;           
    EXCEPTION
      WHEN OTHERS THEN
        NRTN := SQLCODE;
    END;
    RETURN (NRTN);
  END FUNC_MAIN;
  -----------------------------------------------------------
  --  3.パラメータによって本名使用制御のOUT引数を設定する。
  -----------------------------------------------------------
  FUNCTION FUNC_OUT RETURN NUMBER IS
    NRTN       NUMBER := 0;
  BEGIN
    BEGIN
--  2024/11/01 ZCZL.WANGMING ADD START 0.3.000.005:仕様変更：IT_GKB_00451対応
        --変数.本名使用制御管理設定　＝　０の場合（学齢簿側の設定なし）、下記の3-1を実行する。それ以外の場合は3-2へ進む。
        IF g_nHONMYO_KAN = 0 THEN
--  2024/11/01 ZCZL.WANGMING ADD END
        --3-1.IN引数.システム制御設定により児童生徒の名前と生年月日を設定する。
--  2024/09/29 ZCZL.WANGMING UPDATE START 0.3.000.002:IT_GKB_00269の対応
--        CASE i_nSYS_KAN 
            --3-1-1.IN引数.システム制御設定　＝　0　の場合
--            WHEN 0 THEN
            IF i_nSYS_KAN = 0 THEN
--  2024/09/29 ZCZL.WANGMING UPDATE END
              o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIHON;   -- 氏名カナ (OUT引数.氏名名カナ　＝　宛名基本-通称名カナ) 
              o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIHON;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-通称名漢字)
                --宛名基本.人格区分＝　1（外国人）の場合
                IF g_rJINKAKU_KBN = 1 THEN                   
                    o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --宛名基本.人格区分＝　0（日本人）の場合
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
            --3-1-2.IN引数.システム制御設定　＝　1　の場合
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 1 THEN
            ELSIF i_nSYS_KAN = 1 THEN
              o_sSHIMEIKANA := g_rHONMYO_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-本名カナ) 
              o_sSHIMEI     := g_rHONMYO_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-本名漢字)
                --宛名基本.人格区分＝　1（外国人）の場合
                IF g_rJINKAKU_KBN = 1 THEN   
                    o_sBIRTHDAY   := g_rSEINENGAPI;         -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --宛名基本.人格区分＝　0（日本人）の場合
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
            --3-1-3.IN引数.システム制御設定　＝　2　の場合
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 2 THEN
            ELSIF i_nSYS_KAN = 2 THEN
                --宛名基本.人格区分＝　1（外国人）の場合
                IF g_rJINKAKU_KBN = 1 THEN
                    o_sSHIMEIKANA := g_rSHIMEI_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-氏名カナ) 
                    o_sSHIMEI     := g_rSHIMEI_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-氏名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;         -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --宛名基本.人格区分＝　0（日本人）の場合
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    --変数.宛名基本-氏名カナ　＜＞　NULL　かつ　変数.宛名基本-氏名漢字　＜＞　NULL　の場合
                    IF g_rSHIMEI_KANA IS NOT NULL AND g_rSHIMEI_KANJI IS NOT NULL THEN
                        o_sSHIMEIKANA := g_rSHIMEI_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-氏名カナ) 
                        o_sSHIMEI     := g_rSHIMEI_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-氏名漢字)
--  2024/09/02 ZCZL.GUANHONG Update 0.3.000.001:8月1日認識合わせの横展開
--                         o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                        o_sBIRTHDAY   := g_rSEINENGAPI;         -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                    ELSE
                        o_sSHIMEIKANA := g_rHONMYO_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-本名カナ) 
                        o_sSHIMEI     := g_rHONMYO_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-本名漢字)
                        o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                    END IF;
                ELSE
                    NULL;
                END IF;
            --3-1-4.IN引数.システム制御設定　＝　3　かつ　変数.本名使用制御管理設定<>0の場合、以下の3-2-1を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 3 THEN
            ELSIF i_nSYS_KAN = 3 AND g_nHONMYO_KAN = 0 THEN
            --3-2-1.変数.本名使用制御管理設定　＝　11　の場合、児童生徒または保護者の通称名・和暦生年月日を設定する。
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 11 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 11 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
                o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIHON;   -- 氏名カナ (OUT引数.氏名カナ　＝　宛名基本-通称名カナ) 
                o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIHON;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-通称名漢字)
                o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              END IF;
            --3-1-5.IN引数.システム制御設定　＝　4　かつ　変数.本名使用制御管理設定<>0の場合、以下の3-2-4を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 4 THEN
            ELSIF i_nSYS_KAN = 4 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 12 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 12 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
--  2024/10/10 ZCZL.WANGMING UPDATE START 0.3.000.003:IT_GKB_00277の対応
--                o_sSHIMEIKANA := g_rHONMYO_KANA;            -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-本名カナ) 
--                o_sSHIMEI     := g_rHONMYO_KANJI;           -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-本名漢字)
                o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIHON;            -- 氏名カナ (OUT引数.氏名カナ　＝　宛名基本-通称名カナ) 
                o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIHON;           -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-通称名漢字)
--  2024/09/29 ZCZL.WANGMING UPDATE END
                o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--               END IF;
            --3-1-5.IN引数.システム制御設定　＝　5　かつ　変数.本名使用制御管理設定＜＞0の場合、以下の3-2-2を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 5 THEN
            ELSIF i_nSYS_KAN = 5 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 21 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 21 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
--  2024/10/10 ZCZL.WANGMING UPDATE START 0.3.000.003:IT_GKB_00277の対応
--                o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIHON;   -- 氏名カナ (OUT引数.氏名カナ　＝　宛名基本-通称名カナ) 
--                o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIHON;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-通称名漢字)
                o_sSHIMEIKANA := g_rHONMYO_KANA;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-本名カナ) 
                o_sSHIMEI     := g_rHONMYO_KANJI;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-本名漢字)
--  2024/09/29 ZCZL.WANGMING UPDATE END
--  2024/09/02 ZCZL.GUANHONG Update 0.3.000.001:8月1日認識合わせの横展開
--                 o_sBIRTHDAY   := g_rSEINENGAPI;            -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              END IF;
            --3-1-6.IN引数.システム制御設定　＝　6　かつ　変数.本名使用制御管理設定＜＞0の場合、以下の3-2-3を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 6 THEN
            ELSIF i_nSYS_KAN = 6 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 22 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 22 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
                o_sSHIMEIKANA := g_rHONMYO_KANA;            -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-本名カナ) 
                o_sSHIMEI     := g_rHONMYO_KANJI;           -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-本名漢字)
--  2024/09/02 ZCZL.GUANHONG Update 0.3.000.001:8月1日認識合わせの横展開
--                o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              END IF;
            --3-1-7.IN引数.システム制御設定　＝　7　かつ　変数.本名使用制御管理設定＜＞0の場合、以下の3-2-5を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 7 THEN
            ELSIF i_nSYS_KAN = 7 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 31 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 31 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
                --宛名基本.人格区分＝　1（外国人）の場合、児童生徒または保護者の外国人氏名英字・和暦生年月日を設定する。
                IF g_rJINKAKU_KBN = 1 THEN
                    o_sSHIMEIKANA := g_rALP_SHIMEI_KANJI;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-アルファベット氏名漢字) 
                    o_sSHIMEI     := g_rALP_SHIMEI_KANJI;   -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-アルファベット氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                --宛名基本.人格区分＝　０（日本人）の場合、児童生徒の氏名カナ、氏名漢字、和暦生年月日を設定する。
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    o_sSHIMEIKANA := g_rSHIMEI_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-氏名カナ) 
                    o_sSHIMEI     := g_rSHIMEI_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              END IF;
            --3-1-8.IN引数.システム制御設定　＝　8　かつ　変数.本名使用制御管理設定＜＞0の場合、以下の3-2-6を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 8 THEN
            ELSIF i_nSYS_KAN = 8 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 32 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 32 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
                --宛名基本.人格区分＝　1（外国人）の場合、児童生徒または保護者の外国人氏名英字・西暦生年月日を設定する。
                IF g_rJINKAKU_KBN = 1 THEN
                    o_sSHIMEIKANA := g_rALP_SHIMEI_KANJI;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-アルファベット氏名漢字) 
                    o_sSHIMEI     := g_rALP_SHIMEI_KANJI;   -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-アルファベット氏名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;         -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --宛名基本.人格区分＝　０（日本人）の場合、児童生徒の氏名カナ、氏名漢字、和暦生年月日を設定する。
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    o_sSHIMEIKANA := g_rSHIMEI_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-氏名カナ) 
                    o_sSHIMEI     := g_rSHIMEI_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              END IF;
            --3-1-9.IN引数.システム制御設定　＝　9　かつ　変数.本名使用制御管理設定＜＞0の場合、以下の3-2-7を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 9 THEN
            ELSIF i_nSYS_KAN = 9 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 41 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 41 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
                --宛名基本.人格区分＝　1（外国人）　の場合、児童生徒または保護者の外国人氏名漢字・和暦生年月日を設定する。
                IF g_rJINKAKU_KBN = 1 THEN
                    o_sSHIMEIKANA := g_rGAI_SHIMEI_KANJI;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-外国人氏名漢字) 
                    o_sSHIMEI     := g_rGAI_SHIMEI_KANJI;   -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-外国人氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                --宛名基本.人格区分＝　０（日本人）の場合、児童生徒の氏名カナ、氏名漢字、和暦生年月日を設定する。
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    o_sSHIMEIKANA := g_rSHIMEI_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-氏名カナ) 
                    o_sSHIMEI     := g_rSHIMEI_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              END IF;
            --3-1-10.IN引数.システム制御設定　＝　10　かつ　変数.本名使用制御管理設定＜＞0の場合、以下の3-2-8を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 10 THEN
            ELSIF i_nSYS_KAN = 10 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 42 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 42 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
               --宛名基本.人格区分＝　1（外国人）　の場合、児童生徒または保護者の外国人氏名漢字・西暦生年月日を設定する。
                IF g_rJINKAKU_KBN = 1 THEN
                    o_sSHIMEIKANA := g_rGAI_SHIMEI_KANJI;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-外国人氏名漢字) 
                    o_sSHIMEI     := g_rGAI_SHIMEI_KANJI;   -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-外国人氏名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;         -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --宛名基本.人格区分＝　０（日本人）の場合、児童生徒の氏名カナ、氏名漢字、和暦生年月日を設定する。
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    o_sSHIMEIKANA := g_rSHIMEI_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-氏名カナ) 
                    o_sSHIMEI     := g_rSHIMEI_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.和暦生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              END IF;
            --3-1-11.IN引数.システム制御設定　＝　11　かつ　変数.本名使用制御管理設定＜＞0の場合、以下の3-2-9を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 11 THEN
            ELSIF i_nSYS_KAN = 11 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 51 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 51 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
                --引数.保護者区分　＝　0（保護者制御しない）の場合、児童生徒の住記通称名・和暦生年月日を設定する。
                IF i_nHOGOSYA_KAN = 0 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIIDO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.住基異動-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIIDO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.住基異動-通称名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                --引数.保護者区分　＝　1（保護者制御する）の場合、保護者の住記通称名・和暦生年月日を設定する
                ELSIF i_nHOGOSYA_KAN = 1 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIIDO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.保護者住基異動-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIIDO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.保護者住基異動-通称名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              END IF;
            --3-1-12.IN引数.システム制御設定　＝　12　かつ　変数.本名使用制御管理設定＜＞0の場合、以下の3-2-10を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 12 THEN
            ELSIF i_nSYS_KAN = 12 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 52 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 52 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
                --引数.保護者区分　＝　0（保護者制御しない）の場合、児童生徒の住記通称名・西暦生年月日を設定する。
                IF i_nHOGOSYA_KAN = 0 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIIDO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.住基異動-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIIDO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.住基異動-通称名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --引数.保護者区分　＝　1（保護者制御する）の場合、保護者の住記通称名・和暦生年月日を設定する。
                ELSIF i_nHOGOSYA_KAN = 1 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIIDO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.保護者住基異動-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIIDO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.保護者住基異動-通称名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                ELSE
                    NULL;
                END IF;
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              END IF;
            --3-1-13.IN引数.システム制御設定　＝　13　かつ　変数.本名使用制御管理設定＜＞0の場合、以下の3-2-11を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 13 THEN
            ELSIF i_nSYS_KAN = 13 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 61 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 61 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
                --引数.保護者区分　＝　0（保護者制御しない）の場合、児童生徒の学齢簿通称名・和暦生年月日を設定する。
                IF i_nHOGOSYA_KAN = 0 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_REIBO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.学齢簿-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_REIBO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.学齢簿-通称名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                --引数.保護者区分　＝　1（保護者制御する）の場合、保護者の学齢簿通称名・和暦生年月日を設定する。
                ELSIF i_nHOGOSYA_KAN = 1 THEN
                    o_sSHIMEIKANA := g_rHOGOSYA_TSUSHOMEI_KANA_REIBO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.学齢簿-保護者通称名カナ) 
                    o_sSHIMEI     := g_rHOGOSYA_TSUSHOMEI_KANJI_REIBO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.学齢簿-保護者通称名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;              -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              END IF;
            --3-1-14.IN引数.システム制御設定　＝　14　かつ　変数.本名使用制御管理設定＜＞0の場合、以下の3-2-12を実行する。
--  2024/09/29 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00269の対応
--            WHEN 14 THEN
            ELSIF i_nSYS_KAN = 14 AND g_nHONMYO_KAN = 0 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE START
--  2024/09/29 ZCZL.WANGMING DELETE 0.3.000.002:IT_GKB_00269の対応
--              IF g_NAIYO_CD = 62 THEN
--              IF g_nHONMYO_KAN <> 0 AND g_nHONMYO_KAN = 62 THEN
--  2024/08/12 ZCZL.QINYUE UPDATE END
                --引数.保護者区分　＝　0（保護者制御しない）の場合、児童生徒の学齢簿通称名・西暦生年月日を設定する。
                IF i_nHOGOSYA_KAN = 0 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_REIBO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.学齢簿-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_REIBO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.学齢簿-通称名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --引数.保護者区分　＝　1（保護者制御する）の場合、保護者の学齢簿通称名・和暦生年月日を設定する。
                ELSIF i_nHOGOSYA_KAN = 1 THEN
                    o_sSHIMEIKANA := g_rHOGOSYA_TSUSHOMEI_KANA_REIBO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.学齢簿-保護者通称名カナ) 
                    o_sSHIMEI     := g_rHOGOSYA_TSUSHOMEI_KANJI_REIBO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.学齢簿-保護者通称名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;                     -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                ELSE
                    NULL;
                END IF;
            END IF;
--  2024/09/29 ZCZL.WANGMING UPDATE START 0.3.000.002:IT_GKB_00269の対応
--            ELSE
--                NULL;
--  2024/11/01 ZCZL.WANGMING UPDATE 0.3.000.005:仕様変更：IT_GKB_00451対応
--            IF i_nSYS_KAN >= 3 AND g_nHONMYO_KAN <> 0 THEN
        ELSIF g_nHONMYO_KAN <> 0 THEN
              --変数.本名使用制御管理設定　＝　11　の場合、児童生徒または保護者の通称名・和暦生年月日を設定する。
              IF g_nHONMYO_KAN = 11 THEN
                o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIHON;   -- 氏名カナ (OUT引数.氏名カナ　＝　宛名基本-通称名カナ) 
                o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIHON;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-通称名漢字)
                o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
              --変数.本名使用制御管理設定　＝　12　の場合、児童生徒または保護者の通称名・西暦生年月日を設定する。
              ELSIF g_nHONMYO_KAN = 12 THEN
--  2024/10/10 ZCZL.WANGMING UPDATE START 0.3.000.003:IT_GKB_00277の対応
--                o_sSHIMEIKANA := g_rHONMYO_KANA;            -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-本名カナ) 
--                o_sSHIMEI     := g_rHONMYO_KANJI;           -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-本名漢字)
                o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIHON;            -- 氏名カナ (OUT引数.氏名カナ　＝　宛名基本-通称名カナ) 
                o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIHON;           -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-通称名漢字)
--  2024/09/29 ZCZL.WANGMING UPDATE END
                o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
              --変数.本名使用制御管理設定　＝　21　の場合、児童生徒または保護者の本名・和暦生年月日を設定する。
              ELSIF g_nHONMYO_KAN = 21 THEN
--  2024/10/10 ZCZL.WANGMING UPDATE START 0.3.000.003:IT_GKB_00277の対応
--                o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIHON;   -- 氏名カナ (OUT引数.氏名カナ　＝　宛名基本-通称名カナ) 
--                o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIHON;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-通称名漢字)
                o_sSHIMEIKANA := g_rHONMYO_KANA;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-本名カナ) 
                o_sSHIMEI     := g_rHONMYO_KANJI;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-本名漢字)
--  2024/09/29 ZCZL.WANGMING UPDATE END
                o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
              --変数.本名使用制御管理設定　＝　22　の場合、児童生徒または保護者の本名・西暦生年月日を設定する。
              ELSIF g_nHONMYO_KAN = 22 THEN
                o_sSHIMEIKANA := g_rHONMYO_KANA;            -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-本名カナ) 
                o_sSHIMEI     := g_rHONMYO_KANJI;           -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-本名漢字)
                o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
              --変数.本名使用制御管理設定　＝　31　の場合
              ELSIF g_nHONMYO_KAN = 31 THEN
                --宛名基本.人格区分＝　1（外国人）の場合、児童生徒または保護者の外国人氏名英字・和暦生年月日を設定する。
                IF g_rJINKAKU_KBN = 1 THEN
                    o_sSHIMEIKANA := g_rALP_SHIMEI_KANJI;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-アルファベット氏名漢字) 
                    o_sSHIMEI     := g_rALP_SHIMEI_KANJI;   -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-アルファベット氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                --宛名基本.人格区分＝　０（日本人）の場合、児童生徒の氏名カナ、氏名漢字、和暦生年月日を設定する。
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    o_sSHIMEIKANA := g_rSHIMEI_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-氏名カナ) 
                    o_sSHIMEI     := g_rSHIMEI_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
              --変数.本名使用制御管理設定　＝　32　の場合
              ELSIF g_nHONMYO_KAN = 32 THEN
                --宛名基本.人格区分＝　1（外国人）の場合、児童生徒または保護者の外国人氏名英字・西暦生年月日を設定する。
                IF g_rJINKAKU_KBN = 1 THEN
                    o_sSHIMEIKANA := g_rALP_SHIMEI_KANJI;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-アルファベット氏名漢字) 
                    o_sSHIMEI     := g_rALP_SHIMEI_KANJI;   -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-アルファベット氏名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;         -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --宛名基本.人格区分＝　０（日本人）の場合、児童生徒の氏名カナ、氏名漢字、和暦生年月日を設定する。
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    o_sSHIMEIKANA := g_rSHIMEI_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-氏名カナ) 
                    o_sSHIMEI     := g_rSHIMEI_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
              --変数.本名使用制御管理設定　＝　41　の場合
              ELSIF g_nHONMYO_KAN = 41 THEN
                --宛名基本.人格区分＝　1（外国人）　の場合、児童生徒または保護者の外国人氏名漢字・和暦生年月日を設定する。
                IF g_rJINKAKU_KBN = 1 THEN
                    o_sSHIMEIKANA := g_rGAI_SHIMEI_KANJI;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-外国人氏名漢字) 
                    o_sSHIMEI     := g_rGAI_SHIMEI_KANJI;   -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-外国人氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                --宛名基本.人格区分＝　０（日本人）の場合、児童生徒の氏名カナ、氏名漢字、和暦生年月日を設定する。
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    o_sSHIMEIKANA := g_rSHIMEI_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-氏名カナ) 
                    o_sSHIMEI     := g_rSHIMEI_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
              --変数.本名使用制御管理設定　＝　42　の場合
              ELSIF g_nHONMYO_KAN = 42 THEN
                --宛名基本.人格区分＝　1（外国人）　の場合、児童生徒または保護者の外国人氏名漢字・西暦生年月日を設定する。
                IF g_rJINKAKU_KBN = 1 THEN
                    o_sSHIMEIKANA := g_rGAI_SHIMEI_KANJI;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-外国人氏名漢字) 
                    o_sSHIMEI     := g_rGAI_SHIMEI_KANJI;   -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-外国人氏名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;         -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --宛名基本.人格区分＝　０（日本人）の場合、児童生徒の氏名カナ、氏名漢字、和暦生年月日を設定する。
                ELSIF g_rJINKAKU_KBN = 0 THEN
                    o_sSHIMEIKANA := g_rSHIMEI_KANA;        -- 氏名カナ (OUT引数.氏名カナ　＝　変数.宛名基本-氏名カナ) 
                    o_sSHIMEI     := g_rSHIMEI_KANJI;       -- 氏名漢字(OUT引数.氏名漢字　＝　変数.宛名基本-氏名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;  -- 生年月日(OUT引数.和暦生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
              --変数.本名使用制御管理設定　＝　51　の場合
              ELSIF g_nHONMYO_KAN = 51 THEN
                --引数.保護者区分　＝　0（保護者制御しない）の場合、児童生徒の住記通称名・和暦生年月日を設定する。
                IF i_nHOGOSYA_KAN = 0 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIIDO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.住基異動-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIIDO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.住基異動-通称名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                --引数.保護者区分　＝　1（保護者制御する）の場合、保護者の住記通称名・和暦生年月日を設定する
                ELSIF i_nHOGOSYA_KAN = 1 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIIDO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.保護者住基異動-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIIDO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.保護者住基異動-通称名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
              --変数.本名使用制御管理設定　＝　52　の場合
              ELSIF g_nHONMYO_KAN = 52 THEN
                --引数.保護者区分　＝　0（保護者制御しない）の場合、児童生徒の住記通称名・西暦生年月日を設定する。
                IF i_nHOGOSYA_KAN = 0 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIIDO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.住基異動-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIIDO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.住基異動-通称名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --引数.保護者区分　＝　1（保護者制御する）の場合、保護者の住記通称名・和暦生年月日を設定する。
                ELSIF i_nHOGOSYA_KAN = 1 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_KIIDO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.保護者住基異動-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_KIIDO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.保護者住基異動-通称名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                ELSE
                    NULL;
                END IF;
              --変数.本名使用制御管理設定　＝　61　の場合
              ELSIF g_nHONMYO_KAN = 61 THEN
                --引数.保護者区分　＝　0（保護者制御しない）の場合、児童生徒の学齢簿通称名・和暦生年月日を設定する。
                IF i_nHOGOSYA_KAN = 0 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_REIBO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.学齢簿-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_REIBO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.学齢簿-通称名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;      -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                --引数.保護者区分　＝　1（保護者制御する）の場合、保護者の学齢簿通称名・和暦生年月日を設定する。
                ELSIF i_nHOGOSYA_KAN = 1 THEN
                    o_sSHIMEIKANA := g_rHOGOSYA_TSUSHOMEI_KANA_REIBO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.学齢簿-保護者通称名カナ) 
                    o_sSHIMEI     := g_rHOGOSYA_TSUSHOMEI_KANJI_REIBO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.学齢簿-保護者通称名漢字)
                    o_sBIRTHDAY   := g_rWAREKI_SEINENGAPI;              -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-和暦生年月日)
                ELSE
                    NULL;
                END IF;
              --変数.本名使用制御管理設定　＝　62　の場合
              ELSIF g_nHONMYO_KAN = 62 THEN
                --引数.保護者区分　＝　0（保護者制御しない）の場合、児童生徒の学齢簿通称名・西暦生年月日を設定する。
                IF i_nHOGOSYA_KAN = 0 THEN
                    o_sSHIMEIKANA := g_rTSUSHOMEI_KANA_REIBO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.学齢簿-通称名カナ) 
                    o_sSHIMEI     := g_rTSUSHOMEI_KANJI_REIBO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.学齢簿-通称名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;             -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                --引数.保護者区分　＝　1（保護者制御する）の場合、保護者の学齢簿通称名・和暦生年月日を設定する。
                ELSIF i_nHOGOSYA_KAN = 1 THEN
                    o_sSHIMEIKANA := g_rHOGOSYA_TSUSHOMEI_KANA_REIBO;   -- 氏名カナ (OUT引数.氏名カナ　＝　変数.学齢簿-保護者通称名カナ) 
                    o_sSHIMEI     := g_rHOGOSYA_TSUSHOMEI_KANJI_REIBO;  -- 氏名漢字(OUT引数.氏名漢字　＝　変数.学齢簿-保護者通称名漢字)
                    o_sBIRTHDAY   := g_rSEINENGAPI;                     -- 生年月日(OUT引数.生年月日　＝　変数.宛名基本-西暦生年月日)
                ELSE
                    NULL;
                END IF;
              END IF;
            END IF;
--        END CASE;    
--  2024/09/29 ZCZL.WANGMING UPDATE END
    EXCEPTION
      WHEN OTHERS THEN
        NRTN := SQLCODE;
    END;
    RETURN (NRTN);
  END FUNC_OUT;
-----------------------------------------------------------
--  主処理
-----------------------------------------------------------
BEGIN
    --1.変数を初期化する
    g_nFCRTN := 0;
    IF g_nFCRTN <> 0 THEN
        g_nRTN := 1;
        RAISE g_eOTHERS;
    END IF;
    --2.メイン処理
    g_nFCRTN := FUNC_MAIN;
    IF g_nFCRTN <> 0 THEN
        g_nRTN := 1;
        RAISE g_eOTHERS;
    END IF;
    --3.パラメータによって本名使用制御のOUT引数を設定する。
    g_nFCRTN := FUNC_OUT;
    IF g_nFCRTN <> 0 THEN
        g_nRTN := 1;
        RAISE g_eOTHERS;
    END IF;
    --4.戻り値の設定
    RETURN (g_nRTN);
    
EXCEPTION    
    WHEN OTHERS THEN
        RETURN g_nRTN;
END GKBFKHMCTRL;
/