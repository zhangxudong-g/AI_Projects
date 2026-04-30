CREATE OR REPLACE PACKAGE BODY GKBPA00081
--1.0.301.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 教育異動通知書作成（即時）_CSV作成
--  機能概要      : 画面からの引数を元に項目を編集して CSVファイルを出力する。
--                  異動通知書作成（GKBSKIDOTCH）を呼び出す。
--                  KyoikuIdoTsuchishoPreviewEJBBean.javaで呼び出す用。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.LIKEWEN 2024/01/18
--------------------------------------------------------
--  変更履歴
--  2024/03/13-ZCZL.LIKEWEN Update 0.2.000.001:教育残作業対応
--  2025/05/20 ZCZL.wanghj Update 1.0.301.000:認証コード名を取得(QA23484)
--------------------------------------------------------
IS
    -- 全処理必須パラメータ
    c_ONLINE                      CONSTANT PLS_INTEGER := 1;   --オンライン
    c_OK                          CONSTANT PLS_INTEGER := 0;   --正常
    c_ERR                         CONSTANT PLS_INTEGER := -1;  --異常
    c_EMF                         CONSTANT PLS_INTEGER := 1;   --印刷ファイル区分(EMF)
    c_PDF                         CONSTANT PLS_INTEGER := 2;   --印刷ファイル区分(PDF)
    c_EMFANDPDF                   CONSTANT PLS_INTEGER := 3;   --印刷ファイル区分(EMFとPDF)
    g_nJOBNUM                     NUMBER;                      --ジョブナンバー
    g_sTANTOCODE                  CHAR(12);                    --担当者コード
    g_sWSNUM                      NVARCHAR2(63);               --端末番号
    g_sRECUPDKBNCODE              CHAR(2);                     --更新処理区分コード
    g_sBUNSHONUMLIST              NVARCHAR2(1000);             --文書番号情報（リスト）
    g_sMESSAGE                    NVARCHAR2(4000);             --メッセージ返却用
    g_rOPRT                       KKATOPRT%ROWTYPE;            --オンラインジョブステップ情報
    g_sCSV_RCNT                   NVARCHAR2(1000);             --CSVファイル出力件数
    g_sCSVFILENAME                NVARCHAR2(1000);             --CSVファイル名
    g_sPRTFILENAME                NVARCHAR2(1000);             --印刷ファイル名
    g_sSTARTDATE                  NVARCHAR2(23);               --開始時刻

    --パラメータ変数
    i_SHORI_BI                    NVARCHAR2(1000);             -- 日付
    i_SHORI_JIKAN                 NVARCHAR2(1000);             -- 時間
    i_CHOHYO_ID                   NVARCHAR2(1000);             -- 帳票ＩＤ（定義体名）
    i_CHOHYO_ID_S                 NVARCHAR2(1000);             -- 帳票ＩＤ（新１年生用定義体名）

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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/18
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/18
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
    --  パラメータ    : i_vPARAM 処理パラメータテキスト
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/18
    --------------------------------------------------------
    FUNCTION FUNC_O01PINIT(i_sPARAM IN NVARCHAR2) RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        aCSV_TBL              DBMS_UTILITY.MAXNAME_ARRAY; --分解されたデータを格納するPL/SQL表
        nCSV_CNT              PLS_INTEGER;                --PL/SQL表の要素数
    BEGIN
        -- 引数で受け取ったパラメータをCSVに分解
        bRTN := KKBPK5551.FCSV2TBL (i_sPARAM, nCSV_CNT, aCSV_TBL);

        -- 引数で受け取ったパラメータをグローバル変数に展開
        FOR i IN 1..nCSV_CNT LOOP
            CASE i
                WHEN 1  THEN    i_SHORI_BI             := aCSV_TBL(i);    -- 日付
                WHEN 2  THEN    i_SHORI_JIKAN          := aCSV_TBL(i);    -- 時間
                WHEN 3  THEN    i_CHOHYO_ID            := aCSV_TBL(i);    -- 帳票ＩＤ（定義体名）
                WHEN 4  THEN    i_CHOHYO_ID_S          := aCSV_TBL(i);    -- 帳票ＩＤ（新１年生用定義体名）
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/18
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
    --                : o_sCSV_RCNT       CSVファイル出力件数
    --                : o_sCSVFILENAME    CSVファイル名
    --                : o_sPRTFILENAME    印刷ファイル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/18
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
            --返却用パラメータを追加設定する
            g_sCSVFILENAME := g_sCSVFILENAME || sCSVFILENAME || ';'; --CSVファイル名
            g_sPRTFILENAME := g_sPRTFILENAME || sPRTFILENAME || ';'; --印刷ファイル名
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
    --  機能概要      : メインビジネスロジック処理
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/18
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
-- 2025/05/20 ZCZL.wanghj Add start 1.0.301.000:認証コード名を取得
        VSHUCHOMEI                  NVARCHAR2(50);
        o_nDAIRIKBN                 NUMBER;
        o_vKATAGAKI1                NVARCHAR2(50);
        o_vKATAGAKI2                NVARCHAR2(50);
        o_vKOINFILENAME             NVARCHAR2(50);
-- 2025/05/20 ZCZL.wanghj Add end
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');

        -- 教育異動通知書（即時）CSVファイル作成
        -- 初期化
        --  2024/03/13-ZCZL.LIKEWEN Update START 0.2.000.001:教育残作業対応
        --DELETE FROM GKBWL090R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
        DELETE FROM GKBWL600R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
        --  2024/03/13-ZCZL.LIKEWEN Update END
-- 2025/05/20 ZCZL.wanghj Add start 1.0.301.000:認証コード名を取得
            bRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE,0),
                           g_sWSNUM,
                           TO_DATE(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'))),
                           o_nDAIRIKBN,
                           o_vKATAGAKI1,
                           o_vKATAGAKI2,
                           VSHUCHOMEI,
                           o_vKOINFILENAME);
-- 2025/05/20 ZCZL.wanghj Add end
-- 2025/05/20 ZCZL.wanghj Update 1.0.301.000:認証コード名を取得
--        GKBSKIDOTCH(i_SHORI_BI, i_SHORI_JIKAN, g_sWSNUM, g_sTANTOCODE, i_CHOHYO_ID, i_CHOHYO_ID_S, g_nJOBNUM, c_ONLINE);
        GKBSKIDOTCH(i_SHORI_BI, i_SHORI_JIKAN, g_sWSNUM, g_sTANTOCODE, i_CHOHYO_ID, i_CHOHYO_ID_S, g_nJOBNUM, o_vKOINFILENAME, o_vKATAGAKI1, VSHUCHOMEI, c_ONLINE);
        -- 帳票出力CSVの作成
        --  2024/03/13-ZCZL.LIKEWEN Update START 0.2.000.001:教育残作業対応
        --bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL090R001', i_sCHOHYOID);
        bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL600R001', i_sCHOHYOID);
        --  2024/03/13-ZCZL.LIKEWEN Update END
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/18
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
END GKBPA00081;
/
