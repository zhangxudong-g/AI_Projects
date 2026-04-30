CREATE OR REPLACE PACKAGE BODY GKBPA00190
--1.0.106.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : オンラインパラメータ取得処理
--  機能概要      : 学校選択制案内書および学校選択制調査書の即時帳票を印刷する場合に呼び出される。
--                  標準仕様の帳票レイアウトに合わせた項目を出力する。
--                  
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.Lvjq 2024/06/03
--------------------------------------------------------
--  変更履歴
--  2024/08/02 ZCZL.yangshuai Update 0.3.000.001:検収指摘No.90の対応
--  2024/09/04 ZCZL.caiqiushi Update 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/24 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00007、IT_GKB_00008対応
--  2024/09/30 ZCZL.WANGMING UPDATE 0.3.000.004:IT_GKB_00270、IT_GKB_00271対応
--  2024/10/28 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00404の対応
--  2024/11/06 ZCZL.WANGYUNING UPDATE 0.3.000.006:IT_GKB_00455の対応
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.007:IT_GKB_00625対応
--  2024/11/22 ZCZL.WANGYUNING UPDATE 0.3.000.008:IT_GKB_00635対応
--  2024/11/25 ZCZL.WANGYUNING UPDATE 0.3.000.009:IT_GKB_00528対応
--  2024/11/29 ZCZL.WANGYUNING UPDATE 0.3.000.010:IT_GKB_00685対応
--  2024/12/05 ZCZL.WANGMING UPDATE 0.3.000.011:仕様変更：IT_GKB_00717対応
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.012:品質強化：IT_GKB_1031対応
--  2024/12/13 JPJYS.GONGYANYAN 0.3.000.013:　仕様変更：IT_GKB_00722対応
--  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.014:品質強化：IT_GKB_10091対応
--  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.015:品質強化：IT_GKB_10092対応
--  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.016:品質強化：IT_GKB_10093対応
--  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.017:品質強化：IT_GKB_10094対応
--  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.018:品質強化：IT_GKB_10095対応
--  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.019:品質強化：IT_GKB_10096対応
--  2025/07/18 CTC.HJF UPDATE 1.0.010.001:GKB_QA17896対応
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
--------------------------------------------------------
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
    g_cCHOHYOKBN                  CHAR(2);                     --帳票区分
    g_sKOINFILENAME               NVARCHAR2(300);              --公印
    g_sNINSHOSHA                  NVARCHAR2(40);               --首長名
    g_nNKOJIN_NO                   NVARCHAR2(300);              -- 宛名番号
    g_nRIREKIBAN                  NVARCHAR2(300);              -- 特記事項
    g_nCHOHYOKBN                  NVARCHAR2(300);              -- 帳票区分
    g_nHAKKOBI                    NVARCHAR2(300);              -- 発行日
    g_sKYOIKUKAIMEI               NVARCHAR2(300);              -- 教育委員会
    g_sBUNSHOLIST                 NVARCHAR2(300);              -- 文書番号（リスト）
    g_nSHIENSOCHIKBN              NVARCHAR2(300);              -- 支援措置対象住所非表示
    g_nHAKKOSU                    NVARCHAR2(300);              -- 発行部数
    g_sNYUGAKKOMEI                NVARCHAR2(300);              -- 指定学校
    g_dCHOUSASHO                  NVARCHAR2(300);              -- 調査書提出期限
    g_NENDO                       NVARCHAR2(300);
--  2024/12/05 ZCZL.WANGMING ADD 0.3.000.011:仕様変更：IT_GKB_00717対応
    g_nKAITO_KIGEN                NVARCHAR2(300);              --回答期限
    g_sTOKUKIJIKO                 NVARCHAR2(300);              -- 特記事項
--  2024/10/28 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00404の対応    
    eOTHERS                       EXCEPTION;
    --パラメータ変数
    --i_nSORTKEY                    NUMBER;                      -- ソート順
    o_VYUBIN_NO                   NVARCHAR2(10);               -- 郵便番号
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
    --  作成者／作成日: ZCZL.Lvjq 2024/06/03
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
    --  作成者／作成日: ZCZL.Lvjq 2024/06/03
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/06/03
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
                WHEN 3 THEN
                     g_cCHOHYOKBN        := aCSV_TBL(i);         -- 帳票区分
                     FOR o IN 1..nCSV_CNT LOOP
                         IF (g_cCHOHYOKBN = '29' or g_cCHOHYOKBN = '30') THEN
                              CASE o
                              WHEN 1 THEN
                                   g_nNKOJIN_NO         := aCSV_TBL(o);         -- 宛名番号
                              WHEN 2 THEN
                                   g_nRIREKIBAN        := aCSV_TBL(o);         -- 履歴連番
                              WHEN 3 THEN
                                   g_nCHOHYOKBN        := aCSV_TBL(o);         -- 帳票区分
                              WHEN 4 THEN
                                   g_nHAKKOBI          := aCSV_TBL(o);         -- 発行日
                              WHEN 5 THEN
                                   g_sKYOIKUKAIMEI     := aCSV_TBL(o);         -- 教育委員会
                              WHEN 6 THEN
                                   g_sBUNSHOLIST       := aCSV_TBL(o);         -- 文書番号（リスト）
                              WHEN 7 THEN
                                   g_nSHIENSOCHIKBN    := aCSV_TBL(o);         -- 支援措置対象住所非表示
                              WHEN 8 THEN
                                   g_nHAKKOSU          := aCSV_TBL(o);         -- 発行部数
                              WHEN 9 THEN
                                   g_sNYUGAKKOMEI      := aCSV_TBL(o);         -- 指定学校
                              WHEN 10 THEN
                                   g_dCHOUSASHO        := aCSV_TBL(o);         -- 調査書提出期限
                              WHEN 11 THEN
                                   g_sTOKUKIJIKO       := aCSV_TBL(o);         -- 特記事項
                              ELSE
                                   NULL;
                              END CASE;
                         ELSIF (g_cCHOHYOKBN = '31' or g_cCHOHYOKBN = '32') THEN
                              CASE o
                              WHEN 1 THEN
                                   g_nNKOJIN_NO         := aCSV_TBL(o);         -- 宛名番号
                              WHEN 2 THEN
                                   g_nRIREKIBAN        := aCSV_TBL(o);         -- 履歴連番
                              WHEN 3 THEN
                                   g_nCHOHYOKBN        := aCSV_TBL(o);         -- 帳票区分
                              WHEN 4 THEN
                                   g_nHAKKOBI          := aCSV_TBL(o);         -- 発行日
                              WHEN 5 THEN
                                   g_sKYOIKUKAIMEI     := aCSV_TBL(o);         -- 教育委員会
                              WHEN 6 THEN
                                   g_sBUNSHOLIST       := aCSV_TBL(o);         -- 文書番号（リスト）
                              WHEN 7 THEN
                                   g_nSHIENSOCHIKBN    := aCSV_TBL(o);         -- 支援措置対象住所非表示
                              WHEN 8 THEN
                                   g_nHAKKOSU          := aCSV_TBL(o);         -- 発行部数
                              WHEN 9 THEN
                                   g_NENDO             := aCSV_TBL(o);         -- 年度
                              WHEN 10 THEN
--  2024/12/05 ZCZL.WANGMING UPDATE 0.3.000.011:仕様変更：IT_GKB_00717対応
--                                   g_sNYUGAKKOMEI      := aCSV_TBL(o);         -- 回答期限
                                   g_nKAITO_KIGEN      := aCSV_TBL(o);         -- 回答期限
                              WHEN 11 THEN
                                   g_sTOKUKIJIKO       := aCSV_TBL(o);         -- 特記事項
                              ELSE
                                   NULL;
                              END CASE;
                         END IF;
                     END LOOP;
                 ELSE
                      NULL;
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
    --  作成者／作成日: ZCZL.Lvjq 2024/06/03
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/06/03
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
    --  機能概要      : メインビジネスロジック処理
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --                : i_nCHOHYONUM    帳票番号
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_NEWMAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2,
                           i_nCHOHYONUM   IN NUMBER)
        RETURN BOOLEAN
    IS
        bRTN                   BOOLEAN;                        --戻る値
        nRTN                   NUMBER;                         --戻る値
        o_aPRM                 A_CONS_PRM;
        c_SHIMEIJKN_CHOHYO1    NUMBER;                         --健学校選択制案内書_インデックス番号
        c_SHIMEIJKN_CHOHYO2    NUMBER;                         --学校選択制調査書_インデックス番号
        c_EQSHIMEI1            NVARCHAR2(1000);                --健学校選択制案内書_出力制御
        c_EQSHIMEI2            NVARCHAR2(1000);                --学校選択制調査書_出力制御
        nDAIRIKBN              NUMBER;                         --認証者の本人・代理区分（0：通常、1;職務代理）
        sKATAGAKI1             NVARCHAR2(100);                 --認証者の肩書(二段表示用上段)
        sKATAGAKI2             NVARCHAR2(100);                 --認証者の肩書(二段表示用下段)
        sSHIMEI                NVARCHAR2(100);                 --認証者の氏名(首長、副首長等)
        aPARAMETER             A_CONS_PRM;
        nLENGTH                NUMBER(2);
        sTOIAWASE1             NVARCHAR2(1000);                --お問い合わせ先１
        sTOIAWASE2             NVARCHAR2(1000);                --お問い合わせ先２
        sTOIAWASE3             NVARCHAR2(1000);                --お問い合わせ先３
        rBUNNUMSRCINF          KKAPK0040.MR_BUNNUMSRCINF;      --文書番号情報（構造体）
        rBUNNUMEDITKEKA        KKAPK0040.MR_BUNNUMEDITKEKA;    --文書番号編集結果
        cBUNNUM                NVARCHAR2(1000);                --文書番号
        cKOFUDATE              NVARCHAR2(1000);                --発付年月日
        cKOJINNO               NVARCHAR2(1000);                --宛名番号
        cTSUSHOMEIKANA         NVARCHAR2(1000);                --通称名カナ
        cTSUSHOMEIKANJI        NVARCHAR2(1000);                --通称名
        cHOGOSYAKOJINNO        NVARCHAR2(1000);                --保護者宛名番号
        cHOGOSYATSUSHOMEIKANA  NVARCHAR2(1000);                --保護者通称名カナ
        cHOGOSYATSUSHOMEIKENJI NVARCHAR2(1000);                --保護者通称名
        cSHITEISYOGAKOCD       NUMBER;                         --就学指定校_小学校
        cSHITEITYUGAKOCD       NUMBER;                         --就学指定校_中学校
        cCHOHYOMEI             NVARCHAR2(1000);                --帳票名
        cKOINSHORYAKU          NVARCHAR2(1000);                --公印省略
        cKOINCHUSHAKU          NVARCHAR2(1000);                --公印注釈
        cTSUCHIBUN             NVARCHAR2(1000);                --通知文
        cTOKKIJIKO             NVARCHAR2(1000);                --特記事項
        cYOSHIKIBANGOSETTOGO   NVARCHAR2(1000);                --様式番号接頭語
        cYOSHIKIBANGO          NUMBER;                         --様式番号
        cYOSHIKIBANGOSETSUBIGO NVARCHAR2(1000);                --様式番号接尾語
        cnt                    NUMBER;
--  2024/09/30 ZCZL.WANGMING ADD 0.3.000.004:IT_GKB_00270、IT_GKB_00271対応
        sMEISHO                NVARCHAR2(100);
        rGKBWL700R001          GKBWL700R001%ROWTYPE;           --学校選択制案内書ワーク
        rGKBWL700R002          GKBWL700R002%ROWTYPE;           --学校選択制案内書ワーク
        RATENAKIHON_H          GABTATENAKIHON%ROWTYPE;
        RSOFUSAKI_H            GABTSOFUSAKI%ROWTYPE;
        RATENAKIHON_J          GABTATENAKIHON%ROWTYPE;
        RSOFUSAKI_J            GABTSOFUSAKI%ROWTYPE;
        vCHOMEI_BANCHI         NVARCHAR2(1000);                -- 住所マスク文字列
        nPRMCTL                NUMBER;
        sSQL1                  NVARCHAR2(4000);
        sSQL2                  NVARCHAR2(4000);
        rGKBWSENTAKUSEIREC     GKBWSENTAKUSEI%ROWTYPE;        --選択制対象者データ
        TYPE MC_CURSOR IS REF CURSOR;
        cCURSOR                MC_CURSOR;
        cCURSOR2               MC_CURSOR;
        dDATE1                 NUMBER;
--  2024/10/28 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00404の対応
        CURSOR cur_GAKUREIBO IS 
            SELECT KOJIN_NO                   --宛名番号
                   ,TSUSHOMEI_KANA            --通称名カナ
                   ,TSUSHOMEI_KANJI           --通称名
                   ,HOGOSYA_KOJIN_NO          --保護者宛名番号
                   ,HOGOSYA_TSUSHOMEI_KANA    --保護者通称名カナ
                   ,HOGOSYA_TSUSHOMEI_KANJI   --保護者通称名
                   ,SHITEI_SYOGAKO_CD         --就学指定校_小学校
                   ,SHITEI_TYUGAKO_CD         --就学指定校_中学校
            FROM   GKBTGAKUREIBO              --学齢簿
            WHERE  GKBTGAKUREIBO.KOJIN_NO = g_nNKOJIN_NO
            AND    GKBTGAKUREIBO.RIREKI_RENBAN = g_nRIREKIBAN; 
--  2024/10/28 ZCZL.WANGYUNING ADD END
        TYPE MR_TAISHOUJIDOU IS RECORD(
            KOJIN_NO                  NUMBER,                          --宛名番号
            SHUGAKUSHITEIKOU          NUMBER,                          --就学指定校
            GAKKOSHIKIBETSU           NVARCHAR2(5),                    --学校区識別番号
            GAKKO_KBN_CD              NUMBER,                          --学校区分コード
            RENBAN                    NUMBER,                          --連番
            GAKKOBLOCK_CD             NVARCHAR2(3)                     --学校ブロックコード
        );
        rTAISHOUJIDOU                 MR_TAISHOUJIDOU;                 --対象児童カーソル      
        TYPE MR_GKBFKGK IS RECORD(
            SENTAKUKANO_EDABAN        NUMBER,                          --選択可能学校枝番
            SENTAKUKANO_CD            NUMBER,                          --選択可能学校コード
            GAKKO_MEI                 NVARCHAR2(60),                   --選択可能学校名
            GAKKO_JUSHO               NVARCHAR2(300)                   --選択可能学校住所
        );
        rGKBFKGK                      MR_GKBFKGK;                      --学校カーソル
        cJIDO_JUSHO                   NVARCHAR2(1000);                 --住所編集取得
        vCHOMEICHI                    NVARCHAR2(300);
        sSHIMEIKANA                   NVARCHAR2(200);                  --氏名カナ
        svSHIMEI                       NVARCHAR2(200);                  --氏名漢字
        sBIRTHDAY                     NVARCHAR2(20);                   --生年月日
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.012:品質強化：IT_GKB_1031対応 Start
        sHOGOSHASHIMEIKANA                   NVARCHAR2(200);                  --保護者氏名カナ
        svHOGOSHASHIMEI                      NVARCHAR2(200);                  --保護者氏名漢字
        sHOGOSHABIRTHDAY                     NVARCHAR2(20);                   --保護者生年月日     
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.012:品質強化：IT_GKB_1031対応 End   
     
--  2024/11/22 ZCZL.WANGYUNING ADD 0.3.000.008:IT_GKB_00635対応
        vGEN_JUSHO                    rGKBWL700R001.GEN_JUSHO%TYPE;
        BEGIN
--  2024/09/24 ZCZL.WANGMING ADD START 0.3.000.003:仕様変更　IT_GKB_00007、IT_GKB_00008対応
        -- システム設定(KKATCT)から、制御パラメータ取得(KKAPK0030.FCTGetR)を使用して、「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する。
        o_aPRM := A_CONS_PRM();
        IF KKAPK0030.FCTGetR (i_sGYOUMUCODE, 'SHIMEIJKN_CHOHYO', '0000', 1 , o_aPRM) = 0 THEN
            -- 取得したリストから対象の帳票IDが格納されているインデックス番号を取得し、変数に設定する。
            FOR i IN 1..o_aPRM.COUNT LOOP
              IF o_aPRM(i) = 'GKB700R001' THEN
                c_SHIMEIJKN_CHOHYO1 := i;
                EXIT;
              END IF;
            END LOOP;
            FOR i IN 1..o_aPRM.COUNT LOOP
              IF o_aPRM(i) = 'GKB700R002' THEN
                c_SHIMEIJKN_CHOHYO2 := i;
                EXIT;
              END IF;
            END LOOP;
        END IF;
        -- システム設定(KKATCT)から、制御パラメータ取得(KKAPK0030.FCTGetR)を使用して「本名・通称名　出力制御」のリストを取得する。
        o_aPRM := A_CONS_PRM();
        IF KKAPK0030.FCTGetR (i_sGYOUMUCODE, 'EQSHIMEI', '0000', 0 , o_aPRM) = 0 THEN
            c_EQSHIMEI1 := o_aPRM(c_SHIMEIJKN_CHOHYO1);
            c_EQSHIMEI2 := o_aPRM(c_SHIMEIJKN_CHOHYO2);
        END IF;
--  2024/09/24 ZCZL.WANGMING ADD END
--  2024/10/28 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00404の対応            
        cnt := 0;
        -- 教育異動通知書（即時）CSVファイル作成
        -- 呼び出し元の帳票発行画面で選択した帳票が学校選択制案内書の場合
        IF g_cCHOHYOKBN = '29' OR g_cCHOHYOKBN = '30' THEN
            DELETE FROM GKBWL700R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
--  2024/09/24 ZCZL.WANGMING DELETE START 0.3.000.003:仕様変更　IT_GKB_00007、IT_GKB_00008対応
--            -- システム設定(KKATCT)から、制御パラメータ取得(KKAPK0030.FCTGetR)を使用して、「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する。
--            o_aPRM := A_CONS_PRM();
--            IF KKAPK0030.FCTGetR (i_sGYOUMUCODE, 'SHIMEIJKN_CHOHYO', '0000', 1 , o_aPRM) = 0 THEN
--                -- 取得したリストから対象の帳票IDが格納されているインデックス番号を取得し、変数に設定する。
--                FOR i IN 1..o_aPRM.COUNT LOOP
--                    IF o_aPRM(i) = 'GKB700R001' THEN
--                       c_SHIMEIJKN_CHOHYO1 := i;
--                       EXIT;
--                    ELSIF o_aPRM(i) = 'GKB700R002' THEN
--                       c_SHIMEIJKN_CHOHYO2 := i;
--                       EXIT;
--                    END IF;
--                END LOOP;
--            END IF;
--            -- システム設定(KKATCT)から、制御パラメータ取得(KKAPK0030.FCTGetR)を使用して「本名・通称名　出力制御」のリストを取得する。
--            o_aPRM := A_CONS_PRM();
--            IF KKAPK0030.FCTGetR (i_sGYOUMUCODE, 'EQSHIMEI', '0000', 0 , o_aPRM) = 0 THEN
--                c_EQSHIMEI1 := o_aPRM(c_SHIMEIJKN_CHOHYO1);
--                c_EQSHIMEI2 := o_aPRM(c_SHIMEIJKN_CHOHYO2);
--            END IF;
--  2024/09/24 ZCZL.WANGMING DELETE END
            -- 共通部品「公印ファイル名取得」（KKBPK5551.FNINSHOGet）より、公印情報を取得する。
            --首長情報の取得
            bRTN := KKBPK5551.FOPRTGet(i_sGYOUMUCODE, i_nCHOHYONUM, g_rOPRT);
            bRTN := KKBPK5551.FNINSHOGet (g_rOPRT.NINSHOCODE, g_sWSNUM, SYSDATE, nDAIRIKBN, sKATAGAKI1, sKATAGAKI2, sSHIMEI, g_sKOINFILENAME);
            g_sNINSHOSHA := sSHIMEI;    --首長名
            -- 教育委員会情報を取得する
            nRTN := KKAPK0030.FPRMSHUTOKU(i_sGYOUMUCODE, '00KYOIKUKAI', g_sKYOIKUKAIMEI, aPARAMETER, nLENGTH);
            -- 制御ﾊﾟﾗﾒｰﾀが存在する場合
            IF nRTN = 0 THEN
                -- 制御ﾊﾟﾗﾒｰﾀを取得する
                sTOIAWASE1 := aPARAMETER(1);
                sTOIAWASE2 := aPARAMETER(6);
                sTOIAWASE3 := aPARAMETER(7);
            END IF;
            -- 文書番号・発付年月日の取得、設定
            --文書番号情報取得
            rBUNNUMSRCINF := KKBPK5551.FBunNumInf (g_sBUNSHONUMLIST);
            --文書番号
            IF rBUNNUMSRCINF.UOUT.NUMUMUFLG = 0 THEN
                --文書入力画面で文書番号印字ありのとき設定
                cBUNNUM := rBUNNUMSRCINF.UOUT.NUM;
            ELSE
                cBUNNUM := NULL;
            END IF;
            --発付年月日
            IF rBUNNUMSRCINF.UOUT.DATEUMUFLG = 0 THEN
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.007:IT_GKB_00625対応
                --cKOFUDATE := rBUNNUMSRCINF.UOUT.DATEED;
                cKOFUDATE := rBUNNUMSRCINF.UOUT.BUNDATE;
            ELSE
                cKOFUDATE := NULL;
            END IF;
--  2024/10/28 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00404の対応
--            BEGIN
--                -- 初期化
--                cKOJINNO                := NULL;
--                cTSUSHOMEIKANA          := NULL;
--                cTSUSHOMEIKANJI         := NULL;
--                cHOGOSYAKOJINNO         := NULL;
--                cHOGOSYATSUSHOMEIKANA   := NULL;
--                cHOGOSYATSUSHOMEIKENJI  := NULL;
--                cSHITEISYOGAKOCD        := NULL;
--                cSHITEITYUGAKOCD        := NULL;
--                SELECT KOJIN_NO                   --宛名番号
--                       ,TSUSHOMEI_KANA            --通称名カナ
--                       ,TSUSHOMEI_KANJI           --通称名
--                       ,HOGOSYA_KOJIN_NO          --保護者宛名番号
--                       ,HOGOSYA_TSUSHOMEI_KANA    --保護者通称名カナ
--                       ,HOGOSYA_TSUSHOMEI_KANJI   --保護者通称名
--                       ,SHITEI_SYOGAKO_CD         --就学指定校_小学校
--                       ,SHITEI_TYUGAKO_CD         --就学指定校_中学校
--                INTO   cKOJINNO
--                       ,cTSUSHOMEIKANA
--                       ,cTSUSHOMEIKANJI
--                       ,cHOGOSYAKOJINNO
--                       ,cHOGOSYATSUSHOMEIKANA
--                       ,cHOGOSYATSUSHOMEIKENJI
--                       ,cSHITEISYOGAKOCD
--                       ,cSHITEITYUGAKOCD
--                FROM   GKBTGAKUREIBO              --学齢簿
--                WHERE  GKBTGAKUREIBO.KOJIN_NO = g_nNKOJIN_NO
--                AND    GKBTGAKUREIBO.RIREKI_RENBAN = g_nRIREKIBAN;
--                EXCEPTION
--                  WHEN OTHERS THEN
--                    cKOJINNO                := NULL;
--                    cTSUSHOMEIKANA          := NULL;
--                    cTSUSHOMEIKANJI         := NULL;
--                    cHOGOSYAKOJINNO         := NULL;
--                    cHOGOSYATSUSHOMEIKANA   := NULL;
--                    cHOGOSYATSUSHOMEIKENJI  := NULL;
--                    cSHITEISYOGAKOCD        := NULL;
--                    cSHITEITYUGAKOCD        := NULL;
--
--                IF cKOJINNO = NULL THEN
--                    bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 1, 0, SQLCODE, SQLERRM, '異常終了');
--                    RETURN FALSE;
--                END IF;
--            END;
            FOR r_GAKUREIBO IN cur_GAKUREIBO LOOP
              cKOJINNO                       := r_GAKUREIBO.KOJIN_NO;                  --宛名番号
              cTSUSHOMEIKANA                 := r_GAKUREIBO.TSUSHOMEI_KANA;            --通称名カナ  
              cTSUSHOMEIKANJI                := r_GAKUREIBO.TSUSHOMEI_KANJI;           --通称名
              cHOGOSYAKOJINNO                := r_GAKUREIBO.HOGOSYA_KOJIN_NO;          --保護者宛名番号
              cHOGOSYATSUSHOMEIKANA          := r_GAKUREIBO.HOGOSYA_TSUSHOMEI_KANA;    --保護者通称名カナ
              cHOGOSYATSUSHOMEIKENJI         := r_GAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI;   --保護者通称名
              cSHITEISYOGAKOCD               := r_GAKUREIBO.SHITEI_SYOGAKO_CD;         --就学指定校_小学校
              cSHITEITYUGAKOCD               := r_GAKUREIBO.SHITEI_TYUGAKO_CD;         --就学指定校_中学校
--  2024/10/28 ZCZL.WANGYUNING UPDATE END
            BEGIN
                -- 初期化
                cCHOHYOMEI                     := NULL;
                cKOINSHORYAKU                  := NULL;
                cKOINCHUSHAKU                  := NULL;
                cTSUCHIBUN                     := NULL;
                cTOKKIJIKO                     := NULL;
                cYOSHIKIBANGOSETTOGO           := NULL;
                cYOSHIKIBANGO                  := NULL;
                cYOSHIKIBANGOSETSUBIGO         := NULL;
                SELECT KANRI.CHOHYO_MEI                     --帳票名
                       ,KANRI.KOIN_SHORYAKU                 --公印省略
                       ,KANRI.KOIN_CHUSHAKU                 --公印注釈
                       ,KANRI.TSUCHIBUN                     --通知文
                       ,KANRI.TOKKIJIKO                     --特記事項
                       ,KANRI.YOSHIKI_BANGO_SETTOGO         --様式番号接頭語
                       ,KANRI.YOSHIKI_BANGO                 --様式番号
                       ,KANRI.YOSHIKI_BANGO_SETSUBIGO       --様式番号接尾語
                INTO   cCHOHYOMEI
                       ,cKOINSHORYAKU
                       ,cKOINCHUSHAKU
                       ,cTSUCHIBUN
                       ,cTOKKIJIKO
                       ,cYOSHIKIBANGOSETTOGO
                       ,cYOSHIKIBANGO
                       ,cYOSHIKIBANGOSETSUBIGO
                FROM   GKBTTSUCHISHOKANRI KANRI          --通知書管理
                WHERE  KANRI.CHOHYO_KBN = g_cCHOHYOKBN;
                EXCEPTION
                  WHEN OTHERS THEN
                    cCHOHYOMEI                     := NULL;
                    cKOINSHORYAKU                  := NULL;
                    cKOINCHUSHAKU                  := NULL;
                    cTSUCHIBUN                     := NULL;
                    cTOKKIJIKO                     := NULL;
                    cYOSHIKIBANGOSETTOGO           := NULL;
                    cYOSHIKIBANGO                  := NULL;
                    cYOSHIKIBANGOSETSUBIGO         := NULL;
            END;
            BEGIN
                -- 初期化
                dDATE1               := NULL;
                IF g_cCHOHYOKBN = 30 THEN
                    BEGIN
                    SELECT JKN.DATE1                            --日付１
                    INTO   dDATE1
                    FROM   GKBTTSUCHISHOJKN JKN              --通知書条件
                    WHERE  JKN.CHOHYO_KBN = g_cCHOHYOKBN
                    AND    JKN.GAKO_CD = cSHITEITYUGAKOCD
                    AND    JKN.GAKO_CD > 0;
                    EXCEPTION
                      WHEN OTHERS THEN
                        dDATE1           := NULL;
                    END;
                ELSIF g_cCHOHYOKBN = 29 THEN
                    BEGIN
                    SELECT JKN.DATE1                            --日付１
                    INTO   dDATE1
                    FROM   GKBTTSUCHISHOJKN JKN              --通知書条件
                    WHERE  JKN.CHOHYO_KBN = g_cCHOHYOKBN
                    AND    JKN.GAKO_CD = cSHITEISYOGAKOCD
                    AND    JKN.GAKO_CD > 0;
                    EXCEPTION
                      WHEN OTHERS THEN
                        dDATE1           := NULL;
                    END;
                END IF;
            END;

            rGKBWL700R001  := NULL;
--  2024/10/28 ZCZL.WANGYUNING DELETE 0.3.000.005:IT_GKB_00404の対応            
            --cnt := 0;
            -- ソート順
            --rGKBWL700R001.NO  := cnt;
--  2024/10/28 ZCZL.WANGYUNING DELETE END
            -- 保護者宛名情報
            --宛名情報取得２（GAAPK0030.FGETATENA2）より保護者の宛名情報を取得する
            nRTN := GAAPK0030.FGETATENA2(cHOGOSYAKOJINNO
                                       ,i_sGYOUMUCODE
                                       ,g_nHAKKOBI
                                       ,RATENAKIHON_H
                                       ,RSOFUSAKI_H);
                                               
            --児童生徒宛名情報
            --宛名情報取得（GAAPK0030.FGETATENA）より児童の宛名情報を取得する
            nRTN := GAAPK0030.FGETATENA(cKOJINNO
                                      ,i_sGYOUMUCODE
                                      ,g_nHAKKOBI
                                      ,RATENAKIHON_J
                                      ,RSOFUSAKI_J);

            -- 宛先郵便番号
            IF RSOFUSAKI_H.YUBIN_NO IS NOT NULL THEN
                --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.015:品質強化：IT_GKB_10092対応　START
                --IF KKAPK0010.FYUBINHENSHU(RSOFUSAKI_H.YUBIN_NO, o_vYUBIN_NO) = 0 THEN
                --    rGKBWL700R001.ATESAKI_YUBIN_NO  := o_vYUBIN_NO;
                --END IF;
                  nRTN := KKAPK0010.FYUBINHENSHU(RSOFUSAKI_H.YUBIN_NO, o_vYUBIN_NO);
                  rGKBWL700R001.ATESAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(o_vYUBIN_NO,0);
                --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.015:品質強化：IT_GKB_10092対応　END
            END IF;
            -- カスタマバーコード
            rGKBWL700R001.BC_NO  := RSOFUSAKI_H.Yubin_Nobc;
            -- 学齢簿.保護者宛名番号でDV判定を行い、
            vCHOMEICHI                           := GAAPK0010.FADDRESSEDIT( 1, '',  RSOFUSAKI_H.CHOMEI ,RSOFUSAKI_H.BANCHI, '', '');
            rGKBWL700R001.ATESAKI_CHOMEI_BANCHI  := vCHOMEICHI;
            --rGKBWL700R001.ATESAKI_KATAGAKI       := RSOFUSAKI_H.YUBIN_NO;           -- 宛先方書
            rGKBWL700R001.ATESAKI_KATAGAKI       := RSOFUSAKI_H.KATAGAKI;           -- 宛先方書
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
            -- vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO(i_sGYOUMUCODE,cKOJINNO,g_sTANTOCODE,g_sWSNUM,vCHOMEICHI,nPRMCTL,2);
            -- 引数.支援措置対象住所非表示＝１(有)の場合
            IF g_nSHIENSOCHIKBN = '1' THEN
                -- 抑止レベル３制御の要否＝’1’(該当)の場合
                -- IF nPRMCTL = '1' THEN
                    vCHOMEI_BANCHI := GKBPK00010.FGETJUSHOMSG();
                    rGKBWL700R001.ATESAKI_CHOMEI_BANCHI  := vCHOMEI_BANCHI;
                    rGKBWL700R001.ATESAKI_KATAGAKI       := NULL;         -- 宛先方書
                    --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.016:品質強化：IT_GKB_10093対応 START
                    rGKBWL700R001.ATESAKI_YUBIN_NO       := NULL;   -- 宛先郵便番号
                    rGKBWL700R001.BC_NO                  := NULL;   -- カスタマバーコード
                    --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.016:品質強化：IT_GKB_10093対応 END
                -- END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
            END IF;
            -- 宛先
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.012:品質強化：IT_GKB_1031対応 Start            
            nRTN := GKBFKHMCTRL(cKOJINNO, i_sCHOHYOID, 1, c_EQSHIMEI2, sHOGOSHASHIMEIKANA, svHOGOSHASHIMEI, sHOGOSHABIRTHDAY);
            --rGKBWL700R001.ATESAKI  := RSOFUSAKI_H.SHIMEI_KANJI || '　' || '様';
            rGKBWL700R001.ATESAKI  := svHOGOSHASHIMEI || '　' || '様';
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.012:品質強化：IT_GKB_1031対応 End       
            -- 文書番号
            rGKBWL700R001.BUNSHO_NO  := cBUNNUM;
            -- 送付日
-- 2024/09/04 ZCZL.caiqiushi Update start 0.3.000.002:8月1日認識合わせの横展開
--            rGKBWL700R001.SOFUBI  := KKAPK0020.FDateFmt(TO_CHAR(g_nHAKKOBI,'YYYY/MM/DD'), 10);
            --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.014:品質強化：IT_GKB_10091対応　START   
            --rGKBWL700R001.SOFUBI  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(cKOFUDATE, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10);
            rGKBWL700R001.SOFUBI  := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(cKOFUDATE, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10),' ',''));
            --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.014:品質強化：IT_GKB_10091対応　END
-- 2024/09/04 ZCZL.caiqiushi Update end
            -- 教育委員会名
            rGKBWL700R001.KYOIKU_KAI_MEI  := sKATAGAKI1;
            -- 教育長名
            rGKBWL700R001.KYOIKU_CHO_MEI  := g_sNINSHOSHA;
            -- 公印パス
            rGKBWL700R001.KOIN_PATH  := g_sKOINFILENAME;
            IF g_sKOINFILENAME IS NULL THEN
                -- 公印（省略）
                rGKBWL700R001.KOIN_SHORYAKU  := cKOINSHORYAKU;
                -- 公印（注釈）
                rGKBWL700R001.KOIN_CHUSHAKU  := NULL;
            ELSE
                -- 公印（省略）
                rGKBWL700R001.KOIN_SHORYAKU  := NULL;
                -- 公印（注釈）
                rGKBWL700R001.KOIN_CHUSHAKU  := cKOINCHUSHAKU;
            END IF;
            -- タイトル
            rGKBWL700R001.TITLE  := cCHOHYOMEI;
            -- 通知文
            rGKBWL700R001.TSUCHI_BUN  := REPLACE(cTSUCHIBUN, chr(13) || chr(10), '#');
            nRTN := GKBFKHMCTRL(cKOJINNO, 
                                i_sCHOHYOID, 
                                0, 
                                c_EQSHIMEI1, 
                                sSHIMEIKANA, 
                                svSHIMEI, 
                                sBIRTHDAY);
            -- 児童生徒氏名カナ
            rGKBWL700R001.JIDO_SHIMEI_KANA  := sSHIMEIKANA;
            -- 児童生徒氏名漢字
            rGKBWL700R001.JIDO_SHIMEI_KANJI  := svSHIMEI;
            -- 表示生年月日
            rGKBWL700R001.HYOJI_SEINENGAPI  := sBIRTHDAY;
--  2024/11/22 ZCZL.WANGYUNING ADD 0.3.000.008:IT_GKB_00635対応
--  2024/11/29 ZCZL.WANGYUNING UPDATE START 0.3.000.010:IT_GKB_00685対応
            --vGEN_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, RATENAKIHON_J.CHOMEI, RATENAKIHON_J.BANCHI, RATENAKIHON_J.KATAGAKI, NULL);
            rGKBWL700R001.GEN_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, RATENAKIHON_J.CHOMEI, RATENAKIHON_J.BANCHI, RATENAKIHON_J.KATAGAKI, NULL);
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
            -- vGEN_JUSHO := GAAPK0030.FDVJUSHO(i_sGYOUMUCODE, cKOJINNO, g_sTANTOCODE, g_sWSNUM, rGKBWL700R001.GEN_JUSHO, nPRMCTL, 2);
--  2024/11/29 ZCZL.WANGYUNING UPDATE END  
            IF g_nSHIENSOCHIKBN = '1' THEN
                    vGEN_JUSHO := GKBPK00010.FGETJUSHOMSG();
                -- 抑止レベル３制御の要否＝’1’(該当)の場合
                -- IF nPRMCTL = '1' THEN
                    -- 抑止住所編集
--  2024/11/22 ZCZL.WANGYUNING UPDATE 0.3.000.008:IT_GKB_00635対応
                    --rGKBWL700R001.GEN_JUSHO := GAAPK0030.FDVJUSHO(i_sGYOUMUCODE, cKOJINNO, g_sTANTOCODE, g_sWSNUM, rGKBWL700R001.GEN_JUSHO, nPRMCTL, 2);
--  2024/11/29 ZCZL.WANGYUNING UPDATE 0.3.000.010:IT_GKB_00685対応
                    --rGKBWL700R001.GEN_JUSHO := GAAPK0030.FDVJUSHO(i_sGYOUMUCODE, cKOJINNO, g_sTANTOCODE, g_sWSNUM, vGEN_JUSHO, nPRMCTL, 2);
                    rGKBWL700R001.GEN_JUSHO := vGEN_JUSHO;
                -- END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
--  2024/11/29 ZCZL.WANGYUNING DELETE 0.3.000.010:IT_GKB_00685対応
            --ELSE
--  2024/11/22 ZCZL.WANGYUNING UPDATE START 0.3.000.008:IT_GKB_00635対応
                -- 児童生徒現住所
                --rGKBWL700R001.GEN_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, RATENAKIHON_J.CHOMEI, RATENAKIHON_J.BANCHI, RATENAKIHON_J.KATAGAKI, NULL);
--  2024/11/29 ZCZL.WANGYUNING DELETE 0.3.000.010:IT_GKB_00685対応
                --rGKBWL700R001.GEN_JUSHO := vGEN_JUSHO;
--  2024/11/22 ZCZL.WANGYUNING UPDATE END
            END IF;
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.012:品質強化：IT_GKB_1031対応 Start             
            --nRTN := GKBFKHMCTRL(cKOJINNO, i_sCHOHYOID, 1, c_EQSHIMEI2, sSHIMEIKANA, svSHIMEI, sBIRTHDAY);
            -- 保護者氏名カナ
            --rGKBWL700R001.HOGOSHA_SHIMEI_KANA  := sSHIMEIKANA;
            rGKBWL700R001.HOGOSHA_SHIMEI_KANA  := sHOGOSHASHIMEIKANA;
            -- 保護者氏名漢字
            --rGKBWL700R001.HOGOSHA_SHIMEI_KANJI  := svSHIMEI;
            rGKBWL700R001.HOGOSHA_SHIMEI_KANJI  := svHOGOSHASHIMEI;
            -- 選択可能学校
            rGKBWL700R001.SHITEIKO_MEI  := g_sNYUGAKKOMEI;
            -- 調査書提出期限
            --  2024/12/13 JPJYS.GONGYANYAN 0.3.000.013:　仕様変更：IT_GKB_00722対応　STR
            -- rGKBWL700R001.TEISHUTSU_KIGEN  := dDATE1;
            --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.014:品質強化：IT_GKB_10091対応　START
            --rGKBWL700R001.TEISHUTSU_KIGEN := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(g_dCHOUSASHO),12);
            rGKBWL700R001.TEISHUTSU_KIGEN := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(g_dCHOUSASHO),10),' ',''));
            --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.014:品質強化：IT_GKB_10091対応　END
            --  2024/12/13 JPJYS.GONGYANYAN 0.3.000.013:　仕様変更：IT_GKB_00722対応　END
            -- 特記事項
            rGKBWL700R001.TOKKI_JIKO  := REPLACE(g_sTOKUKIJIKO, chr(13) || chr(10), '#');
            -- お問い合わせ先１
            rGKBWL700R001.TOIAWASESAKI1  := sTOIAWASE1;
            -- お問い合わせ先２
            rGKBWL700R001.TOIAWASESAKI2  := sTOIAWASE2;
            -- お問い合わせ先３
            rGKBWL700R001.TOIAWASESAKI3  := sTOIAWASE3;
            -- 様式番号
            rGKBWL700R001.YOSHIKI_NO  := cYOSHIKIBANGOSETTOGO || cYOSHIKIBANGO || cYOSHIKIBANGOSETSUBIGO;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
            rGKBWL700R001.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL700R001.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
            -- 改ページキー
            rGKBWL700R001.BREAK_NO  := NULL;
            -- 端末番号
            rGKBWL700R001.WSNUM  := g_sWSNUM;
            -- 即時バッチ区分
            rGKBWL700R001.BATCHKBN  := c_ONLINE;
            -- ジョブNO
            rGKBWL700R001.JOBNUM  := g_nJOBNUM;
            -- ワークテーブル登録
            FOR i IN 1..g_nHAKKOSU LOOP
--  2024/10/28 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00404の対応
                cnt := cnt + 1;
                -- ソート順
                rGKBWL700R001.NO  := cnt;
--  2024/10/28 ZCZL.WANGYUNING ADD END
                -- ワークテーブルへ出力する
                INSERT INTO GKBWL700R001 VALUES rGKBWL700R001;
            END LOOP;
--  2024/10/28 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00404の対応
            END LOOP;
            IF cnt = 0 THEN
                RAISE eOTHERS;
            END IF;
--  2024/10/28 ZCZL.WANGYUNING ADD END
        -- 3-2.学校選択制調査書小・中学校用ワーク(GKBWL700R002)にセットする。
        ELSIF g_cCHOHYOKBN = '31' OR g_cCHOHYOKBN = '32' THEN
            DELETE FROM GKBWL700R002 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
            -- ①.公印情報を取得する
            -- 共通部品「公印ファイル名取得」（KKBPK5551.FNINSHOGet）より、公印情報を取得する。
            bRTN := KKBPK5551.FOPRTGet(i_sGYOUMUCODE, i_nCHOHYONUM, g_rOPRT);            
            IF bRTN THEN
                -- 共通部品「公印ファイル名取得」（KKBPK5551.FNINSHOGet）より、公印情報を取得する。
                bRTN := KKBPK5551.FNINSHOGet (g_rOPRT.NINSHOCODE, g_sWSNUM, SYSDATE, nDAIRIKBN, sKATAGAKI1, sKATAGAKI2, sSHIMEI, g_sKOINFILENAME);
                g_sNINSHOSHA := sSHIMEI;    --首長名
            END IF;
            -- ④.文書番号・発付年月日の取得、設定
            --文書番号情報取得
            rBUNNUMSRCINF := KKBPK5551.FBunNumInf (g_sBUNSHONUMLIST);
            rBUNNUMEDITKEKA := rBUNNUMSRCINF.UOUT;
            --文書番号
            IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
                --文書入力画面で文書番号印字ありのとき設定
                cBUNNUM := rBUNNUMEDITKEKA.NUM;
            ELSE
                cBUNNUM := NULL;
            END IF;
            --発付年月日
            IF rBUNNUMEDITKEKA.DATEUMUFLG = 0 THEN
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.007:IT_GKB_00625対応
                --cKOFUDATE := rBUNNUMEDITKEKA.DATEED;
                cKOFUDATE := rBUNNUMEDITKEKA.BUNDATE;
            ELSE
                cKOFUDATE := NULL;
            END IF;
--  2024/10/28 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00404の対応
--            BEGIN
--                -- 初期化
--                cKOJINNO                := NULL;
--                cTSUSHOMEIKANA          := NULL;
--                cTSUSHOMEIKANJI         := NULL;
--                cHOGOSYAKOJINNO         := NULL;
--                cHOGOSYATSUSHOMEIKANA   := NULL;
--                cSHITEISYOGAKOCD        := NULL;
--                cSHITEITYUGAKOCD        := NULL;
--                
--                SELECT KOJIN_NO                   --宛名番号
--                       ,TSUSHOMEI_KANA            --通称名カナ
--                       ,TSUSHOMEI_KANJI           --通称名
--                       ,HOGOSYA_KOJIN_NO          --保護者宛名番号
--                       ,HOGOSYA_TSUSHOMEI_KANA    --保護者通称名
--                       ,SHITEI_SYOGAKO_CD         --就学指定校_小学校
--                       ,SHITEI_TYUGAKO_CD         --就学指定校_中学校
--                INTO   cKOJINNO
--                       ,cTSUSHOMEIKANA
--                       ,cTSUSHOMEIKANJI
--                       ,cHOGOSYAKOJINNO
--                       ,cHOGOSYATSUSHOMEIKANA
--                       ,cSHITEISYOGAKOCD
--                       ,cSHITEITYUGAKOCD
--                FROM   GKBTGAKUREIBO              --学齢簿
--                WHERE  GKBTGAKUREIBO.KOJIN_NO = g_nNKOJIN_NO
--                AND    GKBTGAKUREIBO.RIREKI_RENBAN = g_nRIREKIBAN;
--                EXCEPTION
--                  WHEN OTHERS THEN
--                    cKOJINNO                := NULL;
--                    cTSUSHOMEIKANA          := NULL;
--                    cTSUSHOMEIKANJI         := NULL;
--                    cHOGOSYAKOJINNO         := NULL;
--                    cHOGOSYATSUSHOMEIKANA   := NULL;
--                    cHOGOSYATSUSHOMEIKENJI  := NULL;
--                    cSHITEISYOGAKOCD        := NULL;
--                    cSHITEITYUGAKOCD        := NULL;
--                IF cKOJINNO = NULL THEN
--                    bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 1, 0, SQLCODE, SQLERRM, '異常終了');
--                    RETURN FALSE;
--                END IF;
--            END;
            FOR r_GAKUREIBO IN cur_GAKUREIBO LOOP  
              cKOJINNO                       := r_GAKUREIBO.KOJIN_NO;                  --宛名番号
              cTSUSHOMEIKANA                 := r_GAKUREIBO.TSUSHOMEI_KANA;            --通称名カナ  
              cTSUSHOMEIKANJI                := r_GAKUREIBO.TSUSHOMEI_KANJI;           --通称名
              cHOGOSYAKOJINNO                := r_GAKUREIBO.HOGOSYA_KOJIN_NO;          --保護者宛名番号
              cHOGOSYATSUSHOMEIKANA          := r_GAKUREIBO.HOGOSYA_TSUSHOMEI_KANA;    --保護者通称名カナ
              cHOGOSYATSUSHOMEIKENJI         := r_GAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI;   --保護者通称名
              cSHITEISYOGAKOCD               := r_GAKUREIBO.SHITEI_SYOGAKO_CD;         --就学指定校_小学校
              cSHITEITYUGAKOCD               := r_GAKUREIBO.SHITEI_TYUGAKO_CD;         --就学指定校_中学校
--  2024/10/28 ZCZL.WANGYUNING UPDATE END
            BEGIN
                -- 初期化
                cCHOHYOMEI                     := NULL;
                cKOINSHORYAKU                  := NULL;
                cKOINCHUSHAKU                  := NULL;
                cTSUCHIBUN                     := NULL;
                cTOKKIJIKO                     := NULL;
                cYOSHIKIBANGOSETTOGO           := NULL;
                cYOSHIKIBANGO                  := NULL;
                cYOSHIKIBANGOSETSUBIGO         := NULL;
                SELECT KANRI.CHOHYO_MEI                     --帳票名
                       ,KANRI.KOIN_SHORYAKU                 --公印省略
                       ,KANRI.KOIN_CHUSHAKU                 --公印注釈
                       ,KANRI.TSUCHIBUN                     --通知文
                       ,KANRI.TOKKIJIKO                     --特記事項
                       ,KANRI.YOSHIKI_BANGO_SETTOGO         --様式番号接頭語
                       ,KANRI.YOSHIKI_BANGO                 --様式番号
                       ,KANRI.YOSHIKI_BANGO_SETSUBIGO       --様式番号接尾語
                INTO   cCHOHYOMEI
                       ,cKOINSHORYAKU
                       ,cKOINCHUSHAKU
                       ,cTSUCHIBUN
                       ,cTOKKIJIKO
                       ,cYOSHIKIBANGOSETTOGO
                       ,cYOSHIKIBANGO
                       ,cYOSHIKIBANGOSETSUBIGO
                FROM   GKBTTSUCHISHOKANRI KANRI          --通知書管理
                WHERE  KANRI.CHOHYO_KBN = g_cCHOHYOKBN;
                EXCEPTION
                  WHEN OTHERS THEN
                    cCHOHYOMEI                     := NULL;
                    cKOINSHORYAKU                  := NULL;
                    cKOINCHUSHAKU                  := NULL;
                    cTSUCHIBUN                     := NULL;
                    cTOKKIJIKO                     := NULL;
                    cYOSHIKIBANGOSETTOGO           := NULL;
                    cYOSHIKIBANGO                  := NULL;
                    cYOSHIKIBANGOSETSUBIGO         := NULL;
            END;
            BEGIN
                -- 初期化
                dDATE1               := NULL;
                IF g_cCHOHYOKBN = 32 THEN
                    BEGIN
                    SELECT JKN.DATE1                            --日付１
                    INTO   dDATE1
                    FROM   GKBTTSUCHISHOJKN JKN              --通知書条件
                    WHERE  JKN.CHOHYO_KBN = g_cCHOHYOKBN
                    AND    JKN.GAKO_CD = cSHITEITYUGAKOCD
                    AND    cSHITEITYUGAKOCD > 0;
                    EXCEPTION
                      WHEN OTHERS THEN
                           dDATE1                := NULL;
                    END;
                ELSIF g_cCHOHYOKBN = 31 THEN
                    BEGIN
                    SELECT JKN.DATE1                            --日付１
                    INTO   dDATE1
                    FROM   GKBTTSUCHISHOJKN JKN              --通知書条件
                    WHERE  JKN.CHOHYO_KBN = g_cCHOHYOKBN
                    AND    JKN.GAKO_CD = cSHITEISYOGAKOCD
                    AND    cSHITEISYOGAKOCD > 0;
                    EXCEPTION
                      WHEN OTHERS THEN
                           dDATE1                := NULL;
                    END;
                END IF;
            END;
            
            -- ⑤.選択可能学校情報を取得する
            -- 1.学齢簿および、宛名基本、学区管理情報から学校ブロック等の情報を取得する。
            -- 取得項目、抽出条件等は「DB・ファイル等更新説明書（学校ブロック情報_S）」シート参照。
            sSQL1 := '';
            sSQL1 := 'SELECT';
            sSQL1 := sSQL1 || ' HON.KOJIN_NO';                    -- 宛名番号
            IF g_cCHOHYOKBN = '31' THEN
                sSQL1 := sSQL1 || ' ,SKO.SYOGAKO_CD';             -- 就学指定校
            ELSIF g_cCHOHYOKBN = '32' THEN
                sSQL1 := sSQL1 || ' ,CKO.TYUGAKO_CD';             -- 就学指定校
            END IF;
            sSQL1 := sSQL1 || ' ,KKU.GAKKOSHIKIBETSU';            -- 学校区識別番号
            sSQL1 := sSQL1 || ' ,KKU.GAKKO_KBN_CD';               -- 学校区分コード
            sSQL1 := sSQL1 || ' ,KKU.RENBAN';                     -- 連番
            sSQL1 := sSQL1 || ' ,KKU.GAKKOBLOCK_CD';              -- 学校ブロックコード
--  2024/09/30 ZCZL.WANGMING UPDATE START 0.3.000.004:IT_GKB_00270、IT_GKB_00271対応
--            sSQL1 := sSQL1 || ' FROM  GKBTSHOGAKKO    SKO,    ';  --小学校名
--            sSQL1 := sSQL1 || '       GKBTCHUGAKKO    CKO,    ';  --中学校名
            IF g_cCHOHYOKBN = '31' THEN
                sSQL1 := sSQL1 || ' FROM  GKBTSHOGAKKO    SKO,    ';  --小学校名
            ELSIF g_cCHOHYOKBN = '32' THEN
                sSQL1 := sSQL1 || ' FROM  GKBTCHUGAKKO    CKO,    ';  --中学校名
            END IF;
--  2024/09/30 ZCZL.WANGMING UPDATE END
            sSQL1 := sSQL1 || '       GKBTMSGAKKU     KKU,    ';  --学区管理情報
            sSQL1 := sSQL1 || '       GABTATENAKIHON  HON     ';  --宛名基本
            --事業所基本情報データ.事業所番号　=『事業所監査テーブル』「事業所番号」
            sSQL1 := sSQL1 || ' WHERE HON.KOJIN_NO = ''' || g_nNKOJIN_NO || '''';
            sSQL1 := sSQL1 || ' AND   KKU.SAISHIN_FLG = 0';
            sSQL1 := sSQL1 || ' AND   KKU.SAKUJO_FLG = 0';
            IF g_cCHOHYOKBN = '31' THEN
                sSQL1 := sSQL1 || ' AND   KKU.GAKKO_KBN_CD = 1';
                sSQL1 := sSQL1 || ' AND   SKO.GAKKOKU_CD(+) = KKU.GAKKOKU_CD';
                sSQL1 := sSQL1 || ' AND   SKO.SAKUJO_FLG(+) = 0';
            ELSIF g_cCHOHYOKBN = '32' THEN
                sSQL1 := sSQL1 || ' AND   KKU.GAKKO_KBN_CD = 2';
                sSQL1 := sSQL1 || ' AND   CKO.GAKKOKU_CD(+) = KKU.GAKKOKU_CD';
                sSQL1 := sSQL1 || ' AND   CKO.SAKUJO_FLG(+) = 0';
            END IF;
            o_aPRM := A_CONS_PRM();
            nRTN := KKAPK0030.FCTGetR (i_sGYOUMUCODE, '00GAKKU_KANRI', '0000', 0, o_aPRM);
            IF o_aPRM(1) = 0 THEN
                sSQL1 := sSQL1 || ' AND KKU.OAZA_CD     =  HON.OAZA_CD';
                sSQL1 := sSQL1 || ' AND KKU.HONBAN_FR  <=  HON.HONBAN';
                sSQL1 := sSQL1 || ' AND KKU.HONBAN_TO  >=  HON.HONBAN';
                sSQL1 := sSQL1 || ' AND KKU.EDABAN1_FR <=  HON.EDABAN1';
                sSQL1 := sSQL1 || ' AND KKU.EDABAN1_TO >=  HON.EDABAN1';
                sSQL1 := sSQL1 || ' AND KKU.EDABAN2_FR <=  HON.EDABAN2';
                sSQL1 := sSQL1 || ' AND KKU.EDABAN2_TO >=  HON.EDABAN2';
                sSQL1 := sSQL1 || ' AND KKU.EDABAN3_FR <=  HON.EDABAN3';
                sSQL1 := sSQL1 || ' AND KKU.EDABAN3_TO >=  HON.EDABAN3';
                sSQL1 := sSQL1 || ' AND KKU.GAIKU_FR   <=  HON.GAIKU';
                sSQL1 := sSQL1 || ' AND KKU.GAIKU_TO   >=  HON.GAIKU';
                sSQL1 := sSQL1 || ' AND KKU.TOU_FR     <=  HON.TOU';
                sSQL1 := sSQL1 || ' AND KKU.TOU_TO     >=  HON.TOU';
            END IF;
            IF o_aPRM(1) = 1 THEN
                sSQL1 := sSQL1 || ' AND KKU.GYOSEIKU_CD = HON.GYOSEIKU_CD';
            END IF;
        --対象児童カーソル
        OPEN cCURSOR FOR sSQL1;
--  2024/10/28 ZCZL.WANGYUNING DELETE 0.3.000.005:IT_GKB_00404の対応
        --cnt := 0;
        LOOP
            FETCH cCURSOR INTO rTAISHOUJIDOU;         
            EXIT WHEN cCURSOR%NOTFOUND;

            rGKBWL700R002  := NULL;

            --学校ブロック名取得
--  2024/09/30 ZCZL.WANGMING UPDATE START 0.3.000.004:IT_GKB_00270、IT_GKB_00271対応
--             FOR j IN (SELECT MEISHO
            BEGIN
                       SELECT MEISHO
                       INTO sMEISHO
                        FROM KKATCD
                       WHERE GYOUMUCODE = i_sGYOUMUCODE
--  2024/10/28 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00404の対応
                         --AND CODECODE   = '024'
                         AND trim(CODECODE)   = trim('024')
                         AND GROUPCODE  = '0001'
                         AND trim(ANYCODE) = trim(rTAISHOUJIDOU.GAKKOBLOCK_CD);
--             ) LOOP
            EXCEPTION
              WHEN OTHERS THEN
                sMEISHO := NULL;
            END;
                -- 2.変数.表示用選択可能学校を宣言し、補足説明書1の方法で取得できる学校ブロック名を設定する。
--                 rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO := j.MEISHO;
                rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO := sMEISHO;
--             END LOOP;
--  2024/09/30 ZCZL.WANGMING UPDATE END
            -- 3.就学指定校マスタから選択可能学校情報を取得し、選択可能学校カーソルを宣言する。
            -- 「DB・ファイル等更新説明書（選択可能学校カーソル_S）」シート参照。
            sSQL2 := '';
            sSQL2 :=  sSQL2 || ' SELECT KOU.SENTAKUKANO_EDABAN AS SENTAKUKANO_EDABAN,';
            sSQL2 :=  sSQL2 || '        KOU.SENTAKUKANO_CD     AS SENTAKUKANO_CD,';
--  2024/09/24 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00007、IT_GKB_00008対応
--            IF rTAISHOUJIDOU.GAKKO_KBN_CD = 1 THEN
            IF g_cCHOHYOKBN = '31' THEN
              sSQL2 :=  sSQL2 || '      SKO.SYOGAKOMEI         AS GAKKO_MEI,';
              sSQL2 :=  sSQL2 || '      SKO.JUSHO              AS GAKKO_JUSHO';
--  2024/09/24 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00007、IT_GKB_00008対応
--            ELSIF rTAISHOUJIDOU.GAKKO_KBN_CD = 2 THEN
            ELSIF g_cCHOHYOKBN = '32' THEN
              sSQL2 :=  sSQL2 || '      CKO.TYUGAKOMEI         AS GAKKO_MEI,';
              sSQL2 :=  sSQL2 || '      CKO.JUSHO              AS GAKKO_JUSHO';
            END IF;
            sSQL2 :=  sSQL2 || '   FROM GKBTMSSHUGAKUSHITEIKOU KOU,';
--  2024/09/24 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　IT_GKB_00007、IT_GKB_00008対応
--            sSQL2 :=  sSQL2 || '        GKBTSHOGAKKO           SKO,';
--            sSQL2 :=  sSQL2 || '        GKBTCHUGAKKO           CKO';
            IF g_cCHOHYOKBN = '31' THEN
              sSQL2 :=  sSQL2 || '        GKBTSHOGAKKO           SKO';
            ELSIF g_cCHOHYOKBN = '32' THEN
              sSQL2 :=  sSQL2 || '        GKBTCHUGAKKO           CKO';
            END IF;
--  2024/09/24 ZCZL.WANGMING UPDATE END
            sSQL2 :=  sSQL2 || '  WHERE KOU.SAISHIN_FLG        = 0';
            sSQL2 :=  sSQL2 || '    AND KOU.SAKUJO_FLG         = 0';
            sSQL2 :=  sSQL2 || '    AND KOU.GAKKOSHIKIBETSU    = ''' || rTAISHOUJIDOU.GAKKOSHIKIBETSU || '''';
--  2024/09/24 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　IT_GKB_00007、IT_GKB_00008対応
--            sSQL2 :=  sSQL2 || '    AND KOU.GAKKO_KBN_CD       = ''' || rTAISHOUJIDOU.GAKKO_KBN_CD || '''';
            IF g_cCHOHYOKBN = '31' THEN
              sSQL2 := sSQL2 || ' AND   KOU.GAKKO_KBN_CD = 1';
            ELSIF g_cCHOHYOKBN = '32' THEN
              sSQL2 := sSQL2 || ' AND   KOU.GAKKO_KBN_CD = 2';
            END IF;
--  2024/09/24 ZCZL.WANGMING UPDATE END
--  2024/09/24 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00007、IT_GKB_00008対応
--            IF rTAISHOUJIDOU.GAKKO_KBN_CD = 1 THEN
            IF g_cCHOHYOKBN = '31' THEN
              sSQL2 :=  sSQL2 || '  AND SKO.SAKUJO_FLG         = 0';
              sSQL2 :=  sSQL2 || '  AND SKO.SYOGAKO_CD         = KOU.SENTAKUKANO_CD';
            END IF;
--  2024/09/24 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00007、IT_GKB_00008対応
--            IF rTAISHOUJIDOU.GAKKO_KBN_CD = 2 THEN
            IF g_cCHOHYOKBN = '32' THEN
              sSQL2 :=  sSQL2 || '  AND CKO.SAKUJO_FLG         = 0';
              sSQL2 :=  sSQL2 || '  AND CKO.TYUGAKO_CD         = KOU.SENTAKUKANO_CD';
            END IF;
            OPEN cCURSOR2 FOR sSQL2;
            LOOP
                FETCH cCURSOR2 INTO rGKBFKGK;
--  2024/09/24 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　IT_GKB_00007、IT_GKB_00008対応
--                IF cCURSOR2%NOTFOUND THEN
--                  CLOSE cCURSOR2;
--                      continue;
--                END IF;
                EXIT WHEN cCURSOR2%NOTFOUND;
--  2024/09/24 ZCZL.WANGMING UPDATE END
                -- 4.選択可能学校カーソルを件数分ループさせる。
                -- 4-1.変数.表示用選択可能学校に以下を追記する。
                -- 変数.表示用選択可能学校 += '#(0x23)' + '　' + 選択可能学校カーソル.選択可能学校名 + '　　' + 選択可能学校カーソル.選択可能学校住所
--  2024/09/30 ZCZL.WANGMING UPDATE START 0.3.000.004:IT_GKB_00270、IT_GKB_00271対応
--                rGKBWL700R002.SENTAKUKANO_GAKKO := rGKBWL700R002.SENTAKUKANO_GAKKO || 
--                                                       REPLACE(rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO, chr(13) || chr(10), '#')  ||
--                                                       '　' || rGKBFKGK.GAKKO_MEI || '　' || rGKBFKGK.GAKKO_JUSHO;
--  2024/10/28 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00404の対応                
                --rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO := REPLACE(rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO, chr(13) || chr(10), '#')  ||
                --                                       '　' || rGKBFKGK.GAKKO_MEI || '　' || rGKBFKGK.GAKKO_JUSHO;
                rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO := rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO || '#'  ||
                                                       '　' || rGKBFKGK.GAKKO_MEI || '　　' || rGKBFKGK.GAKKO_JUSHO; 
--  2024/10/28 ZCZL.WANGYUNING UPDATE END                                                    
--  2024/09/30 ZCZL.WANGMING UPDATE END
            END LOOP;
--  2024/11/06 ZCZL.WANGYUNING ADD START 0.3.000.006:IT_GKB_00455の対応
            IF cCURSOR2%ISOPEN THEN
                CLOSE  cCURSOR2;
            END IF;
--  2024/11/06 ZCZL.WANGYUNING ADD END
--  2024/10/28 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00404の対応             
            END LOOP;
--  2024/09/30 ZCZL.WANGMING ADD 0.3.000.004:IT_GKB_00270、IT_GKB_00271対応
            rGKBWL700R002.SENTAKUKANO_GAKKO := rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO;
--  2024/09/04 ZCZL.caiqiushi ADD 0.3.000.002:8月1日認識合わせの横展開
--  2024/11/06 ZCZL.WANGYUNING DELETE 0.3.000.006:IT_GKB_00455の対応
            --CLOSE  cCURSOR2; 
--  2024/10/28 ZCZL.WANGYUNING DELETE 0.3.000.005:IT_GKB_00404の対応    
            -- -- ソート順
            --rGKBWL700R002.NO  := cnt;
            -- 保護者宛名情報
            --宛名情報取得２（GAAPK0030.FGETATENA2）より保護者の宛名情報を取得する
            nRTN := GAAPK0030.FGETATENA2( cHOGOSYAKOJINNO
                                       ,i_sGYOUMUCODE
                                       ,g_nHAKKOBI
                                       ,RATENAKIHON_H
                                       ,RSOFUSAKI_H);

            --児童生徒宛名情報
            --宛名情報取得（GAAPK0030.FGETATENA）より児童の宛名情報を取得する
            nRTN := GAAPK0030.FGETATENA( cKOJINNO
                                      ,i_sGYOUMUCODE
                                      ,g_nHAKKOBI
                                      ,RATENAKIHON_J
                                      ,RSOFUSAKI_J);

            -- 宛先郵便番号
            IF RSOFUSAKI_H.YUBIN_NO IS NOT NULL THEN
                nRTN := KKAPK0010.FYUBINHENSHU(RSOFUSAKI_H.YUBIN_NO, o_vYUBIN_NO);
                rGKBWL700R002.ATESAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(o_vYUBIN_NO,0);
            END IF;
            -- 宛先町名番地
            vCHOMEICHI                           := GAAPK0010.FADDRESSEDIT( 1, '',  RSOFUSAKI_H.CHOMEI ,RSOFUSAKI_H.BANCHI, '', '');
            rGKBWL700R002.ATESAKI_CHOMEI_BANCHI  := vCHOMEICHI;
            rGKBWL700R002.ATESAKI_KATAGAKI       := RSOFUSAKI_H.KATAGAKI;          -- 宛先方書
            -- カスタマバーコード
            rGKBWL700R002.BC_NO  := RSOFUSAKI_H.Yubin_Nobc;
            -- 引数.支援措置対象住所非表示＝１(有)の場合
            IF g_nSHIENSOCHIKBN = '1' THEN
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
                    cJIDO_JUSHO := GKBPK00010.FGETJUSHOMSG();
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.010:IT_GKB_00685対応

                -- cJIDO_JUSHO := GAAPK0030.FDVJUSHO(i_sGYOUMUCODE,cKOJINNO,g_sTANTOCODE,g_sWSNUM,vCHOMEICHI,nPRMCTL,2);
                -- 抑止レベル３制御の要否＝’1’(該当)の場合22
                -- IF nPRMCTL = '1' THEN
--  2024/11/29 ZCZL.WANGYUNING UPDATE START 0.3.000.010:IT_GKB_00685対応
                    --cJIDO_JUSHO := GAAPK0030.FDVJUSHO(i_sGYOUMUCODE,cKOJINNO,g_sTANTOCODE,g_sWSNUM,vCHOMEICHI,nPRMCTL,2);
                    ---- 学齢簿.保護者宛名番号でDV判定を行い、
                    --vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO(i_sGYOUMUCODE,RSOFUSAKI_H.KOJIN_NO,g_sTANTOCODE,g_sWSNUM,cJIDO_JUSHO,nPRMCTL,2);
                    rGKBWL700R002.ATESAKI_CHOMEI_BANCHI  := cJIDO_JUSHO;
--  2024/11/29 ZCZL.WANGYUNING UPDATE END
                    rGKBWL700R002.ATESAKI_KATAGAKI       := NULL;                  -- 宛先方書
                    --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.018:品質強化：IT_GKB_10095対応 START
                    rGKBWL700R002.ATESAKI_YUBIN_NO := NULL;  -- 宛先郵便番号
                    rGKBWL700R002.BC_NO  := NULL;            -- カスタマバーコード
                    --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.018:品質強化：IT_GKB_10095対応 END
                -- END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
            END IF;
            
            -- 文書番号
            rGKBWL700R002.BUNSHO_NO  := cBUNNUM;
            -- 送付日
-- 2024/09/04 ZCZL.caiqiushi Update start 0.3.000.002:8月1日認識合わせの横展開
--            rGKBWL700R002.SOFUBI  := KKAPK0020.FDateFmt(TO_CHAR(g_nHAKKOBI,'YYYY/MM/DD'), 10);
            --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.017:品質強化：IT_GKB_10094対応 START
            --rGKBWL700R002.SOFUBI  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(cKOFUDATE, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10);
            rGKBWL700R002.SOFUBI  := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(cKOFUDATE, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10),' ',''));
            --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.017:品質強化：IT_GKB_10094対応 END 
-- 2024/09/04 ZCZL.caiqiushi Update end
            -- 教育委員会名
            rGKBWL700R002.KYOIKU_KAI_MEI  := sKATAGAKI1;
            -- 教育長名
            rGKBWL700R002.KYOIKU_CHO_MEI  := g_sNINSHOSHA;
            -- 公印パス
            rGKBWL700R002.KOIN_PATH  := g_sKOINFILENAME;
--  2024/11/25 ZCZL.WANGYUNING UPDATE 0.3.000.009:IT_GKB_00528対応
            --IF g_sKOINFILENAME IS NOT NULL THEN
            IF g_sKOINFILENAME IS NULL THEN
                -- 公印（省略）
                rGKBWL700R002.KOIN_SHORYAKU  := cKOINSHORYAKU;
                -- 公印（注釈）
                rGKBWL700R002.KOIN_CHUSHAKU  := NULL;
            ELSE
                -- 公印（省略）
                rGKBWL700R002.KOIN_SHORYAKU  := NULL;
                -- 公印（注釈）
                rGKBWL700R002.KOIN_CHUSHAKU  := cKOINCHUSHAKU;
            END IF;
            -- 学校区分
            IF g_cCHOHYOKBN = '31' THEN
                rGKBWL700R002.GAKKO_KBN  := '1';
            ELSIF g_cCHOHYOKBN = '32' THEN
                rGKBWL700R002.GAKKO_KBN  := '2';
            END IF;
            -- タイトル
            rGKBWL700R002.TITLE  := cCHOHYOMEI;
            -- 通知文
            rGKBWL700R002.TSUCHI_BUN  := REPLACE(cTSUCHIBUN, chr(13) || chr(10), '#');
            -- 調査票タイトル
            IF g_cCHOHYOKBN = '31' THEN
                rGKBWL700R002.CHOSAHYO_TITLE  := '小学校希望調査票';
            ELSIF g_cCHOHYOKBN = '32' THEN
                rGKBWL700R002.CHOSAHYO_TITLE  := '中学校希望調査票';
            END IF;
            --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.019:品質強化：IT_GKB_10096対応 START
            -- 児童生徒氏名ラベル
            IF g_cCHOHYOKBN = '31' THEN
                rGKBWL700R002.JIDO_SHIMEI_LAB  := '児童氏名';
            ELSIF g_cCHOHYOKBN = '32' THEN
                rGKBWL700R002.JIDO_SHIMEI_LAB  := '生徒氏名';
            END IF;
            --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.019:品質強化：IT_GKB_10096対応 END
            nRTN := GKBFKHMCTRL(cKOJINNO, i_sCHOHYOID, 0, c_EQSHIMEI1, sSHIMEIKANA, svSHIMEI, sBIRTHDAY);
            -- 児童生徒氏名カナ
            rGKBWL700R002.JIDO_SHIMEI_KANA  := sSHIMEIKANA;
            -- 児童生徒氏名漢字
            rGKBWL700R002.JIDO_SHIMEI_KANJI  := svSHIMEI;
            -- 表示生年月日
            rGKBWL700R002.HYOJI_SEINENGAPI  := sBIRTHDAY;
            nRTN := GKBFKHMCTRL(cKOJINNO, i_sCHOHYOID, 1, c_EQSHIMEI2, sSHIMEIKANA, svSHIMEI, sBIRTHDAY);
            -- 保護者氏名カナ
            rGKBWL700R002.HOGOSHA_SHIMEI_KANA  := sSHIMEIKANA;
            -- 保護者氏名漢字
            rGKBWL700R002.HOGOSHA_SHIMEI_KANJI  := svSHIMEI;
            -- 宛先
            rGKBWL700R002.ATESAKI  := svSHIMEI || '　' || '様';
            -- 回答期限
--  2024/12/05 ZCZL.WANGMING UPDATE 0.3.000.011:仕様変更：IT_GKB_00717対応
--            rGKBWL700R002.KAITO_KIGEN  := dDATE1;
            --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.017:品質強化：IT_GKB_10094対応 START
            --rGKBWL700R002.KAITO_KIGEN := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(g_nKAITO_KIGEN),12);
            rGKBWL700R002.KAITO_KIGEN := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(g_nKAITO_KIGEN),10),' ',''));
            --  2024/12/19 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.017:品質強化：IT_GKB_10094対応 END
            -- 特記事項
            rGKBWL700R002.TOKKI_JIKO  := REPLACE(g_sTOKUKIJIKO, chr(13) || chr(10), '#');
            -- 様式番号
            rGKBWL700R002.YOSHIKI_NO  := cYOSHIKIBANGOSETTOGO || cYOSHIKIBANGO || cYOSHIKIBANGOSETSUBIGO;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
            rGKBWL700R002.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL700R002.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
            -- 改ページキー
            rGKBWL700R002.BREAK_NO  := NULL;
            -- 端末番号
            rGKBWL700R002.WSNUM  := g_sWSNUM;
            -- 即時バッチ区分
            rGKBWL700R002.BATCHKBN  := c_ONLINE;
            -- ジョブNO
            rGKBWL700R002.JOBNUM  := g_nJOBNUM;
            -- ワークテーブル登録
            FOR i IN 1..g_nHAKKOSU LOOP
--  2024/10/28 ZCZL.WANGYUNING DELETE 0.3.000.005:IT_GKB_00404の対応    
                cnt := cnt + 1;
                -- ソート順
                rGKBWL700R002.NO  := cnt;
                -- ワークテーブルへ出力する
                INSERT INTO GKBWL700R002 VALUES rGKBWL700R002;
            END LOOP;
            END LOOP;
--  2024/09/04 ZCZL.caiqiushi ADD 0.3.000.002:8月1日認識合わせの横展開
            CLOSE cCURSOR;
--  2024/10/28 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00404の対応
            IF cnt = 0 THEN
                RAISE eOTHERS;
            END IF;
--  2024/10/28 ZCZL.WANGYUNING ADD END
        END IF;
--  2024/10/28 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00404の対応
        IF cur_GAKUREIBO%ISOPEN THEN
            CLOSE cur_GAKUREIBO;
        END IF;
--  2024/10/28 ZCZL.WANGYUNING ADD END
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/09/04 ZCZL.caiqiushi ADD START 0.3.000.002:8月1日認識合わせの横展開
            IF cCURSOR%ISOPEN THEN
              CLOSE cCURSOR;
            END IF;
            IF cCURSOR2%ISOPEN THEN
              CLOSE cCURSOR2;
            END IF;
--  2024/09/04 ZCZL.caiqiushi ADD END
--  2024/10/28 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00404の対応
            IF cur_GAKUREIBO%ISOPEN THEN
              CLOSE cur_GAKUREIBO;
            END IF;
--  2024/10/28 ZCZL.WANGYUNING ADD END
            bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'CSV出力処理', 1, 0, SQLCODE, SQLERRM, '異常終了');
            RETURN FALSE;
    END FUNC_NEWMAIN;
    --------------------------------------------------------
    --  機能概要      : メインビジネスロジック処理
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --                : i_nCHOHYONUM    帳票番号
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2,
                           i_nCHOHYONUM   IN NUMBER)
        RETURN BOOLEAN
    IS
        bRTN                BOOLEAN;
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');
        -- メインビジネスロジック処理
        bRTN := FUNC_NEWMAIN(i_sGYOUMUCODE, i_sCHOHYOID, i_nCHOHYONUM);
--  2024/10/28 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00404の対応
        IF NOT bRTN THEN
            RAISE eOTHERS;
        END IF;
--  2024/10/28 ZCZL.WANGYUNING ADD END
        -- 帳票出力CSVの作成
        IF i_sCHOHYOID = 'GKB700R001' THEN
            bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL700R001', i_sCHOHYOID);
        ELSIF i_sCHOHYOID = 'GKB700R002' THEN
            bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL700R002', i_sCHOHYOID);
        END IF;
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
    --                : o_sMESSAGE           発行番号
    --                : o_sBUNSHONUM         文書番号
    --  戻り値        : なし
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/06/03
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
--  2024/11/06 ZCZL.WANGYUNING UPDATE START 0.3.000.006:IT_GKB_00455の対応
                      --o_sMESSAGE          OUT NVARCHAR2,
                      --o_sSETAICNT         OUT NVARCHAR2,
                      --o_sBUNSHONUM        OUT NVARCHAR2)
                      o_sMESSAGE          OUT NVARCHAR2)
--  2024/11/06 ZCZL.WANGYUNING UPDATE end                    
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

        -- 入力引数 業務コード、帳票番号、帳票IDを取得する。
        --引数の業務コード（リスト）の配列化
        aGYOUMUCODE := KKBPK5551.FSplitStr (i_sGYOUMUCODE_LIST);
        --引数の帳票番号（リスト）の配列化
        aCHOHYONUM := KKBPK5551.FSplitStr (i_sCHOHYONUM_LIST);
        --引数の帳票ID（リスト）の配列化
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
--  2024/08/02 ZCZL.yangshuai Add 0.3.000.001:検収指摘No.90の対応
            -- オンラインステップ処理パラメータ取得
            bRTN := FUNC_O02PINIT (aGYOUMUCODE(i), aCHOHYONUM(i));
            IF NOT bRTN THEN
                RAISE eSHORIEXCEPTION;
            END IF;
            --メイン処理
            IF i = 1 THEN
                bRTN := FUNC_O10MAIN (aGYOUMUCODE(i), aCHOHYOID(i), aCHOHYONUM(i));
                IF NOT bRTN THEN
                    o_sMESSAGE := g_sMESSAGE;
                    RAISE eSHORIEXCEPTION;
                END IF;
            ELSE
                bRTN := FUNC_O10MAIN (aGYOUMUCODE(i), KKBPK5551.c_CSVCOMBINATOR || aCHOHYOID(i), aCHOHYONUM(i));
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
--  2024/08/02 ZCZL.YANGSHUAI DELETE 0.3.000.001:検収指摘No.90の対応
--            dbms_output.put_line(sqlerrm);
            o_sCSVCNT_LIST := NULL;
            o_sCSVFILENAME_LIST := NULL;
            o_sPRTFILENAME_LIST := NULL;
            o_nRESULT := c_ERR;
            ROLLBACK;
    END PONLINE;
END GKBPA00190;
/