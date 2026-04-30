CREATE OR REPLACE PACKAGE BODY GKBPB00520
--1.0.402.001-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 区域外就学満了通知書・転入学通知書
--  機能概要      : 区域外就学満了通知書、転入学通知書に加えて、
--                 区域外就学満了通知書発送者一覧の出力も行えること。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.lvyan 2024/07/04
--------------------------------------------------------
--  変更履歴
--  2024/08/30 ZCZL.LVYAN Update 0.3.000.001:IT_GKB_00075対応
--  2024/10/17 ZCZL.WANGMING Update 0.3.000.002:仕様変更　ID：IT_GKB_00216,IT_GKB_00217対応
--  2024/10/31 ZCZL.WANGYUNING Update 0.3.000.003:仕様変更　IT_GKB_00434対応
--  2024/11/05 ZCZL.ZHANGLEI Update 0.3.000.004:IT_GKB_00393、IT_GKB_00394対応
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.005:仕様変更　IT_GKB_00426対応
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:仕様変更IT_GKB_00572、IT_GKB_00582、IT_GKB_00583対応
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応
--  2024/11/26 ZCZL.ZHANGLEI UPDATE 0.3.000.008:IT_GKC_00329横展開対応
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
--  2025/01/10 JPJYS.LIZIZHONG Update 0.3.000.010:IT_GKB_10215 
--  2025/01/14 JPJYS.LIUJUNHAO Update 0.3.000.011:IT_GKB_10221、IT_GKB_10230対応
--  2025/01/14 JPJYS.LIUJUNHAO Update 0.3.000.012:IT_GKB_1077対応
--  2025/06/04 CTC.HJF UPDATE 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
--  2025/07/01 CTC.HJF UPDATE 1.0.010.001:GKB_QA17602
--  2025/09/17 CTC.LW ADD 1.0.200.000:帳票アウトソーシング連番対応
--  2025/12/05 CTC.NI UPDATE 1.0.402.000:不具合対応
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
    --  2024/11/05 ZCZL.ZHANGLEI Update START 0.3.000.004:仕様変更　IT_GKB_00393、IT_GKB_00394対応
    --g_nKIJUNSTARTYMD              NUMBER :=0;                      --基準日（開始）
    --g_nKIJUNENDYMD                NUMBER :=0;                      --基準日（終了）
    --g_nTENNYUKIGENYMD             NUMBER :=0;                      --転入学手続き期限
    --g_nHAKKOYMD                   NUMBER :=0;                      --発行日
    g_nKIJUNSTARTYMD              NVARCHAR2(1000);                      --基準日（開始）
    g_nKIJUNENDYMD                NVARCHAR2(1000);                      --基準日（終了）
    g_nTENNYUKIGENYMD             NVARCHAR2(1000);                      --転入学手続き期限
    g_nHAKKOYMD                   NVARCHAR2(1000);                      --発行日
    --  2024/11/16 JPJYS.LIUHUAIQI Add 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
    g_nTENGAKUKIJITSU             NVARCHAR2(1000);                      --転学期日
    g_nTENNYUKIJITSU              NVARCHAR2(1000);                      --転入期日
    --  2024/11/16 JPJYS.LIUHUAIQI Add 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
    --  2024/11/05 ZCZL.ZHANGLEI Update END
    g_sHAKKORIREKI                NUMBER :=0;                      --発行履歴(0：作成する、1:作成しない)
    g_sSHIENSOCHI                 NUMBER :=0;                      --支援措置対象者マスク(0：有り、1：無し)
    --パラメータ変数
    VMSG                          NVARCHAR2(4000);
    g_nKENSAKU                    NUMBER := 0;                     --件数
    g_nCSVKENSAKU                 NUMBER := 0;                     --CSV件数
    g_vKYOIKUKAIMEI               NVARCHAR2(1000);                 --教育委員会名
    g_vKYOIKUKAISHUCHOMEI         NVARCHAR2(1000);                 --教育委員会首長名
    g_vKOUIN                      NVARCHAR2(1000);                 --公印情報
    g_vKUIKIGAIKOINSHORYAKU       NVARCHAR2(1000);                 --区域外公印省略
    g_vKUIKIGAIKOINCHUSHAKU       NVARCHAR2(1000);                 --区域外公印注釈
    g_vKUIKIGAITSUCHIBUN          NVARCHAR2(1000);                 --区域外通知文
    g_vKUIKIGAITOKKIJIKO          NVARCHAR2(1000);                 --区域外特記事項
    g_vKUIKIGAIBIKO               NVARCHAR2(1000);                 --区域外備考
    g_vKUIKIGAIBIKOTITLE          NVARCHAR2(1000);                 --区域外備考タイトル
    g_vKUIKIGAIYOSHIKIBANGO       NVARCHAR2(1000);                 --区域外様式番号
    g_vKUIKIGAITITLE              NVARCHAR2(1000);                 --区域外帳票タイトル
    g_vTENNYUGAKUKOINSHORYAKU       NVARCHAR2(1000);                 --転入学公印省略　　　
    g_vTENNYUGAKUKOINCHUSHAKU       NVARCHAR2(1000);                 --転入学公印注釈
    g_vTENNYUGAKUTSUCHIBUN          NVARCHAR2(1000);                 --転入学通知文
    g_vTENNYUGAKUTOKKIJIKO          NVARCHAR2(1000);                 --転入学特記事項
    g_vTENNYUGAKUBIKO               NVARCHAR2(1000);                 --転入学備考
    g_vTENNYUGAKUBIKOTITLE          NVARCHAR2(1000);                 --転入学備考タイトル
    g_vTENNYUGAKUYOSHIKIBANGO       NVARCHAR2(1000);                 --転入学様式番号
    g_vTENNYUGAKUTITLE              NVARCHAR2(1000);                 --転入学帳票タイトル
    g_vKGAI_SHUTSURYOKUSEIGYO       NVARCHAR2(1000);                 --区域外満了_出力制御
    g_vTGAKU_SHUTSURYOKUSEIGYO      NVARCHAR2(1000);                 --転入学_出力制御    
    TYPE MR_BUNNUM IS RECORD(
        KOJINNUM                           NUMBER,                          --宛名番号
        BUNNUM_ANNAISHOU                   NVARCHAR2(1000)                  --文書番号_案内書
    );
    TYPE MR_BUNNUM_REC IS TABLE OF MR_BUNNUM INDEX BY BINARY_INTEGER;
    g_rHOKANBUNNUM                  MR_BUNNUM_REC;                   --文書番号保管
    --  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START
   /* rBUNNUMSRCINF                   KKAPK0040.MR_BUNNUMSRCINF;    --文書番号情報（構造体）
    rBUNOUTINF                      KKAPK0040.MR_BUNOUTINF;         --文書発行記録出力情報
    rBUNNUMEDITKEKA                 KKAPK0040.MR_BUNNUMEDITKEKA;    --文書番号編集結果
    g_vBUNNUM_KGAIMANRYO            NVARCHAR2(1000);                --文書番号_区域外満了
    g_vBUNNUM_TENNYUGAKU            NVARCHAR2(1000);                --文書番号_転入学*/
    
    rBUNNUMSRCINF1                   KKAPK0040.MR_BUNNUMSRCINF;    --文書番号情報（構造体）
    rBUNOUTINF1                      KKAPK0040.MR_BUNOUTINF;         --文書発行記録出力情報
    rBUNNUMEDITKEKA1                 KKAPK0040.MR_BUNNUMEDITKEKA;    --文書番号編集結果
    rBUNNUMSRCINF2                   KKAPK0040.MR_BUNNUMSRCINF;    --文書番号情報（構造体）
    rBUNOUTINF2                      KKAPK0040.MR_BUNOUTINF;         --文書発行記録出力情報
    rBUNNUMEDITKEKA2                 KKAPK0040.MR_BUNNUMEDITKEKA;    --文書番号編集結果
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END
    g_vBUNNUM_KGAIMANRYO            NVARCHAR2(1000);                --文書番号_区域外満了
    g_vBUNNUM_TENNYUGAKU            NVARCHAR2(1000);                --文書番号_転入学*/
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START
    TYPE JIDO_rec IS RECORD (
    JIDO_ATENANO NUMBER(15),
    JIDO_BUNSHO VARCHAR2(100)
  );

     TYPE JIDO_map IS TABLE OF JIDO_rec INDEX BY VARCHAR2(100);
    JIDO_ATENANO_BUNSHO JIDO_map;  
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END  
 
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
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
--  2024/08/30 ZCZL.LVYAN Add START 0.3.000.001:IT_GKB_00075対応
         a_vHAKKORIREK     DBMS_UTILITY.MAXNAME_ARRAY;   --発行履歴
         a_vSHIENSOCHI     DBMS_UTILITY.MAXNAME_ARRAY;   --支援措置対象者マスク
--  2024/08/30 ZCZL.LVYAN Add END       
    BEGIN
        --基準日（開始）
        g_nKIJUNSTARTYMD := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKijunStartYmd');
        --基準日（終了）
        g_nKIJUNENDYMD := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKijunEndYmd');
        --転入学手続き期限
        g_nTENNYUKIGENYMD := KKBPK5551.GETPARMS(g_nJOBNUM,'txtTennyuKigenYmd');
        --発行日
        g_nHAKKOYMD := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHakkoYmd');
--  2024/08/30 ZCZL.LVYAN Update START 0.3.000.001:IT_GKB_00075対応
--        発行履歴
--         g_sHAKKORIREKI := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHakkoRireki');
--        支援措置対象者マスク
--         g_sSHIENSOCHI := KKBPK5551.GETPARMS(g_nJOBNUM,'txtShienSochi');
--        発行履歴
        a_vHAKKORIREK := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'txtHakkoRireki');
        g_sHAKKORIREKI := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtHakkoRireki',0,a_vHAKKORIREK);        
--        支援措置対象者マスク
        a_vSHIENSOCHI := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'txtShienSochi');
        g_sSHIENSOCHI := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShienSochi',0,a_vSHIENSOCHI);
--  2024/08/30 ZCZL.LVYAN Update END         
--  2024/11/16 JPJYS.LIUHUAIQI Add 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
        --転学期日
        g_nTENGAKUKIJITSU := KKBPK5551.GETPARMS(g_nJOBNUM,'txtTengakuYmd');
        --転入期日
        g_nTENNYUKIJITSU := KKBPK5551.GETPARMS(g_nJOBNUM,'txtTennyuYmd');
--  2024/11/16 JPJYS.LIUHUAIQI Add 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
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
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
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
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
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
        VMSG := '' ;
        --入力条件の日付の妥当性をチェックする
        bRTN := KKAPK0010.FISNUMERIC(g_nKIJUNSTARTYMD);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日（開始）が正しくありません。,;';
--  2024/10/17 ZCZL.WANGMING ADD START 0.3.000.002:仕様変更　ID：IT_GKB_00216,IT_GKB_00217対応
        ELSE
          bRTN := KKAPK0020.FISDATEW(g_nKIJUNSTARTYMD);
          IF NOT bRTN THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日（開始）が正しくありません。,;';
          END IF;
--  2024/10/17 ZCZL.WANGMING ADD END
        END IF;
        bRTN := KKAPK0010.FISNUMERIC(g_nKIJUNENDYMD);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE  || ',99999,基準日（終了）が正しくありません。,;';
--  2024/10/17 ZCZL.WANGMING ADD START 0.3.000.002:仕様変更　ID：IT_GKB_00216,IT_GKB_00217対応
        ELSE
          bRTN := KKAPK0020.FISDATEW(g_nKIJUNENDYMD);
          IF NOT bRTN THEN
            VMSG := VMSG || g_sGYOUMUCODE  || ',99999,基準日（終了）が正しくありません。,;';
          END IF;
--  2024/10/17 ZCZL.WANGMING ADD END
        END IF;
        bRTN := KKAPK0010.FISNUMERIC(g_nTENNYUKIGENYMD);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,転入学手続き期限が正しくありません。,;';
--  2024/10/17 ZCZL.WANGMING ADD START 0.3.000.002:仕様変更　ID：IT_GKB_00216,IT_GKB_00217対応
        ELSE
          bRTN := KKAPK0020.FISDATEW(g_nTENNYUKIGENYMD);
          IF NOT bRTN THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,転入学手続き期限が正しくありません。,;';
          END IF;
--  2024/10/17 ZCZL.WANGMING ADD END
        END IF;
        bRTN := KKAPK0010.FISNUMERIC(g_nHAKKOYMD);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,発行日が正しくありません。,;';
--  2024/10/17 ZCZL.WANGMING ADD START 0.3.000.002:仕様変更　ID：IT_GKB_00216,IT_GKB_00217対応
        ELSE
          bRTN := KKAPK0020.FISDATEW(g_nHAKKOYMD);
          IF NOT bRTN THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,発行日が正しくありません。,;';
          END IF;
--  2024/10/17 ZCZL.WANGMING ADD END
        END IF;
--  2024/10/17 ZCZL.WANGMING DELETE START 0.3.000.002:仕様変更　ID：IT_GKB_00216,IT_GKB_00217対応
--        --入力条件の日付の妥当性をチェックする
--        bRTN := KKAPK0020.FISDATEW(g_nKIJUNSTARTYMD);
--        IF NOT bRTN THEN
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日（開始）が正しくありません。,;';
--        END IF;
--        bRTN := KKAPK0020.FISDATEW(g_nKIJUNENDYMD);
--        IF NOT bRTN THEN
--          VMSG := VMSG || g_sGYOUMUCODE  || ',99999,基準日（終了）が正しくありません。,;';
--        END IF;
--        bRTN := KKAPK0020.FISDATEW(g_nTENNYUKIGENYMD);
--        IF NOT bRTN THEN
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,転入学手続き期限が正しくありません。,;';
--        END IF;
--        bRTN := KKAPK0020.FISDATEW(g_nHAKKOYMD);
--        IF NOT bRTN THEN
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,発行日が正しくありません。,;';
--        END IF;
--  2024/10/17 ZCZL.WANGMING DELETE END
--  2024/11/16 JPJYS.LIUHUAIQI Add 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
        --転学期日
        bRTN := KKAPK0010.FISNUMERIC(g_nTENGAKUKIJITSU);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE  || ',99999,転学期日が正しくありません。,;';
        ELSE
          bRTN := KKAPK0020.FISDATEW(g_nTENGAKUKIJITSU);
          IF NOT bRTN THEN
            VMSG := VMSG || g_sGYOUMUCODE  || ',99999,転学期日が正しくありません。,;';
          END IF;
        END IF;
        --転入期日
        bRTN := KKAPK0010.FISNUMERIC(g_nTENNYUKIJITSU);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE  || ',99999,転入期日が正しくありません。,;';
        ELSE
          bRTN := KKAPK0020.FISDATEW(g_nTENNYUKIJITSU);
          IF NOT bRTN THEN
            VMSG := VMSG || g_sGYOUMUCODE  || ',99999,転入期日が正しくありません。,;';
          END IF;
        END IF;
--  2024/11/16 JPJYS.LIUHUAIQI Add 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
        IF VMSG IS NULL THEN
          IF g_nKIJUNSTARTYMD > g_nKIJUNENDYMD THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日（開始）、基準日（終了）の関係が正しくありません。,;';
          END IF;
--  2024/11/16 JPJYS.LIUHUAIQI Add 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
          --転学期日、転入期日関係チェック
          IF g_nTENGAKUKIJITSU > g_nTENNYUKIJITSU THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,転学期日、転入期日の関係が正しくありません。,;';
          END IF;
--  2024/11/16 JPJYS.LIUHUAIQI Add 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
        END IF;
        o_vRESULT := VMSG ;
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
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
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
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
    --------------------------------------------------------
    FUNCTION FUNC_B11CSV(i_TBLNAME IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;          --戻り値
        nCSV_RCNT                     NUMBER;           --CSVファイル出力件数
        sCSVFILENAME                  NVARCHAR2(1000);  --CSVファイル名
        sPRTFILENAME                  NVARCHAR2(1000);  --印刷ファイル名
        vOUTCSVSQL                    NVARCHAR2(1000);  --SQL文
        nOUTCSVCNT                    NUMBER;           --CSV出力件数
    BEGIN
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        vOUTCSVSQL := 'SELECT COUNT(1) FROM ' || i_TBLNAME || ' WHERE ';
        vOUTCSVSQL := vOUTCSVSQL || ' JOBNUM = ' || g_nJOBNUM;
        vOUTCSVSQL := vOUTCSVSQL || ' AND WSNUM = ' || '''' || g_sWSNUM || '''';
        vOUTCSVSQL := vOUTCSVSQL || ' AND BATCHKBN = ' || c_BATCH;
        EXECUTE IMMEDIATE vOUTCSVSQL INTO nOUTCSVCNT;
        g_nCSVKENSAKU := nOUTCSVCNT;
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
    --  機能概要      : 初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
    --------------------------------------------------------
    FUNCTION FUNC_INIT
        RETURN BOOLEAN
    IS
        bRTN                     BOOLEAN;           --戻り値
        nRTN                     PLS_INTEGER;
        aPRM                     A_CONS_PRM;
        o_nDAIRIKBN              NUMBER;
        o_vKATAGAKI1             NVARCHAR2(1000);
        o_vKATAGAKI2             NVARCHAR2(1000);
        o_vSHIMEI                NVARCHAR2(1000);
        VGYOMU                   NVARCHAR2(1000);
        vKUIKIGAI_INDEXBANGO     NVARCHAR2(100);            --区域外満了_インデックス番号
        vTENNYUGAKU_INDEXBANGO   NVARCHAR2(100);            --転入学_インデックス番号
        dKIJYUNBI                NVARCHAR2(100);                      --基準日
        CURSOR rCURSOR(i_KBN IN NVARCHAR2) IS
          SELECT CHOHYO_MEI,KOIN_SHORYAKU,KOIN_CHUSHAKU,TSUCHIBUN,TOKKIJIKO,BIKO,BIKO_TITLE,YOSHIKI_BANGO_SETTOGO,YOSHIKI_BANGO,YOSHIKI_BANGO_SETSUBIGO
            FROM GKBTTSUCHISHOKANRI
           WHERE CHOHYO_KBN = i_KBN;
        rTSUCHISHOKANRI          rCURSOR%ROWTYPE;
    BEGIN
        dKIJYUNBI := TO_CHAR(SYSDATE,'YYYYMMDD');
        --公印情報を取得
        bRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE,0),           --認証コード
                                     g_sWSNUM,                            --端末番号
                                     TO_DATE(dKIJYUNBI,'YYYYMMDD'),       --基準日
                                     o_nDAIRIKBN,                         --認証者の本人・代理区分
                                     o_vKATAGAKI1,                        --認証者の肩書上段
                                     o_vKATAGAKI2,                        --認証者の肩書下段
                                     o_vSHIMEI,                           --認証者の氏名
                                     VGYOMU);                             --公印ファイル名
        IF NOT bRTN THEN
          bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || '初期処理', 1, '', '', '公印情報を取得する時に共通関数(KKBPK5551.FNINSHOGet)を行った際に、エラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
        END IF;
        g_vKYOIKUKAIMEI := o_vKATAGAKI1;   --教育委員会名
        g_vKYOIKUKAISHUCHOMEI := o_vSHIMEI;--教育委員会首長名
        g_vKOUIN := VGYOMU;--公印情報
        --通知文等編集
        OPEN rCURSOR('28'); --区域外就学満了通知書
        FETCH rCURSOR INTO rTSUCHISHOKANRI;
        LOOP
          EXIT WHEN rCURSOR%NOTFOUND;
          g_vKUIKIGAITSUCHIBUN := rTSUCHISHOKANRI.TSUCHIBUN;--区域外通知文
          g_vKUIKIGAITOKKIJIKO := rTSUCHISHOKANRI.TOKKIJIKO;--区域外特記事項
          g_vKUIKIGAIBIKO      := rTSUCHISHOKANRI.BIKO;    --区域外備考
          g_vKUIKIGAIBIKOTITLE := rTSUCHISHOKANRI.BIKO_TITLE; --区域外備考タイトル
          g_vKUIKIGAITITLE     := rTSUCHISHOKANRI.CHOHYO_MEI;--区域外帳票タイトル
          g_vKUIKIGAIYOSHIKIBANGO := rTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO || rTSUCHISHOKANRI.YOSHIKI_BANGO || rTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO;--区域外様式番号
          IF g_vKOUIN IS NOT NULL THEN
            g_vKUIKIGAIKOINSHORYAKU := NULL; --区域外公印省略
            g_vKUIKIGAIKOINCHUSHAKU := rTSUCHISHOKANRI.KOIN_CHUSHAKU;--区域外公印注釈
          ELSE
            g_vKUIKIGAIKOINSHORYAKU := rTSUCHISHOKANRI.KOIN_SHORYAKU; --区域外公印省略
            g_vKUIKIGAIKOINCHUSHAKU := NULL; --区域外公印注釈
          END IF;
          EXIT;
        END LOOP; 
        IF rCURSOR%ISOPEN THEN
          CLOSE rCURSOR;
        END IF;
        OPEN rCURSOR('4'); --転入学通知書
        FETCH rCURSOR INTO rTSUCHISHOKANRI;
        LOOP
          EXIT WHEN rCURSOR%NOTFOUND;
          g_vTENNYUGAKUTSUCHIBUN := rTSUCHISHOKANRI.TSUCHIBUN;--転入学通知文
          g_vTENNYUGAKUTOKKIJIKO := rTSUCHISHOKANRI.TOKKIJIKO;--転入学特記事項
          g_vTENNYUGAKUBIKO      := rTSUCHISHOKANRI.BIKO;    --転入学備考
          g_vTENNYUGAKUBIKOTITLE := rTSUCHISHOKANRI.BIKO_TITLE; --転入学備考タイトル
          g_vTENNYUGAKUTITLE     := rTSUCHISHOKANRI.CHOHYO_MEI;--転入学帳票タイトル
          g_vTENNYUGAKUYOSHIKIBANGO := rTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO || rTSUCHISHOKANRI.YOSHIKI_BANGO || rTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO;--転入学様式番号
          IF g_vKOUIN IS NOT NULL THEN
            g_vTENNYUGAKUKOINSHORYAKU := NULL; --転入学公印省略
            g_vTENNYUGAKUKOINCHUSHAKU := rTSUCHISHOKANRI.KOIN_CHUSHAKU;--転入学公印注釈
          ELSE
            g_vTENNYUGAKUKOINSHORYAKU := rTSUCHISHOKANRI.KOIN_SHORYAKU; --転入学公印省略
            g_vTENNYUGAKUKOINCHUSHAKU := NULL; --転入学公印注釈
          END IF;
          EXIT;
        END LOOP; 
        IF rCURSOR%ISOPEN THEN
          CLOSE rCURSOR;
        END IF;
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.005:仕様変更　IT_GKB_00426対応
       IF g_rJSTP.CHOHYOID = 'GKB676R001' OR g_rJSTP.CHOHYOID = 'GKB070R001'THEN
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START 
          --文書番号を取得する
          /* 
          bRTN := KKBPK5551.FJBNSGet(g_nJOBNUM, g_rJSTP.STEPSEQ, rBUNNUMSRCINF);
          IF NOT bRTN THEN
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || '初期処理', 1, '', '', '共通関数(バッチジョブ文書番号情報入力)(KKBPK5551.FJBNSGet)を行った際にエラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
          END IF;
          --文書番号編集結果
          rBUNNUMEDITKEKA := rBUNNUMSRCINF.UOUT; 
          --文書番号_区域外満了
          g_vBUNNUM_KGAIMANRYO := rBUNNUMEDITKEKA.NUM;
          --文書番号_転入学
          g_vBUNNUM_TENNYUGAKU := rBUNNUMEDITKEKA.NUM; */
  
          --文書番号を取得する
          bRTN := KKBPK5551.FJBNSGet(g_nJOBNUM, g_rJSTP.STEPSEQ, rBUNNUMSRCINF1);
          IF NOT bRTN THEN
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INIT', 1, '', '', '共通関数(バッチジョブ文書番号情報入力)(KKBPK5551.FJBNSGet)を行った際にエラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
          END IF;
          
          bRTN := KKBPK5551.FJBNSGet(g_nJOBNUM, g_rJSTP.STEPSEQ, rBUNNUMSRCINF2);
          IF NOT bRTN THEN
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INIT', 1, '', '', '共通関数(バッチジョブ文書番号情報入力)(KKBPK5551.FJBNSGet)を行った際にエラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
          END IF;        
          
          
          --文書番号編集結果
          rBUNNUMEDITKEKA1 := rBUNNUMSRCINF1.UOUT;
          rBUNNUMEDITKEKA2 := rBUNNUMSRCINF2.UOUT;
          --文書番号_区域外満了
          g_vBUNNUM_KGAIMANRYO := rBUNNUMEDITKEKA1.NUM;
          --文書番号_転入学
          g_vBUNNUM_TENNYUGAKU := rBUNNUMEDITKEKA2.NUM;          
          
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END         
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.005:仕様変更　IT_GKB_00426対応
        END IF;
        --外国人　氏名・生年月日制御帳票(ID)のリストを取得する
        nRTN := KKAPK0030.FCTGetR ('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aPRM);
        IF nRTN <> 0 THEN
          bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || '初期処理', 1, '', '', 'システム設定(KKATCT)から、制御パラメータ取得(KKAPK0030.FCTGetR)を使用して、「外国人　氏名・生年月日制御帳票(ID)」のリストを取得した際に、エラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
        END IF; 
        FOR i IN 1..aPRM.Count LOOP
          CASE aPRM(i)
            WHEN 'GKB676R001' THEN
              vKUIKIGAI_INDEXBANGO := i;  --区域外満了_インデックス番号
            WHEN 'GKB070R001' THEN
              vTENNYUGAKU_INDEXBANGO := i;--転入学_インデックス番号
            ELSE
              NULL;
          END CASE;
        END LOOP;
        --本名・通称名　出力制御のリストを取得する
        nRTN := KKAPK0030.FCTGetR ('GKB', 'EQSHIMEI', '0000', 0, aPRM);
        IF nRTN <> 0 THEN
          bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || '初期処理', 1, '', '', 'システム設定(KKATCT)から、制御パラメータ取得(KKAPK0030.FCTGetR)を使用して「本名・通称名　出力制御」のリストを取得した際、エラーが発生しました', g_sTANTOCODE, g_sWSNUM, 1);
        END IF;
        g_vKGAI_SHUTSURYOKUSEIGYO  :=aPRM(vKUIKIGAI_INDEXBANGO);  --区域外満了_出力制御
        g_vTGAKU_SHUTSURYOKUSEIGYO :=aPRM(vTENNYUGAKU_INDEXBANGO);--転入学_出力制御
        g_nKENSAKU := 0;    --件数をクリアする
        g_nCSVKENSAKU := 0; --CSV出力件数をクリアする
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
          IF rCURSOR%ISOPEN THEN
             CLOSE rCURSOR;
          END IF;
          bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || '初期処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
    END FUNC_INIT;
    --------------------------------------------------------
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : i_CHOHYOID     帳票ID     
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE(i_CHOHYOID IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;          --戻り値
        nRTN                          PLS_INTEGER;
        TYPE CURTYPE                  IS REF CURSOR;
        rCURSOR                         CURTYPE;
        VSQL                          NVARCHAR2(30000);
        GWK_UIKIGAITENGAKU            GKBWKUIKIGAITENGAKU%ROWTYPE;
        nCNT                          NUMBER :=0;
        rWK676R001                    GKBWL676R001%ROWTYPE;
        rWK130R082                    GKBWL130R082%ROWTYPE;
        rWK070R001                    GKBWL070R001%ROWTYPE;
        vYUBIN_NO                     NVARCHAR2(100);    --編集後郵便番号
        vCTLPRM                       NVARCHAR2(500);    --住所マスク文字列
        nPRMCTL                       NUMBER;            --抑止レベル３制御の要否
        sSHIMEIKANA                   NVARCHAR2(200);    --氏名カナ
        sSHIMEI                       NVARCHAR2(200);    --氏名漢字
        sBIRTHDAY                     NVARCHAR2(20);     --生年月日
        sBUNSHONOTMP                  NVARCHAR2(100);    --文書番号TMP  
        nKENSAKU                      NUMBER;            --出力件数
        
    BEGIN 
        --件数カウント計算
        g_nKENSAKU :=GKBFKTBLCNT('GKBWKUIKIGAITENGAKU',NULL);
        IF g_nKENSAKU = -1 THEN
           bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 1, '', '', '共通関数（件数カウント計算）(GKBFKTBLCNT)でエラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
        END IF;
        VSQL :='';
        VSQL := 'SELECT * ';
        VSQL := VSQL || ' FROM GKBWKUIKIGAITENGAKU ';
        VSQL := VSQL || 'WHERE WSNUM = ''' || g_sWSNUM  ||'''';
        VSQL := VSQL || '  AND BATCHKBN = 2';
-- 2025/09/17 CTC.LW Add Start 1.0.200.000:帳票アウトソーシング連番対応
      --IF g_rJSTP.ORDERBY IS NOT NULL THEN
        IF g_rJSTP.ORDERBYCLAUSE IS NOT NULL THEN
         --VSQL := VSQL || ' ORDER BY ' || g_rJSTP.ORDERBY;  
           VSQL := VSQL || ' ORDER BY ' || g_rJSTP.ORDERBYCLAUSE;  
-- 2025/09/17 CTC.LW Add End
           --  2025/01/14 JPJYS.LIUJUNHAO Update 0.3.000.011:IT_GKB_10221、IT_GKB_10230対応
        ELSE
           VSQL := VSQL || ' ORDER BY GKBWKUIKIGAITENGAKU.KOJIN_NO ';  
           --  2025/01/14 JPJYS.LIUJUNHAO Update 0.3.000.011:IT_GKB_10221、IT_GKB_10230対応
        END IF;
        nCNT := 0;
        CASE i_CHOHYOID
          --区域外就学満了通知書
--  2024/10/31 ZCZL.WANGYUNING Update 0.3.000.003:IT_GKB_00434対応
          --WHEN 'GKB672R001' THEN
          WHEN 'GKB676R001' THEN  
            OPEN rCURSOR FOR VSQL;
            LOOP
              FETCH rCURSOR INTO GWK_UIKIGAITENGAKU;
              EXIT WHEN rCURSOR%NOTFOUND;
                nCNT := nCNT + 1;
                rWK676R001.NO := nCNT;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 START
/*
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 START
--                IF g_sSHIENSOCHI = 1 THEN
                IF g_sSHIENSOCHI = 0 THEN
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 END
                  rWK676R001.SOFU_JUSHO := GWK_UIKIGAITENGAKU.SOFU_JUSHO;--送付先住所
                  rWK676R001.SOFU_KATAGAKI := GWK_UIKIGAITENGAKU.SOFU_KATAGAKAI;--送付先方書
                  nRTN := KKAPK0010.FYUBINHENSHU(GWK_UIKIGAITENGAKU.SOFU_YUBIN_NO,vYUBIN_NO);
                  IF nRTN = 0 THEN
                    rWK676R001.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(vYUBIN_NO,0);--送付先郵便番号
                  END IF;
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 START
--                ELSIF g_sSHIENSOCHI = 0 THEN
                ELSIF g_sSHIENSOCHI = 1 THEN
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 END 
*/
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 END

--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 START
/*      rWK676R001.SOFU_JUSHO := GWK_UIKIGAITENGAKU.SOFU_JUSHO;--送付先住所
                  rWK676R001.SOFU_KATAGAKI := GWK_UIKIGAITENGAKU.SOFU_KATAGAKAI;--送付先方書
                  nRTN := KKAPK0010.FYUBINHENSHU(GWK_UIKIGAITENGAKU.SOFU_YUBIN_NO,vYUBIN_NO);
                  IF nRTN = 0 THEN
                    rWK676R001.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(vYUBIN_NO,0);--送付先郵便番号
                  END IF;
                  vCTLPRM := GAAPK0030.FDVJUSHO('GKB',GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO,g_sTANTOCODE,g_sWSNUM,GWK_UIKIGAITENGAKU.SOFU_JUSHO,nPRMCTL,0);
                  rWK676R001.SOFU_JUSHO := vCTLPRM;--送付先住所
                  IF nPRMCTL = 1 THEN
                    IF g_sSHIENSOCHI = 0 THEN
                    rWK676R001.SOFU_YUBIN :=NULL;--送付先郵便番号
                    rWK676R001.SOFU_KATAGAKI := NULL;--送付先方書
                    
                 /* ELSIF nPRMCTL = 0 THEN
                    rWK676R001.SOFU_KATAGAKI := GWK_UIKIGAITENGAKU.SOFU_KATAGAKAI;--送付先方書                    
                    nRTN := KKAPK0010.FYUBINHENSHU(GWK_UIKIGAITENGAKU.SOFU_YUBIN_NO,vYUBIN_NO);
                  IF nRTN = 0 THEN
                    rWK676R001.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(vYUBIN_NO,0);--送付先郵便番号
                  END IF;
                  ELSE
                    NULL;
                  END IF;
                ELSE
                  NULL; 
                END IF; */
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 END
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 START
                  vCTLPRM := GAAPK0030.FDVJUSHO('GKB',GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO,g_sTANTOCODE,g_sWSNUM,GWK_UIKIGAITENGAKU.SOFU_JUSHO,nPRMCTL,0);
                 IF g_sSHIENSOCHI = 1 THEN 
                   IF nPRMCTL = 1 THEN
                     rWK676R001.SOFU_JUSHO := vCTLPRM;
                     rWK676R001.SOFU_YUBIN := NULL;
                     ELSE   
                     rWK676R001.SOFU_JUSHO := GWK_UIKIGAITENGAKU.SOFU_JUSHO;--送付先住所
                     rWK676R001.SOFU_KATAGAKI := GWK_UIKIGAITENGAKU.SOFU_KATAGAKAI;--送付先方書
                      nRTN := KKAPK0010.FYUBINHENSHU(GWK_UIKIGAITENGAKU.SOFU_YUBIN_NO,vYUBIN_NO);
                        IF nRTN = 0 THEN
                          rWK676R001.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(vYUBIN_NO,0);--送付先郵便番号
                        END IF;
                    END IF;
                    ELSIF  g_sSHIENSOCHI = 0 THEN 
                     rWK676R001.SOFU_JUSHO := GWK_UIKIGAITENGAKU.SOFU_JUSHO;--送付先住所
                     rWK676R001.SOFU_KATAGAKI := GWK_UIKIGAITENGAKU.SOFU_KATAGAKAI;--送付先方書
                      nRTN := KKAPK0010.FYUBINHENSHU(GWK_UIKIGAITENGAKU.SOFU_YUBIN_NO,vYUBIN_NO);
                        IF nRTN = 0 THEN
                          rWK676R001.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(vYUBIN_NO,0);--送付先郵便番号
                        END IF;
                    END IF;   
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 END
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK676R001.SOFU_ATENA := GWK_UIKIGAITENGAKU.HOGOSYA_SHIMEI;  --送付先宛名
                rWK676R001.SOFU_ATENA := GWK_UIKIGAITENGAKU.HOGOSYA_SHIMEI || '　'||'様';  --送付先宛名
                --文書番号
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START
                --IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
                IF rBUNNUMEDITKEKA1.NUMUMUFLG = 0 THEN
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END
                  --rWK676R001.BUNSHO_NO := g_vBUNNUM_KGAIMANRYO;
                  rWK676R001.BUNSHO_NO := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_vBUNNUM_KGAIMANRYO, 0),' ',''),'　','');  
                ELSE
                 rWK676R001.BUNSHO_NO := NULL;
                END IF;
                
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START                
                JIDO_ATENANO_BUNSHO(GWK_UIKIGAITENGAKU.KOJIN_NO).JIDO_ATENANO := GWK_UIKIGAITENGAKU.KOJIN_NO;
                JIDO_ATENANO_BUNSHO(GWK_UIKIGAITENGAKU.KOJIN_NO).JIDO_BUNSHO := g_vBUNNUM_KGAIMANRYO;
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END
                --発行年月日
                --rWK676R001.HAKKO_NENGAPI := KKAPK0020.FDAYEDIT20(g_nHAKKOYMD,0,3);
                rWK676R001.HAKKO_NENGAPI := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(KKAPK0020.FDAYEDIT20(g_nHAKKOYMD,0,3), 0),' ',''),'　','');  
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --教育委員会名
                rWK676R001.KYOIKUKAI_MEI := g_vKYOIKUKAIMEI;
                --認証者氏名
                rWK676R001.NINSHOSHA_SHIMEI := g_vKYOIKUKAISHUCHOMEI;
                --公印
                rWK676R001.KOIN_PATH := g_vKOUIN;
                --公印（省略）
                rWK676R001.KOIN_SHORYAKU := g_vKUIKIGAIKOINSHORYAKU;
                --公印（注釈）
                rWK676R001.KOIN_CHUSHAKU := g_vKUIKIGAIKOINCHUSHAKU;
                --バーコードNo
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                IF g_sSHIENSOCHI = 1 THEN 
                 IF nPRMCTL = 1 THEN
                   rWK676R001.BC_NO := NULL;
                  ELSE
                  rWK676R001.BC_NO := GWK_UIKIGAITENGAKU.SOFU_YUBIN_BC_NO;
                  END IF;
                ELSE  
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                rWK676R001.BC_NO := GWK_UIKIGAITENGAKU.SOFU_YUBIN_BC_NO;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                END IF;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --タイトル
                rWK676R001.TITLE := g_vKUIKIGAITITLE;
                --通知文
                rWK676R001.TSUCHI_BUN := g_vKUIKIGAITSUCHIBUN;

                nRTN := GKBFKHMCTRL(GWK_UIKIGAITENGAKU.KOJIN_NO, 
                                  g_rJSTP.CHOHYOID, 
                                  0, 
                                  g_vKGAI_SHUTSURYOKUSEIGYO, 
                                  sSHIMEIKANA, 
                                  sSHIMEI, 
                                  sBIRTHDAY);
                --児童生徒氏名カナ                                  
                rWK676R001.JIDO_SHIMEI_KANA := sSHIMEIKANA;
                --児童生徒氏名漢字
                rWK676R001.JIDO_SHIMEI_KANJI := sSHIMEI;
                --表示生年月日
                rWK676R001.HYOJI_SEINENGAPI := sBIRTHDAY;
                --児童生徒現住所
                rWK676R001.CHOMEI_BANCHI := GAAPK0010.FADDRESSEDIT(1,NULL,GWK_UIKIGAITENGAKU.CHOMEI_BANCHI,NULL,GWK_UIKIGAITENGAKU.KATAGAKAI,NULL);
                nRTN := GKBFKHMCTRL(GWK_UIKIGAITENGAKU.KOJIN_NO, 
                                     g_rJSTP.CHOHYOID, 
                                     1, 
                                     g_vKGAI_SHUTSURYOKUSEIGYO, 
                                     sSHIMEIKANA, 
                                     sSHIMEI, 
                                     sBIRTHDAY);
                --保護者氏名カナ
                rWK676R001.HOGOSHA_SHIMEI_KANA := sSHIMEIKANA;
                --保護者氏名漢字
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK676R001.HOGOSHA_SHIMEI_KANJI := sSHIMEI || '　様';
                rWK676R001.HOGOSHA_SHIMEI_KANJI := sSHIMEI; 
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --指定校名
                rWK676R001.SHITEIKO_MEI := KKAPK0010.FMULTIBYTEHENKAN(GWK_UIKIGAITENGAKU.SHITEIKOU_MEI, 0);
                --指定校学年
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK676R001.SHITEIKO_GAKUNEN := GWK_UIKIGAITENGAKU.SHITEIKOUGAKUNEN;
                IF GWK_UIKIGAITENGAKU.SHITEIKOUGAKUNEN IS NOT NULL THEN
                rWK676R001.SHITEIKO_GAKUNEN := KKAPK0010.FMULTIBYTEHENKAN('第'||GWK_UIKIGAITENGAKU.SHITEIKOUGAKUNEN||'学年', 0);
                END IF ;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --現在籍校名
                rWK676R001.GENZAISEKIKO_MEI := GWK_UIKIGAITENGAKU.GENZAISEKIKOU_MEI;
                --現在籍校学年
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK676R001.GENZAISEKIKO_GAKUNEN := GWK_UIKIGAITENGAKU.GENZAISEKIKO_GAKUNEN;
                IF GWK_UIKIGAITENGAKU.GENZAISEKIKO_GAKUNEN IS NOT NULL THEN
                rWK676R001.GENZAISEKIKO_GAKUNEN := KKAPK0010.FMULTIBYTEHENKAN('第'||GWK_UIKIGAITENGAKU.GENZAISEKIKO_GAKUNEN||'学年', 0);
                END IF ;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --就学期間
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK676R001.SHUGAKU_KIKAN := GWK_UIKIGAITENGAKU.SHUGAKUKIKAN_FR || 'から' || GWK_UIKIGAITENGAKU.SHUGAKUKIKAN_TO || 'まで満了';
                rWK676R001.SHUGAKU_KIKAN := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(GWK_UIKIGAITENGAKU.SHUGAKUKIKAN_FR, 0),' ',''),'　','') 
                || 'から' || REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(GWK_UIKIGAITENGAKU.SHUGAKUKIKAN_TO, 0),' ',''),'　','')
                || 'まで満了';
                --転入手続き期限
                --rWK676R001.TENNYUTETSUZUKI_KIGEN := KKAPK0020.FDAYEDIT20(g_nTENNYUKIGENYMD,0,3);
                rWK676R001.TENNYUTETSUZUKI_KIGEN := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(KKAPK0020.FDAYEDIT20(g_nTENNYUKIGENYMD,0,3), 0),' ',''),'　','');
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --備考
                rWK676R001.BIKO := REPLACE(g_vKUIKIGAIBIKO, chr(13) || chr(10), '#');
                --特記事項
                rWK676R001.TOKKIJIKO := REPLACE(g_vKUIKIGAITOKKIJIKO, chr(13) || chr(10), '#');
                --お問い合わせ先１
                rWK676R001.TOIAWASESAKI1 := GWK_UIKIGAITENGAKU.TOIAWASESAKI1;
                --お問い合わせ先２
                rWK676R001.TOIAWASESAKI2 := GWK_UIKIGAITENGAKU.TOIAWASESAKI2;
                --お問い合わせ先３
                rWK676R001.TOIAWASESAKI3 := GWK_UIKIGAITENGAKU.TOIAWASESAKI3;
                --様式番号
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK676R001.YOSHIKI_NO := g_vKUIKIGAIYOSHIKIBANGO;
                rWK676R001.YOSHIKI_NO := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_vKUIKIGAIYOSHIKIBANGO, 0),' ',''),'　',''); 
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --備考タイトル
                rWK676R001.BIKO_TITLE := g_vKUIKIGAIBIKOTITLE;
                --児童生徒宛名番号
                rWK676R001.KOJIN_NO := GWK_UIKIGAITENGAKU.KOJIN_NO;
                --保護者宛名番号
                rWK676R001.HOGOSYA_KOJIN_NO := GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO;
                --改ページキー
                rWK676R001.BREAK_NO := NULL;
                --端末番号
                rWK676R001.WSNUM := g_sWSNUM;
                --即時バッチ区分
                rWK676R001.BATCHKBN := 2;
                --ジョブNO
                rWK676R001.JOBNUM := g_nJOBNUM;
                INSERT INTO GKBWL676R001 VALUES rWK676R001;
                --発行履歴を作成する
                 IF g_sHAKKORIREKI = 0 THEN
                   --変数.文書番号_区域外満了を文書番号情報（構造体）.MAEMOJIと文書番号情報（構造体）.USHIROMOJIの値で切り抜いた値
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START                   
                /*   sBUNSHONOTMP := SUBSTR((SUBSTR(g_vBUNNUM_KGAIMANRYO,(LENGTH(rBUNNUMSRCINF.MAEMOJI)+1))),
                                           1,LENGTH(SUBSTR(g_vBUNNUM_KGAIMANRYO,
                                           (LENGTH(rBUNNUMSRCINF.MAEMOJI)+1)))-LENGTH(rBUNNUMSRCINF.USHIROMOJI));
                   sBUNSHONOTMP :=KKAPK0010.FSTRCNV(sBUNSHONOTMP,1);                       
                   nRTN := GKAFKHAKKOR('GKB',                                                --業務コード
                                        GWK_UIKIGAITENGAKU.KOJIN_NO,                         --宛名番号
                                        6761,                                                --帳票コード
                                        TO_NUMBER(SUBSTR(TO_CHAR(SYSDATE,'YYYYMMDD'),1,4)),  --年度
                                        1,                                                   --処理区分
                                        '区域外就学満了通知書',                               --通知書種別
                                        TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),              --発行日
                                        TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'HH24MISS')),         --発行時間
                                        1,                                                   --発行枚数
                                        g_sTANTOCODE,                                        --発行職員宛名番号
                                        g_nHAKKOYMD,                                         --送付日
                                        NULL,                                                --通知場所
                                        rBUNNUMSRCINF.MAEMOJI,                               --文書番号接頭語
--  2024/11/26 ZCZL.ZHANGLEI UPDATE 0.3.000.008:IT_GKC_00329横展開対応
                                        --TO_NUMBER(sBUNSHONOTMP),                             --文書番号
                                        sBUNSHONOTMP,                             --文書番号
                                        rBUNNUMSRCINF.USHIROMOJI,                            --文書番号接尾語
                                        GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO,                 --通知対象者宛名番号
                                        NULL,                                                --転出先自治体コード
                                        g_sWSNUM                                             --更新端末番号
                                        ); */

                   sBUNSHONOTMP := SUBSTR((SUBSTR(g_vBUNNUM_KGAIMANRYO,(LENGTH(rBUNNUMSRCINF1.MAEMOJI)+1))),
                                           1,LENGTH(SUBSTR(g_vBUNNUM_KGAIMANRYO,
                                           (LENGTH(rBUNNUMSRCINF1.MAEMOJI)+1)))-LENGTH(rBUNNUMSRCINF1.USHIROMOJI));
                   sBUNSHONOTMP :=KKAPK0010.FSTRCNV(sBUNSHONOTMP,1);                       
                   nRTN := GKAFKHAKKOR('GKB',                                                --業務コード
                                        GWK_UIKIGAITENGAKU.KOJIN_NO,                         --宛名番号
                                        6761,                                                --帳票コード
                                        TO_NUMBER(SUBSTR(TO_CHAR(SYSDATE,'YYYYMMDD'),1,4)),  --年度
                                        1,                                                   --処理区分
                                        '区域外就学満了通知書',                               --通知書種別
                                        TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),              --発行日
                                        TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'HH24MISS')),         --発行時間
                                        1,                                                   --発行枚数
                                        g_sTANTOCODE,                                        --発行職員宛名番号
                                        g_nHAKKOYMD,                                         --送付日
                                        NULL,                                                --通知場所
                                        rBUNNUMSRCINF1.MAEMOJI,                               --文書番号接頭語
                                        sBUNSHONOTMP,                             --文書番号
                                        rBUNNUMSRCINF1.USHIROMOJI,                            --文書番号接尾語
                                        GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO,                 --通知対象者宛名番号
                                        NULL,                                                --転出先自治体コード
                                        g_sWSNUM                                             --更新端末番号
                                        );                                 
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END
                    IF nRTN = 1 THEN
                      bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME, 1, '', '', '[区域外就学満了通知書]共通関数(帳票発行履歴作成)(GKAFKHAKKOR)でエラーが発生しました。　宛名番号：' || GWK_UIKIGAITENGAKU.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
                    END IF;
                END IF;
                --文書番号編集結果の取得
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START 
                /*IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (rBUNNUMSRCINF.NUMINCTYPE = 1 OR rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
                    KKAPK0040.SBunNumIc(rBUNNUMSRCINF, rBUNNUMEDITKEKA);
                END IF;
                --文書番号保管を追加する
                IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
                  g_rHOKANBUNNUM(nCNT).KOJINNUM := GWK_UIKIGAITENGAKU.KOJIN_NO;
                  g_rHOKANBUNNUM(nCNT).BUNNUM_ANNAISHOU := rBUNNUMEDITKEKA.NUM;
                END IF;
                g_vBUNNUM_KGAIMANRYO := rBUNNUMEDITKEKA.NUM; */
                
                
                 IF rBUNNUMEDITKEKA1.NUMUMUFLG = 0 AND (rBUNNUMSRCINF1.NUMINCTYPE = 1 OR rBUNNUMSRCINF1.NUMINCTYPE = 2) THEN
                    KKAPK0040.SBunNumIc(rBUNNUMSRCINF1, rBUNNUMEDITKEKA1);
                END IF;
                --文書番号保管を追加する
                IF rBUNNUMEDITKEKA1.NUMUMUFLG = 0 THEN
                  g_rHOKANBUNNUM(nCNT).KOJINNUM := GWK_UIKIGAITENGAKU.KOJIN_NO;
                  g_rHOKANBUNNUM(nCNT).BUNNUM_ANNAISHOU := rBUNNUMEDITKEKA1.NUM;
                END IF;
                g_vBUNNUM_KGAIMANRYO := rBUNNUMEDITKEKA1.NUM;
                
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END
            END LOOP;
            --発送者文字切れリストの作成
            bRTN:= GKAPK00010.FKMJGRLST(g_nJOBNUM,g_sWSNUM,g_sTANTOCODE,'GKB676R001',1,nKENSAKU);
            IF NOT bRTN THEN
              bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME, 1, '', '', '[区域外就学満了通知書]共通関数(各種通知書発送者文字切れリスト( GKAPK00010)でエラーが発生しました。　宛名番号：' || GWK_UIKIGAITENGAKU.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
            END IF;
            IF rCURSOR%ISOPEN THEN
               CLOSE rCURSOR;
            END IF;
          WHEN 'GKB130R002' THEN
             OPEN rCURSOR FOR VSQL;
             LOOP
               FETCH rCURSOR INTO GWK_UIKIGAITENGAKU;
               EXIT WHEN rCURSOR%NOTFOUND;
                  nCNT := nCNT + 1;
                  --ソート順
                  rWK130R082.NO := nCNT;
                  --作成年月日
                 rWK130R082.SAKUSEI_YMD := KKAPK0020.FDAYEDIT20(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),0,3);
                 --タイトル
                 rWK130R082.TITLE := '区域外就学満了通知書発送者一覧';  
                 --文書番号
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START 
                /* FOR i IN 1..g_rHOKANBUNNUM.COUNT LOOP
                  IF g_rHOKANBUNNUM(i).KOJINNUM = GWK_UIKIGAITENGAKU.KOJIN_NO THEN
                     rWK130R082.BUNSHO_NO := g_rHOKANBUNNUM(nCNT).BUNNUM_ANNAISHOU;
                    EXIT;
                  END IF;
                 END LOOP; */
                 rWK130R082.BUNSHO_NO := JIDO_ATENANO_BUNSHO(TO_CHAR(GWK_UIKIGAITENGAKU.KOJIN_NO)).JIDO_BUNSHO;
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END 
                 --発行年月日
                 rWK130R082.HAKKO_YMD := KKAPK0020.FDAYEDIT20(g_nHAKKOYMD,0,3);
                 --送付先氏名
                 rWK130R082.SOFUSAKI_SHIMEI := GWK_UIKIGAITENGAKU.HOGOSYA_SHIMEI;
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 START
                 --送付先郵便番号
--                 nRTN := KKAPK0010.FYUBINHENSHU(GWK_UIKIGAITENGAKU.SOFU_YUBIN_NO,vYUBIN_NO);
--                 IF nRTN = 0 THEN
--                   rWK130R082.SOFUSAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(vYUBIN_NO,0);--送付先郵便番号
--                 END IF;
                 --送付先住所
--                 rWK130R082.SOFUSAKI_JUSHO := GAAPK0010.FADDRESSEDIT(1,NULL,GWK_UIKIGAITENGAKU.SOFU_JUSHO,NULL,GWK_UIKIGAITENGAKU.SOFU_KATAGAKAI,NULL);
                 IF g_sSHIENSOCHI = 0 THEN
                   rWK130R082.SOFUSAKI_JUSHO := GWK_UIKIGAITENGAKU.SOFU_JUSHO;--送付先住所
                   nRTN := KKAPK0010.FYUBINHENSHU(GWK_UIKIGAITENGAKU.SOFU_YUBIN_NO,vYUBIN_NO);
                   IF nRTN = 0 THEN
                     rWK130R082.SOFUSAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(vYUBIN_NO,0);--送付先郵便番号
                   END IF;
                 ELSIF g_sSHIENSOCHI = 1 THEN
                   vCTLPRM := GAAPK0030.FDVJUSHO('GKB',GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO,g_sTANTOCODE,g_sWSNUM,GWK_UIKIGAITENGAKU.SOFU_JUSHO,nPRMCTL,0);
                   rWK130R082.SOFUSAKI_JUSHO := vCTLPRM;--送付先住所
                   IF nPRMCTL = 1 THEN
                     rWK130R082.SOFUSAKI_YUBIN_NO :=NULL;--送付先郵便番号
                   ELSIF nPRMCTL = 0 THEN
                     nRTN := KKAPK0010.FYUBINHENSHU(GWK_UIKIGAITENGAKU.SOFU_YUBIN_NO,vYUBIN_NO);
                     IF nRTN = 0 THEN
                       rWK130R082.SOFUSAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(vYUBIN_NO,0);--送付先郵便番号
                     END IF;
                   ELSE
                     NULL;
                   END IF;
                 ELSE
                   NULL;
                 END IF;
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 END
                 nRTN := GKBFKHMCTRL(GWK_UIKIGAITENGAKU.KOJIN_NO, 
                                     g_rJSTP.CHOHYOID, 
                                     0, 
                                     g_vKGAI_SHUTSURYOKUSEIGYO, 
                                     sSHIMEIKANA, 
                                     sSHIMEI, 
                                     sBIRTHDAY);
                  --児童生徒氏名カナ                                  
                 rWK130R082.JIDO_SHIMEI_KANA := sSHIMEIKANA;
                 --児童生徒氏名漢字
                 rWK130R082.JIDO_SHIMEI_KANJI := sSHIMEI;
                 --表示生年月日
                 rWK130R082.SEINENGAPI := sBIRTHDAY;
                 --性別
                 rWK130R082.SEIBETSU := GWK_UIKIGAITENGAKU.SEIBETSU;
                 --児童生徒_支援措置
                 rWK130R082.JIDO_SHIENSOCHI := GWK_UIKIGAITENGAKU.JIDO_SHIENSOTI;
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 START
--                 nRTN := GKBFKHMCTRL(GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO, 
                 nRTN := GKBFKHMCTRL(GWK_UIKIGAITENGAKU.KOJIN_NO,
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 END
                                     g_rJSTP.CHOHYOID, 
                                     1, 
                                     g_vKGAI_SHUTSURYOKUSEIGYO, 
                                     sSHIMEIKANA, 
                                     sSHIMEI, 
                                     sBIRTHDAY);
                 --保護者氏名カナ
                 rWK130R082.HOGOSHA_SHIMEI_KANA := sSHIMEIKANA;
                 --保護者氏名漢字
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                 --rWK130R082.HOGOSHA_SHIMEI_KANJI := sSHIMEI || '　様';
                 rWK130R082.HOGOSHA_SHIMEI_KANJI := sSHIMEI;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                 --児童生徒との関係
                 rWK130R082.HOGOSHA_ZOKUGARA := GWK_UIKIGAITENGAKU.ZOKUGARAMEI;
                 --保護者_支援措置
                 rWK130R082.HOGOSHA_SHIENSOCHI := GWK_UIKIGAITENGAKU.HOGOSHA_SHIENSOTI;
                 --学校名
                 rWK130R082.GAKKO_MEI := GWK_UIKIGAITENGAKU.GENZAISEKIKOU_MEI;
                 --件数
                 rWK130R082.KENSU := g_nKENSAKU;
                 --学校コード
                 rWK130R082.GAKKO_CD := GWK_UIKIGAITENGAKU.GENZAISEKIKOU_CD;
                 --児童生徒氏名_ラベル
                 rWK130R082.JIDO_SHIMEI_LABEL := '児童生徒氏名';
                 --保護者氏名_ラベル
                 rWK130R082.HOGOSHA_SHIMEI_LABEL := '保護者氏名';
                 --学校/行政区_ラベル
                 rWK130R082.GAKKO_GYOSEIKU_LABEL := '学校';
                 --人格区分
                 IF GWK_UIKIGAITENGAKU.JINKAKU_KBN = 1 THEN
                   rWK130R082.JINKAKU_KBN := '＊';
                 ELSE
                   rWK130R082.JINKAKU_KBN := NULL;
                 END IF;
                 --改ページキー
                 rWK130R082.BREAK_NO := NULL;
                 --端末番号
                 rWK130R082.WSNUM := g_sWSNUM;
                 --即時バッチ区分
                 rWK130R082.BATCHKBN := 2;
                 --ジョブNO
                 rWK130R082.JOBNUM := g_nJOBNUM;
                 INSERT INTO GKBWL130R082 VALUES rWK130R082;
            END LOOP;
            IF rCURSOR%ISOPEN THEN
               CLOSE rCURSOR;
            END IF;
          WHEN 'GKB070R001' THEN
            OPEN rCURSOR FOR VSQL;
            LOOP
              FETCH rCURSOR INTO GWK_UIKIGAITENGAKU;
              EXIT WHEN rCURSOR%NOTFOUND;
                nCNT := nCNT + 1;
-- 2025/09/17 CTC.LW Add Start 1.0.200.000:帳票アウトソーシング連番対応
                rWK070R001.KYOTSU_TSUSU_RENBAN := LPAD(nCNT, 6, '0');                    --業務共通_通数連番
                rWK070R001.KYOTSU_YUHEN_KBN :=  GWK_UIKIGAITENGAKU.YUHEN_KBN ;           --郵返区分
--  2025/12/05 CTC.NI UPDATE START 1.0.402.000:不具合対応
                --rWK070R001.KYOTSU_GAKKO_KBN :=  GWK_UIKIGAITENGAKU.GAKKO_KBN ;           --学校区分
                rWK070R001.KYOTSU_GAKKO_KBN := LPAD(GWK_UIKIGAITENGAKU.GAKKO_KBN, 2, '0'); --学校区分
--  2025/12/05 CTC.NI UPDATE END
-- 2025/09/17 CTC.LW Add End
                --ソート順
                rWK070R001.NO := nCNT;
                --年度
                rWK070R001.NENDO := NULL;
                --改頁コード
                rWK070R001.KAIPAGE_CD := NULL;
                --改頁名
                rWK070R001.KAIPAGE_MEI := NULL;
                --基準日
                rWK070R001.KIJUNBI := NULL;
                --連番
                rWK070R001.RENBAN := NULL;
                nRTN := GKBFKHMCTRL(GWK_UIKIGAITENGAKU.KOJIN_NO, 
                                  g_rJSTP.CHOHYOID, 
                                  0, 
                                  g_vTGAKU_SHUTSURYOKUSEIGYO, 
                                  sSHIMEIKANA, 
                                  sSHIMEI, 
                                  sBIRTHDAY);
                --児童氏名かな
                rWK070R001.JIDO_SHIMEI_KANA := sSHIMEIKANA;
                --児童生徒氏名漢字
                rWK070R001.JIDO_SHIMEI_KANJI := sSHIMEI;
                --表示生年月日
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00572 Start
--                rWK070R001.HYOJI_SEINENGAPI := sBIRTHDAY;
                rWK070R001.HYOJI_SEINENGAPI := NULL;
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00572 End
                --表示性別
                rWK070R001.HYOJI_SEIBETSU := NULL;
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 START
--                nRTN := GKBFKHMCTRL(GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO, 
                nRTN := GKBFKHMCTRL(GWK_UIKIGAITENGAKU.KOJIN_NO,
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 END
                                     g_rJSTP.CHOHYOID, 
                                     1, 
                                     g_vTGAKU_SHUTSURYOKUSEIGYO, 
                                     sSHIMEIKANA, 
                                     sSHIMEI, 
                                     sBIRTHDAY);
                --保護者氏名かな
                rWK070R001.HOGOSHA_SHIMEI_KANA := sSHIMEIKANA;
                --保護者氏名漢字
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK070R001.HOGOSHA_SHIMEI_KANJI := sSHIMEI || '　様';
                rWK070R001.HOGOSHA_SHIMEI_KANJI := sSHIMEI ;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --住所上
                rWK070R001.JUSHO_JODAN := NULL;
                --住所下
                rWK070R001.JUSHO_GEDAN := NULL;
                --行政区名
                rWK070R001.GYOSEIKU_MEI := NULL;
                --学校名
                rWK070R001.GAKKO_MEI := NULL;
                --算定団体名
                rWK070R001.SANTEIDANTAI_MEI := NULL;
                --郵便番号
                rWK070R001.YUBIN_NO := NULL;
                --町名番地
                rWK070R001.CHOMEI_BANCHI := NULL;
                --方書
                rWK070R001.KATAGAKI := NULL;
                --宛先上段
                rWK070R001.ATESAKI_JODAN := GWK_UIKIGAITENGAKU.HOGOSYA_SHIMEI || '　様';
                --宛先下段
                rWK070R001.ATESAKI_GEDAN := NULL;
                --漢字生年月日
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00572 Start
--                rWK070R001.KANJI_SEINENGAPI := NULL;
                rWK070R001.KANJI_SEINENGAPI := sBIRTHDAY;
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00572 End
                --教育委員会名
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK070R001.KYOIKU_KAI_MEI := NULL;
                rWK070R001.KYOIKU_KAI_MEI := g_vKYOIKUKAIMEI;
                --入学期日
                rWK070R001.NYUGAKU_KIJITU := NULL;
                --発送日
                --rWK070R001.HASSOBI := NULL;
                rWK070R001.HASSOBI := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(KKAPK0020.FDAYEDIT20(g_nHAKKOYMD,0,3), 0),' ',''),'　',''); 
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --発送番号
                rWK070R001.HASSO_NO := NULL;
                --公印パス
                rWK070R001.KOIN_PATH := g_vKOUIN;
                --電話番号
                rWK070R001.TANTO_TEL := NULL;
                --担当郵便番号
                rWK070R001.TANTO_YUBIN_NO := NULL;
                --担当住所
                rWK070R001.TANTO_JUSHO := NULL;
                --郵便番号ＢＣ
                rWK070R001.YUBIN_NOBC := NULL;
                --日付１
                rWK070R001.DATE1 := NULL;
                --日付２
                rWK070R001.DATE2 := NULL;
                --日付３
                rWK070R001.DATE3 := NULL;
                --日付４
                rWK070R001.DATE4 := NULL;
                --日付５
                rWK070R001.DATE5 := NULL;
                --項目１
                rWK070R001.KOMOKU1 := NULL;
                --項目２
                rWK070R001.KOMOKU2 := NULL;
                --項目３
                rWK070R001.KOMOKU3 := NULL;
                --項目４
                rWK070R001.KOMOKU4 := NULL;
                --項目５
                rWK070R001.KOMOKU5 := NULL;
                --項目６
                rWK070R001.KOMOKU6 := NULL;
                --項目７
                rWK070R001.KOMOKU7 := NULL;
                --項目８
                rWK070R001.KOMOKU8 := NULL;
                --項目９
                rWK070R001.KOMOKU9 := NULL;
                --項目１０
                rWK070R001.KOMOKU10 := NULL;
                --日付名称１
                rWK070R001.DATE_MEI1 := NULL;
                --日付名称２
                rWK070R001.DATE_MEI2 := NULL;
                --日付名称３
                rWK070R001.DATE_MEI3 := NULL;
                --日付名称４
                rWK070R001.DATE_MEI4 := NULL;
                --日付名称５
                rWK070R001.DATE_MEI5 := NULL;
                --項目名称１
                rWK070R001.KOMOKU_MEI1 := NULL;
                --項目名称２
                rWK070R001.KOMOKU_MEI2 := NULL;
                --項目名称３
                rWK070R001.KOMOKU_MEI3 := NULL;
                --項目名称４
                rWK070R001.KOMOKU_MEI4 := NULL;
                --項目名称５
                rWK070R001.KOMOKU_MEI5 := NULL;
                --項目名称６
                rWK070R001.KOMOKU_MEI6 := NULL;
                --項目名称７
                rWK070R001.KOMOKU_MEI7 := NULL;
                --項目名称８
                rWK070R001.KOMOKU_MEI8 := NULL;
                --項目名称９
                rWK070R001.KOMOKU_MEI9 := NULL;
                --項目名称１０
                rWK070R001.KOMOKU_MEI10 := NULL;
                --学校コード
                rWK070R001.GAKKO_CD := NULL;
                --続柄１
                rWK070R001.ZOKUGARAMEI1 := NULL;
                --続柄２
                rWK070R001.ZOKUGARAMEI2 := NULL;
                --児童郵便番号
                rWK070R001.JIDO_YUBIN_NO := NULL;
                --児童郵便番号ＢＣ
                rWK070R001.JIDO_YUBIN_NOBC := NULL;
                --児童町名番地
                rWK070R001.JIDO_CHOMEI_BANCHI := GWK_UIKIGAITENGAKU.CHOMEI_BANCHI;
                --児童方書
                rWK070R001.JIDO_KATAGAKI :=GWK_UIKIGAITENGAKU.KATAGAKAI;
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 START
--                IF g_sSHIENSOCHI = 1 THEN
                IF g_sSHIENSOCHI = 0 THEN
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 END
                  rWK070R001.ATESAKI_CHOMEI_BANCHI := GWK_UIKIGAITENGAKU.SOFU_JUSHO; --宛先町名番地
                  rWK070R001.ATESAKI_KATAGAKI := GWK_UIKIGAITENGAKU.SOFU_KATAGAKAI; --宛先方書
                  nRTN := KKAPK0010.FYUBINHENSHU(GWK_UIKIGAITENGAKU.SOFU_YUBIN_NO,vYUBIN_NO);
                  IF nRTN = 0 THEN
                    rWK070R001.ATESAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(vYUBIN_NO,0);--送付先郵便番号
                  END IF;
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 START
--                ELSIF g_sSHIENSOCHI = 0 THEN
                ELSIF g_sSHIENSOCHI = 1 THEN
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 END
                  vCTLPRM := GAAPK0030.FDVJUSHO('GKB',GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO,g_sTANTOCODE,g_sWSNUM,GWK_UIKIGAITENGAKU.SOFU_JUSHO,nPRMCTL,0);
                  rWK070R001.ATESAKI_CHOMEI_BANCHI := vCTLPRM; --宛先町名番地
                  IF nPRMCTL = 1 THEN
                   rWK070R001.ATESAKI_YUBIN_NO :=NULL;--宛先郵便番号
                   rWK070R001.ATESAKI_KATAGAKI := NULL; --宛先方書
                  ELSIF nPRMCTL = 0 THEN
                    rWK070R001.ATESAKI_KATAGAKI := GWK_UIKIGAITENGAKU.SOFU_KATAGAKAI; --宛先方書                
                    nRTN := KKAPK0010.FYUBINHENSHU(GWK_UIKIGAITENGAKU.SOFU_YUBIN_NO,vYUBIN_NO);
                  IF nRTN = 0 THEN
                    rWK070R001.ATESAKI_YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(vYUBIN_NO,0);--送付先郵便番号
                  END IF;
                  ELSE
                    NULL;
                  END IF;
                ELSE
                  NULL;
                END IF;
                --カスタマーバーコード
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                IF nPRMCTL = 1 THEN
                  rWK070R001.BC_NO := NULL;
                  ELSE
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                rWK070R001.BC_NO := GWK_UIKIGAITENGAKU.SOFU_YUBIN_BC_NO;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                END IF;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応               
                --役職名
                rWK070R001.YAKUSHOKU_MEI := g_vKYOIKUKAIMEI;
                --首長名
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 
                --rWK070R001.SHUCHO_MEI :=NULL;
                rWK070R001.SHUCHO_MEI := g_vKYOIKUKAISHUCHOMEI;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応    
                --担当立名
                rWK070R001.TANTO_RITSU_MEI :=NULL;
                --担当番号内線
                rWK070R001.TANTO_TEL_NAISEN :=NULL;
                --表示帳票連番
                rWK070R001.HYOJI_CHOHYO_NO :=NULL;
                --教育委員会連絡先
                rWK070R001.KYOIKU_RENRAKUSAKI := g_vKYOIKUKAISHUCHOMEI;
                 --文書番号
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START 
                --IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
                IF rBUNNUMEDITKEKA2.NUMUMUFLG = 0 THEN
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END  
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応                  
                  --rWK070R001.BUNSHO_NO := g_vBUNNUM_TENNYUGAKU;
                  rWK070R001.BUNSHO_NO := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_vBUNNUM_TENNYUGAKU, 0),' ',''),'　',''); 
                ELSE
                  rWK070R001.BUNSHO_NO := NULL;
                END IF;
                --発行年月日
                --rWK070R001.HAKKOBI := KKAPK0020.FDAYEDIT20(g_nHAKKOYMD,0,3);
                rWK070R001.HAKKOBI := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(KKAPK0020.FDAYEDIT20(g_nHAKKOYMD,0,3), 0),' ',''),'　',''); 
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応   
                --公印（省略）
                rWK070R001.KOIN_SHORYAKU := g_vTENNYUGAKUKOINSHORYAKU;
                --公印（注釈）
                rWK070R001.KOIN_CHUSHAKU := g_vTENNYUGAKUKOINCHUSHAKU;
                --帳票タイトル
                rWK070R001.CHOHYO_TITLE := g_vTENNYUGAKUTITLE;
                --通知文
                rWK070R001.TSUCHIBUN := g_vTENNYUGAKUTSUCHIBUN;
                --転学期日
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 
                --rWK070R001.TENGAKU_KIJITSU := GWK_UIKIGAITENGAKU.TENGAKUKIJITU;
                rWK070R001.TENGAKU_KIJITSU := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(GWK_UIKIGAITENGAKU.TENGAKUKIJITU, 0),' ',''),'　','');
                --前就学校
                rWK070R001.MAE_GAKKO := GWK_UIKIGAITENGAKU.MAESHUGAKUKOU;
                --（前就学校）学年
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK070R001.MAE_GAKUNEN := GWK_UIKIGAITENGAKU.MAESHUGAKU_GAKUNEN_MEI_R;
                IF GWK_UIKIGAITENGAKU.MAESHUGAKU_GAKUNEN_MEI_R IS NOT NULL THEN
                rWK070R001.MAE_GAKUNEN := KKAPK0010.FMULTIBYTEHENKAN('第'||GWK_UIKIGAITENGAKU.MAESHUGAKU_GAKUNEN_MEI_R||'学年', 0);
                END IF;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --転入期日
                --rWK070R001.TENNYU_KIJITSU :=GWK_UIKIGAITENGAKU.TENNYUKIJITSU;
                rWK070R001.TENNYU_KIJITSU :=REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(GWK_UIKIGAITENGAKU.TENNYUKIJITSU, 0),' ',''),'　','');
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 
                --転入学校
                rWK070R001.ATO_GAKKO := GWK_UIKIGAITENGAKU.TENNYUGAKO;
                --（転入学校）学年
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK070R001.ATO_GAKUNEN := GWK_UIKIGAITENGAKU.TENNYUGAKO_GAKUNEN;
                IF GWK_UIKIGAITENGAKU.TENNYUGAKO_GAKUNEN IS NOT NULL THEN
                rWK070R001.ATO_GAKUNEN := KKAPK0010.FMULTIBYTEHENKAN('第'||GWK_UIKIGAITENGAKU.TENNYUGAKO_GAKUNEN||'学年',0);
                END IF;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                 --お問い合わせ先１
                rWK070R001.TOIAWASESAKI1 := GWK_UIKIGAITENGAKU.TOIAWASESAKI1;
                --お問い合わせ先２
                rWK070R001.TOIAWASESAKI2 := GWK_UIKIGAITENGAKU.TOIAWASESAKI2;
                --お問い合わせ先３
                rWK070R001.TOIAWASESAKI3 := GWK_UIKIGAITENGAKU.TOIAWASESAKI3;
                --特記事項
                rWK070R001.TOKKIJIKO := REPLACE(g_vTENNYUGAKUTOKKIJIKO, chr(13) || chr(10), '#');
                --備考
                rWK070R001.BIKO := REPLACE(g_vTENNYUGAKUBIKO, chr(13) || chr(10), '#');
                --様式番号
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --rWK070R001.YOSHIKI_NO := g_vTENNYUGAKUYOSHIKIBANGO;
                rWK070R001.YOSHIKI_NO := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_vTENNYUGAKUYOSHIKIBANGO, 0),' ',''),'　','');
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
                --備考タイトル
                rWK070R001.BIKO_TITLE := g_vTENNYUGAKUBIKOTITLE;
                --児童生徒宛名番号
                rWK070R001.KOJIN_NO := GWK_UIKIGAITENGAKU.KOJIN_NO;
                --保護者宛名番号
                rWK070R001.HOGOSYA_KOJIN_NO := GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO;
                --改ページキー
                rWK070R001.BREAK_NO := NULL;
                --端末番号
                rWK070R001.WSNUM := g_sWSNUM;
                --即時バッチ区分
                rWK070R001.BATCHKBN := 2;
                --ジョブNO
                rWK070R001.JOBNUM := g_nJOBNUM;
                INSERT INTO GKBWL070R001 VALUES rWK070R001;
                --発行履歴を作成する
                IF g_sHAKKORIREKI = 0 THEN
--                   変数.文書番号_転入学を文書番号情報（構造体）.MAEMOJIと文書番号情報（構造体）.USHIROMOJIの値で切り抜いた値
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START 
                /*   sBUNSHONOTMP := SUBSTR((SUBSTR(g_vBUNNUM_TENNYUGAKU,(LENGTH(rBUNNUMSRCINF.MAEMOJI)+1))),
                                          1,LENGTH(SUBSTR(g_vBUNNUM_TENNYUGAKU,
                                          (LENGTH(rBUNNUMSRCINF.MAEMOJI)+1)))-LENGTH(rBUNNUMSRCINF.USHIROMOJI));
                   sBUNSHONOTMP :=KKAPK0010.FSTRCNV(sBUNSHONOTMP,1);                        
                   nRTN := GKAFKHAKKOR('GKB',                                               --業務コード
                                        GWK_UIKIGAITENGAKU.KOJIN_NO,                        --宛名番号
                                        g_rJSTP.CHOHYONUM,                                        --帳票コード
                                        TO_NUMBER(SUBSTR(TO_CHAR(SYSDATE,'YYYYMMDD'),1,4)), --年度
                                        1,                                                  --処理区分
                                        '転入学通知書',                                      --通知書種別
                                        TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),             --発行日
                                        TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'HH24MISS')),        --発行時間
                                        1,                                                  --発行枚数
                                        g_sTANTOCODE,                                       --発行職員宛名番号
                                        g_nHAKKOYMD,                                        --送付日
                                        NULL,                                               --通知場所
                                        rBUNNUMSRCINF.MAEMOJI,                              --文書番号接頭語
--  2024/11/26 ZCZL.ZHANGLEI UPDATE 0.3.000.008:IT_GKC_00329横展開対応
                                        --TO_NUMBER(sBUNSHONOTMP),                            --文書番号
                                        sBUNSHONOTMP,                            --文書番号
                                        rBUNNUMSRCINF.USHIROMOJI,                           --文書番号接尾語
                                        GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO,                --通知対象者宛名番号
                                        NULL,                                               --転出先自治体コード
                                        g_sWSNUM                                            --更新端末番号
                                        ); */
                                        
                   sBUNSHONOTMP := SUBSTR((SUBSTR(g_vBUNNUM_TENNYUGAKU,(LENGTH(rBUNNUMSRCINF2.MAEMOJI)+1))),

                                          1,LENGTH(SUBSTR(g_vBUNNUM_TENNYUGAKU,
                                          (LENGTH(rBUNNUMSRCINF2.MAEMOJI)+1)))-LENGTH(rBUNNUMSRCINF2.USHIROMOJI));
                   sBUNSHONOTMP :=KKAPK0010.FSTRCNV(sBUNSHONOTMP,1);                        
                   nRTN := GKAFKHAKKOR('GKB',                                               --業務コード
                                        GWK_UIKIGAITENGAKU.KOJIN_NO,                        --宛名番号
                                        g_rJSTP.CHOHYONUM,                                        --帳票コード
                                        TO_NUMBER(SUBSTR(TO_CHAR(SYSDATE,'YYYYMMDD'),1,4)), --年度
                                        1,                                                  --処理区分
                                        '転入学通知書',                                      --通知書種別
                                        TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),             --発行日
                                        TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'HH24MISS')),        --発行時間
                                        1,                                                  --発行枚数
                                        g_sTANTOCODE,                                       --発行職員宛名番号
                                        g_nHAKKOYMD,                                        --送付日
                                        NULL,                                               --通知場所
                                        rBUNNUMSRCINF2.MAEMOJI,                              --文書番号接頭語
--  2024/11/26 ZCZL.ZHANGLEI UPDATE 0.3.000.008:IT_GKC_00329横展開対応
                                        --TO_NUMBER(sBUNSHONOTMP),                            --文書番号
                                        sBUNSHONOTMP,                            --文書番号
                                        rBUNNUMSRCINF2.USHIROMOJI,                           --文書番号接尾語
                                        GWK_UIKIGAITENGAKU.HOGOSYA_KOJIN_NO,                --通知対象者宛名番号
                                        NULL,                                               --転出先自治体コード
                                        g_sWSNUM                                            --更新端末番号
                                        );   
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END                         
                    IF nRTN = 1 THEN
                      bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME, 1, '', '', '[転入学通知書]共通関数(帳票発行履歴作成)(GKAFKHAKKOR)でエラーが発生しました。宛名番号　' || GWK_UIKIGAITENGAKU.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
                    END IF;
                END IF;
                --文書番号編集結果の取得  
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 START             
              /*  IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (rBUNNUMSRCINF.NUMINCTYPE = 1 OR rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
                    KKAPK0040.SBunNumIc(rBUNNUMSRCINF, rBUNNUMEDITKEKA);
                END IF;
                --文書番号保管を追加する
                IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
                  g_rHOKANBUNNUM(nCNT).KOJINNUM := GWK_UIKIGAITENGAKU.KOJIN_NO;
                  g_rHOKANBUNNUM(nCNT).BUNNUM_ANNAISHOU := rBUNNUMEDITKEKA.NUM; 
                END IF;
                g_vBUNNUM_TENNYUGAKU := rBUNNUMEDITKEKA.NUM; */
                
                
                IF rBUNNUMEDITKEKA2.NUMUMUFLG = 0 AND (rBUNNUMSRCINF2.NUMINCTYPE = 1 OR rBUNNUMSRCINF2.NUMINCTYPE = 2) THEN

                    KKAPK0040.SBunNumIc(rBUNNUMSRCINF2, rBUNNUMEDITKEKA2);
                END IF;
                --文書番号保管を追加する
                IF rBUNNUMEDITKEKA2.NUMUMUFLG = 0 THEN
                  g_rHOKANBUNNUM(nCNT).KOJINNUM := GWK_UIKIGAITENGAKU.KOJIN_NO;
                  g_rHOKANBUNNUM(nCNT).BUNNUM_ANNAISHOU := rBUNNUMEDITKEKA2.NUM; 
                END IF;
                g_vBUNNUM_TENNYUGAKU := rBUNNUMEDITKEKA2.NUM;
--  2025/01/16 JPJYS.LIUJUNHAO UPDATE 0.3.000.010:IT_GKB_10177対応 END
            END LOOP;
            --発送者文字切れリストの作成
            bRTN:= GKAPK00010.FKMJGRLST(g_nJOBNUM,g_sWSNUM,g_sTANTOCODE,'GKB070R001',1,nKENSAKU);
            IF NOT bRTN THEN
              bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME, 1, '', '', '[転入学通知書]共通関数(各種通知書発送者文字切れリスト(GKAPK00010)でエラーが発生しました。　宛名番号：' || GWK_UIKIGAITENGAKU.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
            END IF;
            IF rCURSOR%ISOPEN THEN
               CLOSE rCURSOR;
            END IF;
          ELSE
            NULL;
        END CASE;
        g_nKENSAKU := nCNT;
        bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME, 0, '', '', '区域外満了通知書、転入学通知書ＣＳＶ'||g_nKENSAKU ||' 件を出力しました。', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
          IF rCURSOR%ISOPEN THEN
               CLOSE rCURSOR;
           END IF;
           bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 1, SQLCODE, SQLERRM, 'ＣＳＶファイルの書き出し処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
           RETURN FALSE;
    END FUNC_CSV_CREATE;    
    --------------------------------------------------------
    --  機能概要      : 条件取得処理
    --  パラメータ    : o_vRESULT    処理結果
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET
        RETURN BOOLEAN
    IS
       bRTN                          BOOLEAN;          --戻り値
    BEGIN
      VMSG := '' ;
      g_nKIJUNSTARTYMD := KKAPK0020.FNENDOHENKAN(g_nKIJUNSTARTYMD);
      IF g_nKIJUNSTARTYMD =0  THEN
        RETURN FALSE;
      END IF;
      g_nKIJUNENDYMD := KKAPK0020.FNENDOHENKAN(g_nKIJUNENDYMD);
      IF g_nKIJUNENDYMD = 0 THEN
        RETURN FALSE;
      END IF;
      g_nTENNYUKIGENYMD := KKAPK0020.FNENDOHENKAN(g_nTENNYUKIGENYMD);
      IF g_nTENNYUKIGENYMD= 0 THEN
        RETURN FALSE;
      END IF;
      g_nHAKKOYMD := KKAPK0020.FNENDOHENKAN(g_nHAKKOYMD);
      IF g_nHAKKOYMD= 0 THEN
        RETURN FALSE;
      END IF;
--  2024/11/16 JPJYS.LIUHUAIQI Add 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
      --転学期日和暦→西歴
      g_nTENGAKUKIJITSU := KKAPK0020.FNENDOHENKAN(g_nTENGAKUKIJITSU);
      IF g_nTENGAKUKIJITSU =0  THEN
        RETURN FALSE;
      END IF;
      --転入期日和暦→西歴
      g_nTENNYUKIJITSU := KKAPK0020.FNENDOHENKAN(g_nTENNYUKIJITSU);
      IF g_nTENNYUKIJITSU =0  THEN
        RETURN FALSE;
      END IF;
--  2024/11/16 JPJYS.LIUHUAIQI Add 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
          RETURN FALSE;
    END FUNC_JYOKEN_GET;
    --------------------------------------------------------
    --  機能概要      : 区域外転学対象者ワーク作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
    --------------------------------------------------------
    FUNCTION FUNC_UIKIGAITENGAKU
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;  --戻り値
        rKUIKIGTGAKU                  GKBWKUIKIGAITENGAKU%ROWTYPE;
        nRTN                          PLS_INTEGER;
        o_eRSOFU_REC                  GABTSOFUSAKI%ROWTYPE;
      --KARI  
        o_eATENA_REC                  GABTATENAKIHON%ROWTYPE;
        --KARI
        sMEISHO                       NVARCHAR2(100);
        sMEISHOKANA                   NVARCHAR2(100);
        sYOBI                         NVARCHAR2(100);
        nPRMCTL                       NUMBER;            --抑止レベル３制御の要否
        sCHOMEI_BANCHI                NVARCHAR2(1000);
        vCTLPRM                       NVARCHAR2(500);    --住所マスク文字列
        GAKUNENMEI                    NVARCHAR2(500);    --学年名
        GIMUKYOIKU_GAKUNENMEI         NVARCHAR2(500);   --義務教育学校学年名
        sMGAKKO_CD                    NVARCHAR2(100);    --文部科学省学校コード
        nKOJINSETAIKBN                NUMBER;
        nIDOYOKUSHIKBN                NUMBER;
        nHAKKOYOKUSHIKBN              NUMBER;
        nSHOKAIYOKUSHIKBN             NUMBER;
        vSHORICHUIKBN                 NVARCHAR2(100);
        nYOKUSHIKBN                   NUMBER;   --抑止区分（1：支援措置、2：仮支援措置、4：その他抑止）
        nLENGTH                       NUMBER;   --パラメータの配列の長度
        aCONSPRM                      A_CONS_PRM;--パラメータの配列
        KYOIKUIINKAI_CD               NUMBER; --教育委員会コード
        vSQL                          NVARCHAR2(30000);
        TYPE CURTYPE                  IS REF CURSOR;
        rCURSOR                       CURTYPE;
        TYPE GAKUREIBO_REC IS RECORD(
         KOJIN_NO                    GKBTGAKUREIBO.KOJIN_NO%TYPE, 
         JINKAKU_KBN                 GABTATENAKIHON.JINKAKU_KBN%TYPE, 
         JSHIMEI_KANA                GABTATENAKIHON.SHIMEI_KANA%TYPE, 
         JSHIMEI_KANJI               GABTATENAKIHON.SHIMEI_KANJI%TYPE, 
         SEINENGAPI                  GABTATENAKIHON.SEINENGAPI%TYPE, 
         CHOMEI                      GABTATENAKIHON.CHOMEI%TYPE, 
         BANCHI                      GABTATENAKIHON.BANCHI%TYPE, 
         KATAGAKI                    GABTATENAKIHON.KATAGAKI%TYPE, 
         HOGOSHY_KOJIN_NO            GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE, 
         SETAI_NO                    GABTATENAKIHON.SETAI_NO%TYPE, 
         HSHIMEI_KANA                GABTATENAKIHON.SHIMEI_KANA%TYPE, 
         HSHIMEI_KANJI               GABTATENAKIHON.SHIMEI_KANJI%TYPE, 
         HOGOSYA_ZOKUGARA1           GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1%TYPE, 
         HOGOSYA_ZOKUGARA2           GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2%TYPE, 
         HOGOSYA_ZOKUGARA3           GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3%TYPE, 
         HOGOSYA_ZOKUGARA4           GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4%TYPE, 
         SYOGAKO_CD                  GKBTGAKUREIBO.SYOGAKO_CD%TYPE, 
         SYOGAKO_TENNYUGAKU_BI       GKBTGAKUREIBO.SYOGAKO_TENNYUGAKU_BI%TYPE, 
         TYUGAKO_CD                  GKBTGAKUREIBO.TYUGAKO_CD%TYPE, 
         TYUGAKO_TENNYUGAKU_BI       GKBTGAKUREIBO.TYUGAKO_TENNYUGAKU_BI%TYPE, 
         KUIKIGAI_CD                 GKBTGAKUREIBO.KUIKIGAI_CD%TYPE, 
         KUIKIGAI_TENNYUGAKU_BI      GKBTGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI%TYPE, 
         KUIKIGAI_TENGAKU_BI         GKBTGAKUREIBO.KUIKIGAI_TENGAKU_BI%TYPE, 
         GAKUNEN                     GKBTGAKUREIBO.GAKUNEN%TYPE, 
         SYOGAKO_TENNYUGAKU_GAKUNEN  GKBTGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN%TYPE, 
         TYUGAKO_TENNYUGAKU_GAKUNEN  GKBTGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN%TYPE, 
         KUIKIGAI_TENGAKU_GAKUNEN    GKBTGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN%TYPE, 
         GAKKO_KBN_CD                GKBTGAKUREIBO.GAKKO_KBN_CD%TYPE, 
         SEIBETSU                    GKBTGAKUREIBO.SEIBETSU%TYPE, 
         SHITEI_SYOGAKO_CD           GKBTGAKUREIBO.SHITEI_SYOGAKO_CD%TYPE, 
         SHITEI_TYUGAKO_CD           GKBTGAKUREIBO.SHITEI_TYUGAKO_CD%TYPE, 
         HENKO_GAKUNEN_SYOGAKO       GKBTGAKUREIBO.HENKO_GAKUNEN_SYOGAKO%TYPE, 
         HENKO_GAKUNEN_TYUGAKO       GKBTGAKUREIBO.HENKO_GAKUNEN_TYUGAKO%TYPE, 
         KUIKIGAISHUGAKU_KAISI_BI    GKBTGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI%TYPE, 
         KUIKIGAISHUGAKU_SYURYO_BI   GKBTGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI%TYPE
        );
        rGAKUREIBO                   GAKUREIBO_REC;
-- 2025/07/01 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17602
        o_sHOGOSHA_SHIMEI_KANA NVARCHAR2(1000); --保護者氏名カナ
        o_sHOGOSHA_SHIMEI_KANJI NVARCHAR2(1000); --保護者氏名漢字
        o_sHOGOSHA_SEINENGAPI NVARCHAR2(1000); --保護者表示生年月日
        g_nRTN NUMBER;
-- 2025/07/01 CTC.HJF UPDATE End
    BEGIN
      vSQL := '';
      vSQL :=   '      SELECT REIBO.KOJIN_NO                   AS KOJIN_NO ';             
      vSQL := vSQL || '      ,JIDOWA.JINKAKU_KBN               AS JINKAKU_KBN';
      vSQL := vSQL || '      ,JIDOWA.SHIMEI_KANA               AS JSHIMEI_KANA';
      vSQL := vSQL || '      ,JIDOWA.SHIMEI_KANJI              AS JSHIMEI_KANJI';
      vSQL := vSQL || '      ,JIDOWA.SEINENGAPI                AS SEINENGAPI';
      vSQL := vSQL || '      ,JIDOWA.CHOMEI                    AS CHOMEI';
      vSQL := vSQL || '      ,JIDOWA.BANCHI                    AS BANCHI';
      vSQL := vSQL || '      ,JIDOWA.KATAGAKI                  AS KATAGAKI';
      vSQL := vSQL || '      ,REIBO.HOGOSYA_KOJIN_NO           AS HOGOSHY_KOJIN_NO';
      vSQL := vSQL || '      ,HOKOSYA.SETAI_NO                 AS SETAI_NO';
      vSQL := vSQL || '      ,HOKOSYA.SHIMEI_KANA              AS HSHIMEI_KANA';
      vSQL := vSQL || '      ,HOKOSYA.SHIMEI_KANJI             AS HSHIMEI_KANJI';
      vSQL := vSQL || '      ,REIBO.HOGOSYA_ZOKUGARA1          AS HOGOSYA_ZOKUGARA1';
      vSQL := vSQL || '      ,REIBO.HOGOSYA_ZOKUGARA2          AS HOGOSYA_ZOKUGARA2';
      vSQL := vSQL || '      ,REIBO.HOGOSYA_ZOKUGARA3          AS HOGOSYA_ZOKUGARA3';
      vSQL := vSQL || '      ,REIBO.HOGOSYA_ZOKUGARA4          AS HOGOSYA_ZOKUGARA4';
      vSQL := vSQL || '      ,REIBO.SYOGAKO_CD                 AS SYOGAKO_CD';
      vSQL := vSQL || '      ,REIBO.SYOGAKO_TENNYUGAKU_BI      AS SYOGAKO_TENNYUGAKU_BI';
      vSQL := vSQL || '      ,REIBO.TYUGAKO_CD                 AS TYUGAKO_CD';
      vSQL := vSQL || '      ,REIBO.TYUGAKO_TENNYUGAKU_BI      AS TYUGAKO_TENNYUGAKU_BI';
      vSQL := vSQL || '      ,REIBO.KUIKIGAI_CD                AS KUIKIGAI_CD';
      vSQL := vSQL || '      ,REIBO.KUIKIGAI_TENNYUGAKU_BI     AS KUIKIGAI_TENNYUGAKU_BI';
      vSQL := vSQL || '      ,REIBO.KUIKIGAI_TENGAKU_BI        AS KUIKIGAI_TENGAKU_BI';
      vSQL := vSQL || '      ,REIBO.GAKUNEN                    AS GAKUNEN';
      vSQL := vSQL || '      ,REIBO.SYOGAKO_TENNYUGAKU_GAKUNEN AS SYOGAKO_TENNYUGAKU_GAKUNEN';
      vSQL := vSQL || '      ,REIBO.TYUGAKO_TENNYUGAKU_GAKUNEN AS TYUGAKO_TENNYUGAKU_GAKUNEN';
      vSQL := vSQL || '      ,REIBO.KUIKIGAI_TENGAKU_GAKUNEN   AS KUIKIGAI_TENGAKU_GAKUNEN';
      vSQL := vSQL || '      ,REIBO.GAKKO_KBN_CD               AS GAKKO_KBN_CD';
      vSQL := vSQL || '      ,REIBO.SEIBETSU                   AS SEIBETSU';
      vSQL := vSQL || '      ,REIBO.SHITEI_SYOGAKO_CD          AS SHITEI_SYOGAKO_CD';
      vSQL := vSQL || '      ,REIBO.SHITEI_TYUGAKO_CD          AS SHITEI_TYUGAKO_CD';
      vSQL := vSQL || '      ,REIBO.HENKO_GAKUNEN_SYOGAKO      AS HENKO_GAKUNEN_SYOGAKO';
      vSQL := vSQL || '      ,REIBO.HENKO_GAKUNEN_TYUGAKO      AS HENKO_GAKUNEN_TYUGAKO';
      vSQL := vSQL || '      ,REIBO.KUIKIGAISHUGAKU_KAISI_BI   AS KUIKIGAISHUGAKU_KAISI_BI';
      vSQL := vSQL || '      ,REIBO.KUIKIGAISHUGAKU_SYURYO_BI  AS KUIKIGAISHUGAKU_SYURYO_BI';
      vSQL := vSQL || '  FROM GKBTGAKUREIBO REIBO,GABTATENAKIHON JIDOWA,GABTATENAKIHON HOKOSYA ';
      vSQL := vSQL || ' WHERE REIBO.KUIKIGAISHUGAKU_SYURYO_BI BETWEEN ' || g_nKIJUNSTARTYMD || ' AND ' || g_nKIJUNENDYMD;
--  2024/11/16 JPJYS.LIUHUAIQI Delete 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
--      vSQL := vSQL || '  AND REIBO.KUIKIGAI_CD <> 0';
--      vSQL := vSQL || '  AND (CASE  ';
--      vSQL := vSQL || '       WHEN REIBO.GAKUNEN <= 6 THEN';
--      vSQL := vSQL || '         (REIBO.SYOGAKO_TENNYUGAKU_BI)';
--      vSQL := vSQL || '       WHEN REIBO.GAKUNEN >= 7 THEN';
--      vSQL := vSQL || '         (REIBO.TYUGAKO_TENNYUGAKU_BI)';
--      vSQL := vSQL || '       ELSE';
--      vSQL := vSQL || '         NULL';
--      vSQL := vSQL || '       END) BETWEEN '|| g_nKIJUNSTARTYMD || ' AND ' || g_nKIJUNENDYMD;
--  2024/11/16 JPJYS.LIUHUAIQI Delete 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
      vSQL := vSQL || '  AND REIBO.GEN_NENGAPI      = 0';
      vSQL := vSQL || '  AND REIBO.SAISHIN_KBN      = 0';
      vSQL := vSQL || '  AND REIBO.SAKUJO_FLG       = 0';
      vSQL := vSQL || '  AND REIBO.KOJIN_NO         = JIDOWA.KOJIN_NO';
      vSQL := vSQL || '  AND REIBO.HOGOSYA_KOJIN_NO = HOKOSYA.KOJIN_NO';
 
      g_nUPDLOGSEQ := g_nUPDLOGSEQ + 1;
      -- 関数開始
      bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外転学対象者ワーク作成処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 2);
      DELETE GKBWKUIKIGAITENGAKU 
       WHERE WSNUM    = g_sWSNUM 
         AND BATCHKBN = 2;
      OPEN rCURSOR FOR VSQL;
      LOOP
        FETCH rCURSOR INTO rGAKUREIBO;
        EXIT WHEN rCURSOR%NOTFOUND;
         --宛名番号
         rKUIKIGTGAKU.KOJIN_NO := rGAKUREIBO.KOJIN_NO;
         --人格区分
         rKUIKIGTGAKU.JINKAKU_KBN := rGAKUREIBO.JINKAKU_KBN;
         --児童氏名カナ
         rKUIKIGTGAKU.JIDO_SHIMEI_KANA := rGAKUREIBO.JSHIMEI_KANA;
         --児童氏名漢字
         rKUIKIGTGAKU.JIDO_SHIMEI_KANJI := rGAKUREIBO.JSHIMEI_KANJI;
         --生年月日
         IF rGAKUREIBO.JINKAKU_KBN = 0 THEN
           rKUIKIGTGAKU.SEINENGAPI := KKAPK0020.FDAYEDIT20(rGAKUREIBO.SEINENGAPI,0,3);
         ELSIF rGAKUREIBO.JINKAKU_KBN = 1 THEN
           rKUIKIGTGAKU.SEINENGAPI := KKAPK0020.FNENDOHENKAN(rGAKUREIBO.SEINENGAPI);
         ELSE
           NULL;
         END IF;
         --保護者宛名番号
         rKUIKIGTGAKU.HOGOSYA_KOJIN_NO :=rGAKUREIBO.HOGOSHY_KOJIN_NO;
         --送付先情報を取得
         --KARI
       /*  nRTN := GAAPK0030.FSOFUSAKI(rGAKUREIBO.HOGOSHY_KOJIN_NO,
                                     'GKB',
                                     0,
                                     TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),
                                     o_eRSOFU_REC);
         IF nRTN = 0 THEN
           --送付先郵便番号
           rKUIKIGTGAKU.SOFU_YUBIN_NO := o_eRSOFU_REC.YUBIN_NO;
           --送付先郵便番号BC 
           rKUIKIGTGAKU.SOFU_YUBIN_BC_NO := o_eRSOFU_REC.YUBIN_NOBC; */
                   --保護者基本情報取得
           nRTN := GAAPK0030.FGETATENA(rGAKUREIBO.HOGOSHY_KOJIN_NO,
                                       'GKB',
                                       TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),
                                       o_eATENA_REC,
                                       o_eRSOFU_REC); 
           --送付先データ編集                            
           IF nRTN = 0 THEN
             IF o_eRSOFU_REC.KOJIN_NO >0  AND o_eRSOFU_REC.KOJIN_NO IS NOT NULL THEN           
               rKUIKIGTGAKU.SOFU_YUBIN_NO := o_eRSOFU_REC.YUBIN_NO; --送付先郵便番号
               rKUIKIGTGAKU.SOFU_YUBIN_BC_NO := o_eRSOFU_REC.YUBIN_NOBC;--送付先郵便番号BC
               rKUIKIGTGAKU.SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1,NULL,o_eRSOFU_REC.CHOMEI,o_eRSOFU_REC.BANCHI,NULL,NULL);--送付先住所
               rKUIKIGTGAKU.SOFU_KATAGAKAI := o_eRSOFU_REC.KATAGAKI;--送付先方書
              ELSE 
               rKUIKIGTGAKU.SOFU_YUBIN_NO := o_eATENA_REC.YUBIN_NO; --送付先郵便番号
               rKUIKIGTGAKU.SOFU_YUBIN_BC_NO := o_eATENA_REC.YUBIN_NOBC;--送付先郵便番号BC
               rKUIKIGTGAKU.SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1,NULL,o_eATENA_REC.CHOMEI,o_eATENA_REC.BANCHI,NULL,NULL);--送付先住所
               rKUIKIGTGAKU.SOFU_KATAGAKAI := o_eATENA_REC.KATAGAKI;--送付先方書
               END IF; 
            END IF;      
           --支援措置判定 
            IF g_sSHIENSOCHI = 0 THEN
                vCTLPRM := GAAPK0030.FDVJUSHO('GKB',rGAKUREIBO.HOGOSHY_KOJIN_NO,g_sTANTOCODE,g_sWSNUM,rKUIKIGTGAKU.SOFU_JUSHO ,nPRMCTL,2);
                IF nPRMCTL = 1 THEN
                   rKUIKIGTGAKU.SOFU_JUSHO := vCTLPRM;--送付先住所
                   rKUIKIGTGAKU.SOFU_KATAGAKAI := NULL;--送付先方書
                   rKUIKIGTGAKU.SOFU_YUBIN_NO := NULL; --送付先郵便番号
                   rKUIKIGTGAKU.SOFU_YUBIN_BC_NO := NULL;--送付先郵便番号BC
                 END IF; 
            END IF;                     
     --KARI         
           --送付先住所
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
           --rKUIKIGTGAKU.SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1,NULL,o_eRSOFU_REC.CHOMEI,o_eRSOFU_REC.KATAGAKI,NULL,NULL);
        --KARI      
         /*  rKUIKIGTGAKU.SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1,NULL,o_eRSOFU_REC.CHOMEI,o_eRSOFU_REC.BANCHI,NULL,NULL);
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
           --送付先方書
           rKUIKIGTGAKU.SOFU_KATAGAKAI := o_eRSOFU_REC.KATAGAKI;
         END IF;  */
         
           --KARI 
         --世帯番号
         rKUIKIGTGAKU.SETAI_NO := rGAKUREIBO.SETAI_NO;
-- 2025/07/01 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17602
         g_nRTN := GKBFKHMCTRL(rGAKUREIBO.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_vKGAI_SHUTSURYOKUSEIGYO, o_sHOGOSHA_SHIMEI_KANA, o_sHOGOSHA_SHIMEI_KANJI, o_sHOGOSHA_SEINENGAPI);
         --保護者氏名カナ
         --rKUIKIGTGAKU.HOGOSYA_SHIMEI_KANA := rGAKUREIBO.HSHIMEI_KANA;
         rKUIKIGTGAKU.HOGOSYA_SHIMEI_KANA := o_sHOGOSHA_SHIMEI_KANA;
         --保護者氏名漢字
         --rKUIKIGTGAKU.HOGOSYA_SHIMEI := rGAKUREIBO.HSHIMEI_KANJI;
         rKUIKIGTGAKU.HOGOSYA_SHIMEI := o_sHOGOSHA_SHIMEI_KANJI;
-- 2025/07/01 CTC.HJF UPDATE End
         --性別
         nRTN := KKAPK0030.FCDGetR('GKB','021','0001',rGAKUREIBO.SEIBETSU,sMEISHO,sMEISHOKANA,sYOBI);
         IF nRTN = 0 THEN
           rKUIKIGTGAKU.SEIBETSU := sMEISHO;
         END IF;
         --続柄名
         rKUIKIGTGAKU.ZOKUGARAMEI := GKBFKZKGMGET2(2,
                                                   rGAKUREIBO.HOGOSYA_ZOKUGARA1,
                                                   rGAKUREIBO.HOGOSYA_ZOKUGARA2,
                                                   rGAKUREIBO.HOGOSYA_ZOKUGARA3,
                                                   rGAKUREIBO.HOGOSYA_ZOKUGARA4);
         sCHOMEI_BANCHI := GAAPK0010.FADDRESSEDIT(1,NULL,rGAKUREIBO.CHOMEI,rGAKUREIBO.BANCHI,NULL,NULL);                                          
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 START
--         IF g_sSHIENSOCHI = 1 THEN
         IF g_sSHIENSOCHI = 0 THEN
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 END
--  2025/01/10 JPJYS.LIZIZHONG Update 0.3.000.010:IT_GKB_10215  STR
            IF o_eRSOFU_REC.CHOMEI IS NULL AND o_eRSOFU_REC.BANCHI IS NULL AND o_eRSOFU_REC.KATAGAKI IS NULL THEN
           rKUIKIGTGAKU.CHOMEI_BANCHI := sCHOMEI_BANCHI;  --町名番地
           rKUIKIGTGAKU.KATAGAKAI := rGAKUREIBO.KATAGAKI;  --方書
            END IF;
--  2025/01/10 JPJYS.LIZIZHONG Update 0.3.000.010:IT_GKB_10215  END         
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 START
--         ELSIF g_sSHIENSOCHI = 0 THEN
         ELSIF g_sSHIENSOCHI = 1 THEN
--  2024/11/25 JPJYS.LIUHUAIQI Update 0.3.000.007:IT_GKB_00666、IT_GKB_00667対応 END
           vCTLPRM := GAAPK0030.FDVJUSHO('GKB',rGAKUREIBO.HOGOSHY_KOJIN_NO,g_sTANTOCODE,g_sWSNUM,sCHOMEI_BANCHI,nPRMCTL,0);
           rKUIKIGTGAKU.CHOMEI_BANCHI := vCTLPRM;       --町名番地
           IF nPRMCTL = 1 THEN
             rKUIKIGTGAKU.KATAGAKAI := NULL;  --方書
           ELSIF nPRMCTL = 0 THEN
--  2025/01/10 JPJYS.LIZIZHONG Update 0.3.000.010:IT_GKB_10215 STR
             IF o_eRSOFU_REC.CHOMEI IS NULL AND o_eRSOFU_REC.BANCHI IS NULL AND o_eRSOFU_REC.KATAGAKI IS NULL THEN
             rKUIKIGTGAKU.KATAGAKAI := rGAKUREIBO.KATAGAKI;  --方書
             END IF;
--  2025/01/10 JPJYS.LIZIZHONG Update 0.3.000.010:IT_GKB_10215  END         
           ELSE 
             NULL;
           END IF;
         ELSE
           NULL;
         END IF;  
           
         IF rGAKUREIBO.GAKUNEN <= 6 THEN
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
--           rKUIKIGTGAKU.SHITEIKOU_MEI := GKAFKGKOGTEQ(1,rGAKUREIBO.SYOGAKO_CD);--指定校名
           rKUIKIGTGAKU.SHITEIKOU_MEI := GKAFKGKOGTEQ(1,rGAKUREIBO.SHITEI_SYOGAKO_CD);--指定校名
--           rKUIKIGTGAKU.TENNYUKIJITSU := KKAPK0020.FDAYEDIT20(rGAKUREIBO.SYOGAKO_TENNYUGAKU_BI,0,3);   --転入期日
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
        /*   BEGIN
             SELECT GAKUNENMEI,GIMUKYOIKU_GAKUNENMEI 
               INTO GAKUNENMEI,GIMUKYOIKU_GAKUNENMEI 
               FROM GKBTGAKUNEN  */
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
--              WHERE  GAKUNEN_CD = rGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
              -- WHERE  GAKUNEN_CD = rGAKUREIBO.GAKUNEN;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 
    /*       EXCEPTION
              WHEN OTHERS THEN
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外転学対象者ワーク作成処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);  
           END; */
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
         /*  nRTN :=GKAFKMBKKSCDGET(1,rGAKUREIBO.SYOGAKO_CD,sMGAKKO_CD);
           IF nRTN =0 THEN
             IF SUBSTR(sMGAKKO_CD,1,2) = 'C2' THEN
               rKUIKIGTGAKU.SHITEIKOUGAKUNEN := GIMUKYOIKU_GAKUNENMEI;  --指定校学年
             ELSE
               rKUIKIGTGAKU.SHITEIKOUGAKUNEN := GAKUNENMEI; --指定校学年
             END IF;
           END IF; */
         rKUIKIGTGAKU.SHITEIKOUGAKUNEN  := rGAKUREIBO.GAKUNEN;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
         ELSE
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
--           rKUIKIGTGAKU.SHITEIKOU_MEI := GKAFKGKOGTEQ(2,rGAKUREIBO.TYUGAKO_CD);--指定校名
           rKUIKIGTGAKU.SHITEIKOU_MEI := GKAFKGKOGTEQ(2,rGAKUREIBO.SHITEI_TYUGAKO_CD);--指定校名
--           rKUIKIGTGAKU.TENNYUKIJITSU := KKAPK0020.FDAYEDIT20(rGAKUREIBO.TYUGAKO_TENNYUGAKU_BI,0,3);   --転入期日
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
         /*   BEGIN
             SELECT GAKUNENMEI,GIMUKYOIKU_GAKUNENMEI 
               INTO GAKUNENMEI,GIMUKYOIKU_GAKUNENMEI 
               FROM GKBTGAKUNEN  */
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
--              WHERE  GAKUNEN_CD = rGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
              -- WHERE  GAKUNEN_CD = rGAKUREIBO.GAKUNEN;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応               
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 
        /*   EXCEPTION
              WHEN OTHERS THEN
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外転学対象者ワーク作成処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);  
           END; */
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応 
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
          /* nRTN :=GKAFKMBKKSCDGET(2,rGAKUREIBO.TYUGAKO_CD,sMGAKKO_CD);
           IF nRTN =0 THEN
             IF SUBSTR(sMGAKKO_CD,1,2) = 'C2' THEN
               rKUIKIGTGAKU.SHITEIKOUGAKUNEN := GIMUKYOIKU_GAKUNENMEI;--指定校学年
             ELSE
               rKUIKIGTGAKU.SHITEIKOUGAKUNEN := GAKUNENMEI;--指定校学年
             END IF;
           END IF;  */
           rKUIKIGTGAKU.SHITEIKOUGAKUNEN  := rGAKUREIBO.GAKUNEN;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
         END IF;
         --現在籍校コード
         rKUIKIGTGAKU.GENZAISEKIKOU_CD := rGAKUREIBO.KUIKIGAI_CD;
         --現在籍校名
         rKUIKIGTGAKU.GENZAISEKIKOU_MEI := GKAFKGKOGTEQ(4,rGAKUREIBO.KUIKIGAI_CD);
         BEGIN
             SELECT GAKUNENMEI,GIMUKYOIKU_GAKUNENMEI 
               INTO GAKUNENMEI,GIMUKYOIKU_GAKUNENMEI 
               FROM GKBTGAKUNEN 
              WHERE  GAKUNEN_CD = rGAKUREIBO.GAKUNEN;
           EXCEPTION
              WHEN OTHERS THEN
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外転学対象者ワーク作成処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);  
           END;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
        /*   nRTN :=GKAFKMBKKSCDGET(4,rGAKUREIBO.KUIKIGAI_CD,sMGAKKO_CD);
           IF nRTN =0 THEN
             IF SUBSTR(sMGAKKO_CD,1,2) = 'C2' THEN
               rKUIKIGTGAKU.GENZAISEKIKO_GAKUNEN := GIMUKYOIKU_GAKUNENMEI;--現在籍校学年
               
             ELSE
               rKUIKIGTGAKU.GENZAISEKIKO_GAKUNEN := GAKUNENMEI;--現在籍校学年
             END IF;
           END IF; */
           rKUIKIGTGAKU.GENZAISEKIKO_GAKUNEN := rGAKUREIBO.GAKUNEN;
--  2025/1/9 JPJYS.LIUJUNHAO  UPDATE 0.3.000.009:IT_GKB_10171～IT_GKB_10182、IT_GKB_10209～IT_GKB_10218対応
          -- 就学期間・自                              
          rKUIKIGTGAKU.SHUGAKUKIKAN_FR := KKAPK0020.FDAYEDIT20(rGAKUREIBO.KUIKIGAISHUGAKU_KAISI_BI,0,3);
          -- 就学期間・至                              
          rKUIKIGTGAKU.SHUGAKUKIKAN_TO := KKAPK0020.FDAYEDIT20(rGAKUREIBO.KUIKIGAISHUGAKU_SYURYO_BI,0,3);
          --児童生徒_支援措置
          nRTN := GAAPK0030.FGETDV(rGAKUREIBO.KOJIN_NO,
                           rGAKUREIBO.SETAI_NO,
                           TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),
                           'GKB',
                           0,
                           nKOJINSETAIKBN,
                           nYOKUSHIKBN,
                           nIDOYOKUSHIKBN,
                           nHAKKOYOKUSHIKBN,
                           nSHOKAIYOKUSHIKBN,
                           vSHORICHUIKBN);
-- 2025/06/04 CTC.HJF UPDATE Start 1.0.007.000:GKB_QA13919対応
          --IF nYOKUSHIKBN = 1 THEN
          IF nYOKUSHIKBN > 0 AND nYOKUSHIKBN < 99 THEN
-- 2025/06/04 CTC.HJF UPDATE End
            rKUIKIGTGAKU.JIDO_SHIENSOTI := '対象';
          ELSE
            rKUIKIGTGAKU.JIDO_SHIENSOTI := ' ';
          END IF;
           --保護者_支援措置
          nRTN := GAAPK0030.FGETDV(rGAKUREIBO.HOGOSHY_KOJIN_NO,
                           rGAKUREIBO.SETAI_NO,
                           TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),
                           'GKB',
                           0,
                           nKOJINSETAIKBN,
                           nYOKUSHIKBN,
                           nIDOYOKUSHIKBN,
                           nHAKKOYOKUSHIKBN,
                           nSHOKAIYOKUSHIKBN,
                           vSHORICHUIKBN);
-- 2025/06/04 CTC.HJF UPDATE Start 1.0.007.000:GKB_QA13919対応                           
          --IF nYOKUSHIKBN = 1 THEN
          IF nYOKUSHIKBN > 0 AND nYOKUSHIKBN < 99 THEN
-- 2025/06/04 CTC.HJF UPDATE End
            rKUIKIGTGAKU.HOGOSHA_SHIENSOTI := '対象';
          ELSE
            rKUIKIGTGAKU.HOGOSHA_SHIENSOTI := ' ';
          END IF;
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00582、IT_GKB_00583 Start
         --転学期日
--         rKUIKIGTGAKU.TENGAKUKIJITU := KKAPK0020.FDAYEDIT20(rGAKUREIBO.KUIKIGAI_TENGAKU_BI,0,3);
         rKUIKIGTGAKU.TENGAKUKIJITU := KKAPK0020.FDAYEDIT20(g_nTENGAKUKIJITSU,0,3);
         --転入期日
         rKUIKIGTGAKU.TENNYUKIJITSU := KKAPK0020.FDAYEDIT20(g_nTENNYUKIJITSU,0,3);
--  2024/11/16 JPJYS.LIUHUAIQI Update 0.3.000.006:IT_GKB_00582、IT_GKB_00583 End
         --前就学校
         rKUIKIGTGAKU.MAESHUGAKUKOU := rKUIKIGTGAKU.GENZAISEKIKOU_MEI;
         --前就学_学年名
         rKUIKIGTGAKU.MAESHUGAKU_GAKUNEN_MEI_R := rKUIKIGTGAKU.GENZAISEKIKO_GAKUNEN;
         --転入学校
         rKUIKIGTGAKU.TENNYUGAKO := rKUIKIGTGAKU.SHITEIKOU_MEI;
         --転入学校_学年
         rKUIKIGTGAKU.TENNYUGAKO_GAKUNEN := rKUIKIGTGAKU.SHITEIKOUGAKUNEN;
        IF rGAKUREIBO.GAKUNEN <= 6 THEN
            BEGIN
              SELECT KYOIKUIINKAI_CD 
                INTO KYOIKUIINKAI_CD 
                FROM GKBTSHOGAKKO
                --  2025/01/14 JPJYS.LIUJUNHAO Update 0.3.000.011:IT_GKB_10221、IT_GKB_10230対応
               --WHERE SYOGAKO_CD = rGAKUREIBO.SYOGAKO_CD;
               WHERE SYOGAKO_CD = rGAKUREIBO.SHITEI_SYOGAKO_CD;
               --  2025/01/14 JPJYS.LIUJUNHAO Update 0.3.000.011:IT_GKB_10221、IT_GKB_10230対応
            EXCEPTION
              WHEN OTHERS THEN
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外転学対象者ワーク作成処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);  
           END; 
          ELSE
             BEGIN
              SELECT KYOIKUIINKAI_CD 
                INTO KYOIKUIINKAI_CD 
                FROM GKBTCHUGAKKO
                --  2025/01/14 JPJYS.LIUJUNHAO Update 0.3.000.011:IT_GKB_10221、IT_GKB_10230対応
               --WHERE TYUGAKO_CD = rGAKUREIBO.TYUGAKO_CD;
               WHERE TYUGAKO_CD = rGAKUREIBO.SHITEI_TYUGAKO_CD;
               --  2025/01/14 JPJYS.LIUJUNHAO Update 0.3.000.011:IT_GKB_10221、IT_GKB_10230対応
            EXCEPTION
              WHEN OTHERS THEN
                  bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外転学対象者ワーク作成処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);  
           END;
          END IF; 
         nRTN := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',KYOIKUIINKAI_CD,aCONSPRM,nLENGTH);
         IF nRTN =0 THEN
           --お問い合わせ先１
           rKUIKIGTGAKU.TOIAWASESAKI1 := aCONSPRM(1);
           --お問い合わせ先２
           rKUIKIGTGAKU.TOIAWASESAKI2 := aCONSPRM(6);
           --お問い合わせ先３
           rKUIKIGTGAKU.TOIAWASESAKI3 := aCONSPRM(7);
         ELSE
           bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外転学対象者ワーク作成処理', 1, SQLCODE, SQLERRM, '教育委員会情報を取得する時に共通関数(KKAPK0030.FPRMSHUTOKU)を行った際に、エラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 2);  
         END IF;
         --端末番号
         rKUIKIGTGAKU.WSNUM := g_sWSNUM;
         --即時バッチ区分
         rKUIKIGTGAKU.BATCHKBN := 2;
         --ジョブNO
         rKUIKIGTGAKU.JOBNUM := g_nJOBNUM;
-- 2025/09/17 CTC.LW Add Start 1.0.200.000:帳票アウトソーシング連番対応
         -- 郵返区分
         rKUIKIGTGAKU.YUHEN_KBN := GAAPK0030.FYUHENKBNGET(rGAKUREIBO.HOGOSHY_KOJIN_NO
                                                          , 'GKB'
                                                          , TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'))
                                                          ); 
         -- 学校区分
         rKUIKIGTGAKU.GAKKO_KBN := CASE 
                                     WHEN rGAKUREIBO.GAKUNEN <= 6 THEN 1
                                     WHEN rGAKUREIBO.GAKUNEN >= 7 THEN 2
                                   END; 
-- 2025/09/17 CTC.LW Add End
         INSERT INTO GKBWKUIKIGAITENGAKU VALUES rKUIKIGTGAKU;
      END LOOP;
      IF rCURSOR%ISOPEN THEN
        CLOSE rCURSOR;
      END IF;
      -- 関数終了
      bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外転学対象者ワーク作成処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 2);
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '区域外転学対象者ワーク作成処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
    END FUNC_UIKIGAITENGAKU;
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
        g_oKENSU_LIST.EXTEND(2);
        g_oKENSU_LIST(1) :=GKBEKENSU_RECORD(g_nKENSAKU,'入力 区域外満了通知書、転入学通知書対象件数',1);
        g_oKENSU_LIST(2) :=GKBEKENSU_RECORD(g_nCSVKENSAKU,'出力 区域外満了通知書、転入学通知書ＣＳＶ',2);
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
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        --条件取得処理を呼び出す。
        IF g_nSAKUHYOLOGSEQ <= 1 THEN
          bRTN := FUNC_JYOKEN_GET;
          IF NOT bRTN THEN
             bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
             RETURN FALSE;
          END IF;
          --初期処理を呼び出す。
          bRTN := FUNC_INIT;
          IF NOT bRTN THEN
             bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
             RETURN FALSE;
          END IF;
          --区域外転学対象者ワーク作成処理
          bRTN := FUNC_UIKIGAITENGAKU;
          IF NOT bRTN THEN
             bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
             RETURN FALSE;
          END IF;
        END IF;
        --ＣＳＶファイル作成処理
        CASE g_rJSTP.CHOHYOID
--  2024/10/31 ZCZL.WANGYUNING Update 0.3.000.003:IT_GKB_00434対応
          --WHEN 'GKB672R001' THEN
          WHEN 'GKB676R001' THEN
            BEGIN
              DELETE GKBWL676R001 
               WHERE WSNUM    = g_sWSNUM 
                 AND BATCHKBN = 2;
            EXCEPTION
              WHEN OTHERS THEN
                bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '区域外就学満了通知書ワークのデータを削除した際に異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            END;
            bRTN := FUNC_CSV_CREATE(g_rJSTP.CHOHYOID);
            IF NOT bRTN THEN
              RETURN FALSE;
            END IF;
            bRTN := FUNC_B11CSV('GKBWL676R001');
            IF NOT bRTN THEN
              RETURN FALSE;
            END IF;
          WHEN 'GKB130R002' THEN
            BEGIN
              DELETE GKBWL130R082 
               WHERE WSNUM    = g_sWSNUM 
                 AND BATCHKBN = 2;
            EXCEPTION
              WHEN OTHERS THEN
                bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '区域外就学満了通知書ワークのデータを削除した際に異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            END;
            bRTN := FUNC_CSV_CREATE(g_rJSTP.CHOHYOID);
            IF NOT bRTN THEN
              RETURN FALSE;
            END IF;
            bRTN := FUNC_B11CSV('GKBWL130R082');
            IF NOT bRTN THEN
              RETURN FALSE;
            END IF;
           WHEN 'GKB070R001' THEN
            BEGIN
              DELETE GKBWL070R001 
               WHERE WSNUM    = g_sWSNUM 
                 AND BATCHKBN = 2;
            EXCEPTION
              WHEN OTHERS THEN
                bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '区域外就学満了通知書ワークのデータを削除した際に異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            END;
            bRTN := FUNC_CSV_CREATE(g_rJSTP.CHOHYOID);
            IF NOT bRTN THEN
              RETURN FALSE;
            END IF;
            bRTN := FUNC_B11CSV('GKBWL070R001');
            IF NOT bRTN THEN
              RETURN FALSE;
            END IF;
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
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
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
    --  作成者／作成日: ZCZL.lvyan 2024/07/04
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
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
        WHEN OTHERS THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;

    END PBATCH;
END GKBPB00520;
/