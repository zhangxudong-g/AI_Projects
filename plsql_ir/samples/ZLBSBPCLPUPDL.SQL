CREATE OR REPLACE PROCEDURE ZLBSBPCLPUPDL
--1.1.200.000
                            (i_JOBNUM      IN NUMBER,
                             i_NSHOKUIN_NO  IN CHAR,
                             i_VTANMATSU_NO IN NVARCHAR2,
                             i_NTIME        IN NUMBER,
                             o_NRTN         OUT NUMBER,
                             i_CHOHYOID     IN CHAR,
                             i_ORDERBYCLAUSE IN  NVARCHAR2,

                             i_IBATCH_KBN   IN  PLS_INTEGER DEFAULT 0)  --バッチ区分
-------------------------------------------------------------------------------
--  業務名      ZLB（国保税）
--  PG名        ZLBSBPCLPUPDL
--  名称        遡及賦課更正リスト出力用ＣＳＶファイル作成
--  処理概要    課税計算で作成された遡及賦課更正者リストワークを元に
--              遡及賦課更正リスト賦課更正対象外分）を作成する。
--  作成者      ZCZL.LIUDI
--  作成日      2023/08/01
--  Version     0.2.000.000
-------------------------------------------------------------------------------------
--変更履歴
--2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
------------------------------------------------------------------------------
--  変更履歴
--  2024/01/25 ZCZL.HAODAPENG UPDATE 0.2.000.001:512_KHS_0028の横展開
------------------------------------------------------------------------------
--  変更履歴
--  2024/01/29 ZCZL.ZHANGLEI Update 0.2.000.002:512_ZLB_0035対応
--  2024/02/03 ZCZL.HAODAPENG Update 0.2.000.003:512_ZLB_0035対応_2回目
--  2025/08/11 ZCZL.HAODAPENG Update 1.1.200.000:子ども子育て支援金対応
------------------------------------------------------------------------------
IS
-------------------------------------------------------------------------------
--カーソル定義
-------------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --カーソル名  帳票基本データ（個人）から新規賦課されたデータを抽出する。
    --引き数      p_LISTHANTEIKBN           帳票判定区分
    --OUTPUT      遡及賦課更正者リストワークテーブルの全体データ
    ---------------------------------------------------------------------------
    CURSOR CJLPR02CALPASSUPDLST(p_LISTHANTEIKBN IN NUMBER) IS
    SELECT *
    FROM
      ZLBW_02CALPASSUPD_LST
    WHERE
        LIST_HANTEI_KBN = p_LISTHANTEIKBN
    ORDER BY
      SANTEIDANTAI_CD,
      CHOTEI_NENDO,
      NENDO_BUN,
      KOKU_SETAI_NO,
      TSUCHI_NO,
      KOJIN_NO;

-------------------------------------------------------------------------------
--定数宣言
-------------------------------------------------------------------------------
    c_PG_NAME     CONSTANT NVARCHAR2(30) := 'ZLBSBPCLPUPDL';
    c_SYORI_OK    CONSTANT NUMBER  := 0;
    c_SYORI_NG    CONSTANT NUMBER  := 1;
    --  2024/02/03 ZCZL.HAODAPENG Update START 0.2.000.003:512_ZLB_0035対応_2回目
    --c_O_BAT       CONSTANT PLS_INTEGER :=  0;           --オンラインバッチ
    c_O_BAT       CONSTANT PLS_INTEGER :=  2;           --2:バッチ
    --  2024/02/03 ZCZL.HAODAPENG Update END
    --遡及賦課更正リスト（賦課更正反映分）のCSV名
    c_JLPR02CALPASSUPDLST01 CONSTANT NVARCHAR2(256) := 'ZLBW_02CALPASSUPD_LST01' ||
                                                       TO_CHAR(i_VTANMATSU_NO)   ||
                                                       TO_CHAR(i_NSHOKUIN_NO)    ||
                                                       TO_CHAR(i_NTIME)          ||
                                                       '.CSV';

    c_JLPR02CALPASSUPDLST02 CONSTANT NVARCHAR2(256) := 'ZLBW_02CALPASSUPD_LST02' ||
                                                       TO_CHAR(i_VTANMATSU_NO)   ||
                                                       TO_CHAR(i_NSHOKUIN_NO)    ||
                                                       TO_CHAR(i_NTIME)          ||
                                                       '.CSV';
-------------------------------------------------------------------------------
--変数宣言
-------------------------------------------------------------------------------
    --プロジェクト用の変数
    BMAIN_RETURN                 BOOLEAN;        --戻り値
    IMAIN_RETURN                 PLS_INTEGER;    --戻り値
    NMAIN_SRENBAN                NUMBER(10);     --登録連番
    VMAIN_MSG                    NVARCHAR2(256); --ログメッセージ
    IMAIN_DATACOUNT              PLS_INTEGER;    --データの件数
    IMAIN_LOGRETURN1             PLS_INTEGER;    --STEP1のリターン値
    IMAIN_LOGRETURN2             PLS_INTEGER;    --STEP2のリターン値
    IMAIN_LOGRETURN3             PLS_INTEGER;    --STEP3のリターン値
    IMAIN_LOGRETURN4             PLS_INTEGER;    --STEP4のリターン値

    --バッチ処理条件取得パラメータ
    --  2024/01/25 ZCZL.HAODAPENG UPDATE START 0.2.000.001:512_KHS_0028の横展開
    ISORT_SORT01                 PLS_INTEGER;    --ソート条件01
    ISORT_SORT02                 PLS_INTEGER;    --ソート条件02
    ISORT_SORT03                 PLS_INTEGER;    --ソート条件03
    ISORT_SORT04                 PLS_INTEGER;    --ソート条件04
    ISORT_SORT05                 PLS_INTEGER;    --ソート条件05
    ISORT_SORT06                 PLS_INTEGER;    --ソート条件06
    ISORT_SORT07                 PLS_INTEGER;    --ソート条件07
    ISORT_SORT08                 PLS_INTEGER;    --ソート条件08
    ISORT_SORT09                 PLS_INTEGER;    --ソート条件09
    ISORT_SORT10                 PLS_INTEGER;    --ソート条件10
    ISORT_SORT11                 PLS_INTEGER;    --ソート条件11
    ISORT_SORT12                 PLS_INTEGER;    --ソート条件12
    ISORT_SORT13                 PLS_INTEGER;    --ソート条件13
    ISORT_SORT14                 PLS_INTEGER;    --ソート条件14
    ISORT_SORT15                 PLS_INTEGER;    --ソート条件15
    ISORT_BREAK                  PLS_INTEGER;    --改ページ番号
    ISORT_ADRESS                 PLS_INTEGER;    --住所編集区分
    ISORT_MOJISU1                PLS_INTEGER;    --文字列編集段数1
    ISORT_MOJISU2                PLS_INTEGER;    --文字列編集段数2
    ISORT_MOJISU3                PLS_INTEGER;    --文字列編集段数3
    ISORT_MOJISU4                PLS_INTEGER;    --文字列編集段数4
    ISORT_MOJISU5                PLS_INTEGER;    --文字列編集段数5
    --  2024/01/25 ZCZL.HAODAPENG UPDATE END

    VSTART_DOKUJI                NVARCHAR2(500); --独自条件
    BSTART_MAEKEKA               BOOLEAN;        --前処理結果の正常終了の有無
    IBATCHKBN                    PLS_INTEGER;    -- バッチ区分

    --テーブルデータ用の変数
    NBREAKKEY                    NVARCHAR2(256); --改ページキー
    NSAKUSEIBI                   NUMBER(8);      --作成日
    --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
    --NKOKUSETAINO                 NUMBER(12);     --国保世帯番号
    NKOKUSETAINO                 NUMBER;     --国保世帯番号
    --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
    --NKOJINNO                     NUMBER(12);     --個人番号
    NKOJINNO                     NUMBER;     --個人番号
    NSANTEIDANTAICD              NUMBER(2);      --算定団体コード
    NCHOTEINENDO                 NUMBER(4);      --調定年度
    NNENDOBUN                    NUMBER(4);      --年度分
    NTSUCHINO                    NUMBER(12);     --通知書番号
    NJLTKIHONNSEKISAN            NUMBER(12);     --賦課基本(最新)テーブルの積算税額
    NJLTTAINSEKISAN              NUMBER(12);     --賦課退職(最新)テーブルの積算税額
    NJLTKAIKIHONNSEKISAN         NUMBER(12);     --賦課介護基本(最新)テーブルの積算税額
    NJLTKAITAINSEKISAN           NUMBER(12);     --賦課介護退職(最新)テーブルの積算税額
    NJLTSIENKIHONNSEKISAN        NUMBER(12);     --賦課支援基本(最新)テーブルの積算税額
    NJLTSIENTAINSEKISAN          NUMBER(12);     --賦課支援退職(最新)テーブルの積算税額
    NJLTKIHONMIDSEKISAN          NUMBER(12);     --中間基本テーブルの積算税額
    NJLTTAIMIDSEKISAN            NUMBER(12);     --中間退職テーブルの積算税額
    NJLTKAIKIHONMIDSEKISAN       NUMBER(12);     --中間介護基本テーブルの積算税額
    NJLTKAITAIMIDSEKISAN         NUMBER(12);     --中間介護退職テーブルの積算税額
    NJLTSIENKIHONMIDSEKISAN      NUMBER(12);     --賦課支援基本(最新)テーブルの積算税額
    NJLTSIENTAIMIDSEKISAN        NUMBER(12);     --賦課支援退職(最新)テーブルの積算税額
    NFFTSHIKAKUIDOBI             NUMBER(8);      --資格基本テーブルの異動日
    NFFTSHIKAKUSOSHITSUBI        NUMBER(8);      --資格基本テーブルの喪失年月日
    NFFTSHIKAKUJIYU              NUMBER(2);      --資格基本テーブルの取得事由
    NFFTSHIKAKUTODOKEBI          NUMBER(8);      --資格基本テーブルの届出日
    NFFTSHIKAKUSHIKKBN           NUMBER(1);      --資格基本テーブルの資格区分
    --  2025/08/11 ZCZL.HAODAPENG add start 1.1.200.000:子ども子育て支援金対応
    NKODOMOSEKISANGAKU_SAISIN    NUMBER(12);     --賦課子ども基本(最新)テーブルの積算税額
    NKODOMOSEKISANGAKU_CHOKAN    NUMBER(12);     --賦課子ども基本(中間)テーブルの積算税額
    --  2025/08/11 ZCZL.HAODAPENG add end


    -- CSVファイルを格納するパス ⇒ 固定資産税ではこちらを使用する
    O_VCSVDIR_DB                 VARCHAR2(200);
    O_VY_CSVDIR_DB               VARCHAR2(200);    --夜間バッチ用
    VCSVPATH                     NVARCHAR2(1000) := '';
    -- 帳票定義体を格納するパス
    O_VTEIGIDIR                  VARCHAR2(200);
    -- CSVファイルを格納するパス(プリントサーバー)
    O_VCSVDIR_PRN                VARCHAR2(200);
    -- OWFを格納するパス
    O_VOWFDIR                    VARCHAR2(200);
    -- PDFを格納するパス
    O_VPDFDIR                    VARCHAR2(200);
    -- PDFを作成するかどうかのフラグ(1=作る,2=作らない)
    O_PDFFLG                     PLS_INTEGER;

    --遡及賦課更正者リストワークの表類型
    TJLPR02CALPASSUPDLST         ZLBW_02CALPASSUPD_LST%ROWTYPE;
    --宛名レコード
    RATENA_REC                   GABTATENAKIHON%ROWTYPE;
    --送付先レコード
    RSOFU_REC                    GABTSOFUSAKI%ROWTYPE;
-------------------------------------------------------------------------------
--FUNCTION定義
-------------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --変数を初期化
    --返る数 TRUE:正常 FALSE:エラー
    ---------------------------------------------------------------------------
    FUNCTION FUNCINTSET RETURN BOOLEAN IS
    BEGIN
      --戻り値
      BMAIN_RETURN     := TRUE;
      --戻り値
      IMAIN_RETURN     := 0;
      --登録連番
      NMAIN_SRENBAN    := i_JOBNUM;
      --データの件数
      IMAIN_DATACOUNT  := 0;
      --ログメッセージ
      VMAIN_MSG        := '';
      --ログメッセージ
      VMAIN_MSG        := '';
      --STEP1のリターン値
      IMAIN_LOGRETURN1 := 0;
      --STEP2のリターン値
      IMAIN_LOGRETURN2 := 0;
      --STEP3のリターン値
      IMAIN_LOGRETURN3 := 0;
      --STEP4のリターン値
      IMAIN_LOGRETURN4 := 0;

      --終了
      RETURN(TRUE);
    EXCEPTION
      WHEN OTHERS THEN
        --異常終了
        RETURN(FALSE);
    END FUNCINTSET;

--  2024/01/25 ZCZL.HAODAPENG UPDATE START 0.2.000.001:512_KHS_0028の横展開
    ---------------------------------------------------------------------------
    --バッチ帳票ソート条件取得処理を行う
    --返る数 TRUE:正常 FALSE:エラー
    ---------------------------------------------------------------------------
    FUNCTION FUNCAHPFSORT(ISORT_SRENBAN IN NUMBER) RETURN BOOLEAN IS
    BEGIN
      --バッチ帳票ソート条件取得
      ISORT_SORT01 := 1;
      ISORT_SORT02 := 2;
      ISORT_SORT03 := 3;
      ISORT_SORT04 := 4;
      ISORT_SORT05 := 5;
      ISORT_SORT06 := 6;
      ISORT_SORT07 := 7;
      ISORT_SORT08 := 8;
      ISORT_SORT09 := 9;
      ISORT_SORT10 := 10;
      ISORT_SORT11 := 11;
      ISORT_SORT12 := 12;
      ISORT_SORT13 := 13;
      ISORT_SORT14 := 14;
      ISORT_SORT15 := 15;
      ISORT_BREAK := 3;

      --終了
      RETURN(TRUE);
    EXCEPTION
      WHEN OTHERS THEN
        --異常終了
        RETURN(FALSE);
    END FUNCAHPFSORT;
--  2024/01/25 ZCZL.HAODAPENG UPDATE END

    ---------------------------------------------------------------------------
    --時間を取得します
    --返る数 システムの時間
    ---------------------------------------------------------------------------
    FUNCTION FUNCGETTIME RETURN NVARCHAR2 IS
    BEGIN
      RETURN(TO_CHAR(SYSDATE, 'HH24:MI:SS'));
    END FUNCGETTIME;

    ---------------------------------------------------------------------------
    --ログを出力します
    --引き数 INPUT  i_STEP         ログNO
    --返る数 システムの時間
    ---------------------------------------------------------------------------
    PROCEDURE PROCWRITELOG(i_STEP IN NUMBER) IS
    ISYORI PLS_INTEGER := 0;
    BlRTN  BOOLEAN;          --戻り値
    BEGIN
        --ログ内容を取得します
        CASE i_STEP
        WHEN 1 THEN VMAIN_MSG := '遡及賦課更正者リスト(CSV)の作成処理を開始します(' ||
                                 c_PG_NAME ||
                                 ' ' ||
                                 FUNCGETTIME ||
                                 ')';
        WHEN 2 THEN VMAIN_MSG := '帳票基本データ（個人）' ||
                                 IMAIN_DATACOUNT  ||
                                 '件読み込みました';
        WHEN 3 THEN VMAIN_MSG := '帳票(遡及賦課更正者リスト)へ' ||
                                 IMAIN_DATACOUNT ||
                                 '件出力しました';
        WHEN 4 THEN VMAIN_MSG := '遡及賦課更正者リスト作成処理は正常終了しました(' ||
                                 c_PG_NAME ||
                                 ' ' ||
                                 FUNCGETTIME ||
                                 ')';
        WHEN 5 THEN VMAIN_MSG := '遡及賦課更正者リスト作成処理は異常終了しました(' ||
                                 c_PG_NAME ||
                                 ' ' ||
                                 FUNCGETTIME ||
                                 ')';
        ELSE VMAIN_MSG := '';
        END CASE;

        --異常の場合ではありません
        IF i_STEP <> 5 THEN
            ISYORI := c_SYORI_OK;
        ELSE
            ISYORI := c_SYORI_NG;
        END IF;

        --ログを出力します

        IF i_STEP <> 5 THEN
          --オンライン
          IF i_JOBNUM = 0 THEN
              BlRTN := KKBPK5551.FSETOLOG (i_VTANMATSU_NO, TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'),'ZLBSBPCLPUPDL', 0, 0, '','', SUBSTR(VMAIN_MSG,1,256));
          ELSE
              BlRTN := KKBPK5551.FSETBLOG (i_JOBNUM, 'ZLBSBPCLPUPDL', 0, '', '', SUBSTR(VMAIN_MSG,1,256), i_NSHOKUIN_NO, i_VTANMATSU_NO);
          END IF;
        ELSE
          IF SQLCODE = 0 THEN

            --オンライン
            IF i_JOBNUM = 0 THEN
                BlRTN := KKBPK5551.FSETOLOG (i_VTANMATSU_NO, TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'),'ZLBSBPCLPUPDL', 1, 0, '','', SUBSTR(VMAIN_MSG,1,256));
            ELSE
                BlRTN := KKBPK5551.FSETBLOG (i_JOBNUM, 'ZLBSBPCLPUPDL', 1, '', '',SUBSTR(VMAIN_MSG,1,256), i_NSHOKUIN_NO, i_VTANMATSU_NO);
            END IF;
          ELSE
            --オンライン
            IF i_JOBNUM = 0 THEN
                BlRTN := KKBPK5551.FSETOLOG (i_VTANMATSU_NO, TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'),'ZLBSBPCLPUPDL', 1, 0, SQLCODE, SQLERRM,SUBSTR(VMAIN_MSG,1,256));
            ELSE
                BlRTN := KKBPK5551.FSETBLOG (i_JOBNUM, 'ZLBSBPCLPUPDL', 1, SQLCODE, SQLERRM,SUBSTR(VMAIN_MSG,1,256), i_NSHOKUIN_NO, i_VTANMATSU_NO);
            END IF;

          END IF;
        END IF;

    END PROCWRITELOG;


--  2024/01/25 ZCZL.HAODAPENG UPDATE START 0.2.000.001:512_KHS_0028の横展開
    ---------------------------------------------------------------------------
    --ソートを取得します
    --引き数 INPUT  i_SOTONO         ソートNO
    --              i_LISTHANTEIKBN  帳票判定区分
    --返る数 ソート値
    ---------------------------------------------------------------------------
    FUNCTION FUNCGETSOTO(i_SOTONO        IN NUMBER,
                         i_LISTHANTEIKBN IN NUMBER) RETURN NVARCHAR2 IS
    VRET NVARCHAR2(256) := '';
    BEGIN
      CASE i_SOTONO
      --帳票判定区分
      WHEN 1 THEN VRET := i_LISTHANTEIKBN;
      --調定年度
      WHEN 2 THEN VRET := LPAD(NCHOTEINENDO,4,0);
      --年度分
      WHEN 3 THEN VRET := LPAD(NNENDOBUN,4,0);
      --通知書番号
      WHEN 4 THEN VRET := LPAD(NTSUCHINO,12,0);
      --世帯主氏名漢字
      WHEN 5 THEN VRET := RPAD(TJLPR02CALPASSUPDLST.NUSHI_NAME,20,' ');
      --住所
      WHEN 6 THEN VRET := SUBSTR(RPAD(TJLPR02CALPASSUPDLST.NUSHI_CHOMEI ||
                          TJLPR02CALPASSUPDLST.NUSHI_BANCHI             ||
                          TJLPR02CALPASSUPDLST.NUSHI_KATAGAKI,40,' '),1,40);
      --証番号
      WHEN 7 THEN VRET := LPAD(TJLPR02CALPASSUPDLST.SHO_NO,20,0);
      ELSE VRET := '';
      END CASE;

      RETURN(VRET);
    END FUNCGETSOTO;

    -----------------------------------------------------------
    --  改ページキー、改ページ名称作成（不要な改ページ条件の取捨選択も行う）
    -----------------------------------------------------------
    FUNCTION FUNCBREAKFLDVAL(i_NIDX  IN  NUMBER) RETURN NVARCHAR2 IS
      VRKEY NVARCHAR2(256) := '';
    BEGIN
      CASE i_NIDX
        WHEN 2 THEN VRKEY := LPAD(NCHOTEINENDO,4,0);
        WHEN 3 THEN VRKEY := LPAD(NNENDOBUN,4,0);
        WHEN 4 THEN VRKEY := LPAD(NTSUCHINO,12,0);
        WHEN 5 THEN VRKEY := RPAD(TJLPR02CALPASSUPDLST.NUSHI_NAME,20,' ');
        WHEN 6 THEN VRKEY := SUBSTR(RPAD(TJLPR02CALPASSUPDLST.NUSHI_CHOMEI ||
                             TJLPR02CALPASSUPDLST.NUSHI_BANCHI             ||
                             TJLPR02CALPASSUPDLST.NUSHI_KATAGAKI,40,' '),1,40);
        WHEN 7 THEN VRKEY := LPAD(TJLPR02CALPASSUPDLST.SHO_NO,20,0);
        ELSE        VRKEY := '';
      END CASE;

      RETURN(VRKEY);
    END FUNCBREAKFLDVAL ;
--  2024/01/25 ZCZL.HAODAPENG UPDATE END
    ---------------------------------------------------------------------------
    --遡及賦課更正者リストワークへデータを更新する
    --引き数 INPUT  i_LISTHANTEIKBN  帳票判定区分
    --返る数 TRUE:正常 その他:エラー
    ---------------------------------------------------------------------------
    FUNCTION FUNCDATAUPDATE(i_LISTHANTEIKBN IN NUMBER)
    RETURN BOOLEAN IS
    BEGIN
        UPDATE ZLBW_02CALPASSUPD_LST SET
               TITEL                 = TJLPR02CALPASSUPDLST.TITEL,
               SHO_NO                = TJLPR02CALPASSUPDLST.SHO_NO,
               NUSHI_NAME            = TJLPR02CALPASSUPDLST.NUSHI_NAME,
               NUSHI_CHOMEI          = TJLPR02CALPASSUPDLST.NUSHI_CHOMEI,
               NUSHI_BANCHI          = TJLPR02CALPASSUPDLST.NUSHI_BANCHI,
               NUSHI_KATAGAKI        = TJLPR02CALPASSUPDLST.NUSHI_KATAGAKI,
               IDO_BI                = TJLPR02CALPASSUPDLST.IDO_BI,
               TOKUSOU_KBN           = TJLPR02CALPASSUPDLST.TOKUSOU_KBN,
               JIYU                  = TJLPR02CALPASSUPDLST.JIYU,
               HYOJI_JIYU            = TJLPR02CALPASSUPDLST.HYOJI_JIYU,
               TODOKE_BI             = TJLPR02CALPASSUPDLST.TODOKE_BI,
               SHIK_KBN              = TJLPR02CALPASSUPDLST.SHIK_KBN,
               HYOJI_SHIK_KBN        = TJLPR02CALPASSUPDLST.HYOJI_SHIK_KBN,
               SEINENGAPI            = TJLPR02CALPASSUPDLST.SEINENGAPI,
               FUKAGAKU_IRY_NEW      = TJLPR02CALPASSUPDLST.FUKAGAKU_IRY_NEW,
               FUKAGAKU_IRY_TAI_NEW  = TJLPR02CALPASSUPDLST.FUKAGAKU_IRY_TAI_NEW,
               FUKAGAKU_SIEN_NEW     = TJLPR02CALPASSUPDLST.FUKAGAKU_SIEN_NEW,
               FUKAGAKU_SIEN_TAI_NEW = TJLPR02CALPASSUPDLST.FUKAGAKU_SIEN_TAI_NEW,
               FUKAGAKU_KAI_NEW      = TJLPR02CALPASSUPDLST.FUKAGAKU_KAI_NEW,
               FUKAGAKU_KAI_TAI_NEW  = TJLPR02CALPASSUPDLST.FUKAGAKU_KAI_TAI_NEW,
               FUKAGAKU_IRY_OLD      = TJLPR02CALPASSUPDLST.FUKAGAKU_IRY_OLD,
               FUKAGAKU_IRY_TAI_OLD  = TJLPR02CALPASSUPDLST.FUKAGAKU_IRY_TAI_OLD,
               FUKAGAKU_SIEN_OLD     = TJLPR02CALPASSUPDLST.FUKAGAKU_SIEN_OLD,
               FUKAGAKU_SIEN_TAI_OLD = TJLPR02CALPASSUPDLST.FUKAGAKU_SIEN_TAI_OLD,
               FUKAGAKU_KAI_OLD      = TJLPR02CALPASSUPDLST.FUKAGAKU_KAI_OLD,
               FUKAGAKU_KAI_TAI_OLD  = TJLPR02CALPASSUPDLST.FUKAGAKU_KAI_TAI_OLD,
               SORT1                 = TJLPR02CALPASSUPDLST.SORT1,
               SORT2                 = TJLPR02CALPASSUPDLST.SORT2,
               SORT3                 = TJLPR02CALPASSUPDLST.SORT3,
               SORT4                 = TJLPR02CALPASSUPDLST.SORT4,
               SORT5                 = TJLPR02CALPASSUPDLST.SORT5,
               SORT6                 = TJLPR02CALPASSUPDLST.SORT6,
               SORT7                 = TJLPR02CALPASSUPDLST.SORT7,
               BREAK_KEY             = TJLPR02CALPASSUPDLST.BREAK_KEY
               --  2025/08/11 ZCZL.HAODAPENG add start 1.1.200.000:子ども子育て支援金対応
               ,FUKAGAKU_KDM_NEW      = TJLPR02CALPASSUPDLST.FUKAGAKU_KDM_NEW
               ,FUKAGAKU_KDM_OLD      = TJLPR02CALPASSUPDLST.FUKAGAKU_KDM_OLD
               --  2025/08/11 ZCZL.HAODAPENG add end
        WHERE LIST_HANTEI_KBN = i_LISTHANTEIKBN
        AND   KOKU_SETAI_NO   = NKOKUSETAINO
        AND   KOJIN_NO        = NKOJINNO
        AND   SANTEIDANTAI_CD = NSANTEIDANTAICD
        AND   CHOTEI_NENDO    = NCHOTEINENDO
        AND   NENDO_BUN       = NNENDOBUN
        AND   TSUCHI_NO       = NTSUCHINO;

        RETURN(TRUE);
    END FUNCDATAUPDATE;

    ---------------------------------------------------------------------------
    --編集処理 編集データを抽出する
    --引き数 INPUT  i_LISTHANTEIKBN  帳票判定区分
    --返る数 TRUE:正常 FALSE:エラー
    ---------------------------------------------------------------------------
    FUNCTION FUNCDATASYUTOKU(i_LISTHANTEIKBN IN NUMBER) RETURN BOOLEAN IS
    BEGIN
        IF i_LISTHANTEIKBN = 0 THEN
            --賦課基本(最新)テーブルへ積算税額データを抽出する
            BEGIN
                SELECT NVL(SEKISAN,0) INTO NJLTKIHONNSEKISAN
                FROM   ZLBTKIHON_N
                WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
                AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
                AND    CHOTEI_NENDO    = NCHOTEINENDO
                AND    NENDO_BUN       = NNENDOBUN
                AND    TSUCHI_NO       = NTSUCHINO;
            EXCEPTION
              WHEN OTHERS THEN
                NJLTKIHONNSEKISAN := 0;
            END;

            --賦課退職(最新)テーブルへ積算税額データを抽出する
            BEGIN
                SELECT NVL(SEKISAN,0) INTO NJLTTAINSEKISAN
                FROM   ZLBTTAI_N
                WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
                AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
                AND    CHOTEI_NENDO    = NCHOTEINENDO
                AND    NENDO_BUN       = NNENDOBUN
                AND    TSUCHI_NO       = NTSUCHINO;
            EXCEPTION
              WHEN OTHERS THEN
                NJLTTAINSEKISAN := 0;
            END;

            --賦課介護基本(最新)テーブルへ積算税額データを抽出する
            BEGIN
                SELECT NVL(SEKISAN,0) INTO NJLTKAIKIHONNSEKISAN
                FROM   ZLBTKAI_KIHON_N
                WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
                AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
                AND    CHOTEI_NENDO    = NCHOTEINENDO
                AND    NENDO_BUN       = NNENDOBUN
                AND    TSUCHI_NO       = NTSUCHINO;
            EXCEPTION
              WHEN OTHERS THEN
                NJLTKAIKIHONNSEKISAN := 0;
            END;

            --賦課介護退職(最新)テーブルへ積算税額データを抽出する
            BEGIN
                SELECT NVL(SEKISAN,0) INTO NJLTKAITAINSEKISAN
                FROM   ZLBTKAI_TAI_N
                WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
                AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
                AND    CHOTEI_NENDO    = NCHOTEINENDO
                AND    NENDO_BUN       = NNENDOBUN
                AND    TSUCHI_NO       = NTSUCHINO;
            EXCEPTION
              WHEN OTHERS THEN
                NJLTKAITAINSEKISAN := 0;
            END;

            --賦課支援基本(最新)テーブルへ積算税額データを抽出する
            BEGIN
                SELECT NVL(SEKISAN,0) INTO NJLTSIENKIHONNSEKISAN
                FROM   ZLBTSIEN_KIHON_N
                WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
                AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
                AND    CHOTEI_NENDO    = NCHOTEINENDO
                AND    NENDO_BUN       = NNENDOBUN
                AND    TSUCHI_NO       = NTSUCHINO;
            EXCEPTION
              WHEN OTHERS THEN
                NJLTSIENKIHONNSEKISAN := 0;
            END;
            --  2025/08/11 ZCZL.HAODAPENG ADD start 1.1.200.000:子ども子育て支援金対応
            --賦課子ども基本(最新)テーブルへ積算税額データを抽出する
            BEGIN
                SELECT NVL(SEKISAN,0) INTO NKODOMOSEKISANGAKU_SAISIN
                FROM   ZLBTKDM_KIHON_N
                WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
                AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
                AND    CHOTEI_NENDO    = NCHOTEINENDO
                AND    NENDO_BUN       = NNENDOBUN
                AND    TSUCHI_NO       = NTSUCHINO;
            EXCEPTION
              WHEN OTHERS THEN
                NKODOMOSEKISANGAKU_SAISIN := 0;
            END;
            --  2025/08/11 ZCZL.HAODAPENG ADD end

            --賦課支援退職(最新)テーブルへ積算税額データを抽出する
            BEGIN
                SELECT NVL(SEKISAN,0) INTO NJLTSIENTAINSEKISAN
                FROM   ZLBTSIEN_TAI_N
                WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
                AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
                AND    CHOTEI_NENDO    = NCHOTEINENDO
                AND    NENDO_BUN       = NNENDOBUN
                AND    TSUCHI_NO       = NTSUCHINO;
            EXCEPTION
              WHEN OTHERS THEN
                NJLTSIENTAINSEKISAN := 0;
            END;
        END IF;

        --中間基本テーブルへ積算税額データを抽出する
        BEGIN
            SELECT NVL(SEKISAN,0) INTO NJLTKIHONMIDSEKISAN
            FROM   ZLBTKIHON_MID
            WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
            AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
            AND    CHOTEI_NENDO    = NCHOTEINENDO
            AND    NENDO_BUN       = NNENDOBUN
            AND    TSUCHI_NO       = NTSUCHINO;
        EXCEPTION
          WHEN OTHERS THEN
            NJLTKIHONMIDSEKISAN := 0;
        END;

        --中間退職テーブルへ積算税額データを抽出する
        BEGIN
            SELECT NVL(SEKISAN,0) INTO NJLTTAIMIDSEKISAN
            FROM   ZLBTTAI_MID
            WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
            AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
            AND    CHOTEI_NENDO    = NCHOTEINENDO
            AND    NENDO_BUN       = NNENDOBUN
            AND    TSUCHI_NO       = NTSUCHINO;
        EXCEPTION
          WHEN OTHERS THEN
            NJLTTAIMIDSEKISAN := 0;
        END;

        --中間介護基本テーブルへ積算税額データを抽出する
        BEGIN
            SELECT NVL(SEKISAN,0) INTO NJLTKAIKIHONMIDSEKISAN
            FROM   ZLBTKAI_KIHON_MID
            WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
            AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
            AND    CHOTEI_NENDO    = NCHOTEINENDO
            AND    NENDO_BUN       = NNENDOBUN
            AND    TSUCHI_NO       = NTSUCHINO;
        EXCEPTION
          WHEN OTHERS THEN
            NJLTKAIKIHONMIDSEKISAN := 0;
        END;

        --中間介護退職テーブルへ積算税額データを抽出する
        BEGIN
            SELECT NVL(SEKISAN,0) INTO NJLTKAITAIMIDSEKISAN
            FROM   ZLBTKAI_TAI_MID
            WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
            AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
            AND    CHOTEI_NENDO    = NCHOTEINENDO
            AND    NENDO_BUN       = NNENDOBUN
            AND    TSUCHI_NO       = NTSUCHINO;
        EXCEPTION
          WHEN OTHERS THEN
            NJLTKAITAIMIDSEKISAN := 0;
        END;

        --賦課支援基本(中間)テーブルへ積算税額データを抽出する
        BEGIN
            SELECT NVL(SEKISAN,0) INTO NJLTSIENKIHONMIDSEKISAN
            FROM   ZLBTSIEN_KIHON_MID
            WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
            AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
            AND    CHOTEI_NENDO    = NCHOTEINENDO
            AND    NENDO_BUN       = NNENDOBUN
            AND    TSUCHI_NO       = NTSUCHINO;
        EXCEPTION
          WHEN OTHERS THEN
            NJLTSIENKIHONMIDSEKISAN := 0;
        END;
        --  2025/08/11 ZCZL.HAODAPENG ADD start 1.1.200.000:子ども子育て支援金対応
        --賦課子ども基本(中間)テーブルへ積算税額データを抽出する
        BEGIN
            SELECT NVL(SEKISAN,0) INTO NKODOMOSEKISANGAKU_CHOKAN
            FROM   ZLBTKDM_KIHON_MID
            WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
            AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
            AND    CHOTEI_NENDO    = NCHOTEINENDO
            AND    NENDO_BUN       = NNENDOBUN
            AND    TSUCHI_NO       = NTSUCHINO;
        EXCEPTION
          WHEN OTHERS THEN
            NKODOMOSEKISANGAKU_CHOKAN := 0;
        END;
        --  2025/08/11 ZCZL.HAODAPENG ADD end

        --賦課支援退職(最新)テーブルへ積算税額データを抽出する
        BEGIN
            SELECT NVL(SEKISAN,0) INTO NJLTSIENTAIMIDSEKISAN
            FROM   ZLBTSIEN_TAI_MID
            WHERE  KOKU_SETAI_NO   = NKOKUSETAINO
            AND    SANTEIDANTAI_CD = NSANTEIDANTAICD
            AND    CHOTEI_NENDO    = NCHOTEINENDO
            AND    NENDO_BUN       = NNENDOBUN
            AND    TSUCHI_NO       = NTSUCHINO;
        EXCEPTION
          WHEN OTHERS THEN
            NJLTSIENTAIMIDSEKISAN := 0;
        END;

        --資格基本テーブルへデータを抽出する
        BEGIN
            SELECT NVL(IDO_BI,0),
                   NVL(SOSHITSU_BI,0),
                   NVL(JIYU,0),
                   NVL(TODOKE_BI,0),
                   NVL(SHIK_KBN,0)
            INTO   NFFTSHIKAKUIDOBI,      --資格基本テーブルの異動日
                   NFFTSHIKAKUSOSHITSUBI, --資格基本テーブルの喪失年月日
                   NFFTSHIKAKUJIYU,       --資格基本テーブルの取得事由
                   NFFTSHIKAKUTODOKEBI,   --資格基本テーブルの届出日
                   NFFTSHIKAKUSHIKKBN     --資格基本テーブルの資格区分
            FROM   KHSTSHIKAKU
            WHERE  KOKU_SETAI_NO = NKOKUSETAINO
            AND    KOJIN_NO      = NKOJINNO
            AND    NEW_KBN       = 0
            AND    SAKUJO_KBN    = 0;
        EXCEPTION
          WHEN OTHERS THEN
            NFFTSHIKAKUIDOBI      := 0;
            NFFTSHIKAKUSOSHITSUBI := 0;
            NFFTSHIKAKUJIYU       := 0;
            NFFTSHIKAKUTODOKEBI   := 0;
            NFFTSHIKAKUSHIKKBN    := 0;
        END;

        RETURN(TRUE);
    END FUNCDATASYUTOKU;

    ---------------------------------------------------------------------------
    --編集処理 対象・対象外 データを編集する
    --引き数 INPUT  i_LISTHANTEIKBN  帳票判定区分
    --返る数 TRUE:正常 FALSE:エラー
    ---------------------------------------------------------------------------
    FUNCTION FUNCDATAHENSYU(i_LISTHANTEIKBN IN NUMBER) RETURN BOOLEAN IS
    BEGIN
        --帳票判定区分（0:賦課更正反映分、1:賦課更正対象外分）
        IF i_LISTHANTEIKBN = 0 THEN
            TJLPR02CALPASSUPDLST.TITEL := '計算対象';
        ELSE
            TJLPR02CALPASSUPDLST.TITEL := '計算対象外';
        END IF;

        --証番号 渡して返却された値をセット
        TJLPR02CALPASSUPDLST.SHO_NO := KHSFKGETSHONO(NSAKUSEIBI,0,NKOKUSETAINO);

        --宛名情報取得
        IMAIN_RETURN := GAAPK0030.FGETATENA2(NKOJINNO,
                                           'ZLB',
                                           NSAKUSEIBI,
                                           RATENA_REC,
                                           RSOFU_REC);

        --世帯主氏名漢字(GAAPK0030.FGETATENA2に宛名情報のSHIMEI_KANJIをセット)
        TJLPR02CALPASSUPDLST.NUSHI_NAME     := RATENA_REC.SHIMEI_KANJI;

        --世帯主町名(GAAPK0030.FGETATENA2に宛名情報のCHOMEIをセット)
        TJLPR02CALPASSUPDLST.NUSHI_CHOMEI   := RATENA_REC.CHOMEI;

        --世帯主番地(GAAPK0030.FGETATENA2に宛名情報のBANCHIをセット)
        TJLPR02CALPASSUPDLST.NUSHI_BANCHI   := RATENA_REC.BANCHI;

        --世帯主方書(GAAPK0030.FGETATENA2に宛名情報のKATAGAKIをセット)
        TJLPR02CALPASSUPDLST.NUSHI_KATAGAKI := RATENA_REC.KATAGAKI;

        --異動日(抽出(国保資格情報取得)で取得した異動日(KHSTSHIKAKU.IDO_BI)をセット)
        TJLPR02CALPASSUPDLST.IDO_BI         := NFFTSHIKAKUIDOBI;

        --喪失年月日(KHSTSHIKAKU.SOSHITSU_BI)が＞０の場合
        IF NFFTSHIKAKUSOSHITSUBI > 0 THEN
            --得喪区分が固定文字'喪失'をセット
            TJLPR02CALPASSUPDLST.TOKUSOU_KBN := '喪失';
        ELSE
            --得喪区分が固定文字'取得'をセット
            TJLPR02CALPASSUPDLST.TOKUSOU_KBN := '取得';
        END IF;

        --事由(抽出(国保資格情報取得)で取得した事由(KHSTSHIKAKU.JIYU)をセット)
        TJLPR02CALPASSUPDLST.JIYU            := NFFTSHIKAKUJIYU;

        --表示用事由(KHSPK00100.FCODENAMEに返却された値をセット)
        TJLPR02CALPASSUPDLST.HYOJI_JIYU      := KHSPK00100.FCODENAME(7,
                                                                        NFFTSHIKAKUJIYU,
                                                                        2);

        --届出日(抽出(国保資格情報取得)で取得した届出日(KHSTSHIKAKU.TODOKE_BI)をセット)
        TJLPR02CALPASSUPDLST.TODOKE_BI       := NFFTSHIKAKUTODOKEBI;

        --資格区分(抽出(国保資格情報取得)で取得した資格区分(KHSTSHIKAKU.資格区分)をセット)
        TJLPR02CALPASSUPDLST.SHIK_KBN        := NFFTSHIKAKUSHIKKBN;

        --表示用資格区分(KHSPK00100.FCODENAMEに返却された値をセット)
        TJLPR02CALPASSUPDLST.HYOJI_SHIK_KBN  := KHSPK00100.FCODENAME(5,
                                                                        NFFTSHIKAKUSHIKKBN,
                                                                        2);

        --生年月日(GAAPK0030.FGETATENA2に宛名情報のSEINENGAPIをセット)
        TJLPR02CALPASSUPDLST.SEINENGAPI      := RATENA_REC.SEINENGAPI;

        --新_賦課額（医療）
        IF i_LISTHANTEIKBN = 0 THEN
            --新_医療情報表で取得した積算税額をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_IRY_NEW := NJLTKIHONMIDSEKISAN;
        ELSE
            --固定値 0をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_IRY_NEW := 0;
        END IF;

        --新_賦課額（医療退職）
        IF i_LISTHANTEIKBN = 0 THEN
            --新_医療退職情報表で取得した積算税額をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_IRY_TAI_NEW := NJLTTAIMIDSEKISAN;
        ELSE
            --固定値 0をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_IRY_TAI_NEW := 0;
        END IF;

        --新_賦課額（支援）
        IF i_LISTHANTEIKBN = 0 THEN
            --新_支援情報表で取得した積算税額をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_SIEN_NEW := NJLTSIENKIHONMIDSEKISAN;
        ELSE
            --固定値 0をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_SIEN_NEW := 0;
        END IF;
        --  2025/08/11 ZCZL.HAODAPENG add start 1.1.200.000:子ども子育て支援金対応
        IF i_LISTHANTEIKBN = 0 THEN
            --新_賦課額（子ども）= 変数.賦課子ども基本(中間)テーブルの積算税額
            TJLPR02CALPASSUPDLST.FUKAGAKU_KDM_NEW := NKODOMOSEKISANGAKU_CHOKAN;
        ELSE
            --固定値 0をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_KDM_NEW := 0;
        END IF;
        --  2025/08/11 ZCZL.HAODAPENG add end

        --新_賦課額（支援退職）
        IF i_LISTHANTEIKBN = 0 THEN
            --新_支援退職情報表で取得した積算税額をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_SIEN_TAI_NEW := NJLTSIENTAIMIDSEKISAN;
        ELSE
            --固定値 0をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_SIEN_TAI_NEW := 0;
        END IF;

        --新_賦課額（介護）
        IF i_LISTHANTEIKBN = 0 THEN
            --新_介護情報表で取得した積算税額をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_KAI_NEW := NJLTKAIKIHONMIDSEKISAN;
        ELSE
            --固定値 0をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_KAI_NEW := 0;
        END IF;

        --新_賦課額（介護退職）
        IF i_LISTHANTEIKBN = 0 THEN
            --新_介護退職情報表で取得した積算税額をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_KAI_TAI_NEW := NJLTKAITAIMIDSEKISAN;
        ELSE
            --固定値 0をセット
            TJLPR02CALPASSUPDLST.FUKAGAKU_KAI_TAI_NEW := 0;
        END IF;

        --旧_賦課額（医療）
        --旧_医療情報情報表で取得した積算税額をセット
        TJLPR02CALPASSUPDLST.FUKAGAKU_IRY_OLD      := NJLTKIHONNSEKISAN;

        --旧_賦課額（医療退職）
        --旧_医療退職情報表で取得した積算税額をセット
        TJLPR02CALPASSUPDLST.FUKAGAKU_IRY_TAI_OLD  := NJLTTAINSEKISAN;

        --旧_賦課額（支援）
        --旧_支援情報表で取得した積算税額をセット
        TJLPR02CALPASSUPDLST.FUKAGAKU_SIEN_OLD     := NJLTSIENKIHONNSEKISAN;

        --旧_賦課額（支援退職）
        --旧_支援退職情報表で取得した積算税額をセット
        TJLPR02CALPASSUPDLST.FUKAGAKU_SIEN_TAI_OLD := NJLTSIENTAINSEKISAN;

        --旧_賦課額（介護）
        --旧_介護情報表で取得した積算税額をセット
        TJLPR02CALPASSUPDLST.FUKAGAKU_KAI_OLD      := NJLTKAIKIHONNSEKISAN;

        --  2025/08/11 ZCZL.HAODAPENG add start 1.1.200.000:子ども子育て支援金対応
        --旧_賦課額（子ども）
        --旧_賦課額（子ども） = 変数.賦課子ども基本(最新)テーブルの積算税額
        TJLPR02CALPASSUPDLST.FUKAGAKU_KDM_OLD := NKODOMOSEKISANGAKU_SAISIN;
        --  2025/08/11 ZCZL.HAODAPENG add end

        --旧_賦課額（介護退職）
        --旧_介護退職情報表で取得した積算税額をセット
        TJLPR02CALPASSUPDLST.FUKAGAKU_KAI_TAI_OLD  := NJLTKAITAINSEKISAN;

        --  2024/01/25 ZCZL.HAODAPENG UPDATE START 0.2.000.001:512_KHS_0028の横展開
        /*
        --ソート１
        TJLPR02CALPASSUPDLST.SORT1 := NULL;

        --ソート２
        TJLPR02CALPASSUPDLST.SORT2 := NULL;

        --ソート３
        TJLPR02CALPASSUPDLST.SORT3 := NULL;

        --ソート４
        TJLPR02CALPASSUPDLST.SORT4 := NULL;

        --ソート５
        TJLPR02CALPASSUPDLST.SORT5 := NULL;

        --ソート６
        TJLPR02CALPASSUPDLST.SORT6 := NULL;

        --ソート７
        TJLPR02CALPASSUPDLST.SORT7 := NULL;

        --改ページ
        TJLPR02CALPASSUPDLST.BREAK_KEY := NULL;
        */
        --ソート１
        TJLPR02CALPASSUPDLST.SORT1 := FUNCGETSOTO(ISORT_SORT01,i_LISTHANTEIKBN);

        --ソート２
        TJLPR02CALPASSUPDLST.SORT2 := FUNCGETSOTO(ISORT_SORT02,i_LISTHANTEIKBN);

        --ソート３
        TJLPR02CALPASSUPDLST.SORT3 := FUNCGETSOTO(ISORT_SORT03,i_LISTHANTEIKBN);

        --ソート４
        TJLPR02CALPASSUPDLST.SORT4 := FUNCGETSOTO(ISORT_SORT04,i_LISTHANTEIKBN);

        --ソート５
        TJLPR02CALPASSUPDLST.SORT5 := FUNCGETSOTO(ISORT_SORT05,i_LISTHANTEIKBN);

        --ソート６
        TJLPR02CALPASSUPDLST.SORT6 := FUNCGETSOTO(ISORT_SORT06,i_LISTHANTEIKBN);

        --ソート７
        TJLPR02CALPASSUPDLST.SORT7 := FUNCGETSOTO(ISORT_SORT07,i_LISTHANTEIKBN);

        --改ページ
        TJLPR02CALPASSUPDLST.BREAK_KEY := FUNCBREAKFLDVAL(ISORT_BREAK);
        --  2024/01/25 ZCZL.HAODAPENG UPDATE END

        RETURN(TRUE);
    END FUNCDATAHENSYU;

    ---------------------------------------------------------------------------
    --編集処理 対象・対象外条件データ抽出処理
    --引き数 INPUT  i_LISTHANTEIKBN  帳票判定区分
    --返る数 TRUE:正常 FALSE:エラー
    ---------------------------------------------------------------------------
    FUNCTION FUNCDATAJYOUKEN(i_LISTHANTEIKBN IN NUMBER) RETURN BOOLEAN IS
     ISORT_SRENBAN NUMBER   := 0;   -- 帳票連番
     ISORT_SRENBAN_0 NUMBER := 2;   -- 計算対象用帳票連番
     ISORT_SRENBAN_1 NUMBER := 3;   -- 計算対象外用帳票連番
     ISORT_SRENBAN_B0 NUMBER := 52;   --計算対象用帳票連番(夜間バッチ)
     ISORT_SRENBAN_B1 NUMBER := 53;   --計算対象外用帳票連番(夜間バッチ)

    BEGIN
        BEGIN
      -- 計算対象／対象外毎に帳票連番を設定
            IF i_LISTHANTEIKBN = 0 THEN
                IF i_IBATCH_KBN = c_O_BAT THEN
                   ISORT_SRENBAN := ISORT_SRENBAN_0;
                ELSE
                   ISORT_SRENBAN := ISORT_SRENBAN_B0;
                END IF;
      ELSE
                IF i_IBATCH_KBN = c_O_BAT THEN
                   ISORT_SRENBAN := ISORT_SRENBAN_1;
                ELSE
                   ISORT_SRENBAN := ISORT_SRENBAN_B1;
                END IF;
      END IF;

            --  2024/01/25 ZCZL.HAODAPENG UPDATE START 0.2.000.001:512_KHS_0028の横展開
            -- 計算対象／対象外毎にソート条件設定
            IF FUNCAHPFSORT(ISORT_SRENBAN) = FALSE THEN
                RETURN(FALSE);
            END IF;
            --  2024/01/25 ZCZL.HAODAPENG UPDATE END

            IMAIN_DATACOUNT := 0;

            --帳票基本データ（個人）から新規賦課されたデータを抽出する。
            FOR CRJLPR02CALPASSUPDLST IN CJLPR02CALPASSUPDLST(i_LISTHANTEIKBN) LOOP
                --作成日
                NSAKUSEIBI       := CRJLPR02CALPASSUPDLST.SAKUSEI_BI;
                --国保世帯番号
                NKOKUSETAINO     := CRJLPR02CALPASSUPDLST.KOKU_SETAI_NO;
                --個人番号
                NKOJINNO         := CRJLPR02CALPASSUPDLST.KOJIN_NO;
                --算定団体コード
                NSANTEIDANTAICD  := CRJLPR02CALPASSUPDLST.SANTEIDANTAI_CD;
                --調定年度
                NCHOTEINENDO     := CRJLPR02CALPASSUPDLST.CHOTEI_NENDO;
                --年度分
                NNENDOBUN        := CRJLPR02CALPASSUPDLST.NENDO_BUN;
                --通知書番号
                NTSUCHINO        := CRJLPR02CALPASSUPDLST.TSUCHI_NO;

                --編集データを抽出する
                BMAIN_RETURN     := FUNCDATASYUTOKU(i_LISTHANTEIKBN);

                --データを編集する
                BMAIN_RETURN     := FUNCDATAHENSYU(i_LISTHANTEIKBN);

                --データを更新する
                BMAIN_RETURN     := FUNCDATAUPDATE(i_LISTHANTEIKBN);

                --データの件数
                IMAIN_DATACOUNT := IMAIN_DATACOUNT + 1;
            END LOOP;

            RETURN(TRUE);
        EXCEPTION
        WHEN OTHERS THEN
            RETURN(FALSE);
        END;
    END FUNCDATAJYOUKEN;

    ---------------------------------------------------------------------------
    --編集処理 対象・対象外条件データ抽出処理
    --返る数 TRUE:正常 FALSE:エラー
    ---------------------------------------------------------------------------
    FUNCTION FUNCCSV RETURN BOOLEAN IS

      TYPE ref_CUR_DOUTAI IS REF CURSOR;
      C1              ref_CUR_DOUTAI;
      C2              ref_CUR_DOUTAI;
      v_DOUTAISQL     NVARCHAR2(10000);
      v_DOUTAISQL2    NVARCHAR2(10000);
      CR1             ZLBW_02CALPASSUPD_LST%ROWTYPE;
      CR2             ZLBW_02CALPASSUPD_LST%ROWTYPE;
      r_WKRECORD001   ZLBWL131R001%ROWTYPE;
      r_WKRECORD002   ZLBWL131R002%ROWTYPE;
      nROWNO          NUMBER;
      nROWNO2         NUMBER;

      BRETURN BOOLEAN := TRUE;
    BEGIN
        --  2024/02/03 ZCZL.HAODAPENG DEL START 0.2.000.003:512_ZLB_0035対応_2回目
        --取得した出力先をVCSVPATHへセットする
        --IF i_IBATCH_KBN = c_O_BAT THEN        --オンラインバッチのとき
        --   VCSVPATH := O_VCSVDIR_DB;          --オンラインバッチ用DIRをセット
        --ELSE
        --   VCSVPATH := O_VY_CSVDIR_DB;        --夜間バッチ用DIRをセット
        --END IF;


        --CASE i_CHOHYOID
        --  WHEN 'ZLB131R001' THEN
        --  2024/02/03 ZCZL.HAODAPENG DEL END
            -------------------------------------------------------------
            -- 遡及賦課更正リスト（賦課更正反映分）CSVファイルを作成する
            -------------------------------------------------------------
            v_DOUTAISQL := 'SELECT * FROM ZLBW_02CALPASSUPD_LST WHERE LIST_HANTEI_KBN = 0';
            IF KKAPK0010.FTrim(i_ORDERBYCLAUSE) IS NOT NULL THEN
                v_DOUTAISQL := v_DOUTAISQL || ' ORDER BY ' || i_ORDERBYCLAUSE;
            END IF;
            nROWNO := 0;
            OPEN C1 FOR v_DOUTAISQL;
            LOOP
            FETCH C1 INTO CR1;
            EXIT WHEN C1%NOTFOUND;
                nROWNO := nROWNO+1;
                r_WKRECORD001 := NULL;
                r_WKRECORD001.NO:=nROWNO;--ソート順

                r_WKRECORD001.LIST_HANTEI_KBN:=NVL(CR1.LIST_HANTEI_KBN,0);--帳票判定区分
                r_WKRECORD001.TITEL:=CR1.TITEL;--タイトル
                r_WKRECORD001.KOKU_SETAI_NO:=NVL(CR1.KOKU_SETAI_NO,0);--国保世帯番号
                r_WKRECORD001.KOJIN_NO:=NVL(CR1.KOJIN_NO,0);--個人番号
                r_WKRECORD001.SANTEIDANTAI_CD:=NVL(CR1.SANTEIDANTAI_CD,0);--算定団体コード
                r_WKRECORD001.CHOTEI_NENDO:=NVL(CR1.CHOTEI_NENDO,0);--調定年度
                r_WKRECORD001.NENDO_BUN:=NVL(CR1.NENDO_BUN,0);--年度分
                r_WKRECORD001.TSUCHI_NO:=NVL(CR1.TSUCHI_NO,0);--通知書番号
                r_WKRECORD001.FUKAKIJITU:=NVL(CR1.FUKAKIJITU,0);--賦課期日
                r_WKRECORD001.NOKIGEN:=NVL(CR1.NOKIGEN,0);--納期限
                r_WKRECORD001.HAPPU_BI:=NVL(CR1.HAPPU_BI,0);--通知書発布日
                r_WKRECORD001.SAKUSEI_BI:=NVL(CR1.SAKUSEI_BI,0);--作成日
                r_WKRECORD001.SHO_NO:=CR1.SHO_NO;--証番号
                r_WKRECORD001.NUSHI_NAME:=CR1.NUSHI_NAME;--世帯主氏名漢字
                r_WKRECORD001.NUSHI_CHOMEI:=CR1.NUSHI_CHOMEI;--世帯主町名
                r_WKRECORD001.NUSHI_BANCHI:=CR1.NUSHI_BANCHI;--世帯主番地
                r_WKRECORD001.NUSHI_KATAGAKI:=CR1.NUSHI_KATAGAKI;--世帯主方書
                r_WKRECORD001.IDO_BI:=NVL(CR1.IDO_BI,0);--異動日
                r_WKRECORD001.TOKUSOU_KBN:=CR1.TOKUSOU_KBN;--得喪区分
                r_WKRECORD001.JIYU:=NVL(CR1.JIYU,0);--事由
                r_WKRECORD001.HYOJI_JIYU:=CR1.HYOJI_JIYU;--表示用事由
                r_WKRECORD001.TODOKE_BI:=NVL(CR1.TODOKE_BI,0);--届出日
                r_WKRECORD001.SHIK_KBN:=NVL(CR1.SHIK_KBN,0);--資格区分
                r_WKRECORD001.HYOJI_SHIK_KBN:=CR1.HYOJI_SHIK_KBN;--表示用資格区分
                r_WKRECORD001.SEINENGAPI:=NVL(CR1.SEINENGAPI,0);--生年月日
                r_WKRECORD001.FUKAGAKU_IRY_NEW:=NVL(CR1.FUKAGAKU_IRY_NEW,0);--新賦課額医療
                r_WKRECORD001.FUKAGAKU_IRY_TAI_NEW:=NVL(CR1.FUKAGAKU_IRY_TAI_NEW,0);--新賦課額医療退職
                r_WKRECORD001.FUKAGAKU_SIEN_NEW:=NVL(CR1.FUKAGAKU_SIEN_NEW,0);--新賦課額支援
                r_WKRECORD001.FUKAGAKU_SIEN_TAI_NEW:=NVL(CR1.FUKAGAKU_SIEN_TAI_NEW,0);--新賦課額支援退職
                r_WKRECORD001.FUKAGAKU_KAI_NEW:=NVL(CR1.FUKAGAKU_KAI_NEW,0);--新賦課額介護
                r_WKRECORD001.FUKAGAKU_KAI_TAI_NEW:=NVL(CR1.FUKAGAKU_KAI_TAI_NEW,0);--新賦課額介護退職
                r_WKRECORD001.FUKAGAKU_IRY_OLD:=NVL(CR1.FUKAGAKU_IRY_OLD,0);--旧賦課額医療
                r_WKRECORD001.FUKAGAKU_IRY_TAI_OLD:=NVL(CR1.FUKAGAKU_IRY_TAI_OLD,0);--旧賦課額医療退職
                r_WKRECORD001.FUKAGAKU_SIEN_OLD:=NVL(CR1.FUKAGAKU_SIEN_OLD,0);--旧賦課額支援
                r_WKRECORD001.FUKAGAKU_SIEN_TAI_OLD:=NVL(CR1.FUKAGAKU_SIEN_TAI_OLD,0);--旧賦課額支援退職
                r_WKRECORD001.FUKAGAKU_KAI_OLD:=NVL(CR1.FUKAGAKU_KAI_OLD,0);--旧賦課額介護
                r_WKRECORD001.FUKAGAKU_KAI_TAI_OLD:=NVL(CR1.FUKAGAKU_KAI_TAI_OLD,0);--旧賦課額介護退職
                r_WKRECORD001.SORT1:=CR1.SORT1;--ソート１
                r_WKRECORD001.SORT2:=CR1.SORT2;--ソート２
                r_WKRECORD001.SORT3:=CR1.SORT3;--ソート３
                r_WKRECORD001.SORT4:=CR1.SORT4;--ソート４
                r_WKRECORD001.SORT5:=CR1.SORT5;--ソート５
                r_WKRECORD001.SORT6:=CR1.SORT6;--ソート６
                r_WKRECORD001.SORT7:=CR1.SORT7;--ソート７
                r_WKRECORD001.SORT8:=CR1.SORT8;--ソート８
                r_WKRECORD001.SORT9:=CR1.SORT9;--ソート９
                r_WKRECORD001.SORT10:=CR1.SORT10;--ソート１０
                r_WKRECORD001.BREAK_KEY:=CR1.BREAK_KEY;--改ページキー
                r_WKRECORD001.BREAK_NO:=CR1.BREAK_KEY;--改ページキー
                r_WKRECORD001.WSNUM:=i_VTANMATSU_NO;--端末番号
                r_WKRECORD001.BATCHKBN:=i_IBATCH_KBN;--即時バッチ区分
                r_WKRECORD001.JOBNUM:=i_JOBNUM;--ジョブNO
                --  2025/08/11 ZCZL.HAODAPENG add start 1.1.200.000:子ども子育て支援金対応
                r_WKRECORD001.FUKAGAKU_KDM_NEW := NVL(CR1.FUKAGAKU_KDM_NEW, 0);         --新賦課額子ども
                r_WKRECORD001.FUKAGAKU_KDM_OLD := NVL(CR1.FUKAGAKU_KDM_OLD, 0);         --旧賦課額子ども
                --  2025/08/11 ZCZL.HAODAPENG add end
                INSERT INTO ZLBWL131R001 VALUES r_WKRECORD001;
            END LOOP;
            IF C1%ISOPEN THEN
                CLOSE C1;
            END IF;

            --計算対象のデータ抽出時、エラーがありません
            IF IMAIN_RETURN = 0 THEN
                SELECT COUNT(*) INTO IMAIN_DATACOUNT
                FROM   ZLBW_02CALPASSUPD_LST
                WHERE  LIST_HANTEI_KBN = 0;

                --計算対象のデータ抽出後で、ログを出力します
                PROCWRITELOG(3);
            ELSE
                BRETURN := FALSE;
            END IF;
          --  2024/02/03 ZCZL.HAODAPENG DEL START 0.2.000.003:512_ZLB_0035対応_2回目
          --WHEN 'ZLB131R002' THEN
          --  2024/02/03 ZCZL.HAODAPENG DEL END
            ---------------------------------------------------------------
            -- 遡及賦課更正リスト（賦課更正対象外分）CSVファイルを作成する
            ---------------------------------------------------------------
            v_DOUTAISQL2 := 'SELECT * FROM ZLBW_02CALPASSUPD_LST WHERE LIST_HANTEI_KBN = 1';
            IF KKAPK0010.FTrim(i_ORDERBYCLAUSE) IS NOT NULL THEN
                v_DOUTAISQL2 := v_DOUTAISQL2 || ' ORDER BY ' || i_ORDERBYCLAUSE;
            END IF;
            nROWNO := 0;
            OPEN C2 FOR v_DOUTAISQL2;
            LOOP
            FETCH C2 INTO CR2;
            --  2024/02/01 ZCZL.ZHANGLEI Update 0.2.000.001:512_ZLB_0035
            --EXIT WHEN C1%NOTFOUND;
            EXIT WHEN C2%NOTFOUND;
              nROWNO2 := nROWNO2+1;
              r_WKRECORD002 := NULL;
              r_WKRECORD002.NO:=nROWNO2;--ソート順
              r_WKRECORD002.LIST_HANTEI_KBN:=NVL(CR2.LIST_HANTEI_KBN,0);--帳票判定区分
              r_WKRECORD002.TITEL:=CR2.TITEL;--タイトル
              r_WKRECORD002.KOKU_SETAI_NO:=NVL(CR2.KOKU_SETAI_NO,0);--国保世帯番号
              r_WKRECORD002.KOJIN_NO:=NVL(CR2.KOJIN_NO,0);--個人番号
              r_WKRECORD002.SANTEIDANTAI_CD:=NVL(CR2.SANTEIDANTAI_CD,0);--算定団体コード
              r_WKRECORD002.CHOTEI_NENDO:=NVL(CR2.CHOTEI_NENDO,0);--調定年度
              r_WKRECORD002.NENDO_BUN:=NVL(CR2.NENDO_BUN,0);--年度分
              r_WKRECORD002.TSUCHI_NO:=NVL(CR2.TSUCHI_NO,0);--通知書番号
              r_WKRECORD002.FUKAKIJITU:=NVL(CR2.FUKAKIJITU,0);--賦課期日
              r_WKRECORD002.NOKIGEN:=NVL(CR2.NOKIGEN,0);--納期限
              r_WKRECORD002.HAPPU_BI:=NVL(CR2.HAPPU_BI,0);--通知書発布日
              r_WKRECORD002.SAKUSEI_BI:=NVL(CR2.SAKUSEI_BI,0);--作成日
              r_WKRECORD002.SHO_NO:=CR2.SHO_NO;--証番号
              r_WKRECORD002.NUSHI_NAME:=CR2.NUSHI_NAME;--世帯主氏名漢字
              r_WKRECORD002.NUSHI_CHOMEI:=CR2.NUSHI_CHOMEI;--世帯主町名
              r_WKRECORD002.NUSHI_BANCHI:=CR2.NUSHI_BANCHI;--世帯主番地
              r_WKRECORD002.NUSHI_KATAGAKI:=CR2.NUSHI_KATAGAKI;--世帯主方書
              r_WKRECORD002.IDO_BI:=NVL(CR2.IDO_BI,0);--異動日
              r_WKRECORD002.TOKUSOU_KBN:=CR2.TOKUSOU_KBN;--得喪区分
              r_WKRECORD002.JIYU:=NVL(CR2.JIYU,0);--事由
              r_WKRECORD002.HYOJI_JIYU:=CR2.HYOJI_JIYU;--表示用事由
              r_WKRECORD002.TODOKE_BI:=NVL(CR2.TODOKE_BI,0);--届出日
              r_WKRECORD002.SHIK_KBN:=NVL(CR2.SHIK_KBN,0);--資格区分
              r_WKRECORD002.HYOJI_SHIK_KBN:=CR2.HYOJI_SHIK_KBN;--表示用資格区分
              r_WKRECORD002.SEINENGAPI:=NVL(CR2.SEINENGAPI,0);--生年月日
              r_WKRECORD002.FUKAGAKU_IRY_NEW:=NVL(CR2.FUKAGAKU_IRY_NEW,0);--新賦課額医療
              r_WKRECORD002.FUKAGAKU_IRY_TAI_NEW:=NVL(CR2.FUKAGAKU_IRY_TAI_NEW,0);--新賦課額医療退職
              r_WKRECORD002.FUKAGAKU_SIEN_NEW:=NVL(CR2.FUKAGAKU_SIEN_NEW,0);--新賦課額支援
              r_WKRECORD002.FUKAGAKU_SIEN_TAI_NEW:=NVL(CR2.FUKAGAKU_SIEN_TAI_NEW,0);--新賦課額支援退職
              r_WKRECORD002.FUKAGAKU_KAI_NEW:=NVL(CR2.FUKAGAKU_KAI_NEW,0);--新賦課額介護
              r_WKRECORD002.FUKAGAKU_KAI_TAI_NEW:=NVL(CR2.FUKAGAKU_KAI_TAI_NEW,0);--新賦課額介護退職
              r_WKRECORD002.FUKAGAKU_IRY_OLD:=NVL(CR2.FUKAGAKU_IRY_OLD,0);--旧賦課額医療
              r_WKRECORD002.FUKAGAKU_IRY_TAI_OLD:=NVL(CR2.FUKAGAKU_IRY_TAI_OLD,0);--旧賦課額医療退職
              r_WKRECORD002.FUKAGAKU_SIEN_OLD:=NVL(CR2.FUKAGAKU_SIEN_OLD,0);--旧賦課額支援
              r_WKRECORD002.FUKAGAKU_SIEN_TAI_OLD:=NVL(CR2.FUKAGAKU_SIEN_TAI_OLD,0);--旧賦課額支援退職
              r_WKRECORD002.FUKAGAKU_KAI_OLD:=NVL(CR2.FUKAGAKU_KAI_OLD,0);--旧賦課額介護
              r_WKRECORD002.FUKAGAKU_KAI_TAI_OLD:=NVL(CR2.FUKAGAKU_KAI_TAI_OLD,0);--旧賦課額介護退職
              r_WKRECORD002.SORT1:=CR2.SORT1;--ソート１
              r_WKRECORD002.SORT2:=CR2.SORT2;--ソート２
              r_WKRECORD002.SORT3:=CR2.SORT3;--ソート３
              r_WKRECORD002.SORT4:=CR2.SORT4;--ソート４
              r_WKRECORD002.SORT5:=CR2.SORT5;--ソート５
              r_WKRECORD002.SORT6:=CR2.SORT6;--ソート６
              r_WKRECORD002.SORT7:=CR2.SORT7;--ソート７
              r_WKRECORD002.SORT8:=CR2.SORT8;--ソート８
              r_WKRECORD002.SORT9:=CR2.SORT9;--ソート９
              r_WKRECORD002.SORT10:=CR2.SORT10;--ソート１０
              r_WKRECORD002.BREAK_KEY:=CR2.BREAK_KEY;--改ページキー
              r_WKRECORD002.BREAK_NO:=CR2.BREAK_KEY;--改ページキー
              r_WKRECORD002.WSNUM:=i_VTANMATSU_NO;--端末番号
              r_WKRECORD002.BATCHKBN:=i_IBATCH_KBN;--即時バッチ区分
              r_WKRECORD002.JOBNUM:=i_JOBNUM;--ジョブNO
              INSERT INTO ZLBWL131R002 VALUES r_WKRECORD002;
            END LOOP;
            IF C2%ISOPEN THEN
                CLOSE C2;
            END IF;

            --計算対象外のデータ抽出時、エラーがありません
            IF IMAIN_RETURN = 0 THEN
                SELECT COUNT(*) INTO IMAIN_DATACOUNT
                FROM   ZLBW_02CALPASSUPD_LST
                WHERE  LIST_HANTEI_KBN = 1;

                --計算対象外のデータ抽出後で、ログを出力します
                PROCWRITELOG(3);
            ELSE
                BRETURN := FALSE;
            END IF;
        --  2024/02/03 ZCZL.HAODAPENG DEL START 0.2.000.003:512_ZLB_0035対応_2回目
        --  ELSE
        --    NULL;
        --END CASE;
        --  2024/02/03 ZCZL.HAODAPENG DEL END

        RETURN(BRETURN);
    END FUNCCSV;
-------------------------------------------------------------------------------
--  メイン処理
-------------------------------------------------------------------------------
BEGIN
    BEGIN
    ---------------------------------------------------------------------------
    --STEP１　初期化する
    ---------------------------------------------------------------------------
    --  2024/01/29 ZCZL.ZHANGLEI Update Start 0.2.000.002:512_ZLB_0035
    --変数を初期化するが正常の場合
    IF  NOT FUNCINTSET  THEN
        --初期設定が異常の場合
        IMAIN_LOGRETURN1 := 1;
    END IF;
    --  2024/01/29 ZCZL.ZHANGLEI Update Start 0.2.000.002:512_ZLB_0035
    --初期処理は正常の場合、ログを出力します
    IF IMAIN_LOGRETURN1 = 0 THEN
        PROCWRITELOG(1);
    END IF;

    ---------------------------------------------------------------------------
    --STEP２　データ抽出・更新処理
    ---------------------------------------------------------------------------
    --計算対象のデータ抽出・更新処理
    IF FUNCDATAJYOUKEN(0) = FALSE THEN
        --計算対象のデータ抽出・更新処理時、エラーがあります
        IMAIN_LOGRETURN2 := 1;
    END IF;

    --計算対象のデータ抽出時、エラーがありません
    IF IMAIN_LOGRETURN2 = 0 THEN
        --計算対象のデータ抽出後で、ログを出力します
        PROCWRITELOG(2);
    END IF;

    --計算対象外のデータ抽出・更新処理
    IF FUNCDATAJYOUKEN(1) = FALSE THEN
        --計算対象外のデータ抽出・更新処理時、エラーがあります
        IMAIN_LOGRETURN3 := 1;
    END IF;

    --計算対象外のデータ抽出時、エラーがありません
    IF IMAIN_LOGRETURN3 = 0 THEN
        --計算対象外のデータ抽出後で、ログを出力します
        PROCWRITELOG(2);
    END IF;

    ---------------------------------------------------------------------------
    --STEP３　CSVファイルを出力します
    ---------------------------------------------------------------------------
    --CSVファイルを出力します
    IF FUNCCSV = FALSE THEN
        --CSVファイルを出力する時、エラーがあります
        IMAIN_LOGRETURN4 := 1;
    END IF;
    ---------------------------------------------------------------------------
    --STEP４　終了処理
    ---------------------------------------------------------------------------
    IF IMAIN_LOGRETURN1 = 0 AND
       IMAIN_LOGRETURN2 = 0 AND
       IMAIN_LOGRETURN3 = 0 AND
       IMAIN_LOGRETURN4 = 0 THEN
        --メイン処理の正常終了時、ログを出力します
        PROCWRITELOG(4);
    ELSE
        --メイン処理の異常終了時、ログを出力します
        PROCWRITELOG(5);
    END IF;

    o_NRTN := 0;

    EXCEPTION
        WHEN OTHERS THEN
        ROLLBACK;
        --メイン処理の異常終了時、ログを出力します
        PROCWRITELOG(5);
        o_NRTN := 1;
    END;
END;
/
