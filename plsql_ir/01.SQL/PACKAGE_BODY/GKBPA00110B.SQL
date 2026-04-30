CREATE OR REPLACE PACKAGE BODY GKBPA00110
--1.0.106.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 区域外就学満了通知書作成
--  機能概要      : 区域外就学満了通知書の即時帳票を印刷する場合に呼び出される。
--                  標準仕様の帳票レイアウトに合わせた項目を出力する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/06
--------------------------------------------------------
--  変更履歴
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.001:IT_GKB_00433対応  
--  2024/11/11 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00397仕様変更対応
--  2024/11/29 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00685横展開
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.004:仕様変更　IT_GKB_00728対応
--  2024/12/20 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:仕様変更　IT_GKB_10079,IT_GKB_10080対応
--  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.006:品質強化　IT_GKB_00120対応
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
--------------------------------------------------------
IS
    -- 全処理必須パラメータ
    c_ONLINE                      CONSTANT PLS_INTEGER := 1;   --オンライン
    c_OK                          CONSTANT PLS_INTEGER := 0;   --正常
    c_ERR                         CONSTANT PLS_INTEGER := -1;  --異常
    g_nJOBNUM                     NUMBER;                      --ジョブナンバー
    g_sTANTOCODE                  CHAR(12);                    --担当者コード
    g_sWSNUM                      NVARCHAR2(1000);             --端末番号
    g_sBUNSHONUMLIST              NVARCHAR2(1000);             --文書番号情報（リスト）
    g_sMESSAGE                    NVARCHAR2(4000);             --メッセージ返却用
    g_rOPRT                       KKATOPRT%ROWTYPE;            --オンラインジョブステップ情報
    g_sCSV_RCNT                   NVARCHAR2(1000);             --CSVファイル出力件数
    g_sCSVFILENAME                NVARCHAR2(1000);             --CSVファイル名
    g_sPRTFILENAME                NVARCHAR2(1000);             --印刷ファイル名
    g_sSTARTDATE                  NVARCHAR2(23);               --開始時刻
    c_EMF                         CONSTANT PLS_INTEGER := 1;   --印刷ファイル区分(EMF)
    c_PDF                         CONSTANT PLS_INTEGER := 2;   --印刷ファイル区分(PDF)
    c_EMFANDPDF                   CONSTANT PLS_INTEGER := 3;   --印刷ファイル区分(EMFとPDF)
    --パラメータ変数
    g_nCNT                        NUMBER := 0;                 --ソート順
    g_nKOJIN_NO                   NUMBER;                      --宛名番号
    g_nCHOHYOKBN                  NUMBER;                      --帳票区分
    g_sHAKKOBI                    NVARCHAR2(1000);             --発送日
    g_nNATESAKI                   NUMBER;                      --宛先
    g_nKYOIKUKAI                  NUMBER;                      --教育委員会
    g_sBUNSHOLIST                 NVARCHAR2(1000);             --文書番号（リスト）
    g_nSHIENSOCHIKBN              NUMBER;                      --支援措置対象住所非表示
    g_nHAKKOSU                    NUMBER;                      --発行部数
    g_sSHITEIKO_MEI               NVARCHAR2(1000);             --指定学校
    g_sSHITEIKO_GAKUNEN           NVARCHAR2(1000);             --指定学校_学年
    g_sGENZAISEKIKO_MEI           NVARCHAR2(1000);             --現在籍校
    g_sGENZAISEKIKO_GAKUNEN       NVARCHAR2(1000);             --現在籍校_学年
    g_sSHUGAKU_KIKAN              NVARCHAR2(1000);             --就学期間
    g_sTENNYUTETSUZUKI_KIGEN      NVARCHAR2(1000);             --転入学手続き期限
    g_sTOKKIJIKO                  NVARCHAR2(1000);             --特記事項
    g_sBIKO                       NVARCHAR2(1000);             --備考
    g_nRIREKI_RENBAN              NUMBER;                      --履歴連番
    o_ATENA_PRM                   A_CONS_PRM;                  -- パラメータの配列1
    o_LENGTH                      NUMBER;                      -- パラメータの配列の長度1
    o_NSQLCODE                    NUMBER;
    o_VSQLMSG                     NVARCHAR2(500);
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:仕様変更　IT_GKB_00728対応  START       
    TENNYUTETSUZUKI_KIGEN_OUT NVARCHAR2(120);  
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:仕様変更　IT_GKB_00728対応  END    
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/06
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/06
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/06
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
                WHEN 1  THEN    g_nKOJIN_NO              := aCSV_TBL(i);    -- 宛名番号
                WHEN 2  THEN    g_nRIREKI_RENBAN         := aCSV_TBL(i);    -- 履歴連番
                WHEN 3  THEN    g_nCHOHYOKBN             := aCSV_TBL(i);    -- 帳票区分
                WHEN 4  THEN    g_sHAKKOBI               := aCSV_TBL(i);    -- 発送日
                WHEN 5  THEN    g_nNATESAKI              := aCSV_TBL(i);    -- 宛先
                WHEN 6  THEN    g_nKYOIKUKAI             := aCSV_TBL(i);    -- 教育委員会
                WHEN 7  THEN    g_sBUNSHOLIST            := aCSV_TBL(i);    -- 文書番号（リスト）
                --  2024/11/11 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00397対応
                --WHEN 7  THEN    g_nSHIENSOCHIKBN         := aCSV_TBL(i);    -- 支援措置対象住所非表示
                --WHEN 8  THEN    g_nHAKKOSU               := aCSV_TBL(i);    -- 発行部数
                --WHEN 9 THEN     g_sSHITEIKO_MEI          := aCSV_TBL(i);    -- 指定学校
                --WHEN 10 THEN    g_sSHITEIKO_GAKUNEN      := aCSV_TBL(i);    -- 指定学校_学年
                --WHEN 11 THEN    g_sGENZAISEKIKO_MEI      := aCSV_TBL(i);    -- 現在籍校
                --WHEN 12 THEN    g_sGENZAISEKIKO_GAKUNEN  := aCSV_TBL(i);    -- 現在籍校_学年
                --WHEN 13 THEN    g_sSHUGAKU_KIKAN         := aCSV_TBL(i);    -- 就学期間
                --WHEN 14 THEN    g_sTENNYUTETSUZUKI_KIGEN := aCSV_TBL(i);    -- 転入学手続き期限
                --WHEN 15 THEN    g_sTOKKIJIKO             := aCSV_TBL(i);    -- 特記事項
                --WHEN 16 THEN    g_sBIKO                  := aCSV_TBL(i);    -- 備考
                WHEN 8  THEN    g_nSHIENSOCHIKBN         := aCSV_TBL(i);    -- 支援措置対象住所非表示
                WHEN 9  THEN    g_nHAKKOSU               := aCSV_TBL(i);    -- 発行部数
                WHEN 10 THEN     g_sSHITEIKO_MEI          := aCSV_TBL(i);    -- 指定学校
                WHEN 11 THEN    g_sSHITEIKO_GAKUNEN      := aCSV_TBL(i);    -- 指定学校_学年
                WHEN 12 THEN    g_sGENZAISEKIKO_MEI      := aCSV_TBL(i);    -- 現在籍校
                WHEN 13 THEN    g_sGENZAISEKIKO_GAKUNEN  := aCSV_TBL(i);    -- 現在籍校_学年
                WHEN 14 THEN    g_sSHUGAKU_KIKAN         := aCSV_TBL(i);    -- 就学期間
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:仕様変更　IT_GKB_00728対応 START 
               -- WHEN 15 THEN    g_sTENNYUTETSUZUKI_KIGEN := aCSV_TBL(i);    -- 転入学手続き期限
                WHEN 15 THEN    g_sTENNYUTETSUZUKI_KIGEN := TO_NUMBER(aCSV_TBL(i));    -- 転入学手続き期限   
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:仕様変更　IT_GKB_00728対応 END                 
                WHEN 16 THEN    g_sTOKKIJIKO             := aCSV_TBL(i);    -- 特記事項
                WHEN 17 THEN    g_sBIKO                  := aCSV_TBL(i);    -- 備考
                --  2024/10/30 ZCZL.ZHANGLEI UPDATE END
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/06
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/06
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
        --CSV出力処理
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
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:仕様変更　IT_GKB_00728対応 START      
      --------------------------------------------------------
    --  機能概要      : 日付変換
    --  パラメータ    : i_YMD
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: JPJYS.GYY   2024/12/09
    --------------------------------------------------------
    PROCEDURE PROC_GET_YMD(i_YMD IN NUMBER, o_YMD OUT NVARCHAR2) IS
      bRTN             BOOLEAN;                    --戻る値
      io_WAREKIHIZUKE  PLS_INTEGER := 0;
      io_SEIREKIHIZUKE PLS_INTEGER := i_YMD;
      o_EDIT_GYYMMDD1  NVARCHAR2(9);
      o_EDIT_GYYMMDD2  NVARCHAR2(9);
      o_EDIT_GYYMMDD3  NVARCHAR2(11);
      o_KJ_GENGO       NVARCHAR2(2);
      o_KG_GENGO       NVARCHAR2(1);
      o_WAREKI_YY      PLS_INTEGER;
      o_SEIREKI_YYYY   PLS_INTEGER;
      o_WAREKI_GYYMM   PLS_INTEGER;
      o_MM             PLS_INTEGER;
      o_DD             PLS_INTEGER;
      o_IWAREKIHIZUKE  PLS_INTEGER;
      o_ISEIREKIHIZUKE PLS_INTEGER;
    BEGIN
      BRTN := KKAPK0020.FDAYEDIT(io_WAREKIHIZUKE, io_SEIREKIHIZUKE,
                                  o_EDIT_GYYMMDD1, o_EDIT_GYYMMDD2, o_EDIT_GYYMMDD3,
                                  o_KJ_GENGO, o_KG_GENGO,
                                  o_WAREKI_YY, o_SEIREKI_YYYY, o_WAREKI_GYYMM,
                                  o_MM, o_DD,
                                  o_IWAREKIHIZUKE, o_ISEIREKIHIZUKE);
      IF BRTN THEN
        o_YMD := o_EDIT_GYYMMDD3;
      ELSE
        o_YMD := ' ';
      END IF;
    END PROC_GET_YMD;
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:仕様変更　IT_GKB_00728対応 END  
    --------------------------------------------------------
    --  機能概要      : 区域外就学満了通知書作成ワークのレコードの設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC 
        RETURN NUMBER     
    IS
        bRTN                    BOOLEAN;                    --戻る値
        nRTN                    NUMBER;                     --戻る値
        g_nRTN                  PLS_INTEGER;                --処理結果
        o_nDAIRIKBN             NVARCHAR2(1000);            --認証者の本人・代理区分
        o_sKATAGAKI1            NVARCHAR2(1000);            --認証者の肩書上段
        o_sKATAGAKI2            NVARCHAR2(1000);            --認証者の肩書下段
        o_sSHIMEI               NVARCHAR2(1000);            --認証者の氏名
        o_sKOINFILENAME         NVARCHAR2(1000);            --公印ファイル名
        sTOIAWASE1              NVARCHAR2(1000);            --お問い合わせ先１
        sTOIAWASE2              NVARCHAR2(1000);            --お問い合わせ先２
        sTOIAWASE3              NVARCHAR2(1000);            --お問い合わせ先３
        rBUNNUMSRCINF           KKAPK0040.MR_BUNNUMSRCINF;  --文書番号情報（構造体）
        rBUNNUMEDITKEKA         KKAPK0040.MR_BUNNUMEDITKEKA;--文書番号編集結果
        sNUM                    NVARCHAR2(1000);            --文書番号
        sDATEED                 NVARCHAR2(1000);            --発付年月日
        rGKBTGAKUREIBOTY        GKBTGAKUREIBO%ROWTYPE;      --学齢簿情報
        rGKBTTSUCHISHOKANRI     GKBTTSUCHISHOKANRI%ROWTYPE; --通知書管理
        o_aSHIMEIJKN_CHOHYOPRM  A_CONS_PRM;
        o_aEQSHIMEIPRM          A_CONS_PRM;
        nGKBPA00020_INDEX       NUMBER;                     --区域外就学協議書_インデックス番号
        nGKBPA00020_CTL         NUMBER;                     --区域外就学協議書_出力制御
        nHAKKOSU_CNT            NUMBER;                     --発行カウント
        rGKBWL676R001           GKBWL676R001%ROWTYPE;       --区域外就学協議書ワーク
        o_sJIDO_SHIMEI_KANA     NVARCHAR2(1000);            --児童生徒氏名カナ
        o_sJIDO_SHIMEI_KANJI    NVARCHAR2(1000);            --児童生徒氏名漢字
        o_sJIDO_SEINENGAPI      NVARCHAR2(1000);            --児童生徒表示生年月日
        o_sHOGOSHA_SHIMEI_KANA  NVARCHAR2(1000);            --保護者氏名カナ
        o_sHOGOSHA_SHIMEI_KANJI NVARCHAR2(1000);            --保護者氏名漢字
        o_sHOGOSHA_SEINENGAPI   NVARCHAR2(1000);            --保護者表示生年月日
        rRATENA_JIDO2           GABTATENAKIHON%ROWTYPE;     --保護者の宛名基本
        rRSOFU_JIDO2            GABTSOFUSAKI%ROWTYPE;       --保護者の送付先基本
        rRATENA_JIDO            GABTATENAKIHON%ROWTYPE;     --児童生徒の宛名基本
        rRSOFU_JIDO             GABTSOFUSAKI%ROWTYPE;       --児童生徒の送付先基本
        nPRMCTL                 NUMBER;                     --抑止レベル３制御の要否
        sCHOMEI_BANCHI          NVARCHAR2(1000);            --住所マスク文字列
        o_sYUBIN_NO             NVARCHAR2(1000);            --郵便番号
        i_vJUSHO                NVARCHAR2(1000);            --住所 
        --  2024/11/11 ZCZL.ZHANGLEI ADD START 0.3.000.002:IT_GKB_00397対応
        CURSOR  curGAKUREIBOTY IS
          SELECT *
            FROM GKBTGAKUREIBO 
            WHERE KOJIN_NO = g_nKOJIN_NO AND RIREKI_RENBAN = g_nRIREKI_RENBAN ;
        --  2024/11/11 ZCZL.ZHANGLEI ADD END    
    BEGIN 
        -- ワークテーブルを削除する
        -- 初期化
        DELETE FROM GKBWL676R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
        -- ワークテーブル登録
        -- システム制御設定を取得する。
        -- 外国人　氏名・生年月日制御帳票(ID)
        o_aSHIMEIJKN_CHOHYOPRM := A_CONS_PRM();
        --  2024/11/11 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00397対応
        --nRTN := KKAPK0030.FCTGetR('GKB','SHIMEIJKN_CHOHYO','0000',2,o_aSHIMEIJKN_CHOHYOPRM);
        nRTN := KKAPK0030.FCTGetR('GKB','SHIMEIJKN_CHOHYO','0000',1,o_aSHIMEIJKN_CHOHYOPRM);
        IF nRTN = 0 THEN
            FOR i IN 1..o_aSHIMEIJKN_CHOHYOPRM.COUNT LOOP
                --  2024/11/11 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00397対応
                --IF o_aSHIMEIJKN_CHOHYOPRM(i) = '区域外就学満了通知書' THEN
                IF o_aSHIMEIJKN_CHOHYOPRM(i) = 'GKB676R001' THEN
                    nGKBPA00020_INDEX := i;
                    EXIT;
                END IF;
            END LOOP;
        END IF;
        -- 本名・通称名　出力制御
        o_aEQSHIMEIPRM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB','EQSHIMEI','0000',0,o_aEQSHIMEIPRM);
        IF nRTN = 0 AND nGKBPA00020_INDEX <= o_aEQSHIMEIPRM.COUNT THEN
            nGKBPA00020_CTL := o_aEQSHIMEIPRM(nGKBPA00020_INDEX);
        END IF;
        -- 公印情報を取得する
        IF g_nCHOHYOKBN = 28 THEN
            bRTN := KKBPK5551.FNINSHOGet(g_rOPRT.NINSHOCODE, g_sWSNUM, SYSDATE, o_nDAIRIKBN, o_sKATAGAKI1, o_sKATAGAKI2, o_sSHIMEI, o_sKOINFILENAME);
        END IF;
        -- 教育委員会情報を取得する
        o_ATENA_PRM := A_CONS_PRM();
        nRTN := KKAPK0030.FPRMSHUTOKU('GKB', '00KYOIKUKAI', g_nKYOIKUKAI, o_ATENA_PRM, o_LENGTH);
        sTOIAWASE1 := o_ATENA_PRM(1);     --お問い合わせ先１
        sTOIAWASE2 := o_ATENA_PRM(6);     --お問い合わせ先２
        sTOIAWASE3 := o_ATENA_PRM(7);     --お問い合わせ先３
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
            --sDATEED := KKAPK0020.FDAYEDIT20 (TO_NUMBER(TO_CHAR(TO_DATE(rBUNNUMEDITKEKA.DATEED),'YYYYMMDD')), 0, 3, 4, '　');
            --  2024/12/20 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:仕様変更　IT_GKB_10079,IT_GKB_10080対応 Start
            --sDATEED := KKAPK0020.FDAYEDIT20 (TO_NUMBER(TO_CHAR(TO_DATE(rBUNNUMEDITKEKA.BUNDATE),'YYYYMMDD')), 0, 3, 4, '　');
            sDATEED := rBUNNUMEDITKEKA.BUNDATE ;
            --  2024/12/20 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:仕様変更　IT_GKB_10079,IT_GKB_10080対応 End
        ELSE
            sDATEED := '';
        END IF;
        -- 学齢簿から情報を取得する
        --  2024/11/11 ZCZL.ZHANGLEI DEL START 0.3.000.002:IT_GKB_00397対応
        --BEGIN
            --SELECT * INTO rGKBTGAKUREIBOTY
            --FROM GKBTGAKUREIBO 
            --WHERE KOJIN_NO = g_nKOJIN_NO AND RIREKI_RENBAN = g_nRIREKI_RENBAN AND ROWNUM = 1;
        --EXCEPTION
            --WHEN NO_DATA_FOUND THEN  
                 --RETURN 1;
            --WHEN OTHERS THEN
                 --RETURN SQLCODE;
        --END; 
        --  2024/11/11 ZCZL.ZHANGLEI DEL END
        --  2024/11/11 ZCZL.ZHANGLEI ADD 0.3.000.002:IT_GKB_00397対応
        FOR rGKBTGAKUREIBOTY IN curGAKUREIBOTY LOOP
          -- 通知書条件管理から情報を取得する
        BEGIN
            SELECT CHOHYO_MEI
                ,KOIN_SHORYAKU
                ,KOIN_CHUSHAKU
                ,TSUCHIBUN
                ,TOKKIJIKO
                ,BIKO_TITLE
                ,YOSHIKI_BANGO_SETTOGO
                ,YOSHIKI_BANGO
                ,YOSHIKI_BANGO_SETSUBIGO
            INTO rGKBTTSUCHISHOKANRI.CHOHYO_MEI
                ,rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU
                ,rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU
                ,rGKBTTSUCHISHOKANRI.TSUCHIBUN
                ,rGKBTTSUCHISHOKANRI.TOKKIJIKO
                ,rGKBTTSUCHISHOKANRI.BIKO_TITLE
                ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO
                ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO
                ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO
            FROM GKBTTSUCHISHOKANRI   
            WHERE CHOHYO_KBN = '28';   
        EXCEPTION
            WHEN OTHERS THEN
            rGKBTTSUCHISHOKANRI.CHOHYO_MEI               := NULL;
            rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU            := NULL;
            rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU            := NULL;
            rGKBTTSUCHISHOKANRI.TSUCHIBUN                := NULL;
            rGKBTTSUCHISHOKANRI.TOKKIJIKO                := NULL;
            rGKBTTSUCHISHOKANRI.BIKO_TITLE               := NULL;
            rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO    := NULL;
            rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO            := NULL;
            rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO  := NULL;
        END;
        -- 保護者の宛名情報を取得する
        g_nRTN := GAAPK0030.FGETATENA2(rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(TO_DATE(g_sHAKKOBI),'YYYYMMDD')), rRATENA_JIDO2, rRSOFU_JIDO2);
        -- 児童の宛名情報を取得する
        g_nRTN := GAAPK0030.FGETATENA(g_nKOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(TO_DATE(g_sHAKKOBI),'YYYYMMDD')), rRATENA_JIDO, rRSOFU_JIDO);
        -- 児童生徒の本名使用制御判定
        g_nRTN := GKBFKHMCTRL(g_nKOJIN_NO, g_rOPRT.CHOHYOID, 0, nGKBPA00020_CTL, o_sJIDO_SHIMEI_KANA, o_sJIDO_SHIMEI_KANJI, o_sJIDO_SEINENGAPI);
        -- 保護者の本名使用制御判定
        g_nRTN := GKBFKHMCTRL(g_nKOJIN_NO, g_rOPRT.CHOHYOID, 1, nGKBPA00020_CTL, o_sHOGOSHA_SHIMEI_KANA, o_sHOGOSHA_SHIMEI_KANJI, o_sHOGOSHA_SEINENGAPI);
        -- ワークテーブル登録
        -- ソート順
        --  2024/11/11 ZCZL.ZHANGLEI DEL 0.3.000.002:IT_GKB_00397対応
        --rGKBWL676R001.NO := g_nCNT;
        -- 引数.宛先=0（保護者）の場合下
        IF g_nNATESAKI = 0 THEN
            -- 抑止住所編集
--  2024/11/29 ZCZL.WANGYUNING DELETE 0.3.000.003:IT_GKB_00685横展開
--            sCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', rRSOFU_JIDO2.KOJIN_NO,  g_sTANTOCODE, g_sWSNUM, rRSOFU_JIDO2.CHOMEI || rRSOFU_JIDO2.BANCHI, nPRMCTL, 2);
            -- 送付先郵便番号
            --  2024/11/11 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00397対応
            --g_nCNT := KKAPK0010.FYUBINHENSHU(rRSOFU_JIDO2.YUBIN_NO, o_sYUBIN_NO);
            nRTN := KKAPK0010.FYUBINHENSHU(rRSOFU_JIDO2.YUBIN_NO, o_sYUBIN_NO);
            rGKBWL676R001.SOFU_YUBIN :=  KKAPK0010.FMULTIBYTEHENKAN(o_sYUBIN_NO, 0); 
            -- 送付先住所
            rGKBWL676R001.SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, rRSOFU_JIDO2.CHOMEI, rRSOFU_JIDO2.BANCHI, NULL, NULL);
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.003:IT_GKB_00685横展開
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
            --sCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', rRSOFU_JIDO2.KOJIN_NO,  g_sTANTOCODE, g_sWSNUM, rGKBWL676R001.SOFU_JUSHO, nPRMCTL, 2);
            -- 送付先方書
            rGKBWL676R001.SOFU_KATAGAKI := rRSOFU_JIDO2.KATAGAKI;
            -- バーコードNo
            rGKBWL676R001.BC_NO := rRSOFU_JIDO2.YUBIN_NOBC;
            -- 引数.支援措置対象住所非表示＝１(有)の場合
            IF g_nSHIENSOCHIKBN = 1 THEN
                -- 送付先住所
--  2024/11/29 ZCZL.WANGYUNING DELETE 0.3.000.003:IT_GKB_00685横展開
--                rGKBWL676R001.SOFU_JUSHO := sCHOMEI_BANCHI;
                -- 抑止レベル３制御の要否＝’1’(該当)の場合
                --IF nPRMCTL = 1 THEN
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.003:IT_GKB_00685横展開
                    sCHOMEI_BANCHI := GKBPK00010.FGETJUSHOMSG();
                    rGKBWL676R001.SOFU_JUSHO := sCHOMEI_BANCHI;
                    --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.006:品質強化　IT_GKB_00120対応 START
                    -- 送付先方書
                    --rGKBWL676R001.SOFU_KATAGAKI := sCHOMEI_BANCHI;
                    rGKBWL676R001.SOFU_YUBIN := NULL;
                    rGKBWL676R001.SOFU_KATAGAKI := NULL;
                    rGKBWL676R001.BC_NO := NULL;
                    --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.006:品質強化　IT_GKB_00120対応 END
              --END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
            END IF;
            -- 送付先宛名
            rGKBWL676R001.SOFU_ATENA := o_sHOGOSHA_SHIMEI_KANJI || '　' || '様';
        ELSE
            -- 送付先郵便番号
            rGKBWL676R001.SOFU_YUBIN := NULL;
            -- 送付先住所
            rGKBWL676R001.SOFU_JUSHO := NULL;
            -- 送付先方書
            rGKBWL676R001.SOFU_KATAGAKI := NULL;
            -- バーコードNo
            rGKBWL676R001.BC_NO := NULL;
            -- 送付先宛名
            rGKBWL676R001.SOFU_ATENA := g_sSHITEIKO_MEI || '長' || '　' || '様';
        END IF;
        -- 文書番号
        rGKBWL676R001.BUNSHO_NO := sNUM;
        -- 発行年月日
        --  2024/12/20 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:仕様変更　IT_GKB_10079,IT_GKB_10080対応 Start
        --rGKBWL676R001.HAKKO_NENGAPI := sDATEED;
        rGKBWL676R001.HAKKO_NENGAPI := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(TO_NUMBER(REPLACE(sDATEED,'/','')),0,3),' ',''));
        --  2024/12/20 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:仕様変更　IT_GKB_10079,IT_GKB_10080対応 End
        -- 教育委員会名
        rGKBWL676R001.KYOIKUKAI_MEI := o_sKATAGAKI1;
        -- 認証者氏名
        rGKBWL676R001.NINSHOSHA_SHIMEI := o_sSHIMEI;
        -- 公印パス
        rGKBWL676R001.KOIN_PATH := o_sKOINFILENAME;
        IF o_sKOINFILENAME IS NOT NULL THEN 
          -- 公印（省略）
          rGKBWL676R001.KOIN_SHORYAKU := NULL;
          -- 公印（注釈）
          rGKBWL676R001.KOIN_CHUSHAKU := rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU;
        ELSE
          -- 公印（省略）
          rGKBWL676R001.KOIN_SHORYAKU := rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU;
          -- 公印（注釈）
          rGKBWL676R001.KOIN_CHUSHAKU := NULL;
        END IF;
        -- タイトル
        rGKBWL676R001.TITLE := rGKBTTSUCHISHOKANRI.CHOHYO_MEI;
        -- 通知文
        rGKBWL676R001.TSUCHI_BUN := REPLACE(rGKBTTSUCHISHOKANRI.TSUCHIBUN, chr(13)||chr(10),'#');
        -- 児童生徒氏名カナ
        rGKBWL676R001.JIDO_SHIMEI_KANA := o_sJIDO_SHIMEI_KANA;
        -- 児童生徒氏名漢字
        rGKBWL676R001.JIDO_SHIMEI_KANJI := o_sJIDO_SHIMEI_KANJI;
        -- 表示生年月日
        rGKBWL676R001.HYOJI_SEINENGAPI := o_sJIDO_SEINENGAPI;
        -- 住所編集取得関数（GAAPK0010.FADDRESSEDIT）の戻り値を取得する
        i_vJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, rRATENA_JIDO.CHOMEI, rRATENA_JIDO.BANCHI, rRATENA_JIDO.KATAGAKI, NULL);
        -- 児童宛名情報取得 
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
        --sCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', rRATENA_JIDO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, i_vJUSHO, nPRMCTL, 2);
        -- 児童生徒現住所
        IF g_nSHIENSOCHIKBN = 1 THEN 
            --rGKBWL676R001.CHOMEI_BANCHI := sCHOMEI_BANCHI;
            rGKBWL676R001.CHOMEI_BANCHI := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
        ELSE
            rGKBWL676R001.CHOMEI_BANCHI := i_vJUSHO;
        END IF;
        -- 保護者氏名カナ
        rGKBWL676R001.HOGOSHA_SHIMEI_KANA := o_sHOGOSHA_SHIMEI_KANA;
        -- 保護者氏名漢字
        rGKBWL676R001.HOGOSHA_SHIMEI_KANJI := o_sHOGOSHA_SHIMEI_KANJI;
        -- 指定校名
        rGKBWL676R001.SHITEIKO_MEI := g_sSHITEIKO_MEI;
        -- 指定校学年
        rGKBWL676R001.SHITEIKO_GAKUNEN := g_sSHITEIKO_GAKUNEN;
        -- 現在籍校名
        rGKBWL676R001.GENZAISEKIKO_MEI := g_sGENZAISEKIKO_MEI;
        -- 現在籍校学年
        rGKBWL676R001.GENZAISEKIKO_GAKUNEN := g_sGENZAISEKIKO_GAKUNEN;
        -- 就学期間
        rGKBWL676R001.SHUGAKU_KIKAN := g_sSHUGAKU_KIKAN;       
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:仕様変更　IT_GKB_00728対応  START  
--  2024/12/20 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:仕様変更　IT_GKB_10079,IT_GKB_10080対応 Start          
        --PROC_GET_YMD(g_sTENNYUTETSUZUKI_KIGEN, TENNYUTETSUZUKI_KIGEN_OUT);
        -- 転入学手続き期限
        -- rGKBWL676R001.TENNYUTETSUZUKI_KIGEN := g_sTENNYUTETSUZUKI_KIGEN; 
        --rGKBWL676R001.TENNYUTETSUZUKI_KIGEN := TENNYUTETSUZUKI_KIGEN_OUT;
        rGKBWL676R001.TENNYUTETSUZUKI_KIGEN := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(g_sTENNYUTETSUZUKI_KIGEN,0,3),' ',''));
        --  2024/12/20 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:仕様変更　IT_GKB_10079,IT_GKB_10080対応 End
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:仕様変更　IT_GKB_00728対応  END            
        -- 備考
        rGKBWL676R001.BIKO := REPLACE(g_sBIKO, chr(13)||chr(10),'#');
        -- 特記事項
        rGKBWL676R001.TOKKIJIKO := REPLACE(g_sTOKKIJIKO, chr(13)||chr(10),'#'); 
        -- お問い合わせ先１
        rGKBWL676R001.TOIAWASESAKI1 := sTOIAWASE1;
        -- お問い合わせ先２
        rGKBWL676R001.TOIAWASESAKI2 := sTOIAWASE2;
        -- お問い合わせ先３
        rGKBWL676R001.TOIAWASESAKI3 := sTOIAWASE3;
        -- 様式番号
        rGKBWL676R001.YOSHIKI_NO := rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO;
        -- 備考タイトル
        rGKBWL676R001.BIKO_TITLE := rGKBTTSUCHISHOKANRI.BIKO_TITLE;
        -- 改ページキー
        rGKBWL676R001.BREAK_NO := NULL;
        -- 端末番号
        rGKBWL676R001.WSNUM := g_sWSNUM;
        -- 即時バッチ区分
        rGKBWL676R001.BATCHKBN := c_ONLINE;
        -- ジョブNO
        rGKBWL676R001.JOBNUM := g_nJOBNUM;
        FOR i IN 1..g_nHAKKOSU LOOP
            g_nCNT := g_nCNT + 1;
            rGKBWL676R001.NO := g_nCNT;
            INSERT INTO GKBWL676R001 VALUES rGKBWL676R001;
        END LOOP;
        --  2024/11/11 ZCZL.ZHANGLEI ADD 0.3.000.002:IT_GKB_00397対応
        END LOOP;
        -- 関数終了
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN c_ERR;
    END FUNC_GET_JIDO_REC;
    --------------------------------------------------------
    --  機能概要      : メインビジネスロジック処理
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/06
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                    BOOLEAN;                    --戻る値
        nRTN                    PLS_INTEGER;                --戻る値
        ERR                     EXCEPTION;
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');
        -- エラーコードの初期化
        o_NSQLCODE := 0;
        -- エラーメッセージの初期化
        o_VSQLMSG := '';
        -- 区域外就学満了通知書作成ワークのレコードの設定
        nRTN := FUNC_GET_JIDO_REC;
        IF nRTN <> 0 THEN
          RAISE ERR;
        END IF;
        -- CSV出力処理
        bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL676R001', i_sCHOHYOID);
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理終了');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            -- SQL情報取得
            o_NSQLCODE := SQLCODE;
            o_VSQLMSG  := SUBSTR(SQLERRM, 1, 250);
            g_sMESSAGE := g_sMESSAGE || o_NSQLCODE || o_VSQLMSG;
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/06
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
END GKBPA00110;
/