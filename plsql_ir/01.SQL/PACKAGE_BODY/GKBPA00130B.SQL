CREATE OR REPLACE PACKAGE BODY GKBPA00130
--1.0.451.000-02.02-02.02
------------------------------------------------------------------------
--  サブシステム名  : GKB（教育）
--  プログラム名   : 就学校変更満了通知書
--  機能概要    : 就学校変更満了通知書の即時帳票を印刷する場合に呼び出される。
--              標準仕様の帳票レイアウトに合わせた項目を出力する。
--  バージョン     : Ver 0.3.000.000
--  作成者／作成日: ZCZL.xiaoya 2024/06/13
------------------------------------------------------------------------
--  変更履歴
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.001:IT_GKB_00433対応 
--  2024/11/11 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00397仕様変更対応
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
--  2024/12/10 JPJYS.GYY UPDATE 0.3.000.004:品質強化IT_GKB_10023対応
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10021対応
--  2024/12/10 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:品質強化IT_GKB_10082,IT_GKB_10083対応
--  2025/01/09 JPJYS.LIJINGHUI UPDATE 0.3.000.007:品質強化IT_GKB_10206対応
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
--  2026/01/05 CTC.XW UPDATE 1.0.451.000:GKB_QA25619対応
------------------------------------------------------------------------
IS
    -- 全処理必須パラメータ
    c_ONLINE                      CONSTANT PLS_INTEGER := 1;   --オンライン
    c_OK                          CONSTANT PLS_INTEGER := 0;   --正常
    c_ERR                         CONSTANT PLS_INTEGER := -1;  --異常
    g_nJOBNUM                     NUMBER;                      --ジョブナンバー
    g_sTANTOCODE                  CHAR(12);                    --担当者コード
    g_sWSNUM                      NVARCHAR2(1000);             --端末番号
    g_sBUNSHONUMLIST              NVARCHAR2(1000);             --文書番号情報（リスト）
    g_sMESSAGE                    NVARCHAR2(4000);             --メッセージ
    g_rOPRT                       KKATOPRT%ROWTYPE;            --オンラインジョブステップ情報
    g_sCSV_RCNT                   NVARCHAR2(1000);             --CSVファイル出力件数
    g_sCSVFILENAME                NVARCHAR2(1000);             --CSVファイル名
    c_EMF                         CONSTANT PLS_INTEGER := 1;   --印刷ファイル区分(EMF)
    c_PDF                         CONSTANT PLS_INTEGER := 2;   --印刷ファイル区分(PDF)
    c_EMFANDPDF                   CONSTANT PLS_INTEGER := 3;   --印刷ファイル区分(EMFとPDF)
    g_sPRTFILENAME                NVARCHAR2(1000);             --印刷ファイル名
    g_sSTARTDATE                  NVARCHAR2(23);               --開始時刻

    --パラメータ変数
    g_nPRTSORT                    NUMBER := 0;                 --ソート順
    g_nHALTSUKOUCODE              NUMBER := 0;                 --発行カウント
    g_nATENANO                    NUMBER;                      --宛名番号
    g_nNRIREKIRENBAN              NUMBER;                      --履歴連番
    g_nCHOHYOKBN                  NUMBER;                      --帳票区分
    g_sHASSOUBI                   NVARCHAR2(1000);             --発送日
    g_sATESAKI                    NUMBER;                      --宛先
    g_sKYOIKUKAI                  NVARCHAR2(1000);             --教育委員会
    g_nBUNSHONO                   NVARCHAR2(1000);             --文書番号（リスト）
    g_nHIENTAISYOUJUSHO           NUMBER;                      --支援措置対象住所非表示
    g_nHAKKOSU                    NUMBER;                      --発行部数
    g_sSITEIGAKKOU                NVARCHAR2(1000);             --指定学校
    g_sSITEIGAKKOU_KAUNEN         NVARCHAR2(1000);             --指定学校_学年
    g_sGENZAISEKIKO               NVARCHAR2(1000);             --現在籍校
    g_sGENZAISEKIKO_KAUNEN        NVARCHAR2(1000);             --現在籍校_学年
    g_sSYUGAKUKIKAN               NVARCHAR2(1000);             --就学期間
    g_sTENNYUTETSUZUKI_KIGEN      NVARCHAR2(1000);             --転入学手続き期限
    g_sTOKKIGIKOU                 NVARCHAR2(1000);             --特記事項
    g_sBIKO                       NVARCHAR2(1000);             --備考
--  2024/12/10 JPJYS.GYY UPDATE 0.3.000.004:品質強化IT_GKB_10023対応 START    
    TENNYUTETSUZUKI_KIGEN_OUT NVARCHAR2(120);  
--  2024/12/10 JPJYS.GYY UPDATE 0.3.000.004:品質強化IT_GKB_10023対応 END
    -- 通知書条件から情報を取得
    CURSOR CUR_REIBO IS
    SELECT
          REIBO.KOJIN_NO                                  --宛名番号
        , REIBO.TSUSHOMEI_KANA                            --通称名カナ
        , REIBO.TSUSHOMEI_KANJI                           --通称名
        , REIBO.HOGOSYA_KOJIN_NO                          --保護者宛名番号
        , REIBO.HOGOSYA_TSUSHOMEI_KANA                    --保護者通称名カナ
        , REIBO.HOGOSYA_TSUSHOMEI_KANJI                   --保護者通称名
        , REIBO.SHITEI_SYOGAKO_CD                         --就学指定校_小学校
        , REIBO.HENKO_GAKUNEN_SYOGAKO                     --就学校変更_開始学年_小学校
        , REIBO.KIBO_SYOGAKKO_CD                          --希望就学校_小学校
        , REIBO.SHITEI_TYUGAKO_CD                         --就学指定校_中学校
        , REIBO.HENKO_GAKUNEN_TYUGAKO                     --就学校変更_開始学年_中学校
        , REIBO.KIBO_TYUGAKKO_CD                          --希望就学校_中学校
        , REIBO.HENKO_JIYU                                --就学校変更_事由
        , REIBO.HENKO_KAISI_BI                            --就学校変更_開始年月日
        , REIBO.HENKO_SYURYO_BI                           --就学校変更_終了年月日
    FROM
        GKBTGAKUREIBO REIBO
    WHERE REIBO.KOJIN_NO        = g_nATENANO
        AND REIBO.RIREKI_RENBAN = g_nNRIREKIRENBAN;       --履歴連番
    REC_REIBO CUR_REIBO%ROWTYPE;
    --------------------------------------------------------
    --  機能概要      : 処理ログ出力
    --  パラメータ    : i_sSTEP_NANE       処理単位に任意に付したステップ名
    --                : i_nDEBUG_KBN       デバッグ用か否か(1:デバッグ、0:通常)
    --                : i_nSTATUSID        ログ出力時のステータス(1:異常、0:情報)
    --                : i_sSQLCODE         異常ログ出力時のSQLCODE
    --                : i_sSQLERRM         異常ログ出力時のSQLERRM
    --                : i_sERRMSG          エラーログとして出力する文字列
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/13
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/13
    --------------------------------------------------------
    FUNCTION FUNC_O00INIT RETURN BOOLEAN
    IS
    BEGIN
        -- 全処理必須パラメータの設定
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/13
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
                WHEN 1  THEN    g_nATENANO               := aCSV_TBL(i);    --宛名番号
                WHEN 2  THEN    g_nNRIREKIRENBAN         := aCSV_TBL(i);    --履歴連番
                WHEN 3  THEN    g_nCHOHYOKBN             := aCSV_TBL(i);    --帳票区分
                WHEN 4  THEN    g_sHASSOUBI              := aCSV_TBL(i);    --発送日
                WHEN 5  THEN    g_sATESAKI               := aCSV_TBL(i);    --宛先
                WHEN 6  THEN    g_sKYOIKUKAI             := aCSV_TBL(i);    --教育委員会
                WHEN 7  THEN    g_nBUNSHONO              := aCSV_TBL(i);    --文書番号
                WHEN 8  THEN    g_nHIENTAISYOUJUSHO      := aCSV_TBL(i);    --支援措置対象住所非表示
                WHEN 9  THEN    g_nHAKKOSU               := aCSV_TBL(i);    --発行部数
                WHEN 10 THEN    g_sSITEIGAKKOU           := aCSV_TBL(i);    --指定学校
                WHEN 11 THEN    g_sSITEIGAKKOU_KAUNEN    := aCSV_TBL(i);    --指定学校_学年
                WHEN 12 THEN    g_sGENZAISEKIKO          := aCSV_TBL(i);    --現在籍校
                WHEN 13 THEN    g_sGENZAISEKIKO_KAUNEN   := aCSV_TBL(i);    --現在籍校_学年
                WHEN 14 THEN    g_sSYUGAKUKIKAN          := aCSV_TBL(i);    --就学期間
--  2024/12/10 JPJYS.GYY UPDATE 0.3.000.004:品質強化IT_GKB_10023対応 START               
                --WHEN 15 THEN    g_sTENNYUTETSUZUKI_KIGEN := aCSV_TBL(i);    --転入学手続き期限
                WHEN 15 THEN    g_sTENNYUTETSUZUKI_KIGEN := TO_NUMBER(aCSV_TBL(i));    --転入学手続き期限
--  2024/12/10 JPJYS.GYY UPDATE 0.3.000.004:品質強化IT_GKB_10023対応 END                
                WHEN 16 THEN    g_sTOKKIGIKOU            := aCSV_TBL(i);    --特記事項
                WHEN 17 THEN    g_sBIKO                  := aCSV_TBL(i);    --備考
                ELSE NULL;
            END CASE;
        END LOOP;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_O01PINIT;
    --------------------------------------------------------
    --  機能概要      : 画面入力値取得（帳票）
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYONUM    帳票番号
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/13
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/13
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
--  2024/12/10 JPJYS.GYY UPDATE 0.3.000.004:品質強化IT_GKB_10023対応 START   
      --------------------------------------------------------
    --  機能概要      : 日付変換
    --  パラメータ    : i_YMD
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: YAMANI.NISHIMURA   2024/12/10
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
--  2024/12/10 JPJYS.GYY UPDATE 0.3.000.004:品質強化IT_GKB_10023対応 END  
    --------------------------------------------------------
    --  機能概要      : 就学校変更満了通知書ワークのレコードの設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/13
    --------------------------------------------------------
    FUNCTION FUNC_GET_SYUGAKU_REC RETURN NUMBER IS
        bRTN                      BOOLEAN;                             --戻る値
        nRTN                      NUMBER;                              --戻る値
        rWLTBL                    GKBWL676R002%ROWTYPE;                --就学校変更満了通知書ﾜｰｸﾃｰﾌﾞﾙ
        sTOIAWASE1                NVARCHAR2(1000);                     --お問い合わせ先１
        sTOIAWASE2                NVARCHAR2(1000);                     --お問い合わせ先２
        sTOIAWASE3                NVARCHAR2(1000);                     --お問い合わせ先３
        o_SHIMEIPRM               A_CONS_PRM;                          --パラメータ配列
        o_LENGTH                  NUMBER;                              --パラメータ配列の長度
        o_nDAIRIKBN               NUMBER;                              --認証者の本人・代理区分
        o_sKATAGAKI1              NVARCHAR2(1000);                     --認証者の肩書上段
        o_sKATAGAKI2              NVARCHAR2(1000);                     --認証者の肩書下段
        o_sSHIMEI                 NVARCHAR2(1000);                     --認証者の氏名
        o_sKOINFILENAME           NVARCHAR2(1000);                     --公印ファイル名
        rBUNNUMSRCINF             KKAPK0040.MR_BUNNUMSRCINF;           --文書番号情報（構造体）
        rBUNNUMEDITKEKA           KKAPK0040.MR_BUNNUMEDITKEKA;         --文書番号編集結果
        sNUM                      NVARCHAR2(1000);                     --文書番号
        sDATEED                   NVARCHAR2(1000);                     --文書日付
        rTSUCHISHOKANRI           GKBTTSUCHISHOKANRI%ROWTYPE;          --通知書管理テーブルのレコード
        aITEM                     A_CONS_PRM;                          --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        nSYUGAKUHENKOU_INDEXNO    NUMBER;                              --出入国記録照会書_インデックス番号
        sSYUGAKUHENKOU_SYUTURYOKU NVARCHAR2(1000);                     --入学予定通知書_出力制御
        o_rHKSKIHON               GABTATENAKIHON%ROWTYPE;              --保護者の宛名基本
        o_rHKSSOFUSAKI            GABTSOFUSAKI%ROWTYPE;                --保護者の送付先基本
        o_rJDSTKIHON              GABTATENAKIHON%ROWTYPE;              --児童生徒の宛名基本
        o_rJDSTSOFUSAKI           GABTSOFUSAKI%ROWTYPE;                --児童生徒の送付先基本
        sYUBIN_NO                 NVARCHAR2(20);                       --編集後郵便番号
        sGYOMU_CD                 PLS_INTEGER;                         --抑止レベル３制御の要否（0：非該当、1：該当）
        SCTLPRM                   NVARCHAR2(500);                      --住所マスク文字列
        o_sSHIMEIKANA             NVARCHAR2(1000);                     --氏名カナ
        o_sSHIMEIKANJI            NVARCHAR2(1000);                     --氏名漢字
        o_sBIRTHDAY               NVARCHAR2(1000);                     --生年月日
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10021対応 START     
        o_sJIDOSHIMEIKANA             NVARCHAR2(1000);                     --氏名カナ
        o_sJIDOSHIMEIKANJI            NVARCHAR2(1000);                     --氏名漢字
        o_sJIDOBIRTHDAY               NVARCHAR2(1000);                     --生年月日 
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10021対応 END        
        
    BEGIN
        IF g_nCHOHYOKBN = 23 THEN
            -- 公印情報を取得する
            bRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE,0),
                                         g_sWSNUM,
                                         SYSDATE,
                                         o_nDAIRIKBN,
                                         o_sKATAGAKI1,                   --認証者の肩書
                                         o_sKATAGAKI2,
                                         o_sSHIMEI,                      --認証者名
                                         o_sKOINFILENAME);               --公印ファイル名
            -- 教育委員会情報を取得する
            nRTN := KKAPK0030.FPRMSHUTOKU('GKB',                         --業務コード
                                          '00KYOIKUKAI',                 --制御パラメータ項目コード
                                          g_sKYOIKUKAI,                  --制御パラメータ項目連番
                                          o_SHIMEIPRM,
                                          o_LENGTH);
            IF nRTN = 0 THEN
                FOR i IN 1..8 LOOP
                    IF i > o_SHIMEIPRM.COUNT THEN
                        o_SHIMEIPRM.EXTEND;
                        o_SHIMEIPRM(i) := NULL;
                    END IF;
                END LOOP;
            ELSE
                o_SHIMEIPRM := A_CONS_PRM();
                o_SHIMEIPRM.EXTEND;
                FOR i IN 1..8 LOOP
                    o_SHIMEIPRM(i) := NULL;
                    o_SHIMEIPRM.EXTEND;
                END LOOP;
            END IF;
            sTOIAWASE1 := o_SHIMEIPRM(1);                                --お問い合わせ先１
            sTOIAWASE2 := o_SHIMEIPRM(6);                                --お問い合わせ先２
            sTOIAWASE3 := o_SHIMEIPRM(7);                                --お問い合わせ先３
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
            --通知書管理からデータを取得する
            BEGIN
                SELECT
                      KANRI.CHOHYO_MEI                 --帳票名
                    , KANRI.KOIN_SHORYAKU              --公印省略
                    , KANRI.KOIN_CHUSHAKU              --公印注釈
                    , KANRI.TSUCHIBUN                  --通知文
                    , KANRI.TOKKIJIKO                  --特記事項
                    , KANRI.BIKO_TITLE                 --備考タイトル
                    , KANRI.YOSHIKI_BANGO_SETTOGO      --様式番号接頭語
                    , KANRI.YOSHIKI_BANGO              --様式番号
                    , KANRI.YOSHIKI_BANGO_SETSUBIGO    --様式番号接尾語
                INTO
                      rTSUCHISHOKANRI.CHOHYO_MEI
                    , rTSUCHISHOKANRI.KOIN_SHORYAKU
                    , rTSUCHISHOKANRI.KOIN_CHUSHAKU
                    , rTSUCHISHOKANRI.TSUCHIBUN
                    , rTSUCHISHOKANRI.TOKKIJIKO
                    , rTSUCHISHOKANRI.BIKO_TITLE
                    , rTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO
                    , rTSUCHISHOKANRI.YOSHIKI_BANGO
                    , rTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO
                FROM
                    GKBTTSUCHISHOKANRI KANRI
                WHERE
                    KANRI.CHOHYO_KBN = g_nCHOHYOKBN;   --帳票区分
            EXCEPTION
                WHEN OTHERS THEN
                    rTSUCHISHOKANRI.CHOHYO_MEI              := NULL;
                    rTSUCHISHOKANRI.KOIN_SHORYAKU           := NULL;
                    rTSUCHISHOKANRI.KOIN_CHUSHAKU           := NULL;
                    rTSUCHISHOKANRI.TSUCHIBUN               := NULL;
                    rTSUCHISHOKANRI.TOKKIJIKO               := NULL;
                    rTSUCHISHOKANRI.BIKO_TITLE              := NULL;
                    rTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO   := NULL;
                    rTSUCHISHOKANRI.YOSHIKI_BANGO           := NULL;
                    rTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO := NULL;
            END;
            -- システム制御設定を取得
            -- 外国人　氏名・生年月日制御帳票(ID)のリストを取得
            --  2024/11/11 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00397対応
            --nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 2, aITEM);
            nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aITEM);
            --「就学校変更満了通知書」が格納されている箇所のインデックス番号
            IF nRTN = 0 THEN
                FOR i IN 1..aITEM.COUNT LOOP
                    --  2024/11/11 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00397対応
                    --IF aITEM(i) = '就学校変更満了通知書' THEN
                    IF aITEM(i) = 'GKB676R001' THEN
                        nSYUGAKUHENKOU_INDEXNO := i;    --出入国記録照会書_インデックス番号
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
            -- 「本名・通称名　出力制御」のリストを取得する
            nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aITEM);
            IF nRTN = 0 AND nSYUGAKUHENKOU_INDEXNO <= aITEM.COUNT THEN
                sSYUGAKUHENKOU_SYUTURYOKU := aITEM(nSYUGAKUHENKOU_INDEXNO);    --出入国記録照会書_出力制御
            END IF;
            -- 学齢簿から下記の項目の取得する
            OPEN CUR_REIBO;
                LOOP
                    FETCH CUR_REIBO INTO REC_REIBO;
                    EXIT WHEN CUR_REIBO%NOTFOUND;
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00539横展開対応
                    --g_nPRTSORT := g_nPRTSORT + 1;
                    --保護者の宛名情報を取得する
                    nRTN := GAAPK0030.FGETATENA2(REC_REIBO.HOGOSYA_KOJIN_NO,
                                                 'GKB',
                                                 TO_NUMBER(TO_CHAR(TO_DATE(g_sHASSOUBI, 'YYYYMMDD'), 'YYYYMMDD')),
                                                 o_rHKSKIHON,
                                                 o_rHKSSOFUSAKI);
                    --児童の宛名情報を取得する
                    nRTN := GAAPK0030.FGETATENA(REC_REIBO.KOJIN_NO,
                                                'GKB',
                                                TO_NUMBER(TO_CHAR(TO_DATE(g_sHASSOUBI, 'YYYYMMDD'), 'YYYYMMDD')),
                                                o_rJDSTKIHON,
                                                o_rJDSTSOFUSAKI);
                    --ワークテーブル登録
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00539横展開対応
                    --rWLTBL.NO := g_nPRTSORT;                                                          --ソート順
                    --保護者の本名使用制御判定
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10021対応 START                      
                    --nRTN := GKBFKHMCTRL(g_nATENANO, g_nCHOHYOKBN, 1, sSYUGAKUHENKOU_SYUTURYOKU,o_sSHIMEIKANA, o_sSHIMEIKANJI, o_sBIRTHDAY);
                    nRTN := GKBFKHMCTRL(g_nATENANO, g_rOPRT.CHOHYOID, 1, sSYUGAKUHENKOU_SYUTURYOKU,o_sSHIMEIKANA, o_sSHIMEIKANJI, o_sBIRTHDAY);
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10021対応 END 
                    rWLTBL.HOGOSHA_SHIMEI_KANA  := o_sSHIMEIKANA;                                     --保護者氏名カナ
                    rWLTBL.HOGOSHA_SHIMEI_KANJI := o_sSHIMEIKANJI;                                    --保護者氏名漢字
                    --変数.宛先=0（保護者）の場合
                    IF g_sATESAKI = 0 THEN
                        --郵便番号編集処理
                        nRTN := KKAPK0010.FYUBINHENSHU(o_rHKSSOFUSAKI.YUBIN_NO, sYUBIN_NO);
                        rWLTBL.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO, 0);                --送付先郵便番号
                        --送付先住所
                        rWLTBL.SOFU_JUSHO    := GAAPK0010.FADDRESSEDIT(1, NULL, o_rHKSSOFUSAKI.CHOMEI, o_rHKSSOFUSAKI.BANCHI, NULL, NULL);
                        rWLTBL.SOFU_KATAGAKI := o_rHKSSOFUSAKI.KATAGAKI;                              --送付先方書
                        rWLTBL.SOFU_ATENA    := o_sSHIMEIKANJI || '　' || '様';                        --送付先宛名
                        --抑止住所編集
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
                        -- SCTLPRM := GAAPK0030.FDVJUSHO('GKB',
                        --                               REC_REIBO.HOGOSYA_KOJIN_NO,
                        --                               g_sTANTOCODE,
                        --                               g_sWSNUM,
                        --                               rWLTBL.SOFU_JUSHO,
                        --                               sGYOMU_CD,
                        --                               2);
                        --支援措置対象住所非表示＝１(有)の場合
                        IF g_nHIENTAISYOUJUSHO = 1 THEN
                            --保護者宛名番号でDV判定を行い
                            --IF sGYOMU_CD = 1 THEN
                                SCTLPRM := GKBPK00010.FGETJUSHOMSG();
                                rWLTBL.SOFU_JUSHO := SCTLPRM;                                         --送付先住所
                                rWLTBL.SOFU_KATAGAKI := NULL;                                         --送付先方書
                            --END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
                        END IF;
                        rWLTBL.BC_NO := o_rHKSSOFUSAKI.YUBIN_NOBC;                                    --バーコードNo
                    ELSE
                        rWLTBL.SOFU_YUBIN    := NULL;                                                 --送付先郵便番号
                        rWLTBL.SOFU_JUSHO    := NULL;                                                 --送付先住所
                        rWLTBL.SOFU_KATAGAKI := NULL;                                                 --送付先方書
                        rWLTBL.SOFU_ATENA    := g_sSITEIGAKKOU || '長　'|| '様';                        --送付先宛名
                        rWLTBL.BC_NO := NULL;                                                         --バーコードNo
                    END IF;
                    --発行年月日
                    --  2024/12/10 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:品質強化IT_GKB_10082,IT_GKB_10083対応 Start
                    --rWLTBL.HAKKO_NENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sDATEED, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10);
                    rWLTBL.HAKKO_NENGAPI := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(TO_NUMBER(REPLACE(sDATEED,'/','')),0,3),' ',''));
                    --  2024/12/10 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:品質強化IT_GKB_10082,IT_GKB_10083対応 End
                    rWLTBL.BUNSHO_NO        := sNUM;                                                  --文書番号
                    rWLTBL.KYOIKUKAI_MEI    := o_sKATAGAKI1;                                          --教育委員会名
                    rWLTBL.NINSHOSHA_SHIMEI := o_sSHIMEI;                                             --認証者氏名
                    rWLTBL.KOIN_PATH        := o_sKOINFILENAME;                                       --公印パス
                    IF o_sKOINFILENAME IS NULL THEN
                        rWLTBL.KOIN_SHORYAKU := rTSUCHISHOKANRI.KOIN_SHORYAKU;                        --公印（省略）
                        rWLTBL.KOIN_CHUSHAKU := NULL;                                                 --公印（注釈）
                    ELSE
                        rWLTBL.KOIN_SHORYAKU := NULL;                                                 --公印（省略）
                        rWLTBL.KOIN_CHUSHAKU := rTSUCHISHOKANRI.KOIN_CHUSHAKU;                        --公印（注釈）
                    END IF;
                    
                    rWLTBL.TITLE      := rTSUCHISHOKANRI.CHOHYO_MEI;                            --タイトル
                    rWLTBL.TSUCHI_BUN := REPLACE(rTSUCHISHOKANRI.TSUCHIBUN, chr(13) || chr(10), '#'); --通知文
                    --児童生徒の本名使用制御判定
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10021対応 START   
                    /*nRTN := GKBFKHMCTRL(g_nATENANO, g_nCHOHYOKBN, 0, sSYUGAKUHENKOU_SYUTURYOKU,o_sSHIMEIKANA, o_sSHIMEIKANJI, o_sBIRTHDAY);
                    rWLTBL.JIDO_SHIMEI_KANA  := o_sSHIMEIKANA;                                        --児童生徒氏名カナ
                    rWLTBL.JIDO_SHIMEI_KANJI := o_sSHIMEIKANJI;                                       --児童生徒氏名漢字
                    rWLTBL.HYOJI_SEINENGAPI  := o_sBIRTHDAY;                                          --表示生年月日 */
                    nRTN := GKBFKHMCTRL(g_nATENANO, g_rOPRT.CHOHYOID, 0, sSYUGAKUHENKOU_SYUTURYOKU,o_sJIDOSHIMEIKANA, o_sJIDOSHIMEIKANJI, o_sJIDOBIRTHDAY);                    
                    rWLTBL.JIDO_SHIMEI_KANA  := o_sJIDOSHIMEIKANA;                                        --児童生徒氏名カナ
                    rWLTBL.JIDO_SHIMEI_KANJI := o_sJIDOSHIMEIKANJI;                                       --児童生徒氏名漢字
                    rWLTBL.HYOJI_SEINENGAPI  := o_sJIDOBIRTHDAY;                                          --表示生年月日   */ 
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10021対応 END                                       
                    --児童生徒現住所
                    rWLTBL.CHOMEI_BANCHI     := GAAPK0010.FADDRESSEDIT(1, NULL, o_rJDSTKIHON.CHOMEI, o_rJDSTKIHON.BANCHI, o_rJDSTKIHON.KATAGAKI, NULL);
                    --抑止住所編集
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
                    -- SCTLPRM := GAAPK0030.FDVJUSHO('GKB',
                    --                               REC_REIBO.KOJIN_NO,
                    --                               g_sTANTOCODE,
                    --                               g_sWSNUM,
                    --                               rWLTBL.CHOMEI_BANCHI,
                    --                               sGYOMU_CD,
                    --                               2);
                    --支援措置対象住所非表示＝１(有)の場合
                    IF g_nHIENTAISYOUJUSHO = 1 THEN
                        --学齢簿.宛名番号でDV判定を行い
                        -- IF sGYOMU_CD = 1 THEN
                            SCTLPRM := GKBPK00010.FGETJUSHOMSG();
                            rWLTBL.CHOMEI_BANCHI := SCTLPRM;                                          --児童生徒現住所
                        -- END IF;

                        -- 2026/01/05 CTC.XW UPDATE START 1.0.451.000:GKB_QA25619対応
                            rWLTBL.SOFU_YUBIN := NULL;                                                 --送付先郵便番号
                        -- 2026/01/05 CTC.XW UPDATE END
                  
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
                    END IF;
                    rWLTBL.SHITEIKO_MEI          := g_sSITEIGAKKOU;                                   --指定校名
                    rWLTBL.SHITEIKO_GAKUNEN      := g_sSITEIGAKKOU_KAUNEN;                            --指定校学年
                    rWLTBL.GENZAISEKIKO_MEI      := g_sGENZAISEKIKO;                                  --現在籍校
                    rWLTBL.GENZAISEKIKO_GAKUNEN  := g_sGENZAISEKIKO_KAUNEN;                           --現在籍校学年
                    rWLTBL.SHUGAKU_KIKAN         := g_sSYUGAKUKIKAN;                                  --就学期間
--  2024/12/10 JPJYS.GYY UPDATE 0.3.000.004:品質強化IT_GKB_10023対応 START                    
                    --rWLTBL.TENNYUTETSUZUKI_KIGEN := g_sTENNYUTETSUZUKI_KIGEN;                         --転入学手続き期限
                    --  2024/12/10 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:品質強化IT_GKB_10082,IT_GKB_10083対応 Start
                    --PROC_GET_YMD(g_sTENNYUTETSUZUKI_KIGEN, TENNYUTETSUZUKI_KIGEN_OUT);
                    --rWLTBL.TENNYUTETSUZUKI_KIGEN := TENNYUTETSUZUKI_KIGEN_OUT;
                    rWLTBL.TENNYUTETSUZUKI_KIGEN := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(g_sTENNYUTETSUZUKI_KIGEN,0,3),' ',''));
                    --  2024/12/10 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:品質強化IT_GKB_10082,IT_GKB_10083対応 End
--  2024/12/10 JPJYS.GYY UPDATE 0.3.000.004:品質強化IT_GKB_10023対応 END                      
                    rWLTBL.TOKKIJIKO             := REPLACE(g_sTOKKIGIKOU, chr(13)||chr(10),'#');     --特記事項
                    rWLTBL.BIKO                  := REPLACE(g_sBIKO, chr(13)||chr(10),'#');           --備考
                    rWLTBL.TOIAWASESAKI1         := sTOIAWASE1;                                       --お問い合わせ先１
                    rWLTBL.TOIAWASESAKI2         := sTOIAWASE2;                                       --お問い合わせ先２
                    rWLTBL.TOIAWASESAKI3         := sTOIAWASE3;                                       --お問い合わせ先３
                    rWLTBL.BIKO_TITLE            := rTSUCHISHOKANRI.BIKO_TITLE;                       --備考タイトル
                    --様式番号
                    rWLTBL.YOSHIKI_NO := rTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO || rTSUCHISHOKANRI.YOSHIKI_BANGO || rTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO;
--  2025/01/09 JPJYS.LIJINGHUI ADD 0.3.000.006:品質強化IT_GKB_10206対応  Star
                    rWLTBL.YOSHIKI_NO := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(rWLTBL.YOSHIKI_NO, 0),' ',''),'　','');
--  2025/01/09 JPJYS.LIJINGHUI ADD 0.3.000.006:品質強化IT_GKB_10206対応  End
                    rWLTBL.BREAK_NO   := NULL;                                                        --改ページキー
                    rWLTBL.WSNUM      := g_sWSNUM;                                                    --端末番号
                    rWLTBL.BATCHKBN   := c_ONLINE;                                                    --即時バッチ区分
                    rWLTBL.JOBNUM     := g_nJOBNUM;                                                   --ジョブNO
                    FOR i IN 1..g_nHAKKOSU LOOP
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00539横展開対応
                        g_nPRTSORT := g_nPRTSORT + 1;
                        rWLTBL.NO := g_nPRTSORT;                                                          --ソート順
--  2024/11/15 ZCZL.WANGYUNING UPDATE END
                        --登録ワークテーブル
                        INSERT INTO GKBWL676R002 VALUES rWLTBL;
                    END LOOP;
                    g_nHALTSUKOUCODE := g_nHALTSUKOUCODE + 1;
                END LOOP;
        CLOSE CUR_REIBO;
        ELSE
            NULL;
        END IF;
        -- 関数終了
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
            IF CUR_REIBO%ISOPEN THEN
                CLOSE CUR_REIBO;
            END IF;
            RETURN c_ERR;
    END FUNC_GET_SYUGAKU_REC;
    --------------------------------------------------------
    --  機能概要      : データ取得、ワークテーブル登録
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/13
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                             --戻る値
        nRTN                  NUMBER;
        ERR                   EXCEPTION;
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');
        -- 初期化
        DELETE FROM GKBWL676R002
        WHERE WSNUM = g_sWSNUM
        AND BATCHKBN = c_ONLINE;
        -- 就学校変更許可通知書ワークのレコードの設定
        nRTN := FUNC_GET_SYUGAKU_REC;
        IF nRTN <> 0 THEN
          RAISE ERR;
        END IF;
        -- 帳票出力CSVの作成
        bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL676R002', i_sCHOHYOID);
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/13
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
END GKBPA00130;
/

