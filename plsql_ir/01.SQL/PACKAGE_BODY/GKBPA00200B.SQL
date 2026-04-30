CREATE OR REPLACE PACKAGE BODY GKBPA00200
--1.0.000.000-02.02-02.02
------------------------------------------------------------------------
--  サブシステム名  : GKB（教育）
--  プログラム名   : 成人式案内作成
--  機能概要    : 「成人式案内通知」処理を改修し、成人式案内状を標準仕様に合わせる。
--             「成人式対象者照会」画面を新規作成し、即時で成人式案内状を出力する機能を持たせる。
--  バージョン     : Ver 0.3.000.000
--  作成者／作成日: ZCZL.xiaoya 2024/06/03
------------------------------------------------------------------------
--  変更履歴
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.001:IT_GKB_00433対応
--  2024/11/15 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00539横展開対応
--  2024/11/15 JPJYS.WENGSILIANG UPDATE 0.3.000.003:IT_GKB_00543仕様変更対応
--  2024/11/22 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00605:仕様変更対応
--  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応
--  2024/12/20 JPJYS.SHAXUE UPDATE 0.3.000.006:品質強化IT_GKB_10104,IT_GKB_10105:故障対応
------------------------------------------------------------------------
IS
    -- 全処理必須パラメータ
    c_ONLINE                      CONSTANT PLS_INTEGER := 1;   --オンライン
    c_OK                          CONSTANT PLS_INTEGER := 0;   --正常
    c_ERR                         CONSTANT PLS_INTEGER := -1;  --異常
    g_nJOBNUM                     NUMBER;                      --ジョブナンバー
    g_sTANTOCODE                  CHAR(12);                    --担当者コード
    g_sWSNUM                      NVARCHAR2(63);               --端末番号
    g_sBUNSHONUMLIST              NVARCHAR2(1000);             --文書番号情報（リスト）
    g_sMESSAGE                    NVARCHAR2(4000);             --メッセージ返却用
    g_rOPRT                       KKATOPRT%ROWTYPE;            --オンラインジョブステップ情報
    g_sCSV_RCNT                   NVARCHAR2(1000);             --CSVファイル出力件数
    g_sCSVFILENAME                NVARCHAR2(1000);             --CSVファイル名
    c_EMF                         CONSTANT PLS_INTEGER := 1;   --印刷ファイル区分(EMF)
    c_PDF                         CONSTANT PLS_INTEGER := 2;   --印刷ファイル区分(PDF)
    c_EMFANDPDF                   CONSTANT PLS_INTEGER := 3;   --印刷ファイル区分(EMFとPDF)
    g_sPRTFILENAME                NVARCHAR2(1000);             --印刷ファイル名
    g_sSTARTDATE                  NVARCHAR2(23);               --開始時刻
    g_sTYOHYOFROMNAME             NVARCHAR2(1000);             --帳票FORM名
    g_nPRTFILEKBN                 NUMBER;                      --印刷ファイル区分
    g_sTEIKEINUM                  NVARCHAR2(1000);             --定型文番号（リスト）

    --パラメータ変数
    g_nPRTSORT                    NUMBER := 0;                 --ソート順
    g_nNENDO                      NUMBER;                      --年度
    g_nSEIRINO                    NUMBER;                      --整理番号
    g_nNRIREKIRENBAN              NUMBER;                      --履歴連番
    g_nBUNSHONO                   NVARCHAR2(1000);             --文書番号(リスト)
    g_sHASSOBI                    NVARCHAR2(1000);             --発送日
    g_nHAKKOSU                    NUMBER;                      --発行部数

    -- 成人者カーソルデータ取得
    CURSOR CUR_JINSHA IS
    SELECT
          NENDO                                     --年度
        , SEIRI_NO                                  --整理番号
        , KOJIN_CD                                  --宛名番号
        , SHIMEI_KANA                               --氏名カナ
        , SHIMEI_KANJI                              --氏名漢字
        , SEINENGAPI                                --生年月日
        , SEIBETU                                   --性別
        , TYUGAKO_KU                                --中学校区
        , GYOSEI_KU                                 --行政区
        , YUBIN_NO                                  --郵便番号
        , CHOMEI                                    --町名
        , BANCHI                                    --番地
        , KATAGAKI                                  --方書
        , TEL_NO                                    --電話番号
        , SANTEIDANTAI_CD                           --算定団体コード
        , SHOGAKO_KU_CD                             --小学校区コード
        , TYUGAKO_KU_CD                             --中学校区コード
        , GYOSEI_KU_CD                              --行政区コード
    FROM
        GKBTSEIJINSHA 
    WHERE
        NENDO = g_nNENDO
        AND SEIRI_NO = g_nSEIRINO;
    REC_JINSHA CUR_JINSHA%ROWTYPE;
    --------------------------------------------------------
    --  機能概要      : ログ出力処理
    --  パラメータ    : i_sSTEP_NANE       処理単位に任意に付したステップ名
    --                : i_nDEBUG_KBN       デバッグ用か否か(1:デバッグ、0:通常)
    --                : i_nSTATUSID        ログ出力時のステータス(1:異常、0:情報)
    --                : i_sSQLCODE         異常ログ出力時のSQLCODE
    --                : i_sSQLERRM         異常ログ出力時のSQLERRM
    --                : i_sERRMSG          エラーログとして出力する文字列
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_SETLOG(i_sSTEP_NANE IN  NVARCHAR2,
                         i_nDEBUG_KBN IN  NUMBER,
                         i_nSTATUSID  IN  NUMBER,
                         i_sSQLCODE   IN  NVARCHAR2,
                         i_sSQLERRM   IN  NVARCHAR2,
                         i_sERRMSG    IN  NVARCHAR2) RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
    BEGIN
        -- ログ出力（必要数実行する）
        bRTN := KKBPK5551.FSETOLOG (g_sWSNUM,
                                    g_sSTARTDATE,
                                    i_sSTEP_NANE,
                                    i_nDEBUG_KBN,
                                    i_nSTATUSID,
                                    i_sSQLCODE,
                                    i_sSQLERRM,
                                    i_sERRMSG);
        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_SETLOG;
    --------------------------------------------------------
    --  機能概要      : オンライン処理初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_O00INIT RETURN BOOLEAN
    IS
    BEGIN
        -- 初期化
        g_sSTARTDATE := TO_CHAR (SYSTIMESTAMP, 'YYYY/MM/DD HH24:MI:SS.FF3');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_O00INIT;
    --------------------------------------------------------
    --  機能概要      : オンライン処理パラメータ取得処理
    --  パラメータ    : i_sPARAM 処理パラメータテキスト
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_O01PINIT(i_sPARAM IN NVARCHAR2) RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        nCSV_CNT              PLS_INTEGER;                --PL/SQL表の要素数
        aCSV_TBL              DBMS_UTILITY.MAXNAME_ARRAY; --分解されたデータを格納するPL/SQL表
    BEGIN
        -- 引数で受け取ったパラメータをCSVに分解
        bRTN := KKBPK5551.FCSV2TBL (i_sPARAM, nCSV_CNT, aCSV_TBL);

        -- 引数で受け取ったパラメータをグローバル変数に展開
        FOR i IN 1..nCSV_CNT LOOP
            CASE i
                WHEN 1 THEN    g_nNENDO         := aCSV_TBL(i);    --年度
                WHEN 2 THEN    g_nSEIRINO       := aCSV_TBL(i);    --整理番号
                WHEN 3 THEN    g_nNRIREKIRENBAN := aCSV_TBL(i);    --履歴連番
                WHEN 4 THEN    g_nBUNSHONO      := aCSV_TBL(i);    --文書番号(リスト)
                WHEN 5 THEN    g_sHASSOBI       := aCSV_TBL(i);    --発送日
                WHEN 6 THEN    g_nHAKKOSU       := aCSV_TBL(i);    --発行部数
                ELSE NULL;
            END CASE;
        END LOOP;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_O01PINIT;
    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得（帳票）
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYONUM    帳票番号
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_O02PINIT(i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYONUM   IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
    BEGIN
        --ステップ情報クリア
        g_rOPRT := NULL;
        --ステップ情報の取得
        bRTN := KKBPK5551.FOPRTGet (i_sGYOUMUCODE, i_sCHOHYONUM, g_rOPRT);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_O02PINIT;
    --------------------------------------------------------
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_sGYOUMUCODE     業務コード
    --                : i_TBLNAME         テーブル名
    --                : i_sCHOHYOID       帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_O20CSV(i_sGYOUMUCODE  IN  NVARCHAR2,
                         i_TBLNAME      IN  NVARCHAR2,
                         i_sCHOHYOID    IN  NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        nCSV_RCNT             NUMBER;                     --CSVファイル出力件数
        sCSVFILENAME          NVARCHAR2(1000);            --CSVファイル名
        sPRTFILENAME          NVARCHAR2(1000);            --印刷ファイル名
        vOUTCSVSQL            NVARCHAR2(1000);            --SQL文
        nOUTCSVCNT            NUMBER;                     --CSV出力件数
    BEGIN
        --関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'CSV出力処理', 0, 0, '', '', '処理開始');
        vOUTCSVSQL := 'SELECT COUNT(1) FROM ' || i_TBLNAME || ' WHERE ';
        vOUTCSVSQL := vOUTCSVSQL || ' JOBNUM = ' || g_nJOBNUM;
        vOUTCSVSQL := vOUTCSVSQL || ' AND WSNUM = ' || '''' || g_sWSNUM || '''';
        vOUTCSVSQL := vOUTCSVSQL || ' AND BATCHKBN = ' || c_ONLINE;
        EXECUTE IMMEDIATE vOUTCSVSQL INTO nOUTCSVCNT;
        --0件の場合、CSVを出力しない
        IF nOUTCSVCNT = 0 THEN
            bRTN := FUNC_SETLOG(g_rOPRT.CHOHYONAME || 'CSV出力処理', 0, 0, '', '', i_TBLNAME || 'テーブル、' || 'ジョブID ' || g_nJOBNUM || 'の件数が0件ので、CSVを出力しません。処理終了');
            RETURN TRUE;
        END IF;
        IF g_rOPRT.PRTFILEKBN = c_EMFANDPDF THEN
            --CSV出力処理(EMF)
            bRTN := KKBPK5551.FCSVPUT (g_nJOBNUM,
                                       i_sGYOUMUCODE,
                                       g_sWSNUM,
                                       c_ONLINE,
                                       i_TBLNAME,
                                       i_sCHOHYOID,
                                       g_rOPRT.CHOHYOFORM,
                                       c_EMF,
                                       g_rOPRT.TEIKEIBUNNUM_LIST,
                                       nCSV_RCNT,
                                       sCSVFILENAME,
                                       sPRTFILENAME);
            --返却用パラメータを設定する
            g_sCSV_RCNT := g_sCSV_RCNT || nCSV_RCNT || ';';          --CSVファイル出力件数
            g_sCSVFILENAME := g_sCSVFILENAME || sCSVFILENAME || ';'; --CSVファイル名
            g_sPRTFILENAME := g_sPRTFILENAME || sPRTFILENAME || ';'; --印刷ファイル名
            --CSV出力処理(PDF)
            bRTN := KKBPK5551.FCSVPUT (g_nJOBNUM,
                                       i_sGYOUMUCODE,
                                       g_sWSNUM,
                                       c_ONLINE,
                                       i_TBLNAME,
                                       i_sCHOHYOID,
                                       g_rOPRT.CHOHYOFORM,
                                       c_PDF,
                                       g_rOPRT.TEIKEIBUNNUM_LIST,
                                       nCSV_RCNT,
                                       sCSVFILENAME,
                                       sPRTFILENAME);
        ELSE
            --CSV出力処理
            bRTN := KKBPK5551.FCSVPUT (g_nJOBNUM,
                                       i_sGYOUMUCODE,
                                       g_sWSNUM,
                                       c_ONLINE,
                                       i_TBLNAME,
                                       i_sCHOHYOID,
                                       g_rOPRT.CHOHYOFORM,
                                       g_rOPRT.PRTFILEKBN,
                                       g_rOPRT.TEIKEIBUNNUM_LIST,
                                       nCSV_RCNT,
                                       sCSVFILENAME,
                                       sPRTFILENAME);
            --返却用パラメータを設定する
            g_sCSV_RCNT := g_sCSV_RCNT || nCSV_RCNT || ';';          --CSVファイル出力件数
            g_sCSVFILENAME := g_sCSVFILENAME || sCSVFILENAME || ';'; --CSVファイル名
            g_sPRTFILENAME := g_sPRTFILENAME || sPRTFILENAME || ';'; --印刷ファイル名
        END IF;
        --関数終了
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'CSV出力処理', 0, 0, '', '', '処理終了');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'CSV出力処理', 1, 0, SQLCODE, SQLERRM, '異常終了');
            RETURN FALSE;
    END FUNC_O20CSV;
    --------------------------------------------------------
    --  機能概要      : 成人式案内状ワークのレコードの設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_GET_SEIJIN_REC RETURN NUMBER IS
        bRTN                  BOOLEAN;                             --戻る値
        nRTN                  NUMBER;
        rWLTBL                GKBWL400R001%ROWTYPE;                --成人式案内状ﾜｰｸﾃｰﾌﾞﾙ
        sTOIAWASE1            NVARCHAR2(1000);                     --お問い合わせ先１
        sTOIAWASE2            NVARCHAR2(1000);                     --お問い合わせ先２
        sTOIAWASE3            NVARCHAR2(1000);                     --お問い合わせ先３
        o_SHIMEIPRM           A_CONS_PRM;                          --パラメータ配列
        o_LENGTH              NUMBER;                              --パラメータ配列の長度
        o_nDAIRIKBN           NUMBER;                              --認証者の本人・代理区分
        o_sKATAGAKI1          NVARCHAR2(1000);                     --認証者の肩書上段
        o_sKATAGAKI2          NVARCHAR2(1000);                     --認証者の肩書下段
        o_sSHIMEI             NVARCHAR2(1000);                     --認証者の氏名
        o_sKOINFILENAME       NVARCHAR2(1000);                     --公印ファイル名
        o_rATENAKIHON         GABTATENAKIHON%ROWTYPE;              --成人者の宛名基本
        o_rSOFUSAKI           GABTSOFUSAKI%ROWTYPE;                --成人者の送付先基本
        rSEIJIN               GKBTTSUCHISHOKANRISEIJIN%ROWTYPE;    --通知書管理(成人式)ﾃｰﾌﾞﾙ
        o_rJSTP               KKBTJSTP%ROWTYPE;                    --バッチジョブステップテーブルのレコード
        sYUBIN_NO             NVARCHAR2(20);
        rBUNNUMSRCINF         KKAPK0040.MR_BUNNUMSRCINF;           --文書番号情報（構造体）
        rBUNNUMEDITKEKA       KKAPK0040.MR_BUNNUMEDITKEKA;         --文書番号編集結果
        sNUM                  NVARCHAR2(1000);                     --文書番号
        sDATEED               NVARCHAR2(1000);                     --文書日付
    BEGIN
        -- 教育委員会情報を取得する
        nRTN := KKAPK0030.FPRMSHUTOKU('GKB',                       --業務コード
                                      '00SEIJINANNAI',             --制御パラメータ項目コード
                                      1,                           --制御パラメータ項目連番
                                      o_SHIMEIPRM,
                                      o_LENGTH);
        IF nRTN = 0 THEN
            FOR i IN 1..8 LOOP
                IF i > o_SHIMEIPRM.COUNT THEN
                    o_SHIMEIPRM.EXTEND;
                    o_SHIMEIPRM(i) := ' ';
                END IF;
            END LOOP;
        ELSE
            o_SHIMEIPRM := A_CONS_PRM();
            o_SHIMEIPRM.EXTEND;
            FOR i IN 1..8 LOOP
                o_SHIMEIPRM(i) := ' ';
                o_SHIMEIPRM.EXTEND;
            END LOOP;
        END IF;
        sTOIAWASE1 := o_SHIMEIPRM(1);                              --お問い合わせ先１
        sTOIAWASE2 := o_SHIMEIPRM(6);                              --お問い合わせ先２
        sTOIAWASE3 := o_SHIMEIPRM(7);                              --お問い合わせ先３
        -- 公印情報を取得する
        bRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE,0),
                                     g_sWSNUM,
                                     SYSDATE,
                                     o_nDAIRIKBN,
                                     o_sKATAGAKI1,                 --変数.認証者肩書上段
                                     o_sKATAGAKI2,                 --変数.認証者肩書下段
                                     o_sSHIMEI,                    --変数.認証者名
                                     o_sKOINFILENAME);             --変数.公印ファイル名
        -- 文書番号・発付年月日の取得、設定
        rBUNNUMSRCINF := KKBPK5551.FBunNumInf(g_sBUNSHONUMLIST);
        --文書番号編集結果を取得
        rBUNNUMEDITKEKA := rBUNNUMSRCINF.UOUT;
        --文書番号
        IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
           --文書入力画面で文書番号印字ありのとき設定
            sNUM := rBUNNUMEDITKEKA.NUM;
        ELSE
            sNUM := '';
        END IF;
        -- 文書日付
        IF rBUNNUMEDITKEKA.DATEUMUFLG = 0 THEN
            --文書入力画面で文書日付印字ありのとき設定
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.001:IT_GKB_00433対応
            --sDATEED := rBUNNUMEDITKEKA.DATEED;
            sDATEED := rBUNNUMEDITKEKA.BUNDATE;
        ELSE
            sDATEED := '';
        END IF;
        -- 通知書管理(成人式)からデータを取得する
        BEGIN
            SELECT
                  TSUCHIBUN                                        --通知文
                , CHOHYO_MEI                                       --帳票名
                --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 Start
                /*, DATE_MEI1                                        --日付１
                , DATE_MEI2                                        --日付２
                , DATE_MEI3                                        --日付３
                , DATE_MEI4                                        --日付４
                , DATE_MEI5                                        --日付５
                , KOMOKU_MEI1                                      --項目１
                , KOMOKU_MEI2                                      --項目２
                , KOMOKU_MEI3                                      --項目３
                , KOMOKU_MEI4                                      --項目４
                , KOMOKU_MEI5                                      --項目５
                , KOMOKU_MEI6                                      --項目６
                , KOMOKU_MEI7                                      --項目７
                , KOMOKU_MEI8                                      --項目８
                , KOMOKU_MEI9                                      --項目９
                , KOMOKU_MEI10                                     --項目１０
                */
                --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 End
                , KOIN_SHORYAKU                                    --公印省略
                , KOIN_CHUSHAKU                                    --公印注釈
                , YOSHIKI_BANGO_SETTOGO                            --様式番号接頭語
                , YOSHIKI_BANGO                                    --様式番号
                , YOSHIKI_BANGO_SETSUBIGO                          --様式番号接尾語
            INTO
                  rSEIJIN.TSUCHIBUN
                , rSEIJIN.CHOHYO_MEI
                --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 Start
                /*, rSEIJIN.DATE_MEI1
                , rSEIJIN.DATE_MEI2
                , rSEIJIN.DATE_MEI3
                , rSEIJIN.DATE_MEI4
                , rSEIJIN.DATE_MEI5
                , rSEIJIN.KOMOKU_MEI1
                , rSEIJIN.KOMOKU_MEI2
                , rSEIJIN.KOMOKU_MEI3
                , rSEIJIN.KOMOKU_MEI4
                , rSEIJIN.KOMOKU_MEI5
                , rSEIJIN.KOMOKU_MEI6
                , rSEIJIN.KOMOKU_MEI7
                , rSEIJIN.KOMOKU_MEI8
                , rSEIJIN.KOMOKU_MEI9
                , rSEIJIN.KOMOKU_MEI10
                */
                --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 End
                , rSEIJIN.KOIN_SHORYAKU
                , rSEIJIN.KOIN_CHUSHAKU
                , rSEIJIN.YOSHIKI_BANGO_SETTOGO
                , rSEIJIN.YOSHIKI_BANGO
                , rSEIJIN.YOSHIKI_BANGO_SETSUBIGO
            FROM
                GKBTTSUCHISHOKANRISEIJIN
            WHERE
                CHOHYO_KBN = '1';
        EXCEPTION
            WHEN OTHERS THEN
                rSEIJIN.TSUCHIBUN               := NULL;
                rSEIJIN.CHOHYO_MEI              := NULL;
                --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 Start
                /*rSEIJIN.DATE_MEI1               := NULL;
                rSEIJIN.DATE_MEI2               := NULL;
                rSEIJIN.DATE_MEI3               := NULL;
                rSEIJIN.DATE_MEI4               := NULL;
                rSEIJIN.DATE_MEI5               := NULL;
                rSEIJIN.KOMOKU_MEI1             := NULL;
                rSEIJIN.KOMOKU_MEI2             := NULL;
                rSEIJIN.KOMOKU_MEI3             := NULL;
                rSEIJIN.KOMOKU_MEI4             := NULL;
                rSEIJIN.KOMOKU_MEI5             := NULL;
                rSEIJIN.KOMOKU_MEI6             := NULL;
                rSEIJIN.KOMOKU_MEI7             := NULL;
                rSEIJIN.KOMOKU_MEI8             := NULL;
                rSEIJIN.KOMOKU_MEI9             := NULL;
                rSEIJIN.KOMOKU_MEI10            := NULL;
                */
                --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応
                rSEIJIN.KOIN_SHORYAKU           := NULL;
                rSEIJIN.KOIN_CHUSHAKU           := NULL;
                rSEIJIN.YOSHIKI_BANGO_SETTOGO   := NULL;
                rSEIJIN.YOSHIKI_BANGO           := NULL;
                rSEIJIN.YOSHIKI_BANGO_SETSUBIGO := NULL;
        END;
        OPEN CUR_JINSHA;
        -- 成人者カーソルデータ取得
        LOOP
            FETCH CUR_JINSHA INTO REC_JINSHA;
            EXIT WHEN CUR_JINSHA%NOTFOUND;
            --  2024/11/15 ZCZL.ZHANGLEI DEL START 0.3.000.002:IT_GKB_00539横展開対応
            --g_nPRTSORT              := g_nPRTSORT + 1;
            --rWLTBL.NO               := g_nPRTSORT;                                  --ソート順
            --  2024/11/15 ZCZL.ZHANGLEI DEL END
            rWLTBL.NENDO            := NULL;                                        --年度
            rWLTBL.KAIPAGE_CD       := NULL;                                        --改頁コード
            rWLTBL.KAIPAGE_MEI      := NULL;                                        --改頁名
            rWLTBL.GYOSEIKU_MEI     := NULL;                                        --行政区名
            rWLTBL.SANTEIDANTAI_MEI := NULL;                                        --算定団体名
            rWLTBL.SHIMEI_KANA      := NULL;                                        --氏名カナ
            rWLTBL.SEINENGAPI       := NULL;                                        --生年月日
            rWLTBL.SEIBETSU         := NULL;                                        --性別
            rWLTBL.SAKUSEIBI        := NULL;                                        --作成日
            rWLTBL.RENBAN           := NULL;                                        --連番
            rWLTBL.SHIMEI_KANJI     := NULL;                                        --氏名漢字
            rWLTBL.ZOKUGARAMEI      := NULL;                                        --続柄名
            --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 Start
            --IF REC_JINSHA.KOJIN_CD IS NOT NULL THEN
            IF REC_JINSHA.KOJIN_CD <> 0 THEN
            --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 End
                --成人者の宛名情報を取得
                nRTN := GAAPK0030.FGETATENA(REC_JINSHA.KOJIN_CD,                    --宛名番号
                                            'GKB',                                  --業務コード
                                            TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),--基準日
                                            o_rATENAKIHON,                          --成人者の宛名基本
                                            o_rSOFUSAKI);                           --成人者の送付先基本
                --方書
                IF o_rSOFUSAKI.KATAGAKI IS NOT NULL THEN
                    rWLTBL.KATAGAKI := o_rSOFUSAKI.KATAGAKI;
                ELSE
                    rWLTBL.KATAGAKI := o_rATENAKIHON.KATAGAKI;
                END IF;
                --郵便番号
                IF o_rSOFUSAKI.YUBIN_NO IS NOT NULL THEN
                    --郵便番号編集処理
                    nRTN := KKAPK0010.FYUBINHENSHU(o_rSOFUSAKI.YUBIN_NO, sYUBIN_NO);
                    rWLTBL.YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO, 0);
                ELSE
                    nRTN := KKAPK0010.FYUBINHENSHU(o_rATENAKIHON.YUBIN_NO, sYUBIN_NO);
                    rWLTBL.YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO, 0);
                END IF;
                --住所
                --  2024/11/22 ZCZL.ZHANGLEI UPDATE 0.3.000.003:IT_GKB_00605:仕様変更対応
                --rWLTBL.JUSHO  := GAAPK0010.FADDRESSEDIT(1, NULL,o_rSOFUSAKI.CHOMEI, o_rSOFUSAKI.BANCHI, o_rSOFUSAKI.KATAGAKI, NULL);
                --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 Start
                --rWLTBL.JUSHO  := GAAPK0010.FADDRESSEDIT(1, NULL,o_rSOFUSAKI.CHOMEI, o_rSOFUSAKI.BANCHI, NULL, NULL);
                --  2024/12/20 JPJYS.SHAXUE UPDATE 0.3.000.006:品質強化IT_GKB_10104,IT_GKB_10105:故障対応　START
                --rWLTBL.JUSHO  := GAAPK0010.FADDRESSEDIT(1, NULL,REC_JINSHA.CHOMEI, REC_JINSHA.BANCHI, NULL, NULL);
                IF o_rSOFUSAKI.CHOMEI IS NOT NULL or o_rSOFUSAKI.BANCHI IS NOT NULL THEN
                    rWLTBL.JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL,o_rSOFUSAKI.CHOMEI, o_rSOFUSAKI.BANCHI, NULL, NULL);
                ELSE
                    rWLTBL.JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL,o_rATENAKIHON.CHOMEI, o_rATENAKIHON.BANCHI, NULL, NULL);
                END IF;
                
                --  2024/12/20 JPJYS.SHAXUE UPDATE 0.3.000.006:品質強化IT_GKB_10104,IT_GKB_10105:故障対応　END
                
                --rWLTBL.SHIMEI := o_rATENAKIHON.SHIMEI_KANJI;                        --氏名
                rWLTBL.SHIMEI := o_rATENAKIHON.SHIMEI_KANJI||'　様';
                --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 End
                --カスタマバーコード
                IF o_rSOFUSAKI.YUBIN_NOBC IS NOT NULL THEN
                    rWLTBL.BC_NO := o_rSOFUSAKI.YUBIN_NOBC;
                ELSE
                    rWLTBL.BC_NO := o_rATENAKIHON.YUBIN_NOBC;
                END IF;
            ELSE
                rWLTBL.KATAGAKI := REC_JINSHA.KATAGAKI;                             --方書
                --郵便番号
                nRTN := KKAPK0010.FYUBINHENSHU(REC_JINSHA.YUBIN_NO, sYUBIN_NO);
                rWLTBL.YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO, 0);
                --住所
                --  2024/11/22 ZCZL.ZHANGLEI UPDATE 0.3.000.003:IT_GKB_00605:仕様変更対応
                --rWLTBL.JUSHO  := GAAPK0010.FADDRESSEDIT(1, NULL,REC_JINSHA.CHOMEI, REC_JINSHA.BANCHI, o_rSOFUSAKI.KATAGAKI, NULL);
                rWLTBL.JUSHO  := GAAPK0010.FADDRESSEDIT(1, NULL,REC_JINSHA.CHOMEI, REC_JINSHA.BANCHI, NULL, NULL);
                --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 Start
                --rWLTBL.SHIMEI := REC_JINSHA.SHIMEI_KANJI;                           --氏名
                rWLTBL.SHIMEI := REC_JINSHA.SHIMEI_KANJI||'　様';                           --氏名
                --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 End
                --カスタマバーコード
                rWLTBL.BC_NO  := GAAPK0010.FCUSTOM_BC(REC_JINSHA.YUBIN_NO, REC_JINSHA.CHOMEI, REC_JINSHA.BANCHI, REC_JINSHA.KATAGAKI);
            END IF;
            rWLTBL.JUSHO_JODAN          := NULL;                                    --住所上
            rWLTBL.JUSHO_GEDAN          := NULL;                                    --住所下
            rWLTBL.NUSHI_SHIMEI_KANA    := NULL;                                    --氏名カナ主
            rWLTBL.NUSHI_SHIMEI_KANJI   := NULL;                                    --氏名漢字主
            rWLTBL.SYUHATU_NO           := sNUM;                                    --収発番号
            --発送日
            rWLTBL.HASSOBI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sDATEED, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10);
            --  2024/12/20 JPJYS.SHAXUE UPDATE 0.3.000.006:品質強化IT_GKB_10104,IT_GKB_10105:故障対応　START
            rWLTBL.HASSOBI :=REGEXP_REPLACE(
                TRANSLATE(REPLACE(REPLACE(rWLTBL.HASSOBI, ' ', ''), '　', ''), '0123456789', '０１２３４５６７８９'),
                '(０)([１-９])', 
                '\2', 
                1, 
                0, 
                'c'
                );
            --  2024/12/20 JPJYS.SHAXUE UPDATE 0.3.000.006:品質強化IT_GKB_10104,IT_GKB_10105:故障対応　END
            rWLTBL.SHIKUCHOSON_KATAGAKI := o_sKATAGAKI1 || o_sKATAGAKI2;            --市長名称
            rWLTBL.SHIKUCHOSON_CHOMEI   := o_sSHIMEI;                               --市長名
            rWLTBL.KYOIKU_KAI_MEI       := o_SHIMEIPRM(1);                          --教育長名称
            rWLTBL.KYOIKU_SHUCHO_MEI    := o_SHIMEIPRM(2) || '　' || o_SHIMEIPRM(3); --教育長名
            rWLTBL.TITLE                := rSEIJIN.CHOHYO_MEI;                      --タイトル
            rWLTBL.SHIKUCHOSON_MEI      := NULL;                                    --市町村名
            rWLTBL.KYOIKU_YUBIN_NO      := NULL;                                    --委員会郵便番号
            rWLTBL.KYOIKU_JUSHO         := NULL;                                    --委員会住所
            rWLTBL.KYOIKU_TEL           := NULL;                                    --委員会電話番号
       --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 Start
           -- 通知書条件(成人式)からデータを取得する
           BEGIN
              SELECT
                  DATE1
                , KOMOKU1
                , KOMOKU2
                , KOMOKU3
                , KOMOKU4
                , KOMOKU5
                , KOMOKU6
                , KOMOKU7
                , KOMOKU8
                , KOMOKU9
                , KOMOKU10
              INTO
                  rSEIJIN.DATE_MEI1
                , rSEIJIN.KOMOKU_MEI1
                , rSEIJIN.KOMOKU_MEI2
                , rSEIJIN.KOMOKU_MEI3
                , rSEIJIN.KOMOKU_MEI4
                , rSEIJIN.KOMOKU_MEI5
                , rSEIJIN.KOMOKU_MEI6
                , rSEIJIN.KOMOKU_MEI7
                , rSEIJIN.KOMOKU_MEI8
                , rSEIJIN.KOMOKU_MEI9
                , rSEIJIN.KOMOKU_MEI10
              FROM
                GKBTTSUCHISHOJKNSEIJIN
              WHERE
                 CHOHYO_KBN = '1'
                 AND DANTAI_CD  = REC_JINSHA.SANTEIDANTAI_CD;
                 
          EXCEPTION
              WHEN OTHERS THEN
                rSEIJIN.DATE_MEI1               := NULL;
                rSEIJIN.DATE_MEI2               := NULL;
                rSEIJIN.DATE_MEI3               := NULL;
                rSEIJIN.DATE_MEI4               := NULL;
                rSEIJIN.DATE_MEI5               := NULL;
                rSEIJIN.KOMOKU_MEI1             := NULL;
                rSEIJIN.KOMOKU_MEI2             := NULL;
                rSEIJIN.KOMOKU_MEI3             := NULL;
                rSEIJIN.KOMOKU_MEI4             := NULL;
                rSEIJIN.KOMOKU_MEI5             := NULL;
                rSEIJIN.KOMOKU_MEI6             := NULL;
                rSEIJIN.KOMOKU_MEI7             := NULL;
                rSEIJIN.KOMOKU_MEI8             := NULL;
                rSEIJIN.KOMOKU_MEI9             := NULL;
                rSEIJIN.KOMOKU_MEI10            := NULL;
              END;
            --rWLTBL.DATE1                := rSEIJIN.DATE_MEI1;                       --日付１
            rWLTBL.DATE1                := KKAPK0020.FDAYEDIT20(rSEIJIN.DATE_MEI1,0,3,0,NULL);--日付１
            --  2024/12/20 JPJYS.SHAXUE UPDATE 0.3.000.006:品質強化IT_GKB_10104,IT_GKB_10105:故障対応　START
            rWLTBL.DATE1 :=REGEXP_REPLACE(
                TRANSLATE(REPLACE(REPLACE(rWLTBL.DATE1, ' ', ''), '　', ''), '0123456789', '０１２３４５６７８９'),
                '(０)([１-９])', 
                '\2', 
                1, 
                0, 
                'c'
                );
                --  2024/12/20 JPJYS.SHAXUE UPDATE 0.3.000.006:品質強化IT_GKB_10104,IT_GKB_10105:故障対応　END
            --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:IT_GKB_10036,IT_GKB_10037,IT_GKB_10039:仕様変更対応 End
            rWLTBL.DATE2                := NULL;                                    --日付２
            rWLTBL.DATE3                := NULL;                                    --日付３
            rWLTBL.DATE4                := NULL;                                    --日付４
            rWLTBL.DATE5                := NULL;                                    --日付５
            rWLTBL.KOMOKU1              := rSEIJIN.KOMOKU_MEI1;                     --項目１
            rWLTBL.KOMOKU2              := rSEIJIN.KOMOKU_MEI2;                     --項目２
            rWLTBL.KOMOKU3              := rSEIJIN.KOMOKU_MEI3;                     --項目３
            rWLTBL.KOMOKU4              := rSEIJIN.KOMOKU_MEI4;                     --項目４
            rWLTBL.KOMOKU5              := rSEIJIN.KOMOKU_MEI5;                     --項目５
            rWLTBL.KOMOKU6              := NULL;                                    --項目６
            rWLTBL.KOMOKU7              := NULL;                                    --項目７
            rWLTBL.KOMOKU8              := NULL;                                    --項目８
            rWLTBL.KOMOKU9              := NULL;                                    --項目９
            rWLTBL.KOMOKU10             := NULL;                                    --項目１０
            rWLTBL.SHUCHO_KOIN          := o_sKOINFILENAME;                         --首長公印
            rWLTBL.WAREKI_NENDO         := NULL;                                    --和暦年度
            rWLTBL.SEIRI_BANGO          := NULL;                                    --整理番号
            rWLTBL.SETAINUSHIMEI        := NULL;                                    --表示用世帯主名
            --  2024/11/22 ZCZL.ZHANGLEI UPDATE START 0.3.000.003:IT_GKB_00605:仕様変更対応
            --rWLTBL.KOIN_SHORYAKU        := rSEIJIN.KOIN_SHORYAKU;                   --公印省略
            --rWLTBL.KOIN_CHUSHAKU        := rSEIJIN.KOIN_CHUSHAKU;                   --公印注釈
            IF o_sKOINFILENAME IS NOT NULL THEN
              rWLTBL.KOIN_SHORYAKU        := NULL;                                    --公印省略
              rWLTBL.KOIN_CHUSHAKU        := rSEIJIN.KOIN_CHUSHAKU;                   --公印注釈
            ELSE
              rWLTBL.KOIN_SHORYAKU        := rSEIJIN.KOIN_SHORYAKU;                   --公印省略
              rWLTBL.KOIN_CHUSHAKU        := NULL;                                    --公印注釈
            END IF;
            --  2024/11/22 ZCZL.ZHANGLEI UPDATE END
--  2024/11/15 JPJYS.WENGSILIANG UPDATE 0.3.000.003:IT_GKB_00543対応 START
--            rWLTBL.TSUCHIBUN            := rSEIJIN.TSUCHIBUN;                       --通知文
            --通知文
            rWLTBL.TSUCHIBUN            := REPLACE(rSEIJIN.TSUCHIBUN, chr(13)||chr(10),'#');
--  2024/11/15 JPJYS.WENGSILIANG UPDATE 0.3.000.003:IT_GKB_00543対応 END
            rWLTBL.TOIAWASESAKI         := sTOIAWASE1;                              --お問い合わせ先
            rWLTBL.TOIAWASE_JUSHO       := sTOIAWASE2;                              --お問い合わせ先住所
            rWLTBL.TOIAWASE_TEL         := sTOIAWASE3;                              --お問い合わせ先電話番号
            --様式番号
            rWLTBL.YOSHIKI_NO           := rSEIJIN.YOSHIKI_BANGO_SETTOGO || rSEIJIN.YOSHIKI_BANGO || rSEIJIN.YOSHIKI_BANGO_SETSUBIGO;
            rWLTBL.BREAK_NO             := NULL;                  --改ページキー
            rWLTBL.WSNUM                := g_sWSNUM;              --端末番号
            rWLTBL.BATCHKBN             := c_ONLINE;              --即時バッチ区分
            rWLTBL.JOBNUM               := g_nJOBNUM;             --ジョブNO
            FOR i IN 1..g_nHAKKOSU LOOP
                --  2024/11/15 ZCZL.ZHANGLEI ADD START 0.3.000.002:IT_GKB_00539横展開対応
                g_nPRTSORT              := g_nPRTSORT + 1;
                rWLTBL.NO               := g_nPRTSORT;                                  --ソート順
                --  2024/11/15 ZCZL.ZHANGLEI ADD END
                --登録ワークテーブル
                INSERT INTO GKBWL400R001 VALUES rWLTBL;
            END LOOP;
        END LOOP;
        CLOSE CUR_JINSHA;
        -- 関数終了
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
            IF CUR_JINSHA%ISOPEN THEN
                CLOSE CUR_JINSHA;
            END IF;
            RETURN c_ERR;
    END FUNC_GET_SEIJIN_REC;
    --------------------------------------------------------
    --  機能概要      : データ取得、ワークテーブル登録
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                             --戻る値
        nRTN                  NUMBER;
        ERR                     EXCEPTION;
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');
        -- 初期化
        DELETE FROM GKBWL400R001
        WHERE WSNUM = g_sWSNUM
        AND BATCHKBN = c_ONLINE;
        -- 成人式案内状ワークのレコードの設定
        nRTN := FUNC_GET_SEIJIN_REC;
        IF nRTN <> 0 THEN
          RAISE ERR;
        END IF;
        -- 帳票出力CSVの作成
        bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL400R001', i_sCHOHYOID);
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理終了');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 1, 0, SQLCODE, SQLERRM, '異常終了');
            RETURN FALSE;
    END FUNC_O10MAIN;
    ------------------------------------------------------------------------
    --  機能概要      : オンラインパラメータ取得処理
    --  パラメータ    : i_sGYOUMUCODE_LIST   業務コード（リスト）
    --                : i_sCHOHYONUM_LIST    帳票番号（リスト）
    --                : i_sCHOHYOID_LIST     帳票ID（リスト）
    --                : i_sPARAM             抽出条件（リスト）
    --                : i_sBUNSHONUM_LIST    文書番号情報（リスト）（リスト）
    --                : i_sTANTOCODE         ログイン情報.担当者コード
    --                : i_sWSNUM             ログイン情報.端末番号
    --                : o_RESULT             0:すべてのファイル生成成功 -1:異常終了
    --                : o_sCSVCNT_LIST       CSVファイル出力件数（リスト）
    --                : o_sCSVFILENAME_LIST  CSVファイル名（リスト）
    --                : o_sPRTFILENAME_LIST  印刷ファイル名(EMF,PDF)（リスト）
    --                : o_sMESSAGE           エラーメッセージ
    --  戻り値        : なし
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/03
    ------------------------------------------------------------------------
    PROCEDURE PONLINE(i_sGYOUMUCODE_LIST  IN  NVARCHAR2,
                      i_sCHOHYONUM_LIST   IN  NVARCHAR2,
                      i_sCHOHYOID_LIST    IN  NVARCHAR2,
                      i_sPARAM            IN  NVARCHAR2,
                      i_sBUNSHONUM_LIST   IN  NVARCHAR2,
                      i_sTANTOCODE        IN  NVARCHAR2,
                      i_sWSNUM            IN  NVARCHAR2,
                      o_nRESULT           OUT NUMBER,
                      o_sCSVCNT_LIST      OUT NVARCHAR2,
                      o_sCSVFILENAME_LIST OUT NVARCHAR2,
                      o_sPRTFILENAME_LIST OUT NVARCHAR2,
                      o_sMESSAGE          OUT NVARCHAR2)
    IS
        bRTN                  BOOLEAN;                    --戻る値
        ePRMEXCEPTION         EXCEPTION;                  --パラメータ取得異常タイプ
        eSHORIEXCEPTION       EXCEPTION;                  --処理異常タイプ
        aGYOUMUCODE           KKBPK5551.tySPLIT_tbl;      -- 業務コード（リスト）
        aCHOHYONUM            KKBPK5551.tySPLIT_tbl;      -- 帳票番号（リスト）
        aCHOHYOID             KKBPK5551.tySPLIT_tbl;      -- 帳票ID（リスト）
    BEGIN
        --初期化
        g_nJOBNUM    := 0;                                --ジョブナンバー
        g_sTANTOCODE := i_sTANTOCODE;                     --担当者コード
        g_sWSNUM     := i_sWSNUM;                         --端末番号
        g_sBUNSHONUMLIST := i_sBUNSHONUM_LIST;            --文書番号情報（リスト）
        g_sCSV_RCNT := NULL;                              --CSVファイル出力件数
        g_sCSVFILENAME := NULL;                           --CSVファイル名
        g_sPRTFILENAME := NULL;                           --印刷ファイル名(EMF,PDF)

        -- 入力引数を分解して配列にセットする
        -- 引数の業務コード（リスト）の配列化
        aGYOUMUCODE := KKBPK5551.FSplitStr (i_sGYOUMUCODE_LIST);
        -- 引数の帳票番号（リスト）の配列化
        aCHOHYONUM := KKBPK5551.FSplitStr (i_sCHOHYONUM_LIST);
        -- 引数の帳票ID（リスト）の配列化
        aCHOHYOID := KKBPK5551.FSplitStr (i_sCHOHYOID_LIST);

        -- 初期処理
        bRTN := FUNC_O00INIT;
        IF NOT bRTN THEN
            o_sMESSAGE := g_sMESSAGE;
            RAISE ePRMEXCEPTION;
        END IF;

        -- パラメータ取得処理
        bRTN := FUNC_O01PINIT (i_sPARAM);
        IF NOT bRTN THEN
            RAISE ePRMEXCEPTION;
        END IF;

        -- 処理ステップを取得
        FOR i IN 1..aGYOUMUCODE.COUNT LOOP
            -- オンラインステップ処理パラメータ取得
            bRTN := FUNC_O02PINIT (aGYOUMUCODE(i), aCHOHYONUM(i));
            IF NOT bRTN THEN
                RAISE eSHORIEXCEPTION;
            END IF;
            --メイン処理
            IF i = 1 THEN
                bRTN := FUNC_O10MAIN (aGYOUMUCODE(i), aCHOHYOID(i));
                IF NOT bRTN THEN
                    o_sMESSAGE := g_sMESSAGE;
                    RAISE eSHORIEXCEPTION;
                END IF;
            ELSE
                bRTN := FUNC_O10MAIN (aGYOUMUCODE(i), KKBPK5551.c_CSVCOMBINATOR || aCHOHYOID(i));
                IF NOT bRTN THEN
                    o_sMESSAGE := g_sMESSAGE;
                    RAISE eSHORIEXCEPTION;
                END IF;
            END IF;
        END LOOP;

        COMMIT;
        o_sCSVCNT_LIST := g_sCSV_RCNT;
        o_sCSVFILENAME_LIST := g_sCSVFILENAME;
        o_sPRTFILENAME_LIST := g_sPRTFILENAME;
        o_nRESULT := c_OK;
    EXCEPTION
        WHEN ePRMEXCEPTION THEN
            o_sCSVCNT_LIST := NULL;
            o_sCSVFILENAME_LIST := NULL;
            o_sPRTFILENAME_LIST := NULL;
            o_nRESULT := c_ERR;
        WHEN eSHORIEXCEPTION THEN
            o_sCSVCNT_LIST := NULL;
            o_sCSVFILENAME_LIST := NULL;
            o_sPRTFILENAME_LIST := NULL;
            o_nRESULT := c_ERR;
            ROLLBACK;
        WHEN OTHERS THEN
            o_sCSVCNT_LIST := NULL;
            o_sCSVFILENAME_LIST := NULL;
            o_sPRTFILENAME_LIST := NULL;
            o_nRESULT := c_ERR;
            ROLLBACK;
    END PONLINE;
END GKBPA00200;
/