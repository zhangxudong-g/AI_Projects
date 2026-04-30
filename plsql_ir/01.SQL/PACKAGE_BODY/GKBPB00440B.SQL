CREATE OR REPLACE PACKAGE BODY GKBPB00440
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 入学予定者名簿
--  機能概要      : 住基情報より対象者を抽出して入学予定者名簿を作成する。
--              抽出対象者は住基より取得。保護者情報が登録されている場合は
--              学齢簿マスタより保護者情報を取得
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/07/10 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00429対応横展開
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.002:学校コードリスト仕様変更IT_GKB_00090の対応
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
    g_JYOUKEN01                   VARCHAR2(100);
    g_JYOUKEN02                   VARCHAR2(100);
    g_JYOUKEN03                   VARCHAR2(100);
    g_JYOUKEN04                   VARCHAR2(100);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.002:学校コードリスト仕様変更IT_GKB_00090の対応
    --g_JYOUKEN05                   VARCHAR2(100);
    --g_JYOUKEN06                   VARCHAR2(100);
    g_JYOUKEN05                   VARCHAR2(3000);
    g_JYOUKEN06                   VARCHAR2(3000);
--  2024/11/14 ZCZL.WANGYUNING UPDATE END

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --パラメータ変数
    VMSG             NVARCHAR2(4000);
    o_MESSAGE        NVARCHAR2(2000);
    IRET             PLS_INTEGER ;
    IRET1            PLS_INTEGER ;
    IRET2            PLS_INTEGER ;
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
------------------------------------------------------------------------------
--  カーソル定義
------------------------------------------------------------------------------
    TYPE CRATENA_TYPE IS RECORD
    (
      KOJIN_NO            GABTATENAKIHON.KOJIN_NO%TYPE,
      RIREKI_RENBAN       GABTATENAKIHON.RIREKI_RENBAN%TYPE,
      SETAI_NO            GABTATENAKIHON.SETAI_NO%TYPE,
      CHIKU_CD            GABTATENAKIHON.CHIKU_CD%TYPE,
      GYOSEIKU_CD         GABTATENAKIHON.GYOSEIKU_CD%TYPE,
      HAN_CD              GABTATENAKIHON.HAN_CD%TYPE,
      SHOGAKU_CD          GABTATENAKIHON.SHOGAKU_CD%TYPE,
      CHUGAKU_CD          GABTATENAKIHON.CHUGAKU_CD%TYPE,
      SANTEIDANTAI_CD     GABTATENAKIHON.SANTEIDANTAI_CD%TYPE,
      SEINENGAPI          GABTATENAKIHON.SEINENGAPI%TYPE,
      HYOJI_SEINENGAPI    GABTATENAKIHON.HYOJI_SEINENGAPI%TYPE,
      SEIBETSU            GABTATENAKIHON.SEIBETSU%TYPE,
      SHIMEI_KANA         GABTATENAKIHON.SHIMEI_KANA%TYPE,
      SHIMEI_KANJI        GABTATENAKIHON.SHIMEI_KANJI%TYPE,
      CHOMEI              GABTATENAKIHON.CHOMEI%TYPE,
      BANCHI              GABTATENAKIHON.BANCHI%TYPE,
      KATAGAKI            GABTATENAKIHON.KATAGAKI%TYPE,
      JINKAKU_KBN         GABTATENAKIHON.JINKAKU_KBN%TYPE,
      HONMYO_KANA         GABTATENAKIHON.HONMYO_KANA%TYPE,
      HONMYO_KANJI        GABTATENAKIHON.HONMYO_KANJI%TYPE
--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--      ,YOCHIEN_CD         GKBWYOCHIENJOHO.YOCHIEN_CD%TYPE
--      ,YOCHIEN_MEI        GKBWYOCHIENJOHO.YOCHIEN_MEI%TYPE
-- 2025.01.14 JIP.KF ST
--      , GAKUNEN                        GKBTGAKUREIBO.GAKUNEN%TYPE
--      , GAKKO_KBN_CD                   GKBTGAKUREIBO.GAKKO_KBN_CD%TYPE
-- 2025.01.14 JIP.KF ED
      , YUBIN_NO                       GABTATENAKIHON.YUBIN_NO%TYPE
      , KOKUSEKI_CD                    GABTATENAKIHON.KOKUSEKI_CD%TYPE
--      , HOGOSYA_KOJIN_NO               GABTATENAKIHON.KOJIN_NO%TYPE
--      , HOGOSYA_KOKUSEKI_CD            GABTATENAKIHON.KOKUSEKI_CD%TYPE
--  2024/07/10 ZCZL.YANGXINYU UPDATE END
    );

      CRATENA_WORK CRATENA_TYPE;

  ------------------------------------------------------------------------------
  --  定数宣言
  ------------------------------------------------------------------------------
    -- ERROR関連 --
  -- デバック
    N_SQL_CODE      NUMBER;             -- SQLエラーコード
    V_SQL_MSG       NVARCHAR2(255);     -- SQLエラーメッセージ
    c_BERROR      CONSTANT  BOOLEAN :=  FALSE;
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
    -- エラー箇所の値
    c_IERR_POS01   CONSTANT  PLS_INTEGER := 1;         -- メイン処理の［EXCEPTION］
    c_IERR_POS02   CONSTANT  PLS_INTEGER := 2;         -- 処理条件取得エラー
    c_IERR_POS03   CONSTANT  PLS_INTEGER := 3;         -- ソート条件取得エラー
    c_IERR_POS04   CONSTANT  PLS_INTEGER := 4;         -- 中間テーブル作成時のエラー
    c_IERR_POS05   CONSTANT  PLS_INTEGER := 5;         -- 取得データ読込時のエラー
    c_IERR_POS06   CONSTANT  PLS_INTEGER := 6;         -- ソート条件作成時のエラー
    c_IERR_POS07   CONSTANT  PLS_INTEGER := 7;         -- テーブル削除関数実行時のエラー
    c_IERR_POS08   CONSTANT  PLS_INTEGER := 8;         -- データ追加関数のエラー
    c_IERR_POS09   CONSTANT  PLS_INTEGER := 9;         -- データ追加実行時のエラー
    c_IERR_POS10   CONSTANT  PLS_INTEGER := 10;        -- ソート条件作成時のエラー
    c_IERR_POS11   CONSTANT  PLS_INTEGER := 11;        -- ソート条件がひとつも入っていない時のエラー
    c_IERR_POS12   CONSTANT  PLS_INTEGER := 12;        -- 改頁条件が入っていない時のエラー
    c_IERR_POS14   CONSTANT  PLS_INTEGER := 14;        -- 出力データ作成実行時のエラー
    c_IERR_POS15   CONSTANT  PLS_INTEGER := 15;        -- ＣＳＶファイル作成時のエラー
    c_IERR_POS16   CONSTANT  PLS_INTEGER := 16;        -- 該当データなし
    c_IERR_POS17   CONSTANT  PLS_INTEGER := 17;        -- 改頁条件作成時のエラー
    -- 正常メッセージの値
    c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '入学予定者名簿作成処理が正常終了しました。';
    -- エラーメッセージの値
    c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '入学予定者名簿作成処理が異常終了しました。';
    -- 児童生徒ワーク
    c_VTABLE      CONSTANT  NVARCHAR2(128) := 'GKBWJIDOSHINNYUGAKU';
    -- １頁の最大行数
    c_IMAXROWS     CONSTANT  PLS_INTEGER := 15;
    -- CSVファイル --
    -- 帳票連番（作成順序）
    c_NFILENUMBER  CONSTANT NUMBER(2)      := 1;

    -- システム条件:「児童との関係」判定条件
    c_ISYS_J_KANKEI  CONSTANT  PLS_INTEGER := 120;

  ------------------------------------------------------------------------------
  --  変数宣言
  ------------------------------------------------------------------------------
    ISAKUSEIBI                PLS_INTEGER;
    RG                        GKBTGAKUREIBO%ROWTYPE;
    RL                        GKBTGAKUNENLNK%ROWTYPE;
    RA                        GABTATENAKIHON%ROWTYPE;
    RB                        GABTATENAKIHON%ROWTYPE;
    RC                        GABTSOFUSAKI%ROWTYPE;
    RASO                      GABTSOFUSAKI%ROWTYPE;
    IKOJIN_NO                 NUMBER;
    IHOGOSHA_KOJIN_NO         NUMBER;
    IGAKO_CD                  PLS_INTEGER;
    IMRIREKI_RENBAN           PLS_INTEGER;
    VGAKOMEI                  NVARCHAR2(60);
    VSEINENGAPI               NVARCHAR2(11);
    VSEIBETSU                 NVARCHAR2(2);
--  2024/07/10 ZCZL.YANGXINYU Update 0.3.000.000:新WizLIFE２次開発
--    VSETAI_NO                 NVARCHAR2(7);
    VSETAI_NO                 NVARCHAR2(15);
    VGYOSEIKU_MEI             NVARCHAR2(20);
    VHAN_MEI                  NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00429対応横展開
--    VSANTEIDANTAI_MEI         NVARCHAR2(20);
    VSANTEIDANTAI_MEI         GKBWJIDOSHINNYUGAKU.SANTEIDANTAIMEI%TYPE;
    VHYOUJINENDO              NVARCHAR2(10);
    VSASKUSEIBI               NVARCHAR2(30);
    VHOGOSHA_SHIMEI_JODAN     NVARCHAR2(100);
    VHOGOSHA_SHIMEI_GEDAN     NVARCHAR2(100);
    VJUSHO_JODAN              NVARCHAR2(30);
    VJUSHO_GEDAN              NVARCHAR2(60);
    VCNT                      NVARCHAR2(6);
    VZOKUGARAMEI1             NVARCHAR2(30);
    VZOKUGARAMEI2             NVARCHAR2(30);
    VGAKUNENMEI               NVARCHAR2(20);
    NGAKUNENSEI               NUMBER;
    VGAKUNENSEI               NVARCHAR2(20);
    IKAISISEINENGAPI          PLS_INTEGER;
    VKAISISEINENGAPI          NVARCHAR2(14);
    ISHURYOSEINENGAPI         PLS_INTEGER;
    VSHURYOSEINENGAPI         NVARCHAR2(14);
    IHOGOSHA_ZOKUGARA1        PLS_INTEGER;
    IJIDO_ZOKUGARA1           PLS_INTEGER;
    IJUMIN_NARU_JIYU          PLS_INTEGER;
    IJUMIN_NARU               PLS_INTEGER;
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN            BOOLEAN;
    B_RTN           BOOLEAN;
    I_RTN           PLS_INTEGER;
    -- 処理条件（画面からの引数）
    VNENDO          NVARCHAR2(15);      -- 対象年度
    VGAKUNEN        NVARCHAR2(15);      -- 学年
    VSYURYOGAKUNEN  NVARCHAR2(15);      -- 終了学年
    IGAKO_KBN       NUMBER;             -- 学校区分（1：小学校、2：中学校

--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.002:学校コードリスト仕様変更IT_GKB_00090の対応
    --SHOUGAKKOU_CD   NVARCHAR2(100);             -- 小学校コード
    --CHUUGAKKOU_CD   NVARCHAR2(100);             -- 中学校コード
    SHOUGAKKOU_CD   NVARCHAR2(3000);             -- 小学校コード
    CHUUGAKKOU_CD   NVARCHAR2(3000);             -- 中学校コード
--  2024/11/14 ZCZL.WANGYUNING UPDATE END

      IHOGOSHA_KOOM  NVARCHAR2(100);
      VJINKAKU_KBN       NUMBER;
    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWJIDOSHINNYUGAKU%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK MTJIDO_TYPE;
    TYPE MTGAKUREIBO_TYPE IS TABLE OF GKBTGAKUREIBO%ROWTYPE INDEX BY BINARY_INTEGER;
    MGAKUREIBO_WORK MTGAKUREIBO_TYPE;
    TYPE MTGAKUNEN_LNK_TYPE IS TABLE OF GKBTGAKUNENLNK%ROWTYPE INDEX BY BINARY_INTEGER;
    MGAKUNEN_LNK_WORK MTGAKUNEN_LNK_TYPE;

    TYPE MTSORT_TYPE IS TABLE OF NUMBER(2) INDEX BY BINARY_INTEGER;  -- ソート条件の値の配列宣言
    o_MSORT          MTSORT_TYPE;
    -- ソート条件のレコード
    TYPE MTORDER_REC IS RECORD
    (
      ID      NUMBER(2),              -- 番号（基本的には配列値に１加算された値）
      NAME    NVARCHAR2(100),         -- 項目名
      P_NAME  NVARCHAR2(100),         -- 改頁項目名
      BIKO    NVARCHAR2(100)          -- 備考（日本語名）
    );
    o_NBREAK         NUMBER(2);
    o_ADRESS         PLS_INTEGER;
    o_MOJISU1        PLS_INTEGER;
    o_MOJISU2        PLS_INTEGER;
    o_MOJISU3        PLS_INTEGER;
    o_MOJISU4        PLS_INTEGER;
    o_MOJISU5        PLS_INTEGER;
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
    IKISAI_JUNI      PLS_INTEGER;

    I_SYSTEMJOKEN    PLS_INTEGER;        -- システム条件取得用
    NJ_ZOKUGARACD1   NUMBER(2);          -- 児童.続柄1
--  2024/07/10 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
    g_nGKB120R001_INDEX     NUMBER;           --学予定者名簿_インデックス番号
    g_nGKB120R001_CTL       NUMBER;           --学予定者名簿_出力制御

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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        v_cmb               DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/14 ZCZL.WANGYUNING ADD 0.3.000.002:学校コードリスト仕様変更IT_GKB_00090の対応
        objShogakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
        objChugakkoCd  DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/14 ZCZL.WANGYUNING ADD END
    BEGIN

        g_JYOUKEN01 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtNendo');           --表題年度
        g_JYOUKEN02 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSeinenGappiStart');--生年月日 期間(開始)
        g_JYOUKEN03 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSeinenGappiEnd');  --生年月日 期間(終了)
        v_cmb       := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbHyodai');    --表題
        g_JYOUKEN04 := v_cmb(1);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.002:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_JYOUKEN05 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtShogakkoCd');      --小学校コード
        --g_JYOUKEN06 := KKBPK5551.GETPARMS(g_nJOBNUM,'txtChugakkoCd');      --中学校コード
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtShogakkoCd');
        g_JYOUKEN05 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShogakkoCd',0, objShogakkoCd);--小学校コード
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtChugakkoCd');
        g_JYOUKEN06 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtChugakkoCd',0, objChugakkoCd);--中学校コード
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
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
    --  機能概要      : 年度チェック
    --  パラメータ    : i_VNENDO
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
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
    --  機能概要      : 日付チェック
    --  パラメータ    : i_VHIZUKE
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
    --------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    BRET BOOLEAN ;
    TEMP_DATE DATE;
    BEGIN
      IRET := 0 ;
      --日付
      BEGIN
        IF i_VHIZUKE IS NOT NULL THEN
           IF LENGTH(i_VHIZUKE) <> 7 THEN
              IRET := 1;
           ELSE
              IWAREKIHIDUKEIO  := TO_NUMBER(i_VHIZUKE);
              ISEIREKIHIDUKEIO := 0;
           END IF;
        ELSE
          IRET := 1;
        END IF;


      IF IRET = 0 AND LENGTH(IWAREKIHIDUKEIO) = 7 THEN
        BRET := KKAPK0020.FDAYEDIT(IWAREKIHIDUKEIO, ISEIREKIHIDUKEIO,
                                    VEDIT1O, VEDIT2O, VEDIT3O,
                                    VGENGOKANJIO, VGENGOKIGOO,
                                    IWAREKINENO, ISEIREKINENO,
                                    IWAREKINENGETUO, ITUKIO, IDAYO,
                                    IWAREKIHIDUKEO, ISEIREKIHIDUKEO);
          TEMP_DATE := TO_DATE(ISEIREKIHIDUKEIO,'YYYYMMDD');
        IF BRET = FALSE THEN
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
    --  機能概要      : 日付の大小チェック
    --  パラメータ    : i_VHIDUKE1
    --              i_VHIDUKE2
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
    --------------------------------------------------------
    FUNCTION FUNCHIKAKUCHK( i_VHIDUKE1 IN NVARCHAR2, i_VHIDUKE2 IN NVARCHAR2 ) RETURN NUMBER IS
      IRET    PLS_INTEGER ;
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
    --  機能概要      : 学校区分チェック
    --  パラメータ    : i_VKUBUN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
    --------------------------------------------------------
    FUNCTION FUNCKUBUNCHK2( i_VKUBUN IN NVARCHAR2 ) RETURN NUMBER IS
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
        IF NOT ( KUBUN IN (1,2) ) THEN
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.002:学校コードリスト仕様変更IT_GKB_00090の対応
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
        VMSG  := '' ;
        IRET  := 0 ;
        IRET1 := 0 ;
        IRET2 := 0 ;

        --条件１のチェック
        IRET := FUNCNENDOCHK( g_JYOUKEN01 ) ;
        IF IRET <> 0 THEN
            VMSG :=VMSG || g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
        END IF ;

        --条件２のチェック
        IRET := FUNCHIZUKECHK( g_JYOUKEN02 ) ;
        IF IRET <> 0 THEN
            IRET2 := 1 ;
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,抽出開始生年月日が正しくありません。,;';
        END IF ;

        --条件３のチェック
        IRET := FUNCHIZUKECHK( g_JYOUKEN03 ) ;
        IF IRET <> 0 THEN
            IRET2 := 1 ;
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,抽出終了生年月日が正しくありません。,;';
        END IF ;

        --条件２と条件３の大小チェックを行う。
        IF IRET1 = 0 AND IRET2 = 0 THEN
          IRET := FUNCHIKAKUCHK( g_JYOUKEN02, g_JYOUKEN03 ) ;
          IF IRET <> 0 THEN
              VMSG := VMSG || g_sGYOUMUCODE || ',99999,開始生年月日と終了生年月日の大小関係が誤っています。,;';
          END IF ;
        END IF ;

        --条件４のチェック
        IRET := FUNCKUBUNCHK2( g_JYOUKEN04 ) ;
        IF IRET <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,学校区分が正しくありません。,;';
        END IF ;

--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.002:学校コードリスト仕様変更IT_GKB_00090の対応
        --条件５のチェック
       --IRET := GKBPK00010.FGCODCHK( g_JYOUKEN05 ) ;
       -- IF IRET <> 0 THEN
       --     VMSG := VMSG || g_sGYOUMUCODE || ',99999,小学校コードが正しくありません。,;';
       -- END IF;
--
       -- --条件６のチェック
       -- IRET := GKBPK00010.FGCODCHK( g_JYOUKEN06 ) ;
       -- IF IRET <> 0 THEN
       --     VMSG := VMSG || g_sGYOUMUCODE || ',99999,中学校コードが正しくありません。,;';
       -- END IF;
        
        --学校区分と小学校コードの関連チェック
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_JYOUKEN05, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            --学校区分と選択された学校の関係性チェック
            IF g_JYOUKEN04 <> '0' THEN
              IF TO_NUMBER(g_JYOUKEN04) <> vGAKOUKBN THEN
                IF VMSG IS NOT NULL THEN
                  VMSG := VMSG || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                ELSE
                  VMSG := VMSG || g_sGYOUMUCODE || ',99999,選択された学校区分以外の学校が選択されています。,;';
                END IF;
              END IF;
            END IF;
        END LOOP;
        --学校区分と中学校コードの関連チェック
        aGAKKOCD_CHK_LST := KKBPK5551.FSplitStr(g_JYOUKEN06, ';');
        FOR i IN 1..aGAKKOCD_CHK_LST.COUNT LOOP
            vGAKOUKBN := TO_NUMBER(SUBSTR(aGAKKOCD_CHK_LST(i), 1, 3));
            --学校区分と選択された学校の関係性チェック
            IF g_JYOUKEN04 <> '0' THEN
              IF TO_NUMBER(g_JYOUKEN04) <> vGAKOUKBN THEN
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
    --  機能概要      : バッチジョブステップテーブルの更新処理
    --  パラメータ    : i_UPD_KBN       更新区分
    --                : i_STEPRTNCODE   実行結果コード
    --                : i_CSV_RCNT      CSV出力件数
    --                : i_CSVFILENAME   CSVファイル名
    --                : i_PRTFILENAME   出力ファイル名
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
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
    --  機能概要      : システム条件取得
    --  パラメータ    : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
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
    --  機能概要      : 児童生徒ワークレコードの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        NNENDO              PLS_INTEGER;                -- 年度
        NGAKUNEN_CD         NUMBER;                     -- 学年コード
        NSYURYOGAKUNEN_CD   NUMBER;                     -- 終了学年コード
        IRTNA               PLS_INTEGER;
        IRTNSANTEIDANTAI    PLS_INTEGER;
        IRTNAH              PLS_INTEGER;
        ICNT                BINARY_INTEGER;             -- 戻り値
        BRTNSASKUSEIBI      BOOLEAN;
        IJUSHO_NAGASA       PLS_INTEGER;
        ISHIMEINAGASA       PLS_INTEGER;
        IRTNZOKUGARA1       PLS_INTEGER;
        IRTNZOKUGARAHERR1   PLS_INTEGER;
        IRTNZOKUGARA2       PLS_INTEGER;
        IRTNZOKUGARAHERR2   PLS_INTEGER;
        NPRTN               NUMBER;
        IRTN                PLS_INTEGER;
        BRTN                BOOLEAN;
        VSQLSEL             VARCHAR2(5000);
        VKOJIN_NO_CD             NVARCHAR2(15);         -- 連携パラメータ用（コードB）
        VKOJIN_NO_CDMEI          NVARCHAR2(50);         -- 連携パラメータ用（コード名称）

        VHOGOFLG        NVARCHAR2(10);      --保護者判定表示サイン
        TYPE TYPECURSOR  IS REF CURSOR;
        CRATENA            TYPECURSOR;
--  2024/07/10 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        o_kOKUMEKANA          NVARCHAR2(100);
        o_kOKUMEEG            NVARCHAR2(100);
        o_kOKUME              NVARCHAR2(100);
        o_sSHIMEIKANA         NVARCHAR2(100);             -- 氏名カナ
        o_sSHIMEI             NVARCHAR2(100);             -- 氏名漢字
        o_sBIRTHDAY           NVARCHAR2(100);             -- 生年月日
        o_vSYOGAKU_CD         NUMBER;                  -- 小学校区コード
        o_vTYUGAKU_CD         NUMBER;                  -- 中学校区コード
        o_vSYOGAKU_NM         NVARCHAR2(300);          -- 小学校区名
        o_vTYUGAKU_NM         NVARCHAR2(300);          -- 中学校区名
--  2024/07/10 ZCZL.YANGXINYU ADD END

    BEGIN
        IFRET := c_INOTFOUND;                 -- 該当なし
        IKAISISEINENGAPI   := TO_NUMBER(VKAISISEINENGAPI);         -- 開始生年月日
        ISHURYOSEINENGAPI  := TO_NUMBER(VSHURYOSEINENGAPI);        -- 終了生年月日
        NGAKUNEN_CD := TO_NUMBER(VGAKUNEN);          -- 学年
        NSYURYOGAKUNEN_CD := TO_NUMBER(VSYURYOGAKUNEN);          -- 学年
        ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        MGAKUREIBO_WORK.DELETE;
        MGAKUNEN_LNK_WORK.DELETE;
        ICNT := 0;
        -- 連携パラメータ取得
        BRTN := KKCPK0011.FCODEHEN('RSTG', 'KNO', 0, VKOJIN_NO_CD, VKOJIN_NO_CDMEI);

        BEGIN

          -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
          VSQLSEL := '';
--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--            VSQLSEL := VSQLSEL || 'SELECT ';
--            VSQLSEL := VSQLSEL || 'GABTATENAKIHON.KOJIN_NO, ';
--            VSQLSEL := VSQLSEL || 'RIREKI_RENBAN, ';
--            VSQLSEL := VSQLSEL || 'SETAI_NO, ';
--            VSQLSEL := VSQLSEL || 'CHIKU_CD, ';
--            VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
--            VSQLSEL := VSQLSEL || 'HAN_CD, ';
--            VSQLSEL := VSQLSEL || 'SHOGAKU_CD, ';
--            VSQLSEL := VSQLSEL || 'CHUGAKU_CD, ';
--            VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
--            VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
--            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
--            VSQLSEL := VSQLSEL || 'SEIBETSU, ';
--            VSQLSEL := VSQLSEL || 'SHIMEI_KANA, ';
--            VSQLSEL := VSQLSEL || 'SHIMEI_KANJI, ';
--            VSQLSEL := VSQLSEL || 'CHOMEI, ';
--            VSQLSEL := VSQLSEL || 'BANCHI, ';
--            VSQLSEL := VSQLSEL || 'KATAGAKI, ';
--            VSQLSEL := VSQLSEL || 'JINKAKU_KBN, ';
--            VSQLSEL := VSQLSEL || 'HONMYO_KANA, ';
--            VSQLSEL := VSQLSEL || 'HONMYO_KANJI';
--            VSQLSEL := VSQLSEL || ', B.YOCHIEN_CD ';
--            VSQLSEL := VSQLSEL || ', B.YOCHIEN_MEI ';
--            VSQLSEL := VSQLSEL || 'FROM GABTATENAKIHON ';
--            VSQLSEL := VSQLSEL || ', (SELECT D.*,';
--            VSQLSEL := VSQLSEL || '          D.KOJIN_NO || KKAPK0010.FChkDgtWiz11(D.KOJIN_NO) AS KOJIN_NO_CDTSUKI';
--            VSQLSEL := VSQLSEL || '     FROM GKBWYOCHIENJOHO D) B ';
--            VSQLSEL := VSQLSEL || 'WHERE GENZON_KBN = 0 ';
--            VSQLSEL := VSQLSEL || 'AND WAREKI_SEINENGAPI BETWEEN '|| IKAISISEINENGAPI ||
--                                  ' AND '|| ISHURYOSEINENGAPI;
--            IF IGAKO_KBN IS NOT NULL THEN
--                IF IGAKO_KBN = 1 AND SHOUGAKKOU_CD IS NOT NULL THEN
--                   VSQLSEL := VSQLSEL || ' AND SHOGAKU_CD IN ('|| SHOUGAKKOU_CD ||') ';
--                END IF;
--                IF IGAKO_KBN = 2 AND CHUUGAKKOU_CD IS NOT NULL THEN
--                   VSQLSEL := VSQLSEL || ' AND CHUGAKU_CD IN ('|| CHUUGAKKOU_CD ||') ';
--                END IF;
--            END IF;
--            IF VKOJIN_NO_CD = 1 THEN
--              VSQLSEL := VSQLSEL || ' AND GABTATENAKIHON.KOJIN_NO = B.KOJIN_NO(+) ';
--            ELSE
--              VSQLSEL := VSQLSEL || ' AND GABTATENAKIHON.KOJIN_NO = B.KOJIN_NO_CDTSUKI(+) ';
--            END IF;
          VSQLSEL := VSQLSEL || 'SELECT ';
          VSQLSEL := VSQLSEL || ' AJ.KOJIN_NO, ';
          VSQLSEL := VSQLSEL || ' AJ.RIREKI_RENBAN, ';
          VSQLSEL := VSQLSEL || ' AJ.SETAI_NO, ';
          VSQLSEL := VSQLSEL || ' AJ.CHIKU_CD, ';
          VSQLSEL := VSQLSEL || ' AJ.GYOSEIKU_CD, ';
          VSQLSEL := VSQLSEL || ' AJ.HAN_CD, ';
          VSQLSEL := VSQLSEL || ' AJ.SHOGAKU_CD, ';
          VSQLSEL := VSQLSEL || ' AJ.CHUGAKU_CD, ';
          VSQLSEL := VSQLSEL || ' AJ.SANTEIDANTAI_CD, ';
          VSQLSEL := VSQLSEL || ' AJ.SEINENGAPI, ';
          VSQLSEL := VSQLSEL || ' AJ.HYOJI_SEINENGAPI, ';
          VSQLSEL := VSQLSEL || ' AJ.SEIBETSU, ';
          VSQLSEL := VSQLSEL || ' AJ.SHIMEI_KANA, ';
          VSQLSEL := VSQLSEL || ' AJ.SHIMEI_KANJI, ';
          VSQLSEL := VSQLSEL || ' AJ.CHOMEI, ';
          VSQLSEL := VSQLSEL || ' AJ.BANCHI, ';
          VSQLSEL := VSQLSEL || ' AJ.KATAGAKI, ';
          VSQLSEL := VSQLSEL || ' AJ.JINKAKU_KBN, ';
          VSQLSEL := VSQLSEL || ' AJ.HONMYO_KANA, ';
          VSQLSEL := VSQLSEL || ' AJ.HONMYO_KANJI, ';
--2025.01.14 JIP.KF ST
--          VSQLSEL := VSQLSEL || ' BO.GAKUNEN, ';
--          VSQLSEL := VSQLSEL || ' BO.GAKKO_KBN_CD, ';
--2025.01.14 JIP.KF ED
          VSQLSEL := VSQLSEL || ' AJ.YUBIN_NO, ';
--          VSQLSEL := VSQLSEL || ' AJ.KOKUSEKI_CD, ';
--2025.01.14 JIP.KF ST
--          VSQLSEL := VSQLSEL || ' AH.KOJIN_NO AS HOGOSYA_KOJIN_NO, ';
--          VSQLSEL := VSQLSEL || ' AH.KOKUSEKI_CD AS HOGOSYA_KOKUSEKI_CD ';
          VSQLSEL := VSQLSEL || ' AJ.KOKUSEKI_CD ';
--2025.01.14 JIP.KF ED
          --2025.01.14 JIP.KF ST
          /*
          VSQLSEL := VSQLSEL || 'FROM GABTATENAKIHON AJ , GABTATENAKIHON AH, GKBTGAKUREIBO BO ';
          VSQLSEL := VSQLSEL || 'WHERE BO.KOJIN_NO = AJ.KOJIN_NO ';
          VSQLSEL := VSQLSEL || ' AND BO.HOGOSYA_KOJIN_NO = AH.KOJIN_NO ';
          VSQLSEL := VSQLSEL || ' AND AJ.GENZON_KBN = 0 ';
          VSQLSEL := VSQLSEL || 'FROM GABTATENAKIHON AJ , GABTATENAKIHON AH ';
          VSQLSEL := VSQLSEL || 'WHERE AJ.KOJIN_NO = AH.KOJIN_NO AND AJ.GENZON_KBN = 0 ';
          */
          VSQLSEL := VSQLSEL || 'FROM GABTATENAKIHON AJ ';
          --VSQLSEL := VSQLSEL || ',(SELECT * FROM GABTATENAKIHON WHERE ZOKUGARACD1 = 1) AH ';
          VSQLSEL := VSQLSEL || 'WHERE AJ.GENZON_KBN = 0 ';
          --VSQLSEL := VSQLSEL || 'AND AJ.SETAI_NO = AH.SETAI_NO(+) ';
          --2025.01.14 JIP.KF ED
          VSQLSEL := VSQLSEL || ' AND AJ.WAREKI_SEINENGAPI BETWEEN '|| IKAISISEINENGAPI || ' AND '|| ISHURYOSEINENGAPI;
          IF IGAKO_KBN = 1 AND SHOUGAKKOU_CD IS NOT NULL THEN
             VSQLSEL := VSQLSEL || ' AND AJ.SHOGAKU_CD IN ('|| SHOUGAKKOU_CD ||') ';
          END IF;
          IF IGAKO_KBN = 2 AND CHUUGAKKOU_CD IS NOT NULL THEN
             VSQLSEL := VSQLSEL || ' AND AJ.CHUGAKU_CD IN ('|| CHUUGAKKOU_CD ||') ';
          END IF;
          --2025.01.14 JIP.KF ST
          --VSQLSEL := VSQLSEL || ' AND BO.SAISHIN_KBN = 0 ';
          --VSQLSEL := VSQLSEL || ' AND BO.SAKUJO_FLG = 0 ';
          --2025.01.14 JIP.KF ED
--  2024/07/10 ZCZL.YANGXINYU UPDATE END
          EXECUTE IMMEDIATE  VSQLSEL;
            OPEN CRATENA  FOR VSQLSEL;
            LOOP
              FETCH  CRATENA INTO CRATENA_WORK ;
              EXIT WHEN CRATENA%NOTFOUND;
--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
/*2025.01.14 JIP.KF ST
              IF GKBFKGKKUGET(CRATENA_WORK.KOJIN_NO, CRATENA_WORK.RIREKI_RENBAN, o_vSYOGAKU_CD, o_vSYOGAKU_NM, o_vTYUGAKU_CD, o_vTYUGAKU_NM) = 0 THEN
                IF IGAKO_KBN = 1 THEN
                  -- 処理条件.学校区分が「1：小学校」の場合
                  IF o_vSYOGAKU_CD <>  CRATENA_WORK.SHOGAKU_CD THEN
                    -- 小学校区コード<>児童生徒新入学カーソルで取得した小学校区コードの場合、スキープし、次のループで実行
                    CONTINUE;
                  END IF;
                ELSIF IGAKO_KBN = 2 THEN
                  -- 処理条件.学校区分が「2：中学校」の場合
                  IF o_vTYUGAKU_CD <> CRATENA_WORK.CHUGAKU_CD THEN
                    -- 中学校区コード<>児童生徒新入学カーソルで取得した中学校区コードの場合、スキープし、次のループで実行
                    CONTINUE;
                  END IF;
                ELSE
                  NULL;
                END IF;
              ELSE
                CONTINUE;
              END IF;
2025.01.14 JIP.KF ED*/
--  2024/07/10 ZCZL.YANGXINYU UPDATE END
              VHOGOFLG := NULL;
              VCNT :=  TO_CHAR(ICNT);
              IRTN := GAAPK0030.FGETATENA(  CRATENA_WORK.KOJIN_NO,
                                          'GKB',
                                          ISAKUSEIBI,
                                          RA,
                                          RASO);
              VJINKAKU_KBN := RA.JINKAKU_KBN;
              GKBSKJDOG(CRATENA_WORK.KOJIN_NO,RG,NPRTN);  --GKBSKJDOGへ修正


              IF NPRTN IN (0,1) THEN       --学齢簿情報が存在する場合OR存在しない場合

                BEGIN
                  SELECT JUMIN_NARU_JIYU,
                       JUMIN_NARU
                  INTO IJUMIN_NARU_JIYU,
                       IJUMIN_NARU
                  FROM GABTJUKIIDO
                  WHERE KOJIN_NO = CRATENA_WORK.KOJIN_NO;

                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      IJUMIN_NARU_JIYU := 0;
                      IJUMIN_NARU := 0;
                    WHEN OTHERS THEN
                      IJUMIN_NARU_JIYU := 0;
                      IJUMIN_NARU := 0;
                  END;

                IWAREKIHIZUKE := 0;
                BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                             CRATENA_WORK.SEINENGAPI,
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
                IF CRATENA_WORK.SEIBETSU = 1 THEN
                   VSEIBETSU := '男';

                ELSIF CRATENA_WORK.SEIBETSU = 2 THEN
                   VSEIBETSU := '女';
                END IF;

                VSETAI_NO :=  TO_CHAR(CRATENA_WORK.SETAI_NO);

                    IF CRATENA_WORK.KOJIN_NO = 2410168 THEN
                    DBMS_OUTPUT.PUT_LINE('CRATENA_WORK.CHUGAKU_CD　'||CRATENA_WORK.CHUGAKU_CD||' '||CRATENA_WORK.KOJIN_NO||' '||IGAKO_CD||VGAKOMEI||NPRTN);
                    END IF;

                IF RG.HOGOSYA_KOJIN_NO > 0 THEN                    --学齢簿情報に保護者が設定されている場合
                   IHOGOSHA_KOJIN_NO := RG.HOGOSYA_KOJIN_NO;
                     IRTN := GAAPK0030.FGETATENA(  RG.HOGOSYA_KOJIN_NO,
                                                 'GKB',
                                                 ISAKUSEIBI,
                                                 RB,
                                                 RC);
                     IRTN := GKBFKZKGMGET(1,                       --児童続柄
                                          RG.ZOKUGARA1,
                                          RG.ZOKUGARA2,
                                          RG.ZOKUGARA3,
                                          RG.ZOKUGARA4,
                                          VZOKUGARAMEI1,
                                          IRTNZOKUGARAHERR1);
                     IRTN := GKBFKZKGMGET(2,                       -- 保護者続柄
                                          RG.HOGOSYA_ZOKUGARA1,
                                          RG.HOGOSYA_ZOKUGARA2,
                                          RG.HOGOSYA_ZOKUGARA3,
                                          RG.HOGOSYA_ZOKUGARA4,
                                          VZOKUGARAMEI2,
                                          IRTNZOKUGARAHERR2);
--  2024/07/10 ZCZL.YANGXINYU DELETE START 0.3.000.000:新WizLIFE２次開発
--                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RB.SHIMEI_KANA;
--                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := RB.SHIMEI_KANJI;
--  2024/07/10 ZCZL.YANGXINYU DELETE END
--  2025.01.14 JIP.KF ST
                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RB.SHIMEI_KANA;
                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := RB.SHIMEI_KANJI;
--  2025.01.14 JIP.KF ED

                   MJIDO_WORK(ICNT).CHOMEI := RB.CHOMEI;         --保護者町名
                   MJIDO_WORK(ICNT).BANCHI := RB.BANCHI;         --保護者番地
                   MJIDO_WORK(ICNT).KATAGAKI := RB.KATAGAKI;     --保護者方書

                IF LENGTH(RB.YUBIN_NO) > 0 AND
                  RG.HOGOSYA_KOJIN_NO <> 0 THEN
                  MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(RB.YUBIN_NO,1,3)||'-'||SUBSTR(RB.YUBIN_NO,4);
                ELSE
                  MJIDO_WORK(ICNT).YUBIN_NO := NULL;
                END IF;
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
                  VHOGOSHA_SHIMEI_JODAN := '';
                  SELECT SHIMEI_KANJI INTO VHOGOSHA_SHIMEI_GEDAN
                    FROM GABTATENAKIHON
                   WHERE KOJIN_NO = RG.HOGOSYA_KOJIN_NO;
                END IF;

                  IJUSHO_NAGASA := LENGTH(RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI);

                  IF IJUSHO_NAGASA > 20 THEN
                     VJUSHO_JODAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,1,20);
                     VJUSHO_GEDAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,21,20);
                  ELSE
                     VJUSHO_JODAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,1,20);
                     VJUSHO_GEDAN := ' ';
                  END IF;

                  IF CRATENA_WORK.KOJIN_NO = 2410168 THEN
                  DBMS_OUTPUT.PUT_LINE('CRATENA_WORK.CHUGAKU_CD　'||CRATENA_WORK.CHUGAKU_CD||' '||CRATENA_WORK.KOJIN_NO||' '||IGAKO_CD||VGAKOMEI||NPRTN);
                  END IF;
              ELSE
                IF   RA.JINKAKU_KBN = 1 THEN
                  IRTN :=  GKBPK00010.FGKJHGS(ISAKUSEIBI,
                                           CRATENA_WORK.KOJIN_NO,
                                            IHOGOSHA_KOJIN_NO,
                                            IHOGOSHA_KOOM);
                ELSE
                  -- 保護者個人番号が０のときNULL
                  --保護者情報がなかったら判定する

                  IRTN := GKBPK00010.FHOGOSHA(ISAKUSEIBI,
                                              CRATENA_WORK.KOJIN_NO,
                                              IHOGOSHA_KOJIN_NO);

                END IF;
                IHOGOSHA_KOJIN_NO := COALESCE(IHOGOSHA_KOJIN_NO,0);
                IF IHOGOSHA_KOJIN_NO > 0 THEN
                   VHOGOFLG := '*';
                   IRTN := GAAPK0030.FGETATENA(  IHOGOSHA_KOJIN_NO,
                                               'GKB',
                                               ISAKUSEIBI,
                                               RB,
                                               RC);
--  2024/07/10 ZCZL.YANGXINYU DELETE START 0.3.000.000:新WizLIFE２次開発
--                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RB.SHIMEI_KANA;
--                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := RB.SHIMEI_KANJI;
--  2024/07/10 ZCZL.YANGXINYU DELETE END
--  2025.01.14 JIP.KF ST
                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RB.SHIMEI_KANA;
                   MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := RB.SHIMEI_KANJI;
--  2025.01.14 JIP.KF ED
                   -- 判定用続柄コードを変換
                   NJ_ZOKUGARACD1 := 0;                 -- 初期化
                   IF RA.ZOKUGARACD1 BETWEEN 10 AND 29 OR RA.ZOKUGARACD1 IN( 71,72,89 ) THEN
                       NJ_ZOKUGARACD1 := 10;            -- 子を再セット
                   END IF;
                   IF I_SYSTEMJOKEN = 1 THEN
                       IF ( RB.ZOKUGARACD1 = 1 AND RB.ZOKUGARACD2 = 0 AND RB.ZOKUGARACD3 = 0 AND RB.ZOKUGARACD4 = 0 )       -- 保護者の続柄（住記）が「世帯主」のみ
                           AND  ( NJ_ZOKUGARACD1 = 10 AND RA.ZOKUGARACD2 = 0 AND RA.ZOKUGARACD3 = 0 AND RA.ZOKUGARACD4 = 0 ) THEN -- 児童の続柄（住記）が「子」のみ
                           IF RB.SEIBETSU = 1 THEN
                              VZOKUGARAMEI2 := '父';
                           ELSIF RB.SEIBETSU = 2 THEN
                              VZOKUGARAMEI2 := '母';
                           END IF;
                       ELSE
                           VZOKUGARAMEI2 := '';
                       END IF;
                   ELSE
                      IF RB.SEIBETSU = 1 THEN
                         --'父';
                         VZOKUGARAMEI2 := '父';
                      ELSIF RB.SEIBETSU = 2 THEN
                         --'母';
                         VZOKUGARAMEI2 := '母';
                      END IF;
                   END IF;

                   --'子';
                   VZOKUGARAMEI1 := '子';
                   MJIDO_WORK(ICNT).CHOMEI := RB.CHOMEI;         --保護者町名
                   MJIDO_WORK(ICNT).BANCHI := RB.BANCHI;         --保護者番地
                   MJIDO_WORK(ICNT).KATAGAKI := RB.KATAGAKI;     --保護者方書
                   IF LENGTH(RB.YUBIN_NO) > 0 THEN
                     MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(RB.YUBIN_NO,1,3)||'-'||SUBSTR(RB.YUBIN_NO,4);
                   ELSE
                     MJIDO_WORK(ICNT).YUBIN_NO := NULL;
                   END IF;
                  SELECT LENGTH(SHIMEI_KANJI)
                    INTO ISHIMEINAGASA
                    FROM GABTATENAKIHON
                   WHERE KOJIN_NO = IHOGOSHA_KOJIN_NO;

                  IF ISHIMEINAGASA > 15 THEN
                    SELECT SUBSTR (SHIMEI_KANJI,1,15) INTO VHOGOSHA_SHIMEI_JODAN
                      FROM GABTATENAKIHON
                     WHERE KOJIN_NO = IHOGOSHA_KOJIN_NO;

                    SELECT SUBSTR (SHIMEI_KANJI,16) INTO VHOGOSHA_SHIMEI_GEDAN
                      FROM GABTATENAKIHON
                     WHERE KOJIN_NO = IHOGOSHA_KOJIN_NO;
                  ELSE
                    VHOGOSHA_SHIMEI_JODAN := '';
                    SELECT SHIMEI_KANJI INTO VHOGOSHA_SHIMEI_GEDAN
                      FROM GABTATENAKIHON
                     WHERE KOJIN_NO = IHOGOSHA_KOJIN_NO;
                  END IF;
                  VHOGOSHA_SHIMEI_JODAN := VHOGOFLG || VHOGOSHA_SHIMEI_JODAN;

                  IJUSHO_NAGASA := LENGTH(RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI);

                  IF IJUSHO_NAGASA > 20 THEN
                     VJUSHO_JODAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,1,20);
                     VJUSHO_GEDAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,21,20);
                  ELSE
                     VJUSHO_JODAN := SUBSTR (RB.CHOMEI||RB.BANCHI||' '||RB.KATAGAKI,1,20);
                     VJUSHO_GEDAN := ' ';
                  END IF;
                ELSE
              -- 保護者個人番号が０のときNULL
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := NULL;
                 MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := NULL;
                 VZOKUGARAMEI1 := NULL;
                 VZOKUGARAMEI2 := NULL;
                 VHOGOSHA_SHIMEI_JODAN := NULL;
                 VHOGOSHA_SHIMEI_GEDAN := NULL;
                 VJUSHO_JODAN := NULL;
                 VJUSHO_GEDAN := NULL;
                 VHOGOFLG := NULL;

                END IF;
              END IF;

              IF IGAKO_KBN = 1 THEN          -- 小学校名簿
                  IF CRATENA_WORK.SHOGAKU_CD <> 0 THEN
                    BEGIN
                     SELECT SYOGAKO_CD,
                            SYOGAKOMEI
                       INTO IGAKO_CD,
                            VGAKOMEI
                       FROM GKBTSHOGAKKO
                       WHERE SYOGAKO_CD = CRATENA_WORK.SHOGAKU_CD;
                     EXCEPTION
                       WHEN NO_DATA_FOUND THEN

                         DBMS_OUTPUT.PUT_LINE('該当小学校なし　'||CRATENA_WORK.SHOGAKU_CD||' '||CRATENA_WORK.KOJIN_NO);
--  2024/07/10 ZCZL.YANGXINYU DELETE 0.3.000.000:新WizLIFE２次開発
                         --IGAKO_CD := CRATENA_WORK.SHOGAKU_CD;  --2025.01.14 JIP.KF
                         IGAKO_CD := CRATENA_WORK.SHOGAKU_CD;
                         VGAKOMEI := ' ';
                     END;
                       VGAKUNENMEI := VGAKUNENSEI || '年生';
                ELSE
--  2024/07/10 ZCZL.YANGXINYU DELETE 0.3.000.000:新WizLIFE２次開発
                       --IGAKO_CD := CRATENA_WORK.SHOGAKU_CD;  --2025.01.14 JIP.KF
                       IGAKO_CD := CRATENA_WORK.SHOGAKU_CD;
                       VGAKOMEI := ' ';
                       VGAKUNENMEI := VGAKUNENSEI || '年生';
                END IF;
              ELSIF IGAKO_KBN = 2 THEN         -- 中学校名簿
--  2024/07/10 ZCZL.YANGXINYU DELETE START 0.3.000.000:新WizLIFE２次開発
--             CRATENA_WORK.YOCHIEN_CD := 0; -- 入学予定者レコード.幼稚園・保育園コード
--             CRATENA_WORK.YOCHIEN_MEI := '　'; -- 入学予定者レコード.幼稚園・保育園名
--  2024/07/10 ZCZL.YANGXINYU DELETE END
                IF CRATENA_WORK.CHUGAKU_CD <> 0 THEN
                  BEGIN
                   SELECT TYUGAKO_CD,
                          TYUGAKOMEI
                     INTO IGAKO_CD,
                          VGAKOMEI
                     FROM GKBTCHUGAKKO
                     WHERE TYUGAKO_CD = CRATENA_WORK.CHUGAKU_CD;
                   EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                       DBMS_OUTPUT.PUT_LINE('該当中学校なし　'||CRATENA_WORK.CHUGAKU_CD||' '||CRATENA_WORK.KOJIN_NO);
--  2024/07/10 ZCZL.YANGXINYU DELETE 0.3.000.000:新WizLIFE２次開発
--                       IGAKO_CD := CRATENA_WORK.CHUGAKU_CD;
                       IGAKO_CD := CRATENA_WORK.CHUGAKU_CD;  --2025.01.14 JIP.KF
                      VGAKOMEI := ' ';
                   END;

                     VGAKUNENSEI := TO_CHAR(NGAKUNENSEI);
                     VGAKUNENMEI := VGAKUNENSEI || '年生';
                ELSE
--  2024/07/10 ZCZL.YANGXINYU DELETE 0.3.000.000:新WizLIFE２次開発
--                     IGAKO_CD := CRATENA_WORK.CHUGAKU_CD;  --2025.01.14 JIP.KF
                     IGAKO_CD := CRATENA_WORK.CHUGAKU_CD;
                     VGAKOMEI := ' ';
                     VGAKUNENMEI := VGAKUNENSEI || '年生';
                END IF;
                IF CRATENA_WORK.KOJIN_NO = 2410168 THEN
                  DBMS_OUTPUT.PUT_LINE('CRATENA_WORK.CHUGAKU_CD　'||CRATENA_WORK.CHUGAKU_CD||' '||CRATENA_WORK.KOJIN_NO||' '||IGAKO_CD||VGAKOMEI||NPRTN);
                END IF;

             END IF;

              VGYOSEIKU_MEI := GAAPK0030.FGYOSEIKUMEI(CRATENA_WORK.SANTEIDANTAI_CD,CRATENA_WORK.GYOSEIKU_CD);
              VHAN_MEI := GAAPK0030.FHANMEI(CRATENA_WORK.SANTEIDANTAI_CD,
                                             CRATENA_WORK.HAN_CD);
              IRTN := GAAPK0030.FJICHINAME(CRATENA_WORK.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);

              NNENDO := TO_NUMBER(VNENDO);          -- 年度
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

              MJIDO_WORK(ICNT).JIDO_KOJIN_NO := CRATENA_WORK.KOJIN_NO;                 --児童個人番号
--  2025.01.14 JIP.KF ST

--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--              IF GKBFKHMCTRL(MJIDO_WORK(ICNT).JIDO_KOJIN_NO, g_rJSTP.Chohyoid, 0, g_nGKB120R001_CTL,o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN
--                MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := o_sSHIMEIKANA;                      --児童氏名かな
--                MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := o_sSHIMEI;                         --児童氏名
--                MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := o_sBIRTHDAY;                        --表示用生年月日
--              END IF;
--              MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := CRATENA_WORK.SHIMEI_KANA;           --児童氏名かな
--              MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := CRATENA_WORK.SHIMEI_KANJI;         --児童氏名
              MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := CRATENA_WORK.SHIMEI_KANA;           --児童氏名かな
              MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := CRATENA_WORK.SHIMEI_KANJI;         --児童氏名
--  2024/07/10 ZCZL.YANGXINYU UPDATE END
--  2025.01.14 JIP.KF ED
             MJIDO_WORK(ICNT).SEINENGAPI := CRATENA_WORK.SEINENGAPI;                  --児童生年月日
--  2024/07/10 ZCZL.YANGXINYU DELETE 0.3.000.000:新WizLIFE２次開発
--  2025.01.14 JIP.KF ST
--              MJIDO_WORK(ICNT).HYOJI_SEINENGAPI :=  ;                        --表示用生年月日
              MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VSEINENGAPI;                        --表示用生年月日
--  2025.01.14 JIP.KF ED
              MJIDO_WORK(ICNT).KANJI_SEINENGAPI := CRATENA_WORK.HYOJI_SEINENGAPI;      --漢字生年月日
              MJIDO_WORK(ICNT).SEIBETSU := CRATENA_WORK.SEIBETSU;                      --性別
              MJIDO_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;                            --表示用性別
              MJIDO_WORK(ICNT).ZOKUGARAMEI1 := VZOKUGARAMEI1;                          --児童続柄
              MJIDO_WORK(ICNT).SETAI_NO := CRATENA_WORK.SETAI_NO;                      --世帯番号
              MJIDO_WORK(ICNT).HYOJI_SETAI_NO := VSETAI_NO;                            --表示用世帯番号
              MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO := IHOGOSHA_KOJIN_NO;
--  2024/07/10 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
--  2025.01.14 JIP.KF ST
--              IF GKBFKHMCTRL(MJIDO_WORK(ICNT).JIDO_KOJIN_NO, g_rJSTP.Chohyoid, 1, g_nGKB120R001_CTL,o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN
--                MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := o_sSHIMEIKANA;                      --保護者氏名かな
--                MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := o_sSHIMEI;                         --保護者氏名漢字
--              END IF;
--              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := ' ';                      --保護者氏名かな
--              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := VHOGOSHA_SHIMEI_JODAN || VHOGOSHA_SHIMEI_GEDAN;                         --保護者氏名漢字
--  2025.01.14 JIP.KF ED
--  2024/07/10 ZCZL.YANGXINYU ADD END
              MJIDO_WORK(ICNT).ZOKUGARAMEI2 := VZOKUGARAMEI2;                          --保護者続柄

--  2024/07/10 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--              MJIDO_WORK(ICNT).GAKUNEN_CD := 0;                                        --学年
-- 2025.01.14 JIP.KF ST
--              MJIDO_WORK(ICNT).GAKUNEN_CD := CRATENA_WORK.GAKUNEN;                     --学年
              MJIDO_WORK(ICNT).GAKUNEN_CD := 0;                                        --学年
-- 2025.01.14 JIP.KF ED
              MJIDO_WORK(ICNT).GAKUNENMEI := ' ';
--  2024/07/10 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
              --IGAKO_CD := GKBFKGKCDGET (CRATENA_WORK.GAKKO_KBN_CD, CRATENA_WORK.KOJIN_NO, 999);  --2025.01.14 JIP.KF
              MJIDO_WORK(ICNT).GAKOKU_CD := IGAKO_CD;                                  --学校コード
              MJIDO_WORK(ICNT).GAKOKUMEI := VGAKOMEI;                                  --学校名
              MJIDO_WORK(ICNT).GYOSEIKU_CD := CRATENA_WORK.GYOSEIKU_CD;                --行政区コード
              MJIDO_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;                           --行政区名
              MJIDO_WORK(ICNT).HAN_CD := CRATENA_WORK.HAN_CD;                          --班コード
              MJIDO_WORK(ICNT).HANMEI := VHAN_MEI;                                     --班名
              MJIDO_WORK(ICNT).SANTEIDANTAI_CD := CRATENA_WORK.SANTEIDANTAI_CD;        --算定団体コード
              MJIDO_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;                   --算定団体名
              MJIDO_WORK(ICNT).NENDO := VHYOUJINENDO;                                  --年度
              MJIDO_WORK(ICNT).KAIPEJI_CD := ' ';                           --
              MJIDO_WORK(ICNT).KAIPEJI := VHOGOFLG;
              MJIDO_WORK(ICNT).SAKUSEIBI := VSASKUSEIBI;                    --作成日
              MJIDO_WORK(ICNT).RENBAN := ICNT + 1;                          --連番
              MJIDO_WORK(ICNT).HYOJI_RENBAN := VCNT;                        --
              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := VHOGOSHA_SHIMEI_JODAN;--保護者氏名
              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN := VHOGOSHA_SHIMEI_GEDAN;--
              MJIDO_WORK(ICNT).KON_JUSHO_JODAN := VJUSHO_JODAN;              --
              MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := VJUSHO_GEDAN;              --
              MJIDO_WORK(ICNT).JIDO_CHOMEI := RA.CHOMEI;                     --児童町名
              MJIDO_WORK(ICNT).JIDO_BANCHI := RA.BANCHI;                     --児童番地
              MJIDO_WORK(ICNT).JIDO_KATAGAKI := RA.KATAGAKI;                 --児童方書
              IF CRATENA_WORK.JINKAKU_KBN = 1 THEN
                MJIDO_WORK(ICNT).JIDO_HONMYO_KANA := CRATENA_WORK.HONMYO_KANA;           --児童本名かな
                MJIDO_WORK(ICNT).JIDO_HONMYO_KANJI := CRATENA_WORK.HONMYO_KANJI;         --児童本名漢字
              ELSE
                MJIDO_WORK(ICNT).JIDO_HONMYO_KANA := NULL;           --児童本名かな
                MJIDO_WORK(ICNT).JIDO_HONMYO_KANJI := NULL;          --児童本名漢字
              END IF;
              MJIDO_WORK(ICNT).YUHEN_KBN  := RA.YUHEN_KBN;                   --郵返区分
              MJIDO_WORK(ICNT).OAZA_CD    := RA.OAZA_CD;                     --大字コード
              MJIDO_WORK(ICNT).HONBAN     := RA.HONBAN;                      --本番
              MJIDO_WORK(ICNT).EDABAN1    := RA.EDABAN1;                     --枝１
              MJIDO_WORK(ICNT).EDABAN2    := RA.EDABAN2;                     --枝２
              MJIDO_WORK(ICNT).EDABAN3    := RA.EDABAN3;                     --枝３
              MJIDO_WORK(ICNT).GAIKU      := RA.GAIKU;                       --街区
              MJIDO_WORK(ICNT).TOU        := RA.TOU;                         --棟
              MJIDO_WORK(ICNT).GOU        := RA.GOU;                         --号
              MJIDO_WORK(ICNT).GENZON_KBN := RA.GENZON_KBN;                  --現存区分
--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--              MJIDO_WORK(ICNT).YOCHIEN_CD := CRATENA_WORK.YOCHIEN_CD;        --児童生徒新入学ワーク格納用変数.幼稚園・保育園コード
--              MJIDO_WORK(ICNT).YOCHIEN_MEI := CRATENA_WORK.YOCHIEN_MEI;      --児童生徒新入学ワーク格納用変数.幼稚園・保育園名
              -- 児童生徒住所上段、住所下段の編集
/*  2025.01.14 JIP.KF ST
              IF LENGTH(CRATENA_WORK.CHOMEI || CRATENA_WORK.BANCHI || '　' || CRATENA_WORK.KATAGAKI) > 20 THEN
                MJIDO_WORK(ICNT).KON_JUSHO_JODAN := SUBSTR (CRATENA_WORK.CHOMEI || CRATENA_WORK.BANCHI || '　' || CRATENA_WORK.KATAGAKI, 1, 20);
                --  2025.01.14 JIP.KF ST
                --MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := SUBSTR (CRATENA_WORK.CHOMEI || CRATENA_WORK.BANCHI || '　' || CRATENA_WORK.KATAGAKI, 21, 40);
                MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := SUBSTR (CRATENA_WORK.CHOMEI || CRATENA_WORK.BANCHI || '　' || CRATENA_WORK.KATAGAKI, 21, 20);
                --  2025.01.14 JIP.KF ED
              ELSE
                MJIDO_WORK(ICNT).KON_JUSHO_JODAN := CRATENA_WORK.CHOMEI || CRATENA_WORK.BANCHI || '　' || CRATENA_WORK.KATAGAKI;
                MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := NULL;
              END IF;
  2025.01.14 JIP.KF ED*/
              -- 国籍コード、国籍名の編集
              IF GKAFKKKMGET(CRATENA_WORK.KOKUSEKI_CD ,o_kOKUMEKANA , o_kOKUME , o_kOKUMEEG) = 0 THEN
                  MJIDO_WORK(ICNT).JIDO_KOKUSEKI_MEI := o_kOKUME ;
              END IF;

              --IF GKAFKKKMGET(CRATENA_WORK.HOGOSYA_KOKUSEKI_CD ,o_kOKUMEKANA , o_kOKUME , o_kOKUMEEG) = 0 THEN
              IF IHOGOSHA_KOJIN_NO > 0 THEN
                  IF GKAFKKKMGET(RB.KOKUSEKI_CD ,o_kOKUMEKANA , o_kOKUME , o_kOKUMEEG) = 0 THEN
                      MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_MEI := o_kOKUME ;
                  END IF;
              END IF;

               --2025.01.21 JPJYS.SSH Start
              --MJIDO_WORK(ICNT).JIDO_YUBIN_NO := CRATENA_WORK.YUBIN_NO;                     -- 児童生徒現住所郵便番号
              MJIDO_WORK(ICNT).JIDO_YUBIN_NO := SUBSTR(CRATENA_WORK.YUBIN_NO,1,3) || '-' || SUBSTR(CRATENA_WORK.YUBIN_NO,4);  -- 児童生徒現住所郵便番号
              --MJIDO_WORK(ICNT).GAKUNENMEI := GKAFKGKNGTEQ(MJIDO_WORK(ICNT).GAKUNEN_CD);    -- 学年名
              MJIDO_WORK(ICNT).GAKUNENMEI := MJIDO_WORK(ICNT).GAKUNEN_CD || '年生';    -- 学年名
               --2025.01.21 JPJYS.SSH End
              MJIDO_WORK(ICNT).YOCHIEN_CD := NULL;                                         -- 幼稚園・保育園コード
              MJIDO_WORK(ICNT).YOCHIEN_MEI := NULL;                                        -- 幼稚園・保育園名
              MJIDO_WORK(ICNT).TSUSHOMEI_KANA := CRATENA_WORK.SHIMEI_KANA;                 -- 通称名カナ
              MJIDO_WORK(ICNT).TSUSHOMEI_KANJI := CRATENA_WORK.SHIMEI_KANJI;               -- 通称名
              MJIDO_WORK(ICNT).ATENA_RIREKI_RENBAN := CRATENA_WORK.RIREKI_RENBAN;          -- 宛名履歴連番
              MJIDO_WORK(ICNT).JIDO_KOKUSEKI_CD := CRATENA_WORK.KOKUSEKI_CD;               -- 児童国籍コード
              MJIDO_WORK(ICNT).JIDO_KON_JUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  CRATENA_WORK.CHOMEI ,CRATENA_WORK.BANCHI, CRATENA_WORK.KATAGAKI, NULL); -- 児童生徒住所
              --MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_CD := CRATENA_WORK.HOGOSYA_KOKUSEKI_CD;    -- 保護者国籍コード
              MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_CD := RB.KOKUSEKI_CD;    -- 保護者国籍コード
--  2024/07/10 ZCZL.YANGXINYU UPDATE END

              IKISAI_JUNI := 0;
              BEGIN
                SELECT KISAI_JUNI INTO IKISAI_JUNI
                  FROM GABTJUKIIDO
                 WHERE KOJIN_NO = CRATENA_WORK.KOJIN_NO;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                     IKISAI_JUNI := 0;
                WHEN OTHERS THEN
                     IKISAI_JUNI := 0;
                END;
              MJIDO_WORK(ICNT).KISAI_JUNI := IKISAI_JUNI;                    --記載順位
              -- 外国人世帯の保護者判定を追加
              MJIDO_WORK(ICNT).JINKAKU_KBN             := VJINKAKU_KBN;
              ICNT := ICNT + 1;               -- カウントアップ
              IFRET := c_ISUCCESS;              -- 正常終了
            ELSE
             NULL;
            END IF;
          END LOOP;
          CLOSE CRATENA;
        EXCEPTION
            WHEN OTHERS THEN
                IF CRATENA%ISOPEN THEN
                    CLOSE CRATENA;
                END IF;
                IFRET := c_INOT_SUCCESS;      -- 異常終了
                -- SQL情報取得
                N_SQL_CODE := SQLCODE;
                V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
                BRTN  :=FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);-- 処理ログの出力
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
        /* その他エラー */
        WHEN OTHERS THEN
            IF CRATENA%ISOPEN THEN
                    CLOSE CRATENA;
            END IF;
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            BRTN  :=FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);-- 処理ログの出力
        RETURN IFRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------
    --  機能概要      : 学齢簿および児童生徒ワーク（GKBWJIDOSHINNYUGAKU）テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
    --------------------------------------------------------
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
        IMAX :=MJIDO_WORK.LAST;

        -- ワーク領域の先頭位置を取得
        IMIN := MJIDO_WORK.FIRST;
        BEGIN
        -- ワーク領域の件数分繰り返し処理を行う
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
                 , JIDO_HONMYO_KANA
                 , JIDO_HONMYO_KANJI
                ,YUHEN_KBN,
                 OAZA_CD,
                 HONBAN,
                 EDABAN1,
                 EDABAN2,
                 EDABAN3,
                 GAIKU,
                 TOU,
                 GOU,
                 GENZON_KBN,
                 KISAI_JUNI,
                 JINKAKU_KBN
                 ,YOCHIEN_CD
                 ,YOCHIEN_MEI
--  2024/07/10 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
                ,TSUSHOMEI_KANA
                ,TSUSHOMEI_KANJI
                ,ATENA_RIREKI_RENBAN
                ,JIDO_KOKUSEKI_CD
                ,JIDO_KOKUSEKI_MEI
                ,JIDO_YUBIN_NO
                ,JIDO_KON_JUSHO
                ,HOGOSHA_KOKUSEKI_CD
                ,HOGOSHA_KOKUSEKI_MEI
--  2024/07/10 ZCZL.YANGXINYU ADD END
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
                 , MJIDO_WORK(ICNT).JIDO_HONMYO_KANA
                 , MJIDO_WORK(ICNT).JIDO_HONMYO_KANJI
                ,MJIDO_WORK(ICNT).YUHEN_KBN,
                 MJIDO_WORK(ICNT).OAZA_CD,
                 MJIDO_WORK(ICNT).HONBAN,
                 MJIDO_WORK(ICNT).EDABAN1,
                 MJIDO_WORK(ICNT).EDABAN2,
                 MJIDO_WORK(ICNT).EDABAN3,
                 MJIDO_WORK(ICNT).GAIKU,
                 MJIDO_WORK(ICNT).TOU,
                 MJIDO_WORK(ICNT).GOU,
                 MJIDO_WORK(ICNT).GENZON_KBN,
                 MJIDO_WORK(ICNT).KISAI_JUNI,
                 MJIDO_WORK(ICNT).JINKAKU_KBN
                 ,MJIDO_WORK(ICNT).YOCHIEN_CD
                 ,MJIDO_WORK(ICNT).YOCHIEN_MEI
--  2024/07/10 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
                ,MJIDO_WORK(ICNT).TSUSHOMEI_KANA
                ,MJIDO_WORK(ICNT).TSUSHOMEI_KANJI
                ,MJIDO_WORK(ICNT).ATENA_RIREKI_RENBAN
                ,MJIDO_WORK(ICNT).JIDO_KOKUSEKI_CD
                ,MJIDO_WORK(ICNT).JIDO_KOKUSEKI_MEI
                ,MJIDO_WORK(ICNT).JIDO_YUBIN_NO
                ,MJIDO_WORK(ICNT).JIDO_KON_JUSHO
                ,MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_CD
                ,MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_MEI
--  2024/07/10 ZCZL.YANGXINYU ADD END
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
                BRTN  :=FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);-- 処理ログの出力
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
            BRTN  :=FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);-- 処理ログの出力
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------
    --  機能概要      : 児童生徒ワーク（CSV）テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
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
        RREC                GKBWJIDOSHINNYUGAKU%ROWTYPE;      -- 児童生徒ワークのレコード変数
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

        IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
           -- ［ORDER BY］句を付加
           VSQLORDER := ' ORDER BY ' || g_rJSTP.ORDERBYCLAUSE;
        END IF;

        VPAGEFD := ' GAKOKU_CD ';
        VPAGENM := ' GAKOKUMEI ';

        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--            VSQLSEL := VSQLSEL || 'NENDO, ';
--            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
--            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
--            VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
--            VSQLSEL := VSQLSEL || 'RENBAN, ';
--            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
--            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
--            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
--            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN, ';
--            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN, ';
--            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1, ';
--            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
--            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
--            VSQLSEL := VSQLSEL || 'KANJI_SEINENGAPI, ';
--            VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN, ';
--            VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN, ';
--            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
--            VSQLSEL := VSQLSEL || 'SANTEIDANTAIMEI, ';
--            VSQLSEL := VSQLSEL || 'JIDO_CHOMEI, ';
--            VSQLSEL := VSQLSEL || 'JIDO_BANCHI, ';
--            VSQLSEL := VSQLSEL || 'JIDO_KATAGAKI, ';
--            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
--            VSQLSEL := VSQLSEL || 'GAKOKUMEI, ';
--            VSQLSEL := VSQLSEL || VPAGEFD || ' KAIPEJI_CD, ';            -- 改頁値を設定
--            VSQLSEL := VSQLSEL || VPAGENM || ' KAIPEJI ';            -- 改頁名を設定
--            VSQLSEL := VSQLSEL || ', JIDO_HONMYO_KANA ';
--            VSQLSEL := VSQLSEL || ', JIDO_HONMYO_KANJI ';
--
--            VSQLSEL := VSQLSEL || ', YUBIN_NO ';
--            VSQLSEL := VSQLSEL || ', GAKOKU_CD ';
--            VSQLSEL := VSQLSEL || ', JIDO_KOJIN_NO ';
--            VSQLSEL := VSQLSEL || ', JINKAKU_KBN ';
--            VSQLSEL := VSQLSEL || ', YOCHIEN_CD ';
--            VSQLSEL := VSQLSEL || ', YOCHIEN_MEI ';
            VSQLSEL := VSQLSEL || 'JIDO_KOJIN_NO, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'KANJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI1, ';
            VSQLSEL := VSQLSEL || 'SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SETAI_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_KOJIN_NO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
            VSQLSEL := VSQLSEL || 'GAKUNEN_CD, ';
            VSQLSEL := VSQLSEL || 'GAKUNENMEI, ';
            VSQLSEL := VSQLSEL || 'GAKOKU_CD, ';
            VSQLSEL := VSQLSEL || 'GAKOKUMEI, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKU_CD, ';
            VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
            VSQLSEL := VSQLSEL || 'HAN_CD, ';
            VSQLSEL := VSQLSEL || 'HANMEI, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAI_CD, ';
            VSQLSEL := VSQLSEL || 'SANTEIDANTAIMEI, ';
            VSQLSEL := VSQLSEL || 'YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'CHOMEI, ';
            VSQLSEL := VSQLSEL || 'BANCHI, ';
            VSQLSEL := VSQLSEL || 'KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'NENDO, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
            VSQLSEL := VSQLSEL || 'SAKUSEIBI, ';
            VSQLSEL := VSQLSEL || 'RENBAN, ';
            VSQLSEL := VSQLSEL || 'HYOJI_RENBAN, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN, ';
            VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_CHOMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_BANCHI, ';
            VSQLSEL := VSQLSEL || 'JIDO_KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'JIDO_HONMYO_KANA, ';
            VSQLSEL := VSQLSEL || 'JIDO_HONMYO_KANJI, ';
            VSQLSEL := VSQLSEL || 'YUHEN_KBN, ';
            VSQLSEL := VSQLSEL || 'OAZA_CD, ';
            VSQLSEL := VSQLSEL || 'HONBAN, ';
            VSQLSEL := VSQLSEL || 'EDABAN1, ';
            VSQLSEL := VSQLSEL || 'EDABAN2, ';
            VSQLSEL := VSQLSEL || 'GENZON_KBN, ';
            VSQLSEL := VSQLSEL || 'KISAI_JUNI, ';
            VSQLSEL := VSQLSEL || 'GAKO_KBN, ';
            VSQLSEL := VSQLSEL || 'KAGAKUNEN, ';
            VSQLSEL := VSQLSEL || 'EDABAN3, ';
            VSQLSEL := VSQLSEL || 'GAIKU, ';
            VSQLSEL := VSQLSEL || 'TOU, ';
            VSQLSEL := VSQLSEL || 'GOU, ';
            VSQLSEL := VSQLSEL || 'JINKAKU_KBN, ';
            VSQLSEL := VSQLSEL || 'YOCHIEN_CD, ';
            VSQLSEL := VSQLSEL || 'YOCHIEN_MEI, ';
            VSQLSEL := VSQLSEL || 'TSUSHOMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'TSUSHOMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'ATENA_RIREKI_RENBAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_KOKUSEKI_CD, ';
            VSQLSEL := VSQLSEL || 'JIDO_KOKUSEKI_MEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_YUBIN_NO, ';
            VSQLSEL := VSQLSEL || 'JIDO_KON_JUSHO, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_KOKUSEKI_CD, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_KOKUSEKI_MEI, ';
            VSQLSEL := VSQLSEL || VPAGEFD || ' KAIPEJI_CD, ';        -- 改頁値を設定
            VSQLSEL := VSQLSEL || VPAGENM || ' KAIPEJI ';            -- 改頁名を設定
--  2024/07/10 ZCZL.YANGXINYU UPDATE END
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWJIDOSHINNYUGAKU ';
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;
            
            -- カーソルのオープン
            I_CUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(I_CUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, RREC.NENDO, 10);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, RREC.KAIPEJI_CD, 500);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, RREC.KAIPEJI, 500);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.SAKUSEIBI, 30);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.RENBAN, 3);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.JIDO_SHIMEI_KANA, 100);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.JIDO_SHIMEI_KANJI, 100);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.HYOJI_SEIBETSU, 2);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.HOGOSHA_SHIMEI_JODAN, 100);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.HOGOSHA_SHIMEI_GEDAN, 100);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.ZOKUGARAMEI1, 30);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.ZOKUGARAMEI2, 30);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.HYOJI_SEINENGAPI, 11);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.KANJI_SEINENGAPI, 22);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.KON_JUSHO_JODAN, 30);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.KON_JUSHO_GEDAN, 30);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.GYOSEIKUMEI, 20);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.SANTEIDANTAIMEI, 20);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.JIDO_CHOMEI, 40);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.JIDO_BANCHI, 40);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.JIDO_KATAGAKI, 60);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.HOGOSHA_SHIMEI_KANA, 100);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.GAKOKUMEI, 20);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, VPAGEFD, 500);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, VPAGENM, 500);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.JIDO_HONMYO_KANA, 100);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.JIDO_HONMYO_KANJI, 100);
--
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.YUBIN_NO, 10);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, RREC.GAKOKU_CD);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, RREC.JIDO_KOJIN_NO);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, RREC.JINKAKU_KBN);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, RREC.YOCHIEN_CD);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, RREC.YOCHIEN_MEI,180);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 1, RREC.JIDO_KOJIN_NO);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 2, RREC.JIDO_SHIMEI_KANA, 100);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 3, RREC.JIDO_SHIMEI_KANJI, 100);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 4, RREC.SEINENGAPI);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 5, RREC.HYOJI_SEINENGAPI, 11);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 6, RREC.KANJI_SEINENGAPI, 22);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 7, RREC.SEIBETSU);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 8, RREC.HYOJI_SEIBETSU, 2);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 9, RREC.ZOKUGARAMEI1, 30);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.SETAI_NO);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.HYOJI_SETAI_NO, 15);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.HOGOSHA_KOJIN_NO);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.HOGOSHA_SHIMEI_KANA, 100);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.HOGOSHA_SHIMEI_KANJI, 100);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.ZOKUGARAMEI2, 30);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.GAKUNEN_CD);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.GAKUNENMEI, 20);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.GAKOKU_CD);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.GAKOKUMEI, 60);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.GYOSEIKU_CD);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.GYOSEIKUMEI, 20);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.HAN_CD);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.HANMEI, 20);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.SANTEIDANTAI_CD);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.SANTEIDANTAIMEI, 20);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.YUBIN_NO, 10);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.CHOMEI, 136);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.BANCHI, 50);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, RREC.KATAGAKI, 300);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, RREC.NENDO, 10);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, RREC.KAIPEJI_CD, 500);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, RREC.KAIPEJI, 500);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, RREC.SAKUSEIBI, 30);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 34, RREC.RENBAN);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 35, RREC.HYOJI_RENBAN, 6);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 36, RREC.HOGOSHA_SHIMEI_JODAN, 100);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 37, RREC.HOGOSHA_SHIMEI_GEDAN, 100);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 38, RREC.KON_JUSHO_JODAN, 30);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 39, RREC.KON_JUSHO_GEDAN, 30);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 40, RREC.JIDO_CHOMEI, 136);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 41, RREC.JIDO_BANCHI, 50);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 42, RREC.JIDO_KATAGAKI, 300);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 43, RREC.JIDO_HONMYO_KANA, 100);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 44, RREC.JIDO_HONMYO_KANJI, 100);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 45, RREC.YUHEN_KBN);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 46, RREC.OAZA_CD);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 47, RREC.HONBAN, 5);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 48, RREC.EDABAN1, 5);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 49, RREC.EDABAN2, 5);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 50, RREC.GENZON_KBN);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 51, RREC.KISAI_JUNI);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 52, RREC.GAKO_KBN);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 53, RREC.KAGAKUNEN, 20);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 54, RREC.EDABAN3, 5);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 55, RREC.GAIKU, 5);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 56, RREC.TOU, 5);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 57, RREC.GOU, 5);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 58, RREC.JINKAKU_KBN);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 59, RREC.YOCHIEN_CD);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 60, RREC.YOCHIEN_MEI, 180);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 61, RREC.TSUSHOMEI_KANA, 100);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 62, RREC.TSUSHOMEI_KANJI, 100);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 63, RREC.ATENA_RIREKI_RENBAN);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 64, RREC.JIDO_KOKUSEKI_CD);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 65, RREC.JIDO_KOKUSEKI_MEI, 60);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 66, RREC.JIDO_YUBIN_NO, 10);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 67, RREC.JIDO_KON_JUSHO, 486);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 68, RREC.HOGOSHA_KOKUSEKI_CD);
              DBMS_SQL.DEFINE_COLUMN(I_CUR, 69, RREC.HOGOSHA_KOKUSEKI_MEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 70, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 71, VPAGENM, 500);
--  2024/07/10 ZCZL.YANGXINYU UPDATE END

            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(I_CUR);

            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(I_CUR) > 0 THEN

                    -- ワーク領域へセット
--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--                    DBMS_SQL.COLUMN_VALUE(I_CUR,  1, MJIDO_WORK(ICNT).NENDO);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR,  2, MJIDO_WORK(ICNT).KAIPEJI_CD);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR,  3, MJIDO_WORK(ICNT).KAIPEJI);
--
--                    DBMS_SQL.COLUMN_VALUE(I_CUR,  4, MJIDO_WORK(ICNT).SAKUSEIBI);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR,  6, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR,  7, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR,  9, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MJIDO_WORK(ICNT).ZOKUGARAMEI1);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MJIDO_WORK(ICNT).ZOKUGARAMEI2);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MJIDO_WORK(ICNT).KANJI_SEINENGAPI);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MJIDO_WORK(ICNT).KON_JUSHO_JODAN);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MJIDO_WORK(ICNT).KON_JUSHO_GEDAN);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MJIDO_WORK(ICNT).GYOSEIKUMEI);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 18, MJIDO_WORK(ICNT).SANTEIDANTAIMEI);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 19, MJIDO_WORK(ICNT).JIDO_CHOMEI);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 20, MJIDO_WORK(ICNT).JIDO_BANCHI);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 21, MJIDO_WORK(ICNT).JIDO_KATAGAKI);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 22, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 23, MJIDO_WORK(ICNT).GAKOKUMEI);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 24, VPAGEFIELD);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 25, VPAGENAME);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 26, MJIDO_WORK(ICNT).JIDO_HONMYO_KANA);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 27, MJIDO_WORK(ICNT).JIDO_HONMYO_KANJI);
--
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 28, MJIDO_WORK(ICNT).YUBIN_NO);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 29, MJIDO_WORK(ICNT).GAKOKU_CD);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 30, MJIDO_WORK(ICNT).JIDO_KOJIN_NO);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 31, MJIDO_WORK(ICNT).JINKAKU_KBN);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 32, MJIDO_WORK(ICNT).YOCHIEN_CD);
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 33, MJIDO_WORK(ICNT).YOCHIEN_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 1, MJIDO_WORK(ICNT).JIDO_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 2, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 3, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 4, MJIDO_WORK(ICNT).SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 5, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 6, MJIDO_WORK(ICNT).KANJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 7, MJIDO_WORK(ICNT).SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 8, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 9, MJIDO_WORK(ICNT).ZOKUGARAMEI1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MJIDO_WORK(ICNT).SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MJIDO_WORK(ICNT).HYOJI_SETAI_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MJIDO_WORK(ICNT).ZOKUGARAMEI2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MJIDO_WORK(ICNT).GAKUNEN_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MJIDO_WORK(ICNT).GAKUNENMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 18, MJIDO_WORK(ICNT).GAKOKU_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 19, MJIDO_WORK(ICNT).GAKOKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 20, MJIDO_WORK(ICNT).GYOSEIKU_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 21, MJIDO_WORK(ICNT).GYOSEIKUMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 22, MJIDO_WORK(ICNT).HAN_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 23, MJIDO_WORK(ICNT).HANMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 24, MJIDO_WORK(ICNT).SANTEIDANTAI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 25, MJIDO_WORK(ICNT).SANTEIDANTAIMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 26, MJIDO_WORK(ICNT).YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 27, MJIDO_WORK(ICNT).CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 28, MJIDO_WORK(ICNT).BANCHI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 29, MJIDO_WORK(ICNT).KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 30, MJIDO_WORK(ICNT).NENDO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 31, MJIDO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 32, MJIDO_WORK(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 33, MJIDO_WORK(ICNT).SAKUSEIBI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 34, MJIDO_WORK(ICNT).RENBAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 35, MJIDO_WORK(ICNT).HYOJI_RENBAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 36, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 37, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 38, MJIDO_WORK(ICNT).KON_JUSHO_JODAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 39, MJIDO_WORK(ICNT).KON_JUSHO_GEDAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 40, MJIDO_WORK(ICNT).JIDO_CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 41, MJIDO_WORK(ICNT).JIDO_BANCHI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 42, MJIDO_WORK(ICNT).JIDO_KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 43, MJIDO_WORK(ICNT).JIDO_HONMYO_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 44, MJIDO_WORK(ICNT).JIDO_HONMYO_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 45, MJIDO_WORK(ICNT).YUHEN_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 46, MJIDO_WORK(ICNT).OAZA_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 47, MJIDO_WORK(ICNT).HONBAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 48, MJIDO_WORK(ICNT).EDABAN1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 49, MJIDO_WORK(ICNT).EDABAN2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 50, MJIDO_WORK(ICNT).GENZON_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 51, MJIDO_WORK(ICNT).KISAI_JUNI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 52, MJIDO_WORK(ICNT).GAKO_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 53, MJIDO_WORK(ICNT).KAGAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 54, MJIDO_WORK(ICNT).EDABAN3);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 55, MJIDO_WORK(ICNT).GAIKU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 56, MJIDO_WORK(ICNT).TOU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 57, MJIDO_WORK(ICNT).GOU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 58, MJIDO_WORK(ICNT).JINKAKU_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 59, MJIDO_WORK(ICNT).YOCHIEN_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 60, MJIDO_WORK(ICNT).YOCHIEN_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 61, MJIDO_WORK(ICNT).TSUSHOMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 62, MJIDO_WORK(ICNT).TSUSHOMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 63, MJIDO_WORK(ICNT).ATENA_RIREKI_RENBAN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 64, MJIDO_WORK(ICNT).JIDO_KOKUSEKI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 65, MJIDO_WORK(ICNT).JIDO_KOKUSEKI_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 66, MJIDO_WORK(ICNT).JIDO_YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 67, MJIDO_WORK(ICNT).JIDO_KON_JUSHO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 68, MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 69, MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 70, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 71, VPAGENAME);
--  2024/07/10 ZCZL.YANGXINYU UPDATE END

                    -- 改頁の指定がある場合
                      -- 以前の改頁項目値と同じ
                      IF VPAGEWORK = VPAGEFIELD THEN
                      -- 以前の改頁項目値と同じ
                        IGYOCNT := IGYOCNT + 1;
                        IGYORENBAN := IGYORENBAN + 1;

                        IF IGYOCNT > c_IMAXROWS THEN
                        -- １頁内の最大行数を超えた
                            IPAGECNT := IPAGECNT + 1;
                            IGYOCNT := 1;
                                VPAGEWORK := VPAGEFIELD;
                        END IF;
                      ELSE
                      -- 改頁必要
                        IPAGECNT := IPAGECNT + 1;
                        IGYOCNT := 1;
                        IGYORENBAN := 1;
                            VPAGEWORK := VPAGEFIELD;
                      END IF;
                    -- 再セットする項目
                    MJIDO_WORK(ICNT).RENBAN := IGYORENBAN;     -- 連番
                    MJIDO_WORK(ICNT).KAIPEJI := VPAGENAME;   -- 改頁名
                    MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEWORK; -- 改頁コード
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
                BRTN  :=FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, SUBSTR(c_VERR_MSG01 || V_SQL_MSG, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);-- 処理ログの出力
        END;
        RETURN FRET;
    END FUNC_GET_JIDO_WK_CSV;
    --------------------------------------------------------
    --  機能概要      : 児童生徒ワークＣＳＶの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
    --------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        IRET                PLS_INTEGER;                -- 戻り値
        BRET                BOOLEAN;                    -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        VDATA               NVARCHAR2(3000);            -- データ（１レコード分）
        r_CHOHYO_001        GKBWL120R001%ROWTYPE;
        CCOUNT              NUMBER:=0;
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        IMAX := MJIDO_WORK.LAST;             -- ワーク領域の件数の最大値
        IMIN := MJIDO_WORK.FIRST;            -- ワーク領域の件数の最小値

        -- 取得した件数分繰り返す

        FOR ICNT IN IMIN..IMAX LOOP
            CCOUNT                            := CCOUNT+1;
            r_CHOHYO_001                      := NULL;
            r_CHOHYO_001.NO                   := CCOUNT;                                --ソート順
            r_CHOHYO_001.NENDO                := MJIDO_WORK(ICNT).NENDO;                --年度
            r_CHOHYO_001.KAIPAGE_CD           := MJIDO_WORK(ICNT).KAIPEJI_CD;           --ブレークキー
            r_CHOHYO_001.KAIPAGE_MEI          := MJIDO_WORK(ICNT).KAIPEJI;              --ブレーク名称
            r_CHOHYO_001.GENZAIBI             := MJIDO_WORK(ICNT).SAKUSEIBI;            --現在日
            r_CHOHYO_001.NUM                  := MJIDO_WORK(ICNT).RENBAN;               --No
            r_CHOHYO_001.SHIMEI_KANA          := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;     --氏名カナ
            r_CHOHYO_001.SHIMEI               := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;    --氏名
            r_CHOHYO_001.SEIBETSU             := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;       --性別
            r_CHOHYO_001.HOGOSHA_SHIMEI_JODAN := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN; --保護者氏名上
            r_CHOHYO_001.HOGOSHA_SHIMEI_GEDAN := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN; --保護者氏名下
            r_CHOHYO_001.HOGOSHA_KANKEI       := MJIDO_WORK(ICNT).ZOKUGARAMEI1;         --保護者との関係
            r_CHOHYO_001.JIDO_ZOKUGARAMEI     := MJIDO_WORK(ICNT).ZOKUGARAMEI2;         --児童との関係
            r_CHOHYO_001.SEINENGAPI           := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;     --生年月日
            r_CHOHYO_001.KANJI_SEINENGAPI     := MJIDO_WORK(ICNT).KANJI_SEINENGAPI;     --漢字生年月日
            r_CHOHYO_001.JUSHO_JODAN          := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;      --住所上
            r_CHOHYO_001.JUSHO_GEDAN          := MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;      --住所下
            r_CHOHYO_001.GYOSEIKU             := MJIDO_WORK(ICNT).GYOSEIKUMEI;          --行政区
            r_CHOHYO_001.JIDO_JUSHO           := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;      --児童住所

            r_CHOHYO_001.JUSHO1               := MJIDO_WORK(ICNT).JIDO_CHOMEI||MJIDO_WORK(ICNT).JIDO_BANCHI||MJIDO_WORK(ICNT).JIDO_KATAGAKI;--住所１
            r_CHOHYO_001.HOGOSHA_SHIMEI_KANA  := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;                                                      --保護者氏名カナ
--  2024/07/10 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--            r_CHOHYO_001.HOGOSHA_SHIMEI_KANJI := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN ||MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;             --保護者氏名
            r_CHOHYO_001.HOGOSHA_SHIMEI_KANJI := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;             --保護者氏名
            r_CHOHYO_001.JUSHO                := MJIDO_WORK(ICNT).KON_JUSHO_JODAN ||MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;                       --住所
            r_CHOHYO_001.SHOGAKKO_MEI         := MJIDO_WORK(ICNT).GAKOKUMEI;            --小学校名
            r_CHOHYO_001.JIDO_SHIMEI_KANA     := MJIDO_WORK(ICNT).JIDO_HONMYO_KANA;     --児童氏名カナ
            r_CHOHYO_001.JIDO_SHIMEI_KANJI    := MJIDO_WORK(ICNT).JIDO_HONMYO_KANJI;    --児童氏名

            r_CHOHYO_001.YUBIN_NO             := MJIDO_WORK(ICNT).YUBIN_NO;             --郵便番号
            r_CHOHYO_001.GAKKOKU_CD           := MJIDO_WORK(ICNT).GAKOKU_CD;            --学校区コード
            r_CHOHYO_001.JIDO_KOJIN_NO        := MJIDO_WORK(ICNT).JIDO_KOJIN_NO;        --児童個人番号
            r_CHOHYO_001.BIT3SHITAGAKUNEN     := '';                                    --下学年
            r_CHOHYO_001.JINKAKU_KBN          := MJIDO_WORK(ICNT).JINKAKU_KBN;          --人格区分
            r_CHOHYO_001.YOCHIEN_CD           := MJIDO_WORK(ICNT).YOCHIEN_CD;           --幼稚園保育園コード
--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--            r_CHOHYO_001.YOCHIEN_MEI          := MJIDO_WORK(ICNT).YOCHIEN_MEI;          --幼稚園保育園名
            r_CHOHYO_001.YOCHIEN_MEI          := NULL;                                  --幼稚園保育園名
            r_CHOHYO_001.SAKUSEIBI := VSASKUSEIBI;                                      --作成日
            r_CHOHYO_001.HOGOSHA_YUBIN_NO      :=  MJIDO_WORK(ICNT).YUBIN_NO;                                                 --保護者郵便番号
            r_CHOHYO_001.GAKUNEN               :=  MJIDO_WORK(ICNT).GAKUNENMEI;                                               --学年
            r_CHOHYO_001.JIDO_KOKUSEKI         :=  MJIDO_WORK(ICNT).JIDO_KOKUSEKI_MEI;                                        --児童生徒国籍
            r_CHOHYO_001.JIDO_YUBIN_NO         :=  MJIDO_WORK(ICNT).JIDO_YUBIN_NO;                                            --児童生徒郵便番号
            r_CHOHYO_001.JIDO_KON_JUSHO        :=  MJIDO_WORK(ICNT).JIDO_KON_JUSHO;                                           --児童生徒住所
            r_CHOHYO_001.HOGOSHA_KOKUSEKI      :=  MJIDO_WORK(ICNT).HOGOSHA_KOKUSEKI_MEI;                                     --保護者国籍
            --r_CHOHYO_001.BREAK_NO             := NULL;                                  --改ページキー
            r_CHOHYO_001.BREAK_NO             := MJIDO_WORK(ICNT).GAKO_KBN || LPAD(MJIDO_WORK(ICNT).GAKOKU_CD, 3, '0'); --改ページキー
--  2024/07/10 ZCZL.YANGXINYU UPDATE END
            r_CHOHYO_001.WSNUM                := g_sWSNUM;                              --端末番号
--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--            r_CHOHYO_001.BATCHKBN             := c_BATCH;                               --即時バッチ区分
            r_CHOHYO_001.BATCHKBN             := 2;                                     --即時バッチ区分
            r_CHOHYO_001.JOBNUM               := g_nJOBNUM;                             --ジョブNO
            -- １レコードのイメージをセット
            INSERT INTO GKBWL120R001 VALUES r_CHOHYO_001;
        END LOOP;
        -- 終了
        RETURN FRET;
    EXCEPTION
        WHEN OTHERS THEN
            FRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            BRTN  :=FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);-- 処理ログの出力
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE;

--  2024/07/10 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------
    --  機能概要      : 学校コード取得
    --  パラメータ    : パラメータ[小学校コード、小学校名]
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.YANGXINYU 2024/07/10
    --------------------------------------------------------
    FUNCTION FUNC_GET_GAKOCD(i_sGAKOCD IN NVARCHAR2, o_sGAKOCD OUT NVARCHAR2) RETURN NUMBER
    IS
        aGAKOCD           KKBPK5551.tySPLIT_tbl;      -- 業務コード（リスト）
--  2024/11/14 ZCZL.WANGYUNING ADD 0.3.000.002:学校コードリスト仕様変更IT_GKB_00090の対応
        nGAKOUCD_TMP  NUMBER; --学校コード
    BEGIN
        -- 引数の業務コード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.002:学校コードリスト仕様変更IT_GKB_00090の対応
        -- 処理ステップを取得
        --FOR i IN 1..aGAKOCD.COUNT LOOP
        --  IF MOD(i, 2) = 1 THEN
        --      IF i = 1 THEN
        --        o_sGAKOCD := aGAKOCD(i);
        --      ELSE
        --        o_sGAKOCD := o_sGAKOCD || ',' || aGAKOCD(i);
        --      END IF;
        --    END IF;
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
        RETURN 0;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 1;
    END FUNC_GET_GAKOCD;
--  2024/07/10 ZCZL.YANGXINYU ADD END

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        eEXCEPTION       EXCEPTION;
--  2024/07/10 ZCZL.YANGXINYU ADD 0.3.000.000:新WizLIFE２次開発
        aRENBAN_PRM      A_CONS_PRM;      -- パラメータの配列

    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

--  2024/07/10 ZCZL.YANGXINYU UPDATE 0.3.000.000:新WizLIFE２次開発
--        DELETE FROM GKBWL120R001 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
        DELETE FROM GKBWL120R001 WHERE BATCHKBN = 2 AND WSNUM = g_sWSNUM;
        -- 取得した条件をそれぞれの変数へセット
        VNENDO := g_JYOUKEN01;                  -- 対象年度
        VNENDO := KKAPK0020.FNENDO(VNENDO,1);
        VKAISISEINENGAPI := g_JYOUKEN02;        -- 開始生年月日
        VSHURYOSEINENGAPI := g_JYOUKEN03;       -- 終了生年月日
        IGAKO_KBN := g_JYOUKEN04;               -- 学校区分

--  2024/07/10 ZCZL.YANGXINYU UPDATE START 0.3.000.000:新WizLIFE２次開発
--        I_RTN := GKBPK00010.FGKOCDTR(g_JYOUKEN05,SHOUGAKKOU_CD);           -- 小学校コード
--        I_RTN := GKBPK00010.FGKOCDTR(g_JYOUKEN06,CHUUGAKKOU_CD);           -- 中学校コード
        I_RTN := FUNC_GET_GAKOCD(g_JYOUKEN05, SHOUGAKKOU_CD);           -- 小学校コード
        I_RTN := FUNC_GET_GAKOCD(g_JYOUKEN06, CHUUGAKKOU_CD);           -- 中学校コード
--  2024/07/10 ZCZL.YANGXINYU UPDATE END

        -- 児童生徒ワーク（GKBWJIDOSHINNYUGAKU）のデータ全件削除
        I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
        -- テスト用にデータ全件削除

        IF I_RTN = c_INOT_SUCCESS THEN
        -- エラーで帰ってきた場合
            B_RTN  :=FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
            RAISE eEXCEPTION;
        END IF;

        I_SYSTEMJOKEN := 0;
        I_SYSTEMJOKEN := FUNC_GET_SYSJOKEN(c_ISYS_J_KANKEI);
--  2024/07/10 ZCZL.YANGXINYU ADD START 0.3.000.000:新WizLIFE２次開発
        -- システム制御設定を取得
        I_RTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aRENBAN_PRM);
        IF I_RTN = 0 THEN
            FOR j IN 1..aRENBAN_PRM.COUNT LOOP
                IF aRENBAN_PRM(j) = 'GKB120R001' THEN
                    g_nGKB120R001_INDEX := j;
                    EXIT;
                END IF;
            END LOOP;
        END IF;

        I_RTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aRENBAN_PRM);
        IF I_RTN = 0 AND g_nGKB120R001_INDEX <= aRENBAN_PRM.COUNT THEN
            g_nGKB120R001_CTL := aRENBAN_PRM(g_nGKB120R001_INDEX);
        END IF;

--  2024/07/10 ZCZL.YANGXINYU ADD END
        -- 児童生徒新入学ワークの作成
        I_RTN := FUNC_GET_JIDO_WK;
        IF I_RTN <> c_ISUCCESS THEN
        -- エラーで帰ってきた場合
            IF I_RTN = c_INOTFOUND THEN
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--                B_RTN  :=FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
              GOTO END_EXIT;
            END IF;
            RAISE eEXCEPTION;
        END IF;
        -- ワークテーブル作成
        I_RTN := FUNC_INSERT_JIDO_WK;
        IF I_RTN = c_INOT_SUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE eEXCEPTION;
        END IF;
        -- 児童生徒ワークデータ作成（ＣＳＶ用）
        I_RTN := FUNC_GET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE eEXCEPTION;
        END IF;
        -- 児童生徒ワークＣＳＶファイル作成
        I_RTN := FUNC_SET_JIDO_WK_CSVFILE;
        IF I_RTN <> c_ISUCCESS THEN
        -- エラーで帰ってきた場合
            RAISE eEXCEPTION;
        END IF;
        --帳票出力CSVの作成
        bRTN := FUNC_B11CSV('GKBWL120R001');
        --最後ロジックの実行
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
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
    --  作成者／作成日: ZCZL.LIUCHANGQUAN   2024/01/03
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
END GKBPB00440;
/