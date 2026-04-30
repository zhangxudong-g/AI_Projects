CREATE OR REPLACE PACKAGE BODY GKBPB00500
--1.0.006.000-02.02-02.02
-------------------------------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名 : 学校入学者名簿
--  機能概要  : 処理条件にして「小学校入学者名簿」と「中学校入学者名簿」を出力する一括処理機能を作成する。
--            入力した処理条件により、対応する区域外就学者一覧ワークテーブルにデータを作成する。
--  バージョン     : Ver 0.3.000.000
--  作成者／作成日: ZCZL.xiaoya 2024/06/17
-------------------------------------------------------------------------------
--  変更履歴
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00075対応
--  2024/09/06 ZCZL.WANGMING UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00101、IT_GKB_00133対応
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00286横展開対応
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.005:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.000.006:仕様変更IT_GKB_00658の対応
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:仕様変更IT_GKB_00708の対応
--  2025/02/04 JPJYS.WUZHENGDONG Update 0.3.000.009:ST_GKB_TMP00033 対応
--  2025/05/22 CTC.LIUJUNHAO UPDATE 1.0.006.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
-------------------------------------------------------------------------------
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
    g_sSHORISH                    NVARCHAR2(2);                --処理種別
    g_sGYOUMUCODE                 NVARCHAR2(3);                --業務コード
    g_nTIME                       NUMBER;                      --システム時間
    g_oKENSU_LIST                 GKBEKENSU_LIST := GKBEKENSU_LIST();

    g_sTITLE                      NVARCHAR2(1000);             --帳票タイトル
    g_sBIKO_LABEL                 NVARCHAR2(1000);             --出身小学校/備考ラベル
    g_sNYUGAKUSYAMEIBO_INDEXNO    NVARCHAR2(1000);             --学校入学者名簿_インデックス番号
    g_sNYUGAKUSYAMEIBO_SYUTURYOKU NVARCHAR2(1000);             --学校入学者名簿_出力制御
    g_nINDEX                      NUMBER := 0;
    g_nCNT                        NUMBER := 0;                 --グローバル変数.件数
    g_nCSVCNT                     NUMBER := 0;                 --グローバル変数.CSV出力件数
    --画面入力条件
    g_vJYOUKEN01                  NVARCHAR2(1000);
    g_sNYUGAKUND                  NVARCHAR2(1000);             --入学年度
    g_sGAKOKB                     NVARCHAR2(1000);             --学校区分
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.005:学校コードリスト仕様変更IT_GKB_00090の対応
    --g_sSYOUGAKOCD                 NVARCHAR2(1000);             --小学校コード
    --g_sSYOUGAKOCD_ED              NVARCHAR2(1000);             --小学校コード（編集後）
    --g_sCYUGAKOCD                  NVARCHAR2(1000);             --中成学校コード
    --g_sCYUGAKOCD_ED               NVARCHAR2(1000);             --中成学校コード（編集後）
    g_sSYOUGAKOCD                 NVARCHAR2(3000);             --小学校コード
    g_sSYOUGAKOCD_ED              NVARCHAR2(3000);             --小学校コード（編集後）
    g_sCYUGAKOCD                  NVARCHAR2(3000);             --中成学校コード
    g_sCYUGAKOCD_ED               NVARCHAR2(3000);             --中成学校コード（編集後）
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
    g_nNYUGAKUND                  NUMBER := 0;                 --入学年度
    g_nGAKOKB                     NUMBER := 0;                 --学校区分
    g_nSYOUGAKOCD                 NUMBER := 0;                 --小学校コード
    g_nCYUGAKOCD                  NUMBER := 0;                 --中成学校コード

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;
    --パラメータ変数
    VMSG       NVARCHAR2(4000); --エラーメッセージ
	--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応 START
	IRTN PLS_INTEGER;
	--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応 END
    NRTN       NUMBER;
    EERROR      EXCEPTION;
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
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
        --作表処理の場合
        IF i_nSHORIKBN = 1 THEN
            sSTEP_NAME := i_sSTEP_NAME || g_nSAKUHYOLOGSEQ;
            sLOGMSG := i_sLOGMSG;
        --更新処理の場合
        ELSIF i_nSHORIKBN = 2 THEN
            sSTEP_NAME := i_sSTEP_NAME || g_nUPDLOGSEQ;
            sLOGMSG := i_sLOGMSG;
        --カスタマイズログ内容の場合
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
    FUNCTION FUNC_B00INIT RETURN BOOLEAN
    IS
        bRTN          BOOLEAN;           --戻り値
        rJCTL         KKBTJCTL%ROWTYPE;  --バッチジョブ情報
    BEGIN
        --初期処理
        bRTN := KKBPK5551.INITIAL (g_nJOBNUM);
        --バッチパラメータ取得
        bRTN := KKBPK5551.FJCTLGet (g_nJOBNUM, rJCTL);
        g_sTANTOCODE  := rJCTL.LOGIN_TANTOCODE;               --担当者コード
        g_sWSNUM      := rJCTL.LOGIN_WSNUM;                   --端末番号
        g_sSHORIID    := rJCTL.SHORIID;                       --処理ID
        g_sSHORISH    := rJCTL.SHORISH;                       --処理種別
        g_sGYOUMUCODE := rJCTL.GYOUMUCODE;                    --業務コード
        g_nTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));    --システム時間
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B00INIT;
    
    --------------------------------------------------------
    --  機能概要      : 学校コード取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
    FUNCTION FUNC_GET_GAKOCD(i_sGAKOCD IN NVARCHAR2, o_sGAKOCD OUT NVARCHAR2) RETURN BOOLEAN
    IS
        aGAKOCD           KKBPK5551.tySPLIT_tbl;      -- 学校コード（リスト）
--  2024/11/14 ZCZL.WANGYUNING ADD 0.3.000.005:学校コードリスト仕様変更IT_GKB_00090の対応        
        nGAKOUCD_TMP  NUMBER; --学校コード
    BEGIN
        -- 入力引数を分解して配列にセットする
        -- 引数の学校コード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.005:学校コードリスト仕様変更IT_GKB_00090の対応        
        -- 処理ステップを取得
        --FOR i IN 1..aGAKOCD.COUNT LOOP
        --    IF MOD(i - 1, 2) = 0 AND aGAKOCD.COUNT > 2 THEN
        --        IF i = aGAKOCD.COUNT - 1 THEN
        --            o_sGAKOCD := o_sGAKOCD || aGAKOCD(i);
        --        ELSE
        --            o_sGAKOCD := o_sGAKOCD || aGAKOCD(i) || ',';
        --        END IF;
        --    ELSIF aGAKOCD.COUNT = 2 THEN
        --        o_sGAKOCD := aGAKOCD(1);
        --        EXIT;
        --    ELSE
        --        NULL;
        --    END IF;
        --END LOOP;
        o_sGAKOCD := '';
        FOR i IN 1..aGAKOCD.COUNT LOOP
          --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.000.006:仕様変更IT_GKB_00658の対応 START
    --        nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 1, 3));
          --  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.000.006:仕様変更IT_GKB_00658の対応 END
            IF nGAKOUCD_TMP IS NOT NULL THEN
                IF i = aGAKOCD.COUNT THEN
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP ;
                ELSE
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP || ',';
                END IF;
            END IF;
        END LOOP;
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_GET_GAKOCD;

    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT RETURN BOOLEAN
    IS
-- 2024/09/03 ZCZL.WANGMING Add 0.3.000.001:IT_GKB_00075対応
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00101、IT_GKB_00133対応
--      cmbtxtNyugakuNd       DBMS_UTILITY.MAXNAME_ARRAY;
      txtcmbGakoKb       DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.005:学校コードリスト仕様変更IT_GKB_00090の対応
      objShogakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
      objChugakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/14 ZCZL.WANGYUNING ADD END
    BEGIN
-- 2024/09/03 ZCZL.WANGMING UPDATE START 0.3.000.001:IT_GKB_00075対応
--        g_sNYUGAKUND  := KKBPK5551.GETPARMS(g_nJOBNUM,'txtNyugakuNd');     --入学年度
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00101、IT_GKB_00133対応
--        cmbtxtNyugakuNd := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtNyugakuNd');    --入学年度
--        g_sNYUGAKUND := cmbtxtNyugakuNd(1);
        g_sNYUGAKUND := KKBPK5551.GETPARMS(g_nJOBNUM,'txtNyugakuNd');     --入学年度
-- 2024/09/03 ZCZL.WANGMING UPDATE END
--        g_sGAKOKB     := KKBPK5551.GETPARMS(g_nJOBNUM,'txtGakoKb');        --学校区分
        txtcmbGakoKb := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGakoKb');    --学校区分
        g_sGAKOKB := txtcmbGakoKb(1);
--  2024/10/11 ZCZL.WANGMING UPDATE END
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.005:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_sSYOUGAKOCD := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSyougakoCd');    --小学校コード
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtSyougakoCd');
        g_sSYOUGAKOCD := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtSyougakoCd',0, objShogakkoCd);
        --g_sCYUGAKOCD  := KKBPK5551.GETPARMS(g_nJOBNUM,'txtCyugakoCd');     --中学校コード
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtCyugakoCd');
        g_sCYUGAKOCD := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtCyugakoCd',0, objChugakkoCd);
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
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
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応 START
    --------------------------------------------------------
    --  機能概要      : 入学年度のチェック
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
--      FUNCTION FUNC_NYUGAKUNENDO_CHK RETURN NUMBER
--      IS
--        NKIJUN_BI       NUMBER;           --基準日
--        NYUGAKUNENDO    NUMBER;           --変数.入学年度
--        NJINENDO        NUMBER;           --次年度のチェック変数.次年度
--      BEGIN
--        -- 桁数のチェック
--       -- IF LENGTH(g_sNYUGAKUND) <> 3 THEN
--       --   -- エラーメッセージの追加
--       --   VMSG := VMSG || g_sGYOUMUCODE || ',99999,入学年度の桁数が正しくありません。,;';
--       -- END IF;
--
--        -- 年度変換のチェック0
--        -- 共通パッケージ.年度変換を呼び出す。
--       NYUGAKUNENDO :=KKAPK0020.FNENDO(TO_NUMBER(g_sNYUGAKUND) ,1);
--        -- 変数.入学年度=0の場合
--        IF NYUGAKUNENDO = 0 THEN
--          -- エラーメッセージの追加
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,入学年度の形式が正しくありません。,;';
--        END IF;
--
--        -- 次年度のチェック
--        -- 基準日の取得
--        NKIJUN_BI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
--        -- 共通パッケージ.年度取得を呼び出す。
--        NJINENDO := KKAPK0020.FDAYNENDO(NKIJUN_BI ,0);
--        NJINENDO := NJINENDO + 1;
--        -- 変数.次年度<>変数.入学年度
--        IF NJINENDO <> NYUGAKUNENDO THEN
--          -- エラーメッセージの追加
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,入学年度が次年度ではありません。,;';
--        END IF;
--        RETURN 0;
--      END FUNC_NYUGAKUNENDO_CHK;
    --------------------------------------------------------
    --  機能概要      : 学校区分のチェック
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
--    FUNCTION FUNC_GAKKOUKUBUN_CHK RETURN NUMBER
--    IS
--      NRTN NUMBER;
--    BEGIN
--        -- 学校区分のチェック
--        IF g_sGAKOKB IS NULL OR g_sGAKOKB = '' THEN
--            -- エラーメッセージの追加
--            VMSG := VMSG || g_sGYOUMUCODE || ',99999,学校区分が正しくありません。,;';
--        END IF;
--        RETURN 0;
--    END FUNC_GAKKOUKUBUN_CHK;
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応 END
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応 START
----------------------------------------------------------------------------------------------------
    --年度チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCNENDOCHK( i_VNENDO IN NVARCHAR2 ) RETURN NUMBER IS
      IRET PLS_INTEGER;
      INENDO NUMBER;
    BEGIN
      IRET := 0;
      --対象年度
      BEGIN
        IF LENGTH(i_VNENDO) <> 3 THEN
          IRET := 1;
        ELSE
          INENDO := KKAPK0020.FNENDO(i_VNENDO,1);
          IF INENDO = 0 THEN
            IRET := 1;
          END IF;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      RETURN(IRET);
    END FUNCNENDOCHK;
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応 END
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN       BOOLEAN;          --戻り値
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応 START
        NKIJUN_BI       NUMBER;           --基準日
        NYUGAKUNENDO    NUMBER;           --変数.入学年度
        NJINENDO        NUMBER;           --次年度のチェック変数.次年度
        aGAKKOCD_CHK_LST         KKBPK5551.tySPLIT_tbl;   --変数.学校リスト
        vGAKOUKBN       NUMBER;         --学校から学校区別の取得
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応 END
        nRTN       NUMBER;
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
       --各変数の初期化
       VMSG := '';
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応 START
       --入学年度のチェック
--       nRTN := FUNC_NYUGAKUNENDO_CHK;
--       --学校区分のチェック
--       nRTN := FUNC_GAKKOUKUBUN_CHK;

        IRTN := 0;
        --条件１のチェック
        IRTN := FUNCNENDOCHK( g_sNYUGAKUND );
        IF IRTN <> 0 THEN
            VMSG := g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
        END IF;
        IF IRTN = 0 THEN
          -- 次年度のチェック
          NYUGAKUNENDO :=KKAPK0020.FNENDO(TO_NUMBER(g_sNYUGAKUND) ,1); --入学年度
          -- 基準日の取得
          NKIJUN_BI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
          -- 共通パッケージ.年度取得を呼び出す。
          NJINENDO := KKAPK0020.FDAYNENDO(NKIJUN_BI ,0);
          NJINENDO := NJINENDO + 1;
          -- 変数.次年度<>変数.入学年度
          IF NJINENDO <> NYUGAKUNENDO THEN
          -- エラーメッセージの追加
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,入学年度が次年度ではありません。,;';
          END IF;
        END IF;
		--学校区分と小学校コードの関連チェック
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_sSYOUGAKOCD, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            --学校区分と選択された学校の関係性チェック
            IF g_sGAKOKB <> '1' THEN
              IF TO_NUMBER(g_sGAKOKB) <> vGAKOUKBN THEN
                IF VMSG IS NOT NULL THEN
                  VMSG := VMSG || ';' || g_sGYOUMUCODE || ',99999,選択された中学校の学校区分に該当しない学校コードが選択されています。,;';
                ELSE
                  VMSG := VMSG || g_sGYOUMUCODE || ',99999,選択された中学校の学校区分に該当しない学校コードが選択されています。,;';
                END IF;
              END IF;
            END IF;
        END LOOP;
        --学校区分と中学校コードの関連チェック
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_sCYUGAKOCD, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            --学校区分と選択された学校の関係性チェック
            IF g_sGAKOKB <> '2' THEN
              IF TO_NUMBER(g_sGAKOKB) <> vGAKOUKBN THEN
                IF VMSG IS NOT NULL THEN
                  VMSG := VMSG || ';' || g_sGYOUMUCODE || ',99999,選択された小学校の学校区分に該当しない学校コードが選択されています。,;';
                ELSE
                  VMSG := VMSG || g_sGYOUMUCODE || ',99999,選択された小学校の学校区分に該当しない学校コードが選択されています。,;';
                END IF;
              END IF;
            END IF;
        END LOOP;
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.007:仕様変更IT_GKB_00697、IT_GKB_00698の対応 END
       o_vRESULT := VMSG;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
    --------------------------------------------------------
    --  機能概要    : バッチジョブステップテーブルの更新処理
    --  パラメータ    : i_UPD_KBN       更新区分
    --            : i_STEPRTNCODE   実行結果コード
    --            : i_CSV_RCNT      CSV出力件数
    --            : i_CSVFILENAME   CSVファイル名
    --            : i_PRTFILENAME   出力ファイル名
    --  モジュール区分 : 内部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
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
    --  機能概要      : 条件取得処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
    BEGIN
        g_nNYUGAKUND := TO_NUMBER(g_sNYUGAKUND);       --入学年度
        g_nGAKOKB    := TO_NUMBER(g_sGAKOKB);          --学校区分
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
    FUNCTION FUNC_INIT RETURN BOOLEAN
    IS
        nRTN                        NUMBER;               --戻り値
        bRTN                        BOOLEAN;              --戻り値
        o_vSQLERRM                  NVARCHAR2(1000);      --エラーメッセージ
        aITEM                       A_CONS_PRM;           --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
    BEGIN
        --学校入学者名簿ワークファイルをクリアする
--  2024/09/06 ZCZL.WANGMING DELETE 0.3.000.002:8月1日認識合わせの横展開
--        nRTN := KKAPK3000.FTRUNCATE('GKBWL650R001', o_vSQLERRM);
        g_sNYUGAKUND := KKAPK0020.FNENDOEDIT(0, g_sNYUGAKUND, 3) || '年度';    --入学年度
        IF g_sGAKOKB = '1' THEN
            g_sTITLE := '小学校入学者名簿';                                      --帳票タイトル
            g_sBIKO_LABEL := '備考';                                           --出身小学校/備考ラベル
        ELSIF g_sGAKOKB = '2' THEN
            g_sTITLE := '中学校入学者名簿';                                      --帳票タイトル
            g_sBIKO_LABEL := '出身小学校';                                      --出身小学校/備考ラベル
        ELSE
            NULL;
        END IF;
        --小学校コード(編集後)
        bRTN := FUNC_GET_GAKOCD(g_sSYOUGAKOCD, g_sSYOUGAKOCD_ED);
        IF NOT bRTN THEN
          RETURN FALSE;
        END IF;
        --中学校コード(編集後)
        bRTN := FUNC_GET_GAKOCD(g_sCYUGAKOCD, g_sCYUGAKOCD_ED);
        IF NOT bRTN THEN
          RETURN FALSE;
        END IF;
        -- システム制御設定を取得
        -- 外国人　氏名・生年月日制御帳票(ID)のリストを取得
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aITEM);
        --「GKB650R001」が格納されている箇所のインデックス番号
        IF nRTN = 0 THEN
            FOR i IN 1..aITEM.COUNT LOOP
                IF aITEM(i) = 'GKB650R001' THEN
                    g_sNYUGAKUSYAMEIBO_INDEXNO := i;    --学校入学者名簿_インデックス番号
                    EXIT;
                END IF;
            END LOOP;
        END IF;
        -- 「本名・通称名　出力制御」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aITEM);
        IF nRTN = 0 AND g_sNYUGAKUSYAMEIBO_INDEXNO <= aITEM.COUNT THEN
            g_sNYUGAKUSYAMEIBO_SYUTURYOKU := aITEM(g_sNYUGAKUSYAMEIBO_INDEXNO);    --学校入学者名簿_出力制御
        END IF;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_INIT;
    --------------------------------------------------------
    --  機能概要 : 学齢簿から値を取得して、学校入学者名簿中間ワークテーブルを作成する
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC RETURN NUMBER IS
        bRTN                      BOOLEAN;                             --戻る値
        nRTN                      PLS_INTEGER;                         --戻る値
        sNYUGAKUND                NVARCHAR2(1000);                     --編集後入学年度
        sSQL                      VARCHAR2(5000);
        TYPE MC_CURSOR IS REF     CURSOR;                              --カーソルタイプ定義
        cCURSOR                   MC_CURSOR;
        rMEIBO                    GKBTGAKUREIBO%ROWTYPE;               --学齢簿情報
        rWLTBL                    GKBWNYUKAKUSYAMEIBO%ROWTYPE;         --学校入学者名簿中間ワーク
        o_rHKSKIHON               GABTATENAKIHON%ROWTYPE;              --保護者の宛名基本
        o_rHKSSOFUSAKI            GABTSOFUSAKI%ROWTYPE;                --保護者の送付先基本
        o_rJDSTKIHON              GABTATENAKIHON%ROWTYPE;              --児童生徒の宛名基本
        o_rJDSTSOFUSAKI           GABTSOFUSAKI%ROWTYPE;                --児童生徒の送付先基本
        o_sMEISHOKANA             KKATCD.MEISHOKANA%TYPE;              --名称カナ
        o_sYOBI                   KKATCD.YOBI%TYPE;                    --予備
        o_sKOKUMEI_KANA           NVARCHAR2(120);                      --国籍マスタ.国名カナ
        o_sKOKUMEI                NVARCHAR2(60);                       --国籍マスタ.国名漢字
        o_sKOKUMEI_ALPHABET       NVARCHAR2(120);                      --国籍マスタ.国名アルファベット
        sYUBIN_NO                 NVARCHAR2(20);                       --編集後郵便番号
        o_sSHIMEIKANA             NVARCHAR2(1000);                     --氏名カナ
        o_sSHIMEIKANJI            NVARCHAR2(1000);                     --氏名漢字
        o_sBIRTHDAY               NVARCHAR2(1000);                     --生年月日
    BEGIN
        --初期化
        DELETE FROM GKBWNYUKAKUSYAMEIBO;
        --学齢簿データ抽出
        sSQL := '';
        sSQL := sSQL || 'SELECT                          ';
        sSQL := sSQL || '      HOGOSYA_KOJIN_NO          ';            --保護者宛名番号
        sSQL := sSQL || '    , KOJIN_NO                  ';            --宛名番号
        sSQL := sSQL || '    , SYOGAKO_CD                ';            --小学校コード
        sSQL := sSQL || '    , TYUGAKO_CD                ';            --中学校コード
        sSQL := sSQL || '    , ZOKUGARA1                 ';            --続柄１
        sSQL := sSQL || '    , ZOKUGARA2                 ';            --続柄２
        sSQL := sSQL || '    , ZOKUGARA3                 ';            --続柄３
        sSQL := sSQL || '    , ZOKUGARA4                 ';            --続柄４
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
        sSQL := sSQL || '    , HOGOSYA_ZOKUGARA1                 ';            --保護者続柄１
        sSQL := sSQL || '    , HOGOSYA_ZOKUGARA2                 ';            --保護者続柄２
        sSQL := sSQL || '    , HOGOSYA_ZOKUGARA3                 ';            --保護者続柄３
        sSQL := sSQL || '    , HOGOSYA_ZOKUGARA4                 ';            --保護者続柄４
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
        sSQL := sSQL || '    , GAKUNEN                   ';            --学年
        sSQL := sSQL || '    , KUIKIGAISHUGAKU_FLG       ';            --区域外就学フラグ
        sSQL := sSQL || '    , GAKKO_KBN_CD              ';            --学校区分コード
        sSQL := sSQL || '    , KUIKIGAISHUGAKU_KYOKA_BI  ';            --区域外就学_許可年月日
        sSQL := sSQL || '    , GAKUKYU_CD                ';            --学級コード
        sSQL := sSQL || 'FROM                            ';
        sSQL := sSQL || '    GKBTGAKUREIBO               ';
        sSQL := sSQL || 'WHERE                           ';
        --学校区分＝1：小学校の場合
        IF g_nGAKOKB = 1 THEN
            sNYUGAKUND := TO_NUMBER(TO_CHAR(KKAPK0020.FNENDO(g_nNYUGAKUND, 1)) || '0401');
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
            --sSQL := sSQL || '  GAKUNEN = ''1''                          ';--学年
            sSQL := sSQL || '  GAKUNEN = ''0''                          ';--学年
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
            sSQL := sSQL || '  AND SYOGAKO_NYUGAKU_BI = ' || sNYUGAKUND  ;--小学校入学年月日
            sSQL := sSQL || '  AND GAKKO_KBN_CD = ''1''                 ';--学校区分コード
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00101、IT_GKB_00133対応
            IF g_sSYOUGAKOCD_ED IS NOT NULL THEN
               sSQL := sSQL || '  AND SYOGAKO_CD IN (' ||  g_sSYOUGAKOCD_ED || ')';--小学校コード
            END IF;
--  2024/10/11 ZCZL.WANGMING UPDATE END
            sSQL := sSQL || '  AND SAISHIN_KBN = ''0''                  ';--最新
            sSQL := sSQL || '  AND SAKUJO_FLG = ''0''                   ';--削除フラグ
            sSQL := sSQL || '  AND GEN_NENGAPI = ''0''                  ';--減年月日
        --学校区分＝2：中学校の場合
        ELSIF g_nGAKOKB = 2 THEN
            sNYUGAKUND := TO_NUMBER(TO_CHAR(KKAPK0020.FNENDO(g_nNYUGAKUND, 1)) || '0401');
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
            --sSQL := sSQL || '  GAKUNEN = ''7''                          ';--学年
            sSQL := sSQL || '  GAKUNEN = ''6''                          ';--学年
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
            sSQL := sSQL || '  AND TYUGAKO_NYUGAKU_BI = ' || sNYUGAKUND  ;--中学校入学年月日
            sSQL := sSQL || '  AND GAKKO_KBN_CD = ''2''                 ';--学校区分コード
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00101、IT_GKB_00133対応
            IF g_sCYUGAKOCD_ED IS NOT NULL THEN
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:仕様変更IT_GKB_00708の対応 START
--               sSQL := sSQL || '  AND CHUGAKKOKU_CD IN (' || g_sCYUGAKOCD_ED || ')';--中学校コード
               sSQL := sSQL || '  AND TYUGAKO_CD IN (' || g_sCYUGAKOCD_ED || ')';--中学校コード
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:仕様変更IT_GKB_00708の対応 END
            END IF;
--  2024/10/11 ZCZL.WANGMING UPDATE END
            sSQL := sSQL || '  AND SAISHIN_KBN = ''0''                  ';--最新
            sSQL := sSQL || '  AND SAKUJO_FLG = ''0''                   ';--削除フラグ
            sSQL := sSQL || '  AND GEN_NENGAPI = ''0''                  ';--減年月日
        END IF;
        OPEN cCURSOR FOR sSQL;
        LOOP
            FETCH cCURSOR INTO rMEIBO.HOGOSYA_KOJIN_NO                    --保護者宛名番号
                              ,rMEIBO.KOJIN_NO                            --宛名番号
                              ,rMEIBO.SYOGAKO_CD                          --小学校コード
                              ,rMEIBO.TYUGAKO_CD                          --中学校コード
                              ,rMEIBO.ZOKUGARA1                           --続柄１
                              ,rMEIBO.ZOKUGARA2                           --続柄２
                              ,rMEIBO.ZOKUGARA3                           --続柄３
                              ,rMEIBO.ZOKUGARA4                           --続柄４
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
                              ,rMEIBO.HOGOSYA_ZOKUGARA1                           --保護者続柄１
                              ,rMEIBO.HOGOSYA_ZOKUGARA2                           --保護者続柄２
                              ,rMEIBO.HOGOSYA_ZOKUGARA3                           --保護者続柄３
                              ,rMEIBO.HOGOSYA_ZOKUGARA4                           --保護者続柄４
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
                              ,rMEIBO.GAKUNEN                             --学年
                              ,rMEIBO.KUIKIGAISHUGAKU_FLG                 --区域外就学フラグ
                              ,rMEIBO.GAKKO_KBN_CD                        --学校区分コード
                              ,rMEIBO.KUIKIGAISHUGAKU_KYOKA_BI            --区域外就学_許可年月日
                              ,rMEIBO.GAKUKYU_CD;                         --学級コード
            EXIT WHEN cCURSOR%NOTFOUND;
            --児童の宛名情報を取得する
            nRTN := GAAPK0030.FGETATENA(rMEIBO.KOJIN_NO,
                                        'GKB',
                                         TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),
                                         o_rJDSTKIHON,
                                         o_rJDSTSOFUSAKI);
            --保護者の宛名情報を取得する
            nRTN := GAAPK0030.FGETATENA(rMEIBO.HOGOSYA_KOJIN_NO,
                                        'GKB',
                                        TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),
                                        o_rHKSKIHON,
                                        o_rHKSSOFUSAKI);
            rWLTBL.JINKAKU_KBN := o_rJDSTKIHON.JINKAKU_KBN;      --人格区分
            rWLTBL.KOJIN_NO    := rMEIBO.KOJIN_NO;               --児童宛名番号
            --児童生徒の本名使用制御判定
            nRTN := GKBFKHMCTRL(rMEIBO.KOJIN_NO,                --宛名番号
                                g_rJSTP.CHOHYOID,               --帳票ID
                                0,                              --保護者区分(0:児童生徒)
                                g_sNYUGAKUSYAMEIBO_SYUTURYOKU,  --システム制御設定
                                o_sSHIMEIKANA,                  --氏名カナ
                                o_sSHIMEIKANJI,                 --氏名漢字
                                o_sBIRTHDAY);                   --生年月日
            rWLTBL.JIDO_SHIMEI_KANA     := o_sSHIMEIKANA;                 --児童氏名カナ
            rWLTBL.JIDO_SHIMEI_KANJI    := o_sSHIMEIKANJI;                --児童氏名
            rWLTBL.SEINENGAPI           := o_sBIRTHDAY;                   --生年月日
            --保護者の本名使用制御判定
            nRTN := GKBFKHMCTRL(rMEIBO.KOJIN_NO,                --宛名番号
                                g_rJSTP.CHOHYOID,               --帳票ID
                                1,                              --保護者区分(1:保護者)
                                g_sNYUGAKUSYAMEIBO_SYUTURYOKU,  --システム制御設定
                                o_sSHIMEIKANA,                  --氏名カナ
                                o_sSHIMEIKANJI,                 --氏名漢字
                                o_sBIRTHDAY);                   --生年月日
            rWLTBL.HOGOSHA_KOJIN_NO := rMEIBO.HOGOSYA_KOJIN_NO;           --保護者宛名番号
            rWLTBL.HOGOSHA_SHIMEI_KANA  := o_sSHIMEIKANA;                 --保護者氏名カナ
            rWLTBL.HOGOSHA_SHIMEI_KANJI := o_sSHIMEIKANJI;                --保護者氏名
            --性別
            nRTN := KKAPK0030.FCDgetR('GKB', '021', '0001', o_rJDSTKIHON.SEIBETSU, rWLTBL.SEIBETSU, o_sMEISHOKANA, o_sYOBI);
            --児童生徒との関係
            rWLTBL.HOGOSHA_KANKEI := GKBFKZKGMGET2(2,                     --続柄区分(2:保護者用)            
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
                                                  /* rMEIBO.ZOKUGARA1,      --続柄１
                                                   rMEIBO.ZOKUGARA2,      --続柄２
                                                   rMEIBO.ZOKUGARA3,      --続柄３
                                                   rMEIBO.ZOKUGARA4);     --続柄４ */
                                                   rMEIBO.HOGOSYA_ZOKUGARA1,      --続柄１
                                                   rMEIBO.HOGOSYA_ZOKUGARA2,      --続柄２
                                                   rMEIBO.HOGOSYA_ZOKUGARA3,      --続柄３
                                                   rMEIBO.HOGOSYA_ZOKUGARA4);     --続柄４
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13925、QA13933_児童生徒との関係および学年不正対応
            nRTN := GKAFKKKMGET(o_rJDSTKIHON.KOKUMEI_CD, --児童宛名基本.国籍コード
                                o_sKOKUMEI_KANA,         --国籍マスタ.国名カナ
                                o_sKOKUMEI,              --国籍マスタ.国名漢字
                                o_sKOKUMEI_ALPHABET);    --国籍マスタ.国名アルファベット
            --児童生徒国籍名
            rWLTBL.JIDO_KOKUSEKIMEI := o_sKOKUMEI;
            nRTN := GKAFKKKMGET(o_rHKSKIHON.KOKUMEI_CD,  --保護者宛名基本.国籍コード
                                o_sKOKUMEI_KANA,         --国籍マスタ.国名カナ
                                o_sKOKUMEI,              --国籍マスタ.国名漢字
                                o_sKOKUMEI_ALPHABET);    --国籍マスタ.国名アルファベット
            --保護者国籍名
            rWLTBL.HOGOSHA_KOKUSEKIMEI := o_sKOKUMEI;
            rWLTBL.GAKKO_KBN_CD := rMEIBO.GAKKO_KBN_CD;                   --学校区分コード
            --学校区分
            IF rMEIBO.GAKKO_KBN_CD = '1' THEN--小学校の場合
                rWLTBL.GAKKO_KBN := '小学校';
            ELSIF rMEIBO.GAKKO_KBN_CD = '2' THEN--中学校の場合
                rWLTBL.GAKKO_KBN := '中学校';
            ELSE
                NULL;
            END IF;
            --小学校の場合
            IF g_sGAKOKB = 1 THEN
                rWLTBL.GAKO_CD := rMEIBO.SYOGAKO_CD;                      --学校コード
                rWLTBL.GAKKO_MEI := GKAFKGKOGTEQ(1, rMEIBO.SYOGAKO_CD);   --学校名
                rWLTBL.SYUSSHIN_SHOGAKKO_MEI := NULL;                     --出身小学校名
            --中学校の場合
            ELSIF g_sGAKOKB = 2 THEN
                rWLTBL.GAKO_CD := rMEIBO.TYUGAKO_CD;                      --学校コード
                rWLTBL.GAKKO_MEI := GKAFKGKOGTEQ(2, rMEIBO.TYUGAKO_CD);   --学校名
                rWLTBL.SYUSSHIN_SHOGAKKO_MEI := GKAFKGKOGTEQ(1, rMEIBO.SYOGAKO_CD);--出身小学校名
            ELSE
                NULL;
            END IF;
            --学年名
            IF g_sGAKOKB = 1 THEN
                rWLTBL.GAKUNENMEI := GKAFKGNGKGTEQ(g_sGAKOKB, rMEIBO.GAKUNEN, rMEIBO.SYOGAKO_CD, rMEIBO.GAKUKYU_CD);
            ELSIF g_sGAKOKB = 2 THEN
                rWLTBL.GAKUNENMEI := GKAFKGNGKGTEQ(g_sGAKOKB, rMEIBO.GAKUNEN, rMEIBO.TYUGAKO_CD, rMEIBO.GAKUKYU_CD);
            ELSE
                NULL;
            END IF;
            --郵便番号編集処理
-- 2025/02/04 JPJYS.WUZHENGDONG Update 0.3.000.009:ST_GKB_TMP00033 対応 Start
--            nRTN := KKAPK0010.FYUBINHENSHU(o_rJDSTSOFUSAKI.YUBIN_NO, sYUBIN_NO);
            IF o_rJDSTSOFUSAKI.YUBIN_NO IS NOT NULL THEN
                nRTN := KKAPK0010.FYUBINHENSHU(o_rJDSTSOFUSAKI.YUBIN_NO, sYUBIN_NO);
            ELSE
                nRTN := KKAPK0010.FYUBINHENSHU(o_rJDSTKIHON.YUBIN_NO, sYUBIN_NO);
            END IF;
-- 2025/02/04 JPJYS.WUZHENGDONG Update 0.3.000.009:ST_GKB_TMP00033 対応 End
            rWLTBL.YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(sYUBIN_NO, 0);   --送付先郵便番号
            --児童生徒住所
-- 2025/02/04 JPJYS.WUZHENGDONG Update 0.3.000.009:ST_GKB_TMP00033 対応 Start
--            rWLTBL.JIDO_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rJDSTSOFUSAKI.CHOMEI, o_rJDSTSOFUSAKI.BANCHI, o_rJDSTSOFUSAKI.KATAGAKI, NULL);
            IF o_rJDSTSOFUSAKI.CHOMEI IS NOT NULL OR o_rJDSTSOFUSAKI.BANCHI IS NOT NULL OR  o_rJDSTSOFUSAKI.KATAGAKI IS NOT NULL THEN
                rWLTBL.JIDO_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rJDSTSOFUSAKI.CHOMEI, o_rJDSTSOFUSAKI.BANCHI, o_rJDSTSOFUSAKI.KATAGAKI, NULL);
            ELSE
                rWLTBL.JIDO_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rJDSTKIHON.CHOMEI, o_rJDSTKIHON.BANCHI, o_rJDSTKIHON.KATAGAKI, NULL);
            END IF;
-- 2025/02/04 JPJYS.WUZHENGDONG Update 0.3.000.009:ST_GKB_TMP00033 対応 End
            IF rMEIBO.KUIKIGAISHUGAKU_FLG = '1' THEN
                rWLTBL.HENKO_JIYU := '区域外就学事由';                        --就学校・区域外変更事由
                --許可年月日
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00286横展開対応
                --rWLTBL.KUIKIGAISHUGAKU_KYOKA_BI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(rMEIBO.KUIKIGAISHUGAKU_KYOKA_BI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 10, '');
                rWLTBL.KUIKIGAISHUGAKU_KYOKA_BI := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(rMEIBO.KUIKIGAISHUGAKU_KYOKA_BI), 10, '');
            END IF;
            --作成日
            rWLTBL.SYS_SAKUSEIBI := KKAPK0020.FDateFmt(TO_CHAR(SYSDATE, 'YYYY/MM/DD'), 10, '');
            rWLTBL.WSNUM    := g_sWSNUM;                                  --端末番号
            rWLTBL.BATCHKBN := 2;                                         --即時バッチ区分
            rWLTBL.JOBNUM   := g_nJOBNUM;                                 --ジョブNO
            INSERT INTO GKBWNYUKAKUSYAMEIBO VALUES rWLTBL;
        END LOOP;
        CLOSE cCURSOR;
        -- 関数終了
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
            IF cCURSOR%ISOPEN THEN
              CLOSE cCURSOR;
            END IF;
            RETURN c_ERR;
    END FUNC_GET_JIDO_REC;
    --------------------------------------------------------
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE RETURN NUMBER
    IS
        bRTN                      BOOLEAN;  --戻り値
        nRTN                      NUMBER;   --戻り値
        rSYAMEIBO                 GKBWNYUKAKUSYAMEIBO%ROWTYPE;         --学校入学者名簿中間ワーク
        rWLTBL                    GKBWL650R001%ROWTYPE;                --学校入学者名簿ワーク
        NO                        NUMBER := 0;                         --ソート順
        o_sSHIMEIKANA             NVARCHAR2(1000);                     --氏名カナ
        o_sSHIMEIKANJI            NVARCHAR2(1000);                     --氏名漢字
        o_sBIRTHDAY               NVARCHAR2(1000);                     --生年月日
--  2024/09/06 ZCZL.WANGMING ADD START 0.3.000.002:8月1日認識合わせの横展開
        VSQL                      NVARCHAR2(1000);
        TYPE MC_CURSOR IS REF     CURSOR;
        cCURSORWL                 MC_CURSOR;
--  2024/09/06 ZCZL.WANGMING ADD END
    BEGIN
        --1-1.件数表の抽出条件を指定する。
        g_nCNT := GKBFKTBLCNT('GKBWNYUKAKUSYAMEIBO', NULL);
        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB650R001' THEN
--  2024/09/06 ZCZL.WANGMING UPATE START 0.3.000.002:8月1日認識合わせの横展開
--            FOR rSYAMEIBO IN(
--                         SELECT
--                             *
--                         FROM
--                             GKBWNYUKAKUSYAMEIBO
--                         WHERE WSNUM  = g_sWSNUM
--                         AND BATCHKBN = 2
--                         ORDER BY g_rJSTP.ORDERBYCLAUSE)
--            LOOP
            VSQL := '';
            VSQL := '  SELECT * FROM GKBWNYUKAKUSYAMEIBO  WHERE  WSNUM = ''' || g_sWSNUM || '''' || ' AND BATCHKBN = ' || c_BATCH;
            IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
               VSQL := VSQL || ' ORDER BY '|| g_rJSTP.ORDERBYCLAUSE ;
            END IF;
            OPEN cCURSORWL FOR VSQL;
            LOOP
               FETCH cCURSORWL INTO rSYAMEIBO;
               EXIT WHEN cCURSORWL%NOTFOUND;
--  2024/09/06 ZCZL.WANGMING UPDATE END
                NO := NO + 1;
                rWLTBL.NO := NO;                                                  --ソート順
                rWLTBL.NENDO := g_sNYUGAKUND;                                     --入学年度
                rWLTBL.TITLE := g_sTITLE;                                         --タイトル
                rWLTBL.JIDO_SHIMEI_KANA     := rSYAMEIBO.JIDO_SHIMEI_KANA;        --児童生徒氏名カナ
                rWLTBL.JIDO_SHIMEI_KANJI    := rSYAMEIBO.JIDO_SHIMEI_KANJI;       --児童生徒氏名
                rWLTBL.HOGOSHA_SHIMEI_KANA  := rSYAMEIBO.HOGOSHA_SHIMEI_KANA;     --保護者氏名カナ
                rWLTBL.HOGOSHA_SHIMEI_KANJI := rSYAMEIBO.HOGOSHA_SHIMEI_KANJI;    --保護者氏名
                rWLTBL.SEINENGAPI           := rSYAMEIBO.SEINENGAPI;              --生年月日
                rWLTBL.SEIBETSU             := rSYAMEIBO.SEIBETSU;                --性別
                rWLTBL.HOGOSHA_KANKEI       := rSYAMEIBO.HOGOSHA_KANKEI;          --児童生徒との関係
                rWLTBL.JIDO_KOKUSEKI        := rSYAMEIBO.JIDO_KOKUSEKIMEI;        --児童生徒国籍
                rWLTBL.HOGOSHA_KOKUSEKI     := rSYAMEIBO.HOGOSHA_KOKUSEKIMEI;     --保護者国籍
                rWLTBL.GAKKO_MEI            := rSYAMEIBO.GAKKO_MEI;               --学校名
                rWLTBL.GAKUNEN              := rSYAMEIBO.GAKUNENMEI;              --学年
                rWLTBL.JIDO_KOJIN_NO        := rSYAMEIBO.KOJIN_NO;                --児童生徒宛名番号
                rWLTBL.HOGOSHA_KOJIN_NO     := rSYAMEIBO.HOGOSHA_KOJIN_NO;        --保護者宛名番号
                rWLTBL.YUBIN_NO             := rSYAMEIBO.YUBIN_NO;                --郵便番号
                rWLTBL.JIDO_JUSHO           := rSYAMEIBO.JIDO_JUSHO;              --児童生徒住所
                rWLTBL.HENKO_JIYU           := rSYAMEIBO.HENKO_JIYU;              --就学校・区域外変更事由
                rWLTBL.HENKO_KYOKABI        := rSYAMEIBO.KUIKIGAISHUGAKU_KYOKA_BI;--許可年月日
                rWLTBL.BIKO_LABEL           := g_sBIKO_LABEL;                     --出身小学校/備考_ラベル
                rWLTBL.BIKO                 := rSYAMEIBO.SYUSSHIN_SHOGAKKO_MEI;   --出身小学校/備考
                rWLTBL.SYS_SAKUSEIBI        := rSYAMEIBO.SYS_SAKUSEIBI;           --作成日
                rWLTBL.BREAK_NO             := NULL;                              --改ページキー
                rWLTBL.WSNUM                := g_sWSNUM;                          --端末番号
                rWLTBL.BATCHKBN             := 2;                                 --即時バッチ区分
                rWLTBL.JOBNUM               := g_nJOBNUM;                         --ジョブNO
                --登録ワークテーブル
                INSERT INTO GKBWL650R001 VALUES rWLTBL;
                g_nCSVCNT := g_nCSVCNT + 1;                                       --CSV出力件数
            END LOOP;
            --  2024/09/06 ZCZL.WANGMING UPATE START 0.3.000.002:8月1日認識合わせの横展開
            CLOSE cCURSORWL;
          ELSE
            NULL;
        END CASE;
        --学校入学者名簿対象件数
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_nCNT,'入力 学校入学者名簿対象件数',1);
        --CSV出力件数
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_nCSVCNT,'出力 学校入学者名簿ＣＳＶ',2);
        -- 関数終了
        bRTN := FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 0, '', '', '学校入学者名簿ＣＳＶ[' || g_nCNT || ']件を出力しました。', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
            --  2024/09/06 ZCZL.WANGMING ADD START 0.3.000.002:8月1日認識合わせの横展開
            IF cCURSORWL%ISOPEN THEN
              CLOSE cCURSORWL;
            END IF;
             --  2024/09/06 ZCZL.WANGMING ADD END
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 1, SQLCODE, SQLERRM, 'ＣＳＶファイルの書き出し処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN c_ERR;
    END FUNC_CSV_CREATE;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1 RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        nRTN             NUMBER;   --戻り値
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        --条件取得処理
        bRTN := FUNC_JYOKEN_GET;
        IF NOT bRTN THEN
            RAISE EERROR;
        END IF;
        --初期処理
        bRTN := FUNC_INIT;
        IF NOT bRTN THEN
            RAISE EERROR;
        END IF;
        --学齢簿から値を取得して、学校入学者名簿中間ワークテーブルを作成する
        nRTN := FUNC_GET_JIDO_REC;
        IF nRTN <> 0 THEN
            RAISE EERROR;
        END IF;
        --帳票出力CSVの作成
        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB650R001' THEN
            DELETE FROM GKBWL650R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
            --ＣＳＶファイル作成処理
            nRTN := FUNC_CSV_CREATE;
            IF nRTN <> 0 THEN
                RAISE EERROR;
            END IF;
            --CSV出力処理
            bRTN := FUNC_B11CSV('GKBWL650R001');
          ELSE
            NULL;
        END CASE;
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE;
    END FUNC_B10SAKUHYO1;
    --------------------------------------------------------
    --  機能概要      : 更新処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1 RETURN BOOLEAN
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
    --  作成者／作成日: ZCZL.xiaoya 2024/06/17
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
END GKBPB00500;
/
