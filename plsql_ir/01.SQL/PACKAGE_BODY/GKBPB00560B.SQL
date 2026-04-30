CREATE OR REPLACE PACKAGE BODY GKBPB00560
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 抑止対象者一覧作成
--  機能概要      : 抑止対象者を抽出し、抑止対象者一覧を作成する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.shixinyu   2024/06/14
--------------------------------------------------------
--  変更履歴
--  2024/08/30 ZCZL.xiaoya Update 0.3.000.001:IT_GKB_00075対応
--  2024/09/14 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00114対応の横展開
--  2024/11/07 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00415仕様変更対応
--  2025/02/08 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:ST_GKB_TMP00040仕様変更対応
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
    g_nTIME                       NUMBER;                      --システム時間
    g_nREBAN                      NUMBER := 0;                 --連番
    g_nINDEX                      NUMBER := 0;
    g_oKENSU_LIST                 GKBEKENSU_LIST := GKBEKENSU_LIST();

    --変数宣言
    g_nSORT                       NUMBER := 0;                 --ソート順
    g_sSEYIGYO                    NVARCHAR2(1000);             --抑止対象者一覧表_出力制御
    g_nJYOUKEN02                  NUMBER;                      --基準日（西暦）
    
    --画面入力条件 
    g_vJYOUKEN01                  NVARCHAR2(1000);
    g_vJYOUKEN02                  NVARCHAR2(1000);

    --パラメータ変数
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
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
        sSTEP_NAME                    NVARCHAR2(1000);   --ステップ名
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
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
        g_nTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));   --システム時間

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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
-- 2024/08/30 ZCZL.xiaoya Add 0.3.000.001:IT_GKB_00075対応
        stxtTakeObject                      DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        --抽出対象
-- 2024/08/30 ZCZL.xiaoya Update start 0.3.000.001:IT_GKB_00075対応
--         g_vJYOUKEN01 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtTakeObject');
        stxtTakeObject := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'txtTakeObject');
        g_vJYOUKEN01 := stxtTakeObject(1);
-- 2024/08/30 ZCZL.xiaoya Update end
        --基準日
        g_vJYOUKEN02 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtBaseDateYmd');
        IF g_vJYOUKEN02 IS NULL THEN
          g_vJYOUKEN02 := '0';
        END IF;
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN       BOOLEAN;          --戻り値
        VMSG       NVARCHAR2(4000);  --エラーメッセージ
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
       --入力値チェック
       --抽出対象必須入力ﾁｪｯｸ
       IF g_vJYOUKEN01 IS NULL THEN
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00114対応の横展開
--           o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ', 99999, *抽出対象が入力ありません。,;';
           o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,*抽出対象が入力ありません。,;';
       END IF;
       --基準日の数値型変換ﾁｪｯｸ
       bRTN := KKAPK0010.FISNUMERIC(g_vJYOUKEN02);
       IF bRTN THEN
         --基準日の日付チェック
         IF g_vJYOUKEN02 <> '0' THEN
           bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN02));
           IF NOT bRTN THEN
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00114対応の横展開
--             o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ', 99999, 基準日が正しくありません。,;';
             o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
           END IF;
         END IF;
       ELSE
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00114対応の横展開
--         o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ', 99999, 基準日が正しくありません。,;';
         o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
       END IF;
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
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
    --  機能概要      : 条件取得処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET
        RETURN BOOLEAN
    IS
    BEGIN
      --基準日(和暦日付を西暦日付に変換する)
      g_nJYOUKEN02 := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vJYOUKEN02));
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_JYOKEN_GET;
    --------------------------------------------------------
    --  機能概要      : 初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
    --------------------------------------------------------
    FUNCTION FUNC_INIT
        RETURN BOOLEAN
    IS
        bRTN                    BOOLEAN;                    --戻り値
        nRTN                    PLS_INTEGER;                --戻る値
        aITEM                   A_CONS_PRM;                 --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        sINDEXNO                NUMBER;                     --変数.抑止対象者一覧表_インデックス番号
    BEGIN
      --システム制御設定を取得する
        -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aITEM);
        --「GKB712R001」が格納されている箇所のインデックス番号
        IF nRTN = 0 THEN
          FOR i IN 1..aITEM.COUNT LOOP
            IF aITEM(i) = 'GKB712R001' THEN
              sINDEXNO := i;
              EXIT;
            END IF;
          END LOOP;
        END IF;
        -- 「本名・通称名　出力制御」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aITEM);
        IF nRTN = 0 AND sINDEXNO <= aITEM.COUNT THEN
          g_sSEYIGYO := aITEM(sINDEXNO);
        END IF;
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_INIT;
    --------------------------------------------------------
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE
        RETURN NUMBER
    IS
        bRTN                            BOOLEAN;                               --戻り値
        nRTN                            PLS_INTEGER;                           --戻る値
        nCOUNT                          PLS_INTEGER;                           --抽出件数
        sSQL                            VARCHAR2(10000);
        sSQL2                           VARCHAR2(10000);
        sSQL3                           VARCHAR2(10000);
        sSQL4                           VARCHAR2(5000);
        TYPE MC_CURSOR IS REF           CURSOR;                                --カーソルタイプ定義
        cCURSOR                         MC_CURSOR;
        cCURSORWL                       MC_CURSOR;
        rGKBTGAKUREIBO                  GKBTGAKUREIBO%ROWTYPE;                 --学齢簿
        rGACTIDOHAKKOYOKUSHIKANRIA      GACTIDOHAKKOYOKUSHIKANRI%ROWTYPE;      --異動発行抑止管理　A_児童生徒
        rGACTIDOHAKKOYOKUSHIKANRIB      GACTIDOHAKKOYOKUSHIKANRI%ROWTYPE;      --異動発行抑止管理　B_保護者
        rGABTATENAKIHONC                GABTATENAKIHON%ROWTYPE;                --宛名基本　C_児童生徒
        rGABTATENAKIHOND                GABTATENAKIHON%ROWTYPE;                --宛名基本　D_保護者
        rGKBWYOKUSHITAISHO              GKBWYOKUSHITAISHO%ROWTYPE;             --抑止対象者一覧中間ワーク
        rWLTBL                          GKBWL712R001%ROWTYPE;                  --抑止対象者一覧ワーク
        sMEISHO                         NVARCHAR2(1000);                       --名称
        sMEISHOKANA                     NVARCHAR2(1000);                       --名称カナ
        sYOBI                           NVARCHAR2(1000);                       --予備
        vZOKUGARAMEI                    NVARCHAR2(1000);                       --続柄名称
        nIHERR                          PLS_INTEGER;                           --エラーコード
        sKOKUMEI_KANA                   NVARCHAR2(1000);                       --国名カナ
        sKOKUMEI                        NVARCHAR2(1000);                       --国名
        sKOKUMEI_ALPHABET               NVARCHAR2(1000);                       --国名アルファベット
        nGAKKO_CD                       NUMBER;                                --学校等コード
        sSHIMEIKANA                     NVARCHAR2(1000);                       --氏名カナ
        sSHIMEIKANJI                    NVARCHAR2(1000);                       --氏名
        sSEINENGAPI                     NVARCHAR2(1000);                       --生年月日

    BEGIN
      --抑止対象者象者一覧カーソル
      sSQL := '';
      sSQL := 'SELECT';
      sSQL := sSQL || ' GKBTGAKUREIBO.HOGOSYA_KOJIN_NO'; 
      sSQL := sSQL || ',GKBTGAKUREIBO.KOJIN_NO'; 
      --  2024/11/07 ZCZL.ZHANGLEI UPDATE START 0.3.000.004:IT_GKB_00415仕様変更対応
      --sSQL := sSQL || ',GKBTGAKUREIBO.ZOKUGARA1'; 
      --sSQL := sSQL || ',GKBTGAKUREIBO.ZOKUGARA2'; 
      --sSQL := sSQL || ',GKBTGAKUREIBO.ZOKUGARA3'; 
      --sSQL := sSQL || ',GKBTGAKUREIBO.ZOKUGARA4'; 
      sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1';
      sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2';
      sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3';
      sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4';
      --  2024/11/07 ZCZL.ZHANGLEI UPDATE END
      sSQL := sSQL || ',GKBTGAKUREIBO.SYOGAKO_CD'; 
      sSQL := sSQL || ',GKBTGAKUREIBO.TYUGAKO_CD'; 
      sSQL := sSQL || ',GKBTGAKUREIBO.KUIKIGAI_CD'; 
      sSQL := sSQL || ',GKBTGAKUREIBO.YOGOGAKO_CD'; 
      sSQL := sSQL || ',GKBTGAKUREIBO.KUNISHIRITSU_CD'; 
      sSQL := sSQL || ',GKBTGAKUREIBO.GAKUNEN'; 
      sSQL := sSQL || ',GKBTGAKUREIBO.GAKKO_KBN_CD'; 
      sSQL := sSQL || ',GKBTGAKUREIBO.GAKUKYU_CD'; 
      sSQL := sSQL || ',GKBTGAKUREIBO.TENNYUMAE_GAKKO_KBN';
      sSQL := sSQL || ',A.KOJIN_NO';
      sSQL := sSQL || ',A.KOJINSETAIKBN'; 
      sSQL := sSQL || ',A.YOKUSHIKBN'; 
      sSQL := sSQL || ',A.YOKUSHISHURYOKBN'; 
      sSQL := sSQL || ',A.IDOYOKUSHIUMU'; 
      sSQL := sSQL || ',A.IDOYOKUSHI_GAITO_KBN'; 
      sSQL := sSQL || ',A.IDOYOKUSHIKAISHIBI'; 
      sSQL := sSQL || ',A.IDOYOKUSHISHURYOBI'; 
      sSQL := sSQL || ',A.HAKKOYOKUSHIUMU'; 
      sSQL := sSQL || ',A.HAKKOYOKUSHI_GAITO_KBN'; 
      sSQL := sSQL || ',A.HAKKOYOKUSHIKAISHIBI'; 
      sSQL := sSQL || ',A.HAKKOYOKUSHISHURYOBI'; 
      sSQL := sSQL || ',A.SHOKAIYOKUSHIUMU'; 
      sSQL := sSQL || ',A.SHOKAIYOKUSHI_GAITO_KBN'; 
      sSQL := sSQL || ',A.SHOKAIYOKUSHIKAISHIBI'; 
      sSQL := sSQL || ',A.SHOKAIYOKUSHISHURYOBI'; 
      sSQL := sSQL || ',B.KOJIN_NO';
      sSQL := sSQL || ',B.KOJINSETAIKBN'; 
      sSQL := sSQL || ',B.YOKUSHIKBN'; 
      sSQL := sSQL || ',B.YOKUSHISHURYOKBN'; 
      sSQL := sSQL || ',B.IDOYOKUSHIUMU'; 
      sSQL := sSQL || ',B.IDOYOKUSHI_GAITO_KBN'; 
      sSQL := sSQL || ',B.IDOYOKUSHIKAISHIBI'; 
      sSQL := sSQL || ',B.IDOYOKUSHISHURYOBI'; 
      sSQL := sSQL || ',B.HAKKOYOKUSHIUMU'; 
      sSQL := sSQL || ',B.HAKKOYOKUSHI_GAITO_KBN'; 
      sSQL := sSQL || ',B.HAKKOYOKUSHIKAISHIBI'; 
      sSQL := sSQL || ',B.HAKKOYOKUSHISHURYOBI'; 
      sSQL := sSQL || ',B.SHOKAIYOKUSHIUMU'; 
      sSQL := sSQL || ',B.SHOKAIYOKUSHI_GAITO_KBN'; 
      sSQL := sSQL || ',B.SHOKAIYOKUSHIKAISHIBI'; 
      sSQL := sSQL || ',B.SHOKAIYOKUSHISHURYOBI'; 
      sSQL := sSQL || ',C.SHIMEI_KANA'; 
      sSQL := sSQL || ',C.SHIMEI_KANJI'; 
      sSQL := sSQL || ',C.HYOJI_SEINENGAPI'; 
      sSQL := sSQL || ',C.SEIBETSU'; 
      sSQL := sSQL || ',C.KOKUSEKI_CD'; 
      sSQL := sSQL || ',D.SHIMEI_KANA'; 
      sSQL := sSQL || ',D.SHIMEI_KANJI'; 
      sSQL := sSQL || ',D.HYOJI_SEINENGAPI'; 
      sSQL := sSQL || ',D.SEIBETSU'; 
      sSQL := sSQL || ',D.KOKUSEKI_CD'; 
      --  2025/02/08 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:ST_GKB_TMP00040仕様変更対応 Start
      /*
      sSQL := sSQL || ' FROM GKBTGAKUREIBO, GACTIDOHAKKOYOKUSHIKANRI A, GACTIDOHAKKOYOKUSHIKANRI B, GABTATENAKIHON C, GABTATENAKIHON D'; 
      sSQL := sSQL || ' WHERE A.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO'; 
      sSQL := sSQL || ' AND B.KOJIN_NO = GKBTGAKUREIBO.HOGOSYA_KOJIN_NO'; 
      sSQL := sSQL || ' AND A.RIREKI_RENBAN = GKBTGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN';
      sSQL := sSQL || ' AND B.RIREKI_RENBAN = GKBTGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN';
      sSQL := sSQL || ' AND A.RIREKI_RENBAN = (SELECT MAX(E.RIREKI_RENBAN) FROM GACTIDOHAKKOYOKUSHIKANRI E '; 
      sSQL := sSQL || ' WHERE A.KOJIN_NO = E.KOJIN_NO AND A.SYSTEM_TYP = E.SYSTEM_TYP AND A.TOROKU_GYOMU = E.TOROKU_GYOMU)'; 
      sSQL := sSQL || ' AND B.RIREKI_RENBAN = (SELECT MAX(F.RIREKI_RENBAN) FROM GACTIDOHAKKOYOKUSHIKANRI F ';
      sSQL := sSQL || ' WHERE B.KOJIN_NO = F.KOJIN_NO AND B.SYSTEM_TYP = F.SYSTEM_TYP AND B.TOROKU_GYOMU = F.TOROKU_GYOMU)';
      sSQL := sSQL || ' AND A.SYSTEM_TYP = ''10'''; 
      sSQL := sSQL || ' AND B.SYSTEM_TYP = ''10''';
      sSQL := sSQL || ' AND C.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO'; 
      sSQL := sSQL || ' AND D.KOJIN_NO = GKBTGAKUREIBO.HOGOSYA_KOJIN_NO'; 
      sSQL := sSQL || ' AND A.TOROKU_GYOMU IN(''GKB'',''JIB'')'; 
      sSQL := sSQL || ' AND B.TOROKU_GYOMU IN(''GKB'',''JIB'')'; 
      --児童生徒と保護者は抑止対象
      IF g_vJYOUKEN01 = '0' THEN
        sSQL2 := '';
        sSQL2 := sSQL2 || sSQL;
        sSQL2 := sSQL2 || ' AND GKBTGAKUREIBO.SAISHIN_KBN = ''0''';
        sSQL2 := sSQL2 || ' AND GKBTGAKUREIBO.SAKUJO_FLG = ''0''';
        sSQL2 := sSQL2 || ' AND ((A.IDOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND A.IDOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (A.HAKKOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND A.HAKKOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (A.SHOKAIYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND A.SHOKAIYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' AND A.YOKUSHIKBN IN (1, 2, 4))';
        sSQL2 := sSQL2 || ' AND ((B.IDOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND B.IDOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (B.HAKKOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND B.HAKKOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (B.SHOKAIYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND B.SHOKAIYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' AND B.YOKUSHIKBN IN (1, 2, 4))';
        sSQL3 := sSQL2;
      END IF;
      --児童生徒は抑止対象外、保護者は抑止対象
      IF g_vJYOUKEN01 = '1' THEN
        sSQL2 := '';
        sSQL2 := sSQL2 || sSQL;
        sSQL2 := sSQL2 || ' AND GKBTGAKUREIBO.SAISHIN_KBN = ''0''';
        sSQL2 := sSQL2 || ' AND GKBTGAKUREIBO.SAKUJO_FLG = ''0''';
        sSQL2 := sSQL2 || ' AND ((A.IDOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND A.IDOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (A.HAKKOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND A.HAKKOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (A.SHOKAIYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND A.SHOKAIYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' AND A.YOKUSHIKBN IN (1, 2, 4))';
        sSQL2 := sSQL2 || ' AND ((B.IDOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND B.IDOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (B.HAKKOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND B.HAKKOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (B.SHOKAIYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND B.SHOKAIYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' AND B.YOKUSHIKBN IN (1, 2, 4))';
        sSQL2 := sSQL2 || ' UNION ALL ';
        sSQL2 := sSQL2 || sSQL;
        sSQL2 := sSQL2 || ' AND GKBTGAKUREIBO.SAISHIN_KBN = ''0''';
        sSQL2 := sSQL2 || ' AND GKBTGAKUREIBO.SAKUJO_FLG = ''0''';
        sSQL2 := sSQL2 || ' AND (A.IDOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' OR A.HAKKOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' OR A.SHOKAIYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' AND A.YOKUSHIKBN NOT IN (1, 2, 4)';
        sSQL2 := sSQL2 || ' AND ((B.IDOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND B.IDOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (B.HAKKOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND B.HAKKOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (B.SHOKAIYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND B.SHOKAIYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' AND B.YOKUSHIKBN IN (1, 2, 4))';
        sSQL2 := sSQL2 || ' UNION ALL ';
        sSQL2 := sSQL2 || sSQL;
        sSQL2 := sSQL2 || ' AND GKBTGAKUREIBO.SAISHIN_KBN = ''0''';
        sSQL2 := sSQL2 || ' AND GKBTGAKUREIBO.SAKUJO_FLG = ''0''';
        sSQL2 := sSQL2 || ' AND (B.IDOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' OR B.HAKKOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' OR B.SHOKAIYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' AND B.YOKUSHIKBN NOT IN (1, 2, 4)';
        sSQL2 := sSQL2 || ' AND ((A.IDOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND A.IDOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (A.HAKKOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND A.HAKKOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' OR (A.SHOKAIYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
        sSQL2 := sSQL2 || ' AND A.SHOKAIYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
        sSQL2 := sSQL2 || ' AND A.YOKUSHIKBN IN (1, 2, 4))';
        sSQL3 := sSQL2;
        */
        sSQL := sSQL || ' FROM GKBTGAKUREIBO';
        sSQL := sSQL || ' LEFT JOIN GACTIDOHAKKOYOKUSHIKANRI A ON A.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO';
        sSQL := sSQL || ' LEFT JOIN GACTIDOHAKKOYOKUSHIKANRI B ON B.KOJIN_NO = GKBTGAKUREIBO.HOGOSYA_KOJIN_NO';
        sSQL := sSQL || ' LEFT JOIN GABTATENAKIHON C ON C.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO';
        sSQL := sSQL || ' LEFT JOIN GABTATENAKIHON D ON D.KOJIN_NO = GKBTGAKUREIBO.HOGOSYA_KOJIN_NO';
        sSQL := sSQL || ' WHERE A.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO';
        sSQL := sSQL || ' AND A.RIREKI_RENBAN = GKBTGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN ';
        sSQL := sSQL || ' AND A.RIREKI_RENBAN = (';
        sSQL := sSQL || ' SELECT MAX(E.RIREKI_RENBAN)';
        sSQL := sSQL || ' FROM GACTIDOHAKKOYOKUSHIKANRI E';
        sSQL := sSQL || ' WHERE A.KOJIN_NO = E.KOJIN_NO';
        sSQL := sSQL || ' AND A.SYSTEM_TYP = E.SYSTEM_TYP';
        sSQL := sSQL || ' AND A.TOROKU_GYOMU = E.TOROKU_GYOMU';
        sSQL := sSQL || ' )';
        sSQL := sSQL || ' AND A.SYSTEM_TYP = ''10''';
        sSQL := sSQL || ' AND C.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO';
        sSQL := sSQL || ' AND A.TOROKU_GYOMU IN (''GKB'', ''JIB'')';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.SAISHIN_KBN = ''0''';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.SAKUJO_FLG = ''0''';
        --sSQL := sSQL || 'AND B.KOJIN_NO IS NOT NULL';
        
        --児童生徒と保護者は抑止対象
        IF g_vJYOUKEN01 = '0' THEN
          sSQL2 := '';
          sSQL2 := sSQL2 || sSQL;
          sSQL2 := sSQL2 || ' AND ((A.IDOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
          sSQL2 := sSQL2 || ' AND A.IDOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
          sSQL2 := sSQL2 || ' OR (A.HAKKOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
          sSQL2 := sSQL2 || ' AND A.HAKKOYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
          sSQL2 := sSQL2 || ' OR (A.SHOKAIYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
          sSQL2 := sSQL2 || ' AND A.SHOKAIYOKUSHISHURYOBI >= '|| g_nJYOUKEN02 ||')';
          sSQL2 := sSQL2 || ' AND A.YOKUSHIKBN IN (1, 2, 4))';
          sSQL3 := sSQL2;
        END IF;
        --児童生徒は抑止対象外、保護者は抑止対象
      IF g_vJYOUKEN01 = '1' THEN
          sSQL2 := '';
          sSQL2 := sSQL2 || sSQL;
          sSQL2 := sSQL2 || ' AND ((A.IDOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
          sSQL2 := sSQL2 || ' OR A.HAKKOYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||'';
          sSQL2 := sSQL2 || ' OR A.SHOKAIYOKUSHIKAISHIBI <= '|| g_nJYOUKEN02 ||')';
          sSQL2 := sSQL2 || ' AND A.YOKUSHIKBN IN (1, 2, 4))';
          sSQL3 := sSQL2;
        --  2025/02/08 JPJYS.SONGSHIHAO UPDATE 0.3.000.005:ST_GKB_TMP00040仕様変更対応 End
      END IF;
      OPEN cCURSOR FOR sSQL3;
        LOOP
          FETCH cCURSOR INTO rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO
                             ,rGKBTGAKUREIBO.KOJIN_NO
                             --  2024/11/07 ZCZL.ZHANGLEI UPDATE START 0.3.000.004:IT_GKB_00415仕様変更対応
                             --,rGKBTGAKUREIBO.ZOKUGARA1
                             --,rGKBTGAKUREIBO.ZOKUGARA2
                             --,rGKBTGAKUREIBO.ZOKUGARA3
                             --,rGKBTGAKUREIBO.ZOKUGARA4
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA1
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA2
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA3
                             ,rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA4
                             --  2024/11/07 ZCZL.ZHANGLEI UPDATE END
                             ,rGKBTGAKUREIBO.SYOGAKO_CD
                             ,rGKBTGAKUREIBO.TYUGAKO_CD
                             ,rGKBTGAKUREIBO.KUIKIGAI_CD
                             ,rGKBTGAKUREIBO.YOGOGAKO_CD
                             ,rGKBTGAKUREIBO.KUNISHIRITSU_CD
                             ,rGKBTGAKUREIBO.GAKUNEN
                             ,rGKBTGAKUREIBO.GAKKO_KBN_CD
                             ,rGKBTGAKUREIBO.GAKUKYU_CD
                             ,rGKBTGAKUREIBO.TENNYUMAE_GAKKO_KBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.KOJIN_NO
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.KOJINSETAIKBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.YOKUSHIKBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.YOKUSHISHURYOKBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHIUMU
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHI_GAITO_KBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHIKAISHIBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHISHURYOBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHIUMU
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHI_GAITO_KBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHIKAISHIBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHISHURYOBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHIUMU
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHI_GAITO_KBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHIKAISHIBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHISHURYOBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.KOJIN_NO
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.KOJINSETAIKBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.YOKUSHIKBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.YOKUSHISHURYOKBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHIUMU
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHI_GAITO_KBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHIKAISHIBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHISHURYOBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHIUMU
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHI_GAITO_KBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHIKAISHIBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHISHURYOBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHIUMU
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHI_GAITO_KBN
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHIKAISHIBI
                             ,rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHISHURYOBI
                             ,rGABTATENAKIHONC.SHIMEI_KANA
                             ,rGABTATENAKIHONC.SHIMEI_KANJI
                             ,rGABTATENAKIHONC.HYOJI_SEINENGAPI
                             ,rGABTATENAKIHONC.SEIBETSU
                             ,rGABTATENAKIHONC.KOKUSEKI_CD
                             ,rGABTATENAKIHOND.SHIMEI_KANA
                             ,rGABTATENAKIHOND.SHIMEI_KANJI
                             ,rGABTATENAKIHOND.HYOJI_SEINENGAPI
                             ,rGABTATENAKIHOND.SEIBETSU
                             ,rGABTATENAKIHOND.KOKUSEKI_CD;
          EXIT WHEN cCURSOR%NOTFOUND;
          --和暦変換
          rGKBWYOKUSHITAISHO.SAKUSEIBI := KKAPK0020.FDateFmt(TO_CHAR(SYSDATE, 'YYYY/MM/DD'), 12);       --作成日
          --児童生徒の本名使用制御判定
          nRTN := GKBFKHMCTRL(rGKBTGAKUREIBO.KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_sSEYIGYO, sSHIMEIKANA, sSHIMEIKANJI, sSEINENGAPI);
          rGKBWYOKUSHITAISHO.JIDO_SHIMEI_KANA := sSHIMEIKANA;                                           --児童生徒氏名カナ
          rGKBWYOKUSHITAISHO.JIDO_SHIMEI_KANJI := sSHIMEIKANJI;                                         --児童生徒氏名漢字
          rGKBWYOKUSHITAISHO.HYOJI_SEINENGAPI := sSEINENGAPI;                                           --表示用生年月日
          --保護者の本名使用制御判定
          nRTN := GKBFKHMCTRL(rGKBTGAKUREIBO.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_sSEYIGYO, sSHIMEIKANA, sSHIMEIKANJI, sSEINENGAPI);
          rGKBWYOKUSHITAISHO.HOGOSHA_SHIMEI_KANA := sSHIMEIKANA;                                        --保護者氏名カナ
          rGKBWYOKUSHITAISHO.HOGOSHA_SHIMEI_KANJI := sSHIMEIKANJI;                                      --保護者氏名漢字
          --性別名取得
          nRTN := KKAPK0030.FCDGetR('GKB', '021', '0001', rGABTATENAKIHONC.SEIBETSU, sMEISHO, sMEISHOKANA, sYOBI); 
          rGKBWYOKUSHITAISHO.SEIBETSU := sMEISHO;                                                       --性別
          --柄名称取得
          --  2024/11/07 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00415仕様変更対応
          --nRTN := GKBFKZKGMGET(2, rGKBTGAKUREIBO.ZOKUGARA1, rGKBTGAKUREIBO.ZOKUGARA2, rGKBTGAKUREIBO.ZOKUGARA3, rGKBTGAKUREIBO.ZOKUGARA4, vZOKUGARAMEI, nIHERR);
          nRTN := GKBFKZKGMGET(2, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA1, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA2, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA3, rGKBTGAKUREIBO.HOGOSYA_ZOKUGARA4, vZOKUGARAMEI, nIHERR); 
          rGKBWYOKUSHITAISHO.HOGOSHA_KANKEI := vZOKUGARAMEI;                                            --児童生徒との関係
          --国名取得
          nRTN := GKAFKKKMGET(rGABTATENAKIHONC.KOKUSEKI_CD, sKOKUMEI_KANA, sKOKUMEI, sKOKUMEI_ALPHABET);
          rGKBWYOKUSHITAISHO.JIDO_KOKUSEKI := sKOKUMEI;                                                 --児童生徒国籍
          --保護者国籍取得
          nRTN := GKAFKKKMGET(rGABTATENAKIHOND.KOKUSEKI_CD, sKOKUMEI_KANA, sKOKUMEI, sKOKUMEI_ALPHABET);
          rGKBWYOKUSHITAISHO.HOGOSHA_KOKUSEKI := sKOKUMEI;                                               --保護者国籍
          --学校等コード
          IF rGKBTGAKUREIBO.GAKKO_KBN_CD = 1 THEN 
            nGAKKO_CD := rGKBTGAKUREIBO.SYOGAKO_CD;                 --小学校コード
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 2 THEN
            nGAKKO_CD := rGKBTGAKUREIBO.TYUGAKO_CD;                 --中学校コード
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 3 THEN
            nGAKKO_CD := rGKBTGAKUREIBO.YOGOGAKO_CD;                --盲聾養護学校コード
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 4 THEN
            nGAKKO_CD := rGKBTGAKUREIBO.KUIKIGAI_CD;                --区域外学校コード
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 5 THEN
            nGAKKO_CD := rGKBTGAKUREIBO.KUNISHIRITSU_CD;            --国私立学校コード
          END IF;
          rGKBWYOKUSHITAISHO.GAKKO_MEI := GKAFKGKOGTEQ(rGKBTGAKUREIBO.GAKKO_KBN_CD, nGAKKO_CD);         --学校名
          rGKBWYOKUSHITAISHO.GAKUNEN := GKAFKGKNGTEQ(rGKBTGAKUREIBO.GAKUNEN);                           --学年
          IF rGACTIDOHAKKOYOKUSHIKANRIA.YOKUSHIKBN IS NOT NULL AND rGKBTGAKUREIBO.KOJIN_NO = rGACTIDOHAKKOYOKUSHIKANRIA.KOJIN_NO THEN
            rGKBWYOKUSHITAISHO.JIDO_YOKUSHITAISHO := '児童生徒';                                         --児童生徒抑止対象
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIB.YOKUSHIKBN IS NOT NULL  AND rGKBTGAKUREIBO.HOGOSYA_KOJIN_NO = rGACTIDOHAKKOYOKUSHIKANRIB.KOJIN_NO THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_YOKUSHITAISHO := '保護者';                                        --保護者抑止対象
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIA.KOJINSETAIKBN = 0 THEN
            rGKBWYOKUSHITAISHO.JIDO_KOJINSETAIKBN := '個人';                                             --児童生徒個人世帯区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.KOJINSETAIKBN = 1 THEN
            rGKBWYOKUSHITAISHO.JIDO_KOJINSETAIKBN := '世帯';                                             --児童生徒個人世帯区分
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIB.KOJINSETAIKBN = 0 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_KOJINSETAIKBN := '個人';                                          --保護者個人世帯区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.KOJINSETAIKBN = 1 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_KOJINSETAIKBN := '世帯';                                          --保護者個人世帯区分
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIA.YOKUSHIKBN = 1 OR rGACTIDOHAKKOYOKUSHIKANRIA.YOKUSHIKBN = 2 THEN
            rGKBWYOKUSHITAISHO.JIDO_YOKUSHIKBN := '支援措置';                                            --児童生徒抑止区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.YOKUSHIKBN = 4 THEN
            rGKBWYOKUSHITAISHO.JIDO_YOKUSHIKBN := 'その他抑止';                                           --児童生徒抑止区分
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIB.YOKUSHIKBN = 1 OR rGACTIDOHAKKOYOKUSHIKANRIB.YOKUSHIKBN = 2 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_YOKUSHIKBN := '支援措置';                                         --保護者抑止区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.YOKUSHIKBN = 4 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_YOKUSHIKBN := 'その他抑止';                                        --保護者抑止区分
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIA.YOKUSHISHURYOKBN = 3 THEN
            rGKBWYOKUSHITAISHO.JIDO_YKSSHURYOKBN := '措置終了';                                          --児童生徒抑止終了区分
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIB.YOKUSHISHURYOKBN = 3 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_YKSSHURYOKBN := '措置終了';                                       --児童生徒抑止終了区分
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHIUMU = 0 THEN
            rGKBWYOKUSHITAISHO.JIDO_IDOYOKUSHIUMU := '無';                                               --児童生徒異動抑止
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHIUMU = 1 THEN
            rGKBWYOKUSHITAISHO.JIDO_IDOYOKUSHIUMU := '有';                                               --児童生徒異動抑止
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHI_GAITO_KBN = 0 THEN
            rGKBWYOKUSHITAISHO.JIDO_IDOYOKUSHI_KBN := '非該当';                                          --児童生徒異動抑止
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHI_GAITO_KBN = 1 THEN
            rGKBWYOKUSHITAISHO.JIDO_IDOYOKUSHI_KBN := '警告エラー';                                        --児童生徒異動抑止
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHI_GAITO_KBN = 2 THEN
            rGKBWYOKUSHITAISHO.JIDO_IDOYOKUSHI_KBN := '論理エラー';                                        --児童生徒異動抑止
          END IF;
          --児童生徒異動抑止・開始日
          rGKBWYOKUSHITAISHO.JIDO_IDOYKSKAISHIBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHIKAISHIBI, 0, 3, 0, '*');
          --児童生徒異動抑止・終了日
          rGKBWYOKUSHITAISHO.JIDO_IDOYKSSHURYOBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIA.IDOYOKUSHISHURYOBI, 0, 3, 0, '*');
          IF rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHIUMU = 0 THEN
            rGKBWYOKUSHITAISHO.JIDO_HKYOKUSHIUMU := '無';                                                --児童生徒発行抑止
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHIUMU = 1 THEN
            rGKBWYOKUSHITAISHO.JIDO_HKYOKUSHIUMU := '有';                                                --児童生徒発行抑止
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHI_GAITO_KBN = 0 THEN
            rGKBWYOKUSHITAISHO.JIDO_HKYOKUSHI_KBN := '非該当';                                           --児童生徒発行抑止・区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHI_GAITO_KBN = 1 THEN
            rGKBWYOKUSHITAISHO.JIDO_HKYOKUSHI_KBN := '警告エラー';                                         --児童生徒発行抑止・区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHI_GAITO_KBN = 2 THEN
            rGKBWYOKUSHITAISHO.JIDO_HKYOKUSHI_KBN := '論理エラー';                                         --児童生徒発行抑止・区分
          END IF;
          --児童生徒発行抑止・開始日
          rGKBWYOKUSHITAISHO.JIDO_HKYKSKAISHIBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHIKAISHIBI, 0, 3, 0, '*');
          --児童生徒発行抑止・終了日
          rGKBWYOKUSHITAISHO.JIDO_HKYKSSHURYOBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIA.HAKKOYOKUSHISHURYOBI, 0, 3, 0, '*');
          IF rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHIUMU = 0 THEN
            rGKBWYOKUSHITAISHO.JIDO_SHOKAIYKSUMU := '無';                                                --児児童生徒照会抑止
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHIUMU = 1 THEN
            rGKBWYOKUSHITAISHO.JIDO_SHOKAIYKSUMU := '有';                                                --児童生徒照会抑止
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHI_GAITO_KBN = 0 THEN
            rGKBWYOKUSHITAISHO.JIDO_SKYOKUSHI_KBN := '非該当';                                           --児童生徒照会抑止・区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHI_GAITO_KBN = 1 THEN
            rGKBWYOKUSHITAISHO.JIDO_SKYOKUSHI_KBN := '警告エラー';                                         --児童生徒照会抑止・区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHI_GAITO_KBN = 2 THEN
            rGKBWYOKUSHITAISHO.JIDO_SKYOKUSHI_KBN := '論理エラー';                                         --児童生徒照会抑止・区分
          END IF;
          --児童生徒照会抑止・開始日
          rGKBWYOKUSHITAISHO.JIDO_SKYKSKAISHIBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHIKAISHIBI, 0, 3, 0, '*');
          --児童生徒照会抑止・終了日
          rGKBWYOKUSHITAISHO.JIDO_SKYKSSHURYOBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIA.SHOKAIYOKUSHISHURYOBI, 0, 3, 0, '*');
          
          IF rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHIUMU = 0 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_IDOYOKUSHIUMU := '無';                                              --保護者異動抑止
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHIUMU = 1 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_IDOYOKUSHIUMU := '有';                                              --保護者異動抑止
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHI_GAITO_KBN = 0 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_IDOYOKUSHI_KBN := '非該当';                                          --保護者異動抑止・区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHI_GAITO_KBN = 1 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_IDOYOKUSHI_KBN := '警告エラー';                                        --保護者異動抑止・区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHI_GAITO_KBN = 2 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_IDOYOKUSHI_KBN := '論理エラー';                                        --保護者異動抑止・区分
          END IF;
          --保護者異動抑止・開始日
          rGKBWYOKUSHITAISHO.HOGOSHA_IDOYKSKAISHIBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHIKAISHIBI, 0, 3, 0, '*');
          --保護者異動抑止・終了日
          rGKBWYOKUSHITAISHO.HOGOSHA_IDOYKSSHURYOBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIB.IDOYOKUSHISHURYOBI, 0, 3, 0, '*');
          IF rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHIUMU = 0 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_HKYOKUSHIUMU := '無';                                                --保護者発行抑止
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHIUMU = 1 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_HKYOKUSHIUMU := '有';                                                --保護者発行抑止
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHI_GAITO_KBN = 0 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_HKYOKUSHI_KBN := '非該当';                                           --保護者発行抑止・区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHI_GAITO_KBN = 1 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_HKYOKUSHI_KBN := '警告エラー';                                         --保護者発行抑止・区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHI_GAITO_KBN = 2 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_HKYOKUSHI_KBN := '論理エラー';                                         --保護者発行抑止・区分
          END IF;
          --保護者発行抑止・開始日
          rGKBWYOKUSHITAISHO.HOGOSHA_HKYKSKAISHIBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHIKAISHIBI, 0, 3, 0, '*');
          --保護者発行抑止・終了日
          rGKBWYOKUSHITAISHO.HOGOSHA_HKYKSSHURYOBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIB.HAKKOYOKUSHISHURYOBI, 0, 3, 0, '*');
          IF rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHIUMU = 0 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_SHOKAIYKSUMU := '無';                                                --保護者照会抑止
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHIUMU = 1 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_SHOKAIYKSUMU := '有';                                                --保護者照会抑止
          END IF;
          IF rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHI_GAITO_KBN = 0 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_SKYOKUSHI_KBN := '非該当';                                           --保護者照会抑止・区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHI_GAITO_KBN = 1 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_SKYOKUSHI_KBN := '警告エラー';                                         --保護者照会抑止・区分
          ELSIF rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHI_GAITO_KBN = 2 THEN
            rGKBWYOKUSHITAISHO.HOGOSHA_SKYOKUSHI_KBN := '論理エラー';                                         --保護者照会抑止・区分
          END IF;
          --保護者照会抑止・開始日
          rGKBWYOKUSHITAISHO.HOGOSHA_SKYKSKAISHIBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHIKAISHIBI, 0, 3, 0, '*');
          --保護者照会抑止・終了日
          rGKBWYOKUSHITAISHO.HOGOSHA_SKYKSSHURYOBI := KKAPK0020.FDAYEDIT20(rGACTIDOHAKKOYOKUSHIKANRIB.SHOKAIYOKUSHISHURYOBI, 0, 3, 0, '*');
          rGKBWYOKUSHITAISHO.KOJIN_NO := rGKBTGAKUREIBO.KOJIN_NO;                    --宛名番号（ソート用）
          rGKBWYOKUSHITAISHO.GAKKO_KBN_CD := rGKBTGAKUREIBO.GAKKO_KBN_CD;            --学校区分コード（ソート用）
          --学校コード（ソート用）
          IF rGKBTGAKUREIBO.GAKKO_KBN_CD = 1 THEN 
            rGKBWYOKUSHITAISHO.GAKKO_CD := rGKBTGAKUREIBO.SYOGAKO_CD;
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 2 THEN
            rGKBWYOKUSHITAISHO.GAKKO_CD := rGKBTGAKUREIBO.TYUGAKO_CD;
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 3 THEN
            rGKBWYOKUSHITAISHO.GAKKO_CD := rGKBTGAKUREIBO.YOGOGAKO_CD;
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 4 THEN
            rGKBWYOKUSHITAISHO.GAKKO_CD := rGKBTGAKUREIBO.KUIKIGAI_CD;
          ELSIF rGKBTGAKUREIBO.GAKKO_KBN_CD = 5 THEN
            rGKBWYOKUSHITAISHO.GAKKO_CD := rGKBTGAKUREIBO.KUNISHIRITSU_CD;
          END IF;
          rGKBWYOKUSHITAISHO.KIJUNBI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_nJYOUKEN02, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);       --基準日
          --登録中間ワークテーブル
          INSERT INTO GKBWYOKUSHITAISHO VALUES rGKBWYOKUSHITAISHO;
        END LOOP;
      CLOSE cCURSOR;
      --件数取得
      nCOUNT := GKBFKTBLCNT('GKBWYOKUSHITAISHO',NULL);
      --抑止対象者一覧中間カーソル
      sSQL4 := '';
      sSQL4 := 'SELECT *';
      sSQL4 := sSQL4 || ' FROM GKBWYOKUSHITAISHO'; 
--  2024/09/14 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.002:8月1日認識合わせの横展開
--      sSQL4 := sSQL4 || ' ORDER BY '||g_rJSTP.ORDERBYCLAUSE ;
      IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
           sSQL4 := sSQL4 || ' ORDER BY '|| g_rJSTP.ORDERBYCLAUSE ;
      END IF;
--  2024/09/14 ZCZL.LIUCHANGQUAN UPDATE END
      OPEN cCURSORWL FOR sSQL4;
        LOOP
          FETCH cCURSORWL INTO rGKBWYOKUSHITAISHO;
          EXIT WHEN cCURSORWL%NOTFOUND;
          g_nSORT := g_nSORT + 1;
          rWLTBL.NO := g_nSORT;                                                                           --ソート順
          rWLTBL.SAKUSEIBI := rGKBWYOKUSHITAISHO.SAKUSEIBI;                                               --作成日
          rWLTBL.JIDO_SHIMEI_KANA := rGKBWYOKUSHITAISHO.JIDO_SHIMEI_KANA;                                 --児童生徒氏名カナ
          rWLTBL.JIDO_SHIMEI_KANJI := rGKBWYOKUSHITAISHO.JIDO_SHIMEI_KANJI;                               --児童生徒氏名漢字
          rWLTBL.HYOJI_SEINENGAPI := rGKBWYOKUSHITAISHO.HYOJI_SEINENGAPI;                                 --表示用生年月日
          rWLTBL.HOGOSHA_SHIMEI_KANA := rGKBWYOKUSHITAISHO.HOGOSHA_SHIMEI_KANA;                           --保護者氏名カナ
          rWLTBL.HOGOSHA_SHIMEI_KANJI := rGKBWYOKUSHITAISHO.HOGOSHA_SHIMEI_KANJI;                         --保護者氏名漢字
          rWLTBL.SEIBETSU := rGKBWYOKUSHITAISHO.SEIBETSU;                                                 --性別
          rWLTBL.HOGOSHA_KANKEI := rGKBWYOKUSHITAISHO.HOGOSHA_KANKEI;                                     --児童生徒との関係
          rWLTBL.JIDO_KOKUSEKI := rGKBWYOKUSHITAISHO.JIDO_KOKUSEKI;                                       --児童生徒国籍
          rWLTBL.HOGOSHA_KOKUSEKI := rGKBWYOKUSHITAISHO.HOGOSHA_KOKUSEKI;                                 --保護者国籍
          rWLTBL.GAKKO_MEI := rGKBWYOKUSHITAISHO.GAKKO_MEI;                                               --学校名
          rWLTBL.GAKUNEN := rGKBWYOKUSHITAISHO.GAKUNEN;                                                   --学年
          rWLTBL.JIDO_YOKUSHITAISHO := rGKBWYOKUSHITAISHO.JIDO_YOKUSHITAISHO;                             --児童生徒抑止対象
          rWLTBL.HOGOSHA_YOKUSHITAISHO := rGKBWYOKUSHITAISHO.HOGOSHA_YOKUSHITAISHO;                       --保護者抑止対象
          rWLTBL.JIDO_KOJINSETAIKBN := rGKBWYOKUSHITAISHO.JIDO_KOJINSETAIKBN;                             --児童生徒個人世帯区分
          rWLTBL.HOGOSHA_KOJINSETAIKBN := rGKBWYOKUSHITAISHO.HOGOSHA_KOJINSETAIKBN;                       --保護者個人世帯区分
          rWLTBL.JIDO_YOKUSHIKBN := rGKBWYOKUSHITAISHO.JIDO_YOKUSHIKBN;                                   --児童生徒抑止区分
          rWLTBL.HOGOSHA_YOKUSHIKBN := rGKBWYOKUSHITAISHO.HOGOSHA_YOKUSHIKBN;                             --保護者抑止区分
          rWLTBL.JIDO_YKSSHURYOKBN := rGKBWYOKUSHITAISHO.JIDO_YKSSHURYOKBN;                               --児童生徒抑止終了区分
          rWLTBL.HOGOSHA_YKSSHURYOKBN := rGKBWYOKUSHITAISHO.HOGOSHA_YKSSHURYOKBN;                         --保護者抑止終了区分
          rWLTBL.JIDO_IDOYOKUSHIUMU := rGKBWYOKUSHITAISHO.JIDO_IDOYOKUSHIUMU;                             --児童生徒異動抑止
          rWLTBL.JIDO_IDOYOKUSHI_KBN := rGKBWYOKUSHITAISHO.JIDO_IDOYOKUSHI_KBN;                           --児童生徒異動抑止・区分
          rWLTBL.JIDO_IDOYKSKAISHIBI := rGKBWYOKUSHITAISHO.JIDO_IDOYKSKAISHIBI;                           --児童生徒異動抑止・開始日
          rWLTBL.JIDO_IDOYKSSHURYOBI := rGKBWYOKUSHITAISHO.JIDO_IDOYKSSHURYOBI;                           --児童生徒異動抑止・終了日
          rWLTBL.JIDO_HKYOKUSHIUMU := rGKBWYOKUSHITAISHO.JIDO_HKYOKUSHIUMU;                               --児童生徒発行抑止
          rWLTBL.JIDO_HKYOKUSHI_KBN := rGKBWYOKUSHITAISHO.JIDO_HKYOKUSHI_KBN;                             --児童生徒発行抑止・区分
          rWLTBL.JIDO_HKYKSKAISHIBI := rGKBWYOKUSHITAISHO.JIDO_HKYKSKAISHIBI;                             --児童生徒発行抑止・開始日
          rWLTBL.JIDO_HKYKSSHURYOBI := rGKBWYOKUSHITAISHO.JIDO_HKYKSSHURYOBI;                             --児童生徒発行抑止・終了日
          rWLTBL.JIDO_SHOKAIYKSUMU := rGKBWYOKUSHITAISHO.JIDO_SHOKAIYKSUMU;                               --児童生徒照会抑止
          rWLTBL.JIDO_SKYOKUSHI_KBN := rGKBWYOKUSHITAISHO.JIDO_SKYOKUSHI_KBN;                             --児童生徒照会抑止・区分
          rWLTBL.JIDO_SKYKSKAISHIBI := rGKBWYOKUSHITAISHO.JIDO_SKYKSKAISHIBI;                             --児童生徒照会抑止・開始日
          rWLTBL.JIDO_SKYKSSHURYOBI := rGKBWYOKUSHITAISHO.JIDO_SKYKSSHURYOBI;                             --児童生徒照会抑止・終了日
          rWLTBL.HOGOSHA_IDOYOKUSHIUMU := rGKBWYOKUSHITAISHO.HOGOSHA_IDOYOKUSHIUMU;                       --保護者異動抑止
          rWLTBL.HOGOSHA_IDOYOKUSHI_KBN := rGKBWYOKUSHITAISHO.HOGOSHA_IDOYOKUSHI_KBN;                     --保護者異動抑止・区分
          rWLTBL.HOGOSHA_IDOYKSKAISHIBI := rGKBWYOKUSHITAISHO.HOGOSHA_IDOYKSKAISHIBI;                     --保護者異動抑止・開始日
          rWLTBL.HOGOSHA_IDOYKSSHURYOBI := rGKBWYOKUSHITAISHO.HOGOSHA_IDOYKSSHURYOBI;                     --保護者異動抑止・終了日
          rWLTBL.HOGOSHA_HKYOKUSHIUMU := rGKBWYOKUSHITAISHO.HOGOSHA_HKYOKUSHIUMU;                         --保護者発行抑止
          rWLTBL.HOGOSHA_HKYOKUSHI_KBN := rGKBWYOKUSHITAISHO.HOGOSHA_HKYOKUSHI_KBN;                       --保護者発行抑止・区分
          rWLTBL.HOGOSHA_HKYKSKAISHIBI := rGKBWYOKUSHITAISHO.HOGOSHA_HKYKSKAISHIBI;                       --保護者発行抑止・開始日
          rWLTBL.HOGOSHA_HKYKSSHURYOBI := rGKBWYOKUSHITAISHO.HOGOSHA_HKYKSSHURYOBI;                       --保護者発行抑止・終了日
          rWLTBL.HOGOSHA_SHOKAIYKSUMU := rGKBWYOKUSHITAISHO.HOGOSHA_SHOKAIYKSUMU;                         --保護者照会抑止
          rWLTBL.HOGOSHA_SKYOKUSHI_KBN := rGKBWYOKUSHITAISHO.HOGOSHA_SKYOKUSHI_KBN;                       --保護者照会抑止・区分
          rWLTBL.HOGOSHA_SKYKSKAISHIBI := rGKBWYOKUSHITAISHO.HOGOSHA_SKYKSKAISHIBI;                       --保護者照会抑止・開始日
          rWLTBL.HOGOSHA_SKYKSSHURYOBI := rGKBWYOKUSHITAISHO.HOGOSHA_SKYKSSHURYOBI;                       --保護者照会抑止・終了日
          rWLTBL.KIJUNBI := rGKBWYOKUSHITAISHO.KIJUNBI;                                                   --基準日
          rWLTBL.BREAK_NO := CEIL(g_nSORT/10);                                                            --改ページキー
          rWLTBL.WSNUM := g_sWSNUM;                                                                       --端末番号
          rWLTBL.BATCHKBN := 2;                                                                           --即時バッチ区分
          rWLTBL.JOBNUM := g_nJOBNUM;                                                                     --ジョブNO
          --登録ワークテーブル
          INSERT INTO GKBWL712R001 VALUES rWLTBL;
          g_nREBAN := g_nREBAN + 1;                                                                       --CSV出力件数
        END LOOP;
      CLOSE cCURSORWL;
      --抑止対象者一覧対象件数
      g_nINDEX := g_nINDEX + 1;
      g_oKENSU_LIST.EXTEND(1);
      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '入力 抑止対象者一覧対象件数', 1);
      --抑止対象者一覧ＣＳＶ件数
      g_nINDEX := g_nINDEX + 1;
      g_oKENSU_LIST.EXTEND(1);
      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_nREBAN, '出力 抑止対象者一覧ＣＳＶ', 2);
      --関数終了
      bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV作成処理', 0, '', '', '抑止対象者一覧ＣＳＶ' || g_nREBAN ||'件を出力しました', g_sTANTOCODE, g_sWSNUM, 1);
      RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
          IF cCURSOR%ISOPEN THEN
            CLOSE cCURSOR;
          END IF;
          IF cCURSORWL%ISOPEN THEN
            CLOSE cCURSORWL;
          END IF;
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV作成処理', 1, SQLCODE, SQLERRM, 'ＣＳＶファイルの書き出し処理が異常終了しました', g_sTANTOCODE, g_sWSNUM, 1);
          RETURN c_ERR;
    END FUNC_CSV_CREATE;
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu 2024/06/14
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
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;                    --戻り値
        nRTN             PLS_INTEGER;                --戻る値
        sDATE            NVARCHAR2(20);
        ERR              EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        
        --条件取得処理を呼び出す。
        bRTN := FUNC_JYOKEN_GET;
        IF NOT bRTN THEN
            RAISE ERR;
        END IF;
        
        --初期処理を呼び出す。
        bRTN := FUNC_INIT;
        IF NOT bRTN THEN
            RAISE ERR;
        END IF;
        
        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB712R001' THEN
            --抑止対象者一覧中間ワーク初期化
            DELETE FROM GKBWYOKUSHITAISHO;
            --抑止対象者一覧ワーク初期化
            DELETE FROM GKBWL712R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
            --ＣＳＶファイル作成処理を呼び出す。
            nRTN := FUNC_CSV_CREATE;
            IF nRTN <> 0 THEN
              RAISE ERR;
            END IF;
            --帳票出力CSVの作成
            bRTN := FUNC_B11CSV('GKBWL712R001');
          ELSE
            NULL;
        END CASE;
        
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.shixinyu   2024/06/14
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
        --処理ステップ連番が終了するまで繰り返す
        FOR i IN 1..nSTEPSEQ_MAX LOOP

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
END GKBPB00560;
/
