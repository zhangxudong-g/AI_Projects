CREATE OR REPLACE PACKAGE BODY GKBPB00610
--1.0.451.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 入学予定通知書
--  機能概要      : 年度に入学が予定されている児童生徒の入学予定通知書を出力する処理を追加する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.lujian   2024/07/08
--------------------------------------------------------
--  変更履歴
--  2024/08/30 ZCZL.xiaoya Add 0.3.000.001:IT_GKB_00075対応
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--  2024/10/21 ZCZL.WANGMING UPDATE 0.3.000.004:　IT_GKB_00341横展開対応
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00286横展開対応
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00426対応
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/14 YAMANI.SASAKI UPDATE 0.3.000.007:IT_GKB_00557、IT_GKB_00558、仕様変更　IT_GKB_00565対応
--  2024/11/14 YAMANI.SASAKI UPDATE 0.3.000.008:IT_GKB_00573対応
--  2024/11/15 YAMANI.SASAKI UPDATE 0.3.000.009:IT_GKB_00576、IT_GKB_00577、IT_GKB_00579対応、仕様変更　IT_GKB_00578対応
--  2024/11/16 YAMANI.SASAKI UPDATE 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--  2024/11/18 YAMANI.SASAKI UPDATE 0.3.000.011:仕様変更　ID：IT_GKB_00614、IT_GKB_00615　不具合　ID：IT_GKB_00616対応
--  2024/11/19 YAMANI.SASAKI UPDATE 0.3.000.012:仕様変更　ID：IT_GKB_00623、IT_GKB_00624対応
--  2024/11/21 ZCZL.ZHANGLEI UPDATE 0.3.000.013:IT_GKC_00329横展開対応
--  2025/01/07 JPJYS.GAOJIAN UPDATE 0.3.000.012:品質強化IT_GKB_10155対応
--  2025/01/13 JPJYS.GONGYANYAN UPDATE 0.3.000.013:品質強化IT_GKB_10243対応
--  2025/01/15 JPJYS.LIJINGHUI UPDATE 0.3.000.016:学校区マスタ対応
--  2025/06/06 CTC.LIUJUNHAO UPDATE 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
--  2025/07/01 CTC.GL UPDATE 1.0.010.001:GKB_QA17602対応
--  2026/01/05 CTC.HJF UPDATE 1.0.451.000:GKB_QA25074対応
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
    g_sSEYIGYO                    NVARCHAR2(1000);             --入学予定通知書一覧表_出力制御
    g_vMSG                        NVARCHAR2(4000);
    --画面入力条件
    g_txtYear                     NVARCHAR2(1000);             --対象年度
    g_txtGakoKb                   NVARCHAR2(1000);             --学校区分
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
    --g_txtSyougakoCd               NVARCHAR2(1000);             --小学校コード
    --g_txtCyugakoCd                NVARCHAR2(1000);             --中成学校コード
    g_txtSyougakoCd               NVARCHAR2(3000);             --小学校コード
    g_txtCyugakoCd                NVARCHAR2(3000);             --中成学校コード
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
    g_txtSofuSaki                 NVARCHAR2(1000);             --送付先
    g_txtHakkoYmd                 NVARCHAR2(1000);             --発行年月日
    g_txtShinenSochid             NVARCHAR2(1000);             --支援措置対象者マスク
--  2026/01/05 CTC.HJF UPDATE START 1.0.451.000:GKB_QA25074対応
    --g_sHakkoRireki                NVARCHAR2(1000);             --発行履歴
--  2026/01/05 CTC.HJF UPDATE END
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
    --g_sSYOUGAKOCD_ED              NVARCHAR2(1000);             --小学校コード（編集後）
    --g_sCYUGAKOCD_ED               NVARCHAR2(1000);             --中成学校コード（編集後）
    g_sSYOUGAKOCD_ED              NVARCHAR2(3000);             --小学校コード（編集後）
    g_sCYUGAKOCD_ED               NVARCHAR2(3000);             --中成学校コード（編集後）
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
    g_nTxtYear                    PLS_INTEGER;                 --対象年度
    g_nTxtGakoKb                  PLS_INTEGER;                 --学校区分
    g_nTxtSofuSaki                PLS_INTEGER;                 --送付先
    g_nTxtHakkoYmd                PLS_INTEGER;                 --発行年月日
    g_nTxtShinenSochid            PLS_INTEGER;                 --支援措置対象者マスク
    g_rBUNNUMSRCINF                KKAPK0040.MR_BUNNUMSRCINF;     --文書番号情報（構造体）
    g_rBUNNUMEDITKEKA              KKAPK0040.MR_BUNNUMEDITKEKA;   --文書番号編集結果
    g_rBUNNUM                      NVARCHAR2(100);                --文書番号
    g_nKOIN_SHORYAKU               GKBTTSUCHISHOKANRI.KOIN_SHORYAKU%TYPE;
    g_vKOIN_CHUSHAKU               GKBTTSUCHISHOKANRI.KOIN_CHUSHAKU%TYPE;
    g_vTSUCHIBUN                   GKBTTSUCHISHOKANRI.TSUCHIBUN%TYPE;
    g_vTOKKIJIKO                   GKBTTSUCHISHOKANRI.TOKKIJIKO%TYPE;
    g_vCHOHYO_MEI                  GKBTTSUCHISHOKANRI.CHOHYO_MEI%TYPE;
    g_vYOSHIKI_BANGO_SETTOGO       GKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO%TYPE;
    g_nYOSHIKI_BANGO               GKBTTSUCHISHOKANRI.YOSHIKI_BANGO%TYPE;
    g_vYOSHIKI_BANGO_SETSUBIGO     GKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO%TYPE;
    o_nDAIRIKBN                    NVARCHAR2(1000);             --認証者の本人・代理区分
    o_vKATAGAKI1                   NVARCHAR2(1000);             --認証者の肩書上段
    o_vKATAGAKI2                   NVARCHAR2(1000);             --認証者の肩書下段
    o_vSHIMEI                      NVARCHAR2(1000);             --認証者の氏名
    o_vKOINFILENAME                NVARCHAR2(1000);             --公印ファイル名
    g_vTOIAWASESAKI1               NVARCHAR2(1000);             --お問い合わせ先1
    g_vTOIAWASESAKI2               NVARCHAR2(1000);             --お問い合わせ先2
    g_vTOIAWASESAKI3               NVARCHAR2(1000);             --お問い合わせ先3
    TYPE MR_BUNNUM IS RECORD(
        KOJINNUM                           NUMBER,                          --宛名番号
        BUNNUM_ANNAISHOU                   NVARCHAR2(1000)                  --文書番号_案内書
    );
    TYPE MR_BUNNUM_REC IS TABLE OF MR_BUNNUM INDEX BY BINARY_INTEGER;
    g_rHOKANBUNNUM                  MR_BUNNUM_REC;                          --文書番号保管
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
    g_BRTNSEINENGAPI                  BOOLEAN;
    g_IWAREKIHIZUKE                   PLS_INTEGER;
    g_VEDIT_GYYMMDD1                  NVARCHAR2(20);
    g_VEDIT_GYYMMDD2                  NVARCHAR2(20);
    g_VEDIT_GYYMMDD3                  NVARCHAR2(20);
    g_VKJ_GENGO                       NVARCHAR2(20);
    g_VKG_GENGO                       NVARCHAR2(20);
    g_IWAREKI_YY                      PLS_INTEGER;
    g_ISEIREKI_YYYY                   PLS_INTEGER;
    g_IWAREKI_GYYMM                   PLS_INTEGER;
    g_IMM                             PLS_INTEGER;
    g_IDD                             PLS_INTEGER;
    g_IOWAREKIHIZUKE                  PLS_INTEGER;
    g_ISEIREKIHIZUKE                  PLS_INTEGER;
--  2024/11/16 YAMANI.SASAKI UPDATE END
--  2026/01/05 CTC.HJF UPDATE START 1.0.451.000:GKB_QA25074対応
    g_TXTHAKKORIREKI              NVARCHAR2(500); --発行履歴
--  2026/01/05 CTC.HJF UPDATE END
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
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
--  2024/11/14 ZCZL.WANGYUNING ADD 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        nGAKOUCD_TMP  NUMBER; --学校コード
    BEGIN
        -- 入力引数を分解して配列にセットする
        -- 引数の学校コード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
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
            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
-- 2024/08/30 ZCZL.xiaoya Add START 0.3.000.001:IT_GKB_00075対応
      txtGakoKb1 DBMS_UTILITY.MAXNAME_ARRAY;
      txtSofuSaki1 DBMS_UTILITY.MAXNAME_ARRAY;
      txtShinenSochid1 DBMS_UTILITY.MAXNAME_ARRAY;
-- 2024/08/30 ZCZL.xiaoya Add END
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
      objShogakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
      objChugakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/14 ZCZL.WANGYUNING ADD END
--  2026/01/05 CTC.HJF UPDATE START 1.0.451.000:GKB_QA25074対応
      objsHakkoRireki    DBMS_UTILITY.MAXNAME_ARRAY;
--  2026/01/05 CTC.HJF UPDATE END
    BEGIN
        g_txtYear := KKBPK5551.GETPARMS(g_nJOBNUM,'txtYear');                 --対象年度
-- 2024/08/30 ZCZL.xiaoya UPDATE START 0.3.000.001:IT_GKB_00075対応
--        g_txtGakoKb := KKBPK5551.GETPARMS(g_nJOBNUM,'txtGakoKb');             --学校区分
        txtGakoKb1 := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtGakoKb');        --学校区分
        g_txtGakoKb := txtGakoKb1(1);
-- 2024/08/30 ZCZL.xiaoya UPDATE END
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_txtSyougakoCd := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSyougakoCd');     --小学校コード
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtSyougakoCd');
        g_txtSyougakoCd := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtSyougakoCd',0, objShogakkoCd);--小学校コード
        --g_txtCyugakoCd := KKBPK5551.GETPARMS(g_nJOBNUM,'txtCyugakoCd');       --中学校コード
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtCyugakoCd');
        g_txtCyugakoCd := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtCyugakoCd',0, objChugakkoCd);--中学校コード
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
-- 2024/08/30 ZCZL.xiaoya UPDATE START 0.3.000.001:IT_GKB_00075対応
--        g_txtSofuSaki := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSofuSaki');         --送付先
        txtSofuSaki1 := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtSofuSaki');    --送付先
        g_txtSofuSaki := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtSofuSaki', 0, txtSofuSaki1);
-- 2024/08/30 ZCZL.xiaoya UPDATE END
        g_txtHakkoYmd := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHakkoYmd');         --発行年月日
-- 2024/08/30 ZCZL.xiaoya UPDATE START 0.3.000.001:IT_GKB_00075対応
--        g_txtShinenSochid := KKBPK5551.GETPARMS(g_nJOBNUM,'txtShinenSochid'); --支援措置対象者マスク
        txtShinenSochid1 := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtShinenSochid'); --支援措置対象者マスク
        g_txtShinenSochid := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtShinenSochid', 0, txtShinenSochid1);
-- 2024/08/30 ZCZL.xiaoya UPDATE END
--  2026/01/05 CTC.HJF UPDATE START 1.0.451.000:GKB_QA25074対応
        --g_sHakkoRireki := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHakkoRireki');     --発行履歴
        objsHakkoRireki := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtHakkoRireki');
        g_TXTHAKKORIREKI := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtHakkoRireki', 0, objsHakkoRireki);
--  2026/01/05 CTC.HJF UPDATE END
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN       BOOLEAN;          --戻り値
        nRTN       NUMBER;          --戻り値
        nMSG       NVARCHAR2(4000);  --エラーメッセージ
        o_sSEIREKINENDO NVARCHAR2(100);
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        aGAKKOCD_CHK_LST         KKBPK5551.tySPLIT_tbl;   --変数.学校リスト
        vGAKOUKBN          NUMBER;                  --学校から学校区別の取得
--  2024/11/14 ZCZL.WANGYUNING ADD END
    BEGIN
        --ジョブナンバーをセット

        g_nJOBNUM := i_nJOBNUM;

        --バッチ初期処理
        bRTN := FUNC_B00INIT;
        IF NOT bRTN THEN
            o_vRESULT := g_sMESSAGE;
            RETURN;
        END IF;
-- 2024/08/30 ZCZL.xiaoya Add 0.3.000.001:IT_GKB_00075対応
        g_vMSG := '';
        -- バッチ入力値取得
        bRTN := FUNC_B01PINIT;
        --入力値チェック
        nRTN := KKAPK0020.FNendoWS(g_txtYear, o_sSEIREKINENDO);  --処理条件.年度
        IF nRTN <> 0 THEN
            g_vMSG := g_vMSG || g_sGYOUMUCODE || ',99999, 対象年度が正しくありません。,;';
        END IF;
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        --小学校コードのチェック
        --nRTN := GKBPK00010.FGCODCHK( g_txtSyougakoCd );
        --IF nRTN <> 0 THEN
        --    g_vMSG := g_vMSG || g_sGYOUMUCODE || ',99999,小学校コードが正しくありません。,;' ;
        --END IF;
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_txtSyougakoCd, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            --学校区分と選択された学校の関係性チェック
            IF g_txtGakoKb <> '0' THEN
              IF TO_NUMBER(g_txtGakoKb) <> vGAKOUKBN THEN
                IF g_vMSG IS NOT NULL THEN
                  g_vMSG := g_vMSG || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                ELSE
                  g_vMSG := g_vMSG || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                END IF;
              END IF;
            END IF;
        END LOOP;
        --中学校コードのチェック
        --nRTN := GKBPK00010.FGCODCHK( g_txtCyugakoCd ) ;
        --IF nRTN <> 0 THEN
        --    g_vMSG := g_vMSG || g_sGYOUMUCODE || ',99999,中学校コードが正しくありません。,;' ;
        --END IF;
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_txtCyugakoCd, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            --学校区分と選択された学校の関係性チェック
            IF g_txtGakoKb <> '0' THEN
              IF TO_NUMBER(g_txtGakoKb) <> vGAKOUKBN THEN
                IF g_vMSG IS NOT NULL THEN
                  g_vMSG := g_vMSG || ';' || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                ELSE
                  g_vMSG := g_vMSG || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                END IF;
              END IF;
            END IF;
        END LOOP;
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
        --処理条件.発行年月日
--        bRTN := KKAPK0020.FISDATEW(g_txtHakkoYmd);
--        IF NOT bRTN THEN
--          g_vMSG  := g_vMSG || g_sGYOUMUCODE || ',99999,発行年月日が正しくありません。,;';
--        END IF;
--        IF KKAPK0010.FISNUMERIC(g_txtHakkoYmd) THEN
--          g_vMSG  := g_vMSG || g_sGYOUMUCODE || ',99999,発行年月日が正しくありません。,;';
--        END IF;
        bRTN := KKAPK0010.FISNUMERIC( g_txtHakkoYmd );
        IF bRTN = FALSE THEN
          g_vMSG := g_vMSG || g_sGYOUMUCODE || ',99999,発行年月日が正しくありません。,;' ;
        ELSE
          -- 発行年月日の妥当性チェック
          bRTN := KKAPK0020.FISDATEW( g_txtHakkoYmd );
          IF bRTN = FALSE THEN
            g_vMSG := g_vMSG || g_sGYOUMUCODE || ',99999,発行年月日が正しくありません。,;' ;
          END IF;
        END IF;
--  2024/10/11 ZCZL.WANGMING UPDATE END
        o_vRESULT := g_vMSG;
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET
        RETURN BOOLEAN
    IS
        ERR               EXCEPTION;
    BEGIN
      g_nTxtYear         := KKAPK0020.FNENDO(g_txtYear,1);                           --対象年度を数値変換
      g_nTxtGakoKb       := TO_NUMBER(g_txtGakoKb);                         --学校区分を数値変換
      g_nTxtSofuSaki     := TO_NUMBER(g_txtSofuSaki);                       --送付先を数値変換
      g_nTxtHakkoYmd := KKAPK0020.FNENDOHENKAN(g_txtHakkoYmd);              --発行年月日
      g_nTxtShinenSochid := TO_NUMBER(g_txtShinenSochid);                   --支援措置対象者マスクを数値変換
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
    --------------------------------------------------------
    FUNCTION FUNC_INIT
        RETURN BOOLEAN
    IS
        bRTN                    BOOLEAN;                    --戻り値
        nRTN                    PLS_INTEGER;                --戻る値
        aITEM                   A_CONS_PRM;                 --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        sINDEXNO                NUMBER;                     --変数.入学予定通知書一覧表_インデックス番号
        SCHOOLKBN               PLS_INTEGER;
    BEGIN
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00426対応
        IF g_rJSTP.CHOHYOID = 'GKB701R001' THEN
          --文書番号情報を取得
          bRTN := KKBPK5551.FJBNSGet (g_nJOBNUM, g_rJSTP.STEPSEQ, g_rBUNNUMSRCINF);
          --文書番号編集結果を取得
          g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
          --変数.文書番号_入学予定
          g_rBUNNUM := g_rBUNNUMEDITKEKA.NUM;
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00426対応
        END IF;
        --公印取得
        bRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE, 0),
                            g_sWSNUM,
                            SYSDATE,
                            o_nDAIRIKBN,
                            o_vKATAGAKI1,
                            o_vKATAGAKI2,
                            o_vSHIMEI,
                            o_vKOINFILENAME
        );

        IF g_txtGakoKb = '1' THEN
          SCHOOLKBN := 33;
        ELSE
          SCHOOLKBN := 34;
        END IF;
        BEGIN
          SELECT
             KOIN_SHORYAKU
            ,KOIN_CHUSHAKU
            ,TSUCHIBUN
            ,TOKKIJIKO
            ,CHOHYO_MEI
            ,YOSHIKI_BANGO_SETTOGO
            ,YOSHIKI_BANGO
            ,YOSHIKI_BANGO_SETSUBIGO
          INTO
             g_nKOIN_SHORYAKU
            ,g_vKOIN_CHUSHAKU
            ,g_vTSUCHIBUN
            ,g_vTOKKIJIKO
            ,g_vCHOHYO_MEI
            ,g_vYOSHIKI_BANGO_SETTOGO
            ,g_nYOSHIKI_BANGO
            ,g_vYOSHIKI_BANGO_SETSUBIGO
          FROM
            GKBTTSUCHISHOKANRI
          WHERE
            CHOHYO_KBN = SCHOOLKBN;
        EXCEPTION
          WHEN OTHERS THEN
            g_nKOIN_SHORYAKU := NULL;
            g_vKOIN_CHUSHAKU := NULL;
            g_vTSUCHIBUN := NULL;
            g_vTOKKIJIKO := NULL;
            g_vCHOHYO_MEI := NULL;
            g_vYOSHIKI_BANGO_SETTOGO := NULL;
            g_nYOSHIKI_BANGO := NULL;
            g_vYOSHIKI_BANGO_SETSUBIGO := NULL;
        END;
        --小学校コード(編集後)
        bRTN := FUNC_GET_GAKOCD(g_txtSyougakoCd, g_sSYOUGAKOCD_ED);
        IF NOT bRTN THEN
          RETURN FALSE;
        END IF;
        --中学校コード(編集後)
        bRTN := FUNC_GET_GAKOCD(g_txtCyugakoCd, g_sCYUGAKOCD_ED);
        IF NOT bRTN THEN
          RETURN FALSE;
        END IF;

        --システム制御設定を取得する
        -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aITEM);
        --「'GKB701R001」が格納されている箇所のインデックス番号
        IF nRTN = 0 THEN
          FOR i IN 1..aITEM.COUNT LOOP
            IF aITEM(i) = 'GKB701R001' THEN
              sINDEXNO := i;
              EXIT;
            END IF;
          END LOOP;
          -- 「本名・通称名　出力制御」のリストを取得する
          nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aITEM);
          IF nRTN = 0 AND sINDEXNO <= aITEM.COUNT THEN
            g_sSEYIGYO := aITEM(sINDEXNO);
          END IF;
        END IF;
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_INIT;
    --------------------------------------------------------------------------------
    --  機能概要      : 学予定通知書中間ワーク
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_GAKU_WK RETURN BOOLEAN IS
              bRTN                          BOOLEAN;  --戻り値
        nRTN                          NUMBER;
        vRTN                          VARCHAR2(5000);
        sSQL                          VARCHAR2(5000);
        TYPE MC_CURSOR IS REF           CURSOR;                                --カーソルタイプ定義
        cCURSOR                       MC_CURSOR;
        RATENA_HOGOSHA                GABTATENAKIHON%ROWTYPE;
        RSOFU_HOGOSHA                 GABTSOFUSAKI%ROWTYPE;
        RATENA_JIDO                   GABTATENAKIHON%ROWTYPE;
        RSOFU_JIDO                    GABTSOFUSAKI%ROWTYPE;
        rTBL                          GKBWNYUGAKUYOTEITSUCHI%ROWTYPE;
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--        rKOJIN_NO                     GKBTGAKUREIBO.KOJIN_NO%TYPE;
--        rHOGOSYA_KOJIN_NO             GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE;
--        rHOGOSYA_ZOKUGARA1            GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1%TYPE;
--        rHOGOSYA_ZOKUGARA2            GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2%TYPE;
--        rHOGOSYA_ZOKUGARA3            GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3%TYPE;
--        rHOGOSYA_ZOKUGARA4            GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4%TYPE;
--        rSYOGAKO_CD                   GKBTGAKUREIBO.SYOGAKO_CD%TYPE;
--        rTYUGAKO_CD                   GKBTGAKUREIBO.TYUGAKO_CD%TYPE;
--        rNENDO                        GKBTSHUGAKURIREKI.NENDO%TYPE;
--        r_KYOIKUIINKAI_CD             GKBTSHOGAKKO.KYOIKUIINKAI_CD%TYPE;
--        r_A_JUMIN_NAKUNARU            GABVATENAALL.JUMIN_NAKUNARU%TYPE;
--        r_A_JUMIN_NAKUNARU_JIYU       GABVATENAALL.JUMIN_NAKUNARU_JIYU%TYPE;
--        r_B_JUMIN_NAKUNARU            GABVATENAALL.JUMIN_NAKUNARU%TYPE;
--        r_B_JUMIN_NAKUNARU_JIYU       GABVATENAALL.JUMIN_NAKUNARU_JIYU%TYPE;
--        rSEIBETSU                     GKBTGAKUREIBO.SEIBETSU%TYPE;
        TYPE MR_TAISHOUJIDOU IS RECORD(
            KOJIN_NO                    NUMBER,                    --宛名番号
            HOGOSYA_KOJIN_NO            NUMBER,                    --保護者宛名番号
            HOGOSYA_ZOKUGARA1           NUMBER,                    --保護者続柄１
            HOGOSYA_ZOKUGARA2           NUMBER,                    --保護者続柄２
            HOGOSYA_ZOKUGARA3           NUMBER,                    --保護者続柄３
            HOGOSYA_ZOKUGARA4           NUMBER,                    --保護者続柄４
            SYOGAKO_CD                  NUMBER,                    --小学校コード
            TYUGAKO_CD                  NUMBER,                    --中学校コード
            KYOIKUIINKAI_CD             NUMBER,                    --教育委員会コード
            JUMIN_NAKUNARU              NUMBER,
            JUMIN_NAKUNARU_JIYU         NUMBER,
            JUMIN_NAKUNARU_1            NUMBER,
            JUMIN_NAKUNARU_JIYU_1       NUMBER,
            SEIBETSU                    NUMBER                     --児童生徒_性別
        );
        rMEIBO                        MR_TAISHOUJIDOU;                 --対象児童カーソル
--  2024/10/11 ZCZL.WANGMING UPDATE END
        o_vYUBIN_NO                   NVARCHAR2(1000);
        vJUSHO                        NVARCHAR2(1000);
        nPRMCTL                       NUMBER;
        v_A_JUMIN_NAKUNARU            NVARCHAR2(1000);
        v_B_JUMIN_NAKUNARU            NVARCHAR2(1000);
        o_sSHIMEIKANA             NVARCHAR2(1000);                     --氏名カナ
        o_sSHIMEIKANJI            NVARCHAR2(1000);                     --氏名漢字
        o_sBIRTHDAY               NVARCHAR2(1000);                     --生年月日
        vGAKOMEI                  NVARCHAR2(1000);
        vSEX                      NVARCHAR2(100);
        nKOJINSETAIKBN                NUMBER;
        nIDOYOKUSHIKBN                NUMBER;
        nHAKKOYOKUSHIKBN              NUMBER;
        nSHOKAIYOKUSHIKBN             NUMBER;
        vSHORICHUIKBN                 NVARCHAR2(100);
        nYOKUSHIKBN                   NUMBER;
        vIDO_JIYU_MEI                 NVARCHAR2(100);
        o_vSHOGAKU_CD     NVARCHAR2(1000);            --小学校区コード
        o_vSHOGAKU_NM     NVARCHAR2(1000);            --小学校区名
        o_vCHUGAKU_CD     NVARCHAR2(1000);            --中学校区コード
        o_vCHUGAKU_NM     NVARCHAR2(1000);            --中学校区名
        NSQLCODE                    NUMBER;             -- エラーコード
        nLENGTH                         NUMBER;                                  --パラメータの配列の長度
        aCONSPRM                        A_CONS_PRM;                              --パラメータの配列
    BEGIN
      -- 入学予定通知書中間ワークをクリアする。
        DELETE FROM GKBWNYUGAKUYOTEITSUCHI;
        -- 入学予定通知書カーソル_S
        sSQL := '';
        sSQL := 'SELECT ';
        sSQL := sSQL || ' GKBTGAKUREIBO.KOJIN_NO ';
        sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_KOJIN_NO ';
        sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1 ';
        sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2 ';
        sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3 ';
        sSQL := sSQL || ',GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4 ';
        sSQL := sSQL || ',GKBTGAKUREIBO.SYOGAKO_CD ';
        sSQL := sSQL || ',GKBTGAKUREIBO.TYUGAKO_CD ';
--  2024/10/11 ZCZL.WANGMING DELETE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--        sSQL := sSQL || ',GKBTSHUGAKURIREKI.NENDO ';
        --処理条件.学校区分　=　'1'(小学校)の場合
        IF g_TxtGakoKb = '1' THEN
          sSQL := sSQL || ',C.KYOIKUIINKAI_CD ';
        ELSIF g_TxtGakoKb = '2' THEN
          sSQL := sSQL || ',D.KYOIKUIINKAI_CD ';
        END IF;
        sSQL := sSQL || ',A.JUMIN_NAKUNARU ';
--  2024/11/18 YAMANI.SASAKI UPDATE START 0.3.000.011:仕様変更　ID：IT_GKB_00614、IT_GKB_00615　不具合　ID：IT_GKB_00616対応
--        sSQL := sSQL || ',A.JUMIN_NAKUNARU_JIYU ';
        sSQL := sSQL || ',NVL(A.JUMIN_NAKUNARU_JIYU, 0) ';
--  2024/11/18 YAMANI.SASAKI UPDATE END
        sSQL := sSQL || ',B.JUMIN_NAKUNARU ';
--  2024/11/18 YAMANI.SASAKI UPDATE START 0.3.000.011:仕様変更　ID：IT_GKB_00614、IT_GKB_00615　不具合　ID：IT_GKB_00616対応
--        sSQL := sSQL || ',B.JUMIN_NAKUNARU_JIYU ';
    sSQL := sSQL || ',NVL(B.JUMIN_NAKUNARU_JIYU, 0) ';
--  2024/11/18 YAMANI.SASAKI UPDATE END
        sSQL := sSQL || ',GKBTGAKUREIBO.SEIBETSU ';
        sSQL := sSQL || 'FROM ';
        sSQL := sSQL || ' GKBTGAKUREIBO ';
        sSQL := sSQL || ' JOIN GABVATENAALL A ON GKBTGAKUREIBO.KOJIN_NO = A.KOJIN_NO ';
        sSQL := sSQL || ' JOIN GABVATENAALL B ON GKBTGAKUREIBO.HOGOSYA_KOJIN_NO = B.KOJIN_NO  ';
--  2024/10/11 ZCZL.WANGMING DELETE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--        sSQL := sSQL || ' JOIN GKBTSHUGAKURIREKI ON GKBTGAKUREIBO.KOJIN_NO = GKBTSHUGAKURIREKI.KOJIN_NO ';
--        sSQL := sSQL || ' AND GKBTGAKUREIBO.RIREKI_RENBAN = GKBTSHUGAKURIREKI.KOJIN_RIREKI_RENBAN ';
--  2024/10/11 ZCZL.WANGMING DELETE END
        --処理条件.学校区分　=　'1'(小学校)の場合
        IF g_TxtGakoKb = '1' THEN
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
          --sSQL := sSQL || ' JOIN GKBTSHOGAKKO C ON GKBTGAKUREIBO.TYUGAKO_CD = C.SYOGAKO_CD ';
          sSQL := sSQL || ' JOIN GKBTSHOGAKKO C ON GKBTGAKUREIBO.SYOGAKO_CD = C.SYOGAKO_CD ';
        ELSIF g_TxtGakoKb = '2' THEN
          sSQL := sSQL || ' JOIN GKBTCHUGAKKO D ON GKBTGAKUREIBO.TYUGAKO_CD = D.TYUGAKO_CD ';
        END IF;
        sSQL := sSQL || 'WHERE ';
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--        sSQL := sSQL || ' GKBTSHUGAKURIREKI.SHUGAKU_RIREKI_RENBAN = (SELECT MAX(r.SHUGAKU_RIREKI_RENBAN) FROM GKBTSHUGAKURIREKI r WHERE r.NENDO =' ||  g_nTxtYear;
--        sSQL := sSQL || ' AND r.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO AND r.KOJIN_RIREKI_RENBAN =  GKBTGAKUREIBO.RIREKI_RENBAN ) ';
--        sSQL := sSQL || ' AND GKBTSHUGAKURIREKI.NENDO =  ' || g_nTxtYear;              -- 学齢簿.対象年度 = 処理条件.対象年度
--        sSQL := sSQL || ' AND GKBTGAKUREIBO.GAKKO_KBN_CD = ' || g_txtGakoKb;
        sSQL := sSQL || ' GKBTGAKUREIBO.GAKKO_KBN_CD = ' || g_txtGakoKb;
--  2024/10/11 ZCZL.WANGMING UPDATE END
        IF g_TxtGakoKb = '1' THEN
          sSQL := sSQL || ' AND GKBTGAKUREIBO.GAKUNEN  = 0 ';
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
          IF g_sSYOUGAKOCD_ED IS NOT NULL THEN
            sSQL := sSQL || ' AND GKBTGAKUREIBO.SYOGAKO_CD IN (' || g_sSYOUGAKOCD_ED || ')';
          END IF;
--  2024/10/11 ZCZL.WANGMING UPDATE END
        ELSIF g_TxtGakoKb = '2' THEN
          sSQL := sSQL || ' AND GKBTGAKUREIBO.GAKUNEN  = 6 ';
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
          IF g_sCYUGAKOCD_ED IS NOT NULL THEN
            sSQL := sSQL || ' AND GKBTGAKUREIBO.TYUGAKO_CD IN ( ' || g_sCYUGAKOCD_ED || ')';
          END IF;
--  2024/10/11 ZCZL.WANGMING UPDATE END
        END IF;
        sSQL := sSQL || ' AND GKBTGAKUREIBO.GEN_JIYU_CD = 0 ';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.GEN_NENGAPI = 0 ';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.SAISHIN_KBN = 0 ';
        sSQL := sSQL || ' AND GKBTGAKUREIBO.SAKUJO_FLG = 0 ';
        sSQL := sSQL || ' AND A.RIREKI_RENBAN = ''999'' ';
        sSQL := sSQL || ' AND B.RIREKI_RENBAN = ''999'' ';
        IF g_TxtGakoKb = '1' THEN
          sSQL := sSQL || ' AND GKBTGAKUREIBO.SYOGAKO_TENGAKU_BI = 0 ';
        ELSIF g_TxtGakoKb = '2' THEN
          sSQL := sSQL || ' AND GKBTGAKUREIBO.TYUGAKO_TENGAKU_BI = 0 ';
        END IF;
        OPEN cCURSOR FOR sSQL;
        LOOP
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          FETCH cCURSOR INTO rKOJIN_NO
--                            ,rHOGOSYA_KOJIN_NO
--                            ,rHOGOSYA_ZOKUGARA1
--                            ,rHOGOSYA_ZOKUGARA2
--                            ,rHOGOSYA_ZOKUGARA3
--                            ,rHOGOSYA_ZOKUGARA4
--                            ,rSYOGAKO_CD
--                            ,rTYUGAKO_CD
--                            ,rNENDO
--                            ,r_KYOIKUIINKAI_CD
--                            ,r_A_JUMIN_NAKUNARU
--                            ,r_A_JUMIN_NAKUNARU_JIYU
--                            ,r_B_JUMIN_NAKUNARU
--                            ,r_B_JUMIN_NAKUNARU_JIYU
--                            ,rSEIBETSU;
          FETCH cCURSOR INTO rMEIBO;
--  2024/10/11 ZCZL.WANGMING UPDATE END
          EXIT WHEN cCURSOR%NOTFOUND;
          IF g_nTxtSofuSaki = 0 THEN
            -- 保護者の基本情報
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--            nRTN := GAAPK0030.FGETATENA(rHOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), RATENA_HOGOSHA, RSOFU_HOGOSHA);
--  2024/11/14 YAMANI.SASAKI UPDATE START 0.3.000.007:IT_GKB_00557、IT_GKB_00558、仕様変更　IT_GKB_00565対応
--            nRTN := GAAPK0030.FGETATENA(rMEIBO.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), RATENA_HOGOSHA, RSOFU_HOGOSHA);
            nRTN := GAAPK0030.FGETATENA2(rMEIBO.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), RATENA_HOGOSHA, RSOFU_HOGOSHA);
--  2024/11/14 YAMANI.SASAKI UPDATE END
            --郵便番号編集処理（KKAPK0010.FYUBINHENSHU）の戻り値を取得
            nRTN := KKAPK0010.FYUBINHENSHU(RSOFU_HOGOSHA.YUBIN_NO, o_vYUBIN_NO);
            --全角変換処理（KKAPK0010.FMULTIBYTEHENKAN）の戻り値をセット
            rTBL.YUBIN_NO := KKAPK0010.FMULTIBYTEHENKAN(o_vYUBIN_NO, 0);                          --郵便番号

            --住所編集取得（GAAPK0010.FADDRESSEDIT）の戻り値をセット
            vRTN := GAAPK0010.FADDRESSEDIT(1, NULL, RSOFU_HOGOSHA.CHOMEI, RSOFU_HOGOSHA.BANCHI, NULL, NULL);
            rTBL.JUSHO := vRTN;
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
            rTBL.KATAGAKI := RSOFU_HOGOSHA.KATAGAKI;                                              --方書
--  2024/11/16 YAMANI.SASAKI UPDATE END
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--            IF g_txtShinenSochid = 0 THEN
            IF g_txtShinenSochid = 1 THEN
              vJUSHO := GAAPK0030.FDVJUSHO('GKB', RSOFU_HOGOSHA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, RSOFU_HOGOSHA.CHOMEI || RSOFU_HOGOSHA.BANCHI, nPRMCTL, 2);
              IF nPRMCTL = 1 THEN
                rTBL.JUSHO := vJUSHO;                                                             --住所
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--                rTBL.KATAGAKI := RSOFU_HOGOSHA.KATAGAKI;                                          --方書
                rTBL.KATAGAKI := NULL;                                                            --方書
--  2024/11/16 YAMANI.SASAKI UPDATE END
--  2024/11/19 YAMANI.SASAKI UPDATE START 0.3.000.012:仕様変更　ID：IT_GKB_00623、IT_GKB_00624対応
                rTBL.YUBIN_NO := NULL;                                                            --郵便番号
--  2024/11/19 YAMANI.SASAKI UPDATE END
              END IF;
            END IF;
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
            --rTBL.ATENA := RSOFU_HOGOSHA.KOJIN_NO;                       --宛名番号
--  2025/07/01 CTC.GL UPDATE Start 1.0.010.001:GKB_QA17602対応
            --IF g_txtSofuSaki = 0 THEN
                --rTBL.ATENA := RSOFU_HOGOSHA.SHIMEI_KANJI || '　' || '様';
            --ELSE
                --IF rMEIBO.TYUGAKO_CD > 0 THEN
                    --rTBL.ATENA :=  GKAFKGKOGTEQ(2, rMEIBO.TYUGAKO_CD) || '長' || '　' || '様' ;
                --ELSE
                    --rTBL.ATENA :=  GKAFKGKOGTEQ(1, rMEIBO.SYOGAKO_CD) || '長' || '　' || '様' ;
                --END IF;
            --END IF;
--  2025/07/01 CTC.GL UPDATE End
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
            rTBL.BC_NO := RSOFU_HOGOSHA.YUBIN_NOBC;                                               --カスタマーバーコード
          ELSE
--  2024/11/15 YAMANI.SASAKI UPDATE START 0.3.000.009:IT_GKB_00576、IT_GKB_00577、IT_GKB_00579対応、仕様変更　IT_GKB_00578対応
--            IF g_nTxtSofuSaki <> 1 THEN
--  2024/11/15 YAMANI.SASAKI UPDATE END
              rTBL.YUBIN_NO := NULL;
              IF g_txtGakoKb = 2 THEN
                BEGIN
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--                  SELECT JUSHO INTO vJUSHO FROM GKBTCHUGAKKO WHERE GKBTCHUGAKKO.TYUGAKO_CD = rTYUGAKO_CD;
                  SELECT JUSHO INTO vJUSHO FROM GKBTCHUGAKKO WHERE GKBTCHUGAKKO.TYUGAKO_CD = rMEIBO.TYUGAKO_CD;
                EXCEPTION
                WHEN OTHERS THEN
                  vJUSHO := NULL;
                END;
              ELSE
                BEGIN
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--                  SELECT JUSHO INTO vJUSHO FROM GKBTSHOGAKKO WHERE GKBTSHOGAKKO.SYOGAKO_CD = rSYOGAKO_CD;
                  SELECT JUSHO INTO vJUSHO FROM GKBTSHOGAKKO WHERE GKBTSHOGAKKO.SYOGAKO_CD = rMEIBO.SYOGAKO_CD;
                EXCEPTION
                WHEN OTHERS THEN
                  vJUSHO := NULL;
                END;
              END IF;
--  2024/11/15 YAMANI.SASAKI UPDATE START 0.3.000.009:IT_GKB_00576、IT_GKB_00577、IT_GKB_00579対応、仕様変更　IT_GKB_00578対応
--            END IF;
--  2024/11/15 YAMANI.SASAKI UPDATE END
            rTBL.JUSHO := vJUSHO;                                                                     --住所
            rTBL.KATAGAKI := NULL;                                                                   --方書
--  2024/11/15 YAMANI.SASAKI UPDATE START 0.3.000.009:IT_GKB_00576、IT_GKB_00577、IT_GKB_00579対応、仕様変更　IT_GKB_00578対応
            rTBL.ATENA := RSOFU_HOGOSHA.KOJIN_NO;                       --宛名番号
            IF rMEIBO.TYUGAKO_CD > 0 THEN
                rTBL.ATENA :=  GKAFKGKOGTEQ(2, rMEIBO.TYUGAKO_CD) || '長' || '　' || '様' ;
            ELSE
                rTBL.ATENA :=  GKAFKGKOGTEQ(1, rMEIBO.SYOGAKO_CD) || '長' || '　' || '様' ;
            END IF;
--  2024/11/15 YAMANI.SASAKI UPDATE END
            rTBL.BC_NO := NULL;                                                                      --カスタマーバーコード
          END IF;
--  2025/01/07 JPJYS.GAOJIAN UPDATE 0.3.000.012:品質強化IT_GKB_10155対応
          --rTBL.SOFU_YMD := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_nTxtHakkoYmd, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);            --送付日
          rTBL.SOFU_YMD :=  KKAPK0020.FDAYEDIT20(g_nTxtHakkoYmd, 0, 3);            --送付日
--  2025/01/07 JPJYS.GAOJIAN UPDATE 0.3.000.012:品質強化IT_GKB_10155対応
          rTBL.KYOIKUKAI_MEI := o_vKATAGAKI1;                                                        --教育委員会名
          rTBL.KYOIKU_CHO_MEI := o_vSHIMEI;                                                          --教育委員会長
          rTBL.KOIN_PATH := o_vKOINFILENAME;                                                         --公印
          IF o_vKOINFILENAME IS NULL THEN
            rTBL.KOIN_SHORYAKU := g_nKOIN_SHORYAKU;                                                  --公印（省略）
            rTBL.KOIN_CHUSHAKU := NULL;                                                  --公印（注釈）
          ELSE
            rTBL.KOIN_SHORYAKU := NULL;
            rTBL.KOIN_CHUSHAKU := g_vKOIN_CHUSHAKU;                                                  --公印（注釈）
          END IF;
          rTBL.TITLE := g_vCHOHYO_MEI;                                                               --タイトル
          rTBL.TSUCHIBUN := REPLACE(g_vTSUCHIBUN, CHR(13)||CHR(10), '#');                            --通知文
          --児童生徒の本名使用制御判定
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          nRTN := GKBFKHMCTRL(rKOJIN_NO,                      --宛名番号
          nRTN := GKBFKHMCTRL(rMEIBO.KOJIN_NO,                      --宛名番号
                              g_rJSTP.CHOHYOID,               --帳票ID
                              0,                              --保護者区分(0:児童生徒)
                              g_sSEYIGYO,                     --システム制御設定
                              o_sSHIMEIKANA,                  --氏名カナ
                              o_sSHIMEIKANJI,                 --氏名漢字
                              o_sBIRTHDAY);                   --生年月日
          rTBL.JIDO_SHIMEI_KANA     := o_sSHIMEIKANA;                                                --児童氏名カナ
          rTBL.JIDO_SHIMEI_KANJI    := o_sSHIMEIKANJI;                                               --児童氏名
          rTBL.SEINENGAPI           := o_sBIRTHDAY;                                                  --生年月日
          --保護者の本名使用制御判定
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          nRTN := GKBFKHMCTRL(rKOJIN_NO,                      --宛名番号
          nRTN := GKBFKHMCTRL(rMEIBO.KOJIN_NO,                      --宛名番号
                              g_rJSTP.CHOHYOID,               --帳票ID
                              1,                              --保護者区分(1:保護者)
                              g_sSEYIGYO,                     --システム制御設定
                              o_sSHIMEIKANA,                  --氏名カナ
                              o_sSHIMEIKANJI,                 --氏名漢字
                              o_sBIRTHDAY);                   --生年月日
          rTBL.HOGOSHA_SHIMEI_KANA  := o_sSHIMEIKANA;                                                --保護者氏名カナ
          rTBL.HOGOSHA_SHIMEI_KANJI := o_sSHIMEIKANJI;                                               --保護者氏名
--  2025/07/01 CTC.GL UPDATE Start 1.0.010.001:GKB_QA17602対応
            IF g_txtSofuSaki = 0 THEN
                rTBL.ATENA := o_sSHIMEIKANJI || '　' || '様';
            ELSE
                IF rMEIBO.TYUGAKO_CD > 0 THEN
                    rTBL.ATENA :=  GKAFKGKOGTEQ(2, rMEIBO.TYUGAKO_CD) || '長' || '　' || '様' ;
                ELSE
                    rTBL.ATENA :=  GKAFKGKOGTEQ(1, rMEIBO.SYOGAKO_CD) || '長' || '　' || '様' ;
                END IF;
            END IF;
--  2025/07/01 CTC.GL UPDATE End
          IF g_txtGakoKb = 2 THEN
            BEGIN
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--              SELECT TYUGAKOMEI INTO vGAKOMEI FROM GKBTCHUGAKKO WHERE GKBTCHUGAKKO.TYUGAKO_CD = rTYUGAKO_CD;
              SELECT TYUGAKOMEI INTO vGAKOMEI FROM GKBTCHUGAKKO WHERE GKBTCHUGAKKO.TYUGAKO_CD = rMEIBO.TYUGAKO_CD;
            EXCEPTION
            WHEN OTHERS THEN
              vGAKOMEI := NULL;
            END;
          ELSE
            BEGIN
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--              SELECT SYOGAKOMEI INTO vGAKOMEI FROM GKBTSHOGAKKO WHERE GKBTSHOGAKKO.SYOGAKO_CD = rSYOGAKO_CD;
              SELECT SYOGAKOMEI INTO vGAKOMEI FROM GKBTSHOGAKKO WHERE GKBTSHOGAKKO.SYOGAKO_CD = rMEIBO.SYOGAKO_CD;
            EXCEPTION
            WHEN OTHERS THEN
              vGAKOMEI := NULL;
            END;
          END IF;
          rTBL.SHUGAKUYOTEIKO := vGAKOMEI;                                                         --就学予定校
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          rTBL.KYOIKUIINKAI_CD := r_KYOIKUIINKAI_CD;                                           --教育委員会コード
          rTBL.KYOIKUIINKAI_CD := rMEIBO.KYOIKUIINKAI_CD;                                           --教育委員会コード
          rTBL.TOKKIJIKO := REPLACE(g_vTOKKIJIKO, CHR(13)||CHR(10), '#');                          --特記事項

          nRTN := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',rTBL.KYOIKUIINKAI_CD , aCONSPRM, nLENGTH);
          IF nRTN =0 THEN
            --お問い合わせ先１
            g_vTOIAWASESAKI1 := aCONSPRM(1);
            --お問い合わせ先２
            g_vTOIAWASESAKI2 := aCONSPRM(6);
            --お問い合わせ先３
            g_vTOIAWASESAKI3 := aCONSPRM(7);
          END IF;
          rTBL.TOIAWASESAKI1 := g_vTOIAWASESAKI1;                                                  --お問い合わせ先1
          rTBL.TOIAWASESAKI2 := g_vTOIAWASESAKI2;                                                  --お問い合わせ先2
          rTBL.TOIAWASESAKI3 := g_vTOIAWASESAKI3;                                                  --お問い合わせ先3
          rTBL.HAKKO_YMD := KKAPK0020.FDateFmt(TO_CHAR(SYSDATE, 'YYYY/MM/DD'), 12);                --作成年月日
          rTBL.SOFUSAKI_SHIMEI := RSOFU_HOGOSHA.SHIMEI_KANJI;                                      --送付先氏名
          BEGIN
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--            SELECT MEISHO INTO vSEX FROM KKATCD WHERE GYOUMUCODE = 'GKB' AND CODECODE = '021' AND GROUPCODE = '0001' AND ANYCODE = rSEIBETSU;
            SELECT MEISHO INTO vSEX FROM KKATCD WHERE GYOUMUCODE = 'GKB' AND CODECODE = '021' AND GROUPCODE = '0001' AND ANYCODE = rMEIBO.SEIBETSU;
          EXCEPTION
              WHEN OTHERS THEN
                vSEX := NULL;
          END;
          rTBL.SEIBETSU := vSEX;       --性別
          --支援措置
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          nRTN := GAAPK0030.FGETDV(rKOJIN_NO,
          nRTN := GAAPK0030.FGETDV(rMEIBO.KOJIN_NO,
                                   0,
                                   g_nTxtHakkoYmd,
                                   'GKB',
                                   0,
                                   nKOJINSETAIKBN,
                                   nYOKUSHIKBN,
                                   nIDOYOKUSHIKBN,
                                   nHAKKOYOKUSHIKBN,
                                   nSHOKAIYOKUSHIKBN,
                                   vSHORICHUIKBN);
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          IF nYOKUSHIKBN = 0 THEN
--            rTBL.JIDO_SHIENSOCHI := NULL;
--          ELSE
--            rTBL.JIDO_SHIENSOCHI := '該当';                        --児童生徒_支援措置
--          END IF;
--  2025/06/06 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
          --IF nYOKUSHIKBN = 1 THEN
          IF 0 < nYOKUSHIKBN AND nYOKUSHIKBN < 99 THEN
--  2025/06/06 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
            rTBL.JIDO_SHIENSOCHI := '対象';                        --児童生徒_支援措置
          ELSE
            rTBL.JIDO_SHIENSOCHI := NULL;
          END IF;
--  2024/11/16 YAMANI.SASAKI UPDATE END
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          nRTN := GAAPK0030.FGETDV(rHOGOSYA_KOJIN_NO,
          nRTN := GAAPK0030.FGETDV(rMEIBO.HOGOSYA_KOJIN_NO,
                                   0,
                                   g_nTxtHakkoYmd,
                                   'GKB',
                                   0,
                                   nKOJINSETAIKBN,
                                   nYOKUSHIKBN,
                                   nIDOYOKUSHIKBN,
                                   nHAKKOYOKUSHIKBN,
                                   nSHOKAIYOKUSHIKBN,
                                   vSHORICHUIKBN);
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          IF nYOKUSHIKBN = 0 THEN
--            rTBL.HOGOSHA_SHIENSOCHI := NULL;
--          ELSE
--            rTBL.HOGOSHA_SHIENSOCHI := '該当';                     --保護者_支援措置
--          END IF;
--  2025/06/06 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
          --IF nYOKUSHIKBN = 1 THEN
          IF 0 < nYOKUSHIKBN AND nYOKUSHIKBN < 99 THEN  
--  2025/06/06 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
            rTBL.HOGOSHA_SHIENSOCHI := '対象';                     --保護者_支援措置
          ELSE
            rTBL.HOGOSHA_SHIENSOCHI := NULL;
          END IF;
--  2024/11/16 YAMANI.SASAKI UPDATE END
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          rTBL.HOGOSHA_ZOKUGARA := GKBFKZKGMGET2(2, rHOGOSYA_ZOKUGARA1, rHOGOSYA_ZOKUGARA2, rHOGOSYA_ZOKUGARA3, rHOGOSYA_ZOKUGARA4);--児童生徒との関係
          rTBL.HOGOSHA_ZOKUGARA := GKBFKZKGMGET2(2, rMEIBO.HOGOSYA_ZOKUGARA1, rMEIBO.HOGOSYA_ZOKUGARA2, rMEIBO.HOGOSYA_ZOKUGARA3, rMEIBO.HOGOSYA_ZOKUGARA4);--児童生徒との関係
          rTBL.YOSHIKI_NO := g_vYOSHIKI_BANGO_SETTOGO || g_nYOSHIKI_BANGO || g_vYOSHIKI_BANGO_SETSUBIGO; --様式番号

--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          nRTN := KKAPK0020.FDateSW(TO_CHAR(TO_DATE(r_A_JUMIN_NAKUNARU, 'YYYY/MM/DD'), 'YYYY/MM/DD'), v_A_JUMIN_NAKUNARU);
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00286横展開対応
          --nRTN := KKAPK0020.FDateSW(TO_CHAR(TO_DATE(rMEIBO.JUMIN_NAKUNARU, 'YYYY/MM/DD'), 'YYYY/MM/DD'), v_A_JUMIN_NAKUNARU);
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          nRTN := KKAPK0020.FDateSW(GKAPK00020.FGETSTRDATE_SLASH(rMEIBO.JUMIN_NAKUNARU), v_A_JUMIN_NAKUNARU);
          IF rMEIBO.JUMIN_NAKUNARU IS NOT NULL AND rMEIBO.JUMIN_NAKUNARU <> 0 THEN
              g_IWAREKIHIZUKE := 0;
              g_BRTNSEINENGAPI := KKAPK0020.FDAYEDIT(g_IWAREKIHIZUKE,
                                                     rMEIBO.JUMIN_NAKUNARU,
                                                     g_VEDIT_GYYMMDD1,
                                                     g_VEDIT_GYYMMDD2,
                                                     g_VEDIT_GYYMMDD3,
                                                     g_VKJ_GENGO,
                                                     g_VKG_GENGO,
                                                     g_IWAREKI_YY,
                                                     g_ISEIREKI_YYYY,
                                                     g_IWAREKI_GYYMM,
                                                     g_IMM,
                                                     g_IDD,
                                                     g_IOWAREKIHIZUKE,
                                                     g_ISEIREKIHIZUKE);
              v_A_JUMIN_NAKUNARU := g_VEDIT_GYYMMDD1;
          ELSE
              v_A_JUMIN_NAKUNARU := '';
          END IF;
--  2024/11/16 YAMANI.SASAKI UPDATE END
          rTBL.JIDO_IDO_BI := v_A_JUMIN_NAKUNARU;
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応                                                           --児童異動日
--          rTBL.JIDO_IDO_JIYU := r_A_JUMIN_NAKUNARU_JIYU;                                                  --児童異動事由コード
          rTBL.JIDO_IDO_JIYU := rMEIBO.JUMIN_NAKUNARU_JIYU;                                                  --児童異動事由コード
          BEGIN
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--            SELECT IDO_JIYU_MEI INTO vIDO_JIYU_MEI FROM GABTIDOJIYU WHERE IDO_JIYU_CD = r_A_JUMIN_NAKUNARU_JIYU;
            SELECT IDO_JIYU_MEI INTO vIDO_JIYU_MEI FROM GABTIDOJIYU WHERE IDO_JIYU_CD = rMEIBO.JUMIN_NAKUNARU_JIYU;
          EXCEPTION
            WHEN OTHERS THEN
              vIDO_JIYU_MEI := NULL;
          END;
          rTBL.JIDO_IDO_JIYUMEI := vIDO_JIYU_MEI;                                                         --児童異動事由名

--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          nRTN := KKAPK0020.FDateSW(TO_CHAR(TO_DATE(r_B_JUMIN_NAKUNARU, 'YYYY/MM/DD'), 'YYYY/MM/DD'), v_B_JUMIN_NAKUNARU);
--  2024/11/02 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00286横展開対応
          --nRTN := KKAPK0020.FDateSW(TO_CHAR(TO_DATE(rMEIBO.JUMIN_NAKUNARU_1, 'YYYY/MM/DD'), 'YYYY/MM/DD'), v_B_JUMIN_NAKUNARU);
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          nRTN := KKAPK0020.FDateSW(GKAPK00020.FGETSTRDATE_SLASH(rMEIBO.JUMIN_NAKUNARU_1), v_B_JUMIN_NAKUNARU);
          IF rMEIBO.JUMIN_NAKUNARU_1 IS NOT NULL AND rMEIBO.JUMIN_NAKUNARU_1 <> 0 THEN
              g_IWAREKIHIZUKE := 0;
              g_BRTNSEINENGAPI := KKAPK0020.FDAYEDIT(g_IWAREKIHIZUKE,
                                                     rMEIBO.JUMIN_NAKUNARU_1,
                                                     g_VEDIT_GYYMMDD1,
                                                     g_VEDIT_GYYMMDD2,
                                                     g_VEDIT_GYYMMDD3,
                                                     g_VKJ_GENGO,
                                                     g_VKG_GENGO,
                                                     g_IWAREKI_YY,
                                                     g_ISEIREKI_YYYY,
                                                     g_IWAREKI_GYYMM,
                                                     g_IMM,
                                                     g_IDD,
                                                     g_IOWAREKIHIZUKE,
                                                     g_ISEIREKIHIZUKE);
              v_B_JUMIN_NAKUNARU := g_VEDIT_GYYMMDD1;
          ELSE
              v_B_JUMIN_NAKUNARU := '';
          END IF;
--  2024/11/16 YAMANI.SASAKI UPDATE END
          rTBL.HOGOSHA_IDO_BI := v_B_JUMIN_NAKUNARU;                                                            --保護者異動日
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          rTBL.HOGOSHA_IDO_JIYU := r_B_JUMIN_NAKUNARU_JIYU;                                                      --保護者異動事由コード
          rTBL.HOGOSHA_IDO_JIYU := rMEIBO.JUMIN_NAKUNARU_JIYU_1;                                                      --保護者異動事由コード
          BEGIN
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          SELECT IDO_JIYU_MEI INTO vIDO_JIYU_MEI FROM GABTIDOJIYU WHERE IDO_JIYU_CD = r_B_JUMIN_NAKUNARU_JIYU;
            SELECT IDO_JIYU_MEI INTO vIDO_JIYU_MEI FROM GABTIDOJIYU WHERE IDO_JIYU_CD = rMEIBO.JUMIN_NAKUNARU_JIYU_1;
          EXCEPTION
            WHEN OTHERS THEN
              vIDO_JIYU_MEI := NULL;
          END;
          rTBL.HOGOSHA_IDO_JIYUMEI := vIDO_JIYU_MEI;                                                               --保護者異動事由名

--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          nRTN := GAAPK0030.FGETATENA(rKOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), RATENA_JIDO, RSOFU_JIDO);
          nRTN := GAAPK0030.FGETATENA(rMEIBO.KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), RATENA_JIDO, RSOFU_JIDO);
          rTBL.JIDO_CHOMEI := RATENA_JIDO.CHOMEI;                                                               --児童町名
          rTBL.JIDO_BANCHI := RATENA_JIDO.BANCHI;                                                               --児童番地
          rTBL.JIDO_KATAGAKI := RATENA_JIDO.KATAGAKI;                                                           --児童方書

--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応
--          nRTN:= GKBFKGKKUGET(rKOJIN_NO,
--                           rHOGOSYA_KOJIN_NO,
--  2025/01/15 JPJYS.LIJINGHUI UPDATE 0.3.000.016:学校区マスタ対応  Start

--          nRTN:= GKBFKGKKUGET(rMEIBO.KOJIN_NO,
--                           rMEIBO.HOGOSYA_KOJIN_NO,
--  2024/10/11 ZCZL.WANGMING UPDATE END
--                           o_vSHOGAKU_CD,
--                           o_vSHOGAKU_NM,
--                           o_vCHUGAKU_CD,
--                           o_vCHUGAKU_NM);
--          IF o_vCHUGAKU_CD IS NOT NULL THEN
            IF g_TxtGakoKb = 1 THEN
              BEGIN
                SELECT
                    GKBTSHOGAKKO.SYOGAKOMEI
                  INTO o_vSHOGAKU_NM
                  FROM
                    GKBTGAKUREIBO, --学齢簿
                    GKBTSHOGAKKO   --小学校名
                 WHERE
                    GKBTGAKUREIBO.SYOGAKO_CD = GKBTSHOGAKKO.SYOGAKO_CD
                    AND GKBTGAKUREIBO.KOJIN_NO = rMEIBO.KOJIN_NO;
              EXCEPTION
                 WHEN OTHERS THEN
                   o_vSHOGAKU_NM := '';
              END ;
            rTBL.GAKU_CD := rMEIBO.SYOGAKO_CD;                                                                  --小学校区コード
            rTBL.GAKU_MEI := o_vSHOGAKU_NM;                                                                     --小学校区名
--          ELSE
            ELSIF g_TxtGakoKb = 2 THEN
              BEGIN
                  SELECT
                      GKBTCHUGAKKO.TYUGAKOMEI
                    INTO o_vCHUGAKU_NM
                    FROM
                      GKBTGAKUREIBO, --学齢簿
                      GKBTCHUGAKKO   --中学校名
                   WHERE
                      GKBTGAKUREIBO.TYUGAKO_CD = GKBTCHUGAKKO.TYUGAKO_CD
                      AND GKBTGAKUREIBO.KOJIN_NO = rMEIBO.KOJIN_NO;
               EXCEPTION
                 WHEN OTHERS THEN
                   o_vCHUGAKU_NM := '';
               END ;
            rTBL.GAKU_CD := rMEIBO.TYUGAKO_CD;                                                                  --中学校区コード
            rTBL.GAKU_MEI := o_vCHUGAKU_NM;                                                                     --中学校区名
            END IF;
--  2025/01/15 JPJYS.LIJINGHUI UPDATE 0.3.000.016:学校区マスタ対応  End
          rTBL.SANTEIDANTAI_CD := RATENA_JIDO.SANTEIDANTAI_CD;                                                  --算定団体コード
          rTBL.JINKAKU_KBN := RATENA_JIDO.JINKAKU_KBN;                                                          --人格区分
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          rTBL.NENDO := g_nTxtYear || '年度';
          rTBL.NENDO := KKAPK0020.FNENDOEDIT(1, g_nTxtYear, 3);                                      --年度
--  2024/11/16 YAMANI.SASAKI UPDATE END
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更　ID：IT_GKB_00074、IT_GKB_00101、IT_GKB_00081、IT_GKB_00139、IT_GKB_00140対応                                                                    --年度
--          rTBL.KOJIN_NO := rKOJIN_NO;
--          rTBL.HOGOSYA_KOJIN_NO := rHOGOSYA_KOJIN_NO;
          rTBL.KOJIN_NO := rMEIBO.KOJIN_NO;
          rTBL.HOGOSYA_KOJIN_NO := rMEIBO.HOGOSYA_KOJIN_NO;
--  2024/10/11 ZCZL.WANGMING UPDATE END
          INSERT INTO GKBWNYUGAKUYOTEITSUCHI VALUES rTBL;
        END LOOP;
        CLOSE cCURSOR;
        RETURN TRUE;
    EXCEPTION
      WHEN OTHERS THEN
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD START 0.3.000.002:8月1日認識合わせの横展開
        IF cCURSOR%ISOPEN THEN
            CLOSE cCURSOR;
        END IF;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
        NSQLCODE := SQLCODE;
        ROLLBACK;
        BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_GAKU_WK', 1, SQLCODE, SQLERRM, SUBSTR('中間ファイル編集が異常終了しました。' || SQLERRM(NSQLCODE), 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FALSE;
    END FUNC_GET_GAKU_WK;
    --------------------------------------------------------
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lujian   2024/07/08
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE
        RETURN NUMBER
    IS
        bRTN                            BOOLEAN;                               --戻り値
        nRTN                            PLS_INTEGER;                           --戻る値
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
        vRTN                            VARCHAR2(5000);                        --戻り値
--  2024/11/16 YAMANI.SASAKI UPDATE END
        nCOUNT                          PLS_INTEGER;                           --抽出件数
        sSQL                            VARCHAR2(5000);
        TYPE MC_CURSOR IS REF           CURSOR;                                --カーソルタイプ定義
        rGKBWNYUGAKUYOTEITSUCHI         GKBWNYUGAKUYOTEITSUCHI%ROWTYPE;        --入学予定通知書中間ワーク
        rGKBWL701R001                   GKBWL701R001%ROWTYPE;                  --入学予定通知書ワーク
        rGKBWL130R062                   GKBWL130R062%ROWTYPE;                  --入学予定通知書発送者一覧ワーク
        rGKBWL160R004                   GKBWL160R004%ROWTYPE;                  --入学通知書エラーワーク
        cCURSOR                         MC_CURSOR;
        cCURSORWL                       MC_CURSOR;
        sCHOHYOCODE                     NVARCHAR2(100);                        --帳票コード
        sCHOHYONAME                     NVARCHAR2(100);                        --帳票名
        nCNT                            NUMBER := 0;
        sBUNSHONOTMP                    NVARCHAR2(100);                          --文書番号TMP
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
        RATENA_HOGOSHA                  GABTATENAKIHON%ROWTYPE;
        RSOFU_HOGOSHA                   GABTSOFUSAKI%ROWTYPE;
        RATENA_JIDO                     GABTATENAKIHON%ROWTYPE;
        RSOFU_JIDO                      GABTSOFUSAKI%ROWTYPE;
        o_vYUBIN_NO                     NVARCHAR2(1000);
        vJUSHO                          NVARCHAR2(1000);
        nPRMCTL                         NUMBER;
--  2024/11/16 YAMANI.SASAKI UPDATE END
    BEGIN
      --入学予定通知書中間ワーク
      sSQL := '';
      sSQL := 'SELECT * ';
      sSQL := sSQL || 'FROM GKBWNYUGAKUYOTEITSUCHI';
--  2024/10/21 ZCZL.WANGMING UPDATE 0.3.000.004:　IT_GKB_00341横展開対応
--      IF g_rJSTP.CHOHYOID = 'GKB130R062' THEN
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
      --IF g_rJSTP.CHOHYOID = 'GKB130R002' THEN
      IF g_rJSTP.CHOHYOID = 'GKB160R004' THEN
        sSQL := sSQL || ' WHERE JIDO_IDO_JIYU IN (210, 211, 220, 230, 240, 250, 260, 270, 280, 291, 292)';
      ELSE
        sSQL := sSQL || ' WHERE JIDO_IDO_JIYU NOT IN (210, 211, 220, 230, 240, 250, 260, 270, 280, 291, 292)';
      END IF;
--  2024/11/18 YAMANI.SASAKI UPDATE START 0.3.000.011:仕様変更　ID：IT_GKB_00614、IT_GKB_00615　不具合　ID：IT_GKB_00616対応
--      IF KKAPK0010.FTrim(g_rJSTP.ORDERBY) IS NOT NULL THEN
--         sSQL := sSQL || ' ORDER BY ' || g_rJSTP.ORDERBY;
--      END IF;
      IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
         sSQL := sSQL || ' ORDER BY ' || g_rJSTP.ORDERBYCLAUSE;
      END IF;
--  2024/11/18 YAMANI.SASAKI UPDATE END
      nCNT := 0;
      g_nREBAN := 0;
      -- グローバル変数.バッチジョブステップ情報.帳票IDが「入学予定通知書」 の場合、入学予定通知書ワークを登録する。
      CASE g_rJSTP.CHOHYOID
      WHEN 'GKB701R001' THEN
        OPEN cCURSOR FOR sSQL;
        LOOP
          FETCH cCURSOR INTO rGKBWNYUGAKUYOTEITSUCHI;
          EXIT WHEN cCURSOR%NOTFOUND;
          g_nREBAN := g_nREBAN + 1;
          rGKBWL701R001.NO                     := g_nREBAN;   --ソート順
          --郵便番号
          rGKBWL701R001.YUBIN_NO               := rGKBWNYUGAKUYOTEITSUCHI.YUBIN_NO;
          rGKBWL701R001.JUSHO                  := rGKBWNYUGAKUYOTEITSUCHI.JUSHO;                                  --住所
          rGKBWL701R001.KATAGAKI               := rGKBWNYUGAKUYOTEITSUCHI.KATAGAKI;                               --方書
          rGKBWL701R001.ATENA                  := rGKBWNYUGAKUYOTEITSUCHI.ATENA;                                  --宛名
          rGKBWL701R001.BC_NO                  := rGKBWNYUGAKUYOTEITSUCHI.BC_NO;                                  --カスタマーバーコード
          IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
--  2025/01/13 JPJYS.GONGYANYAN UPDATE 0.3.000.013:品質強化IT_GKB_10243対応 START
            --rGKBWL701R001.BUNSHO_NO            := g_rBUNNUM;                                                      --文書番号
            rGKBWL701R001.BUNSHO_NO := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_rBUNNUM, 0),' ',''),'　','');
--  2025/01/13 JPJYS.GONGYANYAN UPDATE 0.3.000.013:品質強化IT_GKB_10243対応 END
          ELSE
            rGKBWL701R001.BUNSHO_NO            := NULL;
          END IF;
--  2025/01/07 JPJYS.GAOJIAN UPDATE 0.3.000.012:品質強化IT_GKB_10155対応
          --rGKBWL701R001.SOFU_YMD               := rGKBWNYUGAKUYOTEITSUCHI.SOFU_YMD;                               --送付日
          rGKBWL701R001.SOFU_YMD               := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(rGKBWNYUGAKUYOTEITSUCHI.SOFU_YMD, 0),' ',''),'　','');                               --送付日
--  2025/01/07 JPJYS.GAOJIAN UPDATE 0.3.000.012:品質強化IT_GKB_10155対応
          rGKBWL701R001.KYOIKUKAI_MEI          := rGKBWNYUGAKUYOTEITSUCHI.KYOIKUKAI_MEI;                          --教育委員会名
          rGKBWL701R001.KYOIKU_CHO_MEI         := rGKBWNYUGAKUYOTEITSUCHI.KYOIKU_CHO_MEI;                         --教育委員会長
          rGKBWL701R001.KOIN_PATH              := rGKBWNYUGAKUYOTEITSUCHI.KOIN_PATH;                              --公印
          rGKBWL701R001.KOIN_SHORYAKU          := rGKBWNYUGAKUYOTEITSUCHI.KOIN_SHORYAKU;                          --公印（省略）
          rGKBWL701R001.KOIN_CHUSHAKU          := rGKBWNYUGAKUYOTEITSUCHI.KOIN_CHUSHAKU;                          --公印（注釈）
          rGKBWL701R001.TITLE                  := rGKBWNYUGAKUYOTEITSUCHI.TITLE;                                  --タイトル
          rGKBWL701R001.TSUCHIBUN              := rGKBWNYUGAKUYOTEITSUCHI.TSUCHIBUN;                              --通知文
          rGKBWL701R001.JIDO_SHIMEI_KANA       := rGKBWNYUGAKUYOTEITSUCHI.JIDO_SHIMEI_KANA;                       --児童氏名カナ
          rGKBWL701R001.JIDO_SHIMEI_KANJI      := rGKBWNYUGAKUYOTEITSUCHI.JIDO_SHIMEI_KANJI;                      --児童氏名
          rGKBWL701R001.SEINENGAPI             := rGKBWNYUGAKUYOTEITSUCHI.SEINENGAPI;                             --生年月日
          rGKBWL701R001.HOGOSHA_SHIMEI_KANA    := rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_SHIMEI_KANA;                    --保護者氏名カナ
          rGKBWL701R001.HOGOSHA_SHIMEI_KANJI   := rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_SHIMEI_KANJI;                   --保護者氏名
          rGKBWL701R001.SHUGAKUYOTEIKO         := rGKBWNYUGAKUYOTEITSUCHI.SHUGAKUYOTEIKO;                         --就学予定校
          rGKBWL701R001.TOKKIJIKO              := rGKBWNYUGAKUYOTEITSUCHI.TOKKIJIKO;                              --特記事項
          rGKBWL701R001.TOIAWASESAKI1          := rGKBWNYUGAKUYOTEITSUCHI.TOIAWASESAKI1;                          --お問い合わせ先1
          rGKBWL701R001.TOIAWASESAKI2          := rGKBWNYUGAKUYOTEITSUCHI.TOIAWASESAKI2;                          --お問い合わせ先2
          rGKBWL701R001.TOIAWASESAKI3          := rGKBWNYUGAKUYOTEITSUCHI.TOIAWASESAKI3;                          --お問い合わせ先3
--  2025/01/13 JPJYS.GONGYANYAN UPDATE 0.3.000.013:品質強化IT_GKB_10243対応 START
          --rGKBWL701R001.YOSHIKI_NO             := rGKBWNYUGAKUYOTEITSUCHI.YOSHIKI_NO;                             --様式番号
          rGKBWL701R001.YOSHIKI_NO             := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(rGKBWNYUGAKUYOTEITSUCHI.YOSHIKI_NO, 0),' ',''),'　','');
--  2025/01/13 JPJYS.GONGYANYAN UPDATE 0.3.000.013:品質強化IT_GKB_10243対応 END
          rGKBWL701R001.KOJIN_NO               := rGKBWNYUGAKUYOTEITSUCHI.KOJIN_NO;
          rGKBWL701R001.HOGOSYA_KOJIN_NO       := rGKBWNYUGAKUYOTEITSUCHI.HOGOSYA_KOJIN_NO;
          rGKBWL701R001.BREAK_NO               := NULL;                                                           --改ページキー
          rGKBWL701R001.WSNUM                  := g_sWSNUM;                                                       --端末番号
          rGKBWL701R001.BATCHKBN               := c_BATCH;                                                        --即時バッチ区分
          rGKBWL701R001.JOBNUM                 := g_nJOBNUM;                                                      --ジョブNO
          INSERT INTO GKBWL701R001 VALUES rGKBWL701R001;
          --①.変数.発行履歴が0:作成するの場合、共通関数の帳票発行履歴作成(GKAFKHAKKOR)を使用し、発行履歴を作成する。
          --発行履歴を作成する
--  2026/01/05 CTC.HJF UPDATE START 1.0.451.000:GKB_QA25074対応
          --IF g_sHAKKORIREKI = 0 THEN
          IF g_TXTHAKKORIREKI = 0 THEN
--  2026/01/05 CTC.HJF UPDATE END
            sCHOHYOCODE := g_rJSTP.CHOHYONUM;
            sCHOHYONAME := g_rJSTP.CHOHYONAME;
            --変数.文書番号_区域外満了を文書番号情報（構造体）.MAEMOJIと文書番号情報（構造体）.USHIROMOJIの値で切り抜いた値
            sBUNSHONOTMP := KKAPK0010.FSTRCNV(REPLACE(REPLACE(g_rBUNNUMEDITKEKA.NUM,g_rBUNNUMSRCINF.MAEMOJI,''),g_rBUNNUMSRCINF.USHIROMOJI,''),1);
            nRTN := GKAFKHAKKOR('GKB',                                       --業務コード
                                rGKBWNYUGAKUYOTEITSUCHI.KOJIN_NO,            --宛名番号
                                TO_NUMBER(sCHOHYOCODE),                      --帳票コード
                                SUBSTR(TO_CHAR(SYSDATE,'YYYYMMDD'),1,4),                         --年度
                                1,                                           --処理区分
                                sCHOHYONAME,                                 --通知書種別
                                TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),      --発行日
                                g_nTIME, --発行時間
                                1,                                           --発行枚数
                                g_sTANTOCODE,                                --発行職員宛名番号
                                g_nTxtHakkoYmd,                              --送付日
                                NULL,                                        --通知場所
                                g_rBUNNUMSRCINF.MAEMOJI,                     --文書番号接頭語
--  2024/11/21 ZCZL.ZHANGLEI UPDATE 0.3.000.013:IT_GKC_00329横展開対応
                                --TO_NUMBER(sBUNSHONOTMP),                                --文書番号
                                sBUNSHONOTMP,                                --文書番号
                                g_rBUNNUMSRCINF.USHIROMOJI,                  --文書番号接尾語
--  2026/01/05 CTC.HJF UPDATE START 1.0.451.000:GKB_QA25074対応
                                --rGKBWNYUGAKUYOTEITSUCHI.KOJIN_NO,            --通知対象者宛名番号
                                rGKBWNYUGAKUYOTEITSUCHI.HOGOSYA_KOJIN_NO,    --通知対象者宛名番号
--  2026/01/05 CTC.HJF UPDATE END
                                NULL,                                        --転出先自治体コード
                                g_sWSNUM                                     --更新端末番号
                                );
            IF nRTN = 1 THEN
              bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME, 1, '', '', '[入学予定通知書]共通関数(帳票発行履歴作成)(GKAFKHAKKOR)でエラーが発生しました。　宛名番号　' || rGKBWNYUGAKUYOTEITSUCHI.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
            END IF;
          END IF;
--  2024/11/15 YAMANI.SASAKI UPDATE START 0.3.000.009:IT_GKB_00576、IT_GKB_00577、IT_GKB_00579対応、仕様変更　IT_GKB_00578対応
--          --文書番号編集結果の取得
--          IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (g_rBUNNUMSRCINF.NUMINCTYPE = 1 OR g_rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
--              KKAPK0040.SBunNumIc(g_rBUNNUMSRCINF, g_rBUNNUMEDITKEKA);
--          END IF;
--  2024/11/15 YAMANI.SASAKI UPDATE END
          --文書番号保管を追加する
          nCNT := nCNT + 1;
          g_rHOKANBUNNUM(nCNT).KOJINNUM := rGKBWNYUGAKUYOTEITSUCHI.KOJIN_NO;
          g_rHOKANBUNNUM(nCNT).BUNNUM_ANNAISHOU := g_rBUNNUMEDITKEKA.NUM;
--  2024/11/15 YAMANI.SASAKI UPDATE START 0.3.000.009:IT_GKB_00576、IT_GKB_00577、IT_GKB_00579対応、仕様変更　IT_GKB_00578対応
          --文書番号編集結果の取得
          IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (g_rBUNNUMSRCINF.NUMINCTYPE = 1 OR g_rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
              KKAPK0040.SBunNumIc(g_rBUNNUMSRCINF, g_rBUNNUMEDITKEKA);
          END IF;
--  2024/11/15 YAMANI.SASAKI UPDATE END
          --変数.文書番号に取得した文書番号編集結果を設定。
          g_rBUNNUM := g_rBUNNUMEDITKEKA.NUM;
        END LOOP;
--  2024/10/21 ZCZL.WANGMING UPDATE 0.3.000.004:　IT_GKB_00341横展開対応
--      WHEN 'GKB130R062' THEN
      WHEN 'GKB130R002' THEN
        OPEN cCURSOR FOR sSQL;
        LOOP
          FETCH cCURSOR INTO rGKBWNYUGAKUYOTEITSUCHI;
          EXIT WHEN cCURSOR%NOTFOUND;
          g_nREBAN := g_nREBAN + 1;
          rGKBWL130R062.NO                   := g_nREBAN;                                                         --ソート順
          rGKBWL130R062.SAKUSEI_YMD          := KKAPK0020.FDAYEDIT20(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),0,3); --作成年月日
          rGKBWL130R062.TITLE                := rGKBWNYUGAKUYOTEITSUCHI.TITLE || '発送者一覧表';                   --タイトル
          --文書番号
          FOR i IN 1..g_rHOKANBUNNUM.COUNT LOOP
            IF g_rHOKANBUNNUM(i).KOJINNUM = rGKBWNYUGAKUYOTEITSUCHI.KOJIN_NO THEN
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
               --rGKBWL130R062.BUNSHO_NO := g_rHOKANBUNNUM(nCNT).BUNNUM_ANNAISHOU;
               rGKBWL130R062.BUNSHO_NO := g_rHOKANBUNNUM(i).BUNNUM_ANNAISHOU;
            END IF;
          END LOOP;
          rGKBWL130R062.HAKKO_YMD            := KKAPK0020.FDAYEDIT20(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),0,3); --発行年月日
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          rGKBWL130R062.SOFUSAKI_SHIMEI      := rGKBWNYUGAKUYOTEITSUCHI.SOFUSAKI_SHIMEI;                          --送付先氏名
          rGKBWL130R062.SOFUSAKI_SHIMEI      := rGKBWNYUGAKUYOTEITSUCHI.ATENA;                                    --送付先氏名
--  2024/11/16 YAMANI.SASAKI UPDATE END
          rGKBWL130R062.SOFUSAKI_YUBIN_NO    := rGKBWNYUGAKUYOTEITSUCHI.YUBIN_NO;                                 --送付先郵便番号
--  2024/11/19 YAMANI.SASAKI UPDATE START 0.3.000.012:仕様変更　ID：IT_GKB_00623、IT_GKB_00624対応
--          rGKBWL130R062.SOFUSAKI_JUSHO       := rGKBWNYUGAKUYOTEITSUCHI.JUSHO;                                    --送付先住所
          rGKBWL130R062.SOFUSAKI_JUSHO       := rGKBWNYUGAKUYOTEITSUCHI.JUSHO || '　' || rGKBWNYUGAKUYOTEITSUCHI.KATAGAKI;         --送付先住所
--  2024/11/19 YAMANI.SASAKI UPDATE END
          rGKBWL130R062.JIDO_SHIMEI_KANA     := rGKBWNYUGAKUYOTEITSUCHI.JIDO_SHIMEI_KANA;                         --児童生徒氏名カナ
          rGKBWL130R062.JIDO_SHIMEI_KANJI    := rGKBWNYUGAKUYOTEITSUCHI.JIDO_SHIMEI_KANJI;                        --児童生徒氏名漢字
          rGKBWL130R062.SEINENGAPI           := rGKBWNYUGAKUYOTEITSUCHI.SEINENGAPI;                               --生年月日
          rGKBWL130R062.SEIBETSU             := rGKBWNYUGAKUYOTEITSUCHI.SEIBETSU;                                 --性別
          rGKBWL130R062.JIDO_SHIENSOCHI      := rGKBWNYUGAKUYOTEITSUCHI.JIDO_SHIENSOCHI;                          --児童生徒_支援措置
          rGKBWL130R062.HOGOSHA_SHIMEI_KANA  := rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_SHIMEI_KANA;                      --保護者氏名カナ
          rGKBWL130R062.HOGOSHA_SHIMEI_KANJI := rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_SHIMEI_KANJI;                     --保護者氏名漢字
          rGKBWL130R062.HOGOSHA_ZOKUGARA     := rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_ZOKUGARA;                         --児童生徒との関係
          rGKBWL130R062.HOGOSHA_SHIENSOCHI   := rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_SHIENSOCHI;                       --保護者_支援措置
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          rGKBWL130R062.GAKKO_MEI            := rGKBWNYUGAKUYOTEITSUCHI.GAKU_MEI;                                 --学校名
          rGKBWL130R062.GAKKO_MEI            := rGKBWNYUGAKUYOTEITSUCHI.SHUGAKUYOTEIKO;                           --学校名
--  2024/11/16 YAMANI.SASAKI UPDATE END
          rGKBWL130R062.KENSU                := nCOUNT;                                                           --件数
          rGKBWL130R062.GAKKO_CD             := rGKBWNYUGAKUYOTEITSUCHI.GAKU_CD;                                  --学校コード
          rGKBWL130R062.JIDO_SHIMEI_LABEL    := '児童生徒氏名';                                                    --児童生徒氏名_ラベル
          rGKBWL130R062.HOGOSHA_SHIMEI_LABEL := '保護者氏名';                                                      --保護者氏名_ラベル
          rGKBWL130R062.GAKKO_GYOSEIKU_LABEL := '学校';                                                            --学校/行政区_ラベル
          --人格区分
          IF rGKBWNYUGAKUYOTEITSUCHI.JINKAKU_KBN = 0 THEN
            rGKBWL130R062.JINKAKU_KBN        := NULL;
          ELSIF rGKBWNYUGAKUYOTEITSUCHI.JINKAKU_KBN = 1 THEN
            rGKBWL130R062.JINKAKU_KBN        := '＊';
          END IF;
          rGKBWL130R062.BREAK_NO             := NULL;                                                             --改ページキー
          rGKBWL130R062.WSNUM                := g_sWSNUM;                                                         --端末番号
          rGKBWL130R062.BATCHKBN             := c_BATCH;                                                          --即時バッチ区分
          rGKBWL130R062.JOBNUM               := g_nJOBNUM;                                                        --ジョブNO
          INSERT INTO GKBWL130R062 VALUES rGKBWL130R062;
        END LOOP;
      WHEN 'GKB160R004' THEN
        OPEN cCURSOR FOR sSQL;
        LOOP
          FETCH cCURSOR INTO rGKBWNYUGAKUYOTEITSUCHI;
          EXIT WHEN cCURSOR%NOTFOUND;
          g_nREBAN := g_nREBAN + 1;
          rGKBWL160R004.NO                      :=  g_nREBAN;                                              --ソート順
          rGKBWL160R004.NENDO                   :=  rGKBWNYUGAKUYOTEITSUCHI.NENDO;                         --年度
          rGKBWL160R004.KAIPAGE_CD              :=  rGKBWNYUGAKUYOTEITSUCHI.GAKU_CD;                       --改頁コード
          rGKBWL160R004.KAIPAGE_MEI             :=  rGKBWNYUGAKUYOTEITSUCHI.GAKU_MEI;                      --改頁名
          rGKBWL160R004.SAKUSEIBI               :=  KKAPK0020.FDAYEDIT20(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),0,3);--作成日
          rGKBWL160R004.CHOHYO_RENBAN           :=  NULL;                                                  --帳票連番
          rGKBWL160R004.JIDO_SHIMEI_KANA        :=  rGKBWNYUGAKUYOTEITSUCHI.JIDO_SHIMEI_KANA;              --児童氏名カナ
          rGKBWL160R004.JIDO_SHIMEI_KANJI       :=  rGKBWNYUGAKUYOTEITSUCHI.JIDO_SHIMEI_KANJI;             --児童氏名漢字
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          rGKBWL160R004.SEINENGAPI              :=  rGKBWNYUGAKUYOTEITSUCHI.SEINENGAPI;                    --生年月日
          nRTN := GAAPK0030.FGETATENA(rGKBWNYUGAKUYOTEITSUCHI.KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), RATENA_JIDO, RSOFU_JIDO);
          g_IWAREKIHIZUKE := 0;
          g_BRTNSEINENGAPI := KKAPK0020.FDAYEDIT(g_IWAREKIHIZUKE,
                                                 RATENA_JIDO.SEINENGAPI,
                                                 g_VEDIT_GYYMMDD1,
                                                 g_VEDIT_GYYMMDD2,
                                                 g_VEDIT_GYYMMDD3,
                                                 g_VKJ_GENGO,
                                                 g_VKG_GENGO,
                                                 g_IWAREKI_YY,
                                                 g_ISEIREKI_YYYY,
                                                 g_IWAREKI_GYYMM,
                                                 g_IMM,
                                                 g_IDD,
                                                 g_IOWAREKIHIZUKE,
                                                 g_ISEIREKIHIZUKE);
          rGKBWL160R004.SEINENGAPI              :=  g_VEDIT_GYYMMDD1;                                        --生年月日
--  2024/11/16 YAMANI.SASAKI UPDATE END
          rGKBWL160R004.SEIBETSU                :=  rGKBWNYUGAKUYOTEITSUCHI.SEIBETSU;                      --性別
          rGKBWL160R004.HOGOSHA_SHIMEI_JODAN    :=  rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_SHIMEI_KANA;           --保護者氏名上段
          rGKBWL160R004.HOGOSHA_SHIMEI_GEDAN    :=  rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_SHIMEI_KANJI;          --保護者氏名下段
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          rGKBWL160R004.JUSHO_JODAN             :=  rGKBWNYUGAKUYOTEITSUCHI.JUSHO;                         --住所上段
--          rGKBWL160R004.JUSHO_GEDAN             :=  rGKBWNYUGAKUYOTEITSUCHI.KATAGAKI;                      --住所下段
--          rGKBWL160R004.GAKKOKU_MEI             :=  rGKBWNYUGAKUYOTEITSUCHI.GAKU_MEI;                      --学校区名
--          rGKBWL160R004.YUBIN_NO                :=  rGKBWNYUGAKUYOTEITSUCHI.YUBIN_NO;                      --郵便番号
--          rGKBWL160R004.CHOMEI_BANCHI           :=  rGKBWNYUGAKUYOTEITSUCHI.JUSHO;                         --町名番地
--          rGKBWL160R004.KATAGAKI                :=  rGKBWNYUGAKUYOTEITSUCHI.KATAGAKI;                      --方書

          nRTN := GAAPK0030.FGETATENA2(rGKBWNYUGAKUYOTEITSUCHI.HOGOSYA_KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), RATENA_HOGOSHA, RSOFU_HOGOSHA);

          vRTN := GAAPK0010.FADDRESSEDIT(1, NULL, RSOFU_HOGOSHA.CHOMEI, RSOFU_HOGOSHA.BANCHI, NULL, NULL);
          rGKBWL160R004.JUSHO_JODAN             :=  vRTN;                                                  --住所上段
          rGKBWL160R004.JUSHO_GEDAN             :=  RSOFU_HOGOSHA.KATAGAKI;                                --住所下段

--  2024/11/19 YAMANI.SASAKI UPDATE START 0.3.000.012:仕様変更　ID：IT_GKB_00623、IT_GKB_00624対応
           --郵便番号編集処理（KKAPK0010.FYUBINHENSHU）の戻り値を取得
           nRTN := KKAPK0010.FYUBINHENSHU(RSOFU_HOGOSHA.YUBIN_NO, o_vYUBIN_NO);
           rGKBWL160R004.YUBIN_NO               :=  KKAPK0010.FMULTIBYTEHENKAN(o_vYUBIN_NO, 0);             --郵便番号
--  2024/11/19 YAMANI.SASAKI UPDATE END

          IF g_txtShinenSochid = 1 THEN
              vJUSHO := GAAPK0030.FDVJUSHO('GKB', RSOFU_HOGOSHA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vRTN, nPRMCTL, 2);
              IF nPRMCTL = 1 THEN
                  rGKBWL160R004.JUSHO_JODAN     :=  vJUSHO;                                                --住所上段
                  rGKBWL160R004.JUSHO_GEDAN     :=  NULL;                                                  --住所下段
--  2024/11/19 YAMANI.SASAKI UPDATE START 0.3.000.012:仕様変更　ID：IT_GKB_00623、IT_GKB_00624対応
                  rGKBWL160R004.YUBIN_NO        :=  NULL;                                                  --郵便番号
--  2024/11/19 YAMANI.SASAKI UPDATE END
              END IF;
           END IF;

          rGKBWL160R004.GAKKOKU_MEI             :=  rGKBWNYUGAKUYOTEITSUCHI.SHUGAKUYOTEIKO;                --学校区名

--  2024/11/19 YAMANI.SASAKI UPDATE START 0.3.000.012:仕様変更　ID：IT_GKB_00623、IT_GKB_00624対応
--           --郵便番号編集処理（KKAPK0010.FYUBINHENSHU）の戻り値を取得
--           nRTN := KKAPK0010.FYUBINHENSHU(RSOFU_HOGOSHA.YUBIN_NO, o_vYUBIN_NO);
--           rGKBWL160R004.YUBIN_NO               :=  KKAPK0010.FMULTIBYTEHENKAN(o_vYUBIN_NO, 0);             --郵便番号
--  2024/11/19 YAMANI.SASAKI UPDATE END
           rGKBWL160R004.CHOMEI_BANCHI          :=  rGKBWL160R004.JUSHO_JODAN;                             --町名番地
           rGKBWL160R004.KATAGAKI               :=  rGKBWL160R004.JUSHO_GEDAN;                             --方書
--  2024/11/16 YAMANI.SASAKI UPDATE END
          rGKBWL160R004.JIDO_CHOMEI             :=  rGKBWNYUGAKUYOTEITSUCHI.JIDO_CHOMEI;                   --児童町名
          rGKBWL160R004.JIDO_BANCHI             :=  rGKBWNYUGAKUYOTEITSUCHI.JIDO_BANCHI;                   --児童番地
          rGKBWL160R004.JIDO_KATAGAKI           :=  rGKBWNYUGAKUYOTEITSUCHI.JIDO_KATAGAKI;                 --児童方書
          rGKBWL160R004.NUM                     :=  g_nREBAN;                                              --No
          rGKBWL160R004.JIDO_IDO_BI             :=  rGKBWNYUGAKUYOTEITSUCHI.JIDO_IDO_BI;                   --児童異動日
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          rGKBWL160R004.JIDO_IDO_JIYU           :=  rGKBWNYUGAKUYOTEITSUCHI.JIDO_IDO_JIYU;                 --児童異動事由
          rGKBWL160R004.JIDO_IDO_JIYU           :=  rGKBWNYUGAKUYOTEITSUCHI.JIDO_IDO_JIYUMEI;              --児童異動事由名
--  2024/11/16 YAMANI.SASAKI UPDATE END
          rGKBWL160R004.HOGOSHA_IDO_BI          :=  rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_IDO_BI;                --保護者異動日
--  2024/11/16 YAMANI.SASAKI UPDATE START 0.3.000.010:仕様変更　ID：IT_GKB_00588、IT_GKB_00589、IT_GKB_00590、IT_GKB_00591、IT_GKB_00592、IT_GKB_00593、IT_GKB_00594、IT_GKB_00595　不具合　ID：IT_GKB_00597対応
--          rGKBWL160R004.HOGOSHA_IDO_JIYU        :=  rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_IDO_JIYU;              --保護者異動事由
          rGKBWL160R004.HOGOSHA_IDO_JIYU        :=  rGKBWNYUGAKUYOTEITSUCHI.HOGOSHA_IDO_JIYUMEI;           --児童異動事由名
--  2024/11/16 YAMANI.SASAKI UPDATE END
          rGKBWL160R004.JINKAKU_KBN             :=  rGKBWNYUGAKUYOTEITSUCHI.JINKAKU_KBN;                   --人格区分
          rGKBWL160R004.BREAK_NO                :=  LPAD(rGKBWNYUGAKUYOTEITSUCHI.GAKU_CD, 3,'0');          --改ページキー
          rGKBWL160R004.WSNUM                   :=  g_sWSNUM;                                              --端末番号
          rGKBWL160R004.BATCHKBN                :=  c_BATCH;                                               --即時バッチ区分
          rGKBWL160R004.JOBNUM                  :=  g_nJOBNUM;                                             --ジョブNO
          INSERT INTO GKBWL160R004 VALUES rGKBWL160R004;
        END LOOP;
      END CASE;
      CLOSE cCURSOR;
      --件数取得
      nCOUNT := GKBFKTBLCNT('GKBWNYUGAKUYOTEITSUCHI',NULL);
--  2024/11/18 YAMANI.SASAKI UPDATE START 0.3.000.011:仕様変更　ID：IT_GKB_00614、IT_GKB_00615　不具合　ID：IT_GKB_00616対応
--      --入学予定通知書対象件数
--      g_nINDEX := g_nINDEX + 1;
--      g_oKENSU_LIST.EXTEND(1);
--      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '入力 入学予定通知書対象件数', 1);
--      --入学予定通知書ＣＳＶ件数
--      g_nINDEX := g_nINDEX + 1;
--      g_oKENSU_LIST.EXTEND(1);
--      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_nREBAN, '出力 入学予定通知書ＣＳＶ', 2);

     CASE g_rJSTP.CHOHYOID
   WHEN 'GKB701R001' THEN
         --入学予定通知書対象件数
         g_nINDEX := g_nINDEX + 1;
         g_oKENSU_LIST.EXTEND(1);
         g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '入力 入学予定通知書対象件数', 1);

         --入学予定通知書ＣＳＶ件数
         g_nINDEX := g_nINDEX + 1;
         g_oKENSU_LIST.EXTEND(1);
         g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_nREBAN, '出力 入学予定通知書ＣＳＶ', 2);
   WHEN 'GKB130R002' THEN
         --入学予定通知書ＣＳＶ件数
         g_nINDEX := g_nINDEX + 1;
         g_oKENSU_LIST.EXTEND(1);
         g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_nREBAN, '出力 入学予定通知書発送者一覧表ＣＳＶ', 2);
   WHEN 'GKB160R004' THEN
         --入学予定通知書ＣＳＶ件数
         g_nINDEX := g_nINDEX + 1;
         g_oKENSU_LIST.EXTEND(1);
         g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_nREBAN, '出力 入学予定通知書エラー一覧表ＣＳＶ', 2);
   END CASE;
--  2024/11/18 YAMANI.SASAKI UPDATE END
      --関数終了
      bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV作成処理', 0, '', '', '入学予定通知書ＣＳＶ' || g_nREBAN ||'件を出力しました', g_sTANTOCODE, g_sWSNUM, 1);
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
    --  作成者／作成日: ZCZL.lujian 2024/07/08
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;                    --戻り値
        nRTN             PLS_INTEGER;                --戻る値
        ERR              EXCEPTION;
        g_nCNT           NUMBER;
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

    -- 入学予定通知書ワーク中間データ編集と作成
--  2024/11/15 YAMANI.SASAKI UPDATE START 0.3.000.009:IT_GKB_00576、IT_GKB_00577、IT_GKB_00579対応、仕様変更　IT_GKB_00578対応
--        bRTN := FUNC_GET_GAKU_WK;
--        IF NOT bRTN THEN
--          RAISE ERR;
--        END IF;

        IF g_rJSTP.CHOHYOID = 'GKB701R001' THEN
          bRTN := FUNC_GET_GAKU_WK;
          IF NOT bRTN THEN
            RAISE ERR;
          END IF;
        END IF;
--  2024/11/15 YAMANI.SASAKI UPDATE END

        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB701R001' THEN
            --入学予定通知書一覧ワーク初期化
            DELETE FROM GKBWL701R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
            --ＣＳＶファイル作成処理を呼び出す。
            nRTN := FUNC_CSV_CREATE;
            IF nRTN <> 0 THEN
              RAISE ERR;
            END IF;
--  2024/08/30 ZCZL.xiaoya Add Start 0.3.000.001:IT_GKB_00075対応
            bRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE , 'GKB701R001', 1, g_nCNT);
            IF NOT bRTN THEN
              RAISE ERR;
            END IF;
--  2024/08/30 ZCZL.xiaoya Add End
            --帳票出力CSVの作成
            bRTN := FUNC_B11CSV('GKBWL701R001');
--  2024/10/21 ZCZL.WANGMING UPDATE 0.3.000.004:　IT_GKB_00341横展開対応
--          WHEN 'GKB130R062' THEN
          WHEN 'GKB130R002' THEN
            --入学予定通知書一覧ワーク初期化
            DELETE FROM GKBWL130R062 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
            --ＣＳＶファイル作成処理を呼び出す。
            nRTN := FUNC_CSV_CREATE;
            IF nRTN <> 0 THEN
              RAISE ERR;
            END IF;
            --帳票出力CSVの作成
            bRTN := FUNC_B11CSV('GKBWL130R062');
          WHEN 'GKB160R004' THEN
            --入学予定通知書一覧ワーク初期化
            DELETE FROM GKBWL160R004 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
            --ＣＳＶファイル作成処理を呼び出す。
            nRTN := FUNC_CSV_CREATE;
            IF nRTN <> 0 THEN
              RAISE ERR;
            END IF;
            --帳票出力CSVの作成
            bRTN := FUNC_B11CSV('GKBWL160R004');
          ELSE
            NULL;
        END CASE;
--  2024/08/30 ZCZL.xiaoya Delete 0.3.000.001:IT_GKB_00075対応
--        bRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE , 'GKB701R001', 1, g_nCNT);
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
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
    --  作成者／作成日: ZCZL.lujian   2024/07/08
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
END GKBPB00610;
/