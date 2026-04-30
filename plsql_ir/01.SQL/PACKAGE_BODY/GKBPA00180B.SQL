CREATE OR REPLACE PACKAGE BODY GKBPA00180
--1.0.106.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 新設校・廃校に伴う入学通知書作成
--  機能概要      : 個人番号をキーにして新設校・廃校に伴う入学通知書を出力する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.shixinyu 2024/06/06
--------------------------------------------------------
--  変更履歴
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.001:IT_GKB_00433対応
--  2024/11/12 ZCZL.WANGYUNING UPDATE 0.3.000.002:仕様変更IT_GKB_00475対応
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
--  2024/11/26 ZCZL.WANGYUNING UPDATE 0.3.000.004:仕様変更IT_GKB_00660対応
--  2024/11/29 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00685横展開
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00729対応
--  2024/12/11 JPJYS.LIUJUNHAO UPDATE 0.3.000.007:品質強化　IT_GKB_00028対応
--  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化　IT_GKB_10087、IT_GKB_10088、IT_GKB_10089対応
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
    g_sHAKKO_YMD                  NVARCHAR2(1000);             -- 発送日
    g_nATESAKI                    NUMBER;                      -- 宛先
    g_nKYOIKUKAI                  NUMBER;                      -- 教育委員会
    g_sBUNSHO_NO                  NVARCHAR2(1000);             -- 文書番号
    g_nHIENTAISYOUJUSHO           NUMBER;                      -- 支援措置対象住所非表示
    g_nHAKKOBUSUU                 NUMBER;                      -- 発行部数
    g_sNYUGAKUKO_MEI              NVARCHAR2(1000);             -- 入学校名
    g_sNYUGAKUKO_GAKUNEN          NVARCHAR2(1000);             -- 入学校名_学年
    g_sNYUGAKU_KIJITU             NVARCHAR2(1000);             -- 入学期日
    g_sTOKKIJIKO                  NVARCHAR2(1000);             -- 特記事項
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00729対応  START       
    NYUGAKU_KIJITU_OUT NVARCHAR2(120);                         -- 入学期日
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00729対応  END  
    
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/06
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/06
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/06
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
                     g_sNYUGAKUKO_MEI       := aCSV_TBL(i);                    -- 入学校名
                WHEN 11 THEN   
                     g_sNYUGAKUKO_GAKUNEN   := aCSV_TBL(i);                    -- 入学校名_学年
                WHEN 12 THEN  
                --  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00729対応  START 
                     --g_sNYUGAKU_KIJITU      := aCSV_TBL(i);                    -- 入学期日
                     g_sNYUGAKU_KIJITU          := TO_NUMBER(aCSV_TBL(i));       -- 入学期日
                --  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00729対応  END 
                WHEN 13 THEN   
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/06
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/06
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
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00729対応 START      
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
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00729対応 END  
    --------------------------------------------------------
    --  機能概要      : 新設校・廃校に伴う入学通知書ワークのレコードの設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu 2024/06/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC RETURN NUMBER IS
        bRTN                    BOOLEAN;                    --戻る値
        nRTN                    PLS_INTEGER;                --戻る値
        sSQL                    VARCHAR2(5000);
        TYPE MC_CURSOR IS REF   CURSOR;                     --カーソルタイプ定義
        cCURSOR                 MC_CURSOR;
        rWLTBL                  GKBWL690R001%ROWTYPE;       --新設校・廃校に伴う入学通知書ワーク
        vKOINFILENAME           NVARCHAR2(100);             --公印ファイル名
        nDAIRIKBN               NUMBER;                     --認証者の本人・代理区分
        vKATAGAKI1              NVARCHAR2(1000);            --認証者の肩書上段
        vKATAGAKI2              NVARCHAR2(1000);            --認証者の肩書下段
        vSHIMEI                 NVARCHAR2(1000);            --認証者の氏名
        aCONSPRM                A_CONS_PRM;                 --戻るパラメータ配列
        nLENGTH                 NUMBER;                     --パラメータ配列の長度
        aITEM                   A_CONS_PRM;                 --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        sNYUUGAKU_INDEXNO       NUMBER;                     --廃校に伴う入学通知書_インデックス番号
        sSHIYUTSURYOKUSEIGYO    NVARCHAR2(1000);            --新設校・廃校に伴う入学通知書_出力制御
        rGKBTGAKUREIBOTY        GKBTGAKUREIBO%ROWTYPE;      --学齢簿情報
        rGKBTTSUCHISHOKANRITY   GKBTTSUCHISHOKANRI%ROWTYPE; --通知書管理情報
        rGABTATENAKIHON         GABTATENAKIHON%ROWTYPE;     --保護者の宛名基本情報
        rGABTSOFUSAKI           GABTSOFUSAKI%ROWTYPE;       --保護者の送付先基本情報
        rGABTATENAKIHONTY       GABTATENAKIHON%ROWTYPE;     --児童の宛名情報宛名基本情報
        rGABTSOFUSAKITY         GABTSOFUSAKI%ROWTYPE;       --児童の宛名情報送付先基本情報
        nHANTEIKEKKA            PLS_INTEGER;                --抑止レベル３制御の要否（0：非該当、1：該当）
        sCTLPRM                 NVARCHAR2(500);             --住所マスク文字列
        sJIDOSHIMEIKANA         NVARCHAR2(1000);            --児童氏名カナ
        sJIDOSHIMEIKANJI        NVARCHAR2(1000);            --児童氏名
        sSEINENGAPI             NVARCHAR2(1000);            --生年月日
        TOIAWASESAKI1           NVARCHAR2(1000);            --お問い合わせ先1
        TOIAWASESAKI2           NVARCHAR2(1000);            --お問い合わせ先2
        TOIAWASESAKI3           NVARCHAR2(1000);            --お問い合わせ先3
        rBUNNUMSRCINF           KKAPK0040.MR_BUNNUMSRCINF;  --文書番号情報（構造体）
        rBUNNUMEDITKEKA         KKAPK0040.MR_BUNNUMEDITKEKA;--文書番号編集結果
        sNUM                    NVARCHAR2(1000);            --文書番号
        sDATEED                 NVARCHAR2(1000);            --文書日付
--  2024/12/11 JPJYS.LIUJUNHAO UPDATE 0.3.000.007:品質強化　IT_GKB_00028対応 Start
        sHOGOSHAKANA            NVARCHAR2(1000);            --保護者カナ
        sHOGOSHAKANJI           NVARCHAR2(1000);            --保護者漢字
        sHOGOSHASEINENGAPI      NVARCHAR2(1000);            --保護者生年月日
--  2024/12/11 JPJYS.LIUJUNHAO UPDATE 0.3.000.007:品質強化　IT_GKB_00028対応 End        
        
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00685横展開
        nPRMCTL                NUMBER;
    BEGIN
        --公印情報を取得する
        bRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE, 0), g_sWSNUM, SYSDATE, nDAIRIKBN, vKATAGAKI1, vKATAGAKI2, vSHIMEI, vKOINFILENAME);
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
          SELECT KOIN_SHORYAKU
                 ,KOIN_CHUSHAKU
                 ,TSUCHIBUN
                 ,YOSHIKI_BANGO_SETTOGO
                 ,YOSHIKI_BANGO
                 ,YOSHIKI_BANGO_SETSUBIGO
--  2024/11/12 ZCZL.WANGYUNING ADD 0.3.000.002:仕様変更IT_GKB_00475対応
                 ,CHOHYO_MEI
          INTO rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU                             --公印省略
               ,rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU                            --公印注釈
               ,rGKBTTSUCHISHOKANRITY.TSUCHIBUN                                --通知文
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO                    --様式番号接頭語
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO                            --様式番号
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO                  --様式番号接尾語
--  2024/11/12 ZCZL.WANGYUNING ADD 0.3.000.002:仕様変更IT_GKB_00475対応
               ,rGKBTTSUCHISHOKANRITY.CHOHYO_MEI
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
--  2024/11/12 ZCZL.WANGYUNING ADD 0.3.000.002:仕様変更IT_GKB_00475対応
            rGKBTTSUCHISHOKANRITY.CHOHYO_MEI := NULL;
        END;
        -- お問い合わせ先情報を取得する
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
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aITEM);
        --「GKB690R001」が格納されている箇所のインデックス番号
        IF nRTN = 0 THEN
          FOR i IN 1..aITEM.COUNT LOOP
            IF aITEM(i) = 'GKB690R001' THEN
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
        --学齢簿データ抽出
        sSQL := '';
        sSQL := sSQL || 'SELECT TSUSHOMEI_KANA';
        sSQL := sSQL || '       ,TSUSHOMEI_KANJI';
        sSQL := sSQL || '       ,HOGOSYA_TSUSHOMEI_KANA';
        sSQL := sSQL || '       ,HOGOSYA_TSUSHOMEI_KANJI';
        sSQL := sSQL || '       ,HOGOSYA_KOJIN_NO';
        sSQL := sSQL || '       ,SYOGAKO_CD';
        sSQL := sSQL || '       ,TYUGAKO_CD';
        sSQL := sSQL || '       ,SYOGAKO_NYUGAKU_BI';
        sSQL := sSQL || '       ,TYUGAKO_NYUGAKU_BI';
        sSQL := sSQL || '       ,GAKUNEN';
        sSQL := sSQL || '       ,GAKKO_KBN_CD';
        sSQL := sSQL || ' FROM GKBTGAKUREIBO';
        sSQL := sSQL || ' WHERE KOJIN_NO = '''||g_nKOJIN_NO||'''';
        sSQL := sSQL || ' AND RIREKI_RENBAN = '''||g_nNRIREKI_RENBAN||'''';
          OPEN cCURSOR FOR sSQL;
            LOOP
              FETCH cCURSOR INTO rGKBTGAKUREIBOTY.TSUSHOMEI_KANA                --通称名カナ
                                 ,rGKBTGAKUREIBOTY.TSUSHOMEI_KANJI              --通称名
                                 ,rGKBTGAKUREIBOTY.HOGOSYA_TSUSHOMEI_KANA       --保護者通称名カナ
                                 ,rGKBTGAKUREIBOTY.HOGOSYA_TSUSHOMEI_KANJI      --保護者通称名
                                 ,rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO             --保護者宛名番号
                                 ,rGKBTGAKUREIBOTY.SYOGAKO_CD                   --小学校コード
                                 ,rGKBTGAKUREIBOTY.TYUGAKO_CD                   --中学校コード
                                 ,rGKBTGAKUREIBOTY.SYOGAKO_NYUGAKU_BI           --小学校入学年月日
                                 ,rGKBTGAKUREIBOTY.TYUGAKO_NYUGAKU_BI           --中学校入学年月日
                                 ,rGKBTGAKUREIBOTY.GAKUNEN                      --学年
                                 ,rGKBTGAKUREIBOTY.GAKKO_KBN_CD;                --学校区分コード
              EXIT WHEN cCURSOR%NOTFOUND;
              --保護者宛名情報
              nRTN := GAAPK0030.FGETATENA2(rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(REPLACE(g_sHAKKO_YMD,'/','')), rGABTATENAKIHON, rGABTSOFUSAKI);
--  2024/12/11 JPJYS.LIUJUNHAO UPDATE 0.3.000.007:品質強化　IT_GKB_00028対応 Start
              nRTN := GKBFKHMCTRL(g_nKOJIN_NO, g_rOPRT.CHOHYOID, 1, sSHIYUTSURYOKUSEIGYO, sHOGOSHAKANA, sHOGOSHAKANJI, sHOGOSHASEINENGAPI );
--  2024/12/11 JPJYS.LIUJUNHAO UPDATE 0.3.000.007:品質強化　IT_GKB_00028対応 End
              --児童生徒宛名情報
              nRTN := GAAPK0030.FGETATENA(g_nKOJIN_NO, 'GKB', TO_NUMBER(REPLACE(g_sHAKKO_YMD,'/','')), rGABTATENAKIHONTY, rGABTSOFUSAKITY);
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
              --g_nSORT := g_nSORT + 1;
              --rWLTBL.NO := g_nSORT;                                                       --ソート順
--  2024/11/15 ZCZL.WANGYUNING UPDATE END
              IF g_nATESAKI = 0 THEN 
--  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化　IT_GKB_10087、IT_GKB_10088、IT_GKB_10089対応 Start
                IF rGABTSOFUSAKI.Kojin_No>0 THEN
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
                  -- sCTLPRM := GAAPK0030.FDVJUSHO('GKB', g_nKOJIN_NO,  g_sTANTOCODE, g_sWSNUM, rWLTBL.SOFU_JUSHO, nPRMCTL, 2);
                  -- IF nPRMCTL = 1 AND g_nHIENTAISYOUJUSHO = 1  THEN
                  IF g_nHIENTAISYOUJUSHO = 1  THEN
                    sCTLPRM := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
                    rWLTBL.SOFU_YUBIN := NULL ;      --送付先郵便番号       
                    rWLTBL.SOFU_JUSHO := sCTLPRM ;   --送付先住所
                    rWLTBL.SOFU_KATAGAKI := NULL ;   --送付先方書
                    rWLTBL.YUBIN_NOBC := NULL ;      --郵便番号ＢＣ
                  ELSE
                    --郵便番号編集処理
                    nRTN := KKAPK0010.FYUBINHENSHU(rGABTSOFUSAKI.YUBIN_NO, rWLTBL.SOFU_YUBIN);
                    rWLTBL.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(rWLTBL.SOFU_YUBIN, 0);    --送付先郵便番号
                    --送付先住所
                    rWLTBL.SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, rGABTSOFUSAKI.CHOMEI, rGABTSOFUSAKI.BANCHI, NULL, NULL);
                    rWLTBL.SOFU_KATAGAKI := rGABTSOFUSAKI.KATAGAKI;                           --送付先方書
                    rWLTBL.YUBIN_NOBC := rGABTSOFUSAKI.YUBIN_NOBC;                              --郵便番号ＢＣ
                  END IF;
                ELSE
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
                  -- sCTLPRM := GAAPK0030.FDVJUSHO('GKB', g_nKOJIN_NO,  g_sTANTOCODE, g_sWSNUM, rWLTBL.SOFU_JUSHO, nPRMCTL, 2);
                  -- IF nPRMCTL = 1 AND g_nHIENTAISYOUJUSHO = 1  THEN
                  IF g_nHIENTAISYOUJUSHO = 1  THEN
                    sCTLPRM := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
                    rWLTBL.SOFU_YUBIN := NULL ;      --送付先郵便番号      
                    rWLTBL.SOFU_JUSHO := sCTLPRM ;   --送付先住所
                    rWLTBL.SOFU_KATAGAKI := NULL ;   --送付先方書
                    rWLTBL.YUBIN_NOBC := NULL ;      --郵便番号ＢＣ
                  ELSE
                    --郵便番号編集処理
                    nRTN := KKAPK0010.FYUBINHENSHU(rGABTATENAKIHONTY.YUBIN_NO, rWLTBL.SOFU_YUBIN);
                    rWLTBL.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(rWLTBL.SOFU_YUBIN, 0);    --送付先郵便番号
                    --送付先住所
                    rWLTBL.SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, rGABTATENAKIHONTY.CHOMEI, rGABTATENAKIHONTY.BANCHI, NULL, NULL);
                    rWLTBL.SOFU_KATAGAKI := rGABTATENAKIHONTY.KATAGAKI;                           --送付先方書
                    rWLTBL.YUBIN_NOBC := rGABTATENAKIHONTY.YUBIN_NOBC;                              --郵便番号ＢＣ
                  END IF;
                END IF;
                --  2024/12/11 JPJYS.LIUJUNHAO UPDATE 0.3.000.007:品質強化　IT_GKB_00028対応 Start
                --rWLTBL.SOFU_ATENA := rGABTSOFUSAKI.SHIMEI_KANJI || '　' || '様';           --送付先宛名
                rWLTBL.SOFU_ATENA := sHOGOSHAKANJI || '　' || '様';           --送付先宛名
              END IF;
--  2024/12/11 JPJYS.LIUJUNHAO UPDATE 0.3.000.007:品質強化　IT_GKB_00028対応 End
                /*
                --郵便番号編集処理
                nRTN := KKAPK0010.FYUBINHENSHU(rGABTSOFUSAKI.YUBIN_NO, rWLTBL.SOFU_YUBIN);
                rWLTBL.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(rWLTBL.SOFU_YUBIN, 0);    --送付先郵便番号
                --送付先住所
                rWLTBL.SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, rGABTSOFUSAKI.CHOMEI, rGABTSOFUSAKI.BANCHI, NULL, NULL);
                rWLTBL.SOFU_KATAGAKI := rGABTSOFUSAKI.KATAGAKI;                           --送付先方書
--  2024/12/11 JPJYS.LIUJUNHAO UPDATE 0.3.000.007:品質強化　IT_GKB_00028対応 Start                
                --rWLTBL.SOFU_ATENA := rGABTSOFUSAKI.SHIMEI_KANJI || '　' || '様';           --送付先宛名
                rWLTBL.SOFU_ATENA := sHOGOSHAKANJI || '　' || '様';           --送付先宛名
--  2024/12/11 JPJYS.LIUJUNHAO UPDATE 0.3.000.007:品質強化　IT_GKB_00028対応 End                
--  2024/11/29 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00685横展開
                sCTLPRM := GAAPK0030.FDVJUSHO('GKB', g_nKOJIN_NO,  g_sTANTOCODE, g_sWSNUM, rWLTBL.SOFU_JUSHO, nPRMCTL, 2);
                IF g_nHIENTAISYOUJUSHO = 1 THEN
                  --学齢簿.保護者宛名番号でDV判定
                  --住所マスク文字列
--  2024/11/29 ZCZL.WANGYUNING UPDATE START 0.3.000.007:IT_GKB_00685横展開
--                  sCTLPRM := GAAPK0030.FDVJUSHO('GKB', rGKBTGAKUREIBOTY.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, rWLTBL.SOFU_JUSHO, nHANTEIKEKKA, 2, NULL, NULL);
--                  rWLTBL.SOFU_JUSHO := sCTLPRM;                                           --送付先住所
--                  IF nHANTEIKEKKA = 1 THEN
--                    rWLTBL.SOFU_KATAGAKI := NULL;                                         --送付先方書
--                  END IF;
                  IF nPRMCTL = '1' THEN
                    rWLTBL.SOFU_JUSHO := sCTLPRM;                                         --送付先住所
                    rWLTBL.SOFU_KATAGAKI := NULL;                                         --送付先方書
                  END IF;
--  2024/11/29 ZCZL.WANGYUNING UPDATE END
                END IF;
              ELSE
                rWLTBL.SOFU_YUBIN := NULL;                                                --送付先郵便番号
                rWLTBL.SOFU_JUSHO := NULL;                                                --送付先住所
                rWLTBL.SOFU_KATAGAKI := NULL;                                             --送付先方書
                rWLTBL.SOFU_ATENA := g_sNYUGAKUKO_MEI || '長' || '　' || '様';             --送付先宛名
              END IF;
              rWLTBL.YUBIN_NOBC := rGABTSOFUSAKI.YUBIN_NOBC;                              --郵便番号ＢＣ
              */
              --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化　IT_GKB_10087、IT_GKB_10088、IT_GKB_10089対応 End
              rWLTBL.BUNSHO_NO := sNUM;                                                   --文書番号
              --発行年月日
              --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化　IT_GKB_10087、IT_GKB_10088、IT_GKB_10089対応 Start
              --rWLTBL.HAKKO_NENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sDATEED, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10);
              rWLTBL.HAKKO_NENGAPI := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(TO_NUMBER(REPLACE(sDATEED,'/','')),0,3),' ',''));
              --rWLTBL.NISHOSHA_SHOKUSHU := vKATAGAKI1 || '市教育委員会';                   --認証者職種
              rWLTBL.NISHOSHA_SHOKUSHU := vKATAGAKI1;
              --rWLTBL.NINSHOSHA_SHIMEI := vSHIMEI || '様';                               --認証者氏名
              rWLTBL.NINSHOSHA_SHIMEI := vSHIMEI;                                         --認証者氏名
              --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化　IT_GKB_10087、IT_GKB_10088、IT_GKB_10089対応 End
              rWLTBL.KOIN_PATH := vKOINFILENAME;                                          --公印パス
              IF vKOINFILENAME IS NULL THEN
                rWLTBL.KOIN_SHORYAKU := rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU;              --公印（省略）
                rWLTBL.KOIN_CHUSHAKU := NULL;                                             --公印（注釈）
              ELSE
                rWLTBL.KOIN_SHORYAKU := NULL;                                             --公印（省略）
                rWLTBL.KOIN_CHUSHAKU := rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU;              --公印（注釈）
              END IF;
--  2024/11/12 ZCZL.WANGYUNING ADD 0.3.000.002:仕様変更IT_GKB_00475対応
              --rWLTBL.TITLE := 'GKBTTSUCHISHOKANRI';                                       --タイトル
              rWLTBL.TITLE := rGKBTTSUCHISHOKANRITY.CHOHYO_MEI;                                       --タイトル
              rWLTBL.TSUCHI_BUN := REPLACE(rGKBTTSUCHISHOKANRITY.TSUCHIBUN, chr(13)||chr(10),'#');                       --通知文
              --児童生徒の本名使用制御判定
              nRTN := GKBFKHMCTRL(g_nKOJIN_NO, g_rOPRT.CHOHYOID, 0, sSHIYUTSURYOKUSEIGYO, sJIDOSHIMEIKANA, sJIDOSHIMEIKANJI, sSEINENGAPI);
              rWLTBL.JIDO_SHIMEI_KANA := sJIDOSHIMEIKANA;                                 --児童氏名カナ
              rWLTBL.JIDO_SHIMEI_KANJI := sJIDOSHIMEIKANJI;                               --児童氏名漢字
              rWLTBL.HYOJI_SEINENGAPI := sSEINENGAPI;                                     --表示生年月日
              --児童生徒現住所
              --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化　IT_GKB_10087、IT_GKB_10088、IT_GKB_10089対応 Start
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
              -- sCTLPRM := GAAPK0030.FDVJUSHO('GKB', g_nKOJIN_NO,  g_sTANTOCODE, g_sWSNUM, rWLTBL.SOFU_JUSHO, nPRMCTL, 2);
              -- IF nPRMCTL = 1 AND g_nHIENTAISYOUJUSHO = 1  THEN
              IF g_nHIENTAISYOUJUSHO = 1  THEN
                sCTLPRM := GKBPK00010.FGETJUSHOMSG();
                rWLTBL.CHOMEI_BANCHI := sCTLPRM ;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
              ELSE
                rWLTBL.CHOMEI_BANCHI := rGABTATENAKIHONTY.CHOMEI || rGABTATENAKIHONTY.BANCHI || rGABTATENAKIHONTY.KATAGAKI;
              END IF;
              --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化　IT_GKB_10087、IT_GKB_10088、IT_GKB_10089対応 End
              rWLTBL.NYUGAKUKO_MEI := g_sNYUGAKUKO_MEI;                                   --入学校名
--  2024/11/26 ZCZL.WANGYUNING UPDATE 0.3.000.004:仕様変更IT_GKB_00660対応
              --rWLTBL.GAKUNEN := '第' || g_sNYUGAKUKO_GAKUNEN || '学年';                   --学年
              rWLTBL.GAKUNEN := g_sNYUGAKUKO_GAKUNEN;                   --学年
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:仕様変更　IT_GKB_00728対応  START            
              --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化　IT_GKB_10087、IT_GKB_10088、IT_GKB_10089対応 Start
              --PROC_GET_YMD(g_sNYUGAKU_KIJITU, NYUGAKU_KIJITU_OUT);
              -- 入学期日
              -- rWLTBL.NYUGAKU_KIJITSU := g_sNYUGAKU_KIJITU;
              NYUGAKU_KIJITU_OUT := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_sNYUGAKU_KIJITU, 'YYYYMMDD'), 'YYYY/MM/DD'), 1);
              rWLTBL.NYUGAKU_KIJITSU := KKAPK0010.FMULTIBYTEHENKAN(REPLACE(NYUGAKU_KIJITU_OUT, ' ', '') , 1);
              --  2024/12/11 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化　IT_GKB_10087、IT_GKB_10088、IT_GKB_10089対応 End
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.005:仕様変更　IT_GKB_00728対応  END
              rWLTBL.TOKKIJIKO := REPLACE(g_sTOKKIJIKO, chr(13)||chr(10),'#');            --特記事項
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
                INSERT INTO GKBWL690R001 VALUES rWLTBL;
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/06
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
        DELETE FROM GKBWL690R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
        --新設校・廃校に伴う入学通知書ワークのレコードの設定
        nRTN := FUNC_GET_JIDO_REC;
        IF nRTN <> 0 THEN
          RAISE ERR;
        END IF;
        -- CSV出力処理
        bRTN := FUNC_O20CSV (i_sGYOUMUCODE, 'GKBWL690R001', i_sCHOHYOID);
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
    --  作成者／作成日: ZCZL.shixinyu 2024/06/06
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
END GKBPA00180;
/
