CREATE OR REPLACE PACKAGE BODY GKBPA00080
--1.0.004.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 教育異動通知書作成（即時）
--  機能概要      : 画面からの引数を元に項目を編集して CSVファイルを出力する。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
--------------------------------------------------------
--  変更履歴
--  2024/06/05 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--  2024/08/20 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00018対応
--  2024/09/11 ZCZL.WANGMING UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00072対応
--  2024/10/18 ZCZL.WANGYUNING Update 0.3.000.004:IT_GKB_00281の対応
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00433対応
--  2024/11/12 ZCZL.ZHANGLEI UPDATE 0.3.000.006:IT_GKB_00469仕様変更対応
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.007:IT_GKB_00539仕様変更対応
--  2024/09/11 JPJYS.LIZIZHONG UPDATE 0.3.000.003:IT_GKB_10041 
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応
--  2025/01/08 JPJYS.GL UPDATE 0.3.000.010:品質強化：IT_GKB_10231対応
--  2025/05/15 CTC.LIUJUNHAO UPDATE 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
--  2025/05/20 ZCZL.wanghj Update 1.0.004.000:認証コード名を取得
---------------------------------------------------------
IS
    -- 全処理必須パラメータ
    c_ONLINE                      CONSTANT PLS_INTEGER := 1;   --オンライン
    c_OK                          CONSTANT PLS_INTEGER := 0;   --正常
    c_ERR                         CONSTANT PLS_INTEGER := -1;  --異常
    c_EMF                         CONSTANT PLS_INTEGER := 1;   --印刷ファイル区分(EMF)
    c_PDF                         CONSTANT PLS_INTEGER := 2;   --印刷ファイル区分(PDF)
    c_EMFANDPDF                   CONSTANT PLS_INTEGER := 3;   --印刷ファイル区分(EMFとPDF)
    g_nJOBNUM                     NUMBER;                      --ジョブナンバー
    g_sTANTOCODE                  CHAR(12);                    --担当者コード
    g_sWSNUM                      NVARCHAR2(63);               --端末番号
    g_sRECUPDKBNCODE              CHAR(2);                     --更新処理区分コード
    g_sBUNSHONUMLIST              NVARCHAR2(1000);             --文書番号情報（リスト）
    g_sMESSAGE                    NVARCHAR2(4000);             --メッセージ返却用
    g_rOPRT                       KKATOPRT%ROWTYPE;            --オンラインジョブステップ情報
    g_sCSV_RCNT                   NVARCHAR2(1000);             --CSVファイル出力件数
    g_sCSVFILENAME                NVARCHAR2(1000);             --CSVファイル名
    g_sPRTFILENAME                NVARCHAR2(1000);             --印刷ファイル名
    g_sSTARTDATE                  NVARCHAR2(23);               --開始時刻
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
    /*g_vTOIAWASESAKI1              NVARCHAR2(45);               --お問い合わせ先１
    g_vTOIAWASESAKI2              NVARCHAR2(45);               --お問い合わせ先2
    g_vTOIAWASESAKI3              NVARCHAR2(45);               --お問い合わせ先3*/
    g_vTOIAWASESAKI1              NVARCHAR2(150);               --お問い合わせ先１
    g_vTOIAWASESAKI2              NVARCHAR2(150);               --お問い合わせ先2
    g_vTOIAWASESAKI3              NVARCHAR2(150);               --お問い合わせ先3
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
    g_vKATAGAKI1                  NVARCHAR2(100);              --認証者肩書
    g_vNINSHOSHA_MEI              NVARCHAR2(180);              --認証者名
-- 2024/06/05 ZCZL.muzl Add end
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
    g_vJINKAKU_KBN                NUMBER;                      --人格区分
    g_vKYUGAKKOCHO_FLG            BOOLEAN;                     -- 旧学校長宛作成要否フラグ
    g_vHOGOSHA_FLG                BOOLEAN;                     -- 保護者宛作成要否フラグ
    g_NHOGOSHA_KOJIN_NO_1         NUMBER;                      -- 保護者個人番号１
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 END

    --パラメータ変数
-- 2024/06/05 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--     i_VNEW_TITLE                  NVARCHAR2(1000);             -- 新学校宛表題
--     i_VOLD_TITLE                  NVARCHAR2(1000);             -- 旧学校宛表題
--     i_IIDO_JIYU                   PLS_INTEGER;                 -- 異動事由コード
--     i_VIDO_JIYU_MEI               NVARCHAR2(1000);             -- 異動事由名
-- 2024/06/05 ZCZL.muzl Delete end
    i_IIDO_BI                     PLS_INTEGER;                 -- 異動日
    i_ITODOKEDE_BI                PLS_INTEGER;                 -- 届出日
-- 2024/06/05 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--     i_ISETAI_NO                   NUMBER;                      -- 世帯番号
--     i_VNEW_CHOMEI                 NVARCHAR2(1000);             -- 新住所町名
--     i_VNEW_BANCHI                 NVARCHAR2(1000);             -- 新住所番地
--     i_VNEW_KATAGAKI               NVARCHAR2(1000);             -- 新住所方書
--     i_VOLD_CHOMEI                 NVARCHAR2(1000);             -- 旧住所町名
--     i_VOLD_BANCHI                 NVARCHAR2(1000);             -- 旧住所番地
--     i_VOLD_KATAGAKI               NVARCHAR2(1000);             -- 旧住所方書
--     i_INEW_GAKKO_CD               PLS_INTEGER;                 -- 新学校区コード
--     i_VNEW_GAKKO                  NVARCHAR2(1000);             -- 新学校名
--     i_IOLD_GAKKO_CD               PLS_INTEGER;                 -- 旧学校区コード
-- 2024/06/05 ZCZL.muzl Delete end
--  2024/06/04 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
    i_VOLD_JUSHO                  NVARCHAR2(1000);             -- 旧住所
    i_VOLD_GAKKO                  NVARCHAR2(1000);             -- 旧学校名
--  2024/06/04 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
    i_VOLD_GAKUNEN                NVARCHAR2(1000);             -- 旧学年
    i_VOLD_JIDO_SHIMEI_KANA       NVARCHAR2(1000);             -- 旧児童生徒氏名カナ
    i_VOLD_JIDO_SHIMEI_KANJI      NVARCHAR2(1000);             -- 旧児童生徒氏名漢字
--  2024/10/18 ZCZL.WANGYUNING Update 0.3.000.004:IT_GKB_00281の対応
    --i_NOLD_JIDO_SEIBETSU          PLS_INTEGER;                 -- 旧児童生徒性別
    i_NOLD_JIDO_SEIBETSU          NVARCHAR2(1000);             -- 旧児童生徒性別
    i_NOLD_JIDO_SEINENGAPI        PLS_INTEGER;                 -- 旧児童生徒生年月日
    i_VOLD_HOGOSHA_SHIMEI_KANA    NVARCHAR2(1000);             -- 旧保護者氏名カナ
    i_VOLD_HOGOSHA_SHIMEI_KANJI   NVARCHAR2(1000);             -- 旧保護者氏名漢字
    i_VNEW_JUSHO                  NVARCHAR2(1000);             -- 新住所
    i_VNEW_GAKKO                  NVARCHAR2(1000);             -- 新学校名
    i_VNEW_GAKUNEN                NVARCHAR2(1000);             -- 新学年
    i_VNEW_JIDO_SHIMEI_KANA       NVARCHAR2(1000);             -- 新児童生徒氏名カナ
    i_VNEW_JIDO_SHIMEI_KANJI      NVARCHAR2(1000);             -- 新児童生徒氏名漢字
--  2024/10/18 ZCZL.WANGYUNING Update 0.3.000.004:IT_GKB_00281の対応
    --i_NNEW_JIDO_SEIBETSU          PLS_INTEGER;                 -- 新児童生徒性別
    i_NNEW_JIDO_SEIBETSU          NVARCHAR2(1000);             -- 新児童生徒性別
    i_NNEW_JIDO_SEINENGAPI        PLS_INTEGER;                 -- 新児童生徒生年月日
    i_VNEW_HOGOSHA_SHIMEI_KANA    NVARCHAR2(1000);             -- 新保護者氏名カナ
    i_VNEW_HOGOSHA_SHIMEI_KANJI   NVARCHAR2(1000);             -- 新保護者氏名漢字
    i_VFHAKKORIREKI               NVARCHAR2(1000);             -- 発行履歴
    i_VFHAKKOBUSUU                NVARCHAR2(1000);             -- 発行部数
    i_NDV_KBN                     NVARCHAR2(1000);             -- DV区分
    i_nCHOHYOKBN                  NUMBER;                      --帳票区分
    i_NJIDO_KOJIN_NO_1            NUMBER;                      -- 児童個人番号
    i_IKYUGAKKOCHO_FLG            PLS_INTEGER;                 -- 旧学校長宛作成フラグ
    i_VIINKAI                     NUMBER;                      -- 教育委員会連番
--2024/06/05 ZCZL.muzl Add end
-- 2024/06/05 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--     i_INEW_GYOSEIKU_CD            PLS_INTEGER;                 -- 新行政区コード
--     i_VNEW_GYOSEIKU_MEI           NVARCHAR2(1000);             -- 新行政区名
--     i_IOLD_GYOSEIKU_CD            PLS_INTEGER;                 -- 旧行政区コード
--     i_VOLD_GYOSEIKU_MEI           NVARCHAR2(1000);             -- 旧行政区名
--     i_NJIDO_KOJIN_NO_1            NUMBER;                      -- 児童個人番号
--     i_ISEQ_NO_1                   PLS_INTEGER;                 -- 連番１
--     i_VSHIMEI_KANA_1              NVARCHAR2(1000);             -- 氏名かな１
--     i_VSHIMEI_KANJI_1             NVARCHAR2(1000);             -- 氏名漢字１
--     i_ISEIBETSU_1                 PLS_INTEGER;                 -- 性別１
--     i_ISEINENGAPI_1               PLS_INTEGER;                 -- 生年月日１
--     i_IGAKUNEN_1                  PLS_INTEGER;                 -- 学年１
--     i_NHOGOSHA_KOJIN_NO_1         NUMBER;                      -- 保護者個人番号１
--     i_VHOGOSHA_KANA_1             NVARCHAR2(1000);             -- 保護者名かな１
--     i_VHOGOSHA_KANJI_1            NVARCHAR2(1000);             -- 保護者名漢字１
--     i_NJIDO_KOJIN_NO_2            NUMBER;                      -- 児童個人番号２
--     i_ISEQ_NO_2                   PLS_INTEGER;                 -- 連番２
--     i_VSHIMEI_KANA_2              NVARCHAR2(1000);             -- 氏名かな２
--     i_VSHIMEI_KANJI_2             NVARCHAR2(1000);             -- 氏名漢字２
--     i_ISEIBETSU_2                 PLS_INTEGER;                 -- 性別２
--     i_ISEINENGAPI_2               PLS_INTEGER;                 -- 生年月日２
--     i_IGAKUNEN_2                  PLS_INTEGER;                 -- 学年２
--     i_NHOGOSHA_KOJIN_NO_2         NUMBER;                      -- 保護者個人番号２
--     i_VHOGOSHA_KANA_2             NVARCHAR2(1000);             -- 保護者名かな２
--     i_VHOGOSHA_KANJI_2            NVARCHAR2(1000);             -- 保護者名漢字２
--     i_NJIDO_KOJIN_NO_3            NUMBER;                      -- 児童個人番号３
--     i_ISEQ_NO_3                   PLS_INTEGER;                 -- 連番３
--     i_VSHIMEI_KANA_3              NVARCHAR2(1000);             -- 氏名かな３
--     i_VSHIMEI_KANJI_3             NVARCHAR2(1000);             -- 氏名漢字３
--     i_ISEIBETSU_3                 PLS_INTEGER;                 -- 性別３
--     i_ISEINENGAPI_3               PLS_INTEGER;                 -- 生年月日３
--     i_IGAKUNEN_3                  PLS_INTEGER;                 -- 学年３
--     i_NHOGOSHA_KOJIN_NO_3         NUMBER;                      -- 保護者個人番号３
--     i_VHOGOSHA_KANA_3             NVARCHAR2(1000);             -- 保護者名かな３
--     i_VHOGOSHA_KANJI_3            NVARCHAR2(1000);             -- 保護者名漢字３
--     i_VGAKKO_NINSHO               NVARCHAR2(1000);             -- 学校長向け認証文
--     i_VGAKKO_BIKO                 NVARCHAR2(1000);             -- 学校長向け備考文
--     i_IKYUGAKKOCHO_FLG            PLS_INTEGER;                 -- 旧学校長宛作成フラグ
--     i_ISHORI_BI                   PLS_INTEGER;                 -- 処理日
--     i_ISHORI_JIKAN                PLS_INTEGER;                 -- 処理時間
--     i_VTEIGITAI_ID                NVARCHAR2(1000);             -- 定義体名
--     i_VTEIGITAI_S_ID              NVARCHAR2(1000);             -- 定義体名（新小学１年用）
--     i_VHOGOSHA_KANKEI_1           NVARCHAR2(1000);             -- 保護者との関係１
--     i_VJIDO_KANKEI_1              NVARCHAR2(1000);             -- 児童生徒との関係１
--     i_VHOGOSHA_KANKEI_2           NVARCHAR2(1000);             -- 保護者との関係２
--     i_VJIDO_KANKEI_2              NVARCHAR2(1000);             -- 児童生徒との関係２
--     i_VHOGOSHA_KANKEI_3           NVARCHAR2(1000);             -- 保護者との関係３
--     i_VJIDO_KANKEI_3              NVARCHAR2(1000);             -- 児童生徒との関係３
--     i_VJIDO_HONMYO_KANA_1         NVARCHAR2(1000);             -- 児童本名かな１
--     i_VJIDO_HONMYO_KANJI_1        NVARCHAR2(1000);             -- 児童本名漢字１
--     i_VHOGOSHA_HONMYO_KANA_1      NVARCHAR2(1000);             -- 保護者本名かな１
--     i_VHOGOSHA_HONMYO_KANJI_1     NVARCHAR2(1000);             -- 保護者本名漢字１
--     i_VJIDO_HONMYO_KANA_2         NVARCHAR2(1000);             -- 児童本名かな２
--     i_VJIDO_HONMYO_KANJI_2        NVARCHAR2(1000);             -- 児童本名漢字２
--     i_VHOGOSHA_HONMYO_KANA_2      NVARCHAR2(1000);             -- 保護者本名かな２
--     i_VHOGOSHA_HONMYO_KANJI_2     NVARCHAR2(1000);             -- 保護者本名漢字２
--     i_VJIDO_HONMYO_KANA_3         NVARCHAR2(1000);             -- 児童本名かな３
--     i_VJIDO_HONMYO_KANJI_3        NVARCHAR2(1000);             -- 児童本名漢字３
--     i_VHOGOSHA_HONMYO_KANA_3      NVARCHAR2(1000);             -- 保護者本名かな３
--     i_VHOGOSHA_HONMYO_KANJI_3     NVARCHAR2(1000);             -- 保護者本名漢字３
--     i_VIDO_JIKO                   NVARCHAR2(1000);             -- 異動事項
--     i_VSHUGAKU                    NVARCHAR2(1000);             -- 就学状況
--     i_VIINKAI                     NUMBER;                      -- 教育委員会連番
--     i_JINKAKU_KBN1                PLS_INTEGER;                 -- 児童人格区分1
--     i_JINKAKU_KBN2                PLS_INTEGER;                 -- 児童人格区分2
--     i_JINKAKU_KBN3                PLS_INTEGER;                 -- 児童人格区分3
--     i_TENNYUGAKU_BI               NUMBER;                      -- 転入学年月日
--     i_TENGAKU_BI                  NUMBER;                      -- 転学年月日
-- 2024/06/05 ZCZL.muzl Delete end
    i_IHOGOSHA_FLG                NUMBER;                      -- 保護者宛作成フラグ
    o_VGYOMU_KOIN                 NVARCHAR2(1000);             -- 業務公印ファイル名
    o_VSHUCHO_KOIN                NVARCHAR2(1000);             -- 首長公印
    o_NSQLCODE                    NUMBER;                      -- SQLエラーコード(通常終了時は 0)
    o_VSQLERRM                    NVARCHAR2(1000);             -- SQLエラーメッセージ(通常終了時は NULL)

    -- デバッグモード(ログをファイルに出力します)
    c_BDEBUG_MODE   CONSTANT BOOLEAN := FALSE;
    -- 処理結果
    c_ISUCCESS     CONSTANT PLS_INTEGER := 0;  -- 正常
    c_INOT_SUCCESS CONSTANT PLS_INTEGER := -1; -- 異常
    c_INOT_FOUND   CONSTANT PLS_INTEGER := -9; -- データ無し
    -- 業務コード
    c_VGYOMU_CD    CONSTANT VARCHAR2(4) := 'GKB';
    -- ワークテーブル名
    c_VWKTBL       CONSTANT VARCHAR2(100) := 'GKBWIDOTSUCHI';
    -- 宛先学校長
    c_ISHIN_KYU_KBN_NEW   CONSTANT PLS_INTEGER := 0;   -- 新学校長
    c_ISHIN_KYU_KBN_OLD   CONSTANT PLS_INTEGER := 1;   -- 旧学校長
    c_ISHIN_KYU_KBN_HOGOSHA   CONSTANT PLS_INTEGER := 2;   -- 保護者宛
    -- 新小学１年生フラグ(定義体切り分けで使用)
    c_ISHIN_SHO1_FLG_NOT_SHO1 CONSTANT PLS_INTEGER := 0;
    c_ISHIN_SHO1_FLG_SHO1     CONSTANT PLS_INTEGER := 1;
    -- システム条件
    --  教育異動通知書１票あたりに出力する児童生徒の人数
    c_ISYS_JIDO_PER_PAGE       CONSTANT PLS_INTEGER := 93;
    c_ISYS_SHIN_SHO1_KIRIWAKE  CONSTANT PLS_INTEGER := 98;
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    I_RTN      PLS_INTEGER;       -- 戻り値
    NSQLCODE   NUMBER;            -- SQLエラーコード
    VSQLERRM   NVARCHAR2(150);    -- SQLエラーメッセージ
    IMEISYUTURYOKUSEIGYO               PLS_INTEGER;      -- 本名・通称名出力制御
    IKYOUIKUIINKAIJOUHOU               PLS_INTEGER;      -- 教育委員会情報
    o_MEISYUPRM                        A_CONS_PRM;
    o_KYOIKUPRM                        A_CONS_PRM;
    o_LENGTH                           NUMBER;
    -- システム条件主取得用
    I_SYSTEMJOKEN     PLS_INTEGER;   -- システム条件取得用
    I_JIDO_PER_PAGE   PLS_INTEGER;   -- 1ページに出力する児童生徒の人数
    I_SHIN_SHO1_KIRIWAKE_KBN  PLS_INTEGER;  -- 新小学１年生の異動通知書を別様式に分ける(0:しない,1:する)
    TYPE MTWK  IS TABLE OF GKBWIDOTSUCHI%ROWTYPE INDEX BY BINARY_INTEGER;
    R_WK    MTWK;
    -- ページ番号の開始番号
    I_PAGE_NUM_BASE  PLS_INTEGER := 0;
    -- 定義体名
    VTEIGITAI_ID  NVARCHAR2(1000);
    --------------------------------------------------------
    --  機能概要      : ログ出力処理
    --  パラメータ    : i_sSTEP_NANE       処理単位に任意に付したステップ名
    --                : i_nDEBUG_KBN       デバッグ用か否か(1:デバッグ、0:通常)
    --                : i_nSTATUSID        ログ出力時のステータス(1:異常、0:情報)
    --                : i_sSQLCODE         異常ログ出力時のSQLCODE
    --                : i_sSQLERRM         異常ログ出力時のSQLERRM
    --                : i_sERRMSG          エラーログとして出力する文字列
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_SETLOG(i_sSTEP_NANE IN  NVARCHAR2,
                         i_nDEBUG_KBN IN  NUMBER,
                         i_nSTATUSID  IN  NUMBER,
                         i_sSQLCODE   IN  NVARCHAR2,
                         i_sSQLERRM   IN  NVARCHAR2,
                         i_sERRMSG    IN  NVARCHAR2) RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
    BEGIN
        -- ログ出力（必要数実行する）
        bRTN := KKBPK5551.FSETOLOG (g_sWSNUM,
                                    g_sSTARTDATE,
                                    i_sSTEP_NANE,
                                    i_nDEBUG_KBN,
                                    i_nSTATUSID,
                                    i_sSQLCODE,
                                    i_sSQLERRM,
                                    i_sERRMSG);
        RETURN bRTN;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_SETLOG;
    --------------------------------------------------------
    --  機能概要      : オンライン処理初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_O00INIT RETURN BOOLEAN
    IS
    BEGIN
        -- 初期化
        g_sSTARTDATE := TO_CHAR (SYSTIMESTAMP, 'YYYY/MM/DD HH24:MI:SS.FF3');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_O00INIT;
    --------------------------------------------------------
    --  機能概要      : オンライン処理パラメータ取得処理
    --  パラメータ    : i_vPARAM 処理パラメータテキスト
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_O01PINIT(i_sPARAM IN NVARCHAR2) RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        aCSV_TBL              DBMS_UTILITY.MAXNAME_ARRAY; --分解されたデータを格納するPL/SQL表
        nCSV_CNT              PLS_INTEGER;                --PL/SQL表の要素数
    BEGIN
        -- 引数で受け取ったパラメータをCSVに分解
        bRTN := KKBPK5551.FCSV2TBL (i_sPARAM, nCSV_CNT, aCSV_TBL);

        -- 引数で受け取ったパラメータをグローバル変数に展開
        FOR i IN 1..nCSV_CNT LOOP
            CASE i
--2024/06/05 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--                 WHEN 1  THEN    i_VNEW_TITLE               := aCSV_TBL(i);    -- 新学校宛表題
--                 WHEN 2  THEN    i_VOLD_TITLE               := aCSV_TBL(i);    -- 旧学校宛表題
--                 WHEN 3  THEN    i_IIDO_JIYU                := aCSV_TBL(i);    -- 異動事由コード
--                 WHEN 4  THEN    i_VIDO_JIYU_MEI            := aCSV_TBL(i);    -- 異動事由名
--                 WHEN 5  THEN    i_IIDO_BI                  := aCSV_TBL(i);    -- 異動日
--                 WHEN 6  THEN    i_ITODOKEDE_BI             := aCSV_TBL(i);    -- 届出日
--                 WHEN 7  THEN    i_ISETAI_NO                := aCSV_TBL(i);    -- 世帯番号
--                 WHEN 8  THEN    i_VNEW_CHOMEI              := aCSV_TBL(i);    -- 新住所町名
--                 WHEN 9  THEN    i_VNEW_BANCHI              := aCSV_TBL(i);    -- 新住所番地
--                 WHEN 10 THEN    i_VNEW_KATAGAKI            := aCSV_TBL(i);    -- 新住所方書
--                 WHEN 11 THEN    i_VOLD_CHOMEI              := aCSV_TBL(i);    -- 旧住所町名
--                 WHEN 12 THEN    i_VOLD_BANCHI              := aCSV_TBL(i);    -- 旧住所番地
--                 WHEN 13 THEN    i_VOLD_KATAGAKI            := aCSV_TBL(i);    -- 旧住所方書
--                 WHEN 14 THEN    i_INEW_GAKKO_CD            := aCSV_TBL(i);    -- 新学校区コード
--                 WHEN 15 THEN    i_VNEW_GAKKO               := aCSV_TBL(i);    -- 新学校名
--                 WHEN 16 THEN    i_IOLD_GAKKO_CD            := aCSV_TBL(i);    -- 旧学校区コード
--                 WHEN 17 THEN    i_VOLD_GAKKO               := aCSV_TBL(i);    -- 旧学校名
--                 WHEN 18 THEN    i_INEW_GYOSEIKU_CD         := aCSV_TBL(i);    -- 新行政区コード
--                 WHEN 19 THEN    i_VNEW_GYOSEIKU_MEI        := aCSV_TBL(i);    -- 新行政区名
--                 WHEN 20 THEN    i_IOLD_GYOSEIKU_CD         := aCSV_TBL(i);    -- 旧行政区コード
--                 WHEN 21 THEN    i_VOLD_GYOSEIKU_MEI        := aCSV_TBL(i);    -- 旧行政区名
--                 WHEN 22 THEN    i_NJIDO_KOJIN_NO_1         := aCSV_TBL(i);    -- 児童個人番号
--                 WHEN 23 THEN    i_ISEQ_NO_1                := aCSV_TBL(i);    -- 連番１
--                 WHEN 24 THEN    i_VSHIMEI_KANA_1           := aCSV_TBL(i);    -- 氏名かな１
--                 WHEN 25 THEN    i_VSHIMEI_KANJI_1          := aCSV_TBL(i);    -- 氏名漢字１
--                 WHEN 26 THEN    i_ISEIBETSU_1              := aCSV_TBL(i);    -- 性別１
--                 WHEN 27 THEN    i_ISEINENGAPI_1            := aCSV_TBL(i);    -- 生年月日１
--                 WHEN 28 THEN    i_IGAKUNEN_1               := aCSV_TBL(i);    -- 学年１
--                 WHEN 29 THEN    i_NHOGOSHA_KOJIN_NO_1      := aCSV_TBL(i);    -- 保護者個人番号１
--                 WHEN 30 THEN    i_VHOGOSHA_KANA_1          := aCSV_TBL(i);    -- 保護者名かな１
--                 WHEN 31 THEN    i_VHOGOSHA_KANJI_1         := aCSV_TBL(i);    -- 保護者名漢字１
--                 WHEN 32 THEN    i_NJIDO_KOJIN_NO_2         := aCSV_TBL(i);    -- 児童個人番号２
--                 WHEN 33 THEN    i_ISEQ_NO_2                := aCSV_TBL(i);    -- 連番２
--                 WHEN 34 THEN    i_VSHIMEI_KANA_2           := aCSV_TBL(i);    -- 氏名かな２
--                 WHEN 35 THEN    i_VSHIMEI_KANJI_2          := aCSV_TBL(i);    -- 氏名漢字２
--                 WHEN 36 THEN    i_ISEIBETSU_2              := aCSV_TBL(i);    -- 性別２
--                 WHEN 37 THEN    i_ISEINENGAPI_2            := aCSV_TBL(i);    -- 生年月日２
--                 WHEN 38 THEN    i_IGAKUNEN_2               := aCSV_TBL(i);    -- 学年２
--                 WHEN 39 THEN    i_NHOGOSHA_KOJIN_NO_2      := aCSV_TBL(i);    -- 保護者個人番号２
--                 WHEN 40 THEN    i_VHOGOSHA_KANA_2          := aCSV_TBL(i);    -- 保護者名かな２
--                 WHEN 41 THEN    i_VHOGOSHA_KANJI_2         := aCSV_TBL(i);    -- 保護者名漢字２
--                 WHEN 42 THEN    i_NJIDO_KOJIN_NO_3         := aCSV_TBL(i);    -- 児童個人番号３
--                 WHEN 43 THEN    i_ISEQ_NO_3                := aCSV_TBL(i);    -- 連番３
--                 WHEN 44 THEN    i_VSHIMEI_KANA_3           := aCSV_TBL(i);    -- 氏名かな３
--                 WHEN 45 THEN    i_VSHIMEI_KANJI_3          := aCSV_TBL(i);    -- 氏名漢字３
--                 WHEN 46 THEN    i_ISEIBETSU_3              := aCSV_TBL(i);    -- 性別３
--                 WHEN 47 THEN    i_ISEINENGAPI_3            := aCSV_TBL(i);    -- 生年月日３
--                 WHEN 48 THEN    i_IGAKUNEN_3               := aCSV_TBL(i);    -- 学年３
--                 WHEN 49 THEN    i_NHOGOSHA_KOJIN_NO_3      := aCSV_TBL(i);    -- 保護者個人番号３
--                 WHEN 50 THEN    i_VHOGOSHA_KANA_3          := aCSV_TBL(i);    -- 保護者名かな３
--                 WHEN 51 THEN    i_VHOGOSHA_KANJI_3         := aCSV_TBL(i);    -- 保護者名漢字３
--                 WHEN 52 THEN    i_VGAKKO_NINSHO            := aCSV_TBL(i);    -- 学校長向け認証文
--                 WHEN 53 THEN    i_VGAKKO_BIKO              := aCSV_TBL(i);    -- 学校長向け備考文
--                 WHEN 54 THEN    i_IKYUGAKKOCHO_FLG         := aCSV_TBL(i);    -- 旧学校長宛作成フラグ
--                 WHEN 55 THEN    i_ISHORI_BI                := aCSV_TBL(i);    -- 処理日
--                 WHEN 56 THEN    i_ISHORI_JIKAN             := aCSV_TBL(i);    -- 処理時間
--                 WHEN 57 THEN    i_VTEIGITAI_ID             := aCSV_TBL(i);    -- 定義体名
--                 WHEN 58 THEN    i_VTEIGITAI_S_ID           := aCSV_TBL(i);    -- 定義体名（新小学１年用）
--                 WHEN 59 THEN    i_VHOGOSHA_KANKEI_1        := aCSV_TBL(i);    -- 保護者との関係１
--                 WHEN 60 THEN    i_VJIDO_KANKEI_1           := aCSV_TBL(i);    -- 児童生徒との関係１
--                 WHEN 61 THEN    i_VHOGOSHA_KANKEI_2        := aCSV_TBL(i);    -- 保護者との関係２
--                 WHEN 62 THEN    i_VJIDO_KANKEI_2           := aCSV_TBL(i);    -- 児童生徒との関係２
--                 WHEN 63 THEN    i_VHOGOSHA_KANKEI_3        := aCSV_TBL(i);    -- 保護者との関係３
--                 WHEN 64 THEN    i_VJIDO_KANKEI_3           := aCSV_TBL(i);    -- 児童生徒との関係３
--                 WHEN 65 THEN    i_VJIDO_HONMYO_KANA_1      := aCSV_TBL(i);    -- 児童本名かな１
--                 WHEN 66 THEN    i_VJIDO_HONMYO_KANJI_1     := aCSV_TBL(i);    -- 児童本名漢字１
--                 WHEN 67 THEN    i_VHOGOSHA_HONMYO_KANA_1   := aCSV_TBL(i);    -- 保護者本名かな１
--                 WHEN 68 THEN    i_VHOGOSHA_HONMYO_KANJI_1  := aCSV_TBL(i);    -- 保護者本名漢字１
--                 WHEN 69 THEN    i_VJIDO_HONMYO_KANA_2      := aCSV_TBL(i);    -- 児童本名かな２
--                 WHEN 70 THEN    i_VJIDO_HONMYO_KANJI_2     := aCSV_TBL(i);    -- 児童本名漢字２
--                 WHEN 71 THEN    i_VHOGOSHA_HONMYO_KANA_2   := aCSV_TBL(i);    -- 保護者本名かな２
--                 WHEN 72 THEN    i_VHOGOSHA_HONMYO_KANJI_2  := aCSV_TBL(i);    -- 保護者本名漢字２
--                 WHEN 73 THEN    i_VJIDO_HONMYO_KANA_3      := aCSV_TBL(i);    -- 児童本名かな３
--                 WHEN 74 THEN    i_VJIDO_HONMYO_KANJI_3     := aCSV_TBL(i);    -- 児童本名漢字３
--                 WHEN 75 THEN    i_VHOGOSHA_HONMYO_KANA_3   := aCSV_TBL(i);    -- 保護者本名かな３
--                 WHEN 76 THEN    i_VHOGOSHA_HONMYO_KANJI_3  := aCSV_TBL(i);    -- 保護者本名漢字３
--                 WHEN 77 THEN    i_VIDO_JIKO                := aCSV_TBL(i);    -- 異動事項
--                 WHEN 78 THEN    i_VSHUGAKU                 := aCSV_TBL(i);    -- 就学状況
--                 WHEN 79 THEN    i_VIINKAI                  := aCSV_TBL(i);    -- 教育委員会連番
--                 WHEN 80 THEN    i_JINKAKU_KBN1             := aCSV_TBL(i);    -- 児童人格区分1
--                 WHEN 81 THEN    i_JINKAKU_KBN2             := aCSV_TBL(i);    -- 児童人格区分2
--                 WHEN 82 THEN    i_JINKAKU_KBN3             := aCSV_TBL(i);    -- 児童人格区分3
--                 WHEN 83 THEN    i_TENNYUGAKU_BI            := aCSV_TBL(i);    -- 転入学年月日
--                 WHEN 84 THEN    i_TENGAKU_BI               := aCSV_TBL(i);    -- 転学年月日
--                 WHEN 85 THEN    i_IHOGOSHA_FLG             := aCSV_TBL(i);    -- 保護者宛作成フラグ
--2024/06/04 ZCZL.muzl Delete end
--2024/06/04 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
                WHEN 1   THEN    i_ITODOKEDE_BI                := aCSV_TBL(i);    -- 届出日
                WHEN 2   THEN    i_IIDO_BI                     := aCSV_TBL(i);    -- 異動日
                WHEN 3   THEN    i_VOLD_JUSHO                  := aCSV_TBL(i);    -- 旧住所
                WHEN 4   THEN    i_VOLD_GAKKO                  := aCSV_TBL(i);    -- 旧学校名
                WHEN 5   THEN    i_VOLD_GAKUNEN                := aCSV_TBL(i);    -- 旧学年
                WHEN 6   THEN    i_VOLD_JIDO_SHIMEI_KANA       := aCSV_TBL(i);    -- 旧児童生徒氏名カナ
                WHEN 7   THEN    i_VOLD_JIDO_SHIMEI_KANJI      := aCSV_TBL(i);    -- 旧児童生徒氏名漢字
                WHEN 8   THEN    i_NOLD_JIDO_SEIBETSU          := aCSV_TBL(i);    -- 旧児童生徒性別
                WHEN 9   THEN    i_NOLD_JIDO_SEINENGAPI        := aCSV_TBL(i);    -- 旧児童生徒生年月日
                WHEN 10  THEN    i_VOLD_HOGOSHA_SHIMEI_KANA    := aCSV_TBL(i);    -- 旧保護者氏名カナ
                WHEN 11  THEN    i_VOLD_HOGOSHA_SHIMEI_KANJI   := aCSV_TBL(i);    -- 旧保護者氏名漢字
                WHEN 12  THEN    i_VNEW_JUSHO                  := aCSV_TBL(i);    -- 新住所
                WHEN 13  THEN    i_VNEW_GAKKO                  := aCSV_TBL(i);    -- 新学校名
                WHEN 14  THEN    i_VNEW_GAKUNEN                := aCSV_TBL(i);    -- 新学年
                WHEN 15  THEN    i_VNEW_JIDO_SHIMEI_KANA       := aCSV_TBL(i);    -- 新児童生徒氏名カナ
                WHEN 16  THEN    i_VNEW_JIDO_SHIMEI_KANJI      := aCSV_TBL(i);    -- 新児童生徒氏名漢字
                WHEN 17  THEN    i_NNEW_JIDO_SEIBETSU          := aCSV_TBL(i);    -- 新児童生徒性別
                WHEN 18  THEN    i_NNEW_JIDO_SEINENGAPI        := aCSV_TBL(i);    -- 新児童生徒生年月日
                WHEN 19  THEN    i_VNEW_HOGOSHA_SHIMEI_KANA    := aCSV_TBL(i);    -- 新保護者氏名カナ
                WHEN 20  THEN    i_VNEW_HOGOSHA_SHIMEI_KANJI   := aCSV_TBL(i);    -- 新保護者氏名漢字
                WHEN 21  THEN    i_VFHAKKORIREKI               := aCSV_TBL(i);    -- 発行履歴
                WHEN 22  THEN    i_VFHAKKOBUSUU                := aCSV_TBL(i);    -- 発行部数
                WHEN 23  THEN    i_NDV_KBN                     := aCSV_TBL(i);    -- DV区分
                WHEN 24  THEN    i_IHOGOSHA_FLG                := aCSV_TBL(i);    -- 保護者宛作成フラグ
                WHEN 25  THEN    i_nCHOHYOKBN                  := aCSV_TBL(i);    -- 帳票区分
                WHEN 26  THEN    i_NJIDO_KOJIN_NO_1            := aCSV_TBL(i);    -- 児童個人番号
                WHEN 27  THEN    i_IKYUGAKKOCHO_FLG            := aCSV_TBL(i);    -- 旧学校長宛作成フラグ
                WHEN 28  THEN    i_VIINKAI                     := aCSV_TBL(i);    -- 教育委員会連番
--2024/06/04 ZCZL.muzl Add end

                ELSE NULL;
            END CASE;
        END LOOP;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_O01PINIT;
    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得（帳票）
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYONUM    帳票番号
    --                : o_tCHOHYORECODE  オンライン帳票テーブルのレコード情報
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_O02PINIT(i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYONUM   IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
    BEGIN
        --ステップ情報クリア
        g_rOPRT := NULL;
        --ステップ情報の取得
        bRTN := KKBPK5551.FOPRTGet (i_sGYOUMUCODE, i_sCHOHYONUM, g_rOPRT);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_O02PINIT;
    --------------------------------------------------------
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_sGYOUMUCODE     業務コード
    --                : i_TBLNAME         テーブル名
    --                : i_sCHOHYOID       帳票ID
    --                : o_sCSV_RCNT       CSVファイル出力件数
    --                : o_sCSVFILENAME    CSVファイル名
    --                : o_sPRTFILENAME    印刷ファイル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_O20CSV(i_sGYOUMUCODE  IN  NVARCHAR2,
                         i_TBLNAME      IN  NVARCHAR2,
                         i_sCHOHYOID    IN  NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        nCSV_RCNT             NUMBER;                     --CSVファイル出力件数
        sCSVFILENAME          NVARCHAR2(1000);            --CSVファイル名
        sPRTFILENAME          NVARCHAR2(1000);            --印刷ファイル名
        vOUTCSVSQL            NVARCHAR2(1000);            --SQL文
        nOUTCSVCNT            NUMBER;                     --CSV出力件数
    BEGIN
        --関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'CSV出力処理', 0, 0, '', '', '処理開始');
        vOUTCSVSQL := 'SELECT COUNT(1) FROM ' || i_TBLNAME || ' WHERE ';
        vOUTCSVSQL := vOUTCSVSQL || ' JOBNUM = ' || g_nJOBNUM;
        vOUTCSVSQL := vOUTCSVSQL || ' AND WSNUM = ' || '''' || g_sWSNUM || '''';
        vOUTCSVSQL := vOUTCSVSQL || ' AND BATCHKBN = ' || c_ONLINE;
        EXECUTE IMMEDIATE vOUTCSVSQL INTO nOUTCSVCNT;
        --0件の場合、CSVを出力しない
        IF nOUTCSVCNT = 0 THEN
            bRTN := FUNC_SETLOG(g_rOPRT.CHOHYONAME || 'CSV出力処理', 0, 0, '', '', i_TBLNAME || 'テーブル、' || 'ジョブID ' || g_nJOBNUM || 'の件数が0件ので、CSVを出力しません。処理終了');
            RETURN TRUE;
        END IF;
        IF g_rOPRT.PRTFILEKBN = c_EMFANDPDF THEN
            --CSV出力処理(EMF)
            bRTN := KKBPK5551.FCSVPUT (g_nJOBNUM,
                                       i_sGYOUMUCODE,
                                       g_sWSNUM,
                                       c_ONLINE,
                                       i_TBLNAME,
                                       i_sCHOHYOID,
                                       g_rOPRT.CHOHYOFORM,
                                       c_EMF,
                                       g_rOPRT.TEIKEIBUNNUM_LIST,
                                       nCSV_RCNT,
                                       sCSVFILENAME,
                                       sPRTFILENAME);
            --返却用パラメータを設定する
            g_sCSV_RCNT := g_sCSV_RCNT || nCSV_RCNT || ';';          --CSVファイル出力件数
            g_sCSVFILENAME := g_sCSVFILENAME || sCSVFILENAME || ';'; --CSVファイル名
            g_sPRTFILENAME := g_sPRTFILENAME || sPRTFILENAME || ';'; --印刷ファイル名
            --CSV出力処理(PDF)
            bRTN := KKBPK5551.FCSVPUT (g_nJOBNUM,
                                       i_sGYOUMUCODE,
                                       g_sWSNUM,
                                       c_ONLINE,
                                       i_TBLNAME,
                                       i_sCHOHYOID,
                                       g_rOPRT.CHOHYOFORM,
                                       c_PDF,
                                       g_rOPRT.TEIKEIBUNNUM_LIST,
                                       nCSV_RCNT,
                                       sCSVFILENAME,
                                       sPRTFILENAME);
            --返却用パラメータを追加設定する
            g_sCSVFILENAME := g_sCSVFILENAME || sCSVFILENAME || ';'; --CSVファイル名
            g_sPRTFILENAME := g_sPRTFILENAME || sPRTFILENAME || ';'; --印刷ファイル名
        ELSE
            --CSV出力処理
            bRTN := KKBPK5551.FCSVPUT (g_nJOBNUM,
                                       i_sGYOUMUCODE,
                                       g_sWSNUM,
                                       c_ONLINE,
                                       i_TBLNAME,
                                       i_sCHOHYOID,
                                       g_rOPRT.CHOHYOFORM,
                                       g_rOPRT.PRTFILEKBN,
                                       g_rOPRT.TEIKEIBUNNUM_LIST,
                                       nCSV_RCNT,
                                       sCSVFILENAME,
                                       sPRTFILENAME);
            --返却用パラメータを設定する
            g_sCSV_RCNT := g_sCSV_RCNT || nCSV_RCNT || ';';          --CSVファイル出力件数
            g_sCSVFILENAME := g_sCSVFILENAME || sCSVFILENAME || ';'; --CSVファイル名
            g_sPRTFILENAME := g_sPRTFILENAME || sPRTFILENAME || ';'; --印刷ファイル名
        END IF;

        --関数終了
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'CSV出力処理', 0, 0, '', '', '処理終了');

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'CSV出力処理', 1, 0, SQLCODE, SQLERRM, '異常終了');
            RETURN FALSE;
    END FUNC_O20CSV;

    --------------------------------------------------------
    --  機能概要      : 性別取得
    --  パラメータ    : i_ISEIBETSU
    --  モジュール区分: 内部関数
    --  戻り値        : 性別名称
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_SEIBETSU(i_ISEIBETSU IN PLS_INTEGER)
      RETURN NVARCHAR2
    IS
      V_SEIBETSU    NVARCHAR2(2);    -- 性別名称
    BEGIN
      CASE i_ISEIBETSU
        WHEN 1 THEN
          V_SEIBETSU := '男';
        WHEN 2 THEN
          V_SEIBETSU := '女';
        ELSE
          V_SEIBETSU := NULL;
      END CASE;
      RETURN V_SEIBETSU;
    END FUNC_GET_SEIBETSU;
    --------------------------------------------------------
    --  機能概要      : 学年取得
    --  パラメータ    : i_IGAKUNEN
    --  モジュール区分: 内部関数
    --  戻り値        : 学年
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_GAKUNEN(i_IGAKUNEN IN PLS_INTEGER)
      RETURN NVARCHAR2
    IS
      V_GAKUNEN    NVARCHAR2(2);    -- 学年名称
    BEGIN
      CASE i_IGAKUNEN
        WHEN 1 THEN
          V_GAKUNEN := '入学';
        WHEN 2 THEN
          V_GAKUNEN := '小１';
        WHEN 3 THEN
          V_GAKUNEN := '小２';
        WHEN 4 THEN
          V_GAKUNEN := '小３';
        WHEN 5 THEN
          V_GAKUNEN := '小４';
        WHEN 6 THEN
          V_GAKUNEN := '小５';
        WHEN 7 THEN
          V_GAKUNEN := '小６';
        WHEN 8 THEN
          V_GAKUNEN := '中１';
        WHEN 9 THEN
          V_GAKUNEN := '中２';
        WHEN 10 THEN
          V_GAKUNEN := '中３';
        ELSE
          NULL;
      END CASE;
      RETURN V_GAKUNEN;
    END FUNC_GET_GAKUNEN;
    --------------------------------------------------------
    --  機能概要      : システム条件取得
    --  パラメータ    : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_GET_SYSJOKEN(i_IRENBAN IN PLS_INTEGER)
      RETURN PLS_INTEGER
    IS
      I_VALUE    PLS_INTEGER;    -- システム条件設定値
      TACONSPRM  A_CONS_PRM;     -- 戻るパラメータ配列
      NLENGTH    NUMBER;         -- 配列件数
      IRTN       PLS_INTEGER;    -- 戻る値
    BEGIN
      BEGIN
        IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      i_IRENBAN,  --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
        IF NLENGTH <> 0 THEN
        --レコードが取得できた場合
          I_VALUE := TACONSPRM(1);
        ELSE
        --レコードが取得できない場合
          I_VALUE := NULL;
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          I_VALUE := NULL;
      END;
      RETURN I_VALUE;
    END FUNC_GET_SYSJOKEN;
    --------------------------------------------------------
    --  機能概要      : 氏名印字制御ﾊﾟﾗﾒｰﾀの設定の編集
    --  パラメータ    : NSEIGYO_IN_FLG,NKANRI_FLG,VSHIMEI_DATA,VHONMYO_DATA
    --  モジュール区分: 内部関数
    --  戻り値        : NSEIGYO_OUT_FLG データ編集用　1 本名　３　管理模型で編集（氏名かな/氏名漢字） ２　管理模型で編集（本名かな/本名漢字）
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
         NSEIGYO_OUT_FLG := 1;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 4 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 1;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 5 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 1;
       END IF;
      ELSIF NSEIGYO_IN_FLG = 6 AND NVL(NKANRI_FLG,0) <> 0 THEN
       IF NKANRI_FLG IN (11,12) THEN
         NSEIGYO_OUT_FLG := 3;
       ELSIF NKANRI_FLG IN (21,22) THEN
         NSEIGYO_OUT_FLG := 2;
       ELSE
         NSEIGYO_OUT_FLG := 1;
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
    --  パラメータ    : NSEIGYO_IN_FLG,NKANRI_FLG 制御ﾊﾟﾗﾒｰﾀ
    --  モジュール区分: 内部関数
    --  戻り値        : 生年月日
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  機能概要      : データ編集処理
    --  パラメータ    : i_ISHIN_SHO1_FLG,i_ISHIN_KYU_KBN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 <>0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_EDIT_DATA(i_ISHIN_SHO1_FLG IN PLS_INTEGER, i_ISHIN_KYU_KBN IN PLS_INTEGER)
      RETURN PLS_INTEGER
    IS
      I_FRTN            PLS_INTEGER;   -- 戻り値
      B_WKRTN           BOOLEAN;       -- 外部関数戻り値
      IJIDO_IDX         PLS_INTEGER;   -- 児童配列インデックス
      I_IDX             PLS_INTEGER;   -- 配列インデックス（帳票ページごと）
      I_ALLPAGE         PLS_INTEGER;   -- 全ページ番号
      vDUMMY            NVARCHAR2(100);
      NDUMMY            NUMBER;
      o_vKOINFILENAME   NVARCHAR2(500);
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
        o_nDAIRIKBN           NUMBER;
        o_vKATAGAKI2          NVARCHAR2(100);
        rBUNNUMSRCINF         KKAPK0040.MR_BUNNUMSRCINF;  --文書番号情報（構造体）
        rBUNNUMEDITKEKA       KKAPK0040.MR_BUNNUMEDITKEKA;--文書番号編集結果
        sNUM                  NVARCHAR2(1000);            --文書番号
        sDATEED               NVARCHAR2(1000);            --文書日付
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
        sCTLPRM               NVARCHAR2(500);             --住所マスク文字列
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 END
        rGKBTTSUCHISHOKANRITY GKBTTSUCHISHOKANRI%ROWTYPE; --通知書管理情報
        nRTN                  NUMBER;                     --戻る値
        o_rHKSKIHON           GABTATENAKIHON%ROWTYPE;
        o_rHKSSOFUSAKI        GABTSOFUSAKI%ROWTYPE;
        nHANTEIKEKKA          NUMBER;
-- 2024/06/05 ZCZL.muzl Add end
-- 2024/06/05 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
      -- 児童情報格納用
--       TYPE MRJIDO IS RECORD (
--         NJIDO_KOJIN_NO     NUMBER,
--         ISEQ_NO            PLS_INTEGER,
--         VSHIMEI_KANA       NVARCHAR2(180),
--         VSHIMEI_KANJI      NVARCHAR2(180),
--         VSEIBETSU          NVARCHAR2(6),
--         ISEINENGAPI        PLS_INTEGER,
--         VGAKUNEN           NVARCHAR2(12),
--         NHOGOSHA_KOJIN_NO  NUMBER,
--         VHOGOSHA_KANA      NVARCHAR2(180),
--         VHOGOSHA_KANJI     NVARCHAR2(180),
--         VJINKAKU_KBN       PLS_INTEGER
--       );
--       TYPE MTJIDO IS TABLE OF MRJIDO INDEX BY BINARY_INTEGER;
--       MJIDO MTJIDO;
-- 2024/06/05 ZCZL.muzl Delete end
      -- 共通情報取得用変数(KKAPK0030.FKYOTU)
      o_IUSER_ID                PLS_INTEGER;
      o_IGAPPEI_BI              PLS_INTEGER;
      o_IJICHI_CD               PLS_INTEGER;
      o_IUSER_KBN               PLS_INTEGER;
      o_VKENMEI                 NVARCHAR2(30);
      o_VGUNSHIMEI              NVARCHAR2(30);
      o_VUSERMEI                NVARCHAR2(40);
      o_VSHUCHOMEI              NVARCHAR2(40);
      o_VSHUCHONINSHOBUN        NVARCHAR2(300);
      o_VYUBIN_NO               NVARCHAR2(10);
      o_VSHOZAICHI              NVARCHAR2(200);
      o_VTEL_NO                 NVARCHAR2(20);
      -- 公印名取得
      o_VKOIN_SHUCHO            NVARCHAR2(40);
      o_VKOIN_GYOMU             NVARCHAR2(40);
      -- 長名取得用
--  2024/08/20 ZCZL.WANGMING DELETE Start 0.3.000.001:IT_GKB_00018対応
--      o_VGYOMU_DOKUJI_KATAGAKI  NVARCHAR2(300);
--      o_VGYOMU_DOKUJI_SHIMEI    NVARCHAR2(40);
--  2024/08/20 ZCZL.WANGMING DELETE End
      N_NAIYO_CD_JIDO_1         GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;
      N_NAIYO_CD_JIDO_2         GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;
      N_NAIYO_CD_JIDO_3         GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;
      N_JIDO_JINGAKU_1          NUMBER := 0;
      N_JIDO_JINGAKU_2          NUMBER := 0;
      N_JIDO_JINGAKU_3          NUMBER := 0;
      N_HOKENSYA_JINGAKU_1      NUMBER := 0;
      N_HOKENSYA_JINGAKU_2      NUMBER := 0;
      N_HOKENSYA_JINGAKU_3      NUMBER := 0;
      VEDIT_GO_DATA             NVARCHAR2(1000) := '';
      RA                        GABTATENAKIHON%ROWTYPE;
      RASO                      GABTSOFUSAKI%ROWTYPE;
      IRTN                      NUMBER := 1;
    BEGIN
      BEGIN
        I_FRTN := c_INOT_SUCCESS;
        IJIDO_IDX := 1;
-- 2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
        -- 児童データを配列に格納
--         IJIDO_IDX := 0;
        -- 連番１の児童
--         IF i_ISEQ_NO_1 > 0 AND
--            (I_SHIN_SHO1_KIRIWAKE_KBN = 0 OR
--             I_SHIN_SHO1_KIRIWAKE_KBN = 1 AND
--             ((i_ISHIN_SHO1_FLG = c_ISHIN_SHO1_FLG_SHO1 AND
--               i_IGAKUNEN_1 = 1) OR
--              (i_ISHIN_SHO1_FLG = c_ISHIN_SHO1_FLG_NOT_SHO1 AND
--               i_IGAKUNEN_1 <> 1))
--            ) THEN
--           IJIDO_IDX := IJIDO_IDX + 1;
--           MJIDO(IJIDO_IDX).NJIDO_KOJIN_NO    := i_NJIDO_KOJIN_NO_1;
--           MJIDO(IJIDO_IDX).ISEQ_NO           := i_ISEQ_NO_1;
          --児童の制御情報を取得
--           BEGIN
--             SELECT NAIYO_CD INTO N_NAIYO_CD_JIDO_1 FROM GKBTSHIMEIJKN
--              WHERE KOJIN_NO = i_NJIDO_KOJIN_NO_1 AND CHOHYO_ID = 'GKB620R001';
--           EXCEPTION
--             WHEN OTHERS THEN
--              N_NAIYO_CD_JIDO_1 := 0;
--           END;
--           BEGIN
--             SELECT NAIYO_CD INTO N_NAIYO_CD_JIDO_2 FROM GKBTSHIMEIJKN
--              WHERE KOJIN_NO = i_NJIDO_KOJIN_NO_2 AND CHOHYO_ID = 'GKB620R001';
--           EXCEPTION
--             WHEN OTHERS THEN
--              N_NAIYO_CD_JIDO_2 := 0;
--           END;
--           BEGIN
--             SELECT NAIYO_CD INTO N_NAIYO_CD_JIDO_3 FROM GKBTSHIMEIJKN
--              WHERE KOJIN_NO = i_NJIDO_KOJIN_NO_3 AND CHOHYO_ID = 'GKB620R001';
--           EXCEPTION
--             WHEN OTHERS THEN
--              N_NAIYO_CD_JIDO_3 := 0;
--           END;
           --KOJIN_NO_1で人格区分を取得
--            BEGIN
--              IRTN := GAAPK0030.FGETATENA(i_NJIDO_KOJIN_NO_1,
--                                                'GKB',
--                                                i_ISHORI_BI,
--                                                RA,
--                                                RASO);
--            N_JIDO_JINGAKU_1 := RA.JINKAKU_KBN;
--            EXCEPTION
--             WHEN OTHERS THEN
--               NULL;
--            END;
           --KOJIN_NO_2で人格区分を取得
--            BEGIN
--              IRTN := GAAPK0030.FGETATENA(i_NJIDO_KOJIN_NO_2,
--                                                'GKB',
--                                                i_ISHORI_BI,
--                                                RA,
--                                                RASO);
--            N_JIDO_JINGAKU_2 := RA.JINKAKU_KBN;
--            EXCEPTION
--             WHEN OTHERS THEN
--               NULL;
--            END;
           --KOJIN_NO_3で人格区分を取得
--            BEGIN
--              IRTN := GAAPK0030.FGETATENA(i_NJIDO_KOJIN_NO_3,
--                                                'GKB',
--                                                i_ISHORI_BI,
--                                                RA,
--                                                RASO);
--            N_JIDO_JINGAKU_3 := RA.JINKAKU_KBN;
--            EXCEPTION
--             WHEN OTHERS THEN
--               NULL;
--            END;
           --HOKENSYA_KOJIN_NO_1で人格区分を取得
--            BEGIN
--              IRTN := GAAPK0030.FGETATENA(i_NHOGOSHA_KOJIN_NO_1,
--                                                'GKB',
--                                                i_ISHORI_BI,
--                                                RA,
--                                                RASO);
--            N_HOKENSYA_JINGAKU_1 := RA.JINKAKU_KBN;
--            EXCEPTION
--             WHEN OTHERS THEN
--               NULL;
--            END;
           --HOKENSYA_KOJIN_NO_2で人格区分を取得
--            BEGIN
--              IRTN := GAAPK0030.FGETATENA(i_NHOGOSHA_KOJIN_NO_2,
--                                                'GKB',
--                                                i_ISHORI_BI,
--                                                RA,
--                                                RASO);
--            N_HOKENSYA_JINGAKU_2 := RA.JINKAKU_KBN;
--            EXCEPTION
--             WHEN OTHERS THEN
--               NULL;
--            END;
           --HOKENSYA_KOJIN_NO_3で人格区分を取得
--            BEGIN
--              IRTN := GAAPK0030.FGETATENA(i_NHOGOSHA_KOJIN_NO_3,
--                                                'GKB',
--                                                i_ISHORI_BI,
--                                                RA,
--                                                RASO);
--            N_HOKENSYA_JINGAKU_3 := RA.JINKAKU_KBN;
--            EXCEPTION
--             WHEN OTHERS THEN
--               NULL;
--            END;
--            IF N_JIDO_JINGAKU_1 = 1 THEN
              --児童１氏名かな編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                     TRIM(i_VSHIMEI_KANA_1),TRIM(i_VJIDO_HONMYO_KANA_1));
--               MJIDO(IJIDO_IDX).VSHIMEI_KANA  := VEDIT_GO_DATA;
              --児童１氏名漢字編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                     TRIM(i_VSHIMEI_KANJI_1),TRIM(i_VJIDO_HONMYO_KANJI_1));
--               MJIDO(IJIDO_IDX).VSHIMEI_KANJI  := VEDIT_GO_DATA;
--            ELSE
--             IF o_MEISYUPRM(3) = 1 THEN
--               IF i_VJIDO_HONMYO_KANA_1 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANA := i_VJIDO_HONMYO_KANA_1;
--               ELSE
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANA := i_VSHIMEI_KANA_1;
--               END IF;
--               IF i_VJIDO_HONMYO_KANJI_1 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANJI := i_VJIDO_HONMYO_KANJI_1;
--               ELSE
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANJI := i_VSHIMEI_KANJI_1;
--               END IF;
--             ELSE
--               MJIDO(IJIDO_IDX).VSHIMEI_KANA  := i_VSHIMEI_KANA_1;
--               MJIDO(IJIDO_IDX).VSHIMEI_KANJI := i_VSHIMEI_KANJI_1;
--             END IF;
--           END IF;
--           MJIDO(IJIDO_IDX).VSEIBETSU         := FUNC_GET_SEIBETSU(i_ISEIBETSU_1);
--           MJIDO(IJIDO_IDX).ISEINENGAPI       := i_ISEINENGAPI_1;
--           MJIDO(IJIDO_IDX).VJINKAKU_KBN      := i_JINKAKU_KBN1;
--           MJIDO(IJIDO_IDX).VGAKUNEN          := FUNC_GET_GAKUNEN(i_IGAKUNEN_1);
--           MJIDO(IJIDO_IDX).NHOGOSHA_KOJIN_NO := i_NHOGOSHA_KOJIN_NO_1;
--            IF N_HOKENSYA_JINGAKU_1 = 1 THEN
              --保険者１氏名かな編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                     TRIM(i_VHOGOSHA_KANA_1),TRIM(i_VHOGOSHA_HONMYO_KANA_1));
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANA  := VEDIT_GO_DATA;
              --保険者１氏名漢字編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1,
--                                     TRIM(i_VHOGOSHA_KANJI_1),TRIM(i_VHOGOSHA_HONMYO_KANJI_1));
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANJI  := VEDIT_GO_DATA;
--            ELSE
--             IF o_MEISYUPRM(3) = 1 THEN
--               IF i_VHOGOSHA_HONMYO_KANA_1 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANA := i_VHOGOSHA_HONMYO_KANA_1;
--               ELSE
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANA := i_VHOGOSHA_KANA_1;
--               END IF;
--               IF i_VHOGOSHA_HONMYO_KANJI_1 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANJI := i_VHOGOSHA_HONMYO_KANJI_1;
--               ELSE
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANJI := i_VHOGOSHA_KANJI_1;
--               END IF;
--             ELSE
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANA  := i_VHOGOSHA_KANA_1;
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANJI := i_VHOGOSHA_KANJI_1;
--             END IF;
--           END IF;
--         END IF;
        -- 連番２の児童
--         IF i_ISEQ_NO_2 > 0 AND
--            (I_SHIN_SHO1_KIRIWAKE_KBN = 0 OR
--             I_SHIN_SHO1_KIRIWAKE_KBN = 1 AND
--             ((i_ISHIN_SHO1_FLG = c_ISHIN_SHO1_FLG_SHO1 AND
--               i_IGAKUNEN_2 = 1) OR
--              (i_ISHIN_SHO1_FLG = c_ISHIN_SHO1_FLG_NOT_SHO1 AND
--               i_IGAKUNEN_2 <> 1))
--            ) THEN
--           IJIDO_IDX := IJIDO_IDX + 1;
--           MJIDO(IJIDO_IDX).NJIDO_KOJIN_NO    := i_NJIDO_KOJIN_NO_2;
--           MJIDO(IJIDO_IDX).ISEQ_NO           := i_ISEQ_NO_2;
--            IF N_JIDO_JINGAKU_2 = 1 THEN
              --児童２氏名かな編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_2 ,
--                                     TRIM(i_VSHIMEI_KANA_2),TRIM(i_VJIDO_HONMYO_KANA_2));
--               MJIDO(IJIDO_IDX).VSHIMEI_KANA  := VEDIT_GO_DATA;
              --児童２氏名漢字編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_2,
--                                     TRIM(i_VSHIMEI_KANJI_2),TRIM(i_VJIDO_HONMYO_KANJI_2));
--               MJIDO(IJIDO_IDX).VSHIMEI_KANJI  := VEDIT_GO_DATA;
--            ELSE
--             IF o_MEISYUPRM(3) = 1 THEN
--               IF i_VJIDO_HONMYO_KANA_2 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANA := i_VJIDO_HONMYO_KANA_2;
--               ELSE
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANA := i_VSHIMEI_KANA_2;
--               END IF;
--               IF i_VJIDO_HONMYO_KANJI_2 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANJI := i_VJIDO_HONMYO_KANJI_2;
--               ELSE
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANJI := i_VSHIMEI_KANJI_2;
--               END IF;
--             ELSE
--               MJIDO(IJIDO_IDX).VSHIMEI_KANA  := i_VSHIMEI_KANA_2;
--               MJIDO(IJIDO_IDX).VSHIMEI_KANJI := i_VSHIMEI_KANJI_2;
--             END IF;
--           END IF;
--           MJIDO(IJIDO_IDX).VSEIBETSU         := FUNC_GET_SEIBETSU(i_ISEIBETSU_2);
--           MJIDO(IJIDO_IDX).ISEINENGAPI       := i_ISEINENGAPI_2;
--           MJIDO(IJIDO_IDX).VJINKAKU_KBN      := i_JINKAKU_KBN2;
--           MJIDO(IJIDO_IDX).VGAKUNEN          := FUNC_GET_GAKUNEN(i_IGAKUNEN_2);
--           MJIDO(IJIDO_IDX).NHOGOSHA_KOJIN_NO := i_NHOGOSHA_KOJIN_NO_2;
--            IF N_HOKENSYA_JINGAKU_2 = 1 THEN
              --保険者2氏名かな編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_2,
--                                     TRIM(i_VHOGOSHA_KANA_2),TRIM(i_VHOGOSHA_HONMYO_KANA_2));
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANA  := VEDIT_GO_DATA;
              --保険者2氏名漢字編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_2,
--                                     TRIM(i_VHOGOSHA_KANJI_2),TRIM(i_VHOGOSHA_HONMYO_KANJI_2));
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANJI  := VEDIT_GO_DATA;
--            ELSE
--             IF o_MEISYUPRM(3) = 1 THEN
--               IF i_VHOGOSHA_HONMYO_KANA_2 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANA := i_VHOGOSHA_HONMYO_KANA_2;
--               ELSE
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANA := i_VHOGOSHA_KANA_2;
--               END IF;
--               IF i_VHOGOSHA_HONMYO_KANJI_2 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANJI := i_VHOGOSHA_HONMYO_KANJI_2;
--               ELSE
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANJI := i_VHOGOSHA_KANJI_2;
--               END IF;
--             ELSE
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANA  := i_VHOGOSHA_KANA_2;
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANJI := i_VHOGOSHA_KANJI_2;
--             END IF;
--           END IF;
--         END IF;
        -- 連番３の児童
--         IF i_ISEQ_NO_3 > 0 AND
--            (I_SHIN_SHO1_KIRIWAKE_KBN = 0 OR
--             I_SHIN_SHO1_KIRIWAKE_KBN = 1 AND
--             ((i_ISHIN_SHO1_FLG = c_ISHIN_SHO1_FLG_SHO1 AND
--               i_IGAKUNEN_3 = 1) OR
--              (i_ISHIN_SHO1_FLG = c_ISHIN_SHO1_FLG_NOT_SHO1 AND
--               i_IGAKUNEN_3 <> 1))
--            ) THEN
--           IJIDO_IDX := IJIDO_IDX + 1;
--           MJIDO(IJIDO_IDX).NJIDO_KOJIN_NO    := i_NJIDO_KOJIN_NO_3;
--           MJIDO(IJIDO_IDX).ISEQ_NO           := i_ISEQ_NO_3;
--            IF N_JIDO_JINGAKU_3 = 1 THEN
              --児童２氏名かな編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_3 ,
--                                     TRIM(i_VSHIMEI_KANA_3),TRIM(i_VJIDO_HONMYO_KANA_3));
--               MJIDO(IJIDO_IDX).VSHIMEI_KANA  := VEDIT_GO_DATA;
              --児童２氏名漢字編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_3,
--                                     TRIM(i_VSHIMEI_KANJI_3),TRIM(i_VJIDO_HONMYO_KANJI_3));
--               MJIDO(IJIDO_IDX).VSHIMEI_KANJI  := VEDIT_GO_DATA;
--            ELSE
--             IF o_MEISYUPRM(3) = 1 THEN
--               IF i_VJIDO_HONMYO_KANA_3 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANA := i_VJIDO_HONMYO_KANA_3;
--               ELSE
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANA := i_VSHIMEI_KANA_3;
--               END IF;
--               IF i_VJIDO_HONMYO_KANJI_3 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANJI := i_VJIDO_HONMYO_KANJI_3;
--               ELSE
--                 MJIDO(IJIDO_IDX).VSHIMEI_KANJI := i_VSHIMEI_KANJI_3;
--               END IF;
--             ELSE
--               MJIDO(IJIDO_IDX).VSHIMEI_KANA  := i_VSHIMEI_KANA_3;
--               MJIDO(IJIDO_IDX).VSHIMEI_KANJI := i_VSHIMEI_KANJI_3;
--             END IF;
--           END IF;
--           MJIDO(IJIDO_IDX).VSEIBETSU         := FUNC_GET_SEIBETSU(i_ISEIBETSU_3);
--           MJIDO(IJIDO_IDX).ISEINENGAPI       := i_ISEINENGAPI_3;
--           MJIDO(IJIDO_IDX).VJINKAKU_KBN      := i_JINKAKU_KBN3;
--           MJIDO(IJIDO_IDX).VGAKUNEN          := FUNC_GET_GAKUNEN(i_IGAKUNEN_3);
--           MJIDO(IJIDO_IDX).NHOGOSHA_KOJIN_NO := i_NHOGOSHA_KOJIN_NO_3;
--            IF N_HOKENSYA_JINGAKU_3 = 1 THEN
              --保険者3氏名かな編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_3,
--                                     TRIM(i_VHOGOSHA_KANA_3),TRIM(i_VHOGOSHA_HONMYO_KANA_3));
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANA  := VEDIT_GO_DATA;
              --保険者3氏名漢字編集
--               VEDIT_GO_DATA := FUNC_SET_SEIGYO(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_3,
--                                     TRIM(i_VHOGOSHA_KANJI_3),TRIM(i_VHOGOSHA_HONMYO_KANJI_3));
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANJI  := VEDIT_GO_DATA;
--            ELSE
--             IF o_MEISYUPRM(3) = 1 THEN
--               IF i_VHOGOSHA_HONMYO_KANA_3 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANA := i_VHOGOSHA_HONMYO_KANA_3;
--               ELSE
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANA := i_VHOGOSHA_KANA_3;
--               END IF;
--               IF i_VHOGOSHA_HONMYO_KANJI_3 IS NOT NULL THEN
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANJI := i_VHOGOSHA_HONMYO_KANJI_3;
--               ELSE
--                 MJIDO(IJIDO_IDX).VHOGOSHA_KANJI := i_VHOGOSHA_KANJI_3;
--               END IF;
--             ELSE
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANA  := i_VHOGOSHA_KANA_3;
--               MJIDO(IJIDO_IDX).VHOGOSHA_KANJI := i_VHOGOSHA_KANJI_3;
--             END IF;
--           END IF;
--         END IF;
        -- 対象児童が見つからなかった場合にはここで終了
--         IF MJIDO.COUNT = 0 THEN
--           I_FRTN := c_INOT_FOUND;
--           RETURN I_FRTN;
--         END IF;
-- 2024/06/11 ZCZL.muzl Delete end
        -- 全ページ番号(児童数 ÷ 1ページの児童数を小数点以下切り上げ)
        --  (旧学校、新学校それぞれで全頁を計算しています)
        I_ALLPAGE := CEIL(IJIDO_IDX / I_JIDO_PER_PAGE) + I_PAGE_NUM_BASE;
        -- 稼動団体名取得
-- 2024/06/25 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--         I_FRTN := KKAPK0030.FKYOTU( i_ISHORI_BI,
        I_FRTN := KKAPK0030.FKYOTU( TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),
                                   o_IUSER_ID,
                                   o_IJICHI_CD,
                                   o_IGAPPEI_BI,
                                   o_IUSER_KBN,
                                   o_VGUNSHIMEI,
                                   O_VUSERMEI,
                                   O_VSHUCHOMEI,
                                   O_VKENMEI,
                                   O_VSHUCHONINSHOBUN,
                                   O_VYUBIN_NO,
                                   O_VSHOZAICHI,
                                   O_VTEL_NO);
        IF I_FRTN = 0 THEN
          NULL;
        ELSE
          RETURN I_FRTN;
        END IF;
        -- 長名、肩書取得
-- 2024/06/25 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--         KKAPK0030.SNinshGet(i_ISHORI_BI, nDUMMY, o_VGYOMU_DOKUJI_SHIMEI, VDUMMY, VDUMMY, o_VGYOMU_DOKUJI_KATAGAKI);
--  2024/08/20 ZCZL.WANGMING DELETE 0.3.000.001:IT_GKB_00018対応
--        KKAPK0030.SNinshGet(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), nDUMMY, o_VGYOMU_DOKUJI_SHIMEI, VDUMMY, VDUMMY, o_VGYOMU_DOKUJI_KATAGAKI);
        -- 公印名取得
-- 2024/06/20 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--         B_WKRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE, 0),
--                                       g_sWSNUM,
--                                       SYSDATE,
--                                       VDUMMY,
--                                       VDUMMY,
--                                       VDUMMY,
--                                       VDUMMY,
--                                       o_vKOINFILENAME
--         );
        IF i_nCHOHYOKBN = 21 THEN
                B_WKRTN := KKBPK5551.FNINSHOGet(g_rOPRT.NINSHOCODE, g_sWSNUM, SYSDATE, o_nDAIRIKBN, g_vKATAGAKI1, o_vKATAGAKI2, g_vNINSHOSHA_MEI, o_vKOINFILENAME);
        END IF;
-- 2024/06/20 ZCZL.muzl Update end
        IF B_WKRTN THEN
          --首長公印ファイル名
          O_VKOIN_SHUCHO := o_vKOINFILENAME;
          --業務毎公印ファイル名
          O_VKOIN_GYOMU := o_vKOINFILENAME;
        ELSE
          O_VKOIN_SHUCHO := '';
          O_VKOIN_GYOMU := '';
          RETURN I_FRTN;
        END IF;
-- 2024/06/11 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
              -- 文書番号・発付年月日の取得、設定
              rBUNNUMSRCINF := KKBPK5551.FBunNumInf(g_sBUNSHONUMLIST);
              --文書番号編集結果を取得
              rBUNNUMEDITKEKA := rBUNNUMSRCINF.UOUT;
              --文書番号
              IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
                 --文書入力画面で文書番号印字ありのとき設定
                  sNUM := rBUNNUMEDITKEKA.NUM;
              ELSE
                  sNUM := '';
              END IF;
              -- 文書日付
              IF rBUNNUMEDITKEKA.DATEUMUFLG = 0 THEN
                  --文書入力画面で文書日付印字ありのとき設定
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00433対応
                  --sDATEED := rBUNNUMEDITKEKA.DATEED;
                  sDATEED := rBUNNUMEDITKEKA.BUNDATE;
              ELSE
                  sDATEED := '';
              END IF;
              --通知書管理データ抽出
              BEGIN
                SELECT KOIN_SHORYAKU
                       ,KOIN_CHUSHAKU
                       ,TSUCHIBUN
                       ,YOSHIKI_BANGO_SETTOGO
                       ,YOSHIKI_BANGO
                       ,YOSHIKI_BANGO_SETSUBIGO
                       ,CHOHYO_MEI
                INTO rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU                             --公印省略
                     ,rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU                            --公印注釈
                     ,rGKBTTSUCHISHOKANRITY.TSUCHIBUN                                --通知文
                     ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO                    --様式番号接頭語
                     ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO                            --様式番号
                     ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO                  --様式番号接尾語
                     ,rGKBTTSUCHISHOKANRITY.CHOHYO_MEI                               --帳票名
                FROM GKBTTSUCHISHOKANRI
                WHERE TRIM(CHOHYO_KBN) = i_nCHOHYOKBN;
              EXCEPTION
                WHEN OTHERS THEN
                  rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU := NULL;
                  rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU := NULL;
                  rGKBTTSUCHISHOKANRITY.TSUCHIBUN := NULL;
                  rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO := NULL;
                  rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO := NULL;
                  rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO := NULL;
                  rGKBTTSUCHISHOKANRITY.CHOHYO_MEI := NULL;
              END;
-- 2024/06/11 ZCZL.muzl Add end
        I_IDX := I_PAGE_NUM_BASE;
        IJIDO_IDX := 0;
        -- 全頁データ作成
        WHILE I_ALLPAGE > I_IDX LOOP
          -- 表題(新学校、旧学校で表題を切り分け)
-- 2024/06/11 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--           CASE i_ISHIN_KYU_KBN
--             WHEN c_ISHIN_KYU_KBN_NEW THEN
--               R_WK(I_IDX).TITLE               := i_VNEW_TITLE;
--             WHEN c_ISHIN_KYU_KBN_OLD THEN
--               R_WK(I_IDX).TITLE               := i_VOLD_TITLE;
--             WHEN c_ISHIN_KYU_KBN_HOGOSHA THEN
--               R_WK(I_IDX).TITLE               := i_VNEW_TITLE;
--             ELSE
--               R_WK(I_IDX).TITLE               := NULL;
--           END CASE;
          R_WK(I_IDX).TITLE               := rGKBTTSUCHISHOKANRITY.CHOHYO_MEI;
-- 2024/06/11 ZCZL.muzl Update end
--2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).IDO_JIYU            := i_IIDO_JIYU;         -- 異動事由
--           R_WK(I_IDX).IDO_JIYU_MEI        := i_VIDO_JIYU_MEI;     -- 異動事由名
-- 2024/06/11 ZCZL.muzl Delete end
          R_WK(I_IDX).IDO_BI              := i_IIDO_BI;           -- 異動日
          R_WK(I_IDX).TODOKEDE_BI         := i_ITODOKEDE_BI;      -- 届出日
--2024/06/11 ZCZL.muzl Delete 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).SETAI_NO            := i_ISETAI_NO;         -- 世帯番号
-- 2024/06/11 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).NEW_CHOMEI          := i_VNEW_CHOMEI;       -- 新住所町名
--           R_WK(I_IDX).NEW_BANCHI          := i_VNEW_BANCHI;       -- 新住所番地
--           R_WK(I_IDX).NEW_KATAGAKI        := i_VNEW_KATAGAKI;     -- 新住所方書
--           R_WK(I_IDX).OLD_CHOMEI          := i_VOLD_CHOMEI;       -- 旧住所町名
--           R_WK(I_IDX).OLD_BANCHI          := i_VOLD_BANCHI;       -- 旧住所番地
--           R_WK(I_IDX).OLD_KATAGAKI        := i_VOLD_KATAGAKI;     -- 旧住所方書
          R_WK(I_IDX).NEW_JUSHO        := i_VNEW_JUSHO;     -- 新住所
          R_WK(I_IDX).OLD_JUSHO        := i_VOLD_JUSHO;     -- 旧住所
-- 2024/06/11 ZCZL.muzl Update end
          R_WK(I_IDX).NEW_GAKKO           := i_VNEW_GAKKO;        -- 新学校名
          R_WK(I_IDX).OLD_GAKKO           := i_VOLD_GAKKO;        -- 旧学校名
--  2024/09/11 ZCZL.WANGMING UPDATE 0.3.000.002:8月1日認識合わせの横展開
--          R_WK(I_IDX).IINKAI_MEI          := o_KYOIKUPRM(1);
          R_WK(I_IDX).IINKAI_MEI          := NULL;
          -- 学校長名(新学校、旧学校で切り分け)
          CASE i_ISHIN_KYU_KBN
            WHEN c_ISHIN_KYU_KBN_NEW THEN
              R_WK(I_IDX).GAKKOCHO            := i_VNEW_GAKKO || '長';
            WHEN c_ISHIN_KYU_KBN_OLD THEN
              R_WK(I_IDX).GAKKOCHO            := i_VOLD_GAKKO || '長';
            WHEN c_ISHIN_KYU_KBN_HOGOSHA THEN
--2024/06/11 ZCZL.muzl Delete 0.3.000.000:新WizLIFE２次開発
--              IF o_MEISYUPRM(3) = 1 THEN
-- 2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--                 IF i_VHOGOSHA_HONMYO_KANJI_1 IS NOT NULL THEN
--                    R_WK(I_IDX).GAKKOCHO := i_VHOGOSHA_HONMYO_KANJI_1;
--                IF i_VOLD_HOGOSHA_SHIMEI_KANJI IS NOT NULL THEN
--                   R_WK(I_IDX).GAKKOCHO := i_VOLD_HOGOSHA_SHIMEI_KANJI;
-- 2024/06/11 ZCZL.muzl Delete end
--                ELSE
-- 2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--                    R_WK(I_IDX).GAKKOCHO := i_VHOGOSHA_KANJI_1;
--                   R_WK(I_IDX).GAKKOCHO := i_VNEW_HOGOSHA_SHIMEI_KANJI;
--                END IF;
--              ELSE
-- 2024/06/11 ZCZL.muzl Delete end
-- 2024/06/11 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--                 R_WK(I_IDX).GAKKOCHO  := i_VHOGOSHA_KANJI_1;
                R_WK(I_IDX).GAKKOCHO  := i_VNEW_HOGOSHA_SHIMEI_KANJI;
--2024/06/11 ZCZL.muzl Delete 0.3.000.000:新WizLIFE２次開発
--              END IF;
            ELSE
              R_WK(I_IDX).GAKKOCHO            := NULL;
          END CASE;
--2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--           IF R_WK(I_IDX).GAKKOCHO <> '長' AND i_ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_NEW THEN
--             R_WK(I_IDX).TENNYUGAKU_BI_MEI := '転入学年月日';
--             R_WK(I_IDX).TENNYUGAKU_BI := i_TENNYUGAKU_BI;
--           ELSIF R_WK(I_IDX).GAKKOCHO = '長' AND i_ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_NEW THEN
--             R_WK(I_IDX).TENNYUGAKU_BI_MEI := '転学年月日';
--             R_WK(I_IDX).TENNYUGAKU_BI := i_TENGAKU_BI;
--           ELSIF i_ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_OLD THEN
--             R_WK(I_IDX).TENNYUGAKU_BI_MEI := '転学年月日';
--             R_WK(I_IDX).TENNYUGAKU_BI := i_TENGAKU_BI;
--           END IF;
--           IF i_ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_HOGOSHA THEN
--             IF i_VNEW_GAKKO IS NOT NULL THEN
--               R_WK(I_IDX).TENNYUGAKU_BI_MEI := '転入学年月日';
--               R_WK(I_IDX).TENNYUGAKU_BI := i_TENNYUGAKU_BI;
--             ELSE
--               R_WK(I_IDX).TENNYUGAKU_BI_MEI := '転学年月日';
--               R_WK(I_IDX).TENNYUGAKU_BI := i_TENGAKU_BI;
--             END IF;
--           END IF;
-- 2024/06/11 ZCZL.muzl Delete end
          --新学校名がないときは旧学校名をセットする
          IF R_WK(I_IDX).GAKKOCHO = '長' AND i_ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_NEW THEN
              R_WK(I_IDX).GAKKOCHO          := i_VOLD_GAKKO || '長';
          END IF;
          --新学校名・旧学校名の両方とも無い場合の判断
          IF R_WK(I_IDX).GAKKOCHO = '長' THEN
            R_WK(I_IDX).GAKKOCHO            := NULL;
          END IF;
-- 2024/06/12 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).GAKKO_NINSHO          := i_VGAKKO_NINSHO;           -- 学校向け認証文
--           IF i_ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_HOGOSHA THEN
-- 2024/06/12 ZCZL.muzl Delete end
            R_WK(I_IDX).GAKKO_NINSHO        := NULL;
-- 2024/06/12 ZCZL.muzl Delete 0.3.000.000:新WizLIFE２次開発
--           END IF;
          R_WK(I_IDX).KYOIKU_KOIN_MEI       := o_VKOIN_GYOMU;             -- 教育長公印名
          R_WK(I_IDX).NINSHO_KATAGAKI       := o_VSHUCHONINSHOBUN;        -- 長認証方書
          R_WK(I_IDX).SHUCHO_MEI            := o_VSHUCHOMEI;              -- 首長名
          R_WK(I_IDX).SHUCHO_KOIN_MEI       := o_VKOIN_SHUCHO;            -- 首長公印名
-- 2024/06/12 ZCZL.muzl Delete 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).GAKKO_BIKO            := i_VGAKKO_BIKO;             -- 学校向け備考
          IF i_ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_HOGOSHA THEN
            R_WK(I_IDX).GAKKO_BIKO          := NULL;
          END IF;
          R_WK(I_IDX).KYOIKU_BIKO           := NULL;                      -- 教育委員会向け備考
-- 2024/06/12 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).SHORI_BI              := i_ISHORI_BI;               -- 処理日
--           R_WK(I_IDX).SHORI_JIKAN           := i_ISHORI_JIKAN;            -- 処理時間
          R_WK(I_IDX).SHORI_BI              := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));               -- 処理日
          R_WK(I_IDX).SHORI_JIKAN           := NULL;            -- 処理時間
-- 2024/06/12 ZCZL.muzl Update end
          R_WK(I_IDX).TANMATSU_NO           := g_sWSNUM;                  -- 端末番号
-- 2024/06/12 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).GYOSEIKU_CD           := i_INEW_GYOSEIKU_CD;        -- 行政区コード
--           R_WK(I_IDX).GYOSEIKU_MEI          := i_VNEW_GYOSEIKU_MEI;       -- 行政区名
--           R_WK(I_IDX).OLD_GYOSEIKU_MEI      := i_VOLD_GYOSEIKU_MEI;       -- 旧行政区名（バッチ用）
-- 2024/06/12 ZCZL.muzl Delete end
--  2024/08/20 ZCZL.WANGMING UPDATE Start 0.3.000.001:IT_GKB_00018対応
--          R_WK(I_IDX).GYOMU_KATAGAKI        := o_VGYOMU_DOKUJI_KATAGAKI;  -- 業務独自認証肩書
--          R_WK(I_IDX).GYOMU_NINSHOSHA_MEI   := o_VGYOMU_DOKUJI_SHIMEI;    -- 業務独自認証者名
          R_WK(I_IDX).GYOMU_KATAGAKI        := g_vKATAGAKI1 || o_vKATAGAKI2;  -- 業務独自認証肩書
          R_WK(I_IDX).GYOMU_NINSHOSHA_MEI   := g_vNINSHOSHA_MEI;    -- 業務独自認証者名
--  2024/08/20 ZCZL.WANGMING UPDATE End
          R_WK(I_IDX).PAGE                  := I_IDX + I_PAGE_NUM_BASE;   -- 頁(新学校と旧学校全体通してのページ番号)
-- 2024/06/12 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).TSUDUKIGARA1          := i_VJIDO_KANKEI_1;        -- 続柄１
--           R_WK(I_IDX).HOGOSHA_TSUDUKIGARA_1 := i_VHOGOSHA_KANKEI_1;     -- 保護者との関係１
--           R_WK(I_IDX).TSUDUKIGARA2          := i_VJIDO_KANKEI_2;        -- 続柄２
--           R_WK(I_IDX).HOGOSHA_TSUDUKIGARA_2 := i_VHOGOSHA_KANKEI_2;     -- 保護者との関係２
--           R_WK(I_IDX).TSUDUKIGARA3          := i_VJIDO_KANKEI_3;        -- 続柄３
--           R_WK(I_IDX).HOGOSHA_TSUDUKIGARA_3 := i_VHOGOSHA_KANKEI_3;     -- 保護者との関係３
--           R_WK(I_IDX).IDOJIKO               := i_VIDO_JIKO;             -- 異動事項
--           R_WK(I_IDX).SHUGAKU               := i_VSHUGAKU;              -- 就学状況
-- 2024/06/12 ZCZL.muzl Delete end
-- 2024/06/11 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
          R_WK(I_IDX).KYOIKUKAI_MEI         := g_vKATAGAKI1;            -- 教育委員会名
          R_WK(I_IDX).KYOIKU_YAKUSHOKU_MEI  := o_KYOIKUPRM(2);            -- 教育委員会役職名
-- 2024/06/11 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).KYOIKU_SHUTHOU_MEI    := o_KYOIKUPRM(3);            -- 教育委員会首長名
          R_WK(I_IDX).KYOIKU_SHUTHOU_MEI    := g_vNINSHOSHA_MEI;            -- 教育委員会首長名
          R_WK(I_IDX).KYOIKU_RITSU_MEI      := o_KYOIKUPRM(4);            -- 教育委員会立区名
          R_WK(I_IDX).KYOIKU_YUBIN_NO := SUBSTR(o_KYOIKUPRM(5),1,3) || '-' || SUBSTR(o_KYOIKUPRM(5),4);-- 教育委員会郵便番号
          R_WK(I_IDX).KYOIKU_YUBIN_NO := TRANSLATE(R_WK(I_IDX).KYOIKU_YUBIN_NO, '1234567890-', '１２３４５６７８９０－');
          R_WK(I_IDX).KYOIKU_JUSHO          := o_KYOIKUPRM(6);            -- 教育委員会住所
          R_WK(I_IDX).KYOIKU_TEL            := o_KYOIKUPRM(7);            -- 教育委員会電話番号
          R_WK(I_IDX).KYOIKU_TEL_NAISEN     := o_KYOIKUPRM(8);            -- 教育委員会内線
-- 2024/06/11 ZCZL.muzl Delete 0.3.000.000:新WizLIFE２次開発
--          IF o_MEISYUPRM(3) = 2 THEN                                      -- 氏名備考1～6
-- 2024/06/11 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--             IF i_VJIDO_HONMYO_KANJI_1 IS NOT NULL THEN
--               R_WK(I_IDX).SHIMEI_BIKO1 := '児童本名：' || i_VJIDO_HONMYO_KANJI_1 || '(' || i_VJIDO_HONMYO_KANA_1 || ')';
            IF i_VOLD_JIDO_SHIMEI_KANJI IS NOT NULL THEN
              R_WK(I_IDX).SHIMEI_BIKO1 := '児童本名：' || i_VOLD_JIDO_SHIMEI_KANJI || '(' || i_VOLD_JIDO_SHIMEI_KANA || ')';
-- 2024/06/11 ZCZL.muzl Update end
            ELSE
              R_WK(I_IDX).SHIMEI_BIKO1 := NULL;
            END IF;
-- 2024/06/11 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--             IF i_VHOGOSHA_HONMYO_KANJI_1 IS NOT NULL THEN
--               R_WK(I_IDX).SHIMEI_BIKO2 := '保護者本名：' || i_VHOGOSHA_HONMYO_KANJI_1 || '(' || i_VHOGOSHA_HONMYO_KANA_1 || ')';
            IF i_VOLD_HOGOSHA_SHIMEI_KANJI IS NOT NULL THEN
              R_WK(I_IDX).SHIMEI_BIKO2 := '保護者本名：' || i_VOLD_HOGOSHA_SHIMEI_KANJI || '(' || i_VOLD_HOGOSHA_SHIMEI_KANA || ')';
-- 2024/06/11 ZCZL.muzl Update end
            ELSE
              R_WK(I_IDX).SHIMEI_BIKO2 := NULL;
            END IF;
-- 2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--             IF i_VJIDO_HONMYO_KANJI_2 IS NOT NULL THEN
--               R_WK(I_IDX).SHIMEI_BIKO3 := '児童本名：' || i_VJIDO_HONMYO_KANJI_2 || '(' || i_VJIDO_HONMYO_KANA_2 || ')';
--             ELSE
-- 2024/06/12 ZCZL.muzl Delete end
              R_WK(I_IDX).SHIMEI_BIKO3 := NULL;
-- 2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--             END IF;
--             IF i_VHOGOSHA_HONMYO_KANJI_2 IS NOT NULL THEN
--               R_WK(I_IDX).SHIMEI_BIKO4 := '保護者本名：' || i_VHOGOSHA_HONMYO_KANJI_2 || '(' || i_VHOGOSHA_HONMYO_KANA_2 || ')';
--             ELSE
-- 2024/06/12 ZCZL.muzl Delete end
              R_WK(I_IDX).SHIMEI_BIKO4 := NULL;
-- 2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--             END IF;
--             IF i_VJIDO_HONMYO_KANJI_3 IS NOT NULL THEN
--               R_WK(I_IDX).SHIMEI_BIKO5 := '児童本名：' || i_VJIDO_HONMYO_KANJI_3 || '(' || i_VJIDO_HONMYO_KANA_3 || ')';
--             ELSE
-- 2024/06/12 ZCZL.muzl Delete end
              R_WK(I_IDX).SHIMEI_BIKO5 := NULL;
-- 2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--             END IF;
--             IF i_VHOGOSHA_HONMYO_KANJI_3 IS NOT NULL THEN
--               R_WK(I_IDX).SHIMEI_BIKO6 := '保護者本名：' || i_VHOGOSHA_HONMYO_KANJI_3 || '(' || i_VHOGOSHA_HONMYO_KANA_3 || ')';
--             ELSE
-- 2024/06/12 ZCZL.muzl Delete end
              R_WK(I_IDX).SHIMEI_BIKO6 := NULL;
-- 2024/06/11 ZCZL.muzl Delete 0.3.000.000:新WizLIFE２次開発
--             END IF;
-- 2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
--          ELSE
--            R_WK(I_IDX).SHIMEI_BIKO1 := NULL;
--            R_WK(I_IDX).SHIMEI_BIKO2 := NULL;
--            R_WK(I_IDX).SHIMEI_BIKO3 := NULL;
--            R_WK(I_IDX).SHIMEI_BIKO4 := NULL;
--            R_WK(I_IDX).SHIMEI_BIKO5 := NULL;
--            R_WK(I_IDX).SHIMEI_BIKO6 := NULL;
--          END IF;
-- 2024/06/12 ZCZL.muzl Delete end
          -- 児童１の情報を出力
          IJIDO_IDX := IJIDO_IDX + 1;
-- 2024/06/18 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).SEQ_NO_1            := MJIDO(IJIDO_IDX).ISEQ_NO;            -- 連番１
--           R_WK(I_IDX).SHIMEI_KANA_1       := i_VSHIMEI_KANA_1;                    -- 氏名かな１
--           R_WK(I_IDX).SHIMEI_KANJI_1      := i_VSHIMEI_KANJI_1;                   -- 氏名漢字１
--           R_WK(I_IDX).SEIBETSU_1          := MJIDO(IJIDO_IDX).VSEIBETSU;          -- 性別１
          R_WK(I_IDX).SEQ_NO_1            := NULL;            -- 連番１
          R_WK(I_IDX).KOJIN_NO_1          := i_NJIDO_KOJIN_NO_1;        -- 宛名番号１
          R_WK(I_IDX).SHIMEI_KANA_1       := i_VNEW_JIDO_SHIMEI_KANA;             -- 新児童生徒氏名カナ
          R_WK(I_IDX).SHIMEI_KANJI_1      := i_VNEW_JIDO_SHIMEI_KANJI;            -- 新児童生徒氏名漢字
          R_WK(I_IDX).SEIBETSU_1          := i_NNEW_JIDO_SEIBETSU;                -- 性別１
-- 2024/06/18 ZCZL.muzl Update end
          --児童１の生年月日編集
-- 2024/06/18 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--           IF N_JIDO_JINGAKU_1 = 1 THEN
--              R_WK(I_IDX).SEINENGAPI_1 := FUNC_SET_SEIGYO_SEINENGAPI(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1) || TO_CHAR(MJIDO(IJIDO_IDX).ISEINENGAPI);--人格区分1 || 生年月日１
--           ELSE
--              R_WK(I_IDX).SEINENGAPI_1 := TO_CHAR(MJIDO(IJIDO_IDX).VJINKAKU_KBN) ||
--                                              TO_CHAR(MJIDO(IJIDO_IDX).ISEINENGAPI);        --人格区分1 || 生年月日１
--           END IF;
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
--          R_WK(I_IDX).SEINENGAPI_1 := i_NNEW_JIDO_SEINENGAPI;  -- 新児童生徒生年月日
          --人格区分取得
          SELECT JINKAKU_KBN INTO g_vJINKAKU_KBN FROM GABTATENAKIHON WHERE KOJIN_NO = i_NJIDO_KOJIN_NO_1;
          -- 新児童生徒生年月日
          IF g_vJINKAKU_KBN = 0 THEN
              R_WK(I_IDX).SEINENGAPI_1 := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(i_NNEW_JIDO_SEINENGAPI,0,3),' ',''));
          ELSE
              R_WK(I_IDX).SEINENGAPI_1 := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(i_NNEW_JIDO_SEINENGAPI,1,3),' ',''));
          END IF;
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 END
-- 2024/06/18 ZCZL.muzl Update end
-- 2024/06/18 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--           R_WK(I_IDX).GAKUNEN_1           := MJIDO(IJIDO_IDX).VGAKUNEN;           -- 学年１
--           R_WK(I_IDX).HOGOSHA_KOJIN_NO_1  := MJIDO(IJIDO_IDX).NHOGOSHA_KOJIN_NO;  -- 保護者宛名番号１
--           R_WK(I_IDX).HOGOSHA_KANA_1      := i_VHOGOSHA_KANA_1;                   -- 保護者名かな１
--           R_WK(I_IDX).HOGOSHA_KANJI_1     := i_VHOGOSHA_KANJI_1;                  -- 保護者名漢字１
          --  2024/11/12 ZCZL.ZHANGLEI ADD 0.3.000.006:IT_GKB_00469仕様変更対応   
          R_WK(I_IDX).GAKUNEN_1           := i_VNEW_GAKUNEN;                               -- 学年１
          R_WK(I_IDX).HOGOSHA_KANA_1      := i_VNEW_HOGOSHA_SHIMEI_KANA;                   -- 新保護者氏名カナ
          R_WK(I_IDX).HOGOSHA_KANJI_1     := i_VNEW_HOGOSHA_SHIMEI_KANJI;                  -- 新保護者氏名漢字
-- 2024/06/18 ZCZL.muzl Update end
-- 2024/06/11 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
          R_WK(I_IDX).TSUCHISHO_KBN       := 0;        -- 通知書区分
          R_WK(I_IDX).JINKAKU_KBN         := NULL;        -- 人格区分1 
          R_WK(I_IDX).OLD_SHIMEI_KANA     := i_VOLD_JIDO_SHIMEI_KANA;        -- 旧児童生徒氏名カナ
          R_WK(I_IDX).OLD_SHIMEI_KANJI    := i_VOLD_JIDO_SHIMEI_KANJI;       -- 旧児童生徒氏名漢字
--  2024/09/29 ZCZL.yangshuai Update start 0.3.000.003:仕様変更 IT_GKB_00072対応
--           R_WK(I_IDX).KOIN_SHORYAKU       := rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU;        -- 公印省略
--           R_WK(I_IDX).KOIN_CHUSHAKU       := rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU;        -- 公印注釈
          IF o_vKOINFILENAME IS NULL THEN
              R_WK(I_IDX).KOIN_SHORYAKU       := rGKBTTSUCHISHOKANRITY.KOIN_SHORYAKU;        -- 公印省略
              R_WK(I_IDX).KOIN_CHUSHAKU       := NULL;
          ELSE
              R_WK(I_IDX).KOIN_SHORYAKU       := NULL;
              R_WK(I_IDX).KOIN_CHUSHAKU       := rGKBTTSUCHISHOKANRITY.KOIN_CHUSHAKU;        -- 公印注釈
          END IF;
--  2024/09/29 ZCZL.yangshuai Update end
          R_WK(I_IDX).OLD_HOGOSHA_SHIMEI_KANA       := i_VOLD_HOGOSHA_SHIMEI_KANA;       -- 旧保護者氏名カナ
          R_WK(I_IDX).OLD_HOGOSHA_SHIMEI_KANJI      := i_VOLD_HOGOSHA_SHIMEI_KANJI;      -- 旧保護者氏名漢字
          R_WK(I_IDX).OLD_GAKUNEN         := i_VOLD_GAKUNEN;      -- 旧学年
--  2025/01/08 JPJYS.GL UPDATE 0.3.000.010:品質強化：IT_GKB_10231対応 start
--          R_WK(I_IDX).YOSHIKI_NO          := rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO;       -- 様式番号
          R_WK(I_IDX).YOSHIKI_NO          := rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO || TRANSLATE(rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO, '0123456789', '０１２３４５６７８９') || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO;      -- 様式番号
--  2025/01/08 JPJYS.GL UPDATE 0.3.000.010:品質強化：IT_GKB_10231対応 end          
          R_WK(I_IDX).BUNSHO_NO           := sNUM;      -- 文書番号
--  2024/09/11 ZCZL.WANGMING UPDATE 0.3.000.002:8月1日認識合わせの横展開
--          IRTN := KKAPK0020.FDateSW(TO_CHAR(SYSDATE,'YYYY/MM/DD'),R_WK(I_IDX).HAKKO_NENGAPI); -- 発行年月日
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
--          R_WK(I_IDX).HAKKO_NENGAPI := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sDATEED, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12); -- 発行年月日
          R_WK(I_IDX).HAKKO_NENGAPI := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(sDATEED, 'YYYY/MM/DD'),'YYYY/MM/DD'), 10),' ','')); -- 発行年月日
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 END
--  2024/09/11 JPJYS.LIZIZHONG UPDATE 0.3.000.003:IT_GKB_10041  STR     
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
--           IF i_IHOGOSHA_FLG = 0 THEN 
         IF g_vHOGOSHA_FLG AND i_ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_HOGOSHA THEN 
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 END
--  2024/09/11 JPJYS.LIZIZHONG UPDATE 0.3.000.003:IT_GKB_10041  END  
            --保護者の宛名情報を取得する
--  2024/09/11 ZCZL.WANGMING UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
--            nRTN := GAAPK0030.FGETATENA2(R_WK(I_IDX).HOGOSHA_KANJI_1,'GKB',TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), o_rHKSKIHON,o_rHKSSOFUSAKI);
--            nRTN := GAAPK0030.FGETATENA(i_NJIDO_KOJIN_NO_1,'GKB',TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), o_rHKSKIHON,o_rHKSSOFUSAKI);
            --保護者宛名番号
            BEGIN
              SELECT
                HOGOSYA_KOJIN_NO
              INTO
                g_NHOGOSHA_KOJIN_NO_1
              FROM
                (
                  SELECT
                    *
                  FROM
                    GKBTGAKUREIBO
                  WHERE
                    KOJIN_NO = i_NJIDO_KOJIN_NO_1
                    AND SAKUJO_FLG = 0
                  ORDER BY
                    RIREKI_RENBAN DESC
                    , RIREKI_RENBAN_EDA DESC
                )
              WHERE
                ROWNUM = 1;
            EXCEPTION
              WHEN OTHERS THEN
                g_NHOGOSHA_KOJIN_NO_1 := NULL;
            END;
            --保護者の宛名情報を取得する
            nRTN := GAAPK0030.FGETATENA2(g_NHOGOSHA_KOJIN_NO_1,'GKB',TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), o_rHKSKIHON,o_rHKSSOFUSAKI);
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 END
            --郵便番号編集処理
            nRTN := KKAPK0010.FYUBINHENSHU(o_rHKSSOFUSAKI.YUBIN_NO, R_WK(I_IDX).SOFU_YUBIN);
            R_WK(I_IDX).SOFU_YUBIN := KKAPK0010.FMULTIBYTEHENKAN(R_WK(I_IDX).SOFU_YUBIN, 0);     --送付先郵便番号
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
            R_WK(I_IDX).YUBIN_NOBC := o_rHKSSOFUSAKI.YUBIN_NOBC;                                 --カスタマーバーコード
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 END
            --送付先住所
            R_WK(I_IDX).SOFU_JUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, o_rHKSSOFUSAKI.CHOMEI, o_rHKSSOFUSAKI.BANCHI, NULL, NULL);
            R_WK(I_IDX).SOFU_KATAGAKI := o_rHKSSOFUSAKI.KATAGAKI;                      --送付先方書
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
            IF i_NDV_KBN = 1 THEN
              --学齢簿.保護者宛名番号でDV判定
              --住所マスク文字列
--  2024/09/11 ZCZL.WANGMING UPDATE 0.3.000.002:8月1日認識合わせの横展開
--              R_WK(I_IDX).SOFU_JUSHO := GAAPK0030.FDVJUSHO('GKB', R_WK(I_IDX).HOGOSHA_KANJI_1, g_sTANTOCODE, g_sWSNUM, R_WK(I_IDX).SOFU_JUSHO, nHANTEIKEKKA, 2, NULL, NULL);   --送付先住所
--              R_WK(I_IDX).SOFU_JUSHO := GAAPK0030.FDVJUSHO('GKB', i_NJIDO_KOJIN_NO_1, g_sTANTOCODE, g_sWSNUM, R_WK(I_IDX).SOFU_JUSHO, nHANTEIKEKKA, 2, NULL, NULL);   --送付先住所
              sCTLPRM := GAAPK0030.FDVJUSHO('GKB', i_NJIDO_KOJIN_NO_1, g_sTANTOCODE, g_sWSNUM, R_WK(I_IDX).SOFU_JUSHO, nHANTEIKEKKA, 2, NULL, NULL); --住所マスク文字列
              IF nHANTEIKEKKA = 1 THEN
                R_WK(I_IDX).SOFU_YUBIN := NULL;                                       --送付先郵便番号
                R_WK(I_IDX).YUBIN_NOBC := NULL;                                       --カスタマーバーコード
                R_WK(I_IDX).SOFU_JUSHO := sCTLPRM;                                    --送付先住所
                R_WK(I_IDX).SOFU_KATAGAKI := NULL;                                    --送付先方書
              END IF;
            END IF;
            R_WK(I_IDX).SOFU_ATENA := o_rHKSSOFUSAKI.SHIMEI_KANJI || '　' || '様';             --送付先宛名
--            R_WK(I_IDX).YUBIN_NOBC := o_rHKSSOFUSAKI.YUBIN_NOBC;                      --カスタマーバーコード
            g_vHOGOSHA_FLG := FALSE;
          ELSE
            R_WK(I_IDX).SOFU_YUBIN := NULL;                                        --送付先郵便番号
            R_WK(I_IDX).SOFU_JUSHO := NULL;                                        --送付先住所
            R_WK(I_IDX).SOFU_KATAGAKI := NULL;                                     --送付先方書
            IF R_WK(I_IDX).GAKKOCHO IS NOT NULL THEN
              R_WK(I_IDX).SOFU_ATENA := R_WK(I_IDX).GAKKOCHO || '　' || '様';      --送付先宛名(学校長)
            ELSE
              R_WK(I_IDX).SOFU_ATENA := NULL;                                        --送付先宛名
            END IF;
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 END
            R_WK(I_IDX).YUBIN_NOBC := NULL;                                        --カスタマーバーコード
          END IF;
          R_WK(I_IDX).TOIAWASESAKI1           := g_vTOIAWASESAKI1;      -- お問い合わせ先
          R_WK(I_IDX).TOIAWASESAKI2           := g_vTOIAWASESAKI2;      -- お問い合わせ先住所
          R_WK(I_IDX).TOIAWASESAKI3           := g_vTOIAWASESAKI3;      -- お問い合わせ先電話番号
          R_WK(I_IDX).TSUCHIBUN               := REPLACE(rGKBTTSUCHISHOKANRITY.TSUCHIBUN,chr(13)||chr(10),'#');      -- 通知文
-- 2024/06/11 ZCZL.muzl Add end
-- 2024/06/12 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
          -- 児童２がいて、１ページの表示児童数が２人以上なら出力
--           IF (IJIDO_IDX + 1) <= MJIDO.LAST AND
--              I_JIDO_PER_PAGE >= 2 THEN
--             IJIDO_IDX := IJIDO_IDX + 1;
--             R_WK(I_IDX).SEQ_NO_2            := MJIDO(IJIDO_IDX).ISEQ_NO;          -- 連番２
--             R_WK(I_IDX).SHIMEI_KANA_2       := i_VSHIMEI_KANA_2;                  -- 氏名かな２
--             R_WK(I_IDX).SHIMEI_KANJI_2      := i_VSHIMEI_KANJI_2;                 -- 氏名漢字２
--             R_WK(I_IDX).SEIBETSU_2          := MJIDO(IJIDO_IDX).VSEIBETSU;        -- 性別２
          --児童１の生年月日編集
--           IF N_JIDO_JINGAKU_2 = 1 THEN
--              R_WK(I_IDX).SEINENGAPI_2 := FUNC_SET_SEIGYO_SEINENGAPI(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1) || TO_CHAR(MJIDO(IJIDO_IDX).ISEINENGAPI);--人格区分1 || 生年月日１
--           ELSE
--             R_WK(I_IDX).SEINENGAPI_2  := TO_CHAR(MJIDO(IJIDO_IDX).VJINKAKU_KBN) ||
--                                                TO_CHAR(MJIDO(IJIDO_IDX).ISEINENGAPI);        --人格区分2 || 生年月日2
--           END IF;
--             R_WK(I_IDX).GAKUNEN_2           := MJIDO(IJIDO_IDX).VGAKUNEN;           -- 学年２
--             R_WK(I_IDX).HOGOSHA_KOJIN_NO_2  := MJIDO(IJIDO_IDX).NHOGOSHA_KOJIN_NO;  -- 学年２
--             R_WK(I_IDX).HOGOSHA_KANA_2      := i_VHOGOSHA_KANA_2;                   -- 保護者名かな２
--             R_WK(I_IDX).HOGOSHA_KANJI_2     := i_VHOGOSHA_KANJI_2;                  -- 保護者名漢字２
--           END IF;
          -- 児童３がいて、１ページの表示児童数が３人以上なら出力
--           IF (IJIDO_IDX + 1) <= MJIDO.LAST AND
--              I_JIDO_PER_PAGE >= 3  THEN
--             IJIDO_IDX := IJIDO_IDX + 1;
--             R_WK(I_IDX).SEQ_NO_3            := MJIDO(IJIDO_IDX).ISEQ_NO;            -- 連番３
--             R_WK(I_IDX).SHIMEI_KANA_3       := i_VSHIMEI_KANA_3;                    -- 氏名かな３
--             R_WK(I_IDX).SHIMEI_KANJI_3      := i_VSHIMEI_KANJI_3;                   -- 氏名漢字３
--             R_WK(I_IDX).SEIBETSU_3          := MJIDO(IJIDO_IDX).VSEIBETSU;          -- 性別３
          --児童１の生年月日編集
--           IF N_JIDO_JINGAKU_3 = 1 THEN
--              R_WK(I_IDX).SEINENGAPI_3 := FUNC_SET_SEIGYO_SEINENGAPI(o_MEISYUPRM(3),N_NAIYO_CD_JIDO_1) || TO_CHAR(MJIDO(IJIDO_IDX).ISEINENGAPI);--人格区分1 || 生年月日１
--           ELSE
--             R_WK(I_IDX).SEINENGAPI_3  := TO_CHAR(MJIDO(IJIDO_IDX).VJINKAKU_KBN) ||
--                                                TO_CHAR(MJIDO(IJIDO_IDX).ISEINENGAPI);        --人格区分3 || 生年月日3
--           END IF;
--             R_WK(I_IDX).GAKUNEN_3           := MJIDO(IJIDO_IDX).VGAKUNEN;           -- 学年３
--             R_WK(I_IDX).HOGOSHA_KOJIN_NO_3  := MJIDO(IJIDO_IDX).NHOGOSHA_KOJIN_NO;  -- 学年３
--             R_WK(I_IDX).HOGOSHA_KANA_3      := i_VHOGOSHA_KANA_3;                   -- 保護者名かな３
--             R_WK(I_IDX).HOGOSHA_KANJI_3     := i_VHOGOSHA_KANJI_3;                  -- 保護者名漢字３
--           END IF;
-- 2024/06/12 ZCZL.muzl Delete end
          -- 公印戻り値設定
          o_VGYOMU_KOIN := R_WK(I_IDX).KYOIKU_KOIN_MEI;
          o_VSHUCHO_KOIN := R_WK(I_IDX).SHUCHO_KOIN_MEI;
          I_IDX := I_IDX + 1;
        END LOOP;

        -- 旧学校分を出力する際のページ番号のために
        -- 旧学校分の開始ページ番号を設定
        IF i_ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_OLD THEN
          I_PAGE_NUM_BASE := I_ALLPAGE;
        ELSE
          I_PAGE_NUM_BASE := I_ALLPAGE + I_PAGE_NUM_BASE;
        END IF;
        I_FRTN := c_ISUCCESS;

      EXCEPTION
        WHEN OTHERS THEN
          NSQLCODE := SQLCODE;
          VSQLERRM := SUBSTR(SQLERRM, 1, 250);
      END;
      RETURN I_FRTN;
    END FUNC_EDIT_DATA;
    --------------------------------------------------------
    --  機能概要      : テーブル追加処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_INSERT_WK
      RETURN PLS_INTEGER
    IS
      I_FRTN   PLS_INTEGER;   -- 戻り値
    BEGIN
      BEGIN
        I_FRTN := c_ISUCCESS;
        FOR I_LOOPCNT IN R_WK.FIRST..R_WK.LAST LOOP
--  2024/11/15 ZCZL.WANGYUNING ADD 0.3.000.007:IT_GKB_00539仕様変更対応
          --INSERT INTO GKBWIDOTSUCHI VALUES R_WK(I_LOOPCNT);
          FOR i in 1..i_VFHAKKOBUSUU LOOP
            INSERT INTO GKBWIDOTSUCHI VALUES R_WK(I_LOOPCNT);
          END LOOP;
--  2024/11/15 ZCZL.WANGYUNING ADD END
        END LOOP;

      EXCEPTION
        WHEN OTHERS THEN
          I_FRTN := c_INOT_SUCCESS;
          NSQLCODE := SQLCODE;
          VSQLERRM := SUBSTR(SQLERRM, 1, 250);
      END;
      RETURN I_FRTN;
    END FUNC_INSERT_WK;
    --------------------------------------------------------
    --  機能概要      : メインビジネスロジック処理
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        EXCEP                 EXCEPTION;
-- 2025/05/20 ZCZL.wanghj Add start 1.0.004.000:認証コード名を取得
        VSHUCHOMEI                  NVARCHAR2(50);
        o_nDAIRIKBN                 NUMBER;
        o_vKATAGAKI1                NVARCHAR2(50);
        o_vKATAGAKI2                NVARCHAR2(50);
        o_vKOINFILENAME             NVARCHAR2(50);
-- 2025/05/20 ZCZL.wanghj Add end
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');
        -- 戻り値初期化
        o_VGYOMU_KOIN  := NULL;
        o_VSHUCHO_KOIN := NULL;
        o_NSQLCODE     := 0;
        o_VSQLERRM     := NULL;
        -- システム条件取得
        --  教育異動通知書１票あたりに出力する児童生徒の人数（０or３：３人、１：１人、２：２人）
        I_SYSTEMJOKEN := FUNC_GET_SYSJOKEN(c_ISYS_JIDO_PER_PAGE);
        IF NVL(I_SYSTEMJOKEN, 0) = 0 THEN
          I_JIDO_PER_PAGE := 3;
        ELSE
          I_JIDO_PER_PAGE := I_SYSTEMJOKEN;
        END IF;
        -- 新小学１年生の異動通知書を別様式に分ける(0:しない,1:する)
        I_SHIN_SHO1_KIRIWAKE_KBN := FUNC_GET_SYSJOKEN(c_ISYS_SHIN_SHO1_KIRIWAKE);
        IF NVL(I_SHIN_SHO1_KIRIWAKE_KBN, -1) = -1 THEN
          I_SHIN_SHO1_KIRIWAKE_KBN := 0;
        END IF;
        -- 新小１とそれ以外の児童で分けて作成
        FOR ISHIN_SHO1_FLG IN c_ISHIN_SHO1_FLG_NOT_SHO1..c_ISHIN_SHO1_FLG_SHO1 LOOP
          -- 新小１を切り分けしないとき、２回目は通さない
          IF ISHIN_SHO1_FLG = c_ISHIN_SHO1_FLG_SHO1 AND
             I_SHIN_SHO1_KIRIWAKE_KBN = 0 THEN
            EXIT;
          END IF;
          -- ページ番号の開始番号を初期化
          I_PAGE_NUM_BASE := 0;
          R_WK.DELETE;
          -- ワークテーブルデータ削除処理
          I_RTN := KKAPK3000.FTRUNCATE(c_VWKTBL, VSQLERRM);
          IF I_RTN <> c_ISUCCESS THEN
            -- 異常終了の場合、戻り値にエラー内容を設定
            o_NSQLCODE := I_RTN;
            o_VSQLERRM := VSQLERRM;
            RAISE EXCEP;
          END IF;
-- 2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
          -- 本名・通称名出力制御を取得する
--           o_MEISYUPRM := A_CONS_PRM();
--           IMEISYUTURYOKUSEIGYO := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,o_MEISYUPRM,o_LENGTH);
--           IF IMEISYUTURYOKUSEIGYO = 1 THEN
--             o_MEISYUPRM := A_CONS_PRM();
--             o_MEISYUPRM.EXTEND;
--             o_MEISYUPRM.EXTEND;
--             o_MEISYUPRM(1) := 0;
--             o_MEISYUPRM.EXTEND;
--             o_MEISYUPRM(2) := 0;
--             o_MEISYUPRM.EXTEND;
--             o_MEISYUPRM(3) := 0;
--           ELSE
--             WHILE (o_LENGTH < 4) LOOP
--               o_MEISYUPRM.EXTEND;
--               o_MEISYUPRM(o_LENGTH+1) := 0;
--               o_LENGTH := o_LENGTH + 1;
--             END LOOP;
--           END IF;
-- 2024/06/11 ZCZL.muzl Delete end
          -- 教育委員会情報を取得する
          IKYOUIKUIINKAIJOUHOU       := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',i_VIINKAI,o_KYOIKUPRM,o_LENGTH);
          IF IKYOUIKUIINKAIJOUHOU = 1 THEN
            o_KYOIKUPRM := A_CONS_PRM();
            o_KYOIKUPRM.EXTEND;
            o_KYOIKUPRM.EXTEND;
            o_KYOIKUPRM(1) := ' ';
            o_KYOIKUPRM.EXTEND;
            o_KYOIKUPRM(2) := ' ';
            o_KYOIKUPRM.EXTEND;
            o_KYOIKUPRM(3) := ' ';
            o_KYOIKUPRM.EXTEND;
            o_KYOIKUPRM(4) := ' ';
            o_KYOIKUPRM.EXTEND;
            o_KYOIKUPRM(5) := ' ';
            o_KYOIKUPRM.EXTEND;
            o_KYOIKUPRM(6) := ' ';
            o_KYOIKUPRM.EXTEND;
            o_KYOIKUPRM(7) := ' ';
            o_KYOIKUPRM.EXTEND;
            o_KYOIKUPRM(8) := ' ';
          ELSE
-- 2024/06/18 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--             WHILE (o_LENGTH < 4) LOOP
            WHILE (o_LENGTH < 8) LOOP
              o_KYOIKUPRM.EXTEND;
              o_KYOIKUPRM(o_LENGTH+1) := ' ';
              o_LENGTH := o_LENGTH + 1;
            END LOOP;
-- 2024/06/05 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
            g_vTOIAWASESAKI1  := o_KYOIKUPRM(1);
            g_vTOIAWASESAKI2  := o_KYOIKUPRM(6);
            g_vTOIAWASESAKI3  := o_KYOIKUPRM(7);
-- 2024/06/05 ZCZL.muzl Add end
          END IF;
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
          IF i_IHOGOSHA_FLG = 1 THEN
            g_vHOGOSHA_FLG := TRUE;
          END IF;
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.009:品質強化：IT_GKB_10106、IT_GKB_10107対応 END
          FOR ISHIN_KYU_KBN IN c_ISHIN_KYU_KBN_NEW..c_ISHIN_KYU_KBN_HOGOSHA LOOP
            -- 新学校宛は無条件に作成、旧学校宛は旧学校長宛作成フラグが 1のときに作成
            -- 新学校宛は無条件に作成、旧学校宛は旧学校長宛作成フラグが 1のときに作成、保護者宛は保護者宛作成フラグが１のとき
            IF ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_NEW OR
               (ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_OLD AND
                i_IKYUGAKKOCHO_FLG = 1) OR
               (ISHIN_KYU_KBN = c_ISHIN_KYU_KBN_HOGOSHA AND
                i_IHOGOSHA_FLG = 1) THEN
              -- データ編集処理
              I_RTN := FUNC_EDIT_DATA(ISHIN_SHO1_FLG, ISHIN_KYU_KBN);
              IF I_RTN = c_INOT_SUCCESS THEN
                -- 異常終了の場合、戻り値にエラー内容を設定
                o_NSQLCODE := NSQLCODE;
                o_VSQLERRM := VSQLERRM;
                RAISE EXCEP;
              END IF;
            END IF;
          END LOOP;
-- 2025/01/31 JPJYS.GL UPDATE ST_GKB_TMP00025対応 start
--          IF R_WK.COUNT > 0 THEN
            -- データ追加処理
--            I_RTN := FUNC_INSERT_WK;
--           IF I_RTN = c_INOT_SUCCESS THEN
              -- 異常終了の場合、戻り値にエラー内容を設定
--              o_NSQLCODE := NSQLCODE;
--              o_VSQLERRM := VSQLERRM;
--              RAISE EXCEP;
--            END IF;
-- 2024/06/12 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
            -- 使用定義体名取得
--             CASE ISHIN_SHO1_FLG
--               WHEN c_ISHIN_SHO1_FLG_SHO1 THEN
--                 VTEIGITAI_ID := i_VTEIGITAI_S_ID;
--               WHEN c_ISHIN_SHO1_FLG_NOT_SHO1 THEN
--                 VTEIGITAI_ID := i_VTEIGITAI_ID;
--             END CASE;
-- 2024/06/12 ZCZL.muzl Delete end
            -- 教育異動通知書（即時）CSVファイル作成
            -- 初期化
--            DELETE FROM GKBWL090R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
-- 2024/06/12 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--             GKBSKIDOTCH(i_ISHORI_BI, i_ISHORI_JIKAN, g_sWSNUM, g_sTANTOCODE, VTEIGITAI_ID, NULL, g_nJOBNUM, c_ONLINE);
--            GKBSKIDOTCH(TO_NUMBER(TO_CHAR(SYSDATE,'YYMMDD')), TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'HH24MISS')), g_sWSNUM, g_sTANTOCODE, i_sCHOHYOID, NULL, g_nJOBNUM, c_ONLINE);
            -- 帳票出力CSVの作成
--            bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL090R001', i_sCHOHYOID);
--          END IF;
        END LOOP;
          IF R_WK.COUNT > 0 THEN
            -- データ追加処理
            I_RTN := FUNC_INSERT_WK;
            IF I_RTN = c_INOT_SUCCESS THEN
              -- 異常終了の場合、戻り値にエラー内容を設定
              o_NSQLCODE := NSQLCODE;
              o_VSQLERRM := VSQLERRM;
              RAISE EXCEP;
            END IF;
            -- 教育異動通知書（即時）CSVファイル作成
            -- 初期化
            DELETE FROM GKBWL090R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
-- 2025/05/20 ZCZL.wanghj Add start 1.0.004.000:認証コード名を取得
            bRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE,0),
                           g_sWSNUM,
                           TO_DATE(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'))),
                           o_nDAIRIKBN,
                           o_vKATAGAKI1,
                           o_vKATAGAKI2,
                           VSHUCHOMEI,
                           o_vKOINFILENAME);
-- 2025/05/20 ZCZL.wanghj Add end
-- 2025/05/20 ZCZL.wanghj Update 1.0.004.000:認証コード名を取得
--            GKBSKIDOTCH(TO_NUMBER(TO_CHAR(SYSDATE,'YYMMDD')), TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'HH24MISS')), g_sWSNUM, g_sTANTOCODE, i_sCHOHYOID, NULL, g_nJOBNUM, c_ONLINE);
            GKBSKIDOTCH(TO_NUMBER(TO_CHAR(SYSDATE,'YYMMDD')), TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'HH24MISS')), g_sWSNUM, g_sTANTOCODE, i_sCHOHYOID, NULL, g_nJOBNUM, o_vKOINFILENAME, o_vKATAGAKI1, VSHUCHOMEI, c_ONLINE);

            -- 帳票出力CSVの作成
            bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL090R001', i_sCHOHYOID);
          END IF;
-- 2025/01/31 JPJYS.GL UPDATE ST_GKB_TMP00025対応 end

        -- 関数終了
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理終了');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            g_sMESSAGE := o_NSQLCODE || o_VSQLERRM;
            bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 1, 0, SQLCODE, SQLERRM, '異常終了');
            RETURN FALSE;
    END FUNC_O10MAIN;
    ------------------------------------------------------------------------
    --  機能概要      : オンラインパラメータ取得処理
    --  パラメータ    : i_sGYOUMUCODE_LIST   業務コード（リスト）
    --                : i_sCHOHYONUM_LIST    帳票番号（リスト）
    --                : i_sCHOHYOID_LIST     帳票ID（リスト）
    --                : i_sPARAM             抽出条件（リスト）
    --                : i_sBUNSHONUM_LIST    文書番号情報（リスト）（リスト）
    --                : i_sTANTOCODE         ログイン情報.担当者コード
    --                : i_sWSNUM             ログイン情報.端末番号
    --                : o_RESULT             0:すべてのファイル生成成功 -1:異常終了
    --                : o_sCSVCNT_LIST       CSVファイル出力件数（リスト）
    --                : o_sCSVFILENAME_LIST  CSVファイル名（リスト）
    --                : o_sPRTFILENAME_LIST  印刷ファイル名(EMF,PDF)（リスト）
    --                : o_sMESSAGE           エラーメッセージ
    --  戻り値        : なし
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    ------------------------------------------------------------------------
    PROCEDURE PONLINE(i_sGYOUMUCODE_LIST  IN  NVARCHAR2,
                      i_sCHOHYONUM_LIST   IN  NVARCHAR2,
                      i_sCHOHYOID_LIST    IN  NVARCHAR2,
                      i_sPARAM            IN  NVARCHAR2,
                      i_sBUNSHONUM_LIST   IN  NVARCHAR2,
                      i_sTANTOCODE        IN  NVARCHAR2,
                      i_sWSNUM            IN  NVARCHAR2,
                      o_nRESULT           OUT NUMBER,
                      o_sCSVCNT_LIST      OUT NVARCHAR2,
                      o_sCSVFILENAME_LIST OUT NVARCHAR2,
                      o_sPRTFILENAME_LIST OUT NVARCHAR2,
                      o_sMESSAGE          OUT NVARCHAR2)
    IS
        bRTN                  BOOLEAN;                    --戻る値
        ePRMEXCEPTION         EXCEPTION;                  --パラメータ取得異常タイプ
        eSHORIEXCEPTION       EXCEPTION;                  --処理異常タイプ
        aGYOUMUCODE           KKBPK5551.tySPLIT_tbl;      -- 業務コード（リスト）
        aCHOHYONUM            KKBPK5551.tySPLIT_tbl;      -- 帳票番号（リスト）
        aCHOHYOID             KKBPK5551.tySPLIT_tbl;      -- 帳票ID（リスト）
    BEGIN
        --初期化
        g_nJOBNUM    := 0;                                --ジョブナンバー
        g_sTANTOCODE := i_sTANTOCODE;                     --担当者コード
        g_sWSNUM     := i_sWSNUM;                         --端末番号
        g_sBUNSHONUMLIST := i_sBUNSHONUM_LIST;            --文書番号情報（リスト）
        g_sCSV_RCNT := NULL;                              --CSVファイル出力件数
        g_sCSVFILENAME := NULL;                           --CSVファイル名
        g_sPRTFILENAME := NULL;                           --印刷ファイル名(EMF,PDF)

        -- 入力引数を分解して配列にセットする
        -- 引数の業務コード（リスト）の配列化
         aGYOUMUCODE := KKBPK5551.FSplitStr (i_sGYOUMUCODE_LIST);
        -- 引数の帳票番号（リスト）の配列化
         aCHOHYONUM := KKBPK5551.FSplitStr (i_sCHOHYONUM_LIST);
        -- 引数の帳票ID（リスト）の配列化
         aCHOHYOID := KKBPK5551.FSplitStr (i_sCHOHYOID_LIST);

        -- 初期処理
        bRTN := FUNC_O00INIT;
        IF NOT bRTN THEN
            o_sMESSAGE := g_sMESSAGE;
            RAISE ePRMEXCEPTION;
        END IF;

        -- パラメータ取得処理
        bRTN := FUNC_O01PINIT (i_sPARAM);
        IF NOT bRTN THEN
            RAISE ePRMEXCEPTION;
        END IF;

        -- 処理ステップを取得
        FOR i IN 1..aGYOUMUCODE.COUNT LOOP
            -- オンラインステップ処理パラメータ取得
            bRTN := FUNC_O02PINIT (aGYOUMUCODE(i), aCHOHYONUM(i));
            IF NOT bRTN THEN
                RAISE eSHORIEXCEPTION;
            END IF;
            --メイン処理
            IF i = 1 THEN
                bRTN := FUNC_O10MAIN (aGYOUMUCODE(i), aCHOHYOID(i));
                IF NOT bRTN THEN
                    o_sMESSAGE := g_sMESSAGE;
                    RAISE eSHORIEXCEPTION;
                END IF;
            ELSE
                bRTN := FUNC_O10MAIN (aGYOUMUCODE(i), KKBPK5551.c_CSVCOMBINATOR || aCHOHYOID(i));
                IF NOT bRTN THEN
                    o_sMESSAGE := g_sMESSAGE;
                    RAISE eSHORIEXCEPTION;
                END IF;
            END IF;

        END LOOP;

        COMMIT;

        o_sCSVCNT_LIST := g_sCSV_RCNT;
        o_sCSVFILENAME_LIST := g_sCSVFILENAME;
        o_sPRTFILENAME_LIST := g_sPRTFILENAME;
        o_nRESULT := c_OK;
        
    EXCEPTION
        WHEN ePRMEXCEPTION THEN
            o_sCSVCNT_LIST := NULL;
            o_sCSVFILENAME_LIST := NULL;
            o_sPRTFILENAME_LIST := NULL;
            o_nRESULT := c_ERR;
        WHEN eSHORIEXCEPTION THEN
            o_sCSVCNT_LIST := NULL;
            o_sCSVFILENAME_LIST := NULL;
            o_sPRTFILENAME_LIST := NULL;
            o_nRESULT := c_ERR;
            ROLLBACK;
        WHEN OTHERS THEN
            o_sCSVCNT_LIST := NULL;
            o_sCSVFILENAME_LIST := NULL;
            o_sPRTFILENAME_LIST := NULL;
            o_nRESULT := c_ERR;
            ROLLBACK;
    END PONLINE;
END GKBPA00080;
/