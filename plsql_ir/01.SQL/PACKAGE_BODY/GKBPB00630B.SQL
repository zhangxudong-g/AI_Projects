CREATE OR REPLACE PACKAGE BODY GKBPB00630
--1.0.010.001.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 出入国記録照会書作成
--  機能概要      : 日本人・外国人出入国記録照会書発送者一覧表(一括処理)できる。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.Lvjq 2024/07/01
--------------------------------------------------------
--  変更履歴
--  2024/08/06 ZCZL.XIAOYA UPDATE 0.3.000.001:検収指摘No.142の対応
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/24 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00019対応
--  2024/09/30 ZCZL.LIUDI UPDATE 0.3.000.004:　IT_GKB_00272対応
--  2024/10/21 ZCZL.WANGMING UPDATE 0.3.000.005:　IT_GKB_00341対応
--  2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.006:　IT_GKB_00338対応
--  2024/11/05 ZCZL.ZHANGLEI Update 0.3.000.007:IT_GKB_00394対応
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.008:仕様変更　IT_GKB_00426対応
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応
--  2025/01/30 JYJYS.SONGSHIHAO UPDATE 0.3.000.010:品質強化：ST_GKB_TMP00023対応
--  2025/06/05 CTC.LIUJUNHAO UPDATE 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
--  2025/07/18 CTC.HJF UOPDATE 1.0.010.001:GKB_QA17896対応
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
    c_BATCH                       CONSTANT PLS_INTEGER := 2;   --バッチ
    rGKBWSHUTSUNYUKOKU            GKBWL680R001%ROWTYPE;        --出入国記録照会対象者ワーク
    rGKBWL680R001                 GKBWL680R001%ROWTYPE;        --出入国記録照会書ワーク
    --  2024/11/05 ZCZL.ZHANGLEI Update START 0.3.000.007:IT_GKB_00394対応
    --g_nKIJUNBI                    NUMBER;                      --処理条件.基準日
    --g_nSEINENGAPIFR               NUMBER;                      --処理条件.生年月日（開始）
    --g_nSEINENGAPITO               NUMBER;                      --処理条件.生年月日（終了）
    --g_nCHOSABIFR                  NUMBER;                      --処理条件.調査開始日
    --g_nCHOSABITO                  NUMBER;                      --処理条件.調査終了日
    --g_nHAKOBI                     NUMBER;                      --処理条件.発行日
    g_nKIJUNBI                    NVARCHAR2(1000);                      --処理条件.基準日
    g_nSEINENGAPIFR               NVARCHAR2(1000);                      --処理条件.生年月日（開始）
    g_nSEINENGAPITO               NVARCHAR2(1000);                      --処理条件.生年月日（終了）
    g_nCHOSABIFR                  NVARCHAR2(1000);                      --処理条件.調査開始日
    g_nCHOSABITO                  NVARCHAR2(1000);                      --処理条件.調査終了日
    g_nHAKOBI                     NVARCHAR2(1000);                      --処理条件.発行日
    --  2024/11/05 ZCZL.ZHANGLEI Update END
    g_vBASEDATEYMD                NUMBER;                      --基準日
    g_vSEINENGAPIFR               NUMBER;                      --生年月日（開始）
    g_vSEINENGAPITO               NUMBER;                      --生年月日（終了）
    g_vHAKOBI                     NUMBER;                      --発行日
    g_sHakkoRireki                NVARCHAR2(1);                --発行履歴
    g_nINDEX                      NUMBER := 0;
    g_nTIME                       NUMBER;                      --時分秒
    g_vCHOSABIFR                  NVARCHAR2(300);              --調査開始日
    g_vCHOSABITO                  NVARCHAR2(300);              --調査終了日
    g_vCHOSABI                    NVARCHAR2(300);              --調査終了日
    g_vHAKOYMD                    NVARCHAR2(300);              --発行日

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;
    g_aSHIMEIPRM                      A_CONS_PRM;

    --------------------------------------------------------------------
    --  変数宣言
    --------------------------------------------------------------------
    g_nSORT                     NUMBER := 0;                 --ソート順
    -- 集計用変数
    BRTN                        BOOLEAN;            -- ステータス
    VSQLERRM                    NVARCHAR2(256);     -- エラーメッセージ
    nCOUNT                      NUMBER;             -- 件数
    g_nGKB010_INDEX             NUMBER;             -- 出入国記録照会書_インデックス番号
    g_vGKB010_CTL               NVARCHAR2(1000);    -- 本名・通称名　出力制御
    
    g_vCHOHYO_MEI               NVARCHAR2(1000);    --帳票名
    g_vTSUCHIBUN                NVARCHAR2(1000);    --通知文
    g_vTOKKIJIKO                NVARCHAR2(1000);    --特記事項
    g_vKOIN_SHORYAKU            NVARCHAR2(1000);    --公印省略
    g_vKOIN_CHUSHAKU            NVARCHAR2(1000);    --公印注釈
    g_vYOSHIKI_BANGO_SETTOGO    NVARCHAR2(1000);    --様式番号接頭語
    g_nYOSHIKI_BANGO            NUMBER;             --様式番号
    g_vYOSHIKI_BANGO_SETSUBIGO  NVARCHAR2(1000);    --様式番号接尾語
    g_vYOSHIKI                  NVARCHAR2(1000);
    nDAIRIKBN                   NUMBER;                         --認証者の本人・代理区分（0：通常、1;職務代理）
    sKATAGAKI1                  NVARCHAR2(100);                 --認証者の肩書(二段表示用上段)
    sKATAGAKI2                  NVARCHAR2(100);                 --認証者の肩書(二段表示用下段)
    sSHIMEI                     NVARCHAR2(100);                 --認証者の氏名(首長、副首長等)
    rBUNNUMSRCINF               KKAPK0040.MR_BUNNUMSRCINF;      --文書番号情報（構造体）
    rBUNOUTINF                  KKAPK0040.MR_BUNOUTINF;         --文書発行記録出力情報
    rBUNNUMEDITKEKA             KKAPK0040.MR_BUNNUMEDITKEKA;    --文書番号編集結果
    sKOIN                       NVARCHAR2(100);                 --公印ファイル名（ファイルパス）
    TPARAMETER                  A_CONS_PRM;
    NLENGTH                     NUMBER(2);
    NSQLCODE                    NUMBER;             -- エラーコード
    o_RATENA_REC                GKBWSHUTSUNYUKOKU%ROWTYPE;      --出入国記録照会対象者ワーク
    sTPARAMETER                 NVARCHAR2(100);                 --宛名
    o_ACONSPRM                  A_CONS_PRM;                     -- パラメータの配列
    o_NPRMSUM                   NUMBER;                         -- パラメータの配列の長度
    
    TYPE MR_BUNNUM IS RECORD(
        KOJIN_NUM                           NUMBER,               --宛名番号
        BUNSHO_NO                   NVARCHAR2(1000)               --文書番号_案内書
    );
    TYPE MR_BUNNUM_REC IS TABLE OF MR_BUNNUM INDEX BY BINARY_INTEGER;
    g_rHOKANBUNNUM                  MR_BUNNUM_REC;                --文書番号退避リスト
    g_rBUNNUM                      NVARCHAR2(100);                --文書番号
    
    
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
    -- カーソル
    CURSOR CTAISHO( p_IKAISHI_SEINENGAPI IN PLS_INTEGER,
                    p_ISHURYO_SEINENGAPI IN PLS_INTEGER,
                    p_IGAKUNEN           IN PLS_INTEGER) IS
    SELECT 
       GB.KOJIN_NO,
       GB.JINKAKU_KBN,
       GB.SHIMEI_KANA,
       GB.SHIMEI_KANJI,
       GB.HONMYO_KANA,
       GB.HONMYO_KANJI,
       GB.SEINENGAPI,
       GB.HYOJI_SEINENGAPI,
       GB.KOKUSEKI_CD,
       GB.SEIBETSU,
       GB.CHOMEI,
       GB.BANCHI,
       GB.KATAGAKI,
       GB.ZAIRYU_NO_SHUBETSU,
       GB.ZAIRYU_CARD_NO,
       GC.BO_KOJIN_NO,
       GC.GAKKO_KBN_CD,
       GC.GAKKO_CD,
       GC.HOGOSYA_KOJIN_NO,
       GC.HOGOSYA_ZOKUGARA1,
       GC.HOGOSYA_ZOKUGARA2,
       GC.HOGOSYA_ZOKUGARA3,
       GC.HOGOSYA_ZOKUGARA4,
       GC.BO_JINKAKU_KBN,
       GC.BO_SHIMEI_KANA,
       GC.BO_SHIMEI_KANJI,
       GC.BO_HONMYO_KANA,
       GC.BO_HONMYO_KANJI,
       GC.BO_SEINENGAPI,
       GC.BO_HYOJI_SEINENGAPI,
       GC.BO_KOKUSEKI_CD,
       GC.FLAG
    FROM 
       GABTATENAKIHON GB,
       (
        SELECT BO.KOJIN_NO AS BO_KOJIN_NO,
               BO.GAKKO_KBN_CD AS GAKKO_KBN_CD,
               (CASE
                WHEN BO.GAKKO_KBN_CD = 1 THEN  BO.SYOGAKO_CD
                WHEN BO.GAKKO_KBN_CD = 2 THEN  BO.TYUGAKO_CD
                WHEN BO.GAKKO_KBN_CD = 3 THEN  BO.KUIKIGAI_CD
                WHEN BO.GAKKO_KBN_CD = 4 THEN  BO.YOGOGAKO_CD
                WHEN BO.GAKKO_KBN_CD = 5 THEN  BO.KUNISHIRITSU_CD
                END) AS GAKKO_CD,
                BO.HOGOSYA_KOJIN_NO AS HOGOSYA_KOJIN_NO,
                BO.HOGOSYA_ZOKUGARA1 AS HOGOSYA_ZOKUGARA1,
                BO.HOGOSYA_ZOKUGARA2 AS HOGOSYA_ZOKUGARA2,
                BO.HOGOSYA_ZOKUGARA3 AS HOGOSYA_ZOKUGARA3,
                BO.HOGOSYA_ZOKUGARA4 AS HOGOSYA_ZOKUGARA4,
                GT.JINKAKU_KBN AS BO_JINKAKU_KBN,
                GT.SHIMEI_KANA AS BO_SHIMEI_KANA,
                GT.SHIMEI_KANJI AS BO_SHIMEI_KANJI,
                GT.HONMYO_KANA AS BO_HONMYO_KANA,
                GT.HONMYO_KANJI AS BO_HONMYO_KANJI,
                GT.SEINENGAPI AS BO_SEINENGAPI,
                GT.HYOJI_SEINENGAPI AS BO_HYOJI_SEINENGAPI,
                GT.KOKUSEKI_CD AS BO_KOKUSEKI_CD,
                (CASE
                  WHEN BO.HUSHUGAKU_KAISI_BI <> 0 AND BO.HUSHUGAKU_KAISI_BI <= p_IGAKUNEN AND (BO.HUSHUGAKU_SYURYO_BI >= p_IGAKUNEN OR BO.HUSHUGAKU_SYURYO_BI = 0) THEN
                    0
                  ELSE 1
                  END) AS FLAG
          FROM
              GABTATENAKIHON GT,
              GKBTGAKUREIBO  BO
          WHERE
              BO.SAISHIN_KBN = 0
              AND BO.SAKUJO_FLG = 0
              AND BO.GEN_NENGAPI = 0
              AND BO.HOGOSYA_KOJIN_NO = GT.KOJIN_NO(+)  
       ) GC
       WHERE 
          GB.GENZON_KBN = 0
          AND GB.SEINENGAPI >= p_IKAISHI_SEINENGAPI
          AND GB.SEINENGAPI <= p_ISHURYO_SEINENGAPI
          --  2025/01/30 JYJYS.SONGSHIHAO UPDATE 0.3.000.010:品質強化：ST_GKB_TMP00023対応 Start
          --AND GB.KOJIN_NO = GC.BO_KOJIN_NO(+)
          AND GB.KOJIN_NO = GC.BO_KOJIN_NO
          --  2025/01/30 JYJYS.SONGSHIHAO UPDATE 0.3.000.010:品質強化：ST_GKB_TMP00023対応 End
          --2024/09/30 ZCZL.LIUDI UPDATE 0.3.000.004:　IT_GKB_00272対応
          --AND GC.FLAG =0;
          AND NVL(GC.FLAG,0) =0;
    -- カーソル用
    RTAISHO                     CTAISHO%ROWTYPE;

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
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
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
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
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
    --  作成者／作成日: ZCZL.muzl 2024/06/03
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        --2024/10/21 ZCZL.LIUDI ADD 0.3.000.006:　IT_GKB_00338対応
        v_optHakkoRireki                  DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        -- 基準日
        g_nKIJUNBI := KKBPK5551.GETPARMS(g_nJOBNUM,'txtKijunbi');
        -- 生年月日（開始）
        g_nSEINENGAPIFR := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSeinengapiFr');
        -- 生年月日（終了）
        g_nSEINENGAPITO := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSeinengapiTo');
        -- 調査開始日
        g_nCHOSABIFR := KKBPK5551.GETPARMS(g_nJOBNUM,'txtChosabiFr');
        -- 調査終了日
        g_nCHOSABITO := KKBPK5551.GETPARMS(g_nJOBNUM,'txtChosabiTo');
        -- 発行日
        g_nHAKOBI := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHakobi');
        --発行履歴
        --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.006:　IT_GKB_00338対応 START
        --g_sHakkoRireki := KKBPK5551.GETPARMS(g_nJOBNUM,'txtHakkoRireki');
        v_optHakkoRireki := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'txtHakkoRireki');
        g_sHakkoRireki := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtHakkoRireki',0,v_optHakkoRireki);
        --2024/10/21 ZCZL.LIUDI UPDATE END
        
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
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
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
    --  作成者／作成日: ZCZL.muzl 2025/06/13
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
        VMSG                          NVARCHAR2(4000);
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

        -- 処理結果を空白で初期化する。
        o_vRESULT := '';
        VMSG := '' ;

        --入力条件の日付の妥当性をチェックする
        bRTN := KKAPK0020.FISDATEW(g_nKIJUNBI);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日の指定が正しくありません。,;';
        END IF;
        --入力条件の日付の妥当性をチェックする
        bRTN := KKAPK0020.FISDATEW(g_nSEINENGAPIFR);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（開始）の指定が正しくありません。,;';
        END IF;
        --入力条件の日付の妥当性をチェックする
        bRTN := KKAPK0020.FISDATEW(g_nSEINENGAPITO);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（終了）の指定が正しくありません。,;';
        END IF;
        --入力条件の日付の妥当性をチェックする
        bRTN := KKAPK0020.FISDATEW(g_nCHOSABIFR);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,調査開始日の指定が正しくありません。,;';
        END IF;
        --入力条件の日付の妥当性をチェックする
        bRTN := KKAPK0020.FISDATEW(g_nCHOSABITO);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,調査終了日の指定が正しくありません。,;';
        END IF;
        --入力条件の日付の妥当性をチェックする
        bRTN := KKAPK0020.FISDATEW(g_nHAKOBI);
        IF NOT bRTN THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,発行日の指定が正しくありません。,;';
        END IF;
        
        -- 入力条件の日付の大小をチェックする。
        IF VMSG IS NULL AND g_nSEINENGAPIFR > g_nSEINENGAPITO THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（開始）、生年月日（終了）の関係が正しくありません。,;';
        END IF;
        IF VMSG IS NULL AND g_nCHOSABIFR > g_nCHOSABITO THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,調査開始日、調査終了日の関係が正しくありません。,;';
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
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  機能概要      : オンライン初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_INIT RETURN BOOLEAN
    IS
        bRTN                   BOOLEAN;                        --戻り値
        nRTN                   NUMBER;                         --戻り値
        aPRM                   A_CONS_PRM;
    BEGIN
        -- 共通部品「公印ファイル名取得」（KKBPK5551.FNINSHOGet）より、公印情報を取得する。
        bRTN := KKBPK5551.FNINSHOGet (g_rJSTP.NINSHOCODE,                             --認証コード
                                      g_sWSNUM,                                       --端末番号
                                      TO_DATE(g_vBASEDATEYMD, 'YYYY/MM/DD'),              --基準日
                                      nDAIRIKBN,                                      --認証者の本人・代理区分（0：通常、1;職務代理）
                                      sKATAGAKI1,                                     --認証者の肩書(二段表示用上段)
                                      sKATAGAKI2,                                     --認証者の肩書(二段表示用下段)
                                      sSHIMEI,                                        --認証者の氏名(首長、副首長等)
                                      sKOIN                                           --公印ファイル名（ファイルパス）
                                     );
                                     
        -- 2-1.通知書管理から必要な項目を取得する。
        BEGIN
          SELECT CHOHYO_MEI,                    -- 帳票名
                 TSUCHIBUN,                     -- 通知文
                 TOKKIJIKO,                     -- 特記事項
                 KOIN_SHORYAKU,                 -- 公印省略
                 KOIN_CHUSHAKU,                 -- 公印注釈
                 YOSHIKI_BANGO_SETTOGO,         -- 様式番号接頭語
                 YOSHIKI_BANGO,                 -- 様式番号
                 YOSHIKI_BANGO_SETSUBIGO        -- 様式番号接尾語
            INTO g_vCHOHYO_MEI,
                 g_vTSUCHIBUN,
                 g_vTOKKIJIKO,
                 g_vKOIN_SHORYAKU,
                 g_vKOIN_CHUSHAKU,
                 g_vYOSHIKI_BANGO_SETTOGO,
                 g_nYOSHIKI_BANGO,
                 g_vYOSHIKI_BANGO_SETSUBIGO
           FROM GKBTTSUCHISHOKANRI
             WHERE chohyo_kbn = '38';
        EXCEPTION
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--          WHEN NO_DATA_FOUND THEN
          WHEN OTHERS THEN
            g_vCHOHYO_MEI              := '';
            g_vTSUCHIBUN               := '';
            g_vTOKKIJIKO               := '';
            g_vKOIN_SHORYAKU           := '';
            g_vKOIN_CHUSHAKU           := '';
            g_vYOSHIKI_BANGO_SETTOGO   := '';
            g_nYOSHIKI_BANGO           := '';        
            g_vYOSHIKI_BANGO_SETSUBIGO := '';
        END;
        -- 2-2.取得情報を変数に設定。
        g_vYOSHIKI := g_vYOSHIKI_BANGO_SETTOGO || g_nYOSHIKI_BANGO || g_vYOSHIKI_BANGO_SETSUBIGO;
        -- ①.公印情報が取得でき、変数.公印 がNULL以外の場合
        IF sKOIN IS NOT NULL THEN
            -- ・変数.公印省略 にNULLを設定。
            g_vKOIN_SHORYAKU := NULL;
        ELSE
            -- ・変数.公印注釈 にNULLを設定。
            g_vKOIN_CHUSHAKU := NULL;
        END IF;
        
        -- 共通関数(KKAPK0030.FPRMSHUTOKU)を使用してパラメータ取得する。
        nRTN := KKAPK0030.FPRMSHUTOKU('GKB',
                                     '00SHUTUNYUKOKU',
                                     0,
                                     TPARAMETER,
                                     NLENGTH);
        -- ・変数.宛名に取得した宛名（No4パラメータ配列[1]）を設定
        sTPARAMETER := TPARAMETER(1);
        
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.008:仕様変更　IT_GKB_00426対応
        IF g_rJSTP.CHOHYOID = 'GKB680R001' THEN
          -- バッチジョブ文書番号情報入力（KKBPK5551.FJBNSGet)を呼び出す。
          bRTN := KKBPK5551.FJBNSGet (g_nJOBNUM, g_rJSTP.STEPSEQ, rBUNNUMSRCINF);
          
          -- 取得した文書番号内部情報.文書番号編集結果内部ﾜｰｸ(MR_BUNNUMSRCINF.UOUT)を文書番号編集結果（KKAPK0040.MR_BUNNUMEDITKEKA）型の変数にセットする。
          rBUNNUMEDITKEKA := rBUNNUMSRCINF.UOUT;
          
          -- 5.変数.文書番号退避リストを宣言
          --文書番号
          g_rBUNNUM := rBUNNUMEDITKEKA.NUM;
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.008:仕様変更　IT_GKB_00426対応
        END IF;
        
        -- 6.システム制御設定を取得する。
        -- 6-1.システム設定(KKATCT)から、制御パラメータ取得(KKAPK0030.FCTGetR)を使用して、「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する。
        nRTN := KKAPK0030.FCTGetR ('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aPRM);
        IF nRTN = 0 THEN
          FOR i IN 1..aPRM.COUNT LOOP
            IF aPRM(i) = 'GKB680R001' THEN
              g_nGKB010_INDEX := i;
--  2024/10/21 ZCZL.WANGMING UPDATE 0.3.000.005:　IT_GKB_00341対応
--            ELSIF aPRM(i) = 'GKB130R072' THEN
            ELSIF aPRM(i) = 'GKB130R002' THEN
              g_nGKB010_INDEX := i;
            END IF;
          END LOOP;
        END IF;
        --本名・通称名　出力制御
        g_aSHIMEIPRM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB','EQSHIMEI','0000',0,g_aSHIMEIPRM);
        IF nRTN = 0 THEN
          g_vGKB010_CTL := g_aSHIMEIPRM(g_nGKB010_INDEX);
        END IF;
        
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_INIT;
    --------------------------------------------------------
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
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
        bRTN := KKBPK5551.FCSVPUT (g_nJOBNUM,g_sGYOUMUCODE,g_sWSNUM,c_BATCH,i_TBLNAME,g_rJSTP.CHOHYOID,g_rJSTP.CHOHYOFORM,g_rJSTP.PRTFILEKBN,g_rJSTP.TEIKEIBUNNUM_LIST,nCSV_RCNT,sCSVFILENAME,sPRTFILENAME);

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

    --------------------------------------------------------------------------------
    -- 出入国記録照会対象者ワーク中間（GKBWSHUTSUNYUKOKU）レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN BOOLEAN IS
    IRTN                 PLS_INTEGER;
    BRTN                 BOOLEAN;
    VZOKUGARAMEI         NVARCHAR2(100);
    BOVZOKUGARAMEI         NVARCHAR2(100);
    o_sMEISHOKANA        KKATCD.MEISHOKANA%TYPE;              --名称カナ
    o_sYOBI              KKATCD.YOBI%TYPE;                    --予備
    nKOJINSETAIKBN          NUMBER;                       --個人世帯区分（0：個人、1：世帯）
    nYOKUSHIKBN             NUMBER;                       --抑止区分（1：支援措置、2：仮支援措置、4：その他抑止）
    nIDOYOKUSHIKBN          NUMBER;                       --異動抑止区分（0：非該当、1：警告、2：論理）
    nHAKKOYOKUSHIKBN        NUMBER;                       --発行抑止区分（0：非該当、1：警告、2：論理）
    nSHOKAIYOKUSHIKBN       NUMBER;                       --照会抑止区分（0：非該当、1：警告、2：論理）
    vSHORICHUIKBN           NVARCHAR2(10000);             --処理注意区分（任意設定）

    BEGIN
      
         -- 対象データ取得
        FOR CRTAISHO IN CTAISHO( g_vSEINENGAPIFR,
                                 g_vSEINENGAPITO,
                                 g_vBASEDATEYMD) LOOP
            RTAISHO := CRTAISHO;
            o_RATENA_REC.HAKKO_YMD := g_vHAKOBI;                           --発行年月日
            o_RATENA_REC.HYOJI_HAKKO_YMD := g_vHAKOYMD;                    --表示発行年月日
            o_RATENA_REC.JIDO_KOJIN_NO := RTAISHO.KOJIN_NO;                --児童生徒宛名番号
            o_RATENA_REC.JIDO_JINKAKU_KBN := RTAISHO.JINKAKU_KBN;          --児童生徒人格区分
            IF RTAISHO.HONMYO_KANA IS NOT NULL THEN
              o_RATENA_REC.JIDO_SHIMEI_KANA := RTAISHO.HONMYO_KANA;        --児童生徒氏名カナ
            ELSE
              o_RATENA_REC.JIDO_SHIMEI_KANA := RTAISHO.SHIMEI_KANA;
            END IF; 
            IF RTAISHO.HONMYO_KANJI IS NOT NULL THEN
              o_RATENA_REC.JIDO_SHIMEI_KANJI := RTAISHO.HONMYO_KANJI;      --児童生徒氏名漢字
            ELSE
              o_RATENA_REC.JIDO_SHIMEI_KANJI := RTAISHO.SHIMEI_KANJI;
            END IF;
            o_RATENA_REC.JIDO_SEINENGAPI := RTAISHO.SEINENGAPI;            --児童生徒生年月日
            IF RTAISHO.JINKAKU_KBN = 0 THEN
              o_RATENA_REC.JIDO_HYOJI_SEINENGAPI := RTAISHO.HYOJI_SEINENGAPI;      --児童生徒表示生年月日
            ELSIF RTAISHO.JINKAKU_KBN = 1 THEN
              o_RATENA_REC.JIDO_HYOJI_SEINENGAPI := KKAPK0020.FDAYEDIT20(RTAISHO.SEINENGAPI,1,3);
            END IF;
            o_RATENA_REC.JIDO_SEIBETSU_CD := RTAISHO.SEIBETSU;             --児童生徒性別
            IRTN := KKAPK0030.FCDgetR('GKB', '021', '0001', RTAISHO.SEIBETSU, o_RATENA_REC.JIDO_SEIBETSU, o_sMEISHOKANA, o_sYOBI);  --児童生徒性別漢字
            o_RATENA_REC.JIDO_KOKUSEKI_CD := RTAISHO.KOKUSEKI_CD;          --児童生徒国籍コード
            BEGIN
               SELECT KOKUMEI
                  INTO VZOKUGARAMEI
               FROM GABTKOKUSEKI
               WHERE KOKUSEKI_CD = RTAISHO.KOKUSEKI_CD;

            EXCEPTION
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--              WHEN NO_DATA_FOUND THEN
              WHEN OTHERS THEN
                  VZOKUGARAMEI := '';
            END;
            o_RATENA_REC.JIDO_KOKUSEKI := VZOKUGARAMEI;                    --児童生徒国籍
            o_RATENA_REC.JIDO_GENJUSHO := GAAPK0010.FADDRESSEDIT(1,NULL,RTAISHO.CHOMEI,RTAISHO.BANCHI,RTAISHO.KATAGAKI,NULL);   --児童生徒現住所
            --児童生徒_支援措置取得
            IRTN := GAAPK0030.FGETDV(RTAISHO.KOJIN_NO,0,g_vBASEDATEYMD,'GKB',0,nKOJINSETAIKBN,nYOKUSHIKBN,nIDOYOKUSHIKBN,nHAKKOYOKUSHIKBN,nSHOKAIYOKUSHIKBN,vSHORICHUIKBN);
--  2025/06/05 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
            /*IF nYOKUSHIKBN = 0 THEN
               o_RATENA_REC.JIDO_SHIENSOCHI := NULL;                       --児童生徒_支援措置
            ELSE
               o_RATENA_REC.JIDO_SHIENSOCHI := '該当';
            END IF;*/
            IF 0 < nYOKUSHIKBN AND nYOKUSHIKBN < 99THEN
               o_RATENA_REC.JIDO_SHIENSOCHI := '対象';                       --児童生徒_支援措置
            ELSE
               o_RATENA_REC.JIDO_SHIENSOCHI := NULL;
            END IF;                  
--  2025/06/05 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
            o_RATENA_REC.ZAIRYU_CARD_TOU_NO := RTAISHO.ZAIRYU_CARD_NO;     --在留カード番号
            o_RATENA_REC.GAKKO_KBN_CD := RTAISHO.GAKKO_KBN_CD;             --学校区分
            o_RATENA_REC.GAKKO_CD := RTAISHO.GAKKO_CD;                     --学校コード
            o_RATENA_REC.GAKKO_MEI := GKAFKGKOGTEQ(RTAISHO.GAKKO_KBN_CD,RTAISHO.GAKKO_CD);   --学校名
            o_RATENA_REC.HOGOSHA_KOJIN_NO := RTAISHO.HOGOSYA_KOJIN_NO;     --保護者宛名番号
            o_RATENA_REC.HOGOSHA_JINKAKU_KBN := RTAISHO.BO_JINKAKU_KBN;    --保護者人格区分
            IF RTAISHO.BO_HONMYO_KANA IS NOT NULL THEN
              o_RATENA_REC.HOGOSHA_SHIMEI_KANA := RTAISHO.BO_HONMYO_KANA;  --保護者氏名カナ
            ELSE
              o_RATENA_REC.HOGOSHA_SHIMEI_KANA := RTAISHO.BO_SHIMEI_KANA;
            END IF;
            IF RTAISHO.BO_HONMYO_KANJI IS NOT NULL THEN
              o_RATENA_REC.HOGOSHA_SHIMEI_KANJI := RTAISHO.BO_HONMYO_KANJI;--保護者氏名漢字
            ELSE
              o_RATENA_REC.HOGOSHA_SHIMEI_KANJI := RTAISHO.BO_SHIMEI_KANJI;
            END IF;
            o_RATENA_REC.HOGOSHA_SEINENGAPI := RTAISHO.BO_SEINENGAPI;      --保護者生年月日
            IF RTAISHO.BO_JINKAKU_KBN = 0 THEN
              o_RATENA_REC.HOGOSHA_HYOJI_SEINENGAPI := RTAISHO.BO_HYOJI_SEINENGAPI;      --保護者表示生年月日
            ELSIF RTAISHO.BO_JINKAKU_KBN = 1 THEN
              o_RATENA_REC.HOGOSHA_HYOJI_SEINENGAPI := KKAPK0020.FDAYEDIT20(RTAISHO.BO_SEINENGAPI,1,3);
            END IF;
            o_RATENA_REC.HOGOSHA_KOKUSEKI_CD := RTAISHO.BO_KOKUSEKI_CD;    --保護者国籍コード
            BEGIN
               SELECT KOKUMEI
                  INTO BOVZOKUGARAMEI
               FROM GABTKOKUSEKI
               WHERE KOKUSEKI_CD = RTAISHO.BO_KOKUSEKI_CD;

            EXCEPTION
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--              WHEN NO_DATA_FOUND THEN
              WHEN OTHERS THEN
                  BOVZOKUGARAMEI := '';
            END;
            o_RATENA_REC.HOGOSHA_KOKUSEKI := BOVZOKUGARAMEI;               --保護者国籍
            o_RATENA_REC.HOGOSHA_ZOKUGARA1 := RTAISHO.HOGOSYA_ZOKUGARA1;   --保護者続柄１
            o_RATENA_REC.HOGOSHA_ZOKUGARA2 := RTAISHO.HOGOSYA_ZOKUGARA2;   --保護者続柄２
            o_RATENA_REC.HOGOSHA_ZOKUGARA3 := RTAISHO.HOGOSYA_ZOKUGARA3;   --保護者続柄３
            o_RATENA_REC.HOGOSHA_ZOKUGARA4 := RTAISHO.HOGOSYA_ZOKUGARA4;   --保護者続柄４
            o_RATENA_REC.HOGOSHA_ZOKUGARA := GKBFKZKGMGET2(2,RTAISHO.HOGOSYA_ZOKUGARA1,RTAISHO.HOGOSYA_ZOKUGARA2,RTAISHO.HOGOSYA_ZOKUGARA3,RTAISHO.HOGOSYA_ZOKUGARA4);  --児童生徒との関係
            --保護者_支援措置取得
            IRTN := GAAPK0030.FGETDV(RTAISHO.HOGOSYA_KOJIN_NO,0,g_vBASEDATEYMD,'GKB',0,nKOJINSETAIKBN,nYOKUSHIKBN,nIDOYOKUSHIKBN,nHAKKOYOKUSHIKBN,nSHOKAIYOKUSHIKBN,vSHORICHUIKBN);
--  2025/06/05 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
            /*IF nYOKUSHIKBN = 0 THEN
               o_RATENA_REC.HOGOSHA_SHIENSOCHI := NULL;                    --保護者_支援措置
            ELSE
               o_RATENA_REC.HOGOSHA_SHIENSOCHI := '該当';
            END IF;*/
            IF 0 < nYOKUSHIKBN AND nYOKUSHIKBN < 99 THEN
               o_RATENA_REC.HOGOSHA_SHIENSOCHI := '対象';                    --保護者_支援措置
            ELSE
               o_RATENA_REC.HOGOSHA_SHIENSOCHI := NULL;
            END IF;
--  2025/06/05 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
            o_RATENA_REC.SOFUSAKI_SHIMEI := sTPARAMETER;                   --送付先氏名
            o_RATENA_REC.SOFUSAKI_YUBIN_NO := NULL;                        --送付先郵便番号
            o_RATENA_REC.SOFUSAKI_JUSHO := NULL;                           --送付先住所
            o_RATENA_REC.WSNUM := g_sWSNUM;                                --端末番号
            o_RATENA_REC.BATCHKBN := 2;                                    --即時バッチ区分
            o_RATENA_REC.JOBNUM := g_nJOBNUM;                              --ジョブNO
            --出入国記録照会対象者ワークファイル登録
            INSERT INTO GKBWSHUTSUNYUKOKU VALUES o_RATENA_REC;
         END LOOP;

         -- 終了
         RETURN TRUE;
    EXCEPTION
      WHEN OTHERS THEN
        NSQLCODE := SQLCODE;
        ROLLBACK;
        BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, SUBSTR('中間ファイル編集が異常終了しました。' || SQLERRM(NSQLCODE), 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FALSE;
    END FUNC_GET_JIDO_WK;

    --------------------------------------------------------
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;          --戻り値
        sSQL                          VARCHAR2(5000);
        sSQL1                         VARCHAR2(5000);   --件数用
        nRTN                          INTEGER;          --戻り値
        rGKBWL680R001                 GKBWL680R001%ROWTYPE;    -- 出入国記録照会書ワーク
        rGKBWL130R072                 GKBWL130R072%ROWTYPE;    -- 出入国記録照会書発送者一覧表ワーク
        rGKBWSHUTSUNYUKOKU            GKBWSHUTSUNYUKOKU%ROWTYPE;    -- 原級留置対象者一覧ワーク
        sMEISHO                       NVARCHAR2(1000);         --名称
        sMEISHOKANA                   NVARCHAR2(1000);         --名称カナ
        sYOBI                         NVARCHAR2(1000);         --予備
        vZOKUGARAMEI                  NVARCHAR2(1000);         --続柄名称
        nIHERR                        PLS_INTEGER;             --エラーコード
        sKOKUMEI_KANA                 NVARCHAR2(1000);         --国名カナ
        sKOKUMEI                      NVARCHAR2(1000);         --国名
        sKOKUMEI_ALPHABET             NVARCHAR2(1000);         --国名アルファベット
        TYPE MC_CURSOR IS REF         CURSOR;                  --カーソルタイプ定義
        cCURSOR                       MC_CURSOR;
        nCNT                          NUMBER := 0;
        o_vSHIMEIKANA                 GKBWL680R001.JIDO_SHIMEI_KANA%TYPE;
        o_vSHIMEIKANJI                GKBWL680R001.JIDO_SHIMEI_KANJI%TYPE;
        o_vBIRTHDAY                   GKBWL680R001.JIDO_HYOJI_SEINENGAPI%TYPE;
        vKYOIKUIINKAICD               NUMBER;                  -- 教育委員会コード
        NTKAI_KENSUHYO                NVARCHAR2(300);          -- 退職介護件数表出力有無
        NTKAI_DATA_KBN                NVARCHAR2(300);          -- 退職介護データ区分
        NTKAI_KOUMOKU_NO              NVARCHAR2(300);          -- 退職介護項目番号
        sCHOHYOCODE                   NVARCHAR2(100);    --帳票コード
        VSORT_JOKEN                   NVARCHAR2(500); -- ソート条件
    BEGIN
      -- 初期処理
      nCOUNT := 0;
      -- ソート条件が1項目目の場合
      IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
        VSORT_JOKEN := ' ORDER BY ' || g_rJSTP.Orderbyclause;
      END IF;
      -- 出入国記録照会対象者ワークの情報を取得する学齢簿カーソル
      sSQL := '';
      sSQL := ' SELECT *'; 
      sSQL := sSQL || ' FROM GKBWSHUTSUNYUKOKU'; 
      sSQL := sSQL || ' WHERE WSNUM  = ' || '''' || g_sWSNUM || ''''; 
      sSQL := sSQL || ' AND BATCHKBN = 2'; 
      IF VSORT_JOKEN IS NOT NULL THEN
         sSQL := sSQL || VSORT_JOKEN ;
      END IF;
      
      -- 出入国記録照会対象者ワークの情報件数
      sSQL1 := '';
      sSQL1 := ' SELECT COUNT(*)'; 
      sSQL1 := sSQL1 || ' FROM GKBWSHUTSUNYUKOKU'; 
      sSQL1 := sSQL1 || ' WHERE WSNUM  = ' || '''' || g_sWSNUM || ''''; 
      sSQL1 := sSQL1 || ' AND BATCHKBN = 2'; 
      IF VSORT_JOKEN IS NOT NULL THEN
         sSQL1 := sSQL1 || VSORT_JOKEN ;
      END IF;
      EXECUTE IMMEDIATE sSQL1 INTO nCOUNT;

      --出入国記録照会書対象件数
      g_nINDEX := g_nINDEX + 1;
      g_oKENSU_LIST.EXTEND(1);
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT,'入力 出入国記録照会書対象件数',1);
      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT,'入力　出入国記録照会書対象件数',1);
--2024/08/06 ZCZL.XIAOYA ADD START 0.3.000.001:検収指摘No.142の対応
      --　原級留置対象者一覧ワークテーブル初期化
      CASE g_rJSTP.CHOHYOID
          WHEN 'GKB680R001' THEN
              DELETE FROM GKBWL680R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
--  2024/10/21 ZCZL.WANGMING UPDATE 0.3.000.005:　IT_GKB_00341対応
--          WHEN 'GKB130R072' THEN
          WHEN 'GKB130R002' THEN
              DELETE FROM GKBWL130R072 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
      ELSE
          NULL;
      END CASE;
--2024/08/06 ZCZL.XIAOYA ADD END
      OPEN cCURSOR FOR sSQL;
        LOOP
          FETCH cCURSOR INTO rGKBWSHUTSUNYUKOKU;
          EXIT WHEN cCURSOR%NOTFOUND;
--  2025/01/30 JYJYS.SONGSHIHAO UPDATE 0.3.000.010:品質強化：ST_GKB_TMP00023対応 Start
        IF rGKBWSHUTSUNYUKOKU.GAKKO_KBN_CD = 1 THEN
          BEGIN
            SELECT KYOIKUIINKAI_CD
              INTO vKYOIKUIINKAICD
             FROM GKBTSHOGAKKO
             --WHERE GAKKOKU_CD = rGKBWSHUTSUNYUKOKU.GAKKO_CD;
             WHERE SYOGAKO_CD = rGKBWSHUTSUNYUKOKU.GAKKO_CD;
          EXCEPTION
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--            WHEN NO_DATA_FOUND THEN
            WHEN OTHERS THEN
              vKYOIKUIINKAICD := NULL;
          END;
        ELSIF  rGKBWSHUTSUNYUKOKU.GAKKO_KBN_CD = 2 THEN
          IF vKYOIKUIINKAICD IS NULL THEN
              BEGIN
                SELECT KYOIKUIINKAI_CD
                  INTO vKYOIKUIINKAICD
                 FROM GKBTCHUGAKKO
                 --WHERE GAKKOKU_CD = rGKBWSHUTSUNYUKOKU.GAKKO_CD;
                 WHERE TYUGAKO_CD = rGKBWSHUTSUNYUKOKU.GAKKO_CD;
              EXCEPTION
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--                WHEN NO_DATA_FOUND THEN
                WHEN OTHERS THEN
                  vKYOIKUIINKAICD := NULL;
              END;
          END IF;
        ELSIF  rGKBWSHUTSUNYUKOKU.GAKKO_KBN_CD = 4 THEN
          IF vKYOIKUIINKAICD IS NULL THEN
              BEGIN
                SELECT KYOIKUIINKAI_CD
                  INTO vKYOIKUIINKAICD
                 FROM GKBTKUIKIGAI
                 WHERE KUIKIGAI_CD = rGKBWSHUTSUNYUKOKU.GAKKO_CD;
              EXCEPTION
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--                WHEN NO_DATA_FOUND THEN
                WHEN OTHERS THEN
                  vKYOIKUIINKAICD := NULL;
              END;
          END IF;
        ELSIF  rGKBWSHUTSUNYUKOKU.GAKKO_KBN_CD = 3 THEN
          IF vKYOIKUIINKAICD IS NULL THEN
              BEGIN
                SELECT KYOIKUIINKAI_CD
                  INTO vKYOIKUIINKAICD
                 FROM GKBTYOGOGAKKO
                 WHERE YOGOGAKO_CD = rGKBWSHUTSUNYUKOKU.GAKKO_CD;
              EXCEPTION
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--                WHEN NO_DATA_FOUND THEN
                WHEN OTHERS THEN
                  vKYOIKUIINKAICD := NULL;
              END;
          END IF;
        ELSIF  rGKBWSHUTSUNYUKOKU.GAKKO_KBN_CD = 5 THEN
          IF vKYOIKUIINKAICD IS NULL THEN
              BEGIN
                SELECT KYOIKUIINKAI_CD
                  INTO vKYOIKUIINKAICD
                 FROM GKBTKUNISIRITSUGAKKO
                 WHERE KUNISHIRITSUGAKKO_CD = rGKBWSHUTSUNYUKOKU.GAKKO_CD;
              EXCEPTION
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--                WHEN NO_DATA_FOUND THEN
                WHEN OTHERS THEN
                  vKYOIKUIINKAICD := NULL;
              END;
          END IF;
        END IF;
        --  2025/01/30 JYJYS.SONGSHIHAO UPDATE 0.3.000.010:品質強化：ST_GKB_TMP00023対応 End
          nCNT := nCNT + 1;
      
          -- 変数.発行履歴 = 0:作成する かつ、グローバル変数.バッチジョブステップ情報.帳票IDが「出入国記録照会書」の場合、
          CASE g_rJSTP.CHOHYOID
              WHEN 'GKB680R001' THEN
                  --　原級留置対象者一覧ワークテーブル初期化
--2024/08/06 ZCZL.XIAOYA DELETE 0.3.000.001:検収指摘No.142の対応
--                   DELETE FROM GKBWL680R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
                  rGKBWL680R001.NO                   := nCNT;                                    -- ソート順
                  rGKBWL680R001.ATENA                := rGKBWSHUTSUNYUKOKU.SOFUSAKI_SHIMEI;      -- 宛名
                  IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
                      rGKBWL680R001.BUNSHO_NO        := g_rBUNNUM;                               -- 文書番号
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                      rGKBWL680R001.BUNSHO_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL680R001.BUNSHO_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
                  ELSE
                      rGKBWL680R001.BUNSHO_NO        := NULL;
                  END IF;
--  2024/09/24 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00019対応
--                  rGKBWL680R001.HAKKO_YMD            := rGKBWSHUTSUNYUKOKU.HAKKO_YMD;            -- 発行年月日
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応 start
                  --rGKBWL680R001.HAKKO_YMD            := rGKBWSHUTSUNYUKOKU.HYOJI_HAKKO_YMD;        -- 表示発行年月日
                  rGKBWL680R001.HAKKO_YMD            := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(rGKBWSHUTSUNYUKOKU.HYOJI_HAKKO_YMD, 0),' ',''),'　','');        -- 表示発行年月日
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応 end
                  rGKBWL680R001.NINSHOSHA_SHOKUSHU   := sKATAGAKI1;                              -- 認証者職種
                  rGKBWL680R001.NINSHOSHA_MEI        := sSHIMEI;                               -- 認証者名
                  rGKBWL680R001.KOIN_PATH            := sKOIN;                                   -- 公印パス
                  rGKBWL680R001.KOIN_SHORYAKU        := g_vKOIN_SHORYAKU;                        -- 公印（省略）
                  rGKBWL680R001.KOIN_CHUSHAKU        := g_vKOIN_CHUSHAKU;                            -- 公印（注釈）
                  rGKBWL680R001.TITLE                := g_vCHOHYO_MEI;                        -- タイトル
                  rGKBWL680R001.TSUCHI_BUN           := REPLACE(g_vTSUCHIBUN, chr(13)||chr(10),'#');-- 通知文
                  IF rGKBWSHUTSUNYUKOKU.JIDO_JINKAKU_KBN = 0 THEN
                      rGKBWL680R001.TAISHO_KIROKU    := '日本人出帰国記録';                       -- 照会対象記録
                  ELSIF rGKBWSHUTSUNYUKOKU.JIDO_JINKAKU_KBN = 1 THEN
                      rGKBWL680R001.TAISHO_KIROKU    := '外国人出入国記録';                       -- 照会対象記録
                  END IF;
                  rGKBWL680R001.JIDO_KOKUSEKI        := rGKBWSHUTSUNYUKOKU.JIDO_KOKUSEKI;        -- 児童生徒国籍
                  IF GKBFKHMCTRL(rGKBWSHUTSUNYUKOKU.JIDO_KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_vGKB010_CTL, o_vSHIMEIKANA, o_vSHIMEIKANJI, o_vBIRTHDAY) = 0 THEN
                      -- 児童氏名かな
                      rGKBWL680R001.JIDO_SHIMEI_KANA  := o_vSHIMEIKANA;                          -- 児童生徒氏名カナ
                      -- 児童氏名漢字
                      rGKBWL680R001.JIDO_SHIMEI_KANJI := o_vSHIMEIKANJI;                         -- 児童生徒氏名漢字
                      -- 表示生年月日
                  END IF;
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応 start
--                      rGKBWL680R001.JIDO_HYOJI_SEINENGAPI  := o_vBIRTHDAY;                       -- 児童生徒表示生年月日
                        rGKBWL680R001.JIDO_HYOJI_SEINENGAPI  :=  TRANSLATE(
                                                      SUBSTR(rGKBWSHUTSUNYUKOKU.Jido_Seinengapi, 1, 4) || '年' ||
                                                      TO_NUMBER(SUBSTR(rGKBWSHUTSUNYUKOKU.Jido_Seinengapi, 5, 2)) || '月' ||
                                                      TO_NUMBER(SUBSTR(rGKBWSHUTSUNYUKOKU.Jido_Seinengapi, 7, 2)) || '日',
                                                      '0123456789','０１２３４５６７８９');     -- 児童生徒表示生年月日
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応 end
                  rGKBWL680R001.JIDO_SEIBETSU        := rGKBWSHUTSUNYUKOKU.JIDO_SEIBETSU;        -- 児童生徒性別
                  rGKBWL680R001.JIDO_GENJUSHO        := rGKBWSHUTSUNYUKOKU.JIDO_GENJUSHO;        -- 児童生徒現住所
                  rGKBWL680R001.ZAIRYU_CARD_TOU_NO   := rGKBWSHUTSUNYUKOKU.ZAIRYU_CARD_TOU_NO;   -- 在留カード番号
                  IF (rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA1 = 4 OR rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA1 = 6) 
                    AND rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA2 = 0 AND rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA3 = 0 
                    AND rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA4 = 0 THEN
                      rGKBWL680R001.CHICHI_KOKUSEKI      := rGKBWSHUTSUNYUKOKU.HOGOSHA_KOKUSEKI;
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応 start
--                      rGKBWL680R001.CHICHI_SEINENGAPI    := rGKBWSHUTSUNYUKOKU.HOGOSHA_HYOJI_SEINENGAPI;
                      rGKBWL680R001.CHICHI_SEINENGAPI    := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(rGKBWSHUTSUNYUKOKU.HOGOSHA_HYOJI_SEINENGAPI, 0),' ',''),'　','');
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応 end
                      rGKBWL680R001.CHICHI_SHIMEI_KANA   := rGKBWSHUTSUNYUKOKU.HOGOSHA_SHIMEI_KANA;
                      rGKBWL680R001.CHICHI_SHIMEI_KANJI  := rGKBWSHUTSUNYUKOKU.HOGOSHA_SHIMEI_KANJI;
                  ELSE
                      rGKBWL680R001.CHICHI_KOKUSEKI      := NULL;                                    -- 父親_国籍
                      rGKBWL680R001.CHICHI_SEINENGAPI    := NULL;                                    -- 父親_生年月日
                      rGKBWL680R001.CHICHI_SHIMEI_KANA   := NULL;                                    -- 父親_氏名カナ
                      rGKBWL680R001.CHICHI_SHIMEI_KANJI  := NULL;                                    -- 父親_氏名漢字
                  END IF;
                  IF (rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA1 = 5 OR rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA1 = 7) 
                    AND rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA2 = 0 AND rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA3 = 0 
                    AND rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA4 = 0 THEN
                      rGKBWL680R001.HAHA_KOKUSEKI        := rGKBWSHUTSUNYUKOKU.HOGOSHA_KOKUSEKI;
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応 start
--                      rGKBWL680R001.HAHA_SEINENGAPI      := rGKBWSHUTSUNYUKOKU.HOGOSHA_HYOJI_SEINENGAPI;
                        rGKBWL680R001.HAHA_SEINENGAPI      := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(rGKBWSHUTSUNYUKOKU.HOGOSHA_HYOJI_SEINENGAPI, 0),' ',''),'　','');
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応 end
                      rGKBWL680R001.HAHA_SHIMEI_KANA     := rGKBWSHUTSUNYUKOKU.HOGOSHA_SHIMEI_KANA;
                      rGKBWL680R001.HAHA_SHIMEI_KANJI    := rGKBWSHUTSUNYUKOKU.HOGOSHA_SHIMEI_KANJI;
                  ELSE
                      rGKBWL680R001.HAHA_KOKUSEKI        := NULL;                                    -- 母親_国籍
                      rGKBWL680R001.HAHA_SEINENGAPI      := NULL;                                    -- 母親_生年月日
                      rGKBWL680R001.HAHA_SHIMEI_KANA     := NULL;                                    -- 母親_氏名カナ
                      rGKBWL680R001.HAHA_SHIMEI_KANJI    := NULL;                                    -- 母親_氏名漢字
                  END IF;
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応 start
--                  rGKBWL680R001.CHOSA_KIKAN          := g_vCHOSABI;                              -- 調査期間
                  rGKBWL680R001.CHOSA_KIKAN          := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_vCHOSABI, 0),' ',''),'　','');   -- 調査期間                           -- 調査期間
--  2025/01/09 JYJYS.GL UPDATE 0.3.000.009:品質強化：IT_GKB_10149~IT_GKB_10154対応 end
                  rGKBWL680R001.TENPU_RENRAKU        := REPLACE(g_vTOKKIJIKO, chr(13)||chr(10),'#');-- 添付物連絡文
                  -- 共通関数(KKAPK0030.FPRMSHUTOKU)を使用してパラメータ取得する。
                  IF vKYOIKUIINKAICD IS NOT NULL THEN
                      IF KKAPK0030.FPRMSHUTOKU('GKB', '00KYOIKUKAI', vKYOIKUIINKAICD, o_ACONSPRM, o_NPRMSUM) = 0 THEN
                        rGKBWL680R001.TOIAWASESAKI1  := o_ACONSPRM(1);                           -- お問い合わせ先１
                        rGKBWL680R001.TOIAWASESAKI2  := o_ACONSPRM(6);                           -- お問い合わせ先２
                        rGKBWL680R001.TOIAWASESAKI3  := o_ACONSPRM(7);                           -- お問い合わせ先３
                      END IF;
                  ELSE
                      rGKBWL680R001.TOIAWASESAKI1    := NULL;                                    -- お問い合わせ先１
                      rGKBWL680R001.TOIAWASESAKI2    := NULL;                                    -- お問い合わせ先２
                      rGKBWL680R001.TOIAWASESAKI3    := NULL;                                    -- お問い合わせ先３
                  END IF;
                  rGKBWL680R001.YOSHIKI_NO           := g_vYOSHIKI;                              -- 様式番号
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
                  rGKBWL680R001.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rGKBWL680R001.YOSHIKI_NO,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
                  rGKBWL680R001.BREAK_NO             := nCNT;                                    -- 改ページキー
                  rGKBWL680R001.WSNUM                := rGKBWSHUTSUNYUKOKU.WSNUM;                -- 端末番号
                  rGKBWL680R001.BATCHKBN             := rGKBWSHUTSUNYUKOKU.BATCHKBN;             -- 即時バッチ区分
                  rGKBWL680R001.JOBNUM               := rGKBWSHUTSUNYUKOKU.JOBNUM;               -- ジョブNO

                  --登録中間ワークテーブル
                  INSERT INTO GKBWL680R001 VALUES rGKBWL680R001;
                  --発行履歴レコード作成
                  rGKATHAKKORIREKI.GYOMU_CD               :=  'GKB';                                                    --業務コード
                  rGKATHAKKORIREKI.KOJIN_NO               :=  rGKBWSHUTSUNYUKOKU.JIDO_KOJIN_NO;                         --宛名番号
                  rGKATHAKKORIREKI.CHOHYO_CD              :=  g_rJSTP.CHOHYONUM;                                        --帳票コード
                  rGKATHAKKORIREKI.NENDO                  :=  SUBSTR(g_vHAKOBI,1,4);                                    --年度
                  rGKATHAKKORIREKI.SHORI_KBN              :=  1;                                                        --処理区分
                  --通知書種別
                  rGKATHAKKORIREKI.TSUCHISHO_SHUBETSU     := '出入国記録照会書';
                  rGKATHAKKORIREKI.HAKKOBI                :=  TO_CHAR(SYSDATE,'YYYYMMDD');                               --発行日
                  rGKATHAKKORIREKI.HAKKO_JIKAN            :=  g_nTIME;                                                   --発行時間
                  rGKATHAKKORIREKI.HAKKO_MAISU            :=  1;                                                         --発行枚数
                  rGKATHAKKORIREKI.HAKKO_SHOKUINKOJIN_NO  :=  g_sTANTOCODE;                                              --発行職員宛名番号
                  rGKATHAKKORIREKI.SOFUBI                 :=  g_vHAKOBI;                                                 --送付日
                  rGKATHAKKORIREKI.TSUCHI_BASHO           :=  NULL;                                                      --通知場所
                  rGKATHAKKORIREKI.BUNSHOBANGO_SETTO      :=  rBUNNUMSRCINF.MAEMOJI;                                     --文書番号接頭語
                  rGKATHAKKORIREKI.BUNSHOBANGO            :=  REPLACE(REPLACE(rBUNNUMEDITKEKA.NUM,rBUNNUMSRCINF.MAEMOJI,''),rBUNNUMSRCINF.USHIROMOJI,''); --文書番号
                  rGKATHAKKORIREKI.BUNSHOBANGO_SETSUBI    :=  rBUNNUMSRCINF.USHIROMOJI;                                  --文書番号接尾語
                  rGKATHAKKORIREKI.TSUCHI_KOJIN_NO        :=  rGKBWSHUTSUNYUKOKU.HOGOSHA_KOJIN_NO;                       --通知対象者宛名番号
                  rGKATHAKKORIREKI.TENSAKI_JICHI_CD       :=  NULL;                                                      --転出先自治体コード
                  rGKATHAKKORIREKI.SYS_TANMATSU_NO        :=  g_sWSNUM;                                                  --更新端末番号
                                    
                  IF g_sHakkoRireki = 0 THEN
                    --発行履歴の作成
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
                  --文書番号編集結果の取得
                  IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (rBUNNUMSRCINF.NUMINCTYPE = 1 OR rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
                      KKAPK0040.SBunNumIc(rBUNNUMSRCINF, rBUNNUMEDITKEKA);
                  END IF;
                  --文書番号保管を追加する
                  IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
                    g_rHOKANBUNNUM(nCNT).KOJIN_NUM := RTAISHO.KOJIN_NO;
                    g_rHOKANBUNNUM(nCNT).BUNSHO_NO := rBUNNUMEDITKEKA.NUM; 
                  END IF;
                  g_rBUNNUM := rBUNNUMEDITKEKA.NUM; 
--  2024/10/21 ZCZL.WANGMING UPDATE 0.3.000.005:　IT_GKB_00341対応
--              WHEN 'GKB130R072' THEN
              WHEN 'GKB130R002' THEN
                  --　原級留置対象者一覧ワークテーブル初期化
--2024/08/06 ZCZL.XIAOYA DELETE 0.3.000.001:検収指摘No.142の対応
--                   DELETE FROM GKBWL130R072 WHERE WSNUM = g_sWSNUM AND BATCHKBN = 2;
                  rGKBWL130R072 := NULL;
                  rGKBWL130R072.NO                        := nCNT;                               -- ソート順
--  2024/09/24 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00019対応
--                  rGKBWL130R072.SAKUSEI_YMD               := TO_DATE(g_vBASEDATEYMD, 'YYYY/MM/DD');  -- 作成年月日
                  rGKBWL130R072.SAKUSEI_YMD               := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_vBASEDATEYMD),'YYYY/MM/DD'),12);  -- 作成年月日
                  rGKBWL130R072.TITLE                     := g_vCHOHYO_MEI || '発送者一覧表';     -- 帳票タイトル
                  IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
                      -- 変数.文書番号退避リストに格納されている、宛名番号と出入国記録照会対象者ワーク.宛名番号が一致するレコードの文書番号を取得し、設定する。
                      FOR i IN 1..g_rHOKANBUNNUM.COUNT LOOP
                        IF g_rHOKANBUNNUM(i).KOJIN_NUM = rGKBWSHUTSUNYUKOKU.JIDO_KOJIN_NO THEN
                          rGKBWL130R072.BUNSHO_NO         :=  g_rHOKANBUNNUM(i).BUNSHO_NO;     -- 文書番号
                          EXIT;
                        END IF;
                      END LOOP;
                  ELSE
                      rGKBWL130R072.BUNSHO_NO             := NULL;                               -- 文書番号
                  END IF;
                  rGKBWL130R072.HAKKO_YMD                 := rGKBWSHUTSUNYUKOKU.HYOJI_HAKKO_YMD; -- 発行年月日
                  rGKBWL130R072.SOFUSAKI_SHIMEI           := rGKBWSHUTSUNYUKOKU.SOFUSAKI_SHIMEI; -- 送付先氏名
                  rGKBWL130R072.SOFUSAKI_YUBIN_NO         := rGKBWSHUTSUNYUKOKU.SOFUSAKI_YUBIN_NO;-- 送付先郵便番号
                  rGKBWL130R072.SOFUSAKI_JUSHO            := rGKBWSHUTSUNYUKOKU.SOFUSAKI_JUSHO;  -- 送付先住所
                  IF GKBFKHMCTRL(rGKBWSHUTSUNYUKOKU.JIDO_KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_vGKB010_CTL, o_vSHIMEIKANA, o_vSHIMEIKANJI, o_vBIRTHDAY) = 0 THEN
                      -- 児童氏名かな
                      rGKBWL130R072.JIDO_SHIMEI_KANA  := o_vSHIMEIKANA;                          -- 児童生徒氏名カナ
                      -- 児童氏名漢字
                      rGKBWL130R072.JIDO_SHIMEI_KANJI := o_vSHIMEIKANJI;                         -- 児童生徒氏名漢字
                      -- 表示生年月日
                      rGKBWL130R072.SEINENGAPI        := o_vBIRTHDAY;                            -- 児童生徒表示生年月日
                  END IF;
                  rGKBWL130R072.SEIBETSU              := rGKBWSHUTSUNYUKOKU.JIDO_SEIBETSU;       -- 性別
                  rGKBWL130R072.JIDO_SHIENSOCHI       := rGKBWSHUTSUNYUKOKU.JIDO_SHIENSOCHI;     -- 児童生徒_支援措置
                  IF GKBFKHMCTRL(rGKBWSHUTSUNYUKOKU.JIDO_KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_vGKB010_CTL, o_vSHIMEIKANA, o_vSHIMEIKANJI, o_vBIRTHDAY) = 0 THEN
                      rGKBWL130R072.HOGOSHA_SHIMEI_KANA  := o_vSHIMEIKANA;                       -- 保護者氏名カナ
                      rGKBWL130R072.HOGOSHA_SHIMEI_KANJI := o_vSHIMEIKANJI;                      -- 保護者氏名漢字
                  END IF;
                  rGKBWL130R072.HOGOSHA_ZOKUGARA      := rGKBWSHUTSUNYUKOKU.HOGOSHA_ZOKUGARA;    -- 児童生徒との関係
                  rGKBWL130R072.HOGOSHA_SHIENSOCHI    := rGKBWSHUTSUNYUKOKU.HOGOSHA_SHIENSOCHI;  -- 保護者_支援措置
                  rGKBWL130R072.GAKKO_MEI             := rGKBWSHUTSUNYUKOKU.GAKKO_MEI;           -- 学校名
                  rGKBWL130R072.KENSU                 := nCOUNT;                                   -- 件数
                  rGKBWL130R072.GAKKO_CD              := rGKBWSHUTSUNYUKOKU.GAKKO_CD;            -- 学校コード
                  rGKBWL130R072.JIDO_SHIMEI_LABEL     := '児童生徒氏名';                          -- 児童生徒氏名_ラベル
                  rGKBWL130R072.HOGOSHA_SHIMEI_LABEL  := '保護者氏名';                            -- 保護者氏名_ラベル
                  rGKBWL130R072.GAKO_GYOSEIKU_LABEL   := '学校';                                  -- 学校/行政区_ラベル
                  IF rGKBWSHUTSUNYUKOKU.JIDO_JINKAKU_KBN = '1' THEN
                      rGKBWL130R072.JINKAKU_KBN       := '＊';                                    -- 人格区分
                  ELSE
                      rGKBWL130R072.JINKAKU_KBN       := NULL;                                    -- 人格区分
                  END IF;
                  --  2025/01/30 JYJYS.SONGSHIHAO UPDATE 0.3.000.010:品質強化：ST_GKB_TMP00023対応 Start
                  --rGKBWL130R072.BREAK_NO              := nCNT / 10 + 1;                         -- 改ページキー
                  rGKBWL130R072.BREAK_NO              := NULL;                                    -- 改ページキー
                  --  2025/01/30 JYJYS.SONGSHIHAO UPDATE 0.3.000.010:品質強化：ST_GKB_TMP00023対応 End
                  rGKBWL130R072.WSNUM                 := rGKBWSHUTSUNYUKOKU.WSNUM;                -- 端末番号
                  rGKBWL130R072.BATCHKBN              := rGKBWSHUTSUNYUKOKU.BATCHKBN;             -- 即時バッチ区分
                  rGKBWL130R072.JOBNUM                := rGKBWSHUTSUNYUKOKU.JOBNUM;               -- ジョブNO
                  --登録中間ワークテーブル
                  INSERT INTO GKBWL130R072 VALUES rGKBWL130R072;
              ELSE
                NULL;
          END CASE;
        END LOOP;
      CLOSE cCURSOR;

--  2024/10/21 ZCZL.WANGMING ADD 0.3.000.005:　IT_GKB_00341対応
      IF g_rJSTP.CHOHYOID = 'GKB680R001' THEN
        --出入国記録照会書ＣＳＶ件数
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
--  2024/09/02 ZCZL.LIUCHAGNQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCNT,'出力  出入国記録照会書ＣＳＶ',2);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCNT,'出力　出入国記録照会書ＣＳＶ',2);
--  2024/10/21 ZCZL.WANGMING ADD 0.3.000.005:　IT_GKB_00341対応
      END IF;
       --関数終了
      bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV作成処理', 0, '', '', '出入国記録照会書ＣＳＶ' || nCNT ||'件を出力しました', g_sTANTOCODE, g_sWSNUM, 1);
      RETURN TRUE;

    EXCEPTION
        WHEN OTHERS THEN
            IF cCURSOR%ISOPEN THEN
            CLOSE cCURSOR;
            END IF;
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'CSV出力処理', 1, SQLCODE, SQLERRM, 'ＣＳＶファイルの書き出し処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_CSV_CREATE;
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
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
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_JYOKEN_GET
        RETURN BOOLEAN
    IS
    BEGIN

        -- 1.共通関数(KKAPK0020.FNENDOHENKAN)で処理条件の各種日付を西暦変換する。
        -- 処理条件の日付を西暦変換する。
        g_vBASEDATEYMD  := KKAPK0020.FNENDOHENKAN(g_nKIJUNBI);
        g_vSEINENGAPIFR := KKAPK0020.FNENDOHENKAN(g_nSEINENGAPIFR);
        g_vSEINENGAPITO := KKAPK0020.FNENDOHENKAN(g_nSEINENGAPITO);
        g_vHAKOBI       := KKAPK0020.FNENDOHENKAN(g_nHAKOBI);
        
        -- 2.共通関数（KKAPK0020.FDAYEDIT20）で印刷用の日付を編集する。
        g_vCHOSABIFR := KKAPK0020.FDAYEDIT20(g_nCHOSABIFR,1,3);
        g_vCHOSABITO := KKAPK0020.FDAYEDIT20(g_nCHOSABITO,1,3);
        
        -- 変数.表示調査期間に調査開始日の編集結果（2-1-1の戻り値）+ "から”　+ 調査終了日の編集結果（2-1-2の戻り値）+ "まで" を設定する。
        g_vCHOSABI   := g_vCHOSABIFR || 'から' || g_vCHOSABITO || 'まで';
        
        -- 表示発行日
--  2024/09/24 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更　IT_GKB_00019対応
--        g_vHAKOYMD   := KKAPK0020.FDAYEDIT20(g_nHAKOBI,1,3);
        g_vHAKOYMD   := KKAPK0020.FDAYEDIT20(g_nHAKOBI,0,3);

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
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        eException       EXCEPTION;
        IRTN             NUMBER;   --戻り値
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        -- 条件取得処理を呼び出す。
        bRTN := FUNC_JYOKEN_GET;
        IF NOT bRTN THEN
            RAISE eException;
        END IF;

        -- 初期処理
        bRTN := FUNC_INIT;
        IF NOT bRTN THEN
            RAISE eException;
        END IF;
        -- 出入国記録照会対象者中間ワークファイルをクリアする。
        IRTN := KKAPK3000.FTRUNCATE( 'GKBWSHUTSUNYUKOKU', VSQLERRM );
        IF IRTN <> 0 THEN
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('中間ファイル削除処理が異常終了しました。' || VSQLERRM, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          RAISE eException;
        END IF;

        -- 出入国記録照会対象者ワーク中間データ編集と作成
        bRTN := FUNC_GET_JIDO_WK;
        IF NOT bRTN THEN
          RAISE eException;
        END IF;

        -- ＣＳＶファイル作成処理
        bRTN := FUNC_CSV_CREATE;
        IF bRTN <> TRUE THEN
          RAISE eException;
        END IF;

        -- CSV出力処理を呼び出す
        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB680R001' THEN
            bRTN := FUNC_B11CSV('GKBWL680R001');
--  2024/10/21 ZCZL.WANGMING UPDATE 0.3.000.005:　IT_GKB_00341対応
--          WHEN 'GKB130R072' THEN
          WHEN 'GKB130R002' THEN
            bRTN := FUNC_B11CSV('GKBWL130R072');
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
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
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
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新表処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
    END FUNC_B20UPDATE1;
    --------------------------------------------------------
    --  機能概要      : バッチ処理の呼出
    --                 指定した期限内の原級留置対象者一覧表を作成する。
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_nRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/07/01
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
END GKBPB00630;
/