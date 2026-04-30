CREATE OR REPLACE PACKAGE BODY GKBPA00150
--1.0.106.000-02.02-02.02
------------------------------------------------------------------------
--  サブシステム名  : GKB（教育）
--  プログラム名   : 就学猶予・免除通知書作成
--  機能概要    : 帳票発行画面で、選択した処理条件により、対応する中間テーブルにデータを作成する。
--              確定したCSVファイル名を呼び出し元へ返す。
--  バージョン     : Ver 0.3.000.000
--  作成者／作成日: ZCZL.xiaoya 2024/06/06
------------------------------------------------------------------------
--  変更履歴
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.001:仕様変更　ID：IT_GKB_00064対応
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00433対応 
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00632対応 
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10011、IT_GKB_10012対応 
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.006:品質強化IT_GKB_10058、IT_GKB_10059、IT_GKB_10060、IT_GKB_10061対応
--  2024/12/20 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:品質強化：IT_GKB_10112対応
--  2025/01/06 JPJYS.GAOJIAN UPDATE 0.3.000.008:品質強化：IT_GKB_10100対応
--  2025/07/18 CTC.HJF UPDATE 1.0.010.001:GKB_QA17896対応
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
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
    g_sTEIKEINUM                  NVARCHAR2(1000);             --定型文番号（リスト）

    --パラメータ変数
    g_nPRTSORT                    NUMBER := 0;                 --ソート順
    g_nHALTSUKOUCODE              NUMBER := 0;                 --発行カウント
    g_nATENANO                    NUMBER;                      --宛名番号
    g_nNRIREKIRENBAN              NUMBER;                      --履歴連番
    g_nCHOHYOKBN                  NUMBER;                      --帳票区分
    g_sHASSOBI                    NVARCHAR2(1000);             --発送日
    g_sATESAKI                    NUMBER := 0;                 --宛先
    g_sKYOIKUKAI                  NVARCHAR2(1000);             --教育委員会
    g_nBUNSHONO                   NVARCHAR2(1000);             --文書番号（リスト）
    g_nHIENTAISYOUJUSHO           NUMBER;                      --支援措置対象住所非表示
    g_nHAKKOSU                    NUMBER;                      --発行部数
    g_sKYOKAKIKAN                 NVARCHAR2(1000);             --許可期間
    g_sJIYU                       NVARCHAR2(1000);             --事由
    g_sBIKO                       NVARCHAR2(1000);             --備考

    -- 通知書管理テーブルのデータを取得
    CURSOR CUR_GAKUREIBO IS
    SELECT
          YUYO_JIYU_CD           --就学猶予事由コード
        , YUYO_JIYU              --就学猶予事由
        , YUYO_KAISI_BI          --就学猶予開始年月日
        , YUYO_SYURYO_BI         --就学猶予終了年月日
        , MENJO_JIYU_CD          --就学免除事由コード
        , MENJO_JIYU             --就学免除事由
        , MENJO_KAISI_BI         --就学免除開始年月日
        , MENJO_SYURYO_BI        --就学免除終了年月日
        , HOGOSYA_KOJIN_NO       --保護者宛名番号
        , SYOGAKO_CD             --小学校コード
        , TYUGAKO_CD             --中学校コード
        , GAKKO_KBN_CD           --学校区分コード
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10059対応 START
        , GAKUNEN                --学年
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10059対応 END
    FROM
        GKBTGAKUREIBO
    WHERE
        KOJIN_NO = g_nATENANO
        AND RIREKI_RENBAN = g_nNRIREKIRENBAN;
    REC_GAKUREIBO CUR_GAKUREIBO%ROWTYPE;
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/06
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/06
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/06
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
                WHEN 1  THEN    g_nATENANO          := aCSV_TBL(i);    --宛名番号
                WHEN 2  THEN    g_nNRIREKIRENBAN    := aCSV_TBL(i);    --履歴連番
                WHEN 3  THEN    g_nCHOHYOKBN        := aCSV_TBL(i);    --帳票区分
                WHEN 4  THEN    g_sHASSOBI          := aCSV_TBL(i);    --発送日
                WHEN 5  THEN    g_sATESAKI          := aCSV_TBL(i);    --宛先
                WHEN 6  THEN    g_sKYOIKUKAI        := aCSV_TBL(i);    --教育委員会
                WHEN 7  THEN    g_nBUNSHONO         := aCSV_TBL(i);    --文書番号
                WHEN 8  THEN    g_nHIENTAISYOUJUSHO := aCSV_TBL(i);    --支援措置対象住所非表示
                WHEN 9  THEN    g_nHAKKOSU          := aCSV_TBL(i);    --発行部数
                WHEN 10 THEN    g_sKYOKAKIKAN       := aCSV_TBL(i);    --許可期間
                WHEN 11 THEN    g_sJIYU             := aCSV_TBL(i);    --事由
                WHEN 12 THEN    g_sBIKO             := aCSV_TBL(i);    --備考
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/06
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/06
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
    --  機能概要      : 就学猶予免除通知ワークのレコードの設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC RETURN NUMBER IS
        bRTN                  BOOLEAN;                             --戻る値
        nRTN                  NUMBER;
        rBUNNUMSRCINF         KKAPK0040.MR_BUNNUMSRCINF;           --文書番号情報（構造体）
        rBUNNUMEDITKEKA       KKAPK0040.MR_BUNNUMEDITKEKA;         --文書番号編集結果
        sNUM                  NVARCHAR2(1000);                     --文書番号
        sDATEED               NVARCHAR2(1000);                     --文書日付
        aITEM                 A_CONS_PRM;                          --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        rWLTBL                GKBWL660R001%ROWTYPE;                --就学猶予免除通知ワーク
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
        o_rHKSKIHON           GABTATENAKIHON%ROWTYPE;              --保護者の宛名基本
        o_rHKSSOFUSAKI        GABTSOFUSAKI%ROWTYPE;                --保護者の送付先基本
        o_rJDSTKIHON          GABTATENAKIHON%ROWTYPE;              --児童生徒の宛名基本
        o_rJDSTSOFUSAKI       GABTSOFUSAKI%ROWTYPE;                --児童生徒の送付先基本
        sHAKKOBI_BYOJI        NVARCHAR2(20);                       --発行年月日_表示
        rTSUCHISHOKANRI       GKBTTSUCHISHOKANRI%ROWTYPE;          --通知書管理テーブルのレコード
        sGYOMU_CD             PLS_INTEGER;                         --抑止レベル３制御の要否（0：非該当、1：該当）
        SCTLPRM               NVARCHAR2(500);                      --住所マスク文字列
        sYUBIN_NO             NVARCHAR2(20);
        o_sSHIMEIKANA         NVARCHAR2(1000);                     --氏名カナ
        o_sSHIMEIKANJI        NVARCHAR2(1000);                     --氏名漢字
        o_sBIRTHDAY           NVARCHAR2(1000);                     --生年月日
        nNYUGAKU_INDEXNO      NUMBER;                              --入学予定通知書_インデックス番号
        sNYUGAKU_SYUTURYOKU   NVARCHAR2(1000);                     --入学予定通知書_出力制御
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10011、IT_GKB_10012対応 Start    
        o_JIDOSHIMEIKANA         NVARCHAR2(1000);                     --児童氏名カナ
        o_JIDOSHIMEIKANJI        NVARCHAR2(1000);                     --児童氏名漢字 
        o_JIDOBIRTHDAY           NVARCHAR2(1000);                     --生年月日  
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10011、IT_GKB_10012対応 End
        
    BEGIN
        -- 公印情報を取得する
        bRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE,0),
                                     g_sWSNUM,
                                     SYSDATE,
                                     o_nDAIRIKBN,
                                     o_sKATAGAKI1,
                                     o_sKATAGAKI2,
                                     o_sSHIMEI,
                                     o_sKOINFILENAME);
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
        sTOIAWASE1 := o_SHIMEIPRM(1);     --お問い合わせ先１
        sTOIAWASE2 := o_SHIMEIPRM(6);     --お問い合わせ先２
        sTOIAWASE3 := o_SHIMEIPRM(7);     --お問い合わせ先３
        --発行年月日の編集
        sHAKKOBI_BYOJI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_sHASSOBI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10);    --発行年月日_表示
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
        -- システム制御設定を取得
        -- 外国人　氏名・生年月日制御帳票(ID)のリストを取得
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aITEM);
        --「GKB660R001」が格納されている箇所のインデックス番号
        IF nRTN = 0 THEN
            FOR i IN 1..aITEM.COUNT LOOP
                IF aITEM(i) = 'GKB660R001' THEN
                    nNYUGAKU_INDEXNO := i;    --入学予定通知書_インデックス番号
                    EXIT;
                END IF;
            END LOOP;
        END IF;
        -- 「本名・通称名　出力制御」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aITEM);
        IF nRTN = 0 AND nNYUGAKU_INDEXNO <= aITEM.COUNT THEN
            sNYUGAKU_SYUTURYOKU := aITEM(nNYUGAKU_INDEXNO);    --入学予定通知書_出力制御
        END IF;
        -- 通知書管理テーブルのデータを取得
        BEGIN
            SELECT
                  KOIN_SHORYAKU              --公印省略
                , KOIN_CHUSHAKU              --公印注釈
                , CHOHYO_MEI                 --帳票名
                , TSUCHIBUN                  --通知文
                , BIKO_TITLE                 --備考タイトル
                , YOSHIKI_BANGO_SETTOGO      --様式番号接頭語
                , YOSHIKI_BANGO              --様式番号
                , YOSHIKI_BANGO_SETSUBIGO    --様式番号接尾語
            INTO
                  rTSUCHISHOKANRI.KOIN_SHORYAKU
                , rTSUCHISHOKANRI.KOIN_CHUSHAKU
                , rTSUCHISHOKANRI.CHOHYO_MEI
                , rTSUCHISHOKANRI.TSUCHIBUN
                , rTSUCHISHOKANRI.BIKO_TITLE
                , rTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO
                , rTSUCHISHOKANRI.YOSHIKI_BANGO
                , rTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO
            FROM
                GKBTTSUCHISHOKANRI
            WHERE
                CHOHYO_KBN = g_nCHOHYOKBN;   --帳票区分
        EXCEPTION
            WHEN OTHERS THEN
                rTSUCHISHOKANRI.KOIN_SHORYAKU           := NULL;
                rTSUCHISHOKANRI.KOIN_CHUSHAKU           := NULL;
                rTSUCHISHOKANRI.CHOHYO_MEI              := NULL;
                rTSUCHISHOKANRI.TSUCHIBUN               := NULL;
                rTSUCHISHOKANRI.BIKO_TITLE              := NULL;
                rTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO   := NULL;
                rTSUCHISHOKANRI.YOSHIKI_BANGO           := NULL;
                rTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO := NULL;
        END;
        -- 学齢簿から下記の項目の取得する
        OPEN CUR_GAKUREIBO;
            LOOP
                FETCH CUR_GAKUREIBO INTO REC_GAKUREIBO;
                EXIT WHEN CUR_GAKUREIBO%NOTFOUND;
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
                --g_nPRTSORT := g_nPRTSORT + 1;
                --保護者の宛名情報を取得する
                nRTN := GAAPK0030.FGETATENA2(REC_GAKUREIBO.HOGOSYA_KOJIN_NO,
                                             'GKB',
                                             TO_NUMBER(TO_CHAR(TO_DATE(g_sHASSOBI, 'YYYYMMDD'), 'YYYYMMDD')),
                                             o_rHKSKIHON,
                                             o_rHKSSOFUSAKI);
                --児童の宛名情報を取得する
                nRTN := GAAPK0030.FGETATENA(g_nATENANO,
                                            'GKB',
                                             TO_NUMBER(TO_CHAR(TO_DATE(g_sHASSOBI, 'YYYYMMDD'), 'YYYYMMDD')),
                                             o_rJDSTKIHON,
                                             o_rJDSTSOFUSAKI);
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応                             
                --rWLTBL.NO := g_nPRTSORT;            --ソート順
--  2024/12/18 JPJYS.LIUHUAIQI ADD 0.3.000.008:品質強化：IT_GKB_10060,IT_GKB_10061対応 START
                --保護者の本名使用制御判定
                nRTN := GKBFKHMCTRL(g_nATENANO, g_rOPRT.CHOHYOID, 1, sNYUGAKU_SYUTURYOKU,o_sSHIMEIKANA, o_sSHIMEIKANJI, o_sBIRTHDAY);
                --抑止住所編集
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
                -- SCTLPRM := GAAPK0030.FDVJUSHO('GKB',
                --                               REC_GAKUREIBO.HOGOSYA_KOJIN_NO,
                --                               g_sTANTOCODE,
                --                               g_sWSNUM,
                --                               rWLTBL.JHUSHO,
                --                               sGYOMU_CD,
                --                               2);
                --現住所
                -- IF g_nHIENTAISYOUJUSHO = 1 AND sGYOMU_CD = 1 THEN
                IF g_nHIENTAISYOUJUSHO = 1  THEN
                    SCTLPRM := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
                    rWLTBL.GENJUSHO := SCTLPRM;
                ELSE
--  2025/01/06 JPJYS.GAOJIAN UPDATE 0.3.000.008:品質強化：IT_GKB_10100対応 START
--                  rWLTBL.GENJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rHKSKIHON.CHOMEI, o_rHKSKIHON.BANCHI, o_rHKSKIHON.KATAGAKI, NULL);
                    rWLTBL.GENJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rJDSTKIHON.CHOMEI, o_rJDSTKIHON.BANCHI, o_rJDSTKIHON.KATAGAKI, NULL);
--  2025/01/06 JPJYS.GAOJIAN UPDATE 0.3.000.008:品質強化：IT_GKB_10100対応 END
                END IF;
--  2024/12/18 JPJYS.LIUHUAIQI ADD 0.3.000.008:品質強化：IT_GKB_10060,IT_GKB_10061対応 END
                --宛先=0（保護者）の場合
                IF g_sATESAKI = 0 THEN
--  2024/12/18 JPJYS.LIUHUAIQI UPD 0.3.000.008:品質強化：IT_GKB_10060,IT_GKB_10061対応 START
--                    --郵便番号編集処理
--                    nRTN := KKAPK0010.FYUBINHENSHU(o_rHKSSOFUSAKI.YUBIN_NO, sYUBIN_NO);
--                    rWLTBL.YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO, 0);    --郵便番号
--                    --住所
--                    rWLTBL.JHUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rHKSSOFUSAKI.CHOMEI, o_rHKSSOFUSAKI.BANCHI, NULL, NULL);
--                    rWLTBL.KATAGAKI := o_rHKSSOFUSAKI.KATAGAKI;                     --方書
--                    --現住所
--                    rWLTBL.GENJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rHKSKIHON.CHOMEI, o_rHKSKIHON.BANCHI, o_rHKSKIHON.KATAGAKI, NULL);
--                    --抑止住所編集
--                    SCTLPRM := GAAPK0030.FDVJUSHO('GKB',
--                                                  REC_GAKUREIBO.HOGOSYA_KOJIN_NO,
--                                                  g_sTANTOCODE,
--                                                  g_sWSNUM,
--                                                  rWLTBL.JHUSHO,
--                                                  sGYOMU_CD,
--                                                  2);
--                    IF g_nHIENTAISYOUJUSHO = 1 THEN
                        --保護者宛名番号でDV判定を行い
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
                    -- IF g_nHIENTAISYOUJUSHO = 1 AND sGYOMU_CD = 1 THEN
                    IF g_nHIENTAISYOUJUSHO = 1  THEN
                        SCTLPRM := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
--                        IF sGYOMU_CD = 1 THEN
                        rWLTBL.JHUSHO := SCTLPRM;                                --住所
                        rWLTBL.KATAGAKI := NULL;                                 --方書
                        rWLTBL.YUBIN_NO := NULL;                                 --郵便番号
                        rWLTBL.BC_NO    := NULL;                                 --カスタマバーコード
--                            --抑止住所編集
--                            SCTLPRM := GAAPK0030.FDVJUSHO('GKB',
--                                                          REC_GAKUREIBO.HOGOSYA_KOJIN_NO,
--                                                          g_sTANTOCODE,
--                                                          g_sWSNUM,
--                                                          rWLTBL.GENJUSHO,
--                                                          sGYOMU_CD,
--                                                          2);
--                            rWLTBL.GENJUSHO := SCTLPRM;                              --現住所
--                        END IF;
                    ELSE
                        --郵便番号編集処理
                        nRTN := KKAPK0010.FYUBINHENSHU(o_rHKSSOFUSAKI.YUBIN_NO, sYUBIN_NO);
                        rWLTBL.YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO, 0);    --郵便番号
                        --住所
                        rWLTBL.JHUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rHKSSOFUSAKI.CHOMEI, o_rHKSSOFUSAKI.BANCHI, NULL, NULL);
                        rWLTBL.KATAGAKI := o_rHKSSOFUSAKI.KATAGAKI;                     --方書
                        rWLTBL.BC_NO := o_rHKSSOFUSAKI.YUBIN_NOBC;                      --カスタマバーコード
--  2024/12/18 JPJYS.LIUHUAIQI UPD 0.3.000.008:品質強化：IT_GKB_10060,IT_GKB_10061対応 END
                    END IF;
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10011、IT_GKB_10012対応 Start 
--  2024/12/18 JPJYS.LIUHUAIQI DEL 0.3.000.008:品質強化：IT_GKB_10060,IT_GKB_10061対応 START
--                    --保護者の本名使用制御判定
--                    nRTN := GKBFKHMCTRL(g_nATENANO, g_rOPRT.CHOHYOID, 1, sNYUGAKU_SYUTURYOKU,o_sSHIMEIKANA, o_sSHIMEIKANJI, o_sBIRTHDAY);--                                
--  2024/12/18 JPJYS.LIUHUAIQI DEL 0.3.000.008:品質強化：IT_GKB_10060,IT_GKB_10061対応 END
                    rWLTBL.KOJIN := o_sSHIMEIKANJI || '　' || '様';   --宛名
                    --rWLTBL.KOJIN := o_rJDSTSOFUSAKI.SHIMEI_KANJI || '　' || '様';     --宛名
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10011、IT_GKB_10012対応 End                        
                ELSE
                    rWLTBL.YUBIN_NO := NULL;                                         --郵便番号
                    rWLTBL.JHUSHO   := NULL;                                         --住所
                    rWLTBL.KATAGAKI := NULL;                                         --方書
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10060,IT_GKB_10061対応 START
                    rWLTBL.BC_NO    := NULL;                                         --カスタマバーコード
--                    rWLTBL.GENJUSHO := NULL;                                         --現住所
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10060,IT_GKB_10061対応 END
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10059対応 START
--                    --学齢簿.小学校コードあるの場合
--                    IF REC_GAKUREIBO.SYOGAKO_CD IS NOT NULL THEN
--                        --学齢簿.中学校コードあるの場合
--                        IF REC_GAKUREIBO.TYUGAKO_CD IS NOT NULL THEN
                    IF REC_GAKUREIBO.GAKUNEN IN (7,8,9) THEN
                        --宛名
--  2024/12/20 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:品質強化：IT_GKB_10112対応 START
--                        rWLTBL.KOJIN := GKAFKGKOGTEQ(REC_GAKUREIBO.GAKKO_KBN_CD, REC_GAKUREIBO.TYUGAKO_CD) || '学校長　様';
                        rWLTBL.KOJIN := GKAFKGKOGTEQ(REC_GAKUREIBO.GAKKO_KBN_CD, REC_GAKUREIBO.TYUGAKO_CD) || '長　様';
--                        ELSE
                    ELSIF REC_GAKUREIBO.GAKUNEN IN (0,1,2,3,4,5,6) THEN
                        --宛名
--                        rWLTBL.KOJIN := GKAFKGKOGTEQ(REC_GAKUREIBO.GAKKO_KBN_CD, REC_GAKUREIBO.SYOGAKO_CD) || '学校長　様';
                        rWLTBL.KOJIN := GKAFKGKOGTEQ(REC_GAKUREIBO.GAKKO_KBN_CD, REC_GAKUREIBO.SYOGAKO_CD) || '長　様';
--  2024/12/20 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:品質強化：IT_GKB_10112対応 END
--                        END IF;
                    END IF;
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_10059対応 END
                END IF;
--  2024/12/18 JPJYS.LIUHUAIQI DEL 0.3.000.008:品質強化：IT_GKB_10060,IT_GKB_10061対応 START
--                rWLTBL.BC_NO := o_rHKSSOFUSAKI.YUBIN_NOBC;                           --カスタマバーコード
--  2024/12/18 JPJYS.LIUHUAIQI DEL 0.3.000.008:品質強化：IT_GKB_10060,IT_GKB_10061対応 END
                rWLTBL.BUNSHO_NO := sNUM;                                            --文書番号
                --発行年月日
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.006:品質強化IT_GKB_10058対応 START
--                rWLTBL.HAKKOBI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sDATEED, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10);
                IF sDATEED = '' THEN
                    rWLTBL.HAKKOBI := '';
                ELSE
                    rWLTBL.HAKKOBI := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(TO_NUMBER(REPLACE(sDATEED,'/','')),0,3),' ',''));
                END IF;
--  2024/12/18 JPJYS.LIUHUAIQI UPDATE 0.3.000.006:品質強化IT_GKB_10058対応 END
--  2024/09/26 ZCZL.WANGMING UPDATE START 0.3.000.001:仕様変更　ID：IT_GKB_00064対応
--                rWLTBL.NINSHO_SHOKUSHU:= o_sKATAGAKI1 || '市教育委員会';               --認証者職種
--                rWLTBL.NINSHO_SHIMEI  := o_sSHIMEI || '様';                          --認証者氏名
                rWLTBL.NINSHO_SHOKUSHU:= o_sKATAGAKI1;                                 --認証者職種
                rWLTBL.NINSHO_SHIMEI  := o_sSHIMEI;                                    --認証者氏名
--  2024/09/26 ZCZL.WANGMING UPDATE END
                rWLTBL.KOIN := o_sKOINFILENAME;                                      --公印
                IF o_sKOINFILENAME IS NULL THEN
                    rWLTBL.KOIN_SHORYAKU := rTSUCHISHOKANRI.KOIN_SHORYAKU;           --公印（省略）
                    rWLTBL.KOIN_CHUSHAKU := NULL;                                    --公印（注釈）
                ELSE
                    rWLTBL.KOIN_SHORYAKU := NULL;                                    --公印（省略）
                    rWLTBL.KOIN_CHUSHAKU := rTSUCHISHOKANRI.KOIN_CHUSHAKU;           --公印（注釈）
                END IF;
                rWLTBL.CHOHYO_TITLE := rTSUCHISHOKANRI.CHOHYO_MEI;                   --帳票タイトル
                --通知文
                rWLTBL.TSUCHIBUN := REPLACE(rTSUCHISHOKANRI.TSUCHIBUN, chr(13)||chr(10),'#');
                --児童生徒の本名使用制御判定
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10011、IT_GKB_10012対応 Start 
                --nRTN := GKBFKHMCTRL(g_nATENANO, g_nCHOHYOKBN, 0, sNYUGAKU_SYUTURYOKU,o_sSHIMEIKANA, o_sSHIMEIKANJI, o_sBIRTHDAY);
                nRTN := GKBFKHMCTRL(g_nATENANO, g_rOPRT.CHOHYOID, 0, sNYUGAKU_SYUTURYOKU,o_JIDOSHIMEIKANA, o_JIDOSHIMEIKANJI, o_JIDOBIRTHDAY);
                --rWLTBL.JIDO_SHIMEI_KANA := o_sSHIMEIKANA;                            --児童生徒氏名カナ
                rWLTBL.JIDO_SHIMEI_KANA := o_JIDOSHIMEIKANA;                            --児童生徒氏名カナ
                --rWLTBL.JIDO_SHIMEI_KANJI := o_sSHIMEIKANJI;                          --児童生徒氏名漢字
                rWLTBL.JIDO_SHIMEI_KANJI := o_JIDOSHIMEIKANJI;                          --児童生徒氏名漢字
                --rWLTBL.SEINENGAPI := o_sBIRTHDAY;                                    --生年月日
                rWLTBL.SEINENGAPI := o_JIDOBIRTHDAY;                                    --生年月日
                --保護者の本名使用制御判定
                --nRTN := GKBFKHMCTRL(g_nATENANO, g_nCHOHYOKBN, 1, sNYUGAKU_SYUTURYOKU,o_sSHIMEIKANA, o_sSHIMEIKANJI, o_sBIRTHDAY);
--  2024/12/10 JPJYS.LIUJUNHAO UPDATE 0.3.000.005:品質強化IT_GKB_10011、IT_GKB_10012対応 End                
                rWLTBL.HOGOSHA_SHIMEI_KANA := o_sSHIMEIKANA;                         --保護者氏名カナ
                rWLTBL.HOGOSHA_SHIMEI_KANJI := o_sSHIMEIKANJI;                       --保護者氏名漢字
                rWLTBL.KYOKA_KIKAN := g_sKYOKAKIKAN;                                 --許可期間
                rWLTBL.JIYU       := REPLACE(g_sJIYU, chr(13)||chr(10),'#');         --事由
                rWLTBL.BIKO       := REPLACE(g_sBIKO, chr(13)||chr(10),'#');         --備考
                rWLTBL.TOIAWASE1  := sTOIAWASE1;                                     --お問い合わせ先1
                rWLTBL.TOIAWASE2  := sTOIAWASE2;                                     --お問い合わせ先2
                rWLTBL.TOIAWASE3  := sTOIAWASE3;                                     --お問い合わせ先3
                rWLTBL.BIKO_TITLE := rTSUCHISHOKANRI.BIKO_TITLE;                     --備考タイトル
                --様式番号
                rWLTBL.YOSHIKI_NO := rTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO || rTSUCHISHOKANRI.YOSHIKI_BANGO || rTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                rWLTBL.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rWLTBL.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
                rWLTBL.BREAK_NO   := NULL;                                           --改ページキー
                rWLTBL.WSNUM      := g_sWSNUM;                                       --端末番号
                rWLTBL.BATCHKBN   := c_ONLINE;                                       --即時バッチ区分
                rWLTBL.JOBNUM     := g_nJOBNUM;                                      --ジョブNO
                FOR i IN 1..g_nHAKKOSU LOOP
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応  
                    g_nPRTSORT := g_nPRTSORT + 1;
                    rWLTBL.NO := g_nPRTSORT;            --ソート順
--  2024/11/15 ZCZL.WANGYUNING UPDATE END
                    --登録ワークテーブル
                    INSERT INTO GKBWL660R001 VALUES rWLTBL;
                END LOOP;
                g_nHALTSUKOUCODE := g_nHALTSUKOUCODE + 1;
            END LOOP;
        CLOSE CUR_GAKUREIBO;
        -- 関数終了
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
            IF CUR_GAKUREIBO%ISOPEN THEN
                CLOSE CUR_GAKUREIBO;
            END IF;
            RETURN c_ERR;
    END FUNC_GET_JIDO_REC;
    --------------------------------------------------------
    --  機能概要      : データ取得、ワークテーブル登録
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/06
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
        BEGIN
            DELETE FROM GKBWL660R001
            WHERE WSNUM = g_sWSNUM
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00632対応 
            --AND BATCHKBN = g_nNRIREKIRENBAN;
            AND BATCHKBN = c_ONLINE;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN FALSE;
        END;
        -- 就学猶予免除通知ワークのレコードの設定
        nRTN := FUNC_GET_JIDO_REC;
        IF nRTN <> 0 THEN
          RAISE ERR;
        END IF;
        -- 帳票出力CSVの作成
        bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL660R001', i_sCHOHYOID);
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/06
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
END GKBPA00150;
/