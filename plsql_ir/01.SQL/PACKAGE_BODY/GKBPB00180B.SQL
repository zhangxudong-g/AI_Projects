CREATE OR REPLACE PACKAGE BODY GKBPB00180
--1.0.010.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 保護者チェック
--  機能概要      : 学齢簿に登録された保護者情報から最新の住民記録情報を検索し
--              転出・死亡などの異動がある場合
--              保護者が設定されていない場合
--              児童生徒と保護者の世帯番号が異なる場合に
--              保護者を確認するための一覧表を作成する
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.WANGYUNING 2024/01/02
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/04/28 ZCZL.WUCAO Update 0.2.000.002:512_GKB_00033対応
--  2024/07/01 ZCZL.caijiacun Update 0.3.000.000:新WizLIFE２次開発対応
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00075対応
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/29 ZCZL.YUCHUFEI UPDATE 0.3.000.003:仕様変更 IT_GKB_00161対応
--  2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.004:IT_GKB_00338の対応
--  2024/10/30 ZCZL.ZHANGLEI UPDATE 0.3.000.005:IT_GKB_00368,IT_GKB_00408の対応
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00429対応横展開
--  2025/05/19 ZCZL.WANGWEIZHE UPDATE 1.0.004.000:GKB_QA13605(保守#2205)二次対応_【学齢簿】保護者警告チェックリストの世帯主氏名が空欄で印字されないを修正する
--  2025/05/22 CTC.LIUJUNHAO UPDATE 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応
--  2025/06/27 JIP.Y.SATO UPDATE 1.0.010.000:GKB_QA16967_児童生徒が住登外者の場合に保護者情報等が不一致でも一覧に出力されない不具合の対応
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
    
    g_sOUTPUTCHACK                NVARCHAR2(1000);              --保護者警告チェックリスト_出力制御
    g_dDATE                       NUMBER;                         --システム日付
    g_nCHUTAISYOU                 NUMBER;                       --抽出対象
    g_nHaniKubun                  NUMBER;                       --抽出範囲区分
    g_nStartYmd                   NUMBER;                       --抽出開始年月日
    g_nEndYmd                     NUMBER;                       --抽出終了年月日
    g_NStartYmd7                   NUMBER;                      --抽出開始年月日7
    g_NEndYmd7                     NUMBER;                      --抽出終了年月日7
    g_nShiteiKojinId              NUMBER;                       --対象者指定宛名番号

    --実行回数とステップ数
    g_nSTEP_MAX   NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;
    nCOUNT        NUMBER := 0;
    g_nCOUNT      NUMBER := 0;

    --パラメータ変数
    g_VJOKEN01    NVARCHAR2(1000);
    g_VJOKEN02    NVARCHAR2(1000);
    g_VJOKEN03    NVARCHAR2(1000);
    VMSG NVARCHAR2(4000);
    IRTN PLS_INTEGER ;
    ICHK1 PLS_INTEGER ;
    ICHK2 PLS_INTEGER ;
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
    -- 学齢簿喪失者は対象としない
--  2024/07/02 ZCZL.caijiacun DELETE start 0.3.000.000:新WizLIFE２次開発対応
--       CURSOR CJIDO(p_GAKUNEN_CD IN NUMBER,
--                    p_SYURYOGAKUNEN_CD IN NUMBER) IS
--           SELECT A.KOJIN_NO,
--                  A.GAKUNEN_CD
--             FROM GKBTGAKUNENLNK A,GKBTGAKUREIBO B
--            WHERE GAKUNEN_CD BETWEEN p_GAKUNEN_CD AND p_SYURYOGAKUNEN_CD
--              AND A.KOJIN_NO=B.KOJIN_NO
--              AND B.SAISHIN_KBN =0
--              AND B.GEN_NENGAPI =0;
---  2024/07/02 ZCZL.caijiacun DELETE end
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
        -- ERROR関連 --
    -- デバック
        N_SQL_CODE     NUMBER;             -- SQLエラーコード
        V_SQL_MSG      NVARCHAR2(255);     -- SQLエラーメッセージ
        c_BERROR       CONSTANT  BOOLEAN :=  FALSE;
        -- 処理結果
        c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
        c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
        c_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし
        -- 戻り値
        c_IOK          CONSTANT  PLS_INTEGER := 0;         -- 正常
        c_IERR         CONSTANT  PLS_INTEGER := 1;         --異常
        c_VNOTHING     CONSTANT  NVARCHAR2(128) := '@@@NOTHING@@@';
        c_BERR         CONSTANT  BOOLEAN := FALSE;         -- 異常
        -- 処理条件数
        c_IJOKEN       CONSTANT  PLS_INTEGER := 20;        -- 処理条件取得処理から取得される項目は２０個
        -- ソート条件数
        c_ISORT        CONSTANT  PLS_INTEGER := 15;        -- ソート条件取得処理から取得される項目は１５個
        -- 正常メッセージの値
        c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '保護者チェック処理が正常終了しました。';
        -- エラーメッセージの値
        c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '保護者チェック処理が異常終了しました。';
        -- 保護者ワーク
        c_VTABLE       CONSTANT  NVARCHAR2(128) := 'GKBWHOGOSHACHK';
        -- １頁の最大行数
        c_IMAXROWS     CONSTANT  PLS_INTEGER := 15;
       -- CSVファイル --
        -- 帳票連番（作成順序）
        c_NFILENUMBER  CONSTANT  NUMBER(2)      := 1;
        i_VMODE        CONSTANT NVARCHAR2(255) := 'W';
        i_PFILESIZE    BINARY_INTEGER := 3000;
        o_MTFILE UTL_FILE.FILE_TYPE;
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
        NHOGOSHA_NO         NUMBER;
        ISAKUSEIBI          PLS_INTEGER;
        RG                  GKBTGAKUREIBO%ROWTYPE;
        RA                  GABTATENAKIHON%ROWTYPE;
        RB                  GABTATENAKIHON%ROWTYPE;
        RC                  GABTSOFUSAKI%ROWTYPE;
        RASO                GABTSOFUSAKI%ROWTYPE;
        IKOJIN_NO           NUMBER;
        IGAKO_CD            PLS_INTEGER;
        IMRIREKI_RENBAN     PLS_INTEGER;
        VGAKOMEI            NVARCHAR2(60);      
        VSEINENGAPI         NVARCHAR2(11);
        VSEIBETSU           NVARCHAR2(2);
--  2024/07/01 ZCZL.caijiacun Update 0.3.000.000:新WizLIFE２次開発対応
--        VSETAI_NO           NVARCHAR2(7);
        VSETAI_NO           NVARCHAR2(15);
        VGYOSEIKU_MEI       NVARCHAR2(20);
        VHAN_MEI            NVARCHAR2(20);
        --  2024/10/30 ZCZL.ZHANGLEI UPDATE 0.3.000.005:IT_GKB_00338の対応
        --VSANTEIDANTAI_MEI   NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.006:IT_GKB_00429対応横展開
--        VSANTEIDANTAI_MEI   NVARCHAR2(40);
        VSANTEIDANTAI_MEI   GKBWHOGOSHACHK.SANTEIDANTAIMEI%TYPE;
        VHYOUJINENDO        NVARCHAR2(10);
        VSASKUSEIBI         NVARCHAR2(30);
        RD                  GABTATENAKIHON%ROWTYPE;
        RE                  GABTSOFUSAKI%ROWTYPE;
        VSHIMEI_KANJI       NVARCHAR2(300);
        VJINKAKU_KBN        NUMBER;
        VHOGOSHA_SHIMEI_JODAN     NVARCHAR2(100);
        VHOGOSHA_SHIMEI_GEDAN     NVARCHAR2(100);
        VJUSHO_JODAN        NVARCHAR2(30);
        VJUSHO_GEDAN        NVARCHAR2(30);
        VCNT                NVARCHAR2(6);
        VZOKUGARAMEI1       NVARCHAR2(30);
        VZOKUGARAMEI2       NVARCHAR2(30);
        VGAKUNENMEI         NVARCHAR2(20);
        NGAKUNENSEI         NUMBER;
        VGAKUNENSEI         NVARCHAR2(20);
--  2024/07/01 ZCZL.caijiacun Update 0.3.000.000:新WizLIFE２次開発対応
--        VHOGOSHA_SETAI_NO   NVARCHAR2(7);
        VHOGOSHA_SETAI_NO   NVARCHAR2(15);
        VSOSHITSU_JIYU      NVARCHAR2(20);      --喪失事由
        VIDO_JIYU           NVARCHAR2(20);      --異動事由
        IJUMIN_NAKUNARU_TODOKEDE_BI PLS_INTEGER;--住民でなくなる届出日
        VTODOKEDEBI         NVARCHAR2(9);       --変数.届出日
        VJIDO_JUSHO         NVARCHAR2(141);     --変数.児童生徒住所
        VHOGOSHA_JUSHO      NVARCHAR2(141);     --変数.保護者住所
        IJUMIN_NAKUNARU_JIYU     NUMBER;
        IIDO_NENGAPI        NUMBER;
        VIDO_NENGAPI        NVARCHAR2(11);
        -- 関数用戻り値変数（外部関数からの戻り値をセット）
        BRTN                BOOLEAN;
        B_RTN               BOOLEAN;
        I_RTN               PLS_INTEGER;
        -- 処理条件（画面からの引数）
        VNENDO              NVARCHAR2(15);      -- 対象年度
        VGAKUNEN            NVARCHAR2(15);      -- 学年
        VSYURYOGAKUNEN      NVARCHAR2(15);      -- 終了学年
        NJIYUSHIYOCHKFLG    NUMBER;            --住所チェックフラグ
        -- 処理条件の取得用変数
        TYPE MTJOKEN_TYPE IS TABLE OF NVARCHAR2(15) INDEX BY BINARY_INTEGER;  -- 処理条件の値の配列宣言
        o_MJYOUKEN      MTJOKEN_TYPE;
        -- 取得したデータのワーク領域
        TYPE MTHOGOSHA_TYPE IS TABLE OF GKBWHOGOSHACHK%ROWTYPE INDEX BY BINARY_INTEGER;
        MHOGOSHA_WORK MTHOGOSHA_TYPE;
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
        -- 帳票ソート条件の取得用変数
        TYPE MTSORT_TYPE IS TABLE OF NUMBER(2) INDEX BY BINARY_INTEGER;  -- ソート条件の値の配列宣言
        o_NBREAK         NUMBER(2);
        -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
--  2024/07/02 ZCZL.caijiacun Add start 0.3.000.000:新WizLIFE２次開発対応
        TYPE REC_CRJIDO IS RECORD
        (
           KOJIN_NO                    GKBTGAKUREIBO.KOJIN_NO%TYPE,
           GAKKO_KBN_CD                GKBTGAKUREIBO.GAKKO_KBN_CD%TYPE,
           SYOGAKO_CD                  GKBTGAKUREIBO.SYOGAKO_CD%TYPE,
           TYUGAKO_CD                  GKBTGAKUREIBO.TYUGAKO_CD%TYPE,
           KUIKIGAI_CD                 GKBTGAKUREIBO.KUIKIGAI_CD%TYPE,
           YOGOGAKO_CD                 GKBTGAKUREIBO.YOGOGAKO_CD%TYPE,
           KUNISHIRITSU_CD             GKBTGAKUREIBO.KUNISHIRITSU_CD%TYPE,
           SEIBETSU                    GKBTGAKUREIBO.SEIBETSU%TYPE,
           GAKUNEN                     GKBTGAKUREIBO.GAKUNEN%TYPE,
           HOGOSYA_ZOKUGARA1           GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1%TYPE,
           HOGOSYA_ZOKUGARA2           GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2%TYPE,
           HOGOSYA_ZOKUGARA3           GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3%TYPE,
           HOGOSYA_ZOKUGARA4           GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4%TYPE,
           IDO_BI                      GKBTGAKUREIBO.IDO_BI%TYPE,
           JUMIN_NAKUNARU              JIBTJUKIIDO.JUMIN_NAKUNARU%TYPE,
           JUMIN_NAKUNARU_TODOKEDE_BI  JIBTJUKIIDO.JUMIN_NAKUNARU_TODOKEDE_BI%TYPE,
           NUSHI_SHIMEI_KANJI          GABTATENAKIHON.NUSHI_SHIMEI_KANJI%TYPE,
           GAKUNEN_CD                  GKBTGAKUNENLNK.GAKUNEN_CD%TYPE,
           HOGOSYA_KOJIN_NO            GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE
        );
        CRJIDO                         REC_CRJIDO;
        TYPE MC_CURSOR IS REF CURSOR;                     --カーソルタイプ
--2024/07/02 ZCZL.caijiacun Add end
        BRTNSEINENGAPI                 BOOLEAN;
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
        VSQLERRM         NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
        VPAGENM          NVARCHAR2(500);    -- 改頁項目名
        VPAGEFD          NVARCHAR2(500);    -- 改頁項目値
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
--  2024/07/02 ZCZL.caijiacun Add Start 0.3.000.000:新WizLIFE２次開発対応
    --------------------------------------------------------
    --  機能概要      : 初期処理
    --  パラメータ      : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.caijiacun 2024/07/02
    --------------------------------------------------------
    FUNCTION FUNC_INIT
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;           --戻り値
        nRTN                          NUMBER;            --戻り値
        vSQLERRM                      NVARCHAR2(1000);
        aPRM1                         A_CONS_PRM;
        aPRM2                         A_CONS_PRM;
        INDEXNUM                      NUMBER;
    BEGIN
        --共通関数（テーブルデータ削除プロシジャ）(KKAPK3000.FTRUNCATE)を呼び出し、保護者チェックワーク、保護者情報チェック一覧表、保護者警告チェックリストワークをクリアする。
        nRTN := KKAPK3000.FTRUNCATE('GKBWHOGOSHACHK', vSQLERRM);
--  2024/09/04 ZCZL.LIUCHANGQUAN DEL START 0.3.000.002:8月1日認識合わせの横展開
--        nRTN := KKAPK3000.FTRUNCATE('GKBWL110R001', vSQLERRM);
--        nRTN := KKAPK3000.FTRUNCATE('GKBWL711R001', vSQLERRM);
--  2024/09/04 ZCZL.LIUCHANGQUAN DEL END
        --システム制御設定を取得する。
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aPRM1);
        IF nRTN = 0 THEN
          FOR i IN 1..aPRM1.COUNT LOOP
            IF aPRM1(i) = 'GKB711R001' THEN
              INDEXNUM := i;
              EXIT;
            END IF;
          END LOOP;
        END IF;
        nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aPRM2);
        g_sOUTPUTCHACK := aPRM2(INDEXNUM);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_INIT;
--  2024/07/02 ZCZL.caijiacun Add end
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

--  2024/07/02 ZCZL.caijiacun Add 0.3.000.000:新WizLIFE２次開発対応
        g_dDATE := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));                      --システム日付
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
        optGSK                   DBMS_UTILITY.MAXNAME_ARRAY;
        cmbGakunenStart          DBMS_UTILITY.MAXNAME_ARRAY;
        cmbGakunenEnd            DBMS_UTILITY.MAXNAME_ARRAY;
        v_optJushoCheckUmu       DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/09/03 ZCZL.WANGMING ADD START 0.3.000.001:IT_GKB_00075対応
        cmbtxtChuTaisyou         DBMS_UTILITY.MAXNAME_ARRAY;
        cmbtxtHaniKubun         DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/09/03 ZCZL.WANGMING ADD END
        sStartYmd                NVARCHAR2(20);
        sEndYmd                  NVARCHAR2(20);
        sCHUTAISYOU              NVARCHAR2(100);
        sHaniKubun               NVARCHAR2(100);
        sStartGakunen            NVARCHAR2(100);
        sEndGakunen              NVARCHAR2(100);
        sShiteiKojinId           NVARCHAR2(100);
        sChackUmu                NVARCHAR2(100);
    BEGIN
        --抽出開始学年 範囲(開始)
        cmbGakunenStart := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGakunenStart');
        g_VJOKEN01 := cmbGakunenStart(1);
        --抽出終了学年 範囲(終了)
        cmbGakunenEnd := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGakunenEnd');
        g_VJOKEN02 := cmbGakunenEnd(1);
        --住所チェック有無
        v_optJushoCheckUmu := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'optJushoCheckUmu');
        g_VJOKEN03 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'optJushoCheckUmu',0,v_optJushoCheckUmu);
--  2024/07/02 ZCZL.caijiacun Update start 0.3.000.000:新WizLIFE２次開発対応
--  2024/09/03 ZCZL.WANGMING UPDATE START 0.3.000.001:IT_GKB_00075対応
        --抽出対象
--        sCHUTAISYOU := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtChuTaisyou');
--        g_nCHUTAISYOU := TO_NUMBER(sCHUTAISYOU);
        cmbtxtChuTaisyou := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtChuTaisyou');
        g_nCHUTAISYOU := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtChuTaisyou', 0, cmbtxtChuTaisyou);
        
        --抽出範囲区分
--        sHaniKubun := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHaniKubun');
--        g_nHaniKubun := TO_NUMBER(sHaniKubun);
        cmbtxtHaniKubun := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'txtHaniKubun');
        g_nHaniKubun := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'txtHaniKubun', 0, cmbtxtHaniKubun);
--  2024/09/03 ZCZL.WANGMING UPDATE END
        --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.004:IT_GKB_00338の対応
        --抽出開始年月日
        --抽出開始年月日 範囲(開始)
        g_NStartYmd7 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtStartYmd');
        g_nStartYmd := KKAPK0020.FNENDOHENKAN(g_NStartYmd7);
        
        --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.004:IT_GKB_00338の対応
        --抽出終了年月日
        --抽出終了年月日 範囲(終了)
        g_nEndYmd7 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtEndYmd');
        g_nEndYmd := KKAPK0020.FNENDOHENKAN(g_nEndYmd7);
        
        --対象者指定宛名番号
        sShiteiKojinId := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShiteiKojinId');
        g_nShiteiKojinId := TO_NUMBER(sShiteiKojinId);
--  2024/07/02 ZCZL.caijiacun Update end
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
        vSQLERRM                      NVARCHAR2(1000);
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
    ----------------------------------------------------------------------------------------------------
    --開始学年と終了学年の大小チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIKAKUCHK( i_VGAKUNEN1 IN NVARCHAR2, i_VGAKUNEN2 IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    SGAKUNEN PLS_INTEGER ;
    EGAKUNEN PLS_INTEGER ;
    BEGIN
      IRET := 0 ;
      SGAKUNEN  := TO_NUMBER( i_VGAKUNEN1 );
      EGAKUNEN  := TO_NUMBER( i_VGAKUNEN2 );
      --開始学年と終了学年の大小チェック
      IF SGAKUNEN > EGAKUNEN THEN
          IRET := 1;
      END IF;
      RETURN(IRET) ;
    END ;
    ----------------------------------------------------------------------------------------------------
    --学年チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCGAKUNENCHK( i_VGAKUNEN IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    GAKUNEN PLS_INTEGER ;
    BEGIN
      IRET := 0 ;
      --学年
      BEGIN
        IF i_VGAKUNEN IS NULL THEN
          IRET := 1;
        ELSE
          GAKUNEN  := TO_NUMBER(i_VGAKUNEN);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      IF IRET = 0 THEN
        IF GAKUNEN > 9 THEN
          IRET := 1;
        END IF;
      END IF;

      RETURN(IRET) ;
    END ;
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
        VMSG := '' ;
        IRTN := 0 ;
        ICHK1 := 0 ;
        ICHK2 := 0 ;
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応
         --条件１のチェック
--        IRTN := FUNCGAKUNENCHK( g_VJOKEN01 ) ;
--        IF IRTN <> 0 THEN
--          ICHK1 := 1 ;
--          VMSG := g_sGYOUMUCODE || ',99999,開始学年が正しくありません。,;';
--        END IF ;
--
--        --条件２のチェック
--        IRTN := FUNCGAKUNENCHK( g_VJOKEN02 ) ;
--        IF IRTN <> 0 THEN
--          ICHK2 := 1 ;
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,終了学年が正しくありません。,;';
--        END IF ;
--
--        --条件１と条件２の大小チェックを行う。
--        IF ICHK1 = 0 AND ICHK2 = 0 THEN
--          IRTN := FUNCHIKAKUCHK( g_VJOKEN01, g_VJOKEN02 ) ;
--          IF IRTN <> 0 THEN
--            VMSG := VMSG || g_sGYOUMUCODE || ',99999,開始学年と終了学年の大小関係が誤っています。,;';
--          END IF ;
--        END IF ;
----  2024/07/02 ZCZL.caijiacun Add start 0.3.000.000:新WizLIFE２次開発対応
----  2024/09/29 ZCZL.YUCHUFEI DELETE START 0.3.000.003:仕様変更 IT_GKB_00161対応
--        --対象者指定チェック
----         IF g_nCHUTAISYOU = 2 AND g_nShiteiKojinId IS NULL THEN
----           VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件7：対象者指定宛名番号が正しくありません。,;';
----         END IF;
--        --抽出年月日
----         IF (g_nHaniKubun = 0 OR g_nHaniKubun = 1)  AND (g_nStartYmd7 IS NULL OR g_nEndYmd7 IS NULL) THEN
----           VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件3と条件4：抽出開始年月日と抽出終了年月日が正しくありません。,;';
----         END IF;
--        --抽出学年チェック
----         IF g_nHaniKubun = 2 AND (g_VJOKEN01 IS NULL OR g_VJOKEN02 IS NULL) THEN
----           VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件5と条件6：抽出開始学年と抽出終了学年が正しくありません。,;';
----         END IF;
----  2024/09/29 ZCZL.YUCHUFEI DELETE END
--        --処理条件.抽出開始年月日チェック
--        bRTN := KKAPK0020.FISDATEW(g_nStartYmd7);
--        IF NOT bRTN THEN
--          --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.004:IT_GKB_00338の対応
--          --VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件3：抽出開始年月日が正しくありません。,;';
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件3：抽出開始年月日 範囲(開始)が正しくありません。,;';
--        END IF;
--        --処理条件.抽出終了年月日チェック
--        bRTN := KKAPK0020.FISDATEW(g_nEndYmd7);
--        IF NOT bRTN THEN
--          --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.004:IT_GKB_00338の対応
--          --VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件4：抽出終了年月日が正しくありません。,;';
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件4：抽出終了年月日 範囲(終了)が正しくありません。,;';
--        END IF;
--        --抽出開始年月日 >抽出終了年月日の場合
--        IF g_nStartYmd7 > g_nEndYmd7 THEN
--          --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.004:IT_GKB_00338の対応
--          --VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件3、4：抽出開始年月日、抽出終了年月日の関係が正しくありません。,;';
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件3、4：抽出開始年月日 範囲(開始)、抽出終了年月日 範囲(終了)の関係が正しくありません。,;';
--        END IF;
--抽出範囲：異動日または処理日の場合
        --処理条件.抽出開始年月日チェック
        IF g_nHaniKubun = 0 OR g_nHaniKubun = 1  THEN
          --抽出学年が入力された場合 
            IF g_VJOKEN01 IS NOT NULL THEN
                VMSG := g_sGYOUMUCODE || ',99999,条件5：開始学年が入力されています,;';                         
            ELSIF g_VJOKEN02 IS NOT NULL THEN
                VMSG := g_sGYOUMUCODE || ',99999,条件6：終了学年が入力されています,;';
            END IF ;
        --処理条件.抽出開始年月日チェック    
           bRTN := KKAPK0020.FISDATEW(g_nStartYmd7);
             IF NOT bRTN THEN
                VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件3：抽出開始年月日 範囲(開始)が正しくありません。,;';
             END IF;
        --処理条件.抽出終了年月日チェック
           bRTN := KKAPK0020.FISDATEW(g_nEndYmd7);
             IF NOT bRTN THEN
                VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件4：抽出終了年月日 範囲(終了)が正しくありません。,;';
             END IF;
        --抽出開始年月日 >抽出終了年月日の場合
             IF g_nStartYmd7 > g_nEndYmd7 THEN
                VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件3、4：抽出開始年月日 範囲(開始)、抽出終了年月日 範囲(終了)の関係が正しくありません。,;';
             END IF;
          END IF;     
--抽出範囲：学年の場合
    --処理条件.抽出開始年月日チェック　
        IF g_nHaniKubun = 2  THEN
           bRTN := KKAPK0020.FISDATEW(g_nStartYmd7);
             IF  bRTN THEN
                VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件3：抽出開始年月日 範囲(開始)が入力されています。,;';
             END IF;
        --処理条件.抽出終了年月日チェック
           bRTN := KKAPK0020.FISDATEW(g_nEndYmd7);
             IF  bRTN THEN
                VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件4：抽出終了年月日 範囲(終了)が入力されています。,;';
             END IF;
        --処理条件.学年範囲チェック
         --開始学年チェック
           IRTN := FUNCGAKUNENCHK( g_VJOKEN01 ) ;
             IF IRTN <> 0 THEN
              ICHK1 := 1 ;
               VMSG := g_sGYOUMUCODE || ',99999,条件5：開始学年が正しくありません。,;';
             END IF ;
         --終了学年チェック
            IRTN := FUNCGAKUNENCHK( g_VJOKEN02 ) ;
             IF IRTN <> 0 THEN
              ICHK2 := 1 ;
               VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件6：終了学年が正しくありません。,;';
             END IF ;
        --開始学年と終了学年の大小チェックを行う。
             IF ICHK1 = 0 AND ICHK2 = 0 THEN
               IRTN := FUNCHIKAKUCHK( g_VJOKEN01, g_VJOKEN02 ) ;
               IF IRTN <> 0 THEN
                 VMSG := VMSG || g_sGYOUMUCODE || ',99999,開始学年と終了学年の大小関係が誤っています。,;';
               END IF ;
             END IF ;
        END IF ;       
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応        
        --対象者指定宛名番号の桁数が15位未満の場合
--  2024/09/29 ZCZL.YUCHUFEI UPDATE 0.3.000.003:仕様変更 IT_GKB_00161対応
--         IF LENGTH(g_nShiteiKojinId) < 15 THEN
        IF LENGTH(g_nShiteiKojinId) <> 15 THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,条件7：対象者指定宛名番号が正しくありません。,;';
        END IF;
--  2024/07/02 ZCZL.caijiacun Add end
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
      nCNT                          NUMBER;
      sJOKEN                        NVARCHAR2(500);
    BEGIN
--  2024/07/03 ZCZL.caijiacun Update start 0.3.000.000:新WizLIFE２次開発対応
        sJOKEN := ' WSNUM = ' ||  '''' || g_sWSNUM || '''' || ' AND BATCHKBN = ' || c_BATCH;
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--        nCNT := GKBFKTBLCNT('GKBWL110R001', sJOKEN);
        nCNT := GKBFKTBLCNT('GKBWHOGOSHACHK', NULL);
        g_oKENSU_LIST.EXTEND(2);
        g_oKENSU_LIST(1) := GKBEKENSU_RECORD(nCNT, '入力　保護者情報チェック一覧表対象件数', 1);
        g_oKENSU_LIST(2) := GKBEKENSU_RECORD(g_nCOUNT, '出力 保護者情報チェック一覧表ＣＳＶ', 2);
--  2024/07/03 ZCZL.caijiacun Update end
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
    -- 保護者ワーク中間（GKBWHOGOSHACHK）レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        IFRET                PLS_INTEGER;                -- 戻り値
        NNENDO              PLS_INTEGER;                -- 年度
        NGAKUNEN_CD              NUMBER;                -- 学年コード
        NSYURYOGAKUNEN_CD   NUMBER;                     -- 終了学年コード
        IRTNA               PLS_INTEGER;
        IRTNSANTEIDANTAI    PLS_INTEGER;
        IRTNAH              PLS_INTEGER;
        IRET                PLS_INTEGER;
        ICNT                BINARY_INTEGER;             -- 戻り値
        BRTNSASKUSEIBI      BOOLEAN;
        IJUSHO_NAGASA       PLS_INTEGER;
        ISHIMEINAGASA       PLS_INTEGER;
        IRTNZOKUGARA1        PLS_INTEGER;
        IRTNZOKUGARAHERR1    PLS_INTEGER;
        IRTNZOKUGARA2        PLS_INTEGER;
        IRTNZOKUGARAHERR2    PLS_INTEGER;
        NPRTN                NUMBER;
        BRTN                 BOOLEAN;
        NJIDO_KOJIN_NO       NUMBER;
        ICOUNT               PLS_INTEGER;
--  2024/07/03 ZCZL.caijiacun Add start 0.3.000.000:新WizLIFE２次開発対応
        sSQL                 NVARCHAR2(3000);
        rCJIDO               MC_CURSOR;
        sJIDO_SHIMEI_KANA    NVARCHAR2(500);             --児童氏名カナ
        sSHIMEI_KANA         NVARCHAR2(500);             --保護者氏名カナ
        sJIDO_SHIMEI_KANJI   NVARCHAR2(500);             --児童氏名漢字
        sSHIMEI_KANJI        NVARCHAR2(500);             --保護者氏名漢字
        sHYOJI_SEINENGAPI    NVARCHAR2(500);             --表示用生年月日
        tRATENA_RECORD       GABTATENAKIHON%ROWTYPE;
        tRSOFU_RECORD        GABTSOFUSAKI%ROWTYPE;
        sKOKUMEI_KANA        NVARCHAR2(200);             --国名カナ
        sKOKUMEI_KANJI       NVARCHAR2(200);             --国名漢字
        sKOKUMEI_ARUFABETTO  NVARCHAR2(200);             --国名アルファベット
        NRTN                 NUMBER;
        IERR                 PLS_INTEGER;
        aRPAM                A_CONS_PRM;
--  2024/07/03 ZCZL.caijiacun Add end
    BEGIN
        IFRET := c_INOTFOUND;                 -- 該当なし
        NGAKUNEN_CD := TO_NUMBER(VGAKUNEN);          -- 学年
        NSYURYOGAKUNEN_CD := TO_NUMBER(VSYURYOGAKUNEN);          -- 学年
        ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));

        -- ワーク領域の初期化
        MHOGOSHA_WORK.DELETE;
        ICNT := 0;
        ICOUNT := 0;
        BEGIN
--  2024/07/02 ZCZL.caijiacun Update start 0.3.000.000:新WizLIFE２次開発対応
            sSQL := '';
            sSQL := sSQL || ' SELECT BO.KOJIN_NO,                   ';
            sSQL := sSQL || '        BO.GAKKO_KBN_CD,               ';
            sSQL := sSQL || '        BO.SYOGAKO_CD,                 ';
            sSQL := sSQL || '        BO.TYUGAKO_CD,                 ';
            sSQL := sSQL || '        BO.KUIKIGAI_CD,                ';
            sSQL := sSQL || '        BO.YOGOGAKO_CD,                ';
            sSQL := sSQL || '        BO.KUNISHIRITSU_CD,            ';
            sSQL := sSQL || '        BO.SEIBETSU,                   ';
            sSQL := sSQL || '        BO.GAKUNEN,                    ';
            sSQL := sSQL || '        BO.HOGOSYA_ZOKUGARA1,          ';
            sSQL := sSQL || '        BO.HOGOSYA_ZOKUGARA2,          ';
            sSQL := sSQL || '        BO.HOGOSYA_ZOKUGARA3,          ';
            sSQL := sSQL || '        BO.HOGOSYA_ZOKUGARA4,          ';
            sSQL := sSQL || '        BO.IDO_BI,                     ';
            sSQL := sSQL || '        DO.JUMIN_NAKUNARU,             ';
            sSQL := sSQL || '        DO.JUMIN_NAKUNARU_TODOKEDE_BI, ';
            sSQL := sSQL || '        HON.NUSHI_SHIMEI_KANJI,        ';
            sSQL := sSQL || '        NK.GAKUNEN_CD,                 ';
            sSQL := sSQL || '        BO.HOGOSYA_KOJIN_NO            ';
            sSQL := sSQL || '   FROM GKBTGAKUREIBO  BO,             ';
            sSQL := sSQL || '        JIBTJUKIIDO    DO,             ';
            sSQL := sSQL || '        GABTATENAKIHON HON,            ';
            sSQL := sSQL || '        GKBTGAKUNENLNK NK              ';
--  2025/06/27 JIP.Y.SATO UPD START 1.0.010.000
--            sSQL := sSQL || '  WHERE BO.KOJIN_NO = DO.KOJIN_NO  AND ';
            sSQL := sSQL || '  WHERE BO.KOJIN_NO = DO.KOJIN_NO(+)  AND ';
--  2025/06/27 JIP.Y.SATO UPD END 1.0.010.000
            sSQL := sSQL || '        BO.KOJIN_NO = NK.KOJIN_NO  AND ';
            sSQL := sSQL || '        BO.KOJIN_NO = HON.KOJIN_NO AND ';
            sSQL := sSQL || '        BO.SAISHIN_KBN = 0         AND ';
            sSQL := sSQL || '        BO.GEN_NENGAPI = 0         AND ';
            sSQL := sSQL || '        BO.SAKUJO_FLG  = 0             ';
            CASE g_nCHUTAISYOU
              WHEN 0 THEN
                --抽出対象 = "エラー分のみ"の場合
                sSQL := sSQL || 'AND NVL(BO.HOGOSYA_KOJIN_NO,0) = 0 ';
              WHEN 1 THEN
                --抽出対象 = "エラー分含む全件"の場合
                NULL;
              WHEN 2 THEN
                --抽出条件 が 2：対象者指定の場合
                sSQL := sSQL || 'AND BO.HOGOSYA_KOJIN_NO = ' || g_nShiteiKojinId;
            END CASE;
            CASE g_nHaniKubun
              --「異動日範囲」の場合
              WHEN 0 THEN
                sSQL := sSQL || 'AND BO.IDO_BI >= ' || g_nStartYmd;
                sSQL := sSQL || 'AND BO.IDO_BI <= ' || g_nEndYmd;
              --「処理日範囲」の場合
              WHEN 1 THEN
                sSQL := sSQL || 'AND BO.SHORIBI >= ' || g_nStartYmd;
                sSQL := sSQL || 'AND BO.SHORIBI <= ' || g_nEndYmd;
              --「学年範囲」の場合
              WHEN 2 THEN
                sSQL := sSQL || 'AND NK.GAKUNEN_CD >= ' || g_VJOKEN01;
                sSQL := sSQL || 'AND NK.GAKUNEN_CD <= ' || g_VJOKEN02;
            END CASE;

          OPEN rCJIDO FOR sSQL;
          LOOP
            FETCH rCJIDO INTO CRJIDO;
            -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
            EXIT WHEN rCJIDO%NOTFOUND;
--            FOR CRJIDO IN CJIDO(NGAKUNEN_CD,NSYURYOGAKUNEN_CD) LOOP
--  2024/07/02 ZCZL.caijiacun Update end
        VCNT :=  TO_CHAR(ICNT);
            GKBSKJDOG(CRJIDO.KOJIN_NO,RG,NPRTN);

            NJIDO_KOJIN_NO := CRJIDO.KOJIN_NO;

          IF NPRTN = 0 AND
             RG.GEN_JIYU_CD = 0 AND
             RG.SAISHIN_KBN = 0 THEN
             IRTNA := GAAPK0030.FGETATENA( CRJIDO.KOJIN_NO,
                                         'GKB',
                                         ISAKUSEIBI,
                                         RA,
                                         RASO);
            VJINKAKU_KBN := RA.JINKAKU_KBN;
            --変数.児童生徒住所 := 児童生徒宛名管理レコード.町名＋児童生徒宛名管理レコード.番地＋'　'＋児童生徒宛名管理レコード.方書
            VJIDO_JUSHO := RA.CHOMEI || RA.BANCHI || '　' || RA.KATAGAKI;
            -- 保護者が設定されているもの
            IF RG.HOGOSYA_KOJIN_NO <> 0 THEN
               IRTNAH := GAAPK0030.FGETATENA(  RG.HOGOSYA_KOJIN_NO,
                                             'GKB',
                                             ISAKUSEIBI,
                                             RB,
                                             RC);

               IRTNZOKUGARA1 := GKBFKZKGMGET(1,
                                             RG.ZOKUGARA1,
                                             RG.ZOKUGARA2,
                                             RG.ZOKUGARA3,
                                             RG.ZOKUGARA4,
                                             VZOKUGARAMEI1,
                                             IRTNZOKUGARAHERR1);

               IRTNZOKUGARA2 := GKBFKZKGMGET(2,
                                             RG.HOGOSYA_ZOKUGARA1,
                                             RG.HOGOSYA_ZOKUGARA2,
                                             RG.HOGOSYA_ZOKUGARA3,
                                             RG.HOGOSYA_ZOKUGARA4,
                                             VZOKUGARAMEI2,
                                             IRTNZOKUGARAHERR2);
               --変数.保護者住所 := 保護者宛名管理レコード.町名＋保護者宛名管理レコード.番地＋'　'＋保護者宛名管理レコード.方書
               VHOGOSHA_JUSHO := RB.CHOMEI || RB.BANCHI || '　' || RB.KATAGAKI;
              IF RA.JINKAKU_KBN = 1 THEN
                 IRET := GKBPK00010.FGKJHGS(ISAKUSEIBI,
                                                       CRJIDO.KOJIN_NO, 
                                                       NHOGOSHA_NO,
                                                       VSHIMEI_KANJI);
              ELSE
                 -- 保護者判定サブルーチン
                 IRET := GKBPK00010.FHOGOSHA(ISAKUSEIBI, CRJIDO.KOJIN_NO, NHOGOSHA_NO);
              END IF;
              VHOGOSHA_SHIMEI_JODAN := RB.SHIMEI_KANA;
              VHOGOSHA_SHIMEI_GEDAN := RB.SHIMEI_KANJI;
              VHOGOSHA_SETAI_NO :=  TO_CHAR(RB.SETAI_NO);

              -- 保護者が住民でなくなったもの
              --住登外も含まれるため喪失（＝１）、喪失後住登外（＝２）に限定
              IF RB.GENZON_KBN IN (1,2) THEN

                    SELECT JUMIN_NAKUNARU_JIYU
                      INTO IJUMIN_NAKUNARU_JIYU
                      FROM GABTJUKIIDO
                     WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;

                    BEGIN
                      SELECT IDO_JIYU_MEI
                        INTO VSOSHITSU_JIYU
                      FROM GABTIDOJIYU
                       WHERE IDO_JIYU_CD = IJUMIN_NAKUNARU_JIYU;
                    VIDO_JIYU := VSOSHITSU_JIYU;
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                        DBMS_OUTPUT.PUT_LINE('該当異動事由なし　'||IJUMIN_NAKUNARU_JIYU||' '||RG.KOJIN_NO);
                        VSOSHITSU_JIYU := ' ';
                        VIDO_JIYU := '　';
                    END;
--  2024/07/02 ZCZL.caijiacun Update start 0.3.000.000:新WizLIFE２次開発対応
--                    SELECT JUMIN_NAKUNARU,
--                           JUMIN_NAKUNARU_TODOKEDE_BI  --住民でなくなる届出日
--                      INTO IIDO_NENGAPI,
--                           IJUMIN_NAKUNARU_TODOKEDE_BI  --変数.住民でなくなる届出日
--                      FROM GABTJUKIIDO
--                     WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                     IIDO_NENGAPI := CRJIDO.JUMIN_NAKUNARU;
                     IJUMIN_NAKUNARU_TODOKEDE_BI := CRJIDO.JUMIN_NAKUNARU_TODOKEDE_BI;
--  2024/07/02 ZCZL.caijiacun Update end
                         IWAREKIHIZUKE := 0;  
                         BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                      IIDO_NENGAPI,
                                                      VIDO_NENGAPI,
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
                                                      IJUMIN_NAKUNARU_TODOKEDE_BI,--取得した届出日
                                                      VTODOKEDEBI,                --変数.届出日
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
                         
             END IF;
             --バッチ処理条件3で住所チェック有とした場合(変数.住所チェックフラグ　＝　0　場合)
             IF NJIYUSHIYOCHKFLG = 0 THEN
               IF VJIDO_JUSHO <> VHOGOSHA_JUSHO THEN
                 --b. 変数.児童生徒住所 <> 変数.保護者住所の場合、喪失事由、異動年月日、届出日、異動事由をセットする。
                 VSOSHITSU_JIYU := '住所不一致';  --変数.喪失事由
                 VIDO_NENGAPI := '　';            --変数.異動年月日
                 VTODOKEDEBI := '　';             --変数.届出日
                 VIDO_JIYU := '　';               --変数.異動事由
               END IF;
             END IF;
             IF RA.SETAI_NO <> RB.SETAI_NO THEN
                    VSOSHITSU_JIYU := '世帯番号不一致';
                    VIDO_NENGAPI := '　';
                    VTODOKEDEBI := '　';             --変数.届出日
                    VIDO_JIYU := '　';               --変数.異動事由
              ELSE

                   NULL;
              END IF;

             -- 保護者判定サブルーチンより取得した保護者と異なるもの
             IF NHOGOSHA_NO <> 0 AND RG.HOGOSYA_KOJIN_NO <> NHOGOSHA_NO THEN
                DBMS_OUTPUT.PUT_LINE('判定不一致 '||RG.HOGOSYA_KOJIN_NO||' '||NHOGOSHA_NO);
                -- 喪失事由
                VSOSHITSU_JIYU := '判定不一致';
                -- 異動年月日
                VIDO_NENGAPI := '';
                VTODOKEDEBI := '　';             --変数.届出日
                VIDO_JIYU := '　';               --変数.異動事由

             END IF;
             IF RG.HOGOSYA_ZOKUGARA1 = 0 
                AND RG.HOGOSYA_ZOKUGARA2 = 0
                AND RG.HOGOSYA_ZOKUGARA3 = 0
                AND RG.HOGOSYA_ZOKUGARA4 = 0 THEN
                VSOSHITSU_JIYU := '保護者続柄未登録';
             END IF;
            -- 保護者が設定されていないもの
            ELSE
                 -- 保護者番号が０のときはNULL
                    MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANA := NULL;
                    MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := NULL;
                    VSOSHITSU_JIYU := '保護者登録なし';
                    VIDO_NENGAPI := '　';
                    VHOGOSHA_SETAI_NO := NULL;
                    VZOKUGARAMEI1 := NULL;
                    VZOKUGARAMEI2 := NULL;
                    VHOGOSHA_SHIMEI_JODAN := NULL;
                    VHOGOSHA_SHIMEI_GEDAN := NULL;
                    VTODOKEDEBI := '　';             --変数.届出日
                    VIDO_JIYU := '　';               --変数.異動事由
                    VHOGOSHA_JUSHO := '　';          --変数.保護者住所
            END IF;

            SELECT COUNT(1) INTO ICOUNT
                FROM GABTATENAKIHON A,
                       (SELECT HOGOSYA_KOJIN_NO
                FROM GKBTGAKUREIBO
                WHERE KOJIN_NO IN
                           (SELECT KOJIN_NO
                            FROM GABTATENAKIHON
                                    WHERE SETAI_NO   = RA.SETAI_NO
                              AND KOJIN_NO  <> CRJIDO.KOJIN_NO
                              AND GENZON_KBN = 0)
                        AND SAISHIN_KBN = 0
                        AND GEN_NENGAPI = 0
                        AND GAKUNEN    <> 99
                        ) B
            WHERE A.KOJIN_NO  = B.HOGOSYA_KOJIN_NO
            AND A.SETAI_NO <> RB.SETAI_NO;
            IF  ICOUNT > 0 THEN
                VSOSHITSU_JIYU := ' 同一世帯不一致';
            END IF;

            IF RG.TYUGAKO_CD = 0 THEN
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
                   VGAKOMEI := ' ';
               END;
                 VGAKUNENSEI := TO_CHAR(CRJIDO.GAKUNEN_CD);
                 VGAKUNENMEI := VGAKUNENSEI || '年生';
            ELSE
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
                   VGAKOMEI := ' ';
               END;
                 NGAKUNENSEI := CRJIDO.GAKUNEN_CD - 6;
                 VGAKUNENSEI := TO_CHAR(NGAKUNENSEI);
                 VGAKUNENMEI := VGAKUNENSEI || '年生';
            END IF;



            IWAREKIHIZUKE := 0;  
            BRTNSEINENGAPI := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
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

            IF RA.SEIBETSU = 1 THEN
               VSEIBETSU := '男';
            ELSIF RA.SEIBETSU = 2 THEN
               VSEIBETSU := '女';
            END IF;

            VSETAI_NO :=  TO_CHAR(RA.SETAI_NO);

            VGYOSEIKU_MEI := GAAPK0030.FGYOSEIKUMEI(RA.SANTEIDANTAI_CD,RA.GYOSEIKU_CD);

            VHAN_MEI := GAAPK0030.FHANMEI(RA.SANTEIDANTAI_CD,
                                           RA.HAN_CD);

            IRTNSANTEIDANTAI := GAAPK0030.FJICHINAME(RA.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);

            NNENDO := TO_NUMBER(VNENDO);          -- 年度
            VHYOUJINENDO := KKAPK0020.FNENDOEDIT(1,
                                                  NNENDO,
                                                  3);
            IWAREKIHIZUKE := 0;  
            BRTNSASKUSEIBI := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
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

            IJUSHO_NAGASA := LENGTH(RA.CHOMEI||RA.BANCHI||RA.KATAGAKI);
            IF IJUSHO_NAGASA > 15 THEN
               VJUSHO_JODAN := SUBSTR (RA.CHOMEI||RA.BANCHI||RA.KATAGAKI,1,15);
               VJUSHO_GEDAN := SUBSTR (RA.CHOMEI||RA.BANCHI||RA.KATAGAKI,16,15); 
            ELSE
               VJUSHO_GEDAN := SUBSTR (RA.CHOMEI||RA.BANCHI||RA.KATAGAKI,1,15);
            END IF;
    DBMS_OUTPUT.PUT_LINE('☆ '||RG.HOGOSYA_KOJIN_NO||' '||RB.GENZON_KBN ||' '||RA.SETAI_NO ||' '||RB.SETAI_NO ||' '||NHOGOSHA_NO);
            IF RG.HOGOSYA_KOJIN_NO = 0 OR
              (RG.HOGOSYA_KOJIN_NO <> 0 AND (RB.GENZON_KBN IN (1,2) OR
                                            (RA.SETAI_NO <> RB.SETAI_NO) OR
                                            (NHOGOSHA_NO <> 0 AND RG.HOGOSYA_KOJIN_NO <> NHOGOSHA_NO) OR
                                            (RG.HOGOSYA_ZOKUGARA1 = 0 AND RG.HOGOSYA_ZOKUGARA2 = 0 AND RG.HOGOSYA_ZOKUGARA3 = 0 AND RG.HOGOSYA_ZOKUGARA4 = 0) OR (NJIYUSHIYOCHKFLG = 0 AND VJIDO_JUSHO <> VHOGOSHA_JUSHO))) OR                                        
              ICOUNT > 0 THEN

                    MHOGOSHA_WORK(ICNT).HANTEI_KBNI := 0;
                    MHOGOSHA_WORK(ICNT).JIDO_KOJIN_NO := RG.KOJIN_NO;
                    MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA := RA.SHIMEI_KANA;
                    MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI := RA.SHIMEI_KANJI;
                    MHOGOSHA_WORK(ICNT).SEINENGAPI := RA.SEINENGAPI;
                    MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI := VSEINENGAPI;
                    MHOGOSHA_WORK(ICNT).SEIBETSU := RA.SEIBETSU;
                    MHOGOSHA_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;
                    MHOGOSHA_WORK(ICNT).ZOKUGARAMEI1 := VZOKUGARAMEI1;
                    MHOGOSHA_WORK(ICNT).JIDO_SETAI_NO := RA.SETAI_NO;
                    MHOGOSHA_WORK(ICNT).HYOJI_JIDO_SETAI_NO := VSETAI_NO;
                    MHOGOSHA_WORK(ICNT).HOGOSHA_KOJIN_NO := RG.HOGOSYA_KOJIN_NO;

                    MHOGOSHA_WORK(ICNT).ZOKUGARAMEI2 := VZOKUGARAMEI2;
                    MHOGOSHA_WORK(ICNT).HOGOSHA_SETAI_NO := VHOGOSHA_SETAI_NO;
                    MHOGOSHA_WORK(ICNT).SOSHITSU_JIYU := VSOSHITSU_JIYU;
                    MHOGOSHA_WORK(ICNT).IDO_NENGAPI := VIDO_NENGAPI;
                    MHOGOSHA_WORK(ICNT).GAKUNEN_CD := CRJIDO.GAKUNEN_CD;
                    MHOGOSHA_WORK(ICNT).GAKUNENMEI := VGAKUNENMEI;
                    MHOGOSHA_WORK(ICNT).GAKOKU_CD := IGAKO_CD;
                    MHOGOSHA_WORK(ICNT).GAKOKUMEI := VGAKOMEI;
                    MHOGOSHA_WORK(ICNT).GYOSEIKU_CD := RA.GYOSEIKU_CD;
                    MHOGOSHA_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;
                    MHOGOSHA_WORK(ICNT).HAN_CD := RA.HAN_CD;
                    MHOGOSHA_WORK(ICNT).HANMEI := VHAN_MEI;
                    MHOGOSHA_WORK(ICNT).SANTEIDANTAI_CD := RA.SANTEIDANTAI_CD;
                    MHOGOSHA_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;
                    MHOGOSHA_WORK(ICNT).KAIPEJI_CD := ' ';
                    MHOGOSHA_WORK(ICNT).KAIPEJI := ' ';
                    MHOGOSHA_WORK(ICNT).SAKUSEIBI := VSASKUSEIBI;
                    MHOGOSHA_WORK(ICNT).RENBAN := ICNT + 1;
                    MHOGOSHA_WORK(ICNT).HYOJI_RENBAN := VCNT;
                    MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := VHOGOSHA_SHIMEI_JODAN;
                    MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN := VHOGOSHA_SHIMEI_GEDAN;
                    MHOGOSHA_WORK(ICNT).KON_JUSHO_JODAN := VJUSHO_JODAN;
                    MHOGOSHA_WORK(ICNT).KON_JUSHO_GEDAN := VJUSHO_GEDAN;
                    MHOGOSHA_WORK(ICNT).JINKAKU_KBN := VJINKAKU_KBN;
                    --保護者チェックワーク格納用変数.児童生徒住所（MHOGOSHA_WORK(ICNT).JIDO_JUSHO） := 変数.児童生徒住所
                    MHOGOSHA_WORK(ICNT).JIDO_JUSHO := VJIDO_JUSHO;
                    --保護者チェックワーク格納用変数.保護者住所（MHOGOSHA_WORK(ICNT).HOGOSHA_JUSHO） := 変数.保護者住所
                    MHOGOSHA_WORK(ICNT).HOGOSHA_JUSHO := VHOGOSHA_JUSHO;
                    --保護者チェックワーク格納用変数.届出日（MHOGOSHA_WORK(ICNT).TODOKEDEBI） := 変数.届出日
                    MHOGOSHA_WORK(ICNT).TODOKEDEBI := VTODOKEDEBI;
                    --保護者チェックワーク格納用変数.異動事由（MHOGOSHA_WORK(ICNT).IDO_JIYU） := 変数.異動事由
                    MHOGOSHA_WORK(ICNT).IDO_JIYU := VIDO_JIYU;
--  2024/07/03 ZCZL.caijiacun Add start 0.3.000.000:新WizLIFE２次開発対応
                    --児童
                    NRTN := GKBFKHMCTRL(CRJIDO.KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_sOUTPUTCHACK, sJIDO_SHIMEI_KANA, sJIDO_SHIMEI_KANJI, sHYOJI_SEINENGAPI);
                    MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA := sJIDO_SHIMEI_KANA;   --児童氏名カナ
                    MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI := sJIDO_SHIMEI_KANJI; --児童氏名漢字
--  2025/01/23 JPJYS.GL UPDATE ST_GKB_TMP00001対応 start
                    --MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI := sHYOJI_SEINENGAPI;   --表示用生年月日
                    MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(RA.SEINENGAPI,'YYYYMMDD'),'YYYY/MM/DD') ,3);   --表示用生年月日
--  2025/01/23 JPJYS.GL UPDATE ST_GKB_TMP00001対応 end
                    --保護者
                    NRTN := GKBFKHMCTRL(CRJIDO.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_sOUTPUTCHACK, sSHIMEI_KANA, sSHIMEI_KANJI, sHYOJI_SEINENGAPI);
                    MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANA  := sSHIMEI_KANA;    --保護者氏名カナ
                    MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := sSHIMEI_KANJI;   --保護者氏名漢字
                    --学校区分コード
                    MHOGOSHA_WORK(ICNT).GAKKO_KUBUN_CD := CRJIDO.GAKKO_KBN_CD;
                    --学校区分
                    NRTN := KKAPK0030.FCTGetR('GKB', '037', '0000', CRJIDO.GAKKO_KBN_CD, aRPAM);
                    IF NRTN = 0 AND aRPAM IS NOT NULL THEN
                      MHOGOSHA_WORK(ICNT).GAKKO_KUBUN := aRPAM(1);
                    END IF;
                    --学校コード
                    CASE CRJIDO.GAKKO_KBN_CD
                      WHEN '1' THEN  --小学校
                        MHOGOSHA_WORK(ICNT).GAKKO_CD := CRJIDO.SYOGAKO_CD;
                      WHEN '2' THEN  --中学校
                        MHOGOSHA_WORK(ICNT).GAKKO_CD := CRJIDO.TYUGAKO_CD;
                      WHEN '3' THEN  --特別支援学校
                        MHOGOSHA_WORK(ICNT).GAKKO_CD := CRJIDO.YOGOGAKO_CD;
                      WHEN '4' THEN  --区域外学校
                        MHOGOSHA_WORK(ICNT).GAKKO_CD := CRJIDO.KUIKIGAI_CD;
                      WHEN '5' THEN  --国・私立学校
                        MHOGOSHA_WORK(ICNT).GAKKO_CD := CRJIDO.KUNISHIRITSU_CD;
                      ELSE
                        NULL;
                    END CASE;
                    --学校名
                    MHOGOSHA_WORK(ICNT).GAKKO_MEI_HYOJI := GKAFKGKOGTEQ(CRJIDO.GAKKO_KBN_CD, MHOGOSHA_WORK(ICNT).GAKKO_CD);
                    --児童生徒国籍
                    NRTN := GAAPK0030.FGETATENA(CRJIDO.KOJIN_NO, 'GKB', g_dDATE, tRATENA_RECORD, tRSOFU_RECORD);
                    NRTN := GKAFKKKMGET(tRATENA_RECORD.KOKUSEKI_CD, sKOKUMEI_KANA, sKOKUMEI_KANJI, sKOKUMEI_ARUFABETTO);
                    MHOGOSHA_WORK(ICNT).JIDO_KOKUSEKI := sKOKUMEI_KANJI;
                    --世帯主氏名漢字
                    MHOGOSHA_WORK(ICNT).SETAINUSHI_SHIMEIKANJI := CRJIDO.NUSHI_SHIMEI_KANJI;   
                    --続柄
                    NRTN := GKBFKZKGMGET(2, 
                                CRJIDO.HOGOSYA_ZOKUGARA1, 
                                CRJIDO.HOGOSYA_ZOKUGARA2, 
                                CRJIDO.HOGOSYA_ZOKUGARA3, 
                                CRJIDO.HOGOSYA_ZOKUGARA4, 
                                MHOGOSHA_WORK(ICNT).ZOKUGARA,
                                IERR);
                    --保護者国籍
                    NRTN := GAAPK0030.FGETATENA(CRJIDO.HOGOSYA_KOJIN_NO, 'GKB', g_dDATE, tRATENA_RECORD, tRSOFU_RECORD);
                    NRTN := GKAFKKKMGET(tRATENA_RECORD.KOKUSEKI_CD, sKOKUMEI_KANA, sKOKUMEI_KANJI, sKOKUMEI_ARUFABETTO);
                    MHOGOSHA_WORK(ICNT).HOGOSHA_KOKUSEKI := sKOKUMEI_KANJI;
--  2024/07/03 ZCZL.caijiacun Add end
                    ICNT := ICNT + 1;               -- カウントアップ
                    IFRET := c_ISUCCESS;              -- 正常終了
                  ELSE
                        NULL;
                  END IF;
                END IF;
            END LOOP;
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応 
            RETURN IFRET;
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応 
        EXCEPTION
            WHEN OTHERS THEN

                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);

                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, 'エラー児童宛名番号＝' || NJIDO_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
                -- 処理の終了通知
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
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);
            -- 処理の終了通知
        RETURN IFRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 保護者ワーク中間（GKBWHOGOSHACHK）テーブルの作成
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
        IMAX := MHOGOSHA_WORK.LAST;
        -- ワーク領域の先頭位置を取得
        IMIN := MHOGOSHA_WORK.FIRST;

        BEGIN
            -- ワーク領域の件数分繰り返し処理を行う
            FOR ICNT IN IMIN..IMAX LOOP
                INSERT INTO
                GKBWHOGOSHACHK
                (
                 HANTEI_KBNI,
                 JIDO_KOJIN_NO,
                 JIDO_SHIMEI_KANA,
                 JIDO_SHIMEI_KANJI,
                 SEINENGAPI,
                 HYOJI_SEINENGAPI,
                 SEIBETSU,
                 HYOJI_SEIBETSU,
                 ZOKUGARAMEI1,
                 JIDO_SETAI_NO,
                 HYOJI_JIDO_SETAI_NO,
                 HOGOSHA_KOJIN_NO,
                 HOGOSHA_SHIMEI_KANA,
                 HOGOSHA_SHIMEI_KANJI,
                 ZOKUGARAMEI2,
                 HOGOSHA_SETAI_NO,
                 SOSHITSU_JIYU,
                 IDO_NENGAPI,
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
                 KAIPEJI_CD,
                 KAIPEJI,
                 SAKUSEIBI,
                 RENBAN,
                 HYOJI_RENBAN,
                 HOGOSHA_SHIMEI_JODAN,
                 HOGOSHA_SHIMEI_GEDAN,
                 KON_JUSHO_JODAN,
                 KON_JUSHO_GEDAN,
                 JINKAKU_KBN,
                 JIDO_JUSHO,
                 HOGOSHA_JUSHO,
                 TODOKEDEBI,
                 IDO_JIYU,
--  2024/07/03 ZCZL.caijiacun Add start 0.3.000.000:新WizLIFE２次開発対応
                 GAKKO_KUBUN_CD,
                 GAKKO_KUBUN,
                 GAKKO_CD,
                 GAKKO_MEI_HYOJI,
                 JIDO_KOKUSEKI,
                 SETAINUSHI_SHIMEIKANJI,
                 ZOKUGARA,
                 HOGOSHA_KOKUSEKI
--  2024/07/03 ZCZL.caijiacun Add end
                )
                VALUES
                (
                 MHOGOSHA_WORK(ICNT).HANTEI_KBNI,
                 MHOGOSHA_WORK(ICNT).JIDO_KOJIN_NO,
                 MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA,
                 MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI,
                 MHOGOSHA_WORK(ICNT).SEINENGAPI,
                 MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI,
                 MHOGOSHA_WORK(ICNT).SEIBETSU,
                 MHOGOSHA_WORK(ICNT).HYOJI_SEIBETSU,
                 MHOGOSHA_WORK(ICNT).ZOKUGARAMEI1,
                 MHOGOSHA_WORK(ICNT).JIDO_SETAI_NO,
                 MHOGOSHA_WORK(ICNT).HYOJI_JIDO_SETAI_NO,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_KOJIN_NO,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANJI,
                 MHOGOSHA_WORK(ICNT).ZOKUGARAMEI2,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_SETAI_NO,
                 MHOGOSHA_WORK(ICNT).SOSHITSU_JIYU,
                 MHOGOSHA_WORK(ICNT).IDO_NENGAPI,
                 MHOGOSHA_WORK(ICNT).GAKUNEN_CD,
                 MHOGOSHA_WORK(ICNT).GAKUNENMEI,
                 MHOGOSHA_WORK(ICNT).GAKOKU_CD,
                 MHOGOSHA_WORK(ICNT).GAKOKUMEI,
                 MHOGOSHA_WORK(ICNT).GYOSEIKU_CD,
                 MHOGOSHA_WORK(ICNT).GYOSEIKUMEI,
                 MHOGOSHA_WORK(ICNT).HAN_CD,
                 MHOGOSHA_WORK(ICNT).HANMEI,
                 MHOGOSHA_WORK(ICNT).SANTEIDANTAI_CD,
                 MHOGOSHA_WORK(ICNT).SANTEIDANTAIMEI,
                 MHOGOSHA_WORK(ICNT).KAIPEJI_CD,
                 MHOGOSHA_WORK(ICNT).KAIPEJI,
                 MHOGOSHA_WORK(ICNT).SAKUSEIBI,
                 MHOGOSHA_WORK(ICNT).RENBAN,
                 MHOGOSHA_WORK(ICNT).HYOJI_RENBAN,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_JODAN,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN,
                 MHOGOSHA_WORK(ICNT).KON_JUSHO_JODAN,
                 MHOGOSHA_WORK(ICNT).KON_JUSHO_GEDAN,
                 MHOGOSHA_WORK(ICNT).JINKAKU_KBN,
                 MHOGOSHA_WORK(ICNT).JIDO_JUSHO,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_JUSHO,
                 MHOGOSHA_WORK(ICNT).TODOKEDEBI,
                 MHOGOSHA_WORK(ICNT).IDO_JIYU,
--  2024/07/03 ZCZL.caijiacun Add start 0.3.000.000:新WizLIFE２次開発対応
                 MHOGOSHA_WORK(ICNT).GAKKO_KUBUN_CD,
                 MHOGOSHA_WORK(ICNT).GAKKO_KUBUN,
                 MHOGOSHA_WORK(ICNT).GAKKO_CD,
                 MHOGOSHA_WORK(ICNT).GAKKO_MEI_HYOJI,
                 MHOGOSHA_WORK(ICNT).JIDO_KOKUSEKI,
                 MHOGOSHA_WORK(ICNT).SETAINUSHI_SHIMEIKANJI,
                 MHOGOSHA_WORK(ICNT).ZOKUGARA,
                 MHOGOSHA_WORK(ICNT).HOGOSHA_KOKUSEKI
--  2024/07/03 ZCZL.caijiacun Add end
                );
            END LOOP;

            -- コミット（確定）
            COMMIT;

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
        /* その他エラー */
        WHEN OTHERS THEN
            ROLLBACK;       -- 処理前に戻す
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);

            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
            -- 処理の終了通知
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 保護者ワーク（GKBWHOGOSHACHK）CSVの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
        IFRET                PLS_INTEGER;               -- 戻り値
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
        RREC                GKBWHOGOSHACHK%ROWTYPE;      -- 入学通知台帳のレコード変数
        NROWS               NUMBER;                     --
        IPAGECNT            PLS_INTEGER;                -- 頁数
        IGYOCNT             PLS_INTEGER;                -- 行番号
        IGYORENBAN          PLS_INTEGER;                -- 行連番
        VPAGENAME           NVARCHAR2(500);             -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(500);             -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(500);             -- 改頁項目値のワーク
--  2024/07/03 ZCZL.caijiacun Add start 0.3.000.000:新WizLIFE２次開発対応
        sJIDO_SHIMEI_KANA   NVARCHAR2(500);             --児童氏名カナ
        sSHIMEI_KANA        NVARCHAR2(500);             --保護者氏名カナ
        sJIDO_SHIMEI_KANJI  NVARCHAR2(500);             --児童氏名漢字
        sSHIMEI_KANJI       NVARCHAR2(500);             --保護者氏名漢字
        sHYOJI_SEINENGAPI   NVARCHAR2(500);             --表示用生年月日
        sHANTEI_KBNI        NUMBER;
--  2024/07/03 ZCZL.caijiacun Add end
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IGYOCNT := 0;
        ICNT := 0;
        MHOGOSHA_WORK.DELETE;                   -- ワーク領域の初期化
        -- ［ORDER BY］句を付加
        IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
          VSQLORDER := ' ORDER BY ' || g_rJSTP.ORDERBYCLAUSE;
        END IF;
        VPAGEFD := 'GAKOKU_CD';
        VPAGENM := 'GAKOKUMEI';
        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
            VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
            VSQLSEL := VSQLSEL || 'RENBAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
            VSQLSEL := VSQLSEL || 'SOSHITSU_JIYU, ';
            VSQLSEL := VSQLSEL || 'IDO_NENGAPI, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAIMEI, ';
            VSQLSEL := VSQLSEL || VPAGEFD || ' KAIPEJI_CD, ';            -- 改頁値を設定
            VSQLSEL := VSQLSEL || VPAGENM || ' KAIPEJI, ';            -- 改頁名を設定
            VSQLSEL := VSQLSEL || 'JINKAKU_KBN '; 
            VSQLSEL := VSQLSEL || ',JIDO_KOJIN_NO ';
            VSQLSEL := VSQLSEL || ',JIDO_JUSHO ';
            VSQLSEL := VSQLSEL || ',HOGOSHA_KOJIN_NO ';
            VSQLSEL := VSQLSEL || ',HOGOSHA_JUSHO ';
            VSQLSEL := VSQLSEL || ',GAKUNENMEI ';
            VSQLSEL := VSQLSEL || ',TODOKEDEBI ';
            VSQLSEL := VSQLSEL || ',IDO_JIYU ';
--  2024/07/03 ZCZL.caijiacun Add start 0.3.000.000:新WizLIFE２次開発対応
            VSQLSEL := VSQLSEL || ',HANTEI_KBNI ';
            VSQLSEL := VSQLSEL || ',SEINENGAPI ';
            VSQLSEL := VSQLSEL || ',SEIBETSU ';
            VSQLSEL := VSQLSEL || ',HYOJI_JIDO_SETAI_NO ';
            VSQLSEL := VSQLSEL || ',HOGOSHA_SHIMEI_KANA ';
            VSQLSEL := VSQLSEL || ',HOGOSHA_SHIMEI_KANJI ';
            VSQLSEL := VSQLSEL || ',GAKUNEN_CD ';
            VSQLSEL := VSQLSEL || ',GAKOKU_CD ';
            VSQLSEL := VSQLSEL || ',GAKOKUMEI ';
            VSQLSEL := VSQLSEL || ',GYOSEIKU_CD ';
            VSQLSEL := VSQLSEL || ',HAN_CD ';
            VSQLSEL := VSQLSEL || ',HANMEI ';
            VSQLSEL := VSQLSEL || ',SANTEIDANTAI_CD ';
            VSQLSEL := VSQLSEL || ',HYOJI_RENBAN ';
            VSQLSEL := VSQLSEL || ',KON_JUSHO_JODAN ';
            VSQLSEL := VSQLSEL || ',KON_JUSHO_GEDAN ';
            VSQLSEL := VSQLSEL || ',GAKKO_KUBUN_CD ';
            VSQLSEL := VSQLSEL || ',GAKKO_KUBUN ';
            VSQLSEL := VSQLSEL || ',GAKKO_CD ';
            VSQLSEL := VSQLSEL || ',GAKKO_MEI_HYOJI ';
            VSQLSEL := VSQLSEL || ',JIDO_KOKUSEKI ';
            VSQLSEL := VSQLSEL || ',SETAINUSHI_SHIMEIKANJI ';
            VSQLSEL := VSQLSEL || ',ZOKUGARA ';
            VSQLSEL := VSQLSEL || ',HOGOSHA_KOKUSEKI ';
--  2024/07/03 ZCZL.caijiacun Add end
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWHOGOSHACHK ';
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;
            -- カーソルのオープン
            I_CUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(I_CUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, RREC.KAIPEJI, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, RREC.SAKUSEIBI, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.RENBAN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.JIDO_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.JIDO_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.HYOJI_SEINENGAPI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.HYOJI_SEIBETSU, 2);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.ZOKUGARAMEI1, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.HOGOSHA_SHIMEI_JODAN, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.HOGOSHA_SHIMEI_GEDAN, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.ZOKUGARAMEI2, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.SOSHITSU_JIYU, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.IDO_NENGAPI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.GYOSEIKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.JIDO_SETAI_NO);
--  2024/07/03 ZCZL.caijiacun Update 0.3.000.000:新WizLIFE２次開発対応
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.HOGOSHA_SETAI_NO, 7);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.HOGOSHA_SETAI_NO, 15);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.SANTEIDANTAIMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, VPAGENM, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.JINKAKU_KBN);        
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.JIDO_KOJIN_NO);
--  2024/07/03 ZCZL.caijiacun Update 0.3.000.000:新WizLIFE２次開発対応
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.JIDO_JUSHO, 141);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.JIDO_JUSHO, 486);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.HOGOSHA_KOJIN_NO);
--  2024/07/03 ZCZL.caijiacun Update 0.3.000.000:新WizLIFE２次開発対応
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.HOGOSHA_JUSHO, 141);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.HOGOSHA_JUSHO, 486);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.GAKUNENMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.TODOKEDEBI, 9);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.IDO_JIYU, 20);
--  2024/07/03 ZCZL.caijiacun Add start 0.3.000.000:新WizLIFE２次開発対応
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, RREC.HANTEI_KBNI);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, RREC.SEINENGAPI);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, RREC.SEIBETSU);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, RREC.HYOJI_JIDO_SETAI_NO, 15);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, RREC.HOGOSHA_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 34, RREC.HOGOSHA_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 35, RREC.GAKUNEN_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 36, RREC.GAKOKU_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 37, RREC.GAKOKUMEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 38, RREC.GYOSEIKU_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 39, RREC.HAN_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 40, RREC.HANMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 41, RREC.SANTEIDANTAI_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 42, RREC.HYOJI_RENBAN, 6);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 43, RREC.KON_JUSHO_JODAN, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 44, RREC.KON_JUSHO_GEDAN, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 45, RREC.GAKKO_KUBUN_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 46, RREC.GAKKO_KUBUN, 6);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 47, RREC.GAKKO_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 48, RREC.GAKKO_MEI_HYOJI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 49, RREC.JIDO_KOKUSEKI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 50, RREC.SETAINUSHI_SHIMEIKANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 51, RREC.ZOKUGARA, 210);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 52, RREC.HOGOSHA_KOKUSEKI, 60);
--  2024/07/03 ZCZL.caijiacun Add end
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(I_CUR);

            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(I_CUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  1, MHOGOSHA_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  2, MHOGOSHA_WORK(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  3, MHOGOSHA_WORK(ICNT).SAKUSEIBI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  5, MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  6, MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  7, MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MHOGOSHA_WORK(ICNT).HYOJI_SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  9, MHOGOSHA_WORK(ICNT).ZOKUGARAMEI1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_JODAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MHOGOSHA_WORK(ICNT).ZOKUGARAMEI2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MHOGOSHA_WORK(ICNT).SOSHITSU_JIYU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MHOGOSHA_WORK(ICNT).IDO_NENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MHOGOSHA_WORK(ICNT).GYOSEIKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MHOGOSHA_WORK(ICNT).JIDO_SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MHOGOSHA_WORK(ICNT).HOGOSHA_SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 18, MHOGOSHA_WORK(ICNT).SANTEIDANTAIMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 19, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 20, VPAGENAME);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 21, MHOGOSHA_WORK(ICNT).JINKAKU_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 22, MHOGOSHA_WORK(ICNT).JIDO_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 23, MHOGOSHA_WORK(ICNT).JIDO_JUSHO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 24, MHOGOSHA_WORK(ICNT).HOGOSHA_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 25, MHOGOSHA_WORK(ICNT).HOGOSHA_JUSHO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 26, MHOGOSHA_WORK(ICNT).GAKUNENMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 27, MHOGOSHA_WORK(ICNT).TODOKEDEBI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 28, MHOGOSHA_WORK(ICNT).IDO_JIYU);
--  2024/07/03 ZCZL.caijiacun Update start 0.3.000.000:新WizLIFE２次開発対応
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 29, MHOGOSHA_WORK(ICNT).HANTEI_KBNI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 30, MHOGOSHA_WORK(ICNT).SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 31, MHOGOSHA_WORK(ICNT).SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 32, MHOGOSHA_WORK(ICNT).HYOJI_JIDO_SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 33, MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 34, MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 35, MHOGOSHA_WORK(ICNT).GAKUNEN_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 36, MHOGOSHA_WORK(ICNT).GAKOKU_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 37, MHOGOSHA_WORK(ICNT).GAKOKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 38, MHOGOSHA_WORK(ICNT).GYOSEIKU_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 39, MHOGOSHA_WORK(ICNT).HAN_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 40, MHOGOSHA_WORK(ICNT).HANMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 41, MHOGOSHA_WORK(ICNT).SANTEIDANTAI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 42, MHOGOSHA_WORK(ICNT).HYOJI_RENBAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 43, MHOGOSHA_WORK(ICNT).KON_JUSHO_JODAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 44, MHOGOSHA_WORK(ICNT).KON_JUSHO_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 45, MHOGOSHA_WORK(ICNT).GAKKO_KUBUN_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 46, MHOGOSHA_WORK(ICNT).GAKKO_KUBUN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 47, MHOGOSHA_WORK(ICNT).GAKKO_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 48, MHOGOSHA_WORK(ICNT).GAKKO_MEI_HYOJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 49, MHOGOSHA_WORK(ICNT).JIDO_KOKUSEKI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 50, MHOGOSHA_WORK(ICNT).SETAINUSHI_SHIMEIKANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 51, MHOGOSHA_WORK(ICNT).ZOKUGARA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 52, MHOGOSHA_WORK(ICNT).HOGOSHA_KOKUSEKI);
--  2024/07/03 ZCZL.caijiacun Update end
--  2024/04/28 ZCZL.WUCAO Update 0.2.000.002:512_GKB_00033対応
--                    IF VPAGEFD <> '' THEN
                    IF VPAGEFD IS NOT NULL THEN
                        -- 改頁の指定がある場合
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
                        MHOGOSHA_WORK(ICNT).RENBAN := IGYORENBAN;    -- 連番
                        MHOGOSHA_WORK(ICNT).KAIPEJI := VPAGENAME;    -- 改頁名
                        MHOGOSHA_WORK(ICNT).KAIPEJI_CD := VPAGEWORK; -- 改頁コード
                    ELSE
                        -- 再セットする項目
                        MHOGOSHA_WORK(ICNT).RENBAN := ICNT + 1;     -- 連番
                        MHOGOSHA_WORK(ICNT).KAIPEJI := '';   -- 改頁名
                        MHOGOSHA_WORK(ICNT).KAIPEJI_CD := ''; -- 改頁コード
                    END IF;
                ELSE
                    -- 全件読み込み終了
                    EXIT;
                END IF;
                ICNT := ICNT + 1;
            END LOOP;
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
    -- 保護者ワーク（GKBWHOGOSHACHK）CSVの作成
    --------------------------------------------------------------------------------
--  2024/07/03 ZCZL.caijiacun Update 0.3.000.000:新WizLIFE２次開発対応
--    FUNCTION FUNC_SET_JIDO_WK_CSVFILE RETURN NUMBER IS
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE(i_sCHOHYOID IN NVARCHAR2) RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        IRET                PLS_INTEGER;                -- 戻り値
        BRET                BOOLEAN;                    -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        VDATA               NVARCHAR2(3000);            -- データ（１レコード分）
        NFNO                UTL_FILE.FILE_TYPE;         -- ファイルハンドル
        r_CHOHYO_001        GKBWL110R001%ROWTYPE;
--  2024/07/03 ZCZL.caijiacun Add 0.3.000.000:新WizLIFE２次開発対応
        r_CHOHYO_002        GKBWL711R001%ROWTYPE;
-- 2025/05/19 ZCZL.WANGWEIZHE Add 1.0.004.000:GKB_QA13605(保守#2205)二次対応_【学齢簿】保護者警告チェックリストの世帯主氏名が空欄で印字されないを修正する
        vSHIMEI_KANJI       GABTATENAKIHON.SHIMEI_KANJI%TYPE;
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        IMAX := MHOGOSHA_WORK.LAST;             -- ワーク領域の件数の最大値
        IMIN := MHOGOSHA_WORK.FIRST;            -- ワーク領域の件数の最小値
        -- 取得した件数分繰り返す
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応 
IF    IMIN IS NOT NULL AND   IMAX IS NOT NULL THEN  
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応 
        FOR ICNT IN IMIN..IMAX LOOP
--  2024/07/03 ZCZL.caijiacun Update start 0.3.000.000:新WizLIFE２次開発対応
          CASE i_sCHOHYOID
           WHEN 'GKB110R001' THEN
            nCOUNT := nCOUNT + 1;
            g_nCOUNT := g_nCOUNT + 1;
            r_CHOHYO_001                       := NULL;  
            r_CHOHYO_001.NO                    := nCOUNT;                                       --ソート順
            r_CHOHYO_001.GAKKOKU_CD            := MHOGOSHA_WORK(ICNT).KAIPEJI_CD;               --学校区コード
--            r_CHOHYO_001.GAKKO_MEI_HYOJI       := MHOGOSHA_WORK(ICNT).KAIPEJI;                   --学校名表示用
--            r_CHOHYO_001.MEI_HYOJI       　　　　　:= MHOGOSHA_WORK(ICNT).GAKKO_MEI_HYOJI;          　--学校名
            r_CHOHYO_001.GAKKO_MEI_HYOJI       := MHOGOSHA_WORK(ICNT).GAKKO_MEI_HYOJI;          --学校名
            r_CHOHYO_001.SAKUSEIBI             := MHOGOSHA_WORK(ICNT).SAKUSEIBI;                --作成日
            r_CHOHYO_001.NUM                   := MHOGOSHA_WORK(ICNT).RENBAN;                   --No
--            r_CHOHYO_001.SHIMEI_KANA           := MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA;         --氏名カナ
--            r_CHOHYO_001.SHIMEI                := MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI;        --氏名
            r_CHOHYO_001.JIDO_SHIMEI_KANA      := MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA;         --児童生徒氏名カナ
            r_CHOHYO_001.JIDO_SHIMEI_KANJI     := MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI;        --児童生徒氏名漢字
            r_CHOHYO_001.SEINENGAPI            := MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI;         --生年月日
            r_CHOHYO_001.SEIBETSU              := MHOGOSHA_WORK(ICNT).HYOJI_SEIBETSU;           --性別
            r_CHOHYO_001.HOGOSHA_KANKEI        := MHOGOSHA_WORK(ICNT).ZOKUGARAMEI1;             --保護者との関係
--            r_CHOHYO_001.HOGOSHA_SHIMEI_JODAN  := MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_JODAN;     --保護者氏名上段
--            r_CHOHYO_001.HOGOSHA_SHIMEI_GEDAN  := MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;     --保護者氏名下段
            r_CHOHYO_001.HOGOSHA_SHIMEI_KANA   := MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANA;      --保護者氏名カナ
            r_CHOHYO_001.HOGOSHA_SHIMEI_KANJI  := MHOGOSHA_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;     --保護者氏名漢字
            r_CHOHYO_001.JIDO_ZOKUGARAMEI      := MHOGOSHA_WORK(ICNT).ZOKUGARAMEI2;             --児童との関係
            r_CHOHYO_001.SOSHITSU_JIYU         := MHOGOSHA_WORK(ICNT).SOSHITSU_JIYU;            --喪失事由
            r_CHOHYO_001.IDO_BI                := MHOGOSHA_WORK(ICNT).IDO_NENGAPI;              --異動年月日
            r_CHOHYO_001.GYOSEIKU_MEI          := MHOGOSHA_WORK(ICNT).GYOSEIKUMEI;              --行政区名
            r_CHOHYO_001.JIDO_SETAI_NO         := MHOGOSHA_WORK(ICNT).JIDO_SETAI_NO;            --児童世帯番号
            r_CHOHYO_001.HOGOSHA_SETAI_NO      := MHOGOSHA_WORK(ICNT).HOGOSHA_SETAI_NO;         --保護者世帯番号
            r_CHOHYO_001.BIKO                  := MHOGOSHA_WORK(ICNT).SANTEIDANTAIMEI;          --備考
            r_CHOHYO_001.JINKAKU_KBN           := MHOGOSHA_WORK(ICNT).JINKAKU_KBN;              --人格区分
            r_CHOHYO_001.GYOSEIKU              := NULL;                                         --行政区
            r_CHOHYO_001.JIDO_KOJIN_NO         := MHOGOSHA_WORK(ICNT).JIDO_KOJIN_NO;            --児童生徒宛名番号
            r_CHOHYO_001.JIDO_JUSHO            := MHOGOSHA_WORK(ICNT).JIDO_JUSHO;               --児童生徒住所
            r_CHOHYO_001.HOGOSHA_KOJIN_NO      := MHOGOSHA_WORK(ICNT).HOGOSHA_KOJIN_NO;         --保護者宛名番号
            r_CHOHYO_001.HOGOSHA_JUSHO         := MHOGOSHA_WORK(ICNT).HOGOSHA_JUSHO;            --保護者住所
            r_CHOHYO_001.GAKUNEN               := MHOGOSHA_WORK(ICNT).GAKUNENMEI;               --学年
            r_CHOHYO_001.TODOKEDEBI            := MHOGOSHA_WORK(ICNT).TODOKEDEBI;               --届出日
            r_CHOHYO_001.IDO_JIYU              := MHOGOSHA_WORK(ICNT).IDO_JIYU;                 --異動事由
            
            r_CHOHYO_001.JIDO_KOKUSEKI         := MHOGOSHA_WORK(ICNT).JIDO_KOKUSEKI;            --児童生徒国籍
-- 2025/05/19 ZCZL.WANGWEIZHE Update 1.0.004.000:GKB_QA13605(保守#2205)二次対応_【学齢簿】保護者警告チェックリストの世帯主氏名が空欄で印字されないを修正する
--           r_CHOHYO_001.SETAINUSHI_SHIMEIKANJI := MHOGOSHA_WORK(ICNT).SETAINUSHI_SHIMEIKANJI;   --世帯主氏名漢字
            BEGIN
              SELECT SHIMEI_KANJI INTO vSHIMEI_KANJI
                FROM GABTATENAKIHON
               WHERE SETAI_NO    = MHOGOSHA_WORK(ICNT).JIDO_SETAI_NO
                 AND GENZON_KBN  = 0
                 AND ZOKUGARACD1 = 1
                 AND ZOKUGARACD2 = 0;
            EXCEPTION
              WHEN OTHERS THEN
                vSHIMEI_KANJI  := ' ';
            END;
            r_CHOHYO_001.SETAINUSHI_SHIMEIKANJI := vSHIMEI_KANJI;
-- 2025/05/19 ZCZL.WANGWEIZHE Update End
            r_CHOHYO_001.ZOKUGARA              := MHOGOSHA_WORK(ICNT).ZOKUGARA;                 --続柄
            r_CHOHYO_001.HOGOSHA_KOKUSEKI      := MHOGOSHA_WORK(ICNT).HOGOSHA_KOKUSEKI;         --保護者国籍
--            r_CHOHYO_001.BREAK_NO              := MHOGOSHA_WORK(ICNT).KAIPEJI;                  --改ページキー
            r_CHOHYO_001.BREAK_NO              := FLOOR(nCOUNT / 11) + 1;                       --改ページキー
            r_CHOHYO_001.WSNUM                 := g_sWSNUM;                                     --端末番号
            r_CHOHYO_001.BATCHKBN              := c_BATCH;                                      --即時バッチ区分
            r_CHOHYO_001.JOBNUM                := g_nJOBNUM;                                    --ジョブNO
            INSERT INTO GKBWL110R001 VALUES r_CHOHYO_001;
            
           WHEN 'GKB711R001' THEN
            r_CHOHYO_002                         := NULL;  
            nCOUNT := nCOUNT + 1;
            r_CHOHYO_002.NO                      := nCOUNT;
            r_CHOHYO_002.SAKUSEIBI               := MHOGOSHA_WORK(ICNT).SAKUSEIBI;
            r_CHOHYO_002.JIDO_SHIMEI_KANA        := MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANA;
            r_CHOHYO_002.JIDO_SHIMEI_KANJI       := MHOGOSHA_WORK(ICNT).JIDO_SHIMEI_KANJI;
            r_CHOHYO_002.SEINENGAPI              := MHOGOSHA_WORK(ICNT).HYOJI_SEINENGAPI;
            r_CHOHYO_002.SEIBETSU                := MHOGOSHA_WORK(ICNT).HYOJI_SEIBETSU;
            r_CHOHYO_002.JIDO_KOKUSEKI           := MHOGOSHA_WORK(ICNT).JIDO_KOKUSEKI;
            r_CHOHYO_002.GAKKO_MEI               := MHOGOSHA_WORK(ICNT).GAKKO_MEI_HYOJI;
            r_CHOHYO_002.GAKUNEN                 := MHOGOSHA_WORK(ICNT).GAKUNENMEI;
            r_CHOHYO_002.SETAI_NO                := MHOGOSHA_WORK(ICNT).HOGOSHA_SETAI_NO;
-- 2025/05/19 ZCZL.WANGWEIZHE Update 1.0.004.000:GKB_QA13605(保守#2205)二次対応_【学齢簿】保護者警告チェックリストの世帯主氏名が空欄で印字されないを修正する
            --r_CHOHYO_002.SETAINUSHI_SHIMEIKANJI  := MHOGOSHA_WORK(ICNT).SETAINUSHI_SHIMEIKANJI;
            BEGIN
              SELECT SHIMEI_KANJI INTO vSHIMEI_KANJI
                FROM GABTATENAKIHON
               WHERE SETAI_NO    = MHOGOSHA_WORK(ICNT).JIDO_SETAI_NO
                 AND GENZON_KBN  = 0
                 AND ZOKUGARACD1 = 1
                 AND ZOKUGARACD2 = 0;
            EXCEPTION
              WHEN OTHERS THEN
                vSHIMEI_KANJI  := ' ';
            END;
            r_CHOHYO_002.SETAINUSHI_SHIMEIKANJI  := vSHIMEI_KANJI;
-- 2025/05/19 ZCZL.WANGWEIZHE Update End
            r_CHOHYO_002.BREAK_NO                := FLOOR(nCOUNT / 15) + 1;
            r_CHOHYO_002.WSNUM                   := g_sWSNUM;
            r_CHOHYO_002.BATCHKBN                := c_BATCH;
            r_CHOHYO_002.JOBNUM                  := g_nJOBNUM;
            INSERT INTO GKBWL711R001 VALUES r_CHOHYO_002;
            
          END CASE;
--  2024/07/03 ZCZL.caijiacun Update end
        END LOOP;
        -- 終了
        RETURN FRET;
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応 
ELSE
  FRET  :=-9;
END IF;
RETURN FRET;  
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応
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
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
--  2024/07/02 ZCZL.caijiacun Delete Start 0.3.000.000:新WizLIFE２次開発対応
--       DELETE FROM GKBWL110R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
--       COMMIT;
--  2024/07/02 ZCZL.caijiacun Delete end
        -- 取得した条件をそれぞれの変数へセット
        VGAKUNEN        := g_VJOKEN01;        -- 学年
        VSYURYOGAKUNEN  := g_VJOKEN02;        -- 終了学年
        --変数.住所チェックフラグ := TO_NUMBER（変数.バッチ処理条件3）
        NJIYUSHIYOCHKFLG := TO_NUMBER(g_VJOKEN03);       --住所チェックフラグ
--  2024/07/05 ZCZL.caijiacun Update start 0.3.000.000:新WizLIFE２次開発対応
       IF g_rJSTP.CHOHYOID = 'GKB110R001' THEN
        --抽出対象チェツク
        IF g_nCHUTAISYOU <> 0 AND g_nCHUTAISYOU <> 1 AND g_nCHUTAISYOU <> 2 THEN
          RETURN FALSE;
        END IF;
        --抽出範囲区分チェツク
        IF g_nHaniKubun <> 0 AND g_nHaniKubun <> 1 AND g_nHaniKubun <> 2 THEN
          RETURN FALSE;
        END IF;
        --初期処理を呼び出す。
        B_RTN := FUNC_INIT;
        IF B_RTN = c_BERROR THEN
          RAISE ERR;
        END IF;
        -- 保護者ワーク（GKBWHOGOSHACHK）のデータ全件削除
        I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
        IF B_RTN = c_BERROR THEN
        -- エラーで帰ってきた場合
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
            RAISE ERR;
        END IF;

        -- 保護者ワーク中間データ作成
        I_RTN := FUNC_GET_JIDO_WK;
        IF I_RTN <> c_ISUCCESS THEN
        -- エラーで帰ってきた場合
            IF I_RTN = c_INOTFOUND THEN
--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
--                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
                GOTO END_EXIT;
            END IF;
            RAISE ERR;
        END IF;
        -- 保護者ワークテーブル作成
        I_RTN := FUNC_INSERT_JIDO_WK;
        IF I_RTN = c_INOT_SUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE ERR;
        END IF;
        -- 保護者ワークデータ作成（ＣＳＶ用）
        I_RTN := FUNC_GET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE ERR;
        END IF;
      END IF;
--  2024/07/05 ZCZL.caijiacun Update end
--  2024/07/02 ZCZL.caijiacun Delete Start 0.3.000.000:新WizLIFE２次開発対応
--        -- 保護者ワークＣＳＶファイル作成
--        I_RTN := FUNC_SET_JIDO_WK_CSVFILE;
--        IF I_RTN <> c_ISUCCESS THEN
--        -- エラーで帰ってきた場合
--            RAISE ERR;
--        END IF;
--  2024/07/02 ZCZL.caijiacun Delete end
--  2024/07/02 ZCZL.caijiacun Update start 0.3.000.000:新WizLIFE２次開発対応
        --帳票出力CSVの作成
--        bRTN :=FUNC_B11CSV('GKBWL110R001');
        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB110R001' THEN
            --保護者情報チェック一覧表をクリアする。
            DELETE FROM GKBWL110R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
            -- 保護者情報チェック一覧表ＣＳＶファイル作成
            I_RTN := FUNC_SET_JIDO_WK_CSVFILE(g_rJSTP.CHOHYOID);
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応 
                IF I_RTN = c_INOTFOUND THEN
                 GOTO END_EXIT;
                 END IF;
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応
                RAISE ERR;
            END IF;
            --CSV出力処理を呼び出す。
            bRTN :=FUNC_B11CSV('GKBWL110R001');
          WHEN 'GKB711R001' THEN
            --保護者警告チェックリストワークをクリアする。
            DELETE FROM GKBWL711R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
            -- 保護者ワークＣＳＶファイル作成
            I_RTN := FUNC_SET_JIDO_WK_CSVFILE(g_rJSTP.CHOHYOID);
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
--  2025/05/22 CTC.LIUJUNHAO ADD START 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応 
                IF I_RTN = c_INOTFOUND THEN
                GOTO END_EXIT;
                END IF;
--  2025/05/22 CTC.LIUJUNHAO ADD END 1.0.006.000:GKB_QA15230_保護者情報チェック一覧表処理時に入力不要な条件は警告エラー対応 
                RAISE ERR;
            END IF;
            --CSV出力処理を呼び出す。
            bRTN :=FUNC_B11CSV('GKBWL711R001');
          ELSE
            NULL;
        END CASE;
--  2024/07/02 ZCZL.caijiacun Update end
--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
       <<END_EXIT>>
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
END GKBPB00180;
/
