CREATE OR REPLACE PACKAGE BODY GKBPB00140
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 学校区別人数集計表作成
--  機能概要      : 学校区別人数集計表を作成する。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
--------------------------------------------------------
IS
    -- 全処理必須パラメータ
    c_BATCH                       CONSTANT PLS_INTEGER := 2;   --バッチ
    c_OK                          CONSTANT PLS_INTEGER := 0;   --正常
    c_ERR                         CONSTANT PLS_INTEGER := -1;  --異常
    g_nJOBNUM                     NUMBER;                      --ジョブナンバー
    g_sTANTOCODE                  CHAR(12);                    --担当者コード
    g_sWSNUM                      NVARCHAR2(63);               --端末番号
    g_nSAKUHYOLOGSEQ              NUMBER := 0;                 --作表ログ連番
    g_nUPDLOGSEQ                  NUMBER := 0;                 --更新ログ連番
    g_sMESSAGE                    NVARCHAR2(4000);             --メッセージ返却用
    g_rJSTP                       KKBTJSTP%ROWTYPE;            --バッチジョブステップ情報
    g_sSHORIID                    KKBTJCTL.SHORIID%TYPE;       --処理ID
    g_sGYOUMUCODE                 NVARCHAR2(3);                --業務コード
    g_oKENSU_LIST                 GKBEKENSU_LIST := GKBEKENSU_LIST();

    g_nTIME NUMBER;  --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --パラメータ変数
    --条件
    g_vJYOUKEN1  NVARCHAR2(500);
    g_vJYOUKEN2  NVARCHAR2(500);
    --------------------------------------------------------------------
    --  定数宣言
    --------------------------------------------------------------------
    c_BERROR          CONSTANT BOOLEAN       := FALSE;
    c_BNORMALEND      CONSTANT BOOLEAN       := TRUE;
    c_VGAKUREIBO      CONSTANT NVARCHAR2(15) := '学齢簿';            -- 業務区分
    c_VJUKI           CONSTANT NVARCHAR2(15) := '住民記録';          -- 業務区分
    --------------------------------------------------------------------
    --  変数宣言
    --------------------------------------------------------------------
    -- 処理条件の取得用変数
    ISAKUSEI_KBN                PLS_INTEGER;        -- 作成区分
    ISHUKEI_KBN                 PLS_INTEGER;        -- 集計区分
    -- 集計用変数
    BRTN                        BOOLEAN;            -- ステータス
    ISAKUSEIBI                  PLS_INTEGER := 0;   -- 作成日
    VSAKUSEIBI                  NVARCHAR2(15);      -- 表示用作成日
    VGYOMU                      NVARCHAR2(15);      -- 業務区分
    IGAKO_CD                    PLS_INTEGER := 0;   -- 学校区コード
    VGAKOMEI                    NVARCHAR2(60);      -- 学校区
    IGAKUNEN                    PLS_INTEGER := 0;   -- 学年
    VGAKUNEN                    NVARCHAR2(30);      -- 表示用学年
    ISANTEIDANTAI_CD            PLS_INTEGER := 0;   -- 算定団体コード
    ISHOCHU_KBN                 PLS_INTEGER := 0;   -- 小学中学区分
    ICNT_M                      PLS_INTEGER := 0;   -- 男性件数
    ICNT_W                      PLS_INTEGER := 0;   -- 女性件数
    ICNT_KEI                    PLS_INTEGER := 0;   -- 合計件数
    ICNT_REC                    PLS_INTEGER := 0;   -- 入力件数
    NSQLCODE                    NUMBER := 0;        -- エラーコード
    ICOUNT                      PLS_INTEGER := 0;   -- CSVカウント数

    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    io_IWAREKIHIZUKE            PLS_INTEGER := 0;
    io_ISEIREKIHIZUKE           PLS_INTEGER := 0;
    o_VEDIT_GYYMMDD1            NVARCHAR2(16);
    o_VEDIT_GYYMMDD2            NVARCHAR2(16);
    o_VEDIT_GYYMMDD3            NVARCHAR2(16);
    o_VKJ_GENGO                 NVARCHAR2(16);
    o_VKG_GENGO                 NVARCHAR2(16);
    o_IWAREKI_YY                PLS_INTEGER;
    o_ISEIREKI_YYYY             PLS_INTEGER;
    o_IWAREKI_GYYMM             PLS_INTEGER;
    o_IMM                       PLS_INTEGER;
    o_IDD                       PLS_INTEGER;
    o_IWAREKIHIZUKE             PLS_INTEGER;
    o_ISEIREKIHIZUKE            PLS_INTEGER;

    -- 稼動ユーザー情報
    o_IUSER_ID                  PLS_INTEGER;
    o_IGAPPEI_BI                PLS_INTEGER;
    o_IJICHI_CD                 PLS_INTEGER;
    o_IUSER_KBN                 PLS_INTEGER;
    o_VKENMEI                   NVARCHAR2(1000);
    o_VGUNSHIMEI                NVARCHAR2(1000);
    o_VUSERMEI                  NVARCHAR2(1000);
    o_VSHUCHOMEI                NVARCHAR2(1000);
    o_VSHUNYUNINSHOBUN          NVARCHAR2(1000);
    o_VYUBIN_NO                 NVARCHAR2(1000);
    o_VSHOZAICHI                NVARCHAR2(1000);
    o_VTEL_NO                   NVARCHAR2(1000);

    -- 学齢簿カーソル
    CURSOR CGAKUREIBO( p_ISHUKEI_KBN IN PLS_INTEGER ) IS
    SELECT G.SYOGAKO_CD AS GAKO_CD,
           L.GAKUNEN_CD,
           A.SEIBETSU
      FROM GABTATENAKIHON  A,
           GKBTGAKUNENLNK  L,
           GKBTGAKUREIBO   G
     WHERE p_ISHUKEI_KBN  = 0
       AND G.SAISHIN_KBN  = 0
       AND G.GEN_NENGAPI  = 0
       AND G.KUIKIGAI_CD  = 0  
       AND G.YOGOGAKO_CD  = 0  
       AND L.GAKUNEN_CD   BETWEEN 1 AND 6
       AND L.KOJIN_NO     = G.KOJIN_NO
       AND A.KOJIN_NO     = G.KOJIN_NO
     UNION ALL
    SELECT G.TYUGAKO_CD AS GAKO_CD,
           L.GAKUNEN_CD,
           A.SEIBETSU
      FROM GABTATENAKIHON  A,
           GKBTGAKUNENLNK  L,
           GKBTGAKUREIBO   G
     WHERE p_ISHUKEI_KBN  = 1
       AND G.SAISHIN_KBN  = 0
       AND G.GEN_NENGAPI  = 0
       AND G.KUIKIGAI_CD  = 0  
       AND G.YOGOGAKO_CD  = 0  
       AND L.GAKUNEN_CD   BETWEEN 7 AND 9
       AND L.KOJIN_NO     = G.KOJIN_NO
       AND A.KOJIN_NO     = G.KOJIN_NO
     ORDER BY GAKO_CD, GAKUNEN_CD;
     
    -- 住記異動カーソル
    CURSOR CJUKI( p_IKIJUNBI IN PLS_INTEGER ) IS
    SELECT 0 AS SHOCHU_KBN,
           J.SHOGAKU_CD AS GAKO_CD,
           J.SEINENGAPI,
           J.SEIBETSU,
           J.SANTEIDANTAI_CD
      FROM GABTJUKIIDO J
     WHERE J.GENZON_KBN = 0
       AND J.SEINENGAPI >= (p_IKIJUNBI + 30000)
     UNION ALL
    SELECT 1 AS SHOCHU_KBN,
           J.CHUGAKU_CD AS GAKO_CD,
           J.SEINENGAPI,
           J.SEIBETSU,
           J.SANTEIDANTAI_CD
      FROM GABTJUKIIDO J
     WHERE J.GENZON_KBN = 0
       AND J.SEINENGAPI BETWEEN p_IKIJUNBI AND (p_IKIJUNBI + 30000 - 1)
     ORDER BY SHOCHU_KBN, GAKO_CD, SEINENGAPI DESC;

    --------------------------------------------------------
    --  機能概要      : 処理ログ出力
    --  パラメータ    : i_vSTEP_NANE       処理単位に任意に付したステップ名
    --                : i_nJOHOKBN         ステータス（0:正常,1:異常）
    --                : i_sSQLCODE         異常ログ出力時のSQLCODE
    --                : i_sSQLERRM         異常ログ出力時のSQLERRM
    --                : i_sLOGMSG          エラーログとして出力する文字列
    --                : i_TANTOCODE        担当者コード
    --                : i_WSNUM            端末番号
    --                : i_nSHORIKBN        処理区分（1：作表処理, 2：更新処理, 0：カスタマイズログ内容）
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_SETLOG(i_sSTEP_NAME IN  NVARCHAR2,
                         i_nJOHOKBN   IN  NUMBER,
                         i_sSQLCODE   IN  NVARCHAR2,
                         i_sSQLERRM   IN  NVARCHAR2,
                         i_sLOGMSG    IN  NVARCHAR2,
                         i_TANTOCODE  IN  NVARCHAR2,
                         i_WSNUM      IN  NVARCHAR2,
                         i_nSHORIKBN  IN  NUMBER DEFAULT 0) RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;          --戻り値
        sSTEP_NAME                    NVARCHAR2(100);   --ステップ名
        sLOGMSG                       NVARCHAR2(1000);  --エラーログ
    BEGIN
        IF i_nSHORIKBN = 1 THEN
            sSTEP_NAME := i_sSTEP_NAME || g_nSAKUHYOLOGSEQ;
            sLOGMSG := i_sLOGMSG;
        ELSIF i_nSHORIKBN = 2 THEN
            sSTEP_NAME := i_sSTEP_NAME || g_nUPDLOGSEQ;
            sLOGMSG := i_sLOGMSG;
        ELSIF i_nSHORIKBN = 0 THEN
            sSTEP_NAME := i_sSTEP_NAME;
            sLOGMSG := i_sLOGMSG;
        ELSE
            NULL;
        END IF;

        --ログ出力
        bRTN := KKBPK5551.FSETBLOG (g_nJOBNUM,
                                    sSTEP_NAME,
                                    i_nJOHOKBN,
                                    i_sSQLCODE,
                                    i_sSQLERRM,
                                    sLOGMSG,
                                    i_TANTOCODE,
                                    i_WSNUM);
        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_SETLOG;
    --------------------------------------------------------
    --  機能概要      : バッチ初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_B00INIT
        RETURN BOOLEAN
    IS
        bRTN          BOOLEAN;           --戻り値
        rJCTL         KKBTJCTL%ROWTYPE;  --バッチジョブ情報
    BEGIN
        --初期処理
        bRTN := KKBPK5551.INITIAL (g_nJOBNUM);
        --バッチパラメータ取得
        bRTN := KKBPK5551.FJCTLGet (g_nJOBNUM, rJCTL);
        g_sTANTOCODE := rJCTL.LOGIN_TANTOCODE;  --担当者コード
        g_sWSNUM     := rJCTL.LOGIN_WSNUM;      --端末番号
        g_sSHORIID   := rJCTL.SHORIID;          --処理ID
        g_sGYOUMUCODE   := rJCTL.GYOUMUCODE;    --業務コード

        g_nTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));--時分秒

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B00INIT;
    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        v_cmbSakuseiKbn              DBMS_UTILITY.MAXNAME_ARRAY;
        v_cmbJuKiGakkokuShukeiKbn    DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        -- 作成区分
        v_cmbSakuseiKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbSakuseiKbn');
        g_vJYOUKEN1              := v_cmbSakuseiKbn(1);
        -- 住記学校区集計区分
        v_cmbJuKiGakkokuShukeiKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbJuKiGakkokuShukeiKbn');
        g_vJYOUKEN2              := v_cmbJuKiGakkokuShukeiKbn(1);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B01PINIT;
    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得（帳票）
    --  パラメータ    : i_STEPSEQ     バッチジョブステップ連番
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_B02PINIT(i_STEPSEQ IN NUMBER)
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;  --戻り値
    BEGIN
        --ステップ情報クリア
        g_rJSTP := NULL;
        --ステップ情報の取得
        bRTN := KKBPK5551.FJSTPGet (g_nJOBNUM, i_STEPSEQ, g_rJSTP);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B02PINIT;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
    BEGIN
        --ジョブナンバーをセット

        g_nJOBNUM := i_nJOBNUM;

        --バッチ初期処理
        bRTN := FUNC_B00INIT;
        IF NOT bRTN THEN
            o_vRESULT := g_sMESSAGE;
            RETURN;
        END IF;

        -- バッチ入力値取得
        bRTN := FUNC_B01PINIT;

    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
    --------------------------------------------------------
    --  機能概要      : バッチジョブステップテーブルの更新処理
    --  パラメータ    : i_UPD_KBN       更新区分
    --                : i_STEPRTNCODE   実行結果コード
    --                : i_CSV_RCNT      CSV出力件数
    --                : i_CSVFILENAME   CSVファイル名
    --                : i_PRTFILENAME   出力ファイル名
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    PROCEDURE PROC_JSTPSTAUTSUPD(i_UPD_KBN     IN  NUMBER,
                                 i_STEPRTNCODE IN  NUMBER DEFAULT 0,
                                 i_CSV_RCNT    IN  NUMBER DEFAULT 0,
                                 i_CSVFILENAME IN  NVARCHAR2 DEFAULT '',
                                 i_PRTFILENAME IN  NVARCHAR2 DEFAULT '')
    IS
        bRTN                          BOOLEAN;                  --戻り値
        aCOLNAME_TBL                  KKBPK5551.tyCOLNAME_Tbl;  --テーブル項目名リスト
    BEGIN
        --開始状態
        IF i_UPD_KBN = 1 THEN
            aCOLNAME_TBL := KKBPK5551.tyCOLNAME_Tbl ('STEPSTARTTIME');
            g_rJSTP.STEPSTARTTIME := TO_CHAR (SYSTIMESTAMP, 'YYYY/MM/DD HH24:MI:SS.FF3');
            bRTN := KKBPK5551.FJSTPPut (g_rJSTP, aCOLNAME_TBL);
        --終了状態
        ELSIF i_UPD_KBN = 2 THEN
            aCOLNAME_TBL := KKBPK5551.tyCOLNAME_Tbl ('STEPENDTIME', 'STEPRTNCODE');
            g_rJSTP.STEPENDTIME := TO_CHAR (SYSTIMESTAMP, 'YYYY/MM/DD HH24:MI:SS.FF3');
            g_rJSTP.STEPRTNCODE := i_STEPRTNCODE;
            bRTN := KKBPK5551.FJSTPPut (g_rJSTP, aCOLNAME_TBL);
        --ＣＳＶ出力状態
        ELSIF i_UPD_KBN = 3 THEN
            aCOLNAME_TBL := KKBPK5551.tyCOLNAME_Tbl ('SHORIRECCNT', 'CSVFILENAME', 'PRTFILENAME');
            g_rJSTP.SHORIRECCNT := i_CSV_RCNT;
            g_rJSTP.CSVFILENAME := i_CSVFILENAME;
            g_rJSTP.PRTFILENAME := i_PRTFILENAME;
            bRTN := KKBPK5551.FJSTPPut (g_rJSTP, aCOLNAME_TBL);
        --その他
        ELSE
            NULL;
        END IF;
    END PROC_JSTPSTAUTSUPD;
    --------------------------------------------------------
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_B11CSV(i_TBLNAME IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;          --戻り値
        nCSV_RCNT                     NUMBER;           --CSVファイル出力件数
        sCSVFILENAME                  NVARCHAR2(1000);  --CSVファイル名
        sPRTFILENAME                  NVARCHAR2(1000);  --印刷ファイル名
    BEGIN
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        --CSV出力処理
        bRTN := KKBPK5551.FCSVPUT (g_nJOBNUM,
                                   g_sGYOUMUCODE,
                                   g_sWSNUM,
                                   c_BATCH,
                                   i_TBLNAME,
                                   g_rJSTP.CHOHYOID,
                                   g_rJSTP.CHOHYOFORM,
                                   g_rJSTP.PRTFILEKBN,
                                   g_rJSTP.TEIKEIBUNNUM_LIST,
                                   nCSV_RCNT,
                                   sCSVFILENAME,
                                   sPRTFILENAME);

        --バッチジョブステップ情報を更新
        PROC_JSTPSTAUTSUPD (3, 0, nCSV_RCNT, sCSVFILENAME, sPRTFILENAME);

        --関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_B11CSV;
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
        FOR i in 1..g_oKENSU_LIST.COUNT LOOP
            bRTN:= KKBPK5551.FSETCNT(
                                     g_nJOBNUM,                  --ジョブナンバー
                                     i,                          --件数連番
                                     g_oKENSU_LIST(i).NAIYOU,    --件数名称
                                     g_oKENSU_LIST(i).KBN,       --件数区分
                                     g_oKENSU_LIST(i).CNT,       --件数
                                     g_sTANTOCODE,               --担当者コード
                                     g_sWSNUM                    --端末番号
                                     );
            IF NOT bRTN THEN
              RAISE eEXCEPTION;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END PROC_KENSUSET;

    --------------------------------------------------------------------
    --  日付和暦変換（平成○年○月○日）
    --------------------------------------------------------------------
    FUNCTION FUNC_WAREKI_HENKAN( i_ISEIREKI IN PLS_INTEGER ) RETURN NVARCHAR2 IS
      BRTN   BOOLEAN;
    BEGIN
      io_ISEIREKIHIZUKE := i_ISEIREKI;
      io_IWAREKIHIZUKE  := NULL;
      BRTN := KKAPK0020.FDAYEDIT( io_IWAREKIHIZUKE,
                                   io_ISEIREKIHIZUKE,
                                   o_VEDIT_GYYMMDD1,
                                   o_VEDIT_GYYMMDD2,
                                   o_VEDIT_GYYMMDD3,
                                   o_VKJ_GENGO,
                                   o_VKG_GENGO,
                                   o_IWAREKI_YY,
                                   o_ISEIREKI_YYYY,
                                   o_IWAREKI_GYYMM,
                                   o_IMM,
                                   o_IDD,
                                   o_IWAREKIHIZUKE,
                                   o_ISEIREKIHIZUKE );
      RETURN O_VEDIT_GYYMMDD3;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_WAREKI_HENKAN;

    --------------------------------------------------------------------
    --  初期処理
    --------------------------------------------------------------------
    PROCEDURE PROC_INITIAL( o_BRTN OUT BOOLEAN ) IS
    BEGIN
      ISAKUSEI_KBN := NVL(g_vJYOUKEN1, 0);        -- 作成区分
      ISHUKEI_KBN  := NVL(g_vJYOUKEN2, 0);        -- 集計区分
      -- 業務区分
      IF ISAKUSEI_KBN = 0 THEN
        VGYOMU := c_VGAKUREIBO;
      ELSIF ISAKUSEI_KBN = 1 THEN
        VGYOMU := c_VJUKI;
      END IF;
      ISAKUSEIBI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));  -- 作成日
      VSAKUSEIBI := FUNC_WAREKI_HENKAN( ISAKUSEIBI );         -- 表示用作成日
      o_BRTN     := c_BNORMALEND;
    END PROC_INITIAL;

    --------------------------------------------------------------------
    --  稼働ユーザー情報取得
    --------------------------------------------------------------------
    PROCEDURE PROC_GET_KYOTSU( i_IKIJYUNBI IN  PLS_INTEGER,
                               o_BRTN      OUT BOOLEAN ) IS
      IRTN PLS_INTEGER;
    BEGIN
      -- 稼動ユーザ情報取得
      IRTN := KKAPK0030.FKYOTU( i_IKIJYUNBI,
                                 o_IUSER_ID,
                                 o_IJICHI_CD,
                                 o_IGAPPEI_BI,
                                 o_IUSER_KBN,
                                 o_VGUNSHIMEI,
                                 o_VUSERMEI,
                                 o_VSHUCHOMEI,
                                 o_VKENMEI,
                                 o_VSHUNYUNINSHOBUN,
                                 o_VYUBIN_NO,
                                 o_VSHOZAICHI,
                                 o_VTEL_NO);
      IF IRTN = 0 THEN
        o_BRTN := c_BNORMALEND;
      ELSE
        BRTN   := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'PROC_GET_KYOTSU', 1, '', '', SUBSTR('稼動ユーザー情報の取得が異常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        o_BRTN := c_BERROR;
      END IF;
    END PROC_GET_KYOTSU;

    --------------------------------------------------------------------
    --  学校区名取得
    --------------------------------------------------------------------
    FUNCTION FUNC_GET_GAKOMEI( i_ISHUKEI_KBN IN  PLS_INTEGER,
                               i_IGAKO_CD    IN  PLS_INTEGER ) RETURN NVARCHAR2 IS
      VGAKOMEI  NVARCHAR2(60);
    BEGIN
      IF i_ISHUKEI_KBN = 0 THEN     -- 小学校
        SELECT SYOGAKOMEI
          INTO VGAKOMEI
          FROM GKBTSHOGAKKO
         WHERE SYOGAKO_CD = i_IGAKO_CD;
      ELSIF i_ISHUKEI_KBN = 1 THEN  -- 中学校
        SELECT TYUGAKOMEI
          INTO VGAKOMEI
          FROM GKBTCHUGAKKO
         WHERE TYUGAKO_CD = i_IGAKO_CD;
      END IF;
      RETURN VGAKOMEI;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_GET_GAKOMEI;

    --------------------------------------------------------------------
    --  学年編集
    --------------------------------------------------------------------
    FUNCTION FUNC_EDIT_GAKUNEN( i_ISHUKEI_KBN IN  PLS_INTEGER,
                                i_IGAKUNEN    IN  PLS_INTEGER ) RETURN NVARCHAR2 IS
      VGAKUNEN  NVARCHAR2(30);
    BEGIN
      IF i_ISHUKEI_KBN = 0 THEN      -- 小学校
        VGAKUNEN := '小学' || KKAPK0010.FMULTIBYTEHENKAN( i_IGAKUNEN,1 ) || '年生';
      ELSIF i_ISHUKEI_KBN = 1 THEN   -- 中学校
        VGAKUNEN := '中学' || KKAPK0010.FMULTIBYTEHENKAN( i_IGAKUNEN - 6,1 ) || '年生';
      END IF;
      RETURN VGAKUNEN;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_EDIT_GAKUNEN;

    --------------------------------------------------------------------
    --  学校区名取得（住記）
    --------------------------------------------------------------------
    FUNCTION FUNC_GET_GAKOMEI_JUKI( i_ISHOCHU_KBN       IN  PLS_INTEGER,
                                    i_IGAKO_CD          IN  PLS_INTEGER,
                                    i_ISANTEIDANTAI_CD  IN  PLS_INTEGER ) RETURN NVARCHAR2 IS
      VGAKOMEI          NVARCHAR2(60);
      ISANTEIDANTAI_CD  PLS_INTEGER;
    BEGIN
      -- 算定団体コード
      If ISAKUSEIBI >= o_IGAPPEI_BI THEN
        ISANTEIDANTAI_CD := 1;
      ELSE
        ISANTEIDANTAI_CD := i_ISANTEIDANTAI_CD;
      END IF;
      IF i_ISHOCHU_KBN = 0 THEN     -- 小学校
        VGAKOMEI := GAAPK0030.FSHOGAKUMEI( ISANTEIDANTAI_CD, i_IGAKO_CD );
      ELSIF i_ISHOCHU_KBN = 1 THEN  -- 中学校
        VGAKOMEI := GAAPK0030.FCHUGAKUMEI( ISANTEIDANTAI_CD, i_IGAKO_CD );
      END IF;
      RETURN VGAKOMEI;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_GET_GAKOMEI_JUKI;

    --------------------------------------------------------------------
    --  学年編集（住記）
    --------------------------------------------------------------------
    FUNCTION FUNC_EDIT_GAKUNEN_JUKI( i_IKIJUNBI     IN  PLS_INTEGER,
                                     i_ISEINENGAPI  IN  PLS_INTEGER ) RETURN NVARCHAR2 IS
      VGAKUNEN  NVARCHAR2(30);
      INENREI   PLS_INTEGER;
    BEGIN
      -- 年齢算出
      IF i_ISEINENGAPI = 0 THEN
        INENREI := NULL;
      ELSE
        INENREI := KKAPK0020.FAgeGet( TO_CHAR(i_ISEINENGAPI), TO_CHAR(i_IKIJUNBI) );
      END IF;
      -- 学年編集
      IF INENREI >= 0 AND INENREI <= 6 THEN
        VGAKUNEN := KKAPK0010.FMULTIBYTEHENKAN( INENREI,1 ) || '歳';
      ELSIF INENREI >= 7 AND INENREI <= 12 THEN
        VGAKUNEN := '小学' || KKAPK0010.FMULTIBYTEHENKAN( INENREI - 6,1 ) || '年生';
      ELSIF INENREI >= 13 AND INENREI <= 15 THEN
        VGAKUNEN := '中学' || KKAPK0010.FMULTIBYTEHENKAN( INENREI - 12,1 ) || '年生';
      END IF;
      RETURN VGAKUNEN;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_EDIT_GAKUNEN_JUKI;

    --------------------------------------------------------------------
    --  CSVファイル出力用のWK表を作成
    --------------------------------------------------------------------
    PROCEDURE PROC_OUT_CSV(iROWNO IN NUMBER, o_BRTN OUT BOOLEAN ) IS
      BRTN BOOLEAN;
      r_WKRECORD001 GKBWL260R001%ROWTYPE;
    BEGIN
      
      r_WKRECORD001 := NULL;
      r_WKRECORD001.NO         := iROWNO;      --ソート順
      r_WKRECORD001.GYOMU      := VGYOMU;      --業務区分
      r_WKRECORD001.GAKKOKU_CD := IGAKO_CD;    --学校区コード
      r_WKRECORD001.GAKKOKU    := VGAKOMEI;    --学校区
      r_WKRECORD001.KIJUNBI    := VSAKUSEIBI;  --基準日
      r_WKRECORD001.GAKUNEN    := VGAKUNEN;    --年齢学年
      r_WKRECORD001.CNT_WOMEN  := ICNT_W;      --女性件数
      r_WKRECORD001.CNT_MEN    := ICNT_M;      --男性件数
      r_WKRECORD001.KEI        := ICNT_KEI;    --合計件数
      r_WKRECORD001.BREAK_NO   := NULL;        --改ページキー
      r_WKRECORD001.WSNUM      := g_sWSNUM;    --端末番号
      r_WKRECORD001.BATCHKBN   := c_BATCH;     --バッチ区分
      r_WKRECORD001.JOBNUM     := g_nJOBNUM;   --ジョブNO

      INSERT INTO GKBWL260R001 VALUES r_WKRECORD001;
      BRTN := c_BNORMALEND;
    EXCEPTION
      WHEN OTHERS THEN
        NSQLCODE := SQLCODE;
        ROLLBACK;
        BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'PROC_OUT_CSV', 1, SQLCODE, SQLERRM, SUBSTR('CSVデータ作成が異常終了しました。' || SQLERRM(NSQLCODE), 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        o_BRTN := c_BERROR;
    END PROC_OUT_CSV;

    --------------------------------------------------------------------
    --  学齢簿情報取得
    --------------------------------------------------------------------
    PROCEDURE PROC_GET_GAKUREIBO( o_BRTN OUT BOOLEAN ) IS
      BRTN BOOLEAN;
    BEGIN
      BRTN := c_BNORMALEND;
      ICOUNT := 0;

      FOR CRGAKUREIBO IN CGAKUREIBO( ISHUKEI_KBN ) LOOP
        ICNT_REC := ICNT_REC + 1;
        IF ICNT_REC > 1 AND
          (IGAKO_CD <> CRGAKUREIBO.GAKO_CD  OR
           IGAKUNEN <> CRGAKUREIBO.GAKUNEN_CD) THEN
          -- 学校区名取得
          VGAKOMEI := FUNC_GET_GAKOMEI( ISHUKEI_KBN, IGAKO_CD );
          -- 学年編集
          VGAKUNEN := FUNC_EDIT_GAKUNEN( ISHUKEI_KBN, IGAKUNEN );
          -- CSVファイル出力用のWK表を作成
          ICOUNT := ICOUNT + 1;
          PROC_OUT_CSV( ICOUNT, BRTN );
          EXIT WHEN BRTN = c_BERROR;
          ICNT_M   := 0;   -- 男性件数
          ICNT_W   := 0;   -- 女性件数
          ICNT_KEI := 0;   -- 合計件数
        END IF;
        IGAKO_CD := CRGAKUREIBO.GAKO_CD;      -- 学校区
        IGAKUNEN := CRGAKUREIBO.GAKUNEN_CD;   -- 学年
        IF CRGAKUREIBO.SEIBETSU = 1 THEN
          ICNT_M := ICNT_M + 1;   -- 男性件数
        ELSIF CRGAKUREIBO.SEIBETSU = 2 THEN
          ICNT_W := ICNT_W + 1;   -- 女性件数
        END IF;
        ICNT_KEI := ICNT_KEI + 1; -- 合計件数
      END LOOP;
      IF ICNT_REC > 0 THEN
        -- 学校区名取得
        VGAKOMEI := FUNC_GET_GAKOMEI( ISHUKEI_KBN, IGAKO_CD );
        -- 学年編集
        VGAKUNEN := FUNC_EDIT_GAKUNEN( ISHUKEI_KBN, IGAKUNEN );
        -- CSVファイル出力用のWK表を作成
        ICOUNT := ICOUNT + 1;
        PROC_OUT_CSV( ICOUNT, BRTN );
      END IF;
      o_BRTN := BRTN;
    END PROC_GET_GAKUREIBO;

    --------------------------------------------------------------------
    --  住記情報取得
    --------------------------------------------------------------------
    PROCEDURE PROC_GET_JUKI( o_BRTN OUT BOOLEAN ) IS
      BRTN        BOOLEAN;
      INENDO      PLS_INTEGER := 0;   -- 年度
      IKIJUNBI    PLS_INTEGER := 0;   -- 抽出基準日
      IKIJUNBI_N  PLS_INTEGER := 0;   -- 年齢基準日
      VGAKUNEN_N  NVARCHAR2(30);      -- 表示用学年
    BEGIN
      BRTN       := c_BNORMALEND;
      ICOUNT     := 0;
      INENDO     := KKAPK0020.FDAYNENDO( ISAKUSEIBI, 0 );   -- 年度
      IKIJUNBI   := (INENDO - 15) * 10000 + 402 ;         -- 抽出基準日
      IKIJUNBI_N := (INENDO + 1)  * 10000 + 331 ;         -- 年齢基準日
      FOR CRJUKI IN CJUKI( IKIJUNBI ) LOOP
        ICNT_REC := ICNT_REC + 1;
        -- 学年編集
        VGAKUNEN_N := FUNC_EDIT_GAKUNEN_JUKI( IKIJUNBI_N, CRJUKI.SEINENGAPI );
        IF ICNT_REC > 1 AND
          (IGAKO_CD <> CRJUKI.GAKO_CD  OR
           VGAKUNEN <> VGAKUNEN_N) THEN
          -- 学校区名取得（住記）
          VGAKOMEI := FUNC_GET_GAKOMEI_JUKI( ISHOCHU_KBN, IGAKO_CD, ISANTEIDANTAI_CD );
          -- CSVファイル出力用のWK表を作成
          ICOUNT := ICOUNT + 1;
          PROC_OUT_CSV( ICOUNT, BRTN );
          EXIT WHEN BRTN = c_BERROR;
          ICNT_M   := 0;   -- 男性件数
          ICNT_W   := 0;   -- 女性件数
          ICNT_KEI := 0;   -- 合計件数
        END IF;
        IGAKO_CD         := CRJUKI.GAKO_CD;          -- 学校区
        VGAKUNEN         := VGAKUNEN_N;              -- 学年
        ISANTEIDANTAI_CD := CRJUKI.SANTEIDANTAI_CD;  -- 算定団体コード
        ISHOCHU_KBN      := CRJUKI.SHOCHU_KBN;       -- 小学中学区分
        IF CRJUKI.SEIBETSU = 1 THEN
          ICNT_M := ICNT_M + 1;   -- 男性件数
        ELSIF CRJUKI.SEIBETSU = 2 THEN
          ICNT_W := ICNT_W + 1;   -- 女性件数
        END IF;
        ICNT_KEI := ICNT_KEI + 1; -- 合計件数
      END LOOP;
      IF ICNT_REC > 0 THEN
        -- 学校区名取得（住記）
        VGAKOMEI := FUNC_GET_GAKOMEI_JUKI( ISHOCHU_KBN, IGAKO_CD, ISANTEIDANTAI_CD );
        -- CSVファイル出力用のWK表を作成
        ICOUNT := ICOUNT + 1;
        PROC_OUT_CSV( ICOUNT, BRTN );
      END IF;
      o_BRTN := BRTN;
    END PROC_GET_JUKI;

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        eException       EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        
        -- 初期化
        DELETE FROM GKBWL260R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;

        -- 初期処理
        PROC_INITIAL( BRTN );
        IF BRTN = c_BERROR THEN
          RAISE eException;
        END IF;
        -- 稼動ユーザー情報取得
        PROC_GET_KYOTSU( ISAKUSEIBI, BRTN );
        IF BRTN = c_BERROR THEN
          RAISE eException;
        END IF;

        IF ISAKUSEI_KBN = 0 THEN
          -- 学齢簿情報取得
          PROC_GET_GAKUREIBO( BRTN );
          IF BRTN = c_BERROR THEN
            RAISE eException;
          END IF;
        ELSIF ISAKUSEI_KBN = 1 THEN
          -- 住記情報取得
          PROC_GET_JUKI( BRTN );
          IF BRTN = c_BERROR THEN
            RAISE eException;
          END IF;
        END IF;

        -- 帳票出力CSVの作成
        bRTN := FUNC_B11CSV('GKBWL260R001');

        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);

        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE;
    END FUNC_B10SAKUHYO1;
    --------------------------------------------------------
    --  機能概要      : 更新処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;  --戻り値
    BEGIN
        g_nUPDLOGSEQ := g_nUPDLOGSEQ + 1;
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 2);
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 2);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
    END FUNC_B20UPDATE1;
    --------------------------------------------------------
    --  機能概要      : バッチ処理の呼出
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_nRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    PROCEDURE PBATCH(i_nJOBNUM  IN  NUMBER,
                     o_nRESULT  OUT NUMBER)
    IS
        ePRMEXCEPTION                 EXCEPTION;                --パラメータ取得異常タイプ
        eSHORIEXCEPTION               EXCEPTION;                --処理異常タイプ
        bRTN                          BOOLEAN;                  --戻り値
        aSTEPSEQ_TBL                  KKBPK5551.tySTEPSEQ_Tbl;  --処理ステップ連番
        nSTEPSEQ_MAX                  NUMBER;                   --処理ステップレコード数

    BEGIN
        --戻り値
        o_nRESULT := c_OK;
        --ジョブナンバーをセット
        g_nJOBNUM := i_nJOBNUM;
        --バッチ初期処理
        bRTN := FUNC_B00INIT;
        IF NOT bRTN THEN
            RAISE ePRMEXCEPTION;
        END IF;
        --バッチ入力値取得
        bRTN := FUNC_B01PINIT;
        IF NOT bRTN THEN
            RAISE ePRMEXCEPTION;
        END IF;

        --処理ステップを取得
        bRTN := KKBPK5551.FJSTGetStep (g_nJOBNUM, aSTEPSEQ_TBL, nSTEPSEQ_MAX);
        g_nSTEP_MAX  := nSTEPSEQ_MAX;
        --処理ステップ連番が終了するまで繰り返す
        FOR i IN 1..nSTEPSEQ_MAX LOOP

            g_nSTEP_INDEX := i;
            --バッチステップ処理パラメータ取得
            bRTN := FUNC_B02PINIT (aSTEPSEQ_TBL(i));
            IF NOT bRTN THEN
                RAISE ePRMEXCEPTION;
            END IF;

            --バッチジョブステップ情報を更新
            PROC_JSTPSTAUTSUPD(1);
            --メイン処理
            CASE g_rJSTP.SHORIKBN
                WHEN 0 THEN
                    --作表処理
                    bRTN := FUNC_B10SAKUHYO1;
                    IF NOT bRTN THEN
                        o_nRESULT := c_ERR;
                    END IF;
                WHEN 1 THEN
                    --更新処理
                    bRTN := FUNC_B20UPDATE1;
                    IF NOT bRTN THEN
                        o_nRESULT := c_ERR;
                    END IF;
                ELSE
                    NULL;
            END CASE;
            --異常処理へ
            IF o_nRESULT <> 0 THEN
                RAISE eSHORIEXCEPTION;
            END IF;

            --バッチジョブステップ情報を更新
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);

        END LOOP;

        --件数表出力
        --PROC_KENSUSET;

        --終了処理
        bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
        COMMIT;

    EXCEPTION
        WHEN ePRMEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
        WHEN eSHORIEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
        WHEN OTHERS THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;

    END PBATCH;
END GKBPB00140;
/
