CREATE OR REPLACE FUNCTION        GKBFKGZSHNT(
--1.0.000.000-02.02-02.02
--2024/08/08 ZCZL.wanghj Update start 0.3.000.100:マージ作業
--  i_IKOJIN_NO          IN  PLS_INTEGER,
  i_IKOJIN_NO          IN  NUMBER,
  i_IKIJUN_BI          IN  NUMBER,
  o_IGENZON_KBN        OUT PLS_INTEGER,
  o_JINKAKU_KBN        OUT PLS_INTEGER,
  o_VYUBIN_NO          OUT NVARCHAR2,
  o_VCHOMEI            OUT NVARCHAR2,
  o_VBANCHI            OUT NVARCHAR2,
  o_VKATAGAKI          OUT NVARCHAR2,
  o_VSHIMEI_KANA       OUT NVARCHAR2,
  o_VSHIMEI_KANJI      OUT NVARCHAR2,
  o_SEINENGAPI         OUT PLS_INTEGER,
  o_SEIBETSU           OUT PLS_INTEGER,
  o_IGYOSEIKU_CD       OUT PLS_INTEGER,
  o_VGYOSEIKU_NM       OUT NVARCHAR2,
  o_ICHUGAKU_CD        OUT PLS_INTEGER,
  o_VCHUGAKU_NM        OUT NVARCHAR2,
  o_ISHOGAKU_CD        OUT PLS_INTEGER,
  o_VSHOGAKU_NM        OUT NVARCHAR2,
  o_VTEL_NO            OUT NVARCHAR2,
  o_ISANTEIDANTAI_CD   OUT PLS_INTEGER,
  o_VSANTEIDANTAI_NM   OUT NVARCHAR2,
  o_VCUSTOM_BC         OUT NVARCHAR2
) RETURN  PLS_INTEGER
------------------------------------------------------------------------------
--  業務名      GKB（教育）
--  PG名        GKBFKGZSHNT
--  名称        現存者判定サブルーチン
--  処理概要    基準日時点で対象者が現存していたかを判定する
--  引き数      i_IKOJIN_NO          個人番号
--              i_IKIJUN_BI          基準日（西暦８桁）
--              o_IGENZON_KBN        現存区分
--              o_JINKAKU_KBN        人格区分
--              o_VYUBIN_NO          郵便番号
--              o_VCHOMEI            町名
--              o_VBANCHI            番地
--              o_VKATAGAKI          肩書
--              o_VSHIMEI_KANA       氏名かな
--              o_VSHIMEI_KANJI      氏名漢字
--              o_SEINENGAPI         生年月日
--              o_SEIBETSU           性別
--              o_IGYOSEIKU_CD       行政区コード
--              o_VGYOSEIKU_NM       行政区名
--              o_ICHUGAKU_CD        中学校区コード
--              o_VCHUGAKU_NM        中学校区名
--              o_VTEL_NO            電話番号
--              o_ISANTEIDANTAI_CD   算定団体コード
--              o_VSANTEIDANTAI_NM   算定団体名
--              o_VCUSTOM_BC         カスタムバーコード
--  作成者      ZCZL.GUOXU
--  作成日      2024/01/22
--  VERSION     0.2.000.000
IS
------------------------------------------------------------------------------
--  定数宣言
------------------------------------------------------------------------------
  c_IOK          CONSTANT  PLS_INTEGER := 0;         -- 正常
  c_INOTFOUND    CONSTANT  PLS_INTEGER := 1;         -- 該当なし
  c_IERR         CONSTANT  PLS_INTEGER := 9;         -- その他エラー

------------------------------------------------------------------------------
--  変数宣言
------------------------------------------------------------------------------
  IRETURN_CODE        PLS_INTEGER;
  IRTN                PLS_INTEGER;
  IRTN_J              PLS_INTEGER;  
  IGENZON_KBN         PLS_INTEGER;
  IJINKAKU_KBN        PLS_INTEGER;
  VYUBIN_NO           NVARCHAR2(10);
  VCHOMEI             NVARCHAR2(40);
  VBANCHI             NVARCHAR2(40);
  VKATAGAKI           NVARCHAR2(60);
  VSHIMEI_KANA        NVARCHAR2(100);
  VSHIMEI_KANJI       NVARCHAR2(100);
  ISEINENGAPI         PLS_INTEGER;
  ISEIBETSU           PLS_INTEGER;
  IGYOSEIKU_CD        PLS_INTEGER;
  ICHUGAKU_CD         PLS_INTEGER;
  ISHOGAKU_CD         PLS_INTEGER;  
  VTEL_NO             NVARCHAR2(20);
  ISANTEIDANTAI_CD    PLS_INTEGER;
  IJUMIN_NAKUNARU     PLS_INTEGER;  

------------------------------------------------------------------------------
-- 旧自治体名称取得
------------------------------------------------------------------------------
FUNCTION FUNC_JICHINAME( pSANTEIDANTAI_CD IN NUMBER ) RETURN NVARCHAR2 IS
  IRTN        PLS_INTEGER;
  WK_MEISYO   NVARCHAR2(40);
  VRTN        NVARCHAR2(40);
BEGIN
  WK_MEISYO := NULL;
  IRTN := GAAPK0030.FJICHINAME( pSANTEIDANTAI_CD, WK_MEISYO );
  IF IRTN = 0 THEN
    VRTN := WK_MEISYO;
  ELSE
    VRTN := NULL;
  END IF;
  RETURN VRTN;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END FUNC_JICHINAME;

------------------------------------------------------------------------------
-- 初期化
------------------------------------------------------------------------------
PROCEDURE PROC_INITIALIZE IS
BEGIN
  IGENZON_KBN       := 0;
  IJINKAKU_KBN      := 0;
  VYUBIN_NO         := NULL;
  VCHOMEI           := NULL;
  VBANCHI           := NULL;
  VKATAGAKI         := NULL;
  VSHIMEI_KANA      := NULL;
  VSHIMEI_KANJI     := NULL;
  ISEINENGAPI       := 0;
  ISEIBETSU         := 0;
  IGYOSEIKU_CD      := 0;
  ICHUGAKU_CD       := 0;
  ISHOGAKU_CD       := 0;  
  VTEL_NO           := NULL;
  ISANTEIDANTAI_CD  := 0;
END PROC_INITIALIZE;

------------------------------------------------------------------------------
-- 戻り値データセット
------------------------------------------------------------------------------
PROCEDURE PROC_SET_DATA IS
BEGIN
  o_IGENZON_KBN       := IGENZON_KBN;
  o_JINKAKU_KBN       := IJINKAKU_KBN;
  o_VYUBIN_NO         := VYUBIN_NO;
  o_VCHOMEI           := VCHOMEI;
  o_VBANCHI           := VBANCHI;
  o_VKATAGAKI         := VKATAGAKI;
  o_VSHIMEI_KANA      := VSHIMEI_KANA;
  o_VSHIMEI_KANJI     := VSHIMEI_KANJI;
  o_SEINENGAPI        := ISEINENGAPI;
  o_SEIBETSU          := ISEIBETSU;
  o_IGYOSEIKU_CD      := IGYOSEIKU_CD;
  o_VGYOSEIKU_NM      := GAAPK0030.FGYOSEIKUMEI( ISANTEIDANTAI_CD,IGYOSEIKU_CD );
  o_ICHUGAKU_CD       := ICHUGAKU_CD;
  o_VCHUGAKU_NM       := GAAPK0030.FCHUGAKUMEI( ISANTEIDANTAI_CD,ICHUGAKU_CD );
  o_ISHOGAKU_CD       := ISHOGAKU_CD;
  o_VSHOGAKU_NM       := GAAPK0030.FSHOGAKUMEI( ISANTEIDANTAI_CD,ISHOGAKU_CD );
  o_VTEL_NO           := VTEL_NO;
  o_ISANTEIDANTAI_CD  := ISANTEIDANTAI_CD;
  o_VSANTEIDANTAI_NM  := FUNC_JICHINAME( ISANTEIDANTAI_CD );
  o_VCUSTOM_BC        := GAAPK0010.FCUSTOM_BC( VYUBIN_NO,VCHOMEI,VBANCHI,VKATAGAKI );
END PROC_SET_DATA;

------------------------------------------------------------------------------
-- 住記異動検索（最新チェック）
------------------------------------------------------------------------------
FUNCTION FUNC_CHK_JUKIIDO_SAISHIN RETURN PLS_INTEGER IS
  IRTN        PLS_INTEGER;
BEGIN
  IRTN := c_IERR;
  BEGIN
    SELECT JI.JUMIN_NAKUNARU
      INTO IJUMIN_NAKUNARU
      FROM GABTJUKIIDO JI
     WHERE JI.KOJIN_NO = i_IKOJIN_NO;

    IF (IJUMIN_NAKUNARU < i_IKIJUN_BI) AND
       (IJUMIN_NAKUNARU > 0) THEN
        IGENZON_KBN := 1;
    END IF;

    IRTN := c_IOK;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      IRTN := c_INOTFOUND;
    WHEN OTHERS THEN
      IRTN := c_IERR;
  END;

  RETURN IRTN;
EXCEPTION
  WHEN OTHERS THEN
    IRTN := c_IERR;
    RETURN IRTN;
END FUNC_CHK_JUKIIDO_SAISHIN;

------------------------------------------------------------------------------
-- 住記異動検索
------------------------------------------------------------------------------
FUNCTION FUNC_CHK_JUKIIDO RETURN PLS_INTEGER IS
  IRTN        PLS_INTEGER;
BEGIN
  IRTN := c_IERR;
  BEGIN
    SELECT JI.GENZON_KBN,JI.JINKAKU_KBN,
           AK.YUBIN_NO,AK.CHOMEI,AK.BANCHI,AK.KATAGAKI,
           JI.SHIMEI_KANA,JI.SHIMEI_KANJI,
           JI.SEINENGAPI,JI.SEIBETSU,
           JI.GYOSEIKU_CD,JI.CHUGAKU_CD,
           AK.TEL_NO,JI.SANTEIDANTAI_CD
          ,JI.SHOGAKU_CD
      INTO IGENZON_KBN,IJINKAKU_KBN,
           VYUBIN_NO,VCHOMEI,VBANCHI,VKATAGAKI,
           VSHIMEI_KANA,VSHIMEI_KANJI,
           ISEINENGAPI,ISEIBETSU,
           IGYOSEIKU_CD,ICHUGAKU_CD,
           VTEL_NO,ISANTEIDANTAI_CD
          ,ISHOGAKU_CD
      FROM GABTATENAKIHON AK,GABTJUKIIDO JI
     WHERE JI.KOJIN_NO = i_IKOJIN_NO
       AND JI.KOJIN_NO = AK.KOJIN_NO(+)
       AND JI.JUMIN_NARU <= i_IKIJUN_BI
       AND ((JI.JUMIN_NAKUNARU > i_IKIJUN_BI) OR (JI.JUMIN_NAKUNARU = 0));

    IRTN := c_IOK;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      IRTN := c_INOTFOUND;
    WHEN OTHERS THEN
      IRTN := c_IERR;
  END;

  RETURN IRTN;
EXCEPTION
  WHEN OTHERS THEN
    IRTN := c_IERR;
    RETURN IRTN;
END FUNC_CHK_JUKIIDO;

------------------------------------------------------------------------------
-- 宛名履歴検索
------------------------------------------------------------------------------
FUNCTION FUNC_CHK_ATENARIREKI RETURN PLS_INTEGER IS
  IRTN        PLS_INTEGER;
BEGIN
  IRTN := c_IERR;
  BEGIN
    SELECT A.GENZON_KBN,A.JINKAKU_KBN,
           A.YUBIN_NO,A.CHOMEI,A.BANCHI,A.KATAGAKI,
           A.SHIMEI_KANA,A.SHIMEI_KANJI,
           A.SEINENGAPI,A.SEIBETSU,
           A.GYOSEIKU_CD,A.CHUGAKU_CD,
           A.TEL_NO,A.SANTEIDANTAI_CD
          ,A.SHOGAKU_CD
      INTO IGENZON_KBN,IJINKAKU_KBN,
           VYUBIN_NO,VCHOMEI,VBANCHI,VKATAGAKI,
           VSHIMEI_KANA,VSHIMEI_KANJI,
           ISEINENGAPI,ISEIBETSU,
           IGYOSEIKU_CD,ICHUGAKU_CD,
           VTEL_NO,ISANTEIDANTAI_CD
          ,ISHOGAKU_CD
      FROM GABTATENARIREKI A
     WHERE A.KOJIN_NO = i_IKOJIN_NO
       AND A.RIREKI_RENBAN = (SELECT MAX(B.RIREKI_RENBAN)
                                FROM GABTATENARIREKI B
                               WHERE B.KOJIN_NO = A.KOJIN_NO
                                 AND B.JUMIN_NARU <= i_IKIJUN_BI)
       AND ((A.JUMIN_NAKUNARU > i_IKIJUN_BI) OR
            (A.JUMIN_NAKUNARU = 0));
    IRTN := c_IOK;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      IRTN := c_INOTFOUND;
    WHEN OTHERS THEN
      IRTN := c_IERR;
  END;

  RETURN IRTN;
EXCEPTION
  WHEN OTHERS THEN
    IRTN := c_IERR;
    RETURN IRTN;
END FUNC_CHK_ATENARIREKI;

------------------------------------------------------------------------------
-- 住民の時の最終住所を取得（住民用）
------------------------------------------------------------------------------
FUNCTION FUNC_GET_GENJUSHO1 RETURN PLS_INTEGER IS
  IRTN        PLS_INTEGER;
BEGIN
  IRTN := c_IERR;
  BEGIN
    SELECT JJ.YUBIN_NO,JJ.CHOMEI,JJ.BANCHI,JJ.KATAGAKI
      INTO VYUBIN_NO,VCHOMEI,VBANCHI,VKATAGAKI
      FROM GABTJUKIIDO JI,GABTJUKIJUSHO JJ
     WHERE JI.KOJIN_NO = i_IKOJIN_NO
       AND JJ.KOJIN_NO = JI.KOJIN_NO
       AND JJ.JUSHO_REN = JI.GENJUSHO_REN
       ;

    IRTN := c_IOK;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      IRTN := c_INOTFOUND;
    WHEN OTHERS THEN
      IRTN := c_IERR;
  END;

  RETURN IRTN;
EXCEPTION
  WHEN OTHERS THEN
    IRTN := c_IERR;
    RETURN IRTN;
END FUNC_GET_GENJUSHO1;

------------------------------------------------------------------------------
-- 住民の時の最終住所を取得（外国人用）
------------------------------------------------------------------------------
FUNCTION FUNC_GET_GENJUSHO2 RETURN PLS_INTEGER IS
  IRTN        PLS_INTEGER;
BEGIN
  IRTN := c_IERR;
  BEGIN
    SELECT A.YUBIN_NO,A.CHOMEI,A.BANCHI,A.KATAGAKI
      INTO VYUBIN_NO,VCHOMEI,VBANCHI,VKATAGAKI
      FROM GABTATENARIREKI A,
           (SELECT MAX(RIREKI_RENBAN) AS RIREKI_RENBANMAX
              FROM GABTATENARIREKI
             WHERE KOJIN_NO = i_IKOJIN_NO
               AND GENZON_KBN = 0
             GROUP BY KOJIN_NO
           ) B
     WHERE A.KOJIN_NO = i_IKOJIN_NO
       AND A.GENZON_KBN = 0
       AND A.RIREKI_RENBAN = B.RIREKI_RENBANMAX
       ;

    IRTN := c_IOK;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      IRTN := c_INOTFOUND;
    WHEN OTHERS THEN
      IRTN := c_IERR;
  END;

  RETURN IRTN;
EXCEPTION
  WHEN OTHERS THEN
    IRTN := c_IERR;
    RETURN IRTN;
END FUNC_GET_GENJUSHO2;

------------------------------------------------------------------------------
--  メイン処理
------------------------------------------------------------------------------
BEGIN
  IRTN := c_IOK;
  IRTN_J := c_IOK;  
  PROC_INITIALIZE;

  --住記異動検索
  --住記異動（最新住記マスタ）で基準日時点で喪失かどうかをチェック
  IRTN := FUNC_CHK_JUKIIDO_SAISHIN;
  IF IRTN = c_IOK AND IGENZON_KBN = 1 THEN
     --喪失の場合は現存区分＝１をセットしてすぐに終了する
     o_IGENZON_KBN := IGENZON_KBN;
     IRETURN_CODE := c_INOTFOUND;
     RETURN IRETURN_CODE;
  END IF;

  --住記異動検索
  IRTN := FUNC_CHK_JUKIIDO;

  --住記異動に基準日時点のデータが存在する場合（住記異動だけで現存かどうか判断できる場合）
  IF IRTN = c_IOK THEN
    --現存者の場合
      --データを戻り値にセットする
      IGENZON_KBN := 0;  

      --住民だったときの最終住所を取得しなおす。最新宛名住所はすでにセットしているため
      --取得できた場合のみ上書きされる
      IF IJINKAKU_KBN = 0 THEN
        IRTN_J := FUNC_GET_GENJUSHO1;  --住民のとき
      ELSE
        IRTN_J := FUNC_GET_GENJUSHO2;  --外国人のとき
      END IF;

      PROC_SET_DATA;
      IRETURN_CODE := c_IOK;
  --住記異動に基準日時点のデータが存在しない場合
  ELSIF IRTN = c_INOTFOUND THEN
    PROC_INITIALIZE;
    --宛名履歴検索
    IRTN := FUNC_CHK_ATENARIREKI;
    IF IRTN = c_IOK THEN
      --現存者の場合
        --データを戻り値にセットする
        IGENZON_KBN := 0;  

        --住民だったときの最終住所を取得しなおす。最新宛名住所はすでにセットしているため
        --取得できた場合のみ上書きされる
        IF IJINKAKU_KBN = 0 THEN
          IRTN_J := FUNC_GET_GENJUSHO1;  --住民のとき
        ELSE
          IRTN_J := FUNC_GET_GENJUSHO2;  --外国人のとき
        END IF;

        PROC_SET_DATA;
        IRETURN_CODE := c_IOK;
      --宛名履歴にも基準日時点のデータが存在しない場合
      --エラー
    ELSE
      IF IRTN = c_INOTFOUND THEN
      --宛名履歴に基準日時点のデータが存在しない場合
        IRETURN_CODE := c_INOTFOUND;
      ELSE
      --エラー
        IRETURN_CODE := c_IERR;
      END IF;
    END IF;
  --エラーの場合
  ELSIF IRTN = c_IERR THEN
    IRETURN_CODE := c_IERR;
  END IF;

  RETURN IRETURN_CODE;

EXCEPTION
  WHEN OTHERS THEN
    IRETURN_CODE := c_IERR;
    RETURN IRETURN_CODE;
END GKBFKGZSHNT;
/
