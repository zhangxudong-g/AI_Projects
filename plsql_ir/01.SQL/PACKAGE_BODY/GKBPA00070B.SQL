CREATE OR REPLACE PACKAGE BODY GKBPA00070
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 中学校入学通知書(第6条)（即時）
--  機能概要      : 個人番号と履歴連番をキーにして入学通知書を出力する。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.WANGYANYING   2024/01/08
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
    g_sSTARTDATE                  NVARCHAR2(23);               -- 開始時刻

    --パラメータ変数
    g_NKOJIN_NO            NUMBER;                                 -- 個人番号
    g_NRIREKI_RENBAN       NUMBER;                                 -- 履歴連番
    g_NHASSO_NO            NUMBER;                                 -- 発送番号
    g_NHASSO_BI            NUMBER;                                 -- 発送日
    g_NNYUGAKU_KIJITSU     NUMBER;                                 -- 入学期日
    g_NIINKAI              NUMBER;                                 -- 教育委員会の連番
    g_VTANMATSU_NO         NVARCHAR2(20);                          -- 端末番号
    g_VGYOMU_KOIN          NVARCHAR2(500);
    o_NSQLCODE             NUMBER; 
    o_VSQLMSG              NVARCHAR2(300); 
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- 処理結果
    c_ISUCCESS     CONSTANT PLS_INTEGER := 0; -- 正常
    c_INOT_SUCCESS CONSTANT PLS_INTEGER := -1; -- 異常
    -- 業務コード
    c_VGYOMU_CD    CONSTANT VARCHAR2(3) := 'GKB';
    -- 帳票区分
    c_CHOHYO_KBN_T CONSTANT PLS_INTEGER := 5; -- 中学校入学通知
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    -- 戻り値取得用
    BRTN           BOOLEAN;
    IRTN           PLS_INTEGER;
    ISAKUSEIBI     PLS_INTEGER;
    -- 収発名
    VSYUHATU_MEI   NVARCHAR2(12);
    --公印ファイル名取得
    VGYOMU         NVARCHAR2(100); --業務毎公印ファイル名
    VTANTO_TEL     NVARCHAR2(60);
    VDATE_MEI1     NVARCHAR2(40);
    VDATE_MEI2     NVARCHAR2(40);
    VDATE_MEI3     NVARCHAR2(40);
    VDATE_MEI4     NVARCHAR2(40);
    VDATE_MEI5     NVARCHAR2(40);
    VKOMOKU_MEI1   NVARCHAR2(40);
    VKOMOKU_MEI2   NVARCHAR2(40);
    VKOMOKU_MEI3   NVARCHAR2(40);
    VKOMOKU_MEI4   NVARCHAR2(40);
    VKOMOKU_MEI5   NVARCHAR2(40);
    VKOMOKU_MEI6   NVARCHAR2(40);
    VKOMOKU_MEI7   NVARCHAR2(40);
    VKOMOKU_MEI8   NVARCHAR2(40);
    VKOMOKU_MEI9   NVARCHAR2(40);
    VKOMOKU_MEI10  NVARCHAR2(40);
    -- 宛名情報取得用
    RATENA_HOGOSHA GABTATENAKIHON%ROWTYPE;
    RSOFU_HOGOSHA  GABTSOFUSAKI%ROWTYPE;
    -- 児童宛名情報取得用
    RATENA_JIDO    GABTATENAKIHON%ROWTYPE;
    RSOFU_JIDO     GABTSOFUSAKI%ROWTYPE;
    NNENDO         PLS_INTEGER;
    VHYOUJINENDO   NVARCHAR2(30);
    ISIMEYISYUTURYOKUSEGYO             PLS_INTEGER;      -- 宛先の氏名出力制御
    IKYOUIKUIINKAIJOUHOU               PLS_INTEGER;      -- 教育委員会情報
    ICHOUHYOURENBANINZIKOUMOKU         PLS_INTEGER;      -- 帳票連番印字項目制御
    VACONSPRM1                         A_CONS_PRM;       -- パラメータの配列1
    NLENGTH1                           NUMBER;           -- パラメータの配列の長度1
    VACONSPRM2                         A_CONS_PRM;       -- パラメータの配列2
    NLENGTH2                           NUMBER;           -- パラメータの配列の長度2
    VACONSPRM3                         A_CONS_PRM;       -- パラメータの配列3
    NLENGTH3                           NUMBER;           -- パラメータの配列の長度3
    GYOSEIKUMEI                        NVARCHAR2(15);
    ATESAKI_JODAN                      NVARCHAR2(110);   
    ATESAKI_GEDAN                      NVARCHAR2(110);   
    VTANTO_YUBIN                       NVARCHAR2(60);
    VTANTO_JUSHO                       NVARCHAR2(60);
    ATESAKI_YUBIN_NO                   NVARCHAR2(10);
    ATESAKI_YUBIN_NOBC                 NVARCHAR2(30);
    ATESAKI_CHOMEI                     NVARCHAR2(40);
    ATESAKI_BANCHI                     NVARCHAR2(40);
    ATESAKI_KATAGAKI                   NVARCHAR2(60);
    VTANTO_YAKUSHOKU_MEI               NVARCHAR2(60);
    VTANTO_SHUTHOU_MEI                 NVARCHAR2(60);
    VTANTO_RITSU_MEI                   NVARCHAR2(60);
    VTANTO_TEL_NAISEN                  NVARCHAR2(60);
    HYOJI_CHOHYO_NO                    NVARCHAR2(90);    
    NCHOHYO_NO2                        NVARCHAR2(6);     -- ZZZZ9表示連番
    IGAKKO_CD2                         NVARCHAR2(5);     -- ZZZZ9学校コード
    HASSOBI                            PLS_INTEGER;
    NSHIMEI_KANJI          NVARCHAR2(110);       --氏名漢字
    o_SHIMEIPRM      A_CONS_PRM;
    o_LENGTH         NUMBER;
    BPRMFLG_001      BOOLEAN;
    BPRMFLG_002      BOOLEAN;
    BPRMFLG_003      BOOLEAN;
    BPRMFLG_004      BOOLEAN;
    o_YMD2           NVARCHAR2(30);
    N_NAIYO_CD       GKBTSHIMEIJKN.NAIYO_CD%TYPE;
    KYOIKUKAI_RENRAKUSAKI      NVARCHAR2(100);
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
    CURSOR CGAKUREIBO(p_NKOJIN_NO IN NUMBER, p_NRIREKI_RENBAN IN NUMBER) IS
      SELECT *
        FROM GKBTGAKUREIBO
       WHERE KOJIN_NO      = p_NKOJIN_NO
         AND RIREKI_RENBAN = p_NRIREKI_RENBAN;
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/08
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/08
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/08
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
                     g_NKOJIN_NO            := aCSV_TBL(i);         -- 個人番号
                WHEN 2 THEN
                     g_NRIREKI_RENBAN       := aCSV_TBL(i);         -- 履歴連番
                WHEN 3 THEN
                     g_NHASSO_NO            := aCSV_TBL(i);         -- 発送番号
                WHEN 4 THEN
                     g_NHASSO_BI            := aCSV_TBL(i);         -- 発送日
                WHEN 5 THEN
                     g_NNYUGAKU_KIJITSU     := aCSV_TBL(i);         -- 入学期日
                WHEN 6 THEN
                     g_NIINKAI              := aCSV_TBL(i);         -- 教育委員会の連番
                WHEN 7 THEN
                     g_VTANMATSU_NO         := aCSV_TBL(i);         -- 端末番号
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/08
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/08
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
    -- 通知書条件取得
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_TSUCHISHO_JKN(i_IGAKKO_CD IN PLS_INTEGER)
      RETURN GKBTTSUCHISHOJKN%ROWTYPE
    IS
      RTSUCHISHOJKN  GKBTTSUCHISHOJKN%ROWTYPE;
    BEGIN
      BEGIN
        SELECT *
          INTO RTSUCHISHOJKN
          FROM GKBTTSUCHISHOJKN
         WHERE CHOHYO_KBN = c_CHOHYO_KBN_T
           AND GAKO_CD = i_IGAKKO_CD;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RTSUCHISHOJKN := NULL;
          RTSUCHISHOJKN.DATE1 := 0;
          RTSUCHISHOJKN.DATE2 := 0;
          RTSUCHISHOJKN.DATE3 := 0;
          RTSUCHISHOJKN.DATE4 := 0;
          RTSUCHISHOJKN.DATE5 := 0;
          RTSUCHISHOJKN.KOMOKU1  := ' ';
          RTSUCHISHOJKN.KOMOKU2  := ' ';
          RTSUCHISHOJKN.KOMOKU3  := ' ';
          RTSUCHISHOJKN.KOMOKU4  := ' ';
          RTSUCHISHOJKN.KOMOKU5  := ' ';
          RTSUCHISHOJKN.KOMOKU6  := ' ';
          RTSUCHISHOJKN.KOMOKU7  := ' ';
          RTSUCHISHOJKN.KOMOKU8  := ' ';
          RTSUCHISHOJKN.KOMOKU9  := ' ';
          RTSUCHISHOJKN.KOMOKU10 := ' ';
      END;
      RETURN RTSUCHISHOJKN;
    END FUNC_GET_TSUCHISHO_JKN;
    --------------------------------------------------------------------------------
    -- 教育学校名取得
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_EQGAKKOMEI(i_IGAKKO_CD IN PLS_INTEGER)
      RETURN NVARCHAR2
    IS
      VTYUGAKOMEI  GKBTCHUGAKKO.TYUGAKOMEI%TYPE;
    BEGIN
      BEGIN
        SELECT TYUGAKOMEI
          INTO VTYUGAKOMEI
          FROM GKBTCHUGAKKO
         WHERE TYUGAKO_CD = i_IGAKKO_CD;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          VTYUGAKOMEI := ' ';
      END;
      RETURN VTYUGAKOMEI;
    END FUNC_GET_EQGAKKOMEI;
    --------------------------------------------------------------------------------
    -- 共通情報取得
    --------------------------------------------------------------------------------
    PROCEDURE PROC_GET_USER(o_USERMEI OUT NVARCHAR2, o_GAPPEIBI OUT PLS_INTEGER) IS
      -- 共通情報取得用変数(KKAPK0030.FKYOTU)
      i_IKIJYUNBI              PLS_INTEGER;    -- 基準日
      o_IUSER_ID               PLS_INTEGER;    -- 市町村コード
      o_IGAPPEI_BI             PLS_INTEGER;    -- 合併日付
      o_IJICHI_CD              PLS_INTEGER;    -- 自治コード
      o_IUSER_KBN              PLS_INTEGER;    -- 市町村区分
      o_VKENMEI                NVARCHAR2(30);  -- 県名
      o_VGUNSHIMEI             NVARCHAR2(30);  -- 郡市名
      o_VUSERMEI               NVARCHAR2(40);  -- 市町村名
      o_VSHUCHOMEI             NVARCHAR2(40);  -- 首長名
      o_VSHUNYUNINSHOBUN       NVARCHAR2(100); -- 収入役認証文
      o_VYUBIN_NO              NVARCHAR2(10);  -- 郵便番号
      o_VSHOZAICHI             NVARCHAR2(200); -- 所在地
      o_VTEL_NO                NVARCHAR2(20);  -- 代表電話番号
    BEGIN
      i_IKIJYUNBI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
      IRTN := KKAPK0030.FKYOTU(i_IKIJYUNBI,
                                o_IUSER_ID, o_IJICHI_CD,  o_IGAPPEI_BI, o_IUSER_KBN,
                                o_VGUNSHIMEI,  o_VUSERMEI, o_VSHUCHOMEI, o_VKENMEI,
                                o_VSHUNYUNINSHOBUN, o_VYUBIN_NO, o_VSHOZAICHI, o_VTEL_NO);
      o_USERMEI   := o_VUSERMEI;
      o_GAPPEIBI  := o_IGAPPEI_BI;
    END PROC_GET_USER;
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
      BRTN := KKAPK0020.FDAYEDIT(io_WAREKIHIZUKE, io_SEIREKIHIZUKE,
                                  o_EDIT_GYYMMDD1, o_EDIT_GYYMMDD2, o_EDIT_GYYMMDD3,
                                  o_KJ_GENGO, o_KG_GENGO, o_WAREKI_YY, o_SEIREKI_YYYY,
                                  o_WAREKI_GYYMM, o_MM, o_DD, o_IWAREKIHIZUKE, o_ISEIREKIHIZUKE);
      IF BRTN THEN
        o_YMD := o_EDIT_GYYMMDD3;
      ELSE
        o_YMD := ' ';
      END IF;
    END PROC_GET_YMD;
    --------------------------------------------------------------------------------
    -- 制御のフラグをセットするのを行う
    --------------------------------------------------------------------------------
    FUNCTION FUNC_PRMFLGSET(i_KOJIN_NO IN NUMBER,o_NAIYO_CD OUT NUMBER) RETURN NUMBER IS
      NODATAFOUND_FLG    BOOLEAN;
      ZERO_FLG           BOOLEAN;
    BEGIN
      --フラグ初期化
      BPRMFLG_001      := FALSE;
      BPRMFLG_002      := FALSE;
      BPRMFLG_003      := FALSE;
      BPRMFLG_004      := FALSE;
      NODATAFOUND_FLG    := FALSE;
      ZERO_FLG           := FALSE;
      --本名使用制御管理情報の取得
      BEGIN 
        SELECT NAIYO_CD INTO o_NAIYO_CD
        FROM GKBTSHIMEIJKN
        WHERE KOJIN_NO = i_KOJIN_NO
         AND CHOHYO_ID = 'GKB040R001';
        IF o_NAIYO_CD = 0 THEN
          ZERO_FLG  := TRUE;
        END IF;
      EXCEPTION
        --データを取得しない場合
        WHEN NO_DATA_FOUND THEN
        NODATAFOUND_FLG  := TRUE;
      END;
      --氏名印字.制御ﾊﾟﾗﾒｰﾀ(7)が1の場合
      IF o_SHIMEIPRM(7) = 1 THEN
        BPRMFLG_001  := TRUE;
      END IF;
      --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(7)が4、6場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(7) IN (4, 6) THEN
          BPRMFLG_002  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在する、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(7)が3、4、5、6場合
      IF NOT NODATAFOUND_FLG AND NOT ZERO_FLG THEN
        IF o_SHIMEIPRM(7) IN(3,4,5,6) THEN
          BPRMFLG_003  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(7)が4、5場合「生年月日」
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(7) IN (4, 5) THEN
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
              IRTN := GKBPK00010.FYMDEDT1(i_YMD,o_YMD,o_YMD2);
              o_YMD    := o_YMD2;  
            ELSIF BPRMFLG_003 THEN
              -- 和暦で表示生年月日
              IF N_NAIYO_CD IN(11,21) THEN
                o_YMD    := o_EDIT_GYYMMDD3;
              -- 西暦で表示生年月日
              ELSIF N_NAIYO_CD IN(12,22) THEN
                o_YMD    := o_SEIREKI_YYYY || '年'||LPAD(o_MM,2)||'月'||LPAD(o_DD,2)||'日';
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
      RGAKUREIBO GKBTGAKUREIBO%ROWTYPE;
      -- 戻り値
      IFRET PLS_INTEGER;
      -- 中学校コード
      IGAKKO_CD   PLS_INTEGER;
      VGAKKO_MEI  NVARCHAR2(60);
      -- 出力用児童生年月日
      JIDO_BTH_OUT NVARCHAR2(11);
      -- 出力用入学期日
      NYUGAKUKIJITU_OUT NVARCHAR2(11);
      -- 出力用発送日
      HASSOBI_OUT NVARCHAR2(11);
      -- 日付
      DATE_IN PLS_INTEGER;
      -- 出力用日付
      DATE1_OUT NVARCHAR2(11);
      DATE2_OUT NVARCHAR2(11);
      DATE3_OUT NVARCHAR2(11);
      DATE4_OUT NVARCHAR2(11);
      DATE5_OUT NVARCHAR2(11);
      -- 出力用項目
      KOMOKU1_OUT  NVARCHAR2(120);
      KOMOKU2_OUT  NVARCHAR2(120);
      KOMOKU3_OUT  NVARCHAR2(120);
      KOMOKU4_OUT  NVARCHAR2(120);
      KOMOKU5_OUT  NVARCHAR2(120);
      KOMOKU6_OUT  NVARCHAR2(120);
      KOMOKU7_OUT  NVARCHAR2(120);
      KOMOKU8_OUT  NVARCHAR2(120);
      KOMOKU9_OUT  NVARCHAR2(120);
      KOMOKU10_OUT NVARCHAR2(120);
      VUSER_MEI  NVARCHAR2(40);    -- 市町村名
      IGAPPEIBI  PLS_INTEGER;      -- 合併日
      VSEIBETSU NVARCHAR2(1);
      -- 続柄
      VZOKUGARAMEI1     NVARCHAR2(30); --続柄名１
      VZOKUGARAMEI2     NVARCHAR2(30); --続柄名２
      IRTNZOKUGARA1     PLS_INTEGER;
      IRTNZOKUGARAHERR1 PLS_INTEGER;
      IRTNZOKUGARA2     PLS_INTEGER;
      IRTNZOKUGARAHERR2 PLS_INTEGER;
      -- 通知書条件
      RTSUCHISHOJKN  GKBTTSUCHISHOJKN%ROWTYPE;
      -- 宛名情報取得用
      RATENA_JIDO    GABTATENAKIHON%ROWTYPE;
      RSOFU_JIDO     GABTSOFUSAKI%ROWTYPE;
      RATENA_HOGOSHA GABTATENAKIHON%ROWTYPE;
      RSOFU_HOGOSHA  GABTSOFUSAKI%ROWTYPE;
      -- 表示用送付先住所
      VYUBIN_NO     NVARCHAR2(10);   
      VYUBIN_NOBC   NVARCHAR2(30);
      VCHOMEI       NVARCHAR2(40);
      VBANCHI       NVARCHAR2(40);
      VKATAGAKI     NVARCHAR2(60);
      VJIDO_YUBIN_NO   NVARCHAR2(10);  -- 郵便番号
      VJIDO_YUBIN_NOBC NVARCHAR2(30);  -- 郵便番号BC
      VJIDO_CHOMEI     NVARCHAR2(40);  -- 町名
      VJIDO_BANCHI     NVARCHAR2(40);  -- 番地
      VJIDO_KATAGAKI   NVARCHAR2(60);  -- 方書
      VDUMMY           NVARCHAR2(1000);
      r_CHOHYO_001     GKBWL080R001%ROWTYPE;
      nCOUNT           NUMBER;
    BEGIN
      -- 正常終了
      IFRET := c_ISUCCESS;
      BEGIN
        DELETE FROM GKBWL080R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
        nCOUNT := 0;
        -- 教育委員会電話番号取得
        VTANTO_TEL := VACONSPRM2(7);
        --市町村名の取得
        PROC_GET_USER(VUSER_MEI, IGAPPEIBI);
        -- カーソルのオープン
        OPEN CGAKUREIBO(g_NKOJIN_NO, g_NRIREKI_RENBAN);
        -- レコード参照
        FETCH CGAKUREIBO INTO RGAKUREIBO;
        -- ループ開始
        LOOP
          -- 読むレコードが無い場合ループから抜け出す
          EXIT WHEN CGAKUREIBO%NOTFOUND;
          nCOUNT := nCOUNT + 1;
          -- 発送日が入力された場合は発送日時点の宛名を取得する
          IF g_NHASSO_BI > 0 THEN
            -- 児童宛名情報取得
            IRTN := GAAPK0030.FGETATENA(RGAKUREIBO.KOJIN_NO, c_VGYOMU_CD, g_NHASSO_BI,
                                      RATENA_JIDO, RSOFU_JIDO);
            -- 保護者宛名情報取得
            IRTN := GAAPK0030.FGETATENA(RGAKUREIBO.HOGOSYA_KOJIN_NO, c_VGYOMU_CD, g_NHASSO_BI,
                                      RATENA_HOGOSHA, RSOFU_HOGOSHA);
          -- 発送日が入力されなかった場合は作成日時点での宛名を取得する
          ELSE
            -- 児童宛名情報取得
            IRTN := GAAPK0030.FGETATENA(RGAKUREIBO.KOJIN_NO, c_VGYOMU_CD, ISAKUSEIBI,
                                      RATENA_JIDO, RSOFU_JIDO);
            -- 保護者宛名情報取得
            IRTN := GAAPK0030.FGETATENA(RGAKUREIBO.HOGOSYA_KOJIN_NO, c_VGYOMU_CD, ISAKUSEIBI,
                                      RATENA_HOGOSHA, RSOFU_HOGOSHA);        
          END IF;
          IRTN  := FUNC_PRMFLGSET(RATENA_JIDO.KOJIN_NO,N_NAIYO_CD);
          -- 中学校コードが学齢簿に登録されていなければ宛名の中学校名を使用する
          IF RGAKUREIBO.TYUGAKO_CD = 0 THEN
            IGAKKO_CD := RATENA_JIDO.CHUGAKU_CD;
            IF g_NHASSO_BI >= IGAPPEIBI THEN
              VGAKKO_MEI := GAAPK0030.FCHUGAKUMEI(1, IGAKKO_CD);
            ELSE
              VGAKKO_MEI := GAAPK0030.FCHUGAKUMEI(RATENA_JIDO.SANTEIDANTAI_CD, IGAKKO_CD);
            END IF;
          ELSE
            IGAKKO_CD := RGAKUREIBO.TYUGAKO_CD;
            VGAKKO_MEI := FUNC_GET_EQGAKKOMEI(IGAKKO_CD);
          END IF;
          -- 通知書条件の取得
          RTSUCHISHOJKN := FUNC_GET_TSUCHISHO_JKN(IGAKKO_CD);
          -- 出力用児童生年月日の取得
          PROC_GET_YMD(RATENA_JIDO.SEINENGAPI, JIDO_BTH_OUT);
          IF (RATENA_JIDO.JINKAKU_KBN != 0) THEN
            PROC_GET_YMD1(RATENA_JIDO.JINKAKU_KBN,RATENA_JIDO.SEINENGAPI, JIDO_BTH_OUT);
          END IF;
          -- 入学期日の取得
          PROC_GET_YMD(g_NNYUGAKU_KIJITSU, NYUGAKUKIJITU_OUT);
          NNENDO := KKAPK0020.FDAYNENDO(g_NNYUGAKU_KIJITSU,0);
          IF NVL(NNENDO,0) = 0 THEN
            VHYOUJINENDO := '';
          ELSE
            PROC_GET_YMD(NNENDO * 10000 + 401,VHYOUJINENDO);
            VHYOUJINENDO := SUBSTR(VHYOUJINENDO,1,4);
          END IF;
          -- 発送日の取得
          PROC_GET_YMD(g_NHASSO_BI, HASSOBI_OUT);
          -- 続柄名取得
          IRTNZOKUGARA1 := GKBFKZKGMGET(1,
                                        RGAKUREIBO.ZOKUGARA1, RGAKUREIBO.ZOKUGARA2,
                                        RGAKUREIBO.ZOKUGARA3, RGAKUREIBO.ZOKUGARA4,
                                        VZOKUGARAMEI1, IRTNZOKUGARAHERR1);
          IRTNZOKUGARA2 := GKBFKZKGMGET(2,
                                        RGAKUREIBO.HOGOSYA_ZOKUGARA1, RGAKUREIBO.HOGOSYA_ZOKUGARA2,
                                        RGAKUREIBO.HOGOSYA_ZOKUGARA3, RGAKUREIBO.HOGOSYA_ZOKUGARA4,
                                        VZOKUGARAMEI2, IRTNZOKUGARAHERR2);
          -- 表示用送付先住所
          IF RSOFU_HOGOSHA.KOJIN_NO > 0 AND
             (RSOFU_HOGOSHA.TEKIYO_BI <= HASSOBI) AND
             ((RSOFU_HOGOSHA.SHURYO_BI >= HASSOBI) OR (RSOFU_HOGOSHA.SHURYO_BI = 0)) THEN
            IF LENGTH(RSOFU_HOGOSHA.YUBIN_NO) > 0 THEN
              VYUBIN_NO := SUBSTR(RSOFU_HOGOSHA.YUBIN_NO, 1, 3) || '-' || SUBSTR(RSOFU_HOGOSHA.YUBIN_NO, 4);
              VYUBIN_NO := TRANSLATE(VYUBIN_NO, '1234567890-', '１２３４５６７８９０－');
            ELSE
              VYUBIN_NO := NULL;
            END IF;
            VYUBIN_NOBC   := RSOFU_HOGOSHA.YUBIN_NOBC;
            VCHOMEI       := RSOFU_HOGOSHA.CHOMEI;
            VBANCHI       := RSOFU_HOGOSHA.BANCHI;
            VKATAGAKI     := RSOFU_HOGOSHA.KATAGAKI;
          ELSE
            IF LENGTH(RATENA_HOGOSHA.YUBIN_NO) > 0 THEN
              VYUBIN_NO := SUBSTR(RATENA_HOGOSHA.YUBIN_NO, 1, 3) || '-' || SUBSTR(RATENA_HOGOSHA.YUBIN_NO, 4);
              VYUBIN_NO := TRANSLATE(VYUBIN_NO, '1234567890-', '１２３４５６７８９０－');
            ELSE
              VYUBIN_NO := NULL;
            END IF;
            VYUBIN_NOBC   := RATENA_HOGOSHA.YUBIN_NOBC;
            VCHOMEI       := RATENA_HOGOSHA.CHOMEI;
            VBANCHI       := RATENA_HOGOSHA.BANCHI;
            VKATAGAKI     := RATENA_HOGOSHA.KATAGAKI;
          END IF;
          IF RSOFU_JIDO.KOJIN_NO > 0 AND
             (RSOFU_JIDO.TEKIYO_BI <= HASSOBI) AND
             ((RSOFU_JIDO.SHURYO_BI >= HASSOBI) OR (RSOFU_JIDO.SHURYO_BI = 0)) THEN
            IF LENGTH(RSOFU_JIDO.YUBIN_NO) > 0 THEN
              VJIDO_YUBIN_NO := SUBSTR(RSOFU_JIDO.YUBIN_NO,1,3)||'-'||SUBSTR(RSOFU_JIDO.YUBIN_NO,4);
              VJIDO_YUBIN_NO := TRANSLATE(VJIDO_YUBIN_NO, '1234567890-', '１２３４５６７８９０－');
            ELSE
              VJIDO_YUBIN_NO := NULL;
            END IF;
            VJIDO_YUBIN_NOBC := RSOFU_JIDO.YUBIN_NOBC;
            VJIDO_CHOMEI     := RSOFU_JIDO.CHOMEI;
            VJIDO_BANCHI     := RSOFU_JIDO.BANCHI;
            VJIDO_KATAGAKI   := RSOFU_JIDO.KATAGAKI;
          ELSE
            IF LENGTH(RATENA_JIDO.YUBIN_NO) > 0 THEN
              VJIDO_YUBIN_NO := SUBSTR(RATENA_JIDO.YUBIN_NO,1,3)||'-'||SUBSTR(RATENA_JIDO.YUBIN_NO,4);
              VJIDO_YUBIN_NO := TRANSLATE(VJIDO_YUBIN_NO, '1234567890-', '１２３４５６７８９０－');
            ELSE
              VJIDO_YUBIN_NO := NULL;
            END IF;
            VJIDO_YUBIN_NOBC := RATENA_JIDO.YUBIN_NOBC;
            VJIDO_CHOMEI     := RATENA_JIDO.CHOMEI;
            VJIDO_BANCHI     := RATENA_JIDO.BANCHI;
            VJIDO_KATAGAKI   := RATENA_JIDO.KATAGAKI;
          END IF;
          -- ＣＳＶ出力用変数の初期化
          r_CHOHYO_001 := NULL;
          r_CHOHYO_001.NO := nCOUNT;
          r_CHOHYO_001.NENDO := VHYOUJINENDO;
          r_CHOHYO_001.KAIPAGE_CD := NULL;
          r_CHOHYO_001.KAIPAGE_MEI := NULL;
          r_CHOHYO_001.KIJUNBI := NULL;
          -- 連番
          r_CHOHYO_001.RENBAN := 1;
          -- 児童氏名かな
        IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
          IRTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANA,RATENA_JIDO.SHIMEI_KANA,RATENA_JIDO.SHIMEI_KANA);
        END IF;
          r_CHOHYO_001.JIDO_SHIMEI_KANA := RATENA_JIDO.SHIMEI_KANA;
          -- 児童氏名漢字
        IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
          IRTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,RATENA_JIDO.SHIMEI_KANJI);
        END IF;
          r_CHOHYO_001.JIDO_SHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
          -- 表示生年月日
          r_CHOHYO_001.HYOJI_SEINENGAPI := NULL;
          -- 性別
          IF RATENA_JIDO.SEIBETSU = 1 THEN
            VSEIBETSU := '男';
          ELSIF RATENA_JIDO.SEIBETSU = 2 THEN
            VSEIBETSU := '女';
          ELSE
            VSEIBETSU := NULL;
          END IF;
          r_CHOHYO_001.HYOJI_SEIBETSU := VSEIBETSU;
          -- 保護者氏名かな
        IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
          IRTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANA,RATENA_HOGOSHA.SHIMEI_KANA,RATENA_HOGOSHA.SHIMEI_KANA);
        END IF;
          r_CHOHYO_001.HOGOSHA_SHIMEI_KANA := RATENA_HOGOSHA.SHIMEI_KANA;
          -- 保護者氏名漢字
        IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
          IRTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI);
        END IF;
          r_CHOHYO_001.HOGOSHA_SHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
          -- 住所上
          r_CHOHYO_001.JUSHO_JODAN := NULL;
          -- 住所下
          r_CHOHYO_001.JUSHO_GEDAN := NULL;
          GYOSEIKUMEI := GAAPK0030.FGYOSEIKUMEI(RATENA_HOGOSHA.SANTEIDANTAI_CD,RATENA_HOGOSHA.GYOSEIKU_CD);
          -- 行政区名
          r_CHOHYO_001.GYOSEIKU_MEI := GYOSEIKUMEI;
          -- 中学校名
          r_CHOHYO_001.GAKKO_MEI := VGAKKO_MEI;
          -- 収発名を取得する
          BEGIN
            SELECT SHUHATS_MEI,
                   DATE_MEI1,   DATE_MEI2,   DATE_MEI3,   DATE_MEI4,   DATE_MEI5,
                   KOMOKU_MEI1, KOMOKU_MEI2, KOMOKU_MEI3, KOMOKU_MEI4, KOMOKU_MEI5,
                   KOMOKU_MEI6, KOMOKU_MEI7, KOMOKU_MEI8, KOMOKU_MEI9, KOMOKU_MEI10
              INTO VSYUHATU_MEI,
                   VDATE_MEI1,   VDATE_MEI2,   VDATE_MEI3,   VDATE_MEI4,   VDATE_MEI5,
                   VKOMOKU_MEI1, VKOMOKU_MEI2, VKOMOKU_MEI3, VKOMOKU_MEI4, VKOMOKU_MEI5,
                   VKOMOKU_MEI6, VKOMOKU_MEI7, VKOMOKU_MEI8, VKOMOKU_MEI9, VKOMOKU_MEI10
              FROM GKBTTSUCHISHOKANRI
             WHERE CHOHYO_KBN = c_CHOHYO_KBN_T;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              VSYUHATU_MEI  := NULL;
              VDATE_MEI1    := NULL;
              VDATE_MEI2    := NULL;
              VDATE_MEI3    := NULL;
              VDATE_MEI4    := NULL;
              VDATE_MEI5    := NULL;
              VKOMOKU_MEI1  := NULL;
              VKOMOKU_MEI2  := NULL;
              VKOMOKU_MEI3  := NULL;
              VKOMOKU_MEI4  := NULL;
              VKOMOKU_MEI5  := NULL;
              VKOMOKU_MEI6  := NULL;
              VKOMOKU_MEI7  := NULL;
              VKOMOKU_MEI8  := NULL;
              VKOMOKU_MEI9  := NULL;
              VKOMOKU_MEI10 := NULL;
          END;
          --公印ファイル名取得
          BRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE,0),g_sWSNUM,SYSDATE,VDUMMY,VDUMMY,VDUMMY,VDUMMY,VGYOMU);
          -- 日付の取得
          DATE_IN := RTSUCHISHOJKN.DATE1;
          PROC_GET_YMD(DATE_IN, DATE1_OUT);
          DATE_IN := RTSUCHISHOJKN.DATE2;
          PROC_GET_YMD(DATE_IN, DATE2_OUT);
          DATE_IN := RTSUCHISHOJKN.DATE3;
          PROC_GET_YMD(DATE_IN, DATE3_OUT);
          DATE_IN := RTSUCHISHOJKN.DATE4;
          PROC_GET_YMD(DATE_IN, DATE4_OUT);
          DATE_IN := RTSUCHISHOJKN.DATE5;
          PROC_GET_YMD(DATE_IN, DATE5_OUT);
          KOMOKU1_OUT  := RTSUCHISHOJKN.KOMOKU1;
          KOMOKU2_OUT  := RTSUCHISHOJKN.KOMOKU2;
          KOMOKU3_OUT  := RTSUCHISHOJKN.KOMOKU3;
          KOMOKU4_OUT  := RTSUCHISHOJKN.KOMOKU4;
          KOMOKU5_OUT  := RTSUCHISHOJKN.KOMOKU5;
          KOMOKU6_OUT  := RTSUCHISHOJKN.KOMOKU6;
          KOMOKU7_OUT  := RTSUCHISHOJKN.KOMOKU7;
          KOMOKU8_OUT  := RTSUCHISHOJKN.KOMOKU8;
          KOMOKU9_OUT  := RTSUCHISHOJKN.KOMOKU9;
          KOMOKU10_OUT := RTSUCHISHOJKN.KOMOKU10;
          r_CHOHYO_001.SANTEIDANTAI_MEI := NULL;
          -- 郵便番号
          r_CHOHYO_001.YUBIN_NO := VYUBIN_NO;
          -- 町名番地
          r_CHOHYO_001.CHOMEI_BANCHI := VCHOMEI || VBANCHI;
          -- 方書
          r_CHOHYO_001.KATAGAKI := VKATAGAKI;
          -- 保護者氏名漢字
            -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=1,3の場合
            IF VACONSPRM1(1) IN (1,3) THEN
                        IF (RSOFU_JIDO.KOJIN_NO > 0) AND 
                     (RSOFU_JIDO.TEKIYO_BI <= HASSOBI) AND 
                     (RSOFU_JIDO.SHURYO_BI >= HASSOBI OR  RSOFU_JIDO.SHURYO_BI = 0) THEN
                     IF RSOFU_JIDO.SHIMEI_KANJI IS NOT NULL THEN
                        NSHIMEI_KANJI := RSOFU_JIDO.SHIMEI_KANJI;
                     ELSE
                        NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                        IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                          IRTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                        END IF;
                     END IF;
                  ELSE
                     NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                     IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                       IRTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                     END IF;
                  END IF;
              IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
                -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(2)=1の場合
                IF VACONSPRM1(3) = 1 THEN
                  ATESAKI_JODAN := '（'||NSHIMEI_KANJI||'　様）';
                -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(2)=1以外の場合
                ELSE
                  ATESAKI_JODAN := NSHIMEI_KANJI||'　様';
                END IF;
              ELSE
                ATESAKI_JODAN := '';
              END IF;
            -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=1,3以外の場合
            ELSE
                        IF (RSOFU_HOGOSHA.KOJIN_NO  > 0) AND 
                     (RSOFU_HOGOSHA.TEKIYO_BI <= HASSOBI) AND 
                     (RSOFU_HOGOSHA.SHURYO_BI >= HASSOBI OR  RSOFU_HOGOSHA.SHURYO_BI = 0) THEN
                     IF RSOFU_HOGOSHA.SHIMEI_KANJI IS NOT NULL THEN
                        NSHIMEI_KANJI := RSOFU_HOGOSHA.SHIMEI_KANJI;
                     ELSE
                        NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                        IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                          IRTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                        END IF;
                     END IF;
                  ELSE
                     NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                     IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                       IRTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                     END IF;
                  END IF;
              IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
                -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(2)=1の場合
                IF VACONSPRM1(2) = 1 THEN
                  ATESAKI_JODAN := '（'||NSHIMEI_KANJI||'　様）';
                -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(2)=1以外の場合
                ELSE
                  ATESAKI_JODAN := NSHIMEI_KANJI||'　様';
                END IF;
              ELSE
                ATESAKI_JODAN := '';
              END IF;
            END IF;
            -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=2,3の場合
            IF VACONSPRM1(1) IN (2,3) THEN
              -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=2の場合
              IF VACONSPRM1(1) = 2 THEN
                        IF (RSOFU_JIDO.KOJIN_NO > 0) AND 
                     (RSOFU_JIDO.TEKIYO_BI <= HASSOBI) AND 
                     (RSOFU_JIDO.SHURYO_BI >= HASSOBI OR  RSOFU_JIDO.SHURYO_BI = 0) THEN
                     IF RSOFU_JIDO.SHIMEI_KANJI IS NOT NULL THEN
                        NSHIMEI_KANJI := RSOFU_JIDO.SHIMEI_KANJI;
                     ELSE
                        NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                        IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                          IRTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                        END IF;
                     END IF;
                  ELSE
                     NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                     IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                       IRTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                     END IF;
                  END IF;
                IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
                  -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(3)=1の場合
                  IF VACONSPRM1(3) = 1 THEN
                    ATESAKI_GEDAN := '（'||NSHIMEI_KANJI||'　様）';
                  -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(3)=1以外の場合
                  ELSE
                    ATESAKI_GEDAN := NSHIMEI_KANJI||'　様';
                  END IF;
                ELSE
                ATESAKI_GEDAN := '';
                END IF;
              -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=3の場合
              ELSE
                        IF (RSOFU_HOGOSHA.KOJIN_NO  > 0) AND 
                     (RSOFU_HOGOSHA.TEKIYO_BI <= HASSOBI) AND 
                     (RSOFU_HOGOSHA.SHURYO_BI >= HASSOBI OR  RSOFU_HOGOSHA.SHURYO_BI = 0) THEN
                     IF RSOFU_HOGOSHA.SHIMEI_KANJI IS NOT NULL THEN
                        NSHIMEI_KANJI := RSOFU_HOGOSHA.SHIMEI_KANJI;
                     ELSE
                        NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                        IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                          IRTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                        END IF;
                     END IF;
                  ELSE
                     NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                     IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                       IRTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                     END IF;
                  END IF;
                IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
                  -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(3)=1の場合
                  IF VACONSPRM1(2) = 1 THEN
                    ATESAKI_GEDAN := '（'||NSHIMEI_KANJI||'　様）';
                  -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(3)=1以外の場合
                  ELSE
                    ATESAKI_GEDAN := NSHIMEI_KANJI||'　様';
                  END IF;
                ELSE
                  ATESAKI_GEDAN := '';
                END IF;
              END IF;
            -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=2,3以外の場合
            ELSE
              ATESAKI_GEDAN := ' ';
            END IF;
          r_CHOHYO_001.ATESAKI_JODAN := ATESAKI_JODAN;
          r_CHOHYO_001.ATESAKI_GEDAN := ATESAKI_GEDAN;
          -- 児童生年月日
          r_CHOHYO_001.KANJI_SEINENGAPI := JIDO_BTH_OUT;
          -- 市町村名
            VUSER_MEI := VACONSPRM2(1);
          r_CHOHYO_001.KYOIKU_KAI_MEI := VUSER_MEI;
          -- 入学期日
          r_CHOHYO_001.NYUGAKU_KIJITU := NYUGAKUKIJITU_OUT;
          -- 発送日
          r_CHOHYO_001.HASSOBI := HASSOBI_OUT;
          -- 発送番号
          r_CHOHYO_001.HASSO_NO := VSYUHATU_MEI || '第 ' || g_NHASSO_NO || ' 号';
          -- 公印
          r_CHOHYO_001.KOIN_PATH := VGYOMU; -- 業務毎公印ファイル名（.bmp）
          -- 電話番号
          r_CHOHYO_001.TANTO_TEL := VTANTO_TEL;
          IF LENGTH(VACONSPRM2(5)) > 0 THEN
            VTANTO_YUBIN := SUBSTR(VACONSPRM2(5),1,3) || '-' || SUBSTR(VACONSPRM2(5),4);
            VTANTO_YUBIN := TRANSLATE(VTANTO_YUBIN, '1234567890-', '１２３４５６７８９０－');
          ELSE
            VTANTO_YUBIN := '';
          END IF;
          VTANTO_JUSHO := VACONSPRM2(6);
          r_CHOHYO_001.TANTO_YUBIN_NO := VTANTO_YUBIN;
          r_CHOHYO_001.TANTO_JUSHO := VTANTO_JUSHO;
          -- カスタマーバーコード
          r_CHOHYO_001.YUBIN_NOBC := VYUBIN_NOBC;
          r_CHOHYO_001.DATE1 := DATE1_OUT;        -- 日付１
          r_CHOHYO_001.DATE2 := DATE2_OUT;        -- 日付２
          r_CHOHYO_001.DATE3 := DATE3_OUT;        -- 日付３
          r_CHOHYO_001.DATE4 := DATE4_OUT;        -- 日付４
          r_CHOHYO_001.DATE5 := DATE5_OUT;        -- 日付５
          r_CHOHYO_001.KOMOKU1 := KOMOKU1_OUT;        -- 項目１
          r_CHOHYO_001.KOMOKU2 := KOMOKU2_OUT;        -- 項目２
          r_CHOHYO_001.KOMOKU3 := KOMOKU3_OUT;        -- 項目３
          r_CHOHYO_001.KOMOKU4 := KOMOKU4_OUT;        -- 項目４
          r_CHOHYO_001.KOMOKU5 := KOMOKU5_OUT;        -- 項目５
          r_CHOHYO_001.KOMOKU6 := KOMOKU6_OUT;        -- 項目６
          r_CHOHYO_001.KOMOKU7 := KOMOKU7_OUT;        -- 項目７
          r_CHOHYO_001.KOMOKU8 := KOMOKU8_OUT;        -- 項目８
          r_CHOHYO_001.KOMOKU9 := KOMOKU9_OUT;        -- 項目９
          r_CHOHYO_001.KOMOKU10 := KOMOKU10_OUT;      -- 項目１０
          r_CHOHYO_001.DATE_MEI1 := VDATE_MEI1;
          r_CHOHYO_001.DATE_MEI2 := VDATE_MEI2;
          r_CHOHYO_001.DATE_MEI3 := VDATE_MEI3;
          r_CHOHYO_001.DATE_MEI4 := VDATE_MEI4;
          r_CHOHYO_001.DATE_MEI5 := VDATE_MEI5;
          r_CHOHYO_001.KOMOKU_MEI1 := VKOMOKU_MEI1;
          r_CHOHYO_001.KOMOKU_MEI2 := VKOMOKU_MEI2;
          r_CHOHYO_001.KOMOKU_MEI3 := VKOMOKU_MEI3;
          r_CHOHYO_001.KOMOKU_MEI4 := VKOMOKU_MEI4;
          r_CHOHYO_001.KOMOKU_MEI5 := VKOMOKU_MEI5;
          r_CHOHYO_001.KOMOKU_MEI6 := VKOMOKU_MEI6;
          r_CHOHYO_001.KOMOKU_MEI7 := VKOMOKU_MEI7;
          r_CHOHYO_001.KOMOKU_MEI8 := VKOMOKU_MEI8;
          r_CHOHYO_001.KOMOKU_MEI9 := VKOMOKU_MEI9;
          r_CHOHYO_001.KOMOKU_MEI10 := VKOMOKU_MEI10;
          r_CHOHYO_001.GAKKO_CD := IGAKKO_CD;
          r_CHOHYO_001.ZOKUGARAMEI1 := VZOKUGARAMEI1;
          r_CHOHYO_001.ZOKUGARAMEI2 := VZOKUGARAMEI2;
          r_CHOHYO_001.JIDO_YUBIN_NO := VJIDO_YUBIN_NO;
          r_CHOHYO_001.JIDO_YUBIN_NOBC := VJIDO_YUBIN_NOBC;
          r_CHOHYO_001.JIDO_CHOMEI_BANCHI := VJIDO_CHOMEI || VJIDO_BANCHI;
          r_CHOHYO_001.JIDO_KATAGAKI := VJIDO_KATAGAKI;
          IF VACONSPRM1(1) IN (1,3) THEN
            ATESAKI_YUBIN_NO   := VJIDO_YUBIN_NO;
            ATESAKI_YUBIN_NOBC := VJIDO_YUBIN_NOBC;
            ATESAKI_CHOMEI     := VJIDO_CHOMEI;
            ATESAKI_BANCHI     := VJIDO_BANCHI;
            ATESAKI_KATAGAKI   := VJIDO_KATAGAKI;
          ELSE
            ATESAKI_YUBIN_NO   := VYUBIN_NO;
            ATESAKI_YUBIN_NOBC := VYUBIN_NOBC;
            ATESAKI_CHOMEI     := VCHOMEI;
            ATESAKI_BANCHI     := VBANCHI;
            ATESAKI_KATAGAKI   := VKATAGAKI;
          END IF;
          r_CHOHYO_001.ATESAKI_YUBIN_NO := ATESAKI_YUBIN_NO;
          r_CHOHYO_001.BC_NO := ATESAKI_YUBIN_NOBC;
          r_CHOHYO_001.ATESAKI_CHOMEI_BANCHI := ATESAKI_CHOMEI || ATESAKI_BANCHI;
          r_CHOHYO_001.ATESAKI_KATAGAKI := ATESAKI_KATAGAKI;
          VTANTO_YAKUSHOKU_MEI := VACONSPRM2(2);
          VTANTO_SHUTHOU_MEI   := VACONSPRM2(3);
          VTANTO_RITSU_MEI     := VACONSPRM2(4);
          VTANTO_TEL_NAISEN    := VACONSPRM2(8);
          r_CHOHYO_001.YAKUSHOKU_MEI := VTANTO_YAKUSHOKU_MEI;
          r_CHOHYO_001.SHUCHO_MEI := VTANTO_SHUTHOU_MEI;
          r_CHOHYO_001.TANTO_RITSU_MEI := VTANTO_RITSU_MEI;
          r_CHOHYO_001.TANTO_TEL_NAISEN := VTANTO_TEL_NAISEN;
          NCHOHYO_NO2 := TRIM(RGAKUREIBO.CHOHYO_NO);
          NCHOHYO_NO2 := LPAD(NCHOHYO_NO2,5,' ');
          IF IGAKKO_CD IS NOT NULL THEN
            IGAKKO_CD2 := TRIM(TO_CHAR(IGAKKO_CD));
            IGAKKO_CD2 := LPAD(IGAKKO_CD2,5,' ');
          ELSE
            IGAKKO_CD2 := NULL;
          END IF;
          IF VACONSPRM3(1) = 0 THEN
            HYOJI_CHOHYO_NO := ' ';
          ELSIF VACONSPRM3(1) = 1 THEN
            HYOJI_CHOHYO_NO := NCHOHYO_NO2;
          ELSIF VACONSPRM3(1) = 2 THEN
            HYOJI_CHOHYO_NO := LTRIM(VGAKKO_MEI) || '-' || NCHOHYO_NO2;
          ELSIF VACONSPRM3(1) = 3 THEN
            HYOJI_CHOHYO_NO := IGAKKO_CD2 || '-' || NCHOHYO_NO2;
          ELSIF VACONSPRM3(1) = 4 THEN
            HYOJI_CHOHYO_NO := LTRIM(VGAKKO_MEI) || '-' || LTRIM(GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
          ELSIF VACONSPRM3(1) = 5 THEN
            HYOJI_CHOHYO_NO := IGAKKO_CD2 || '-' || LTRIM(GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
          ELSE
            HYOJI_CHOHYO_NO := ' ';
          END IF;
          r_CHOHYO_001.HYOJI_CHOHYO_NO := HYOJI_CHOHYO_NO;             --表示帳票連番
          KYOIKUKAI_RENRAKUSAKI := GET_EQRENRAKUSAKI(6, VACONSPRM2(1), VACONSPRM2(7), VACONSPRM2(8));
          r_CHOHYO_001.KYOIKU_RENRAKUSAKI := KYOIKUKAI_RENRAKUSAKI;    --教育委員会連絡先
          r_CHOHYO_001.BREAK_NO := NULL;                               --改ページキー
          r_CHOHYO_001.WSNUM := g_sWSNUM;                              --端末番号
          r_CHOHYO_001.BATCHKBN := c_ONLINE;                           --即時バッチ区分
          r_CHOHYO_001.JOBNUM := g_nJOBNUM;                            --ジョブNO
          
          INSERT INTO GKBWL080R001 VALUES r_CHOHYO_001;
          -- 一意的なレコードなので複数回繰り返すことはないので脱出
          EXIT;
        END LOOP;
        -- カーソルを閉じる
        IF CGAKUREIBO%ISOPEN THEN
          CLOSE CGAKUREIBO;
        END IF;
        -- 例外エラー
      EXCEPTION
        -- 該当なし
        WHEN NO_DATA_FOUND THEN
          -- 該当なしは正常終了とする
          IFRET := c_ISUCCESS;
          -- カーソルが開いていたらクローズ
          IF CGAKUREIBO%ISOPEN THEN
            CLOSE CGAKUREIBO;
          END IF;
        -- その他
        WHEN OTHERS THEN
          IFRET := c_INOT_SUCCESS;
          -- カーソルが開いていたらクローズ
          IF CGAKUREIBO%ISOPEN THEN
            CLOSE CGAKUREIBO;
          END IF;
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/08
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
        
          BEGIN
            -- エラーコードの初期化
            o_NSQLCODE := 0;
            -- エラーメッセージの初期化
            o_VSQLMSG := '';
          -- 宛先の氏名出力制御を取得
            ISIMEYISYUTURYOKUSEGYO     := KKAPK0030.FPRMSHUTOKU('GKB','00ATENA',5,VACONSPRM1,NLENGTH1);
            IF ISIMEYISYUTURYOKUSEGYO = 1 THEN
                          VACONSPRM1 := A_CONS_PRM();
                          VACONSPRM1.EXTEND;
                          VACONSPRM1.EXTEND;
                          VACONSPRM1(1) := 0;
                          VACONSPRM1.EXTEND;
                          VACONSPRM1(2) := 0;
                          VACONSPRM1.EXTEND;
                          VACONSPRM1(3) := 0;
                          VACONSPRM1.EXTEND;
                          VACONSPRM1(4) := 0;
            ELSE
              WHILE (NLENGTH1 < 4) LOOP
                VACONSPRM1.EXTEND;
                VACONSPRM1(NLENGTH1+1) := 0;
                NLENGTH1 := NLENGTH1 + 1;
              END LOOP;
            END IF;
            IRTN := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,o_SHIMEIPRM,o_LENGTH);
            IF IRTN  = 1 THEN
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
              o_SHIMEIPRM.EXTEND;
              o_SHIMEIPRM(6) := 0;
              o_SHIMEIPRM.EXTEND;
              o_SHIMEIPRM(7) := 0;
            ELSE
              WHILE (o_LENGTH < 8) LOOP   
                o_SHIMEIPRM.EXTEND;
                o_SHIMEIPRM(o_LENGTH+1) := 0;
                o_LENGTH := o_LENGTH + 1;
              END LOOP;
            END IF;
          -- 教育委員会情報を取得
          IKYOUIKUIINKAIJOUHOU       := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',g_NIINKAI,VACONSPRM2,NLENGTH2);
            IF IKYOUIKUIINKAIJOUHOU = 1 THEN
                          VACONSPRM2 := A_CONS_PRM();
                          VACONSPRM2.EXTEND;
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(1) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(2) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(3) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(4) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(5) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(6) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(7) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(8) := ' ';
            ELSE
              WHILE (NLENGTH2 < 8) LOOP
                VACONSPRM2.EXTEND;
                VACONSPRM2(NLENGTH2+1) := ' ';
                NLENGTH2 := NLENGTH2 + 1;
              END LOOP;
            END IF;
          -- 帳票連番印字項目の制御を取得
          ICHOUHYOURENBANINZIKOUMOKU := KKAPK0030.FPRMSHUTOKU('GKB','00RENBAN',0,VACONSPRM3,NLENGTH3);
            IF ICHOUHYOURENBANINZIKOUMOKU = 1 THEN
                          VACONSPRM3 := A_CONS_PRM();
                          VACONSPRM3.EXTEND;
                          VACONSPRM3.EXTEND;
                          VACONSPRM3(1) := 0;
            ELSE
              WHILE (NLENGTH3 < 1) LOOP
                VACONSPRM3.EXTEND;
                VACONSPRM3(NLENGTH3+1) := 0;
                NLENGTH3 := NLENGTH3 + 1;
              END LOOP;
            END IF;
          IF TO_NUMBER(g_NHASSO_BI) = 0 THEN
            HASSOBI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
          ELSE
            HASSOBI := g_NHASSO_BI;
          END IF;
          ISAKUSEIBI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
          -- ＣＳＶ作成
          IRTN := FUNC_GET_JIDO_REC;
          IF IRTN <> c_ISUCCESS THEN
            RAISE ERR;
          END IF;
        EXCEPTION
          -- その他エラー
          WHEN OTHERS THEN
            -- SQL情報取得
            o_NSQLCODE := SQLCODE;
            o_VSQLMSG  := SUBSTR(SQLERRM, 1, 250);
            g_sMESSAGE := g_sMESSAGE || o_NSQLCODE || o_VSQLMSG;
            RAISE ERR;
        END;
        --帳票出力CSVの作成
        bRTN := FUNC_O20CSV(i_sGYOUMUCODE,'GKBWL080R001',i_sCHOHYOID);

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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/08
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
        o_sMESSAGE := g_VGYOMU_KOIN;
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
END GKBPA00070;
/
