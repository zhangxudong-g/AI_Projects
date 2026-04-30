CREATE OR REPLACE PACKAGE BODY GKBPC00460
--1.0.402.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 新設・統廃合一括処理
--  機能概要      : 新設・統廃合一括処理
--  バージョン    : Ver 1.0.200.000
--  作成者／作成日: ZCZL.LISHUAI   2024/06/26
--------------------------------------------------------
--  変更履歴
--  2024/09/03 ZCZL.WANGMING Update 0.3.000.001:IT_GKB_00075対応
--  2024/09/09 ZCZL.WANGMING Update 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00014、15対応
--  2024/10/15 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00294対応
--  2024/10/17 ZCZL.WANGMING UPDATE 0.3.000.005:仕様変更　IT_GKB_00283、IT_GKB_00284、IT_GKB_00287対応
--  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.006:IT_GKB_00297対応
--  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.007:IT_GKB_00282対応
--  2024/11/08 ZCZL.ZHANGLEI UPDATE 0.3.000.008:仕様変更　IT_GKB_00293、IT_GKB_00378対応
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.009:仕様変更　IT_GKB_00426対応
--  2024/11/23 YAMANI.OHARA UPDATE 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
--  2024/11/25 YAMANI.SASAKI UPDATE 0.3.000.011:仕様変更　IT_GKB_00680対応
--  2024/11/26 YAMANI.SASAKI UPDATE 0.3.000.012:仕様変更　IT_GKB_00688対応
--  2025/01/09 JPJYS.WUZHENGDONG UPDATE 0.3.000.013:不具合　IT_GKB_10147、IT_GKB_10148対応
--  2025/05/17 ZCZL.WANGMING UPDATE 1.0.004.000: GKB_QA15258(保守2209)_転学日・転入学日のチェックと警告エラー対応
--  2025/05/22 CTC.LIUJUNHAO UPDATE 1.0.006.000:GKB_QA13005_新設・統廃合一括処理で帳票の出力や更新がかからない対応
--  2025/07/02 CTC.LIUJUNHAO UPDATE 1.0.010.001:GKB_QA17602対応
--  2025/07/18 CTC.HJF UOPDATE 1.0.010.001:GKB_QA17896対応
--  2025/09/17 CTC.Zhou UPDATE 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
--  2025/12/05 CTC.NI UPDATE 1.0.402.000:不具合対応
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

    g_nTIME                       NUMBER;                        --時分秒
    g_nDATE                       NUMBER;                        --年月日

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --パラメータ変数
    g_vSCHOOLSTARTYMD             NVARCHAR2(10);                 --開校・廃校日（開始）
    g_vSCHOOLENDYMD               NVARCHAR2(10);                 --開校・廃校日（終了）
    g_vSHORIKBN                   NVARCHAR2(2);                  --処理区分
    g_vHAKKOYMD                   NVARCHAR2(10);                 --発行日
    g_vHAKKOYMD2                  PLS_INTEGER;                   --発行日_西暦
    g_vHAKKOYMDHIXYOJI            NVARCHAR2(11);                 --表示発行日
    g_vTODOTEDEYMD                NVARCHAR2(10);                 --届出日
    g_vIDOYMD                     NVARCHAR2(10);                 --異動日
    g_vIDOYMD2                    NVARCHAR2(11);                 --表示異動日
    g_vTENGAKUYMD                 NVARCHAR2(10);                 --転学日
    g_vTENNYUGAKUYMD              NVARCHAR2(10);                 --転入学日
    g_vSHINENSOCHI                NVARCHAR2(1);                  --支援措置対象マスク
    g_vHAKKORERIKI                NVARCHAR2(1);                  --発行履歴

    g_sDAIRIKBN                   NVARCHAR2(1000);               --認証者の本人・代理区分
    g_sKATAGAKI1                  NVARCHAR2(1000);               --認証者の肩書上段
    g_sKATAGAKI2                  NVARCHAR2(1000);               --認証者の肩書下段
    g_sSHIMEI                     NVARCHAR2(1000);               --認証者の氏名
    g_sKOINFILENAME               NVARCHAR2(1000);               --公印ファイル名

    g_sCHOHYOTITLE_SGAKKOU       NVARCHAR2(1000);                --帳票タイトル_小学校
    g_sCHOHYOTITLE_CGAKKOU       NVARCHAR2(1000);                --帳票タイトル_中学校
    g_sTSUCHIBUN_SGAKKOU         NVARCHAR2(1000);                --通知文_小学校
    g_sTSUCHIBUN_CGAKKOU         NVARCHAR2(1000);                --通知文_中学校
    g_sTOKKIJIKO_SGAKKOU         NVARCHAR2(1000);                --特記事項_小学校
    g_sTOKKIJIKO_CGAKKOU         NVARCHAR2(1000);                --特記事項_中学校
    g_sYOSHIKI_SGAKKOU           NVARCHAR2(1000);                --様式番号_小学校
    g_sYOSHIKI_CGAKKOU           NVARCHAR2(1000);                --様式番号_中学校
    g_sKOIN_SHORYAKU_SGAKKOU     NVARCHAR2(1000);                --公印省略_小学校
    g_sKOIN_SHORYAKU_CGAKKOU     NVARCHAR2(1000);                --公印省略_中学校
    g_sKOIN_CHUSHAKU_SGAKKOU     NVARCHAR2(1000);                --公印注釈_小学校
    g_sKOIN_CHUSHAKU_CGAKKOU     NVARCHAR2(1000);                --公印注釈_中学校

    g_rBUNNUMSRCINF              KKAPK0040.MR_BUNNUMSRCINF;      --文書番号情報（構造体）

    g_nTSUCHICNT                 NUMBER;                         --通知件数
    g_nCSVCNT                    NUMBER;                         --CSV出力件数
    g_nTAISIXYOUCNT              NUMBER;                         --対象者件数
    g_nTCL                       NUMBER;                         --新設校・廃校に伴う入学通知書_出力制御
    g_nCNT                       NUMBER;                         --件数

    g_nGAKKU_KBN                 NUMBER;                         --学区管理区分（0：住所、 1：行政区）
    g_NENTXYUFLG                 NUMBER;                         --年度途中フラグ(0:次年度、1:年度途中)
    g_SINSAKUJIXYOFLG            NUMBER;                         --新入学作成処理フラグ(0:未処理、1:処理済)

    TYPE MR_BUNNUM IS RECORD(
        KOJIN_NUM                NUMBER,                         --宛名番号
        BUNSHO_NO                KKAPK0040.MR_BUNNUMEDITKEKA     --文書番号
    );
    TYPE ntTYPE1 IS TABLE OF MR_BUNNUM;
    g_rOldBUNNUM                 ntTYPE1 := ntTYPE1();           --文書番号退避リスト

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
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
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
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
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
        g_nDATE := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));--年月日
        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B00INIT;
    --------------------------------------------------------
    --  機能概要      : 初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
    --------------------------------------------------------
    FUNCTION FUNC_INIT RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                      --戻り値
        nRTN                          NUMBER;                       --戻り値
        aPRM                          A_CONS_PRM;
        nIBDEX                        NUMBER;                       --新設校・廃校に伴う入学通知書_インデックス番号
        rJCTL                         KKBTJCTL%ROWTYPE;             --バッチジョブ情報\

        sSQL                          NVARCHAR2(3000);              --SQL文
        TYPE MC_CURSOR IS REF CURSOR;
        cCURSOR                       MC_CURSOR;
        TYPE MR_GKBTTSUCHISHOKANRI IS RECORD(
             CHOHYO_MEI               GKBTTSUCHISHOKANRI.CHOHYO_MEI%TYPE,
             TSUCHIBUN                GKBTTSUCHISHOKANRI.TSUCHIBUN%TYPE,
             TOKKIJIKO                GKBTTSUCHISHOKANRI.TOKKIJIKO%TYPE,
             KOIN_SHORYAKU            GKBTTSUCHISHOKANRI.KOIN_SHORYAKU%TYPE,
             KOIN_CHUSHAKU            GKBTTSUCHISHOKANRI.KOIN_CHUSHAKU%TYPE,
             YOSHIKI_BANGO_SETTOGO    GKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO%TYPE,
             YOSHIKI_BANGO            GKBTTSUCHISHOKANRI.YOSHIKI_BANGO%TYPE,
             YOSHIKI_BANGO_SETSUBIGO  GKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO%TYPE,
             CHOHYO_KBN               GKBTTSUCHISHOKANRI.CHOHYO_KBN%TYPE
        );
        rGKBTTSUCHISHOKANRI           MR_GKBTTSUCHISHOKANRI;

    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '初期処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        --公印情報を編集する
        bRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.Ninshocode,0), g_sWSNUM, SYSDATE, g_sDAIRIKBN, g_sKATAGAKI1, g_sKATAGAKI2, g_sSHIMEI, g_sKOINFILENAME);
        --SQL文
        sSQL := '';
        sSQL := sSQL ||'SELECT GTS.CHOHYO_MEI';
        sSQL := sSQL ||'       , GTS.TSUCHIBUN';
        sSQL := sSQL ||'       , GTS.TOKKIJIKO';
        sSQL := sSQL ||'       , GTS.KOIN_SHORYAKU';
        sSQL := sSQL ||'       , GTS.KOIN_CHUSHAKU';
        sSQL := sSQL ||'       , GTS.YOSHIKI_BANGO_SETTOGO';
        sSQL := sSQL ||'       , GTS.YOSHIKI_BANGO';
        sSQL := sSQL ||'       , GTS.YOSHIKI_BANGO_SETSUBIGO';
        sSQL := sSQL ||'       ,GTS.CHOHYO_KBN ';
        sSQL := sSQL ||'FROM GKBTTSUCHISHOKANRI GTS ';
        sSQL := sSQL ||'WHERE GTS.CHOHYO_KBN IN(35, 36)';
        --通知書情報を編集する
        OPEN cCURSOR FOR sSQL;
        LOOP
            FETCH cCURSOR INTO rGKBTTSUCHISHOKANRI;
            EXIT WHEN cCURSOR%NOTFOUND;
            CASE rGKBTTSUCHISHOKANRI.CHOHYO_KBN
              WHEN '35' THEN
                g_sCHOHYOTITLE_SGAKKOU := rGKBTTSUCHISHOKANRI.CHOHYO_MEI;
                g_sTSUCHIBUN_SGAKKOU   := rGKBTTSUCHISHOKANRI.TSUCHIBUN;
                g_sTOKKIJIKO_SGAKKOU   := rGKBTTSUCHISHOKANRI.TOKKIJIKO;
                g_sYOSHIKI_SGAKKOU     := rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO;
                IF g_sKOINFILENAME IS NOT NULL THEN
                  g_sKOIN_SHORYAKU_SGAKKOU := NULL;
                  g_sKOIN_CHUSHAKU_SGAKKOU := rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU;
                ELSE
                  g_sKOIN_SHORYAKU_SGAKKOU := rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU;
                  g_sKOIN_CHUSHAKU_SGAKKOU := NULL;
                END IF;
              WHEN '36' THEN
                g_sCHOHYOTITLE_CGAKKOU := rGKBTTSUCHISHOKANRI.CHOHYO_MEI;
                g_sTSUCHIBUN_CGAKKOU   := rGKBTTSUCHISHOKANRI.TSUCHIBUN;
                g_sTOKKIJIKO_CGAKKOU   := rGKBTTSUCHISHOKANRI.TOKKIJIKO;
                g_sYOSHIKI_CGAKKOU     := rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO;
                IF g_sKOINFILENAME IS NOT NULL THEN
                  g_sKOIN_SHORYAKU_CGAKKOU := NULL;
                  g_sKOIN_CHUSHAKU_CGAKKOU := rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU;
                ELSE
                  g_sKOIN_SHORYAKU_CGAKKOU := rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU;
                  g_sKOIN_CHUSHAKU_CGAKKOU := NULL;
                END IF;
              ELSE
                NULL;
            END CASE;
        END LOOP;
        IF cCURSOR%ISOPEN THEN
          CLOSE cCURSOR;
        END IF;
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.009:仕様変更　IT_GKB_00426対応
        IF g_rJSTP.CHOHYOID = 'GKB690R001' THEN
          --文書番号を取得する
          bRTN := KKBPK5551.FJBNSGet(g_nJOBNUM, g_rJSTP.STEPSEQ, g_rBUNNUMSRCINF);
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.009:仕様変更　IT_GKB_00426対応
        END IF;
--  2024/09/09 ZCZL.WANGMING DEL START 0.3.000.002:8月1日認識合わせの横展開
--        g_nTSUCHICNT := 0;
--        g_nCSVCNT    := 0;
--        g_nTAISIXYOUCNT := 0;
--  2024/09/09 ZCZL.WANGMING DEL END
        aPRM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aPRM);
        IF nRTN = 0 THEN
          FOR i IN 1..aPRM.COUNT LOOP
            IF aPRM(i) = 'GKB690R001' THEN
              nIBDEX := i;
            END IF;
          END LOOP;
        END IF;
        aPRM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aPRM);
        IF nRTN = 0 AND nIBDEX <= aPRM.COUNT THEN
          g_nTCL := aPRM(nIBDEX);
        END IF;
        --関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '初期処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/09/09 ZCZL.WANGMING ADD START 0.3.000.002:8月1日認識合わせの横展開
            IF cCURSOR%ISOPEN THEN
              CLOSE cCURSOR;
            END IF;
--  2024/09/09 ZCZL.WANGMING ADD END
            RETURN FALSE;
    END FUNC_INIT;
    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT RETURN BOOLEAN
    IS
-- 2024/08/30 ZCZL.WANGMING Add START 0.3.000.001:IT_GKB_00075対応
      cmbtxtShoriKbn           DBMS_UTILITY.MAXNAME_ARRAY;
      cmbtxtShinenSochi        DBMS_UTILITY.MAXNAME_ARRAY;
      cmbtxtHakkoRireki        DBMS_UTILITY.MAXNAME_ARRAY;
-- 2024/08/30 ZCZL.WANGMING Add END
    BEGIN
        g_vSCHOOLSTARTYMD := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSchoolStartYmd');  --開校・廃校日（開始）
        g_vSCHOOLENDYMD   := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSchoolEndYmd');    --開校・廃校日（終了）
--  2024/09/03 ZCZL.WANGMING Update START 0.3.000.001:IT_GKB_00075対応
--        g_vSHORIKBN       := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShoriKbn');        --処理区分
        cmbtxtShoriKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtShoriKbn');        --処理区分
        g_vSHORIKBN := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtShoriKbn', 0, cmbtxtShoriKbn);
--  2024/09/03 ZCZL.WANGMING Update END
        g_vHAKKOYMD       := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHakkoYmd');        --発行日
        g_vTODOTEDEYMD    := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtTodokedeYmd');     --届出日
        g_vIDOYMD         := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtIdoYmd');          --異動日
        g_vTENGAKUYMD     := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtTengakuYmd');      --転学日
        g_vTENNYUGAKUYMD  := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtTennyugakuYmd');   --転入学日
--  2024/09/03 ZCZL.WANGMING Update START 0.3.000.001:IT_GKB_00075対応
--        g_vSHINENSOCHI    := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShinenSochi');     --支援措置対象マスク
        cmbtxtShinenSochi := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtShinenSochi');    --支援措置対象マスク
        g_vSHINENSOCHI := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtShinenSochi', 0, cmbtxtShinenSochi);
--        g_vHAKKORERIKI    := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHakkoRireki');     --発行履歴
        cmbtxtHakkoRireki := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtHakkoRireki');    --発行履歴
        g_vHAKKORERIKI := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtHakkoRireki', 0, cmbtxtHakkoRireki);
--  2024/09/03 ZCZL.WANGMING Update END
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
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
--  2024/11/25 YAMANI.SASAKI UPDATE START 0.3.000.011:仕様変更　IT_GKB_00680対応
        sWHERE                        NVARCHAR2(100);               --条件
--  2024/11/25 YAMANI.SASAKI UPDATE END
--  2025/05/17 ZCZL.WANGMING ADD START 1.0.004.000: GKB_QA15258(保守2209)_転学日・転入学日のチェックと警告エラー対応
        nTENGAKUYMD                   NUMBER;                       --変数.転学日
        nTENNYUGAKUYMD                NUMBER;                       --変数.転入学日の前日
--  2025/05/17 ZCZL.WANGMING ADD END
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
        --引数.処理結果を空白で初期化する。
        o_vRESULT := '';
        --入力値チェック
        --開校・廃校日（開始）
        bRTN := KKAPK0020.FISDATEW(g_vSCHOOLSTARTYMD);
        IF NOT bRTN THEN
          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件1：開校・廃校日（開始）が不正です。,;';
        END IF;
        --開校・廃校日（終了）
        bRTN := KKAPK0020.FISDATEW(g_vSCHOOLENDYMD);
        IF NOT bRTN THEN
          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件2：開校・廃校日（終了）が不正です。,;';
        END IF;
        --発行日
        bRTN := KKAPK0020.FISDATEW(g_vHAKKOYMD);
        IF NOT bRTN THEN
          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件4：発行日が不正です。,;';
        END IF;
        --届出日
        bRTN := KKAPK0020.FISDATEW(g_vTODOTEDEYMD);
        IF NOT bRTN THEN
          o_vRESULT := o_vRESULT  || g_sGYOUMUCODE || ',99999,条件5：届出日が不正です。,;';
        END IF;
        --異動日
        bRTN := KKAPK0020.FISDATEW(g_vIDOYMD);
        IF NOT bRTN THEN
          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件6：異動日が不正です。,;';
        END IF;
        --転学日
        bRTN := KKAPK0020.FISDATEW(g_vTENGAKUYMD);
        IF NOT bRTN THEN
          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件7：転学日が不正です。,;';
        END IF;
        --転入学日
        bRTN := KKAPK0020.FISDATEW(g_vTENNYUGAKUYMD);
        IF NOT bRTN THEN
          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件8：転入学日が不正です。,;';
        END IF;
        --入力条件の日付の大小をチェックする。
        IF o_vRESULT IS NULL THEN
          --開校・廃校日（開始）＞開校・廃校日（終了）
          IF g_vSCHOOLSTARTYMD > g_vSCHOOLENDYMD THEN
            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件1、2：開校・廃校日（開始）と開校・廃校日（終了）の関係が不正です。,;';
          END IF;
          --転学日 > 転入学日
          IF g_vTENGAKUYMD > g_vTENNYUGAKUYMD THEN
            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件6、7：転学日と転入学日の関係が不正です。,;';
          END IF;
--  2025/05/17 ZCZL.WANGMING UPDATE START 1.0.004.000: GKB_QA15258(保守2209)_転学日・転入学日のチェックと警告エラー対応
--          --転学日 <> (転入学日 - 1)
--          IF g_vTENGAKUYMD <> (g_vTENNYUGAKUYMD - 1) THEN
--            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件6、7：転学日が転入学日の前日ではありませんが、よろしいですか？,;';
--          END IF;
          --変数.転学日と変数.転入学日の前日をチェックする。
          --共通関数「和暦日付を西暦日付に変換」（KKAPK0020.FNENDOHENKAN）で、変数.転学日を取得する。
          nTENGAKUYMD := TO_NUMBER(TO_CHAR(TO_DATE(KKAPK0020.FNENDOHENKAN(g_vTENGAKUYMD)),'YYYYMMDD'));
          --共通関数「和暦日付を西暦日付に変換」（KKAPK0020.FNENDOHENKAN）で、変数.転入学日を取得する。
          nTENNYUGAKUYMD := TO_NUMBER(TO_CHAR((TO_DATE(KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD)) - 1),'YYYYMMDD'));
          --転学日 <> (転入学日 - 1)
          IF nTENGAKUYMD <> nTENNYUGAKUYMD THEN
            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99998,条件6、7：転学日が転入学日の前日ではありませんが、よろしいですか？,;';
          END IF;
--  2025/05/17 ZCZL.WANGMING UPDATE END
        END IF;
--  2024/11/25 YAMANI.SASAKI UPDATE START 0.3.000.011:仕様変更　IT_GKB_00680対応
        --学区管理情報仮マスタに学校区分が小学校のデータが存在するかチェックする。
        sWHERE := '';
        sWHERE := sWHERE ||' GAKKO_KBN_CD = 1';
        sWHERE := sWHERE ||' AND SAISHIN_FLG = 0';
        sWHERE := sWHERE ||' AND SAKUJO_FLG = 0';
        IF GKBFKTBLCNT('GKBTMSGAKKUKARI', sWHERE) = 0 THEN
          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,学区仮マスタ（小学校）が未登録のため処理を実行できません。,;';
        END IF;

        --学区管理情報仮マスタに学校区分が中学校のデータが存在するかチェックする。
        sWHERE := '';
        sWHERE := sWHERE ||' GAKKO_KBN_CD = 2';
        sWHERE := sWHERE ||' AND SAISHIN_FLG = 0';
        sWHERE := sWHERE ||' AND SAKUJO_FLG = 0';
        IF GKBFKTBLCNT('GKBTMSGAKKUKARI', sWHERE) = 0 THEN
          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,学区仮マスタ（中学校）が未登録のため処理を実行できません。,;';
        END IF;
--  2024/11/25 YAMANI.SASAKI UPDATE END
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
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
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
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                      --戻り値
        nRTN                          NUMBER;                       --戻り値
        sWHERE                        NVARCHAR2(100);               --条件
        sSQL                          NVARCHAR2(32767);             --SQL文
        sSQL2                         NVARCHAR2(3000);              --SQL文(件数 のカウントアップを行う)
        o_aPRM                        A_CONS_PRM;
        o_nLENGTH                     NUMBER;
        nINDEX                        NUMBER := 0;
        sTOIAWASE1                    NVARCHAR2(1000);              --お問い合わせ先１
        sTOIAWASE2                    NVARCHAR2(1000);              --お問い合わせ先２
        sTOIAWASE3                    NVARCHAR2(1000);              --お問い合わせ先３
        nPRMCTL                       NUMBER;                       --抑止レベル３制御の要否
        sCHOMEI_BANCHI                NVARCHAR2(1000);              --住所マスク文字列
        sHAKKONENGAPI                 NVARCHAR2(100);               --発行年月日
        sGAKUNENMEI                   GKBTGAKUNEN.GAKUNENMEI%TYPE;  --学年名
        sNYUGAKUKIJITSU               NVARCHAR2(100);               --入学期日
        nNENDO                        NUMBER;                       --年度
        rBUNNUMEDITKEKA2              KKAPK0040.MR_BUNNUMEDITKEKA;  --文書番号編集結果2
        iRERISEQ                      NUMBER := 0;                  --履歴連番
        --  2024/10/18 ZCZL.ZHANGLEI ADD 0.3.000.007:IT_GKB_00282対応
        sTEXTDATA_HEAD                NVARCHAR2(32767);             -- テキストデータ
        sTEXTDATA                     NVARCHAR2(32767);             -- テキストデータ
        sGYOUMUCODE                   CHAR(3);                      --業務コード
        sGROUPCODE                    CHAR(4);                      --グループコード
        sSHORINAME                    NVARCHAR2(100);               --処理名
--  2025/07/01 CTC.LIUJUNHAO ADD START 1.0.010.001:GKB_QA17602対応
        HMOSHIMEIKANA                 NVARCHAR2(100);               --本名使用制御OUT氏名カナ通知書保護者
        HMOSHIMEIKANJI                NVARCHAR2(100);               --本名使用制御OUT氏名漢字通知書保護者
        HMOSEINENGAPI                 NVARCHAR2(15);                --本名使用制御OUT生年月日通知書保護者
        nRTN2                         NUMBER;                       --戻り値2通知書保護者
        HMOSHIMEIKANA2                NVARCHAR2(100);               --本名使用制御OUT氏名カナ一覧表保護者
        HMOSHIMEIKANJI2               NVARCHAR2(100);               --本名使用制御OUT氏名漢字一覧表保護者
        HMOSEINENGAPI2                NVARCHAR2(15);                --本名使用制御OUT生年月日一覧表保護者
        nRTN3                         NUMBER;                       --戻り値一覧表保護者
        HMOSHIMEIKANA3                 NVARCHAR2(100);               --本名使用制御OUT氏名カナCSV児童生徒
        HMOSHIMEIKANJI3                NVARCHAR2(100);               --本名使用制御OUT氏名漢字CSV児童生徒
        HMOSEINENGAPI3                 NVARCHAR2(15);                --本名使用制御OUT生年月日CSV児童生徒
        nRTN4                         NUMBER;                       --戻り値CSV児童生徒
        HMOSHIMEIKANA4                NVARCHAR2(100);               --本名使用制御OUT氏名カナCSV保護者
        HMOSHIMEIKANJI4               NVARCHAR2(100);               --本名使用制御OUT氏名漢字CSV保護者
        HMOSEINENGAPI4                NVARCHAR2(15);                --本名使用制御OUT生年月日CSV保護者
        nRTN5                         NUMBER;                       --戻り値CSV保護者
--  2025/07/01 CTC.LIUJUNHAO ADD END 1.0.010.001:GKB_QA17602対応

        TYPE MC_CURSOR IS REF CURSOR;
        cCURSOR                       MC_CURSOR;
        TYPE MR_GKBWTOHAIGOTAIHI IS RECORD(
            KOJIN_NO                 GKBWTOHAIGOTAIHI.KOJIN_NO%TYPE,
            UPDATE_FLG               GKBWTOHAIGOTAIHI.UPDATE_FLG%TYPE,
            NOW_GAKUNEN              GKBWTOHAIGOTAIHI.NOW_GAKUNEN%TYPE,
            TENNYUGAKU_GAKUNEN       GKBWTOHAIGOTAIHI.TENNYUGAKU_GAKUNEN%TYPE,
            GAKKO_KBN                GKBWTOHAIGOTAIHI.GAKKO_KBN%TYPE,
            TSUJO_SHUGAKUYOTEIKO     GKBWTOHAIGOTAIHI.TSUJO_SHUGAKUYOTEIKO%TYPE,
            TSUJO_SHUGAKUYOTEIKO_MEI GKBWTOHAIGOTAIHI.TSUJO_SHUGAKUYOTEIKO_MEI%TYPE,
            NEW_SHUGAKUSHITEIKOU_KBN GKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN%TYPE,
            NEW_SHUGAKUSHITEIKOU     GKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU%TYPE,
            NEW_SHUGAKUSHITEIKOU_MEI GKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_MEI%TYPE,
            NEW_KYOIKUIINKAI_CD      GKBWTOHAIGOTAIHI.NEW_KYOIKUIINKAI_CD%TYPE,
            NEW_GAKKOKU_CD           GKBWTOHAIGOTAIHI.NEW_GAKKOKU_CD%TYPE,
            BIKO                     GKBWTOHAIGOTAIHI.BIKO%TYPE,
            SOFU_YUBIN               GKBWTOHAIGOTAIHI.SOFU_YUBIN%TYPE,
            SOFU_JUSHO               GKBWTOHAIGOTAIHI.SOFU_JUSHO%TYPE,
            SOFU_KATAGAKI            GKBWTOHAIGOTAIHI.SOFU_KATAGAKI%TYPE,
            SOFU_ATENA               GKBWTOHAIGOTAIHI.SOFU_ATENA%TYPE,
            YUBIN_NOBC               GKBWTOHAIGOTAIHI.YUBIN_NOBC%TYPE,
            JIDO_SHIMEI_KANA         GKBWTOHAIGOTAIHI.JIDO_SHIMEI_KANA%TYPE,
            JIDO_SHIMEI_KANJI        GKBWTOHAIGOTAIHI.JIDO_SHIMEI_KANJI%TYPE,
            JIDO_SEIBETSU            GKBWTOHAIGOTAIHI.JIDO_SEIBETSU%TYPE,
            JIDO_SHIENSOCHI          GKBWTOHAIGOTAIHI.JIDO_SHIENSOCHI%TYPE,
            JIDO_SEINENGAPI          GKBWTOHAIGOTAIHI.JIDO_SEINENGAPI%TYPE,
            JIDO_JUSHO               GKBWTOHAIGOTAIHI.JIDO_JUSHO%TYPE,
            HOGOSHA_KOJIJN_NO        GKBWTOHAIGOTAIHI.HOGOSHA_KOJIJN_NO%TYPE,
            HOGOSHA_SHIMEI_KANA      GKBWTOHAIGOTAIHI.HOGOSHA_SHIMEI_KANA%TYPE,
            HOGOSHA_SHIMEI_KANJI     GKBWTOHAIGOTAIHI.HOGOSHA_SHIMEI_KANJI%TYPE,
            HOGOSHA_ZOKUGARA         GKBWTOHAIGOTAIHI.HOGOSHA_ZOKUGARA%TYPE,
            HOGOSHA_SHIENZOCHI       GKBWTOHAIGOTAIHI.HOGOSHA_SHIENZOCHI%TYPE,
            JINKAKU_KBN              GKBWTOHAIGOTAIHI.JINKAKU_KBN%TYPE,
            WSNUM                    GKBWTOHAIGOTAIHI.WSNUM%TYPE,
            BATCHKBN                 GKBWTOHAIGOTAIHI.BATCHKBN%TYPE,
            JOBNUM                   GKBWTOHAIGOTAIHI.JOBNUM%TYPE
-- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
           ,YUHEN_KBN                NUMBER(1)
-- 2025/09/17 CTC.Zhou Add End
        );
        rGKBWTOHAIGOTAIHI            MR_GKBWTOHAIGOTAIHI;           --新設・統廃合退避ワークカーソル
        rGKBWL690R001                GKBWL690R001%ROWTYPE;          --新設校・廃校に伴う入学通知書ワーク
        rGKBWL130R112                GKBWL130R112%ROWTYPE;          --新設校・廃校に伴う入学通知書発送者一覧ワーク
        temp                         NVARCHAR2(10);

    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        --初期処理
        sWHERE := '';
        sWHERE := sWHERE ||' WSNUM = ' || '''' || g_sWSNUM || '''';
        sWHERE := sWHERE ||' AND BATCHKBN = 2';
        sWHERE := sWHERE ||' AND JOBNUM = ' || g_nJOBNUM;
        g_nCNT := GKBFKTBLCNT('GKBWTOHAIGOTAIHI', sWHERE);
        --SQL文
        sSQL := '';
        sSQL := sSQL ||'SELECT KOJIN_NO';
        sSQL := sSQL ||'       , UPDATE_FLG';
        sSQL := sSQL ||'       , NOW_GAKUNEN';
        sSQL := sSQL ||'       , TENNYUGAKU_GAKUNEN';
        sSQL := sSQL ||'       , GAKKO_KBN';
        sSQL := sSQL ||'       , TSUJO_SHUGAKUYOTEIKO';
        sSQL := sSQL ||'       , TSUJO_SHUGAKUYOTEIKO_MEI';
        sSQL := sSQL ||'       , NEW_SHUGAKUSHITEIKOU_KBN';
        sSQL := sSQL ||'       , NEW_SHUGAKUSHITEIKOU';
        sSQL := sSQL ||'       , NEW_SHUGAKUSHITEIKOU_MEI';
        sSQL := sSQL ||'       , NEW_KYOIKUIINKAI_CD';
        sSQL := sSQL ||'       , NEW_GAKKOKU_CD';
        sSQL := sSQL ||'       , BIKO';
        sSQL := sSQL ||'       , SOFU_YUBIN';
        sSQL := sSQL ||'       , SOFU_JUSHO';
        sSQL := sSQL ||'       , SOFU_KATAGAKI';
        sSQL := sSQL ||'       , SOFU_ATENA';
        sSQL := sSQL ||'       , YUBIN_NOBC';
        sSQL := sSQL ||'       , JIDO_SHIMEI_KANA';
        sSQL := sSQL ||'       , JIDO_SHIMEI_KANJI';
        sSQL := sSQL ||'       , JIDO_SEIBETSU';
        sSQL := sSQL ||'       , JIDO_SHIENSOCHI';
        sSQL := sSQL ||'       , JIDO_SEINENGAPI';
        sSQL := sSQL ||'       , JIDO_JUSHO';
        sSQL := sSQL ||'       , HOGOSHA_KOJIJN_NO';
        sSQL := sSQL ||'       , HOGOSHA_SHIMEI_KANA';
        sSQL := sSQL ||'       , HOGOSHA_SHIMEI_KANJI';
        sSQL := sSQL ||'       , HOGOSHA_ZOKUGARA';
        sSQL := sSQL ||'       , HOGOSHA_SHIENZOCHI';
        sSQL := sSQL ||'       , JINKAKU_KBN';
        sSQL := sSQL ||'       , WSNUM';
        sSQL := sSQL ||'       , BATCHKBN';
        sSQL := sSQL ||'       , JOBNUM ';
-- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
        sSQL := sSQL ||'       , GAAPK0030.FYUHENKBNGET(HOGOSHA_KOJIJN_NO ,''GKB'',TO_NUMBER(TO_CHAR(SYSDATE,''YYYYMMDD''))) AS YUHEN_KBN ';--郵返区分
-- 2025/09/17 CTC.Zhou Add End
        sSQL := sSQL ||'FROM GKBWTOHAIGOTAIHI ';
        CASE g_rJSTP.CHOHYOID
          --新設校・廃校に伴う入学通知書
          WHEN 'GKB690R001' THEN
            sSQL := sSQL ||'WHERE WSNUM = ' || '''' || g_sWSNUM || '''';
            sSQL := sSQL ||'      AND BATCHKBN = 2';
            sSQL := sSQL ||'      AND JOBNUM = ' || g_nJOBNUM;
            sSQL := sSQL ||'      AND UPDATE_FLG = 1';
            sSQL := sSQL ||'      AND ((NEW_SHUGAKUSHITEIKOU_KBN = 1 AND NOW_GAKUNEN <> 0)';
            sSQL := sSQL ||'           OR (NEW_SHUGAKUSHITEIKOU_KBN = 2 AND NOW_GAKUNEN <> 6) ) ';
-- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
--            sSQL := sSQL ||'ORDER BY GAKKO_KBN ASC, NEW_SHUGAKUSHITEIKOU ASC, TENNYUGAKU_GAKUNEN ASC, TSUJO_SHUGAKUYOTEIKO ASC';
            IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
                sSQL := sSQL ||'ORDER BY ' || g_rJSTP.ORDERBYCLAUSE || ', GAKKO_KBN ASC, NEW_SHUGAKUSHITEIKOU ASC, TENNYUGAKU_GAKUNEN ASC, TSUJO_SHUGAKUYOTEIKO ASC';
            ELSE
                sSQL := sSQL ||'ORDER BY GAKKO_KBN ASC, NEW_SHUGAKUSHITEIKOU ASC, TENNYUGAKU_GAKUNEN ASC, TSUJO_SHUGAKUYOTEIKO ASC';
            END IF;
-- 2025/09/17 CTC.Zhou Add End
--  2024/09/09 ZCZL.WANGMING ADD START 0.3.000.002:8月1日認識合わせの横展開
            g_nTSUCHICNT := 0;
            g_nCSVCNT    := 0;
            g_nTAISIXYOUCNT := 0;
--  2024/09/09 ZCZL.WANGMING ADD END
            --新設・統廃合退避ワークカーソル
            OPEN cCURSOR FOR sSQL;
            LOOP
                FETCH cCURSOR INTO rGKBWTOHAIGOTAIHI;
                EXIT WHEN cCURSOR%NOTFOUND;
                --お問い合わせ先を編集する
                nRTN := KKAPK0030.FPRMSHUTOKU('GKB', '00KYOIKUKAI',rGKBWTOHAIGOTAIHI.NEW_KYOIKUIINKAI_CD, o_aPRM, o_nLENGTH);
                IF nRTN = 0 THEN
                  sTOIAWASE1 := o_aPRM(1);
                  sTOIAWASE2 := o_aPRM(6);
                  sTOIAWASE3 := o_aPRM(7);
                END IF;
                nINDEX := nINDEX + 1;
                --新設校・廃校に伴う入学通知書ワークにデータを追加する。
-- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
                rGKBWL690R001.KYOTSU_TSUSU_RENBAN     := LPAD(nINDEX, 6, '0');          -- 業務共通_通数連番
                rGKBWL690R001.KYOTSU_PAGE_RENBAN      := NULL;                          -- 業務共通_頁連番
                rGKBWL690R001.KYOTSU_DOFU_RENBAN      := NULL;                          -- 業務共通_同封内連番
                rGKBWL690R001.KYOTSU_DOFU_MAISU       := NULL;                          -- 業務共通_同封内枚数
                rGKBWL690R001.KYOTSU_YUBIN_K_KBN      := NULL;                          -- 業務共通_郵便局区分
                rGKBWL690R001.KYOTSU_YUHEN_KBN        := rGKBWTOHAIGOTAIHI.YUHEN_KBN;   -- 業務共通_郵返区分
                rGKBWL690R001.KYOTSU_CHOSHU_KBN       := NULL;                          -- 業務共通_徴収区分
--  2025/12/05 CTC.NI UPDATE 1.0.402.000:不具合対応
                --rGKBWL690R001.KYOTSU_GAKKO_KBN        := rGKBWTOHAIGOTAIHI.GAKKO_KBN;   -- 業務共通_学校区分
                rGKBWL690R001.KYOTSU_GAKKO_KBN        := LPAD(rGKBWTOHAIGOTAIHI.GAKKO_KBN, 2, '0');   -- 業務共通_学校区分
--  2025/12/05 CTC.NI UPDATE END
                rGKBWL690R001.KYOTSU_YOBI_AREA1       := NULL;                          -- 業務共通_予備エリア1
                rGKBWL690R001.KYOTSU_YOBI_AREA2       := NULL;                          -- 業務共通_予備エリア2
                rGKBWL690R001.KYOTSU_YOBI_AREA3       := NULL;                          -- 業務共通_予備エリア3
                rGKBWL690R001.KYOTSU_YOBI_AREA4       := NULL;                          -- 業務共通_予備エリア4
                rGKBWL690R001.KYOTSU_YOBI_AREA5       := NULL;                          -- 業務共通_予備エリア5
                rGKBWL690R001.KYOTSU_YOBI_AREA6       := NULL;                          -- 業務共通_予備エリア6
                rGKBWL690R001.KYOTSU_YOBI_AREA7       := NULL;                          -- 業務共通_予備エリア7
                rGKBWL690R001.KYOTSU_YOBI_AREA8       := NULL;                          -- 業務共通_予備エリア8
                rGKBWL690R001.KYOTSU_YOBI_AREA9       := NULL;                          -- 業務共通_予備エリア9
                rGKBWL690R001.KYOTSU_YOBI_AREA10      := NULL;                          -- 業務共通_予備エリア10
                rGKBWL690R001.KYOTSU_YOBI_AREA11      := NULL;                          -- 業務共通_予備エリア11
                rGKBWL690R001.KYOTSU_YOBI_AREA12      := NULL;                          -- 業務共通_予備エリア12
-- 2025/09/17 CTC.Zhou Add End
                --ソート順
                rGKBWL690R001.NO := nINDEX;
                sCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', rGKBWTOHAIGOTAIHI.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, rGKBWTOHAIGOTAIHI.SOFU_JUSHO, nPRMCTL, 2);
                IF g_vSHINENSOCHI = '1' AND nPRMCTL = 1 THEN
                  --送付先郵便番号
                  rGKBWL690R001.SOFU_YUBIN := NULL;
                  --送付先住所
                  rGKBWL690R001.SOFU_JUSHO := sCHOMEI_BANCHI;
                  --送付先方書
                  rGKBWL690R001.SOFU_KATAGAKI := NULL;
                ELSE
                  rGKBWL690R001.SOFU_YUBIN := rGKBWTOHAIGOTAIHI.SOFU_YUBIN;
                  rGKBWL690R001.SOFU_JUSHO := rGKBWTOHAIGOTAIHI.SOFU_JUSHO;
                  rGKBWL690R001.SOFU_KATAGAKI := rGKBWTOHAIGOTAIHI.SOFU_KATAGAKI;
                END IF;
                --送付先宛名
--  2025/07/01 CTC.LIUJUNHAO ADD START 1.0.010.001:GKB_QA17602対応
                nRTN2 := GKBFKHMCTRL(rGKBWTOHAIGOTAIHI.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_nTCL, HMOSHIMEIKANA, HMOSHIMEIKANJI,HMOSEINENGAPI);
                rGKBWL690R001.SOFU_ATENA := HMOSHIMEIKANJI || ' ' || '様';
                --rGKBWL690R001.SOFU_ATENA := rGKBWTOHAIGOTAIHI.SOFU_ATENA;
--  2025/07/01 CTC.LIUJUNHAO ADD END 1.0.010.001:GKB_QA17602対応
                --郵便番号ＢＣ
                rGKBWL690R001.YUBIN_NOBC := rGKBWTOHAIGOTAIHI.YUBIN_NOBC;
                --文書番号
                IF g_rBUNNUMSRCINF.UOUT.NUMUMUFLG = 0 THEN
                  rGKBWL690R001.BUNSHO_NO := g_rBUNNUMSRCINF.UOUT.NUM;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                  rGKBWL690R001.BUNSHO_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL690R001.BUNSHO_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
                ELSE
                  rGKBWL690R001.BUNSHO_NO := NULL;
                END IF;
                --発行年月日
                sHAKKONENGAPI := KKAPK0020.FNENDOHENKAN(g_vHAKKOYMD);
-- 2025/01/08 JPJYS.WUZHENGDONG Update 0.3.000.013:IT_GKB_10147対応 Start
--              rGKBWL690R001.HAKKO_NENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sHAKKONENGAPI), 'YYYY/MM/DD'), 12);
                rGKBWL690R001.HAKKO_NENGAPI := KKAPK0010.FALPZENHANHENKAN(REPLACE(KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sHAKKONENGAPI), 'YYYY/MM/DD'), 1),' ',''),0,'');
-- 2025/01/08 JPJYS.WUZHENGDONG Update 0.3.000.013:IT_GKB_10147対応 End
                --認証者職種
                rGKBWL690R001.NISHOSHA_SHOKUSHU := g_sKATAGAKI1;
                --認証者氏名
                rGKBWL690R001.NINSHOSHA_SHIMEI := g_sSHIMEI;
                --公印パス
                rGKBWL690R001.KOIN_PATH := g_sKOINFILENAME;
                IF rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN  = 1 THEN
                  --公印（省略）
                  rGKBWL690R001.KOIN_SHORYAKU := g_sKOIN_SHORYAKU_SGAKKOU;
                  --公印（注釈）
                  rGKBWL690R001.KOIN_CHUSHAKU := g_sKOIN_CHUSHAKU_SGAKKOU;
                  --タイトル
                  rGKBWL690R001.TITLE := g_sCHOHYOTITLE_SGAKKOU;
                  --通知文
                  rGKBWL690R001.TSUCHI_BUN := REPLACE(g_sTSUCHIBUN_SGAKKOU, CHR(13) || CHR(10), '#');
                  --特記事項
                  rGKBWL690R001.TOKKIJIKO := REPLACE(g_sTOKKIJIKO_SGAKKOU, CHR(13) || CHR(10), '#');
                  --様式番号
                  rGKBWL690R001.YOSHIKI_NO := g_sYOSHIKI_SGAKKOU;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                  rGKBWL690R001.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL690R001.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
                ELSIF rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN  = 2 THEN
                  --公印（省略）
                  rGKBWL690R001.KOIN_SHORYAKU := g_sKOIN_SHORYAKU_CGAKKOU;
                  --公印（注釈）
                  rGKBWL690R001.KOIN_CHUSHAKU := g_sKOIN_CHUSHAKU_CGAKKOU;
                  --タイトル
                  rGKBWL690R001.TITLE := g_sCHOHYOTITLE_CGAKKOU;
                  --通知文
                  rGKBWL690R001.TSUCHI_BUN := REPLACE(g_sTSUCHIBUN_CGAKKOU, CHR(13) || CHR(10), '#');
                  --特記事項
                  rGKBWL690R001.TOKKIJIKO := REPLACE(g_sTOKKIJIKO_CGAKKOU, CHR(13) || CHR(10), '#');
                  --様式番号
                  rGKBWL690R001.YOSHIKI_NO := g_sYOSHIKI_CGAKKOU;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                  rGKBWL690R001.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL690R001.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
                ELSE
                  NULL;
                END IF;
                nRTN := GKBFKHMCTRL(rGKBWTOHAIGOTAIHI.KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_nTCL, rGKBWL690R001.JIDO_SHIMEI_KANA, rGKBWL690R001.JIDO_SHIMEI_KANJI,rGKBWL690R001.HYOJI_SEINENGAPI);
                IF g_vSHINENSOCHI = '1' AND nPRMCTL = 1 THEN
                  --児童生徒現住所
                  rGKBWL690R001.CHOMEI_BANCHI := sCHOMEI_BANCHI;
                ELSE
                  --児童生徒現住所
                  rGKBWL690R001.CHOMEI_BANCHI := rGKBWTOHAIGOTAIHI.JIDO_JUSHO;
                END IF;
                --入学校名
                rGKBWL690R001.NYUGAKUKO_MEI := rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_MEI;
                BEGIN
                  SELECT GAKUNENMEI
                  INTO sGAKUNENMEI
                  FROM GKBTGAKUNEN
                  WHERE GKBTGAKUNEN.GAKUNEN_CD = rGKBWTOHAIGOTAIHI.TENNYUGAKU_GAKUNEN;
                EXCEPTION
                  WHEN OTHERS THEN
                    sGAKUNENMEI := '';
                END;
                --学年
                rGKBWL690R001.GAKUNEN := sGAKUNENMEI;
                --入学期日
                sNYUGAKUKIJITSU := KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD);
-- 2025/01/09 JPJYS.WUZHENGDONG Update 0.3.000.013:IT_GKB_10147対応 Start
--              rGKBWL690R001.NYUGAKU_KIJITSU := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sNYUGAKUKIJITSU), 'YYYY/MM/DD'), 12);
                rGKBWL690R001.NYUGAKU_KIJITSU := KKAPK0010.FALPZENHANHENKAN(REPLACE(KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sNYUGAKUKIJITSU), 'YYYY/MM/DD'), 1),' ',''),0,'');
-- 2025/01/09 JPJYS.WUZHENGDONG Update 0.3.000.013:IT_GKB_10147対応 End
                rGKBWL690R001.TOIAWASESAKI1 := sTOIAWASE1;
                rGKBWL690R001.TOIAWASESAKI2 := sTOIAWASE2;
                rGKBWL690R001.TOIAWASESAKI3 := sTOIAWASE3;
                rGKBWL690R001.KOJIN_NO := rGKBWTOHAIGOTAIHI.KOJIN_NO;
                rGKBWL690R001.HOGOSYA_KOJIN_NO := rGKBWTOHAIGOTAIHI.HOGOSHA_KOJIJN_NO;
                rGKBWL690R001.BREAK_NO := nINDEX;
                rGKBWL690R001.WSNUM := g_sWSNUM;
                rGKBWL690R001.BATCHKBN := 2;
                rGKBWL690R001.JOBNUM := g_nJOBNUM;
                --新設校・廃校に伴う入学通知書ワークにデータを追加す
                INSERT INTO GKBWL690R001 VALUES rGKBWL690R001;
                --通知件数 のカウントアップを行う
                g_nTSUCHICNT := g_nTSUCHICNT + 1;
                --発行履歴作成
                IF g_vHAKKORERIKI = 0 THEN
                  --年度
                  nNENDO := TO_NUMBER(SUBSTR(g_nDATE, 1, 4));
                  --通知書種別
                  IF rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN = 1 THEN
                    g_rJSTP.CHOHYONAME := g_sCHOHYOTITLE_SGAKKOU;
                  ELSIF rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN = 2 THEN
                    g_rJSTP.CHOHYONAME := g_sCHOHYOTITLE_CGAKKOU;
                  END IF;
                  nRTN := GKAFKHAKKOR('GKB',
                                      rGKBWTOHAIGOTAIHI.KOJIN_NO,
                                      g_rJSTP.CHOHYONUM,
                                      nNENDO,
                                      1,
                                      g_rJSTP.CHOHYONAME,
                                      g_nDATE,
                                      g_nTIME,
                                      1,
                                      g_sTANTOCODE,
                                      TO_NUMBER(KKAPK0020.FNENDOHENKAN(g_vHAKKOYMD)),
                                      NULL,
                                      g_rBUNNUMSRCINF.MAEMOJI,
                                      KKAPK0010.FSTRCNV(REPLACE(REPLACE(g_rBUNNUMSRCINF.UOUT.NUM,g_rBUNNUMSRCINF.MAEMOJI,''),g_rBUNNUMSRCINF.USHIROMOJI,''), 1),
                                      g_rBUNNUMSRCINF.USHIROMOJI,
                                      rGKBWTOHAIGOTAIHI.HOGOSHA_KOJIJN_NO,
                                      NULL,
                                      g_sWSNUM);
                END IF;
                --  2024/10/15 ZCZL.ZHANGLEI DEL START 0.3.000.004:IT_GKB_00294対応
                --文書番号編集結果の取得（文書番号のカウントアップ）
                --IF g_rBUNNUMSRCINF.UOUT.NUMUMUFLG = 0 AND (g_rBUNNUMSRCINF.NUMINCTYPE = 1 OR g_rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
                --  KKAPK0040.SBunNumIc(g_rBUNNUMSRCINF, rBUNNUMEDITKEKA2);
                --END IF;
                --  2024/10/15 ZCZL.ZHANGLEI DEL END
                --文書番号の退避
                g_rOldBUNNUM.EXTEND;
                g_rOldBUNNUM(g_rOldBUNNUM.LAST).KOJIN_NUM := rGKBWTOHAIGOTAIHI.KOJIN_NO;
                g_rOldBUNNUM(g_rOldBUNNUM.LAST).BUNSHO_NO := g_rBUNNUMSRCINF.UOUT;
                --  2024/10/15 ZCZL.ZHANGLEI ADD START 0.3.000.004:IT_GKB_00294対応
                --文書番号編集結果の取得（文書番号のカウントアップ）
                IF g_rBUNNUMSRCINF.UOUT.NUMUMUFLG = 0 AND (g_rBUNNUMSRCINF.NUMINCTYPE = 1 OR g_rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
                  KKAPK0040.SBunNumIc(g_rBUNNUMSRCINF, rBUNNUMEDITKEKA2);
                END IF;
                --  2024/10/15 ZCZL.ZHANGLEI ADD END
            END LOOP;
            --発送者文字切れリストの作成
            --  2024/10/15 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00294対応
            --bRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sTANTOCODE, g_sWSNUM, 'GKB690R001', 1, g_nCNT);
            bRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE, 'GKB690R001', 1, g_nCNT);
            --ファイルオープンする
            nRTN := KKAPK0090.FDLWorkOpen('GKBWDC004601', iRERISEQ, 1, '新設・統廃合対象', 'GKBF_SHIN_TOHAIGO_TAISHO.csv', '', g_sTANTOCODE, g_sWSNUM, '');

            --  2024/10/18 ZCZL.ZHANGLEI ADD START 0.3.000.007:IT_GKB_00282対応
            sTEXTDATA_HEAD := '児童生徒_宛名番号';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',児童生徒_氏名';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',保護者_宛名番号';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',保護者_氏名';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',更新対象フラグ';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',更新対象フラグ_表示';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',学校区分コード';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',学校区分名';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',通常就学予定校コード';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',通常就学予定校名';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',新就学指定校_学校区分コード';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',新就学指定校_学校区分名';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',新就学指定校コード';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',新就学指定校名';
            sTEXTDATA_HEAD := sTEXTDATA_HEAD || ',備考';
            nRTN := KKAPK0090.FDLWorkPutNC(sTEXTDATA_HEAD, 'UTF8', 1);
            IF nRTN = 1 THEN
              RETURN FALSE;
            END IF;
            --  2024/10/18 ZCZL.ZHANGLEI ADD END
            --新設・統廃合対象CSV
            sSQL := '';
            sSQL := sSQL ||'SELECT KOJIN_NO';
            sSQL := sSQL ||'       , UPDATE_FLG';
            sSQL := sSQL ||'       , NOW_GAKUNEN';
            sSQL := sSQL ||'       , TENNYUGAKU_GAKUNEN';
            sSQL := sSQL ||'       , GAKKO_KBN';
            sSQL := sSQL ||'       , TSUJO_SHUGAKUYOTEIKO';
            sSQL := sSQL ||'       , TSUJO_SHUGAKUYOTEIKO_MEI';
            sSQL := sSQL ||'       , NEW_SHUGAKUSHITEIKOU_KBN';
            sSQL := sSQL ||'       , NEW_SHUGAKUSHITEIKOU';
            sSQL := sSQL ||'       , NEW_SHUGAKUSHITEIKOU_MEI';
            sSQL := sSQL ||'       , NEW_KYOIKUIINKAI_CD';
            sSQL := sSQL ||'       , NEW_GAKKOKU_CD';
            sSQL := sSQL ||'       , BIKO';
            sSQL := sSQL ||'       , SOFU_YUBIN';
            sSQL := sSQL ||'       , SOFU_JUSHO';
            sSQL := sSQL ||'       , SOFU_KATAGAKI';
            sSQL := sSQL ||'       , SOFU_ATENA';
            sSQL := sSQL ||'       , YUBIN_NOBC';
            sSQL := sSQL ||'       , JIDO_SHIMEI_KANA';
            sSQL := sSQL ||'       , JIDO_SHIMEI_KANJI';
            sSQL := sSQL ||'       , JIDO_SEIBETSU';
            sSQL := sSQL ||'       , JIDO_SHIENSOCHI';
            sSQL := sSQL ||'       , JIDO_SEINENGAPI';
            sSQL := sSQL ||'       , JIDO_JUSHO';
            sSQL := sSQL ||'       , HOGOSHA_KOJIJN_NO';
            sSQL := sSQL ||'       , HOGOSHA_SHIMEI_KANA';
            sSQL := sSQL ||'       , HOGOSHA_SHIMEI_KANJI';
            sSQL := sSQL ||'       , HOGOSHA_ZOKUGARA';
            sSQL := sSQL ||'       , HOGOSHA_SHIENZOCHI';
            sSQL := sSQL ||'       , JINKAKU_KBN';
            sSQL := sSQL ||'       , WSNUM';
            sSQL := sSQL ||'       , BATCHKBN';
            sSQL := sSQL ||'       , JOBNUM ';
-- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
            sSQL := sSQL ||'       , NULL AS YUHEN_KBN ';--郵返区分
-- 2025/09/17 CTC.Zhou Add End
            sSQL := sSQL ||'FROM GKBWTOHAIGOTAIHI ';
            sSQL := sSQL ||' WHERE WSNUM = ' || '''' || g_sWSNUM || '''';
            sSQL := sSQL ||'      AND BATCHKBN = 2';
            sSQL := sSQL ||'      AND JOBNUM = ' || g_nJOBNUM;
            sSQL := sSQL ||' ORDER BY GAKKO_KBN ASC, NEW_SHUGAKUSHITEIKOU ASC, TENNYUGAKU_GAKUNEN ASC, TSUJO_SHUGAKUYOTEIKO ASC';
            --新設・統廃合退避ワークカーソル
            OPEN cCURSOR FOR sSQL;
            LOOP
                FETCH cCURSOR INTO rGKBWTOHAIGOTAIHI;
                EXIT WHEN cCURSOR%NOTFOUND;
                --CSVとして出力する情報の編集を行う
                sTEXTDATA := '';
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.KOJIN_NO || ',';
--  2025/07/01 CTC.LIUJUNHAO ADD START 1.0.010.001:GKB_QA17602対応
                /*sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.JIDO_SHIMEI_KANJI || ',';
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.HOGOSHA_KOJIJN_NO || ',';
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.HOGOSHA_SHIMEI_KANJI || ',';*/
                nRTN4:= GKBFKHMCTRL(rGKBWTOHAIGOTAIHI.KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_nTCL, HMOSHIMEIKANA3, HMOSHIMEIKANJI3,HMOSEINENGAPI3);
                sTEXTDATA := sTEXTDATA || HMOSHIMEIKANJI3 || ',';
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.HOGOSHA_KOJIJN_NO || ',';
                nRTN5:= GKBFKHMCTRL(rGKBWTOHAIGOTAIHI.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_nTCL, HMOSHIMEIKANA4, HMOSHIMEIKANJI4,HMOSEINENGAPI4);
                sTEXTDATA := sTEXTDATA || HMOSHIMEIKANJI4 || ',';
--  2025/07/01 CTC.LIUJUNHAO ADD END 1.0.010.001:GKB_QA17602対応
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.UPDATE_FLG || ',';
                IF rGKBWTOHAIGOTAIHI.UPDATE_FLG = 1 THEN
                  sTEXTDATA := sTEXTDATA || '一括更新・通知対象' || ',';
                ELSIF rGKBWTOHAIGOTAIHI.UPDATE_FLG = 0 THEN
                  sTEXTDATA := sTEXTDATA || '一括更新・通知対象外' || ',';
                ELSE
                  NULL;
                END IF;
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.GAKKO_KBN || ',';
                IF rGKBWTOHAIGOTAIHI.GAKKO_KBN = 1 THEN
                  sTEXTDATA := sTEXTDATA || '小学校' || ',';
                ELSIF rGKBWTOHAIGOTAIHI.GAKKO_KBN = 2 THEN
                  sTEXTDATA := sTEXTDATA || '中学校' || ',';
                ELSIF rGKBWTOHAIGOTAIHI.GAKKO_KBN = 3 THEN
                  sTEXTDATA := sTEXTDATA || '特別支援学校' || ',';
                ELSIF rGKBWTOHAIGOTAIHI.GAKKO_KBN = 4 THEN
                  sTEXTDATA := sTEXTDATA || '区域外就学' || ',';
                ELSIF rGKBWTOHAIGOTAIHI.GAKKO_KBN = 5 THEN
                  sTEXTDATA := sTEXTDATA || '国・私立学校' || ',';
                ELSE
--  2024/11/26 YAMANI.SASAKI UPDATE START 0.3.000.012:仕様変更　IT_GKB_00688対応
--                  NULL;
                  sTEXTDATA := sTEXTDATA || '' || ',';
--  2024/11/26 YAMANI.SASAKI UPDATE END
                END IF;
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.TSUJO_SHUGAKUYOTEIKO || ',';
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.TSUJO_SHUGAKUYOTEIKO_MEI || ',';
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN || ',';
--  2024/11/26 YAMANI.SASAKI UPDATE START 0.3.000.012:仕様変更　IT_GKB_00688対応
--                IF rGKBWTOHAIGOTAIHI.NOW_GAKUNEN IN (1, 2, 3, 4, 5, 6) THEN
--                  sTEXTDATA := sTEXTDATA || '小学校' || ',';
--                ELSIF rGKBWTOHAIGOTAIHI.NOW_GAKUNEN IN (7, 8, 9) THEN
--                  sTEXTDATA := sTEXTDATA || '中学校' || ',';
--                ELSE
--                  NULL;
--                END IF;
                IF rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN = 1 THEN
                  sTEXTDATA := sTEXTDATA || '小学校' || ',';
                ELSIF rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN = 2 THEN
                  sTEXTDATA := sTEXTDATA || '中学校' || ',';
                ELSE
                  sTEXTDATA := sTEXTDATA || '' || ',';
                END IF;
--  2024/11/26 YAMANI.SASAKI UPDATE END
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU || ',';
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_MEI || ',';
                sTEXTDATA := sTEXTDATA || rGKBWTOHAIGOTAIHI.BIKO;
                nRTN := KKAPK0090.FDLWorkPutNC(sTEXTDATA, 'UTF8', 1);
                IF nRTN = 1 THEN
                  RETURN FALSE;
                END IF;
                g_nCSVCNT := g_nCSVCNT + 1;
            END LOOP;
            --ファイルをクローズする
            nRTN := KKAPK0090.FDLWorkClose;
            IF nRTN = 1 THEN
              RETURN FALSE;
            END IF;
            --ダウンロード設定用情報の取得を行う\

            bRTN := KKBPK5551.FKKBVJCTLGET(g_nJOBNUM, sGYOUMUCODE, sGROUPCODE, sSHORINAME);
            IF NOT bRTN THEN
              RETURN FALSE;
            END IF;
            nRTN := KKAPK0090.FDLCtlPut (sGYOUMUCODE, sGROUPCODE, sSHORINAME, g_nJOBNUM);
            IF nRTN = 1 THEN
              RETURN FALSE;
            END IF;
            g_nTAISIXYOUCNT := g_nTAISIXYOUCNT + 1;
          --新設校・廃校に伴う入学通知書発送者一覧
          WHEN 'GKB130R002' THEN
            sSQL := sSQL ||' WHERE WSNUM = ' || '''' || g_sWSNUM || '''';
            sSQL := sSQL ||'      AND BATCHKBN = 2';
            sSQL := sSQL ||'      AND JOBNUM = ' || g_nJOBNUM;
            sSQL := sSQL ||'      AND UPDATE_FLG = 1';
            sSQL := sSQL ||'      AND ((NEW_SHUGAKUSHITEIKOU_KBN = 1 AND NOW_GAKUNEN <> 0)';
            sSQL := sSQL ||'           OR (NEW_SHUGAKUSHITEIKOU_KBN = 2 AND NOW_GAKUNEN <> 6) ) ';
            sSQL := sSQL ||'ORDER BY GAKKO_KBN ASC, NEW_SHUGAKUSHITEIKOU ASC, TENNYUGAKU_GAKUNEN ASC, TSUJO_SHUGAKUYOTEIKO ASC';
            --新設・統廃合退避ワークカーソル
            OPEN cCURSOR FOR sSQL;
            LOOP
                FETCH cCURSOR INTO rGKBWTOHAIGOTAIHI;
                EXIT WHEN cCURSOR%NOTFOUND;
                nINDEX := nINDEX + 1;
                --ソート順
                rGKBWL130R112.NO := nINDEX;
                --作成年月日
                rGKBWL130R112.SAKUSEI_YMD := g_nDATE;
                --タイトル
                IF rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN = 1 THEN
                  rGKBWL130R112.TITLE := g_sCHOHYOTITLE_SGAKKOU || '発送者一覧表';
                ELSIF rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN = 2 THEN
                  rGKBWL130R112.TITLE := g_sCHOHYOTITLE_CGAKKOU || '発送者一覧表';
                ELSE
                  NULL;
                END IF;
                FOR i IN 1..g_rOldBUNNUM.COUNT LOOP
                  IF g_rOldBUNNUM(i).KOJIN_NUM = rGKBWTOHAIGOTAIHI.KOJIN_NO THEN
                    IF g_rOldBUNNUM(i).BUNSHO_NO.NUMUMUFLG = 0 THEN
                      rGKBWL130R112.BUNSHO_NO := g_rOldBUNNUM(i).BUNSHO_NO.NUM;
                    ELSE
                      rGKBWL130R112.BUNSHO_NO := NULL;
                    END IF;
                  END IF;
                END LOOP;
                --発行年月日
                sHAKKONENGAPI := KKAPK0020.FNENDOHENKAN(g_vHAKKOYMD);
                rGKBWL130R112.HAKKO_YMD := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sHAKKONENGAPI), 'YYYY/MM/DD'), 12);
                --送付先氏名
                rGKBWL130R112.SOFUSAKI_SHIMEI := rGKBWTOHAIGOTAIHI.SOFU_ATENA;
                --送付先郵便番号
                rGKBWL130R112.SOFUSAKI_YUBIN_NO := rGKBWTOHAIGOTAIHI.SOFU_YUBIN;
                --送付先住所
                rGKBWL130R112.SOFUSAKI_JUSHO := rGKBWTOHAIGOTAIHI.SOFU_JUSHO || '　' || rGKBWTOHAIGOTAIHI.SOFU_KATAGAKI;
                nRTN := GKBFKHMCTRL(rGKBWTOHAIGOTAIHI.KOJIN_NO,
--  2025/07/01 CTC.LIUJUNHAO ADD START 1.0.010.001:GKB_QA17602対応
                                    --g_rJSTP.CHOHYOID,
                                    'GKB690R001',
--  2025/07/01 CTC.LIUJUNHAO ADD START 1.0.010.001:GKB_QA17602対応
                                    0,
                                    g_nTCL,
                                    rGKBWL130R112.JIDO_SHIMEI_KANA,    --児童生徒氏名カナ
                                    rGKBWL130R112.JIDO_SHIMEI_KANJI,   --児童生徒氏名漢字
                                    rGKBWL130R112.SEINENGAPI);         --生年月日
                --性別
                rGKBWL130R112.SEIBETSU := rGKBWTOHAIGOTAIHI.JIDO_SEIBETSU;
                --児童生徒_支援措置
                rGKBWL130R112.JIDO_SHIENSOCHI := rGKBWTOHAIGOTAIHI.JIDO_SHIENSOCHI;
                nRTN := GKBFKHMCTRL(rGKBWTOHAIGOTAIHI.KOJIN_NO,
--  2025/07/01 CTC.LIUJUNHAO ADD START 1.0.010.001:GKB_QA17602対応
                                    --g_rJSTP.CHOHYOID,
                                    'GKB690R001',
--  2025/07/01 CTC.LIUJUNHAO ADD START 1.0.010.001:GKB_QA17602対応
                                    1,
                                    g_nTCL,
                                    rGKBWL130R112.HOGOSHA_SHIMEI_KANA,    --保護者氏名カナ
                                    rGKBWL130R112.HOGOSHA_SHIMEI_KANJI,   --保護者氏名漢字
                                    temp);                                --生年月日
--  2025/07/01 CTC.LIUJUNHAO ADD START 1.0.010.001:GKB_QA17602対応]
               --送付先氏名再セット
               rGKBWL130R112.SOFUSAKI_SHIMEI := rGKBWL130R112.HOGOSHA_SHIMEI_KANJI;
--  2025/07/01 CTC.LIUJUNHAO ADD END 1.0.010.001:GKB_QA17602対応
                --児童生徒との関係
                rGKBWL130R112.HOGOSHA_ZOKUGARA := rGKBWTOHAIGOTAIHI.HOGOSHA_ZOKUGARA;
                --保護者_支援措置
                rGKBWL130R112.HOGOSHA_SHIENSOCHI := rGKBWTOHAIGOTAIHI.HOGOSHA_SHIENZOCHI;
                --学校名
                rGKBWL130R112.GAKKO_MEI := rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_MEI;
                --件数
                rGKBWL130R112.KENSU := g_nTSUCHICNT;
                --学校コード
                rGKBWL130R112.GAKKO_CD := rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU;
                --児童生徒氏名_ラベル
                rGKBWL130R112.JIDO_SHIMEI_LABEL := '児童生徒氏名';
                --保護者氏名_ラベル
                rGKBWL130R112.HOGOSHA_SHIMEI_LABEL := '保護者氏名';
                --学校/行政区_ラベル
                rGKBWL130R112.GAKO_GYOSEIKU_LABEL := '学校';
                --人格区分
                IF rGKBWTOHAIGOTAIHI.JINKAKU_KBN = 1 THEN
                  rGKBWL130R112.JINKAKU_KBN := '＊';
                ELSE
                  rGKBWL130R112.JINKAKU_KBN := NULL;
                END IF;
                --改ページキー
                rGKBWL130R112.BREAK_NO := LPAD(rGKBWTOHAIGOTAIHI.GAKKO_KBN, 3, 0) || LPAD(rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU, 3, 0) || LPAD(rGKBWTOHAIGOTAIHI.TENNYUGAKU_GAKUNEN, 2, 0);
                --端末番号
                rGKBWL130R112.WSNUM := g_sWSNUM;
                --即時バッチ区分
                rGKBWL130R112.BATCHKBN := 2;
                --ジョブNO
                rGKBWL130R112.JOBNUM := g_nJOBNUM;
                INSERT INTO GKBWL130R112 VALUES rGKBWL130R112;
            END LOOP;
          ELSE
            NULL;
        END CASE;
        --終了処理
        IF cCURSOR%ISOPEN THEN
          CLOSE cCURSOR;
        END IF;
        --関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            IF cCURSOR%ISOPEN THEN
              CLOSE cCURSOR;
            END IF;
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_CSV_CREATE;
    --------------------------------------------------------
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
    --------------------------------------------------------
    FUNCTION FUNC_B11CSV(i_TBLNAME IN NVARCHAR2) RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                      --戻り値
        nCSV_RCNT                     NUMBER;                       --CSVファイル出力件数
        sCSVFILENAME                  NVARCHAR2(1000);              --CSVファイル名
        sPRTFILENAME                  NVARCHAR2(1000);              --印刷ファイル名

    BEGIN
        -- 関数開始
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
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_B11CSV;
    --------------------------------------------------------
    --  機能概要      : 条件取得処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET RETURN BOOLEAN
    IS
    BEGIN
        --処理条件.発行日を西暦変換する
        g_vHAKKOYMD2 := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vHAKKOYMD));
        --表示異動日
        g_vIDOYMD2 := KKAPK0020.FDAYEDIT20(TO_NUMBER(g_vIDOYMD), 1, 3);
        --表示発行日
        g_vHAKKOYMDHIXYOJI := KKAPK0020.FDAYEDIT20(TO_NUMBER(g_vHAKKOYMD), 1, 3);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_JYOKEN_GET;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                      --戻り値

    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        --初期処理
        IF NOT FUNC_INIT THEN
          RETURN FALSE;
        END IF;

        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB690R001' THEN
            DELETE FROM GKBWL690R001
            WHERE WSNUM = g_sWSNUM
            AND BATCHKBN = c_BATCH;
            --ＣＳＶファイル作成処理
            IF NOT FUNC_CSV_CREATE THEN
              RETURN FALSE;
            END IF;
            --CSV出力処理を呼び出す
            bRTN := FUNC_B11CSV('GKBWL690R001');
          WHEN 'GKB130R002' THEN
            DELETE FROM GKBWL130R112
            WHERE WSNUM = g_sWSNUM
            AND BATCHKBN = c_BATCH;
            --ＣＳＶファイル作成処理
            IF NOT FUNC_CSV_CREATE THEN
              RETURN FALSE;
            END IF;
            --CSV出力処理を呼び出す
            bRTN := FUNC_B11CSV('GKBWL130R112');
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                 --戻り値
        nRTN                          NUMBER;                  --戻り値
        eEXCEPTION                    EXCEPTION;
        aPRM                          A_CONS_PRM;
        nSOTONENDO                    NUMBER;                  --対象年度
        nMM                           NUMBER;                  --月
        nYY                           NUMBER;                  --年
        nMAXNENDO                     NUMBER;                  --MAX(年度)
        sSQL                          NVARCHAR2(32767);        --SQL文
        nKOUSINFLG                    NUMBER;                  --更新対象フラグ
        sBIKO                         NVARCHAR2(1000);         --備考
        rGKBWTOHAIGOTAIHI             GKBWTOHAIGOTAIHI%ROWTYPE;--新設・統廃合退避ワークレコード
        o_rGABTATENAKIHON             GABTATENAKIHON%ROWTYPE;  --保護者の宛名基本
        o_rGABTSOFUSAKI               GABTSOFUSAKI%ROWTYPE;    --保護者の送付先基本
        o_rGABTATENAKIHON_2           GABTATENAKIHON%ROWTYPE;  --児童生徒の宛名基本
        o_rGABTSOFUSAKI_2             GABTSOFUSAKI%ROWTYPE;    --児童生徒の送付先基本
        rGKBTGAKUREIBO_2              GKBTGAKUREIBO%ROWTYPE;   --学齢簿
        sMEISHO                       NVARCHAR2(1000);         --名称
        sMEISHOKANA                   NVARCHAR2(1000);         --名称カナ
        sYOBI                         NVARCHAR2(1000);         --予備
        nKOJINSETAIKBN                NUMBER;                  --個人世帯区分（0：個人、1：世帯）
        nYOKUSHIKBN                   NUMBER;                  --抑止区分（1：支援措置、2：仮支援措置、4：その他抑止）
        nIDOYOKUSHIKBN                NUMBER;                  --異動抑止区分（0：非該当、1：警告、2：論理）
        nHAKKOYOKUSHIKBN              NUMBER;                  --発行抑止区分（0：非該当、1：警告、2：論理）
        nSHOKAIYOKUSHIKBN             NUMBER;                  --照会抑止区分（0：非該当、1：警告、2：論理）
        vSHORICHUIKBN                 NVARCHAR2(1000);         --処理注意区分（任意設定）
        nGKBTGAKUREIBOSEQ             NUMBER;                  --学齢簿最新履歴連番
        nGKBTSHUGAKURIREKISEQ         NUMBER;                  --就学履歴最新履歴連番
        nGKBTGAKUNENRIREKISEQ         NUMBER;                  --学年履歴最新履歴連番
        --  2024/10/18 ZCZL.ZHANGLEI ADD 0.3.000.007:IT_GKB_00282対応
        vSEINENGAPI                   NVARCHAR2(10);
        TYPE MC_CURSOR IS REF CURSOR;
        cCURSOR                       MC_CURSOR;
        cCURSOR2                      MC_CURSOR;
        TYPE MR_GKBTGAKUREIBO IS RECORD(
            KOJIN_NO                  GKBTGAKUREIBO.KOJIN_NO%TYPE,
            GAKKO_KBN                 GKBTGAKUNENRIREKI.GAKKO_KBN_CD%TYPE,
            GAKUNEN                   GKBTGAKUREIBO.GAKUNEN%TYPE,
            TSUJO_SHUGAKUYOTEIKO      GKBTGAKUNENRIREKI.GAKKO_CD%TYPE,
            NOW_SHUGAKUSHITEIKO_SHO   GKBTGAKUREIBO.SHITEI_SYOGAKO_CD%TYPE,
            NOW_SHUGAKUSHITEIKO_CHU   GKBTGAKUREIBO.SHITEI_TYUGAKO_CD%TYPE,
            NEW_SHUGAKUSHITEIKO_KBN   NUMBER,
            NEW_SHUGAKUSHITEIKO       GKBTSHOGAKKO.SYOGAKO_CD%TYPE,
            NEW_SHUGAKUSHITEIKO_MEI   GKBTSHOGAKKO.SYOGAKOMEI%TYPE,
            NEW_KYOIKUIINKAI_CD       GKBTSHOGAKKO.KYOIKUIINKAI_CD%TYPE,
            NEW_GAKKOKU_CD            GKBTSHOGAKKO.GAKKOKU_CD%TYPE,
            SAISHIN_TENNYUGAKU_BI     GKBTGAKUREIBO.SYOGAKO_TENNYUGAKU_BI%TYPE
        );
        rGKBTGAKUREIBO                MR_GKBTGAKUREIBO;        --学齢簿・学年履歴カーソル

        TYPE MR_GKBWTOHAIGOTAIHI IS RECORD(
            KOJIN_NO                  GKBWTOHAIGOTAIHI.KOJIN_NO%TYPE,
            UPDATE_FLG                GKBWTOHAIGOTAIHI.UPDATE_FLG%TYPE,
            NOW_GAKUNEN               GKBWTOHAIGOTAIHI.NOW_GAKUNEN%TYPE,
            TENNYUGAKU_GAKUNEN        GKBWTOHAIGOTAIHI.TENNYUGAKU_GAKUNEN%TYPE,
            GAKKO_KBN                 GKBWTOHAIGOTAIHI.GAKKO_KBN%TYPE,
            TSUJO_SHUGAKUYOTEIKO      GKBWTOHAIGOTAIHI.TSUJO_SHUGAKUYOTEIKO%TYPE,
            TSUJO_SHUGAKUYOTEIKO_MEI  GKBWTOHAIGOTAIHI.TSUJO_SHUGAKUYOTEIKO_MEI%TYPE,
            NEW_SHUGAKUSHITEIKOU_KBN  GKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN%TYPE,
            NEW_SHUGAKUSHITEIKOU      GKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU%TYPE,
            NEW_SHUGAKUSHITEIKOU_MEI  GKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_MEI%TYPE,
            NEW_KYOIKUIINKAI_CD       GKBWTOHAIGOTAIHI.NEW_KYOIKUIINKAI_CD%TYPE,
            NEW_GAKKOKU_CD            GKBWTOHAIGOTAIHI.NEW_GAKKOKU_CD%TYPE,
            BIKO                      GKBWTOHAIGOTAIHI.BIKO%TYPE,
            SOFU_YUBIN                GKBWTOHAIGOTAIHI.SOFU_YUBIN%TYPE,
            SOFU_JUSHO                GKBWTOHAIGOTAIHI.SOFU_JUSHO%TYPE,
            SOFU_KATAGAKI             GKBWTOHAIGOTAIHI.SOFU_KATAGAKI%TYPE,
            SOFU_ATENA                GKBWTOHAIGOTAIHI.SOFU_ATENA%TYPE,
            YUBIN_NOBC                GKBWTOHAIGOTAIHI.YUBIN_NOBC%TYPE,
            JIDO_SHIMEI_KANA          GKBWTOHAIGOTAIHI.JIDO_SHIMEI_KANA%TYPE,
            JIDO_SHIMEI_KANJI         GKBWTOHAIGOTAIHI.JIDO_SHIMEI_KANJI%TYPE,
            JIDO_SEIBETSU             GKBWTOHAIGOTAIHI.JIDO_SEIBETSU%TYPE,
            JIDO_SHIENSOCHI           GKBWTOHAIGOTAIHI.JIDO_SHIENSOCHI%TYPE,
            JIDO_SEINENGAPI           GKBWTOHAIGOTAIHI.JIDO_SEINENGAPI%TYPE,
            JIDO_JUSHO                GKBWTOHAIGOTAIHI.JIDO_JUSHO%TYPE,
            HOGOSHA_KOJIJN_NO         GKBWTOHAIGOTAIHI.HOGOSHA_KOJIJN_NO%TYPE,
            HOGOSHA_SHIMEI_KANA       GKBWTOHAIGOTAIHI.HOGOSHA_SHIMEI_KANA%TYPE,
            HOGOSHA_SHIMEI_KANJI      GKBWTOHAIGOTAIHI.HOGOSHA_SHIMEI_KANJI%TYPE,
            HOGOSHA_ZOKUGARA          GKBWTOHAIGOTAIHI.HOGOSHA_ZOKUGARA%TYPE,
            HOGOSHA_SHIENZOCHI        GKBWTOHAIGOTAIHI.HOGOSHA_SHIENZOCHI%TYPE,
            JINKAKU_KBN               GKBWTOHAIGOTAIHI.JINKAKU_KBN%TYPE,
            WSNUM                     GKBWTOHAIGOTAIHI.WSNUM%TYPE,
            BATCHKBN                  GKBWTOHAIGOTAIHI.BATCHKBN%TYPE,
            JOBNUM                    GKBWTOHAIGOTAIHI.JOBNUM%TYPE
        );
        rDATA                         MR_GKBWTOHAIGOTAIHI;           --新設・統廃合退避ワークカーソル

        TYPE MR_GTG IS RECORD(
            KOJIN_NO                       NUMBER := 0,              --宛名番号
            RIREKI_RENBAN                  NUMBER := 0,              --履歴連番
            RIREKI_RENBAN_EDA              NUMBER := 0,              --児童生徒_個人履歴番号枝番
            GENZON_KBN                     NUMBER := 0,              --現存区分
            SAISHIN_KBN                    NUMBER := 0,              --最新区分
            ZO_JIYU_CD                     NUMBER := 0,              --増事由コード
            ZO_NENGAPI                     NUMBER := 0,              --増年月日
            GEN_JIYU_CD                    NUMBER := 0,              --減事由コー
            GEN_NENGAPI                    NUMBER := 0,              --減年月日
            ZOKUGARA1                      NUMBER := 0,              --続柄１
            ZOKUGARA2                      NUMBER := 0,              --続柄２
            ZOKUGARA3                      NUMBER := 0,              --続柄３
            ZOKUGARA4                      NUMBER := 0,              --続柄４
            HOGOSYA_KOJIN_NO               NUMBER := 0,              --保護者宛名番号
            HOGOSYA_ZOKUGARA1              NUMBER := 0,              --保護者続柄１
            HOGOSYA_ZOKUGARA2              NUMBER := 0,              --保護者続柄２
            HOGOSYA_ZOKUGARA3              NUMBER := 0,              --保護者続柄３
            HOGOSYA_ZOKUGARA4              NUMBER := 0,              --保護者続柄４
            SYOGAKO_CD                     NUMBER := 0,              --小学校コード
            SYOGAKO_NYUGAKU_BI             NUMBER := 0,              --小学校入学年月日
            SYOGAKO_TENNYUGAKU_BI          NUMBER := 0,              --小学校転入学年月日
            SYOGAKO_TENGAKU_BI             NUMBER := 0,              --小学校転学年月日
            SYOGAKO_SOTSUGYO_BI            NUMBER := 0,              --小学校卒業年月日
            TYUGAKO_CD                     NUMBER := 0,              --中学校コード
            TYUGAKO_NYUGAKU_BI             NUMBER := 0,              --中学校入学年月日
            TYUGAKO_TENNYUGAKU_BI          NUMBER := 0,              --中学校転入学年月日
            TYUGAKO_TENGAKU_BI             NUMBER := 0,              --中学校転学年月日
            TYUGAKO_SOTSUGYO_BI            NUMBER := 0,              --中学校卒業年月日
            TOKUSOKU_BI1                   NUMBER := 0,              --督促年月日1
            TOKUSOKU_NAIYO1                NVARCHAR2(1000),          --督促内容１
            TOKUSOKU_JIYU1                 NUMBER := 0,              --督促事由１
            TOKUSOKU_JURI_BI1              NUMBER := 0,              --督促受理年月日１
            TOKUSOKU_BI2                   NUMBER := 0,              --督促年月日２
            TOKUSOKU_NAIYO2                NVARCHAR2(1000),          --督促内容２
            TOKUSOKU_JIYU2                 NUMBER := 0,              --督促事由2
            TOKUSOKU_JURI_BI2              NUMBER := 0,              --督促受理年月日2
            TOKUSOKU_BI3                   NUMBER := 0,              --督促年月日３
            TOKUSOKU_NAIYO3                NVARCHAR2(1000),          --督促内容３
            TOKUSOKU_JIYU3                 NUMBER := 0,              --督促事由3
            TOKUSOKU_JURI_BI3              NUMBER := 0,              --督促受理年月日3
            TOKUSOKU_BI4                   NUMBER := 0,              --督促年月日４
            TOKUSOKU_NAIYO4                NVARCHAR2(1000),          --督促内容４
            TOKUSOKU_JIYU4                 NUMBER := 0,              --督促事由4
            TOKUSOKU_JURI_BI4              NUMBER := 0,              --督促受理年月日4
            TOKUSOKU_BI5                   NUMBER := 0,              --督促年月日５
            TOKUSOKU_NAIYO5                NVARCHAR2(1000),          --督促内容５
            TOKUSOKU_JIYU5                 NUMBER := 0,              --督促事由5
            TOKUSOKU_JURI_BI5              NUMBER := 0,              --督促受理年月日5
            TOKUSOKU_BI6                   NUMBER := 0,              --督促年月日6
            TOKUSOKU_NAIYO6                NVARCHAR2(1000),          --督促内容6
            TOKUSOKU_JIYU6                 NUMBER := 0,              --督促事由6
            TOKUSOKU_JURI_BI6              NUMBER := 0,              --督促受理年月日6
            TOKUSOKU_BI7                   NUMBER := 0,              --督促年月日7
            TOKUSOKU_NAIYO7                NVARCHAR2(1000),          --督促内容7
            TOKUSOKU_JIYU7                 NUMBER := 0,              --督促事由7
            TOKUSOKU_JURI_BI7              NUMBER := 0,              --督促受理年月日7
            TOKUSOKU_BI8                   NUMBER := 0,              --督促年月日8
            TOKUSOKU_NAIYO8                NVARCHAR2(1000),          --督促内容8
            TOKUSOKU_JIYU8                 NUMBER := 0,              --督促事由8
            TOKUSOKU_JURI_BI8              NUMBER := 0,              --督促受理年月日8
            TOKUSOKU_BI9                   NUMBER := 0,              --督促年月日9
            TOKUSOKU_NAIYO9                NVARCHAR2(1000),          --督促内容9
            TOKUSOKU_JIYU9                 NUMBER := 0,              --督促事由9
            TOKUSOKU_JURI_BI9              NUMBER := 0,              --督促受理年月日9
            TOKUSOKU_BI10                  NUMBER := 0,              --督促年月日10
            TOKUSOKU_NAIYO10               NVARCHAR2(1000),          --督促内容10
            TOKUSOKU_JIYU10                NUMBER := 0,              --督促事由10
            TOKUSOKU_JURI_BI10             NUMBER := 0,              --督促受理年月日10
            KUIKIGAI_CD                    NUMBER := 0,              --区域外学校コード
            KUIKIGAI_SETISYA               NVARCHAR2(1000),          --区域外設置者名
            KUIKIGAI_NYUGAKU_BI            NUMBER := 0,              --区域外入学年月日
            KUIKIGAI_TENNYUGAKU_BI         NUMBER := 0,              --区域外転入学年月日
            KUIKIGAI_TENGAKU_BI            NUMBER := 0,              --区域外転学年月日
            KUIKIGAI_TAIGAKU_BI            NUMBER := 0,              --区域外退学年月日
            KUIKIGAI_SOTSUGYO_BI           NUMBER := 0,              --区域外卒業年月日
            YOGOGAKO_CD                    NUMBER := 0,              --盲聾養護学校コード
            YOGOGAKO_SETISYA               NVARCHAR2(1000),          --盲聾養護設置者名
            YOGOGAKO_NYUGAKU_BI            NUMBER := 0,              --盲聾養護学校入学年月日
            YOGOGAKO_TENNYUGAKU_BI         NUMBER := 0,              --盲聾養護学校転入学年月日
            YOGOGAKO_TENGAKU_BI            NUMBER := 0,              --盲聾養護学校転学年月日
            YOGOGAKO_TAIGAKU_BI            NUMBER := 0,              --盲聾養護学校退学年月日
            YOGOGAKO_SOTSUGYO_BI           NUMBER := 0,              --盲聾養護学校卒業年月日
            YUYO_KYOKA_BI                  NUMBER := 0,              --就学猶予許可年月日
            YUYO_JIYU_CD                   NUMBER := 0,              --就学猶予事由コード
            YUYO_JIYU                      NVARCHAR2(1000),          --就学猶予事由
            YUYO_KAISI_BI                  NUMBER := 0,              --就学猶予開始年月日
            YUYO_SYURYO_BI                 NUMBER := 0,              --就学猶予終了年月日
            YUYO_NENSU                     NUMBER := 0,              --就学猶予_年数
            YUYO_FUKUGAKU_BI               NUMBER := 0,              --就学猶予復学年月日
            MENJO_KYOKA_BI                 NUMBER := 0,              --就学免除許可年月日
            MENJO_JIYU_CD                  NUMBER := 0,              --就学免除事由コード
            MENJO_JIYU                     NVARCHAR2(1000),          --就学免除事由
            MENJO_KAISI_BI                 NUMBER := 0,              --就学免除_開始年月日
            MENJO_SYURYO_BI                NUMBER := 0,              --就学免除_終了年月日
            MENJO_NENSU                    NUMBER := 0,              --就学免除_年数
            MENJO_FUKUGAKU_BI              NUMBER := 0,              --就学免除復学年月日
            IDO_BI1                        NUMBER := 0,              --異動日1
            IDO_JIYU1                      NVARCHAR2(1000),          --異動事由1
            IDO_BI2                        NUMBER := 0,              --異動日２
            IDO_JIYU2                      NVARCHAR2(1000),          --異動事由２
            IDO_BI3                        NUMBER := 0,              --異動日３
            IDO_JIYU3                      NVARCHAR2(1000),          --異動事由３
            IDO_BI4                        NUMBER := 0,              --異動日４
            IDO_JIYU4                      NVARCHAR2(1000),          --異動事由４
            IDO_BI5                        NUMBER := 0,              --異動日５
            IDO_JIYU5                      NVARCHAR2(1000),          --異動事由５
            IDO_BI6                        NUMBER := 0,              --異動日６
            IDO_JIYU6                      NVARCHAR2(1000),          --異動事由６
            IDO_BI7                        NUMBER := 0,              --異動日７
            IDO_JIYU7                      NVARCHAR2(1000),          --異動事由７
            IDO_BI8                        NUMBER := 0,              --異動日８
            IDO_JIYU8                      NVARCHAR2(1000),          --異動事由８
            IDO_BI9                        NUMBER := 0,              --異動日９
            IDO_JIYU9                      NVARCHAR2(1000),          --異動事由９
            IDO_BI10                       NUMBER := 0,              --異動日１０
            IDO_JIYU10                     NVARCHAR2(1000),          --異動事由１０
            SYS_SAKUSEIBI                  NUMBER := 0,              --作成日
            SYS_KOSHINBI                   NUMBER := 0,              --更新日
            SYS_JIKAN                      NUMBER := 0,              --更新時間
            SYS_SHOKUINKOJIN_NO            NVARCHAR2(1000),          --更新職員宛名番号
            SYS_TANMATU_NO                 NVARCHAR2(1000),          --更新端末番号
            GAKUNEN                        NUMBER := 0,              --学年
            SHORIBI                        NUMBER := 0,              --処理日
            SHUGAKU                        NVARCHAR2(1000),          --就学状況
            IDOJIKO                        NVARCHAR2(1000),          --異動事項
            CHOHYO_NO                      NUMBER := 0,              --帳票連番
            SYOGAKO_TENNYUGAKU_GAKUNEN     NUMBER := 0,              --小学校転入学 学年
            SYOGAKO_TENGAKU_GAKUNEN        NUMBER := 0,              --小学校転学 学年
            TYUGAKO_TENNYUGAKU_GAKUNEN     NUMBER := 0,              --中学校転入学 学年
            TYUGAKO_TENGAKU_GAKUNEN        NUMBER := 0,              --中学校転学 学年
            KUIKIGAI_TENNYUGAKU_GAKUNEN    NUMBER := 0,              --区域外転入学 学年
            KUIKIGAI_TENGAKU_GAKUNEN       NUMBER := 0,              --区域外転学 学年
            KUIKIGAI_TAIGAKU_GAKUNEN       NUMBER := 0,              --区域外退学 学年
            YOGOGAKO_TENNYUGAKU_GAKUNEN    NUMBER := 0,              --盲聾養護学校転入学 学年
            YOGOGAKO_TENGAKU_GAKUNEN       NUMBER := 0,              --盲聾養護学校転学 学年
            YOGOGAKO_TAIGAKU_GAKUNEN       NUMBER := 0,              --盲聾養護学校退学 学年
            GAKKO_KBN_CD                   NUMBER := 0,              --学校区分コード
            GAKUKYU_CD                     NUMBER := 0,              --学級コード
            SEIBETSU                       NUMBER := 0,              --児童生徒_性別
            JOTAI                          NUMBER := 0,              --状態
            TENNYUMAE_GAKKO_KBN            NUMBER := 0,              --転入前学校区分
            TENNYUMAE_GAKKO_CD             NUMBER := 0,              --転入前学校
            TENNYUMAE_GAKUNEN              NUMBER := 0,              --転入前学年
            GENKYURYUCHI_FLG               NUMBER := 0,              --原級留置_対象者フラグ
            GENKYURYUCHI_KETTEI_BI         NUMBER := 0,              --原級留置_決定年月日
            GENKYURYUCHI_KAISI_BI          NUMBER := 0,              --原級留置_開始年月日
            GENKYURYUCHI_SYURYOBI          NUMBER := 0,              --原級留置_終了年月日
            GENKYURYUCHI_RIYU              NUMBER := 0,              --原級留置_理由
            SHITEI_SYOGAKO_CD              NUMBER := 0,              --就学指定校_小学校
            SHITEI_TYUGAKO_CD              NUMBER := 0,              --就学指定校_中学校
            HENKO_GAKUNEN_SYOGAKO          NUMBER := 0,              --就学校変更_開始学年_小学校
            HENKO_GAKUNEN_TYUGAKO          NUMBER := 0,              --就学校変更_開始学年_中学校
            HENKO_SHINSEI_BI               NUMBER := 0,              --就学校変更_申請年月日
            HENKO_KYOKA_BI                 NUMBER := 0,              --就学校変更_許可年月日
            HENKO_KBN                      NUMBER := 0,              --就学校変更_区分
            HENKO_KAISI_BI                 NUMBER := 0,              --就学校変更_開始年月日
            HENKO_SYURYO_BI                NUMBER := 0,              --就学校変更_終了年月日
            HENKO_KYOKA_RIYU               NUMBER := 0,              --就学校変更_許可理由
            HENKO_JIYU                     NUMBER := 0,              --就学校変更_事由
            HENKO_HUKYOKA_RIYU             NVARCHAR2(1000),          --就学校変更_不許可理由
            KIBO_GAKKO_KBN_CD              NUMBER := 0,              --希望就学校_学校区分コード
            KIBO_SYOGAKKO_CD               NUMBER := 0,              --希望就学校_小学校
            KIBO_TYUGAKKO_CD               NUMBER := 0,              --希望就学校_中学校
            KIBO_UKETSUKE_BI_SYOGAKO       NUMBER := 0,              --希望就学校_受付年月日_小学校
            KIBO_UKETSUKE_BI_TYUGAKO       NUMBER := 0,              --希望就学校_受付年月日_中学校
            KUIKIGAISHUGAKU_FLG            NUMBER := 0,              --区域外就学フラグ
            KUIKIGAISHUGAKU_SHINSEI_BI     NUMBER := 0,              --区域外就学_申請年月日
            KUIKIGAISHUGAKU_KYOKA_BI       NUMBER := 0,              --区域外就学_許可年月日
            KUIKIGAISHUGAKU_KAISI_BI       NUMBER := 0,              --区域外就学_開始年月日
            KUIKIGAISHUGAKU_SYURYO_BI      NUMBER := 0,              --区域外就学_終了年月日
            KUIKIGAISHUGAKU_JIYU           NUMBER := 0,              --区域外就学_事由
            KUIKIGAISHUGAKU_KYOKA_RIYU     NUMBER := 0,              --区域外就学_許可理由
            KUIKIGAISHUGAKU_HUKYOKA_RIYU   NVARCHAR2(1000),          --区域外就学_不許可理由
            HUSHUGAKU_KAISI_BI             NUMBER := 0,              --不就学_開始年月日
            HUSHUGAKU_SYURYO_BI            NUMBER := 0,              --不就学_終了年月日
            HUSHUGAKU_RIYU                 NUMBER := 0,              --不就学_理由
            KUNISHIRITSU_CD                NUMBER := 0,              --国私立学校コード
            KUNISHIRITSU_NYUGAKU_BI        NUMBER := 0,              --国私立入学年月日
            KUNISHIRITSU_TENNYUGAKU_BI     NUMBER := 0,              --国私立転入学年月日
            KUNISHIRITSU_TENNYUGAKU_GAKUNEN NUMBER,                  --国私立転入学 学年
            KUNISHIRITSU_TENGAKU_BI        NUMBER := 0,              --国私立転学年月日
            KUNISHIRITSU_TENGAKU_GAKUNEN   NUMBER := 0,              --国私立転学 学年
            KUNISHIRITSU_TAIGAKU_BI        NUMBER := 0,              --国私立退学年月日
            KUNISHIRITSU_TAIGAKU_GAKUNEN   NUMBER := 0,              --国私立退学 学年
            KUNISHIRITSU_SOTSUGYO_BI       NUMBER := 0,              --国私立卒業年月日
            KUNISHIRITSU_KAISI_BI          NUMBER := 0,              --国私立開始年月日
            KUNISHIRITSU_SYURYO_BI         NUMBER := 0,              --国私立終了年月日
            TSUSHOMEI_KANA                 NVARCHAR2(1000),          --通称名カナ
            TSUSHOMEI_KANJI                NVARCHAR2(1000),          --通称名
            HOGOSHA_TSUSHOMEI_KANA         NVARCHAR2(1000),          --保護者通称名カナ
            HOGOSHA_TSUSHOMEI_KANJI        NVARCHAR2(1000),          --保護者通称名
            GRB_HENKO_TODOKEDE_BI          NUMBER := 0,              --学齢簿変更_届出年月日
            GRB_HENKO_BI                   NUMBER := 0,              --学齢簿変更_年月日
            GRB_HENKO_JIYU                 NUMBER := 0,              --学齢簿変更_事由
            BIKO                           NVARCHAR2(1000),          --備考
            IDO_BI                         NUMBER := 0,              --異動年月日
            TODOKEDE_BI                    NUMBER := 0,              --届出年月日
            SHINSEI_KANRI_RENBAN           NUMBER := 0,              --申請管理連番
            IDOJI_ATENA_RIREKI_RENBAN      NUMBER := 0,              --異動時宛名基本履歴連番
            HOGOSYA_IDOJI_RIREKI_RENBAN    NUMBER := 0,              --異動時保護者宛名基本履歴連番
            SHOGAKKOKU_CD                  NVARCHAR2(1000),          --小学校区コード
            CHUGAKKOKU_CD                  NVARCHAR2(1000),          --中学校区コード
            SAKUJO_FLG                     NUMBER := 0,              --削除フラグ
            SYS_TANMATU_BASHO              NVARCHAR2(1000)           --入力端末_入力場所
        );
        rGTG1                              MR_GTG;
        rGTG2                              MR_GTG;                   --元

        TYPE MR_GTR IS RECORD(
            KOJIN_NO                       NUMBER := 0,              --児童生徒_宛名番号
            NENDO                          NUMBER := 0,              --年度
            KOJIN_RIREKI_RENBAN            NUMBER := 0,              --児童生徒_個人履歴番号
            SHUGAKU_RIREKI_RENBAN          NUMBER := 0,              --就学履歴番号
            SAISHIN_FLG                    NUMBER := 0,              --最新フラグ
            S_CD                           NUMBER := 0,              --小学校コード
            S_NYUGAKU_BI                   NUMBER := 0,              --小学校_入学年月日
            S_TENNYU_BI                    NUMBER := 0,              --小学校_転入学年月日
            S_TENNYU_GAKUNEN               NUMBER := 0,              --小学校_転入学学年
            S_TENGAKU_BI                   NUMBER := 0,              --小学校_転学年月日
            S_TENGAKU_GAKUNEN              NUMBER := 0,              --小学校_転学学年
            S_TAIGAKU_BI                   NUMBER := 0,              --小学校_退学年月日
            S_TAIGAKU_GAKUNEN              NUMBER := 0,              --小学校_退学学年
            S_SOTSUGYO_BI                  NUMBER := 0,              --小学校_卒業年月日
            T_CD                           NUMBER := 0,              --中学校コード
            T_NYUGAKU_BI                   NUMBER := 0,              --中学校_入学年月日
            T_TENNYU_BI                    NUMBER := 0,              --中学校_転入学年月日
            T_TENNYU_GAKUNEN               NUMBER := 0,              --中学校_転入学学年
            T_TENGAKU_BI                   NUMBER := 0,              --中学校_転学年月日
            T_TENGAKU_GAKUNEN              NUMBER := 0,              --中学校_転学学年
            T_TAIGAKU_BI                   NUMBER := 0,              --中学校_退学年月日
            T_TAIGAKU_GAKUNEN              NUMBER := 0,              --中学校_退学学年
            T_SOTSUGYO_BI                  NUMBER := 0,              --中学校_卒業年月日
            SHIEN_BU_CD                    NUMBER := 0,              --特別支援学校_部コード
            SHIEN_S_CD                     NUMBER := 0,              --特別支援学校_小学校コード
            SHIEN_S_HUKUSEKI_CD            NUMBER := 0,              --特別支援学校_小学校部_副籍校コード
            SHIEN_S_NYUGAKU_BI             NUMBER := 0,              --特別支援学校_小学校部_入学年月日
            SHIEN_S_TENNYU_BI              NUMBER := 0,              --特別支援学校_小学校部_転入学年月日
            SHIEN_S_TENNYU_GAKUNEN         NUMBER := 0,              --特別支援学校_小学校部_転入学学年
            SHIEN_S_TENGAKU_BI             NUMBER := 0,              --特別支援学校_小学校部_転学年月日
            SHIEN_S_TENGAKU_GAKUNEN        NUMBER := 0,              --特別支援学校_小学校部_転学学年
            SHIEN_S_TAIGAKU_BI             NUMBER := 0,              --特別支援学校_小学校部_退学年月日
            SHIEN_S_TAIGAKU_GAKUNEN        NUMBER := 0,              --特別支援学校_小学校部_退学学年
            SHIEN_S_SOTSUGYO_BI            NUMBER := 0,              --特別支援学校_小学校部_卒業年月日
            SHIEN_T_CD                     NUMBER := 0,              --特別支援学校_中学校コード
            SHIEN_T_HUKUSEKI_CD            NUMBER := 0,              --特別支援学校_中学校部_副籍校コード
            SHIEN_T_NYUGAKU_BI             NUMBER := 0,              --特別支援学校_中学校部_入学年月日
            SHIEN_T_TENNYU_BI              NUMBER := 0,              --特別支援学校_中学校部_転入学年月日
            SHIEN_T_TENNYU_GAKUNEN         NUMBER := 0,              --特別支援学校_中学校部_転入学学年
            SHIEN_T_TENGAKU_BI             NUMBER := 0,              --特別支援学校_中学校部_転学年月日
            SHIEN_T_TENGAKU_GAKUNEN        NUMBER := 0,              --特別支援学校_中学校部_転学学年
            SHIEN_T_TAIGAKU_BI             NUMBER := 0,              --特別支援学校_中学校部_退学年月日
            SHIEN_T_TAIGAKU_GAKUNEN        NUMBER := 0,              --特別支援学校_中学校部_退学学年
            SHIEN_T_SOTSUGYO_BI            NUMBER := 0,              --特別支援学校_中学校部_卒業年月日
            KUIKIGAI_S_CD                  NUMBER := 0,              --区域外就学_小学校コード
            KUIKIGAI_S_KAISHI_GAKUNEN      NUMBER := 0,              --区域外就学_小学校_開始学年
            KUIKIGAI_S_NYUGAKU_BI          NUMBER := 0,              --区域外就学_小学校_入学年月日
            KUIKIGAI_S_TENNYU_BI           NUMBER := 0,              --区域外就学_小学校_転入学年月日
            KUIKIGAI_S_TENNYU_GAKUNEN      NUMBER := 0,              --区域外就学_小学校_転入学学年
            KUIKIGAI_S_TENGAKU_BI          NUMBER := 0,              --区域外就学_小学校_転学年月日
            KUIKIGAI_S_TENGAKU_GAKUNEN     NUMBER := 0,              --区域外就学_小学校_転学学年
            KUIKIGAI_S_TAIGAKU_BI          NUMBER := 0,              --区域外就学_小学校_退学年月日
            KUIKIGAI_S_TAIGAKU_GAKUNEN     NUMBER := 0,              --区域外就学_小学校_退学学年
            KUIKIGAI_S_SOTSUGYO_BI         NUMBER := 0,              --区域外就学_小学校_卒業年月日
            KUIKIGAI_S_KAISHI_BI           NUMBER := 0,              --区域外就学_小学校_開始年月日
            KUIKIGAI_S_SHURYO_BI           NUMBER := 0,              --区域外就学_小学校_終了年月日
            KUIKIGAI_S_KAIJO_BI            NUMBER := 0,              --区域外就学_小学校_解除年月日
            KUIKIGAI_T_CD                  NUMBER := 0,              --区域外就学_中学校コード
            KUIKIGAI_T_KAISHI_GAKUNEN      NUMBER := 0,              --区域外就学_中学校_開始学年
            KUIKIGAI_T_NYUGAKU_BI          NUMBER := 0,              --区域外就学_中学校_入学年月日
            KUIKIGAI_T_TENNYU_BI           NUMBER := 0,              --区域外就学_中学校_転入学年月日
            KUIKIGAI_T_TENNYU_GAKUNEN      NUMBER := 0,              --区域外就学_中学校_転入学学年
            KUIKIGAI_T_TENGAKU_BI          NUMBER := 0,              --区域外就学_中学校_転学年月日
            KUIKIGAI_T_TENGAKU_GAKUNEN     NUMBER := 0,              --区域外就学_中学校_転学学年
            KUIKIGAI_T_TAIGAKU_BI          NUMBER := 0,              --区域外就学_中学校_退学年月日
            KUIKIGAI_T_TAIGAKU_GAKUNEN     NUMBER := 0,              --区域外就学_中学校_退学学年
            KUIKIGAI_T_SOTSUGYO_BI         NUMBER := 0,              --区域外就学_中学校_卒業年月日
            KUIKIGAI_T_KAISHI_BI           NUMBER := 0,              --区域外就学_中学校_開始年月日
            KUIKIGAI_T_SHURYO_BI           NUMBER := 0,              --区域外就学_中学校_終了年月日
            KUIKIGAI_T_KAIJO_BI            NUMBER := 0,              --区域外就学_中学校_解除年月日
            KUNISHIRITSU_S_CD              NUMBER := 0,              --国・私立学校_小学校コード
            KUNISHIRITSU_S_NYUGAKU_BI      NUMBER := 0,              --国・私立学校_小学校_入学年月日
            KUNISHIRITSU_S_TENNYU_BI       NUMBER := 0,              --国・私立学校_小学校_転入学年月日
            KUNISHIRITSU_S_TENNYU_GAKUNEN  NUMBER := 0,              --国・私立学校_小学校_転入学学年
            KUNISHIRITSU_S_TENGAKU_BI      NUMBER := 0,              --国・私立学校_小学校_転学年月日
            KUNISHIRITSU_S_TENGAKU_GAKUNEN NUMBER := 0,              --国・私立学校_小学校_転学学年
            KUNISHIRITSU_S_TAIGAKU_BI      NUMBER := 0,              --国・私立学校_小学校_退学年月日
            KUNISHIRITSU_S_TAIGAKU_GAKUNEN NUMBER := 0,              --国・私立学校_小学校_退学学年
            KUNISHIRITSU_S_SOTSUGYO_BI     NUMBER := 0,              --国・私立学校_小学校_卒業年月日
            KUNISHIRITSU_S_KAISHI_BI       NUMBER := 0,              --国・私立学校_小学校_就学開始年月日
            KUNISHIRITSU_S_SHURYO_BI       NUMBER := 0,              --国・私立学校_小学校_就学終了年月日
            KUNISHIRITSU_T_CD              NUMBER := 0,              --国・私立学校_中学校コード
            KUNISHIRITSU_T_NYUGAKU_BI      NUMBER := 0,              --国・私立学校_中学校_入学年月日
            KUNISHIRITSU_T_TENNYU_BI       NUMBER := 0,              --国・私立学校_中学校_転入学年月日
            KUNISHIRITSU_T_TENNYU_GAKUNEN  NUMBER := 0,              --国・私立学校_中学校_転入学学年
            KUNISHIRITSU_T_TENGAKU_BI      NUMBER := 0,              --国・私立学校_中学校_転学年月日
            KUNISHIRITSU_T_TENGAKU_GAKUNEN NUMBER := 0,              --国・私立学校_中学校_転学学年
            KUNISHIRITSU_T_TAIGAKU_BI      NUMBER := 0,              --国・私立学校_中学校_退学年月日
            KUNISHIRITSU_T_TAIGAKU_GAKUNEN NUMBER := 0,              --国・私立学校_中学校_退学学年
            KUNISHIRITSU_T_SOTSUGYO_BI     NUMBER := 0,              --国・私立学校_中学校_卒業年月日
            KUNISHIRITSU_T_KAISHI_BI       NUMBER := 0,              --国・私立学校_中学校_就学開始年月日
            KUNISHIRITSU_T_SHURYO_BI       NUMBER := 0,              --国・私立学校_中学校_就学終了年月日
            SAKUJO_FLG                     NUMBER := 0,              --削除フラグ
            SYS_SAKUSEIBI                  NUMBER := 0,              --作成日
            SYS_KOSHINBI                   NUMBER := 0,              --更新日
            SYS_JIKAN                      NUMBER := 0,              --更新時間
            SYS_SHOKUINKOJIN_NO            NVARCHAR2(1000),          --更新職員宛名番号
            SYS_TANMATU_NO                 NVARCHAR2(1000)           --更新端末番号
        );
        rGTR1                              MR_GTR;
        rGTR2                              MR_GTR;                   --元
        rGKBTGAKUREIBO_I                   GKBTGAKUREIBO%ROWTYPE;    --学齢簿
        rGKBTSHUGAKURIREKI_I               GKBTSHUGAKURIREKI%ROWTYPE; --就学履歴
        rGKBTGAKUNENRIREKI_I               GKBTGAKUNENRIREKI%ROWTYPE; --学年履歴
        sBUKACODE                          NVARCHAR2(63);             --端末番号
        v_SQL_MSG                          VARCHAR(255);              -- SQLエラーメッセージ

    BEGIN
        g_nUPDLOGSEQ := g_nUPDLOGSEQ + 1;
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 2);
        --初期処理
        --新設・統廃合退避ワークをTRUNCATEで初期化する
        nRTN := KKAPK3000.FTRUNCATE('GKBWTOHAIGOTAIHI', v_SQL_MSG);
        --条件取得処理を呼び出す
        IF NOT FUNC_JYOKEN_GET THEN
          RAISE eEXCEPTION;
        END IF;
        --学区管理区分の取得
        IF KKAPK0030.FCTGetR('GKB', '00GAKKU_KANRI','0000', 0, aPRM) = 0 THEN
          g_nGAKKU_KBN := aPRM(1);
        END IF;
        nMM := TO_NUMBER(SUBSTR(g_vTENNYUGAKUYMD, 4,2));
        nYY := TO_NUMBER(SUBSTR(g_vTENNYUGAKUYMD, 1,3));
        --対象年度の設定
        IF nMM < 4 THEN
          nSOTONENDO := nYY - 1;
        ELSIF nMM >= 4 THEN
          nSOTONENDO := nYY;
        ELSE
          NULL;
        END IF;
        --進級・卒業処理の処理状況取得
        BEGIN
          SELECT MAX(NENDO)
          INTO nMAXNENDO
          FROM GKBTKOSHINLOG
          WHERE GYOMU_SUBCD = 0
            AND GROUPKEY = 1
            AND RENBAN = 2
            AND SHORI_RENBAN = 1;
        EXCEPTION
          WHEN OTHERS THEN
            nMAXNENDO := NULL;
        END;
        --年度途中の判断
        IF nMAXNENDO IS NULL THEN
          g_NENTXYUFLG := 1;
        ELSIF nMAXNENDO = nSOTONENDO THEN
          g_NENTXYUFLG := 1;
        ELSIF nMAXNENDO <> nSOTONENDO THEN
          g_NENTXYUFLG := 0;
        ELSE
          NULL;
        END IF;
        --新入学児童学齢簿作成処理の処理状況取得
        BEGIN
          SELECT MAX(NENDO)
          INTO nMAXNENDO
          FROM GKBTKOSHINLOG
          WHERE GYOMU_SUBCD = 0
            AND GROUPKEY = 1
            AND RENBAN = 1
--  2024/10/17 ZCZL.WANGMING UPDATE 0.3.000.005:仕様変更　IT_GKB_00284対応
--            AND SHORI_RENBAN = 3;
            AND SHORI_RENBAN = 1;
        EXCEPTION
          WHEN OTHERS THEN
            nMAXNENDO := NULL;
        END;
        --処理状況の判断
        IF nMAXNENDO IS NULL THEN
          g_SINSAKUJIXYOFLG := 1;
        ELSIF nMAXNENDO = nSOTONENDO THEN
          g_SINSAKUJIXYOFLG := 1;
        ELSIF nMAXNENDO <> nSOTONENDO THEN
          g_SINSAKUJIXYOFLG := 0;
        ELSE
          NULL;
        END IF;
        --対象児童生徒情報取得
        --児童生徒の抽出
        sSQL := '';
        sSQL := sSQL || 'SELECT GTG.KOJIN_NO AS KOJIN_NO,';
        sSQL := sSQL || '       CASE GTG.GAKUNEN';
        sSQL := sSQL || '         WHEN 0 THEN 1';
        sSQL := sSQL || '         WHEN 6 THEN ';
        sSQL := sSQL || '           CASE B.GAKKO_KBN';
        sSQL := sSQL || '             WHEN 1 THEN GTR.GAKKO_KBN_CD';
        sSQL := sSQL || '             WHEN 2 THEN 2';
        sSQL := sSQL || '           END';
        sSQL := sSQL || '         ELSE';
        sSQL := sSQL || '           GTR.GAKKO_KBN_CD';
        sSQL := sSQL || '       END AS GAKKO_KBN,';
        sSQL := sSQL || '       GTG.GAKUNEN AS GAKUNEN,';
        sSQL := sSQL || '       CASE GTG.GAKUNEN';
        sSQL := sSQL || '         WHEN 0 THEN GTG.SYOGAKO_CD';
        sSQL := sSQL || '         WHEN 6 THEN ';
        sSQL := sSQL || '           CASE B.GAKKO_KBN';
        sSQL := sSQL || '             WHEN 1 THEN GTR.GAKKO_CD';
        sSQL := sSQL || '             WHEN 2 THEN GTG.TYUGAKO_CD';
        sSQL := sSQL || '           END';
        sSQL := sSQL || '         ELSE';
        sSQL := sSQL || '           GTR.GAKKO_CD';
        sSQL := sSQL || '       END AS TSUJO_SHUGAKUYOTEIKO,';
        --2024/11/23 YAMANI.OHARA UPDATE START 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
        --sSQL := sSQL || '       GTG.SHITEI_SYOGAKO_CD AS NOW_SHUGAKUSHITEIKO_SHO,';
        --sSQL := sSQL || '       GTG.SHITEI_TYUGAKO_CD AS NOW_SHUGAKUSHITEIKO_CHU,';
        sSQL := sSQL || '       NVL(GTG.SHITEI_SYOGAKO_CD,0) AS NOW_SHUGAKUSHITEIKO_SHO,';
        sSQL := sSQL || '       NVL(GTG.SHITEI_TYUGAKO_CD,0) AS NOW_SHUGAKUSHITEIKO_CHU,';
        --2024/11/23 YAMANI.OHARA UPDATE END
        --  2024/10/15 ZCZL.ZHANGLEI UPDATE 0.3.000.004:IT_GKB_00294対応
        --sSQL := sSQL || '       B.GAKKO_CD AS NEW_SHUGAKUSHITEIKO_KBN,';
        --2024/11/23 YAMANI.OHARA UPDATE START 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
        --sSQL := sSQL || '       B.GAKKO_KBN AS NEW_SHUGAKUSHITEIKO_KBN,';
        --sSQL := sSQL || '       B.GAKKO_CD AS NEW_SHUGAKUSHITEIKO,';
        --sSQL := sSQL || '       B.GAKKO_MEI AS NEW_SHUGAKUSHITEIKO_MEI,';
        sSQL := sSQL || '       NVL(B.GAKKO_KBN,0) AS NEW_SHUGAKUSHITEIKO_KBN,';
        sSQL := sSQL || '       NVL(B.GAKKO_CD,0) AS NEW_SHUGAKUSHITEIKO,';
        --2024/11/23 YAMANI.OHARA UPDATE END
        sSQL := sSQL || '       B.GAKKO_MEI AS NEW_SHUGAKUSHITEIKO_MEI,';
        sSQL := sSQL || '       B.KYOIKUIINKAI_CD AS NEW_KYOIKUIINKAI_CD,';
        sSQL := sSQL || '       B.GAKKOKU_CD AS NEW_GAKKOKU_CD,';
        sSQL := sSQL || '       CASE WHEN (GTG.SYOGAKO_TENNYUGAKU_BI < GTG.TYUGAKO_TENNYUGAKU_BI) THEN';
        sSQL := sSQL || '              GTG.TYUGAKO_TENNYUGAKU_BI';
        sSQL := sSQL || '            WHEN (GTG.SYOGAKO_TENNYUGAKU_BI > GTG.TYUGAKO_TENNYUGAKU_BI) THEN';
        sSQL := sSQL || '              GTG.SYOGAKO_TENNYUGAKU_BI';
        sSQL := sSQL || '       END AS SAISHIN_TENNYUGAKU_BI ';
        sSQL := sSQL || 'FROM GKBTGAKUREIBO GTG,';
        sSQL := sSQL || '     GKBTGAKUNENRIREKI GTR,';
        sSQL := sSQL || '     (';
        sSQL := sSQL || '       SELECT 1 AS KAIKO_HAIKO_KBN,';
        sSQL := sSQL || '              1 AS GAKKO_KBN,';
        sSQL := sSQL || '              GTS.SYOGAKO_CD AS GAKKO_CD';
        sSQL := sSQL || '       FROM GKBTSHOGAKKO GTS';
        sSQL := sSQL || '       WHERE GTS.SAKUJO_FLG = 0';
        sSQL := sSQL || '             AND '|| KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLSTARTYMD)) || ' <= GTS.KAIKO_BI';
        sSQL := sSQL || '             AND GTS.KAIKO_BI <= ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLENDYMD));
        sSQL := sSQL || '       UNION';
        sSQL := sSQL || '       SELECT 2 AS KAIKO_HAIKO_KBN,';
        sSQL := sSQL || '              1 AS GAKKO_KBN,';
        sSQL := sSQL || '              GTS.SYOGAKO_CD AS GAKKO_CD';
        sSQL := sSQL || '       FROM GKBTSHOGAKKO GTS';
        sSQL := sSQL || '       WHERE GTS.SAKUJO_FLG = 0';
        sSQL := sSQL || '             AND ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLSTARTYMD)) || ' <= GTS.HAIKO_BI';
        sSQL := sSQL || '             AND GTS.HAIKO_BI <= ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLENDYMD));
        sSQL := sSQL || '       UNION';
        sSQL := sSQL || '       SELECT 1 AS KAIKO_HAIKO_KBN,';
        sSQL := sSQL || '              2 AS GAKKO_KBN,';
        sSQL := sSQL || '              GTC.TYUGAKO_CD AS GAKKO_CD';
        sSQL := sSQL || '       FROM GKBTCHUGAKKO GTC';
        sSQL := sSQL || '       WHERE GTC.SAKUJO_FLG = 0';
        sSQL := sSQL || '             AND ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLSTARTYMD)) || ' <= GTC.KAIKO_BI';
        sSQL := sSQL || '             AND GTC.KAIKO_BI <= ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLENDYMD));
        sSQL := sSQL || '       UNION';
        sSQL := sSQL || '       SELECT 2 AS KAIKO_HAIKO_KBN,';
        sSQL := sSQL || '              2 AS GAKKO_KBN,';
        sSQL := sSQL || '              GTC.TYUGAKO_CD AS GAKKO_CD';
        sSQL := sSQL || '       FROM GKBTCHUGAKKO GTC';
        sSQL := sSQL || '       WHERE GTC.SAKUJO_FLG = 0';
        sSQL := sSQL || '             AND ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLSTARTYMD)) || ' <= GTC.HAIKO_BI';
        sSQL := sSQL || '             AND GTC.HAIKO_BI <= ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLENDYMD));
        sSQL := sSQL || '      ) A,';
        sSQL := sSQL || '     (';
        sSQL := sSQL || '       SELECT GTE.KOJIN_NO AS KOJIN_NO,';
        sSQL := sSQL || '              C.GAKKO_KBN AS GAKKO_KBN,';
        sSQL := sSQL || '              C.GAKKO_CD AS GAKKO_CD,';
        sSQL := sSQL || '              C.GAKKO_MEI AS GAKKO_MEI,';
        --2024/11/23 YAMANI.OHARA UPDATE START 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
        --sSQL := sSQL || '              C.GAKKOKU_CD AS GAKKOKU_CD,';
        sSQL := sSQL || '              NVL(C.GAKKOKU_CD,0) AS GAKKOKU_CD,';
        --2024/11/23 YAMANI.OHARA UPDATE END
        sSQL := sSQL || '              C.KYOIKUIINKAI_CD AS KYOIKUIINKAI_CD';
        sSQL := sSQL || '       FROM GKBTMSGAKKUKARI GTM,';
        sSQL := sSQL || '            GABVATENAALL    GTE,';
        sSQL := sSQL || '            (';
        sSQL := sSQL || '              SELECT 1 AS GAKKO_KBN,';
        sSQL := sSQL || '                     GTS.GAKKOKU_CD AS GAKKOKU_CD,';
        sSQL := sSQL || '                     GTS.SYOGAKO_CD AS GAKKO_CD,';
        sSQL := sSQL || '                     GTS.SYOGAKOMEI AS GAKKO_MEI,';
        sSQL := sSQL || '                     GTS.KYOIKUIINKAI_CD AS KYOIKUIINKAI_CD';
        sSQL := sSQL || '              FROM GKBTSHOGAKKO GTS';
        sSQL := sSQL || '              WHERE GTS.SAKUJO_FLG = 0';
        sSQL := sSQL || '              UNION';
        sSQL := sSQL || '              SELECT 2 AS GAKKO_KBN,';
        sSQL := sSQL || '                     GTC.GAKKOKU_CD AS GAKKOKU_CD,';
        sSQL := sSQL || '                     GTC.TYUGAKO_CD AS GAKKO_CD,';
        sSQL := sSQL || '                     GTC.TYUGAKOMEI AS GAKKO_MEI,';
        sSQL := sSQL || '                     GTC.KYOIKUIINKAI_CD AS KYOIKUIINKAI_CD';
        sSQL := sSQL || '              FROM GKBTCHUGAKKO GTC';
        sSQL := sSQL || '              WHERE GTC.SAKUJO_FLG = 0';
        sSQL := sSQL || '             ) C';
        sSQL := sSQL || '       WHERE GTE.RIREKI_RENBAN = 999';
        sSQL := sSQL || '             AND GTM.SAISHIN_FLG = 0';
        sSQL := sSQL || '             AND GTM.SAKUJO_FLG = 0';
        sSQL := sSQL || '             AND C.GAKKO_KBN = GTM.GAKKO_KBN_CD';
--  2025/05/21 CTC.LIUJUNHAO ADD START 1.0.006.000:GKB_QA13005_新設・統廃合一括処理で帳票の出力や更新がかからない対応
        --sSQL := sSQL || '             AND C.GAKKOKU_CD = GTM.GAKKOKU_CD';
        sSQL := sSQL || '             AND C.GAKKOKU_CD =  TO_NUMBER(GTM.GAKKOKU_CD)';
--  2025/05/21 CTC.LIUJUNHAO ADD END 1.0.006.000:GKB_QA13005_新設・統廃合一括処理で帳票の出力や更新がかからない対応
        IF g_nGAKKU_KBN = 0 THEN
          sSQL := sSQL || '           AND GTM.OAZA_CD = GTE.OAZA_CD';
          sSQL := sSQL || '           AND GTM.HONBAN_FR <= GTE.HONBAN';
          sSQL := sSQL || '           AND GTM.HONBAN_TO >= GTE.HONBAN';
          sSQL := sSQL || '           AND GTM.EDABAN1_FR <= GTE.EDABAN1';
          sSQL := sSQL || '           AND GTM.EDABAN1_TO >= GTE.EDABAN1';
          sSQL := sSQL || '           AND GTM.EDABAN2_FR <= GTE.EDABAN2';
          sSQL := sSQL || '           AND GTM.EDABAN2_TO >= GTE.EDABAN2';
          sSQL := sSQL || '           AND GTM.EDABAN3_FR <= GTE.EDABAN3';
          sSQL := sSQL || '           AND GTM.EDABAN3_TO >= GTE.EDABAN3';
          sSQL := sSQL || '           AND GTM.GAIKU_FR <= GTE.GAIKU';
          sSQL := sSQL || '           AND GTM.GAIKU_TO >= GTE.GAIKU';
          sSQL := sSQL || '           AND GTM.TOU_FR <= GTE.TOU';
          sSQL := sSQL || '           AND GTM.TOU_TO >= GTE.TOU';
        END IF;
        IF g_nGAKKU_KBN = 1 THEN
          sSQL := sSQL || '           AND GTM.GYOSEIKU_CD = GTE.GYOSEIKU_CD';
        END IF;
        sSQL := sSQL || '      ) B ';
        sSQL := sSQL || 'WHERE GTG.SAISHIN_KBN = 0';
        sSQL := sSQL || '      AND GTG.SAKUJO_FLG = 0';
        sSQL := sSQL || '      AND GTG.GEN_NENGAPI = 0';
        IF g_NENTXYUFLG = 0 THEN
          sSQL := sSQL || '    AND GTG.GAKUNEN IN(0, 1, 2, 3, 4, 5, 6, 7, 8)';
        ELSIF g_NENTXYUFLG = 1 THEN
          sSQL := sSQL || '    AND GTG.GAKUNEN IN(0, 1, 2, 3, 4, 5, 6, 7, 8, 9)';
        ELSE
          NULL;
        END IF;
        sSQL := sSQL || '      AND GTR.KOJIN_NO(+) = GTG.KOJIN_NO';
        sSQL := sSQL || '      AND GTR.SAISIN_FLG(+) = 0';
        sSQL := sSQL || '      AND GTR.SAKUJO_FLG(+) = 0';
        sSQL := sSQL || '      AND B.KOJIN_NO(+) = GTG.KOJIN_NO';
        IF g_NENTXYUFLG = 0 THEN
          sSQL := sSQL || '    AND B.GAKKO_KBN(+) = (';
          sSQL := sSQL || '                           CASE WHEN 0 <= GTG.GAKUNEN AND GTG.GAKUNEN <= 5 THEN 1';
          sSQL := sSQL || '                                WHEN 6 <= GTG.GAKUNEN AND GTG.GAKUNEN <= 8 THEN 2';
          sSQL := sSQL || '                           END';
          sSQL := sSQL || '                          )';
          sSQL := sSQL || '    AND A.GAKKO_KBN = (';
          sSQL := sSQL || '                           CASE WHEN 0 <= GTG.GAKUNEN AND GTG.GAKUNEN <= 5 THEN 1';
          sSQL := sSQL || '                                WHEN 6 <= GTG.GAKUNEN AND GTG.GAKUNEN <= 8 THEN 2';
          sSQL := sSQL || '                           END';
          sSQL := sSQL || '                       )';
        ELSIF g_NENTXYUFLG = 1 THEN
          sSQL := sSQL || '    AND B.GAKKO_KBN(+) = (';
          sSQL := sSQL || '                           CASE WHEN 0 <= GTG.GAKUNEN AND GTG.GAKUNEN <= 6 THEN 1';
          sSQL := sSQL || '                                WHEN 7 <= GTG.GAKUNEN AND GTG.GAKUNEN <= 9 THEN 2';
          sSQL := sSQL || '                           END';
          sSQL := sSQL || '                          )';
          sSQL := sSQL || '    AND A.GAKKO_KBN = (';
          sSQL := sSQL || '                           CASE WHEN 0 <= GTG.GAKUNEN AND GTG.GAKUNEN <= 6 THEN 1';
          sSQL := sSQL || '                                WHEN 7 <= GTG.GAKUNEN AND GTG.GAKUNEN <= 9 THEN 2';
          sSQL := sSQL || '                           END';
          sSQL := sSQL || '                       )';
        ELSE
          NULL;
        END IF;
        sSQL := sSQL || '      AND (';
        sSQL := sSQL || '            (';
        sSQL := sSQL || '              A.KAIKO_HAIKO_KBN = 1';
        sSQL := sSQL || '              AND A.GAKKO_CD = B.GAKKO_CD';
        sSQL := sSQL || '             ) OR';
        sSQL := sSQL || '            (';
        --  2024/11/08 ZCZL.ZHANGLEI ADD 0.3.000.007:仕様変更　IT_GKB_00293、IT_GKB_00378対応
        sSQL := sSQL || '              NOT A.KAIKO_HAIKO_KBN = 1 AND';
        sSQL := sSQL || '              A.KAIKO_HAIKO_KBN = 2 ';
        IF g_NENTXYUFLG = 0 THEN
          sSQL := sSQL || '             AND (';
          sSQL := sSQL || '                   (GTG.GAKUNEN >= 0 AND GTG.GAKUNEN <= 5 AND (A.GAKKO_CD = GTG.SYOGAKO_CD OR A.GAKKO_CD = GTG.SHITEI_SYOGAKO_CD))';
          sSQL := sSQL || '                   OR (GTG.GAKUNEN >= 6 AND GTG.GAKUNEN <= 8 AND (A.GAKKO_CD = GTG.TYUGAKO_CD OR A.GAKKO_CD = GTG.SHITEI_TYUGAKO_CD))';
          sSQL := sSQL || '                  )';
        ELSIF g_NENTXYUFLG = 1 THEN
          sSQL := sSQL || '             AND (';
          sSQL := sSQL || '                   (GTG.GAKUNEN >= 0 AND GTG.GAKUNEN <= 6 AND (A.GAKKO_CD = GTG.SYOGAKO_CD OR A.GAKKO_CD = GTG.SHITEI_SYOGAKO_CD))';
          sSQL := sSQL || '                   OR (GTG.GAKUNEN >= 7 AND GTG.GAKUNEN <= 9 AND (A.GAKKO_CD = GTG.TYUGAKO_CD OR A.GAKKO_CD = GTG.SHITEI_TYUGAKO_CD))';
          sSQL := sSQL || '                  )';
        ELSE
          NULL;
        END IF;
        sSQL := sSQL || '             )';
        sSQL := sSQL || '           )';
        sSQL := sSQL || 'AND ((' || g_NENTXYUFLG || ' = 0 AND GTG.GAKUNEN IN(1,2,3,4,5,7,8) AND GKBFKZISKCHK(GTG.KOJIN_NO ,GTR.GAKKO_KBN_CD, GTG.GAKUNEN) = 1) ';
--  2024/11/23 YAMANI.OHARA UPDATE START 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
--        sSQL := sSQL || 'OR (' || g_NENTXYUFLG || ' = 1 AND GTG.GAKUNEN <> 0 AND GKBFKZISKCHK(GTG.KOJIN_NO, GTR.GAKKO_KBN_CD, GTG.GAKUNEN) = 1)) ';
        sSQL := sSQL || 'OR (' || g_NENTXYUFLG || ' = 1 AND GTG.GAKUNEN <> 0 AND GKBFKZISKCHK(GTG.KOJIN_NO, GTR.GAKKO_KBN_CD, GTG.GAKUNEN) = 1) ';
        sSQL := sSQL || 'OR GTG.GAKUNEN = 0) ';
--  2024/11/23 YAMANI.OHARA UPDATE END
        IF g_NENTXYUFLG = 1 AND g_SINSAKUJIXYOFLG = 1 THEN
          sSQL := sSQL || 'UNION ';
          sSQL := sSQL || 'SELECT GTG.KOJIN_NO AS KOJIN_NO,';
          sSQL := sSQL || '       2 AS GAKKO_KBN,';
          sSQL := sSQL || '       GTG.GAKUNEN AS GAKUNEN,';
          sSQL := sSQL || '       GTG.TYUGAKO_CD AS TSUJO_SHUGAKUYOTEIKO,';
--  2024/10/17 ZCZL.WANGMING DELETE START 0.3.000.005:仕様変更　IT_GKB_00283、IT_GKB_00287対応
--          sSQL := sSQL || '       (';
--          sSQL := sSQL || '         SELECT GTC.TYUGAKOMEI';
--          sSQL := sSQL || '         FROM GKBTCHUGAKKO GTC';
--          sSQL := sSQL || '         WHERE GTC.TYUGAKO_CD = GTG.TYUGAKO_CD';
 --         sSQL := sSQL || '               AND GTC.SAKUJO_FLG = 0';
--          sSQL := sSQL || '        ) AS TSUJO_SHUGAKUYOTEIKO_MEI,';
--  2024/10/17 ZCZL.WANGMING DELETE END
          --2024/11/23 YAMANI.OHARA UPDATE START 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
          --sSQL := sSQL || '        GTG.SHITEI_SYOGAKO_CD AS NOW_SHUGAKUSHITEIKO_SHO,';
          --sSQL := sSQL || '        GTG.SHITEI_TYUGAKO_CD AS NOW_SHUGAKUSHITEIKO_CHU,';
          --sSQL := sSQL || '        B.GAKKO_KBN AS NEW_SHUGAKUSHITEIKO_KBN,';
          --sSQL := sSQL || '        B.GAKKO_CD AS NEW_SHUGAKUSHITEIKO,';
          sSQL := sSQL || '        NVL(GTG.SHITEI_SYOGAKO_CD,0) AS NOW_SHUGAKUSHITEIKO_SHO,';
          sSQL := sSQL || '        NVL(GTG.SHITEI_TYUGAKO_CD,0) AS NOW_SHUGAKUSHITEIKO_CHU,';
          sSQL := sSQL || '        NVL(B.GAKKO_KBN,0) AS NEW_SHUGAKUSHITEIKO_KBN,';
          sSQL := sSQL || '        NVL(B.GAKKO_CD,0) AS NEW_SHUGAKUSHITEIKO,';
          --2024/11/23 YAMANI.OHARA UPDATE END
          sSQL := sSQL || '        B.GAKKO_MEI AS NEW_SHUGAKUSHITEIKO_MEI,';
          sSQL := sSQL || '        B.KYOIKUIINKAI_CD AS NEW_KYOIKUIINKAI_CD,';
          sSQL := sSQL || '        B.GAKKOKU_CD AS NEW_GAKKOKU_CD,';
          sSQL := sSQL || '        CASE WHEN (GTG.SYOGAKO_TENNYUGAKU_BI < GTG.TYUGAKO_TENNYUGAKU_BI) THEN';
          sSQL := sSQL || '               GTG.TYUGAKO_TENNYUGAKU_BI';
          sSQL := sSQL || '             WHEN (GTG.SYOGAKO_TENNYUGAKU_BI > GTG.TYUGAKO_TENNYUGAKU_BI) THEN';
          sSQL := sSQL || '               GTG.SYOGAKO_TENNYUGAKU_BI';
          sSQL := sSQL || '        END AS SAISHIN_TENNYUGAKU_BI ';
          sSQL := sSQL || 'FROM GKBTGAKUREIBO GTG,';
          sSQL := sSQL || '     (';
          sSQL := sSQL || '       SELECT 1 AS KAIKO_HAIKO_KBN,';
          sSQL := sSQL || '              1 AS GAKKO_KBN,';
          sSQL := sSQL || '              GTS.SYOGAKO_CD AS GAKKO_CD';
          sSQL := sSQL || '       FROM GKBTSHOGAKKO GTS';
          sSQL := sSQL || '       WHERE GTS.SAKUJO_FLG = 0';
          sSQL := sSQL || '             AND '|| KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLSTARTYMD)) || ' <= GTS.KAIKO_BI';
          sSQL := sSQL || '             AND GTS.KAIKO_BI <= ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLENDYMD));
          sSQL := sSQL || '       UNION';
          sSQL := sSQL || '       SELECT 2 AS KAIKO_HAIKO_KBN,';
          sSQL := sSQL || '              1 AS GAKKO_KBN,';
          sSQL := sSQL || '              GTS.SYOGAKO_CD AS GAKKO_CD';
          sSQL := sSQL || '       FROM GKBTSHOGAKKO GTS';
          sSQL := sSQL || '       WHERE GTS.SAKUJO_FLG = 0';
          sSQL := sSQL || '             AND ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLSTARTYMD)) || ' <= GTS.HAIKO_BI';
          sSQL := sSQL || '             AND GTS.HAIKO_BI <= ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLENDYMD));
          sSQL := sSQL || '       UNION';
          sSQL := sSQL || '       SELECT 1 AS KAIKO_HAIKO_KBN,';
          sSQL := sSQL || '              2 AS GAKKO_KBN,';
          sSQL := sSQL || '              GTC.TYUGAKO_CD AS GAKKO_CD';
          sSQL := sSQL || '       FROM GKBTCHUGAKKO GTC';
          sSQL := sSQL || '       WHERE GTC.SAKUJO_FLG = 0';
          sSQL := sSQL || '             AND ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLSTARTYMD)) || ' <= GTC.KAIKO_BI';
          sSQL := sSQL || '             AND GTC.KAIKO_BI <= ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLENDYMD));
          sSQL := sSQL || '       UNION';
          sSQL := sSQL || '       SELECT 2 AS KAIKO_HAIKO_KBN,';
          sSQL := sSQL || '              2 AS GAKKO_KBN,';
          sSQL := sSQL || '              GTC.TYUGAKO_CD AS GAKKO_CD';
          sSQL := sSQL || '       FROM GKBTCHUGAKKO GTC';
          sSQL := sSQL || '       WHERE GTC.SAKUJO_FLG = 0';
          sSQL := sSQL || '             AND ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLSTARTYMD)) || ' <= GTC.HAIKO_BI';
          sSQL := sSQL || '             AND GTC.HAIKO_BI <= ' || KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vSCHOOLENDYMD));
          sSQL := sSQL || '      ) A,';
          sSQL := sSQL || '     (';
          sSQL := sSQL || '       SELECT GTE.KOJIN_NO AS KOJIN_NO,';
          sSQL := sSQL || '              C.GAKKO_KBN AS GAKKO_KBN,';
          sSQL := sSQL || '              C.GAKKO_CD AS GAKKO_CD,';
          sSQL := sSQL || '              C.GAKKO_MEI AS GAKKO_MEI,';
          sSQL := sSQL || '              C.GAKKOKU_CD AS GAKKOKU_CD,';
          sSQL := sSQL || '              C.KYOIKUIINKAI_CD AS KYOIKUIINKAI_CD';
          sSQL := sSQL || '       FROM GKBTMSGAKKUKARI GTM,';
          sSQL := sSQL || '            GABVATENAALL    GTE,';
          sSQL := sSQL || '            (';
          sSQL := sSQL || '              SELECT 1 AS GAKKO_KBN,';
          sSQL := sSQL || '                     GTS.GAKKOKU_CD AS GAKKOKU_CD,';
          sSQL := sSQL || '                     GTS.SYOGAKO_CD AS GAKKO_CD,';
          sSQL := sSQL || '                     GTS.SYOGAKOMEI AS GAKKO_MEI,';
          sSQL := sSQL || '                     GTS.KYOIKUIINKAI_CD AS KYOIKUIINKAI_CD';
          sSQL := sSQL || '              FROM GKBTSHOGAKKO GTS';
          sSQL := sSQL || '              WHERE GTS.SAKUJO_FLG = 0';
          sSQL := sSQL || '              UNION';
          sSQL := sSQL || '              SELECT 2 AS GAKKO_KBN,';
          sSQL := sSQL || '                     GTC.GAKKOKU_CD AS GAKKOKU_CD,';
          sSQL := sSQL || '                     GTC.TYUGAKO_CD AS GAKKO_CD,';
          sSQL := sSQL || '                     GTC.TYUGAKOMEI AS GAKKO_MEI,';
          sSQL := sSQL || '                     GTC.KYOIKUIINKAI_CD AS KYOIKUIINKAI_CD';
          sSQL := sSQL || '              FROM GKBTCHUGAKKO GTC';
          sSQL := sSQL || '              WHERE GTC.SAKUJO_FLG = 0';
          sSQL := sSQL || '             ) C';
          sSQL := sSQL || '       WHERE GTE.RIREKI_RENBAN = 999';
          sSQL := sSQL || '             AND GTM.SAISHIN_FLG = 0';
          sSQL := sSQL || '             AND GTM.SAKUJO_FLG = 0';
          sSQL := sSQL || '             AND C.GAKKO_KBN = GTM.GAKKO_KBN_CD';
--  2025/05/21 CTC.LIUJUNHAO ADD START 1.0.006.000:GKB_QA13005_新設・統廃合一括処理で帳票の出力や更新がかからない対応
          --sSQL := sSQL || '             AND C.GAKKOKU_CD = GTM.GAKKOKU_CD';
          sSQL := sSQL || '             AND C.GAKKOKU_CD =  TO_NUMBER(GTM.GAKKOKU_CD)';
--  2025/05/21 CTC.LIUJUNHAO ADD END 1.0.006.000:GKB_QA13005_新設・統廃合一括処理で帳票の出力や更新がかからない対応
          IF g_nGAKKU_KBN = 0 THEN
            sSQL := sSQL || '           AND GTM.OAZA_CD = GTE.OAZA_CD';
            sSQL := sSQL || '           AND GTM.HONBAN_FR <= GTE.HONBAN';
            sSQL := sSQL || '           AND GTM.HONBAN_TO >= GTE.HONBAN';
            sSQL := sSQL || '           AND GTM.EDABAN1_FR <= GTE.EDABAN1';
            sSQL := sSQL || '           AND GTM.EDABAN1_TO >= GTE.EDABAN1';
            sSQL := sSQL || '           AND GTM.EDABAN2_FR <= GTE.EDABAN2';
            sSQL := sSQL || '           AND GTM.EDABAN2_TO >= GTE.EDABAN2';
            sSQL := sSQL || '           AND GTM.EDABAN3_FR <= GTE.EDABAN3';
            sSQL := sSQL || '           AND GTM.EDABAN3_TO >= GTE.EDABAN3';
            sSQL := sSQL || '           AND GTM.GAIKU_FR <= GTE.GAIKU';
            sSQL := sSQL || '           AND GTM.GAIKU_TO >= GTE.GAIKU';
            sSQL := sSQL || '           AND GTM.TOU_FR <= GTE.TOU';
            sSQL := sSQL || '           AND GTM.TOU_TO >= GTE.TOU';
          END IF;
          IF g_nGAKKU_KBN = 1 THEN
            sSQL := sSQL || '           AND GTM.GYOSEIKU_CD = GTE.GYOSEIKU_CD';
          END IF;
          sSQL := sSQL || '      ) B ';
          sSQL := sSQL || 'WHERE GTG.SAISHIN_KBN = 0';
          sSQL := sSQL || '      AND GTG.SAKUJO_FLG = 0';
          sSQL := sSQL || '      AND GTG.GEN_NENGAPI = 0';
          sSQL := sSQL || '      AND GTG.GAKUNEN = 6';
          sSQL := sSQL || '      AND B.KOJIN_NO(+) = GTG.KOJIN_NO';
          sSQL := sSQL || '      AND B.GAKKO_KBN(+) = 2';
          sSQL := sSQL || '      AND A.GAKKO_KBN = 2';
          sSQL := sSQL || '      AND (';
          sSQL := sSQL || '            (';
          sSQL := sSQL || '              A.KAIKO_HAIKO_KBN = 1';
          sSQL := sSQL || '              AND A.GAKKO_CD = B.GAKKO_CD';
          sSQL := sSQL || '             )';
          sSQL := sSQL || '           OR';
          sSQL := sSQL || '           (';
          --  2024/11/08 ZCZL.ZHANGLEI ADD 0.3.000.007:仕様変更　IT_GKB_00293、IT_GKB_00378対応
          sSQL := sSQL || '             NOT A.KAIKO_HAIKO_KBN = 1 AND';
          sSQL := sSQL || '             A.KAIKO_HAIKO_KBN = 2';
          sSQL := sSQL || '             AND (A.GAKKO_CD = GTG.TYUGAKO_CD OR A.GAKKO_CD = GTG.SHITEI_TYUGAKO_CD)';
          sSQL := sSQL || '            )';
          sSQL := sSQL || '           ) ';
        END IF;
        sSQL := sSQL || 'ORDER BY KOJIN_NO ASC, GAKKO_KBN ASC ';
        --児童生徒情報の登録
        OPEN cCURSOR FOR sSQL;
            LOOP
                FETCH cCURSOR INTO rGKBTGAKUREIBO;
                EXIT WHEN cCURSOR%NOTFOUND;
                --更新対象者判定
                nKOUSINFLG := 0;
                sBIKO := '';
                --就学校のチェック
                IF rGKBTGAKUREIBO.GAKUNEN = 0 THEN
                  IF rGKBTGAKUREIBO.GAKKO_KBN <> 1 OR rGKBTGAKUREIBO.NOW_SHUGAKUSHITEIKO_SHO <> rGKBTGAKUREIBO.TSUJO_SHUGAKUYOTEIKO THEN
                    nKOUSINFLG := 0;
                    sBIKO := sBIKO || '就学指定校と異なる小学校に就学予定のため、更新対象外です。';
                  ELSE
                    nKOUSINFLG := 1;
                  END IF;
                ELSIF rGKBTGAKUREIBO.GAKUNEN >= 1 AND rGKBTGAKUREIBO.GAKUNEN <= 5 THEN
                  IF rGKBTGAKUREIBO.GAKKO_KBN <> 1 OR rGKBTGAKUREIBO.NOW_SHUGAKUSHITEIKO_SHO <> rGKBTGAKUREIBO.TSUJO_SHUGAKUYOTEIKO THEN
                    nKOUSINFLG := 0;
                    sBIKO := sBIKO || '就学指定校と異なる学校に就学中のため、更新対象外です。';
                  ELSE
                    nKOUSINFLG := 1;
                  END IF;
                ELSIF rGKBTGAKUREIBO.GAKUNEN = 6 THEN
                  IF rGKBTGAKUREIBO.GAKKO_KBN = 1 THEN
                    IF rGKBTGAKUREIBO.NOW_SHUGAKUSHITEIKO_SHO <> rGKBTGAKUREIBO.TSUJO_SHUGAKUYOTEIKO THEN
                      nKOUSINFLG := 0;
                      sBIKO := sBIKO || '就学指定校と異なる学校に就学中のため、更新対象外です。';
                    ELSE
                      nKOUSINFLG := 1;
                    END IF;
                  ELSIF rGKBTGAKUREIBO.GAKKO_KBN = 2 THEN
                    IF rGKBTGAKUREIBO.NOW_SHUGAKUSHITEIKO_CHU <> rGKBTGAKUREIBO.TSUJO_SHUGAKUYOTEIKO THEN
                      nKOUSINFLG := 0;
                      sBIKO := sBIKO || '就学指定校と異なる中学校に就学予定のため、更新対象外です。';
                    ELSE
                      nKOUSINFLG := 1;
                    END IF;
                  ELSE
                    nKOUSINFLG := 0;
                    sBIKO := sBIKO || '就学指定校と異なる学校に就学中のため、更新対象外です。';
                  END IF;
                ELSIF rGKBTGAKUREIBO.GAKUNEN >= 7 AND rGKBTGAKUREIBO.GAKUNEN <= 9 THEN
                  IF rGKBTGAKUREIBO.GAKKO_KBN <> 2 OR rGKBTGAKUREIBO.NOW_SHUGAKUSHITEIKO_CHU <> rGKBTGAKUREIBO.TSUJO_SHUGAKUYOTEIKO THEN
                    nKOUSINFLG := 0;
                    sBIKO := sBIKO || '就学指定校と異なる学校に就学中のため、更新対象外です。';
                  ELSE
                    nKOUSINFLG := 1;
                  END IF;
                ELSE
                  NULL;
                END IF;
                --転学年月日と転入学年月日の関係性チェック
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00014、15対応
--                IF nKOUSINFLG = 1 AND rGKBTGAKUREIBO.SAISHIN_TENNYUGAKU_BI <= KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD)) THEN
                IF nKOUSINFLG = 1 AND rGKBTGAKUREIBO.SAISHIN_TENNYUGAKU_BI >= KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD)) THEN
                  nKOUSINFLG := 0;
                  sBIKO := sBIKO || '既に設定されている転入学日と処理条件で指定した転学年月日の関係性が不正です。';
                END IF;
                --2024/11/23 YAMANI.OHARA UPDATE START 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
                IF nKOUSINFLG = 1 AND (rGKBTGAKUREIBO.NEW_SHUGAKUSHITEIKO_KBN = 0 or rGKBTGAKUREIBO.NEW_SHUGAKUSHITEIKO = 0) THEN
                  nKOUSINFLG := 0;
                  sBIKO := sBIKO || '学区を特定できない児童生徒がいます。学区仮マスタを確認してください。';
                END IF;
                --2024/11/23 YAMANI.OHARA UPDATE END

                --抽出した児童生徒情報の登録
                BEGIN
                  SELECT *
                  INTO rGKBTGAKUREIBO_2
                  FROM GKBTGAKUREIBO GTG
                  WHERE GTG.KOJIN_NO = rGKBTGAKUREIBO.KOJIN_NO
                        AND GTG.SAISHIN_KBN = 0
                        AND GTG.SAKUJO_FLG = 0;
                EXCEPTION
                  WHEN OTHERS THEN
                    rGKBTGAKUREIBO_2 := NULL;
                END;
                --保護者宛名情報
                nRTN := GAAPK0030.FGETATENA2(rGKBTGAKUREIBO_2.HOGOSYA_KOJIN_NO,  --宛名番号
                                             'GKB',                              --業務コード
                                             g_vHAKKOYMD2,                       --基準日
                                             o_rGABTATENAKIHON,                  --保護者宛名
                                             o_rGABTSOFUSAKI                     --保護者送付先
                                             );
                --児童生徒宛名情報
                nRTN := GAAPK0030.FGETATENA(rGKBTGAKUREIBO.KOJIN_NO,             --宛名番号
                                            'GKB',                               --業務コード
                                            g_vHAKKOYMD2,                        --基準日
                                            o_rGABTATENAKIHON_2,                 --児童生徒宛名
                                            o_rGABTSOFUSAKI_2                    --児童生徒送付先
                                             );
                rGKBWTOHAIGOTAIHI.KOJIN_NO := rGKBTGAKUREIBO.KOJIN_NO;           --宛名番号
                rGKBWTOHAIGOTAIHI.UPDATE_FLG := nKOUSINFLG;                      --更新対象フラグ
                rGKBWTOHAIGOTAIHI.NOW_GAKUNEN := rGKBTGAKUREIBO.GAKUNEN;         --現在学年
                IF g_NENTXYUFLG = 0 THEN
                  rGKBWTOHAIGOTAIHI.TENNYUGAKU_GAKUNEN := rGKBTGAKUREIBO.GAKUNEN + 1;
                ELSIF g_NENTXYUFLG = 1 THEN
                  rGKBWTOHAIGOTAIHI.TENNYUGAKU_GAKUNEN := rGKBTGAKUREIBO.GAKUNEN;  --転入学時学年
                ELSE
                  NULL;
                END IF;
                rGKBWTOHAIGOTAIHI.GAKKO_KBN := rGKBTGAKUREIBO.GAKKO_KBN;           --学校区分
                rGKBWTOHAIGOTAIHI.TSUJO_SHUGAKUYOTEIKO := rGKBTGAKUREIBO.TSUJO_SHUGAKUYOTEIKO;        --通常就学予定校
                rGKBWTOHAIGOTAIHI.TSUJO_SHUGAKUYOTEIKO_MEI := GKAFKGKOGTEQ(rGKBTGAKUREIBO.GAKKO_KBN, rGKBTGAKUREIBO.TSUJO_SHUGAKUYOTEIKO);  --通常就学予定校名
                rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_KBN := rGKBTGAKUREIBO.NEW_SHUGAKUSHITEIKO_KBN; --新就学指定校_学校区分
                rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU := rGKBTGAKUREIBO.NEW_SHUGAKUSHITEIKO;         --新就学指定校
                rGKBWTOHAIGOTAIHI.NEW_SHUGAKUSHITEIKOU_MEI := rGKBTGAKUREIBO.NEW_SHUGAKUSHITEIKO_MEI; --新就学指定校名
                rGKBWTOHAIGOTAIHI.NEW_KYOIKUIINKAI_CD := rGKBTGAKUREIBO.NEW_KYOIKUIINKAI_CD;          --新就学指定校_教育委員会コード
                rGKBWTOHAIGOTAIHI.NEW_GAKKOKU_CD := rGKBTGAKUREIBO.NEW_GAKKOKU_CD;                    --新学校区コード
                rGKBWTOHAIGOTAIHI.BIKO := sBIKO;                                                      --備考
                nRTN := KKAPK0010.FYUBINHENSHU(o_rGABTSOFUSAKI.YUBIN_NO, rGKBWTOHAIGOTAIHI.SOFU_YUBIN);
                rGKBWTOHAIGOTAIHI.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(rGKBWTOHAIGOTAIHI.SOFU_YUBIN, 0); --送付先郵便番号
-- 2025/01/09 JPJYS.WUZHENGDONG Update 0.3.000.013:IT_GKB_10148対応 Start
--              rGKBWTOHAIGOTAIHI.SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rGABTATENAKIHON.CHOMEI, o_rGABTATENAKIHON.BANCHI, NULL, NULL); --送付先住所
                rGKBWTOHAIGOTAIHI.SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rGABTSOFUSAKI.CHOMEI, o_rGABTSOFUSAKI.BANCHI, NULL, NULL); --送付先住所
-- 2025/01/09 JPJYS.WUZHENGDONG Update 0.3.000.013:IT_GKB_10148対応 End
                rGKBWTOHAIGOTAIHI.SOFU_KATAGAKI := o_rGABTSOFUSAKI.KATAGAKI;                                 --送付先方書
                rGKBWTOHAIGOTAIHI.SOFU_ATENA := o_rGABTSOFUSAKI.SHIMEI_KANJI || ' ' || '様';                 --送付先宛名
                rGKBWTOHAIGOTAIHI.YUBIN_NOBC := o_rGABTSOFUSAKI.YUBIN_NOBC;                                  --郵便番号BC
                rGKBWTOHAIGOTAIHI.JIDO_SHIMEI_KANA := o_rGABTATENAKIHON_2.SHIMEI_KANA;                       --児童生徒氏名カナ
                rGKBWTOHAIGOTAIHI.JIDO_SHIMEI_KANJI := o_rGABTATENAKIHON_2.SHIMEI_KANJI;                     --児童生徒氏名漢字
                IF KKAPK0030.FCDGetR('GKB', '021', '0001', rGKBTGAKUREIBO_2.SEIBETSU, sMEISHO, sMEISHOKANA, sYOBI) = 0 THEN
                  rGKBWTOHAIGOTAIHI.JIDO_SEIBETSU := sMEISHO;                                                --児童生徒性別
                END IF;
                nRTN := GAAPK0030.FGETDV(rGKBTGAKUREIBO.KOJIN_NO,
                                         o_rGABTATENAKIHON_2.SETAI_NO,
                                         g_vHAKKOYMD2,
                                         'GKB',
                                         0,
                                         nKOJINSETAIKBN,
                                         nYOKUSHIKBN,
                                         nIDOYOKUSHIKBN,
                                         nHAKKOYOKUSHIKBN,
                                         nSHOKAIYOKUSHIKBN,
                                         nSHOKAIYOKUSHIKBN,
                                         vSHORICHUIKBN);
                --  2024/11/08 ZCZL.ZHANGLEI UPDATE 0.3.000.007:仕様変更　IT_GKB_00293、IT_GKB_00378対応
                --IF nYOKUSHIKBN = 0 THEN
                IF nYOKUSHIKBN NOT IN (1,2,4) THEN
                  rGKBWTOHAIGOTAIHI.JIDO_SHIENSOCHI := NULL;                                                 --児童生徒_支援措置
                ELSE
                  rGKBWTOHAIGOTAIHI.JIDO_SHIENSOCHI := '該当';                                               --児童生徒_支援措置
                END IF;
                --  2024/10/18 ZCZL.ZHANGLEI ADD START 0.3.000.007:IT_GKB_00282対応
                vSEINENGAPI := GKAPK00020.FGETSTRDATE_SLASH(o_rGABTATENAKIHON_2.SEINENGAPI);
                IF vSEINENGAPI IS NOT NULL THEN
                  --  2024/10/18 ZCZL.ZHANGLEI ADD END
                IF o_rGABTATENAKIHON_2.JINKAKU_KBN = 1 THEN
                  --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.007:IT_GKB_00282対応
                  --rGKBWTOHAIGOTAIHI.JIDO_SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_rGABTATENAKIHON_2.SEINENGAPI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 6); --表示生年月日
                  rGKBWTOHAIGOTAIHI.JIDO_SEINENGAPI := KKAPK0020.FDateFmt(vSEINENGAPI,6);
                ELSE
                  --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.007:IT_GKB_00282対応
                  --rGKBWTOHAIGOTAIHI.JIDO_SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(o_rGABTATENAKIHON_2.SEINENGAPI, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);--表示生年月日
                  rGKBWTOHAIGOTAIHI.JIDO_SEINENGAPI := KKAPK0020.FDateFmt(vSEINENGAPI,12);
                END IF;
                --  2024/10/18 ZCZL.ZHANGLEI ADD 0.3.000.007:IT_GKB_00282対応
                END IF;
                rGKBWTOHAIGOTAIHI.JIDO_JUSHO := o_rGABTATENAKIHON_2.CHOMEI || o_rGABTATENAKIHON_2.BANCHI || '　' || o_rGABTATENAKIHON_2.KATAGAKI;  --児童生徒住所
                rGKBWTOHAIGOTAIHI.HOGOSHA_KOJIJN_NO := rGKBTGAKUREIBO_2.HOGOSYA_KOJIN_NO;                    --保護者宛名番号
                rGKBWTOHAIGOTAIHI.HOGOSHA_SHIMEI_KANA := o_rGABTATENAKIHON.SHIMEI_KANA;                      --保護者氏名カナ
                rGKBWTOHAIGOTAIHI.HOGOSHA_SHIMEI_KANJI := o_rGABTATENAKIHON.SHIMEI_KANJI;                    --保護者氏名漢字
--  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.006:IT_GKB_00297対応
                --rGKBWTOHAIGOTAIHI.HOGOSHA_ZOKUGARA := GKBFKZKGMGET2(2, rGKBTGAKUREIBO_2.ZOKUGARA1, rGKBTGAKUREIBO_2.ZOKUGARA2, rGKBTGAKUREIBO_2.ZOKUGARA3, rGKBTGAKUREIBO_2.ZOKUGARA4);  --児童生徒との関係
                rGKBWTOHAIGOTAIHI.HOGOSHA_ZOKUGARA := GKBFKZKGMGET2(2, rGKBTGAKUREIBO_2.HOGOSYA_ZOKUGARA1, rGKBTGAKUREIBO_2.HOGOSYA_ZOKUGARA2, rGKBTGAKUREIBO_2.HOGOSYA_ZOKUGARA3, rGKBTGAKUREIBO_2.HOGOSYA_ZOKUGARA4);  --児童生徒との関係
                nRTN := GAAPK0030.FGETDV(rGKBTGAKUREIBO_2.HOGOSYA_KOJIN_NO,
                                         o_rGABTATENAKIHON.SETAI_NO,
                                         g_vHAKKOYMD2,
                                         'GKB',
                                         0,
                                         nKOJINSETAIKBN,
                                         nYOKUSHIKBN,
                                         nIDOYOKUSHIKBN,
                                         nHAKKOYOKUSHIKBN,
                                         nSHOKAIYOKUSHIKBN,
                                         nSHOKAIYOKUSHIKBN,
                                         vSHORICHUIKBN);
                --  2024/11/08 ZCZL.ZHANGLEI UPDATE 0.3.000.007:仕様変更　IT_GKB_00293、IT_GKB_00378対応
                --IF nYOKUSHIKBN = 0 THEN
                IF nYOKUSHIKBN NOT IN (1,2,4) THEN
                  rGKBWTOHAIGOTAIHI.HOGOSHA_SHIENZOCHI := NULL;                                              --保護者_支援措置
                ELSE
                  rGKBWTOHAIGOTAIHI.HOGOSHA_SHIENZOCHI := '該当';                                            --保護者_支援措置
                END IF;
                rGKBWTOHAIGOTAIHI.JINKAKU_KBN := o_rGABTATENAKIHON_2.JINKAKU_KBN;                            --人格区分
                rGKBWTOHAIGOTAIHI.WSNUM := g_sWSNUM;                                                         --端末番号
                rGKBWTOHAIGOTAIHI.BATCHKBN := 2;                                                             --即時バッチ区分
                rGKBWTOHAIGOTAIHI.JOBNUM := g_nJOBNUM;                                                       --ジョブNO
                INSERT INTO GKBWTOHAIGOTAIHI VALUES rGKBWTOHAIGOTAIHI;
            END LOOP;
        CLOSE cCURSOR;
        --更新処理
        IF g_vSHORIKBN = 2 THEN
          --SQL文
          sSQL := '';
          sSQL := sSQL || 'SELECT KOJIN_NO';
          sSQL := sSQL || '       , UPDATE_FLG';
          sSQL := sSQL || '       , NOW_GAKUNEN';
          sSQL := sSQL || '       , TENNYUGAKU_GAKUNEN';
          sSQL := sSQL || '       , GAKKO_KBN';
          sSQL := sSQL || '       , TSUJO_SHUGAKUYOTEIKO';
          sSQL := sSQL || '       , TSUJO_SHUGAKUYOTEIKO_MEI';
          sSQL := sSQL || '       , NEW_SHUGAKUSHITEIKOU_KBN';
          sSQL := sSQL || '       , NEW_SHUGAKUSHITEIKOU';
          sSQL := sSQL || '       , NEW_SHUGAKUSHITEIKOU_MEI';
          sSQL := sSQL || '       , NEW_KYOIKUIINKAI_CD';
          sSQL := sSQL || '       , NEW_GAKKOKU_CD';
          sSQL := sSQL || '       , BIKO';
          sSQL := sSQL || '       , SOFU_YUBIN';
          sSQL := sSQL || '       , SOFU_JUSHO';
          sSQL := sSQL || '       , SOFU_KATAGAKI';
          sSQL := sSQL || '       , SOFU_ATENA';
          sSQL := sSQL || '       , YUBIN_NOBC';
          sSQL := sSQL || '       , JIDO_SHIMEI_KANA';
          sSQL := sSQL || '       , JIDO_SHIMEI_KANJI';
          sSQL := sSQL || '       , JIDO_SEIBETSU';
          sSQL := sSQL || '       , JIDO_SHIENSOCHI';
          sSQL := sSQL || '       , JIDO_SEINENGAPI';
          sSQL := sSQL || '       , JIDO_JUSHO';
          sSQL := sSQL || '       , HOGOSHA_KOJIJN_NO';
          sSQL := sSQL || '       , HOGOSHA_SHIMEI_KANA';
          sSQL := sSQL || '       , HOGOSHA_SHIMEI_KANJI';
          sSQL := sSQL || '       , HOGOSHA_ZOKUGARA';
          sSQL := sSQL || '       , HOGOSHA_SHIENZOCHI';
          sSQL := sSQL || '       , JINKAKU_KBN';
          sSQL := sSQL || '       , WSNUM';
          sSQL := sSQL || '       , BATCHKBN';
          sSQL := sSQL || '       , JOBNUM ';
          sSQL := sSQL || 'FROM GKBWTOHAIGOTAIHI ';
          sSQL := sSQL || 'WHERE WSNUM = ' || '''' || g_sWSNUM || '''';
          sSQL := sSQL || '      AND BATCHKBN = 2';
          sSQL := sSQL || '      AND JOBNUM = ' || g_nJOBNUM;
          sSQL := sSQL || '      AND UPDATE_FLG = 1 ';
          sSQL := sSQL || 'ORDER BY GAKKO_KBN ASC, NEW_SHUGAKUSHITEIKOU ASC, TENNYUGAKU_GAKUNEN ASC, TSUJO_SHUGAKUYOTEIKO ASC';
          OPEN cCURSOR2 FOR sSQL;
          LOOP
              FETCH cCURSOR2 INTO rDATA;
              EXIT WHEN cCURSOR2%NOTFOUND;
              --変数の初期化
              rGTG1 := rGTG2;
              rGTR1 := rGTR2;
              BEGIN
                SELECT *
                --学齢簿現最新履歴
                INTO rGTG1
                FROM GKBTGAKUREIBO GTG
                WHERE GTG.KOJIN_NO = rDATA.KOJIN_NO
                  AND GTG.SAISHIN_KBN = 0
                  AND GTG.SAKUJO_FLG = 0;
              EXCEPTION
                WHEN OTHERS THEN
                  rGTG1 := rGTG2;
              END;
              BEGIN
                SELECT *
                --就学履歴現最新履歴
                INTO rGTR1
                FROM GKBTSHUGAKURIREKI GTR
                WHERE GTR.KOJIN_NO = rDATA.KOJIN_NO
                  AND GTR.SAISHIN_FLG = 0
                  AND GTR.SAKUJO_FLG = 0;
              EXCEPTION
                WHEN OTHERS THEN
                  rGTR1 := rGTR2;
              END;
              --最新履歴連番の取得
              nGKBTGAKUREIBOSEQ := rGTG1.RIREKI_RENBAN;
              nGKBTSHUGAKURIREKISEQ := rGTR1.SHUGAKU_RIREKI_RENBAN;
              BEGIN
                SELECT GAKUNEN_RIREKI_RENBAN
                INTO nGKBTGAKUNENRIREKISEQ
                FROM GKBTGAKUNENRIREKI
                WHERE KOJIN_NO = rDATA.KOJIN_NO
                  AND SAISIN_FLG = 0
                  AND SAKUJO_FLG = 0;
              EXCEPTION
                WHEN OTHERS THEN
                  nGKBTGAKUNENRIREKISEQ := 0;
              END;
              --更新処理
              IF rDATA.NOW_GAKUNEN = 0 THEN
                --学齢簿の現最新履歴の最新区分を変更する
                UPDATE GKBTGAKUREIBO
                SET SAISHIN_KBN = 1,        --最新区分固定値「1」
                    SYS_KOSHINBI = g_nDATE, --更新日
                    SYS_JIKAN = g_nTIME,    --システム時間
                    SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                    SYS_TANMATU_NO = g_sWSNUM
                WHERE KOJIN_NO = rDATA.KOJIN_NO
                  AND SAISHIN_KBN = 0;
                --学齢簿の履歴を作成する ※新入学児童の場合
                rGKBTGAKUREIBO_I.KOJIN_NO := rDATA.KOJIN_NO;
                nGKBTGAKUREIBOSEQ := nGKBTGAKUREIBOSEQ + 10;
                rGKBTGAKUREIBO_I.RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                rGKBTGAKUREIBO_I.RIREKI_RENBAN_EDA := 0;
                rGKBTGAKUREIBO_I.GENZON_KBN := rGTG1.GENZON_KBN;
                rGKBTGAKUREIBO_I.SAISHIN_KBN := 0;
                rGKBTGAKUREIBO_I.ZO_JIYU_CD := rGTG1.ZO_JIYU_CD;
                rGKBTGAKUREIBO_I.ZO_NENGAPI := rGTG1.ZO_NENGAPI;
                rGKBTGAKUREIBO_I.GEN_JIYU_CD := rGTG1.GEN_JIYU_CD;
                rGKBTGAKUREIBO_I.GEN_NENGAPI := rGTG1.GEN_NENGAPI;
                rGKBTGAKUREIBO_I.ZOKUGARA1 := rGTG1.ZOKUGARA1;
                rGKBTGAKUREIBO_I.ZOKUGARA2 := rGTG1.ZOKUGARA2;
                rGKBTGAKUREIBO_I.ZOKUGARA3 := rGTG1.ZOKUGARA3;
                rGKBTGAKUREIBO_I.ZOKUGARA4 := rGTG1.ZOKUGARA4;
                rGKBTGAKUREIBO_I.HOGOSYA_KOJIN_NO := rGTG1.HOGOSYA_KOJIN_NO;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA1 := rGTG1.HOGOSYA_ZOKUGARA1;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA2 := rGTG1.HOGOSYA_ZOKUGARA2;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA3 := rGTG1.HOGOSYA_ZOKUGARA3;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA4 := rGTG1.HOGOSYA_ZOKUGARA4;
                IF rDATA.NOW_GAKUNEN = 0 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_CD := rGTG1.SYOGAKO_CD;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := rGTG1.SYOGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := rGTG1.SYOGAKO_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := rGTG1.SYOGAKO_TENGAKU_BI;
                rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := rGTG1.SYOGAKO_SOTSUGYO_BI;
                IF rDATA.NOW_GAKUNEN = 0 THEN
                  rGKBTGAKUREIBO_I.TYUGAKO_CD := rGTG1.TYUGAKO_CD;
                ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                  rGKBTGAKUREIBO_I.TYUGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := rGTG1.TYUGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := rGTG1.TYUGAKO_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := rGTG1.TYUGAKO_TENGAKU_BI;
                rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := rGTG1.TYUGAKO_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI1 := rGTG1.TOKUSOKU_BI1;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO1 := rGTG1.TOKUSOKU_NAIYO1;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU1 := rGTG1.TOKUSOKU_JIYU1;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI1 := rGTG1.TOKUSOKU_JURI_BI1;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI2 := rGTG1.TOKUSOKU_BI2;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO2 := rGTG1.TOKUSOKU_NAIYO2;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU2 := rGTG1.TOKUSOKU_JIYU2;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI2 := rGTG1.TOKUSOKU_JURI_BI2;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI3 := rGTG1.TOKUSOKU_BI3;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO3 := rGTG1.TOKUSOKU_NAIYO3;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU3 := rGTG1.TOKUSOKU_JIYU3;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI3 := rGTG1.TOKUSOKU_JURI_BI3;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI4 := rGTG1.TOKUSOKU_BI4;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO4 := rGTG1.TOKUSOKU_NAIYO4;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU4 := rGTG1.TOKUSOKU_JIYU4;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI4 := rGTG1.TOKUSOKU_JURI_BI4;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI5 := rGTG1.TOKUSOKU_BI5;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO5 := rGTG1.TOKUSOKU_NAIYO5;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU5 := rGTG1.TOKUSOKU_JIYU5;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI5 := rGTG1.TOKUSOKU_JURI_BI5;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI6 := rGTG1.TOKUSOKU_BI6;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO6 := rGTG1.TOKUSOKU_NAIYO6;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU6 := rGTG1.TOKUSOKU_JIYU6;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI6 := rGTG1.TOKUSOKU_JURI_BI6;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI7 := rGTG1.TOKUSOKU_BI7;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO7 := rGTG1.TOKUSOKU_NAIYO7;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU7 := rGTG1.TOKUSOKU_JIYU7;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI7 := rGTG1.TOKUSOKU_JURI_BI7;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI8 := rGTG1.TOKUSOKU_BI8;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO8 := rGTG1.TOKUSOKU_NAIYO8;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU8 := rGTG1.TOKUSOKU_JIYU8;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI8 := rGTG1.TOKUSOKU_JURI_BI8;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI9 := rGTG1.TOKUSOKU_BI9;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO9 := rGTG1.TOKUSOKU_NAIYO9;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU9 := rGTG1.TOKUSOKU_JIYU9;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI9 := rGTG1.TOKUSOKU_JURI_BI9;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI10 := rGTG1.TOKUSOKU_BI10;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO10 := rGTG1.TOKUSOKU_NAIYO10;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU10 := rGTG1.TOKUSOKU_JIYU10;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI10 := rGTG1.TOKUSOKU_JURI_BI10;
                rGKBTGAKUREIBO_I.KUIKIGAI_CD := rGTG1.KUIKIGAI_CD;
                rGKBTGAKUREIBO_I.KUIKIGAI_SETISYA := rGTG1.KUIKIGAI_SETISYA;
                rGKBTGAKUREIBO_I.KUIKIGAI_NYUGAKU_BI := rGTG1.KUIKIGAI_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_BI := rGTG1.KUIKIGAI_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_BI := rGTG1.KUIKIGAI_TENGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_BI := rGTG1.KUIKIGAI_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_SOTSUGYO_BI := rGTG1.KUIKIGAI_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_CD := rGTG1.YOGOGAKO_CD;
                rGKBTGAKUREIBO_I.YOGOGAKO_SETISYA := rGTG1.YOGOGAKO_SETISYA;
                rGKBTGAKUREIBO_I.YOGOGAKO_NYUGAKU_BI := rGTG1.YOGOGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_BI := rGTG1.YOGOGAKO_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_BI := rGTG1.YOGOGAKO_TENGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_BI := rGTG1.YOGOGAKO_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_SOTSUGYO_BI := rGTG1.YOGOGAKO_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.YUYO_KYOKA_BI := rGTG1.YUYO_KYOKA_BI;
                rGKBTGAKUREIBO_I.YUYO_JIYU_CD := rGTG1.YUYO_JIYU_CD;
                rGKBTGAKUREIBO_I.YUYO_JIYU := rGTG1.YUYO_JIYU;
                rGKBTGAKUREIBO_I.YUYO_KAISI_BI := rGTG1.YUYO_KAISI_BI;
                rGKBTGAKUREIBO_I.YUYO_SYURYO_BI := rGTG1.YUYO_SYURYO_BI;
                rGKBTGAKUREIBO_I.YUYO_NENSU := rGTG1.YUYO_NENSU;
                rGKBTGAKUREIBO_I.YUYO_FUKUGAKU_BI := rGTG1.YUYO_FUKUGAKU_BI;
                rGKBTGAKUREIBO_I.MENJO_KYOKA_BI := rGTG1.MENJO_KYOKA_BI;
                rGKBTGAKUREIBO_I.MENJO_JIYU_CD := rGTG1.MENJO_JIYU_CD;
                rGKBTGAKUREIBO_I.MENJO_JIYU := rGTG1.MENJO_JIYU;
                rGKBTGAKUREIBO_I.MENJO_KAISI_BI := rGTG1.MENJO_KAISI_BI;
                rGKBTGAKUREIBO_I.MENJO_SYURYO_BI := rGTG1.MENJO_SYURYO_BI;
                rGKBTGAKUREIBO_I.MENJO_NENSU := rGTG1.MENJO_NENSU;
                rGKBTGAKUREIBO_I.MENJO_FUKUGAKU_BI := rGTG1.MENJO_FUKUGAKU_BI;
                rGKBTGAKUREIBO_I.IDO_BI1 := rGTG1.IDO_BI1;
                rGKBTGAKUREIBO_I.IDO_JIYU1 := rGTG1.IDO_JIYU1;
                rGKBTGAKUREIBO_I.IDO_BI2 := rGTG1.IDO_BI2;
                rGKBTGAKUREIBO_I.IDO_JIYU2 := rGTG1.IDO_JIYU2;
                rGKBTGAKUREIBO_I.IDO_BI3 := rGTG1.IDO_BI3;
                rGKBTGAKUREIBO_I.IDO_JIYU3 := rGTG1.IDO_JIYU3;
                rGKBTGAKUREIBO_I.IDO_BI4 := rGTG1.IDO_BI4;
                rGKBTGAKUREIBO_I.IDO_JIYU4 := rGTG1.IDO_JIYU4;
                rGKBTGAKUREIBO_I.IDO_BI5 := rGTG1.IDO_BI5;
                rGKBTGAKUREIBO_I.IDO_JIYU5 := rGTG1.IDO_JIYU5;
                rGKBTGAKUREIBO_I.IDO_BI6 := rGTG1.IDO_BI6;
                rGKBTGAKUREIBO_I.IDO_JIYU6 := rGTG1.IDO_JIYU6;
                rGKBTGAKUREIBO_I.IDO_BI7 := rGTG1.IDO_BI7;
                rGKBTGAKUREIBO_I.IDO_JIYU7 := rGTG1.IDO_JIYU7;
                rGKBTGAKUREIBO_I.IDO_BI8 := rGTG1.IDO_BI8;
                rGKBTGAKUREIBO_I.IDO_JIYU8 := rGTG1.IDO_JIYU8;
                rGKBTGAKUREIBO_I.IDO_BI9 := rGTG1.IDO_BI9;
                rGKBTGAKUREIBO_I.IDO_JIYU9 := rGTG1.IDO_JIYU9;
                rGKBTGAKUREIBO_I.IDO_BI10 := rGTG1.IDO_BI10;
                rGKBTGAKUREIBO_I.IDO_JIYU10 := rGTG1.IDO_JIYU10;
                rGKBTGAKUREIBO_I.SYS_SAKUSEIBI := rGTG1.SYS_SAKUSEIBI;
                rGKBTGAKUREIBO_I.SYS_KOSHINBI := g_nDATE;
                rGKBTGAKUREIBO_I.SYS_JIKAN := g_nTIME;
                rGKBTGAKUREIBO_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                rGKBTGAKUREIBO_I.SYS_TANMATU_NO := g_sWSNUM;
                rGKBTGAKUREIBO_I.GAKUNEN := rGTG1.GAKUNEN;
                rGKBTGAKUREIBO_I.SHORIBI := g_nDATE;
                rGKBTGAKUREIBO_I.SHUGAKU := rGTG1.SHUGAKU;
                rGKBTGAKUREIBO_I.IDOJIKO := rGTG1.IDOJIKO;
                rGKBTGAKUREIBO_I.CHOHYO_NO := rGTG1.CHOHYO_NO;
                rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.SYOGAKO_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rGTG1.SYOGAKO_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rGTG1.TYUGAKO_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rGTG1.TYUGAKO_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_GAKUNEN := rGTG1.KUIKIGAI_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_GAKUNEN := rGTG1.YOGOGAKO_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.GAKKO_KBN_CD := rGTG1.GAKKO_KBN_CD;
                rGKBTGAKUREIBO_I.GAKUKYU_CD := rGTG1.GAKUKYU_CD;
                rGKBTGAKUREIBO_I.SEIBETSU := rGTG1.SEIBETSU;
                rGKBTGAKUREIBO_I.JOTAI := rGTG1.JOTAI;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_KBN := rGTG1.TENNYUMAE_GAKKO_KBN;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_CD := rGTG1.TENNYUMAE_GAKKO_CD;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKUNEN := rGTG1.TENNYUMAE_GAKUNEN;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_FLG := rGTG1.GENKYURYUCHI_FLG;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_KETTEI_BI := rGTG1.GENKYURYUCHI_KETTEI_BI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_KAISI_BI := rGTG1.GENKYURYUCHI_KAISI_BI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_SYURYOBI := rGTG1.GENKYURYUCHI_SYURYOBI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_RIYU := rGTG1.GENKYURYUCHI_RIYU;
                IF rDATA.NOW_GAKUNEN = 0 THEN
                  rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                  rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rGTG1.SHITEI_SYOGAKO_CD;
                ELSE
                  NULL;
                END IF;
                IF rDATA.NOW_GAKUNEN = 0 THEN
                  rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rGTG1.SHITEI_TYUGAKO_CD;
                ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                  rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.HENKO_GAKUNEN_SYOGAKO := rGTG1.HENKO_GAKUNEN_SYOGAKO;
                rGKBTGAKUREIBO_I.HENKO_GAKUNEN_TYUGAKO := rGTG1.HENKO_GAKUNEN_TYUGAKO;
                rGKBTGAKUREIBO_I.HENKO_SHINSEI_BI := rGTG1.HENKO_SHINSEI_BI;
                rGKBTGAKUREIBO_I.HENKO_KYOKA_BI := rGTG1.HENKO_KYOKA_BI;
                rGKBTGAKUREIBO_I.HENKO_KBN := rGTG1.HENKO_KBN;
                rGKBTGAKUREIBO_I.HENKO_KAISI_BI := rGTG1.HENKO_KAISI_BI;
                rGKBTGAKUREIBO_I.HENKO_SYURYO_BI := rGTG1.HENKO_SYURYO_BI;
                rGKBTGAKUREIBO_I.HENKO_KYOKA_RIYU := rGTG1.HENKO_KYOKA_RIYU;
                rGKBTGAKUREIBO_I.HENKO_JIYU := rGTG1.HENKO_JIYU;
                rGKBTGAKUREIBO_I.HENKO_HUKYOKA_RIYU := rGTG1.HENKO_HUKYOKA_RIYU;
                rGKBTGAKUREIBO_I.KIBO_GAKKO_KBN_CD := rGTG1.KIBO_GAKKO_KBN_CD;
                rGKBTGAKUREIBO_I.KIBO_SYOGAKKO_CD := rGTG1.KIBO_SYOGAKKO_CD;
                rGKBTGAKUREIBO_I.KIBO_TYUGAKKO_CD := rGTG1.KIBO_TYUGAKKO_CD;
                rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_SYOGAKO := rGTG1.KIBO_UKETSUKE_BI_SYOGAKO;
                rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_TYUGAKO := rGTG1.KIBO_UKETSUKE_BI_TYUGAKO;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_FLG := rGTG1.KUIKIGAISHUGAKU_FLG;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SHINSEI_BI := rGTG1.KUIKIGAISHUGAKU_SHINSEI_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_BI := rGTG1.KUIKIGAISHUGAKU_KYOKA_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KAISI_BI := rGTG1.KUIKIGAISHUGAKU_KAISI_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SYURYO_BI := rGTG1.KUIKIGAISHUGAKU_SYURYO_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_JIYU := rGTG1.KUIKIGAISHUGAKU_JIYU;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_KYOKA_RIYU;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_HUKYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_HUKYOKA_RIYU;
                rGKBTGAKUREIBO_I.HUSHUGAKU_KAISI_BI := rGTG1.HUSHUGAKU_KAISI_BI;
                rGKBTGAKUREIBO_I.HUSHUGAKU_SYURYO_BI := rGTG1.HUSHUGAKU_SYURYO_BI;
                rGKBTGAKUREIBO_I.HUSHUGAKU_RIYU := rGTG1.HUSHUGAKU_RIYU;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_CD := rGTG1.KUNISHIRITSU_CD;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_NYUGAKU_BI := rGTG1.KUNISHIRITSU_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_BI := rGTG1.KUNISHIRITSU_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_BI := rGTG1.KUNISHIRITSU_TENGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_BI := rGTG1.KUNISHIRITSU_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_SOTSUGYO_BI := rGTG1.KUNISHIRITSU_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_KAISI_BI := rGTG1.KUNISHIRITSU_KAISI_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_SYURYO_BI := rGTG1.KUNISHIRITSU_SYURYO_BI;
                rGKBTGAKUREIBO_I.TSUSHOMEI_KANA := rGTG1.TSUSHOMEI_KANA;
                rGKBTGAKUREIBO_I.TSUSHOMEI_KANJI := rGTG1.TSUSHOMEI_KANJI;
                rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANA := rGTG1.HOGOSHA_TSUSHOMEI_KANA;
                rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANJI := rGTG1.HOGOSHA_TSUSHOMEI_KANJI;
                rGKBTGAKUREIBO_I.GRB_HENKO_TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                rGKBTGAKUREIBO_I.GRB_HENKO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                nRTN := KKAPK0030.FCTGetR('GKB', '00TOHAIGO_HENKOJIYU', '0000', 0, aPRM);
                IF aPRM(1) = '1' THEN
                  rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 14;
                ELSIF aPRM(1) = '2' THEN
                  rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 99;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.BIKO := REPLACE(rGTG1.BIKO, chr(13)||chr(10),'#') || '新設・統廃合一括処理による学校変更';
                rGKBTGAKUREIBO_I.IDO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                rGKBTGAKUREIBO_I.TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                rGKBTGAKUREIBO_I.SHINSEI_KANRI_RENBAN := rGTG1.SHINSEI_KANRI_RENBAN;
                rGKBTGAKUREIBO_I.IDOJI_ATENA_RIREKI_RENBAN := rGTG1.IDOJI_ATENA_RIREKI_RENBAN;
                rGKBTGAKUREIBO_I.HOGOSYA_IDOJI_RIREKI_RENBAN := rGTG1.HOGOSYA_IDOJI_RIREKI_RENBAN;
                IF rDATA.NOW_GAKUNEN = 0 THEN
                  rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rDATA.NEW_GAKKOKU_CD;
                ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                  rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rGTG1.SHOGAKKOKU_CD;
                ELSE
                  NULL;
                END IF;
                IF rDATA.NOW_GAKUNEN = 0 THEN
                  rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rGTG1.CHUGAKKOKU_CD;
                ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                  rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rDATA.NEW_GAKKOKU_CD;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.SAKUJO_FLG := 0;
                BEGIN
                  SELECT
                    BUKACODE
                  INTO sBUKACODE
                  FROM
                    KKNTWS
                  WHERE
                    KKNTWS.WSNUM = g_sWSNUM;
                EXCEPTION
                  WHEN OTHERS THEN
                    sBUKACODE := NULL;
                END;
                BEGIN
                  SELECT
                    BUKANAME
                  INTO rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO
                  FROM
                    KKNTBK
                  WHERE
                    BUKACODE = sBUKACODE
                    AND KKNTBK.YUKOKIKANFR = (
                                               SELECT MAX(YUKOKIKANFR) FROM KKNTBK WHERE BUKACODE = sBUKACODE
                                              );
                EXCEPTION
                  WHEN OTHERS THEN
                    rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO := NULL;
                END;
                INSERT INTO GKBTGAKUREIBO VALUES rGKBTGAKUREIBO_I;
              ELSIF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 5 THEN
                --学齢簿、就学履歴の現最新履歴の最新区分を変更する。
                UPDATE GKBTGAKUREIBO
                SET SAISHIN_KBN = 1,        --最新区分固定値「1」
                    SYS_KOSHINBI = g_nDATE, --更新日
                    SYS_JIKAN = g_nTIME,    --システム時間
                    SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                    SYS_TANMATU_NO = g_sWSNUM
                WHERE KOJIN_NO = rDATA.KOJIN_NO
                  AND SAISHIN_KBN = 0;
                UPDATE GKBTSHUGAKURIREKI
                SET SAISHIN_FLG = 1,        --最新フラグ固定値「1」
                    SYS_KOSHINBI = g_nDATE, --更新日
                    SYS_JIKAN = g_nTIME,    --システム時間
                    SYS_SHOKUINKOJIN_NO = g_sTANTOCODE, --更新職員宛名番号
                    SYS_TANMATU_NO = g_sWSNUM --更新端末番号
                WHERE KOJIN_NO = rDATA.KOJIN_NO
                  AND SAISHIN_FLG = 0;
                --学齢簿に転学の履歴を作成する。 ※新入学児童以外の場合の転学時
                rGKBTGAKUREIBO_I.KOJIN_NO := rDATA.KOJIN_NO;
                nGKBTGAKUREIBOSEQ := nGKBTGAKUREIBOSEQ + 10;
                rGKBTGAKUREIBO_I.RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                rGKBTGAKUREIBO_I.RIREKI_RENBAN_EDA := 0;
                rGKBTGAKUREIBO_I.GENZON_KBN := rGTG1.GENZON_KBN;
                rGKBTGAKUREIBO_I.SAISHIN_KBN := 1;
                rGKBTGAKUREIBO_I.ZO_JIYU_CD := rGTG1.ZO_JIYU_CD;
                rGKBTGAKUREIBO_I.ZO_NENGAPI := rGTG1.ZO_NENGAPI;
                rGKBTGAKUREIBO_I.GEN_JIYU_CD := rGTG1.GEN_JIYU_CD;
                rGKBTGAKUREIBO_I.GEN_NENGAPI := rGTG1.GEN_NENGAPI;
                rGKBTGAKUREIBO_I.ZOKUGARA1 := rGTG1.ZOKUGARA1;
                rGKBTGAKUREIBO_I.ZOKUGARA2 := rGTG1.ZOKUGARA2;
                rGKBTGAKUREIBO_I.ZOKUGARA3 := rGTG1.ZOKUGARA3;
                rGKBTGAKUREIBO_I.ZOKUGARA4 := rGTG1.ZOKUGARA4;
                rGKBTGAKUREIBO_I.HOGOSYA_KOJIN_NO := rGTG1.HOGOSYA_KOJIN_NO;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA1 := rGTG1.HOGOSYA_ZOKUGARA1;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA2 := rGTG1.HOGOSYA_ZOKUGARA2;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA3 := rGTG1.HOGOSYA_ZOKUGARA3;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA4 := rGTG1.HOGOSYA_ZOKUGARA4;
                rGKBTGAKUREIBO_I.SYOGAKO_CD := rGTG1.SYOGAKO_CD;
                rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := rGTG1.SYOGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := rGTG1.SYOGAKO_TENNYUGAKU_BI;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := rGTG1.SYOGAKO_TENGAKU_BI;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := rGTG1.SYOGAKO_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.TYUGAKO_CD := rGTG1.TYUGAKO_CD;
                rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := rGTG1.TYUGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := rGTG1.TYUGAKO_TENNYUGAKU_BI;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := rGTG1.TYUGAKO_TENGAKU_BI;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := rGTG1.TYUGAKO_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI1 := rGTG1.TOKUSOKU_BI1;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO1 := rGTG1.TOKUSOKU_NAIYO1;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU1 := rGTG1.TOKUSOKU_JIYU1;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI1 := rGTG1.TOKUSOKU_JURI_BI1;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI2 := rGTG1.TOKUSOKU_BI2;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO2 := rGTG1.TOKUSOKU_NAIYO2;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU2 := rGTG1.TOKUSOKU_JIYU2;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI2 := rGTG1.TOKUSOKU_JURI_BI2;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI3 := rGTG1.TOKUSOKU_BI3;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO3 := rGTG1.TOKUSOKU_NAIYO3;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU3 := rGTG1.TOKUSOKU_JIYU3;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI3 := rGTG1.TOKUSOKU_JURI_BI3;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI4 := rGTG1.TOKUSOKU_BI4;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO4 := rGTG1.TOKUSOKU_NAIYO4;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU4 := rGTG1.TOKUSOKU_JIYU4;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI4 := rGTG1.TOKUSOKU_JURI_BI4;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI5 := rGTG1.TOKUSOKU_BI5;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO5 := rGTG1.TOKUSOKU_NAIYO5;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU5 := rGTG1.TOKUSOKU_JIYU5;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI5 := rGTG1.TOKUSOKU_JURI_BI5;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI6 := rGTG1.TOKUSOKU_BI6;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO6 := rGTG1.TOKUSOKU_NAIYO6;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU6 := rGTG1.TOKUSOKU_JIYU6;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI6 := rGTG1.TOKUSOKU_JURI_BI6;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI7 := rGTG1.TOKUSOKU_BI7;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO7 := rGTG1.TOKUSOKU_NAIYO7;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU7 := rGTG1.TOKUSOKU_JIYU7;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI7 := rGTG1.TOKUSOKU_JURI_BI7;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI8 := rGTG1.TOKUSOKU_BI8;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO8 := rGTG1.TOKUSOKU_NAIYO8;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU8 := rGTG1.TOKUSOKU_JIYU8;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI8 := rGTG1.TOKUSOKU_JURI_BI8;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI9 := rGTG1.TOKUSOKU_BI9;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO9 := rGTG1.TOKUSOKU_NAIYO9;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU9 := rGTG1.TOKUSOKU_JIYU9;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI9 := rGTG1.TOKUSOKU_JURI_BI9;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI10 := rGTG1.TOKUSOKU_BI10;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO10 := rGTG1.TOKUSOKU_NAIYO10;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU10 := rGTG1.TOKUSOKU_JIYU10;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI10 := rGTG1.TOKUSOKU_JURI_BI10;
                rGKBTGAKUREIBO_I.KUIKIGAI_CD := rGTG1.KUIKIGAI_CD;
                rGKBTGAKUREIBO_I.KUIKIGAI_SETISYA := rGTG1.KUIKIGAI_SETISYA;
                rGKBTGAKUREIBO_I.KUIKIGAI_NYUGAKU_BI := rGTG1.KUIKIGAI_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_BI := rGTG1.KUIKIGAI_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_BI := rGTG1.KUIKIGAI_TENGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_BI := rGTG1.KUIKIGAI_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_SOTSUGYO_BI := rGTG1.KUIKIGAI_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_CD := rGTG1.YOGOGAKO_CD;
                rGKBTGAKUREIBO_I.YOGOGAKO_SETISYA := rGTG1.YOGOGAKO_SETISYA;
                rGKBTGAKUREIBO_I.YOGOGAKO_NYUGAKU_BI := rGTG1.YOGOGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_BI := rGTG1.YOGOGAKO_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_BI := rGTG1.YOGOGAKO_TENGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_BI := rGTG1.YOGOGAKO_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_SOTSUGYO_BI := rGTG1.YOGOGAKO_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.YUYO_KYOKA_BI := rGTG1.YUYO_KYOKA_BI;
                rGKBTGAKUREIBO_I.YUYO_JIYU_CD := rGTG1.YUYO_JIYU_CD;
                rGKBTGAKUREIBO_I.YUYO_JIYU := rGTG1.YUYO_JIYU;
                rGKBTGAKUREIBO_I.YUYO_KAISI_BI := rGTG1.YUYO_KAISI_BI;
                rGKBTGAKUREIBO_I.YUYO_SYURYO_BI := rGTG1.YUYO_SYURYO_BI;
                rGKBTGAKUREIBO_I.YUYO_NENSU := rGTG1.YUYO_NENSU;
                rGKBTGAKUREIBO_I.YUYO_FUKUGAKU_BI := rGTG1.YUYO_FUKUGAKU_BI;
                rGKBTGAKUREIBO_I.MENJO_KYOKA_BI := rGTG1.MENJO_KYOKA_BI;
                rGKBTGAKUREIBO_I.MENJO_JIYU_CD := rGTG1.MENJO_JIYU_CD;
                rGKBTGAKUREIBO_I.MENJO_JIYU := rGTG1.MENJO_JIYU;
                rGKBTGAKUREIBO_I.MENJO_KAISI_BI := rGTG1.MENJO_KAISI_BI;
                rGKBTGAKUREIBO_I.MENJO_SYURYO_BI := rGTG1.MENJO_SYURYO_BI;
                rGKBTGAKUREIBO_I.MENJO_NENSU := rGTG1.MENJO_NENSU;
                rGKBTGAKUREIBO_I.MENJO_FUKUGAKU_BI := rGTG1.MENJO_FUKUGAKU_BI;
                rGKBTGAKUREIBO_I.IDO_BI1 := rGTG1.IDO_BI1;
                rGKBTGAKUREIBO_I.IDO_JIYU1 := rGTG1.IDO_JIYU1;
                rGKBTGAKUREIBO_I.IDO_BI2 := rGTG1.IDO_BI2;
                rGKBTGAKUREIBO_I.IDO_JIYU2 := rGTG1.IDO_JIYU2;
                rGKBTGAKUREIBO_I.IDO_BI3 := rGTG1.IDO_BI3;
                rGKBTGAKUREIBO_I.IDO_JIYU3 := rGTG1.IDO_JIYU3;
                rGKBTGAKUREIBO_I.IDO_BI4 := rGTG1.IDO_BI4;
                rGKBTGAKUREIBO_I.IDO_JIYU4 := rGTG1.IDO_JIYU4;
                rGKBTGAKUREIBO_I.IDO_BI5 := rGTG1.IDO_BI5;
                rGKBTGAKUREIBO_I.IDO_JIYU5 := rGTG1.IDO_JIYU5;
                rGKBTGAKUREIBO_I.IDO_BI6 := rGTG1.IDO_BI6;
                rGKBTGAKUREIBO_I.IDO_JIYU6 := rGTG1.IDO_JIYU6;
                rGKBTGAKUREIBO_I.IDO_BI7 := rGTG1.IDO_BI7;
                rGKBTGAKUREIBO_I.IDO_JIYU7 := rGTG1.IDO_JIYU7;
                rGKBTGAKUREIBO_I.IDO_BI8 := rGTG1.IDO_BI8;
                rGKBTGAKUREIBO_I.IDO_JIYU8 := rGTG1.IDO_JIYU8;
                rGKBTGAKUREIBO_I.IDO_BI9 := rGTG1.IDO_BI9;
                rGKBTGAKUREIBO_I.IDO_JIYU9 := rGTG1.IDO_JIYU9;
                rGKBTGAKUREIBO_I.IDO_BI10 := rGTG1.IDO_BI10;
                rGKBTGAKUREIBO_I.IDO_JIYU10 := rGTG1.IDO_JIYU10;
                rGKBTGAKUREIBO_I.SYS_SAKUSEIBI := rGTG1.SYS_SAKUSEIBI;
                rGKBTGAKUREIBO_I.SYS_KOSHINBI := g_nDATE;
                rGKBTGAKUREIBO_I.SYS_JIKAN := g_nTIME;
                rGKBTGAKUREIBO_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                rGKBTGAKUREIBO_I.SYS_TANMATU_NO := g_sWSNUM;
                rGKBTGAKUREIBO_I.GAKUNEN := rGTG1.GAKUNEN;
                rGKBTGAKUREIBO_I.SHORIBI := g_nDATE;
                rGKBTGAKUREIBO_I.SHUGAKU := rGTG1.SHUGAKU;
                rGKBTGAKUREIBO_I.IDOJIKO := rGTG1.IDOJIKO;
                rGKBTGAKUREIBO_I.CHOHYO_NO := rGTG1.CHOHYO_NO;
                rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.SYOGAKO_TENNYUGAKU_GAKUNEN;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rGTG1.SYOGAKO_TENGAKU_GAKUNEN;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rGTG1.TYUGAKO_TENNYUGAKU_GAKUNEN;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rGTG1.TYUGAKO_TENGAKU_GAKUNEN;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_GAKUNEN := rGTG1.KUIKIGAI_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_GAKUNEN := rGTG1.YOGOGAKO_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.GAKKO_KBN_CD := rGTG1.GAKKO_KBN_CD;
                rGKBTGAKUREIBO_I.GAKUKYU_CD := rGTG1.GAKUKYU_CD;
                rGKBTGAKUREIBO_I.SEIBETSU := rGTG1.SEIBETSU;
                rGKBTGAKUREIBO_I.JOTAI := rGTG1.JOTAI;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_KBN := rGTG1.TENNYUMAE_GAKKO_KBN;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_CD := rGTG1.TENNYUMAE_GAKKO_CD;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKUNEN := rGTG1.TENNYUMAE_GAKUNEN;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_FLG := rGTG1.GENKYURYUCHI_FLG;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_KETTEI_BI := rGTG1.GENKYURYUCHI_KETTEI_BI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_KAISI_BI := rGTG1.GENKYURYUCHI_KAISI_BI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_SYURYOBI := rGTG1.GENKYURYUCHI_SYURYOBI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_RIYU := rGTG1.GENKYURYUCHI_RIYU;
                rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rGTG1.SHITEI_SYOGAKO_CD;
                rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rGTG1.SHITEI_TYUGAKO_CD;
                rGKBTGAKUREIBO_I.HENKO_GAKUNEN_SYOGAKO := rGTG1.HENKO_GAKUNEN_SYOGAKO;
                rGKBTGAKUREIBO_I.HENKO_GAKUNEN_TYUGAKO := rGTG1.HENKO_GAKUNEN_TYUGAKO;
                rGKBTGAKUREIBO_I.HENKO_SHINSEI_BI := rGTG1.HENKO_SHINSEI_BI;
                rGKBTGAKUREIBO_I.HENKO_KYOKA_BI := rGTG1.HENKO_KYOKA_BI;
                rGKBTGAKUREIBO_I.HENKO_KBN := rGTG1.HENKO_KBN;
                rGKBTGAKUREIBO_I.HENKO_KAISI_BI := rGTG1.HENKO_KAISI_BI;
                rGKBTGAKUREIBO_I.HENKO_SYURYO_BI := rGTG1.HENKO_SYURYO_BI;
                rGKBTGAKUREIBO_I.HENKO_KYOKA_RIYU := rGTG1.HENKO_KYOKA_RIYU;
                rGKBTGAKUREIBO_I.HENKO_JIYU := rGTG1.HENKO_JIYU;
                rGKBTGAKUREIBO_I.HENKO_HUKYOKA_RIYU := rGTG1.HENKO_HUKYOKA_RIYU;
                rGKBTGAKUREIBO_I.KIBO_GAKKO_KBN_CD := rGTG1.KIBO_GAKKO_KBN_CD;
                rGKBTGAKUREIBO_I.KIBO_SYOGAKKO_CD := rGTG1.KIBO_SYOGAKKO_CD;
                rGKBTGAKUREIBO_I.KIBO_TYUGAKKO_CD := rGTG1.KIBO_TYUGAKKO_CD;
                rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_SYOGAKO := rGTG1.KIBO_UKETSUKE_BI_SYOGAKO;
                rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_TYUGAKO := rGTG1.KIBO_UKETSUKE_BI_TYUGAKO;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_FLG := rGTG1.KUIKIGAISHUGAKU_FLG;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SHINSEI_BI := rGTG1.KUIKIGAISHUGAKU_SHINSEI_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_BI := rGTG1.KUIKIGAISHUGAKU_KYOKA_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KAISI_BI := rGTG1.KUIKIGAISHUGAKU_KAISI_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SYURYO_BI := rGTG1.KUIKIGAISHUGAKU_SYURYO_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_JIYU := rGTG1.KUIKIGAISHUGAKU_JIYU;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_KYOKA_RIYU;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_HUKYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_HUKYOKA_RIYU;
                rGKBTGAKUREIBO_I.HUSHUGAKU_KAISI_BI := rGTG1.HUSHUGAKU_KAISI_BI;
                rGKBTGAKUREIBO_I.HUSHUGAKU_SYURYO_BI := rGTG1.HUSHUGAKU_SYURYO_BI;
                rGKBTGAKUREIBO_I.HUSHUGAKU_RIYU := rGTG1.HUSHUGAKU_RIYU;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_CD := rGTG1.KUNISHIRITSU_CD;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_NYUGAKU_BI := rGTG1.KUNISHIRITSU_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_BI := rGTG1.KUNISHIRITSU_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_BI := rGTG1.KUNISHIRITSU_TENGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_BI := rGTG1.KUNISHIRITSU_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_SOTSUGYO_BI := rGTG1.KUNISHIRITSU_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_KAISI_BI := rGTG1.KUNISHIRITSU_KAISI_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_SYURYO_BI := rGTG1.KUNISHIRITSU_SYURYO_BI;
                rGKBTGAKUREIBO_I.TSUSHOMEI_KANA := rGTG1.TSUSHOMEI_KANA;
                rGKBTGAKUREIBO_I.TSUSHOMEI_KANJI := rGTG1.TSUSHOMEI_KANJI;
                rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANA := rGTG1.HOGOSHA_TSUSHOMEI_KANA;
                rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANJI := rGTG1.HOGOSHA_TSUSHOMEI_KANJI;
                rGKBTGAKUREIBO_I.GRB_HENKO_TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                rGKBTGAKUREIBO_I.GRB_HENKO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                nRTN := KKAPK0030.FCTGetR('GKB', '00TOHAIGO_HENKOJIYU', '0000', 0, aPRM);
                IF aPRM(1) = '1' THEN
                  rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 14;
                ELSIF aPRM(1) = '2' THEN
                  rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 99;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.BIKO := REPLACE(rGTG1.BIKO, chr(13)||chr(10),'#') || '新設・統廃合一括処理による転学';
                rGKBTGAKUREIBO_I.IDO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                rGKBTGAKUREIBO_I.TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                rGKBTGAKUREIBO_I.SHINSEI_KANRI_RENBAN := rGTG1.SHINSEI_KANRI_RENBAN;
                rGKBTGAKUREIBO_I.IDOJI_ATENA_RIREKI_RENBAN := rGTG1.IDOJI_ATENA_RIREKI_RENBAN;
                rGKBTGAKUREIBO_I.HOGOSYA_IDOJI_RIREKI_RENBAN := rGTG1.HOGOSYA_IDOJI_RIREKI_RENBAN;
                rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rGTG1.SHOGAKKOKU_CD;
                rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rGTG1.CHUGAKKOKU_CD;
                rGKBTGAKUREIBO_I.SAKUJO_FLG := 0;
                BEGIN
                  SELECT
                    BUKACODE
                  INTO sBUKACODE
                  FROM
                    KKNTWS
                  WHERE
                    KKNTWS.WSNUM = g_sWSNUM;
                EXCEPTION
                  WHEN OTHERS THEN
                    sBUKACODE := NULL;
                END;
                BEGIN
                  SELECT
                    BUKANAME
                  INTO rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO
                  FROM
                    KKNTBK
                  WHERE
                    BUKACODE = sBUKACODE
                    AND KKNTBK.YUKOKIKANFR = (
                                               SELECT MAX(YUKOKIKANFR) FROM KKNTBK WHERE BUKACODE = sBUKACODE
                                              );
                EXCEPTION
                  WHEN OTHERS THEN
                    rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO := NULL;
                END;
                INSERT INTO GKBTGAKUREIBO VALUES rGKBTGAKUREIBO_I;
                --就学履歴に転学の履歴を作成する。 ※転学時
                rGKBTSHUGAKURIREKI_I.KOJIN_NO := rDATA.KOJIN_NO;
                rGKBTSHUGAKURIREKI_I.NENDO := TO_NUMBER(SUBSTR(KKAPK0020.FNENDOHENKAN(g_vTENGAKUYMD), 1, 4));
                rGKBTSHUGAKURIREKI_I.KOJIN_RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                nGKBTSHUGAKURIREKISEQ := nGKBTSHUGAKURIREKISEQ + 10;
                rGKBTSHUGAKURIREKI_I.SHUGAKU_RIREKI_RENBAN := nGKBTSHUGAKURIREKISEQ;
                rGKBTSHUGAKURIREKI_I.SAISHIN_FLG := 1;
                rGKBTSHUGAKURIREKI_I.S_CD := rGTR1.S_CD;
                rGKBTSHUGAKURIREKI_I.S_NYUGAKU_BI := rGTR1.S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.S_TENNYU_BI := rGTR1.S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.S_TENNYU_GAKUNEN := rGTR1.S_TENNYU_GAKUNEN;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(g_vTENGAKUYMD);
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := rGTR1.S_TENGAKU_BI;
                ELSE
                  NULL;
                END IF;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := rGTR1.S_TENGAKU_GAKUNEN;
                ELSE
                  NULL;
                END IF;
                rGKBTSHUGAKURIREKI_I.S_TAIGAKU_BI := rGTR1.S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.S_TAIGAKU_GAKUNEN := rGTR1.S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.S_SOTSUGYO_BI := rGTR1.S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.T_CD := rGTR1.T_CD;
                rGKBTSHUGAKURIREKI_I.T_NYUGAKU_BI := rGTR1.T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.T_TENNYU_BI := rGTR1.T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.T_TENNYU_GAKUNEN := rGTR1.T_TENNYU_GAKUNEN;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := rGTR1.T_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := rGTR1.T_TENGAKU_GAKUNEN;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(g_vTENGAKUYMD);
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                ELSE
                  NULL;
                END IF;
                rGKBTSHUGAKURIREKI_I.T_TAIGAKU_BI := rGTR1.T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.T_TAIGAKU_GAKUNEN := rGTR1.T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.T_SOTSUGYO_BI := rGTR1.T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_BU_CD := rGTR1.SHIEN_BU_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_CD := rGTR1.SHIEN_S_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_HUKUSEKI_CD := rGTR1.SHIEN_S_HUKUSEKI_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_NYUGAKU_BI := rGTR1.SHIEN_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_BI := rGTR1.SHIEN_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_GAKUNEN := rGTR1.SHIEN_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_BI := rGTR1.SHIEN_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_GAKUNEN := rGTR1.SHIEN_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_BI := rGTR1.SHIEN_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_GAKUNEN := rGTR1.SHIEN_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_SOTSUGYO_BI := rGTR1.SHIEN_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_CD := rGTR1.SHIEN_T_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_HUKUSEKI_CD := rGTR1.SHIEN_T_HUKUSEKI_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_NYUGAKU_BI := rGTR1.SHIEN_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_BI := rGTR1.SHIEN_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_GAKUNEN := rGTR1.SHIEN_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_BI := rGTR1.SHIEN_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_GAKUNEN := rGTR1.SHIEN_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_BI := rGTR1.SHIEN_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_GAKUNEN := rGTR1.SHIEN_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_SOTSUGYO_BI := rGTR1.SHIEN_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_CD := rGTR1.KUIKIGAI_S_CD;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_S_KAISHI_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_NYUGAKU_BI := rGTR1.KUIKIGAI_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_BI := rGTR1.KUIKIGAI_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_BI := rGTR1.KUIKIGAI_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_BI := rGTR1.KUIKIGAI_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SOTSUGYO_BI := rGTR1.KUIKIGAI_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_BI := rGTR1.KUIKIGAI_S_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SHURYO_BI := rGTR1.KUIKIGAI_S_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAIJO_BI := rGTR1.KUIKIGAI_S_KAIJO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_CD := rGTR1.KUIKIGAI_T_CD;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_T_KAISHI_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_NYUGAKU_BI := rGTR1.KUIKIGAI_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_BI := rGTR1.KUIKIGAI_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_BI := rGTR1.KUIKIGAI_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_BI := rGTR1.KUIKIGAI_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SOTSUGYO_BI := rGTR1.KUIKIGAI_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_BI := rGTR1.KUIKIGAI_T_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SHURYO_BI := rGTR1.KUIKIGAI_T_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAIJO_BI := rGTR1.KUIKIGAI_T_KAIJO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_CD := rGTR1.KUNISHIRITSU_S_CD;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_NYUGAKU_BI := rGTR1.KUNISHIRITSU_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_BI := rGTR1.KUNISHIRITSU_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_BI := rGTR1.KUNISHIRITSU_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_BI := rGTR1.KUNISHIRITSU_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_KAISHI_BI := rGTR1.KUNISHIRITSU_S_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SHURYO_BI := rGTR1.KUNISHIRITSU_S_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_CD := rGTR1.KUNISHIRITSU_T_CD;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_NYUGAKU_BI := rGTR1.KUNISHIRITSU_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_BI := rGTR1.KUNISHIRITSU_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_BI := rGTR1.KUNISHIRITSU_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_BI := rGTR1.KUNISHIRITSU_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_KAISHI_BI := rGTR1.KUNISHIRITSU_T_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SHURYO_BI := rGTR1.KUNISHIRITSU_T_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.SAKUJO_FLG := 0;
                rGKBTSHUGAKURIREKI_I.SYS_SAKUSEIBI := g_nDATE;
                rGKBTSHUGAKURIREKI_I.SYS_KOSHINBI := 0;
                rGKBTSHUGAKURIREKI_I.SYS_JIKAN := g_nTIME;
                rGKBTSHUGAKURIREKI_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                rGKBTSHUGAKURIREKI_I.SYS_TANMATU_NO := g_sWSNUM;
                INSERT INTO GKBTSHUGAKURIREKI VALUES rGKBTSHUGAKURIREKI_I;
                rGTG1 := rGTG2;
                rGTR1 := rGTR2;
                --学齢簿、就学履歴の現最新履歴を取得し直す。
                BEGIN
                  SELECT *
                  --学齢簿現最新履歴
                  INTO rGTG1
                  FROM GKBTGAKUREIBO GTG
                  WHERE GTG.KOJIN_NO = rDATA.KOJIN_NO
--  2024/11/23 YAMANI.OHARA UPDATE START 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
--                    AND GTG.SAISHIN_KBN = 0
          AND GTG.RIREKI_RENBAN = nGKBTGAKUREIBOSEQ
--  2024/11/23 YAMANI.OHARA UPDATE END
                    AND GTG.SAKUJO_FLG = 0;
                EXCEPTION
                  WHEN OTHERS THEN
                    rGTG1 := rGTG2;
                END;
                BEGIN
                  SELECT *
                  --就学履歴現最新履歴
                  INTO rGTR1
                  FROM GKBTSHUGAKURIREKI GTR
                  WHERE GTR.KOJIN_NO = rDATA.KOJIN_NO
--  2024/11/23 YAMANI.OHARA UPDATE START 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
--                    AND GTR.SAISHIN_FLG = 0
          AND GTR.KOJIN_RIREKI_RENBAN = nGKBTGAKUREIBOSEQ
          AND GTR.SHUGAKU_RIREKI_RENBAN = nGKBTSHUGAKURIREKISEQ
--  2024/11/23 YAMANI.OHARA UPDATE END
                    AND GTR.SAKUJO_FLG = 0;
                EXCEPTION
                  WHEN OTHERS THEN
                    rGTR1 := rGTR2;
                END;
                --学齢簿に転入学の履歴を作成する。 ※新入学児童以外の場合の転入学
                rGKBTGAKUREIBO_I.KOJIN_NO := rDATA.KOJIN_NO;
                nGKBTGAKUREIBOSEQ := nGKBTGAKUREIBOSEQ + 10;
                rGKBTGAKUREIBO_I.RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                rGKBTGAKUREIBO_I.RIREKI_RENBAN_EDA := 0;
                rGKBTGAKUREIBO_I.GENZON_KBN := rGTG1.GENZON_KBN;
                rGKBTGAKUREIBO_I.SAISHIN_KBN := 0;
                rGKBTGAKUREIBO_I.ZO_JIYU_CD := rGTG1.ZO_JIYU_CD;
                rGKBTGAKUREIBO_I.ZO_NENGAPI := rGTG1.ZO_NENGAPI;
                rGKBTGAKUREIBO_I.GEN_JIYU_CD := rGTG1.GEN_JIYU_CD;
                rGKBTGAKUREIBO_I.GEN_NENGAPI := rGTG1.GEN_NENGAPI;
                rGKBTGAKUREIBO_I.ZOKUGARA1 := rGTG1.ZOKUGARA1;
                rGKBTGAKUREIBO_I.ZOKUGARA2 := rGTG1.ZOKUGARA2;
                rGKBTGAKUREIBO_I.ZOKUGARA3 := rGTG1.ZOKUGARA3;
                rGKBTGAKUREIBO_I.ZOKUGARA4 := rGTG1.ZOKUGARA4;
                rGKBTGAKUREIBO_I.HOGOSYA_KOJIN_NO := rGTG1.HOGOSYA_KOJIN_NO;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA1 := rGTG1.HOGOSYA_ZOKUGARA1;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA2 := rGTG1.HOGOSYA_ZOKUGARA2;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA3 := rGTG1.HOGOSYA_ZOKUGARA3;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA4 := rGTG1.HOGOSYA_ZOKUGARA4;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := 0;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := 0;
                  rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := 0;
                  rGKBTGAKUREIBO_I.TYUGAKO_CD := rGTG1.TYUGAKO_CD;
                  rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := rGTG1.TYUGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := rGTG1.TYUGAKO_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := rGTG1.TYUGAKO_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := rGTG1.TYUGAKO_SOTSUGYO_BI;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_CD := rGTG1.SYOGAKO_CD;
                  rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := rGTG1.SYOGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := rGTG1.SYOGAKO_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := rGTG1.SYOGAKO_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := rGTG1.SYOGAKO_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := 0;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := 0;
                  rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := 0;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI1 := rGTG1.TOKUSOKU_BI1;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO1 := rGTG1.TOKUSOKU_NAIYO1;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU1 := rGTG1.TOKUSOKU_JIYU1;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI1 := rGTG1.TOKUSOKU_JURI_BI1;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI2 := rGTG1.TOKUSOKU_BI2;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO2 := rGTG1.TOKUSOKU_NAIYO2;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU2 := rGTG1.TOKUSOKU_JIYU2;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI2 := rGTG1.TOKUSOKU_JURI_BI2;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI3 := rGTG1.TOKUSOKU_BI3;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO3 := rGTG1.TOKUSOKU_NAIYO3;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU3 := rGTG1.TOKUSOKU_JIYU3;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI3 := rGTG1.TOKUSOKU_JURI_BI3;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI4 := rGTG1.TOKUSOKU_BI4;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO4 := rGTG1.TOKUSOKU_NAIYO4;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU4 := rGTG1.TOKUSOKU_JIYU4;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI4 := rGTG1.TOKUSOKU_JURI_BI4;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI5 := rGTG1.TOKUSOKU_BI5;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO5 := rGTG1.TOKUSOKU_NAIYO5;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU5 := rGTG1.TOKUSOKU_JIYU5;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI5 := rGTG1.TOKUSOKU_JURI_BI5;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI6 := rGTG1.TOKUSOKU_BI6;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO6 := rGTG1.TOKUSOKU_NAIYO6;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU6 := rGTG1.TOKUSOKU_JIYU6;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI6 := rGTG1.TOKUSOKU_JURI_BI6;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI7 := rGTG1.TOKUSOKU_BI7;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO7 := rGTG1.TOKUSOKU_NAIYO7;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU7 := rGTG1.TOKUSOKU_JIYU7;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI7 := rGTG1.TOKUSOKU_JURI_BI7;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI8 := rGTG1.TOKUSOKU_BI8;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO8 := rGTG1.TOKUSOKU_NAIYO8;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU8 := rGTG1.TOKUSOKU_JIYU8;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI8 := rGTG1.TOKUSOKU_JURI_BI8;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI9 := rGTG1.TOKUSOKU_BI9;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO9 := rGTG1.TOKUSOKU_NAIYO9;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU9 := rGTG1.TOKUSOKU_JIYU9;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI9 := rGTG1.TOKUSOKU_JURI_BI9;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI10 := rGTG1.TOKUSOKU_BI10;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO10 := rGTG1.TOKUSOKU_NAIYO10;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU10 := rGTG1.TOKUSOKU_JIYU10;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI10 := rGTG1.TOKUSOKU_JURI_BI10;
                rGKBTGAKUREIBO_I.KUIKIGAI_CD := rGTG1.KUIKIGAI_CD;
                rGKBTGAKUREIBO_I.KUIKIGAI_SETISYA := rGTG1.KUIKIGAI_SETISYA;
                rGKBTGAKUREIBO_I.KUIKIGAI_NYUGAKU_BI := rGTG1.KUIKIGAI_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_BI := rGTG1.KUIKIGAI_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_BI := rGTG1.KUIKIGAI_TENGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_BI := rGTG1.KUIKIGAI_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_SOTSUGYO_BI := rGTG1.KUIKIGAI_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_CD := rGTG1.YOGOGAKO_CD;
                rGKBTGAKUREIBO_I.YOGOGAKO_SETISYA := rGTG1.YOGOGAKO_SETISYA;
                rGKBTGAKUREIBO_I.YOGOGAKO_NYUGAKU_BI := rGTG1.YOGOGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_BI := rGTG1.YOGOGAKO_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_BI := rGTG1.YOGOGAKO_TENGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_BI := rGTG1.YOGOGAKO_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_SOTSUGYO_BI := rGTG1.YOGOGAKO_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.YUYO_KYOKA_BI := rGTG1.YUYO_KYOKA_BI;
                rGKBTGAKUREIBO_I.YUYO_JIYU_CD := rGTG1.YUYO_JIYU_CD;
                rGKBTGAKUREIBO_I.YUYO_JIYU := rGTG1.YUYO_JIYU;
                rGKBTGAKUREIBO_I.YUYO_KAISI_BI := rGTG1.YUYO_KAISI_BI;
                rGKBTGAKUREIBO_I.YUYO_SYURYO_BI := rGTG1.YUYO_SYURYO_BI;
                rGKBTGAKUREIBO_I.YUYO_NENSU := rGTG1.YUYO_NENSU;
                rGKBTGAKUREIBO_I.YUYO_FUKUGAKU_BI := rGTG1.YUYO_FUKUGAKU_BI;
                rGKBTGAKUREIBO_I.MENJO_KYOKA_BI := rGTG1.MENJO_KYOKA_BI;
                rGKBTGAKUREIBO_I.MENJO_JIYU_CD := rGTG1.MENJO_JIYU_CD;
                rGKBTGAKUREIBO_I.MENJO_JIYU := rGTG1.MENJO_JIYU;
                rGKBTGAKUREIBO_I.MENJO_KAISI_BI := rGTG1.MENJO_KAISI_BI;
                rGKBTGAKUREIBO_I.MENJO_SYURYO_BI := rGTG1.MENJO_SYURYO_BI;
                rGKBTGAKUREIBO_I.MENJO_NENSU := rGTG1.MENJO_NENSU;
                rGKBTGAKUREIBO_I.MENJO_FUKUGAKU_BI := rGTG1.MENJO_FUKUGAKU_BI;
                rGKBTGAKUREIBO_I.IDO_BI1 := rGTG1.IDO_BI1;
                rGKBTGAKUREIBO_I.IDO_JIYU1 := rGTG1.IDO_JIYU1;
                rGKBTGAKUREIBO_I.IDO_BI2 := rGTG1.IDO_BI2;
                rGKBTGAKUREIBO_I.IDO_JIYU2 := rGTG1.IDO_JIYU2;
                rGKBTGAKUREIBO_I.IDO_BI3 := rGTG1.IDO_BI3;
                rGKBTGAKUREIBO_I.IDO_JIYU3 := rGTG1.IDO_JIYU3;
                rGKBTGAKUREIBO_I.IDO_BI4 := rGTG1.IDO_BI4;
                rGKBTGAKUREIBO_I.IDO_JIYU4 := rGTG1.IDO_JIYU4;
                rGKBTGAKUREIBO_I.IDO_BI5 := rGTG1.IDO_BI5;
                rGKBTGAKUREIBO_I.IDO_JIYU5 := rGTG1.IDO_JIYU5;
                rGKBTGAKUREIBO_I.IDO_BI6 := rGTG1.IDO_BI6;
                rGKBTGAKUREIBO_I.IDO_JIYU6 := rGTG1.IDO_JIYU6;
                rGKBTGAKUREIBO_I.IDO_BI7 := rGTG1.IDO_BI7;
                rGKBTGAKUREIBO_I.IDO_JIYU7 := rGTG1.IDO_JIYU7;
                rGKBTGAKUREIBO_I.IDO_BI8 := rGTG1.IDO_BI8;
                rGKBTGAKUREIBO_I.IDO_JIYU8 := rGTG1.IDO_JIYU8;
                rGKBTGAKUREIBO_I.IDO_BI9 := rGTG1.IDO_BI9;
                rGKBTGAKUREIBO_I.IDO_JIYU9 := rGTG1.IDO_JIYU9;
                rGKBTGAKUREIBO_I.IDO_BI10 := rGTG1.IDO_BI10;
                rGKBTGAKUREIBO_I.IDO_JIYU10 := rGTG1.IDO_JIYU10;
                rGKBTGAKUREIBO_I.SYS_SAKUSEIBI := rGTG1.SYS_SAKUSEIBI;
                rGKBTGAKUREIBO_I.SYS_KOSHINBI := g_nDATE;
                rGKBTGAKUREIBO_I.SYS_JIKAN := g_nTIME;
                rGKBTGAKUREIBO_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                rGKBTGAKUREIBO_I.SYS_TANMATU_NO := g_sWSNUM;
                rGKBTGAKUREIBO_I.GAKUNEN := rGTG1.GAKUNEN;
                rGKBTGAKUREIBO_I.SHORIBI := g_nDATE;
                rGKBTGAKUREIBO_I.SHUGAKU := rGTG1.SHUGAKU;
                rGKBTGAKUREIBO_I.IDOJIKO := rGTG1.IDOJIKO;
                rGKBTGAKUREIBO_I.CHOHYO_NO := rGTG1.CHOHYO_NO;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := 0;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rGTG1.TYUGAKO_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rGTG1.TYUGAKO_TENGAKU_GAKUNEN;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.SYOGAKO_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rGTG1.SYOGAKO_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := 0;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_GAKUNEN := rGTG1.KUIKIGAI_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_GAKUNEN := rGTG1.YOGOGAKO_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.GAKKO_KBN_CD := rGTG1.GAKKO_KBN_CD;
                rGKBTGAKUREIBO_I.GAKUKYU_CD := 0;
                rGKBTGAKUREIBO_I.SEIBETSU := rGTG1.SEIBETSU;
                rGKBTGAKUREIBO_I.JOTAI := rGTG1.JOTAI;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_KBN := rGTG1.TENNYUMAE_GAKKO_KBN;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_CD := rGTG1.TENNYUMAE_GAKKO_CD;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKUNEN := rGTG1.TENNYUMAE_GAKUNEN;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_FLG := rGTG1.GENKYURYUCHI_FLG;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_KETTEI_BI := rGTG1.GENKYURYUCHI_KETTEI_BI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_KAISI_BI := rGTG1.GENKYURYUCHI_KAISI_BI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_SYURYOBI := rGTG1.GENKYURYUCHI_SYURYOBI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_RIYU := rGTG1.GENKYURYUCHI_RIYU;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rGTG1.SHITEI_TYUGAKO_CD;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rGTG1.SHITEI_SYOGAKO_CD;
                  rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.HENKO_GAKUNEN_SYOGAKO := rGTG1.HENKO_GAKUNEN_SYOGAKO;
                rGKBTGAKUREIBO_I.HENKO_GAKUNEN_TYUGAKO := rGTG1.HENKO_GAKUNEN_TYUGAKO;
                rGKBTGAKUREIBO_I.HENKO_SHINSEI_BI := rGTG1.HENKO_SHINSEI_BI;
                rGKBTGAKUREIBO_I.HENKO_KYOKA_BI := rGTG1.HENKO_KYOKA_BI;
                rGKBTGAKUREIBO_I.HENKO_KBN := rGTG1.HENKO_KBN;
                rGKBTGAKUREIBO_I.HENKO_KAISI_BI := rGTG1.HENKO_KAISI_BI;
                rGKBTGAKUREIBO_I.HENKO_SYURYO_BI := rGTG1.HENKO_SYURYO_BI;
                rGKBTGAKUREIBO_I.HENKO_KYOKA_RIYU := rGTG1.HENKO_KYOKA_RIYU;
                rGKBTGAKUREIBO_I.HENKO_JIYU := rGTG1.HENKO_JIYU;
                rGKBTGAKUREIBO_I.HENKO_HUKYOKA_RIYU := rGTG1.HENKO_HUKYOKA_RIYU;
                rGKBTGAKUREIBO_I.KIBO_GAKKO_KBN_CD := rGTG1.KIBO_GAKKO_KBN_CD;
                rGKBTGAKUREIBO_I.KIBO_SYOGAKKO_CD := rGTG1.KIBO_SYOGAKKO_CD;
                rGKBTGAKUREIBO_I.KIBO_TYUGAKKO_CD := rGTG1.KIBO_TYUGAKKO_CD;
                rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_SYOGAKO := rGTG1.KIBO_UKETSUKE_BI_SYOGAKO;
                rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_TYUGAKO := rGTG1.KIBO_UKETSUKE_BI_TYUGAKO;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_FLG := rGTG1.KUIKIGAISHUGAKU_FLG;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SHINSEI_BI := rGTG1.KUIKIGAISHUGAKU_SHINSEI_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_BI := rGTG1.KUIKIGAISHUGAKU_KYOKA_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KAISI_BI := rGTG1.KUIKIGAISHUGAKU_KAISI_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SYURYO_BI := rGTG1.KUIKIGAISHUGAKU_SYURYO_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_JIYU := rGTG1.KUIKIGAISHUGAKU_JIYU;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_KYOKA_RIYU;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_HUKYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_HUKYOKA_RIYU;
                rGKBTGAKUREIBO_I.HUSHUGAKU_KAISI_BI := rGTG1.HUSHUGAKU_KAISI_BI;
                rGKBTGAKUREIBO_I.HUSHUGAKU_SYURYO_BI := rGTG1.HUSHUGAKU_SYURYO_BI;
                rGKBTGAKUREIBO_I.HUSHUGAKU_RIYU := rGTG1.HUSHUGAKU_RIYU;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_CD := rGTG1.KUNISHIRITSU_CD;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_NYUGAKU_BI := rGTG1.KUNISHIRITSU_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_BI := rGTG1.KUNISHIRITSU_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_BI := rGTG1.KUNISHIRITSU_TENGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_BI := rGTG1.KUNISHIRITSU_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_SOTSUGYO_BI := rGTG1.KUNISHIRITSU_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_KAISI_BI := rGTG1.KUNISHIRITSU_KAISI_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_SYURYO_BI := rGTG1.KUNISHIRITSU_SYURYO_BI;
                rGKBTGAKUREIBO_I.TSUSHOMEI_KANA := rGTG1.TSUSHOMEI_KANA;
                rGKBTGAKUREIBO_I.TSUSHOMEI_KANJI := rGTG1.TSUSHOMEI_KANJI;
                rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANA := rGTG1.HOGOSHA_TSUSHOMEI_KANA;
                rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANJI := rGTG1.HOGOSHA_TSUSHOMEI_KANJI;
                rGKBTGAKUREIBO_I.GRB_HENKO_TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                rGKBTGAKUREIBO_I.GRB_HENKO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                nRTN := KKAPK0030.FCTGetR('GKB', '00TOHAIGO_HENKOJIYU', '0000', 0, aPRM);
                IF aPRM(1) = '1' THEN
                  rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 14;
                ELSIF aPRM(1) = '2' THEN
                  rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 99;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.BIKO := REPLACE(rGTG1.BIKO, chr(13)||chr(10),'#') || '新設・統廃合一括処理による転入学';
                rGKBTGAKUREIBO_I.IDO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                rGKBTGAKUREIBO_I.TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                rGKBTGAKUREIBO_I.SHINSEI_KANRI_RENBAN := rGTG1.SHINSEI_KANRI_RENBAN;
                rGKBTGAKUREIBO_I.IDOJI_ATENA_RIREKI_RENBAN := rGTG1.IDOJI_ATENA_RIREKI_RENBAN;
                rGKBTGAKUREIBO_I.HOGOSYA_IDOJI_RIREKI_RENBAN := rGTG1.HOGOSYA_IDOJI_RIREKI_RENBAN;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rDATA.NEW_GAKKOKU_CD;
                  rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rGTG1.CHUGAKKOKU_CD;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rGTG1.SHOGAKKOKU_CD;
                  rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rDATA.NEW_GAKKOKU_CD;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.SAKUJO_FLG := 0;
                BEGIN
                  SELECT
                    BUKACODE
                  INTO sBUKACODE
                  FROM
                    KKNTWS
                  WHERE
                    KKNTWS.WSNUM = g_sWSNUM;
                EXCEPTION
                  WHEN OTHERS THEN
                    sBUKACODE := NULL;
                END;
                BEGIN
                  SELECT
                    BUKANAME
                  INTO rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO
                  FROM
                    KKNTBK
                  WHERE
                    BUKACODE = sBUKACODE
                    AND KKNTBK.YUKOKIKANFR = (
                                               SELECT MAX(YUKOKIKANFR) FROM KKNTBK WHERE BUKACODE = sBUKACODE
                                              );
                EXCEPTION
                  WHEN OTHERS THEN
                    rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO := NULL;
                END;
                INSERT INTO GKBTGAKUREIBO VALUES rGKBTGAKUREIBO_I;
                --就学履歴に転入学の履歴を作成する。 ※転入学時
                rGKBTSHUGAKURIREKI_I.KOJIN_NO := rDATA.KOJIN_NO;
                rGKBTSHUGAKURIREKI_I.NENDO := TO_NUMBER(SUBSTR(KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD), 1, 4));
                rGKBTSHUGAKURIREKI_I.KOJIN_RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                nGKBTSHUGAKURIREKISEQ := nGKBTSHUGAKURIREKISEQ + 10;
                rGKBTSHUGAKURIREKI_I.SHUGAKU_RIREKI_RENBAN := nGKBTSHUGAKURIREKISEQ;
                rGKBTSHUGAKURIREKI_I.SAISHIN_FLG := 0;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTSHUGAKURIREKI_I.S_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTSHUGAKURIREKI_I.S_NYUGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.S_TENNYU_BI := KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD);
                  rGKBTSHUGAKURIREKI_I.S_TENNYU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := 0;
                  rGKBTSHUGAKURIREKI_I.S_TAIGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.S_TAIGAKU_GAKUNEN := 0;
                  rGKBTSHUGAKURIREKI_I.S_SOTSUGYO_BI := 0;
                  rGKBTSHUGAKURIREKI_I.T_CD := rGTR1.T_CD;
                  rGKBTSHUGAKURIREKI_I.T_NYUGAKU_BI := rGTR1.T_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TENNYU_BI := rGTR1.T_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TENNYU_GAKUNEN := rGTR1.T_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := rGTR1.T_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := rGTR1.T_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.T_TAIGAKU_BI := rGTR1.T_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TAIGAKU_GAKUNEN := rGTR1.T_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.T_SOTSUGYO_BI := rGTR1.T_SOTSUGYO_BI;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTSHUGAKURIREKI_I.S_CD := rGTR1.S_CD;
                  rGKBTSHUGAKURIREKI_I.S_NYUGAKU_BI := rGTR1.S_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TENNYU_BI := rGTR1.S_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TENNYU_GAKUNEN := rGTR1.S_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := rGTR1.S_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := rGTR1.S_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.S_TAIGAKU_BI := rGTR1.S_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TAIGAKU_GAKUNEN := rGTR1.S_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.S_SOTSUGYO_BI := rGTR1.S_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.T_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTSHUGAKURIREKI_I.T_NYUGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.T_TENNYU_BI := KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD);
                  rGKBTSHUGAKURIREKI_I.T_TENNYU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := 0;
                  rGKBTSHUGAKURIREKI_I.T_TAIGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.T_TAIGAKU_GAKUNEN := 0;
                  rGKBTSHUGAKURIREKI_I.T_SOTSUGYO_BI := 0;
                ELSE
                  NULL;
                END IF;
                rGKBTSHUGAKURIREKI_I.SHIEN_BU_CD := rGTR1.SHIEN_BU_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_CD := rGTR1.SHIEN_S_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_HUKUSEKI_CD := rGTR1.SHIEN_S_HUKUSEKI_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_NYUGAKU_BI := rGTR1.SHIEN_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_BI := rGTR1.SHIEN_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_GAKUNEN := rGTR1.SHIEN_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_BI := rGTR1.SHIEN_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_GAKUNEN := rGTR1.SHIEN_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_BI := rGTR1.SHIEN_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_GAKUNEN := rGTR1.SHIEN_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_SOTSUGYO_BI := rGTR1.SHIEN_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_CD := rGTR1.SHIEN_T_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_HUKUSEKI_CD := rGTR1.SHIEN_T_HUKUSEKI_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_NYUGAKU_BI := rGTR1.SHIEN_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_BI := rGTR1.SHIEN_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_GAKUNEN := rGTR1.SHIEN_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_BI := rGTR1.SHIEN_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_GAKUNEN := rGTR1.SHIEN_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_BI := rGTR1.SHIEN_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_GAKUNEN := rGTR1.SHIEN_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_SOTSUGYO_BI := rGTR1.SHIEN_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_CD := rGTR1.KUIKIGAI_S_CD;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_S_KAISHI_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_NYUGAKU_BI := rGTR1.KUIKIGAI_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_BI := rGTR1.KUIKIGAI_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_BI := rGTR1.KUIKIGAI_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_BI := rGTR1.KUIKIGAI_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SOTSUGYO_BI := rGTR1.KUIKIGAI_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_BI := rGTR1.KUIKIGAI_S_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SHURYO_BI := rGTR1.KUIKIGAI_S_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAIJO_BI := rGTR1.KUIKIGAI_S_KAIJO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_CD := rGTR1.KUIKIGAI_T_CD;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_T_KAISHI_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_NYUGAKU_BI := rGTR1.KUIKIGAI_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_BI := rGTR1.KUIKIGAI_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_BI := rGTR1.KUIKIGAI_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_BI := rGTR1.KUIKIGAI_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SOTSUGYO_BI := rGTR1.KUIKIGAI_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_BI := rGTR1.KUIKIGAI_T_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SHURYO_BI := rGTR1.KUIKIGAI_T_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAIJO_BI := rGTR1.KUIKIGAI_T_KAIJO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_CD := rGTR1.KUNISHIRITSU_S_CD;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_NYUGAKU_BI := rGTR1.KUNISHIRITSU_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_BI := rGTR1.KUNISHIRITSU_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_BI := rGTR1.KUNISHIRITSU_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_BI := rGTR1.KUNISHIRITSU_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_KAISHI_BI := rGTR1.KUNISHIRITSU_S_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SHURYO_BI := rGTR1.KUNISHIRITSU_S_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_CD := rGTR1.KUNISHIRITSU_T_CD;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_NYUGAKU_BI := rGTR1.KUNISHIRITSU_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_BI := rGTR1.KUNISHIRITSU_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_BI := rGTR1.KUNISHIRITSU_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_BI := rGTR1.KUNISHIRITSU_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_KAISHI_BI := rGTR1.KUNISHIRITSU_T_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SHURYO_BI := rGTR1.KUNISHIRITSU_T_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.SAKUJO_FLG := rGTR1.SAKUJO_FLG;
                rGKBTSHUGAKURIREKI_I.SYS_SAKUSEIBI := g_nDATE;
                rGKBTSHUGAKURIREKI_I.SYS_KOSHINBI := 0;
                rGKBTSHUGAKURIREKI_I.SYS_JIKAN := g_nTIME;
                rGKBTSHUGAKURIREKI_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                rGKBTSHUGAKURIREKI_I.SYS_TANMATU_NO := g_sWSNUM;
                INSERT INTO GKBTSHUGAKURIREKI VALUES rGKBTSHUGAKURIREKI_I;
                IF g_NENTXYUFLG = 1 THEN
                  --学年履歴の現最新履歴の最新フラグを変更する。
                  UPDATE GKBTGAKUNENRIREKI
                  SET SAISIN_FLG = 1,
                      SYS_KOSHINBI = g_nDATE,
                      SYS_JIKAN = g_nTIME,
                      SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                      SYS_TANMATU_NO = g_sWSNUM
                  WHERE KOJIN_NO = rDATA.KOJIN_NO
                    AND SAISIN_FLG = 0;
                  --学年履歴に転入先の学校の学年履歴を作成する。
                  rGKBTGAKUNENRIREKI_I.KOJIN_NO := rDATA.KOJIN_NO;
                  rGKBTGAKUNENRIREKI_I.NENDO := TO_NUMBER(SUBSTR(KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD), 1, 4));
                  rGKBTGAKUNENRIREKI_I.KOJIN_RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                  rGKBTGAKUNENRIREKI_I.GAKUNEN_RIREKI_RENBAN := nGKBTGAKUNENRIREKISEQ;
                  rGKBTGAKUNENRIREKI_I.GAKKO_KBN_CD := rDATA.NEW_SHUGAKUSHITEIKOU_KBN;
                  rGKBTGAKUNENRIREKI_I.GAKKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTGAKUNENRIREKI_I.SAISIN_FLG := 0;
                  rGKBTGAKUNENRIREKI_I.GAKUKYU_KBN := 0;
                  rGKBTGAKUNENRIREKI_I.GAKUKYU_CD := 0;
                  rGKBTGAKUNENRIREKI_I.GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUNENRIREKI_I.SAKUJO_FLG := 0;
                  rGKBTGAKUNENRIREKI_I.SYS_SAKUSEIBI := g_nDATE;
                  rGKBTGAKUNENRIREKI_I.SYS_KOSHINBI := 0;
                  rGKBTGAKUNENRIREKI_I.SYS_JIKAN := g_nTIME;
                  rGKBTGAKUNENRIREKI_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                  rGKBTGAKUNENRIREKI_I.SYS_TANMATU_NO := g_sWSNUM;
                  INSERT INTO GKBTGAKUNENRIREKI VALUES rGKBTGAKUNENRIREKI_I;
                END IF;
              ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                IF rDATA.NEW_SHUGAKUSHITEIKOU_KBN = 1 THEN
                  --学齢簿、就学履歴の現最新履歴の最新区分を変更する。
                  UPDATE GKBTGAKUREIBO
                  SET SAISHIN_KBN = 1,        --最新区分固定値「1」
                      SYS_KOSHINBI = g_nDATE, --更新日
                      SYS_JIKAN = g_nTIME,    --システム時間
                      SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                      SYS_TANMATU_NO = g_sWSNUM
                  WHERE KOJIN_NO = rDATA.KOJIN_NO
                    AND SAISHIN_KBN = 0;
                  UPDATE GKBTSHUGAKURIREKI
                  SET SAISHIN_FLG = 1,        --最新フラグ固定値「1」
                      SYS_KOSHINBI = g_nDATE, --更新日
                      SYS_JIKAN = g_nTIME,    --システム時間
                      SYS_SHOKUINKOJIN_NO = g_sTANTOCODE, --更新職員宛名番号
                      SYS_TANMATU_NO = g_sWSNUM --更新端末番号
                  WHERE KOJIN_NO = rDATA.KOJIN_NO
                    AND SAISHIN_FLG = 0;
                  --学齢簿に転学の履歴を作成する。 ※新入学児童以外の場合の転学時
                  rGKBTGAKUREIBO_I.KOJIN_NO := rDATA.KOJIN_NO;
                  nGKBTGAKUREIBOSEQ := nGKBTGAKUREIBOSEQ + 10;
                  rGKBTGAKUREIBO_I.RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                  rGKBTGAKUREIBO_I.RIREKI_RENBAN_EDA := 0;
                  rGKBTGAKUREIBO_I.GENZON_KBN := rGTG1.GENZON_KBN;
                  rGKBTGAKUREIBO_I.SAISHIN_KBN := 1;
                  rGKBTGAKUREIBO_I.ZO_JIYU_CD := rGTG1.ZO_JIYU_CD;
                  rGKBTGAKUREIBO_I.ZO_NENGAPI := rGTG1.ZO_NENGAPI;
                  rGKBTGAKUREIBO_I.GEN_JIYU_CD := rGTG1.GEN_JIYU_CD;
                  rGKBTGAKUREIBO_I.GEN_NENGAPI := rGTG1.GEN_NENGAPI;
                  rGKBTGAKUREIBO_I.ZOKUGARA1 := rGTG1.ZOKUGARA1;
                  rGKBTGAKUREIBO_I.ZOKUGARA2 := rGTG1.ZOKUGARA2;
                  rGKBTGAKUREIBO_I.ZOKUGARA3 := rGTG1.ZOKUGARA3;
                  rGKBTGAKUREIBO_I.ZOKUGARA4 := rGTG1.ZOKUGARA4;
                  rGKBTGAKUREIBO_I.HOGOSYA_KOJIN_NO := rGTG1.HOGOSYA_KOJIN_NO;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA1 := rGTG1.HOGOSYA_ZOKUGARA1;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA2 := rGTG1.HOGOSYA_ZOKUGARA2;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA3 := rGTG1.HOGOSYA_ZOKUGARA3;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA4 := rGTG1.HOGOSYA_ZOKUGARA4;
                  rGKBTGAKUREIBO_I.SYOGAKO_CD := rGTG1.SYOGAKO_CD;
                  rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := rGTG1.SYOGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := rGTG1.SYOGAKO_TENNYUGAKU_BI;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := rGTG1.SYOGAKO_TENGAKU_BI;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := rGTG1.SYOGAKO_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_CD := rGTG1.TYUGAKO_CD;
                  rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := rGTG1.TYUGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := rGTG1.TYUGAKO_TENNYUGAKU_BI;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := rGTG1.TYUGAKO_TENGAKU_BI;
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := rGTG1.TYUGAKO_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI1 := rGTG1.TOKUSOKU_BI1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO1 := rGTG1.TOKUSOKU_NAIYO1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU1 := rGTG1.TOKUSOKU_JIYU1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI1 := rGTG1.TOKUSOKU_JURI_BI1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI2 := rGTG1.TOKUSOKU_BI2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO2 := rGTG1.TOKUSOKU_NAIYO2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU2 := rGTG1.TOKUSOKU_JIYU2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI2 := rGTG1.TOKUSOKU_JURI_BI2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI3 := rGTG1.TOKUSOKU_BI3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO3 := rGTG1.TOKUSOKU_NAIYO3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU3 := rGTG1.TOKUSOKU_JIYU3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI3 := rGTG1.TOKUSOKU_JURI_BI3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI4 := rGTG1.TOKUSOKU_BI4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO4 := rGTG1.TOKUSOKU_NAIYO4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU4 := rGTG1.TOKUSOKU_JIYU4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI4 := rGTG1.TOKUSOKU_JURI_BI4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI5 := rGTG1.TOKUSOKU_BI5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO5 := rGTG1.TOKUSOKU_NAIYO5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU5 := rGTG1.TOKUSOKU_JIYU5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI5 := rGTG1.TOKUSOKU_JURI_BI5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI6 := rGTG1.TOKUSOKU_BI6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO6 := rGTG1.TOKUSOKU_NAIYO6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU6 := rGTG1.TOKUSOKU_JIYU6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI6 := rGTG1.TOKUSOKU_JURI_BI6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI7 := rGTG1.TOKUSOKU_BI7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO7 := rGTG1.TOKUSOKU_NAIYO7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU7 := rGTG1.TOKUSOKU_JIYU7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI7 := rGTG1.TOKUSOKU_JURI_BI7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI8 := rGTG1.TOKUSOKU_BI8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO8 := rGTG1.TOKUSOKU_NAIYO8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU8 := rGTG1.TOKUSOKU_JIYU8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI8 := rGTG1.TOKUSOKU_JURI_BI8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI9 := rGTG1.TOKUSOKU_BI9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO9 := rGTG1.TOKUSOKU_NAIYO9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU9 := rGTG1.TOKUSOKU_JIYU9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI9 := rGTG1.TOKUSOKU_JURI_BI9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI10 := rGTG1.TOKUSOKU_BI10;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO10 := rGTG1.TOKUSOKU_NAIYO10;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU10 := rGTG1.TOKUSOKU_JIYU10;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI10 := rGTG1.TOKUSOKU_JURI_BI10;
                  rGKBTGAKUREIBO_I.KUIKIGAI_CD := rGTG1.KUIKIGAI_CD;
                  rGKBTGAKUREIBO_I.KUIKIGAI_SETISYA := rGTG1.KUIKIGAI_SETISYA;
                  rGKBTGAKUREIBO_I.KUIKIGAI_NYUGAKU_BI := rGTG1.KUIKIGAI_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_BI := rGTG1.KUIKIGAI_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_BI := rGTG1.KUIKIGAI_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_BI := rGTG1.KUIKIGAI_TAIGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_SOTSUGYO_BI := rGTG1.KUIKIGAI_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_CD := rGTG1.YOGOGAKO_CD;
                  rGKBTGAKUREIBO_I.YOGOGAKO_SETISYA := rGTG1.YOGOGAKO_SETISYA;
                  rGKBTGAKUREIBO_I.YOGOGAKO_NYUGAKU_BI := rGTG1.YOGOGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_BI := rGTG1.YOGOGAKO_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_BI := rGTG1.YOGOGAKO_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_BI := rGTG1.YOGOGAKO_TAIGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_SOTSUGYO_BI := rGTG1.YOGOGAKO_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.YUYO_KYOKA_BI := rGTG1.YUYO_KYOKA_BI;
                  rGKBTGAKUREIBO_I.YUYO_JIYU_CD := rGTG1.YUYO_JIYU_CD;
                  rGKBTGAKUREIBO_I.YUYO_JIYU := rGTG1.YUYO_JIYU;
                  rGKBTGAKUREIBO_I.YUYO_KAISI_BI := rGTG1.YUYO_KAISI_BI;
                  rGKBTGAKUREIBO_I.YUYO_SYURYO_BI := rGTG1.YUYO_SYURYO_BI;
                  rGKBTGAKUREIBO_I.YUYO_NENSU := rGTG1.YUYO_NENSU;
                  rGKBTGAKUREIBO_I.YUYO_FUKUGAKU_BI := rGTG1.YUYO_FUKUGAKU_BI;
                  rGKBTGAKUREIBO_I.MENJO_KYOKA_BI := rGTG1.MENJO_KYOKA_BI;
                  rGKBTGAKUREIBO_I.MENJO_JIYU_CD := rGTG1.MENJO_JIYU_CD;
                  rGKBTGAKUREIBO_I.MENJO_JIYU := rGTG1.MENJO_JIYU;
                  rGKBTGAKUREIBO_I.MENJO_KAISI_BI := rGTG1.MENJO_KAISI_BI;
                  rGKBTGAKUREIBO_I.MENJO_SYURYO_BI := rGTG1.MENJO_SYURYO_BI;
                  rGKBTGAKUREIBO_I.MENJO_NENSU := rGTG1.MENJO_NENSU;
                  rGKBTGAKUREIBO_I.MENJO_FUKUGAKU_BI := rGTG1.MENJO_FUKUGAKU_BI;
                  rGKBTGAKUREIBO_I.IDO_BI1 := rGTG1.IDO_BI1;
                  rGKBTGAKUREIBO_I.IDO_JIYU1 := rGTG1.IDO_JIYU1;
                  rGKBTGAKUREIBO_I.IDO_BI2 := rGTG1.IDO_BI2;
                  rGKBTGAKUREIBO_I.IDO_JIYU2 := rGTG1.IDO_JIYU2;
                  rGKBTGAKUREIBO_I.IDO_BI3 := rGTG1.IDO_BI3;
                  rGKBTGAKUREIBO_I.IDO_JIYU3 := rGTG1.IDO_JIYU3;
                  rGKBTGAKUREIBO_I.IDO_BI4 := rGTG1.IDO_BI4;
                  rGKBTGAKUREIBO_I.IDO_JIYU4 := rGTG1.IDO_JIYU4;
                  rGKBTGAKUREIBO_I.IDO_BI5 := rGTG1.IDO_BI5;
                  rGKBTGAKUREIBO_I.IDO_JIYU5 := rGTG1.IDO_JIYU5;
                  rGKBTGAKUREIBO_I.IDO_BI6 := rGTG1.IDO_BI6;
                  rGKBTGAKUREIBO_I.IDO_JIYU6 := rGTG1.IDO_JIYU6;
                  rGKBTGAKUREIBO_I.IDO_BI7 := rGTG1.IDO_BI7;
                  rGKBTGAKUREIBO_I.IDO_JIYU7 := rGTG1.IDO_JIYU7;
                  rGKBTGAKUREIBO_I.IDO_BI8 := rGTG1.IDO_BI8;
                  rGKBTGAKUREIBO_I.IDO_JIYU8 := rGTG1.IDO_JIYU8;
                  rGKBTGAKUREIBO_I.IDO_BI9 := rGTG1.IDO_BI9;
                  rGKBTGAKUREIBO_I.IDO_JIYU9 := rGTG1.IDO_JIYU9;
                  rGKBTGAKUREIBO_I.IDO_BI10 := rGTG1.IDO_BI10;
                  rGKBTGAKUREIBO_I.IDO_JIYU10 := rGTG1.IDO_JIYU10;
                  rGKBTGAKUREIBO_I.SYS_SAKUSEIBI := rGTG1.SYS_SAKUSEIBI;
                  rGKBTGAKUREIBO_I.SYS_KOSHINBI := g_nDATE;
                  rGKBTGAKUREIBO_I.SYS_JIKAN := g_nTIME;
                  rGKBTGAKUREIBO_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                  rGKBTGAKUREIBO_I.SYS_TANMATU_NO := g_sWSNUM;
                  rGKBTGAKUREIBO_I.GAKUNEN := rGTG1.GAKUNEN;
                  rGKBTGAKUREIBO_I.SHORIBI := g_nDATE;
                  rGKBTGAKUREIBO_I.SHUGAKU := rGTG1.SHUGAKU;
                  rGKBTGAKUREIBO_I.IDOJIKO := rGTG1.IDOJIKO;
                  rGKBTGAKUREIBO_I.CHOHYO_NO := rGTG1.CHOHYO_NO;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.SYOGAKO_TENNYUGAKU_GAKUNEN;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rGTG1.SYOGAKO_TENGAKU_GAKUNEN;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rGTG1.TYUGAKO_TENNYUGAKU_GAKUNEN;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rGTG1.TYUGAKO_TENGAKU_GAKUNEN;
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_GAKUNEN := rGTG1.KUIKIGAI_TAIGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_GAKUNEN := rGTG1.YOGOGAKO_TAIGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.GAKKO_KBN_CD := rGTG1.GAKKO_KBN_CD;
                  rGKBTGAKUREIBO_I.GAKUKYU_CD := rGTG1.GAKUKYU_CD;
                  rGKBTGAKUREIBO_I.SEIBETSU := rGTG1.SEIBETSU;
                  rGKBTGAKUREIBO_I.JOTAI := rGTG1.JOTAI;
                  rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_KBN := rGTG1.TENNYUMAE_GAKKO_KBN;
                  rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_CD := rGTG1.TENNYUMAE_GAKKO_CD;
                  rGKBTGAKUREIBO_I.TENNYUMAE_GAKUNEN := rGTG1.TENNYUMAE_GAKUNEN;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_FLG := rGTG1.GENKYURYUCHI_FLG;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_KETTEI_BI := rGTG1.GENKYURYUCHI_KETTEI_BI;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_KAISI_BI := rGTG1.GENKYURYUCHI_KAISI_BI;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_SYURYOBI := rGTG1.GENKYURYUCHI_SYURYOBI;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_RIYU := rGTG1.GENKYURYUCHI_RIYU;
                  rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rGTG1.SHITEI_SYOGAKO_CD;
                  rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rGTG1.SHITEI_TYUGAKO_CD;
                  rGKBTGAKUREIBO_I.HENKO_GAKUNEN_SYOGAKO := rGTG1.HENKO_GAKUNEN_SYOGAKO;
                  rGKBTGAKUREIBO_I.HENKO_GAKUNEN_TYUGAKO := rGTG1.HENKO_GAKUNEN_TYUGAKO;
                  rGKBTGAKUREIBO_I.HENKO_SHINSEI_BI := rGTG1.HENKO_SHINSEI_BI;
                  rGKBTGAKUREIBO_I.HENKO_KYOKA_BI := rGTG1.HENKO_KYOKA_BI;
                  rGKBTGAKUREIBO_I.HENKO_KBN := rGTG1.HENKO_KBN;
                  rGKBTGAKUREIBO_I.HENKO_KAISI_BI := rGTG1.HENKO_KAISI_BI;
                  rGKBTGAKUREIBO_I.HENKO_SYURYO_BI := rGTG1.HENKO_SYURYO_BI;
                  rGKBTGAKUREIBO_I.HENKO_KYOKA_RIYU := rGTG1.HENKO_KYOKA_RIYU;
                  rGKBTGAKUREIBO_I.HENKO_JIYU := rGTG1.HENKO_JIYU;
                  rGKBTGAKUREIBO_I.HENKO_HUKYOKA_RIYU := rGTG1.HENKO_HUKYOKA_RIYU;
                  rGKBTGAKUREIBO_I.KIBO_GAKKO_KBN_CD := rGTG1.KIBO_GAKKO_KBN_CD;
                  rGKBTGAKUREIBO_I.KIBO_SYOGAKKO_CD := rGTG1.KIBO_SYOGAKKO_CD;
                  rGKBTGAKUREIBO_I.KIBO_TYUGAKKO_CD := rGTG1.KIBO_TYUGAKKO_CD;
                  rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_SYOGAKO := rGTG1.KIBO_UKETSUKE_BI_SYOGAKO;
                  rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_TYUGAKO := rGTG1.KIBO_UKETSUKE_BI_TYUGAKO;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_FLG := rGTG1.KUIKIGAISHUGAKU_FLG;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SHINSEI_BI := rGTG1.KUIKIGAISHUGAKU_SHINSEI_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_BI := rGTG1.KUIKIGAISHUGAKU_KYOKA_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KAISI_BI := rGTG1.KUIKIGAISHUGAKU_KAISI_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SYURYO_BI := rGTG1.KUIKIGAISHUGAKU_SYURYO_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_JIYU := rGTG1.KUIKIGAISHUGAKU_JIYU;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_KYOKA_RIYU;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_HUKYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_HUKYOKA_RIYU;
                  rGKBTGAKUREIBO_I.HUSHUGAKU_KAISI_BI := rGTG1.HUSHUGAKU_KAISI_BI;
                  rGKBTGAKUREIBO_I.HUSHUGAKU_SYURYO_BI := rGTG1.HUSHUGAKU_SYURYO_BI;
                  rGKBTGAKUREIBO_I.HUSHUGAKU_RIYU := rGTG1.HUSHUGAKU_RIYU;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_CD := rGTG1.KUNISHIRITSU_CD;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_NYUGAKU_BI := rGTG1.KUNISHIRITSU_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_BI := rGTG1.KUNISHIRITSU_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_BI := rGTG1.KUNISHIRITSU_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_BI := rGTG1.KUNISHIRITSU_TAIGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TAIGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_SOTSUGYO_BI := rGTG1.KUNISHIRITSU_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_KAISI_BI := rGTG1.KUNISHIRITSU_KAISI_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_SYURYO_BI := rGTG1.KUNISHIRITSU_SYURYO_BI;
                  rGKBTGAKUREIBO_I.TSUSHOMEI_KANA := rGTG1.TSUSHOMEI_KANA;
                  rGKBTGAKUREIBO_I.TSUSHOMEI_KANJI := rGTG1.TSUSHOMEI_KANJI;
                  rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANA := rGTG1.HOGOSHA_TSUSHOMEI_KANA;
                  rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANJI := rGTG1.HOGOSHA_TSUSHOMEI_KANJI;
                  rGKBTGAKUREIBO_I.GRB_HENKO_TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                  rGKBTGAKUREIBO_I.GRB_HENKO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                  nRTN := KKAPK0030.FCTGetR('GKB', '00TOHAIGO_HENKOJIYU', '0000', 0, aPRM);
                  IF aPRM(1) = '1' THEN
                    rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 14;
                  ELSIF aPRM(1) = '2' THEN
                    rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 99;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.BIKO := REPLACE(rGTG1.BIKO, chr(13)||chr(10),'#') || '新設・統廃合一括処理による転学';
                  rGKBTGAKUREIBO_I.IDO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                  rGKBTGAKUREIBO_I.TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                  rGKBTGAKUREIBO_I.SHINSEI_KANRI_RENBAN := rGTG1.SHINSEI_KANRI_RENBAN;
                  rGKBTGAKUREIBO_I.IDOJI_ATENA_RIREKI_RENBAN := rGTG1.IDOJI_ATENA_RIREKI_RENBAN;
                  rGKBTGAKUREIBO_I.HOGOSYA_IDOJI_RIREKI_RENBAN := rGTG1.HOGOSYA_IDOJI_RIREKI_RENBAN;
                  rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rGTG1.SHOGAKKOKU_CD;
                  rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rGTG1.CHUGAKKOKU_CD;
                  rGKBTGAKUREIBO_I.SAKUJO_FLG := 0;
                  BEGIN
                    SELECT
                      BUKACODE
                    INTO sBUKACODE
                    FROM
                      KKNTWS
                    WHERE
                      KKNTWS.WSNUM = g_sWSNUM;
                  EXCEPTION
                    WHEN OTHERS THEN
                      sBUKACODE := NULL;
                  END;
                  BEGIN
                    SELECT
                      BUKANAME
                    INTO rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO
                    FROM
                      KKNTBK
                    WHERE
                      BUKACODE = sBUKACODE
                      AND KKNTBK.YUKOKIKANFR = (
                                                 SELECT MAX(YUKOKIKANFR) FROM KKNTBK WHERE BUKACODE = sBUKACODE
                                                );
                  EXCEPTION
                    WHEN OTHERS THEN
                      rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO := NULL;
                  END;
                  INSERT INTO GKBTGAKUREIBO VALUES rGKBTGAKUREIBO_I;
                  --就学履歴に転学の履歴を作成する。 ※転学時
                  rGKBTSHUGAKURIREKI_I.KOJIN_NO := rDATA.KOJIN_NO;
                  rGKBTSHUGAKURIREKI_I.NENDO := TO_NUMBER(SUBSTR(KKAPK0020.FNENDOHENKAN(g_vTENGAKUYMD), 1, 4));
                  rGKBTSHUGAKURIREKI_I.KOJIN_RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                  nGKBTSHUGAKURIREKISEQ := nGKBTSHUGAKURIREKISEQ + 10;
                  rGKBTSHUGAKURIREKI_I.SHUGAKU_RIREKI_RENBAN := nGKBTSHUGAKURIREKISEQ;
                  rGKBTSHUGAKURIREKI_I.SAISHIN_FLG := 1;
                  rGKBTSHUGAKURIREKI_I.S_CD := rGTR1.S_CD;
                  rGKBTSHUGAKURIREKI_I.S_NYUGAKU_BI := rGTR1.S_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TENNYU_BI := rGTR1.S_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TENNYU_GAKUNEN := rGTR1.S_TENNYU_GAKUNEN;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(g_vTENGAKUYMD);
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := rGTR1.S_TENGAKU_BI;
                  ELSE
                    NULL;
                  END IF;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := rGTR1.S_TENGAKU_GAKUNEN;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTSHUGAKURIREKI_I.S_TAIGAKU_BI := rGTR1.S_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TAIGAKU_GAKUNEN := rGTR1.S_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.S_SOTSUGYO_BI := rGTR1.S_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.T_CD := rGTR1.T_CD;
                  rGKBTSHUGAKURIREKI_I.T_NYUGAKU_BI := rGTR1.T_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TENNYU_BI := rGTR1.T_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TENNYU_GAKUNEN := rGTR1.T_TENNYU_GAKUNEN;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := rGTR1.T_TENGAKU_BI;
                    rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := rGTR1.T_TENGAKU_GAKUNEN;
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(g_vTENGAKUYMD);
                    rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTSHUGAKURIREKI_I.T_TAIGAKU_BI := rGTR1.T_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TAIGAKU_GAKUNEN := rGTR1.T_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.T_SOTSUGYO_BI := rGTR1.T_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_BU_CD := rGTR1.SHIEN_BU_CD;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_CD := rGTR1.SHIEN_S_CD;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_HUKUSEKI_CD := rGTR1.SHIEN_S_HUKUSEKI_CD;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_NYUGAKU_BI := rGTR1.SHIEN_S_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_BI := rGTR1.SHIEN_S_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_GAKUNEN := rGTR1.SHIEN_S_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_BI := rGTR1.SHIEN_S_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_GAKUNEN := rGTR1.SHIEN_S_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_BI := rGTR1.SHIEN_S_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_GAKUNEN := rGTR1.SHIEN_S_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_SOTSUGYO_BI := rGTR1.SHIEN_S_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_CD := rGTR1.SHIEN_T_CD;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_HUKUSEKI_CD := rGTR1.SHIEN_T_HUKUSEKI_CD;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_NYUGAKU_BI := rGTR1.SHIEN_T_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_BI := rGTR1.SHIEN_T_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_GAKUNEN := rGTR1.SHIEN_T_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_BI := rGTR1.SHIEN_T_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_GAKUNEN := rGTR1.SHIEN_T_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_BI := rGTR1.SHIEN_T_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_GAKUNEN := rGTR1.SHIEN_T_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_SOTSUGYO_BI := rGTR1.SHIEN_T_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_CD := rGTR1.KUIKIGAI_S_CD;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_S_KAISHI_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_NYUGAKU_BI := rGTR1.KUIKIGAI_S_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_BI := rGTR1.KUIKIGAI_S_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_S_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_BI := rGTR1.KUIKIGAI_S_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_BI := rGTR1.KUIKIGAI_S_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SOTSUGYO_BI := rGTR1.KUIKIGAI_S_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_BI := rGTR1.KUIKIGAI_S_KAISHI_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SHURYO_BI := rGTR1.KUIKIGAI_S_SHURYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAIJO_BI := rGTR1.KUIKIGAI_S_KAIJO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_CD := rGTR1.KUIKIGAI_T_CD;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_T_KAISHI_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_NYUGAKU_BI := rGTR1.KUIKIGAI_T_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_BI := rGTR1.KUIKIGAI_T_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_T_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_BI := rGTR1.KUIKIGAI_T_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_BI := rGTR1.KUIKIGAI_T_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SOTSUGYO_BI := rGTR1.KUIKIGAI_T_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_BI := rGTR1.KUIKIGAI_T_KAISHI_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SHURYO_BI := rGTR1.KUIKIGAI_T_SHURYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAIJO_BI := rGTR1.KUIKIGAI_T_KAIJO_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_CD := rGTR1.KUNISHIRITSU_S_CD;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_NYUGAKU_BI := rGTR1.KUNISHIRITSU_S_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_BI := rGTR1.KUNISHIRITSU_S_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_BI := rGTR1.KUNISHIRITSU_S_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_BI := rGTR1.KUNISHIRITSU_S_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_S_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_KAISHI_BI := rGTR1.KUNISHIRITSU_S_KAISHI_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SHURYO_BI := rGTR1.KUNISHIRITSU_S_SHURYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_CD := rGTR1.KUNISHIRITSU_T_CD;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_NYUGAKU_BI := rGTR1.KUNISHIRITSU_T_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_BI := rGTR1.KUNISHIRITSU_T_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_BI := rGTR1.KUNISHIRITSU_T_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_BI := rGTR1.KUNISHIRITSU_T_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_T_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_KAISHI_BI := rGTR1.KUNISHIRITSU_T_KAISHI_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SHURYO_BI := rGTR1.KUNISHIRITSU_T_SHURYO_BI;
                  rGKBTSHUGAKURIREKI_I.SAKUJO_FLG := 0;
                  rGKBTSHUGAKURIREKI_I.SYS_SAKUSEIBI := g_nDATE;
                  rGKBTSHUGAKURIREKI_I.SYS_KOSHINBI := 0;
                  rGKBTSHUGAKURIREKI_I.SYS_JIKAN := g_nTIME;
                  rGKBTSHUGAKURIREKI_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                  rGKBTSHUGAKURIREKI_I.SYS_TANMATU_NO := g_sWSNUM;
                  INSERT INTO GKBTSHUGAKURIREKI VALUES rGKBTSHUGAKURIREKI_I;
                  rGTG1 := rGTG2;
                  rGTR1 := rGTR2;
                  --学齢簿、就学履歴の現最新履歴を取得し直す。
                  BEGIN
                    SELECT *
                    --学齢簿現最新履歴
                    INTO rGTG1
                    FROM GKBTGAKUREIBO GTG
                    WHERE GTG.KOJIN_NO = rDATA.KOJIN_NO
--  2024/11/23 YAMANI.OHARA UPDATE START 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
--                      AND GTG.SAISHIN_KBN = 0
            AND GTG.RIREKI_RENBAN = nGKBTGAKUREIBOSEQ
--  2024/11/23 YAMANI.OHARA UPDATE END
                      AND GTG.SAKUJO_FLG = 0;
                  EXCEPTION
                    WHEN OTHERS THEN
                      rGTG1 := rGTG2;
                  END;
                  BEGIN
                    SELECT *
                    --就学履歴現最新履歴
                    INTO rGTR1
                    FROM GKBTSHUGAKURIREKI GTR
                    WHERE GTR.KOJIN_NO = rDATA.KOJIN_NO
--  2024/11/23 YAMANI.OHARA UPDATE START 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
--                      AND GTR.SAISHIN_FLG = 0
                      AND GTR.KOJIN_RIREKI_RENBAN = nGKBTGAKUREIBOSEQ
                      AND GTR.SHUGAKU_RIREKI_RENBAN = nGKBTSHUGAKURIREKISEQ
--  2024/11/23 YAMANI.OHARA UPDATE END
                      AND GTR.SAKUJO_FLG = 0;
                  EXCEPTION
                    WHEN OTHERS THEN
                      rGTR1 := rGTR2;
                  END;
                  --学齢簿に転入学の履歴を作成する。 ※新入学児童以外の場合の転入学
                  rGKBTGAKUREIBO_I.KOJIN_NO := rDATA.KOJIN_NO;
                  nGKBTGAKUREIBOSEQ := nGKBTGAKUREIBOSEQ + 10;
                  rGKBTGAKUREIBO_I.RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                  rGKBTGAKUREIBO_I.RIREKI_RENBAN_EDA := 0;
                  rGKBTGAKUREIBO_I.GENZON_KBN := rGTG1.GENZON_KBN;
                  rGKBTGAKUREIBO_I.SAISHIN_KBN := 0;
                  rGKBTGAKUREIBO_I.ZO_JIYU_CD := rGTG1.ZO_JIYU_CD;
                  rGKBTGAKUREIBO_I.ZO_NENGAPI := rGTG1.ZO_NENGAPI;
                  rGKBTGAKUREIBO_I.GEN_JIYU_CD := rGTG1.GEN_JIYU_CD;
                  rGKBTGAKUREIBO_I.GEN_NENGAPI := rGTG1.GEN_NENGAPI;
                  rGKBTGAKUREIBO_I.ZOKUGARA1 := rGTG1.ZOKUGARA1;
                  rGKBTGAKUREIBO_I.ZOKUGARA2 := rGTG1.ZOKUGARA2;
                  rGKBTGAKUREIBO_I.ZOKUGARA3 := rGTG1.ZOKUGARA3;
                  rGKBTGAKUREIBO_I.ZOKUGARA4 := rGTG1.ZOKUGARA4;
                  rGKBTGAKUREIBO_I.HOGOSYA_KOJIN_NO := rGTG1.HOGOSYA_KOJIN_NO;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA1 := rGTG1.HOGOSYA_ZOKUGARA1;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA2 := rGTG1.HOGOSYA_ZOKUGARA2;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA3 := rGTG1.HOGOSYA_ZOKUGARA3;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA4 := rGTG1.HOGOSYA_ZOKUGARA4;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTGAKUREIBO_I.SYOGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                    rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := 0;
                    rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                    rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := 0;
                    rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := 0;
                    rGKBTGAKUREIBO_I.TYUGAKO_CD := rGTG1.TYUGAKO_CD;
                    rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := rGTG1.TYUGAKO_NYUGAKU_BI;
                    rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := rGTG1.TYUGAKO_TENNYUGAKU_BI;
                    rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := rGTG1.TYUGAKO_TENGAKU_BI;
                    rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := rGTG1.TYUGAKO_SOTSUGYO_BI;
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTGAKUREIBO_I.SYOGAKO_CD := rGTG1.SYOGAKO_CD;
                    rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := rGTG1.SYOGAKO_NYUGAKU_BI;
                    rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := rGTG1.SYOGAKO_TENNYUGAKU_BI;
                    rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := rGTG1.SYOGAKO_TENGAKU_BI;
                    rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := rGTG1.SYOGAKO_SOTSUGYO_BI;
                    rGKBTGAKUREIBO_I.TYUGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                    rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := 0;
                    rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                    rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := 0;
                    rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := 0;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI1 := rGTG1.TOKUSOKU_BI1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO1 := rGTG1.TOKUSOKU_NAIYO1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU1 := rGTG1.TOKUSOKU_JIYU1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI1 := rGTG1.TOKUSOKU_JURI_BI1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI2 := rGTG1.TOKUSOKU_BI2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO2 := rGTG1.TOKUSOKU_NAIYO2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU2 := rGTG1.TOKUSOKU_JIYU2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI2 := rGTG1.TOKUSOKU_JURI_BI2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI3 := rGTG1.TOKUSOKU_BI3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO3 := rGTG1.TOKUSOKU_NAIYO3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU3 := rGTG1.TOKUSOKU_JIYU3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI3 := rGTG1.TOKUSOKU_JURI_BI3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI4 := rGTG1.TOKUSOKU_BI4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO4 := rGTG1.TOKUSOKU_NAIYO4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU4 := rGTG1.TOKUSOKU_JIYU4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI4 := rGTG1.TOKUSOKU_JURI_BI4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI5 := rGTG1.TOKUSOKU_BI5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO5 := rGTG1.TOKUSOKU_NAIYO5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU5 := rGTG1.TOKUSOKU_JIYU5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI5 := rGTG1.TOKUSOKU_JURI_BI5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI6 := rGTG1.TOKUSOKU_BI6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO6 := rGTG1.TOKUSOKU_NAIYO6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU6 := rGTG1.TOKUSOKU_JIYU6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI6 := rGTG1.TOKUSOKU_JURI_BI6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI7 := rGTG1.TOKUSOKU_BI7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO7 := rGTG1.TOKUSOKU_NAIYO7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU7 := rGTG1.TOKUSOKU_JIYU7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI7 := rGTG1.TOKUSOKU_JURI_BI7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI8 := rGTG1.TOKUSOKU_BI8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO8 := rGTG1.TOKUSOKU_NAIYO8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU8 := rGTG1.TOKUSOKU_JIYU8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI8 := rGTG1.TOKUSOKU_JURI_BI8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI9 := rGTG1.TOKUSOKU_BI9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO9 := rGTG1.TOKUSOKU_NAIYO9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU9 := rGTG1.TOKUSOKU_JIYU9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI9 := rGTG1.TOKUSOKU_JURI_BI9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI10 := rGTG1.TOKUSOKU_BI10;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO10 := rGTG1.TOKUSOKU_NAIYO10;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU10 := rGTG1.TOKUSOKU_JIYU10;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI10 := rGTG1.TOKUSOKU_JURI_BI10;
                  rGKBTGAKUREIBO_I.KUIKIGAI_CD := rGTG1.KUIKIGAI_CD;
                  rGKBTGAKUREIBO_I.KUIKIGAI_SETISYA := rGTG1.KUIKIGAI_SETISYA;
                  rGKBTGAKUREIBO_I.KUIKIGAI_NYUGAKU_BI := rGTG1.KUIKIGAI_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_BI := rGTG1.KUIKIGAI_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_BI := rGTG1.KUIKIGAI_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_BI := rGTG1.KUIKIGAI_TAIGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_SOTSUGYO_BI := rGTG1.KUIKIGAI_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_CD := rGTG1.YOGOGAKO_CD;
                  rGKBTGAKUREIBO_I.YOGOGAKO_SETISYA := rGTG1.YOGOGAKO_SETISYA;
                  rGKBTGAKUREIBO_I.YOGOGAKO_NYUGAKU_BI := rGTG1.YOGOGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_BI := rGTG1.YOGOGAKO_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_BI := rGTG1.YOGOGAKO_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_BI := rGTG1.YOGOGAKO_TAIGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_SOTSUGYO_BI := rGTG1.YOGOGAKO_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.YUYO_KYOKA_BI := rGTG1.YUYO_KYOKA_BI;
                  rGKBTGAKUREIBO_I.YUYO_JIYU_CD := rGTG1.YUYO_JIYU_CD;
                  rGKBTGAKUREIBO_I.YUYO_JIYU := rGTG1.YUYO_JIYU;
                  rGKBTGAKUREIBO_I.YUYO_KAISI_BI := rGTG1.YUYO_KAISI_BI;
                  rGKBTGAKUREIBO_I.YUYO_SYURYO_BI := rGTG1.YUYO_SYURYO_BI;
                  rGKBTGAKUREIBO_I.YUYO_NENSU := rGTG1.YUYO_NENSU;
                  rGKBTGAKUREIBO_I.YUYO_FUKUGAKU_BI := rGTG1.YUYO_FUKUGAKU_BI;
                  rGKBTGAKUREIBO_I.MENJO_KYOKA_BI := rGTG1.MENJO_KYOKA_BI;
                  rGKBTGAKUREIBO_I.MENJO_JIYU_CD := rGTG1.MENJO_JIYU_CD;
                  rGKBTGAKUREIBO_I.MENJO_JIYU := rGTG1.MENJO_JIYU;
                  rGKBTGAKUREIBO_I.MENJO_KAISI_BI := rGTG1.MENJO_KAISI_BI;
                  rGKBTGAKUREIBO_I.MENJO_SYURYO_BI := rGTG1.MENJO_SYURYO_BI;
                  rGKBTGAKUREIBO_I.MENJO_NENSU := rGTG1.MENJO_NENSU;
                  rGKBTGAKUREIBO_I.MENJO_FUKUGAKU_BI := rGTG1.MENJO_FUKUGAKU_BI;
                  rGKBTGAKUREIBO_I.IDO_BI1 := rGTG1.IDO_BI1;
                  rGKBTGAKUREIBO_I.IDO_JIYU1 := rGTG1.IDO_JIYU1;
                  rGKBTGAKUREIBO_I.IDO_BI2 := rGTG1.IDO_BI2;
                  rGKBTGAKUREIBO_I.IDO_JIYU2 := rGTG1.IDO_JIYU2;
                  rGKBTGAKUREIBO_I.IDO_BI3 := rGTG1.IDO_BI3;
                  rGKBTGAKUREIBO_I.IDO_JIYU3 := rGTG1.IDO_JIYU3;
                  rGKBTGAKUREIBO_I.IDO_BI4 := rGTG1.IDO_BI4;
                  rGKBTGAKUREIBO_I.IDO_JIYU4 := rGTG1.IDO_JIYU4;
                  rGKBTGAKUREIBO_I.IDO_BI5 := rGTG1.IDO_BI5;
                  rGKBTGAKUREIBO_I.IDO_JIYU5 := rGTG1.IDO_JIYU5;
                  rGKBTGAKUREIBO_I.IDO_BI6 := rGTG1.IDO_BI6;
                  rGKBTGAKUREIBO_I.IDO_JIYU6 := rGTG1.IDO_JIYU6;
                  rGKBTGAKUREIBO_I.IDO_BI7 := rGTG1.IDO_BI7;
                  rGKBTGAKUREIBO_I.IDO_JIYU7 := rGTG1.IDO_JIYU7;
                  rGKBTGAKUREIBO_I.IDO_BI8 := rGTG1.IDO_BI8;
                  rGKBTGAKUREIBO_I.IDO_JIYU8 := rGTG1.IDO_JIYU8;
                  rGKBTGAKUREIBO_I.IDO_BI9 := rGTG1.IDO_BI9;
                  rGKBTGAKUREIBO_I.IDO_JIYU9 := rGTG1.IDO_JIYU9;
                  rGKBTGAKUREIBO_I.IDO_BI10 := rGTG1.IDO_BI10;
                  rGKBTGAKUREIBO_I.IDO_JIYU10 := rGTG1.IDO_JIYU10;
                  rGKBTGAKUREIBO_I.SYS_SAKUSEIBI := rGTG1.SYS_SAKUSEIBI;
                  rGKBTGAKUREIBO_I.SYS_KOSHINBI := g_nDATE;
                  rGKBTGAKUREIBO_I.SYS_JIKAN := g_nTIME;
                  rGKBTGAKUREIBO_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                  rGKBTGAKUREIBO_I.SYS_TANMATU_NO := g_sWSNUM;
                  rGKBTGAKUREIBO_I.GAKUNEN := rGTG1.GAKUNEN;
                  rGKBTGAKUREIBO_I.SHORIBI := g_nDATE;
                  rGKBTGAKUREIBO_I.SHUGAKU := rGTG1.SHUGAKU;
                  rGKBTGAKUREIBO_I.IDOJIKO := rGTG1.IDOJIKO;
                  rGKBTGAKUREIBO_I.CHOHYO_NO := rGTG1.CHOHYO_NO;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                    rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := 0;
                    rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rGTG1.TYUGAKO_TENNYUGAKU_GAKUNEN;
                    rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rGTG1.TYUGAKO_TENGAKU_GAKUNEN;
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.SYOGAKO_TENNYUGAKU_GAKUNEN;
                    rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rGTG1.SYOGAKO_TENGAKU_GAKUNEN;
                    rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                    rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := 0;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_GAKUNEN := rGTG1.KUIKIGAI_TAIGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_GAKUNEN := rGTG1.YOGOGAKO_TAIGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.GAKKO_KBN_CD := rGTG1.GAKKO_KBN_CD;
                  rGKBTGAKUREIBO_I.GAKUKYU_CD := 0;
                  rGKBTGAKUREIBO_I.SEIBETSU := rGTG1.SEIBETSU;
                  rGKBTGAKUREIBO_I.JOTAI := rGTG1.JOTAI;
                  rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_KBN := rGTG1.TENNYUMAE_GAKKO_KBN;
                  rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_CD := rGTG1.TENNYUMAE_GAKKO_CD;
                  rGKBTGAKUREIBO_I.TENNYUMAE_GAKUNEN := rGTG1.TENNYUMAE_GAKUNEN;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_FLG := rGTG1.GENKYURYUCHI_FLG;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_KETTEI_BI := rGTG1.GENKYURYUCHI_KETTEI_BI;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_KAISI_BI := rGTG1.GENKYURYUCHI_KAISI_BI;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_SYURYOBI := rGTG1.GENKYURYUCHI_SYURYOBI;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_RIYU := rGTG1.GENKYURYUCHI_RIYU;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                    rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rGTG1.SHITEI_TYUGAKO_CD;
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rGTG1.SHITEI_SYOGAKO_CD;
                    rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.HENKO_GAKUNEN_SYOGAKO := rGTG1.HENKO_GAKUNEN_SYOGAKO;
                  rGKBTGAKUREIBO_I.HENKO_GAKUNEN_TYUGAKO := rGTG1.HENKO_GAKUNEN_TYUGAKO;
                  rGKBTGAKUREIBO_I.HENKO_SHINSEI_BI := rGTG1.HENKO_SHINSEI_BI;
                  rGKBTGAKUREIBO_I.HENKO_KYOKA_BI := rGTG1.HENKO_KYOKA_BI;
                  rGKBTGAKUREIBO_I.HENKO_KBN := rGTG1.HENKO_KBN;
                  rGKBTGAKUREIBO_I.HENKO_KAISI_BI := rGTG1.HENKO_KAISI_BI;
                  rGKBTGAKUREIBO_I.HENKO_SYURYO_BI := rGTG1.HENKO_SYURYO_BI;
                  rGKBTGAKUREIBO_I.HENKO_KYOKA_RIYU := rGTG1.HENKO_KYOKA_RIYU;
                  rGKBTGAKUREIBO_I.HENKO_JIYU := rGTG1.HENKO_JIYU;
                  rGKBTGAKUREIBO_I.HENKO_HUKYOKA_RIYU := rGTG1.HENKO_HUKYOKA_RIYU;
                  rGKBTGAKUREIBO_I.KIBO_GAKKO_KBN_CD := rGTG1.KIBO_GAKKO_KBN_CD;
                  rGKBTGAKUREIBO_I.KIBO_SYOGAKKO_CD := rGTG1.KIBO_SYOGAKKO_CD;
                  rGKBTGAKUREIBO_I.KIBO_TYUGAKKO_CD := rGTG1.KIBO_TYUGAKKO_CD;
                  rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_SYOGAKO := rGTG1.KIBO_UKETSUKE_BI_SYOGAKO;
                  rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_TYUGAKO := rGTG1.KIBO_UKETSUKE_BI_TYUGAKO;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_FLG := rGTG1.KUIKIGAISHUGAKU_FLG;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SHINSEI_BI := rGTG1.KUIKIGAISHUGAKU_SHINSEI_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_BI := rGTG1.KUIKIGAISHUGAKU_KYOKA_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KAISI_BI := rGTG1.KUIKIGAISHUGAKU_KAISI_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SYURYO_BI := rGTG1.KUIKIGAISHUGAKU_SYURYO_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_JIYU := rGTG1.KUIKIGAISHUGAKU_JIYU;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_KYOKA_RIYU;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_HUKYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_HUKYOKA_RIYU;
                  rGKBTGAKUREIBO_I.HUSHUGAKU_KAISI_BI := rGTG1.HUSHUGAKU_KAISI_BI;
                  rGKBTGAKUREIBO_I.HUSHUGAKU_SYURYO_BI := rGTG1.HUSHUGAKU_SYURYO_BI;
                  rGKBTGAKUREIBO_I.HUSHUGAKU_RIYU := rGTG1.HUSHUGAKU_RIYU;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_CD := rGTG1.KUNISHIRITSU_CD;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_NYUGAKU_BI := rGTG1.KUNISHIRITSU_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_BI := rGTG1.KUNISHIRITSU_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_BI := rGTG1.KUNISHIRITSU_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_BI := rGTG1.KUNISHIRITSU_TAIGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TAIGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_SOTSUGYO_BI := rGTG1.KUNISHIRITSU_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_KAISI_BI := rGTG1.KUNISHIRITSU_KAISI_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_SYURYO_BI := rGTG1.KUNISHIRITSU_SYURYO_BI;
                  rGKBTGAKUREIBO_I.TSUSHOMEI_KANA := rGTG1.TSUSHOMEI_KANA;
                  rGKBTGAKUREIBO_I.TSUSHOMEI_KANJI := rGTG1.TSUSHOMEI_KANJI;
                  rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANA := rGTG1.HOGOSHA_TSUSHOMEI_KANA;
                  rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANJI := rGTG1.HOGOSHA_TSUSHOMEI_KANJI;
                  rGKBTGAKUREIBO_I.GRB_HENKO_TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                  rGKBTGAKUREIBO_I.GRB_HENKO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                  nRTN := KKAPK0030.FCTGetR('GKB', '00TOHAIGO_HENKOJIYU', '0000', 0, aPRM);
                  IF aPRM(1) = '1' THEN
                    rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 14;
                  ELSIF aPRM(1) = '2' THEN
                    rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 99;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.BIKO := REPLACE(rGTG1.BIKO, chr(13)||chr(10),'#') || '新設・統廃合一括処理による転入学';
                  rGKBTGAKUREIBO_I.IDO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                  rGKBTGAKUREIBO_I.TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                  rGKBTGAKUREIBO_I.SHINSEI_KANRI_RENBAN := rGTG1.SHINSEI_KANRI_RENBAN;
                  rGKBTGAKUREIBO_I.IDOJI_ATENA_RIREKI_RENBAN := rGTG1.IDOJI_ATENA_RIREKI_RENBAN;
                  rGKBTGAKUREIBO_I.HOGOSYA_IDOJI_RIREKI_RENBAN := rGTG1.HOGOSYA_IDOJI_RIREKI_RENBAN;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rDATA.NEW_GAKKOKU_CD;
                    rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rGTG1.CHUGAKKOKU_CD;
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rGTG1.SHOGAKKOKU_CD;
                    rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rDATA.NEW_GAKKOKU_CD;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.SAKUJO_FLG := 0;
                  BEGIN
                    SELECT
                      BUKACODE
                    INTO sBUKACODE
                    FROM
                      KKNTWS
                    WHERE
                      KKNTWS.WSNUM = g_sWSNUM;
                  EXCEPTION
                    WHEN OTHERS THEN
                      sBUKACODE := NULL;
                  END;
                  BEGIN
                    SELECT
                      BUKANAME
                    INTO rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO
                    FROM
                      KKNTBK
                    WHERE
                      BUKACODE = sBUKACODE
                      AND KKNTBK.YUKOKIKANFR = (
                                                 SELECT MAX(YUKOKIKANFR) FROM KKNTBK WHERE BUKACODE = sBUKACODE
                                                );
                  EXCEPTION
                    WHEN OTHERS THEN
                      rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO := NULL;
                  END;
                  INSERT INTO GKBTGAKUREIBO VALUES rGKBTGAKUREIBO_I;
                  --就学履歴に転入学の履歴を作成する。 ※転入学時
                  rGKBTSHUGAKURIREKI_I.KOJIN_NO := rDATA.KOJIN_NO;
                  rGKBTSHUGAKURIREKI_I.NENDO := TO_NUMBER(SUBSTR(KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD), 1, 4));
                  rGKBTSHUGAKURIREKI_I.KOJIN_RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                  nGKBTSHUGAKURIREKISEQ := nGKBTSHUGAKURIREKISEQ + 10;
                  rGKBTSHUGAKURIREKI_I.SHUGAKU_RIREKI_RENBAN := nGKBTSHUGAKURIREKISEQ;
                  rGKBTSHUGAKURIREKI_I.SAISHIN_FLG := 0;
                  IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                    rGKBTSHUGAKURIREKI_I.S_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                    rGKBTSHUGAKURIREKI_I.S_NYUGAKU_BI := 0;
                    rGKBTSHUGAKURIREKI_I.S_TENNYU_BI := KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD);
                    rGKBTSHUGAKURIREKI_I.S_TENNYU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                    rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := 0;
                    rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := 0;
                    rGKBTSHUGAKURIREKI_I.S_TAIGAKU_BI := 0;
                    rGKBTSHUGAKURIREKI_I.S_TAIGAKU_GAKUNEN := 0;
                    rGKBTSHUGAKURIREKI_I.S_SOTSUGYO_BI := 0;
                    rGKBTSHUGAKURIREKI_I.T_CD := rGTR1.T_CD;
                    rGKBTSHUGAKURIREKI_I.T_NYUGAKU_BI := rGTR1.T_NYUGAKU_BI;
                    rGKBTSHUGAKURIREKI_I.T_TENNYU_BI := rGTR1.T_TENNYU_BI;
                    rGKBTSHUGAKURIREKI_I.T_TENNYU_GAKUNEN := rGTR1.T_TENNYU_GAKUNEN;
                    rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := rGTR1.T_TENGAKU_BI;
                    rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := rGTR1.T_TENGAKU_GAKUNEN;
                    rGKBTSHUGAKURIREKI_I.T_TAIGAKU_BI := rGTR1.T_TAIGAKU_BI;
                    rGKBTSHUGAKURIREKI_I.T_TAIGAKU_GAKUNEN := rGTR1.T_TAIGAKU_GAKUNEN;
                    rGKBTSHUGAKURIREKI_I.T_SOTSUGYO_BI := rGTR1.T_SOTSUGYO_BI;
                  ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                    rGKBTSHUGAKURIREKI_I.S_CD := rGTR1.S_CD;
                    rGKBTSHUGAKURIREKI_I.S_NYUGAKU_BI := rGTR1.S_NYUGAKU_BI;
                    rGKBTSHUGAKURIREKI_I.S_TENNYU_BI := rGTR1.S_TENNYU_BI;
                    rGKBTSHUGAKURIREKI_I.S_TENNYU_GAKUNEN := rGTR1.S_TENNYU_GAKUNEN;
                    rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := rGTR1.S_TENGAKU_BI;
                    rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := rGTR1.S_TENGAKU_GAKUNEN;
                    rGKBTSHUGAKURIREKI_I.S_TAIGAKU_BI := rGTR1.S_TAIGAKU_BI;
                    rGKBTSHUGAKURIREKI_I.S_TAIGAKU_GAKUNEN := rGTR1.S_TAIGAKU_GAKUNEN;
                    rGKBTSHUGAKURIREKI_I.S_SOTSUGYO_BI := rGTR1.S_SOTSUGYO_BI;
                    rGKBTSHUGAKURIREKI_I.T_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                    rGKBTSHUGAKURIREKI_I.T_NYUGAKU_BI := 0;
                    rGKBTSHUGAKURIREKI_I.T_TENNYU_BI := KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD);
                    rGKBTSHUGAKURIREKI_I.T_TENNYU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                    rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := 0;
                    rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := 0;
                    rGKBTSHUGAKURIREKI_I.T_TAIGAKU_BI := 0;
                    rGKBTSHUGAKURIREKI_I.T_TAIGAKU_GAKUNEN := 0;
                    rGKBTSHUGAKURIREKI_I.T_SOTSUGYO_BI := 0;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTSHUGAKURIREKI_I.SHIEN_BU_CD := rGTR1.SHIEN_BU_CD;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_CD := rGTR1.SHIEN_S_CD;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_HUKUSEKI_CD := rGTR1.SHIEN_S_HUKUSEKI_CD;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_NYUGAKU_BI := rGTR1.SHIEN_S_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_BI := rGTR1.SHIEN_S_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_GAKUNEN := rGTR1.SHIEN_S_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_BI := rGTR1.SHIEN_S_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_GAKUNEN := rGTR1.SHIEN_S_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_BI := rGTR1.SHIEN_S_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_GAKUNEN := rGTR1.SHIEN_S_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_S_SOTSUGYO_BI := rGTR1.SHIEN_S_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_CD := rGTR1.SHIEN_T_CD;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_HUKUSEKI_CD := rGTR1.SHIEN_T_HUKUSEKI_CD;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_NYUGAKU_BI := rGTR1.SHIEN_T_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_BI := rGTR1.SHIEN_T_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_GAKUNEN := rGTR1.SHIEN_T_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_BI := rGTR1.SHIEN_T_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_GAKUNEN := rGTR1.SHIEN_T_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_BI := rGTR1.SHIEN_T_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_GAKUNEN := rGTR1.SHIEN_T_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.SHIEN_T_SOTSUGYO_BI := rGTR1.SHIEN_T_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_CD := rGTR1.KUIKIGAI_S_CD;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_S_KAISHI_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_NYUGAKU_BI := rGTR1.KUIKIGAI_S_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_BI := rGTR1.KUIKIGAI_S_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_S_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_BI := rGTR1.KUIKIGAI_S_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_BI := rGTR1.KUIKIGAI_S_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SOTSUGYO_BI := rGTR1.KUIKIGAI_S_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_BI := rGTR1.KUIKIGAI_S_KAISHI_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SHURYO_BI := rGTR1.KUIKIGAI_S_SHURYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAIJO_BI := rGTR1.KUIKIGAI_S_KAIJO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_CD := rGTR1.KUIKIGAI_T_CD;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_T_KAISHI_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_NYUGAKU_BI := rGTR1.KUIKIGAI_T_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_BI := rGTR1.KUIKIGAI_T_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_T_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_BI := rGTR1.KUIKIGAI_T_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_BI := rGTR1.KUIKIGAI_T_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SOTSUGYO_BI := rGTR1.KUIKIGAI_T_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_BI := rGTR1.KUIKIGAI_T_KAISHI_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SHURYO_BI := rGTR1.KUIKIGAI_T_SHURYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAIJO_BI := rGTR1.KUIKIGAI_T_KAIJO_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_CD := rGTR1.KUNISHIRITSU_S_CD;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_NYUGAKU_BI := rGTR1.KUNISHIRITSU_S_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_BI := rGTR1.KUNISHIRITSU_S_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_BI := rGTR1.KUNISHIRITSU_S_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_BI := rGTR1.KUNISHIRITSU_S_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_S_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_KAISHI_BI := rGTR1.KUNISHIRITSU_S_KAISHI_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SHURYO_BI := rGTR1.KUNISHIRITSU_S_SHURYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_CD := rGTR1.KUNISHIRITSU_T_CD;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_NYUGAKU_BI := rGTR1.KUNISHIRITSU_T_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_BI := rGTR1.KUNISHIRITSU_T_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_BI := rGTR1.KUNISHIRITSU_T_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_BI := rGTR1.KUNISHIRITSU_T_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_T_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_KAISHI_BI := rGTR1.KUNISHIRITSU_T_KAISHI_BI;
                  rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SHURYO_BI := rGTR1.KUNISHIRITSU_T_SHURYO_BI;
                  rGKBTSHUGAKURIREKI_I.SAKUJO_FLG := rGTR1.SAKUJO_FLG;
                  rGKBTSHUGAKURIREKI_I.SYS_SAKUSEIBI := g_nDATE;
                  rGKBTSHUGAKURIREKI_I.SYS_KOSHINBI := 0;
                  rGKBTSHUGAKURIREKI_I.SYS_JIKAN := g_nTIME;
                  rGKBTSHUGAKURIREKI_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                  rGKBTSHUGAKURIREKI_I.SYS_TANMATU_NO := g_sWSNUM;
                  INSERT INTO GKBTSHUGAKURIREKI VALUES rGKBTSHUGAKURIREKI_I;
                  IF g_NENTXYUFLG = 1 THEN
                    --学年履歴の現最新履歴の最新フラグを変更する。
                    UPDATE GKBTGAKUNENRIREKI
                    SET SAISIN_FLG = 1,
                        SYS_KOSHINBI = g_nDATE,
                        SYS_JIKAN = g_nTIME,
                        SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                        SYS_TANMATU_NO = g_sWSNUM
                    WHERE KOJIN_NO = rDATA.KOJIN_NO
                      AND SAISIN_FLG = 0;
                    --学年履歴に転入先の学校の学年履歴を作成する。
                    rGKBTGAKUNENRIREKI_I.KOJIN_NO := rDATA.KOJIN_NO;
                    rGKBTGAKUNENRIREKI_I.NENDO := TO_NUMBER(SUBSTR(KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD), 1, 4));
                    rGKBTGAKUNENRIREKI_I.KOJIN_RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                    rGKBTGAKUNENRIREKI_I.GAKUNEN_RIREKI_RENBAN := nGKBTGAKUNENRIREKISEQ;
                    rGKBTGAKUNENRIREKI_I.GAKKO_KBN_CD := rDATA.NEW_SHUGAKUSHITEIKOU_KBN;
                    rGKBTGAKUNENRIREKI_I.GAKKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                    rGKBTGAKUNENRIREKI_I.SAISIN_FLG := 0;
                    rGKBTGAKUNENRIREKI_I.GAKUKYU_KBN := 0;
                    rGKBTGAKUNENRIREKI_I.GAKUKYU_CD := 0;
                    rGKBTGAKUNENRIREKI_I.GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                    rGKBTGAKUNENRIREKI_I.SAKUJO_FLG := 0;
                    rGKBTGAKUNENRIREKI_I.SYS_SAKUSEIBI := g_nDATE;
                    rGKBTGAKUNENRIREKI_I.SYS_KOSHINBI := 0;
                    rGKBTGAKUNENRIREKI_I.SYS_JIKAN := g_nTIME;
                    rGKBTGAKUNENRIREKI_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                    rGKBTGAKUNENRIREKI_I.SYS_TANMATU_NO := g_sWSNUM;
                    INSERT INTO GKBTGAKUNENRIREKI VALUES rGKBTGAKUNENRIREKI_I;
                  END IF;
                ELSIF rDATA.NEW_SHUGAKUSHITEIKOU_KBN = 2 THEN
                  --学齢簿の現最新履歴の最新区分を変更する。
                  UPDATE GKBTGAKUREIBO
                  SET SAISHIN_KBN = 1,
                      SYS_KOSHINBI = g_nDATE,
                      SYS_JIKAN = g_nTIME,
                      SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                      SYS_TANMATU_NO = g_sWSNUM
                  WHERE KOJIN_NO = rDATA.KOJIN_NO
                    AND SAISHIN_KBN = 0;
                  --学齢簿の履歴を作成する。 ※新入学児童の場合
                  rGKBTGAKUREIBO_I.KOJIN_NO := rDATA.KOJIN_NO;
                  nGKBTGAKUREIBOSEQ := nGKBTGAKUREIBOSEQ + 10;
                  rGKBTGAKUREIBO_I.RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                  rGKBTGAKUREIBO_I.RIREKI_RENBAN_EDA := 0;
                  rGKBTGAKUREIBO_I.GENZON_KBN := rGTG1.GENZON_KBN;
                  rGKBTGAKUREIBO_I.SAISHIN_KBN := 0;
                  rGKBTGAKUREIBO_I.ZO_JIYU_CD := rGTG1.ZO_JIYU_CD;
                  rGKBTGAKUREIBO_I.ZO_NENGAPI := rGTG1.ZO_NENGAPI;
                  rGKBTGAKUREIBO_I.GEN_JIYU_CD := rGTG1.GEN_JIYU_CD;
                  rGKBTGAKUREIBO_I.GEN_NENGAPI := rGTG1.GEN_NENGAPI;
                  rGKBTGAKUREIBO_I.ZOKUGARA1 := rGTG1.ZOKUGARA1;
                  rGKBTGAKUREIBO_I.ZOKUGARA2 := rGTG1.ZOKUGARA2;
                  rGKBTGAKUREIBO_I.ZOKUGARA3 := rGTG1.ZOKUGARA3;
                  rGKBTGAKUREIBO_I.ZOKUGARA4 := rGTG1.ZOKUGARA4;
                  rGKBTGAKUREIBO_I.HOGOSYA_KOJIN_NO := rGTG1.HOGOSYA_KOJIN_NO;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA1 := rGTG1.HOGOSYA_ZOKUGARA1;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA2 := rGTG1.HOGOSYA_ZOKUGARA2;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA3 := rGTG1.HOGOSYA_ZOKUGARA3;
                  rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA4 := rGTG1.HOGOSYA_ZOKUGARA4;
                  IF rDATA.NOW_GAKUNEN = 0 THEN
                    rGKBTGAKUREIBO_I.SYOGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                    rGKBTGAKUREIBO_I.SYOGAKO_CD := rGTG1.SYOGAKO_CD;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := rGTG1.SYOGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := rGTG1.SYOGAKO_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := rGTG1.SYOGAKO_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := rGTG1.SYOGAKO_SOTSUGYO_BI;
                  IF rDATA.NOW_GAKUNEN = 0 THEN
                    rGKBTGAKUREIBO_I.TYUGAKO_CD := rGTG1.TYUGAKO_CD;
                  ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                    rGKBTGAKUREIBO_I.TYUGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := rGTG1.TYUGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := rGTG1.TYUGAKO_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := rGTG1.TYUGAKO_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := rGTG1.TYUGAKO_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI1 := rGTG1.TOKUSOKU_BI1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO1 := rGTG1.TOKUSOKU_NAIYO1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU1 := rGTG1.TOKUSOKU_JIYU1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI1 := rGTG1.TOKUSOKU_JURI_BI1;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI2 := rGTG1.TOKUSOKU_BI2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO2 := rGTG1.TOKUSOKU_NAIYO2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU2 := rGTG1.TOKUSOKU_JIYU2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI2 := rGTG1.TOKUSOKU_JURI_BI2;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI3 := rGTG1.TOKUSOKU_BI3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO3 := rGTG1.TOKUSOKU_NAIYO3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU3 := rGTG1.TOKUSOKU_JIYU3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI3 := rGTG1.TOKUSOKU_JURI_BI3;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI4 := rGTG1.TOKUSOKU_BI4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO4 := rGTG1.TOKUSOKU_NAIYO4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU4 := rGTG1.TOKUSOKU_JIYU4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI4 := rGTG1.TOKUSOKU_JURI_BI4;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI5 := rGTG1.TOKUSOKU_BI5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO5 := rGTG1.TOKUSOKU_NAIYO5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU5 := rGTG1.TOKUSOKU_JIYU5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI5 := rGTG1.TOKUSOKU_JURI_BI5;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI6 := rGTG1.TOKUSOKU_BI6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO6 := rGTG1.TOKUSOKU_NAIYO6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU6 := rGTG1.TOKUSOKU_JIYU6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI6 := rGTG1.TOKUSOKU_JURI_BI6;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI7 := rGTG1.TOKUSOKU_BI7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO7 := rGTG1.TOKUSOKU_NAIYO7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU7 := rGTG1.TOKUSOKU_JIYU7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI7 := rGTG1.TOKUSOKU_JURI_BI7;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI8 := rGTG1.TOKUSOKU_BI8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO8 := rGTG1.TOKUSOKU_NAIYO8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU8 := rGTG1.TOKUSOKU_JIYU8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI8 := rGTG1.TOKUSOKU_JURI_BI8;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI9 := rGTG1.TOKUSOKU_BI9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO9 := rGTG1.TOKUSOKU_NAIYO9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU9 := rGTG1.TOKUSOKU_JIYU9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI9 := rGTG1.TOKUSOKU_JURI_BI9;
                  rGKBTGAKUREIBO_I.TOKUSOKU_BI10 := rGTG1.TOKUSOKU_BI10;
                  rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO10 := rGTG1.TOKUSOKU_NAIYO10;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JIYU10 := rGTG1.TOKUSOKU_JIYU10;
                  rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI10 := rGTG1.TOKUSOKU_JURI_BI10;
                  rGKBTGAKUREIBO_I.KUIKIGAI_CD := rGTG1.KUIKIGAI_CD;
                  rGKBTGAKUREIBO_I.KUIKIGAI_SETISYA := rGTG1.KUIKIGAI_SETISYA;
                  rGKBTGAKUREIBO_I.KUIKIGAI_NYUGAKU_BI := rGTG1.KUIKIGAI_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_BI := rGTG1.KUIKIGAI_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_BI := rGTG1.KUIKIGAI_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_BI := rGTG1.KUIKIGAI_TAIGAKU_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAI_SOTSUGYO_BI := rGTG1.KUIKIGAI_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_CD := rGTG1.YOGOGAKO_CD;
                  rGKBTGAKUREIBO_I.YOGOGAKO_SETISYA := rGTG1.YOGOGAKO_SETISYA;
                  rGKBTGAKUREIBO_I.YOGOGAKO_NYUGAKU_BI := rGTG1.YOGOGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_BI := rGTG1.YOGOGAKO_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_BI := rGTG1.YOGOGAKO_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_BI := rGTG1.YOGOGAKO_TAIGAKU_BI;
                  rGKBTGAKUREIBO_I.YOGOGAKO_SOTSUGYO_BI := rGTG1.YOGOGAKO_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.YUYO_KYOKA_BI := rGTG1.YUYO_KYOKA_BI;
                  rGKBTGAKUREIBO_I.YUYO_JIYU_CD := rGTG1.YUYO_JIYU_CD;
                  rGKBTGAKUREIBO_I.YUYO_JIYU := rGTG1.YUYO_JIYU;
                  rGKBTGAKUREIBO_I.YUYO_KAISI_BI := rGTG1.YUYO_KAISI_BI;
                  rGKBTGAKUREIBO_I.YUYO_SYURYO_BI := rGTG1.YUYO_SYURYO_BI;
                  rGKBTGAKUREIBO_I.YUYO_NENSU := rGTG1.YUYO_NENSU;
                  rGKBTGAKUREIBO_I.YUYO_FUKUGAKU_BI := rGTG1.YUYO_FUKUGAKU_BI;
                  rGKBTGAKUREIBO_I.MENJO_KYOKA_BI := rGTG1.MENJO_KYOKA_BI;
                  rGKBTGAKUREIBO_I.MENJO_JIYU_CD := rGTG1.MENJO_JIYU_CD;
                  rGKBTGAKUREIBO_I.MENJO_JIYU := rGTG1.MENJO_JIYU;
                  rGKBTGAKUREIBO_I.MENJO_KAISI_BI := rGTG1.MENJO_KAISI_BI;
                  rGKBTGAKUREIBO_I.MENJO_SYURYO_BI := rGTG1.MENJO_SYURYO_BI;
                  rGKBTGAKUREIBO_I.MENJO_NENSU := rGTG1.MENJO_NENSU;
                  rGKBTGAKUREIBO_I.MENJO_FUKUGAKU_BI := rGTG1.MENJO_FUKUGAKU_BI;
                  rGKBTGAKUREIBO_I.IDO_BI1 := rGTG1.IDO_BI1;
                  rGKBTGAKUREIBO_I.IDO_JIYU1 := rGTG1.IDO_JIYU1;
                  rGKBTGAKUREIBO_I.IDO_BI2 := rGTG1.IDO_BI2;
                  rGKBTGAKUREIBO_I.IDO_JIYU2 := rGTG1.IDO_JIYU2;
                  rGKBTGAKUREIBO_I.IDO_BI3 := rGTG1.IDO_BI3;
                  rGKBTGAKUREIBO_I.IDO_JIYU3 := rGTG1.IDO_JIYU3;
                  rGKBTGAKUREIBO_I.IDO_BI4 := rGTG1.IDO_BI4;
                  rGKBTGAKUREIBO_I.IDO_JIYU4 := rGTG1.IDO_JIYU4;
                  rGKBTGAKUREIBO_I.IDO_BI5 := rGTG1.IDO_BI5;
                  rGKBTGAKUREIBO_I.IDO_JIYU5 := rGTG1.IDO_JIYU5;
                  rGKBTGAKUREIBO_I.IDO_BI6 := rGTG1.IDO_BI6;
                  rGKBTGAKUREIBO_I.IDO_JIYU6 := rGTG1.IDO_JIYU6;
                  rGKBTGAKUREIBO_I.IDO_BI7 := rGTG1.IDO_BI7;
                  rGKBTGAKUREIBO_I.IDO_JIYU7 := rGTG1.IDO_JIYU7;
                  rGKBTGAKUREIBO_I.IDO_BI8 := rGTG1.IDO_BI8;
                  rGKBTGAKUREIBO_I.IDO_JIYU8 := rGTG1.IDO_JIYU8;
                  rGKBTGAKUREIBO_I.IDO_BI9 := rGTG1.IDO_BI9;
                  rGKBTGAKUREIBO_I.IDO_JIYU9 := rGTG1.IDO_JIYU9;
                  rGKBTGAKUREIBO_I.IDO_BI10 := rGTG1.IDO_BI10;
                  rGKBTGAKUREIBO_I.IDO_JIYU10 := rGTG1.IDO_JIYU10;
                  rGKBTGAKUREIBO_I.SYS_SAKUSEIBI := rGTG1.SYS_SAKUSEIBI;
                  rGKBTGAKUREIBO_I.SYS_KOSHINBI := g_nDATE;
                  rGKBTGAKUREIBO_I.SYS_JIKAN := g_nTIME;
                  rGKBTGAKUREIBO_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                  rGKBTGAKUREIBO_I.SYS_TANMATU_NO := g_sWSNUM;
                  rGKBTGAKUREIBO_I.GAKUNEN := rGTG1.GAKUNEN;
                  rGKBTGAKUREIBO_I.SHORIBI := g_nDATE;
                  rGKBTGAKUREIBO_I.SHUGAKU := rGTG1.SHUGAKU;
                  rGKBTGAKUREIBO_I.IDOJIKO := rGTG1.IDOJIKO;
                  rGKBTGAKUREIBO_I.CHOHYO_NO := rGTG1.CHOHYO_NO;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.SYOGAKO_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rGTG1.SYOGAKO_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rGTG1.TYUGAKO_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rGTG1.TYUGAKO_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_GAKUNEN := rGTG1.KUIKIGAI_TAIGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_GAKUNEN := rGTG1.YOGOGAKO_TAIGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.GAKKO_KBN_CD := rGTG1.GAKKO_KBN_CD;
                  rGKBTGAKUREIBO_I.GAKUKYU_CD := rGTG1.GAKUKYU_CD;
                  rGKBTGAKUREIBO_I.SEIBETSU := rGTG1.SEIBETSU;
                  rGKBTGAKUREIBO_I.JOTAI := rGTG1.JOTAI;
                  rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_KBN := rGTG1.TENNYUMAE_GAKKO_KBN;
                  rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_CD := rGTG1.TENNYUMAE_GAKKO_CD;
                  rGKBTGAKUREIBO_I.TENNYUMAE_GAKUNEN := rGTG1.TENNYUMAE_GAKUNEN;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_FLG := rGTG1.GENKYURYUCHI_FLG;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_KETTEI_BI := rGTG1.GENKYURYUCHI_KETTEI_BI;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_KAISI_BI := rGTG1.GENKYURYUCHI_KAISI_BI;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_SYURYOBI := rGTG1.GENKYURYUCHI_SYURYOBI;
                  rGKBTGAKUREIBO_I.GENKYURYUCHI_RIYU := rGTG1.GENKYURYUCHI_RIYU;
                  IF rDATA.NOW_GAKUNEN = 0 THEN
                    rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                    rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rGTG1.SHITEI_SYOGAKO_CD;
                  ELSE
                    NULL;
                  END IF;
                  IF rDATA.NOW_GAKUNEN = 0 THEN
                    rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rGTG1.SHITEI_TYUGAKO_CD;
                  ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                    rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.HENKO_GAKUNEN_SYOGAKO := rGTG1.HENKO_GAKUNEN_SYOGAKO;
                  rGKBTGAKUREIBO_I.HENKO_GAKUNEN_TYUGAKO := rGTG1.HENKO_GAKUNEN_TYUGAKO;
                  rGKBTGAKUREIBO_I.HENKO_SHINSEI_BI := rGTG1.HENKO_SHINSEI_BI;
                  rGKBTGAKUREIBO_I.HENKO_KYOKA_BI := rGTG1.HENKO_KYOKA_BI;
                  rGKBTGAKUREIBO_I.HENKO_KBN := rGTG1.HENKO_KBN;
                  rGKBTGAKUREIBO_I.HENKO_KAISI_BI := rGTG1.HENKO_KAISI_BI;
                  rGKBTGAKUREIBO_I.HENKO_SYURYO_BI := rGTG1.HENKO_SYURYO_BI;
                  rGKBTGAKUREIBO_I.HENKO_KYOKA_RIYU := rGTG1.HENKO_KYOKA_RIYU;
                  rGKBTGAKUREIBO_I.HENKO_JIYU := rGTG1.HENKO_JIYU;
                  rGKBTGAKUREIBO_I.HENKO_HUKYOKA_RIYU := rGTG1.HENKO_HUKYOKA_RIYU;
                  rGKBTGAKUREIBO_I.KIBO_GAKKO_KBN_CD := rGTG1.KIBO_GAKKO_KBN_CD;
                  rGKBTGAKUREIBO_I.KIBO_SYOGAKKO_CD := rGTG1.KIBO_SYOGAKKO_CD;
                  rGKBTGAKUREIBO_I.KIBO_TYUGAKKO_CD := rGTG1.KIBO_TYUGAKKO_CD;
                  rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_SYOGAKO := rGTG1.KIBO_UKETSUKE_BI_SYOGAKO;
                  rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_TYUGAKO := rGTG1.KIBO_UKETSUKE_BI_TYUGAKO;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_FLG := rGTG1.KUIKIGAISHUGAKU_FLG;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SHINSEI_BI := rGTG1.KUIKIGAISHUGAKU_SHINSEI_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_BI := rGTG1.KUIKIGAISHUGAKU_KYOKA_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KAISI_BI := rGTG1.KUIKIGAISHUGAKU_KAISI_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SYURYO_BI := rGTG1.KUIKIGAISHUGAKU_SYURYO_BI;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_JIYU := rGTG1.KUIKIGAISHUGAKU_JIYU;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_KYOKA_RIYU;
                  rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_HUKYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_HUKYOKA_RIYU;
                  rGKBTGAKUREIBO_I.HUSHUGAKU_KAISI_BI := rGTG1.HUSHUGAKU_KAISI_BI;
                  rGKBTGAKUREIBO_I.HUSHUGAKU_SYURYO_BI := rGTG1.HUSHUGAKU_SYURYO_BI;
                  rGKBTGAKUREIBO_I.HUSHUGAKU_RIYU := rGTG1.HUSHUGAKU_RIYU;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_CD := rGTG1.KUNISHIRITSU_CD;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_NYUGAKU_BI := rGTG1.KUNISHIRITSU_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_BI := rGTG1.KUNISHIRITSU_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_BI := rGTG1.KUNISHIRITSU_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_BI := rGTG1.KUNISHIRITSU_TAIGAKU_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TAIGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_SOTSUGYO_BI := rGTG1.KUNISHIRITSU_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_KAISI_BI := rGTG1.KUNISHIRITSU_KAISI_BI;
                  rGKBTGAKUREIBO_I.KUNISHIRITSU_SYURYO_BI := rGTG1.KUNISHIRITSU_SYURYO_BI;
                  rGKBTGAKUREIBO_I.TSUSHOMEI_KANA := rGTG1.TSUSHOMEI_KANA;
                  rGKBTGAKUREIBO_I.TSUSHOMEI_KANJI := rGTG1.TSUSHOMEI_KANJI;
                  rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANA := rGTG1.HOGOSHA_TSUSHOMEI_KANA;
                  rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANJI := rGTG1.HOGOSHA_TSUSHOMEI_KANJI;
                  rGKBTGAKUREIBO_I.GRB_HENKO_TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                  rGKBTGAKUREIBO_I.GRB_HENKO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                  nRTN := KKAPK0030.FCTGetR('GKB', '00TOHAIGO_HENKOJIYU', '0000', 0, aPRM);
                  IF aPRM(1) = '1' THEN
                    rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 14;
                  ELSIF aPRM(1) = '2' THEN
                    rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 99;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.BIKO := REPLACE(rGTG1.BIKO, chr(13)||chr(10),'#') || '新設・統廃合一括処理による学校変更';
                  rGKBTGAKUREIBO_I.IDO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                  rGKBTGAKUREIBO_I.TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                  rGKBTGAKUREIBO_I.SHINSEI_KANRI_RENBAN := rGTG1.SHINSEI_KANRI_RENBAN;
                  rGKBTGAKUREIBO_I.IDOJI_ATENA_RIREKI_RENBAN := rGTG1.IDOJI_ATENA_RIREKI_RENBAN;
                  rGKBTGAKUREIBO_I.HOGOSYA_IDOJI_RIREKI_RENBAN := rGTG1.HOGOSYA_IDOJI_RIREKI_RENBAN;
                  IF rDATA.NOW_GAKUNEN = 0 THEN
                    rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rDATA.NEW_GAKKOKU_CD;
                  ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                    rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rGTG1.SHOGAKKOKU_CD;
                  ELSE
                    NULL;
                  END IF;
                  IF rDATA.NOW_GAKUNEN = 0 THEN
                    rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rGTG1.CHUGAKKOKU_CD;
                  ELSIF rDATA.NOW_GAKUNEN = 6 THEN
                    rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rDATA.NEW_GAKKOKU_CD;
                  ELSE
                    NULL;
                  END IF;
                  rGKBTGAKUREIBO_I.SAKUJO_FLG := 0;
                  BEGIN
                    SELECT
                      BUKACODE
                    INTO sBUKACODE
                    FROM
                      KKNTWS
                    WHERE
                      KKNTWS.WSNUM = g_sWSNUM;
                  EXCEPTION
                    WHEN OTHERS THEN
                      sBUKACODE := NULL;
                  END;
                  BEGIN
                    SELECT
                      BUKANAME
                    INTO rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO
                    FROM
                      KKNTBK
                    WHERE
                      BUKACODE = sBUKACODE
                      AND KKNTBK.YUKOKIKANFR = (
                                                 SELECT MAX(YUKOKIKANFR) FROM KKNTBK WHERE BUKACODE = sBUKACODE
                                                );
                  EXCEPTION
                    WHEN OTHERS THEN
                      rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO := NULL;
                  END;
                  INSERT INTO GKBTGAKUREIBO VALUES rGKBTGAKUREIBO_I;
                ELSE
                  NULL;
                END IF;
              ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                --学齢簿、就学履歴の現最新履歴の最新区分を変更する。
                UPDATE GKBTGAKUREIBO
                SET SAISHIN_KBN = 1,        --最新区分固定値「1」
                    SYS_KOSHINBI = g_nDATE, --更新日
                    SYS_JIKAN = g_nTIME,    --システム時間
                    SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                    SYS_TANMATU_NO = g_sWSNUM
                WHERE KOJIN_NO = rDATA.KOJIN_NO
                  AND SAISHIN_KBN = 0;
                UPDATE GKBTSHUGAKURIREKI
                SET SAISHIN_FLG = 1,        --最新フラグ固定値「1」
                    SYS_KOSHINBI = g_nDATE, --更新日
                    SYS_JIKAN = g_nTIME,    --システム時間
                    SYS_SHOKUINKOJIN_NO = g_sTANTOCODE, --更新職員宛名番号
                    SYS_TANMATU_NO = g_sWSNUM --更新端末番号
                WHERE KOJIN_NO = rDATA.KOJIN_NO
                  AND SAISHIN_FLG = 0;
                --学齢簿に転学の履歴を作成する。 ※新入学児童以外の場合の転学時
                rGKBTGAKUREIBO_I.KOJIN_NO := rDATA.KOJIN_NO;
                nGKBTGAKUREIBOSEQ := nGKBTGAKUREIBOSEQ + 10;
                rGKBTGAKUREIBO_I.RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                rGKBTGAKUREIBO_I.RIREKI_RENBAN_EDA := 0;
                rGKBTGAKUREIBO_I.GENZON_KBN := rGTG1.GENZON_KBN;
                rGKBTGAKUREIBO_I.SAISHIN_KBN := 1;
                rGKBTGAKUREIBO_I.ZO_JIYU_CD := rGTG1.ZO_JIYU_CD;
                rGKBTGAKUREIBO_I.ZO_NENGAPI := rGTG1.ZO_NENGAPI;
                rGKBTGAKUREIBO_I.GEN_JIYU_CD := rGTG1.GEN_JIYU_CD;
                rGKBTGAKUREIBO_I.GEN_NENGAPI := rGTG1.GEN_NENGAPI;
                rGKBTGAKUREIBO_I.ZOKUGARA1 := rGTG1.ZOKUGARA1;
                rGKBTGAKUREIBO_I.ZOKUGARA2 := rGTG1.ZOKUGARA2;
                rGKBTGAKUREIBO_I.ZOKUGARA3 := rGTG1.ZOKUGARA3;
                rGKBTGAKUREIBO_I.ZOKUGARA4 := rGTG1.ZOKUGARA4;
                rGKBTGAKUREIBO_I.HOGOSYA_KOJIN_NO := rGTG1.HOGOSYA_KOJIN_NO;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA1 := rGTG1.HOGOSYA_ZOKUGARA1;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA2 := rGTG1.HOGOSYA_ZOKUGARA2;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA3 := rGTG1.HOGOSYA_ZOKUGARA3;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA4 := rGTG1.HOGOSYA_ZOKUGARA4;
                rGKBTGAKUREIBO_I.SYOGAKO_CD := rGTG1.SYOGAKO_CD;
                rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := rGTG1.SYOGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := rGTG1.SYOGAKO_TENNYUGAKU_BI;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := rGTG1.SYOGAKO_TENGAKU_BI;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := rGTG1.SYOGAKO_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.TYUGAKO_CD := rGTG1.TYUGAKO_CD;
                rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := rGTG1.TYUGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := rGTG1.TYUGAKO_TENNYUGAKU_BI;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := rGTG1.TYUGAKO_TENGAKU_BI;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := rGTG1.TYUGAKO_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI1 := rGTG1.TOKUSOKU_BI1;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO1 := rGTG1.TOKUSOKU_NAIYO1;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU1 := rGTG1.TOKUSOKU_JIYU1;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI1 := rGTG1.TOKUSOKU_JURI_BI1;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI2 := rGTG1.TOKUSOKU_BI2;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO2 := rGTG1.TOKUSOKU_NAIYO2;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU2 := rGTG1.TOKUSOKU_JIYU2;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI2 := rGTG1.TOKUSOKU_JURI_BI2;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI3 := rGTG1.TOKUSOKU_BI3;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO3 := rGTG1.TOKUSOKU_NAIYO3;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU3 := rGTG1.TOKUSOKU_JIYU3;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI3 := rGTG1.TOKUSOKU_JURI_BI3;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI4 := rGTG1.TOKUSOKU_BI4;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO4 := rGTG1.TOKUSOKU_NAIYO4;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU4 := rGTG1.TOKUSOKU_JIYU4;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI4 := rGTG1.TOKUSOKU_JURI_BI4;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI5 := rGTG1.TOKUSOKU_BI5;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO5 := rGTG1.TOKUSOKU_NAIYO5;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU5 := rGTG1.TOKUSOKU_JIYU5;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI5 := rGTG1.TOKUSOKU_JURI_BI5;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI6 := rGTG1.TOKUSOKU_BI6;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO6 := rGTG1.TOKUSOKU_NAIYO6;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU6 := rGTG1.TOKUSOKU_JIYU6;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI6 := rGTG1.TOKUSOKU_JURI_BI6;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI7 := rGTG1.TOKUSOKU_BI7;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO7 := rGTG1.TOKUSOKU_NAIYO7;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU7 := rGTG1.TOKUSOKU_JIYU7;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI7 := rGTG1.TOKUSOKU_JURI_BI7;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI8 := rGTG1.TOKUSOKU_BI8;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO8 := rGTG1.TOKUSOKU_NAIYO8;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU8 := rGTG1.TOKUSOKU_JIYU8;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI8 := rGTG1.TOKUSOKU_JURI_BI8;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI9 := rGTG1.TOKUSOKU_BI9;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO9 := rGTG1.TOKUSOKU_NAIYO9;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU9 := rGTG1.TOKUSOKU_JIYU9;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI9 := rGTG1.TOKUSOKU_JURI_BI9;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI10 := rGTG1.TOKUSOKU_BI10;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO10 := rGTG1.TOKUSOKU_NAIYO10;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU10 := rGTG1.TOKUSOKU_JIYU10;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI10 := rGTG1.TOKUSOKU_JURI_BI10;
                rGKBTGAKUREIBO_I.KUIKIGAI_CD := rGTG1.KUIKIGAI_CD;
                rGKBTGAKUREIBO_I.KUIKIGAI_SETISYA := rGTG1.KUIKIGAI_SETISYA;
                rGKBTGAKUREIBO_I.KUIKIGAI_NYUGAKU_BI := rGTG1.KUIKIGAI_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_BI := rGTG1.KUIKIGAI_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_BI := rGTG1.KUIKIGAI_TENGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_BI := rGTG1.KUIKIGAI_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_SOTSUGYO_BI := rGTG1.KUIKIGAI_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_CD := rGTG1.YOGOGAKO_CD;
                rGKBTGAKUREIBO_I.YOGOGAKO_SETISYA := rGTG1.YOGOGAKO_SETISYA;
                rGKBTGAKUREIBO_I.YOGOGAKO_NYUGAKU_BI := rGTG1.YOGOGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_BI := rGTG1.YOGOGAKO_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_BI := rGTG1.YOGOGAKO_TENGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_BI := rGTG1.YOGOGAKO_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_SOTSUGYO_BI := rGTG1.YOGOGAKO_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.YUYO_KYOKA_BI := rGTG1.YUYO_KYOKA_BI;
                rGKBTGAKUREIBO_I.YUYO_JIYU_CD := rGTG1.YUYO_JIYU_CD;
                rGKBTGAKUREIBO_I.YUYO_JIYU := rGTG1.YUYO_JIYU;
                rGKBTGAKUREIBO_I.YUYO_KAISI_BI := rGTG1.YUYO_KAISI_BI;
                rGKBTGAKUREIBO_I.YUYO_SYURYO_BI := rGTG1.YUYO_SYURYO_BI;
                rGKBTGAKUREIBO_I.YUYO_NENSU := rGTG1.YUYO_NENSU;
                rGKBTGAKUREIBO_I.YUYO_FUKUGAKU_BI := rGTG1.YUYO_FUKUGAKU_BI;
                rGKBTGAKUREIBO_I.MENJO_KYOKA_BI := rGTG1.MENJO_KYOKA_BI;
                rGKBTGAKUREIBO_I.MENJO_JIYU_CD := rGTG1.MENJO_JIYU_CD;
                rGKBTGAKUREIBO_I.MENJO_JIYU := rGTG1.MENJO_JIYU;
                rGKBTGAKUREIBO_I.MENJO_KAISI_BI := rGTG1.MENJO_KAISI_BI;
                rGKBTGAKUREIBO_I.MENJO_SYURYO_BI := rGTG1.MENJO_SYURYO_BI;
                rGKBTGAKUREIBO_I.MENJO_NENSU := rGTG1.MENJO_NENSU;
                rGKBTGAKUREIBO_I.MENJO_FUKUGAKU_BI := rGTG1.MENJO_FUKUGAKU_BI;
                rGKBTGAKUREIBO_I.IDO_BI1 := rGTG1.IDO_BI1;
                rGKBTGAKUREIBO_I.IDO_JIYU1 := rGTG1.IDO_JIYU1;
                rGKBTGAKUREIBO_I.IDO_BI2 := rGTG1.IDO_BI2;
                rGKBTGAKUREIBO_I.IDO_JIYU2 := rGTG1.IDO_JIYU2;
                rGKBTGAKUREIBO_I.IDO_BI3 := rGTG1.IDO_BI3;
                rGKBTGAKUREIBO_I.IDO_JIYU3 := rGTG1.IDO_JIYU3;
                rGKBTGAKUREIBO_I.IDO_BI4 := rGTG1.IDO_BI4;
                rGKBTGAKUREIBO_I.IDO_JIYU4 := rGTG1.IDO_JIYU4;
                rGKBTGAKUREIBO_I.IDO_BI5 := rGTG1.IDO_BI5;
                rGKBTGAKUREIBO_I.IDO_JIYU5 := rGTG1.IDO_JIYU5;
                rGKBTGAKUREIBO_I.IDO_BI6 := rGTG1.IDO_BI6;
                rGKBTGAKUREIBO_I.IDO_JIYU6 := rGTG1.IDO_JIYU6;
                rGKBTGAKUREIBO_I.IDO_BI7 := rGTG1.IDO_BI7;
                rGKBTGAKUREIBO_I.IDO_JIYU7 := rGTG1.IDO_JIYU7;
                rGKBTGAKUREIBO_I.IDO_BI8 := rGTG1.IDO_BI8;
                rGKBTGAKUREIBO_I.IDO_JIYU8 := rGTG1.IDO_JIYU8;
                rGKBTGAKUREIBO_I.IDO_BI9 := rGTG1.IDO_BI9;
                rGKBTGAKUREIBO_I.IDO_JIYU9 := rGTG1.IDO_JIYU9;
                rGKBTGAKUREIBO_I.IDO_BI10 := rGTG1.IDO_BI10;
                rGKBTGAKUREIBO_I.IDO_JIYU10 := rGTG1.IDO_JIYU10;
                rGKBTGAKUREIBO_I.SYS_SAKUSEIBI := rGTG1.SYS_SAKUSEIBI;
                rGKBTGAKUREIBO_I.SYS_KOSHINBI := g_nDATE;
                rGKBTGAKUREIBO_I.SYS_JIKAN := g_nTIME;
                rGKBTGAKUREIBO_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                rGKBTGAKUREIBO_I.SYS_TANMATU_NO := g_sWSNUM;
                rGKBTGAKUREIBO_I.GAKUNEN := rGTG1.GAKUNEN;
                rGKBTGAKUREIBO_I.SHORIBI := g_nDATE;
                rGKBTGAKUREIBO_I.SHUGAKU := rGTG1.SHUGAKU;
                rGKBTGAKUREIBO_I.IDOJIKO := rGTG1.IDOJIKO;
                rGKBTGAKUREIBO_I.CHOHYO_NO := rGTG1.CHOHYO_NO;
                rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.SYOGAKO_TENNYUGAKU_GAKUNEN;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rGTG1.SYOGAKO_TENGAKU_GAKUNEN;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rGTG1.TYUGAKO_TENNYUGAKU_GAKUNEN;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rGTG1.TYUGAKO_TENGAKU_GAKUNEN;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_GAKUNEN := rGTG1.KUIKIGAI_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_GAKUNEN := rGTG1.YOGOGAKO_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.GAKKO_KBN_CD := rGTG1.GAKKO_KBN_CD;
                rGKBTGAKUREIBO_I.GAKUKYU_CD := rGTG1.GAKUKYU_CD;
                rGKBTGAKUREIBO_I.SEIBETSU := rGTG1.SEIBETSU;
                rGKBTGAKUREIBO_I.JOTAI := rGTG1.JOTAI;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_KBN := rGTG1.TENNYUMAE_GAKKO_KBN;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_CD := rGTG1.TENNYUMAE_GAKKO_CD;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKUNEN := rGTG1.TENNYUMAE_GAKUNEN;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_FLG := rGTG1.GENKYURYUCHI_FLG;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_KETTEI_BI := rGTG1.GENKYURYUCHI_KETTEI_BI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_KAISI_BI := rGTG1.GENKYURYUCHI_KAISI_BI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_SYURYOBI := rGTG1.GENKYURYUCHI_SYURYOBI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_RIYU := rGTG1.GENKYURYUCHI_RIYU;
                rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rGTG1.SHITEI_SYOGAKO_CD;
                rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rGTG1.SHITEI_TYUGAKO_CD;
                rGKBTGAKUREIBO_I.HENKO_GAKUNEN_SYOGAKO := rGTG1.HENKO_GAKUNEN_SYOGAKO;
                rGKBTGAKUREIBO_I.HENKO_GAKUNEN_TYUGAKO := rGTG1.HENKO_GAKUNEN_TYUGAKO;
                rGKBTGAKUREIBO_I.HENKO_SHINSEI_BI := rGTG1.HENKO_SHINSEI_BI;
                rGKBTGAKUREIBO_I.HENKO_KYOKA_BI := rGTG1.HENKO_KYOKA_BI;
                rGKBTGAKUREIBO_I.HENKO_KBN := rGTG1.HENKO_KBN;
                rGKBTGAKUREIBO_I.HENKO_KAISI_BI := rGTG1.HENKO_KAISI_BI;
                rGKBTGAKUREIBO_I.HENKO_SYURYO_BI := rGTG1.HENKO_SYURYO_BI;
                rGKBTGAKUREIBO_I.HENKO_KYOKA_RIYU := rGTG1.HENKO_KYOKA_RIYU;
                rGKBTGAKUREIBO_I.HENKO_JIYU := rGTG1.HENKO_JIYU;
                rGKBTGAKUREIBO_I.HENKO_HUKYOKA_RIYU := rGTG1.HENKO_HUKYOKA_RIYU;
                rGKBTGAKUREIBO_I.KIBO_GAKKO_KBN_CD := rGTG1.KIBO_GAKKO_KBN_CD;
                rGKBTGAKUREIBO_I.KIBO_SYOGAKKO_CD := rGTG1.KIBO_SYOGAKKO_CD;
                rGKBTGAKUREIBO_I.KIBO_TYUGAKKO_CD := rGTG1.KIBO_TYUGAKKO_CD;
                rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_SYOGAKO := rGTG1.KIBO_UKETSUKE_BI_SYOGAKO;
                rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_TYUGAKO := rGTG1.KIBO_UKETSUKE_BI_TYUGAKO;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_FLG := rGTG1.KUIKIGAISHUGAKU_FLG;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SHINSEI_BI := rGTG1.KUIKIGAISHUGAKU_SHINSEI_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_BI := rGTG1.KUIKIGAISHUGAKU_KYOKA_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KAISI_BI := rGTG1.KUIKIGAISHUGAKU_KAISI_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SYURYO_BI := rGTG1.KUIKIGAISHUGAKU_SYURYO_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_JIYU := rGTG1.KUIKIGAISHUGAKU_JIYU;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_KYOKA_RIYU;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_HUKYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_HUKYOKA_RIYU;
                rGKBTGAKUREIBO_I.HUSHUGAKU_KAISI_BI := rGTG1.HUSHUGAKU_KAISI_BI;
                rGKBTGAKUREIBO_I.HUSHUGAKU_SYURYO_BI := rGTG1.HUSHUGAKU_SYURYO_BI;
                rGKBTGAKUREIBO_I.HUSHUGAKU_RIYU := rGTG1.HUSHUGAKU_RIYU;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_CD := rGTG1.KUNISHIRITSU_CD;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_NYUGAKU_BI := rGTG1.KUNISHIRITSU_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_BI := rGTG1.KUNISHIRITSU_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_BI := rGTG1.KUNISHIRITSU_TENGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_BI := rGTG1.KUNISHIRITSU_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_SOTSUGYO_BI := rGTG1.KUNISHIRITSU_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_KAISI_BI := rGTG1.KUNISHIRITSU_KAISI_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_SYURYO_BI := rGTG1.KUNISHIRITSU_SYURYO_BI;
                rGKBTGAKUREIBO_I.TSUSHOMEI_KANA := rGTG1.TSUSHOMEI_KANA;
                rGKBTGAKUREIBO_I.TSUSHOMEI_KANJI := rGTG1.TSUSHOMEI_KANJI;
                rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANA := rGTG1.HOGOSHA_TSUSHOMEI_KANA;
                rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANJI := rGTG1.HOGOSHA_TSUSHOMEI_KANJI;
                rGKBTGAKUREIBO_I.GRB_HENKO_TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                rGKBTGAKUREIBO_I.GRB_HENKO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                nRTN := KKAPK0030.FCTGetR('GKB', '00TOHAIGO_HENKOJIYU', '0000', 0, aPRM);
                IF aPRM(1) = '1' THEN
                  rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 14;
                ELSIF aPRM(1) = '2' THEN
                  rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 99;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.BIKO := REPLACE(rGTG1.BIKO, chr(13)||chr(10),'#') || '新設・統廃合一括処理による転学';
                rGKBTGAKUREIBO_I.IDO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                rGKBTGAKUREIBO_I.TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                rGKBTGAKUREIBO_I.SHINSEI_KANRI_RENBAN := rGTG1.SHINSEI_KANRI_RENBAN;
                rGKBTGAKUREIBO_I.IDOJI_ATENA_RIREKI_RENBAN := rGTG1.IDOJI_ATENA_RIREKI_RENBAN;
                rGKBTGAKUREIBO_I.HOGOSYA_IDOJI_RIREKI_RENBAN := rGTG1.HOGOSYA_IDOJI_RIREKI_RENBAN;
                rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rGTG1.SHOGAKKOKU_CD;
                rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rGTG1.CHUGAKKOKU_CD;
                rGKBTGAKUREIBO_I.SAKUJO_FLG := 0;
                BEGIN
                  SELECT
                    BUKACODE
                  INTO sBUKACODE
                  FROM
                    KKNTWS
                  WHERE
                    KKNTWS.WSNUM = g_sWSNUM;
                EXCEPTION
                  WHEN OTHERS THEN
                    sBUKACODE := NULL;
                END;
                BEGIN
                  SELECT
                    BUKANAME
                  INTO rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO
                  FROM
                    KKNTBK
                  WHERE
                    BUKACODE = sBUKACODE
                    AND KKNTBK.YUKOKIKANFR = (
                                               SELECT MAX(YUKOKIKANFR) FROM KKNTBK WHERE BUKACODE = sBUKACODE
                                              );
                EXCEPTION
                  WHEN OTHERS THEN
                    rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO := NULL;
                END;
                INSERT INTO GKBTGAKUREIBO VALUES rGKBTGAKUREIBO_I;
                --就学履歴に転学の履歴を作成する。 ※転学時
                rGKBTSHUGAKURIREKI_I.KOJIN_NO := rDATA.KOJIN_NO;
                rGKBTSHUGAKURIREKI_I.NENDO := TO_NUMBER(SUBSTR(KKAPK0020.FNENDOHENKAN(g_vTENGAKUYMD), 1, 4));
                rGKBTSHUGAKURIREKI_I.KOJIN_RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                nGKBTSHUGAKURIREKISEQ := nGKBTSHUGAKURIREKISEQ + 10;
                rGKBTSHUGAKURIREKI_I.SHUGAKU_RIREKI_RENBAN := nGKBTSHUGAKURIREKISEQ;
                rGKBTSHUGAKURIREKI_I.SAISHIN_FLG := 1;
                rGKBTSHUGAKURIREKI_I.S_CD := rGTR1.S_CD;
                rGKBTSHUGAKURIREKI_I.S_NYUGAKU_BI := rGTR1.S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.S_TENNYU_BI := rGTR1.S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.S_TENNYU_GAKUNEN := rGTR1.S_TENNYU_GAKUNEN;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(g_vTENGAKUYMD);
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := rGTR1.S_TENGAKU_BI;
                ELSE
                  NULL;
                END IF;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := rGTR1.S_TENGAKU_GAKUNEN;
                ELSE
                  NULL;
                END IF;
                rGKBTSHUGAKURIREKI_I.S_TAIGAKU_BI := rGTR1.S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.S_TAIGAKU_GAKUNEN := rGTR1.S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.S_SOTSUGYO_BI := rGTR1.S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.T_CD := rGTR1.T_CD;
                rGKBTSHUGAKURIREKI_I.T_NYUGAKU_BI := rGTR1.T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.T_TENNYU_BI := rGTR1.T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.T_TENNYU_GAKUNEN := rGTR1.T_TENNYU_GAKUNEN;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := rGTR1.T_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := rGTR1.T_TENGAKU_GAKUNEN;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := KKAPK0020.FNENDOHENKAN(g_vTENGAKUYMD);
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := rDATA.NOW_GAKUNEN;
                ELSE
                  NULL;
                END IF;
                rGKBTSHUGAKURIREKI_I.T_TAIGAKU_BI := rGTR1.T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.T_TAIGAKU_GAKUNEN := rGTR1.T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.T_SOTSUGYO_BI := rGTR1.T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_BU_CD := rGTR1.SHIEN_BU_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_CD := rGTR1.SHIEN_S_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_HUKUSEKI_CD := rGTR1.SHIEN_S_HUKUSEKI_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_NYUGAKU_BI := rGTR1.SHIEN_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_BI := rGTR1.SHIEN_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_GAKUNEN := rGTR1.SHIEN_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_BI := rGTR1.SHIEN_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_GAKUNEN := rGTR1.SHIEN_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_BI := rGTR1.SHIEN_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_GAKUNEN := rGTR1.SHIEN_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_SOTSUGYO_BI := rGTR1.SHIEN_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_CD := rGTR1.SHIEN_T_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_HUKUSEKI_CD := rGTR1.SHIEN_T_HUKUSEKI_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_NYUGAKU_BI := rGTR1.SHIEN_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_BI := rGTR1.SHIEN_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_GAKUNEN := rGTR1.SHIEN_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_BI := rGTR1.SHIEN_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_GAKUNEN := rGTR1.SHIEN_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_BI := rGTR1.SHIEN_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_GAKUNEN := rGTR1.SHIEN_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_SOTSUGYO_BI := rGTR1.SHIEN_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_CD := rGTR1.KUIKIGAI_S_CD;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_S_KAISHI_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_NYUGAKU_BI := rGTR1.KUIKIGAI_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_BI := rGTR1.KUIKIGAI_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_BI := rGTR1.KUIKIGAI_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_BI := rGTR1.KUIKIGAI_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SOTSUGYO_BI := rGTR1.KUIKIGAI_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_BI := rGTR1.KUIKIGAI_S_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SHURYO_BI := rGTR1.KUIKIGAI_S_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAIJO_BI := rGTR1.KUIKIGAI_S_KAIJO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_CD := rGTR1.KUIKIGAI_T_CD;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_T_KAISHI_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_NYUGAKU_BI := rGTR1.KUIKIGAI_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_BI := rGTR1.KUIKIGAI_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_BI := rGTR1.KUIKIGAI_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_BI := rGTR1.KUIKIGAI_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SOTSUGYO_BI := rGTR1.KUIKIGAI_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_BI := rGTR1.KUIKIGAI_T_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SHURYO_BI := rGTR1.KUIKIGAI_T_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAIJO_BI := rGTR1.KUIKIGAI_T_KAIJO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_CD := rGTR1.KUNISHIRITSU_S_CD;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_NYUGAKU_BI := rGTR1.KUNISHIRITSU_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_BI := rGTR1.KUNISHIRITSU_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_BI := rGTR1.KUNISHIRITSU_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_BI := rGTR1.KUNISHIRITSU_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_KAISHI_BI := rGTR1.KUNISHIRITSU_S_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SHURYO_BI := rGTR1.KUNISHIRITSU_S_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_CD := rGTR1.KUNISHIRITSU_T_CD;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_NYUGAKU_BI := rGTR1.KUNISHIRITSU_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_BI := rGTR1.KUNISHIRITSU_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_BI := rGTR1.KUNISHIRITSU_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_BI := rGTR1.KUNISHIRITSU_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_KAISHI_BI := rGTR1.KUNISHIRITSU_T_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SHURYO_BI := rGTR1.KUNISHIRITSU_T_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.SAKUJO_FLG := 0;
                rGKBTSHUGAKURIREKI_I.SYS_SAKUSEIBI := g_nDATE;
                rGKBTSHUGAKURIREKI_I.SYS_KOSHINBI := 0;
                rGKBTSHUGAKURIREKI_I.SYS_JIKAN := g_nTIME;
                rGKBTSHUGAKURIREKI_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                rGKBTSHUGAKURIREKI_I.SYS_TANMATU_NO := g_sWSNUM;
                INSERT INTO GKBTSHUGAKURIREKI VALUES rGKBTSHUGAKURIREKI_I;
                rGTG1 := rGTG2;
                rGTR1 := rGTR2;
                --学齢簿、就学履歴の現最新履歴を取得し直す。
                BEGIN
                  SELECT *
                  --学齢簿現最新履歴
                  INTO rGTG1
                  FROM GKBTGAKUREIBO GTG
                  WHERE GTG.KOJIN_NO = rDATA.KOJIN_NO
--  2024/11/23 YAMANI.OHARA UPDATE 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
--                    AND GTG.SAISHIN_KBN = 0
                    AND GTG.RIREKI_RENBAN = nGKBTGAKUREIBOSEQ
--  2024/11/23 YAMANI.OHARA UPDATE END
                    AND GTG.SAKUJO_FLG = 0;
                EXCEPTION
                  WHEN OTHERS THEN
                    rGTG1 := rGTG2;
                END;
                BEGIN
                  SELECT *
                  --就学履歴現最新履歴
                  INTO rGTR1
                  FROM GKBTSHUGAKURIREKI GTR
                  WHERE GTR.KOJIN_NO = rDATA.KOJIN_NO
--  2024/11/23 YAMANI.OHARA UPDATE 0.3.000.010:不具合 IT_GKB_00555対応　仕様変更　IT_GKB_00563　仕様変更　IT_GKB_00669
--                    AND GTR.SAISHIN_FLG = 0
                    AND GTR.KOJIN_RIREKI_RENBAN = nGKBTGAKUREIBOSEQ
          AND GTR.SHUGAKU_RIREKI_RENBAN = nGKBTSHUGAKURIREKISEQ
--  2024/11/23 YAMANI.OHARA UPDATE END
                    AND GTR.SAKUJO_FLG = 0;
                EXCEPTION
                  WHEN OTHERS THEN
                    rGTR1 := rGTR2;
                END;
                --学齢簿に転入学の履歴を作成する。 ※新入学児童以外の場合の転入学
                rGKBTGAKUREIBO_I.KOJIN_NO := rDATA.KOJIN_NO;
                nGKBTGAKUREIBOSEQ := nGKBTGAKUREIBOSEQ + 10;
                rGKBTGAKUREIBO_I.RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                rGKBTGAKUREIBO_I.RIREKI_RENBAN_EDA := 0;
                rGKBTGAKUREIBO_I.GENZON_KBN := rGTG1.GENZON_KBN;
                rGKBTGAKUREIBO_I.SAISHIN_KBN := 0;
                rGKBTGAKUREIBO_I.ZO_JIYU_CD := rGTG1.ZO_JIYU_CD;
                rGKBTGAKUREIBO_I.ZO_NENGAPI := rGTG1.ZO_NENGAPI;
                rGKBTGAKUREIBO_I.GEN_JIYU_CD := rGTG1.GEN_JIYU_CD;
                rGKBTGAKUREIBO_I.GEN_NENGAPI := rGTG1.GEN_NENGAPI;
                rGKBTGAKUREIBO_I.ZOKUGARA1 := rGTG1.ZOKUGARA1;
                rGKBTGAKUREIBO_I.ZOKUGARA2 := rGTG1.ZOKUGARA2;
                rGKBTGAKUREIBO_I.ZOKUGARA3 := rGTG1.ZOKUGARA3;
                rGKBTGAKUREIBO_I.ZOKUGARA4 := rGTG1.ZOKUGARA4;
                rGKBTGAKUREIBO_I.HOGOSYA_KOJIN_NO := rGTG1.HOGOSYA_KOJIN_NO;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA1 := rGTG1.HOGOSYA_ZOKUGARA1;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA2 := rGTG1.HOGOSYA_ZOKUGARA2;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA3 := rGTG1.HOGOSYA_ZOKUGARA3;
                rGKBTGAKUREIBO_I.HOGOSYA_ZOKUGARA4 := rGTG1.HOGOSYA_ZOKUGARA4;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := 0;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := 0;
                  rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := 0;
                  rGKBTGAKUREIBO_I.TYUGAKO_CD := rGTG1.TYUGAKO_CD;
                  rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := rGTG1.TYUGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := rGTG1.TYUGAKO_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := rGTG1.TYUGAKO_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := rGTG1.TYUGAKO_SOTSUGYO_BI;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_CD := rGTG1.SYOGAKO_CD;
                  rGKBTGAKUREIBO_I.SYOGAKO_NYUGAKU_BI := rGTG1.SYOGAKO_NYUGAKU_BI;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_BI := rGTG1.SYOGAKO_TENNYUGAKU_BI;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_BI := rGTG1.SYOGAKO_TENGAKU_BI;
                  rGKBTGAKUREIBO_I.SYOGAKO_SOTSUGYO_BI := rGTG1.SYOGAKO_SOTSUGYO_BI;
                  rGKBTGAKUREIBO_I.TYUGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTGAKUREIBO_I.TYUGAKO_NYUGAKU_BI := 0;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_BI := KKAPK0020.FNENDOHENKAN(TO_NUMBER(g_vTENGAKUYMD));
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_BI := 0;
                  rGKBTGAKUREIBO_I.TYUGAKO_SOTSUGYO_BI := 0;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI1 := rGTG1.TOKUSOKU_BI1;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO1 := rGTG1.TOKUSOKU_NAIYO1;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU1 := rGTG1.TOKUSOKU_JIYU1;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI1 := rGTG1.TOKUSOKU_JURI_BI1;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI2 := rGTG1.TOKUSOKU_BI2;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO2 := rGTG1.TOKUSOKU_NAIYO2;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU2 := rGTG1.TOKUSOKU_JIYU2;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI2 := rGTG1.TOKUSOKU_JURI_BI2;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI3 := rGTG1.TOKUSOKU_BI3;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO3 := rGTG1.TOKUSOKU_NAIYO3;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU3 := rGTG1.TOKUSOKU_JIYU3;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI3 := rGTG1.TOKUSOKU_JURI_BI3;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI4 := rGTG1.TOKUSOKU_BI4;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO4 := rGTG1.TOKUSOKU_NAIYO4;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU4 := rGTG1.TOKUSOKU_JIYU4;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI4 := rGTG1.TOKUSOKU_JURI_BI4;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI5 := rGTG1.TOKUSOKU_BI5;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO5 := rGTG1.TOKUSOKU_NAIYO5;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU5 := rGTG1.TOKUSOKU_JIYU5;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI5 := rGTG1.TOKUSOKU_JURI_BI5;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI6 := rGTG1.TOKUSOKU_BI6;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO6 := rGTG1.TOKUSOKU_NAIYO6;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU6 := rGTG1.TOKUSOKU_JIYU6;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI6 := rGTG1.TOKUSOKU_JURI_BI6;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI7 := rGTG1.TOKUSOKU_BI7;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO7 := rGTG1.TOKUSOKU_NAIYO7;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU7 := rGTG1.TOKUSOKU_JIYU7;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI7 := rGTG1.TOKUSOKU_JURI_BI7;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI8 := rGTG1.TOKUSOKU_BI8;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO8 := rGTG1.TOKUSOKU_NAIYO8;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU8 := rGTG1.TOKUSOKU_JIYU8;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI8 := rGTG1.TOKUSOKU_JURI_BI8;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI9 := rGTG1.TOKUSOKU_BI9;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO9 := rGTG1.TOKUSOKU_NAIYO9;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU9 := rGTG1.TOKUSOKU_JIYU9;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI9 := rGTG1.TOKUSOKU_JURI_BI9;
                rGKBTGAKUREIBO_I.TOKUSOKU_BI10 := rGTG1.TOKUSOKU_BI10;
                rGKBTGAKUREIBO_I.TOKUSOKU_NAIYO10 := rGTG1.TOKUSOKU_NAIYO10;
                rGKBTGAKUREIBO_I.TOKUSOKU_JIYU10 := rGTG1.TOKUSOKU_JIYU10;
                rGKBTGAKUREIBO_I.TOKUSOKU_JURI_BI10 := rGTG1.TOKUSOKU_JURI_BI10;
                rGKBTGAKUREIBO_I.KUIKIGAI_CD := rGTG1.KUIKIGAI_CD;
                rGKBTGAKUREIBO_I.KUIKIGAI_SETISYA := rGTG1.KUIKIGAI_SETISYA;
                rGKBTGAKUREIBO_I.KUIKIGAI_NYUGAKU_BI := rGTG1.KUIKIGAI_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_BI := rGTG1.KUIKIGAI_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_BI := rGTG1.KUIKIGAI_TENGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_BI := rGTG1.KUIKIGAI_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.KUIKIGAI_SOTSUGYO_BI := rGTG1.KUIKIGAI_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_CD := rGTG1.YOGOGAKO_CD;
                rGKBTGAKUREIBO_I.YOGOGAKO_SETISYA := rGTG1.YOGOGAKO_SETISYA;
                rGKBTGAKUREIBO_I.YOGOGAKO_NYUGAKU_BI := rGTG1.YOGOGAKO_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_BI := rGTG1.YOGOGAKO_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_BI := rGTG1.YOGOGAKO_TENGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_BI := rGTG1.YOGOGAKO_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.YOGOGAKO_SOTSUGYO_BI := rGTG1.YOGOGAKO_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.YUYO_KYOKA_BI := rGTG1.YUYO_KYOKA_BI;
                rGKBTGAKUREIBO_I.YUYO_JIYU_CD := rGTG1.YUYO_JIYU_CD;
                rGKBTGAKUREIBO_I.YUYO_JIYU := rGTG1.YUYO_JIYU;
                rGKBTGAKUREIBO_I.YUYO_KAISI_BI := rGTG1.YUYO_KAISI_BI;
                rGKBTGAKUREIBO_I.YUYO_SYURYO_BI := rGTG1.YUYO_SYURYO_BI;
                rGKBTGAKUREIBO_I.YUYO_NENSU := rGTG1.YUYO_NENSU;
                rGKBTGAKUREIBO_I.YUYO_FUKUGAKU_BI := rGTG1.YUYO_FUKUGAKU_BI;
                rGKBTGAKUREIBO_I.MENJO_KYOKA_BI := rGTG1.MENJO_KYOKA_BI;
                rGKBTGAKUREIBO_I.MENJO_JIYU_CD := rGTG1.MENJO_JIYU_CD;
                rGKBTGAKUREIBO_I.MENJO_JIYU := rGTG1.MENJO_JIYU;
                rGKBTGAKUREIBO_I.MENJO_KAISI_BI := rGTG1.MENJO_KAISI_BI;
                rGKBTGAKUREIBO_I.MENJO_SYURYO_BI := rGTG1.MENJO_SYURYO_BI;
                rGKBTGAKUREIBO_I.MENJO_NENSU := rGTG1.MENJO_NENSU;
                rGKBTGAKUREIBO_I.MENJO_FUKUGAKU_BI := rGTG1.MENJO_FUKUGAKU_BI;
                rGKBTGAKUREIBO_I.IDO_BI1 := rGTG1.IDO_BI1;
                rGKBTGAKUREIBO_I.IDO_JIYU1 := rGTG1.IDO_JIYU1;
                rGKBTGAKUREIBO_I.IDO_BI2 := rGTG1.IDO_BI2;
                rGKBTGAKUREIBO_I.IDO_JIYU2 := rGTG1.IDO_JIYU2;
                rGKBTGAKUREIBO_I.IDO_BI3 := rGTG1.IDO_BI3;
                rGKBTGAKUREIBO_I.IDO_JIYU3 := rGTG1.IDO_JIYU3;
                rGKBTGAKUREIBO_I.IDO_BI4 := rGTG1.IDO_BI4;
                rGKBTGAKUREIBO_I.IDO_JIYU4 := rGTG1.IDO_JIYU4;
                rGKBTGAKUREIBO_I.IDO_BI5 := rGTG1.IDO_BI5;
                rGKBTGAKUREIBO_I.IDO_JIYU5 := rGTG1.IDO_JIYU5;
                rGKBTGAKUREIBO_I.IDO_BI6 := rGTG1.IDO_BI6;
                rGKBTGAKUREIBO_I.IDO_JIYU6 := rGTG1.IDO_JIYU6;
                rGKBTGAKUREIBO_I.IDO_BI7 := rGTG1.IDO_BI7;
                rGKBTGAKUREIBO_I.IDO_JIYU7 := rGTG1.IDO_JIYU7;
                rGKBTGAKUREIBO_I.IDO_BI8 := rGTG1.IDO_BI8;
                rGKBTGAKUREIBO_I.IDO_JIYU8 := rGTG1.IDO_JIYU8;
                rGKBTGAKUREIBO_I.IDO_BI9 := rGTG1.IDO_BI9;
                rGKBTGAKUREIBO_I.IDO_JIYU9 := rGTG1.IDO_JIYU9;
                rGKBTGAKUREIBO_I.IDO_BI10 := rGTG1.IDO_BI10;
                rGKBTGAKUREIBO_I.IDO_JIYU10 := rGTG1.IDO_JIYU10;
                rGKBTGAKUREIBO_I.SYS_SAKUSEIBI := rGTG1.SYS_SAKUSEIBI;
                rGKBTGAKUREIBO_I.SYS_KOSHINBI := g_nDATE;
                rGKBTGAKUREIBO_I.SYS_JIKAN := g_nTIME;
                rGKBTGAKUREIBO_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                rGKBTGAKUREIBO_I.SYS_TANMATU_NO := g_sWSNUM;
                rGKBTGAKUREIBO_I.GAKUNEN := rGTG1.GAKUNEN;
                rGKBTGAKUREIBO_I.SHORIBI := g_nDATE;
                rGKBTGAKUREIBO_I.SHUGAKU := rGTG1.SHUGAKU;
                rGKBTGAKUREIBO_I.IDOJIKO := rGTG1.IDOJIKO;
                rGKBTGAKUREIBO_I.CHOHYO_NO := rGTG1.CHOHYO_NO;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := 0;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rGTG1.TYUGAKO_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := rGTG1.TYUGAKO_TENGAKU_GAKUNEN;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SYOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.SYOGAKO_TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.SYOGAKO_TENGAKU_GAKUNEN := rGTG1.SYOGAKO_TENGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENNYUGAKU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUREIBO_I.TYUGAKO_TENGAKU_GAKUNEN := 0;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENNYUGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TENGAKU_GAKUNEN := rGTG1.KUIKIGAI_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUIKIGAI_TAIGAKU_GAKUNEN := rGTG1.KUIKIGAI_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENNYUGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TENGAKU_GAKUNEN := rGTG1.YOGOGAKO_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.YOGOGAKO_TAIGAKU_GAKUNEN := rGTG1.YOGOGAKO_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.GAKKO_KBN_CD := rGTG1.GAKKO_KBN_CD;
                rGKBTGAKUREIBO_I.GAKUKYU_CD := 0;
                rGKBTGAKUREIBO_I.SEIBETSU := rGTG1.SEIBETSU;
                rGKBTGAKUREIBO_I.JOTAI := rGTG1.JOTAI;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_KBN := rGTG1.TENNYUMAE_GAKKO_KBN;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKKO_CD := rGTG1.TENNYUMAE_GAKKO_CD;
                rGKBTGAKUREIBO_I.TENNYUMAE_GAKUNEN := rGTG1.TENNYUMAE_GAKUNEN;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_FLG := rGTG1.GENKYURYUCHI_FLG;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_KETTEI_BI := rGTG1.GENKYURYUCHI_KETTEI_BI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_KAISI_BI := rGTG1.GENKYURYUCHI_KAISI_BI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_SYURYOBI := rGTG1.GENKYURYUCHI_SYURYOBI;
                rGKBTGAKUREIBO_I.GENKYURYUCHI_RIYU := rGTG1.GENKYURYUCHI_RIYU;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rGTG1.SHITEI_TYUGAKO_CD;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SHITEI_SYOGAKO_CD := rGTG1.SHITEI_SYOGAKO_CD;
                  rGKBTGAKUREIBO_I.SHITEI_TYUGAKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.HENKO_GAKUNEN_SYOGAKO := rGTG1.HENKO_GAKUNEN_SYOGAKO;
                rGKBTGAKUREIBO_I.HENKO_GAKUNEN_TYUGAKO := rGTG1.HENKO_GAKUNEN_TYUGAKO;
                rGKBTGAKUREIBO_I.HENKO_SHINSEI_BI := rGTG1.HENKO_SHINSEI_BI;
                rGKBTGAKUREIBO_I.HENKO_KYOKA_BI := rGTG1.HENKO_KYOKA_BI;
                rGKBTGAKUREIBO_I.HENKO_KBN := rGTG1.HENKO_KBN;
                rGKBTGAKUREIBO_I.HENKO_KAISI_BI := rGTG1.HENKO_KAISI_BI;
                rGKBTGAKUREIBO_I.HENKO_SYURYO_BI := rGTG1.HENKO_SYURYO_BI;
                rGKBTGAKUREIBO_I.HENKO_KYOKA_RIYU := rGTG1.HENKO_KYOKA_RIYU;
                rGKBTGAKUREIBO_I.HENKO_JIYU := rGTG1.HENKO_JIYU;
                rGKBTGAKUREIBO_I.HENKO_HUKYOKA_RIYU := rGTG1.HENKO_HUKYOKA_RIYU;
                rGKBTGAKUREIBO_I.KIBO_GAKKO_KBN_CD := rGTG1.KIBO_GAKKO_KBN_CD;
                rGKBTGAKUREIBO_I.KIBO_SYOGAKKO_CD := rGTG1.KIBO_SYOGAKKO_CD;
                rGKBTGAKUREIBO_I.KIBO_TYUGAKKO_CD := rGTG1.KIBO_TYUGAKKO_CD;
                rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_SYOGAKO := rGTG1.KIBO_UKETSUKE_BI_SYOGAKO;
                rGKBTGAKUREIBO_I.KIBO_UKETSUKE_BI_TYUGAKO := rGTG1.KIBO_UKETSUKE_BI_TYUGAKO;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_FLG := rGTG1.KUIKIGAISHUGAKU_FLG;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SHINSEI_BI := rGTG1.KUIKIGAISHUGAKU_SHINSEI_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_BI := rGTG1.KUIKIGAISHUGAKU_KYOKA_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KAISI_BI := rGTG1.KUIKIGAISHUGAKU_KAISI_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_SYURYO_BI := rGTG1.KUIKIGAISHUGAKU_SYURYO_BI;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_JIYU := rGTG1.KUIKIGAISHUGAKU_JIYU;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_KYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_KYOKA_RIYU;
                rGKBTGAKUREIBO_I.KUIKIGAISHUGAKU_HUKYOKA_RIYU := rGTG1.KUIKIGAISHUGAKU_HUKYOKA_RIYU;
                rGKBTGAKUREIBO_I.HUSHUGAKU_KAISI_BI := rGTG1.HUSHUGAKU_KAISI_BI;
                rGKBTGAKUREIBO_I.HUSHUGAKU_SYURYO_BI := rGTG1.HUSHUGAKU_SYURYO_BI;
                rGKBTGAKUREIBO_I.HUSHUGAKU_RIYU := rGTG1.HUSHUGAKU_RIYU;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_CD := rGTG1.KUNISHIRITSU_CD;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_NYUGAKU_BI := rGTG1.KUNISHIRITSU_NYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_BI := rGTG1.KUNISHIRITSU_TENNYUGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENNYUGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENNYUGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_BI := rGTG1.KUNISHIRITSU_TENGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TENGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TENGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_BI := rGTG1.KUNISHIRITSU_TAIGAKU_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_TAIGAKU_GAKUNEN := rGTG1.KUNISHIRITSU_TAIGAKU_GAKUNEN;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_SOTSUGYO_BI := rGTG1.KUNISHIRITSU_SOTSUGYO_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_KAISI_BI := rGTG1.KUNISHIRITSU_KAISI_BI;
                rGKBTGAKUREIBO_I.KUNISHIRITSU_SYURYO_BI := rGTG1.KUNISHIRITSU_SYURYO_BI;
                rGKBTGAKUREIBO_I.TSUSHOMEI_KANA := rGTG1.TSUSHOMEI_KANA;
                rGKBTGAKUREIBO_I.TSUSHOMEI_KANJI := rGTG1.TSUSHOMEI_KANJI;
                rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANA := rGTG1.HOGOSHA_TSUSHOMEI_KANA;
                rGKBTGAKUREIBO_I.HOGOSYA_TSUSHOMEI_KANJI := rGTG1.HOGOSHA_TSUSHOMEI_KANJI;
                rGKBTGAKUREIBO_I.GRB_HENKO_TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                rGKBTGAKUREIBO_I.GRB_HENKO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                nRTN := KKAPK0030.FCTGetR('GKB', '00TOHAIGO_HENKOJIYU', '0000', 0, aPRM);
                IF aPRM(1) = '1' THEN
                  rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 14;
                ELSIF aPRM(1) = '2' THEN
                  rGKBTGAKUREIBO_I.GRB_HENKO_JIYU := 99;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.BIKO := REPLACE(rGTG1.BIKO, chr(13)||chr(10),'#') || '新設・統廃合一括処理による転入学';
                rGKBTGAKUREIBO_I.IDO_BI := KKAPK0020.FNENDOHENKAN(g_vIDOYMD);
                rGKBTGAKUREIBO_I.TODOKEDE_BI := KKAPK0020.FNENDOHENKAN(g_vTODOTEDEYMD);
                rGKBTGAKUREIBO_I.SHINSEI_KANRI_RENBAN := rGTG1.SHINSEI_KANRI_RENBAN;
                rGKBTGAKUREIBO_I.IDOJI_ATENA_RIREKI_RENBAN := rGTG1.IDOJI_ATENA_RIREKI_RENBAN;
                rGKBTGAKUREIBO_I.HOGOSYA_IDOJI_RIREKI_RENBAN := rGTG1.HOGOSYA_IDOJI_RIREKI_RENBAN;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rDATA.NEW_GAKKOKU_CD;
                  rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rGTG1.CHUGAKKOKU_CD;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTGAKUREIBO_I.SHOGAKKOKU_CD := rGTG1.SHOGAKKOKU_CD;
                  rGKBTGAKUREIBO_I.CHUGAKKOKU_CD := rDATA.NEW_GAKKOKU_CD;
                ELSE
                  NULL;
                END IF;
                rGKBTGAKUREIBO_I.SAKUJO_FLG := 0;
                BEGIN
                  SELECT
                    BUKACODE
                  INTO sBUKACODE
                  FROM
                    KKNTWS
                  WHERE
                    KKNTWS.WSNUM = g_sWSNUM;
                EXCEPTION
                  WHEN OTHERS THEN
                    sBUKACODE := NULL;
                END;
                BEGIN
                  SELECT
                    BUKANAME
                  INTO rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO
                  FROM
                    KKNTBK
                  WHERE
                    BUKACODE = sBUKACODE
                    AND KKNTBK.YUKOKIKANFR = (
                                               SELECT MAX(YUKOKIKANFR) FROM KKNTBK WHERE BUKACODE = sBUKACODE
                                              );
                EXCEPTION
                  WHEN OTHERS THEN
                    rGKBTGAKUREIBO_I.SYS_TANMATU_BASHO := NULL;
                END;
                INSERT INTO GKBTGAKUREIBO VALUES rGKBTGAKUREIBO_I;
                --就学履歴に転入学の履歴を作成する。 ※転入学時
                rGKBTSHUGAKURIREKI_I.KOJIN_NO := rDATA.KOJIN_NO;
                rGKBTSHUGAKURIREKI_I.NENDO := TO_NUMBER(SUBSTR(KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD), 1, 4));
                rGKBTSHUGAKURIREKI_I.KOJIN_RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                nGKBTSHUGAKURIREKISEQ := nGKBTSHUGAKURIREKISEQ + 10;
                rGKBTSHUGAKURIREKI_I.SHUGAKU_RIREKI_RENBAN := nGKBTSHUGAKURIREKISEQ;
                rGKBTSHUGAKURIREKI_I.SAISHIN_FLG := 0;
                IF rDATA.NOW_GAKUNEN >= 1 AND rDATA.NOW_GAKUNEN <= 6 THEN
                  rGKBTSHUGAKURIREKI_I.S_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTSHUGAKURIREKI_I.S_NYUGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.S_TENNYU_BI := KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD);
                  rGKBTSHUGAKURIREKI_I.S_TENNYU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := 0;
                  rGKBTSHUGAKURIREKI_I.S_TAIGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.S_TAIGAKU_GAKUNEN := 0;
                  rGKBTSHUGAKURIREKI_I.S_SOTSUGYO_BI := 0;
                  rGKBTSHUGAKURIREKI_I.T_CD := rGTR1.T_CD;
                  rGKBTSHUGAKURIREKI_I.T_NYUGAKU_BI := rGTR1.T_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TENNYU_BI := rGTR1.T_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TENNYU_GAKUNEN := rGTR1.T_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := rGTR1.T_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := rGTR1.T_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.T_TAIGAKU_BI := rGTR1.T_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.T_TAIGAKU_GAKUNEN := rGTR1.T_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.T_SOTSUGYO_BI := rGTR1.T_SOTSUGYO_BI;
                ELSIF rDATA.NOW_GAKUNEN >= 7 AND rDATA.NOW_GAKUNEN <= 9 THEN
                  rGKBTSHUGAKURIREKI_I.S_CD := rGTR1.S_CD;
                  rGKBTSHUGAKURIREKI_I.S_NYUGAKU_BI := rGTR1.S_NYUGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TENNYU_BI := rGTR1.S_TENNYU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TENNYU_GAKUNEN := rGTR1.S_TENNYU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_BI := rGTR1.S_TENGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TENGAKU_GAKUNEN := rGTR1.S_TENGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.S_TAIGAKU_BI := rGTR1.S_TAIGAKU_BI;
                  rGKBTSHUGAKURIREKI_I.S_TAIGAKU_GAKUNEN := rGTR1.S_TAIGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.S_SOTSUGYO_BI := rGTR1.S_SOTSUGYO_BI;
                  rGKBTSHUGAKURIREKI_I.T_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTSHUGAKURIREKI_I.T_NYUGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.T_TENNYU_BI := KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD);
                  rGKBTSHUGAKURIREKI_I.T_TENNYU_GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.T_TENGAKU_GAKUNEN := 0;
                  rGKBTSHUGAKURIREKI_I.T_TAIGAKU_BI := 0;
                  rGKBTSHUGAKURIREKI_I.T_TAIGAKU_GAKUNEN := 0;
                  rGKBTSHUGAKURIREKI_I.T_SOTSUGYO_BI := 0;
                ELSE
                  NULL;
                END IF;
                rGKBTSHUGAKURIREKI_I.SHIEN_BU_CD := rGTR1.SHIEN_BU_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_CD := rGTR1.SHIEN_S_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_HUKUSEKI_CD := rGTR1.SHIEN_S_HUKUSEKI_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_NYUGAKU_BI := rGTR1.SHIEN_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_BI := rGTR1.SHIEN_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENNYU_GAKUNEN := rGTR1.SHIEN_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_BI := rGTR1.SHIEN_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TENGAKU_GAKUNEN := rGTR1.SHIEN_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_BI := rGTR1.SHIEN_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_TAIGAKU_GAKUNEN := rGTR1.SHIEN_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_S_SOTSUGYO_BI := rGTR1.SHIEN_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_CD := rGTR1.SHIEN_T_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_HUKUSEKI_CD := rGTR1.SHIEN_T_HUKUSEKI_CD;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_NYUGAKU_BI := rGTR1.SHIEN_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_BI := rGTR1.SHIEN_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENNYU_GAKUNEN := rGTR1.SHIEN_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_BI := rGTR1.SHIEN_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TENGAKU_GAKUNEN := rGTR1.SHIEN_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_BI := rGTR1.SHIEN_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_TAIGAKU_GAKUNEN := rGTR1.SHIEN_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.SHIEN_T_SOTSUGYO_BI := rGTR1.SHIEN_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_CD := rGTR1.KUIKIGAI_S_CD;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_S_KAISHI_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_NYUGAKU_BI := rGTR1.KUIKIGAI_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_BI := rGTR1.KUIKIGAI_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_BI := rGTR1.KUIKIGAI_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_BI := rGTR1.KUIKIGAI_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SOTSUGYO_BI := rGTR1.KUIKIGAI_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAISHI_BI := rGTR1.KUIKIGAI_S_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_SHURYO_BI := rGTR1.KUIKIGAI_S_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_S_KAIJO_BI := rGTR1.KUIKIGAI_S_KAIJO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_CD := rGTR1.KUIKIGAI_T_CD;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_GAKUNEN := rGTR1.KUIKIGAI_T_KAISHI_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_NYUGAKU_BI := rGTR1.KUIKIGAI_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_BI := rGTR1.KUIKIGAI_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENNYU_GAKUNEN := rGTR1.KUIKIGAI_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_BI := rGTR1.KUIKIGAI_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TENGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_BI := rGTR1.KUIKIGAI_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_TAIGAKU_GAKUNEN := rGTR1.KUIKIGAI_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SOTSUGYO_BI := rGTR1.KUIKIGAI_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAISHI_BI := rGTR1.KUIKIGAI_T_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_SHURYO_BI := rGTR1.KUIKIGAI_T_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUIKIGAI_T_KAIJO_BI := rGTR1.KUIKIGAI_T_KAIJO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_CD := rGTR1.KUNISHIRITSU_S_CD;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_NYUGAKU_BI := rGTR1.KUNISHIRITSU_S_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_BI := rGTR1.KUNISHIRITSU_S_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_BI := rGTR1.KUNISHIRITSU_S_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_BI := rGTR1.KUNISHIRITSU_S_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_S_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_S_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_KAISHI_BI := rGTR1.KUNISHIRITSU_S_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_S_SHURYO_BI := rGTR1.KUNISHIRITSU_S_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_CD := rGTR1.KUNISHIRITSU_T_CD;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_NYUGAKU_BI := rGTR1.KUNISHIRITSU_T_NYUGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_BI := rGTR1.KUNISHIRITSU_T_TENNYU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENNYU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENNYU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_BI := rGTR1.KUNISHIRITSU_T_TENGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TENGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TENGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_BI := rGTR1.KUNISHIRITSU_T_TAIGAKU_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_TAIGAKU_GAKUNEN := rGTR1.KUNISHIRITSU_T_TAIGAKU_GAKUNEN;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SOTSUGYO_BI := rGTR1.KUNISHIRITSU_T_SOTSUGYO_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_KAISHI_BI := rGTR1.KUNISHIRITSU_T_KAISHI_BI;
                rGKBTSHUGAKURIREKI_I.KUNISHIRITSU_T_SHURYO_BI := rGTR1.KUNISHIRITSU_T_SHURYO_BI;
                rGKBTSHUGAKURIREKI_I.SAKUJO_FLG := rGTR1.SAKUJO_FLG;
                rGKBTSHUGAKURIREKI_I.SYS_SAKUSEIBI := g_nDATE;
                rGKBTSHUGAKURIREKI_I.SYS_KOSHINBI := 0;
                rGKBTSHUGAKURIREKI_I.SYS_JIKAN := g_nTIME;
                rGKBTSHUGAKURIREKI_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                rGKBTSHUGAKURIREKI_I.SYS_TANMATU_NO := g_sWSNUM;
                INSERT INTO GKBTSHUGAKURIREKI VALUES rGKBTSHUGAKURIREKI_I;
                IF g_NENTXYUFLG = 1 THEN
                  --学年履歴の現最新履歴の最新フラグを変更する。
                  UPDATE GKBTGAKUNENRIREKI
                  SET SAISIN_FLG = 1,
                      SYS_KOSHINBI = g_nDATE,
                      SYS_JIKAN = g_nTIME,
                      SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                      SYS_TANMATU_NO = g_sWSNUM
                  WHERE KOJIN_NO = rDATA.KOJIN_NO
                    AND SAISIN_FLG = 0;
                  --学年履歴に転入先の学校の学年履歴を作成する。
                  rGKBTGAKUNENRIREKI_I.KOJIN_NO := rDATA.KOJIN_NO;
                  rGKBTGAKUNENRIREKI_I.NENDO := TO_NUMBER(SUBSTR(KKAPK0020.FNENDOHENKAN(g_vTENNYUGAKUYMD), 1, 4));
                  rGKBTGAKUNENRIREKI_I.KOJIN_RIREKI_RENBAN := nGKBTGAKUREIBOSEQ;
                  rGKBTGAKUNENRIREKI_I.GAKUNEN_RIREKI_RENBAN := nGKBTGAKUNENRIREKISEQ;
                  rGKBTGAKUNENRIREKI_I.GAKKO_KBN_CD := rDATA.NEW_SHUGAKUSHITEIKOU_KBN;
                  rGKBTGAKUNENRIREKI_I.GAKKO_CD := rDATA.NEW_SHUGAKUSHITEIKOU;
                  rGKBTGAKUNENRIREKI_I.SAISIN_FLG := 0;
                  rGKBTGAKUNENRIREKI_I.GAKUKYU_KBN := 0;
                  rGKBTGAKUNENRIREKI_I.GAKUKYU_CD := 0;
                  rGKBTGAKUNENRIREKI_I.GAKUNEN := rDATA.TENNYUGAKU_GAKUNEN;
                  rGKBTGAKUNENRIREKI_I.SAKUJO_FLG := 0;
                  rGKBTGAKUNENRIREKI_I.SYS_SAKUSEIBI := g_nDATE;
                  rGKBTGAKUNENRIREKI_I.SYS_KOSHINBI := 0;
                  rGKBTGAKUNENRIREKI_I.SYS_JIKAN := g_nTIME;
                  rGKBTGAKUNENRIREKI_I.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                  rGKBTGAKUNENRIREKI_I.SYS_TANMATU_NO := g_sWSNUM;
                  INSERT INTO GKBTGAKUNENRIREKI VALUES rGKBTGAKUNENRIREKI_I;
                ELSE
                  NULL;
                END IF;
              ELSE
                NULL;
              END IF;
          END LOOP;
          IF cCURSOR2%ISOPEN THEN
            CLOSE cCURSOR2;
          END IF;
          --学区管理情報、就学指定校マスタの入れ替え
          DELETE FROM GKBTMSGAKKU;
          DELETE FROM GKBTMSSHUGAKUSHITEIKOU;
          INSERT INTO GKBTMSGAKKU SELECT * FROM GKBTMSGAKKUKARI;
          INSERT INTO GKBTMSSHUGAKUSHITEIKOU SELECT * FROM GKBTMSSHUGAKUSHITEIKOUKR;
          DELETE FROM GKBTMSGAKKUKARI;
          DELETE FROM GKBTMSSHUGAKUSHITEIKOUKR;
        ELSE
          NULL;
        END IF;
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 2);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/09/09 ZCZL.WANGMING ADD START 0.3.000.002:8月1日認識合わせの横展開
            IF cCURSOR%ISOPEN THEN
              CLOSE cCURSOR;
            END IF;
            IF cCURSOR2%ISOPEN THEN
              CLOSE cCURSOR2;
            END IF;
--  2024/09/09 ZCZL.WANGMING ADD END
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
    END FUNC_B20UPDATE1;
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
        g_oKENSU_LIST.EXTEND(3);
--  2024/09/09 ZCZL.WANGMING Update 0.3.000.002:8月1日認識合わせの横展開
--        g_oKENSU_LIST(1) := GKBEKENSU_RECORD(g_nTAISIXYOUCNT, '入力　新設・統廃合対象件数', 1);
        g_oKENSU_LIST(1) := GKBEKENSU_RECORD(g_nCNT, '入力　新設・統廃合対象件数', 1);
        g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nTSUCHICNT, '出力　新設・統廃合通知件数', 2);
--  2024/09/09 ZCZL.WANGMING Update 0.3.000.002:8月1日認識合わせの横展開
--        g_oKENSU_LIST(3) := GKBEKENSU_RECORD(g_nCSVCNT, '出力　新設・統廃合対象CSV', 3);
        g_oKENSU_LIST(3) := GKBEKENSU_RECORD(g_nCSVCNT, '出力　新設・統廃合対象CSV', 2);
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LISHUAI   2024/06/26
    --------------------------------------------------------
    PROCEDURE PBATCH(i_nJOBNUM  IN  NUMBER,
                     o_nRESULT  OUT NUMBER)
    IS
        ePRMEXCEPTION                 EXCEPTION;                --パラメータ取得異常タイプ
        eSHORIEXCEPTION               EXCEPTION;                --処理異常タイプ
        bRTN                          BOOLEAN;                  --戻り値
        nRTN                          NUMBER;                   --戻り値
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
        --排他処理を行う
        nRTN := GKBFKHTSET(2, '999999999999', '全件', g_nDATE, g_sTANTOCODE, g_sWSNUM, g_nTIME);
        IF nRTN = 1 THEN
--  2024/09/03 ZCZL.WANGMING Update 0.3.000.001:IT_GKB_00075対応
--          bRTN:= FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'バッチ処理の呼出１', 1, '', '排他がかかっているデータが存在するため、処理を実行できませんでした。', '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
          bRTN:= FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'PBATCH', 1, '', '', '排他がかかっているデータが存在するため、処理を実行できませんでした。', g_sTANTOCODE, g_sWSNUM, 1);
          RAISE ePRMEXCEPTION;
        ELSIF nRTN <> 0 AND nRTN <> 1 THEN
--  2024/09/03 ZCZL.WANGMING Update 0.3.000.001:IT_GKB_00075対応
--          bRTN:= FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'バッチ処理の呼出２', 1, '', '排他制御処理で異常終了しました。', '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
          bRTN:= FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'PBATCH', 1, '', '', '排他制御処理で異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
          RAISE ePRMEXCEPTION;
        ELSE
          NULL;
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
        --排他制御クリア
        nRTN := GKBFKHTCLR(2, '999999999999');
        IF nRTN = 0 THEN
--  2024/09/03 ZCZL.WANGMING Update 0.3.000.001:IT_GKB_00075対応
--          bRTN:= FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'バッチ処理の呼出３', 0, '', '', '排他制御クリア処理　正常終了', g_sTANTOCODE, g_sWSNUM, 2);
          bRTN:= FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'PBATCH', 0, '', '', '排他制御クリア処理　正常終了', g_sTANTOCODE, g_sWSNUM, 1);
        ELSIF nRTN = 9 THEN
--  2024/09/03 ZCZL.WANGMING Update 0.3.000.001:IT_GKB_00075対応
--          bRTN:= FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'バッチ処理の呼出４', 1, SQLCODE, SQLERRM, '排他制御クリア処理　異常終了', g_sTANTOCODE, g_sWSNUM, 2);
          bRTN:= FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'PBATCH', 1, '', '', '排他制御クリア処理　異常終了', g_sTANTOCODE, g_sWSNUM, 1);
          RAISE ePRMEXCEPTION;
        END IF;
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
END GKBPC00460;
/
