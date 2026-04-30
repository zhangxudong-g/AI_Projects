CREATE OR REPLACE PACKAGE BODY GKBPC00170
--1.0.203.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : バックアップ・復元処理
--  機能概要      : 学齢簿データのバックアップ・復元を行う。バックアップは１世代のみ取得可能にする。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
--------------------------------------------------------
--  変更履歴
--  2024/04/18 ZCZL.LIKEWEN UPDATE 0.2.000.001:512_GKB_00020対応
--  2024/06/06 ZCZL.GUANHONG Update 0.3.000.000:新WizLIFE２次開発
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--  2025/10/23 CTC.HJF UPDATE 1.0.203.000:GKB_QA16961対応
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

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --パラメータ変数
    VMSG        NVARCHAR2(4000);
    VMSG_WK     NVARCHAR2(4000);
    IRTN        PLS_INTEGER;
    NSHORIBI    NUMBER(8,0);
    NSHORIJIKAN NUMBER(6,0);
    VSHORIBI    NVARCHAR2(10);
    VSHORIJIKAN NVARCHAR2(8);
--  2024/06/06 ZCZL.GUANHONG Add 0.3.000.000:新WizLIFE２次開発
    VSEIREKI_SYSDATE                  NVARCHAR2(8);           --変数.処理日_西暦
    --画面から条件
    g_vJYOUKEN1  NVARCHAR2(500);
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- 戻り値
--  2024/06/06 ZCZL.GUANHONG Update 0.3.000.000:新WizLIFE２次開発
--     C_TABLE_COUNT  CONSTANT  PLS_INTEGER := 6;                     --マスタ・バックアップテーブル数
    C_TABLE_COUNT  CONSTANT  PLS_INTEGER := 5;
    ------------------------------------------------------------------------------
    -- 変数宣言
    ------------------------------------------------------------------------------
    VERRMSG          NVARCHAR2(256);                               --エラーメッセージ
    VERRSTP          PLS_INTEGER;                                  --エラーステップ
    BRTN             BOOLEAN;                                      --戻り値用
    EERROR           EXCEPTION;                                    --異常
    RINS             GKBTBKLOG%ROWTYPE;                            --バックアップログ登録用
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
    VLOG             NVARCHAR2(256);
    BHAITA_CHU                        BOOLEAN := FALSE;       --w排他中
--  2024/06/06 ZCZL.GUANHONG Add end 
    TYPE MR_TABLE IS RECORD(
      TABLE_ID       VARCHAR2(30),                                 --テーブルID
      TABLE_NM       NVARCHAR2(100)                                --テーブル名称
    );
    TYPE MT_TABLE IS TABLE OF MR_TABLE INDEX BY BINARY_INTEGER;
    TBACKUPTABLE     MT_TABLE;                                     --バックアップテーブル用
    TMASTERTABLE     MT_TABLE;                                     --マスタテーブル用
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT RETURN BOOLEAN
    IS
        v_cmbShoriKbn          DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        v_cmbShoriKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbShoriKbn');
        g_vJYOUKEN1 := v_cmbShoriKbn(1);
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
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
    ------------------------------
    --  機能概要      : 条件１のチェック
    --  パラメータ    : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
    ------------------------------
    FUNCTION FUNCVJOKEN1CHK (i_IRENBAN IN NVARCHAR2) RETURN NUMBER IS
      IRET      PLS_INTEGER;
      IVJOKEN1  PLS_INTEGER;
    BEGIN
      IRET := 0;
      BEGIN
        IVJOKEN1 := TO_NUMBER(i_IRENBAN);
        IF i_IRENBAN IS NOT NULL THEN
          IF NOT IVJOKEN1 IN (0,1) THEN
            IRET := 1;
          END IF;
        ELSE
            IRET := 1;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;
    RETURN (IRET);
    END FUNCVJOKEN1CHK;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                : o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
    BEGIN
        VMSG    := '';
        VMSG_WK := '';
        IRTN    := 0;
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
        -- 条件１のチェック
        IRTN := FUNCVJOKEN1CHK(g_vJYOUKEN1);
        IF IRTN <> 0 THEN
          VMSG  := g_sGYOUMUCODE || ',99999,処理区分が正しくありません。,;';
        END IF;

        -- 前回処理のログ情報を取得し
        BEGIN
          SELECT SHORIBI, SHORIJIKAN
          INTO   NSHORIBI,NSHORIJIKAN
          FROM   GKBTBKLOG;
        EXCEPTION
          WHEN OTHERS THEN
            NSHORIBI    := NULL;
            NSHORIJIKAN := NULL;
        END;

        -- データが存在しない場合、又はレコードが無い場合は、メッセージを出力しない
        IF NSHORIBI IS NOT NULL AND NSHORIJIKAN IS NOT NULL THEN
          VSHORIBI    := TO_CHAR(TO_DATE(NSHORIBI,'YYYYMMDD'),'YYYY/MM/DD');
          VSHORIJIKAN := TO_CHAR(TO_DATE(LPAD(NSHORIJIKAN,6,0),'HH24MISS'),'HH24:MI:SS');
          VMSG := VMSG || g_sGYOUMUCODE || ',99998, ' || '前回のバックアップは、[' || VSHORIBI || ' ' || VSHORIJIKAN || ']に処理済みです。,;';
        END IF;

        o_vRESULT := VMSG;
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
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
    --------------------------------------------------------------------------------
    --  機能概要      : テーブルの設定
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
    --------------------------------------------------------------------------------
    PROCEDURE PROC_SETTABLEINFO
    IS
    BEGIN
      --マスタテーブル
      --  2024/04/18 ZCZL.LIKEWEN UPDATE START 0.2.000.001:512_GKB_00020対応
      --TMASTERTABLE(1).TABLE_ID := 'GKBTGAKUREIBOBK';
      --TMASTERTABLE(1).TABLE_NM := '学齢簿バックアップ';
      --TMASTERTABLE(2).TABLE_ID := 'GKBTGAKUNENLNKBK';
      --TMASTERTABLE(2).TABLE_NM := '学年リンクバックアップ';
      --TMASTERTABLE(3).TABLE_ID := 'GKBTNINIBITBK';
      --TMASTERTABLE(3).TABLE_NM := '任意ビットバックアップ';
      --TMASTERTABLE(4).TABLE_ID := 'GKBTKOSHINLOGBK';
      --TMASTERTABLE(4).TABLE_NM := '更新ログバックアップ';
      --TMASTERTABLE(5).TABLE_ID := 'GKBTKUIKIGAIKANRIBK';
      --TMASTERTABLE(5).TABLE_NM := '区域外管理バックアップ';
      --TMASTERTABLE(6).TABLE_ID := 'GKBTSHUGAKUENJOBK';
      --TMASTERTABLE(6).TABLE_NM := '就学援助情報管理バックアップ';
      TMASTERTABLE(1).TABLE_ID := 'GKBTGAKUREIBO';
      TMASTERTABLE(1).TABLE_NM := '学齢簿';
      TMASTERTABLE(2).TABLE_ID := 'GKBTGAKUNENLNK';
      TMASTERTABLE(2).TABLE_NM := '学年リンク';
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
--       TMASTERTABLE(3).TABLE_ID := 'GKBTNINIBIT';
--       TMASTERTABLE(3).TABLE_NM := '任意ビット';
--  2024/06/06 ZCZL.GUANHONG Add end 
      TMASTERTABLE(3).TABLE_ID := 'GKBTKOSHINLOG';
      TMASTERTABLE(3).TABLE_NM := '更新ログ';
--  2024/06/06 ZCZL.GUANHONG Update Start 0.3.000.000:新WizLIFE２次開発
--       TMASTERTABLE(5).TABLE_ID := 'GKBTKUIKIGAIKANRI';
--       TMASTERTABLE(5).TABLE_NM := '区域外管理';
--       TMASTERTABLE(6).TABLE_ID := 'GKBTSHUGAKUENJO';
--       TMASTERTABLE(6).TABLE_NM := '就学援助情報管理';
      TMASTERTABLE(4).TABLE_ID := 'GKBTGAKUNENRIREKI';
      TMASTERTABLE(4).TABLE_NM := '学年履歴';
      TMASTERTABLE(5).TABLE_ID := 'GKBTSHUGAKURIREKI';
      TMASTERTABLE(5).TABLE_NM := '就学履歴';

--  2024/06/06 ZCZL.GUANHONG Add end 
      --  2024/04/18 ZCZL.LIKEWEN UPDATE END
      FOR I IN 1..C_TABLE_COUNT LOOP
        --  2024/04/18 ZCZL.LIKEWEN UPDATE START 0.2.000.001:512_GKB_00020対応
        --TBACKUPTABLE(I).TABLE_ID := TMASTERTABLE(I).TABLE_ID;
        --TBACKUPTABLE(I).TABLE_NM := TMASTERTABLE(I).TABLE_NM;
        TBACKUPTABLE(I).TABLE_ID := TMASTERTABLE(I).TABLE_ID || 'BK';
        TBACKUPTABLE(I).TABLE_NM := TMASTERTABLE(I).TABLE_NM || 'バックアップ';
        --  2024/04/18 ZCZL.LIKEWEN UPDATE END
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE;
    END PROC_SETTABLEINFO;
    --------------------------------------------------------------------------------
    --  機能概要      : 指定テーブルから件数の取得
    --  パラメータ    : i_VTABLEID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GETKENSU(i_VTABLEID IN  VARCHAR2) RETURN NUMBER
    IS
      NKENSU              NUMBER;         --件数用
    BEGIN
      EXECUTE IMMEDIATE 'SELECT COUNT(1) FROM ' || i_VTABLEID INTO NKENSU;
      RETURN NKENSU;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE;
    END FUNC_GETKENSU;
    --------------------------------------------------------------------------------
    --  機能概要      : バックアップ
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
    --------------------------------------------------------------------------------
    PROCEDURE PROC_BACKUP
    IS
      IRTN             PLS_INTEGER;                                  --戻り値用
    BEGIN
      --テーブルの設定
      PROC_SETTABLEINFO;

      --バックアップテーブルの初期化
      FOR I IN 1..C_TABLE_COUNT LOOP
        IRTN := KKAPK3000.FTRUNCATE(TBACKUPTABLE(I).TABLE_ID, VERRMSG);
        IF IRTN <> 0 THEN
          VERRSTP := 3;
          VERRMSG := 'KKAPK3000.FTRUNCATE' || '（' || TBACKUPTABLE(I).TABLE_ID || '）';
          RAISE EERROR;
        END IF;
      END LOOP;

      --各マスタテーブルの件数取得し、件数表に出力
      FOR I IN 1..C_TABLE_COUNT LOOP
          g_nINDEX := g_nINDEX + 1;
          g_oKENSU_LIST.EXTEND(1);
          g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(FUNC_GETKENSU(TMASTERTABLE(I).TABLE_ID), '入力　'||TMASTERTABLE(I).TABLE_NM || '（' || TMASTERTABLE(I).TABLE_ID || '）', 1);
      END LOOP;

      --バックアップ処理
      FOR I IN 1..C_TABLE_COUNT LOOP
        BEGIN
          EXECUTE IMMEDIATE 'INSERT INTO ' || TBACKUPTABLE(I).TABLE_ID || ' SELECT * FROM ' || TMASTERTABLE(I).TABLE_ID;
        EXCEPTION
          WHEN OTHERS THEN
            VERRSTP := 4;
            VERRMSG := 'バックアップ処理異常（' || TBACKUPTABLE(I).TABLE_ID || '）';
            RAISE EERROR;
        END;
      END LOOP;
      BEGIN
        DELETE FROM GKBTBKLOG;
        RINS.TOUROKU_RENBAN := g_nJOBNUM;
        RINS.SHORIBI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        RINS.SHORIJIKAN := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS'));
        RINS.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
        RINS.SYS_TANMATU_NO := g_sWSNUM;
        INSERT INTO GKBTBKLOG VALUES RINS;
-- 2025/10/23 CTC.HJF UPDATE START 1.0.203.000:GKB_QA16961
        COMMIT;
-- 2025/10/23 CTC.HJF UPDATE END
      EXCEPTION
        WHEN OTHERS THEN
          VERRSTP := 5;
          VERRMSG := 'バックアップログ更新異常（' || SQLERRM || '）';
          RAISE EERROR;
      END;

      --各バックアップテーブルの件数を取得し、件数表に出力
      FOR I IN 1..C_TABLE_COUNT LOOP
          g_nINDEX := g_nINDEX + 1;
          g_oKENSU_LIST.EXTEND(1);
          g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(FUNC_GETKENSU(TBACKUPTABLE(I).TABLE_ID), '出力　'||TBACKUPTABLE(I).TABLE_NM || '（' || TBACKUPTABLE(I).TABLE_ID || '）', 2);
      END LOOP;
    END PROC_BACKUP;
    -------------------------------------------------------------------------------------
    --  ログ内容編集(最大256文字）
    -------------------------------------------------------------------------------------
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
    FUNCTION FUNC_GET_LOG(i_VLOG IN NVARCHAR2) RETURN NVARCHAR2
    IS
    BEGIN
      --出力するログ情報(最大256文字）
      RETURN SUBSTR( i_VLOG
                    ,0
                    ,256);
    END FUNC_GET_LOG;
--  2024/06/06 ZCZL.GUANHONG Add end 
    --------------------------------------------------------------------------------
    --  機能概要      : 復元
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
    --------------------------------------------------------------------------------
    PROCEDURE PROC_RECOVERY
    IS
      NCOUNT          PLS_INTEGER;
    BEGIN
      --テーブルの設定
      PROC_SETTABLEINFO;

      --バックアップテーブルのデータ件数を確認する。
      SELECT COUNT(1)
        INTO NCOUNT
        FROM GKBTGAKUREIBOBK;
      --「GKBTGAKUREIBOBKテーブルの件数」=0の場合、処理を終了する。
      IF NCOUNT = 0 THEN
        VERRSTP := 6;
        VERRMSG := '復元処理異常（GKBTGAKUREIBOBKの件数ゼロ件）';
        RAISE EERROR;
      END IF;

      --各バックアップテーブルの件数を取得し、件数表に出力
      FOR I IN 1..C_TABLE_COUNT LOOP
          g_nINDEX := g_nINDEX + 1;
          g_oKENSU_LIST.EXTEND(1);
          g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(FUNC_GETKENSU(TBACKUPTABLE(I).TABLE_ID), '入力　'||TBACKUPTABLE(I).TABLE_NM || '（' || TBACKUPTABLE(I).TABLE_ID || '）', 1);
      END LOOP;

      --各マスタテーブルを初期化する。（DELETE処理）
      FOR I IN 1..C_TABLE_COUNT LOOP
        EXECUTE IMMEDIATE 'DELETE FROM ' || TMASTERTABLE(I).TABLE_ID;
      END LOOP;

      --復元処理
      FOR I IN 1..C_TABLE_COUNT LOOP
        BEGIN
          EXECUTE IMMEDIATE 'INSERT INTO ' || TMASTERTABLE(I).TABLE_ID || ' SELECT * FROM ' || TBACKUPTABLE(I).TABLE_ID;
        EXCEPTION
          WHEN OTHERS THEN
            VERRSTP := 7;
            VERRMSG := '復元処理異常（' || TMASTERTABLE(I).TABLE_ID || '）';
            RAISE EERROR;
        END;
      END LOOP;

      --各マスタテーブルの件数を取得し、件数表に出力
      FOR I IN 1..C_TABLE_COUNT LOOP
          g_nINDEX := g_nINDEX + 1;
          g_oKENSU_LIST.EXTEND(1);
          g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(FUNC_GETKENSU(TMASTERTABLE(I).TABLE_ID), '出力　'||TMASTERTABLE(I).TABLE_NM || '（' || TMASTERTABLE(I).TABLE_ID || '）', 2);
      END LOOP;
    END PROC_RECOVERY;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                      --戻り値
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;    --戻り値
--  2024/06/06 ZCZL.GUANHONG Add 0.3.000.000:新WizLIFE２次開発
        NRTN                          NUMBER;
    BEGIN
        g_nUPDLOGSEQ := g_nUPDLOGSEQ + 1;
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 2);
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
        --変数.処理日_西暦 :=　システム日付（YYYYMMDD)に編集してセット
        VSEIREKI_SYSDATE := TO_CHAR(SYSDATE, 'YYYYMMDD');
        NRTN := GKBFKHTSET(2,'999999999999','全件',TO_NUMBER(VSEIREKI_SYSDATE),g_sTANTOCODE,g_sWSNUM,g_nTIME);
        IF NRTN = 1 THEN
            VLOG := FUNC_GET_LOG('排他がかかっているデータが存在するため、処理を実行できませんでした。');
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
        ELSIF NRTN <> 0 AND NRTN <> 1 THEN
            VLOG := FUNC_GET_LOG('排他制御処理で異常終了しました。');
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
        ELSE
            BHAITA_CHU := TRUE;
        END IF;     
         --バックアップ（処理区分=0）の場合
        IF g_vJYOUKEN1 = '0' THEN
          PROC_BACKUP;
        --復元処理（処理区分=1）の場合
        ELSIF g_vJYOUKEN1 = '1' THEN
          PROC_RECOVERY;
        END IF;
--  2024/06/06 ZCZL.GUANHONG Add end 
     --終了出力処理
        --更新が正常終了した場合はコミットし、件数表CSVファイルを出力し処理を終了する。
        COMMIT;
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
         --変数.リターンコード := 排他制御クリア関数（GKBFKHTCLR）を使用し、排他の解除を行う。
        IF BHAITA_CHU THEN
        -- 排他制御クリア関数（GKBFKHTCLR）を使用し、排他の解除を行う。
        IRTN := GKBFKHTCLR(2 ,'999999999999');
          IF IRTN <> 0 THEN
            VLOG := FUNC_GET_LOG('排他解除が異常終了しました。');
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 2);
          END IF;
        END IF;
--  2024/06/06 ZCZL.GUANHONG Add end 
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 2);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/06/06 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
           ROLLBACK;
           --変数.リターンコード := 排他制御クリア関数（GKCFKHTCLR）を使用し、排他の解除を行う。
           IF BHAITA_CHU THEN
             -- 排他制御クリア関数（GKCFKHTCLR）を使用し、排他の解除を行う。
             IRTN := GKBFKHTCLR(2 ,'999999999999');
                IF IRTN <> 0 THEN 
                   VLOG := FUNC_GET_LOG('排他解除が異常終了しました。');
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.001:8月1日認識合わせの横展開
--                   bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, VLOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 2); 
                   bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 2); 
                END IF;
           END IF;
--  2024/06/06 ZCZL.GUANHONG Add end 
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
    END FUNC_B20UPDATE1;
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU   2024/01/02
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
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM)   ;
            ROLLBACK;
        WHEN OTHERS THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
    END PBATCH;
END GKBPC00170;
/
