CREATE OR REPLACE PACKAGE BODY GKBPB00130
--1.0.402.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB(教育)
--  プログラム名  : 入学予定者名簿作成処理
--  機能概要      : 学齢簿から小学校または中学校への入学予定者を抽出し、入学予定者名簿を作成する。
--                  件数表を出力する。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.CONGDAN 2024/01/02
--------------------------------------------------------
--  変更履歴
--  2024/06/17 ZCZL.muzhilin Update 0.3.000.000:新WizLIFE２次開発
--  2024/09/05 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/10/28 ZCZL.HAODAPENG UPDATE 0.3.000.002:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/28 JPJYS.SHAXUE UPDATE 0.3.000.003:IT_GKB_00682の対応
--  2024/12/26 JIP.KF 続柄取得結果の戻り値でRAISE EERRORしている個所を削除
--  2025/05/08 CTC.HUANG UPDATE 1.0.003.000 GK_QA13756_入力予定者名簿作成、中学校異常終了を対応
--  2025/05/08 CTC.HUANG UPDATE 1.0.003.000 GK_QA13766_入学予定者名簿の児童生徒の住所欄が空欄
--  2025/11/10 CTC.GL UPDATE 1.0.205.000:GKB_QA22990対応
--  2025/12/8 CTC.GL UPDATE 1.0.402.000:GKB_QA24306対応
---------------------------------------------------------
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
    g_nINDEX                      NUMBER := 0;

    g_nTIME NUMBER;  --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
    g_nGKB120_INDEX               NUMBER;                      --教育異動通知書_インデックス番号
    g_vGKB120_CTL                 NVARCHAR2(1000);             --教育異動通知書_出力制御
    g_nJIDO_KOKUSEKI_CD           NUMBER;                      --児童生徒国籍コード
    g_vJIDO_KOKUSEKI_MEI          NVARCHAR2(60);               --児童生徒国籍名
    g_nHOGOSHA_KOKUSEKI_CD        NUMBER;                      --保護者国籍コード
    g_vHOGOSHA_KOKUSEKI_MEI       NVARCHAR2(60);               --保護者国籍名
    g_vJIDO_YUBIN_NO              NVARCHAR2(10);               --児童生徒郵便番号
-- 2024/06/05 ZCZL.muzl Add end

    --パラメータ変数
    VMSG       NVARCHAR2(4000);  --エラーメッセージ
    NERR       NUMBER;          --エラー有無
    NRTN       NUMBER;

    IRTN        PLS_INTEGER;
    BRTN        BOOLEAN;
    EERROR      EXCEPTION;
    VLOG        NVARCHAR2(500);
    VSQL        VARCHAR2(2000);
    --  定数
    C_TABLE          CONSTANT NVARCHAR2(50) :=  'GKBWJIDOSHINNYUGAKU';      --  テーブル名
    --画面入力条件
    g_vJYOUKEN01                  NVARCHAR2(1000);
    g_vJYOUKEN02                  NVARCHAR2(1000);
    g_vJYOUKEN03                  NVARCHAR2(1000);
    g_vJYOUKEN04                  NVARCHAR2(1000);

    VNENDO                 NVARCHAR2(11);      -- 入学年度
    NTAISHOGAKO_KBN        NUMBER;             -- 処理対象学校区分
    --  2024/10/28 ZCZL.HAODAPENG UPDATE START 0.3.000.002:学校コードリスト仕様変更の対応
    --VSYOGAKO_CD            NVARCHAR2(100);     -- 小学校コード
    --VTYUGAKO_CD            NVARCHAR2(100);     -- 中学校コード
    VSYOGAKO_CD            NVARCHAR2(1000);     -- 小学校コード
    VTYUGAKO_CD            NVARCHAR2(1000);     -- 中学校コード
    --  2024/10/28 ZCZL.HAODAPENG UPDATE END
    NJIDOSINNYUGAKU_COUNT  NUMBER;             -- 入学予定者名簿の出力件数

    VSQLERRM          NVARCHAR2(50);
    NVALUE            NUMBER;         -- 児童生徒との関係システム条件
    NRENBAN           NUMBER;         -- 連番
    NCINT             NUMBER;         -- 対象児童生徒数
    NSHOGAKO_CNT      NUMBER;         -- 小学校入学児童生徒数
    NCHUGAKO_CNT      NUMBER;         -- 中学校入学児童生徒数
    NYOCHIENFUMEI_CNT NUMBER;         -- 幼稚園・保育園不明児童生徒数
    NSYS_SAKUSEIBI    NUMBER;         -- 作成日
    VHYOJI_SAKUSEIBI  NVARCHAR2(20);  -- 表示用作成日
    VHYOJI_SAIN       NVARCHAR2(20);  -- 保護者判定表示サイン
    VHYOJI_RENBAN     NVARCHAR2(6);   -- 表示用連番
    RATENA_REC        GABTATENAKIHON%ROWTYPE;
    RSOFU_REC         GABTSOFUSAKI%ROWTYPE;

    -- 児童生徒新入学ワーク用配列
    TYPE JIDO_SINNYUGAKU_TBL IS TABLE OF GKBWJIDOSHINNYUGAKU%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_SINNYUGAKU        JIDO_SINNYUGAKU_TBL;
    -- 幼稚園・保育園児童生徒数レコード配列
    TYPE MR_YOCHIEN_RECORD IS RECORD(YOCHIEN_CD    GKBWYOCHIENJOHO.YOCHIEN_CD%TYPE    -- 幼稚園・保育園コード
                                    ,YOCHIEN_MEI   GKBWYOCHIENJOHO.YOCHIEN_MEI%TYPE   -- 幼稚園・保育園名
                                    ,YOCHIEN_KAZU  NUMBER);                              -- 幼稚園・児童生徒数
    TYPE YOCHIEN_RECORD_TBL IS TABLE OF MR_YOCHIEN_RECORD;
    MYOCHIEN_RECORD       YOCHIEN_RECORD_TBL := YOCHIEN_RECORD_TBL();

    TYPE MR_JUKIIDO_JIDOSEITO IS RECORD (KOJIN_NO   GKBTGAKUREIBO.KOJIN_NO%TYPE                   -- 宛名番号
                                        ,ZOKUGARA1  GKBTGAKUREIBO.ZOKUGARA1%TYPE                  -- 続柄１
                                        ,ZOKUGARA2  GKBTGAKUREIBO.ZOKUGARA2%TYPE                  -- 続柄２
                                        ,ZOKUGARA3  GKBTGAKUREIBO.ZOKUGARA3%TYPE                  -- 続柄３
                                        ,ZOKUGARA4  GKBTGAKUREIBO.ZOKUGARA4%TYPE                  -- 続柄４
                                        ,HOGOSYA_KOJIN_NO   GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE   -- 保護者宛名番号
                                        ,HOGOSYA_ZOKUGARA1  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1%TYPE  -- 保護者続柄１
                                        ,HOGOSYA_ZOKUGARA2  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2%TYPE  -- 保護者続柄２
                                        ,HOGOSYA_ZOKUGARA3  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3%TYPE  -- 保護者続柄３
                                        ,HOGOSYA_ZOKUGARA4  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4%TYPE  -- 保護者続柄４
                                        ,GAKUNEN      GKBTGAKUREIBO.GAKUNEN%TYPE                  -- 学年
                                        ,SYOGAKO_CD   GKBTGAKUREIBO.SYOGAKO_CD%TYPE               -- 小学校コード
                                        ,SYOGAKOMEI   GKBTSHOGAKKO.SYOGAKOMEI%TYPE                 -- 小学校名
                                        ,TYUGAKO_CD   GKBTGAKUREIBO.TYUGAKO_CD%TYPE               -- 中学校コード
                                        ,TYUGAKOMEI   GKBTCHUGAKKO.TYUGAKOMEI%TYPE                 -- 中学校名
                                        ,YOCHIEN_CD   GKBWYOCHIENJOHO.YOCHIEN_CD%TYPE          -- 幼稚園・保育園コード
                                        ,YOCHIEN_MEI  GKBWYOCHIENJOHO.YOCHIEN_MEI%TYPE         -- 幼稚園・保育園名
                                        ,KISAI_JUNI   GABTJUKIIDO.KISAI_JUNI%TYPE               -- 記載順位
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
-- 2025/01/20 JIP.KF ST
                                        --,KOKUSEKI_CD  GABTKOKUSEKI.KOKUSEKI_CD%TYPE
                                        --,KOKUMEI  GABTKOKUSEKI.KOKUMEI%TYPE);
                                        ,KOKUSEKI_CD  GABTATENAKIHON.KOKUSEKI_CD%TYPE);
-- 2025/01/20 JIP.KF ST
-- 2024/06/05 ZCZL.muzl Add end
    RWJUKIIDO_JIDOSEITO        MR_JUKIIDO_JIDOSEITO;

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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
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
-- 2024/06/17 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
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
        --  2024/10/28 ZCZL.HAODAPENG ADD START 0.3.000.002:学校コードリスト仕様変更の対応
        nGAKOUCD_TMP  NUMBER; --学校コード
        --  2024/10/28 ZCZL.HAODAPENG ADD END
    BEGIN
        -- 入力引数を分解して配列にセットする
        -- 引数の学校コード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
        -- 処理ステップを取得
        --  2024/10/28 ZCZL.HAODAPENG UPDATE START 0.3.000.002:学校コードリスト仕様変更の対応
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
            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
            IF nGAKOUCD_TMP IS NOT NULL THEN
                IF i = aGAKOCD.COUNT THEN
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP ;
                ELSE
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP || ',';
                END IF;
            END IF;
        END LOOP;
        --  2024/10/28 ZCZL.HAODAPENG UPDATE END
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_GET_GAKOCD;
-- 2024/06/17 ZCZL.muzl Add end
    --------------------------------------------------------
    --  機能概要      : 入学年度のチェック
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    --------------------------------------------------------
      FUNCTION FUNC_NYUGAKUNENDO_CHK RETURN NUMBER
      IS
        NKIJUN_BI       NUMBER;        --基準日
        NYUGAKUNENDO    NUMBER;        --変数.入学年度
        NJINENDO        NUMBER;        --2-2-3. 次年度のチェック変数.次年度
      BEGIN
        --2-2-1. 桁数のチェック
        IF LENGTH(g_vJYOUKEN01) <> 3 THEN
          --a. 変数.エラー有無=1の場合
          IF NERR = 1 THEN
            VMSG := VMSG || ';';
          END IF;
          --b. エラーメッセージの追加
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,入学年度の桁数が正しくありません。,';
          NERR := 1;
        END IF;

        --2-2-2. 年度変換のチェック0
        --1.共通パッケージ.年度変換を呼び出す。
        NYUGAKUNENDO :=KKAPK0020.FNENDO(TO_NUMBER(g_vJYOUKEN01) ,1);
        --2.変数.入学年度=0の場合
        IF NYUGAKUNENDO = 0 THEN
          --a. 変数.エラー有無=1の場合
          IF NERR = 1 THEN
            VMSG := VMSG || ';';
          END IF;
          --b. エラーメッセージの追加
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,入学年度の形式が正しくありません。,';
          NERR := 1;
        END IF;

        --2-2-3. 次年度のチェック
        --1.基準日の取得
        NKIJUN_BI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        --2.共通パッケージ.年度取得を呼び出す。
        NJINENDO := KKAPK0020.FDAYNENDO(NKIJUN_BI ,0);
        NJINENDO := NJINENDO + 1;
        --3.変数.入学年度<>変数.次年度
        IF NJINENDO <> NYUGAKUNENDO THEN
          --a. 変数.エラー有無=1の場合
          IF NERR = 1 THEN
            VMSG := VMSG || ';';
          END IF;
          --b. エラーメッセージの追加
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,入学年度が次年度ではありません。,';
          NERR := 1;
        END IF;
        RETURN 0;
      END FUNC_NYUGAKUNENDO_CHK;

    --------------------------------------------------------
    --  機能概要      : 小学校コードのチェック
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    --------------------------------------------------------
    --  2024/10/28 ZCZL.HAODAPENG UPDATE 0.3.000.002:学校コードリスト仕様変更の対応
--      FUNCTION FUNC_SHOGAKU_CHK RETURN NUMBER
--      IS
--        NRTN  NUMBER;
--      BEGIN
--        --2-3-1. GKB共通パッケージ.学校コードチェックを呼び出す。
--        NRTN := GKBPK00010.FGCODCHK(g_vJYOUKEN03);
--        IF NRTN <> 0 THEN
--          --1.変数.エラー有無=1の場合
--          IF NERR = 1 THEN
--            VMSG := VMSG || ';';
--          END IF;
--          --2.エラーメッセージの追加
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,小学校コードが正しくありません。,';
--          NERR := 1;
--        END IF;
--        RETURN 0;
--      END FUNC_SHOGAKU_CHK;

    --------------------------------------------------------
    --  機能概要      : 中学校コードのチェック
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    --------------------------------------------------------
--      FUNCTION FUNC_CHUGAKU_CHK RETURN NUMBER
--      IS
--        NRTN NUMBER;
--      BEGIN
--        --2-4-1. GKB共通パッケージ.学校コードチェックを呼び出す。
--        NRTN := GKBPK00010.FGCODCHK(g_vJYOUKEN04);
--        IF NRTN <> 0 THEN
--           --1.変数.エラー有無=1の場合
--          IF NERR = 1 THEN
--            VMSG := VMSG || ';';
--          END IF;
--          --2.エラーメッセージの追加
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,中学校コードが正しくありません。,';
--          NERR := 1;
--        END IF;
--        RETURN 0;
--      END FUNC_CHUGAKU_CHK;
      --  2024/10/28 ZCZL.HAODAPENG UPDATE 0.3.000.002:学校コードリスト仕様変更の対応
    ---------------------------------------------------------------
    --  機能概要      : 児童生徒新入学データの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    ---------------------------------------------------------------
      FUNCTION FUNC_JIDOSEITO_MAKE RETURN BOOLEAN
      IS
        IRTN                     PLS_INTEGER;
        BRTN                     BOOLEAN;
        BYOCHIEN_HANDAN          BOOLEAN;
        NYOUCHIEN_ICNT           NUMBER;
-- 2024/06/17 ZCZL.muzl Delete 0.3.000.000:新WizLIFE２次開発
--         IYOCHIEN_COUNT           PLS_INTEGER;
        EERROR                   EXCEPTION;
        VSETAI_NO                NVARCHAR2(20);    -- 世帯番号
        VHYOJI_SEINENGAPI        NVARCHAR2(20);    -- 表示用生年月日
        VHYOJI_SEIBETSU          NVARCHAR2(20);    -- 表示用性別
        VGAKUNENMEI              NVARCHAR2(20);    -- 学年名
        VGAKO_KBN                NVARCHAR2(2);     -- 学校区分
        VGAKOKUMEI               NVARCHAR2(60);    -- 学校区名
        VGAKOKU_CD               NVARCHAR2(20);    -- 学校区コード
        VGYOSEIKUMEI             NVARCHAR2(15);    -- 行政区名
        VHANMEI                  NVARCHAR2(15);    -- 班名
        VSANTEIDANTAIMEI         NVARCHAR2(40);    -- 算定団体名
        VJIDO_HONMYO_KANA        NVARCHAR2(100);   -- 児童本名かな
        VJIDO_HONMYO_KANJI       NVARCHAR2(100);   -- 児童本名漢字
        NYOCHIEN_CD              NUMBER;           -- 幼稚園・保育園コード
        VYOCHIEN_MEI             NVARCHAR2(180);   -- 幼稚園・保育園名
        NHOGOSYA_KOJIN_NO        NUMBER;           -- 保護者宛名番号
        HOGORATENA_REC           GABTATENAKIHON%ROWTYPE;  -- 保護者宛名レコード
        HOGORSOFU_REC            GABTSOFUSAKI%ROWTYPE;    -- 保護者送付先レコード
        VHOGOSYA_SHIMEI_KANA     NVARCHAR2(100);          -- 保護者氏名かな
        VHOGOSYA_SHIMEI_KANJI    NVARCHAR2(100);          -- 保護者氏名漢字
        VCHOMEI                  NVARCHAR2(40);           -- 町名
        VBANCHI                  NVARCHAR2(40);           -- 番地
        VKATAGAKI                NVARCHAR2(60);           -- 方書
        VZOKUGARAMEI1            NVARCHAR2(50);           -- 保護者との関係
        IHERR                    PLS_INTEGER;             -- エラーコード
        VZOKUGARAMEI2            NVARCHAR2(50);           -- 児童生徒との関係
        VHOGOSHA_SHIMEI_JODAN    NVARCHAR2(16);           -- 保護者氏名上段
        VHOGOSHA_SHIMEI_GEDAN    NVARCHAR2(85);           -- 保護者氏名下段
        VJYUUSHO                 NVARCHAR2(200);          -- 住所
        VKON_JUSHO_JODAN         NVARCHAR2(20);           -- 住所上段
        VKON_JUSHO_GEDAN         NVARCHAR2(20);           -- 住所下段
        NZOKUGARACD              NUMBER;                  -- 判定用続柄コード
        VYUBIN_NO                NVARCHAR2(15);           -- 郵便番号
        NKISAI_JUNI              NUMBER;                  -- 記載順位
        VDUMMY                   NVARCHAR2(30);           -- ダミー
        NDUMMY                   NUMBER;                  -- ダミー
        IMAX                     PLS_INTEGER;             -- 幼稚園・保育園児童生徒数レコード配列の最大値
-- 2024/06/17 ZCZL.muzl Delete 0.3.000.000:新WizLIFE２次開発
--         IMIN                     PLS_INTEGER;             -- 幼稚園・保育園児童生徒数レコード配列の最小値
        VKOJIN_NO_CD             NVARCHAR2(15);           -- 連携パラメータ用（コードB）
        VKOJIN_NO_CDMEI          NVARCHAR2(50);           -- 連携パラメータ用（コード名称）
        TYPE CURTYPE             IS REF CURSOR;
        CDATA                    CURTYPE;
-- 2024/06/17 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
        vKOKUSEKI_MEI       NVARCHAR2(60);                -- 国籍名
        vKOKUMEI_KANA            NVARCHAR2(120);          -- 国名カナ
        vKOKUMEI_ALP             NVARCHAR2(120);          -- 国名アルファベット
-- 2024/06/17 ZCZL.muzl Add end
      BEGIN
        -- 2-8-1. ワーク用配列の初期化
        MJIDO_SINNYUGAKU.DELETE;
        -- 2-8-2. 各変数の初期化
        NRENBAN            := 0;
        NCINT              := 0;
        NSHOGAKO_CNT       := 0;
        NCHUGAKO_CNT       := 0;
        NYOCHIENFUMEI_CNT  := 0;
        MYOCHIEN_RECORD.DELETE;
        -- 2-8-3. 作成日のセット
        NSYS_SAKUSEIBI := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
        -- 2-8-4. 表示用作成日の編集
        BRTN := KKAPK0020.FDAYEDIT(NDUMMY,
                                    NSYS_SAKUSEIBI,
                                    VDUMMY,
                                    VDUMMY,
                                    VHYOJI_SAKUSEIBI,
                                    VDUMMY,
                                    VDUMMY,
                                    NDUMMY,
                                    NDUMMY,
                                    NDUMMY,
                                    NDUMMY,
                                    NDUMMY,
                                    NDUMMY,
                                    NDUMMY);
        IF NOT BRTN THEN
          RAISE EERROR;
        END IF;
        -- 連携パラメータ取得
        BRTN := KKCPK0011.FCODEHEN('RSTG', 'KNO', 0, VKOJIN_NO_CD, VKOJIN_NO_CDMEI);
        -- 児童生徒新入学カーソル
        VSQL :=         'SELECT GA.KOJIN_NO          AS KOJIN_NO';
        VSQL := VSQL || '      ,GA.ZOKUGARA1         AS ZOKUGARA1';
        VSQL := VSQL || '      ,GA.ZOKUGARA2         AS ZOKUGARA2';
        VSQL := VSQL || '      ,GA.ZOKUGARA3         AS ZOKUGARA3';
        VSQL := VSQL || '      ,GA.ZOKUGARA4         AS ZOKUGARA4';
        VSQL := VSQL || '      ,GA.HOGOSYA_KOJIN_NO  AS HOGOSYA_KOJIN_NO';
        VSQL := VSQL || '      ,GA.HOGOSYA_ZOKUGARA1 AS HOGOSYA_ZOKUGARA1';
        VSQL := VSQL || '      ,GA.HOGOSYA_ZOKUGARA2 AS HOGOSYA_ZOKUGARA2';
        VSQL := VSQL || '      ,GA.HOGOSYA_ZOKUGARA3 AS HOGOSYA_ZOKUGARA3';
        VSQL := VSQL || '      ,GA.HOGOSYA_ZOKUGARA4 AS HOGOSYA_ZOKUGARA4';
        VSQL := VSQL || '      ,GA.GAKUNEN           AS GAKUNEN';
        VSQL := VSQL || '      ,GA.SYOGAKO_CD        AS SYOGAKO_CD';
        VSQL := VSQL || '      ,SY.SYOGAKOMEI        AS SYOGAKOMEI';
        VSQL := VSQL || '      ,GA.TYUGAKO_CD        AS TYUGAKO_CD';
        VSQL := VSQL || '      ,TY.TYUGAKOMEI        AS TYUGAKOMEI';
        VSQL := VSQL || '      ,WK.YOCHIEN_CD        AS YOCHIEN_CD';
        VSQL := VSQL || '      ,WK.YOCHIEN_MEI           AS YOCHIEN_MEI';
        VSQL := VSQL || '      ,NVL(JU.KISAI_JUNI, 0)    AS KISAI_JUNI';
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
-- 2025/01/20 JIP.KF ST
        --VSQL := VSQL || '      ,GABTKOKUSEKI.KOKUSEKI_CD    AS KOKUSEKI_CD';
        --VSQL := VSQL || '      ,GABTKOKUSEKI.KOKUMEI        AS KOKUMEI';
        VSQL := VSQL || '      ,GABTATENAKIHON.KOKUSEKI_CD    AS KOKUSEKI_CD';
-- 2025/01/20 JIP.KF ED
-- 2024/06/05 ZCZL.muzl Add end
        VSQL := VSQL || '  FROM GKBTGAKUREIBO GA';
-- 2024/06/05 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
-- 2025/01/20 JIP.KF ST
        --VSQL := VSQL || '      ,GABTATENAKIHON,GABTKOKUSEKI ';
        VSQL := VSQL || '      ,GABTATENAKIHON ';
-- 2025/01/20 JIP.KF ED
        VSQL := VSQL || '      ,GKBTSHOGAKKO SY';
        VSQL := VSQL || '      ,GKBTCHUGAKKO TY';
        VSQL := VSQL || '      ,(SELECT D.*,';
        VSQL := VSQL || '               D.KOJIN_NO || KKAPK0010.FChkDgtWiz11(D.KOJIN_NO) AS KOJIN_NO_CDTSUKI';
        VSQL := VSQL || '          FROM GKBWYOCHIENJOHO D) WK ';
        VSQL := VSQL || '      ,GABTJUKIIDO JU';
        VSQL := VSQL || ' WHERE GA.SAISHIN_KBN = 0';
        VSQL := VSQL || '   AND GA.GENZON_KBN  = 0';
        VSQL := VSQL || '   AND GA.GEN_JIYU_CD = 0';
        VSQL := VSQL || '   AND GA.GEN_NENGAPI = 0';
        -- 変数.学校区分=0の場合
        IF NTAISHOGAKO_KBN = 0 THEN
          --  2024/10/28 ZCZL.HAODAPENG UPDATE START 0.3.000.002:学校コードリスト仕様変更の対応
          --VSQL := VSQL || '  AND GA.GAKUNEN IN (0,6)';
          -- 変数.小学校コードNOT NULLの、変数.中学校コードNOT NULL場合
          --IF VSYOGAKO_CD  IS NOT NULL  AND VTYUGAKO_CD IS NOT NULL  THEN
          --  VSQL := VSQL || '  AND (GA.SYOGAKO_CD IN ( ' || VSYOGAKO_CD  || ' ) ' || ' OR GA.TYUGAKO_CD IN ( ' || VTYUGAKO_CD || ')' || ')';
          -- 変数.中学校コードNOT NULL 、変数.小学校コードIS NULLの場合
          --ELSIF VTYUGAKO_CD IS NOT NULL AND VSYOGAKO_CD  IS  NULL THEN
          --  VSQL := VSQL || '  AND GA.TYUGAKO_CD IN ( ' || VTYUGAKO_CD || ' ) ';
          -- 変数.中学校コードIS NULL 、変数.小学校コードNOT NULL
          --ELSIF VTYUGAKO_CD IS  NULL AND VSYOGAKO_CD  IS NOT NULL THEN
          --  VSQL := VSQL || '  AND GA.SYOGAKO_CD IN ( ' || VSYOGAKO_CD || ' ) ';
          --ELSE
          --  NULL;
          --END IF;
-- 2025/01/20 JIP.KF ST
          --NULL;
          VSQL := VSQL || '  AND GA.GAKUNEN IN (0,6)';
-- 2025/01/20 JIP.KF ED
          --  2024/10/28 ZCZL.HAODAPENG UPDATE END

        ELSIF NTAISHOGAKO_KBN = 1 THEN
          --  2024/10/28 ZCZL.HAODAPENG UPDATE 0.3.000.002:学校コードリスト仕様変更の対応
-- 2025/01/20 JIP.KF ST
          --VSQL := VSQL || '  AND GA.GAKUNEN = 0';
          VSQL := VSQL || '  AND GA.GAKUNEN = 0';
-- 2025/01/20 JIP.KF ED
-- 2025/12/8 CTC.GL UPDATE START 1.0.402.000:GKB_QA24306対応
--          VSQL := VSQL || '  AND GA.GAKKO_KBN_CD = ' || NTAISHOGAKO_KBN;
          VSQL := VSQL || '  AND GA.GAKKO_KBN_CD IN (0,1)';
-- 2025/12/8 CTC.GL UPDATE END
          -- 変数.小学校コードNOT NULLの場合
          IF VSYOGAKO_CD  IS NOT NULL THEN
            VSQL := VSQL || '  AND GA.SYOGAKO_CD IN ( ' || VSYOGAKO_CD ||' ) ';
          END IF;
        ELSIF NTAISHOGAKO_KBN = 2 THEN
          --  2024/10/28 ZCZL.HAODAPENG UPDATE 0.3.000.002:学校コードリスト仕様変更の対応
-- 2025/01/20 JIP.KF ST
          --VSQL := VSQL || '  AND GA.GAKUNEN = 6';
          VSQL := VSQL || '  AND GA.GAKUNEN = 6';
-- 2025/01/20 JIP.KF ST
-- 2025/11/10 CTC.GL UPDATE START 1.0.205.000:GKB_QA22990対応
          --VSQL := VSQL || '  AND GA.GAKKO_KBN_CD = ' || NTAISHOGAKO_KBN;
          VSQL := VSQL || '  AND GA.GAKKO_KBN_CD = 1';
-- 2025/11/10 CTC.GL UPDATE END
          -- 変数.中学校コードNOT NULLの場合
          IF VTYUGAKO_CD IS NOT NULL THEN
            VSQL := VSQL || '  AND GA.TYUGAKO_CD IN ( ' || VTYUGAKO_CD || ' ) ';
          END IF;
        ELSE
          NULL;
        END IF;
        VSQL := VSQL || '   AND GA.SYOGAKO_CD = SY.SYOGAKO_CD(+)';
        VSQL := VSQL || '   AND GA.TYUGAKO_CD = TY.TYUGAKO_CD(+)';
        IF VKOJIN_NO_CD = 1 THEN
          VSQL := VSQL || '   AND GA.KOJIN_NO   = WK.KOJIN_NO(+)';
        ELSE
          VSQL := VSQL || '   AND GA.KOJIN_NO   = WK.KOJIN_NO_CDTSUKI(+)';
        END IF;
        VSQL := VSQL || '   AND GA.KOJIN_NO   = JU.KOJIN_NO(+)';
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
        VSQL := VSQL || '   AND GA.KOJIN_NO                  = GABTATENAKIHON.KOJIN_NO ';
-- 2025/01/20 JIP.KF ST
        --VSQL := VSQL || '   AND GABTATENAKIHON.KOKUSEKI_CD   = GABTKOKUSEKI.KOKUSEKI_CD ';
-- 2025/01/20 JIP.KF ED
-- 2024/06/05 ZCZL.muzl Add end
        VSQL := VSQL || ' ORDER BY GA.KOJIN_NO';
        -- 2-8-5. 児童生徒新入学レコードの抽出
        OPEN CDATA FOR VSQL;
        LOOP
          FETCH CDATA INTO RWJUKIIDO_JIDOSEITO;
          EXIT WHEN CDATA%NOTFOUND;
            --初期化
            IMAX    := 0;
            BYOCHIEN_HANDAN   := TRUE;
            NYOUCHIEN_ICNT    := 0;
            VHYOJI_SEINENGAPI := NULL;
            NYOCHIEN_CD       := NULL;
            VYOCHIEN_MEI      := NULL;
            VGAKO_KBN         := NULL;
            VGAKOKU_CD        := NULL;
            VGAKOKUMEI        := NULL;
            HOGORATENA_REC    := NULL;
            NHOGOSYA_KOJIN_NO := 0;
            -- 2-8-6. 抽出した各レコードに対する処理
            -- 1.各件数のカウントアップ
            NCINT := NCINT + 1;
            IF RWJUKIIDO_JIDOSEITO.GAKUNEN = 0 THEN
              NSHOGAKO_CNT := NSHOGAKO_CNT + 1;
            END IF;
            IF RWJUKIIDO_JIDOSEITO.GAKUNEN = 6 THEN
              NCHUGAKO_CNT := NCHUGAKO_CNT + 1;
            END IF;
            -- 2.保護者判定表示サインの初期化
            VHYOJI_SAIN := NULL;
            -- 3.表示用連番のセット
            VHYOJI_RENBAN := TO_CHAR(NRENBAN + 1);
            -- 4.児童宛名情報の取得
            IRTN := GAAPK0030.FGETATENA(RWJUKIIDO_JIDOSEITO.KOJIN_NO
                                     ,'GKB'
                                     ,NSYS_SAKUSEIBI
                                     ,RATENA_REC
                                     ,RSOFU_REC);
            IF IRTN <> 0 THEN
              RAISE EERROR;
            END IF;
            -- 5.児童宛名情報の編集
            -- a. 表示用生年月日の編集
            BRTN := KKAPK0020.FDAYEDIT(NDUMMY,
                                        RATENA_REC.SEINENGAPI,
                                        VHYOJI_SEINENGAPI,
                                        VDUMMY,
                                        VDUMMY,
                                        VDUMMY,
                                        VDUMMY,
                                        NDUMMY,
                                        NDUMMY,
                                        NDUMMY,
                                        NDUMMY,
                                        NDUMMY,
                                        NDUMMY,
                                        NDUMMY);
            IF NOT BRTN THEN
              RAISE EERROR;
            END IF;
            -- b. 表示用性別の編集
            IF RATENA_REC.SEIBETSU = 1 THEN
              VHYOJI_SEIBETSU := '男';
            ELSIF RATENA_REC.SEIBETSU = 2 THEN
              VHYOJI_SEIBETSU := '女';
            ELSE
              VHYOJI_SEIBETSU := NULL;
            END IF;
            -- c. 世帯番号の編集
            VSETAI_NO := TO_CHAR(RATENA_REC.SETAI_NO);
            -- d. 学年名の編集
            VGAKUNENMEI := RWJUKIIDO_JIDOSEITO.GAKUNEN || '年生';
            -- e. 学校区分、学校区コード、学校区名の編集
            IF RWJUKIIDO_JIDOSEITO.GAKUNEN = 0 THEN
              VGAKO_KBN := 1;
              VGAKOKU_CD  := RWJUKIIDO_JIDOSEITO.SYOGAKO_CD;
              VGAKOKUMEI := RWJUKIIDO_JIDOSEITO.SYOGAKOMEI;
            ELSIF RWJUKIIDO_JIDOSEITO.GAKUNEN = 6 THEN
              VGAKO_KBN := 2;
              VGAKOKU_CD  := RWJUKIIDO_JIDOSEITO.TYUGAKO_CD;
              VGAKOKUMEI := RWJUKIIDO_JIDOSEITO.TYUGAKOMEI;
            ELSE
              NULL;
            END IF;
            -- f. 行政区名の編集
            VGYOSEIKUMEI := GAAPK0030.FGYOSEIKUMEI(RATENA_REC.SANTEIDANTAI_CD, RATENA_REC.GYOSEIKU_CD);
            -- g. 班名の編集
            VHANMEI := GAAPK0030.FHANMEI(RATENA_REC.SANTEIDANTAI_CD, RATENA_REC.HAN_CD);
            -- h. 算定団体名の編集
            IRTN := GAAPK0030.FJICHINAME(RATENA_REC.SANTEIDANTAI_CD, VSANTEIDANTAIMEI);
            -- i. 児童本名かな、児童本名漢字の編集
            IF RATENA_REC.JINKAKU_KBN = 1 THEN
              VJIDO_HONMYO_KANA := RATENA_REC.HONMYO_KANA;
              VJIDO_HONMYO_KANJI := RATENA_REC.HONMYO_KANJI;
            ELSE
              VJIDO_HONMYO_KANA := NULL;
              VJIDO_HONMYO_KANJI := NULL;
            END IF;
-- 2024/06/05 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
            -- j. 幼稚園・保育園コード、幼稚園・保育園名の編集
--             IF RWJUKIIDO_JIDOSEITO.GAKUNEN = 0 THEN
--               NYOCHIEN_CD := RWJUKIIDO_JIDOSEITO.YOCHIEN_CD;
--               VYOCHIEN_MEI := RWJUKIIDO_JIDOSEITO.YOCHIEN_MEI;
--             ELSIF RWJUKIIDO_JIDOSEITO.GAKUNEN = 6 THEN
--               NYOCHIEN_CD := 0;
--               VYOCHIEN_MEI := NULL;
--             ELSE
--               NULL;
--             END IF;
-- 2024/06/05 ZCZL.muzl Delete end
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
            -- j.児童生徒国籍名の編集
            IRTN := GKAFKKKMGET(RATENA_REC.KOKUSEKI_CD,vKOKUMEI_KANA,vKOKUSEKI_MEI,vKOKUMEI_ALP);
            --k.（児童生徒）国籍コード、国籍名の編集
            g_nJIDO_KOKUSEKI_CD     := RATENA_REC.KOKUSEKI_CD;
            g_vJIDO_KOKUSEKI_MEI    := vKOKUSEKI_MEI;
            --ｌ.（児童生徒）郵便番号の編集の編集
            -- 2025/01/21 JPJYS.SSH 更新 Start
            -- g_vJIDO_YUBIN_NO        := RATENA_REC.YUBIN_NO;
            g_vJIDO_YUBIN_NO        := SUBSTR(RATENA_REC.YUBIN_NO,1,3) || '-' || SUBSTR(RATENA_REC.YUBIN_NO,4);
            -- 2025/01/21 JPJYS.SSH 更新 Start
-- 2024/06/05 ZCZL.muzl Add end
-- 2024/06/05 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
            -- 6.各幼稚園・保育園の児童生徒数のカウントアップ
--             IF RWJUKIIDO_JIDOSEITO.GAKUNEN = 0 THEN
--               IF NYOCHIEN_CD <> 0 THEN
--                 IYOCHIEN_COUNT := MYOCHIEN_RECORD.COUNT;
--                 IF IYOCHIEN_COUNT <> 0 THEN
--                   IMIN := MYOCHIEN_RECORD.FIRST;
--                   IMAX := MYOCHIEN_RECORD.LAST;
--                   FOR ICNT IN IMIN..IMAX LOOP
--                     IF NYOCHIEN_CD = MYOCHIEN_RECORD(ICNT).YOCHIEN_CD THEN
--                       BYOCHIEN_HANDAN := FALSE;
--                       NYOUCHIEN_ICNT := ICNT;
--                       EXIT;
--                     END IF;
--                   END LOOP;
--                 END IF;
                -- 幼稚園・保育園児童生徒数レコード配列に変数.幼稚園・保育園コードが含まれていない場合
--                 IF BYOCHIEN_HANDAN OR IMAX = 0 THEN
--                   MYOCHIEN_RECORD.EXTEND;
--                   MYOCHIEN_RECORD(IMAX + 1).YOCHIEN_CD   := NYOCHIEN_CD;
--                   MYOCHIEN_RECORD(IMAX + 1).YOCHIEN_MEI  := VYOCHIEN_MEI;
--                   MYOCHIEN_RECORD(IMAX + 1).YOCHIEN_KAZU := 1;
                -- 幼稚園・保育園児童生徒数レコード配列に変数.幼稚園・保育園コードが含まれている場合
--                 ELSE
--                   MYOCHIEN_RECORD(NYOUCHIEN_ICNT).YOCHIEN_KAZU := MYOCHIEN_RECORD(NYOUCHIEN_ICNT).YOCHIEN_KAZU + 1;
--                 END IF;
--               ELSE
--                 NYOCHIENFUMEI_CNT := NYOCHIENFUMEI_CNT +1;
--               END IF;
--             END IF;
-- 2024/06/05 ZCZL.muzl Delete end
            -- 7.学齢簿に保護者が設定されている場合
            IF RWJUKIIDO_JIDOSEITO.HOGOSYA_KOJIN_NO > 0 THEN
              -- a. 保護者宛名情報の取得
              NHOGOSYA_KOJIN_NO := RWJUKIIDO_JIDOSEITO.HOGOSYA_KOJIN_NO;
              IRTN := GAAPK0030.FGETATENA(NHOGOSYA_KOJIN_NO
                                       ,'GKB'
                                       ,NSYS_SAKUSEIBI
                                       ,HOGORATENA_REC
                                       ,HOGORSOFU_REC);
              IF IRTN <> 0 THEN
                RAISE EERROR;
              END IF;
              -- b. 保護者宛名情報の編集
              VHOGOSYA_SHIMEI_KANA  := HOGORATENA_REC.SHIMEI_KANA;
              VHOGOSYA_SHIMEI_KANJI := HOGORATENA_REC.SHIMEI_KANJI;
              VCHOMEI               := HOGORATENA_REC.CHOMEI;
              VBANCHI               := HOGORATENA_REC.BANCHI;
              VKATAGAKI             := HOGORATENA_REC.KATAGAKI;
              -- 保護者との関係の編集
              IRTN := GKBFKZKGMGET(1
                                  ,RWJUKIIDO_JIDOSEITO.ZOKUGARA1
                                  ,RWJUKIIDO_JIDOSEITO.ZOKUGARA2
                                  ,RWJUKIIDO_JIDOSEITO.ZOKUGARA3
                                  ,RWJUKIIDO_JIDOSEITO.ZOKUGARA4
                                  ,VZOKUGARAMEI1
                                  ,IHERR);
/* 2024/12/26 JIP.KF Del start
              IF IRTN <> 0 THEN
                RAISE EERROR;
              END IF;
   2024/12/26 JIP.KF Del end */
              -- 児童生徒との関係の編集
              IRTN := GKBFKZKGMGET(2
                                  ,RWJUKIIDO_JIDOSEITO.HOGOSYA_ZOKUGARA1
                                  ,RWJUKIIDO_JIDOSEITO.HOGOSYA_ZOKUGARA2
                                  ,RWJUKIIDO_JIDOSEITO.HOGOSYA_ZOKUGARA3
                                  ,RWJUKIIDO_JIDOSEITO.HOGOSYA_ZOKUGARA4
                                  ,VZOKUGARAMEI2
                                  ,IHERR);
/* 2024/12/26 JIP.KF Del start
              IF IRTN <> 0 THEN
                RAISE EERROR;
              END IF;
   2024/12/26 JIP.KF Del end */
              -- 保護者氏名上段、保護者氏名下段の編集
              IF LENGTH(VHOGOSYA_SHIMEI_KANJI) > 15 THEN
                VHOGOSHA_SHIMEI_JODAN := SUBSTR(VHOGOSYA_SHIMEI_KANJI, 1, 15);
                VHOGOSHA_SHIMEI_GEDAN := SUBSTR(VHOGOSYA_SHIMEI_KANJI, 16);
              ELSE
                VHOGOSHA_SHIMEI_JODAN := NULL;
                VHOGOSHA_SHIMEI_GEDAN := VHOGOSYA_SHIMEI_KANJI;
              END IF;
              -- 住所上段、住所下段の編集
              VJYUUSHO := VCHOMEI || VBANCHI || '　' || VKATAGAKI;
              IF LENGTH(VJYUUSHO) > 20 THEN
                VKON_JUSHO_JODAN := SUBSTR(VJYUUSHO,1,20);
                VKON_JUSHO_GEDAN := SUBSTR(VJYUUSHO,21,20);
              ELSE
                VKON_JUSHO_JODAN := VJYUUSHO;
                VKON_JUSHO_GEDAN := NULL;
              END IF;
            -- 8.学齢簿に保護者が設定されていない場合
            ELSE
              -- a. 保護者宛名番号の取得
              -- a-1. 児童が外国人の場合
              IF RATENA_REC.JINKAKU_KBN = 1 THEN
                IRTN := GKBPK00010.FGKJHGS(NSYS_SAKUSEIBI
                                                     ,RWJUKIIDO_JIDOSEITO.KOJIN_NO
                                                     ,NHOGOSYA_KOJIN_NO
                                                     ,VHOGOSYA_SHIMEI_KANJI);
              -- a-2. 児童が外国人でない場合
              ELSE
                IRTN := GKBPK00010.FHOGOSHA(NSYS_SAKUSEIBI
                                           ,RWJUKIIDO_JIDOSEITO.KOJIN_NO
                                           ,NHOGOSYA_KOJIN_NO);
              END IF;
               -- b. 保護者情報が取得できた場合
              IF NHOGOSYA_KOJIN_NO > 0 THEN
                -- b-1. 保護者宛名情報の取得
                IRTN := GAAPK0030.FGETATENA(NHOGOSYA_KOJIN_NO
                                         ,'GKB'
                                         ,NSYS_SAKUSEIBI
                                         ,HOGORATENA_REC
                                         ,HOGORSOFU_REC);
                IF IRTN <> 0 THEN
                  RAISE EERROR;
                END IF;
                -- b-2. 保護者宛名情報の編集
                  -- b-2-1. 保護者氏名かな、保護者氏名漢字、町名、番地、方書の編集
                VHOGOSYA_SHIMEI_KANA  := HOGORATENA_REC.SHIMEI_KANA;
                VHOGOSYA_SHIMEI_KANJI := HOGORATENA_REC.SHIMEI_KANJI;
                VCHOMEI    := HOGORATENA_REC.CHOMEI;
                VBANCHI    := HOGORATENA_REC.BANCHI;
                VKATAGAKI  := HOGORATENA_REC.KATAGAKI;
                -- b-2-2. 保護者判定表示サインの編集
                VHYOJI_SAIN := '*';
                -- b-2-3. 保護者との関係の編集
                VZOKUGARAMEI1 := '子';
                -- b-2-4. 児童生徒との関係の編集
                -- 1.判定用続柄コードの初期化
                NZOKUGARACD := 0;
                -- 2.児童生徒新入学レコード.続柄１=10～29、71、72、89の場合
                IF (RWJUKIIDO_JIDOSEITO.ZOKUGARA1 BETWEEN 10 AND 29) OR RWJUKIIDO_JIDOSEITO.ZOKUGARA1 IN (71,72,89) THEN
                  NZOKUGARACD := 10;
                END IF;
                -- 3.変数.児童生徒との関係システム条件=1の場合
                IF NVALUE = 1 THEN
                  -- 3-1. 下記条件を満たす場合、下記処理を行う。
                  IF (HOGORATENA_REC.ZOKUGARACD1 = 1
                      AND HOGORATENA_REC.ZOKUGARACD2 = 0
                      AND HOGORATENA_REC.ZOKUGARACD3 = 0
                      AND HOGORATENA_REC.ZOKUGARACD4 = 0)
                     AND (NZOKUGARACD = 10
                          AND RWJUKIIDO_JIDOSEITO.ZOKUGARA2 = 0
                          AND RWJUKIIDO_JIDOSEITO.ZOKUGARA3 = 0
                          AND RWJUKIIDO_JIDOSEITO.ZOKUGARA4 = 0) THEN
                    -- 保護者宛名レコード.性別=1の場合
                    IF HOGORATENA_REC.SEIBETSU = 1 THEN
                      VZOKUGARAMEI2 := '父';
                    -- 保護者宛名レコード.性別=2の場合
                    ELSIF HOGORATENA_REC.SEIBETSU = 2 THEN
                      VZOKUGARAMEI2 := '母';
                    ELSE
                      VZOKUGARAMEI2 := NULL;
                    END IF;
                  -- 3-2. 3-1.を満たさない場合
                  ELSE
                    VZOKUGARAMEI2 := NULL;
                  END IF;
                -- 4 3以外の場合
                ELSE
                  IF HOGORATENA_REC.SEIBETSU = 1 THEN
                    VZOKUGARAMEI2 := '父';
                  ELSIF HOGORATENA_REC.SEIBETSU = 2 THEN
                    VZOKUGARAMEI2 := '母';
                  ELSE
                    VZOKUGARAMEI2 := NULL;
                  END IF;
                END IF;
                -- b-2-5. 保護者氏名上段、保護者氏名下段の編集
                IF LENGTH(VHOGOSYA_SHIMEI_KANJI) > 15 THEN
                  VHOGOSHA_SHIMEI_JODAN := VHYOJI_SAIN || SUBSTR(VHOGOSYA_SHIMEI_KANJI, 1, 15);
                  VHOGOSHA_SHIMEI_GEDAN := SUBSTR(VHOGOSYA_SHIMEI_KANJI, 16);
                ELSE
                  VHOGOSHA_SHIMEI_JODAN := VHYOJI_SAIN;
                  VHOGOSHA_SHIMEI_GEDAN := VHOGOSYA_SHIMEI_KANJI;
                END IF;
                -- b-2-6. 住所上段、住所下段の編集
                VJYUUSHO := VCHOMEI || VBANCHI || '　' || VKATAGAKI;
                IF LENGTH(VJYUUSHO) > 20 THEN
                  VKON_JUSHO_JODAN := SUBSTR(VJYUUSHO, 1, 20);
                  VKON_JUSHO_GEDAN := SUBSTR(VJYUUSHO, 21, 20);
                ELSE
                  VKON_JUSHO_JODAN := VJYUUSHO;
                  VKON_JUSHO_GEDAN := NULL;
                END IF;
              -- c. 保護者情報が取得できなかった場合
              ELSE
                VHOGOSYA_SHIMEI_KANA    := NULL;  -- 保護者氏名かな
                VHOGOSYA_SHIMEI_KANJI   := NULL;  -- 保護者氏名漢字
                VCHOMEI                 := NULL;  -- 町名
                VBANCHI                 := NULL;  -- 番地
                VKATAGAKI               := NULL;  -- 方書
                VZOKUGARAMEI1           := NULL;  -- 保護者との関係
                VZOKUGARAMEI2           := NULL;  -- 児童との関係
                VHOGOSHA_SHIMEI_JODAN   := NULL;  -- 保護者氏名上段
                VHOGOSHA_SHIMEI_GEDAN   := NULL;  -- 保護者氏名下段
                VKON_JUSHO_JODAN        := NULL;  -- 住所上段
                VKON_JUSHO_GEDAN        := NULL;  -- 住所下段
              END IF;
            END IF;

            -- 9.他情報の編集
            -- a. 郵便番号の編集
            IF NVL(HOGORATENA_REC.YUBIN_NO, 0) > 0 THEN
              VYUBIN_NO := SUBSTR(HOGORATENA_REC.YUBIN_NO,1,3) || '-' || SUBSTR(HOGORATENA_REC.YUBIN_NO,4);
            ELSE
              VYUBIN_NO := NULL;
            END IF;
            -- b. 記載順位の編集
            NKISAI_JUNI := RWJUKIIDO_JIDOSEITO.KISAI_JUNI;
-- 2024/06/17 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
            -- c.保護者国籍名の編集
            IRTN := GKAFKKKMGET(HOGORATENA_REC.KOKUSEKI_CD,vKOKUMEI_KANA,vKOKUSEKI_MEI,vKOKUMEI_ALP);
            -- d.（保護者）国籍コード、国籍名の編集
            g_nHOGOSHA_KOKUSEKI_CD     := HOGORATENA_REC.KOKUSEKI_CD;
            g_vHOGOSHA_KOKUSEKI_MEI    := vKOKUSEKI_MEI;
-- 2024/06/17 ZCZL.muzl Add end
            -- 10.取得情報のセット
            MJIDO_SINNYUGAKU(NCINT).JIDO_KOJIN_NO          := RWJUKIIDO_JIDOSEITO.KOJIN_NO;
            MJIDO_SINNYUGAKU(NCINT).JIDO_SHIMEI_KANA       := RATENA_REC.SHIMEI_KANA;
            MJIDO_SINNYUGAKU(NCINT).JIDO_SHIMEI_KANJI      := RATENA_REC.SHIMEI_KANJI;
            MJIDO_SINNYUGAKU(NCINT).SEINENGAPI             := RATENA_REC.SEINENGAPI;
            MJIDO_SINNYUGAKU(NCINT).HYOJI_SEINENGAPI       := VHYOJI_SEINENGAPI;
            MJIDO_SINNYUGAKU(NCINT).KANJI_SEINENGAPI       := RATENA_REC.HYOJI_SEINENGAPI;
            MJIDO_SINNYUGAKU(NCINT).SEIBETSU               := RATENA_REC.SEIBETSU;
            MJIDO_SINNYUGAKU(NCINT).HYOJI_SEIBETSU         := VHYOJI_SEIBETSU;
            MJIDO_SINNYUGAKU(NCINT).ZOKUGARAMEI1           := VZOKUGARAMEI1;
            MJIDO_SINNYUGAKU(NCINT).SETAI_NO               := RATENA_REC.SETAI_NO;
            MJIDO_SINNYUGAKU(NCINT).HYOJI_SETAI_NO         := VSETAI_NO;
            MJIDO_SINNYUGAKU(NCINT).HOGOSHA_KOJIN_NO       := NHOGOSYA_KOJIN_NO;
            MJIDO_SINNYUGAKU(NCINT).HOGOSHA_SHIMEI_KANA    := VHOGOSYA_SHIMEI_KANA;
            MJIDO_SINNYUGAKU(NCINT).HOGOSHA_SHIMEI_KANJI   := VHOGOSYA_SHIMEI_KANJI;
            MJIDO_SINNYUGAKU(NCINT).ZOKUGARAMEI2           := VZOKUGARAMEI2;
            MJIDO_SINNYUGAKU(NCINT).GAKUNEN_CD             := RWJUKIIDO_JIDOSEITO.GAKUNEN;
            MJIDO_SINNYUGAKU(NCINT).GAKUNENMEI             := VGAKUNENMEI;
            MJIDO_SINNYUGAKU(NCINT).GAKOKU_CD              := VGAKOKU_CD;
            MJIDO_SINNYUGAKU(NCINT).GAKOKUMEI              := VGAKOKUMEI;
            MJIDO_SINNYUGAKU(NCINT).GYOSEIKU_CD            := RATENA_REC.GYOSEIKU_CD;
            MJIDO_SINNYUGAKU(NCINT).GYOSEIKUMEI            := VGYOSEIKUMEI;
            MJIDO_SINNYUGAKU(NCINT).HAN_CD                 := RATENA_REC.HAN_CD;
            MJIDO_SINNYUGAKU(NCINT).HANMEI                 := VHANMEI;
            MJIDO_SINNYUGAKU(NCINT).SANTEIDANTAI_CD        := RATENA_REC.SANTEIDANTAI_CD;
            MJIDO_SINNYUGAKU(NCINT).SANTEIDANTAIMEI        := VSANTEIDANTAIMEI;
            MJIDO_SINNYUGAKU(NCINT).YUBIN_NO               := VYUBIN_NO;
            MJIDO_SINNYUGAKU(NCINT).CHOMEI                 := VCHOMEI;
            MJIDO_SINNYUGAKU(NCINT).BANCHI                 := VBANCHI;
            MJIDO_SINNYUGAKU(NCINT).KATAGAKI               := VKATAGAKI;
            MJIDO_SINNYUGAKU(NCINT).NENDO                  := VNENDO;
            MJIDO_SINNYUGAKU(NCINT).KAIPEJI_CD             := '　';
            MJIDO_SINNYUGAKU(NCINT).KAIPEJI                := '　';
            MJIDO_SINNYUGAKU(NCINT).SAKUSEIBI              := VHYOJI_SAKUSEIBI;
            MJIDO_SINNYUGAKU(NCINT).RENBAN                 := NRENBAN + 1;
            MJIDO_SINNYUGAKU(NCINT).HYOJI_RENBAN           := VHYOJI_RENBAN;
            MJIDO_SINNYUGAKU(NCINT).HOGOSHA_SHIMEI_JODAN   := VHOGOSHA_SHIMEI_JODAN;
            MJIDO_SINNYUGAKU(NCINT).HOGOSHA_SHIMEI_GEDAN   := VHOGOSHA_SHIMEI_GEDAN;
            MJIDO_SINNYUGAKU(NCINT).KON_JUSHO_JODAN        := VKON_JUSHO_JODAN;
            MJIDO_SINNYUGAKU(NCINT).KON_JUSHO_GEDAN        := VKON_JUSHO_GEDAN;
            MJIDO_SINNYUGAKU(NCINT).JIDO_CHOMEI            := RATENA_REC.CHOMEI;
            MJIDO_SINNYUGAKU(NCINT).JIDO_BANCHI            := RATENA_REC.BANCHI;
            MJIDO_SINNYUGAKU(NCINT).JIDO_KATAGAKI          := RATENA_REC.KATAGAKI;
            MJIDO_SINNYUGAKU(NCINT).JIDO_HONMYO_KANA       := VJIDO_HONMYO_KANA;
            MJIDO_SINNYUGAKU(NCINT).JIDO_HONMYO_KANJI      := VJIDO_HONMYO_KANJI;
            MJIDO_SINNYUGAKU(NCINT).YUHEN_KBN              := RATENA_REC.YUHEN_KBN;
            MJIDO_SINNYUGAKU(NCINT).OAZA_CD                := RATENA_REC.OAZA_CD;
            MJIDO_SINNYUGAKU(NCINT).HONBAN                 := RATENA_REC.HONBAN;
            MJIDO_SINNYUGAKU(NCINT).EDABAN1                := RATENA_REC.EDABAN1;
            MJIDO_SINNYUGAKU(NCINT).EDABAN2                := RATENA_REC.EDABAN2;
            MJIDO_SINNYUGAKU(NCINT).GENZON_KBN             := RATENA_REC.GENZON_KBN;
            MJIDO_SINNYUGAKU(NCINT).KISAI_JUNI             := NKISAI_JUNI;
            MJIDO_SINNYUGAKU(NCINT).GAKO_KBN               := VGAKO_KBN;
            MJIDO_SINNYUGAKU(NCINT).KAGAKUNEN              := '　';
            MJIDO_SINNYUGAKU(NCINT).EDABAN3                := RATENA_REC.EDABAN3;
            MJIDO_SINNYUGAKU(NCINT).GAIKU                  := RATENA_REC.GAIKU;
            MJIDO_SINNYUGAKU(NCINT).TOU                    := RATENA_REC.TOU;
            MJIDO_SINNYUGAKU(NCINT).GOU                    := RATENA_REC.GOU;
            MJIDO_SINNYUGAKU(NCINT).JINKAKU_KBN            := RATENA_REC.JINKAKU_KBN;
-- 2024/06/05 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--             MJIDO_SINNYUGAKU(NCINT).YOCHIEN_CD             := NYOCHIEN_CD;
--             MJIDO_SINNYUGAKU(NCINT).YOCHIEN_MEI            := VYOCHIEN_MEI;
            MJIDO_SINNYUGAKU(NCINT).YOCHIEN_CD             := NULL;
            MJIDO_SINNYUGAKU(NCINT).YOCHIEN_MEI            := NULL;
            MJIDO_SINNYUGAKU(NCINT).JIDO_KOKUSEKI_CD       := g_nJIDO_KOKUSEKI_CD;
            MJIDO_SINNYUGAKU(NCINT).JIDO_KOKUSEKI_MEI      := g_vJIDO_KOKUSEKI_MEI;
            MJIDO_SINNYUGAKU(NCINT).JIDO_YUBIN_NO          := g_vJIDO_YUBIN_NO;
            -- 2025/01/21 JPJYS.SSH Update Start
            --MJIDO_SINNYUGAKU(NCINT).KON_JUSHO_JODAN        := NULL;
            --MJIDO_SINNYUGAKU(NCINT).KON_JUSHO_GEDAN        := NULL;
            -- 2025/01/21 JPJYS.SSH Update End
            MJIDO_SINNYUGAKU(NCINT).HOGOSHA_KOKUSEKI_CD    := g_nHOGOSHA_KOKUSEKI_CD;
            MJIDO_SINNYUGAKU(NCINT).HOGOSHA_KOKUSEKI_MEI   := g_vHOGOSHA_KOKUSEKI_MEI;
-- 2024/06/05 ZCZL.muzl Update end
            -- 11.連番のカウントアップ
            NRENBAN := NRENBAN + 1;
        END LOOP;
        CLOSE CDATA;
        RETURN TRUE;
      EXCEPTION
        WHEN OTHERS THEN
          IF CDATA%ISOPEN THEN
            CLOSE CDATA;
          END IF;
          VLOG := '児童生徒新入学データの作成が異常終了しました。';
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JIDOSEITO_MAKE', 1,SQLCODE, SQLERRM, VLOG, g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
      END FUNC_JIDOSEITO_MAKE;
    ------------------------------------------------------------------------
    --  機能概要      : 児童生徒新入学ワークへのデータ挿入
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    ------------------------------------------------------------------------
      FUNCTION FUNC_JIDOSEITO_INSERT RETURN BOOLEAN
      IS
        RGKBWJIDOSHINNYUGAKU     GKBWJIDOSHINNYUGAKU%ROWTYPE;
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
        vSHIMEI_KANA             NVARCHAR2(100);
        vSHIMEI_KANJI            NVARCHAR2(100);
        vSEINENGAPI              NVARCHAR2(100);
        vSHIMEI_KANA1            NVARCHAR2(100);
        vSHIMEI_KANJI1           NVARCHAR2(100);
        vSEINENGAPI1             NVARCHAR2(100);
        nRTN                     PLS_INTEGER;
-- 2024/06/05 ZCZL.muzl Add end
      BEGIN
        FOR NUM IN 1..MJIDO_SINNYUGAKU.COUNT LOOP
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
          --児童生徒の本名使用制御判定
          nRTN := GKBFKHMCTRL(MJIDO_SINNYUGAKU(NUM).JIDO_KOJIN_NO,g_rJSTP.Chohyoid,0,g_vGKB120_CTL,vSHIMEI_KANA,vSHIMEI_KANJI,vSEINENGAPI);
          --保護者の本名使用制御判定
          nRTN := GKBFKHMCTRL(MJIDO_SINNYUGAKU(NUM).JIDO_KOJIN_NO,g_rJSTP.Chohyoid,1,g_vGKB120_CTL,vSHIMEI_KANA1,vSHIMEI_KANJI1,vSEINENGAPI1);
-- 2024/06/05 ZCZL.muzl Add end

          RGKBWJIDOSHINNYUGAKU.JIDO_KOJIN_NO        := MJIDO_SINNYUGAKU(NUM).JIDO_KOJIN_NO;
-- 2024/06/05 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--           RGKBWJIDOSHINNYUGAKU.JIDO_SHIMEI_KANA     := MJIDO_SINNYUGAKU(NUM).JIDO_SHIMEI_KANA;
--           RGKBWJIDOSHINNYUGAKU.JIDO_SHIMEI_KANJI    := MJIDO_SINNYUGAKU(NUM).JIDO_SHIMEI_KANJI;
          RGKBWJIDOSHINNYUGAKU.JIDO_SHIMEI_KANA     := vSHIMEI_KANA;
          RGKBWJIDOSHINNYUGAKU.JIDO_SHIMEI_KANJI    := vSHIMEI_KANJI;
-- 2024/06/05 ZCZL.muzl Update end
          RGKBWJIDOSHINNYUGAKU.SEINENGAPI           := MJIDO_SINNYUGAKU(NUM).SEINENGAPI;
-- 2024/06/05 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
-- 2025/01/21 JPJYS.SSH Update Start
--          RGKBWJIDOSHINNYUGAKU.HYOJI_SEINENGAPI     := MJIDO_SINNYUGAKU(NUM).HYOJI_SEINENGAPI;
            RGKBWJIDOSHINNYUGAKU.HYOJI_SEINENGAPI     := REPLACE(MJIDO_SINNYUGAKU(NUM).HYOJI_SEINENGAPI,' ','');
--          RGKBWJIDOSHINNYUGAKU.HYOJI_SEINENGAPI     := vSEINENGAPI;
-- 2025/01/21 JPJYS.SSH Update End
          RGKBWJIDOSHINNYUGAKU.KANJI_SEINENGAPI     := MJIDO_SINNYUGAKU(NUM).KANJI_SEINENGAPI;
          RGKBWJIDOSHINNYUGAKU.SEIBETSU             := MJIDO_SINNYUGAKU(NUM).SEIBETSU;
          RGKBWJIDOSHINNYUGAKU.HYOJI_SEIBETSU       := MJIDO_SINNYUGAKU(NUM).HYOJI_SEIBETSU;
          RGKBWJIDOSHINNYUGAKU.ZOKUGARAMEI1         := MJIDO_SINNYUGAKU(NUM).ZOKUGARAMEI1;
          RGKBWJIDOSHINNYUGAKU.SETAI_NO             := MJIDO_SINNYUGAKU(NUM).SETAI_NO;
          RGKBWJIDOSHINNYUGAKU.HYOJI_SETAI_NO       := MJIDO_SINNYUGAKU(NUM).HYOJI_SETAI_NO;
          RGKBWJIDOSHINNYUGAKU.HOGOSHA_KOJIN_NO     := MJIDO_SINNYUGAKU(NUM).HOGOSHA_KOJIN_NO;
-- 2024/06/05 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--           RGKBWJIDOSHINNYUGAKU.HOGOSHA_SHIMEI_KANA  := MJIDO_SINNYUGAKU(NUM).HOGOSHA_SHIMEI_KANA;
--           RGKBWJIDOSHINNYUGAKU.HOGOSHA_SHIMEI_KANJI := MJIDO_SINNYUGAKU(NUM).HOGOSHA_SHIMEI_KANJI;
          RGKBWJIDOSHINNYUGAKU.HOGOSHA_SHIMEI_KANA  := vSHIMEI_KANA1;
          RGKBWJIDOSHINNYUGAKU.HOGOSHA_SHIMEI_KANJI := vSHIMEI_KANJI1;
-- 2024/06/05 ZCZL.muzl Update end
          RGKBWJIDOSHINNYUGAKU.ZOKUGARAMEI2         := MJIDO_SINNYUGAKU(NUM).ZOKUGARAMEI2;
          RGKBWJIDOSHINNYUGAKU.GAKUNEN_CD           := MJIDO_SINNYUGAKU(NUM).GAKUNEN_CD;
          RGKBWJIDOSHINNYUGAKU.GAKUNENMEI           := MJIDO_SINNYUGAKU(NUM).GAKUNENMEI;
          RGKBWJIDOSHINNYUGAKU.GAKOKU_CD            := MJIDO_SINNYUGAKU(NUM).GAKOKU_CD;
          RGKBWJIDOSHINNYUGAKU.GAKOKUMEI            := MJIDO_SINNYUGAKU(NUM).GAKOKUMEI;
          RGKBWJIDOSHINNYUGAKU.GYOSEIKU_CD          := MJIDO_SINNYUGAKU(NUM).GYOSEIKU_CD;
          RGKBWJIDOSHINNYUGAKU.GYOSEIKUMEI          := MJIDO_SINNYUGAKU(NUM).GYOSEIKUMEI;
          RGKBWJIDOSHINNYUGAKU.HAN_CD               := MJIDO_SINNYUGAKU(NUM).HAN_CD;
          RGKBWJIDOSHINNYUGAKU.HANMEI               := MJIDO_SINNYUGAKU(NUM).HANMEI;
          RGKBWJIDOSHINNYUGAKU.SANTEIDANTAI_CD      := MJIDO_SINNYUGAKU(NUM).SANTEIDANTAI_CD;
          RGKBWJIDOSHINNYUGAKU.SANTEIDANTAIMEI      := MJIDO_SINNYUGAKU(NUM).SANTEIDANTAIMEI;
          RGKBWJIDOSHINNYUGAKU.YUBIN_NO             := MJIDO_SINNYUGAKU(NUM).YUBIN_NO;
          RGKBWJIDOSHINNYUGAKU.CHOMEI               := MJIDO_SINNYUGAKU(NUM).CHOMEI;
          RGKBWJIDOSHINNYUGAKU.BANCHI               := MJIDO_SINNYUGAKU(NUM).BANCHI;
          RGKBWJIDOSHINNYUGAKU.KATAGAKI             := MJIDO_SINNYUGAKU(NUM).KATAGAKI;
          RGKBWJIDOSHINNYUGAKU.NENDO                := MJIDO_SINNYUGAKU(NUM).NENDO;
          RGKBWJIDOSHINNYUGAKU.KAIPEJI_CD           := MJIDO_SINNYUGAKU(NUM).KAIPEJI_CD;
          RGKBWJIDOSHINNYUGAKU.KAIPEJI              := MJIDO_SINNYUGAKU(NUM).KAIPEJI;
          RGKBWJIDOSHINNYUGAKU.SAKUSEIBI            := MJIDO_SINNYUGAKU(NUM).SAKUSEIBI;
          RGKBWJIDOSHINNYUGAKU.RENBAN               := MJIDO_SINNYUGAKU(NUM).RENBAN;
          RGKBWJIDOSHINNYUGAKU.HYOJI_RENBAN         := MJIDO_SINNYUGAKU(NUM).HYOJI_RENBAN;
          RGKBWJIDOSHINNYUGAKU.HOGOSHA_SHIMEI_JODAN := MJIDO_SINNYUGAKU(NUM).HOGOSHA_SHIMEI_JODAN;
          RGKBWJIDOSHINNYUGAKU.HOGOSHA_SHIMEI_GEDAN := MJIDO_SINNYUGAKU(NUM).HOGOSHA_SHIMEI_GEDAN;
          RGKBWJIDOSHINNYUGAKU.KON_JUSHO_JODAN      := MJIDO_SINNYUGAKU(NUM).KON_JUSHO_JODAN;
          RGKBWJIDOSHINNYUGAKU.KON_JUSHO_GEDAN      := MJIDO_SINNYUGAKU(NUM).KON_JUSHO_GEDAN;
          RGKBWJIDOSHINNYUGAKU.JIDO_CHOMEI          := MJIDO_SINNYUGAKU(NUM).JIDO_CHOMEI;
          RGKBWJIDOSHINNYUGAKU.JIDO_BANCHI          := MJIDO_SINNYUGAKU(NUM).JIDO_BANCHI;
          RGKBWJIDOSHINNYUGAKU.JIDO_KATAGAKI        := MJIDO_SINNYUGAKU(NUM).JIDO_KATAGAKI;
          RGKBWJIDOSHINNYUGAKU.JIDO_HONMYO_KANA     := MJIDO_SINNYUGAKU(NUM).JIDO_HONMYO_KANA;
          RGKBWJIDOSHINNYUGAKU.JIDO_HONMYO_KANJI    := MJIDO_SINNYUGAKU(NUM).JIDO_HONMYO_KANJI;
          RGKBWJIDOSHINNYUGAKU.YUHEN_KBN            := MJIDO_SINNYUGAKU(NUM).YUHEN_KBN;
          RGKBWJIDOSHINNYUGAKU.OAZA_CD              := MJIDO_SINNYUGAKU(NUM).OAZA_CD;
          RGKBWJIDOSHINNYUGAKU.HONBAN               := MJIDO_SINNYUGAKU(NUM).HONBAN;
          RGKBWJIDOSHINNYUGAKU.EDABAN1              := MJIDO_SINNYUGAKU(NUM).EDABAN1;
          RGKBWJIDOSHINNYUGAKU.EDABAN2              := MJIDO_SINNYUGAKU(NUM).EDABAN2;
          RGKBWJIDOSHINNYUGAKU.GENZON_KBN           := MJIDO_SINNYUGAKU(NUM).GENZON_KBN;
          RGKBWJIDOSHINNYUGAKU.KISAI_JUNI           := MJIDO_SINNYUGAKU(NUM).KISAI_JUNI;
          RGKBWJIDOSHINNYUGAKU.GAKO_KBN             := MJIDO_SINNYUGAKU(NUM).GAKO_KBN;
          RGKBWJIDOSHINNYUGAKU.KAGAKUNEN            := MJIDO_SINNYUGAKU(NUM).KAGAKUNEN;
          RGKBWJIDOSHINNYUGAKU.EDABAN3              := MJIDO_SINNYUGAKU(NUM).EDABAN3;
          RGKBWJIDOSHINNYUGAKU.GAIKU                := MJIDO_SINNYUGAKU(NUM).GAIKU;
          RGKBWJIDOSHINNYUGAKU.TOU                  := MJIDO_SINNYUGAKU(NUM).TOU;
          RGKBWJIDOSHINNYUGAKU.GOU                  := MJIDO_SINNYUGAKU(NUM).GOU;
          RGKBWJIDOSHINNYUGAKU.JINKAKU_KBN          := MJIDO_SINNYUGAKU(NUM).JINKAKU_KBN;
-- 2024/06/06 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--           RGKBWJIDOSHINNYUGAKU.YOCHIEN_CD           := MJIDO_SINNYUGAKU(NUM).YOCHIEN_CD;
--           RGKBWJIDOSHINNYUGAKU.YOCHIEN_MEI          := MJIDO_SINNYUGAKU(NUM).YOCHIEN_MEI;
          RGKBWJIDOSHINNYUGAKU.YOCHIEN_CD           := 0;
          RGKBWJIDOSHINNYUGAKU.YOCHIEN_MEI          := NULL;
          RGKBWJIDOSHINNYUGAKU.TSUSHOMEI_KANA       := NULL;
          RGKBWJIDOSHINNYUGAKU.TSUSHOMEI_KANJI      := NULL;
          RGKBWJIDOSHINNYUGAKU.ATENA_RIREKI_RENBAN  := 0;
          RGKBWJIDOSHINNYUGAKU.JIDO_KOKUSEKI_CD     := MJIDO_SINNYUGAKU(NUM).JIDO_KOKUSEKI_CD;
          RGKBWJIDOSHINNYUGAKU.JIDO_KOKUSEKI_MEI    := MJIDO_SINNYUGAKU(NUM).JIDO_KOKUSEKI_MEI;
          RGKBWJIDOSHINNYUGAKU.JIDO_YUBIN_NO        := MJIDO_SINNYUGAKU(NUM).JIDO_YUBIN_NO;
          RGKBWJIDOSHINNYUGAKU.JIDO_KON_JUSHO       := NULL;
          RGKBWJIDOSHINNYUGAKU.HOGOSHA_KOKUSEKI_CD  := MJIDO_SINNYUGAKU(NUM).HOGOSHA_KOKUSEKI_CD;
          RGKBWJIDOSHINNYUGAKU.HOGOSHA_KOKUSEKI_MEI := MJIDO_SINNYUGAKU(NUM).HOGOSHA_KOKUSEKI_MEI;
-- 2024/06/06 ZCZL.muzl Update end
          INSERT INTO GKBWJIDOSHINNYUGAKU VALUES RGKBWJIDOSHINNYUGAKU;
        END LOOP;
        COMMIT;
        RETURN TRUE;
      EXCEPTION
        WHEN OTHERS THEN
          VLOG := '児童生徒新入学ワークへのデータ挿入が異常終了しました。';
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JIDOSEITO_INSERT', 1,SQLCODE, SQLERRM, VLOG, g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
      END FUNC_JIDOSEITO_INSERT;
    --------------------------------------------------------------
    --  機能概要      : 児童生徒新入学ワークからのデータ取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    --------------------------------------------------------------
      FUNCTION FUNC_JIDOSEITO_GET RETURN BOOLEAN
      IS
        VSORT_JOKEN                     NVARCHAR2(500); -- ソート条件
        VIBREAK_CD                      NVARCHAR2(50);  -- 改ページコード
        VKAIPEJIE                       NVARCHAR2(50);  -- 改頁項目名
        INUM                            PLS_INTEGER;
        VSQL                            VARCHAR2(2000);
        NRENBAN                         NUMBER;
        VKAIPEJI_CD                     NVARCHAR2(500);
        TYPE MR_JIDO_SINNYUGAKU IS RECORD (NENDO                 GKBWJIDOSHINNYUGAKU.NENDO%TYPE
                                          ,KAIPEJI_CD            GKBWJIDOSHINNYUGAKU.KAIPEJI_CD%TYPE
                                          ,KAIPEJI               GKBWJIDOSHINNYUGAKU.KAIPEJI%TYPE
                                          ,SAKUSEIBI             GKBWJIDOSHINNYUGAKU.SAKUSEIBI%TYPE
                                          ,JIDO_SHIMEI_KANA      GKBWJIDOSHINNYUGAKU.JIDO_SHIMEI_KANA%TYPE
                                          ,JIDO_SHIMEI_KANJI     GKBWJIDOSHINNYUGAKU.JIDO_SHIMEI_KANJI%TYPE
                                          ,HYOJI_SEIBETSU        GKBWJIDOSHINNYUGAKU.HYOJI_SEIBETSU%TYPE
                                          ,HOGOSHA_SHIMEI_JODAN  GKBWJIDOSHINNYUGAKU.HOGOSHA_SHIMEI_JODAN%TYPE
                                          ,HOGOSHA_SHIMEI_GEDAN  GKBWJIDOSHINNYUGAKU.HOGOSHA_SHIMEI_GEDAN%TYPE
                                          ,ZOKUGARAMEI1          GKBWJIDOSHINNYUGAKU.ZOKUGARAMEI1%TYPE
                                          ,ZOKUGARAMEI2          GKBWJIDOSHINNYUGAKU.ZOKUGARAMEI2%TYPE
                                          ,HYOJI_SEINENGAPI      GKBWJIDOSHINNYUGAKU.HYOJI_SEINENGAPI%TYPE
                                          ,KANJI_SEINENGAPI      GKBWJIDOSHINNYUGAKU.KANJI_SEINENGAPI%TYPE
                                          ,KON_JUSHO_JODAN       GKBWJIDOSHINNYUGAKU.KON_JUSHO_JODAN%TYPE
                                          ,KON_JUSHO_GEDAN       GKBWJIDOSHINNYUGAKU.KON_JUSHO_GEDAN%TYPE
                                          ,GYOSEIKUMEI           GKBWJIDOSHINNYUGAKU.GYOSEIKUMEI%TYPE
                                          ,SANTEIDANTAIMEI       GKBWJIDOSHINNYUGAKU.SANTEIDANTAIMEI%TYPE
                                          ,JIDO_CHOMEI           GKBWJIDOSHINNYUGAKU.JIDO_CHOMEI%TYPE
                                          ,JIDO_BANCHI           GKBWJIDOSHINNYUGAKU.JIDO_BANCHI%TYPE
                                          ,JIDO_KATAGAKI         GKBWJIDOSHINNYUGAKU.JIDO_KATAGAKI%TYPE
                                          ,HOGOSHA_SHIMEI_KANA   GKBWJIDOSHINNYUGAKU.HOGOSHA_SHIMEI_KANA%TYPE
                                          ,GAKOKUMEI             GKBWJIDOSHINNYUGAKU.GAKOKUMEI%TYPE
                                          ,JIDO_HONMYO_KANA      GKBWJIDOSHINNYUGAKU.JIDO_HONMYO_KANA%TYPE
                                          ,JIDO_HONMYO_KANJI     GKBWJIDOSHINNYUGAKU.JIDO_HONMYO_KANJI%TYPE
                                          ,YUBIN_NO              GKBWJIDOSHINNYUGAKU.YUBIN_NO%TYPE
                                          ,GAKOKU_CD             GKBWJIDOSHINNYUGAKU.GAKOKU_CD%TYPE
                                          ,JIDO_KOJIN_NO         GKBWJIDOSHINNYUGAKU.JIDO_KOJIN_NO%TYPE
                                          ,JINKAKU_KBN           GKBWJIDOSHINNYUGAKU.JINKAKU_KBN%TYPE
                                          ,KAGAKUNEN             GKBWJIDOSHINNYUGAKU.KAGAKUNEN%TYPE
                                          ,YOCHIEN_CD            GKBWJIDOSHINNYUGAKU.YOCHIEN_CD%TYPE
                                          ,YOCHIEN_MEI           GKBWJIDOSHINNYUGAKU.YOCHIEN_MEI%TYPE
-- 2024/06/17 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
--  2024/09/05 ZCZL.WANGMING ADD 0.3.000.001:8月1日認識合わせの横展開
                                          ,JIDO_KON_JUSHO        GKBWJIDOSHINNYUGAKU.JIDO_KON_JUSHO%TYPE
                                          ,GAKUNENMEI            GKBWJIDOSHINNYUGAKU.GAKUNENMEI%TYPE
                                          ,JIDO_KOKUSEKI_MEI     GKBWJIDOSHINNYUGAKU.JIDO_KOKUSEKI_MEI%TYPE
                                          ,JIDO_YUBIN_NO         GKBWJIDOSHINNYUGAKU.JIDO_YUBIN_NO%TYPE
                                          ,HOGOSHA_KOKUSEKI_MEI  GKBWJIDOSHINNYUGAKU.HOGOSHA_KOKUSEKI_MEI%TYPE);
-- 2024/06/17 ZCZL.muzl Add end
        RWJIDO_SINNYUGAKU        MR_JIDO_SINNYUGAKU;
        TYPE CURTYPE IS REF CURSOR;
        CDATA       CURTYPE;
      BEGIN
        INUM := 0;
        NRENBAN := 0;    --  ソート後連番の初期化
        -- 2-10-1. ワーク用配列の初期化
        MJIDO_SINNYUGAKU.DELETE;

        -- ソート条件が1項目目の場合
        IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
          VSORT_JOKEN := ' ORDER BY ' || g_rJSTP.Orderbyclause;
        ELSE
          VSORT_JOKEN := ' ORDER BY GAKO_KBN';
        END IF;

        -- 2-10-3. 改ページコードの作成
         VIBREAK_CD := 'GAKO_KBN || GAKOKU_CD ';

        -- 2-10-4. 改ページの作成
         VKAIPEJIE := ' GAKOKUMEI ';

        -- 2-10-5. 児童生徒新入学データの取得
        VSQL :=         'SELECT NENDO';
        VSQL := VSQL || ',' || VIBREAK_CD || ' KAIPEJI_CD';
        VSQL := VSQL || ',' || VKAIPEJIE  || ' KAIPEJI';
        VSQL := VSQL || '     ,SAKUSEIBI';
-- 2024/06/05 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
-- 2025/01/21 JPJYS.SSH Update Start
--         VSQL := VSQL || '     ,JIDO_SHIMEI_KANA';
--         VSQL := VSQL || '     ,KKAPK0010.FSTRCNV(JIDO_SHIMEI_KANA,2)';
        VSQL := VSQL || '     ,JIDO_SHIMEI_KANA';
-- 2025/01/21 JPJYS.SSH Update End
        VSQL := VSQL || '     ,JIDO_SHIMEI_KANJI';
        VSQL := VSQL || '     ,HYOJI_SEIBETSU';
        VSQL := VSQL || '     ,HOGOSHA_SHIMEI_JODAN';
        VSQL := VSQL || '     ,HOGOSHA_SHIMEI_GEDAN';
        VSQL := VSQL || '     ,ZOKUGARAMEI1';
        VSQL := VSQL || '     ,ZOKUGARAMEI2';
        VSQL := VSQL || '     ,HYOJI_SEINENGAPI';
        VSQL := VSQL || '     ,KANJI_SEINENGAPI';
        VSQL := VSQL || '     ,KON_JUSHO_JODAN';
        VSQL := VSQL || '     ,KON_JUSHO_GEDAN';
        VSQL := VSQL || '     ,GYOSEIKUMEI';
        VSQL := VSQL || '     ,SANTEIDANTAIMEI';
        VSQL := VSQL || '     ,JIDO_CHOMEI';
        VSQL := VSQL || '     ,JIDO_BANCHI';
        VSQL := VSQL || '     ,JIDO_KATAGAKI';
-- 2024/06/18 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
-- 2025/01/21 JPJYS.SSH Update Start
--         VSQL := VSQL || '     ,HOGOSHA_SHIMEI_KANA';
--         VSQL := VSQL || '     ,KKAPK0010.FSTRCNV(HOGOSHA_SHIMEI_KANA,2)';
        VSQL := VSQL || '     ,HOGOSHA_SHIMEI_KANA';
-- 2025/01/21 JPJYS.SSH Update End
        VSQL := VSQL || '     ,GAKOKUMEI';
        VSQL := VSQL || '     ,JIDO_HONMYO_KANA';
        VSQL := VSQL || '     ,JIDO_HONMYO_KANJI';
        VSQL := VSQL || '     ,YUBIN_NO';
        VSQL := VSQL || '     ,GAKOKU_CD';
        VSQL := VSQL || '     ,JIDO_KOJIN_NO';
        VSQL := VSQL || '     ,JINKAKU_KBN';
        VSQL := VSQL || '     ,KAGAKUNEN';
        VSQL := VSQL || '     ,YOCHIEN_CD';
        VSQL := VSQL || '     ,YOCHIEN_MEI';
--2024/11/28 JPJYS.SHAXUE UPDATE 0.3.000.003:IT_GKB_00682の対応 START
        VSQL := VSQL || '     ,JIDO_KON_JUSHO';
        VSQL := VSQL || '     ,GAKUNENMEI';
        VSQL := VSQL || '     ,JIDO_KOKUSEKI_MEI';
        VSQL := VSQL || '     ,JIDO_YUBIN_NO';
        VSQL := VSQL || '     ,HOGOSHA_KOKUSEKI_MEI';
--2024/11/28 JPJYS.SHAXUE UPDATE 0.3.000.003:IT_GKB_00682の対応 END
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
--        VSQL := VSQL || '     ,GAKUNENMEI';
--        VSQL := VSQL || '     ,JIDO_KOKUSEKI_MEI';
--       VSQL := VSQL || '     ,JIDO_YUBIN_NO';
--  2024/09/05 ZCZL.WANGMING ADD 0.3.000.001:8月1日認識合わせの横展開
--        VSQL := VSQL || '     ,JIDO_KON_JUSHO';
--        VSQL := VSQL || '     ,HOGOSHA_KOKUSEKI_MEI';
-- 2024/06/05 ZCZL.muzl Add end
        VSQL := VSQL || ' FROM GKBWJIDOSHINNYUGAKU';
        VSQL := VSQL || VSORT_JOKEN;
        OPEN CDATA FOR VSQL;
        LOOP
          FETCH CDATA INTO RWJIDO_SINNYUGAKU;
          EXIT WHEN CDATA%NOTFOUND;
            INUM := INUM + 1;
            MJIDO_SINNYUGAKU(INUM).NENDO                := RWJIDO_SINNYUGAKU.NENDO;
            MJIDO_SINNYUGAKU(INUM).KAIPEJI_CD           := RWJIDO_SINNYUGAKU.KAIPEJI_CD;
            MJIDO_SINNYUGAKU(INUM).KAIPEJI              := RWJIDO_SINNYUGAKU.KAIPEJI;
            MJIDO_SINNYUGAKU(INUM).SAKUSEIBI            := RWJIDO_SINNYUGAKU.SAKUSEIBI;
            MJIDO_SINNYUGAKU(INUM).JIDO_SHIMEI_KANA     := RWJIDO_SINNYUGAKU.JIDO_SHIMEI_KANA;
            MJIDO_SINNYUGAKU(INUM).JIDO_SHIMEI_KANJI    := RWJIDO_SINNYUGAKU.JIDO_SHIMEI_KANJI;
            MJIDO_SINNYUGAKU(INUM).HYOJI_SEIBETSU       := RWJIDO_SINNYUGAKU.HYOJI_SEIBETSU;
            MJIDO_SINNYUGAKU(INUM).HOGOSHA_SHIMEI_JODAN := RWJIDO_SINNYUGAKU.HOGOSHA_SHIMEI_JODAN;
            MJIDO_SINNYUGAKU(INUM).HOGOSHA_SHIMEI_GEDAN := RWJIDO_SINNYUGAKU.HOGOSHA_SHIMEI_GEDAN;
            MJIDO_SINNYUGAKU(INUM).ZOKUGARAMEI1         := RWJIDO_SINNYUGAKU.ZOKUGARAMEI1;
            MJIDO_SINNYUGAKU(INUM).ZOKUGARAMEI2         := RWJIDO_SINNYUGAKU.ZOKUGARAMEI2;
            MJIDO_SINNYUGAKU(INUM).HYOJI_SEINENGAPI     := RWJIDO_SINNYUGAKU.HYOJI_SEINENGAPI;
            MJIDO_SINNYUGAKU(INUM).KANJI_SEINENGAPI     := RWJIDO_SINNYUGAKU.KANJI_SEINENGAPI;
            MJIDO_SINNYUGAKU(INUM).KON_JUSHO_JODAN      := RWJIDO_SINNYUGAKU.KON_JUSHO_JODAN;
            MJIDO_SINNYUGAKU(INUM).KON_JUSHO_GEDAN      := RWJIDO_SINNYUGAKU.KON_JUSHO_GEDAN;
            MJIDO_SINNYUGAKU(INUM).GYOSEIKUMEI          := RWJIDO_SINNYUGAKU.GYOSEIKUMEI;
            MJIDO_SINNYUGAKU(INUM).SANTEIDANTAIMEI      := RWJIDO_SINNYUGAKU.SANTEIDANTAIMEI;
            MJIDO_SINNYUGAKU(INUM).JIDO_CHOMEI          := RWJIDO_SINNYUGAKU.JIDO_CHOMEI;
            MJIDO_SINNYUGAKU(INUM).JIDO_BANCHI          := RWJIDO_SINNYUGAKU.JIDO_BANCHI;
            MJIDO_SINNYUGAKU(INUM).JIDO_KATAGAKI        := RWJIDO_SINNYUGAKU.JIDO_KATAGAKI;
            MJIDO_SINNYUGAKU(INUM).HOGOSHA_SHIMEI_KANA  := RWJIDO_SINNYUGAKU.HOGOSHA_SHIMEI_KANA;
            MJIDO_SINNYUGAKU(INUM).GAKOKUMEI            := RWJIDO_SINNYUGAKU.GAKOKUMEI;
            MJIDO_SINNYUGAKU(INUM).JIDO_HONMYO_KANA     := RWJIDO_SINNYUGAKU.JIDO_HONMYO_KANA;
            MJIDO_SINNYUGAKU(INUM).JIDO_HONMYO_KANJI    := RWJIDO_SINNYUGAKU.JIDO_HONMYO_KANJI;
            MJIDO_SINNYUGAKU(INUM).YUBIN_NO             := RWJIDO_SINNYUGAKU.YUBIN_NO;
            MJIDO_SINNYUGAKU(INUM).GAKOKU_CD            := RWJIDO_SINNYUGAKU.GAKOKU_CD;
            MJIDO_SINNYUGAKU(INUM).JIDO_KOJIN_NO        := RWJIDO_SINNYUGAKU.JIDO_KOJIN_NO;
            MJIDO_SINNYUGAKU(INUM).JINKAKU_KBN          := RWJIDO_SINNYUGAKU.JINKAKU_KBN;
            MJIDO_SINNYUGAKU(INUM).KAGAKUNEN            := RWJIDO_SINNYUGAKU.KAGAKUNEN;
            MJIDO_SINNYUGAKU(INUM).YOCHIEN_CD           := RWJIDO_SINNYUGAKU.YOCHIEN_CD;
            MJIDO_SINNYUGAKU(INUM).YOCHIEN_MEI          := RWJIDO_SINNYUGAKU.YOCHIEN_MEI;
-- 2024/06/17 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
            MJIDO_SINNYUGAKU(INUM).GAKUNENMEI           := RWJIDO_SINNYUGAKU.GAKUNENMEI;
            MJIDO_SINNYUGAKU(INUM).JIDO_KOKUSEKI_MEI    := RWJIDO_SINNYUGAKU.JIDO_KOKUSEKI_MEI;
            MJIDO_SINNYUGAKU(INUM).JIDO_YUBIN_NO        := RWJIDO_SINNYUGAKU.JIDO_YUBIN_NO;
--  2024/09/05 ZCZL.WANGMING ADD 0.3.000.001:8月1日認識合わせの横展開
            MJIDO_SINNYUGAKU(INUM).JIDO_KON_JUSHO       := RWJIDO_SINNYUGAKU.JIDO_KON_JUSHO;
            MJIDO_SINNYUGAKU(INUM).HOGOSHA_KOKUSEKI_MEI := RWJIDO_SINNYUGAKU.HOGOSHA_KOKUSEKI_MEI;
-- 2024/06/17 ZCZL.muzl Add end

            IF MJIDO_SINNYUGAKU(INUM).KAIPEJI_CD = VKAIPEJI_CD THEN
              NRENBAN := NRENBAN + 1;
              MJIDO_SINNYUGAKU(INUM).RENBAN := NRENBAN;
            ELSE
              NRENBAN := 1;
              MJIDO_SINNYUGAKU(INUM).RENBAN := NRENBAN;
              VKAIPEJI_CD := MJIDO_SINNYUGAKU(INUM).KAIPEJI_CD;
            END IF;

        END LOOP;
        CLOSE CDATA;
        RETURN TRUE;
      EXCEPTION
        WHEN OTHERS THEN
          IF CDATA%ISOPEN THEN
            CLOSE CDATA;
          END IF;
          VLOG := '児童生徒新入学ワークからのデータ取得が異常終了';
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JIDOSEITO_GET', 1,SQLCODE, SQLERRM, VLOG, g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
      END FUNC_JIDOSEITO_GET;
    --------------------------------------------------------------
    --  機能概要      : 児童生徒新入学ワークCSVの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    --------------------------------------------------------------
      FUNCTION FUNC_JIDOSEITOCSV_MAKE RETURN BOOLEAN
      IS
        BRTN              BOOLEAN;
        IMAX              PLS_INTEGER;        -- 児童生徒新入学ワーク用配列の最大値
        IMIN              PLS_INTEGER;        -- 児童生徒新入学ワーク用配列の最小値
        rRECODE           GKBWL120R001%ROWTYPE;
      BEGIN
        -- 2-11-1. 入学予定者名簿の出力件数の初期化
        NJIDOSINNYUGAKU_COUNT := 0;
        -- 2-11-3. 下記処理を児童生徒新入学ワーク用配列長分繰り返す。
        IMAX := MJIDO_SINNYUGAKU.LAST;
        IMIN := MJIDO_SINNYUGAKU.FIRST;
        -- 1.CSVファイル作成（1レコード分）
        FOR IDX IN IMIN..IMAX LOOP
          -- 2.入学予定者名簿の出力件数のカウントアップ
          NJIDOSINNYUGAKU_COUNT := NJIDOSINNYUGAKU_COUNT + 1;
          rRECODE := NULL;
          rRECODE.NO                         :=           NJIDOSINNYUGAKU_COUNT;                                                                                                                  --ソート順
          rRECODE.NENDO                      :=           MJIDO_SINNYUGAKU(IDX).NENDO;                                                                                                            --年度
          rRECODE.KAIPAGE_CD                 :=           MJIDO_SINNYUGAKU(IDX).KAIPEJI_CD;                                                                                                       --ブレークキー
          rRECODE.KAIPAGE_MEI                :=           MJIDO_SINNYUGAKU(IDX).KAIPEJI;                                                                                                          --ブレーク名称
          rRECODE.GENZAIBI                   :=           MJIDO_SINNYUGAKU(IDX).SAKUSEIBI;                                                                                                        --現在日
          rRECODE.NUM                        :=           MJIDO_SINNYUGAKU(IDX).RENBAN;                                                                                                           --No
          rRECODE.SHIMEI_KANA                :=           MJIDO_SINNYUGAKU(IDX).JIDO_SHIMEI_KANA;                                                                                                 --氏名カナ
          rRECODE.SHIMEI                     :=           MJIDO_SINNYUGAKU(IDX).JIDO_SHIMEI_KANJI;                                                                                                --氏名
          rRECODE.SEIBETSU                   :=           MJIDO_SINNYUGAKU(IDX).HYOJI_SEIBETSU;                                                                                                   --性別
          rRECODE.HOGOSHA_SHIMEI_JODAN       :=           MJIDO_SINNYUGAKU(IDX).HOGOSHA_SHIMEI_JODAN;                                                                                             --保護者氏名上
          rRECODE.HOGOSHA_SHIMEI_GEDAN       :=           MJIDO_SINNYUGAKU(IDX).HOGOSHA_SHIMEI_GEDAN;                                                                                             --保護者氏名下
          rRECODE.HOGOSHA_KANKEI             :=           MJIDO_SINNYUGAKU(IDX).ZOKUGARAMEI1;                                                                                                     --保護者との関係
          rRECODE.JIDO_ZOKUGARAMEI           :=           MJIDO_SINNYUGAKU(IDX).ZOKUGARAMEI2;                                                                                                     --児童との関係
          rRECODE.SEINENGAPI                 :=           MJIDO_SINNYUGAKU(IDX).HYOJI_SEINENGAPI;                                                                                                 --生年月日
          rRECODE.KANJI_SEINENGAPI           :=           MJIDO_SINNYUGAKU(IDX).KANJI_SEINENGAPI;                                                                                                 --漢字生年月日
          rRECODE.JUSHO_JODAN                :=           MJIDO_SINNYUGAKU(IDX).KON_JUSHO_JODAN;                                                                                                  --住所上
          rRECODE.JUSHO_GEDAN                :=           MJIDO_SINNYUGAKU(IDX).KON_JUSHO_GEDAN;                                                                                                  --住所下
          rRECODE.GYOSEIKU                   :=           MJIDO_SINNYUGAKU(IDX).GYOSEIKUMEI;                                                                                                      --行政区
          rRECODE.JIDO_JUSHO                 :=           MJIDO_SINNYUGAKU(IDX).SANTEIDANTAIMEI;                                                                                                  --児童住所
-- 2024/06/06 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--          rRECODE.JUSHO1                     :=           MJIDO_SINNYUGAKU(IDX).JIDO_CHOMEI || MJIDO_SINNYUGAKU(IDX).JIDO_BANCHI || '　' || MJIDO_SINNYUGAKU(IDX).JIDO_KATAGAKI;                  --住所１
          rRECODE.JUSHO1                     :=           GAAPK0010.FADDRESSEDIT(1, NULL, MJIDO_SINNYUGAKU(IDX).JIDO_CHOMEI, MJIDO_SINNYUGAKU(IDX).JIDO_BANCHI, MJIDO_SINNYUGAKU(IDX).JIDO_KATAGAKI, NULL);      --住所１
          rRECODE.HOGOSHA_SHIMEI_KANA        :=           MJIDO_SINNYUGAKU(IDX).HOGOSHA_SHIMEI_KANA;                                                                                              --保護者氏名カナ
          rRECODE.HOGOSHA_SHIMEI_KANJI       :=           MJIDO_SINNYUGAKU(IDX).HOGOSHA_SHIMEI_JODAN || MJIDO_SINNYUGAKU(IDX).HOGOSHA_SHIMEI_GEDAN;                                               --保護者氏名
          rRECODE.JUSHO                      :=           MJIDO_SINNYUGAKU(IDX).KON_JUSHO_JODAN || MJIDO_SINNYUGAKU(IDX).KON_JUSHO_GEDAN;                                                         --住所
          rRECODE.SHOGAKKO_MEI               :=           MJIDO_SINNYUGAKU(IDX).GAKOKUMEI;                                                                                                        --小学校名
          rRECODE.JIDO_SHIMEI_KANA           :=           MJIDO_SINNYUGAKU(IDX).JIDO_HONMYO_KANA;                                                                                                 --児童氏名カナ
          rRECODE.JIDO_SHIMEI_KANJI          :=           MJIDO_SINNYUGAKU(IDX).JIDO_HONMYO_KANJI;                                                                                                --児童氏名
          rRECODE.YUBIN_NO                   :=           MJIDO_SINNYUGAKU(IDX).YUBIN_NO;                                                                                                         --郵便番号
          rRECODE.GAKKOKU_CD                 :=           MJIDO_SINNYUGAKU(IDX).GAKOKU_CD;                                                                                                        --学校区コード
          rRECODE.JIDO_KOJIN_NO              :=           MJIDO_SINNYUGAKU(IDX).JIDO_KOJIN_NO;                                                                                                    --児童個人番号
          rRECODE.BIT3SHITAGAKUNEN           :=           MJIDO_SINNYUGAKU(IDX).KAGAKUNEN;                                                                                                        --下学年
          rRECODE.JINKAKU_KBN                :=           MJIDO_SINNYUGAKU(IDX).JINKAKU_KBN;                                                                                                      --人格区分
-- 2024/06/06 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--           rRECODE.YOCHIEN_CD                 :=           MJIDO_SINNYUGAKU(IDX).YOCHIEN_CD;                                                                                                       --幼稚園保育園コード
--           rRECODE.YOCHIEN_MEI                :=           MJIDO_SINNYUGAKU(IDX).YOCHIEN_MEI;                                                                                                      --幼稚園保育園名
          rRECODE.YOCHIEN_CD                 :=           NULL;
          rRECODE.YOCHIEN_MEI                :=           NULL;
          rRECODE.SAKUSEIBI                  :=           MJIDO_SINNYUGAKU(IDX).SAKUSEIBI;
          rRECODE.HOGOSHA_YUBIN_NO           :=           MJIDO_SINNYUGAKU(IDX).YUBIN_NO;
          rRECODE.GAKUNEN                    :=           MJIDO_SINNYUGAKU(IDX).GAKUNENMEI;
          rRECODE.JIDO_KOKUSEKI              :=           MJIDO_SINNYUGAKU(IDX).JIDO_KOKUSEKI_MEI;
          rRECODE.JIDO_YUBIN_NO              :=           MJIDO_SINNYUGAKU(IDX).JIDO_YUBIN_NO;
-- 2025/02/04 JPJYS.WUZHENGDONG Update 0.3.000.004:ST_GKB_TMP00031対応 Start
--        IF RWJUKIIDO_JIDOSEITO.GAKUNEN = 0 THEN
         -- 2025/05/08 CTC.HUANG Update start 1.0.003.000 GK_QA13766_入学予定者名簿の児童生徒の住所欄が空欄を対応
          IF SUBSTR(TRIM(MJIDO_SINNYUGAKU(IDX).GAKUNENMEI), 1, 1) = '0' OR SUBSTR(TRIM(MJIDO_SINNYUGAKU(IDX).GAKUNENMEI), 1, 1) = '6'  THEN
         -- 2025/05/08 CTC.HUANG Update end
-- 2025/02/04 JPJYS.WUZHENGDONG Update 0.3.000.004:ST_GKB_TMP00031対応 End
            rRECODE.JIDO_KON_JUSHO           :=           MJIDO_SINNYUGAKU(IDX).JIDO_CHOMEI || MJIDO_SINNYUGAKU(IDX).JIDO_BANCHI || '　' || MJIDO_SINNYUGAKU(IDX).JIDO_KATAGAKI;
--  2024/09/05 ZCZL.WANGMING ADD START 0.3.000.001:8月1日認識合わせの横展開
          ELSE
            rRECODE.JIDO_KON_JUSHO           :=           MJIDO_SINNYUGAKU(IDX).JIDO_KON_JUSHO;
--  2024/09/05 ZCZL.WANGMING ADD END
          END IF;
          rRECODE.HOGOSHA_KOKUSEKI           :=           MJIDO_SINNYUGAKU(IDX).HOGOSHA_KOKUSEKI_MEI;
-- 2024/06/06 ZCZL.muzl Update end
          rRECODE.BREAK_NO                   :=           NULL;                                                                                                                                   --改ページキー
          rRECODE.WSNUM                      :=           g_sWSNUM;                                                                                                                               --端末番号
          rRECODE.BATCHKBN                   :=           c_BATCH;                                                                                                                                --即時バッチ区分
          rRECODE.JOBNUM                     :=           g_nJOBNUM;                                                                                                                              --ジョブNO
          INSERT INTO GKBWL120R001 VALUES rRECODE;
        END LOOP;
        RETURN TRUE;
      EXCEPTION
        WHEN OTHERS THEN
         -- 2025/05/08 CTC.HUANG Update start 1.0.003.000 GK_QA13756_入力予定者名簿作成、中学校異常終了を対応
         IF IMAX IS NULL THEN
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JIDOSEITOCSV_MAKE', 0,0, 0, 'ジョブID ' || g_nJOBNUM || '抽出件数が0件です。処理終了', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN TRUE;
         ELSE
         -- 2025/05/08 CTC.HUANG Update end
          VLOG := '児童生徒新入学ワークCSVの作成が異常終了しました。';
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_JIDOSEITOCSV_MAKE', 1,SQLCODE, SQLERRM, VLOG, g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
         -- 2025/05/08 CTC.HUANG Update start 1.0.003.000 GK_QA13756_入力予定者名簿作成、中学校異常終了を対応
         END IF;
         -- 2025/05/08 CTC.HUANG Update end
      END FUNC_JIDOSEITOCSV_MAKE;
    ---------------------------------------------------------------
    --  機能概要      : 件数表の作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    ---------------------------------------------------------------
      FUNCTION FUNC_KENSUUTEPURU_MAKE RETURN BOOLEAN
      IS
        BRTN        BOOLEAN;
        IMAX        PLS_INTEGER;
        IMIN        PLS_INTEGER;
        NCOUNT      PLS_INTEGER;
      BEGIN
        -- 2-12-2. 対象児童生徒数の作成
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NCINT,'入力　入学予定者の学齢簿情報入力件数',1);
        -- 2-12-3. 変数.処理対象学校区分=0 または 1の場合
        IF NTAISHOGAKO_KBN = 0 OR NTAISHOGAKO_KBN = 1 THEN
          -- 1.小学校入学児童生徒数の作成
          g_nINDEX := g_nINDEX + 1;
          g_oKENSU_LIST.EXTEND(1);
          g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NSHOGAKO_CNT,'処理　小学校入学予定の件数',0);
          -- 2.各幼稚園・保育園の児童生徒数の作成
          NCOUNT := MYOCHIEN_RECORD.COUNT;
          IF NCOUNT <> 0 THEN
            IMAX   := MYOCHIEN_RECORD.LAST;
            IMIN   := MYOCHIEN_RECORD.FIRST;
            FOR IDX IN IMIN..IMAX LOOP
              g_nINDEX := g_nINDEX + 1;
              g_oKENSU_LIST.EXTEND(1);
              g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(MYOCHIEN_RECORD(IDX).YOCHIEN_KAZU,'処理　' || MYOCHIEN_RECORD(IDX).YOCHIEN_MEI || 'の件数',0);
            END LOOP;
          END IF;
          -- 3.変数.幼稚園・保育園不明児童生徒数<>0の場合
          IF NYOCHIENFUMEI_CNT <> 0 THEN
            g_nINDEX := g_nINDEX + 1;
            g_oKENSU_LIST.EXTEND(1);
            g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NYOCHIENFUMEI_CNT,'処理　幼稚園・保育園不明の件数',0);
          END IF;
        END IF;
        -- 2-12-4. 変数.処理対象学校区分=0 または 2の場合
        IF NTAISHOGAKO_KBN = 0 OR NTAISHOGAKO_KBN = 2 THEN
          -- 1.中学校入学児童生徒数の作成
          g_nINDEX := g_nINDEX + 1;
          g_oKENSU_LIST.EXTEND(1);
          g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NCHUGAKO_CNT,'処理　中学校入学予定の件数',0);
        END IF;
        -- 2-12-5. 入学予定者名簿の出力件数の作成
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NJIDOSINNYUGAKU_COUNT,'出力　入学予定者名簿の出力件数',2);

        RETURN TRUE;
      EXCEPTION
        WHEN OTHERS THEN
          VLOG := '件数表の作成が異常終了しました。';
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_KENSUUTEPURU_MAKE', 1,SQLCODE, SQLERRM, VLOG, g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
      END FUNC_KENSUUTEPURU_MAKE;

    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        VcmbGakkoKbn          DBMS_UTILITY.MAXNAME_ARRAY;
        --  2024/10/28 ZCZL.HAODAPENG ADD 0.3.000.002:学校コードリスト仕様変更の対応
        objShogakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
        objChugakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
        --  2024/10/28 ZCZL.HAODAPENG ADD 0.3.000.002:学校コードリスト仕様変更の対応
    BEGIN
        --入学年度
        g_vJYOUKEN01 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtNendo');
        --学校区分
        VcmbGakkoKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbGakkoKbn');
        g_vJYOUKEN02 := VcmbGakkoKbn(1);
        --  2024/10/28 ZCZL.HAODAPENG UPDATE START 0.3.000.002:学校コードリスト仕様変更の対応
        --小学校コード
        --g_vJYOUKEN03 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtShogakkoCd');
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtShogakkoCd');
        g_vJYOUKEN03 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShogakkoCd',0, objShogakkoCd);
        --中学校コード
        --g_vJYOUKEN04 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtChugakkoCd');
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtChugakkoCd');
        g_vJYOUKEN04 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtChugakkoCd',0, objChugakkoCd);
        --  2024/10/28 ZCZL.HAODAPENG UPDATE END

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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
        --  2024/10/28 ZCZL.HAODAPENG ADD START 0.3.000.002:学校コードリスト仕様変更の対応
        aGAKKOCD_CHK_LST         KKBPK5551.tySPLIT_tbl;   --変数.学校リスト
        vGAKOUKBN          NUMBER;                  --学校から学校区別の取得
        --  2024/10/28 ZCZL.HAODAPENG ADD END
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

        --各変数の初期化
        VMSG := '';
        NERR := 0;
        --入学年度のチェック
        NRTN := FUNC_NYUGAKUNENDO_CHK;

--  2024/10/28 ZCZL.HAODAPENG UPDATE START 0.3.000.002:学校コードリスト仕様変更の対応
        --学校区分と小学校コードの関連チェック
        --NRTN := FUNC_SHOGAKU_CHK;

        --学校区分と中学校コードの関連チェック
        --NRTN := FUNC_CHUGAKU_CHK;

        --学校区分と小学校コードの関連チェック
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_vJYOUKEN03, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            --学校区分と選択された学校の関係性チェック
            IF g_vJYOUKEN02 <> '0' THEN
              IF TO_NUMBER(g_vJYOUKEN02) <> vGAKOUKBN THEN
                IF VMSG IS NOT NULL THEN
                  VMSG := VMSG || ';' || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                ELSE
                  VMSG := VMSG || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                END IF;
              END IF;
            END IF;
        END LOOP;
        --学校区分と中学校コードの関連チェック
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_vJYOUKEN04, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            --学校区分と選択された学校の関係性チェック
            IF g_vJYOUKEN02 <> '0' THEN
              IF TO_NUMBER(g_vJYOUKEN02) <> vGAKOUKBN THEN
                IF VMSG IS NOT NULL THEN
                  VMSG := VMSG || ';' || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                ELSE
                  VMSG := VMSG || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                END IF;
              END IF;
            END IF;
        END LOOP;
--  2024/10/28 ZCZL.HAODAPENG UPDATE END
        --エラーメッセージのセット
        -- 文字末でセミコロンを連接する
        IF LENGTH(VMSG) > 0 THEN
          o_vRESULT := VMSG || ';';
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;          --戻り値
        eEXCEPTION       EXCEPTION;
        TACONSPRM        A_CONS_PRM;       --戻るパラメータ配列
        NLENGTH          NUMBER;           --配列件数
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
        o_tITEM          A_CONS_PRM;
        g_aSHIMEIPRM     A_CONS_PRM;
-- 2024/06/05 ZCZL.muzl Add end
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        DELETE FROM GKBWL120R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;

        -- 2-2. 各変数へ取得したバッチ処理条件のセット
        -- 2-2-1. 入学年度
        VNENDO := KKAPK0020.FNENDOEDIT(0,
                                        TO_NUMBER(g_vJYOUKEN01),
                                        3);
        -- 2-2-2. 処理対象学校区分
        NTAISHOGAKO_KBN := TO_NUMBER(g_vJYOUKEN02);
        -- 2-2-3. 小学校コード
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
--        IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN03,VSYOGAKO_CD);
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN03, VSYOGAKO_CD);
        IF NOT bRTN THEN
          RETURN FALSE;
        END IF;
-- 2024/06/05 ZCZL.muzl Add end
        -- 2-2-4. 中学校コード
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
--        IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN04,VTYUGAKO_CD);
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN04, VTYUGAKO_CD);
        IF NOT bRTN THEN
          RETURN FALSE;
        END IF;
-- 2024/06/05 ZCZL.muzl Add end

        -- 2-6. 児童生徒新入学ワークの初期化
        IRTN := KKAPK3000.FTRUNCATE(C_TABLE,VSQLERRM);
        IF IRTN <> 0 THEN
          VLOG := '児童生徒新入学ワークの初期化が異常終了しました。';
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', VLOG, g_sTANTOCODE, g_sWSNUM, 1);
          RAISE EERROR;
        END IF;

        -- 2-7. システム条件の取得
          --2-7-1. システム条件から「児童との関係の判定条件」のシステム条件値を取得する。
        BEGIN
          IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                        'SYSTEM',   --制御コンスタントコード
                                        120,        --制御コンスタント連番
                                        TACONSPRM,
                                        NLENGTH);
          IF NLENGTH <> 0 THEN
          --レコードが取得できた場合
            NVALUE := TACONSPRM(1);
          ELSE
          --レコードが取得できない場合
            NVALUE := 0;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            NVALUE := 0;
        END;
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
          --2-7-2. システム制御設定を取得する。
          -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する
        o_tITEM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB','SHIMEIJKN_CHOHYO','0000',1,o_tITEM);
        IF nRTN = 0 THEN
          FOR i IN 1..o_tITEM.COUNT LOOP
            IF o_tITEM(i) = 'GKB120R001' THEN
              g_nGKB120_INDEX := i;
            END IF;
          END LOOP;
        END IF;
        --本名・通称名　出力制御
        g_aSHIMEIPRM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB','EQSHIMEI','0000',0,g_aSHIMEIPRM);
        IF nRTN = 0 THEN
          g_vGKB120_CTL := g_aSHIMEIPRM(g_nGKB120_INDEX);
        END IF;
-- 2024/06/05 ZCZL.muzl Add end
        -- 2-8. 児童生徒新入学データの作成
        BRTN := FUNC_JIDOSEITO_MAKE;
        IF NOT BRTN THEN
          RAISE EERROR;
        END IF;

        -- 2-9. 児童生徒新入学ワークへのデータ挿入
        BRTN := FUNC_JIDOSEITO_INSERT;
        IF NOT BRTN THEN
          RAISE EERROR;
        END IF;

        -- 2-10. 児童生徒新入学ワークからのデータ取得
        BRTN := FUNC_JIDOSEITO_GET;
        IF NOT BRTN THEN
          RAISE EERROR;
        END IF;

        -- 2-11. 児童生徒新入学ワークCSVの作成
        BRTN := FUNC_JIDOSEITOCSV_MAKE;
        IF NOT BRTN THEN
          RAISE EERROR;
        END IF;

        --  2-12. 件数表の作成
        BRTN := FUNC_KENSUUTEPURU_MAKE;
        IF NOT BRTN THEN
          RAISE EERROR;
        END IF;

        --帳票出力CSVの作成
        CASE g_rJSTP.Chohyoid
          WHEN 'GKB120R001' THEN
            bRTN := FUNC_B11CSV('GKBWL120R001');
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/02
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
END GKBPB00130;
/