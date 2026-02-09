CREATE OR REPLACE PACKAGE BODY GKBPA00050
--1.0.106.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 就学時健康診断結果通知書即時
--  機能概要      : 就学時健康診断結果通知書即時を作成する
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
--------------------------------------------------------
--  修正履歴
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE 0.3.000.000:新WizLIFE２次開発(標準化)
--  2024/08/20 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00018対応
--  2024/09/13 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00433対応
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00539横展開対応
--  2024/11/21 ZCZL.ZHANGLEI UPDATE 0.3.000.005:IT_GKC_00329横展開対応
--  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応
--  2025/05/08 CTC.LIUJUNHAO UPDATE 1.0.003.000:GKB_QA13561_宛先の名前が印字されない対応
--  2025/07/01 CTC.HJF UPDATE 1.0.010.001:GKB_QA17602
--  2025/07/18 CTC.HJF UPDATE 1.0.010.001:GKB_QA17896対応
--  2025/08/18 CTC.GYY UPDATE 1.0.102.000:GKB_QA19542対応
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
    g_sNKOJIN_NO                  NUMBER;                      --個人番号
    g_sNRIREKI_RENBAN             NUMBER;                      --履歴連番
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE 0.3.000.000:新WizLIFE２次開発(標準化)
--    g_sNHASSO_NO                  NUMBER;                      --発送番号
    g_nCHOHYO_KBN                 NUMBER;                      --帳票区分
    g_sNHASSO_BI                  NUMBER;                      --発送日
    g_sNIINKAI                    NUMBER;                      --教育委員会の連番
--  2024/07/05 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発(標準化)
    g_sBUNSHOLIST                 NVARCHAR2(1000);             --文書番号（リスト）
    g_nSHIENSOCHIKBN              NUMBER;                      --支援措置対象住所非表示
    g_nHAKKOSU                    NUMBER;                      --発行部数
--  2024/07/05 ZCZL.GUANJINGHENG ADD END
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- 処理結果
    c_ISUCCESS     CONSTANT PLS_INTEGER := 0;  -- 正常
    c_INOT_SUCCESS CONSTANT PLS_INTEGER := -1; -- 異常
    -- 帳票区分
    c_CHOHYO_KBN CONSTANT NUMBER(2) := 5;      -- 健康診断通知書
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    -- ERROR関連 --
    I_RTN      PLS_INTEGER;     -- 戻り値
    VKIJUNBI     PLS_INTEGER;                 -- 年齢計算用基準日
    BRTN         BOOLEAN;                     -- サブルーチンの戻り値
    ISAKUSEIBI   PLS_INTEGER;
    HASSO_BI                           PLS_INTEGER;   --処理条件４.発行日
    --公印ファイル名取得
    VGYOMU           NVARCHAR2(100); --業務毎公印ファイル名
--  2024/08/20 ZCZL.WANGMING UPDATE Start 0.3.000.001:IT_GKB_00018対応
--    VNINSHO_KATAGAKI NVARCHAR2(100);
--    VNINSHO_SHIMEI   NVARCHAR2(40);
--  2024/08/20 ZCZL.WANGMING DELETE End
    NNENDO           PLS_INTEGER;
    VHYOUJINENDO     NVARCHAR2(30);  -- 年度
    RA               GABTATENAKIHON%ROWTYPE;
    RASO             GABTSOFUSAKI%ROWTYPE;
    o_SHIMEIPRM      A_CONS_PRM;   --氏名印字.制御ﾊﾟﾗﾒｰﾀ
    BPRMFLG_001      BOOLEAN;
    BPRMFLG_002      BOOLEAN;
    BPRMFLG_003      BOOLEAN;
    BPRMFLG_004      BOOLEAN;
    o_YMD2           NVARCHAR2(30);
    N_NAIYO_CD       GKBTSHIMEIJKN.NAIYO_CD%TYPE;
    KYOIKUKAI_RENRAKUSAKI  NVARCHAR2(100);
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
    CURSOR GAKUREIBO(p_KojinNo IN NUMBER, p_RirekiRenban IN NUMBER) IS
      SELECT A.KOJIN_NO KOJIN_NO,
             A.HOGOSYA_KOJIN_NO,
             NVL(B1.SHIMEI_KANA, ' ') SHIMEI_KANA,
             NVL(B1.SHIMEI_KANJI, ' ') SHIMEI_KANJI,
             DECODE(NVL(B1.SEIBETSU, 0), 1, '男', 2, '女', ' ') SEIBETSU,
             NVL(B1.SEINENGAPI, 0) SEINENGAPI,
             NVL(B2.SHIMEI_KANA, ' ') HOGOSYA_SHIMEI_KANA,
             NVL(B2.SHIMEI_KANJI, ' ') HOGOSYA_SHIMEI_KANJI,
             NVL(C.DATE1, 0) IDATE1,
             NVL(C.DATE2, 0) IDATE2,
             NVL(C.DATE3, 0) IDATE3,
             NVL(C.DATE4, 0) IDATE4,
             NVL(C.DATE5, 0) IDATE5,
             NVL(C.KOMOKU1, ' ') VKOMOKU1,
             NVL(C.KOMOKU2, ' ') VKOMOKU2,
             NVL(C.KOMOKU3, ' ') VKOMOKU3,
             NVL(C.KOMOKU4, ' ') VKOMOKU4,
             NVL(C.KOMOKU5, ' ') VKOMOKU5,
             NVL(C.KOMOKU6, ' ') VKOMOKU6,
             NVL(C.KOMOKU7, ' ') VKOMOKU7,
             NVL(C.KOMOKU8, ' ') VKOMOKU8,
             NVL(C.KOMOKU9, ' ') VKOMOKU9,
             NVL(C.KOMOKU10, ' ') VKOMOKU10,
             NVL(F1.ZOKUGARAMEI, ' ') ZOKUGARAMEI1,
             NVL(F2.ZOKUGARAMEI, ' ') ZOKUGARAMEI2,
             NVL(F3.ZOKUGARAMEI, ' ') ZOKUGARAMEI3,
             NVL(F4.ZOKUGARAMEI, ' ') ZOKUGARAMEI4,
             NVL(A.SYOGAKO_CD, 0) SYOGAKO_CD,
             NVL(A.SYOGAKO_TENGAKU_BI, 0) SYOGAKO_TENGAKU_BI,
             NVL(A.SYOGAKO_SOTSUGYO_BI, 0) SYOGAKO_SOTSUGYO_BI,
             NVL(A.KUIKIGAI_CD, 0) KUIKIGAI_CD,
             NVL(A.KUIKIGAI_TENGAKU_BI, 0) KUIKIGAI_TENGAKU_BI,
             NVL(A.KUIKIGAI_TAIGAKU_BI, 0) KUIKIGAI_TAIGAKU_BI,
             NVL(A.KUIKIGAI_SOTSUGYO_BI, 0) KUIKIGAI_SOTSUGYO_BI,
             NVL(A.YOGOGAKO_CD, 0) YOGOGAKO_CD,
             NVL(A.YOGOGAKO_TENGAKU_BI, 0) YOGOGAKO_TENGAKU_BI,
             NVL(A.YOGOGAKO_TAIGAKU_BI, 0) YOGOGAKO_TAIGAKU_BI,
             NVL(A.YOGOGAKO_SOTSUGYO_BI, 0) YOGOGAKO_SOTSUGYO_BI,
             A.CHOHYO_NO CHOHYO_NO
        FROM 
            GKBTGAKUREIBO A,
            GABTATENAKIHON B1,
            GABTATENAKIHON B2,
            GKBTTSUCHISHOJKN C,
            GKBTZOKUGARA F1,
            GKBTZOKUGARA F2,
            GKBTZOKUGARA F3,
            GKBTZOKUGARA F4
       WHERE A.HOGOSYA_KOJIN_NO = B2.KOJIN_NO(+)
         AND A.HOGOSYA_ZOKUGARA1 = F1.ZOKUGARA_CD(+)
         AND A.HOGOSYA_ZOKUGARA2 = F2.ZOKUGARA_CD(+)
         AND A.HOGOSYA_ZOKUGARA3 = F3.ZOKUGARA_CD(+)
         AND A.HOGOSYA_ZOKUGARA4 = F4.ZOKUGARA_CD(+)
         AND A.RIREKI_RENBAN = p_RirekiRenban
         AND B1.KOJIN_NO = p_KojinNo
         AND B1.KOJIN_NO = A.KOJIN_NO(+)
         AND C.CHOHYO_KBN(+) = 1
         AND A.SYOGAKO_CD = C.GAKO_CD(+)
         AND F1.ZOKUGARA_KBN(+) = 2
         AND F2.ZOKUGARA_KBN(+) = 2
         AND F3.ZOKUGARA_KBN(+) = 2
         AND F4.ZOKUGARA_KBN(+) = 2;
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
                     g_sNKOJIN_NO       := TO_NUMBER(aCSV_TBL(i));      -- 個人番号
                WHEN 2 THEN
                     g_sNRIREKI_RENBAN  := TO_NUMBER(aCSV_TBL(i));      -- 履歴連番
                WHEN 3 THEN
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE 0.3.000.000:新WizLIFE２次開発(標準化)
--                     g_sNHASSO_NO       := TO_NUMBER(aCSV_TBL(i));      -- 発送番号
                     g_nCHOHYO_KBN      := TO_NUMBER(aCSV_TBL(i));      -- 帳票区分
                WHEN 4 THEN
                     g_sNHASSO_BI       := TO_NUMBER(aCSV_TBL(i));      -- 発送日
                WHEN 5 THEN
                     g_sNIINKAI         := TO_NUMBER(aCSV_TBL(i));      -- 教育委員会の連番
--  2024/07/05 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発(標準化)
                WHEN 6 THEN
--  2024/11/21 ZCZL.ZHANGLEI UPDATE 0.3.000.005:IT_GKC_00329横展開対応
                     --g_sBUNSHOLIST      := TO_NUMBER(aCSV_TBL(i));      -- 文書番号（リスト）
                     g_sBUNSHOLIST      := aCSV_TBL(i);      -- 文書番号（リスト）
                WHEN 7 THEN
                     g_nSHIENSOCHIKBN   := TO_NUMBER(aCSV_TBL(i));      -- 支援措置対象住所非表示
                WHEN 8 THEN
                     g_nHAKKOSU         := TO_NUMBER(aCSV_TBL(i));      -- 発行部数
--  2024/07/05 ZCZL.GUANJINGHENG ADD END
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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

    --------------------------------------------------------------------------------------------------
    -- 教育委員会連絡先を取得
    --------------------------------------------------------------------------------------------------
    FUNCTION GET_EQRENRAKUSAKI(i_SEIGYORENBAN IN NUMBER
                              ,i_EQNAME       IN GKBWJIDOSHINDAN.KYOIKUKAI_MEI%TYPE
                              ,i_EQTELNO      IN GKBWJIDOSHINDAN.KYOIKU_TEL%TYPE
                              ,i_EQNAISENNO   IN GKBWJIDOSHINDAN.KYOIKU_TEL_NAISEN%TYPE) RETURN VARCHAR2 IS
      EQRENRAKUSAKI  NVARCHAR2(100);  --教育委員会連絡先
      SEIGYO         A_CONS_PRM;     --印字制御
      LEN            NUMBER;         --印字制御数
      RTN_NUM        NUMBER;
    BEGIN
      --印字制御を取得
      RTN_NUM := KKAPK0030.FPRMSHUTOKU('GKB', 'EQRENRAKUSAKI', i_SEIGYORENBAN, SEIGYO, LEN);
      IF RTN_NUM = 1 THEN
        RETURN '';
      END IF;
      WHILE (LEN < 3) LOOP
        SEIGYO.EXTEND;
        SEIGYO(LEN + 1) := NULL;
        LEN := LEN + 1;
      END LOOP;
      --教育委員会名を取得
      IF SEIGYO(1) = 1 THEN
        EQRENRAKUSAKI := EQRENRAKUSAKI || i_EQNAME;
      END IF;
      --教育委員会電話番号を取得
      IF SEIGYO(2) = 1 THEN
        IF EQRENRAKUSAKI IS NULL THEN
          EQRENRAKUSAKI := EQRENRAKUSAKI || i_EQTELNO;
        ELSE
          EQRENRAKUSAKI := EQRENRAKUSAKI || '　　' || i_EQTELNO;
        END IF;
      END IF;
      --教育委員会内線番号を取得
      IF SEIGYO(3) = 1 AND TRIM(i_EQNAISENNO) IS NOT NULL THEN
        EQRENRAKUSAKI := EQRENRAKUSAKI || '（内線：' || i_EQNAISENNO || '）';
      END IF;
      RETURN SUBSTR(EQRENRAKUSAKI, 1, 100);
    END GET_EQRENRAKUSAKI;
    --------------------------------------------------------------------------------
    -- 日付変換
    --------------------------------------------------------------------------------
    PROCEDURE PROC_GET_YMD(i_YMD IN NUMBER, o_YMD OUT NVARCHAR2) IS
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
      BRTN := KKAPK0020.FDAYEDIT(io_WAREKIHIZUKE,
                                  io_SEIREKIHIZUKE,
                                  o_EDIT_GYYMMDD1,
                                  o_EDIT_GYYMMDD2,
                                  o_EDIT_GYYMMDD3,
                                  o_KJ_GENGO,
                                  o_KG_GENGO,
                                  o_WAREKI_YY,
                                  o_SEIREKI_YYYY,
                                  o_WAREKI_GYYMM,
                                  o_MM,
                                  o_DD,
                                  o_IWAREKIHIZUKE,
                                  o_ISEIREKIHIZUKE);
      IF BRTN THEN
        o_YMD := o_EDIT_GYYMMDD3;
      ELSE
        o_YMD := ' ';
      END IF;
    END PROC_GET_YMD;
    --------------------------------------------------------------------------------
    -- 制御のフラグをセットするのを行う
    --------------------------------------------------------------------------------
    FUNCTION FUNC_PRMFLGSET(i_KOJIN_NO IN NUMBER,i_SHIMEIPRM IN NUMBER,o_NAIYO_CD OUT NUMBER) RETURN NUMBER IS
      NODATAFOUND_FLG    BOOLEAN;
      ZERO_FLG           BOOLEAN;
    BEGIN
      --フラグ初期化
      BPRMFLG_001      := FALSE;
      BPRMFLG_002      := FALSE;
      BPRMFLG_003      := FALSE;
      BPRMFLG_004      := FALSE;
      NODATAFOUND_FLG  := FALSE;
      ZERO_FLG         := FALSE;
      --本名使用制御管理情報の取得
      BEGIN 
        SELECT NAIYO_CD
          INTO o_NAIYO_CD
          FROM GKBTSHIMEIJKN
         WHERE KOJIN_NO = i_KOJIN_NO
           AND CHOHYO_ID = 'GKB060R001';
        IF o_NAIYO_CD = 0 THEN
          ZERO_FLG  := TRUE;
        END IF;
      EXCEPTION
        --データを取得しない場合
        WHEN NO_DATA_FOUND THEN
        NODATAFOUND_FLG  := TRUE;
      END;
      --氏名印字.制御ﾊﾟﾗﾒｰﾀ(5)が1の場合
      IF i_SHIMEIPRM = 1 THEN
        BPRMFLG_001  := TRUE;
      END IF;
      --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(5)が4、6場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF i_SHIMEIPRM IN (4, 6) THEN
          BPRMFLG_002  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在する、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(5)が3、4、5、6場合
      IF NOT NODATAFOUND_FLG AND NOT ZERO_FLG THEN
        IF i_SHIMEIPRM IN(3,4,5,6) THEN
          BPRMFLG_003  := TRUE;
        END IF;
      END IF;
        -- 本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(5)が4、5場合「生年月日」
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF i_SHIMEIPRM IN (4, 5) THEN
          BPRMFLG_004  := TRUE;
        END IF;
      END IF;
    RETURN 0;
    END FUNC_PRMFLGSET;
    --------------------------------------------------------------------------------
    -- 日付変換2
    --------------------------------------------------------------------------------
    PROCEDURE PROC_GET_YMD1(i_KBN IN NUMBER,i_YMD IN NUMBER, o_YMD OUT NVARCHAR2) IS
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
      BRTN := KKAPK0020.FDAYEDIT(io_WAREKIHIZUKE,
                                  io_SEIREKIHIZUKE,
                                  o_EDIT_GYYMMDD1,
                                  o_EDIT_GYYMMDD2,
                                  o_EDIT_GYYMMDD3,
                                  o_KJ_GENGO,
                                  o_KG_GENGO,
                                  o_WAREKI_YY,
                                  o_SEIREKI_YYYY,
                                  o_WAREKI_GYYMM,
                                  o_MM,
                                  o_DD,
                                  o_IWAREKIHIZUKE,
                                  o_ISEIREKIHIZUKE);
      IF BRTN THEN
        IF i_KBN = 1 THEN
            IF BPRMFLG_004 THEN
              --GKBPK00010.FYMDEDT1より取得した表示生年月日
              I_RTN := GKBPK00010.FYMDEDT1(i_YMD,o_YMD,o_YMD2);
              o_YMD := o_YMD2;
            ELSIF BPRMFLG_003 THEN
              -- 和暦で表示生年月日
              IF N_NAIYO_CD IN(11,21) THEN
                o_YMD    := o_EDIT_GYYMMDD3;
              -- 西暦で表示生年月日
              ELSIF N_NAIYO_CD IN(12,22) THEN
                o_YMD    := o_SEIREKI_YYYY ||'.'||LPAD(o_MM,2)||'.'||LPAD(o_DD,2);
              END IF;
            ELSE
              -- 「平成○年○月○日」の形式で表示
              o_YMD      := o_EDIT_GYYMMDD3;
            END IF;
        END IF;
      ELSE
        o_YMD := ' ';
      END IF;
    END PROC_GET_YMD1;
    --------------------------------------------------------------------------------
    -- 制御を行う
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SEIGYO_SET(i_HONMYO IN NVARCHAR2,i_SHIMEI IN NVARCHAR2, o_SET OUT NVARCHAR2) RETURN NUMBER
    IS
    BEGIN
      -- HONMYO_KANAをセット
      IF BPRMFLG_001 OR BPRMFLG_002 THEN
        o_SET := NVL(TRIM(i_HONMYO),i_SHIMEI);
      END IF;
      -- 本名使用制御管理情報の設定で編集
      IF BPRMFLG_003 THEN
        IF N_NAIYO_CD IN(11,12) THEN
          o_SET := NVL(TRIM(i_SHIMEI),i_HONMYO);
        ELSIF N_NAIYO_CD IN(21,22) THEN
          o_SET := NVL(TRIM(i_HONMYO),i_SHIMEI);
        END IF;
      END IF;
      --SHIMEI_KANAをセット
      IF NOT BPRMFLG_001 AND NOT BPRMFLG_002 AND NOT BPRMFLG_003 THEN
        o_SET := NVL(TRIM(i_SHIMEI),i_HONMYO);
      END IF;
      RETURN 0;
    END FUNC_SEIGYO_SET;
    --------------------------------------------------------------------------------
    -- レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC RETURN NUMBER IS
      -- カーソル定義
      RECGAKUREIBO GAKUREIBO%ROWTYPE;
      r_WKRECORD001 GKBWL060R001%ROWTYPE;
      -- WK表のソート順用
      nROWNO NUMBER;
      -- ループ用
      IDX        PLS_INTEGER;
      -- 戻り値
      IFRET      PLS_INTEGER;
      o_ACONSPRM A_CONS_PRM;
      o_LENGTH   NUMBER;
      vDUMMY     NVARCHAR2(100);
      -- 児童住所
      JIDO_JUSHO NVARCHAR2(140);
      -- 保護者住所
      HOGO_JUSHO NVARCHAR2(140);
      -- 続柄取得用
      ZOKUGARA_IN NVARCHAR2(20);
      -- 続柄フラグ
      ZOKUGARA_FLAG BOOLEAN;
      -- 続柄
      ZOKUGARA NVARCHAR2(20);
      -- 児童生年月日
      JIDO_BTH_IN PLS_INTEGER;
      --児童年齢
      INENREI PLS_INTEGER;
      -- 出力用児童生年月日
      JIDO_BTH_OUT NVARCHAR2(11);
      -- 出力用発送日
      HASSOBI_OUT NVARCHAR2(11);
      --出力用児童年齢
      NENREI_OUT NVARCHAR2(3);
      -- 出力用郵便番号
      YUBIN_NO_OUT NVARCHAR2(10);
      -- 日付
      DATE_IN PLS_INTEGER;
      -- 日付１
      DATE1_OUT NVARCHAR2(11);
      -- 日付２
      DATE2_OUT NVARCHAR2(11);
      -- 日付３
      DATE3_OUT NVARCHAR2(11);
      -- 日付４
      DATE4_OUT NVARCHAR2(11);
      -- 日付５
      DATE5_OUT NVARCHAR2(11);
      -- 日付名１
      VDATE_MEI1    NVARCHAR2(40);
      -- 日付名2
      VDATE_MEI2    NVARCHAR2(40);
      -- 日付名3
      VDATE_MEI3    NVARCHAR2(40);
      -- 日付名4
      VDATE_MEI4    NVARCHAR2(40);
      -- 日付名5
      VDATE_MEI5    NVARCHAR2(40);
      -- 項目１
      VKOMOKU_MEI1  NVARCHAR2(150);
      -- 項目2
      VKOMOKU_MEI2  NVARCHAR2(150);
      -- 項目3
      VKOMOKU_MEI3  NVARCHAR2(150);
      -- 項目4
      VKOMOKU_MEI4  NVARCHAR2(150);
      -- 項目5
      VKOMOKU_MEI5  NVARCHAR2(150);
      -- 項目6
      VKOMOKU_MEI6  NVARCHAR2(150);
      -- 項目7
      VKOMOKU_MEI7  NVARCHAR2(150);
      -- 項目8
      VKOMOKU_MEI8  NVARCHAR2(150);
      -- 項目9
      VKOMOKU_MEI9  NVARCHAR2(150);
      -- 項目１0
      VKOMOKU_MEI10 NVARCHAR2(150);
      -- 旧自治体名称取得
      WK_MEISYO     NVARCHAR2(40);
      -- 宛名情報取得用
      RATENA_HOGOSHA GABTATENAKIHON%ROWTYPE;
      RSOFU_HOGOSHA  GABTSOFUSAKI%ROWTYPE;
      -- 児童宛名情報取得用
      RATENA_JIDO           GABTATENAKIHON%ROWTYPE;
      RSOFU_JIDO            GABTSOFUSAKI%ROWTYPE;
      -- 保護者方書
      GAKOKUMEI             NVARCHAR2(60);
      -- 郵便番号
      JIDO_YUBIN_NO         NVARCHAR2(20);
      -- 児童送付先児童郵便番号ＢＣ
      JIDO_YUBIN_NOBC       NVARCHAR2(80);
      -- 児童町名と児童番地
      JIDO_CHOMEI_BANCHI    NVARCHAR2(80);
      -- 方書
      JIDO_KATAGAKI         NVARCHAR2(60);
      -- 宛先郵便番号
      ATESAKI_YUBIN_NO      NVARCHAR2(200);
      -- 宛先郵便番号BC
      ATESAKI_YUBIN_NOBC    NVARCHAR2(80);
      -- 宛先町名番地
      ATESAKI_CHOMEI_BANCHI NVARCHAR2(80);
      -- 宛先方書
      ATESAKI_KATAGAKI      NVARCHAR2(60);
      -- 教育委員会名
      USER_MEI              NVARCHAR2(60); 
      -- 役職名
      VTANTO_YAKUSHOKU_MEI  NVARCHAR2(60); 
      -- 首長名
      VTANTO_SHUTHOU_MEI    NVARCHAR2(60); 
      -- ○○立
      VTANTO_RITSU_MEI      NVARCHAR2(60); 
      -- 郵便番号
      VTANTO_YUBIN_NO       NVARCHAR2(10);
      -- 住所 
      VTANTO_JUSHO          NVARCHAR2(100);
      -- 電話番号
--  2025/08/18 CTC.GYY UPDATE 1.0.102.000:GKB_QA19542対応 START
      VTANTO_TEL            NVARCHAR2(60);
      --VTANTO_TEL            NVARCHAR2(20);
--  2025/08/18 CTC.GYY UPDATE 1.0.102.000:GKB_QA19542対応 END
      -- 内線
      VTANTO_TEL_NAISEN     NVARCHAR2(10); 
      -- 表示帳票連番
      HYOJI_CHOHYO_NO       NVARCHAR2(90);
      -- 行政区名
      GYOSEIKUMEI           NVARCHAR2(20);
      -- 送付先郵便番号
      SOFU_YUBIN_NO         NVARCHAR2(10);
      -- 送付先町名と送付先番地
      SOFU_CHOMEI_BANCHI    NVARCHAR2(80);
      -- 送付先方書
      SOFU_KATAGAKI         NVARCHAR2(60);
      -- 宛先上段
      ATESAKI_JODAN         NVARCHAR2(110);
      -- 宛先下段
      ATESAKI_GEDAN         NVARCHAR2(110);
      -- 送付先児童郵便番号ＢＣ
      SOFU_YUBIN_NOBC       NVARCHAR2(80);
      -- 学校区コード
      GAKOKU_CD             NVARCHAR2(3);
      NCHOHYO_NO2           NVARCHAR2(6);   -- ZZZZ9表示連番
      IGAKKO_CD2            NVARCHAR2(5);   -- ZZZZ9学校コード
      NSHIMEI_KANJI         NVARCHAR2(100); -- 氏名漢字
      NDUMMY                NUMBER;
--  2024/07/05 ZCZL.GUANJINGHENG ADD START 0.3.000.000:新WizLIFE２次開発(標準化)
      o_nDAIRIKBN             NVARCHAR2(1000);              --認証者の本人・代理区分
      o_sKATAGAKI1            NVARCHAR2(1000);              --認証者の肩書上段
      o_sKATAGAKI2            NVARCHAR2(1000);              --認証者の肩書下段
      o_sSHIMEI               NVARCHAR2(1000);              --認証者の氏名
      o_sKOINFILENAME         NVARCHAR2(1000);              --公印ファイル名
      rBUNNUMSRCINF           KKAPK0040.MR_BUNNUMSRCINF;    --文書番号情報（構造体）
      rBUNNUMEDITKEKA         KKAPK0040.MR_BUNNUMEDITKEKA;  --文書番号編集結果
      sNUM                    NVARCHAR2(1000);              --文書番号
      sDATEED                 NVARCHAR2(1000);              --発付年月日
      rGKBTTSUCHISHOKANRI     GKBTTSUCHISHOKANRI%ROWTYPE;   --通知書管理
      rGKBTGAKUREIBO          GKBTGAKUREIBO%ROWTYPE;        --学齢簿
      o_aSHIMEIJKN_CHOHYOPRM  A_CONS_PRM;
      o_aEQSHIMEIPRM          A_CONS_PRM;
      nGKBPA00050_INDEX       NUMBER;                       --健康診断結果通知書_インデックス番号
      nGKBPA00050_CTL         NUMBER;                       --健康診断結果通知書_出力制御
      o_sJIDO_SHIMEI_KANA     NVARCHAR2(1000);              --児童生徒氏名カナ
      o_sJIDO_SHIMEI_KANJI    NVARCHAR2(1000);              --児童生徒氏名漢字
      o_sJIDO_SEINENGAPI      NVARCHAR2(1000);              --児童生徒表示生年月日
      o_sHOGOSHA_SHIMEI_KANA  NVARCHAR2(1000);              --保護者氏名カナ
      o_sHOGOSHA_SHIMEI_KANJI NVARCHAR2(1000);              --保護者氏名漢字
      o_sHOGOSHA_SEINENGAPI   NVARCHAR2(1000);              --保護者表示生年月日
      sYUBIN_NO               NVARCHAR2(1000);              --編集後郵便番号
      sCHOMEI_BANCHI          NVARCHAR2(1000);              --編集後町名番地
      sKATAGAKI               NVARCHAR2(1000);              --編集後方書
      nHANTEIKEKKA            PLS_INTEGER;
      sJYUSHO                 NVARCHAR2(1000);
-- 2025/07/01 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17602
      g_nRTN                  NUMBER;
-- 2025/07/01 CTC.HJF UPDATE End
--  2024/07/05 ZCZL.GUANJINGHENG ADD END
    BEGIN
      -- 正常終了
      IFRET := c_ISUCCESS;
      NSHIMEI_KANJI := NULL;                  --氏名漢字
      --初期化
      DELETE FROM GKBWL060R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
      nROWNO := 0;
      BEGIN
        -- 収発名を取得する
        BEGIN
          SELECT DATE_MEI1,
                 DATE_MEI2,
                 DATE_MEI3,
                 DATE_MEI4,
                 DATE_MEI5,
                 KOMOKU_MEI1,
                 KOMOKU_MEI2,
                 KOMOKU_MEI3,
                 KOMOKU_MEI4,
                 KOMOKU_MEI5,
                 KOMOKU_MEI6,
                 KOMOKU_MEI7,
                 KOMOKU_MEI8,
                 KOMOKU_MEI9,
                 KOMOKU_MEI10
            INTO VDATE_MEI1,
                 VDATE_MEI2,
                 VDATE_MEI3,
                 VDATE_MEI4,
                 VDATE_MEI5,
                 VKOMOKU_MEI1,
                 VKOMOKU_MEI2,
                 VKOMOKU_MEI3,
                 VKOMOKU_MEI4,
                 VKOMOKU_MEI5,
                 VKOMOKU_MEI6,
                 VKOMOKU_MEI7,
                 VKOMOKU_MEI8,
                 VKOMOKU_MEI9,
                 VKOMOKU_MEI10
            FROM GKBTTSUCHISHOKANRI
           WHERE CHOHYO_KBN = c_CHOHYO_KBN;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            VDATE_MEI1    := '';
            VDATE_MEI2    := '';
            VDATE_MEI3    := '';
            VDATE_MEI4    := '';
            VDATE_MEI5    := '';
            VKOMOKU_MEI1  := '';
            VKOMOKU_MEI2  := '';
            VKOMOKU_MEI3  := '';
            VKOMOKU_MEI4  := '';
            VKOMOKU_MEI5  := '';
            VKOMOKU_MEI6  := '';
            VKOMOKU_MEI7  := '';
            VKOMOKU_MEI8  := '';
            VKOMOKU_MEI9  := '';
            VKOMOKU_MEI10 := '';
        END;
--  2024/07/05 ZCZL.GUANJINGHENG ADD  START 0.3.000.000:新WizLIFE２次開発(標準化)
--  2024/11/15 ZCZL.WANGYUNING DEL START 0.3.000.004:IT_GKB_00539横展開対応
        ---- 学齢簿から情報を取得する
        --BEGIN
        --    SELECT HOGOSYA_KOJIN_NO
        --        ,SYOGAKO_CD
        --        ,KUIKIGAI_CD
        --        ,YOGOGAKO_CD
        --        ,KUNISHIRITSU_CD
        --    INTO rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO         --保護者宛名番号
        --        ,rGKBTGAKUREIBO.SYOGAKO_CD               --小学校コード
        --        ,rGKBTGAKUREIBO.KUIKIGAI_CD              --区域外学校コード
        --        ,rGKBTGAKUREIBO.YOGOGAKO_CD              --盲聾養護学校コード
        --        ,rGKBTGAKUREIBO.KUNISHIRITSU_CD          --国私立学校コード
        --    FROM GKBTGAKUREIBO
        --    WHERE KOJIN_NO = g_sNKOJIN_NO AND RIREKI_RENBAN = g_sNRIREKI_RENBAN;
        --EXCEPTION
        --    WHEN OTHERS THEN
        --        g_sMESSAGE := g_sMESSAGE || '健康診断結果通知ワーク情報が抽出異常が発生しました。,';
        --        RETURN 2;
        --END;
--  2024/11/15 ZCZL.WANGYUNING DEL END        
--  2024/07/05 ZCZL.GUANJINGHENG ADD  END
        -- カーソルのオープン
        OPEN GAKUREIBO(g_sNKOJIN_NO, g_sNRIREKI_RENBAN);
        -- レコード参照
        FETCH GAKUREIBO
          INTO RECGAKUREIBO;
        -- ループ開始
        LOOP
          -- 読むレコードが無い場合ループから抜け出す
          EXIT WHEN GAKUREIBO%NOTFOUND;
          IF g_sNHASSO_BI > 0 THEN
            -- 保護者宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(RECGAKUREIBO.HOGOSYA_KOJIN_NO,
                                       'GKB',
                                       g_sNHASSO_BI,
                                       RATENA_HOGOSHA,
                                       RSOFU_HOGOSHA);
            -- 児童宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(g_sNKOJIN_NO,
                                       'GKB',
                                       g_sNHASSO_BI,
                                       RATENA_JIDO,
                                       RSOFU_JIDO);
          ELSE
            -- 保護者宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(RECGAKUREIBO.HOGOSYA_KOJIN_NO,
                                       'GKB',
                                       ISAKUSEIBI,
                                       RATENA_HOGOSHA,
                                       RSOFU_HOGOSHA);
            -- 児童宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(g_sNKOJIN_NO,
                                       'GKB',
                                       ISAKUSEIBI,
                                       RATENA_JIDO,
                                       RSOFU_JIDO);
          END IF;
          I_RTN := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,o_SHIMEIPRM,o_LENGTH);
          IF I_RTN  = 1 THEN
            o_SHIMEIPRM := A_CONS_PRM();
            o_SHIMEIPRM.EXTEND;
            o_SHIMEIPRM.EXTEND;
            o_SHIMEIPRM(1) := 0;
            o_SHIMEIPRM.EXTEND;
            o_SHIMEIPRM(2) := 0;
            o_SHIMEIPRM.EXTEND;
            o_SHIMEIPRM(3) := 0;
            o_SHIMEIPRM.EXTEND;
            o_SHIMEIPRM(4) := 0;
            o_SHIMEIPRM.EXTEND;
            o_SHIMEIPRM(5) := 0;
          ELSE
            WHILE (o_LENGTH < 6) LOOP   
              o_SHIMEIPRM.EXTEND;
              o_SHIMEIPRM(o_LENGTH+1) := 0;
              o_LENGTH := o_LENGTH + 1;
            END LOOP;
          END IF;
          I_RTN  := FUNC_PRMFLGSET(g_sNKOJIN_NO,o_SHIMEIPRM(5),N_NAIYO_CD);
          -- 処理条件3
          IF RSOFU_JIDO.KOJIN_NO > 0 AND RSOFU_JIDO.TEKIYO_BI <= HASSO_BI AND
             (RSOFU_JIDO.SHURYO_BI >= HASSO_BI  OR RSOFU_JIDO.SHURYO_BI = 0) THEN
              -- 郵便番号
              -- 間に'-'を付加し、全角に変換
              IF LENGTH(RSOFU_JIDO.YUBIN_NO) > 0 THEN
                  JIDO_YUBIN_NO := SUBSTR(RSOFU_JIDO.YUBIN_NO, 1, 3) || '-' ||
                             SUBSTR(RSOFU_JIDO.YUBIN_NO, 4);
                  JIDO_YUBIN_NO := TRANSLATE(JIDO_YUBIN_NO, '1234567890-', '１２３４５６７８９０−');
              ELSE
                  JIDO_YUBIN_NO := NULL;
              END IF;
            -- 郵便番号BC
            JIDO_YUBIN_NOBC := RSOFU_JIDO.YUBIN_NOBC;
            -- 郵便町名番地
            JIDO_CHOMEI_BANCHI := RSOFU_JIDO.CHOMEI || RSOFU_JIDO.BANCHI;
            -- 方書
            JIDO_KATAGAKI := RSOFU_JIDO.KATAGAKI;
          -- 処理条件4
          ELSE
              -- 郵便番号
              -- 間に'-'を付加し、全角に変換
              IF LENGTH(RATENA_JIDO.YUBIN_NO) > 0 THEN
                  JIDO_YUBIN_NO := SUBSTR(RATENA_JIDO.YUBIN_NO, 1, 3) || '-' ||
                             SUBSTR(RATENA_JIDO.YUBIN_NO, 4);
                  JIDO_YUBIN_NO := TRANSLATE(JIDO_YUBIN_NO, '1234567890-', '１２３４５６７８９０−');
              ELSE
                  JIDO_YUBIN_NO := NULL;
              END IF;
            -- 郵便番号BC
            JIDO_YUBIN_NOBC := RATENA_JIDO.YUBIN_NOBC;
            -- 郵便町名番地
            JIDO_CHOMEI_BANCHI := RATENA_JIDO.CHOMEI || RATENA_JIDO.BANCHI;
            -- 方書
            JIDO_KATAGAKI := RATENA_JIDO.KATAGAKI;
          END IF;
          -- 続柄フラグの初期化
          ZOKUGARA_FLAG := TRUE;
          -- 続柄の初期化
          ZOKUGARA := '';
          -- ４回ループする
          FOR IDX IN 1 .. 4 LOOP
            -- ループ変数による分岐
            CASE IDX
              -- 続柄１
              WHEN 1 THEN
                ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI1;
              -- 続柄２
              WHEN 2 THEN
                ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI2;
              -- 続柄３
              WHEN 3 THEN
                ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI3;
                -- 続柄４
              WHEN 4 THEN
                ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI4;
            END CASE;
            -- 取得した続柄が存在する場合
            IF ZOKUGARA_IN <> ' ' THEN
              -- 続柄が設定されていない場合
              IF ZOKUGARA_FLAG = TRUE THEN
                -- 続柄フラグを設定
                ZOKUGARA_FLAG := FALSE;
                -- 続柄を設定
                ZOKUGARA := ZOKUGARA_IN;
                -- 続柄が設定されている場合
              ELSE
                -- 続柄を付与する
                ZOKUGARA := ZOKUGARA || 'の' || ZOKUGARA_IN;
              END IF;
            END IF;
          END LOOP;
          -- 保護者の住所は宛名住所を使用
          JIDO_JUSHO := RATENA_JIDO.CHOMEI || RATENA_JIDO.BANCHI ||
                        RATENA_JIDO.KATAGAKI;
          -- 検診票用の住所は宛名住所を使用
          HOGO_JUSHO := RATENA_HOGOSHA.CHOMEI || RATENA_HOGOSHA.BANCHI ||
                        RATENA_HOGOSHA.KATAGAKI;
          -- 児童生年月日の取得
          JIDO_BTH_IN := RECGAKUREIBO.SEINENGAPI;
          -- 出力用児童生年月日の取得
          PROC_GET_YMD(JIDO_BTH_IN, JIDO_BTH_OUT);
          IF (RATENA_JIDO.JINKAKU_KBN != 0) THEN
            PROC_GET_YMD1(RATENA_JIDO.JINKAKU_KBN,JIDO_BTH_IN, JIDO_BTH_OUT);
          END IF;
          -- 児童年齢の取得
          VKIJUNBI := (KKAPK0020.FDAYNENDO(g_sNHASSO_BI,0) + 1) * 10000 + 101;
          IF RECGAKUREIBO.SEINENGAPI = 0 THEN
            INENREI := NULL;
          ELSE
            INENREI    := KKAPK0020.FAgeGet(TO_CHAR(RECGAKUREIBO.SEINENGAPI), TO_CHAR(VKIJUNBI));
          END IF;
          NENREI_OUT := TO_CHAR(INENREI);
          -- 発送日の取得「平成○年○月○日」の形式に変換
          PROC_GET_YMD(g_sNHASSO_BI, HASSOBI_OUT);
          NNENDO := KKAPK0020.FDAYNENDO(g_sNHASSO_BI, 0);
          IF NVL(NNENDO, 0) = 0 THEN
            VHYOUJINENDO := '';
          ELSE
            PROC_GET_YMD(NNENDO * 10000 + 401, VHYOUJINENDO);
            VHYOUJINENDO := SUBSTR(VHYOUJINENDO, 1, 4);
          END IF;
          -- 日付の取得
          DATE_IN := RECGAKUREIBO.IDATE1;
          PROC_GET_YMD(DATE_IN, DATE1_OUT);
          DATE_IN := RECGAKUREIBO.IDATE2;
          PROC_GET_YMD(DATE_IN, DATE2_OUT);
          DATE_IN := RECGAKUREIBO.IDATE3;
          PROC_GET_YMD(DATE_IN, DATE3_OUT);
          DATE_IN := RECGAKUREIBO.IDATE4;
          PROC_GET_YMD(DATE_IN, DATE4_OUT);
          DATE_IN := RECGAKUREIBO.IDATE5;
          PROC_GET_YMD(DATE_IN, DATE5_OUT);
          -- 宛名情報取得
          I_RTN     := GAAPK0030.FGETATENA(RECGAKUREIBO.KOJIN_NO,
                                         'GKB',
                                         ISAKUSEIBI,
                                         RA,
                                         RASO);
          WK_MEISYO := NULL;
          -- 旧自治体名称取得
          GYOSEIKUMEI := GAAPK0030.FGYOSEIKUMEI(RA.SANTEIDANTAI_CD,RA.GYOSEIKU_CD);
          -- 処理条件5
          IF RECGAKUREIBO.SYOGAKO_CD <> 0 AND
             RECGAKUREIBO.SYOGAKO_TENGAKU_BI = 0 AND
             RECGAKUREIBO.SYOGAKO_SOTSUGYO_BI = 0 THEN
            -- 小学校コード
            GAKOKU_CD := RECGAKUREIBO.SYOGAKO_CD;
            -- 小学校名
            BEGIN
              SELECT SYOGAKOMEI
                INTO GAKOKUMEI
                FROM GKBTSHOGAKKO
               WHERE SYOGAKO_CD = RECGAKUREIBO.SYOGAKO_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                GAKOKUMEI := '';
          END;
          -- 処理条件6
          ELSIF RECGAKUREIBO.KUIKIGAI_CD <> 0         AND
              RECGAKUREIBO.KUIKIGAI_TENGAKU_BI = 0  AND
              RECGAKUREIBO.KUIKIGAI_TAIGAKU_BI = 0  AND
              RECGAKUREIBO.KUIKIGAI_SOTSUGYO_BI = 0 THEN
            -- 区域外コード
            GAKOKU_CD := RECGAKUREIBO.KUIKIGAI_CD;
            -- 区域外学校名
            BEGIN
              SELECT KUIKIGAIMEI
                INTO GAKOKUMEI
                FROM GKBTKUIKIGAI
               WHERE KUIKIGAI_CD = RECGAKUREIBO.KUIKIGAI_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                GAKOKUMEI := '';
            END;
          -- 処理条件7
          ELSIF NOT (RECGAKUREIBO.SYOGAKO_CD <> 0 AND
                 RECGAKUREIBO.SYOGAKO_TENGAKU_BI = 0 AND
                 RECGAKUREIBO.SYOGAKO_SOTSUGYO_BI = 0) AND
                NOT (RECGAKUREIBO.KUIKIGAI_CD <> 0 AND
                 RECGAKUREIBO.KUIKIGAI_TENGAKU_BI = 0 AND
                 RECGAKUREIBO.KUIKIGAI_TAIGAKU_BI = 0 AND
                 RECGAKUREIBO.KUIKIGAI_SOTSUGYO_BI = 0) AND
                (RECGAKUREIBO.YOGOGAKO_CD <> 0 AND
                RECGAKUREIBO.YOGOGAKO_TENGAKU_BI = 0 AND
                RECGAKUREIBO.YOGOGAKO_TAIGAKU_BI = 0 AND
                RECGAKUREIBO.YOGOGAKO_SOTSUGYO_BI = 0) THEN
            -- 盲聾養護学校コード
            GAKOKU_CD := RECGAKUREIBO.YOGOGAKO_CD;
            -- 盲聾養護学校名
            BEGIN
              SELECT YOGOGAKOMEI
                INTO GAKOKUMEI
                FROM GKBTYOGOGAKKO
               WHERE YOGOGAKO_CD = RECGAKUREIBO.YOGOGAKO_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                GAKOKUMEI := '';
            END;
          -- 上記以外場合
          ELSE
            GAKOKU_CD := '';
            GAKOKUMEI := '';
          END IF;
          -- 処理条件1
          IF RSOFU_HOGOSHA.KOJIN_NO > 0 AND
             RSOFU_HOGOSHA.TEKIYO_BI <= HASSO_BI AND
             (RSOFU_HOGOSHA.SHURYO_BI >= HASSO_BI OR
             RSOFU_HOGOSHA.SHURYO_BI = 0) THEN
            -- 送付先郵便番号
            IF LENGTH(RSOFU_HOGOSHA.YUBIN_NO) > 0 THEN
                SOFU_YUBIN_NO := SUBSTR(RSOFU_HOGOSHA.YUBIN_NO, 1, 3) || '-' ||
                             SUBSTR(RSOFU_HOGOSHA.YUBIN_NO, 4);
                SOFU_YUBIN_NO := TRANSLATE(JIDO_YUBIN_NO, '1234567890-', '１２３４５６７８９０−');
            ELSE
                SOFU_YUBIN_NO := NULL;
            END IF;
            -- 送付先町名送付先番地
            SOFU_CHOMEI_BANCHI := RSOFU_HOGOSHA.CHOMEI || RSOFU_HOGOSHA.BANCHI;
            -- 送付先方書
            SOFU_KATAGAKI      := RSOFU_HOGOSHA.KATAGAKI;
            -- 送付先児童郵便番号ＢＣ
            SOFU_YUBIN_NOBC    := RSOFU_HOGOSHA.YUBIN_NOBC;
          -- 上記以外場合
          ELSE
            -- 送付先郵便番号
            IF LENGTH(RATENA_HOGOSHA.YUBIN_NO) > 0 THEN
                SOFU_YUBIN_NO := SUBSTR(RATENA_HOGOSHA.YUBIN_NO, 1, 3) || '-' ||
                             SUBSTR(RATENA_HOGOSHA.YUBIN_NO, 4);
                SOFU_YUBIN_NO := TRANSLATE(SOFU_YUBIN_NO, '1234567890-', '１２３４５６７８９０−');
            ELSE
                SOFU_YUBIN_NO := NULL;
            END IF;
            -- 送付先町名送付先番地
            SOFU_CHOMEI_BANCHI := RATENA_HOGOSHA.CHOMEI || RATENA_HOGOSHA.BANCHI;
            -- 送付先方書
            SOFU_KATAGAKI      := RATENA_HOGOSHA.KATAGAKI;
            -- 送付先児童郵便番号ＢＣ
            SOFU_YUBIN_NOBC    := RATENA_HOGOSHA.YUBIN_NOBC;
          END IF;
          -- 宛先の氏名出力制御を取得する
          I_RTN := KKAPK0030.FPRMSHUTOKU('GKB','00ATENA',3,o_ACONSPRM,o_LENGTH);
          IF I_RTN = 1 THEN
             o_ACONSPRM := A_CONS_PRM();
             o_ACONSPRM.EXTEND;
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(1) := 0;
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(2) := 0;
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(3) := 0;
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(4) := 0;
          ELSE
             WHILE (o_LENGTH < 4) LOOP   
                o_ACONSPRM.EXTEND;
                o_ACONSPRM(o_LENGTH+1) := 0;
                o_LENGTH := o_LENGTH + 1;
             END LOOP;
          END IF;
          -- 処理条件８（宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=1,3の場合）
--  2025/05/08 CTC.LIUJUNHAO ADD START 1.0.003.000:GKB_QA13561_宛先の名前が印字されない対応          
          /*IF o_ACONSPRM(1) IN (1,3)  THEN 
             IF (RSOFU_JIDO.KOJIN_NO > 0) AND 
                (RSOFU_JIDO.TEKIYO_BI <= ISAKUSEIBI) AND 
                (RSOFU_JIDO.SHURYO_BI >= ISAKUSEIBI OR RSOFU_JIDO.SHURYO_BI = 0) THEN
                  IF RSOFU_JIDO.SHIMEI_KANJI IS NOT NULL THEN
                      NSHIMEI_KANJI := RSOFU_JIDO.SHIMEI_KANJI;
                  ELSE
                      NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                     IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                       I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                     END IF;
                  END IF;
             ELSE
                  NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                  IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                    I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                  END IF;
             END IF;
             -- 宛先郵便番号
             ATESAKI_YUBIN_NO      := JIDO_YUBIN_NO;
             -- 宛先郵便番号BC
             ATESAKI_YUBIN_NOBC    := JIDO_YUBIN_NOBC;
             -- 宛先町名番地
             ATESAKI_CHOMEI_BANCHI := JIDO_CHOMEI_BANCHI;
             -- 宛先方書
             ATESAKI_KATAGAKI      := JIDO_KATAGAKI;
             IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
               -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(3)=1の場合
               IF o_ACONSPRM(3) = 1 THEN
                 -- 宛先上段
                 ATESAKI_JODAN := '(' || NSHIMEI_KANJI || '　様)';
               -- 上記以外
               ELSE
                 -- 宛先上段
                 ATESAKI_JODAN := NSHIMEI_KANJI || '　様';
               END IF;
             ELSE
               ATESAKI_JODAN := '';
             END IF;*/         
          -- 処理条件９(宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=1,3 以外の場合)
          --ELSE
--  2025/05/08 CTC.LIUJUNHAO ADD END 1.0.003.000:GKB_QA13561_宛先の名前が印字されない対応  
            IF (RSOFU_HOGOSHA.KOJIN_NO > 0)  
                   AND (RSOFU_HOGOSHA.TEKIYO_BI <= ISAKUSEIBI) 
                   AND (RSOFU_HOGOSHA.SHURYO_BI >= ISAKUSEIBI 
                   OR RSOFU_HOGOSHA.SHURYO_BI = 0) THEN
               IF RSOFU_HOGOSHA.SHIMEI_KANJI IS NOT NULL THEN
                  NSHIMEI_KANJI := RSOFU_HOGOSHA.SHIMEI_KANJI;
               ELSE 
                  NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                  IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                    I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                  END IF;
               END IF;
            ELSE
                NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                  I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                END IF;
            END IF;
            -- 宛先郵便番号
            ATESAKI_YUBIN_NO      := SOFU_YUBIN_NO;
            -- 宛先郵便番号BC
            ATESAKI_YUBIN_NOBC    := SOFU_YUBIN_NOBC;
            -- 宛先町名番地
            ATESAKI_CHOMEI_BANCHI := SOFU_CHOMEI_BANCHI;
            -- 宛先方書
            ATESAKI_KATAGAKI      := SOFU_KATAGAKI;
--  2025/05/08 CTC.LIUJUNHAO ADD START 1.0.003.000:GKB_QA13561_宛先の名前が印字されない対応 
           -- 宛先上段
-- 2025/07/01 CTC.HJF DELETE Start 1.0.010.001:GKB_QA17602
           --ATESAKI_JODAN := NSHIMEI_KANJI || '様';
-- 2025/07/01 CTC.HJF DELETE End
           -- 宛先下段
           ATESAKI_GEDAN := NSHIMEI_KANJI || '　様'; 
/*            IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
                -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(2)=1の場合
                IF o_ACONSPRM(2) = 1 THEN
                  -- 宛先上段
                  ATESAKI_JODAN := '(' || NSHIMEI_KANJI || '　様)';
                -- 上記以外
                ELSE
                  -- 宛先上段
                  ATESAKI_JODAN := NSHIMEI_KANJI || '様';
                END IF;
            ELSE
              ATESAKI_JODAN := '';
            END IF;
          END IF;
          -- 処理条件(10)宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=2の場合
          IF o_ACONSPRM(1) = 2 THEN
            IF (RSOFU_JIDO.KOJIN_NO > 0) AND 
                   (RSOFU_JIDO.TEKIYO_BI <= ISAKUSEIBI) AND 
                   (RSOFU_JIDO.SHURYO_BI >= ISAKUSEIBI OR RSOFU_JIDO.SHURYO_BI = 0) THEN
               IF RSOFU_JIDO.SHIMEI_KANJI IS NOT NULL THEN
                  NSHIMEI_KANJI := RSOFU_JIDO.SHIMEI_KANJI;
               ELSE
                  NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                  IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                     I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                  END IF;
               END IF;
            ELSE
               NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
               IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                 I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
               END IF;
            END IF;
            IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
              -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(3)=1の場合
              IF o_ACONSPRM(3) = 1 THEN
                 -- 宛先下段
                ATESAKI_GEDAN := '(' || NSHIMEI_KANJI || '　様)';
              ELSE
                 -- 宛先下段
                ATESAKI_GEDAN := NSHIMEI_KANJI || '　様';
              END IF;
            ELSE
              ATESAKI_GEDAN := '';
            END IF;
          -- 処理条件(11)宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=3の場合
          ELSIF o_ACONSPRM(1) = 3 THEN
            IF (RSOFU_HOGOSHA.KOJIN_NO >0)
                   AND (RSOFU_HOGOSHA.TEKIYO_BI <= ISAKUSEIBI)
                   AND (RSOFU_HOGOSHA.SHURYO_BI >= ISAKUSEIBI
                   OR RSOFU_HOGOSHA.SHURYO_BI = 0) THEN
               IF RSOFU_HOGOSHA.SHIMEI_KANJI IS NOT NULL THEN
                  NSHIMEI_KANJI := RSOFU_HOGOSHA.SHIMEI_KANJI;
               ELSE 
                  NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                  IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                    I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                  END IF;
               END IF;
            ELSE
               NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
               IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                 I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
               END IF;
            END IF;
            IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
              -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(2)=1の場合
              IF o_ACONSPRM(2) = 1 THEN
                -- 宛先下段
                ATESAKI_GEDAN := '(' || NSHIMEI_KANJI || '　様)';
              ELSE
                -- 宛先下段
                ATESAKI_GEDAN := NSHIMEI_KANJI || '　様';
              END IF;
            ELSE
              ATESAKI_GEDAN := '';
            END IF;
          -- 処理条件(12) 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=2,3以外の場合
          ELSE
            -- 宛先下段
            ATESAKI_GEDAN := ' ';
          END IF; */
--  2025/05/08 CTC.LIUJUNHAO ADD END 1.0.003.000:GKB_QA13561_宛先の名前が印字されない対応            
          -- 教育委員会情報を取得する。
          o_ACONSPRM := NULL;
          o_LENGTH   := 0;
          I_RTN      := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',g_sNIINKAI,o_ACONSPRM,o_LENGTH);
          IF I_RTN = 1 THEN
             o_ACONSPRM := A_CONS_PRM();
             o_ACONSPRM.EXTEND;
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(1) := ' ';
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(2) := ' ';
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(3) := ' ';
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(4) := ' ';
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(5) := ' ';
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(6) := ' ';
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(7) := ' ';
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(8) := ' ';
          ELSE  
            WHILE (o_LENGTH < 8) LOOP
                o_ACONSPRM.EXTEND;
                o_ACONSPRM(o_LENGTH+1) := ' ';
                o_LENGTH := o_LENGTH + 1;
            END LOOP;
          END IF;
          USER_MEI             := o_ACONSPRM(1);-- 教育委員会名
          VTANTO_YAKUSHOKU_MEI := o_ACONSPRM(2);-- 役職名
          VTANTO_SHUTHOU_MEI   := o_ACONSPRM(3);-- 首長名
          VTANTO_RITSU_MEI     := o_ACONSPRM(4);-- ○○立
          VTANTO_YUBIN_NO      := o_ACONSPRM(5);-- 郵便番号
          VTANTO_JUSHO         := o_ACONSPRM(6);-- 住所
          VTANTO_TEL           := o_ACONSPRM(7);-- 電話番号
          VTANTO_TEL_NAISEN    := o_ACONSPRM(8);-- 内線

          --公印ファイル名取得
          BRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE, 0),
                                      g_sWSNUM,
                                      SYSDATE,
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発(標準化)
--                                      VDUMMY,
--                                      VDUMMY,
--                                      VDUMMY,
--                                      VDUMMY,
--                                      VGYOMU);     --業務毎公印ファイル名
                                      o_nDAIRIKBN,          --認証者の本人・代理区分
                                      o_sKATAGAKI1,         --認証者の肩書上段
                                      o_sKATAGAKI2,         --認証者の肩書下段
                                      o_sSHIMEI,            --認証者の氏名
                                      o_sKOINFILENAME);     --業務毎公印ファイル名
                                      
          -- システム制御設定を取得する。
          --外国人　氏名・生年月日制御帳票(ID)
          I_RTN := KKAPK0030.FCTGetR('GKB','SHIMEIJKN_CHOHYO','0000',1,o_aSHIMEIJKN_CHOHYOPRM);
          IF I_RTN = 0 THEN
              FOR i IN 1..o_aSHIMEIJKN_CHOHYOPRM.COUNT LOOP
                  IF o_aSHIMEIJKN_CHOHYOPRM(i) = 'GKB060R001' THEN
                      nGKBPA00050_INDEX := i;
                      EXIT;
                  END IF;
              END LOOP;
              --本名・通称名　出力制御
              I_RTN := KKAPK0030.FCTGetR('GKB','EQSHIMEI','0000',0,o_aEQSHIMEIPRM);
              IF I_RTN = 0 AND nGKBPA00050_INDEX <= o_aEQSHIMEIPRM.COUNT THEN
                  nGKBPA00050_CTL := o_aEQSHIMEIPRM(nGKBPA00050_INDEX);
              END IF;
          END IF;
-- 2025/07/01 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17602
          -- 宛先下段
          g_nRTN := GKBFKHMCTRL(g_sNKOJIN_NO, 'GKB060R001', 1, nGKBPA00050_CTL, o_sHOGOSHA_SHIMEI_KANA, o_sHOGOSHA_SHIMEI_KANJI, o_sHOGOSHA_SEINENGAPI);
          ATESAKI_GEDAN := o_sHOGOSHA_SHIMEI_KANJI || '　様';
-- 2025/07/01 CTC.HJF UPDATE End
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
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00433対応
              --sDATEED := rBUNNUMEDITKEKA.DATEED;
              sDATEED := rBUNNUMEDITKEKA.BUNDATE;
          ELSE
              sDATEED := '';
          END IF;
          -- 通知書条件管理から情報を取得する
          BEGIN
              SELECT KOIN_SHORYAKU
                  ,KOIN_CHUSHAKU
                  ,TSUCHIBUN
                  ,YOSHIKI_BANGO_SETTOGO
                  ,YOSHIKI_BANGO
                  ,YOSHIKI_BANGO_SETSUBIGO
              INTO rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU              --公印省略
                  ,rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU              --公印注釈
                  ,rGKBTTSUCHISHOKANRI.TSUCHIBUN                  --通知文
                  ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO      --様式番号接頭語
                  ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO              --様式番号
                  ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO    --様式番号接尾語
              FROM GKBTTSUCHISHOKANRI   
              WHERE CHOHYO_KBN = g_nCHOHYO_KBN;   
          EXCEPTION
              WHEN OTHERS THEN
              rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU            := NULL;
              rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU            := NULL;
              rGKBTTSUCHISHOKANRI.TSUCHIBUN                := NULL;
              rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO    := NULL;
              rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO            := NULL;
              rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO  := NULL;
          END;
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE END

          -- 市町村長名情報を取得する
--  2024/08/20 ZCZL.WANGMING DELETE 0.3.000.001:IT_GKB_00018対応
--          KKAPK0030.SNinshGet(ISAKUSEIBI, nDUMMY, VNINSHO_SHIMEI, VDUMMY, VDUMMY, VNINSHO_KATAGAKI);
          --郵便番号教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(5)の左から３桁めと４桁めの
          -- 間に'-'を付加し、全角に変換
          IF LENGTH(VTANTO_YUBIN_NO) > 0 THEN
            YUBIN_NO_OUT := SUBSTR(VTANTO_YUBIN_NO, 1, 3) || '-' ||
                            SUBSTR(VTANTO_YUBIN_NO, 4);
          ELSE
            YUBIN_NO_OUT := NULL;
          END IF;
          -- 連番印字制御
          o_ACONSPRM := NULL;
          o_LENGTH   := 0;
          I_RTN := NULL;
          I_RTN := KKAPK0030.FPRMSHUTOKU('GKB','00RENBAN', 0,o_ACONSPRM, o_LENGTH);
          IF I_RTN =1 THEN
             o_ACONSPRM := A_CONS_PRM();
             o_ACONSPRM.EXTEND;
             o_ACONSPRM.EXTEND;
             o_ACONSPRM(1) := 0;
          ELSE
             WHILE (o_LENGTH < 1) LOOP
                o_ACONSPRM.EXTEND;
                o_ACONSPRM(o_LENGTH+1) := 0;
                o_LENGTH := o_LENGTH + 1;
             END LOOP;
          END IF;
          NCHOHYO_NO2 := TRIM(TO_CHAR(RECGAKUREIBO.CHOHYO_NO));
          NCHOHYO_NO2 := LPAD(NCHOHYO_NO2,5,' ');
          IGAKKO_CD2 := TRIM(TO_CHAR(GAKOKU_CD));
          IGAKKO_CD2 := LPAD(IGAKKO_CD2,5,' ');
          IF o_ACONSPRM(1) = 0 THEN
            HYOJI_CHOHYO_NO := ' ';
          ELSIF o_ACONSPRM(1) = 1 THEN
            HYOJI_CHOHYO_NO := NCHOHYO_NO2;
          ELSIF o_ACONSPRM(1) = 2 THEN
            HYOJI_CHOHYO_NO := LTRIM(GAKOKUMEI) || '-' || NCHOHYO_NO2;
          ELSIF o_ACONSPRM(1) = 3 THEN
            HYOJI_CHOHYO_NO := IGAKKO_CD2 || '-' || NCHOHYO_NO2;
          ELSIF o_ACONSPRM(1) = 4 THEN
            HYOJI_CHOHYO_NO := LTRIM(GAKOKUMEI) || '-' || LTRIM(GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
          ELSIF o_ACONSPRM(1) = 5 THEN
            HYOJI_CHOHYO_NO := IGAKKO_CD2 || '-' || LTRIM(GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
          ELSE
            HYOJI_CHOHYO_NO := ' ';
          END IF;

          -- ＣＳＶ出力用変数の初期化
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00539横展開対応
          --nROWNO                                  := nROWNO + 1;
          r_WKRECORD001                           := NULL;
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00539横展開対応
          --r_WKRECORD001.NO                        := nROWNO;                               --ソート順

          r_WKRECORD001.NENDO                     := VHYOUJINENDO;                         --年度
          r_WKRECORD001.KAIPAGE_CD                := '';                                   --改頁コード
          r_WKRECORD001.KAIPAGE                   := '';                                   --改頁
          r_WKRECORD001.SAKUSEIBI                 := '';                                   --作成日
          r_WKRECORD001.RENBAN                    := 1;                                    --連番
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE  START 0.3.000.000:新WizLIFE２次開発(標準化)
--          -- 児童氏名かな
--          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
--            I_RTN :=  FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANA,RATENA_JIDO.SHIMEI_KANA,RECGAKUREIBO.SHIMEI_KANA);
--          END IF;
--          r_WKRECORD001.JIDO_SHIMEI_KANA          := RECGAKUREIBO.SHIMEI_KANA;             --児童氏名かな
--          -- 児童氏名漢字
--          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
--            I_RTN :=  FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,RECGAKUREIBO.SHIMEI_KANJI);
--          END IF;
--          r_WKRECORD001.JIDO_SHIMEI_KANJI         := RECGAKUREIBO.SHIMEI_KANJI;            --児童氏名漢字
--          r_WKRECORD001.HYOJI_SEINENGAPI          := '';                                   --表示生年月日
          r_WKRECORD001.BUNSHO_NO                 := sNUM;                                 --文書番号
          -- 児童生徒の本名使用制御判定
          I_RTN := GKBFKHMCTRL(g_sNKOJIN_NO, g_rOPRT.CHOHYOID, 0, nGKBPA00050_CTL, o_sJIDO_SHIMEI_KANA, o_sJIDO_SHIMEI_KANJI, o_sJIDO_SEINENGAPI);
          r_WKRECORD001.JIDO_SHIMEI_KANA          := o_sJIDO_SHIMEI_KANA;                  --児童氏名かな
          r_WKRECORD001.JIDO_SHIMEI_KANJI         := o_sJIDO_SHIMEI_KANJI;                 --児童氏名漢字
          r_WKRECORD001.HYOJI_SEINENGAPI          := o_sJIDO_SEINENGAPI;                   --表示生年月日
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE  END
          r_WKRECORD001.HYOJI_SEIBETSU            := RECGAKUREIBO.SEIBETSU;                --児童性別
          r_WKRECORD001.HOGOSHA_SHIMEI_JODAN      := '';                                   --保護者氏名上段
--  2025/05/08 CTC.LIUJUNHAO  ADD START  1.0.003.000:GKB_QA13561_宛先の名前が印字されない対応
          --r_WKRECORD001.HOGOSHA_SHIMEI_GEDAN      := ''; 
          r_WKRECORD001.HOGOSHA_SHIMEI_GEDAN      := ATESAKI_GEDAN;                        --保護者氏名下段
--  2025/05/08 CTC.LIUJUNHAO  ADD　END  1.0.003.000:GKB_QA13561_宛先の名前が印字されない対応
          r_WKRECORD001.JUSHO_JODAN               := '';                                   --住所上
          r_WKRECORD001.JUSHO_GEDAN               := '';                                   --住所下
          r_WKRECORD001.GYOSEIKU_MEI              := GYOSEIKUMEI;                          --行政区名
          r_WKRECORD001.GAKKOKU_MEI               := GAKOKUMEI;                            --学校区名
          r_WKRECORD001.SANTEIDANTAI_MEI          := '';                                   --算定団体名
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
            IF g_nSHIENSOCHIKBN = 1  THEN
          r_WKRECORD001.ATESAKI_YUBIN_NO          := '';                                    --宛先郵便番号
          r_WKRECORD001.ATESAKI_CHOMEI_BANCHI     := GKBPK00010.FGETJUSHOMSG();             --宛先町名番地
          r_WKRECORD001.ATESAKI_KATAGAKI          := '';                                    --宛先方書
          r_WKRECORD001.ATESAKI_GEDAN             := '';                                    --宛先下段
            ELSE
          r_WKRECORD001.ATESAKI_YUBIN_NO          := SOFU_YUBIN_NO;                        --宛先郵便番号
          r_WKRECORD001.ATESAKI_CHOMEI_BANCHI     := SOFU_CHOMEI_BANCHI;                   --宛先町名番地
          r_WKRECORD001.ATESAKI_KATAGAKI          := SOFU_KATAGAKI;                        --宛先方書
          --  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応 Start
          --r_WKRECORD001.ATESAKI_JODAN             := ATESAKI_JODAN;                        --宛先上段
          --  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応 End
          r_WKRECORD001.ATESAKI_GEDAN             := ATESAKI_GEDAN;                        --宛先下段
            END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
          r_WKRECORD001.KANJI_SEINENGAPI          := JIDO_BTH_OUT;                         --漢字生年月日
          r_WKRECORD001.NENREI                    := NENREI_OUT || '年';                   --年齢
          r_WKRECORD001.JIDO_JUSHO                := JIDO_JUSHO;                           --児童現住所
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE  START 0.3.000.000:新WizLIFE２次開発(標準化)
--          -- 保護者氏名かな
--          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
--            I_RTN :=  FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANA,RATENA_HOGOSHA.SHIMEI_KANA,RECGAKUREIBO.HOGOSYA_SHIMEI_KANA);
--          END IF;
--          r_WKRECORD001.HOGOSHA_SHIMEI_KANA       := RECGAKUREIBO.HOGOSYA_SHIMEI_KANA;     --保護者氏名カナ
--          -- 保護者氏名漢字
--          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
--            I_RTN :=  FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI);
--          END IF;
--          r_WKRECORD001.HOGOSHA_SHIMEI_KANJI      := RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI;    --保護者氏名漢字
--          r_WKRECORD001.CHOMEI_BANCHI_KATAGAKI    := HOGO_JUSHO;                           --町名番地方書
          -- 保護者の本名使用制御判定
          I_RTN := GKBFKHMCTRL(g_sNKOJIN_NO, g_rOPRT.CHOHYOID, 1, nGKBPA00050_CTL, o_sHOGOSHA_SHIMEI_KANA, o_sHOGOSHA_SHIMEI_KANJI, o_sHOGOSHA_SEINENGAPI);
          --  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応 Start
          r_WKRECORD001.ATESAKI_JODAN             := o_sHOGOSHA_SHIMEI_KANJI|| '　様'; 
          --  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応 End
          r_WKRECORD001.HOGOSHA_SHIMEI_KANA       := o_sHOGOSHA_SHIMEI_KANA;               --保護者氏名カナ
          r_WKRECORD001.HOGOSHA_SHIMEI_KANJI      := o_sHOGOSHA_SHIMEI_KANJI;              --保護者氏名漢字
          r_WKRECORD001.CHOMEI_BANCHI_KATAGAK     := HOGO_JUSHO;                           --町名番地方書
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE  END
          r_WKRECORD001.JIDO_ZOKUGARAMEI          := ZOKUGARA;                             --児童との関係
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE  START 0.3.000.000:新WizLIFE２次開発(標準化)
--          r_WKRECORD001.KYOIKU_KAI_MEI            := USER_MEI;                             --教育委員会名
--          r_WKRECORD001.HASSOBI                   := HASSOBI_OUT;                          --発送日
          r_WKRECORD001.KYOIKU_KAI_MEI            := o_sKATAGAKI1;                         --教育委員会名
--  2024/09/13 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--          r_WKRECORD001.HASSOBI                   := sDATEED;                              --発送日
          --  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応 Start
          --r_WKRECORD001.HASSOBI                   := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sDATEED, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);
          r_WKRECORD001.HASSOBI                   := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(TO_NUMBER(REPLACE(sDATEED,'/','')),0,3),' ','')); --発送日
          --  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応 End
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE  END
          r_WKRECORD001.SYUHATU_NO                := '';                                   --収発番号
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE  START 0.3.000.000:新WizLIFE２次開発(標準化)
--          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
--            r_WKRECORD001.KOIN_PATH               := VGYOMU;                               --公印パス
--          ELSE
--            r_WKRECORD001.KOIN_PATH               := NULL;
--          END IF;
          IF o_sKOINFILENAME IS NOT NULL THEN
            r_WKRECORD001.KOIN_PATH               := o_sKOINFILENAME;                      --公印パス
            r_WKRECORD001.KOIN_SHORYAKU           := NULL;                                 --公印（省略）
            r_WKRECORD001.KOIN_CHUSHAKU           := rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU;    --公印（注釈）
          ELSE
            r_WKRECORD001.KOIN_PATH               := NULL;                                 --公印パス
            r_WKRECORD001.KOIN_SHORYAKU           := rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU;    --公印（省略）
            r_WKRECORD001.KOIN_CHUSHAKU           := NULL;                                 --公印（注釈）
          END IF;
          r_WKRECORD001.TSUCHIBUN                 := REPLACE(rGKBTTSUCHISHOKANRI.TSUCHIBUN, chr(13)||chr(10),'#');    --通知文
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE  END
          r_WKRECORD001.KYOIKU_TEL                := VTANTO_TEL;                           --委員会電話番号
          r_WKRECORD001.KYOIKU_YUBIN_NO           := YUBIN_NO_OUT;                         --委員会郵便番号
          r_WKRECORD001.KYOIKU_JUSHO              := VTANTO_JUSHO;                         --委員会住所
          r_WKRECORD001.HASSO_NO                  := SOFU_YUBIN_NOBC;                      --発送番号
          r_WKRECORD001.DATE1                     := DATE1_OUT;                            --日付１
          r_WKRECORD001.DATE2                     := DATE2_OUT;                            --日付２
          r_WKRECORD001.DATE3                     := DATE3_OUT;                            --日付３
          r_WKRECORD001.DATE4                     := DATE4_OUT;                            --日付４
          r_WKRECORD001.DATE5                     := DATE5_OUT;                            --日付５
          r_WKRECORD001.KOMOKU1                   := RECGAKUREIBO.VKOMOKU1;                --項目１
          r_WKRECORD001.KOMOKU2                   := RECGAKUREIBO.VKOMOKU2;                --項目２
          r_WKRECORD001.KOMOKU3                   := RECGAKUREIBO.VKOMOKU3;                --項目３
          r_WKRECORD001.KOMOKU4                   := RECGAKUREIBO.VKOMOKU4;                --項目４
          r_WKRECORD001.KOMOKU5                   := RECGAKUREIBO.VKOMOKU5;                --項目５
          r_WKRECORD001.KOMOKU6                   := RECGAKUREIBO.VKOMOKU6;                --項目６
          r_WKRECORD001.KOMOKU7                   := RECGAKUREIBO.VKOMOKU7;                --項目７
          r_WKRECORD001.KOMOKU8                   := RECGAKUREIBO.VKOMOKU8;                --項目８
          r_WKRECORD001.KOMOKU9                   := RECGAKUREIBO.VKOMOKU9;                --項目９
          r_WKRECORD001.KOMOKU10                  := RECGAKUREIBO.VKOMOKU10;               --項目１０
          r_WKRECORD001.DATE_MEI1                 := VDATE_MEI1;                           --日付名称１
          r_WKRECORD001.DATE_MEI2                 := VDATE_MEI2;                           --日付名称２
          r_WKRECORD001.DATE_MEI3                 := VDATE_MEI3;                           --日付名称３
          r_WKRECORD001.DATE_MEI4                 := VDATE_MEI4;                           --日付名称４
          r_WKRECORD001.DATE_MEI5                 := VDATE_MEI5;                           --日付名称５
          r_WKRECORD001.KOMOKU_MEI1               := VKOMOKU_MEI1;                         --項目名称１
          r_WKRECORD001.KOMOKU_MEI2               := VKOMOKU_MEI2;                         --項目名称２
          r_WKRECORD001.KOMOKU_MEI3               := VKOMOKU_MEI3;                         --項目名称３
          r_WKRECORD001.KOMOKU_MEI4               := VKOMOKU_MEI4;                         --項目名称４
          r_WKRECORD001.KOMOKU_MEI5               := VKOMOKU_MEI5;                         --項目名称５
          r_WKRECORD001.KOMOKU_MEI6               := VKOMOKU_MEI6;                         --項目名称６
          r_WKRECORD001.KOMOKU_MEI7               := VKOMOKU_MEI7;                         --項目名称７
          r_WKRECORD001.KOMOKU_MEI8               := VKOMOKU_MEI8;                         --項目名称８
          r_WKRECORD001.KOMOKU_MEI9               := VKOMOKU_MEI9;                         --項目名称９
          r_WKRECORD001.KOMOKU_MEI10              := VKOMOKU_MEI10;                        --項目名称１０
          r_WKRECORD001.GAKKO_CD                  := GAKOKU_CD;                            --学校コード
--  2024/08/20 ZCZL.WANGMING UPDATE Start 0.3.000.001:IT_GKB_00018対応
--          r_WKRECORD001.NINSHOSHAKATAGAKI         := VNINSHO_KATAGAKI;                     --認証肩書
--          r_WKRECORD001.NINSHOSHAMEI              := VNINSHO_SHIMEI;                       --認証者名
          r_WKRECORD001.NINSHOSHAKATAGAKI         := o_sKATAGAKI1 || o_sKATAGAKI2;           --認証肩書
          r_WKRECORD001.NINSHOSHAMEI              := o_sSHIMEI;                              --認証者名
--  2024/08/20 ZCZL.WANGMING UPDATE End
          r_WKRECORD001.JIDO_YUBIN_NO             := JIDO_YUBIN_NO;                        --児童郵便番号
          r_WKRECORD001.JIDO_SOFU_YUBIN_NOBC      := JIDO_YUBIN_NOBC;                      --児童カスタマバーコード
          r_WKRECORD001.JIDO_CHOMEI_BANCHI        := JIDO_CHOMEI_BANCHI;                   --児童町名番地
          r_WKRECORD001.JIDO_KATAGAKI             := JIDO_KATAGAKI;                        --児童方書
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発(標準化)
--          r_WKRECORD001.YUBIN_NO                  := ATESAKI_YUBIN_NO;                     --郵便番号
--          r_WKRECORD001.BC_NO                     := ATESAKI_YUBIN_NOBC;                   --カスタマバーコード
--          r_WKRECORD001.CHOMEI_BANCHI             := ATESAKI_CHOMEI_BANCHI;                --町名番地
--          r_WKRECORD001.KATAGAKI                  := ATESAKI_KATAGAKI;                     --方書
--  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応 Start
          /*
          --郵便番号編集処理（KKAPK0010.FYUBINHENSHU）の戻り値を取得
          I_RTN := KKAPK0010.FYUBINHENSHU(RSOFU_HOGOSHA.YUBIN_NO,sYUBIN_NO);
          --全角変換処理（KKAPK0010.FMULTIBYTEHENKAN）の戻り値をセット
          r_WKRECORD001.YUBIN_NO                  := KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO,0);     --郵便番号
          r_WKRECORD001.BC_NO                     := RSOFU_HOGOSHA.YUBIN_NOBC;                    --カスタマバーコード
          -- 住所編集取得（GAAPK0010.FADDRESSEDIT）の戻り値をセット
          sCHOMEI_BANCHI := GAAPK0010.FADDRESSEDIT(1, NULL, RSOFU_HOGOSHA.CHOMEI, RSOFU_HOGOSHA.BANCHI, NULL, NULL);
          r_WKRECORD001.CHOMEI_BANCHI             := sCHOMEI_BANCHI;                       --町名番地
          -- 住所編集取得（GAAPK0010.FADDRESSEDIT）の戻り値をセット
          sKATAGAKI := GAAPK0010.FADDRESSEDIT(1, NULL, NULL, NULL, RSOFU_HOGOSHA.KATAGAKI, NULL);
          r_WKRECORD001.KATAGAKI                  := sKATAGAKI;                            --方書
          -- 支援措置対象住所非表示＝１(有)の場合
          IF g_nSHIENSOCHIKBN = 1 THEN
              -- 抑止住所編集
              sJYUSHO := GAAPK0030.FDVJUSHO('GKB',RECGAKUREIBO.KOJIN_NO,g_sTANTOCODE,g_sWSNUM,RSOFU_HOGOSHA.CHOMEI || RSOFU_HOGOSHA.BANCHI,nHANTEIKEKKA,2);
              IF nHANTEIKEKKA = 1 THEN
                  r_WKRECORD001.CHOMEI_BANCHI             := sJYUSHO;                  --町名番地
                  r_WKRECORD001.KATAGAKI                  := sJYUSHO;                  --方書
              END IF;
          END IF;
          */
          IF RSOFU_HOGOSHA.KOJIN_NO > 0 THEN
            I_RTN := KKAPK0010.FYUBINHENSHU(RSOFU_HOGOSHA.YUBIN_NO,sYUBIN_NO);
            -- 支援措置対象を取得
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
            --sJYUSHO := GAAPK0030.FDVJUSHO('GKB',RECGAKUREIBO.KOJIN_NO,g_sTANTOCODE,g_sWSNUM,RSOFU_HOGOSHA.CHOMEI || RSOFU_HOGOSHA.BANCHI,nHANTEIKEKKA,2);
            -- 支援措置対象住所非表示＝１(有)の場合
            -- IF g_nSHIENSOCHIKBN = 1 AND nHANTEIKEKKA = 1 THEN
            IF g_nSHIENSOCHIKBN = 1  THEN
              sJYUSHO := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
              r_WKRECORD001.YUBIN_NO                  := '';                       --郵便番号
              r_WKRECORD001.CHOMEI_BANCHI             := sJYUSHO;                  --町名番地
              r_WKRECORD001.KATAGAKI                  := '';                       --方書
              r_WKRECORD001.BC_NO                     := '';                       --カスタマバーコード
            ELSE
              --全角変換処理（KKAPK0010.FMULTIBYTEHENKAN）の戻り値をセット
              r_WKRECORD001.YUBIN_NO                  := KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO,0);    
              -- 住所編集取得（GAAPK0010.FADDRESSEDIT）の戻り値をセット                     --郵便番号
              sCHOMEI_BANCHI := GAAPK0010.FADDRESSEDIT(1, NULL, RSOFU_HOGOSHA.CHOMEI, RSOFU_HOGOSHA.BANCHI, NULL, NULL);
              r_WKRECORD001.CHOMEI_BANCHI             := sCHOMEI_BANCHI;                                                  --町名番地
              r_WKRECORD001.KATAGAKI                  := RSOFU_HOGOSHA.KATAGAKI;                                                       --方書
              r_WKRECORD001.BC_NO                     := RSOFU_HOGOSHA.YUBIN_NOBC;                                        --カスタマバーコード
            END IF ;
          ELSE
            I_RTN := KKAPK0010.FYUBINHENSHU(RATENA_HOGOSHA.YUBIN_NO,sYUBIN_NO);
            -- 支援措置対象を取得
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
            --sJYUSHO := GAAPK0030.FDVJUSHO('GKB',RECGAKUREIBO.KOJIN_NO,g_sTANTOCODE,g_sWSNUM,RATENA_HOGOSHA.CHOMEI || RATENA_HOGOSHA.BANCHI,nHANTEIKEKKA,2);
            -- 支援措置対象住所非表示＝１(有)の場合
            --IF g_nSHIENSOCHIKBN = 1 AND nHANTEIKEKKA = 1 THEN
            IF g_nSHIENSOCHIKBN = 1  THEN
              sJYUSHO := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
              r_WKRECORD001.YUBIN_NO                  := '';                       --郵便番号
              r_WKRECORD001.CHOMEI_BANCHI             := sJYUSHO;                  --町名番地
              r_WKRECORD001.KATAGAKI                  := '';                       --方書
              r_WKRECORD001.BC_NO                     := '';                       --カスタマバーコード
            ELSE
              --全角変換処理（KKAPK0010.FMULTIBYTEHENKAN）の戻り値をセット
              r_WKRECORD001.YUBIN_NO                  := KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO,0);    
              -- 住所編集取得（GAAPK0010.FADDRESSEDIT）の戻り値をセット                     --郵便番号
              sCHOMEI_BANCHI := GAAPK0010.FADDRESSEDIT(1, NULL, RATENA_HOGOSHA.CHOMEI, RATENA_HOGOSHA.BANCHI, NULL, NULL);
              r_WKRECORD001.CHOMEI_BANCHI             := sCHOMEI_BANCHI;                                                  --町名番地
              r_WKRECORD001.KATAGAKI                  := RATENA_HOGOSHA.KATAGAKI;                                                       --方書
              r_WKRECORD001.BC_NO                     := RATENA_HOGOSHA.YUBIN_NOBC;                                        --カスタマバーコード
            END IF ;
          END IF ;
          --  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応 End
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE END
          r_WKRECORD001.KYOIKU_YAKUSHOKU_MEI      := VTANTO_YAKUSHOKU_MEI;                 --委員会役職名
          --  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応 Start
          --r_WKRECORD001.KYOIKU_SHUCHO_MEI         := VTANTO_SHUTHOU_MEI;                   --委員会首長名
          r_WKRECORD001.KYOIKU_SHUCHO_MEI         := o_sSHIMEI;                            --委員会首長名
          --  2024/12/19 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_10053、IT_GKB_10054、IT_GKB_10055、IT_GKB_10056、IT_GKB_10057対応 End
          r_WKRECORD001.KYOIKU_RITSU_MEI          := VTANTO_RITSU_MEI;                     --委員会立区名
          r_WKRECORD001.KYOIKU_TEL_NAISEN         := VTANTO_TEL_NAISEN;                    --委員会内線
          r_WKRECORD001.HYOJI_CHOHYO_NO           := HYOJI_CHOHYO_NO;                      --表示帳票連番
          KYOIKUKAI_RENRAKUSAKI                   := GET_EQRENRAKUSAKI(2, USER_MEI, VTANTO_TEL, VTANTO_TEL_NAISEN);
          r_WKRECORD001.KYOIKU_RENRAKUSAKI        := KYOIKUKAI_RENRAKUSAKI;                --教育委員会連絡先
--  2024/07/05 ZCZL.GUANJINGHENG ADD 0.3.000.000:新WizLIFE２次開発(標準化)
          r_WKRECORD001.YOSHIKI_NO                := rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO;    --様式番号
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
          r_WKRECORD001.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(r_WKRECORD001.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
          r_WKRECORD001.BREAK_NO                  := NULL;                                 --改ページキー
          r_WKRECORD001.WSNUM                     := g_sWSNUM;                             --端末番号
          r_WKRECORD001.BATCHKBN                  := c_ONLINE;                             --バッチ区分
          r_WKRECORD001.JOBNUM                    := g_nJOBNUM;                            --ジョブNO
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE START 0.3.000.000:新WizLIFE２次開発(標準化)
--          INSERT INTO GKBWL060R001 VALUES r_WKRECORD001;
          FOR i IN 1..g_nHAKKOSU LOOP
--  2024/11/15 ZCZL.WANGYUNING UPDATE START 0.3.000.004:IT_GKB_00539横展開対応
              nROWNO                                  := nROWNO + 1;
              r_WKRECORD001.NO                        := nROWNO;                               --ソート順
--  2024/11/15 ZCZL.WANGYUNING UPDATE END
              INSERT INTO GKBWL060R001 VALUES r_WKRECORD001;
          END LOOP;
--  2024/07/05 ZCZL.GUANJINGHENG UPDATE END
          -- 一意的なレコードなので複数回繰り返すことはないので脱出
          EXIT;
          -- ループの終端
        END LOOP;
        -- カーソルを閉じる
        CLOSE GAKUREIBO;
    -- 例外エラー
    EXCEPTION
        -- 該当なし
        WHEN NO_DATA_FOUND THEN
          -- 該当なしは正常終了とする
          IFRET := c_ISUCCESS;
          -- カーソルが開いていたらクローズ
          IF GAKUREIBO%ISOPEN THEN
            CLOSE GAKUREIBO;
          END IF;
        -- その他
        WHEN OTHERS THEN
          -- その他エラー
          IFRET := c_INOT_SUCCESS;
          -- カーソルが開いていたらクローズ
          IF GAKUREIBO%ISOPEN THEN
            CLOSE GAKUREIBO;
          END IF;
        -- 例外エラー終端
        END;
        -- 終了
        RETURN IFRET;
    END FUNC_GET_JIDO_REC;

    --------------------------------------------------------
    --  機能概要      : メインビジネスロジック処理
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        ERR                   EXCEPTION;
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');

        -- 基準日セット
        ISAKUSEIBI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        IF TO_NUMBER(g_sNHASSO_BI) = 0 THEN
          HASSO_BI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        ELSE
          HASSO_BI := g_sNHASSO_BI;
        END IF;
        -- ＣＳＶ作成
        I_RTN := FUNC_GET_JIDO_REC;
        IF I_RTN <> 0 THEN
          RAISE ERR;
        END IF;
        -- 帳票出力CSVの作成
        bRTN := FUNC_O20CSV(i_sGYOUMUCODE,'GKBWL060R001',i_sCHOHYOID);

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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
END GKBPA00050;
/