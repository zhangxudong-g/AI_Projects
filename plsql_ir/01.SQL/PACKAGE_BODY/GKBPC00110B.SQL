CREATE OR REPLACE PACKAGE BODY GKBPC00110
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 学級一括設定
--  機能概要      : 学級設定データ（CSVファイル）で、学齢簿に学級を一括設定する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
--------------------------------------------------------
--  変更履歴
--  2024/06/19 ZCZL.GUOXIAOZHU Update 0.3.000.000:新WizLIFE２次開発
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--  2024/12/27 JIP.Y.SATO Update 0.3.000.002:故障対応
--------------------------------------------------------
IS
    --全処理必須パラメータ
    c_BATCH                       CONSTANT PLS_INTEGER := 2;     --バッチ
    c_OK                          CONSTANT PLS_INTEGER := 0;     --正常
    c_ERR                         CONSTANT PLS_INTEGER := -1;    --異常
    g_nJOBNUM                     NUMBER;                        --ジョブナンバー
    g_sTANTOCODE                  CHAR(12);                      --担当者コード
    g_sWSNUM                      NVARCHAR2(63);                 --端末番号
    g_nSAKUHYOLOGSEQ              NUMBER := 0;                   --作表ログ連番
    g_nUPDLOGSEQ                  NUMBER := 0;                   --更新ログ連番
    g_sSHORIID                    NVARCHAR2(8);                  --処理ID
    g_sSHORISH                    NVARCHAR2(2);                  --処理種別
    g_sGYOUMUCODE                 NVARCHAR2(3);                  --業務コード
    g_sMESSAGE                    NVARCHAR2(4000);               --メッセージ返却用
    g_rJSTP                       KKBTJSTP%ROWTYPE;              --バッチジョブステップ情報
    --全域変数
    g_oKENSU_LIST                 GKBEKENSU_LIST := GKBEKENSU_LIST();
    g_nINDEX                      NUMBER         := 0;

    g_nTIME NUMBER;  --時分秒
--  2024/06/19 ZCZL.GUOXIAOZHU Add Start 0.3.000.000:新WizLIFE２次開発
       BHAITA_CHU                        BOOLEAN := FALSE;       --排他中
--  2024/06/19 ZCZL.GUOXIAOZHU Add end 
    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --パラメータ変数
    g_VJOKEN01                        NVARCHAR2(100);


    -- 変数宣言
    VTYOUHYOU_NAME                    NVARCHAR2(500);                    -- 変数.帳票名
    NDATASEQ                          NUMBER;                            -- 変数.ループ回数
    VSYSDATE                          NVARCHAR2(8);                      -- 変数.処理日にシステム日付
    NERR_LIST_RENBAN                  NUMBER;                            -- 変数.エラーリスト連番
    VSHORI_KUBUN                      NVARCHAR2(11);                     -- 変数.処理区分
    NWAREKIHIZUKEIN                   NUMBER :=0;                        -- 変数.和暦日付
    NSEIREKIHIZUKE                    NUMBER;                            -- 変数.西暦日付
    VEDIT_GYYMMDD3                    NVARCHAR2(20);                     -- 変数.編集後処理日
    ICOUNT                            PLS_INTEGER := 0;                  -- 変数.更新件数
    NRTN                              NUMBER;
    NRTN_G                            NUMBER;
    BRTN                              BOOLEAN;
    VLOG                              NVARCHAR2(256);                    -- ログ
    EEXCEPTION_G                      EXCEPTION;                         -- 異常
    BCSV_SHUTURYOKU                   BOOLEAN := FALSE;                  -- エラーリストCSVフラグ
    NERROR_KENSU                      NUMBER:= 0;                        -- 項目エラー件数
    --ダミー変数
    VDUMMY                            NVARCHAR2(500);
    IDUMMY                            PLS_INTEGER;
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
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
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
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
    --------------------------------------------------------
    FUNCTION FUNC_B00INIT RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;           --戻り値
        rJCTL                         KKBTJCTL%ROWTYPE;  --バッチジョブ情報
    BEGIN
        --初期処理
        bRTN := KKBPK5551.INITIAL (g_nJOBNUM);
        --バッチパラメータ取得
        bRTN := KKBPK5551.FJCTLGet (g_nJOBNUM, rJCTL);
        g_sTANTOCODE    := rJCTL.LOGIN_TANTOCODE;    --担当者コード
        g_sWSNUM        := rJCTL.LOGIN_WSNUM;        --端末番号
        g_sSHORIID      := rJCTL.SHORIID;            --処理ID
        g_sSHORISH      := rJCTL.SHORISH;            --処理種別
        g_sGYOUMUCODE   := rJCTL.GYOUMUCODE;         --業務コード
        g_nTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));--時分秒

        RETURN bRTN;
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
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT RETURN BOOLEAN
    IS
        v_optShoriKbn     DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        v_optShoriKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'optShoriKbn');
        g_VJOKEN01 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'optShoriKbn',0,v_optShoriKbn);
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
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
    --------------------------------------------------------
    FUNCTION FUNC_B02PINIT(i_STEPSEQ IN NUMBER) RETURN BOOLEAN
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
    --                : o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
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
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
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
            aCOLNAME_TBL := KKBPK5551.tyCOLNAME_Tbl('SHORIRECCNT', 'CSVFILENAME', 'PRTFILENAME');
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
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
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
    -------------------------------------------------------------------------------------
    -- ログ内容編集(最大256文字）
    -------------------------------------------------------------------------------------
    FUNCTION FUNC_GET_LOG(i_VLOG IN NVARCHAR2) RETURN NVARCHAR2
    IS
    BEGIN
        --出力するログ情報(最大256文字）
        RETURN SUBSTR( i_VLOG
                    ,0
                    ,256);
    END;
    -------------------------------------------------------------------------------------
    -- エラーになると、①Aのエラーリストへの更新処理を行う
    -------------------------------------------------------------------------------------
    PROCEDURE PROC_INS(io_NERROR_CD IN OUT NUMBER
                        ,io_NERR_LIST_RENBAN IN OUT NUMBER
                        ,io_BCSV_SHUTURYOKU IN OUT BOOLEAN
                        ,io_VERR_NAIYO IN OUT NVARCHAR2)
    IS
    BEGIN
        io_BCSV_SHUTURYOKU := TRUE;
        io_NERR_LIST_RENBAN := io_NERR_LIST_RENBAN + 1;
        io_NERROR_CD := io_NERROR_CD + 1;
        INSERT INTO GKBWHANYOERRLIST(SUB_TITLE
                                ,MIDASHI1
                                ,MIDASHI2
                                ,MIDASHI3
                                ,SHORIBI
                                ,HENSHU_SHORIBI
                                ,NUM
                                ,ERR_NAIYO
                                ,SAKUSEIBI
                                ,SYS_KOSHINBI
                                ,SYS_JIKAN
                                ,SYS_SHOKUINKOJIN_NO
                                ,SYS_TANMATSU_NO
                                )VALUES(
                                '学級一括設定処理エラーリスト'
                                ,NULL
                                ,NULL
                                ,NULL
                                ,VSYSDATE
                                ,VEDIT_GYYMMDD3
                                ,io_NERR_LIST_RENBAN
                                ,io_VERR_NAIYO
                                ,VSYSDATE
                                ,VSYSDATE
                                ,g_nTIME
                                ,g_sTANTOCODE
                                ,g_sWSNUM);
        io_VERR_NAIYO := '';

    END PROC_INS;
    -------------------------------------------------------------------------------------
    -- 1.初期処理
    -------------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JOKEN RETURN PLS_INTEGER
    IS
    BEGIN
        VLOG := FUNC_GET_LOG('処理条件取得が正常終了しました。');
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JOKEN', 0, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
        -- 1-1.変数の定義と編集
        BEGIN
            VTYOUHYOU_NAME     := '学級一括設定';
            NDATASEQ           := 0;                                            -- 変数.ループ回数 := 0
            VSYSDATE           := TO_CHAR(SYSDATE, 'YYYYMMDD');                 -- 変数.処理日にシステム日付（YYYYMMDD)に編集してセットする
            NERR_LIST_RENBAN   := 0;                                            -- 変数.エラーリスト連番 := 0
            VSHORI_KUBUN       := g_VJOKEN01;                                   -- 変数.処理区分 := 処理条件1.処理区分
            NSEIREKIHIZUKE     := TO_NUMBER(VSYSDATE);                          -- 変数.処理日西暦
            NRTN := KKAPK0020.FDAYEDIT2(NWAREKIHIZUKEIN
                                        ,NSEIREKIHIZUKE
                                        ,VDUMMY
                                        ,VDUMMY
                                        ,VEDIT_GYYMMDD3
                                        ,VDUMMY
                                        ,VDUMMY
                                        ,IDUMMY
                                        ,IDUMMY
                                        ,IDUMMY
                                        ,IDUMMY
                                        ,IDUMMY
                                        ,IDUMMY
                                        ,IDUMMY);
            VLOG := FUNC_GET_LOG('変数の定義と編集が正常終了しました。');
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JOKEN', 0, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
        EXCEPTION
            WHEN OTHERS THEN
            VLOG := FUNC_GET_LOG('変数の定義と編集で異常終了しました。');
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JOKEN', 1, SQLCODE, SQLERRM, VLOG, g_sTANTOCODE, g_sWSNUM, 1);
            RETURN 1;
        END;
        -- 1-2.汎用エラーワークの初期化
        BEGIN
            DELETE FROM GKBWHANYOERRLIST A
            WHERE A.SYS_SHOKUINKOJIN_NO = g_sTANTOCODE
            AND   A.SYS_TANMATSU_NO = g_sWSNUM;
        EXCEPTION
            WHEN OTHERS THEN
            RETURN 1;
        END;
        RETURN 0;
    EXCEPTION
        WHEN OTHERS THEN
        RETURN 1;
    END FUNC_GET_JOKEN;
    --------------------------------------------------------
    --  機能概要      : 即時帳票ワークテーブルからCSVファイル
    --  パラメータ      : なし
    --  モジュール区分  : 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン      : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
    --------------------------------------------------------
    FUNCTION FUNC_CREATE_CSV RETURN NUMBER IS
      N_RTN   NUMBER  :=  0;
      TYPE ref_CUR_DOUTAI IS REF CURSOR;
      C1              ref_CUR_DOUTAI;
      v_DOUTAISQL     NVARCHAR2(10000);
      CR1             GKBWHANYOERRLIST%ROWTYPE;
      r_WL460R001     GKBWL460R001%ROWTYPE;
      nROWNO          NUMBER;
    BEGIN
      BEGIN
        v_DOUTAISQL := 'SELECT * FROM GKBWHANYOERRLIST WHERE SYS_SHOKUINKOJIN_NO = ''' || g_sTANTOCODE || ''' AND  SYS_TANMATSU_NO = ''' || g_sWSNUM || '''';
        v_DOUTAISQL := v_DOUTAISQL || ' ORDER BY NUM ';  --2025/01/03 JIP.Y.SATO ADD
        nROWNO := 0;
        OPEN C1 FOR v_DOUTAISQL;
        LOOP
        FETCH C1 INTO CR1;
        EXIT WHEN C1%NOTFOUND;
          nROWNO                              := nROWNO+1;
          r_WL460R001                         := NULL;
          r_WL460R001.NO                      := nROWNO;                         --  ソート順
          r_WL460R001.SUB_TITLE               := CR1.SUB_TITLE;                  --  サブタイトル
          r_WL460R001.MIDASHI1                := CR1.MIDASHI1;                   --  見出し１
          r_WL460R001.MIDASHI2                := CR1.MIDASHI2;                   --  見出し２
          r_WL460R001.MIDASHI3                := CR1.MIDASHI3;                   --  見出し３
          r_WL460R001.HENSHU_SHORIBI          := NVL(CR1.SHORIBI , 0);           --  処理日選択項目
          r_WL460R001.SHORIBI                 := CR1.HENSHU_SHORIBI;             --  処理日
          r_WL460R001.NUM                     := NVL(CR1.NUM , 0);               --  Ｎｏ
          r_WL460R001.ERR_NAIYO               := CR1.ERR_NAIYO;                  --  エラー内容
          r_WL460R001.SAKUSEIBI               := NVL(CR1.SAKUSEIBI , 0);         --  作成日
          r_WL460R001.SYS_KOSHINBI            := NVL(CR1.SYS_KOSHINBI  , 0);     --  更新日
          r_WL460R001.SYS_JIKAN               := NVL(CR1.SYS_JIKAN , 0);         --  更新時間
          r_WL460R001.SYS_SHOKUINKOJIN_NO     := CR1.SYS_SHOKUINKOJIN_NO;        --  更新職員宛名番号
          r_WL460R001.SYS_TANMATSU_NO         := CR1.SYS_TANMATSU_NO;            --  更新端末番号
          r_WL460R001.BREAK_NO                := NULL;                           --  改ページキー
          r_WL460R001.WSNUM                   := g_sWSNUM;                       --  端末番号
          r_WL460R001.BATCHKBN                := c_BATCH;                        --  即時バッチ区分
          r_WL460R001.JOBNUM                  := g_nJOBNUM;                      --  ジョブNO
          INSERT INTO GKBWL460R001 VALUES r_WL460R001;
        END LOOP;
        IF C1%ISOPEN THEN
            CLOSE C1;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IF C1%ISOPEN THEN
            CLOSE C1;
          END IF;
          N_RTN:=1;
      END;
      RETURN(N_RTN);
    END FUNC_CREATE_CSV;
    -------------------------------------------------------------------------------------
    -- 2.排他処理
    -------------------------------------------------------------------------------------
--  2024/06/19 ZCZL.GUOXIAOZHU Add Start 0.3.000.000:新WizLIFE２次開発
    FUNCTION FUNC_GET_FKHTSET RETURN PLS_INTEGER
    IS
        bRTN                          BOOLEAN;    --戻り値
        NRTN                          NUMBER;
    BEGIN

        NRTN := GKBFKHTSET(2,'999999999999','全件',TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),g_sTANTOCODE,g_sWSNUM,g_nTIME);
        IF NRTN = 1 THEN
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, '排他がかかっているデータが存在するため、処理を実行できませんでした。', '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_FKHTSET', 1, '', '', '排他がかかっているデータが存在するため、処理を実行できませんでした。', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN 1;
        ELSIF NRTN <> 0 AND NRTN <> 1 THEN
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, '排他制御処理で異常終了しました。', '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_FKHTSET', 1, '', '', '排他制御処理で異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN 1;
        ELSE
            BHAITA_CHU := TRUE;
        END IF;     
        IF NRTN <> 0 THEN
            RETURN 1;
        END IF;
      RETURN 0;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 1;
    END FUNC_GET_FKHTSET;
--  2024/06/19 ZCZL.GUOXIAOZHU Add end 
    -------------------------------------------------------------------------------------
    -- 3.準備処理
    -------------------------------------------------------------------------------------
    FUNCTION FUNC_JUNBI_SHORI RETURN PLS_INTEGER
    IS
        VKOUMOKUMEI                 NVARCHAR2(500);                      -- 変数.エラー項目名
        NERROR_CD                   NUMBER;                              -- 変数.1件毎エラーカウント
        VERROR_MSG                  NVARCHAR2(200);                      -- 変数.1件毎エラーメッセージ
        VERR_NAIYO                  NVARCHAR2(500);                      -- 変数.エラー内容
        BKOJIN_NO_ERROR_FLG         BOOLEAN;                             -- 変数.宛名番号エラー有無フラグ
        BRIREKI_RENBAN_ERROR_FLG    BOOLEAN;                             -- 変数.履歴連番エラー有無フラグ
        BGAKKO_KBN_CD_ERROR_FLG     BOOLEAN;                             -- 変数.学校区分コードエラー有無フラグ
        BGAKKO_KBN_MEISHO_ERROR_FLG BOOLEAN;                             -- 変数.学校区分名称エラー有無フラグ
        BGAKKO_CD_ERROR_FLG         BOOLEAN;                             -- 変数.学校等コードエラー有無フラグ
        BGAKKO_MEISHO_ERROR_FLG     BOOLEAN;                             -- 変数.学校等名称エラー有無フラグ
        BGAKUNEN_CD_ERROR_FLG       BOOLEAN;                             -- 変数.学年コードエラー有無フラグ
        BGAKUNEN_MEISHO_ERROR_FLG   BOOLEAN;                             -- 変数.学年名称エラー有無フラグ
        BGAKUKYU_CD_ERROR_FLG       BOOLEAN;                             -- 変数.学級コードエラー有無フラグ
        BRIREKI_RENBAN_SAISHIN_FLG  BOOLEAN;                             -- 変数.履歴連番の最新フラグ
        BGAKKOU_JOUHOU_ITTI_FLG     BOOLEAN;                             -- 変数.学校情報の一致フラグ
        VKOYUKEY                    NVARCHAR2(50);                       -- 変数.固有キー
        NERROR_FLG                  NUMBER;                              -- 変数.エラー有無フラグ
        NSYOGAKO_CD                 NUMBER;                              -- 変数.小学校学校等コード
        VSYOGAKOMEI                 NVARCHAR2(500);                      -- 変数.小学校名
        NTYUGAKO_CD                 NUMBER;                              -- 変数.中学校学校等コード
        VTYUGAKOMEI                 NVARCHAR2(500);                      -- 変数.中学校名
        NYOGOGAKO_CD                NUMBER;                              -- 変数.別支援学校学校等コード
        VYOGOGAKOMEI                NVARCHAR2(500);                      -- 変数.別支援学校名
        NKUIKIGAI_CD                NUMBER;                              -- 変数.区域外学校学校等コード
        VKUIKIGAIMEI                NVARCHAR2(500);                      -- 変数.区域外学校名
--2024/06/19 ZCZL.GUOXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発
        NKUNISHIRITSUGAKKO_CD       NUMBER;                              -- 変数.国・私立学校等コード
        VKUNISHIRITSUGAKKOMEI       NVARCHAR2(500);                      -- 変数.国・私立学校名
        o_MGAKKO_CD                 NVARCHAR2(500);                      -- 文部科学省学校コード
        GAKUNENMEI                  NVARCHAR2(500);                      -- 義務教育学校学年名
--2024/06/19 ZCZL.GUOXIAOZHU Add end
        NGAKUNEN_CD                 NUMBER;                              -- 変数.学年コード
        VGAKUNENMEI                 NVARCHAR2(500);                      -- 変数.学年名
        NGAKUKYU_CD                 NUMBER;                              -- 変数.学級コード
        NGAKUREIBO_SAISHIN_KBN      NUMBER;                              -- 変数.学齢簿最新区分
        NGAKUREIBO_GAKKO_KBN_CD     NUMBER;                              -- 変数.学齢簿学校区分コード
        NGAKUREIBO_GAKO_CD          NUMBER;                              -- 変数.学齢簿学校等コード
        NGAKUREIBO_GAKUNEN_CD       NUMBER;                              -- 変数.学齢簿学年コード

        -- 2-1-2-1.アップロード済ワークデータのカーソル
        CURSOR CWK_GAKUKYU_SETTEI IS
            SELECT GKBWGAKUKYUSETTEI.KOJIN_NO
                    ,GKBWGAKUKYUSETTEI.RIREKI_RENBAN
--2024/06/19 ZCZL.GUOXIAOZHU Add 0.3.000.000:新WizLIFE２次開発
                    ,GKBWGAKUKYUSETTEI.RIREKI_RENBAN_EDA
                    ,GKBWGAKUKYUSETTEI.GAKKO_KBN_CD
                    ,GKBWGAKUKYUSETTEI.GAKKO_KBN_MEISHO
                    ,GKBWGAKUKYUSETTEI.GAKKO_CD
                    ,GKBWGAKUKYUSETTEI.GAKKO_MEISHO
                    ,GKBWGAKUKYUSETTEI.GAKUNEN_CD
                    ,GKBWGAKUKYUSETTEI.GAKUNEN_MEISHO
                    ,GKBWGAKUKYUSETTEI.GAKUKYU_CD
                    ,GKBWGAKUKYUSETTEI.GAKUKYU_MEISHO
            FROM  GKBWGAKUKYUSETTEI
            ORDER BY GAKKO_KBN_CD
                    ,GAKKO_CD
                    ,GAKUNEN_CD
                    ,GAKUKYU_CD
                    ,SHIMEI_KANA
                    ,SEINENGAPI;

        -- 小学校名（GKBTSHOGAKKO）
        CURSOR CSGKBTSHOGAKKO(p_GAKKO_CD IN NUMBER) IS
        SELECT GKBTSHOGAKKO.SYOGAKO_CD
                ,GKBTSHOGAKKO.SYOGAKOMEI
        FROM  GKBTSHOGAKKO
        WHERE  GKBTSHOGAKKO.SYOGAKO_CD = p_GAKKO_CD;

        -- 中学校名（GKBTCHUGAKKO）
        CURSOR CSGKBTCHUGAKKO(p_GAKKO_CD IN NUMBER) IS
        SELECT GKBTCHUGAKKO.TYUGAKO_CD
                ,GKBTCHUGAKKO.TYUGAKOMEI
        FROM GKBTCHUGAKKO
        WHERE GKBTCHUGAKKO.TYUGAKO_CD = p_GAKKO_CD;

        -- 盲聾養護学校名（GKBTYOGOGAKKO）
        CURSOR CSGKBTYOGOGAKKO(p_GAKKO_CD IN NUMBER) IS
        SELECT GKBTYOGOGAKKO.YOGOGAKO_CD
                ,GKBTYOGOGAKKO.YOGOGAKOMEI
        FROM GKBTYOGOGAKKO
        WHERE GKBTYOGOGAKKO.YOGOGAKO_CD = p_GAKKO_CD;

        -- 区域外学校名（GKBTKUIKIGAI）
        CURSOR CSGKBTKUIKIGAI(p_GAKKO_CD IN NUMBER) IS
        SELECT GKBTKUIKIGAI.KUIKIGAI_CD
                ,GKBTKUIKIGAI.KUIKIGAIMEI
        FROM GKBTKUIKIGAI
        WHERE GKBTKUIKIGAI.KUIKIGAI_CD = p_GAKKO_CD;
--2024/06/19 ZCZL.GUOXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発
        -- 国・私立学校名（GKBTKUNISIRITSUGAKKO）
        CURSOR CSGKBTKUNISIRITSUGAKKO(p_GAKKO_CD IN NUMBER) IS
        SELECT GKBTKUNISIRITSUGAKKO.KUNISHIRITSUGAKKO_CD
                ,GKBTKUNISIRITSUGAKKO.KUNISHIRITSUGAKKOMEI
        FROM GKBTKUNISIRITSUGAKKO
        WHERE GKBTKUNISIRITSUGAKKO.KUNISHIRITSUGAKKO_CD = p_GAKKO_CD;
--2024/06/19 ZCZL.GUOXIAOZHU Add end
        -- 学年テーブル（GKBTGAKUNEN）
        CURSOR CSGKBTGAKUNEN(p_GAKUNEN_CD IN NUMBER) IS
        SELECT GKBTGAKUNEN.GAKUNEN_CD
                ,GKBTGAKUNEN.GAKUNENMEI
        FROM GKBTGAKUNEN
        WHERE GKBTGAKUNEN.GAKUNEN_CD = p_GAKUNEN_CD;

        -- 学級マスタ（GKBTMSGAKUKYUCD）
        CURSOR CSGKCTSHIKYU(p_GAKKO_KBN_CD IN NUMBER
                        ,p_GAKKO_CD IN NUMBER
                        ,p_GAKUKYU_CD IN NUMBER) IS
        SELECT GKBTMSGAKUKYUCD.GAKUKYU_CD
        FROM GKBTMSGAKUKYUCD
        WHERE GKBTMSGAKUKYUCD.GAKKO_KBN_CD = p_GAKKO_KBN_CD
        AND GKBTMSGAKUKYUCD.GAKKO_CD = p_GAKKO_CD
        AND GKBTMSGAKUKYUCD.GAKUKYU_CD = p_GAKUKYU_CD;

        -- 学齢簿（GKBTGAKUREIBO）
        CURSOR CSGKBTGAKUREIBO(p_KOJIN_NO IN NUMBER,p_RIREKI_RENBAN IN NUMBER,p_GAKKO_KBN_CD IN NUMBER) IS
        SELECT GKBTGAKUREIBO.SAISHIN_KBN
                ,GKBTGAKUREIBO.GAKKO_KBN_CD
                ,GKBTGAKUREIBO.GAKUNEN
                ,CASE WHEN p_GAKKO_KBN_CD = 1 THEN
                        GKBTGAKUREIBO.SYOGAKO_CD
                    WHEN p_GAKKO_KBN_CD = 2 THEN
                        GKBTGAKUREIBO.TYUGAKO_CD
                    WHEN p_GAKKO_KBN_CD = 3 THEN
                        GKBTGAKUREIBO.YOGOGAKO_CD
                    WHEN p_GAKKO_KBN_CD = 4 THEN
                        GKBTGAKUREIBO.KUIKIGAI_CD
                    END GAKO_CD
        FROM GKBTGAKUREIBO
        WHERE GKBTGAKUREIBO.KOJIN_NO = p_KOJIN_NO
        AND GKBTGAKUREIBO.RIREKI_RENBAN = p_RIREKI_RENBAN;

    BEGIN
        -- 2-1.アップロード済ワークデータのチェックと更新処理
        -- 2-1-1.学級一括設定ワークテーブル（GKBWGAKUKYUSETTEIW）のデータ全行削除を行う。（TRUNCATE)
        EXECUTE IMMEDIATE 'TRUNCATE TABLE GKBWGAKUKYUSETTEIW';

        BEGIN
        FOR CRCWK_GAKUKYU_SETTEI IN CWK_GAKUKYU_SETTEI LOOP
            NDATASEQ                    := NDATASEQ + 1;                            -- 変数.ループ回数に1をカウントアップする
            VKOUMOKUMEI                 := '';                                      -- 変数.エラー項目名に空白の初期値を設定する
            NERROR_CD                   := 0;                                       -- 変数.1件毎エラーカウントに初期値0を設定する
            VERROR_MSG                  := '';                                      -- 変数.1件毎エラーメッセージに空白の初期値を設定する
            VERR_NAIYO                  := '';                                      -- 変数.エラー内容に空白の初期値を設定する
            NSYOGAKO_CD                 := '';                                      -- 変数.小学校学校等コード
            VSYOGAKOMEI                 := '';                                      -- 変数.小学校名
            NTYUGAKO_CD                 := '';                                      -- 変数.中学校学校等コード
            VTYUGAKOMEI                 := '';                                      -- 変数.中学校名
            NYOGOGAKO_CD                := '';                                      -- 変数.別支援学校学校等コード
            VYOGOGAKOMEI                := '';                                      -- 変数.別支援学校名
            NKUIKIGAI_CD                := '';                                      -- 変数.区域外学校学校等コード
            VKUIKIGAIMEI                := '';                                      -- 変数.区域外学校名
            NGAKUNEN_CD                 := '';                                      -- 変数.学年コード
            VGAKUNENMEI                 := '';                                      -- 変数.学年名
            NGAKUKYU_CD                 := '';                                      -- 変数.学級コード
            NGAKUREIBO_SAISHIN_KBN      := '';                                      -- 変数.学齢簿最新区分
            NGAKUREIBO_GAKKO_KBN_CD     := '';                                      -- 変数.学齢簿学校区分コード
            NGAKUREIBO_GAKO_CD          := '';                                      -- 変数.学齢簿学校等コード
            NGAKUREIBO_GAKUNEN_CD       := '';                                      -- 変数.学齢簿学年コード
            BKOJIN_NO_ERROR_FLG         := FALSE;                                   -- 変数.宛名番号エラー有無フラグ
            BRIREKI_RENBAN_ERROR_FLG    := FALSE;                                   -- 変数.履歴連番エラー有無フラグ
            BGAKKO_KBN_CD_ERROR_FLG     := FALSE;                                   -- 変数.学校区分コードエラー有無フラグ
            BGAKKO_KBN_MEISHO_ERROR_FLG := FALSE;                                   -- 変数.学校区分名称エラー有無フラグ
            BGAKKO_CD_ERROR_FLG         := FALSE;                                   -- 変数.学校等コードエラー有無フラグ
            BGAKKO_MEISHO_ERROR_FLG     := FALSE;                                   -- 変数.学校等名称エラー有無フラグ
            BGAKUNEN_CD_ERROR_FLG       := FALSE;                                   -- 変数.学年コードエラー有無フラグ
            BGAKUNEN_MEISHO_ERROR_FLG   := FALSE;                                   -- 変数.学年名称エラー有無フラグ
            BGAKUKYU_CD_ERROR_FLG       := FALSE;                                   -- 変数.学級コードエラー有無フラグ
            BRIREKI_RENBAN_SAISHIN_FLG  := FALSE;                                   -- 変数.履歴連番の最新フラグ
            BGAKKOU_JOUHOU_ITTI_FLG     := FALSE;                                   -- 変数.学校情報の一致フラグ
            NERROR_FLG                  := 0;                                       -- 変数.エラー有無フラグ

            -- 宛名番号数値ではない場合
            IF CRCWK_GAKUKYU_SETTEI.KOJIN_NO IS NULL THEN
                VERR_NAIYO := '宛名番号（' || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                            || '）：' || '数値以外；';
                BKOJIN_NO_ERROR_FLG := TRUE;
                PROC_INS(NERROR_CD
                        ,NERR_LIST_RENBAN
                        ,BCSV_SHUTURYOKU
                        ,VERR_NAIYO);
                VKOUMOKUMEI := '宛名番号';
            END IF;

            -- 履歴連番数値ではない場合
            IF CRCWK_GAKUKYU_SETTEI.RIREKI_RENBAN IS NULL THEN
            VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                    || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                    || '）の対象者の履歴連番：'
                                    || '数値以外；';
                BRIREKI_RENBAN_ERROR_FLG := TRUE;
                PROC_INS(NERROR_CD
                        ,NERR_LIST_RENBAN
                        ,BCSV_SHUTURYOKU
                        ,VERR_NAIYO);
                IF VKOUMOKUMEI IS NULL THEN
                    VKOUMOKUMEI := '履歴連番';
                ELSE
                    VKOUMOKUMEI := VKOUMOKUMEI || ',' || '履歴連番';
                END IF;
            END IF;

            -- 学校区分コード数値ではない場合
            IF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD IS NULL THEN
            VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                        || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                        || '）の対象者の学校区分コード：'
                                        || '数値以外；';
                BGAKKO_KBN_CD_ERROR_FLG := TRUE;
                PROC_INS(NERROR_CD
                        ,NERR_LIST_RENBAN
                        ,BCSV_SHUTURYOKU
                        ,VERR_NAIYO);
                IF VKOUMOKUMEI IS NULL THEN
                    VKOUMOKUMEI := '学校区分コード';
                ELSE
                    VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校区分コード';
                END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Update start 0.3.000.000:新WizLIFE２次開発
--            -- 学校区分コードが１～４以外の場合
--            ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD > 4 OR CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD < 1 THEN
--            VERR_NAIYO := VERR_NAIYO || '宛名番号（'
--                                        || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
--                                        || '）の対象者の学校区分コード：'
--                                        || '1～4以外；';
            -- 学校区分コードが１～5以外の場合
            ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD > 5 OR CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD < 1 THEN
            VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                        || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                        || '）の対象者の学校区分コード：'
                                        || '1～5以外；';
--2024/03/19 ZCZL.GUOXIAOZHU Update end                                        
                BGAKKO_KBN_CD_ERROR_FLG := TRUE;
                PROC_INS(NERROR_CD
                        ,NERR_LIST_RENBAN
                        ,BCSV_SHUTURYOKU
                        ,VERR_NAIYO);

                IF VKOUMOKUMEI IS NULL THEN
                VKOUMOKUMEI := '学校区分コード';
                ELSE
                VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校区分コード';
                END IF;

            -- 学校区分コードがエラーでない時に、学校区分名称は以下の対照表と合わない場合
            ELSE
                IF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 1 AND (CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO <> '小学校'
                    OR CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO IS NULL) THEN
                    VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                || '）の対象者の学校区分名称：'
                                                || '正しくありません；';
                    BGAKKO_KBN_MEISHO_ERROR_FLG := TRUE;
                    PROC_INS(NERROR_CD
                            ,NERR_LIST_RENBAN
                            ,BCSV_SHUTURYOKU
                            ,VERR_NAIYO);
                    IF VKOUMOKUMEI IS NULL THEN
                        VKOUMOKUMEI := '学校区分名称';
                    ELSE
                        VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校区分名称';
                    END IF;
                ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 2 AND (CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO <> '中学校'
                    OR CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO IS NULL) THEN
                    VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                || '）の対象者の学校区分名称：'
                                                || '正しくありません；';
                    BGAKKO_KBN_MEISHO_ERROR_FLG := TRUE;
                    PROC_INS(NERROR_CD
                            ,NERR_LIST_RENBAN
                            ,BCSV_SHUTURYOKU
                            ,VERR_NAIYO);
                    IF VKOUMOKUMEI IS NULL THEN
                        VKOUMOKUMEI := '学校区分名称';
                    ELSE
                        VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校区分名称';
                    END IF;
                ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 3 AND (CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO <> '特別支援学校'
                    OR CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO IS NULL) THEN
                    VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                || '）の対象者の学校区分名称：'
                                                || '正しくありません；';
                    BGAKKO_KBN_MEISHO_ERROR_FLG := TRUE;
                    PROC_INS(NERROR_CD
                            ,NERR_LIST_RENBAN
                            ,BCSV_SHUTURYOKU
                            ,VERR_NAIYO);
                    IF VKOUMOKUMEI IS NULL THEN
                        VKOUMOKUMEI := '学校区分名称';
                    ELSE
                        VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校区分名称';
                    END IF;
                ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 4 AND (CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO <> '区域外学校'
                    OR CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO IS NULL) THEN
                    VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                || '）の対象者の学校区分名称：'
                                                || '正しくありません；';
                    BGAKKO_KBN_MEISHO_ERROR_FLG := TRUE;
                    PROC_INS(NERROR_CD
                            ,NERR_LIST_RENBAN
                            ,BCSV_SHUTURYOKU
                            ,VERR_NAIYO);
                    IF VKOUMOKUMEI IS NULL THEN
                        VKOUMOKUMEI := '学校区分名称';
                    ELSE
                        VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校区分名称';
                    END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発   
                ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 5 AND (CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO <> '国・私立学校'
                    OR CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO IS NULL) THEN
                    VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                || '）の対象者の学校区分名称：'
                                                || '正しくありません；';
                    BGAKKO_KBN_MEISHO_ERROR_FLG := TRUE;
                    PROC_INS(NERROR_CD
                            ,NERR_LIST_RENBAN
                            ,BCSV_SHUTURYOKU
                            ,VERR_NAIYO);
                    IF VKOUMOKUMEI IS NULL THEN
                        VKOUMOKUMEI := '学校区分名称';
                    ELSE
                        VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校区分名称';
                    END IF;  
--2024/06/19 ZCZL.GUOXIAOZHU Add end                    
                ELSE
                    NULL;
                END IF;
            END IF;

            -- 学校等コード数値ではない場合
            IF CRCWK_GAKUKYU_SETTEI.GAKKO_CD IS NULL THEN
            VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                    || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                    || '）の対象者の学校等コード：'
                                    || '数値以外；';
                BGAKKO_CD_ERROR_FLG := TRUE;
                PROC_INS(NERROR_CD
                        ,NERR_LIST_RENBAN
                        ,BCSV_SHUTURYOKU
                        ,VERR_NAIYO);
                IF VKOUMOKUMEI IS NULL THEN
                    VKOUMOKUMEI := '学校等コード';
                ELSE
                    VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等コード';
                END IF;
            ELSE
                -- 学校区分コードと学校等コードがエラーでない時に、以下のように学校区分コードに対応する学校名テーブルより学校等コードの存在チェックを行う。存在しない場合
                IF NOT BGAKKO_KBN_CD_ERROR_FLG THEN
                    IF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 1 THEN
                        FOR CSRGKBTSHOGAKKO IN CSGKBTSHOGAKKO(CRCWK_GAKUKYU_SETTEI.GAKKO_CD) LOOP
                            NSYOGAKO_CD := CSRGKBTSHOGAKKO.SYOGAKO_CD;
                            VSYOGAKOMEI := CSRGKBTSHOGAKKO.SYOGAKOMEI;
                        END LOOP;
                        IF NSYOGAKO_CD IS NULL THEN
                            VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                    || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                    || '）の対象者の学校等コード：'
                                                    || '存在しません；';
                            BGAKKO_CD_ERROR_FLG := TRUE;
                            PROC_INS(NERROR_CD
                                    ,NERR_LIST_RENBAN
                                    ,BCSV_SHUTURYOKU
                                    ,VERR_NAIYO);
                            IF VKOUMOKUMEI IS NULL THEN
                            VKOUMOKUMEI := '学校等コード';
                            ELSE
                            VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等コード';
                            END IF;
                        END IF;
                    ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 2 THEN
                        FOR CSRGKBTCHUGAKKO IN CSGKBTCHUGAKKO(CRCWK_GAKUKYU_SETTEI.GAKKO_CD) LOOP
                            NTYUGAKO_CD := CSRGKBTCHUGAKKO.TYUGAKO_CD;
                            VTYUGAKOMEI := CSRGKBTCHUGAKKO.TYUGAKOMEI;
                        END LOOP;
                        IF NTYUGAKO_CD IS NULL THEN
                            VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                    || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                    || '）の対象者の学校等コード：'
                                                    || '存在しません；';
                            BGAKKO_CD_ERROR_FLG := TRUE;
                            PROC_INS(NERROR_CD
                                    ,NERR_LIST_RENBAN
                                    ,BCSV_SHUTURYOKU
                                    ,VERR_NAIYO);
                            IF VKOUMOKUMEI IS NULL THEN
                            VKOUMOKUMEI := '学校等コード';
                            ELSE
                            VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等コード';
                            END IF;
                        END IF;
                    ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 3 THEN
                        FOR CSRGKBTYOGOGAKKO IN CSGKBTYOGOGAKKO(CRCWK_GAKUKYU_SETTEI.GAKKO_CD) LOOP
                            NYOGOGAKO_CD := CSRGKBTYOGOGAKKO.YOGOGAKO_CD;
                            VYOGOGAKOMEI := CSRGKBTYOGOGAKKO.YOGOGAKOMEI;
                        END LOOP;
                        IF NYOGOGAKO_CD IS NULL THEN
                            VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                    || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                    || '）の対象者の学校等コード：'
                                                    || '存在しません；';
                            BGAKKO_CD_ERROR_FLG := TRUE;
                            PROC_INS(NERROR_CD
                                    ,NERR_LIST_RENBAN
                                    ,BCSV_SHUTURYOKU
                                    ,VERR_NAIYO);
                            IF VKOUMOKUMEI IS NULL THEN
                            VKOUMOKUMEI := '学校等コード';
                            ELSE
                            VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等コード';
                            END IF;
                        END IF;
                    ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 4 THEN
                        FOR CSRGKBTKUIKIGAI IN CSGKBTKUIKIGAI(CRCWK_GAKUKYU_SETTEI.GAKKO_CD) LOOP
                            NKUIKIGAI_CD := CSRGKBTKUIKIGAI.KUIKIGAI_CD;
                            VKUIKIGAIMEI := CSRGKBTKUIKIGAI.KUIKIGAIMEI;
                        END LOOP;
                        IF NKUIKIGAI_CD IS NULL THEN
                            VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                    || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                    || '）の対象者の学校等コード：'
                                                    || '存在しません；';
                            BGAKKO_CD_ERROR_FLG := TRUE;
                            PROC_INS(NERROR_CD
                                    ,NERR_LIST_RENBAN
                                    ,BCSV_SHUTURYOKU
                                    ,VERR_NAIYO);
                            IF VKOUMOKUMEI IS NULL THEN
                                VKOUMOKUMEI := '学校等コード';
                            ELSE
                                VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等コード';
                            END IF;
                        END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発
                    ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 5 THEN
                        FOR CSRGKBTKUNISIRITSUGAKKO IN CSGKBTKUNISIRITSUGAKKO(CRCWK_GAKUKYU_SETTEI.GAKKO_CD) LOOP
                            NKUNISHIRITSUGAKKO_CD := CSRGKBTKUNISIRITSUGAKKO.KUNISHIRITSUGAKKO_CD;
                            VKUNISHIRITSUGAKKOMEI := CSRGKBTKUNISIRITSUGAKKO.KUNISHIRITSUGAKKOMEI;
                        END LOOP;
                        IF NKUNISHIRITSUGAKKO_CD IS NULL THEN
                            VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                    || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                    || '）の対象者の学校等コード：'
                                                    || '存在しません；';
                            BGAKKO_CD_ERROR_FLG := TRUE;
                            PROC_INS(NERROR_CD
                                    ,NERR_LIST_RENBAN
                                    ,BCSV_SHUTURYOKU
                                    ,VERR_NAIYO);
                            IF VKOUMOKUMEI IS NULL THEN
                                VKOUMOKUMEI := '学校等コード';
                            ELSE
                                VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等コード';
                            END IF;
                        END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Add end                       
                    ELSE
                        NULL;
                    END IF;
                END IF;
            END IF;

            -- 学校等コードがエラーでない時に、学校等名称が学校等コードに対応する学校名テーブルの学校等名称と合わない場合
            IF NOT BGAKKO_CD_ERROR_FLG THEN
                IF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 1 THEN
                    IF CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO <> VSYOGAKOMEI OR CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO IS NULL THEN
                        VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                || '）の対象者の学校等名称：'
                                                || '存在しません；';
                        BGAKKO_MEISHO_ERROR_FLG := TRUE;
                        PROC_INS(NERROR_CD
                                ,NERR_LIST_RENBAN
                                ,BCSV_SHUTURYOKU
                                ,VERR_NAIYO);
                        IF VKOUMOKUMEI IS NULL THEN
                            VKOUMOKUMEI := '学校等名称';
                        ELSE
                            VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等名称';
                        END IF;
                    END IF;
                ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 2 THEN
                    IF CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO <> VTYUGAKOMEI OR CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO IS NULL THEN
                        VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                || '）の対象者の学校等名称：'
                                                || '存在しません；';
                        BGAKKO_MEISHO_ERROR_FLG := TRUE;
                        PROC_INS(NERROR_CD
                                ,NERR_LIST_RENBAN
                                ,BCSV_SHUTURYOKU
                                ,VERR_NAIYO);
                        IF VKOUMOKUMEI IS NULL THEN
                            VKOUMOKUMEI := '学校等名称';
                        ELSE
                            VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等名称';
                        END IF;
                    END IF;
                ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 3 THEN
                    IF CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO <> VYOGOGAKOMEI OR CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO IS NULL THEN
                        VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                || '）の対象者の学校等名称：'
                                                || '存在しません；';
                        BGAKKO_MEISHO_ERROR_FLG := TRUE;
                        PROC_INS(NERROR_CD
                                ,NERR_LIST_RENBAN
                                ,BCSV_SHUTURYOKU
                                ,VERR_NAIYO);
                        IF VKOUMOKUMEI IS NULL THEN
                            VKOUMOKUMEI := '学校等名称';
                        ELSE
                            VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等名称';
                        END IF;
                    END IF;
                ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 4 THEN
                    IF CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO <> VKUIKIGAIMEI OR CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO IS NULL THEN
                        VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                || '）の対象者の学校等名称：'
                                                || '存在しません；';
                        BGAKKO_MEISHO_ERROR_FLG := TRUE;
                        PROC_INS(NERROR_CD
                                ,NERR_LIST_RENBAN
                                ,BCSV_SHUTURYOKU
                                ,VERR_NAIYO);
                        IF VKOUMOKUMEI IS NULL THEN
                            VKOUMOKUMEI := '学校等名称';
                        ELSE
                            VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等名称';
                        END IF;
                    END IF;
--2024/06/19 ZCZL.GUPXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発
                ELSIF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD = 5 THEN
                    IF CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO <> VKUNISHIRITSUGAKKOMEI OR CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO IS NULL THEN
                        VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                                || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                || '）の対象者の学校等名称：'
                                                || '存在しません；';
                        BGAKKO_MEISHO_ERROR_FLG := TRUE;
                        PROC_INS(NERROR_CD
                                ,NERR_LIST_RENBAN
                                ,BCSV_SHUTURYOKU
                                ,VERR_NAIYO);
                        IF VKOUMOKUMEI IS NULL THEN
                            VKOUMOKUMEI := '学校等名称';
                        ELSE
                            VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校等名称';
                        END IF;
                    END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Add end                    
                ELSE
                    NULL;
                END IF;
            END IF;

            -- 学年コード数値ではない場合
            IF CRCWK_GAKUKYU_SETTEI.GAKUNEN_CD IS NULL THEN
                VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                      || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                      || '）の対象者の学年コード：'
                                      || '数値以外；';
                BGAKUNEN_CD_ERROR_FLG := TRUE;
                PROC_INS(NERROR_CD
                        ,NERR_LIST_RENBAN
                        ,BCSV_SHUTURYOKU
                        ,VERR_NAIYO);
                IF VKOUMOKUMEI IS NULL THEN
                    VKOUMOKUMEI := '学年コード';
                ELSE
                    VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学年コード';
                END IF;
                -- 学年コードが学年テーブル（GKBTGAKUNEN）に登録されていない場合、エラー
                ELSE
                FOR CSRGKBTGAKUNEN IN CSGKBTGAKUNEN(CRCWK_GAKUKYU_SETTEI.GAKUNEN_CD) LOOP
                    NGAKUNEN_CD := CSRGKBTGAKUNEN.GAKUNEN_CD;
                    VGAKUNENMEI := CSRGKBTGAKUNEN.GAKUNENMEI;
                END LOOP;
                IF NGAKUNEN_CD IS NOT NULL THEN
                    BGAKUNEN_CD_ERROR_FLG := FALSE;
                ELSE
                    VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                            || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                            || '）の対象者の学年コード：'
                                            || '存在しません；';
                    BGAKUNEN_CD_ERROR_FLG := TRUE;
                    PROC_INS(NERROR_CD
                            ,NERR_LIST_RENBAN
                            ,BCSV_SHUTURYOKU
                            ,VERR_NAIYO);
                    IF VKOUMOKUMEI IS NULL THEN
                    VKOUMOKUMEI := '学年コード';
                    ELSE
                    VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学年コード';
                    END IF;
                END IF;
            END IF;

            -- 学年コードがエラーでない時に、学年名称が学年コードに対応する学年名称と合わない場合
            IF NOT BGAKUNEN_CD_ERROR_FLG  THEN
                IF CRCWK_GAKUKYU_SETTEI.GAKUNEN_MEISHO <> VGAKUNENMEI OR CRCWK_GAKUKYU_SETTEI.GAKUNEN_MEISHO IS NULL THEN
                    VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                            || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                            || '）の対象者の学年名称：'
                                            || '存在しません；';
                    BGAKUNEN_MEISHO_ERROR_FLG := TRUE;
                    PROC_INS(NERROR_CD
                            ,NERR_LIST_RENBAN
                            ,BCSV_SHUTURYOKU
                            ,VERR_NAIYO);
                    IF VKOUMOKUMEI IS NULL THEN
                    VKOUMOKUMEI := '学年名称';
                    ELSE
                    VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学年名称';
                    END IF;
                END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発
                NRTN := GKAFKMBKKSCDGET(CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD, CRCWK_GAKUKYU_SETTEI.GAKKO_CD, o_MGAKKO_CD);
                IF SUBSTR(o_MGAKKO_CD, 1, 2) = 'C2' THEN
                    BEGIN
                      SELECT GAKUNENMEI INTO GAKUNENMEI FROM GKBTGAKUNEN WHERE GAKUNEN_CD = CRCWK_GAKUKYU_SETTEI.GAKUNEN_CD;
                    EXCEPTION
                      WHEN OTHERS THEN
                        GAKUNENMEI := '';
                    END;
                    IF GAKUNENMEI <> CRCWK_GAKUKYU_SETTEI.GAKUNEN_MEISHO THEN
                        VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                         || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                         || '）の対象者の学年名称：'
                                         || '義務教育学校学年名ではない；';
                        BGAKUNEN_MEISHO_ERROR_FLG := TRUE;
                        PROC_INS(NERROR_CD
                            ,NERR_LIST_RENBAN
                            ,BCSV_SHUTURYOKU
                            ,VERR_NAIYO);
                        IF VKOUMOKUMEI IS NULL THEN
                            VKOUMOKUMEI := '学年名称';
                        ELSE
                            VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学年名称';
                        END IF;
                    END IF;
                END IF;

--2024/06/19 ZCZL.GUOXIAOZHU Add end                
            END IF;

            -- 学級コード数値ではない場合
            IF CRCWK_GAKUKYU_SETTEI.GAKUKYU_CD IS NULL THEN
                VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                        || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                        || '）の対象者の学級コード：'
                                        || '数値以外；';
                BGAKUKYU_CD_ERROR_FLG := TRUE;
                PROC_INS(NERROR_CD
                        ,NERR_LIST_RENBAN
                        ,BCSV_SHUTURYOKU
                        ,VERR_NAIYO);
                IF VKOUMOKUMEI IS NULL THEN
                    VKOUMOKUMEI := '学級コード';
                ELSE
                    VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学級コード';
                END IF;
            -- 学校区分コードと学校等コードがエラーでない時に、学級コードが学級マスタ（GKBTMSGAKUKYUCD）に登録されていない場合、エラー
            ELSE
                IF NOT BGAKKO_KBN_CD_ERROR_FLG AND NOT BGAKKO_CD_ERROR_FLG THEN
                    FOR CSRGKCTSHIKYU IN CSGKCTSHIKYU(CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD
                                                    ,CRCWK_GAKUKYU_SETTEI.GAKKO_CD
                                                    ,CRCWK_GAKUKYU_SETTEI.GAKUKYU_CD) LOOP
                    NGAKUKYU_CD := CSRGKCTSHIKYU.GAKUKYU_CD;
                    END LOOP;
                    IF NGAKUKYU_CD IS NULL THEN
                    VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                            || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                            || '）の対象者の学級コード：'
                                            || '存在しません；';
                    BGAKUKYU_CD_ERROR_FLG := TRUE;
                    PROC_INS(NERROR_CD
                            ,NERR_LIST_RENBAN
                            ,BCSV_SHUTURYOKU
                            ,VERR_NAIYO);
                    IF VKOUMOKUMEI IS NULL THEN
                        VKOUMOKUMEI := '学級コード';
                    ELSE
                        VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学級コード';
                    END IF;
                    END IF;
                END IF;
            END IF;

            -- 最新であるかどうかのチェック
            FOR CSRGKBTGAKUREIBO IN CSGKBTGAKUREIBO(CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                                    ,CRCWK_GAKUKYU_SETTEI.RIREKI_RENBAN
                                                    ,CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD) LOOP
                NGAKUREIBO_SAISHIN_KBN  := CSRGKBTGAKUREIBO.SAISHIN_KBN;
                NGAKUREIBO_GAKKO_KBN_CD := CSRGKBTGAKUREIBO.GAKKO_KBN_CD;
                NGAKUREIBO_GAKO_CD      := CSRGKBTGAKUREIBO.GAKO_CD;
                NGAKUREIBO_GAKUNEN_CD   := CSRGKBTGAKUREIBO.GAKUNEN;
            END LOOP;
            -- 宛名番号と履歴連番の数値チェックにエラーでない場合、履歴連番が最新かどうかのチェック
            IF NOT BKOJIN_NO_ERROR_FLG AND NOT BRIREKI_RENBAN_ERROR_FLG THEN
                IF NGAKUREIBO_SAISHIN_KBN <> 0 OR NGAKUREIBO_SAISHIN_KBN IS NULL THEN
                    VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                            || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                            || '）の対象者の履歴連番：'
                                            || '最新ではありません；';
                    BRIREKI_RENBAN_SAISHIN_FLG := TRUE;
                    PROC_INS(NERROR_CD
                            ,NERR_LIST_RENBAN
                            ,BCSV_SHUTURYOKU
                            ,VERR_NAIYO);
                    IF VKOUMOKUMEI IS NULL THEN
                    VKOUMOKUMEI := '履歴連番の最新';
                    ELSE
                    VKOUMOKUMEI := VKOUMOKUMEI || ',' || '履歴連番の最新';
                    END IF;
                END IF;
            END IF;
            -- 学校情報（学校区分コード、学校等コード、学年コード）が変更されているかどうかのチェック
            IF CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD <> NGAKUREIBO_GAKKO_KBN_CD
              OR NGAKUREIBO_GAKKO_KBN_CD IS NULL
              OR CRCWK_GAKUKYU_SETTEI.GAKKO_CD <> NGAKUREIBO_GAKO_CD
              OR NGAKUREIBO_GAKO_CD IS NULL
              OR CRCWK_GAKUKYU_SETTEI.GAKUNEN_CD <> NGAKUREIBO_GAKUNEN_CD
              OR NGAKUREIBO_GAKUNEN_CD IS NULL THEN
                VERR_NAIYO := VERR_NAIYO || '宛名番号（'
                                          || CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                          || '）の対象者の学校情報（学校区分コード、学校等コード、学年コード）：'
                                          || '学齢簿の学校情報と一致していません；';
                BGAKKOU_JOUHOU_ITTI_FLG := TRUE;
                PROC_INS(NERROR_CD
                        ,NERR_LIST_RENBAN
                        ,BCSV_SHUTURYOKU
                        ,VERR_NAIYO);
                IF VKOUMOKUMEI IS NULL THEN
                    VKOUMOKUMEI := '学校情報の一致';
                ELSE
                    VKOUMOKUMEI := VKOUMOKUMEI || ',' || '学校情報の一致';
                END IF;
            END IF;

            -- 変数.1件毎エラーカウント>0の場合、変数.1件毎エラーメッセージの内容を下記に設定する。
            -- 変数.エラー項目名+'　'+'項目が既定値の範囲でないか、コード表に登録されていません。'
            IF NERROR_CD > 0 THEN
                VERROR_MSG := VKOUMOKUMEI || '　' || '項目が既定値の範囲でないか、コード表に登録されていません。';
                NERROR_FLG := 1;
                NERROR_KENSU := NERROR_KENSU + 1;
            ELSE
                VERROR_MSG := '';
                NERROR_FLG := 0;
            END IF;
            VKOYUKEY := CRCWK_GAKUKYU_SETTEI.KOJIN_NO || '-' || CRCWK_GAKUKYU_SETTEI.RIREKI_RENBAN;
            INSERT INTO GKBWGAKUKYUSETTEIW (KOJIN_NO
                                           ,RIREKI_RENBAN
--2024/06/19 ZCZL.GUOXIAOZHU Add 0.3.000.000:新WizLIFE２次開発
                                           ,RIREKI_RENBAN_EDA
                                           ,GAKKO_KBN_CD
                                           ,GAKKO_KBN_MEISHO
                                           ,GAKKO_CD
                                           ,GAKKO_MEISHO
                                           ,GAKUNEN_CD
                                           ,GAKUNEN_MEISHO
                                           ,GAKUKYU_CD
                                           ,GAKUKYU_MEISHO
                                           ,DATASEQ
                                           ,KOYUKEY
                                           ,ERROR_CD
                                           ,ERROR_MSG
                                           ,ERROR_FLG
                                           ,SYS_SAKUSEIBI
                                           ,SYS_KOSHINBI
                                           ,SYS_JIKAN
                                           ,SYS_SHOKUINKOJIN_NO
                                           ,SYS_TANMATSU_NO)
                                           VALUES(
                                           CRCWK_GAKUKYU_SETTEI.KOJIN_NO
                                           ,CRCWK_GAKUKYU_SETTEI.RIREKI_RENBAN
--2024/06/19 ZCZL.GUOXIAOZHU Add 0.3.000.000:新WizLIFE２次開発
                                           ,CRCWK_GAKUKYU_SETTEI.RIREKI_RENBAN_EDA
                                           ,CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_CD
                                           ,CRCWK_GAKUKYU_SETTEI.GAKKO_KBN_MEISHO
                                           ,CRCWK_GAKUKYU_SETTEI.GAKKO_CD
                                           ,CRCWK_GAKUKYU_SETTEI.GAKKO_MEISHO
                                           ,CRCWK_GAKUKYU_SETTEI.GAKUNEN_CD
                                           ,CRCWK_GAKUKYU_SETTEI.GAKUNEN_MEISHO
                                           ,CRCWK_GAKUKYU_SETTEI.GAKUKYU_CD
                                           ,CRCWK_GAKUKYU_SETTEI.GAKUKYU_MEISHO
                                           ,NDATASEQ
                                           ,VKOYUKEY
                                           ,NERROR_CD
                                           ,VERROR_MSG
                                           ,NERROR_FLG
                                           ,VSYSDATE
                                           ,VSYSDATE
                                           ,g_nTIME
                                           ,g_sTANTOCODE
                                           ,g_sWSNUM);


        END LOOP;
        EXCEPTION
        WHEN OTHERS THEN
            VLOG := FUNC_GET_LOG('アップロード済ワークデータのチェックと更新処理で異常終了しました。');
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JUNBI_SHORI', 1, SQLCODE, SQLERRM, VLOG, g_sTANTOCODE, g_sWSNUM, 1);
            RETURN 1;
        END;

        VLOG := FUNC_GET_LOG('アップロード済ワークデータのチェックと更新処理が正常終了しました。');
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JUNBI_SHORI', 0, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
        
        -- 汎用エラーリストワークへの出力を行った場合、下記の処理を行う。
        IF BCSV_SHUTURYOKU THEN
          -- CSVを作成する。
          NRTN := FUNC_CREATE_CSV;
          IF NRTN <> 0 THEN
            -- 2-2.エラーリスト出力処理で異常終了した場合に出力する。
            VLOG := FUNC_GET_LOG('エラーリスト出力処理で異常終了しました。');
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JUNBI_SHORI', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
            RETURN 1;
          END IF;
          VLOG := FUNC_GET_LOG('エラーリスト出力処理が正常終了しました。');
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JUNBI_SHORI', 0, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
        END IF;

        RETURN 0;
    EXCEPTION
        WHEN OTHERS THEN
        RETURN 1;
    END FUNC_JUNBI_SHORI;
    --------------------------------------------------------
    --  機能概要      : 件数表で対応メッセージが含めか
    --  パラメータ    : i_vKENSUU_NAIYOU 件数表のタイトル
    --  モジュール区分: 内部関数
    --  戻り値        : 含める TRUE,  含めいない FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.GUOXU 2024/1/2
    --------------------------------------------------------
    FUNCTION FUNC_CHECK_KENSUU(i_vKENSUU_NAIYOU VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        IF g_oKENSU_LIST IS NULL OR g_oKENSU_LIST.COUNT = 0 THEN
          RETURN FALSE;
        END IF;
        FOR i IN 1..g_oKENSU_LIST.COUNT LOOP
           --同じタイトルを含めて、一つを設定する
           IF g_oKENSU_LIST(i).NAIYOU = i_vKENSUU_NAIYOU THEN
               RETURN TRUE;
           END IF;
        END LOOP;
        RETURN FALSE;
    END FUNC_CHECK_KENSUU;
    -------------------------------------------------------------------------------------
    -- 3.メーン処理
    FUNCTION FUNC_SET_GAKUKYU RETURN PLS_INTEGER
    IS
        NKENSU NUMBER := 0;  -- 変数.件数カウント
        VFROM  NVARCHAR2(250);
--2024/06/19 ZCZL.GUOXIAOZHU Add 0.3.000.000:新WizLIFE２次開発
        CSGKBTGAKUNENRIREKI   GKBTGAKUNENRIREKI%ROWTYPE;      -- 学齢簿
        CSGKBTGAKUREIBO       GKBTGAKUREIBO%ROWTYPE;          -- 学年履歴
        eEXCEPTION                    EXCEPTION;
        -- 3-2-1.学級一括設定ワークテーブルのカーソルを宣言する。
        CURSOR CWK_GAKUKYU_SETTEI_W IS
            SELECT
                 GKBWGAKUKYUSETTEIW.KOJIN_NO
                ,GKBWGAKUKYUSETTEIW.RIREKI_RENBAN
--2024/06/19 ZCZL.GUOXIAOZHU Add 0.3.000.000:新WizLIFE２次開発
                ,GKBWGAKUKYUSETTEIW.RIREKI_RENBAN_EDA
                ,GKBWGAKUKYUSETTEIW.GAKKO_KBN_CD
                ,GKBWGAKUKYUSETTEIW.GAKKO_KBN_MEISHO
                ,GKBWGAKUKYUSETTEIW.GAKKO_CD
                ,GKBWGAKUKYUSETTEIW.GAKKO_MEISHO
                ,GKBWGAKUKYUSETTEIW.GAKUNEN_CD
                ,GKBWGAKUKYUSETTEIW.GAKUNEN_MEISHO
                ,GKBWGAKUKYUSETTEIW.GAKUKYU_CD
                ,GKBWGAKUKYUSETTEIW.GAKUKYU_MEISHO
            FROM  GKBWGAKUKYUSETTEIW
            WHERE GKBWGAKUKYUSETTEIW.ERROR_FLG = 0
            ORDER BY GKBWGAKUKYUSETTEIW.KOJIN_NO;
    BEGIN
        g_nINDEX := g_oKENSU_LIST.COUNT;
        -- 3-1.学級一括設定ワークの件数カウント・セット
        VFROM := 'CSVデータ読込件数【 外部データ（学級一括設定処理用）取込件数 】';
        -- 3-1-1.変数.件数カウント := 件数カウント計算（GKBFKTBLCNT）を使用して件数をカウントする。
        NKENSU := GKBFKTBLCNT('GKBWGAKUKYUSETTEIW',NULL);
        -- 3-1-2.共通関数（FUNC_CHECK_KENSUU）を使用し、INPUTデータを件数表データテーブルにセットする。
        IF NOT FUNC_CHECK_KENSUU(VFROM) THEN
          g_nINDEX := g_nINDEX + 1;
          g_oKENSU_LIST.EXTEND(1);
          g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NKENSU,'入力　' || VFROM,1);
        END IF;
        -- 3-1.学級一括設定ワークの件数カウント・セットが正常終了した場合に出力する。
        VLOG := FUNC_GET_LOG('学級一括設定ワークの件数カウント・セットが正常終了しました。');
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_GAKUKYU', 0, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
        -- 3-2.学級の更新
        BEGIN
          FOR CRWK_GAKUKYU_SETTEI_W IN CWK_GAKUKYU_SETTEI_W LOOP
              -- 学齢簿に学級コードを更新する。（詳細はシート「DB・ファイル等更新説明書（学齢簿_U）」を参照する）
--2024/03/19 ZCZL.GUOXIAOZHU Update start 0.3.000.000:新WizLIFE２次開発
--               UPDATE
--               GKBTGAKUREIBO
--               SET
--               GAKUKYU_CD = CRWK_GAKUKYU_SETTEI_W.GAKUKYU_CD
--               ,SYS_KOSHINBI = TO_NUMBER(VSYSDATE)
--               ,SYS_JIKAN  =  g_nTIME
--               ,SYS_SHOKUINKOJIN_NO  =  g_sTANTOCODE
--               ,GKBTGAKUREIBO.SYS_TANMATU_NO = g_sWSNUM
--               WHERE
--               GKBTGAKUREIBO.KOJIN_NO = CRWK_GAKUKYU_SETTEI_W.KOJIN_NO
--               AND GKBTGAKUREIBO.RIREKI_RENBAN = CRWK_GAKUKYU_SETTEI_W.RIREKI_RENBAN;
              BEGIN
                SELECT * INTO CSGKBTGAKUREIBO FROM GKBTGAKUREIBO 
                WHERE SAISHIN_KBN = 0
                  AND GKBTGAKUREIBO.KOJIN_NO = CRWK_GAKUKYU_SETTEI_W.KOJIN_NO
                  AND GKBTGAKUREIBO.RIREKI_RENBAN = CRWK_GAKUKYU_SETTEI_W.RIREKI_RENBAN
                  AND GKBTGAKUREIBO.RIREKI_RENBAN_EDA = CRWK_GAKUKYU_SETTEI_W.RIREKI_RENBAN_EDA;
              EXCEPTION
                WHEN OTHERS THEN
                  RAISE eEXCEPTION;
              END;
              UPDATE GKBTGAKUREIBO SET
              SAISHIN_KBN = 1
              ,SYS_KOSHINBI = TO_NUMBER(VSYSDATE)
              ,SYS_JIKAN  =  g_nTIME
              ,SYS_SHOKUINKOJIN_NO  =  g_sTANTOCODE
              ,SYS_TANMATU_NO = g_sWSNUM
              WHERE
              SAISHIN_KBN = 0
              AND GKBTGAKUREIBO.KOJIN_NO = CRWK_GAKUKYU_SETTEI_W.KOJIN_NO
              AND GKBTGAKUREIBO.RIREKI_RENBAN = CRWK_GAKUKYU_SETTEI_W.RIREKI_RENBAN
              AND GKBTGAKUREIBO.RIREKI_RENBAN_EDA = CRWK_GAKUKYU_SETTEI_W.RIREKI_RENBAN_EDA;
--2024/03/19 ZCZL.GUOXIAOZHU Update end
--2024/03/19 ZCZL.GUOXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発
              -- DB・ファイル等更新説明書（学齢簿_I）
              INSERT INTO GKBTGAKUREIBO VALUES(
                                        CSGKBTGAKUREIBO.KOJIN_NO,
                                        CRWK_GAKUKYU_SETTEI_W.RIREKI_RENBAN + 10,
                                        CSGKBTGAKUREIBO.RIREKI_RENBAN_EDA,
                                        CSGKBTGAKUREIBO.GENZON_KBN,
                                        0,
                                        CSGKBTGAKUREIBO.ZO_JIYU_CD,
                                        CSGKBTGAKUREIBO.ZO_NENGAPI,
                                        CSGKBTGAKUREIBO.GEN_JIYU_CD,
                                        CSGKBTGAKUREIBO.GEN_NENGAPI,
                                        CSGKBTGAKUREIBO.ZOKUGARA1,
                                        CSGKBTGAKUREIBO.ZOKUGARA2,
                                        CSGKBTGAKUREIBO.ZOKUGARA3,
                                        CSGKBTGAKUREIBO.ZOKUGARA4,
                                        CSGKBTGAKUREIBO.HOGOSYA_KOJIN_NO,
                                        CSGKBTGAKUREIBO.HOGOSYA_ZOKUGARA1,
                                        CSGKBTGAKUREIBO.HOGOSYA_ZOKUGARA2,
                                        CSGKBTGAKUREIBO.HOGOSYA_ZOKUGARA3,
                                        CSGKBTGAKUREIBO.HOGOSYA_ZOKUGARA4,
                                        CSGKBTGAKUREIBO.SYOGAKO_CD,
                                        CSGKBTGAKUREIBO.SYOGAKO_NYUGAKU_BI,
                                        CSGKBTGAKUREIBO.SYOGAKO_TENNYUGAKU_BI,
                                        CSGKBTGAKUREIBO.SYOGAKO_TENGAKU_BI,
                                        CSGKBTGAKUREIBO.SYOGAKO_SOTSUGYO_BI,
                                        CSGKBTGAKUREIBO.TYUGAKO_CD,
                                        CSGKBTGAKUREIBO.TYUGAKO_NYUGAKU_BI,
                                        CSGKBTGAKUREIBO.TYUGAKO_TENNYUGAKU_BI,
                                        CSGKBTGAKUREIBO.TYUGAKO_TENGAKU_BI,
                                        CSGKBTGAKUREIBO.TYUGAKO_SOTSUGYO_BI,
                                        CSGKBTGAKUREIBO.TOKUSOKU_BI1,
                                        CSGKBTGAKUREIBO.TOKUSOKU_NAIYO1,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JIYU1,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JURI_BI1,
                                        CSGKBTGAKUREIBO.TOKUSOKU_BI2,
                                        CSGKBTGAKUREIBO.TOKUSOKU_NAIYO2,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JIYU2,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JURI_BI2,
                                        CSGKBTGAKUREIBO.TOKUSOKU_BI3,
                                        CSGKBTGAKUREIBO.TOKUSOKU_NAIYO3,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JIYU3,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JURI_BI3,
                                        CSGKBTGAKUREIBO.TOKUSOKU_BI4,
                                        CSGKBTGAKUREIBO.TOKUSOKU_NAIYO4,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JIYU4,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JURI_BI4,
                                        CSGKBTGAKUREIBO.TOKUSOKU_BI5,
                                        CSGKBTGAKUREIBO.TOKUSOKU_NAIYO5,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JIYU5,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JURI_BI5,
                                        CSGKBTGAKUREIBO.TOKUSOKU_BI6,
                                        CSGKBTGAKUREIBO.TOKUSOKU_NAIYO6,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JIYU6,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JURI_BI6,
                                        CSGKBTGAKUREIBO.TOKUSOKU_BI7,
                                        CSGKBTGAKUREIBO.TOKUSOKU_NAIYO7,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JIYU7,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JURI_BI7,
                                        CSGKBTGAKUREIBO.TOKUSOKU_BI8,
                                        CSGKBTGAKUREIBO.TOKUSOKU_NAIYO8,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JIYU8,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JURI_BI8,
                                        CSGKBTGAKUREIBO.TOKUSOKU_BI9,
                                        CSGKBTGAKUREIBO.TOKUSOKU_NAIYO9,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JIYU9,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JURI_BI9,
                                        CSGKBTGAKUREIBO.TOKUSOKU_BI10,
                                        CSGKBTGAKUREIBO.TOKUSOKU_NAIYO10,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JIYU10,
                                        CSGKBTGAKUREIBO.TOKUSOKU_JURI_BI10,
                                        CSGKBTGAKUREIBO.KUIKIGAI_CD,
                                        CSGKBTGAKUREIBO.KUIKIGAI_SETISYA,
                                        CSGKBTGAKUREIBO.KUIKIGAI_NYUGAKU_BI,
                                        CSGKBTGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI,
                                        CSGKBTGAKUREIBO.KUIKIGAI_TENGAKU_BI,
                                        CSGKBTGAKUREIBO.KUIKIGAI_TAIGAKU_BI,
                                        CSGKBTGAKUREIBO.KUIKIGAI_SOTSUGYO_BI,
                                        CSGKBTGAKUREIBO.YOGOGAKO_CD,
                                        CSGKBTGAKUREIBO.YOGOGAKO_SETISYA,
                                        CSGKBTGAKUREIBO.YOGOGAKO_NYUGAKU_BI,
                                        CSGKBTGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI,
                                        CSGKBTGAKUREIBO.YOGOGAKO_TENGAKU_BI,
                                        CSGKBTGAKUREIBO.YOGOGAKO_TAIGAKU_BI,
                                        CSGKBTGAKUREIBO.YOGOGAKO_SOTSUGYO_BI,
                                        CSGKBTGAKUREIBO.YUYO_KYOKA_BI,
                                        CSGKBTGAKUREIBO.YUYO_JIYU_CD,
                                        CSGKBTGAKUREIBO.YUYO_JIYU,
                                        CSGKBTGAKUREIBO.YUYO_KAISI_BI,
                                        CSGKBTGAKUREIBO.YUYO_SYURYO_BI,
                                        CSGKBTGAKUREIBO.YUYO_NENSU,
                                        CSGKBTGAKUREIBO.YUYO_FUKUGAKU_BI,
                                        CSGKBTGAKUREIBO.MENJO_KYOKA_BI,
                                        CSGKBTGAKUREIBO.MENJO_JIYU_CD,
                                        CSGKBTGAKUREIBO.MENJO_JIYU,
                                        CSGKBTGAKUREIBO.MENJO_KAISI_BI,
                                        CSGKBTGAKUREIBO.MENJO_SYURYO_BI,
                                        CSGKBTGAKUREIBO.MENJO_NENSU,
                                        CSGKBTGAKUREIBO.MENJO_FUKUGAKU_BI,
                                        CSGKBTGAKUREIBO.IDO_BI1,
                                        CSGKBTGAKUREIBO.IDO_JIYU1,
                                        CSGKBTGAKUREIBO.IDO_BI2,
                                        CSGKBTGAKUREIBO.IDO_JIYU2,
                                        CSGKBTGAKUREIBO.IDO_BI3,
                                        CSGKBTGAKUREIBO.IDO_JIYU3,
                                        CSGKBTGAKUREIBO.IDO_BI4,
                                        CSGKBTGAKUREIBO.IDO_JIYU4,
                                        CSGKBTGAKUREIBO.IDO_BI5,
                                        CSGKBTGAKUREIBO.IDO_JIYU5,
                                        CSGKBTGAKUREIBO.IDO_BI6,
                                        CSGKBTGAKUREIBO.IDO_JIYU6,
                                        CSGKBTGAKUREIBO.IDO_BI7,
                                        CSGKBTGAKUREIBO.IDO_JIYU7,
                                        CSGKBTGAKUREIBO.IDO_BI8,
                                        CSGKBTGAKUREIBO.IDO_JIYU8,
                                        CSGKBTGAKUREIBO.IDO_BI9,
                                        CSGKBTGAKUREIBO.IDO_JIYU9,
                                        CSGKBTGAKUREIBO.IDO_BI10,
                                        CSGKBTGAKUREIBO.IDO_JIYU10,
                                        CSGKBTGAKUREIBO.SYS_SAKUSEIBI,
                                        TO_NUMBER(VSYSDATE),
                                        g_nTIME,
                                        g_sTANTOCODE,
                                        g_sWSNUM,
                                        CSGKBTGAKUREIBO.GAKUNEN,
                                        CSGKBTGAKUREIBO.SHORIBI,
                                        CSGKBTGAKUREIBO.SHUGAKU,
                                        CSGKBTGAKUREIBO.IDOJIKO,
                                        CSGKBTGAKUREIBO.CHOHYO_NO,
                                        CSGKBTGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.GAKKO_KBN_CD,
                                        CRWK_GAKUKYU_SETTEI_W.GAKUKYU_CD,
                                        CSGKBTGAKUREIBO.SEIBETSU,
                                        CSGKBTGAKUREIBO.JOTAI,
                                        CSGKBTGAKUREIBO.TENNYUMAE_GAKKO_KBN,
                                        CSGKBTGAKUREIBO.TENNYUMAE_GAKKO_CD,
                                        CSGKBTGAKUREIBO.TENNYUMAE_GAKUNEN,
                                        CSGKBTGAKUREIBO.GENKYURYUCHI_FLG,
                                        CSGKBTGAKUREIBO.GENKYURYUCHI_KETTEI_BI,
                                        CSGKBTGAKUREIBO.GENKYURYUCHI_KAISI_BI,
                                        CSGKBTGAKUREIBO.GENKYURYUCHI_SYURYOBI,
                                        CSGKBTGAKUREIBO.GENKYURYUCHI_RIYU,
                                        CSGKBTGAKUREIBO.SHITEI_SYOGAKO_CD,
                                        CSGKBTGAKUREIBO.SHITEI_TYUGAKO_CD,
                                        CSGKBTGAKUREIBO.HENKO_GAKUNEN_SYOGAKO,
                                        CSGKBTGAKUREIBO.HENKO_GAKUNEN_TYUGAKO,
                                        CSGKBTGAKUREIBO.HENKO_SHINSEI_BI,
                                        CSGKBTGAKUREIBO.HENKO_KYOKA_BI,
                                        CSGKBTGAKUREIBO.HENKO_KBN,
                                        CSGKBTGAKUREIBO.HENKO_KAISI_BI,
                                        CSGKBTGAKUREIBO.HENKO_SYURYO_BI,
                                        CSGKBTGAKUREIBO.HENKO_KYOKA_RIYU,
                                        CSGKBTGAKUREIBO.HENKO_JIYU,
                                        CSGKBTGAKUREIBO.HENKO_HUKYOKA_RIYU,
                                        CSGKBTGAKUREIBO.KIBO_GAKKO_KBN_CD,
                                        CSGKBTGAKUREIBO.KIBO_SYOGAKKO_CD,
                                        CSGKBTGAKUREIBO.KIBO_TYUGAKKO_CD,
                                        CSGKBTGAKUREIBO.KIBO_UKETSUKE_BI_SYOGAKO,
                                        CSGKBTGAKUREIBO.KIBO_UKETSUKE_BI_TYUGAKO,
                                        CSGKBTGAKUREIBO.KUIKIGAISHUGAKU_FLG,
                                        CSGKBTGAKUREIBO.KUIKIGAISHUGAKU_SHINSEI_BI,
                                        CSGKBTGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_BI,
                                        CSGKBTGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI,
                                        CSGKBTGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI,
                                        CSGKBTGAKUREIBO.KUIKIGAISHUGAKU_JIYU,
                                        CSGKBTGAKUREIBO.KUIKIGAISHUGAKU_KYOKA_RIYU,
                                        CSGKBTGAKUREIBO.KUIKIGAISHUGAKU_HUKYOKA_RIYU,
                                        CSGKBTGAKUREIBO.HUSHUGAKU_KAISI_BI,
                                        CSGKBTGAKUREIBO.HUSHUGAKU_SYURYO_BI,
                                        CSGKBTGAKUREIBO.HUSHUGAKU_RIYU,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_CD,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_NYUGAKU_BI,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_BI,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_TENGAKU_BI,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_TENGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_TAIGAKU_BI,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_TAIGAKU_GAKUNEN,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_SOTSUGYO_BI,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_KAISI_BI,
                                        CSGKBTGAKUREIBO.KUNISHIRITSU_SYURYO_BI,
                                        CSGKBTGAKUREIBO.TSUSHOMEI_KANA,
                                        CSGKBTGAKUREIBO.TSUSHOMEI_KANJI,
                                        CSGKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA,
                                        CSGKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI,
                                        --2024/12/27 JIP.Y.SATO UPD ST
                                        --CSGKBTGAKUREIBO.GRB_HENKO_TODOKEDE_BI,
                                        --CSGKBTGAKUREIBO.GRB_HENKO_BI,
                                        TO_NUMBER(VSYSDATE),
                                        TO_NUMBER(VSYSDATE),
                                        --2024/12/27 JIP.Y.SATO UPD ED
                                        14,
                                        CSGKBTGAKUREIBO.BIKO,
                                        --2024/12/27 JIP.Y.SATO UPD ST
                                        --CSGKBTGAKUREIBO.IDO_BI,
                                        --CSGKBTGAKUREIBO.TODOKEDE_BI,
                                        TO_NUMBER(VSYSDATE),
                                        TO_NUMBER(VSYSDATE),
                                        --2024/12/27 JIP.Y.SATO UPD ED
                                        CSGKBTGAKUREIBO.SHINSEI_KANRI_RENBAN,
                                        CSGKBTGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN,
                                        CSGKBTGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN,
                                        CSGKBTGAKUREIBO.SHOGAKKOKU_CD,
                                        CSGKBTGAKUREIBO.CHUGAKKOKU_CD,
                                        CSGKBTGAKUREIBO.SAKUJO_FLG,
                                        CSGKBTGAKUREIBO.SYS_TANMATU_BASHO);
              -- 学年履歴 更新したレコードの履歴連番取得する        
              BEGIN             
                SELECT * INTO CSGKBTGAKUNENRIREKI FROM GKBTGAKUNENRIREKI
                WHERE SAISIN_FLG = 0
                AND GKBTGAKUNENRIREKI.KOJIN_NO = CRWK_GAKUKYU_SETTEI_W.KOJIN_NO; 
              EXCEPTION
                WHEN OTHERS THEN
                  RAISE eEXCEPTION;
              END;
              -- DB・ファイル等更新説明書（学年履歴_U）
              UPDATE GKBTGAKUNENRIREKI SET
              SAISIN_FLG = 1
              ,SYS_KOSHINBI = TO_NUMBER(VSYSDATE)
              ,SYS_JIKAN  =  g_nTIME
              ,SYS_SHOKUINKOJIN_NO  =  g_sTANTOCODE
              ,SYS_TANMATU_NO = g_sWSNUM
              WHERE
              SAISIN_FLG = 0
              AND GKBTGAKUNENRIREKI.KOJIN_NO = CRWK_GAKUKYU_SETTEI_W.KOJIN_NO;
              -- DB・ファイル等更新説明書（学年履歴_I）
              INSERT INTO GKBTGAKUNENRIREKI VALUES(
                          CSGKBTGAKUNENRIREKI.KOJIN_NO,
                          CSGKBTGAKUNENRIREKI.NENDO,
                          CRWK_GAKUKYU_SETTEI_W.RIREKI_RENBAN + 10,
                          CSGKBTGAKUNENRIREKI.GAKUNEN_RIREKI_RENBAN + 10,
                          CSGKBTGAKUNENRIREKI.GAKKO_KBN_CD,
                          CSGKBTGAKUNENRIREKI.GAKKO_CD,
                          0,
                          CSGKBTGAKUNENRIREKI.GAKUKYU_KBN,
                          CRWK_GAKUKYU_SETTEI_W.GAKUKYU_CD,
                          CSGKBTGAKUNENRIREKI.GAKUNEN,
                          CSGKBTGAKUNENRIREKI.SAKUJO_FLG,
                          CSGKBTGAKUNENRIREKI.SYS_SAKUSEIBI,
                          TO_NUMBER(VSYSDATE),
                          g_nTIME,
                          g_sTANTOCODE,
                          g_sWSNUM);
--2024/03/19 ZCZL.GUOXIAOZHU Add end
          -- 変数.更新件数に1をカウントする。
          ICOUNT := ICOUNT + 1;
          END LOOP;
        EXCEPTION
        WHEN OTHERS THEN
          -- 3-2.学齢簿を更新する処理で異常終了した場合に出力する。
          VLOG := FUNC_GET_LOG('学齢簿を更新する処理で異常終了しました。');
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_GAKUKYU', 1, SQLCODE, SQLERRM, VLOG, g_sTANTOCODE, g_sWSNUM, 1);
          RETURN 1;
        END;
        -- 3-2.学齢簿を更新する処理が正常終了した場合に出力する。
        VLOG := FUNC_GET_LOG('学齢簿を更新する処理が正常終了しました。');
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_GAKUKYU', 0, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN 0;
    EXCEPTION
        WHEN OTHERS THEN
        RETURN 1;
    END FUNC_SET_GAKUKYU;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                      --戻り値
        eEXCEPTION                    EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        DELETE FROM GKBWL460R001 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
        g_nINDEX := g_oKENSU_LIST.COUNT;

        -- 1.初期処理
        NRTN_G := FUNC_GET_JOKEN;
        IF NRTN_G <> 0 THEN
            RAISE eEXCEPTION;
        END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発
        -- 排他処理
        NRTN_G := FUNC_GET_FKHTSET;
        IF NRTN_G <> 0 THEN
            RAISE eEXCEPTION;
        END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Add end    
        -- 2.準備処理
        NRTN_G := FUNC_JUNBI_SHORI;
        IF NRTN_G <> 0 THEN
            RAISE eEXCEPTION;
        END IF;
        -- ※変数.処理区分=2（更新あり）の場合、実行する
        IF VSHORI_KUBUN = 2 THEN
            -- 3.メーン処理
            NRTN_G := FUNC_SET_GAKUKYU;
            IF NRTN_G <> 0 THEN
               RAISE eEXCEPTION;
            END IF;
            IF NOT FUNC_CHECK_KENSUU('学齢簿を更新しなかった件数【 項目エラー等（汎用エラーリストに出力）】') THEN
              g_nINDEX := g_nINDEX + 1;
              g_oKENSU_LIST.EXTEND(1);
              g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NERROR_KENSU,'処理　' || '学齢簿を更新しなかった件数【 項目エラー等（汎用エラーリストに出力）】',0);
            END IF;
            -- 4.件数表ＣＳＶ作成処理
            -- 4-1.更新件数を件数表へセット
            -- 4-1-1.共通関数（FUNC_CHECK_KENSUU）を使用し、OUTPUTデータを件数表データテーブルにセットする。
            IF NOT FUNC_CHECK_KENSUU('学齢簿の更新件数') THEN
              g_nINDEX := g_nINDEX + 1;
              g_oKENSU_LIST.EXTEND(1);
              g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(ICOUNT,'出力　' || '学齢簿の更新件数',2);
            END IF;
        END IF;
        
        --帳票出力CSVの作成
        CASE g_rJSTP.Chohyoid
          WHEN 'GKB460R001' THEN
            bRTN :=FUNC_B11CSV('GKBWL460R001');
          ELSE
            NULL;
        END CASE;

        --関数終了
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
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;    --戻り値
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
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
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
    --------------------------------------------------------
    --  機能概要      : バッチ処理の呼出
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                : o_nRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.DINGHONGRUI   2024/1/2
    --------------------------------------------------------
    PROCEDURE PBATCH(i_nJOBNUM  IN  NUMBER,
                     o_nRESULT  OUT NUMBER)
    IS
        ePRMEXCEPTION                 EXCEPTION;                --パラメータ取得異常タイプ
        eSHORIEXCEPTION               EXCEPTION;                --処理異常タイプ
        bRTN                          BOOLEAN;                  --戻り値
        aSTEPSEQ_TBL                  KKBPK5551.tySTEPSEQ_Tbl;  --処理ステップ連番
        nSTEPSEQ_MAX                  NUMBER;                   --処理ステップレコード数
--2024/06/19 ZCZL.GUOXIAOZHU Add 0.3.000.000:新WizLIFE２次開発
        iRTN                          NUMBER;                   --戻り値
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
        PROC_KENSUSET;
        --終了処理
        bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
        COMMIT;
--2024/06/19 ZCZL.GUOXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発        
        IF BHAITA_CHU THEN
            iRTN := GKBFKHTCLR(2, '999999999999');
        END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Add end     
    EXCEPTION
        WHEN ePRMEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
        WHEN eSHORIEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM)   ;
            ROLLBACK;
--2024/06/19 ZCZL.GUOXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発 
            IF BHAITA_CHU THEN
                iRTN := GKBFKHTCLR(2, '999999999999');
            END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Add end 
        WHEN OTHERS THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
--2024/06/19 ZCZL.GUOXIAOZHU Add start 0.3.000.000:新WizLIFE２次開発 
            IF BHAITA_CHU THEN
                iRTN := GKBFKHTCLR(2, '999999999999');
            END IF;
--2024/06/19 ZCZL.GUOXIAOZHU Add end 
    END PBATCH;
END GKBPC00110;
/