CREATE OR REPLACE PACKAGE BODY GKBPB00490
--1.0.402.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB(教育)
--  プログラム名  : 学校選択制案内書作成
--  機能概要      : 学年単位で児童・生徒の一覧表を作成する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.caijiacun 2024/06/05
--------------------------------------------------------
--  変更履歴
--  2024/08/05 ZCZL.caijiacun Update 0.3.000.001:検収指摘No.138、139の対応
--  2024/08/30 ZCZL.caijiacun Update 0.3.000.002:IT_GKB_00075対応
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.003:8月1日認識合わせの横展開
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.004:IT_GKB_00177対応
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.005:仕様変更　IT_GKB_00010対応
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00225、IT_GKB_00262、IT_GKB_00265、IT_GKB_00226、IT_GKB_00227対応
--  2024/10/17 ZCZL.ZHANGLEI UPDATE 0.3.000.007:IT_GKB_00260対応
--  2024/10/21 ZCZL.ZHANGLEI UPDATE 0.3.000.008:IT_GKB_00248対応
--  2024/10/30 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKB_00303仕様変更対応
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.010:IT_GKB_00286横展開対応
--  2024/11/05 ZCZL.ZHANGLEI UPDATE 0.3.000.011:IT_GKB_00259対応
--  2024/11/07 ZCZL.ZHANGLEI UPDATE 0.3.000.012:IT_GKB_00444対応
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.013:仕様変更　IT_GKB_00426対応
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.014:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.015:IT_GKB_00600対応
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応
--  2024/11/26 ZCZL.ZHANGLEI UPDATE 0.3.000.017:IT_GKC_00329横展開対応
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
--  2025/02/05 JIP.Y.SATO UPDATE 0.3.000.019:ST故障対応
--  2025/05/23 CTC.LIZIZHONG UPDATE 1.0.006.000:QA15755対応
--  2025/06/04 CTC.HJF UPDATE 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
--  2025/06/11 CTC.GL UPDATE 1.0.008.000:GKB_QA13861対応
--  2025/07/01 CTC.GL UPDATE 1.0.010.001::GKB_QA17602対応
--  2025/07/18 CTC.HJF UOPDATE 1.0.010.001:GKB_QA17896対応
--  2025/12/03 CTC.GYY UPDATE 1.0.401.000:GKB_QA23605対応
--  2025/12/05 CTC.NI UPDATE 1.0.402.000:不具合対応
--------------------------------------------------------
-- 修正概要      : 帳票アウトソーシング連番対応
-- バージョン    : 1.0.300.000
-- 修正者／修正日: CTC.BAI 2025/10/16
--------------------------------------------------------
IS
    -- 全処理必須パラメータ
    c_BATCH                                CONSTANT PLS_INTEGER := 2;      --バッチ
    c_OK                                   CONSTANT PLS_INTEGER := 0;      --正常
    c_ERR                                  CONSTANT PLS_INTEGER := -1;     --異常
    g_nJOBNUM                              NUMBER;                         --ジョブナンバー
    g_sTANTOCODE                           CHAR(12);                       --担当者コード
    g_sWSNUM                               NVARCHAR2(63);                  --端末番号
    g_nSAKUHYOLOGSEQ                       NUMBER := 0;                    --作表ログ連番
    g_nUPDLOGSEQ                           NUMBER := 0;                    --更新ログ連番
    g_sMESSAGE                             NVARCHAR2(4000);                --メッセージ返却用
    g_rJSTP                                KKBTJSTP%ROWTYPE;               --バッチジョブステップ情報
    g_sSHORIID                             KKBTJCTL.SHORIID%TYPE;          --処理ID
    g_sGYOUMUCODE                          NVARCHAR2(3);                   --業務コード
    g_sGAKO_KBN                            NVARCHAR2(3);                   --学校区分（ 1：すべて が選択されている、2:小学校、3:中学校
--  2024/10/30 ZCZL.WANGYUNING UPDATE START 0.3.000.014:学校コードリスト仕様変更IT_GKB_00090の対応
    --g_sGAKO                                NVARCHAR2(1000);                --就学指定校
    --g_sGAKO_ED                             NVARCHAR2(1000);                --就学指定校編集後
    --g_sTYUGAKO_ED                          NVARCHAR2(1000);                --就学指定中学校編集後
    --g_sSYOGAKO_ED                          NVARCHAR2(1000);                --就学指定小学校編集後
    g_sGAKO                                NVARCHAR2(3000);                --就学指定校
    g_sGAKO_ED                             NVARCHAR2(3000);                --就学指定校編集後
    g_sTYUGAKO_ED                          NVARCHAR2(3000);                --就学指定中学校編集後
    g_sSYOGAKO_ED                          NVARCHAR2(3000);                --就学指定小学校編集後
--  2024/10/30 ZCZL.WANGYUNING UPDATE END
    g_sHAKKOBI                             NVARCHAR2(20);                  --発行日
    g_nHAKKOBI                             NUMBER;                         --発行日_西暦
    g_sSHIENSOCHI                          NVARCHAR2(10);                  --支援措置対象マスク
    g_sHakkoRireki                         NVARCHAR2(1);                   --発行履歴
    g_oKENSU_LIST                          GKBEKENSU_LIST := GKBEKENSU_LIST();

    g_nTIME                                NUMBER;                         --時分秒
    g_nSTEP_MAX                            NUMBER;
    g_nCNT                                 NUMBER;                         --グローバル変数.件数
    g_nCSVCNT                              NUMBER;                         --グローバル変数.CSV出力件数
    g_nDAIRIKBN                            NVARCHAR2(1000);                --認証者の本人・代理区分
    g_sKATAGAKI1                           NVARCHAR2(1000);                --認証者職種
    g_sKATAGAKI2                           NVARCHAR2(1000);                --認証者の肩書下段
    g_sSHIMEI                              NVARCHAR2(1000);                --認証者名
    g_sKOINFILENAME                        NVARCHAR2(1000);                --公印ファイル名
    g_bSHORIFLAG                           BOOLEAN := TRUE;                --処理FLAG
    
--  2025/05/23 CTC.LIZIZHONG UPDATE 1.0.006.000:QA15755対応 Start　    
    VERRMSG                                NVARCHAR2(1000);                --エラーメッセージ
    IRTN                                    PLS_INTEGER;
     --日付変換パラメータ
    IWAREKIHIDUKEIO             PLS_INTEGER;
    ISEIREKIHIDUKEIO            PLS_INTEGER;
    VEDIT1O                     NVARCHAR2(20);
    VEDIT2O                     NVARCHAR2(20);
    VEDIT3O                     NVARCHAR2(20);
    VGENGOKANJIO                NVARCHAR2(10);
    VGENGOKIGOO                 NVARCHAR2(10);
    IWAREKINENO                 PLS_INTEGER;
    ISEIREKINENO                PLS_INTEGER;
    IWAREKINENGETUO             PLS_INTEGER;
    ITUKIO                      PLS_INTEGER;
    IDAYO                       PLS_INTEGER;
    IWAREKIHIDUKEO              PLS_INTEGER;
    ISEIREKIHIDUKEO             PLS_INTEGER;
    VDUMMY                      NVARCHAR2(500);
--  2025/05/23 CTC.LIZIZHONG UPDATE 1.0.006.000:QA15755対応 End
    
    --案内書
    g_sCHOHYOTITLE_ANNAISHOU_SGAKKOU       NVARCHAR2(1000);                --帳票タイトル_案内書_小学校
    g_sCHOHYOTITLE_ANNAISHOU_CGAKKOU       NVARCHAR2(1000);                --帳票タイトル_案内書_中学校
    g_sTSUCHIBUN_ANNAISHOU_SGAKKOU         NVARCHAR2(1000);                --通知文_案内書_小学校
    g_sTSUCHIBUN_ANNAISHOU_CGAKKOU         NVARCHAR2(1000);                --通知文_案内書_中学校
    g_sTOKKIJIKO_ANNAISHOU_SGAKKOU         NVARCHAR2(1000);                --特記事項_案内書_小学校
    g_sTOKKIJIKO_ANNAISHOU_CGAKKOU         NVARCHAR2(1000);                --特記事項_案内書_中学校
    g_sYOSHIKI_BANGO_ANNAISHOU_SGAKKOU     NVARCHAR2(1000);                --様式番号_案内書_小学校
    g_sYOSHIKI_BANGO_ANNAISHOU_CGAKKOU     NVARCHAR2(1000);                --様式番号_案内書_中学校
    g_sKOIN_SHORYAKU_ANNAISHOU_SGAKKOU     NVARCHAR2(1000);                --公印省略_案内書_小学校
    g_sKOIN_SHORYAKU_ANNAISHOU_CGAKKOU     NVARCHAR2(1000);                --公印省略_案内書_中学校
    g_sKOIN_CHUSHAKU_ANNAISHOU_SGAKKOU     NVARCHAR2(1000);                --公印注釈_案内書_小学校
    g_sKOIN_CHUSHAKU_ANNAISHOU_CGAKKOU     NVARCHAR2(1000);                --公印注釈_案内書_中学校
    g_dANNAISHOU_KIGEN_ANNAISHOU_SGAKKOU   NVARCHAR2(20);                  --案内書提出期限_小学校
    g_dANNAISHOU_KIGEN_ANNAISHOU_CGAKKOU   NVARCHAR2(20);                  --案内書提出期限_中学校

    --調査書
    g_sCHOHYOTITLE_CHOUSASHO_SGAKKOU       NVARCHAR2(1000);                 --帳票タイトル_調査書_小学校
    g_sCHOHYOTITLE_CHOUSASHO_CGAKKOU       NVARCHAR2(1000);                 --帳票タイトル_調査書_中学校
    g_sTSUCHIBUN_CHOUSASHO_SGAKKOU         NVARCHAR2(1000);                 --通知文_調査書_小学校
    g_sTSUCHIBUN_CHOUSASHO_CGAKKOU         NVARCHAR2(1000);                 --通知文_調査書_中学校
    g_sTOKKIJIKO_CHOUSASHO_SGAKKOU         NVARCHAR2(1000);                 --特記事項_調査書_小学校
    g_sTOKKIJIKO_CHOUSASHO_CGAKKOU         NVARCHAR2(1000);                 --特記事項_調査書_中学校
    g_sYOSHIKI_BANGO_CHOUSASHO_SGAKKOU     NVARCHAR2(1000);                 --様式番号_調査書_小学校
    g_sYOSHIKI_BANGO_CHOUSASHO_CGAKKOU     NVARCHAR2(1000);                 --様式番号_調査書_中学校
    g_sKOIN_SHORYAKU_CHOUSASHO_SGAKKOU     NVARCHAR2(1000);                 --公印省略_調査書_小学校
    g_sKOIN_SHORYAKU_CHOUSASHO_CGAKKOU     NVARCHAR2(1000);                 --公印省略_調査書_中学校
    g_sKOIN_CHUSHAKU_CHOUSASHO_SGAKKOU     NVARCHAR2(1000);                 --公印注釈_調査書_小学校
    g_sKOIN_CHUSHAKU_CHOUSASHO_CGAKKOU     NVARCHAR2(1000);                 --公印注釈_調査書_中学校
    g_dCHOUSASHO_KIGEN_CHOUSASHO_SGAKKOU   NVARCHAR2(20);                   --調査書提出期限_小学校(回答期限_小学)
    g_dCHOUSASHO_KIGEN_CHOUSASHO_CGAKKOU   NVARCHAR2(20);                   --調査書提出期限_中学校(回答期限_中学)

    g_rBUNNUMEDITKEKA                      KKAPK0040.MR_BUNNUMEDITKEKA;     --文書番号編集結果
    g_rBUNNUMSRCINF                        KKAPK0040.MR_BUNNUMSRCINF;
    g_cBUNNUM                              NVARCHAR2(100);

    g_rBUNNUM_shoushasho                   KKAPK0040.MR_BUNNUMEDITKEKA;     --調査書_案内書
    g_rBUNNUM_annaisho                     KKAPK0040.MR_BUNNUMEDITKEKA;     --文書番号_案内書
    g_r_shoushasho_seigyo                  NUMBER;                          --学校選択制案内書_出力制御
    g_r_annaisho_seigyo                    NUMBER;                          --学校選択制調査書_出力制御
    TYPE MR_BUNNUM IS RECORD(
        nKOJINNUM                           NUMBER,                          --宛名番号
        sBUNNUM                             NVARCHAR2(1000)                  --文書番号
    );
    TYPE MR_BUNNUM_REC IS TABLE OF MR_BUNNUM INDEX BY BINARY_INTEGER;
    g_rHOKANBUNNUM                          MR_BUNNUM_REC;                   --文書番号退避リスト
--  2024/11/02 ZCZL.WANGMING ADD 0.3.000.010:IT_GKB_00286横展開対応
    o_sEINENGAPI                    GKAPK00020.SEINENGAPI_REC;           --生年月日
    
--  2025/05/23 CTC.LIZIZHONG UPDATE 1.0.006.000:QA15755対応　Start
    --------------------------------------------------------
    --  機能概要      : 日付チェック
    --  パラメータ      : i_VHIZUKE  日付
    --                 i_IRENBAN
    --  モジュール区分   : 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン      : Ver 0.1.000.006
    --  作成者／作成日: CTC.LIZIZHONG 2025/05/023
    --------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2, i_IRENBAN IN NVARCHAR2) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    BRET BOOLEAN ;
    BEGIN
      IRET := 0 ;
      --日付
      BEGIN
        IF i_IRENBAN = 1 THEN
           IF LENGTH(i_VHIZUKE) <> 7 THEN
              IRET := 1;
           ELSE
              IWAREKIHIDUKEIO  := TO_NUMBER(i_VHIZUKE);
              ISEIREKIHIDUKEIO := 0;
           END IF;
        ELSE
          IRET := 0;
        END IF;


      IF IRET = 0 AND LENGTH(IWAREKIHIDUKEIO) = 7 THEN
        BRET := KKAPK0020.FDAYEDIT(IWAREKIHIDUKEIO, ISEIREKIHIDUKEIO,
                                    VEDIT1O, VEDIT2O, VEDIT3O,
                                    VGENGOKANJIO, VGENGOKIGOO,
                                    IWAREKINENO, ISEIREKINENO,
                                    IWAREKINENGETUO, ITUKIO, IDAYO,
                                    IWAREKIHIDUKEO, ISEIREKIHIDUKEO);
        IF BRET = FALSE THEN
          IRET := 1;
        END IF;
      END IF;

      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      RETURN(IRET) ;
    END FUNCHIZUKECHK; 
--  2025/05/23 CTC.LIZIZHONG UPDATE 1.0.006.000:QA15755対応 End　       
    --------------------------------------------------------
    --  機能概要      : バッチジョブステップテーブルの更新処理
    --  パラメータ    : i_UPD_KBN       更新区分
    --                : i_STEPRTNCODE   実行結果コード
    --                : i_CSV_RCNT      CSV出力件数
    --                : i_CSVFILENAME   CSVファイル名
    --                : i_PRTFILENAME   出力ファイル名
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun 2024/06/06
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
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun 2024/06/11
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;        --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
        --初期処理
        g_oKENSU_LIST.EXTEND(2);
        g_oKENSU_LIST(1) := GKBEKENSU_RECORD(g_nCNT,'入力　学校選択制対象者件数',1);
        g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nCSVCNT,'出力 学校選択制案内書CSV',2);

        FOR i in 1..g_oKENSU_LIST.COUNT LOOP
            bRTN:= KKBPK5551.FSETCNT(g_nJOBNUM,                  --ジョブナンバー
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
    --  作成者／作成日: ZCZL.DINGHONGRUI 2024/01/06
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
    --  機能概要      : 処理ログ出力
    --  パラメータ      : i_sGAKOCD       編集前学校コード
    --              : o_sGAKOCD       編集後学校コード
    --              : o_sSYOGAKOCD    編集後小学校コード
    --              : o_sTYUGAKOCD    編集後中学校コード
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.CAIJIACUN   2024/07/18
    --------------------------------------------------------
    FUNCTION FUNC_GET_GAKOCD(i_sGAKOCD IN NVARCHAR2, 
                             o_sGAKOCD OUT NVARCHAR2, 
                             o_sSYOGAKOCD OUT NVARCHAR2, 
                             o_sTYUGAKOCD OUT NVARCHAR2) RETURN BOOLEAN
    IS
        aGAKOCD           KKBPK5551.tySPLIT_tbl;      -- 学校コード（リスト）
        aGAKOCD_ED        KKBPK5551.tySPLIT_tbl;
--  2024/10/30 ZCZL.WANGYUNING ADD 0.3.000.014:学校コードリスト仕様変更IT_GKB_00090の対応
        nGAKOUCD_TMP      NUMBER; --学校コード
    BEGIN
        -- 入力引数を分解して配列にセットする
        -- 引数の業務コード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
        -- 処理ステップを取得
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.014:学校コードリスト仕様変更IT_GKB_00090の対応
        --FOR i IN 1..aGAKOCD.COUNT LOOP
        --  IF MOD(i - 1, 2) = 0 AND aGAKOCD.COUNT > 2 THEN
        --    IF i = aGAKOCD.COUNT - 1 THEN
        --      o_sGAKOCD := o_sGAKOCD || aGAKOCD(i);
        --    ELSE
        --      o_sGAKOCD := o_sGAKOCD || aGAKOCD(i) || ',';
        --    END IF;
        --  ELSIF aGAKOCD.COUNT = 2 THEN
        --    o_sGAKOCD := aGAKOCD(1);
        --  ELSE
        --    NULL;
        --  END IF;
        --END LOOP;
--
        --aGAKOCD_ED := KKBPK5551.FSplitStr (o_sGAKOCD, ',');
        --FOR i IN 1..aGAKOCD.COUNT LOOP
        --  IF SUBSTR(aGAKOCD(i),1,3) = '001' AND o_sSYOGAKOCD IS NOT NULL THEN
        --    o_sSYOGAKOCD := o_sSYOGAKOCD || ',' || SUBSTR(aGAKOCD(i), 4, 6);
        --  END IF;
        --  IF SUBSTR(aGAKOCD(i),1,3) = '002' AND o_sTYUGAKOCD IS NOT NULL THEN
        --    o_sTYUGAKOCD := o_sTYUGAKOCD || ',' || SUBSTR(aGAKOCD(i), 4, 6);
        --  END IF;
        --  IF o_sSYOGAKOCD IS NULL AND SUBSTR(aGAKOCD(i),1,3) = '001' THEN
        --      o_sSYOGAKOCD := SUBSTR(aGAKOCD(i), 4, 6);
        --  END IF;
        --  IF o_sTYUGAKOCD IS NULL AND SUBSTR(aGAKOCD_ED(i),1,3) = '002' THEN
        --      o_sTYUGAKOCD := SUBSTR(aGAKOCD_ED(i), 4, 6);
        --  END IF;
        --END LOOP;
        o_sSYOGAKOCD := '';
        o_sTYUGAKOCD := '';
        o_sGAKOCD := '';
        FOR i IN 1..aGAKOCD.COUNT LOOP
            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
            IF SUBSTR(aGAKOCD(i), 1, 3) = '001' THEN
                o_sSYOGAKOCD := o_sSYOGAKOCD || nGAKOUCD_TMP || ','; 
            ELSIF SUBSTR(aGAKOCD(i), 1, 3) = '002' THEN    
                o_sTYUGAKOCD := o_sTYUGAKOCD || nGAKOUCD_TMP || ','; 
            END IF;
        END LOOP;
        o_sSYOGAKOCD := SUBSTR(o_sSYOGAKOCD, 1, LENGTH(o_sSYOGAKOCD) - 1);
        o_sTYUGAKOCD := SUBSTR(o_sTYUGAKOCD, 1, LENGTH(o_sTYUGAKOCD) - 1);
--  2024/10/30 ZCZL.WANGYUNING UPDATE END
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_GET_GAKOCD;
    --------------------------------------------------------
    --  機能概要      : 初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun 2024/06/11
    --------------------------------------------------------
    FUNCTION FUNC_INIT
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                      --戻り値
        nRTN                          PLS_INTEGER;
        aPRM                          A_CONS_PRM;
        shoushasho_indexNUM           NUMBER;                       --学校選択制案内書_インデックス番号
        annaisho_indexNum             NUMBER;                       --学校選択制調査書_インデックス番号
    BEGIN
        --1.公印情報を編集する
        bRTN := KKBPK5551.FNINSHOGet(g_rJSTP.NINSHOCODE,g_sWSNUM,SYSDATE,g_nDAIRIKBN,g_sKATAGAKI1,g_sKATAGAKI2,g_sSHIMEI,g_sKOINFILENAME);
        --2.通知書情報を編集する
        FOR r IN (SELECT CHOHYO_KBN,
                         CHOHYO_MEI,
                         TSUCHIBUN,
                         TOKKIJIKO,
                         KOIN_SHORYAKU,
                         KOIN_CHUSHAKU,
                         YOSHIKI_BANGO_SETTOGO,
                         YOSHIKI_BANGO,
                         YOSHIKI_BANGO_SETSUBIGO
                   FROM  GKBTTSUCHISHOKANRI
                  WHERE  chohyo_kbn IN ('29','30','31','32')
        ) LOOP
            CASE r.CHOHYO_KBN
              WHEN '29' THEN
                --帳票タイトル_案内書_小学校
                g_sCHOHYOTITLE_ANNAISHOU_SGAKKOU    := r.CHOHYO_MEI;
                --通知文_案内書_小学校
                g_sTSUCHIBUN_ANNAISHOU_SGAKKOU      := r.TSUCHIBUN;
                --特記事項_案内書_小学校
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00225、IT_GKB_00262、IT_GKB_00265対応
--                g_sTOKKIJIKO_ANNAISHOU_SGAKKOU      := r.CHOHYO_MEI;
                --  2024/11/07 ZCZL.ZHANGLEI UPDATE 0.3.000.012:IT_GKB_00444対応
                --g_sTOKKIJIKO_ANNAISHOU_SGAKKOU      := r.TOKKIJIKO;
                g_sTOKKIJIKO_ANNAISHOU_SGAKKOU      := REPLACE(r.TOKKIJIKO, chr(13) || chr(10), '#');
                --様式番号_案内書_小学校
                g_sYOSHIKI_BANGO_ANNAISHOU_SGAKKOU  := r.YOSHIKI_BANGO_SETTOGO || r.YOSHIKI_BANGO || r.YOSHIKI_BANGO_SETSUBIGO;
                IF g_sKOINFILENAME IS NOT NULL THEN
                  --公印省略_案内書_小学校
                  g_sKOIN_SHORYAKU_ANNAISHOU_SGAKKOU := NULL;
                  --公印注釈_案内書_小学校
                  g_sKOIN_CHUSHAKU_ANNAISHOU_SGAKKOU := r.KOIN_CHUSHAKU;
                ELSE
                  --公印省略_案内書_小学校
                  g_sKOIN_SHORYAKU_ANNAISHOU_SGAKKOU := r.KOIN_SHORYAKU;
                  --公印注釈_案内書_小学校
                  g_sKOIN_CHUSHAKU_ANNAISHOU_SGAKKOU := NULL;
                END IF;
              WHEN '30' THEN
                --帳票タイトル_案内書_中学校
                g_sCHOHYOTITLE_ANNAISHOU_CGAKKOU    := r.CHOHYO_MEI;
                --通知文_案内書_中学校
                g_sTSUCHIBUN_ANNAISHOU_CGAKKOU      := r.TSUCHIBUN;
                --特記事項_案内書_中学校
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00225、IT_GKB_00262、IT_GKB_00265対応
--                g_sTOKKIJIKO_ANNAISHOU_CGAKKOU      := r.CHOHYO_MEI;
                g_sTOKKIJIKO_ANNAISHOU_CGAKKOU      := r.TOKKIJIKO;
                --様式番号_案内書_中学校
                g_sYOSHIKI_BANGO_ANNAISHOU_CGAKKOU  := r.YOSHIKI_BANGO_SETTOGO || r.YOSHIKI_BANGO || r.YOSHIKI_BANGO_SETSUBIGO;
                IF g_sKOINFILENAME IS NOT NULL THEN
                  --公印省略_案内書_中学校
                  g_sKOIN_SHORYAKU_ANNAISHOU_CGAKKOU := NULL;
                  --公印注釈_案内書_中学校
                  g_sKOIN_CHUSHAKU_ANNAISHOU_CGAKKOU := r.KOIN_CHUSHAKU;
                ELSE
                  --公印省略_案内書_中学校
                  g_sKOIN_SHORYAKU_ANNAISHOU_CGAKKOU := r.KOIN_SHORYAKU;
                  --公印注釈_案内書_中学校
                  g_sKOIN_CHUSHAKU_ANNAISHOU_CGAKKOU := NULL;
                END IF;
              WHEN '31' THEN
                --帳票タイトル_調査書_小学校
                g_sCHOHYOTITLE_CHOUSASHO_SGAKKOU    := r.CHOHYO_MEI;
                --通知文_調査書_小学校
                g_sTSUCHIBUN_CHOUSASHO_SGAKKOU      := r.TSUCHIBUN;
                --特記事項_調査書_小学校
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00225、IT_GKB_00262、IT_GKB_00265対応
--                g_sTOKKIJIKO_CHOUSASHO_SGAKKOU      := r.CHOHYO_MEI;
                g_sTOKKIJIKO_CHOUSASHO_SGAKKOU      := r.TOKKIJIKO;
                --様式番号_調査書_小学校
                g_sYOSHIKI_BANGO_CHOUSASHO_SGAKKOU  := r.YOSHIKI_BANGO_SETTOGO || r.YOSHIKI_BANGO || r.YOSHIKI_BANGO_SETSUBIGO;
                IF g_sKOINFILENAME IS NOT NULL THEN
                  --公印省略_調査書_小学校
                  g_sKOIN_SHORYAKU_CHOUSASHO_SGAKKOU := NULL;
                  --公印注釈_調査書_小学校
                  g_sKOIN_CHUSHAKU_CHOUSASHO_SGAKKOU := r.KOIN_CHUSHAKU;
                ELSE
                  --公印省略_調査書_小学校
                  g_sKOIN_SHORYAKU_CHOUSASHO_SGAKKOU := r.KOIN_SHORYAKU;
                  --公印注釈_調査書_小学校
                  g_sKOIN_CHUSHAKU_CHOUSASHO_SGAKKOU := NULL;
                END IF;
              WHEN '32' THEN
                --帳票タイトル_調査書_中学校
                g_sCHOHYOTITLE_CHOUSASHO_CGAKKOU    := r.CHOHYO_MEI;
                --通知文_調査書_中学校
                g_sTSUCHIBUN_CHOUSASHO_CGAKKOU      := r.TSUCHIBUN;
                --特記事項_調査書_中学校
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00225、IT_GKB_00262、IT_GKB_00265対応
--                g_sTOKKIJIKO_CHOUSASHO_CGAKKOU      := r.CHOHYO_MEI;
                g_sTOKKIJIKO_CHOUSASHO_CGAKKOU      := r.TOKKIJIKO;
                --様式番号_調査書_中学校
                g_sYOSHIKI_BANGO_CHOUSASHO_CGAKKOU  := r.YOSHIKI_BANGO_SETTOGO || r.YOSHIKI_BANGO || r.YOSHIKI_BANGO_SETSUBIGO;
                IF g_sKOINFILENAME IS NOT NULL THEN
                  --公印省略_調査書_中学校
                  g_sKOIN_SHORYAKU_CHOUSASHO_CGAKKOU := NULL;
                  --公印注釈_調査書_中学校
                  g_sKOIN_CHUSHAKU_CHOUSASHO_CGAKKOU := r.KOIN_CHUSHAKU;
                ELSE
                  --公印省略_調査書_中学校
                  g_sKOIN_SHORYAKU_CHOUSASHO_CGAKKOU := r.KOIN_SHORYAKU;
                  --公印注釈_調査書_中学校
                  g_sKOIN_CHUSHAKU_CHOUSASHO_CGAKKOU := NULL;
                END IF;
              ELSE
                NULL;
            END CASE;
            NULL;
        END LOOP;
--  2024/11/12 ZCZL.WANGMING ADD 0.3.000.013:仕様変更　IT_GKB_00426対応
        IF g_rJSTP.Chohyoid = 'GKB700R001'THEN
          --文書番号を取得する
          bRTN := KKBPK5551.FJBNSGet(g_nJOBNUM, g_rJSTP.STEPSEQ, g_rBUNNUMSRCINF);
          --文書番号編集結果を取得
          g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
--  2024/11/12 ZCZL.WANGMING ADD 0.3.000.013:仕様変更　IT_GKB_00426対応
        END IF;

        --5.システム制御設定を取得する。
        nRTN := KKAPK0030.FCTGetR ('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aPRM);
        FOR i IN 1..aPRM.Count LOOP
          CASE aPRM(i)
            WHEN 'GKB700R001' THEN
              shoushasho_indexNUM := i;
            WHEN 'GKB700R002' THEN
              annaisho_indexNum := i;
            ELSE
              NULL;
          END CASE;
        END LOOP;
        nRTN := KKAPK0030.FCTGetR ('GKB', 'EQSHIMEI', '0000', 0, aPRM);
        g_r_shoushasho_seigyo := aPRM(shoushasho_indexNUM);
        g_r_annaisho_seigyo := aPRM(annaisho_indexNum);
--  2024/11/12 ZCZL.WANGMING ADD 0.3.000.013:仕様変更　IT_GKB_00426対応
        IF g_rJSTP.Chohyoid = 'GKB700R001'THEN
          IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (g_rBUNNUMSRCINF.NUMINCTYPE = 1 OR g_rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
            KKAPK0040.SBunNumIc(g_rBUNNUMSRCINF, g_rBUNNUMEDITKEKA);
            g_rBUNNUM_shoushasho := g_rBUNNUMEDITKEKA;
            g_rBUNNUM_annaisho   := g_rBUNNUMEDITKEKA;
            --文書番号編集結果を取得
            g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
          END IF;
--  2024/11/12 ZCZL.WANGMING ADD 0.3.000.013:仕様変更　IT_GKB_00426対応
        END IF;

        --6.グローバル変数.件数、グローバル変数.CSV出力件数を0クリア
        g_nCNT := 0;
        g_nCSVCNT := 0;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_INIT;
    --------------------------------------------------------
    --  機能概要      : バッチ初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun   2024/06/06
    --------------------------------------------------------
    FUNCTION FUNC_B00INIT
        RETURN BOOLEAN
    IS
        bRTN          BOOLEAN;                                        --戻り値
        rJCTL         KKBTJCTL%ROWTYPE;                               --バッチジョブ情報
    BEGIN
        --初期処理
        bRTN := KKBPK5551.INITIAL (g_nJOBNUM);
        --バッチパラメータ取得
        bRTN := KKBPK5551.FJCTLGet (g_nJOBNUM, rJCTL);
        g_sTANTOCODE    := rJCTL.LOGIN_TANTOCODE;                     --担当者コード
        g_sWSNUM        := rJCTL.LOGIN_WSNUM;                         --端末番号
        g_sSHORIID      := rJCTL.SHORIID;                             --処理ID
        g_sGYOUMUCODE   := rJCTL.GYOUMUCODE;                          --業務コード
        g_nTIME         := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));    --時分秒

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B00INIT;
    --------------------------------------------------------
    --  機能概要      : バッチ処理入力値取得処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun   2024/06/06
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
      bRTN                    BOOLEAN;
--  2024/08/30 ZCZL.caijiacun Add start 0.3.000.002:IT_GKB_00075対応
      vGAKO_KBN               DBMS_UTILITY.MAXNAME_ARRAY;
      vSHIENSOCHI             DBMS_UTILITY.MAXNAME_ARRAY;
      vHakkoRireki            DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/08/30 ZCZL.caijiacun Add end
--  2024/10/30 ZCZL.WANGYUNING ADD 0.3.000.014:学校コードリスト仕様変更IT_GKB_00090の対応
      objShugakuShiteikou              DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        --学校区分
--  2024/08/30 ZCZL.caijiacun Update start 0.3.000.002:IT_GKB_00075対応
--         g_sGAKO_KBN := KKBPK5551.GETPARMS(g_nJOBNUM,'txtGakkoKbn');
        vGAKO_KBN := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'txtGakkoKbn');
        g_sGAKO_KBN := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtGakkoKbn', 0, vGAKO_KBN);
--  2024/08/30 ZCZL.caijiacun Update end
        --就学指定校
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.014:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_sGAKO := KKBPK5551.GETPARMS(g_nJOBNUM,'txtShugakuShiteikou');
        objShugakuShiteikou := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtShugakuShiteikou');
        g_sGAKO := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShugakuShiteikou',0, objShugakuShiteikou);
--  2024/10/30 ZCZL.WANGYUNING UPDATE END
        bRTN := FUNC_GET_GAKOCD(g_sGAKO, g_sGAKO_ED, g_sSYOGAKO_ED, g_sTYUGAKO_ED);
        IF NOT bRTN THEN
           RETURN FALSE;
        END IF;
        --発行日
        g_sHAKKOBI := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHakkoYmd');
        --支援措置対象マスク
--  2024/08/30 ZCZL.caijiacun Update start 0.3.000.002:IT_GKB_00075対応
--         g_sSHIENSOCHI := KKBPK5551.GETPARMS(g_nJOBNUM,'txtShinenSochi');
        vSHIENSOCHI := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'txtShinenSochi');
        g_sSHIENSOCHI := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtShinenSochi', 0, vSHIENSOCHI);
--  2024/08/30 ZCZL.caijiacun Update end
        --発行履歴
--  2024/08/30 ZCZL.caijiacun Update start 0.3.000.002:IT_GKB_00075対応
--         g_sHakkoRireki := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHakkoRireki');
        vHakkoRireki := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'txtHakkoRireki');
        g_sHakkoRireki := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtHakkoRireki', 0, vHakkoRireki);
--  2024/08/30 ZCZL.caijiacun Update end
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B01PINIT;
    --------------------------------------------------------
    --  機能概要      : バッチステップ処理パラメータ取得処理
    --  パラメータ    : i_STEPSEQ     バッチジョブステップ連番
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun 2024/06/06
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
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun 2024/06/12
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
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun   2024/06/12
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE
        RETURN NUMBER
    IS
        bRTN                BOOLEAN;                              --戻り値
        nRTN                PLS_INTEGER;                          --戻り値
        nCOUNT              NUMBER;
        aCONSPRM            A_CONS_PRM;
        nLENGTH             NUMBER;
        rGKBWL700R001       GKBWL700R001%ROWTYPE;                 --学校選択制案内書ワーク
        rGKBWL130R092       GKBWL130R092%ROWTYPE;                 --学校選択制案内書発送者一覧ワーク
        rGKBWL700R002       GKBWL700R002%ROWTYPE;                 --学校選択制調査書小・中学校用ワーク
        nPRMCTL             NUMBER;                               --抑止レベル３制御の要否
        sCHOMEI_BANCHI      NVARCHAR2(1000);                      --住所マスク文字列
        sSHIMEIKANA         NVARCHAR2(200);                       --氏名カナ
        sSHIMEI             NVARCHAR2(200);                       --氏名漢字
        sGENJUSHO           NVARCHAR2(1000);                      --住所編集取得
        sBIRTHDAY           NVARCHAR2(20);                        --生年月日
        nMAEMOJILEN         NUMBER;
        nUSHIROMOJILEN      NUMBER;
        nNUMLENGTH          NUMBER;
--  2024/11/26 ZCZL.ZHANGLEI UPDATE 0.3.000.017:IT_GKC_00329横展開対応
        --nBUNSHOBANGO        NUMBER;
        nBUNSHOBANGO        NVARCHAR2(1000);
        TYPE  REC_GKATHAKKORIREKI IS RECORD(
          GYOMU_CD                GKATHAKKORIREKI.GYOMU_CD%TYPE,
          KOJIN_NO                GKATHAKKORIREKI.KOJIN_NO%TYPE,
          CHOHYO_CD               GKATHAKKORIREKI.CHOHYO_CD%TYPE,
          NENDO                   GKATHAKKORIREKI.NENDO%TYPE,
          SHORI_KBN               GKATHAKKORIREKI.SHORI_KBN%TYPE,
          TSUCHISHO_SHUBETSU      GKATHAKKORIREKI.TSUCHISHO_SHUBETSU%TYPE,
          HAKKOBI                 GKATHAKKORIREKI.HAKKOBI%TYPE,
          HAKKO_JIKAN             GKATHAKKORIREKI.HAKKO_JIKAN%TYPE,
          HAKKO_MAISU             GKATHAKKORIREKI.HAKKO_MAISU%TYPE,
          HAKKO_SHOKUINKOJIN_NO   GKATHAKKORIREKI.HAKKO_SHOKUINKOJIN_NO%TYPE,
          SOFUBI                  GKATHAKKORIREKI.SOFUBI%TYPE,
          TSUCHI_BASHO            GKATHAKKORIREKI.TSUCHI_BASHO%TYPE,
          BUNSHOBANGO_SETTO       GKATHAKKORIREKI.BUNSHOBANGO_SETTO%TYPE,
          BUNSHOBANGO             GKATHAKKORIREKI.BUNSHOBANGO%TYPE,
          BUNSHOBANGO_SETSUBI     GKATHAKKORIREKI.BUNSHOBANGO_SETSUBI%TYPE,
          TSUCHI_KOJIN_NO         GKATHAKKORIREKI.TSUCHI_KOJIN_NO%TYPE,
          TENSAKI_JICHI_CD        GKATHAKKORIREKI.TENSAKI_JICHI_CD%TYPE,
          SYS_TANMATSU_NO         GKATHAKKORIREKI.SYS_TANMATSU_NO%TYPE
        );
        rGKATHAKKORIREKI    REC_GKATHAKKORIREKI;
        nCONT                     NUMBER;
        sDATE1                    NVARCHAR2(20);
--2025/10/16 CTC.BAI Add start 1.0.300.000:帳票アウトソーシング連番対応
        TYPE MC_CURSOR IS REF CURSOR;
        VSQL                      VARCHAR2(2000);
        CURSOR1                   MC_CURSOR;
        r                         GKBWSENTAKUSEI%ROWTYPE;
--2025/10/16 CTC.BAI Add end
    BEGIN
        --初期処理
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00010対応
--        g_nCNT := GKBFKTBLCNT('GKBWSENTAKUSEI',NULL);
        g_nCNT := GKBFKTBLCNT('GKBWSENTAKUSEI',' BATCHKBN = ' || c_BATCH || ' AND WSNUM = ''' || g_sWSNUM || '''');
        nCOUNT := 0;

--2025/10/16 CTC.BAI UPDATE start 1.0.300.000:帳票アウトソーシング連番対応
--        FOR r IN (SELECT *
--                    FROM GKBWSENTAKUSEI
--                   WHERE WSNUM = g_sWSNUM
--                     AND BATCHKBN = 2
--                     AND JOBNUM = g_nJOBNUM
--                ORDER BY JIDO_KOKUSEKI,
--                         GAKKO_KBN_CD,
--                         GAKKOBLOCK_CD,
--                         SHUGAKUSHITEIKOU,
--                         HOGOSHA_KOJIN_NO
--        ) LOOP
        VSQL := 'SELECT * FROM GKBWSENTAKUSEI WHERE WSNUM = ''' || g_sWSNUM || ''' AND BATCHKBN = 2 AND JOBNUM = ' || g_nJOBNUM || '';
        IF KKAPK0010.FTrim (g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
            VSQL := VSQL || ' ORDER BY ' || g_rJSTP.ORDERBYCLAUSE;
        END IF;
        OPEN CURSOR1 FOR VSQL;
        LOOP
          FETCH CURSOR1 INTO r;
          EXIT WHEN CURSOR1%NOTFOUND;
--2025/10/16 CTC.BAI UPDATE end
          nCOUNT := nCOUNT + 1;
          
          FOR rGKBTTSUCHISHOJKN IN (
              SELECT DATE1,
                     CHOHYO_KBN
                FROM GKBTTSUCHISHOJKN
               WHERE CHOHYO_KBN IN ('29','30','31','32')
                 AND GAKO_CD =  r.SHUGAKUSHITEIKOU
          ) LOOP
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.010:IT_GKB_00286横展開対応
--              sDATE1 := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(rGKBTTSUCHISHOJKN.DATE1),'YYYY/MM/DD'),12);
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
              --sDATE1 := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(rGKBTTSUCHISHOJKN.DATE1),12);
              sDATE1 := KKAPK0020.FDAYEDIT20(rGKBTTSUCHISHOJKN.DATE1,0,3,0);
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
              CASE rGKBTTSUCHISHOJKN.CHOHYO_KBN
                WHEN '29' THEN
                  --案内書提出期限_小学校
                  g_dANNAISHOU_KIGEN_ANNAISHOU_SGAKKOU := sDATE1;
                WHEN '30' THEN
                  --案内書提出期限_中学校
                  g_dANNAISHOU_KIGEN_ANNAISHOU_CGAKKOU := sDATE1;
                WHEN '31' THEN
                  --調査書提出期限_小学校
                  g_dCHOUSASHO_KIGEN_CHOUSASHO_SGAKKOU := sDATE1;
                WHEN '32' THEN
                  --調査書提出期限_中学校
                  g_dCHOUSASHO_KIGEN_CHOUSASHO_CGAKKOU := sDATE1;
               END CASE;
          END LOOP;
          
          CASE g_rJSTP.Chohyoid
            WHEN 'GKB700R001' THEN
              rGKBWL700R001 := NULL;
              --NO
              rGKBWL700R001.NO := nCOUNT;
--2025/10/16 CTC.BAI Add start 1.0.300.000:帳票アウトソーシング連番対応
              rGKBWL700R001.KYOTSU_TSUSU_RENBAN    := LPAD(nCOUNT,6,'0');                                   -- 業務共通_通数連番
              rGKBWL700R001.KYOTSU_PAGE_RENBAN     := NULL;                                                 -- 業務共通_頁連番
              rGKBWL700R001.KYOTSU_DOFU_RENBAN     := NULL;                                                 -- 業務共通_同封内連番
              rGKBWL700R001.KYOTSU_DOFU_MAISU      := NULL;                                                 -- 業務共通_同封内枚数
              rGKBWL700R001.KYOTSU_YUBIN_K_KBN     := NULL;                                                 -- 業務共通_郵便局区分
              rGKBWL700R001.KYOTSU_YUHEN_KBN       := r.YUHEN_KBN;                                          -- 業務共通_郵返区分
              rGKBWL700R001.KYOTSU_CHOSHU_KBN      := NULL;                                                 -- 業務共通_徴収区分
--  2025/12/05 CTC.NI UPDATE START 1.0.402.000:不具合対応
              --rGKBWL700R001.KYOTSU_GAKKO_KBN       := r.GAKKO_KBN_CD;                                       -- 業務共通_学校区分
              rGKBWL700R001.KYOTSU_GAKKO_KBN       := LPAD(r.GAKKO_KBN_CD, 2, '0');                         -- 業務共通_学校区分
--  2025/12/05 CTC.NI UPDATE START 1.0.402.000:不具合対応
              rGKBWL700R001.KYOTSU_YOBI_AREA1      := NULL;                                                 -- 業務共通_予備エリア1
              rGKBWL700R001.KYOTSU_YOBI_AREA2      := NULL;                                                 -- 業務共通_予備エリア2
              rGKBWL700R001.KYOTSU_YOBI_AREA3      := NULL;                                                 -- 業務共通_予備エリア3
              rGKBWL700R001.KYOTSU_YOBI_AREA4      := NULL;                                                 -- 業務共通_予備エリア4
              rGKBWL700R001.KYOTSU_YOBI_AREA5      := NULL;                                                 -- 業務共通_予備エリア5
              rGKBWL700R001.KYOTSU_YOBI_AREA6      := NULL;                                                 -- 業務共通_予備エリア6
              rGKBWL700R001.KYOTSU_YOBI_AREA7      := NULL;                                                 -- 業務共通_予備エリア7
              rGKBWL700R001.KYOTSU_YOBI_AREA8      := NULL;                                                 -- 業務共通_予備エリア8
              rGKBWL700R001.KYOTSU_YOBI_AREA9      := NULL;                                                 -- 業務共通_予備エリア9
              rGKBWL700R001.KYOTSU_YOBI_AREA10     := NULL;                                                 -- 業務共通_予備エリア10
              rGKBWL700R001.KYOTSU_YOBI_AREA11     := NULL;                                                 -- 業務共通_予備エリア11
              rGKBWL700R001.KYOTSU_YOBI_AREA12     := NULL;                                                 -- 業務共通_予備エリア12
--2025/10/16 CTC.BAI Add end
              --有支援措置対象の場合
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--              IF g_sSHIENSOCHI = 0 THEN
              IF g_sSHIENSOCHI = 1 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
                sCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', r.JIDO_KOJIN_NO, g_sTANTOCODE,g_sWSNUM,r.SOFU_JUSHO, nPRMCTL,2);
                IF r.SOFU_JUSHO IS NOT NULL AND nPRMCTL = 0 THEN
                  rGKBWL700R001.ATESAKI_YUBIN_NO := r.SOFU_YUBIN;
                  rGKBWL700R001.ATESAKI_KATAGAKI := r.ATESAKI_KATAGAKI;
                ELSE
                  rGKBWL700R001.ATESAKI_YUBIN_NO := NULL;
                  rGKBWL700R001.ATESAKI_KATAGAKI := NULL;
                END IF;
                IF r.SOFU_JUSHO IS NOT NULL THEN
                  --宛先町名番地
                  rGKBWL700R001.ATESAKI_CHOMEI_BANCHI := sCHOMEI_BANCHI;
                ELSE
                  rGKBWL700R001.ATESAKI_CHOMEI_BANCHI := NULL;
                END IF;
              END IF;
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--              IF g_sSHIENSOCHI = 1 THEN
              IF g_sSHIENSOCHI = 0 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
                --宛先郵便番号
                rGKBWL700R001.ATESAKI_YUBIN_NO := r.SOFU_YUBIN;
                --宛先町名番地
                rGKBWL700R001.ATESAKI_CHOMEI_BANCHI := r.SOFU_JUSHO;
                --宛先方書
                rGKBWL700R001.ATESAKI_KATAGAKI := r.ATESAKI_KATAGAKI;
              END IF;
              --宛先
--  2025/07/01 CTC.GL UPDATE Start 1.0.010.001:GKB_QA17602対応
              --rGKBWL700R001.ATESAKI               :=  r.ATESAKI;
--  2025/07/01 CTC.GL UPDATE End
              --カスタマバーコード
              rGKBWL700R001.BC_NO                 :=  r.YUBIN_NOBC;
              --文書番号
              IF g_rBUNNUM_annaisho.NUMUMUFLG = 0 THEN
                rGKBWL700R001.BUNSHO_NO           :=  g_rBUNNUM_annaisho.NUM;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                rGKBWL700R001.BUNSHO_NO  := KKAPK0010.FALPZENHANHENKAN(rGKBWL700R001.BUNSHO_NO ,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
              ELSE
                rGKBWL700R001.BUNSHO_NO           :=  NULL;
              END IF;
              --送付日
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応            
              --GKBWL700R001.SOFUBI                := r.SOFUBI;
              rGKBWL700R001.SOFUBI                := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(r.SOFUBI, 0),' ',''),'　','');
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応     
              
              --教育委員会名
              rGKBWL700R001.KYOIKU_KAI_MEI        :=  g_sKATAGAKI1;
              --教育長名
              rGKBWL700R001.KYOIKU_CHO_MEI        :=  g_sSHIMEI;
              --公印パス
              rGKBWL700R001.KOIN_PATH             :=  g_sKOINFILENAME;
              IF r.GAKKO_KBN_CD = 1 THEN
               --公印（省略）
               rGKBWL700R001.KOIN_SHORYAKU         := g_sKOIN_SHORYAKU_ANNAISHOU_SGAKKOU;
               --公印（注釈）
               rGKBWL700R001.KOIN_CHUSHAKU         := g_sKOIN_CHUSHAKU_ANNAISHOU_SGAKKOU;
               --タイトル
               rGKBWL700R001.TITLE                 := g_sCHOHYOTITLE_ANNAISHOU_SGAKKOU;
               --通知文
               rGKBWL700R001.TSUCHI_BUN            := REPLACE(g_sTSUCHIBUN_ANNAISHOU_SGAKKOU, chr(13) || chr(10), '#');
              END IF;
              IF r.GAKKO_KBN_CD = 2 THEN
               --公印（省略）
               rGKBWL700R001.KOIN_SHORYAKU         := g_sKOIN_SHORYAKU_ANNAISHOU_CGAKKOU;
               --公印（注釈）
               rGKBWL700R001.KOIN_CHUSHAKU         := g_sKOIN_CHUSHAKU_ANNAISHOU_CGAKKOU;
               --タイトル
               rGKBWL700R001.TITLE                 := g_sCHOHYOTITLE_ANNAISHOU_CGAKKOU;
               --通知文
               rGKBWL700R001.TSUCHI_BUN            := REPLACE(g_sTSUCHIBUN_ANNAISHOU_CGAKKOU, chr(13) || chr(10), '#');
              END IF;
              nRTN := GKBFKHMCTRL(r.JIDO_KOJIN_NO, 
                                  g_rJSTP.Chohyoid, 
                                  0, 
                                  g_r_shoushasho_seigyo, 
                                  sSHIMEIKANA, 
                                  sSHIMEI, 
                                  sBIRTHDAY);
              --児童生徒氏名カナ
              rGKBWL700R001.JIDO_SHIMEI_KANA      := sSHIMEIKANA;
              --児童生徒氏名漢字
              rGKBWL700R001.JIDO_SHIMEI_KANJI     := sSHIMEI;
              --表示生年月日
              rGKBWL700R001.HYOJI_SEINENGAPI      := sBIRTHDAY;
--  2024/11/21 JPJYS.LIUHUAIQI ADD 0.3.000.015:IT_GKB_00600対応 Start
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
              --sGENJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, r.CHOMEI_BANCHI, NULL, NULL, NULL);
              sGENJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, r.CHOMEI_BANCHI, NULL, r.KATAGAKI, NULL);
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
--  2024/11/21 JPJYS.LIUHUAIQI ADD 0.3.000.015:IT_GKB_00600対応 End
              --児童生徒現住所
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--              IF g_sSHIENSOCHI = 0 THEN
              IF g_sSHIENSOCHI = 1 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
                rGKBWL700R001.GEN_JUSHO := GAAPK0030.FDVJUSHO('GKB', r.JIDO_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sGENJUSHO, nPRMCTL, 2);
              END IF;
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--              IF g_sSHIENSOCHI = 1 THEN
              IF g_sSHIENSOCHI = 0 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
                rGKBWL700R001.GEN_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, r.CHOMEI_BANCHI, NULL, r.KATAGAKI, NULL);
              END IF;
              
              nRTN := GKBFKHMCTRL(r.JIDO_KOJIN_NO, g_rJSTP.Chohyoid, 1, g_r_shoushasho_seigyo, sSHIMEIKANA, sSHIMEI, sBIRTHDAY);
              --保護者氏名カナ
              rGKBWL700R001.HOGOSHA_SHIMEI_KANA   :=  sSHIMEIKANA;
              --保護者氏名漢字
              rGKBWL700R001.HOGOSHA_SHIMEI_KANJI  :=  sSHIMEI;
              --指定校名
              rGKBWL700R001.SHITEIKO_MEI          :=  r.SHUGAKUSHITEIKOU_MEI;
--  2025/07/01 CTC.GL UPDATE Start 1.0.010.001:GKB_QA17602対応
              --宛先
              rGKBWL700R001.ATESAKI               :=  sSHIMEI || '　' || '様';
--  2025/07/01 CTC.GL UPDATE End
              
              CASE r.GAKKO_KBN_CD
                WHEN 1 THEN
                  --調査書提出期限
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00226、IT_GKB_00227対応
--                  rGKBWL700R001.TEISHUTSU_KIGEN       :=  g_dCHOUSASHO_KIGEN_CHOUSASHO_SGAKKOU;
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応     
                  --rGKBWL700R001.TEISHUTSU_KIGEN       :=  g_dANNAISHOU_KIGEN_ANNAISHOU_SGAKKOU;
                  rGKBWL700R001.TEISHUTSU_KIGEN       :=  REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_dANNAISHOU_KIGEN_ANNAISHOU_SGAKKOU, 0),' ',''),'　','');
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応     
                  --特記事項     
                  --  2024/11/07 ZCZL.ZHANGLEI UPDATE 0.3.000.012:IT_GKB_00444対応
                  --rGKBWL700R001.TOKKI_JIKO            :=  g_sTOKKIJIKO_ANNAISHOU_SGAKKOU;
                  rGKBWL700R001.TOKKI_JIKO            :=  REPLACE(g_sTOKKIJIKO_ANNAISHOU_SGAKKOU, chr(13) || chr(10), '#');
                  --様式番号
                  rGKBWL700R001.YOSHIKI_NO            :=  g_sYOSHIKI_BANGO_ANNAISHOU_SGAKKOU;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                  rGKBWL700R001.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL700R001.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
                WHEN 2 THEN
                  --調査書提出期限
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00226、IT_GKB_00227対応
--                  rGKBWL700R001.TEISHUTSU_KIGEN       :=  g_dCHOUSASHO_KIGEN_CHOUSASHO_CGAKKOU;
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応     
                  --rGKBWL700R001.TEISHUTSU_KIGEN       :=  g_dANNAISHOU_KIGEN_ANNAISHOU_CGAKKOU;
                  rGKBWL700R001.TEISHUTSU_KIGEN       :=  REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_dANNAISHOU_KIGEN_ANNAISHOU_CGAKKOU, 0),' ',''),'　','');
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応      
                  --特記事項
                  --  2024/11/07 ZCZL.ZHANGLEI UPDATE 0.3.000.012:IT_GKB_00444対応
                  --rGKBWL700R001.TOKKI_JIKO            :=  g_sTOKKIJIKO_ANNAISHOU_CGAKKOU;
                  rGKBWL700R001.TOKKI_JIKO            :=  REPLACE(g_sTOKKIJIKO_ANNAISHOU_CGAKKOU, chr(13) || chr(10), '#');
                  --様式番号
                  rGKBWL700R001.YOSHIKI_NO            :=  g_sYOSHIKI_BANGO_ANNAISHOU_CGAKKOU;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                  rGKBWL700R001.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL700R001.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
                ELSE
                  NULL;
              END CASE;
              --お問い合わせ先を編集する
              IF KKAPK0030.FPRMSHUTOKU('GKB', '00KYOIKUKAI',r.KYOIKUIINKAI_CD, aCONSPRM, nLENGTH) = c_OK THEN
                --お問い合わせ先１
                rGKBWL700R001.TOIAWASESAKI1         :=  aCONSPRM(1);
                --お問い合わせ先２
                rGKBWL700R001.TOIAWASESAKI2         :=  aCONSPRM(6);
                --お問い合わせ先３
                rGKBWL700R001.TOIAWASESAKI3         :=  aCONSPRM(7);
              ELSE
                rGKBWL700R001.TOIAWASESAKI1 := NULL;
                rGKBWL700R001.TOIAWASESAKI2 := NULL;
                rGKBWL700R001.TOIAWASESAKI3 := NULL;
              END IF;
              --児童生徒宛名番号
              rGKBWL700R001.KOJIN_NO := r.JIDO_KOJIN_NO;
              --保護者宛名番号
              rGKBWL700R001.HOGOSYA_KOJIN_NO := r.HOGOSHA_KOJIN_NO;
              --改ページキー
              rGKBWL700R001.BREAK_NO              :=  nCOUNT;
              --端末番号
              rGKBWL700R001.WSNUM                 :=  g_sWSNUM;
              --即時バッチ区分
              rGKBWL700R001.BATCHKBN              :=  2;
              --ジョブNO
              rGKBWL700R001.JOBNUM                :=  g_nJOBNUM;
              INSERT INTO GKBWL700R001 VALUES rGKBWL700R001;
              --文書番号の退避
              g_rHOKANBUNNUM(nCOUNT).nKOJINNUM := r.JIDO_KOJIN_NO;
              --  2024/10/17 ZCZL.ZHANGLEI UPDATE 0.3.000.007:IT_GKB_00260対応
              --g_rHOKANBUNNUM(nCOUNT).sBUNNUM := g_rBUNNUMEDITKEKA.NUM;
              g_rHOKANBUNNUM(nCOUNT).sBUNNUM := g_rBUNNUM_annaisho.NUM;
              
--  2024/09/26 ZCZL.WANGMING ADD START 0.3.000.005:仕様変更　IT_GKB_00010対応
              --グローバル変数.CSV出力件数のカウントアップを行う。
              g_nCSVCNT := g_nCSVCNT + 1;
--  2024/09/26 ZCZL.WANGMING ADD END
              --発行履歴レコード作成
              IF g_sHakkoRireki = 0 THEN
                
                --文書番号（編集済み）
                g_cBUNNUM := g_rBUNNUMEDITKEKA.NUM;
                --文書番号（編集前文字）の LENGTH
                nMAEMOJILEN := LENGTH(g_rBUNNUMSRCINF.MAEMOJI);
                --文書番号（後ろ文字）の LENGTH
                nUSHIROMOJILEN := LENGTH(g_rBUNNUMSRCINF.USHIROMOJI);
                --文書番号（編集前）の LENGTH
                nNUMLENGTH := LENGTH(g_cBUNNUM) - nUSHIROMOJILEN - nMAEMOJILEN;
                --文書番号（編集前）の取得
--  2024/11/26 ZCZL.ZHANGLEI UPDATE 0.3.000.017:IT_GKC_00329横展開対応
                --nBUNSHOBANGO := TO_NUMBER(KKAPK0010.FSTRCNV(SUBSTR(g_cBUNNUM, nMAEMOJILEN+1, nNUMLENGTH),1));
                nBUNSHOBANGO := KKAPK0010.FSTRCNV(SUBSTR(g_cBUNNUM, nMAEMOJILEN+1, nNUMLENGTH),1);
                
                rGKATHAKKORIREKI.GYOMU_CD               :=  'GKB';                                                    --業務コード
                rGKATHAKKORIREKI.KOJIN_NO               :=  r.JIDO_KOJIN_NO;                                          --宛名番号
                rGKATHAKKORIREKI.CHOHYO_CD              :=  g_rJSTP.CHOHYONUM;                                        --帳票コード
                rGKATHAKKORIREKI.NENDO                  :=  SUBSTR(g_nHAKKOBI,1,4);                                   --年度
                rGKATHAKKORIREKI.SHORI_KBN              :=  1;                                                        --処理区分
                --通知書種別
                CASE r.GAKKO_KBN_CD
                  WHEN 1 THEN
                    rGKATHAKKORIREKI.TSUCHISHO_SHUBETSU := g_sCHOHYOTITLE_ANNAISHOU_SGAKKOU;
                  WHEN 2 THEN
                    rGKATHAKKORIREKI.TSUCHISHO_SHUBETSU := g_sCHOHYOTITLE_ANNAISHOU_CGAKKOU;
                  ELSE
                    NULL;
                END CASE;
                rGKATHAKKORIREKI.HAKKOBI                :=  TO_CHAR(SYSDATE,'YYYYMMDD');                               --発行日
                rGKATHAKKORIREKI.HAKKO_JIKAN            :=  g_nTIME;                                                   --発行時間
                rGKATHAKKORIREKI.HAKKO_MAISU            :=  1;                                                         --発行枚数
                rGKATHAKKORIREKI.HAKKO_SHOKUINKOJIN_NO  :=  g_sTANTOCODE;                                              --発行職員宛名番号
                rGKATHAKKORIREKI.SOFUBI                 :=  g_nHAKKOBI;                                                --送付日
                rGKATHAKKORIREKI.TSUCHI_BASHO           :=  NULL;                                                      --通知場所
                rGKATHAKKORIREKI.BUNSHOBANGO_SETTO      :=  g_rBUNNUMSRCINF.MAEMOJI;                                   --文書番号接頭語
                rGKATHAKKORIREKI.BUNSHOBANGO            :=  nBUNSHOBANGO;                                              --文書番号
                rGKATHAKKORIREKI.BUNSHOBANGO_SETSUBI    :=  g_rBUNNUMSRCINF.USHIROMOJI;                                --文書番号接尾語
                rGKATHAKKORIREKI.TSUCHI_KOJIN_NO        :=  r.HOGOSHA_KOJIN_NO;                                        --通知対象者宛名番号
                rGKATHAKKORIREKI.TENSAKI_JICHI_CD       :=  NULL;                                                      --転出先自治体コード
                rGKATHAKKORIREKI.SYS_TANMATSU_NO        :=  g_sWSNUM;                                                  --更新端末番号
                --発行履歴作成
                nRTN := GKAFKHAKKOR(rGKATHAKKORIREKI.GYOMU_CD,
                                    rGKATHAKKORIREKI.KOJIN_NO,
                                    rGKATHAKKORIREKI.CHOHYO_CD,
                                    rGKATHAKKORIREKI.NENDO,
                                    rGKATHAKKORIREKI.SHORI_KBN,
                                    rGKATHAKKORIREKI.TSUCHISHO_SHUBETSU,
                                    rGKATHAKKORIREKI.HAKKOBI,
                                    rGKATHAKKORIREKI.HAKKO_JIKAN,
                                    rGKATHAKKORIREKI.HAKKO_MAISU,
                                    rGKATHAKKORIREKI.HAKKO_SHOKUINKOJIN_NO,
                                    rGKATHAKKORIREKI.SOFUBI,
                                    rGKATHAKKORIREKI.TSUCHI_BASHO,
                                    rGKATHAKKORIREKI.BUNSHOBANGO_SETTO,
                                    rGKATHAKKORIREKI.BUNSHOBANGO,
                                    rGKATHAKKORIREKI.BUNSHOBANGO_SETSUBI,
                                    rGKATHAKKORIREKI.TSUCHI_KOJIN_NO,
                                    rGKATHAKKORIREKI.TENSAKI_JICHI_CD,
                                    rGKATHAKKORIREKI.SYS_TANMATSU_NO);
              END IF;
              --  2024/10/21 ZCZL.ZHANGLEI DEL 0.3.000.008:IT_GKB_00248対応
              --発送者文字切れリストの作成
              --BRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE, 'GKB700R001', 1, nCONT);
              --本番、枝番をカウントアップした文書番号編集結果を取得する。
              IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (g_rBUNNUMSRCINF.NUMINCTYPE = 1 OR g_rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
                KKAPK0040.SBunNumIc(g_rBUNNUMSRCINF, g_rBUNNUMEDITKEKA);
                --  2024/10/17 ZCZL.ZHANGLEI UPDATE 0.3.000.007:IT_GKB_00260対応
                --g_rBUNNUM_shoushasho := g_rBUNNUMEDITKEKA;
                g_rBUNNUM_annaisho   := g_rBUNNUMEDITKEKA;
                --文書番号編集結果を取得
                g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
              END IF;
            WHEN 'GKB130R002' THEN
              rGKBWL130R092 := NULL;
              --ソート順
              rGKBWL130R092.NO                    :=  nCOUNT;
              --作成年月日
              rGKBWL130R092.SAKUSEI_YMD           :=  TO_CHAR(SYSDATE,'YYYY/MM/DD');
              --タイトル
              rGKBWL130R092.TITLE                 :=  '学校選択制案内書発送者一覧';
              IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
                --文書番号
                FOR i IN 1..g_rHOKANBUNNUM.COUNT LOOP
                  IF g_rHOKANBUNNUM(i).nKOJINNUM = r.JIDO_KOJIN_NO THEN
                    rGKBWL130R092.BUNSHO_NO       :=  g_rHOKANBUNNUM(i).sBUNNUM;
                    EXIT;
                  END IF;
                END LOOP;
              END IF;
              --発行年月日
              rGKBWL130R092.HAKKO_YMD             :=  r.SOFUBI;
              --送付先氏名
              rGKBWL130R092.SOFUSAKI_SHIMEI       :=  r.ATESAKI;
              
              --有支援措置対象
              sGENJUSHO := GAAPK0010.FADDRESSEDIT(1,NULL,r.SOFU_JUSHO,NULL,r.ATESAKI_KATAGAKI,NULL);
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--              IF g_sSHIENSOCHI = 0 THEN
              IF g_sSHIENSOCHI = 1 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
                sCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', r.HOGOSHA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sGENJUSHO, nPRMCTL, 2);
                IF r.SOFU_JUSHO IS NOT NULL AND nPRMCTL = 0 THEN
                  --送付先郵便番号
                  rGKBWL130R092.SOFUSAKI_YUBIN_NO := sGENJUSHO;
                END IF;
                IF r.SOFU_JUSHO IS NOT NULL THEN
                  --送付先住所
                  rGKBWL130R092.SOFUSAKI_JUSHO := sCHOMEI_BANCHI;
                END IF;
              END IF;
              --無支援措置対象
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--              IF g_sSHIENSOCHI = 1 THEN
              IF g_sSHIENSOCHI = 0 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
                --送付先郵便番号
                rGKBWL130R092.SOFUSAKI_YUBIN_NO := r.SOFU_YUBIN;
                --送付先住所
                rGKBWL130R092.SOFUSAKI_JUSHO := sGENJUSHO;
              END IF;
              
              nRTN := GKBFKHMCTRL(r.JIDO_KOJIN_NO, g_rJSTP.Chohyoid, 0, g_r_shoushasho_seigyo, sSHIMEIKANA, sSHIMEI, sBIRTHDAY);
              --児童生徒氏名カナ
              rGKBWL130R092.JIDO_SHIMEI_KANA      := sSHIMEIKANA;
              --児童生徒氏名漢字
              rGKBWL130R092.JIDO_SHIMEI_KANJI     := sSHIMEI;
              --表示生年月日
              rGKBWL130R092.SEINENGAPI            := sBIRTHDAY;
              --性別
              rGKBWL130R092.SEIBETSU              :=  r.SEIBETSU;
              --児童生徒_支援措置  
              rGKBWL130R092.JIDO_SHIENSOCHI       :=  r.JIDO_SHIENSOCHI;

              nRTN := GKBFKHMCTRL(r.JIDO_KOJIN_NO, g_rJSTP.Chohyoid, 1, g_r_shoushasho_seigyo, sSHIMEIKANA, sSHIMEI, sBIRTHDAY);
              --保護者氏名カナ     
              rGKBWL130R092.HOGOSHA_SHIMEI_KANA   :=  sSHIMEIKANA;
              --保護者氏名漢字     
              rGKBWL130R092.HOGOSHA_SHIMEI_KANJI  :=  sSHIMEI;
              --児童生徒との関係   
              rGKBWL130R092.HOGOSHA_ZOKUGARA      :=  r.HOGOSHA_ZOKUGARA;
              --保護者_支援措置    
              rGKBWL130R092.HOGOSHA_SHIENSOCHI    :=  r.HOGOSHA_SHIENSOCHI;
              --学校名             
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00225、IT_GKB_00262、IT_GKB_00265対応
--              rGKBWL130R092.GAKKO_MEI             :=  r.SHUGAKUSHITEIKOU;
              rGKBWL130R092.GAKKO_MEI             :=  r.SHUGAKUSHITEIKOU_MEI;
              --件数               
              rGKBWL130R092.KENSU                 :=  g_nCNT;
              --学校コード         
              rGKBWL130R092.GAKKO_CD              :=  r.SHUGAKUSHITEIKOU;
              --児童生徒氏名_ラベル
              rGKBWL130R092.JIDO_SHIMEI_LABEL     :=  '児童生徒氏名';
              --保護者氏名_ラベル  
              rGKBWL130R092.HOGOSHA_SHIMEI_LABEL  :=  '保護者氏名';
              --学校/行政区_ラベル 
              rGKBWL130R092.GAKO_GYOSEIKU_LABEL  :=  '学校';
              IF r.JINKAKU_KBN = 1 THEN
                --人格区分
                rGKBWL130R092.JINKAKU_KBN           :=  '*';
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD 0.3.000.003:8月1日認識合わせの横展開
              ELSE
                rGKBWL130R092.JINKAKU_KBN           :=  NULL;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
              END IF;
              --改ページキー
              rGKBWL130R092.BREAK_NO              :=  TRUNC((nCOUNT-1)/10) + 1;
              --端末番号
              rGKBWL130R092.WSNUM                 :=  g_sWSNUM;
              --即時バッチ区分
              rGKBWL130R092.BATCHKBN              :=  2;
              --ジョブNO
              rGKBWL130R092.JOBNUM                :=  g_nJOBNUM;
              INSERT INTO GKBWL130R092 VALUES rGKBWL130R092;
            WHEN 'GKB700R002' THEN
              rGKBWL700R002 := NULL;
              --  2024/10/17 ZCZL.ZHANGLEI ADD START 0.3.000.007:IT_GKB_00260対応
              IF nCOUNT = 1 THEN
                --文書番号を取得する
                bRTN := KKBPK5551.FJBNSGet(g_nJOBNUM, g_rJSTP.STEPSEQ, g_rBUNNUMSRCINF);
                --文書番号編集結果を取得
                g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
                IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (g_rBUNNUMSRCINF.NUMINCTYPE = 1 OR g_rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
                  KKAPK0040.SBunNumIc(g_rBUNNUMSRCINF, g_rBUNNUMEDITKEKA);
                  g_rBUNNUM_shoushasho := g_rBUNNUMEDITKEKA;
                  g_rBUNNUM_annaisho   := g_rBUNNUMEDITKEKA;
                  --文書番号編集結果を取得
                  g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
                END IF;
              END IF;
              --  2024/10/17 ZCZL.ZHANGLEI ADD END
              --ソート順
              rGKBWL700R002.NO := nCOUNT;
--2025/10/16 CTC.BAI Add start 1.0.300.000:帳票アウトソーシング連番対応
              rGKBWL700R002.KYOTSU_TSUSU_RENBAN    := LPAD(nCOUNT,6,'0');                                   -- 業務共通_通数連番
              rGKBWL700R002.KYOTSU_PAGE_RENBAN     := NULL;                                                 -- 業務共通_頁連番
              rGKBWL700R002.KYOTSU_DOFU_RENBAN     := NULL;                                                 -- 業務共通_同封内連番
              rGKBWL700R002.KYOTSU_DOFU_MAISU      := NULL;                                                 -- 業務共通_同封内枚数
              rGKBWL700R002.KYOTSU_YUBIN_K_KBN     := NULL;                                                 -- 業務共通_郵便局区分
              rGKBWL700R002.KYOTSU_YUHEN_KBN       := r.YUHEN_KBN;                                          -- 業務共通_郵返区分
              rGKBWL700R002.KYOTSU_CHOSHU_KBN      := NULL;                                                 -- 業務共通_徴収区分
--  2025/12/05 CTC.NI UPDATE START 1.0.402.000:不具合対応
              --rGKBWL700R002.KYOTSU_GAKKO_KBN       := r.GAKKO_KBN_CD;                                       -- 業務共通_学校区分
              rGKBWL700R002.KYOTSU_GAKKO_KBN       := LPAD(r.GAKKO_KBN_CD, 2, '0');                         -- 業務共通_学校区分
--  2025/12/05 CTC.NI UPDATE END
              rGKBWL700R002.KYOTSU_YOBI_AREA1      := NULL;                                                 -- 業務共通_予備エリア1
              rGKBWL700R002.KYOTSU_YOBI_AREA2      := NULL;                                                 -- 業務共通_予備エリア2
              rGKBWL700R002.KYOTSU_YOBI_AREA3      := NULL;                                                 -- 業務共通_予備エリア3
              rGKBWL700R002.KYOTSU_YOBI_AREA4      := NULL;                                                 -- 業務共通_予備エリア4
              rGKBWL700R002.KYOTSU_YOBI_AREA5      := NULL;                                                 -- 業務共通_予備エリア5
              rGKBWL700R002.KYOTSU_YOBI_AREA6      := NULL;                                                 -- 業務共通_予備エリア6
              rGKBWL700R002.KYOTSU_YOBI_AREA7      := NULL;                                                 -- 業務共通_予備エリア7
              rGKBWL700R002.KYOTSU_YOBI_AREA8      := NULL;                                                 -- 業務共通_予備エリア8
              rGKBWL700R002.KYOTSU_YOBI_AREA9      := NULL;                                                 -- 業務共通_予備エリア9
              rGKBWL700R002.KYOTSU_YOBI_AREA10     := NULL;                                                 -- 業務共通_予備エリア10
              rGKBWL700R002.KYOTSU_YOBI_AREA11     := NULL;                                                 -- 業務共通_予備エリア11
              rGKBWL700R002.KYOTSU_YOBI_AREA12     := NULL;                                                 -- 業務共通_予備エリア12
--2025/10/16 CTC.BAI Add end
              --有支援措置対象の場合
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--              IF g_sSHIENSOCHI = 0 THEN
              IF g_sSHIENSOCHI = 1 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
                sCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', r.JIDO_KOJIN_NO, g_sTANTOCODE,g_sWSNUM,r.SOFU_JUSHO, nPRMCTL,2);
                IF r.SOFU_JUSHO IS NOT NULL AND nPRMCTL = 0 THEN
                  rGKBWL700R002.ATESAKI_YUBIN_NO := r.SOFU_YUBIN;
                  rGKBWL700R002.ATESAKI_KATAGAKI := r.ATESAKI_KATAGAKI;
                END IF;
                IF r.SOFU_JUSHO IS NOT NULL THEN
                  --宛先町名番地
                  rGKBWL700R002.ATESAKI_CHOMEI_BANCHI := sCHOMEI_BANCHI;
                END IF;
              END IF;
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--              IF g_sSHIENSOCHI = 1 THEN
              IF g_sSHIENSOCHI = 0 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
                --宛先郵便番号
                rGKBWL700R002.ATESAKI_YUBIN_NO := r.SOFU_YUBIN;
                --宛先町名番地
                rGKBWL700R002.ATESAKI_CHOMEI_BANCHI := r.SOFU_JUSHO;
                --宛先方書
                rGKBWL700R002.ATESAKI_KATAGAKI := r.ATESAKI_KATAGAKI;
              END IF;
              --宛先
--  2025/07/01 CTC.GL UPDATE Start 1.0.010.001:GKB_QA17602対応
              --rGKBWL700R002.ATESAKI := r.ATESAKI;
--  2025/07/01 CTC.GL UPDATE End
              --カスタマバーコード
              rGKBWL700R002.BC_NO := r.YUBIN_NOBC;
              --文書番号
              --  2024/10/17 ZCZL.ZHANGLEI UPDATE START 0.3.000.007:IT_GKB_00260対応
              --IF g_rBUNNUM_annaisho.NUMUMUFLG = 0 THEN
                --rGKBWL700R002.BUNSHO_NO := g_rBUNNUM_annaisho.NUM;
              IF g_rBUNNUM_shoushasho.NUMUMUFLG = 0 THEN  
                rGKBWL700R002.BUNSHO_NO := g_rBUNNUM_shoushasho.NUM;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                rGKBWL700R002.BUNSHO_NO  := KKAPK0010.FALPZENHANHENKAN(rGKBWL700R002.BUNSHO_NO ,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
              --  2024/10/17 ZCZL.ZHANGLEI UPDATE END
              END IF;
              --発送日
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応     
              --rGKBWL700R002.SOFUBI := r.SOFUBI;
              rGKBWL700R002.SOFUBI := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(r.SOFUBI, 0),' ',''),'　','');
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応     
              --教育委員会名
              rGKBWL700R002.KYOIKU_KAI_MEI := g_sKATAGAKI1;
              --教育長名
              rGKBWL700R002.KYOIKU_CHO_MEI := g_sSHIMEI;
              --公印パス
              rGKBWL700R002.KOIN_PATH := g_sKOINFILENAME;
              IF r.GAKKO_KBN_CD = 1 THEN
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.006:IT_GKB_00226、IT_GKB_00227対応
--               --公印（省略）
--               rGKBWL700R002.KOIN_SHORYAKU         := g_sKOIN_SHORYAKU_ANNAISHOU_SGAKKOU;
--               --公印（注釈）
--               rGKBWL700R002.KOIN_CHUSHAKU         := g_sKOIN_CHUSHAKU_ANNAISHOU_SGAKKOU;
--               --タイトル
--               rGKBWL700R002.TITLE                 := g_sCHOHYOTITLE_ANNAISHOU_SGAKKOU;
--               --通知文
--               rGKBWL700R002.TSUCHI_BUN            := REPLACE(g_sTSUCHIBUN_ANNAISHOU_SGAKKOU, chr(13) || chr(10), '#');
               --公印（省略）
               rGKBWL700R002.KOIN_SHORYAKU         := g_sKOIN_SHORYAKU_CHOUSASHO_SGAKKOU;
               --公印（注釈）
               rGKBWL700R002.KOIN_CHUSHAKU         := g_sKOIN_CHUSHAKU_CHOUSASHO_SGAKKOU;
               --タイトル
               rGKBWL700R002.TITLE                 := g_sCHOHYOTITLE_CHOUSASHO_SGAKKOU;
               --通知文
               rGKBWL700R002.TSUCHI_BUN            := REPLACE(g_sTSUCHIBUN_CHOUSASHO_SGAKKOU, chr(13) || chr(10), '#');
--  2024/10/11 ZCZL.WANGMING UPDATE END
              END IF;
              IF r.GAKKO_KBN_CD = 2 THEN
--  2024/10/11 ZCZL.WANGMING UPDATE START 0.3.000.006:IT_GKB_00226、IT_GKB_00227対応
--               --公印（省略）
--               rGKBWL700R002.KOIN_SHORYAKU         := g_sKOIN_SHORYAKU_ANNAISHOU_CGAKKOU;
--               --公印（注釈）
--               rGKBWL700R002.KOIN_CHUSHAKU         := g_sKOIN_CHUSHAKU_ANNAISHOU_CGAKKOU;
--               --タイトル
--               rGKBWL700R002.TITLE                 := g_sCHOHYOTITLE_ANNAISHOU_CGAKKOU;
--               --通知文
--               rGKBWL700R002.TSUCHI_BUN            := REPLACE(g_sTSUCHIBUN_ANNAISHOU_CGAKKOU, chr(13) || chr(10), '#');
               --公印（省略）
               rGKBWL700R002.KOIN_SHORYAKU         := g_sKOIN_SHORYAKU_CHOUSASHO_CGAKKOU;
               --公印（注釈）
               rGKBWL700R002.KOIN_CHUSHAKU         := g_sKOIN_CHUSHAKU_CHOUSASHO_CGAKKOU;
               --タイトル
               rGKBWL700R002.TITLE                 := g_sCHOHYOTITLE_CHOUSASHO_CGAKKOU;
               --通知文
               rGKBWL700R002.TSUCHI_BUN            := REPLACE(g_sTSUCHIBUN_CHOUSASHO_CGAKKOU, chr(13) || chr(10), '#');
--  2024/10/11 ZCZL.WANGMING UPDATE END
              END IF;
              --学校区分
              rGKBWL700R002.GAKKO_KBN := r.GAKKO_KBN_MEI;
              --調査票タイトル
              rGKBWL700R002.CHOSAHYO_TITLE := r.GAKKO_KBN_MEI || '希望調査票';
              
              
              nRTN := GKBFKHMCTRL(r.JIDO_KOJIN_NO, g_rJSTP.Chohyoid, 0, g_r_shoushasho_seigyo, sSHIMEIKANA, sSHIMEI, sBIRTHDAY);
              --児童生徒氏名カナ
              rGKBWL700R002.JIDO_SHIMEI_KANA      := sSHIMEIKANA;
              --児童生徒氏名漢字
              rGKBWL700R002.JIDO_SHIMEI_KANJI     := sSHIMEI;
              --表示生年月日
              rGKBWL700R002.HYOJI_SEINENGAPI      := sBIRTHDAY;
              
              nRTN := GKBFKHMCTRL(r.JIDO_KOJIN_NO, g_rJSTP.Chohyoid, 1, g_r_shoushasho_seigyo, sSHIMEIKANA, sSHIMEI, sBIRTHDAY);
              --保護者氏名カナ
              rGKBWL700R002.HOGOSHA_SHIMEI_KANA   :=  sSHIMEIKANA;
              --保護者氏名漢字
              rGKBWL700R002.HOGOSHA_SHIMEI_KANJI  :=  sSHIMEI;
--  2025/07/01 CTC.GL UPDATE Start 1.0.010.001:GKB_QA17602対応
              --宛先
              rGKBWL700R002.ATESAKI := sSHIMEI || '　' || '様';
--  2025/07/01 CTC.GL UPDATE End
              
              --選択可能学校
              rGKBWL700R002.SENTAKUKANO_GAKKO := r.HYOJI_SENTAKUKANO_GAKKO;
              
              CASE r.GAKKO_KBN_CD
                WHEN 1 THEN
                  --調査書提出期限
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応     
                  --rGKBWL700R002.KAITO_KIGEN           :=  g_dCHOUSASHO_KIGEN_CHOUSASHO_SGAKKOU;
                  rGKBWL700R002.KAITO_KIGEN           :=  REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_dCHOUSASHO_KIGEN_CHOUSASHO_SGAKKOU, 0),' ',''),'　','');
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応     
                  --特記事項     
                  --rGKBWL700R002.TOKKI_JIKO            :=  g_sTOKKIJIKO_CHOUSASHO_SGAKKOU;
                  rGKBWL700R002.TOKKI_JIKO            :=  REPLACE(g_sTOKKIJIKO_CHOUSASHO_SGAKKOU, chr(13) || chr(10), '#');
                  --様式番号
                  rGKBWL700R002.YOSHIKI_NO            :=  g_sYOSHIKI_BANGO_CHOUSASHO_SGAKKOU;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                  rGKBWL700R002.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL700R002.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
                WHEN 2 THEN
                  --調査書提出期限
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応     
                  --rGKBWL700R002.KAITO_KIGEN           :=  g_dCHOUSASHO_KIGEN_CHOUSASHO_CGAKKOU;
                  rGKBWL700R002.KAITO_KIGEN           :=  REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_dCHOUSASHO_KIGEN_CHOUSASHO_CGAKKOU, 0),' ',''),'　','');
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応     
                  --特記事項
                  --rGKBWL700R002.TOKKI_JIKO            :=  g_sTOKKIJIKO_CHOUSASHO_CGAKKOU;
                  rGKBWL700R002.TOKKI_JIKO            :=  REPLACE(g_sTOKKIJIKO_CHOUSASHO_CGAKKOU, chr(13) || chr(10), '#');
                  --様式番号
                  rGKBWL700R002.YOSHIKI_NO            :=  g_sYOSHIKI_BANGO_CHOUSASHO_CGAKKOU;
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                  rGKBWL700R002.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL700R002.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
                ELSE
                  NULL;
              END CASE;
              --児童生徒宛名番号
              rGKBWL700R002.KOJIN_NO := r.JIDO_KOJIN_NO;
              --保護者宛名番号
              rGKBWL700R002.HOGOSYA_KOJIN_NO := r.HOGOSHA_KOJIN_NO;
              
              --改ページキー
              rGKBWL700R002.BREAK_NO := nCOUNT;
              --端末番号
              rGKBWL700R002.WSNUM := g_sWSNUM;
              --即時バッチ区分
              rGKBWL700R002.BATCHKBN := 2;
              --ジョブNO
              rGKBWL700R002.JOBNUM := g_nJOBNUM;
              --学校選択制案内書ワークを登録する。
              INSERT INTO GKBWL700R002 VALUES rGKBWL700R002;
              --文書番号の退避
              g_rHOKANBUNNUM(nCOUNT).nKOJINNUM := r.JIDO_KOJIN_NO;
              g_rHOKANBUNNUM(nCOUNT).sBUNNUM := g_rBUNNUMEDITKEKA.NUM;
              
              --発行履歴レコード編集
              IF g_sHakkoRireki = 0 THEN
                
                --文書番号（編集済み）
                g_cBUNNUM := g_rBUNNUMEDITKEKA.NUM;
                --文書番号（編集前文字）の LENGTH
                nMAEMOJILEN := LENGTH(g_rBUNNUMSRCINF.MAEMOJI);
                --文書番号（後ろ文字）の LENGTH
                nUSHIROMOJILEN := LENGTH(g_rBUNNUMSRCINF.USHIROMOJI);
                --文書番号（編集前）の LENGTH
                nNUMLENGTH := LENGTH(g_cBUNNUM) - nUSHIROMOJILEN - nMAEMOJILEN;
                --文書番号（編集前）の取得
--  2024/11/26 ZCZL.ZHANGLEI UPDATE 0.3.000.017:IT_GKC_00329横展開対応
                --nBUNSHOBANGO := TO_NUMBER(KKAPK0010.FSTRCNV(SUBSTR(g_cBUNNUM, nMAEMOJILEN+1, nNUMLENGTH),1));
                nBUNSHOBANGO := KKAPK0010.FSTRCNV(SUBSTR(g_cBUNNUM, nMAEMOJILEN+1, nNUMLENGTH),1);
                
                rGKATHAKKORIREKI.GYOMU_CD               :=  'GKB';                                                    --業務コード
                rGKATHAKKORIREKI.KOJIN_NO               :=  r.JIDO_KOJIN_NO;                                          --宛名番号
                rGKATHAKKORIREKI.CHOHYO_CD              :=  g_rJSTP.CHOHYONUM;                                        --帳票コード
                rGKATHAKKORIREKI.NENDO                  :=  SUBSTR(g_nHAKKOBI,1,4);                                   --年度
                rGKATHAKKORIREKI.SHORI_KBN              :=  1;                                                        --処理区分
                --通知書種別
                CASE r.GAKKO_KBN_CD
                  WHEN 1 THEN
                    rGKATHAKKORIREKI.TSUCHISHO_SHUBETSU := g_sCHOHYOTITLE_CHOUSASHO_SGAKKOU;
                  WHEN 2 THEN
                    rGKATHAKKORIREKI.TSUCHISHO_SHUBETSU := g_sCHOHYOTITLE_CHOUSASHO_CGAKKOU;
                  ELSE
                    NULL;
                END CASE;
                rGKATHAKKORIREKI.HAKKOBI                :=  TO_CHAR(SYSDATE,'YYYYMMDD');                               --発行日
                rGKATHAKKORIREKI.HAKKO_JIKAN            :=  g_nTIME;                                                   --発行時間
                rGKATHAKKORIREKI.HAKKO_MAISU            :=  1;                                                         --発行枚数
                rGKATHAKKORIREKI.HAKKO_SHOKUINKOJIN_NO  :=  g_sTANTOCODE;                                              --発行職員宛名番号
                rGKATHAKKORIREKI.SOFUBI                 :=  g_nHAKKOBI;                                                --送付日
                rGKATHAKKORIREKI.TSUCHI_BASHO           :=  NULL;                                                      --通知場所
                rGKATHAKKORIREKI.BUNSHOBANGO_SETTO      :=  g_rBUNNUMSRCINF.MAEMOJI;                                   --文書番号接頭語
                rGKATHAKKORIREKI.BUNSHOBANGO            :=  nBUNSHOBANGO;                                              --文書番号
                rGKATHAKKORIREKI.BUNSHOBANGO_SETSUBI    :=  g_rBUNNUMSRCINF.USHIROMOJI;                                --文書番号接尾語
                rGKATHAKKORIREKI.TSUCHI_KOJIN_NO        :=  r.HOGOSHA_KOJIN_NO;                                        --通知対象者宛名番号
                rGKATHAKKORIREKI.TENSAKI_JICHI_CD       :=  NULL;                                                      --転出先自治体コード
                rGKATHAKKORIREKI.SYS_TANMATSU_NO        :=  g_sWSNUM;                                                  --更新端末番号
                --発行履歴作成
                nRTN := GKAFKHAKKOR(rGKATHAKKORIREKI.GYOMU_CD,
                                    rGKATHAKKORIREKI.KOJIN_NO,
                                    rGKATHAKKORIREKI.CHOHYO_CD,
                                    rGKATHAKKORIREKI.NENDO,
                                    rGKATHAKKORIREKI.SHORI_KBN,
                                    rGKATHAKKORIREKI.TSUCHISHO_SHUBETSU,
                                    rGKATHAKKORIREKI.HAKKOBI,
                                    rGKATHAKKORIREKI.HAKKO_JIKAN,
                                    rGKATHAKKORIREKI.HAKKO_MAISU,
                                    rGKATHAKKORIREKI.HAKKO_SHOKUINKOJIN_NO,
                                    rGKATHAKKORIREKI.SOFUBI,
                                    rGKATHAKKORIREKI.TSUCHI_BASHO,
                                    rGKATHAKKORIREKI.BUNSHOBANGO_SETTO,
                                    rGKATHAKKORIREKI.BUNSHOBANGO,
                                    rGKATHAKKORIREKI.BUNSHOBANGO_SETSUBI,
                                    rGKATHAKKORIREKI.TSUCHI_KOJIN_NO,
                                    rGKATHAKKORIREKI.TENSAKI_JICHI_CD,
                                    rGKATHAKKORIREKI.SYS_TANMATSU_NO);
              END IF;
--  2024/10/11 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00225、IT_GKB_00262、IT_GKB_00265対応
              --発送者文字切れリストの作成
              --  2024/10/21 ZCZL.ZHANGLEI DEL 0.3.000.008:IT_GKB_00248対応
              --BRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE, 'GKB700R002', 1, nCONT);
              --本番、枝番をカウントアップした文書番号編集結果を取得する。
              IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (g_rBUNNUMSRCINF.NUMINCTYPE = 1 OR g_rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
                KKAPK0040.SBunNumIc(g_rBUNNUMSRCINF, g_rBUNNUMEDITKEKA);
                g_rBUNNUM_shoushasho := g_rBUNNUMEDITKEKA;
                --  2024/10/17 ZCZL.ZHANGLEI DEL 0.3.000.007:IT_GKB_00260対応
                --g_rBUNNUM_annaisho   := g_rBUNNUMEDITKEKA;
                --文書番号編集結果を取得
                g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
              END IF;
            ELSE
              NULL;
          END CASE;
--  2024/09/26 ZCZL.WANGMING DELETE 0.3.000.005:仕様変更　IT_GKB_00010対応
--          g_nCSVCNT := g_nCSVCNT + 1;
        END LOOP;
--2025/10/16 CTC.BAI Add start 1.0.300.000:帳票アウトソーシング連番対応
        CLOSE CURSOR1;
--2025/10/16 CTC.BAI Add end
        --  2024/10/21 ZCZL.ZHANGLEI ADD START 0.3.000.008:IT_GKB_00248対応
        --発送者文字切れリストの作成
        CASE g_rJSTP.Chohyoid
            WHEN 'GKB700R001' THEN
              BRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE, 'GKB700R001', 1, nCONT);
            WHEN 'GKB700R002' THEN  
              BRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE, 'GKB700R002', 1, nCONT);
            ELSE
              NULL;
         END CASE;  
         --  2024/10/21 ZCZL.ZHANGLEI ADD END     
         --関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);
        -- 終了
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
--2025/10/16 CTC.BAI Add start 1.0.300.000:帳票アウトソーシング連番対応
            IF CURSOR1%ISOPEN THEN
              CLOSE CURSOR1;
            END IF;
--2025/10/16 CTC.BAI Add end
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN c_ERR;
    END FUNC_CSV_CREATE;
    --------------------------------------------------------
    --  機能概要      : 条件取得処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun   2024/06/12
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET
        RETURN BOOLEAN
    IS
    BEGIN
        --発行日_西暦
        g_nHAKKOBI := KKAPK0020.FNENDOHENKAN(g_sHAKKOBI);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_JYOKEN_GET;
    --------------------------------------------------------
    --  機能概要      : 条件入力チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun   2024/06/06
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;            --戻り値
        aGAKO                         KKBPK5551.tySPLIT_tbl;      --学校（リスト）
--  2024/10/30 ZCZL.WANGYUNING ADD 0.3.000.014:学校コードリスト仕様変更IT_GKB_00090の対応
        aGAKKOCD_CHK_LST         KKBPK5551.tySPLIT_tbl;   --変数.学校リスト
        vGAKOUKBN                NUMBER;                  --学校から学校区別の取得
--  2024/10/30 ZCZL.WANGYUNING ADD END
    BEGIN
        --ジョブナンバーをセット
        g_nJOBNUM := i_nJOBNUM;
--  2025/05/23 CTC.LIZIZHONG UPDATE 1.0.006.000:QA15755対応　Start
        IRTN := 0 ;
--  2025/05/23 CTC.LIZIZHONG UPDATE 1.0.006.000:QA15755対応　End          
        --バッチ初期処理
        bRTN := FUNC_B00INIT;
        IF NOT bRTN THEN
            o_vRESULT := g_sMESSAGE;
            RETURN;
        END IF;
        -- バッチ入力値取得
        bRTN := FUNC_B01PINIT;
--  2025/05/23 CTC.LIZIZHONG UPDATE 1.0.006.000:QA15755対応　Start        
      --基準日のチェック
        IRTN := FUNCHIZUKECHK(g_sHAKKOBI,1);
        IF IRTN <> 0 THEN
            o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,発行日が正しくありません。,;' ;
        ELSE
          VERRMSG := KKBPK5551.FJOKENDATECHK('GKB', g_sSHORIID, 0, 4, 1, g_sHAKKOBI);
          IF VERRMSG IS NOT NULL THEN
            o_vRESULT := o_vRESULT || VERRMSG;
          END IF;
        END IF;               
--  2025/05/23 CTC.LIZIZHONG UPDATE 1.0.006.000:QA15755対応 End　        
        bRTN := KKAPK0020.FISDATEW(g_sHAKKOBI);
        IF NOT bRTN THEN
--  2024/08/30 ZCZL.caijiacun Update 0.3.000.002:IT_GKB_00075対応
--          o_vRESULT := o_vRESULT || i_nJOBNUM || ',99999,発行日が正しくありません。,;';
          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,発行日が正しくありません。,;';
        END IF;
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.014:学校コードリスト仕様変更IT_GKB_00090の対応
        ---- 引数の学校（リスト）の配列化
        --aGAKO := KKBPK5551.FSplitStr (g_sGAKO_ED);
        --FOR i IN 1..aGAKO.COUNT LOOP
        --  CASE g_sGAKO_KBN
        --    WHEN 2 THEN
        --      IF g_sTYUGAKO_ED IS NOT NULL THEN
--  2024/08/30 ZCZL.caijiacun Update 0.3.000.002:IT_GKB_00075対応
--      --             o_vRESULT := o_vRESULT || i_nJOBNUM || ',99999,条件1で選択した学校区分と異なる学校が条件2で選択されています。,;';
        --          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件1で選択した学校区分と異なる学校が条件2で選択されています。,;';
        --      END IF;
        --    WHEN 3 THEN
        --      IF g_sSYOGAKO_ED IS NOT NULL THEN
--  2024/08/30 ZCZL.caijiacun Update 0.3.000.002:IT_GKB_00075対応
--      --             o_vRESULT := o_vRESULT || i_nJOBNUM || ',99999,条件1で選択した学校区分と異なる学校が条件2で選択されています。,;';
        --          o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,条件1で選択した学校区分と異なる学校が条件2で選択されています。,;';
        --      END IF;
        --    WHEN 1 THEN
        --      o_vRESULT := '';
        --    ELSE
        --      NULL;
        --  END CASE;
        --END LOOP;
        --学校区分と小学校コードの関連チェック
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_sGAKO, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 3, 1));
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
            --学校区分と選択された学校の関係性チェック
            IF g_sGAKO_KBN <> '0' THEN
              IF TO_NUMBER(g_sGAKO_KBN) <> vGAKOUKBN THEN
                IF o_vRESULT IS NOT NULL THEN
                  o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                ELSE
                  o_vRESULT := o_vRESULT || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                END IF;
              END IF;
            END IF;
        END LOOP;
--  2024/10/30 ZCZL.WANGYUNING UPDATE END
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun 2024/06/11
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        sSQL1                         NVARCHAR2(4000);
        sSELECT1                      NVARCHAR2(1000);
        sSELECT2                      NVARCHAR2(1000);
        sSQL1_1                       NVARCHAR2(2000);
        sSQL1_2                       NVARCHAR2(2000);
        sSQL2                         NVARCHAR2(2000);
        bRTN                          BOOLEAN;                         --戻り値
        nRTN                          NUMBER;                          --戻り値
        eEXCEPTION                    EXCEPTION;
        rGKBWSENTAKUSEIREC            GKBWSENTAKUSEI%ROWTYPE;          --選択制対象者データ
        rGKBWSENTAKUSEIREC_NULL       GKBWSENTAKUSEI%ROWTYPE;          --選択制対象者データ
        t_RATENA_REC                  GABTATENAKIHON%ROWTYPE;          --保護者宛名レコード
        t_RSOFU_REC                   GABTSOFUSAKI%ROWTYPE;            --保護者送付先レコード
        t_RATENA_REC2                 GABTATENAKIHON%ROWTYPE;          --児童生徒宛名レコード
        t_RSOFU_REC2                  GABTSOFUSAKI%ROWTYPE;            --児童生徒送付先レコード
        TYPE MC_CURSOR IS REF CURSOR;
        cCURSOR                       MC_CURSOR;
        cCURSOR2                      MC_CURSOR;
        aPRM                          A_CONS_PRM;
        nKOJINSETAIKBN                NUMBER;                          --個人世帯区分（0：個人、1：世帯）
        nYOKUSHIKBN                   NUMBER;                          --抑止区分（1：支援措置、2：仮支援措置、4：その他抑止）
        nIDOYOKUSHIKBN                NUMBER;                          --異動抑止区分（0：非該当、1：警告、2：論理）
        nHAKKOYOKUSHIKBN              NUMBER;                          --発行抑止区分（0：非該当、1：警告、2：論理）
        nSHOKAIYOKUSHIKBN             NUMBER;                          --照会抑止区分（0：非該当、1：警告、2：論理）
        vSHORICHUIKBN                 NVARCHAR2(1000);                 --処理注意区分（任意設定）
        TYPE MR_TAISHOUJIDOU IS RECORD(
            KOJIN_NO                  NUMBER,                          --宛名番号
            SHUGAKUSHITEIKOU          NUMBER,                          --就学指定校
            KYOIKUIINKAI_CD           NUMBER,                          --教育委員会コード
            GAKKOSHIKIBETSU           NVARCHAR2(5),                    --学校区識別番号
            GAKKO_KBN_CD              NUMBER,                          --学校区分コード
            RENBAN                    NUMBER,                          --連番
            GAKKOBLOCK_CD             NVARCHAR2(3)                     --学校ブロックコード
--2025/10/16 CTC.BAI Add start 1.0.300.000:帳票アウトソーシング連番対応
            ,YUHEN_KBN                 NUMBER                           --郵返区分
--2025/10/16 CTC.BAI Add end
        );
        rTAISHOUJIDOU                 MR_TAISHOUJIDOU;                 --対象児童カーソル

        TYPE MR_GKBFKGK IS RECORD(
            SENTAKUKANO_EDABAN        NUMBER,                          --選択可能学校枝番
            GAKKO_MEI                 NVARCHAR2(60),                   --選択可能学校名
            GAKKO_JUSHO               NVARCHAR2(300),                  --選択可能学校住所
            SENTAKUKANO_CD            NUMBER                           --選択可能学校コード
        );
        rGKBFKGK                      MR_GKBFKGK;                      --学校カーソル
        sMEISHO                       NVARCHAR2(1000);
        sMEISHOKANA                   NVARCHAR2(1000);
        sYOBI                         NVARCHAR2(1000);
        cCURSOR2_FLG                  BOOLEAN;
        CURSOR MC_REIBO  (i_sKONJI_NO IN NVARCHAR2)
            IS
               SELECT HOGOSYA_ZOKUGARA1,
                      HOGOSYA_ZOKUGARA2,
                      HOGOSYA_ZOKUGARA3,
                      HOGOSYA_ZOKUGARA4,
                      HOGOSYA_KOJIN_NO
                 FROM GKBTGAKUREIBO
                WHERE KOJIN_NO = rTAISHOUJIDOU.KOJIN_NO
                  AND SAISHIN_KBN = 0
                  AND SAKUJO_FLG = 0
                ORDER BY RIREKI_RENBAN DESC FETCH FIRST 1 ROWS ONLY;
        TYPE MR_rREIBO IS RECORD(
            HOGOSYA_ZOKUGARA1     GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1%TYPE,
            HOGOSYA_ZOKUGARA2     GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2%TYPE,
            HOGOSYA_ZOKUGARA3     GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3%TYPE,
            HOGOSYA_ZOKUGARA4     GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4%TYPE,
            HOGOSYA_KOJIN_NO      GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE
        );
        --学齢簿情報
        rREIBO                   MR_rREIBO;
        
        CURSOR MC_SKOKKU  (i_sGAKKOSHIKIBETSU IN NVARCHAR2,
                           i_nGAKKO_KBN_CD    IN NUMBER)
            IS
               SELECT KOU.SENTAKUKANO_EDABAN AS SENTAKUKANO_EDABAN,
                      SKO.SYOGAKOMEI         AS GAKKO_MEI,
                      SKO.JUSHO              AS GAKKO_JUSHO,
                      KOU.SENTAKUKANO_CD     AS SENTAKUKANO_CD
                 FROM GKBTMSSHUGAKUSHITEIKOU    KOU,
                      GKBTSHOGAKKO              SKO
                WHERE KOU.SAISHIN_FLG     = 0
                  AND KOU.SAKUJO_FLG      = 0
                  AND KOU.GAKKOSHIKIBETSU = i_sGAKKOSHIKIBETSU
                  AND KOU.GAKKO_KBN_CD    = i_nGAKKO_KBN_CD
                  AND SKO.SAKUJO_FLG(+)   = 0
--  2025/06/11 CTC.GL UPDATE Start 1.0.008.000:GKB_QA13861対応
                  --AND SKO.SYOGAKO_CD(+)   = KOU.SENTAKUKANO_CD;
                  AND SKO.SYOGAKO_CD(+)   = KOU.SENTAKUKANO_CD
                  AND KOU.NENDO = CASE 
                    WHEN EXTRACT(MONTH FROM SYSDATE) BETWEEN 4 AND 12 
                    THEN EXTRACT(YEAR FROM SYSDATE)
                    ELSE EXTRACT(YEAR FROM SYSDATE) - 1
                 END;
--  2025/06/11 CTC.GL UPDATE End

        CURSOR MC_CKOKKU  (i_sGAKKOSHIKIBETSU IN NVARCHAR2,
                           i_nGAKKO_KBN_CD    IN NUMBER)
            IS
               SELECT KOU.SENTAKUKANO_EDABAN AS SENTAKUKANO_EDABAN,
                      CKO.TYUGAKOMEI         AS GAKKO_MEI,
                      CKO.JUSHO              AS GAKKO_JUSHO,
                      KOU.SENTAKUKANO_CD     AS SENTAKUKANO_CD
                 FROM GKBTMSSHUGAKUSHITEIKOU KOU,
                      GKBTCHUGAKKO           CKO
                WHERE KOU.SAISHIN_FLG     = 0
                  AND KOU.SAKUJO_FLG      = 0
                  AND KOU.GAKKOSHIKIBETSU = i_sGAKKOSHIKIBETSU
                  AND KOU.GAKKO_KBN_CD    = i_nGAKKO_KBN_CD
                  AND CKO.SAKUJO_FLG(+)   = 0
--  2025/06/11 CTC.GL UPDATE Start 1.0.008.000:GKB_QA13861対応
                  --AND CKO.TYUGAKO_CD(+)   = KOU.SENTAKUKANO_CD;
                  AND CKO.TYUGAKO_CD(+)   = KOU.SENTAKUKANO_CD
                  AND KOU.NENDO = CASE 
                    WHEN EXTRACT(MONTH FROM SYSDATE) BETWEEN 4 AND 12 
                    THEN EXTRACT(YEAR FROM SYSDATE)
                    ELSE EXTRACT(YEAR FROM SYSDATE) - 1
                 END;
--  2025/06/11 CTC.GL UPDATE End
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        IF g_bSHORIFLAG THEN
           g_bSHORIFLAG := FALSE;
           --1.初期処理
           bRTN := FUNC_INIT;
           IF NOT bRTN THEN
             RETURN FALSE;
           END IF;
           --選択制対象者ワーク初期化
           DELETE FROM GKBWSENTAKUSEI
           WHERE BATCHKBN = c_BATCH
           AND WSNUM = g_sWSNUM;
           --条件取得処理
           IF NOT FUNC_JYOKEN_GET THEN
              RAISE eEXCEPTION;
           END IF;
           --対象児童カーソルの宣言
           sSELECT1 := '';
           sSELECT2 := '';
           sSQL1 := '';
           --学齢簿.学年 = 0 の場合
           sSELECT1 := sSELECT1 || 'SELECT IBO.KOJIN_NO        AS KOJIN_NO,                            ';
           sSELECT1 := sSELECT1 || '       SKO.SYOGAKO_CD      AS SHUGAKUSHITEIKOU,                    ';
           sSELECT1 := sSELECT1 || '       SKO.KYOIKUIINKAI_CD AS KYOIKUIINKAI_CD,                     ';
           sSELECT1 := sSELECT1 || '       KKU.GAKKOSHIKIBETSU AS GAKKOSHIKIBETSU,                     ';
           sSELECT1 := sSELECT1 || '       KKU.GAKKO_KBN_CD    AS GAKKO_KBN_CD,                        ';
           sSELECT1 := sSELECT1 || '       KKU.RENBAN          AS RENBAN,                              ';
           sSELECT1 := sSELECT1 || '       KKU.GAKKOBLOCK_CD   AS GAKKOBLOCK_CD                        ';
--2025/10/16 CTC.BAI Add start 1.0.300.000:帳票アウトソーシング連番対応
           sSELECT1 := sSELECT1 || '       ,GAAPK0030.FYUHENKBNGET(IBO.HOGOSYA_KOJIN_NO, ''GKB'', ' || g_nHAKKOBI || ') AS YUHEN_KBN  ';      --郵返区分
--2025/10/16 CTC.BAI Add end
           sSELECT1 := sSELECT1 || '  FROM GKBTGAKUREIBO   IBO,    ';           --学齢簿
           sSELECT1 := sSELECT1 || '       GKBTSHOGAKKO    SKO,    ';           --小学校名
           sSELECT1 := sSELECT1 || '       GKBTMSGAKKU     KKU,    ';           --学区管理情報
           sSELECT1 := sSELECT1 || '       GABTATENAKIHON  HON     ';           --宛名基本
           sSELECT1 := sSELECT1 || ' WHERE IBO.SAISHIN_KBN = 0 ';
           sSELECT1 := sSELECT1 || '   AND IBO.SAKUJO_FLG  = 0 ';
           --学齢簿.学年 = 6 の場合
           sSELECT2 := sSELECT2 || 'SELECT IBO.KOJIN_NO        AS KOJIN_NO,                            ';
           sSELECT2 := sSELECT2 || '       CKO.TYUGAKO_CD      AS SHUGAKUSHITEIKOU,                    ';
           sSELECT2 := sSELECT2 || '       CKO.KYOIKUIINKAI_CD AS KYOIKUIINKAI_CD,                     ';
           sSELECT2 := sSELECT2 || '       KKU.GAKKOSHIKIBETSU AS GAKKOSHIKIBETSU,                     ';
           sSELECT2 := sSELECT2 || '       KKU.GAKKO_KBN_CD    AS GAKKO_KBN_CD,                        ';
           sSELECT2 := sSELECT2 || '       KKU.RENBAN          AS RENBAN,                              ';
           sSELECT2 := sSELECT2 || '       KKU.GAKKOBLOCK_CD   AS GAKKOBLOCK_CD                        ';
--2025/10/16 CTC.BAI Add start 1.0.300.000:帳票アウトソーシング連番対応
           sSELECT2 := sSELECT2 || '       ,GAAPK0030.FYUHENKBNGET(IBO.HOGOSYA_KOJIN_NO, ''GKB'', ' || g_nHAKKOBI || ') AS YUHEN_KBN  ';      --郵返区分
--2025/10/16 CTC.BAI Add end
           sSELECT2 := sSELECT2 || '  FROM GKBTGAKUREIBO   IBO,    ';           --学齢簿
           sSELECT2 := sSELECT2 || '       GKBTCHUGAKKO    CKO,    ';           --中学校名
           sSELECT2 := sSELECT2 || '       GKBTMSGAKKU     KKU,    ';           --学区管理情報
           sSELECT2 := sSELECT2 || '       GABTATENAKIHON  HON     ';           --宛名基本
           sSELECT2 := sSELECT2 || ' WHERE IBO.SAISHIN_KBN = 0 ';
           sSELECT2 := sSELECT2 || '   AND IBO.SAKUJO_FLG  = 0 ';
           CASE g_sGAKO_KBN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--             --処理条件1.学校区分 = 1:すべて の場合
--             WHEN 1 THEN
             --処理条件1.学校区分 = 0:すべて の場合
             WHEN 0 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
               CASE
                 --1.処理条件2.就学指定校 で小学校のみ選択されている場合
                 WHEN  g_sSYOGAKO_ED IS NOT NULL AND g_sTYUGAKO_ED IS NULL THEN
                   sSELECT1 := sSELECT1 || '   AND IBO.GAKUNEN =  0';
                   --  2024/10/30 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKB_00303仕様変更対応
                   --sSELECT1 := sSELECT1 || '   AND IBO.SHITEI_SYOGAKO_CD IN  (' || g_sSYOGAKO_ED || ')';
                   sSELECT1 := sSELECT1 || '   AND SKO.SYOGAKO_CD(+) IN  (' || g_sSYOGAKO_ED || ')';
                   sSELECT2 := sSELECT2 || '   AND IBO.GAKUNEN =  6';
                   sSELECT2 := sSELECT2 || '   AND IBO.SHITEI_TYUGAKO_CD IS NULL';
                 --2：処理条件2.就学指定校 で中学校のみ選択されている場合
                 WHEN  g_sSYOGAKO_ED IS NULL AND g_sTYUGAKO_ED IS NOT NULL THEN
                   sSELECT2 := sSELECT2 || '   AND IBO.GAKUNEN =  6';
                   --  2024/10/30 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKB_00303仕様変更対応
                   --sSELECT2 := sSELECT2 || '   AND IBO.SHITEI_TYUGAKO_CD IN  (' || g_sTYUGAKO_ED || ')';
                   sSELECT2 := sSELECT2 || '   AND CKO.TYUGAKO_CD(+) IN  (' || g_sTYUGAKO_ED || ')';
                   sSELECT1 := sSELECT1 || '   AND IBO.GAKUNEN =  0';
                   sSELECT1 := sSELECT1 || '   AND IBO.SHITEI_SYOGAKO_CD IS NULL';
                 --3.上記の1、2に当てはまらない場合
                 ELSE
                   sSELECT1 := sSELECT1 || '   AND IBO.GAKUNEN =  0';
                   sSELECT2 := sSELECT2 || '   AND IBO.GAKUNEN =  6';
                   IF g_sSYOGAKO_ED IS NOT NULL AND g_sTYUGAKO_ED IS NOT NULL THEN
                     --  2024/11/05 ZCZL.ZHANGLEI DEL 0.3.000.011:IT_GKB_00259対応
                     --sSELECT1 := sSELECT1 || '   AND IBO.GAKUNEN =  0';
                     --  2024/10/30 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKB_00303仕様変更対応
                     --sSELECT1 := sSELECT1 || '   AND IBO.SHITEI_SYOGAKO_CD IN  (' || g_sSYOGAKO_ED || ')';
                     sSELECT1 := sSELECT1 || '   AND SKO.SYOGAKO_CD(+) IN  (' || g_sSYOGAKO_ED || ')';
                     --  2024/11/05 ZCZL.ZHANGLEI DEL 0.3.000.011:IT_GKB_00259対応
                     --sSELECT2 := sSELECT2 || '   AND IBO.GAKUNEN =  6';
                     --  2024/10/30 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKB_00303仕様変更対応
                     --sSELECT2 := sSELECT2 || '   AND IBO.SHITEI_TYUGAKO_CD IN  (' || g_sTYUGAKO_ED || ')';
                     sSELECT2 := sSELECT2 || '   AND CKO.TYUGAKO_CD(+) IN  (' || g_sTYUGAKO_ED || ')';
                   END IF;
               END CASE;
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--             --処理条件1.学校区分 = 2:小学校 の場合
--             WHEN 2 THEN
             --処理条件1.学校区分 = 1:小学校 の場合
             WHEN 1 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
               sSELECT1 := sSELECT1 || '     AND IBO.GAKUNEN =  0';
               IF g_sSYOGAKO_ED IS NOT NULL THEN
                 --  2024/10/30 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKB_00303仕様変更対応
                 --sSELECT1 := sSELECT1 || '   AND IBO.SHITEI_SYOGAKO_CD IN  (' || g_sSYOGAKO_ED || ')';
                 sSELECT1 := sSELECT1 || '   AND SKO.SYOGAKO_CD(+) IN  (' || g_sSYOGAKO_ED || ')';
--  2025/06/11 CTC.GL UPDATE Start 1.0.008.000:GKB_QA13861対応
               --END IF;
               ELSE
                  sSELECT1 := sSELECT1 || '   AND SKO.SYOGAKO_CD = IBO.SHITEI_SYOGAKO_CD';
               END IF;
--  2025/06/11 CTC.GL UPDATE End
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--             --処理条件2.学校区分 = 3:中学校 の場合
--             WHEN 3 THEN
             --処理条件2.学校区分 = 2:中学校 の場合
             WHEN 2 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
               sSELECT2 := sSELECT2 || '   AND IBO.GAKUNEN =  6';
               IF g_sTYUGAKO_ED IS NOT NULL THEN
                 --  2024/10/30 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKB_00303仕様変更対応
                 --sSELECT2 := sSELECT2 || '   AND IBO.SHITEI_TYUGAKO_CD IN  (' || g_sTYUGAKO_ED || ')';
                 sSELECT2 := sSELECT2 || '   AND CKO.TYUGAKO_CD(+) IN  (' || g_sTYUGAKO_ED || ')';
--  2025/06/11 CTC.GL UPDATE Start 1.0.008.000:GKB_QA13861対応
               --END IF;
               ELSE
                  sSELECT2 := sSELECT2 || '   AND CKO.TYUGAKO_CD = IBO.SHITEI_TYUGAKO_CD';
               END IF;
--  2025/06/11 CTC.GL UPDATE End
             ELSE
               NULL;
           END CASE;
           sSQL1 := sSQL1 || '   AND HON.KOJIN_NO = IBO.KOJIN_NO ';
           sSQL1 := sSQL1 || '   AND KKU.SAISHIN_FLG = 0 ';
           sSQL1 := sSQL1 || '   AND KKU.SAKUJO_FLG =  0';
           --学齢簿.学年 = 0 の場合
--  2025/02/05 JIP.Y.SATO UPD ST
           --sSELECT1 := sSELECT1 || ' AND KKU.GAKKO_KBN_CD = 1 AND SKO.SYOGAKO_CD = KKU.GAKKOKU_CD(+) AND SKO.SAKUJO_FLG(+) = 0';
--  2025/12/03 CTC.GYY UPDATE 1.0.401.000:GKB_QA23605対応 START
           --sSELECT1 := sSELECT1 || ' AND KKU.GAKKO_KBN_CD = 1 AND SKO.GAKKOKU_CD = TO_NUMBER(KKU.GAKKOKU_CD(+)) AND SKO.SAKUJO_FLG(+) = 0';
           sSELECT1 := sSELECT1 || ' AND KKU.GAKKO_KBN_CD = 1 AND SKO.GAKKOKU_CD(+) = TO_NUMBER(KKU.GAKKOKU_CD) AND SKO.SAKUJO_FLG(+) = 0';
--  2025/12/03 CTC.GYY UPDATE 1.0.401.000:GKB_QA23605対応 END
           --学齢簿.学年 = 6 の場合
           --sSELECT2 := sSELECT2 || ' AND KKU.GAKKO_KBN_CD = 2 AND CKO.GAKKOKU_CD = KKU.GAKKOKU_CD(+) AND CKO.SAKUJO_FLG(+) = 0';
--  2025/12/03 CTC.GYY UPDATE 1.0.401.000:GKB_QA23605対応 START
           --sSELECT2 := sSELECT2 || ' AND KKU.GAKKO_KBN_CD = 2 AND CKO.GAKKOKU_CD = TO_NUMBER(KKU.GAKKOKU_CD(+)) AND CKO.SAKUJO_FLG(+) = 0';
           sSELECT2 := sSELECT2 || ' AND KKU.GAKKO_KBN_CD = 2 AND CKO.GAKKOKU_CD(+) = TO_NUMBER(KKU.GAKKOKU_CD) AND CKO.SAKUJO_FLG(+) = 0';
--  2025/12/03 CTC.GYY UPDATE 1.0.401.000:GKB_QA23605対応 END
--  2025/02/05 JIP.Y.SATO UPD ST
   
           --システム設定(KKATCT)から、学区管理区分を取得する。（0：住所、 1：行政区）
           nRTN := KKAPK0030.FCTGetR ('GKB', '00GAKKU_KANRI', '0000', 0, aPRM);
           IF aPRM(1) = 0 THEN
             sSQL1 := sSQL1 || ' AND KKU.OAZA_CD     =  HON.OAZA_CD';
             sSQL1 := sSQL1 || ' AND KKU.HONBAN_FR  <=  HON.HONBAN';
             sSQL1 := sSQL1 || ' AND KKU.HONBAN_TO  >=  HON.HONBAN';
             sSQL1 := sSQL1 || ' AND KKU.EDABAN1_FR <=  HON.EDABAN1';
             sSQL1 := sSQL1 || ' AND KKU.EDABAN1_TO >=  HON.EDABAN1';
             sSQL1 := sSQL1 || ' AND KKU.EDABAN2_FR <=  HON.EDABAN2';
             sSQL1 := sSQL1 || ' AND KKU.EDABAN2_TO >=  HON.EDABAN2';
             sSQL1 := sSQL1 || ' AND KKU.EDABAN3_FR <=  HON.EDABAN3';
             sSQL1 := sSQL1 || ' AND KKU.EDABAN3_TO >=  HON.EDABAN3';
--  2024/09/26 ZCZL.WANGMING UPDATE START 0.3.000.004:IT_GKB_00177対応
--             sSQL1 := sSQL1 || ' AND KKU.GAIKU_FR   >=  HON.GAIKU';
--             sSQL1 := sSQL1 || ' AND KKU.GAIKU_TO   <=  HON.GAIKU';
--             sSQL1 := sSQL1 || ' AND KKU.TOU_FR     >=  HON.TOU';
--             sSQL1 := sSQL1 || ' AND KKU.TOU_TO     <=  HON.TOU';
             sSQL1 := sSQL1 || ' AND KKU.GAIKU_FR   <=  HON.GAIKU';
             sSQL1 := sSQL1 || ' AND KKU.GAIKU_TO   >=  HON.GAIKU';
             sSQL1 := sSQL1 || ' AND KKU.TOU_FR     <=  HON.TOU';
             sSQL1 := sSQL1 || ' AND KKU.TOU_TO     >=  HON.TOU';
--  2024/09/26 ZCZL.WANGMING UPDATE END
           END IF;
           IF aPRM(1) = 1 THEN
             sSQL1 := sSQL1 || ' AND KKU.GYOSEIKU_CD = HON.GYOSEIKU_CD';
           END IF;
           sSQL1_1 := sSELECT1 || sSQL1; --小学校
           sSQL1_2 := sSELECT2 || sSQL1; --中学校
           sSQL1 := '';
           CASE g_sGAKO_KBN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--             --処理条件1.学校区分 = 1:すべて の場合
--             WHEN 1 THEN
             --処理条件1.学校区分 = 0:すべて の場合
             WHEN 0 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
               --  2024/11/05 ZCZL.ZHANGLEI UPDATE 0.3.000.011:IT_GKB_00259対応
               --CASE
               --  WHEN  g_sSYOGAKO_ED IS NOT NULL AND g_sTYUGAKO_ED IS NULL THEN
               --     sSQL1 := sSQL1_1;
               --  WHEN  g_sSYOGAKO_ED IS NULL AND g_sTYUGAKO_ED IS NOT NULL THEN
               --     sSQL1 := sSQL1_2;
               --  ELSE
               --    sSQL1 := sSQL1_1 || ' UNION ALL ' || sSQL1_2;
               --  END CASE;
               sSQL1 := sSQL1_1 || ' UNION ALL ' || sSQL1_2;
               --  2024/11/05 ZCZL.ZHANGLEI UPDATE 0.3.000.011:IT_GKB_00259対応  
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--             --処理条件1.学校区分 = 2:小学校 の場合
--             WHEN 2 THEN
             --処理条件1.学校区分 = 1:小学校 の場合
             WHEN 1 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
               sSQL1 := sSQL1_1;
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--             --処理条件2.学校区分 = 3:中学校 の場合
--             WHEN 3 THEN
             --処理条件2.学校区分 = 2:中学校 の場合
             WHEN 2 THEN
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
               sSQL1 := sSQL1_2;
           END CASE;
           --対象児童カーソル
           OPEN cCURSOR FOR sSQL1;
           LOOP
               FETCH cCURSOR INTO rTAISHOUJIDOU;
               EXIT WHEN cCURSOR%NOTFOUND;
               rGKBWSENTAKUSEIREC := rGKBWSENTAKUSEIREC_NULL;
               --学校ブロック名取得
               NRTN := KKAPK0030.FCDGetR('GKB', '024', '0001', rTAISHOUJIDOU.GAKKOBLOCK_CD, sMEISHO, sMEISHOKANA, sYOBI);
               rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO := sMEISHO;
               --選択可能学校取得
               cCURSOR2_FLG := FALSE;
               IF rTAISHOUJIDOU.GAKKO_KBN_CD = 1 THEN
                 FOR rGKBFKGK IN MC_SKOKKU(rTAISHOUJIDOU.GAKKOSHIKIBETSU, rTAISHOUJIDOU.GAKKO_KBN_CD) LOOP
                   rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO := rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO || '#' ||
                    '　' || rGKBFKGK.GAKKO_MEI || '　' || rGKBFKGK.GAKKO_JUSHO;
                   cCURSOR2_FLG := TRUE;
                 END LOOP;
               END IF;
               IF rTAISHOUJIDOU.GAKKO_KBN_CD = 2 THEN
                 FOR rGKBFKGK IN MC_CKOKKU(rTAISHOUJIDOU.GAKKOSHIKIBETSU, rTAISHOUJIDOU.GAKKO_KBN_CD) LOOP
                   rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO := rGKBWSENTAKUSEIREC.HYOJI_SENTAKUKANO_GAKKO || '#' ||
                    '　' || rGKBFKGK.GAKKO_MEI || '　' || rGKBFKGK.GAKKO_JUSHO;
                   cCURSOR2_FLG := TRUE;
                 END LOOP;
               END IF;
               IF NOT cCURSOR2_FLG THEN
                 CONTINUE;
               END IF;
               --学齢簿情報取得
               FOR r IN MC_REIBO(rTAISHOUJIDOU.KOJIN_NO) LOOP
                 rREIBO.HOGOSYA_KOJIN_NO := r.HOGOSYA_KOJIN_NO;
                 rREIBO.HOGOSYA_ZOKUGARA1 := r.HOGOSYA_ZOKUGARA1;
                 rREIBO.HOGOSYA_ZOKUGARA2 := r.HOGOSYA_ZOKUGARA2;
                 rREIBO.HOGOSYA_ZOKUGARA3 := r.HOGOSYA_ZOKUGARA3;
                 rREIBO.HOGOSYA_ZOKUGARA4 := r.HOGOSYA_ZOKUGARA4;
               END LOOP;
               --保護者宛名情報
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
               --nRTN := GAAPK0030.FGETATENA2(rREIBO.HOGOSYA_KOJIN_NO, 'GKB', g_nHAKKOBI, t_RATENA_REC, t_RSOFU_REC);
               nRTN := GAAPK0030.FGETATENA(rREIBO.HOGOSYA_KOJIN_NO, 'GKB', g_nHAKKOBI, t_RATENA_REC, t_RSOFU_REC);
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
               --児童生徒宛名情報
               nRTN := GAAPK0030.FGETATENA(rTAISHOUJIDOU.KOJIN_NO, 'GKB', g_nHAKKOBI, t_RATENA_REC2, t_RSOFU_REC2);
               
               --送付先郵便番号
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
               IF t_RSOFU_REC.YUBIN_NO IS NOT NULL THEN
               nRTN := KKAPK0010.FYUBINHENSHU(t_RSOFU_REC.YUBIN_NO, rGKBWSENTAKUSEIREC.SOFU_YUBIN);
               ELSE 
                 nRTN := KKAPK0010.FYUBINHENSHU(t_RATENA_REC.YUBIN_NO, rGKBWSENTAKUSEIREC.SOFU_YUBIN);
               END IF;  
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
               rGKBWSENTAKUSEIREC.SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(rGKBWSENTAKUSEIREC.SOFU_YUBIN,0);
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
               --送付先住所
               IF t_RSOFU_REC.CHOMEI IS NOT NULL THEN
                  rGKBWSENTAKUSEIREC.SOFU_JUSHO  := GAAPK0010.FADDRESSEDIT(1,
                                                                        NULL,
                                                                        t_RSOFU_REC.CHOMEI,
                                                                        t_RSOFU_REC.BANCHI,
                                                                        NULL,
                                                                        NULL);
                  rGKBWSENTAKUSEIREC.ATESAKI_KATAGAKI := t_RSOFU_REC.KATAGAKI;
                ELSE
                  rGKBWSENTAKUSEIREC.SOFU_JUSHO  := GAAPK0010.FADDRESSEDIT(1,
                                                                        NULL,
                                                                        t_RATENA_REC.CHOMEI,
                                                                        t_RATENA_REC.BANCHI,
                                                                        NULL,
                                                                        NULL);
                  rGKBWSENTAKUSEIREC.ATESAKI_KATAGAKI := t_RATENA_REC.KATAGAKI;
                END IF;

               /* rGKBWSENTAKUSEIREC.SOFU_JUSHO  := GAAPK0010.FADDRESSEDIT(1,
                                                                        NULL,
                                                                        t_RATENA_REC2.CHOMEI,
                                                                        t_RATENA_REC2.BANCHI,
                                                                        NULL,
                                                                        NULL);
                
               --宛先方書
               rGKBWSENTAKUSEIREC.ATESAKI_KATAGAKI := t_RATENA_REC2.KATAGAKI; */
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
               --宛先
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 START
--               rGKBWSENTAKUSEIREC.ATESAKI := t_RSOFU_REC2.SHIMEI_KANJI || '　' || '様';
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
               IF t_RSOFU_REC.SHIMEI_KANJI IS NOT NULL THEN
               rGKBWSENTAKUSEIREC.ATESAKI := t_RSOFU_REC.SHIMEI_KANJI || '　' || '様';
               ELSE
               rGKBWSENTAKUSEIREC.ATESAKI := t_RATENA_REC.SHIMEI_KANJI || '　' || '様';
               END IF;
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
--  2024/11/25 JPJYS.LIUHUAIQI UPDATE 0.3.000.016:IT_GKB_00668対応 END
               --郵便番号BC
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
               IF t_RSOFU_REC.YUBIN_NOBC IS NOT NULL THEN
               rGKBWSENTAKUSEIREC.YUBIN_NOBC := t_RSOFU_REC.YUBIN_NOBC;
               ELSE
                 rGKBWSENTAKUSEIREC.YUBIN_NOBC := t_RATENA_REC.YUBIN_NOBC;
               END IF;
--  2025/01/07 JPJYS.LIUJUNHAO UPDATE 0.3.000.018:品質強化　IT_GKB_10142、IT_GKB_10143、IT_GKB_10144、IT_GKB_10145、IT_GKB_10146対応
               --送付日
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.010:IT_GKB_00286横展開対応
--               rGKBWSENTAKUSEIREC.SOFUBI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_nHAKKOBI),'YYYY/MM/DD'),1);
               rGKBWSENTAKUSEIREC.SOFUBI := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(g_nHAKKOBI),1);
               --学校区分
               rGKBWSENTAKUSEIREC.GAKKO_KBN_CD := rTAISHOUJIDOU.GAKKO_KBN_CD;
               --学校区分名
               IF rTAISHOUJIDOU.GAKKO_KBN_CD = 1 THEN
                 rGKBWSENTAKUSEIREC.GAKKO_KBN_MEI := '小学校';
               END IF;
               IF rTAISHOUJIDOU.GAKKO_KBN_CD = 2 THEN
                 rGKBWSENTAKUSEIREC.GAKKO_KBN_MEI := '中学校';
               END IF;
               --児童生徒宛名番号
               rGKBWSENTAKUSEIREC.JIDO_KOJIN_NO     := t_RATENA_REC2.KOJIN_NO;
               --児童生徒氏名カナ
               rGKBWSENTAKUSEIREC.JIDO_SHIMEI_KANA  := t_RATENA_REC2.SHIMEI_KANA;
               --児童生徒氏名漢字
               rGKBWSENTAKUSEIREC.JIDO_SHIMEI_KANJI := t_RATENA_REC2.SHIMEI_KANJI;
               --表示生年月日
               IF t_RATENA_REC2.JINKAKU_KBN <> 1 THEN
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.010:IT_GKB_00286横展開対応
--                 rGKBWSENTAKUSEIREC.HYOJI_SEINENGAPPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_nHAKKOBI),'YYYY/MM/DD'),1);
                 GKAPK00020.FGETSEINENGHYOUJI(g_nHAKKOBI,o_sEINENGAPI);
                 rGKBWSENTAKUSEIREC.HYOJI_SEINENGAPPI := o_sEINENGAPI.o_vEDIT_GYYMMDD3;
               ELSE
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.010:IT_GKB_00286横展開対応
--                 rGKBWSENTAKUSEIREC.HYOJI_SEINENGAPPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_nHAKKOBI),'YYYY/MM/DD'),6);
                 GKAPK00020.FGETSEINENGHYOUJI(g_nHAKKOBI,o_sEINENGAPI);
                 rGKBWSENTAKUSEIREC.HYOJI_SEINENGAPPI := o_sEINENGAPI.o_vSEINEN_UMIGAI;
               END IF;
               --児童生徒現住所
               rGKBWSENTAKUSEIREC.CHOMEI_BANCHI := GAAPK0010.FADDRESSEDIT(1,NULL,t_RATENA_REC2.CHOMEI,t_RATENA_REC2.BANCHI,NULL,NULL);
               --児童生徒方書
               rGKBWSENTAKUSEIREC.KATAGAKI      := t_RATENA_REC2.KATAGAKI;
               --性別
               NRTN := KKAPK0030.FCDGetR('GKB', '021', '0001', t_RATENA_REC2.SEIBETSU, sMEISHO, sMEISHOKANA, sYOBI);
               rGKBWSENTAKUSEIREC.SEIBETSU := sMEISHO;
               --児童生徒国籍
               rGKBWSENTAKUSEIREC.JIDO_KOKUSEKI        := t_RATENA_REC2.KOKUSEKI_CD;
               --児童生徒_支援措置
-- 2025/06/04 CTC.HJF UPDATE Start 1.0.007.000:GKB_QA13919対応
              /* nRTN := GAAPK0030.FGETDV(t_RATENA_REC2.KOJIN_NO,
                                        0,
                                        g_nHAKKOBI,
                                        'GKB',
                                        nKOJINSETAIKBN,
                                        nYOKUSHIKBN,      
                                        nIDOYOKUSHIKBN,   
                                        nHAKKOYOKUSHIKBN, 
                                        nSHOKAIYOKUSHIKBN,
                                        nSHOKAIYOKUSHIKBN,
                                        vSHORICHUIKBN);
                                        
               /*IF nHAKKOYOKUSHIKBN = 0 THEN
                 rGKBWSENTAKUSEIREC.JIDO_SHIENSOCHI := NULL;
               ELSE
                 rGKBWSENTAKUSEIREC.JIDO_SHIENSOCHI := '該当';
               END IF;*/
               nRTN := GAAPK0030.FGETDV(t_RATENA_REC2.KOJIN_NO,
                                        t_RATENA_REC2.SETAI_NO,
                                        g_nHAKKOBI,
                                        'GKB',
                                        0,
                                        nKOJINSETAIKBN,
                                        nYOKUSHIKBN,      
                                        nIDOYOKUSHIKBN,   
                                        nHAKKOYOKUSHIKBN, 
                                        nSHOKAIYOKUSHIKBN,
                                        vSHORICHUIKBN);                
               IF 0 < nYOKUSHIKBN AND nYOKUSHIKBN < 99 THEN 
                 rGKBWSENTAKUSEIREC.JIDO_SHIENSOCHI := '対象';
               ELSE
                 rGKBWSENTAKUSEIREC.JIDO_SHIENSOCHI := NULL;
               END IF;             
-- 2025/06/04 CTC.HJF UPDATE End
               --保護者宛名番号
               rGKBWSENTAKUSEIREC.HOGOSHA_KOJIN_NO     := t_RATENA_REC.KOJIN_NO;
               --保護者氏名カナ
               rGKBWSENTAKUSEIREC.HOGOSHA_SHIMEI_KANA  := t_RATENA_REC.SHIMEI_KANA;
               --保護者氏名漢字
               rGKBWSENTAKUSEIREC.HOGOSHA_SHIMEI_KANJI := t_RATENA_REC.SHIMEI_KANJI;
               --児童生徒との関係
               rGKBWSENTAKUSEIREC.HOGOSHA_ZOKUGARA := GKBFKZKGMGET2(2, 
                                                                    rREIBO.HOGOSYA_ZOKUGARA1, 
                                                                    rREIBO.HOGOSYA_ZOKUGARA2, 
                                                                    rREIBO.HOGOSYA_ZOKUGARA3, 
                                                                    rREIBO.HOGOSYA_ZOKUGARA4);
               --保護者_支援措置
-- 2025/06/04 CTC.HJF UPDATE Start 1.0.007.000:GKB_QA13919対応
               /*nRTN := GAAPK0030.FGETDV(t_RATENA_REC.KOJIN_NO, 
                                        0,
                                        g_nHAKKOBI,
                                        'GKB',
                                        nKOJINSETAIKBN,
                                        nYOKUSHIKBN,   
                                        nIDOYOKUSHIKBN,   
                                        nHAKKOYOKUSHIKBN, 
                                        nSHOKAIYOKUSHIKBN,
                                        nSHOKAIYOKUSHIKBN,
                                        vSHORICHUIKBN);
                                        
               IF nHAKKOYOKUSHIKBN = 0 THEN
                 rGKBWSENTAKUSEIREC.HOGOSHA_SHIENSOCHI := NULL;
               ELSE
                 rGKBWSENTAKUSEIREC.HOGOSHA_SHIENSOCHI := '該当';
               END IF;*/
               nRTN := GAAPK0030.FGETDV(t_RATENA_REC.KOJIN_NO, 
                                        t_RATENA_REC.SETAI_NO,
                                        g_nHAKKOBI,
                                        'GKB',
                                        0,
                                        nKOJINSETAIKBN,
                                        nYOKUSHIKBN,   
                                        nIDOYOKUSHIKBN,   
                                        nHAKKOYOKUSHIKBN, 
                                        nSHOKAIYOKUSHIKBN,
                                        vSHORICHUIKBN);
             
               IF 0< nYOKUSHIKBN AND nYOKUSHIKBN < 99 THEN
                 rGKBWSENTAKUSEIREC.HOGOSHA_SHIENSOCHI := '対象';
               ELSE  
                 rGKBWSENTAKUSEIREC.HOGOSHA_SHIENSOCHI := NULL;
               END IF;              
-- 2025/06/04 CTC.HJF UPDATE End 
               --就学指定校
               rGKBWSENTAKUSEIREC.SHUGAKUSHITEIKOU := rTAISHOUJIDOU.SHUGAKUSHITEIKOU;
               --就学指定校名
               IF rTAISHOUJIDOU.GAKKO_KBN_CD = 1 THEN
                 FOR i IN (SELECT SYOGAKOMEI
                             FROM GKBTSHOGAKKO
                            WHERE SAKUJO_FLG = 0
                              AND SYOGAKO_CD = rTAISHOUJIDOU.SHUGAKUSHITEIKOU) LOOP
                   rGKBWSENTAKUSEIREC.SHUGAKUSHITEIKOU_MEI := i.SYOGAKOMEI;
                 END LOOP;
               END IF;
               IF rTAISHOUJIDOU.GAKKO_KBN_CD = 2 THEN
                 FOR i IN (SELECT TYUGAKOMEI
                             FROM GKBTCHUGAKKO
                            WHERE SAKUJO_FLG = 0
                              AND TYUGAKO_CD = rTAISHOUJIDOU.SHUGAKUSHITEIKOU) LOOP
                   rGKBWSENTAKUSEIREC.SHUGAKUSHITEIKOU_MEI := i.TYUGAKOMEI;
                 END LOOP;
               END IF;
               --教育委員会コード
               rGKBWSENTAKUSEIREC.KYOIKUIINKAI_CD := rTAISHOUJIDOU.KYOIKUIINKAI_CD;
--  2024/08/05 ZCZL.caijiacun Update START 0.3.000.001:検収指摘No.138、139の対応
               --学校ブロック
               --rGKBWSENTAKUSEIREC.GAKKOBLOCK_CD := rTAISHOUJIDOU.GAKKO_KBN_CD;
               rGKBWSENTAKUSEIREC.GAKKOBLOCK_CD := rTAISHOUJIDOU.GAKKOBLOCK_CD;
               --人格区分
               rGKBWSENTAKUSEIREC.JINKAKU_KBN := t_RATENA_REC.JINKAKU_KBN;
               --端末番号
--  2024/08/05 ZCZL.caijiacun Update end
               rGKBWSENTAKUSEIREC.WSNUM := g_sWSNUM;
--2025/10/16 CTC.BAI Add start 1.0.300.000:帳票アウトソーシング連番対応
               rGKBWSENTAKUSEIREC.YUHEN_KBN := rTAISHOUJIDOU.YUHEN_KBN;
--2025/10/16 CTC.BAI Add end
               --即時バッチ区分
               rGKBWSENTAKUSEIREC.BATCHKBN := 2;
               --ジョブNO
               rGKBWSENTAKUSEIREC.JOBNUM := g_nJOBNUM;
               INSERT INTO GKBWSENTAKUSEI VALUES rGKBWSENTAKUSEIREC;
               
           END LOOP;
           CLOSE cCURSOR;
        END IF;
        --帳票分のワークテーブルのデータ編集
        CASE g_rJSTP.Chohyoid
          WHEN 'GKB700R001' THEN
            --学校選択制案内書ワーク初期化
            DELETE FROM GKBWL700R001
            WHERE BATCHKBN = c_BATCH
            AND WSNUM = g_sWSNUM;
            --ＣＳＶファイル作成処理
            nRTN := FUNC_CSV_CREATE;
            IF nRTN <> 0 THEN
              RAISE eEXCEPTION;
            END IF;
            --CSV出力処理
            bRTN := FUNC_B11CSV('GKBWL700R001');
          WHEN 'GKB130R002' THEN
            --学校選択制案内書発送者一覧ワークをクリアする
            DELETE FROM GKBWL130R092
            WHERE BATCHKBN = c_BATCH
            AND WSNUM = g_sWSNUM;
            --ＣＳＶファイル作成処理
            nRTN := FUNC_CSV_CREATE;
            IF nRTN <> 0 THEN
              RAISE eEXCEPTION;
            END IF;
            --CSV出力処理
            bRTN := FUNC_B11CSV('GKBWL130R092');
          WHEN 'GKB700R002' THEN
            --学校選択制調査書小・中学校用ワークをクリアする
            DELETE FROM GKBWL700R002
            WHERE BATCHKBN = c_BATCH
            AND WSNUM = g_sWSNUM;
            --ＣＳＶファイル作成処理
            nRTN := FUNC_CSV_CREATE;
            IF nRTN <> 0 THEN
              RAISE eEXCEPTION;
            END IF;
            --CSV出力処理
            bRTN := FUNC_B11CSV('GKBWL700R002');
          ELSE
            NULL;
        END CASE;
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD START 0.3.000.003:8月1日認識合わせの横展開
            IF cCURSOR%ISOPEN THEN
                CLOSE cCURSOR;
            END IF;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE;
    END FUNC_B10SAKUHYO1;
    --------------------------------------------------------
    --  機能概要      : 更新処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun 2024/06/06
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;  --戻り値
    BEGIN
        g_nUPDLOGSEQ := g_nUPDLOGSEQ + 1;
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 2);
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
    --  作成者／作成日: ZCZL.caijiacun 2024/06/06
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
            IF o_nRESULT <> c_OK THEN
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
END GKBPB00490;
/