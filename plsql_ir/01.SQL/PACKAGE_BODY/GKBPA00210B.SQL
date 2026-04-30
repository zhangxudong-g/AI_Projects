CREATE OR REPLACE PACKAGE BODY GKBPA00210
--1.0.106.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 入学予定通知書作成
--  機能概要      : 入学予定通知書の即時帳票を印刷する場合に呼び出される。
--                 入学予定通知書を出力する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.shixinyu 2024/06/03
--------------------------------------------------------
--  変更履歴
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.001:IT_GKB_00433対応
--  2024/11/15 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00539横展開対応
--  2024/11/29 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00685横展開
--  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.004:IT_GKB_10071仕様変更対応
--  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.005:IT_GKB_10072仕様変更対応
--  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.006:IT_GKB_10073仕様変更対応
--  2024/12/20 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.007:IT_GKB_10117仕様変更対応
--  2024/12/23 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.008:IT_GKB_10070仕様変更対応
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
    g_sHAKKO_YMD                  NVARCHAR2(1000);             -- 発送日
    g_nATESAKI                    NUMBER;                      -- 宛先
    g_nKYOIKUKAI                  NUMBER;                      -- 教育委員会
    g_sBUNSHO_NO                  NVARCHAR2(1000);             -- 文書番号
    g_nHIENTAISYOUJUSHO           NUMBER;                      -- 支援措置対象住所非表示
    g_nHAKKOBUSUU                 NUMBER;                      -- 発行部数
    g_sSHUGAKUYOTEIKO             NVARCHAR2(1000);             -- 就学予定校
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/03
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/03
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/03
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
                     g_nKOJIN_NO          := TO_NUMBER(aCSV_TBL(i));         -- 宛名番号
                WHEN 2 THEN
                     g_nNRIREKI_RENBAN    := TO_NUMBER(aCSV_TBL(i));         -- 履歴連番
                WHEN 3 THEN
                     g_nCHOHYO_KBN        := TO_NUMBER(aCSV_TBL(i));         -- 帳票区分
                WHEN 4 THEN
                     g_sHAKKO_YMD         := aCSV_TBL(i);                    -- 発送日
                WHEN 5 THEN
                     g_nATESAKI           := TO_NUMBER(aCSV_TBL(i));         -- 宛先
                WHEN 6 THEN
                     g_nKYOIKUKAI         := TO_NUMBER(aCSV_TBL(i));         -- 教育委員会
                WHEN 7 THEN
                     g_sBUNSHO_NO         := aCSV_TBL(i);                    -- 文書番号
                WHEN 8 THEN
                     g_nHIENTAISYOUJUSHO  := TO_NUMBER(aCSV_TBL(i));         -- 支援措置対象住所非表示
                WHEN 9 THEN
                     g_nHAKKOBUSUU        := TO_NUMBER(aCSV_TBL(i));         -- 発行部数
                WHEN 10 THEN
                     g_sSHUGAKUYOTEIKO    := aCSV_TBL(i);                    -- 就学予定校
                WHEN 11 THEN
                     g_sTOKKIJIKO         := aCSV_TBL(i);                    -- 特記事項
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/03
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/03
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
    --  機能概要      : 入学予定通知書ワークのレコードの設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC RETURN NUMBER IS
        bRTN                    BOOLEAN;                    --戻る値
        nRTN                    PLS_INTEGER;                --戻る値
        sSQL                    VARCHAR2(5000);
        TYPE MC_CURSOR IS REF   CURSOR;                     --カーソルタイプ定義
        cCURSOR                 MC_CURSOR;
        rWLTBL                  GKBWL701R001%ROWTYPE;       --入学予定通知書ワーク
        vKOINFILENAME           NVARCHAR2(100);             --公印ファイル名
        o_nDAIRIKBN             NUMBER;                     --認証者の本人・代理区分
        o_vKATAGAKI1            NVARCHAR2(1000);            --認証者の肩書上段
        o_vKATAGAKI2            NVARCHAR2(1000);            --認証者の肩書下段
        o_vSHIMEI               NVARCHAR2(1000);            --認証者の氏名
        aCONSPRM                A_CONS_PRM;                 --戻るパラメータ配列
        nLENGTH                 NUMBER;                     --パラメータ配列の長度
        o_tITEM                 A_CONS_PRM;                 --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        sNYUUGAKU_INDEXNO       NUMBER;                     --入学予定通知書_インデックス番号
        sSHIYUTSURYOKUSEIGYO    NVARCHAR2(1000);            --入学予定通知書_出力制御
        rGKBTGAKUREIBOTY        GKBTGAKUREIBO%ROWTYPE;      --学齢簿情報
        rGKBTTSUCHISHOKANRITY   GKBTTSUCHISHOKANRI%ROWTYPE; --通知書管理情報
        rGABTATENAKIHON         GABTATENAKIHON%ROWTYPE;     --宛名基本情報
        rGABTSOFUSAKI           GABTSOFUSAKI%ROWTYPE;       --送付先基本情報
        nHANTEIKEKKA            PLS_INTEGER;                --抑止レベル３制御の要否（0：非該当、1：該当）
        sCTLPRM                 NVARCHAR2(500);             --住所マスク文字列
        rGKBTCHUGAKKO           GKBTCHUGAKKO%ROWTYPE;       --中学校名情報
        rGKBTSHOGAKKO           GKBTSHOGAKKO%ROWTYPE;       --小学校名情報
        sJIDOSHIMEIKANA         NVARCHAR2(1000);            --児童氏名カナ
        sJIDOSHIMEIKANJI        NVARCHAR2(1000);            --児童氏名
        sSEINENGAPI             NVARCHAR2(1000);            --生年月日
        sHOGOSHASHIMEIKANA      NVARCHAR2(1000);            --保護者氏名カナ
        sHOGOSHASHIMEIKANJI     NVARCHAR2(1000);            --保護者氏名
        TOIAWASESAKI1           NVARCHAR2(1000);            --お問い合わせ先1
        TOIAWASESAKI2           NVARCHAR2(1000);            --お問い合わせ先2
        TOIAWASESAKI3           NVARCHAR2(1000);            --お問い合わせ先3
        rBUNNUMSRCINF           KKAPK0040.MR_BUNNUMSRCINF;  --文書番号情報（構造体）
        rBUNNUMEDITKEKA         KKAPK0040.MR_BUNNUMEDITKEKA;--文書番号編集結果
        sNUM                    NVARCHAR2(1000);            --文書番号
        sDATEED                 NVARCHAR2(1000);            --文書日付
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.003:IT_GKB_00685横展開
        nPRMCTL                NUMBER;
        --  2024/12/23 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.008:IT_GKB_10070仕様変更対応 START
        sYUBIN_NO              NVARCHAR2(1000);             --郵便番号
        sCHOMEI                NVARCHAR2(1000);             --町名
        sBANCHI                NVARCHAR2(1000);             --番地
        sKATAGAKI              NVARCHAR2(1000);             --方書
        sYUBIN_NOBC            NVARCHAR2(1000);             --カスタマーバーコード
        --  2024/12/23 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.008:IT_GKB_10070仕様変更対応 END
        
        BEGIN
          -- 公印情報を取得する
        IF g_nCHOHYO_KBN = 33 OR g_nCHOHYO_KBN = 34 THEN
          bRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE, 0), g_sWSNUM, SYSDATE, o_nDAIRIKBN, o_vKATAGAKI1, o_vKATAGAKI2, o_vSHIMEI, vKOINFILENAME);
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
        -- システム制御設定を取得する
        -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, o_tITEM);
        --「GKB701R001」が格納されている箇所のインデックス番号
        IF nRTN = 0 THEN
          FOR i IN 1..o_tITEM.COUNT LOOP
            IF o_tITEM(i) = 'GKB701R001' THEN
              sNYUUGAKU_INDEXNO := i;
              EXIT;
            END IF;
          END LOOP;
        END IF;
        -- 「本名・通称名　出力制御」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, o_tITEM);
        IF nRTN = 0 AND sNYUUGAKU_INDEXNO <= o_tITEM.COUNT THEN
          sSHIYUTSURYOKUSEIGYO := o_tITEM(sNYUUGAKU_INDEXNO);
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
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.001:IT_GKB_00433対応
            --sDATEED := rBUNNUMEDITKEKA.DATEED;
            sDATEED := rBUNNUMEDITKEKA.BUNDATE;
        ELSE
            sDATEED := '';
        END IF;
        --通知書管理データ抽出
        BEGIN
          SELECT CHOHYO_MEI
                 ,KOIN_SHORYAKU
                 ,KOIN_CHUSHAKU
                 ,TSUCHIBUN
                 ,YOSHIKI_BANGO_SETTOGO
                 ,YOSHIKI_BANGO
                 ,YOSHIKI_BANGO_SETSUBIGO
          INTO rGKBTTSUCHISHOKANRITY.CHOHYO_MEI                                --帳票名
               ,rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU                            --公印省略
               ,rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU                            --公印注釈
               ,rGKBTTSUCHISHOKANRITY.TSUCHIBUN                                --通知文
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO                    --様式番号接頭語
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO                            --様式番号
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO                  --様式番号接尾語
          FROM GKBTTSUCHISHOKANRI
          WHERE CHOHYO_KBN = g_nCHOHYO_KBN;
        EXCEPTION
          WHEN OTHERS THEN
            rGKBTTSUCHISHOKANRITY.CHOHYO_MEI := NULL;
            rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU := NULL;
            rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU := NULL;
            rGKBTTSUCHISHOKANRITY.TSUCHIBUN := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO := NULL;
        END;
        --学齢簿データ抽出
        sSQL := '';
        sSQL := sSQL || 'SELECT KOJIN_NO';
        sSQL := sSQL || '       ,TSUSHOMEI_KANA';
        sSQL := sSQL || '       ,TSUSHOMEI_KANJI';
        sSQL := sSQL || '       ,HOGOSYA_KOJIN_NO';
        sSQL := sSQL || '       ,HOGOSYA_TSUSHOMEI_KANA';
        sSQL := sSQL || '       ,HOGOSYA_TSUSHOMEI_KANJI';
        sSQL := sSQL || ' FROM GKBTGAKUREIBO';
        sSQL := sSQL || ' WHERE KOJIN_NO = '''||g_nKOJIN_NO||'''';
        sSQL := sSQL || ' AND RIREKI_RENBAN = '''||g_nNRIREKI_RENBAN||'''';
        OPEN cCURSOR FOR sSQL;
        LOOP
            FETCH cCURSOR INTO rGKBTGAKUREIBOTY.KOJIN_NO                      --宛名番号
                               ,rGKBTGAKUREIBOTY.TSUSHOMEI_KANA               --通称名カナ
                               ,rGKBTGAKUREIBOTY.TSUSHOMEI_KANJI              --通称名
                               ,rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO             --保護者宛名番号
                               ,rGKBTGAKUREIBOTY.HOGOSYA_TSUSHOMEI_KANA       --保護者通称名カナ
                               ,rGKBTGAKUREIBOTY.HOGOSYA_TSUSHOMEI_KANJI;     --保護者通称名
            EXIT WHEN cCURSOR%NOTFOUND;
            --  2024/11/15 ZCZL.ZHANGLEI DEL START 0.3.000.002:IT_GKB_00539横展開対応
            --g_nSORT := g_nSORT + 1;
            --rWLTBL.NO := g_nSORT;                                             --ソート順
            --  2024/11/15 ZCZL.ZHANGLEI DEL END
            --保護者の基本情報
            nRTN := GAAPK0030.FGETATENA(rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(REPLACE(g_sHAKKO_YMD,'/','')), rGABTATENAKIHON, rGABTSOFUSAKI);
            --保護者の本名使用制御判定
            nRTN := GKBFKHMCTRL(g_nKOJIN_NO, g_rOPRT.CHOHYOID, 1, sSHIYUTSURYOKUSEIGYO, sHOGOSHASHIMEIKANA, sHOGOSHASHIMEIKANJI, sSEINENGAPI);
            IF g_nATESAKI = 0 THEN
              --  2024/12/23 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.008:IT_GKB_10070仕様変更対応 START
              --保護者の送付先がNULLの場合、 保護者の宛名基本が利用
              IF rGABTSOFUSAKI.KOJIN_NO IS NULL THEN
                sYUBIN_NO   := rGABTATENAKIHON.YUBIN_NO;      --宛名基本の郵便番号
                sCHOMEI     := rGABTATENAKIHON.CHOMEI;        --宛名基本の町名
                sBANCHI     := rGABTATENAKIHON.BANCHI;        --宛名基本の番地
                sKATAGAKI   := rGABTATENAKIHON.KATAGAKI;      --宛名基本の方書
                sYUBIN_NOBC := rGABTATENAKIHON.YUBIN_NOBC;    --宛名基本のカスタマーバーコード
              ELSE  
                sYUBIN_NO   := rGABTSOFUSAKI.YUBIN_NO;        --宛名基本の郵便番号
                sCHOMEI     := rGABTSOFUSAKI.CHOMEI;          --宛名基本の町名
                sBANCHI      := rGABTSOFUSAKI.BANCHI;          --宛名基本の番地
                sKATAGAKI   := rGABTSOFUSAKI.KATAGAKI;        --宛名基本の方書
                sYUBIN_NOBC := rGABTSOFUSAKI.YUBIN_NOBC;      --宛名基本のカスタマーバーコード
              END IF;
              --郵便番号編集処理
              --nRTN := KKAPK0010.FYUBINHENSHU(rGABTSOFUSAKI.YUBIN_NO, rWLTBL.YUBIN_NO);
              --rWLTBL.YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(rWLTBL.YUBIN_NO, 0);     --郵便番号
              --住所
              --rWLTBL.JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, rGABTSOFUSAKI.CHOMEI, rGABTSOFUSAKI.BANCHI, NULL, NULL);
              --rWLTBL.KATAGAKI := rGABTSOFUSAKI.KATAGAKI;                      --方書
              --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.006:IT_GKB_10073仕様変更対応　START
              --rWLTBL.BC_NO := rGABTSOFUSAKI.YUBIN_NOBC;                       --カスタマーバーコード
              --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.006:IT_GKB_10073仕様変更対応　END
               --郵便番号編集処理
              nRTN := KKAPK0010.FYUBINHENSHU(sYUBIN_NO, rWLTBL.YUBIN_NO);
              rWLTBL.YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(rWLTBL.YUBIN_NO, 0);     --郵便番号
              --住所
              rWLTBL.JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, sCHOMEI, sBANCHI, NULL, NULL);
              rWLTBL.KATAGAKI := sKATAGAKI;                      --方書
              rWLTBL.BC_NO := sYUBIN_NOBC;                       --カスタマーバーコード
              ----  2024/12/23 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.008:IT_GKB_10070仕様変更対応 END 
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.003:IT_GKB_00685横展開
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
              --sCTLPRM := GAAPK0030.FDVJUSHO('GKB',g_nKOJIN_NO,g_sTANTOCODE,g_sWSNUM,rWLTBL.JUSHO,nPRMCTL,2);
              IF g_nHIENTAISYOUJUSHO = 1 THEN
                sCTLPRM := GKBPK00010.FGETJUSHOMSG();
                --学齢簿.保護者宛名番号でDV判定
                --住所マスク文字列
--  2024/11/29 ZCZL.WANGYUNING UPDATE START 0.3.000.003:IT_GKB_00685横展開
--                sCTLPRM := GAAPK0030.FDVJUSHO('GKB', rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, rWLTBL.JUSHO, nHANTEIKEKKA, 2, NULL, NULL);
--                rWLTBL.JUSHO := sCTLPRM;                                      --住所
--                IF nHANTEIKEKKA = 1 THEN
--                  rWLTBL.KATAGAKI := NULL;                                    --方書
--                END IF;
--  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.006:IT_GKB_10073仕様変更対応　START
                -- IF nPRMCTL = 1 THEN
--  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.006:IT_GKB_10073仕様変更対応　END
                  rWLTBL.JUSHO := sCTLPRM;                            --住所
                  rWLTBL.KATAGAKI := NULL;                                    --方書
                  --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.006:IT_GKB_10073仕様変更対応　START
                  rWLTBL.YUBIN_NO := NULL;                           --郵便番号
                  rWLTBL.BC_NO := NULL;                              --カスタマーバーコード
                  --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.006:IT_GKB_10073仕様変更対応　END
                -- END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
--  2024/11/29 ZCZL.WANGYUNING UPDATE END
              END IF;
              rWLTBL.ATENA := sHOGOSHASHIMEIKANJI || '　' || '様';             --宛名
              --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.006:IT_GKB_10073仕様変更対応　START
              --rWLTBL.BC_NO := rGABTSOFUSAKI.YUBIN_NOBC;                       --カスタマーバーコード
              --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.006:IT_GKB_10073仕様変更対応　END
            ELSE
              rWLTBL.YUBIN_NO := NULL;                                        --郵便番号
              BEGIN
                --中学校名マスタから学校の住所取得
                SELECT JUSHO
                INTO rGKBTCHUGAKKO.JUSHO
                FROM GKBTCHUGAKKO
                WHERE GKBTCHUGAKKO.TYUGAKO_CD = g_sSHUGAKUYOTEIKO;
                rWLTBL.JUSHO := rGKBTCHUGAKKO.JUSHO;
              EXCEPTION
                WHEN OTHERS THEN
                  BEGIN
                  --小学校名マスタから学校の住所取得
                  SELECT JUSHO
                  INTO rGKBTSHOGAKKO.JUSHO
                  FROM GKBTSHOGAKKO
                  WHERE GKBTSHOGAKKO.SYOGAKO_CD = g_sSHUGAKUYOTEIKO;
                  rWLTBL.JUSHO := rGKBTSHOGAKKO.JUSHO;
                  EXCEPTION
                    WHEN OTHERS THEN
                      rWLTBL.JUSHO := NULL;
                  END;
              END;
              rWLTBL.KATAGAKI := NULL;                                         --方書
              --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.005:IT_GKB_10072仕様変更対応　START
              --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.007:IT_GKB_10117仕様変更対応　START
              rWLTBL.ATENA := g_sSHUGAKUYOTEIKO || '長' || '　' || '様';  --宛名
              --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.007:IT_GKB_10117仕様変更対応　END
              --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.005:IT_GKB_10072仕様変更対応　END
              rWLTBL.BC_NO := NULL;                                            --カスタマーバーコード
            END IF;
            rWLTBL.BUNSHO_NO := sNUM;                                          --文書番号
            --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.004:IT_GKB_10071仕様変更対応　START
            rWLTBL.SOFU_YMD := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sDATEED, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10),' ',''));         --送付日
            --  2024/12/18 JPJYS.ZHANGYUNSONG   UPDATE 0.3.030.004:IT_GKB_10071仕様変更対応　END
            rWLTBL.KYOIKUKAI_MEI := o_vKATAGAKI1;                              --教育委員会名
            rWLTBL.KYOIKU_CHO_MEI := o_vSHIMEI;                                --教育委員会長
            rWLTBL.KOIN_PATH := vKOINFILENAME;                                 --公印
            IF vKOINFILENAME IS NULL THEN
              rWLTBL.KOIN_SHORYAKU := rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU;     --公印（省略）
              rWLTBL.KOIN_CHUSHAKU := NULL;                                    --公印（注釈）
            ELSE
              rWLTBL.KOIN_SHORYAKU := NULL;                                    --公印（省略）
              rWLTBL.KOIN_CHUSHAKU := rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU;     --公印（注釈）
            END IF;
            rWLTBL.TITLE := rGKBTTSUCHISHOKANRITY.CHOHYO_MEI;                  --タイトル
            rWLTBL.TSUCHIBUN := REPLACE(rGKBTTSUCHISHOKANRITY.TSUCHIBUN, chr(13)||chr(10),'#');               --通知文
            --児童生徒の本名使用制御判定
            nRTN := GKBFKHMCTRL(g_nKOJIN_NO, g_rOPRT.CHOHYOID, 0, sSHIYUTSURYOKUSEIGYO, sJIDOSHIMEIKANA, sJIDOSHIMEIKANJI, sSEINENGAPI);
            rWLTBL.JIDO_SHIMEI_KANA := sJIDOSHIMEIKANA;                        --児童氏名カナ
            rWLTBL.JIDO_SHIMEI_KANJI := sJIDOSHIMEIKANJI;                      --児童氏名
            rWLTBL.SEINENGAPI := sSEINENGAPI;                                  --生年月日
            rWLTBL.HOGOSHA_SHIMEI_KANA := sHOGOSHASHIMEIKANA;                  --保護者氏名カナ
            rWLTBL.HOGOSHA_SHIMEI_KANJI := sHOGOSHASHIMEIKANJI;                --保護者氏名
            rWLTBL.SHUGAKUYOTEIKO := g_sSHUGAKUYOTEIKO;                        --就学予定校
            rWLTBL.TOKKIJIKO := g_sTOKKIJIKO;                                  --特記事項
            rWLTBL.TOIAWASESAKI1 := TOIAWASESAKI1;                             --お問い合わせ先1
            rWLTBL.TOIAWASESAKI2 := TOIAWASESAKI2;                             --お問い合わせ先2
            rWLTBL.TOIAWASESAKI3 := TOIAWASESAKI3;                             --お問い合わせ先3
            --様式番号
            rWLTBL.YOSHIKI_NO := rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO;
            rWLTBL.BREAK_NO := NULL;                                           --改ページキー
            rWLTBL.WSNUM := g_sWSNUM;                                          --端末番号
            rWLTBL.BATCHKBN := c_ONLINE;                                       --即時バッチ区分
            rWLTBL.JOBNUM := g_nJOBNUM;                                        --ジョブNO
            FOR i IN 1..g_nHAKKOBUSUU LOOP
              --  2024/11/15 ZCZL.ZHANGLEI ADD START 0.3.000.002:IT_GKB_00539横展開対応
              g_nSORT := g_nSORT + 1;
              rWLTBL.NO := g_nSORT;                                             --ソート順
              --  2024/11/15 ZCZL.ZHANGLEI ADD END
              --登録ワークテーブル
              INSERT INTO GKBWL701R001 VALUES rWLTBL;
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/03
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
        -- 初期化
        DELETE FROM GKBWL701R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
        -- 入学予定通知書ワークのレコードの設定
        nRTN := FUNC_GET_JIDO_REC;
        IF nRTN <> 0 THEN
          RAISE ERR;
        END IF;
        -- CSV出力処理
        bRTN := FUNC_O20CSV (i_sGYOUMUCODE, 'GKBWL701R001', i_sCHOHYOID);
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理終了');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            g_sMESSAGE := SQLCODE || SUBSTR(SQLERRM, 1, 250);
            bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 1, 0, SQLCODE, SQLERRM, '異常終了:' || REPLACE(DBMS_UTILITY.format_error_backtrace, '"', ''));
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/03
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
END GKBPA00210;
/