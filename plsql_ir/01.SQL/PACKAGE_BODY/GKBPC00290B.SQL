CREATE OR REPLACE PACKAGE BODY GKBPC00290
--1.0.205.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 成人者マスタ作成
--  機能概要      : 成人式に出席する対象者のマスタを作成する
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/06/04 ZCZL.WANGYUNING UPDATE 0.3.000.000:新WizLIFE２次開発
--  2024/09/11 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00114対応
--  2025/01/16 JPJYS.LIJINGHUI UPDATE 0.3.000.003:学校区マスタ対応
--  2025/02/14 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:資産比較対応
--  2025/11/10 CTC.HJF UPDATE 1.0.205.000:保守QA22954対応
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
    g_sSHORIID                    NVARCHAR2(8);                --処理ID
    g_sSHORISH                    NVARCHAR2(2);                --処理種別
    g_sGYOUMUCODE                 NVARCHAR2(3);                --業務コード
    g_sMESSAGE                    NVARCHAR2(4000);             --メッセージ返却用
    g_rJSTP                       KKBTJSTP%ROWTYPE;            --バッチジョブステップ情報
    --全域変数
    g_oKENSU_LIST                 GKBEKENSU_LIST := GKBEKENSU_LIST();

    g_nTIME NUMBER;  --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --画面から条件
    g_vJYOUKEN1  NVARCHAR2(500);
    g_vJYOUKEN2  NVARCHAR2(500);
    g_vJYOUKEN3  NVARCHAR2(500);
    g_vJYOUKEN4  NVARCHAR2(500);
    g_vJYOUKEN5  NVARCHAR2(500);
-- 2024/06/04 ZCZL.WANGYUNING ADD Start 0.3.000.000:新WizLIFE２次開発
    g_vJYOUKEN6  NVARCHAR2(500); 
    g_vJYOUKEN7  NVARCHAR2(500);
    g_nBIRTHDAY_START NUMBER;  --処理条件.生年月日(自)          
    g_nBIRTHDAY_END   NUMBER;  --処理条件.生年月日(至)
-- 2024/06/04 ZCZL.WANGYUNING ADD End
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
    CURSOR CJIDO(p_START   IN NUMBER,
                 p_END     IN NUMBER,
                 p_KIJUNBI IN NUMBER) IS
      SELECT A.KOJIN_NO,
             A.SHIMEI_KANA,
-- 2024/06/04 ZCZL.WANGYUNING ADD 0.3.000.000:新WizLIFE２次開発
             A.RIREKI_RENBAN,         --履歴連番
             A.SHIMEI_KANJI,
             A.SEINENGAPI,
             A.SEIBETSU,
             A.CHUGAKU_CD,
             A.GYOSEIKU_CD,
             A.TEL_NO,
             A.SANTEIDANTAI_CD,
             A.YUBIN_NO,
--  2025/01/16 JPJYS.SONGSHIHAO UPDATE 0.3.000.003:学校区マスタ対応  Start
             A.SHOGAKU_CD,              --小学校区コード
--  2025/01/16 JPJYS.SONGSHIHAO UPDATE 0.3.000.003:学校区マスタ対応  End             
             A.CHOMEI,
             A.BANCHI,
             A.KATAGAKI
        FROM GABTATENAKIHON A
       WHERE A.SEINENGAPI BETWEEN p_START AND p_END
-- 2024/06/04 ZCZL.WANGYUNING UPDATE START 0.3.000.000:新WizLIFE２次開発
--         AND A.GENZON_KBN < 3;
--  2024/09/11 ZCZL.LIUCHANGQUAN ADD 0.3.000.001:8月1日認識合わせの横展開
--  2025/02/14 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:資産比較対応
         --AND A.GENZON_KBN > 3
         AND A.GENZON_KBN < 3
--  2025/02/14 JPJYS.SONGSHIHAO UPDATE 0.3.000.004:資産比較対応
         AND A.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) FROM GABTATENAKIHON B WHERE A.KOJIN_NO = B.KOJIN_NO);
-- 2024/06/04 ZCZL.WANGYUNING UPDATE END
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
    -- 戻り値
    c_IOK          CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_IERR         CONSTANT  PLS_INTEGER := 1;         --異常
    -- 正常メッセージの値
    c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '成人者マスタ作成処理が正常終了しました。';
    --パラメータ変数
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    NSHORIBI                  NUMBER;
    NSYSTIME                  NUMBER;       -- システム時間
    ISHOGAKO_CD               PLS_INTEGER;
    IMAX                      BINARY_INTEGER;
    -- 関数用変数
    B_RTN                     BOOLEAN;
    I_RTN                     PLS_INTEGER;
    -- 処理条件（画面からの引数）
    VNENDO                    NVARCHAR2(15);       -- 対象年度
    V_KIJUNBI                 NVARCHAR2(15);       -- 基準日
    N_JUMIN_KIJUNBI           PLS_INTEGER;         -- 住民基準日
    N_CHUGAKU_KIJUNBI         PLS_INTEGER;         -- 中学校卒業時点の基準日
    IGAIKOKUJIN_HANTEI        PLS_INTEGER;         -- 外国人を抽出するか（0:する 1:しない）
    ICHUSHUTSU_HANTEI         PLS_INTEGER;         -- 中学校卒業以降の住民を対象とするか（0:しない 1:する）
    JI_GENZON_KBN             PLS_INTEGER;         -- 住基異動現存区分
    JI_JUMIN_NAKUNARU_JIYU    PLS_INTEGER;         -- 住基異動住民でなくなる異動事由
    ISAKUJO_KBN               PLS_INTEGER;         --既存データ削除区分（0:削除しない1:削除する）

    BTARGET                   BOOLEAN;             -- 対象レコードとして適正か
    IGENZON_KBN               PLS_INTEGER;
    IJINKAKU_KBN              PLS_INTEGER;
    VYUBIN_NO                 NVARCHAR2(10);
    VCHOMEI                   NVARCHAR2(40);
    VBANCHI                   NVARCHAR2(40);
    VKATAGAKI                 NVARCHAR2(60);
    VSHIMEI_KANA              NVARCHAR2(100);
    VSHIMEI_KANJI             NVARCHAR2(100);
    ISEINENGAPI               PLS_INTEGER;
    ISEIBETSU                 PLS_INTEGER;
    IGYOSEIKU_CD              PLS_INTEGER;
    VGYOSEIKU_NM              NVARCHAR2(15);
    ICHUGAKU_CD               PLS_INTEGER;
    VCHUGAKU_NM               NVARCHAR2(15);
    VTEL_NO                   NVARCHAR2(20);
    ISANTEIDANTAI_CD          PLS_INTEGER;
    VSANTEIDANTAI_NM          NVARCHAR2(40);
    VCUSTOM_BC                NVARCHAR2(50);
    ITENSHUTSU_FLAG           PLS_INTEGER;    --現時点では保留（取得するが、DBへセットしない）
    ISHOGAKU_CD               PLS_INTEGER;
    VSHOGAKU_NM               NVARCHAR2(15);
    INENDO                    PLS_INTEGER;  --年度
-- 2024/06/04 ZCZL.WANGYUNING ADD Start 0.3.000.000:新WizLIFE２次開発
    VSHOGAKU_CD               NVARCHAR2(1000); --小学校区コード
    VCHUGAKU_CD               NVARCHAR2(1000); --中学校区コード
-- 2024/06/04 ZCZL.WANGYUNING ADD End

    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBTSEIJINSHA%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK MTJIDO_TYPE;
    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    io_SEIREKIHIZUKE     PLS_INTEGER;
    VEDIT_GYYMMDD1       NVARCHAR2(20);
    VEDIT_GYYMMDD2       NVARCHAR2(20);
    VEDIT_GYYMMDD3       NVARCHAR2(20);
    VKJ_GENGO            NVARCHAR2(20);
    VKG_GENGO            NVARCHAR2(20);
    IWAREKI_YY           PLS_INTEGER;
    ISEIREKI_YYYY        PLS_INTEGER;
    IWAREKI_GYYMM        PLS_INTEGER;
    IMM                  PLS_INTEGER;
    IDD                  PLS_INTEGER;
    IOWAREKIHIZUKE       PLS_INTEGER;
    ISEIREKIHIZUKE       PLS_INTEGER;
    VMSG NVARCHAR2(4000);
    IRTN PLS_INTEGER;
    ERR                  EXCEPTION;
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
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
        g_sSHORISH      := rJCTL.SHORISH;            --処理種別
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        v_cmbGaikokujinKbn                           DBMS_UTILITY.MAXNAME_ARRAY;
        v_cmbKisonDataSakujoKbn                      DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        g_vJYOUKEN1 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNendo');
        g_vJYOUKEN2 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtGenzonshaJuminKijunBi');
        g_vJYOUKEN3 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtChugakkoSotsugyoJitenNoJuminKijunBi');
        v_cmbGaikokujinKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGaikokujinKbn');
        g_vJYOUKEN4 := v_cmbGaikokujinKbn(1);
        v_cmbKisonDataSakujoKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbKisonDataSakujoKbn');
        g_vJYOUKEN5 := v_cmbKisonDataSakujoKbn(1);
-- 2024/06/04 ZCZL.WANGYUNING ADD Start 0.3.000.000:新WizLIFE２次開発
        --生年月日(自)
        g_vJYOUKEN6:= KKBPK5551.GETPARMS(g_nJOBNUM, 'txtBirStartYmd');
        --生年月日(至)
        g_vJYOUKEN7:= KKBPK5551.GETPARMS(g_nJOBNUM, 'txtBirEndYmd');
        --取得したバッチ処理入力値は条件取得処理をして、変数にセットする。
        --処理条件.生年月日(自)
        g_nBIRTHDAY_START := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN6);
        --処理条件.生年月日(至)
        g_nBIRTHDAY_END := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN7);
-- 2024/06/04 ZCZL.WANGYUNING ADD End
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
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
    --年度チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCNENDOCHK( i_VNENDO IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    INENDO NUMBER;
    BEGIN
      IRET := 0;
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

      RETURN(IRET);
    END FUNCNENDOCHK;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                : o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
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
        VMSG := '';
        IRTN := 0;

        --条件１のチェック
        IRTN := FUNCNENDOCHK( g_vJYOUKEN1 );
        IF IRTN <> 0 THEN
            VMSG := g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
        END IF;
        
-- 2024/06/04 ZCZL.WANGYUNING ADD Start 0.3.000.000:新WizLIFE２次開発
        --生年月日(自)）の日付変換(KKAPK0020.FDateFmt)でエラーの場合
        bRTN := KKAPK0010.FISNUMERIC(g_vJYOUKEN6);
        IF bRTN THEN          
          -- 生年月日(自)の日付チェック
          bRTN := KKAPK0020.FISDATEW(g_vJYOUKEN6);
          IF bRTN = FALSE THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日(自)が正しくありません。,;';
          END IF;
        ELSE
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00114対応
--          VMSG := VMSG || g_sGYOUMUCODE || ', 99999,生年月日(自)が正しくありません。,;';  
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日(自)が正しくありません。,;';
        END IF;

-- 2024/07/15 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
       IF VMSG IS NULL THEN
        --生年月日(至)の日付変換(KKAPK0020.FDateFmt)でエラーの場合
        bRTN := KKAPK0010.FISNUMERIC(g_vJYOUKEN7);
        IF bRTN THEN
          -- 生年月日(至)の日付チェック
          bRTN := KKAPK0020.FISDATEW(g_vJYOUKEN7);
          IF bRTN = FALSE THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日(至)が正しくありません。,;';
          END IF;
        ELSE
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00114対応
--          VMSG := VMSG || g_sGYOUMUCODE || ', 99999,生年月日(至)が正しくありません。,;';       
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日(至)が正しくありません。,;';
        END IF;
-- 2024/07/15 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
       END IF;

-- 2024/07/15 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
       IF VMSG IS NULL THEN        
        --変数.生年月日(自) > 変数.生年月日(至)の場合
        IF TO_NUMBER(g_vJYOUKEN6) > TO_NUMBER(g_vJYOUKEN7) THEN
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00114対応
--          VMSG := VMSG || g_sGYOUMUCODE || ', 99999,生年月日(自)、生年月日(至)の関係が正しくありません。,;';  
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日(自)、生年月日(至)の関係が正しくありません。,;';
        END IF;
-- 2024/07/15 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
       END IF;
       IF VMSG IS NULL THEN  
-- 2024/07/15 ZCZL.qinyue Add end     
        --変数.生年月日(至)　≧　変数.生年月日(自)の翌年の4月2日 また 変数.生年月日(至) ー 変数.生年月日(自)　＞　1年の場合
        IF TO_NUMBER(g_vJYOUKEN7) >= TO_NUMBER(SUBSTR(TO_NUMBER(g_vJYOUKEN6),1 , 3) + 1 || '0402') 
--  2024/09/11 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--          OR (TO_NUMBER(g_nBIRTHDAY_START) - TO_NUMBER(g_nBIRTHDAY_END) > 10000) THEN
          OR (TO_NUMBER(g_nBIRTHDAY_END) - TO_NUMBER(g_nBIRTHDAY_START) > 10000) THEN
--  2024/09/20 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00114対応
--          VMSG := VMSG || g_sGYOUMUCODE || ', 99999,生年月日(自)、生年月日(至)は1学年分区間ではありません。,;';     
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,生年月日(自)、生年月日(至)は1学年分区間ではありません。,;';
        END IF;
-- 2024/07/15 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
       END IF;
-- 2024/06/04 ZCZL.WANGYUNING ADD End
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
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

    ------------------------------------------------------------------------------
    -- 旧自治体名称取得
    ------------------------------------------------------------------------------
    FUNCTION FUNC_JICHINAME( pSANTEIDANTAI_CD IN NUMBER ) RETURN NVARCHAR2 IS
      IRTN        PLS_INTEGER;
      WK_MEISYO   NVARCHAR2(40);
      VRTN        NVARCHAR2(40);
    BEGIN
      WK_MEISYO := NULL;
      IRTN := GAAPK0030.FJICHINAME( pSANTEIDANTAI_CD, WK_MEISYO );
      IF IRTN = 0 THEN
        VRTN := WK_MEISYO;
      ELSE
        VRTN := NULL;
      END IF;
      RETURN VRTN;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_JICHINAME;

    --------------------------------------------------------------------------------
    -- 中学校卒業以降に一度でも住民となった対象者の抽出区分の取得(0=抽出しない,1=抽出する)
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_CHUSHUTSU_HANTEI RETURN PLS_INTEGER IS
      IRTN                PLS_INTEGER;
      TACONSPRM           A_CONS_PRM;                 --戻るパラメータ配列
      NLENGTH             NUMBER;                     --配列件数
    BEGIN
      IRTN := 0;
      BEGIN
        IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      96,         --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
        IF NLENGTH <> 0 THEN
        --レコードが取得できた場合
          IRTN := TACONSPRM(1);
        ELSE
        --レコードが取得できない場合
          IRTN := 0;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          --データが存在しない場合は、抽出しない(=0)をデフォルトとする。
          IRTN := 0;
      END;
      RETURN IRTN;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN IRTN;
    END FUNC_GET_CHUSHUTSU_HANTEI;

    --------------------------------------------------------------------------------
    -- 個人レコードの初期化
    --------------------------------------------------------------------------------
    PROCEDURE PROC_INITIALIZE IS
    BEGIN
      BTARGET           := FALSE;
      ITENSHUTSU_FLAG   := 0;
      IGENZON_KBN       := 0;
      IJINKAKU_KBN      := 0;
      VYUBIN_NO         := NULL;
      VCHOMEI           := NULL;
      VBANCHI           := NULL;
      VKATAGAKI         := NULL;
      VSHIMEI_KANA      := NULL;
      VSHIMEI_KANJI     := NULL;
      ISEINENGAPI       := 0;
      ISEIBETSU         := 0;
      IGYOSEIKU_CD      := 0;
      ICHUGAKU_CD       := 0;
      VTEL_NO           := NULL;
      ISANTEIDANTAI_CD  := 0;
      ISHOGAKO_CD       := 0;
-- 2024/06/04 ZCZL.WANGYUNING ADD Start 0.3.000.000:新WizLIFE２次開発
      VSHOGAKU_CD       := NULL;
      VSHOGAKU_NM       := NULL;
      VCHUGAKU_CD       := NULL;
      VCHUGAKU_NM       := NULL;
-- 2024/06/04 ZCZL.WANGYUNING ADD End      
    END PROC_INITIALIZE;

    --------------------------------------------------------------------------------
    -- 成人者マスタ中間（GKBTSEIJINSHA）の初期化
    --------------------------------------------------------------------------------
    FUNCTION FUNC_INIT_SEIJINSYA(pNENDO IN PLS_INTEGER) RETURN PLS_INTEGER IS
      INENDO PLS_INTEGER;
      IRTN   PLS_INTEGER;
    BEGIN
      IRTN := 0;
      INENDO := KKAPK0020.FNENDO( pNENDO,1 );  --西暦変換
      DELETE FROM GKBTSEIJINSHA
       WHERE NENDO = INENDO;
      RETURN IRTN;
    EXCEPTION
      WHEN OTHERS THEN
        IRTN := SQLCODE;
        RETURN IRTN;
    END FUNC_INIT_SEIJINSYA;

    --------------------------------------------------------------------------------
    -- 住基異動検索
    --------------------------------------------------------------------------------
    FUNCTION FUNC_CHK_JUKIIDO(i_IKOJIN_NO        IN  NUMBER,
                              i_IKIJUN_BI        IN  PLS_INTEGER,
                              o_IGENZON_KBN      OUT PLS_INTEGER,
                              o_JINKAKU_KBN      OUT PLS_INTEGER,
                              o_VYUBIN_NO        OUT NVARCHAR2,
                              o_VCHOMEI          OUT NVARCHAR2,
                              o_VBANCHI          OUT NVARCHAR2,
                              o_VKATAGAKI        OUT NVARCHAR2,
                              o_VSHIMEI_KANA     OUT NVARCHAR2,
                              o_VSHIMEI_KANJI    OUT NVARCHAR2,
                              o_SEINENGAPI       OUT PLS_INTEGER,
                              o_SEIBETSU         OUT PLS_INTEGER,
                              o_IGYOSEIKU_CD     OUT PLS_INTEGER,
                              o_VGYOSEIKU_NM     OUT NVARCHAR2,
                              o_ICHUGAKU_CD      OUT PLS_INTEGER,
                              o_VCHUGAKU_NM      OUT NVARCHAR2,
                              o_ISHOGAKU_CD      OUT PLS_INTEGER,
                              o_VSHOGAKU_NM      OUT NVARCHAR2,
                              o_VTEL_NO          OUT NVARCHAR2,
                              o_ISANTEIDANTAI_CD OUT PLS_INTEGER,
                              o_VSANTEIDANTAI_NM OUT NVARCHAR2,
                              o_VCUSTOM_BC       OUT NVARCHAR2) RETURN PLS_INTEGER IS
      IRTN   PLS_INTEGER;
    BEGIN
      BEGIN
        SELECT JI.JINKAKU_KBN,
               AK.YUBIN_NO,AK.CHOMEI,AK.BANCHI,AK.KATAGAKI,
               JI.SHIMEI_KANA,JI.SHIMEI_KANJI,
               JI.SEINENGAPI,JI.SEIBETSU,
               JI.GYOSEIKU_CD,JI.CHUGAKU_CD,
               AK.TEL_NO,JI.SANTEIDANTAI_CD
              ,JI.SHOGAKU_CD
          INTO o_JINKAKU_KBN,
               o_VYUBIN_NO,o_VCHOMEI,o_VBANCHI,o_VKATAGAKI,
               o_VSHIMEI_KANA,o_VSHIMEI_KANJI,
               o_SEINENGAPI,o_SEIBETSU,
               o_IGYOSEIKU_CD,o_ICHUGAKU_CD,
               o_VTEL_NO,o_ISANTEIDANTAI_CD
              ,o_ISHOGAKU_CD
          FROM GABTATENAKIHON AK,GABTJUKIIDO JI
         WHERE JI.KOJIN_NO = i_IKOJIN_NO
           AND JI.KOJIN_NO = AK.KOJIN_NO(+)
           AND JI.JUMIN_NARU > i_IKIJUN_BI;

        o_VGYOSEIKU_NM := GAAPK0030.FGYOSEIKUMEI( o_ISANTEIDANTAI_CD,o_IGYOSEIKU_CD );
--2024/06/04 ZCZL.WANGYUNING DELETE START 0.3.000.000:新WizLIFE２次開発
--        o_VCHUGAKU_NM := GAAPK0030.FCHUGAKUMEI( o_ISANTEIDANTAI_CD,o_ICHUGAKU_CD );
--        o_VSHOGAKU_NM := GAAPK0030.FSHOGAKUMEI( o_ISANTEIDANTAI_CD,o_ISHOGAKU_CD );
--2024/06/04 ZCZL.WANGYUNING DELETE END
        o_VSANTEIDANTAI_NM := FUNC_JICHINAME( o_ISANTEIDANTAI_CD );
        o_VCUSTOM_BC := GAAPK0010.FCUSTOM_BC( o_VYUBIN_NO,o_VCHOMEI,o_VBANCHI,o_VKATAGAKI );
        o_IGENZON_KBN := 0; --データが存在したら、現存区分=0のデータとして取得する
      EXCEPTION
        WHEN OTHERS THEN
          IRTN := SQLCODE;
          RETURN IRTN;
      END;
      IRTN := 0;
      RETURN IRTN;
    EXCEPTION
      WHEN OTHERS THEN
        IRTN := 9;
        RETURN IRTN;
    END FUNC_CHK_JUKIIDO;

    ------------------------------------------------------------------------------
    -- 住民の時の最終住所を取得（住民用）
    ------------------------------------------------------------------------------
    FUNCTION FUNC_GET_GENJUSHO1(i_IKOJIN_NO IN NUMBER) RETURN PLS_INTEGER IS
      IRTN        PLS_INTEGER;
    BEGIN
      IRTN := c_IERR;
      BEGIN
        SELECT JJ.YUBIN_NO,JJ.CHOMEI,JJ.BANCHI,JJ.KATAGAKI
          INTO VYUBIN_NO,VCHOMEI,VBANCHI,VKATAGAKI
          FROM GABTJUKIIDO JI,GABTJUKIJUSHO JJ
         WHERE JI.KOJIN_NO = i_IKOJIN_NO
           AND JJ.KOJIN_NO = JI.KOJIN_NO
           AND JJ.JUSHO_REN = JI.GENJUSHO_REN;

        IRTN := c_IOK;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          IRTN := c_INOTFOUND;
        WHEN OTHERS THEN
          IRTN := c_IERR;
      END;

      RETURN IRTN;
    EXCEPTION
      WHEN OTHERS THEN
        IRTN := c_IERR;
        RETURN IRTN;
    END FUNC_GET_GENJUSHO1;

    ------------------------------------------------------------------------------
    -- 住民の時の最終住所を取得（外国人用）
    ------------------------------------------------------------------------------
    FUNCTION FUNC_GET_GENJUSHO2(i_IKOJIN_NO IN NUMBER) RETURN PLS_INTEGER IS
      IRTN        PLS_INTEGER;
    BEGIN
      IRTN := c_IERR;
      BEGIN
        SELECT A.YUBIN_NO,A.CHOMEI,A.BANCHI,A.KATAGAKI
          INTO VYUBIN_NO,VCHOMEI,VBANCHI,VKATAGAKI
          FROM GABTATENARIREKI A,
               (SELECT MAX(RIREKI_RENBAN) AS RIREKI_RENBANMAX
                  FROM GABTATENARIREKI
                 WHERE KOJIN_NO = i_IKOJIN_NO
                   AND GENZON_KBN = 0
                 GROUP BY KOJIN_NO
               ) B
         WHERE A.KOJIN_NO = i_IKOJIN_NO
           AND A.GENZON_KBN = 0
           AND A.RIREKI_RENBAN = B.RIREKI_RENBANMAX;

        IRTN := c_IOK;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          IRTN := c_INOTFOUND;
        WHEN OTHERS THEN
          IRTN := c_IERR;
      END;

      RETURN IRTN;
    EXCEPTION
      WHEN OTHERS THEN
        IRTN := c_IERR;
        RETURN IRTN;
    END FUNC_GET_GENJUSHO2;

    --------------------------------------------------------------------------------
    -- 成人者マスタ中間（GKBTSEIJINSHA）レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
      IFRET             PLS_INTEGER;                -- 戻り値
      ISTART            PLS_INTEGER;                -- 開始生年月日
      IEND              PLS_INTEGER;                -- 終了生年月日
      ICNT              BINARY_INTEGER;             -- 戻り値
      IRTN              PLS_INTEGER;
      bRTN              BOOLEAN;
    BEGIN
        IFRET := c_INOTFOUND;                 -- 該当なし
        INENDO := TO_NUMBER(VNENDO);        -- 年度
        -- 対象年度を西暦に変換
        INENDO := KKAPK0020.FNENDO(INENDO,1);
        -- 成人式出席対象者の生年月日
-- 2024/06/04 ZCZL.WANGYUNING UPDATE Start 0.3.000.000:新WizLIFE２次開発
        --ISTART := (INENDO - 20) * 10000 + 402;
        --IEND := (INENDO - 19) * 10000 + 401;
        ISTART := g_nBIRTHDAY_START;
        IEND := g_nBIRTHDAY_END;
-- 2024/06/04 ZCZL.WANGYUNING UPDATE End
        -- 宛名基本を検索
        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        ICNT := 1;

        BEGIN
          -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
            FOR CRJIDO IN CJIDO(ISTART,IEND,V_KIJUNBI) LOOP
              PROC_INITIALIZE;
              -- 現存者住民基準日で検索
              IRTN := GKBFKGZSHNT(CRJIDO.KOJIN_NO,N_JUMIN_KIJUNBI,
                                 IGENZON_KBN,IJINKAKU_KBN,
                                 VYUBIN_NO,VCHOMEI,VBANCHI,VKATAGAKI,
                                 VSHIMEI_KANA,VSHIMEI_KANJI,
                                 ISEINENGAPI,ISEIBETSU,
                                 IGYOSEIKU_CD,VGYOSEIKU_NM,ICHUGAKU_CD,VCHUGAKU_NM,
                                 ISHOGAKU_CD,VSHOGAKU_NM,
                                 VTEL_NO,ISANTEIDANTAI_CD,VSANTEIDANTAI_NM,VCUSTOM_BC);

              IF IRTN = 0 AND IGENZON_KBN = 0 THEN
                IF IGAIKOKUJIN_HANTEI = 1 AND IJINKAKU_KBN = 1 THEN
                  BTARGET := FALSE;
                ELSE
                  BTARGET := TRUE;
                END IF;
              ELSE
                -- 中学卒業基準日で検索
                IF N_CHUGAKU_KIJUNBI <> 0 THEN
                  PROC_INITIALIZE;
                  IRTN := GKBFKGZSHNT(CRJIDO.KOJIN_NO,N_CHUGAKU_KIJUNBI,
                                     IGENZON_KBN,IJINKAKU_KBN,
                                     VYUBIN_NO,VCHOMEI,VBANCHI,VKATAGAKI,
                                     VSHIMEI_KANA,VSHIMEI_KANJI,
                                     ISEINENGAPI,ISEIBETSU,
                                     IGYOSEIKU_CD,VGYOSEIKU_NM,ICHUGAKU_CD,VCHUGAKU_NM,
                                     ISHOGAKU_CD,VSHOGAKU_NM,
                                     VTEL_NO,ISANTEIDANTAI_CD,VSANTEIDANTAI_NM,VCUSTOM_BC);
                  IF IRTN = 0 AND IGENZON_KBN = 0 THEN
                    IF IGAIKOKUJIN_HANTEI = 1 AND IJINKAKU_KBN = 1 THEN
                      BTARGET := FALSE;
                    ELSE
                      BTARGET := TRUE;
                    END IF;
                  ELSE
                    --システム条件をもとに判定を行うかどうかを判断
                    IF ICHUSHUTSU_HANTEI = 1 THEN
                      PROC_INITIALIZE;
                      ITENSHUTSU_FLAG := 1;  --転出フラグ
                      -- 住民となる日＞中学卒業時点で住基異動を検索
                      IRTN := FUNC_CHK_JUKIIDO(CRJIDO.KOJIN_NO,N_CHUGAKU_KIJUNBI,
                                               IGENZON_KBN,IJINKAKU_KBN,
                                               VYUBIN_NO,VCHOMEI,VBANCHI,VKATAGAKI,
                                               VSHIMEI_KANA,VSHIMEI_KANJI,
                                               ISEINENGAPI,ISEIBETSU,
                                               IGYOSEIKU_CD,VGYOSEIKU_NM,ICHUGAKU_CD,VCHUGAKU_NM,
                                               ISHOGAKU_CD,VSHOGAKU_NM,
                                               VTEL_NO,ISANTEIDANTAI_CD,VSANTEIDANTAI_NM,VCUSTOM_BC);
                      IF IRTN = 0 AND IGENZON_KBN = 0 THEN
                        IF IGAIKOKUJIN_HANTEI = 1 AND IJINKAKU_KBN = 1 THEN
                          BTARGET := FALSE;
                        ELSE
                          --住民だったときの最終住所を取得しなおす。最新宛名住所はすでにセットしているため
                          --取得できた場合のみ上書きされる
                          IF IJINKAKU_KBN = 0 THEN
                            IRTN := FUNC_GET_GENJUSHO1(CRJIDO.KOJIN_NO);  --住民のとき
                          ELSE
                            IRTN := FUNC_GET_GENJUSHO2(CRJIDO.KOJIN_NO);  --外国人のとき
                          END IF;

                          BTARGET := TRUE;
                        END IF;
                      END IF;
                    ELSE
                      BTARGET := FALSE;
                    END IF;
                  END IF;
                ELSE
                  BTARGET := FALSE;
                END IF;
              END IF;

              --最新住記の喪失チェック
              BEGIN
                SELECT GENZON_KBN,JUMIN_NAKUNARU_JIYU
                  INTO JI_GENZON_KBN,JI_JUMIN_NAKUNARU_JIYU
                  FROM GABTJUKIIDO
                 WHERE KOJIN_NO = CRJIDO.KOJIN_NO;
              EXCEPTION
                WHEN OTHERS THEN
                  JI_GENZON_KBN := 0;
                  JI_JUMIN_NAKUNARU_JIYU := 0;
                  BTARGET := FALSE;
              END;
--  2025/11/10 CTC.HJF UPDATE START 1.0.205.000:保守QA22954対応
              --読み飛ばす条件を２１（転出）以外に修正
              --IF JI_GENZON_KBN = 1 AND JI_JUMIN_NAKUNARU_JIYU <> 21 THEN
              IF JI_GENZON_KBN = 1 AND JI_JUMIN_NAKUNARU_JIYU NOT IN (210,211) THEN
--  2025/11/10 CTC.HJF UPDATE END
                  BTARGET := FALSE;
              END IF;
              --成人者マスタに出力します
              IF BTARGET = TRUE THEN
-- 2024/06/04 ZCZL.WANGYUNING ADD Start 0.3.000.000:新WizLIFE２次開発
                --共通関数学齢簿学校区取得（GKBFKGKKUGET）を使用して、小学校区コード、小学校区名、中学校区コードと中学校区名を取得する。
--  2025/01/16 JPJYS.LIJINGHUI UPDATE 0.3.000.003:学校区マスタ対応  Start                
--                IRTN := GKBFKGKKUGET(CRJIDO.KOJIN_NO,
--                                    CRJIDO.RIREKI_RENBAN,
--                                     VSHOGAKU_CD,
--                                     VSHOGAKU_NM,
--                                     VCHUGAKU_CD,
--                                     VCHUGAKU_NM);
--  2025/01/16 JPJYS.LIJINGHUI UPDATE 0.3.000.003:学校区マスタ対応  End                                     
-- 2024/06/04 ZCZL.WANGYUNING ADD End
                MJIDO_WORK(ICNT).NENDO := INENDO;
                MJIDO_WORK(ICNT).SEIRI_NO := ICNT;
                MJIDO_WORK(ICNT).KOJIN_CD := CRJIDO.KOJIN_NO;
                MJIDO_WORK(ICNT).SHIMEI_KANA := CRJIDO.SHIMEI_KANA;
                MJIDO_WORK(ICNT).SHIMEI_KANJI := CRJIDO.SHIMEI_KANJI;
                MJIDO_WORK(ICNT).SEINENGAPI := ISEINENGAPI;
                MJIDO_WORK(ICNT).SEIBETU := ISEIBETSU;
--  2025/01/16 JPJYS.LIJINGHUI UPDATE 0.3.000.003:学校区マスタ対応  Start  
                BEGIN
                  SELECT
                      GKBTSHOGAKKO.SYOGAKOMEI
                    INTO vSHOGAKU_NM 
                    FROM
                      GABTATENAKIHON,   --宛名基本
                      GKBTSHOGAKKO      --小学校名
                   WHERE
                      GABTATENAKIHON.SHOGAKU_CD = GKBTSHOGAKKO.SYOGAKO_CD
                      AND GABTATENAKIHON.KOJIN_NO = CRJIDO.KOJIN_NO;
                EXCEPTION
                   WHEN OTHERS THEN
                     vSHOGAKU_NM := '';
                END; 
                
                BEGIN
                  SELECT
                      GKBTCHUGAKKO.TYUGAKOMEI
                    INTO VCHUGAKU_NM 
                    FROM
                      GABTATENAKIHON,   --宛名基本
                      GKBTCHUGAKKO      --中学校名
                   WHERE
                      GABTATENAKIHON.CHUGAKU_CD = GKBTCHUGAKKO.TYUGAKO_CD
                      AND GABTATENAKIHON.KOJIN_NO = CRJIDO.KOJIN_NO;
                EXCEPTION
                   WHEN OTHERS THEN
                     VCHUGAKU_NM := '';
                END ;

                MJIDO_WORK(ICNT).TYUGAKO_KU := VCHUGAKU_NM;             --中学校区名
                MJIDO_WORK(ICNT).GYOSEI_KU := VGYOSEIKU_NM;
                MJIDO_WORK(ICNT).YUBIN_NO := VYUBIN_NO;
                MJIDO_WORK(ICNT).CHOMEI := VCHOMEI;
                MJIDO_WORK(ICNT).BANCHI := VBANCHI;
                MJIDO_WORK(ICNT).KATAGAKI := VKATAGAKI;
                MJIDO_WORK(ICNT).TEL_NO := VTEL_NO;
                MJIDO_WORK(ICNT).SYUKETSU_KBN := 1;
                MJIDO_WORK(ICNT).SANTEIDANTAI_CD := ISANTEIDANTAI_CD;
                MJIDO_WORK(ICNT).SHOGAKO_KU    := VSHOGAKU_NM;          --小学校区名
--  2025/01/16 JPJYS.LIJINGHUI UPDATE 0.3.000.003:学校区マスタ対応  End                
-- 2024/06/04 ZCZL.WANGYUNING UPDATE Start 0.3.000.000:新WizLIFE２次開発           
                --MJIDO_WORK(ICNT).SHOGAKO_KU_CD := ISHOGAKU_CD;
                --MJIDO_WORK(ICNT).TYUGAKO_KU_CD := ICHUGAKU_CD;
                MJIDO_WORK(ICNT).SHOGAKO_KU_CD := CRJIDO.SHOGAKU_CD;    --小学校区コード
                MJIDO_WORK(ICNT).TYUGAKO_KU_CD := CRJIDO.CHUGAKU_CD;    --中学校区コード
-- 2024/06/04 ZCZL.WANGYUNING UPDATE End
                MJIDO_WORK(ICNT).GYOSEI_KU_CD  := IGYOSEIKU_CD;
                ICNT := ICNT + 1;      -- カウントアップ
                IFRET := c_ISUCCESS;   -- 正常終了
              END IF;
            END LOOP;
        EXCEPTION
          WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 2);
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
        RAISE ERR;
      RETURN IFRET;
    END FUNC_GET_JIDO_WK;

    --------------------------------------------------------------------------------
    -- 成人者マスタ（GKBTSEIJINSHA）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_INSERT_JIDO_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        ICNT                BINARY_INTEGER;             -- 戻り値
        IMAX                BINARY_INTEGER;             -- 戻り値
        IMIN                BINARY_INTEGER;             -- 戻り値
        ISEIJINCNT          PLS_INTEGER;
        IMAX_SEIRI_NO       PLS_INTEGER;                --最大整理番号
        IINSERTCNT          PLS_INTEGER;                --INSERT件数
        bRTN              BOOLEAN;
    BEGIN
        IFRET := c_ISUCCESS;                  -- 正常終了
        -- ワーク領域の最終位置を取得
        IMAX := MJIDO_WORK.LAST;
        -- ワーク領域の先頭位置を取得
        IMIN := MJIDO_WORK.FIRST;
        IMAX_SEIRI_NO := 0;
        IINSERTCNT    := 0;

        BEGIN
            SELECT NVL(MAX(SEIRI_NO),0)
              INTO IMAX_SEIRI_NO
              FROM GKBTSEIJINSHA
             WHERE NENDO = INENDO;

            -- ワーク領域の件数分繰り返し処理を行う
            FOR ICNT IN IMIN..IMAX LOOP
              SELECT COUNT(KOJIN_CD)
                INTO ISEIJINCNT
                FROM GKBTSEIJINSHA
               WHERE NENDO = MJIDO_WORK(ICNT).NENDO
                 AND KOJIN_CD = MJIDO_WORK(ICNT).KOJIN_CD;

              IF ISEIJINCNT = 0 THEN

                IINSERTCNT := IINSERTCNT + 1;
                MJIDO_WORK(ICNT).SEIRI_NO := IMAX_SEIRI_NO + IINSERTCNT;

                INSERT INTO
                GKBTSEIJINSHA
                (
                 NENDO,
                 SEIRI_NO,
                 KOJIN_CD,
                 SHIMEI_KANA,
                 SHIMEI_KANJI,
                 SEINENGAPI,
                 SEIBETU,
                 TYUGAKO_KU,
                 GYOSEI_KU,
                 YUBIN_NO,
                 CHOMEI,
                 BANCHI,
                 KATAGAKI,
                 TEL_NO,
                 SYUKETSU_KBN,
                 SANTEIDANTAI_CD,
                 SYS_SAKUSEIBI,
                 SYS_KOSHINBI,
                 SYS_JIKAN,
                 SYS_SHOKUINKOJIN_NO,
                 SYS_TANMATU_NO,
                 SHOGAKO_KU,
                 SHOGAKO_KU_CD,
                 TYUGAKO_KU_CD,
                 GYOSEI_KU_CD
                )
                VALUES
                (
                  MJIDO_WORK(ICNT).NENDO,
                  MJIDO_WORK(ICNT).SEIRI_NO,
                  MJIDO_WORK(ICNT).KOJIN_CD,
                  MJIDO_WORK(ICNT).SHIMEI_KANA,
                  MJIDO_WORK(ICNT).SHIMEI_KANJI,
                  MJIDO_WORK(ICNT).SEINENGAPI,
                  MJIDO_WORK(ICNT).SEIBETU,
                  MJIDO_WORK(ICNT).TYUGAKO_KU,
                  MJIDO_WORK(ICNT).GYOSEI_KU,
                  MJIDO_WORK(ICNT).YUBIN_NO,
                  MJIDO_WORK(ICNT).CHOMEI,
                  MJIDO_WORK(ICNT).BANCHI,
                  MJIDO_WORK(ICNT).KATAGAKI,
                  MJIDO_WORK(ICNT).TEL_NO,
                  MJIDO_WORK(ICNT).SYUKETSU_KBN,
                  MJIDO_WORK(ICNT).SANTEIDANTAI_CD,
                  NSHORIBI,
                  0,
                  NSYSTIME,
                  g_sTANTOCODE,
                  g_sWSNUM,
                  MJIDO_WORK(ICNT).SHOGAKO_KU,
                  MJIDO_WORK(ICNT).SHOGAKO_KU_CD,
                  MJIDO_WORK(ICNT).TYUGAKO_KU_CD,
                  MJIDO_WORK(ICNT).GYOSEI_KU_CD
                 );
              END IF;
            END LOOP;
            commit;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;       -- 処理前に戻す
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := 'FUNC_INSERT_JIDO_WK:' || SUBSTR(SQLERRM, 1, 250);
                bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 2);
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
            RAISE ERR;
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B20UPDATE1
        RETURN BOOLEAN
    IS
        bRTN                          BOOLEAN;  --戻り値
        
    BEGIN
        g_nUPDLOGSEQ := g_nUPDLOGSEQ + 1;
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 2);

        --システム情報の取得
        NSHORIBI := TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'yyyymmdd'))); -- 処理日
        NSYSTIME := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS'));       -- システム時間（テーブル更新用）
        -- 取得した条件をそれぞれの変数へセット
        VNENDO := g_vJYOUKEN1;        -- 年度

        -- 基準日
        B_RTN := KKAPK0020.FDAYEDIT(g_vJYOUKEN2,
                         io_SEIREKIHIZUKE,
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
         V_KIJUNBI := ISEIREKIHIZUKE;   -- 基準日
         N_JUMIN_KIJUNBI := TO_NUMBER( V_KIJUNBI );

         --中学卒業時点の基準日
         io_SEIREKIHIZUKE := 0;
         IOWAREKIHIZUKE := 0;
         ISEIREKIHIZUKE := 0;
         N_CHUGAKU_KIJUNBI := TO_NUMBER(g_vJYOUKEN3);
         B_RTN := KKAPK0020.FDAYEDIT(N_CHUGAKU_KIJUNBI,
                       io_SEIREKIHIZUKE,
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
        IF B_RTN = TRUE THEN
          N_CHUGAKU_KIJUNBI := ISEIREKIHIZUKE;
        ELSE
          N_CHUGAKU_KIJUNBI := 0;
        END IF;

        --外国人抽出区分
        IF g_vJYOUKEN4 IS NOT NULL THEN
           IGAIKOKUJIN_HANTEI := TO_NUMBER(g_vJYOUKEN4);
        ELSE
           IGAIKOKUJIN_HANTEI := 0;
        END IF;
        --中学校以降に一度でも住民となった対象者の抽出区分
        ICHUSHUTSU_HANTEI := FUNC_GET_CHUSHUTSU_HANTEI;

        --既存データ削除区分（0:削除しない 1:削除する（再抽出））
        IF g_vJYOUKEN5 IS NOT NULL THEN
           ISAKUJO_KBN := TO_NUMBER(g_vJYOUKEN5);
           IF ISAKUJO_KBN NOT IN (0,1) THEN
              ISAKUJO_KBN := 0;
           END IF;
        ELSE
           ISAKUJO_KBN := 0;
        END IF;

        IF ISAKUJO_KBN = 1 THEN
          I_RTN := FUNC_INIT_SEIJINSYA( TO_NUMBER(VNENDO) );
        END IF;
        -- 成人者マスタ中間データ作成
        I_RTN := FUNC_GET_JIDO_WK;
        IF I_RTN <> c_ISUCCESS THEN
            IF I_RTN = c_INOTFOUND THEN
--  2024/04/22 ZCZL.WUCAO UPDATE START 0.2.000.001:512_GKB_00027対応
--                bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 1, '', '', c_VOK_MSG01 || '：対象データなし', g_sTANTOCODE, g_sWSNUM, 2);
               bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '更新処理', 0, '', '', c_VOK_MSG01 || '：対象データなし', g_sTANTOCODE, g_sWSNUM, 2);
               RETURN TRUE;
--  2024/04/22 ZCZL.WUCAO UPDATE END
            END IF;
            RETURN FALSE;
        END IF;

        -- 成人者マスタ作成
        I_RTN := FUNC_INSERT_JIDO_WK;
        IF I_RTN = c_INOT_SUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE ERR;
        END IF;

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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
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
    --  作成者／作成日: ZCZL.LUANSONGLIN 2024/01/02
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
END GKBPC00290;
/
