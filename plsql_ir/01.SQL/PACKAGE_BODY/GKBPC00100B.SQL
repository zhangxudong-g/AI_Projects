CREATE OR REPLACE PACKAGE BODY GKBPC00100
--1.0.008.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 入学・進級・卒業
--  機能概要      : 小学校入学、小学校卒業、中学校入学
--                  中学校卒業、および進級による学齢簿の一括更新処理を行う
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
--------------------------------------------------------
--  変更履歴
--  2024/06/12 ZCZL.lvjq Update 0.3.000.000:新WizLIFE２次開発
--  2024/08/08 ZCZL.WANGQIWEI Update 0.3.000.001:検収指摘No.564の対応
--  2024/08/12 ZCZL.WANGQIWEI Update 0.3.000.002:検収指摘No.564_2回目の対応
--  2024/09/03 ZCZL.YANGSHUAI Update 0.3.000.003:IT_GKB_00075対応
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.004:8月1日認識合わせの横展開
--  2024/10/30 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00213仕様変更対応
--  2024/11/12 ZCZL.WANGYUNING UPDATE 0.3.000.006:IT_GKB_00491仕様変更対応
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00689対応
--  2024/12/27 JIP.Y.SATO UPDATE 0.3.000.009:故障対応
--  2025/06/10 CTC.LIUJUNHAO UPDATE 1.0.008.000:GKB_QA15679_前年度以前に転出しているような児童も進級卒業処理の対象になる対応
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

    --画面から条件
    g_vJYOUKEN1  NVARCHAR2(500);
    g_vJYOUKEN2  NVARCHAR2(500);
    g_vJYOUKEN3  NVARCHAR2(500);
    g_vJYOUKEN4  NVARCHAR2(500);
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
    g_vJYOUKEN5                   NUMBER;
    g_nSUGYOFLG                   NUMBER;                        -- 進級卒業可能
    g_nSHORIDAY                   NUMBER;                        -- 処理日
    VNENDO                        NVARCHAR2(15);                 -- 対象年度
    g_nGNRIREKIBAN                NUMBER;                        -- 学年履歴
    g_nCSVCNT                     NUMBER := 0;                   -- CSV出力件数_還付公金融機関・支店未登録対象一覧
    g_nSHINKYUSOTUGYOU_KENSU      NUMBER := 0;                   -- 進級・卒業処理対象者件数
-- 2024/06/12 ZCZL.Lvjq Add end
-- 2024/06/12 ZCZL.Lvjq Delete 0.3.000.000:新WizLIFE２次開発
--    g_nTIME NUMBER;  --時分秒
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD 0.3.000.004:8月1日認識合わせの横展開
    nCNT                          NUMBER;                          --CSV出力件数
    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;
--2025/01/03 JIP.Y.SATO ADD ST
    g_SYS_TANMATU_BASHO GKBTGAKUREIBO.SYS_TANMATU_BASHO%TYPE;
    sBUKACODE           KKNTWS.BUKACODE%TYPE;
--2025/01/03 JIP.Y.SATO ADD ED
------------------------------------------------------------------------------
--  カーソル定義
------------------------------------------------------------------------------
-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
    CURSOR CJIDO IS
--  SELECT KOJIN_NO,
--       GAKUNEN AS GAKUNEN_CD
--  FROM GKBTGAKUREIBO
--  WHERE GAKUNEN<>99 AND SAISHIN_KBN=0;
    SELECT  GKBTGAKUREIBO.KOJIN_NO
           ,GKBTGAKUREIBO.GAKUNEN AS GAKUNEN_CD
           ,GKBTGAKUREIBO.RIREKI_RENBAN
           ,GKBTGAKUREIBO.RIREKI_RENBAN_EDA
           ,GABTATENAKIHON.SHIMEI_KANA
           ,GABTATENAKIHON.SHIMEI_KANJI
--2025/01/03 JIP.Y.SATO UPD ST
--           ,GKBTSHUGAKURIREKI.SAISHIN_FLG
--           ,GKBTSHUGAKURIREKI.S_TAIGAKU_BI
--           ,GKBTSHUGAKURIREKI.T_TAIGAKU_BI
--           ,GKBTSHUGAKURIREKI.SHIEN_T_CD
--           ,GKBTSHUGAKURIREKI.KUIKIGAI_T_CD
--           ,GKBTSHUGAKURIREKI.KUNISHIRITSU_T_CD
           ,NVL(GKBTSHUGAKURIREKI.SAISHIN_FLG,0) SAISHIN_FLG
           ,NVL(GKBTSHUGAKURIREKI.S_TAIGAKU_BI,0) S_TAIGAKU_BI
           ,NVL(GKBTSHUGAKURIREKI.T_TAIGAKU_BI,0) T_TAIGAKU_BI
           ,NVL(GKBTSHUGAKURIREKI.SHIEN_T_CD,0) SHIEN_T_CD
           ,NVL(GKBTSHUGAKURIREKI.KUIKIGAI_T_CD,0) KUIKIGAI_T_CD
           ,NVL(GKBTSHUGAKURIREKI.KUNISHIRITSU_T_CD,0) KUNISHIRITSU_T_CD
    FROM  GKBTGAKUREIBO
    INNER JOIN GABTATENAKIHON
       ON  GKBTGAKUREIBO.KOJIN_NO = GABTATENAKIHON.KOJIN_NO
--    INNER JOIN GKBTSHUGAKURIREKI
    LEFT JOIN GKBTSHUGAKURIREKI
       ON  GKBTGAKUREIBO.KOJIN_NO = GKBTSHUGAKURIREKI.KOJIN_NO
      AND  GKBTSHUGAKURIREKI.SAISHIN_FLG = 0
      AND  GKBTSHUGAKURIREKI.SAKUJO_FLG = 0
    WHERE  GKBTGAKUREIBO.GAKUNEN <> 99
      AND  GKBTGAKUREIBO.SAISHIN_KBN = 0
      --AND  GKBTGAKUREIBO.GEN_NENGAPI = 0
      --AND  GKBTGAKUREIBO.GEN_JIYU_CD = 0
      AND  GKBTGAKUREIBO.SAKUJO_FLG = 0
--  2025/06/10 CTC.LIUJUNHAO UPDATE 1.0.008.000:GKB_QA15679_前年度以前に転出しているような児童も進級卒業処理の対象になる対応
      AND  GABTATENAKIHON.GENZON_KBN = 0
--  2025/06/10 CTC.LIUJUNHAO UPDATE 1.0.008.000:GKB_QA15679_前年度以前に転出しているような児童も進級卒業処理の対象になる対応
      --AND  GKBTSHUGAKURIREKI.NENDO = VNENDO  --2024/12/27 JIP.Y.SATO DEL
      --AND  GKBTSHUGAKURIREKI.KOJIN_RIREKI_RENBAN = GKBTGAKUREIBO.RIREKI_RENBAN
      --AND  GKBTSHUGAKURIREKI.SHUGAKU_RIREKI_RENBAN = GKBTGAKUREIBO.RIREKI_RENBAN
      --AND  GKBTSHUGAKURIREKI.SAISHIN_FLG = 0
      --AND  GKBTSHUGAKURIREKI.SAKUJO_FLG = 0;
      ;
--2025/01/03 JIP.Y.SATO UPD ED
-- 2024/06/12 ZCZL.Lvjq Update end
------------------------------------------------------------------------------
--  定数宣言
------------------------------------------------------------------------------
    -- ERROR関連 --
    -- デバック
    N_SQL_CODE     NUMBER;             -- SQLエラーコード
    V_SQL_MSG      NVARCHAR2(255);     -- SQLエラーメッセージ
    -- 処理結果
    c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    c_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし
    -- 戻り値

------------------------------------------------------------------------------
--  変数宣言
------------------------------------------------------------------------------
    ISAKUSEIBI         PLS_INTEGER;
    NSYSTIME           NUMBER;
    RG                 GKBTGAKUREIBO%ROWTYPE;
    RA                 GABTATENAKIHON%ROWTYPE;
    RASO               GABTSOFUSAKI%ROWTYPE;
    VSASKUSEIBI        NVARCHAR2(30);
    VSHONYUBI          NVARCHAR2(14);
    VSHOSOBI           NVARCHAR2(14);
    VCHUNYUBI          NVARCHAR2(14);
    VCHUSOBI           NVARCHAR2(14);
    IGAKUNEN           PLS_INTEGER;
    ISHONYUBI          PLS_INTEGER;
    ISEIREKI_SHONYUBI  PLS_INTEGER;
    ISHOSOBI           PLS_INTEGER;
    ISEIREKI_SHOSOBI   PLS_INTEGER;
    ICHUNYUBI          PLS_INTEGER;
    ISEIREKI_CHUNYUBI  PLS_INTEGER;
    ICHUSOBI           PLS_INTEGER;
    ISEIREKI_CHUSOBI   PLS_INTEGER;
    VHYOJI_SHONYUBI    NVARCHAR2(18);
    VHYOJI_SHOSOBI     NVARCHAR2(18);
    VHYOJI_CHUNYUBI    NVARCHAR2(18);
    VHYOJI_CHUSOBI     NVARCHAR2(18);
    IJIDOCNT           PLS_INTEGER;
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN               BOOLEAN;
    I_RTN              PLS_INTEGER;
    -- 処理条件（画面からの引数）
-- 2024/06/12 ZCZL.Lvjq Delete 0.3.000.000:新WizLIFE２次開発
--    VNENDO          NVARCHAR2(15);      -- 対象年度
    VNENDO_GYY      NVARCHAR2(15);      -- 対象年度(GYY)

    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    IWAREKIHIZUKE                  PLS_INTEGER;
    VEDIT_GYYMMDD2                 NVARCHAR2(20);
    VEDIT_GYYMMDD3                 NVARCHAR2(20);
    VKJ_GENGO                      NVARCHAR2(20);
    VKG_GENGO                      NVARCHAR2(20);
    IWAREKI_YY                     PLS_INTEGER;
    ISEIREKI_YYYY                  PLS_INTEGER;
    IWAREKI_GYYMM                  PLS_INTEGER;
    IMM                            PLS_INTEGER;
    IDD                            PLS_INTEGER;
    IOWAREKIHIZUKE                 PLS_INTEGER;
    ISEIREKIHIZUKE                 PLS_INTEGER;
    ACONSPRM_KYOUIKU               A_CONS_PRM;
    NLENGTH                        NUMBER;
    IRTN_KYOUIKU                   NUMBER;
    NRIREKI_RENBAN                 NUMBER;
    NRENBAN_COUNT                  NUMBER;
    NSYS_SAKUSEIBI                 NUMBER(8,0);
    NSYS_KOSHINBI                  NUMBER(8,0);
    NSYS_JIKAN                     NUMBER(6,0);
    NSYS_SHOKUINKOJIN_NO           CHAR(12);
    VSYS_TANMATU_NO                NVARCHAR2(63);

    VMSG NVARCHAR2(4000);
    VERRMSG NVARCHAR2(1000);
    IRTN PLS_INTEGER ;
    --日付変換パラメータ
    IWAREKIHIDUKEIO  PLS_INTEGER;
    ISEIREKIHIDUKEIO PLS_INTEGER;
    VEDIT1O          NVARCHAR2(20);
    VEDIT2O          NVARCHAR2(20);
    VEDIT3O          NVARCHAR2(20);
    VGENGOKANJIO     NVARCHAR2(10);
    VGENGOKIGOO      NVARCHAR2(10);
    IWAREKINENO      PLS_INTEGER;
    ISEIREKINENO     PLS_INTEGER;
    IWAREKINENGETUO  PLS_INTEGER;
    ITUKIO           PLS_INTEGER;
    IDAYO            PLS_INTEGER;
    IWAREKIHIDUKEO   PLS_INTEGER;
    ISEIREKIHIDUKEO  PLS_INTEGER;

    ERR              EXCEPTION;
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
    RG2              GKBTGAKUREIBO%ROWTYPE;
    SG               GKBTSHUGAKURIREKI%ROWTYPE;
    SG2              GKBTSHUGAKURIREKI%ROWTYPE;
    GN               GKBTGAKUNENRIREKI%ROWTYPE;
    RGVALUE                 GKBTGAKUREIBO%ROWTYPE;
    SGVALUE                 GKBTSHUGAKURIREKI%ROWTYPE;
    SGVALUE2                GKBTSHUGAKURIREKI%ROWTYPE;
    NGSOVALUE               GKBTGAKUNENRIREKI%ROWTYPE;
-- 2024/06/12 ZCZL.Lvjq Add end
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
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
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
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
-- 2024/06/12 ZCZL.Lvjq Update 0.3.000.000:新WizLIFE２次開発
--        g_nTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));--時分秒
        NSYSTIME := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));--時分秒

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
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT RETURN BOOLEAN
    IS
-- 2024/09/03 ZCZL.YANGSHUAI ADD 0.3.000.003:IT_GKB_00075対応
      v_oSinKyuSoTsuGyoTaiSho     DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
      g_vJYOUKEN1 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShogakkoNyugakuYMD');
      g_vJYOUKEN2 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShogakkoSotsugyoYMD');
      g_vJYOUKEN3 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtChugakkoNyugakuYMD');
      g_vJYOUKEN4 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtChugakkoSotsugyoYMD');
-- 2024/06/12 ZCZL.Lvjq Add 0.3.000.000:新WizLIFE２次開発
-- 2024/09/03 ZCZL.YANGSHUAI Update start 0.3.000.003:IT_GKB_00075対応
--    g_vJYOUKEN5 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSinKyuSoTsuGyoTaiSho');
      v_oSinKyuSoTsuGyoTaiSho := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'txtSinKyuSoTsuGyoTaiSho');
      g_vJYOUKEN5 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtSinKyuSoTsuGyoTaiSho',0,v_oSinKyuSoTsuGyoTaiSho);
-- 2024/08/30 ZCZL.YANGSHUAI Update end
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B01PINIT;
    --------------------------------------------------------
-- 2024/06/12 ZCZL.Lvjq Add 0.3.000.000:新WizLIFE２次開発
    --  機能概要      : 排他制御
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvjq   2024/06/29
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

-- 2024/06/12 ZCZL.Lvjq Add 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------
    --  機能概要      : 学齢簿最新レコードの取得
    --  パラメータ     :  i_nKOJIN_NO
    --              : i_vNENDO
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 SG,その他 NULL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvjq   2024/06/29
    --------------------------------------------------------
    FUNCTION FUNC_SG_GET(i_nKOJIN_NO IN NUMBER, i_vNENDO IN NVARCHAR2 ) RETURN GKBTSHUGAKURIREKI%ROWTYPE
    IS
    BEGIN
          SELECT
              *
              INTO SG
          FROM
              (
                  SELECT
                      *
                  FROM
                      GKBTSHUGAKURIREKI SG
                  WHERE
                      SG.KOJIN_NO = i_NKOJIN_NO
                      --AND SG.NENDO = i_VNENDO  --2024/12/27 JIP.Y.SATO DEL
--  2024/11/12 ZCZL.WANGYUNING UPDATE 0.3.000.006:IT_GKB_00491仕様変更対応
                      --AND SG.SAISHIN_FLG = 1
                  ORDER BY
                      SG.KOJIN_RIREKI_RENBAN DESC
                      , SG.SHUGAKU_RIREKI_RENBAN DESC
              )
          WHERE
              ROWNUM = 1;
      RETURN SG;
    EXCEPTION
    --2024/12/27 JIP.Y.SATO ADD ST
        WHEN NO_DATA_FOUND THEN
            SELECT
                 i_nKOJIN_NO
                ,i_vNENDO
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
            INTO SG
            FROM
                DUAL;
            RETURN SG;
    --2024/12/27 JIP.Y.SATO ADD ED
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SG_GET', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE;
        RETURN SG;
    END FUNC_SG_GET;
    --------------------------------------------------------
    --  機能概要      : 学齢簿最新レコードの取得
    --  パラメータ    : i_nKOJIN_NO　　宛名番号
    --             : i_vNENDO   　年度
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 SG,その他 NULL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvjq   2024/06/29
    --------------------------------------------------------
    FUNCTION FUNC_GN_GET(i_nKOJIN_NO IN NUMBER, i_vNENDO IN NVARCHAR2 ) RETURN GKBTGAKUNENRIREKI%ROWTYPE
    IS
    BEGIN
        SELECT
            *
        INTO GN
        FROM
            GKBTGAKUNENRIREKI SG
        WHERE
            SG.KOJIN_NO = i_nKOJIN_NO
            --2024/12/27 JIP.Y.SATO UPD ST
            --AND SG.NENDO = i_vNENDO
            --AND SG.KOJIN_RIREKI_RENBAN = (
            AND ROWNUM = 1
            AND SG.GAKUNEN_RIREKI_RENBAN = (
            --2024/12/27 JIP.Y.SATO UPD ED
                SELECT
                    --2024/12/27 JIP.Y.SATO UPD ST
                    --MAX(KOJIN_RIREKI_RENBAN)
                    MAX(GAKUNEN_RIREKI_RENBAN)
                    --2024/12/27 JIP.Y.SATO UPD ED
                FROM
                    GKBTGAKUNENRIREKI
                WHERE
                    KOJIN_NO = i_nKOJIN_NO
                    --AND NENDO = i_vNENDO  --2024/12/27 JIP.Y.SATO DEL
--  2024/11/12 ZCZL.WANGYUNING UPDATE START 0.3.000.006:IT_GKB_00491仕様変更対応                    
                    --AND SAISIN_FLG = 1
            --)
            --AND SG.SAISIN_FLG = 1;
            );
--  2024/11/12 ZCZL.WANGYUNING UPDATE END
        RETURN GN;
    EXCEPTION
    --2024/12/27 JIP.Y.SATO ADD ST
        WHEN NO_DATA_FOUND THEN
            SELECT
                 i_nKOJIN_NO
                ,i_vNENDO
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
            INTO GN
            FROM
                DUAL;
            RETURN GN;
    --2024/12/27 JIP.Y.SATO ADD ED
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_NG_GET', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE;
        RETURN GN;
    END FUNC_GN_GET;
    --------------------------------------------------------
    --  機能概要      : 学齢簿最新履歴連番の取得
    --  パラメータ    : i_nKOJIN_NO 宛名番号
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 g_nGNRIREKIBAN,その他 NULL
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.lvjq   2024/06/29
    --------------------------------------------------------
    FUNCTION FUNC_NEW_RIREKIRENBAN_GET(i_nKOJIN_NO IN NUMBER) RETURN PLS_INTEGER
    IS
    nGNRIREKIBAN number;
    BEGIN
          -- 変数.学齢簿履歴連番
          SELECT
              *
              INTO nGNRIREKIBAN
          FROM
              (
                  SELECT
                      RIREKI_RENBAN
                  FROM
                      GKBTGAKUREIBO
                  WHERE
                      KOJIN_NO = i_nKOJIN_NO
-- 2024/09/03 ZCZL.YANGSHUAI Update START 0.3.000.003:IT_GKB_00075対応
--                      AND SAISHIN_KBN = 0
--  2024/11/21 JPJYS.LIUHUAIQI DELETE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 Start
--                      AND SAISHIN_KBN = 1
--  2024/11/21 JPJYS.LIUHUAIQI DELETE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 End
-- 2024/09/03 ZCZL.YANGSHUAI Update END
                  ORDER BY
                      RIREKI_RENBAN DESC
                      , RIREKI_RENBAN_EDA DESC
              )
          WHERE
              ROWNUM = 1;
      RETURN nGNRIREKIBAN;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_NEW_RIREKIRENBAN_GET', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE;
        RETURN nGNRIREKIBAN;
    END FUNC_NEW_RIREKIRENBAN_GET;
    --------------------------------------------------------
-- 2024/06/12 ZCZL.Lvjq Add end
    --  機能概要      : バッチ処理画面入力値取得（帳票）
    --  パラメータ    : i_STEPSEQ     バッチジョブステップ連番
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
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
-- 2024/06/12 ZCZL.Lvjq Add 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------
    --  機能概要      : ファイル等更新説明書（学齢簿_U）
    --  パラメータ        : i_KOJIN_NO             宛名番号
    --                : i_RIREKI_RENBAN         履歴連番
    --                : i_RIREKI_RENBAN_EDA     児童生徒_個人履歴番号枝番
    --                : i_nGAKUNEN              学年
    --                : i_SAKUSEIDAY            作成日
    --                : i_GAKKO_KBN_CD          学校区分
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq   2024/06/20
    --------------------------------------------------------
    FUNCTION FUNC_GAKUREIBO_UPDATE(i_nGAKUNEN            IN  NUMBER,
                                   i_SAKUSEIDAY          IN  NUMBER,
                                   i_GAKKO_KBN_CD        IN  NUMBER,
                                   i_KOJIN_NO            IN  NUMBER,
                                   i_RIREKI_RENBAN       IN  NUMBER,
                                   i_RIREKI_RENBAN_EDA   IN  NUMBER) RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;  --戻り値
    BEGIN
        UPDATE GKBTGAKUREIBO
          SET GAKUNEN = i_nGAKUNEN,
              SHORIBI = i_SAKUSEIDAY,
              GAKKO_KBN_CD = i_GAKKO_KBN_CD,
              GAKUKYU_CD = 0,
              SYS_KOSHINBI = i_SAKUSEIDAY,
              SYS_JIKAN = NSYSTIME,
              SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
              SYS_TANMATU_NO = g_sWSNUM
             ,SYS_TANMATU_BASHO = g_SYS_TANMATU_BASHO  --2025/01/03 JIP.Y.SATO ADD
        WHERE KOJIN_NO = i_KOJIN_NO
          AND RIREKI_RENBAN = i_RIREKI_RENBAN
          AND RIREKI_RENBAN_EDA = i_RIREKI_RENBAN_EDA
          AND SAISHIN_KBN = 0;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_GAKUREIBO_UPDATE;

    --------------------------------------------------------
    --  機能概要      : ファイル等更新説明書（学齢簿_I）
    --  パラメータ    : i_RG    学齢簿
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq   2024/06/20
    --------------------------------------------------------
    FUNCTION FUNC_GAKUREIBO_INSERT(i_TABLEVALUE IN GKBTGAKUREIBO%ROWTYPE) RETURN BOOLEAN
    IS
        bRTN                           BOOLEAN;
    BEGIN
      --「DB・ファイル等更新説明書（学齢簿_I）」の①.aを参照
      INSERT INTO GKBTGAKUREIBO VALUES i_TABLEVALUE;
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_GAKUREIBO_INSERT;
    --------------------------------------------------------
    --  機能概要      : ファイル等更新説明書（就学履歴_I）
    --  パラメータ    : i_RG    就学履歴
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq   2024/06/20
    --------------------------------------------------------
    FUNCTION FUNC_SHUGAKURIREKI_INSERT(i_TABLEVALUE IN GKBTSHUGAKURIREKI%ROWTYPE) RETURN BOOLEAN
    IS
        bRTN                           BOOLEAN;
    BEGIN
      --「DB・ファイル等更新説明書（就学履歴_I」の①.aを参照
      INSERT INTO GKBTSHUGAKURIREKI VALUES i_TABLEVALUE;
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_SHUGAKURIREKI_INSERT;
    --------------------------------------------------------
    --  機能概要      : ファイル等更新説明書（学年履歴_I）
    --  パラメータ    : i_RG    学齢簿
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq   2024/06/20
    --------------------------------------------------------
    FUNCTION FUNC_GAKUNENRIREKI_INSERT(i_TABLEVALUE IN GKBTGAKUNENRIREKI%ROWTYPE) RETURN BOOLEAN
    IS
        bRTN                           BOOLEAN;
    BEGIN
      --「DB・ファイル等更新説明書（学年履歴_I）」の①.aを参照
      INSERT INTO GKBTGAKUNENRIREKI VALUES i_TABLEVALUE;
      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_GAKUNENRIREKI_INSERT;
-- 2024/06/12 ZCZL.Lvjq Add end
    ----------------------------------------------------------------------------------------------------
    --日付の大小チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIKAKUCHK( i_VHIDUKE1 IN NVARCHAR2, i_VHIDUKE2 IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
      HIDUKE1 NUMBER ;
      HIDUKE2 NUMBER ;
    BEGIN
      IRET := 0 ;
      HIDUKE1  := TO_NUMBER( i_VHIDUKE1 );
      HIDUKE2  := TO_NUMBER( i_VHIDUKE2 );
      --大小チェック
      IF i_VHIDUKE1 > i_VHIDUKE2 THEN
        IRET := 1;
      END IF;
      RETURN(IRET) ;
    END FUNCHIKAKUCHK;
    ----------------------------------------------------------------------------------------------------
    --日付チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    BRET BOOLEAN ;
    BEGIN
      IRET := 0 ;
      BEGIN
        IF i_VHIZUKE IS NULL THEN
          IRET := 1;
        ELSIF LENGTH(i_VHIZUKE) <> 7 THEN
          IRET := 1;
        ELSE
          IWAREKIHIDUKEIO  := TO_NUMBER(i_VHIZUKE);
          ISEIREKIHIDUKEIO := 0;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      IF IRET = 0 THEN
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

      RETURN(IRET) ;
    END FUNCHIZUKECHK;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                : o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
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
        IRTN := 0 ;
        --条件１のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN1 ) ;
        IF IRTN <> 0 THEN
          VERRMSG := g_sGYOUMUCODE || ',99999,小学校入学年月日が正しくありません。,;';
          VMSG := VMSG || VERRMSG;
        ELSE
          VERRMSG := KKBPK5551.FJOKENDATECHK('GKB',  g_sSHORIID,0, 1, 1, g_vJYOUKEN1);
          IF VERRMSG IS NOT NULL THEN
            VMSG := VMSG || VERRMSG;
          END IF;
        END IF ;

        --条件２のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN2 ) ;
        IF IRTN <> 0 THEN
          VERRMSG := g_sGYOUMUCODE || ',99999,小学校卒業年月日が正しくありません。,;';
          VMSG := VMSG || VERRMSG;
        ELSE
          VERRMSG := KKBPK5551.FJOKENDATECHK('GKB',  g_sSHORIID,0, 2, 1, g_vJYOUKEN2);
          IF VERRMSG IS NOT NULL THEN
            VMSG := VMSG || VERRMSG;
          END IF;
        END IF ;

        --条件３のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN3 ) ;
        IF IRTN <> 0 THEN
          VERRMSG := g_sGYOUMUCODE || ',99999,中学校入学年月日が正しくありません。,;';
          VMSG := VMSG || VERRMSG;
        ELSE
          VERRMSG := KKBPK5551.FJOKENDATECHK('GKB',  g_sSHORIID,0, 3, 1, g_vJYOUKEN3);
          IF VERRMSG IS NOT NULL THEN
            VMSG := VMSG || VERRMSG;
          END IF;
        END IF ;

        --条件４のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN4 ) ;
        IF IRTN <> 0 THEN
          VERRMSG := g_sGYOUMUCODE || ',99999,中学校卒業年月日が正しくありません。,;';
          VMSG := VMSG || VERRMSG;
        ELSE
          VERRMSG := KKBPK5551.FJOKENDATECHK('GKB',  g_sSHORIID,0, 4, 1, g_vJYOUKEN4);
          IF VERRMSG IS NOT NULL THEN
            VMSG := VMSG || VERRMSG;
          END IF;
        END IF ;

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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
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
-- 2024/06/12 ZCZL.Lvjq Add 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------
    --  機能概要       : 学齢簿、就学履歴、学年履歴の最新区分を解除する
    --  パラメータ        : i_KOJIN_NO              RG.宛名番号
    --                : i_RIREKI_RENBAN         RG.履歴連番
    --                : i_RIREKI_RENBAN_EDA     RG.児童生徒_個人履歴番号枝番
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq   2024/07/01
    --------------------------------------------------------
    PROCEDURE FUNC_UPDDATE(i_KOJIN_NO            IN  NUMBER,
                           i_RIREKI_RENBAN       IN  NUMBER,
                           i_RIREKI_RENBAN_EDA   IN  NUMBER)
    IS
        bRTN                          BOOLEAN;                  --戻り値
    BEGIN
       UPDATE GKBTGAKUREIBO
         SET SAISHIN_KBN = 1,
             SYS_KOSHINBI = ISAKUSEIBI,
             SYS_JIKAN = NSYSTIME,
             SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
             SYS_TANMATU_NO = g_sWSNUM
       WHERE KOJIN_NO = i_KOJIN_NO
         AND RIREKI_RENBAN = i_RIREKI_RENBAN
         AND RIREKI_RENBAN_EDA = i_RIREKI_RENBAN_EDA
         AND SAISHIN_KBN = 0;

       -- 「DB・ファイル等更新説明書（就学履歴_U）」を参照
       UPDATE GKBTSHUGAKURIREKI
         SET SAISHIN_FLG = 1,
             SYS_KOSHINBI = ISAKUSEIBI,
             SYS_JIKAN = NSYSTIME,
             SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
             SYS_TANMATU_NO = g_sWSNUM
       WHERE KOJIN_NO = i_KOJIN_NO
         --AND NENDO = VNENDO  --2024/12/27 JIP.Y.SATO DEL
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 Start
--         AND KOJIN_RIREKI_RENBAN = i_RIREKI_RENBAN_EDA
         --AND KOJIN_RIREKI_RENBAN = i_RIREKI_RENBAN  --2024/12/27 JIP.Y.SATO DEL
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 End
         AND SAISHIN_FLG = 0;

       -- 「DB・ファイル等更新説明書（学年履歴_U）」を参照
       UPDATE GKBTGAKUNENRIREKI
         SET SAISIN_FLG = 1,
             SYS_KOSHINBI = ISAKUSEIBI,
             SYS_JIKAN = NSYSTIME,
             SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
             SYS_TANMATU_NO = g_sWSNUM
       WHERE KOJIN_NO = i_KOJIN_NO
         --AND NENDO = VNENDO  --2024/12/27 JIP.Y.SATO DEL
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 Start
--         AND KOJIN_RIREKI_RENBAN = i_RIREKI_RENBAN_EDA
         --AND KOJIN_RIREKI_RENBAN = i_RIREKI_RENBAN  --2024/12/27 JIP.Y.SATO DEL
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 End
         AND SAISIN_FLG = 0;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END FUNC_UPDDATE;
    --------------------------------------------------------
    --  機能概要       : 就学履歴、学年履歴の最新区分を解除する
    --  パラメータ        : i_KOJIN_NO              RG.宛名番号
    --                : i_RIREKI_RENBAN         RG.履歴連番
    --                : i_RIREKI_RENBAN_EDA     RG.児童生徒_個人履歴番号枝番
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq   2024/07/01
    --------------------------------------------------------
    PROCEDURE FUNC_RIREKI_SET(i_KOJIN_NO            IN  NUMBER,
                           i_RIREKI_RENBAN       IN  NUMBER,
                           i_RIREKI_RENBAN_EDA   IN  NUMBER)
    IS
        bRTN                          BOOLEAN;                  --戻り値
    BEGIN
       -- 「DB・ファイル等更新説明書（就学履歴_U）」を参照
       UPDATE GKBTSHUGAKURIREKI
         SET SAISHIN_FLG = 1,
             SYS_KOSHINBI = ISAKUSEIBI,
             SYS_JIKAN = NSYSTIME,
             SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
             SYS_TANMATU_NO = g_sWSNUM
       WHERE KOJIN_NO = i_KOJIN_NO
         --AND NENDO = VNENDO  --2024/12/27 JIP.Y.SATO DEL
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 Start
--         AND KOJIN_RIREKI_RENBAN = i_RIREKI_RENBAN_EDA
         --AND KOJIN_RIREKI_RENBAN = i_RIREKI_RENBAN  --2024/12/27 JIP.Y.SATO DEL
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 End
         AND SAISHIN_FLG = 0;

       -- 「DB・ファイル等更新説明書（学年履歴_U）」を参照
       UPDATE GKBTGAKUNENRIREKI
         SET SAISIN_FLG = 1,
             SYS_KOSHINBI = ISAKUSEIBI,
             SYS_JIKAN = NSYSTIME,
             SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
             SYS_TANMATU_NO = g_sWSNUM
       WHERE KOJIN_NO = i_KOJIN_NO
         --AND NENDO = VNENDO  --2024/12/27 JIP.Y.SATO DEL
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 Start
--         AND KOJIN_RIREKI_RENBAN = i_RIREKI_RENBAN_EDA
         --AND KOJIN_RIREKI_RENBAN = i_RIREKI_RENBAN  --2024/12/27 JIP.Y.SATO DEL
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 End
         AND SAISIN_FLG = 0;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END FUNC_RIREKI_SET;
-- 2024/06/12 ZCZL.Lvjq Add end
    --------------------------------------------------------------------------------
    -- 一括更新処理
    --------------------------------------------------------------------------------
    FUNCTION FUNC_IKATU_UPD RETURN NUMBER IS
        IFRET                PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- 戻り値
        NPRTN                NUMBER;
        IRTN                 PLS_INTEGER;
        BRTN                 BOOLEAN;
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
        nNDSTARTBI           NUMBER;                    -- 年度開始日
        nNDENDBI             NUMBER;                    -- 年度終了日
        vHENKOJIYU           NVARCHAR2(1000);           -- 進級・卒業できなかった理由
        nRIREKIBAN           NUMBER;                    -- 学齢簿履歴連番
        nSYOGAKOCD           NUMBER;                    -- 小学校コード
        nCHUGAKOCD           NUMBER;                    -- 中学校コード
        vSYOGAKONM           NVARCHAR2(1000);           -- 学校名
        nSYOGAKOSOTSUGYOBI   NUMBER;
        nTYUGAKOCD           NUMBER;
        nGAKKOCD             NUMBER;
        nTSOTSUGYOBI         NUMBER;
        bRTNFLG              BOOLEAN;
-- 2024/06/12 ZCZL.Lvjq Add end
    BEGIN
        IFRET := c_INOTFOUND;                 -- 該当なし

        ICNT := 0;
        ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        NSYSTIME   := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS'));
        ISHONYUBI := TO_NUMBER(VSHONYUBI);
        BRTN := KKAPK0020.FDAYEDIT( ISHONYUBI,
                                     ISEIREKI_SHONYUBI,
                                     VHYOJI_SHONYUBI,
                                     VEDIT_GYYMMDD2,
                                     VEDIT_GYYMMDD3,
                                     VKJ_GENGO,
                                     VKG_GENGO,
                                     IWAREKI_YY,
                                     ISEIREKI_YYYY,
                                     IWAREKI_GYYMM,
                                     IMM,
                                     IDD,
                                     IOWAREKIHIZUKE,
                                     ISEIREKIHIZUKE);
        ISHOSOBI := TO_NUMBER(VSHOSOBI);
        BRTN := KKAPK0020.FDAYEDIT( ISHOSOBI,
                                     ISEIREKI_SHOSOBI,
                                     VHYOJI_SHOSOBI,
                                     VEDIT_GYYMMDD2,
                                     VEDIT_GYYMMDD3,
                                     VKJ_GENGO,
                                     VKG_GENGO,
                                     IWAREKI_YY,
                                     ISEIREKI_YYYY,
                                     IWAREKI_GYYMM,
                                     IMM,
                                     IDD,
                                     IOWAREKIHIZUKE,
                                     ISEIREKIHIZUKE);
        ICHUNYUBI := TO_NUMBER(VCHUNYUBI);
        BRTN := KKAPK0020.FDAYEDIT( ICHUNYUBI,
                                     ISEIREKI_CHUNYUBI,
                                     VHYOJI_CHUNYUBI,
                                     VEDIT_GYYMMDD2,
                                     VEDIT_GYYMMDD3,
                                     VKJ_GENGO,
                                     VKG_GENGO,
                                     IWAREKI_YY,
                                     ISEIREKI_YYYY,
                                     IWAREKI_GYYMM,
                                     IMM,
                                     IDD,
                                     IOWAREKIHIZUKE,
                                     ISEIREKIHIZUKE);
        ICHUSOBI := TO_NUMBER(VCHUSOBI);
        BRTN := KKAPK0020.FDAYEDIT( ICHUSOBI,
                                     ISEIREKI_CHUSOBI,
                                     VHYOJI_CHUSOBI,
                                     VEDIT_GYYMMDD2,
                                     VEDIT_GYYMMDD3,
                                     VKJ_GENGO,
                                     VKG_GENGO,
                                     IWAREKI_YY,
                                     ISEIREKI_YYYY,
                                     IWAREKI_GYYMM,
                                     IMM,
                                     IDD,
                                     IOWAREKIHIZUKE,
                                     ISEIREKIHIZUKE);
        BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                     ISAKUSEIBI,
                                     VEDIT_GYYMMDD3,
                                     VEDIT_GYYMMDD2,
                                     VSASKUSEIBI,
                                     VKJ_GENGO,
                                     VKG_GENGO,
                                     IWAREKI_YY,
                                     ISEIREKI_YYYY,
                                     IWAREKI_GYYMM,
                                     IMM,
                                     IDD,
                                     IOWAREKIHIZUKE,
                                     ISEIREKIHIZUKE);

--2025/01/03 JIP.Y.SATO ADD ST
        BEGIN
          SELECT  BUKACODE
            INTO  sBUKACODE
            FROM  KKNTWS
           WHERE  KKNTWS.WSNUM = g_sWSNUM;
        EXCEPTION
          WHEN OTHERS THEN
            sBUKACODE := NULL;
        END;
        IF sBUKACODE IS NOT NULL THEN
          BEGIN
            SELECT  BUKANAME
              INTO  g_SYS_TANMATU_BASHO
              FROM  KKNTBK
             WHERE  BUKACODE = sBUKACODE
               AND  KKNTBK.YUKOKIKANFR = (
                      SELECT MAX(YUKOKIKANFR)
                        FROM KKNTBK
                       WHERE BUKACODE = sBUKACODE
                      );
          EXCEPTION
            WHEN OTHERS THEN
              g_SYS_TANMATU_BASHO := NULL;
          END;
        ELSE
          g_SYS_TANMATU_BASHO := NULL;
        END IF;
--2025/01/03 JIP.Y.SATO ADD ED
        BEGIN

            -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
            FOR CRJIDO IN CJIDO LOOP
                GKBSKJDOG(CRJIDO.KOJIN_NO,RG,NPRTN);
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
                -- ③進級・卒業対象外処理
                -- (取得したレコード「RG」が下記のb~fいずれか該当の場合、該当の児童は④処理にいって、後続の2-2-2処理をスキップする）
                -- a.比較の日付設定
                -- 変数.西暦小学校入学年月日-10000を変数.年度開始日にセットする
                nNDSTARTBI := ISEIREKI_SHONYUBI - 10000;

                -- a-2. 年度終了日の設定
                -- 変数.西暦小学校卒業年月日を変数.年度終了日にセットする
                nNDENDBI := ISEIREKI_SHOSOBI;
                bRTNFLG := FALSE;
                -- b.処理を行う年度内に猶予・免除情報がある児童生徒
                -- （RG.就学猶予開始年月日　＞＝　変数.年度開始日　かつ　RG.就学猶予開始年月日　<=　変数.年度終了日）
                -- （RG.就学猶予終了年月日　＞＝　変数.年度開始日　かつ　RG.就学猶予終了年月日　<=　変数.年度終了日）
                IF g_nSUGYOFLG = '1' AND ((RG.YUYO_KAISI_BI >= nNDSTARTBI AND RG.YUYO_KAISI_BI <= nNDENDBI) OR
                  (RG.YUYO_SYURYO_BI >= nNDSTARTBI AND RG.YUYO_SYURYO_BI <= nNDENDBI)) THEN
                   vHENKOJIYU := '猶予対象者';
                   bRTNFLG := TRUE;
                -- （RG.就学免除_開始年月日　＞＝　変数.年度開始日　かつ　RG.就学免除_開始年月日　<=　変数.年度終了日）
                -- （RG.就学免除_終了年月日　＞＝　変数.年度開始日　かつ　RG.就学免除_終了年月日　<=　変数.年度終了日）
                ELSIF  g_nSUGYOFLG = '1' AND ((RG.MENJO_KAISI_BI >= nNDSTARTBI AND RG.MENJO_KAISI_BI <= nNDENDBI) OR
                  (RG.MENJO_SYURYO_BI >= nNDSTARTBI AND RG.MENJO_SYURYO_BI <= nNDENDBI)) THEN
                   vHENKOJIYU := '免除対象者';
                   bRTNFLG := TRUE;
                -- c.変数.進級卒業可能　＝　１（0：可能、１：不可）　かつ　下記の条件が満たす場合、変数.進級・卒業できなかった理由に「原級留置対象者」をセットする
                -- RG.原級留置_対象者フラグ　＝　1
                ELSIF  g_nSUGYOFLG = '1' AND RG.GENKYURYUCHI_FLG = 1 THEN
                   vHENKOJIYU := '原級留置対象者';
                   bRTNFLG := TRUE;
                -- d‐1.下記の条件が満たす場合、変数.進級・卒業できなかった理由に「区域外就学対象者」をセットする
                -- RG.学年　＜＞　6　かつ RG.学年　＜＞　9　かつ RG.区域外就学_終了年月日　＝　　変数.年度終了日
                ELSIF RG.GAKUNEN <> 6 AND RG.GAKUNEN <> 9 AND RG.KUIKIGAISHUGAKU_SYURYO_BI = nNDENDBI THEN
                    vHENKOJIYU := '区域外就学対象者';
                    bRTNFLG := TRUE;

                -- d‐2.下記の条件が満たす場合、変数.進級・卒業できなかった理由に「国・私立対象者」をセットする
                -- RG.学年　＜＞　6　かつ RG.学年　＜＞　9　かつ RG.国私立終了年月日　＝　　変数.年度終了日
                ELSIF RG.GAKUNEN <> 6 AND RG.GAKUNEN <> 9 AND RG.KUNISHIRITSU_SYURYO_BI = nNDENDBI THEN
                    vHENKOJIYU := '国・私立対象者';
                    bRTNFLG := TRUE;

                -- d-3.下記の条件が満たす場合、変数.進級・卒業できなかった理由に「就学変更対象者」をセットする
                -- （RG.就学校変更_開始年月日　＞＝　変数.年度開始日　かつ　就学校変更_開始年月日　<=　変数.年度終了日）
                -- （RG.就学校変更_終了年月日　＞＝　変数.年度開始日　かつ　RG.就学校変更_終了年月日　<=　変数.年度終了日）
                ELSIF ((RG.HENKO_KAISI_BI >= nNDSTARTBI AND RG.HENKO_KAISI_BI <= nNDENDBI) OR
                  (RG.HENKO_SYURYO_BI >= nNDSTARTBI AND RG.HENKO_SYURYO_BI <= nNDENDBI)) THEN
                   vHENKOJIYU := '就学変更対象者';
                   bRTNFLG := TRUE;

                -- e.下記の条件が満たす場合、変数.進級・卒業できなかった理由に「不就学対象者」をセットする
                -- （RG.不就学_開始年月日　＞＝　変数.年度開始日　かつ　RG.不就学_開始年月日　<=　変数.年度終了日）
                -- （RG.不就学_終了年月日　＞＝　変数.年度開始日　かつ　RG.不就学_終了年月日　<=　変数.年度終了日）
                ELSIF ((RG.HUSHUGAKU_KAISI_BI >= nNDSTARTBI AND RG.HUSHUGAKU_KAISI_BI <= nNDENDBI) OR
                  (RG.HUSHUGAKU_SYURYO_BI >= nNDSTARTBI AND RG.HUSHUGAKU_SYURYO_BI <= nNDENDBI)) THEN
                   vHENKOJIYU := '不就学対象者';
                   bRTNFLG := TRUE;

                -- f.下記の条件が満たす場合、退学者と判定する
                --  ・RG.区域外学校コード<>0　かつ　RG.区域外退学年月日 ＞ 0　の場合、※変数.進級・卒業できなかった理由　＝「区域外退学者。」
                ELSIF RG.KUIKIGAI_CD <> 0 AND RG.KUIKIGAI_TAIGAKU_BI > 0 THEN
                    vHENKOJIYU := '区域外退学者';
                    bRTNFLG := TRUE;
                --  ・RG.盲聾養護学校コード<> 0 　かつ　RG.盲聾養護学校退学年月日　＞０　の場合、※変数.進級・卒業できなかった理由　＝「特別支援学校退学者。」
                ELSIF RG.YOGOGAKO_CD <> 0 AND RG.YOGOGAKO_TAIGAKU_BI > 0 THEN
                    vHENKOJIYU := '特別支援学校退学者';
                    bRTNFLG := TRUE;
                --  ・RG.国・私立学校コード<> 0 　かつ　RG.国・私立退学年月日 ＞ 0　＞０　の場合、※変数.進級・卒業できなかった理由　＝「国・私立退学者。」
                ELSIF RG.KUNISHIRITSU_CD <> 0 AND RG.KUNISHIRITSU_TAIGAKU_BI > 0 THEN
                    vHENKOJIYU := '国・私立退学者';
                    bRTNFLG := TRUE;
                --  ・RG.小学校コード<> 0 　かつ　就学履歴.小学校_退学年月日　＞０　の場合、※変数.進級・卒業できなかった理由　＝「小学校退学者。」
                ELSIF RG.SYOGAKO_CD <> 0 AND CRJIDO.S_TAIGAKU_BI > 0 THEN
                    vHENKOJIYU := '小学校退学者';
                    bRTNFLG := TRUE;
                --  ・RG.中学校コード<> 0 　かつ　就学履歴.中学校_退学年月日　＞０　の場合、※変数.進級・卒業できなかった理由　＝「中学校退学者。」
                ELSIF RG.TYUGAKO_CD <> 0 AND CRJIDO.T_TAIGAKU_BI > 0 THEN
                    vHENKOJIYU := '中学校退学者';
                    bRTNFLG := TRUE;
                --2025/01/03 JIP.Y.SATO ADD ST
                ELSIF RG.GEN_NENGAPI <> 0 AND RG.GEN_JIYU_CD <> 0 THEN
                    vHENKOJIYU := '減異動対象者';
                    bRTNFLG := TRUE;
                --2025/01/03 JIP.Y.SATO ADD ED
                END IF;
                -- ④以上の対象外となるデータを進級・卒業対象外児童生徒一覧ワークに登録する
                IF bRTNFLG THEN
                  IF RG.GAKKO_KBN_CD = 1 THEN
                      nSYOGAKOCD := RG.SYOGAKO_CD;
                  ELSIF RG.GAKKO_KBN_CD = 2 THEN
                      nSYOGAKOCD := RG.TYUGAKO_CD;
                  ELSIF RG.GAKKO_KBN_CD = 3 THEN
                      nSYOGAKOCD := RG.YOGOGAKO_CD;
                  ELSIF RG.GAKKO_KBN_CD = 4 THEN
                      nSYOGAKOCD := RG.KUIKIGAI_CD;
                  ELSIF RG.GAKKO_KBN_CD = 5 THEN
                      nSYOGAKOCD := RG.KUNISHIRITSU_CD;
                  END IF;
                  vSYOGAKONM := GKAFKGKOGTEQ(RG.GAKKO_KBN_CD, nSYOGAKOCD);
                  INSERT INTO GKBWTAISHOGAI (KOJIN_NO
                                            ,SHIMEI_KANA
                                            ,SHIMEI_KANJI
                                            ,GAKKO_CD
                                            ,GAKKO_MEI
                                            ,GAKUNEN
                                            ,RIYU
                                            ,SYS_KOSHINBI
                                            ,SYS_JIKAN
                                            ,SYS_SHOKUINKOJIN_NO
                                            ,SYS_TANMATU_NO
                                            ) VALUES (
                                                 RG.KOJIN_NO
                                                ,CRJIDO.SHIMEI_KANA
                                                ,CRJIDO.SHIMEI_KANJI
                                                ,nSYOGAKOCD
                                                ,vSYOGAKONM
                                                ,RG.GAKUNEN
                                                ,vHENKOJIYU
                                                ,ISAKUSEIBI
                                                ,NSYSTIME
                                                ,g_sTANTOCODE
                                                ,g_sWSNUM);
                  CONTINUE;
                END IF;
                -- ※②で取得したレコード「RG」が下記のb~fいずれか該当の場合、該当の児童は④処理にいって、後続の2-2-2処理をスキップする
-- 2024/06/12 ZCZL.Lvjq Add end
                IF RG.SAISHIN_KBN = 0 THEN
                   IF CRJIDO.GAKUNEN_CD = 0 OR
                      CRJIDO.GAKUNEN_CD = 1 OR
                      CRJIDO.GAKUNEN_CD = 2 OR
                      CRJIDO.GAKUNEN_CD = 3 OR
                      CRJIDO.GAKUNEN_CD = 4 OR
                      CRJIDO.GAKUNEN_CD = 5 OR
                      CRJIDO.GAKUNEN_CD = 6 THEN
                      IF RG.SYOGAKO_CD <> 0 AND
                      (RG.SYOGAKO_CD <> 0
                       AND (RG.SYOGAKO_NYUGAKU_BI <> 0 OR RG.SYOGAKO_TENNYUGAKU_BI <> 0)
                       AND (RG.SYOGAKO_TENGAKU_BI = 0 AND RG.SYOGAKO_SOTSUGYO_BI = 0)
                      )AND
                         RG.SYOGAKO_TENGAKU_BI = 0 AND
                         RG.SYOGAKO_SOTSUGYO_BI = 0 THEN
                         IF CRJIDO.GAKUNEN_CD = 0 THEN
                            -- 小学校入学者
                            IGAKUNEN := CRJIDO.GAKUNEN_CD + 1;
                            UPDATE GKBTGAKUNENLNK
                               SET GAKUNEN_CD = IGAKUNEN,
-- 2024/06/12 ZCZL.Lvjq Add 0.3.000.000:新WizLIFE２次開発
                                   SYS_SAKUSEIBI = ISAKUSEIBI,
                                   SYS_KOSHINBI = ISAKUSEIBI,
                                   SYS_JIKAN = NSYSTIME,
                                   SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                   SYS_TANMATU_NO = g_sWSNUM
                            WHERE KOJIN_NO = RG.KOJIN_NO;
-- 2024/06/12 ZCZL.Lvjq Add 0.3.000.000:新WizLIFE２次開発
                            -- ・学齢簿、就学履歴、学年履歴の最新区分を解除する
                            FUNC_UPDDATE(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                            IF RG.SYOGAKO_NYUGAKU_BI = 0 THEN
-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
--                               UPDATE GKBTGAKUREIBO
--                                 SET SYOGAKO_NYUGAKU_BI = ISEIREKI_SHONYUBI,
--                                     SYS_KOSHINBI = ISAKUSEIBI,
--                                     SYS_JIKAN = NSYSTIME,
--                                     SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                     SYS_TANMATU_NO = g_sWSNUM
--                                    ,GAKUNEN = IGAKUNEN
--                                    ,SHORIBI = ISAKUSEIBI
--                                    ,GAKKO_KBN_CD = 1
--                                    ,GAKUKYU_CD = 0
--                               WHERE KOJIN_NO = RG.KOJIN_NO
--                                 AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
                               -- ・学齢簿、就学履歴、学年履歴にデータを登録する
                               -- 履歴を積むのため、現時点小学校卒業児童の学齢簿情報を取得する
                               rGVALUE :=  RG;
                               -- 「DB・ファイル等更新説明書（学齢簿_I）」の①.aを参照
                               rGVALUE.Rireki_Renban        := RG.RIREKI_RENBAN + 10;
                               rGVALUE.SYS_SAKUSEIBI        := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                               rGVALUE.SYS_KOSHINBI         := ISAKUSEIBI;
                               rGVALUE.SYS_JIKAN            := NSYSTIME;
                               rGVALUE.SYS_SHOKUINKOJIN_NO  := g_sTANTOCODE;
                               rGVALUE.SYS_TANMATU_NO       := g_sWSNUM;
                               rGVALUE.GRB_HENKO_TODOKEDE_BI:= g_nSHORIDAY;
                               rGVALUE.GRB_HENKO_BI         := g_nSHORIDAY;
                               rGVALUE.IDO_BI               := g_nSHORIDAY;
                               rGVALUE.TODOKEDE_BI          := g_nSHORIDAY;
                               rGVALUE.SYOGAKO_NYUGAKU_BI   := ISEIREKI_SHONYUBI;   -- 変数.西暦小学校入学年月日
                               rGVALUE.GAKUNEN              := IGAKUNEN;
                               rGVALUE.SHORIBI              := ISAKUSEIBI;
                               rGVALUE.GAKKO_KBN_CD         := 1;
                               rGVALUE.GAKUKYU_CD           := 0;
                               rGVALUE.JOTAI                := 2;
                               rGVALUE.SYS_TANMATU_BASHO    := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                               -- DB・ファイル等更新説明書（学齢簿_I）
                               bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                               rGVALUE := null;
                               -- （就学履歴と学年履歴は学齢簿の履歴連番を使用するのため、ここでサブクエリで学齢簿最新の履歴連番を取得する「※補足説明書の1を参照」）
                               g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                               -- 就学履歴レコードの取得
                               SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                               -- 「DB・ファイル等更新説明書（就学履歴_I）」の①.aを参照
                               sGVALUE                       := SG;
                               sGVALUE.Nendo                 := VNENDO;
                               sGVALUE.KOJIN_RIREKI_RENBAN   := g_nGNRIREKIBAN;
                               --2024/12/27 JIP.Y.SATO UPD ST
                               --sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN;
                               sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                               --2024/12/27 JIP.Y.SATO UPD ED
                               sGVALUE.SAISHIN_FLG           := 0;
                               sGVALUE.S_CD                  := RG.SYOGAKO_CD;
                               sGVALUE.S_NYUGAKU_BI          := ISEIREKI_SHONYUBI; -- 変数.西暦小学校入学年月日
                               sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                               sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                               sGVALUE.SYS_JIKAN             := NSYSTIME;
                               sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                               sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                               bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                               sGVALUE := null;
                               -- 「DB・ファイル等更新説明書（学年履歴_I）」の①.aを参照
                               GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                               NGSOVALUE := GN;
                               NGSOVALUE.NENDO                   := VNENDO;
                               NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                               --2024/12/27 JIP.Y.SATO ADD ST
                               NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                               --2024/12/27 JIP.Y.SATO ADD ED
                               NGSOVALUE.GAKKO_KBN_CD            := 1;
                               NGSOVALUE.GAKKO_CD                := RG.SYOGAKO_CD;
                               NGSOVALUE.SAISIN_FLG              := 0;
                               NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                               NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                               NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                               NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                               NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                               NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                               NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                               bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                               NGSOVALUE := null;
-- 2024/06/12 ZCZL.Lvjq Update end
                            ELSE
-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
--                               UPDATE GKBTGAKUREIBO
--                                 SET SYS_KOSHINBI = ISAKUSEIBI,
--                                     SYS_JIKAN = NSYSTIME,
--                                     SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                     SYS_TANMATU_NO = g_sWSNUM
--                                    ,GAKUNEN = IGAKUNEN
--                                    ,SHORIBI = ISAKUSEIBI
--                                    ,GAKKO_KBN_CD = 1
--                                    ,GAKUKYU_CD = 0
--                               WHERE KOJIN_NO = RG.KOJIN_NO
--                                 AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
                               -- 学齢簿、就学履歴、学年履歴にデータを登録する
                               -- 履歴を積むのため、現時点小学校卒業児童の学齢簿情報を取得する
                               -- 学齢簿から現時点のデータを抽出する
                               rGVALUE :=  RG;
                               -- 「DB・ファイル等更新説明書（学齢簿_I）」の①.bを参照
                               rGVALUE.Rireki_Renban        := RG.RIREKI_RENBAN + 10; -- 履歴連番
                               rGVALUE.SYS_SAKUSEIBI        := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                               rGVALUE.SYS_KOSHINBI         := ISAKUSEIBI;            -- 更新日
                               rGVALUE.SYS_JIKAN            := NSYSTIME;            -- 更新時間
                               rGVALUE.SYS_SHOKUINKOJIN_NO  := g_sTANTOCODE;          -- 更新職員宛名番号
                               rGVALUE.SYS_TANMATU_NO       := g_sWSNUM;              -- 更新端末番号
                               rGVALUE.GRB_HENKO_TODOKEDE_BI:= g_nSHORIDAY;           -- 学齢簿変更_届出年月日
                               rGVALUE.GRB_HENKO_BI         := g_nSHORIDAY;           -- 学齢簿変更_年月日
                               rGVALUE.IDO_BI               := g_nSHORIDAY;           -- 異動年月日
                               rGVALUE.TODOKEDE_BI          := g_nSHORIDAY;           -- 届出年月日
                               rGVALUE.GAKUNEN              := IGAKUNEN;
                               rGVALUE.SHORIBI              := ISAKUSEIBI;
                               rGVALUE.GAKKO_KBN_CD         := 1;
                               rGVALUE.GAKUKYU_CD           := 0;
                               rGVALUE.JOTAI                := 2;
                               rGVALUE.SYS_TANMATU_BASHO    := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                               -- 「DB・ファイル等更新説明書（学齢簿_I）」の①.bを参照
                               bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                               rGVALUE := NULL;
                               -- 「DB・ファイル等更新説明書（就学履歴_I）」の①.bを参照
                               g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                               -- 就学履歴レコードの取得
                               SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                               sGVALUE                       := SG;
                               sGVALUE.Nendo                 := VNENDO;
                               sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                               --2024/12/27 JIP.Y.SATO UPD ST
                               --sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN;
                               sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                               --2024/12/27 JIP.Y.SATO UPD ED
                               sGVALUE.Saishin_Flg           := 0;
                               sGVALUE.S_CD                  := RG.SYOGAKO_CD;
                               sGVALUE.S_NYUGAKU_BI          := RG.SYOGAKO_NYUGAKU_BI;  --2025/01/03 JIP.Y.SATO ADD
                               sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                               sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                               sGVALUE.SYS_JIKAN             := NSYSTIME;
                               sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                               sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                               bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                               sGVALUE := NULL;

                               -- 学年履歴レコードの取得
                               -- 「DB・ファイル等更新説明書（学年履歴_I）」の①.bを参照
                               GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                                NGSOVALUE := GN;
                                NGSOVALUE.NENDO                   := VNENDO;
                                NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                                --2024/12/27 JIP.Y.SATO ADD ST
                                NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                                --2024/12/27 JIP.Y.SATO ADD ED
                                NGSOVALUE.GAKKO_KBN_CD            := 1;
                                NGSOVALUE.GAKKO_CD                := RG.SYOGAKO_CD;
                                NGSOVALUE.SAISIN_FLG              := 0;
                                NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                                NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                                NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                                NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                                NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                                NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                                NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                                bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                                NGSOVALUE := NULL;
-- 2024/06/12 ZCZL.Lvjq Update end
                            END IF;

                         ELSIF CRJIDO.GAKUNEN_CD = 1 OR
                               CRJIDO.GAKUNEN_CD = 2 OR
                               CRJIDO.GAKUNEN_CD = 3 OR
                               CRJIDO.GAKUNEN_CD = 4 OR
                               CRJIDO.GAKUNEN_CD = 5 THEN
                               -- 小学校進級者
                               IGAKUNEN := CRJIDO.GAKUNEN_CD + 1;
                               UPDATE GKBTGAKUNENLNK
                                  SET GAKUNEN_CD = IGAKUNEN,
                                   SYS_KOSHINBI = ISAKUSEIBI,
                                   SYS_JIKAN = NSYSTIME,
                                   SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                   SYS_TANMATU_NO = g_sWSNUM
                               WHERE KOJIN_NO = RG.KOJIN_NO;

-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
--                               UPDATE GKBTGAKUREIBO
--                                 SET GAKUNEN = IGAKUNEN,
--                                     SHORIBI = ISAKUSEIBI,
--                                     GAKKO_KBN_CD = 1,
--                                     GAKUKYU_CD   = 0,
--                                     SYS_KOSHINBI = ISAKUSEIBI,
--                                     SYS_JIKAN = NSYSTIME,
--                                     SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                     SYS_TANMATU_NO = g_sWSNUM
--                               WHERE KOJIN_NO = RG.KOJIN_NO
--                                 AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
                              -- ・学齢簿、就学履歴、学年履歴の最新区分を解除する
                              FUNC_RIREKI_SET(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                               -- 「DB・ファイル等更新説明書（学齢簿_U）」の②を参照
                              BRTN := FUNC_GAKUREIBO_UPDATE(IGAKUNEN, ISAKUSEIBI, 1, RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                              g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                               -- 就学履歴レコードの取得
                               SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                               --「DB・ファイル等更新説明書（就学履歴_I）」の②を参照
                               sGVALUE                       := SG;
                               sGVALUE.Nendo                 := VNENDO;
                               sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                               sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                               sGVALUE.Saishin_Flg           := 0;
                               sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                               sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                               sGVALUE.SYS_JIKAN             := NSYSTIME;
                               sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                               sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                               bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                               sGVALUE := null;
                               -- 「DB・ファイル等更新説明書（学年履歴_I）」の②を参照
                               GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                               NGSOVALUE := GN;
                               NGSOVALUE.NENDO                   := VNENDO;
                               NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                               NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                               NGSOVALUE.SAISIN_FLG              := 0;
                               NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                               NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                               NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                               NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                               NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                               NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                               NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                               bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                               NGSOVALUE := NULL;
-- 2024/06/12 ZCZL.Lvjq Update end

                         ELSIF CRJIDO.GAKUNEN_CD = 6 THEN
                               -- 中学校入学者
                               IGAKUNEN := CRJIDO.GAKUNEN_CD + 1;
                               IRTN := GAAPK0030.FGETATENA(  RG.KOJIN_NO,
                                                           'GKB',
                                                           ISAKUSEIBI,
                                                           RA,
                                                           RASO);
                               UPDATE GKBTGAKUNENLNK
                                  SET GAKUNEN_CD = IGAKUNEN,
                                      SYS_KOSHINBI = ISAKUSEIBI,
                                      SYS_JIKAN = NSYSTIME,
                                      SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                      SYS_TANMATU_NO = g_sWSNUM
                               WHERE KOJIN_NO = RG.KOJIN_NO;
-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
-- 2024/09/03 ZCZL.YANGSHUAI Update START 0.3.000.003:IT_GKB_00075対応
--                               -- ・学齢簿、就学履歴、学年履歴の最新区分を解除する
--                               FUNC_UPDDATE(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                               IF RG.SYOGAKO_SOTSUGYO_BI = 0 OR RG.TYUGAKO_CD = 0 THEN
                                 -- ・学齢簿、就学履歴、学年履歴の最新区分を解除する
                                 FUNC_UPDDATE(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
-- 2024/09/03 ZCZL.YANGSHUAI Update END
--                                  UPDATE GKBTGAKUREIBO
--                                     SET SYOGAKO_SOTSUGYO_BI = DECODE(RG.SYOGAKO_SOTSUGYO_BI,0,ISEIREKI_SHOSOBI,RG.SYOGAKO_SOTSUGYO_BI),
--                                         TYUGAKO_CD = DECODE(RG.TYUGAKO_CD,0,RA.CHUGAKU_CD,RG.TYUGAKO_CD),
--                                         TYUGAKO_NYUGAKU_BI = ISEIREKI_CHUNYUBI,
--                                         SYS_KOSHINBI = ISAKUSEIBI,
--                                         SYS_JIKAN = NSYSTIME,
--                                         SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                         SYS_TANMATU_NO = g_sWSNUM
--                                        ,GAKUNEN = IGAKUNEN
--                                        ,SHORIBI = ISAKUSEIBI
--                                        ,GAKKO_KBN_CD = 2
--                                        ,GAKUKYU_CD   = 0
--                                   WHERE KOJIN_NO = RG.KOJIN_NO
--                                     AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
                                 -- 就学履歴レコードの取得
                                 SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                 IF SG.KUNISHIRITSU_T_CD = 0 AND SG.KUIKIGAI_T_CD = 0 AND SG.SHIEN_T_CD = 0 THEN
                                   BEGIN
                                     SELECT
                                        *
                                        INTO RG2
                                     FROM
                                        (
                                            SELECT
                                                *
                                            FROM
                                                GKBTGAKUREIBO T
                                            WHERE
                                                T.KOJIN_NO = CRJIDO.KOJIN_NO
                                            ORDER BY
                                                T.RIREKI_RENBAN DESC
                                                , T.RIREKI_RENBAN_EDA DESC
                                        )
                                      WHERE ROWNUM = 1;
                                    EXCEPTION
                                      WHEN OTHERS THEN
                                        RAISE;
                                    END;
                                   IF RG2.TYUGAKO_CD = 0 THEN
                                     nCHUGAKOCD := RA.CHUGAKU_CD;
                                   ELSE
                                     nCHUGAKOCD := RG2.TYUGAKO_CD;
                                   END IF;
                                 ELSE
                                   nCHUGAKOCD := 0;
                                 END IF;
                                 RG2 := NULL;
                                 -- 「DB・ファイル等更新説明書（学齢簿_I）」の③-1.aを参照
                                 RGVALUE := RG;
                                 RGVALUE.RIREKI_RENBAN := RG.RIREKI_RENBAN + 10;
                                 --DECODE(RG.小学校卒業年月日,0,変数.西暦小学校卒業年月日,RG.小学校卒業年月日)
                                 IF RG.SYOGAKO_SOTSUGYO_BI = 0 THEN
                                   RGVALUE.SYOGAKO_SOTSUGYO_BI := ISEIREKI_SHOSOBI;
                                 ELSE
                                   NULL;
                                 END IF;
                                 RGVALUE.TYUGAKO_CD              := nCHUGAKOCD;
                                 RGVALUE.SAISHIN_KBN             := 1;  --2024/12/27 JIP.Y.SATO ADD
                                 RGVALUE.GEN_JIYU_CD             := 0;
                                 RGVALUE.GEN_NENGAPI             := 0;
                                 RGVALUE.SYS_SAKUSEIBI           := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                                 RGVALUE.SYS_KOSHINBI            := ISAKUSEIBI;
                                 RGVALUE.SYS_JIKAN               := NSYSTIME;
                                 RGVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                                 RGVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                                 RGVALUE.GAKUNEN                 := 6;
                                 RGVALUE.SHORIBI                 := ISAKUSEIBI;
                                 --2024/12/27 JIP.Y.SATO UPD ST
                                 --RGVALUE.GAKKO_KBN_CD            := 2;
                                 RGVALUE.GAKKO_KBN_CD            := 1;
                                 --2024/12/27 JIP.Y.SATO UPD ED
                                 RGVALUE.GAKUKYU_CD              := 0;
                                 RGVALUE.JOTAI                   := 4;
                                 RGVALUE.GRB_HENKO_TODOKEDE_BI   := g_nSHORIDAY;
                                 RGVALUE.GRB_HENKO_BI            := g_nSHORIDAY;
                                 RGVALUE.GRB_HENKO_JIYU          := 10;
                                 RGVALUE.IDO_BI                  := g_nSHORIDAY;
                                 RGVALUE.TODOKEDE_BI             := g_nSHORIDAY;
                                 RGVALUE.GEN_JIYU_CD             := 0;
                                 RGVALUE.SYS_TANMATU_BASHO       := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                                 bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                                 RGVALUE := NULL;
                                 g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                 -- ・学齢簿、就学履歴、学年履歴にデータを登録する
                                 -- 就学履歴レコードの取得
                                 BEGIN
                                   SELECT
                                      *
                                      INTO RG2
                                   FROM
                                      (
                                          SELECT
                                              *
                                          FROM
                                              GKBTGAKUREIBO T
                                          WHERE
                                              T.KOJIN_NO = CRJIDO.KOJIN_NO
                                          ORDER BY
                                              T.RIREKI_RENBAN DESC
                                              , T.RIREKI_RENBAN_EDA DESC
                                      )
                                   WHERE ROWNUM = 1;
                                 EXCEPTION
                                     WHEN OTHERS THEN
                                       RAISE;
                                 END;
                                 -- 「DB・ファイル等更新説明書（学齢簿_I）」の③-2.aを参照
                                 RGVALUE := RG2;
                                 RGVALUE.RIREKI_RENBAN         := RG2.RIREKI_RENBAN + 10;
                                 RGVALUE.SAISHIN_KBN           := 0;  --2024/12/27 JIP.Y.SATO ADD
                                 RGVALUE.TYUGAKO_NYUGAKU_BI    := ISEIREKI_CHUNYUBI;
                                 RGVALUE.SYS_SAKUSEIBI         := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                                 RGVALUE.SYS_KOSHINBI          := ISAKUSEIBI;
                                 RGVALUE.SYS_JIKAN             := NSYSTIME;
                                 RGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                 RGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                 RGVALUE.GAKUNEN               := IGAKUNEN;
                                 RGVALUE.SHORIBI               := ISAKUSEIBI;
                                 RGVALUE.GAKKO_KBN_CD          := 2;
                                 RGVALUE.GAKUKYU_CD            := 0;
                                 RGVALUE.JOTAI                 := 2;
                                 RGVALUE.GRB_HENKO_JIYU        := 1;
                                 RGVALUE.GRB_HENKO_TODOKEDE_BI := g_nSHORIDAY;
                                 RGVALUE.GRB_HENKO_BI          := g_nSHORIDAY;
                                 RGVALUE.IDO_BI                := g_nSHORIDAY;
                                 RGVALUE.TODOKEDE_BI           := g_nSHORIDAY;
                                 RGVALUE.SYS_TANMATU_BASHO     := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                                 bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                                 rGVALUE := null;

                                 -- a.RG.小学校卒業年月日　＝　０の場合、
                                 IF RG2.TYUGAKO_CD = 0 THEN
                                   -- 「DB・ファイル等更新説明書（就学履歴_I）」の③-1.aを参照
                                   sGVALUE                       := SG;
                                   sGVALUE.Nendo                 := VNENDO;
                                   sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                   sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                   sGVALUE.Saishin_Flg           := 0;
                                   sGVALUE.S_SOTSUGYO_BI         := ISEIREKI_SHOSOBI; -- 変数.西暦小学校卒業年月日
                                   sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                   sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                   sGVALUE.SYS_JIKAN             := NSYSTIME;
                                   sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                   sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                   bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                   sGVALUE := NULL;
                                 END IF;
                                 g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                 -- 就学履歴レコードの取得
                                 BEGIN
                                   SELECT
                                        *
                                     INTO SG2
                                   FROM
                                       GKBTSHUGAKURIREKI SG2
                                   WHERE
                                        SG2.KOJIN_NO = RG.KOJIN_NO
                                        --2024/12/27 JIP.Y.SATO UPD ST
                                        --AND SG2.NENDO = VNENDO
                                        --AND SG2.KOJIN_RIREKI_RENBAN = (
                                        AND ROWNUM = 1
                                        AND SG2.SHUGAKU_RIREKI_RENBAN = (
                                        --2024/12/27 JIP.Y.SATO UPD ED
                                            SELECT
                                                --2024/12/27 JIP.Y.SATO UPD ST
                                                --MAX(SA.KOJIN_RIREKI_RENBAN)
                                                MAX(SA.SHUGAKU_RIREKI_RENBAN)
                                                --2024/12/27 JIP.Y.SATO UPD ED
                                            FROM
                                                GKBTSHUGAKURIREKI SA
                                            WHERE
                                                SA.KOJIN_NO = RG.KOJIN_NO
--  2024/11/12 ZCZL.WANGYUNING UPDATE START 0.3.000.006:IT_GKB_00491仕様変更対応
                                                --AND SA.NENDO = VNENDO
                                                --AND SA.SAISHIN_FLG = 1)
                                        --AND SG2.SAISHIN_FLG = 1;
                                        --2024/12/27 JIP.Y.SATO UPD ST
                                        --AND SA.NENDO = VNENDO);
                                        );
                                        --2024/12/27 JIP.Y.SATO UPD ED
--  2024/11/12 ZCZL.WANGYUNING UPDATE END
                                 EXCEPTION
                                   WHEN OTHERS THEN
                                     RAISE;
                                 END;
                                 -- 「DB・ファイル等更新説明書（就学履歴_I）」の①.aを参照
                                 SGVALUE2                       := SG2;
                                 SGVALUE2.Nendo                 := VNENDO;
                                 SGVALUE2.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                 SGVALUE2.SHUGAKU_RIREKI_RENBAN := SG2.SHUGAKU_RIREKI_RENBAN + 10;
                                 SGVALUE2.Saishin_Flg           := 0;
                                 IF RG.SYOGAKO_SOTSUGYO_BI = 0 THEN
                                   SGVALUE2.S_SOTSUGYO_BI := ISEIREKI_SHOSOBI;
                                 END IF;
                                 IF RG.TYUGAKO_CD = 0 THEN
                                   SGVALUE2.T_CD := RA.CHUGAKU_CD;
                                 END IF;
                                 SGVALUE2.T_NYUGAKU_BI          := ISEIREKI_CHUNYUBI; -- 変数.西暦中学校入学年月日
                                 SGVALUE2.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                 SGVALUE2.SYS_KOSHINBI          := g_nSHORIDAY;
                                 SGVALUE2.SYS_JIKAN             := NSYSTIME;
                                 SGVALUE2.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                 SGVALUE2.SYS_TANMATU_NO        := g_sWSNUM;
                                 bRTN := FUNC_SHUGAKURIREKI_INSERT(SGVALUE2);
                                 SGVALUE2 := null;
                                 -- 「DB・ファイル等更新説明書（就学履歴_I）」の③-2.aを参照
                                 GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                                 NGSOVALUE := GN;
                                 NGSOVALUE.NENDO                   := VNENDO;
                                 NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                                 NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                                 NGSOVALUE.GAKKO_KBN_CD            := 2;
                                 IF RG.TYUGAKO_CD = 0 THEN
                                   NGSOVALUE.GAKKO_CD := RA.CHUGAKU_CD;
                                 ELSE
                                   NGSOVALUE.GAKKO_CD := RG.TYUGAKO_CD;
                                 END IF;
                                 NGSOVALUE.SAISIN_FLG              := 0;
                                 NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                                 NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                                 NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                                 NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                                 NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                                 NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                                 NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                                 bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                                 NGSOVALUE := NULL;
-- 2024/06/12 ZCZL.Lvjq Update end
-- 2024/06/12 ZCZL.Lvjq Delete start 0.3.000.000:新WizLIFE２次開発
                                 --d-2.学齢簿、就学履歴、学年履歴に児童生徒の他のデータを更新する
--                               ELSE
--                                 UPDATE GKBTGAKUREIBO
--                                     SET SYS_KOSHINBI = ISAKUSEIBI,
--                                         SYS_JIKAN = NSYSTIME,
--                                         SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                         SYS_TANMATU_NO = g_sWSNUM
--                                        ,GAKUNEN = IGAKUNEN
--                                        ,SHORIBI = ISAKUSEIBI
--                                        ,GAKKO_KBN_CD = 2
--                                        ,GAKUKYU_CD = 0
--                                   WHERE KOJIN_NO = RG.KOJIN_NO
--                                     AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
--                                IRTN_KYOUIKU := KKAPK0030.FPRMSHUTOKU('GKB','00SINKYU','0',ACONSPRM_KYOUIKU,NLENGTH);
--                                  IF IRTN_KYOUIKU = 1 THEN
--                                    ACONSPRM_KYOUIKU := A_CONS_PRM();
--                                    ACONSPRM_KYOUIKU.EXTEND;
--                                    ACONSPRM_KYOUIKU.EXTEND;
--                                    ACONSPRM_KYOUIKU(1) := 0;
--                                  ELSE
--                                      WHILE (NLENGTH < 1) LOOP
--                                        ACONSPRM_KYOUIKU.EXTEND;
--                                        ACONSPRM_KYOUIKU(NLENGTH+1) := 0;
--                                        NLENGTH := NLENGTH + 1;
--                                      END LOOP;
--                                  END IF;
--                                    IF ACONSPRM_KYOUIKU(1) = 1 THEN
--                                       BEGIN
--                                         SELECT RIREKI_RENBAN,SYS_SAKUSEIBI,SYS_KOSHINBI,SYS_JIKAN,SYS_SHOKUINKOJIN_NO,SYS_TANMATU_NO
--                                           INTO NRIREKI_RENBAN,NSYS_SAKUSEIBI,NSYS_KOSHINBI,NSYS_JIKAN,NSYS_SHOKUINKOJIN_NO,VSYS_TANMATU_NO
--                                           FROM GKBTNINIBIT
--                                          WHERE KOJIN_NO = RG.KOJIN_NO AND
--                                                RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) REN FROM GKBTNINIBIT WHERE KOJIN_NO = RG.KOJIN_NO);
--                                       EXCEPTION
--                                           WHEN NO_DATA_FOUND THEN
--                                            INSERT INTO GKBTNINIBIT
--                                                  (KOJIN_NO,
--                                                   RIREKI_RENBAN,
--                                                   NINIBIT1,
--                                                   NINIBIT2,
--                                                   NINIBIT3,
--                                                   NINIBIT4,
--                                                   NINIBIT5,
--                                                   NINIBIT6,
--                                                   NINIBIT7,
--                                                   NINIBIT8,
--                                                   NINIBIT9,
--                                                   NINIBIT10,
--                                                   NINIBIT11,
--                                                   NINIBIT12,
--                                                   NINIBIT13,
--                                                   NINIBIT14,
--                                                   NINIBIT15,
--                                                   NINIBIT16,
--                                                   NINIBIT17,
--                                                   NINIBIT18,
--                                                   NINIBIT19,
--                                                   NINIBIT20)
--                                            VALUES(RG.KOJIN_NO,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
--                                       END;
--
--                                           SELECT COUNT(1) INTO NRENBAN_COUNT
--                                             FROM GKBTNINIBIT
--                                            WHERE KOJIN_NO = RG.KOJIN_NO AND RIREKI_RENBAN = NRIREKI_RENBAN-1;
--
--                                       IF NRIREKI_RENBAN IS  NOT NULL AND NRENBAN_COUNT = 0 THEN
--                                             UPDATE GKBTNINIBIT
--                                                SET RIREKI_RENBAN = NRIREKI_RENBAN-1
--                                              WHERE KOJIN_NO = RG.KOJIN_NO AND RIREKI_RENBAN = NRIREKI_RENBAN;
--
--                                        INSERT INTO GKBTNINIBIT(KOJIN_NO,
--                                                    RIREKI_RENBAN,
--                                                    NINIBIT1,
--                                                    NINIBIT2,
--                                                    NINIBIT3,
--                                                    NINIBIT4,
--                                                    NINIBIT5,
--                                                    NINIBIT6,
--                                                    NINIBIT7,
--                                                    NINIBIT8,
--                                                    NINIBIT9,
--                                                    NINIBIT10,
--                                                    NINIBIT11,
--                                                    NINIBIT12,
--                                                    NINIBIT13,
--                                                    NINIBIT14,
--                                                    NINIBIT15,
--                                                    NINIBIT16,
--                                                    NINIBIT17,
--                                                    NINIBIT18,
--                                                    NINIBIT19,
--                                                    NINIBIT20,
--                                                    SYS_SAKUSEIBI,
--                                                    SYS_KOSHINBI,
--                                                    SYS_JIKAN,
--                                                    SYS_SHOKUINKOJIN_NO,
--                                                    SYS_TANMATU_NO)
--                                             VALUES(RG.KOJIN_NO,NRIREKI_RENBAN,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
--                                                  NSYS_SAKUSEIBI,NSYS_KOSHINBI,NSYS_JIKAN,NSYS_SHOKUINKOJIN_NO,VSYS_TANMATU_NO);
--                                       END IF;
-- 2024/06/12 ZCZL.Lvjq Delete end
                                   END IF;

                         ELSE
                               NULL;
                         END IF;
                      ELSE
                            --区域外就学、養護学校児童の場合は学年コードのみ繰り上げる
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00689対応 START
--                            IF (RG.KUIKIGAI_CD <> 0 AND
--                            (RG.KUIKIGAI_CD <> 0
--                            AND (RG.KUIKIGAI_NYUGAKU_BI <> 0 OR RG.KUIKIGAI_TENNYUGAKU_BI <> 0)
--                            AND (RG.KUIKIGAI_TENGAKU_BI = 0 AND RG.KUIKIGAI_SOTSUGYO_BI = 0) AND RG.KUIKIGAI_TAIGAKU_BI = 0
--                           )AND
--
--                                RG.KUIKIGAI_TENGAKU_BI = 0 AND
--                                RG.KUIKIGAI_TAIGAKU_BI = 0 AND
--                                RG.KUIKIGAI_SOTSUGYO_BI = 0) OR
--                               (RG.YOGOGAKO_CD <> 0 AND
--                          (RG.YOGOGAKO_CD <> 0
--                            AND (RG.YOGOGAKO_NYUGAKU_BI <> 0 OR RG.YOGOGAKO_TENNYUGAKU_BI <> 0)
--                            AND (RG.YOGOGAKO_TENGAKU_BI = 0 AND RG.YOGOGAKO_SOTSUGYO_BI = 0)
--                           )AND
--                                RG.YOGOGAKO_TENGAKU_BI = 0 AND
--                                RG.YOGOGAKO_TAIGAKU_BI = 0 AND
-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
--                                 RG.YOGOGAKO_SOTSUGYO_BI = 0) THEN
--                                RG.YOGOGAKO_SOTSUGYO_BI = 0) OR
--                                (RG.KUNISHIRITSU_CD <> 0 AND
--                                (RG.KUNISHIRITSU_CD <> 0 AND (RG.KUNISHIRITSU_NYUGAKU_BI <> 0 OR RG.KUNISHIRITSU_TENNYUGAKU_BI <>0)
--                                 AND (RG.KUNISHIRITSU_TENGAKU_BI = 0 AND RG.KUNISHIRITSU_SOTSUGYO_BI = 0))
--                                 AND RG.KUNISHIRITSU_TENGAKU_BI = 0
--                                 AND RG.KUNISHIRITSU_TAIGAKU_BI = 0
--                                 AND RG.KUNISHIRITSU_SOTSUGYO_BI = 0) THEN
                            IF ( 
                                (
                                    RG.KUIKIGAI_CD <> 0
                                    AND (
                                        RG.KUIKIGAI_NYUGAKU_BI <> 0
                                        OR RG.KUIKIGAI_TENNYUGAKU_BI <> 0
                                    )
                                    AND RG.KUIKIGAI_TENGAKU_BI = 0
                                    AND RG.KUIKIGAI_SOTSUGYO_BI = 0
                                    AND RG.KUIKIGAI_TAIGAKU_BI = 0
                                )
                                OR (
                                    RG.YOGOGAKO_CD <> 0
                                    AND (
                                        RG.YOGOGAKO_NYUGAKU_BI <> 0
                                        OR RG.YOGOGAKO_TENNYUGAKU_BI <> 0
                                    )
                                    AND RG.YOGOGAKO_TENGAKU_BI = 0
                                    AND RG.YOGOGAKO_SOTSUGYO_BI = 0
                                    AND RG.YOGOGAKO_TAIGAKU_BI = 0
                                )
                                OR (
                                    RG.KUNISHIRITSU_CD <> 0
                                    AND (
                                        RG.KUNISHIRITSU_NYUGAKU_BI <> 0
                                        OR RG.KUNISHIRITSU_TENNYUGAKU_BI <> 0
                                    )
                                    AND RG.KUNISHIRITSU_TENGAKU_BI = 0
                                    AND RG.KUNISHIRITSU_SOTSUGYO_BI = 0
                                    AND RG.KUNISHIRITSU_TAIGAKU_BI = 0
                                )
                            ) THEN
--  2024/11/26 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00689対応 END
-- 2024/06/12 ZCZL.Lvjq Update end

                               IGAKUNEN := CRJIDO.GAKUNEN_CD + 1;
                               UPDATE GKBTGAKUNENLNK
                                  SET GAKUNEN_CD = IGAKUNEN,
                                      SYS_KOSHINBI = ISAKUSEIBI,
                                      SYS_JIKAN = NSYSTIME,
                                      SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                      SYS_TANMATU_NO = g_sWSNUM
                               WHERE KOJIN_NO = RG.KOJIN_NO;
                              IF (RG.KUIKIGAI_CD <> 0 AND
                                 (RG.KUIKIGAI_CD <> 0 AND (RG.KUIKIGAI_NYUGAKU_BI <> 0 OR RG.KUIKIGAI_TENNYUGAKU_BI <> 0)
                                   AND (RG.KUIKIGAI_TENGAKU_BI = 0 AND RG.KUIKIGAI_SOTSUGYO_BI = 0) AND RG.KUIKIGAI_TAIGAKU_BI = 0
                                  ) AND RG.KUIKIGAI_TENGAKU_BI = 0 AND RG.KUIKIGAI_TAIGAKU_BI = 0 AND RG.KUIKIGAI_SOTSUGYO_BI = 0) THEN
-- 2024/06/12 ZCZL.Lvjq Delete start 0.3.000.000:新WizLIFE２次開発
--                                  --区域外
--                                   UPDATE GKBTGAKUREIBO
--                                    SET GAKUNEN = IGAKUNEN,
--                                        SHORIBI = ISAKUSEIBI,
--                                        GAKKO_KBN_CD = 4,
--                                        GAKUKYU_CD = 0,
--                                        SYS_KOSHINBI = ISAKUSEIBI,
--                                        SYS_JIKAN = NSYSTIME,
--                                        SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                        SYS_TANMATU_NO = g_sWSNUM
--                                  WHERE KOJIN_NO = RG.KOJIN_NO
--                                    AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
--                             ELSE
--                                  --特別支援
--                                   UPDATE GKBTGAKUREIBO
--                                    SET GAKUNEN = IGAKUNEN,
--                                        SHORIBI = ISAKUSEIBI,
--                                        GAKKO_KBN_CD = 3,
--                                        GAKUKYU_CD = 0,
--                                        SYS_KOSHINBI = ISAKUSEIBI,
--                                        SYS_JIKAN = NSYSTIME,
--                                        SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                        SYS_TANMATU_NO = g_sWSNUM
--                                  WHERE KOJIN_NO = RG.KOJIN_NO
--                                    AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
-- 2024/06/12 ZCZL.Lvjq Delete end
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
                                IF RG.GAKUNEN < 6 THEN
                                   --就学履歴、学年履歴の最新区分を解除する
                                   FUNC_RIREKI_SET(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                   --・学齢簿、就学履歴、学年履歴にデータを登録する
                                   --「DB・ファイル等更新説明書（学齢簿_U）」の④.aを参照
                                   BRTN := FUNC_GAKUREIBO_UPDATE(IGAKUNEN, ISAKUSEIBI, 4, RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                   --「DB・ファイル等更新説明書（就学履歴_I）」の④.a-1を参照
                                   g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                   -- 就学履歴レコードの取得
                                   SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                   sGVALUE                       := SG;
                                   sGVALUE.Nendo                 := VNENDO;
                                   sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                   sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                   sGVALUE.Saishin_Flg           := 0;
                                   sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                   sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                   sGVALUE.SYS_JIKAN             := NSYSTIME;
                                   sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                   sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                   bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                   sGVALUE := null;
                                   -- 「DB・ファイル等更新説明書（学年履歴_I）」の④.aを参照
                                   GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                                   NGSOVALUE                         := GN;
                                   NGSOVALUE.NENDO                   := VNENDO;
                                   NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                                   NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                                   NGSOVALUE.SAISIN_FLG              := 0;
                                   NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                                   NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                                   NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                                   NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                                   NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                                   NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                                   NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                                   bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                                   NGSOVALUE := NULL;
                                ELSIF RG.GAKUNEN = 6 THEN
                                   --・学齢簿、就学履歴、学年履歴の最新区分を解除する
                                   FUNC_UPDDATE(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                   -- 「DB・ファイル等更新説明書（学齢簿_I）」の③-2.c-1を参照

                                   BEGIN
                                     SELECT
                                          *
                                          INTO RG2
                                      FROM
                                          (
                                              SELECT
                                                  *
                                              FROM
                                                  GKBTGAKUREIBO T
                                              WHERE
                                                  t.KOJIN_NO = CRJIDO.KOJIN_NO
                                              ORDER BY
                                                  t.RIREKI_RENBAN DESC
                                                  , t.RIREKI_RENBAN_EDA DESC
                                          )
                                      where
                                          rownum = 1;
                                   EXCEPTION
                                     WHEN OTHERS THEN
                                       RAISE;
                                   END;
                                   RGVALUE := RG2;
                                   RGVALUE.RIREKI_RENBAN         := RG2.RIREKI_RENBAN + 10;
                                   RGVALUE.KUIKIGAI_NYUGAKU_BI   := ISEIREKI_CHUNYUBI; --変数.西暦中学校入学年月日
                                   RGVALUE.SYS_SAKUSEIBI         := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                                   RGVALUE.SYS_KOSHINBI          := ISAKUSEIBI;
                                   RGVALUE.SYS_JIKAN             := NSYSTIME;
                                   RGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                   RGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                   RGVALUE.GAKUNEN               := IGAKUNEN;
                                   RGVALUE.SHORIBI               := ISAKUSEIBI;
                                   RGVALUE.GAKKO_KBN_CD          := 5;
                                   RGVALUE.Saishin_Kbn           := 0;
                                   RGVALUE.GAKUKYU_CD            := 0;
                                   RGVALUE.JOTAI                 := 2;
                                   RGVALUE.GRB_HENKO_JIYU        := 1;
                                   RGVALUE.SYS_TANMATU_BASHO     := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                                   bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                                   RGVALUE := NULL;
                                   g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(rg2.kojin_no);
                                   -- 「DB・ファイル等更新説明書（就学履歴_I）」の④.a-2を参照
                                   SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                   sGVALUE                       := SG;
                                   sGVALUE.Nendo                 := VNENDO;
                                   sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                   sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                   sGVALUE.Saishin_Flg           := 0;
                                   sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                   sGVALUE.KUIKIGAI_T_NYUGAKU_BI := ISEIREKI_CHUNYUBI;
                                   sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                   sGVALUE.SYS_JIKAN             := NSYSTIME;
                                   sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                   sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                   bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                   sGVALUE := null;
                                END IF;
                              --d-2.特別支援と国私立の判定、下記の条件が満たす場合、特別支援と判定され、d-3処理にいく、以外の場合、国私立と判定され、d-4処理へいく
                              ELSIF (RG.YOGOGAKO_CD <> 0 AND (RG.YOGOGAKO_CD <> 0 AND (
                                                        RG.YOGOGAKO_NYUGAKU_BI <> 0 OR RG.YOGOGAKO_TENNYUGAKU_BI <> 0) AND (
                                                        RG.YOGOGAKO_TENGAKU_BI = 0 AND RG.YOGOGAKO_TENNYUGAKU_BI = 0) AND
                                                        RG.YOGOGAKO_TAIGAKU_BI = 0) AND RG.YOGOGAKO_TENGAKU_BI = 0 AND
                                                        RG.YOGOGAKO_TAIGAKU_BI = 0 AND RG.YOGOGAKO_SOTSUGYO_BI = 0) THEN
                                IF RG.GAKUNEN < 6 THEN
                                   --d-3.特別支援と判定され、学齢簿、就学履歴、学年履歴に特別支援の情報を更新する
                                   -- 就学履歴、学年履歴の最新区分を解除する
                                   FUNC_RIREKI_SET(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                   --・学齢簿、就学履歴、学年履歴にデータを登録する
                                   --「DB・ファイル等更新説明書（学齢簿_U）」の④.bを参照
                                   BRTN := FUNC_GAKUREIBO_UPDATE(IGAKUNEN, ISAKUSEIBI, 3, RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                   --「DB・ファイル等更新説明書（就学履歴_I）」の④.bを参照
                                   g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                   --「DB・ファイル等更新説明書（学年履歴_I）」の④.bを参照
                                   -- 就学履歴レコードの取得
                                   SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                   sGVALUE                       := SG;
                                   sGVALUE.Nendo                 := VNENDO;
                                   sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                   sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                   sGVALUE.Saishin_Flg           := 0;
                                   sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                   sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                   sGVALUE.SYS_JIKAN             := NSYSTIME;
                                   sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                   sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                   bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                   sGVALUE := null;
                                   GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                                   NGSOVALUE := GN;
                                   NGSOVALUE.NENDO                   := VNENDO;
                                   NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                                   NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                                   NGSOVALUE.SAISIN_FLG              := 0;
                                   NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                                   NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                                   NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                                   NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                                   NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                                   NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                                   NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                                   bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                                   NGSOVALUE := NULL;
                                ELSIF RG.GAKUNEN = 6 THEN
                                  -- 「DB・ファイル等更新説明書（学齢簿_U）」の「※既存の最新区分を解除する」を参照
                                  UPDATE GKBTGAKUREIBO
                                     SET SAISHIN_KBN = 1,
                                         SYS_KOSHINBI = ISAKUSEIBI,
                                         SYS_JIKAN = NSYSTIME,
                                         SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                         SYS_TANMATU_NO = g_sWSNUM
                                   WHERE KOJIN_NO = RG.KOJIN_NO
                                     AND RIREKI_RENBAN = RG.RIREKI_RENBAN
                                     AND RIREKI_RENBAN_EDA = RG.RIREKI_RENBAN_EDA
                                     AND SAISHIN_KBN = 0;

                                   -- 「DB・ファイル等更新説明書（就学履歴_U）」を参照
                                   UPDATE GKBTSHUGAKURIREKI
                                     SET SAISHIN_FLG = 1,
                                         SYS_KOSHINBI = ISAKUSEIBI,
                                         SYS_JIKAN = NSYSTIME,
                                         SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                         SYS_TANMATU_NO = g_sWSNUM
                                   WHERE KOJIN_NO = RG.KOJIN_NO
                                     AND NENDO = VNENDO
                                     AND KOJIN_RIREKI_RENBAN = RG.RIREKI_RENBAN
                                     AND SAISHIN_FLG = 0;

                                  -- 「DB・ファイル等更新説明書（学齢簿_I）」の③-2.c-2を参照
                                  BEGIN
                                     SELECT
                                          *
                                          INTO RG2
                                      FROM
                                          (
                                              SELECT
                                                  *
                                              FROM
                                                  GKBTGAKUREIBO T
                                              WHERE
                                                  t.KOJIN_NO = CRJIDO.KOJIN_NO
                                              ORDER BY
                                                  t.RIREKI_RENBAN DESC
                                                  , t.RIREKI_RENBAN_EDA DESC
                                          )
                                      WHERE
                                          rownum = 1;
                                   EXCEPTION
                                     WHEN OTHERS THEN
                                       RAISE;
                                   END;
                                   RGVALUE := RG2;
                                   RGVALUE.RIREKI_RENBAN        := RG2.RIREKI_RENBAN + 10;
                                   RGVALUE.KUIKIGAI_NYUGAKU_BI  := ISEIREKI_CHUNYUBI; --変数.西暦中学校入学年月日
                                   RGVALUE.SYS_SAKUSEIBI        := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                                   RGVALUE.SYS_KOSHINBI         := ISAKUSEIBI;
                                   RGVALUE.SYS_JIKAN            := NSYSTIME;
                                   RGVALUE.SYS_SHOKUINKOJIN_NO  := g_sTANTOCODE;
                                   RGVALUE.SYS_TANMATU_NO       := g_sWSNUM;
                                   RGVALUE.GAKUNEN              := IGAKUNEN;
                                   RGVALUE.SHORIBI              := ISAKUSEIBI;
                                   RGVALUE.GAKKO_KBN_CD         := 5;
                                   RGVALUE.GAKUKYU_CD           := 0;
                                   RGVALUE.JOTAI                := 2;
                                   RGVALUE.GRB_HENKO_JIYU       := 1;
                                   RGVALUE.Saishin_Kbn          := 0;
                                   RGVALUE.SYS_TANMATU_BASHO    := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                                   bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                                   RGVALUE := NULL;
                                   -- 「DB・ファイル等更新説明書（就学履歴_I）」の④.b-2を参照
                                   g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                   SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                   sGVALUE                       := SG;
                                   sGVALUE.Nendo                 := VNENDO;
                                   sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                   sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                   sGVALUE.Saishin_Flg           := 0;
                                   SGVALUE.SHIEN_T_NYUGAKU_BI    := ISEIREKI_CHUSOBI;
                                   sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                   sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                   sGVALUE.SYS_JIKAN             := NSYSTIME;
                                   sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                   sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                   bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                   sGVALUE := null;
                                ELSE
                                  NULL;
                                END IF;
                              ELSE
--                                --特別支援
--                                UPDATE GKBTGAKUREIBO
--                                   SET GAKUNEN = IGAKUNEN,
--                                      SHORIBI = ISAKUSEIBI,
--                                       GAKKO_KBN_CD = 3,
--                                       GAKUKYU_CD = 0,
--                                       SYS_KOSHINBI = ISAKUSEIBI,
--                                       SYS_JIKAN = NSYSTIME,
--                                       SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                       SYS_TANMATU_NO = g_sWSNUM
--                                 WHERE KOJIN_NO = RG.KOJIN_NO
--                                   AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
                                --d-4.国私立と判定され、学齢簿、就学履歴、学年履歴に国私立の情報を更新する
                                IF RG.GAKUNEN < 6 THEN
                                   --就学履歴、学年履歴の最新区分を解除する
                                   FUNC_RIREKI_SET(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                   --・学齢簿、就学履歴、学年履歴にデータを登録する
                                   --「DB・ファイル等更新説明書（学齢簿_U）」の④.cを参照
                                   BRTN := FUNC_GAKUREIBO_UPDATE(IGAKUNEN, ISAKUSEIBI, 5, RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                   --「DB・ファイル等更新説明書（就学履歴_I）」の④.cを参照
                                   g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                   --「DB・ファイル等更新説明書（学年履歴_I）」の④.cを参照
                                   -- 就学履歴レコードの取得
                                   SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                   sGVALUE                       := SG;
                                   sGVALUE.Nendo                 := VNENDO;
                                   sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                   sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                   sGVALUE.Saishin_Flg           := 0;
                                   sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                   sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                   sGVALUE.SYS_JIKAN             := NSYSTIME;
                                   sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                   sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                   bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                   sGVALUE := null;
                                   GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                                   NGSOVALUE := GN;
                                   NGSOVALUE.NENDO                   := VNENDO;
                                   NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                                   NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                                   --2024/12/27 JIP.Y.SATO UPD ST
                                   --NGSOVALUE.SAISIN_FLG              := 1;
                                   NGSOVALUE.SAISIN_FLG              := 0;
                                   --2024/12/27 JIP.Y.SATO UPD ED
                                   NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                                   NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                                   NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                                   NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                                   NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                                   NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                                   NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                                   bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                                   NGSOVALUE := NULL;
                                ELSIF RG.GAKUNEN = 6 THEN
                                  --「DB・ファイル等更新説明書（学齢簿_U）」の「※既存の最新区分を解除する」を参照
                                  UPDATE GKBTGAKUREIBO
                                     SET SAISHIN_KBN = 1,
                                         SYS_KOSHINBI = ISAKUSEIBI,
                                         SYS_JIKAN = NSYSTIME,
                                         SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                         SYS_TANMATU_NO = g_sWSNUM
                                   WHERE KOJIN_NO = RG.KOJIN_NO
                                     AND RIREKI_RENBAN = RG.RIREKI_RENBAN
                                     AND RIREKI_RENBAN_EDA = RG.RIREKI_RENBAN_EDA
                                     AND SAISHIN_KBN = 0;

                                   -- 「DB・ファイル等更新説明書（就学履歴_U）」を参照
                                   UPDATE GKBTSHUGAKURIREKI
                                     SET SAISHIN_FLG = 1,
                                         SYS_KOSHINBI = ISAKUSEIBI,
                                         SYS_JIKAN = NSYSTIME,
                                         SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                         SYS_TANMATU_NO = g_sWSNUM
                                   WHERE KOJIN_NO = RG.KOJIN_NO
                                     AND NENDO = VNENDO
                                     AND KOJIN_RIREKI_RENBAN = RG.RIREKI_RENBAN
                                     AND SAISHIN_FLG = 0;

                                  -- 「DB・ファイル等更新説明書（学齢簿_I）」の③-2.c-3を参照
                                  BEGIN
                                     SELECT
                                          *
                                          INTO RG2
                                      FROM
                                          (
                                              SELECT
                                                  *
                                              FROM
                                                  GKBTGAKUREIBO T
                                              WHERE
                                                  t.KOJIN_NO = CRJIDO.KOJIN_NO
                                              ORDER BY
                                                  t.RIREKI_RENBAN DESC
                                                  , t.RIREKI_RENBAN_EDA DESC
                                          )
                                      WHERE
                                          rownum = 1;
                                   EXCEPTION
                                     WHEN OTHERS THEN
                                       RAISE;
                                   END;
                                   RGVALUE := RG2;
                                   RGVALUE.RIREKI_RENBAN       := RG2.RIREKI_RENBAN + 10;
                                   RGVALUE.KUIKIGAI_NYUGAKU_BI := ISEIREKI_CHUNYUBI; --変数.西暦中学校入学年月日
                                   RGVALUE.SYS_SAKUSEIBI       := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                                   RGVALUE.SYS_KOSHINBI        := ISAKUSEIBI;
                                   RGVALUE.SYS_JIKAN           := NSYSTIME;
                                   RGVALUE.SYS_SHOKUINKOJIN_NO := g_sTANTOCODE;
                                   RGVALUE.SYS_TANMATU_NO      := g_sWSNUM;
                                   RGVALUE.GAKUNEN             := IGAKUNEN;
                                   RGVALUE.SHORIBI             := ISAKUSEIBI;
                                   RGVALUE.GAKKO_KBN_CD        := 5;
                                   RGVALUE.GAKUKYU_CD          := 0;
                                   RGVALUE.JOTAI               := 2;
                                   RGVALUE.GRB_HENKO_JIYU      := 1;
                                   RGVALUE.SAISHIN_KBN         := 0;
                                   RGVALUE.SYS_TANMATU_BASHO   := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                                   bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                                   RGVALUE := NULL;
                                   g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                   -- 「DB・ファイル等更新説明書（就学履歴_I）」の④.c-2を参照
                                   SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                   sGVALUE                       := SG;
                                   sGVALUE.Nendo                 := VNENDO;
                                   sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                   sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                   sGVALUE.Saishin_Flg           := 0;
                                   SGVALUE.SHIEN_T_NYUGAKU_BI    := ISEIREKI_CHUSOBI;
                                   sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                   sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                   sGVALUE.SYS_JIKAN             := NSYSTIME;
                                   sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                   sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                   bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                   sGVALUE := null;
                                ELSE
                                  NULL;
                                END IF;
                              END IF;
                            END IF;
                      END IF;
-- 2024/06/12 ZCZL.Lvjq Add end
                   -- CRJIDO.学年コード　は下記の条件が満たす場合、中学校生と判定する
                   ELSIF CRJIDO.GAKUNEN_CD = 7 OR
                         CRJIDO.GAKUNEN_CD = 8 OR
                         CRJIDO.GAKUNEN_CD = 9 THEN
                         --A.RG.中学校コード＜＞０　かつ　下記の条件が満たす場合、下記の①~②.処理へいく、以外の場合、Bの処理へいく
                         IF RG.TYUGAKO_CD <> 0 AND

                            (RG.TYUGAKO_CD <> 0
                        AND (RG.TYUGAKO_NYUGAKU_BI <> 0 OR RG.TYUGAKO_TENNYUGAKU_BI <> 0)
                        AND (RG.TYUGAKO_TENGAKU_BI = 0 AND RG.TYUGAKO_SOTSUGYO_BI = 0))AND
                            RG.TYUGAKO_TENGAKU_BI = 0 AND
                            RG.TYUGAKO_SOTSUGYO_BI = 0 THEN
                            --a. CRJIDO.学年コード　＝　７ または 8の場合、中学校進級者と判定し、下記の（1）~(3)を実行する
                            IF CRJIDO.GAKUNEN_CD = 7 OR
                               CRJIDO.GAKUNEN_CD = 8 THEN
                               -- 中学校進級者
                               IGAKUNEN := CRJIDO.GAKUNEN_CD + 1;
                               UPDATE GKBTGAKUNENLNK
                                  SET GAKUNEN_CD = IGAKUNEN,
                                      SYS_KOSHINBI = ISAKUSEIBI,
                                      SYS_JIKAN = NSYSTIME,
                                      SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                      SYS_TANMATU_NO = g_sWSNUM
                                WHERE KOJIN_NO = RG.KOJIN_NO;
-- 2024/06/12 ZCZL.Lvjq Delete start 0.3.000.000:新WizLIFE２次開発
--                                 UPDATE GKBTGAKUREIBO
--                                   SET GAKUNEN = IGAKUNEN,
--                                       SHORIBI = ISAKUSEIBI,
--                                       GAKKO_KBN_CD = 2,
--                                       GAKUKYU_CD = 0,
--                                       SYS_KOSHINBI = ISAKUSEIBI,
--                                       SYS_JIKAN = NSYSTIME,
--                                       SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                       SYS_TANMATU_NO = g_sWSNUM
--                                 WHERE KOJIN_NO = RG.KOJIN_NO
--                                   AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
-- 2024/06/12 ZCZL.Lvjq Delete end
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
                               -- 就学履歴、学年履歴の最新区分を解除する
                               FUNC_RIREKI_SET(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                               -- 「DB・ファイル等更新説明書（学齢簿_U）」の5を参照
                               BRTN := FUNC_GAKUREIBO_UPDATE(IGAKUNEN, ISAKUSEIBI, 2, RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                               -- 「DB・ファイル等更新説明書（学齢簿_U）」の5を参照
                               g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                               -- 就学履歴レコードの取得
                               SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                               sGVALUE                       := SG;
                               sGVALUE.Nendo                 := VNENDO;
                               sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                               sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                               sGVALUE.Saishin_Flg           := 0;
                               sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                               sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                               sGVALUE.SYS_JIKAN             := NSYSTIME;
                               sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                               sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                               bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                               sGVALUE := NULL;
                               --「DB・ファイル等更新説明書（学年履歴_I）」の5を参照
                               GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                               NGSOVALUE := GN;
                               NGSOVALUE.NENDO                   := VNENDO;
                               NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                               NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                               NGSOVALUE.SAISIN_FLG              := 0;
                               NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                               NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                               NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                               NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                               NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                               NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                               NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                               bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                               NGSOVALUE := NULL;
                            --b.CRJIDO.学年コード = 9の場合、中学校卒業者と判定し、下記のa~bを実行する
-- 2024/06/12 ZCZL.Lvjq Add end
                            ELSIF CRJIDO.GAKUNEN_CD = 9 THEN
                                  -- 中学校卒業者
                                  UPDATE GKBTGAKUNENLNK
                                     SET GAKUNEN_CD = 99,
                                         SYS_KOSHINBI = ISAKUSEIBI,
                                         SYS_JIKAN = NSYSTIME,
                                         SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                         SYS_TANMATU_NO = g_sWSNUM
                                   WHERE KOJIN_NO = RG.KOJIN_NO;
-- 2024/06/12 ZCZL.Lvjq Delete start 0.3.000.000:新WizLIFE２次開発
--                                 UPDATE GKBTGAKUREIBO
--                                       SET TYUGAKO_SOTSUGYO_BI = DECODE(RG.TYUGAKO_SOTSUGYO_BI,0,ISEIREKI_CHUSOBI,RG.TYUGAKO_SOTSUGYO_BI),
--                                           GEN_JIYU_CD = DECODE(RG.GEN_JIYU_CD,0,52,RG.GEN_JIYU_CD),
--                                           GEN_NENGAPI = DECODE(RG.GEN_NENGAPI,0,ISEIREKI_CHUSOBI,RG.GEN_NENGAPI),
--                                           SYS_KOSHINBI = ISAKUSEIBI,
--                                           SYS_JIKAN = NSYSTIME,
--                                           SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                           SYS_TANMATU_NO = g_sWSNUM
--                                          ,GAKUNEN = 99
--                                          ,SHORIBI = ISAKUSEIBI
--                                          ,GAKKO_KBN_CD = 999
--                                          ,GAKUKYU_CD = 0
--
--                                     WHERE KOJIN_NO = RG.KOJIN_NO
--                                       AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
-- 2024/06/12 ZCZL.Lvjq Delete end
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
                               --・学齢簿、就学履歴、学年履歴の最新区分を解除する
                               FUNC_UPDDATE(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                               --「DB・ファイル等更新説明書（学齢簿_I）」の⑥を参照
                               -- 就学履歴レコードの取得
                               rGVALUE                      := RG;
                               rGVALUE.Rireki_Renban        := RG.RIREKI_RENBAN + 10;
                               IF RG.TYUGAKO_SOTSUGYO_BI = 0 THEN
                                 rGVALUE.TYUGAKO_SOTSUGYO_BI:= ISEIREKI_CHUSOBI;
                               END IF;
                               IF RG.GEN_JIYU_CD = 0 THEN
                                 rGVALUE.GEN_JIYU_CD := 52;
                               END IF;
                               IF RG.GEN_NENGAPI = 0 THEN
                                 rGVALUE.GEN_NENGAPI := ISEIREKI_CHUSOBI;
                               END IF;
                               rGVALUE.SYS_SAKUSEIBI        := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                               rGVALUE.SYS_KOSHINBI         := ISAKUSEIBI;
                               rGVALUE.SYS_JIKAN            := NSYSTIME;
                               rGVALUE.SYS_SHOKUINKOJIN_NO  := g_sTANTOCODE;
                               rGVALUE.SYS_TANMATU_NO       := g_sWSNUM;
                               rGVALUE.GRB_HENKO_TODOKEDE_BI:= g_nSHORIDAY;
                               rGVALUE.GRB_HENKO_BI         := g_nSHORIDAY;
                               rGVALUE.GRB_HENKO_JIYU       := 10;
                               rGVALUE.IDO_BI               := g_nSHORIDAY;
                               rGVALUE.TODOKEDE_BI          := g_nSHORIDAY;
                               rGVALUE.GAKUNEN              := 99;
                               rGVALUE.SHORIBI              := ISAKUSEIBI;
                               rGVALUE.GAKKO_KBN_CD         := 2;
                               rGVALUE.GAKUKYU_CD           := 0;
                               rGVALUE.JOTAI                := 4;
                               rGVALUE.SYS_TANMATU_BASHO    := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                               -- DB・ファイル等更新説明書（学齢簿_I）
                               bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                               rGVALUE := NULL;
                               g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                               --「DB・ファイル等更新説明書（就学履歴_I）」の⑥を参照
                               SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                               sGVALUE                       := SG;
                               sGVALUE.Nendo                 := VNENDO;
                               sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                               sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                               sGVALUE.Saishin_Flg           := 0;
                               IF SG.T_SOTSUGYO_BI = 0 THEN
                                 sGVALUE.t_Sotsugyo_Bi   := ISEIREKI_CHUSOBI;-- 変数.西暦中学校卒業年月日
                               END IF;
                               sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                               sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                               sGVALUE.SYS_JIKAN             := NSYSTIME;
                               sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                               sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                               bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                               sGVALUE := null;
-- 2024/06/12 ZCZL.Lvjq Add end
                            ELSE
                                  NULL;
                            END IF;
                         ELSE
                            --区域外就学、養護学校児童の場合は学年コードのみ繰り上げる
                            IF (RG.KUIKIGAI_CD <> 0 AND
                          (RG.KUIKIGAI_CD <> 0
                            AND (RG.KUIKIGAI_NYUGAKU_BI <> 0 OR RG.KUIKIGAI_TENNYUGAKU_BI <> 0)
                            AND (RG.KUIKIGAI_TENGAKU_BI = 0 AND RG.KUIKIGAI_SOTSUGYO_BI = 0) AND RG.KUIKIGAI_TAIGAKU_BI = 0
                          )AND
                                RG.KUIKIGAI_TENGAKU_BI = 0 AND
                                RG.KUIKIGAI_TAIGAKU_BI = 0 AND
                                RG.KUIKIGAI_SOTSUGYO_BI = 0) OR
                               (RG.YOGOGAKO_CD <> 0 AND
                          (RG.YOGOGAKO_CD <> 0
                            AND (RG.YOGOGAKO_NYUGAKU_BI <> 0 OR RG.YOGOGAKO_TENNYUGAKU_BI <> 0)
                            AND (RG.YOGOGAKO_TENGAKU_BI = 0 AND RG.YOGOGAKO_SOTSUGYO_BI = 0)
                          )AND
                                RG.YOGOGAKO_TENGAKU_BI = 0 AND
                                RG.YOGOGAKO_TAIGAKU_BI = 0 AND
-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
--                                 RG.YOGOGAKO_SOTSUGYO_BI = 0) THEN
                                RG.YOGOGAKO_SOTSUGYO_BI = 0) OR
                                (RG.KUNISHIRITSU_CD <> 0 AND
                                (RG.KUNISHIRITSU_CD <> 0 AND (RG.KUNISHIRITSU_NYUGAKU_BI <> 0 OR RG.KUNISHIRITSU_TENNYUGAKU_BI <>0)
                                 AND (RG.KUNISHIRITSU_TENGAKU_BI = 0 AND RG.KUNISHIRITSU_SOTSUGYO_BI = 0))
                                 AND RG.KUNISHIRITSU_TENGAKU_BI = 0
                                 AND RG.KUNISHIRITSU_TAIGAKU_BI = 0
                                 AND RG.KUNISHIRITSU_SOTSUGYO_BI = 0) THEN
-- 2024/06/12 ZCZL.Lvjq Update end
                                IF CRJIDO.GAKUNEN_CD = 7 OR
                                   CRJIDO.GAKUNEN_CD = 8 THEN
                                   -- 中学校進級者
                                   IGAKUNEN := CRJIDO.GAKUNEN_CD + 1;
                                   UPDATE GKBTGAKUNENLNK
                                      SET GAKUNEN_CD = IGAKUNEN,
                                          SYS_KOSHINBI = ISAKUSEIBI,
                                          SYS_JIKAN = NSYSTIME,
                                          SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                          SYS_TANMATU_NO = g_sWSNUM
                                   WHERE KOJIN_NO = RG.KOJIN_NO;
                                   IF (RG.KUIKIGAI_CD <> 0
                                      AND (RG.KUIKIGAI_CD <> 0 AND (RG.KUIKIGAI_NYUGAKU_BI <> 0 OR RG.KUIKIGAI_TENNYUGAKU_BI <> 0)
                                      AND (RG.KUIKIGAI_TENGAKU_BI = 0 AND RG.KUIKIGAI_SOTSUGYO_BI = 0) AND RG.KUIKIGAI_TAIGAKU_BI = 0)
                                      AND RG.KUIKIGAI_TENGAKU_BI = 0 AND RG.KUIKIGAI_TAIGAKU_BI = 0 AND RG.KUIKIGAI_SOTSUGYO_BI = 0) THEN
-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
--                                       --区域外
--                                        UPDATE GKBTGAKUREIBO
--                                            SET GAKUNEN = IGAKUNEN,
--                                                SHORIBI = ISAKUSEIBI,
--                                                GAKKO_KBN_CD = 4,
--                                                GAKUKYU_CD = 0,
--                                                SYS_KOSHINBI = ISAKUSEIBI,
--                                                SYS_JIKAN = NSYSTIME,
--                                                SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                                SYS_TANMATU_NO = g_sWSNUM
--                                          WHERE KOJIN_NO = RG.KOJIN_NO
--                                            AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
--                                   ELSE
--                                       --特別支援
--                                        UPDATE GKBTGAKUREIBO
--                                            SET GAKUNEN = IGAKUNEN,
--                                                SHORIBI = ISAKUSEIBI,
--                                                GAKKO_KBN_CD = 3,
--                                                GAKUKYU_CD = 0,
--                                                SYS_KOSHINBI = ISAKUSEIBI,
--                                                SYS_JIKAN = NSYSTIME,
--                                                SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                                SYS_TANMATU_NO = g_sWSNUM
--                                          WHERE KOJIN_NO = RG.KOJIN_NO
--                                            AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
                                     --・学齢簿、就学履歴、学年履歴の最新区分を解除する
                                     FUNC_RIREKI_SET(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                     --「DB・ファイル等更新説明書（学齢簿_U）」の⑦.aを参照
                                     BRTN := FUNC_GAKUREIBO_UPDATE(IGAKUNEN, ISAKUSEIBI, 4, RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                     --「DB・ファイル等更新説明書（就学履歴_I）」の⑦.aを参照
                                     g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                     -- 就学履歴レコードの取得
                                     SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                     sGVALUE                       := SG;
                                     sGVALUE.Nendo                 := VNENDO;
                                     sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                     sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                     sGVALUE.Saishin_Flg           := 0;
                                     sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                     sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                     sGVALUE.SYS_JIKAN             := NSYSTIME;
                                     sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                     sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                     bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                     sGVALUE := NULL;
                                     --「DB・ファイル等更新説明書（学年履歴_I）」の?を参照
                                     GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                                     NGSOVALUE := GN;
                                     NGSOVALUE.NENDO                   := VNENDO;
                                     NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                                     NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                                     NGSOVALUE.SAISIN_FLG              := 0;
                                     NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                                     NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                                     NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                                     NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                                     NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                                     NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                                     NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                                     bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                                     NGSOVALUE := NULL;
                                   -- (4)特別支援と国私立の判定、下記の条件が満たす場合、特別支援と判定され、下記の（5）処理へいく、以外の場合、国私立と判定され、（6）処理へいく
                                   ELSIF (RG.YOGOGAKO_CD <> 0
                                        AND (RG.YOGOGAKO_CD <> 0 AND (RG.YOGOGAKO_NYUGAKU_BI <> 0 OR RG.YOGOGAKO_TENNYUGAKU_BI <> 0)
                                             AND (RG.YOGOGAKO_TENGAKU_BI = 0 AND RG.YOGOGAKO_TENNYUGAKU_BI = 0)
                                             AND RG.YOGOGAKO_TAIGAKU_BI = 0)
                                        AND RG.YOGOGAKO_TENGAKU_BI = 0
                                        AND RG.YOGOGAKO_TAIGAKU_BI = 0
                                        AND RG.YOGOGAKO_SOTSUGYO_BI = 0)  THEN
                                     --就学履歴、学年履歴の最新区分を解除する
                                     FUNC_RIREKI_SET(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                     --「DB・ファイル等更新説明書（学齢簿_U）」の⑦.bを参照
                                     BRTN := FUNC_GAKUREIBO_UPDATE(IGAKUNEN, ISAKUSEIBI, 3, RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                     --「DB・ファイル等更新説明書（就学履歴_I）」の⑦.bを参照
                                     g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                     SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                     sGVALUE                       := SG;
                                     sGVALUE.Nendo                 := VNENDO;
                                     sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                     sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                     sGVALUE.Saishin_Flg           := 0;
                                     sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                     sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                     sGVALUE.SYS_JIKAN             := NSYSTIME;
                                     sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                     sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                     bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                     sGVALUE := null;
                                     --「DB・ファイル等更新説明書（学年履歴_I）」の⑦.bを参照
                                     GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                                     NGSOVALUE := GN;
                                     NGSOVALUE.NENDO                   := VNENDO;
                                     NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                                     NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                                     NGSOVALUE.SAISIN_FLG              := 0;
                                     NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                                     NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                                     NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                                     NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                                     NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                                     NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                                     NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                                     bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                                     NGSOVALUE := NULL;
-- 2024/06/12 ZCZL.Lvjq Update end
                                   ELSE
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
                                     --・就学履歴、学年履歴の最新区分を解除する
                                     FUNC_RIREKI_SET(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                     --「DB・ファイル等更新説明書（学齢簿_U）」の⑦.cを参照
                                     BRTN := FUNC_GAKUREIBO_UPDATE(IGAKUNEN, ISAKUSEIBI, 5, RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                     --「DB・ファイル等更新説明書（就学履歴_I）」の⑦.cを参照
                                     g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                     SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                     sGVALUE                       := SG;
                                     sGVALUE.Nendo                 := VNENDO;
                                     sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                     sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                     sGVALUE.Saishin_Flg           := 0;
                                     sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                     sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                     sGVALUE.SYS_JIKAN             := NSYSTIME;
                                     sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                     sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                     bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                     sGVALUE := NULL;
                                     --「DB・ファイル等更新説明書（学年履歴_I）」の⑦.cを参照
                                     GN := FUNC_GN_GET(RG.KOJIN_NO, VNENDO);
                                     NGSOVALUE := GN;
                                     NGSOVALUE.NENDO                   := VNENDO;
                                     NGSOVALUE.KOJIN_RIREKI_RENBAN     := g_nGNRIREKIBAN;
                                     NGSOVALUE.GAKUNEN_RIREKI_RENBAN   := GN.GAKUNEN_RIREKI_RENBAN + 10;
                                     NGSOVALUE.SAISIN_FLG              := 0;
                                     NGSOVALUE.GAKUKYU_CD              := 0;  --2024/12/27 JIP.Y.SATO ADD
                                     NGSOVALUE.GAKUNEN                 := IGAKUNEN;
                                     NGSOVALUE.SYS_SAKUSEIBI           := g_nSHORIDAY;
                                     NGSOVALUE.SYS_KOSHINBI            := g_nSHORIDAY;
                                     NGSOVALUE.SYS_JIKAN               := NSYSTIME;
                                     NGSOVALUE.SYS_SHOKUINKOJIN_NO     := g_sTANTOCODE;
                                     NGSOVALUE.SYS_TANMATU_NO          := g_sWSNUM;
                                     bRTN := FUNC_GAKUNENRIREKI_INSERT(NGSOVALUE);
                                     NGSOVALUE := NULL;
-- 2024/06/12 ZCZL.Lvjq Add end
                                   END IF;
                                ELSIF CRJIDO.GAKUNEN_CD = 9 THEN
                                      -- 中学校卒業者
                                      UPDATE GKBTGAKUNENLNK
                                         SET GAKUNEN_CD = 99,
                                             SYS_KOSHINBI = ISAKUSEIBI,
                                             SYS_JIKAN = NSYSTIME,
                                             SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                             SYS_TANMATU_NO = g_sWSNUM
                                       WHERE KOJIN_NO = RG.KOJIN_NO;

                                    IF (RG.KUIKIGAI_CD <> 0 AND
                                       (RG.KUIKIGAI_NYUGAKU_BI <> 0 OR RG.KUIKIGAI_TENNYUGAKU_BI <> 0) AND
                                       (RG.KUIKIGAI_TENGAKU_BI = 0 AND RG.KUIKIGAI_SOTSUGYO_BI = 0 AND RG.KUIKIGAI_TAIGAKU_BI = 0)) THEN
                                        --区域外
-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
--                                        UPDATE GKBTGAKUREIBO
--                                           SET GAKUNEN = 99,
--                                               KUIKIGAI_SOTSUGYO_BI = ISEIREKI_CHUSOBI,
--                                               SHORIBI = ISAKUSEIBI,
--                                               GAKKO_KBN_CD = 999,
--                                               GAKUKYU_CD = 0,
--                                               SYS_KOSHINBI = ISAKUSEIBI,
--                                               SYS_JIKAN = NSYSTIME,
--                                               SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                               SYS_TANMATU_NO = g_sWSNUM
--                                         WHERE KOJIN_NO = RG.KOJIN_NO
--                                         AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
                                         -- ・学齢簿、就学履歴、学年履歴の最新区分を解除する
                                         UPDATE GKBTGAKUREIBO
                                             SET SAISHIN_KBN = 1,
                                                 SYS_KOSHINBI = ISAKUSEIBI,
                                                 SYS_JIKAN = NSYSTIME,
                                                 SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                                 SYS_TANMATU_NO = g_sWSNUM
                                           WHERE KOJIN_NO = RG.KOJIN_NO
                                             AND RIREKI_RENBAN = RG.RIREKI_RENBAN
                                             AND RIREKI_RENBAN_EDA = RG.RIREKI_RENBAN_EDA
                                             AND SAISHIN_KBN = 0;

                                           -- 「DB・ファイル等更新説明書（就学履歴_U）」を参照
                                           UPDATE GKBTSHUGAKURIREKI
                                             SET SAISHIN_FLG = 1,
                                                 SYS_KOSHINBI = ISAKUSEIBI,
                                                 SYS_JIKAN = NSYSTIME,
                                                 SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                                 SYS_TANMATU_NO = g_sWSNUM
                                           WHERE KOJIN_NO = RG.KOJIN_NO
                                             AND NENDO = VNENDO
                                             AND KOJIN_RIREKI_RENBAN = RG.RIREKI_RENBAN_EDA
                                             AND SAISHIN_FLG = 0;

                                           -- 就学履歴レコードの取得
                                           -- 「DB・ファイル等更新説明書（学齢簿_I）」の8.aを参照
                                           rGVALUE                      := RG;
                                           rGVALUE.Rireki_Renban        := RG.RIREKI_RENBAN + 10;
                                           rGVALUE.GAKUNEN              := 99;
                                           rGVALUE.KUIKIGAI_SOTSUGYO_BI := ISEIREKI_CHUSOBI;
                                           rGVALUE.SHORIBI              := ISAKUSEIBI;
                                           rGVALUE.GAKKO_KBN_CD         := 4;
                                           rGVALUE.GAKUKYU_CD           := 0;
                                           rGVALUE.SYS_SAKUSEIBI        := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                                           rGVALUE.SYS_KOSHINBI         := ISAKUSEIBI;
                                           rGVALUE.SYS_JIKAN            := NSYSTIME;
                                           rGVALUE.SYS_SHOKUINKOJIN_NO  := g_sTANTOCODE;
                                           rGVALUE.SYS_TANMATU_NO       := g_sWSNUM;
                                           rGVALUE.GRB_HENKO_TODOKEDE_BI:= g_nSHORIDAY;
                                           rGVALUE.GRB_HENKO_BI         := g_nSHORIDAY;
                                           rGVALUE.GRB_HENKO_JIYU       := 10;
                                           rGVALUE.GEN_JIYU_CD          := 52;
                                           rGVALUE.IDO_BI               := g_nSHORIDAY;
                                           rGVALUE.TODOKEDE_BI          := g_nSHORIDAY;
                                           rGVALUE.JOTAI                := 4;
                                           rGVALUE.SYS_TANMATU_BASHO    := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                                           -- DB・ファイル等更新説明書（学齢簿_I）
                                           bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                                           rGVALUE := NULL;
                                           g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                           --「DB・ファイル等更新説明書（就学履歴_I）」の8.aを参照
                                           SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                           sGVALUE                       := SG;
                                           sGVALUE.Nendo                 := VNENDO;
                                           sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                           sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                           sGVALUE.Saishin_Flg           := 0;
                                           sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                           sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                           sGVALUE.SYS_JIKAN             := NSYSTIME;
                                           sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                           sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                           bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                           sGVALUE := null;
--                                     ELSE
--                                        --特別支援
--                                         UPDATE GKBTGAKUREIBO
--                                            SET GAKUNEN = 99,
--                                                YOGOGAKO_SOTSUGYO_BI = ISEIREKI_CHUSOBI,
--                                                SHORIBI = ISAKUSEIBI,
--                                                GAKKO_KBN_CD = 999,
--                                                GAKUKYU_CD = 0,
--                                                SYS_KOSHINBI = ISAKUSEIBI,
--                                                SYS_JIKAN = NSYSTIME,
--                                                SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
--                                                SYS_TANMATU_NO = g_sWSNUM
--                                          WHERE KOJIN_NO = RG.KOJIN_NO
--                                            AND RIREKI_RENBAN = RG.RIREKI_RENBAN;
                                    ELSIF (RG.YOGOGAKO_CD <> 0 AND (RG.YOGOGAKO_CD <> 0 AND (RG.YOGOGAKO_NYUGAKU_BI <> 0 OR RG.YOGOGAKO_TENNYUGAKU_BI <> 0)
                                           AND (RG.YOGOGAKO_TENGAKU_BI = 0 AND RG.YOGOGAKO_TENNYUGAKU_BI = 0) AND RG.YOGOGAKO_TAIGAKU_BI = 0)
                                           AND RG.YOGOGAKO_TENGAKU_BI = 0
                                           AND RG.YOGOGAKO_TAIGAKU_BI = 0
                                           AND RG.YOGOGAKO_SOTSUGYO_BI = 0) THEN
                                        --・学齢簿、就学履歴、学年履歴の最新区分を解除する
                                        FUNC_UPDDATE(RG.KOJIN_NO, RG.RIREKI_RENBAN, RG.RIREKI_RENBAN_EDA);
                                        -- 就学履歴レコードの取得
                                        -- 「DB・ファイル等更新説明書（学齢簿_I）」の8.bを参照
                                        rGVALUE                      := RG;
                                        rGVALUE.Rireki_Renban        := RG.RIREKI_RENBAN + 10;
                                        rGVALUE.GAKUNEN              := 99;
--  2024/08/12 ZCZL.WANGQIWEI Update 0.3.000.002:検収指摘No.564_2回目の対応
--                                         rGVALUE.KUIKIGAI_SOTSUGYO_BI := ISEIREKI_CHUSOBI;
                                        rGVALUE.YOGOGAKO_SOTSUGYO_BI := ISEIREKI_CHUSOBI;
                                        rGVALUE.SHORIBI              := ISAKUSEIBI;
                                        rGVALUE.GAKKO_KBN_CD         := 3;
                                        rGVALUE.GAKUKYU_CD           := 0;
                                        rGVALUE.SYS_SAKUSEIBI        := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                                        rGVALUE.SYS_KOSHINBI         := ISAKUSEIBI;
                                        rGVALUE.SYS_JIKAN            := NSYSTIME;
                                        rGVALUE.SYS_SHOKUINKOJIN_NO  := g_sTANTOCODE;
                                        rGVALUE.SYS_TANMATU_NO       := g_sWSNUM;
                                        rGVALUE.GRB_HENKO_TODOKEDE_BI:= g_nSHORIDAY;
                                        rGVALUE.GRB_HENKO_BI         := g_nSHORIDAY;
                                        rGVALUE.GRB_HENKO_JIYU       := 10;
                                        rGVALUE.GEN_JIYU_CD          := 52;
                                        rGVALUE.IDO_BI               := g_nSHORIDAY;
                                        rGVALUE.TODOKEDE_BI          := g_nSHORIDAY;
                                        rGVALUE.JOTAI                := 4;
                                        rGVALUE.SYS_TANMATU_BASHO    := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                                        -- DB・ファイル等更新説明書（学齢簿_I）
                                        bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                                        rGVALUE := NULL;
                                        g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                        --「DB・ファイル等更新説明書（就学履歴_I）」の8.bを参照
                                        SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                        sGVALUE                       := SG;
                                        sGVALUE.Nendo                 := VNENDO;
                                        sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                        sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                        sGVALUE.Saishin_Flg           := 0;
                                        sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                        sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                        sGVALUE.SYS_JIKAN             := NSYSTIME;
                                        sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                        sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                        bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                        sGVALUE := null;
                                     ELSE
                                        -- 「DB・ファイル等更新説明書（学齢簿_U）」の「※既存の最新区分を解除する」を参照
                                        UPDATE GKBTGAKUREIBO
                                          SET SAISHIN_KBN = 1,
                                              SYS_KOSHINBI = ISAKUSEIBI,
                                              SYS_JIKAN = NSYSTIME,
                                              SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                              SYS_TANMATU_NO = g_sWSNUM
                                        WHERE KOJIN_NO = RG.KOJIN_NO
                                          AND RIREKI_RENBAN = RG.RIREKI_RENBAN
                                          AND RIREKI_RENBAN_EDA = RG.RIREKI_RENBAN_EDA
                                          AND SAISHIN_KBN = 0;

                                         -- 「DB・ファイル等更新説明書（就学履歴_U）」を参照
                                        UPDATE GKBTSHUGAKURIREKI
                                          SET SAISHIN_FLG = 1,
                                              SYS_KOSHINBI = ISAKUSEIBI,
                                              SYS_JIKAN = NSYSTIME,
                                              SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,
                                              SYS_TANMATU_NO = g_sWSNUM
                                        WHERE KOJIN_NO = RG.KOJIN_NO
                                          AND NENDO = VNENDO
                                          AND KOJIN_RIREKI_RENBAN = RG.RIREKI_RENBAN_EDA
                                          AND SAISHIN_FLG = 0;
                                        -- 「DB・ファイル等更新説明書（学齢簿_I）」の8.cを参照
                                        rGVALUE                      := RG;
                                        rGVALUE.Rireki_Renban        := RG.RIREKI_RENBAN + 10;
                                        rGVALUE.GAKUNEN              := 99;
--  2024/08/12 ZCZL.WANGQIWEI Update 0.3.000.002:検収指摘No.564_2回目の対応
--                                         rGVALUE.KUIKIGAI_SOTSUGYO_BI := ISEIREKI_CHUSOBI;
                                        rGVALUE.KUNISHIRITSU_SOTSUGYO_BI := ISEIREKI_CHUSOBI;
                                        rGVALUE.SHORIBI              := ISAKUSEIBI;
                                        rGVALUE.GAKKO_KBN_CD         := 3;
                                        rGVALUE.GAKUKYU_CD           := 0;
                                        rGVALUE.SYS_SAKUSEIBI        := ISAKUSEIBI;  --2024/12/27 JIP.Y.SATO ADD
                                        rGVALUE.SYS_KOSHINBI         := ISAKUSEIBI;
                                        rGVALUE.SYS_JIKAN            := NSYSTIME;
                                        rGVALUE.SYS_SHOKUINKOJIN_NO  := g_sTANTOCODE;
                                        rGVALUE.SYS_TANMATU_NO       := g_sWSNUM;
                                        rGVALUE.GRB_HENKO_TODOKEDE_BI:= g_nSHORIDAY;
                                        rGVALUE.GRB_HENKO_BI         := g_nSHORIDAY;
                                        rGVALUE.GRB_HENKO_JIYU       := 10;
                                        rGVALUE.GEN_JIYU_CD          := 52;
                                        rGVALUE.IDO_BI               := g_nSHORIDAY;
                                        rGVALUE.TODOKEDE_BI          := g_nSHORIDAY;
                                        rGVALUE.JOTAI                := 5;
                                        rGVALUE.SYS_TANMATU_BASHO    := g_SYS_TANMATU_BASHO;  --2025/01/03 JIP.Y.SATO ADD
                                        -- DB・ファイル等更新説明書（学齢簿_I）
                                        bRTN := FUNC_GAKUREIBO_INSERT(rGVALUE);
                                        rGVALUE := null;
                                        g_nGNRIREKIBAN := FUNC_NEW_RIREKIRENBAN_GET(RG.KOJIN_NO);
                                        --「DB・ファイル等更新説明書（就学履歴_I）」の8.ｃを参照
                                        SG := FUNC_SG_GET(RG.KOJIN_NO, VNENDO);
                                        sGVALUE                       := SG;
                                        g_nGNRIREKIBAN                  := SG.Kojin_Rireki_Renban;
                                        sGVALUE.Nendo                 := VNENDO;
                                        sGVALUE.Kojin_Rireki_Renban   := g_nGNRIREKIBAN;
                                        sGVALUE.SHUGAKU_RIREKI_RENBAN := SG.SHUGAKU_RIREKI_RENBAN + 10;
                                        sGVALUE.Saishin_Flg           := 0;
                                        sGVALUE.SYS_SAKUSEIBI         := g_nSHORIDAY;
                                        sGVALUE.SYS_KOSHINBI          := g_nSHORIDAY;
                                        sGVALUE.SYS_JIKAN             := NSYSTIME;
                                        sGVALUE.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
                                        sGVALUE.SYS_TANMATU_NO        := g_sWSNUM;
                                        bRTN := FUNC_SHUGAKURIREKI_INSERT(sGVALUE);
                                        sGVALUE := null;
-- 2024/06/12 ZCZL.Lvjq Update end
                                    END IF;

                                ELSE
                                      NULL;
                                END IF;
                            END IF;
                         END IF;
                   END IF;
                ELSE
                      NULL;
                END IF;
-- 2024/06/12 ZCZL.Lvjq Add 0.3.000.000:新WizLIFE２次開発
            --グローバル変数.進級・卒業処理対象件数のカウントアップを行う。
            g_nSHINKYUSOTUGYOU_KENSU := g_nSHINKYUSOTUGYOU_KENSU + 1;
            END LOOP;
                SELECT COUNT(GYOMU_SUBCD)
                  INTO  IJIDOCNT
                  FROM GKBTKOSHINLOG
                 WHERE GYOMU_SUBCD = 0
                   AND GROUPKEY = 1
                   AND RENBAN = 2
                   AND SHORI_RENBAN = 1
                   AND NENDO = VNENDO_GYY;
                IF IJIDOCNT = 0 THEN
                  INSERT INTO GKBTKOSHINLOG   --存在しない場合を追加
                           (GYOMU_SUBCD,
                            GROUPKEY,
                            RENBAN,
                            SHORI_RENBAN,
                            NENDO,
                            SHORIID,
                            SHORINAME,
                            JOKEN1,
                            JOKEN2,
                            JOKEN3,
                            JOKEN4,
                            JOKEN5)
                    VALUES( 0,
                            1,
                            2,
                            1,
                            VNENDO_GYY,
                            g_sSHORIID,
                            '進級卒業処理更新時間',
                            ISAKUSEIBI ,
                            NSYSTIME,
                            0,
                            0,
                            0);
                ELSIF IJIDOCNT >0 THEN
                  UPDATE GKBTKOSHINLOG  --存在すればを更新
                      SET JOKEN1 = ISAKUSEIBI,
                          JOKEN2 = NSYSTIME
                    WHERE GYOMU_SUBCD = 0
                          AND GROUPKEY = 1
                          AND RENBAN = 2
                          AND SHORI_RENBAN = 1
                          AND NENDO = VNENDO_GYY;
                END IF;
            -- コミット（確定）
            COMMIT;
-- 2024/06/12 ZCZL.Lvjq Add 0.3.000.000:新WizLIFE２次開発
            IFRET := GKBFKHTCLR(2, '999999999999');
      EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;       -- 処理前に戻す
-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
                IFRET := GKBFKHTCLR(2, '999999999999');
--                 IFRET := c_INOT_SUCCESS;      -- 異常終了
-- 2024/06/12 ZCZL.Lvjq Update end
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                RAISE ERR;
        END;
        -- 終了
    RETURN IFRET;
    EXCEPTION
        /* その他エラー */
        WHEN OTHERS THEN
-- 2024/06/12 ZCZL.Lvjq Update start 0.3.000.000:新WizLIFE２次開発
--             IFRET := c_INOT_SUCCESS;      -- 異常終了
            IFRET := GKBFKHTCLR(2, '999999999999');
-- 2024/06/12 ZCZL.Lvjq Update end
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            RAISE ERR;
        RETURN IFRET;
    END FUNC_IKATU_UPD;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
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
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------
    --  機能概要      : ＣＳＶファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq   2024/06/26
    --------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE RETURN BOOLEAN
    IS
        VSQL               NVARCHAR2(3000);
        bRTN               BOOLEAN;                         --戻り値
--  2024/09/09 ZCZL.LIUCHANGQUAN DEL 0.3.000.004:8月1日認識合わせの横展開
--        nCNT               NUMBER;                          --CSV出力件数
        TYPE               ref_CUR_DOUTAI IS REF CURSOR;    --カーソル定義
        C1                 ref_CUR_DOUTAI;                  --動態カーソル
        TYPE CRATENA_TYPE2 IS RECORD
            (KOJIN_NO      GKBWTAISHOGAI.KOJIN_NO%TYPE,
             SHIMEI_KANA   GKBWTAISHOGAI.SHIMEI_KANA%TYPE,
             SHIMEI_KANJI  GKBWTAISHOGAI.SHIMEI_KANJI%TYPE,
             GAKKO_CD      GKBWTAISHOGAI.GAKKO_CD%TYPE,
             GAKKO_MEI     GKBWTAISHOGAI.GAKKO_MEI%TYPE,
             GAKUNEN       GKBWTAISHOGAI.GAKUNEN%TYPE,
             RIYU          GKBWTAISHOGAI.RIYU%TYPE);
        CR1                CRATENA_TYPE2;
        TEXTDATA           NVARCHAR2(3000);                 -- テキストデータ
        nGYOMU_CD          NVARCHAR2(10);                   --業務コード
        nGROUP_CD          NVARCHAR2(10);                   --グループコード
        nSHORIMEI          NVARCHAR2(10);                   --処理名
        IRTN               BOOLEAN;
        iRIREKI            NUMBER;
        nRTN               NUMBER;                          --戻り値
        io_nRIREKISEQ      NUMBER := 0;
    BEGIN
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        -- 1-1.グローバル変数.バッチジョブステップ情報.帳票IDが「進級・卒業対象外児童生徒一覧」 の場合
--  2024/09/09 ZCZL.LIUCHANGQUAN DEL START 0.3.000.004:8月1日認識合わせの横展開
--        IF g_rJSTP.CHOHYOID = 'GKB001R001' THEN
           -- [DB・ファイル等更新説明書（ワークテーブル初期化_D）]シート参照
--           DELETE FROM GKBWDC001001
--           WHERE RECUPDKBNCODE = g_sTANTOCODE
--           AND RECUPDWSNUM = g_sWSNUM;
--  2024/09/09 ZCZL.LIUCHANGQUAN DEL END
           -- 1-1.件数表の抽出条件を指定する。
           nCNT := 0;
           --SQL文
           VSQL := '';
-- 2024/09/03 ZCZL.YANGSHUAI Update START 0.3.000.003:IT_GKB_00075対応
--           VSQL := 'SYS_TANMATU_NO = ' || g_sTANTOCODE ;
           VSQL := 'SYS_SHOKUINKOJIN_NO = ' || '''' || g_sTANTOCODE || '''' ;
           VSQL := VSQL || ' AND SYS_TANMATU_NO = ' || '''' || g_sWSNUM || '''' ;
-- 2024/09/03 ZCZL.YANGSHUAI Update END
           -- 1-2.共通関数（件数カウント計算）(GKBFTCOUNT)を呼び出し、グローバル変数.件数にセットする。
           nCNT := GKBFKTBLCNT('GKBWTAISHOGAI' , VSQL);

           -- 2-1.共通関数「ワークテーブルオープン（KKAPK0090.FDLWorkOpen」を呼び出して、ワークテーブルをオープンする。
           nRTN := KKAPK0090.FDLWorkOpen ('GKBWDC001001',
                                         io_nRIREKISEQ,
                                         1,
                                         '進級・卒業対象外児童生徒一覧',
                                         'GKBF_SHIN_SOTSU_TAISHOGAI.csv',
                                         '',
                                         g_sTANTOCODE,
                                         g_sWSNUM,
                                         '');
--  2024/10/30 ZCZL.WANGYUNING ADD 0.3.000.005:IT_GKB_00213仕様変更対応
           TEXTDATA := '';    
           TEXTDATA := '児童生徒宛名番号';        
           TEXTDATA := TEXTDATA ||','|| '児童生徒氏名カナ';        
           TEXTDATA := TEXTDATA ||','|| '児童生徒氏名';        
           TEXTDATA := TEXTDATA ||','|| '学校コード';       
           TEXTDATA := TEXTDATA ||','|| '学校名';       
           TEXTDATA := TEXTDATA ||','|| '学年';        
           TEXTDATA := TEXTDATA ||','|| '進級・卒業できなかった理由';       
           
           IF KKAPK0090.FDLWorkPutNC (TEXTDATA, 'UTF8', 1) <> 0 THEN
               RETURN FALSE;
           END IF;
--  2024/10/30 ZCZL.WANGYUNING ADD END                            
           --CSVファイル作成処理
           VSQL := '';
           VSQL := 'SELECT KOJIN_NO ';
           VSQL := VSQL || ',SHIMEI_KANA ';
           VSQL := VSQL || ',SHIMEI_KANJI ';
           VSQL := VSQL || ',GAKKO_CD ';
           VSQL := VSQL || ',GAKKO_MEI ';
           VSQL := VSQL || ',GAKUNEN ';
           VSQL := VSQL || ',RIYU ';
           VSQL := VSQL || 'FROM GKBWTAISHOGAI ';
--  2024/11/21 JPJYS.LIUHUAIQI ADD 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 Start
           VSQL := VSQL || 'WHERE SYS_SHOKUINKOJIN_NO = ' || '''' || g_sTANTOCODE || '''' ;
           VSQL := VSQL || 'AND SYS_TANMATU_NO = ' || '''' || g_sWSNUM || '''' ;
--  2024/11/21 JPJYS.LIUHUAIQI ADD 0.3.000.007:IT_GKB_00654,IT_GKB_00655対応 End
           OPEN C1 FOR VSQL;
           LOOP
             FETCH C1 INTO CR1;
             EXIT WHEN C1%NOTFOUND;
             TEXTDATA := '';
             TEXTDATA := TEXTDATA || CR1.KOJIN_NO;                 --児童生徒宛名番号
             TEXTDATA := TEXTDATA ||','|| CR1.SHIMEI_KANA;         --児童生徒氏名カナ
             TEXTDATA := TEXTDATA ||','|| CR1.SHIMEI_KANJI;        --児童生徒氏名
             TEXTDATA := TEXTDATA ||','|| CR1.GAKKO_CD;            --学校コード
             TEXTDATA := TEXTDATA ||','|| CR1.GAKKO_MEI;           --学校名
             TEXTDATA := TEXTDATA ||','|| CR1.GAKUNEN;             --学年
             TEXTDATA := TEXTDATA ||','|| CR1.RIYU;                --進級・卒業できなかった理由
             g_nCSVCNT := g_nCSVCNT + 1;
            --ワークテーブルテキスト出力
--  2024/08/08 ZCZL.WANGQIWEI Update 0.3.000.001:検収指摘No.564の対応
--            IF KKAPK0090.FDLWorkPutNC (TEXTDATA, 'JA16SJIS', 1) <> 0 THEN
            IF KKAPK0090.FDLWorkPutNC (TEXTDATA, 'UTF8', 1) <> 0 THEN
                RETURN FALSE;
            END IF;
           END LOOP;
           CLOSE C1;
           --ファイルをクローズする。
           nRTN := KKAPK0090.FDLWorkClose(g_nCSVCNT);
           IF nRTN <> 0 THEN
             RETURN FALSE;
           END IF;
           --ダウンロード設定用情報の取得を行う。
           IRTN := KKBPK5551.FKKBVJCTLGET(g_nJOBNUM,g_sGYOUMUCODE,nGROUP_CD,nSHORIMEI);
           IF IRTN THEN
               IF KKAPK0090.FDLCtlPut (g_sGYOUMUCODE, nGROUP_CD, nSHORIMEI, g_nJOBNUM) <> 0 THEN
                   RETURN FALSE;
               END IF;
           END IF;
--  2024/09/09 ZCZL.LIUCHANGQUAN DEL 0.3.000.004:8月1日認識合わせの横展開
--        END IF;

        --関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);
        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            IF C1%ISOPEN THEN
              CLOSE C1;
            END IF;
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ＣＳＶファイル作成処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE;
    END FUNC_CSV_CREATE;
-- 2024/06/12 ZCZL.Lvjq Add end
    --------------------------------------------------------
    --  機能概要      : 更新処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;    --戻り値
        ERR                           EXCEPTION;
    BEGIN
        g_nUPDLOGSEQ := g_nUPDLOGSEQ + 1;
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 2);
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
        -- 初期処理
        bRTN := FUNC_INIT;
        IF NOT bRTN THEN
          RAISE ERR;
        END IF;
-- 2024/06/12 ZCZL.Lvjq Add end
        -- 取得した条件をそれぞれの変数へセット
        VSHONYUBI := g_vJYOUKEN1;        -- 小学校入学年月日
        VSHOSOBI := g_vJYOUKEN2;        -- 小学校卒業年月日
        VCHUNYUBI := g_vJYOUKEN3;        -- 中学校入学年月日
        VCHUSOBI := g_vJYOUKEN4;        -- 中学校卒業年月日
        VNENDO := SUBSTR(VSHONYUBI,1,3);
        VNENDO_GYY := VNENDO;
        VNENDO := KKAPK0020.FNENDO(VNENDO,1);
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
        g_nSUGYOFLG := g_vJYOUKEN5;        -- 進級卒業可能
        g_nSHORIDAY := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
        DELETE FROM GKBWTAISHOGAI
        WHERE SYS_SHOKUINKOJIN_NO = g_sTANTOCODE
        AND SYS_TANMATU_NO = g_sWSNUM;
-- 2024/06/12 ZCZL.Lvjq Add end
        -- 一括更新処理
        I_RTN := FUNC_IKATU_UPD;
        IF I_RTN = c_INOT_SUCCESS THEN
            RAISE ERR;
        END IF;

-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
        bRTN := FUNC_CSV_CREATE;
        IF NOT bRTN THEN
            RAISE ERR;
        END IF;
-- 2024/06/12 ZCZL.Lvjq Add end

        -- 関数終了
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 2);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
            RETURN FALSE;
    END FUNC_B20UPDATE1;
    --------------------------------------------------------
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.004:8月1日認識合わせの横展開
-- 2024/06/12 ZCZL.Lvjq Add start 0.3.000.000:新WizLIFE２次開発
--     g_oKENSU_LIST.EXTEND(2);
--     g_oKENSU_LIST(1) := GKBEKENSU_RECORD(g_nCSVCNT, '処理　進級・卒業処理対象件数', 0);
--     g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nSHINKYUSOTUGYOU_KENSU, '出力 進級・卒業処理対象外件数', 2);
-- 2024/06/12 ZCZL.Lvjq Add end
       g_oKENSU_LIST.EXTEND(2);
       g_oKENSU_LIST(1) := GKBEKENSU_RECORD(nCNT, '処理　進級・卒業処理対象件数', 0);
       g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nCSVCNT, '出力 進級・卒業処理対象外件数', 2);
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE END
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
    --  作成者／作成日: ZCZL.LUANSONGLIN   2024/01/29
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
END GKBPC00100;
/
