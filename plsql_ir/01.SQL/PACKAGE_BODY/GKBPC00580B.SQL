CREATE OR REPLACE PACKAGE BODY GKBPC00580
--1.0.004.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 学齢簿一括削除処理
--  機能概要      : 学齢簿から指定した期間を経過したデータを一括処理で削除できること。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.sunyue 2024/07/01
--------------------------------------------------------
--  変更履歴
--  2024/08/02 ZCZL.yangshuai Update 0.3.000.001:検収指摘No.352、358の対応
--  2024/08/12 ZCZL.yangshuai Update 0.3.000.002:検収指摘No.358_2回目の対応
--  2024/09/02 ZCZL.WANGMING UPDATE 0.3.000.003:8月1日認識合わせの横展開
--  2024/11/13 YAMANI.SASAKI UPDATE 0.3.000.004:仕様変更　ID：IT_GKB_00554対応
--  2024/11/14 YAMANI.SASAKI UPDATE 0.3.000.005:不具合対応　ID：IT_GKB_00575対応
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応
--  2025/05/19 CTC.LIUJUNHAO UPDATE 1.0.004.000:GKB_QA14331_異常終了対応
--------------------------------------------------------
IS
    -- 全処理必須パラメータ
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

    g_nGAKUNENRIREKI_SAKUJYOCNT   NUMBER;                      -- 学年履歴_削除件数
    g_nSHUGAKURIREKI_SAKUJYOCNT   NUMBER;                      -- 就学履歴_削除件数
    g_nGAKUREIBO_SAKUJYOCNT       NUMBER;                      -- 学齢簿_削除件数
    g_vHOZON                      NUMBER;                      -- 保存期間
    g_nNENDO                      NUMBER;                      -- 年度
--2024/11/14 YAMANI.SASAKI UPDATE START 0.3.000.005:不具合対応　ID：IT_GKB_00575対応
	g_nSHORIBI                    NUMBER;                      -- 処理日
--2024/11/14 YAMANI.SASAKI UPDATE END

    g_nTIME NUMBER;  --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --------------------------------------------------------------------
    --  変数宣言
    --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 START
     NSYSTIME           NUMBER;
     ERR                EXCEPTION;
    --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 END
    --------------------------------------------------------------------
    -- 集計用変数
    BRTN                        BOOLEAN;            -- ステータス
    ISYSDATE                    PLS_INTEGER := 0;   -- システム日付

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
    --  作成者／作成日: ZCZL.sunyue 2024/07/01
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
        bRTN := KKBPK5551.FSETBLOG (g_nJOBNUM,sSTEP_NAME,i_nJOHOKBN,i_sSQLCODE,i_sSQLERRM,sLOGMSG,i_TANTOCODE,i_WSNUM);
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
    --  作成者／作成日: ZCZL.sunyue 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_B00INIT RETURN BOOLEAN
    IS
        bRTN          BOOLEAN;           --戻り値
        rJCTL         KKBTJCTL%ROWTYPE;  --バッチジョブ情報
        o_tITEM       A_CONS_PRM;
        nRTN          NUMBER;
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
--  2025/05/19 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA14331_異常終了対応
        NSYSTIME := g_nTIME;
        --nRTN := KKAPK0030.FCTGetR('GKB', 'DATAHOZONKIKAN', '0000', 1, o_tITEM);
        nRTN := KKAPK0030.FCTGetR('GKB', 'DATAHOZONKIKAN', '0000', 0, o_tITEM);
--  2025/05/19 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA14331_異常終了対応 
        IF nRTN = 0 THEN
          g_vHOZON := o_tITEM(1); -- 保存期間
        END IF;

--2024/11/14 YAMANI.SASAKI UPDATE START 0.3.000.005:不具合対応　ID：IT_GKB_00575対応
	    g_nSHORIBI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
--2024/11/14 YAMANI.SASAKI UPDATE END

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
    --  作成者／作成日: ZCZL.sunyue 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT RETURN BOOLEAN
    IS
    BEGIN

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
    --  バージョン    : Ver 0.3.000.00
    --  作成者／作成日: ZCZL.sunyue 2024/07/01
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
    --  作成者／作成日: ZCZL.sunyue 2024/07/01
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
--  2024/08/12 ZCZL.yangshuai DELETE 0.3.000.002:検収指摘No.358_2回目の対応
--         o_vRESULT := o_vRESULT || 'GKB,15540,' || g_vHOZON || ',;';
        IF NOT bRTN THEN
            o_vRESULT := g_sMESSAGE;
            RETURN;
        END IF;

        -- バッチ入力値取得
        bRTN := FUNC_B01PINIT;

--  2024/08/12 ZCZL.yangshuai Add start 0.3.000.002:検収指摘No.358_2回目の対応
        --メッセージ
        g_sMESSAGE := g_sGYOUMUCODE || ',99998,データ削除しますか。（保存期間' || g_vHOZON || '年）,;';
        o_vRESULT := g_sMESSAGE;
--  2024/08/02 ZCZL.yangshuai Add end
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
    
    --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 START
    --------------------------------------------------------
	--  機能概要      : 排他制御
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: JPJYS   2024/12/03
    --------------------------------------------------------
    FUNCTION FUNC_INIT RETURN BOOLEAN
    IS
    nSYSDATE            NUMBER;
    nRTN                PLS_INTEGER  :=  0 ;           -- 戻り値
    BEGIN
      nSYSDATE := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
      -- 排他制御セット
      nRTN := GKBFKHTSET(2,'999999999999','全件',nSYSDATE,g_sTANTOCODE,g_sWSNUM,NSYSTIME);
      IF nRTN <> 0 THEN
        RAISE ERR;
      END IF;
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INIT', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE;
        RETURN FALSE;
    END FUNC_INIT;
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 END
    --------------------------------------------------------
    --  機能概要      : バッチジョブステップテーブルの更新処理
    --  パラメータ    : i_UPD_KBN       更新区分
    --                : i_STEPRTNCODE   実行結果コード
    --                : i_CSV_RCNT      CSV出力件数
    --                : i_CSVFILENAME   CSVファイル名
    --                : i_PRTFILENAME   出力ファイル名
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.sunyue 2024/07/01
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
        --その他
        ELSE
            NULL;
        END IF;
    END PROC_JSTPSTAUTSUPD;
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 START
--------------------------------------------------------
    --  機能概要      : ログ内容編集(最大256文字）
    --  パラメータ    : ログ内容
    --  モジュール区分: 内部関数
    --  戻り値        : ログ内容
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZHANGYUNSONG  2024/12/3
    --------------------------------------------------------
    FUNCTION FUNC_GET_LOG(i_VLOG IN NVARCHAR2) RETURN NVARCHAR2
    IS
    BEGIN
        --出力するログ情報(最大256文字）
        RETURN SUBSTR( i_VLOG, 0, 256);
    END;

    --------------------------------------------------------
    --  機能概要      : 排他制御クリア
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZHANGYUNSONG   2024/12/3
    --------------------------------------------------------
    PROCEDURE FUNC_GKBFKHTCLR IS
          VLOG             NVARCHAR2(256);
          bRTN             BOOLEAN;          --戻り値
    BEGIN
        IF GKBFKHTCLR(2 ,'999999999999') <> 0 THEN
            -- 処理ログの出力を行う。
            VLOG := FUNC_GET_LOG('排他解除が異常終了しました。');
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GKBFKHTCLR', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
        END IF;
    END FUNC_GKBFKHTCLR;
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 END

    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.sunyue 2024/07/01
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN                         --件数

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
    --  機能概要      : 更新処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.sunyue 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;  --戻り値
    BEGIN
        g_nUPDLOGSEQ := g_nUPDLOGSEQ + 1;
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 2);
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 START
         bRTN := FUNC_INIT;
        IF NOT bRTN THEN
          RAISE ERR;
        END IF;
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 END

        -- 学年履歴データの削除
        DELETE 
        FROM
            GKBTGAKUNENRIREKI A
        WHERE
            EXISTS ( 
                SELECT
                    * 
                FROM
                    GKBTGAKUREIBO B                                                
                WHERE
                    B.KOJIN_NO = A.KOJIN_NO 
--  2024/11/13 YAMANI.SASAKI UPDATE START 0.3.000.004:仕様変更　ID：IT_GKB_00554対応
--                    AND B.RIREKI_RENBAN = A.KOJIN_RIREKI_RENBAN
                    AND B.GEN_NENGAPI <> 0
--  2024/11/13 YAMANI.SASAKI UPDATE END
--2024/11/14 YAMANI.SASAKI UPDATE START 0.3.000.005:不具合対応　ID：IT_GKB_00575対応
--                    AND B.GEN_NENGAPI <= ( SHORIBI - g_vHOZON * 10000 ) 
					AND B.GEN_NENGAPI <= ( g_nSHORIBI - g_vHOZON * 10000 ) 
--2024/11/14 YAMANI.SASAKI UPDATE END
                    AND B.SAISHIN_KBN = 0
            );
        g_nGAKUNENRIREKI_SAKUJYOCNT := SQL%ROWCOUNT; -- 学年履歴_削除件数
        -- 就学履歴データの削除
        DELETE 
        FROM
            GKBTSHUGAKURIREKI A
        WHERE
            EXISTS ( 
                SELECT
                    * 
                FROM
                    GKBTGAKUREIBO B                                                
                WHERE
                    B.KOJIN_NO = A.KOJIN_NO 
--  2024/11/13 YAMANI.SASAKI UPDATE START 0.3.000.004:仕様変更　ID：IT_GKB_00554対応
--                    AND B.RIREKI_RENBAN = A.KOJIN_RIREKI_RENBAN
					AND B.GEN_NENGAPI <> 0
--  2024/11/13 YAMANI.SASAKI UPDATE END
--2024/11/14 YAMANI.SASAKI UPDATE START 0.3.000.005:不具合対応　ID：IT_GKB_00575対応
--                    AND B.GEN_NENGAPI <= ( SHORIBI - g_vHOZON * 10000 ) 
					AND B.GEN_NENGAPI <= ( g_nSHORIBI - g_vHOZON * 10000 ) 
--2024/11/14 YAMANI.SASAKI UPDATE END
                    AND B.SAISHIN_KBN = 0
            );
        g_nSHUGAKURIREKI_SAKUJYOCNT := SQL%ROWCOUNT; -- 就学履歴_削除件数
        -- 学齢簿データの削除
        DELETE 
        FROM
            GKBTGAKUREIBO A 
        WHERE
            EXISTS ( 
                SELECT
                    * 
                FROM
                    GKBTGAKUREIBO B 
                WHERE
                    A.KOJIN_NO = B.KOJIN_NO 
--  2024/11/13 YAMANI.SASAKI UPDATE START 0.3.000.004:仕様変更　ID：IT_GKB_00554対応
--                    AND A.RIREKI_RENBAN = B.RIREKI_RENBAN 
--                    AND A.RIREKI_RENBAN_EDA = B.RIREKI_RENBAN_EDA 
                    AND B.GEN_NENGAPI <> 0
--  2024/11/13 YAMANI.SASAKI UPDATE END
--2024/11/14 YAMANI.SASAKI UPDATE START 0.3.000.005:不具合対応　ID：IT_GKB_00575対応
--                    AND B.GEN_NENGAPI <= ( SHORIBI - g_vHOZON * 10000 ) 
					AND B.GEN_NENGAPI <= ( g_nSHORIBI - g_vHOZON * 10000 ) 
--2024/11/14 YAMANI.SASAKI UPDATE END
                    AND B.SAISHIN_KBN = 0
            );
        g_nGAKUREIBO_SAKUJYOCNT := SQL%ROWCOUNT; -- 学齢簿_削除件数 
        g_oKENSU_LIST.EXTEND(3);
        g_oKENSU_LIST(1) := GKBEKENSU_RECORD(g_nGAKUNENRIREKI_SAKUJYOCNT,'学年履歴',0);
        g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nSHUGAKURIREKI_SAKUJYOCNT,'就学履歴',0);
        g_oKENSU_LIST(3) := GKBEKENSU_RECORD(g_nGAKUREIBO_SAKUJYOCNT,'学齢簿',0);
--  2024/09/02 ZCZL.WANGMING ADD 0.3.000.003:8月1日認識合わせの横展開
        COMMIT;
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 2);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新表処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
    END FUNC_B20UPDATE1;
--  2024/08/02 ZCZL.yangshuai Add start 0.3.000.001:検収指摘No.352の対応
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.yangshuai 2024/08/02
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
--  2024/08/02 ZCZL.yangshuai Add end
    --------------------------------------------------------
    --  機能概要      : バッチ処理の呼出
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_nRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.sunyue 2024/07/01
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
--  2024/08/02 ZCZL.yangshuai Add start 0.3.000.001:検収指摘No.352、358の対応
                WHEN 0 THEN
                    --作表処理
                    bRTN := FUNC_B10SAKUHYO1;
                    IF NOT bRTN THEN
                        o_nRESULT := c_ERR;
                    END IF;
--  2024/08/02 ZCZL.yangshuai Add end
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
			--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 START
			FUNC_GKBFKHTCLR;
			--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 END
        WHEN eSHORIEXCEPTION THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
			--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 START
			FUNC_GKBFKHTCLR;
			--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 END
        WHEN OTHERS THEN
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
			--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 START
			FUNC_GKBFKHTCLR;
			--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00715の対応 END
    END PBATCH;
END GKBPC00580;
/
