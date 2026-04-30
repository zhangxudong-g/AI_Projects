CREATE OR REPLACE PACKAGE BODY GKBPB00320
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 成人式
--  機能概要      : 成人式対象者名簿を作成する
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.GUOXU 2024/01/26
--------------------------------------------------------
--  変更履歴
--  2024/03/19 ZCZL.WUCAO Update 0.2.000.001:512_GKB_00002対応
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00027対応
--  2024/06/19 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00429対応横展開
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

    --パラメータ変数
    g_vJOKEN1         NVARCHAR2(1000);
    g_vJOKEN2         NVARCHAR2(1000);
    g_vJOKEN3         NVARCHAR2(1000);
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
    g_vJOKEN4         NVARCHAR2(1000);          --開始生年月日
    g_vJOKEN5         NVARCHAR2(1000);          --終了生年月日
    TYPE MR_CRSEIJINSYA IS RECORD (NENDO                  GKBTSEIJINSHA.NENDO%TYPE,
                                   SEIRI_NO               GKBTSEIJINSHA.SEIRI_NO%TYPE,
                                   KOJIN_CD               GKBTSEIJINSHA.KOJIN_CD%TYPE,
                                   SHIMEI_KANA            GKBTSEIJINSHA.SHIMEI_KANA%TYPE,
                                   SHIMEI_KANJI           GKBTSEIJINSHA.SHIMEI_KANJI%TYPE,
                                   SEINENGAPI             GKBTSEIJINSHA.SEINENGAPI%TYPE,
                                   SEIBETU                GKBTSEIJINSHA.SEIBETU%TYPE,
                                   TYUGAKO_KU             GKBTSEIJINSHA.TYUGAKO_KU%TYPE,
                                   GYOSEI_KU              GKBTSEIJINSHA.GYOSEI_KU%TYPE,
                                   YUBIN_NO               GKBTSEIJINSHA.YUBIN_NO%TYPE,
                                   CHOMEI                 GKBTSEIJINSHA.CHOMEI%TYPE,
                                   BANCHI                 GKBTSEIJINSHA.BANCHI%TYPE,
                                   KATAGAKI               GKBTSEIJINSHA.KATAGAKI%TYPE,
                                   TEL_NO                 GKBTSEIJINSHA.TEL_NO%TYPE,
                                   SANTEIDANTAI_CD        GKBTSEIJINSHA.SANTEIDANTAI_CD%TYPE,
                                   SYUKETSU_KBN           GKBTSEIJINSHA.SYUKETSU_KBN%TYPE,
                                   SHOGAKO_KU             GKBTSEIJINSHA.SHOGAKO_KU%TYPE,
                                   SHOGAKO_KU_CD          GKBTSEIJINSHA.SHOGAKO_KU_CD%TYPE,
                                   TYUGAKO_KU_CD          GKBTSEIJINSHA.TYUGAKO_KU_CD%TYPE,
                                   GYOSEI_KU_CD           GKBTSEIJINSHA.GYOSEI_KU_CD%TYPE);
        CRSEIJINSYA        MR_CRSEIJINSYA;
-- 2024/06/12 ZCZL.wangyunhan Add end 

    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--     CURSOR CSEIJINSYA(p_NENDO IN NUMBER,
--                         p_IKBN  IN PLS_INTEGER,
--                         p_ISANTEIDANTAI_CD IN PLS_INTEGER
--                         ) IS
--         SELECT NENDO,
--             SEIRI_NO,
--             KOJIN_CD,
--             SHIMEI_KANA,
--             SHIMEI_KANJI,
--             SEINENGAPI,
--             SEIBETU,
--             TYUGAKO_KU,
--             GYOSEI_KU,
--             YUBIN_NO,
--             CHOMEI,
--             BANCHI,
--             KATAGAKI,
--             TEL_NO
--             ,SANTEIDANTAI_CD
--             ,SYUKETSU_KBN
--             ,SHOGAKO_KU
--             ,SHOGAKO_KU_CD
--             ,TYUGAKO_KU_CD
--             ,GYOSEI_KU_CD
--         FROM GKBTSEIJINSHA
--         WHERE NENDO = p_NENDO
--         AND ((p_ISANTEIDANTAI_CD <> 0 AND SANTEIDANTAI_CD = p_ISANTEIDANTAI_CD) OR
--                 p_ISANTEIDANTAI_CD = 0)
--         AND SYUKETSU_KBN = DECODE(p_IKBN,1,1,DECODE(p_IKBN,2,0,SYUKETSU_KBN));
-- 2024/06/12 ZCZL.wangyunhan Delete end 
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- ERROR関連 --
    -- デバック
    N_SQL_CODE     NUMBER;             -- SQLエラーコード
    V_SQL_MSG      NVARCHAR2(255);     -- SQLエラーメッセージ
    -- 処理結果
    c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    c_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし


    -- 正常メッセージの値
    c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '成人式処理が正常終了しました。';
    -- エラーメッセージの値
    c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '成人式処理が異常終了しました。';
    -- 成人者マスタ
    c_VTABLE       CONSTANT  NVARCHAR2(128) := 'GKBWSEIJINSHA';
    --  2024/03/19 ZCZL.WUCAO Add 0.2.000.001:512_GKB_00002対応
    -- １頁の最大行数
    c_IMAXROWS     CONSTANT  PLS_INTEGER    := 15;
    
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    VKBN                      NVARCHAR2(15);
    IKBN                      PLS_INTEGER;
    ISAKUSEIBI                PLS_INTEGER;
    RSEIJINSYA_ATENA          GABTATENAKIHON%ROWTYPE;
    RSEIJINSYA_SOFU           GABTSOFUSAKI%ROWTYPE;
    RNUSHI_ATENA              GABTATENAKIHON%ROWTYPE;  -- 世帯主用
    RNUSHI_SOFU               GABTSOFUSAKI%ROWTYPE;    -- 世帯主用
    VSHIMEI_KANA              NVARCHAR2(100);
    VSHIMEI_KANJI             NVARCHAR2(100);
    VZOKUGARAMEI              NVARCHAR2(30);
    VSEINENGAPI               NVARCHAR2(11);
    VSEIBETSU                 NVARCHAR2(2);
    VGYOSEIKU_MEI             NVARCHAR2(20);
    VHAN_MEI                  NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00429対応横展開
--    VSANTEIDANTAI_MEI         NVARCHAR2(20);
    VSANTEIDANTAI_MEI         GKBWSEIJINSHA.SANTEIDANTAIMEI%TYPE;
    VSAKUSEIBI                NVARCHAR2(30);
    VJUSHO_JODAN              NVARCHAR2(100);
    VJUSHO_GEDAN              NVARCHAR2(100);
    VSEIJINKIJITU             NVARCHAR2(11);
    VHASOBI                   NVARCHAR2(11);
    VUSERMEI                  NVARCHAR2(40);
    VKENUSERMEI               NVARCHAR2(40);
    VSHUCHOMEI                NVARCHAR2(40);
--  2024/06/19 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--    NNUSHIKOJINNO             NUMBER(12);
    NNUSHIKOJINNO             NUMBER(15);
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN                      BOOLEAN;
    I_RTN                     PLS_INTEGER;
    -- 処理条件（画面からの引数）
    VNENDO                    NVARCHAR2(15);      -- 対象年度
    VSANTEIDANTAI_CD          NVARCHAR2(2);       -- 算定団体コード
    IKISAI_JUNI               PLS_INTEGER;
    IJUMIN_NAKUNARU_JIYU      PLS_INTEGER;        --住民でなくなる事由
    VJUMIN_NAKUNARU_JIYU_MEI  NVARCHAR2(20);      --住民でなくなる事由
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
    VSEINENGAPI_KAISHI        NUMBER(8);          --開始生年月日
    VSEINENGAPI_SHURYO        NUMBER(8);          --終了生年月日
-- 2024/06/12 ZCZL.wangyunhan Add end 
    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWSEIJINSHA%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK MTJIDO_TYPE;

    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    IWAREKIHIZUKE               PLS_INTEGER;
    VEDIT_GYYMMDD1              NVARCHAR2(20);
    VEDIT_GYYMMDD2              NVARCHAR2(20);
    VEDIT_GYYMMDD3              NVARCHAR2(20);
    VKJ_GENGO                   NVARCHAR2(20);
    VKG_GENGO                   NVARCHAR2(20);
    IWAREKI_YY                  PLS_INTEGER;
    ISEIREKI_YYYY               PLS_INTEGER;
    IWAREKI_GYYMM               PLS_INTEGER;
    IMM                         PLS_INTEGER;
    IDD                         PLS_INTEGER;
    IOWAREKIHIZUKE              PLS_INTEGER;
    ISEIREKIHIZUKE              PLS_INTEGER;
    -- 共通情報取得用変数(KKAPK0030.FKYOTU)
    o_IUSER_ID                  PLS_INTEGER;       -- 市町村コード
    o_IGAPPEI_BI                PLS_INTEGER;       -- 合併日付
    o_IJICHI_CD                 PLS_INTEGER;       -- 自治コード
    o_IUSER_KBN                 PLS_INTEGER;       -- 市町村区分
    o_VKENMEI                   NVARCHAR2(30);     -- 県名
    o_VGUNSHIMEI                NVARCHAR2(30);     -- 郡市名
    o_VUSERMEI                  NVARCHAR2(40);     -- 市町村名
    o_VSHUCHOMEI                NVARCHAR2(40);     -- 首長名
    o_VSHUCHONINSHOBUN          NVARCHAR2(100);    -- 首長認証文
    o_VYUBIN_NO                 NVARCHAR2(10);     -- 郵便番号
    o_VSHOZAICHI                NVARCHAR2(200);    -- 所在地
    o_VTEL_NO                   NVARCHAR2(20);     -- 代表電話番号
    VSQLERRM                    NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
    VPAGENM                     NVARCHAR2(500);    -- 改頁項目名
    VPAGEFD                     NVARCHAR2(500);    -- 改頁項目値
    ----------------------------------------------------------------------------------------------------
    --  総合行政システム　教育システム　成人式名簿処理条件チェック
    ----------------------------------------------------------------------------------------------------
    VMSG NVARCHAR2(4000);
-- 2024/06/12 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
    VMSG2 NVARCHAR2(4000);
    IRTN PLS_INTEGER ;

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
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
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
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
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
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        cmbSakuseiKbn DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        g_vJOKEN1 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtNendo');                --対象年度
        cmbSakuseiKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'cmbSakuseiKbn');  --作成区分
        g_vJOKEN2 := cmbSakuseiKbn(1);
        g_vJOKEN3 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSanteiDantai');         --算定団体コード
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        g_vJOKEN4 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtBirStartYmd');          --生年月日(開始)
        g_vJOKEN5 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtBirEndYmd');            --生年月日(終了)
-- 2024/06/12 ZCZL.wangyunhan Add end 
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
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
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
    ----------------------------------------------------------------------------------------------------
    --作成区分チェック
    ----------------------------------------------------------------------------------------------------

    FUNCTION FUNCKUBUNCHK( i_VKUBUN IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    KUBUN PLS_INTEGER ;
    BEGIN
    IRET := 0 ;
    BEGIN
        IF i_VKUBUN IS NULL THEN
        IRET := 1;
        ELSE
        KUBUN  := TO_NUMBER(i_VKUBUN);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
        IRET := 1;
    END;

    IF IRET = 0 THEN
        IF KUBUN < 1 OR KUBUN > 3 THEN
        IRET := 1;
        END IF;
    END IF;

    RETURN(IRET) ;
    END ;
    ----------------------------------------------------------------------------------------------------
    --年度チェック
    ----------------------------------------------------------------------------------------------------

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
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        ICHK1                        NUMBER := 0;
        ICHK2                        NUMBER := 0; 
-- 2024/06/12 ZCZL.wangyunhan Add end 
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
        IRTN := FUNCNENDOCHK( g_vJOKEN1 ) ;
        IF IRTN <> 0 THEN
            VMSG  := g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
        END IF ;

        --条件２のチェック
        IRTN := FUNCKUBUNCHK( g_vJOKEN2 ) ;
        IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,作成区分が正しくありません。,;';
        END IF ;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
       --生年月日(開始)チェック
       IF KKAPK0010.FISNUMERIC(g_vJOKEN4) = FALSE THEN 
         VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（開始）が正しくありません。,;';
         ICHK1 := 1;
       ELSE 
           --日付チェック
           IF g_vJOKEN4 IS NOT NULL THEN
               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJOKEN4));
               IF NOT bRTN THEN
                   VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（開始）が正しくありません。,;';
                   ICHK1 := 1;
               END IF;
           END IF;
       END IF;
       --生年月日（終了）チェック
       IF KKAPK0010.FISNUMERIC(g_vJOKEN5) = FALSE THEN 
         VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（終了）が正しくありません。,;';
         ICHK2 := 1;
       ELSE 
           --日付チェック
           IF g_vJOKEN5 IS NOT NULL THEN
               bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJOKEN5));
               IF NOT bRTN THEN
                   VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（終了）が正しくありません。,;';
                   ICHK2 := 1;
               END IF;
           END IF;
       END IF;
       -- 変数.生年月日（開始） > 変数.生年月日（終了）の場合
        IF ICHK1 = 0 AND ICHK2 = 0 THEN
          IF g_vJOKEN4 > g_vJOKEN5 THEN 
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日（開始）、生年月日（終了）の関係が正しくありません。,;';
          END IF;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end 
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
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
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
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
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
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
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

    --------------------------------------------------------------------------------------------------
    -- 処理条件の設定
    --------------------------------------------------------------------------------------------------
    PROCEDURE PROCHAISET IS
    IWAREKI  PLS_INTEGER;
    ISEIREKI PLS_INTEGER;
    BEGIN
    -- 市町村名等の設定
    IRTN := KKAPK0030.FKYOTU(ISAKUSEIBI, o_IUSER_ID, o_IJICHI_CD, o_IGAPPEI_BI,
                             o_IUSER_KBN, o_VGUNSHIMEI, o_VUSERMEI, o_VSHUCHOMEI,
                             o_VKENMEI,o_VSHUCHONINSHOBUN, o_VYUBIN_NO, o_VSHOZAICHI, o_VTEL_NO);
    VUSERMEI    := o_VUSERMEI;
    VKENUSERMEI := o_VKENMEI || o_VGUNSHIMEI || o_VUSERMEI;
    VSHUCHOMEI  := o_VSHUCHOMEI;
    -- 成人式期日の設定
    IWAREKI  := TO_NUMBER(VSEIJINKIJITU);
    ISEIREKI := 0;
    BRTN := KKAPK0020.FDAYEDIT(IWAREKI,
                                ISEIREKI,
                                VEDIT_GYYMMDD3,
                                VEDIT_GYYMMDD2,
                                VSEIJINKIJITU,
                                VKJ_GENGO,
                                VKG_GENGO,
                                IWAREKI_YY,
                                ISEIREKI_YYYY,
                                IWAREKI_GYYMM,
                                IMM,
                                IDD,
                                IOWAREKIHIZUKE,
                                ISEIREKIHIZUKE);
    -- 発送日の設定
    IWAREKI  := TO_NUMBER(VHASOBI);
    ISEIREKI := 0;
    BRTN := KKAPK0020.FDAYEDIT(IWAREKI,
                                ISEIREKI,
                                VEDIT_GYYMMDD3,
                                VEDIT_GYYMMDD2,
                                VHASOBI,
                                VKJ_GENGO,
                                VKG_GENGO,
                                IWAREKI_YY,
                                ISEIREKI_YYYY,
                                IWAREKI_GYYMM,
                                IMM,
                                IDD,
                                IOWAREKIHIZUKE,
                                ISEIREKIHIZUKE);
    END PROCHAISET;

    --------------------------------------------------------------------------------
    -- 成人者名簿ワーク中間（GKBWSEIJINSHA）レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
    IFRET                PLS_INTEGER;                -- 戻り値
    INENDO               PLS_INTEGER;                -- 年度
    ICNT                 BINARY_INTEGER;             -- 戻り値
    IRTN                 PLS_INTEGER;
    BRTN                 BOOLEAN;
    IATENA_FLG           PLS_INTEGER;                -- 宛名フラグ（[0]:宛名情報あり、[1]:宛名情報なし）
    ISANTEIDANTAI_CD     PLS_INTEGER;                -- 算定団体コード
    IKOJIN_NO            NUMBER;
    o_RATENA_REC   GABTATENAKIHON%ROWTYPE;
    o_RSOFU_REC    GABTSOFUSAKI%ROWTYPE;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
    SSQL                NVARCHAR2(2000) := '';
    TYPE CURTYPE        IS REF CURSOR;
    CDATA               CURTYPE;
    
-- 2024/06/12 ZCZL.wangyunhan Add end 
    BEGIN
      IFRET := c_INOTFOUND;             -- 該当なし
      INENDO := TO_NUMBER(VNENDO);      -- 年度
      IKBN   := TO_NUMBER(VKBN);        -- 作成区分
      IF VSANTEIDANTAI_CD IS NOT NULL THEN
          ISANTEIDANTAI_CD := TO_NUMBER(VSANTEIDANTAI_CD);  -- 算定団体コード
      ELSE
          ISANTEIDANTAI_CD := 0;
      END IF;

      -- 対象年度を西暦に変換
      INENDO := KKAPK0020.FNENDO(INENDO,1);

      VNENDO := KKAPK0020.FNENDOEDIT(1,
                                      INENDO,
                                      3);
      -- ワーク領域の初期化
      MJIDO_WORK.DELETE;
      ICNT := 0;

      -- 処理条件の年度に該当する成人者を検索
      BEGIN
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
         SSQL := SSQL ||' SELECT NENDO,                ';
         SSQL := SSQL ||'             SEIRI_NO,        ';
         SSQL := SSQL ||'             KOJIN_CD,        ';
         SSQL := SSQL ||'             SHIMEI_KANA,     ';
         SSQL := SSQL ||'             SHIMEI_KANJI,    ';
         SSQL := SSQL ||'             SEINENGAPI,      ';
         SSQL := SSQL ||'             SEIBETU,         ';
         SSQL := SSQL ||'             TYUGAKO_KU,      ';
         SSQL := SSQL ||'             GYOSEI_KU,       ';
         SSQL := SSQL ||'             YUBIN_NO,        ';
         SSQL := SSQL ||'             CHOMEI,          ';
         SSQL := SSQL ||'             BANCHI,          ';
         SSQL := SSQL ||'             KATAGAKI,        ';
         SSQL := SSQL ||'             TEL_NO           ';
         SSQL := SSQL ||'             ,SANTEIDANTAI_CD ';
         SSQL := SSQL ||'             ,SYUKETSU_KBN    ';
         SSQL := SSQL ||'             ,SHOGAKO_KU      ';
         SSQL := SSQL ||'             ,SHOGAKO_KU_CD   ';
         SSQL := SSQL ||'             ,TYUGAKO_KU_CD   ';
         SSQL := SSQL ||'             ,GYOSEI_KU_CD    ';
         SSQL := SSQL ||'         FROM GKBTSEIJINSHA   ';
         SSQL := SSQL ||'         WHERE NENDO = '|| INENDO ||' ';
         SSQL := SSQL ||'         AND (('||ISANTEIDANTAI_CD||' <> 0 AND SANTEIDANTAI_CD = '||ISANTEIDANTAI_CD||') OR  ';
         SSQL := SSQL ||'                '|| ISANTEIDANTAI_CD||' = 0)  ';
         SSQL := SSQL ||'         AND SYUKETSU_KBN = DECODE('||IKBN||',1,1,DECODE('||IKBN||',2,0,SYUKETSU_KBN))  ';
         IF NVL(VSEINENGAPI_KAISHI,0) > 0 THEN
            SSQL := SSQL || ' AND SEINENGAPI >= '|| VSEINENGAPI_KAISHI ||''; --sql条件
         END IF;
         IF NVL(VSEINENGAPI_SHURYO,0) > 0 THEN
           IF NVL(VSEINENGAPI_KAISHI,0) = 0 THEN 
              SSQL := SSQL || ' AND SEINENGAPI　> 0  '; --sql条件
           END IF;
              SSQL := SSQL || ' AND SEINENGAPI <= '|| VSEINENGAPI_SHURYO||' '; --sql条件
         END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end 
          -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--           FOR CRSEIJINSYA IN CSEIJINSYA(INENDO,
--                                       IKBN,
--                                       ISANTEIDANTAI_CD
--                                       ) LOOP
          OPEN CDATA FOR SSQL;
          LOOP
          FETCH CDATA INTO CRSEIJINSYA;
          EXIT WHEN CDATA%NOTFOUND;
-- 2024/06/12 ZCZL.wangyunhan Update end 
          IKOJIN_NO := CRSEIJINSYA.KOJIN_CD;

          IATENA_FLG := 1;    -- 宛名情報なし
          IKISAI_JUNI := 0;
          VZOKUGARAMEI := ' ';
          NNUSHIKOJINNO := 0;
          VSHIMEI_KANA  := ' ';
          VSHIMEI_KANJI := ' ';
          RSEIJINSYA_ATENA := NULL;
          RSEIJINSYA_SOFU := NULL;
          RNUSHI_ATENA := NULL;
          RNUSHI_SOFU := NULL;
          IJUMIN_NAKUNARU_JIYU := 0;        --住民でなくなる事由
          VJUMIN_NAKUNARU_JIYU_MEI := NULL; --住民でなくなる事由

          IF CRSEIJINSYA.KOJIN_CD > 0 THEN
              -- 成人者の個人番号より宛名情報取得
              IRTN := GAAPK0030.FGETATENA(CRSEIJINSYA.KOJIN_CD,
                                      'GKB',
                                      ISAKUSEIBI,
                                      RSEIJINSYA_ATENA,
                                      RSEIJINSYA_SOFU);
              IF IRTN = 0 THEN
                -- 個人番号(GKBTSEIJINSHA:KOJIN_NO)がゼロでなく、その個人番号で宛名情報が取得できた場合
                IATENA_FLG := 0;    -- 宛名情報あり
              END IF;

              -- 個人番号より住基異動の続柄名・記載順位取得
              BEGIN
              SELECT ZOKUGARA_MEI,
                      KISAI_JUNI
                      , JUMIN_NAKUNARU_JIYU
                  INTO VZOKUGARAMEI,
                      IKISAI_JUNI
                      , IJUMIN_NAKUNARU_JIYU
                  FROM GABTJUKIIDO
              WHERE KOJIN_NO = CRSEIJINSYA.KOJIN_CD;

              IF IJUMIN_NAKUNARU_JIYU > 0 THEN
                  VJUMIN_NAKUNARU_JIYU_MEI := GAAPK0030.FIDOJIYUMEI(IJUMIN_NAKUNARU_JIYU);
              END IF;
              EXCEPTION
              WHEN NO_DATA_FOUND THEN
                  NULL;
              END;

              -- 世帯主取得共通サブルーチンから世帯主名を取得する
              IRTN := JIAPK0030.FGETNUSHI(ISAKUSEIBI,
                                          CRSEIJINSYA.KOJIN_CD,
                                          NNUSHIKOJINNO,
                                          VSHIMEI_KANJI);
              --世帯主が取得できたとき
              IF IRTN = 0 THEN
              -- 世帯主の宛名情報を取得
              IRTN := GAAPK0030.FGETATENA(NNUSHIKOJINNO,
                                          'GKB',
                                          ISAKUSEIBI,
                                          RNUSHI_ATENA,
                                          RNUSHI_SOFU);
              VSHIMEI_KANA := RNUSHI_ATENA.SHIMEI_KANA;
              END IF;
          END IF;

          --成人者マスタの内容をセット
          --中学校区／小学校区
          MJIDO_WORK(ICNT).CHUGAKOKU_CD := CRSEIJINSYA.TYUGAKO_KU_CD;
          MJIDO_WORK(ICNT).CHUGAKOMEI   := CRSEIJINSYA.TYUGAKO_KU;
          MJIDO_WORK(ICNT).SHOGAKOKU_CD := CRSEIJINSYA.SHOGAKO_KU_CD;
          MJIDO_WORK(ICNT).SHOGAKOMEI   := CRSEIJINSYA.SHOGAKO_KU;
          --行政区コード
          MJIDO_WORK(ICNT).GYOSEIKU_CD  := CRSEIJINSYA.GYOSEI_KU_CD;

          --宛名情報がある場合
          IF IATENA_FLG = 0 THEN
              MJIDO_WORK(ICNT).YUHEN_KBN  := RSEIJINSYA_ATENA.YUHEN_KBN;     --郵返区分
              MJIDO_WORK(ICNT).OAZA_CD    := RSEIJINSYA_ATENA.OAZA_CD;       --大字コード
              MJIDO_WORK(ICNT).HONBAN     := RSEIJINSYA_ATENA.HONBAN;        --本番
              MJIDO_WORK(ICNT).EDABAN1    := RSEIJINSYA_ATENA.EDABAN1;       --枝１
              MJIDO_WORK(ICNT).EDABAN2    := RSEIJINSYA_ATENA.EDABAN2;       --枝２
              MJIDO_WORK(ICNT).EDABAN3    := RSEIJINSYA_ATENA.EDABAN3;       --枝３
              MJIDO_WORK(ICNT).GAIKU      := RSEIJINSYA_ATENA.GAIKU;         --街区
              MJIDO_WORK(ICNT).TOU        := RSEIJINSYA_ATENA.TOU;           --棟
              MJIDO_WORK(ICNT).GOU        := RSEIJINSYA_ATENA.GOU;           --号
              MJIDO_WORK(ICNT).GENZON_KBN := RSEIJINSYA_ATENA.GENZON_KBN;    --現存区分
              MJIDO_WORK(ICNT).KISAI_JUNI := IKISAI_JUNI;                    --記載順位
          ELSE
              MJIDO_WORK(ICNT).YUHEN_KBN  := 9;                  --郵返区分
              MJIDO_WORK(ICNT).OAZA_CD    := 999999;             --大字コード
              MJIDO_WORK(ICNT).HONBAN     := '99999';            --本番
              MJIDO_WORK(ICNT).EDABAN1    := '99999';            --枝１
              MJIDO_WORK(ICNT).EDABAN2    := '99999';            --枝２
              MJIDO_WORK(ICNT).EDABAN3    := '99999';            --枝３
              MJIDO_WORK(ICNT).GAIKU      := '99999';            --街区
              MJIDO_WORK(ICNT).TOU        := '99999';            --棟
              MJIDO_WORK(ICNT).GOU        := '99999';            --号
              MJIDO_WORK(ICNT).GENZON_KBN := 9;                  --現存区分
              MJIDO_WORK(ICNT).KISAI_JUNI := 99;                 --記載順位
          END IF;

          MJIDO_WORK(ICNT).SEIRI_NO := CRSEIJINSYA.SEIRI_NO;         --整理番号
          MJIDO_WORK(ICNT).KOJIN_CD := CRSEIJINSYA.KOJIN_CD;         --個人番号

          --行政区名取得
          VGYOSEIKU_MEI := CRSEIJINSYA.GYOSEI_KU;
          VHAN_MEI := GAAPK0030.FHANMEI(RSEIJINSYA_ATENA.SANTEIDANTAI_CD,
                                          RSEIJINSYA_ATENA.HAN_CD);
          IRTN := GAAPK0030.FJICHINAME(CRSEIJINSYA.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);
          IWAREKIHIZUKE := 0;
          BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,
                                      CRSEIJINSYA.SEINENGAPI,
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
          IF CRSEIJINSYA.SEIBETU = 1 THEN
              VSEIBETSU := '男';
          ELSIF CRSEIJINSYA.SEIBETU = 2 THEN
              VSEIBETSU := '女';
          END IF;
          IWAREKIHIZUKE := 0;
          BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,
                                      ISAKUSEIBI,
                                      VEDIT_GYYMMDD1,
                                      VEDIT_GYYMMDD2,
                                      VSAKUSEIBI,
                                      VKJ_GENGO,
                                      VKG_GENGO,
                                      IWAREKI_YY,
                                      ISEIREKI_YYYY,
                                      IWAREKI_GYYMM,
                                      IMM,
                                      IDD,
                                      IOWAREKIHIZUKE,
                                      ISEIREKIHIZUKE);
          -- 成人者マスタの項目を使用する
          VJUSHO_JODAN := SUBSTR (CRSEIJINSYA.CHOMEI||CRSEIJINSYA.BANCHI||' '||CRSEIJINSYA.KATAGAKI,1,100);
          VJUSHO_GEDAN := SUBSTR (CRSEIJINSYA.CHOMEI||CRSEIJINSYA.BANCHI||' '||CRSEIJINSYA.KATAGAKI,101,200);
          MJIDO_WORK(ICNT).NENDO := VNENDO;
          MJIDO_WORK(ICNT).KAIPEJI_CD := ' ';
          MJIDO_WORK(ICNT).KAIPEJI := ' ';
          MJIDO_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;
          MJIDO_WORK(ICNT).HAN_CD := RSEIJINSYA_ATENA.HAN_CD;
          MJIDO_WORK(ICNT).HANMEI := VHAN_MEI;
          MJIDO_WORK(ICNT).SANTEIDANTAI_CD := CRSEIJINSYA.SANTEIDANTAI_CD;
          MJIDO_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;
          MJIDO_WORK(ICNT).SHIMEI_KANA := CRSEIJINSYA.SHIMEI_KANA;
          MJIDO_WORK(ICNT).SEINENGAPI := CRSEIJINSYA.SEINENGAPI;
          IF CRSEIJINSYA.SEINENGAPI = 0 THEN
              MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := ' ';
          ELSE
              MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VSEINENGAPI;
          END IF;
          MJIDO_WORK(ICNT).SEIBETSU := CRSEIJINSYA.SEIBETU;
          MJIDO_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;
          MJIDO_WORK(ICNT).SETAI_NO := RSEIJINSYA_ATENA.SETAI_NO;
          MJIDO_WORK(ICNT).SAKUSEIBI := VSAKUSEIBI;
          MJIDO_WORK(ICNT).RENBAN := 0;
          MJIDO_WORK(ICNT).SHIMEI_KANJI := CRSEIJINSYA.SHIMEI_KANJI;
          MJIDO_WORK(ICNT).ZOKUGARAMEI := VZOKUGARAMEI;

          MJIDO_WORK(ICNT).CHOMEI   := CRSEIJINSYA.CHOMEI;
          MJIDO_WORK(ICNT).BANCHI   := CRSEIJINSYA.BANCHI;
          MJIDO_WORK(ICNT).KATAGAKI := CRSEIJINSYA.KATAGAKI;

          MJIDO_WORK(ICNT).JUSHO_JODAN := VJUSHO_JODAN;
          MJIDO_WORK(ICNT).JUSHO_GEDAN := VJUSHO_GEDAN;
          MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA  := VSHIMEI_KANA;
          MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI := VSHIMEI_KANJI;

          IF CRSEIJINSYA.YUBIN_NO IS NOT NULL THEN
              MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(CRSEIJINSYA.YUBIN_NO,1,3)||'-'||SUBSTR(CRSEIJINSYA.YUBIN_NO,4);
          ELSE
              MJIDO_WORK(ICNT).YUBIN_NO := NULL;
          END IF;

          IF IATENA_FLG = 0 AND
              NVL(CRSEIJINSYA.CHOMEI || CRSEIJINSYA.BANCHI || CRSEIJINSYA.KATAGAKI, ' ') <> NVL(RSEIJINSYA_ATENA.CHOMEI || RSEIJINSYA_ATENA.BANCHI || RSEIJINSYA_ATENA.KATAGAKI, ' ') THEN
              MJIDO_WORK(ICNT).ATENA_CHOMEI   := RSEIJINSYA_ATENA.CHOMEI;
              MJIDO_WORK(ICNT).ATENA_BANCHI   := RSEIJINSYA_ATENA.BANCHI;
              MJIDO_WORK(ICNT).ATENA_KATAGAKI := RSEIJINSYA_ATENA.KATAGAKI;
          ELSE
              MJIDO_WORK(ICNT).ATENA_CHOMEI   := NULL;
              MJIDO_WORK(ICNT).ATENA_BANCHI   := NULL;
              MJIDO_WORK(ICNT).ATENA_KATAGAKI := NULL;
          END IF;
          IF IATENA_FLG = 0 AND
              NVL(CRSEIJINSYA.YUBIN_NO, ' ') <> NVL(RSEIJINSYA_ATENA.YUBIN_NO, ' ') THEN
              IF RSEIJINSYA_ATENA.YUBIN_NO IS NOT NULL THEN
              MJIDO_WORK(ICNT).ATENA_YUBIN_NO := SUBSTR(RSEIJINSYA_ATENA.YUBIN_NO,1,3)||'-'||SUBSTR(RSEIJINSYA_ATENA.YUBIN_NO,4);
              ELSE
              MJIDO_WORK(ICNT).ATENA_YUBIN_NO := NULL;
              END IF;
          ELSE
              MJIDO_WORK(ICNT).ATENA_YUBIN_NO := NULL;
          END IF;

          IF RSEIJINSYA_SOFU.KOJIN_NO IS NOT NULL THEN
              MJIDO_WORK(ICNT).ATENA_YUBIN_NO := SUBSTR(RSEIJINSYA_SOFU.YUBIN_NO,1,3)||'-'||SUBSTR(RSEIJINSYA_SOFU.YUBIN_NO,4);
              MJIDO_WORK(ICNT).ATENA_CHOMEI   := RSEIJINSYA_SOFU.CHOMEI;
              MJIDO_WORK(ICNT).ATENA_BANCHI   := RSEIJINSYA_SOFU.BANCHI;
              MJIDO_WORK(ICNT).ATENA_KATAGAKI := RSEIJINSYA_SOFU.KATAGAKI;
          END IF;

          -- 住民でなくなる事由名
          MJIDO_WORK(ICNT).JUMIN_NAKUNARU_JIYU_MEI := VJUMIN_NAKUNARU_JIYU_MEI;

          IRTN := GAAPK0030.FGETATENA(CRSEIJINSYA.KOJIN_CD, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), o_RATENA_REC, o_RSOFU_REC);
          MJIDO_WORK(ICNT).JINKAKU_KBN := o_RATENA_REC.JINKAKU_KBN;
          ICNT := ICNT + 1;                 -- カウントアップ
          IFRET := c_ISUCCESS;              -- 正常終了

        END LOOP;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD 0.3.000.001:8月1日認識合わせの横展開
        CLOSE CDATA;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD START 0.3.000.001:8月1日認識合わせの横展開
          IF CDATA%ISOPEN THEN
              CLOSE CDATA;
          END IF;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
          IFRET := c_INOT_SUCCESS;      -- 異常終了
          -- SQL情報取得
          N_SQL_CODE := SQLCODE;
          V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
          -- 処理ログの出力
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);
    END;

    -- 終了
    RETURN IFRET;
    EXCEPTION
      -- その他エラー
      WHEN OTHERS THEN
          IFRET := c_INOT_SUCCESS;      -- 異常終了
          -- SQL情報取得
          N_SQL_CODE := SQLCODE;
          V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
          -- 処理ログの出力
          bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, '成人者マスタ作成処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
          RETURN IFRET;
    END FUNC_GET_JIDO_WK;

    --------------------------------------------------------------------------------
    -- 成人者名簿ワーク（GKBWSEIJINSHA）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_INSERT_JIDO_WK RETURN NUMBER IS
    IFRET               PLS_INTEGER;                -- 戻り値
    ICNT                BINARY_INTEGER;             -- 戻り値
    IMAX                BINARY_INTEGER;             -- 戻り値
    IMIN                BINARY_INTEGER;             -- 戻り値
    BEGIN
    IFRET := c_ISUCCESS;                            -- 正常終了
    -- ワーク領域の最終位置を取得
    IMAX := MJIDO_WORK.LAST;
    -- ワーク領域の先頭位置を取得
    IMIN := MJIDO_WORK.FIRST;

    BEGIN
        -- ワーク領域の件数分繰り返し処理を行う
        FOR ICNT IN IMIN..IMAX LOOP
        INSERT INTO GKBWSEIJINSHA VALUES MJIDO_WORK(ICNT);
        END LOOP;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
        ROLLBACK;       -- 処理前に戻す
        IFRET := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        N_SQL_CODE := SQLCODE;
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        -- 処理ログの出力
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
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
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 成人式中間データ作成（ＣＳＶ用）
    --------------------------------------------------------------------------------
    FUNCTION FUNCGET_JIDO_WK_CSV RETURN NUMBER IS
    IFRET               PLS_INTEGER;                   -- 戻り値
    IRET                PLS_INTEGER;                   -- 戻り値
    ICNT                BINARY_INTEGER;                -- カウント
    VSQL                NVARCHAR2(10000);              -- ＳＱＬ文
    VSQLSEL             NVARCHAR2(9000);               -- ＳＱＬのソート以外
    VSQLORDER           NVARCHAR2(1000);               -- ＳＱＬの［ORDER BY］句
    ICUR                PLS_INTEGER;                   -- カーソル
    RREC                GKBWSEIJINSHA%ROWTYPE;         -- 成人式中間のレコード変数
    NROWS               NUMBER;                        --
    IPAGECNT            PLS_INTEGER;                   -- 頁数
    IGYOCNT             PLS_INTEGER;                   -- 行番号
    IGYORENBAN          PLS_INTEGER;                   -- 行連番
    VPAGENAME           NVARCHAR2(500);                -- 改頁項目名のワーク
    VPAGEWORK           NVARCHAR2(500);                -- 改頁項目値のワーク
    VPAGEFIELD          NVARCHAR2(500);                -- 改頁項目値のワーク

    BEGIN
    IFRET := c_ISUCCESS;                  -- 正常終了
    VPAGEWORK := '';
    IPAGECNT := 0;
    IGYOCNT := 0;
    ICNT := 0;
    IGYORENBAN := 0;
    MJIDO_WORK.DELETE;                   -- ワーク領域の初期化

     -- 改頁条件取得
    VPAGENM:= ' GYOSEIKUMEI ';
    VPAGEFD:= ' GYOSEIKU_CD ';

    BEGIN
        -- 出力データ取得ＳＱＬの構文
        VSQLSEL := '';
        VSQLSEL := VSQLSEL || 'SELECT ';
        VSQLSEL := VSQLSEL || 'NENDO, ';
        VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
        VSQLSEL := VSQLSEL || 'KAIPEJI, ';
        VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
        VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
        VSQLSEL := VSQLSEL || 'HAN_CD, ';
        VSQLSEL := VSQLSEL || 'HANMEI, ';
        VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
        VSQLSEL := VSQLSEL || 'SANTEIDANTAIMEI, ';
        VSQLSEL := VSQLSEL || 'SHIMEI_KANA, ';
        VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
        VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
        VSQLSEL := VSQLSEL || 'SEIBETSU, ';
        VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
        VSQLSEL := VSQLSEL || 'SETAI_NO, ';
        VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
        VSQLSEL := VSQLSEL || 'RENBAN, ';
        VSQLSEL := VSQLSEL || 'SHIMEI_KANJI, ';
        VSQLSEL := VSQLSEL || 'ZOKUGARAMEI, ';
        VSQLSEL := VSQLSEL || 'CHOMEI, ';
        VSQLSEL := VSQLSEL || 'BANCHI, ';
        VSQLSEL := VSQLSEL || 'KATAGAKI, ';
        VSQLSEL := VSQLSEL || 'JUSHO_JODAN, ';
        VSQLSEL := VSQLSEL || 'JUSHO_GEDAN, ';
        VSQLSEL := VSQLSEL || 'NUSI_SHIMEI_KANA, ';
        VSQLSEL := VSQLSEL || 'NUSI_SHIMEI_KANJI, ';
        VSQLSEL := VSQLSEL || 'YUBIN_NO, ';
        VSQLSEL := VSQLSEL || VPAGENM || ' KAIPEJI_CD, ';            -- 改頁名を設定
        VSQLSEL := VSQLSEL || VPAGEFD || ' KAIPEJI, ';           -- 改頁値を設定
        VSQLSEL := VSQLSEL || 'SHOGAKOKU_CD, ';
        VSQLSEL := VSQLSEL || 'SHOGAKOMEI ';
        VSQLSEL := VSQLSEL || ',CHUGAKOKU_CD, ';
        VSQLSEL := VSQLSEL || 'CHUGAKOMEI, ';
        VSQLSEL := VSQLSEL || 'SEIRI_NO, ';
        VSQLSEL := VSQLSEL || 'KOJIN_CD, ';
        VSQLSEL := VSQLSEL || 'ATENA_YUBIN_NO, ';
        VSQLSEL := VSQLSEL || 'ATENA_CHOMEI, ';
        VSQLSEL := VSQLSEL || 'ATENA_BANCHI, ';
        VSQLSEL := VSQLSEL || 'ATENA_KATAGAKI ';
        VSQLSEL := VSQLSEL || ', JUMIN_NAKUNARU_JIYU_MEI ';
        VSQLSEL := VSQLSEL || ',JINKAKU_KBN ';
        VSQLSEL := VSQLSEL || 'FROM ';
        VSQLSEL := VSQLSEL || 'GKBWSEIJINSHA ';

        -- ひとつのＳＱＬ文にする
        IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
            VSQL := VSQLSEL || ' ORDER BY ' || g_rJSTP.ORDERBYCLAUSE;
        END IF;
        -- カーソルのオープン
        ICUR := DBMS_SQL.OPEN_CURSOR;
        -- ＳＱＬ文の解析
        DBMS_SQL.PARSE(ICUR, VSQL, DBMS_SQL.NATIVE);

        -- 取得する列の定義
        DBMS_SQL.DEFINE_COLUMN(ICUR,  1, RREC.NENDO, 10);
        DBMS_SQL.DEFINE_COLUMN(ICUR,  2, RREC.KAIPEJI_CD, 500);
        DBMS_SQL.DEFINE_COLUMN(ICUR,  3, RREC.KAIPEJI, 500);
        DBMS_SQL.DEFINE_COLUMN(ICUR,  4, RREC.GYOSEIKU_CD);
        DBMS_SQL.DEFINE_COLUMN(ICUR,  5, RREC.GYOSEIKUMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(ICUR,  6, RREC.HAN_CD);
        DBMS_SQL.DEFINE_COLUMN(ICUR,  7, RREC.HANMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(ICUR,  8, RREC.SANTEIDANTAI_CD);
        DBMS_SQL.DEFINE_COLUMN(ICUR,  9, RREC.SANTEIDANTAIMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 10, RREC.SHIMEI_KANA, 100);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 11, RREC.SEINENGAPI);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 12, RREC.HYOJI_SEINENGAPI, 11);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 13, RREC.SEIBETSU);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 14, RREC.HYOJI_SEIBETSU, 2);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 15, RREC.SETAI_NO);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 16, RREC.SAKUSEIBI, 30);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 17, RREC.RENBAN);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 18, RREC.SHIMEI_KANJI, 100);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 19, RREC.ZOKUGARAMEI, 30);
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--        DBMS_SQL.DEFINE_COLUMN(ICUR, 20, RREC.CHOMEI, 40);
--        DBMS_SQL.DEFINE_COLUMN(ICUR, 21, RREC.BANCHI, 40);
--        DBMS_SQL.DEFINE_COLUMN(ICUR, 22, RREC.KATAGAKI, 60);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 20, RREC.CHOMEI, 136);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 21, RREC.BANCHI, 50);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 22, RREC.KATAGAKI, 300);
-- 2024/06/12 ZCZL.wangyunhan Update end
        DBMS_SQL.DEFINE_COLUMN(ICUR, 23, RREC.JUSHO_JODAN, 30);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 24, RREC.JUSHO_GEDAN, 30);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 25, RREC.NUSI_SHIMEI_KANA, 100);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 26, RREC.NUSI_SHIMEI_KANJI, 100);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 27, RREC.YUBIN_NO, 10);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 28, VPAGENM,500 );
        DBMS_SQL.DEFINE_COLUMN(ICUR, 29, VPAGEFD,500 );
        DBMS_SQL.DEFINE_COLUMN(ICUR, 30, RREC.SHOGAKOKU_CD );
        DBMS_SQL.DEFINE_COLUMN(ICUR, 31, RREC.SHOGAKOMEI,30 );
        DBMS_SQL.DEFINE_COLUMN(ICUR, 32, RREC.CHUGAKOKU_CD);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 33, RREC.CHUGAKOMEI,30);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 34, RREC.SEIRI_NO);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 35, RREC.KOJIN_CD);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 36, RREC.ATENA_YUBIN_NO,10);
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--        DBMS_SQL.DEFINE_COLUMN(ICUR, 37, RREC.ATENA_CHOMEI,40);
--        DBMS_SQL.DEFINE_COLUMN(ICUR, 38, RREC.ATENA_BANCHI,40);
--        DBMS_SQL.DEFINE_COLUMN(ICUR, 39, RREC.ATENA_KATAGAKI,60);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 37, RREC.ATENA_CHOMEI,136);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 38, RREC.ATENA_BANCHI,50);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 39, RREC.ATENA_KATAGAKI, 300);
-- 2024/06/12 ZCZL.wangyunhan Update end
        DBMS_SQL.DEFINE_COLUMN(ICUR, 40, RREC.JUMIN_NAKUNARU_JIYU_MEI,20);
        DBMS_SQL.DEFINE_COLUMN(ICUR, 41, RREC.JINKAKU_KBN);

        -- ＳＱＬ実行
        NROWS := DBMS_SQL.EXECUTE(ICUR);
        LOOP
        --FETCH（行の取り出し）
        IF DBMS_SQL.FETCH_ROWS(ICUR) > 0 THEN
            -- ワーク領域へセット
            DBMS_SQL.COLUMN_VALUE(ICUR,  1, MJIDO_WORK(ICNT).NENDO);
            DBMS_SQL.COLUMN_VALUE(ICUR,  2, MJIDO_WORK(ICNT).KAIPEJI_CD);
            DBMS_SQL.COLUMN_VALUE(ICUR,  3, MJIDO_WORK(ICNT).KAIPEJI);
            DBMS_SQL.COLUMN_VALUE(ICUR,  4, MJIDO_WORK(ICNT).GYOSEIKU_CD);
            DBMS_SQL.COLUMN_VALUE(ICUR,  5, MJIDO_WORK(ICNT).GYOSEIKUMEI);
            DBMS_SQL.COLUMN_VALUE(ICUR,  6, MJIDO_WORK(ICNT).HAN_CD);
            DBMS_SQL.COLUMN_VALUE(ICUR,  7, MJIDO_WORK(ICNT).HANMEI);
            DBMS_SQL.COLUMN_VALUE(ICUR,  8, MJIDO_WORK(ICNT).SANTEIDANTAI_CD);
            DBMS_SQL.COLUMN_VALUE(ICUR,  9, MJIDO_WORK(ICNT).SANTEIDANTAIMEI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 10, MJIDO_WORK(ICNT).SHIMEI_KANA);
            DBMS_SQL.COLUMN_VALUE(ICUR, 11, MJIDO_WORK(ICNT).SEINENGAPI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 12, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 13, MJIDO_WORK(ICNT).SEIBETSU);
            DBMS_SQL.COLUMN_VALUE(ICUR, 14, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
            DBMS_SQL.COLUMN_VALUE(ICUR, 15, MJIDO_WORK(ICNT).SETAI_NO);
            DBMS_SQL.COLUMN_VALUE(ICUR, 16, MJIDO_WORK(ICNT).SAKUSEIBI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 17, MJIDO_WORK(ICNT).RENBAN);
            DBMS_SQL.COLUMN_VALUE(ICUR, 18, MJIDO_WORK(ICNT).SHIMEI_KANJI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 19, MJIDO_WORK(ICNT).ZOKUGARAMEI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 20, MJIDO_WORK(ICNT).CHOMEI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 21, MJIDO_WORK(ICNT).BANCHI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 22, MJIDO_WORK(ICNT).KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 23, MJIDO_WORK(ICNT).JUSHO_JODAN);
            DBMS_SQL.COLUMN_VALUE(ICUR, 24, MJIDO_WORK(ICNT).JUSHO_GEDAN);
            DBMS_SQL.COLUMN_VALUE(ICUR, 25, MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA);
            DBMS_SQL.COLUMN_VALUE(ICUR, 26, MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 27, MJIDO_WORK(ICNT).YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(ICUR, 28, VPAGENAME);
            DBMS_SQL.COLUMN_VALUE(ICUR, 29, VPAGEFIELD);
            DBMS_SQL.COLUMN_VALUE(ICUR, 30, MJIDO_WORK(ICNT).SHOGAKOKU_CD);
            DBMS_SQL.COLUMN_VALUE(ICUR, 31, MJIDO_WORK(ICNT).SHOGAKOMEI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 32, MJIDO_WORK(ICNT).CHUGAKOKU_CD);
            DBMS_SQL.COLUMN_VALUE(ICUR, 33, MJIDO_WORK(ICNT).CHUGAKOMEI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 34, MJIDO_WORK(ICNT).SEIRI_NO);
            DBMS_SQL.COLUMN_VALUE(ICUR, 35, MJIDO_WORK(ICNT).KOJIN_CD);
            DBMS_SQL.COLUMN_VALUE(ICUR, 36, MJIDO_WORK(ICNT).ATENA_YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(ICUR, 37, MJIDO_WORK(ICNT).ATENA_CHOMEI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 38, MJIDO_WORK(ICNT).ATENA_BANCHI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 39, MJIDO_WORK(ICNT).ATENA_KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 40, MJIDO_WORK(ICNT).JUMIN_NAKUNARU_JIYU_MEI);
            DBMS_SQL.COLUMN_VALUE(ICUR, 41, MJIDO_WORK(ICNT).JINKAKU_KBN);


            -- 改頁の指定がある場合
            IF NVL(VPAGEWORK,' ') = NVL(VPAGENAME,' ') THEN
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

        DBMS_SQL.CLOSE_CURSOR(ICUR);
    EXCEPTION
        WHEN OTHERS THEN
        IFRET := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        N_SQL_CODE := SQLCODE;
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);

        IF DBMS_SQL.IS_OPEN(ICUR) THEN
            DBMS_SQL.CLOSE_CURSOR(ICUR);
        END IF;

        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
    END;
    -- 終了
    RETURN IFRET;
    EXCEPTION
    WHEN OTHERS THEN
        IFRET := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        N_SQL_CODE := SQLCODE;
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);

        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCGET_JIDO_WK_CSV;

    --------------------------------------------------------------------------------------------------
    -- 成人式名簿ＣＳＶファイル作成
    --------------------------------------------------------------------------------------------------
    FUNCTION FUNCSET_JIDO_WK_CSVFILE3 RETURN NUMBER IS
    IFRET               PLS_INTEGER;                -- 戻り値
    BRET                BOOLEAN;                    -- 戻り値
    ICNT                PLS_INTEGER;                -- カウント
    IMAX                PLS_INTEGER;                -- 最大値（出力件数）
    IMIN                PLS_INTEGER;                -- 最小値（出力件数）
    VDATA               NVARCHAR2(3000);            -- データ（１レコード分）
    r_WKRECORD001       GKBWL390R001%ROWTYPE;
    nCNT                NUMBER := 0;                 --件数
    g_nCSVCNT           NUMBER := 0;                 --CSV出力件数
    nROWNO NUMBER := 0;
    BEGIN
    nCNT := GKBFKTBLCNT('GKBWSEIJINSHA', NULL);
    IFRET := c_ISUCCESS;                -- 正常終了

    IMAX := MJIDO_WORK.LAST;           -- ワーク領域の件数の最大値
    IMIN := MJIDO_WORK.FIRST;          -- ワーク領域の件数の最小値

    -- 取得した件数分繰り返す
    FOR ICNT IN IMIN..IMAX LOOP
        nROWNO := nROWNO + 1;
        r_WKRECORD001 := NULL;
        r_WKRECORD001.NO := nROWNO;                                                                        --ソート順
        r_WKRECORD001.NENDO                   := MJIDO_WORK(ICNT).NENDO||'年度';                           --年度
        r_WKRECORD001.KAIPAGE_CD              := MJIDO_WORK(ICNT).KAIPEJI_CD;                              --改頁コード
        r_WKRECORD001.KAIPAGE_MEI             := MJIDO_WORK(ICNT).KAIPEJI;                                 --改頁名
        r_WKRECORD001.GYOSEIKU_MEI            := MJIDO_WORK(ICNT).GYOSEIKUMEI;                             --行政区名
        r_WKRECORD001.SANTEIDANTAI_MEI        := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;                         --算定団体名
        r_WKRECORD001.SHIMEI_KANA             := MJIDO_WORK(ICNT).SHIMEI_KANA;                             --氏名カナ
        r_WKRECORD001.SEINENGAPI              := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;                        --生年月日
        r_WKRECORD001.SEIBETSU                := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;                          --性別
        r_WKRECORD001.GENZAIBI                := MJIDO_WORK(ICNT).SAKUSEIBI;                               --現在日
        r_WKRECORD001.NUM                     := MJIDO_WORK(ICNT).RENBAN;                                  --No
        r_WKRECORD001.SHIMEI                  := MJIDO_WORK(ICNT).SHIMEI_KANJI;                            --氏名
        r_WKRECORD001.ZOKUGARA                := MJIDO_WORK(ICNT).ZOKUGARAMEI;                             --続柄
        r_WKRECORD001.KATAGAKI                := MJIDO_WORK(ICNT).KATAGAKI;                                --方書
        r_WKRECORD001.JUSHO_JODAN             := MJIDO_WORK(ICNT).JUSHO_JODAN;                             --住所上
        r_WKRECORD001.JUSHO_GEDAN             := MJIDO_WORK(ICNT).JUSHO_GEDAN;                             --住所下
        r_WKRECORD001.NUSHI_SHIMEI_KANA       := MJIDO_WORK(ICNT).NUSI_SHIMEI_KANA;                        --世帯主氏名カナ
        r_WKRECORD001.NUSHI_SHIMEI_KANJI      := MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI;                       --世帯主氏名
        r_WKRECORD001.YUBIN_NO                := MJIDO_WORK(ICNT).YUBIN_NO;                                --郵便番号
        r_WKRECORD001.CHOMEI_BANCHI           := MJIDO_WORK(ICNT).CHOMEI || MJIDO_WORK(ICNT).BANCHI;       --町名番地
        r_WKRECORD001.SHIMEI_KANJI_SAMA       := MJIDO_WORK(ICNT).SHIMEI_KANJI ||'　様';                    --氏名漢字様
        r_WKRECORD001.SHOGAKKO_CD             := MJIDO_WORK(ICNT).SHOGAKOKU_CD;                            --小学校コード
        r_WKRECORD001.SHOGAKKO_MEI            := MJIDO_WORK(ICNT).SHOGAKOMEI;                              --小学校名
        r_WKRECORD001.SEIRI_NO                := MJIDO_WORK(ICNT).SEIRI_NO;                                --整理番号
        r_WKRECORD001.ATENA_YUBIN_NO          := MJIDO_WORK(ICNT).ATENA_YUBIN_NO;                          --宛名郵便番号
        r_WKRECORD001.ATENA_JUSHO             := MJIDO_WORK(ICNT).ATENA_CHOMEI ||
                                                 MJIDO_WORK(ICNT).ATENA_BANCHI || ' ' ||
                                                 MJIDO_WORK(ICNT).ATENA_KATAGAKI;                          --宛名住所
        r_WKRECORD001.JUMIN_NAKUNARU_JIYU_MEI := MJIDO_WORK(ICNT).JUMIN_NAKUNARU_JIYU_MEI;                 --住民でなくなる事由名
        r_WKRECORD001.JINKAKU_KBN             := MJIDO_WORK(ICNT).JINKAKU_KBN;                             --人格区分
        r_WKRECORD001.BREAK_NO                := MJIDO_WORK(ICNT).KAIPEJI_CD;                              --改ページキー
        r_WKRECORD001.WSNUM                   := g_sWSNUM;                                                 --端末番号
        r_WKRECORD001.BATCHKBN                := c_BATCH;                                                  --バッチ区分
        r_WKRECORD001.JOBNUM                  := g_nJOBNUM;                                                --ジョブNO

        INSERT INTO GKBWL390R001 VALUES r_WKRECORD001;
--  2024/06/19 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
        g_nCSVCNT := g_nCSVCNT + 1;                                                                        --CSV出力件数
    END LOOP;
--  2024/06/19 ZCZL.wangyunhan Add strat 0.3.000.000:新WizLIFE２次開発
    g_oKENSU_LIST.EXTEND();
    g_oKENSU_LIST(1) :=GKBEKENSU_RECORD(nCNT,'入力 成人式名簿対象者件数',1);
    g_oKENSU_LIST.EXTEND();
    g_oKENSU_LIST(2) :=GKBEKENSU_RECORD(g_nCSVCNT,'出力 成人式名簿CSV',2);
--  2024/06/19 ZCZL.wangyunhan Add End
    -- 終了
    RETURN IFRET;
    EXCEPTION
    WHEN OTHERS THEN
        IFRET := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        N_SQL_CODE := SQLCODE;
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);

        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_CSVFILE3', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNCSET_JIDO_WK_CSVFILE3;

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        EXCEPT           EXCEPTION;
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        DELETE FROM GKBWL390R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
        -- システム日付を西暦数値（YYYYMMDD形式）にする
        ISAKUSEIBI := TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));

        -- 取得した条件をそれぞれの変数へセット
        VNENDO           := g_vJOKEN1;               -- 年度
        VKBN             := g_vJOKEN2;               -- 作成区分
        VSANTEIDANTAI_CD := g_vJOKEN3;               -- 算定団体コード
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        VSEINENGAPI_KAISHI  := KKAPK0020.FNENDOHENKAN(g_vJOKEN4);             -- 生年月日（開始）
        VSEINENGAPI_SHURYO  := KKAPK0020.FNENDOHENKAN(g_vJOKEN5);             -- 生年月日（終了）
-- 2024/06/12 ZCZL.wangyunhan Add end 
        -- 処理条件の設定
        PROCHAISET;

        -- 成人者名簿ワーク（GKBWSEIJINSHA）のデータ全件削除
        I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
        IF I_RTN = c_INOT_SUCCESS THEN
            -- エラーで帰ってきた場合
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
            RAISE EXCEPT;
        END IF;

        -- 成人者名簿ワーク中間データ作成
        I_RTN := FUNC_GET_JIDO_WK;
        IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            IF I_RTN = c_INOTFOUND THEN
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00027対応
--               bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
              GOTO END_EXIT;
            END IF;
            RAISE EXCEPT;
        END IF;

        -- 成人者名簿ワーク作成
        I_RTN := FUNC_INSERT_JIDO_WK;
        IF I_RTN = c_INOT_SUCCESS THEN
            -- エラーで帰ってきた場合
            RAISE EXCEPT;
        END IF;

        -- 成人式中間データ作成（ＣＳＶ用）
        I_RTN := FUNCGET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            -- ※ 終了処理は処理の内部で行っています
            RAISE EXCEPT;
        END IF;

        -- 成人式名簿ＣＳＶファイル作成
        I_RTN := FUNCSET_JIDO_WK_CSVFILE3;
        IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
            -- ※ 終了処理は処理の内部で行っています
            RAISE EXCEPT;
        END IF;

        --帳票出力CSVの作成
        bRTN := FUNC_B11CSV('GKBWL390R001');
--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.002:512_GKB_00027対応
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
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
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
    --  作成者／作成日: ZCZL.GUOXU 2024/01/26
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
END GKBPB00320;
/
