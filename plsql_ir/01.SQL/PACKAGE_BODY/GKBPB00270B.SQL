CREATE OR REPLACE PACKAGE BODY GKBPB00270
--1.0.402.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB(教育)
--  プログラム名  : 宛名ラベル（住記参照）
--  機能概要      : 住記を参照し児童生徒の宛名ラベル、宛名ラベル(住基参照)発送者一覧を作成する
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/06/12 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--  2024/08/05 ZCZL.wangqiwei Update 0.3.000.001:受入検証No.364の対応
--  2024/09/14 ZCZL.haodapeng Update 0.3.000.002:IT_GKB_00088の対応
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00429対応横展開
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
--  2025/05/15 ZCZL.LIYUWEI UPDATE 1.0.004.000:【学齢簿】宛名ラベル(住記参照)印字時、中学生の場合は「生徒氏名」と印字してほしい
--  2025/05/17 ZCZL.WANGMING UPDATE 1.0.004.000: GKB_QA14782(保守2194)_振り仮名部分は保護者氏名カナ対応
--  2025/12/01 CTC.HJF UPDATE 1.0.402.000: GKB_保守QA23236対応
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
-- 2024/06/11 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
    g_sSHIMEIJKN_CHOHYO  A_CONS_PRM; -- インデックス番号
    g_sEQSHIMEI   A_CONS_PRM;        --本名・通称名　出力制御
    g_sATENA      NVARCHAR2(100);    --宛名ラベル_出力制御
    g_nGKB010_INDEX   NUMBER;
    g_sKOJIN_NO       NVARCHAR2(100);
-- 2024/06/11 ZCZL.wangqiwei Add end

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --パラメータ変数
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- 処理結果
    c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    c_INOTFOUND    CONSTANT  PLS_INTEGER := -9;        -- 該当なし
    -- 戻り値
    c_IERR         CONSTANT  PLS_INTEGER := 1;         --異常
    c_BOK          CONSTANT  BOOLEAN := TRUE;          -- 正常
    -- エラーメッセージの値
    c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '宛名ラベル作成処理が異常終了しました。';
    -- 宛名マスタ
    c_VTABLE       CONSTANT  NVARCHAR2(128) := 'GKBWALABEL';
    -- １頁の最大行数
    c_IMAXROWS     CONSTANT  PLS_INTEGER := 15;
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    ISAKUSEIBI         PLS_INTEGER;
    RJIDO_ATENA        GABTATENAKIHON%ROWTYPE;
    RHOGO_ATENA        GABTATENAKIHON%ROWTYPE;
    RJIDO_SOFU         GABTSOFUSAKI%ROWTYPE;
    RHOGO_SOFU         GABTSOFUSAKI%ROWTYPE;
    RHOGO_ATENA_NULL   GABTATENAKIHON%ROWTYPE;
    RHOGO_SOFU_NULL    GABTSOFUSAKI%ROWTYPE;
    -- 処理条件（画面からの引数）
    VSTART             NVARCHAR2(15);     -- 開始生年月日
    VEND               NVARCHAR2(15);     -- 終了生年月日
    VGAKO_KBN          NVARCHAR2(15);     -- 学校区分（1：小学校、2：中学校
    IGAKO_KBN          NUMBER;            -- 学校区分（1：小学校、2：中学校）
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
    --VSYOGAKO_CD        NVARCHAR2(100);    --小学校コード
    --VCHUGAKU_CD        NVARCHAR2(100);    --中学校コード
    VSYOGAKO_CD        NVARCHAR2(3000);    --小学校コード
    VCHUGAKU_CD        NVARCHAR2(3000);    --中学校コード
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
    --  2024/09/14 ZCZL.haodapeng Update 0.3.000.002:IT_GKB_00088の対応
    --INUSHI_NO          PLS_INTEGER;
    INUSHI_NO          NUMBER;
    VNUSHI_NM          NVARCHAR2(100);
    VCNT               NVARCHAR2(6);
    IMAX               BINARY_INTEGER;
    ICNTM              BINARY_INTEGER :=0;             -- 宛名レコードカウント
    W_HOGOSHAKOJINNO   NUMBER;                    -- 保護者個人番号
    W_HOGOSHANM        NVARCHAR2(100);
    VJINKAKU_KBN       NUMBER;
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN               BOOLEAN;
    B_RTN              BOOLEAN;
    I_RTN              PLS_INTEGER;
    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWALABEL%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK         MTJIDO_TYPE;
    -- 宛名作成のレコード（GKBWALABEL_CSV）
    TYPE MTATENA_REC IS RECORD
    (
        KAIPEJI_CD            NVARCHAR2(500),
        YUBIN_NO              NVARCHAR2(10),
        CHOMEI                NVARCHAR2(40),
        BANCHI                NVARCHAR2(40),
        KATAGAKI              NVARCHAR2(60),
        NUSI_SHIMEI_KANJI     NVARCHAR2(110),
        ATENA_JODAN           NVARCHAR2(110),
        ATENA_GEDAN           NVARCHAR2(110),
        YUBIN_NOBC            NVARCHAR2(30),
        YUBIN_NO2             NVARCHAR2(10),
        CHOMEI2               NVARCHAR2(40),
        BANCHI2               NVARCHAR2(40),
        KATAGAKI2             NVARCHAR2(60),
        NUSI_SHIMEI_KANJI2    NVARCHAR2(110),
        ATENA_JODAN2          NVARCHAR2(110),
        ATENA_GEDAN2          NVARCHAR2(110),
        YUBIN_NOBC2           NVARCHAR2(30),
        JINKAKU_KBN           NUMBER(1)           --人格区分
    );
    MATENA_REC           MTATENA_REC;
    -- 処理条件の取得用変数
    g_VJYOUKEN01       NVARCHAR2(200);
    g_VJYOUKEN02       NVARCHAR2(200);
    g_VJYOUKEN03       NVARCHAR2(200);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応    
    --g_VJYOUKEN04       NVARCHAR2(200);
    --g_VJYOUKEN05       NVARCHAR2(200);
    g_VJYOUKEN04       NVARCHAR2(3000);
    g_VJYOUKEN05       NVARCHAR2(3000);
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
    o_NBREAK           NUMBER(2);
    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    ISEIREKI           PLS_INTEGER;
    IWAREKIHIZUKE      PLS_INTEGER;
    VEDIT_GYYMMDD1     NVARCHAR2(20);
    VEDIT_GYYMMDD2     NVARCHAR2(20);
    VEDIT_GYYMMDD3     NVARCHAR2(20);
    VKJ_GENGO          NVARCHAR2(20);
    VKG_GENGO          NVARCHAR2(20);
    IWAREKI_YY         PLS_INTEGER;
    ISEIREKI_YYYY      PLS_INTEGER;
    IWAREKI_GYYMM      PLS_INTEGER;
    IMM                PLS_INTEGER;
    IDD                PLS_INTEGER;
    ISEIREKIHIZUKE     PLS_INTEGER;
    VSQLERRM           NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
    VPAGENM            NVARCHAR2(500);    -- 改頁項目名
    VPAGEFD            NVARCHAR2(500);    -- 改頁項目値
    -- 宛名ラベルの氏名出力制御用変数(KKAPK0030.FPRMSHUTOKU)
    ACONSPRM_ATENA        A_CONS_PRM;
    NLENGTH               NUMBER;
    IRTN_ATENA            NUMBER;
    NSHORIBI              NUMBER;
    -- 旧自治体名称取得用変数(GAAPK0030.FJICHINAME)
    i_ISAN_CD  PLS_INTEGER;
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00429対応横展開
--    o_VSAN_KJ  NVARCHAR2(40);
    o_VSAN_KJ  GKBWALABEL.SANTEIDANTAIMEI%TYPE;
    IRTN1                  PLS_INTEGER;
    -- 行政区名取得用変数(GAAPK0030.FGYOSEIKUMEI)
    i_SANTEIDANTAI_CD  PLS_INTEGER;
    i_GYOSEIKU_CD      PLS_INTEGER;
    VGYOSEIKU_MEI      NVARCHAR2(100);
    -- 処理条件チェック用戻る値
    IRTN                  PLS_INTEGER;
    NSHIMEI_KANJI         NVARCHAR2(110);       --氏名漢字
    ACONSPRM_SHIMEI       A_CONS_PRM;
    NLENGTH1              NUMBER;
    IRTN_SHIMEI           NUMBER;
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        ARR DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
        objShogakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
        objChugakkoCd  DBMS_UTILITY.MAXNAME_ARRAY; 
--  2024/11/14 ZCZL.WANGYUNING ADD END
    BEGIN
        --開始生年月日 期間(開始)
        g_VJYOUKEN01 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSeinenGappiStart');
        --終了生年月日 期間(終了)
        g_vJYOUKEN02 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSeinenGappiEnd');
        --学校区分
        ARR := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGakkoKbn');
        g_VJYOUKEN03 := ARR(1);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
        --小学校コード
        --g_VJYOUKEN04 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShogakkoCd');
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtShogakkoCd');
        g_VJYOUKEN04 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShogakkoCd',0, objShogakkoCd);
        --中学校コード
        --g_VJYOUKEN05 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtChugakkoCd');
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtChugakkoCd');
        g_VJYOUKEN05 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtChugakkoCd',0, objChugakkoCd);
--  2024/11/14 ZCZL.WANGYUNING UPDATE END

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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
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
    --  機能概要      : 学校区分チェック
    --  パラメータ    : i_VKUBUN
    --  モジュール区分: 内部関数
    --  戻り値        : 0 正常,その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNCKUBUNCHK2( i_VKUBUN IN NVARCHAR2 ) RETURN NUMBER IS
      IRET PLS_INTEGER;
      KUBUN PLS_INTEGER;

    BEGIN
      IRET := 0;
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
        IF NOT ( KUBUN IN (1,2) ) THEN
          IRET := 1;
        END IF;
      END IF;

      RETURN(IRET);
    END;
    --------------------------------------------------------
    --  機能概要      : 日付の大小チェック
    --  パラメータ    : i_VHIDUKE1
    --             : i_VHIDUKE2
    --  モジュール区分: 内部関数
    --  戻り値        : 0 正常,その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNCHIKAKUCHK( i_VHIDUKE1 IN NVARCHAR2, i_VHIDUKE2 IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;

    BEGIN
      IRET := 0;
      --大小チェック
      IF i_VHIDUKE1 > i_VHIDUKE2 THEN
        IRET := 1;
      END IF;
      RETURN(IRET);
    END;
    --------------------------------------------------------
    --  機能概要      : 日付チェック
    --  パラメータ    : i_VHIZUKE
    --  モジュール区分: 内部関数
    --  戻り値        : 0 正常,その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    BRET BOOLEAN;
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

    BEGIN
      IRET := 0;
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

      RETURN(IRET);
    END;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
        VMSG NVARCHAR2(4000);
        IRTN PLS_INTEGER;
        ICHK1 PLS_INTEGER;
        ICHK2 PLS_INTEGER;
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
        aGAKKOCD_CHK_LST         KKBPK5551.tySPLIT_tbl;   --変数.学校リスト
        vGAKOUKBN          NUMBER;                  --学校から学校区別の取得
--  2024/11/14 ZCZL.WANGYUNING ADD END

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

        VMSG  := '';
        IRTN  := 0;
        ICHK1 := 0;
        ICHK2 := 0;

        --抽出開始生年月日のチェック
        IRTN := FUNCHIZUKECHK( g_VJYOUKEN01 );
        IF IRTN <> 0 THEN
          ICHK1 := 1;
          VMSG := g_sGYOUMUCODE || ',99999,抽出開始生年月日が正しくありません。,;';
        END IF;

        --抽出終了生年月日のチェック
        IRTN := FUNCHIZUKECHK( g_VJYOUKEN02 );
        IF IRTN <> 0 THEN
          ICHK2 := 1;
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,抽出終了生年月日が正しくありません。,;';
        END IF;

        --抽出開始生年月日と抽出終了生年月日の大小チェックを行う。
        IF ICHK1 = 0 AND ICHK2 = 0 THEN
          IRTN := FUNCHIKAKUCHK( g_VJYOUKEN01, g_VJYOUKEN02 );
          IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,開始生年月日と終了生年月日の大小関係が誤っています。,;';
          END IF;
        END IF;

        --学校区分のチェック
        IRTN := FUNCKUBUNCHK2( g_VJYOUKEN03 );
        IF IRTN <> 0 THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,学校区分が正しくありません。,;';
        END IF;

--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
       -- --小学校コードのチェック
       --IRTN := GKBPK00010.FGCODCHK( g_VJYOUKEN04 );
       -- IF IRTN <> 0 THEN
       --     VMSG := VMSG || g_sGYOUMUCODE || ',99999,小学校コードが正しくありません。,;';
       -- END IF;


       -- --中学校コードのチェック
       -- IRTN := GKBPK00010.FGCODCHK( g_VJYOUKEN05 );
       -- IF IRTN <> 0 THEN
       --     VMSG := VMSG || g_sGYOUMUCODE || ',99999,中学校コードが正しくありません。,;';
       -- END IF;

        --学校区分と小学校コードの関連チェック
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_VJYOUKEN04, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            --学校区分と選択された学校の関係性チェック
            IF g_VJYOUKEN03 <> '0' THEN
              IF TO_NUMBER(g_VJYOUKEN03) <> vGAKOUKBN THEN
                IF VMSG IS NOT NULL THEN
                  VMSG := VMSG || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                ELSE
                  VMSG := VMSG || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                END IF;
              END IF;
            END IF;
        END LOOP;
        --学校区分と中学校コードの関連チェック
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_VJYOUKEN05, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            --学校区分と選択された学校の関係性チェック
            IF g_VJYOUKEN03 <> '0' THEN
              IF TO_NUMBER(g_VJYOUKEN03) <> vGAKOUKBN THEN
                IF VMSG IS NOT NULL THEN
                  VMSG := VMSG || ';' || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                ELSE
                  VMSG := VMSG || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                END IF;
              END IF;
            END IF;
        END LOOP;
--  2024/11/14 ZCZL.WANGYUNING UPDATE END

        o_vRESULT := VMSG;

    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
    --------------------------------------------------------
    --  機能概要      : 処理ログ出力
    --  パラメータ      : i_sGAKOCD       編集前学校コード
    --              : o_sGAKOCD       編集後学校コード
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.001
    --  作成者／作成日: ZCZL.WANGQIWEI   2024/08/02
    --------------------------------------------------------
-- 2024/08/05 ZCZL.wangqiwei Add start 0.3.000.001:受入検証No.364の対応
    FUNCTION FUNC_GET_GAKOCD(i_sGAKOCD IN NVARCHAR2, o_sGAKOCD OUT NVARCHAR2) RETURN BOOLEAN
    IS
        aGAKOCD           KKBPK5551.tySPLIT_tbl;      -- 業務コード（リスト）
--  2024/11/14 ZCZL.WANGYUNING ADD 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
        nGAKOUCD_TMP  NUMBER; --学校コード
    BEGIN
        -- 入力引数を分解して配列にセットする
        -- 引数の業務コード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.004:学校コードリスト仕様変更IT_GKB_00090の対応
        ---- 処理ステップを取得
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
        o_sGAKOCD := '';
        FOR i IN 1..aGAKOCD.COUNT LOOP
            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
            IF nGAKOUCD_TMP IS NOT NULL THEN
                IF i = aGAKOCD.COUNT THEN
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP ;
                ELSE
                    o_sGAKOCD := o_sGAKOCD || nGAKOUCD_TMP || ',';
                END IF;
            END IF;
        END LOOP;
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_GET_GAKOCD;
-- 2024/08/05 ZCZL.wangqiwei Add end
    --------------------------------------------------------
    --  機能概要      : バッチジョブステップテーブルの更新処理
    --  パラメータ    : i_UPD_KBN       更新区分
    --                : i_STEPRTNCODE   実行結果コード
    --                : i_CSV_RCNT      CSV出力件数
    --                : i_CSVFILENAME   CSVファイル名
    --                : i_PRTFILENAME   出力ファイル名
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
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
    --  機能概要      : 日付変換
    --  パラメータ    : i_IDATE
    --             : I_ICONV_TYPE
    --  モジュール区分: 内部関数
    --  戻り値        : 日付
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNC_CONV_DATE(i_IDATE IN PLS_INTEGER, I_ICONV_TYPE IN PLS_INTEGER)
        RETURN NVARCHAR2
    IS
        V_FRET    NVARCHAR2(16);
        B_WKRTN   BOOLEAN;
        -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
        io_IWAREKIHIZUKE  PLS_INTEGER;
        io_ISEIREKIHIZUKE PLS_INTEGER;
        o_VEDIT_GYYMMDD1  NVARCHAR2(9);
        o_VEDIT_GYYMMDD2  NVARCHAR2(9);
        o_VEDIT_GYYMMDD3  NVARCHAR2(11);
        o_VKJ_GENGO       NVARCHAR2(2);
        o_VKG_GENGO       NVARCHAR2(1);
        o_IWAREKI_YY      PLS_INTEGER;
        o_ISEIREKI_YYYY   PLS_INTEGER;
        o_IWAREKI_GYYMM   PLS_INTEGER;
        o_IMM             PLS_INTEGER;
        o_IDD             PLS_INTEGER;
        o_IWAREKIHIZUKE   PLS_INTEGER;
        o_ISEIREKIHIZUKE  PLS_INTEGER;
    BEGIN
        V_FRET := NULL;
        BEGIN
          IF i_IDATE >= 10000000 THEN
            io_IWAREKIHIZUKE  := 0;
            io_ISEIREKIHIZUKE := i_IDATE;
          ELSE
            io_IWAREKIHIZUKE  := i_IDATE;
            io_ISEIREKIHIZUKE := 0;
          END IF;
          --日付変換
          B_WKRTN := KKAPK0020.FDAYEDIT(io_IWAREKIHIZUKE, io_ISEIREKIHIZUKE,
                                         o_VEDIT_GYYMMDD1, o_VEDIT_GYYMMDD2, o_VEDIT_GYYMMDD3,
                                         o_VKJ_GENGO, o_VKG_GENGO,
                                         o_IWAREKI_YY, o_ISEIREKI_YYYY, o_IWAREKI_GYYMM,
                                         o_IMM, o_IDD, o_IWAREKIHIZUKE, o_ISEIREKIHIZUKE);
          IF B_WKRTN = c_BOK THEN
            CASE I_ICONV_TYPE
              WHEN 0 THEN
                V_FRET := RTRIM(LTRIM(TO_CHAR(o_ISEIREKIHIZUKE)));
              WHEN 1 THEN
                V_FRET := o_VEDIT_GYYMMDD1;
              WHEN 2 THEN
                V_FRET := o_VEDIT_GYYMMDD2;
              WHEN 3 THEN
                V_FRET := o_VEDIT_GYYMMDD3;
              ELSE
                NULL;
            END CASE;
          END IF;
        END;
        RETURN V_FRET;
    END FUNC_CONV_DATE;
    --------------------------------------------------------
    --  機能概要      : 氏名印字制御ﾊﾟﾗﾒｰﾀの設定の編集
    --  パラメータ    : NSEIGYO_IN_FLG 制御ﾊﾟﾗﾒｰﾀ
    --            :  NKANRI_FLG
    --            :  VSHIMEI_DATA
    --            :  VHONMYO_DATA
    --  モジュール区分: 内部関数
    --  戻り値        : データ編集用　1 本名　３　管理模型で編集（氏名かな/氏名漢字） ２　管理模型で編集（本名かな/本名漢字）
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNC_SET_SEIGYO (NSEIGYO_IN_FLG IN NUMBER , NKANRI_FLG IN NUMBER ,
                              VSHIMEI_DATA IN NVARCHAR2 , VHONMYO_DATA IN NVARCHAR2)
      RETURN NVARCHAR2 IS
      NSEIGYO_OUT_FLG   NUMBER := 0;
      VRETURN           NVARCHAR2(1000);
    BEGIN
     NSEIGYO_OUT_FLG := 0;
      IF NSEIGYO_IN_FLG IS NULL OR NSEIGYO_IN_FLG = 0 THEN
        NSEIGYO_OUT_FLG := 4;
        GOTO  SHORI;
      END IF;
      IF NSEIGYO_IN_FLG = 1 THEN
       NSEIGYO_OUT_FLG := 1;
      ELSIF NSEIGYO_IN_FLG = 4 AND NVL(NKANRI_FLG,0) = 0 THEN
       NSEIGYO_OUT_FLG := 1;
      ELSIF NSEIGYO_IN_FLG = 6 AND NVL(NKANRI_FLG,0) = 0 THEN
       NSEIGYO_OUT_FLG := 1;
      ELSIF NSEIGYO_IN_FLG = 3 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 4 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 5 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 6 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSE
        NSEIGYO_OUT_FLG := 4;
      END IF;
       <<SHORI>>
      IF NSEIGYO_OUT_FLG = 1 THEN
        IF  VHONMYO_DATA IS NOT NULL THEN
           VRETURN := VHONMYO_DATA;
        ELSE
           VRETURN := VSHIMEI_DATA;
        END IF;
      ELSIF NSEIGYO_OUT_FLG = 2 THEN
        IF  VHONMYO_DATA  IS NOT NULL THEN
           VRETURN := VHONMYO_DATA;
        ELSE
           VRETURN := VSHIMEI_DATA;
        END IF;
      ELSIF NSEIGYO_OUT_FLG = 3 THEN
        IF  VSHIMEI_DATA IS NOT NULL THEN
           VRETURN := VSHIMEI_DATA;
        ELSE
           VRETURN := VHONMYO_DATA;
        END IF;
      ELSE
        IF  VSHIMEI_DATA IS NOT NULL THEN
           VRETURN := VSHIMEI_DATA;
        ELSE
           VRETURN := VHONMYO_DATA;
        END IF;
      END IF;
      RETURN VRETURN;
    END FUNC_SET_SEIGYO;
    --------------------------------------------------------
    --  機能概要      : 生年月日の編集
    --  パラメータ    : NSEIGYO_IN_FLG 制御ﾊﾟﾗﾒｰﾀ
    --            :  NKANRI_FLG
    --  モジュール区分: 内部関数
    --  戻り値        : 生年月日
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNC_SET_SEIGYO_SEINENGAPI (NSEIGYO_IN_FLG IN NUMBER , NKANRI_FLG IN NUMBER)
      RETURN NVARCHAR2 IS
      NSEIGYO_OUT_FLG   NUMBER := 0;
      VRETURN           NVARCHAR2(1000);
    BEGIN
    --データ編集用　1 データなし　３　西暦 　２　和暦
     NSEIGYO_OUT_FLG := 0;
      IF NSEIGYO_IN_FLG IS NULL OR NSEIGYO_IN_FLG = 0 THEN
        NSEIGYO_OUT_FLG := 4;
        GOTO  SHORI;
      END IF;
      IF NSEIGYO_IN_FLG = 4 AND NVL(NKANRI_FLG,0) = 0 THEN
       NSEIGYO_OUT_FLG := 1;
      ELSIF NSEIGYO_IN_FLG = 5 AND NVL(NKANRI_FLG,0) = 0 THEN
       NSEIGYO_OUT_FLG := 1;
      ELSIF NSEIGYO_IN_FLG = 3 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (22) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 4 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (22) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 5 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (22) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 6 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSIF NKANRI_FLG IN (22) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSE
         NSEIGYO_OUT_FLG := 4;
       END IF;
      ELSE
        NSEIGYO_OUT_FLG := 4;
      END IF;
       <<SHORI>>
      IF NSEIGYO_OUT_FLG = 1 THEN
       VRETURN := '1';
      ELSIF NSEIGYO_OUT_FLG = 2 THEN
       VRETURN := '0';
      ELSIF NSEIGYO_OUT_FLG = 3 THEN
       VRETURN := '1';
      ELSE
       VRETURN := '0';
      END IF;
      RETURN VRETURN;
    END FUNC_SET_SEIGYO_SEINENGAPI;
    --------------------------------------------------------
    --  機能概要      : 宛名ラベルワーク中間（GKBWALABEL）レコードの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        IFRET                PLS_INTEGER;                -- 戻り値
        ISTART               PLS_INTEGER;                -- 開始生年月日
        IEND                 PLS_INTEGER;                -- 終了生年月日
        ICNT                 BINARY_INTEGER;             -- 戻り値
        VSQLSEL              VARCHAR2(2000);
        IRTN                 PLS_INTEGER;
        IRET                 PLS_INTEGER;
        KOJIN_NO             GABTATENAKIHON.KOJIN_NO%TYPE;
        VGAKOMEI             NVARCHAR2(60);    ----学校名   -- 50->60
        VKON_JUSHO           NVARCHAR2(140);   ----住所
        VKON_JUSHO_JODAN     NVARCHAR2(20);    ----住所上段
        VKON_JUSHO_GEDAN     NVARCHAR2(120);   ----住所下段
        N_NAIYO_CD_JIDO      GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;
        N_INUSHI_JINGAKU     NUMBER := 0;
        VEDIT_GO_DATA        NVARCHAR2(1000) := '';
        RA                   GABTATENAKIHON%ROWTYPE;
        RASO                 GABTSOFUSAKI%ROWTYPE;
        NKOJIN_NO            NUMBER := 0;
        TYPE TYPECURSOR      IS REF CURSOR;
        CRATENA              TYPECURSOR;
-- 2024/06/12 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
        o_sSHIMEIKANA              NVARCHAR2(1000);  --氏名カナ
        o_sSHIMEI                  NVARCHAR2(1000);  --氏名漢字
        o_sBIRTHDAY                NVARCHAR2(1000);  --生年月日
        o_JIDO_SHIMEI_JODAN        NVARCHAR2(1000);  --児童氏名上段
        o_JIDO_SHIMEI_GEDAN        NVARCHAR2(1000);  --児童氏名下段
        o_HYOJI_SEINENGAPI         NVARCHAR2(1000);  --表示生年月日
--  2025/05/17 ZCZL.WANGMING DELETE 1.0.004.000: GKB_QA14782(保守2194)_振り仮名部分は保護者氏名カナ対応
--        o_HOGOSHA_SHIMEI_JODAN     NVARCHAR2(1000);  --保護者氏名上段
-- 2024/06/12 ZCZL.wangqiwei Add end
    BEGIN
        IFRET  := c_INOTFOUND;                           -- 該当なし
        ISTART := FUNC_CONV_DATE(TO_NUMBER(VSTART), 0);  -- 抽出開始生年月日
        IEND   := FUNC_CONV_DATE(TO_NUMBER(VEND), 0);    -- 抽出終了生年月日
        --処理条件変更のため、削除された条件を削除する
        IGAKO_KBN := TO_NUMBER(VGAKO_KBN);               -- 学校区分（1：小学校、2：中学校
        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        ICNT := 0;
        BEGIN
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'KOJIN_NO ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GABTATENAKIHON ';
            VSQLSEL := VSQLSEL || 'WHERE  ';
            VSQLSEL := VSQLSEL || 'GENZON_KBN = 0 ';
            VSQLSEL := VSQLSEL || 'AND (SEINENGAPI BETWEEN '|| ISTART || ' AND '|| IEND ||')';
           IF VSYOGAKO_CD IS NOT NULL AND IGAKO_KBN = 1 THEN
               VSQLSEL := VSQLSEL || ' AND SHOGAKU_CD IN (' || VSYOGAKO_CD || ') ';
            END IF;
           IF VCHUGAKU_CD IS NOT NULL AND IGAKO_KBN = 2 THEN
               VSQLSEL := VSQLSEL || ' AND CHUGAKU_CD IN (' || VCHUGAKU_CD || ') ';
           END IF;
           OPEN CRATENA  FOR VSQLSEL;
           LOOP
              FETCH  CRATENA INTO KOJIN_NO;
                EXIT WHEN CRATENA%NOTFOUND;
-- 2024/06/12 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
        --児童生徒の本名使用制御判定
        IF GKBFKHMCTRL(KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_sATENA, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY)= 0 THEN
          o_JIDO_SHIMEI_JODAN := o_sSHIMEIKANA; --児童氏名上段
          o_JIDO_SHIMEI_GEDAN := o_sSHIMEI;     --児童氏名下段
--  2025/12/01 CTC.HJF UPDATE START 1.0.402.000: GKB_保守QA23236対応
          --o_HYOJI_SEINENGAPI  := o_sBIRTHDAY;   --表示生年月日
         ISEIREKIHIZUKE := RJIDO_ATENA.SEINENGAPI;
         IWAREKIHIZUKE := NULL;
         BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                           VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                           VEDIT_GYYMMDD3, VKJ_GENGO,
                           VKG_GENGO,      IWAREKI_YY,
                           ISEIREKI_YYYY,  IWAREKI_GYYMM,
                           IMM,            IDD,
                           IWAREKIHIZUKE,  ISEIREKIHIZUKE );
         IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
          IF FUNC_SET_SEIGYO_SEINENGAPI(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO) = 1 THEN
             IF ISEIREKIHIZUKE <> 0 THEN
               MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := TO_CHAR(TO_DATE(ISEIREKIHIZUKE,'YYYYMMDD'),'YYYY.MM.DD');
             ELSE
               MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := '';
             END IF;
           ELSE
             MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VEDIT_GYYMMDD1;
           END IF;
         ELSE
           MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VEDIT_GYYMMDD1;
         END IF;
--  2025/12/01 CTC.HJF UPDATE END
        END IF;
--  2025/05/17 ZCZL.WANGMING DELETE START 1.0.004.000: GKB_QA14782(保守2194)_振り仮名部分は保護者氏名カナ対応
--        IF GKBFKHMCTRL(KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_sATENA, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN
--          o_HOGOSHA_SHIMEI_JODAN := o_sSHIMEI;  --保護者氏名上段
--        END IF;
--  2025/05/17 ZCZL.WANGMING DELETE END
-- 2024/06/12 ZCZL.wangqiwei Add end
              VCNT :=  TO_CHAR(ICNT);
              -- 児童生徒個人番号より宛名情報取得
              IRTN := GAAPK0030.FGETATENA( KOJIN_NO,
                                         g_sGYOUMUCODE,
                                         ISAKUSEIBI,
                                         RJIDO_ATENA,
                                         RJIDO_SOFU );
              IF IRTN <> c_ISUCCESS THEN
                -- 児童宛名情報取得エラー
                IFRET := c_INOT_SUCCESS;
                EXIT;
              END IF;
              --児童の個人番号、作成日を元に保護者個人番号を取得する
             VJINKAKU_KBN := RJIDO_ATENA.JINKAKU_KBN;
             IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
                      IRTN := GKBPK00010.FGKJHGS(ISAKUSEIBI,
                                           KOJIN_NO,
                                           W_HOGOSHAKOJINNO,
                                           W_HOGOSHANM);
                    IF IRTN <> c_ISUCCESS THEN
                        -- 保護者個人番号が取得できなかった場合
                        W_HOGOSHAKOJINNO := 0;
                    END IF;
             ELSE
                      IRTN := GKBPK00010.FHOGOSHA( ISAKUSEIBI,
                                           KOJIN_NO,
                                           W_HOGOSHAKOJINNO );
                    IF IRTN <> c_ISUCCESS THEN
                        -- 保護者個人番号が取得できなかった場合
                        W_HOGOSHAKOJINNO := 0;
                    END IF;
              END IF;
              --保護者の宛名情報を取得する
              IF W_HOGOSHAKOJINNO <> 0 THEN
                IRTN := GAAPK0030.FGETATENA( W_HOGOSHAKOJINNO,
                                           g_sGYOUMUCODE,
                                           ISAKUSEIBI,
                                           RHOGO_ATENA,
                                           RHOGO_SOFU );
              END IF;
              -- 保護者の情報が取得できなかった場合
              IF W_HOGOSHAKOJINNO = 0 OR IRTN <> c_ISUCCESS THEN
                RHOGO_ATENA := RHOGO_ATENA_NULL;
                RHOGO_SOFU  := RHOGO_SOFU_NULL;
                RHOGO_ATENA.KOJIN_NO := 0;
                RHOGO_ATENA.SHIMEI_KANA := '';
                RHOGO_ATENA.SHIMEI_KANJI := '';
                RHOGO_ATENA.YUBIN_NO := '';
                RHOGO_ATENA.YUBIN_NOBC := '';
                RHOGO_ATENA.CHOMEI := '';
                RHOGO_ATENA.BANCHI := '';
                RHOGO_ATENA.KATAGAKI := '';
                RHOGO_ATENA.YUHEN_KBN := 0;
                RHOGO_ATENA.OAZA_CD := 0;
                RHOGO_ATENA.HONBAN := '';
                RHOGO_ATENA.EDABAN1 := '';
                RHOGO_ATENA.EDABAN2 := '';
                RHOGO_ATENA.EDABAN3 := '';
                RHOGO_ATENA.GAIKU := '';
                RHOGO_ATENA.TOU := '';
                RHOGO_ATENA.GOU := '';
              END IF;
            --保護者宛のとき
             --宛名ラベルの氏名の出力制御
              IF NOT(ACONSPRM_ATENA(1) IN (1,3)) THEN
             --保護者が判定できたとき
                 IF W_HOGOSHAKOJINNO <> 0 THEN
                   -- 保護者個人番号から世帯主情報を取得
                   IRET := JIAPK0030.FGETNUSHI(ISAKUSEIBI, W_HOGOSHAKOJINNO, INUSHI_NO, VNUSHI_NM);
                   IF IRET <> c_ISUCCESS THEN
                      INUSHI_NO := '0';
                      VNUSHI_NM := '';
                   END IF;
                 --保護者が判定できなかったときは世帯主の宛名を取得する
                 ELSE
                   -- 児童生徒個人番号から世帯主情報を取得
                   IRET := JIAPK0030.FGETNUSHI(ISAKUSEIBI, KOJIN_NO, INUSHI_NO, VNUSHI_NM);
                   IF IRET <> c_ISUCCESS THEN
                      INUSHI_NO := '0';
                      VNUSHI_NM := '';
                   ELSE
                      --世帯主が判定できたときは保護者の住所に上書きして宛名を取得
                      IRTN := GAAPK0030.FGETATENA( INUSHI_NO,
                                                 g_sGYOUMUCODE,
                                                 ISAKUSEIBI,
                                                 RHOGO_ATENA,
                                                 RHOGO_SOFU );
                      IF INUSHI_NO = 0 OR IRTN <> c_ISUCCESS THEN
                          RHOGO_ATENA := RHOGO_ATENA_NULL;
                          RHOGO_SOFU  := RHOGO_SOFU_NULL;
                          VNUSHI_NM   := NULL;
                          RHOGO_ATENA.KOJIN_NO := 0;
                          RHOGO_ATENA.SHIMEI_KANA := '';
                          RHOGO_ATENA.SHIMEI_KANJI := '';
                          RHOGO_ATENA.YUBIN_NO := '';
                          RHOGO_ATENA.YUBIN_NOBC := '';
                          RHOGO_ATENA.CHOMEI := '';
                          RHOGO_ATENA.BANCHI := '';
                          RHOGO_ATENA.KATAGAKI := '';
                          RHOGO_ATENA.YUHEN_KBN := 0;
                          RHOGO_ATENA.OAZA_CD := 0;
                          RHOGO_ATENA.HONBAN := '';
                          RHOGO_ATENA.EDABAN1 := '';
                          RHOGO_ATENA.EDABAN2 := '';
                          RHOGO_ATENA.EDABAN3 := '';
                          RHOGO_ATENA.GAIKU := '';
                          RHOGO_ATENA.TOU := '';
                          RHOGO_ATENA.GOU := '';
                      END IF;
                   END IF;
                END IF;
           --児童宛のとき
              ELSE
                 -- 児童生徒個人番号から世帯主情報を取得
                 IRET := JIAPK0030.FGETNUSHI(ISAKUSEIBI, KOJIN_NO, INUSHI_NO, VNUSHI_NM);
                 IF IRET <> c_ISUCCESS THEN
                    INUSHI_NO := '0';
                    VNUSHI_NM := '';
                 END IF;
              END IF;
              --児童の制御情報を取得
              BEGIN
                 NKOJIN_NO := KOJIN_NO;
                 SELECT NAIYO_CD INTO N_NAIYO_CD_JIDO FROM GKBTSHIMEIJKN
                   WHERE KOJIN_NO = NKOJIN_NO AND CHOHYO_ID = 'GKB230R001';
              EXCEPTION
                  WHEN OTHERS THEN
                    N_NAIYO_CD_JIDO := 0;
              END;
                   --世帯主KOJIN_NOで人格区分を取得
              BEGIN
                    IRTN := GAAPK0030.FGETATENA(INUSHI_NO,
                                              g_sGYOUMUCODE,
                                              ISAKUSEIBI,
                                              RA,
                                              RASO);
                    N_INUSHI_JINGAKU := RA.JINKAKU_KBN;
              EXCEPTION
              WHEN OTHERS THEN
               NULL;
              END;
              IF IGAKO_KBN = 1 THEN          -- 小学校分
                MJIDO_WORK(ICNT).GAKO_CD             := RJIDO_ATENA.SHOGAKU_CD;
              ELSIF IGAKO_KBN = 2 THEN       -- 中学校分
                MJIDO_WORK(ICNT).GAKO_CD             := RJIDO_ATENA.CHUGAKU_CD;
              END IF;
              MJIDO_WORK(ICNT).GYOSEIKU_CD         := RJIDO_ATENA.GYOSEIKU_CD;
              MJIDO_WORK(ICNT).HAN_CD              := RJIDO_ATENA.HAN_CD;
              MJIDO_WORK(ICNT).SANTEIDANTAI_CD     := RJIDO_ATENA.SANTEIDANTAI_CD;
              MJIDO_WORK(ICNT).SHIMEI_KANA         := RJIDO_ATENA.SHIMEI_KANA;
              MJIDO_WORK(ICNT).SEINENGAPI          := RJIDO_ATENA.SEINENGAPI;
              MJIDO_WORK(ICNT).SEIBETSU            := RJIDO_ATENA.SEIBETSU;
              MJIDO_WORK(ICNT).SETAI_NO            := RJIDO_ATENA.SETAI_NO;

             IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
               VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                      TRIM(RHOGO_ATENA.SHIMEI_KANA),TRIM(RHOGO_ATENA.HONMYO_KANA));
               MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA  := VEDIT_GO_DATA;
             ELSE
              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RHOGO_ATENA.SHIMEI_KANA;
             END IF;
              --児童宛のとき
              IF ACONSPRM_ATENA(1) IN (1,3) THEN
                      IF RJIDO_SOFU.KOJIN_NO > 0 AND
                         (RJIDO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND
                         (RJIDO_SOFU.SHURYO_BI >= ISAKUSEIBI OR
                         RJIDO_SOFU.SHURYO_BI = 0) THEN
                         IF RJIDO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
                            NSHIMEI_KANJI := RJIDO_SOFU.SHIMEI_KANJI;
                         ELSE
                          IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
                            VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                             TRIM(RJIDO_ATENA.SHIMEI_KANJI),TRIM(RJIDO_ATENA.HONMYO_KANJI));
                            NSHIMEI_KANJI  := VEDIT_GO_DATA;
                          ELSE
                            NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
                          END IF;
                         END IF;
                      ELSE
                        IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
                          VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                             TRIM(RJIDO_ATENA.SHIMEI_KANJI),TRIM(RJIDO_ATENA.HONMYO_KANJI));
                          NSHIMEI_KANJI  := VEDIT_GO_DATA;
                        ELSE
                          NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
                        END IF;
                      END IF;
                --送付先住所の設定があるとき
                  IF RJIDO_SOFU.KOJIN_NO > 0 THEN
                      IF RJIDO_SOFU.YUBIN_NO IS NOT NULL THEN
                         MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(RJIDO_SOFU.YUBIN_NO,1,3)||'-'||SUBSTR(RJIDO_SOFU.YUBIN_NO,4);
                      ELSE
                         MJIDO_WORK(ICNT).YUBIN_NO := NULL;
                      END IF;
                         MJIDO_WORK(ICNT).YUBIN_NOBC := RJIDO_SOFU.YUBIN_NOBC;
                         MJIDO_WORK(ICNT).CHOMEI   := RJIDO_SOFU.CHOMEI;
                         MJIDO_WORK(ICNT).BANCHI   := RJIDO_SOFU.BANCHI;
                         MJIDO_WORK(ICNT).KATAGAKI := RJIDO_SOFU.KATAGAKI;
                  ELSE
                      IF RJIDO_ATENA.YUBIN_NO IS NOT NULL THEN
                         MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(RJIDO_ATENA.YUBIN_NO,1,3)||'-'||SUBSTR(RJIDO_ATENA.YUBIN_NO,4);
                      ELSE
                         MJIDO_WORK(ICNT).YUBIN_NO := NULL;
                      END IF;
                         MJIDO_WORK(ICNT).YUBIN_NOBC := RJIDO_ATENA.YUBIN_NOBC;
                         MJIDO_WORK(ICNT).CHOMEI   := RJIDO_ATENA.CHOMEI;
                         MJIDO_WORK(ICNT).BANCHI   := RJIDO_ATENA.BANCHI;
                         MJIDO_WORK(ICNT).KATAGAKI := RJIDO_ATENA.KATAGAKI;
                  END IF;
                  IF LENGTH(VNUSHI_NM) > 0 AND ACONSPRM_ATENA(4) = 1 THEN
                       IF N_INUSHI_JINGAKU = 1 THEN
                          VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                        TRIM(RA.SHIMEI_KANJI),TRIM(RA.HONMYO_KANJI));
                          VNUSHI_NM  := VEDIT_GO_DATA;
                       END IF;
                       MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI:= VNUSHI_NM||'　様方';
                  ELSE
                      MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI := NULL;
                  END IF;
                  IF LENGTH(NSHIMEI_KANJI) > 0 THEN
                      IF  ACONSPRM_ATENA(3) = 1 THEN
                        MJIDO_WORK(ICNT).ATENA_JODAN := ' ('|| NSHIMEI_KANJI ||'　様 ) ';
                      ELSE
                        MJIDO_WORK(ICNT).ATENA_JODAN := NSHIMEI_KANJI||'　様 ';
                      END IF;
                 ELSE
                   MJIDO_WORK(ICNT).ATENA_JODAN := NULL;
                 END IF;
              --保護者宛のとき
            ELSE
                  IF (RHOGO_SOFU.KOJIN_NO IS NOT NULL)
                         AND (RHOGO_SOFU.TEKIYO_BI <= ISAKUSEIBI)
                         AND (RHOGO_SOFU.SHURYO_BI >= ISAKUSEIBI
                         OR RHOGO_SOFU.SHURYO_BI = 0) THEN
                         IF RHOGO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
                            NSHIMEI_KANJI := RHOGO_SOFU.SHIMEI_KANJI;
                         ELSE
                          IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
                            VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                               TRIM(RHOGO_ATENA.SHIMEI_KANJI),TRIM(RHOGO_ATENA.HONMYO_KANJI));
                            NSHIMEI_KANJI  := VEDIT_GO_DATA;
                          ELSE
                            NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
                          END IF;
                         END IF;
                      ELSE
                          IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
                            VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                               TRIM(RHOGO_ATENA.SHIMEI_KANJI),TRIM(RHOGO_ATENA.HONMYO_KANJI));
                            NSHIMEI_KANJI  := VEDIT_GO_DATA;
                          ELSE
                            NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
                          END IF;
                      END IF;
                --送付先住所の設定があるとき
                IF RHOGO_SOFU.KOJIN_NO > 0 THEN
                    IF RHOGO_SOFU.YUBIN_NO IS NOT NULL THEN
                       MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(RHOGO_SOFU.YUBIN_NO,1,3)||'-'||SUBSTR(RHOGO_SOFU.YUBIN_NO,4);
                    ELSE
                       MJIDO_WORK(ICNT).YUBIN_NO := NULL;
                    END IF;
                       MJIDO_WORK(ICNT).YUBIN_NOBC := RHOGO_SOFU.YUBIN_NOBC;
                       MJIDO_WORK(ICNT).CHOMEI   := RHOGO_SOFU.CHOMEI;
                       MJIDO_WORK(ICNT).BANCHI   := RHOGO_SOFU.BANCHI;
                       MJIDO_WORK(ICNT).KATAGAKI := RHOGO_SOFU.KATAGAKI;
                ELSE
                    IF RHOGO_ATENA.YUBIN_NO IS NOT NULL THEN
                       MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(RHOGO_ATENA.YUBIN_NO,1,3)||'-'||SUBSTR(RHOGO_ATENA.YUBIN_NO,4);
                    ELSE
                       MJIDO_WORK(ICNT).YUBIN_NO := NULL;
                    END IF;
                       MJIDO_WORK(ICNT).YUBIN_NOBC := RHOGO_ATENA.YUBIN_NOBC;
                       MJIDO_WORK(ICNT).CHOMEI   := RHOGO_ATENA.CHOMEI;
                       MJIDO_WORK(ICNT).BANCHI   := RHOGO_ATENA.BANCHI;
                       MJIDO_WORK(ICNT).KATAGAKI := RHOGO_ATENA.KATAGAKI;
                END IF;
                --世帯主名のセット
                IF W_HOGOSHAKOJINNO = INUSHI_NO THEN
                  MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI:= '';
                ELSE
                  IF LENGTH(VNUSHI_NM) > 0 AND ACONSPRM_ATENA(4) = 1 THEN
                     IF N_INUSHI_JINGAKU = 1 THEN
                        VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                        TRIM(RA.SHIMEI_KANJI),TRIM(RA.HONMYO_KANJI));
                        VNUSHI_NM  := VEDIT_GO_DATA;
                     END IF;
                     MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI:= VNUSHI_NM||'　様方';
                  ELSE
                     MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI := NULL;
                  END IF;
                END IF;
                --保護者名のセット
                IF W_HOGOSHAKOJINNO <> 0 AND
                    LENGTH(NSHIMEI_KANJI) > 0 THEN
                      IF ACONSPRM_ATENA(2) = 1 THEN
                        MJIDO_WORK(ICNT).ATENA_JODAN := ' （ '|| NSHIMEI_KANJI||'　様 ）';
                      ELSE
                        MJIDO_WORK(ICNT).ATENA_JODAN := NSHIMEI_KANJI||'　様 ';
                  END IF;
                ELSE
                  MJIDO_WORK(ICNT).ATENA_JODAN := NULL;
                END IF;
            END IF;
            --保護者宛児童名ありのとき
            IF ACONSPRM_ATENA(1) = 2 THEN
                      IF RJIDO_SOFU.KOJIN_NO > 0 AND
                         (RJIDO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND
                         (RJIDO_SOFU.SHURYO_BI >= ISAKUSEIBI OR
                         RJIDO_SOFU.SHURYO_BI = 0) THEN
                         IF RJIDO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
                            NSHIMEI_KANJI := RJIDO_SOFU.SHIMEI_KANJI;
                         ELSE
                          IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
                           VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                                 TRIM(RJIDO_ATENA.SHIMEI_KANJI),TRIM(RJIDO_ATENA.HONMYO_KANJI));
                            NSHIMEI_KANJI := VEDIT_GO_DATA;
                          ELSE
                            NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
                          END IF;
                         END IF;
                      ELSE
                       IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
                        VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                              TRIM(RJIDO_ATENA.SHIMEI_KANJI),TRIM(RJIDO_ATENA.HONMYO_KANJI));
                         NSHIMEI_KANJI := VEDIT_GO_DATA;
                       ELSE
                         NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
                       END IF;
                      END IF;
              IF LENGTH(NSHIMEI_KANJI) > 0 THEN
                  IF ACONSPRM_ATENA(3) = 1 THEN
-- 2025/5/15 ZCZL.LIYUWEI Update Start 1.0.004.000:【学齢簿】宛名ラベル(住記参照)印字時、中学生の場合は「生徒氏名」と印字してほしい
                     -- MJIDO_WORK(ICNT).ATENA_GEDAN := '（児童氏名： '||NSHIMEI_KANJI||'　様）';
                     -- 学校区分コードが小学生の場合
                     IF VGAKO_KBN = '1' THEN
                         MJIDO_WORK(ICNT).ATENA_GEDAN := '（児童氏名： '||NSHIMEI_KANJI||'　様）';
                     -- 学校区分コードが中学校の場合
                     ELSIF VGAKO_KBN = '2' THEN
                         MJIDO_WORK(ICNT).ATENA_GEDAN := '（生徒氏名： '||NSHIMEI_KANJI||'　様）';
                     END IF;
-- 2025/5/15 ZCZL.LIYUWEI Update End
                  ELSE
                     MJIDO_WORK(ICNT).ATENA_GEDAN := NSHIMEI_KANJI||'　様';
                  END IF;
              ELSE
                  MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
              END IF;
            END IF;
            IF ACONSPRM_ATENA(1) = 3 THEN
                  IF (RHOGO_SOFU.KOJIN_NO IS NOT NULL)
                         AND (RHOGO_SOFU.TEKIYO_BI <= ISAKUSEIBI)
                         AND (RHOGO_SOFU.SHURYO_BI >= ISAKUSEIBI
                         OR RHOGO_SOFU.SHURYO_BI = 0) THEN
                         IF RHOGO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
                            NSHIMEI_KANJI := RHOGO_SOFU.SHIMEI_KANJI;
                         ELSE
                          IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
                             VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                                   TRIM(RHOGO_ATENA.SHIMEI_KANJI),TRIM(RHOGO_ATENA.HONMYO_KANJI));
                              NSHIMEI_KANJI := VEDIT_GO_DATA;
                          ELSE
                              NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
                          END IF;
                         END IF;
                      ELSE
                          IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
                             VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
                                                   TRIM(RHOGO_ATENA.SHIMEI_KANJI),TRIM(RHOGO_ATENA.HONMYO_KANJI));
                              NSHIMEI_KANJI := VEDIT_GO_DATA;
                          ELSE
                              NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
                          END IF;
                      END IF;
               IF W_HOGOSHAKOJINNO <> 0 AND LENGTH(NSHIMEI_KANJI) >0 THEN
                   IF ACONSPRM_ATENA(2) = 1 THEN
                      MJIDO_WORK(ICNT).ATENA_GEDAN := ' （ '|| NSHIMEI_KANJI||'　様）';
                   ELSE
                      MJIDO_WORK(ICNT).ATENA_GEDAN := NSHIMEI_KANJI||'　様';
                   END IF;
               ELSE
                   MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
               END IF;
            END IF;
            IF NOT( ACONSPRM_ATENA(1) IN (2,3) ) THEN
                 MJIDO_WORK(ICNT).ATENA_GEDAN := NULL;
            END IF;
            MJIDO_WORK(ICNT).KAIPEJI_CD := '';
            MJIDO_WORK(ICNT).JIDO_KOJIN_NO := RJIDO_ATENA.KOJIN_NO;
            MJIDO_WORK(ICNT).KAIPEJI := ' ';
            NSHORIBI := ISAKUSEIBI;
            -- 処理日（表示用）
            ISEIREKIHIZUKE := NSHORIBI;
            IWAREKIHIZUKE := NULL;
            BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
                                  VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                  VEDIT_GYYMMDD3, VKJ_GENGO,
                                  VKG_GENGO,      IWAREKI_YY,
                                  ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                  IMM,            IDD,
                                  IWAREKIHIZUKE,  ISEIREKIHIZUKE );
                MJIDO_WORK(ICNT).SAKUSEIBI :=VEDIT_GYYMMDD3;
                MJIDO_WORK(ICNT).RENBAN := NULL;
                MJIDO_WORK(ICNT).HYOJI_RENBAN := NULL;
--                 IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
--                   VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
--                                             TRIM(RHOGO_ATENA.SHIMEI_KANA),TRIM(RHOGO_ATENA.HONMYO_KANA));
--                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := VEDIT_GO_DATA;
--                   VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
--                                             TRIM(RHOGO_ATENA.SHIMEI_KANJI),TRIM(RHOGO_ATENA.HONMYO_KANJI));
--                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN := VEDIT_GO_DATA;
--                 ELSE
-- 2024/06/26 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := RHOGO_ATENA.SHIMEI_KANA;
--  2025/05/17 ZCZL.WANGMING UPDATE 1.0.004.000: GKB_QA14782(保守2194)_振り仮名部分は保護者氏名カナ対応
--                  MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := o_HOGOSHA_SHIMEI_JODAN;
                  MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := RHOGO_ATENA.SHIMEI_KANA;
                  MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN := RHOGO_ATENA.SHIMEI_KANJI;
--                 END IF;
--                 IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
--                   VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
--                                             TRIM(RJIDO_ATENA.SHIMEI_KANA),TRIM(RJIDO_ATENA.HONMYO_KANA));
--                   MJIDO_WORK(ICNT).JIDO_SHIMEI_JODAN := VEDIT_GO_DATA;
--                   VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO,
--                                             TRIM(RJIDO_ATENA.SHIMEI_KANJI),TRIM(RJIDO_ATENA.HONMYO_KANJI));
--                   MJIDO_WORK(ICNT).JIDO_SHIMEI_GEDAN := VEDIT_GO_DATA;
--                 ELSE
-- 2024/06/26 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--                   MJIDO_WORK(ICNT).JIDO_SHIMEI_JODAN := RJIDO_ATENA.SHIMEI_KANA;
--                   MJIDO_WORK(ICNT).JIDO_SHIMEI_GEDAN := RJIDO_ATENA.SHIMEI_KANJI;
                  MJIDO_WORK(ICNT).JIDO_SHIMEI_JODAN := o_JIDO_SHIMEI_JODAN;
                  MJIDO_WORK(ICNT).JIDO_SHIMEI_GEDAN := o_JIDO_SHIMEI_GEDAN;
-- 2024/06/26 ZCZL.wangqiwei Update end
--                 END IF;
-- 2024/06/26 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--             ISEIREKI := RJIDO_ATENA.SEINENGAPI;
--                 ISEIREKIHIZUKE := RJIDO_ATENA.SEINENGAPI;
--                 IWAREKIHIZUKE := NULL;
--                 BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISEIREKIHIZUKE,
--                                   VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
--                                   VEDIT_GYYMMDD3, VKJ_GENGO,
--                                   VKG_GENGO,      IWAREKI_YY,
--                                   ISEIREKI_YYYY,  IWAREKI_GYYMM,
--                                   IMM,            IDD,
--                                   IWAREKIHIZUKE,  ISEIREKIHIZUKE );
--                 IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
--                   IF FUNC_SET_SEIGYO_SEINENGAPI(ACONSPRM_SHIMEI(13),N_NAIYO_CD_JIDO) = 1 THEN
--                     IF ISEIREKIHIZUKE <> 0 THEN
--                       MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := TO_CHAR(TO_DATE(ISEIREKIHIZUKE,'YYYYMMDD'),'YYYY.MM.DD');
--                     ELSE
--                       MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := '';
--                     END IF;
--                   ELSE
--                     MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VEDIT_GYYMMDD1;
--                   END IF;
--                 ELSE
--                   MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VEDIT_GYYMMDD1;
--                 END IF;
--  2025/12/01 CTC.HJF UPDATE START 1.0.402.000: GKB_保守QA23236対応
               --MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := o_HYOJI_SEINENGAPI; 
--  2025/12/01 CTC.HJF UPDATE END
-- 2024/06/26 ZCZL.wangqiwei Update end
               IF MJIDO_WORK(ICNT).SEIBETSU = 1 THEN
                  MJIDO_WORK(ICNT).HYOJI_SEIBETSU := '男';
               ELSIF MJIDO_WORK(ICNT).SEIBETSU = 2 THEN
                  MJIDO_WORK(ICNT).HYOJI_SEIBETSU :=  '女';
               END IF;
               i_GYOSEIKU_CD  := MJIDO_WORK(ICNT).GYOSEIKU_CD;
               i_SANTEIDANTAI_CD := MJIDO_WORK(ICNT).SANTEIDANTAI_CD;
               VGYOSEIKU_MEI :=  GAAPK0030.FGYOSEIKUMEI(i_SANTEIDANTAI_CD,i_GYOSEIKU_CD);
               MJIDO_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;
              IF IGAKO_KBN = 1 THEN
                            BEGIN
                          SELECT SYOGAKOMEI INTO VGAKOMEI
                          FROM GKBTSHOGAKKO
                          WHERE SYOGAKO_CD = MJIDO_WORK(ICNT).GAKO_CD;
                            EXCEPTION
                             WHEN NO_DATA_FOUND THEN
                                  DBMS_OUTPUT.PUT_LINE('該当小学校なし　'||' '||KOJIN_NO);
                                  VGAKOMEI := ' ';
                            END;
              END IF;
              IF IGAKO_KBN = 2 THEN
                            BEGIN
                           SELECT TYUGAKOMEI INTO VGAKOMEI
                           FROM GKBTCHUGAKKO
                           WHERE TYUGAKO_CD = MJIDO_WORK(ICNT).GAKO_CD;
                            EXCEPTION
                               WHEN NO_DATA_FOUND THEN
                                    DBMS_OUTPUT.PUT_LINE('該当中学校なし　'||' '||KOJIN_NO);
                                    VGAKOMEI := ' ';
                            END;
              END IF;
              MJIDO_WORK(ICNT).GAKOKUMEI := VGAKOMEI;
              i_ISAN_CD := MJIDO_WORK(ICNT).SANTEIDANTAI_CD;
              IRTN1 := GAAPK0030.FJICHINAME(i_ISAN_CD,o_VSAN_KJ);
              MJIDO_WORK(ICNT).SANTEIDANTAIMEI := o_VSAN_KJ;
              IF RJIDO_SOFU.KOJIN_NO > 0 AND
                 (RJIDO_SOFU.TEKIYO_BI <= NSHORIBI) AND
                 (RJIDO_SOFU.SHURYO_BI >= NSHORIBI OR
                 RJIDO_SOFU.SHURYO_BI = 0) THEN
                  MJIDO_WORK(ICNT).JIDO_YUBIN_NO := RJIDO_SOFU.YUBIN_NO;
                  MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC := RJIDO_SOFU.YUBIN_NOBC;
                  MJIDO_WORK(ICNT).JIDO_CHOMEI := RJIDO_SOFU.CHOMEI;
                  MJIDO_WORK(ICNT).JIDO_BANCHI := RJIDO_SOFU.BANCHI;
                  MJIDO_WORK(ICNT).JIDO_KATAGAKI :=RJIDO_SOFU.KATAGAKI;
              ELSE
                  MJIDO_WORK(ICNT).JIDO_YUBIN_NO := RJIDO_ATENA.YUBIN_NO;
                  MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC:= RJIDO_ATENA.YUBIN_NOBC;
                  MJIDO_WORK(ICNT).JIDO_CHOMEI:= RJIDO_ATENA.CHOMEI;
                  MJIDO_WORK(ICNT).JIDO_BANCHI:= RJIDO_ATENA.BANCHI;
                  MJIDO_WORK(ICNT).JIDO_KATAGAKI:= RJIDO_ATENA.KATAGAKI;
              END IF;
              IF RHOGO_SOFU.KOJIN_NO > 0  AND
                 (RHOGO_SOFU.TEKIYO_BI <= NSHORIBI) AND
                 (RHOGO_SOFU.SHURYO_BI >= NSHORIBI OR
                 RHOGO_SOFU.SHURYO_BI = 0) THEN
                  MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO := RHOGO_SOFU.YUBIN_NO;
                  MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NOBC := RHOGO_SOFU.YUBIN_NOBC;
                  MJIDO_WORK(ICNT).HOGOSHA_CHOMEI := RHOGO_SOFU.CHOMEI;
                  MJIDO_WORK(ICNT).HOGOSHA_BANCHI := RHOGO_SOFU.BANCHI;
                  MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI := RHOGO_SOFU.KATAGAKI;
              ELSE
                  MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO := RHOGO_ATENA.YUBIN_NO;
                  MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NOBC :=  RHOGO_ATENA.YUBIN_NOBC;
                  MJIDO_WORK(ICNT).HOGOSHA_CHOMEI := RHOGO_ATENA.CHOMEI;
                  MJIDO_WORK(ICNT).HOGOSHA_BANCHI := RHOGO_ATENA.BANCHI;
                  MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI := RHOGO_ATENA.KATAGAKI;
              END IF;
                  VKON_JUSHO := MJIDO_WORK(ICNT).HOGOSHA_CHOMEI||MJIDO_WORK(ICNT).HOGOSHA_BANCHI||MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI;
              IF LENGTH(VKON_JUSHO) > 20 THEN
              VKON_JUSHO_JODAN := SUBSTR(VKON_JUSHO,1,20);
              VKON_JUSHO_GEDAN := SUBSTR(VKON_JUSHO,21);
                  MJIDO_WORK(ICNT).KON_JUSHO_JODAN := VKON_JUSHO_JODAN;
                  MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := VKON_JUSHO_GEDAN;
              END IF;
              IF LENGTH(VKON_JUSHO) = 0 THEN
                  MJIDO_WORK(ICNT).KON_JUSHO_JODAN := NULL;
                  MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := NULL;
              END IF;
              IF LENGTH(VKON_JUSHO) BETWEEN 1 AND 20 THEN
                  MJIDO_WORK(ICNT).KON_JUSHO_JODAN := VKON_JUSHO;
                  MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := NULL;
              END IF;
              -- 外国人世帯の保護者判定を追加
              MJIDO_WORK(ICNT).JINKAKU_KBN             := VJINKAKU_KBN;
              ICNT := ICNT + 1;                 -- カウントアップ
              IFRET := c_ISUCCESS;              -- 正常終了
             END LOOP;
             dbms_output.put_line('ICNT = ' || ICNT);
       EXCEPTION
          WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        IF CRATENA%ISOPEN THEN
           CLOSE CRATENA;
        END IF;
        RETURN IFRET;
    EXCEPTION
        -- その他エラー
        WHEN OTHERS THEN
            IF CRATENA%ISOPEN THEN
              CLOSE CRATENA;
            END IF;
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------
    --  機能概要      : 宛名ラベルワーク（GKBWALABEL）（GKBWALABEL_CSV）テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNC_INSERT_JIDO_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
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
                INSERT INTO
                GKBWALABEL
                (
                 GAKO_CD,
                 GYOSEIKU_CD,
                 HAN_CD,
                 SANTEIDANTAI_CD,
                 SHIMEI_KANA,
                 SEINENGAPI,
                 SEIBETSU,
                 SETAI_NO,
                 HOGOSHA_SHIMEI_KANA,
                 YUBIN_NO,
                 CHOMEI,
                 BANCHI,
                 KATAGAKI,
                 NUSI_SHIMEI_KANJI,
                 ATENA_JODAN,
                 ATENA_GEDAN,
                 KAIPEJI_CD,
                 YUBIN_NOBC,
                 JIDO_KOJIN_NO,
                 KAIPEJI,
                 SAKUSEIBI,
                 RENBAN,
                 HYOJI_RENBAN,
                 HOGOSHA_SHIMEI_JODAN,
                 HOGOSHA_SHIMEI_GEDAN,
                 JIDO_SHIMEI_JODAN,
                 JIDO_SHIMEI_GEDAN,
                 HYOJI_SEINENGAPI,
                 HYOJI_SEIBETSU,
                 GYOSEIKUMEI,
                 GAKOKUMEI,
                 SANTEIDANTAIMEI,
                 JIDO_YUBIN_NO,
                 JIDO_YUBIN_NOBC,
                 JIDO_CHOMEI,
                 JIDO_BANCHI,
                 JIDO_KATAGAKI,
                 HOGOSHA_YUBIN_NO,
                 HOGOSHA_YUBIN_NOBC,
                 HOGOSHA_CHOMEI,
                 HOGOSHA_BANCHI,
                 HOGOSHA_KATAGAKI,
                 KON_JUSHO_JODAN,
                 KON_JUSHO_GEDAN,
                 --外国人世帯の保護者判定を追加
                 JINKAKU_KBN
               )
                VALUES
                (
                 MJIDO_WORK(ICNT).GAKO_CD,
                 MJIDO_WORK(ICNT).GYOSEIKU_CD,
                 MJIDO_WORK(ICNT).HAN_CD,
                 MJIDO_WORK(ICNT).SANTEIDANTAI_CD,
                 MJIDO_WORK(ICNT).SHIMEI_KANA,
                 MJIDO_WORK(ICNT).SEINENGAPI,
                 MJIDO_WORK(ICNT).SEIBETSU,
                 MJIDO_WORK(ICNT).SETAI_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
                 MJIDO_WORK(ICNT).YUBIN_NO,
                 MJIDO_WORK(ICNT).CHOMEI,
                 MJIDO_WORK(ICNT).BANCHI,
                 MJIDO_WORK(ICNT).KATAGAKI,
                 MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI,
                 MJIDO_WORK(ICNT).ATENA_JODAN,
                 MJIDO_WORK(ICNT).ATENA_GEDAN,
                 MJIDO_WORK(ICNT).KAIPEJI_CD,
                 MJIDO_WORK(ICNT).YUBIN_NOBC,
                 MJIDO_WORK(ICNT).JIDO_KOJIN_NO,
                 MJIDO_WORK(ICNT).KAIPEJI,
                 MJIDO_WORK(ICNT).SAKUSEIBI,
                 MJIDO_WORK(ICNT).RENBAN,
                 MJIDO_WORK(ICNT).HYOJI_RENBAN,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN,
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN,
                 MJIDO_WORK(ICNT).JIDO_SHIMEI_JODAN,
                 MJIDO_WORK(ICNT).JIDO_SHIMEI_GEDAN,
                 MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,
                 MJIDO_WORK(ICNT).HYOJI_SEIBETSU,
                 MJIDO_WORK(ICNT).GYOSEIKUMEI,
                 MJIDO_WORK(ICNT).GAKOKUMEI,
                 MJIDO_WORK(ICNT).SANTEIDANTAIMEI,
                 MJIDO_WORK(ICNT).JIDO_YUBIN_NO,
                 MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC,
                 MJIDO_WORK(ICNT).JIDO_CHOMEI,
                 MJIDO_WORK(ICNT).JIDO_BANCHI,
                 MJIDO_WORK(ICNT).JIDO_KATAGAKI,
                 MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO,
                 MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NOBC,
                 MJIDO_WORK(ICNT).HOGOSHA_CHOMEI,
                 MJIDO_WORK(ICNT).HOGOSHA_BANCHI,
                 MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI,
                 MJIDO_WORK(ICNT).KON_JUSHO_JODAN,
                 MJIDO_WORK(ICNT).KON_JUSHO_GEDAN,
                 --外国人世帯の保護者判定を追加
                 MJIDO_WORK(ICNT).JINKAKU_KBN
                 );
            END LOOP;
            COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
            ROLLBACK;       -- 処理前に戻す
              IFRET := c_INOT_SUCCESS;      -- 異常終了
              -- 処理ログの出力
              B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        RETURN IFRET;
    EXCEPTION
    -- その他エラー
        WHEN OTHERS THEN
            ROLLBACK;       -- 処理前に戻す
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------
    --  機能概要      : 宛名ラベル中間データ作成（ＣＳＶ用)
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNCGET_JIDO_WK_CSV RETURN NUMBER IS
        IFRET               PLS_INTEGER;                   -- 戻り値
        ICNT                BINARY_INTEGER;                -- カウント
        VSQL                NVARCHAR2(10000);              -- ＳＱＬ文
        VSQLSEL             NVARCHAR2(9000);               -- ＳＱＬのソート以外
        VSQLORDER           NVARCHAR2(1000);               -- ＳＱＬの［ORDER BY］句
        ICUR                PLS_INTEGER;                   -- カーソル
        RREC                GKBWALABEL%ROWTYPE;            -- 宛名中間レコード変数
        NROWS               NUMBER;
        IPAGECNT            PLS_INTEGER;                   -- 頁数
        IGYOCNT             PLS_INTEGER;                   -- 行番号
        IGYORENBAN          PLS_INTEGER;                   -- 行連番
        VPAGEWORK           NVARCHAR2(1000);               -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(1000);               -- 改頁項目値のワーク
    BEGIN
        IFRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IPAGECNT := 0;
        IGYOCNT := 0;
        ICNT := 0;
        IGYORENBAN := 0;
        MJIDO_WORK.DELETE;                   -- ワーク領域の初期化

        -- 改頁条件取得
        VPAGENM := ' GAKOKUMEI ';
        VPAGEFD := ' GAKO_CD ';
        -- ［ORDER BY］句を付加
        IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
           VSQLORDER := ' ORDER BY ' || g_rJSTP.Orderbyclause;
        ELSE
           VSQLORDER :='';
        END IF;

        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'GAKO_CD, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
            VSQLSEL := VSQLSEL || 'HAN_CD, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
            VSQLSEL := VSQLSEL || 'SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'CHOMEI, ';
            VSQLSEL := VSQLSEL || 'BANCHI, ';
            VSQLSEL := VSQLSEL || 'KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'NUSI_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'ATENA_JODAN, ';
            VSQLSEL := VSQLSEL || 'ATENA_GEDAN, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || VPAGEFD || ' PAGE_FIELD, ';             -- 改頁値を設定
            VSQLSEL := VSQLSEL || 'YUBIN_NOBC, ';
            VSQLSEL := VSQLSEL || 'JINKAKU_KBN ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || c_VTABLE || ' ';
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;
            -- カーソルのオープン
            ICUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(ICUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(ICUR,  1, RREC.GAKO_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  2, RREC.GYOSEIKU_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  3, RREC.HAN_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  4, RREC.SANTEIDANTAI_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  5, RREC.SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  6, RREC.SEINENGAPI);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  7, RREC.SEIBETSU);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  8, RREC.SETAI_NO);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  9, RREC.HOGOSHA_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 10, RREC.YUBIN_NO, 10);
-- 2024/06/26 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 11, RREC.CHOMEI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 12, RREC.BANCHI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 13, RREC.KATAGAKI, 60);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 11, RREC.CHOMEI, 136);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 12, RREC.BANCHI, 50);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 13, RREC.KATAGAKI, 300);
-- 2024/06/26 ZCZL.wangqiwei Update
            DBMS_SQL.DEFINE_COLUMN(ICUR, 14, RREC.NUSI_SHIMEI_KANJI, 110);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 15, RREC.ATENA_JODAN, 110);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 16, RREC.ATENA_GEDAN, 110);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 17, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 18, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 19, RREC.YUBIN_NOBC, 30);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 20, RREC.JINKAKU_KBN);
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(ICUR);
            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(ICUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(ICUR,  1, MJIDO_WORK(ICNT).GAKO_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  2, MJIDO_WORK(ICNT).GYOSEIKU_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  3, MJIDO_WORK(ICNT).HAN_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  4, MJIDO_WORK(ICNT).SANTEIDANTAI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  5, MJIDO_WORK(ICNT).SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  6, MJIDO_WORK(ICNT).SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  7, MJIDO_WORK(ICNT).SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  8, MJIDO_WORK(ICNT).SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  9, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 10, MJIDO_WORK(ICNT).YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 11, MJIDO_WORK(ICNT).CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 12, MJIDO_WORK(ICNT).BANCHI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 13, MJIDO_WORK(ICNT).KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 14, MJIDO_WORK(ICNT).NUSI_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 15, MJIDO_WORK(ICNT).ATENA_JODAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 16, MJIDO_WORK(ICNT).ATENA_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 17, MJIDO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 18, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 19, MJIDO_WORK(ICNT).YUBIN_NOBC);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 20, MJIDO_WORK(ICNT).JINKAKU_KBN);

                    IF VPAGEWORK = VPAGEFIELD THEN
                    -- 以前の改頁項目値と同じ
                        IGYOCNT := IGYOCNT + 1;
                        IGYORENBAN := IGYORENBAN + 1;
                    ELSE
                    -- 改頁必要
                        IPAGECNT := IPAGECNT + 1;
                        IGYOCNT := 1;
                        IGYORENBAN := 1;
                        VPAGEWORK := VPAGEFIELD;
                    END IF;
                    MJIDO_WORK(ICNT).RENBAN := IGYORENBAN;
                    MJIDO_WORK(ICNT).HYOJI_RENBAN := TO_CHAR(MJIDO_WORK(ICNT).RENBAN);
                    -- 再セットする項目
                    MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEFIELD;  -- 改頁コード
                ELSE
                    -- 全件読み込み終了
                    EXIT;
                END IF;
                ICNT := ICNT + 1;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);  -- 処理ログの出力
        END;
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_CSV', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);  -- 処理ログの出力
        RETURN IFRET;
    END FUNCGET_JIDO_WK_CSV;
    --------------------------------------------------------
    --  機能概要      : 宛名レコードの作成(GKBWALABEL_CSV用）
    --  パラメータ    : MATENA_REC
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNC_REC_ATENA(MATENA_REC OUT MTATENA_REC) RETURN NUMBER IS
        VHANTEI_CD          NVARCHAR2(500);
        IFRET               NUMBER;
    BEGIN
        IFRET := 0;
        --宛名作成レコード初期化
        MATENA_REC.YUBIN_NO := ' ';
        MATENA_REC.CHOMEI := ' ';
        MATENA_REC.BANCHI := ' ';
        MATENA_REC.KATAGAKI := ' ';
        MATENA_REC.NUSI_SHIMEI_KANJI := ' ';
        MATENA_REC.ATENA_JODAN := ' ';
        MATENA_REC.ATENA_GEDAN := ' ';
        MATENA_REC.YUBIN_NOBC := ' ';
        MATENA_REC.YUBIN_NO2 := ' ';
        MATENA_REC.CHOMEI2 := ' ';
        MATENA_REC.BANCHI2 := ' ';
        MATENA_REC.KATAGAKI2 := ' ';
        MATENA_REC.NUSI_SHIMEI_KANJI2 := ' ';
        MATENA_REC.ATENA_JODAN2 := ' ';
        MATENA_REC.ATENA_GEDAN2 := ' ';
        MATENA_REC.KAIPEJI_CD := ' ';
        MATENA_REC.YUBIN_NOBC2 := ' ';
        MATENA_REC.JINKAKU_KBN := 0;
        MATENA_REC.KAIPEJI_CD := MJIDO_WORK(ICNTM).KAIPEJI_CD;
        MATENA_REC.YUBIN_NO := MJIDO_WORK(ICNTM).YUBIN_NO;
        MATENA_REC.CHOMEI := MJIDO_WORK(ICNTM).CHOMEI;
        MATENA_REC.BANCHI := MJIDO_WORK(ICNTM).BANCHI;
        MATENA_REC.KATAGAKI := MJIDO_WORK(ICNTM).KATAGAKI;
        MATENA_REC.NUSI_SHIMEI_KANJI := MJIDO_WORK(ICNTM).NUSI_SHIMEI_KANJI;
        MATENA_REC.ATENA_JODAN := MJIDO_WORK(ICNTM).ATENA_JODAN;
        MATENA_REC.ATENA_GEDAN := MJIDO_WORK(ICNTM).ATENA_GEDAN;
        VHANTEI_CD := MJIDO_WORK(ICNTM).KAIPEJI_CD;
        MATENA_REC.YUBIN_NOBC := MJIDO_WORK(ICNTM).YUBIN_NOBC;
        ICNTM := ICNTM + 1;
        IF ICNTM > IMAX THEN
            RETURN IFRET;
        END IF;
        IF VHANTEI_CD <> MJIDO_WORK(ICNTM).KAIPEJI_CD THEN
           RETURN IFRET;
        ELSE
           MATENA_REC.YUBIN_NO2 := MJIDO_WORK(ICNTM).YUBIN_NO;
           MATENA_REC.CHOMEI2 := MJIDO_WORK(ICNTM).CHOMEI;
           MATENA_REC.BANCHI2 := MJIDO_WORK(ICNTM).BANCHI;
           MATENA_REC.KATAGAKI2 := MJIDO_WORK(ICNTM).KATAGAKI;
           MATENA_REC.NUSI_SHIMEI_KANJI2 := MJIDO_WORK(ICNTM).NUSI_SHIMEI_KANJI;
           MATENA_REC.ATENA_JODAN2 := MJIDO_WORK(ICNTM).ATENA_JODAN;
           MATENA_REC.ATENA_GEDAN2 := MJIDO_WORK(ICNTM).ATENA_GEDAN;
           MATENA_REC.YUBIN_NOBC2 := MJIDO_WORK(ICNTM).YUBIN_NOBC;
           ICNTM := ICNTM +1;
           IF ICNTM > IMAX THEN
              RETURN IFRET;
           END IF;
        END IF;
        RETURN IFRET;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN IFRET;
    END FUNC_REC_ATENA;
    --------------------------------------------------------
    --  機能概要      : 宛名ラベルＣＳＶファイル作成
    --  パラメータ    : ない
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNCSET_JIDO_WK_CSVFILE RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        IRTN                PLS_INTEGER;                -- 戻り値
        IMIN                PLS_INTEGER;                -- 最小値（出力件数）
        MATENA_REC          MTATENA_REC;
        --カーソルのレコード
        rec_WL              GKBWL240R001%ROWTYPE;
        nROWNO              NUMBER := 0;

    BEGIN
        IFRET := c_ISUCCESS;               -- 正常終了
        IMAX := MJIDO_WORK.LAST;           -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;          -- ワーク領域の件数の最小値

        --ワークテーブルのデータを削除する
        DELETE FROM GKBWL240R001 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;

        -- 取得した件数分繰り返す
        LOOP
            EXIT WHEN ICNTM > IMAX;
            IRTN := FUNC_REC_ATENA(MATENA_REC);

            rec_WL := NUll;
            nROWNO := nROWNO + 1;
            rec_WL.NO := nROWNO;  --ソート順
            --郵便番号
            IF LENGTH(MATENA_REC.YUBIN_NO) > 0 THEN
               rec_WL.YUBIN_NO := TRANSLATE( MATENA_REC.YUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
            ELSE
               rec_WL.YUBIN_NO := MATENA_REC.YUBIN_NO;
            END IF;
            rec_WL.CHOMEI_BANCHI := MATENA_REC.CHOMEI || MATENA_REC.BANCHI;  --町名番地
            rec_WL.KATAGAKI := MATENA_REC.KATAGAKI;  --方書
            rec_WL.SHIMEI_KANJI := MATENA_REC.NUSI_SHIMEI_KANJI;  --世帯主名
            rec_WL.ATENA_JODAN := MATENA_REC.ATENA_JODAN;  --宛名上段
            rec_WL.ATENA_GEDAN := MATENA_REC.ATENA_GEDAN;  --宛名下段
            rec_WL.BC_NO := MATENA_REC.YUBIN_NOBC;  --カスタマバーコード
            --郵便番号２
            IF LENGTH(MATENA_REC.YUBIN_NO2) > 0 THEN
               rec_WL.YUBIN_NO2 := TRANSLATE( MATENA_REC.YUBIN_NO2, '1234567890-', '１２３４５６７８９０－' );
            ELSE
               rec_WL.YUBIN_NO2 := MATENA_REC.YUBIN_NO2;
            END IF;
            rec_WL.CHOMEI_BANCHI2 := MATENA_REC.CHOMEI2 || MATENA_REC.BANCHI2;  --町名番地２
            rec_WL.KATAGAKI2 := MATENA_REC.KATAGAKI2;  --方書２
            rec_WL.SHIMEI_KANJI2 := MATENA_REC.NUSI_SHIMEI_KANJI2;  --世帯主名２
            rec_WL.ATENA_JODAN2 := MATENA_REC.ATENA_JODAN2;  --宛名上段２
            rec_WL.ATENA_GEDAN2 := MATENA_REC.ATENA_GEDAN2;  --宛名下段２
            rec_WL.KAIPAGE_CD := MATENA_REC.KAIPEJI_CD;  --改頁コード
            rec_WL.YUBIN_NOBC2 := MATENA_REC.YUBIN_NOBC2;  --カスタマバーコード２
            rec_WL.BREAK_NO := NULL;  --改ページキー
            rec_WL.WSNUM := g_sWSNUM;  --端末番号
            rec_WL.BATCHKBN := c_BATCH;  --即時バッチ区分
            rec_WL.JOBNUM := g_nJOBNUM;  --ジョブNO

            INSERT INTO GKBWL240R001 VALUES rec_WL;
        END LOOP;
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_CSVFILE', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);  -- 処理ログの出力
        RETURN IFRET;
    END FUNCSET_JIDO_WK_CSVFILE;
    --------------------------------------------------------
    --  機能概要      : 宛名ラベル中間データ作成（ＣＳＶ用)
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNCGET_JIDO_WK_ITIRAN_CSV RETURN NUMBER IS
        IFRET               PLS_INTEGER;                   -- 戻り値
        ICNT                BINARY_INTEGER;                -- カウント
        VSQL                NVARCHAR2(10000);              -- ＳＱＬ文
        VSQLSEL             NVARCHAR2(9000);               -- ＳＱＬのソート以外
        VSQLORDER           NVARCHAR2(1000);               -- ＳＱＬの［ORDER BY］句
        ICUR                PLS_INTEGER;                   -- カーソル
        RREC                GKBWALABEL%ROWTYPE;            -- 宛名中間レコード変数
        NROWS               NUMBER;
        IPAGECNT            PLS_INTEGER;                   -- 頁数
        IGYOCNT             PLS_INTEGER;                   -- 行番号
        IGYORENBAN          PLS_INTEGER;                   -- 行連番
        VPAGENM             NVARCHAR2(1000);               -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(1000);               -- 改頁項目値のワーク
        VPAGEFD             NVARCHAR2(1000);               -- 改頁項目値のワーク
    BEGIN
        IFRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IPAGECNT := 0;
        IGYOCNT := 0;
        ICNT := 0;
        IGYORENBAN := 0;
        MJIDO_WORK.DELETE;                   -- ワーク領域の初期化

        -- 改頁条件取得
        VPAGENM := ' GAKOKUMEI ';
        VPAGEFD := ' GAKO_CD ';
        -- ［ORDER BY］句を付加
        IF KKAPK0010.FTrim(g_rJSTP.Orderbyclause) IS NOT NULL THEN
            VSQLORDER := ' ORDER BY ' || g_rJSTP.Orderbyclause;
        ELSE
            VSQLORDER := '';
        END IF;

        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'GAKO_CD, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
            VSQLSEL := VSQLSEL || 'HAN_CD, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
            VSQLSEL := VSQLSEL || 'SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
            VSQLSEL := VSQLSEL ||  VPAGEFD || ' PAGE_FIELD, ';     -- 改頁値を設定
            VSQLSEL := VSQLSEL ||  VPAGENM || ' PAGE_NAME, ';      -- 改頁名を設定
            VSQLSEL := VSQLSEL || 'RENBAN, ';
            VSQLSEL := VSQLSEL || 'GAKOKUMEI, ';
            VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_JODAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_GEDAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_KOJIN_NO, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'JIDO_CHOMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_BANCHI, ';
            VSQLSEL := VSQLSEL || 'JIDO_KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'JIDO_YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_CHOMEI, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_BANCHI, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN, ';
            --外国人世帯の保護者判定を追加
            VSQLSEL := VSQLSEL || 'JINKAKU_KBN ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || c_VTABLE || ' ';
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;
            -- カーソルのオープン
            ICUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(ICUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(ICUR,  1, RREC.GAKO_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  2, RREC.GYOSEIKU_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  3, RREC.HAN_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  4, RREC.SANTEIDANTAI_CD);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  5, RREC.SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  6, RREC.SEINENGAPI);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  7, RREC.SEIBETSU);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  8, RREC.SETAI_NO);
            DBMS_SQL.DEFINE_COLUMN(ICUR,  9, RREC.HOGOSHA_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 10, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 11, RREC.KAIPEJI, 500);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 12, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 13, VPAGENM, 500);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 14, RREC.RENBAN);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 15, RREC.GAKOKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 16, RREC.SAKUSEIBI, 30);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 17, RREC.GYOSEIKUMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 18, RREC.JIDO_SHIMEI_JODAN, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 19, RREC.JIDO_SHIMEI_GEDAN, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 20, RREC.JIDO_KOJIN_NO);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 21, RREC.HYOJI_SEINENGAPI,11 );
            DBMS_SQL.DEFINE_COLUMN(ICUR, 22, RREC.HYOJI_SEIBETSU,2 );
--2024/06/27 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 23, RREC.JIDO_CHOMEI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 24, RREC.JIDO_BANCHI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 25, RREC.JIDO_KATAGAKI, 60);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 23, RREC.JIDO_CHOMEI, 136);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 24, RREC.JIDO_BANCHI, 50);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 25, RREC.JIDO_KATAGAKI, 300);
--2024/06/27 ZCZL.wangqiwei Update end
            DBMS_SQL.DEFINE_COLUMN(ICUR, 26, RREC.JIDO_YUBIN_NO, 10);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 27, RREC.HOGOSHA_SHIMEI_JODAN, 100);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 28, RREC.HOGOSHA_SHIMEI_GEDAN, 100);
--2024/06/27 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 29, RREC.HOGOSHA_CHOMEI, 40);
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 30, RREC.HOGOSHA_BANCHI,40 );
--            DBMS_SQL.DEFINE_COLUMN(ICUR, 31, RREC.HOGOSHA_KATAGAKI,60 );
            DBMS_SQL.DEFINE_COLUMN(ICUR, 29, RREC.HOGOSHA_CHOMEI, 136);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 30, RREC.HOGOSHA_BANCHI,50 );
            DBMS_SQL.DEFINE_COLUMN(ICUR, 31, RREC.HOGOSHA_KATAGAKI,300 );
--2024/06/27 ZCZL.wangqiwei Update end
            DBMS_SQL.DEFINE_COLUMN(ICUR, 32, RREC.HOGOSHA_YUBIN_NO, 10);
            DBMS_SQL.DEFINE_COLUMN(ICUR, 33, RREC.KON_JUSHO_JODAN,120 );
            DBMS_SQL.DEFINE_COLUMN(ICUR, 34, RREC.KON_JUSHO_GEDAN,120 );
            --外国人世帯の保護者判定を追加
            DBMS_SQL.DEFINE_COLUMN(ICUR, 35, RREC.JINKAKU_KBN);
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(ICUR);
            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(ICUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(ICUR,  1, MJIDO_WORK(ICNT).GAKO_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  2, MJIDO_WORK(ICNT).GYOSEIKU_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  3, MJIDO_WORK(ICNT).HAN_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  4, MJIDO_WORK(ICNT).SANTEIDANTAI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  5, MJIDO_WORK(ICNT).SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  6, MJIDO_WORK(ICNT).SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  7, MJIDO_WORK(ICNT).SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  8, MJIDO_WORK(ICNT).SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR,  9, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 10, MJIDO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 11, MJIDO_WORK(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 12, VPAGEFD);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 13, VPAGENM);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 14, MJIDO_WORK(ICNT).RENBAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 15, MJIDO_WORK(ICNT).GAKOKUMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 16, MJIDO_WORK(ICNT).SAKUSEIBI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 17, MJIDO_WORK(ICNT).GYOSEIKUMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 18, MJIDO_WORK(ICNT).JIDO_SHIMEI_JODAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 19, MJIDO_WORK(ICNT).JIDO_SHIMEI_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 20, MJIDO_WORK(ICNT).JIDO_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 21, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 22, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 23, MJIDO_WORK(ICNT).JIDO_CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 24, MJIDO_WORK(ICNT).JIDO_BANCHI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 25, MJIDO_WORK(ICNT).JIDO_KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 26, MJIDO_WORK(ICNT).JIDO_YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 27, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 28, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 29, MJIDO_WORK(ICNT).HOGOSHA_CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 30, MJIDO_WORK(ICNT).HOGOSHA_BANCHI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 31, MJIDO_WORK(ICNT).HOGOSHA_KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 32, MJIDO_WORK(ICNT).HOGOSHA_YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 33, MJIDO_WORK(ICNT).KON_JUSHO_JODAN);
                    DBMS_SQL.COLUMN_VALUE(ICUR, 34, MJIDO_WORK(ICNT).KON_JUSHO_GEDAN);
                    --外国人世帯の保護者判定を追加
                    DBMS_SQL.COLUMN_VALUE(ICUR, 35, MJIDO_WORK(ICNT).JINKAKU_KBN);
                    IF VPAGEWORK = VPAGENM OR (VPAGEWORK IS NULL AND VPAGENM IS NULL)THEN
                    -- 以前の改頁項目値と同じ
                        IGYOCNT := IGYOCNT + 1;
                        IGYORENBAN := IGYORENBAN + 1;
                        IF IGYOCNT > c_IMAXROWS THEN
                        -- １頁内の最大行数を超えた
                          IPAGECNT := IPAGECNT + 1;
                          IGYOCNT := 1;
                          VPAGEWORK := VPAGENM;
                        END IF;
                    ELSE
                    -- 改頁必要
                        IPAGECNT := IPAGECNT + 1;
                        IGYOCNT := 1;
                        IGYORENBAN := 1;
                        VPAGEWORK := VPAGENM;
                    END IF;
                    MJIDO_WORK(ICNT).RENBAN := IGYORENBAN;
                    MJIDO_WORK(ICNT).HYOJI_RENBAN := TO_CHAR(MJIDO_WORK(ICNT).RENBAN);
                    -- 再セットする項目
                    MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEFD;  -- 改頁コード
                    MJIDO_WORK(ICNT).KAIPEJI := VPAGENM;     -- 改頁名
  
                ELSE
                    -- 全件読み込み終了
                    EXIT;
                END IF;
                ICNT := ICNT + 1;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_ITIRAN_CSV', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);  -- 処理ログの出力
        END;
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_JIDO_WK_ITIRAN_CSV', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);  -- 処理ログの出力
        RETURN IFRET;
    END FUNCGET_JIDO_WK_ITIRAN_CSV;
    --------------------------------------------------------
    --  機能概要      : 宛名ラベルＣＳＶファイル作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 その他 異常
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNCSET_JIDO_WK_ITIRAN_CSVFILE RETURN NUMBER IS
        IFRET                       PLS_INTEGER;                -- 戻り値
        IMIN                        PLS_INTEGER;                -- 最小値（出力件数）
        VSTART2                     NVARCHAR2(15);              -- 開始生年月日
        VEND2                       NVARCHAR2(15);              -- 終了生年月日
        rec_WL                      GKBWL240R002%ROWTYPE;       --カーソルのレコード
        nROWNO                      NUMBER := 0;
    BEGIN
        ICNTM := 0;
        IFRET := c_ISUCCESS;               -- 正常終了
        IMAX := MJIDO_WORK.LAST;           -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;          -- ワーク領域の件数の最小値

        --ワークテーブルのデータを削除する
        DELETE FROM GKBWL240R002 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;

        -- 取得した件数分繰り返す
        VSTART2 := FUNC_CONV_DATE(TO_NUMBER(VSTART), 3);     -- 抽出開始生年月日
        VEND2   := FUNC_CONV_DATE(TO_NUMBER(VEND), 3);       -- 抽出終了生年月日
        LOOP
            EXIT WHEN ICNTM > IMAX;

            rec_WL := NUll;
            nROWNO := nROWNO + 1;
            rec_WL.NO := nROWNO;  --ソート順
            rec_WL.KAIPAGE_CD := MJIDO_WORK(ICNTM).KAIPEJI_CD;  --改頁コード
            rec_WL.KAIPAGE_MEI := MJIDO_WORK(ICNTM).KAIPEJI;  --改頁名
            rec_WL.RENBAN := MJIDO_WORK(ICNTM).RENBAN;  --連番
            rec_WL.GAKKO_MEI := MJIDO_WORK(ICNTM).GAKOKUMEI;  --学校名
            rec_WL.GAKKO_CD := MJIDO_WORK(ICNTM).GAKO_CD;  --学校コード
            rec_WL.SAKUSEIBI := MJIDO_WORK(ICNTM).SAKUSEIBI;  --作成日
            rec_WL.GYOSEIKU := MJIDO_WORK(ICNTM).GYOSEIKUMEI;  --行政区
            rec_WL.JIDO_SHIMEI_JODAN := MJIDO_WORK(ICNTM).JIDO_SHIMEI_JODAN;  --児童氏名上段
            rec_WL.JIDO_SHIMEI_GEDAN := MJIDO_WORK(ICNTM).JIDO_SHIMEI_GEDAN;  --児童氏名下段
            rec_WL.JIDO_KOJIN_NO := MJIDO_WORK(ICNTM).JIDO_KOJIN_NO;  --児童個人番号
            rec_WL.HYOJI_SEINENGAPI := MJIDO_WORK(ICNTM).HYOJI_SEINENGAPI;  --表示生年月日
            rec_WL.SEIBETSU := MJIDO_WORK(ICNTM).HYOJI_SEIBETSU;  --性別
            rec_WL.JIDO_CHOMEI_BANCHI_KATAGAKI := MJIDO_WORK(ICNTM).JIDO_CHOMEI || MJIDO_WORK(ICNTM).JIDO_BANCHI || MJIDO_WORK(ICNTM).JIDO_KATAGAKI;  --児童町名番地方書
            --児童郵便番号
            IF MJIDO_WORK(ICNTM).JIDO_YUBIN_NO IS NOT NULL AND LENGTH(MJIDO_WORK(ICNTM).JIDO_YUBIN_NO) > 3 THEN
                rec_WL.JIDO_YUBIN_NO := SUBSTR(MJIDO_WORK(ICNTM).JIDO_YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNTM).JIDO_YUBIN_NO,4);
            ELSE
                rec_WL.JIDO_YUBIN_NO := NULL;
            END IF;
            rec_WL.HOGOSHA_SHIMEI_JODAN := MJIDO_WORK(ICNTM).HOGOSHA_SHIMEI_JODAN;  --保護者氏名上段
            rec_WL.HOGOSHA_SHIMEI_GEDAN := MJIDO_WORK(ICNTM).HOGOSHA_SHIMEI_GEDAN;  --保護者氏名下段
            rec_WL.HOGOSHA_ZOKUGARAMEI := ' ';  --保護者続柄名
            rec_WL.JIDO_ZOKUGARAMEI := ' ';  --児童続柄名
            rec_WL.HOGOSHA_JUSHO := MJIDO_WORK(ICNTM).HOGOSHA_CHOMEI || MJIDO_WORK(ICNTM).HOGOSHA_BANCHI || MJIDO_WORK(ICNTM).HOGOSHA_KATAGAKI;  --保護者町名番地方書
            --保護者郵便番号
            IF MJIDO_WORK(ICNTM).HOGOSHA_YUBIN_NO IS NOT NULL AND LENGTH(MJIDO_WORK(ICNTM).HOGOSHA_YUBIN_NO) > 3 THEN
               rec_WL.HOGOSHA_YUBIN_NO := SUBSTR(MJIDO_WORK(ICNTM).HOGOSHA_YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNTM).HOGOSHA_YUBIN_NO,4);
            ELSE
               rec_WL.HOGOSHA_YUBIN_NO := NULL;
            END IF;
            rec_WL.HOGOSHA_JUSHO_JODAN := MJIDO_WORK(ICNTM).KON_JUSHO_JODAN;  --保護者住所上段
            rec_WL.HOGOSHA_JUSHO_GEDAN := MJIDO_WORK(ICNTM).KON_JUSHO_GEDAN;  --保護者住所下段
            rec_WL.KIJUNBI := ' ';  --基準日
            rec_WL.KAISHIBI := VSTART2;  --条件抽出開始日
            rec_WL.SHURYOBI := VEND2;  --条件抽出終了日
            rec_WL.JINKAKU_KBN := MJIDO_WORK(ICNTM).JINKAKU_KBN;  --人格区分
            rec_WL.BREAK_NO := NULL;  --改ページキー
            rec_WL.WSNUM := g_sWSNUM;  --端末番号
            rec_WL.BATCHKBN := c_BATCH;  --即時バッチ区分
            rec_WL.JOBNUM := g_nJOBNUM;  --ジョ
            -- １レコードのイメージをセット
            ICNTM :=ICNTM+1;

            INSERT INTO GKBWL240R002 VALUES rec_WL;
        END LOOP;
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_JIDO_WK_ITIRAN_CSVFILE', c_IERR, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);  -- 処理ログの出力

        RETURN IFRET;
    END FUNCSET_JIDO_WK_ITIRAN_CSVFILE;
    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        eEXCEPTION       EXCEPTION;
-- 2024/06/12 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発の標準化対応
        o_tITEM       A_CONS_PRM;

    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        --帳票IDに関連な変数にIF内で書く
        IF g_nSTEP_INDEX = 1 THEN
          -- システム日付を西暦数値（YYYYMMDD形式）にする
          ISAKUSEIBI := TO_NUMBER(TRIM(TO_CHAR(SYSDATE, 'YYYYMMDD')));
          -- 取得した条件をそれぞれの変数へセット
          VSTART    := g_VJYOUKEN01;              -- 抽出開始生年月日
          VEND      := g_VJYOUKEN02;              -- 抽出終了生年月日
          VGAKO_KBN := g_VJYOUKEN03;              -- 学校区分
-- 2024/08/02 ZCZL.wangqiwei Update start 0.3.000.001:受入検証No.364の対応
--           IRTN := GKBPK00010.FGKOCDTR(g_VJYOUKEN04,VSYOGAKO_CD);  --小学校コード
--           IRTN := GKBPK00010.FGKOCDTR(g_VJYOUKEN05,VCHUGAKU_CD);  --中学校コード
          bRTN := FUNC_GET_GAKOCD(g_VJYOUKEN04,VSYOGAKO_CD);  --小学校コード
          bRTN := FUNC_GET_GAKOCD(g_VJYOUKEN05,VCHUGAKU_CD);  --中学校コード
-- 2024/08/02 ZCZL.wangqiwei Update end
          --宛名ラベルの氏名出力制御
          IRTN_ATENA := KKAPK0030.FPRMSHUTOKU(g_sGYOUMUCODE,'00ATENA',1,ACONSPRM_ATENA,NLENGTH);
          IF IRTN_ATENA = 1 THEN
             ACONSPRM_ATENA := A_CONS_PRM();
             ACONSPRM_ATENA.EXTEND;
             ACONSPRM_ATENA.EXTEND;
             ACONSPRM_ATENA(1) := 0;
             ACONSPRM_ATENA.EXTEND;
             ACONSPRM_ATENA(2) := 0;
             ACONSPRM_ATENA.EXTEND;
             ACONSPRM_ATENA(3) := 0;
             ACONSPRM_ATENA.EXTEND;
             ACONSPRM_ATENA(4) := 0;
          ELSE
            WHILE (NLENGTH < 4) LOOP
              ACONSPRM_ATENA.EXTEND;
              ACONSPRM_ATENA(NLENGTH+1) := 0;
              NLENGTH := NLENGTH + 1;
            END LOOP;
          END IF;
          --制御情報を取得
          IRTN_SHIMEI := KKAPK0030.FPRMSHUTOKU(g_sGYOUMUCODE,'EQSHIMEI',0,ACONSPRM_SHIMEI,NLENGTH1);
          IF IRTN_SHIMEI =1 THEN
              ACONSPRM_SHIMEI := A_CONS_PRM();
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(1) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(2) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(3) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(4) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(5) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(6) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(7) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(8) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(9) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(10) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(11) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(12) := 0;
              ACONSPRM_SHIMEI.EXTEND;
              ACONSPRM_SHIMEI(13) := 0;
          ELSE
             WHILE (NLENGTH1 < 14) LOOP
               ACONSPRM_SHIMEI.EXTEND;
               ACONSPRM_SHIMEI(NLENGTH1+1) := 0;
               NLENGTH1 := NLENGTH1 + 1;
             END LOOP;
          END IF;
-- 2024/06/12 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
        I_RTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, o_tITEM);
        IF I_RTN = 0 THEN
            FOR j IN 1..o_tITEM.COUNT LOOP
                IF o_tITEM(j) = 'GKB240R001' THEN
                    g_nGKB010_INDEX := j;
                    EXIT;
                END IF;
            END LOOP;
        END IF;
        -- 本名・通称名　出力制御
        I_RTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, o_tITEM);
        IF I_RTN = 0 AND g_nGKB010_INDEX <= o_tITEM.COUNT THEN
            g_sATENA := o_tITEM(g_nGKB010_INDEX);
        END IF;
-- 2024/06/12 ZCZL.wangqiwei Add end

--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
        END IF;
          -- 宛名ラベルワーク（GKBWALABEL）のデータ全件削除
          I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
          IF I_RTN = c_INOT_SUCCESS THEN
              RAISE eEXCEPTION;
          END IF;
          -- 宛名ラベルワーク中間データ作成
          I_RTN := FUNC_GET_JIDO_WK;
          IF I_RTN <> c_ISUCCESS THEN
--  2024/04/22 ZCZL.WUCAO ADD START 0.2.000.001:512_GKB_00027対応
            IF I_RTN = c_INOTFOUND THEN
                GOTO END_EXIT;
            END IF;
--  2024/04/22 ZCZL.WUCAO ADD END 
              RAISE eEXCEPTION;
          END IF;
          -- 宛名ラベルワーク作成
          I_RTN := FUNC_INSERT_JIDO_WK;
          IF I_RTN = c_INOT_SUCCESS THEN
              RAISE eEXCEPTION;
          END IF;
--  2024/04/22 ZCZL.WUCAO DELETE 0.2.000.001:512_GKB_00027対応
--        END IF;

        --帳票出力CSVの作成
        CASE g_rJSTP.CHOHYOID
        WHEN 'GKB240R001' THEN

           -- 宛名ラベル中間データ作成（ＣＳＶ用）
           I_RTN := FUNCGET_JIDO_WK_CSV;
           IF I_RTN <> c_ISUCCESS THEN
               RAISE eEXCEPTION;
           END IF;
           -- 宛名ラベル中間ＣＳＶファイル作成
           I_RTN := FUNCSET_JIDO_WK_CSVFILE;
           IF I_RTN <> c_ISUCCESS THEN
               RAISE eEXCEPTION;
           END IF;

           bRTN := FUNC_B11CSV('GKBWL240R001');

        WHEN 'GKB240R002' THEN

           -- 宛名ラベル中間データ作成（ＣＳＶ用）
           I_RTN := FUNCGET_JIDO_WK_ITIRAN_CSV;
           IF I_RTN <> c_ISUCCESS THEN
               RAISE eEXCEPTION;
           END IF;
           -- 宛名ラベル中間ＣＳＶファイル作成
           I_RTN := FUNCSET_JIDO_WK_ITIRAN_CSVFILE;
           IF I_RTN <> c_ISUCCESS THEN
               RAISE eEXCEPTION;
           END IF;

           bRTN := FUNC_B11CSV('GKBWL240R002');
        ELSE
           NULL;
        END CASE;
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
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
    --  作成者／作成日: ZCZL.HUANGFUCHENGMING   2024/01/22
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
END GKBPB00270;
/