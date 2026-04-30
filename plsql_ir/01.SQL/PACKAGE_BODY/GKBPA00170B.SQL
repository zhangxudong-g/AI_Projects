CREATE OR REPLACE PACKAGE BODY GKBPA00170
--1.0.301.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 外国籍児童への就学案内
--  機能概要      : 帳票発行画面で、選択した処理条件により、対応する中間テーブルにデータを作成する。
--                 確定したCSVファイル名を呼び出し元へ返す。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.shixinyu 2024/06/07
--------------------------------------------------------
--  変更履歴
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.001:IT_GKB_00433対応 
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00539横展開対応
--  2024/11/29 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00685横展開
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応
--  2025/05/21 CTC.HJF UPDATE 1.0.006.000:GKB_QA14685_外国籍児童への就学案内に印字される案内文の３行目が印字されず２行目の設定内容が印字される対応
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
--  2025/11/14 CTC.HJF UPDATE 1.0.301.000:GKB_QA23161対応
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
    g_sWSNUM                      NVARCHAR2(1000);             --端末番号
    g_sBUNSHONUMLIST              NVARCHAR2(1000);             --文書番号情報（リスト）
    g_sMESSAGE                    NVARCHAR2(4000);             --メッセージ返却用
    g_rOPRT                       KKATOPRT%ROWTYPE;            --オンラインジョブステップ情報
    g_sCSV_RCNT                   NVARCHAR2(1000);             --CSVファイル出力件数
    g_sCSVFILENAME                NVARCHAR2(1000);             --CSVファイル名
    g_sPRTFILENAME                NVARCHAR2(1000);             --印刷ファイル名
    g_sSTARTDATE                  NVARCHAR2(23);               --開始時刻

    --変数宣言
    g_nSORT                       NUMBER := 0;                 --ソート順
    g_nHALTSUKOUCODE              NUMBER := 0;                 --発行カウント

    --パラメータ変数
    g_nKOJIN_NO                   NUMBER;                      -- 宛名番号
    g_nNRIREKI_RENBAN             NUMBER;                      -- 履歴連番
    g_nCHOHYO_KBN                 NUMBER;                      -- 帳票区分
    g_sHAKKO_YMD                  NVARCHAR2(1000);             -- 発送日
    g_nATESAKI                    NUMBER;                      -- 宛先
    g_nKYOIKUKAI                  NUMBER;                      -- 教育委員会
    g_sBUNSHO_NO                  NVARCHAR2(1000);             -- 文書番号
    g_nHIENTAISYOUJUSHO           NUMBER;                      -- 支援措置対象住所非表示
    g_nHAKKOBUSUU                 NUMBER;                      -- 発行部数
    g_sHYOUKI                     NVARCHAR2(1000);             -- 標記パターン
    
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/07
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/07
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/07
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
                WHEN 1 THEN
                     g_nKOJIN_NO            := TO_NUMBER(aCSV_TBL(i));         -- 宛名番号
                WHEN 2 THEN
                     g_nNRIREKI_RENBAN      := TO_NUMBER(aCSV_TBL(i));         --履歴連番
                WHEN 3 THEN   
                     g_nCHOHYO_KBN          := TO_NUMBER(aCSV_TBL(i));         -- 帳票区分
                WHEN 4 THEN   
                     g_sHAKKO_YMD           := aCSV_TBL(i);                    -- 発送日
                WHEN 5 THEN   
                     g_nATESAKI             := TO_NUMBER(aCSV_TBL(i));         -- 宛先
                WHEN 6 THEN   
                     g_nKYOIKUKAI           := TO_NUMBER(aCSV_TBL(i));         -- 教育委員会
                WHEN 7 THEN   
                     g_sBUNSHO_NO           := aCSV_TBL(i);                    -- 文書番号
                WHEN 8 THEN   
                     g_nHIENTAISYOUJUSHO    := TO_NUMBER(aCSV_TBL(i));         -- 支援措置対象住所非表示
                WHEN 9 THEN   
                     g_nHAKKOBUSUU          := TO_NUMBER(aCSV_TBL(i));         -- 発行部数
                WHEN 10 THEN   
                     g_sHYOUKI              := aCSV_TBL(i);                    -- 標記パターン
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/07
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/07
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
    --  機能概要      : 外国籍児童への就学案内ワークのレコードの設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu 2024/06/07
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC RETURN NUMBER IS
        bRTN                    BOOLEAN;                    --戻る値
        nRTN                    PLS_INTEGER;                --戻る値
        sSQL                    VARCHAR2(5000);
        TYPE MC_CURSOR IS REF   CURSOR;                     --カーソルタイプ定義
        cCURSOR                 MC_CURSOR;
        rWLTBL                  GKBWL640R001%ROWTYPE;       --新設校・廃校に伴う入学通知書ワーク
        vKOINFILENAME           NVARCHAR2(100);             --公印ファイル名
        nDAIRIKBN               NUMBER;                     --認証者の本人・代理区分
        vKATAGAKI1              NVARCHAR2(1000);            --認証者の肩書上段
        vKATAGAKI2              NVARCHAR2(1000);            --認証者の肩書下段
        vSHIMEI                 NVARCHAR2(1000);            --認証者の氏名
        aCONSPRM                A_CONS_PRM;                 --戻るパラメータ配列
        nLENGTH                 NUMBER;                     --パラメータ配列の長度
        rBUNNUMSRCINF           KKAPK0040.MR_BUNNUMSRCINF;  --文書番号情報（構造体）
        rBUNNUMEDITKEKA         KKAPK0040.MR_BUNNUMEDITKEKA;--文書番号編集結果
        sNUM                    NVARCHAR2(1000);            --文書番号
        sDATEED                 NVARCHAR2(1000);            --文書日付
        aITEM                   A_CONS_PRM;                 --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        sINDEXNO                NUMBER;                     --廃校に伴う入学通知書_インデックス番号
        sSHIYUTSURYOKUSEIGYO    NVARCHAR2(1000);            --新設校・廃校に伴う入学通知書_出力制御
        rGKBTGAKUREIBOTY        GKBTGAKUREIBO%ROWTYPE;      --学齢簿情報
        rGKBTTSUCHISHOKANRITY   GKBTTSUCHISHOKANRI%ROWTYPE; --通知書管理情報
        rGKBTTSUCHIBUNMEN       GKBTTSUCHIBUNMEN%ROWTYPE;   --通知文面設定情報
        rGABTATENAKIHON         GABTATENAKIHON%ROWTYPE;     --保護者の宛名基本情報
        rGABTSOFUSAKI           GABTSOFUSAKI%ROWTYPE;       --保護者の送付先基本情報
        nHANTEIKEKKA            PLS_INTEGER;                --抑止レベル３制御の要否（0：非該当、1：該当）
        sCTLPRM                 NVARCHAR2(500);             --住所マスク文字列
        sJIDOSHIMEIKANA         NVARCHAR2(1000);            --児童氏名カナ
        sJIDOSHIMEIKANJI        NVARCHAR2(1000);            --児童氏名
        sSEINENGAPI             NVARCHAR2(1000);            --生年月日
        vHAKOBI                 NVARCHAR2(100);             --発行日
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.003:IT_GKB_00685横展開
        nPRMCTL                NUMBER;
    BEGIN
        IF g_nCHOHYO_KBN = '37' THEN
          --公印情報を取得する
          bRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE, 0), g_sWSNUM, SYSDATE, nDAIRIKBN, vKATAGAKI1, vKATAGAKI2, vSHIMEI, vKOINFILENAME);
        END IF;
        vHAKOBI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_sHAKKO_YMD,'YYYY/MM/DD'),'YYYY/MM/DD'), 10);            --発行日_表示
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
        -- システム制御設定を取得する
        -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aITEM);
        --「GKB640R001」が格納されている箇所のインデックス番号
        IF nRTN = 0 THEN
          FOR i IN 1..aITEM.COUNT LOOP
            IF aITEM(i) = 'GKB640R001' THEN
              sINDEXNO := i;
              EXIT;
            END IF;
          END LOOP;
        END IF;
        -- 「本名・通称名　出力制御」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aITEM);
        IF nRTN = 0 AND sINDEXNO <= aITEM.COUNT THEN
          sSHIYUTSURYOKUSEIGYO := aITEM(sINDEXNO);
        END IF;
        --通知書管理データ抽出
        BEGIN
          SELECT KOIN_SHORYAKU
                 ,KOIN_CHUSHAKU
                 ,TSUCHIBUN
                 ,YOSHIKI_BANGO_SETTOGO
                 ,YOSHIKI_BANGO
                 ,YOSHIKI_BANGO_SETSUBIGO
          INTO rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU                             --公印省略
               ,rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU                            --公印注釈
               ,rGKBTTSUCHISHOKANRITY.TSUCHIBUN                                --通知文
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO                    --様式番号接頭語
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO                            --様式番号
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO                  --様式番号接尾語
          FROM GKBTTSUCHISHOKANRI
          WHERE CHOHYO_KBN = g_nCHOHYO_KBN;
        EXCEPTION
          WHEN OTHERS THEN
            rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU := NULL;
            rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU := NULL;
            rGKBTTSUCHISHOKANRITY.TSUCHIBUN := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO := NULL;
        END;
        --通知文面設定データ抽出
        BEGIN
          SELECT *
          INTO rGKBTTSUCHIBUNMEN
          FROM GKBTTSUCHIBUNMEN
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応 START
--          WHERE TSUCHI_KBN = '01'
          WHERE TSUCHI_KBN = '37'
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応 END
                AND PATTERN_NO = g_sHYOUKI;
        EXCEPTION
          WHEN OTHERS THEN
              rGKBTTSUCHIBUNMEN := NULL;
        END;
        --学齢簿データ抽出
        sSQL := '';
        sSQL := sSQL || 'SELECT GKBTGAKUREIBO.HUSHUGAKU_KAISI_BI';
        sSQL := sSQL || '       ,GKBTGAKUREIBO.HOGOSYA_KOJIN_NO';
        sSQL := sSQL || '       ,GKBTGAKUREIBO.SYOGAKO_CD';
        sSQL := sSQL || '       ,GKBTGAKUREIBO.TYUGAKO_CD';
        sSQL := sSQL || '       ,GKBTGAKUREIBO.GAKKO_KBN_CD';
        sSQL := sSQL || '       ,GKBTGAKUREIBO.HUSHUGAKU_SYURYO_BI';
        sSQL := sSQL || ' FROM GKBTGAKUREIBO, GABTATENAKIHON';
        sSQL := sSQL || ' WHERE GKBTGAKUREIBO.KOJIN_NO = '||g_nKOJIN_NO||'';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.RIREKI_RENBAN =  '||g_nNRIREKI_RENBAN||'';
        sSQL := sSQL || ' AND GABTATENAKIHON.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.HUSHUGAKU_KAISI_BI <= '||g_sHAKKO_YMD||'';
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097対応 START
--        sSQL := sSQL || ' AND GKBTGAKUREIBO.HUSHUGAKU_KAISI_BI IS NOT NULL';
--        sSQL := sSQL || ' AND GKBTGAKUREIBO.HUSHUGAKU_SYURYO_BI IS NOT NULL';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.HUSHUGAKU_KAISI_BI > 0';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.HUSHUGAKU_SYURYO_BI > 0';
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097対応 END
        sSQL := sSQL || ' AND GKBTGAKUREIBO.HUSHUGAKU_SYURYO_BI >= '||g_sHAKKO_YMD||'';
        sSQL := sSQL || ' AND GABTATENAKIHON.JINKAKU_KBN = 1';
        sSQL := sSQL || ' UNION';
        sSQL := sSQL || ' SELECT GKBTGAKUREIBO.HUSHUGAKU_KAISI_BI';
        sSQL := sSQL || '        ,GKBTGAKUREIBO.HOGOSYA_KOJIN_NO';
        sSQL := sSQL || '        ,GKBTGAKUREIBO.SYOGAKO_CD';
        sSQL := sSQL || '        ,GKBTGAKUREIBO.TYUGAKO_CD';
        sSQL := sSQL || '        ,GKBTGAKUREIBO.GAKKO_KBN_CD';
        sSQL := sSQL || '        ,GKBTGAKUREIBO.HUSHUGAKU_SYURYO_BI';
        sSQL := sSQL || ' FROM GKBTGAKUREIBO, GABTATENAKIHON';
        sSQL := sSQL || ' WHERE GKBTGAKUREIBO.KOJIN_NO = '||g_nKOJIN_NO||'';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.RIREKI_RENBAN =  '||g_nNRIREKI_RENBAN||'';
        sSQL := sSQL || ' AND GABTATENAKIHON.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.HUSHUGAKU_KAISI_BI <= '||g_sHAKKO_YMD||'';
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097対応 START
--        sSQL := sSQL || ' AND GKBTGAKUREIBO.HUSHUGAKU_SYURYO_BI IS NULL';
        sSQL := sSQL || ' AND (GKBTGAKUREIBO.HUSHUGAKU_SYURYO_BI IS NULL OR GKBTGAKUREIBO.HUSHUGAKU_SYURYO_BI = 0)';
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097対応 END
        sSQL := sSQL || ' AND GABTATENAKIHON.JINKAKU_KBN = 1';
        OPEN cCURSOR FOR sSQL;
          LOOP
            FETCH cCURSOR INTO rGKBTGAKUREIBOTY.HUSHUGAKU_KAISI_BI            --不就学_開始年月日
                               ,rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO             --保護者宛名番号
                               ,rGKBTGAKUREIBOTY.SYOGAKO_CD                   --小学校コード
                               ,rGKBTGAKUREIBOTY.TYUGAKO_CD                   --中学校コード
                               ,rGKBTGAKUREIBOTY.GAKKO_KBN_CD                 --学校区分コード
                               ,rGKBTGAKUREIBOTY.HUSHUGAKU_SYURYO_BI;         --不就学_終了年月日
            EXIT WHEN cCURSOR%NOTFOUND;
            --保護者宛名情報
            nRTN := GAAPK0030.FGETATENA2(rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(g_sHAKKO_YMD), rGABTATENAKIHON, rGABTSOFUSAKI);
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00539横展開対応
            --g_nSORT := g_nSORT + 1;
            --rWLTBL.NO := g_nSORT;                                                       --ソート順
--  2024/11/15 ZCZL.WANGYUNING UPDATE END
            rWLTBL.KOJIN_NO := g_nKOJIN_NO;                                             --宛名番号
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応 START
--            --郵便番号編集処理
--            nRTN := KKAPK0010.FYUBINHENSHU(rGABTSOFUSAKI.YUBIN_NO, rWLTBL.SOFUSAKI_YUBIN_NO);
--            rWLTBL.SOFUSAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(rWLTBL.SOFUSAKI_YUBIN_NO, 0);      --送付先郵便番号
--            --送付先住所
--            rWLTBL.SOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, rGABTSOFUSAKI.CHOMEI, rGABTSOFUSAKI.BANCHI, NULL, NULL);
--            rWLTBL.SOFUSAKI_KATAGAKI := rGABTSOFUSAKI.KATAGAKI;                         --送付先方書
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応 END
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.003:IT_GKB_00685横展開
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
            -- sCTLPRM := GAAPK0030.FDVJUSHO('GKB', g_nKOJIN_NO,  g_sTANTOCODE, g_sWSNUM, rWLTBL.SOFUSAKI_JUSHO, nPRMCTL, 2);
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応 START
--            IF g_nHIENTAISYOUJUSHO = 1 THEN
            IF g_nHIENTAISYOUJUSHO = 1 THEN
              --学齢簿.保護者宛名番号でDV判定
            -- IF g_nHIENTAISYOUJUSHO = 1 AND nPRMCTL = 1 THEN
                sCTLPRM := GKBPK00010.FGETJUSHOMSG();
              --住所マスク文字列
--  2024/11/29 ZCZL.WANGYUNING UPDATE START 0.3.000.003:IT_GKB_00685横展開
--              sCTLPRM := GAAPK0030.FDVJUSHO('GKB', rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, rWLTBL.SOFUSAKI_JUSHO, nHANTEIKEKKA, 2, NULL, NULL);
--              rWLTBL.SOFUSAKI_JUSHO := sCTLPRM;                                         --送付先住所
--              IF nHANTEIKEKKA = 1 THEN
--                rWLTBL.SOFUSAKI_KATAGAKI := NULL;                                       --送付先方書
--              END IF;
                -- 抑止レベル３制御の要否＝’1’(該当)の場合
--              IF nPRMCTL = '1' THEN
                rWLTBL.BC_NO := NULL;                           --郵便番号ＢＣ
                rWLTBL.SOFUSAKI_YUBIN_NO := NULL;               --郵便番号
                rWLTBL.SOFUSAKI_JUSHO  := sCTLPRM;              --住所
                rWLTBL.SOFUSAKI_KATAGAKI       := NULL;         --送付先方書
--              END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
            ELSE
                rWLTBL.BC_NO := rGABTATENAKIHON.YUBIN_NOBC;                                                                      --郵便番号ＢＣ
                --郵便番号編集処理
                nRTN := KKAPK0010.FYUBINHENSHU(rGABTSOFUSAKI.YUBIN_NO, rWLTBL.SOFUSAKI_YUBIN_NO);
                rWLTBL.SOFUSAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(rWLTBL.SOFUSAKI_YUBIN_NO, 0);                             --郵便番号
                rWLTBL.SOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, rGABTSOFUSAKI.CHOMEI, rGABTSOFUSAKI.BANCHI, NULL, NULL);--住所
                rWLTBL.SOFUSAKI_KATAGAKI := rGABTSOFUSAKI.KATAGAKI;                                                              --送付先方書
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応 END
--  2024/11/29 ZCZL.WANGYUNING UPDATE END
            END IF;
            --保護者の本名使用制御判定
            nRTN := GKBFKHMCTRL(g_nKOJIN_NO, g_rOPRT.CHOHYOID, 1, sSHIYUTSURYOKUSEIGYO, sJIDOSHIMEIKANA, sJIDOSHIMEIKANJI, sSEINENGAPI);
            rWLTBL.SOFUSAKI_MEI := sJIDOSHIMEIKANJI || '　' || '様';                     --送付先名
--  2024/12/19 JPJYS.LIUHUAIQI DEL 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応 START
--            rWLTBL.BC_NO := rGABTATENAKIHON.YUBIN_NOBC;                                 --郵便番号ＢＣ
--  2024/12/19 JPJYS.LIUHUAIQI DEL 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応 END
            rWLTBL.BUNSHO_NO := sNUM;                                                   --文書番号
            --和暦の場合
            IF rGKBTTSUCHIBUNMEN.HAKKOBI_HYOJI_KBN = 2 THEN
              --送付年月日
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応 START
--              nRTN := KKAPK0020.FDateSW(TO_CHAR(TO_DATE(g_sHAKKO_YMD,'YYYY/MM/DD'),'YYYY/MM/DD'), rWLTBL.SOFUSAKI_YMD);
-- 2025/11/14 CTC.HJF UPDATE START 1.0.301.000:GKB_QA23161
              IF sDATEED IS NOT NULL OR sDATEED <> '' THEN
-- 2025/11/14 CTC.HJF UPDATE END
                rWLTBL.SOFUSAKI_YMD := TO_MULTI_BYTE(REPLACE(vHAKOBI,' ',''));
-- 2025/11/14 CTC.HJF UPDATE START 1.0.301.000:GKB_QA23161
              END IF;
-- 2025/11/14 CTC.HJF UPDATE END
--  2024/12/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10097,IT_GKB_10098,IT_GKB_10099,IT_GKB_10109対応 END
            END IF;
            --西暦の場合
            IF rGKBTTSUCHIBUNMEN.HAKKOBI_HYOJI_KBN = 1 THEN
              --送付年月日
-- 2025/11/14 CTC.HJF UPDATE START 1.0.301.000:GKB_QA23161
              IF sDATEED IS NOT NULL OR sDATEED <> '' THEN
-- 2025/11/14 CTC.HJF UPDATE END
              rWLTBL.SOFUSAKI_YMD := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_sHAKKO_YMD,'YYYY/MM/DD'),'YYYY/MM/DD'), 8);
              rWLTBL.SOFUSAKI_YMD := SUBSTR (rWLTBL.SOFUSAKI_YMD, 1, 2) || 'Year' || '/' || SUBSTR (rWLTBL.SOFUSAKI_YMD, 4, 2) || 'Month' || '/' || SUBSTR (rWLTBL.SOFUSAKI_YMD, 7, 2) || 'Day';
-- 2025/11/14 CTC.HJF UPDATE START 1.0.301.000:GKB_QA23161
              END IF;
-- 2025/11/14 CTC.HJF UPDATE END
            END IF;
            rWLTBL.NINSHOSHAKATAGAKI := vKATAGAKI1;                                     --認証者肩書
            rWLTBL.NINSHOSHANAME := vSHIMEI;                                            --認証者名
            rWLTBL.TSUCHI_KOIN_JOHO := vKOINFILENAME;                                   --公印
            IF vKOINFILENAME IS NULL THEN
              rWLTBL.TSUCHI_KOIN_JOHO_SHORYAKU := rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU;  --公印（省略）
              rWLTBL.TSUCHI_KOIN_JOHO_CHUSHAKU := NULL;                                 --公印（注釈）
            ELSE
              rWLTBL.TSUCHI_KOIN_JOHO_SHORYAKU := NULL;                                 --公印（省略）
              rWLTBL.TSUCHI_KOIN_JOHO_CHUSHAKU := rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU;  --公印（注釈）
            END IF;
            IF rGKBTTSUCHIBUNMEN.HYODAI_SHIYO_FLG = 1 THEN 
              rWLTBL.HYODAI := rGKBTTSUCHIBUNMEN.HYODAI;                                --標題
            ELSIF rGKBTTSUCHIBUNMEN.HYODAI_SHIYO_FLG = 0 THEN
              rWLTBL.HYODAI := '';
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG1 = 1 THEN 
              rWLTBL.HONBUN1 := rGKBTTSUCHIBUNMEN.HONBUN1;                              --本文1
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG1 = 0 THEN
              rWLTBL.HONBUN1 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG2 = 1 THEN 
              rWLTBL.HONBUN2 := rGKBTTSUCHIBUNMEN.HONBUN2;                              --本文2
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG2 = 0 THEN
              rWLTBL.HONBUN2 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG3 = 1 THEN 
--  2025/05/15 CTC.HJF UPDATE START 1.0.006.000:GKB_QA14685_外国籍児童への就学案内に印字される案内文の３行目が印字されず２行目の設定内容が印字される対応
              rWLTBL.HONBUN3 := rGKBTTSUCHIBUNMEN.HONBUN3;                              --本文3
--  2025/05/15 CTC.HJF UPDATE END
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG3 = 0 THEN
              rWLTBL.HONBUN3 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG4 = 1 THEN 
              rWLTBL.HONBUN4 := rGKBTTSUCHIBUNMEN.HONBUN4;                              --本文4
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG4 = 0 THEN
              rWLTBL.HONBUN4 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG5 = 1 THEN 
              rWLTBL.HONBUN5 := rGKBTTSUCHIBUNMEN.HONBUN5;                              --本文5
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG5 = 0 THEN
              rWLTBL.HONBUN5 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG6 = 1 THEN 
              rWLTBL.HONBUN6 := rGKBTTSUCHIBUNMEN.HONBUN6;                              --本文6
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG6 = 0 THEN
              rWLTBL.HONBUN6 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG7 = 1 THEN 
              rWLTBL.HONBUN7 := rGKBTTSUCHIBUNMEN.HONBUN7;                              --本文7
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG7 = 0 THEN
              rWLTBL.HONBUN7 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG8 = 1 THEN 
              rWLTBL.HONBUN8 := rGKBTTSUCHIBUNMEN.HONBUN8;                              --本文8
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG8 = 0 THEN
              rWLTBL.HONBUN8 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG9 = 1 THEN 
              rWLTBL.HONBUN9 := rGKBTTSUCHIBUNMEN.HONBUN9;                              --本文9
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG9 = 0 THEN
              rWLTBL.HONBUN9 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG10 = 1 THEN 
              rWLTBL.HONBUN10 := rGKBTTSUCHIBUNMEN.HONBUN10;                            --本文10
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG10 = 0 THEN
              rWLTBL.HONBUN10 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG11 = 1 THEN 
              rWLTBL.HONBUN11 := rGKBTTSUCHIBUNMEN.HONBUN11;                            --本文11
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG11 = 0 THEN
              rWLTBL.HONBUN11 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG12 = 1 THEN 
              rWLTBL.HONBUN12 := rGKBTTSUCHIBUNMEN.HONBUN12;                            --本文12
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG12 = 0 THEN
              rWLTBL.HONBUN12 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG13 = 1 THEN 
              rWLTBL.HONBUN13 := rGKBTTSUCHIBUNMEN.HONBUN13;                            --本文13
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG13 = 0 THEN
              rWLTBL.HONBUN13 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG14 = 1 THEN 
              rWLTBL.HONBUN14 := rGKBTTSUCHIBUNMEN.HONBUN14;                            --本文14
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG13 = 0 THEN
              rWLTBL.HONBUN14 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG15 = 1 THEN 
              rWLTBL.HONBUN15 := rGKBTTSUCHIBUNMEN.HONBUN15;                            --本文15
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG15 = 0 THEN
              rWLTBL.HONBUN15 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG16 = 1 THEN 
              rWLTBL.HONBUN16 := rGKBTTSUCHIBUNMEN.HONBUN16;                            --本文16
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG16 = 0 THEN
              rWLTBL.HONBUN16 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG17 = 1 THEN 
              rWLTBL.HONBUN17 := rGKBTTSUCHIBUNMEN.HONBUN17;                            --本文17
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG17 = 0 THEN
              rWLTBL.HONBUN17 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG18 = 1 THEN 
              rWLTBL.HONBUN18 := rGKBTTSUCHIBUNMEN.HONBUN18;                            --本文18
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG18 = 0 THEN
              rWLTBL.HONBUN18 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG19 = 1 THEN 
              rWLTBL.HONBUN19 := rGKBTTSUCHIBUNMEN.HONBUN19;                            --本文19
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG19 = 0 THEN
              rWLTBL.HONBUN19 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG20 = 1 THEN 
              rWLTBL.HONBUN20 := rGKBTTSUCHIBUNMEN.HONBUN20;                            --本文20
            ELSIF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG20 = 0 THEN
              rWLTBL.HONBUN20 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.OTOIAWASESAKI_SHIYO_FLG1 = 1 THEN 
              rWLTBL.OTOIAWASESAKI1 := rGKBTTSUCHIBUNMEN.OTOIAWASESAKI1;                --お問い合わせ先1
            ELSIF rGKBTTSUCHIBUNMEN.OTOIAWASESAKI_SHIYO_FLG1 = 0 THEN
              rWLTBL.OTOIAWASESAKI1 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.OTOIAWASESAKI_SHIYO_FLG2 = 1 THEN 
              rWLTBL.OTOIAWASESAKI2 := rGKBTTSUCHIBUNMEN.OTOIAWASESAKI2;                --お問い合わせ先2
            ELSIF rGKBTTSUCHIBUNMEN.OTOIAWASESAKI_SHIYO_FLG2 = 0 THEN
              rWLTBL.OTOIAWASESAKI2 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.OTOIAWASESAKI_SHIYO_FLG3 = 1 THEN 
              rWLTBL.OTOIAWASESAKI3 := rGKBTTSUCHIBUNMEN.OTOIAWASESAKI3;                --お問い合わせ先3
            ELSIF rGKBTTSUCHIBUNMEN.OTOIAWASESAKI_SHIYO_FLG3 = 0 THEN
              rWLTBL.OTOIAWASESAKI3 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.OTOIAWASESAKI_SHIYO_FLG4 = 1 THEN 
              rWLTBL.OTOIAWASESAKI4 := rGKBTTSUCHIBUNMEN.OTOIAWASESAKI4;                --お問い合わせ先4
            ELSIF rGKBTTSUCHIBUNMEN.OTOIAWASESAKI_SHIYO_FLG4 = 0 THEN
              rWLTBL.OTOIAWASESAKI4 := NULL;
            END IF;
            IF rGKBTTSUCHIBUNMEN.OTOIAWASESAKI_SHIYO_FLG5 = 1 THEN 
              rWLTBL.OTOIAWASESAKI5 := rGKBTTSUCHIBUNMEN.OTOIAWASESAKI5;                --お問い合わせ先5
            ELSIF rGKBTTSUCHIBUNMEN.OTOIAWASESAKI_SHIYO_FLG5 = 0 THEN
              rWLTBL.OTOIAWASESAKI5 := NULL;
            END IF;
            --様式番号
            rWLTBL.YOSHIKI_NO := rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO;
            rWLTBL.BREAK_NO := NULL;                                                    --改ページキー
            rWLTBL.WSNUM := g_sWSNUM;                                                   --端末番号
            rWLTBL.BATCHKBN := c_ONLINE;                                                --即時バッチ区分
            rWLTBL.JOBNUM := g_nJOBNUM;                                                 --ジョブNO
            FOR i IN 1..g_nHAKKOBUSUU LOOP
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00539横展開対応
              g_nSORT := g_nSORT + 1;
              rWLTBL.NO := g_nSORT;                                                       --ソート順
--  2024/11/15 ZCZL.WANGYUNING UPDATE END
              --登録ワークテーブル
              INSERT INTO GKBWL640R001 VALUES rWLTBL;
            END LOOP;
          END LOOP;
        CLOSE cCURSOR;
        -- 関数終了
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
            IF cCURSOR%ISOPEN THEN
              CLOSE cCURSOR;
            END IF;
            RETURN c_ERR;
    END FUNC_GET_JIDO_REC;
    --------------------------------------------------------
    --  機能概要      : メインビジネスロジック処理
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu 2024/06/07
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        nRTN                  PLS_INTEGER;                --戻る値
        ERR                   EXCEPTION;
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');
        -- 初期化
        BEGIN
            DELETE FROM GKBWL640R001
            WHERE WSNUM = g_sWSNUM
            AND BATCHKBN = c_ONLINE;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE ERR;
        END;
        -- 外国籍児童への就学案内ワークのレコードの設定
        nRTN := FUNC_GET_JIDO_REC;
        IF nRTN <> 0 THEN
          RAISE ERR;
        END IF;
        -- CSV出力処理
        bRTN := FUNC_O20CSV (i_sGYOUMUCODE, 'GKBWL640R001', i_sCHOHYOID);
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理終了');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            g_sMESSAGE := SQLCODE || SUBSTR(SQLERRM, 1, 250);
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/07
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
END GKBPA00170;
/
