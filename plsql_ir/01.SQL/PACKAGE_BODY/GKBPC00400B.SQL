CREATE OR REPLACE PACKAGE BODY GKBPC00400
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 新入学児童学齢簿作成処理
--  機能概要      : 小学校に就学する新入生の学齢簿を作成する
--                また、入学予定者名簿を作成する
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
--------------------------------------------------------
--  変更履歴
--  2024/04/19 ZCZL.LIKEWEN UPDATE 0.2.000.001:512_GKB_00018対応
--  2024/07/28 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--  2024/08/02 ZCZL.wangqiwei Update 0.3.000.001:受入検証対応No.61
--  2024/08/30 ZCZL.WANGMING Update 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.004:IT_GKB_00429対応横展開
--  2024/11/20 JPJYS.LIUHUAIQI UPDATE 0.3.000.005:IT_GKB_00511対応
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応
--  2024/12/27,2025/01/03 JIP.Y.SATO UPDATE 0.3.000.007:故障対応
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

    g_nTIME NUMBER;  --時分秒
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
    g_nDATE NUMBER;  --処理日_西暦
    g_SYS_TANMATU_BASHO NVARCHAR2(63);
    sBUKACODE           NVARCHAR2(63);
    g_JIDO_KOKUSEKI_MEI       NVARCHAR2(100);
-- 2024/07/18 ZCZL.wangqiwei Add end
    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --画面から条件
    g_vJYOUKEN1  NVARCHAR2(500);
    g_vJYOUKEN2  NVARCHAR2(500);
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
    g_vSYORINENDO NVARCHAR2(500);
    --パラメータ変数
    VMSG             NVARCHAR2(4000);
    VERRMSG          NVARCHAR2(1000);
    o_MESSAGE        NVARCHAR2(1000);
    IRTN             PLS_INTEGER ;
    ICHK1            PLS_INTEGER ;
    ICHK2            PLS_INTEGER ;
    ICHK3            PLS_INTEGER ;
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
    NSYSTEM_YEAR         NUMBER;       --システム時間_年　　　　　　
    NSYSTEM_MONTH        NUMBER;       --システム時間_月　　　　　　
    NLOGCNT              NUMBER;       --GKBTBKLOGチェック
-- ERROR関連 --
-- デバック
    N_SQL_CODE      NUMBER;             -- SQLエラーコード
    V_SQL_MSG       NVARCHAR2(255);     -- SQLエラーメッセージ
    -- 処理結果
    C_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
    C_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    C_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし
    -- 児童生徒ワーク
    C_VTABLE      CONSTANT  NVARCHAR2(128) := 'GKBWJIDOSHINNYUGAKU';
    -- １頁の最大行数
    C_IMAXROWS     CONSTANT  PLS_INTEGER := 15;

    -- システム条件:「児童との関係」判定条件
    c_ISYS_J_KANKEI  CONSTANT  PLS_INTEGER := 120;
    
    ERR              EXCEPTION;
------------------------------------------------------------------------------
--  変数宣言
------------------------------------------------------------------------------
    ISAKUSEIBI         PLS_INTEGER;
    NSYSTIME           NUMBER;       -- システム時間
    RG                 GKBTGAKUREIBO%ROWTYPE;
    RB                 GABTATENAKIHON%ROWTYPE;
    RC                 GABTSOFUSAKI%ROWTYPE;
    IHOGOSHA_KOJIN_NO  NUMBER;
    VJINKAKU_KBN       NUMBER;
    W_HOGOSHANM        NVARCHAR2(100); 
    IGAKO_CD           PLS_INTEGER;
    VGAKOMEI           NVARCHAR2(60);       
    VSEINENGAPI        NVARCHAR2(11);
    VSEIBETSU          NVARCHAR2(2);
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--     VSETAI_NO          NVARCHAR2(7);
    VSETAI_NO          NVARCHAR2(15);
    VGYOSEIKU_MEI      NVARCHAR2(20);
    VHAN_MEI           NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.004:IT_GKB_00429対応横展開
--    VSANTEIDANTAI_MEI  NVARCHAR2(20);
    VSANTEIDANTAI_MEI  GKBWJIDOSHINNYUGAKU.SANTEIDANTAIMEI%TYPE;
    VHYOUJINENDO       NVARCHAR2(10);
    VSASKUSEIBI        NVARCHAR2(30);
    VHOGOSHA_SHIMEI_JODAN     NVARCHAR2(100);
    VHOGOSHA_SHIMEI_GEDAN     NVARCHAR2(100);
    VJUSHO_JODAN              NVARCHAR2(30);
    VJUSHO_GEDAN              NVARCHAR2(30);
    VCNT                      NVARCHAR2(6);
    VZOKUGARAMEI1      NVARCHAR2(30);
    VZOKUGARAMEI2      NVARCHAR2(30);
    VGAKUNENMEI        NVARCHAR2(20);
    VGAKUNENSEI        NVARCHAR2(20);
    IKAISISEINENGAPI   PLS_INTEGER;
    VKAISISEINENGAPI   NVARCHAR2(14);
    ISHURYOSEINENGAPI  PLS_INTEGER;
    VSHURYOSEINENGAPI  NVARCHAR2(14);
    IHOGOSHA_ZOKUGARA1 PLS_INTEGER;
    IJUMIN_NARU_JIYU   PLS_INTEGER;
    IJUMIN_NARU        PLS_INTEGER;
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN            BOOLEAN;
    B_RTN           BOOLEAN;
    I_RTN           PLS_INTEGER;
    -- 処理条件（画面からの引数）
    VNENDO          NVARCHAR2(15);      -- 対象年度
    VGAKUNEN        NVARCHAR2(15);      -- 学年
    VSYURYOGAKUNEN  NVARCHAR2(15);      -- 終了学年
    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWJIDOSHINNYUGAKU%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK MTJIDO_TYPE;
    TYPE MTGAKUREIBO_TYPE IS TABLE OF GKBTGAKUREIBO%ROWTYPE INDEX BY BINARY_INTEGER;
    MGAKUREIBO_WORK MTGAKUREIBO_TYPE;
    TYPE MTGAKUNEN_LNK_TYPE IS TABLE OF GKBTGAKUNENLNK%ROWTYPE INDEX BY BINARY_INTEGER;
    MGAKUNEN_LNK_WORK MTGAKUNEN_LNK_TYPE;
    TYPE MKOSHINLOG_TYPE IS TABLE OF GKBTKOSHINLOG%ROWTYPE INDEX BY BINARY_INTEGER;
    MKOSHINLOG_WORK MKOSHINLOG_TYPE;
-- 2024/07/18 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--     TYPE MNINIBIT_TYPE IS TABLE OF GKBTNINIBIT%ROWTYPE INDEX BY BINARY_INTEGER;
--     MNINIBIT_WORK MNINIBIT_TYPE;
-- 2024/07/18 ZCZL.wangqiwei Delete end 
    TYPE MATENAKIHON_TYPE IS TABLE OF GABTATENAKIHON%ROWTYPE INDEX BY BINARY_INTEGER;
    MATENAKIHON_WORK MATENAKIHON_TYPE;
    -- 処理条件の取得用変数
    I_NTRENBAN      NUMBER;
    O_NBREAK        NUMBER(2);
    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    IWAREKIHIZUKE                  PLS_INTEGER;
    IO_SEIREKIHIZUKE               PLS_INTEGER;
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
    INENDO_S_DAY                   PLS_INTEGER;    -- 年度の開始年月日
    ISYOGAKO_NYUGAKU_BI            PLS_INTEGER;    -- 小学校入学年月日
    IZO_NENGAPI                    PLS_INTEGER;    -- 増年月日
    ISEIREKI_WORK                  PLS_INTEGER;
    IRTN_RENBAN                    PLS_INTEGER;      -- 帳票連番印字項目制御
    o_RENBAN_PRM                   A_CONS_PRM;       -- パラメータの配列1
    IRTN_SINNYUGAKU                PLS_INTEGER;      -- 新入学児童作成処理　任意ビット制御
    o_SINNYUGAKU_PRM               A_CONS_PRM;       -- パラメータの配列1
    o_LENGTH                       NUMBER;           -- パラメータの配列の長度1
    NRENBAN                        PLS_INTEGER;      -- 帳票連番使用有無(0:使用する、1:使用しない)
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--     VSQLSEL                        VARCHAR(3000);
    VSQLSEL                        NVARCHAR2(30000);
    TYPE CRJIDO_1 IS RECORD
    (
        GAKO_KBN         NUMBER(2), 
-- 2024/07/18 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発   
--         KOJIN_NO         NUMBER(12),       
--         SETAI_NO         NUMBER(7),
        KOJIN_NO         NUMBER(15),       
        SETAI_NO         NUMBER(15), 
-- 2024/07/18 ZCZL.wangqiwei Update    
        CHIKU_CD         NUMBER(5),
        GYOSEIKU_CD      NUMBER(5),
        HAN_CD           NUMBER(15),
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        SHITEI_SYOGAKO_CD NUMBER(5),
        SHITEI_TYUGAKO_CD NUMBER(5),
-- 2024/07/18 ZCZL.wangqiwei Add end
        GAKOKU_CD        NUMBER(5),
        SANTEIDANTAI_CD  NUMBER(2),
        SEINENGAPI       NUMBER(8),
        HYOJI_SEINENGAPI NVARCHAR2(11),
        SEIBETSU         NUMBER(1),
        JIDO_SHIMEI_KANA NVARCHAR2(100),
        SHIMEI_KANJI     NVARCHAR2(100),
        CHOMEI           NVARCHAR2(40),
        BANCHI           NVARCHAR2(40),
        KATAGAKI         NVARCHAR2(60),
        RIREKI_RENBAN    NUMBER(8),
-- 2024/07/18 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発
--         NINIBIT3         NUMBER(2),
        JINKAKU_KBN      NUMBER(1)
        , ZOKUGARACD1    NUMBER(2)      -- 続柄コード１
        , ZOKUGARACD2    NUMBER(2)      -- 続柄コード２
        , ZOKUGARACD3    NUMBER(2)      -- 続柄コード３
        , ZOKUGARACD4    NUMBER(2)      -- 続柄コード４
-- 2024/07/18 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--         ,YOCHIEN_CD      NUMBER(10)     --幼稚園・保育園コード
--         ,YOCHIEN_MEI     NVARCHAR2(180) --幼稚園・保育園名
-- 2024/07/18 ZCZL.wangqiwei Delete end
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        ,TSUSHOMEI_KANA              NVARCHAR2(100) -- 通称名カナ
        ,TSUSHOMEI_KANJI             NVARCHAR2(100) -- 通称名
        ,ATENA_RIREKI_RENBAN         NUMBER(5)      -- 宛名履歴連番
        ,KOKUSEKI_CD                 NUMBER(3)      -- 国籍コード
        ,YUBIN_NO                    NVARCHAR2(10)  -- 郵便番号
        ,SHOGAKKOKU_CD               NVARCHAR2(5)   -- 小学校区コード
        ,CHUGAKKOKU_CD               NVARCHAR2(5)   -- 中学校区コード
        ,KUIKIGAISHUGAKU_SYURYO_BI   NUMBER(8)      -- 区域外就学_終了年月日
        ,KUNISHIRITSU_SYURYO_BI      NUMBER(8)      -- 国私立終了年月日
-- 2024/07/18 ZCZL.wangqiwei Add end
    );
        A_REC           CRJIDO_1;
    TYPE CRJIDO_2 IS RECORD
    (
        JOKEN3           NUMBER(8),
        CNTRENBAN        PLS_INTEGER
    );
        B_REC             CRJIDO_2;
        MAXRENBAN         NUMBER;
        NNENDO            NUMBER(3);
    I_SYSTEMJOKEN        PLS_INTEGER;        -- システム条件取得用
    NJ_ZOKUGARACD1       NUMBER(2);          -- 児童.続柄1
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
    g_TSUSHOMEI_KANA              A_REC.TSUSHOMEI_KANA%TYPE;       -- 通称名カナ
    g_TSUSHOMEI_KANJI             A_REC.TSUSHOMEI_KANJI%TYPE;      -- 通称名
    g_ATENA_RIREKI_RENBAN         A_REC.ATENA_RIREKI_RENBAN%TYPE;  -- 宛名履歴連番
    g_KOKUSEKI_CD                 A_REC.KOKUSEKI_CD%TYPE;          -- 国籍コード
    g_YUBIN_NO                    A_REC.YUBIN_NO%TYPE;             -- 郵便番号
-- 2024/07/18 ZCZL.wangqiwei Add end

-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
    FUNCTION FUNC_GET_LOG(i_VLOG IN NVARCHAR2) RETURN NVARCHAR2
    IS
    BEGIN
      --出力するログ情報(最大256文字）
      RETURN SUBSTR( i_VLOG
                    ,0
                    ,256);
    END FUNC_GET_LOG;
-- 2024/07/18 ZCZL.wangqiwei Add end
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B00INIT RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;           --戻り値
        rJCTL                         KKBTJCTL%ROWTYPE;  --バッチジョブ情報
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        nRTN                          NUMBER;            --戻り値
        v_LOG                         NVARCHAR2(256);
-- 2024/07/18 ZCZL.wangqiwei Add end 
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
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        -- 排他制御処理
        g_nDATE         := TO_NUMBER(TO_CHAR(SYSDATE ,'YYYYMMDD'));  -- 処理日_西暦
--2024/12/27 JIP.Y.SATO DEL ST
--        nRTN := GKBFKHTSET(2, '999999999999', '全件', g_nDATE, g_sTANTOCODE, g_sWSNUM, g_nTIME);
--        IF nRTN = 1 THEN
--            v_LOG := FUNC_GET_LOG('排他制御処理で異常終了しました。');
----  2024/08/30 ZCZL.WANGMING Update 0.3.000.002:8月1日認識合わせの横展開
----            bRTN  := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '排他制御処理', 1, SQLCODE, v_LOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
--            bRTN  := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_B00INIT', 1, '', '', v_LOG, g_sTANTOCODE, g_sWSNUM, 1);
--            RETURN FALSE;
--        ELSIF nRTN <> 0 AND nRTN <> 1 THEN
--            v_LOG := FUNC_GET_LOG('排他がかかっているデータが存在するため、処理を実行できませんでした。');
----  2024/08/30 ZCZL.WANGMING Update 0.3.000.002:8月1日認識合わせの横展開
----            bRTN  := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '排他制御処理', 1, SQLCODE, v_LOG, '異常終了', g_sTANTOCODE, g_sWSNUM, 2);
--            bRTN  := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_B00INIT', 1, '', '', v_LOG, g_sTANTOCODE, g_sWSNUM, 1);
--            RETURN FALSE;
--        ELSE
--            NULL;
--        END IF;
-- 2024/07/18 ZCZL.wangqiwei Add end
--2024/12/27 JIP.Y.SATO DEL ED
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT RETURN BOOLEAN
    IS
        Vcm         DBMS_UTILITY.MAXNAME_ARRAY;
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        PINT        INTEGER;
        o_sSNENDO   NVARCHAR2(100);
-- 2024/07/18 ZCZL.wangqiwei Add end 
    BEGIN
      
        g_vJYOUKEN1 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNendo');                --就学年度
        Vcm := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbChohyoRenbanShiyoUmu');   --帳票連番使用有無
        g_vJYOUKEN2 := Vcm(1);
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        PINT := KKAPK0020.FNendoWS(g_vJYOUKEN1 , o_sSNENDO );
        g_vSYORINENDO := o_sSNENDO - 1 ;                                      -- 処理年度
-- 2024/07/18 ZCZL.wangqiwei Add end 
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
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
    --  機能概要      : 日付の大小チェック
    --  パラメータ    : i_VHIDUKE1
    --               i_VHIDUKE2
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------    
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
    END ;
    --------------------------------------------------------
    --  機能概要      : 日付チェック
    --  パラメータ    : i_VHIZUKE
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    BRET BOOLEAN ;
    BEGIN
      IRET := 0 ;
      --日付
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
    END ;
    --------------------------------------------------------
    --  機能概要      : 年度チェック
    --  パラメータ    : i_VNENDO
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNCNENDOCHK( i_VNENDO IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    INENDO NUMBER ;
    BEGIN
      IRET := 0 ;
      --対象年度
      BEGIN
        IF i_VNENDO IS NULL THEN
          IRET := 1;
        ELSIF LENGTH(i_VNENDO) <> 3 THEN
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

      RETURN(IRET) ;
    END ;
    --------------------------------------------------------
    --  機能概要      : 年度範囲チェック
    --  パラメータ    : i_VNENDO
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNCNENHANNIDOCHK( i_VNENDO IN NVARCHAR2 ) RETURN NVARCHAR2 IS
    VERRMSG NVARCHAR2(1000) ;
    INENDO NUMBER ;
    BEGIN
      VERRMSG := ''; 
      NSYSTEM_YEAR  := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'));
      NSYSTEM_MONTH := TO_NUMBER(TO_CHAR(SYSDATE, 'MM'));
      --対象年度
      BEGIN
        
        IF NSYSTEM_MONTH >= 4 AND NSYSTEM_MONTH <= 12 THEN
           NSYSTEM_YEAR := NSYSTEM_YEAR + 1;
           VERRMSG :='(処理日を含む年度の1年後)';
        ELSE 
           VERRMSG :='(処理日を含む年度)';   
        END IF;
        
        INENDO := KKAPK0020.FNENDO(NSYSTEM_YEAR,0); 
        
        IF  i_VNENDO = INENDO THEN
         VERRMSG := '';
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
           VERRMSG := '';
      END;
      
      RETURN(VERRMSG) ;
    END ;
    --------------------------------------------------------
    --  機能概要      : 学齢簿バックアップ処理が実行チェック
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNGAKUREIBOBACKUPCHECK RETURN NUMBER IS
    IRET PLS_INTEGER ;

     BEGIN 
       IRET := 0 ;
       NLOGCNT := 0;
     BEGIN 
        
        SELECT COUNT(*)
        INTO NLOGCNT
        FROM GKBTBKLOG 
        WHERE SHORIBI =TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
        
        IF NLOGCNT = 0 THEN
            IRET := 1; 
        END IF;
        
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;
      RETURN(IRET) ;
    END;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                : o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
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
        ICHK1 := 0 ;
        ICHK2 := 0 ;
        ICHK3 := 0 ;

        --条件１のチェック
        IRTN := FUNCNENDOCHK( g_vJYOUKEN1 ) ;
        IF IRTN <> 0 THEN
            ICHK1 := 1 ;
            VMSG := g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
            o_MESSAGE := VMSG ;
        ELSE
            VERRMSG := FUNCNENHANNIDOCHK( g_vJYOUKEN1 ) ;
            IF VERRMSG IS NOT NULL THEN
              ICHK1 := 1 ;
              --2024/12/27 JIP.Y.SATO UPD
              --VMSG :=  g_sGYOUMUCODE || ',99999,入力した年度は、妥当な範囲内の値ではありません'|| VERRMSG ||'。,;';
              VMSG :=  g_sGYOUMUCODE || ',99998,入力した年度は、妥当な範囲内の値ではありません'|| VERRMSG ||'。,;';
              o_MESSAGE := VMSG ;
            END IF;     
        END IF ;
        --条件４のチェック
        IRTN := GKBPK00010.FRBCHK( g_vJYOUKEN2 ) ;
        IF IRTN <> 0  THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,帳票連番使用有無が正しくありません。,;';
          o_MESSAGE := VMSG ;
        END IF ;
       --学齢簿バックアップ処理が実行チェック
        IRTN := FUNGAKUREIBOBACKUPCHECK();
          IF IRTN <> 0   THEN
             VMSG := VMSG || g_sGYOUMUCODE || ',99998,学齢簿バックアップ処理が実行されていません。,;';
             o_MESSAGE := VMSG ;
           END IF;
        o_vRESULT := o_MESSAGE ;
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
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
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
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
    --  機能概要      :  システム条件取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_GET_SYSJOKEN(i_IRENBAN IN PLS_INTEGER) RETURN PLS_INTEGER IS
        I_VALUE    PLS_INTEGER;    -- システム条件設定値
        TACONSPRM  A_CONS_PRM;
        NLENGTH    NUMBER;
        IRTN       NUMBER;
    BEGIN

        BEGIN

           IRTN := KKAPK0030.FPRMSHUTOKU('GKB',
                                         'SYSTEM',
                                         i_IRENBAN,
                                         TACONSPRM,
                                         NLENGTH);
           IF NLENGTH <> 0 THEN
             I_VALUE := TACONSPRM(1);
           ELSE
             I_VALUE := 0;
           END IF;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            I_VALUE := 0;
        END;

        RETURN I_VALUE;
    END FUNC_GET_SYSJOKEN;
    --------------------------------------------------------
    --  機能概要      :  MAX連番(GKBTKOSHINLOG.JOKEN3)を取得の作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FLASE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_GET_MAXRENBAN(I_GAKO_KBN IN NUMBER,I_VNNENDO IN NUMBER,I_GAKO_CD IN NUMBER,
                                I_GYOSEIKU_CD IN NUMBER,MAXRENBAN OUT NUMBER) 
        RETURN BOOLEAN IS
        TYPE TYPECURSOR  IS REF CURSOR;      
        CRSINNYUGAKU2            TYPECURSOR;
    BEGIN

       VSQLSEL := ''; 
       VSQLSEL := VSQLSEL || 'SELECT ';
       VSQLSEL := VSQLSEL || 'NVL(';
       VSQLSEL := VSQLSEL || 'MAX(JOKEN3), ';
       VSQLSEL := VSQLSEL || '0) ';
       VSQLSEL := VSQLSEL || ' FROM ';
       VSQLSEL := VSQLSEL || 'GKBTKOSHINLOG ';
       VSQLSEL := VSQLSEL || 'WHERE  ';
       VSQLSEL := VSQLSEL || 'GYOMU_SUBCD = 0 ';
       VSQLSEL := VSQLSEL || 'AND GROUPKEY = 1 ';
       VSQLSEL := VSQLSEL || 'AND RENBAN = 1 ';
    IF o_RENBAN_PRM(1) IN (2,3,4,5) THEN
       VSQLSEL := VSQLSEL || 'AND SHORI_RENBAN = '|| I_GAKO_KBN;
    ELSE
       VSQLSEL := VSQLSEL || 'AND SHORI_RENBAN = 9 ';
    END IF;
       VSQLSEL := VSQLSEL || ' AND NENDO = '|| I_VNNENDO ;  --------処理条件１.対象年度（GYY）
       
       IF o_RENBAN_PRM(1) IN (2,3,4,5) THEN
            VSQLSEL := VSQLSEL || ' AND JOKEN1 = '|| I_GAKO_CD;
       END IF;

       IF o_RENBAN_PRM(1) IN (4,5) THEN
           VSQLSEL := VSQLSEL || ' AND JOKEN2 = '|| I_GYOSEIKU_CD;
       END IF;
       EXECUTE IMMEDIATE  VSQLSEL;
          OPEN CRSINNYUGAKU2 FOR VSQLSEL;
          LOOP
            FETCH CRSINNYUGAKU2 INTO B_REC.JOKEN3;
            EXIT WHEN CRSINNYUGAKU2%NOTFOUND;

            MAXRENBAN := B_REC.JOKEN3;

          END LOOP;
          IF CRSINNYUGAKU2%ISOPEN THEN
              CLOSE CRSINNYUGAKU2;
          END IF;
       RETURN (B_RTN);
       
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            IF CRSINNYUGAKU2%ISOPEN THEN
                CLOSE CRSINNYUGAKU2;
            END IF;
            MAXRENBAN := 0;
            RETURN TRUE;
       
        WHEN OTHERS THEN
            IF CRSINNYUGAKU2%ISOPEN THEN
                CLOSE CRSINNYUGAKU2;
            END IF;
            MAXRENBAN := 0;
            RETURN FALSE;
    END  FUNC_GET_MAXRENBAN;
    --------------------------------------------------------
    --  機能概要      :  MAX連番(データ有無)を取得の作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FLASE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_GET_CNTRENBAN(I_GAKO_KBN IN NUMBER,I_VNENDO IN NVARCHAR2,I_GAKO_CD IN NVARCHAR2,
                                I_GYOSEIKU_CD IN NVARCHAR2,OCNTRENBAN OUT NUMBER) 
        RETURN NUMBER IS
        IFRET            PLS_INTEGER;        -- 戻り値
        TYPE TYPECURSOR  IS REF CURSOR;      
        CRSINNYUGAKU2            TYPECURSOR;
    BEGIN
       IFRET := C_INOT_SUCCESS;  -- 存在しない

       VSQLSEL := ''; 
       VSQLSEL := VSQLSEL || 'SELECT ';
       VSQLSEL := VSQLSEL || 'COUNT( ';
       VSQLSEL := VSQLSEL || 'JOKEN3 ';
       VSQLSEL := VSQLSEL || ') ';
       VSQLSEL := VSQLSEL || 'AS ';
       VSQLSEL := VSQLSEL || 'CNTRENBAN  ';
       VSQLSEL := VSQLSEL || 'FROM ';
       VSQLSEL := VSQLSEL || 'GKBTKOSHINLOG ';
       VSQLSEL := VSQLSEL || 'WHERE  ';
       VSQLSEL := VSQLSEL || 'GYOMU_SUBCD = 0 ';
       VSQLSEL := VSQLSEL || 'AND GROUPKEY = 1 ';
       VSQLSEL := VSQLSEL || 'AND RENBAN = 1 ';
       IF o_RENBAN_PRM(1) IN (2,3,4,5) THEN
          VSQLSEL := VSQLSEL || 'AND SHORI_RENBAN = '|| I_GAKO_KBN;
       ELSE
          VSQLSEL := VSQLSEL || 'AND SHORI_RENBAN = 9 ';
       END IF;
       VSQLSEL := VSQLSEL || ' AND NENDO = '|| I_VNENDO ;  --------処理条件１.対象年度（GYY）
       
       IF o_RENBAN_PRM(1) IN (2,3,4,5) THEN
            VSQLSEL := VSQLSEL || ' AND JOKEN1 = '|| I_GAKO_CD;
       END IF;

       IF o_RENBAN_PRM(1) IN (4,5) THEN
           VSQLSEL := VSQLSEL || ' AND JOKEN2 = '|| I_GYOSEIKU_CD;
       END IF;
       EXECUTE IMMEDIATE  VSQLSEL;
          OPEN CRSINNYUGAKU2 FOR VSQLSEL;
          LOOP
            FETCH CRSINNYUGAKU2 INTO B_REC.CNTRENBAN;
            EXIT WHEN CRSINNYUGAKU2%NOTFOUND;

            OCNTRENBAN := B_REC.CNTRENBAN;
          END LOOP;
          IF CRSINNYUGAKU2%ISOPEN THEN
              CLOSE CRSINNYUGAKU2;
          END IF;
       RETURN (IFRET);
       
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            OCNTRENBAN := 0;
            RETURN IFRET;
       
        WHEN OTHERS THEN
            IF CRSINNYUGAKU2%ISOPEN THEN
                CLOSE CRSINNYUGAKU2;
            END IF;
            OCNTRENBAN := 0;
            RETURN IFRET;
    END  FUNC_GET_CNTRENBAN;
    --------------------------------------------------------
    --  機能概要      :  検索条件を作成する
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : WHERECASE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    -------------------------------------------------------- 
    FUNCTION FUNC_GET_DYWHERE(I_GAKO_KBN IN NUMBER,I_VNENDO IN NUMBER,I_GAKO_CD IN NVARCHAR2,
                I_GYOSEIKU_CD IN NVARCHAR2)    

    RETURN NVARCHAR2 IS
            WHERECASE NVARCHAR2(200);
         
    BEGIN

       -- 変化の検索条件作成します。
       WHERECASE :=   'WHERE  ';
       WHERECASE := WHERECASE || 'GYOMU_SUBCD = 0 ';
       WHERECASE := WHERECASE || 'AND GROUPKEY = 1 ';
       WHERECASE := WHERECASE || 'AND RENBAN = 1 ';
       WHERECASE := WHERECASE || 'AND SHORI_RENBAN = '|| I_GAKO_KBN;
       WHERECASE := WHERECASE || ' AND NENDO = '|| I_VNENDO ;  --------処理条件１.対象年度（GYY）
       IF o_RENBAN_PRM(1) IN (2,3,4,5) THEN
            WHERECASE := WHERECASE || ' AND JOKEN1 = '|| I_GAKO_CD;
       ELSE
           WHERECASE := WHERECASE || ' AND JOKEN1 = 0';
       END IF;
       IF o_RENBAN_PRM(1) IN (4,5) THEN
           WHERECASE := WHERECASE || ' AND JOKEN2 = '|| I_GYOSEIKU_CD;
       ELSE
           WHERECASE := WHERECASE || ' AND JOKEN2 = 0';       
       END IF;

       RETURN WHERECASE;   

    END  FUNC_GET_DYWHERE;
    --------------------------------------------------------
    --  機能概要      :  MAX連番(GKBTKOSHINLOG.JOKEN3)を更新する。
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FLASE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    -------------------------------------------------------- 
    FUNCTION FUNC_UPDATE_MAXRENBAN(I_GAKO_KBN IN NUMBER,
                                I_VNENDO IN NVARCHAR2,I_GAKO_CD IN NVARCHAR2,
                                I_GYOSEIKU_CD IN NVARCHAR2,I_MAXRENBAN IN NUMBER)    

    RETURN BOOLEAN IS
            WHERECASE    NVARCHAR2(200);
            IINIT_RENBAN NUMBER;
            CNTRENBAN    NUMBER;
            BRTN         BOOLEAN;
    BEGIN

       VSQLSEL := ''; 

       BRTN := FUNC_GET_MAXRENBAN(I_GAKO_KBN, I_VNENDO, I_GAKO_CD,
                                I_GYOSEIKU_CD,IINIT_RENBAN);
       I_RTN := FUNC_GET_CNTRENBAN(I_GAKO_KBN, I_VNENDO, I_GAKO_CD,
                                I_GYOSEIKU_CD,CNTRENBAN);
       -- 変化の検索条件作成します。
       WHERECASE := FUNC_GET_DYWHERE(I_GAKO_KBN,I_VNENDO, I_GAKO_CD, I_GYOSEIKU_CD);

       IF CNTRENBAN = 0 THEN    -- MAX連番を存在しない場合、追加処理を行う。
        VSQLSEL := 'INSERT INTO GKBTKOSHINLOG VALUES(';
            VSQLSEL := VSQLSEL || '0';
            VSQLSEL := VSQLSEL || ',1';
            VSQLSEL := VSQLSEL || ',1';
            VSQLSEL := VSQLSEL || ',' || I_GAKO_KBN;
            VSQLSEL := VSQLSEL || ',' || I_VNENDO;
            VSQLSEL := VSQLSEL || ',''GKBPC00400''';
            VSQLSEL := VSQLSEL || ',''新入学児童学齢簿作成処理''';
        IF o_RENBAN_PRM(1) IN (2,3,4,5) THEN
                          VSQLSEL := VSQLSEL || ',' || I_GAKO_CD;
            ELSE 
                          VSQLSEL := VSQLSEL || ',0';
            END IF;

        IF o_RENBAN_PRM(1) IN (4,5) THEN
                 VSQLSEL := VSQLSEL || ',' || I_GYOSEIKU_CD;
            ELSE 
                 VSQLSEL := VSQLSEL || ',0';
            END IF;

            VSQLSEL := VSQLSEL || ',' || I_MAXRENBAN;
            VSQLSEL := VSQLSEL || ',0';
            VSQLSEL := VSQLSEL || ',0';
            VSQLSEL := VSQLSEL || ')';

       ELSE                         -- MAX連番を存在する場合、更新処理を行う。
            VSQLSEL := 'UPDATE GKBTKOSHINLOG SET ';
        IF o_RENBAN_PRM(1) IN (2,3,4,5) THEN
                          VSQLSEL := VSQLSEL || 'JOKEN1=' || I_GAKO_CD;
            ELSE 
                          VSQLSEL := VSQLSEL || 'JOKEN1=0';
            END IF;

        IF o_RENBAN_PRM(1) IN (4,5) THEN
                 VSQLSEL := VSQLSEL || ',JOKEN2=' || I_GYOSEIKU_CD;
            ELSE 
                 VSQLSEL := VSQLSEL || ',JOKEN2=0';
            END IF;

            VSQLSEL := VSQLSEL || ',JOKEN3=' || I_MAXRENBAN;
        VSQLSEL := VSQLSEL || ' ' || WHERECASE;
        
       END IF;
       EXECUTE IMMEDIATE  VSQLSEL;

       RETURN TRUE;   

    END  FUNC_UPDATE_MAXRENBAN; 
    --------------------------------------------------------
    --  機能概要      : 児童生徒ワークレコードの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    -------------------------------------------------------- 
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        IFRET                PLS_INTEGER;           -- 戻り値
        NNENDO               PLS_INTEGER;           -- 年度
        NGAKUNEN_CD          NUMBER;                -- 学年コード
        NSYURYOGAKUNEN_CD    NUMBER;                -- 終了学年コード
        ICNT                 BINARY_INTEGER;        -- 戻り値
        IJUSHO_NAGASA        PLS_INTEGER;
        IRTNZOKUGARAHERR2    PLS_INTEGER;
        IRTN                 PLS_INTEGER;
        BRTN                 BOOLEAN;
        TEMP_KAIPEJINM   NVARCHAR2(100);       --前回改ページ項目
        MAX_KAIPEIJINM   NVARCHAR2(100);       --今回改ページ項目
        VSQLORDER            NVARCHAR2(1000);            -- ＳＱＬの［ORDER BY］句
        VKOJIN_NO_CD         NVARCHAR2(15);   --連携パラメータ用（コードB）
        VKOJIN_NO_CDMEI      NVARCHAR2(50);   --連携パラメータ用（コード名称）
        TYPE TYPECURSOR  IS REF CURSOR;      
        CRSINNYUGAKU             TYPECURSOR;
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
        o_vSHOGAKU_CD            NVARCHAR2(50);
        o_vSHOGAKU_NM            NVARCHAR2(50);
        o_vCHUGAKU_CD            NVARCHAR2(50);
        o_vCHUGAKU_NM            NVARCHAR2(50);
        nRTN                     NUMBER;
        o_sKOKUMEI_KANA          NVARCHAR2(50);
        o_sKOKUMEI_KANJI         NVARCHAR2(50);  
        o_sKOKUMEI_ARUFABETTO    NVARCHAR2(50);
        o_rGABTATENAKIHON     GABTATENAKIHON%ROWTYPE;     --保護者の宛名基本
        o_rGABTSOFUSAKI       GABTSOFUSAKI%ROWTYPE;    --保護者の送付先基本
-- 2024/07/18 ZCZL.wangqiwei Add end
    BEGIN
     
       IFRET := C_INOTFOUND;                 -- 該当なし
       TEMP_KAIPEJINM := NULL;
       MAX_KAIPEIJINM := NULL;
        NGAKUNEN_CD := TO_NUMBER(VGAKUNEN);          -- 学年
        NSYURYOGAKUNEN_CD := TO_NUMBER(VSYURYOGAKUNEN);          -- 学年
        ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        NSYSTIME   := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS'));   -- システム時間（テーブル更新用）

        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        MGAKUREIBO_WORK.DELETE;
        MGAKUNEN_LNK_WORK.DELETE;
        ICNT := 0;
        MKOSHINLOG_WORK.DELETE;
-- 2024/07/18 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発
--         MNINIBIT_WORK.DELETE;
        TEMP_KAIPEJINM := NULL;
        MAX_KAIPEIJINM := NULL;
        NNENDO := TO_NUMBER(g_vJYOUKEN1);         -- 年度
        MATENAKIHON_WORK.DELETE;
        BEGIN
          -- 連携パラメータ取得
          BRTN := KKCPK0011.FCODEHEN('RSTG', 'KNO', 0, VKOJIN_NO_CD, VKOJIN_NO_CDMEI);
          -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
          VSQLSEL := '';
          VSQLSEL := VSQLSEL || 'SELECT * FROM ';
          VSQLSEL := VSQLSEL || '(SELECT 0 AS GAKO_KBN, ';
          VSQLSEL := VSQLSEL || 'A.KOJIN_NO, ';
          VSQLSEL := VSQLSEL || 'SETAI_NO, ';
          VSQLSEL := VSQLSEL || 'CHIKU_CD, ';
          VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
          VSQLSEL := VSQLSEL || 'HAN_CD, ';
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
--  2024/09/26 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--          VSQLSEL := VSQLSEL || 'GKBFKGKCDGET( 1, A.KOJIN_NO , 999 ) AS SHITEI_SYOGAKO_CD , ';
--          VSQLSEL := VSQLSEL || 'GKBFKGKCDGET( 2, A.KOJIN_NO , 999 ) AS SHITEI_TYUGAKO_CD , ';
          VSQLSEL := VSQLSEL || 'NULL AS SHITEI_SYOGAKO_CD , ';
          VSQLSEL := VSQLSEL || 'NULL AS SHITEI_TYUGAKO_CD , ';
--  2024/09/26 ZCZL.WANGMING UPDATE END
-- 2024/07/18 ZCZL.wangqiwei Add end
          VSQLSEL := VSQLSEL || 'SHOGAKU_CD AS GAKOKU_CD, ';
          VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
          VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
          VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
          VSQLSEL := VSQLSEL || 'SEIBETSU, ';
          VSQLSEL := VSQLSEL || 'SHIMEI_KANA AS JIDO_SHIMEI_KANA, ';
          VSQLSEL := VSQLSEL || 'SHIMEI_KANJI, ';
          VSQLSEL := VSQLSEL || 'CHOMEI, ';
          VSQLSEL := VSQLSEL || 'BANCHI, ';
          VSQLSEL := VSQLSEL || 'KATAGAKI, ';
          VSQLSEL := VSQLSEL || '10 AS RIREKI_RENBAN,';
-- 2024/07/18 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発
--           VSQLSEL := VSQLSEL || ' NULL AS NINIBIT3, ';
          VSQLSEL := VSQLSEL || ' JINKAKU_KBN ';
          VSQLSEL := VSQLSEL || ' , ZOKUGARACD1, ZOKUGARACD2, ZOKUGARACD3, ZOKUGARACD4 ';
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
          VSQLSEL := VSQLSEL || ' , TSUSHOMEI_KANA ';
          VSQLSEL := VSQLSEL || ' , TSUSHOMEI_KANJI ';
          VSQLSEL := VSQLSEL || ' , RIREKI_RENBAN AS ATENA_RIREKI_RENBAN ';
          VSQLSEL := VSQLSEL || ' , KOKUSEKI_CD ';
          VSQLSEL := VSQLSEL || ' , YUBIN_NO ';
          VSQLSEL := VSQLSEL || ' , SHOGAKU_CD ';
          VSQLSEL := VSQLSEL || ' , CHUGAKU_CD ';
          VSQLSEL := VSQLSEL || ' , 0 AS KUIKIGAISHUGAKU_SYURYO_BI ';
          VSQLSEL := VSQLSEL || ' , 0 AS KUNISHIRITSU_SYURYO_BI ';
-- 2024/07/18 ZCZL.wangqiwei Add end
-- 2024/07/18 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--           VSQLSEL := VSQLSEL || ' ,NVL(C.YOCHIEN_CD,0) ';
--           VSQLSEL := VSQLSEL || ' ,C.YOCHIEN_MEI ';
-- 2024/07/18 ZCZL.wangqiwei Delete end 
          VSQLSEL := VSQLSEL || ' FROM GABTATENAKIHON A ';
-- 2024/07/18 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--           VSQLSEL := VSQLSEL || ', (SELECT D.*,';
--           VSQLSEL := VSQLSEL || '          D.KOJIN_NO || KKAPK0010.FChkDgtWiz11(D.KOJIN_NO) AS KOJIN_NO_CDTSUKI';
--           VSQLSEL := VSQLSEL || '     FROM GKBWYOCHIENJOHO D) C ';
-- 2024/07/18 ZCZL.wangqiwei Delete end 
          VSQLSEL := VSQLSEL || 'WHERE GENZON_KBN = 0 ';
          VSQLSEL := VSQLSEL || 'AND SEINENGAPI BETWEEN  ';
          VSQLSEL := VSQLSEL || IKAISISEINENGAPI ;
          VSQLSEL := VSQLSEL || ' AND ';
          VSQLSEL := VSQLSEL || ISHURYOSEINENGAPI ;
          VSQLSEL := VSQLSEL || ' AND NOT EXISTS (SELECT 1 FROM GKBTGAKUREIBO B WHERE A.KOJIN_NO = B.KOJIN_NO )';
-- 2024/07/18 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--           IF VKOJIN_NO_CD = 1 THEN
--             VSQLSEL := VSQLSEL || 'AND A.KOJIN_NO = C.KOJIN_NO(+)  ';
--           ELSE
--             VSQLSEL := VSQLSEL || 'AND A.KOJIN_NO = C.KOJIN_NO_CDTSUKI(+)';
--           END IF;
-- 2024/07/18 ZCZL.wangqiwei Delete end 
          VSQLSEL := VSQLSEL || ' UNION ';
          VSQLSEL := VSQLSEL || 'SELECT 1 AS GAKO_KBN, ';
          VSQLSEL := VSQLSEL || 'B.KOJIN_NO, ';
          VSQLSEL := VSQLSEL || 'B.SETAI_NO, ';
          VSQLSEL := VSQLSEL || 'B.CHIKU_CD, ';
          VSQLSEL := VSQLSEL || 'B.GYOSEIKU_CD, ';
          VSQLSEL := VSQLSEL || 'B.HAN_CD, ';
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
          VSQLSEL := VSQLSEL || 'A.SHITEI_SYOGAKO_CD AS  SHITEI_SYOGAKO_CD , ';
--  2024/09/26 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--          VSQLSEL := VSQLSEL || 'GKBFKGKCDGET( 2, B.KOJIN_NO , 999 ) AS SHITEI_TYUGAKO_CD , ';
          VSQLSEL := VSQLSEL || 'A.SHITEI_TYUGAKO_CD AS SHITEI_TYUGAKO_CD , ';
-- 2024/07/18 ZCZL.wangqiwei Add end
          VSQLSEL := VSQLSEL || 'B.CHUGAKU_CD AS GAKOKU_CD, ';
          VSQLSEL := VSQLSEL || 'B.SANTEIDANTAI_CD, ';
          VSQLSEL := VSQLSEL || 'B.SEINENGAPI, ';
          VSQLSEL := VSQLSEL || 'B.HYOJI_SEINENGAPI, ';
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--           VSQLSEL := VSQLSEL || 'B.SEIBETSU, ';
          VSQLSEL := VSQLSEL || 'A.SEIBETSU AS SEIBETSU, ';
          VSQLSEL := VSQLSEL || 'B.SHIMEI_KANA AS JIDO_SHIMEI_KANA, ';
          VSQLSEL := VSQLSEL || 'B.SHIMEI_KANJI, ';
          VSQLSEL := VSQLSEL || 'B.CHOMEI, ';
          VSQLSEL := VSQLSEL || 'B.BANCHI, ';
          VSQLSEL := VSQLSEL || 'B.KATAGAKI, ';
          VSQLSEL := VSQLSEL || 'A.RIREKI_RENBAN, ';
-- 2024/07/18 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発
--           VSQLSEL := VSQLSEL || 'C.NINIBIT3, ';
          VSQLSEL := VSQLSEL || 'B.JINKAKU_KBN ';
          VSQLSEL := VSQLSEL || ' , B.ZOKUGARACD1, B.ZOKUGARACD2, B.ZOKUGARACD3, B.ZOKUGARACD4 ';
          -- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
          VSQLSEL := VSQLSEL || ' , B.TSUSHOMEI_KANA ';
          VSQLSEL := VSQLSEL || ' , B.TSUSHOMEI_KANJI ';
          VSQLSEL := VSQLSEL || ' , B.RIREKI_RENBAN AS ATENA_RIREKI_RENBAN ';
          VSQLSEL := VSQLSEL || ' , B.KOKUSEKI_CD ';
          VSQLSEL := VSQLSEL || ' , B.YUBIN_NO ';
          VSQLSEL := VSQLSEL || ' , B.SHOGAKU_CD ';
          VSQLSEL := VSQLSEL || ' , B.CHUGAKU_CD ';
          VSQLSEL := VSQLSEL || ' , A.KUIKIGAISHUGAKU_SYURYO_BI ';
          VSQLSEL := VSQLSEL || ' , A.KUNISHIRITSU_SYURYO_BI ';
-- 2024/07/18 ZCZL.wangqiwei Add end
-- 2024/07/18 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--           VSQLSEL := VSQLSEL || ' ,0 ';
--           VSQLSEL := VSQLSEL || ' , N''　'' ';
-- 2024/07/18 ZCZL.wangqiwei Delete end
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--           VSQLSEL := VSQLSEL || 'FROM  GKBTGAKUREIBO A,GABTATENAKIHON B,GKBTNINIBIT C  ';
          VSQLSEL := VSQLSEL || 'FROM  GKBTGAKUREIBO A , GABTATENAKIHON B , GKBTSHUGAKURIREKI C ';
          VSQLSEL := VSQLSEL || 'WHERE A.KOJIN_NO      = B.KOJIN_NO ';
-- 2024/07/18 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--           VSQLSEL := VSQLSEL || 'AND A.KOJIN_NO      = C.KOJIN_NO ';
--           VSQLSEL := VSQLSEL || 'AND A.RIREKI_RENBAN = C.RIREKI_RENBAN ';
-- 2024/07/18 ZCZL.wangqiwei Delete end
          VSQLSEL := VSQLSEL || 'AND A.GAKUNEN       = 6 ';
          VSQLSEL := VSQLSEL || 'AND A.SAISHIN_KBN   = 0 ';
          VSQLSEL := VSQLSEL || 'AND( ';
          VSQLSEL := VSQLSEL || '    (A.SYOGAKO_CD <> 0 ';
          VSQLSEL := VSQLSEL || '    AND (A.SYOGAKO_NYUGAKU_BI <> 0 OR A.SYOGAKO_TENNYUGAKU_BI <> 0) ';
          VSQLSEL := VSQLSEL || '    AND (A.SYOGAKO_TENGAKU_BI = 0 AND A.SYOGAKO_SOTSUGYO_BI = 0)) ';
          VSQLSEL := VSQLSEL || ' OR (A.KUIKIGAI_CD <> 0 ';
          VSQLSEL := VSQLSEL || '    AND (A.KUIKIGAI_NYUGAKU_BI <> 0 OR A.KUIKIGAI_TENNYUGAKU_BI <> 0) ';
          VSQLSEL := VSQLSEL || '    AND (A.KUIKIGAI_TENGAKU_BI = 0 AND A.KUIKIGAI_SOTSUGYO_BI = 0) AND KUIKIGAI_TAIGAKU_BI = 0) ';
          VSQLSEL := VSQLSEL || ' OR (A.YOGOGAKO_CD <> 0 ';
          VSQLSEL := VSQLSEL || '    AND (A.YOGOGAKO_NYUGAKU_BI <> 0 OR A.YOGOGAKO_TENNYUGAKU_BI <> 0) ';
          VSQLSEL := VSQLSEL || '    AND (A.YOGOGAKO_TENGAKU_BI = 0 AND A.YOGOGAKO_SOTSUGYO_BI = 0))) ';
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--           VSQLSEL := VSQLSEL || ' AND B.GENZON_KBN    = 0 ) ';
          VSQLSEL := VSQLSEL || '    AND B.GENZON_KBN    = 0  ';
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
          VSQLSEL := VSQLSEL || ' AND A.KOJIN_NO = C.KOJIN_NO                           ';
          VSQLSEL := VSQLSEL || ' AND A.GENZON_KBN = 0                                  ';
          VSQLSEL := VSQLSEL || ' AND A.SAKUJO_FLG = 0                                  ';
          VSQLSEL := VSQLSEL || ' AND C.SAISHIN_FLG = 0                                 ';
          VSQLSEL := VSQLSEL || ' AND C.SAKUJO_FLG = 0                                  ';
          VSQLSEL := VSQLSEL || ' AND (                                                 ';
          VSQLSEL := VSQLSEL || ' ( C.S_CD <> 0 AND                                     ';
          VSQLSEL := VSQLSEL || ' ( C.S_NYUGAKU_BI <> 0 OR                              ';
          VSQLSEL := VSQLSEL || '   C.S_TENNYU_BI  <> 0 ) AND                           ';
          VSQLSEL := VSQLSEL || ' ( C.S_TENGAKU_BI = 0 AND                              ';
          VSQLSEL := VSQLSEL || '   C.S_SOTSUGYO_BI = 0 AND                             ';
          VSQLSEL := VSQLSEL || '   C.S_TAIGAKU_BI  = 0 )) OR                           ';
          VSQLSEL := VSQLSEL || ' ( C.SHIEN_S_CD <> 0 AND                               ';
          VSQLSEL := VSQLSEL || ' ( C.SHIEN_S_NYUGAKU_BI <> 0 OR                        ';
          VSQLSEL := VSQLSEL || '   C.SHIEN_S_TENNYU_BI <> 0 ) AND                      ';
          VSQLSEL := VSQLSEL || ' ( C.SHIEN_S_TENGAKU_BI = 0 AND                        ';
          VSQLSEL := VSQLSEL || '   C.SHIEN_S_SOTSUGYO_BI = 0 AND                       ';
          VSQLSEL := VSQLSEL || '   C.SHIEN_S_TAIGAKU_BI = 0 )) OR                      ';
          VSQLSEL := VSQLSEL || ' ( C.KUIKIGAI_S_CD <> 0 AND                            ';
          VSQLSEL := VSQLSEL || ' ( C.KUIKIGAI_S_NYUGAKU_BI <> 0 OR                     ';
          VSQLSEL := VSQLSEL || '   C.KUIKIGAI_S_TENNYU_BI <> 0 ) AND                   ';
          VSQLSEL := VSQLSEL || ' ( C.KUIKIGAI_S_TENGAKU_BI = 0 AND                     ';
          VSQLSEL := VSQLSEL || '   C.KUIKIGAI_S_SOTSUGYO_BI = 0 AND                    ';
          VSQLSEL := VSQLSEL || '   C.KUIKIGAI_S_TAIGAKU_BI = 0 )) OR                   ';
          VSQLSEL := VSQLSEL || ' ( C.KUNISHIRITSU_S_CD  <> 0 AND                       ';
          VSQLSEL := VSQLSEL || ' ( C.KUNISHIRITSU_S_NYUGAKU_BI <> 0 OR                 ';
          VSQLSEL := VSQLSEL || '   C.KUNISHIRITSU_S_TENNYU_BI <> 0 ) AND               ';
          VSQLSEL := VSQLSEL || ' ( C.KUNISHIRITSU_S_TENGAKU_BI = 0 AND                 ';
          VSQLSEL := VSQLSEL || '   C.KUNISHIRITSU_S_SOTSUGYO_BI = 0 AND                ';
          VSQLSEL := VSQLSEL || '   C.KUNISHIRITSU_S_TAIGAKU_BI = 0 ))                  ';
          VSQLSEL := VSQLSEL || ' ) ) ';
-- 2024/07/18 ZCZL.wangqiwei Add end 
         IF NRENBAN = 0 THEN
            VSQLORDER := ' GAKO_KBN,GAKOKU_CD,GYOSEIKU_CD ';
--  2024/11/20 JPJYS.LIUHUAIQI ADD 0.3.000.005:IT_GKB_00511対応 Start
         ELSE
           IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
             VSQLORDER :=  g_rJSTP.ORDERBYCLAUSE; --［ORDER BY］句を付加
           END IF;
--  2024/11/20 JPJYS.LIUHUAIQI ADD 0.3.000.005:IT_GKB_00511対応 End
         END IF;
          -- ［ORDER BY］句を付加
          VSQLSEL := VSQLSEL ||' ORDER BY ' || VSQLORDER;
          OPEN CRSINNYUGAKU FOR VSQLSEL;
          LOOP
            FETCH CRSINNYUGAKU INTO A_REC;
            EXIT WHEN CRSINNYUGAKU%NOTFOUND;
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
--  2024/09/26 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--2024/12/27 JIP.Y.SATO UPD ST
--            IRTN := GKBFKGKKUGET(A_REC.KOJIN_NO, A_REC.ATENA_RIREKI_RENBAN, o_vSHOGAKU_CD ,o_vSHOGAKU_NM ,o_vCHUGAKU_CD ,o_vCHUGAKU_NM );
----            IF GKBFKGKKUGET(A_REC.KOJIN_NO, A_REC.ATENA_RIREKI_RENBAN, o_vSHOGAKU_CD ,o_vSHOGAKU_NM ,o_vCHUGAKU_CD ,o_vCHUGAKU_NM ) = 0 THEN
--            IF IRTN = 0 THEN
----  2024/09/26 ZCZL.WANGMING UPDATE END
--               MGAKUREIBO_WORK(ICNT).SHOGAKKOKU_CD := o_vSHOGAKU_CD ;  -- 小学校区コード
--               MGAKUREIBO_WORK(ICNT).CHUGAKKOKU_CD := o_vCHUGAKU_CD ;  -- 中学校区コード
----  2024/09/26 ZCZL.WANGMING ADD START 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--            ELSE
--               BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, '', '', '学校区の取得に失敗したため異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
--               RAISE ERR;
----  2024/09/26 ZCZL.WANGMING ADD END
--            END IF;
            MGAKUREIBO_WORK(ICNT).SHOGAKKOKU_CD := A_REC.SHOGAKKOKU_CD ;  -- 小学校区コード
            MGAKUREIBO_WORK(ICNT).CHUGAKKOKU_CD := A_REC.CHUGAKKOKU_CD ;  -- 中学校区コード
--2024/12/27 JIP.Y.SATO UPD ED
--2024/12/27 JIP.Y.SATO UPD ST
            --MGAKUREIBO_WORK(ICNT).SHITEI_SYOGAKO_CD := A_REC.SHITEI_SYOGAKO_CD ; -- 就学指定校_小学校
            --MGAKUREIBO_WORK(ICNT).SHITEI_TYUGAKO_CD := A_REC.SHITEI_TYUGAKO_CD ; -- 就学指定校_中学校
            MGAKUREIBO_WORK(ICNT).SHITEI_SYOGAKO_CD := A_REC.SHOGAKKOKU_CD ; -- 就学指定校_小学校
            MGAKUREIBO_WORK(ICNT).SHITEI_TYUGAKO_CD := A_REC.CHUGAKKOKU_CD ; -- 就学指定校_中学校
--2024/12/27 JIP.Y.SATO UPD ED
            MGAKUREIBO_WORK(ICNT).SEIBETSU          := A_REC.SEIBETSU ; -- 性別
            MGAKUREIBO_WORK(ICNT).IDOJI_ATENA_RIREKI_RENBAN := A_REC.ATENA_RIREKI_RENBAN; -- 宛名履歴連番
            MGAKUREIBO_WORK(ICNT).KUIKIGAISHUGAKU_SYURYO_BI := A_REC.KUIKIGAISHUGAKU_SYURYO_BI; -- 区域外就学_終了年月日
            MGAKUREIBO_WORK(ICNT).KUNISHIRITSU_SYURYO_BI    := A_REC.KUNISHIRITSU_SYURYO_BI; -- 国私立終了年月日
            MJIDO_WORK(ICNT).TSUSHOMEI_KANA                 := A_REC.TSUSHOMEI_KANA;
            MJIDO_WORK(ICNT).TSUSHOMEI_KANJI                := A_REC.TSUSHOMEI_KANJI;
            MJIDO_WORK(ICNT).ATENA_RIREKI_RENBAN            := A_REC.ATENA_RIREKI_RENBAN;
            MJIDO_WORK(ICNT).JIDO_KOKUSEKI_CD               := A_REC.KOKUSEKI_CD;
            nRTN := GKAFKKKMGET(MJIDO_WORK(ICNT).JIDO_KOKUSEKI_CD , o_sKOKUMEI_KANA , o_sKOKUMEI_KANJI  , o_sKOKUMEI_ARUFABETTO );
            MJIDO_WORK(ICNT).JIDO_KOKUSEKI_MEI:= o_sKOKUMEI_KANJI;
-- 2024/07/18 ZCZL.wangqiwei Add end
                IF o_RENBAN_PRM(1) IN (2,3)THEN             -- JOKEN3(MAX連番)を編集
                  MAX_KAIPEIJINM := A_REC.GAKO_KBN || A_REC.GAKOKU_CD;
                ELSIF o_RENBAN_PRM(1) IN (4,5) THEN
                  MAX_KAIPEIJINM := A_REC.GAKO_KBN || A_REC.GAKOKU_CD || A_REC.GYOSEIKU_CD;
                ELSE
                  MAX_KAIPEIJINM := NULL;
                END IF;
                NNENDO := TO_NUMBER(g_vJYOUKEN1);
                IF TEMP_KAIPEJINM <> MAX_KAIPEIJINM OR (ICNT = 0 )THEN
                   BRTN := FUNC_GET_MAXRENBAN(A_REC.GAKO_KBN,NNENDO,A_REC.GAKOKU_CD,A_REC.GYOSEIKU_CD,MAXRENBAN);
                   TEMP_KAIPEJINM := MAX_KAIPEIJINM;
                END IF;
                IF o_RENBAN_PRM(1) IN (2,3,4,5) THEN              -- JOKEN1を編集
                       MKOSHINLOG_WORK(ICNT).JOKEN1 := A_REC.GAKOKU_CD;
                ELSE
                   MKOSHINLOG_WORK(ICNT).JOKEN1 := 0;
                END IF;
                IF o_RENBAN_PRM(1) IN (4,5) THEN                 -- JOKEN2を編集
                     MKOSHINLOG_WORK(ICNT).JOKEN2 := A_REC.GYOSEIKU_CD;
                ELSE
                    MKOSHINLOG_WORK(ICNT).JOKEN2 := 0;
                END IF;
-- 2024/07/18 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発
--                 MNINIBIT_WORK(ICNT).KOJIN_NO := A_REC.KOJIN_NO;
                MATENAKIHON_WORK(ICNT).JINKAKU_KBN := A_REC.JINKAKU_KBN;
                MKOSHINLOG_WORK(ICNT).JOKEN3 := MAXRENBAN+1;
            VCNT :=  TO_CHAR(ICNT);
            IHOGOSHA_KOJIN_NO := 0;
            BEGIN 
              SELECT HOGOSYA_KOJIN_NO
                INTO IHOGOSHA_KOJIN_NO
                FROM GKBTGAKUREIBO
               WHERE KOJIN_NO = A_REC.KOJIN_NO
                 AND SAISHIN_KBN = 0;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                IHOGOSHA_KOJIN_NO := 0;
            END;
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
           nRTN := GAAPK0030.FGETATENA2(       IHOGOSHA_KOJIN_NO,  --宛名番号
                                             'GKB',                       --業務コード
                                             TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),      --基準日
                                             o_rGABTATENAKIHON,           --保護者宛名
                                             o_rGABTSOFUSAKI              --保護者送付先
                                             );
            MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_CD := o_rGABTATENAKIHON.KOKUSEKI_CD;
            nRTN := GKAFKKKMGET(MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_CD , o_sKOKUMEI_KANA , o_sKOKUMEI_KANJI  , o_sKOKUMEI_ARUFABETTO );
            MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_MEI := o_sKOKUMEI_KANJI; 
-- 2024/07/18 ZCZL.wangqiwei Add end
            -- 判定用続柄コードを変換
            NJ_ZOKUGARACD1 := 0;                 -- 初期化
            IF A_REC.ZOKUGARACD1 BETWEEN 10 AND 29 OR A_REC.ZOKUGARACD1 IN( 71,72,89 ) THEN
                NJ_ZOKUGARACD1 := 10;            -- 子を再セット
            END IF;

            --学齢簿に該当データがなかった場合は判定して取得する
            IF IHOGOSHA_KOJIN_NO = 0 THEN
             IRTN := GAAPK0030.FGETATENA(A_REC.KOJIN_NO,
                                             'GKB',
                                             ISAKUSEIBI,
                                             RB,
                                             RC);
               IF IRTN <> c_ISUCCESS THEN
                  RB.Jinkaku_Kbn := 0;
               END IF;
               VJINKAKU_KBN := RB.Jinkaku_Kbn;
               IF RB.Jinkaku_Kbn = 1 THEN
                      IRTN := GKBPK00010.FGKJHGS(ISAKUSEIBI,
                                          A_REC.KOJIN_NO,
                                          IHOGOSHA_KOJIN_NO,
                                          W_HOGOSHANM);
               ELSE
                     IRTN := GKBPK00010.FHOGOSHA(ISAKUSEIBI,
                                          A_REC.KOJIN_NO,
                                          IHOGOSHA_KOJIN_NO);
               END IF;
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START
				nRTN := GAAPK0030.FGETATENA2(IHOGOSHA_KOJIN_NO,           --宛名番号
                                             'GKB',                       --業務コード
                                             TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),      --基準日
                                             o_rGABTATENAKIHON,           --保護者宛名
                                             o_rGABTSOFUSAKI              --保護者送付先
                                             );
                MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_CD := o_rGABTATENAKIHON.KOKUSEKI_CD;
                nRTN := GKAFKKKMGET(MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_CD , o_sKOKUMEI_KANA , o_sKOKUMEI_KANJI  , o_sKOKUMEI_ARUFABETTO );
                MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_MEI := o_sKOKUMEI_KANJI;
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END
            END IF;

            IHOGOSHA_KOJIN_NO := COALESCE(IHOGOSHA_KOJIN_NO,0);
            MGAKUREIBO_WORK(ICNT).HOGOSYA_IDOJI_RIREKI_RENBAN := NVL(o_rGABTATENAKIHON.RIREKI_RENBAN,0); --2025/01/03 JIP.Y.SATO ADD
          BEGIN
            SELECT JUMIN_NARU_JIYU,
                   JUMIN_NARU
              INTO IJUMIN_NARU_JIYU,
                   IJUMIN_NARU
              FROM GABTJUKIIDO
             WHERE KOJIN_NO = A_REC.KOJIN_NO;
             EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 IJUMIN_NARU_JIYU := 0;
                 IJUMIN_NARU := 0;
          END;

            IWAREKIHIZUKE := 0;  
            BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                         A_REC.SEINENGAPI,
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
            IF A_REC.SEIBETSU = 1 THEN
               VSEIBETSU := '男';
            ELSIF A_REC.SEIBETSU = 2 THEN
               VSEIBETSU := '女';
            END IF;
            VSETAI_NO :=  TO_CHAR(A_REC.SETAI_NO);
            IF IHOGOSHA_KOJIN_NO <> 0 THEN
               IRTN := GAAPK0030.FGETATENA(  IHOGOSHA_KOJIN_NO,
                                             'GKB',
                                             ISAKUSEIBI,
                                             RB,
                                             RC);
              IF I_SYSTEMJOKEN = 1 THEN
                  IF ( RB.ZOKUGARACD1 = 1 AND RB.ZOKUGARACD2 = 0 AND RB.ZOKUGARACD3 = 0 AND RB.ZOKUGARACD4 = 0 )       -- 保護者の続柄（住記）が「世帯主」のみ
                      AND  ( NJ_ZOKUGARACD1 = 10 AND A_REC.ZOKUGARACD2 = 0 AND A_REC.ZOKUGARACD3 = 0 AND A_REC.ZOKUGARACD4 = 0 ) THEN -- 児童の続柄（住記）が「子」のみ
                      IF RB.SEIBETSU = 1 THEN
                         IHOGOSHA_ZOKUGARA1 := 4;
                      ELSIF RB.SEIBETSU = 2 THEN
                         IHOGOSHA_ZOKUGARA1 := 5;
                      END IF;
                  ELSE
                      IHOGOSHA_ZOKUGARA1 := 0;
                  END IF;
              ELSE
                  IF RB.SEIBETSU = 1 THEN
                     IHOGOSHA_ZOKUGARA1 := 4;
                  ELSIF RB.SEIBETSU = 2 THEN
                     IHOGOSHA_ZOKUGARA1 := 5;
                  END IF;
              END IF;
               VHOGOSHA_SHIMEI_GEDAN := RB.SHIMEI_KANJI;    -- 保護者氏名漢字
                -- 保護者との続柄を判定します
                RG.ZOKUGARA1  := 10;
                VZOKUGARAMEI1 := '子';
                IRTN := GKBFKZKGMGET(2,
                                     IHOGOSHA_ZOKUGARA1,
                                     0,
                                     0,
                                     0,
                                     VZOKUGARAMEI2,
                                     IRTNZOKUGARAHERR2);
                IJUSHO_NAGASA := LENGTH(RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI);           

                IF IJUSHO_NAGASA > 20 THEN
                   VJUSHO_JODAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,1,20);   
                   VJUSHO_GEDAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,21,20);  
                ELSE
                   VJUSHO_JODAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,1,20);   
                   VJUSHO_GEDAN := ' ';
                END IF;
            ELSE
                 RG.ZOKUGARA1 := 0;    -- 続柄１（児童）
                 IHOGOSHA_ZOKUGARA1 := 0;
                 RB.SHIMEI_KANA := NULL;
                 RB.SHIMEI_KANJI := NULL;
                 RB.CHOMEI := NULL;
                 RB.BANCHI := NULL;
                 RB.KATAGAKI := NULL;
                 VZOKUGARAMEI1 := NULL;
                 VZOKUGARAMEI2 := NULL;
                 VHOGOSHA_SHIMEI_JODAN := NULL;
                 VHOGOSHA_SHIMEI_GEDAN := NULL;
                 VJUSHO_JODAN := NULL;
                 VJUSHO_GEDAN := NULL;
            END IF;
            IF A_REC.GAKOKU_CD <> 0 THEN
              IF  A_REC.GAKO_KBN = 0 THEN
                 BEGIN
                  SELECT SYOGAKO_CD,
                         SYOGAKOMEI
                    INTO IGAKO_CD,
                         VGAKOMEI
                    FROM GKBTSHOGAKKO
                    WHERE SYOGAKO_CD = A_REC.GAKOKU_CD;
                 EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                   DBMS_OUTPUT.PUT_LINE('該当小学校なし　'||A_REC.GAKOKU_CD||' '||A_REC.KOJIN_NO);
                     IGAKO_CD := A_REC.GAKOKU_CD;
                      VGAKOMEI := ' ';
                 END;
               ELSIF  A_REC.GAKO_KBN = 1 THEN
                BEGIN 
                  SELECT TYUGAKOMEI
                     INTO VGAKOMEI
                     FROM GKBTCHUGAKKO
                     WHERE TYUGAKO_CD = A_REC.GAKOKU_CD;         
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       DBMS_OUTPUT.PUT_LINE('該当中学校なし　'||A_REC.GAKOKU_CD||' '||A_REC.KOJIN_NO);
                       IGAKO_CD := A_REC.GAKOKU_CD;
                       VGAKOMEI := ' ';
                  END;
                END IF;
               VGAKUNENMEI := VGAKUNENSEI || '年生';
          ELSE
              IGAKO_CD := A_REC.GAKOKU_CD;
              VGAKOMEI := ' ';
              VGAKUNENMEI := VGAKUNENSEI || '年生';
          END IF;
              VGYOSEIKU_MEI := GAAPK0030.FGYOSEIKUMEI(A_REC.SANTEIDANTAI_CD,A_REC.GYOSEIKU_CD);

            VHAN_MEI := GAAPK0030.FHANMEI(A_REC.SANTEIDANTAI_CD,
                                           A_REC.HAN_CD);

            IRTN := GAAPK0030.FJICHINAME(A_REC.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);
            NNENDO := TO_NUMBER(VNENDO);   
           -- 年度
            VHYOUJINENDO := KKAPK0020.FNENDOEDIT(1,
                                                  NNENDO,
                                                  3);

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
            MGAKUREIBO_WORK(ICNT).KOJIN_NO := A_REC.KOJIN_NO;
            MGAKUREIBO_WORK(ICNT).RIREKI_RENBAN := A_REC.RIREKI_RENBAN;
            MGAKUREIBO_WORK(ICNT).GENZON_KBN := 0;
            MGAKUREIBO_WORK(ICNT).SAISHIN_KBN := 0;
            MGAKUREIBO_WORK(ICNT).ZO_JIYU_CD := 0;              -- 増事由コード
            MGAKUREIBO_WORK(ICNT).ZO_NENGAPI := IZO_NENGAPI;    -- 増年月日
            MGAKUREIBO_WORK(ICNT).ZOKUGARA1 := RG.ZOKUGARA1;    -- 続柄１（児童）
            MGAKUREIBO_WORK(ICNT).HOGOSYA_KOJIN_NO := IHOGOSHA_KOJIN_NO;
            MGAKUREIBO_WORK(ICNT).HOGOSYA_ZOKUGARA1 := IHOGOSHA_ZOKUGARA1;
            MGAKUREIBO_WORK(ICNT).HOGOSYA_ZOKUGARA2 := 0;
            MGAKUREIBO_WORK(ICNT).HOGOSYA_ZOKUGARA3 := 0;
            MGAKUREIBO_WORK(ICNT).HOGOSYA_ZOKUGARA4 := 0;
            IF A_REC.GAKO_KBN =0  THEN
                MGAKUREIBO_WORK(ICNT).SYOGAKO_CD := A_REC.GAKOKU_CD;
            ELSIF A_REC.GAKO_KBN = 1 THEN
                MGAKUREIBO_WORK(ICNT).TYUGAKO_CD := A_REC.GAKOKU_CD;
            END IF;
            MGAKUNEN_LNK_WORK(ICNT).KOJIN_NO := A_REC.KOJIN_NO;

            MGAKUNEN_LNK_WORK(ICNT).GAKUNEN_CD := 0;

            MJIDO_WORK(ICNT).JIDO_KOJIN_NO := A_REC.KOJIN_NO;
            MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := A_REC.JIDO_SHIMEI_KANA;
            MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := A_REC.SHIMEI_KANJI;
            MJIDO_WORK(ICNT).SEINENGAPI := A_REC.SEINENGAPI;

            MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VSEINENGAPI;

            MJIDO_WORK(ICNT).KANJI_SEINENGAPI := A_REC.HYOJI_SEINENGAPI;
            MJIDO_WORK(ICNT).SEIBETSU := A_REC.SEIBETSU;

            MJIDO_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;
            MJIDO_WORK(ICNT).ZOKUGARAMEI1 := VZOKUGARAMEI1;

            MJIDO_WORK(ICNT).SETAI_NO := A_REC.SETAI_NO;

            MJIDO_WORK(ICNT).HYOJI_SETAI_NO := VSETAI_NO;
            MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO := IHOGOSHA_KOJIN_NO;
            MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RB.SHIMEI_KANA;
            MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := RB.SHIMEI_KANJI;
            MJIDO_WORK(ICNT).ZOKUGARAMEI2 := VZOKUGARAMEI2;

            IF A_REC.GAKO_KBN = 0 THEN
              MJIDO_WORK(ICNT).GAKUNEN_CD := 0;
            ELSIF A_REC.GAKO_KBN=1 THEN
              MJIDO_WORK(ICNT).GAKUNEN_CD := 6;
            END IF;


            MJIDO_WORK(ICNT).GAKUNENMEI := ' ';
            MJIDO_WORK(ICNT).GAKOKU_CD := A_REC.GAKOKU_CD;
            MJIDO_WORK(ICNT).GAKOKUMEI := VGAKOMEI;
            MJIDO_WORK(ICNT).GYOSEIKU_CD := A_REC.GYOSEIKU_CD;
            MJIDO_WORK(ICNT).GYOSEIKU_CD := A_REC.GYOSEIKU_CD;

            MJIDO_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;

            MJIDO_WORK(ICNT).HAN_CD := A_REC.HAN_CD;

            MJIDO_WORK(ICNT).HANMEI := VHAN_MEI;

            MJIDO_WORK(ICNT).SANTEIDANTAI_CD := A_REC.SANTEIDANTAI_CD;

            MJIDO_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;
            IF LENGTH(RB.YUBIN_NO) > 0 AND
               IHOGOSHA_KOJIN_NO <> 0 THEN
              MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(RB.YUBIN_NO,1,3)||'-'||SUBSTR(RB.YUBIN_NO,4);
-- 2024/08/02 ZCZL.wangqiwei Add 0.3.000.001:受入検証対応No.61
              MJIDO_WORK(ICNT).JIDO_YUBIN_NO := MJIDO_WORK(ICNT).YUBIN_NO;
            ELSE
              MJIDO_WORK(ICNT).YUBIN_NO := NULL;
-- 2024/08/02 ZCZL.wangqiwei Add 0.3.000.001:受入検証対応No.61
              MJIDO_WORK(ICNT).JIDO_YUBIN_NO := NULL;
            END IF;
            MJIDO_WORK(ICNT).CHOMEI := RB.CHOMEI;
            MJIDO_WORK(ICNT).BANCHI := RB.BANCHI;
            MJIDO_WORK(ICNT).KATAGAKI := RB.KATAGAKI;
            MJIDO_WORK(ICNT).NENDO := VHYOUJINENDO;
            MJIDO_WORK(ICNT).KAIPEJI_CD := ' ';
            MJIDO_WORK(ICNT).KAIPEJI := ' ';
            MJIDO_WORK(ICNT).SAKUSEIBI := VSASKUSEIBI;
            MJIDO_WORK(ICNT).RENBAN := MAXRENBAN+1;
            MJIDO_WORK(ICNT).HYOJI_RENBAN := TO_CHAR(MJIDO_WORK(ICNT).RENBAN);
            MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := VHOGOSHA_SHIMEI_JODAN;
            MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN := VHOGOSHA_SHIMEI_GEDAN;
            MJIDO_WORK(ICNT).KON_JUSHO_JODAN := VJUSHO_JODAN;
            MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := VJUSHO_GEDAN;
            MJIDO_WORK(ICNT).JIDO_CHOMEI := A_REC.CHOMEI;
            MJIDO_WORK(ICNT).JIDO_BANCHI := A_REC.BANCHI;
            MJIDO_WORK(ICNT).JIDO_KATAGAKI := A_REC.KATAGAKI;
            MJIDO_WORK(ICNT).GAKO_KBN := A_REC.GAKO_KBN;
-- 2024/07/18 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--             IF A_REC.NINIBIT3 > 0 THEN
--               MJIDO_WORK(ICNT).KAGAKUNEN := A_REC.NINIBIT3 || '年';
--             ELSE
--               MJIDO_WORK(ICNT).KAGAKUNEN := '';
--             END IF;
-- 2024/07/18 ZCZL.wangqiwei Delete end
            MJIDO_WORK(ICNT).JINKAKU_KBN := A_REC.JINKAKU_KBN;
-- 2024/07/18 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--             MJIDO_WORK(ICNT).YOCHIEN_CD  := A_REC.YOCHIEN_CD;
--             MJIDO_WORK(ICNT).YOCHIEN_MEI := A_REC.YOCHIEN_MEI;
-- 2024/07/18 ZCZL.wangqiwei Delete end
            MAXRENBAN := MAXRENBAN + 1;
            ICNT := ICNT + 1;               -- カウントアップ
            IFRET := C_ISUCCESS;              -- 正常終了
            END LOOP;
            IF CRSINNYUGAKU%ISOPEN THEN
              CLOSE CRSINNYUGAKU;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF CRSINNYUGAKU%ISOPEN THEN
                   CLOSE CRSINNYUGAKU;
                END IF;
                IFRET := C_INOT_SUCCESS;      -- 異常終了
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
            IF CRSINNYUGAKU%ISOPEN THEN
                CLOSE CRSINNYUGAKU;
            END IF;
            IFRET := C_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            RAISE ERR;
        RETURN IFRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------
    --  機能概要      : 学齢簿および児童生徒ワーク（GKBWJIDOSHINNYUGAKU）テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_INSERT_JIDO_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- 戻り値
        IMAX                BINARY_INTEGER;             -- 戻り値
        IMIN                BINARY_INTEGER;             -- 戻り値
        IJIDOCNT            PLS_INTEGER;                --学齢簿データ有無
        NNENDO               PLS_INTEGER;      -- 年度
        LAST_KAIPEJINM   NVARCHAR2(100);       --前回改ページ項目
        CURRENT_KAIPEIJINM   NVARCHAR2(100);   --今回改ページ項目
       ININIBIT2          PLS_INTEGER;         --NINIBIT2の設定
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
       v_SYSDATE             NUMBER(8);
       v_RIREKI_RENBAN       NUMBER(5);
       v_SAKUDATE            NUMBER(8);
       nRTN                  BINARY_INTEGER;             -- 戻り値
       o_rGABTATENAKIHON     GABTATENAKIHON%ROWTYPE;     --保護者の宛名基本
       o_rGABTSOFUSAKI       GABTSOFUSAKI%ROWTYPE;    --保護者の送付先基本
-- 2024/07/18 ZCZL.wangqiwei Add end
--  2024/09/26 ZCZL.WANGMING ADD START 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
       iSYOGAKO_CD              PLS_INTEGER;      --小学校
       iTYUGAKO_CD              PLS_INTEGER;      --中学校
       BRTN                  BOOLEAN;
--  2024/09/26 ZCZL.WANGMING ADD END
    BEGIN
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
        v_SAKUDATE :=  TO_NUMBER(g_vSYORINENDO) * 10000 + 401 ; -- 小学校入学年月日
        v_SYSDATE  :=  TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) ;
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
--2025/01/03 JIP.Y.SATO DEL ST
--         -- 保護者宛名情報
--         nRTN := GAAPK0030.FGETATENA2(       IHOGOSHA_KOJIN_NO,  --宛名番号
--                                             'GKB',                       --業務コード
--                                             TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),      --基準日
--                                             o_rGABTATENAKIHON,           --保護者宛名
--                                             o_rGABTSOFUSAKI              --保護者送付先
--                                             );
--2025/01/03 JIP.Y.SATO DEL ED
                                             
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
                  INTO g_SYS_TANMATU_BASHO
                  FROM
                    KKNTBK
                  WHERE
                    BUKACODE = sBUKACODE
                    AND KKNTBK.YUKOKIKANFR = (
                                               SELECT MAX(YUKOKIKANFR) FROM KKNTBK WHERE BUKACODE = sBUKACODE
                                              );
                EXCEPTION
                  WHEN OTHERS THEN
                    g_SYS_TANMATU_BASHO := NULL;
                END;
-- 2024/07/18 ZCZL.wangqiwei Add end
        IFRET := C_ISUCCESS;                  -- 正常終了
        -- ワーク領域の最終位置を取得
        IMAX := MGAKUREIBO_WORK.LAST;

        -- ワーク領域の先頭位置を取得
        IMIN := MGAKUREIBO_WORK.FIRST;
        NNENDO :=TO_NUMBER(g_vJYOUKEN1);           -- 年度
        BEGIN
            -- ワーク領域の件数分繰り返し処理を行う
            FOR ICNT IN IMIN..IMAX LOOP
             -- 学齢簿データが存在しない場合のみINSERT
             SELECT COUNT(KOJIN_NO)
               INTO  IJIDOCNT
               FROM GKBTGAKUREIBO
              WHERE KOJIN_NO = MGAKUREIBO_WORK(ICNT).KOJIN_NO;
--  2024/09/26 ZCZL.WANGMING ADD START 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
             --2024/12/27 JIP.Y.SATO UPD ST
             --iSYOGAKO_CD := GKBFKGKCDGET(1, MGAKUREIBO_WORK(ICNT).KOJIN_NO, 999);
             iSYOGAKO_CD := MGAKUREIBO_WORK(ICNT).SYOGAKO_CD;
             --IF iSYOGAKO_CD = -1 THEN
             --   BRTN  :=FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, '', '', '就学指定校の取得に失敗したため異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
             --   RAISE ERR;
             --END IF;
             --iTYUGAKO_CD := GKBFKGKCDGET(2, MGAKUREIBO_WORK(ICNT).KOJIN_NO, 999);
             iTYUGAKO_CD := MGAKUREIBO_WORK(ICNT).TYUGAKO_CD;
             --IF iTYUGAKO_CD = -1 THEN
             --   BRTN  :=FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, '', '', '就学指定校の取得に失敗したため異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
             --   RAISE ERR;
             --END IF;
             --2024/12/27 JIP.Y.SATO UPD ed
--  2024/09/26 ZCZL.WANGMING ADD END
            IF (MJIDO_WORK(ICNT).GAKO_KBN = 0 AND IJIDOCNT = 0) OR  (MJIDO_WORK(ICNT).GAKO_KBN = 1 AND IJIDOCNT > 0) THEN
             IF IJIDOCNT = 0 THEN
                INSERT INTO     --(小学校のみ)
                GKBTGAKUREIBO
                (
                 KOJIN_NO,
                 RIREKI_RENBAN,
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
                 RIREKI_RENBAN_EDA,
                 GENZON_KBN,
                 SAISHIN_KBN,
                 ZO_JIYU_CD,
                 ZO_NENGAPI,
                 GEN_JIYU_CD,
                 GEN_NENGAPI,
                 ZOKUGARA1,
                 ZOKUGARA2,
                 ZOKUGARA3,
                 ZOKUGARA4,
                 HOGOSYA_KOJIN_NO,
                 HOGOSYA_ZOKUGARA1,
                 HOGOSYA_ZOKUGARA2,
                 HOGOSYA_ZOKUGARA3,
                 HOGOSYA_ZOKUGARA4,
                 SYOGAKO_CD,
                 SYOGAKO_NYUGAKU_BI,
                 SYOGAKO_TENNYUGAKU_BI,
                 SYOGAKO_TENGAKU_BI,
                 SYOGAKO_SOTSUGYO_BI,
                 TYUGAKO_CD,
                 TYUGAKO_NYUGAKU_BI,
                 TYUGAKO_TENNYUGAKU_BI,
                 TYUGAKO_TENGAKU_BI,
                 TYUGAKO_SOTSUGYO_BI,
                 TOKUSOKU_BI1,
                 TOKUSOKU_NAIYO1,
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 TOKUSOKU_JIYU1,
                 TOKUSOKU_JURI_BI1,
-- 2024/07/18 ZCZL.wangqiwei Add end
                 TOKUSOKU_BI2,
                 TOKUSOKU_NAIYO2,
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 TOKUSOKU_JIYU2,
                 TOKUSOKU_JURI_BI2,
-- 2024/07/18 ZCZL.wangqiwei Add end
                 TOKUSOKU_BI3,
                 TOKUSOKU_NAIYO3,
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 TOKUSOKU_JIYU3,
                 TOKUSOKU_JURI_BI3,
-- 2024/07/18 ZCZL.wangqiwei Add end
                 TOKUSOKU_BI4,
                 TOKUSOKU_NAIYO4,
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 TOKUSOKU_JIYU4,
                 TOKUSOKU_JURI_BI4,
-- 2024/07/18 ZCZL.wangqiwei Add end
                 TOKUSOKU_BI5,
                 TOKUSOKU_NAIYO5,
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 TOKUSOKU_JIYU5,
                 TOKUSOKU_JURI_BI5,
-- 2024/07/18 ZCZL.wangqiwei Add end
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 TOKUSOKU_BI6,
                 TOKUSOKU_NAIYO6,
                 TOKUSOKU_JIYU6,
                 TOKUSOKU_JURI_BI6,
                 TOKUSOKU_BI7,
                 TOKUSOKU_NAIYO7,
                 TOKUSOKU_JIYU7,
                 TOKUSOKU_JURI_BI7,
                 TOKUSOKU_BI8,
                 TOKUSOKU_NAIYO8,
                 TOKUSOKU_JIYU8,
                 TOKUSOKU_JURI_BI8,
                 TOKUSOKU_BI9,
                 TOKUSOKU_NAIYO9,
                 TOKUSOKU_JIYU9,
                 TOKUSOKU_JURI_BI9,
                 TOKUSOKU_BI10,
                 TOKUSOKU_NAIYO10,
                 TOKUSOKU_JIYU10,
                 TOKUSOKU_JURI_BI10,
-- 2024/07/18 ZCZL.wangqiwei Add end
                 KUIKIGAI_CD,
                 KUIKIGAI_SETISYA,
                 KUIKIGAI_NYUGAKU_BI,
                 KUIKIGAI_TENNYUGAKU_BI,
                 KUIKIGAI_TENGAKU_BI,
                 KUIKIGAI_TAIGAKU_BI,
                 KUIKIGAI_SOTSUGYO_BI,
                 YOGOGAKO_CD,
                 YOGOGAKO_SETISYA,
                 YOGOGAKO_NYUGAKU_BI,
                 YOGOGAKO_TENNYUGAKU_BI,
                 YOGOGAKO_TENGAKU_BI,
                 YOGOGAKO_TAIGAKU_BI,
                 YOGOGAKO_SOTSUGYO_BI,
                 YUYO_KYOKA_BI,
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
                 YUYO_JIYU_CD,
                 YUYO_JIYU,
                 YUYO_KAISI_BI,
                 YUYO_SYURYO_BI,
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
                 YUYO_NENSU,
                 YUYO_FUKUGAKU_BI,
                 MENJO_KYOKA_BI,
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
                 MENJO_JIYU_CD,
                 MENJO_JIYU,
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 MENJO_KAISI_BI,
                 MENJO_SYURYO_BI,
                 MENJO_NENSU,
-- 2024/07/18 ZCZL.wangqiwei Add end
                 MENJO_FUKUGAKU_BI,
                 IDO_BI1,
                 IDO_JIYU1,
                 IDO_BI2,
                 IDO_JIYU2,
                 IDO_BI3,
                 IDO_JIYU3,
                 IDO_BI4,
                 IDO_JIYU4,
                 IDO_BI5,
                 IDO_JIYU5,
                 IDO_BI6,
                 IDO_JIYU6,
                 IDO_BI7,
                 IDO_JIYU7,
                 IDO_BI8,
                 IDO_JIYU8,
                 IDO_BI9,
                 IDO_JIYU9,
                 IDO_BI10,
                 IDO_JIYU10,
                 SYS_SAKUSEIBI,
                 SYS_KOSHINBI,
                 SYS_JIKAN,
                 SYS_SHOKUINKOJIN_NO,
                 SYS_TANMATU_NO
                ,GAKUNEN
                ,SHORIBI
                ,SHUGAKU
                ,IDOJIKO
                ,CHOHYO_NO
                ,SYOGAKO_TENNYUGAKU_GAKUNEN
                ,SYOGAKO_TENGAKU_GAKUNEN
                ,TYUGAKO_TENNYUGAKU_GAKUNEN
                ,TYUGAKO_TENGAKU_GAKUNEN
                ,KUIKIGAI_TENNYUGAKU_GAKUNEN
                ,KUIKIGAI_TENGAKU_GAKUNEN
                ,KUIKIGAI_TAIGAKU_GAKUNEN
                ,YOGOGAKO_TENNYUGAKU_GAKUNEN
                ,YOGOGAKO_TENGAKU_GAKUNEN
                ,YOGOGAKO_TAIGAKU_GAKUNEN
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 ,GAKKO_KBN_CD,
                 GAKUKYU_CD,
                 SEIBETSU,
                 JOTAI,
                 TENNYUMAE_GAKKO_KBN,
                 TENNYUMAE_GAKKO_CD,
                 TENNYUMAE_GAKUNEN,
                 GENKYURYUCHI_FLG,
                 GENKYURYUCHI_KETTEI_BI,
                 GENKYURYUCHI_KAISI_BI,
                 GENKYURYUCHI_SYURYOBI,
                 GENKYURYUCHI_RIYU,
                 SHITEI_SYOGAKO_CD,
                 SHITEI_TYUGAKO_CD,
                 HENKO_GAKUNEN_SYOGAKO,
                 HENKO_GAKUNEN_TYUGAKO,
                 HENKO_SHINSEI_BI,
                 HENKO_KYOKA_BI,
                 HENKO_KBN,
                 HENKO_KAISI_BI,
                 HENKO_SYURYO_BI,
                 HENKO_KYOKA_RIYU,
                 HENKO_JIYU,
                 HENKO_HUKYOKA_RIYU,
                 KIBO_GAKKO_KBN_CD,
                 KIBO_SYOGAKKO_CD,
                 KIBO_TYUGAKKO_CD,
                 KIBO_UKETSUKE_BI_SYOGAKO,
                 KIBO_UKETSUKE_BI_TYUGAKO,
                 KUIKIGAISHUGAKU_FLG,
                 KUIKIGAISHUGAKU_SHINSEI_BI,
                 KUIKIGAISHUGAKU_KYOKA_BI,
                 KUIKIGAISHUGAKU_KAISI_BI,
                 KUIKIGAISHUGAKU_SYURYO_BI,
                 KUIKIGAISHUGAKU_JIYU,
                 KUIKIGAISHUGAKU_KYOKA_RIYU,
                 KUIKIGAISHUGAKU_HUKYOKA_RIYU,
                 HUSHUGAKU_KAISI_BI,
                 HUSHUGAKU_SYURYO_BI,
                 HUSHUGAKU_RIYU,
                 KUNISHIRITSU_CD,
                 KUNISHIRITSU_NYUGAKU_BI,
                 KUNISHIRITSU_TENNYUGAKU_BI,
                 KUNISHIRITSU_TENNYUGAKU_GAKUNEN,
                 KUNISHIRITSU_TENGAKU_BI,
                 KUNISHIRITSU_TENGAKU_GAKUNEN,
                 KUNISHIRITSU_TAIGAKU_BI,
                 KUNISHIRITSU_TAIGAKU_GAKUNEN,
                 KUNISHIRITSU_SOTSUGYO_BI,
                 KUNISHIRITSU_KAISI_BI,
                 KUNISHIRITSU_SYURYO_BI,
                 TSUSHOMEI_KANA,
                 TSUSHOMEI_KANJI,
                 HOGOSYA_TSUSHOMEI_KANA,
                 HOGOSYA_TSUSHOMEI_KANJI,
                 GRB_HENKO_TODOKEDE_BI,
                 GRB_HENKO_BI,
                 GRB_HENKO_JIYU,
                 BIKO,
                 IDO_BI,
                 TODOKEDE_BI,
                 SHINSEI_KANRI_RENBAN,
                 IDOJI_ATENA_RIREKI_RENBAN,
                 HOGOSYA_IDOJI_RIREKI_RENBAN,
                 SHOGAKKOKU_CD,
                 CHUGAKKOKU_CD,
                 SAKUJO_FLG,
                 SYS_TANMATU_BASHO
-- 2024/07/18 ZCZL.wangqiwei Add end
                )
                VALUES
                (
                MGAKUREIBO_WORK(ICNT).KOJIN_NO,
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--                 MGAKUREIBO_WORK(ICNT).RIREKI_RENBAN,
                10,
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
                0,
                MGAKUREIBO_WORK(ICNT).GENZON_KBN,
                MGAKUREIBO_WORK(ICNT).SAISHIN_KBN,
                MGAKUREIBO_WORK(ICNT).ZO_JIYU_CD,
                MGAKUREIBO_WORK(ICNT).ZO_NENGAPI,
                0,
                0,
                MGAKUREIBO_WORK(ICNT).ZOKUGARA1,    -- 続柄１（児童）
                0,
                0,
                0,
                MGAKUREIBO_WORK(ICNT).HOGOSYA_KOJIN_NO,
                MGAKUREIBO_WORK(ICNT).HOGOSYA_ZOKUGARA1,
                MGAKUREIBO_WORK(ICNT).HOGOSYA_ZOKUGARA2,
                MGAKUREIBO_WORK(ICNT).HOGOSYA_ZOKUGARA3,
                MGAKUREIBO_WORK(ICNT).HOGOSYA_ZOKUGARA4,
-- 2024/07/18 ZCZL.wangqiwei Update  0.3.000.000:新WizLIFE2次開発
--                 MGAKUREIBO_WORK(ICNT).SYOGAKO_CD,
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--                MGAKUREIBO_WORK(ICNT).SHITEI_SYOGAKO_CD,
                iSYOGAKO_CD,
-- 2024/07/18 ZCZL.wangqiwei Update  0.3.000.000:新WizLIFE2次開発
--2025/01/03 JIP.Y.SATO UPD ST
                ISYOGAKO_NYUGAKU_BI,    -- 小学校入学年月日
--                0,
--2025/01/03 JIP.Y.SATO UPD ED
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                ' ',
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                0,
                0,
-- 2024/07/18 ZCZL.wangqiwei Add end
                0,
                ' ',
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                0,
                0,
-- 2024/07/18 ZCZL.wangqiwei Add end
                0,
                ' ',
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                0,
                0,
-- 2024/07/18 ZCZL.wangqiwei Add end
                0,
                ' ',
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                0,
                0,
-- 2024/07/18 ZCZL.wangqiwei Add end
                0,
                ' ',
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                0,
                0,
                0,
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--                0,
                NULL,
                0,
                0,
                0,
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--                0,
                NULL,
                0,
                0,
                0,
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--                0,
                NULL,
                0,
                0,
                0,
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--                0,
                NULL,
                0,
                0,
                0,
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--                0,
                NULL,
                0,
                0,
-- 2024/07/18 ZCZL.wangqiwei Add end
                0,
                ' ',
                0,
                0,
                0,
                0,
                0,
                0,
                ' ',
                0,
                0,
                0,
                0,
                0,
                0,
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
                0,
                ' ',
                0,
                0,
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
                0,
                0,
                0,
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
                0,
                ' ',
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
                0,
                0,
                0,
-- 2024/07/18 ZCZL.wangqiwei Add end
                0,
                0,
                ' ',
                0,
                ' ',
                0,
                ' ',
                0,
                ' ',
                0,
                ' ',
                0,
                ' ',
                0,
                ' ',
                0,
                ' ',
                0,
                ' ',
                0,
                ' ',
                ISAKUSEIBI,         -- 作成日
--2024/12/27 JIP.Y.SATO UPD ST
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
                ISAKUSEIBI,         --システム処理日(ISAKUSEIBI)
--                0,
--2024/12/27 JIP.Y.SATO UPD ED
                NSYSTIME,           -- 時間
                g_sTANTOCODE,       -- 職員番号
                g_sWSNUM            -- 端末番号
                ,0
                ,ISAKUSEIBI
                ,NULL
                ,NULL
                ,DECODE(NRENBAN,0,MKOSHINLOG_WORK(ICNT).JOKEN3,NULL)--  帳票連番セット
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
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                ,1,
                0,
                MGAKUREIBO_WORK(ICNT).SEIBETSU,
                1,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
--2024/12/27 JIP.Y.SATO UPD ST
--  2024/09/26 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
                MGAKUREIBO_WORK(ICNT).SHITEI_SYOGAKO_CD,
                MGAKUREIBO_WORK(ICNT).SHITEI_TYUGAKO_CD,
--                iSYOGAKO_CD,
--                iTYUGAKO_CD,
--  2024/09/26 ZCZL.WANGMING UPDATE END
--2024/12/27 JIP.Y.SATO UPD ED
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                NULL,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                NULL,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                NULL,
                NULL,
                NULL,
                NULL,
                v_SYSDATE,
                v_SYSDATE,
                01,
                NULL,
                v_SYSDATE,
                v_SYSDATE,
                0,
                MGAKUREIBO_WORK(ICNT).IDOJI_ATENA_RIREKI_RENBAN,
                --2025/01/03 JIP.Y.SATO UPD ST
                --o_rGABTATENAKIHON.Rireki_Renban,
                MGAKUREIBO_WORK(ICNT).HOGOSYA_IDOJI_RIREKI_RENBAN,
                --2025/01/03 JIP.Y.SATO UPD ED
                MGAKUREIBO_WORK(ICNT).SHOGAKKOKU_CD,
                MGAKUREIBO_WORK(ICNT).CHUGAKKOKU_CD,
                0,
                g_SYS_TANMATU_BASHO
-- 2024/07/18 ZCZL.wangqiwei Add end
                );
             ELSIF IJIDOCNT > 0 AND MJIDO_WORK(ICNT).GAKO_KBN = 1 THEN  --(中学校のみ)
               UPDATE GKBTGAKUREIBO   SET
--2024/12/27 JIP.Y.SATO UPD ST
-- 2024/07/18 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
                           TYUGAKO_CD = DECODE(TYUGAKO_CD ,0,MGAKUREIBO_WORK(ICNT).TYUGAKO_CD,TYUGAKO_CD),  -- 中学校コード   
--                           TYUGAKO_CD =  CASE WHEN MGAKUREIBO_WORK(ICNT).KUIKIGAISHUGAKU_SYURYO_BI <= v_SAKUDATE
--                                                OR MGAKUREIBO_WORK(ICNT).KUNISHIRITSU_SYURYO_BI    <= v_SAKUDATE
--                                              THEN 0 
----  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
----                                              ELSE MGAKUREIBO_WORK(ICNT).SHITEI_TYUGAKO_CD 
--                                              ELSE iTYUGAKO_CD
--                                              END,
-- 2024/07/18 ZCZL.wangqiwei Update end
--2024/12/27 JIP.Y.SATO UPD ED
                           SYS_KOSHINBI = ISAKUSEIBI,            -- システム処理日
                           SYS_JIKAN = NSYSTIME ,                -- システム処理時間
                           SYS_SHOKUINKOJIN_NO = g_sTANTOCODE,  -- バッチ処理実行時の職員番号
                           SYS_TANMATU_NO = g_sWSNUM,      -- バッチ処理実行時の端末番号
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
                           SHORIBI = v_SYSDATE ,           -- 処理日
                           CHOHYO_NO = DECODE(NRENBAN,0,MKOSHINLOG_WORK(ICNT).JOKEN3,NULL) ,-- 帳票連番セット
-- 2024/07/18 ZCZL.wangqiwei Add  start 0.3.000.000:新WizLIFE2次開発
                           SHITEI_SYOGAKO_CD = MGAKUREIBO_WORK(ICNT).SHITEI_SYOGAKO_CD ,  -- 就学指定校_小学校
--  2024/09/26 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--                           SHITEI_TYUGAKO_CD = MGAKUREIBO_WORK(ICNT).SHITEI_TYUGAKO_CD ,  -- 就学指定校_中学校
                           SHITEI_TYUGAKO_CD = iTYUGAKO_CD ,                              -- 就学指定校_中学校
                           GRB_HENKO_TODOKEDE_BI = v_SYSDATE ,                            -- 学齢簿変更_届出年月日
                           GRB_HENKO_BI          = v_SYSDATE ,                            -- 学齢簿変更_年月日
                           IDO_BI                = v_SYSDATE ,                            -- 異動年月日
                           TODOKEDE_BI           = v_SYSDATE ,                            -- 届出年月日
                           SHOGAKKOKU_CD         = MGAKUREIBO_WORK(ICNT).SHOGAKKOKU_CD ,  -- 小学校区コード
                           CHUGAKKOKU_CD         = MGAKUREIBO_WORK(ICNT).CHUGAKKOKU_CD ,  -- 中学校区コード
                           SYS_TANMATU_BASHO     = g_SYS_TANMATU_BASHO                    -- 入力端末_入力場所
-- 2024/07/18 ZCZL.wangqiwei Add end
                WHERE
                      KOJIN_NO = MGAKUREIBO_WORK(ICNT).KOJIN_NO 
                      AND RIREKI_RENBAN = MGAKUREIBO_WORK(ICNT).RIREKI_RENBAN;
            END IF;
          END IF;
            END LOOP;
            COMMIT;

            FOR ICNT IN IMIN..IMAX LOOP
             SELECT COUNT(KOJIN_NO)
               INTO  IJIDOCNT
               FROM GKBTGAKUNENLNK
              WHERE KOJIN_NO = MGAKUREIBO_WORK(ICNT).KOJIN_NO;

             IF IJIDOCNT = 0 THEN         
                INSERT INTO
                GKBTGAKUNENLNK
                (
                 KOJIN_NO,
                 GAKUNEN_CD ,
                 SYS_SAKUSEIBI,
                 SYS_KOSHINBI,
                 SYS_JIKAN,
                 SYS_SHOKUINKOJIN_NO,
                 SYS_TANMATU_NO
                )
                VALUES
                (
                 MGAKUNEN_LNK_WORK(ICNT).KOJIN_NO,
                 0,
                 ISAKUSEIBI,         -- 作成日
                 0,
                 NSYSTIME,           -- 時間
                 g_sTANTOCODE,      -- 職員番号
                 g_sWSNUM      -- 端末番号
                );
             END IF;
-- 2024/07/18 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発
--              任意ビット(GKBTNINIBIT)の追加
--              SELECT COUNT(KOJIN_NO)
--                INTO  IJIDOCNT
--                FROM GKBTNINIBIT
--              WHERE KOJIN_NO = MGAKUREIBO_WORK(ICNT).KOJIN_NO
--                AND RIREKI_RENBAN = MGAKUREIBO_WORK(ICNT).RIREKI_RENBAN;
--              IF o_SINNYUGAKU_PRM(1) = 1 AND MATENAKIHON_WORK(ICNT).JINKAKU_KBN = 1 THEN
--                  ININIBIT2 := 1;
--              ELSE
--                  ININIBIT2 := 0;
--              END IF;
--              IF IJIDOCNT = 0 THEN
--                INSERT INTO
--                GKBTNINIBIT
--                (
--                KOJIN_NO
--                ,RIREKI_RENBAN
--                ,NINIBIT1
--                ,NINIBIT2
--                ,NINIBIT3
--                ,NINIBIT4
--                ,NINIBIT5
--                ,NINIBIT6
--                ,NINIBIT7
--                ,NINIBIT8
--                ,NINIBIT9
--                ,NINIBIT10
--                ,NINIBIT11
--                ,NINIBIT12
--                ,NINIBIT13
--                ,NINIBIT14
--                ,NINIBIT15
--                ,NINIBIT16
--                ,NINIBIT17
--                ,NINIBIT18
--                ,NINIBIT19
--                ,NINIBIT20
--                ,SYS_SAKUSEIBI
--                ,SYS_KOSHINBI
--                ,SYS_JIKAN
--                ,SYS_SHOKUINKOJIN_NO
--                ,SYS_TANMATU_NO
--                )
--                VALUES
--                (
--                MNINIBIT_WORK(ICNT).KOJIN_NO
--                ,10
--                ,0
--                ,ININIBIT2
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,0
--                ,ISAKUSEIBI     -- システム処理日
--                ,0
--                ,NSYSTIME       -- システム処理時間
--                ,g_sTANTOCODE  -- バッチ処理実行時の職員番号
--                ,g_sWSNUM -- バッチ処理実行時の端末番号
--                );
--              END IF;
-- 2024/07/18 ZCZL.wangqiwei Delete end
            END LOOP;
            COMMIT;
          FOR ICNT IN IMIN..IMAX LOOP
                    INSERT INTO GKBWJIDOSHINNYUGAKU
    (
                 JIDO_KOJIN_NO,
                 JIDO_SHIMEI_KANA,
                 JIDO_SHIMEI_KANJI,
                 SEINENGAPI,
                 HYOJI_SEINENGAPI,
                 KANJI_SEINENGAPI,
                 SEIBETSU,
                 HYOJI_SEIBETSU,
                 ZOKUGARAMEI1,
                 SETAI_NO,
                 HYOJI_SETAI_NO,
                 HOGOSHA_KOJIN_NO,
                 HOGOSHA_SHIMEI_KANA,
                 HOGOSHA_SHIMEI_KANJI,
                 ZOKUGARAMEI2,
                 GAKUNEN_CD,
                 GAKUNENMEI,
                 GAKOKU_CD,
                 GAKOKUMEI,
                 GYOSEIKU_CD,
                 GYOSEIKUMEI,
                 HAN_CD,
                 HANMEI,
                 SANTEIDANTAI_CD,
                 SANTEIDANTAIMEI,
                 YUBIN_NO,
                 CHOMEI,
                 BANCHI,
                 KATAGAKI,
                 NENDO,
                 KAIPEJI_CD,
                 KAIPEJI,
                 SAKUSEIBI,
                 RENBAN,
                 HYOJI_RENBAN,
                 HOGOSHA_SHIMEI_JODAN,
                 HOGOSHA_SHIMEI_GEDAN,
                 KON_JUSHO_JODAN,
                 KON_JUSHO_GEDAN,
                 JIDO_CHOMEI,
                 JIDO_BANCHI,
                 JIDO_KATAGAKI
                 ,GAKO_KBN
                 ,KAGAKUNEN
                 ,JINKAKU_KBN
                 ,YOCHIEN_CD
                 ,YOCHIEN_MEI
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                 ,TSUSHOMEI_KANA,
                 TSUSHOMEI_KANJI,
                 ATENA_RIREKI_RENBAN,
                 JIDO_KOKUSEKI_CD,
                 JIDO_KOKUSEKI_MEI,
                 JIDO_YUBIN_NO,
                 JIDO_KON_JUSHO,
                 HOGOSHA_KOKUSEKI_CD,
                 HOGOSHA_KOKUSEKI_MEI
-- 2024/07/18 ZCZL.wangqiwei Add end
                )
                VALUES
                (
                 MJIDO_WORK(ICNT).JIDO_KOJIN_NO,
                 MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA,
                 MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI,
                 MJIDO_WORK(ICNT).SEINENGAPI,
                 MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,
                 MJIDO_WORK(ICNT).KANJI_SEINENGAPI,
                 MJIDO_WORK(ICNT).SEIBETSU,
                 MJIDO_WORK(ICNT).HYOJI_SEIBETSU,
                 MJIDO_WORK(ICNT).ZOKUGARAMEI1,
                 MJIDO_WORK(ICNT).SETAI_NO,
                 MJIDO_WORK(ICNT).HYOJI_SETAI_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI,
                 MJIDO_WORK(ICNT).ZOKUGARAMEI2,
                 MJIDO_WORK(ICNT).GAKUNEN_CD,
                 MJIDO_WORK(ICNT).GAKUNENMEI,
                 MJIDO_WORK(ICNT).GAKOKU_CD,
                 MJIDO_WORK(ICNT).GAKOKUMEI,
                 MJIDO_WORK(ICNT).GYOSEIKU_CD,
                 MJIDO_WORK(ICNT).GYOSEIKUMEI,
                 MJIDO_WORK(ICNT).HAN_CD,
                 MJIDO_WORK(ICNT).HANMEI,
                 MJIDO_WORK(ICNT).SANTEIDANTAI_CD,
                 MJIDO_WORK(ICNT).SANTEIDANTAIMEI,
                 MJIDO_WORK(ICNT).YUBIN_NO,
                 MJIDO_WORK(ICNT).CHOMEI,
                 MJIDO_WORK(ICNT).BANCHI,
                 MJIDO_WORK(ICNT).KATAGAKI,
                 MJIDO_WORK(ICNT).NENDO,
                 MJIDO_WORK(ICNT).KAIPEJI_CD,
                 MJIDO_WORK(ICNT).KAIPEJI,
                 MJIDO_WORK(ICNT).SAKUSEIBI,
                 MJIDO_WORK(ICNT).RENBAN,
                 MJIDO_WORK(ICNT).HYOJI_RENBAN,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN,
                 MJIDO_WORK(ICNT).KON_JUSHO_JODAN,
                 MJIDO_WORK(ICNT).KON_JUSHO_GEDAN,
                 MJIDO_WORK(ICNT).JIDO_CHOMEI,
                 MJIDO_WORK(ICNT).JIDO_BANCHI,
                 MJIDO_WORK(ICNT).JIDO_KATAGAKI
                ,MJIDO_WORK(ICNT).GAKO_KBN
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--                 ,MJIDO_WORK(ICNT).KAGAKUNEN
                ,NULL
                ,MJIDO_WORK(ICNT).JINKAKU_KBN
-- 2024/07/18 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--                 ,MJIDO_WORK(ICNT).YOCHIEN_CD
--                 ,MJIDO_WORK(ICNT).YOCHIEN_MEI
                ,NULL
                ,NULL,
-- 2024/07/18 ZCZL.wangqiwei Update end 
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                MJIDO_WORK(ICNT).TSUSHOMEI_KANA,
                MJIDO_WORK(ICNT).TSUSHOMEI_KANJI,
                MJIDO_WORK(ICNT).ATENA_RIREKI_RENBAN,
                MJIDO_WORK(ICNT).JIDO_KOKUSEKI_CD,
                MJIDO_WORK(ICNT).JIDO_KOKUSEKI_MEI,
                MJIDO_WORK(ICNT).JIDO_YUBIN_NO,
                NULL,
                MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_CD,
                MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_MEI
-- 2024/07/18 ZCZL.wangqiwei Update end
                );
           END LOOP;

         COMMIT;

               -- MAX連番の更新処理

              IF NRENBAN = 0 THEN
                  FOR ICNT IN IMIN..IMAX LOOP 
                    IF o_RENBAN_PRM(1) IN (2,3)THEN             -- JOKEN3(MAX連番)を編集
                      CURRENT_KAIPEIJINM := MJIDO_WORK(ICNT).GAKO_KBN || MJIDO_WORK(ICNT).GAKOKU_CD;
                    ELSIF o_RENBAN_PRM(1) IN (4,5) THEN
                     CURRENT_KAIPEIJINM := MJIDO_WORK(ICNT).GAKO_KBN || MJIDO_WORK(ICNT).GAKOKU_CD || MJIDO_WORK(ICNT).GYOSEIKU_CD;
                    ELSE
                      CURRENT_KAIPEIJINM := NULL;
                    END IF;

                    IF (LAST_KAIPEJINM <> CURRENT_KAIPEIJINM AND ICNT <> IMIN AND CURRENT_KAIPEIJINM IS NOT NULL) THEN
                       -- 初回以外の場合、改ページ項目を変更するとき、
                       -- テーブルにMAX連番を更新する。
                      BRTN := FUNC_UPDATE_MAXRENBAN( MJIDO_WORK(ICNT-1).GAKO_KBN,NNENDO,MJIDO_WORK(ICNT-1).GAKOKU_CD,MJIDO_WORK(ICNT-1).GYOSEIKU_CD,MJIDO_WORK(ICNT-1).RENBAN);
                          LAST_KAIPEJINM := CURRENT_KAIPEIJINM;
                     END IF;
                     IF ICNT = IMAX THEN 
                          IF o_RENBAN_PRM(1) IN (2,3,4,5) THEN 
                              BRTN := FUNC_UPDATE_MAXRENBAN( MJIDO_WORK(ICNT).GAKO_KBN,NNENDO,MJIDO_WORK(ICNT).GAKOKU_CD,MJIDO_WORK(ICNT).GYOSEIKU_CD,MJIDO_WORK(ICNT).RENBAN);
                           ELSE
                              BRTN := FUNC_UPDATE_MAXRENBAN( 9,NNENDO,MJIDO_WORK(ICNT).GAKOKU_CD,MJIDO_WORK(ICNT).GYOSEIKU_CD,MJIDO_WORK(ICNT).RENBAN);
                           END IF;
                     END IF;
                     IF ( CURRENT_KAIPEIJINM IS NOT NULL AND LAST_KAIPEJINM IS NULL ) THEN
                        LAST_KAIPEJINM := CURRENT_KAIPEIJINM;
                     END IF;
                 END LOOP;
               END IF;


         COMMIT;
              --更新ログ(GKBTKOSHINLOG)の基準日の更新
                 SELECT COUNT(GYOMU_SUBCD) INTO IJIDOCNT FROM GKBTKOSHINLOG 
                  WHERE GYOMU_SUBCD = 0 
                    AND  GROUPKEY = 1
                    AND  RENBAN = 1
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--                     AND  SHORI_RENBAN = 2
                    AND  SHORI_RENBAN = 3
                    AND  NENDO = NNENDO;

                  IF IJIDOCNT = 0 THEN
                   INSERT INTO GKBTKOSHINLOG   --更新ログテーブル
                               (
                                GYOMU_SUBCD,
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
                                JOKEN5
                               )
                    VALUES( 
                                0,
                                1,
                                1,
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--                                 2,
                                3,
                                NNENDO,      -- 処理条件1.対象年度(GYY)
-- 2024/07/18 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--                                 'CHOHYO_NO',
--                                 '帳票連番基準日',
                                'GKBPC00400',
                                '新入学児童学齢簿作成処理',
-- 2024/07/18 ZCZL.wangqiwei Update
                                ISAKUSEIBI,   -- システム処理日
                                NSYSTIME,     -- システム処理時間
                                0,
                                0,
                                0
                                );
                  ELSIF IJIDOCNT > 0 THEN 
                    UPDATE GKBTKOSHINLOG   SET --更新ログテーブル
                                JOKEN1 = ISAKUSEIBI,    -- システム処理日
                                JOKEN2 = NSYSTIME       -- システム処理時間
                     WHERE
                           GYOMU_SUBCD = 0 
                           AND GROUPKEY = 1
                           AND RENBAN = 1
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--                            AND SHORI_RENBAN = 2
                           AND SHORI_RENBAN = 3
                           AND NENDO = NNENDO;  -- 処理条件1.対象年度(GYY)
                  END IF;
                COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;       -- 処理前に戻す

                IFRET := C_INOT_SUCCESS;      -- 異常終了
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
            ROLLBACK;       -- 処理前に戻す
            IFRET := C_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            RAISE ERR;
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------
    --  機能概要      : 児童生徒ワーク（CSV）テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        VSQL                NVARCHAR2(10000);           -- ＳＱＬ文
        VSQLSEL             NVARCHAR2(9000);            -- ＳＱＬのソート以外
        VSQLORDER           NVARCHAR2(1000);            -- ＳＱＬの［ORDER BY］句
        I_CUR               PLS_INTEGER;                -- カーソル
        RREC                GKBWJIDOSHINNYUGAKU%ROWTYPE;      -- 児童生徒ワークのレコード変数
        NROWS               NUMBER;                     --
        IPAGECNT            PLS_INTEGER;                -- 頁数
        IGYOCNT             PLS_INTEGER;                -- 行番号
        IGYORENBAN          PLS_INTEGER;                -- 行連番
        VPAGENAME           NVARCHAR2(500);             -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(500);             -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(500);             -- 改頁項目値のワーク
    BEGIN
        FRET := C_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IGYOCNT := 0;
        ICNT := 0;
        MJIDO_WORK.DELETE;                   -- ワーク領域の初期化
        MGAKUREIBO_WORK.DELETE;
        MGAKUNEN_LNK_WORK.DELETE;
        MKOSHINLOG_WORK.DELETE;
-- 2024/07/18 ZCZL.wangqiwei Delete 0.3.000.000:新WizLIFE2次開発
--         MNINIBIT_WORK.DELETE;
        -- ソート条件取得
         IF NRENBAN = 0 THEN
            VSQLORDER := ' GAKO_KBN,GAKOKU_CD,GYOSEIKU_CD ';
         ELSE
           IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
              -- ［ORDER BY］句を付加
              VSQLORDER :=  g_rJSTP.ORDERBYCLAUSE;
           END IF;
         END IF;
        -- ［ORDER BY］句を付加

        VSQLORDER := ' ORDER BY ' || VSQLORDER;
        
        VPAGEFD := ' GAKO_KBN||GAKOKU_CD ';
        VPAGENM := ' GAKOKUMEI ';

        BEGIN

            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'NENDO, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
            VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
            VSQLSEL := VSQLSEL || 'RENBAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'KANJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAIMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_CHOMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_BANCHI, ';
            VSQLSEL := VSQLSEL || 'JIDO_KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'GAKOKUMEI, ';
            IF NRENBAN = 0 THEN -- 処理条件4[帳票連番使用有無]が0の場合
              IF o_RENBAN_PRM(1) IN (1,2,3) THEN -- 連番印字制御.制御ﾊﾟﾗﾒｰﾀ(1)が (1,2,3)の場合
                VSQLSEL := VSQLSEL || 'GAKO_KBN  || GAKOKU_CD'|| ' PAGE_FIELD, ';
                VSQLSEL := VSQLSEL || 'GAKOKUMEI'|| ' PAGE_NAME, ';
              ELSIF o_RENBAN_PRM(1) IN (4,5) THEN -- 連番印字制御.制御ﾊﾟﾗﾒｰﾀ(1)が (4,5)の場合
                VSQLSEL := VSQLSEL || 'GAKO_KBN || GAKOKU_CD || GYOSEIKU_CD '|| ' PAGE_FIELD, ';
                VSQLSEL := VSQLSEL || 'GAKOKUMEI || ''  '' ||  GYOSEIKUMEI '|| ' PAGE_NAME, ';
              ELSE
                VSQLSEL := VSQLSEL ||  'NULL AS PAGE_FIELD, ';     -- 改頁値を設定
                VSQLSEL := VSQLSEL ||  'NULL AS PAGE_NAME, ';      -- 改頁名を設定
              END IF;
            ELSE
                VSQLSEL := VSQLSEL ||  VPAGEFD || ' PAGE_FIELD, ';     -- 改頁値を設定
                VSQLSEL := VSQLSEL ||  VPAGENM || ' PAGE_NAME, ';      -- 改頁名を設定
            END IF;
            VSQLSEL := VSQLSEL || 'JIDO_HONMYO_KANA, ';
            VSQLSEL := VSQLSEL || 'JIDO_HONMYO_KANJI, ';
            VSQLSEL := VSQLSEL || 'YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'GAKOKU_CD, ';
            VSQLSEL := VSQLSEL || 'JIDO_KOJIN_NO, ';
            VSQLSEL := VSQLSEL || 'KAGAKUNEN, ';
            VSQLSEL := VSQLSEL || 'JINKAKU_KBN ';
            VSQLSEL := VSQLSEL || ',YOCHIEN_CD ';
            VSQLSEL := VSQLSEL || ',YOCHIEN_MEI ';
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
            VSQLSEL := VSQLSEL || ',TSUSHOMEI_KANA ';
            VSQLSEL := VSQLSEL || ',TSUSHOMEI_KANJI ';
            VSQLSEL := VSQLSEL || ',ATENA_RIREKI_RENBAN ';
            --  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START
            --VSQLSEL := VSQLSEL || ',JIDO_KOKUSEKI_CD ';
            VSQLSEL := VSQLSEL || ',GAKUNEN_CD ';
            --  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END
            VSQLSEL := VSQLSEL || ',JIDO_KOKUSEKI_MEI ';
            VSQLSEL := VSQLSEL || ',JIDO_YUBIN_NO ';
            VSQLSEL := VSQLSEL || ',JIDO_KON_JUSHO ';
            VSQLSEL := VSQLSEL || ',HOGOSHA_KOKUSEKI_CD ';
            VSQLSEL := VSQLSEL || ',HOGOSHA_KOKUSEKI_MEI ';
-- 2024/07/18 ZCZL.wangqiwei Add end
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWJIDOSHINNYUGAKU ';
--  2024/11/20 JPJYS.LIUHUAIQI ADD 0.3.000.005:IT_GKB_00511対応 Start
            VSQLSEL := VSQLSEL || VSQLORDER;
--  2024/11/20 JPJYS.LIUHUAIQI ADD 0.3.000.005:IT_GKB_00511対応 End
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL ;

            -- カーソルのオープン
            I_CUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(I_CUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, RREC.NENDO, 10);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, RREC.KAIPEJI, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.SAKUSEIBI, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.RENBAN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.JIDO_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.JIDO_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.HYOJI_SEIBETSU, 2);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.HOGOSHA_SHIMEI_JODAN, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.HOGOSHA_SHIMEI_GEDAN, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.ZOKUGARAMEI1, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.ZOKUGARAMEI2, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.HYOJI_SEINENGAPI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.KANJI_SEINENGAPI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.KON_JUSHO_JODAN, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.KON_JUSHO_GEDAN, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.GYOSEIKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.SANTEIDANTAIMEI, 20);
-- 2024/07/18 ZCZL.wangqiwei UPDATE start 0.3.000.000:新WizLIFE2次開発
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.JIDO_CHOMEI, 40);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.JIDO_BANCHI, 40);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.JIDO_KATAGAKI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.JIDO_CHOMEI, 136);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.JIDO_BANCHI, 50);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.JIDO_KATAGAKI, 300);
-- 2024/07/18 ZCZL.wangqiwei Update end
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.HOGOSHA_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.GAKOKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, VPAGENM, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.JIDO_HONMYO_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.JIDO_HONMYO_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.YUBIN_NO, 10);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, RREC.GAKOKU_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, RREC.JIDO_KOJIN_NO);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, RREC.KAGAKUNEN, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, RREC.JINKAKU_KBN);            
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, RREC.YOCHIEN_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 34, RREC.YOCHIEN_MEI, 180);
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 35, RREC.TSUSHOMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 36, RREC.TSUSHOMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 37, RREC.ATENA_RIREKI_RENBAN);
            --  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START
            --DBMS_SQL.DEFINE_COLUMN(I_CUR, 38, RREC.JIDO_KOKUSEKI_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 38, RREC.GAKUNEN_CD);
            --  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 39, RREC.JIDO_KOKUSEKI_MEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 40, RREC.JIDO_YUBIN_NO, 10);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 41, RREC.JIDO_KON_JUSHO, 486);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 42, RREC.HOGOSHA_KOKUSEKI_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 43, RREC.HOGOSHA_KOKUSEKI_MEI, 60);
-- 2024/07/18 ZCZL.wangqiwei Add end
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(I_CUR);
            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(I_CUR) > 0 THEN

                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  1, MJIDO_WORK(ICNT).NENDO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  2, MJIDO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  3, MJIDO_WORK(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  4, MJIDO_WORK(ICNT).SAKUSEIBI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  5, MJIDO_WORK(ICNT).RENBAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  6, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  7, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  9, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MJIDO_WORK(ICNT).ZOKUGARAMEI1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MJIDO_WORK(ICNT).ZOKUGARAMEI2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MJIDO_WORK(ICNT).KANJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MJIDO_WORK(ICNT).KON_JUSHO_JODAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MJIDO_WORK(ICNT).KON_JUSHO_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MJIDO_WORK(ICNT).GYOSEIKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 18, MJIDO_WORK(ICNT).SANTEIDANTAIMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 19, MJIDO_WORK(ICNT).JIDO_CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 20, MJIDO_WORK(ICNT).JIDO_BANCHI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 21, MJIDO_WORK(ICNT).JIDO_KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 22, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 23, MJIDO_WORK(ICNT).GAKOKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 24, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 25, VPAGENAME);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 26, MJIDO_WORK(ICNT).JIDO_HONMYO_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 27, MJIDO_WORK(ICNT).JIDO_HONMYO_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 28, MJIDO_WORK(ICNT).YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 29, MJIDO_WORK(ICNT).GAKOKU_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 30, MJIDO_WORK(ICNT).JIDO_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 31, MJIDO_WORK(ICNT).KAGAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 32, MJIDO_WORK(ICNT).JINKAKU_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 33, MJIDO_WORK(ICNT).YOCHIEN_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 34, MJIDO_WORK(ICNT).YOCHIEN_MEI);
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 35, MJIDO_WORK(ICNT).TSUSHOMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 36, MJIDO_WORK(ICNT).TSUSHOMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 37, MJIDO_WORK(ICNT).ATENA_RIREKI_RENBAN);
                    --  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START
                    --DBMS_SQL.COLUMN_VALUE(I_CUR, 38, MJIDO_WORK(ICNT).JIDO_KOKUSEKI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 38, MJIDO_WORK(ICNT).GAKUNEN_CD);
                    --  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 39, MJIDO_WORK(ICNT).JIDO_KOKUSEKI_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 40, MJIDO_WORK(ICNT).JIDO_YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 41, MJIDO_WORK(ICNT).JIDO_KON_JUSHO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 42, MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 43, MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_MEI);
-- 2024/07/18 ZCZL.wangqiwei Add end
                    -- 改頁の指定がある場合
                    IF VPAGEWORK = VPAGENAME THEN
                    -- 以前の改頁項目名と同じ
                        IGYOCNT := IGYOCNT + 1;
                        IGYORENBAN := IGYORENBAN + 1;
                        IF IGYOCNT > C_IMAXROWS THEN
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
                    IF NRENBAN = 1 OR NRENBAN IS NULL  THEN
                       MJIDO_WORK(ICNT).RENBAN := IGYORENBAN;    -- 連番
                    END IF;                    
                    MJIDO_WORK(ICNT).KAIPEJI := VPAGENAME;    -- 改頁名
                    MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEFIELD; -- 改頁コード
                 
                ELSE
                    -- 全件読み込み終了
                    EXIT;
                END IF;
                ICNT := ICNT + 1;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                FRET := C_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                RAISE ERR;
        END;
        RETURN FRET;
    END FUNC_GET_JIDO_WK_CSV;
    --------------------------------------------------------
    --  機能概要      : 児童生徒ワークＣＳＶの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        r_CHOHYO_001        GKBWL120R001%ROWTYPE;
        CCOUNT              NUMBER:=0;
--  2024/09/26 ZCZL.WANGMING ADD START 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
        rGAKUNENMEI                    NVARCHAR2(500);    --学年名
        rGIMUKYOIKU_GAKUNENMEI         NVARCHAR2(500);    --義務教育学校学年名
        i_nGAKOUKUBUN                  NUMBER;            --学校区分コード
        o_sMGAKKO_CD                   NVARCHAR2(100);    --文部科学省学校コード
        nRTN                           NUMBER:=0;         -- 戻り値
--  2024/09/26 ZCZL.WANGMING ADD END
    BEGIN
        FRET := C_ISUCCESS;                  -- 正常終了
        IMAX := MJIDO_WORK.LAST;             -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;            -- ワーク領域の件数の最小値
        -- 取得した件数分繰り返す
        FOR ICNT IN IMIN..IMAX LOOP
            CCOUNT                            := CCOUNT+1;
            r_CHOHYO_001                      := NULL;
            r_CHOHYO_001.NO                   := CCOUNT;                                  --ソート順
            r_CHOHYO_001.NENDO                := MJIDO_WORK(ICNT).NENDO;                  --年度
-- 2024/07/18 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START
             r_CHOHYO_001.KAIPAGE_CD           := MJIDO_WORK(ICNT).KAIPEJI_CD;             --ブレークキー
            r_CHOHYO_001.KAIPAGE_MEI          := MJIDO_WORK(ICNT).KAIPEJI;                --ブレーク名称
             r_CHOHYO_001.GENZAIBI             := MJIDO_WORK(ICNT).SAKUSEIBI;              --現在日
            r_CHOHYO_001.NUM                  := MJIDO_WORK(ICNT).RENBAN;                 --No
             r_CHOHYO_001.SHIMEI_KANA          := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;       --氏名カナ
             r_CHOHYO_001.SHIMEI               := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;      --氏名
--            r_CHOHYO_001.KAIPAGE_CD           := NULL;                                       --ブレークキー
--            r_CHOHYO_001.KAIPAGE_MEI          := NULL;                                       --ブレーク名称
--            r_CHOHYO_001.GENZAIBI             := NULL;                                       --現在日
--            r_CHOHYO_001.NUM                  := NULL;                                       --No
--            r_CHOHYO_001.SHIMEI_KANA          := NULL;                                       --氏名カナ
--            r_CHOHYO_001.SHIMEI               := NULL;                                       --氏名
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END
-- 2024/07/18 ZCZL.wangqiwei Update end
            r_CHOHYO_001.SEIBETSU             := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;            --性別
-- 2024/07/18 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--             r_CHOHYO_001.HOGOSHA_SHIMEI_JODAN := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN;   --保護者氏名上
--             r_CHOHYO_001.HOGOSHA_SHIMEI_GEDAN := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;   --保護者氏名下
            r_CHOHYO_001.HOGOSHA_SHIMEI_JODAN := NULL;                                       --保護者氏名上
            r_CHOHYO_001.HOGOSHA_SHIMEI_GEDAN := NULL;                                       --保護者氏名下
-- 2024/07/18 ZCZL.wangqiwei Update end
            r_CHOHYO_001.HOGOSHA_KANKEI       := MJIDO_WORK(ICNT).ZOKUGARAMEI1;           --保護者との関係
            r_CHOHYO_001.JIDO_ZOKUGARAMEI     := MJIDO_WORK(ICNT).ZOKUGARAMEI2;           --児童との関係
            r_CHOHYO_001.SEINENGAPI           := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;       --生年月日
-- 2024/07/18 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--             r_CHOHYO_001.KANJI_SEINENGAPI     := MJIDO_WORK(ICNT).KANJI_SEINENGAPI;       --漢字生年月日
--             r_CHOHYO_001.JUSHO_JODAN          := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;        --住所上
--             r_CHOHYO_001.JUSHO_GEDAN          := MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;        --住所下
            r_CHOHYO_001.KANJI_SEINENGAPI     := NULL;                                       --漢字生年月日
            r_CHOHYO_001.JUSHO_JODAN          := NULL;                                       --住所上
            r_CHOHYO_001.JUSHO_GEDAN          := NULL;                                       --住所下
-- 2024/07/18 ZCZL.wangqiwei Update end
            r_CHOHYO_001.GYOSEIKU             := MJIDO_WORK(ICNT).GYOSEIKUMEI;            --行政区
-- 2024/07/18 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START
             r_CHOHYO_001.JIDO_JUSHO           := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;        --児童住所
            r_CHOHYO_001.JUSHO1               := MJIDO_WORK(ICNT).JIDO_CHOMEI||MJIDO_WORK(ICNT).JIDO_BANCHI||MJIDO_WORK(ICNT).JIDO_KATAGAKI;--住所１
--            r_CHOHYO_001.JIDO_JUSHO           := NULL;                                       --児童住所
--             r_CHOHYO_001.JUSHO1               := NULL;                                       --住所１
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END
-- 2024/07/18 ZCZL.wangqiwei Update end
            r_CHOHYO_001.HOGOSHA_SHIMEI_KANA  := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;                                                      --保護者氏名カナ
            r_CHOHYO_001.HOGOSHA_SHIMEI_KANJI := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;                                                     --保護者氏名
            r_CHOHYO_001.JUSHO                := MJIDO_WORK(ICNT).KON_JUSHO_JODAN ||MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;                       --住所
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--             r_CHOHYO_001.SHOGAKKO_MEI         := MJIDO_WORK(ICNT).GAKOKUMEI;              --小学校名
            r_CHOHYO_001.SHOGAKKO_MEI         := NULL;                                    --小学校名
            r_CHOHYO_001.JIDO_SHIMEI_KANA     := MJIDO_WORK(ICNT).JIDO_HONMYO_KANA;       --児童氏名カナ
            r_CHOHYO_001.JIDO_SHIMEI_KANJI    := MJIDO_WORK(ICNT).JIDO_HONMYO_KANJI;      --児童氏名
-- 2024/07/18 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START
			 r_CHOHYO_001.YUBIN_NO             := MJIDO_WORK(ICNT).YUBIN_NO;               --郵便番号
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END
--             r_CHOHYO_001.GAKKOKU_CD           := MJIDO_WORK(ICNT).GAKOKU_CD;              --学校区コード
--             r_CHOHYO_001.JIDO_KOJIN_NO        := MJIDO_WORK(ICNT).JIDO_KOJIN_NO;          --児童個人番号
--             r_CHOHYO_001.BIT3SHITAGAKUNEN     := MJIDO_WORK(ICNT).KAGAKUNEN;              --下学年    
--             r_CHOHYO_001.JINKAKU_KBN          := MJIDO_WORK(ICNT).JINKAKU_KBN;            --人格区分       
--             r_CHOHYO_001.YOCHIEN_CD           := MJIDO_WORK(ICNT).YOCHIEN_CD;             --幼稚園保育園コ
--             r_CHOHYO_001.YOCHIEN_MEI          := MJIDO_WORK(ICNT).YOCHIEN_MEI;            --幼稚園保育園名
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START
--            r_CHOHYO_001.YUBIN_NO             := NULL;                                       --郵便番号
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END
            r_CHOHYO_001.GAKKOKU_CD           := NULL;                                       --学校区コード
            r_CHOHYO_001.JIDO_KOJIN_NO        := NULL;                                       --児童個人番号
            r_CHOHYO_001.BIT3SHITAGAKUNEN     := NULL;                                       --下学年    
            r_CHOHYO_001.JINKAKU_KBN          := NULL;                                       --人格区分       
            r_CHOHYO_001.YOCHIEN_CD           := NULL;                                       --幼稚園保育園コ
            r_CHOHYO_001.YOCHIEN_MEI          := NULL;                                       --幼稚園保育園名
-- 2024/07/18 ZCZL.wangqiwei Update end
-- 2024/07/18 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発
            r_CHOHYO_001.SAKUSEIBI            := MJIDO_WORK(ICNT).SAKUSEIBI;                 -- 作成日
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START            
--            r_CHOHYO_001.YUBIN_NO             := MJIDO_WORK(ICNT).YUBIN_NO;                  -- 保護者郵便番号
			  r_CHOHYO_001.HOGOSHA_YUBIN_NO      := MJIDO_WORK(ICNT).YUBIN_NO;                  -- 保護者郵便番号
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END
--  2024/09/26 ZCZL.WANGMING UPDATE START 0.3.000.003:仕様変更 IT_GKB_00003、IT_GKB_00004、IT_GKB_00005対応
--            r_CHOHYO_001.GAKUNEN              := '一年生';                                   -- 学年
            -- 共通関数文部科学省学校コード取得（GKAFKMBKKSCDGET）より、文部科学省学校コードを取得。
            IF MJIDO_WORK(ICNT).GAKUNEN_CD = 0 THEN
               i_nGAKOUKUBUN := 1;
            ELSE
               i_nGAKOUKUBUN := 2;
            END IF;
            nRTN := GKAFKMBKKSCDGET(i_nGAKOUKUBUN, MJIDO_WORK(ICNT).GAKOKU_CD, o_sMGAKKO_CD);
            --学年名マスタ（GKBTGAKUNEN）を取得する
            BEGIN
             SELECT GAKUNENMEI,GIMUKYOIKU_GAKUNENMEI 
               INTO rGAKUNENMEI,rGIMUKYOIKU_GAKUNENMEI 
               FROM GKBTGAKUNEN 
              WHERE  GAKUNEN_CD = MJIDO_WORK(ICNT).GAKUNEN_CD + 1;
            EXCEPTION
              WHEN OTHERS THEN
                  rGAKUNENMEI := '';
                  rGIMUKYOIKU_GAKUNENMEI := '';
            END;
            IF nRTN =0 THEN
               IF SUBSTR(o_sMGAKKO_CD,1,2) = 'C2' THEN
                 r_CHOHYO_001.GAKUNEN := rGAKUNENMEI;             --指定校学年
               ELSE
                 r_CHOHYO_001.GAKUNEN := rGIMUKYOIKU_GAKUNENMEI;  --指定校学年
               END IF;
            END IF;
--  2024/09/26 ZCZL.WANGMING UPDATE END
            r_CHOHYO_001.JIDO_KOKUSEKI        := MJIDO_WORK(ICNT).JIDO_KOKUSEKI_MEI;         -- 児童生徒国籍
            r_CHOHYO_001.JIDO_YUBIN_NO        := MJIDO_WORK(ICNT).JIDO_YUBIN_NO;             -- 保護者郵便番号
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START
          --r_CHOHYO_001.JIDO_JUSHO           := MJIDO_WORK(ICNT).JIDO_CHOMEI ||
            r_CHOHYO_001.JIDO_KON_JUSHO       := MJIDO_WORK(ICNT).JIDO_CHOMEI ||
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END            
                                                 MJIDO_WORK(ICNT).JIDO_BANCHI ||
                                                 MJIDO_WORK(ICNT).JIDO_KATAGAKI ;            -- 児童生徒住所
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 START
          --r_CHOHYO_001.JIDO_JUSHO           := MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_MEI;      -- 保護者国籍
            r_CHOHYO_001.HOGOSHA_KOKUSEKI     := MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_MEI;      -- 保護者国籍
--  2024/11/29 JPJYS.SHAXUE UPDATE 0.3.000.006:IT_GKB_00683対応 END
-- 2024/07/18 ZCZL.wangqiwei Add end
            r_CHOHYO_001.BREAK_NO             := NULL;                                    --改ページキー
            r_CHOHYO_001.WSNUM                := g_sWSNUM;                                --端末番号
-- 2024/07/18 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発
--             r_CHOHYO_001.BATCHKBN             := c_BATCH;                                 --即時バッチ区分
            r_CHOHYO_001.BATCHKBN             := 2;                                 --即時バッチ区分
            r_CHOHYO_001.JOBNUM               := g_nJOBNUM;                               --ジョブNO
            INSERT INTO GKBWL120R001 VALUES r_CHOHYO_001;
        END LOOP;
        -- 終了
        RETURN FRET;
    EXCEPTION
        WHEN OTHERS THEN
            FRET := C_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            RAISE ERR;
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE;
    --2024/12/27 JIP.Y.SATO ADD ST
    --------------------------------------------------------
    --  機能概要      : 排他制御
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: JIP.Y.SATO  2024/12/27
    --------------------------------------------------------
    FUNCTION FUNC_INIT RETURN BOOLEAN
    IS
    nRTN                PLS_INTEGER  :=  0 ;
    bRTN                BOOLEAN;
    v_LOG               NVARCHAR2(256);
    BEGIN
      v_LOG := NULL;
      -- 排他制御セット
      nRTN := GKBFKHTSET(2, '999999999999', '全件', g_nDATE, g_sTANTOCODE, g_sWSNUM, g_nTIME);
      IF nRTN = 1 THEN
          v_LOG := FUNC_GET_LOG('排他制御処理で異常終了しました。');
          bRTN  := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INIT', 1, '', '', v_LOG, g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
      ELSIF nRTN <> 0 AND nRTN <> 1 THEN
          v_LOG := FUNC_GET_LOG('排他がかかっているデータが存在するため、処理を実行できませんでした。');
          bRTN  := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INIT', 1, '', '', v_LOG, g_sTANTOCODE, g_sWSNUM, 1);
          RETURN FALSE;
      ELSE
          NULL;
      END IF;

      RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INIT', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            RETURN FALSE;
    END FUNC_INIT;
    --2024/12/27 JIP.Y.SATO ADD ED
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;                      --戻り値
        eEXCEPTION                    EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        --2024/12/27 JIP.Y.SATO ADD ST
        IF NOT bRTN THEN
          RAISE eEXCEPTION;
        END IF;
        
        bRTN := FUNC_INIT;
        IF NOT bRTN THEN
          RAISE eEXCEPTION;
        END IF;
        --2024/12/27 JIP.Y.SATO ADD ED        
        DELETE FROM GKBWL120R001 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
        -- 処理条件の取得
        I_NTRENBAN := g_nJOBNUM;
        -- 取得した条件をそれぞれの変数へセット
        VNENDO := g_vJYOUKEN1;                  -- 対象年度
        NNENDO := TO_NUMBER(VNENDO);
        NRENBAN := TO_NUMBER(g_vJYOUKEN2);
        o_RENBAN_PRM := A_CONS_PRM();
        IRTN_RENBAN := KKAPK0030.FPRMSHUTOKU('GKB','00RENBAN',0,o_RENBAN_PRM,o_LENGTH);
        IF IRTN_RENBAN = 1 THEN
                      o_RENBAN_PRM := A_CONS_PRM();
                      o_RENBAN_PRM.EXTEND;
                      o_RENBAN_PRM.EXTEND;
                      o_RENBAN_PRM(1) := 0;
        ELSE
          WHILE (o_LENGTH < 1) LOOP
            o_RENBAN_PRM.EXTEND;
            o_RENBAN_PRM(o_LENGTH+1) := 0;
            o_LENGTH := o_LENGTH + 1;
          END LOOP;
        END IF;

       o_SINNYUGAKU_PRM := A_CONS_PRM();
       IRTN_SINNYUGAKU := KKAPK0030.FPRMSHUTOKU('GKB','00SINNYUGAKU',0,o_SINNYUGAKU_PRM,o_LENGTH);
       IF IRTN_SINNYUGAKU = 1 THEN
                      o_SINNYUGAKU_PRM := A_CONS_PRM();
                      o_SINNYUGAKU_PRM.EXTEND;
                      o_SINNYUGAKU_PRM.EXTEND;
                      o_SINNYUGAKU_PRM(1) := 1;
        ELSE
          WHILE (o_LENGTH < 1) LOOP
            o_SINNYUGAKU_PRM.EXTEND;
            o_SINNYUGAKU_PRM(o_LENGTH+1) := 1;
            o_LENGTH := o_LENGTH + 1;
          END LOOP;
        END IF;
        INENDO_S_DAY := TO_NUMBER(VNENDO) * 10000 + 401;    -- 条件の年度の４月１日[GYYMMDD]
        -- 日付変換をします
        IO_SEIREKIHIZUKE := 0;  
        BRTN := KKAPK0020.FDAYEDIT( INENDO_S_DAY,
                                     IO_SEIREKIHIZUKE,
                                     VEDIT_GYYMMDD1,
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
                                     INENDO_S_DAY);
        ISYOGAKO_NYUGAKU_BI := INENDO_S_DAY;     -- 小学校入学年月日
        IZO_NENGAPI := INENDO_S_DAY;             -- 増年月日
        VNENDO := KKAPK0020.FNENDO(VNENDO,1);
        VKAISISEINENGAPI  := KKAPK0020.FNENDO(VNENDO-7,0) || '0402';        -- 開始生年月日
        VSHURYOSEINENGAPI := KKAPK0020.FNENDO(VNENDO-6,0) || '0401';       -- 終了生年月日
        -- 和暦生年月日の西暦日付変換
        IKAISISEINENGAPI  := TO_NUMBER(VKAISISEINENGAPI);
        ISEIREKI_WORK := 0;
        BRTN := KKAPK0020.FDAYEDIT( IKAISISEINENGAPI,
                                     ISEIREKI_WORK,
                                     VEDIT_GYYMMDD1,
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
        IKAISISEINENGAPI  := ISEIREKI_WORK;
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', 'KAISISEINENGAPI = ' || IKAISISEINENGAPI, g_sTANTOCODE, g_sWSNUM, 1);
        ISHURYOSEINENGAPI := TO_NUMBER(VSHURYOSEINENGAPI);
        ISEIREKI_WORK := 0;
        BRTN := KKAPK0020.FDAYEDIT( ISHURYOSEINENGAPI,
                                     ISEIREKI_WORK,
                                     VEDIT_GYYMMDD1,
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
        ISHURYOSEINENGAPI  := ISEIREKI_WORK;
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', 'SHURYOSEINENGAPI = ' || ISHURYOSEINENGAPI, g_sTANTOCODE, g_sWSNUM, 1);
        -- 児童生徒ワーク（GKBWJIDOSHINNYUGAKU）のデータ全件削除
        I_RTN := KKAPK3000.FTRUNCATE(C_VTABLE, VSQLERRM);
        -- テスト用にデータ全件削除

        IF I_RTN = C_INOT_SUCCESS THEN
            RAISE eEXCEPTION;
        END IF;

        I_SYSTEMJOKEN := 0;
        I_SYSTEMJOKEN := FUNC_GET_SYSJOKEN(c_ISYS_J_KANKEI);

        -- 児童生徒ワークデータ作成
        I_RTN := FUNC_GET_JIDO_WK;
        IF I_RTN <> C_ISUCCESS THEN
            --  2024/04/19 ZCZL.LIKEWEN ADD START 0.2.000.001:512_GKB_00018対応
            IF I_RTN = c_INOTFOUND THEN
              --対象データ無しの場合は異常終了させない
              GOTO NODATA_EXIT;
            END IF;
            --  2024/04/19 ZCZL.LIKEWEN ADD END
            RAISE eEXCEPTION;
        END IF;

        -- ワークテーブル作成
        I_RTN := FUNC_INSERT_JIDO_WK;
        IF I_RTN = C_INOT_SUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE eEXCEPTION;
        END IF;

        -- 児童生徒ワークデータ作成（ＣＳＶ用）
        I_RTN := FUNC_GET_JIDO_WK_CSV;
        IF I_RTN <> C_ISUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE eEXCEPTION;
        END IF;
        -- 児童生徒ワークＣＳＶファイル作成
        I_RTN := FUNC_SET_JIDO_WK_CSVFILE;
        IF I_RTN <> C_ISUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE eEXCEPTION;
        END IF;
        --帳票出力CSVの作成
        bRTN:= FUNC_B11CSV('GKBWL120R001');
        --  2024/04/19 ZCZL.LIKEWEN ADD START 0.2.000.001:512_GKB_00018対応
        <<NODATA_EXIT>>
        --  2024/04/19 ZCZL.LIKEWEN ADD 
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1 RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;    --戻り値
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
    --  機能概要      : 件数表出力
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
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
    --  機能概要      : バッチ処理の呼出
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                : o_nRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/02
    --------------------------------------------------------
    PROCEDURE PBATCH(i_nJOBNUM  IN  NUMBER,
                     o_nRESULT  OUT NUMBER)
    IS
        ePRMEXCEPTION                 EXCEPTION;                --パラメータ取得異常タイプ
        eSHORIEXCEPTION               EXCEPTION;                --処理異常タイプ
        bRTN                          BOOLEAN;                  --戻り値
        aSTEPSEQ_TBL                  KKBPK5551.tySTEPSEQ_Tbl;  --処理ステップ連番
        nSTEPSEQ_MAX                  NUMBER;                   --処理ステップレコード数
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
        nRTN                          NUMBER;                   --戻り値
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
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
        -- 排他制御クリア
        nRTN := GKBFKHTCLR(2, '999999999999');
    EXCEPTION
        WHEN ePRMEXCEPTION THEN
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
            nRTN := GKBFKHTCLR(2, '999999999999');
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
        WHEN eSHORIEXCEPTION THEN
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
            nRTN := GKBFKHTCLR(2, '999999999999');
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM)   ;
            ROLLBACK;
        WHEN OTHERS THEN
-- 2024/07/18 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発
            nRTN := GKBFKHTCLR(2, '999999999999');
            o_nRESULT := c_ERR;
            PROC_JSTPSTAUTSUPD (2, o_nRESULT);
            bRTN := KKBPK5551.FFINAL (g_nJOBNUM);
            ROLLBACK;
    END PBATCH;
END GKBPC00400;
/