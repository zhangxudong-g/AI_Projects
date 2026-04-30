CREATE OR REPLACE PACKAGE BODY GKBPA00160
--1.0.106.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 出入国記録照会書作成
--  機能概要      : 出入国記録照会書の即時帳票を印刷する場合に呼び出される。
--                 標準仕様の帳票レイアウトに合わせた項目を出力する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.shixinyu 2024/06/12
--------------------------------------------------------
--  変更履歴
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.001:仕様変更 IT_GKB_00001対応
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00433対応
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00633対応
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00634対応
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.006:IT_GKB_00625横展開
--  2024/11/29 ZCZL.WANGYUNING UPDATE 0.3.000.007:IT_GKB_00685横展開
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10084対応
--  2025/07/18 CTC.HJF UPDATE 1.0.010.001:GKB_QA17896対応
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
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

    --パラメータ変数
    g_nKOJIN_NO                   NUMBER;                      -- 宛名番号
    g_nNRIREKI_RENBAN             NUMBER;                      -- 履歴連番
    g_nCHOHYO_KBN                 NUMBER;                      -- 帳票区分
    g_sHAKKO_YMD                  NVARCHAR2(1000);             -- 発行年月日
    g_nKYOIKUKAI                  NUMBER;                      -- 教育委員会
    g_sBUNSHO_NO                  NVARCHAR2(1000);             -- 文書番号（リスト）
    g_nHIENTAISYOUJUSHO           NUMBER;                      -- 支援措置対象住所非表示
    g_nHAKKOBUSUU                 NUMBER;                      -- 発行部数
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00634対応
    --g_sZAIRYU_CARD_TOU_NO         NUMBER;                      -- 在留カード番号
    g_sZAIRYU_CARD_TOU_NO         NVARCHAR2(1000);             -- 在留カード番号
    g_sCHICHI_SHIMEI              NVARCHAR2(1000);             -- 父親_氏名
    g_sCHICHI_SHIMEI_KANA         NVARCHAR2(1000);             -- 父親_氏名カナ
    g_sCHICHI_KOKUSEKI            NVARCHAR2(1000);             -- 父親_国籍
    g_sCHICHI_SEINENGAPI          NVARCHAR2(1000);             -- 父親_生年月日
    g_sHAHA_SHIMEI                NVARCHAR2(1000);             -- 母親_氏名
    g_sHAHA_SHIMEI_KANA           NVARCHAR2(1000);             -- 母親_氏名カナ
    g_sHAHA_KOKUSEKI              NVARCHAR2(1000);             -- 母親_国籍
    g_sHAHA_SEINENGAPI            NVARCHAR2(1000);             -- 母親_生年月日
    g_sCHOSA_KIKAN                NVARCHAR2(1000);             -- 調査期間
    g_sTOKKIJIKO                  NVARCHAR2(1000);             -- 特記事項
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/12
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/12
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/12
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
                     g_nNRIREKI_RENBAN      := TO_NUMBER(aCSV_TBL(i));         -- 履歴連番
                WHEN 3 THEN   
                     g_nCHOHYO_KBN          := TO_NUMBER(aCSV_TBL(i));         -- 帳票区分
                WHEN 4 THEN   
                     g_sHAKKO_YMD           := aCSV_TBL(i);                    -- 発行年月日
                WHEN 5 THEN   
                     g_nKYOIKUKAI           := TO_NUMBER(aCSV_TBL(i));         -- 教育委員会
                WHEN 6 THEN   
                     g_sBUNSHO_NO           := aCSV_TBL(i);                    -- 文書番号
                WHEN 7 THEN   
                     g_nHIENTAISYOUJUSHO    := TO_NUMBER(aCSV_TBL(i));         -- 支援措置対象住所非表示
                WHEN 8 THEN   
                     g_nHAKKOBUSUU          := TO_NUMBER(aCSV_TBL(i));         -- 発行部数
                WHEN 9 THEN   
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.006:IT_GKB_00625横展開
                     --g_sZAIRYU_CARD_TOU_NO  := TO_NUMBER(aCSV_TBL(i));         -- 在留カード番号
                     g_sZAIRYU_CARD_TOU_NO  := aCSV_TBL(i);         -- 在留カード番号
                WHEN 10 THEN   
                     g_sCHICHI_SHIMEI       := aCSV_TBL(i);                    -- 父親_氏名
                WHEN 11 THEN   
                     g_sCHICHI_SHIMEI_KANA  := aCSV_TBL(i);                    -- 父親_氏名カナ
                WHEN 12 THEN   
                     g_sCHICHI_KOKUSEKI     := aCSV_TBL(i);                    -- 父親_国籍
                WHEN 13 THEN   
                     g_sCHICHI_SEINENGAPI   := aCSV_TBL(i);                    -- 父親_生年月日
                WHEN 14 THEN   
                     g_sHAHA_SHIMEI         := aCSV_TBL(i);                    -- 母親_氏名
                WHEN 15 THEN   
                     g_sHAHA_SHIMEI_KANA    := aCSV_TBL(i);                    -- 母親_氏名カナ
                WHEN 16 THEN   
                     g_sHAHA_KOKUSEKI       := aCSV_TBL(i);                    -- 母親_国籍
                WHEN 17 THEN   
                     g_sHAHA_SEINENGAPI     := aCSV_TBL(i);                    -- 母親_生年月日
                WHEN 18 THEN   
                     g_sCHOSA_KIKAN         := aCSV_TBL(i);                    -- 調査期間
                WHEN 19 THEN   
                     g_sTOKKIJIKO           := aCSV_TBL(i);                    -- 特記事項
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/12
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/12
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
    --  機能概要      : 出入国記録照会書ワークのレコードの設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu 2024/06/12
    --------------------------------------------------------
    FUNCTION FUNC_GET_REC RETURN NUMBER IS
        bRTN                    BOOLEAN;                    --戻る値
        nRTN                    PLS_INTEGER;                --戻る値
        sSQL                    VARCHAR2(5000);
        TYPE MC_CURSOR IS REF   CURSOR;                     --カーソルタイプ定義
        cCURSOR                 MC_CURSOR;
        rWLTBL                  GKBWL680R001%ROWTYPE;       --出入国記録照会書ワーク
        vKOINFILENAME           NVARCHAR2(100);             --公印ファイル名
        nDAIRIKBN               NUMBER;                     --認証者の本人・代理区分
        vKATAGAKI1              NVARCHAR2(1000);            --認証者の肩書上段
        vKATAGAKI2              NVARCHAR2(1000);            --認証者の肩書下段
        vSHIMEI                 NVARCHAR2(1000);            --認証者の氏名
        aCONSPRM                A_CONS_PRM;                 --戻るパラメータ配列
        nLENGTH                 NUMBER;                     --パラメータ配列の長度
        aCONSPRM2               A_CONS_PRM;                 --戻るパラメータ配列（宛名）
        nLENGTH2                NUMBER;                     --パラメータ配列の長度（宛名）
        rBUNNUMSRCINF           KKAPK0040.MR_BUNNUMSRCINF;  --文書番号情報（構造体）
        rBUNNUMEDITKEKA         KKAPK0040.MR_BUNNUMEDITKEKA;--文書番号編集結果
        sNUM                    NVARCHAR2(1000);            --文書番号
        sDATEED                 NVARCHAR2(1000);            --文書日付
        aITEM                   A_CONS_PRM;                 --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        sNYUUGAKU_INDEXNO       NUMBER;                     --廃校に伴う入学通知書_インデックス番号
        sSHIYUTSURYOKUSEIGYO    NVARCHAR2(1000);            --新設校・廃校に伴う入学通知書_出力制御
        rGKBTGAKUREIBOTY        GKBTGAKUREIBO%ROWTYPE;      --学齢簿情報
        rGKBTTSUCHISHOKANRITY   GKBTTSUCHISHOKANRI%ROWTYPE; --通知書管理情報
        rGKBTTSUCHIBUNMEN       GKBTTSUCHIBUNMEN%ROWTYPE;   --通知文面設定情報
        rGABTATENAKIHON         GABTATENAKIHON%ROWTYPE;     --保護者の宛名基本情報
        rGABTSOFUSAKI           GABTSOFUSAKI%ROWTYPE;       --保護者の送付先基本情報
        rGABTATENAKIHONTY       GABTATENAKIHON%ROWTYPE;     --児童の宛名情報宛名基本情報
        rGABTSOFUSAKITY         GABTSOFUSAKI%ROWTYPE;       --児童の宛名情報送付先基本情報
        nHANTEIKEKKA            PLS_INTEGER;                --抑止レベル３制御の要否（0：非該当、1：該当）
        sCTLPRM                 NVARCHAR2(500);             --住所マスク文字列
        sJIDOSHIMEIKANA         NVARCHAR2(1000);            --児童氏名カナ
        sJIDOSHIMEIKANJI        NVARCHAR2(1000);            --児童氏名
        sSEINENGAPI             NVARCHAR2(1000);            --生年月日
        sTSUCHI_BUN1            NVARCHAR2(1000);            --通知文1
        sTSUCHI_BUN2            NVARCHAR2(1000);            --通知文2
        sTSUCHI_BUN3            NVARCHAR2(1000);            --通知文3
        sTSUCHI_BUN4            NVARCHAR2(1000);            --通知文4
        sTSUCHI_BUN5            NVARCHAR2(1000);            --通知文5
        sMEISHOKANA             NVARCHAR2(1000);            --名称カナ
        sYOBI                   NVARCHAR2(1000);            --予備
        sJIDO_GENJUSHO          NVARCHAR2(1000);            --編集児童生徒現住所
        sKOKUMEI_KANA           NVARCHAR2(1000);            --国名カナ
        sKOKUMEI                NVARCHAR2(1000);            --国名
        sKOKUMEI_ALPHABET       NVARCHAR2(1000);            --国名アルファベット
        TOIAWASESAKI1           NVARCHAR2(1000);            --お問い合わせ先1
        TOIAWASESAKI2           NVARCHAR2(1000);            --お問い合わせ先2
        TOIAWASESAKI3           NVARCHAR2(1000);            --お問い合わせ先3
        sATENA                  NVARCHAR2(1000);            --宛名
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.007:IT_GKB_00685横展開
        nPRMCTL                NUMBER;
        
    BEGIN
        IF g_nCHOHYO_KBN = '38' THEN
        --公印情報を取得する
        bRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE, 0), g_sWSNUM, SYSDATE, nDAIRIKBN, vKATAGAKI1, vKATAGAKI2, vSHIMEI, vKOINFILENAME);
        END IF;
        -- 教育委員会情報を取得する
        nRTN := KKAPK0030.FPRMSHUTOKU('GKB', '00KYOIKUKAI', g_nKYOIKUKAI, aCONSPRM, nLENGTH);
        IF nRTN = 0 AND nLENGTH >= 1 THEN
          TOIAWASESAKI1 := aCONSPRM(1);
        ELSE
          TOIAWASESAKI1 := NULL;
        END IF;
        IF nRTN = 0 AND nLENGTH >= 6 THEN
          TOIAWASESAKI2 := aCONSPRM(6);
        ELSE
          TOIAWASESAKI2 := NULL;
        END IF;
        IF nRTN = 0 AND nLENGTH >= 7 THEN
          TOIAWASESAKI3 := aCONSPRM(7);
        ELSE
          TOIAWASESAKI3 := NULL;
        END IF;
        -- 宛名を編集する。
        nRTN := KKAPK0030.FPRMSHUTOKU('GKB', '00SHUTUNYUKOKU', 0, aCONSPRM2, nLENGTH2);
        IF nRTN = 0 AND nLENGTH2 >= 1 THEN
          sATENA := aCONSPRM2(1);
        ELSE
          sATENA := NULL;
        END IF;
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
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00433対応 
            --sDATEED := rBUNNUMEDITKEKA.DATEED;
            sDATEED := rBUNNUMEDITKEKA.BUNDATE;
        ELSE
            sDATEED := '';
        END IF;
        -- システム制御設定を取得する
        -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aITEM);
        --「GKB680R001」が格納されている箇所のインデックス番号
        IF nRTN = 0 THEN
          FOR i IN 1..aITEM.COUNT LOOP
            IF aITEM(i) = 'GKB680R001' THEN
              sNYUUGAKU_INDEXNO := i;
              EXIT;
            END IF;
          END LOOP;
        END IF;
        -- 「本名・通称名　出力制御」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aITEM);
        IF nRTN = 0 AND sNYUUGAKU_INDEXNO <= aITEM.COUNT THEN
          sSHIYUTSURYOKUSEIGYO := aITEM(sNYUUGAKU_INDEXNO);
        END IF;
        --通知書管理データ抽出
        BEGIN
          SELECT CHOHYO_MEI
                 ,YOSHIKI_BANGO_SETTOGO
                 ,YOSHIKI_BANGO
                 ,YOSHIKI_BANGO_SETSUBIGO
--  2024/09/26 ZCZL.WANGMING ADD START 0.3.000.001:仕様変更 IT_GKB_00001対応
                 ,TSUCHIBUN
                 ,KOIN_SHORYAKU
                 ,KOIN_CHUSHAKU
--  2024/09/26 ZCZL.WANGMING ADD END
          INTO rGKBTTSUCHISHOKANRITY.CHOHYO_MEI                             --帳票名
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO                 --様式番号接頭語
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO                         --様式番号
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO               --様式番号接尾語
--  2024/09/26 ZCZL.WANGMING ADD START 0.3.000.001:仕様変更 IT_GKB_00001対応
               ,rGKBTTSUCHISHOKANRITY.TSUCHIBUN                             --通知文
               ,rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU                         --公印省略
               ,rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU                         --公印注釈
--  2024/09/26 ZCZL.WANGMING ADD END
          FROM GKBTTSUCHISHOKANRI
          WHERE CHOHYO_KBN = g_nCHOHYO_KBN;
        EXCEPTION
          WHEN OTHERS THEN
            rGKBTTSUCHISHOKANRITY.CHOHYO_MEI := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO := NULL;
--  2024/09/26 ZCZL.WANGMING ADD START 0.3.000.001:仕様変更 IT_GKB_00001対応
            rGKBTTSUCHISHOKANRITY.TSUCHIBUN := NULL;
            rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU := NULL;
            rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU := NULL;
--  2024/09/26 ZCZL.WANGMING ADD END
        END;
--  2024/09/26 ZCZL.WANGMING DELETE START 0.3.000.001:仕様変更 IT_GKB_00001対応
--        --通知文面設定データ抽出
--        BEGIN
--          SELECT *
--          INTO rGKBTTSUCHIBUNMEN
--          FROM GKBTTSUCHIBUNMEN
--          WHERE TSUCHI_KBN = g_nCHOHYO_KBN
--                AND PATTERN_NO = '0';
--        EXCEPTION
--          WHEN OTHERS THEN
--              rGKBTTSUCHIBUNMEN := NULL;
--        END;
--  2024/09/26 ZCZL.WANGMING DELETE END
        --学齢簿データ抽出
        sSQL := '';
        sSQL := 'SELECT *';
        sSQL := sSQL || ' FROM GKBTGAKUREIBO';
        sSQL := sSQL || ' WHERE KOJIN_NO = '''||g_nKOJIN_NO||'''';
        sSQL := sSQL || ' AND RIREKI_RENBAN = '''||g_nNRIREKI_RENBAN||'''';
        OPEN cCURSOR FOR sSQL;
          LOOP
            FETCH cCURSOR INTO rGKBTGAKUREIBOTY;
            EXIT WHEN cCURSOR%NOTFOUND;
            --保護者宛名情報
            nRTN := GAAPK0030.FGETATENA2(rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(g_sHAKKO_YMD), rGABTATENAKIHON, rGABTSOFUSAKI);
            --児童生徒宛名情報
            nRTN := GAAPK0030.FGETATENA(g_nKOJIN_NO, 'GKB', TO_NUMBER(g_sHAKKO_YMD), rGABTATENAKIHONTY, rGABTSOFUSAKITY);
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
            --g_nSORT := g_nSORT + 1;
            --rWLTBL.NO := g_nSORT;                                                       --ソート順
--  2024/11/15 ZCZL.WANGYUNING UPDATE END
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10084対応 Start
            rWLTBL.ATENA := sATENA|| ' 殿';                                                     --宛名
            --  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10084対応 End
            rWLTBL.BUNSHO_NO := sNUM;                                                   --文書番号
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10084対応 START
--            rWLTBL.HAKKO_YMD := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sDATEED, 'YYYY/MM/DD'),'YYYY/MM/DD'), 10);       --発行年月日
            rWLTBL.HAKKO_YMD := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sDATEED, 'YYYY/MM/DD'),'YYYY/MM/DD'), 10),' ',''));  --発行年月日
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10084対応 END
            rWLTBL.NINSHOSHA_SHOKUSHU := vKATAGAKI1;                                    --認証者職種
            rWLTBL.NINSHOSHA_MEI := vSHIMEI;                                            --認証者名
            rWLTBL.KOIN_PATH := vKOINFILENAME;                                          --公印パス
--  2024/09/26 ZCZL.WANGMING UPDATE START 0.3.000.001:仕様変更 IT_GKB_00001対応
--            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG11 = 0 OR vKOINFILENAME IS NOT NULL THEN 
--              rWLTBL.KOIN_SHORYAKU := NULL;                                             --公印（省略）
--            ELSE
--              rWLTBL.KOIN_SHORYAKU := rGKBTTSUCHIBUNMEN.HONBUN11;                       --公印（省略）
--            END IF;
--            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG12 = 0 OR vKOINFILENAME IS NULL THEN 
--              rWLTBL.KOIN_CHUSHAKU := NULL;                                             --公印（注釈）
--            ELSE
--              rWLTBL.KOIN_CHUSHAKU := rGKBTTSUCHIBUNMEN.HONBUN12;                       --公印（注釈）
--            END IF;
--            rWLTBL.TITLE := rGKBTTSUCHISHOKANRITY.CHOHYO_MEI;                           --タイトル
--            IF rGKBTTSUCHIBUNMEN.HYODAI_SHIYO_FLG = 1 THEN
--              rWLTBL.TITLE := rGKBTTSUCHIBUNMEN.HYODAI;                                 --タイトル
--            END IF;
--            --通知文を編集する
--            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG1 = 0 THEN
--              sTSUCHI_BUN1 := rGKBTTSUCHIBUNMEN.HONBUN1;
--            ELSE
--              sTSUCHI_BUN1 := rGKBTTSUCHIBUNMEN.HONBUN1 || '#';
--            END IF;
--            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG2 = 0 THEN
--              sTSUCHI_BUN2 := rGKBTTSUCHIBUNMEN.HONBUN2;
--            ELSE
--              sTSUCHI_BUN2 := rGKBTTSUCHIBUNMEN.HONBUN2 || '#';
--            END IF;
--            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG3 = 0 THEN
--              sTSUCHI_BUN3 := rGKBTTSUCHIBUNMEN.HONBUN3;
--            ELSE
--              sTSUCHI_BUN3 := rGKBTTSUCHIBUNMEN.HONBUN3 || '#';
--            END IF;
--            IF rGKBTTSUCHIBUNMEN.HONBUN_SHIYO_FLG4 = 0 THEN
--              sTSUCHI_BUN4 := rGKBTTSUCHIBUNMEN.HONBUN4;
--            ELSE
--              sTSUCHI_BUN4 := rGKBTTSUCHIBUNMEN.HONBUN4 || '#';
--            END IF;
--            sTSUCHI_BUN5 := rGKBTTSUCHIBUNMEN.HONBUN5;
--            rWLTBL.TSUCHI_BUN := sTSUCHI_BUN1 || sTSUCHI_BUN2 || sTSUCHI_BUN3 || sTSUCHI_BUN4 || sTSUCHI_BUN5;      --通知文
              IF vKOINFILENAME IS NOT NULL THEN
                rWLTBL.KOIN_SHORYAKU := NULL;                                             --公印（省略）
              ELSE
                rWLTBL.KOIN_SHORYAKU := rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU;              --公印（省略）
              END IF;
              IF vKOINFILENAME IS NULL THEN 
                rWLTBL.KOIN_CHUSHAKU := NULL;                                             --公印（注釈）
              ELSE
                rWLTBL.KOIN_CHUSHAKU := rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU;              --公印（注釈）
              END IF;
              rWLTBL.TITLE := rGKBTTSUCHISHOKANRITY.CHOHYO_MEI;                           --タイトル
              rWLTBL.TSUCHI_BUN := REPLACE(rGKBTTSUCHISHOKANRITY.TSUCHIBUN, chr(13)||chr(10),'#');      --通知文
--  2024/09/26 ZCZL.WANGMING UPDATE END
            --照会対象記録
            IF rGABTATENAKIHONTY.JINKAKU_KBN = 0 THEN
              rWLTBL.TAISHO_KIROKU := '日本人出帰国記録';
            ELSIF rGABTATENAKIHONTY.JINKAKU_KBN = 1 THEN
              rWLTBL.TAISHO_KIROKU := '外国人出入国記録';
            END IF;
            --国籍名取得
            nRTN := GKAFKKKMGET(rGABTATENAKIHONTY.KOKUSEKI_CD, sKOKUMEI_KANA, sKOKUMEI, sKOKUMEI_ALPHABET);
            rWLTBL.JIDO_KOKUSEKI := sKOKUMEI;                                           --児童生徒国籍
            --児童生徒の本名使用制御判定
            nRTN := GKBFKHMCTRL(g_nKOJIN_NO, g_rOPRT.CHOHYOID, 0, sSHIYUTSURYOKUSEIGYO, sJIDOSHIMEIKANA, sJIDOSHIMEIKANJI, sSEINENGAPI);
            rWLTBL.JIDO_SHIMEI_KANA := sJIDOSHIMEIKANA;                                 --児童氏名カナ
            rWLTBL.JIDO_SHIMEI_KANJI := sJIDOSHIMEIKANJI;                               --児童氏名漢字
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10084対応 START
--            rWLTBL.JIDO_HYOJI_SEINENGAPI := sSEINENGAPI;                                --表示生年月日
            rWLTBL.JIDO_HYOJI_SEINENGAPI := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(rGABTATENAKIHONTY.SEINENGAPI,1,3),' ',''));  --表示生年月日（西暦）
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10084対応 END
            --児童生徒性別
            nRTN := KKAPK0030.FCDGetR('GKB', '021', '0001', rGABTATENAKIHONTY.SEIBETSU, rWLTBL.JIDO_SEIBETSU, sMEISHOKANA, sYOBI);
            --児童生徒現住所を編集する
            sJIDO_GENJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, rGABTATENAKIHONTY.CHOMEI, rGABTATENAKIHONTY.BANCHI, rGABTATENAKIHONTY.KATAGAKI, NULL);
--  2024/11/29 ZCZL.WANGYUNING ADD START 0.3.000.007:IT_GKB_00685横展開
            rWLTBL.JIDO_GENJUSHO := sJIDO_GENJUSHO;
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
            -- sCTLPRM := GAAPK0030.FDVJUSHO('GKB', g_nKOJIN_NO,  g_sTANTOCODE, g_sWSNUM, sJIDO_GENJUSHO, nPRMCTL, 2);
--  2024/11/29 ZCZL.WANGYUNING ADD END
            IF g_nHIENTAISYOUJUSHO = 1 THEN
                sCTLPRM := GKBPK00010.FGETJUSHOMSG();
              --学齢簿.児童生徒宛名番号でDV判定
              --住所マスク文字列
--  2024/11/29 ZCZL.WANGYUNING UPDATE START 0.3.000.007:IT_GKB_00685横展開
--              sCTLPRM := GAAPK0030.FDVJUSHO('GKB', g_nKOJIN_NO, g_sTANTOCODE, g_sWSNUM, sJIDO_GENJUSHO, nHANTEIKEKKA, 2, NULL, NULL);
              -- IF nPRMCTL = '1' THEN
                rWLTBL.JIDO_GENJUSHO := sCTLPRM;                                         --児童生徒現住所
              -- END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
--  2024/11/29 ZCZL.WANGYUNING UPDATE END
            ELSE
              rWLTBL.JIDO_GENJUSHO := sJIDO_GENJUSHO;
            END IF;
            rWLTBL.ZAIRYU_CARD_TOU_NO := g_sZAIRYU_CARD_TOU_NO;                         -- 在留カード番号
            rWLTBL.CHICHI_KOKUSEKI := g_sCHICHI_KOKUSEKI;                               -- 父親_国籍
            rWLTBL.CHICHI_SEINENGAPI := g_sCHICHI_SEINENGAPI;                           -- 父親_生年月日
            rWLTBL.CHICHI_SHIMEI_KANA := g_sCHICHI_SHIMEI_KANA;                         -- 父親_氏名カナ
            rWLTBL.CHICHI_SHIMEI_KANJI := g_sCHICHI_SHIMEI;                             -- 父親_氏名
            rWLTBL.HAHA_KOKUSEKI := g_sHAHA_KOKUSEKI;                                   -- 母親_国籍
            rWLTBL.HAHA_SEINENGAPI := g_sHAHA_SEINENGAPI;                               -- 母親_生年月日
            rWLTBL.HAHA_SHIMEI_KANA := g_sHAHA_SHIMEI_KANA;                             -- 母親_氏名カナ
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00633対応
            --rWLTBL.HAHA_SHIMEI_KANJI := g_sCHICHI_SHIMEI;                               -- 母親_氏名
            rWLTBL.HAHA_SHIMEI_KANJI := g_sHAHA_SHIMEI;                               -- 母親_氏名
            rWLTBL.CHOSA_KIKAN := g_sCHOSA_KIKAN;                                       -- 調査期間
            rWLTBL.TENPU_RENRAKU := g_sTOKKIJIKO;                                       -- 添付物連絡文
            rWLTBL.TOIAWASESAKI1 := TOIAWASESAKI1;                                      --お問い合わせ先1
            rWLTBL.TOIAWASESAKI2 := TOIAWASESAKI2;                                      --お問い合わせ先2
            rWLTBL.TOIAWASESAKI3 := TOIAWASESAKI3;                                      --お問い合わせ先3
            --様式番号
            rWLTBL.YOSHIKI_NO := rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
            rWLTBL.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rWLTBL.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
            rWLTBL.BREAK_NO := NULL;                                                    --改ページキー
            rWLTBL.WSNUM := g_sWSNUM;                                                   --端末番号
            rWLTBL.BATCHKBN := c_ONLINE;                                                --即時バッチ区分
            rWLTBL.JOBNUM := g_nJOBNUM;                                                 --ジョブNO
            FOR i IN 1..g_nHAKKOBUSUU LOOP
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
               g_nSORT := g_nSORT + 1;
               rWLTBL.NO := g_nSORT;                                                       --ソート順
--  2024/11/15 ZCZL.WANGYUNING UPDATE END
              --登録ワークテーブル
              INSERT INTO GKBWL680R001 VALUES rWLTBL;
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
    END FUNC_GET_REC;
    --------------------------------------------------------
    --  機能概要      : メインビジネスロジック処理
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu 2024/06/12
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
        DELETE FROM GKBWL680R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
        -- 出入国記録照会書ワークのレコードの設定
        nRTN := FUNC_GET_REC;
        IF nRTN <> 0 THEN
          RAISE ERR;
        END IF;
        -- CSV出力処理
        bRTN := FUNC_O20CSV (i_sGYOUMUCODE, 'GKBWL680R001', i_sCHOHYOID);
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/12
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
END GKBPA00160;
/
