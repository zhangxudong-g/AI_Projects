CREATE OR REPLACE PACKAGE BODY GKBPB00390
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 入学・進級・卒業者一覧作成
--  機能概要      : 小学校入学者一覧、中学校入学者一覧、中学校卒業者一覧を作成する
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
--------------------------------------------------------
--  変更履歴
--  2024/06/04 ZCZL.GUANHONG Update 0.3.000.000:新WizLIFE２次開発
--  2024/09/06 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00429対応横展開
--  2024/11/06 ZCZL.ZHANGLEI UPDATE 0.3.000.003:IT_GKB_00463対応
--  2024/11/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00620対応
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.005:IT_GKB_00621対応
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
--  2024/06/04 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
    g_aSHIMEIJKN_CHOHYOPRM        A_CONS_PRM;                  --「外国人　氏名・生年月日制御帳票(ID)」のリスト
    g_aEQSHIMEIPRM                A_CONS_PRM;                  --「本名・通称名　出力制御」のリスト
    g_nGKBPB00390_INDEX           NUMBER;                      --入学通知書_インデックス番号
    g_vGKBPB00390_CTL             NVARCHAR2(1000);             --入学通知書_出力制御
    g_nKENSAKU                      NUMBER := 0;                     --件数
    g_nCSVKENSAKU                   NUMBER := 0;                     --CSV件数
-- 2024/06/04 ZCZL.GUANHONG Add end
    g_nTIME NUMBER;  --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;
    nCOUNT        NUMBER := 0;
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
        CURSOR CJIDO IS
    SELECT KOJIN_NO,
           GAKUNEN_CD
    FROM GKBTGAKUNENLNK;
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
        -- ERROR関連 --
    -- デバック
        N_SQL_CODE      NUMBER;             -- SQLエラーコード
        V_SQL_MSG       NVARCHAR2(255);     -- SQLエラーメッセージ
        c_BERROR        CONSTANT  BOOLEAN :=  FALSE;
        c_BERR          CONSTANT  BOOLEAN :=  FALSE;
        -- 処理結果
        c_ISUCCESS      CONSTANT  PLS_INTEGER := 0;         -- 正常
        c_INOT_SUCCESS  CONSTANT  PLS_INTEGER := -1;        -- 異常
        c_INOTFOUND     CONSTANT  PLS_INTEGER := -9;        -- 該当なし
        -- 戻り値
        c_IOK           CONSTANT  PLS_INTEGER := 0;         -- 正常
        c_IERR          CONSTANT  PLS_INTEGER := 1;         --異常
        c_VNOTHING      CONSTANT  NVARCHAR2(128) := '@@@NOTHING@@@';
        -- 処理条件数
        c_IJOKEN        CONSTANT  PLS_INTEGER := 20;        -- 処理条件取得処理から取得される項目は２０個
        -- ソート条件数
        c_ISORT         CONSTANT  PLS_INTEGER := 15;        -- ソート条件取得処理から取得される項目は１５個
       
        -- 正常メッセージの値
        c_VOK_MSG01     CONSTANT  NVARCHAR2(256) := '入学・進級・卒業処理が正常終了しました。';
        -- エラーメッセージの値
        c_VERR_MSG01    CONSTANT  NVARCHAR2(256) := '入学・進級・卒業処理が異常終了しました。';
        -- 児童生徒ワーク
        c_VTABLE        CONSTANT  NVARCHAR2(128) := 'GKBWJIDOSHINKYU';
        c_VGTABLE       CONSTANT  NVARCHAR2(128) := 'GKBTGAKUREIBO';
        c_VLTABLE       CONSTANT  NVARCHAR2(128) := 'GKBTGAKUNENLNK';
        -- １頁の最大行数
        c_IMAXROWS      CONSTANT  PLS_INTEGER := 15;
       -- CSVファイル --
        -- 帳票連番（作成順序）
        c_NFILENUMBER   CONSTANT  NUMBER(2)      := 1;
        i_VMODE         CONSTANT  NVARCHAR2(255) := 'W';
        i_PFILESIZE     BINARY_INTEGER := 3000;
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
        ISAKUSEIBI         PLS_INTEGER;
        RG                 GKBTGAKUREIBO%ROWTYPE;
        RA                 GABTATENAKIHON%ROWTYPE;
        RB                 GABTATENAKIHON%ROWTYPE;
        RC                 GABTSOFUSAKI%ROWTYPE;
        RASO               GABTSOFUSAKI%ROWTYPE;
        RK                 KKATCD%ROWTYPE;
        IKOJIN_NO          NUMBER;
        IHOGOSHA_KOJIN_NO  NUMBER;
        IGAKO_CD           PLS_INTEGER;
        IMRIREKI_RENBAN    PLS_INTEGER;
        VGAKOMEI           NVARCHAR2(60);       
        VSEINENGAPI        NVARCHAR2(11);
--  2024/06/04 ZCZL.GUANHONG Update 0.3.000.000:新WizLIFE２次開発
--         VSEIBETSU          NVARCHAR2(2);
        VSEIBETSU          NVARCHAR2(4);
--  2024/06/04 ZCZL.GUANHONG Update 0.3.000.000:新WizLIFE２次開発
--        VSETAI_NO          NVARCHAR2(7);
        VSETAI_NO          NVARCHAR2(15);
        VGYOSEIKU_MEI      NVARCHAR2(20);
        VHAN_MEI           NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00429対応横展開
--        VSANTEIDANTAI_MEI  NVARCHAR2(20);
        VSANTEIDANTAI_MEI  GKBWJIDOSHINKYU.SANTEIDANTAIMEI%TYPE;
        VHYOUJINENDO       NVARCHAR2(10);
        VSASKUSEIBI        NVARCHAR2(30);
        VHOGOSHA_SHIMEI_JODAN     NVARCHAR2(100);
        VHOGOSHA_SHIMEI_GEDAN     NVARCHAR2(100);
        VJUSHO_JODAN       NVARCHAR2(30);
        VJUSHO_GEDAN       NVARCHAR2(30);
        VCNT               NVARCHAR2(6);
        VZOKUGARAMEI1      NVARCHAR2(30);
        VZOKUGARAMEI2      NVARCHAR2(30);
        VGAKUNENMEI        NVARCHAR2(20);
        NGAKUNENSEI        NUMBER;
        VGAKUNENSEI        NVARCHAR2(20);
        IKAISISEINENGAPI   PLS_INTEGER;
        VKAISISEINENGAPI   NVARCHAR2(14);
        ISHURYOSEINENGAPI  PLS_INTEGER;
        VSHURYOSEINENGAPI  NVARCHAR2(14);
        IHOGOSHA_ZOKUGARA1 PLS_INTEGER;
        IJUMIN_NARU_JIYU   PLS_INTEGER;
        IJUMIN_NARU        PLS_INTEGER;
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
        IICHIRAN_CD        PLS_INTEGER;
        VICHIRANMEI        NVARCHAR2(12);
        VHYOJI_SHONYUBI    NVARCHAR2(18);
        VHYOJI_SHOSOBI     NVARCHAR2(18);
        VHYOJI_CHUNYUBI    NVARCHAR2(18);
        VHYOJI_CHUSOBI     NVARCHAR2(18);
        VHIDARI            NVARCHAR2(40);
        VMIGI              NVARCHAR2(40);
        VBIKO              NVARCHAR2(60);           
        -- 関数用戻り値変数（外部関数からの戻り値をセット）
        BRTN               BOOLEAN;
        B_RTN              BOOLEAN;
        I_RTN              PLS_INTEGER;
        -- 処理条件（画面からの引数）
        VNENDO             NVARCHAR2(15);      -- 対象年度
        VGAKUNEN           NVARCHAR2(15);      -- 学年
        VSYURYOGAKUNEN     NVARCHAR2(15);      -- 終了学年
        -- 処理条件の取得用変数
        TYPE MTJOKEN_TYPE IS TABLE OF NVARCHAR2(15) INDEX BY BINARY_INTEGER;  -- 処理条件の値の配列宣言
        o_MJYOUKEN      MTJOKEN_TYPE;
        o_NBREAK         NUMBER(2) := 0;
        -- 取得したデータのワーク領域
        TYPE MTJIDO_TYPE IS TABLE OF GKBWJIDOSHINKYU%ROWTYPE INDEX BY BINARY_INTEGER;
        MJIDO_WORK MTJIDO_TYPE;
        TYPE MTGAKUREIBO_TYPE IS TABLE OF GKBTGAKUREIBO%ROWTYPE INDEX BY BINARY_INTEGER;
        MGAKUREIBO_WORK MTGAKUREIBO_TYPE;
        TYPE MTGAKUNEN_LNK_TYPE IS TABLE OF GKBTGAKUNENLNK%ROWTYPE INDEX BY BINARY_INTEGER;
        MGAKUNEN_LNK_WORK MTGAKUNEN_LNK_TYPE;
        -- ソート条件のレコード
        TYPE MTORDER_REC IS RECORD
        (
            ID      NUMBER(2),              -- 番号（基本的には配列値に１加算された値）
            NAME    NVARCHAR2(100),         -- 項目名
            P_NAME  NVARCHAR2(100),         -- 改頁項目名
            BIKO    NVARCHAR2(100)          -- 備考（日本語名）
        );
        -- ソート条件のワーク領域
        TYPE MTORDER_TYPE IS TABLE OF MTORDER_REC INDEX BY BINARY_INTEGER;
        MORDER_WORK MTORDER_TYPE;
        -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
        BRTNSEINENGAPI                  BOOLEAN;
        IWAREKIHIZUKE                  PLS_INTEGER;
        io_SEIREKIHIZUKE               PLS_INTEGER;
        VEDIT_GYYMMDD1                 NVARCHAR2(20);
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
        VSQLERRM         NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
        VPAGENM          NVARCHAR2(500);    -- 改頁項目名
        VPAGEFD          NVARCHAR2(500);    -- 改頁項目値
       BPRMFLG_001      BOOLEAN;
       BPRMFLG_002      BOOLEAN;
       BPRMFLG_003      BOOLEAN;
       BPRMFLG_004      BOOLEAN;
       o_YMD2           NVARCHAR2(30);
       N_NAIYO_CD       GKBTSHIMEIJKN.NAIYO_CD%TYPE;
       o_SHIMEIPRM      A_CONS_PRM;   --宛先の氏名出力制御
       o_LENGTH         NUMBER;
--2024/06/03 ZCZL.GUANHONG ADD START 0.3.000.000:新WizLIFE２次開発
      o_vSHIMEIKANA        GABTATENAKIHON.TSUSHOMEI_KANA%TYPE;
      o_vSHIMEIKANJI       GABTATENAKIHON.TSUSHOMEI_KANJI%TYPE;
      --  2024/11/06 ZCZL.ZHANGLEI UPDATE 0.3.000.003:IT_GKB_00463対応
      --o_vBIRTHDAY          GABTATENAKIHON.WAREKI_SEINENGAPI%TYPE;
      o_vBIRTHDAY          GABTATENAKIHON.HYOJI_SEINENGAPI%TYPE;
-- 2024/06/04 ZCZL.GUANHONG ADD end
    --パラメータ変数
      g_JYOUKEN01   NVARCHAR2(1000);     
      g_JYOUKEN02   NVARCHAR2(1000);     
      g_JYOUKEN03   NVARCHAR2(1000);     
      g_JYOUKEN04   NVARCHAR2(1000);     
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
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
    BEGIN
        --小学校入学年月日
        g_JYOUKEN01  := KKBPK5551.GETPARMS(g_nJOBNUM,'txtShogakkoNyugakuYMD');
        --小学校卒業年月日
        g_JYOUKEN02  := KKBPK5551.GETPARMS(g_nJOBNUM,'txtShogakkoSotsugyoYMD');
        --中学校入学年月日
        g_JYOUKEN03  := KKBPK5551.GETPARMS(g_nJOBNUM,'txtChugakkoNyugakuYMD');
        --中学校卒業年月日
        g_JYOUKEN04  := KKBPK5551.GETPARMS(g_nJOBNUM,'txtChugakkoSotsugyoYMD');
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
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
        g_oKENSU_LIST.EXTEND(2);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.005:IT_GKB_00621対応 Start
--        g_oKENSU_LIST(1) :=GKBEKENSU_RECORD(g_nKENSAKU,'入力 就学校変更満了通知書対象件数',1);
        g_oKENSU_LIST(1) :=GKBEKENSU_RECORD(g_nKENSAKU,'入力 入学・卒業者一覧対象件数',1);
--        g_oKENSU_LIST(2) :=GKBEKENSU_RECORD(g_nCSVKENSAKU,'出力 就学校変更満了通知書ＣＳＶ',2);
        g_oKENSU_LIST(2) :=GKBEKENSU_RECORD(g_nCSVKENSAKU,'出力 入学・卒業者一覧ＣＳＶ',2);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.005:IT_GKB_00621対応 End
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
    --------------------------------------------------------------------------------
    -- 制御のフラグをセットするのを行う
    --------------------------------------------------------------------------------
--  2024/06/04 ZCZL.GUANHONG Delete Start 0.3.000.000:新WizLIFE２次開発
    /*FUNCTION FUNC_PRMFLGSET(i_KOJIN_NO IN NUMBER,o_NAIYO_CD OUT NUMBER) RETURN NUMBER IS
      NODATAFOUND_FLG    BOOLEAN;
      ZERO_FLG           BOOLEAN;
    BEGIN
      --フラグ初期化
      BPRMFLG_001      := FALSE;
      BPRMFLG_002      := FALSE;
      BPRMFLG_003      := FALSE;
      BPRMFLG_004      := FALSE;
      NODATAFOUND_FLG    := FALSE;
      ZERO_FLG           := FALSE;
      --本名使用制御管理情報の取得
      BEGIN
        SELECT NAIYO_CD
          INTO o_NAIYO_CD
          FROM GKBTSHIMEIJKN
         WHERE KOJIN_NO = i_KOJIN_NO
           AND CHOHYO_ID = 'GKB220R001';   
        IF o_NAIYO_CD = 0 THEN
          ZERO_FLG  := TRUE;
        END IF;
      EXCEPTION
        --データを取得しない場合
        WHEN NO_DATA_FOUND THEN
        NODATAFOUND_FLG  := TRUE;
      END;
      --氏名印字.制御ﾊﾟﾗﾒｰﾀ(11)が1の場合
      IF o_SHIMEIPRM(11) = 1 THEN
        BPRMFLG_001  := TRUE;
      END IF;
      --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(11)が4、6場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(11) IN (4, 6) THEN
          BPRMFLG_002  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在する、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(11)が3、4、5、6場合
      IF NOT NODATAFOUND_FLG AND NOT ZERO_FLG THEN
        IF o_SHIMEIPRM(11) IN(3,4,5,6) THEN
          BPRMFLG_003  := TRUE;
        END IF;
      END IF;
        -- 本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(11)が4、5場合「生年月日」
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(11) IN (4, 5) THEN
          BPRMFLG_004  := TRUE;
        END IF;
      END IF;
    RETURN 0;
    END;
    --------------------------------------------------------------------------------
    -- 制御を行う
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SEIGYO_SET(i_HONMYO IN NVARCHAR2,i_SHIMEI IN NVARCHAR2, o_SET OUT NVARCHAR2) RETURN NUMBER
    IS
    BEGIN
      -- HONMYO_KANAをセット
      IF BPRMFLG_001 OR BPRMFLG_002 THEN
        o_SET := NVL(trim(i_HONMYO),i_SHIMEI);
      END IF;
      -- 本名使用制御管理情報の設定で編集
      IF BPRMFLG_003 THEN
        IF N_NAIYO_CD IN(11,12) THEN
          o_SET := NVL(trim(i_SHIMEI),i_HONMYO);
        ELSIF N_NAIYO_CD IN(21,22) THEN
          o_SET := NVL(trim(i_HONMYO),i_SHIMEI);
        END IF;
      END IF;
      --SHIMEI_KANAをセット
      IF NOT BPRMFLG_001 AND NOT BPRMFLG_002 AND NOT BPRMFLG_003 THEN
        o_SET := NVL(trim(i_SHIMEI),i_HONMYO);
      END IF;
      RETURN 0;
    END;*/
-- 2024/06/04 ZCZL.GUANHONG Delete end
    --------------------------------------------------------------------------------
    -- 児童生徒中間（GKBWJIDOSHINKYU）レコードの取得
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        IFRET                PLS_INTEGER;                -- 戻り値
        NNENDO              PLS_INTEGER;                -- 年度
        NGAKUNEN_CD              NUMBER;                -- 学年コード
        NSYURYOGAKUNEN_CD   NUMBER;                     -- 終了学年コード
        IRTNA               PLS_INTEGER;
        IRTNSANTEIDANTAI    PLS_INTEGER;
        IRTNAH              PLS_INTEGER;
        ICNT                BINARY_INTEGER;             -- 戻り値
        BRTNSASKUSEIBI      BOOLEAN;
        IJUSHO_NAGASA       PLS_INTEGER;
        ISHIMEINAGASA       PLS_INTEGER;
        IRTNZOKUGARA1        PLS_INTEGER;
        IRTNZOKUGARAHERR1    PLS_INTEGER;
        IRTNZOKUGARA2        PLS_INTEGER;
        IRTNZOKUGARAHERR2    PLS_INTEGER;
        NPRTN                NUMBER;
        IRTN                 PLS_INTEGER;
        BRTN                 BOOLEAN;
        n_YYYY               PLS_INTEGER;
        n_MM                 PLS_INTEGER;
        n_DD                 PLS_INTEGER;
--  2024/09/06 ZCZL.WANGMING ADD START 0.3.000.001:8月1日認識合わせの横展開
        sMEISHO                         NVARCHAR2(1000);                       --名称
        sMEISHOKANA                     NVARCHAR2(1000);                       --名称カナ
        sYOBI                           NVARCHAR2(1000);                       --予備
--  2024/09/06 ZCZL.WANGMING ADD END
    BEGIN
        IFRET := c_INOTFOUND;                 -- 該当なし
        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        MGAKUREIBO_WORK.DELETE;
        MGAKUNEN_LNK_WORK.DELETE;
        ICNT := 0;
        ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        ISHONYUBI := TO_NUMBER(VSHONYUBI);
        ISEIREKI_SHONYUBI := 0;  
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
        ISEIREKI_SHOSOBI := 0;  
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
        ISEIREKI_CHUNYUBI := 0;  
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
        ISEIREKI_CHUSOBI := 0;  
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
        IWAREKIHIZUKE := 0;  
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
        BEGIN
            -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
            FOR CRJIDO IN CJIDO LOOP
                GKBSKJDOG(CRJIDO.KOJIN_NO,RG,NPRTN);
                IF RG.SAISHIN_KBN = 0 THEN
                   IF CRJIDO.GAKUNEN_CD = 1 AND
                      RG.SYOGAKO_NYUGAKU_BI = ISEIREKI_SHONYUBI THEN
                      IICHIRAN_CD := 1;
                      VICHIRANMEI := '小学校入学者';
                      BEGIN
                        SELECT SYOGAKO_CD,
                               SYOGAKOMEI
                          INTO IGAKO_CD,
                               VGAKOMEI
                          FROM GKBTSHOGAKKO
                         WHERE SYOGAKO_CD = RG.SYOGAKO_CD;
                      EXCEPTION
                                 WHEN NO_DATA_FOUND THEN
                                      DBMS_OUTPUT.PUT_LINE('該当小学校なし　'||RG.SYOGAKO_CD||' '||RG.KOJIN_NO);
                                      IGAKO_CD := RG.SYOGAKO_CD;
                      END;
                      VHIDARI := '小学校入学年月日 : '||VHYOJI_SHONYUBI;
                      VMIGI := ' ';
                      VBIKO := ' ';
                   ELSIF CRJIDO.GAKUNEN_CD = 7 AND
                         RG.TYUGAKO_NYUGAKU_BI = ISEIREKI_CHUNYUBI THEN
                         IICHIRAN_CD := 2;
                         VICHIRANMEI := '中学校入学者';
                         BEGIN
                           SELECT TYUGAKO_CD,
                                  TYUGAKOMEI
                             INTO IGAKO_CD,
                                  VGAKOMEI
                             FROM GKBTCHUGAKKO
                            WHERE TYUGAKO_CD = RG.TYUGAKO_CD;
                         EXCEPTION
                                    WHEN NO_DATA_FOUND THEN
                                         DBMS_OUTPUT.PUT_LINE('該当中学校なし　'||RG.TYUGAKO_CD||' '||RG.KOJIN_NO);
                                         IGAKO_CD := RG.TYUGAKO_CD;
                         END;
                         BEGIN
                           SELECT SYOGAKOMEI
                             INTO VBIKO
                             FROM GKBTSHOGAKKO
                            WHERE SYOGAKO_CD = RG.SYOGAKO_CD;
                         EXCEPTION
                                    WHEN NO_DATA_FOUND THEN
                                         DBMS_OUTPUT.PUT_LINE('該当小学校なし　'||RG.SYOGAKO_CD||' '||RG.KOJIN_NO);
                                         VBIKO := '小学校不明';
                         END;
                         VHIDARI := '小学校卒業年月日 : '||VHYOJI_SHOSOBI;
                         VMIGI := '中学校入学年月日 : '||VHYOJI_CHUNYUBI;
                   ELSIF CRJIDO.GAKUNEN_CD = 99 AND
                         RG.TYUGAKO_SOTSUGYO_BI = ISEIREKI_CHUSOBI THEN
                         IICHIRAN_CD := 3;
                         VICHIRANMEI := '中学校卒業者';
                         BEGIN
                           SELECT TYUGAKO_CD,
                                  TYUGAKOMEI
                             INTO IGAKO_CD,
                                  VGAKOMEI
                             FROM GKBTCHUGAKKO
                            WHERE TYUGAKO_CD = RG.TYUGAKO_CD;
                         EXCEPTION
                                    WHEN NO_DATA_FOUND THEN
                                         DBMS_OUTPUT.PUT_LINE('該当中学校なし　'||RG.TYUGAKO_CD||' '||RG.KOJIN_NO);
                                         IGAKO_CD := RG.TYUGAKO_CD;
                         END;
                         BEGIN
                           SELECT SYOGAKOMEI
                             INTO VBIKO
                             FROM GKBTSHOGAKKO
                            WHERE SYOGAKO_CD = RG.SYOGAKO_CD;
                         EXCEPTION
                                    WHEN NO_DATA_FOUND THEN
                                         DBMS_OUTPUT.PUT_LINE('該当小学校なし　'||RG.SYOGAKO_CD||' '||RG.KOJIN_NO);
                                         VBIKO := '小学校不明';
                         END;
                         VHIDARI := '中学校卒業年月日 : '||VHYOJI_CHUSOBI;
                         VMIGI := ' ';
                   ELSE
                       NULL;
                   END IF;
                   IF ( CRJIDO.GAKUNEN_CD = 1 AND
                        RG.SYOGAKO_NYUGAKU_BI = ISEIREKI_SHONYUBI )  OR
                      ( CRJIDO.GAKUNEN_CD = 7 AND
                        RG.TYUGAKO_NYUGAKU_BI = ISEIREKI_CHUNYUBI )  OR
                      ( CRJIDO.GAKUNEN_CD = 99 AND
                        RG.TYUGAKO_SOTSUGYO_BI = ISEIREKI_CHUSOBI )  THEN
                      IRTN := GAAPK0030.FGETATENA(  RG.KOJIN_NO,
                                                  'GKB',
                                                  ISAKUSEIBI,
                                                  RA,
                                                  RASO);
                      IRTN := GAAPK0030.FGETATENA(  RG.HOGOSYA_KOJIN_NO,
                                                  'GKB',
                                                  ISAKUSEIBI,
                                                  RB,
                                                  RC);
--  2024/06/04 ZCZL.GUANHONG Delete 0.3.000.000:新WizLIFE２次開発  
--       IRTN  := FUNC_PRMFLGSET(RA.KOJIN_NO,N_NAIYO_CD);
                       IWAREKIHIZUKE := 0;  
                       BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                    RA.SEINENGAPI,
                                                    VSEINENGAPI,
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
                         n_YYYY      :=     ISEIREKI_YYYY;
                         n_MM        :=     IMM;
                         n_DD        :=     IDD;
--  2024/06/04 ZCZL.GUANHONG Update Start 0.3.000.000:新WizLIFE２次開発
--                        IF RA.SEIBETSU = 1 THEN
--                           VSEIBETSU := '男';
--                        ELSIF RA.SEIBETSU = 2 THEN
--                              VSEIBETSU := '女';
--                        END IF;
--  2024/09/06 ZCZL.WANGMING DELETE START 0.3.000.001:8月1日認識合わせの横展開
--                       IF RK.ANYCODE = 1 THEN
--                          VSEIBETSU := '男';
--                       ELSIF RK.ANYCODE = 2 THEN
--                          VSEIBETSU := '女';
--                       ELSIF RK.ANYCODE = 0 THEN
--                          VSEIBETSU := '不明';
--                       ELSIF RK.ANYCODE = 9 THEN
--                          VSEIBETSU := '適用不能';
--                       END IF;
--  2024/09/06 ZCZL.WANGMING DELETE END
-- 2024/06/04 ZCZL.GUANHONG Update end
                       VSETAI_NO :=  TO_CHAR(RA.SETAI_NO);
                       VGYOSEIKU_MEI := GAAPK0030.FGYOSEIKUMEI(RA.SANTEIDANTAI_CD,RA.GYOSEIKU_CD);
                       VHAN_MEI := GAAPK0030.FHANMEI(RA.SANTEIDANTAI_CD,
                                                      RA.HAN_CD);
                       IRTN := GAAPK0030.FJICHINAME(RA.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);
                       NNENDO := TO_NUMBER(VNENDO);          -- 年度
                       VHYOUJINENDO := KKAPK0020.FNENDOEDIT(1,
                                                             NNENDO,
                                                             3);
                       IF RG.HOGOSYA_KOJIN_NO <> 0 THEN
                            IRTN := GKBFKZKGMGET(1,
                                                 RG.ZOKUGARA1,
                                                 RG.ZOKUGARA2,
                                                 RG.ZOKUGARA3,
                                                 RG.ZOKUGARA4,
                                                 VZOKUGARAMEI1,
                                                 IRTNZOKUGARAHERR1);
                            IRTN := GKBFKZKGMGET(2,
                                                 RG.HOGOSYA_ZOKUGARA1,
                                                 RG.HOGOSYA_ZOKUGARA2,
                                                 RG.HOGOSYA_ZOKUGARA3,
                                                 RG.HOGOSYA_ZOKUGARA4,
                                                 VZOKUGARAMEI2,
                                                 IRTNZOKUGARAHERR2);
                           SELECT LENGTH(SHIMEI_KANJI)
                           INTO ISHIMEINAGASA
                           FROM GABTATENAKIHON
                           WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                           IF ISHIMEINAGASA > 15 THEN
                              SELECT SUBSTR (SHIMEI_KANJI,1,15) INTO VHOGOSHA_SHIMEI_JODAN
                                FROM GABTATENAKIHON
                               WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                              SELECT SUBSTR (SHIMEI_KANJI,16) INTO VHOGOSHA_SHIMEI_GEDAN
                                FROM GABTATENAKIHON
                               WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                           ELSE
                                 VHOGOSHA_SHIMEI_JODAN := NULL;  
                                 SELECT SHIMEI_KANJI INTO VHOGOSHA_SHIMEI_GEDAN
                                   FROM GABTATENAKIHON
                                  WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                           END IF;
                       ELSE
                            RB.SHIMEI_KANA := NULL;
                            RB.SHIMEI_KANJI := NULL;
                            VZOKUGARAMEI1 := NULL;
                            VZOKUGARAMEI2 := NULL;
                            VHOGOSHA_SHIMEI_JODAN := NULL;
                            VHOGOSHA_SHIMEI_GEDAN := NULL;
                       END IF;
                       IJUSHO_NAGASA := LENGTH(RA.CHOMEI||RA.BANCHI||' '||RA.KATAGAKI);          
                       IF IJUSHO_NAGASA > 20 THEN
                          VJUSHO_JODAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,1,20);  
                          VJUSHO_GEDAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,21,20); 
                       ELSE
                          VJUSHO_JODAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,1,20);  
                          VJUSHO_GEDAN := ' ';
                       END IF;
                       MJIDO_WORK(ICNT).JIDO_KOJIN_NO := RG.KOJIN_NO;
--  2024/06/04 ZCZL.GUANHONG Update Start 0.3.000.000:新WizLIFE２次開発
--                        MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := RA.SHIMEI_KANA;
--                        MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := RA.SHIMEI_KANJI; 
                       I_RTN := GKBFKHMCTRL(CRJIDO.KOJIN_NO, g_rJSTP.CHOHYOID, '0', g_vGKBPB00390_CTL, o_vSHIMEIKANA, o_vSHIMEIKANJI, o_vBIRTHDAY);

                       MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := o_vSHIMEIKANA;
                       MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := o_vSHIMEIKANJI;
-- 2024/06/04 ZCZL.GUANHONG Update end
--  2024/06/04 ZCZL.GUANHONG Delete Start 0.3.000.000:新WizLIFE２次開発           
--                        IF RA.JINKAKU_KBN = 1 THEN
                         -- 児童氏名かな
--                          I_RTN  := FUNC_SEIGYO_SET(RA.HONMYO_KANA,RA.SHIMEI_KANA,MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
                         -- 児童氏名漢字
--                          I_RTN  := FUNC_SEIGYO_SET(RA.HONMYO_KANJI,RA.SHIMEI_KANJI,MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
--                        END IF;
-- 2024/06/04 ZCZL.GUANHONG Delete end
                       MJIDO_WORK(ICNT).SEINENGAPI := RA.SEINENGAPI;
--  2024/06/04 ZCZL.GUANHONG Update 0.3.000.000:新WizLIFE２次開発
--                        MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VSEINENGAPI;
-- 2025/01/27 JPJYS.GL UPDATE ST_GKB_TMP00012対応 start 
                       --MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := o_vBIRTHDAY;
                       MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(RA.SEINENGAPI,'YYYYMMDD'),'YYYY/MM/DD') ,3);
-- 2025/01/27 JPJYS.GL UPDATE ST_GKB_TMP00012対応 end 
--  2024/06/04 ZCZL.GUANHONG Delete Start 0.3.000.000:新WizLIFE２次開発  
--                        IF RA.JINKAKU_KBN = 1 THEN
--                          IF BPRMFLG_004 THEN
                         --GKBPK00010.GKBFYMDEDT1より取得した表示生年月日
--                            I_RTN := GKBPK00010.FYMDEDT1(RA.SEINENGAPI,MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,o_YMD2);
--                          ELSIF BPRMFLG_003 THEN
                         -- 和暦で表示生年月日
--                            IF N_NAIYO_CD IN(11,21) THEN
--                              MJIDO_WORK(ICNT).HYOJI_SEINENGAPI    := VSEINENGAPI;
                             -- 西暦で表示生年月日
--                            ELSIF N_NAIYO_CD IN(12,22) THEN
--                              MJIDO_WORK(ICNT).HYOJI_SEINENGAPI    := n_YYYY ||'.' || n_MM || '.'|| n_DD;
--                            END IF;
--                          ELSE
                           -- 「平成○年○月○日」の形式で表示
--                            MJIDO_WORK(ICNT).HYOJI_SEINENGAPI      := VSEINENGAPI;       
--                          END IF;
--                        END IF;
-- 2024/06/04 ZCZL.GUANHONG Delete end
                       MJIDO_WORK(ICNT).SEIBETSU := RA.SEIBETSU;
--  2024/09/06 ZCZL.WANGMING UPDATE START 0.3.000.001:8月1日認識合わせの横展開
                       I_RTN := KKAPK0030.FCDGetR('GKB', '021', '0001', RA.SEIBETSU, sMEISHO, sMEISHOKANA, sYOBI); 
--                       MJIDO_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;
                       MJIDO_WORK(ICNT).HYOJI_SEIBETSU := sMEISHO;
--  2024/09/06 ZCZL.WANGMING UPDATE END
                       MJIDO_WORK(ICNT).ZOKUGARAMEI1 := VZOKUGARAMEI1;
                       MJIDO_WORK(ICNT).SETAI_NO := RA.SETAI_NO;
                       MJIDO_WORK(ICNT).HYOJI_SETAI_NO := VSETAI_NO;
                       MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO := RG.HOGOSYA_KOJIN_NO;
--  2024/06/04 ZCZL.GUANHONG Add Start 0.3.000.000:新WizLIFE２次開発
                       I_RTN := GKBFKHMCTRL(CRJIDO.KOJIN_NO, g_rJSTP.CHOHYOID, '1', g_vGKBPB00390_CTL, o_vSHIMEIKANA, o_vSHIMEIKANJI, o_vBIRTHDAY);
--  2024/09/06 ZCZL.WANGMING UPDATE START 0.3.000.001:8月1日認識合わせの横展開
--                       MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := o_vSHIMEIKANJI;
--  2024/11/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00620対応 Start
--                       MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RB.SHIMEI_KANA;
                       MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := o_vSHIMEIKANA;
--  2024/11/19 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:IT_GKB_00620対応 End
                       MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := o_vSHIMEIKANJI;
--  2024/09/06 ZCZL.WANGMING UPDATE END
-- 2024/06/04 ZCZL.GUANHONG Add end
--  2024/06/04 ZCZL.GUANHONG Delete Start 0.3.000.000:新WizLIFE２次開発 
--                        MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RB.SHIMEI_KANA;
--                        MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := RB.SHIMEI_KANJI;
--                        IF RB.JINKAKU_KBN = 1 THEN
                         -- 保護者氏名かな
--                          I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANA,RB.SHIMEI_KANA,MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                         -- 保護者氏名漢字
--                          I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI);
--                        END IF;
-- 2024/06/04 ZCZL.GUANHONG Delete end
                       MJIDO_WORK(ICNT).ZOKUGARAMEI2 := VZOKUGARAMEI2;
                       MJIDO_WORK(ICNT).GAKOKU_CD := IGAKO_CD;
                       MJIDO_WORK(ICNT).GAKOKUMEI := VGAKOMEI;
                       MJIDO_WORK(ICNT).GYOSEIKU_CD := RA.GYOSEIKU_CD;
                       MJIDO_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;
                       MJIDO_WORK(ICNT).HAN_CD := RA.HAN_CD;
                       MJIDO_WORK(ICNT).HANMEI := VHAN_MEI;
                       MJIDO_WORK(ICNT).SANTEIDANTAI_CD := RA.SANTEIDANTAI_CD;
                       MJIDO_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;
                       MJIDO_WORK(ICNT).CHOMEI := RA.CHOMEI;
                       MJIDO_WORK(ICNT).BANCHI := RA.BANCHI;
                       MJIDO_WORK(ICNT).KATAGAKI := RA.KATAGAKI;
                       MJIDO_WORK(ICNT).NENDO := VHYOUJINENDO;
                       MJIDO_WORK(ICNT).ICHIRAN_CD := IICHIRAN_CD;
                       MJIDO_WORK(ICNT).ICHIRANMEI := VICHIRANMEI;
                       MJIDO_WORK(ICNT).KAIPEJI_CD := ' ';
                       MJIDO_WORK(ICNT).KAIPEJI := ' ';
                       MJIDO_WORK(ICNT).HIDARI := VHIDARI;
                       MJIDO_WORK(ICNT).MIGI := VMIGI;
                       MJIDO_WORK(ICNT).SAKUSEIBI := VSASKUSEIBI;
                       MJIDO_WORK(ICNT).RENBAN := ICNT + 1;
--  2024/06/04 ZCZL.GUANHONG Delete Start 0.3.000.000:新WizLIFE２次開発                 
--                        IF RB.JINKAKU_KBN = 1 THEN
                         -- 保護者氏名上段
--                          I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,VHOGOSHA_SHIMEI_JODAN);
--                          VHOGOSHA_SHIMEI_JODAN   := SUBSTR(VHOGOSHA_SHIMEI_JODAN,1,15);
                         -- 保護者氏名下段(保護者氏名漢字)
--                          I_RTN  := FUNC_SEIGYO_SET(RB.HONMYO_KANJI,RB.SHIMEI_KANJI,VHOGOSHA_SHIMEI_GEDAN);
--                          VHOGOSHA_SHIMEI_GEDAN   := SUBSTR(VHOGOSHA_SHIMEI_GEDAN,16);
--                        END IF;
-- 2024/06/04 ZCZL.GUANHONG Delete end
                       MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := VHOGOSHA_SHIMEI_JODAN;
                       MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN := VHOGOSHA_SHIMEI_GEDAN;
                       MJIDO_WORK(ICNT).KON_JUSHO_JODAN := VJUSHO_JODAN;
                       MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := VJUSHO_GEDAN;
                       MJIDO_WORK(ICNT).BIKO := VBIKO;
                       MJIDO_WORK(ICNT).JINKAKU_KBN := RA.JINKAKU_KBN;
                       ICNT := ICNT + 1;               -- カウントアップ
                       IFRET := c_ISUCCESS;              -- 正常終了
                   ELSE
                         NULL;
                   END IF;
                ELSE
                      NULL;
                END IF;
            END LOOP;
--  2024/11/21 JPJYS.LIUHUAIQI ADD 0.3.000.005:IT_GKB_00621対応 Start
            g_nKENSAKU:= ICNT;
--  2024/11/21 JPJYS.LIUHUAIQI ADD 0.3.000.005:IT_GKB_00621対応 End
      EXCEPTION
                 WHEN OTHERS THEN
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
    RETURN IFRET;
    EXCEPTION
        /* その他エラー */
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 児童生徒ワーク（GKBWJIDOSHINKYU）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_INSERT_JIDO_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        IRET                PLS_INTEGER;                -- 戻り値
        BRET                BOOLEAN;                    -- 戻り値
        ICNT                BINARY_INTEGER;             -- 戻り値
        IMAX                BINARY_INTEGER;             -- 戻り値
        IMIN                BINARY_INTEGER;             -- 戻り値
    BEGIN
        IFRET := c_ISUCCESS;                  -- 正常終了
        -- ワーク領域の最終位置を取得
        IMAX := MJIDO_WORK.LAST;
        -- ワーク領域の先頭位置を取得
        IMIN := MJIDO_WORK.FIRST;
        BEGIN
            -- ワーク領域の件数分繰り返し処理を行う
            FOR ICNT IN IMIN..IMAX LOOP
                    Insert INTO GKBWJIDOSHINKYU
    (
                 JIDO_KOJIN_NO,
                 JIDO_SHIMEI_KANA,
                 JIDO_SHIMEI_KANJI,
                 SEINENGAPI,
                 HYOJI_SEINENGAPI,
                 SEIBETSU,
                 HYOJI_SEIBETSU,
                 ZOKUGARAMEI1,
                 SETAI_NO,
                 HYOJI_SETAI_NO,
                 HOGOSHA_KOJIN_NO,
                 HOGOSHA_SHIMEI_KANA,
                 HOGOSHA_SHIMEI_KANJI,
                 ZOKUGARAMEI2,
                 GAKOKU_CD,
                 GAKOKUMEI,
                 GYOSEIKU_CD,
                 GYOSEIKUMEI,
                 HAN_CD,
                 HANMEI,
                 SANTEIDANTAI_CD,
                 SANTEIDANTAIMEI,
                 CHOMEI,
                 BANCHI,
                 KATAGAKI,
                 NENDO,
                 ICHIRAN_CD,
                 ICHIRANMEI,
                 KAIPEJI_CD,
                 KAIPEJI,
                 HIDARI,
                 MIGI,
                 SAKUSEIBI,
                 RENBAN,
                 HOGOSHA_SHIMEI_JODAN,
                 HOGOSHA_SHIMEI_GEDAN,
                 KON_JUSHO_JODAN,
                 KON_JUSHO_GEDAN,
                 BIKO,
                 JINKAKU_KBN
                )
                VALUES
                (
                 MJIDO_WORK(ICNT).JIDO_KOJIN_NO,
                 MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA,
                 MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI,
                 MJIDO_WORK(ICNT).SEINENGAPI,
                 MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,
                 MJIDO_WORK(ICNT).SEIBETSU,
                 MJIDO_WORK(ICNT).HYOJI_SEIBETSU,
                 MJIDO_WORK(ICNT).ZOKUGARAMEI1,
                 MJIDO_WORK(ICNT).SETAI_NO,
                 MJIDO_WORK(ICNT).HYOJI_SETAI_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI,
                 MJIDO_WORK(ICNT).ZOKUGARAMEI2,
                 MJIDO_WORK(ICNT).GAKOKU_CD,
                 MJIDO_WORK(ICNT).GAKOKUMEI,
                 MJIDO_WORK(ICNT).GYOSEIKU_CD,
                 MJIDO_WORK(ICNT).GYOSEIKUMEI,
                 MJIDO_WORK(ICNT).HAN_CD,
                 MJIDO_WORK(ICNT).HANMEI,
                 MJIDO_WORK(ICNT).SANTEIDANTAI_CD,
                 MJIDO_WORK(ICNT).SANTEIDANTAIMEI,
                 MJIDO_WORK(ICNT).CHOMEI,
                 MJIDO_WORK(ICNT).BANCHI,
                 MJIDO_WORK(ICNT).KATAGAKI,
                 MJIDO_WORK(ICNT).NENDO,
                 MJIDO_WORK(ICNT).ICHIRAN_CD,
                 MJIDO_WORK(ICNT).ICHIRANMEI,
                 MJIDO_WORK(ICNT).KAIPEJI_CD,
                 MJIDO_WORK(ICNT).KAIPEJI,
                 MJIDO_WORK(ICNT).HIDARI,
                 MJIDO_WORK(ICNT).MIGI,
                 MJIDO_WORK(ICNT).SAKUSEIBI,
                 MJIDO_WORK(ICNT).RENBAN,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN,
                 MJIDO_WORK(ICNT).KON_JUSHO_JODAN,
                 MJIDO_WORK(ICNT).KON_JUSHO_GEDAN,
                 MJIDO_WORK(ICNT).BIKO,
                 MJIDO_WORK(ICNT).JINKAKU_KBN
                );
               END LOOP;
              commit;
    EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;       -- 処理前に戻す
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
    -- その他エラー
        WHEN OTHERS THEN
            ROLLBACK;       -- 処理前に戻す
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 児童生徒ワーク（GKBWJIDOSHINKYU）CSVファイルの取得
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
        IFRET               PLS_INTEGER;                   -- 戻り値
        FRET                PLS_INTEGER;                -- 戻り値
        IRET                PLS_INTEGER;                -- 戻り値
        BRET                BOOLEAN;                    -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        VSQL                NVARCHAR2(10000);           -- ＳＱＬ文
        VSQLSEL             NVARCHAR2(9000);            -- ＳＱＬのソート以外
        VSQLORDER           NVARCHAR2(1000);            -- ＳＱＬの［ORDER BY］句
        I_CUR               PLS_INTEGER;                -- カーソル
        RREC                GKBWJIDOSHINKYU%ROWTYPE;      -- 入学通知台帳のレコード変数
        NROWS               NUMBER;                     --
        IPAGECNT            PLS_INTEGER;                -- 頁数
        IGYOCNT             PLS_INTEGER;                -- 行番号
        IGYORENBAN          PLS_INTEGER;                -- 行連番
        VPAGENAME           NVARCHAR2(500);             -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(500);             -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(500);             -- 改頁項目値のワーク
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IGYOCNT := 0;
        ICNT := 0;
        MJIDO_WORK.DELETE;                   -- ワーク領域の初期化
        MGAKUREIBO_WORK.DELETE;
        MGAKUNEN_LNK_WORK.DELETE;
        -- ［ORDER BY］句を付加
        IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
          VSQLORDER := ' ORDER BY ICHIRAN_CD,' || g_rJSTP.ORDERBYCLAUSE;
        END IF;
        
        VPAGEFD := ' GAKOKU_CD ';
        VPAGENM := ' GAKOKUMEI ';
        
        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'NENDO, ';
            VSQLSEL := VSQLSEL || 'ICHIRAN_CD, ';
            VSQLSEL := VSQLSEL || 'ICHIRANMEI, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
            VSQLSEL := VSQLSEL || 'HIDARI, ';
            VSQLSEL := VSQLSEL || 'MIGI, ';
            VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
            VSQLSEL := VSQLSEL || 'RENBAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAIMEI, ';
            VSQLSEL := VSQLSEL || 'BIKO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || VPAGEFD || ' KAIPEJI_CD, ';            -- 改頁値を設定
            VSQLSEL := VSQLSEL || VPAGENM || ' KAIPEJI, ';            -- 改頁名を設定
            VSQLSEL := VSQLSEL || 'JINKAKU_KBN ';               -- 人格区分
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWJIDOSHINKYU ';
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;
            -- カーソルのオープン
            I_CUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(I_CUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, RREC.NENDO, 10);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, RREC.ICHIRAN_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, RREC.ICHIRANMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.KAIPEJI, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.HIDARI, 40);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.MIGI, 40);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.SAKUSEIBI, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.RENBAN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.JIDO_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.JIDO_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.HYOJI_SEINENGAPI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.HYOJI_SEIBETSU, 2);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.ZOKUGARAMEI1, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.ZOKUGARAMEI2, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.HOGOSHA_SHIMEI_JODAN, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.HOGOSHA_SHIMEI_GEDAN, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.KON_JUSHO_JODAN, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.KON_JUSHO_GEDAN, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.GYOSEIKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.SANTEIDANTAIMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.BIKO, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.HOGOSHA_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.HOGOSHA_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, VPAGENM, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.JINKAKU_KBN);
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(I_CUR);
            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(I_CUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  1, MJIDO_WORK(ICNT).NENDO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  2, MJIDO_WORK(ICNT).ICHIRAN_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  3, MJIDO_WORK(ICNT).ICHIRANMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  4, MJIDO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  5, MJIDO_WORK(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  6, MJIDO_WORK(ICNT).HIDARI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  7, MJIDO_WORK(ICNT).MIGI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MJIDO_WORK(ICNT).SAKUSEIBI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MJIDO_WORK(ICNT).ZOKUGARAMEI1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MJIDO_WORK(ICNT).ZOKUGARAMEI2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 18, MJIDO_WORK(ICNT).KON_JUSHO_JODAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 19, MJIDO_WORK(ICNT).KON_JUSHO_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 20, MJIDO_WORK(ICNT).GYOSEIKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 21, MJIDO_WORK(ICNT).SANTEIDANTAIMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 22, MJIDO_WORK(ICNT).BIKO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 23, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 24, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 25, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 26, VPAGENAME);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 27, MJIDO_WORK(ICNT).JINKAKU_KBN);
                    -- 改頁の指定がある場合
    --                -- 以前の改頁項目値と同じ
                    IF VPAGEWORK = VPAGENAME THEN
                    -- 以前の改頁項目名と同じ
                        IGYOCNT := IGYOCNT + 1;
                        IGYORENBAN := IGYORENBAN + 1;
                        IF IGYOCNT > c_IMAXROWS THEN
                        -- １頁内の最大行数を超えた
                            IPAGECNT := IPAGECNT + 1;
                            IGYOCNT := 1;
                            VPAGEWORK := VPAGENAME;
                        END IF;
                    ELSE
                    -- 改頁必要
                        IPAGECNT := IPAGECNT + 1;
                        IGYOCNT := 1;
                        IGYORENBAN := 1;
                        VPAGEWORK := VPAGENAME;
                    END IF;
                    -- 再セットする項目
                    MJIDO_WORK(ICNT).RENBAN := IGYORENBAN;    -- 連番
                    MJIDO_WORK(ICNT).KAIPEJI := VPAGENAME;    -- 改頁名
                    MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEWORK; -- 改頁コード
                ELSE
                    -- 全件読み込み終了
                    EXIT;
                END IF;
                ICNT := ICNT + 1;
            END LOOP;
--  2024/11/21 JPJYS.LIUHUAIQI ADD 0.3.000.005:IT_GKB_00621対応 Start
            g_nCSVKENSAKU := ICNT;
--  2024/11/21 JPJYS.LIUHUAIQI ADD 0.3.000.005:IT_GKB_00621対応 End
        EXCEPTION
            WHEN OTHERS THEN
                FRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        RETURN FRET;
    END FUNC_GET_JIDO_WK_CSV;
    --------------------------------------------------------------------------------
    -- 児童生徒ワーク（GKBWJIDOSHINKYU）CSVファイルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        IRET                PLS_INTEGER;                -- 戻り値
        BRET                BOOLEAN;                    -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        VDATA               NVARCHAR2(3000);            -- データ（１レコード分）
        r_CHOHYO_001        GKBWL220R001%ROWTYPE;
        
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        IMAX := MJIDO_WORK.LAST;             -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;            -- ワーク領域の件数の最小値
        -- 取得した件数分繰り返す
        FOR ICNT IN IMIN..IMAX LOOP
          
            nCOUNT := nCOUNT + 1;
            r_CHOHYO_001                                :=NULL;  
            r_CHOHYO_001.NO                             := nCOUNT;                                                    --ソート順
            r_CHOHYO_001.NENDO                          := MJIDO_WORK(ICNT).NENDO;                                    --年度
            r_CHOHYO_001.ICHIRAN_CD                     := MJIDO_WORK(ICNT).ICHIRAN_CD;                               --一覧表コード
            r_CHOHYO_001.ICHIRANMEI                     := MJIDO_WORK(ICNT).ICHIRANMEI;                               --一覧表名
            r_CHOHYO_001.GAKKOKU_CD                     := MJIDO_WORK(ICNT).ICHIRAN_CD|| MJIDO_WORK(ICNT).KAIPEJI;    --学校区コード
            r_CHOHYO_001.GAKKO_MEI_HYOJI                := MJIDO_WORK(ICNT).KAIPEJI;                                  --学校名表示用
            r_CHOHYO_001.HIDARI                         := MJIDO_WORK(ICNT).HIDARI;                                   --左
            r_CHOHYO_001.MIGI                           := MJIDO_WORK(ICNT).MIGI;                                     --右
            r_CHOHYO_001.GENZAIBI                       := MJIDO_WORK(ICNT).SAKUSEIBI;                                --現在日
            r_CHOHYO_001.NUM                            := MJIDO_WORK(ICNT).RENBAN;                                   --No
            r_CHOHYO_001.SHIMEI_KANA                    := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;                         --氏名カナ
            r_CHOHYO_001.SHIMEI                         := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;                        --氏名
            r_CHOHYO_001.SEINENGAPI                     := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;                         --生年月日
            r_CHOHYO_001.SEIBETSU                       := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;                           --性別
            r_CHOHYO_001.HOGOSHA_KANKEI                 := MJIDO_WORK(ICNT).ZOKUGARAMEI1;                             --保護者との関係
            r_CHOHYO_001.JIDO_ZOKUGARAMEI               := MJIDO_WORK(ICNT).ZOKUGARAMEI2;                             --児童との関係
            r_CHOHYO_001.HOGOSHA_JODAN                  := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;                      --保護者上
            r_CHOHYO_001.HOGOSHA_SHIMEI                 := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;                     --保護者
            r_CHOHYO_001.JUSHO_JODAN                    := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;                          --住所上
            r_CHOHYO_001.JUSHO_GEDAN                    := MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;                          --住所下
            r_CHOHYO_001.GYOSEIKU                       := MJIDO_WORK(ICNT).GYOSEIKUMEI;                              --行政区
            r_CHOHYO_001.SANTEIDANTAI_MEI               := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;                          --算定団体名
            r_CHOHYO_001.BIKO                           := MJIDO_WORK(ICNT).BIKO;                                     --備考
            r_CHOHYO_001.JINKAKU_KBN                    := MJIDO_WORK(ICNT).JINKAKU_KBN;                              --人格区分
            r_CHOHYO_001.CHOMEI                         := MJIDO_WORK(ICNT).CHOMEI;                                   --町名
            r_CHOHYO_001.BANCHI                         := MJIDO_WORK(ICNT).BANCHI;                                   --番地
            r_CHOHYO_001.KATAGAKI                       := MJIDO_WORK(ICNT).KATAGAKI;                                 --方書
            r_CHOHYO_001.GYOSEIKU_MEI                   := MJIDO_WORK(ICNT).GYOSEIKUMEI;                              --行政区名
            r_CHOHYO_001.BREAK_NO                       := NULL;                                                      --改ページキー
            r_CHOHYO_001.WSNUM                          := g_sWSNUM;                                                  --端末番号
            r_CHOHYO_001.BATCHKBN                       := c_BATCH;                                                   --即時バッチ区分
            r_CHOHYO_001.JOBNUM                         := g_nJOBNUM;                                                 --ジョブNO

            INSERT INTO GKBWL220R001 VALUES r_CHOHYO_001;

        END LOOP;
        -- 終了
        RETURN FRET;
    EXCEPTION
        WHEN OTHERS THEN
            FRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE;

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        ERR              EXCEPTION;
--2024/06/04 ZCZL.GUANHONG ADD 0.3.000.000:新WizLIFE２次開発
        nRTN                  NUMBER;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        
        DELETE FROM GKBWL220R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
        COMMIT;
        -- 取得した条件をそれぞれの変数へセット
        VSHONYUBI := g_JYOUKEN01;        -- 小学校入学年月日
        VSHOSOBI  := g_JYOUKEN02;        -- 小学校卒業年月日
        VCHUNYUBI := g_JYOUKEN03;        -- 中学校入学年月日
        VCHUSOBI  := g_JYOUKEN04;        -- 中学校卒業年月日
        VNENDO := SUBSTR(VSHONYUBI,1,3);
        VNENDO := KKAPK0020.FNENDO(VNENDO,1);
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
                      o_SHIMEIPRM.EXTEND;
                      o_SHIMEIPRM(11) := 0;
        ELSE
          WHILE (o_LENGTH < 12) LOOP
            o_SHIMEIPRM.EXTEND;
            o_SHIMEIPRM(o_LENGTH+1) := 0;
            o_LENGTH := o_LENGTH + 1;
          END LOOP;
        END IF; 
--2024/06/04 ZCZL.GUANHONG ADD START 0.3.000.000:新WizLIFE２次開発
          --外国人　氏名・生年月日制御帳票(ID)
          g_aSHIMEIJKN_CHOHYOPRM := A_CONS_PRM();
          nRTN := KKAPK0030.FCTGetR('GKB','SHIMEIJKN_CHOHYO','0000',1,g_aSHIMEIJKN_CHOHYOPRM);
          IF nRTN = 0 THEN
            FOR i IN 1..g_aSHIMEIJKN_CHOHYOPRM.COUNT LOOP
              IF g_aSHIMEIJKN_CHOHYOPRM(i) = 'GKB220R001' THEN
                g_nGKBPB00390_INDEX := i;
                EXIT;
              END IF;
            END LOOP;
          END IF;
          --本名・通称名　出力制御
          g_aEQSHIMEIPRM := A_CONS_PRM();
          nRTN := KKAPK0030.FCTGetR('GKB','EQSHIMEI','0000',0,g_aEQSHIMEIPRM);
          IF nRTN = 0 AND g_nGKBPB00390_INDEX < g_aEQSHIMEIPRM.COUNT THEN
            g_vGKBPB00390_CTL := g_aEQSHIMEIPRM(g_nGKBPB00390_INDEX);
          END IF;
--2024/06/04 ZCZL.GUANHONG ADD END
        -- 児童生徒ワーク（GKBWJIDOSHINKYU）のデータ全件削除
        I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
        IF I_RTN = c_INOT_SUCCESS THEN
        -- エラーで帰ってきた場合
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
            RAISE ERR;
        END IF;
        -- 児童生徒ワークデータ作成
        I_RTN := FUNC_GET_JIDO_WK;
        IF I_RTN = c_INOT_SUCCESS THEN
        -- エラーで帰ってきた場合
            IF I_RTN = c_INOTFOUND THEN
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
            END IF;
            RAISE ERR;
        END IF;
        IF MJIDO_WORK.COUNT > 0 THEN
            -- ワークテーブル作成
            I_RTN := FUNC_INSERT_JIDO_WK;
            IF I_RTN = c_INOT_SUCCESS THEN
            -- エラーで帰ってきた場合
                RAISE ERR;
            END IF;
            -- 児童生徒データ作成（ＣＳＶ用）
            I_RTN := FUNC_GET_JIDO_WK_CSV;
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
                RAISE ERR;
            END IF;
            -- 児童生徒ＣＳＶファイル作成
            I_RTN := FUNC_SET_JIDO_WK_CSVFILE;
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
                RAISE ERR;
            END IF;
        END IF;
        
        --帳票出力CSVの作成
        bRTN :=FUNC_B11CSV('GKBWL220R001');

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
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
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
    --  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
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
END GKBPB00390;
/