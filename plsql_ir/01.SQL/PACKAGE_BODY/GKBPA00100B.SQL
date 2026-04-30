CREATE OR REPLACE PACKAGE BODY GKBPA00100
--1.0.403.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 区域外就学承諾書作成
--  機能概要      : 区域外就学承諾書の即時帳票を印刷する場合に呼び出される。
--                  標準仕様の帳票レイアウトに合わせた項目を出力する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/05
--------------------------------------------------------
--  変更履歴
--  2024/11/29 ZCZL.WANGYUNING UPDATE 0.3.000.001:IT_GKB_00685横展開
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:IT_GKB_00726横展開対応 
--  2025/05/20 ZCZL.ZHANGLEI UPDATE 1.0.004.000：GKB_QA13577_二次対応_(保守#2243)_発送日印字対応
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
--  2025/11/14 CTC.HJF UPDATE 1.0.301.000:GKB_QA23161対応
--  2025/12/10 CTC.HJF UPDATE 1.0.403.000:GKB_QA23034対応
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
    g_nKYOIKUKAI                  NUMBER;                      --教育委員会
    g_nSHIENSOCHIKBN              NUMBER;                      --支援措置対象住所非表示
    g_nHAKKOSU                    NUMBER;                      --発行部数
    g_sJUSHO_KBN                  NVARCHAR2(1000);             --住所区分
    g_sJUSHO                      NVARCHAR2(1000);             --住所
    g_sSHITEIKO_MEI               NVARCHAR2(1000);             --指定学校
    g_sSHITEIKO_GAKUNEN           NVARCHAR2(1000);             --指定学校_学年
    g_sKIBOKO_MEI                 NVARCHAR2(1000);             --希望就学校
    g_sKIBOKO_GAKUNEN             NVARCHAR2(1000);             --希望就学校_学年
    g_sKIBO_HENKO_KIKAN           NVARCHAR2(1000);             --希望変更期間    
    g_sSHINSEI_RIYU               NVARCHAR2(1000);             --申請理由  
    g_nRIREKI_RENBAN              NUMBER;                      --履歴連番    
    o_ATENA_PRM                   A_CONS_PRM;                  --パラメータの配列1
    o_LENGTH                      NUMBER;                      --パラメータの配列の長度1
    o_NSQLCODE                    NUMBER;
    o_VSQLMSG                     NVARCHAR2(500);
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:IT_GKB_00726横展開対応 START  
    o_sJUSHO_SHIMEI               NVARCHAR2(100);
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:IT_GKB_00726横展開対応 END 
--  2025/12/10 CTC.HJF UPDATE START 1.0.403.000:GKB_QA23034対応
    g_nAGREEMENT                  NVARCHAR2(1000);             --承諾書宛先
--  2025/12/10 CTC.HJF UPDATE END
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/05
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/05
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/05
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
                WHEN 1  THEN     g_nKOJIN_NO             := aCSV_TBL(i);    -- 宛名番号
                WHEN 2  THEN     g_nRIREKI_RENBAN        := aCSV_TBL(i);    -- 履歴連番
                WHEN 3  THEN     g_nCHOHYOKBN            := aCSV_TBL(i);    -- 帳票区分
                WHEN 4  THEN     g_sHAKKOBI              := aCSV_TBL(i);    -- 発送日
                WHEN 5  THEN     g_nKYOIKUKAI            := aCSV_TBL(i);    -- 教育委員会
                WHEN 6  THEN     g_nSHIENSOCHIKBN        := aCSV_TBL(i);    -- 支援措置対象住所非表示
                WHEN 7  THEN     g_nHAKKOSU              := aCSV_TBL(i);    -- 発行部数
                WHEN 8  THEN     g_sJUSHO_KBN            := aCSV_TBL(i);    -- 住所区分
                WHEN 9  THEN     g_sJUSHO                := aCSV_TBL(i);    -- 住所
                WHEN 10  THEN    g_sSHITEIKO_MEI         := aCSV_TBL(i);    -- 指定学校
                WHEN 11  THEN    g_sSHITEIKO_GAKUNEN     := aCSV_TBL(i);    -- 指定学校_学年
                WHEN 12  THEN    g_sKIBOKO_MEI           := aCSV_TBL(i);    -- 希望就学校
                WHEN 13  THEN    g_sKIBOKO_GAKUNEN       := aCSV_TBL(i);    -- 希望就学校_学年
                WHEN 14  THEN    g_sKIBO_HENKO_KIKAN     := aCSV_TBL(i);    -- 希望変更期間
                WHEN 15  THEN    g_sSHINSEI_RIYU         := aCSV_TBL(i);    -- 申請理由
--  2025/12/10 CTC.HJF UPDATE START 1.0.403.000:GKB_QA23034対応
                WHEN 16  THEN    g_nAGREEMENT            := aCSV_TBL(i);    -- 承諾書宛先テキスト
--  2025/12/10 CTC.HJF UPDATE END
 
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/05
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/05
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
    --------------------------------------------------------
    --  機能概要      : 区域外就学承諾書作成ワークのレコードの設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/05
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC 
        RETURN NUMBER     
    IS
        nRTN                    NUMBER;                     --戻る値
        g_nRTN                  PLS_INTEGER;                --処理結果
        sKYOIKUKAI              NVARCHAR2(1000);            --教育委員会名
        sTOIAWASE2              NVARCHAR2(1000);            --お問い合わせ先２
        sTOIAWASE3              NVARCHAR2(1000);            --お問い合わせ先３
        rGKBTTSUCHISHOKANRI     GKBTTSUCHISHOKANRI%ROWTYPE; --通知書管理
        o_aSHIMEIJKN_CHOHYOPRM  A_CONS_PRM;
        o_aEQSHIMEIPRM          A_CONS_PRM;
        nGKBPA00020_INDEX       NUMBER;                     --区域外就学協議書_インデックス番号
        nGKBPA00020_CTL         NUMBER;                     --区域外就学協議書_出力制御
        rGKBWL673R001           GKBWL673R001%ROWTYPE;       --区域外就学協議書ワーク
        o_sJIDO_SHIMEI_KANA     NVARCHAR2(1000);            --児童生徒氏名カナ
        o_sJIDO_SHIMEI_KANJI    NVARCHAR2(1000);            --児童生徒氏名漢字
        o_sJIDO_SEINENGAPI      NVARCHAR2(1000);            --児童生徒表示生年月日
        o_sHOGOSHA_SHIMEI_KANA  NVARCHAR2(1000);            --保護者氏名カナ
        o_sHOGOSHA_SHIMEI_KANJI NVARCHAR2(1000);            --保護者氏名漢字
        o_sHOGOSHA_SEINENGAPI   NVARCHAR2(1000);            --保護者表示生年月日
        rRATENA_JIDO             GABTATENAKIHON%ROWTYPE;    --児童生徒の宛名基本
        rRSOFU_JIDO              GABTSOFUSAKI%ROWTYPE;      --児童生徒の送付先基本
        nPRMCTL                 NUMBER;                     --抑止レベル３制御の要否
        sCHOMEI_BANCHI          NVARCHAR2(1000);            --住所マスク文字列
        i_vJUSHO                NVARCHAR2(1000);            --住所                    
-- 2025/11/14 CTC.HJF UPDATE START 1.0.301.000:GKB_QA23161
        sDATEED                 NVARCHAR2(1000);            --発付年月日
        rBUNNUMSRCINF           KKAPK0040.MR_BUNNUMSRCINF;  --文書番号情報（構造体）
        rBUNNUMEDITKEKA         KKAPK0040.MR_BUNNUMEDITKEKA;--文書番号編集結果
        sNUM                    NVARCHAR2(1000);            --文書番号
-- 2025/11/14 CTC.HJF UPDATE END
    BEGIN
        -- ワークテーブルを削除する
        -- 初期化
        DELETE FROM GKBWL673R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
        -- ワークテーブル登録
        -- 教育委員会情報を取得する
        o_ATENA_PRM := A_CONS_PRM();
        nRTN := KKAPK0030.FPRMSHUTOKU('GKB', '00KYOIKUKAI', g_nKYOIKUKAI, o_ATENA_PRM, o_LENGTH);
        sKYOIKUKAI := o_ATENA_PRM(1);     --教育委員会名
        sTOIAWASE2 := o_ATENA_PRM(6);     --お問い合わせ先２
        sTOIAWASE3 := o_ATENA_PRM(7);     --お問い合わせ先３
        -- 通知書条件管理から情報を取得する
        BEGIN
            SELECT CHOHYO_MEI
                ,TSUCHIBUN
                ,YOSHIKI_BANGO_SETTOGO
                ,YOSHIKI_BANGO
                ,YOSHIKI_BANGO_SETSUBIGO
            INTO rGKBTTSUCHISHOKANRI.CHOHYO_MEI
                ,rGKBTTSUCHISHOKANRI.TSUCHIBUN
                ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO
                ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO
                ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO
           FROM GKBTTSUCHISHOKANRI   
           WHERE CHOHYO_KBN = '26';   
        EXCEPTION
            WHEN OTHERS THEN
            rGKBTTSUCHISHOKANRI.CHOHYO_MEI               := NULL;
            rGKBTTSUCHISHOKANRI.TSUCHIBUN                := NULL;
            rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU            := NULL;
            rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO    := NULL;
            rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO            := NULL;
            rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO  := NULL;
        END;
        -- システム制御設定を取得する。
        --外国人　氏名・生年月日制御帳票(ID)
        o_aSHIMEIJKN_CHOHYOPRM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB','SHIMEIJKN_CHOHYO','0000',1,o_aSHIMEIJKN_CHOHYOPRM);
        IF nRTN = 0 THEN
            FOR i IN 1..o_aSHIMEIJKN_CHOHYOPRM.COUNT LOOP
                IF o_aSHIMEIJKN_CHOHYOPRM(i) = 'GKB673R001' THEN
                    nGKBPA00020_INDEX := i;
                    EXIT;
                END IF;
            END LOOP;
        END IF;
        --本名・通称名　出力制御
        o_aEQSHIMEIPRM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB','EQSHIMEI','0000',0,o_aEQSHIMEIPRM);
        IF nRTN = 0 AND nGKBPA00020_INDEX <= o_aEQSHIMEIPRM.COUNT THEN
            nGKBPA00020_CTL := o_aEQSHIMEIPRM(nGKBPA00020_INDEX);
        END IF;
        -- 児童宛名情報取得 
        g_nRTN := GAAPK0030.FGETATENA(g_nKOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(TO_DATE(g_sHAKKOBI),'YYYYMMDD')), rRATENA_JIDO, rRSOFU_JIDO);
        -- ワークテーブル登録
        -- ソート順
        rGKBWL673R001.NO := g_nCNT;
        -- 教育委員会名
--  2025/12/10 CTC.HJF UPDATE START 1.0.403.000:GKB_QA23034対応
        IF g_nAGREEMENT IS NOT NULL THEN
           rGKBWL673R001.KYOIKUKAI_MEI := g_nAGREEMENT || '　' || '教育長宛';
        ELSE
--  2025/12/10 CTC.HJF UPDATE  END
        rGKBWL673R001.KYOIKUKAI_MEI := sKYOIKUKAI || '　' || '教育長宛';
--  2025/12/10 CTC.HJF UPDATE START 1.0.403.000:GKB_QA23034対応
        END IF;
--  2025/12/10 CTC.HJF UPDATE END
        -- 発行年月日
        --  2025/05/20 ZCZL.ZHANGLEI UPDATE 1.0.004.000：GKB_QA13577_二次対応_(保守#2243)_発送日印字対応
        --rGKBWL673R001.HAKKO_NENGAPI := KKAPK0020.FDAYEDIT20 (TO_NUMBER(TO_CHAR(TO_DATE(g_sHAKKOBI),'YYYYMMDD')), 0, 3, 4, '　');
-- 2025/11/14 CTC.HJF UPDATE START 1.0.301.000:GKB_QA23161
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
            sDATEED := rBUNNUMEDITKEKA.BUNDATE;
        ELSE
            sDATEED := '';
        END IF;
        IF sDATEED IS NOT NULL OR sDATEED <> '' THEN
-- 2025/11/14 CTC.HJF UPDATE END
        rGKBWL673R001.HAKKO_NENGAPI := KKAPK0020.FDAYEDIT20 (TO_NUMBER(TO_CHAR(TO_DATE(g_sHAKKOBI),'YYYYMMDD')), 0, 3, 1, '　');
-- 2025/11/14 CTC.HJF UPDATE START 1.0.301.000:GKB_QA23161
        END IF;
-- 2025/11/14 CTC.HJF UPDATE END
        -- タイトル
        rGKBWL673R001.TITLE := rGKBTTSUCHISHOKANRI.CHOHYO_MEI;
        -- 通知文
        rGKBWL673R001.TSUCHI_BUN := REPLACE(rGKBTTSUCHISHOKANRI.TSUCHIBUN, chr(13)||chr(10),'#');
        -- 児童生徒の本名使用制御判定
        g_nRTN := GKBFKHMCTRL(g_nKOJIN_NO, g_rOPRT.CHOHYOID, 0, nGKBPA00020_CTL, o_sJIDO_SHIMEI_KANA, o_sJIDO_SHIMEI_KANJI, o_sJIDO_SEINENGAPI);
        -- 児童生徒氏名カナ
        rGKBWL673R001.JIDO_SHIMEI_KANA := o_sJIDO_SHIMEI_KANA;
        -- 児童生徒氏名漢字
        rGKBWL673R001.JIDO_SHIMEI_KANJI := o_sJIDO_SHIMEI_KANJI;
        -- 表示生年月日
        rGKBWL673R001.HYOJI_SEINENGAPI := o_sJIDO_SEINENGAPI;
        -- 住所編集取得関数（GAAPK0010.FADDRESSEDIT）の戻り値を取得する
        i_vJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, rRATENA_JIDO.CHOMEI, rRATENA_JIDO.BANCHI, rRATENA_JIDO.KATAGAKI, NULL);
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
        --sCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', rRATENA_JIDO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, i_vJUSHO, nPRMCTL, 2);
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.001:IT_GKB_00685横展開
        rGKBWL673R001.CHOMEI_BANCHI := i_vJUSHO;
        -- 児童生徒現住所
        IF g_nSHIENSOCHIKBN = 1 THEN 
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.001:IT_GKB_00685横展開
          --IF nPRMCTL = '1' THEN
            sCHOMEI_BANCHI := GKBPK00010.FGETJUSHOMSG();
            rGKBWL673R001.CHOMEI_BANCHI := sCHOMEI_BANCHI;
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.001:IT_GKB_00685横展開
          --END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
        ELSE
            rGKBWL673R001.CHOMEI_BANCHI := i_vJUSHO;
        END IF;
 --  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:IT_GKB_00726横展開対応 START  
        IF g_sJUSHO_KBN = 0 THEN
          o_sJUSHO_SHIMEI := '異動前';
        ELSIF g_sJUSHO_KBN = 1 THEN
          o_sJUSHO_SHIMEI := '異動後';   
        ELSIF g_sJUSHO_KBN = 2 THEN
          o_sJUSHO_SHIMEI := '預かり先等'; 
        END IF;
        -- 住所区分
        --rGKBWL673R001.JUSHO_KBN := g_sJUSHO_KBN;
        rGKBWL673R001.JUSHO_KBN := o_sJUSHO_SHIMEI;
 --  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:IT_GKB_00726横展開対応 END  
        -- 住所
        rGKBWL673R001.JUSHO := g_sJUSHO;
        -- 保護者の本名使用制御判定
        g_nRTN := GKBFKHMCTRL(g_nKOJIN_NO, g_rOPRT.CHOHYOID, 1, nGKBPA00020_CTL, o_sHOGOSHA_SHIMEI_KANA, o_sHOGOSHA_SHIMEI_KANJI, o_sHOGOSHA_SEINENGAPI);
        -- 保護者氏名カナ
        rGKBWL673R001.HOGOSHA_SHIMEI_KANA := o_sHOGOSHA_SHIMEI_KANA;
        -- 保護者氏名漢字
        rGKBWL673R001.HOGOSHA_SHIMEI_KANJI := o_sHOGOSHA_SHIMEI_KANJI;
        -- 指定校名
        rGKBWL673R001.SHITEIKO_MEI := g_sSHITEIKO_MEI;
        -- 指定校学年
        rGKBWL673R001.SHITEIKO_GAKUNEN := g_sSHITEIKO_GAKUNEN;
        -- 希望校名
        rGKBWL673R001.KIBOKO_MEI := g_sKIBOKO_MEI;
        -- 希望校学年
        rGKBWL673R001.KIBOKO_GAKUNEN := g_sKIBOKO_GAKUNEN;
        -- 希望変更期間
        rGKBWL673R001.KIBO_HENKO_KIKAN := g_sKIBO_HENKO_KIKAN;
        -- 申請理由
        rGKBWL673R001.SHINSEI_RIYU := REPLACE(g_sSHINSEI_RIYU, chr(13)||chr(10),'#');
        -- お問い合わせ先１
        rGKBWL673R001.TOIAWASESAKI1 := sKYOIKUKAI;
        -- お問い合わせ先２
        rGKBWL673R001.TOIAWASESAKI2 := sTOIAWASE2;
        -- お問い合わせ先３
        rGKBWL673R001.TOIAWASESAKI3 := sTOIAWASE3;
        -- 様式番号
        rGKBWL673R001.YOSHIKI_NO := rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO;
        -- 改ページキー
        rGKBWL673R001.BREAK_NO := NULL;
        -- 端末番号
        rGKBWL673R001.WSNUM := g_sWSNUM;
        -- 即時バッチ区分
        rGKBWL673R001.BATCHKBN := c_ONLINE;
        -- ジョブNO
        rGKBWL673R001.JOBNUM := g_nJOBNUM;
        FOR i IN 1..g_nHAKKOSU LOOP
            INSERT INTO GKBWL673R001 VALUES rGKBWL673R001;
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/05
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
        -- 区域外就学承諾書作成ワークのレコードの設定
        nRTN := FUNC_GET_JIDO_REC;
        IF nRTN <> 0 THEN
          RAISE ERR;
        END IF;
        -- CSV出力処理
        bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL673R001', i_sCHOHYOID);
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
    --  作成者／作成日: ZCZL.GUOXIAOZHU 2024/06/05
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
END GKBPA00100;
/
