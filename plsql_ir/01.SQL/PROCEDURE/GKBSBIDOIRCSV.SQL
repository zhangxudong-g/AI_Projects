CREATE OR REPLACE PROCEDURE GKBSBIDOIRCSV (
--1.0.000.000-02.02-02.02
                                    i_NRENBAN     IN NUMBER,
                                    i_NSHOKUIN_NO IN CHAR,
                                    i_VPRINT_ID   IN NVARCHAR2,
                                    i_VSHORI_ID   IN NVARCHAR2,
                                    i_NSORT_KBN   IN NUMBER,
                                    i_VTANMATSU   IN NVARCHAR2,
                                    i_NTIME       IN NUMBER,
                                    i_ORDERBY     IN  NVARCHAR2  DEFAULT NULL,
                                    i_BATCH       IN  PLS_INTEGER DEFAULT 2 ) IS
------------------------------------------------------------------------------
--  業務名    GKB（教育）
--  PG名      GKBSBIDOIRCSV
--  名称      バッチ処理ワークCSV作成
--  処理概要  バッチ帳票用中間ファイルよりCSVファイルを作成する。
--  引き数    i_NRENBAN       登録連番
--            i_NSHOKUIN_NO   職員番号
--            i_VPRINT_ID     帳票ID
--            i_VSHORI_ID     処理ID
--            i_NSORT_KBN     改頁条件
--                           （0:指定なし,1:学校区-異動事由[異動事由で改頁],2:学校区-届出日-世帯番号[学校区で改頁]）
--            i_VTANMATSU     端末番号
--            i_NTIME         処理時間（時分秒）
--  作成者    ZCZL.LIKEWEN
--  作成日    2024/01/06
--  Version   0.2.000.000
------------------------------------------------------------------------------
  -----------------------------------------------
  --  変数
  -----------------------------------------------
  VERRMSG     NVARCHAR2(256)  :=  'CSV作成処理が異常終了しました。';      --ログ出力用メッセージ
  VLOGMSG     NVARCHAR2(256)  :=  '';           --ログ出力用メッセージ
  B_RTN       BOOLEAN;                          --戻り値（共通）
  I_RTN       PLS_INTEGER;                      --戻り値（共通）
  NRECCNT     NUMBER(8)     :=  0;              --CSV書き込みレコード数

  --動的SQL(1)（中間TBL項目取得用）
  VSQL      NVARCHAR2(2000);                    --SQL文字列用

  --動的SQL(2)（ソート条件項目取得用）
  VSORT_CLM       NVARCHAR2(2000);              --ソート項目

  --CSV出力用
  TYPE  ref_CUR_DOUTAI IS REF CURSOR;           --カーソル定義
  C1    ref_CUR_DOUTAI;                         --動態カーソル
  CR1   GKBWIDOICHIRAN%ROWTYPE;                 --C1カーソルのレコード
  r_WKRECORD001 GKBWL280R001%ROWTYPE;
  nROWNO NUMBER;
BEGIN

  --初期化
  VSORT_CLM := '';
  nROWNO := 0;

  --ソート条件となる項目名を取得
  IF LENGTHB(i_ORDERBY) > 0 THEN
    IF KKAPK0010.FTrim(i_ORDERBY) IS NOT NULL OR KKAPK0010.FTrim(i_ORDERBY) <> '' THEN
      VSORT_CLM := i_ORDERBY;
    END IF;
    IF i_NSORT_KBN = 1 THEN
      VSORT_CLM := 'GAKKO_KBN, (CASE WHEN GAKKO_KBN >= 3 THEN EQGAKKOKU_CD ELSE EAGAKKOKU_CD END), IDO_JIYU, IDO_TODOKE_BI, SETAI_NO, KISAI_JUNI';
    ELSIF i_NSORT_KBN = 2 THEN
      VSORT_CLM := 'GAKKO_KBN, (CASE WHEN GAKKO_KBN >= 3 THEN EQGAKKOKU_CD ELSE EAGAKKOKU_CD END), IDO_TODOKE_BI, SETAI_NO, KISAI_JUNI';
    ELSIF i_NSORT_KBN = 3 THEN
      VSORT_CLM := 'GAKKO_KBN, (CASE WHEN GAKKO_KBN >= 3 THEN EQGAKKOKU_CD ELSE EAGAKKOKU_CD END), IDO_JIYU, SEINENGAPI, SHIMEI_KANA';
    ELSIF i_NSORT_KBN = 4 THEN
      VSORT_CLM := 'GAKKO_KBN, (CASE WHEN GAKKO_KBN >= 3 THEN EQGAKKOKU_CD ELSE EAGAKKOKU_CD END), IDO_JIYU ,SEINENGAPI, SETAI_NO, JIDO_KOJIN_NO, KOJIN_NO';
    ELSE
      VSORT_CLM := VSORT_CLM;
    END IF;
  END IF;

  ----------------------------------------------
  --バッチ処理ワークテーブルより抽出
  ----------------------------------------------
  --SQL文
  VSQL := 'SELECT * FROM GKBWIDOICHIRAN';
  --ソート条件があれば付加
  IF LENGTHB(VSORT_CLM) > 0 THEN
     VSQL := VSQL || ' ORDER BY ' || VSORT_CLM;
  END IF;

  --CSVファイル作成処理
  OPEN C1 FOR VSQL;
  LOOP
    FETCH C1 INTO CR1;
    EXIT WHEN C1%NOTFOUND;
    nROWNO := nROWNO + 1;
    r_WKRECORD001 := NULL;
    r_WKRECORD001.NO                      := nROWNO;                                 --ソート順
    r_WKRECORD001.SHIKUCHOSON_MEI         := CR1.USERMEI;                            --市区町村名
    r_WKRECORD001.CHOHYO_TITLE            := CR1.CHOHYO_TITLE;                       --帳票タイトル
    r_WKRECORD001.SHUKEI_KBN              := CR1.SHUKEI_KBN;                         --集計区分
    r_WKRECORD001.KAISHIBI                := CR1.JKN_CHUSHUTSU_KAISHI;               --条件抽出開始日
    r_WKRECORD001.SHURYOBI                := CR1.JKN_CHUSHUTSU_SHURYO;               --条件抽出終了日
    r_WKRECORD001.SEINENGAPI_KAISHI       := CR1.JKN_SEINENGAPI_KAISHI;              --生年月日始
    r_WKRECORD001.SEINENGAPI_SHURYO       := CR1.JKN_SEINENGAPI_SHURYO;              --生年月日終
    r_WKRECORD001.KOMOKU_MEI1             := CR1.BIKO_2;                             --項目名０１
    r_WKRECORD001.KOMOKU_MEI2             := CR1.BIKO_3;                             --項目名０２
    r_WKRECORD001.KOMOKU_MEI3             := CR1.BIKO_4;                             --項目名０３
    r_WKRECORD001.IDO_JIYU                := CR1.IDO_JIYU_MEI;                       --異動事由
    r_WKRECORD001.IDOSHA_SHIMEI_KANA      := CR1.SHIMEI_KANA;                        --異動者氏名かな
    r_WKRECORD001.IDOSHA_SHIMEI_KANJI     := CR1.SHIMEI_KANJI;                       --異動者氏名漢字
    JIBSKDAYEDIT1(CR1.WAREKI_SEINENGAPI, r_WKRECORD001.SEINENGAPI, I_RTN);           --生年月日
    r_WKRECORD001.ZOKUGARA                := CR1.ZOKUGARA_MEI;                       --続柄
    r_WKRECORD001.SEIBETSU                := CR1.SEIBETSU;                           --性別
    r_WKRECORD001.SHIMEI_KANJI            := CR1.NUSHI_SHIMEI_KANJI;                 --世帯主名
    r_WKRECORD001.CHOMEI                  := CR1.CHOMEI;                             --町名
    r_WKRECORD001.BANCHI                  := CR1.BANCHI;                             --番地
    r_WKRECORD001.KATAGAKI                := CR1.KATAGAKI;                           --方書
    r_WKRECORD001.GYOSEIKU                := CR1.GYOSEIKU_MEI;                       --行政区
    r_WKRECORD001.SETAIIN_ZOKUGARA        := CR1.JITSU_ZOKUGARA_MEI;                 --世帯員続柄
    r_WKRECORD001.RINPOHAN                := CR1.HAN_MEI;                            --隣保班
    r_WKRECORD001.KOJIN_NO                := NVL(CR1.KOJIN_NO,0);                    --個人番号
    JIBSKDAYEDIT1(CR1.IDO_BI, r_WKRECORD001.IDO_BI, I_RTN);                          --異動年月日
    JIBSKDAYEDIT1(CR1.IDO_TODOKE_BI, r_WKRECORD001.TODOKEDEBI, I_RTN);               --届出年月日
    r_WKRECORD001.ZENBU_ICHIBU_KBN        := CR1.ZENBU_ICHIBU_KBN;                   --全部一部区分
    r_WKRECORD001.TENNYU_CHOMEI           := CR1.TENNYU_CHOMEI;                      --転入元町名
    r_WKRECORD001.TENNYU_BANCHI           := CR1.TENNYU_BANCHI;                      --転入元番地
    r_WKRECORD001.TENNYU_KATAGAKI         := CR1.TENNYU_KATAGAKI;                    --転入元方書
    r_WKRECORD001.SHORIBI                 := CR1.JKN_SAKUSEI_BI;                     --条件処理日
    r_WKRECORD001.BIKO_TITLE              := CR1.BIKO_1;                             --備考タイトル
    r_WKRECORD001.GAKKO_KBN               := NVL(CR1.GAKKO_KBN,0);                   --学校区分
    r_WKRECORD001.EQGAKKOKU_CD            := NVL(CR1.EQGAKKOKU_CD,0);                --教育学校区コード
    r_WKRECORD001.ATENA_GAKKOKU_CD        := NVL(CR1.EAGAKKOKU_CD,0);                --宛名学校区コード
    r_WKRECORD001.EQGAKKOKU_MEI           := CR1.EQGAKKOKU_MEI;                      --教育学校区名
    r_WKRECORD001.ATENA_GAKKOKU_MEI       := CR1.EAGAKKOKU_MEI;                      --宛名学校区名
    r_WKRECORD001.SETAI_NO                := NVL(CR1.SETAI_NO,0);                    --世帯番号
    r_WKRECORD001.SETAIIN_SEIBETSU        := CR1.SETAI_SEIBETSU;                     --世帯員性別
    r_WKRECORD001.JINKAKU_KBN             := NVL(CR1.JINKAKU_KBN,0);                 --人格区分
    --改頁キーとヘッダ異動事由と改ページキーの設定
    IF i_NSORT_KBN = 0 THEN
      r_WKRECORD001.KAIPAGE_KEY           := CR1.IDO_JIYU;
      r_WKRECORD001.HD_IDOJIYU            := CR1.IDO_JIYU_MEI;
      r_WKRECORD001.BREAK_NO              := CR1.IDO_JIYU;
    ELSIF i_NSORT_KBN = 1 THEN
      r_WKRECORD001.KAIPAGE_KEY           := CR1.IDO_JIYU;
      r_WKRECORD001.HD_IDOJIYU            := CR1.IDO_JIYU_MEI;
      r_WKRECORD001.BREAK_NO              := CR1.IDO_JIYU;
    ELSIF i_NSORT_KBN = 2 THEN
      r_WKRECORD001.KAIPAGE_KEY           := CASE WHEN CR1.GAKKO_KBN >= 3 THEN CR1.EQGAKKOKU_CD ELSE CR1.EAGAKKOKU_CD END;
      r_WKRECORD001.HD_IDOJIYU            := NULL;
      r_WKRECORD001.BREAK_NO              := CASE WHEN CR1.GAKKO_KBN >= 3 THEN CR1.EQGAKKOKU_CD ELSE CR1.EAGAKKOKU_CD END;
    ELSIF i_NSORT_KBN = 3 THEN
      r_WKRECORD001.KAIPAGE_KEY           := CR1.IDO_JIYU;
      r_WKRECORD001.HD_IDOJIYU            := CR1.IDO_JIYU_MEI;
      r_WKRECORD001.BREAK_NO              := CR1.IDO_JIYU;
    ELSIF i_NSORT_KBN = 4 THEN
      r_WKRECORD001.KAIPAGE_KEY           := CASE WHEN CR1.GAKKO_KBN >= 3 THEN CR1.EQGAKKOKU_CD ELSE CR1.EAGAKKOKU_CD END;
      r_WKRECORD001.HD_IDOJIYU            := NULL;
      r_WKRECORD001.BREAK_NO              := CASE WHEN CR1.GAKKO_KBN >= 3 THEN CR1.EQGAKKOKU_CD ELSE CR1.EAGAKKOKU_CD END;
    END IF;
    r_WKRECORD001.WSNUM                   := i_VTANMATSU;    --端末番号
    r_WKRECORD001.BATCHKBN                := i_BATCH;        --バッチ区分
    r_WKRECORD001.JOBNUM                  := i_NRENBAN;      --ジョブNO

    INSERT INTO GKBWL280R001 VALUES r_WKRECORD001;

  END LOOP;

  IF C1%ISOPEN THEN
    CLOSE C1;
  END IF;

  --出力件数カウント
  NRECCNT := nROWNO;

  --件数ログ出力
  VLOGMSG := 'CSVファイルに処理データ' || NRECCNT || '件を作成しました。';
  B_RTN := KKBPK5551.FSETBLOG (i_NRENBAN, 'GKBSBIDOIRCSV', 0, '', '', SUBSTR(VLOGMSG, 1, 256), i_NSHOKUIN_NO, i_VTANMATSU);

  ----------------------------------------------
  --正常終了
  ----------------------------------------------
  --処理ログの出力
  B_RTN := KKBPK5551.FSETBLOG (i_NRENBAN, 'GKBSBIDOIRCSV', 0, '', '', 'CSV作成処理が正常終了しました。', i_NSHOKUIN_NO, i_VTANMATSU);

EXCEPTION
  ----------------------------------------------
  --例外処理
  ----------------------------------------------
  WHEN OTHERS THEN
    --ファイルのクローズ
    IF C1%ISOPEN THEN
      CLOSE C1;
    END IF;
    --ログの出力
    B_RTN := KKBPK5551.FSETBLOG (i_NRENBAN, 'GKBSBIDOIRCSV', 1, SQLCODE, SQLERRM, SUBSTR(VERRMSG,1,100), i_NSHOKUIN_NO, i_VTANMATSU);
END GKBSBIDOIRCSV;
/
