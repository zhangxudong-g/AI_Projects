CREATE OR REPLACE PACKAGE BODY GKBPB00410
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 教育児童生徒集計
--  機能概要      : 転入・転出等児童生徒一覧表を作成する
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
--------------------------------------------------------
--  変更履歴
--  2024/06/04 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00100の対応
--  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.005:IT_GKB_00619対応
--  2024/11/25 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_00684の対応
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応
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
--  2024/09/03 ZCZL.WANGMING ADD 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00100の対応
    g_nINDEX                      NUMBER         := 0;

    --パラメータ変数
    
------------------------------------------------------------------------------
--  カーソル定義
------------------------------------------------------------------------------
  TYPE CRATENA_TYPE IS RECORD
  (
    KOJIN_NO             GKBTGAKUREIBO.KOJIN_NO%TYPE,
    RIREKI_RENBAN        GKBTGAKUREIBO.RIREKI_RENBAN%TYPE
--  2024/06/04 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
    ,RIREKI_RENBAN_EDA    GKBTGAKUREIBO.RIREKI_RENBAN_EDA%TYPE
  );
 CRATENA_WORK CRATENA_TYPE;
------------------------------------------------------------------------------
--  カーソル定義
------------------------------------------------------------------------------
  TYPE CRATENA_TYPE2 IS RECORD
  (
    GAKO_CD                 GKBWTENNYUSHUTSU.GAKO_CD%TYPE,
    GAKO_KBN                GKBWTENNYUSHUTSU.GAKO_KBN%TYPE, --最後の位置から異動
    GAKOMEI                 GKBWTENNYUSHUTSU.GAKOMEI%TYPE,
    GAKUNEN1_TENNYU_CNT     NUMBER,
    GAKUNEN2_TENNYU_CNT     NUMBER,
    GAKUNEN3_TENNYU_CNT     NUMBER,
    GAKUNEN4_TENNYU_CNT     NUMBER,
    GAKUNEN5_TENNYU_CNT     NUMBER,
    GAKUNEN6_TENNYU_CNT     NUMBER,
    ALL_TENNYU_CNT          NUMBER,
    GAKUNEN1_TENGAKU_CNT    NUMBER,
    GAKUNEN2_TENGAKU_CNT    NUMBER,
    GAKUNEN3_TENGAKU_CNT    NUMBER,
    GAKUNEN4_TENGAKU_CNT    NUMBER,
    GAKUNEN5_TENGAKU_CNT    NUMBER,
    GAKUNEN6_TENGAKU_CNT    NUMBER,
    ALL_TENGAKU_CNT         NUMBER,
    GAKUNEN1_TAIGAKU_CNT    NUMBER,
    GAKUNEN2_TAIGAKU_CNT    NUMBER,
    GAKUNEN3_TAIGAKU_CNT    NUMBER,
    GAKUNEN4_TAIGAKU_CNT    NUMBER,
    GAKUNEN5_TAIGAKU_CNT    NUMBER,
    GAKUNEN6_TAIGAKU_CNT    NUMBER,
    ALL_TAIGAKU_CNT         NUMBER,
    GAKUNEN1_GETUMATU_CNT   NUMBER,
    GAKUNEN2_GETUMATU_CNT   NUMBER,
    GAKUNEN3_GETUMATU_CNT   NUMBER,
    GAKUNEN4_GETUMATU_CNT   NUMBER,
    GAKUNEN5_GETUMATU_CNT   NUMBER,
    GAKUNEN6_GETUMATU_CNT   NUMBER,
    ALL_GETUMATU_CNT        NUMBER,
    IDO_KBN                 GKBWTENNYUSHUTSU.IDO_KBN%TYPE,
    GAKUNEN                 GKBWTENNYUSHUTSU.GAKUNEN%TYPE,
    SHIMEI_KANJI            GKBWTENNYUSHUTSU.SHIMEI_KANJI%TYPE,
    SHIMEI_KANA             GKBWTENNYUSHUTSU.SHIMEI_KANA%TYPE,
    IDOBI                   GKBWTENNYUSHUTSU.IDOBI%TYPE,
    JINKAKU_KBN             GKBWTENNYUSHUTSU.JINKAKU_KBN%TYPE
  );
    CRATENA_WORK2 CRATENA_TYPE2;
------------------------------------------------------------------------------
--  定数宣言
------------------------------------------------------------------------------
    -- ERROR関連
    c_BERROR        CONSTANT  BOOLEAN :=  FALSE;
    -- 処理結果
    c_ISUCCESS      CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS  CONSTANT  PLS_INTEGER := -1;        -- 異常
    c_INOT_SUCCESS2 CONSTANT  PLS_INTEGER := 1;         -- 異常
    c_INOT_SUCCESS3 CONSTANT  PLS_INTEGER := -2;        -- 異常
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
    --中間ファイル
    c_VGTABLE      CONSTANT  NVARCHAR2(100) := 'GKBWTENNYUSHUTSU';
------------------------------------------------------------------------------
--  変数宣言
------------------------------------------------------------------------------
    ISAKUSEIBI      PLS_INTEGER;
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    B_RTN           BOOLEAN;
    I_RTN           PLS_INTEGER;
    V_JYOUKEN01    NVARCHAR2(400);
--  --2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
    --V_JYOUKEN02    NVARCHAR2(400);
    --V_JYOUKEN03    NVARCHAR2(400);
    --V_JYOUKEN04    NVARCHAR2(400);
    --V_JYOUKEN05    NVARCHAR2(400);
--  2024/06/04 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
    --g_vJYOUKEN06    NVARCHAR2(400);
    V_JYOUKEN02    NVARCHAR2(3000);
    V_JYOUKEN03    NVARCHAR2(3000);
    V_JYOUKEN04    NVARCHAR2(3000);
    V_JYOUKEN05    NVARCHAR2(3000);
    g_vJYOUKEN06    NVARCHAR2(3000);
--  2024/10/30 ZCZL.WANGYUNING UPDATE END
    -- 処理条件（画面からの引数）
    VNENDO          NVARCHAR2(100);      -- 抽出年月
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
    --VSYOGAKO_CD     NVARCHAR2(100);      -- 小学校コード
    --VTYUGAKO_CD     NVARCHAR2(100);      -- 中学校コード
    --VKUIKIGAI_CD    NVARCHAR2(100);      -- 区域外学校コード
    --VYOGOGAKO_CD    NVARCHAR2(100);      -- 盲聾養護学校コード
--  2024/06/04 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
    --g_vKUNISHIRITSU_CD NVARCHAR2(100);   --  国・私立学校コード
    VSYOGAKO_CD     NVARCHAR2(3000);      -- 小学校コード
    VTYUGAKO_CD     NVARCHAR2(3000);      -- 中学校コード
    VKUIKIGAI_CD    NVARCHAR2(3000);      -- 区域外学校コード
    VYOGOGAKO_CD    NVARCHAR2(3000);      -- 盲聾養護学校コード
    --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
    --g_vKUNISHIRITSU_CD NVARCHAR2(3000);   --  国・私立学校コード
    VKUNISHIRITSU_CD NVARCHAR2(3000);   --  国・私立学校コード
	--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 END
--  2024/10/30 ZCZL.WANGYUNING UPDATE END
    VSQLERRM        NVARCHAR2(256);      -- 外部関数から返ってくるエラーメッセージ
    RG              GKBTGAKUREIBO%ROWTYPE;
    RB              GABTATENAKIHON%ROWTYPE;
    RC              GABTSOFUSAKI%ROWTYPE;
    RG2             GKBTGAKUREIBO%ROWTYPE;   --最新取得用
    GAKO_KBN        NUMBER(1);               --学校区分
    GAKO_CD         NUMBER(10);              --学校コード
    IDO_KBN         NUMBER(1);               --異動区分
    GAKUNEN         NUMBER(2);               --学年
    GAKOMEI         NVARCHAR2(60);           --学校名
    SHIMEI_KANA     NVARCHAR2(100);          --氏名かな
    SHIMEI_KANJI    NVARCHAR2(100);          --氏名漢字
    IDOBI           NUMBER(8);               --異動日
    BPRMFLG_001     BOOLEAN;
    BPRMFLG_002     BOOLEAN;
    BPRMFLG_003     BOOLEAN;
    BPRMFLG_004     BOOLEAN;
    N_NAIYO_CD      GKBTSHIMEIJKN.NAIYO_CD%TYPE;
    o_SHIMEIPRM     A_CONS_PRM;   --宛先の氏名出力制御
    o_LENGTH        NUMBER;
    JINKAKU_KBN     NUMBER(1,0);
--  2024/06/04 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
    g_aSHIMEIJKN_CHOHYOPRM            A_CONS_PRM;
    g_aSHIMEIPRM                      A_CONS_PRM;
    g_nGKB360_INDEX                   NUMBER;          --転入・転出等児童生徒一覧表_インデックス番号
    g_vGKB360_CTL                     NVARCHAR2(1000); --転入・転出等児童生徒一覧表_出力制御 
--  2024/06/04 ZCZL.ZHANGLEI ADD END
--  2024/07/26 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
    g_nCNT                                 NUMBER;                         --グローバル変数.件数
    g_nCSVCNT                              NUMBER;                         --グローバル変数.CSV出力件数
--  2024/09/03 ZCZL.WANGMING ADD START 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00100の対応
    KENSUU_COUNT                    NUMBER;                                --変数.件数カウント
    NCSVSHUTURYOKU_COUNT            NUMBER;                                --変数.CSV出力件数
--  2024/09/03 ZCZL.WANGMING ADD END
--  2024/07/26 ZCZL.ZHANGLEI ADD END
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
--  2024/10/30 ZCZL.WANGYUNING ADD 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
        objShogakkoCd          DBMS_UTILITY.MAXNAME_ARRAY;
        objChugakkoCd          DBMS_UTILITY.MAXNAME_ARRAY;
        objKuikigaiGakkoCd     DBMS_UTILITY.MAXNAME_ARRAY;
        objTokubetsuShienGakkoCd DBMS_UTILITY.MAXNAME_ARRAY;
        objKuniShiritsuGakkoCd DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/10/30 ZCZL.WANGYUNING ADD END
    BEGIN
        V_JYOUKEN01 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNengetsu');               --抽出年月
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
        --V_JYOUKEN02 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShogakkoCd');             --小学校コード
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtShogakkoCd');
        V_JYOUKEN02 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShogakkoCd',0, objShogakkoCd);
        --V_JYOUKEN03 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtChugakkoCd');             --中学校コード
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtChugakkoCd');
        V_JYOUKEN03 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtChugakkoCd',0, objChugakkoCd);
        --V_JYOUKEN04 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKuikigaiGakkoCd');        --区域外学校コード
        objKuikigaiGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKuikigaiGakkoCd');
        V_JYOUKEN04 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuikigaiGakkoCd',0, objKuikigaiGakkoCd);
        --V_JYOUKEN05 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtTokubetsuShienGakkoCd');  --特別支援学校コード
        objTokubetsuShienGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtTokubetsuShienGakkoCd');
        V_JYOUKEN05 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtTokubetsuShienGakkoCd',0, objTokubetsuShienGakkoCd);
--  2024/06/04 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
        --g_vJYOUKEN06 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKuniShiritsuGakkoCd');   -- 国・私立学校コード
        objKuniShiritsuGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKuniShiritsuGakkoCd');
        g_vJYOUKEN06 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuniShiritsuGakkoCd',0, objKuniShiritsuGakkoCd);
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
        --  2024/10/18 ZCZL.ZHANGLEI ADD START 0.3.000.002:IT_GKB_00079仕様変更対応
        vMSG                          NVARCHAR2(4000);
        iRTN                          PLS_INTEGER;
        vERRTMPMSG                    NVARCHAR2(1000);
        sWAREKINENDO                  NUMBER;
        --  2024/10/18 ZCZL.ZHANGLEI ADD END
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
        --  2024/10/18 ZCZL.ZHANGLEI ADD START 0.3.000.002:IT_GKB_00079仕様変更対応
        vMSG := '';
        iRTN := 0;
        vERRTMPMSG := '';
        bRTN := KKAPK0010.FISNUMERIC(V_JYOUKEN01);
        IF bRTN THEN
          --処理条件.基準日の日付の妥当性をチェック
          bRTN := KKAPK0020.FISDATEW(TO_NUMBER(V_JYOUKEN01 || '01'));
          IF NOT bRTN THEN
            vERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出年月が正しくありません。,;';
            vMSG := vMSG || vERRTMPMSG;
          END IF;
        ELSE
          vERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出年月が正しくありません。,;';
          vMSG := vMSG || vERRTMPMSG;
        END IF;
        o_vRESULT := vMSG;
        --  2024/10/18 ZCZL.ZHANGLEI ADD END
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
--  2024/10/30 ZCZL.WANGYUNING ADD 0.3.000.005:学校コードリスト仕様変更IT_GKB_00090の対応
    --------------------------------------------------------
    --  機能概要      : 学校コード取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/10/30
    --------------------------------------------------------
    FUNCTION FUNC_GET_GAKOCD(i_sGAKOCD IN NVARCHAR2, o_sGAKOCD OUT NVARCHAR2) RETURN BOOLEAN
    IS
        aGAKOCD           KKBPK5551.tySPLIT_tbl;      -- 学校コード（リスト）
        nGAKOUCD_TMP  NUMBER; --学校コード
    BEGIN
        -- 入力引数を分解して配列にセットする
        -- 引数の学校コード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
        -- 処理ステップを取得
        o_sGAKOCD := '';
        FOR i IN 1..aGAKOCD.COUNT LOOP
        --  2024/11/25 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_00684の対応 Start
            --nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 1, 3));
        --  2024/11/25 JPJYS.SONGSHIHAO UPDATE 0.3.000.006:IT_GKB_00684の対応 End
            IF nGAKOUCD_TMP IS NOT NULL THEN
                IF i = aGAKOCD.COUNT THEN
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP ;
                ELSE
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP || ',';
                END IF;
            END IF;
        END LOOP;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_GET_GAKOCD;
--  2024/10/30 ZCZL.WANGYUNING ADD END
    --------------------------------------------------------
    --  機能概要      : バッチジョブステップテーブルの更新処理
    --  パラメータ    : i_UPD_KBN       更新区分
    --                : i_STEPRTNCODE   実行結果コード
    --                : i_CSV_RCNT      CSV出力件数
    --                : i_CSVFILENAME   CSVファイル名
    --                : i_PRTFILENAME   出力ファイル名
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
--  2024/09/03 ZCZL.WANGMING DELETE START 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00100の対応
        --初期処理
--        g_oKENSU_LIST.EXTEND(2);
--        g_oKENSU_LIST(1) := GKBEKENSU_RECORD(g_nCNT,'入力 口座振替済通知書転入・転出対象件数',1);
--        g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nCSVCNT,'出力 口座振替済通知書転入・転出ＣＳＶ',2);
--  2024/09/03 ZCZL.WANGMING DELETE END
    
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
    
    --------------------------------------------------------------------------------------------------
    --  機能概要      : 処理・ソート条件の値をセットする配列の初期化
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
    --------------------------------------------------------------------------------------------------
    PROCEDURE INITWKTENNYUSHUTU IS
    BEGIN
       GAKO_KBN     := 0;
       GAKO_CD      := 0;
       IDO_KBN      := 0;
       GAKUNEN      := 0;
       GAKOMEI      := '';
       --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
       --SHIMEI_KANA  := '';
       --SHIMEI_KANJI := '';
       --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
       IDOBI        := 0;
    END INITWKTENNYUSHUTU;
    --------------------------------------------------------------------------------------------------
    --  機能概要      : 対象学校が入力した学校条件に含まれるかチェック
    --  パラメータ    : GAKO_CD   : 対象学校コード
    --              :GAKO_JOKEN: 入力した学校コード
    --  モジュール区分: 内部関数
    --  戻り値        : 1:含まれる 0:含まれない
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
    --------------------------------------------------------------------------------------------------
    FUNCTION FUNC_CHECK_GAKO(GAKO_CD IN PLS_INTEGER,GAKO_JOKEN IN NVARCHAR2) RETURN PLS_INTEGER IS
    P_SQL      VARCHAR2(2000);
    I_COUNT    PLS_INTEGER;
    TYPE TYPECURSOR  IS REF CURSOR;
    CRGAKO     TYPECURSOR;
    BEGIN
      I_COUNT := 0;
      IF GAKO_JOKEN IS NOT NULL THEN
          P_SQL := 'SELECT COUNT(1) FROM DUAL ';
          P_SQL := P_SQL || 'WHERE ' || GAKO_CD || ' IN (' || GAKO_JOKEN || ')';
          EXECUTE IMMEDIATE  P_SQL;
          OPEN CRGAKO  FOR P_SQL;
          LOOP
            FETCH  CRGAKO INTO I_COUNT;
            EXIT WHEN CRGAKO%NOTFOUND;
          END LOOP;
      END IF;
      RETURN I_COUNT;
    END FUNC_CHECK_GAKO;
    --------------------------------------------------------------------------------
    --  機能概要      : 制御のフラグをセットするのを行う
    --  パラメータ    : i_KOJIN_NO
    --             : o_NAIYO_CD
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
    --------------------------------------------------------------------------------
    FUNCTION FUNC_PRMFLGSET(i_KOJIN_NO IN NUMBER,o_NAIYO_CD OUT NUMBER) RETURN NUMBER IS
      NODATAFOUND_FLG    BOOLEAN;
      ZERO_FLG           BOOLEAN;
    BEGIN
      --フラグ初期化
      BPRMFLG_001        := FALSE;
      BPRMFLG_002        := FALSE;
      BPRMFLG_003        := FALSE;
      BPRMFLG_004        := FALSE;
      NODATAFOUND_FLG    := FALSE;
      ZERO_FLG           := FALSE;
      --本名使用制御管理情報の取得
      BEGIN 
        SELECT NAIYO_CD
          INTO o_NAIYO_CD
          FROM GKBTSHIMEIJKN
         WHERE KOJIN_NO = i_KOJIN_NO
           AND CHOHYO_ID = 'GKB360R001';
        IF o_NAIYO_CD = 0 THEN
          ZERO_FLG  := TRUE;
        END IF;
      EXCEPTION
        --データを取得しない場合 
        WHEN NO_DATA_FOUND THEN
        NODATAFOUND_FLG  := TRUE;
      END;
      --氏名印字.制御ﾊﾟﾗﾒｰﾀ(10)が1の場合
      IF o_SHIMEIPRM(10) = 1 THEN
        BPRMFLG_001  := TRUE;
      END IF;
      --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(10)が4、6場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(10) IN (4, 6) THEN
          BPRMFLG_002  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在する、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(10)が3、4、5、6場合
      IF NOT NODATAFOUND_FLG AND NOT ZERO_FLG THEN
        IF o_SHIMEIPRM(10) IN(3,4,5,6) THEN
          BPRMFLG_003  := TRUE;
        END IF;
      END IF;
        -- 本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(10)が4、5場合「生年月日」
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(10) IN (4, 5) THEN
          BPRMFLG_004  := TRUE;
        END IF;
      END IF;
    RETURN 0;
    END FUNC_PRMFLGSET;
    --------------------------------------------------------------------------------
    --  機能概要      : 制御を行う
    --  パラメータ    : i_HONMYO
    --             : i_SHIMEI
    --             : o_SET
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SEIGYO_SET(i_HONMYO IN NVARCHAR2,i_SHIMEI IN NVARCHAR2, o_SET OUT NVARCHAR2) RETURN NUMBER
    IS
    BEGIN
      -- HONMYO_KANAをセット
      IF BPRMFLG_001 OR BPRMFLG_002 THEN
        o_SET := NVL(TRIM(i_HONMYO),i_SHIMEI);
      END IF;
      -- 本名使用制御管理情報の設定で編集
      IF BPRMFLG_003 THEN
        IF N_NAIYO_CD IN(11,12) THEN
          o_SET := NVL(TRIM(i_SHIMEI),i_HONMYO);
        ELSIF N_NAIYO_CD IN(21,22) THEN
          o_SET := NVL(TRIM(i_HONMYO),i_SHIMEI);
        END IF;
      END IF;
      --SHIMEI_KANAをセット
      IF NOT BPRMFLG_001 AND NOT BPRMFLG_002 AND NOT BPRMFLG_003 THEN
        o_SET := NVL(TRIM(i_SHIMEI),i_HONMYO);
      END IF;
      RETURN 0;
    END FUNC_SEIGYO_SET;
    --------------------------------------------------------------------------------
    --  機能概要      : 転入・転出児童生徒中間（GKBWTENNYUSHUTSU）テーブルの作成
    --  パラメータ    : ない
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 その他
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
       FRET             PLS_INTEGER;            -- 戻り値
       p_KIZYUN         PLS_INTEGER;            -- 抽出年月
       VSQLSEL          VARCHAR2(2000);         -- SQL文
       NEN              NVARCHAR2(10);          -- 和暦年度
       NEN2             NUMBER(5) := 0;         -- 西暦年度
       ICNT             BINARY_INTEGER;         -- カウント
       NPRTN            NUMBER;
       NPRTN2           NUMBER;                 --最新取得用
       IRTNAH           PLS_INTEGER;
       VNYUGAKUTENNYU_BI      NUMBER(8);        --V入学転入年月
       VTENGAKUSOTSUGYO_BI    NUMBER(8);        --V転学卒業年月\
--  2024/06/04 ZCZL.ZHANGLEI Update start 0.3.000.000:新WizLIFE２次開発
--       KOJINNO1               NUMBER(12);       --個人番号
--       KOJINNO2               NUMBER(12);       --個人番号
       KOJINNO1               NUMBER(15);       --個人番号
       KOJINNO2               NUMBER(15);       --個人番号
--  2024/06/04 ZCZL.ZHANGLEI Update end
       VGAKO_JOKEN            BOOLEAN;          --学校条件フラグ
       TYPE TYPECURSOR        IS REF CURSOR;
       CRATENA                TYPECURSOR;
--  2024/06/04 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
       vDUMMY              NVARCHAR2(1000);
    BEGIN
       FRET            := -2;
       ICNT            := 0;
       NEN             := SUBSTR(VNENDO,1,3);
       NEN2            := KKAPK0020.FNENDO(TO_NUMBER(NEN),1);
       p_KIZYUN        := TO_NUMBER(TO_CHAR(NEN2) || SUBSTR(VNENDO,4,2)); --西暦年月
       --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
       IF VSYOGAKO_CD IS NULL AND VTYUGAKO_CD IS NULL AND VKUIKIGAI_CD IS NULL AND VYOGOGAKO_CD IS NULL AND VKUNISHIRITSU_CD IS NULL THEN
       --IF VSYOGAKO_CD IS NULL AND VTYUGAKO_CD IS NULL AND VKUIKIGAI_CD IS NULL AND VYOGOGAKO_CD IS NULL AND g_vKUNISHIRITSU_CD IS NULL THEN
	   --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 END
         VGAKO_JOKEN := FALSE;
       ELSE
         VGAKO_JOKEN := TRUE;
       END IF;
       BEGIN
       VSQLSEL := '';
       VSQLSEL := VSQLSEL || 'SELECT ';
       VSQLSEL := VSQLSEL || 'KOJIN_NO,RIREKI_RENBAN ';
--  2024/06/04 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
       VSQLSEL := VSQLSEL || ',RIREKI_RENBAN_EDA ';
       VSQLSEL := VSQLSEL || 'FROM ';
       VSQLSEL := VSQLSEL || 'GKBTGAKUREIBO A ';
       VSQLSEL := VSQLSEL || 'WHERE  ';
       VSQLSEL := VSQLSEL || '    GAKUNEN NOT IN (0,99) ';
--  2024/06/04 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
       VSQLSEL := VSQLSEL || ' AND SAKUJO_FLG = 0 ';
--  2024/06/04 ZCZL.ZHANGLEI UPDATE 0.3.000.000:新WizLIFE２次開発
       --IF VSYOGAKO_CD IS NOT NULL OR VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR VYOGOGAKO_CD IS NOT NULL THEN
       --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
       --IF VSYOGAKO_CD IS NOT NULL OR VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR VYOGOGAKO_CD IS NOT NULL OR g_vKUNISHIRITSU_CD IS NOT NULL THEN
       IF VSYOGAKO_CD IS NOT NULL OR VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR VYOGOGAKO_CD IS NOT NULL OR VKUNISHIRITSU_CD IS NOT NULL THEN
	   --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 END
            VSQLSEL := VSQLSEL || 'AND (';
            IF VSYOGAKO_CD IS NOT NULL THEN
--  2024/06/04 ZCZL.ZHANGLEI UPDATE 0.3.000.000:新WizLIFE２次開発
                --IF VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR  VYOGOGAKO_CD IS NOT NULL THEN
                --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
                --IF VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR  VYOGOGAKO_CD IS NOT NULL OR g_vKUNISHIRITSU_CD IS NOT NULL THEN
                IF VTYUGAKO_CD IS NOT NULL OR VKUIKIGAI_CD IS NOT NULL OR  VYOGOGAKO_CD IS NOT NULL OR VKUNISHIRITSU_CD IS NOT NULL THEN 
				--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 END
                    --小学生のみに変更
                    VSQLSEL := VSQLSEL || '(A.SYOGAKO_CD IN ('|| VSYOGAKO_CD ||') AND A.SYOGAKO_SOTSUGYO_BI = 0) OR ';
                ELSE
                    --小学生のみに変更
                    VSQLSEL := VSQLSEL || '(A.SYOGAKO_CD IN ('|| VSYOGAKO_CD ||') AND A.SYOGAKO_SOTSUGYO_BI = 0) ';
                END IF;
            END IF;
            IF VTYUGAKO_CD IS NOT NULL THEN
--  2024/06/04 ZCZL.ZHANGLEI UPDATE 0.3.000.000:新WizLIFE２次開発
                --IF VKUIKIGAI_CD IS NOT NULL OR   VYOGOGAKO_CD IS NOT NULL THEN
                --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
                --IF VKUIKIGAI_CD IS NOT NULL OR   VYOGOGAKO_CD IS NOT NULL OR g_vKUNISHIRITSU_CD IS NOT NULL THEN 
                IF VKUIKIGAI_CD IS NOT NULL OR   VYOGOGAKO_CD IS NOT NULL OR VKUNISHIRITSU_CD IS NOT NULL THEN 
                --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 END
                
                    -- 中学生のみに変更
                    --卒業日の判定を修正
                    VSQLSEL := VSQLSEL || '(A.TYUGAKO_CD IN ('|| VTYUGAKO_CD ||') AND ';
                    VSQLSEL := VSQLSEL || '((A.SYOGAKO_SOTSUGYO_BI <> 0 AND A.SYOGAKO_CD <> 0) OR (A.SYOGAKO_TENGAKU_BI <> 0 AND A.SYOGAKO_CD <> 0) OR (A.SYOGAKO_SOTSUGYO_BI = 0 AND A.SYOGAKO_CD = 0))) OR '; 
                ELSE
                    -- 中学生のみに変更
                    --卒業日の判定を修正
                    VSQLSEL := VSQLSEL || '(A.TYUGAKO_CD IN ('|| VTYUGAKO_CD ||') AND  ';
                    VSQLSEL := VSQLSEL || '((A.SYOGAKO_SOTSUGYO_BI <> 0 AND A.SYOGAKO_CD <> 0) OR (A.SYOGAKO_TENGAKU_BI <> 0 AND A.SYOGAKO_CD <> 0) OR (A.SYOGAKO_SOTSUGYO_BI = 0 AND A.SYOGAKO_CD = 0)))  ';   
                END IF;
            END IF;
            IF VKUIKIGAI_CD IS NOT NULL THEN
--  2024/06/04 ZCZL.ZHANGLEI UPDATE 0.3.000.000:新WizLIFE２次開発
                --IF VYOGOGAKO_CD IS NOT NULL THEN
                --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
                --IF VYOGOGAKO_CD IS NOT NULL OR g_vKUNISHIRITSU_CD IS NOT NULL THEN
                IF VYOGOGAKO_CD IS NOT NULL OR VKUNISHIRITSU_CD IS NOT NULL THEN
				--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 END
                    VSQLSEL := VSQLSEL || 'A.KUIKIGAI_CD IN ('|| VKUIKIGAI_CD ||') OR ';
                ELSE
                    VSQLSEL := VSQLSEL || 'A.KUIKIGAI_CD IN ('|| VKUIKIGAI_CD ||')';
                END IF;
            END IF;
            IF VYOGOGAKO_CD IS NOT NULL THEN
--  2024/06/04 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
			  --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
			  --IF g_vKUNISHIRITSU_CD IS NOT NULL THEN
              IF VKUNISHIRITSU_CD IS NOT NULL THEN
			  --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 END
                VSQLSEL := VSQLSEL || 'A.YOGOGAKO_CD IN ('|| VYOGOGAKO_CD ||') OR ';
              ELSE
--  2024/06/04 ZCZL.ZHANGLEI ADD END  
                VSQLSEL := VSQLSEL || 'A.YOGOGAKO_CD IN ('|| VYOGOGAKO_CD ||') ';
--  2024/06/04 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発  
              END IF;  
            END IF;
--  2024/06/04 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
			--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START

            --IF g_vKUNISHIRITSU_CD IS NOT NULL THEN
              --VSQLSEL := VSQLSEL || 'A.KUNISHIRITSU_CD IN ('|| g_vKUNISHIRITSU_CD ||') ';
            IF VKUNISHIRITSU_CD IS NOT NULL THEN
              VSQLSEL := VSQLSEL || 'A.KUNISHIRITSU_CD IN ('|| VKUNISHIRITSU_CD ||') ';
			--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
            END IF;
--  2024/06/04 ZCZL.ZHANGLEI ADD END  
            VSQLSEL := VSQLSEL || ' )';
       END IF;
       VSQLSEL := VSQLSEL ||' ORDER BY KOJIN_NO,RIREKI_RENBAN DESC ';
       EXECUTE IMMEDIATE  VSQLSEL;
            OPEN CRATENA  FOR VSQLSEL;
            LOOP
               FETCH  CRATENA INTO CRATENA_WORK;
               EXIT WHEN CRATENA%NOTFOUND;
               ICNT := ICNT+1;
--  2024/06/04 ZCZL.ZHANGLEI UPDATE 0.3.000.000:新WizLIFE２次開発
               --GKBSKJDOG2(CRATENA_WORK.KOJIN_NO,CRATENA_WORK.RIREKI_RENBAN,RG,NPRTN);
               GKBSKJDOG2(CRATENA_WORK.KOJIN_NO,CRATENA_WORK.RIREKI_RENBAN,CRATENA_WORK.RIREKI_RENBAN_EDA,RG,NPRTN);
 --  2024/06/04 ZCZL.ZHANGLEI UPDATE START 0.3.000.000:新WizLIFE２次開発
               I_RTN := GKBFKHMCTRL(CRATENA_WORK.KOJIN_NO,
                                    g_rJSTP.Chohyoid,
                                    0,
                                    g_vGKB360_CTL,
                                    SHIMEI_KANA, --氏名かな      
                                    SHIMEI_KANJI,  --氏名漢字        
                                    vDUMMY);
--  2024/06/04 ZCZL.ZHANGLEI UPDATE END  
               --学齢簿の最新取得
               GKBSKJDOG(CRATENA_WORK.KOJIN_NO,RG2,NPRTN2);
               IF NPRTN = 0 AND NPRTN2 = 0 THEN     
                --最新が0,99年の場合は対象外
                IF RG2.GAKUNEN NOT IN (0,99) THEN   
                   IF ICNT = 1 THEN 
                      KOJINNO1 := CRATENA_WORK.KOJIN_NO;
                      KOJINNO2 := 0;
                   ELSE
                      KOJINNO2 := CRATENA_WORK.KOJIN_NO;
                   END IF;
                 --小学校
                 --抽出条件に任意学校の指定があり且つ学校が指定条件にあてはまる場合
                 --抽出条件に任意学校の指定がない場合
                 IF (VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.SYOGAKO_CD,VSYOGAKO_CD) = 1 ) OR VGAKO_JOKEN = FALSE THEN       --小学校条件に存在チェック
                   --条件 1 AND 2
                   IF RG.SYOGAKO_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.SYOGAKO_TENNYUGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 1;                            --異動区分を設定
                      GAKO_CD  := RG.SYOGAKO_CD + 1000;         --学校コードを設定
                      IDOBI    := RG.SYOGAKO_TENNYUGAKU_BI;     --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT SYOGAKOMEI
                            INTO GAKOMEI
                          FROM   GKBTSHOGAKKO
                          WHERE  SYOGAKO_CD = RG.SYOGAKO_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                         --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --IF RB.JINKAKU_KBN = 1 THEN
                          -- 児童氏名かな
                          --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                          -- 児童氏名漢字
                          --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                        --END IF;
                        --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                        JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   --条件 1 AND 3
                   IF RG.SYOGAKO_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.SYOGAKO_TENGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 2;                            --異動区分を設定
                      GAKO_CD  := RG.SYOGAKO_CD + 1000;         --学校コードを設定
                      IDOBI    := RG.SYOGAKO_TENGAKU_BI;        --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT SYOGAKOMEI
                            INTO GAKOMEI
                          FROM   GKBTSHOGAKKO
                          WHERE  SYOGAKO_CD = RG.SYOGAKO_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                      --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                         --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --IF RB.JINKAKU_KBN = 1 THEN
                           -- 児童氏名かな
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                           -- 児童氏名漢字
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                         --END IF;
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   IF KOJINNO1 <> KOJINNO2 THEN                    --条件 19
                      --V入学転入年月、V転学卒業年月に初期値0を設定
                      VNYUGAKUTENNYU_BI   := 0;
                      VTENGAKUSOTSUGYO_BI := 0;
                      IF RG.SYOGAKO_NYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.SYOGAKO_NYUGAKU_BI),1,6));
                      END IF;
                      IF RG.SYOGAKO_TENNYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.SYOGAKO_TENNYUGAKU_BI),1,6));
                      END IF;
                      IF RG.SYOGAKO_TENGAKU_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.SYOGAKO_TENGAKU_BI),1,6));
                      END IF;
                      IF RG.SYOGAKO_SOTSUGYO_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.SYOGAKO_SOTSUGYO_BI),1,6));
                      END IF;
                      --条件 1 AND 4
                      IF RG.SYOGAKO_CD <> 0 THEN                                                                         
                         IF VNYUGAKUTENNYU_BI <=  p_KIZYUN AND (VTENGAKUSOTSUGYO_BI > p_KIZYUN OR VTENGAKUSOTSUGYO_BI = 0) THEN
                             INITWKTENNYUSHUTU;
                             IF RG.GAKUNEN > 6 THEN 
                                GAKO_KBN := 2;                         --学校区分を設定
                                GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                             ELSE
                                GAKO_KBN := 1;                         --学校区分を設定
                                GAKUNEN := RG.GAKUNEN;                 --学年を設定
                             END IF;
                             IDO_KBN  := 4;                            --異動区分を設定
                             GAKO_CD  := RG.SYOGAKO_CD + 1000;         --学校コードを設定
                             IDOBI    := NULL;                         --異動日を設定
                             --学校名を設定
                             BEGIN
                                 SELECT SYOGAKOMEI
                                   INTO GAKOMEI
                                 FROM   GKBTSHOGAKKO
                                 WHERE  SYOGAKO_CD = RG.SYOGAKO_CD;
                             EXCEPTION
                                 WHEN NO_DATA_FOUND THEN
                                      GAKOMEI := NULL;
                             END;
                             IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                         'GKB',
                                                         ISAKUSEIBI,
                                                         RB,
                                                         RC);
                             IF IRTNAH = 0 THEN
                             --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                                --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                                --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                                I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応
                                --IF RB.JINKAKU_KBN = 1 THEN
                                  -- 児童氏名かな
                                  --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                                  -- 児童氏名漢字
                                  --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                                --END IF;
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応
                                JINKAKU_KBN   := RB.JINKAKU_KBN;
                             END IF;
                             BEGIN
                                INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                                COMMIT;
                             EXCEPTION
                                 WHEN OTHERS THEN
                                 ROLLBACK;                  -- 処理前に戻す
                                 FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                                 RETURN FRET;
                             END;
                         END IF;
                      END IF;
                   END IF;
                 END IF;  --小学校条件に存在チェック
                 --中学校(6年生以上(入学予定者を除く))
                 --抽出条件に任意学校の指定があり且つ学校が指定条件にあてはまる場合
                 --抽出条件に任意学校の指定がない場合
                 IF RG.GAKUNEN > 6 
                  AND ((VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.TYUGAKO_CD,VTYUGAKO_CD) = 1 ) OR VGAKO_JOKEN = FALSE) THEN
                   --条件 5 AND 6
                   IF RG.TYUGAKO_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.TYUGAKO_TENNYUGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 1;                            --異動区分を設定
                      GAKO_CD  := RG.TYUGAKO_CD + 2000;         --学校コードを設定
                      IDOBI    := RG.TYUGAKO_TENNYUGAKU_BI;     --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT TYUGAKOMEI
                            INTO GAKOMEI
                          FROM   GKBTCHUGAKKO
                          WHERE  TYUGAKO_CD = RG.TYUGAKO_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                      --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                         --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                           --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                           --IF RB.JINKAKU_KBN = 1 THEN
                           -- 児童氏名かな
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                           -- 児童氏名漢字
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                         --END IF;
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   --条件 5 AND 7
                   IF RG.TYUGAKO_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.TYUGAKO_TENGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 2;                            --異動区分を設定
                      GAKO_CD  := RG.TYUGAKO_CD + 2000;         --学校コードを設定
                      IDOBI    := RG.TYUGAKO_TENGAKU_BI;        --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT TYUGAKOMEI
                            INTO GAKOMEI
                          FROM   GKBTCHUGAKKO
                          WHERE  TYUGAKO_CD = RG.TYUGAKO_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                      --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                         --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                           --IF RB.JINKAKU_KBN = 1 THEN
                           -- 児童氏名かな
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                           -- 児童氏名漢字
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                         --END IF;
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   IF KOJINNO1 <> KOJINNO2 THEN                    --条件 19
                      --V入学転入年月、V転学卒業年月に初期値0を設定
                      VNYUGAKUTENNYU_BI   := 0;
                      VTENGAKUSOTSUGYO_BI := 0;
                      IF RG.TYUGAKO_NYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.TYUGAKO_NYUGAKU_BI),1,6));
                      END IF;
                      IF RG.TYUGAKO_TENNYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.TYUGAKO_TENNYUGAKU_BI),1,6));
                      END IF;
                      IF RG.TYUGAKO_TENGAKU_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.TYUGAKO_TENGAKU_BI),1,6));
                      END IF;
                      IF RG.TYUGAKO_SOTSUGYO_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.TYUGAKO_SOTSUGYO_BI),1,6));
                      END IF;
                      --条件 5 AND 8
                      IF RG.TYUGAKO_CD <> 0 THEN                                                                         
                         IF VNYUGAKUTENNYU_BI <=  p_KIZYUN AND (VTENGAKUSOTSUGYO_BI > p_KIZYUN OR VTENGAKUSOTSUGYO_BI = 0) THEN
                             INITWKTENNYUSHUTU;
                             IF RG.GAKUNEN > 6 THEN 
                                 GAKO_KBN := 2;                         --学校区分を設定
                                 GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                             ELSE
                                 GAKO_KBN := 1;                         --学校区分を設定
                                 GAKUNEN := RG.GAKUNEN;                 --学年を設定
                             END IF;
                             IDO_KBN  := 4;                             --異動区分を設定
                             GAKO_CD  := RG.TYUGAKO_CD + 2000;          --学校コードを設定
                             IDOBI    := NULL;                          --異動日を設定
                             --学校名を設定
                             BEGIN
                                 SELECT TYUGAKOMEI
                                   INTO GAKOMEI
                                 FROM   GKBTCHUGAKKO
                                 WHERE  TYUGAKO_CD = RG.TYUGAKO_CD;
                             EXCEPTION
                                 WHEN NO_DATA_FOUND THEN
                                      GAKOMEI := NULL;
                             END;
                             IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                         'GKB',
                                                         ISAKUSEIBI,
                                                         RB,
                                                         RC);
                             IF IRTNAH = 0 THEN
                             --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                                --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                                --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                                I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                                --IF RB.JINKAKU_KBN = 1 THEN
                                  -- 児童氏名かな
                                  --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                                  -- 児童氏名漢字
                                  --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                                --END IF;
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                                JINKAKU_KBN   := RB.JINKAKU_KBN;
                             END IF;
                             BEGIN
                                INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                                COMMIT;
                             EXCEPTION
                                 WHEN OTHERS THEN
                                 ROLLBACK;                  -- 処理前に戻す
                                 FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                                 RETURN FRET;
                             END;
                         END IF;
                      END IF;
                   END IF;
                 END IF;  --小学校条件に存在チェック
                 --区域外学校
                 --抽出条件に任意学校の指定があり且つ学校が指定条件にあてはまる場合
                 --抽出条件に任意学校の指定がない場合
                 IF (VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.KUIKIGAI_CD,VKUIKIGAI_CD) = 1 ) OR VGAKO_JOKEN = FALSE THEN    --小学校条件に存在チェック
                   --条件 9 AND 10
                   IF RG.KUIKIGAI_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.KUIKIGAI_TENNYUGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 1;                            --異動区分を設定
                      GAKO_CD  := RG.KUIKIGAI_CD + 3000;        --学校コードを設定
                      IDOBI    := RG.KUIKIGAI_TENNYUGAKU_BI;    --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT KUIKIGAIMEI
                            INTO GAKOMEI
                          FROM   GKBTKUIKIGAI
                          WHERE  KUIKIGAI_CD = RG.KUIKIGAI_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                      --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                         --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                           --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                           --IF RB.JINKAKU_KBN = 1 THEN
                           -- 児童氏名かな
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                           -- 児童氏名漢字
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                         --END IF;
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   --条件 9 AND 11
                   IF RG.KUIKIGAI_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.KUIKIGAI_TENGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 2;                            --異動区分を設定
                      GAKO_CD  := RG.KUIKIGAI_CD + 3000;        --学校コードを設定
                      IDOBI    := RG.KUIKIGAI_TENGAKU_BI;       --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT KUIKIGAIMEI
                            INTO GAKOMEI
                          FROM   GKBTKUIKIGAI
                          WHERE  KUIKIGAI_CD = RG.KUIKIGAI_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                      --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                         --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                           --IF RB.JINKAKU_KBN = 1 THEN
                           -- 児童氏名かな
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                           -- 児童氏名漢字
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                         --END IF;
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   --条件 9 AND 12
                   IF RG.KUIKIGAI_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.KUIKIGAI_TAIGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 3;                            --異動区分を設定
                      GAKO_CD  := RG.KUIKIGAI_CD + 3000;        --学校コードを設定
                      IDOBI    := RG.KUIKIGAI_TAIGAKU_BI;       --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT KUIKIGAIMEI
                            INTO GAKOMEI
                          FROM   GKBTKUIKIGAI
                          WHERE  KUIKIGAI_CD = RG.KUIKIGAI_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                      --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                         --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                           --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                           --IF RB.JINKAKU_KBN = 1 THEN
                           -- 児童氏名かな
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                           -- 児童氏名漢字
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                         --END IF;
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   IF KOJINNO1 <> KOJINNO2 THEN                    --条件 19
                      --V入学転入年月、V転学卒業年月に初期値0を設定
                      VNYUGAKUTENNYU_BI   := 0;
                      VTENGAKUSOTSUGYO_BI := 0;
                      IF RG.KUIKIGAI_NYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUIKIGAI_NYUGAKU_BI),1,6));
                      END IF;
                      IF RG.KUIKIGAI_TENNYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUIKIGAI_TENNYUGAKU_BI),1,6));
                      END IF;
                      IF RG.KUIKIGAI_TENGAKU_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUIKIGAI_TENGAKU_BI),1,6));
                      END IF;
                      IF RG.KUIKIGAI_TAIGAKU_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUIKIGAI_TAIGAKU_BI),1,6));
                      END IF;
                      IF RG.KUIKIGAI_SOTSUGYO_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUIKIGAI_SOTSUGYO_BI),1,6));
                      END IF;
                      --条件 9 AND 13
                      IF RG.KUIKIGAI_CD <> 0 THEN
                         IF VNYUGAKUTENNYU_BI <=  p_KIZYUN AND (VTENGAKUSOTSUGYO_BI > p_KIZYUN OR VTENGAKUSOTSUGYO_BI = 0) THEN
                             INITWKTENNYUSHUTU;
                             IF RG.GAKUNEN > 6 THEN 
                                GAKO_KBN := 2;                         --学校区分を設定
                                GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                             ELSE
                                GAKO_KBN := 1;                         --学校区分を設定
                                GAKUNEN := RG.GAKUNEN;                 --学年を設定
                             END IF;
                             IDO_KBN  := 4;                            --異動区分を設定
                             GAKO_CD  := RG.KUIKIGAI_CD + 3000;        --学校コードを設定
                             IDOBI    := NULL;                         --異動日を設定
                             --学校名を設定
                             BEGIN
                                 SELECT KUIKIGAIMEI
                                   INTO GAKOMEI
                                 FROM   GKBTKUIKIGAI
                                 WHERE  KUIKIGAI_CD = RG.KUIKIGAI_CD;
                             EXCEPTION
                                 WHEN NO_DATA_FOUND THEN
                                      GAKOMEI := NULL;
                             END;
                             IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                         'GKB',
                                                         ISAKUSEIBI,
                                                         RB,
                                                         RC);
                             IF IRTNAH = 0 THEN
                             --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                                --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                                --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                                I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                                --IF RB.JINKAKU_KBN = 1 THEN
                                  -- 児童氏名かな
                                  --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                                  -- 児童氏名漢字
                                  --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                                --END IF;
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 ENd
                                JINKAKU_KBN   := RB.JINKAKU_KBN;
                             END IF;
                             BEGIN
                                INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                                COMMIT;
                             EXCEPTION
                                 WHEN OTHERS THEN
                                 ROLLBACK;                  -- 処理前に戻す
                                 FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                                 RETURN FRET;
                             END;
                         END IF;
                      END IF;
                   END IF;
                 END IF;   --小学校条件に存在チェック
                 --養護学校
                 --抽出条件に任意学校の指定があり且つ学校が指定条件にあてはまる場合
                 --抽出条件に任意学校の指定がない場合
                 IF (VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.YOGOGAKO_CD,VYOGOGAKO_CD) = 1 ) OR VGAKO_JOKEN = FALSE THEN  --小学校条件に存在チェック
                   --条件 14 AND 15
                   IF RG.YOGOGAKO_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.YOGOGAKO_TENNYUGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 1;                            --異動区分を設定
                      GAKO_CD  := RG.YOGOGAKO_CD + 4000;        --学校コードを設定
                      IDOBI    := RG.YOGOGAKO_TENNYUGAKU_BI;    --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT YOGOGAKOMEI
                            INTO GAKOMEI
                          FROM   GKBTYOGOGAKKO
                          WHERE  YOGOGAKO_CD = RG.YOGOGAKO_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                      --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                         --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --IF RB.JINKAKU_KBN = 1 THEN
                           -- 児童氏名かな
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                           -- 児童氏名漢字
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                         --END IF;
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   --条件 14 AND 16
                   IF RG.YOGOGAKO_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.YOGOGAKO_TENGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 2;                            --異動区分を設定
                      GAKO_CD  := RG.YOGOGAKO_CD + 4000;        --学校コードを設定
                      IDOBI    := RG.YOGOGAKO_TENGAKU_BI;       --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT YOGOGAKOMEI
                            INTO GAKOMEI
                          FROM   GKBTYOGOGAKKO
                          WHERE  YOGOGAKO_CD = RG.YOGOGAKO_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                      --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                         --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                           --IF RB.JINKAKU_KBN = 1 THEN
                           -- 児童氏名かな
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                           -- 児童氏名漢字
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                         --END IF;
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   --条件 14 AND 17
                   IF RG.YOGOGAKO_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.YOGOGAKO_TAIGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 3;                            --異動区分を設定
                      GAKO_CD  := RG.YOGOGAKO_CD + 4000;        --学校コードを設定
                      IDOBI    := RG.YOGOGAKO_TAIGAKU_BI;       --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT YOGOGAKOMEI
                            INTO GAKOMEI
                          FROM   GKBTYOGOGAKKO
                          WHERE  YOGOGAKO_CD = RG.YOGOGAKO_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                      --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                         --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                         --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                           --IF RB.JINKAKU_KBN = 1 THEN
                           -- 児童氏名かな
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                           -- 児童氏名漢字
                           --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                         --END IF;
                         --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   IF KOJINNO1 <> KOJINNO2 THEN                    --条件 19
                      --V入学転入年月、V転学卒業年月に初期値0を設定
                      VNYUGAKUTENNYU_BI   := 0;
                      VTENGAKUSOTSUGYO_BI := 0;
                      IF RG.YOGOGAKO_NYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.YOGOGAKO_NYUGAKU_BI),1,6));
                      END IF;
                      IF RG.YOGOGAKO_TENNYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.YOGOGAKO_TENNYUGAKU_BI),1,6));
                      END IF;
                      IF RG.YOGOGAKO_TENGAKU_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.YOGOGAKO_TENGAKU_BI),1,6));
                      END IF;
                      IF RG.YOGOGAKO_TAIGAKU_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.YOGOGAKO_TAIGAKU_BI),1,6));
                      END IF;
                      IF RG.YOGOGAKO_SOTSUGYO_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.YOGOGAKO_SOTSUGYO_BI),1,6));
                      END IF;
                      --条件 14 AND 18
                      IF RG.YOGOGAKO_CD <> 0 THEN                                                                         
                         IF VNYUGAKUTENNYU_BI <=  p_KIZYUN AND (VTENGAKUSOTSUGYO_BI > p_KIZYUN OR VTENGAKUSOTSUGYO_BI = 0) THEN
                             INITWKTENNYUSHUTU;
                             IF RG.GAKUNEN > 6 THEN 
                                 GAKO_KBN := 2;                         --学校区分を設定
                                 GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                             ELSE
                                 GAKO_KBN := 1;                         --学校区分を設定
                                 GAKUNEN := RG.GAKUNEN;                 --学年を設定
                             END IF;
                             IDO_KBN  := 4;                             --異動区分を設定
                             GAKO_CD  := RG.YOGOGAKO_CD + 4000;         --学校コードを設定
                             IDOBI    := NULL;                          --異動日を設定
                             --学校名を設定
                             BEGIN
                                 SELECT YOGOGAKOMEI
                                   INTO GAKOMEI
                                 FROM   GKBTYOGOGAKKO
                                 WHERE  YOGOGAKO_CD = RG.YOGOGAKO_CD;
                             EXCEPTION
                                 WHEN NO_DATA_FOUND THEN
                                      GAKOMEI := NULL;
                             END;
                             IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                         'GKB',
                                                         ISAKUSEIBI,
                                                         RB,
                                                         RC);
                             IF IRTNAH = 0 THEN
                             --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                                --SHIMEI_KANA  := RB.SHIMEI_KANA;   --氏名かなを設定
                                --SHIMEI_KANJI := RB.SHIMEI_KANJI;  --氏名漢字を設定
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                                I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
                                --IF RB.JINKAKU_KBN = 1 THEN
                                  -- 児童氏名かな
                                  --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,SHIMEI_KANA);
                                  -- 児童氏名漢字
                                  --I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,SHIMEI_KANJI);
                                --END IF;
                                --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
                                JINKAKU_KBN   := RB.JINKAKU_KBN;
                             END IF;
                             BEGIN
                                INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                                COMMIT;
                             EXCEPTION
                                 WHEN OTHERS THEN
                                 ROLLBACK;                  -- 処理前に戻す
                                 FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                                 RETURN FRET;
                             END;




                             
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
			IF (VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.KUNISHIRITSU_CD,VKUNISHIRITSU_CD) = 1 ) OR VGAKO_JOKEN = FALSE THEN  --小学校条件に存在チェック
                   --条件 16 AND 17
                   IF RG.KUNISHIRITSU_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TENGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 1;                            --異動区分を設定
                      GAKO_CD  := RG.KUNISHIRITSU_CD + 4000;        --学校コードを設定
                      IDOBI    := RG.KUNISHIRITSU_TENGAKU_BI;    --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT KUNISHIRITSUGAKKOMEI
                            INTO GAKOMEI
                          FROM   GKBTKUNISIRITSUGAKKO
                          WHERE  KUNISHIRITSUGAKKO_CD = RG.KUNISHIRITSU_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
 
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);

                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   --条件 17 AND 18
                   IF RG.KUNISHIRITSU_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TENGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 2;                            --異動区分を設定
                      GAKO_CD  := RG.KUNISHIRITSU_CD + 4000;        --学校コードを設定
                      IDOBI    := RG.KUNISHIRITSU_TENGAKU_BI;       --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT KUNISHIRITSUGAKKOMEI
                            INTO GAKOMEI
                          FROM   GKBTKUNISIRITSUGAKKO
                          WHERE  KUNISHIRITSUGAKKO_CD = RG.KUNISHIRITSU_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);

                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   --条件 19 AND 20
                   IF RG.KUNISHIRITSU_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TAIGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 3;                            --異動区分を設定
                      GAKO_CD  := RG.KUNISHIRITSU_CD + 4000;        --学校コードを設定
                      IDOBI    := RG.KUNISHIRITSU_TAIGAKU_BI;       --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT KUNISHIRITSUGAKKOMEI
                            INTO GAKOMEI
                          FROM   GKBTKUNISIRITSUGAKKO
                          WHERE  KUNISHIRITSUGAKKO_CD = RG.KUNISHIRITSU_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   IF KOJINNO1 <> KOJINNO2 THEN                    --条件 19
                      --V入学転入年月、V転学卒業年月に初期値0を設定
                      VNYUGAKUTENNYU_BI   := 0;
                      VTENGAKUSOTSUGYO_BI := 0;
                      IF RG.KUNISHIRITSU_NYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_NYUGAKU_BI),1,6));
                      END IF;
                      IF RG.KUNISHIRITSU_TENGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TENGAKU_BI),1,6));
                      END IF;
                      IF RG.KUNISHIRITSU_TENGAKU_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TENGAKU_BI),1,6));
                      END IF;
                      IF RG.KUNISHIRITSU_TAIGAKU_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TAIGAKU_BI),1,6));
                      END IF;
                      IF RG.KUNISHIRITSU_SOTSUGYO_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_SOTSUGYO_BI),1,6));
                      END IF;
                      --条件 21 AND 22
                      IF RG.KUNISHIRITSU_CD <> 0 THEN                                                                         
                         IF VNYUGAKUTENNYU_BI <=  p_KIZYUN AND (VTENGAKUSOTSUGYO_BI > p_KIZYUN OR VTENGAKUSOTSUGYO_BI = 0) THEN
                             INITWKTENNYUSHUTU;
                             IF RG.GAKUNEN > 6 THEN 
                                 GAKO_KBN := 2;                         --学校区分を設定
                                 GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                             ELSE
                                 GAKO_KBN := 1;                         --学校区分を設定
                                 GAKUNEN := RG.GAKUNEN;                 --学年を設定
                             END IF;
                             IDO_KBN  := 4;                             --異動区分を設定
                             GAKO_CD  := RG.KUNISHIRITSU_CD + 4000;         --学校コードを設定
                             IDOBI    := NULL;                          --異動日を設定
                             --学校名を設定
                             BEGIN
                                 SELECT KUNISHIRITSUGAKKOMEI
                                   INTO GAKOMEI
                                 FROM   GKBTKUNISIRITSUGAKKO
                                 WHERE  KUNISHIRITSUGAKKO_CD = RG.KUNISHIRITSU_CD;
                             EXCEPTION
                                 WHEN NO_DATA_FOUND THEN
                                      GAKOMEI := NULL;
                             END;
                             IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                         'GKB',
                                                         ISAKUSEIBI,
                                                         RB,
                                                         RC);
                             IF IRTNAH = 0 THEN
                                I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                                JINKAKU_KBN   := RB.JINKAKU_KBN;
                             END IF;
                             BEGIN
                                INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                                COMMIT;
                             EXCEPTION
                                 WHEN OTHERS THEN
                                 ROLLBACK;                  -- 処理前に戻す
                                 FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                                 RETURN FRET;
                             END;
                           END IF;  
                           END IF;  
                           END IF;  
                           END IF;  
                           
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 END
                         END IF;
                      END IF;
                   END IF;
                 END IF; --小学校条件に存在チェック
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
				 --国私立学校
                 --抽出条件に任意学校の指定があり且つ学校が指定条件にあてはまる場合
                 --抽出条件に任意学校の指定がない場合
                 IF (VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.KUNISHIRITSU_CD,VKUNISHIRITSU_CD) = 1 ) OR VGAKO_JOKEN = FALSE THEN  --小学校条件に存在チェック
                   --条件
                   IF RG.KUNISHIRITSU_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TENNYUGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 1;                            --異動区分を設定
                      GAKO_CD  := RG.KUNISHIRITSU_CD + 5000;    --学校コードを設定
                      IDOBI    := RG.KUNISHIRITSU_TENNYUGAKU_BI;--異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT KUNISHIRITSUGAKKOMEI
                            INTO GAKOMEI
                          FROM   GKBTKUNISIRITSUGAKKO
                          WHERE  KUNISHIRITSUGAKKO_CD = RG.KUNISHIRITSU_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                     END IF;
                   --条件
                   IF RG.KUNISHIRITSU_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TENGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 2;                            --異動区分を設定
                      GAKO_CD  := RG.KUNISHIRITSU_CD + 5000;    --学校コードを設定
                      IDOBI    := RG.KUNISHIRITSU_TENGAKU_BI;   --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT KUNISHIRITSUGAKKOMEI
                            INTO GAKOMEI
                          FROM   GKBTKUNISIRITSUGAKKO
                          WHERE  KUNISHIRITSUGAKKO_CD = RG.KUNISHIRITSU_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                   END IF;
                   --条件
                   IF RG.KUNISHIRITSU_CD <> 0 AND TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TAIGAKU_BI),1,6)) = p_KIZYUN THEN
                      INITWKTENNYUSHUTU;
                      IF RG.GAKUNEN > 6 THEN 
                         GAKO_KBN := 2;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                      ELSE
                         GAKO_KBN := 1;                         --学校区分を設定
                         GAKUNEN := RG.GAKUNEN;                 --学年を設定
                      END IF;
                      IDO_KBN  := 3;                            --異動区分を設定
                      GAKO_CD  := RG.KUNISHIRITSU_CD + 5000;    --学校コードを設定
                      IDOBI    := RG.KUNISHIRITSU_TAIGAKU_BI;   --異動日を設定
                      --学校名を設定
                      BEGIN
                          SELECT KUNISHIRITSUGAKKOMEI
                            INTO GAKOMEI
                          FROM   GKBTKUNISIRITSUGAKKO
                          WHERE  KUNISHIRITSUGAKKO_CD = RG.KUNISHIRITSU_CD;
                      EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                               GAKOMEI := NULL;
                      END;
                      IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IF IRTNAH = 0 THEN
                         I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                         JINKAKU_KBN   := RB.JINKAKU_KBN;
                      END IF;
                      BEGIN
                         INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                         COMMIT;
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;                  -- 処理前に戻す
                            FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                            RETURN FRET;
                      END;
                     END IF;
                   IF KOJINNO1 <> KOJINNO2 THEN                    --条件 19
                      --V入学転入年月、V転学卒業年月に初期値0を設定
                      VNYUGAKUTENNYU_BI   := 0;
                      VTENGAKUSOTSUGYO_BI := 0;
                      IF RG.KUNISHIRITSU_NYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_NYUGAKU_BI),1,6));
                      END IF;
                      IF RG.KUNISHIRITSU_TENNYUGAKU_BI > 0 THEN
                          VNYUGAKUTENNYU_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TENNYUGAKU_BI),1,6));
                      END IF;
                      IF RG.KUNISHIRITSU_TENGAKU_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TENGAKU_BI),1,6));
                      END IF;
                      IF RG.KUNISHIRITSU_TAIGAKU_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_TAIGAKU_BI),1,6));
                      END IF;
                      IF RG.KUNISHIRITSU_SOTSUGYO_BI > 0 THEN
                          VTENGAKUSOTSUGYO_BI := TO_NUMBER(SUBSTR(TO_CHAR(RG.KUNISHIRITSU_SOTSUGYO_BI),1,6));
                      END IF;
                      --条件 14 AND 18
                      IF RG.KUNISHIRITSU_CD <> 0 THEN                                                                         
                         IF VNYUGAKUTENNYU_BI <=  p_KIZYUN AND (VTENGAKUSOTSUGYO_BI > p_KIZYUN OR VTENGAKUSOTSUGYO_BI = 0) THEN
                             INITWKTENNYUSHUTU;
                             IF RG.GAKUNEN > 6 THEN 
                                 GAKO_KBN := 2;                         --学校区分を設定
                                 GAKUNEN := RG.GAKUNEN - 6;             --学年を設定
                             ELSE
                                 GAKO_KBN := 1;                         --学校区分を設定
                                 GAKUNEN := RG.GAKUNEN;                 --学年を設定
                             END IF;
                             IDO_KBN  := 4;                             --異動区分を設定
                             GAKO_CD  := RG.KUNISHIRITSU_CD + 5000;     --学校コードを設定
                             IDOBI    := NULL;                          --異動日を設定
                             --学校名を設定
                             BEGIN
                                 SELECT KUNISHIRITSUGAKKOMEI
                                   INTO GAKOMEI
                                 FROM   GKBTKUNISIRITSUGAKKO
                                 WHERE  KUNISHIRITSUGAKKO_CD = RG.KUNISHIRITSU_CD;
                             EXCEPTION
                                 WHEN NO_DATA_FOUND THEN
                                      GAKOMEI := NULL;
                             END;
                             IRTNAH := GAAPK0030.FGETATENA( RG.KOJIN_NO,
                                                         'GKB',
                                                         ISAKUSEIBI,
                                                         RB,
                                                         RC);
                             IF IRTNAH = 0 THEN
                                I_RTN  := FUNC_PRMFLGSET(RB.KOJIN_NO,N_NAIYO_CD);
                                JINKAKU_KBN   := RB.JINKAKU_KBN;
                             END IF;
                             BEGIN
                                INSERT INTO GKBWTENNYUSHUTSU VALUES (GAKO_KBN,
                                                          GAKO_CD,
                                                          IDO_KBN,
                                                          GAKUNEN,
                                                          GAKOMEI,
                                                          SHIMEI_KANA,
                                                          SHIMEI_KANJI,
                                                          IDOBI,
                                                          JINKAKU_KBN);
                                COMMIT;
                             EXCEPTION
                                 WHEN OTHERS THEN
                                 ROLLBACK;                  -- 処理前に戻す
                                 FRET := c_INOT_SUCCESS2;   -- 中間データ作成処理異常終了
                                 RETURN FRET;
                             END;    
                         END IF;
                      END IF;
                   END IF;
                 END IF; --小学校条件に存在チェック 
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 END
                END IF;  
               ELSE
                     FRET := c_INOT_SUCCESS2;          -- 作成処理異常終了
                     RETURN FRET;
               END IF;
               KOJINNO1 := CRATENA_WORK.KOJIN_NO;      -- 個人番号保存
               FRET := c_ISUCCESS;                     -- 正常終了
            END LOOP;
            IF CRATENA%ISOPEN THEN
              CLOSE CRATENA;
            END IF;
       END;
       -- 終了
       RETURN FRET;
    EXCEPTION
        /* その他エラー */
        WHEN OTHERS THEN
            IF CRATENA%ISOPEN THEN
              CLOSE CRATENA;
            END IF;
            FRET := c_INOT_SUCCESS;      -- 編集処理異常終了
            RETURN FRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------------------------------
    --  機能概要      : 転入・転出児童生徒ＣＳＶファイルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 その他
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
        VSQLSEL             VARCHAR2(20000);      -- ＳＱＬのソート以外
        ICNT                BINARY_INTEGER;       -- 戻り値
        FRET                PLS_INTEGER;          -- 戻り値
        NEN                 NUMBER(5);            -- 西暦年度
        NEN2                NVARCHAR2(10);        -- 平成年度
        MON                 NUMBER(5);            -- 月
        NENMON              NVARCHAR2(20);        -- 平成年月
        COUNT1              PLS_INTEGER;          -- １年 差引人数
        COUNT2              PLS_INTEGER;          -- ２年 差引人数
        COUNT3              PLS_INTEGER;          -- ３年 差引人数
        COUNT4              PLS_INTEGER;          -- ４年 差引人数
        COUNT5              PLS_INTEGER;          -- ５年 差引人数
        COUNT6              PLS_INTEGER;          -- ６年 差引人数
        COUNTALL            PLS_INTEGER;          -- 合計 差引人数
        r_CHOHYO_001        GKBWL360R001%ROWTYPE;
        TYPE TYPECURSOR2    IS REF CURSOR;
        CRATENA2            TYPECURSOR2;
    BEGIN
        DELETE FROM GKBWL360R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
        ICNT  := 0;
--  2024/09/03 ZCZL.WANGMING ADD 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00100の対応
        NCSVSHUTURYOKU_COUNT  := 0;
        FRET  := c_INOT_SUCCESS;
        NEN   := KKAPK0020.FNENDO(TO_NUMBER(SUBSTR(VNENDO,1,3)),1);
        NEN2  := KKAPK0020.FNENDOEDIT(1,NEN,3);
        MON   := TO_NUMBER(SUBSTR(VNENDO,4,2));
        IF LENGTH(TO_CHAR(MON)) = 1 THEN
            NENMON := NEN2 || '年' || ' ' || TO_CHAR(MON) || '月分';
        ELSE
            NENMON := NEN2 || '年' || TO_CHAR(MON) || '月分';
        END IF;    
        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT A.*, ';
            VSQLSEL := VSQLSEL || 'B.IDO_KBN,B.GAKUNEN,B.SHIMEI_KANJI,B.SHIMEI_KANA,B.IDOBI,B.JINKAKU_KBN ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || '(SELECT  C.GAKO_CD,C.GAKO_KBN,C.GAKOMEI ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,11,1,0)) GAKUNEN1_TENNYU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,12,1,0)) GAKUNEN2_TENNYU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,13,1,0)) GAKUNEN3_TENNYU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,14,1,0)) GAKUNEN4_TENNYU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,15,1,0)) GAKUNEN5_TENNYU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,16,1,0)) GAKUNEN6_TENNYU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN,1,1,0))             ALL_TENNYU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,21,1,0)) GAKUNEN1_TENGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,22,1,0)) GAKUNEN2_TENGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,23,1,0)) GAKUNEN3_TENGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,24,1,0)) GAKUNEN4_TENGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,25,1,0)) GAKUNEN5_TENGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,26,1,0)) GAKUNEN6_TENGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN,2,1,0))             ALL_TENGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,31,1,0)) GAKUNEN1_TAIGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,32,1,0)) GAKUNEN2_TAIGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,33,1,0)) GAKUNEN3_TAIGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,34,1,0)) GAKUNEN4_TAIGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,35,1,0)) GAKUNEN5_TAIGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,36,1,0)) GAKUNEN6_TAIGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN,3,1,0))             ALL_TAIGAKU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,41,1,0)) GAKUNEN1_GETUMATU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,42,1,0)) GAKUNEN2_GETUMATU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,43,1,0)) GAKUNEN3_GETUMATU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,44,1,0)) GAKUNEN4_GETUMATU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,45,1,0)) GAKUNEN5_GETUMATU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN||C.GAKUNEN,46,1,0)) GAKUNEN6_GETUMATU_CNT ';
            VSQLSEL := VSQLSEL || ',SUM(DECODE(C.IDO_KBN,4,1,0))             ALL_GETUMATU_CNT ';
            VSQLSEL := VSQLSEL || 'FROM (SELECT DISTINCT * FROM GKBWTENNYUSHUTSU) C ';
            VSQLSEL := VSQLSEL || 'GROUP BY C.GAKO_CD,C.GAKO_KBN,C.GAKOMEI ';
            VSQLSEL := VSQLSEL || 'ORDER BY C.GAKO_CD,C.GAKO_KBN,C.GAKOMEI ';
            VSQLSEL := VSQLSEL || ') A, ';
            VSQLSEL := VSQLSEL || '(SELECT DISTINCT GAKO_KBN,GAKO_CD,IDO_KBN,GAKUNEN,IDOBI,SHIMEI_KANA,SHIMEI_KANJI,JINKAKU_KBN ';
            VSQLSEL := VSQLSEL || 'FROM GKBWTENNYUSHUTSU ';
            VSQLSEL := VSQLSEL || 'WHERE IDO_KBN IN (1,2,3) ';
            VSQLSEL := VSQLSEL || 'UNION  ';
            VSQLSEL := VSQLSEL || 'SELECT DISTINCT C.GAKO_KBN,C.GAKO_CD,C.IDO_KBN,  ';
            VSQLSEL := VSQLSEL || 'NULL GAKUNEN,NULL IDOBI,NULL SHIMEI_KANA,NULL SHIMEI_KANJI,0 JINKAKU_KBN  ';
            VSQLSEL := VSQLSEL || 'FROM GKBWTENNYUSHUTSU C  ';
            VSQLSEL := VSQLSEL || 'WHERE C.IDO_KBN IN (4) AND  ';
            VSQLSEL := VSQLSEL || 'NOT EXISTS (SELECT D.GAKO_CD FROM GKBWTENNYUSHUTSU D  ';
            VSQLSEL := VSQLSEL || 'WHERE ';
            VSQLSEL := VSQLSEL || 'C.GAKO_CD  = D.GAKO_CD  ';
            VSQLSEL := VSQLSEL || 'AND  C.GAKO_KBN = D.GAKO_KBN '; 
            VSQLSEL := VSQLSEL || 'AND  D.IDO_KBN IN (1,2,3) )  ';
            VSQLSEL := VSQLSEL || ') B  ';
            VSQLSEL := VSQLSEL || 'WHERE ';
            VSQLSEL := VSQLSEL || '    A.GAKO_CD   = B.GAKO_CD  ';
            VSQLSEL := VSQLSEL || 'AND A.GAKO_KBN  = B.GAKO_KBN ';
            VSQLSEL := VSQLSEL || 'ORDER BY A.GAKO_CD,A.GAKO_KBN,B.IDO_KBN,B.GAKUNEN,B.IDOBI,B.SHIMEI_KANA ';
            OPEN CRATENA2  FOR VSQLSEL;
            LOOP
               FETCH  CRATENA2 INTO CRATENA_WORK2;
               EXIT WHEN CRATENA2%NOTFOUND;
               ICNT := ICNT+1;
--  2024/09/03 ZCZL.WANGMING ADD 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00100の対応
               NCSVSHUTURYOKU_COUNT := NCSVSHUTURYOKU_COUNT+1;
               COUNT1 := CRATENA_WORK2.GAKUNEN1_TENNYU_CNT - CRATENA_WORK2.GAKUNEN1_TENGAKU_CNT - CRATENA_WORK2.GAKUNEN1_TAIGAKU_CNT;
               COUNT2 := CRATENA_WORK2.GAKUNEN2_TENNYU_CNT - CRATENA_WORK2.GAKUNEN2_TENGAKU_CNT - CRATENA_WORK2.GAKUNEN2_TAIGAKU_CNT;
               COUNT3 := CRATENA_WORK2.GAKUNEN3_TENNYU_CNT - CRATENA_WORK2.GAKUNEN3_TENGAKU_CNT - CRATENA_WORK2.GAKUNEN3_TAIGAKU_CNT;
               IF CRATENA_WORK2.GAKO_KBN <> 2 THEN
                   COUNT4 := CRATENA_WORK2.GAKUNEN4_TENNYU_CNT - CRATENA_WORK2.GAKUNEN4_TENGAKU_CNT - CRATENA_WORK2.GAKUNEN4_TAIGAKU_CNT;
                   COUNT5 := CRATENA_WORK2.GAKUNEN5_TENNYU_CNT - CRATENA_WORK2.GAKUNEN5_TENGAKU_CNT - CRATENA_WORK2.GAKUNEN5_TAIGAKU_CNT;
                   COUNT6 := CRATENA_WORK2.GAKUNEN6_TENNYU_CNT - CRATENA_WORK2.GAKUNEN6_TENGAKU_CNT - CRATENA_WORK2.GAKUNEN6_TAIGAKU_CNT;
                   COUNTALL := COUNT1+COUNT2+COUNT3+COUNT4+COUNT5+COUNT6;
               ELSE
                   COUNT4 := NULL;
                   COUNT5 := NULL;
                   COUNT6 := NULL;
                   COUNTALL := COUNT1+COUNT2+COUNT3;
               END IF;
               
               r_CHOHYO_001                           := NULL;
               r_CHOHYO_001.NO                        := ICNT;                                                         --ソート順
               r_CHOHYO_001.NENDO                     := NENMON;                                                       --年度
               r_CHOHYO_001.GAKKO_KBN                 := CRATENA_WORK2.GAKO_KBN;                                       --学校区分
               r_CHOHYO_001.GAKKO_CD                  := CRATENA_WORK2.GAKO_CD;                                        --学校コード
               r_CHOHYO_001.GAKKO_MEI                 := CRATENA_WORK2.GAKOMEI;                                        --学校名
               r_CHOHYO_001.GAKUNEN1_TENNYU_CNT       := CRATENA_WORK2.GAKUNEN1_TENNYU_CNT;                            --１年 転入者人数
               r_CHOHYO_001.GAKUNEN2_TENNYU_CNT       := CRATENA_WORK2.GAKUNEN2_TENNYU_CNT;                            --２年 転入者人数
               r_CHOHYO_001.GAKUNEN3_TENNYU_CNT       := CRATENA_WORK2.GAKUNEN3_TENNYU_CNT;                            --３年 転入者人数
               IF CRATENA_WORK2.GAKO_KBN <> 2 THEN
                    r_CHOHYO_001.GAKUNEN4_TENNYU_CNT  := CRATENA_WORK2.GAKUNEN4_TENNYU_CNT;                            --４年 転入者人数
                    r_CHOHYO_001.GAKUNEN5_TENNYU_CNT  := CRATENA_WORK2.GAKUNEN5_TENNYU_CNT;                            --５年 転入者人数
                    r_CHOHYO_001.GAKUNEN6_TENNYU_CNT  := CRATENA_WORK2.GAKUNEN6_TENNYU_CNT;                            --６年 転入者人数
               ELSE
                    r_CHOHYO_001.GAKUNEN4_TENNYU_CNT  := '';                                                           --４年 転入者人数
                    r_CHOHYO_001.GAKUNEN5_TENNYU_CNT  := '';                                                           --５年 転入者人数
                    r_CHOHYO_001.GAKUNEN6_TENNYU_CNT  := '';                                                           --６年 転入者人数
               END IF;
               r_CHOHYO_001.ALL_TENNYU_CNT            := CRATENA_WORK2.ALL_TENNYU_CNT;                                 --合計 転入者人数
               r_CHOHYO_001.GAKUNEN1_TENGAKU_CNT      := CRATENA_WORK2.GAKUNEN1_TENGAKU_CNT;                           --１年 転出者人数
               r_CHOHYO_001.GAKUNEN2_TENGAKU_CNT      := CRATENA_WORK2.GAKUNEN2_TENGAKU_CNT;                           --２年 転出者人数
               r_CHOHYO_001.GAKUNEN3_TENGAKU_CNT      := CRATENA_WORK2.GAKUNEN3_TENGAKU_CNT;                           --３年 転出者人数
               IF CRATENA_WORK2.GAKO_KBN <> 2 THEN
                    r_CHOHYO_001.GAKUNEN4_TENGAKU_CNT := CRATENA_WORK2.GAKUNEN4_TENGAKU_CNT;                           --４年 転出者人数
                    r_CHOHYO_001.GAKUNEN5_TENGAKU_CNT := CRATENA_WORK2.GAKUNEN5_TENGAKU_CNT;                           --５年 転出者人数
                    r_CHOHYO_001.GAKUNEN6_TENGAKU_CNT := CRATENA_WORK2.GAKUNEN6_TENGAKU_CNT;                           --６年 転出者人数
               ELSE
                    r_CHOHYO_001.GAKUNEN4_TENGAKU_CNT := '';                                                           --４年 転出者人数
                    r_CHOHYO_001.GAKUNEN5_TENGAKU_CNT := '';                                                           --５年 転出者人数
                    r_CHOHYO_001.GAKUNEN6_TENGAKU_CNT := '';                                                           --６年 転出者人数
               END IF;
               r_CHOHYO_001.ALL_TENGAKU_CNT           := CRATENA_WORK2.ALL_TENGAKU_CNT;                                --合計 転出者人数
               r_CHOHYO_001.GAKUNEN1_TAIGAKU_CNT      := CRATENA_WORK2.GAKUNEN1_TAIGAKU_CNT;                           --１年 退学者人数
               r_CHOHYO_001.GAKUNEN2_TAIGAKU_CNT      := CRATENA_WORK2.GAKUNEN2_TAIGAKU_CNT;                           --２年 退学者人数
               r_CHOHYO_001.GAKUNEN3_TAIGAKU_CNT      := CRATENA_WORK2.GAKUNEN3_TAIGAKU_CNT;                           --３年 退学者人数
               IF CRATENA_WORK2.GAKO_KBN <> 2 THEN
                    r_CHOHYO_001.GAKUNEN4_TAIGAKU_CNT := CRATENA_WORK2.GAKUNEN4_TAIGAKU_CNT;                           --４年 退学者人数
                    r_CHOHYO_001.GAKUNEN5_TAIGAKU_CNT := CRATENA_WORK2.GAKUNEN5_TAIGAKU_CNT;                           --５年 退学者人数
                    r_CHOHYO_001.GAKUNEN6_TAIGAKU_CNT := CRATENA_WORK2.GAKUNEN6_TAIGAKU_CNT;                           --６年 退学者人数
               ELSE
                    r_CHOHYO_001.GAKUNEN4_TAIGAKU_CNT := '';                                                           --４年 退学者人数
                    r_CHOHYO_001.GAKUNEN5_TAIGAKU_CNT := '';                                                           --５年 退学者人数
                    r_CHOHYO_001.GAKUNEN6_TAIGAKU_CNT := '';                                                                --６年 退学者人数
               END IF;
               r_CHOHYO_001.ALL_TAIGAKU_CNT           := CRATENA_WORK2.ALL_TAIGAKU_CNT;                                --合計 退学者人数
               r_CHOHYO_001.COUNT1                    := COUNT1;                                                       --１年 差引人数
               r_CHOHYO_001.COUNT2                    := COUNT2;                                                       --２年 差引人数
               r_CHOHYO_001.COUNT3                    := COUNT3;                                                       --３年 差引人数
               r_CHOHYO_001.COUNT4                    := COUNT4;                                                       --４年 差引人数
               r_CHOHYO_001.COUNT5                    := COUNT5;                                                       --５年 差引人数
               r_CHOHYO_001.COUNT6                    := COUNT6;                                                       --６年 差引人数
               r_CHOHYO_001.ALL_SASHIHIKI_CNT         := COUNTALL;                                                     --合計 差引人数
               r_CHOHYO_001.GAKUNEN1_GETUMATU_CNT     := CRATENA_WORK2.GAKUNEN1_GETUMATU_CNT;                          --１年 月末人数
               r_CHOHYO_001.GAKUNEN2_GETUMATU_CNT     := CRATENA_WORK2.GAKUNEN2_GETUMATU_CNT;                          --２年 月末人数
               r_CHOHYO_001.GAKUNEN3_GETUMATU_CNT     := CRATENA_WORK2.GAKUNEN3_GETUMATU_CNT;                          --３年 月末人数
               IF CRATENA_WORK2.GAKO_KBN <> 2 THEN
                    r_CHOHYO_001.GAKUNEN4_GETUMATU_CNT := CRATENA_WORK2.GAKUNEN4_GETUMATU_CNT;                         --４年 月末人数
                    r_CHOHYO_001.GAKUNEN5_GETUMATU_CNT := CRATENA_WORK2.GAKUNEN5_GETUMATU_CNT;                         --５年 月末人数
                    r_CHOHYO_001.GAKUNEN6_GETUMATU_CNT := CRATENA_WORK2.GAKUNEN6_GETUMATU_CNT;                         --６年 月末人数
               ELSE
                    r_CHOHYO_001.GAKUNEN4_GETUMATU_CNT := '';                                                          --４年 月末人数
                    r_CHOHYO_001.GAKUNEN5_GETUMATU_CNT := '';                                                          --５年 月末人数
                    r_CHOHYO_001.GAKUNEN6_GETUMATU_CNT := '';                                                          --６年 月末人数
               END IF;
               r_CHOHYO_001.ALL_GETUMATU_CNT          := CRATENA_WORK2.ALL_GETUMATU_CNT;                               --合計 月末人数
               IF CRATENA_WORK2.IDO_KBN =1 THEN
                    r_CHOHYO_001.IDO_KBN              := '転入';                                                        --異動区分
               ELSIF CRATENA_WORK2.IDO_KBN =2 THEN
                    r_CHOHYO_001.IDO_KBN              := '転出';                                                        --異動区分
               ELSIF CRATENA_WORK2.IDO_KBN =3 THEN
                    r_CHOHYO_001.IDO_KBN              := '退学';                                                        --異動区分
               ELSE
                    r_CHOHYO_001.IDO_KBN              := '';                                                           --異動区分      
               END IF;
               r_CHOHYO_001.GAKUNEN                   := CRATENA_WORK2.GAKUNEN;                                        --学年                                                                    
               IF CRATENA_WORK2.IDOBI IS NOT NULL THEN
                  r_CHOHYO_001.IDO_BI                 := SUBSTR(TO_CHAR(CRATENA_WORK2.IDOBI),5,2) || '/' || SUBSTR(TO_CHAR(CRATENA_WORK2.IDOBI),7,2);  --異動日
               ELSE
                  r_CHOHYO_001.IDO_BI                 := CRATENA_WORK2.IDOBI;
               END IF;
               r_CHOHYO_001.JINKAKU_KBN               := CRATENA_WORK2.JINKAKU_KBN;
               r_CHOHYO_001.BREAK_NO                  := NULL;                                                         -- 改ページキー
               r_CHOHYO_001.WSNUM                     := g_sWSNUM;                                                     -- 端末番号
               r_CHOHYO_001.BATCHKBN                  := c_BATCH;                                                      -- 即時バッチ区分
               r_CHOHYO_001.JOBNUM                    := g_nJOBNUM;                                                    -- ジョブNO
               --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 Start
               --r_CHOHYO_001.SHIMEI_KANA               := SHIMEI_KANA ;
               --r_CHOHYO_001.SHIMEI_KANJI              := SHIMEI_KANJI ;
               r_CHOHYO_001.SHIMEI_KANA               := CRATENA_WORK2.SHIMEI_KANA; 
               r_CHOHYO_001.SHIMEI_KANJI              := CRATENA_WORK2.SHIMEI_KANJI;               
               --  2024/11/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:本名制御仮対応IT_GKB_00613の対応 End
               -- １レコードのイメージをセット
               INSERT INTO GKBWL360R001 VALUES r_CHOHYO_001;
               FRET := c_ISUCCESS;       -- 正常終了
            END LOOP;
            IF CRATENA2%ISOPEN THEN
              CLOSE CRATENA2;
            END IF;
            RETURN FRET;
        EXCEPTION
            WHEN OTHERS THEN
              IF CRATENA2%ISOPEN THEN
                CLOSE CRATENA2;
              END IF;
              FRET := c_INOT_SUCCESS2; -- 異常終了
        END;
        -- 終了
        RETURN FRET;
    EXCEPTION
        /* その他エラー */
        WHEN OTHERS THEN
             FRET := c_INOT_SUCCESS2;     -- 異常終了
             RETURN FRET;
    END FUNC_GET_JIDO_WK_CSV;

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        ERR              EXCEPTION;
        --  2024/06/04 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
        nRTN             NUMBER;
        vERRMSG          NVARCHAR2(1000);
        --  2024/06/04 ZCZL.ZHANGLEI ADD END
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        
        -- 処理・ソート条件のワーク領域を初期化
        --  2024/06/04 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
--  2024/09/03 ZCZL.WANGMING DELETE 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00100の対応
--        nRTN := KKAPK3000.FTRUNCATE('GKBWL360R001',vERRMSG);
        g_aSHIMEIJKN_CHOHYOPRM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB','SHIMEIJKN_CHOHYO','0000',1,g_aSHIMEIJKN_CHOHYOPRM);
        IF nRTN = 0 THEN
          FOR i IN 1..g_aSHIMEIJKN_CHOHYOPRM.COUNT LOOP
            IF g_aSHIMEIJKN_CHOHYOPRM(i) = 'GKB360R001' THEN
              g_nGKB360_INDEX := i;
            END IF;
          END LOOP;
        END IF;
        --本名・通称名　出力制御
        g_aSHIMEIPRM := A_CONS_PRM();
        nRTN := KKAPK0030.FCTGetR('GKB','EQSHIMEI','0000',0,g_aSHIMEIPRM);
        IF nRTN = 0 THEN
          g_vGKB360_CTL := g_aSHIMEIPRM(g_nGKB360_INDEX);
        END IF;
        --  2024/06/04 ZCZL.ZHANGLEI ADD END
          
        -- システム日付を西暦数値（YYYYMMDD形式）にする
        ISAKUSEIBI := TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));
        -- 取得した条件をそれぞれの変数へセット
        VNENDO        := V_JYOUKEN01;           -- 抽出年月
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
        --I_RTN := GKBPK00010.FGKOCDTR(V_JYOUKEN02,VSYOGAKO_CD);   --小学校コード
        --I_RTN := GKBPK00010.FGKOCDTR(V_JYOUKEN03,VTYUGAKO_CD);   --中学校コード
        --I_RTN := GKBPK00010.FGKOCDTR(V_JYOUKEN04,VKUIKIGAI_CD);  --区域外学校コード
        --I_RTN := GKBPK00010.FGKOCDTR(V_JYOUKEN05,VYOGOGAKO_CD);  --盲聾養護学校コード
        --I_RTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN06,g_vKUNISHIRITSU_CD);  -- 国・私立学校コード
        bRTN := FUNC_GET_GAKOCD(V_JYOUKEN02,VSYOGAKO_CD);   --小学校コード
        bRTN := FUNC_GET_GAKOCD(V_JYOUKEN03,VTYUGAKO_CD);   --中学校コード
        bRTN := FUNC_GET_GAKOCD(V_JYOUKEN04,VKUIKIGAI_CD);  --区域外学校コード
        bRTN := FUNC_GET_GAKOCD(V_JYOUKEN05,VYOGOGAKO_CD);  --盲聾養護学校コード
        --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 START
        --bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN06,g_vKUNISHIRITSU_CD);  -- 国・私立学校コード
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN06,VKUNISHIRITSU_CD);  -- 国・私立学校コード
        --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.007:IT_GKB_00646の対応 END
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.003:学校コードリスト仕様変更IT_GKB_00090の対応
        o_SHIMEIPRM := A_CONS_PRM();
        I_RTN := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,o_SHIMEIPRM,o_LENGTH);
        IF I_RTN = 1 THEN
                      o_SHIMEIPRM := A_CONS_PRM();
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(1) := 0;
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(2) := 0;
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(3) := 0;
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(4) := 0;
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(5) := 0;
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(6) := 0;
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(7) := 0;
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(8) := 0;
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(9) := 0;
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(10) := 0;
        ELSE
          WHILE (o_LENGTH < 11) LOOP   
            o_SHIMEIPRM.EXTEND;
            o_SHIMEIPRM(o_LENGTH+1) := 0;
            o_LENGTH := o_LENGTH + 1;
          END LOOP;
        END IF;
        -- 中間ファイル(GKBWTENNYUSHUTSU)のクリアを行う
        I_RTN := KKAPK3000.FTRUNCATE(c_VGTABLE, VSQLERRM);
        IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '中間テーブルの初期化処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE ERR;
        END IF;
        --抽出年月のチェック
        IF LENGTH(VNENDO) <> 5 THEN
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '抽出年月の入力が正しくありません。', g_sTANTOCODE, g_sWSNUM, 1);
            RAISE ERR;
        ELSE
            IWAREKIHIDUKEIO  := TO_NUMBER(VNENDO || '01');
            ISEIREKIHIDUKEIO := 0;
            B_RTN := KKAPK0020.FDAYEDIT(IWAREKIHIDUKEIO, ISEIREKIHIDUKEIO,
                                        VEDIT1O, VEDIT2O, VEDIT3O,
                                        VGENGOKANJIO, VGENGOKIGOO,
                                        IWAREKINENO, ISEIREKINENO,
                                        IWAREKINENGETUO, ITUKIO, IDAYO,
                                        IWAREKIHIDUKEO, ISEIREKIHIDUKEO);
            IF B_RTN = c_BERROR THEN
               B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '抽出年月の入力が正しくありません。', g_sTANTOCODE, g_sWSNUM, 1);
               RAISE ERR;
            END IF;
        END IF;
        --データ抽出処理
        I_RTN := FUNC_GET_JIDO_WK;
        IF I_RTN <> c_ISUCCESS THEN
           IF I_RTN = c_INOT_SUCCESS2 THEN
                  B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '中間データ作成処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
                  RAISE ERR;
           END IF;
           IF I_RTN = c_INOT_SUCCESS THEN
                  B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '中間データ編集処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
                  RAISE ERR;
           END IF;
           IF I_RTN = c_INOT_SUCCESS3 THEN
                  B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '転入・転出等児童生徒一覧作成処理が正常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
                  RAISE ERR;
           END IF;
        END IF;
--  2024/09/03 ZCZL.WANGMING ADD START 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00100の対応
        KENSUU_COUNT := GKBFKTBLCNT('GKBWTENNYUSHUTSU', NULL);
        IF KENSUU_COUNT = -1 THEN
          RAISE ERR;
        END IF;
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(KENSUU_COUNT,'入力　'||'転入・転出対象件数',1);
--  2024/09/03 ZCZL.WANGMING ADD END
        -- ＣＳＶ用
        I_RTN := FUNC_GET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
            IF I_RTN = c_INOT_SUCCESS THEN
                 B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '中間データ出力処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
                 RAISE ERR;
            END IF;
            IF I_RTN = c_INOT_SUCCESS2 THEN
                 B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', '転入・転出等児童生徒一覧ＣＳＶデータ作成処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
                 RAISE ERR;
            END IF;
        END IF;
--  2024/09/03 ZCZL.WANGMING ADD START 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00100の対応
        --変数のクリア
        KENSUU_COUNT := 0;
        --変数.件数カウント :=　変数.CSV出力件数
        KENSUU_COUNT := NCSVSHUTURYOKU_COUNT;
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(KENSUU_COUNT,'出力　'||'転入・転出ＣＳＶ',2);
        --変数のクリア
        --変数.件数カウント :=　0
--  2024/11/21 JPJYS.LIUHUAIQI DELETE 0.3.000.005:IT_GKB_00619対応 Start
--        KENSUU_COUNT := 0;
        --変数.CSV出力件数 :=　0
--        NCSVSHUTURYOKU_COUNT := 0;
--  2024/11/21 JPJYS.LIUHUAIQI DELETE 0.3.000.005:IT_GKB_00619対応 End
--  2024/09/03 ZCZL.WANGMING ADD END
        --帳票出力CSVの作成
        bRTN := FUNC_B11CSV('GKBWL360R001');

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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/04
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
END GKBPB00410;
/