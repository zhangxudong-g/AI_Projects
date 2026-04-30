CREATE OR REPLACE PACKAGE BODY GKBPB00380
--1.0.451.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 健康診断結果通知書
--  機能概要      : 処理条件の学年の学年リンク(GKBTGAKUNENLNK)より個人番号をキーとして
--                  その児童生徒個人番号の学齢簿情報を
--                  児童生徒ワーク(GKBWJIDOSHINDANKEKKA)へセットし
--                  ソート条件に従い、並び順を決め、CSVファイルを作成する
--  バージョン    : Ver 1.0.200.000
--  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/07/03 ZCZL.qinyue Add 0.3.000.000:新WizLIFE2次開発
--  2024/08/20 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00018対応
--  2024/09/03 ZCZL.WANGMING UPDATE 0.3.000.002:IT_GKB_00075対応
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00074対応
--  2024/10/21 ZCZL.WANGMING Update 0.3.000.004:IT_GKB_00341横展開対応
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.005:IT_GKB_00429対応横展開
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00426対応
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/24 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00676対応
--  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応
--  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応
--  2025/05/22 CTC.SONGSHIHAO UPDATE 1.0.006.000:GKB_QA14765_GKB発送者一覧表の送付先住所が文字切れ対応
--  2025/07/10 CTC.GL UPDATE 1.0.010.001:GKB_QA17697対応
--  2025/07/18 CTC.HJF UOPDATE 1.0.010.001:GKB_QA17896対応
--  2025/08/22 CTC.GYY UPDATE 1.0.102.000:GKB_QA19542対応
--  2025/09/17 CTC.Zhou UPDATE 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
--  2025/11/17 CTC.GL UPDATE 1.0.301.000:GKB_QA22992対応
--  2025/12/05 CTC.NI UPDATE 1.0.402.000:不具合対応
--  2026/01/05 CTC.HJF UPDATE 1.0.451.000:GKB_QA25074対応
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
    g_nINDEX                      NUMBER := 0;

    g_nTIME                       NUMBER;                      --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX                   NUMBER := 0;
    g_nSTEP_INDEX                 NUMBER := 0;
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
    g_rBUNNUMSRCINF               KKAPK0040.MR_BUNNUMSRCINF;      --文書番号情報（構造体）
    g_rBUNNUMEDITKEKA             KKAPK0040.MR_BUNNUMEDITKEKA;   --文書番号編集結果
    nIBDEX                        NUMBER;            --健康診断結果通知書_インデックス番号
    g_nTCL                        NUMBER;            --健康診断結果通知書_出力制御
    g_nTSUCHICNT                  NUMBER;            --通知件数
    g_nCSVCNT                     NUMBER;            --CSV出力件数
    g_nTAISIXYOUCNT               NUMBER;            --対象者件数
    g_CTLPRM                      NVARCHAR2(500);    --抑止レベル３制御の要否
    TYPE MR_BUNNUM IS RECORD(
        nKOJINNUM                           NUMBER,                          --宛名番号
        sBUNNUM                             NVARCHAR2(1000)                  --文書番号
    );
    g_rBUNNUM                     NVARCHAR2(100);  --文書番号
    TYPE MR_BUNNUM_REC IS TABLE OF MR_BUNNUM INDEX BY BINARY_INTEGER;
    g_rHOKANBUNNUM          MR_BUNNUM_REC;   --文書番号保管リスト
    g_TSUCHIBUN             NVARCHAR2(1000); --診断結果通知文
    g_YOSHIKIBANGO          NVARCHAR2(1000); --様式番号
    g_KOINSHORYAKU          NVARCHAR2(1000); --診断結果公印省略
    g_KOINCHUSHAKU          NVARCHAR2(1000); --診断結果公印注釈
    --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
    rBUNNUMSRCINF1                   KKAPK0040.MR_BUNNUMSRCINF;    --文書番号情報（構造体）
    rBUNOUTINF1                      KKAPK0040.MR_BUNOUTINF;         --文書発行記録出力情報
    rBUNNUMEDITKEKA1                 KKAPK0040.MR_BUNNUMEDITKEKA;    --文書番号編集結果
    rBUNNUMSRCINF2                   KKAPK0040.MR_BUNNUMSRCINF;    --文書番号情報（構造体）
    rBUNOUTINF2                      KKAPK0040.MR_BUNOUTINF;         --文書発行記録出力情報
    rBUNNUMEDITKEKA2                 KKAPK0040.MR_BUNNUMEDITKEKA;    --文書番号編集結果
    g_vBUNNUM_KENKOSYO            NVARCHAR2(1000);                --文書番号_健康診断結果発送者一覧
    g_vBUNNUM_KENKOHYO            NVARCHAR2(1000);                --文書番号_健康診断結果診断票
    --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
-- 2024/07/03 ZCZL.qinyue Add end

    --パラメータ変数
 --  2024/07/05 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE２次開発
    --就学時健康診断通知書
    TYPE MR_rKANRI1 IS RECORD(
    TSUCHIBUN                 GKBTTSUCHISHOKANRI.TSUCHIBUN%TYPE,
    KOIN_SHORYAKU             GKBTTSUCHISHOKANRI.KOIN_SHORYAKU%TYPE,
    KOIN_CHUSHAKU             GKBTTSUCHISHOKANRI.KOIN_CHUSHAKU%TYPE,
    YOSHIKI_BANGO_SETTOGO     GKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO%TYPE,
    YOSHIKI_BANGO             GKBTTSUCHISHOKANRI.YOSHIKI_BANGO%TYPE,
    YOSHIKI_BANGO_SETSUBIGO   GKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO%TYPE
    );
    g_rKANRI1                 MR_rKANRI1;
--  2024/07/05 ZCZL.qinyue Add end
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
    TYPE  CTJIDO IS REF CURSOR;
    TYPE CRATENA_TYPE IS RECORD
    (
     KOJIN_NO               GKBTGAKUREIBO.KOJIN_NO%TYPE,
     RIREKI_RENBAN          GKBTGAKUREIBO.RIREKI_RENBAN%TYPE,
     GAKUNEN                GKBTGAKUREIBO.GAKUNEN%TYPE,
     SYOGAKO_CD             GKBTGAKUREIBO.SYOGAKO_CD%TYPE,
--  2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE２次開発
     HOGOSYA_KOJIN_NO       GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE,
--  2024/07/03 ZCZL.qinyue Add end
     SYOGAKO_SOTSUGYO_BI    GKBTGAKUREIBO.SYOGAKO_SOTSUGYO_BI%TYPE,
     SYOGAKO_TENGAKU_BI     GKBTGAKUREIBO.SYOGAKO_TENGAKU_BI%TYPE,
     KUIKIGAI_CD            GKBTGAKUREIBO.KUIKIGAI_CD%TYPE,
     KUIKIGAI_TAIGAKU_BI    GKBTGAKUREIBO.KUIKIGAI_TAIGAKU_BI%TYPE,
     KUIKIGAI_TENGAKU_BI    GKBTGAKUREIBO.KUIKIGAI_TENGAKU_BI%TYPE,
     KUIKIGAI_SOTSUGYO_BI   GKBTGAKUREIBO.KUIKIGAI_SOTSUGYO_BI%TYPE,
     YOGOGAKO_CD            GKBTGAKUREIBO.YOGOGAKO_CD%TYPE,
     YOGOGAKO_TENGAKU_BI    GKBTGAKUREIBO.YOGOGAKO_TENGAKU_BI%TYPE,
     YOGOGAKO_TAIGAKU_BI    GKBTGAKUREIBO.YOGOGAKO_TAIGAKU_BI%TYPE,
     YOGOGAKO_SOTSUGYO_BI   GKBTGAKUREIBO.YOGOGAKO_SOTSUGYO_BI%TYPE,
     CHOHYO_NO              GKBTGAKUREIBO.CHOHYO_NO%TYPE,
     TYUGAKO_CD             GKBTGAKUREIBO.TYUGAKO_CD%TYPE,
--  2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE２次開発
     RIREKI_RENBAN_EDA      GKBTGAKUREIBO.RIREKI_RENBAN_EDA%TYPE,
     KUNISHIRITSU_CD        GKBTGAKUREIBO.KUNISHIRITSU_CD%TYPE,
--  2024/07/03 ZCZL.qinyue Add end
--  2024/07/25 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE２次開発
     SHOGAKKOKU_CD          GKBTGAKUREIBO.SHOGAKKOKU_CD%TYPE
--  2024/07/25 ZCZL.qinyue Add end
      );
     CRATENA_WORK CRATENA_TYPE;
     VMSG NVARCHAR2(4000);
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
    g_vJYOUKEN1      NVARCHAR2(500);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
    --g_vJYOUKEN2      NVARCHAR2(500);
    --g_vJYOUKEN3      NVARCHAR2(500);
    --g_vJYOUKEN4      NVARCHAR2(500);
    g_vJYOUKEN2      NVARCHAR2(3000);
    g_vJYOUKEN3      NVARCHAR2(3000);
    g_vJYOUKEN4      NVARCHAR2(3000);
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
    g_vJYOUKEN5      NVARCHAR2(500);
    g_vJYOUKEN6      NVARCHAR2(500);
    g_vJYOUKEN7      NVARCHAR2(500);
    g_vJYOUKEN8      NVARCHAR2(500);
--  2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE２次開発
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
    --g_VKUNISHIRITSUGAKKOCD        NVARCHAR2(500); --国私立学校コード
    g_VKUNISHIRITSUGAKKOCD        NVARCHAR2(3000); --国私立学校コード
    g_TXTHAKKORIREKI              NVARCHAR2(500); --発行履歴
    g_OPTSHINENSOCHI              NVARCHAR2(500); --支援措置対象者マスク
--  2024/07/03 ZCZL.qinyue Add end
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
    -- 正常メッセージの値
    c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '健康診断結果通知書・診断結果票作成処理が正常終了しました。';
    -- エラーメッセージの値
    c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '健康診断結果通知書・診断票結果作成処理が異常終了しました。';
    -- 児童生徒ワーク
    c_VTABLE       CONSTANT  NVARCHAR2(128) := 'GKBWJIDOSHINDANKEKKA';
    -- １頁の最大行数
    c_IMAXROWS     CONSTANT  PLS_INTEGER := 15;
    -- 帳票区分
    c_CHOHYO_KBN   CONSTANT  NUMBER(2)      := 1;
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    IRTN               PLS_INTEGER;
    INENREI_KIJUNBI    PLS_INTEGER;
    ISAKUSEIBI         PLS_INTEGER;
    ISAKUSEIBI2        PLS_INTEGER;
    RGAKUREIBO         GKBTGAKUREIBO%ROWTYPE;
    RJIDO_ATENA        GABTATENAKIHON%ROWTYPE;
    RJIDO_SOFU         GABTSOFUSAKI%ROWTYPE;
    RHOGO_ATENA        GABTATENAKIHON%ROWTYPE;
    RHOGO_SOFU         GABTSOFUSAKI%ROWTYPE;
    RHOGO_ATENA_NULL   GABTATENAKIHON%ROWTYPE;
    RHOGO_SOFU_NULL    GABTSOFUSAKI%ROWTYPE;
    IGAKO_CD           PLS_INTEGER;
    VGAKOMEI           NVARCHAR2(60);
    VSEINENGAPI        NVARCHAR2(11);
    VSEIBETSU          NVARCHAR2(2);
--  2024/07/03 ZCZL.qinyue Update 0.3.000.000:新WizLIFE２次開発
--    VSETAI_NO          NVARCHAR2(7);
    VSETAI_NO          NVARCHAR2(15);
    VGYOSEIKU_MEI      NVARCHAR2(20);
    VHAN_MEI           NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.005:IT_GKB_00429対応横展開
--    VSANTEIDANTAI_MEI  NVARCHAR2(20);
    VSANTEIDANTAI_MEI  GKBWJIDOSHINDANKEKKA.SANTEIDANTAIMEI%TYPE;
    VHYOUJINENDO       NVARCHAR2(10);
    VSASKUSEIBI        NVARCHAR2(30);
    VHASSOBI           NVARCHAR2(30);
    VHOGOSHA_SHIMEI_JODAN     NVARCHAR2(100);
    VHOGOSHA_SHIMEI_GEDAN     NVARCHAR2(100);
    VJUSHO_JODAN              NVARCHAR2(30);
    VJUSHO_GEDAN              NVARCHAR2(30);
    VCNT                      NVARCHAR2(6);
    VZOKUGARAMEI1      NVARCHAR2(30);
    VZOKUGARAMEI2      NVARCHAR2(30);
    VGAKUNENMEI        NVARCHAR2(20);
    NGAKUNENSEI        NUMBER;
    VGAKUNENSEI        NVARCHAR2(20);
    INENREI            PLS_INTEGER;
    VNENREI            NVARCHAR2(3);
    VSYUHATU_MEI       NVARCHAR2(12);
    VHASOBI            NVARCHAR2(11);
    VUSERMEI           NVARCHAR2(40);
    IDATE1             PLS_INTEGER;
    VDATE1             NVARCHAR2(11);
    IDATE2             PLS_INTEGER;
    VDATE2             NVARCHAR2(11);
    IDATE3             PLS_INTEGER;
    VDATE3             NVARCHAR2(11);
    IDATE4             PLS_INTEGER;
    VDATE4             NVARCHAR2(11);
    IDATE5             PLS_INTEGER;
    VDATE5             NVARCHAR2(11);
    VKOMOKU1           NVARCHAR2(120);
    VKOMOKU2           NVARCHAR2(120);
    VKOMOKU3           NVARCHAR2(120);
    VKOMOKU4           NVARCHAR2(120);
    VKOMOKU5           NVARCHAR2(120);
    VKOMOKU6           NVARCHAR2(120);
    VKOMOKU7           NVARCHAR2(120);
    VKOMOKU8           NVARCHAR2(120);
    VKOMOKU9           NVARCHAR2(120);
    VKOMOKU10          NVARCHAR2(120);
    VDATE_MEI1         NVARCHAR2(40);
    VDATE_MEI2         NVARCHAR2(40);
    VDATE_MEI3         NVARCHAR2(40);
    VDATE_MEI4         NVARCHAR2(40);
    VDATE_MEI5         NVARCHAR2(40);
    VKOMOKU_MEI1       NVARCHAR2(40);
    VKOMOKU_MEI2       NVARCHAR2(40);
    VKOMOKU_MEI3       NVARCHAR2(40);
    VKOMOKU_MEI4       NVARCHAR2(40);
    VKOMOKU_MEI5       NVARCHAR2(40);
    VKOMOKU_MEI6       NVARCHAR2(40);
    VKOMOKU_MEI7       NVARCHAR2(40);
    VKOMOKU_MEI8       NVARCHAR2(40);
    VKOMOKU_MEI9       NVARCHAR2(40);
    VKOMOKU_MEI10      NVARCHAR2(40);
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN               BOOLEAN;
    B_RTN              BOOLEAN;
    I_RTN              PLS_INTEGER;
    -- 処理条件（画面からの引数）
    VNENDO             NVARCHAR2(15);      -- 対象年度
    VGAKUNEN           NVARCHAR2(15);      -- 学年
    NHASSOUKBN         NUMBER(3,0);
    KYOIKUKAI_RENRAKUSAKI  NVARCHAR2(100);
    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWJIDOSHINDANKEKKA%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK MTJIDO_TYPE;
    o_NBREAK         NUMBER(2);
    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    BRTNSEINENGAPI                  BOOLEAN;
    IWAREKIHIZUKE                  PLS_INTEGER;
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
    -- 共通情報取得用変数(KKAPK0030.FKYOTU)
    o_IUSER_ID                  PLS_INTEGER; -- 市町村コード
    o_IGAPPEI_BI                PLS_INTEGER; -- 合併日付
    o_IJICHI_CD                 PLS_INTEGER; -- 自治コード
    o_IUSER_KBN                 PLS_INTEGER; -- 市町村区分
    o_VKENMEI                   NVARCHAR2(30); -- 県名
    o_VGUNSHIMEI                NVARCHAR2(30); -- 郡市名
    o_VUSERMEI                  NVARCHAR2(40); -- 市町村名
    o_VSHUCHOMEI                NVARCHAR2(40); -- 首長名
    o_VSHUCHONINSHOBUN          NVARCHAR2(100); -- 首長認証文
    o_VYUBIN_NO                 NVARCHAR2(10); -- 郵便番号
    o_VSHOZAICHI                NVARCHAR2(200); -- 所在地
    o_VTEL_NO                   NVARCHAR2(20); -- 代表電話番号
    VSQLERRM         NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
    VPAGENM          NVARCHAR2(500);    -- 改頁項目名
    VPAGEFD          NVARCHAR2(500);    -- 改頁項目値
    --公印ファイル名取得
    VSHUCHO                 NVARCHAR2(100); --首長公印ファイル名
    VSHUNYUYAKU             NVARCHAR2(100); --収入役公印ファイル名
    VGYOMU                  NVARCHAR2(100); --業務毎公印ファイル名
    VNINSHOSHAKATAGAKI      NVARCHAR2(100);  --認証者肩書
--  2024/08/20 ZCZL.WANGMING ADD 0.3.000.001:IT_GKB_00018対応
    o_vSHIMEI        NVARCHAR2(1000);
--  2024/08/20 ZCZL.WANGMING DELETE 0.3.000.001:IT_GKB_00018対応
--    VNINSHOSHAMEI           NVARCHAR2(100);  --認証者名
    NKIJUNBI      NUMBER(8);         --基準日
    NNENDO        NUMBER(3);         --対象年度
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
    --VSYOGAKOU     NVARCHAR2(100);   --小学校コード
    --VKUIKIGAI     NVARCHAR2(100);   --区域外学校コード
    --VYOGOGAKO     NVARCHAR2(100);   --盲聾養護学校コード
-- 2024/07/16 ZCZL.qinyue Add 0.3.000.000:新WizLIFE2次開発
    --VKUNISHIRITSU NVARCHAR2(100);   --国私立学校コード
    VSYOGAKOU     NVARCHAR2(3000);   --小学校コード
    VKUIKIGAI     NVARCHAR2(3000);   --区域外学校コード
    VYOGOGAKO     NVARCHAR2(3000);   --盲聾養護学校コード
    VKUNISHIRITSU NVARCHAR2(3000);   --国私立学校コード
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
    NRENBAN       NUMBER(1);        --帳票連番使用有無
    NHAKKOUBI     NUMBER;        --発行日
    NHAKKOUBI1    NUMBER;
    IWAREKI1      NUMBER;
    ISEIREKI1     NUMBER;
    NKIJUNBI1     NVARCHAR2(11);
    o_ATENAPRM    A_CONS_PRM;   --宛先の氏名出力制御
    o_KYOIKUPRM   A_CONS_PRM;   --教育委員会情報
    o_RENBANPRM   A_CONS_PRM;   --帳票連番印字項目の制御
    o_LENGTH      NUMBER;
    VYUBIN_NO1    NVARCHAR2(60);    -- 郵便番号編集用
    NCHOHYO_NO2   NVARCHAR2(6);     -- ZZZZ9表示連番
    VGAKOKU_CD2   NVARCHAR2(5);     -- ZZZZ9学校コード
    NSHIMEI_KANJI          NVARCHAR2(110);       --氏名漢字
    KYOIKUIINKAI_CD        NUMBER;               --教育委員会コード
    NSYOGAKOKYOIKUIINKAI_CD       NUMBER(2);  --小学校教育委員会
    NKUIKIGAIKYOIKUIINKAI_CD      NUMBER(2);  --区域外学校教育委員会
    NYOGOGAKOKYOIKUIINKAI_CD      NUMBER(2);  --養護学校養護教育委員会
    o_SHIMEIPRM      A_CONS_PRM;   --氏名印字.制御ﾊﾟﾗﾒｰﾀ
    --BPRMFLG_001      BOOLEAN;
    --BPRMFLG_002      BOOLEAN;
    --BPRMFLG_003      BOOLEAN;
    --BPRMFLG_004      BOOLEAN;
    --o_YMD2           NVARCHAR2(30);
    --N_NAIYO_CD       GKBTSHIMEIJKN.NAIYO_CD%TYPE;
    NKENSU           NUMBER;    --対象者件数
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
--  2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        --------------------------------------------------------
    --  機能概要      : 学校コード取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.qinyue 2024/06/17
    --------------------------------------------------------
    FUNCTION FUNC_GET_GAKOCD(i_sGAKOCD IN NVARCHAR2, o_sGAKOCD OUT NVARCHAR2) RETURN BOOLEAN
    IS
        aGAKOCD           KKBPK5551.tySPLIT_tbl;      -- 業務コード（リスト）
--  2024/11/14 ZCZL.WANGYUNING ADD 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        nGAKOUCD_TMP  NUMBER; --学校コード
    BEGIN
        -- 入力引数を分解して配列にセットする
        -- 引数の業務コード（リスト）の配列化
        aGAKOCD := KKBPK5551.FSplitStr (i_sGAKOCD);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
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
--  2024/11/24 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00676対応 Start
--            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
            nGAKOUCD_TMP := TO_NUMBER(aGAKOCD(i));
--  2024/11/24 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:IT_GKB_00676対応 End
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
--  2024/07/03 ZCZL.qinyue Add
    --------------------------------------------------------
    --  機能概要      : バッチ初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        v_cmbChohyoRenbanShiyoUmu           DBMS_UTILITY.MAXNAME_ARRAY;
        --v_cmbHassoKbn                       DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/09/03 ZCZL.WANGMING ADD START 0.3.000.002:IT_GKB_00075対応
        cmboptShinenSochi    DBMS_UTILITY.MAXNAME_ARRAY;
        cmboptHakkoRireki    DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/09/03 ZCZL.WANGMING ADD END
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        objShogakkoCd               DBMS_UTILITY.MAXNAME_ARRAY;
        objKuikigaiGakkoCd          DBMS_UTILITY.MAXNAME_ARRAY;
        objTokubetsuShienGakkoCd    DBMS_UTILITY.MAXNAME_ARRAY;
        objKuniShiritsuGakkoCd    DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/14 ZCZL.WANGYUNING ADD END
    BEGIN
        g_vJYOUKEN1 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNendo');
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_vJYOUKEN2 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShogakkoCd');
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtShogakkoCd');
        g_vJYOUKEN2 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShogakkoCd',0, objShogakkoCd);--小学校コード
        --g_vJYOUKEN3 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKuikigaiGakkoCd');
        objKuikigaiGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKuikigaiGakkoCd');
        g_vJYOUKEN3 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuikigaiGakkoCd',0, objKuikigaiGakkoCd);--区域外学校コード
        --g_vJYOUKEN4 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtTokubetsuShienGakkoCd');
        objTokubetsuShienGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtTokubetsuShienGakkoCd');
        g_vJYOUKEN4 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtTokubetsuShienGakkoCd',0, objTokubetsuShienGakkoCd);--盲聾養護学校コード
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
        v_cmbChohyoRenbanShiyoUmu := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbChohyoRenbanShiyoUmu');
        g_vJYOUKEN5 := v_cmbChohyoRenbanShiyoUmu(1);
        g_vJYOUKEN6 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKijunBi');
        g_vJYOUKEN7 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHakkoBi');
--  2024/07/03 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE２次開発
--        v_cmbHassoKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbHassoKbn');
--        g_vJYOUKEN8 := v_cmbHassoKbn(1);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_VKUNISHIRITSUGAKKOCD := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKuniShiritsuGakkoCd'); -- 国私立学校コード
        objKuniShiritsuGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKuniShiritsuGakkoCd');
        g_VKUNISHIRITSUGAKKOCD := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuniShiritsuGakkoCd',0, objKuniShiritsuGakkoCd);--国私立学校コード
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
--  2024/09/03 ZCZL.WANGMING UPDATE START 0.3.000.002:IT_GKB_00075対応
--        g_OPTSHINENSOCHI := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShinenSochi');               -- 支援措置対象マスク
        cmboptShinenSochi := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'optShinenSochi');
        g_OPTSHINENSOCHI := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'optShinenSochi', 0, cmboptShinenSochi);
--        g_TXTHAKKORIREKI := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHakkoRireki');               -- 発行履歴
        cmboptHakkoRireki := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'optHakkoRireki');
        g_TXTHAKKORIREKI := KKBPK5551.FGETSPRM(g_sGYOUMUCODE, g_sSHORIID, 'optHakkoRireki', 0, cmboptHakkoRireki);
--  2024/09/03 ZCZL.WANGMING UPDATE END
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN2, VSYOGAKOU);      --小学校コード
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN3, VKUIKIGAI);      --区域外学校コード
        bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN4, VYOGOGAKO);      --盲聾養護学校コード
        bRTN := FUNC_GET_GAKOCD(g_VKUNISHIRITSUGAKKOCD, VKUNISHIRITSU);  --国私立学校コード
--  2024/07/03 ZCZL.qinyue Add end

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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
    --  機能概要      : 日付チェック
    --  パラメータ    : i_VHIZUKE
    --            : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 ,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2, i_IRENBAN IN NVARCHAR2) RETURN NUMBER IS
    IRET PLS_INTEGER;
    BRET BOOLEAN;
    TEMP_DATE DATE;
    BEGIN
      IRET := 0;
      --日付
      BEGIN
        IF i_IRENBAN = 1 AND i_VHIZUKE IS NOT NULL THEN
           IF LENGTH(i_VHIZUKE) <> 7 THEN
              IRET := 1;
           ELSE
              IWAREKIHIDUKEIO  := TO_NUMBER(i_VHIZUKE);
              ISEIREKIHIDUKEIO := 0;
           END IF;
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

      RETURN(IRET);
    END;
    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 年度チェック
    --  パラメータ    : i_VNENDO
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 ,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
    END;
    --------------------------------------------------------
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
-- 2024/09/03 ZCZL.WANGMING Add 0.3.000.002:IT_GKB_00075対応
        VMSG := '';
        --条件１のチェック
        IRTN := FUNCNENDOCHK( g_vJYOUKEN1 );
        IF IRTN <> 0 THEN
            VMSG := g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
        END IF;

--  2024/11/14 ZCZL.WANGYUNING DELETE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        --条件２のチェック
-- 2024/07/15 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--        IRTN := GKBPK00010.FGCODCHK( g_vJYOUKEN2 );
        --IRTN := GKBPK00010.FGCODCHK( VSYOGAKOU );
        --IF IRTN <> 0 THEN
        --    VMSG := VMSG || g_sGYOUMUCODE || ',99999,小学校コードが正しくありません。,;';
        --END IF;

        --条件３のチェック
-- 2024/07/15 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--        IRTN := GKBPK00010.FGCODCHK( g_vJYOUKEN3 );
        --IRTN := GKBPK00010.FGCODCHK( VKUIKIGAI );
        --IF IRTN <> 0 THEN
        --    VMSG := VMSG || g_sGYOUMUCODE || ',99999,区域外学校コードが正しくありません。,;';
        --END IF;

        --条件４のチェック
-- 2024/07/15 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--        IRTN := GKBPK00010.FGCODCHK( g_vJYOUKEN4 );
        --IRTN := GKBPK00010.FGCODCHK( VYOGOGAKO );
        --IF IRTN <> 0 THEN
        --    VMSG := VMSG || g_sGYOUMUCODE || ',99999,特別支援学校コードが正しくありません。,;';
        --END IF;
--  2024/11/14 ZCZL.WANGYUNING DELETE END

        --条件５のチェック
        IRTN := GKBPK00010.FRBCHK( g_vJYOUKEN5 );
        IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,帳票連番使用有無が正しくありません。,;';
        END IF;

        --条件６のチェック
        IF g_vJYOUKEN6 IS NOT NULL THEN
          IRTN := FUNCHIZUKECHK( g_vJYOUKEN6,1 );
          IF IRTN <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
          END IF;
        ELSE
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
        END IF;
        --条件７のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN7,1 );
        IF IRTN <> 0 THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,発行日が正しくありません。,;';
        END IF;

-- 2024/07/15 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
--  2024/11/14 ZCZL.WANGYUNING DELETE START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        --IRTN := GKBPK00010.FGCODCHK( VKUNISHIRITSU );
        --IF IRTN <> 0 THEN
        --    VMSG := VMSG || g_sGYOUMUCODE || ',99999,国私立学校コードが正しくありません。,;';
        --END IF;
--  2024/11/14 ZCZL.WANGYUNING DELETE END
-- 2024/07/15 ZCZL.qinyue Add end

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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
    --------------------------------------------------------------------------------------------------
    --  機能概要      : 教育委員会連絡先を取得
    --  パラメータ    : i_SEIGYORENBAN
    --                : i_EQNAME
    --                : i_EQTELNO
    --                : i_EQNAISENNO
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------------------------------------------------
    FUNCTION GET_EQRENRAKUSAKI(i_SEIGYORENBAN IN NUMBER
                              ,i_EQNAME       IN GKBWJIDOSHINDAN.KYOIKUKAI_MEI%TYPE
                              ,i_EQTELNO      IN GKBWJIDOSHINDAN.KYOIKU_TEL%TYPE
                              ,i_EQNAISENNO   IN GKBWJIDOSHINDAN.KYOIKU_TEL_NAISEN%TYPE) RETURN VARCHAR2 IS
      EQRENRAKUSAKI  NVARCHAR2(100);  --教育委員会連絡先
      SEIGYO         A_CONS_PRM;     --印字制御
      LEN            NUMBER;         --印字制御数
      RTN_NUM        NUMBER;
    BEGIN
      --印字制御を取得
      RTN_NUM := KKAPK0030.FPRMSHUTOKU('GKB', 'EQRENRAKUSAKI', i_SEIGYORENBAN, SEIGYO, LEN);
      IF RTN_NUM = 1 THEN
        RETURN '';
      END IF;
      WHILE (LEN < 3) LOOP
        SEIGYO.EXTEND;
        SEIGYO(LEN + 1) := NULL;
        LEN := LEN + 1;
      END LOOP;
      --教育委員会名を取得
      IF SEIGYO(1) = 1 THEN
        EQRENRAKUSAKI := EQRENRAKUSAKI || i_EQNAME;
      END IF;
      --教育委員会電話番号を取得
      IF SEIGYO(2) = 1 THEN
        IF EQRENRAKUSAKI IS NULL THEN
          EQRENRAKUSAKI := EQRENRAKUSAKI || i_EQTELNO;
        ELSE
          EQRENRAKUSAKI := EQRENRAKUSAKI || ' ' || i_EQTELNO;
        END IF;
      END IF;
      --教育委員会内線番号を取得
      IF SEIGYO(3) = 1 AND TRIM(i_EQNAISENNO) IS NOT NULL THEN
        EQRENRAKUSAKI := EQRENRAKUSAKI || '（内線：' || i_EQNAISENNO || '）';
      END IF;
      RETURN SUBSTR(EQRENRAKUSAKI, 1, 100);
    END GET_EQRENRAKUSAKI;
    --------------------------------------------------------------------------------------------------
    --  機能概要      : 幼稚園情報を取得
    --  パラメータ    : i_NENDO
    --                : i_KOJIN_NO
    --                : o_YOCHIEN_CD
    --                : o_YOCHIENMEI
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------------------------------------------------
    PROCEDURE GET_YOCHIEN_INFO(i_NENDO        IN  NUMBER
                              ,i_KOJIN_NO     IN  NUMBER
                              ,o_YOCHIEN_CD   OUT GKBWJIDOSHINDAN.YOCHIEN_CD%TYPE
                              ,o_YOCHIENMEI   OUT GKBWJIDOSHINDAN.YOCHIENMEI%TYPE) IS
    BEGIN
      BEGIN
        --GKB_QANo.15回答より、一応対応
        --SELECT NVL(YOCHIEN_CD, 0) INTO o_YOCHIEN_CD
        --FROM ETT_ENJI
        --WHERE NENDO = i_NENDO AND ENJI_KOJIN_NO = i_KOJIN_NO AND ROWNUM = 1
        --ORDER BY RIREKI_RENBAN DESC;
        o_YOCHIEN_CD := 0;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          o_YOCHIEN_CD := 0;
      END;
      BEGIN
        --GKB_QANo.15回答より、一応対応
        --SELECT NAME INTO o_YOCHIENMEI
        --FROM ETT_YOCHIEN
        --WHERE NENDO = i_NENDO AND YOCHIEN_CD = o_YOCHIEN_CD;
        o_YOCHIENMEI := NULL;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          o_YOCHIENMEI := NULL;
      END;
    END GET_YOCHIEN_INFO;
    --------------------------------------------------------------------------------------------------
    --  機能概要      : 処理条件の設定
    --  パラメータ    : IWAREKI
    --             : ISEIREKI
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 ,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------------------------------------------------
    PROCEDURE PROCHAISET IS
      IWAREKI  PLS_INTEGER;
      ISEIREKI PLS_INTEGER;
    BEGIN
      ISAKUSEIBI2 :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
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
      ISAKUSEIBI := NKIJUNBI;
      -- 市町村名の設定
      IRTN := KKAPK0030.FKYOTU(ISAKUSEIBI,
                               o_IUSER_ID,
                               o_IJICHI_CD,
                               o_IGAPPEI_BI,
                               o_IUSER_KBN,
                               o_VGUNSHIMEI,
                               o_VUSERMEI,
                               o_VSHUCHOMEI,
                               o_VKENMEI,
                               o_VSHUCHONINSHOBUN,
                               o_VYUBIN_NO,
                               o_VSHOZAICHI,
                               o_VTEL_NO);
      VUSERMEI := o_VUSERMEI;
    END PROCHAISET;
--2024/07/03 ZCZL.qinyue Delete start 0.3.000.000:新WizLIFE2次開発
/*
    --------------------------------------------------------------------------------
    --  機能概要      : 制御のフラグをセットするのを行う
    --  パラメータ    : i_KOJIN_NO
    --             : o_NAIYO_CD
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------------------------------
    FUNCTION FUNC_PRMFLGSET(i_KOJIN_NO IN NUMBER,o_NAIYO_CD OUT NUMBER) RETURN NUMBER IS
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
           AND CHOHYO_ID = 'GKB060R001';
        IF o_NAIYO_CD = 0 THEN
          ZERO_FLG  := TRUE;
        END IF;
      EXCEPTION
        --データを取得しない場合
        WHEN NO_DATA_FOUND THEN
        NODATAFOUND_FLG  := TRUE;
      END;
      --氏名印字.制御ﾊﾟﾗﾒｰﾀ(5)が1の場合
      IF o_SHIMEIPRM(5) = 1 THEN
        BPRMFLG_001  := TRUE;
      END IF;
      --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(5)が4、6場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(5) IN (4, 6) THEN
          BPRMFLG_002  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在する、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(5)が3、4、5、6場合
      IF NOT NODATAFOUND_FLG AND NOT ZERO_FLG THEN
        IF o_SHIMEIPRM(5) IN(3,4,5,6) THEN
          BPRMFLG_003  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(5)が4、5場合「生年月日」
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(5) IN (4, 5) THEN
          BPRMFLG_004  := TRUE;
        END IF;
      END IF;
    RETURN 0;
    END;
    --------------------------------------------------------------------------------
    --  機能概要      : 制御を行う
    --  パラメータ    : i_HONMYO
    --                : i_SHIMEI
    --                : o_SET
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 ,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
    END;
    */
--2024/07/03 ZCZL.qinyue Delete end
    --------------------------------------------------------------------------------
    --  機能概要      : 児童生徒中間（GKBWJIDOSHINDANKEKKA）レコードの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
      IFRET                PLS_INTEGER;                -- 戻り値
      NNENDO               PLS_INTEGER;                -- 年度
      NGAKUNEN_CD          NUMBER;                     -- 学年コード
      IRTNA                PLS_INTEGER;
      IRTNSANTEIDANTAI     PLS_INTEGER;
      IRTNAH               PLS_INTEGER;
      ICNT                 BINARY_INTEGER;             -- 戻り値
      BRTNSASKUSEIBI       BOOLEAN;
      IJUSHO_NAGASA        PLS_INTEGER;
      IRTNZOKUGARA1        PLS_INTEGER;
      IRTNZOKUGARAHERR1    PLS_INTEGER;
      IRTNZOKUGARA2        PLS_INTEGER;
      IRTNZOKUGARAHERR2    PLS_INTEGER;
      NPRTN                NUMBER;
      IWAREKI              PLS_INTEGER;
      VSQLSEL              VARCHAR2(1000);
      VSQL_GAKO            VARCHAR2(200);
      NKYOIKUIINKAI_CD     NUMBER(2,0);  --教育委員会コード
      n_YYYY               PLS_INTEGER;
      n_MM                 PLS_INTEGER;
      n_DD                 PLS_INTEGER;
      v_GYYMMDD3           NVARCHAR2(20);
      o_RATENA_REC   GABTATENAKIHON%ROWTYPE;
      o_RSOFU_REC    GABTSOFUSAKI%ROWTYPE;
      o_YOCHIEN_CD   GKBWJIDOSHINDAN.YOCHIEN_CD%TYPE;
      o_YOCHIENMEI   GKBWJIDOSHINDAN.YOCHIENMEI%TYPE;
      CJIDO CTJIDO;
-- 2024/07/05 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
      nRTN               PLS_INTEGER;
      sBUNSHONOTMP       NVARCHAR2(100); --文書番号TMP
      sSHIMEIKANA        NVARCHAR2(200); --児童生徒氏名カナ(編集後)
      sSHIMEI            NVARCHAR2(200); --児童生徒氏名漢字(編集後)
      sBIRTHDAY          NVARCHAR2(20);  --児童生徒生年月日(編集後)
      sSHIMEIKANA2       NVARCHAR2(200); --保護者氏名カナ(編集後)
      sSHIMEI2           NVARCHAR2(200); --保護者氏名漢字(編集後)
      sBIRTHDAY2         NVARCHAR2(20);  --保護者生年月日(編集後)
      sJUSHO             NVARCHAR2(200); --住所
      --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
      o_nDAIRIKBN        NVARCHAR2(1000);
      o_vKATAGAKI1       NVARCHAR2(1000);
      o_vKATAGAKI2       NVARCHAR2(1000);
      o_vKOINFILENAME    NVARCHAR2(1000);
      --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
      tKANRI1_REC        MR_rKANRI1;

      CURSOR MC_CUR1
          IS
             SELECT TSUCHIBUN,
                    KOIN_SHORYAKU,
                    KOIN_CHUSHAKU,
                    YOSHIKI_BANGO_SETTOGO,
                    YOSHIKI_BANGO,
                    YOSHIKI_BANGO_SETSUBIGO
             FROM GKBTTSUCHISHOKANRI
             WHERE CHOHYO_KBN = '6';
--  2024/07/05 ZCZL.qinyue Add end
    BEGIN
      IFRET := c_INOTFOUND;                 -- 該当なし
      NGAKUNEN_CD := TO_NUMBER(VGAKUNEN);   -- 学年
      -- ワーク領域の初期化
      MJIDO_WORK.DELETE;
      ICNT := 0;
--  2024/07/05 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE２次開発
      --「就学時健康診断通知書」の通知書情報を取得する。
      FOR MC_CUR IN MC_CUR1 LOOP
        tKANRI1_REC := MC_CUR;
      END LOOP;
      g_rKANRI1 := tKANRI1_REC;
      --取得情報を変数に設定
      g_TSUCHIBUN := g_rKANRI1.TSUCHIBUN;
      --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
      --g_YOSHIKIBANGO := g_rKANRI1.YOSHIKI_BANGO || g_rKANRI1.YOSHIKI_BANGO_SETSUBIGO || g_rKANRI1.YOSHIKI_BANGO_SETTOGO;
      g_YOSHIKIBANGO := g_rKANRI1.YOSHIKI_BANGO_SETTOGO || g_rKANRI1.YOSHIKI_BANGO || g_rKANRI1.YOSHIKI_BANGO_SETSUBIGO;
      --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
      IF VGYOMU IS NOT NULL THEN
        g_KOINSHORYAKU := NULL;
        g_KOINCHUSHAKU := g_rKANRI1.KOIN_CHUSHAKU;
      ELSE
        g_KOINSHORYAKU := g_rKANRI1.KOIN_SHORYAKU;
        g_KOINCHUSHAKU := NULL;
      END IF;
-- 2024/07/05 ZCZL.qinyue Add end
      BEGIN
        -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
        VSQLSEL := '';
        VSQLSEL := VSQLSEL || 'SELECT ';
        VSQLSEL := VSQLSEL || 'B.KOJIN_NO, B.RIREKI_RENBAN, B.GAKUNEN, B.SYOGAKO_CD, ';
-- 2024/07/03 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--         VSQLSEL := VSQLSEL || 'B.SYOGAKO_SOTSUGYO_BI, B.SYOGAKO_TENGAKU_BI, ';
        VSQLSEL := VSQLSEL || 'B.HOGOSYA_KOJIN_NO,B.SYOGAKO_SOTSUGYO_BI, B.SYOGAKO_TENGAKU_BI, ';
        VSQLSEL := VSQLSEL || 'B.KUIKIGAI_CD, B.KUIKIGAI_TAIGAKU_BI, B.KUIKIGAI_TENGAKU_BI, ';
        VSQLSEL := VSQLSEL || 'B.KUIKIGAI_SOTSUGYO_BI, B.YOGOGAKO_CD, ';
        VSQLSEL := VSQLSEL || 'B.YOGOGAKO_TENGAKU_BI, B.YOGOGAKO_TAIGAKU_BI, ';
        VSQLSEL := VSQLSEL || 'B.YOGOGAKO_SOTSUGYO_BI, B.CHOHYO_NO, B.TYUGAKO_CD ';
-- 2024/07/03 ZCZL.qinyue Add 0.3.000.000:新WizLIFE2次開発
        VSQLSEL := VSQLSEL || ', B.RIREKI_RENBAN_EDA, B.KUNISHIRITSU_CD, B.SHOGAKKOKU_CD '; --児童生徒_個人履歴番号枝番 国私立学校コード 小学校区コード
        VSQLSEL := VSQLSEL || 'FROM ';
        VSQLSEL := VSQLSEL || 'GKBTGAKUREIBO B, ';
        VSQLSEL := VSQLSEL || '(SELECT KOJIN_NO,MAX(RIREKI_RENBAN) AS RIREKI_RENBAN ';
        VSQLSEL := VSQLSEL || 'FROM GKBTGAKUREIBO ';
        VSQLSEL := VSQLSEL || 'WHERE SHORIBI<='|| NKIJUNBI;
        VSQLSEL := VSQLSEL || ' GROUP BY KOJIN_NO) C';
        VSQLSEL := VSQLSEL || ' WHERE  ';
        VSQLSEL := VSQLSEL || 'C.KOJIN_NO = B.KOJIN_NO ';
        VSQLSEL := VSQLSEL || 'AND C.RIREKI_RENBAN =B.RIREKI_RENBAN ';
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
-- 2025/11/17 CTC.GL UPDATE START 1.0.301.000:GKB_QA22992対応
--        VSQLSEL := VSQLSEL || 'AND B.SAISHIN_KBN = 0 '; --最新区分
-- 2025/11/17 CTC.GL UPDATE END
        VSQLSEL := VSQLSEL || 'AND B.SAKUJO_FLG = 0 '; --削除フラグ
        VSQLSEL := VSQLSEL || 'AND B.GEN_JIYU_CD = 0 '; --減事由コード
-- 2024/07/03 ZCZL.qinyue Add end
        VSQLSEL := VSQLSEL || 'AND B.GAKUNEN = 0 ';
        VSQLSEL := VSQLSEL || 'AND B.GEN_NENGAPI = 0 ';
-- 2024/07/15 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--         IF VSYOGAKOU IS NOT NULL  OR VKUIKIGAI IS NOT NULL OR VYOGOGAKO IS NOT NULL THEN
        IF VSYOGAKOU IS NOT NULL  OR VKUIKIGAI IS NOT NULL OR VYOGOGAKO IS NOT NULL OR VKUNISHIRITSU IS NOT NULL THEN
          VSQLSEL := VSQLSEL || 'AND (';
          IF VSYOGAKOU IS NOT NULL THEN
-- 2024/07/15 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--             IF  VKUIKIGAI IS NOT NULL OR  VYOGOGAKO IS NOT NULL THEN
             IF  VKUIKIGAI IS NOT NULL OR VYOGOGAKO IS NOT NULL OR VKUNISHIRITSU IS NOT NULL THEN
              VSQLSEL := VSQLSEL || 'B.SYOGAKO_CD IN ('|| VSYOGAKOU ||')  OR ';
            ELSE
              VSQLSEL := VSQLSEL || 'B.SYOGAKO_CD IN ('|| VSYOGAKOU ||')';
            END IF;
          END IF;
          IF VKUIKIGAI IS NOT NULL THEN
-- 2024/07/15 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--             IF VYOGOGAKO IS NOT NULL THEN
            IF VYOGOGAKO IS NOT NULL OR VKUNISHIRITSU IS NOT NULL THEN
              VSQLSEL := VSQLSEL || 'B.KUIKIGAI_CD IN ('|| VKUIKIGAI ||') OR ';
            ELSE
              VSQLSEL := VSQLSEL || 'B.KUIKIGAI_CD IN ('|| VKUIKIGAI ||')';
            END IF;
          END IF;
          IF VYOGOGAKO IS NOT NULL THEN
-- 2024/07/15 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--            VSQLSEL := VSQLSEL || 'B.YOGOGAKO_CD IN ('|| VYOGOGAKO ||') ';
            IF VKUNISHIRITSU IS NOT NULL THEN
              VSQLSEL := VSQLSEL || 'B.YOGOGAKO_CD IN ('|| VYOGOGAKO ||') OR ';
            ELSE
              VSQLSEL := VSQLSEL || 'B.YOGOGAKO_CD IN ('|| VYOGOGAKO ||')';
            END IF;
          END IF;
          IF VKUNISHIRITSU IS NOT NULL THEN
              VSQLSEL := VSQLSEL || 'B.KUNISHIRITSU_CD IN ('|| VKUNISHIRITSU ||') ';
-- 2024/07/15 ZCZL.qinyue Update end
          END IF;
          VSQLSEL := VSQLSEL || ' )';
        END IF;
        OPEN CJIDO FOR VSQLSEL;
        LOOP
          FETCH CJIDO INTO CRATENA_WORK;
          EXIT WHEN CJIDO%NOTFOUND;
          VCNT :=  TO_CHAR(ICNT);
-- 2024/07/15 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
          --文書番号編集結果の取得
          IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 AND (g_rBUNNUMSRCINF.NUMINCTYPE = 1 OR g_rBUNNUMSRCINF.NUMINCTYPE = 2) THEN
            KKAPK0040.SBunNumIc(g_rBUNNUMSRCINF, g_rBUNNUMEDITKEKA);
            --変数.文書番号に取得した文書番号編集結果を設定。
            g_rBUNNUM := g_rBUNNUMEDITKEKA.NUM;
            --変数.文書番号_区域外満了を文書番号情報（構造体）.MAEMOJIと文書番号情報（構造体）.USHIROMOJIの値で切り抜いた値
            sBUNSHONOTMP := REPLACE(REPLACE(g_rBUNNUM,g_rBUNNUMSRCINF.MAEMOJI,''),g_rBUNNUMSRCINF.USHIROMOJI,'');
          END IF;
          --文書番号保管を追加する
          g_rHOKANBUNNUM(ICNT+1).nKOJINNUM := CRATENA_WORK.KOJIN_NO;
          g_rHOKANBUNNUM(ICNT+1).sBUNNUM := g_rBUNNUM;
          -- 発行履歴作成処理
          IF g_TXTHAKKORIREKI = 0 THEN
             nRTN := GKAFKHAKKOR('GKB',                                        --業務コード
                                        CRATENA_WORK.KOJIN_NO,                 --宛名番号
                                        g_rJSTP.CHOHYONUM,                            --帳票コード
                                        SUBSTR(TO_CHAR(SYSDATE,'YYYYMMDD'),1,4),     --年度
                                        1,                                           --処理区分
                                        g_rJSTP.CHOHYONAME,                          --通知書種別
                                        TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),      --発行日
                                        TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'HH24MISS')), --発行時間
                                        1,                                           --発行枚数
                                        g_sTANTOCODE,                                --発行職員宛名番号
                                        KKAPK0020.FNENDOHENKAN(g_vJYOUKEN7),         --送付日
                                        NULL,                                        --通知場所
                                        g_rBUNNUMSRCINF.MAEMOJI,                     --文書番号接頭語
                                        sBUNSHONOTMP,                                --文書番号
                                        g_rBUNNUMSRCINF.USHIROMOJI,                  --文書番号接尾語
--  2026/01/05 CTC.HJF UPDATE START 1.0.451.000:GKB_QA25074対応
                                        --CRATENA_WORK.KOJIN_NO,              --通知対象者宛名番号
                                        CRATENA_WORK.HOGOSYA_KOJIN_NO,               --通知対象者宛名番号
--  2026/01/05 CTC.HJF UPDATE END
                                        NULL,                                        --転出先自治体コード
                                        g_sWSNUM                                     --更新端末番号
                                        );
            IF nRTN = 1 THEN
              bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME, 1, '', '', '[健康診断結果通知書]共通関数(帳票発行履歴作成)(GKAFKHAKKOR)でエラーが発生しました。　宛名番号　' || CRATENA_WORK.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, 1);
              CONTINUE;
            END IF;
          END IF;
-- 2024/07/16 ZCZL.qinyue Add end
          -- 児童の学齢簿情報取得
-- 2024/07/03 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--           GKBSKJDOG2(CRATENA_WORK.KOJIN_NO,CRATENA_WORK.RIREKI_RENBAN,RGAKUREIBO,NPRTN);
          GKBSKJDOG2(CRATENA_WORK.KOJIN_NO,CRATENA_WORK.RIREKI_RENBAN,CRATENA_WORK.RIREKI_RENBAN_EDA,RGAKUREIBO,NPRTN);
          IF NPRTN = 0 THEN
            IF RGAKUREIBO.TYUGAKO_CD = 0 THEN
              BEGIN
                SELECT SYOGAKO_CD,
                       SYOGAKOMEI
                  INTO IGAKO_CD,
                       VGAKOMEI
                  FROM GKBTSHOGAKKO
                 WHERE SYOGAKO_CD = RGAKUREIBO.SYOGAKO_CD;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  DBMS_OUTPUT.PUT_LINE('該当小学校なし '||RGAKUREIBO.SYOGAKO_CD||' '||CRATENA_WORK.KOJIN_NO);
                  IGAKO_CD := RGAKUREIBO.SYOGAKO_CD;
                  VGAKOMEI := ' ';
              END;
              VGAKUNENSEI := TO_CHAR(NGAKUNEN_CD);
              VGAKUNENMEI := VGAKUNENSEI || '年生';
            ELSE
              BEGIN
                SELECT TYUGAKO_CD,
                       TYUGAKOMEI
                  INTO IGAKO_CD,
                       VGAKOMEI
                  FROM GKBTCHUGAKKO
                 WHERE TYUGAKO_CD = RGAKUREIBO.TYUGAKO_CD;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  DBMS_OUTPUT.PUT_LINE('該当中学校なし '||RGAKUREIBO.TYUGAKO_CD||' '||CRATENA_WORK.KOJIN_NO);
                  IGAKO_CD := RGAKUREIBO.TYUGAKO_CD;
                  VGAKOMEI := ' ';
              END;
              NGAKUNENSEI := NGAKUNEN_CD - 6;
              VGAKUNENSEI := TO_CHAR(NGAKUNENSEI);
              VGAKUNENMEI := VGAKUNENSEI || '年生';
            END IF;
            -- 児童の宛名情報取得
            IRTNA := GAAPK0030.FGETATENA(CRATENA_WORK.KOJIN_NO,
                                       'GKB',
                                       ISAKUSEIBI,
                                       RJIDO_ATENA,
                                       RJIDO_SOFU);
--2024/07/03 ZCZL.qinyue Delete 0.3.000.000:新WizLIFE2次開発
--            IRTN  := FUNC_PRMFLGSET(RJIDO_ATENA.KOJIN_NO,N_NAIYO_CD);
            -- 児童生年月日編集
            IWAREKIHIZUKE := 0;
            BRTNSEINENGAPI := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,
                                            RJIDO_ATENA.SEINENGAPI,
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
            n_YYYY     := ISEIREKI_YYYY;
            n_MM       := IMM;
            n_DD       := IDD;
            v_GYYMMDD3 := VEDIT_GYYMMDD3;
            -- 児童性別編集
            IF RJIDO_ATENA.SEIBETSU = 1 THEN
              VSEIBETSU := '男';
            ELSIF RJIDO_ATENA.SEIBETSU = 2 THEN
              VSEIBETSU := '女';
            END IF;
            -- 世帯番号
            VSETAI_NO :=  TO_CHAR(RJIDO_ATENA.SETAI_NO);
            -- 行政区名
            VGYOSEIKU_MEI := GAAPK0030.FGYOSEIKUMEI(RJIDO_ATENA.SANTEIDANTAI_CD,RJIDO_ATENA.GYOSEIKU_CD);
            -- 班名
            VHAN_MEI := GAAPK0030.FHANMEI(RJIDO_ATENA.SANTEIDANTAI_CD, RJIDO_ATENA.HAN_CD);
            -- 旧自治体名
            IRTNSANTEIDANTAI := GAAPK0030.FJICHINAME(RJIDO_ATENA.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);
            -- 保護者が設定されていれば保護者情報取得
            IF RGAKUREIBO.HOGOSYA_KOJIN_NO <> 0 THEN
              -- 保護者宛名情報取得
              IRTNAH := GAAPK0030.FGETATENA(RGAKUREIBO.HOGOSYA_KOJIN_NO,
                                          'GKB',
                                          ISAKUSEIBI,
                                          RHOGO_ATENA,
                                          RHOGO_SOFU);
              -- 保護者氏名上段(保護者氏名かな)
              VHOGOSHA_SHIMEI_JODAN := RHOGO_ATENA.SHIMEI_KANA;
              -- 保護者氏名下段(保護者氏名漢字)
              VHOGOSHA_SHIMEI_GEDAN := RHOGO_ATENA.SHIMEI_KANJI;
              IJUSHO_NAGASA := LENGTH(RHOGO_ATENA.CHOMEI||RHOGO_ATENA.BANCHI||' '||RHOGO_ATENA.KATAGAKI);
              IF IJUSHO_NAGASA > 20 THEN
                VJUSHO_JODAN := SUBSTR (RHOGO_ATENA.CHOMEI||RHOGO_ATENA.BANCHI||' '||RHOGO_ATENA.KATAGAKI,1,20);
                VJUSHO_GEDAN := SUBSTR (RHOGO_ATENA.CHOMEI||RHOGO_ATENA.BANCHI||' '||RHOGO_ATENA.KATAGAKI,21,20);
              ELSE
                VJUSHO_JODAN := SUBSTR (RHOGO_ATENA.CHOMEI||RHOGO_ATENA.BANCHI||' '||RHOGO_ATENA.KATAGAKI,1,20);
                VJUSHO_GEDAN := ' ';
              END IF;
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
--               MJIDO_WORK(ICNT).CHOMEI   := RHOGO_ATENA.CHOMEI;
--               MJIDO_WORK(ICNT).BANCHI   := RHOGO_ATENA.BANCHI;
--               MJIDO_WORK(ICNT).KATAGAKI := RHOGO_ATENA.KATAGAKI;
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00074対応
--               IF g_OPTSHINENSOCHI = 0 THEN
              IF g_OPTSHINENSOCHI = 1 THEN
                sJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, RHOGO_ATENA.CHOMEI, RHOGO_ATENA.BANCHI, RHOGO_ATENA.KATAGAKI, NULL);
                sJUSHO := GAAPK0030.FDVJUSHO('GKB', RHOGO_ATENA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sJUSHO, g_CTLPRM, 2, NULL, NULL);
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00074対応
--                 IF g_OPTSHINENSOCHI = 0 AND g_CTLPRM = 1 THEN
                IF g_OPTSHINENSOCHI = 1 AND g_CTLPRM = 1 THEN
                  MJIDO_WORK(ICNT).CHOMEI   := sJUSHO;
                  --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
                  --MJIDO_WORK(ICNT).BANCHI   := sJUSHO;
                  --MJIDO_WORK(ICNT).KATAGAKI := sJUSHO;
                  MJIDO_WORK(ICNT).BANCHI   := NULL;
                  MJIDO_WORK(ICNT).KATAGAKI := NULL;
                  --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
                  VJUSHO_JODAN := sJUSHO;
                  VJUSHO_GEDAN := sJUSHO;
                ELSE
                  MJIDO_WORK(ICNT).CHOMEI   := RHOGO_ATENA.CHOMEI;
                  MJIDO_WORK(ICNT).BANCHI   := RHOGO_ATENA.BANCHI;
                  MJIDO_WORK(ICNT).KATAGAKI := RHOGO_ATENA.KATAGAKI;
                END IF;
              ELSE
                MJIDO_WORK(ICNT).CHOMEI   := RHOGO_ATENA.CHOMEI;
                MJIDO_WORK(ICNT).BANCHI   := RHOGO_ATENA.BANCHI;
                MJIDO_WORK(ICNT).KATAGAKI := RHOGO_ATENA.KATAGAKI;
              END IF;
-- 2024/07/03 ZCZL.qinyue end
              IF LENGTH(RHOGO_ATENA.YUBIN_NO) > 0 AND
                 RGAKUREIBO.HOGOSYA_KOJIN_NO <> 0 THEN
                MJIDO_WORK(ICNT).YUBIN_NO   := RHOGO_ATENA.YUBIN_NO;
                MJIDO_WORK(ICNT).YUBIN_NOBC := RHOGO_ATENA.YUBIN_NOBC;
              ELSE
                MJIDO_WORK(ICNT).YUBIN_NO   := NULL;
                MJIDO_WORK(ICNT).YUBIN_NOBC := NULL;
              END IF;
              IF RHOGO_SOFU.KOJIN_NO IS NOT NULL AND
                 (RHOGO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND
                 (RHOGO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RHOGO_SOFU.SHURYO_BI = 0) THEN
                IJUSHO_NAGASA := LENGTH(RHOGO_SOFU.CHOMEI||RHOGO_SOFU.BANCHI||' '||RHOGO_SOFU.KATAGAKI);
                IF IJUSHO_NAGASA > 20 THEN
                  VJUSHO_JODAN := SUBSTR (RHOGO_SOFU.CHOMEI||RHOGO_SOFU.BANCHI||' '||RHOGO_SOFU.KATAGAKI,1,20);
                  VJUSHO_GEDAN := SUBSTR (RHOGO_SOFU.CHOMEI||RHOGO_SOFU.BANCHI||' '||RHOGO_SOFU.KATAGAKI,21,20);
                ELSE
                  VJUSHO_JODAN := SUBSTR (RHOGO_SOFU.CHOMEI||RHOGO_SOFU.BANCHI||' '||RHOGO_SOFU.KATAGAKI,1,20);
                  VJUSHO_GEDAN := ' ';
                END IF;
                MJIDO_WORK(ICNT).SOFU_YUBIN_NO   := RHOGO_SOFU.YUBIN_NO;
                MJIDO_WORK(ICNT).SOFU_YUBIN_NOBC := RHOGO_SOFU.YUBIN_NOBC;
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
--                 MJIDO_WORK(ICNT).SOFU_CHOMEI   := RHOGO_SOFU.CHOMEI;
--                 MJIDO_WORK(ICNT).SOFU_BANCHI   := RHOGO_SOFU.BANCHI;
--                 MJIDO_WORK(ICNT).SOFU_KATAGAKI := RHOGO_SOFU.KATAGAKI;
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00074対応
--                 IF g_OPTSHINENSOCHI = 0 THEN
                IF g_OPTSHINENSOCHI = 1 THEN
                  sJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, RHOGO_SOFU.CHOMEI, RHOGO_SOFU.BANCHI, RHOGO_SOFU.KATAGAKI, NULL);
                  sJUSHO := GAAPK0030.FDVJUSHO('GKB', RHOGO_ATENA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sJUSHO, g_CTLPRM, 2, NULL, NULL);
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00074対応
--                   IF g_OPTSHINENSOCHI = 0 AND g_CTLPRM = 1 THEN
                  IF g_OPTSHINENSOCHI = 1 AND g_CTLPRM = 1 THEN
                    MJIDO_WORK(ICNT).SOFU_CHOMEI   := sJUSHO;
                    --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
                    --MJIDO_WORK(ICNT).SOFU_BANCHI   := sJUSHO;
                    --MJIDO_WORK(ICNT).SOFU_KATAGAKI := sJUSHO;
                    MJIDO_WORK(ICNT).SOFU_BANCHI   := NULL;
                    MJIDO_WORK(ICNT).SOFU_KATAGAKI := NULL;
                    --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
                    VJUSHO_JODAN                   := sJUSHO;
                    VJUSHO_GEDAN                   := sJUSHO;
                  ELSE
                    MJIDO_WORK(ICNT).SOFU_CHOMEI   := RHOGO_SOFU.CHOMEI;
                    MJIDO_WORK(ICNT).SOFU_BANCHI   := RHOGO_SOFU.BANCHI;
                    MJIDO_WORK(ICNT).SOFU_KATAGAKI := RHOGO_SOFU.KATAGAKI;
                  END IF;
                ELSE
                  MJIDO_WORK(ICNT).SOFU_CHOMEI   := RHOGO_SOFU.CHOMEI;
                  MJIDO_WORK(ICNT).SOFU_BANCHI   := RHOGO_SOFU.BANCHI;
                  MJIDO_WORK(ICNT).SOFU_KATAGAKI := RHOGO_SOFU.KATAGAKI;
                END IF;
-- 2024/07/03 ZCZL.qinyue Update end
              ELSE
                MJIDO_WORK(ICNT).SOFU_YUBIN_NO   := RHOGO_ATENA.YUBIN_NO;
                MJIDO_WORK(ICNT).SOFU_YUBIN_NOBC := RHOGO_ATENA.YUBIN_NOBC;
                MJIDO_WORK(ICNT).SOFU_CHOMEI   := RHOGO_ATENA.CHOMEI;
                MJIDO_WORK(ICNT).SOFU_BANCHI   := RHOGO_ATENA.BANCHI;
                MJIDO_WORK(ICNT).SOFU_KATAGAKI := RHOGO_ATENA.KATAGAKI;
              END IF;
              -- 児童続柄
              IRTNZOKUGARA1 := GKBFKZKGMGET(1,
                                            RGAKUREIBO.ZOKUGARA1,
                                            RGAKUREIBO.ZOKUGARA2,
                                            RGAKUREIBO.ZOKUGARA3,
                                            RGAKUREIBO.ZOKUGARA4,
                                            VZOKUGARAMEI1,
                                            IRTNZOKUGARAHERR1);
              -- 保護者続柄
              IRTNZOKUGARA2 := GKBFKZKGMGET(2,
                                            RGAKUREIBO.HOGOSYA_ZOKUGARA1,
                                            RGAKUREIBO.HOGOSYA_ZOKUGARA2,
                                            RGAKUREIBO.HOGOSYA_ZOKUGARA3,
                                            RGAKUREIBO.HOGOSYA_ZOKUGARA4,
                                            VZOKUGARAMEI2,
                                            IRTNZOKUGARAHERR2);
-- 2024/07/03 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RHOGO_ATENA.SHIMEI_KANA;
--              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
              --保護者の本名使用制御判定
--  2025/11/17 CTC.GL UPDATE START 1.0.301.000:GKB_QA22992対応
--              nRTN := GKBFKHMCTRL(RGAKUREIBO.KOJIN_NO,
--                              g_rJSTP.CHOHYOID,
--                              1,
--                              g_nTCL,
--                              sSHIMEIKANA2,
--                              sSHIMEI2,
--                              sBIRTHDAY2);
              nRTN := GKBFKHMCTRL(RGAKUREIBO.KOJIN_NO,
                              g_rJSTP.CHOHYOID,
                              1,
                              g_nTCL,
                              sSHIMEIKANA2,
                              sSHIMEI2,
                              sBIRTHDAY2,
                              RGAKUREIBO.RIREKI_RENBAN);
--  2025/11/17 CTC.GL UPDATE END
              -- 保護者氏名かな
              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := sSHIMEIKANA2;
              -- 保護者氏名漢字
              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := sSHIMEI2;
-- 2024/07/03 ZCZL.qinyue Update end
              IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
                -- 保護者氏名上段(保護者氏名かな)
                VHOGOSHA_SHIMEI_JODAN := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;
                -- 保護者氏名下段(保護者氏名漢字)
                VHOGOSHA_SHIMEI_GEDAN := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;
              END IF;
            ELSE
              RHOGO_ATENA := RHOGO_ATENA_NULL;
              RHOGO_SOFU  := RHOGO_SOFU_NULL;
              --保護者個人番号が０のときはNULL
              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := NULL;
              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := NULL;
              MJIDO_WORK(ICNT).CHOMEI := NULL;
              MJIDO_WORK(ICNT).BANCHI := NULL;
              MJIDO_WORK(ICNT).KATAGAKI := NULL;
              VZOKUGARAMEI1 := NULL;
              VZOKUGARAMEI2 := NULL;
              VHOGOSHA_SHIMEI_JODAN := NULL;
              VHOGOSHA_SHIMEI_GEDAN := NULL;
              VJUSHO_JODAN := NULL;
              VJUSHO_GEDAN := NULL;
              MJIDO_WORK(ICNT).YUBIN_NO   := NULL;
              MJIDO_WORK(ICNT).YUBIN_NOBC := NULL;
              MJIDO_WORK(ICNT).SOFU_CHOMEI := NULL;
              MJIDO_WORK(ICNT).SOFU_BANCHI := NULL;
              MJIDO_WORK(ICNT).SOFU_KATAGAKI := NULL;
              MJIDO_WORK(ICNT).SOFU_YUBIN_NO   := NULL;
              MJIDO_WORK(ICNT).SOFU_YUBIN_NOBC := NULL;
              DBMS_OUTPUT.PUT_LINE('該当保護者なし '||RGAKUREIBO.HOGOSYA_KOJIN_NO||' '||CRATENA_WORK.KOJIN_NO);
            END IF;
            BEGIN
              SELECT NVL(KYOIKUIINKAI_CD,0)
                INTO NSYOGAKOKYOIKUIINKAI_CD
                FROM GKBTSHOGAKKO
               WHERE SYOGAKO_CD = RGAKUREIBO.SYOGAKO_CD;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                 NSYOGAKOKYOIKUIINKAI_CD := 0;
            END;
            BEGIN
              SELECT NVL(KYOIKUIINKAI_CD,0)
                INTO NKUIKIGAIKYOIKUIINKAI_CD
                FROM GKBTKUIKIGAI
               WHERE KUIKIGAI_CD = RGAKUREIBO.KUIKIGAI_CD;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                 NKUIKIGAIKYOIKUIINKAI_CD := 0;
            END;
            BEGIN
              SELECT NVL(KYOIKUIINKAI_CD,0)
                INTO NYOGOGAKOKYOIKUIINKAI_CD
                FROM GKBTYOGOGAKKO
               WHERE YOGOGAKO_CD = RGAKUREIBO.YOGOGAKO_CD;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  NYOGOGAKOKYOIKUIINKAI_CD := 0;
            END;
            NNENDO := TO_NUMBER(VNENDO);          -- 年度
            VHYOUJINENDO := KKAPK0020.FNENDOEDIT(1, NNENDO, 3);
            IWAREKIHIZUKE := 0;
            BRTNSASKUSEIBI := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,
                                                  ISAKUSEIBI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VHASSOBI,
                                                  VKJ_GENGO,
                                                  VKG_GENGO,
                                                  IWAREKI_YY,
                                                  ISEIREKI_YYYY,
                                                  IWAREKI_GYYMM,
                                                  IMM,
                                                  IDD,
                                                  IOWAREKIHIZUKE,
                                                  ISEIREKIHIZUKE);
            --処理日
            IWAREKIHIZUKE := 0;
            BRTNSASKUSEIBI := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,
                                                  ISAKUSEIBI2,
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
            -- 通知書条件取得
            IF RGAKUREIBO.SYOGAKO_CD <> 0 THEN
              BEGIN
                SELECT NVL(DATE1,0), NVL(DATE2,0), NVL(DATE3,0), NVL(DATE4,0), NVL(DATE5,0),
                       NVL(KOMOKU1,' '), NVL(KOMOKU2,' '), NVL(KOMOKU3,' '), NVL(KOMOKU4,' '), NVL(KOMOKU5,' '),
                       NVL(KOMOKU6,' '), NVL(KOMOKU7,' '), NVL(KOMOKU8,' '), NVL(KOMOKU9,' '), NVL(KOMOKU10,' ')
                  INTO IDATE1, IDATE2, IDATE3, IDATE4, IDATE5,
                       VKOMOKU1, VKOMOKU2, VKOMOKU3, VKOMOKU4, VKOMOKU5,
                       VKOMOKU6, VKOMOKU7, VKOMOKU8, VKOMOKU9, VKOMOKU10
                  FROM GKBTTSUCHISHOJKN
                 WHERE CHOHYO_KBN = c_CHOHYO_KBN
                   AND GAKO_CD = RGAKUREIBO.SYOGAKO_CD;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  IDATE1 := 0;
                  IDATE2 := 0;
                  IDATE3 := 0;
                  IDATE4 := 0;
                  IDATE5 := 0;
                  VKOMOKU1 := ' ';
                  VKOMOKU2 := ' ';
                  VKOMOKU3 := ' ';
                  VKOMOKU4 := ' ';
                  VKOMOKU5 := ' ';
                  VKOMOKU6 := ' ';
                  VKOMOKU7 := ' ';
                  VKOMOKU8 := ' ';
                  VKOMOKU9 := ' ';
                  VKOMOKU10 := ' ';
              END;
            ELSE
              IDATE1 := 0;
              IDATE2 := 0;
              IDATE3 := 0;
              IDATE4 := 0;
              IDATE5 := 0;
              VKOMOKU1 := ' ';
              VKOMOKU2 := ' ';
              VKOMOKU3 := ' ';
              VKOMOKU4 := ' ';
              VKOMOKU5 := ' ';
              VKOMOKU6 := ' ';
              VKOMOKU7 := ' ';
              VKOMOKU8 := ' ';
              VKOMOKU9 := ' ';
              VKOMOKU10 := ' ';
            END IF;
            -- 通知書管理情報取得
            BEGIN
              SELECT NVL(DATE_MEI1,' '), NVL(DATE_MEI2,' '), NVL(DATE_MEI3,' '), NVL(DATE_MEI4,' '), NVL(DATE_MEI5,' '),
                     NVL(KOMOKU_MEI1,' '), NVL(KOMOKU_MEI2,' '), NVL(KOMOKU_MEI3,' '), NVL(KOMOKU_MEI4,' '), NVL(KOMOKU_MEI5,' '),
                     NVL(KOMOKU_MEI6,' '), NVL(KOMOKU_MEI7,' '), NVL(KOMOKU_MEI8,' '), NVL(KOMOKU_MEI9,' '), NVL(KOMOKU_MEI10,' ')
                INTO VDATE_MEI1, VDATE_MEI2, VDATE_MEI3, VDATE_MEI4, VDATE_MEI5,
                     VKOMOKU_MEI1, VKOMOKU_MEI2, VKOMOKU_MEI3, VKOMOKU_MEI4, VKOMOKU_MEI5,
                     VKOMOKU_MEI6, VKOMOKU_MEI7, VKOMOKU_MEI8, VKOMOKU_MEI9, VKOMOKU_MEI10
                FROM GKBTTSUCHISHOKANRI
                  WHERE CHOHYO_KBN = c_CHOHYO_KBN;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                VDATE_MEI1 :=' ';
                VDATE_MEI2 :=' ';
                VDATE_MEI3 :=' ';
                VDATE_MEI4 :=' ';
                VDATE_MEI5 :=' ';
                VKOMOKU_MEI1 :=' ';
                VKOMOKU_MEI2 :=' ';
                VKOMOKU_MEI3 :=' ';
                VKOMOKU_MEI4 :=' ';
                VKOMOKU_MEI5 :=' ';
                VKOMOKU_MEI6 :=' ';
                VKOMOKU_MEI7 :=' ';
                VKOMOKU_MEI8 :=' ';
                VKOMOKU_MEI9 :=' ';
                VKOMOKU_MEI10 :=' ';
            END;
            IF IDATE1 <> 0 THEN
              IWAREKI := 0;
              BRTN := KKAPK0020.FDAYEDIT(IWAREKI,
                                          IDATE1,
                                          VEDIT_GYYMMDD3,
                                          VEDIT_GYYMMDD2,
                                          VDATE1,
                                          VKJ_GENGO,
                                          VKG_GENGO,
                                          IWAREKI_YY,
                                          ISEIREKI_YYYY,
                                          IWAREKI_GYYMM,
                                          IMM,
                                          IDD,
                                          IOWAREKIHIZUKE,
                                          ISEIREKIHIZUKE);
            ELSE
              VDATE1 := ' ';
            END IF;
            IF IDATE2 <> 0 THEN
              IWAREKI := 0;
              BRTN := KKAPK0020.FDAYEDIT(IWAREKI,
                                          IDATE2,
                                          VEDIT_GYYMMDD3,
                                          VEDIT_GYYMMDD2,
                                          VDATE2,
                                          VKJ_GENGO,
                                          VKG_GENGO,
                                          IWAREKI_YY,
                                          ISEIREKI_YYYY,
                                          IWAREKI_GYYMM,
                                          IMM,
                                          IDD,
                                          IOWAREKIHIZUKE,
                                          ISEIREKIHIZUKE);
            ELSE
              VDATE2 := ' ';
            END IF;
            IF IDATE3 <> 0 THEN
              IWAREKI := 0;
              BRTN := KKAPK0020.FDAYEDIT(IWAREKI,
                                          IDATE3,
                                          VEDIT_GYYMMDD3,
                                          VEDIT_GYYMMDD2,
                                          VDATE3,
                                          VKJ_GENGO,
                                          VKG_GENGO,
                                          IWAREKI_YY,
                                          ISEIREKI_YYYY,
                                          IWAREKI_GYYMM,
                                          IMM,
                                          IDD,
                                          IOWAREKIHIZUKE,
                                          ISEIREKIHIZUKE);
            ELSE
              VDATE3 := ' ';
            END IF;
            IF IDATE4 <> 0 THEN
              IWAREKI := 0;
              BRTN := KKAPK0020.FDAYEDIT(IWAREKI,
                                          IDATE4,
                                          VEDIT_GYYMMDD3,
                                          VEDIT_GYYMMDD2,
                                          VDATE4,
                                          VKJ_GENGO,
                                          VKG_GENGO,
                                          IWAREKI_YY,
                                          ISEIREKI_YYYY,
                                          IWAREKI_GYYMM,
                                          IMM,
                                          IDD,
                                          IOWAREKIHIZUKE,
                                          ISEIREKIHIZUKE);
            ELSE
              VDATE4 := ' ';
            END IF;
            IF IDATE5 <> 0 THEN
              IWAREKI := 0;
              BRTN := KKAPK0020.FDAYEDIT(IWAREKI,
                                          IDATE5,
                                          VEDIT_GYYMMDD3,
                                          VEDIT_GYYMMDD2,
                                          VDATE5,
                                          VKJ_GENGO,
                                          VKG_GENGO,
                                          IWAREKI_YY,
                                          ISEIREKI_YYYY,
                                          IWAREKI_GYYMM,
                                          IMM,
                                          IDD,
                                          IOWAREKIHIZUKE,
                                          ISEIREKIHIZUKE);
            ELSE
              VDATE5 := ' ';
            END IF;
            -- 年齢取得
            INENREI_KIJUNBI := (KKAPK0020.FNENDO(KKAPK0020.FDAYNENDO(0,g_vJYOUKEN6),1) + 1) * 10000 + 101;
            IF RJIDO_ATENA.SEINENGAPI = 0 THEN
              INENREI := NULL;
            ELSE
              INENREI := KKAPK0020.FAgeGet(TO_CHAR(RJIDO_ATENA.SEINENGAPI), TO_CHAR(INENREI_KIJUNBI));
            END IF;

            VNENREI :=  TO_CHAR(INENREI);
            MJIDO_WORK(ICNT).JIDO_KOJIN_NO := RGAKUREIBO.KOJIN_NO;
-- 2024/07/05 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--             MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := RJIDO_ATENA.SHIMEI_KANA;
--             MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
--             IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
--              -- 児童氏名かな
--               I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANA,RJIDO_ATENA.SHIMEI_KANA,MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
--              -- 児童氏名漢字
--               I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANJI,RJIDO_ATENA.SHIMEI_KANJI,MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
--             END IF;
            --児童生徒の本名使用制御判定
            nRTN := GKBFKHMCTRL(RGAKUREIBO.KOJIN_NO,
                              g_rJSTP.CHOHYOID,
                              0,
                              g_nTCL,
                              sSHIMEIKANA,
                              sSHIMEI,
                              sBIRTHDAY);
            MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := sSHIMEIKANA; -- 児童氏名かな
            MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := sSHIMEI; -- 児童氏名漢字
-- 2024/07/05 ZCZL.qinyue Update end
            MJIDO_WORK(ICNT).SEINENGAPI := RJIDO_ATENA.SEINENGAPI;
-- 2024/07/05 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--             MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VSEINENGAPI;
--             MJIDO_WORK(ICNT).KANJI_SEINENGAPI := RJIDO_ATENA.HYOJI_SEINENGAPI;
--             IF RJIDO_ATENA.JINKAKU_KBN != 0 THEN
--                 I_RTN := GKBPK00010.FYMDEDT1(RJIDO_ATENA.SEINENGAPI,
--                          MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,MJIDO_WORK(ICNT).KANJI_SEINENGAPI);
--               IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
--                 IF BPRMFLG_004 THEN
--                 GKBPK00010.FYMDEDT1より取得した表示生年月日
--                   I_RTN := GKBPK00010.FYMDEDT1(RJIDO_ATENA.SEINENGAPI,MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,o_YMD2);
--                   MJIDO_WORK(ICNT).KANJI_SEINENGAPI := n_YYYY||'年'||LPAD(n_MM,2)||'月'||LPAD(n_DD,2)||'日';
--                 ELSIF BPRMFLG_003 THEN
--                  和暦で表示生年月日
--                   IF N_NAIYO_CD IN(11,21) THEN
--                     MJIDO_WORK(ICNT).HYOJI_SEINENGAPI    := VSEINENGAPI;
--                     MJIDO_WORK(ICNT).KANJI_SEINENGAPI    := RJIDO_ATENA.HYOJI_SEINENGAPI;
--                  西暦で表示生年月日
--                   ELSIF N_NAIYO_CD IN(12,22) THEN
--                     MJIDO_WORK(ICNT).HYOJI_SEINENGAPI    := n_YYYY||'.'||LPAD(n_MM,2)||'.'||LPAD(n_DD,2);
--                     MJIDO_WORK(ICNT).KANJI_SEINENGAPI    := n_YYYY||'年'||LPAD(n_MM,2)||'月'||LPAD(n_DD,2)||'日';
--                   END IF;
--                 ELSE
--                  「平成○年○月○日」の形式で表示
--                   MJIDO_WORK(ICNT).HYOJI_SEINENGAPI    := VSEINENGAPI;
--                   MJIDO_WORK(ICNT).KANJI_SEINENGAPI    := v_GYYMMDD3;
--                 END IF;
--               END IF;
--             END IF;
            MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := sBIRTHDAY; -- 表示用生年月日
            MJIDO_WORK(ICNT).KANJI_SEINENGAPI := sBIRTHDAY; -- 漢字生年月日
-- 2024/07/05 ZCZL.qinyue Update end
            MJIDO_WORK(ICNT).SEIBETSU := RJIDO_ATENA.SEIBETSU;
            MJIDO_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;
            MJIDO_WORK(ICNT).ZOKUGARAMEI1 := VZOKUGARAMEI1;
            MJIDO_WORK(ICNT).SETAI_NO := RJIDO_ATENA.SETAI_NO;
            MJIDO_WORK(ICNT).HYOJI_SETAI_NO := VSETAI_NO;
            MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO := RGAKUREIBO.HOGOSYA_KOJIN_NO;
            MJIDO_WORK(ICNT).ZOKUGARAMEI2 := VZOKUGARAMEI2;
            MJIDO_WORK(ICNT).GAKUNEN_CD := CRATENA_WORK.GAKUNEN;
            MJIDO_WORK(ICNT).GAKUNENMEI := CRATENA_WORK.GAKUNEN||'年生';
            IF CRATENA_WORK.SYOGAKO_CD <> 0 AND
               CRATENA_WORK.SYOGAKO_TENGAKU_BI = 0 AND
               CRATENA_WORK.SYOGAKO_SOTSUGYO_BI = 0 THEN
               MJIDO_WORK(ICNT).GAKOKU_CD := CRATENA_WORK.SYOGAKO_CD;
               VSQL_GAKO := 'SELECT SYOGAKOMEI FROM GKBTSHOGAKKO WHERE SYOGAKO_CD = '''||MJIDO_WORK(ICNT).GAKOKU_CD||'''';
               MJIDO_WORK(ICNT).GAKO_KBN := 1;
               NKYOIKUIINKAI_CD := NSYOGAKOKYOIKUIINKAI_CD;
            ELSE
                IF CRATENA_WORK.KUIKIGAI_CD <> 0 AND
                   CRATENA_WORK.KUIKIGAI_TENGAKU_BI = 0 AND
                   CRATENA_WORK.KUIKIGAI_TAIGAKU_BI = 0 AND
                   CRATENA_WORK.KUIKIGAI_SOTSUGYO_BI = 0 THEN
                   MJIDO_WORK(ICNT).GAKOKU_CD := CRATENA_WORK.KUIKIGAI_CD;
                   VSQL_GAKO := 'SELECT KUIKIGAIMEI FROM GKBTKUIKIGAI WHERE KUIKIGAI_CD = '''||MJIDO_WORK(ICNT).GAKOKU_CD||'''';
                   MJIDO_WORK(ICNT).GAKO_KBN := 2;
                   NKYOIKUIINKAI_CD := NKUIKIGAIKYOIKUIINKAI_CD;
                ELSE
                    IF CRATENA_WORK.YOGOGAKO_CD <> 0 AND
                       CRATENA_WORK.YOGOGAKO_TENGAKU_BI = 0 AND
                       CRATENA_WORK.YOGOGAKO_TAIGAKU_BI = 0 AND
                       CRATENA_WORK.YOGOGAKO_SOTSUGYO_BI = 0 THEN
                       MJIDO_WORK(ICNT).GAKOKU_CD := CRATENA_WORK.YOGOGAKO_CD;
                       VSQL_GAKO := 'SELECT YOGOGAKOMEI FROM GKBTYOGOGAKKO WHERE YOGOGAKO_CD = '''||MJIDO_WORK(ICNT).GAKOKU_CD||'''';
                       MJIDO_WORK(ICNT).GAKO_KBN := 3;
                       NKYOIKUIINKAI_CD := NYOGOGAKOKYOIKUIINKAI_CD;
                    ELSE
                        MJIDO_WORK(ICNT).GAKOKU_CD := NULL;
                        MJIDO_WORK(ICNT).GAKOKUMEI := NULL;
                        VSQL_GAKO := '';
                        MJIDO_WORK(ICNT).GAKO_KBN := 0;
                        NKYOIKUIINKAI_CD := NULL;
                    END IF;
                END IF;
            END IF;
            IF LENGTH(VSQL_GAKO) > 0 THEN
               BEGIN
                    EXECUTE IMMEDIATE VSQL_GAKO INTO MJIDO_WORK(ICNT).GAKOKUMEI;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                             MJIDO_WORK(ICNT).GAKOKUMEI := NULL;
               END;
            END IF;
--2024/07/03 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
/*
            IF o_ATENAPRM(1) IN (1,3) THEN
               IF (RJIDO_SOFU.KOJIN_NO IS NOT NULL) AND
                  (RJIDO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND
                  (RJIDO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RJIDO_SOFU.SHURYO_BI = 0) THEN
                  IF RJIDO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
                     NSHIMEI_KANJI := RJIDO_SOFU.SHIMEI_KANJI;
                  ELSE
                     NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
                     IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
                       I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANJI,RJIDO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
                     END IF;
                  END IF;
               ELSE
                  NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
                  IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
                    I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANJI,RJIDO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
                  END IF;
               END IF;
               IF LENGTH(NSHIMEI_KANJI) > 0 THEN
                 IF o_ATENAPRM(3) = 1 THEN
                     MJIDO_WORK(ICNT).ATESAKI_JODAN := '（' || NSHIMEI_KANJI||' 様）';
                 ELSE
                     MJIDO_WORK(ICNT).ATESAKI_JODAN := NSHIMEI_KANJI||' 様';
                 END IF;
               ELSE
                 MJIDO_WORK(ICNT).ATESAKI_JODAN := NULL;
               END IF;
            ELSE
               IF (RHOGO_SOFU.KOJIN_NO IS NOT NULL) AND
                  (RHOGO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND
                  (RHOGO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RHOGO_SOFU.SHURYO_BI = 0) THEN
                  IF RHOGO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
                     NSHIMEI_KANJI := RHOGO_SOFU.SHIMEI_KANJI;
                  ELSE
                     NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
                     IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
                       I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANJI,RHOGO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
                     END IF;
                  END IF;
               ELSE
                  NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
                  IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
                    I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANJI,RHOGO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
                  END IF;
               END IF;
               IF LENGTH(NSHIMEI_KANJI) > 0 THEN
                 IF o_ATENAPRM(2) = 1 THEN
                     MJIDO_WORK(ICNT).ATESAKI_JODAN := '（' || NSHIMEI_KANJI||' 様）';
                 ELSE
                     MJIDO_WORK(ICNT).ATESAKI_JODAN := NSHIMEI_KANJI||' 様';
                 END IF;
               ELSE
                 MJIDO_WORK(ICNT).ATESAKI_JODAN := NULL;
               END IF;
            END IF;
            IF o_ATENAPRM(1) = 2 THEN
               IF (RJIDO_SOFU.KOJIN_NO IS NOT NULL) AND
                  (RJIDO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND
                  (RJIDO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RJIDO_SOFU.SHURYO_BI = 0) THEN
                  IF RJIDO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
                     NSHIMEI_KANJI := RJIDO_SOFU.SHIMEI_KANJI;
                  ELSE
                     NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
                     IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
                       I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANJI,RJIDO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
                     END IF;
                  END IF;
               ELSE
                  NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
                  IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
                    I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANJI,RJIDO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
                  END IF;
               END IF;
               IF LENGTH(NSHIMEI_KANJI) > 0 THEN
                 IF o_ATENAPRM(3) = 1 THEN
                     MJIDO_WORK(ICNT).ATESAKI_GEDAN := '（' || NSHIMEI_KANJI||' 様）';
                 ELSE
                     MJIDO_WORK(ICNT).ATESAKI_GEDAN := NSHIMEI_KANJI||' 様';
                 END IF;
               ELSE
                 MJIDO_WORK(ICNT).ATESAKI_GEDAN := NULL;
               END IF;
            ELSIF o_ATENAPRM(1) = 3 THEN
               IF (RHOGO_SOFU.KOJIN_NO IS NOT NULL) AND
                  (RHOGO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND
                  (RHOGO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RHOGO_SOFU.SHURYO_BI = 0) THEN
                  IF RHOGO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
                     NSHIMEI_KANJI := RHOGO_SOFU.SHIMEI_KANJI;
                  ELSE
                     NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
                     IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
                       I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANJI,RHOGO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
                     END IF;
                  END IF;
               ELSE
                  NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
                  IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
                    I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANJI,RHOGO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
                  END IF;
               END IF;
               IF LENGTH(NSHIMEI_KANJI) > 0 THEN
                 IF o_ATENAPRM(2) = 1 THEN
                     MJIDO_WORK(ICNT).ATESAKI_GEDAN := '（' || NSHIMEI_KANJI||' 様）';
                 ELSE
                     MJIDO_WORK(ICNT).ATESAKI_GEDAN := NSHIMEI_KANJI||' 様';
                 END IF;
               ELSE
                 MJIDO_WORK(ICNT).ATESAKI_GEDAN := NULL;
               END IF;
            ELSE
                MJIDO_WORK(ICNT).ATESAKI_GEDAN := NULL;
            END IF;
*/
            IF o_ATENAPRM(1) IN (1,3) THEN
              --保護者の本名使用制御判定
--  2025/11/17 CTC.GL UPDATE START 1.0.301.000:GKB_QA22992対応
--              nRTN := GKBFKHMCTRL(RGAKUREIBO.KOJIN_NO,
--                                g_rJSTP.CHOHYOID,
--                                0,
--                                g_nTCL,
--                                sSHIMEIKANA,
--                                sSHIMEI,
--                                sBIRTHDAY);
              nRTN := GKBFKHMCTRL(RGAKUREIBO.KOJIN_NO,
                                g_rJSTP.CHOHYOID,
                                0,
                                g_nTCL,
                                sSHIMEIKANA,
                                sSHIMEI,
                                sBIRTHDAY,
                                RGAKUREIBO.RIREKI_RENBAN);
              --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
              --MJIDO_WORK(ICNT).ATESAKI_JODAN := '（' || sSHIMEI||' 様）';
              MJIDO_WORK(ICNT).ATESAKI_JODAN := sSHIMEI||' 様';
              --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
            ELSE
              --保護者の本名使用制御判定
--              nRTN := GKBFKHMCTRL(RGAKUREIBO.KOJIN_NO,
--                                g_rJSTP.CHOHYOID,
--                                1,
--                                g_nTCL,
--                                sSHIMEIKANA,
--                                sSHIMEI,
--                                sBIRTHDAY);
              nRTN := GKBFKHMCTRL(RGAKUREIBO.KOJIN_NO,
                                g_rJSTP.CHOHYOID,
                                1,
                                g_nTCL,
                                sSHIMEIKANA,
                                sSHIMEI,
                                sBIRTHDAY,
                                RGAKUREIBO.RIREKI_RENBAN);
--  2025/11/17 CTC.GL UPDATE END
              --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
              --MJIDO_WORK(ICNT).ATESAKI_JODAN := '（' || sSHIMEI||' 様）';
              MJIDO_WORK(ICNT).ATESAKI_JODAN := sSHIMEI||' 様';
              --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
            END IF;
            MJIDO_WORK(ICNT).ATESAKI_GEDAN := NULL;
--2024/07/03 ZCZL.qinyue Update end
            --教育委員会情報
            o_KYOIKUPRM := A_CONS_PRM();
            IF NKYOIKUIINKAI_CD IS NOT NULL THEN
              IRTN := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',NKYOIKUIINKAI_CD,o_KYOIKUPRM,o_LENGTH);
              IF IRTN = 1 THEN
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
              WHILE (o_LENGTH < 8) LOOP
                o_KYOIKUPRM.EXTEND;
                o_KYOIKUPRM(o_LENGTH+1) := ' ';
                o_LENGTH := o_LENGTH + 1;
              END LOOP;
            END IF;
          ELSE
             o_KYOIKUPRM := A_CONS_PRM();
             o_KYOIKUPRM.EXTEND;
             o_KYOIKUPRM.EXTEND;
             o_KYOIKUPRM(1)     :=  ' ';        -- 教育委員会名
             o_KYOIKUPRM.EXTEND;
             o_KYOIKUPRM(2)     :=  ' ';        -- 役職名
             o_KYOIKUPRM.EXTEND;
             o_KYOIKUPRM(3)     :=  ' ';        -- 首長名
             o_KYOIKUPRM.EXTEND;
             o_KYOIKUPRM(4)     :=  ' ';        -- ○○立
             o_KYOIKUPRM.EXTEND;
             o_KYOIKUPRM(5)     :=  ' ';        -- 郵便番号
             o_KYOIKUPRM.EXTEND;
             o_KYOIKUPRM(6)     :=  ' ';        -- 住所
             o_KYOIKUPRM.EXTEND;
             o_KYOIKUPRM(7)     :=  ' ';        -- 電話番号
             o_KYOIKUPRM.EXTEND;
             o_KYOIKUPRM(8)     :=  ' ';        -- 内線
          END IF;
          --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
            BRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE, 0),
                   g_sWSNUM,
                   TO_DATE(ISAKUSEIBI,'YYYYMMDD'),
                   o_nDAIRIKBN,
                   o_vKATAGAKI1,
                   o_vKATAGAKI2,
                   o_vSHIMEI,
                   o_vKOINFILENAME);
           -- MJIDO_WORK(ICNT).KYOIKUKAI_MEI := o_KYOIKUPRM(1);
            MJIDO_WORK(ICNT).KYOIKUKAI_MEI := o_vKATAGAKI1;
            MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI := o_KYOIKUPRM(2);
           -- MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI := o_KYOIKUPRM(3);
            MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI := o_vSHIMEI;
            --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
            MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI := o_KYOIKUPRM(4);
            MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO := o_KYOIKUPRM(5);
            MJIDO_WORK(ICNT).KYOIKU_JUSHO := o_KYOIKUPRM(6);
            MJIDO_WORK(ICNT).KYOIKU_TEL := o_KYOIKUPRM(7);
            MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN := o_KYOIKUPRM(8);
            MJIDO_WORK(ICNT).CHOHYO_NO := CRATENA_WORK.CHOHYO_NO;
           IWAREKI1 := 0;
           ISEIREKI1 := NKIJUNBI;
           BRTN := KKAPK0020.FDAYEDIT(IWAREKI1,
                                       ISEIREKI1,
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
            NKIJUNBI1   := VEDIT_GYYMMDD3;
            MJIDO_WORK(ICNT).KIJUN_BI := NKIJUNBI1;
            MJIDO_WORK(ICNT).GYOSEIKU_CD := RJIDO_ATENA.GYOSEIKU_CD;
            MJIDO_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;
            NCHOHYO_NO2 := TRIM(CRATENA_WORK.CHOHYO_NO);
            NCHOHYO_NO2 := LPAD(NCHOHYO_NO2,5,' ');
            IF MJIDO_WORK(ICNT).GAKOKU_CD IS NOT NULL THEN
              VGAKOKU_CD2 := TRIM(TO_CHAR(MJIDO_WORK(ICNT).GAKOKU_CD));
              VGAKOKU_CD2 := LPAD(MJIDO_WORK(ICNT).GAKOKU_CD,5,' ');
            ELSE
              VGAKOKU_CD2 := NULL;
            END IF;
            IF o_RENBANPRM(1) = 1 THEN
                MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := NCHOHYO_NO2;
            ELSIF o_RENBANPRM(1) = 2 THEN
                MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := LTRIM(MJIDO_WORK(ICNT).GAKOKUMEI) || '-' || NCHOHYO_NO2;
            ELSIF o_RENBANPRM(1) = 3 THEN
                MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := VGAKOKU_CD2 || '-' || NCHOHYO_NO2;
            ELSIF o_RENBANPRM(1) = 4 THEN
                MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := LTRIM(MJIDO_WORK(ICNT).GAKOKUMEI) || '-' || LTRIM(MJIDO_WORK(ICNT).GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
            ELSIF o_RENBANPRM(1) = 5 THEN
                MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := VGAKOKU_CD2 || '-' || LTRIM(MJIDO_WORK(ICNT).GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
            ELSE
                MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := ' ';
            END IF;
            MJIDO_WORK(ICNT).HAN_CD := RJIDO_ATENA.HAN_CD;
            MJIDO_WORK(ICNT).HANMEI := VHAN_MEI;
            MJIDO_WORK(ICNT).SANTEIDANTAI_CD := RJIDO_ATENA.SANTEIDANTAI_CD;
            MJIDO_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;
            MJIDO_WORK(ICNT).NENDO := VHYOUJINENDO;
            MJIDO_WORK(ICNT).KAIPEJI_CD := ' ';
            MJIDO_WORK(ICNT).KAIPEJI := ' ';
            MJIDO_WORK(ICNT).SAKUSEIBI := VSASKUSEIBI;
            MJIDO_WORK(ICNT).RENBAN := ICNT + 1;
            MJIDO_WORK(ICNT).HYOJI_RENBAN := VCNT;
            MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN := VHOGOSHA_SHIMEI_JODAN;
            MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN := VHOGOSHA_SHIMEI_GEDAN;
            MJIDO_WORK(ICNT).KON_JUSHO_JODAN := VJUSHO_JODAN;
            MJIDO_WORK(ICNT).KON_JUSHO_GEDAN := VJUSHO_GEDAN;
            MJIDO_WORK(ICNT).NENREI := VNENREI;     -- 年齢
-- 2024/07/03 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--             MJIDO_WORK(ICNT).JIDO_CHOMEI := RJIDO_ATENA.CHOMEI;
--             MJIDO_WORK(ICNT).JIDO_BANCHI := RJIDO_ATENA.BANCHI;
--             MJIDO_WORK(ICNT).JIDO_KATAGAKI := RJIDO_ATENA.KATAGAKI;
            sJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, RJIDO_ATENA.CHOMEI, RJIDO_ATENA.BANCHI, RJIDO_ATENA.KATAGAKI, NULL);
            sJUSHO := GAAPK0030.FDVJUSHO('GKB', MJIDO_WORK(ICNT).JIDO_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sJUSHO, g_CTLPRM, 2, NULL, NULL);
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00074対応
--             IF g_OPTSHINENSOCHI = 0 AND g_CTLPRM = 1 THEN
            IF g_OPTSHINENSOCHI = 1 AND g_CTLPRM = 1 THEN
              MJIDO_WORK(ICNT).JIDO_CHOMEI   := sJUSHO;
              --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
              --MJIDO_WORK(ICNT).JIDO_BANCHI   := sJUSHO;
              --MJIDO_WORK(ICNT).JIDO_KATAGAKI := sJUSHO;
              MJIDO_WORK(ICNT).JIDO_BANCHI   := NULL;
              MJIDO_WORK(ICNT).JIDO_KATAGAKI := NULL;
              --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
            ELSE
              MJIDO_WORK(ICNT).JIDO_CHOMEI := RJIDO_ATENA.CHOMEI;
              MJIDO_WORK(ICNT).JIDO_BANCHI := RJIDO_ATENA.BANCHI;
              MJIDO_WORK(ICNT).JIDO_KATAGAKI := RJIDO_ATENA.KATAGAKI;
            END IF;
-- 2024/07/03 ZCZL.qinyue Update end
            MJIDO_WORK(ICNT).JIDO_YUBIN_NO := RJIDO_ATENA.YUBIN_NO;
            MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC := RJIDO_ATENA.YUBIN_NOBC;
            -- 児童の送付先が設定されている場合は児童住所に送付先を再設定する
            IF RJIDO_SOFU.KOJIN_NO IS NOT NULL AND
               (RJIDO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND
               (RJIDO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RJIDO_SOFU.SHURYO_BI = 0) THEN
-- 2024/07/03 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--               MJIDO_WORK(ICNT).JIDO_SOFU_CHOMEI := RJIDO_SOFU.CHOMEI;
--               MJIDO_WORK(ICNT).JIDO_SOFU_BANCHI := RJIDO_SOFU.BANCHI;
--               MJIDO_WORK(ICNT).JIDO_SOFU_KATAGAKI := RJIDO_SOFU.KATAGAKI;
            sJUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, RJIDO_SOFU.CHOMEI, RJIDO_SOFU.BANCHI, RJIDO_SOFU.KATAGAKI, NULL);
            sJUSHO := GAAPK0030.FDVJUSHO('GKB', RJIDO_ATENA.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, sJUSHO, g_CTLPRM, 2, NULL, NULL);
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00074対応
--             IF g_OPTSHINENSOCHI = 0 AND g_CTLPRM = 1 THEN
            IF g_OPTSHINENSOCHI = 1 AND g_CTLPRM = 1 THEN
              MJIDO_WORK(ICNT).JIDO_SOFU_CHOMEI   := sJUSHO;
              --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
              --MJIDO_WORK(ICNT).JIDO_SOFU_BANCHI   := sJUSHO;
              --MJIDO_WORK(ICNT).JIDO_SOFU_KATAGAKI := sJUSHO;
              MJIDO_WORK(ICNT).JIDO_SOFU_BANCHI   := NULL;
              MJIDO_WORK(ICNT).JIDO_SOFU_KATAGAKI := NULL;
              --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
            ELSE
              MJIDO_WORK(ICNT).JIDO_SOFU_CHOMEI := RJIDO_SOFU.CHOMEI;
              MJIDO_WORK(ICNT).JIDO_SOFU_BANCHI := RJIDO_SOFU.BANCHI;
              MJIDO_WORK(ICNT).JIDO_SOFU_KATAGAKI := RJIDO_SOFU.KATAGAKI;
            END IF;
-- 2024/07/03 ZCZL.qinyue Update end
              MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO := RJIDO_SOFU.YUBIN_NO;
              MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NOBC := RJIDO_SOFU.YUBIN_NOBC;
            ELSE
              MJIDO_WORK(ICNT).JIDO_SOFU_CHOMEI := RJIDO_ATENA.CHOMEI;
              MJIDO_WORK(ICNT).JIDO_SOFU_BANCHI := RJIDO_ATENA.BANCHI;
              MJIDO_WORK(ICNT).JIDO_SOFU_KATAGAKI := RJIDO_ATENA.KATAGAKI;
              MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO := RJIDO_ATENA.YUBIN_NO;
              MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NOBC := RJIDO_ATENA.YUBIN_NOBC;
            END IF;
            --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
            --MJIDO_WORK(ICNT).DATE1 := VDATE1;
            MJIDO_WORK(ICNT).DATE1 := TO_MULTI_BYTE(REPLACE(VDATE1,' ',''));
            --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
            MJIDO_WORK(ICNT).DATE2 := VDATE2;
            MJIDO_WORK(ICNT).DATE3 := VDATE3;
            MJIDO_WORK(ICNT).DATE4 := VDATE4;
            MJIDO_WORK(ICNT).DATE5 := VDATE5;
            MJIDO_WORK(ICNT).KOMOKU1 := VKOMOKU1;
            MJIDO_WORK(ICNT).KOMOKU2 := VKOMOKU2;
            MJIDO_WORK(ICNT).KOMOKU3 := VKOMOKU3;
            MJIDO_WORK(ICNT).KOMOKU4 := VKOMOKU4;
            MJIDO_WORK(ICNT).KOMOKU5 := VKOMOKU5;
            MJIDO_WORK(ICNT).KOMOKU6 := VKOMOKU6;
            MJIDO_WORK(ICNT).KOMOKU7 := VKOMOKU7;
            MJIDO_WORK(ICNT).KOMOKU8 := VKOMOKU8;
            MJIDO_WORK(ICNT).KOMOKU9 := VKOMOKU9;
            MJIDO_WORK(ICNT).KOMOKU10 := VKOMOKU10;
            MJIDO_WORK(ICNT).DATE_MEI1 := VDATE_MEI1;
            MJIDO_WORK(ICNT).DATE_MEI2 := VDATE_MEI2;
            MJIDO_WORK(ICNT).DATE_MEI3 := VDATE_MEI3;
            MJIDO_WORK(ICNT).DATE_MEI4 := VDATE_MEI4;
            MJIDO_WORK(ICNT).DATE_MEI5 := VDATE_MEI5;
            MJIDO_WORK(ICNT).KOMOKU_MEI1 := VKOMOKU_MEI1;
            MJIDO_WORK(ICNT).KOMOKU_MEI2 := VKOMOKU_MEI2;
            MJIDO_WORK(ICNT).KOMOKU_MEI3 := VKOMOKU_MEI3;
            MJIDO_WORK(ICNT).KOMOKU_MEI4 := VKOMOKU_MEI4;
            MJIDO_WORK(ICNT).KOMOKU_MEI5 := VKOMOKU_MEI5;
            MJIDO_WORK(ICNT).KOMOKU_MEI6 := VKOMOKU_MEI6;
            MJIDO_WORK(ICNT).KOMOKU_MEI7 := VKOMOKU_MEI7;
            MJIDO_WORK(ICNT).KOMOKU_MEI8 := VKOMOKU_MEI8;
            MJIDO_WORK(ICNT).KOMOKU_MEI9 := VKOMOKU_MEI9;
            MJIDO_WORK(ICNT).KOMOKU_MEI10 := VKOMOKU_MEI10;
            IRTN := GAAPK0030.FGETATENA(MJIDO_WORK(ICNT).JIDO_KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), o_RATENA_REC, o_RSOFU_REC);
            MJIDO_WORK(ICNT).JINKAKU_KBN := o_RATENA_REC.JINKAKU_KBN;
            GET_YOCHIEN_INFO(VNENDO - 1, MJIDO_WORK(ICNT).JIDO_KOJIN_NO, o_YOCHIEN_CD, o_YOCHIENMEI);
            MJIDO_WORK(ICNT).YOCHIEN_CD := o_YOCHIEN_CD;
            MJIDO_WORK(ICNT).YOCHIENMEI := o_YOCHIENMEI;
--  2024/07/05 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE２次開発
            --通知文
            MJIDO_WORK(ICNT).TSUCHIBUN := g_TSUCHIBUN;
            --公印パス
            MJIDO_WORK(ICNT).KOIN_PATH := VGYOMU;
            --公印（省略）
            MJIDO_WORK(ICNT).KOIN_SHORYAKU := g_KOINSHORYAKU;
            --公印（注釈）
            MJIDO_WORK(ICNT).KOIN_CHUSHAKU := g_KOINCHUSHAKU;
            --様式番号
            MJIDO_WORK(ICNT).YOSHIKI_NO := g_YOSHIKIBANGO;
            --学校名
            MJIDO_WORK(ICNT).GAKKO_MEI := GKAFKGKOGTEQ(1 ,CRATENA_WORK.SHOGAKKOKU_CD);
            --学校コード
            MJIDO_WORK(ICNT).GAKKO_CD := CRATENA_WORK.SHOGAKKOKU_CD;
--  2024/07/05 ZCZL.qinyue Add end
            ICNT := ICNT + 1;               -- カウントアップ
            IFRET := c_ISUCCESS;              -- 正常終了
          ELSE
            NULL;
          END IF;
        END LOOP;
        CLOSE CJIDO;
        RETURN IFRET;
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
    --  機能概要      : 児童生徒ワーク中間（GKBWJIDOSHINDANKEKKA）テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 ,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------------------------------
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
          INSERT INTO GKBWJIDOSHINDANKEKKA VALUES MJIDO_WORK(ICNT);
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
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------
    --  機能概要      : 出力順を取得する
    --  パラメータ    : i_nCHOHYONUM
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_GETSORTCOLS(i_nCHOHYONUM IN KKBTSPRT.CHOHYONUM%TYPE) RETURN NVARCHAR2
    IS
       v_ORDERBY_LIST KKBTSPRT.ORDERBYCLAUSE_LIST%TYPE;
    BEGIN
       BEGIN
         --帳票ごとに、出力順を取得する
         SELECT ORDERBYCLAUSE_LIST INTO v_ORDERBY_LIST
           FROM KKBTSPRT
          WHERE GYOUMUCODE = g_sGYOUMUCODE    --共通部品の場合、業務コード
             AND CHOHYONUM = i_nCHOHYONUM;
       EXCEPTION
         WHEN OTHERS THEN
           --帳票ごとがない場合、NULLを出力する
           v_ORDERBY_LIST := NULL;
       END;
       RETURN v_ORDERBY_LIST;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_GETSORTCOLS;
    --------------------------------------------------------------------------------
    --  機能概要      : 児童生徒中間（GKBWJIDOSHINDANKEKKA）テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 ,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
      FRET                PLS_INTEGER;                -- 戻り値
      ICNT                BINARY_INTEGER;             -- カウント
      VSQL                NVARCHAR2(10000);           -- ＳＱＬ文
      VSQLSEL             NVARCHAR2(9000);            -- ＳＱＬのソート以外
      VSQLORDER           NVARCHAR2(1000);            -- ＳＱＬの［ORDER BY］句
      I_CUR               PLS_INTEGER;                -- カーソル
      RREC                GKBWJIDOSHINDANKEKKA%ROWTYPE;      -- 入学通知台帳のレコード変数
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
      IGYORENBAN := 0;
      MJIDO_WORK.DELETE;                   -- ワーク領域の初期化
      -- ソート条件取得
      VSQLORDER := '';
      IF NRENBAN = 0 THEN
         VSQLORDER := ' GAKO_KBN,GAKOKU_CD,GYOSEIKU_CD,CHOHYO_NO ';
      ELSE
         CASE g_rJSTP.CHOHYOID
         -- 就学時健康診断結果通知書のソート条件取得
         WHEN 'GKB060R001' THEN
           VSQLORDER := FUNC_GETSORTCOLS(601);
           --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
           IF VSQLORDER IS NULL THEN
             VSQLORDER :=' GAKO_KBN,GAKOKU_CD,GYOSEIKU_CD,CHOHYO_NO ';
           ELSE
             VSQLORDER := FUNC_GETSORTCOLS(601);
           END IF;
           --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
         -- 健康診断結果通知発送者一覧表のソート条件取得
-- 2024/07/24 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--         WHEN 'GKB150R002' THEN
--  2024/10/21 ZCZL.WANGMING Update 0.3.000.004:IT_GKB_00341横展開対応
--         WHEN 'GKB130R012' THEN
         WHEN 'GKB130R002' THEN
           VSQLORDER := FUNC_GETSORTCOLS(1502);
           --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
           IF VSQLORDER IS NULL THEN
             VSQLORDER :=' GAKO_KBN,GAKOKU_CD,GYOSEIKU_CD,CHOHYO_NO ';
           ELSE
             VSQLORDER := FUNC_GETSORTCOLS(1502);
           END IF;
           --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
         -- 健康診断結果診断票のソート条件取得
         WHEN 'GKB020R001' THEN
           VSQLORDER := FUNC_GETSORTCOLS(202);
           --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
           IF VSQLORDER IS NULL THEN
             VSQLORDER :=' GAKO_KBN,GAKOKU_CD,GYOSEIKU_CD,CHOHYO_NO ';
           ELSE
             VSQLORDER := FUNC_GETSORTCOLS(202);
           END IF;
           --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
         ELSE
           NULL;
         END CASE;
      END IF;
      -- ［ORDER BY］句を付加
      IF KKAPK0010.FTrim(VSQLORDER) IS NOT NULL THEN
         VSQLORDER := ' ORDER BY ' || VSQLORDER;
      END IF;
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
        VSQLSEL := VSQLSEL || 'HYOJI_SEINENGAPI, ';
        VSQLSEL := VSQLSEL || 'KANJI_SEINENGAPI, ';
        VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
        VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN, ';
        VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN, ';
        VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN, ';
        VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN, ';
        VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
        VSQLSEL := VSQLSEL || 'GAKOKUMEI, ';
        VSQLSEL := VSQLSEL || 'SANTEIDANTAIMEI, ';
        VSQLSEL := VSQLSEL || 'YUBIN_NO, ';
        VSQLSEL := VSQLSEL || 'CHOMEI, ';
        VSQLSEL := VSQLSEL || 'BANCHI, ';
        VSQLSEL := VSQLSEL || 'KATAGAKI, ';
        VSQLSEL := VSQLSEL || 'NENREI, ';
        VSQLSEL := VSQLSEL || 'JIDO_CHOMEI, ';
        VSQLSEL := VSQLSEL || 'JIDO_BANCHI, ';
        VSQLSEL := VSQLSEL || 'JIDO_KATAGAKI, ';
        VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
        VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANJI, ';
        VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
            IF NRENBAN =0 THEN
               IF o_RENBANPRM(1) IN (1,2,3) THEN
                  VSQLSEL := VSQLSEL || ' GAKO_KBN || GAKOKU_CD '|| ' PAGE_FIELD, ';          -- 改頁値を設定
                  VSQLSEL := VSQLSEL || ' GAKOKUMEI '|| ' PAGE_NAME, ';                     -- 改頁名を設定
               ELSIF o_RENBANPRM(1) IN (4,5) THEN
                  VSQLSEL := VSQLSEL || ' GAKO_KBN || GAKOKU_CD || GYOSEIKU_CD '|| ' PAGE_FIELD, ';     -- 改頁値を設定
                  VSQLSEL := VSQLSEL || ' GAKOKUMEI || '' '' || GYOSEIKUMEI '|| ' PAGE_NAME, ';      -- 改頁名を設定
               ELSE
                  VSQLSEL := VSQLSEL || 'null as PAGE_FIELD, ';                            -- 改頁値を設定
                  VSQLSEL := VSQLSEL || 'null as PAGE_NAME, ';                             -- 改頁名を設定
               END IF;
             ELSE
                  VSQLSEL := VSQLSEL ||  VPAGEFD || ' PAGE_FIELD, ';     -- 改頁値を設定
                  VSQLSEL := VSQLSEL ||  VPAGENM || ' PAGE_NAME, ';      -- 改頁名を設定
            END IF;
        VSQLSEL := VSQLSEL || 'DATE1, ';
        VSQLSEL := VSQLSEL || 'DATE2, ';
        VSQLSEL := VSQLSEL || 'DATE3, ';
        VSQLSEL := VSQLSEL || 'DATE4, ';
        VSQLSEL := VSQLSEL || 'DATE5, ';
        VSQLSEL := VSQLSEL || 'KOMOKU1, ';
        VSQLSEL := VSQLSEL || 'KOMOKU2, ';
        VSQLSEL := VSQLSEL || 'KOMOKU3, ';
        VSQLSEL := VSQLSEL || 'KOMOKU4, ';
        VSQLSEL := VSQLSEL || 'KOMOKU5, ';
        VSQLSEL := VSQLSEL || 'KOMOKU6, ';
        VSQLSEL := VSQLSEL || 'KOMOKU7, ';
        VSQLSEL := VSQLSEL || 'KOMOKU8, ';
        VSQLSEL := VSQLSEL || 'KOMOKU9, ';
        VSQLSEL := VSQLSEL || 'KOMOKU10, ';
        VSQLSEL := VSQLSEL || 'DATE_MEI1, ';
        VSQLSEL := VSQLSEL || 'DATE_MEI2, ';
        VSQLSEL := VSQLSEL || 'DATE_MEI3, ';
        VSQLSEL := VSQLSEL || 'DATE_MEI4, ';
        VSQLSEL := VSQLSEL || 'DATE_MEI5, ';
        VSQLSEL := VSQLSEL || 'KOMOKU_MEI1, ';
        VSQLSEL := VSQLSEL || 'KOMOKU_MEI2, ';
        VSQLSEL := VSQLSEL || 'KOMOKU_MEI3, ';
        VSQLSEL := VSQLSEL || 'KOMOKU_MEI4, ';
        VSQLSEL := VSQLSEL || 'KOMOKU_MEI5, ';
        VSQLSEL := VSQLSEL || 'KOMOKU_MEI6, ';
        VSQLSEL := VSQLSEL || 'KOMOKU_MEI7, ';
        VSQLSEL := VSQLSEL || 'KOMOKU_MEI8, ';
        VSQLSEL := VSQLSEL || 'KOMOKU_MEI9, ';
        VSQLSEL := VSQLSEL || 'KOMOKU_MEI10, ';
        VSQLSEL := VSQLSEL || 'GAKOKU_CD  ';
        VSQLSEL := VSQLSEL || ',YUBIN_NOBC  ';
        VSQLSEL := VSQLSEL || ',JIDO_YUBIN_NO ';
        VSQLSEL := VSQLSEL || ',JIDO_YUBIN_NOBC ';
        VSQLSEL := VSQLSEL || ',SOFU_YUBIN_NO ';
        VSQLSEL := VSQLSEL || ',SOFU_YUBIN_NOBC ';
        VSQLSEL := VSQLSEL || ',SOFU_CHOMEI ';
        VSQLSEL := VSQLSEL || ',SOFU_BANCHI ';
        VSQLSEL := VSQLSEL || ',SOFU_KATAGAKI ';
        VSQLSEL := VSQLSEL || ',JIDO_SOFU_YUBIN_NO ';
        VSQLSEL := VSQLSEL || ',JIDO_SOFU_YUBIN_NOBC ';
        VSQLSEL := VSQLSEL || ',JIDO_SOFU_CHOMEI ';
        VSQLSEL := VSQLSEL || ',JIDO_SOFU_BANCHI ';
        VSQLSEL := VSQLSEL || ',JIDO_SOFU_KATAGAKI ';
        VSQLSEL := VSQLSEL || ',KIJUN_BI';
        VSQLSEL := VSQLSEL || ',KYOIKUKAI_MEI';
        VSQLSEL := VSQLSEL || ',ATESAKI_JODAN';
        VSQLSEL := VSQLSEL || ',ATESAKI_GEDAN';
        VSQLSEL := VSQLSEL || ',KYOIKU_TEL';
        VSQLSEL := VSQLSEL || ',KYOIKU_YUBIN_NO';
        VSQLSEL := VSQLSEL || ',KYOIKU_JUSHO';
        VSQLSEL := VSQLSEL || ',KYOIKU_YAKUSHOKU_MEI';
        VSQLSEL := VSQLSEL || ',KYOIKU_SHUTHOU_MEI';
        VSQLSEL := VSQLSEL || ',KYOIKU_RITSU_MEI';
        VSQLSEL := VSQLSEL || ',KYOIKU_TEL_NAISEN';
        VSQLSEL := VSQLSEL || ',ZOKUGARAMEI1';
        VSQLSEL := VSQLSEL || ',HYOJI_CHOHYO_NO';
        VSQLSEL := VSQLSEL || ',CHOHYO_NO ';
        VSQLSEL := VSQLSEL || ',JINKAKU_KBN';
        VSQLSEL := VSQLSEL || ',YOCHIEN_CD';
        VSQLSEL := VSQLSEL || ',YOCHIENMEI ';
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        VSQLSEL := VSQLSEL || ',TSUCHIBUN ';
        VSQLSEL := VSQLSEL || ',KOIN_PATH ';
        VSQLSEL := VSQLSEL || ',KOIN_SHORYAKU ';
        VSQLSEL := VSQLSEL || ',KOIN_CHUSHAKU ';
        VSQLSEL := VSQLSEL || ',YOSHIKI_NO ';
        VSQLSEL := VSQLSEL || ',JIDO_KOJIN_NO ';
        VSQLSEL := VSQLSEL || ',HOGOSHA_KOJIN_NO ';
        VSQLSEL := VSQLSEL || ',GAKKO_MEI ';
        VSQLSEL := VSQLSEL || ',GAKKO_CD ';
-- 2024/07/03 ZCZL.qinyue Add end
-- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
        VSQLSEL := VSQLSEL || ',GAKO_KBN';--学校区分
        VSQLSEL := VSQLSEL || ',GAAPK0030.FYUHENKBNGET(HOGOSHA_KOJIN_NO ,''GKB'',TO_NUMBER(TO_CHAR(SYSDATE,''YYYYMMDD''))) AS YUHEN_KBN ';--郵返区分はソートのみに抽出する
-- 2025/09/17 CTC.Zhou Add End
        VSQLSEL := VSQLSEL || 'FROM ';
        VSQLSEL := VSQLSEL || 'GKBWJIDOSHINDANKEKKA ';
        -- ひとつのＳＱＬ文にする
        VSQL := VSQLSEL || VSQLORDER;

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
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.HYOJI_SEINENGAPI, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.KANJI_SEINENGAPI, 13);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.HYOJI_SEIBETSU, 2);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.HOGOSHA_SHIMEI_JODAN, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.HOGOSHA_SHIMEI_GEDAN, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.KON_JUSHO_JODAN, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.KON_JUSHO_GEDAN, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.GYOSEIKUMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.GAKOKUMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.SANTEIDANTAIMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.YUBIN_NO, 10);
-- 2024/07/03 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.CHOMEI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.BANCHI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.KATAGAKI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.CHOMEI, 136);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.BANCHI, 50);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.KATAGAKI, 300);
-- 2024/07/03 ZCZL.qinyue Update end
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.NENREI, 3);
-- 2024/07/03 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.JIDO_CHOMEI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.JIDO_BANCHI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.JIDO_KATAGAKI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.JIDO_CHOMEI, 136);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.JIDO_BANCHI, 50);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.JIDO_KATAGAKI, 300);
-- 2024/07/03 ZCZL.qinyue Update end
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.HOGOSHA_SHIMEI_KANA, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.HOGOSHA_SHIMEI_KANJI, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.ZOKUGARAMEI2, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, VPAGEFD, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, VPAGENM, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, RREC.DATE1, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, RREC.DATE2, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, RREC.DATE3, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 34, RREC.DATE4, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 35, RREC.DATE5, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 36, RREC.KOMOKU1, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 37, RREC.KOMOKU2, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 38, RREC.KOMOKU3, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 39, RREC.KOMOKU4, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 40, RREC.KOMOKU5, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 41, RREC.KOMOKU6, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 42, RREC.KOMOKU7, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 43, RREC.KOMOKU8, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 44, RREC.KOMOKU9, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 45, RREC.KOMOKU10, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 46, RREC.DATE_MEI1, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 47, RREC.DATE_MEI2, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 48, RREC.DATE_MEI3, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 49, RREC.DATE_MEI4, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 50, RREC.DATE_MEI5, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 51, RREC.KOMOKU_MEI1, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 52, RREC.KOMOKU_MEI2, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 53, RREC.KOMOKU_MEI3, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 54, RREC.KOMOKU_MEI4, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 55, RREC.KOMOKU_MEI5, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 56, RREC.KOMOKU_MEI6, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 57, RREC.KOMOKU_MEI7, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 58, RREC.KOMOKU_MEI8, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 59, RREC.KOMOKU_MEI9, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 60, RREC.KOMOKU_MEI10, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 61, RREC.GAKOKU_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 62, RREC.YUBIN_NOBC, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 63, RREC.JIDO_YUBIN_NO, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 64, RREC.JIDO_YUBIN_NOBC, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 65, RREC.SOFU_YUBIN_NO, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 66, RREC.SOFU_YUBIN_NOBC, 30);
-- 2024/07/03 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 67, RREC.SOFU_CHOMEI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 68, RREC.SOFU_BANCHI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 69, RREC.SOFU_KATAGAKI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 67, RREC.SOFU_CHOMEI, 136);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 68, RREC.SOFU_BANCHI, 50);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 69, RREC.SOFU_KATAGAKI, 300);
-- 2024/07/03 ZCZL.qinyue Update end
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 70, RREC.JIDO_SOFU_YUBIN_NO, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 71, RREC.JIDO_SOFU_YUBIN_NOBC, 30);
-- 2024/07/03 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 72, RREC.JIDO_SOFU_CHOMEI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 73, RREC.JIDO_SOFU_BANCHI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 74, RREC.JIDO_SOFU_KATAGAKI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 72, RREC.JIDO_SOFU_CHOMEI, 136);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 73, RREC.JIDO_SOFU_BANCHI, 50);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 74, RREC.JIDO_SOFU_KATAGAKI, 300);
-- 2024/07/03 ZCZL.qinyue Update end
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 75, RREC.KIJUN_BI, 16);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 76, RREC.KYOIKUKAI_MEI,60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 77, RREC.ATESAKI_JODAN,110);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 78, RREC.ATESAKI_GEDAN,110);
--  2025/08/22 CTC.GYY UPDATE 1.0.102.000:GKB_QA19542対応　START
       -- DBMS_SQL.DEFINE_COLUMN(I_CUR, 79, RREC.KYOIKU_TEL, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 79, RREC.KYOIKU_TEL, 60);
--  2025/08/22 CTC.GYY UPDATE 1.0.102.000:GKB_QA19542対応　END
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 80, RREC.KYOIKU_YUBIN_NO, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 81, RREC.KYOIKU_JUSHO, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 82, RREC.KYOIKU_YAKUSHOKU_MEI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 83, RREC.KYOIKU_SHUTHOU_MEI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 84, RREC.KYOIKU_RITSU_MEI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 85, RREC.KYOIKU_TEL_NAISEN, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 86, RREC.ZOKUGARAMEI1, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 87, RREC.HYOJI_CHOHYO_NO, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 88, RREC.CHOHYO_NO);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 89, RREC.JINKAKU_KBN);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 90, RREC.YOCHIEN_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 91, RREC.YOCHIENMEI, 20);
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 92, RREC.TSUCHIBUN, 300);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 93, RREC.KOIN_PATH, 240);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 94, RREC.KOIN_SHORYAKU, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 95, RREC.KOIN_CHUSHAKU, 50);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 96, RREC.YOSHIKI_NO, 34);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 97, RREC.JIDO_KOJIN_NO);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 98, RREC.HOGOSHA_KOJIN_NO);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 99, RREC.GAKKO_MEI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 100, RREC.GAKKO_CD);
-- 2024/07/03 ZCZL.qinyue Add end
--  2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 101, RREC.GAKO_KBN);--学校区分
--  2025/09/17 CTC.Zhou Add End
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
            DBMS_SQL.COLUMN_VALUE(I_CUR,  6, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  7, MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
            DBMS_SQL.COLUMN_VALUE(I_CUR,  9, MJIDO_WORK(ICNT).KANJI_SEINENGAPI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MJIDO_WORK(ICNT).KON_JUSHO_JODAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MJIDO_WORK(ICNT).KON_JUSHO_GEDAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MJIDO_WORK(ICNT).GYOSEIKUMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MJIDO_WORK(ICNT).GAKOKUMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MJIDO_WORK(ICNT).SANTEIDANTAIMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 18, MJIDO_WORK(ICNT).YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 19, MJIDO_WORK(ICNT).CHOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 20, MJIDO_WORK(ICNT).BANCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 21, MJIDO_WORK(ICNT).KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 22, MJIDO_WORK(ICNT).NENREI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 23, MJIDO_WORK(ICNT).JIDO_CHOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 24, MJIDO_WORK(ICNT).JIDO_BANCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 25, MJIDO_WORK(ICNT).JIDO_KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 26, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 27, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 28, MJIDO_WORK(ICNT).ZOKUGARAMEI2);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 29, VPAGEFIELD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 30, VPAGENAME);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 31, MJIDO_WORK(ICNT).DATE1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 32, MJIDO_WORK(ICNT).DATE2);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 33, MJIDO_WORK(ICNT).DATE3);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 34, MJIDO_WORK(ICNT).DATE4);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 35, MJIDO_WORK(ICNT).DATE5);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 36, MJIDO_WORK(ICNT).KOMOKU1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 37, MJIDO_WORK(ICNT).KOMOKU2);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 38, MJIDO_WORK(ICNT).KOMOKU3);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 39, MJIDO_WORK(ICNT).KOMOKU4);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 40, MJIDO_WORK(ICNT).KOMOKU5);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 41, MJIDO_WORK(ICNT).KOMOKU6);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 42, MJIDO_WORK(ICNT).KOMOKU7);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 43, MJIDO_WORK(ICNT).KOMOKU8);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 44, MJIDO_WORK(ICNT).KOMOKU9);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 45, MJIDO_WORK(ICNT).KOMOKU10);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 46, MJIDO_WORK(ICNT).DATE_MEI1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 47, MJIDO_WORK(ICNT).DATE_MEI2);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 48, MJIDO_WORK(ICNT).DATE_MEI3);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 49, MJIDO_WORK(ICNT).DATE_MEI4);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 50, MJIDO_WORK(ICNT).DATE_MEI5);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 51, MJIDO_WORK(ICNT).KOMOKU_MEI1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 52, MJIDO_WORK(ICNT).KOMOKU_MEI2);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 53, MJIDO_WORK(ICNT).KOMOKU_MEI3);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 54, MJIDO_WORK(ICNT).KOMOKU_MEI4);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 55, MJIDO_WORK(ICNT).KOMOKU_MEI5);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 56, MJIDO_WORK(ICNT).KOMOKU_MEI6);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 57, MJIDO_WORK(ICNT).KOMOKU_MEI7);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 58, MJIDO_WORK(ICNT).KOMOKU_MEI8);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 59, MJIDO_WORK(ICNT).KOMOKU_MEI9);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 60, MJIDO_WORK(ICNT).KOMOKU_MEI10);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 61, MJIDO_WORK(ICNT).GAKOKU_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 62, MJIDO_WORK(ICNT).YUBIN_NOBC);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 63, MJIDO_WORK(ICNT).JIDO_YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 64, MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 65, MJIDO_WORK(ICNT).SOFU_YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 66, MJIDO_WORK(ICNT).SOFU_YUBIN_NOBC);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 67, MJIDO_WORK(ICNT).SOFU_CHOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 68, MJIDO_WORK(ICNT).SOFU_BANCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 69, MJIDO_WORK(ICNT).SOFU_KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 70, MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 71, MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NOBC);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 72, MJIDO_WORK(ICNT).JIDO_SOFU_CHOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 73, MJIDO_WORK(ICNT).JIDO_SOFU_BANCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 74, MJIDO_WORK(ICNT).JIDO_SOFU_KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 75, MJIDO_WORK(ICNT).KIJUN_BI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 76, MJIDO_WORK(ICNT).KYOIKUKAI_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 77, MJIDO_WORK(ICNT).ATESAKI_JODAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 78, MJIDO_WORK(ICNT).ATESAKI_GEDAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 79, MJIDO_WORK(ICNT).KYOIKU_TEL);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 80, MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 81, MJIDO_WORK(ICNT).KYOIKU_JUSHO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 82, MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 83, MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 84, MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 85, MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 86, MJIDO_WORK(ICNT).ZOKUGARAMEI1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 87, MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 88, MJIDO_WORK(ICNT).CHOHYO_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 89, MJIDO_WORK(ICNT).JINKAKU_KBN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 90, MJIDO_WORK(ICNT).YOCHIEN_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 91, MJIDO_WORK(ICNT).YOCHIENMEI);
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
            DBMS_SQL.COLUMN_VALUE(I_CUR, 92, MJIDO_WORK(ICNT).TSUCHIBUN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 93, MJIDO_WORK(ICNT).KOIN_PATH);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 94, MJIDO_WORK(ICNT).KOIN_SHORYAKU);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 95, MJIDO_WORK(ICNT).KOIN_CHUSHAKU);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 96, MJIDO_WORK(ICNT).YOSHIKI_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 97, MJIDO_WORK(ICNT).JIDO_KOJIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 98, MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 99, MJIDO_WORK(ICNT).GAKKO_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 100, MJIDO_WORK(ICNT).GAKKO_CD);
-- 2024/07/03 ZCZL.qinyue Add end
--  2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
            DBMS_SQL.COLUMN_VALUE(I_CUR, 101, MJIDO_WORK(ICNT).GAKO_KBN);--学校区分
--  郵返区分はMJIDO_WORKに存在しないため、値は帳票ワーク設定時再度取得する
--  2025/09/17 CTC.Zhou Add End

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
            ELSIF VPAGEWORK IS NULL AND VPAGENAME IS NULL THEN
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
            MJIDO_WORK(ICNT).KAIPEJI_CD := VPAGEFIELD; -- 改頁コード

          ELSE
            -- 全件読み込み終了
            EXIT;
          END IF;
          ICNT := ICNT + 1;
        END LOOP;
        DBMS_SQL.CLOSE_CURSOR(I_CUR);
      EXCEPTION
        WHEN OTHERS THEN
          FRET := c_INOT_SUCCESS;      -- 異常終了
          -- SQL情報取得
          N_SQL_CODE := SQLCODE;
          V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
          IF DBMS_SQL.IS_OPEN(I_CUR) THEN
            DBMS_SQL.CLOSE_CURSOR(I_CUR);
          END IF;
          -- 処理ログの出力
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
      END;
      RETURN FRET;
    END FUNC_GET_JIDO_WK_CSV;
    --------------------------------------------------------------------------------
    --  機能概要      : 健康診断結果通知書ＣＳＶファイルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 ,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE1 RETURN NUMBER IS
      FRET                PLS_INTEGER;                -- 戻り値
      ICNT                BINARY_INTEGER;             -- カウント
      IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
      IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
      VTANTO_TEL_NO       NVARCHAR2(60);              -- 教育委員会電話番号
      VTANTO_YUBIN_NO     NVARCHAR2(60);              -- 教育委員会郵便番号
      VTANTO_JUSHO        NVARCHAR2(60);              -- 教育委員会住所
      VYUBIN_NO           NVARCHAR2(60);              -- 郵便番号編集用
      ICNT_1              BINARY_INTEGER := 0;        -- カウント
      r_WKRECORD001       GKBWL060R001%ROWTYPE;
      TACONSPRM           A_CONS_PRM;                 --戻るパラメータ配列
      NLENGTH             NUMBER;                     --配列件数
      --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
      sBUNSHONOTMP        NVARCHAR2(100);             --文書番号TMP
      nCNT                NUMBER :=0;
      --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
    BEGIN
      FRET := c_ISUCCESS;                             -- 正常終了
      -- 収発名を取得する
      BEGIN
        SELECT SHUHATS_MEI
          INTO VSYUHATU_MEI
          FROM GKBTTSUCHISHOKANRI
         WHERE CHOHYO_KBN = c_CHOHYO_KBN;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          VSYUHATU_MEI := '';
      END;
      IMAX := MJIDO_WORK.LAST;             -- ワーク領域の件数の最大値
      IMIN := MJIDO_WORK.FIRST;            -- ワーク領域の件数の最小値
      BEGIN
        IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      4,         --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
        IF NLENGTH <> 0 THEN
        --レコードが取得できた場合
          VTANTO_TEL_NO := TACONSPRM(1);
        ELSE
        --レコードが取得できない場合
          VTANTO_TEL_NO := 0;
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          VTANTO_TEL_NO := '';
      END;
      BEGIN
        IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      2,         --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
        IF NLENGTH <> 0 THEN
        --レコードが取得できた場合
          VTANTO_YUBIN_NO := TACONSPRM(1);
        ELSE
        --レコードが取得できない場合
          VTANTO_YUBIN_NO := 0;
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          VTANTO_YUBIN_NO := '';
      END;
      IF VTANTO_YUBIN_NO IS NOT NULL THEN
        VTANTO_YUBIN_NO := SUBSTR(VTANTO_YUBIN_NO, 1, 3) || '-' || SUBSTR(VTANTO_YUBIN_NO, 4);
        VTANTO_YUBIN_NO := TRANSLATE( VTANTO_YUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
      END IF;
      BEGIN
        IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      3,         --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
        IF NLENGTH <> 0 THEN
        --レコードが取得できた場合
          VTANTO_JUSHO := TACONSPRM(1);
        ELSE
        --レコードが取得できない場合
          VTANTO_JUSHO := 0;
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          VTANTO_JUSHO := '';
      END;

      -- 取得した件数分繰り返す
      FOR ICNT IN IMIN..IMAX LOOP
        ICNT_1 := ICNT_1 + 1;
        r_WKRECORD001 := NULL;
-- 2025/09/17 CTC.Zhou Add Start 1.0.200.000:新WizLIFE開発_帳票アウトソーシング連番対応
        r_WKRECORD001.KYOTSU_TSUSU_RENBAN     := LPAD(ICNT_1, 6, '0');                              -- 業務共通_通数連番
        r_WKRECORD001.KYOTSU_PAGE_RENBAN      := NULL;                                              -- 業務共通_頁連番
        r_WKRECORD001.KYOTSU_DOFU_RENBAN      := NULL;                                              -- 業務共通_同封内連番
        r_WKRECORD001.KYOTSU_DOFU_MAISU       := NULL;                                              -- 業務共通_同封内枚数
        r_WKRECORD001.KYOTSU_YUBIN_K_KBN      := NULL;                                              -- 業務共通_郵便局区分
        r_WKRECORD001.KYOTSU_YUHEN_KBN        := GAAPK0030.FYUHENKBNGET(
                                                                 MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO
                                                                 , 'GKB'
                                                                 , TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'))
                                                                 );                                  -- 業務共通_郵返区分
        r_WKRECORD001.KYOTSU_CHOSHU_KBN       := NULL;                                               -- 業務共通_徴収区分
--  2025/12/05 CTC.NI UPDATE START 1.0.402.000:不具合対応
        --r_WKRECORD001.KYOTSU_GAKKO_KBN        := MJIDO_WORK(ICNT).GAKO_KBN;                          -- 業務共通_学校区分
        r_WKRECORD001.KYOTSU_GAKKO_KBN        := LPAD(MJIDO_WORK(ICNT).GAKO_KBN, 2, '0');            -- 業務共通_学校区分
--  2025/12/05 CTC.NI UPDATE END
        r_WKRECORD001.KYOTSU_YOBI_AREA1       := NULL;                                               -- 業務共通_予備エリア1
        r_WKRECORD001.KYOTSU_YOBI_AREA2       := NULL;                                               -- 業務共通_予備エリア2
        r_WKRECORD001.KYOTSU_YOBI_AREA3       := NULL;                                               -- 業務共通_予備エリア3
        r_WKRECORD001.KYOTSU_YOBI_AREA4       := NULL;                                               -- 業務共通_予備エリア4
        r_WKRECORD001.KYOTSU_YOBI_AREA5       := NULL;                                               -- 業務共通_予備エリア5
        r_WKRECORD001.KYOTSU_YOBI_AREA6       := NULL;                                               -- 業務共通_予備エリア6
        r_WKRECORD001.KYOTSU_YOBI_AREA7       := NULL;                                               -- 業務共通_予備エリア7
        r_WKRECORD001.KYOTSU_YOBI_AREA8       := NULL;                                               -- 業務共通_予備エリア8
        r_WKRECORD001.KYOTSU_YOBI_AREA9       := NULL;                                               -- 業務共通_予備エリア9
        r_WKRECORD001.KYOTSU_YOBI_AREA10      := NULL;                                               -- 業務共通_予備エリア10
        r_WKRECORD001.KYOTSU_YOBI_AREA11      := NULL;                                               -- 業務共通_予備エリア11
        r_WKRECORD001.KYOTSU_YOBI_AREA12      := NULL;                                               -- 業務共通_予備エリア12
-- 2025/09/17 CTC.Zhou Add End
        r_WKRECORD001.NO                      := ICNT_1;                                             --ソート順

        r_WKRECORD001.NENDO                   := MJIDO_WORK(ICNT).NENDO;                             --年度
        r_WKRECORD001.KAIPAGE_CD              := MJIDO_WORK(ICNT).KAIPEJI_CD;                        --改頁コード
        r_WKRECORD001.KAIPAGE                 := MJIDO_WORK(ICNT).KAIPEJI;                           --改頁
        r_WKRECORD001.SAKUSEIBI               := MJIDO_WORK(ICNT).KIJUN_BI;                          --作成日
        r_WKRECORD001.RENBAN                  := MJIDO_WORK(ICNT).RENBAN;                            --連番
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
        --IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
            --r_WKRECORD001.BUNSHO_NO            := g_rBUNNUM;                                         --文書番号
          IF rBUNNUMEDITKEKA2.NUMUMUFLG = 0 THEN
            r_WKRECORD001.BUNSHO_NO            := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_vBUNNUM_KENKOSYO, 0),' ',''),'　','');--文書番号
        --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
          ELSE
            r_WKRECORD001.BUNSHO_NO            := NULL;
          END IF;
-- 2024/07/03 ZCZL.qinyue Add end
        r_WKRECORD001.JIDO_SHIMEI_KANA        := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;                  --児童氏名カナ
        r_WKRECORD001.JIDO_SHIMEI_KANJI       := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;                 --児童氏名漢字
        r_WKRECORD001.HYOJI_SEINENGAPI        := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;                  --表示生年月日
        r_WKRECORD001.HYOJI_SEIBETSU          := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;                    --表示性別
        r_WKRECORD001.HOGOSHA_SHIMEI_JODAN    := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN;              --保護者氏名上段
        r_WKRECORD001.HOGOSHA_SHIMEI_GEDAN    := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;              --保護者氏名下段
        r_WKRECORD001.JUSHO_JODAN             := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;                   --住所上
        r_WKRECORD001.JUSHO_GEDAN             := MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;                   --住所下
        r_WKRECORD001.GYOSEIKU_MEI            := MJIDO_WORK(ICNT).GYOSEIKUMEI;                       --行政区名
        r_WKRECORD001.GAKKOKU_MEI             := MJIDO_WORK(ICNT).GAKOKUMEI;                         --学校区名
        r_WKRECORD001.SANTEIDANTAI_MEI        := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;                   --算定団体名
        --宛先郵便番号
        IF LENGTH(MJIDO_WORK(ICNT).SOFU_YUBIN_NO) > 0 THEN
          VYUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).SOFU_YUBIN_NO,1,3) || '-' || SUBSTR(MJIDO_WORK(ICNT).SOFU_YUBIN_NO,4);
          VYUBIN_NO := TRANSLATE(VYUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
          r_WKRECORD001.ATESAKI_YUBIN_NO      := VYUBIN_NO;
        ELSE
          r_WKRECORD001.ATESAKI_YUBIN_NO      := MJIDO_WORK(ICNT).SOFU_YUBIN_NO;
        END IF;
        --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
        --r_WKRECORD001.ATESAKI_CHOMEI_BANCHI   := MJIDO_WORK(ICNT).SOFU_CHOMEI || MJIDO_WORK(ICNT).SOFU_BANCHI;    --宛先町名番地
        --r_WKRECORD001.ATESAKI_KATAGAKI        := MJIDO_WORK(ICNT).SOFU_KATAGAKI;                     --宛先方書
        IF MJIDO_WORK(ICNT).CHOMEI IS NOT NULL THEN
          r_WKRECORD001.ATESAKI_CHOMEI_BANCHI   := MJIDO_WORK(ICNT).SOFU_CHOMEI || MJIDO_WORK(ICNT).SOFU_BANCHI;    --宛先町名番地
          r_WKRECORD001.ATESAKI_KATAGAKI        := MJIDO_WORK(ICNT).SOFU_KATAGAKI;                     --宛先方書
        ELSE
          r_WKRECORD001.ATESAKI_CHOMEI_BANCHI   := MJIDO_WORK(ICNT).CHOMEI || MJIDO_WORK(ICNT).BANCHI;    --宛先町名番地
          r_WKRECORD001.ATESAKI_KATAGAKI        := MJIDO_WORK(ICNT).KATAGAKI;                     --宛先方書
        END IF;
        --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
        r_WKRECORD001.ATESAKI_JODAN           := MJIDO_WORK(ICNT).ATESAKI_JODAN;                     --宛先上段
        r_WKRECORD001.ATESAKI_GEDAN           := MJIDO_WORK(ICNT).ATESAKI_GEDAN;                     --宛先下段
        r_WKRECORD001.KANJI_SEINENGAPI        := MJIDO_WORK(ICNT).KANJI_SEINENGAPI;                  --漢字生年月日
        r_WKRECORD001.NENREI                  := MJIDO_WORK(ICNT).NENREI;                            --年齢
        r_WKRECORD001.JIDO_JUSHO              := MJIDO_WORK(ICNT).JIDO_SOFU_CHOMEI || MJIDO_WORK(ICNT).JIDO_SOFU_BANCHI || MJIDO_WORK(ICNT).JIDO_SOFU_KATAGAKI;    --児童現住所
        r_WKRECORD001.HOGOSHA_SHIMEI_KANA     := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;               --保護者氏名カナ
        r_WKRECORD001.HOGOSHA_SHIMEI_KANJI    := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;              --保護者氏名漢字
-- 2024/07/03 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--        r_WKRECORD001.CHOMEI_BANCHI_KATAGAKI  := MJIDO_WORK(ICNT).CHOMEI || MJIDO_WORK(ICNT).BANCHI || MJIDO_WORK(ICNT).KATAGAKI;    --町名番地方書
        r_WKRECORD001.CHOMEI_BANCHI_KATAGAK   := MJIDO_WORK(ICNT).CHOMEI || MJIDO_WORK(ICNT).BANCHI || MJIDO_WORK(ICNT).KATAGAKI;    --町名番地方書
        r_WKRECORD001.JIDO_ZOKUGARAMEI        := MJIDO_WORK(ICNT).ZOKUGARAMEI2;                      --児童との関係
        r_WKRECORD001.KYOIKU_KAI_MEI          := MJIDO_WORK(ICNT).KYOIKUKAI_MEI;                     --教育委員会名
        --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
        --r_WKRECORD001.HASSOBI                 := VHASOBI;                                            --発送日
        r_WKRECORD001.HASSOBI                 := TO_MULTI_BYTE(REPLACE(VHASOBI,' ',''));               --発送日
        --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
        r_WKRECORD001.SYUHATU_NO              := '';                                                 --収発番号
        r_WKRECORD001.KOIN_PATH               := VGYOMU ;                                            --公印パス
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        r_WKRECORD001.KOIN_SHORYAKU           := MJIDO_WORK(ICNT).KOIN_SHORYAKU;                     --公印（省略）
        r_WKRECORD001.KOIN_CHUSHAKU           := MJIDO_WORK(ICNT).KOIN_CHUSHAKU;                     --公印（注釈）
        r_WKRECORD001.TSUCHIBUN               := MJIDO_WORK(ICNT).TSUCHIBUN;                         --通知文
-- 2024/07/03 ZCZL.qinyue Add end
        r_WKRECORD001.KYOIKU_TEL              := MJIDO_WORK(ICNT).KYOIKU_TEL;                        --委員会電話番号
        --委員会郵便番号
        VYUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO,1,3) || '-' || SUBSTR(MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO,4);
        IF LENGTH(VYUBIN_NO) > 1 THEN
          r_WKRECORD001.KYOIKU_YUBIN_NO     := TRANSLATE(VYUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
        ELSE
          r_WKRECORD001.KYOIKU_YUBIN_NO     := MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO;
        END IF;
        r_WKRECORD001.KYOIKU_JUSHO            := MJIDO_WORK(ICNT).KYOIKU_JUSHO;                      --委員会住所
        r_WKRECORD001.HASSO_NO                := MJIDO_WORK(ICNT).SOFU_YUBIN_NOBC;                   --発送番号
        r_WKRECORD001.DATE1                   := MJIDO_WORK(ICNT).DATE1;                             --日付１
        r_WKRECORD001.DATE2                   := MJIDO_WORK(ICNT).DATE2;                             --日付２
        r_WKRECORD001.DATE3                   := MJIDO_WORK(ICNT).DATE3;                             --日付３
        r_WKRECORD001.DATE4                   := MJIDO_WORK(ICNT).DATE4;                             --日付４
        r_WKRECORD001.DATE5                   := MJIDO_WORK(ICNT).DATE5;                             --日付５
        r_WKRECORD001.KOMOKU1                 := MJIDO_WORK(ICNT).KOMOKU1;                           --項目１
        r_WKRECORD001.KOMOKU2                 := MJIDO_WORK(ICNT).KOMOKU2;                           --項目２
        r_WKRECORD001.KOMOKU3                 := MJIDO_WORK(ICNT).KOMOKU3;                           --項目３
        r_WKRECORD001.KOMOKU4                 := MJIDO_WORK(ICNT).KOMOKU4;                           --項目４
        r_WKRECORD001.KOMOKU5                 := MJIDO_WORK(ICNT).KOMOKU5;                           --項目５
        r_WKRECORD001.KOMOKU6                 := MJIDO_WORK(ICNT).KOMOKU6;                           --項目６
        r_WKRECORD001.KOMOKU7                 := MJIDO_WORK(ICNT).KOMOKU7;                           --項目７
        r_WKRECORD001.KOMOKU8                 := MJIDO_WORK(ICNT).KOMOKU8;                           --項目８
        r_WKRECORD001.KOMOKU9                 := MJIDO_WORK(ICNT).KOMOKU9;                           --項目９
        r_WKRECORD001.KOMOKU10                := MJIDO_WORK(ICNT).KOMOKU10;                          --項目１０
        r_WKRECORD001.DATE_MEI1               := MJIDO_WORK(ICNT).DATE_MEI1;                         --日付名称１
        r_WKRECORD001.DATE_MEI2               := MJIDO_WORK(ICNT).DATE_MEI2;                         --日付名称２
        r_WKRECORD001.DATE_MEI3               := MJIDO_WORK(ICNT).DATE_MEI3;                         --日付名称３
        r_WKRECORD001.DATE_MEI4               := MJIDO_WORK(ICNT).DATE_MEI4;                         --日付名称４
        r_WKRECORD001.DATE_MEI5               := MJIDO_WORK(ICNT).DATE_MEI5;                         --日付名称５
        r_WKRECORD001.KOMOKU_MEI1             := MJIDO_WORK(ICNT).KOMOKU_MEI1;                       --項目名称１
        r_WKRECORD001.KOMOKU_MEI2             := MJIDO_WORK(ICNT).KOMOKU_MEI2;                       --項目名称２
        r_WKRECORD001.KOMOKU_MEI3             := MJIDO_WORK(ICNT).KOMOKU_MEI3;                       --項目名称３
        r_WKRECORD001.KOMOKU_MEI4             := MJIDO_WORK(ICNT).KOMOKU_MEI4;                       --項目名称４
        r_WKRECORD001.KOMOKU_MEI5             := MJIDO_WORK(ICNT).KOMOKU_MEI5;                       --項目名称５
        r_WKRECORD001.KOMOKU_MEI6             := MJIDO_WORK(ICNT).KOMOKU_MEI6;                       --項目名称６
        r_WKRECORD001.KOMOKU_MEI7             := MJIDO_WORK(ICNT).KOMOKU_MEI7;                       --項目名称７
        r_WKRECORD001.KOMOKU_MEI8             := MJIDO_WORK(ICNT).KOMOKU_MEI8;                       --項目名称８
        r_WKRECORD001.KOMOKU_MEI9             := MJIDO_WORK(ICNT).KOMOKU_MEI9;                       --項目名称９
        r_WKRECORD001.KOMOKU_MEI10            := MJIDO_WORK(ICNT).KOMOKU_MEI10;                      --項目名称１０
        r_WKRECORD001.GAKKO_CD                := MJIDO_WORK(ICNT).GAKOKU_CD;                         --学校コード
        r_WKRECORD001.NINSHOSHAKATAGAKI       := VNINSHOSHAKATAGAKI;                                 --認証肩書
--  2024/08/20 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00018対応
--        r_WKRECORD001.NINSHOSHAMEI            := VNINSHOSHAMEI;                                      --認証者名
        r_WKRECORD001.NINSHOSHAMEI            := o_vSHIMEI;                                      --認証者名

        --児童郵便番号
        IF LENGTH(MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO) > 0 THEN
          VYUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO,1,3) || '-' || SUBSTR(MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO,4);
          VYUBIN_NO := TRANSLATE(VYUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
          r_WKRECORD001.JIDO_YUBIN_NO         := VYUBIN_NO;
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
          VYUBIN_NO := GAAPK0030.FDVJUSHO('GKB', MJIDO_WORK(ICNT).JIDO_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, MJIDO_WORK(ICNT).JIDO_YUBIN_NO, g_CTLPRM, 2);
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00074対応
--           IF g_OPTSHINENSOCHI = 0 AND g_CTLPRM = 1 THEN
          IF g_OPTSHINENSOCHI = 1 AND g_CTLPRM = 1 THEN
            r_WKRECORD001.JIDO_YUBIN_NO       := NULL;
          END IF;
-- 2024/07/03 ZCZL.qinyue Add end
        ELSE
          r_WKRECORD001.JIDO_YUBIN_NO         := MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO;
        END IF;
        r_WKRECORD001.JIDO_SOFU_YUBIN_NOBC    := MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NOBC;              --児童カスタマバーコード
        r_WKRECORD001.JIDO_CHOMEI_BANCHI      := MJIDO_WORK(ICNT).JIDO_SOFU_CHOMEI || MJIDO_WORK(ICNT).JIDO_SOFU_BANCHI;    --児童町名番地
        r_WKRECORD001.JIDO_KATAGAKI           := MJIDO_WORK(ICNT).JIDO_SOFU_KATAGAKI;                --児童方書
        IF o_ATENAPRM(1) IN (1,3) THEN
          --郵便番号
           IF LENGTH(MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO) > 0 THEN
             VYUBIN_NO1 := SUBSTR(MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO,4);
             VYUBIN_NO1 := TRANSLATE(VYUBIN_NO1, '1234567890-', '１２３４５６７８９０－' );
             r_WKRECORD001.YUBIN_NO            := VYUBIN_NO1;
          ELSE
            r_WKRECORD001.YUBIN_NO            := MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO;
          END IF;
          r_WKRECORD001.BC_NO                 := MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NOBC;              --カスタマバーコード
          r_WKRECORD001.CHOMEI_BANCHI         := MJIDO_WORK(ICNT).JIDO_SOFU_CHOMEI || MJIDO_WORK(ICNT).JIDO_SOFU_BANCHI;    --町名番地
          r_WKRECORD001.KATAGAKI              := MJIDO_WORK(ICNT).JIDO_SOFU_KATAGAKI;                --方書
        ELSE
          --郵便番号
          IF LENGTH(MJIDO_WORK(ICNT).SOFU_YUBIN_NO) > 0 THEN
            VYUBIN_NO1 := SUBSTR(MJIDO_WORK(ICNT).SOFU_YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNT).SOFU_YUBIN_NO,4);
            VYUBIN_NO1 := TRANSLATE(VYUBIN_NO1, '1234567890-', '１２３４５６７８９０－' );
            r_WKRECORD001.YUBIN_NO            := VYUBIN_NO1;
          ELSE
            r_WKRECORD001.YUBIN_NO            := MJIDO_WORK(ICNT).SOFU_YUBIN_NO;
          END IF;
          r_WKRECORD001.BC_NO                 := MJIDO_WORK(ICNT).SOFU_YUBIN_NOBC;                   --カスタマバーコード
          r_WKRECORD001.CHOMEI_BANCHI         := MJIDO_WORK(ICNT).SOFU_CHOMEI || MJIDO_WORK(ICNT).SOFU_BANCHI;    --町名番地
          r_WKRECORD001.KATAGAKI              := MJIDO_WORK(ICNT).SOFU_KATAGAKI;                     --方書
        END IF;
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        VYUBIN_NO1 := GAAPK0030.FDVJUSHO('GKB', MJIDO_WORK(ICNT).JIDO_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, r_WKRECORD001.YUBIN_NO, g_CTLPRM, 2);
--  2024/09/29 ZCZL.yangshuai Update 0.3.000.003:仕様変更 IT_GKB_00074対応
--         IF g_OPTSHINENSOCHI = 0 AND g_CTLPRM = 1 THEN
        IF g_OPTSHINENSOCHI = 1 AND g_CTLPRM = 1 THEN
               r_WKRECORD001.YUBIN_NO            := NULL;
        END IF;
-- 2024/07/03 ZCZL.qinyue Update end
        r_WKRECORD001.KYOIKU_YAKUSHOKU_MEI    := MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI;              --委員会役職名
        r_WKRECORD001.KYOIKU_SHUCHO_MEI       := MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI;                --委員会首長名
        r_WKRECORD001.KYOIKU_RITSU_MEI        := MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI;                  --委員会立区名
        r_WKRECORD001.KYOIKU_TEL_NAISEN       := MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN;                 --委員会内線
        --表示帳票連番
        IF NRENBAN = 0 THEN
          r_WKRECORD001.HYOJI_CHOHYO_NO       := MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO;
        ELSE
          r_WKRECORD001.HYOJI_CHOHYO_NO       := MJIDO_WORK(ICNT).RENBAN;
        END IF;
        KYOIKUKAI_RENRAKUSAKI := GET_EQRENRAKUSAKI(2, MJIDO_WORK(ICNT).KYOIKUKAI_MEI, MJIDO_WORK(ICNT).KYOIKU_TEL, MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN);
        r_WKRECORD001.KYOIKU_RENRAKUSAKI      := KYOIKUKAI_RENRAKUSAKI;                              --教育委員会連絡先
-- 2024/07/03 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--         r_WKRECORD001.BREAK_NO                := MJIDO_WORK(ICNT).KAIPEJI_CD;                     --改ページキー
        r_WKRECORD001.YOSHIKI_NO              := MJIDO_WORK(ICNT).YOSHIKI_NO;                        --様式番号
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
        r_WKRECORD001.YOSHIKI_NO  := KKAPK0010.FALPZENHANHENKAN(r_WKRECORD001.YOSHIKI_NO ,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
        r_WKRECORD001.BREAK_NO                := NULL;                                               --改ページキー
-- 2024/07/03 ZCZL.qinyue Update end
        r_WKRECORD001.WSNUM                   := g_sWSNUM;                                           --端末番号
        r_WKRECORD001.BATCHKBN                := c_BATCH;                                            --即時バッチ区分
        r_WKRECORD001.JOBNUM                  := g_nJOBNUM;                                          --ジョブNO
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        r_WKRECORD001.KOJIN_NO                := MJIDO_WORK(ICNT).JIDO_KOJIN_NO;                     --児童生徒宛名番号
        r_WKRECORD001.HOGOSYA_KOJIN_NO        := MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO;                  --保護者宛名番号
-- 2024/07/03 ZCZL.qinyue Add end

        INSERT INTO GKBWL060R001 VALUES r_WKRECORD001;
        --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
        -- 文書番号加算
          IF rBUNNUMEDITKEKA2.NUMUMUFLG = 0 AND (rBUNNUMSRCINF2.NUMINCTYPE = 1 OR rBUNNUMSRCINF2.NUMINCTYPE = 2) THEN
             KKAPK0040.SBunNumIc(rBUNNUMSRCINF2, rBUNNUMEDITKEKA2);
                END IF;
                --文書番号保管を追加する
                IF rBUNNUMEDITKEKA2.NUMUMUFLG = 0 THEN
                  g_rHOKANBUNNUM(nCNT).nKOJINNUM := CRATENA_WORK.KOJIN_NO;
                  g_rHOKANBUNNUM(nCNT).sBUNNUM := rBUNNUMEDITKEKA2.NUM;
                END IF;
                g_vBUNNUM_KENKOSYO := rBUNNUMEDITKEKA2.NUM;
        --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
      END LOOP;

        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(ICNT_1, '出力　'|| '健康診断結果通知書CSV', 2);

      -- 終了
      RETURN FRET;
    EXCEPTION
      WHEN OTHERS THEN
        FRET := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        N_SQL_CODE := SQLCODE;
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        -- 処理ログの出力
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE1', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE1;
    --------------------------------------------------------------------------------
    --  機能概要      : 健康診断結果通知書発送者一覧表ＣＳＶファイルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 ,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE2 RETURN NUMBER IS
      FRET                PLS_INTEGER;                -- 戻り値
      ICNT                BINARY_INTEGER;             -- カウント
      IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
      IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
      VYUBIN_NO           NVARCHAR2(60);    --郵便番号編集用
      ICNT_1              BINARY_INTEGER := 0;             -- カウント
-- 2024/07/24 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
      iHAKKOBI            BINARY_INTEGER;             -- 基準日(西暦変換)
-- 2024/07/24 ZCZL.qinyue Add end
-- 2024/07/24 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
      --r_WKRECORD002       GKBWL150R002%ROWTYPE;
      r_WKRECORD002       GKBWL130R012%ROWTYPE;
      --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
      nCNT                NUMBER :=0;
      --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
    BEGIN
      FRET := c_ISUCCESS;                  -- 正常終了
      IMAX := MJIDO_WORK.LAST;             -- ワーク領域の件数の最大値
      IMIN := MJIDO_WORK.FIRST;            -- ワーク領域の件数の最小値

      -- 取得した件数分繰り返す
      FOR ICNT IN IMIN..IMAX LOOP
        ICNT_1 := ICNT_1 + 1;
-- 2024/07/24 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
        r_WKRECORD002 := NULL;
        r_WKRECORD002.NO                      := ICNT_1;                                             --ソート順
--       r_WKRECORD002.NENDO                   := MJIDO_WORK(ICNT).NENDO;                             --年度
--        r_WKRECORD002.KAIPAGE_CD              := MJIDO_WORK(ICNT).KAIPEJI_CD;                        --改頁コード
--        r_WKRECORD002.KAIPAGE_MEI             := MJIDO_WORK(ICNT).KAIPEJI;                           --改頁名

        r_WKRECORD002.SAKUSEI_YMD             := MJIDO_WORK(ICNT).SAKUSEIBI;                         --作成日
        r_WKRECORD002.TITLE                   := '健康診断結果通知発送者一覧表';                       --タイトル
--        r_WKRECORD002.RENBAN                  := MJIDO_WORK(ICNT).RENBAN;                            --連番

        --発行日(西暦変換)
        iHAKKOBI := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN7);
        --発行年月日
--  2025/07/10 CTC.GL UPDATE Start 1.0.010.001:GKB_QA17697対応
        --r_WKRECORD002.HAKKO_YMD  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(iHAKKOBI,'YYYY/MM/DD'),'YYYY/MM/DD'), 12);
        r_WKRECORD002.HAKKO_YMD  := VHASOBI;
--  2025/07/10 CTC.GL UPDATE End

        r_WKRECORD002.SOFUSAKI_SHIMEI         := MJIDO_WORK(ICNT).ATESAKI_JODAN;                     --送付先氏名
        --  2025/05/22 CTC.SONGSHIHAO UPDATE 1.0.006.000:GKB_QA14765_GKB発送者一覧表の送付先住所が文字切れ対応 START
        --r_WKRECORD002.SOFUSAKI_YUBIN_NO       := MJIDO_WORK(ICNT).YUBIN_NO;                          --送付先郵便番号
        IF MJIDO_WORK(ICNT).YUBIN_NO IS NOT NULL THEN
        r_WKRECORD002.SOFUSAKI_YUBIN_NO       := SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO,1,3) || '-' || SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO,4);
        END IF;
        --r_WKRECORD002.SOFUSAKI_JUSHO          := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;                   --送付先住所
        r_WKRECORD002.SOFUSAKI_JUSHO          := MJIDO_WORK(ICNT).KON_JUSHO_JODAN || MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;                  --送付先住所
        --  2025/05/22 CTC.SONGSHIHAO UPDATE 1.0.006.000:GKB_QA14765_GKB発送者一覧表の送付先住所が文字切れ対応 END
        r_WKRECORD002.JIDO_SHIMEI_KANA        := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;                  --児童生徒氏名カナ
        r_WKRECORD002.JIDO_SHIMEI_KANJI       := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;                 --児童生徒氏名漢字

--        r_WKRECORD002.SHIMEI_KANA             := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;                  --氏名カナ
--        r_WKRECORD002.SHIMEI                  := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;                 --氏名
        r_WKRECORD002.SEINENGAPI              := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;                  --生年月日
        r_WKRECORD002.SEIBETSU                := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;                    --性別
        r_WKRECORD002.JIDO_SHIENSOCHI         := NULL;                                               --児童生徒_支援措置
        r_WKRECORD002.HOGOSHA_SHIMEI_KANA     := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;               --保護者氏名カナ
        r_WKRECORD002.HOGOSHA_SHIMEI_KANJI    := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;              --保護者氏名漢字
        r_WKRECORD002.HOGOSHA_ZOKUGARA        := MJIDO_WORK(ICNT).ZOKUGARAMEI2;                      --児童生徒との関係
        r_WKRECORD002.HOGOSHA_SHIENSOCHI      := NULL;                                               --保護者_支援措置
--        r_WKRECORD002.HOGOSHA_SHIMEI_JODAN    := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN;              --保護者氏名上段
--        r_WKRECORD002.HOGOSHA_SHIMEI_GEDAN    := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;              --保護者氏名下段
--        r_WKRECORD002.JUSHO_JODAN             := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;                   --住所上段
--        r_WKRECORD002.JUSHO_GEDAN             := MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;                   --住所下段
--        --行政区名
--        IF NHASSOUKBN = 1 THEN
--          r_WKRECORD002.GYOSEIKU_MEI          := MJIDO_WORK(ICNT).YOCHIENMEI;
--        ELSE
--          r_WKRECORD002.GYOSEIKU_MEI          := MJIDO_WORK(ICNT).GYOSEIKUMEI;
--        END IF;
--        r_WKRECORD002.GAKKO_MEI               := MJIDO_WORK(ICNT).GAKOKUMEI;                         --学校名
        r_WKRECORD002.GAKKO_MEI               := MJIDO_WORK(ICNT).GAKKO_MEI;                         --学校名
        r_WKRECORD002.KENSU                   := MJIDO_WORK.COUNT;                                   --件数
        r_WKRECORD002.GAKKO_CD                := MJIDO_WORK(ICNT).GAKKO_CD;                          --学校コード
--        r_WKRECORD002.GYOSEIKU                := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;                   --行政区
--        --郵便
--        VYUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).SOFU_YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNT).SOFU_YUBIN_NO,4);
--        IF LENGTH(VYUBIN_NO) > 1 THEN
--          r_WKRECORD002.YUBIN_NO              := VYUBIN_NO;
--        ELSE
--          r_WKRECORD002.YUBIN_NO              := MJIDO_WORK(ICNT).SOFU_YUBIN_NO;
--        END IF;
--        r_WKRECORD002.CHOMEI_BANCHI           := MJIDO_WORK(ICNT).SOFU_CHOMEI || MJIDO_WORK(ICNT).SOFU_BANCHI; --町名番地
--        r_WKRECORD002.KATAGAKI                := MJIDO_WORK(ICNT).SOFU_KATAGAKI;                     --かたがき
--        --保護者氏名上下様
--        IF LENGTH(MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN) > 0 OR
--           LENGTH(MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN) > 0 THEN
--          r_WKRECORD002.HOGOSHA_SHIMEI_JGSAMA := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN || MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN || '　様';
--        ELSE
--          r_WKRECORD002.HOGOSHA_SHIMEI_JGSAMA := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN || MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;
--        END IF;
--        r_WKRECORD002.KANJI_SEINENGAPI        := MJIDO_WORK(ICNT).KANJI_SEINENGAPI;                  --漢字生年月日
--        r_WKRECORD002.NENREI                  := MJIDO_WORK(ICNT).NENREI;                            --年齢
--        r_WKRECORD002.JIDO_JUSHO              := MJIDO_WORK(ICNT).JIDO_SOFU_CHOMEI || MJIDO_WORK(ICNT).JIDO_SOFU_BANCHI || MJIDO_WORK(ICNT).JIDO_SOFU_KATAGAKI;    --児童現住所
--        r_WKRECORD002.HOGOSHA_SHIMEI_KANA     := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;               --保護者氏名カナ
--        r_WKRECORD002.HOGOSHA_SHIMEI_KANJI    := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;              --保護者氏名漢字
--        r_WKRECORD002.CHOMEI_BANCHI_KATAGAKI  := MJIDO_WORK(ICNT).SOFU_CHOMEI || MJIDO_WORK(ICNT).SOFU_BANCHI || MJIDO_WORK(ICNT).SOFU_KATAGAKI;    --町名番地かたがき
--        r_WKRECORD002.ZOKUGARA                := MJIDO_WORK(ICNT).ZOKUGARAMEI2;                      --続柄
--        --児童郵便番号
--        IF LENGTH(MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO) > 0 THEN
--          VYUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO,1,3)||'-'||SUBSTR(MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO,4);
--          VYUBIN_NO := TRANSLATE(VYUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
--          r_WKRECORD002.JIDO_YUBIN_NO         := VYUBIN_NO;
--        ELSE
--          r_WKRECORD002.JIDO_YUBIN_NO         := MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NO;
--        END IF;
--        r_WKRECORD002.JIDO_SOFU_YUBIN_NOBC    := MJIDO_WORK(ICNT).JIDO_SOFU_YUBIN_NOBC;              --児童カスタマバーコード
--        r_WKRECORD002.JIDO_ZOKUGARAMEI        := MJIDO_WORK(ICNT).ZOKUGARAMEI1;                      --児童との関係
--        r_WKRECORD002.GAKKO_CD                := MJIDO_WORK(ICNT).GAKOKU_CD;                         --学校コード
--        r_WKRECORD002.KIJUNBI                 := MJIDO_WORK(ICNT).KIJUN_BI;                          --基準日
--        --No
--        IF NRENBAN = 0 THEN
--          r_WKRECORD002.NUM                   := MJIDO_WORK(ICNT).CHOHYO_NO;
--        ELSE
--         r_WKRECORD002.NUM                   := MJIDO_WORK(ICNT).RENBAN;
--        END IF;
-- 2024/07/24 ZCZL.qinyue Update end
-- 2024/07/05 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        --文書番号
        --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
        /*
        FOR i in 1..g_rHOKANBUNNUM.COUNT LOOP
          --変数.文書番号保管に格納している宛名番号と学齢簿カーソル.宛名番号を比較
          IF g_rHOKANBUNNUM(i).nKOJINNUM = MJIDO_WORK(ICNT).JIDO_KOJIN_NO THEN
            --該当するレコードの文書番号をセットする
            r_WKRECORD002.BUNSHO_NO := g_rHOKANBUNNUM(i).sBUNNUM;
            EXIT;
          END IF;
        END LOOP;
        */
        IF rBUNNUMEDITKEKA2.NUMUMUFLG = 0 THEN
            r_WKRECORD002.BUNSHO_NO            := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(g_vBUNNUM_KENKOHYO, 0),' ',''),'　','');
        ELSE
            r_WKRECORD002.BUNSHO_NO            := NULL;
        END IF;
        --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
        r_WKRECORD002.JIDO_SHIMEI_LABEL     :=  '児童生徒氏名';
        r_WKRECORD002.HOGOSHA_SHIMEI_LABEL  :=  '保護者氏名';
        r_WKRECORD002.GAKKO_GYOSEIKU_LABEL  :=  '学校';
        IF MJIDO_WORK(ICNT).JINKAKU_KBN = 0 THEN
          r_WKRECORD002.JINKAKU_KBN := NULL;
        END IF;
        IF MJIDO_WORK(ICNT).JINKAKU_KBN = 1 THEN
          r_WKRECORD002.JINKAKU_KBN :=  '＊';
        END IF;
-- 2024/07/05 ZCZL.qinyue Add end

-- 2024/07/24 ZCZL.qinyue Delete 0.3.000.000:新WizLIFE2次開発
--        r_WKRECORD002.JINKAKU_KBN             := MJIDO_WORK(ICNT).JINKAKU_KBN;                       --人格区分
        r_WKRECORD002.BREAK_NO                := NULL;                                               --改ページキー
        r_WKRECORD002.WSNUM                   := g_sWSNUM;                                           --端末番号
        r_WKRECORD002.BATCHKBN                := c_BATCH;                                            --即時バッチ区分
        r_WKRECORD002.JOBNUM                  := g_nJOBNUM;                                          --ジョブNO

-- 2024/07/24 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
--        INSERT INTO GKBWL150R002 VALUES r_WKRECORD002;
        INSERT INTO GKBWL130R012 VALUES r_WKRECORD002;
        --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
        IF rBUNNUMEDITKEKA1.NUMUMUFLG = 0 AND (rBUNNUMSRCINF1.NUMINCTYPE = 1 OR rBUNNUMSRCINF1.NUMINCTYPE = 2) THEN
            KKAPK0040.SBunNumIc(rBUNNUMSRCINF1, rBUNNUMEDITKEKA1);
                END IF;
                --文書番号保管を追加する
                IF rBUNNUMEDITKEKA1.NUMUMUFLG = 0 THEN
                  g_rHOKANBUNNUM(nCNT).nKOJINNUM := CRATENA_WORK.KOJIN_NO;
                  g_rHOKANBUNNUM(nCNT).sBUNNUM := rBUNNUMEDITKEKA1.NUM;
                END IF;
                g_vBUNNUM_KENKOHYO := rBUNNUMEDITKEKA1.NUM;
        --  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End

      END LOOP;
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(ICNT_1, '出力　'|| '健康診断結果通知書発送者一覧表CSV', 2);

      -- 終了
      RETURN FRET;
    EXCEPTION
      WHEN OTHERS THEN
        FRET := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        N_SQL_CODE := SQLCODE;
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        -- 処理ログの出力
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE2', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE2;
    --------------------------------------------------------------------------------
    --  機能概要      : 健康診断結果票ＣＳＶファイルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0 ,その他 1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE3 RETURN NUMBER IS
      FRET                PLS_INTEGER;                -- 戻り値
      ICNT                BINARY_INTEGER;             -- カウント
      IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
      IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
      VYUBIN_NO           NVARCHAR2(60);              -- 郵便番号編集用
      ICNT_1              BINARY_INTEGER := 0;        -- カウント
      VJUSHO              NVARCHAR2(150);
      r_WKRECORD003       GKBWL020R001%ROWTYPE;

    BEGIN
      FRET := c_ISUCCESS;                  -- 正常終了
      IMAX := MJIDO_WORK.LAST;             -- ワーク領域の件数の最大値
      IMIN := MJIDO_WORK.FIRST;            -- ワーク領域の件数の最小値

      -- 取得した件数分繰り返す
      FOR ICNT IN IMIN..IMAX LOOP
        ICNT_1 := ICNT_1 + 1;
        r_WKRECORD003 := NULL;
        r_WKRECORD003.NO                      := ICNT_1;                                             --ソート順
        r_WKRECORD003.NENDO                   := MJIDO_WORK(ICNT).NENDO;                             --年度
        r_WKRECORD003.KAIPAGE_CD              := MJIDO_WORK(ICNT).KAIPEJI_CD;                        --改頁コード
        r_WKRECORD003.KAIPAGE                 := MJIDO_WORK(ICNT).KAIPEJI;                           --改頁
        r_WKRECORD003.SAKUSEIBI               := MJIDO_WORK(ICNT).SAKUSEIBI;                         --作成日
        r_WKRECORD003.RENBAN                  := MJIDO_WORK(ICNT).RENBAN;                            --連番
        r_WKRECORD003.JIDO_SHIMEI_KANA        := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;                  --児童氏名カナ
        r_WKRECORD003.JIDO_SHIMEI_KANJI       := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;                 --児童氏名漢字
        r_WKRECORD003.JISSHI_BI               := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;                  --実施日
        r_WKRECORD003.JIDO_HYOJI_SEIBETSU     := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;                    --児童性別
        r_WKRECORD003.HOGOSHA_SHIMEI_JODAN    := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN;              --保護者氏名上段
        r_WKRECORD003.HOGOSHA_SHIMEI_GEDAN    := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;              --保護者氏名下段
        r_WKRECORD003.JUSHO_JODAN             := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;                   --住所上
        r_WKRECORD003.JUSHO_GEDAN             := MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;                   --住所下
        r_WKRECORD003.GYOSEIKU_MEI            := MJIDO_WORK(ICNT).GYOSEIKUMEI;                       --行政区名
        r_WKRECORD003.GAKKOKU_MEI             := MJIDO_WORK(ICNT).GAKOKUMEI;                         --学校区名
        r_WKRECORD003.SANTEIDANTAI_MEI        := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;                   --算定団体名
        r_WKRECORD003.YUBIN_NO                := MJIDO_WORK(ICNT).YUBIN_NO;                          --郵便番号
        r_WKRECORD003.CHOMEI_BANCHI           := MJIDO_WORK(ICNT).CHOMEI||MJIDO_WORK(ICNT).BANCHI;   --町名番地
        r_WKRECORD003.KATAGAKI                := MJIDO_WORK(ICNT).KATAGAKI;                          --かたがき
        r_WKRECORD003.HOGOSHA_SHIMEI_SAMA     := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN || MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN || ' 様';    --保護者氏名様
        r_WKRECORD003.KANJI_SEINENGAPI        := MJIDO_WORK(ICNT).KANJI_SEINENGAPI;                  --漢字生年月日
        r_WKRECORD003.JIDO_NENREI             := MJIDO_WORK(ICNT).NENREI;                            --児童年齢
        --児童住所
        VJUSHO := '';
        VJUSHO := GAAPK0010.FADDRESSEDIT( 1, '', MJIDO_WORK(ICNT).JIDO_CHOMEI, MJIDO_WORK(ICNT).JIDO_BANCHI, MJIDO_WORK(ICNT).JIDO_KATAGAKI, '');
        r_WKRECORD003.JIDO_JUSHO              := VJUSHO;                                             --児童住所
        r_WKRECORD003.HOGOSHA_SHIMEI_KANA     := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;               --保護者氏名カナ
        r_WKRECORD003.HOGOSHA_SHIMEI_KANJI    := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;              --保護者氏名漢字
        --保護者住所
        VJUSHO := '';
        VJUSHO := GAAPK0010.FADDRESSEDIT( 1, '', MJIDO_WORK(ICNT).CHOMEI, MJIDO_WORK(ICNT).BANCHI, MJIDO_WORK(ICNT).KATAGAKI, '');
        r_WKRECORD003.HOGOSHA_JUSHO           := VJUSHO;
        r_WKRECORD003.ZOKUGARA                := MJIDO_WORK(ICNT).ZOKUGARAMEI2;                      --続柄
        r_WKRECORD003.KYOIKU_KAI_MEI          := MJIDO_WORK(ICNT).KYOIKUKAI_MEI;                     --教育委員会名
        r_WKRECORD003.HASSOBI                 := MJIDO_WORK(ICNT).KIJUN_BI;                          --発送日
        r_WKRECORD003.DATE1                   := MJIDO_WORK(ICNT).DATE1;                             --日付１
        r_WKRECORD003.BC_NO                   := MJIDO_WORK(ICNT).GAKOKU_CD;                         --カスタマバーコード
        r_WKRECORD003.TANTO_YAKUSHOKU_MEI     := MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI;              --担当役職名
        r_WKRECORD003.TANTO_SHUTHOU_MEI       := MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI;                --担当首長名
        r_WKRECORD003.RITSU_MEI               := MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI;                  --担当会立名
        r_WKRECORD003.TANTO_YUBIN_NO          := MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO;                   --担当郵便番号
        r_WKRECORD003.TANTO_JUSHO             := MJIDO_WORK(ICNT).KYOIKU_JUSHO;                      --担当住所
        r_WKRECORD003.TANTO_TEL               := MJIDO_WORK(ICNT).KYOIKU_TEL;                        --担当電話番号
        r_WKRECORD003.TANTO_TEL_NAISEN        := MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN;                 --担当内線番号
        r_WKRECORD003.DATE2                   := MJIDO_WORK(ICNT).DATE2;                             --日付２
        r_WKRECORD003.DATE3                   := MJIDO_WORK(ICNT).DATE3;                             --日付３
        r_WKRECORD003.DATE4                   := MJIDO_WORK(ICNT).DATE4;                             --日付４
        r_WKRECORD003.DATE5                   := MJIDO_WORK(ICNT).DATE5;                             --日付５
        r_WKRECORD003.KOMOKU1                 := MJIDO_WORK(ICNT).KOMOKU1;                           --項目１
        r_WKRECORD003.KOMOKU2                 := MJIDO_WORK(ICNT).KOMOKU2;                           --項目２
        r_WKRECORD003.KOMOKU3                 := MJIDO_WORK(ICNT).KOMOKU3;                           --項目３
        r_WKRECORD003.KOMOKU4                 := MJIDO_WORK(ICNT).KOMOKU4;                           --項目４
        r_WKRECORD003.ISHI_SHOKEN             := MJIDO_WORK(ICNT).KOMOKU5;                           --担当医師所見
        r_WKRECORD003.SHIKA_ISHI_SHOKEN       := MJIDO_WORK(ICNT).KOMOKU6;                           --担当歯科医師所見
        r_WKRECORD003.KOMOKU7                 := MJIDO_WORK(ICNT).KOMOKU7;                           --項目７
        r_WKRECORD003.KOMOKU8                 := MJIDO_WORK(ICNT).KOMOKU8;                           --項目８
        r_WKRECORD003.KOMOKU9                 := MJIDO_WORK(ICNT).KOMOKU9;                           --項目９
        r_WKRECORD003.KOMOKU10                := MJIDO_WORK(ICNT).KOMOKU10;                          --項目１０
        r_WKRECORD003.DATE_MEI1               := MJIDO_WORK(ICNT).DATE_MEI1;                         --日付名１
        r_WKRECORD003.DATE_MEI2               := MJIDO_WORK(ICNT).DATE_MEI2;                         --日付名２
        r_WKRECORD003.DATE_MEI3               := MJIDO_WORK(ICNT).DATE_MEI3;                         --日付名３
        r_WKRECORD003.DATE_MEI4               := MJIDO_WORK(ICNT).DATE_MEI4;                         --日付名４
        r_WKRECORD003.DATE_MEI5               := MJIDO_WORK(ICNT).DATE_MEI5;                         --日付名５
        r_WKRECORD003.KOMOKU_MEI1             := MJIDO_WORK(ICNT).KOMOKU_MEI1;                       --項目名１
        r_WKRECORD003.KOMOKU_MEI2             := MJIDO_WORK(ICNT).KOMOKU_MEI2;                       --項目名２
        r_WKRECORD003.KOMOKU_MEI3             := MJIDO_WORK(ICNT).KOMOKU_MEI3;                       --項目名３
        r_WKRECORD003.KOMOKU_MEI4             := MJIDO_WORK(ICNT).KOMOKU_MEI4;                       --項目名４
        r_WKRECORD003.KOMOKU_MEI5             := MJIDO_WORK(ICNT).KOMOKU_MEI5;                       --項目名５
        r_WKRECORD003.KOMOKU_MEI6             := MJIDO_WORK(ICNT).KOMOKU_MEI6;                       --項目名６
        r_WKRECORD003.KOMOKU_MEI7             := MJIDO_WORK(ICNT).KOMOKU_MEI7;                       --項目名７
        r_WKRECORD003.KOMOKU_MEI8             := MJIDO_WORK(ICNT).KOMOKU_MEI8;                       --項目名８
        r_WKRECORD003.KOMOKU_MEI9             := MJIDO_WORK(ICNT).KOMOKU_MEI9;                       --項目名９
        r_WKRECORD003.KOMOKU_MEI10            := MJIDO_WORK(ICNT).KOMOKU_MEI10;                      --項目名１０
        r_WKRECORD003.GAKKO_CD                := MJIDO_WORK(ICNT).GAKOKU_CD;                         --学校コード
        --表示帳票連番
        IF NRENBAN = 0 THEN
          r_WKRECORD003.HYOJI_CHOHYO_NO       := MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO;
        ELSE
          r_WKRECORD003.HYOJI_CHOHYO_NO       := MJIDO_WORK(ICNT).RENBAN;
        END IF;
        --教育委員会連絡先
        KYOIKUKAI_RENRAKUSAKI := GET_EQRENRAKUSAKI(1, MJIDO_WORK(ICNT).KYOIKUKAI_MEI, MJIDO_WORK(ICNT).KYOIKU_TEL, MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN);
        r_WKRECORD003.KYOIKU_RENRAKUSAKI      := KYOIKUKAI_RENRAKUSAKI;
        r_WKRECORD003.BREAK_NO                := MJIDO_WORK(ICNT).KAIPEJI_CD;                        --改ページキー
        r_WKRECORD003.WSNUM                   := g_sWSNUM;                                           --端末番号
        r_WKRECORD003.BATCHKBN                := c_BATCH;                                            --即時バッチ区分
        r_WKRECORD003.JOBNUM                  := g_nJOBNUM;                                          --ジョブNO
        --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 Start
        r_WKRECORD003.YOSHIKI_NO              := MJIDO_WORK(ICNT).YOSHIKI_NO;                        --様式番号
        --  2025/01/13 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:IT_GKB_10136~IT_GKB_10141対応 End
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
        r_WKRECORD003.YOSHIKI_NO  := KKAPK0010.FALPZENHANHENKAN(r_WKRECORD003.YOSHIKI_NO ,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
        INSERT INTO GKBWL020R001 VALUES r_WKRECORD003;
      END LOOP;
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(ICNT_1, '出力　'|| '健康診断結果診断票CSV', 2);

      -- 終了
      RETURN FRET;
    EXCEPTION
      WHEN OTHERS THEN
        FRET := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        N_SQL_CODE := SQLCODE;
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        -- 処理ログの出力
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE3', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE3;
    --------------------------------------------------------
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        ERR              EXCEPTION;
        o_nDAIRIKBN      NVARCHAR2(1000);
        o_vKATAGAKI1     NVARCHAR2(1000);
        o_vKATAGAKI2     NVARCHAR2(1000);
--  2024/08/20 ZCZL.WANGMING DELETE 0.3.000.001:IT_GKB_00018対応
--        o_vSHIMEI        NVARCHAR2(1000);
        o_vKOINFILENAME  NVARCHAR2(1000);
        nDUMMY           NUMBER;
        vDUMMY           NVARCHAR2(100);
--  2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE２次開発
        nRTN             NUMBER;  --戻り値
        aPRM             A_CONS_PRM;
        nCNT           NUMBER;
--  2024/07/03 ZCZL.qinyue Add end
      BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

--  2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE２次開発
--  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 Start
/*
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00426対応
        IF g_rJSTP.CHOHYOID = 'GKB060R001' THEN
          --文書番号を取得する
          bRTN := KKBPK5551.FJBNSGet(g_nJOBNUM, g_rJSTP.STEPSEQ, g_rBUNNUMSRCINF);
          IF NOT bRTN THEN
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || '初期処理', 1, '', '', '共通関数(バッチジョブ文書番号情報入力)(KKBPK5551.FJBNSGet)を行った際にエラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
          END IF;
           --書番号編集結果内部ﾜｰｸを取得する
          g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00426対応
        END IF;
        */
        --文書番号を取得する
        IF g_rJSTP.CHOHYOID = 'GKB060R001' THEN
          bRTN := KKBPK5551.FJBNSGet(g_nJOBNUM, g_rJSTP.STEPSEQ, rBUNNUMSRCINF1);
          IF NOT bRTN THEN
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INIT', 1, '', '', '共通関数(バッチジョブ文書番号情報入力)(KKBPK5551.FJBNSGet)を行った際にエラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
          END IF;

          bRTN := KKBPK5551.FJBNSGet(g_nJOBNUM, g_rJSTP.STEPSEQ, rBUNNUMSRCINF2);
          IF NOT bRTN THEN
            bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INIT', 1, '', '', '共通関数(バッチジョブ文書番号情報入力)(KKBPK5551.FJBNSGet)を行った際にエラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
          END IF;
         --文書番号編集結果
          rBUNNUMEDITKEKA1 := rBUNNUMSRCINF1.UOUT;
          rBUNNUMEDITKEKA2 := rBUNNUMSRCINF2.UOUT;
          --文書番号_発送者一覧
          g_vBUNNUM_KENKOSYO := rBUNNUMEDITKEKA1.NUM;
          --文書番号_健康診断結果通知書
          g_vBUNNUM_KENKOHYO := rBUNNUMEDITKEKA2.NUM;
        END IF;
--  2025/01/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:IT_GKB_10250対応 End
        g_nTSUCHICNT := 0;
        g_nCSVCNT    := 0;
        g_nTAISIXYOUCNT := 0;
        nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aPRM);
        IF nRTN = 0 THEN
          FOR i IN 1..aPRM.COUNT LOOP
            IF aPRM(i) = 'GKB060R001' THEN
              nIBDEX := i;
            END IF;
          END LOOP;
        END IF;
        nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aPRM);
        IF nRTN = 0 AND nIBDEX <= aPRM.COUNT THEN
          g_nTCL := aPRM(nIBDEX);
        END IF;
--  2024/07/03 ZCZL.qinyue Add end

        --複数な帳票の場合、該当ロジックあり
        --変数の初期について、該当処理内作成しますか？判断要
        --帳票IDに関連な変数にIF内で書く
        IF g_nSTEP_INDEX = 1 THEN
          DELETE FROM GKBWL060R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
-- 2024/07/24 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--          DELETE FROM GKBWL150R002 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
          DELETE FROM GKBWL130R012 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
          DELETE FROM GKBWL020R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;

          -- 取得した条件をそれぞれの変数へセット
          VNENDO     := KKAPK0020.FNENDO(g_vJYOUKEN1,1);  -- 対象年度
          NNENDO     := TO_NUMBER(g_vJYOUKEN1);           --対象年度（和暦）
-- 2024/07/03 ZCZL.qinyue Delete start 0.3.000.000:新WizLIFE2次開発
--          IRTN       := GKBPK00010.FGKOCDTR(g_vJYOUKEN2,VSYOGAKOU);  --小学校コード
--          IRTN       := GKBPK00010.FGKOCDTR(g_vJYOUKEN3,VKUIKIGAI);  --区域外学校コード
--          IRTN       := GKBPK00010.FGKOCDTR(g_vJYOUKEN4,VYOGOGAKO);  --盲聾養護学校コード
-- 2024/07/03 ZCZL.qinyue Delete end
          NRENBAN    := TO_NUMBER(g_vJYOUKEN5);           --帳票連番使用有無
          NHAKKOUBI  := TO_NUMBER(g_vJYOUKEN6);           --発行日
          VHASOBI    := g_vJYOUKEN7;                      --発行日復活
          NHASSOUKBN := TO_NUMBER(g_vJYOUKEN8);
          IWAREKI1   := NHAKKOUBI;
          ISEIREKI1  := 0;
          BRTN := KKAPK0020.FDAYEDIT(IWAREKI1,
                                      ISEIREKI1,
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
          NHAKKOUBI1 := ISEIREKI1;
          IRTN := GKBPK00010.FKJBGET2(NHAKKOUBI1,NRENBAN,NNENDO,NKIJUNBI); --基準日
          IF IRTN <> c_IOK THEN
            -- エラーで帰ってきた場合
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
            GOTO ERROR_EXIT;
          END IF;
          --宛先の氏名出力制御
          o_ATENAPRM := A_CONS_PRM();
          IRTN := KKAPK0030.FPRMSHUTOKU('GKB','00ATENA',3,o_ATENAPRM,o_LENGTH);
          IF IRTN = 1 THEN
                        o_ATENAPRM := A_CONS_PRM();
                        o_ATENAPRM.EXTEND;
                        o_ATENAPRM.EXTEND;
                        o_ATENAPRM(1) := 0;
                        o_ATENAPRM.EXTEND;
                        o_ATENAPRM(2) := 0;
                        o_ATENAPRM.EXTEND;
                        o_ATENAPRM(3) := 0;
                        o_ATENAPRM.EXTEND;
                        o_ATENAPRM(4) := 0;
          ELSE
            WHILE (o_LENGTH < 4) LOOP
              o_ATENAPRM.EXTEND;
              o_ATENAPRM(o_LENGTH+1) := 0;
              o_LENGTH := o_LENGTH + 1;
            END LOOP;
          END IF;
          IRTN := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,o_SHIMEIPRM,o_LENGTH);
          IF IRTN  = 1 THEN
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
          ELSE
            WHILE (o_LENGTH < 6) LOOP
              o_SHIMEIPRM.EXTEND;
              o_SHIMEIPRM(o_LENGTH+1) := 0;
              o_LENGTH := o_LENGTH + 1;
            END LOOP;
          END IF;
          --教育委員会情報
          --帳票連番印字項目の制御
          IRTN := KKAPK0030.FPRMSHUTOKU('GKB','00RENBAN',0,o_RENBANPRM,o_LENGTH);
          IF IRTN = 1 THEN
                        o_RENBANPRM := A_CONS_PRM();
                        o_RENBANPRM.EXTEND;
                        o_RENBANPRM.EXTEND;
                        o_RENBANPRM(1) := 0;
          ELSE
            WHILE (o_LENGTH < 1) LOOP
              o_RENBANPRM.EXTEND;
              o_RENBANPRM(o_LENGTH+1) := 0;
              o_LENGTH := o_LENGTH + 1;
            END LOOP;
          END IF;
          -- 処理条件の設定
          PROCHAISET;
          --公印ファイル名取得
          BRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE, 0),
                                       g_sWSNUM,
                                       TO_DATE(ISAKUSEIBI,'YYYYMMDD'),
                                       o_nDAIRIKBN,
                                       o_vKATAGAKI1,
                                       o_vKATAGAKI2,
                                       o_vSHIMEI,
                                       o_vKOINFILENAME);
          VSHUCHO := o_vKOINFILENAME;
          VSHUNYUYAKU := o_vKOINFILENAME;
          VGYOMU := o_vKOINFILENAME;
          -- 市町村名取得（稼働ユーザ情報取得サブルーチン）
          -- 帳票独自の認証者を取得する
--  2024/08/20 ZCZL.WANGMING UPDATE Start 0.3.000.001:IT_GKB_00018対応
--          KKAPK0030.SNinshGet(TO_DATE(ISAKUSEIBI,'YYYYMMDD'), nDUMMY, VNINSHOSHAMEI, vDUMMY, vDUMMY, VNINSHOSHAKATAGAKI);
          -- ○○県○○郡をカットする
--          VNINSHOSHAKATAGAKI := GAAPK0010.FADDRESSEDIT2(3, VNINSHOSHAKATAGAKI);
          VNINSHOSHAKATAGAKI := GAAPK0010.FADDRESSEDIT2(3, o_vKATAGAKI1 || o_vKATAGAKI2);
--  2024/08/20 ZCZL.WANGMING UPDATE End
--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
        END IF;
          -- 児童生徒ワーク（GKBWJIDOSHINDANKEKKA）のデータ全件削除
          I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
          IF B_RTN = c_BERROR THEN
          -- エラーで帰ってきた場合
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
            GOTO ERROR_EXIT;
          END IF;
          -- 児童生徒中間データ作成
          I_RTN := FUNC_GET_JIDO_WK;
          IF I_RTN <> c_ISUCCESS THEN
            -- 対象データがなかった場合
            IF I_RTN = c_INOTFOUND THEN
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--              B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
              GOTO END_EXIT;
            END IF;
            GOTO ERROR_EXIT;
          END IF;
          -- 児童生徒ワークテーブル作成
          I_RTN := FUNC_INSERT_JIDO_WK;
          IF I_RTN = c_INOT_SUCCESS THEN
          -- エラーで帰ってきた場合
            GOTO ERROR_EXIT;
          END IF;
--  2024/04/22 ZCZL.WUCAO DELETE 0.2.000.001:512_GKB_00027対応
--        END IF;

   -- 児童生徒中間データ作成（ＣＳＶ用）
        I_RTN := FUNC_GET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
        -- エラーで帰ってきた場合
          GOTO ERROR_EXIT;
        END IF;

        --ＣＳＶファイル作成処理前に件数カウント
        NKENSU := GKBPK00010.FTCOUNT('GKBWJIDOSHINDANKEKKA',NULL);
           g_nINDEX := g_nINDEX + 1;
           g_oKENSU_LIST.EXTEND(1);
           g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NKENSU, '入力　'||'対象者件数', 1);

        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB060R001' THEN
            -- 健康診断通知書ＣＳＶファイル作成
            I_RTN := FUNC_SET_JIDO_WK_CSVFILE1;
            IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
              GOTO ERROR_EXIT;
            END IF;
-- 2024/07/24 ZCZL.qinyue Update 0.3.000.000:新WizLIFE2次開発
          --WHEN 'GKB150R002' THEN
--  2024/10/21 ZCZL.WANGMING Update 0.3.000.004:IT_GKB_00341横展開対応
--          WHEN 'GKB130R012' THEN
          WHEN 'GKB130R002' THEN
            -- 健康診断通知書発送者一覧表ＣＳＶファイル作成
            I_RTN := FUNC_SET_JIDO_WK_CSVFILE2;
            IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
              GOTO ERROR_EXIT;
            END IF;
          WHEN 'GKB020R001' THEN
            -- 健康診断票ＣＳＶファイル作成
            I_RTN := FUNC_SET_JIDO_WK_CSVFILE3;
            IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
              GOTO ERROR_EXIT;
            END IF;
          ELSE
            NULL;
        END CASE;

        --異常の場合、この標示に移動する
        <<ERROR_EXIT>>

         --帳票出力CSVの作成
        CASE g_rJSTP.CHOHYOID
           WHEN 'GKB060R001' THEN
             --CSV出力処理
             bRTN := FUNC_B11CSV ('GKBWL060R001');
-- 2024/07/03 ZCZL.qinyue Add start 0.3.000.000:新WizLIFE2次開発
        --発送者文字切れリストの作成
        bRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE, 'GKB060R001', 1, nCNT);
-- 2024/07/03 ZCZL.qinyue Add
-- 2024/07/24 ZCZL.qinyue Update start 0.3.000.000:新WizLIFE2次開発
--           WHEN 'GKB150R002' THEN
--  2024/10/21 ZCZL.WANGMING Update 0.3.000.004:IT_GKB_00341横展開対応
--           WHEN 'GKB130R012' THEN
           WHEN 'GKB130R002' THEN
             --CSV出力処理
--             bRTN := FUNC_B11CSV ('GKBWL150R002');
             bRTN := FUNC_B11CSV ('GKBWL130R012');
-- 2024/07/24 ZCZL.qinyue Update end
           WHEN 'GKB020R001' THEN
             --CSV出力処理
             bRTN := FUNC_B11CSV ('GKBWL020R001');
           ELSE
             NULL;
        END CASE;

        --最後ロジックの実行
        --ROLLBACKの処理、と件数表の値、既存の最後更新、削除処理等
        IF g_nSTEP_INDEX = g_nSTEP_MAX THEN
          IF I_RTN = 0 THEN
             COMMIT;
           ELSE
             ROLLBACK;
             RAISE ERR;
           END IF;
        END IF;
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/03
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
END GKBPB00380;
/
