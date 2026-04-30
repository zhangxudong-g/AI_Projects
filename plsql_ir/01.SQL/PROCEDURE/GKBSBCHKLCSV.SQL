CREATE OR REPLACE PROCEDURE GKBSBCHKLCSV (i_NRENBAN    IN  NUMBER,
--1.0.000.000-02.02-02.02
                                              i_NSHOKUIN_NO   IN  NVARCHAR2,
                                              i_VTANMATSU_NO  IN  NVARCHAR2,
                                              i_NTIME         IN  NUMBER,
                                              i_VCHOHYO_ID    IN  NVARCHAR2,
                                              i_VWKTABLE      IN  NVARCHAR2,
                                              o_BRTN          OUT BOOLEAN,
                                              i_ORDERBY       IN  NVARCHAR2  DEFAULT NULL,
                                              i_Batch         IN  NVARCHAR2)
-------------------------------------------------------------------
--  業務名       GKB（教育）
--  PG 名        GKBSBCHKLCSV
--  名称         バッチ処理ワークCSV作成
--  処理概要     バッチ帳票用中間ファイルよりCSVファイルを作成する
--  引き数       i_NRENBAN        登録連番
--               i_NSHOKUIN_NO    職員個人番号
--               i_VTANMATSU_NO   端末番号
--               i_NTIME          時分秒
--               i_VCHOHYO_ID     帳票ＩＤ（定義体名）
--               i_VWKTABLE       中間テーブル名
--               o_BRTN           ステータス
--               i_ORDERBY        出力ソート順
--               i_Batch          バッチ区分
--  作成者       ZCZL.LIKEWEN
--  作成日       2024/01/06
--  Version      0.2.000.000
--------------------------------------------------------
--  変更履歴
--  2024/04/25 ZCZL.LIKEWEN UPDATE 0.2.000.001:512_GKB_00028対応
--  2024/06/17 ZCZL.muzhilin Update 0.3.000.000:新WizLIFE２次開発
---------------------------------------------------------
--------------------------------------------------------
IS
--------------------------------------------------------------------
--  定数宣言
--------------------------------------------------------------------
  c_BERROR      CONSTANT BOOLEAN := FALSE;
  c_BNORMALEND  CONSTANT BOOLEAN := TRUE;

--------------------------------------------------------------------
--  変数宣言
--------------------------------------------------------------------
  BRTN            BOOLEAN;                -- ステータス
  I_RTN           PLS_INTEGER;            -- 戻り値（共通）
  VERRMSG         NVARCHAR2(256);         -- エラーメッセージ
  VORDER_BY       NVARCHAR2(2000);        -- 中間TBLソート用
  -- 動的ＳＱＬ
  VSQL            VARCHAR2(4000);         -- SQL文字列用

--------------------------------------------------------------------------------
-- ソート条件を取得
--------------------------------------------------------------------------------
  FUNCTION FUNC_GET_SORT_ORDER
    RETURN NVARCHAR2
  IS
    V_WKORDER             VARCHAR2(3000);
  BEGIN
    BEGIN
      V_WKORDER := ' KAIPEJI_CD ';
      IF KKAPK0010.FTrim(i_ORDERBY) IS NOT NULL OR KKAPK0010.FTrim(i_ORDERBY) <> '' THEN
        V_WKORDER := V_WKORDER || ', ' || i_ORDERBY;
      END IF; 
    EXCEPTION
      WHEN OTHERS THEN
        V_WKORDER := ' RENBAN ';
    END;
    RETURN V_WKORDER;
  END FUNC_GET_SORT_ORDER;

--------------------------------------------------------------------
--  ＣＳＶ作成
--------------------------------------------------------------------
  FUNCTION FUNCOUT_CSV RETURN BOOLEAN IS
    TYPE  ref_CUR_DOUTAI IS REF CURSOR;    --カーソル定義
    C1    ref_CUR_DOUTAI;                  --動態カーソル
    CR1   GKBWCHECK%ROWTYPE;               --C1カーソルのレコード
    r_WKRECORD001 GKBWL320R001%ROWTYPE;
    nROWNO      NUMBER := 0;
    v_GKB_TMP_YMDBI NVARCHAR2(100);
  BEGIN
  
    --SQL文作成
    VSQL := ' SELECT * FROM GKBWCHECK ';
    IF VORDER_BY <> ' ' THEN
      VSQL := VSQL || ' ORDER BY ' || VORDER_BY;
    END IF;
    --初期化
    DELETE FROM GKBWL320R001 WHERE WSNUM = i_VTANMATSU_NO AND BATCHKBN = i_Batch;

    --CSVファイル作成処理
    OPEN C1 FOR VSQL;
    LOOP
      FETCH C1 INTO CR1;
      EXIT WHEN C1%NOTFOUND;

      nROWNO := nROWNO + 1;
      r_WKRECORD001 := NULL;
      r_WKRECORD001.NO                   := nROWNO;                       --ソート順
      r_WKRECORD001.JIDO_KOJIN_NO        := NVL(CR1.JIDO_KOJIN_NO,0);     --児童個人番号
      r_WKRECORD001.JIDO_SHIMEI_KANA     := CR1.JIDO_SHIMEI_KANA;         --児童氏名かな
      r_WKRECORD001.JIDO_SHIMEI_KANJI    := CR1.JIDO_SHIMEI_KANJI;        --児童氏名漢字
      r_WKRECORD001.SEINENGAPI           := NVL(CR1.SEINENGAPI,0);        --生年月日
      JIBSKDAYEDIT1(CR1.HYOJI_SEINENGAPI, CR1.HYOJI_SEINENGAPI, I_RTN);
      r_WKRECORD001.HYOJI_SEINENGAPI     := CR1.HYOJI_SEINENGAPI;         --表示用生年月日
      r_WKRECORD001.SEIBETSU             := NVL(CR1.SEIBETSU,0);          --性別
      r_WKRECORD001.HYOJI_SEIBETSU       := CR1.HYOJI_SEIBETSU;           --表示用性別
      r_WKRECORD001.ZOKUGARAMEI1         := CR1.ZOKUGARAMEI1;             --保護者との関係
-- 2024/06/18 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
      r_WKRECORD001.JIDO_KOKUSEKI        := CR1.JIDO_KOKUSEKI;            -- 児童生徒国籍
      r_WKRECORD001.SETAI_NO             := NVL(CR1.SETAI_NO,0);          --世帯番号
      r_WKRECORD001.HOGOSHA_KOJIN_NO     := NVL(CR1.HOGOSHA_KOJIN_NO,0);  --保護者個人番号
      r_WKRECORD001.HOGOSHA_SHIMEI_KANA  := CR1.HOGOSHA_SHIMEI_KANA;      --保護者氏名かな
      r_WKRECORD001.HOGOSHA_SHIMEI_KANJI := CR1.HOGOSHA_SHIMEI_KANJI;     --保護者氏名漢字
-- 2024/06/18 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
      r_WKRECORD001.HOGOSHA_KOKUSEKI     := CR1.HOGOSHA_KOKUSEKI;         -- 保護者国籍
      r_WKRECORD001.ZOKUGARAMEI2         := CR1.ZOKUGARAMEI2;             --児童生徒との関係
      r_WKRECORD001.GAKUNEN_CD           := NVL(CR1.GAKUNEN_CD,0);        --学年コード
      r_WKRECORD001.GAKUNENMEI           := CR1.GAKUNENMEI;               --学年名
      r_WKRECORD001.ATENA_GAKU_CD        := NVL(CR1.ATENA_GAKU_CD,0);     --宛名学校コード
      r_WKRECORD001.ATENA_GAKU_MEI       := CR1.ATENA_GAKU_MEI;           --宛名学校名
      r_WKRECORD001.GAKOKU_CD            := NVL(CR1.GAKOKU_CD,0);         --学校区コード
      r_WKRECORD001.GAKOKUMEI            := CR1.GAKOKUMEI;                --学校区名
      r_WKRECORD001.GYOSEIKU_CD          := NVL(CR1.GYOSEIKU_CD,0);       --行政区コード
      r_WKRECORD001.GYOSEIKUMEI          := CR1.GYOSEIKUMEI;              --行政区名
      r_WKRECORD001.HAN_CD               := NVL(CR1.HAN_CD,0);            --班コード
      r_WKRECORD001.HANMEI               := CR1.HANMEI;                   --班名
      r_WKRECORD001.SANTEIDANTAI_CD      := NVL(CR1.SANTEIDANTAI_CD,0);   --算定団体コード
      r_WKRECORD001.SANTEIDANTAIMEI      := CR1.SANTEIDANTAIMEI;          --算定団体名
      r_WKRECORD001.YUBIN_NO             := CR1.YUBIN_NO;                 --郵便番号
      r_WKRECORD001.CHOMEI               := CR1.CHOMEI;                   --町名
      r_WKRECORD001.BANCHI               := CR1.BANCHI;                   --番地
      r_WKRECORD001.KATAGAKI             := CR1.KATAGAKI;                 --方書
      r_WKRECORD001.BIKO                 := CR1.BIKO;                     --備考
      JIBSKDAYEDIT1(CR1.SOSHITSUBI, CR1.SOSHITSUBI, I_RTN);
      --  2024/04/25 ZCZL.LIKEWEN UPDATE START 0.2.000.001:512_GKB_00028対応
      --r_WKRECORD001.KAIPAGE_CD           := CR1.KAIPEJI_CD ||'GAKOKU_CD' ;               --改ページコード
      --r_WKRECORD001.KAIPAGE_MEI          := CR1.KAIPEJI || '　' || 'GAKOKUMEI' ;                  --改ページ名称
      r_WKRECORD001.KAIPEJI_CD           := CR1.KAIPEJI_CD || CR1.GAKOKU_CD;               --改ページコード
      r_WKRECORD001.KAIPEJI              := CR1.KAIPEJI || '　' || CR1.GAKOKUMEI;          --改ページ名称
      --  2024/04/25 ZCZL.LIKEWEN UPDATE END
      v_GKB_TMP_YMDBI := '';
      JIBSKDAYEDIT2(CR1.SAKUSEIBI, v_GKB_TMP_YMDBI, I_RTN);
      r_WKRECORD001.SAKUSEIBI            := v_GKB_TMP_YMDBI;              --作成日
      r_WKRECORD001.RENBAN               := CR1.RENBAN;                   --連番
      r_WKRECORD001.BREAK_NO             := CR1.KAIPEJI_CD;               --改ページキー
      r_WKRECORD001.WSNUM                := i_VTANMATSU_NO;               --端末番号
      r_WKRECORD001.BATCHKBN             := i_Batch;                      --バッチ区分
      r_WKRECORD001.JOBNUM               := i_NRENBAN;                    --ジョブNO

      INSERT INTO GKBWL320R001 VALUES r_WKRECORD001;
    END LOOP;

    IF C1%ISOPEN THEN
      CLOSE C1;
    END IF;

    RETURN(c_BNORMALEND);
  EXCEPTION
    WHEN OTHERS THEN
      IF C1%ISOPEN THEN
        CLOSE C1;
      END IF;
      RETURN(c_BERROR);
  END FUNCOUT_CSV;

--------------------------------------------------------------------
--  メイン
--------------------------------------------------------------------
BEGIN

  -- ソート条件を取得
  VORDER_BY := FUNC_GET_SORT_ORDER;

  --  CSV作成
  BRTN := FUNCOUT_CSV;
  IF BRTN = c_BERROR THEN
    o_BRTN := c_BERROR;
    RETURN;
  END IF;
  o_BRTN := c_BNORMALEND;
EXCEPTION
  WHEN OTHERS THEN
    VERRMSG := SUBSTR('ＣＳＶ作成処理が異常終了しました。' || SQLERRM, 1, 256);
    BRTN := KKBPK5551.FSETBLOG (i_NRENBAN, 'GKBSBCHKLCSV', 1, SQLCODE, SQLERRM, VERRMSG, i_NSHOKUIN_NO, i_VTANMATSU_NO);
    o_BRTN := c_BERROR;
END GKBSBCHKLCSV;
/
