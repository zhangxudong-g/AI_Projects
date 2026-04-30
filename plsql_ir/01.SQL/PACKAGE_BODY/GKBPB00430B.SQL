CREATE OR REPLACE PACKAGE BODY GKBPB00430
--1.0.205.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 中学校入学通知
--  機能概要      : 入学通知書、通知書発送者一覧表を作成する。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.LIKEWEN UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/06/27 ZCZL.shixinyu Update 0.3.000.000:新WizLIFE２次開発
--  2024/08/30 ZCZL.xiaoya Update 0.3.000.001:IT_GKB_00075対応
--  2024/09/29 ZCZL.YUCHUFEI UPDATE 0.3.000.002:仕様変更 IT_GKB_00074対応
--  2024/10/08 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00218対応
--  2024/10/22 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更 IT_GKB_00220対応
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.005:IT_GKB_00398対応
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00426対応
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/18 YAMANI.SASAKI UPDATE 0.3.000.008:IT_GKB_00609対応
--  2024/11/21 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKC_00329横展開対応
--  2024/12/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:仕様変更IT_GKB_10044の対応
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応
--  2025/01/15 JPJYS.SONGSHIHAO UPDATE 0.3.000.012:学校区マスタ対応（GKBFKGKCDGETを使用しないようにする）対応
--  2025/04/27 ZCZL.HUANGFUCHENGMING Update 1.0.002.000:GKB_QA13482(保守#1813)_学校コードの取得ロジックを修正します
--  2025/05/15 CTC.LIUJUNHAO UPDATE 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
--  2025/05/28 CTC.HJF UPDATE 1.0.006.000:GKB_QA14364_未登録外字で登録した対象者が文字切れリストに表示されない対応
--  2025/06/04 CTC.HJF UPDATE 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
--  2025/07/31 CTC.GL UPDATE 1.0.011.000:GKB_QA19054対応
--  2025/07/16 CTC.Wang UPDATE 1.0.100.000:新WizLIFE開発_帳票アウトソーシング連番対応
--  2025/08/21 CTC.LIUJUNHAO UPDATE 1.0.102.000:GKB_QA19314対応
--  2025/08/22 CTC.GYY UPDATE 1.0.102.000:GKB_QA19542対応
--  2025/09/11 CTC.XIAOMINGBO UPDATE 1.0.105.000:GKB_QA20562対応
--  2025/10/14 CTC.GYY UPDATE 1.0.201.000:GKB_QA21166対応
--  2025/11/10 CTC.GL UPDATE 1.0.205.000:GKB_QA22992対応
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

    g_nTIME NUMBER;  --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX   NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;
    g_NBREAK      NUMBER := 0;
    --パラメータ変数
    VMSG          NVARCHAR2(4000);
    VERRMSG       NVARCHAR2(1000);
    IRET          PLS_INTEGER;
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
      TYPE CRJIDO_1 IS RECORD
      (
        KOJIN_NO         NUMBER,
        RIREKI_RENBAN    NUMBER,
--  2024/06/27 ZCZL.shixinyu Add 0.3.000.000:新WizLIFE２次開発
        RIREKI_RENBAN_EDA NUMBER,
        GAKUNEN          NUMBER
        , JD_JUMIN_NAKUNARU         NUMBER
        , JD_JUMIN_NAKUNARU_JIYU    NUMBER
        , JD_JUMIN_NAKUNARU_JIYUNM  NVARCHAR2(20)
      );
          CRJIDO           CRJIDO_1;
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
    -- 児童生徒ワーク
    c_VTABLE       CONSTANT  NVARCHAR2(128) := 'GKBWJIDOTSUCHI';
    -- 業務コード
    c_VGYOMU_CD                  CONSTANT NVARCHAR2(3)  := 'GKB';
    -- 宛先の氏名出力制御コード
    c_VATENA_SEIGYO_CD           CONSTANT NVARCHAR2(7) := '00ATENA';
    -- 宛先の氏名出力制御連番
    c_VATENA_SEIGYO_RENBAN       CONSTANT  PLS_INTEGER := 5;
    -- 教育委員会情報制御コード
    c_VKYOIKUKAI_SEIGYO_CD       CONSTANT NVARCHAR2(11) := '00KYOIKUKAI';
    -- 帳票連番印字項目制御コード
    c_VRENBAN_CD                 CONSTANT NVARCHAR2(8) := '00RENBAN';
    -- 帳票連番印字項目制御連番
    c_VRENBAN_RENBAN             CONSTANT  PLS_INTEGER := 0;
    -- １頁の最大行数
    c_IMAXROWS     CONSTANT  PLS_INTEGER := 15;
   -- CSVファイル
    -- 帳票区分
    c_CHOHYO_KBN   CONSTANT NUMBER(2)      := 3;       -- 中学校入学通知
  ------------------------------------------------------------------------------
  --  変数宣言
  ------------------------------------------------------------------------------
    VTANTO_TEL       NVARCHAR2(60); 
    VTANTO_YUBIN     NVARCHAR2(60);
    VTANTO_JUSHO     NVARCHAR2(60);
    IRTN             PLS_INTEGER;
    ISAKUSEIBI       PLS_INTEGER;
    ISAKUSEIBI2      PLS_INTEGER; 
    RGAKUREIBO       GKBTGAKUREIBO%ROWTYPE;
    RJIDO_ATENA      GABTATENAKIHON%ROWTYPE;
    RJIDO_SOFU       GABTSOFUSAKI%ROWTYPE;
    RHOGO_ATENA      GABTATENAKIHON%ROWTYPE;
    RHOGO_SOFU       GABTSOFUSAKI%ROWTYPE;
    RHOGO_ATENA_NULL   GABTATENAKIHON%ROWTYPE;
    RHOGO_SOFU_NULL    GABTSOFUSAKI%ROWTYPE;
    IGAKO_CD           PLS_INTEGER;
    VGAKOMEI           NVARCHAR2(60);
    ISHOGAKO_CD        PLS_INTEGER;
    VSHOGAKOMEI        NVARCHAR2(60);
    VSEINENGAPI        NVARCHAR2(11);
    VSEIBETSU          NVARCHAR2(2);
--2024/06/27 ZCZL.shixinyu Update 0.3.000.000:新WizLIFE２次開発
--    VSETAI_NO          NVARCHAR2(7);
    VSETAI_NO          NVARCHAR2(15);
    VGYOSEIKU_MEI      NVARCHAR2(20);
    VHAN_MEI           NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.005:IT_GKB_00398対応
--    VSANTEIDANTAI_MEI  NVARCHAR2(20);
    VSANTEIDANTAI_MEI  GKBWJIDOTSUCHI.SANTEIDANTAIMEI%TYPE;
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
    VGAKUNENSEI        NVARCHAR2(20);
    VNYUGAKUKIJITU     NVARCHAR2(11);
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
--  2024/06/27 ZCZL.shixinyu Add 0.3.000.000:新WizLIFE２次開発
    rGKBTTSUCHISHOKANRI GKBTTSUCHISHOKANRI%ROWTYPE;          --通知書管理情報
    IKISAI_JUNI        PLS_INTEGER;    
  --SQL文
    VSQLJIDO                     VARCHAR2(2000);             --SQL文
    VKIJUNBI                     PLS_INTEGER;                -- 基準日
    VKOMOKU_SEIGYO               PLS_INTEGER;                -- 出力項目の制御
    VKOMOKU_HOGOSHA              PLS_INTEGER;                -- 保護者
    VKOMOKU_DOJI                 PLS_INTEGER;                -- 児童
    VKOMOKU_SEITAINUSHI          PLS_INTEGER;                -- 世帯主名印字制御
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応  
    --VKYOIKUKAI_MEI               NVARCHAR2(40);              -- 教育委員会名
    VKYOIKUKAI_MEI               NVARCHAR2(150);              -- 教育委員会名
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
    VYAKUSHOKU_MEI               NVARCHAR2(40);              -- 役職名
    VSHUTHOU_MEI                 NVARCHAR2(40);              -- 首長名
    VRITSU_MEI                   NVARCHAR2(40);              -- 立名
    VYUBIN_NO                    NVARCHAR2(40);              -- 郵便番号
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応 
    /*VJUSHO                       NVARCHAR2(120);             -- 住所
    VTEL_NO                      NVARCHAR2(40);              -- 電話番号*/
    VJUSHO                       NVARCHAR2(150);             -- 住所
    VTEL_NO                      NVARCHAR2(150);              -- 電話番号
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
    VNAISEN                      NVARCHAR2(40);              -- 内線
    VYINJI_PATTERN               PLS_INTEGER;                -- 印字パターン指定
    VCHOHYO_NO                   PLS_INTEGER;                -- 帳票番号
    VPAGENAME                    NVARCHAR2(500);             -- 改頁項目名のワーク
    VPAGEWORK                    NVARCHAR2(500);             -- 改頁項目値のワーク
    VPAGEFIELD                   NVARCHAR2(500);             -- 改頁項目値のワーク
    VYUBIN_NO1                   NVARCHAR2(60);           -- 郵便番号編集用
    NCHOHYO_NO2                  NVARCHAR2(6);            -- ZZZZ9表示連番
    IGAKKO_CD2                   NVARCHAR2(5);            -- ZZZZ9学校コード
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN               BOOLEAN;
    B_RTN              BOOLEAN;
    I_RTN              PLS_INTEGER;
    N_RTN              NUMBER;
    -- 処理条件（画面からの引数）
    VNENDO             NVARCHAR2(15);      -- 対象年度
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
    --VTYUGAKO_CD        NVARCHAR2(100);    -- 中学校コード
    VTYUGAKO_CD        NVARCHAR2(3000);    -- 中学校コード
    VHCHOHYO_RENBAN    PLS_INTEGER;       -- 帳票連番使用有無(0:使用する、1:使用しない）
    VKIJUNBI_IN        NUMBER(8);         --基準日
    VNENDO_GYY         NVARCHAR2(15);     -- 年度 (GYY)
    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWJIDOTSUCHI%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK MTJIDO_TYPE;
    -- ソート条件のワーク領域
    V_JYOUKEN01     NVARCHAR2(1000);
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
    --V_JYOUKEN02     NVARCHAR2(1000);
    V_JYOUKEN02     NVARCHAR2(3000);
    V_JYOUKEN03     NVARCHAR2(1000);
    V_JYOUKEN04     NVARCHAR2(1000);
    V_JYOUKEN05     NVARCHAR2(1000);
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
    V_JYOUKEN06     NVARCHAR2(1000);
    V_JYOUKEN07     NVARCHAR2(1000);
--  2024/06/27 ZCZL.shixinyu Add end
    -- ソート条件の値の配列宣言
    o_NBREAK         NUMBER(2);
    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    BRTNSEINENGAPI   BOOLEAN;
    IWAREKIHIZUKE    PLS_INTEGER;
    VEDIT_GYYMMDD1   NVARCHAR2(20);
    VEDIT_GYYMMDD2   NVARCHAR2(20);
    VEDIT_GYYMMDD3   NVARCHAR2(20);
    VKJ_GENGO        NVARCHAR2(20);
    VKG_GENGO        NVARCHAR2(20);
    IWAREKI_YY       PLS_INTEGER;
    ISEIREKI_YYYY    PLS_INTEGER;
    IWAREKI_GYYMM    PLS_INTEGER;
    IMM              PLS_INTEGER;
    IDD              PLS_INTEGER;
    IOWAREKIHIZUKE   PLS_INTEGER;
    ISEIREKIHIZUKE   PLS_INTEGER;
    -- 共通情報取得用変数(KKAPK0030.FKYOTU)
    o_IUSER_ID                  PLS_INTEGER;        -- 市町村コード
    o_IGAPPEI_BI                PLS_INTEGER;        -- 合併日付
    o_IJICHI_CD                 PLS_INTEGER;        -- 自治コード
    o_IUSER_KBN                 PLS_INTEGER;        -- 市町村区分
    o_VKENMEI                   NVARCHAR2(30);      -- 県名
    o_VGUNSHIMEI                NVARCHAR2(30);      -- 郡市名
    o_VUSERMEI                  NVARCHAR2(40);      -- 市町村名
    o_VSHUCHOMEI                NVARCHAR2(40);      -- 首長名
    o_VSHUCHONINSHOBUN          NVARCHAR2(100);     -- 首長認証文
    o_VYUBIN_NO                 NVARCHAR2(10);      -- 郵便番号
    o_VSHOZAICHI                NVARCHAR2(200);     -- 所在地
    o_VTEL_NO                   NVARCHAR2(20);      -- 代表電話番号
    VSQLERRM                    NVARCHAR2(256);     -- 外部関数から返ってくるエラーメッセージ
    VPAGENM                     NVARCHAR2(500);     -- 改頁項目名
    VPAGEFD                     NVARCHAR2(500);     -- 改頁項目値
    o_ATENA_PRM      A_CONS_PRM;          -- 宛先の氏名出力制御を取得
    o_KYOIKUKAI_PRM  A_CONS_PRM;          -- 教育委員会情報を取得
    o_RENBAN_PRM     A_CONS_PRM;          -- 帳票連番印字項目の制御を取得
    o_LENGTH         NUMBER;
    NHAKKOUBI1       NUMBER;
    IWAREKI1         NUMBER;
    ISEIREKI1        NUMBER;
    VKIJUNBI1        NVARCHAR2(11);
    NSHIMEI_KANJI          NVARCHAR2(110);       --氏名漢字
    KYOIKUIINKAI_CD        NUMBER;               --教育委員会コード
    --公印ファイル名取得
    VGYOMU              NVARCHAR2(100); --業務毎公印ファイル名
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
    nDAIRIKBN               NUMBER;                       --認証者の本人・代理区分
    vKATAGAKI1              NVARCHAR2(1000);              --認証者の肩書上段
    vKATAGAKI2              NVARCHAR2(1000);              --認証者の肩書下段
    vSHIMEI                 NVARCHAR2(1000);              --認証者の氏名
    rBUNNUMSRCINF           KKAPK0040.MR_BUNNUMSRCINF;    --文書番号情報（構造体）
    rBUNOUTINF              KKAPK0040.MR_BUNOUTINF;       --文書発行記録出力情報
    rBUNNUMEDITKEKA         KKAPK0040.MR_BUNNUMEDITKEKA;  --文書番号編集結果
    TYPE CR_BUNSHO_NO IS RECORD
    (
      KOJIN_NO              NUMBER,                       --宛名番号
      BUNSHONO              NVARCHAR2(1000)               --文書番号
    );
    TYPE BUNNUMHOKAN_TYPE IS TABLE OF CR_BUNSHO_NO INDEX BY BINARY_INTEGER;
    rBUNNUMHOKAN_WORK BUNNUMHOKAN_TYPE;
    sMEISHO                 NVARCHAR2(1000);              --名称(性別用)
    sMEISHOKANA             NVARCHAR2(1000);              --名称カナ(性別用)
    sYOBI                   NVARCHAR2(1000);              --予備(性別用)
    aITEM                   A_CONS_PRM;                   --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
    sINDEXNO                NUMBER;                       --変数.抑止対象者一覧表_インデックス番号
    g_sSEYIGYO              NVARCHAR2(1000);              --抑止対象者一覧表_出力制御
    nKOJINSETAIKBN          NUMBER;                       --個人世帯区分（0：個人、1：世帯）
    nYOKUSHIKBN             NUMBER;                       --抑止区分（1：支援措置、2：仮支援措置、4：その他抑止）
    nIDOYOKUSHIKBN          NUMBER;                       --異動抑止区分（0：非該当、1：警告、2：論理）
    nHAKKOYOKUSHIKBN        NUMBER;                       --発行抑止区分（0：非該当、1：警告、2：論理）
    nSHOKAIYOKUSHIKBN       NUMBER;                       --照会抑止区分（0：非該当、1：警告、2：論理）
    vSHORICHUIKBN           NVARCHAR2(10000);             --処理注意区分（任意設定）
    g_nCNT                  NUMBER;
    sSHIMEIKANA             NVARCHAR2(1000);            --児童氏名カナ
    sSHIMEIKANJI            NVARCHAR2(1000);            --児童氏名
    sSEINENGAPI             NVARCHAR2(1000);            --生年月日
    iSOFUBI                 PLS_INTEGER;                --送付日(西暦変換)
--  2024/06/27 ZCZL.shixinyu Add end
    o_SHIMEIPRM      A_CONS_PRM;
    BPRMFLG_001      BOOLEAN;
    BPRMFLG_002      BOOLEAN;
    BPRMFLG_003      BOOLEAN;
    BPRMFLG_004      BOOLEAN;
    o_YMD2           NVARCHAR2(30);
    N_NAIYO_CD       GKBTSHIMEIJKN.NAIYO_CD%TYPE;
    KYOIKUKAI_RENRAKUSAKI  NVARCHAR2(100);
    NKENSU           NUMBER;          --対象者件数
    
--  2025/08/21 CTC.LIUJUNHAO ADD START 1.0.102.000:GKB_QA19314対応
    iKIJUNBI         NUMBER;
--  2025/08/21 CTC.LIUJUNHAO ADD END 1.0.102.000:GKB_QA19314対応
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        CMBARR       DBMS_UTILITY.MAXNAME_ARRAY;
-- 2024/08/30 ZCZL.xiaoya Add start 0.3.000.001:IT_GKB_00075対応
        v_optHakkoRireki                      DBMS_UTILITY.MAXNAME_ARRAY;
        v_optShinenSochi                      DBMS_UTILITY.MAXNAME_ARRAY;
-- 2024/08/30 ZCZL.xiaoya Add end
--  2024/11/14 ZCZL.WANGYUNING ADD 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        objChugakkoCd              DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        V_JYOUKEN01 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtNendo');                --対象年度
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
        --V_JYOUKEN02 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtChugakkoCd');           --中学校コード
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtChugakkoCd');
        V_JYOUKEN02 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtChugakkoCd',0, objChugakkoCd);
--  2024/11/14 ZCZL.WANGYUNING ADD END
        CMBARR     := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbChohyoRenbanShiyoUmu');
        V_JYOUKEN03 :=CMBARR(1);                                                --帳票連番使用有無
        V_JYOUKEN04 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKijunBi');              --基準日
        V_JYOUKEN05 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'txtHakkoBi');              --発行日
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
-- 2024/08/30 ZCZL.xiaoya Update start 0.3.000.001:IT_GKB_00075対応
--         V_JYOUKEN06 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'optHakkoRireki');          --発行履歴
--         V_JYOUKEN07 :=KKBPK5551.GETPARMS(g_nJOBNUM, 'optShinenSochi');          --支援措置対象者マスク
        --発行履歴
        v_optHakkoRireki := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'optHakkoRireki');
        V_JYOUKEN06 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'optHakkoRireki',0,v_optHakkoRireki);
        --支援措置対象者マスク
        v_optShinenSochi  := KKBPK5551.GETPARMARRAYS(g_nJOBNUM,'optShinenSochi');
        V_JYOUKEN07 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'optShinenSochi',0,v_optShinenSochi);
-- 2024/08/30 ZCZL.xiaoya Update end
--  2024/06/27 ZCZL.shixinyu Add end
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FUNC_B01PINIT;

    --------------------------------------------------------
    --  機能概要      : 出力順を取得する
    --  パラメータ    : i_nCHOHYONUM
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/08
    --------------------------------------------------------
    FUNCTION FUNC_GETSORTCOLS(i_nCHOHYONUM IN KKBTSPRT.CHOHYONUM%TYPE) RETURN NVARCHAR2
    IS
       v_ORDERBY_LIST KKBTSPRT.ORDERBYCLAUSE_LIST%TYPE;
    BEGIN
       BEGIN
         --帳票ごとに、出力順を取得する
         SELECT ORDERBYCLAUSE_LIST INTO v_ORDERBY_LIST
           FROM KKBTSPRT
          WHERE GYOUMUCODE = g_sGYOUMUCODE
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
    --------------------------------------------------------
    --  機能概要      : バッチ処理画面入力値取得（帳票）
    --  パラメータ    : i_STEPSEQ     バッチジョブステップ連番
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
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
    --発送番号チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHASOBANGOCHK( i_VHASOBANGO IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    IHASOBANGO PLS_INTEGER;
    BEGIN
      IRET := 0;
      --発送番号
      BEGIN
        IF i_VHASOBANGO IS NULL THEN
          IRET := 1;
        ELSIF LENGTH(i_VHASOBANGO) > 5 THEN
          IRET := 1;
        ELSE
          IHASOBANGO  := TO_NUMBER(i_VHASOBANGO);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      RETURN(IRET);
    END FUNCHASOBANGOCHK;
    ----------------------------------------------------------------------------------------------------
    --日付チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2, i_IRENBAN IN NVARCHAR2) RETURN NUMBER IS
    IRET PLS_INTEGER;
    BRET BOOLEAN;
    TEMP_DATE DATE;
    BEGIN
      IRET := 0;
      --日付
      BEGIN
        IF i_IRENBAN = 1 THEN
           IF LENGTH(i_VHIZUKE) <> 7 THEN
              IRET := 1;
           ELSE
              IWAREKIHIDUKEIO  := TO_NUMBER(i_VHIZUKE);
              ISEIREKIHIDUKEIO := 0;
           END IF;
        ELSE
          IRET := 0;
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
    END FUNCHIZUKECHK;
    ----------------------------------------------------------------------------------------------------
    --学年チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCGAKUNENCHK( i_VGAKUNEN IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    GAKUNEN PLS_INTEGER;
    BEGIN
      IRET := 0;
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

      RETURN(IRET);
    END FUNCGAKUNENCHK;
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
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
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
        IRET := 0;

        --条件１のチェック
        IRET := FUNCNENDOCHK( V_JYOUKEN01 );
        IF IRET <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,対象年度が正しくありません。,;';
        ELSE
          VERRMSG := KKBPK5551.FJOKENDATECHK('GKB', g_sSHORIID, 0, 1, 1, V_JYOUKEN01);
          IF VERRMSG IS NOT NULL THEN  
            VMSG := VMSG || VERRMSG;
          END IF;
        END IF;

        --条件２のチェック
--  2024/11/18 YAMANI.SASAKI UPDATE START 0.3.000.008:IT_GKB_00609対応
--        IRET := GKBPK00010.FGCODCHK( V_JYOUKEN02 );
--        IF IRET <> 0 THEN
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,学校コードが正しくありません。,;';
--        END IF;
--  2024/11/18 YAMANI.SASAKI UPDATE END

        --条件３のチェック
        IRET := GKBPK00010.FRBCHK( V_JYOUKEN03 );
        IF IRET <> 0 THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,帳票連番使用有無が正しくありません。,;';
        END IF;

        --条件４のチェック
        IRET := FUNCHIZUKECHK( V_JYOUKEN04,V_JYOUKEN03 );
        IF IRET <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
        ELSE
          VERRMSG := KKBPK5551.FJOKENDATECHK('GKB', g_sSHORIID, 0, 4, 1, V_JYOUKEN04);
          IF VERRMSG IS NOT NULL THEN 
            VMSG := VMSG || VERRMSG;
          END IF;
        END IF;
        
      --条件５のチェック
        IRET := FUNCHIZUKECHK( V_JYOUKEN05,1 );
        IF IRET <> 0 THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,発行日が正しくありません。,;';
        ELSE
          VERRMSG := KKBPK5551.FJOKENDATECHK('GKB', g_sSHORIID, 0, 5, 1, V_JYOUKEN05);
          IF VERRMSG IS NOT NULL THEN
            VMSG := VMSG || VERRMSG;
          END IF;
        END IF;
--2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
        --条件７のチェック
        IF V_JYOUKEN07 <> 0 AND V_JYOUKEN07 <> 1 THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,支援措置対象者マスクが正しくありません。,;';
        END IF;
--2024/06/27 ZCZL.shixinyu Add end
        o_vRESULT := VMSG;


    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END PBPRMCHK;
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
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
        --  2024/12/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:仕様変更IT_GKB_10044の対応
            --nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
--  2025/04/27 ZCZL.HUANGFUCHENGMING Update Start 1.0.002.000:GKB_QA13482(保守#1813)_学校コードの取得ロジックを修正します
            --nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 1, 3));
            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
--  2025/04/27 ZCZL.HUANGFUCHENGMING Update End
        --  2024/12/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:仕様変更IT_GKB_10044の対応
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
--  2024/11/14 ZCZL.WANGYUNING ADD END  
    --------------------------------------------------------
    --  機能概要      : バッチジョブステップテーブルの更新処理
    --  パラメータ    : i_UPD_KBN       更新区分
    --                : i_STEPRTNCODE   実行結果コード
    --                : i_CSV_RCNT      CSV出力件数
    --                : i_CSVFILENAME   CSVファイル名
    --                : i_PRTFILENAME   出力ファイル名
    --  モジュール区分: 内部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
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
    --  機能概要      : 教育委員会連絡先を取得
    --  パラメータ    : i_SEIGYORENBAN    
    --             :i_EQNAME    
    --             :i_EQTELNO    
    --             :i_EQNAISENNO
    --  モジュール区分: 内部関数
    --  戻り値        : 教育委員会連絡先
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
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
          EQRENRAKUSAKI := EQRENRAKUSAKI || '　　' || i_EQTELNO;
        END IF;
      END IF;
      --教育委員会内線番号を取得
      IF SEIGYO(3) = 1 AND TRIM(i_EQNAISENNO) IS NOT NULL THEN
        EQRENRAKUSAKI := EQRENRAKUSAKI || '（内線：' || i_EQNAISENNO || '）';
      END IF;
      RETURN SUBSTR(EQRENRAKUSAKI, 1, 100);
    END GET_EQRENRAKUSAKI;
    --------------------------------------------------------------------------------------------------
    --  機能概要      : 処理条件の設定
    --  パラメータ    : ない
    --  モジュール区分: 内部関数
    --  戻り値        : ない
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
    --------------------------------------------------------------------------------------------------
    PROCEDURE PROCHAISET IS
      IWAREKI  PLS_INTEGER;
      ISEIREKI PLS_INTEGER;
    BEGIN
      -- 市町村名の設定
      ISAKUSEIBI2 :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));  
      -- 発送日の設定
      -- 基準日の設定
      I_RTN := GKBPK00010.FKJBGET2(NHAKKOUBI1,VHCHOHYO_RENBAN,VNENDO_GYY,VKIJUNBI); 
      IF I_RTN = 1 THEN
          RETURN;
      END IF;
      ISAKUSEIBI := VKIJUNBI;
      N_RTN := KKAPK0030.FKYOTU(ISAKUSEIBI,
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
      -- 入学期日の設定
      IWAREKI  := TO_NUMBER(VNYUGAKUKIJITU);
      ISEIREKI := 0;
      BRTN := KKAPK0020.FDAYEDIT(IWAREKI,
                                  ISEIREKI,
                                  VEDIT_GYYMMDD3,
                                  VEDIT_GYYMMDD2,
                                  VNYUGAKUKIJITU,
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
    -- 制御パレメータを取得
    --------------------------------------------------------------------------------
    PROCEDURE PROC_GET_SEIGYO_PRM  IS
    BEGIN     
      --宛先の氏名出力制御を取得
      o_ATENA_PRM := A_CONS_PRM();
      I_RTN := KKAPK0030.FPRMSHUTOKU(c_VGYOMU_CD,                    -- 業務コード
                                      c_VATENA_SEIGYO_CD,             -- 制御コード
                                      c_VATENA_SEIGYO_RENBAN,         -- 制御連番
                                      o_ATENA_PRM,                    -- 制御ﾊﾟﾗﾒｰﾀ配列
                                      o_LENGTH);                      -- 配列長さ
        IF I_RTN = 1 THEN
                      o_ATENA_PRM := A_CONS_PRM();
                      o_ATENA_PRM.EXTEND;
                      o_ATENA_PRM.EXTEND;
                      o_ATENA_PRM(1) := 0;
                      o_ATENA_PRM.EXTEND;
                      o_ATENA_PRM(2) := 0;
                      o_ATENA_PRM.EXTEND;
                      o_ATENA_PRM(3) := 0;
                      o_ATENA_PRM.EXTEND;
                      o_ATENA_PRM(4) := 0;
        ELSE
          WHILE (o_LENGTH < 4) LOOP   
            o_ATENA_PRM.EXTEND;
            o_ATENA_PRM(o_LENGTH+1) := 0;
            o_LENGTH := o_LENGTH + 1;
          END LOOP;
        END IF;
--2024/06/27 ZCZL.shixinyu Delete start 0.3.000.000:新WizLIFE２次開発
--         IRTN := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,o_SHIMEIPRM,o_LENGTH);
--         IF IRTN  = 1 THEN
--           o_SHIMEIPRM := A_CONS_PRM();
--           o_SHIMEIPRM.EXTEND;
--           o_SHIMEIPRM.EXTEND;
--           o_SHIMEIPRM(1) := 0;
--           o_SHIMEIPRM.EXTEND;
--           o_SHIMEIPRM(2) := 0;
--           o_SHIMEIPRM.EXTEND;
--           o_SHIMEIPRM(3) := 0;
--           o_SHIMEIPRM.EXTEND;
--           o_SHIMEIPRM(4) := 0;
--           o_SHIMEIPRM.EXTEND;
--           o_SHIMEIPRM(5) := 0;
--           o_SHIMEIPRM.EXTEND;
--           o_SHIMEIPRM(6) := 0;
--           o_SHIMEIPRM.EXTEND;
--           o_SHIMEIPRM(7) := 0;
--         ELSE
--           WHILE (o_LENGTH < 8) LOOP   
--             o_SHIMEIPRM.EXTEND;
--             o_SHIMEIPRM(o_LENGTH+1) := 0;
--             o_LENGTH := o_LENGTH + 1;
--           END LOOP;
--         END IF;
--2024/06/27 ZCZL.shixinyu Delete end
      VKOMOKU_SEIGYO         := o_ATENA_PRM(1);      -- 出力項目の制御 
      VKOMOKU_HOGOSHA        := o_ATENA_PRM(2);      -- 保護者
      VKOMOKU_DOJI           := o_ATENA_PRM(3);      -- 児童
      VKOMOKU_SEITAINUSHI    := o_ATENA_PRM(4);      -- 世帯主名印字
       --帳票連番印字項目の制御
       o_RENBAN_PRM := A_CONS_PRM();
       I_RTN := KKAPK0030.FPRMSHUTOKU(c_VGYOMU_CD,
                                       c_VRENBAN_CD,
                                       c_VRENBAN_RENBAN,
                                       o_RENBAN_PRM,
                                       o_LENGTH);
        IF I_RTN = 1 THEN
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
      VYINJI_PATTERN := o_RENBAN_PRM(1);                -- 印字パターン指定  
    END PROC_GET_SEIGYO_PRM;
--2024/06/27 ZCZL.shixinyu Delete start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------------------------------
    -- 制御のフラグをセットするのを行う
    --------------------------------------------------------------------------------
--     FUNCTION FUNC_PRMFLGSET(i_KOJIN_NO IN NUMBER,o_NAIYO_CD OUT NUMBER) RETURN NUMBER IS
--       NODATAFOUND_FLG    BOOLEAN;
--       ZERO_FLG           BOOLEAN;
--     BEGIN
     --フラグ初期化
--       BPRMFLG_001      := FALSE;
--       BPRMFLG_002      := FALSE;
--       BPRMFLG_003      := FALSE;
--       BPRMFLG_004      := FALSE;
--       NODATAFOUND_FLG    := FALSE;
--       ZERO_FLG           := FALSE;
     --本名使用制御管理情報の取得
--       BEGIN 
--         SELECT NAIYO_CD
--           INTO o_NAIYO_CD
--           FROM GKBTSHIMEIJKN
--          WHERE KOJIN_NO = i_KOJIN_NO
--            AND CHOHYO_ID = 'GKB040R001';
--         IF o_NAIYO_CD = 0 THEN
--           ZERO_FLG  := TRUE;
--         END IF;
--       EXCEPTION
       --データを取得しない場合
--         WHEN NO_DATA_FOUND THEN
--         NODATAFOUND_FLG  := TRUE;
--       END;
     --氏名印字.制御ﾊﾟﾗﾒｰﾀ(7)が1の場合
--       IF o_SHIMEIPRM(7) = 1 THEN
--         BPRMFLG_001  := TRUE;
--       END IF;
     --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(7)が4、6場合
--       IF NODATAFOUND_FLG OR ZERO_FLG THEN
--         IF o_SHIMEIPRM(7) IN (4, 6) THEN
--           BPRMFLG_002  := TRUE;
--         END IF;
--       END IF;
     --本名使用制御管理情報が存在する、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(7)が3、4、5、6場合
--       IF NOT NODATAFOUND_FLG AND NOT ZERO_FLG THEN
--         IF o_SHIMEIPRM(7) IN(3,4,5,6) THEN
--           BPRMFLG_003  := TRUE;
--         END IF;
--       END IF;
       --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(7)が4、5場合「生年月日」
--       IF NODATAFOUND_FLG OR ZERO_FLG THEN
--         IF o_SHIMEIPRM(7) IN (4, 5) THEN
--           BPRMFLG_004  := TRUE;
--         END IF;
--       END IF;
--     RETURN 0;
--     END FUNC_PRMFLGSET;
    --------------------------------------------------------------------------------
    -- 制御を行う
    --------------------------------------------------------------------------------
--     FUNCTION FUNC_SEIGYO_SET(i_HONMYO IN NVARCHAR2,i_SHIMEI IN NVARCHAR2, o_SET OUT NVARCHAR2) RETURN NUMBER
--     IS
--     BEGIN
     --HONMYO_KANAをセット
--       IF BPRMFLG_001 OR BPRMFLG_002 THEN
--         o_SET := NVL(TRIM(i_HONMYO),i_SHIMEI);
--       END IF;
     --本名使用制御管理情報の設定で編集
--       IF BPRMFLG_003 THEN
--         IF N_NAIYO_CD IN(11,12) THEN
--           o_SET := NVL(TRIM(i_SHIMEI),i_HONMYO);
--         ELSIF N_NAIYO_CD IN(21,22) THEN
--           o_SET := NVL(TRIM(i_HONMYO),i_SHIMEI);
--         END IF;
--       END IF;
     --SHIMEI_KANAをセット
--       IF NOT BPRMFLG_001 AND NOT BPRMFLG_002 AND NOT BPRMFLG_003 THEN
--         o_SET := NVL(TRIM(i_SHIMEI),i_HONMYO);
--       END IF;
--       RETURN 0;
--     END FUNC_SEIGYO_SET;
--  2024/06/27 ZCZL.shixinyu Delete end
    --------------------------------------------------------------------------------
    -- 児童生徒中間（ETT_WK_JIDO_TUTI）レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
      IFRET               PLS_INTEGER;                -- 戻り値
      NNENDO              PLS_INTEGER;                -- 年度
      NTYUGAKO_CD           NVARCHAR2(100);           -- 中学校コード
      IRTNA               PLS_INTEGER;
      IRTNSANTEIDANTAI    PLS_INTEGER;
      IRTNAH              PLS_INTEGER;
      ICNT                BINARY_INTEGER;             -- 戻り値
      BRTNSASKUSEIBI      BOOLEAN;
      IJUSHO_NAGASA       PLS_INTEGER;
      IRTNZOKUGARA1       PLS_INTEGER;
      IRTNZOKUGARAHERR1   PLS_INTEGER;
      IRTNZOKUGARA2       PLS_INTEGER;
      IRTNZOKUGARAHERR2   PLS_INTEGER;
      NPRTN               NUMBER;
      IWAREKI             PLS_INTEGER;
      n_YYYY               PLS_INTEGER;
      n_MM                 PLS_INTEGER;
      n_DD                 PLS_INTEGER;
      v_GYYMMDD3           NVARCHAR2(20);
      o_RATENA_REC   GABTATENAKIHON%ROWTYPE;
      o_RSOFU_REC    GABTSOFUSAKI%ROWTYPE;
      ISEIREKI             PLS_INTEGER;               --西暦(YYYYMMDD)
      TYPE CTGKBTGAKUREIBO IS REF CURSOR;
      CJIDO CTGKBTGAKUREIBO;

    BEGIN
      IFRET := c_INOTFOUND;                 -- 該当なし
      NTYUGAKO_CD := VTYUGAKO_CD;          -- 中学校コード
      -- ワーク領域の初期化
      MJIDO_WORK.DELETE;
      ICNT := 0;
        NSHIMEI_KANJI := NULL;              --氏名漢字  
      BEGIN
        VSQLJIDO := '';
        VSQLJIDO := VSQLJIDO || 'SELECT ';
        VSQLJIDO := VSQLJIDO || 'B.KOJIN_NO, ';
        VSQLJIDO := VSQLJIDO || 'B.RIREKI_RENBAN ';
--  2024/06/27 ZCZL.shixinyu Add 0.3.000.000:新WizLIFE２次開発
        VSQLJIDO := VSQLJIDO || ',B.RIREKI_RENBAN_EDA ';
        VSQLJIDO := VSQLJIDO || ',B.GAKUNEN ';
        VSQLJIDO := VSQLJIDO || ',NVL(D.JUMIN_NAKUNARU, 0)      JD_JUMIN_NAKUNARU ';
        VSQLJIDO := VSQLJIDO || ',NVL(D.JUMIN_NAKUNARU_JIYU, 0) JD_JUMIN_NAKUNARU_JIYU ';
        VSQLJIDO := VSQLJIDO || ',GAAPK0030.FIDOJIYUMEI( D.JUMIN_NAKUNARU_JIYU) JD_JUMIN_NAKUNARU_JIYUNM ';
        VSQLJIDO := VSQLJIDO || 'FROM ';
        VSQLJIDO := VSQLJIDO || 'GKBTGAKUREIBO B, ';
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--        VSQLJIDO := VSQLJIDO || '(SELECT KOJIN_NO,MAX(RIREKI_RENBAN) RIREKI_RENBAN FROM GKBTGAKUREIBO ';
--        VSQLJIDO := VSQLJIDO || 'WHERE SHORIBI<='|| VKIJUNBI;
        VSQLJIDO := VSQLJIDO || '(SELECT KOJIN_NO,MAX(RIREKI_RENBAN*1000 + RIREKI_RENBAN_EDA) RIREKIBANGO FROM GKBTGAKUREIBO ';
        VSQLJIDO := VSQLJIDO || 'WHERE SHORIBI<='|| VKIJUNBI || 'AND SAKUJO_FLG = 0';
--  2024/06/27 ZCZL.shixinyu Update end
        VSQLJIDO := VSQLJIDO || ' GROUP BY KOJIN_NO) C ';
        VSQLJIDO := VSQLJIDO || ' ,GABVATENAALL D ';                     
        VSQLJIDO := VSQLJIDO || 'WHERE C.KOJIN_NO=B.KOJIN_NO ';
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--        VSQLJIDO := VSQLJIDO || 'AND   C.RIREKI_RENBAN=B.RIREKI_RENBAN ';
        VSQLJIDO := VSQLJIDO || 'AND   ROUND(C.RIREKIBANGO/1000) = B.RIREKI_RENBAN ';
        VSQLJIDO := VSQLJIDO || 'AND   B.RIREKI_RENBAN_EDA = MOD(C.RIREKIBANGO,1000) ';
--  2024/06/27 ZCZL.shixinyu Update end
        VSQLJIDO := VSQLJIDO || 'AND   B.GAKUNEN = 6 ';
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--         VSQLJIDO := VSQLJIDO || 'AND( ';
--         VSQLJIDO := VSQLJIDO || '    (B.SYOGAKO_CD <> 0 ';
--         VSQLJIDO := VSQLJIDO || '    AND (B.SYOGAKO_NYUGAKU_BI <> 0 OR B.SYOGAKO_TENNYUGAKU_BI <> 0) ';
--         VSQLJIDO := VSQLJIDO || '    AND (B.SYOGAKO_TENGAKU_BI = 0 AND B.SYOGAKO_SOTSUGYO_BI = 0)) ';
--         VSQLJIDO := VSQLJIDO || ' OR (B.TYUGAKO_CD <> 0 ';                                                  
--         VSQLJIDO := VSQLJIDO || '    AND B.SYOGAKO_CD = 0 AND B.KUIKIGAI_CD = 0 AND B.YOGOGAKO_CD = 0) ';   
--         VSQLJIDO := VSQLJIDO || ' OR (B.KUIKIGAI_CD <> 0 ';
--         VSQLJIDO := VSQLJIDO || '    AND (B.KUIKIGAI_NYUGAKU_BI <> 0 OR B.KUIKIGAI_TENNYUGAKU_BI <> 0) ';
--         VSQLJIDO := VSQLJIDO || '    AND (B.KUIKIGAI_TENGAKU_BI = 0 AND B.KUIKIGAI_SOTSUGYO_BI = 0) AND KUIKIGAI_TAIGAKU_BI = 0) ';
--         VSQLJIDO := VSQLJIDO || ' OR (B.YOGOGAKO_CD <> 0 ';
--         VSQLJIDO := VSQLJIDO || '    AND (B.YOGOGAKO_NYUGAKU_BI <> 0 OR B.YOGOGAKO_TENNYUGAKU_BI <> 0) ';
--         VSQLJIDO := VSQLJIDO || '    AND (B.YOGOGAKO_TENGAKU_BI = 0 AND B.YOGOGAKO_SOTSUGYO_BI = 0))) ';
--         VSQLJIDO := VSQLJIDO || ' AND C.KOJIN_NO = D.KOJIN_NO AND D.RIREKI_RENBAN = 999 ';
        VSQLJIDO := VSQLJIDO || 'AND   B.GEN_NENGAPI = 0 ';
        VSQLJIDO := VSQLJIDO || 'AND   B.SYOGAKO_TENGAKU_BI = 0 ';
        VSQLJIDO := VSQLJIDO || 'AND   B.KOJIN_NO = D.KOJIN_NO ';
        VSQLJIDO := VSQLJIDO || 'AND   D.RIREKI_RENBAN = 999 ';
--  2024/06/27 ZCZL.shixinyu Update end
        -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
        EXECUTE IMMEDIATE  VSQLJIDO;
        OPEN CJIDO FOR VSQLJIDO;
        LOOP
          FETCH CJIDO INTO CRJIDO;
          EXIT WHEN CJIDO%NOTFOUND;
          VCNT :=  TO_CHAR(ICNT);
          -- 学齢簿情報取得
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--          GKBSKJDOG2(CRJIDO.KOJIN_NO,CRJIDO.RIREKI_RENBAN,RGAKUREIBO,NPRTN);
          GKBSKJDOG2(CRJIDO.KOJIN_NO,CRJIDO.RIREKI_RENBAN,CRJIDO.RIREKI_RENBAN_EDA,RGAKUREIBO,NPRTN);
          --性別漢字取得
          IFRET := KKAPK0030.FCDGetR('GKB', '021', '0001', RGAKUREIBO.SEIBETSU, sMEISHO, sMEISHOKANA, sYOBI);
--  2024/06/27 ZCZL.shixinyu Update end
          -- 学齢簿にデータがあったときのみ出力対象
          IF NPRTN = 0 THEN
            --実行順序入れ替え
            -- 児童宛名情報取得
            IRTNA := GAAPK0030.FGETATENA(CRJIDO.KOJIN_NO,
                                       'GKB',
                                       ISAKUSEIBI,
                                       RJIDO_ATENA,
                                       RJIDO_SOFU);
--2024/06/27 ZCZL.shixinyu Delete 0.3.000.000:新WizLIFE２次開発
--            IRTN  := FUNC_PRMFLGSET(RJIDO_ATENA.KOJIN_NO,N_NAIYO_CD);
            -- 小学校名称取得
            BEGIN
              SELECT SYOGAKO_CD,
                     SYOGAKOMEI
                INTO ISHOGAKO_CD,
                     VSHOGAKOMEI
                FROM GKBTSHOGAKKO
               WHERE SYOGAKO_CD = RGAKUREIBO.SYOGAKO_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                ISHOGAKO_CD := RGAKUREIBO.SYOGAKO_CD;
                VSHOGAKOMEI := ' ';
            END;
            --学齢簿に中学校区がまだ入っていない場合は宛名の中学校区を参照する
            --学齢簿に小学校区がまだ入っていない場合は宛名の小学校区を参照する
            IF ISHOGAKO_CD = 0 THEN
              BEGIN
                SELECT SYOGAKO_CD,
                       SYOGAKOMEI
                  INTO ISHOGAKO_CD,
                       VSHOGAKOMEI
                  FROM GKBTSHOGAKKO
--  2024/10/22 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更 IT_GKB_00220対応
--                 WHERE SYOGAKO_CD = RJIDO_ATENA.SHOGAKU_CD;
--  2025/01/15 JPJYS.SONGSHIHAO UPDATE 0.3.000.012:学校区マスタ対応（GKBFKGKCDGETを使用しないようにする）対応 Start
                 --WHERE SYOGAKO_CD = GKBFKGKCDGET(1,CRJIDO.KOJIN_NO,RJIDO_ATENA.RIREKI_RENBAN);
                 WHERE SYOGAKO_CD = RJIDO_ATENA.SHOGAKU_CD;
--  2025/01/15 JPJYS.SONGSHIHAO UPDATE 0.3.000.012:学校区マスタ対応（GKBFKGKCDGETを使用しないようにする）対応 End
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  ISHOGAKO_CD := 0;
                  VSHOGAKOMEI := ' ';
              END;
            END IF;
            -- 中学校名取得
            BEGIN
              SELECT TYUGAKO_CD,
                     TYUGAKOMEI
                INTO IGAKO_CD,
                     VGAKOMEI
                FROM GKBTCHUGAKKO
               WHERE TYUGAKO_CD = RGAKUREIBO.TYUGAKO_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                IGAKO_CD := RGAKUREIBO.TYUGAKO_CD;
                VGAKOMEI := ' ';
            END;
            -- 学年名        
            VGAKUNENSEI := RGAKUREIBO.GAKUNEN - 6;
            VGAKUNENMEI := VGAKUNENSEI || '年生';
            --学齢簿に中学校区がまだ入っていない場合は宛名の中学校区を参照する
            --養護学校・区域外の生徒の場合もあるため、養護学校コード・区域外学校コードも判断に追加する
            --養護学校・区域外の生徒の場合でも、従来の児童と同様に出力する必要があるため、
            --養護学校コード・区域外学校コードの判断を削除する
            IF IGAKO_CD = 0 THEN
              -- 中学校名取得
              BEGIN
                SELECT TYUGAKO_CD,
                       TYUGAKOMEI
                  INTO IGAKO_CD,
                       VGAKOMEI
                  FROM GKBTCHUGAKKO
--  2024/10/22 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更 IT_GKB_00220対応
--                 WHERE TYUGAKO_CD = RJIDO_ATENA.CHUGAKU_CD;
--  2025/01/15 JPJYS.SONGSHIHAO UPDATE 0.3.000.012:学校区マスタ対応（GKBFKGKCDGETを使用しないようにする）対応 Start
                 --WHERE TYUGAKO_CD = GKBFKGKCDGET(2,CRJIDO.KOJIN_NO,RJIDO_ATENA.RIREKI_RENBAN);
                 WHERE TYUGAKO_CD = RJIDO_ATENA.CHUGAKU_CD;
--  2025/01/15 JPJYS.SONGSHIHAO UPDATE 0.3.000.012:学校区マスタ対応（GKBFKGKCDGETを使用しないようにする）対応 End
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  IGAKO_CD := 0;
                  VGAKOMEI := ' ';
              END;
              --養護学校・区域外就学の児童は宛名の中学校区をセットしない
              --養護学校・区域外就学の児童は宛名の中学校区をセットしない処理を削除
            END IF;
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
            n_YYYY           := ISEIREKI_YYYY;
            n_MM             := IMM;
            n_DD             := IDD;
            v_GYYMMDD3       := VEDIT_GYYMMDD3;
--  2024/06/27 ZCZL.shixinyu Delete start 0.3.000.000:新WizLIFE２次開発
--             IF RJIDO_ATENA.SEIBETSU = 1 THEN
--               VSEIBETSU := '男';
--             ELSIF RJIDO_ATENA.SEIBETSU = 2 THEN
--               VSEIBETSU := '女';
--             END IF;
--  2024/06/27 ZCZL.shixinyu Delete end
            VSETAI_NO :=  TO_CHAR(RJIDO_ATENA.SETAI_NO);
            VGYOSEIKU_MEI := GAAPK0030.FGYOSEIKUMEI(RJIDO_ATENA.SANTEIDANTAI_CD,RJIDO_ATENA.GYOSEIKU_CD);
            VHAN_MEI := GAAPK0030.FHANMEI(RJIDO_ATENA.SANTEIDANTAI_CD, RJIDO_ATENA.HAN_CD);
            IRTNSANTEIDANTAI := GAAPK0030.FJICHINAME(RJIDO_ATENA.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);
            IF RGAKUREIBO.HOGOSYA_KOJIN_NO <> 0 THEN
              IRTNAH := GAAPK0030.FGETATENA(RGAKUREIBO.HOGOSYA_KOJIN_NO,
                                          'GKB',
                                          ISAKUSEIBI,
                                          RHOGO_ATENA,
                                          RHOGO_SOFU);
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--               MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RHOGO_ATENA.SHIMEI_KANA;
--               MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
              --保護者の本名使用制御判定
--  2025/11/10 CTC.GL UPDATE START 1.0.205.000:GKB_QA22992対応
--              IRTN := GKBFKHMCTRL(RGAKUREIBO.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_sSEYIGYO, sSHIMEIKANA, sSHIMEIKANJI, sSEINENGAPI);
              IRTN := GKBFKHMCTRL(RGAKUREIBO.KOJIN_NO, g_rJSTP.CHOHYOID, 1, g_sSEYIGYO, sSHIMEIKANA, sSHIMEIKANJI, sSEINENGAPI, RGAKUREIBO.RIREKI_RENBAN);
--  2025/11/10 CTC.GL UPDATE END
              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := sSHIMEIKANA;
              MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := sSHIMEIKANJI;
--  2024/06/27 ZCZL.shixinyu Update end
              MJIDO_WORK(ICNT).CHOMEI := RHOGO_ATENA.CHOMEI;
              MJIDO_WORK(ICNT).BANCHI := RHOGO_ATENA.BANCHI;
              MJIDO_WORK(ICNT).KATAGAKI := RHOGO_ATENA.KATAGAKI;
              IRTNZOKUGARA1 := GKBFKZKGMGET(1,
                                            RGAKUREIBO.ZOKUGARA1,
                                            RGAKUREIBO.ZOKUGARA2,
                                            RGAKUREIBO.ZOKUGARA3,
                                            RGAKUREIBO.ZOKUGARA4,
                                            VZOKUGARAMEI1,
                                            IRTNZOKUGARAHERR1);
              IRTNZOKUGARA2 := GKBFKZKGMGET(2,
                                            RGAKUREIBO.HOGOSYA_ZOKUGARA1,
                                            RGAKUREIBO.HOGOSYA_ZOKUGARA2,
                                            RGAKUREIBO.HOGOSYA_ZOKUGARA3,
                                            RGAKUREIBO.HOGOSYA_ZOKUGARA4,
                                            VZOKUGARAMEI2,
                                            IRTNZOKUGARAHERR2);
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--               VHOGOSHA_SHIMEI_JODAN := RHOGO_ATENA.SHIMEI_KANA;
--               VHOGOSHA_SHIMEI_GEDAN := RHOGO_ATENA.SHIMEI_KANJI;
--               IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
                --保護者氏名かな
--                 I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANA,RHOGO_ATENA.SHIMEI_KANA,MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                --保護者氏名漢字
--                 I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANJI,RHOGO_ATENA.SHIMEI_KANJI,MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI);
                --保護者氏名上段
--                   I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANA,RHOGO_ATENA.SHIMEI_KANA,VHOGOSHA_SHIMEI_JODAN);    
-- 
                --保護者氏名下段(保護者氏名漢字)
--                 I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANJI,RHOGO_ATENA.SHIMEI_KANJI,VHOGOSHA_SHIMEI_GEDAN);
--               END IF;
              VHOGOSHA_SHIMEI_JODAN := sSHIMEIKANA;
              VHOGOSHA_SHIMEI_GEDAN := sSHIMEIKANJI;
--  2024/06/27 ZCZL.shixinyu Update end
              IJUSHO_NAGASA := LENGTH(RHOGO_ATENA.CHOMEI||RHOGO_ATENA.BANCHI||' '||RHOGO_ATENA.KATAGAKI);           
              IF IJUSHO_NAGASA > 20 THEN
                VJUSHO_JODAN := SUBSTR (RHOGO_ATENA.CHOMEI||RHOGO_ATENA.BANCHI||' '||RHOGO_ATENA.KATAGAKI,1,20);    
                VJUSHO_GEDAN := SUBSTR (RHOGO_ATENA.CHOMEI||RHOGO_ATENA.BANCHI||' '||RHOGO_ATENA.KATAGAKI,21,20);   
              ELSE
                VJUSHO_JODAN := SUBSTR (RHOGO_ATENA.CHOMEI||RHOGO_ATENA.BANCHI||' '||RHOGO_ATENA.KATAGAKI,1,20);    
                VJUSHO_GEDAN := ' ';
              END IF;
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
                MJIDO_WORK(ICNT).CHOMEI   := RHOGO_SOFU.CHOMEI;
                MJIDO_WORK(ICNT).BANCHI   := RHOGO_SOFU.BANCHI;
                MJIDO_WORK(ICNT).KATAGAKI := RHOGO_SOFU.KATAGAKI;
                MJIDO_WORK(ICNT).YUBIN_NO   := RHOGO_SOFU.YUBIN_NO;
                MJIDO_WORK(ICNT).YUBIN_NOBC := RHOGO_SOFU.YUBIN_NOBC;
              END IF;
            ELSE
              RHOGO_ATENA := RHOGO_ATENA_NULL;
              RHOGO_SOFU  := RHOGO_SOFU_NULL;
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
            END IF;
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
            MJIDO_WORK(ICNT).JIDO_KOJIN_NO := RGAKUREIBO.KOJIN_NO;
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--             MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := RJIDO_ATENA.SHIMEI_KANA;
--             MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
--             IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
              --児童氏名かな
--               I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANA,RJIDO_ATENA.SHIMEI_KANA,MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA);
             --児童氏名漢字
--               I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANJI,RJIDO_ATENA.SHIMEI_KANJI,MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI);
--             END IF;
            --児童生徒の本名使用制御判定
            IRTN := GKBFKHMCTRL(MJIDO_WORK(ICNT).JIDO_KOJIN_NO, g_rJSTP.CHOHYOID, 0, g_sSEYIGYO, sSHIMEIKANA, sSHIMEIKANJI, sSEINENGAPI);
            MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA := sSHIMEIKANA;
            MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI := sSHIMEIKANJI;
--  2024/06/27 ZCZL.shixinyu Update end
            MJIDO_WORK(ICNT).SEINENGAPI := RJIDO_ATENA.SEINENGAPI;
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--             MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := VSEINENGAPI;
--             MJIDO_WORK(ICNT).KANJI_SEINENGAPI := RJIDO_ATENA.HYOJI_SEINENGAPI;
--             IF RJIDO_ATENA.JINKAKU_KBN != 0 THEN
--                 I_RTN := GKBPK00010.FYMDEDT1(RJIDO_ATENA.SEINENGAPI,
--                          MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,MJIDO_WORK(ICNT).KANJI_SEINENGAPI);
--               IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
--                 IF BPRMFLG_004 THEN
--                   I_RTN := GKBPK00010.FYMDEDT1(RJIDO_ATENA.SEINENGAPI,MJIDO_WORK(ICNT).HYOJI_SEINENGAPI,o_YMD2);
--                   MJIDO_WORK(ICNT).KANJI_SEINENGAPI := n_YYYY||'年'||LPAD(n_MM,2)||'月'||LPAD(n_DD,2)||'日';     
--                 ELSIF BPRMFLG_003 THEN
                  --和暦で表示生年月日
--                   IF N_NAIYO_CD IN(11,21) THEN
--                     MJIDO_WORK(ICNT).HYOJI_SEINENGAPI    := VSEINENGAPI;
--                     MJIDO_WORK(ICNT).KANJI_SEINENGAPI    := RJIDO_ATENA.HYOJI_SEINENGAPI; 
                  --西暦で表示生年月日
--                   ELSIF N_NAIYO_CD IN(12,22) THEN
--                     MJIDO_WORK(ICNT).HYOJI_SEINENGAPI    := n_YYYY||'.'||LPAD(n_MM,2)||'.'||LPAD(n_DD,2);
--                     MJIDO_WORK(ICNT).KANJI_SEINENGAPI    := n_YYYY||'年'||LPAD(n_MM,2)||'月'||LPAD(n_DD,2)||'日';  
--                   END IF;
--                 ELSE
                  --「平成○年○月○日」の形式で表示
--                   MJIDO_WORK(ICNT).HYOJI_SEINENGAPI        := VSEINENGAPI; 
--                   MJIDO_WORK(ICNT).KANJI_SEINENGAPI        := v_GYYMMDD3;  
--                 END IF;
--               END IF;
--             END IF;
--             MJIDO_WORK(ICNT).SEIBETSU := RJIDO_ATENA.SEIBETSU;
--             MJIDO_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;
            MJIDO_WORK(ICNT).HYOJI_SEINENGAPI := sSEINENGAPI;
            MJIDO_WORK(ICNT).KANJI_SEINENGAPI := RJIDO_ATENA.HYOJI_SEINENGAPI;
            MJIDO_WORK(ICNT).SEIBETSU := RGAKUREIBO.SEIBETSU;
            MJIDO_WORK(ICNT).HYOJI_SEIBETSU := sMEISHO;
--  2024/06/27 ZCZL.shixinyu Update end
            MJIDO_WORK(ICNT).ZOKUGARAMEI1 := VZOKUGARAMEI1;
            MJIDO_WORK(ICNT).SETAI_NO := RJIDO_ATENA.SETAI_NO;
            MJIDO_WORK(ICNT).HYOJI_SETAI_NO := VSETAI_NO;
            MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO := RGAKUREIBO.HOGOSYA_KOJIN_NO;
            MJIDO_WORK(ICNT).ZOKUGARAMEI2 := VZOKUGARAMEI2;
            MJIDO_WORK(ICNT).GAKUNEN_CD := CRJIDO.GAKUNEN;
            MJIDO_WORK(ICNT).GAKUNENMEI := VGAKUNENMEI;
            MJIDO_WORK(ICNT).GAKOKU_CD := IGAKO_CD;
            MJIDO_WORK(ICNT).GAKOKUMEI := VGAKOMEI;
            MJIDO_WORK(ICNT).GYOSEIKU_CD := RJIDO_ATENA.GYOSEIKU_CD;
            MJIDO_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;
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
            -- 児童の送付先が設定されていた場合には送付先住所を表示
            IF RJIDO_SOFU.KOJIN_NO IS NOT NULL AND
               (RJIDO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND
               (RJIDO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RJIDO_SOFU.SHURYO_BI = 0) THEN
              MJIDO_WORK(ICNT).JIDO_YUBIN_NO := RJIDO_SOFU.YUBIN_NO;
              MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC := RJIDO_SOFU.YUBIN_NOBC;
              MJIDO_WORK(ICNT).JIDO_CHOMEI := RJIDO_SOFU.CHOMEI;
              MJIDO_WORK(ICNT).JIDO_BANCHI := RJIDO_SOFU.BANCHI;
              MJIDO_WORK(ICNT).JIDO_KATAGAKI := RJIDO_SOFU.KATAGAKI;
            ELSE
              -- 送付先が設定されてなければ宛名住所を表示
              MJIDO_WORK(ICNT).JIDO_YUBIN_NO := RJIDO_ATENA.YUBIN_NO;
              MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC := RJIDO_ATENA.YUBIN_NOBC;
              MJIDO_WORK(ICNT).JIDO_CHOMEI := RJIDO_ATENA.CHOMEI;
              MJIDO_WORK(ICNT).JIDO_BANCHI := RJIDO_ATENA.BANCHI;
              MJIDO_WORK(ICNT).JIDO_KATAGAKI := RJIDO_ATENA.KATAGAKI;
            END IF;
            BEGIN
              SELECT NVL(DATE1,0), NVL(DATE2,0), NVL(DATE3,0), NVL(DATE4,0), NVL(DATE5,0),
                     NVL(KOMOKU1,' '), NVL(KOMOKU2,' '), NVL(KOMOKU3,' '), NVL(KOMOKU4,' '), NVL(KOMOKU5,' '),
                     NVL(KOMOKU6,' '), NVL(KOMOKU7,' '), NVL(KOMOKU8,' '), NVL(KOMOKU9,' '), NVL(KOMOKU10,' ')
                INTO IDATE1, IDATE2, IDATE3, IDATE4, IDATE5,
                     VKOMOKU1, VKOMOKU2, VKOMOKU3, VKOMOKU4, VKOMOKU5,
                     VKOMOKU6, VKOMOKU7, VKOMOKU8, VKOMOKU9, VKOMOKU10
                FROM GKBTTSUCHISHOJKN
               WHERE CHOHYO_KBN = c_CHOHYO_KBN
                 AND GAKO_CD = IGAKO_CD;
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
            BEGIN
              SELECT NVL(DATE_MEI1,' '), NVL(DATE_MEI2,' '), NVL(DATE_MEI3,' '), NVL(DATE_MEI4,' '), NVL(DATE_MEI5,' '),
                     NVL(KOMOKU_MEI1,' '), NVL(KOMOKU_MEI2,' '), NVL(KOMOKU_MEI3,' '), NVL(KOMOKU_MEI4,' '), NVL(KOMOKU_MEI5,' '),
                     NVL(KOMOKU_MEI6,' '), NVL(KOMOKU_MEI7,' '), NVL(KOMOKU_MEI8,' '), NVL(KOMOKU_MEI9,' '), NVL(KOMOKU_MEI10,' ')
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
                     ,CHOHYO_MEI,KOIN_SHORYAKU,KOIN_CHUSHAKU,TSUCHIBUN,TOKKIJIKO,BIKO,BIKO_TITLE
                     ,YOSHIKI_BANGO_SETTOGO,YOSHIKI_BANGO,YOSHIKI_BANGO_SETSUBIGO
--  2024/06/27 ZCZL.shixinyu Add end
                INTO VDATE_MEI1, VDATE_MEI2, VDATE_MEI3, VDATE_MEI4, VDATE_MEI5,
                     VKOMOKU_MEI1, VKOMOKU_MEI2, VKOMOKU_MEI3, VKOMOKU_MEI4, VKOMOKU_MEI5,
                     VKOMOKU_MEI6, VKOMOKU_MEI7, VKOMOKU_MEI8, VKOMOKU_MEI9, VKOMOKU_MEI10
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
                    ,rGKBTTSUCHISHOKANRI.CHOHYO_MEI,rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU,rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU
                    ,rGKBTTSUCHISHOKANRI.TSUCHIBUN,rGKBTTSUCHISHOKANRI.TOKKIJIKO,rGKBTTSUCHISHOKANRI.BIKO
                    ,rGKBTTSUCHISHOKANRI.BIKO_TITLE,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO
                    ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO
--  2024/06/27 ZCZL.shixinyu Add end
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
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
               rGKBTTSUCHISHOKANRI.CHOHYO_MEI :=' ';
               rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU :=' ';
               rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU :=' ';
               rGKBTTSUCHISHOKANRI.TSUCHIBUN :=' ';
               rGKBTTSUCHISHOKANRI.TOKKIJIKO :=' ';
               rGKBTTSUCHISHOKANRI.BIKO :=' ';
               rGKBTTSUCHISHOKANRI.BIKO_TITLE :=' ';
               rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO :=' ';
               rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO :=' ';
               rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO :=' ';
--  2024/06/27 ZCZL.shixinyu Add end
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
            MJIDO_WORK(ICNT).DATE1 := VDATE1;
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
            MJIDO_WORK(ICNT).YUHEN_KBN  := RJIDO_ATENA.YUHEN_KBN;                   --郵返区分
            MJIDO_WORK(ICNT).OAZA_CD    := RJIDO_ATENA.OAZA_CD;                     --大字コード
            MJIDO_WORK(ICNT).HONBAN     := RJIDO_ATENA.HONBAN;                      --本番
            MJIDO_WORK(ICNT).EDABAN1    := RJIDO_ATENA.EDABAN1;                     --枝１
            MJIDO_WORK(ICNT).EDABAN2    := RJIDO_ATENA.EDABAN2;                     --枝２
            MJIDO_WORK(ICNT).EDABAN3    := RJIDO_ATENA.EDABAN3;                     --枝３
            MJIDO_WORK(ICNT).GAIKU      := RJIDO_ATENA.GAIKU;                       --街区
            MJIDO_WORK(ICNT).TOU        := RJIDO_ATENA.TOU;                         --棟
            MJIDO_WORK(ICNT).GOU        := RJIDO_ATENA.GOU;                         --号
            MJIDO_WORK(ICNT).GENZON_KBN := RJIDO_ATENA.GENZON_KBN;                  --現存区分
            --  宛先上段
-- 2024/06/27 ZCZL.shixinyu Delete start 0.3.000.000:新WizLIFE２次開発
--             IF VKOMOKU_SEIGYO IN (1,3)  THEN
--                 IF (RJIDO_SOFU.KOJIN_NO IS NOT NULL) AND 
--                        (RJIDO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND 
--                        (RJIDO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RJIDO_SOFU.SHURYO_BI = 0) THEN
--                        IF RJIDO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
--                           NSHIMEI_KANJI := RJIDO_SOFU.SHIMEI_KANJI;
--                        ELSE
--                           NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
--                          IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
--                            I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANJI,RJIDO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                          END IF;
--                        END IF;
--                     ELSE
--                        NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
--                        IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
--                          I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANJI,RJIDO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                        END IF;
--                     END IF;
--               IF LENGTH(NSHIMEI_KANJI) > 0 THEN
--                 IF VKOMOKU_DOJI = 1 THEN
--                   MJIDO_WORK(ICNT).ATESAKI_JODAN :=  '（' || NSHIMEI_KANJI || '　様）';
--                 ELSE
--                   MJIDO_WORK(ICNT).ATESAKI_JODAN  := NSHIMEI_KANJI || '　様';
--                 END IF;
--               ELSE
--                 MJIDO_WORK(ICNT).ATESAKI_JODAN  := NULL;
--               END IF;
--             ELSE
--                   IF (RHOGO_SOFU.KOJIN_NO IS NOT NULL) AND 
--                          (RHOGO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND 
--                          (RHOGO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RHOGO_SOFU.SHURYO_BI = 0) THEN
--                          IF RHOGO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
--                             NSHIMEI_KANJI := RHOGO_SOFU.SHIMEI_KANJI;
--                          ELSE
--                             NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
--                             IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
--                               I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANJI,RHOGO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                             END IF;
--                          END IF;
--                       ELSE
--                          NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
--                          IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
--                            I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANJI,RHOGO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                          END IF;
--                       END IF;
--               IF LENGTH(NSHIMEI_KANJI) > 0 THEN
--                 IF VKOMOKU_HOGOSHA = 1 THEN
--                   MJIDO_WORK(ICNT).ATESAKI_JODAN := '（' || NSHIMEI_KANJI || '　様）';
--                 ELSE
--                   MJIDO_WORK(ICNT).ATESAKI_JODAN  := NSHIMEI_KANJI || '　様';  
--                 END IF;  
--               ELSE
--                 MJIDO_WORK(ICNT).ATESAKI_JODAN  := NULL;
--               END IF;
--             END IF;
            --宛先下段
--             IF VKOMOKU_SEIGYO = 2 THEN
--                   IF (RJIDO_SOFU.KOJIN_NO IS NOT NULL) AND 
--                          (RJIDO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND 
--                          (RJIDO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RJIDO_SOFU.SHURYO_BI = 0) THEN
--                          IF RJIDO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
--                             NSHIMEI_KANJI := RJIDO_SOFU.SHIMEI_KANJI;
--                          ELSE
--                             NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
--                             IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
--                               I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANJI,RJIDO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                             END IF;
--                          END IF;
--                       ELSE
--                          NSHIMEI_KANJI := RJIDO_ATENA.SHIMEI_KANJI;
--                          IF RJIDO_ATENA.JINKAKU_KBN = 1 THEN
--                            I_RTN  := FUNC_SEIGYO_SET(RJIDO_ATENA.HONMYO_KANJI,RJIDO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                          END IF;
--                       END IF;
--               IF LENGTH(NSHIMEI_KANJI) > 0 THEN
--                 IF VKOMOKU_DOJI = 1 THEN
--                   MJIDO_WORK(ICNT).ATESAKI_GEDAN  := '（' || NSHIMEI_KANJI || '　様）';
--                 ELSE
--                   MJIDO_WORK(ICNT).ATESAKI_GEDAN  :=  NSHIMEI_KANJI || '　様';
--                 END IF;  
--               ELSE
--                 MJIDO_WORK(ICNT).ATESAKI_GEDAN  :=  NULL;
--               END IF;
--             ELSIF  VKOMOKU_SEIGYO = 3 THEN
--                   IF (RHOGO_SOFU.KOJIN_NO IS NOT NULL) AND 
--                          (RHOGO_SOFU.TEKIYO_BI <= ISAKUSEIBI) AND 
--                          (RHOGO_SOFU.SHURYO_BI >= ISAKUSEIBI OR RHOGO_SOFU.SHURYO_BI = 0) THEN
--                          IF RHOGO_SOFU.SHIMEI_KANJI IS NOT NULL THEN
--                             NSHIMEI_KANJI := RHOGO_SOFU.SHIMEI_KANJI;
--                          ELSE
--                             NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
--                             IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
--                               I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANJI,RHOGO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                             END IF;
--                          END IF;
--                       ELSE
--                          NSHIMEI_KANJI := RHOGO_ATENA.SHIMEI_KANJI;
--                          IF RHOGO_ATENA.JINKAKU_KBN = 1 THEN
--                            I_RTN  := FUNC_SEIGYO_SET(RHOGO_ATENA.HONMYO_KANJI,RHOGO_ATENA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                          END IF;
--                       END IF;
--               IF LENGTH(NSHIMEI_KANJI) > 0 THEN
--                 IF VKOMOKU_HOGOSHA = 1 THEN
--                   MJIDO_WORK(ICNT).ATESAKI_GEDAN  := '（' || NSHIMEI_KANJI || '　様）';
--                 ELSE
--                   MJIDO_WORK(ICNT).ATESAKI_GEDAN  := NSHIMEI_KANJI || '　様'; 
--                 END IF;
--               ELSE
--                 MJIDO_WORK(ICNT).ATESAKI_GEDAN  := NULL;
--               END IF;
--             ELSE
--               MJIDO_WORK(ICNT).ATESAKI_GEDAN  := NULL;
--             END IF;
--2024/06/27 ZCZL.shixinyu Delete end
      BEGIN
      SELECT NVL(KYOIKUIINKAI_CD,0)
        INTO KYOIKUIINKAI_CD 
        FROM GKBTCHUGAKKO
       WHERE TYUGAKO_CD= RGAKUREIBO.TYUGAKO_CD;
      EXCEPTION
             WHEN NO_DATA_FOUND THEN
               KYOIKUIINKAI_CD := 0; 
             END;     
      -- 教育委員会情報を取得
      o_KYOIKUKAI_PRM := A_CONS_PRM();
      IF KYOIKUIINKAI_CD IS NOT NULL THEN 
        I_RTN := KKAPK0030.FPRMSHUTOKU(c_VGYOMU_CD,
                                      c_VKYOIKUKAI_SEIGYO_CD,                                 
                                      KYOIKUIINKAI_CD,
                                      o_KYOIKUKAI_PRM,
                                      o_LENGTH);
        IF I_RTN = 1 THEN
                      o_KYOIKUKAI_PRM := A_CONS_PRM();
                      o_KYOIKUKAI_PRM.EXTEND;
                      o_KYOIKUKAI_PRM.EXTEND;
                      o_KYOIKUKAI_PRM(1) := ' ';
                      o_KYOIKUKAI_PRM.EXTEND;
                      o_KYOIKUKAI_PRM(2) := ' ';
                      o_KYOIKUKAI_PRM.EXTEND;
                      o_KYOIKUKAI_PRM(3) := ' ';
                      o_KYOIKUKAI_PRM.EXTEND;
                      o_KYOIKUKAI_PRM(4) := ' ';
                      o_KYOIKUKAI_PRM.EXTEND;
                      o_KYOIKUKAI_PRM(5) := ' ';
                      o_KYOIKUKAI_PRM.EXTEND;
                      o_KYOIKUKAI_PRM(6) := ' ';
                      o_KYOIKUKAI_PRM.EXTEND;
                      o_KYOIKUKAI_PRM(7) := ' ';
                      o_KYOIKUKAI_PRM.EXTEND;
                      o_KYOIKUKAI_PRM(8) := ' ';
        ELSE
          WHILE (o_LENGTH < 8) LOOP
            o_KYOIKUKAI_PRM.EXTEND;
            o_KYOIKUKAI_PRM(o_LENGTH+1) := ' ';
            o_LENGTH := o_LENGTH + 1;
          END LOOP;
        END IF;
       VKYOIKUKAI_MEI     :=  o_KYOIKUKAI_PRM(1);        -- 教育委員会名
       VYAKUSHOKU_MEI     :=  o_KYOIKUKAI_PRM(2);        -- 役職名
       VSHUTHOU_MEI       :=  o_KYOIKUKAI_PRM(3);        -- 首長名
       VRITSU_MEI         :=  o_KYOIKUKAI_PRM(4);        -- ○○立
       VYUBIN_NO          :=  o_KYOIKUKAI_PRM(5);        -- 郵便番号
       VJUSHO             :=  o_KYOIKUKAI_PRM(6);        -- 住所
       VTEL_NO            :=  o_KYOIKUKAI_PRM(7);        -- 電話番号
       VNAISEN            :=  o_KYOIKUKAI_PRM(8);        -- 内線 
      ELSE 
       VKYOIKUKAI_MEI     :=  ' ';        -- 教育委員会名
       VYAKUSHOKU_MEI     :=  ' ';        -- 役職名
       VSHUTHOU_MEI       :=  ' ';        -- 首長名
       VRITSU_MEI         :=  ' ';        -- ○○立
       VYUBIN_NO          :=  ' ';        -- 郵便番号
       VJUSHO             :=  ' ';        -- 住所
       VTEL_NO            :=  ' ';        -- 電話番号
       VNAISEN            :=  ' ';        -- 内線 
      END IF;
            MJIDO_WORK(ICNT).KYOIKUKAI_MEI :=   VKYOIKUKAI_MEI;
            MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI := VYAKUSHOKU_MEI;
            MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI := VSHUTHOU_MEI;
            MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI := VRITSU_MEI;
            MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO := VYUBIN_NO;
            MJIDO_WORK(ICNT).KYOIKU_JUSHO := VJUSHO;
            MJIDO_WORK(ICNT).KYOIKU_TEL := VTEL_NO;
            MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN := VNAISEN;            
            MJIDO_WORK(ICNT).CHOHYO_NO := RGAKUREIBO.CHOHYO_NO;
            NCHOHYO_NO2 := TRIM(RGAKUREIBO.CHOHYO_NO);
            NCHOHYO_NO2 := LPAD(NCHOHYO_NO2,5,' ');
            IF MJIDO_WORK(ICNT).GAKOKU_CD IS NOT NULL THEN
              IGAKKO_CD2 := TRIM(TO_CHAR(MJIDO_WORK(ICNT).GAKOKU_CD));
              IGAKKO_CD2 := LPAD(MJIDO_WORK(ICNT).GAKOKU_CD,5,' ');
            ELSE
              IGAKKO_CD2 := NULL;
            END IF;
            CASE VYINJI_PATTERN
              WHEN  0 THEN  MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := ' ';
              WHEN  1 THEN  MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := NCHOHYO_NO2;
              WHEN  2 THEN  MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := VGAKOMEI  || '-' || 
                                                                NCHOHYO_NO2;
              WHEN  3 THEN  MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := IGAKKO_CD2 || '-' || 
                                                                NCHOHYO_NO2;
              WHEN  4 THEN  MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := VGAKOMEI || '-'  || 
                                                                VGYOSEIKU_MEI || '-'  ||
                                                                NCHOHYO_NO2;
              WHEN  5 THEN  MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO := IGAKKO_CD2 || '-' ||
                                                                VGYOSEIKU_MEI || '-'  ||
                                                                NCHOHYO_NO2;   
              ELSE                MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO :=  ' ';
            END CASE;
            IWAREKI1 := 0;
            ISEIREKI1 := VKIJUNBI;
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
            VKIJUNBI1   := VEDIT_GYYMMDD3;
            MJIDO_WORK(ICNT).KIJUN_BI := VKIJUNBI1;
            IKISAI_JUNI := 0;
            BEGIN
              SELECT KISAI_JUNI INTO IKISAI_JUNI
                FROM GABTJUKIIDO
               WHERE KOJIN_NO = CRJIDO.KOJIN_NO;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                IKISAI_JUNI := 0;
              WHEN OTHERS THEN
                IKISAI_JUNI := 0;
            END;
            MJIDO_WORK(ICNT).KISAI_JUNI := IKISAI_JUNI;                    --記載順位
            -- 小学校
            MJIDO_WORK(ICNT).SYOGAKO_CD := ISHOGAKO_CD;
            MJIDO_WORK(ICNT).SYOGAKOMEI := VSHOGAKOMEI;
            -- 中学校
            MJIDO_WORK(ICNT).TYUGAKO_CD := IGAKO_CD;
            MJIDO_WORK(ICNT).TYUGAKOMEI := VGAKOMEI;
            IRTN := GAAPK0030.FGETATENA(MJIDO_WORK(ICNT).JIDO_KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), o_RATENA_REC, o_RSOFU_REC);
            MJIDO_WORK(ICNT).JINKAKU_KBN := o_RATENA_REC.JINKAKU_KBN;

            -- 児童情報をセット
            IF CRJIDO.JD_JUMIN_NAKUNARU <>  0 THEN
              --日付変換
              IWAREKIHIZUKE  := 0;
              BRTNSASKUSEIBI := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,
                                                    CRJIDO.JD_JUMIN_NAKUNARU,
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
              MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU    := VEDIT_GYYMMDD3;
            ELSE
              MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU    := '';
            END IF;
            MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU_JIYU   := CRJIDO.JD_JUMIN_NAKUNARU_JIYU;
            MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU_JIYUNM := CRJIDO.JD_JUMIN_NAKUNARU_JIYUNM;

            -- GABVATENAALLより最新の減情報をチェック（保護者）
            -- 初期化
            ISEIREKI := 0;
            MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU        := '';
            MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYU   := 0;
            MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYUNM := '';
            -- 保護者宛名番号がある場合
            IF RGAKUREIBO.HOGOSYA_KOJIN_NO <> 0 THEN
              BEGIN
                SELECT NVL(JUMIN_NAKUNARU, 0), NVL(JUMIN_NAKUNARU_JIYU, 0), GAAPK0030.FIDOJIYUMEI(JUMIN_NAKUNARU_JIYU) 
                  INTO  ISEIREKI
                       ,MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYU
                       ,MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYUNM
                  FROM GABVATENAALL
                 WHERE KOJIN_NO = RGAKUREIBO.HOGOSYA_KOJIN_NO AND RIREKI_RENBAN = 999;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU        := '';
                  MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYU   := 0;
                  MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYUNM := '';
                WHEN OTHERS THEN
                  MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU        := '';
                  MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYU   := 0;
                  MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYUNM := '';
              END;
            END IF;
            -- 住民でなくなる日（保護者）がある場合
            IF ISEIREKI <>  0 THEN
              --日付変換
              IWAREKIHIZUKE  := 0;
              BRTNSASKUSEIBI := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,
                                                    ISEIREKI,
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

              MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU    := VEDIT_GYYMMDD3;
            ELSE
              MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU    := '';
            END IF;

--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
            --児童生徒_支援措置取得
            NPRTN := GAAPK0030.FGETDV(RGAKUREIBO.KOJIN_NO,MJIDO_WORK(ICNT).SETAI_NO,TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),'GKB',0,nKOJINSETAIKBN,nYOKUSHIKBN,nIDOYOKUSHIKBN,nHAKKOYOKUSHIKBN,nSHOKAIYOKUSHIKBN,vSHORICHUIKBN);
-- 2025/06/04 CTC.HJF UPDATE Start 1.0.007.000:GKB_QA13919対応
            --IF nYOKUSHIKBN = 1 THEN
            IF nYOKUSHIKBN > 0 AND nYOKUSHIKBN < 99 THEN
-- 2025/06/04 CTC.HJF UPDATE End
             MJIDO_WORK(ICNT).JIDO_SHIENSOCHI := '対象';
            ELSIF nYOKUSHIKBN = 0 THEN
             MJIDO_WORK(ICNT).JIDO_SHIENSOCHI := '';
            END IF;
            --保護者_支援措置取得
            NPRTN := GAAPK0030.FGETDV(RGAKUREIBO.HOGOSYA_KOJIN_NO,MJIDO_WORK(ICNT).SETAI_NO,TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),'GKB',0,nKOJINSETAIKBN,nYOKUSHIKBN,nIDOYOKUSHIKBN,nHAKKOYOKUSHIKBN,nSHOKAIYOKUSHIKBN,vSHORICHUIKBN);
-- 2025/06/04 CTC.HJF UPDATE Start 1.0.007.000:GKB_QA13919対応
            --IF nYOKUSHIKBN = 1 THEN
            IF nYOKUSHIKBN > 0 AND nYOKUSHIKBN < 99 THEN
-- 2025/06/04 CTC.HJF UPDATE End
             MJIDO_WORK(ICNT).HOGOSHA_SHIENSOCHI := '対象';
            ELSIF nYOKUSHIKBN = 0 THEN
             MJIDO_WORK(ICNT).HOGOSHA_SHIENSOCHI := '';
            END IF;
--  2025/09/11 CTC.XIAOMINGBO UPDATE START 1.0.105.000:GKB_QA20562対応
            MJIDO_WORK(ICNT).GAKKO_KBN_CD := '02';      --学校区分コード
            --MJIDO_WORK(ICNT).GAKKO_KBN_CD := RGAKUREIBO.GAKKO_KBN_CD;      --学校区分コード
--  2025/09/11 CTC.XIAOMINGBO UPDATE END
--  2024/06/27 ZCZL.shixinyu Add end
            ICNT := ICNT + 1;               -- カウントアップ
            IFRET := c_ISUCCESS;              -- 正常終了
          ELSE
            NULL;
          END IF;
        END LOOP;
        RETURN IFRET;
      EXCEPTION
        WHEN OTHERS THEN
          IFRET := c_INOT_SUCCESS;      -- 異常終了
          -- SQL情報取得
          N_SQL_CODE := SQLCODE;
          V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
          -- 処理ログの出力
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCBREAK_DATA_SHOKIKA', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1); 
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
        RETURN IFRET;
    END FUNC_GET_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 児童ワーク中間（GKBWJIDOTSUCHI）テーブルの作成
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
          INSERT INTO GKBWJIDOTSUCHI
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
                 DATE1,
                 DATE2,
                 DATE3,
                 DATE4,
                 DATE5,
                 KOMOKU1,
                 KOMOKU2,
                 KOMOKU3,
                 KOMOKU4,
                 KOMOKU5,
                 KOMOKU6,
                 KOMOKU7,
                 KOMOKU8,
                 KOMOKU9,
                 KOMOKU10,
                 DATE_MEI1,
                 DATE_MEI2,
                 DATE_MEI3,
                 DATE_MEI4,
                 DATE_MEI5,
                 KOMOKU_MEI1,
                 KOMOKU_MEI2,
                 KOMOKU_MEI3,
                 KOMOKU_MEI4,
                 KOMOKU_MEI5,
                 KOMOKU_MEI6,
                 KOMOKU_MEI7,
                 KOMOKU_MEI8,
                 KOMOKU_MEI9,
                 KOMOKU_MEI10
                ,YUBIN_NOBC
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
                 KISAI_JUNI
                 -- 小学校
                 , SYOGAKO_CD
                 , SYOGAKOMEI
                 -- 中学校
                 , TYUGAKO_CD
                 , TYUGAKOMEI
                 , JIDO_YUBIN_NO
                 , JIDO_YUBIN_NOBC
                 , JIDO_CHOMEI
                 , JIDO_BANCHI
                 , JIDO_KATAGAKI
                 ,ATESAKI_JODAN,
                 ATESAKI_GEDAN,
                 KYOIKUKAI_MEI,
                 KYOIKU_YAKUSHOKU_MEI,
                 KYOIKU_SHUTHOU_MEI,
                 KYOIKU_RITSU_MEI,
                 KYOIKU_YUBIN_NO,
                 KYOIKU_JUSHO,
                 KYOIKU_TEL,
                 KYOIKU_TEL_NAISEN,
                 CHOHYO_NO,
                 HYOJI_CHOHYO_NO,
                 KIJUN_BI
                ,JINKAKU_KBN
                 ,JD_JUMIN_NAKUNARU
                 ,JD_JUMIN_NAKUNARU_JIYU
                 ,JD_JUMIN_NAKUNARU_JIYUNM
                 ,HG_JUMIN_NAKUNARU
                 ,HG_JUMIN_NAKUNARU_JIYU
                 ,HG_JUMIN_NAKUNARU_JIYUNM
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
                 ,JIDO_SHIENSOCHI
                 ,HOGOSHA_SHIENSOCHI
                 ,KOIN_SHORYAKU
                 ,KOIN_CHUSHAKU
                 ,TITLE
                 ,TSUCHIBUN
                 ,TOKKIJIKO
                 ,BIKO
                 ,YOSHIKI_NO
                 ,BIKO_TITLE
                 ,GAKKO_KBN_CD
--  2024/06/27 ZCZL.shixinyu Add end
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
                 MJIDO_WORK(ICNT).DATE1,
                 MJIDO_WORK(ICNT).DATE2,
                 MJIDO_WORK(ICNT).DATE3,
                 MJIDO_WORK(ICNT).DATE4,
                 MJIDO_WORK(ICNT).DATE5,
                 MJIDO_WORK(ICNT).KOMOKU1,
                 MJIDO_WORK(ICNT).KOMOKU2,
                 MJIDO_WORK(ICNT).KOMOKU3,
                 MJIDO_WORK(ICNT).KOMOKU4,
                 MJIDO_WORK(ICNT).KOMOKU5,
                 MJIDO_WORK(ICNT).KOMOKU6,
                 MJIDO_WORK(ICNT).KOMOKU7,
                 MJIDO_WORK(ICNT).KOMOKU8,
                 MJIDO_WORK(ICNT).KOMOKU9,
                 MJIDO_WORK(ICNT).KOMOKU10,
                 MJIDO_WORK(ICNT).DATE_MEI1,
                 MJIDO_WORK(ICNT).DATE_MEI2,
                 MJIDO_WORK(ICNT).DATE_MEI3,
                 MJIDO_WORK(ICNT).DATE_MEI4,
                 MJIDO_WORK(ICNT).DATE_MEI5,
                 MJIDO_WORK(ICNT).KOMOKU_MEI1,
                 MJIDO_WORK(ICNT).KOMOKU_MEI2,
                 MJIDO_WORK(ICNT).KOMOKU_MEI3,
                 MJIDO_WORK(ICNT).KOMOKU_MEI4,
                 MJIDO_WORK(ICNT).KOMOKU_MEI5,
                 MJIDO_WORK(ICNT).KOMOKU_MEI6,
                 MJIDO_WORK(ICNT).KOMOKU_MEI7,
                 MJIDO_WORK(ICNT).KOMOKU_MEI8,
                 MJIDO_WORK(ICNT).KOMOKU_MEI9,
                 MJIDO_WORK(ICNT).KOMOKU_MEI10
                ,MJIDO_WORK(ICNT).YUBIN_NOBC
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
                 MJIDO_WORK(ICNT).KISAI_JUNI
                 -- 小学校
                 , MJIDO_WORK(ICNT).SYOGAKO_CD
                 , MJIDO_WORK(ICNT).SYOGAKOMEI
                 -- 中学校
                 , MJIDO_WORK(ICNT).TYUGAKO_CD
                 , MJIDO_WORK(ICNT).TYUGAKOMEI
                 , MJIDO_WORK(ICNT).JIDO_YUBIN_NO
                 , MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC
                 , MJIDO_WORK(ICNT).JIDO_CHOMEI
                 , MJIDO_WORK(ICNT).JIDO_BANCHI
                 , MJIDO_WORK(ICNT).JIDO_KATAGAKI
                 ,MJIDO_WORK(ICNT).ATESAKI_JODAN,
                 MJIDO_WORK(ICNT).ATESAKI_GEDAN,
                 MJIDO_WORK(ICNT).KYOIKUKAI_MEI,
                 MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI,
                 MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI,
                 MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI,
                 MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO,
                 MJIDO_WORK(ICNT).KYOIKU_JUSHO,
                 MJIDO_WORK(ICNT).KYOIKU_TEL,
                 MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN,
                 MJIDO_WORK(ICNT).CHOHYO_NO,
                 MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO,
                 MJIDO_WORK(ICNT).KIJUN_BI
                ,MJIDO_WORK(ICNT).JINKAKU_KBN
                 ,MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU
                 ,MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU_JIYU
                 ,MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU_JIYUNM
                 ,MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU
                 ,MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYU
                 ,MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYUNM
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
                 ,MJIDO_WORK(ICNT).JIDO_SHIENSOCHI
                 ,MJIDO_WORK(ICNT).HOGOSHA_SHIENSOCHI
                 ,rGKBTTSUCHISHOKANRI.KOIN_SHORYAKU
                 ,rGKBTTSUCHISHOKANRI.KOIN_CHUSHAKU
                 ,rGKBTTSUCHISHOKANRI.CHOHYO_MEI
                 ,REPLACE(rGKBTTSUCHISHOKANRI.TSUCHIBUN,chr(13)||chr(10),'#')
                 ,REPLACE(rGKBTTSUCHISHOKANRI.TOKKIJIKO,chr(13)||chr(10),'#')
                 ,rGKBTTSUCHISHOKANRI.BIKO
                 ,rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO
                 ,rGKBTTSUCHISHOKANRI.BIKO_TITLE
                 ,MJIDO_WORK(ICNT).GAKKO_KBN_CD
--  2024/06/27 ZCZL.shixinyu Add end
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
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1); 
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
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1); 
        RETURN IFRET;
    END FUNC_INSERT_JIDO_WK;
    --------------------------------------------------------------------------------
    -- 児童生徒中間（GKBWJIDOTSUCHI）テーブルの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
      FRET                PLS_INTEGER;                -- 戻り値
      ICNT                BINARY_INTEGER;             -- カウント
      VSQL                NVARCHAR2(10000);           -- ＳＱＬ文
      VSQLSEL             NVARCHAR2(9000);            -- ＳＱＬのソート以外
      VSQLORDER           NVARCHAR2(1000);            -- ＳＱＬの［ORDER BY］句
      VSQLWHERE           NVARCHAR2(1000);            -- ＳＱＬの[WHERE]句
      I_CUR               PLS_INTEGER;                -- カーソル
      RREC                GKBWJIDOTSUCHI%ROWTYPE;     -- 入学通知台帳のレコード変数
      NROWS               NUMBER;                     --
      IPAGECNT            PLS_INTEGER;                -- 頁数
      IGYOCNT             PLS_INTEGER;                -- 行番号
      IGYORENBAN          PLS_INTEGER;                -- 行連番
      vORDER_BY           NVARCHAR2(1000);

    BEGIN
      FRET := c_ISUCCESS;                  -- 正常終了
      VPAGEWORK := '';
      IGYOCNT := 0;
      ICNT := 0;
      MJIDO_WORK.DELETE;                   -- ワーク領域の初期化
      vORDER_BY := FUNC_GETSORTCOLS(401);
      -- ソート条件取得
         IF VHCHOHYO_RENBAN = 0 THEN
            VSQLORDER := ' GAKOKU_CD,GYOSEIKU_CD,CHOHYO_NO ';
         ELSE
            IF KKAPK0010.FTrim(vORDER_BY) IS NOT NULL THEN
              VSQLORDER := vORDER_BY;
            END IF;
         END IF;
      -- ［ORDER BY］句を付加
      IF VSQLORDER IS NOT NULL THEN
         VSQLORDER := ' ORDER BY ' || VSQLORDER;
      END IF;
      
      VPAGENM := ' GAKOKUMEI ';
      VPAGEFD := ' GAKOKU_CD ';
      
      -- 22:死亡、23:職権消除、25:失踪宣告は通知書発行から除外する。

--  2024/06/27 ZCZL.shixinyu Update 0.3.000.000:新WizLIFE２次開発
--      VSQLWHERE := ' WHERE ( HG_JUMIN_NAKUNARU_JIYU NOT IN (22, 23, 25) AND JD_JUMIN_NAKUNARU_JIYU NOT IN (22, 23, 25) ) ';
      VSQLWHERE := ' WHERE ( HG_JUMIN_NAKUNARU_JIYU NOT IN (220, 230, 250) AND JD_JUMIN_NAKUNARU_JIYU NOT IN (220, 230, 250) ) ';
      IF VTYUGAKO_CD IS NOT NULL THEN
        VSQLWHERE := VSQLWHERE || ' AND TYUGAKO_CD  IN ('|| VTYUGAKO_CD || ') ';
      END IF;

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
        IF VHCHOHYO_RENBAN = 0 THEN
          IF VYINJI_PATTERN IN (1,2,3)  THEN
            VSQLSEL := VSQLSEL || '  GAKOKU_CD '|| ' PAGE_FIELD, ';
            VSQLSEL := VSQLSEL || ' GAKOKUMEI ' || ' PAGE_NAME, ';
          ELSIF VYINJI_PATTERN IN (4,5)  THEN
            VSQLSEL := VSQLSEL || ' GAKOKU_CD || GYOSEIKU_CD '|| ' PAGE_FIELD, ';
            VSQLSEL := VSQLSEL || ' GAKOKUMEI || '' '' || GYOSEIKUMEI '|| ' PAGE_NAME, ';
          ELSE
            VSQLSEL := VSQLSEL || 'null as PAGE_FIELD, ';
            VSQLSEL := VSQLSEL || 'null as PAGE_NAME, ';
          END IF;
        ELSE
          VSQLSEL := VSQLSEL || VPAGEFD ||' PAGE_FIELD, ';
          VSQLSEL := VSQLSEL || VPAGENM ||' PAGE_NAME, ';
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
        VSQLSEL := VSQLSEL || ',ZOKUGARAMEI1 ';
        VSQLSEL := VSQLSEL || ',ZOKUGARAMEI2 ';
        -- 小学校
        VSQLSEL := VSQLSEL || ', SYOGAKO_CD ';
        VSQLSEL := VSQLSEL || ', SYOGAKOMEI ';
        -- 中学校
        VSQLSEL := VSQLSEL || ', TYUGAKO_CD ';
        VSQLSEL := VSQLSEL || ', TYUGAKOMEI ';
        VSQLSEL := VSQLSEL || ', JIDO_YUBIN_NO ';
        VSQLSEL := VSQLSEL || ', JIDO_YUBIN_NOBC ';
        VSQLSEL := VSQLSEL || ', JIDO_CHOMEI ';
        VSQLSEL := VSQLSEL || ', JIDO_BANCHI ';
        VSQLSEL := VSQLSEL || ', JIDO_KATAGAKI ';
        VSQLSEL := VSQLSEL || ', ATESAKI_JODAN ';
        VSQLSEL := VSQLSEL || ', ATESAKI_GEDAN ';
        VSQLSEL := VSQLSEL || ', KYOIKUKAI_MEI ';
        VSQLSEL := VSQLSEL || ', KYOIKU_YAKUSHOKU_MEI ';
        VSQLSEL := VSQLSEL || ', KYOIKU_SHUTHOU_MEI ';
        VSQLSEL := VSQLSEL || ', KYOIKU_RITSU_MEI ';
        VSQLSEL := VSQLSEL || ', KYOIKU_YUBIN_NO ';
        VSQLSEL := VSQLSEL || ', KYOIKU_JUSHO ';
        VSQLSEL := VSQLSEL || ', KYOIKU_TEL ';
        VSQLSEL := VSQLSEL || ', KYOIKU_TEL_NAISEN';
        VSQLSEL := VSQLSEL || ', CHOHYO_NO ';
        VSQLSEL := VSQLSEL || ', HYOJI_CHOHYO_NO ';
        VSQLSEL := VSQLSEL || ', KIJUN_BI ';
        VSQLSEL := VSQLSEL || ', JINKAKU_KBN ';
        VSQLSEL := VSQLSEL || ', JD_JUMIN_NAKUNARU_JIYU ';           
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
        VSQLSEL := VSQLSEL || ', JIDO_SHIENSOCHI ';
        VSQLSEL := VSQLSEL || ', HOGOSHA_SHIENSOCHI ';
        VSQLSEL := VSQLSEL || ', KOIN_SHORYAKU ';
        VSQLSEL := VSQLSEL || ', KOIN_CHUSHAKU ';
        VSQLSEL := VSQLSEL || ', TITLE ';
        VSQLSEL := VSQLSEL || ', TSUCHIBUN ';
        VSQLSEL := VSQLSEL || ', TOKKIJIKO ';
        VSQLSEL := VSQLSEL || ', BIKO ';
        VSQLSEL := VSQLSEL || ', YOSHIKI_NO ';
        VSQLSEL := VSQLSEL || ', BIKO_TITLE ';
        VSQLSEL := VSQLSEL || ', GAKKO_KBN_CD ';
        VSQLSEL := VSQLSEL || ', JIDO_KOJIN_NO ';
        VSQLSEL := VSQLSEL || ', HOGOSHA_KOJIN_NO ';
--  2024/06/27 ZCZL.shixinyu Add end
-- 2025/07/16 CTC.Wang Add Start 1.0.100.000:新WizLIFE開発_帳票アウトソーシング連番対応
        VSQLSEL := VSQLSEL || ',YUHEN_KBN ';
-- 2025/07/16 CTC.Wang Add End
        VSQLSEL := VSQLSEL || 'FROM ';
        VSQLSEL := VSQLSEL || 'GKBWJIDOTSUCHI ';
        -- ひとつのＳＱＬ文にする
        VSQL := VSQLSEL || VSQLWHERE || VSQLORDER;
        -- カーソルのオープン
        I_CUR := DBMS_SQL.OPEN_CURSOR;
        -- ＳＱＬ文の解析
        DBMS_SQL.PARSE(I_CUR, VSQL, DBMS_SQL.NATIVE);
        -- 取得する列の定義
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, RREC.NENDO, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, RREC.KAIPEJI_CD, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, RREC.KAIPEJI, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.SAKUSEIBI, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.RENBAN );
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.JIDO_SHIMEI_KANA, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.JIDO_SHIMEI_KANJI, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.HYOJI_SEINENGAPI, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.KANJI_SEINENGAPI, 13);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.HYOJI_SEIBETSU, 1);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.HOGOSHA_SHIMEI_JODAN, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.HOGOSHA_SHIMEI_GEDAN, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.KON_JUSHO_JODAN, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.KON_JUSHO_GEDAN, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.GYOSEIKUMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.GAKOKUMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.SANTEIDANTAIMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.YUBIN_NO, 10);
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.CHOMEI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.BANCHI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.KATAGAKI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.CHOMEI, 136);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.BANCHI, 50);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.KATAGAKI, 300);
--  2024/06/27 ZCZL.shixinyu Update end
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, VPAGEFD, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, VPAGENM, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.DATE1, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.DATE2, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.DATE3, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.DATE4, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.DATE5, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, RREC.KOMOKU1, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, RREC.KOMOKU2, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, RREC.KOMOKU3, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, RREC.KOMOKU4, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, RREC.KOMOKU5, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 34, RREC.KOMOKU6, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 35, RREC.KOMOKU7, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 36, RREC.KOMOKU8, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 37, RREC.KOMOKU9, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 38, RREC.KOMOKU10, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 39, RREC.DATE_MEI1, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 40, RREC.DATE_MEI2, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 41, RREC.DATE_MEI3, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 42, RREC.DATE_MEI4, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 43, RREC.DATE_MEI5, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 44, RREC.KOMOKU_MEI1, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 45, RREC.KOMOKU_MEI2, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 46, RREC.KOMOKU_MEI3, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 47, RREC.KOMOKU_MEI4, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 48, RREC.KOMOKU_MEI5, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 49, RREC.KOMOKU_MEI6, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 50, RREC.KOMOKU_MEI7, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 51, RREC.KOMOKU_MEI8, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 52, RREC.KOMOKU_MEI9, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 53, RREC.KOMOKU_MEI10, 40);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 54, RREC.GAKOKU_CD );
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 55, RREC.YUBIN_NOBC, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 56, RREC.ZOKUGARAMEI1, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 57, RREC.ZOKUGARAMEI2, 30);
        -- 小学校
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 58, RREC.SYOGAKO_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 59, RREC.SYOGAKOMEI, 60);
        -- 中学校
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 60, RREC.TYUGAKO_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 61, RREC.TYUGAKOMEI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 62, RREC.JIDO_YUBIN_NO, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 63, RREC.JIDO_YUBIN_NOBC, 30);
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 64, RREC.JIDO_CHOMEI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 65, RREC.JIDO_BANCHI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 66, RREC.JIDO_KATAGAKI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 64, RREC.JIDO_CHOMEI, 136);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 65, RREC.JIDO_BANCHI, 50);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 66, RREC.JIDO_KATAGAKI, 300);
--  2024/06/27 ZCZL.shixinyu Update end
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 67, RREC.ATESAKI_JODAN, 110); 
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 68, RREC.ATESAKI_GEDAN, 110); 
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 69, RREC.KYOIKUKAI_MEI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 70, RREC.KYOIKU_YAKUSHOKU_MEI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 71, RREC.KYOIKU_SHUTHOU_MEI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 72, RREC.KYOIKU_RITSU_MEI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 73, RREC.KYOIKU_YUBIN_NO, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 74, RREC.KYOIKU_JUSHO, 100);
--  2025/08/22 CTC.GYY UPDATE 1.0.102.000:GKB_QA19542対応　START
        --DBMS_SQL.DEFINE_COLUMN(I_CUR, 75, RREC.KYOIKU_TEL, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 75, RREC.KYOIKU_TEL, 60);
--  2025/08/22 CTC.GYY UPDATE 1.0.102.000:GKB_QA19542対応　END
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 76, RREC.KYOIKU_TEL_NAISEN, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 77, RREC.CHOHYO_NO);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 78, RREC.HYOJI_CHOHYO_NO, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 79, RREC.KIJUN_BI, 16);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 80, RREC.JINKAKU_KBN);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 81, RREC.JD_JUMIN_NAKUNARU_JIYU);        
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 82, RREC.JIDO_SHIENSOCHI, 2);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 83, RREC.HOGOSHA_SHIENSOCHI, 2);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 84, RREC.KOIN_SHORYAKU, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 85, RREC.KOIN_CHUSHAKU, 120);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 86, RREC.TITLE, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 87, RREC.TSUCHIBUN, 300);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 88, RREC.TOKKIJIKO, 700);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 89, RREC.BIKO, 1000);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 90, RREC.YOSHIKI_NO, 34);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 91, RREC.BIKO_TITLE, 2);
--  2025/09/11 CTC.XIAOMINGBO UPDATE START 1.0.105.000:GKB_QA20562対応
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 92, RREC.GAKKO_KBN_CD,3);
        --DBMS_SQL.DEFINE_COLUMN(I_CUR, 92, RREC.GAKKO_KBN_CD);
--  2025/09/11 CTC.XIAOMINGBO UPDATE END
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 93, RREC.JIDO_KOJIN_NO);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 94, RREC.HOGOSHA_KOJIN_NO);
--  2024/06/27 ZCZL.shixinyu Add end
-- 2025/07/16 CTC.Wang Add Start 1.0.100.000:新WizLIFE開発_帳票アウトソーシング連番対応
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 95, RREC.YUHEN_KBN);
-- 2025/07/16 CTC.Wang Add End
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
            DBMS_SQL.COLUMN_VALUE(I_CUR, 22, VPAGEFIELD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 23, VPAGENAME);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 24, MJIDO_WORK(ICNT).DATE1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 25, MJIDO_WORK(ICNT).DATE2);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 26, MJIDO_WORK(ICNT).DATE3);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 27, MJIDO_WORK(ICNT).DATE4);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 28, MJIDO_WORK(ICNT).DATE5);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 29, MJIDO_WORK(ICNT).KOMOKU1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 30, MJIDO_WORK(ICNT).KOMOKU2);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 31, MJIDO_WORK(ICNT).KOMOKU3);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 32, MJIDO_WORK(ICNT).KOMOKU4);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 33, MJIDO_WORK(ICNT).KOMOKU5);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 34, MJIDO_WORK(ICNT).KOMOKU6);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 35, MJIDO_WORK(ICNT).KOMOKU7);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 36, MJIDO_WORK(ICNT).KOMOKU8);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 37, MJIDO_WORK(ICNT).KOMOKU9);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 38, MJIDO_WORK(ICNT).KOMOKU10);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 39, MJIDO_WORK(ICNT).DATE_MEI1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 40, MJIDO_WORK(ICNT).DATE_MEI2);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 41, MJIDO_WORK(ICNT).DATE_MEI3);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 42, MJIDO_WORK(ICNT).DATE_MEI4);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 43, MJIDO_WORK(ICNT).DATE_MEI5);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 44, MJIDO_WORK(ICNT).KOMOKU_MEI1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 45, MJIDO_WORK(ICNT).KOMOKU_MEI2);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 46, MJIDO_WORK(ICNT).KOMOKU_MEI3);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 47, MJIDO_WORK(ICNT).KOMOKU_MEI4);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 48, MJIDO_WORK(ICNT).KOMOKU_MEI5);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 49, MJIDO_WORK(ICNT).KOMOKU_MEI6);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 50, MJIDO_WORK(ICNT).KOMOKU_MEI7);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 51, MJIDO_WORK(ICNT).KOMOKU_MEI8);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 52, MJIDO_WORK(ICNT).KOMOKU_MEI9);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 53, MJIDO_WORK(ICNT).KOMOKU_MEI10);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 54, MJIDO_WORK(ICNT).GAKOKU_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 55, MJIDO_WORK(ICNT).YUBIN_NOBC);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 56, MJIDO_WORK(ICNT).ZOKUGARAMEI1);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 57, MJIDO_WORK(ICNT).ZOKUGARAMEI2);
            -- 小学校
            DBMS_SQL.COLUMN_VALUE(I_CUR, 58, MJIDO_WORK(ICNT).SYOGAKO_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 59, MJIDO_WORK(ICNT).SYOGAKOMEI);
            -- 中学校
            DBMS_SQL.COLUMN_VALUE(I_CUR, 60, MJIDO_WORK(ICNT).TYUGAKO_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 61, MJIDO_WORK(ICNT).TYUGAKOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 62, MJIDO_WORK(ICNT).JIDO_YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 63, MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 64, MJIDO_WORK(ICNT).JIDO_CHOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 65, MJIDO_WORK(ICNT).JIDO_BANCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 66, MJIDO_WORK(ICNT).JIDO_KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 67, MJIDO_WORK(ICNT).ATESAKI_JODAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 68, MJIDO_WORK(ICNT).ATESAKI_GEDAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 69, MJIDO_WORK(ICNT).KYOIKUKAI_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 70, MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 71, MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 72, MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 73, MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 74, MJIDO_WORK(ICNT).KYOIKU_JUSHO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 75, MJIDO_WORK(ICNT).KYOIKU_TEL);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 76, MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 77, MJIDO_WORK(ICNT).CHOHYO_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 78, MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 79, MJIDO_WORK(ICNT).KIJUN_BI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 80, MJIDO_WORK(ICNT).JINKAKU_KBN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 81, MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU_JIYU);   
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
            DBMS_SQL.COLUMN_VALUE(I_CUR, 82, MJIDO_WORK(ICNT).JIDO_SHIENSOCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 83, MJIDO_WORK(ICNT).HOGOSHA_SHIENSOCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 84, MJIDO_WORK(ICNT).KOIN_SHORYAKU);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 85, MJIDO_WORK(ICNT).KOIN_CHUSHAKU);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 86, MJIDO_WORK(ICNT).TITLE);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 87, MJIDO_WORK(ICNT).TSUCHIBUN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 88, MJIDO_WORK(ICNT).TOKKIJIKO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 89, MJIDO_WORK(ICNT).BIKO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 90, MJIDO_WORK(ICNT).YOSHIKI_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 91, MJIDO_WORK(ICNT).BIKO_TITLE);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 92, MJIDO_WORK(ICNT).GAKKO_KBN_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 93, MJIDO_WORK(ICNT).JIDO_KOJIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 94, MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO);
--  2024/06/27 ZCZL.shixinyu Add end
-- 2025/07/16 CTC.Wang Add Start 1.0.100.000:新WizLIFE開発_帳票アウトソーシング連番対応
            DBMS_SQL.COLUMN_VALUE(I_CUR, 95, MJIDO_WORK(ICNT).YUHEN_KBN);
-- 2025/07/16 CTC.Wang Add End
            -- 以前の改頁項目値と同じ
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
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1); 
      END;
      RETURN FRET;
    END FUNC_GET_JIDO_WK_CSV;
    --------------------------------------------------------------------------------
    -- 入学通知書CSVの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE1 RETURN NUMBER IS
      FRET                PLS_INTEGER;                -- 戻り値
      ICNT                BINARY_INTEGER;             -- カウント
      IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
      IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
      VYUBIN_NO           NVARCHAR2(60);              --郵便番号編集用
      ICNT_1              BINARY_INTEGER := 0;        -- カウント
--  2024/06/27 ZCZL.shixinyu Update 0.3.000.000:新WizLIFE２次開発
--      r_CHOHYO_001        GKBWL040R001%ROWTYPE;
      r_CHOHYO_001        GKBWL030R001%ROWTYPE;
      nCOUNT              NUMBER;
      TACONSPRM           A_CONS_PRM;                 --戻るパラメータ配列
      NLENGTH             NUMBER;                     --配列件数
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
      sCTLPRM             NVARCHAR2(1000);            --住所マスク文字列
      nHANTEIKEKKA        PLS_INTEGER;                --抑止レベル３制御の要否（0：非該当、1：該当）
      nBUNSHOBANGO        NVARCHAR2(1000);            --文書番号
--  2024/06/27 ZCZL.shixinyu Add end
    BEGIN
      FRET := c_ISUCCESS;                  -- 正常終了
      VCHOHYO_NO := 0;                     -- 帳票連番初期化
      nCOUNT := 0;
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
      -- 担当電話
      BEGIN
        IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      4,          --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
        IF NLENGTH <> 0 THEN
        --担当電話が取得できた場合
          VTANTO_TEL := TACONSPRM(1);
        ELSE
        --担当電話が取得できない場合
          VTANTO_TEL := '';
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          VTANTO_TEL := '';
      END;
      -- 担当郵便番号
      BEGIN
        IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      2,          --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
        IF NLENGTH <> 0 THEN
        --担当郵便番号が取得できた場合
          VTANTO_YUBIN := TACONSPRM(1);
        ELSE
        --担当郵便番号が取得できない場合
          VTANTO_YUBIN := '';
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          VTANTO_YUBIN := '';
      END;
      -- 担当住所
      BEGIN
        IRTN := KKAPK0030.FPRMSHUTOKU('GKB',      --業務コード
                                      'SYSTEM',   --制御コンスタントコード
                                      3,          --制御コンスタント連番
                                      TACONSPRM,
                                      NLENGTH);
        IF NLENGTH <> 0 THEN
        --担当住所が取得できた場合
          VTANTO_JUSHO := TACONSPRM(1);
        ELSE
        --担当住所が取得できない場合
          VTANTO_JUSHO := '';
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          VTANTO_JUSHO := '';
      END;
      
--  2025/08/21 CTC.LIUJUNHAO ADD START 1.0.102.000:GKB_QA19314対応
       --公印ファイル名取得
       BEGIN            
            BRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE, 0),
                                       g_sWSNUM,
                                       TO_DATE(iKIJUNBI,'YYYYMMDD'),
                                       nDAIRIKBN,
                                       vKATAGAKI1,
                                       vKATAGAKI2,
                                       vSHIMEI,
                                       VGYOMU);
       EXCEPTION
        WHEN OTHERS THEN
           vKATAGAKI1  := NULL;
           vKATAGAKI2  := NULL;
           vSHIMEI     := NULL;
           VGYOMU      := NULL;
      END;
--  2025/08/21 CTC.LIUJUNHAO ADD END 1.0.102.000:GKB_QA19314対応

--  2025/07/31 CTC.GL UPDATE START 1.0.011.000:GKB_QA19054対応
      IF IMIN IS NOT NULL AND IMAX IS NOT NULL THEN
--  2025/07/31 CTC.GL UPDATE END
      -- 取得した件数分繰り返す
      FOR ICNT IN IMIN..IMAX LOOP
        nCOUNT := nCOUNT + 1;
        ICNT_1 := ICNT_1 + 1;
--2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
        --文書番号編集結果の取得
        IF rBUNNUMSRCINF.UOUT.NUMUMUFLG = 0 AND rBUNNUMSRCINF.NUMINCTYPE IN (1,2) THEN
            KKAPK0040.SBunNumIc(rBUNNUMSRCINF,rBUNNUMEDITKEKA);
        END IF;
--2024/06/27 ZCZL.shixinyu Add end
        r_CHOHYO_001 := NULL;
-- 2025/07/16 CTC.Wang Add Start 1.0.100.000:新WizLIFE開発_帳票アウトソーシング連番対応
        r_CHOHYO_001.KYOTSU_TSUSU_RENBAN        := LPAD(nCOUNT, 6, '0');                                -- 業務共通_通数連番
        r_CHOHYO_001.KYOTSU_PAGE_RENBAN         := NULL;                                                -- 業務共通_頁連番
        r_CHOHYO_001.KYOTSU_DOFU_RENBAN         := NULL;                                                -- 業務共通_同封内連番
        r_CHOHYO_001.KYOTSU_DOFU_MAISU          := NULL;                                                -- 業務共通_同封内枚数
        r_CHOHYO_001.KYOTSU_YUBIN_K_KBN         := NULL;                                                -- 業務共通_郵便局区分
        r_CHOHYO_001.KYOTSU_YUHEN_KBN           := MJIDO_WORK(ICNT).YUHEN_KBN;                          -- 業務共通_郵返区分
        r_CHOHYO_001.KYOTSU_CHOSHU_KBN          := NULL;                                                -- 業務共通_徴収区分
        r_CHOHYO_001.KYOTSU_GAKKO_KBN           := MJIDO_WORK(ICNT).GAKKO_KBN_CD;                       -- 業務共通_学校区分
        r_CHOHYO_001.KYOTSU_YOBI_AREA1          := NULL;                                                -- 業務共通_予備エリア1
        r_CHOHYO_001.KYOTSU_YOBI_AREA2          := NULL;                                                -- 業務共通_予備エリア2
        r_CHOHYO_001.KYOTSU_YOBI_AREA3          := NULL;                                                -- 業務共通_予備エリア3
        r_CHOHYO_001.KYOTSU_YOBI_AREA4          := NULL;                                                -- 業務共通_予備エリア4
        r_CHOHYO_001.KYOTSU_YOBI_AREA5          := NULL;                                                -- 業務共通_予備エリア5
        r_CHOHYO_001.KYOTSU_YOBI_AREA6          := NULL;                                                -- 業務共通_予備エリア6
        r_CHOHYO_001.KYOTSU_YOBI_AREA7          := NULL;                                                -- 業務共通_予備エリア7
        r_CHOHYO_001.KYOTSU_YOBI_AREA8          := NULL;                                                -- 業務共通_予備エリア8
        r_CHOHYO_001.KYOTSU_YOBI_AREA9          := NULL;                                                -- 業務共通_予備エリア9
        r_CHOHYO_001.KYOTSU_YOBI_AREA10         := NULL;                                                -- 業務共通_予備エリア10
        r_CHOHYO_001.KYOTSU_YOBI_AREA11         := NULL;                                                -- 業務共通_予備エリア11
        r_CHOHYO_001.KYOTSU_YOBI_AREA12         := NULL;                                                -- 業務共通_予備エリア12
-- 2025/07/16 CTC.Wang Add End
        r_CHOHYO_001.NO := nCOUNT;
        r_CHOHYO_001.NENDO := MJIDO_WORK(ICNT).NENDO;
        r_CHOHYO_001.KAIPAGE_CD := MJIDO_WORK(ICNT).KAIPEJI_CD;
        r_CHOHYO_001.KAIPAGE_MEI := MJIDO_WORK(ICNT).KAIPEJI;
        r_CHOHYO_001.KIJUNBI := VHASSOBI;                      --通知書には発送日をセット
        r_CHOHYO_001.RENBAN := MJIDO_WORK(ICNT).RENBAN;
        r_CHOHYO_001.JIDO_SHIMEI_KANA := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;
        r_CHOHYO_001.JIDO_SHIMEI_KANJI := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;
        r_CHOHYO_001.HYOJI_SEINENGAPI := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;
        r_CHOHYO_001.HYOJI_SEIBETSU := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;
        r_CHOHYO_001.HOGOSHA_SHIMEI_KANA := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN;
        r_CHOHYO_001.HOGOSHA_SHIMEI_KANJI := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;
        r_CHOHYO_001.JUSHO_JODAN := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;
        r_CHOHYO_001.JUSHO_GEDAN := MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;
        r_CHOHYO_001.GYOSEIKU_MEI := MJIDO_WORK(ICNT).GYOSEIKUMEI;
        r_CHOHYO_001.GAKKO_MEI := MJIDO_WORK(ICNT).GAKOKUMEI;
        r_CHOHYO_001.SANTEIDANTAI_MEI := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;
    -- 保護者の設定がない場合に郵便番号のハイフンのみが表示される不具合修正
        IF LENGTH(MJIDO_WORK(ICNT).YUBIN_NO) > 0 THEN
          VYUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO, 1, 3) || '-' || SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO, 4);
          VYUBIN_NO := TRANSLATE( VYUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
          r_CHOHYO_001.YUBIN_NO := VYUBIN_NO;
        ELSE
          r_CHOHYO_001.YUBIN_NO := MJIDO_WORK(ICNT).YUBIN_NO;
        END IF;
        r_CHOHYO_001.CHOMEI_BANCHI := MJIDO_WORK(ICNT).CHOMEI||MJIDO_WORK(ICNT).BANCHI;
        r_CHOHYO_001.KATAGAKI := MJIDO_WORK(ICNT).KATAGAKI;
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
--  2024/09/29 ZCZL.YUCHUFEI UPDATE 0.3.000.002:仕様変更 IT_GKB_00074対応
--         IF V_JYOUKEN07 = 0 THEN
        IF V_JYOUKEN07 = 1 THEN
          --抑止住所編集（送付先住所）
          sCTLPRM := GAAPK0030.FDVJUSHO('GKB', MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, r_CHOHYO_001.CHOMEI_BANCHI, nHANTEIKEKKA, 2, NULL, NULL);
          r_CHOHYO_001.CHOMEI_BANCHI := sCTLPRM;
          IF nHANTEIKEKKA = 1 THEN
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
            MJIDO_WORK(ICNT).YUBIN_NOBC := '';    --  郵便番号ＢＣ
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
            r_CHOHYO_001.YUBIN_NO := '';
            r_CHOHYO_001.KATAGAKI := '';
          END IF;
        END IF;
--  2024/06/27 ZCZL.shixinyu Add end
    -- 保護者の設定がない場合に”様”のみが表示されないように修正
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--        r_CHOHYO_001.ATESAKI_JODAN := MJIDO_WORK(ICNT).ATESAKI_JODAN;
--        r_CHOHYO_001.ATESAKI_GEDAN := MJIDO_WORK(ICNT).ATESAKI_GEDAN;
--        r_CHOHYO_001.KANJI_SEINENGAPI := MJIDO_WORK(ICNT).KANJI_SEINENGAPI;
--        r_CHOHYO_001.KYOIKU_KAI_MEI := MJIDO_WORK(ICNT).KYOIKUKAI_MEI;
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
--      r_CHOHYO_001.ATESAKI_JODAN := r_CHOHYO_001.HOGOSHA_SHIMEI_KANJI;
        r_CHOHYO_001.ATESAKI_JODAN := r_CHOHYO_001.HOGOSHA_SHIMEI_KANJI || '　様';
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
        r_CHOHYO_001.ATESAKI_GEDAN := NULL;
        r_CHOHYO_001.KANJI_SEINENGAPI := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;
        r_CHOHYO_001.KYOIKU_KAI_MEI := vKATAGAKI1;
--  2024/06/27 ZCZL.shixinyu Update end
        r_CHOHYO_001.NYUGAKU_KIJITU := NULL;
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
--      r_CHOHYO_001.HASSOBI := VHASOBI; --発行日
        r_CHOHYO_001.HASSOBI                    := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(VHASOBI, 0),' ',''),'　','');
                                                                                                   --  発送日
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
        r_CHOHYO_001.HASSO_NO := NULL;
        r_CHOHYO_001.KOIN_PATH :=  VGYOMU ;    -- 業務毎公印ファイル名（.bmp）
        r_CHOHYO_001.TANTO_TEL :=  MJIDO_WORK(ICNT).KYOIKU_TEL;
        IF LENGTH(MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO) > 3 THEN
          VTANTO_YUBIN := SUBSTR(MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO, 1, 3) || '-' || SUBSTR(MJIDO_WORK(ICNT).KYOIKU_YUBIN_NO, 4);
          VTANTO_YUBIN := TRANSLATE(VTANTO_YUBIN, '1234567890-', '１２３４５６７８９０－');
        ELSE
          VTANTO_YUBIN := NULL;
        END IF;
        r_CHOHYO_001.TANTO_YUBIN_NO := VTANTO_YUBIN;
        r_CHOHYO_001.TANTO_JUSHO := MJIDO_WORK(ICNT).KYOIKU_JUSHO;
    -- 教育委員会の郵便番号ではなくワークテーブルの郵便番号ＢＣをセットする
        r_CHOHYO_001.YUBIN_NOBC := MJIDO_WORK(ICNT).YUBIN_NOBC;  -- カスタマーバーコード
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
--      r_CHOHYO_001.DATE1 := MJIDO_WORK(ICNT).DATE1;
--      r_CHOHYO_001.DATE2 := MJIDO_WORK(ICNT).DATE2;
        r_CHOHYO_001.DATE1 := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(MJIDO_WORK(ICNT).DATE1, 0),' ',''),'　','');
                                                                                                   --  日付１
        r_CHOHYO_001.DATE2 := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(MJIDO_WORK(ICNT).DATE2, 0),' ',''),'　','');
                                                                                                   --  日付２
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
        r_CHOHYO_001.DATE3 := MJIDO_WORK(ICNT).DATE3;
        r_CHOHYO_001.DATE4 := MJIDO_WORK(ICNT).DATE4;
        r_CHOHYO_001.DATE5 := MJIDO_WORK(ICNT).DATE5;
        r_CHOHYO_001.KOMOKU1 := MJIDO_WORK(ICNT).KOMOKU1;
        r_CHOHYO_001.KOMOKU2 := MJIDO_WORK(ICNT).KOMOKU2;
        r_CHOHYO_001.KOMOKU3 := MJIDO_WORK(ICNT).KOMOKU3;
        r_CHOHYO_001.KOMOKU4 := MJIDO_WORK(ICNT).KOMOKU4;
        r_CHOHYO_001.KOMOKU5 := MJIDO_WORK(ICNT).KOMOKU5;
        r_CHOHYO_001.KOMOKU6 := MJIDO_WORK(ICNT).KOMOKU6;
        r_CHOHYO_001.KOMOKU7 := MJIDO_WORK(ICNT).KOMOKU7;
        r_CHOHYO_001.KOMOKU8 := MJIDO_WORK(ICNT).KOMOKU8;
        r_CHOHYO_001.KOMOKU9 := MJIDO_WORK(ICNT).KOMOKU9;
        r_CHOHYO_001.KOMOKU10 := MJIDO_WORK(ICNT).KOMOKU10;
        r_CHOHYO_001.DATE_MEI1 := MJIDO_WORK(ICNT).DATE_MEI1;
        r_CHOHYO_001.DATE_MEI2 := MJIDO_WORK(ICNT).DATE_MEI2;
        r_CHOHYO_001.DATE_MEI3 := MJIDO_WORK(ICNT).DATE_MEI3;
        r_CHOHYO_001.DATE_MEI4 := MJIDO_WORK(ICNT).DATE_MEI4;
        r_CHOHYO_001.DATE_MEI5 := MJIDO_WORK(ICNT).DATE_MEI5;
        r_CHOHYO_001.KOMOKU_MEI1 := MJIDO_WORK(ICNT).KOMOKU_MEI1;
        r_CHOHYO_001.KOMOKU_MEI2 := MJIDO_WORK(ICNT).KOMOKU_MEI2;
        r_CHOHYO_001.KOMOKU_MEI3 := MJIDO_WORK(ICNT).KOMOKU_MEI3;
        r_CHOHYO_001.KOMOKU_MEI4 := MJIDO_WORK(ICNT).KOMOKU_MEI4;
        r_CHOHYO_001.KOMOKU_MEI5 := MJIDO_WORK(ICNT).KOMOKU_MEI5;
        r_CHOHYO_001.KOMOKU_MEI6 := MJIDO_WORK(ICNT).KOMOKU_MEI6;
        r_CHOHYO_001.KOMOKU_MEI7 := MJIDO_WORK(ICNT).KOMOKU_MEI7;
        r_CHOHYO_001.KOMOKU_MEI8 := MJIDO_WORK(ICNT).KOMOKU_MEI8;
        r_CHOHYO_001.KOMOKU_MEI9 := MJIDO_WORK(ICNT).KOMOKU_MEI9;
        r_CHOHYO_001.KOMOKU_MEI10 := MJIDO_WORK(ICNT).KOMOKU_MEI10;
        r_CHOHYO_001.GAKKO_CD := MJIDO_WORK(ICNT).GAKOKU_CD;
        r_CHOHYO_001.ZOKUGARAMEI1 := MJIDO_WORK(ICNT).ZOKUGARAMEI1;
        r_CHOHYO_001.ZOKUGARAMEI2 := MJIDO_WORK(ICNT).ZOKUGARAMEI2;
        IF LENGTH(MJIDO_WORK(ICNT).JIDO_YUBIN_NO) > 0 THEN
          VYUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).JIDO_YUBIN_NO, 1, 3) || '-' || SUBSTR(MJIDO_WORK(ICNT).JIDO_YUBIN_NO, 4);
          VYUBIN_NO := TRANSLATE(VYUBIN_NO, '1234567890-', '１２３４５６７８９０－');
          r_CHOHYO_001.JIDO_YUBIN_NO := VYUBIN_NO;
        ELSE
          r_CHOHYO_001.JIDO_YUBIN_NO := MJIDO_WORK(ICNT).JIDO_YUBIN_NO;
        END IF;
        r_CHOHYO_001.JIDO_YUBIN_NOBC := MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC;
        r_CHOHYO_001.JIDO_CHOMEI_BANCHI := MJIDO_WORK(ICNT).JIDO_CHOMEI || MJIDO_WORK(ICNT).JIDO_BANCHI;
        r_CHOHYO_001.JIDO_KATAGAKI := MJIDO_WORK(ICNT).JIDO_KATAGAKI;
        IF VKOMOKU_SEIGYO IN (1,3)  THEN
          IF LENGTH(MJIDO_WORK(ICNT).JIDO_YUBIN_NO) > 0 THEN
            VYUBIN_NO1 := SUBSTR(MJIDO_WORK(ICNT).JIDO_YUBIN_NO, 1, 3) || '-' || SUBSTR(MJIDO_WORK(ICNT).JIDO_YUBIN_NO, 4);
            VYUBIN_NO1 := TRANSLATE(VYUBIN_NO1, '1234567890-', '１２３４５６７８９０－');
            r_CHOHYO_001.ATESAKI_YUBIN_NO := VYUBIN_NO1;
          ELSE
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
--          r_CHOHYO_001.ATESAKI_YUBIN_NO := MJIDO_WORK(ICNT).JIDO_YUBIN_NO;
            r_CHOHYO_001.ATESAKI_YUBIN_NO := r_CHOHYO_001.YUBIN_NO;                         --  宛先郵便番号
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
          END IF;
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
--        r_CHOHYO_001.BC_NO := MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC;
--        r_CHOHYO_001.ATESAKI_CHOMEI_BANCHI := MJIDO_WORK(ICNT).JIDO_CHOMEI || ' ' || MJIDO_WORK(ICNT).JIDO_BANCHI;
--        r_CHOHYO_001.ATESAKI_KATAGAKI := MJIDO_WORK(ICNT).JIDO_KATAGAKI;
          r_CHOHYO_001.BC_NO := r_CHOHYO_001.YUBIN_NOBC;
          r_CHOHYO_001.ATESAKI_CHOMEI_BANCHI := REPLACE(REPLACE(r_CHOHYO_001.CHOMEI_BANCHI,' ',''),'　','');       --  宛先町名番地
          r_CHOHYO_001.ATESAKI_KATAGAKI := r_CHOHYO_001.KATAGAKI;
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
        ELSE
          IF LENGTH(MJIDO_WORK(ICNT).YUBIN_NO) > 0 THEN
            VYUBIN_NO1 := SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO, 1, 3) || '-' || SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO, 4);
            VYUBIN_NO1 := TRANSLATE(VYUBIN_NO1, '1234567890-', '１２３４５６７８９０－');
            r_CHOHYO_001.ATESAKI_YUBIN_NO := VYUBIN_NO1;
          ELSE
            r_CHOHYO_001.ATESAKI_YUBIN_NO := MJIDO_WORK(ICNT).YUBIN_NO;
          END IF;
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
--        r_CHOHYO_001.BC_NO := MJIDO_WORK(ICNT).YUBIN_NOBC;
--        r_CHOHYO_001.ATESAKI_CHOMEI_BANCHI := MJIDO_WORK(ICNT).CHOMEI || ' ' || MJIDO_WORK(ICNT).BANCHI;
          r_CHOHYO_001.BC_NO := r_CHOHYO_001.YUBIN_NOBC;
          r_CHOHYO_001.ATESAKI_CHOMEI_BANCHI := REPLACE(REPLACE(r_CHOHYO_001.CHOMEI_BANCHI,' ',''),'　','');       --  宛先町名番地
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
          r_CHOHYO_001.ATESAKI_KATAGAKI := MJIDO_WORK(ICNT).KATAGAKI;
        END IF;
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
       r_CHOHYO_001.ATESAKI_YUBIN_NO := r_CHOHYO_001.YUBIN_NO;
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
--  2024/09/29 ZCZL.YUCHUFEI UPDATE 0.3.000.002:仕様変更 IT_GKB_00074対応
--         IF V_JYOUKEN07 = 0 THEN
        IF V_JYOUKEN07 = 1 THEN
          --抑止住所編集（児童生徒住所）
          sCTLPRM := GAAPK0030.FDVJUSHO('GKB', MJIDO_WORK(ICNT).JIDO_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, r_CHOHYO_001.JIDO_CHOMEI_BANCHI, nHANTEIKEKKA, 2, NULL, NULL);
          r_CHOHYO_001.JIDO_CHOMEI_BANCHI := sCTLPRM;
          IF nHANTEIKEKKA = 1 THEN
            r_CHOHYO_001.JIDO_YUBIN_NO := '';
            r_CHOHYO_001.JIDO_YUBIN_NOBC := '';
            r_CHOHYO_001.JIDO_KATAGAKI := '';
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
--          r_CHOHYO_001.ATESAKI_YUBIN_NO := '';
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
          END IF;
        END IF;
--  2024/06/27 ZCZL.shixinyu Add end
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--         r_CHOHYO_001.YAKUSHOKU_MEI := MJIDO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI;
--         r_CHOHYO_001.SHUCHO_MEI := MJIDO_WORK(ICNT).KYOIKU_SHUTHOU_MEI;
        r_CHOHYO_001.YAKUSHOKU_MEI := vKATAGAKI1;
        r_CHOHYO_001.SHUCHO_MEI := vSHIMEI;
--  2024/06/27 ZCZL.shixinyu Update end
        r_CHOHYO_001.TANTO_RITSU_MEI := MJIDO_WORK(ICNT).KYOIKU_RITSU_MEI;
        r_CHOHYO_001.TANTO_TEL_NAISEN := MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN;
        IF VHCHOHYO_RENBAN <> 0 THEN
            -- 以前の改頁項目値と同じ
            IF VPAGEWORK = VPAGENAME THEN
              -- 以前の改頁項目名と同じ
              VCHOHYO_NO := VCHOHYO_NO + 1;
            ELSE
              VCHOHYO_NO := 1; 
              VPAGEWORK := VPAGENAME;
            END IF;
        END IF;
        IF VHCHOHYO_RENBAN = 0 THEN
          r_CHOHYO_001.HYOJI_CHOHYO_NO := MJIDO_WORK(ICNT).HYOJI_CHOHYO_NO;
        ELSE
          r_CHOHYO_001.HYOJI_CHOHYO_NO := MJIDO_WORK(ICNT).RENBAN;
        END IF;
        KYOIKUKAI_RENRAKUSAKI := GET_EQRENRAKUSAKI(4, MJIDO_WORK(ICNT).KYOIKUKAI_MEI, MJIDO_WORK(ICNT).KYOIKU_TEL, MJIDO_WORK(ICNT).KYOIKU_TEL_NAISEN);
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--        r_CHOHYO_001.KYOIKU_RENRAKUSAKI := KYOIKUKAI_RENRAKUSAKI;
        r_CHOHYO_001.KYOIKU_RENRAKUSAKI := vSHIMEI;
        IF rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
--        r_CHOHYO_001.BUNSHO_NO := rBUNNUMEDITKEKA.NUM;                --文書番号
          r_CHOHYO_001.BUNSHO_NO := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(rBUNNUMEDITKEKA.NUM, 0),' ',''),'　','');
                                                                          --  文書番号
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
        ELSE
          r_CHOHYO_001.BUNSHO_NO := '';
        END IF;
        IF r_CHOHYO_001.KOIN_PATH IS NULL THEN
          r_CHOHYO_001.KOIN_SHORYAKU := MJIDO_WORK(ICNT).KOIN_SHORYAKU;   --公印省略
          r_CHOHYO_001.KOIN_CHUSHAKU := '';                               --公印注釈
        ELSE
          r_CHOHYO_001.KOIN_SHORYAKU := '';
          r_CHOHYO_001.KOIN_CHUSHAKU := MJIDO_WORK(ICNT).KOIN_CHUSHAKU;
        END IF; 
        r_CHOHYO_001.TITLE := MJIDO_WORK(ICNT).TITLE;                     --通知書タイトル
        r_CHOHYO_001.TSUCHIBUN := REPLACE(MJIDO_WORK(ICNT).TSUCHIBUN,chr(13)||chr(10),'#');             --通知文
        r_CHOHYO_001.TOKKIJIKO := REPLACE(MJIDO_WORK(ICNT).TOKKIJIKO,chr(13)||chr(10),'#');             --特記事項
        r_CHOHYO_001.BIKO := REPLACE(MJIDO_WORK(ICNT).BIKO,chr(13)||chr(10),'#');  --備考
        r_CHOHYO_001.TOIAWASESAKI1 := MJIDO_WORK(ICNT).KYOIKUKAI_MEI;              --お問い合わせ先１
        r_CHOHYO_001.TOIAWASESAKI2 := MJIDO_WORK(ICNT).KYOIKU_JUSHO;               --お問い合わせ先2
        r_CHOHYO_001.TOIAWASESAKI3 := MJIDO_WORK(ICNT).KYOIKU_TEL;                 --お問い合わせ先3
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 START
--      r_CHOHYO_001.YOSHIKI_NO := MJIDO_WORK(ICNT).YOSHIKI_NO;                    --様式番号
        r_CHOHYO_001.YOSHIKI_NO := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(MJIDO_WORK(ICNT).YOSHIKI_NO, 0),' ',''),'　','');
                                                                                   --様式番号
--  2025/01/09 JPJYS.GAOJIAN UPDATE 0.3.000.011:IT_GKB_10167、IT_GKB_10168、IT_GKB_10169、IT_GKB_10170、IT_GKB_10200、IT_GKB_10201、IT_GKB_10202、IT_GKB_10203対応 END
        r_CHOHYO_001.BIKO_TITLE := MJIDO_WORK(ICNT).BIKO_TITLE;                    --備考タイトル
        r_CHOHYO_001.GAKKO_KBN_CD := MJIDO_WORK(ICNT).GAKKO_KBN_CD;                --学校区分コード
        r_CHOHYO_001.KOJIN_NO := MJIDO_WORK(ICNT).JIDO_KOJIN_NO;                   --児童生徒宛名番号
        r_CHOHYO_001.HOGOSYA_KOJIN_NO := MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO;        --保護者宛名番号
        --  2024/12/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:仕様変更IT_GKB_10044の対応 Start
        r_CHOHYO_001.JIDO_SHIMEI_LAB := '生徒氏名';                                --児童生徒氏名ラベル
        --  2024/12/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.010:仕様変更IT_GKB_10044の対応 End
--  2024/06/27 ZCZL.shixinyu Update end
        r_CHOHYO_001.BREAK_NO := MJIDO_WORK(ICNT).KAIPEJI_CD;
        r_CHOHYO_001.WSNUM := g_sWSNUM;
        r_CHOHYO_001.BATCHKBN := c_BATCH;
        r_CHOHYO_001.JOBNUM := g_nJOBNUM;
        
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--        INSERT INTO GKBWL040R001 VALUES r_CHOHYO_001;
        INSERT INTO GKBWL030R001 VALUES r_CHOHYO_001;
        --発行履歴作成
        IF V_JYOUKEN06 = 0 THEN
            nBUNSHOBANGO := KKAPK0010.FSTRCNV(REPLACE(REPLACE(rBUNNUMEDITKEKA.NUM,rBUNNUMSRCINF.MAEMOJI,''),rBUNNUMSRCINF.USHIROMOJI,''),1);
            IRTN := GKAFKHAKKOR('GKB',
                                MJIDO_WORK(ICNT).JIDO_KOJIN_NO,
                                3,
                                SUBSTR(TO_CHAR(SYSDATE, 'YYYYMMDD'), 1, 4),
                                1,
                                '中学校入学通知書',
                                TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')),
                                TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS')),
                                1,
                                g_sTANTOCODE,
                                iSOFUBI,
                                NULL,
                                rBUNNUMSRCINF.MAEMOJI,
--  2024/11/21 ZCZL.ZHANGLEI UPDATE 0.3.000.009:IT_GKC_00329横展開対応
                                --TO_NUMBER(nBUNSHOBANGO),
                                nBUNSHOBANGO,
                                rBUNNUMSRCINF.USHIROMOJI,
                                MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO,
                                NULL,
                                g_sWSNUM);
        END IF;
        --文書番号保管を追加
        rBUNNUMHOKAN_WORK(ICNT).KOJIN_NO := MJIDO_WORK(ICNT).JIDO_KOJIN_NO;
        rBUNNUMHOKAN_WORK(ICNT).BUNSHONO := rBUNNUMSRCINF.UOUT.NUM;
--  2024/06/27 ZCZL.shixinyu Update end
      END LOOP;
--  2025/07/31 CTC.GL UPDATE START 1.0.011.000:GKB_QA19054対応
      END IF;
--  2025/07/31 CTC.GL UPDATE END
      g_nINDEX := g_nINDEX + 1;
      g_oKENSU_LIST.EXTEND(1);
      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(ICNT_1,'出力　中学校入学通知書CSV',2);
      -- 終了
      RETURN FRET;
    EXCEPTION
      WHEN OTHERS THEN
        FRET := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        N_SQL_CODE := SQLCODE;
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        -- 処理ログの出力
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE1', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1); 
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE1;
    --------------------------------------------------------------------------------
    -- 入学通知書発送者一覧表CSVの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE2 RETURN NUMBER IS
      FRET                PLS_INTEGER;                -- 戻り値
      ICNT                BINARY_INTEGER;             -- カウント
      IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
      IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
      VYUBIN_NO           NVARCHAR2(60);              --郵便番号編集用
      ICNT_1              BINARY_INTEGER := 0;        -- カウント
      JD_TENSHUTSU_KBN    BINARY_INTEGER := 0;        --転出区分（1:転出,0:以外）
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--      r_CHOHYO_001        GKBWL160R002%ROWTYPE;
      r_CHOHYO_001        GKBWL130R022%ROWTYPE;
      sCTLPRM             NVARCHAR2(500);             --住所マスク文字列
      nHANTEIKEKKA        PLS_INTEGER;                --抑止レベル３制御の要否（0：非該当、1：該当）
--  2024/06/27 ZCZL.shixinyu Update end
      nCOUNT              NUMBER;

    BEGIN
      FRET := c_ISUCCESS;                  -- 正常終了
      IMAX := MJIDO_WORK.LAST;             -- ワーク領域の件数の最大値
      IMIN := MJIDO_WORK.FIRST;            -- ワーク領域の件数の最小値
      VCHOHYO_NO := 0;                     -- 帳票連番初期化
      nCOUNT := 0;
--  2025/07/31 CTC.GL UPDATE START 1.0.011.000:GKB_QA19054対応
      IF IMIN IS NOT NULL AND IMAX IS NOT NULL THEN
--  2025/07/31 CTC.GL UPDATE END
      -- 取得した件数分繰り返す
      FOR ICNT IN IMIN..IMAX LOOP
        ICNT_1 := ICNT_1 + 1;
        nCOUNT := nCOUNT + 1;
        r_CHOHYO_001 := NULL;
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--         r_CHOHYO_001.NO := nCOUNT;
--         r_CHOHYO_001.NENDO := MJIDO_WORK(ICNT).NENDO;
--         r_CHOHYO_001.KAIPAGE_CD := MJIDO_WORK(ICNT).KAIPEJI_CD;
--         r_CHOHYO_001.KAIPAGE_MEI := MJIDO_WORK(ICNT).KAIPEJI;
--         r_CHOHYO_001.SAKUSEIBI := MJIDO_WORK(ICNT).SAKUSEIBI;
--         r_CHOHYO_001.CHOHYO_RENBAN := MJIDO_WORK(ICNT).RENBAN;
--         r_CHOHYO_001.JIDO_SHIMEI_KANA := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;
--         r_CHOHYO_001.JIDO_SHIMEI_KANJI := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;
--         r_CHOHYO_001.SEINENGAPI := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;
--         r_CHOHYO_001.SEIBETSU := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;
--         r_CHOHYO_001.HOGOSHA_SHIMEI_JODAN := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN;
--         r_CHOHYO_001.HOGOSHA_SHIMEI_GEDAN := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;
--         r_CHOHYO_001.JUSHO_JODAN := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;
--         r_CHOHYO_001.JUSHO_GEDAN := MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;
--         r_CHOHYO_001.GYOSEIKU_MEI := MJIDO_WORK(ICNT).GYOSEIKUMEI;
--         r_CHOHYO_001.GAKKOKU_MEI := MJIDO_WORK(ICNT).GAKOKUMEI;
--         r_CHOHYO_001.SANTEIDANTAI_MEI := MJIDO_WORK(ICNT).SANTEIDANTAIMEI;   
--         IF LENGTH(MJIDO_WORK(ICNT).YUBIN_NO) > 0 THEN
--           MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO, 1, 3) || '-' || SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO, 4);
--         END IF;
--         r_CHOHYO_001.YUBIN_NO := MJIDO_WORK(ICNT).YUBIN_NO;
--         r_CHOHYO_001.CHOMEI_BANCHI := MJIDO_WORK(ICNT).CHOMEI||MJIDO_WORK(ICNT).BANCHI;
--         r_CHOHYO_001.KATAGAKI := MJIDO_WORK(ICNT).KATAGAKI;
--         r_CHOHYO_001.HOGOSHA_SHIMEI_JGSAMA := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN||MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN ||'　様'|| ',';
--         r_CHOHYO_001.KANJI_SEINENGAPI := MJIDO_WORK(ICNT).KANJI_SEINENGAPI;
--         r_CHOHYO_001.KYOIKU_KAI_MEI := MJIDO_WORK(ICNT).KYOIKUKAI_MEI;
--         r_CHOHYO_001.NYUGAKU_KIJITU := NULL; 
--         r_CHOHYO_001.KIJUNBI := MJIDO_WORK(ICNT).KIJUN_BI;
--         r_CHOHYO_001.SYUHATU_NO := NULL; 
--         r_CHOHYO_001.ZOKUGARAMEI1 := MJIDO_WORK(ICNT).ZOKUGARAMEI1;
--         r_CHOHYO_001.ZOKUGARAMEI2 := MJIDO_WORK(ICNT).ZOKUGARAMEI2;
--         IF LENGTH(MJIDO_WORK(ICNT).JIDO_YUBIN_NO) > 0 THEN
--           VYUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).JIDO_YUBIN_NO, 1, 3) || '-' || SUBSTR(MJIDO_WORK(ICNT).JIDO_YUBIN_NO, 4);
--           VYUBIN_NO := TRANSLATE(VYUBIN_NO, '1234567890-', '１２３４５６７８９０－');
--           r_CHOHYO_001.JIDO_YUBIN_NO := VYUBIN_NO;
--         ELSE
--           r_CHOHYO_001.JIDO_YUBIN_NO := MJIDO_WORK(ICNT).JIDO_YUBIN_NO;
--         END IF;
--         r_CHOHYO_001.JIDO_YUBIN_NOBC := MJIDO_WORK(ICNT).JIDO_YUBIN_NOBC;
--         r_CHOHYO_001.JIDO_CHOMEI := MJIDO_WORK(ICNT).JIDO_CHOMEI;
--         r_CHOHYO_001.JIDO_BANCHI := MJIDO_WORK(ICNT).JIDO_BANCHI;
--         r_CHOHYO_001.JIDO_KATAGAKI := MJIDO_WORK(ICNT).JIDO_KATAGAKI;
--         r_CHOHYO_001.KIJUNBI_GENZAI := MJIDO_WORK(ICNT).KIJUN_BI;
--         IF VHCHOHYO_RENBAN <> 0 THEN
--            --以前の改頁項目値と同じ
--             IF VPAGEWORK = VPAGENAME THEN
--              --以前の改頁項目名と同じ
--               VCHOHYO_NO := VCHOHYO_NO + 1;
--             ELSE
--               VCHOHYO_NO := 1; 
--               VPAGEWORK := VPAGENAME;
--             END IF;
--         END IF;
--         IF VHCHOHYO_RENBAN = 0 THEN
--           r_CHOHYO_001.NUM := MJIDO_WORK(ICNT).CHOHYO_NO;
--         ELSE
--           r_CHOHYO_001.NUM := MJIDO_WORK(ICNT).RENBAN;
--         END IF;
--         r_CHOHYO_001.JINKAKU_KBN := MJIDO_WORK(ICNT).JINKAKU_KBN;
-- 
--         IF MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU_JIYU = 21 THEN
--          --転出の場合
--           JD_TENSHUTSU_KBN := 1;
--         ELSE
--           JD_TENSHUTSU_KBN := 0;
--         END IF;
--         r_CHOHYO_001.TENSHUTSU_KBN := JD_TENSHUTSU_KBN;
--  2025/10/14 CTC.GYY UPDATE 1.0.201.000:GKB_QA21166対応 START
        --r_CHOHYO_001.NO := MJIDO_WORK(ICNT).RENBAN;                                                   --ソート順
        r_CHOHYO_001.NO := ICNT;                                                                        --ソート順
--  2025/10/14 CTC.GYY UPDATE 1.0.201.000:GKB_QA21166対応 END
        r_CHOHYO_001.SAKUSEI_YMD := KKAPK0020.FDateFmt(TO_CHAR(SYSDATE,'YYYY/MM/DD'), 10);            --作成年月日
        r_CHOHYO_001.TITLE := MJIDO_WORK(ICNT).TITLE || '発送者一覧表';                                --タイトル
        --文書番号
        FOR i IN IMIN..IMAX LOOP
            IF rBUNNUMHOKAN_WORK(i).KOJIN_NO = MJIDO_WORK(ICNT).JIDO_KOJIN_NO THEN
                r_CHOHYO_001.BUNSHO_NO := rBUNNUMHOKAN_WORK(i).BUNSHONO;                              --文書番号
                EXIT;
            END IF;
        END LOOP;
        r_CHOHYO_001.HAKKO_YMD := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(iSOFUBI,'YYYY/MM/DD'),'YYYY/MM/DD'), 10);             --発行年月日
        --保護者抑止住所編集
        sCTLPRM := GAAPK0030.FDVJUSHO('GKB', MJIDO_WORK(ICNT).HOGOSHA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM,MJIDO_WORK(ICNT).KON_JUSHO_JODAN||MJIDO_WORK(ICNT).KON_JUSHO_GEDAN, nHANTEIKEKKA, 2);
        r_CHOHYO_001.SOFUSAKI_JUSHO := sCTLPRM;                                                       --送付先住所
        IF nHANTEIKEKKA = 1 THEN
           r_CHOHYO_001.SOFUSAKI_YUBIN_NO := '';
        ELSE
           r_CHOHYO_001.SOFUSAKI_YUBIN_NO := MJIDO_WORK(ICNT).YUBIN_NO;                               --送付先郵便番号
        END IF;
        r_CHOHYO_001.JIDO_SHIMEI_KANA := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;                           --児童生徒氏名カナ
        r_CHOHYO_001.JIDO_SHIMEI_KANJI := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;                         --児童生徒氏名漢字
        r_CHOHYO_001.SEINENGAPI := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;                                 --生年月日
        r_CHOHYO_001.SEIBETSU := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;                                     --性別
        r_CHOHYO_001.JIDO_SHIENSOCHI := MJIDO_WORK(ICNT).JIDO_SHIENSOCHI;                             --児童生徒_支援措置
        r_CHOHYO_001.HOGOSHA_SHIMEI_KANA := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN;                    --保護者氏名カナ
        r_CHOHYO_001.HOGOSHA_SHIMEI_KANJI := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;                   --保護者氏名漢字
        r_CHOHYO_001.SOFUSAKI_SHIMEI := r_CHOHYO_001.HOGOSHA_SHIMEI_KANJI;                            --送付先氏名
        r_CHOHYO_001.HOGOSHA_ZOKUGARA := MJIDO_WORK(ICNT).ZOKUGARAMEI2;                               --児童生徒との関係
        r_CHOHYO_001.HOGOSHA_SHIENSOCHI := MJIDO_WORK(ICNT).HOGOSHA_SHIENSOCHI;                       --保護者_支援措置
        r_CHOHYO_001.GAKKO_MEI := MJIDO_WORK(ICNT).TYUGAKOMEI;                                        --学校名
        r_CHOHYO_001.KENSU := nCOUNT;                                                                 --件数
        r_CHOHYO_001.GAKKO_CD := MJIDO_WORK(ICNT).TYUGAKO_CD;                                         --学校コード
        r_CHOHYO_001.JIDO_SHIMEI_LABEL := '児童生徒氏名';                                              --児童生徒氏名_ラベ
        r_CHOHYO_001.HOGOSHA_SHIMEI_LABEL := '保護者氏名';                                             --保護者氏名_ラベル
        r_CHOHYO_001.GAKKO_GYOSEIKU_LABEL := '学校';                                                   --学校/行政区_ラベル
        IF MJIDO_WORK(ICNT).JINKAKU_KBN = 1 THEN
          r_CHOHYO_001.JINKAKU_KBN := '＊';                                                           --人格区分
        ELSE
          r_CHOHYO_001.JINKAKU_KBN := NULL;
        END IF;
--  2024/06/27 ZCZL.shixinyu Update end
        r_CHOHYO_001.BREAK_NO := MJIDO_WORK(ICNT).KAIPEJI_CD;
        r_CHOHYO_001.WSNUM := g_sWSNUM;
        r_CHOHYO_001.BATCHKBN := c_BATCH;
        r_CHOHYO_001.JOBNUM := g_nJOBNUM;
--  2024/06/27 ZCZL.shixinyu Update 0.3.000.000:新WizLIFE２次開発
        --INSERT INTO GKBWL160R002 VALUES r_CHOHYO_001;
        INSERT INTO GKBWL130R022 VALUES r_CHOHYO_001;
      END LOOP;
--  2025/07/31 CTC.GL UPDATE START 1.0.011.000:GKB_QA19054対応
      END IF;
--  2025/07/31 CTC.GL UPDATE END
      g_nINDEX := g_nINDEX + 1;
      g_oKENSU_LIST.EXTEND(1);
      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(ICNT_1,'出力　入学通知書発送者一覧表CSV',2);
      
      -- 終了
      RETURN FRET;
    EXCEPTION
      WHEN OTHERS THEN
        FRET := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        N_SQL_CODE := SQLCODE;
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        -- 処理ログの出力
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE2', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1); 
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE2;
    --------------------------------------------------------------------------------
    -- 入学通知書エラー一覧表CSVの抽出
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_ERRCSV RETURN NUMBER IS
      FRET                PLS_INTEGER;                -- 戻り値
      ICNT                BINARY_INTEGER;             -- カウント
      VSQL                NVARCHAR2(10000);           -- ＳＱＬ文
      VSQLSEL             NVARCHAR2(9000);            -- ＳＱＬのソート以外
      VSQLORDER           NVARCHAR2(1000);            -- ＳＱＬの［ORDER BY］句
      VSQLWHERE           NVARCHAR2(1000);            -- ＳＱＬの[WHERE]句
      I_CUR               PLS_INTEGER;                -- カーソル
      RREC                GKBWJIDOTSUCHI%ROWTYPE;   -- 入学通知台帳のレコード変数
      NROWS               NUMBER;                     --
      IPAGECNT            PLS_INTEGER;                -- 頁数
      IGYOCNT             PLS_INTEGER;                -- 行番号
      IGYORENBAN          PLS_INTEGER;                -- 行連番
      vORDER_BY           NVARCHAR2(1000);

    BEGIN
      FRET      := c_ISUCCESS;                  -- 正常終了
      VPAGEWORK := '';
      IGYOCNT   := 0;
      ICNT      := 0;
      MJIDO_WORK.DELETE;                   -- ワーク領域の初期化

      vORDER_BY := FUNC_GETSORTCOLS(1604);
      -- ソート条件取得
      IF VHCHOHYO_RENBAN = 0 THEN
        VSQLORDER := ' GAKOKU_CD,GYOSEIKU_CD,CHOHYO_NO ';
      ELSE
        IF KKAPK0010.FTrim(vORDER_BY) IS NOT NULL THEN
          VSQLORDER := vORDER_BY;
        END IF;
      END IF;
      -- ［ORDER BY］句を付加
      IF VSQLORDER IS NOT NULL THEN
         VSQLORDER := ' ORDER BY ' || VSQLORDER;
      END IF;
      
      VPAGENM := ' GAKOKUMEI ';
      VPAGEFD := ' GAKOKU_CD ';

      -- 22:死亡、23:職権消除、25:失踪宣告はエラー一覧に出力する。
--  2024/06/27 ZCZL.shixinyu Update 0.3.000.000:新WizLIFE２次開発
--      VSQLWHERE := ' WHERE ( HG_JUMIN_NAKUNARU_JIYU IN (22, 23, 25) OR JD_JUMIN_NAKUNARU_JIYU IN (22, 23, 25) ) ';
      VSQLWHERE := ' WHERE ( HG_JUMIN_NAKUNARU_JIYU IN (220, 230, 250) OR JD_JUMIN_NAKUNARU_JIYU IN (220, 230, 250) ) ';
      IF VTYUGAKO_CD IS NOT NULL THEN
        VSQLWHERE := VSQLWHERE || ' AND TYUGAKO_CD  IN ('|| VTYUGAKO_CD || ') ';
      END IF;

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
        VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
        VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_JODAN, ';
        VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_GEDAN, ';
        VSQLSEL := VSQLSEL || 'KON_JUSHO_JODAN, ';
        VSQLSEL := VSQLSEL || 'KON_JUSHO_GEDAN, ';
        VSQLSEL := VSQLSEL || 'GYOSEIKUMEI, ';
        VSQLSEL := VSQLSEL || 'GAKOKUMEI, ';
        VSQLSEL := VSQLSEL || 'YUBIN_NO, ';
        VSQLSEL := VSQLSEL || 'CHOMEI, ';
        VSQLSEL := VSQLSEL || 'BANCHI, ';
        VSQLSEL := VSQLSEL || 'KATAGAKI, ';
        IF VHCHOHYO_RENBAN = 0 THEN
          IF VYINJI_PATTERN IN (1,2,3)  THEN
            VSQLSEL := VSQLSEL || '  GAKOKU_CD '|| ' PAGE_FIELD, ';
            VSQLSEL := VSQLSEL || ' GAKOKUMEI ' || ' PAGE_NAME, ';
          ELSIF VYINJI_PATTERN IN (4,5)  THEN
            VSQLSEL := VSQLSEL || ' GAKOKU_CD || GYOSEIKU_CD '|| ' PAGE_FIELD, ';
            VSQLSEL := VSQLSEL || ' GAKOKUMEI || '' '' || GYOSEIKUMEI '|| ' PAGE_NAME, ';
          ELSE
            VSQLSEL := VSQLSEL || 'null as PAGE_FIELD, ';
            VSQLSEL := VSQLSEL || 'null as PAGE_NAME, ';
          END IF;
        ELSE
          VSQLSEL := VSQLSEL || VPAGEFD ||' PAGE_FIELD, ';
          VSQLSEL := VSQLSEL || VPAGENM ||' PAGE_NAME, ';
        END IF;

        -- 小学校
        VSQLSEL := VSQLSEL || ' SYOGAKO_CD ';
        VSQLSEL := VSQLSEL || ', SYOGAKOMEI ';
        -- 中学校
        VSQLSEL := VSQLSEL || ', TYUGAKO_CD ';
        VSQLSEL := VSQLSEL || ', TYUGAKOMEI ';
        VSQLSEL := VSQLSEL || ', JIDO_CHOMEI ';
        VSQLSEL := VSQLSEL || ', JIDO_BANCHI ';
        VSQLSEL := VSQLSEL || ', JIDO_KATAGAKI ';
        VSQLSEL := VSQLSEL || ', CHOHYO_NO ';
        VSQLSEL := VSQLSEL || ', KIJUN_BI ';
        VSQLSEL := VSQLSEL || ', JINKAKU_KBN ';
        VSQLSEL := VSQLSEL || ', JD_JUMIN_NAKUNARU ';
        VSQLSEL := VSQLSEL || ', JD_JUMIN_NAKUNARU_JIYUNM ';
        VSQLSEL := VSQLSEL || ', HG_JUMIN_NAKUNARU ';
        VSQLSEL := VSQLSEL || ', HG_JUMIN_NAKUNARU_JIYUNM ';

        VSQLSEL := VSQLSEL || 'FROM ';
        VSQLSEL := VSQLSEL || 'GKBWJIDOTSUCHI ';
        -- ひとつのＳＱＬ文にする
        VSQL := VSQLSEL || VSQLWHERE || VSQLORDER;

        -- カーソルのオープン
        I_CUR := DBMS_SQL.OPEN_CURSOR;
        -- ＳＱＬ文の解析
        DBMS_SQL.PARSE(I_CUR, VSQL, DBMS_SQL.NATIVE);
        -- 取得する列の定義
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, RREC.NENDO, 10);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, RREC.KAIPEJI_CD, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, RREC.KAIPEJI, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.SAKUSEIBI, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.RENBAN );
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.JIDO_SHIMEI_KANA, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.JIDO_SHIMEI_KANJI, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.HYOJI_SEINENGAPI, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 9, RREC.HYOJI_SEIBETSU, 1);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.HOGOSHA_SHIMEI_JODAN, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.HOGOSHA_SHIMEI_GEDAN, 100);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.KON_JUSHO_JODAN, 30); 
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.KON_JUSHO_GEDAN, 30);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.GYOSEIKUMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.GAKOKUMEI, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.YUBIN_NO, 10);
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.CHOMEI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.BANCHI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.KATAGAKI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.CHOMEI, 136);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.BANCHI, 50);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.KATAGAKI, 300);
--  2024/06/27 ZCZL.shixinyu Update end
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, VPAGEFD, 500);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, VPAGENM, 500);
        -- 小学校
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.SYOGAKO_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.SYOGAKOMEI, 60);
        -- 中学校
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.TYUGAKO_CD);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.TYUGAKOMEI, 60);

--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.JIDO_CHOMEI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.JIDO_BANCHI, 40);
--        DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.JIDO_KATAGAKI, 60);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.JIDO_CHOMEI, 136);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.JIDO_BANCHI, 50);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.JIDO_KATAGAKI, 300);
--  2024/06/27 ZCZL.shixinyu Update end
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, RREC.CHOHYO_NO);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, RREC.KIJUN_BI, 16);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, RREC.JINKAKU_KBN);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, RREC.JD_JUMIN_NAKUNARU, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, RREC.JD_JUMIN_NAKUNARU_JIYUNM, 20);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 34, RREC.HG_JUMIN_NAKUNARU, 11);
        DBMS_SQL.DEFINE_COLUMN(I_CUR, 35, RREC.HG_JUMIN_NAKUNARU_JIYUNM, 20);

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
            DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MJIDO_WORK(ICNT).HYOJI_SEINENGAPI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 9, MJIDO_WORK(ICNT).HYOJI_SEIBETSU);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MJIDO_WORK(ICNT).KON_JUSHO_JODAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MJIDO_WORK(ICNT).KON_JUSHO_GEDAN);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 14, MJIDO_WORK(ICNT).GYOSEIKUMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MJIDO_WORK(ICNT).GAKOKUMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MJIDO_WORK(ICNT).YUBIN_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MJIDO_WORK(ICNT).CHOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 18, MJIDO_WORK(ICNT).BANCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 19, MJIDO_WORK(ICNT).KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 20, VPAGEFIELD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 21, VPAGENAME);

            -- 小学校
            DBMS_SQL.COLUMN_VALUE(I_CUR, 22, MJIDO_WORK(ICNT).SYOGAKO_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 23, MJIDO_WORK(ICNT).SYOGAKOMEI);
            -- 中学校
            DBMS_SQL.COLUMN_VALUE(I_CUR, 24, MJIDO_WORK(ICNT).TYUGAKO_CD);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 25, MJIDO_WORK(ICNT).TYUGAKOMEI);

            DBMS_SQL.COLUMN_VALUE(I_CUR, 26, MJIDO_WORK(ICNT).JIDO_CHOMEI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 27, MJIDO_WORK(ICNT).JIDO_BANCHI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 28, MJIDO_WORK(ICNT).JIDO_KATAGAKI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 29, MJIDO_WORK(ICNT).CHOHYO_NO);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 30, MJIDO_WORK(ICNT).KIJUN_BI);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 31, MJIDO_WORK(ICNT).JINKAKU_KBN);
            
            DBMS_SQL.COLUMN_VALUE(I_CUR, 32, MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 33, MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU_JIYUNM);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 34, MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU);
            DBMS_SQL.COLUMN_VALUE(I_CUR, 35, MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYUNM);

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
        
        IF ICNT = 0 THEN
          FRET  := c_INOTFOUND;         -- 該当データ無し
        END IF;
        
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
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK_ERRCSV', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1); 
      END;
      RETURN FRET;
    END FUNC_GET_JIDO_WK_ERRCSV;
    --------------------------------------------------------------------------------
    -- 入学通知書エラー一覧表CSVの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_ERRCSVFILE RETURN NUMBER IS
      FRET                PLS_INTEGER;                -- 戻り値
      ICNT                BINARY_INTEGER;             -- カウント
      IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
      IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
      ICNT_1              BINARY_INTEGER := 0;        -- カウント
      r_CHOHYO_001        GKBWL160R004%ROWTYPE;
      nCOUNT              NUMBER;

    BEGIN
      FRET := c_ISUCCESS;                  -- 正常終了
      IMAX := MJIDO_WORK.LAST;             -- ワーク領域の件数の最大値
      IMIN := MJIDO_WORK.FIRST;            -- ワーク領域の件数の最小値
      VCHOHYO_NO := 0;                     -- 帳票連番初期化
      nCOUNT := 0;
      -- 取得した件数分繰り返す
      FOR ICNT IN IMIN..IMAX LOOP
        ICNT_1 := ICNT_1 + 1; --件数表を出力
        nCOUNT := nCOUNT + 1;
        r_CHOHYO_001 := NULL;
        r_CHOHYO_001.NO := nCOUNT;                                                           --ソート順
        r_CHOHYO_001.NENDO := MJIDO_WORK(ICNT).NENDO;                                        --年度
        r_CHOHYO_001.KAIPAGE_CD := MJIDO_WORK(ICNT).KAIPEJI_CD;                              --改頁コード
        r_CHOHYO_001.KAIPAGE_MEI := MJIDO_WORK(ICNT).KAIPEJI;                                --改頁名
        r_CHOHYO_001.SAKUSEIBI := MJIDO_WORK(ICNT).SAKUSEIBI;                                --作成日
        r_CHOHYO_001.CHOHYO_RENBAN := MJIDO_WORK(ICNT).RENBAN;                               --連番
        r_CHOHYO_001.JIDO_SHIMEI_KANA := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANA;                  --児童氏名かな
        r_CHOHYO_001.JIDO_SHIMEI_KANJI := MJIDO_WORK(ICNT).JIDO_SHIMEI_KANJI;                --児童氏名漢字
        r_CHOHYO_001.SEINENGAPI := MJIDO_WORK(ICNT).HYOJI_SEINENGAPI;                        --生年月日
        r_CHOHYO_001.SEIBETSU := MJIDO_WORK(ICNT).HYOJI_SEIBETSU;                            --性別
        r_CHOHYO_001.HOGOSHA_SHIMEI_JODAN := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_JODAN;          --保護者氏名上段
        r_CHOHYO_001.HOGOSHA_SHIMEI_GEDAN := MJIDO_WORK(ICNT).HOGOSHA_SHIMEI_GEDAN;          --保護者氏名下段
        r_CHOHYO_001.JUSHO_JODAN := MJIDO_WORK(ICNT).KON_JUSHO_JODAN;                        --保護者住所上段
        r_CHOHYO_001.JUSHO_GEDAN := MJIDO_WORK(ICNT).KON_JUSHO_GEDAN;                        --保護者住所下段
        r_CHOHYO_001.GAKKOKU_MEI := MJIDO_WORK(ICNT).GAKOKUMEI;                              --学校区名
        --郵便番号
        IF LENGTH(MJIDO_WORK(ICNT).YUBIN_NO) > 0 THEN
          MJIDO_WORK(ICNT).YUBIN_NO := SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO, 1, 3) || '-' || SUBSTR(MJIDO_WORK(ICNT).YUBIN_NO, 4);
        END IF;
        r_CHOHYO_001.YUBIN_NO := MJIDO_WORK(ICNT).YUBIN_NO;
        r_CHOHYO_001.CHOMEI_BANCHI := MJIDO_WORK(ICNT).CHOMEI||MJIDO_WORK(ICNT).BANCHI;      --町名||番地
        r_CHOHYO_001.KATAGAKI := MJIDO_WORK(ICNT).KATAGAKI;                                  --方書
        r_CHOHYO_001.JIDO_CHOMEI := MJIDO_WORK(ICNT).JIDO_CHOMEI;                            --町名（児童）
        r_CHOHYO_001.JIDO_BANCHI := MJIDO_WORK(ICNT).JIDO_BANCHI;                            --番地（児童）
        r_CHOHYO_001.JIDO_KATAGAKI := MJIDO_WORK(ICNT).JIDO_KATAGAKI;                        --方書（児童）
        IF VHCHOHYO_RENBAN <> 0 THEN
            -- 以前の改頁項目値と同じ
            IF VPAGEWORK = VPAGENAME THEN
              -- 以前の改頁項目名と同じ
              VCHOHYO_NO := VCHOHYO_NO + 1;
            ELSE
              VCHOHYO_NO := 1; 
              VPAGEWORK := VPAGENAME;
            END IF;
        END IF;
        IF VHCHOHYO_RENBAN = 0 THEN
          r_CHOHYO_001.NUM := MJIDO_WORK(ICNT).CHOHYO_NO;
        ELSE
          r_CHOHYO_001.NUM := MJIDO_WORK(ICNT).RENBAN;
        END IF;
        r_CHOHYO_001.JIDO_IDO_BI := MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU;                --児童異動日
        r_CHOHYO_001.JIDO_IDO_JIYU := MJIDO_WORK(ICNT).JD_JUMIN_NAKUNARU_JIYUNM;       --児童異動事由名
        r_CHOHYO_001.HOGOSHA_IDO_BI := MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU;             --保護者異動日
        r_CHOHYO_001.HOGOSHA_IDO_JIYU := MJIDO_WORK(ICNT).HG_JUMIN_NAKUNARU_JIYUNM;    --保護者異動事由名
        r_CHOHYO_001.JINKAKU_KBN := MJIDO_WORK(ICNT).JINKAKU_KBN;                      --人格区分
        r_CHOHYO_001.BREAK_NO := MJIDO_WORK(ICNT).KAIPEJI_CD;                          --改ページキー
        r_CHOHYO_001.WSNUM := g_sWSNUM;                                                --端末番号
        r_CHOHYO_001.BATCHKBN := c_BATCH;                                              --即時バッチ区分
        r_CHOHYO_001.JOBNUM := g_nJOBNUM;                                              --ジョブNO
        
        INSERT INTO GKBWL160R004 VALUES r_CHOHYO_001;
      END LOOP;

      --件数表を出力を追加
      g_nINDEX := g_nINDEX + 1;
      g_oKENSU_LIST.EXTEND(1);
      g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(ICNT_1,'出力　入学通知書エラー一覧表CSV',2);
      -- 終了
      RETURN FRET;
    EXCEPTION
      WHEN OTHERS THEN
        FRET := c_INOT_SUCCESS;      -- 異常終了
        -- SQL情報取得
        N_SQL_CODE := SQLCODE;
        V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
        -- 処理ログの出力
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_ERRCSVFILE', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1); 
        RETURN FRET;
    END FUNC_SET_JIDO_WK_ERRCSVFILE;

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        ERR              EXCEPTION;
        VDUMMY           NVARCHAR2(1000);
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
        nRTN             NUMBER;
--  2025/08/21 CTC.LIUJUNHAO ADD START 1.0.102.000:GKB_QA19314対応
        --iKIJUNBI         PLS_INTEGER;
--  2025/08/21 CTC.LIUJUNHAO ADD END 1.0.102.000:GKB_QA19314対応
--  2024/06/27 ZCZL.shixinyu Add end
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        
        --複数な帳票の場合、該当ロジックあり
        --変数の初期について、該当処理内作成しますか？判断要
        --帳票IDに関連な変数にIF内で書く
        IF g_nSTEP_INDEX = 1 THEN
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--           DELETE FROM GKBWL040R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
--           DELETE FROM GKBWL160R002 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
          DELETE FROM GKBWL030R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
          DELETE FROM GKBWL130R022 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
--  2024/06/27 ZCZL.shixinyu Update end
          DELETE FROM GKBWL160R004 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
--  2024/06/27 ZCZL.shixinyu Add 0.3.000.000:新WizLIFE２次開発
        END IF;
          BEGIN
            -- 取得した条件をそれぞれの変数へセット
            VNENDO := KKAPK0020.FNENDO(V_JYOUKEN01,1);     -- 年度
            VNENDO_GYY               := V_JYOUKEN01;       -- 年度 (GYY)
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.007:学校コードリスト仕様変更IT_GKB_00090の対応
            --IRTN := GKBPK00010.FGKOCDTR(V_JYOUKEN02,VTYUGAKO_CD);         -- 中学校コード
            bRTN := FUNC_GET_GAKOCD(V_JYOUKEN02,VTYUGAKO_CD);         -- 中学校コード
            VHCHOHYO_RENBAN          := TO_NUMBER(V_JYOUKEN03);           -- 帳票連番使用有無(0:使用する、1:使用しない）
            VKIJUNBI_IN              := TO_NUMBER(V_JYOUKEN04);           --基準日
            VHASOBI                  := V_JYOUKEN05;                      --発行日復活
            IWAREKI1 := VKIJUNBI_IN;
            ISEIREKI1 := 0;
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
            -- 処理条件の設定
            PROCHAISET;
            IF I_RTN <> c_ISUCCESS THEN
              RAISE ERR;
            END IF;
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
            iKIJUNBI := KKAPK0020.FNENDOHENKAN(V_JYOUKEN04);    --基準日(西暦変換)
            iSOFUBI := KKAPK0020.FNENDOHENKAN(V_JYOUKEN05);     --送付日(西暦変換)
--  2024/06/27 ZCZL.shixinyu Update end
--  2025/08/21 CTC.LIUJUNHAO ADD START 1.0.102.000:GKB_QA19314対応
            /*--公印ファイル名取得
            BRTN := KKBPK5551.FNINSHOGet(NVL(g_rJSTP.NINSHOCODE, 0),
                                       g_sWSNUM,
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--                                        SYSDATE,
--                                        VDUMMY,
--                                        VDUMMY,
--                                        VDUMMY,
--                                        VDUMMY,
                                       TO_DATE(iKIJUNBI,'YYYYMMDD'),
                                       nDAIRIKBN,
                                       vKATAGAKI1,
                                       vKATAGAKI2,
                                       vSHIMEI,
--  2024/06/27 ZCZL.shixinyu Update end
                                       VGYOMU);*/
--  2025/08/21 CTC.LIUJUNHAO ADD END 1.0.102.000:GKB_QA19314対応
            -- 児童生徒ワーク（GKBWJIDOTSUCHI）のデータ全件削除
            I_RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
            IF I_RTN <> c_ISUCCESS THEN
              RAISE ERR;
            END IF;
            -- 制御パレメータを取得
           PROC_GET_SEIGYO_PRM;
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
            --システム制御設定を取得する。
            -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する
            nRTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, aITEM);
            --「GKB712R001」が格納されている箇所のインデックス番号
            IF nRTN = 0 THEN
              FOR i IN 1..aITEM.COUNT LOOP
                IF aITEM(i) = 'GKB030R001' THEN
                  sINDEXNO := i;
                  EXIT;
                END IF;
              END LOOP;
            ELSE
              bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM,
               'システム設定(KKATCT)から、制御パラメータ取得(KKAPK0030.FCTGetR)を使用して、「外国人　氏名・生年月日制御帳票(ID)」のリストを取得した際に、エラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
            END IF;
            -- 「本名・通称名　出力制御」のリストを取得する
            nRTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, aITEM);
            IF nRTN = 0 AND sINDEXNO <= aITEM.COUNT THEN
              g_sSEYIGYO := aITEM(sINDEXNO);
            ELSIF nRTN <> 0 THEN
              bRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM,
               'システム設定(KKATCT)から、制御パラメータ取得(KKAPK0030.FCTGetR)を使用して「本名・通称名　出力制御」のリストを取得した際、エラーが発生しました。', g_sTANTOCODE, g_sWSNUM, 1);
            END IF;

--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00426対応
            IF g_rJSTP.CHOHYOID = 'GKB030R001' THEN
              --文書番号情報取得
              bRTN := KKBPK5551.FJBNSGet (g_nJOBNUM, g_rJSTP.STEPSEQ, rBUNNUMSRCINF);
              --文書番号編集結果を取得
              rBUNNUMEDITKEKA := rBUNNUMSRCINF.UOUT;
--  2024/11/12 ZCZL.WANGMING UPDATE 0.3.000.006:仕様変更　IT_GKB_00426対応
            END IF;
--  2024/06/27 ZCZL.shixinyu Add end
            -- 児童生徒中間データ作成
            I_RTN := FUNC_GET_JIDO_WK;
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
              IF I_RTN = c_INOTFOUND THEN
                GOTO ERROR_EXIT;
              END IF;
              RAISE ERR;
            END IF;
            -- 児童生徒ワークテーブル作成
            I_RTN := FUNC_INSERT_JIDO_WK;
            IF I_RTN = c_INOT_SUCCESS THEN
            -- エラーで帰ってきた場合
              RAISE ERR;
            END IF;
            -- 児童生徒中間データ作成（ＣＳＶ用）
            I_RTN := FUNC_GET_JIDO_WK_CSV;
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
              RAISE ERR;
            END IF;

--  2024/06/27 ZCZL.shixinyu Add 0.3.000.000:新WizLIFE２次開発
          IF g_nSTEP_INDEX = 1 THEN
            --ＣＳＶファイル作成処理前に件数カウント
            NKENSU := GKBPK00010.FTCOUNT('GKBWJIDOTSUCHI',NULL);
            g_nINDEX := g_nINDEX + 1;
            g_oKENSU_LIST.EXTEND(1);
            g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NKENSU,'入力　対象者件数',1);
--  2024/06/27 ZCZL.shixinyu Add 0.3.000.000:新WizLIFE２次開発
          END IF;

--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
        CASE g_rJSTP.Chohyoid
          WHEN 'GKB030R001' THEN
--  2024/06/27 ZCZL.shixinyu Add end
            -- 入学通知書ＣＳＶファイル作成
             I_RTN := FUNC_SET_JIDO_WK_CSVFILE1;
             IF I_RTN <> c_ISUCCESS THEN
             -- エラーで帰ってきた場合
               RAISE ERR;
             END IF;
--  2024/06/27 ZCZL.shixinyu Add 0.3.000.000:新WizLIFE２次開発
--  2024/10/08 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00218対応
--          WHEN 'GKB030R002' THEN
          WHEN 'GKB130R002' THEN
            -- 入学通知書発送者一覧表ＣＳＶファイル作成
            I_RTN := FUNC_SET_JIDO_WK_CSVFILE2;
            IF I_RTN <> c_ISUCCESS THEN
            -- エラーで帰ってきた場合
              RAISE ERR;
            END IF;
--  2024/06/27 ZCZL.shixinyu Add 0.3.000.000:新WizLIFE２次開発
          WHEN 'GKB160R004' THEN
            -- 児童生徒中間エラーデータ作成（ＣＳＶ用）
            I_RTN := FUNC_GET_JIDO_WK_ERRCSV;
            IF I_RTN = c_INOT_SUCCESS THEN
            -- エラーで帰ってきた場合
              RAISE ERR;
            END IF;
            -- 入学通知書エラー一覧表ＣＳＶファイル作成
            IF I_RTN <> c_INOTFOUND THEN
              I_RTN := FUNC_SET_JIDO_WK_ERRCSVFILE;
              IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
                RAISE ERR;
              END IF;
            END IF;
--  2024/06/27 ZCZL.shixinyu Add start 0.3.000.000:新WizLIFE２次開発
          ELSE
            NULL;
        END CASE;
--  2024/06/27 ZCZL.shixinyu Add end
          EXCEPTION
            /* その他エラー */
            WHEN OTHERS THEN
              -- SQL情報取得
              N_SQL_CODE := SQLCODE;
              V_SQL_MSG  := SUBSTR(SQLERRM, 1 ,250);
              -- 処理ログの出力
              B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, V_SQL_MSG, g_sTANTOCODE, g_sWSNUM, 1);
              RAISE;
          END;
--2024/06/27 ZCZL.shixinyu Delete 0.3.000.000:新WizLIFE２次開発
--        END IF;
        --帳票出力CSVの作成
        CASE g_rJSTP.Chohyoid
--  2024/06/27 ZCZL.shixinyu Update start 0.3.000.000:新WizLIFE２次開発
--           WHEN 'GKB040R001' THEN
--             bRTN :=FUNC_B11CSV('GKBWL040R001');
--           WHEN 'GKB160R002' THEN
--             bRTN :=FUNC_B11CSV('GKBWL160R002');
          WHEN 'GKB030R001' THEN
            bRTN :=FUNC_B11CSV('GKBWL030R001');
            --発送者文字切れリストの作成
-- 2025/05/28 CTC.HJF UPDATE Start 1.0.006.000:GKB_QA14364対応
            --bRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, 'GKB030R001', g_sTANTOCODE, 1, g_nCNT);
            bRTN := GKAPK00010.FKMJGRLST(g_nJOBNUM, g_sWSNUM, g_sTANTOCODE, 'GKB030R001', 1, g_nCNT);
-- 2025/05/28 CTC.HJF UPDATE End
--  2024/10/08 ZCZL.WANGMING UPDATE 0.3.000.003:仕様変更 IT_GKB_00218対応
--          WHEN 'GKB030R002' THEN
          WHEN 'GKB130R002' THEN
            bRTN :=FUNC_B11CSV('GKBWL130R022');
--  2024/06/27 ZCZL.shixinyu Update end
          WHEN 'GKB160R004' THEN
            bRTN :=FUNC_B11CSV('GKBWL160R004');
          ELSE
            NULL;
        END CASE;

        --最後ロジックの実行
        --ROLLBACKの処理、と件数表の値、既存の最後更新、削除処理等
        IF g_nSTEP_INDEX = g_nSTEP_MAX THEN
         --2024/04/22 ZCZL.LIKEWEN UPDATE START 0.2.000.001:512_GKB_00027対応
         --IF I_RTN = 0 THEN
          IF I_RTN = 0 OR I_RTN = c_INOTFOUND THEN
          --2024/04/22 ZCZL.LIKEWEN ADD END
              COMMIT;    --データ確定
           ELSE
              ROLLBACK;
              RAISE ERR;
           END IF;
        END IF;
        <<ERROR_EXIT>>

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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
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
    --  作成者／作成日: ZCZL.WANGYANYING   2024/01/05
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
END GKBPB00430;
/