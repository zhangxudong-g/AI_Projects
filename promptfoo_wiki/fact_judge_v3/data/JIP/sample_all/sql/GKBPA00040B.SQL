CREATE OR REPLACE PACKAGE BODY GKBPA00040
--1.0.302.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 学齢簿帳票情報出力
--  機能概要      : 個人番号と履歴連番をキーにして学齢簿情報を出力する。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
--------------------------------------------------------
--  変更履歴
--  2024/06/26 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.001:IT_GKB_00286横展開対応
--  2024/11/06 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00443横展開対応
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
--  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.004:IT_GKB_00711の対応
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応
--  2025/05/16 CTC.LIUJUNHAO UPDATE 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
--  2025/06/04 CTC.LIUJUNHAO UPDATE 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
--  2025/06/27 CTC.HJF UPDATE 1.0.010.000:IT_GKB_00003対応
--  2025/07/14 CTC.HJF UPDATE 1.0.010.001:GKB_QA18187_異動処理を行うと学齢簿が印刷エラーになる対応
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
--  2025/11/20 CTC.GL UPDATE 1.0.302.000:GKB_QA23586、QA21478対応
--------------------------------------------------------

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
    g_sSTARTDATE                  NVARCHAR2(23);               -- 開始時刻

    --パラメータ変数
    g_sKojinNo             NUMBER;
    g_sRirekiRenban        NUMBER;
    g_sIinkai              NUMBER;
--  2025/11/20 CTC.GL UPDATE START 1.0.302.000:GKB_QA23586、QA21478対応
    g_sGakunen             NUMBER;
--  2025/11/20 CTC.GL UPDATE END
-- 2024/06/26 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
    g_sSIENJYUSYO          NVARCHAR2(1000);
    g_sHAKOUTEXT           NVARCHAR2(1000);
    B_RTN                  BOOLEAN;
    g_sSHIMEIJKN_CHOHYO    A_CONS_PRM;         -- インデックス番号
    g_sEQSHIMEI            A_CONS_PRM;         --本名・通称名　出力制御
    g_sATENA               NVARCHAR2(100);     --宛名ラベル_出力制御
    g_nGKB010_INDEX        NUMBER;
    rGKBTTSUCHISHOKANRITY   GKBTTSUCHISHOKANRI%ROWTYPE; --通知書管理情報
    TYPE TYPECURSOR  IS REF CURSOR;
   --支援措置対象者情報
   TYPE GACTKANRI_REC IS RECORD
    (
    TOROKU_GYOMU              CHAR(8),
    SHIENSOCHIKBN             NUMBER,
    SHIENSOCHISHURYOKBN       NUMBER,
    SHIENSOCHIKAISHIBI        NUMBER,
    SHIENSOCHISHURYOBI        NUMBER,
    TAISHOSHAKBN              NUMBER,
    KARISHIENSOCHIKAISHIBI    NUMBER,
    KARISHIENSOCHISHURYOBI    NUMBER,
    SHIENSOCHIKAIJOBI         NUMBER
    );   
   GACTKANRIS_REC        GACTKANRI_REC;
   v_TOROKU_GYOMU           A_CONS_PRM;
   v_SHIENSOCHIKBN          A_CONS_PRM;
   v_SHIENSOCHISHURYOKBN    A_CONS_PRM;
   v_SHIENSOCHIKAISHIBI     A_CONS_PRM;
   v_SHIENSOCHISHURYOBI     A_CONS_PRM;
   v_TAISHOSHAKBN           A_CONS_PRM;
   v_KARISHIENSOCHIKAISHIBI A_CONS_PRM;
   v_KARISHIENSOCHISHURYOBI A_CONS_PRM;
   v_SHIENSOCHIKAIJOBI      A_CONS_PRM;
   ICNT                     NUMBER := 0;
-- 2024/06/26 ZCZL.wangqiwei Add end
    o_SqlCode              NUMBER; 
    o_SqlMsg               NVARCHAR2(300); 
    YUYO_JIYU              NVARCHAR2(1000);
    MENJO_JIYU             NVARCHAR2(1000);
    YUYO_JIYU_CD            GKBTGAKUREIBO%ROWTYPE;
    MENJO_JIYU_CD           GKBTGAKUREIBO%ROWTYPE;
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
    -- 処理結果
    c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    -- ERROR関連 --
    I_RTN           PLS_INTEGER;     -- 戻り値
    -- ＣＳＶファイル操作
    ISAKUSEIBI      PLS_INTEGER;
    IGAKO_CD        PLS_INTEGER;                    -- 学校区コード
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN                        BOOLEAN;
    -- 各制御用のフラグ
    BPRMFLG_001      BOOLEAN;
    BPRMFLG_002      BOOLEAN;
    BPRMFLG_003      BOOLEAN;
    BPRMFLG_004      BOOLEAN;
    o_YMD2           NVARCHAR2(30);
--  2025/11/20 CTC.GL UPDATE START 1.0.302.000:GKB_QA23586、QA21478対応
    CURSOR CUR_GAKUNEN(p_KojinNo IN NUMBER, p_RirekiRenban IN NUMBER) IS
        SELECT GAKUNEN
        FROM GKBTGAKUREIBO
        WHERE KOJIN_NO = p_KojinNo
          AND RIREKI_RENBAN = p_RirekiRenban
          AND SAKUJO_FLG = 0;
--  2025/11/20 CTC.GL UPDATE END
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
--  2025/11/20 CTC.GL UPDATE START 1.0.302.000:GKB_QA23586、QA21478対応
--    CURSOR GAKUREIBO(p_KojinNo IN NUMBER, p_RirekiRenban IN NUMBER) IS
    CURSOR GAKUREIBO(p_KojinNo IN NUMBER, p_RirekiRenban IN NUMBER, p_Gakunen IN NUMBER) IS
--  2025/11/20 CTC.GL UPDATE END
      SELECT
      NVL(A.SYOGAKO_CD,0) SYOGAKO_CD,                   --小学校区コード
      NVL(A.SYOGAKO_NYUGAKU_BI,0) SYOGAKO_NYUGAKU_BI,
      NVL(A.SYOGAKO_TENNYUGAKU_BI,0) SYOGAKO_TENNYUGAKU_BI,
      NVL(A.SYOGAKO_TENGAKU_BI,0) SYOGAKO_TENGAKU_BI,
      NVL(A.SYOGAKO_SOTSUGYO_BI,0) SYOGAKO_SOTSUGYO_BI,
      NVL(A.TYUGAKO_CD,0) TYUGAKO_CD,                   --中学校区コード
      NVL(A.TYUGAKO_NYUGAKU_BI,0) TYUGAKO_NYUGAKU_BI,
      NVL(A.TYUGAKO_TENNYUGAKU_BI,0) TYUGAKO_TENNYUGAKU_BI,
      NVL(A.TYUGAKO_TENGAKU_BI,0) TYUGAKO_TENGAKU_BI,
      NVL(A.TYUGAKO_SOTSUGYO_BI,0) TYUGAKO_SOTSUGYO_BI,
      NVL(A.KUIKIGAI_CD,0) KUIKIGAI_CD,                 --区域外学校コード
      NVL(A.KUIKIGAI_SETISYA,' ') KUIKIGAI_SETISYA,
      NVL(A.KUIKIGAI_NYUGAKU_BI,0) KUIKIGAI_NYUGAKU_BI,
      NVL(A.KUIKIGAI_TENNYUGAKU_BI,0) KUIKIGAI_TENNYUGAKU_BI,
      DECODE(NVL(A.KUIKIGAI_TENGAKU_BI,0),0,NVL(A.KUIKIGAI_TAIGAKU_BI,0),A.KUIKIGAI_TENGAKU_BI) KUIKIGAI_TENTAIGAKU_BI,
      NVL(A.KUIKIGAI_TENGAKU_BI,0) KUIKIGAI_TENGAKU_BI, --区域外転学年月日
      NVL(A.KUIKIGAI_TAIGAKU_BI,0) KUIKIGAI_TAIGAKU_BI, --区域外退学年月日
      NVL(A.KUIKIGAI_SOTSUGYO_BI,0) KUIKIGAI_SOTSUGYO_BI,
      NVL(A.YOGOGAKO_CD,0) YOGOGAKO_CD,                 --養護学校コード
      NVL(A.YOGOGAKO_SETISYA,' ') YOGOGAKO_SETISYA,
      NVL(A.YOGOGAKO_NYUGAKU_BI,0) YOGOGAKO_NYUGAKU_BI,
      NVL(A.YOGOGAKO_TENNYUGAKU_BI,0) YOGOGAKO_TENNYUGAKU_BI,
      DECODE(NVL(A.YOGOGAKO_TENGAKU_BI,0),0,NVL(A.YOGOGAKO_TAIGAKU_BI,0),A.YOGOGAKO_TENGAKU_BI) YOGOGAKO_TENTAIGAKU_BI,
      NVL(A.YOGOGAKO_TENGAKU_BI,0) YOGOGAKO_TENGAKU_BI, --盲聾養護学校転学年月日
      NVL(A.YOGOGAKO_TAIGAKU_BI,0) YOGOGAKO_TAIGAKU_BI, --盲聾養護学校退学年月日
      NVL(A.YOGOGAKO_SOTSUGYO_BI,0) YOGOGAKO_SOTSUGYO_BI,
      NVL(A.YUYO_KYOKA_BI,0) YUYO_KYOKA_BI,
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応  STR    
      TO_CHAR(A.YUYO_JIYU_CD, 'FM00') AS YUYO_JIYU_CD, 
      --NVL(A.YUYO_JIYU,' ') YUYO_JIYU,
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応  END    
      NVL(A.YUYO_KAISI_BI,0) YUYO_KAISI_BI,
      NVL(A.YUYO_SYURYO_BI,0) YUYO_SYURYO_BI,
      NVL(A.YUYO_FUKUGAKU_BI,0) YUYO_FUKUGAKU_BI,
      NVL(A.MENJO_KYOKA_BI,0) MENJO_KYOKA_BI,
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応  STR    
      TO_CHAR(A.MENJO_JIYU_CD, 'FM00') AS MENJO_JIYU_CD,
      --NVL(A.MENJO_JIYU,' ') MENJO_JIYU,
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応  END    
      NVL(A.MENJO_FUKUGAKU_BI,0) MENJO_FUKUGAKU_BI,
      NVL(A.TOKUSOKU_BI1,0) TOKUSOKU_BI1,          --督促年月日１
      NVL(A.TOKUSOKU_NAIYO1,' ') TOKUSOKU_NAIYO1,  --督促内容１
      NVL(A.TOKUSOKU_BI2,0) TOKUSOKU_BI2,          --督促年月日２
      NVL(A.TOKUSOKU_NAIYO2,' ') TOKUSOKU_NAIYO2,  --督促内容２
      NVL(A.TOKUSOKU_BI3,0) TOKUSOKU_BI3,          --督促年月日３
      NVL(A.TOKUSOKU_NAIYO3,' ') TOKUSOKU_NAIYO3,  --督促内容３
      NVL(A.TOKUSOKU_BI4,0) TOKUSOKU_BI4,          --督促年月日４
      NVL(A.TOKUSOKU_NAIYO4,' ') TOKUSOKU_NAIYO4,  --督促内容４
      NVL(A.TOKUSOKU_BI5,0) TOKUSOKU_BI5,          --督促年月日５
      NVL(A.TOKUSOKU_NAIYO5,' ') TOKUSOKU_NAIYO5,  --督促内容５
-- 2024/07/01 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--       NVL(A.IDO_BI1,0) IDO_BI1,                    --異動日１
--       NVL(A.IDO_JIYU1,' ') IDO_JIYU1,              --異動事由１
--       NVL(A.IDO_BI2,0) IDO_BI2,                    --異動日２
--       NVL(A.IDO_JIYU2,' ') IDO_JIYU2,              --異動事由２
--       NVL(A.IDO_BI3,0) IDO_BI3,                    --異動日３
--       NVL(A.IDO_JIYU3,' ') IDO_JIYU3,              --異動事由３
--       NVL(A.IDO_BI4,0) IDO_BI4,                    --異動日４
--       NVL(A.IDO_JIYU4,' ') IDO_JIYU4,              --異動事由４
--       NVL(A.IDO_BI5,0) IDO_BI5,                    --異動日５
--       NVL(A.IDO_JIYU5,' ') IDO_JIYU5,              --異動事由５
--       NVL(A.IDO_BI6,0) IDO_BI6,                    --異動日６
--       NVL(A.IDO_JIYU6,' ') IDO_JIYU6,              --異動事由６
--       NVL(A.IDO_BI7,0) IDO_BI7,                    --異動日７
--       NVL(A.IDO_JIYU7,' ') IDO_JIYU7,              --異動事由７
--       NVL(A.IDO_BI8,0) IDO_BI8,                    --異動日８
--       NVL(A.IDO_JIYU8,' ') IDO_JIYU8,              --異動事由８
--       NVL(A.IDO_BI9,0) IDO_BI9,                    --異動日９
--       NVL(A.IDO_JIYU9,' ') IDO_JIYU9,              --異動事由９
--       NVL(A.IDO_BI10,0) IDO_BI10,                  --異動日１０
--       NVL(A.IDO_JIYU10,' ') IDO_JIYU10,            --異動事由１０
      NVL(A.TOKUSOKU_BI6,0) TOKUSOKU_BI6,          --督促年月日6
      NVL(A.TOKUSOKU_NAIYO6,' ') TOKUSOKU_NAIYO6,  --督促内容6
      NVL(A.TOKUSOKU_BI7,0) TOKUSOKU_BI7,          --督促年月日7
      NVL(A.TOKUSOKU_NAIYO7,' ') TOKUSOKU_NAIYO7,  --督促内容7
      NVL(A.TOKUSOKU_BI8,0) TOKUSOKU_BI8,          --督促年月日8
      NVL(A.TOKUSOKU_NAIYO8,' ') TOKUSOKU_NAIYO8,  --督促内容8
      NVL(A.TOKUSOKU_BI9,0) TOKUSOKU_BI9,          --督促年月日9
      NVL(A.TOKUSOKU_NAIYO9,' ') TOKUSOKU_NAIYO9,  --督促内容9
      NVL(A.TOKUSOKU_BI10,0) TOKUSOKU_BI10,        --督促年月日５
      NVL(A.TOKUSOKU_NAIYO10,' ') TOKUSOKU_NAIYO10,--督促内容５
-- 2024/07/01 ZCZL.wangqiwei Update end
      NVL(B1.SHIMEI_KANA,' ') SHIMEI_KANA,
      NVL(B1.SHIMEI_KANJI,' ') SHIMEI_KANJI,
      B1.JINKAKU_KBN,
      NVL(B1.HONMYO_KANA,' ') HONMYO_KANA,
      NVL(B1.HONMYO_KANJI,' ') HONMYO_KANJI,
      DECODE(NVL(B1.SEIBETSU,0),1,'男',2,'女',' ') SEIBETSU,
      NVL(B1.SEINENGAPI,0) SEINENGAPI,
      NVL(B1.YUBIN_NO,' ') YUBIN_NO,
      NVL(B1.CHOMEI,' ') CHOMEI,
      NVL(B1.BANCHI,' ') BANCHI,
      NVL(B1.KATAGAKI,' ') KATAGAKI,
      NVL(B1.GYOSEIKU_CD,0) GYOSEIKU_CD,                  --児童行政区コード
      NVL(B1.SANTEIDANTAI_CD,0) SANTEIDANTAI_CD,          --児童算定団体コード
      NVL(B2.SHIMEI_KANA,' ') HOGOSYA_SHIMEI_KANA,
      NVL(B2.SHIMEI_KANJI,' ') HOGOSYA_SHIMEI_KANJI,
      NVL(B2.SEIBETSU,0) HOGOSYA_SEIBETSU,
      NVL(B2.SEINENGAPI,0) HOGOSYA_SEINENGAPI,
      NVL(B2.SETAI_NO,0) HOGOSYA_SETAI_NO,
      NVL(B2.YUBIN_NO,' ') HOGOSYA_YUBIN_NO,
      NVL(B2.CHOMEI,' ') HOGOSYA_CHOMEI,
      NVL(B2.BANCHI,' ') HOGOSYA_BANCHI,
      NVL(B2.KATAGAKI,' ') HOGOSYA_KATAGAKI,
      NVL(B2.GYOSEIKU_CD,0) HOGOSYA_GYOSEIKU_CD,          --保護者行政区コード
      NVL(B2.SANTEIDANTAI_CD,0) HOGOSYA_SANTEIDANTAI_CD,  --保護者算定団体コード
-- 2024/07/01 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--       NVL(F1.ZOKUGARAMEI,' ') ZOKUGARAMEI1,
--       NVL(F2.ZOKUGARAMEI,' ') ZOKUGARAMEI2,
--       NVL(F3.ZOKUGARAMEI,' ') ZOKUGARAMEI3,
--       NVL(F4.ZOKUGARAMEI,' ') ZOKUGARAMEI4,
     　A.HOGOSYA_ZOKUGARA1      --学齢簿.保護者続柄１
      ,　A.HOGOSYA_ZOKUGARA2    --学齢簿.保護者続柄２
      ,　A.HOGOSYA_ZOKUGARA3    --学齢簿.保護者続柄３
      ,　A.HOGOSYA_ZOKUGARA4,   --学齢簿.保護者続柄４
-- 2024/07/01 ZCZL.wangqiwei Update end
      NVL(G.SYOGAKOMEI,' ') SYOGAKOMEI,
      NVL(H.TYUGAKOMEI,' ') TYUGAKOMEI,
      NVL(I.KUIKIGAIMEI,' ') KUIKIGAIMEI,
      NVL(A.KOJIN_NO,0) KOJIN_NO,        -- 個人番号
      NVL(A.ZOKUGARA1,0) ZOKUGARA1,        -- 続柄１
      NVL(A.ZOKUGARA2,0) ZOKUGARA2,        -- 続柄2
      NVL(A.ZOKUGARA3,0) ZOKUGARA3,        -- 続柄3
      NVL(A.ZOKUGARA4,0) ZOKUGARA4,        -- 続柄4
      NVL(A.SYOGAKO_TENNYUGAKU_GAKUNEN,0) SYOGAKO_TENNYUGAKU_GAKUNEN,     -- 小学校転入学 学年
      NVL(A.SYOGAKO_TENGAKU_GAKUNEN,0) SYOGAKO_TENGAKU_GAKUNEN,           -- 小学校転学 学年
      NVL(A.TYUGAKO_TENNYUGAKU_GAKUNEN,0) TYUGAKO_TENNYUGAKU_GAKUNEN,     -- 中学校転入学 学年
      NVL(A.TYUGAKO_TENGAKU_GAKUNEN,0) TYUGAKO_TENGAKU_GAKUNEN,           -- 中学校転学 学年
      NVL(A.KUIKIGAI_TENNYUGAKU_GAKUNEN,0) KUIKIGAI_TENNYUGAKU_GAKUNEN,   -- 区域外転入学 学年
      NVL(A.KUIKIGAI_TENGAKU_GAKUNEN,0) KUIKIGAI_TENGAKU_GAKUNEN,         -- 区域外転学 学年
      NVL(A.KUIKIGAI_TAIGAKU_GAKUNEN,0) KUIKIGAI_TAIGAKU_GAKUNEN,         -- 区域外退学 学年
      NVL(A.YOGOGAKO_TENNYUGAKU_GAKUNEN,0) YOGOGAKO_TENNYUGAKU_GAKUNEN,   -- 盲聾養護転入学 学年
      NVL(A.YOGOGAKO_TENGAKU_GAKUNEN,0) YOGOGAKO_TENGAKU_GAKUNEN,         -- 盲聾養護転学 学年
      NVL(A.YOGOGAKO_TAIGAKU_GAKUNEN,0) YOGOGAKO_TAIGAKU_GAKUNEN,         -- 盲聾養護退学 学年
      NVL(REPLACE(REPLACE(REPLACE(A.SHUGAKU, chr(10), '#'), chr(13), '#'),'##','#'),' ') SHUGAKU,         --就学状況
      NVL(REPLACE(REPLACE(REPLACE(A.IDOJIKO, chr(10), '#'), chr(13), '#'),'##','#'),' ') IDOJIKO,         --異動事由
      A.CHOHYO_NO CHOHYO_NO,                                              -- 帳票連番
      NVL(A.HOGOSYA_KOJIN_NO, 0) HOGOSYA_KOJIN_NO,                        -- 保護者個人番号
      NVL(A.GAKUNEN, 0) GAKUNEN,                                          -- 学年
      NVL(J.YOGOGAKOMEI,' ') YOGOGAKOMEI
-- 2024/07/01 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
-- 2025/11/20 CTC.GL UPDATE START 1.0.302.000:GKB_QA23586、QA21478対応
--      , GKBTSHUGAKURIREKI.S_TAIGAKU_BI
--      , GKBTSHUGAKURIREKI.S_TAIGAKU_GAKUNEN
--      , GKBTSHUGAKURIREKI.T_TAIGAKU_BI
--      , GKBTSHUGAKURIREKI.T_TAIGAKU_GAKUNEN
--      , GKBTSHUGAKURIREKI.KUIKIGAI_S_CD
--      , GKBTSHUGAKURIREKI.KUIKIGAI_S_NYUGAKU_BI
--      , GKBTSHUGAKURIREKI.KUIKIGAI_S_TENNYU_BI
--      , GKBTSHUGAKURIREKI.KUIKIGAI_S_TENNYU_GAKUNEN
--      , GKBTSHUGAKURIREKI.KUIKIGAI_S_TENGAKU_BI
--      , GKBTSHUGAKURIREKI.KUIKIGAI_S_TENGAKU_GAKUNEN
--      , GKBTSHUGAKURIREKI.KUIKIGAI_S_TAIGAKU_BI
--      , GKBTSHUGAKURIREKI.KUIKIGAI_S_TAIGAKU_GAKUNEN
--      , GKBTSHUGAKURIREKI.KUIKIGAI_S_SOTSUGYO_BI
--      , GKBTSHUGAKURIREKI.KUIKIGAI_T_CD
--      , GKBTSHUGAKURIREKI.KUIKIGAI_T_NYUGAKU_BI
--      , GKBTSHUGAKURIREKI.KUIKIGAI_T_TENNYU_BI
--      , GKBTSHUGAKURIREKI.KUIKIGAI_T_TENNYU_GAKUNEN
--      , GKBTSHUGAKURIREKI.KUIKIGAI_T_TENGAKU_BI
--      , GKBTSHUGAKURIREKI.KUIKIGAI_T_TENGAKU_GAKUNEN
--      , GKBTSHUGAKURIREKI.KUIKIGAI_T_TAIGAKU_BI
--      , GKBTSHUGAKURIREKI.KUIKIGAI_T_TAIGAKU_GAKUNEN
--      , GKBTSHUGAKURIREKI.KUIKIGAI_T_SOTSUGYO_BI
--      , GKBTSHUGAKURIREKI.SHIEN_S_CD
--      , GKBTSHUGAKURIREKI.SHIEN_S_NYUGAKU_BI
--      , GKBTSHUGAKURIREKI.SHIEN_S_TENNYU_BI
--      , GKBTSHUGAKURIREKI.SHIEN_S_TENNYU_GAKUNEN
--      , GKBTSHUGAKURIREKI.SHIEN_S_TENGAKU_BI
--      , GKBTSHUGAKURIREKI.SHIEN_S_TENGAKU_GAKUNEN
--      , GKBTSHUGAKURIREKI.SHIEN_S_TAIGAKU_BI
--      , GKBTSHUGAKURIREKI.SHIEN_S_TAIGAKU_GAKUNEN
--      , GKBTSHUGAKURIREKI.SHIEN_S_SOTSUGYO_BI
--      , GKBTSHUGAKURIREKI.SHIEN_T_CD
--      , GKBTSHUGAKURIREKI.SHIEN_T_NYUGAKU_BI
--      , GKBTSHUGAKURIREKI.SHIEN_T_TENNYU_BI
--      , GKBTSHUGAKURIREKI.SHIEN_T_TENNYU_GAKUNEN
--      , GKBTSHUGAKURIREKI.SHIEN_T_TENGAKU_BI
--      , GKBTSHUGAKURIREKI.SHIEN_T_TENGAKU_GAKUNEN
--      , GKBTSHUGAKURIREKI.SHIEN_T_TAIGAKU_BI
--      , GKBTSHUGAKURIREKI.SHIEN_T_TAIGAKU_GAKUNEN
--      , GKBTSHUGAKURIREKI.SHIEN_T_SOTSUGYO_BI 
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.S_TAIGAKU_BI END AS S_TAIGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.S_TAIGAKU_GAKUNEN END AS S_TAIGAKU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.T_TAIGAKU_BI END AS T_TAIGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.T_TAIGAKU_GAKUNEN END AS T_TAIGAKU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_S_CD END AS KUIKIGAI_S_CD
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_S_NYUGAKU_BI END AS KUIKIGAI_S_NYUGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_S_TENNYU_BI END AS KUIKIGAI_S_TENNYU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_S_TENNYU_GAKUNEN END AS KUIKIGAI_S_TENNYU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_S_TENGAKU_BI END AS KUIKIGAI_S_TENGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_S_TENGAKU_GAKUNEN END AS KUIKIGAI_S_TENGAKU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_S_TAIGAKU_BI END AS KUIKIGAI_S_TAIGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_S_TAIGAKU_GAKUNEN END AS KUIKIGAI_S_TAIGAKU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_S_SOTSUGYO_BI END AS KUIKIGAI_S_SOTSUGYO_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_T_CD END AS KUIKIGAI_T_CD
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_T_NYUGAKU_BI END AS KUIKIGAI_T_NYUGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_T_TENNYU_BI END AS KUIKIGAI_T_TENNYU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_T_TENNYU_GAKUNEN END AS KUIKIGAI_T_TENNYU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_T_TENGAKU_BI END AS KUIKIGAI_T_TENGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_T_TENGAKU_GAKUNEN END AS KUIKIGAI_T_TENGAKU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_T_TAIGAKU_BI END AS KUIKIGAI_T_TAIGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_T_TAIGAKU_GAKUNEN END AS KUIKIGAI_T_TAIGAKU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.KUIKIGAI_T_SOTSUGYO_BI END AS KUIKIGAI_T_SOTSUGYO_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_S_CD END AS SHIEN_S_CD
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_S_NYUGAKU_BI END AS SHIEN_S_NYUGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_S_TENNYU_BI END AS SHIEN_S_TENNYU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_S_TENNYU_GAKUNEN END AS SHIEN_S_TENNYU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_S_TENGAKU_BI END AS SHIEN_S_TENGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_S_TENGAKU_GAKUNEN END AS SHIEN_S_TENGAKU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_S_TAIGAKU_BI END AS SHIEN_S_TAIGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_S_TAIGAKU_GAKUNEN END AS SHIEN_S_TAIGAKU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_S_SOTSUGYO_BI END AS SHIEN_S_SOTSUGYO_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_T_CD END AS SHIEN_T_CD
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_T_NYUGAKU_BI END AS SHIEN_T_NYUGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_T_TENNYU_BI END AS SHIEN_T_TENNYU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_T_TENNYU_GAKUNEN END AS SHIEN_T_TENNYU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_T_TENGAKU_BI END AS SHIEN_T_TENGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_T_TENGAKU_GAKUNEN END AS SHIEN_T_TENGAKU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_T_TAIGAKU_BI END AS SHIEN_T_TAIGAKU_BI
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_T_TAIGAKU_GAKUNEN END AS SHIEN_T_TAIGAKU_GAKUNEN
        , CASE WHEN p_Gakunen = 0 THEN 0 ELSE R.SHIEN_T_SOTSUGYO_BI END AS SHIEN_T_SOTSUGYO_BI
-- 2025/11/20 CTC.GL UPDATE END
-- 2024/07/01 ZCZL.wangqiwei Add end
      FROM
      GKBTGAKUREIBO A,
      GABTATENAKIHON B1,
      GABTATENAKIHON B2,
-- 2024/07/01 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発の標準化対応
--       GKBTZOKUGARA F1,
--       GKBTZOKUGARA F2,
--       GKBTZOKUGARA F3,
--       GKBTZOKUGARA F4,
-- 2024/07/01 ZCZL.wangqiwei Delete end
      GKBTSHOGAKKO G,
      GKBTCHUGAKKO H,
      GKBTKUIKIGAI I,
      GKBTYOGOGAKKO J
-- 2024/07/01 ZCZL.wangqiwei Add 0.3.000.000:新WizLIFE2次開発の標準化対応
-- 2025/11/20 CTC.GL UPDATE START 1.0.302.000:GKB_QA23586、QA21478対応
--      , GKBTSHUGAKURIREKI
      , GKBTSHUGAKURIREKI R
--  2025/11/20 CTC.GL UPDATE END
      WHERE
      A.HOGOSYA_KOJIN_NO = B2.KOJIN_NO(+) and
-- 2024/07/01 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発の標準化対応
--       A.HOGOSYA_ZOKUGARA1 = F1.ZOKUGARA_CD(+) and
--       A.HOGOSYA_ZOKUGARA2 = F2.ZOKUGARA_CD(+) and
--       A.HOGOSYA_ZOKUGARA3 = F3.ZOKUGARA_CD(+) and
--       A.HOGOSYA_ZOKUGARA4 = F4.ZOKUGARA_CD(+) and
-- 2024/07/01 ZCZL.wangqiwei Delete end
      A.SYOGAKO_CD = G.SYOGAKO_CD(+) and
      A.TYUGAKO_CD = H.TYUGAKO_CD(+) and
      A.KUIKIGAI_CD = I.KUIKIGAI_CD(+) and
      A.YOGOGAKO_CD = J.YOGOGAKO_CD(+) and
      A.RIREKI_RENBAN = p_RirekiRenban and
      B1.KOJIN_NO = p_KojinNo and
      B1.KOJIN_NO = A.KOJIN_NO(+) and
-- 2024/07/01 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--       F1.ZOKUGARA_KBN(+) = 2 and
--       F2.ZOKUGARA_KBN(+) = 2 and
--       F3.ZOKUGARA_KBN(+) = 2 and
--       F4.ZOKUGARA_KBN(+) = 2;
--  2025/11/20 CTC.GL UPDATE START 1.0.302.000:GKB_QA23586、QA21478対応
--      A.KOJIN_NO = GKBTSHUGAKURIREKI.KOJIN_NO 
--      AND A.RIREKI_RENBAN = GKBTSHUGAKURIREKI.KOJIN_RIREKI_RENBAN 
--      AND GKBTSHUGAKURIREKI.KOJIN_NO = p_KojinNo 
--      AND GKBTSHUGAKURIREKI.SAKUJO_FLG = 0 
--      AND GKBTSHUGAKURIREKI.SAISHIN_FLG = 0
--      AND A.SAISHIN_KBN = 0 
--      AND A.SAKUJO_FLG = 0 ;
         (p_Gakunen = 0
            OR (
                p_Gakunen <> 0
                AND A.KOJIN_NO = R.KOJIN_NO
                AND R.KOJIN_NO = p_KojinNo
                AND R.SAKUJO_FLG = 0
                AND R.SAISHIN_FLG = 0
                AND R.KOJIN_RIREKI_RENBAN = (
                    SELECT MAX(KOJIN_RIREKI_RENBAN)
                    FROM GKBTSHUGAKURIREKI
                    WHERE KOJIN_NO = A.KOJIN_NO
                    AND SAKUJO_FLG = 0
                )
            )
        )
        AND A.RIREKI_RENBAN = (
            SELECT MAX(RIREKI_RENBAN)
            FROM GKBTGAKUREIBO
            WHERE KOJIN_NO = A.KOJIN_NO 
            AND SAKUJO_FLG = 0
        )
        AND A.SAISHIN_KBN = 0
        AND A.SAKUJO_FLG = 0;
--  2025/11/20 CTC.GL UPDATE END
-- 2024/07/01 ZCZL.wangqiwei Update end
      
     -- カーソル定義
     RECGAKUREIBO         GAKUREIBO%ROWTYPE;
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
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
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
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
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
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
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
                WHEN 1 THEN
                     g_sKojinNo       := aCSV_TBL(i);         -- 個人番号
                WHEN 2 THEN
                     g_sRirekiRenban  := aCSV_TBL(i);         -- 履歴連番
                WHEN 3 THEN
                     g_sIinkai        := aCSV_TBL(i);         -- 帳票区分
-- 2024/06/26 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
                WHEN 4 THEN
                     g_sSIENJYUSYO    := aCSV_TBL(i);         -- 支援措置対象住所
                WHEN 5 THEN
                     g_sHAKOUTEXT     := aCSV_TBL(i);         -- 発行部数テキスト
-- 2024/06/26 ZCZL.wangqiwei Add end
                ELSE
                    NULL;
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
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
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
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
    --------------------------------------------------------
    FUNCTION FUNC_O20CSV(i_sGYOUMUCODE  IN  NVARCHAR2,
                         i_TBLNAME      IN  NVARCHAR2,
-- 2024/06/11 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                          i_sCHOHYOID    IN  NVARCHAR2)
                         g_sIinkai      IN  NVARCHAR2)
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
-- 2024/06/26 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                                        i_sCHOHYOID,
                                       g_sIinkai,
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
-- 2024/06/26 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                                        i_sCHOHYOID,
                                       g_sIinkai,
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
-- 2024/06/26 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--                                        i_sCHOHYOID,
                                       g_sIinkai,
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
    --  機能概要      : 日付変換
    --  パラメータ    : i_YMD
    --               o_YMD
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
    --------------------------------------------------------
    PROCEDURE PROC_GET_YMD(i_YMD IN NUMBER, o_YMD OUT NVARCHAR2) IS
      WbRtn             BOOLEAN;
      io_WAREKIHIZUKE   PLS_INTEGER:=0;
      io_SEIREKIHIZUKE  PLS_INTEGER:=i_YMD;
      o_EDIT_GYYMMDD1   NVARCHAR2(9);
      o_EDIT_GYYMMDD2   NVARCHAR2(9);
      o_EDIT_GYYMMDD3   NVARCHAR2(11);
      o_KJ_GENGO        NVARCHAR2(2);
      o_KG_GENGO        NVARCHAR2(1);
      o_WAREKI_YY       PLS_INTEGER;
      o_SEIREKI_YYYY    PLS_INTEGER;
      o_WAREKI_GYYMM    PLS_INTEGER;
      o_MM              PLS_INTEGER;
      o_DD              PLS_INTEGER;
      o_IWAREKIHIZUKE   PLS_INTEGER;
      o_ISEIREKIHIZUKE  PLS_INTEGER;
    BEGIN
      WbRtn:=KKAPK0020.FDAYEDIT(io_WAREKIHIZUKE,
                                 io_SEIREKIHIZUKE,
                                 o_EDIT_GYYMMDD1,
                                 o_EDIT_GYYMMDD2,
                                 o_EDIT_GYYMMDD3,
                                 o_KJ_GENGO,
                                 o_KG_GENGO,
                                 o_WAREKI_YY,
                                 o_SEIREKI_YYYY,
                                 o_WAREKI_GYYMM,
                                 o_MM,
                                 o_DD,
                                 o_IWAREKIHIZUKE,
                                 o_ISEIREKIHIZUKE);
      IF WbRtn THEN
        o_YMD := o_EDIT_GYYMMDD3;
      ELSE
        o_YMD := ' ';
      END IF;
    END PROC_GET_YMD;

    --  機能概要      : 制御のフラグをセットするのを行う
    --  パラメータ    : i_KOJIN_NO
    --               i_PRM
    --               o_NAIYO_CD
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
    --------------------------------------------------------
    FUNCTION FUNC_PRMFLGSET(i_KOJIN_NO IN NUMBER, i_PRM IN NUMBER, o_NAIYO_CD OUT NUMBER) RETURN NUMBER IS
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

      --児童の制御情報を取得
      BEGIN
        SELECT NAIYO_CD INTO o_NAIYO_CD FROM GKBTSHIMEIJKN
         WHERE KOJIN_NO = g_sKojinNo AND CHOHYO_ID = 'GKB050R001';
        IF o_NAIYO_CD = 0 THEN
          ZERO_FLG  := TRUE;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
        NODATAFOUND_FLG  := TRUE;
      END;

      --氏名印字.制御ﾊﾟﾗﾒｰﾀ(1)が1の場合
      IF i_PRM = 1 THEN
        BPRMFLG_001  := TRUE;
      END IF;
      --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(1)が4、6場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF i_PRM IN (4, 6) THEN
          BPRMFLG_002  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在する、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(1)が3、4、5、6場合
      IF NOT NODATAFOUND_FLG AND NOT ZERO_FLG THEN
        IF i_PRM IN(3,4,5,6) THEN
          BPRMFLG_003  := TRUE;
        END IF;
      END IF;
        -- 本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(1)が4、5場合「生年月日」
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF i_PRM IN (4, 5) THEN
          BPRMFLG_004  := TRUE;
        END IF;
      END IF;
    RETURN 0;
    END FUNC_PRMFLGSET;
    --------------------------------------------------------
    --  機能概要      : 日付変換2
    --  パラメータ    : i_KBN
    --               i_YMD
    --               i_NAIYO_CD_PRM
    --               o_YMD
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
    --------------------------------------------------------
    PROCEDURE PROC_GET_YMD1(i_KBN IN NUMBER,i_YMD IN NUMBER,i_NAIYO_CD_PRM IN NUMBER, o_YMD OUT NVARCHAR2) IS
      io_WAREKIHIZUKE  PLS_INTEGER := 0;
      io_SEIREKIHIZUKE PLS_INTEGER := i_YMD;
      o_EDIT_GYYMMDD1  NVARCHAR2(9);
      o_EDIT_GYYMMDD2  NVARCHAR2(9);
      o_EDIT_GYYMMDD3  NVARCHAR2(11);
      o_KJ_GENGO       NVARCHAR2(2);
      o_KG_GENGO       NVARCHAR2(1);
      o_WAREKI_YY      PLS_INTEGER;
      o_SEIREKI_YYYY   PLS_INTEGER;
      o_WAREKI_GYYMM   PLS_INTEGER;
      o_MM             PLS_INTEGER;
      o_DD             PLS_INTEGER;
      o_IWAREKIHIZUKE  PLS_INTEGER;
      o_ISEIREKIHIZUKE PLS_INTEGER;
      IRTN             PLS_INTEGER;
    BEGIN
      BRTN := KKAPK0020.FDAYEDIT(io_WAREKIHIZUKE,
                                  io_SEIREKIHIZUKE,
                                  o_EDIT_GYYMMDD1,
                                  o_EDIT_GYYMMDD2,
                                  o_EDIT_GYYMMDD3,
                                  o_KJ_GENGO,
                                  o_KG_GENGO,
                                  o_WAREKI_YY,
                                  o_SEIREKI_YYYY,
                                  o_WAREKI_GYYMM,
                                  o_MM,
                                  o_DD,
                                  o_IWAREKIHIZUKE,
                                  o_ISEIREKIHIZUKE);
      IF BRTN THEN
        IF i_KBN = 1 THEN
            IF BPRMFLG_004 THEN
              --GKBPK00010.FYMDEDT1より取得した表示生年月日
              IRTN := GKBPK00010.FYMDEDT1(i_YMD,o_YMD,o_YMD2);
              o_YMD    := o_YMD2;
            ELSIF BPRMFLG_003 THEN
              -- 和暦で表示生年月日
              IF i_NAIYO_CD_PRM IN(11,21) THEN
                o_YMD    := o_EDIT_GYYMMDD3;
              -- 西暦で表示生年月日
              ELSIF i_NAIYO_CD_PRM IN(12,22) THEN
                o_YMD    := o_SEIREKI_YYYY || '年'||LPAD(o_MM,2)||'月'||LPAD(o_DD,2)||'日';
              END IF;
            ELSE
              -- 「平成○年○月○日」の形式で表示
              o_YMD      := o_EDIT_GYYMMDD3;
            END IF;
        END IF;
      ELSE
        o_YMD := ' ';
      END IF;
    END PROC_GET_YMD1;
    --------------------------------------------------------
    --  機能概要      : 前住所の取得
    --  パラメータ    : i_KOJIN_NO
    --  モジュール区分: 内部関数
    --  戻り値        : VZEN_JUSHO
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
    --------------------------------------------------------
    FUNCTION FUNC_GET_ZENJUSHO(i_KOJIN_NO IN NUMBER) RETURN NVARCHAR2 IS
    VZEN_JUSHO                NVARCHAR2(150);         

    NTENSHUTSU_KAKUTEI_REN    GABTJUKIIDO.TENSHUTSU_KAKUTEI_REN%TYPE;
    NTENSHUTSU_YOTEI_REN      GABTJUKIIDO.TENSHUTSU_YOTEI_REN%TYPE;
    NGENJUSHO_REN             GABTJUKIIDO.GENJUSHO_REN%TYPE;
    NZENJUSHO_REN             GABTJUKIIDO.ZENJUSHO_REN%TYPE;
    VGEN_CHOMEI               GABTJUKIJUSHO.CHOMEI%TYPE;
    VGEN_BANCHI               GABTJUKIJUSHO.BANCHI%TYPE;
    VGEN_KATAGAKI             GABTJUKIJUSHO.KATAGAKI%TYPE;
    VZEN_CHOMEI               GABTJUKIJUSHO.CHOMEI%TYPE;
    VZEN_BANCHI               GABTJUKIJUSHO.BANCHI%TYPE;
    VZEN_KATAGAKI             GABTJUKIJUSHO.KATAGAKI%TYPE;
    BEGIN
      VZEN_JUSHO := '';
      IF i_KOJIN_NO = NULL OR i_KOJIN_NO = 0 THEN
         RETURN VZEN_JUSHO;
      END IF;
      --住所連番取得
      SELECT NVL(A.TENSHUTSU_KAKUTEI_REN,0),
             NVL(A.TENSHUTSU_YOTEI_REN,0),
             NVL(A.GENJUSHO_REN,0),
             NVL(A.ZENJUSHO_REN,0),
             B.CHOMEI,
             B.BANCHI,
             B.KATAGAKI,
             C.CHOMEI,
             C.BANCHI,
             C.KATAGAKI
        INTO NTENSHUTSU_KAKUTEI_REN,
             NTENSHUTSU_YOTEI_REN,
             NGENJUSHO_REN,
             NZENJUSHO_REN,
             VGEN_CHOMEI,
             VGEN_BANCHI,
             VGEN_KATAGAKI,
             VZEN_CHOMEI,
             VZEN_BANCHI,
             VZEN_KATAGAKI
        FROM GABTJUKIIDO A,GABTJUKIJUSHO B,GABTJUKIJUSHO C
       WHERE A.KOJIN_NO     = B.KOJIN_NO(+)  and
             A.GENJUSHO_REN = B.JUSHO_REN(+) and
             A.KOJIN_NO     = C.KOJIN_NO(+)  and
             A.ZENJUSHO_REN = C.JUSHO_REN(+) and
             A.KOJIN_NO     = i_KOJIN_NO;
       --転出確定あるいは転出予定で現住所がある場合、現住所を表示
       IF (NTENSHUTSU_KAKUTEI_REN > 0 OR NTENSHUTSU_YOTEI_REN > 0) AND
           NGENJUSHO_REN > 0 THEN
           VZEN_JUSHO := GAAPK0010.FADDRESSEDIT( 1, '', VGEN_CHOMEI, VGEN_BANCHI, VGEN_KATAGAKI, '') || '（転出前）';
       --前住所を表示
       ELSIF NZENJUSHO_REN > 0 THEN
           VZEN_JUSHO := GAAPK0010.FADDRESSEDIT( 1, '', VZEN_CHOMEI, VZEN_BANCHI, VZEN_KATAGAKI, '')  || '（転居前）';
       END IF;
      RETURN VZEN_JUSHO;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN VZEN_JUSHO;
    END FUNC_GET_ZENJUSHO;
    --------------------------------------------------------
    --  機能概要      : 氏名印字制御ﾊﾟﾗﾒｰﾀの設定の編集
    --  パラメータ    : NSEIGYO_IN_FLG 制御ﾊﾟﾗﾒｰﾀ
    --               NKANRI_FLG   
    --               VSHIMEI_DATA
    --               VHONMYO_DATA
    --  モジュール区分: 内部関数
    --  戻り値        : 1 本名　３　管理模型で編集（氏名かな/氏名漢字） ２　管理模型で編集（本名かな/本名漢字）
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
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
           VRETURN := VSHIMEI_DATA ;
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
    -- 2024/06/27 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------------------------------
    --  機能概要      : 支援措置対象者情報
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.wangqiwei 2024/06/27
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GACTKANRI_WK(v_KOJIN_NO IN NVARCHAR2) RETURN NUMBER IS
        sVSQL               NVARCHAR2(10000);           -- ＳＱＬ文
        GACTKANRI           TYPECURSOR;                 -- カーソル定義
        nJYOUKEN            PLS_INTEGER;                -- システム日付
    BEGIN
        nJYOUKEN := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
        --ＳＱＬ文
        sVSQL := '';
        sVSQL := sVSQL || ' SELECT';
        sVSQL := sVSQL || '          SONOTAGYOMU.TOROKU_GYOMU                                     ';
        sVSQL := sVSQL || '        , SONOTAGYOMU.SHIENSOCHIKBN                                    ';
        sVSQL := sVSQL || '        , SONOTAGYOMU.SHIENSOCHISHURYOKBN                              ';
        sVSQL := sVSQL || '        , SONOTAGYOMU.SHIENSOCHIKAISHIBI                               ';
        sVSQL := sVSQL || '        , SONOTAGYOMU.SHIENSOCHISHURYOBI                               ';
        sVSQL := sVSQL || '        , NULL AS  TAISHOSHAKBN                                        ';
        sVSQL := sVSQL || '        , NULL AS  KARISHIENSOCHIKAISHIBI                              ';
        sVSQL := sVSQL || '        , NULL AS  KARISHIENSOCHISHURYOBI                              ';
        sVSQL := sVSQL || '        , NULL AS  SHIENSOCHIKAIJOBI                                   ';
        sVSQL := sVSQL || ' FROM                                                                  ';
        sVSQL := sVSQL || '      GACTKANRI_SONOTAGYOMU SONOTAGYOMU                                ';
        sVSQL := sVSQL || ' WHERE                                                                 ';
        sVSQL := sVSQL || '         SONOTAGYOMU.TOROKU_GYOMU        = ''GKB''                     ';
        sVSQL := sVSQL || '     AND SONOTAGYOMU.KOJIN_NO            = '|| v_KOJIN_NO ||'          ';
-- 2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応     
        --sVSQL := sVSQL || '     AND SONOTAGYOMU.SHIENSOCHIKBN       IN (1, 2)                     ';
        sVSQL := sVSQL || '     AND SONOTAGYOMU.SHIENSOCHIKBN       IN (1,2,4)                     ';        
        --sVSQL := sVSQL || '     AND SONOTAGYOMU.SHIENSOCHISHURYOKBN <> 3                          ';    
        sVSQL := sVSQL || '     AND NVL(SONOTAGYOMU.SHIENSOCHISHURYOKBN, 0) <> 3                  ';
-- 2025/06/04 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
        sVSQL := sVSQL || '     AND SONOTAGYOMU.RIREKI_NO           =                             ';
        sVSQL := sVSQL || '     (SELECT MAX(RIREKI_NO) FROM GACTKANRI_SONOTAGYOMU                 ';
        sVSQL := sVSQL || '                           WHERE TOROKU_GYOMU = ''GKB''                ';
        sVSQL := sVSQL || '                             AND KOJIN_NO     = '|| v_KOJIN_NO ||' )   ';
        sVSQL := sVSQL || ' UNION ALL                                                             ';
        sVSQL := sVSQL || ' SELECT                                                                ';
        sVSQL := sVSQL || '       NULL AS TOROKU_GYOMU,                                           ';
        sVSQL := sVSQL || '       NULL AS SHIENSOCHIKBN,                                          ';
        sVSQL := sVSQL || '       NULL AS SHIENSOCHISHURYOKBN,                                    ';
        sVSQL := sVSQL || '       MOUSHID.SHIENSOCHIKAISHIBI,                                     ';
        sVSQL := sVSQL || '       MOUSHID.SHIENSOCHISHURYOBI,                                     ';
        sVSQL := sVSQL || '       MOUSHID.TAISHOSHAKBN,                                           ';
        sVSQL := sVSQL || '       MOUSHID.KARISHIENSOCHIKAISHIBI,                                 ';
        sVSQL := sVSQL || '       MOUSHID.KARISHIENSOCHISHURYOBI,                                 ';
        sVSQL := sVSQL || '       MOUSHID.SHIENSOCHIKAIJOBI                                       ';
        sVSQL := sVSQL || ' FROM                                                                  ';
        sVSQL := sVSQL || '       GACTKANRI_MOUSHIDE  MOUSHID                                     ';
        sVSQL := sVSQL || ' WHERE                                                                 ';
        sVSQL := sVSQL || '      MOUSHID.KOJIN_NO IN (                                            ';
        sVSQL := sVSQL || '         SELECT                                                        ';
        sVSQL := sVSQL || '             KOJIN_NO                                                  ';
        sVSQL := sVSQL || '         FROM                                                          ';
        sVSQL := sVSQL || '             GACTKANRI_MOUSHIDE                                        ';
        sVSQL := sVSQL || '         WHERE  '|| v_KOJIN_NO ||' = TAISHO_ATENA_NO                   ';
        sVSQL := sVSQL || '                  AND TAISHOSHAKBN = 1                                 ';
        sVSQL := sVSQL || '         UNION ALL                                                     ';
        sVSQL := sVSQL || '         SELECT                                                        ';
        sVSQL := sVSQL || '             KOJIN_NO                                                  ';
        sVSQL := sVSQL || '         FROM                                                          ';
        sVSQL := sVSQL || '             GACTKANRI_MOUSHIDE                                        ';
        sVSQL := sVSQL || '         WHERE  '|| v_KOJIN_NO ||' = KOJIN_NO                          ';
        sVSQL := sVSQL || '                  AND TAISHOSHAKBN = 0                                 ';
        sVSQL := sVSQL || '     )                                                                 ';
        sVSQL := sVSQL || '     AND MOUSHID.TAISHOSHAKBN = 0                                      ';
        sVSQL := sVSQL || '     AND                                                               ';
        sVSQL := sVSQL || '        MOUSHID.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) FROM GACTKANRI_MOUSHIDE                    ';
        sVSQL := sVSQL || '                                  WHERE  KOJIN_NO    = '|| v_KOJIN_NO ||'                             ';
        sVSQL := sVSQL || '                                    AND TAISHOSHAKBN = 0 )                                            ';
        sVSQL := sVSQL || '     AND                                                                                              ';
        sVSQL := sVSQL || '     (                                                                                                ';
        sVSQL := sVSQL || '       (MOUSHID.SHIENSOCHIKAISHIBI <= TO_NUMBER(TO_CHAR(SYSDATE, '' YYYYMMDD '')))                    ';
        sVSQL := sVSQL || '        AND ((                                                                                        ';
        sVSQL := sVSQL || '        CASE WHEN MOUSHID.SHIENSOCHIKAIJOBI IS NOT NULL                                               ';
        sVSQL := sVSQL || '        THEN MOUSHID.SHIENSOCHIKAIJOBI END >= ' || nJYOUKEN || ')                                     ';
        sVSQL := sVSQL || '        OR (                                                                                          ';
        sVSQL := sVSQL || '        CASE WHEN MOUSHID.SHIENSOCHIKAIJOBI IS NULL                                                   ';
        sVSQL := sVSQL || '        THEN NVL(MOUSHID.SHIENSOCHISHURYOBI, 99999999) END >= ' || nJYOUKEN || ' ))                   ';
        sVSQL := sVSQL || '     )                                                                                                ';
        sVSQL := sVSQL || '     OR                                                                                               ';
        sVSQL := sVSQL || '     (                                                                                                ';
        sVSQL := sVSQL || '       (MOUSHID.KARISHIENSOCHIKAISHIBI <= TO_NUMBER(TO_CHAR(SYSDATE, '' YYYYMMDD '')))                ';
        sVSQL := sVSQL || '        AND ((                                                                                        ';
        sVSQL := sVSQL || '        CASE WHEN MOUSHID.SHIENSOCHIKAIJOBI IS NOT NULL                                               ';
        sVSQL := sVSQL || '        THEN MOUSHID.SHIENSOCHIKAIJOBI END >= ' || nJYOUKEN ||' )                                     ';
        sVSQL := sVSQL || '        OR (                                                                                          ';
        sVSQL := sVSQL || '        CASE WHEN MOUSHID.SHIENSOCHIKAIJOBI IS NULL                                                   ';
        sVSQL := sVSQL || '        THEN NVL(MOUSHID.KARISHIENSOCHISHURYOBI, 99999999)  END >= ' || nJYOUKEN || ' ))              ';
        sVSQL := sVSQL || '     )                                                                                                ';
        OPEN GACTKANRI FOR sVSQL;
        v_TOROKU_GYOMU := A_CONS_PRM();
        v_SHIENSOCHIKBN := A_CONS_PRM();
        v_SHIENSOCHISHURYOKBN := A_CONS_PRM();
        v_SHIENSOCHIKAISHIBI := A_CONS_PRM();
        v_SHIENSOCHISHURYOBI := A_CONS_PRM();
        v_TAISHOSHAKBN := A_CONS_PRM();
        v_KARISHIENSOCHIKAISHIBI := A_CONS_PRM();
        v_KARISHIENSOCHISHURYOBI := A_CONS_PRM();
        v_SHIENSOCHIKAIJOBI := A_CONS_PRM();
        LOOP
            FETCH GACTKANRI INTO GACTKANRIS_REC;
            EXIT WHEN GACTKANRI%NOTFOUND;
            ICNT := ICNT + 1;
            v_TOROKU_GYOMU.EXTEND;
            v_SHIENSOCHIKBN.EXTEND;
            v_SHIENSOCHISHURYOKBN.EXTEND;
            v_SHIENSOCHIKAISHIBI.EXTEND;
            v_SHIENSOCHISHURYOBI.EXTEND;
            v_TAISHOSHAKBN.EXTEND;
            v_KARISHIENSOCHIKAISHIBI.EXTEND;
            v_KARISHIENSOCHISHURYOBI.EXTEND;
            v_SHIENSOCHIKAIJOBI.EXTEND;
            v_TOROKU_GYOMU(ICNT)             := GACTKANRIS_REC.TOROKU_GYOMU          ;       --支援措置申出者管理_その他業務.登録業務
            v_SHIENSOCHIKBN(ICNT)            := GACTKANRIS_REC.SHIENSOCHIKBN         ;       --支援措置申出者管理_その他業務.支援措置区分
            v_SHIENSOCHISHURYOKBN(ICNT)      := GACTKANRIS_REC.SHIENSOCHISHURYOKBN   ;       --支援措置申出者管理_その他業務.支援措置終了区分
            v_SHIENSOCHIKAISHIBI(ICNT)       := GACTKANRIS_REC.SHIENSOCHIKAISHIBI    ;       --支援措置申出者管理_その他業務.支援措置開始年月日/支援措置申出者管理_申出者情報.支援措置開始年月日
            v_SHIENSOCHISHURYOBI(ICNT)       := GACTKANRIS_REC.SHIENSOCHISHURYOBI    ;       --支援措置申出者管理_その他業務.支援措置終了年月日/支援措置申出者管理_申出者情報.支援措置終了年月日
            v_TAISHOSHAKBN(ICNT)             := GACTKANRIS_REC.TAISHOSHAKBN          ;       --支援措置申出者管理_申出者情報.支援措置対象者区分
            v_KARISHIENSOCHIKAISHIBI(ICNT)   := GACTKANRIS_REC.KARISHIENSOCHIKAISHIBI;       --支援措置申出者管理_申出者情報.仮支援措置開始年月日
            v_KARISHIENSOCHISHURYOBI(ICNT)   := GACTKANRIS_REC.KARISHIENSOCHISHURYOBI;       --支援措置申出者管理_申出者情報.仮支援措置終了年月日
            v_SHIENSOCHIKAIJOBI(ICNT)        := GACTKANRIS_REC.SHIENSOCHIKAIJOBI     ;       --支援措置申出者管理_申出者情報.措置解除日
        END LOOP;
        CLOSE GACTKANRI;
        -- 終了
        RETURN c_ISUCCESS;                      -- 正常終了
    EXCEPTION
      WHEN OTHERS THEN
        IF GACTKANRI%ISOPEN THEN
          CLOSE GACTKANRI;
        END IF;
        RETURN c_INOT_SUCCESS;
    END FUNC_GACTKANRI_WK;
-- 2024/06/04 ZCZL.wangqiwei Add end
    --------------------------------------------------------
    --------------------------------------------------------
    --  機能概要      : レコードの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,その他 -1
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
    --------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC RETURN NUMBER IS
        -- カーソル定義
        RECGAKUREIBO         GAKUREIBO%ROWTYPE;
        -- ループ用
        IDX                  PLS_INTEGER;
        -- 戻り値
        IFRET                PLS_INTEGER;
        -- 児童住所
        JIDO_JUSHO           NVARCHAR2(150);         
        -- 保護者住所
        HOGO_JUSHO           NVARCHAR2(150);         
        -- 続柄取得用
        ZOKUGARA_IN          NVARCHAR2(20);
        -- 続柄フラグ
        ZOKUGARA_FLAG        BOOLEAN;
        -- 続柄
        ZOKUGARA             NVARCHAR2(20);
        -- 児童生年月日
        JIDO_BTH_IN          PLS_INTEGER;
        -- 小学校入学日
        SYO_NYUGAKU_IN       PLS_INTEGER;
        -- 小学校転入学日
        SYO_TENNYUGAKU_IN    PLS_INTEGER;  
        -- 小学校転学日
        SYO_TENGAKU_IN       PLS_INTEGER;
        -- 小学校卒業日
        SYO_SOTUGYO_IN       PLS_INTEGER;
        -- 中学校入学日
        TYU_NYUGAKU_IN       PLS_INTEGER;
        -- 中学校転入学日
        TYU_TENNYUGAKU_IN    PLS_INTEGER;  
        -- 中学校転学日
        TYU_TENGAKU_IN       PLS_INTEGER;
        -- 中学校卒業日
        TYU_SOTUGYO_IN       PLS_INTEGER;
        -- 区域外学校入学日
        GAI_NYUGAKU_IN       PLS_INTEGER;
        -- 区域外学校転入学日
        GAI_TENNYUGAKU_IN    PLS_INTEGER;  
        -- 区域外学校転退学日
        GAI_TENTAI_IN        PLS_INTEGER;
        -- 区域外学校転学日
        GAI_TENGAKU_IN       PLS_INTEGER;  
        -- 区域外学校退学日
        GAI_TAIGAKU_IN       PLS_INTEGER;  
        -- 区域外学校卒業日
        GAI_SOTUGYO_IN       PLS_INTEGER;
        -- 養護学校入学日
        YOG_NYUGAKU_IN       PLS_INTEGER;
        -- 養護学校転入学日
        YOG_TENNYUGAKU_IN    PLS_INTEGER;  
        -- 養護学校転退学日
        YOG_TENTAI_IN        PLS_INTEGER;
        -- 養護学校転学日
        YOG_TENGAKU_IN       PLS_INTEGER;  
        -- 養護学校退学日
        YOG_TAIGAKU_IN       PLS_INTEGER;  
        -- 養護学校卒業日
        YOG_SOTUGYO_IN       PLS_INTEGER;
        -- 猶予許可日
        YUYO_KYOKA_IN        PLS_INTEGER;
        -- 猶予開始日
        YUYO_KAISI_IN        PLS_INTEGER;
        -- 猶予終了日
        YUYO_SYURYO_IN       PLS_INTEGER;
        -- 猶予復学日
        YUYO_FUKUGAKU_IN     PLS_INTEGER;
        -- 免除許可日
        MENJO_KYOKA_IN       PLS_INTEGER;
        -- 免除復学日
        MENJO_FUKUGAKU_IN    PLS_INTEGER;
        -- 督促年月日１
        TOKUSOKU_BI1_IN      PLS_INTEGER;
        -- 督促年月日２
        TOKUSOKU_BI2_IN      PLS_INTEGER;
        -- 督促年月日３
        TOKUSOKU_BI3_IN      PLS_INTEGER;
        -- 督促年月日４
        TOKUSOKU_BI4_IN      PLS_INTEGER;
        -- 督促年月日５
        TOKUSOKU_BI5_IN      PLS_INTEGER;
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応   STR    
          -- 督促年月日6
        TOKUSOKU_BI6_IN      PLS_INTEGER;
          -- 督促年月日7
        TOKUSOKU_BI7_IN      PLS_INTEGER;
          -- 督促年月日8
        TOKUSOKU_BI8_IN      PLS_INTEGER;
          -- 督促年月日9
        TOKUSOKU_BI9_IN      PLS_INTEGER;
          -- 督促年月日10
        TOKUSOKU_BI10_IN     PLS_INTEGER;
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応   END     
        -- 異動年月日１
        IDO_BI1_IN           PLS_INTEGER;
        -- 異動年月日１
        IDO_BI2_IN           PLS_INTEGER;
        -- 異動年月日１
        IDO_BI3_IN           PLS_INTEGER;
        -- 異動年月日１
        IDO_BI4_IN           PLS_INTEGER;
        -- 異動年月日１
        IDO_BI5_IN           PLS_INTEGER;
        -- 異動年月日１
        IDO_BI6_IN           PLS_INTEGER;
        -- 異動年月日１
        IDO_BI7_IN           PLS_INTEGER;
        -- 異動年月日１
        IDO_BI8_IN           PLS_INTEGER;
        -- 異動年月日１
        IDO_BI9_IN           PLS_INTEGER;
        -- 異動年月日１
        IDO_BI10_IN          PLS_INTEGER;
        -- 出力用児童生年月日
        JIDO_BTH_OUT         NVARCHAR2(11);
        -- 出力用小学校入学日
        SYO_NYUGAKU_OUT       NVARCHAR2(11);
        -- 出力用小学校転入学日
        SYO_TENNYUGAKU_OUT    NVARCHAR2(11);  
        -- 出力用小学校転学日
        SYO_TENGAKU_OUT       NVARCHAR2(11);
        -- 出力用小学校卒業日
        SYO_SOTUGYO_OUT       NVARCHAR2(11);
        -- 出力用中学校入学日
        TYU_NYUGAKU_OUT       NVARCHAR2(11);
        -- 出力用中学校転入学日
        TYU_TENNYUGAKU_OUT    NVARCHAR2(11);  
        -- 出力用中学校転学日
        TYU_TENGAKU_OUT       NVARCHAR2(11);
        -- 出力用中学校卒業日
        TYU_SOTUGYO_OUT       NVARCHAR2(11);
        -- 出力用区域外学校入学日
        GAI_NYUGAKU_OUT       NVARCHAR2(11);
        -- 出力用区域外学校転入学日
        GAI_TENNYUGAKU_OUT    NVARCHAR2(11); 
        -- 出力用区域外学校転退学日
        GAI_TENTAI_OUT        NVARCHAR2(11);
        -- 出力用区域外学校転学日
        GAI_TENGAKU_OUT       NVARCHAR2(11);  
        -- 出力用区域外学校退学日
        GAI_TAIGAKU_OUT       NVARCHAR2(11);  
        -- 出力用 区域外学校卒業日
        GAI_SOTUGYO_OUT       NVARCHAR2(11);
        -- 出力用養護学校入学日
        YOG_NYUGAKU_OUT       NVARCHAR2(11);
        -- 出力用養護学校転入学日
        YOG_TENNYUGAKU_OUT    NVARCHAR2(11);  
        -- 出力用養護学校転退学日
        YOG_TENTAI_OUT        NVARCHAR2(11);
        -- 出力用養護学校転学日
        YOG_TENGAKU_OUT       NVARCHAR2(11);  
        -- 出力用養護学校退学日
        YOG_TAIGAKU_OUT       NVARCHAR2(11);  
        -- 出力用養護学校卒業日
        YOG_SOTUGYO_OUT       NVARCHAR2(11);
        -- 出力用猶予許可日
        YUYO_KYOKA_OUT        NVARCHAR2(11);
        -- 出力用猶予開始日
        YUYO_KAISI_OUT        NVARCHAR2(11);
        -- 出力用猶予終了日
        YUYO_SYURYO_OUT       NVARCHAR2(11);
        -- 出力用猶予復学日
        YUYO_FUKUGAKU_OUT     NVARCHAR2(11);
        -- 出力用免除許可日
        MENJO_KYOKA_OUT       NVARCHAR2(11);
        -- 出力用免除復学日
        MENJO_FUKUGAKU_OUT    NVARCHAR2(11);
        -- 出力用督促年月日１
        TOKUSOKU_BI1_OUT      NVARCHAR2(11);
        -- 出力用督促年月日２
        TOKUSOKU_BI2_OUT      NVARCHAR2(11);
        -- 出力用督促年月日３
        TOKUSOKU_BI3_OUT      NVARCHAR2(11);
        -- 出力用督促年月日４
        TOKUSOKU_BI4_OUT      NVARCHAR2(11);
        -- 出力用督促年月日５
        TOKUSOKU_BI5_OUT      NVARCHAR2(11);
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応  STR      
          -- 出力用督促年月日6
        TOKUSOKU_BI6_OUT      NVARCHAR2(11);
         -- 出力用督促年月日7
        TOKUSOKU_BI7_OUT      NVARCHAR2(11);
         -- 出力用督促年月日8
        TOKUSOKU_BI8_OUT      NVARCHAR2(11);
         -- 出力用督促年月日9
        TOKUSOKU_BI9_OUT      NVARCHAR2(11);
         -- 出力用督促年月日10
        TOKUSOKU_BI10_OUT      NVARCHAR2(11);
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 END       
        -- 出力用異動年月日１
        IDO_BI1_OUT           NVARCHAR2(11);
        -- 出力用異動年月日２
        IDO_BI2_OUT           NVARCHAR2(11);
        -- 出力用異動年月日３
        IDO_BI3_OUT           NVARCHAR2(11);
        -- 出力用異動年月日４
        IDO_BI4_OUT           NVARCHAR2(11);
        -- 出力用異動年月日５
        IDO_BI5_OUT           NVARCHAR2(11);
        -- 出力用異動年月日６
        IDO_BI6_OUT           NVARCHAR2(11);
        -- 出力用異動年月日７
        IDO_BI7_OUT           NVARCHAR2(11);
        -- 出力用異動年月日８
        IDO_BI8_OUT           NVARCHAR2(11);
        -- 出力用異動年月日９
        IDO_BI9_OUT           NVARCHAR2(11);
        -- 出力用異動年月日１０
        IDO_BI10_OUT          NVARCHAR2(11);
        IRTN            PLS_INTEGER;
        IRTN_SIMEI      PLS_INTEGER;
        IRTN_KYOUIKU    PLS_INTEGER;
        o_ACONSPRM       A_CONS_PRM;
        ACONSPRM_SIMEI   A_CONS_PRM;
        ACONSPRM_KYOUIKU A_CONS_PRM;
        o_LENGTH        NUMBER;
        GAKKOUMEI       NVARCHAR2(60);                -- 学校名
        RA1             GABTATENAKIHON%ROWTYPE;
        RA2             GABTSOFUSAKI%ROWTYPE;
        HONMYO_KANA     NVARCHAR2(100);                -- 外国人児童本名かな
        HONMYO_KANJI    NVARCHAR2(100);                -- 外国人児童本名漢字
        HOGOSYA_HONMYO_KANA    NVARCHAR2(100);         -- 外国人保護者本名かな
        HOGOSYA_HONMYO_KANJI   NVARCHAR2(100);         -- 外国人保護者本名漢字
        o_VZOKUGARAMEI NVARCHAR2(100);
        o_IHERR        PLS_INTEGER;
        VHOGOSHA_YUBIN_NO NVARCHAR2(20);              -- 教育委員会郵便番号
        N_NAIYO_CD_JIDO             GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;
        VEDIT_GO_DATA               NVARCHAR2(1000) := '';
        nROWNUM        NUMBER;
        rRECODE        GKBWL050R001%ROWTYPE;
-- 2024/06/26 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
        o_tITEM       A_CONS_PRM;
        o_sSHIMEIKANA NVARCHAR2(100);
        o_sSHIMEI     NVARCHAR2(100);
        o_sBIRTHDAY   NVARCHAR2(100);
        nPRMCTL       PLS_INTEGER;
        FLG                     NUMBER := 1;
        TOKUSOKU_BIS            A_CONS_PRM;
        TOKUSOKU_NAIYOS         A_CONS_PRM;
        TOKUSOKU_BI             A_CONS_PRM;          --督促年月日
        TOKUSOKU_NAIYO          A_CONS_PRM;          --督促内容
        INDX                    NUMBER := 1;
        N                       NUMBER := 1;
        o_sWAREKIDATE           NVARCHAR2(100);
        nGAITO_KARA             NUMBER;                     --支援措置開始年月日
        nGAITO_MADE             NUMBER;                     --支援措置終了年月日
        rGABTATENAKIHON         GABTATENAKIHON%ROWTYPE;     --宛名基本情報
        rGABTSOFUSAKI           GABTSOFUSAKI%ROWTYPE;       --送付先基本情報
        nKOJINSETAIKBN          NUMBER;                     --個人世帯区分（0：個人、1：世帯）
        nYOKUSHIKBN             NUMBER;                     --抑止区分（1：支援措置、2：仮支援措置、4：その他抑止）
        nIDOYOKUSHIKBN          NUMBER;                     --異動抑止区分（0：非該当、1：警告、2：論理）
        nHAKKOYOKUSHIKBN        NUMBER;                     --発行抑止区分（0：非該当、1：警告、2：論理）
        nSHOKAIYOKUSHIKBN       NUMBER;                     --照会抑止区分（0：非該当、1：警告、2：論理）
        vSHORICHUIKBN           NVARCHAR2(1000);            --処理注意区分（任意設定）

-- 2024/06/26 ZCZL.wangqiwei Add end
    BEGIN
        -- 正常終了
        IFRET := c_ISUCCESS;
        nROWNUM := 0;
        BEGIN
          -- 市町村名の取得
          ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
--  2025/11/20 CTC.GL UPDATE START 1.0.302.000:GKB_QA23586、QA21478対応
          OPEN CUR_GAKUNEN(g_sKojinNo, g_sRirekiRenban);
          FETCH CUR_GAKUNEN INTO g_sGakunen;
          CLOSE CUR_GAKUNEN;

          -- カーソルのオープン
--          OPEN GAKUREIBO(g_sKojinNo, g_sRirekiRenban);
          OPEN GAKUREIBO(g_sKojinNo, g_sRirekiRenban,g_sGakunen);
--  2025/11/20 CTC.GL UPDATE END
          -- レコード参照
          FETCH GAKUREIBO INTO RECGAKUREIBO;
          -- ループ開始
          LOOP
            -- 読むレコードが無い場合ループから抜け出す
            EXIT WHEN GAKUREIBO%NOTFOUND;
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
            --nROWNUM := nROWNUM + 1;
            -- 続柄フラグの初期化
            ZOKUGARA_FLAG := TRUE;
            -- 続柄の初期化
            ZOKUGARA := '';
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START
            ZOKUGARA := GKBFKZKGMGET(2, RECGAKUREIBO.HOGOSYA_ZOKUGARA1, RECGAKUREIBO.HOGOSYA_ZOKUGARA2, RECGAKUREIBO.HOGOSYA_ZOKUGARA3, RECGAKUREIBO.HOGOSYA_ZOKUGARA4, o_VZOKUGARAMEI, o_IHERR);
            ZOKUGARA :=  o_VZOKUGARAMEI; 
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END            
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START
            /*
            -- ４回ループする
            FOR IDX IN 1..4 LOOP
              -- ループ変数による分岐
-- 2024/06/26 ZCZL.wangqiwei Update Start 0.3.000.000:新WizLIFE2次開発の標準化対応
--               CASE IDX
--                --続柄１
--                 WHEN 1 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI1;
--                --続柄２
--                 WHEN 2 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI2;
--                --続柄３
--                 WHEN 3 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI3;
--                --続柄４
--                 WHEN 4 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI4;
--               END CASE;
               CASE IDX
                --続柄１
                 WHEN 1 THEN ZOKUGARA_IN := RECGAKUREIBO.HOGOSYA_ZOKUGARA1;
                --続柄２
                 WHEN 2 THEN ZOKUGARA_IN := RECGAKUREIBO.HOGOSYA_ZOKUGARA2;
                --続柄３
                 WHEN 3 THEN ZOKUGARA_IN := RECGAKUREIBO.HOGOSYA_ZOKUGARA3;
                --続柄４
                 WHEN 4 THEN ZOKUGARA_IN := RECGAKUREIBO.HOGOSYA_ZOKUGARA4;
               END CASE;
-- 2024/06/26 ZCZL.wangqiwei Update Start End
              -- 取得した続柄が存在する場合
              IF ZOKUGARA_IN <> ' ' THEN
                -- 続柄が設定されていない場合
                IF ZOKUGARA_FLAG = TRUE THEN
                  -- 続柄フラグを設定
                  ZOKUGARA_FLAG := FALSE;
                  -- 続柄を設定
                  ZOKUGARA := ZOKUGARA_IN;
                  IRTN := GKBFKZKGMGET(2, ZOKUGARA_IN, ZOKUGARA_IN, ZOKUGARA_IN, ZOKUGARA_IN, o_VZOKUGARAMEI, o_IHERR);
                  IF IRTN = 0 THEN
                     ZOKUGARA :=  o_VZOKUGARAMEI;                                                                                      
                  END IF;
                -- 続柄が設定されている場合
                ELSE
                  -- 続柄を付与する
                  IRTN := GKBFKZKGMGET(2, ZOKUGARA_IN, ZOKUGARA_IN, ZOKUGARA_IN, ZOKUGARA_IN, o_VZOKUGARAMEI, o_IHERR);
                  IF IRTN = 0 THEN
                    ZOKUGARA :=  o_VZOKUGARAMEI;                                                                                      
                  END IF;
                  ZOKUGARA := ZOKUGARA;
                  --ZOKUGARA := ZOKUGARA || 'の' || ZOKUGARA_IN;
                END IF;
              END IF;
            END LOOP;
            */
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END
            -- 学校区コードの判定
            IF RECGAKUREIBO.SYOGAKO_CD <> 0 AND
               RECGAKUREIBO.SYOGAKO_TENGAKU_BI = 0 AND
               RECGAKUREIBO.SYOGAKO_SOTSUGYO_BI = 0 THEN
               IGAKO_CD := RECGAKUREIBO.SYOGAKO_CD;
               GAKKOUMEI := RECGAKUREIBO.SYOGAKOMEI;
            ELSE
               IF RECGAKUREIBO.TYUGAKO_CD <> 0 AND
                  RECGAKUREIBO.TYUGAKO_TENGAKU_BI = 0 AND
                  RECGAKUREIBO.TYUGAKO_SOTSUGYO_BI = 0 THEN
                  IGAKO_CD := RECGAKUREIBO.TYUGAKO_CD;
                  GAKKOUMEI := RECGAKUREIBO.TYUGAKOMEI;
               ELSE
                  IF RECGAKUREIBO.KUIKIGAI_CD <> 0 AND
                     RECGAKUREIBO.KUIKIGAI_TENGAKU_BI = 0 AND
                     RECGAKUREIBO.KUIKIGAI_TAIGAKU_BI = 0 AND
                     RECGAKUREIBO.KUIKIGAI_SOTSUGYO_BI = 0 THEN
                     IGAKO_CD := RECGAKUREIBO.KUIKIGAI_CD;
                     GAKKOUMEI := RECGAKUREIBO.KUIKIGAIMEI;
                  ELSE
                     IF RECGAKUREIBO.YOGOGAKO_CD <> 0 AND
                        RECGAKUREIBO.YOGOGAKO_TENGAKU_BI = 0 AND
                        RECGAKUREIBO.YOGOGAKO_TAIGAKU_BI = 0 AND
                        RECGAKUREIBO.YOGOGAKO_SOTSUGYO_BI = 0 THEN
                        IGAKO_CD := RECGAKUREIBO.YOGOGAKO_CD;
                        GAKKOUMEI := RECGAKUREIBO.YOGOGAKOMEI;
                     ELSE
                        IGAKO_CD := 0;
                        GAKKOUMEI := ' ';
                     END IF;
                  END IF;
               END IF;
            END IF;
            -- 児童住所
            JIDO_JUSHO := '';
-- 2024/07/02 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--             JIDO_JUSHO := GAAPK0010.FADDRESSEDIT( 1, '',  RECGAKUREIBO.CHOMEI, RECGAKUREIBO.BANCHI, RECGAKUREIBO.KATAGAKI,  '');
            JIDO_JUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  RECGAKUREIBO.CHOMEI, RECGAKUREIBO.BANCHI, RECGAKUREIBO.KATAGAKI, NULL);
            -- 保護者住所
            HOGO_JUSHO := '';
            HOGO_JUSHO := GAAPK0010.FADDRESSEDIT( 1, '',  RECGAKUREIBO.HOGOSYA_CHOMEI, RECGAKUREIBO.HOGOSYA_BANCHI, RECGAKUREIBO.HOGOSYA_KATAGAKI, '');
            -- 児童生年月日の取得
            JIDO_BTH_IN := RECGAKUREIBO.SEINENGAPI;
            -- 小学校入学日
            SYO_NYUGAKU_IN := RECGAKUREIBO.SYOGAKO_NYUGAKU_BI;
            -- 小学校転入学日
            SYO_TENNYUGAKU_IN := RECGAKUREIBO.SYOGAKO_TENNYUGAKU_BI;  
            -- 小学校転学日
            SYO_TENGAKU_IN := RECGAKUREIBO.SYOGAKO_TENGAKU_BI;
            -- 小学校卒業日
            SYO_SOTUGYO_IN := RECGAKUREIBO.SYOGAKO_SOTSUGYO_BI;
            -- 中学校入学日
            TYU_NYUGAKU_IN := RECGAKUREIBO.TYUGAKO_NYUGAKU_BI;
            -- 中学校転入学日
            TYU_TENNYUGAKU_IN := RECGAKUREIBO.TYUGAKO_TENNYUGAKU_BI;  
            -- 中学校転学日
            TYU_TENGAKU_IN := RECGAKUREIBO.TYUGAKO_TENGAKU_BI;
            -- 中学校卒業日
            TYU_SOTUGYO_IN := RECGAKUREIBO.TYUGAKO_SOTSUGYO_BI;
            -- 区域外学校入学日
            GAI_NYUGAKU_IN := RECGAKUREIBO.KUIKIGAI_NYUGAKU_BI;
            -- 区域外学校転入学日
            GAI_TENNYUGAKU_IN := RECGAKUREIBO.KUIKIGAI_TENNYUGAKU_BI;  
            -- 区域外学校転退学日
            GAI_TENTAI_IN := RECGAKUREIBO.KUIKIGAI_TENTAIGAKU_BI;
            -- 区域外学校転学日
            GAI_TENGAKU_IN := RECGAKUREIBO.KUIKIGAI_TENGAKU_BI;
            -- 区域外学校退学日
            GAI_TAIGAKU_IN := RECGAKUREIBO.KUIKIGAI_TAIGAKU_BI;
            -- 区域外学校卒業日
            GAI_SOTUGYO_IN := RECGAKUREIBO.KUIKIGAI_SOTSUGYO_BI;
            -- 養護学校入学日
            YOG_NYUGAKU_IN := RECGAKUREIBO.YOGOGAKO_NYUGAKU_BI;
            -- 養護学校転入学日
            YOG_TENNYUGAKU_IN := RECGAKUREIBO.YOGOGAKO_TENNYUGAKU_BI;  
            -- 養護学校転退学日
            YOG_TENTAI_IN := RECGAKUREIBO.YOGOGAKO_TENTAIGAKU_BI;
            -- 養護学校転学日
            YOG_TENGAKU_IN := RECGAKUREIBO.YOGOGAKO_TENGAKU_BI;
            -- 養護学校退学日
            YOG_TAIGAKU_IN := RECGAKUREIBO.YOGOGAKO_TAIGAKU_BI;
            -- 養護学校卒業日
            YOG_SOTUGYO_IN := RECGAKUREIBO.YOGOGAKO_SOTSUGYO_BI;
            -- 猶予許可日
            YUYO_KYOKA_IN := RECGAKUREIBO.YUYO_KYOKA_BI;
            -- 猶予開始日
            YUYO_KAISI_IN := RECGAKUREIBO.YUYO_KAISI_BI;
            -- 猶予終了日
            YUYO_SYURYO_IN := RECGAKUREIBO.YUYO_SYURYO_BI;
            -- 猶予復学日
            YUYO_FUKUGAKU_IN := RECGAKUREIBO.YUYO_FUKUGAKU_BI;
            -- 免除許可日
            MENJO_KYOKA_IN := RECGAKUREIBO.MENJO_KYOKA_BI;
            -- 免除復学日
            MENJO_FUKUGAKU_IN := RECGAKUREIBO.MENJO_FUKUGAKU_BI;
            -- 督促年月日１
            TOKUSOKU_BI1_IN := RECGAKUREIBO.TOKUSOKU_BI1;
            -- 督促年月日２
            TOKUSOKU_BI2_IN := RECGAKUREIBO.TOKUSOKU_BI2;
            -- 督促年月日３
            TOKUSOKU_BI3_IN := RECGAKUREIBO.TOKUSOKU_BI3;
            -- 督促年月日４
            TOKUSOKU_BI4_IN := RECGAKUREIBO.TOKUSOKU_BI4;
            -- 督促年月日５
            TOKUSOKU_BI5_IN := RECGAKUREIBO.TOKUSOKU_BI5;
-- 2024/07/02 ZCZL.wangqiwei Delete Start 0.3.000.000:新WizLIFE2次開発の標準化対応
--            -- 異動年月日１
--             IDO_BI1_IN := RECGAKUREIBO.IDO_BI1;
--            -- 異動年月日２
--             IDO_BI2_IN := RECGAKUREIBO.IDO_BI2;
--            --異動年月日３
--             IDO_BI3_IN := RECGAKUREIBO.IDO_BI3;
--            --異動年月日４
--             IDO_BI4_IN := RECGAKUREIBO.IDO_BI4;
--            --異動年月日５
--             IDO_BI5_IN := RECGAKUREIBO.IDO_BI5;
--            --異動年月日６
--             IDO_BI6_IN := RECGAKUREIBO.IDO_BI6;
--            --異動年月日７
--             IDO_BI7_IN := RECGAKUREIBO.IDO_BI7;
--            --異動年月日８
--             IDO_BI8_IN := RECGAKUREIBO.IDO_BI8;
--            --異動年月日９
--             IDO_BI9_IN := RECGAKUREIBO.IDO_BI9;
--            --異動年月日１０
--             IDO_BI10_IN := RECGAKUREIBO.IDO_BI10;
-- 2024/07/02 ZCZL.wangqiwei Delete End
            -- 出力用児童生年月日の取得
            PROC_GET_YMD(JIDO_BTH_IN, JIDO_BTH_OUT);
            --本名・通称名出力制御を取得する。
            IRTN_SIMEI := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,ACONSPRM_SIMEI,o_LENGTH);
            IF IRTN_SIMEI = 1 THEN
               ACONSPRM_SIMEI := A_CONS_PRM();
               ACONSPRM_SIMEI.EXTEND;
               ACONSPRM_SIMEI.EXTEND;
               ACONSPRM_SIMEI(1) := 0;
               ACONSPRM_SIMEI.EXTEND;
               ACONSPRM_SIMEI(2) := 0;
               ACONSPRM_SIMEI.EXTEND;
               ACONSPRM_SIMEI(3) := 0;
            ELSE
              WHILE (o_LENGTH < 3) LOOP
                          ACONSPRM_SIMEI.EXTEND;
                    ACONSPRM_SIMEI(o_LENGTH+1) := 0;
               o_LENGTH := o_LENGTH + 1;
              END LOOP;
            END IF;
            IF RECGAKUREIBO.JINKAKU_KBN != 0 THEN  
              IRTN  := FUNC_PRMFLGSET(g_sKojinNo,ACONSPRM_SIMEI(1),N_NAIYO_CD_JIDO);
              PROC_GET_YMD1(RECGAKUREIBO.JINKAKU_KBN,JIDO_BTH_IN,N_NAIYO_CD_JIDO, JIDO_BTH_OUT);
            END IF;
            -- 出力用小学校入学日の取得
            PROC_GET_YMD(SYO_NYUGAKU_IN, SYO_NYUGAKU_OUT);
            -- 出力用小学校転入学日の取得
            PROC_GET_YMD(SYO_TENNYUGAKU_IN, SYO_TENNYUGAKU_OUT);  
            -- 出力用小学校転学日の取得
            PROC_GET_YMD(SYO_TENGAKU_IN, SYO_TENGAKU_OUT);
            -- 出力用小学校卒業日の取得
            PROC_GET_YMD(SYO_SOTUGYO_IN, SYO_SOTUGYO_OUT);
            -- 出力用中学校入学日の取得
            PROC_GET_YMD(TYU_NYUGAKU_IN, TYU_NYUGAKU_OUT);
            -- 出力用中学校転入学日の取得
            PROC_GET_YMD(TYU_TENNYUGAKU_IN, TYU_TENNYUGAKU_OUT);  
            -- 出力用中学校転学日の取得
            PROC_GET_YMD(TYU_TENGAKU_IN, TYU_TENGAKU_OUT);
            -- 出力用中学校卒業日の取得
            PROC_GET_YMD(TYU_SOTUGYO_IN, TYU_SOTUGYO_OUT);
            -- 出力用区域外学校入学日の取得
            PROC_GET_YMD(GAI_NYUGAKU_IN, GAI_NYUGAKU_OUT);
            -- 出力用区域外学校転入学日の取得
            PROC_GET_YMD(GAI_TENNYUGAKU_IN, GAI_TENNYUGAKU_OUT);  
            -- 出力用区域外学校転退学日の取得
            PROC_GET_YMD(GAI_TENTAI_IN, GAI_TENTAI_OUT);
            -- 出力用区域外学校転学日の取得
            PROC_GET_YMD(GAI_TENGAKU_IN, GAI_TENGAKU_OUT);
            -- 出力用区域外学校退学日の取得
            PROC_GET_YMD(GAI_TAIGAKU_IN, GAI_TAIGAKU_OUT);
            -- 出力用区域外学校卒業日の取得
            PROC_GET_YMD(GAI_SOTUGYO_IN, GAI_SOTUGYO_OUT);
            -- 出力用養護学校入学日の取得
            PROC_GET_YMD(YOG_NYUGAKU_IN, YOG_NYUGAKU_OUT);
            -- 出力用養護学校転入学日の取得
            PROC_GET_YMD(YOG_TENNYUGAKU_IN, YOG_TENNYUGAKU_OUT);  
            -- 出力用養護学校転退学日の取得
            PROC_GET_YMD(YOG_TENTAI_IN, YOG_TENTAI_OUT);
            -- 出力用養護学校転学日の取得
            PROC_GET_YMD(YOG_TENGAKU_IN, YOG_TENGAKU_OUT);
            -- 出力用養護学校退学日の取得
            PROC_GET_YMD(YOG_TAIGAKU_IN, YOG_TAIGAKU_OUT);
            -- 出力用養護学校卒業日の取得
            PROC_GET_YMD(YOG_SOTUGYO_IN, YOG_SOTUGYO_OUT);
            -- 出力用猶予許可日の取得
            PROC_GET_YMD(YUYO_KYOKA_IN, YUYO_KYOKA_OUT);
            -- 出力用猶予開始日の取得
            PROC_GET_YMD(YUYO_KAISI_IN, YUYO_KAISI_OUT);
            -- 出力用猶予終了日の取得
            PROC_GET_YMD(YUYO_SYURYO_IN, YUYO_SYURYO_OUT);
            -- 出力用猶予復学日の取得
            PROC_GET_YMD(YUYO_FUKUGAKU_IN, YUYO_FUKUGAKU_OUT);
            -- 出力用免除許可日の取得
            PROC_GET_YMD(MENJO_KYOKA_IN, MENJO_KYOKA_OUT);
            -- 出力用免除復学日の取得
            PROC_GET_YMD(MENJO_FUKUGAKU_IN, MENJO_FUKUGAKU_OUT);
            -- 出力用督促年月日１の取得
            PROC_GET_YMD(TOKUSOKU_BI1_IN, TOKUSOKU_BI1_OUT);
            -- 出力用督促年月日２の取得
            PROC_GET_YMD(TOKUSOKU_BI2_IN, TOKUSOKU_BI2_OUT);
            -- 出力用督促年月日３の取得
            PROC_GET_YMD(TOKUSOKU_BI3_IN, TOKUSOKU_BI3_OUT);
            -- 出力用督促年月日４の取得
            PROC_GET_YMD(TOKUSOKU_BI4_IN, TOKUSOKU_BI4_OUT);
            -- 出力用督促年月日５の取得
            PROC_GET_YMD(TOKUSOKU_BI5_IN, TOKUSOKU_BI5_OUT);
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 STR           
            -- 出力用督促年月日6の取得
            PROC_GET_YMD(TOKUSOKU_BI6_IN, TOKUSOKU_BI6_OUT);
            -- 出力用督促年月日7の取得
            PROC_GET_YMD(TOKUSOKU_BI7_IN, TOKUSOKU_BI7_OUT);
            -- 出力用督促年月日8の取得
            PROC_GET_YMD(TOKUSOKU_BI8_IN, TOKUSOKU_BI8_OUT);
            -- 出力用督促年月日9の取得
            PROC_GET_YMD(TOKUSOKU_BI9_IN, TOKUSOKU_BI9_OUT);
            -- 出力用督促年月日10の取得
            PROC_GET_YMD(TOKUSOKU_BI10_IN, TOKUSOKU_BI10_OUT);
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 END           
            -- 出力用異動年月日１の取得
            PROC_GET_YMD(IDO_BI1_IN, IDO_BI1_OUT);
            -- 出力用異動年月日２の取得
            PROC_GET_YMD(IDO_BI2_IN, IDO_BI2_OUT);
            -- 出力用異動年月日３の取得
            PROC_GET_YMD(IDO_BI3_IN, IDO_BI3_OUT);
            -- 出力用異動年月日４の取得
            PROC_GET_YMD(IDO_BI4_IN, IDO_BI4_OUT);
            -- 出力用異動年月日５の取得
            PROC_GET_YMD(IDO_BI5_IN, IDO_BI5_OUT);
            -- 出力用異動年月日６の取得
            PROC_GET_YMD(IDO_BI6_IN, IDO_BI6_OUT);
            -- 出力用異動年月日７の取得
            PROC_GET_YMD(IDO_BI7_IN, IDO_BI7_OUT);
            -- 出力用異動年月日８の取得
            PROC_GET_YMD(IDO_BI8_IN, IDO_BI8_OUT);
            -- 出力用異動年月日９の取得
            PROC_GET_YMD(IDO_BI9_IN, IDO_BI9_OUT);
            -- 出力用異動年月日１０の取得
            PROC_GET_YMD(IDO_BI10_IN, IDO_BI10_OUT);
-- 2024/06/26 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
        I_RTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, o_tITEM);
        IF I_RTN = 0 THEN
            FOR j IN 1..o_tITEM.COUNT LOOP
                IF o_tITEM(j) = 'GKB050R001' THEN
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
        --通知書管理データ抽出
          BEGIN
          SELECT YOSHIKI_BANGO_SETTOGO,
                 YOSHIKI_BANGO,
                 YOSHIKI_BANGO_SETSUBIGO
          INTO 
                rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO                    --様式番号接頭語
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO                            --様式番号
               ,rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO                  --様式番号接尾語
          FROM GKBTTSUCHISHOKANRI
          WHERE CHOHYO_KBN = g_sIinkai;
        EXCEPTION
          WHEN OTHERS THEN
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO := NULL;
        END; 
-- 2024/06/26 ZCZL.wangqiwei Add end
            -- ＣＳＶ出力用変数の初期化
            rRECODE := NULL;
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00539横展開対応
            --rRECODE.NO                           :=      nROWNUM;                                --ソート順
            rRECODE.RENBAN                       :=      1;                                      --連番
-- 2024/07/02 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--             rRECODE.JIDO_SHIMEI_KANA             :=      RECGAKUREIBO.SHIMEI_KANA;               --児童氏名カナ
--             rRECODE.JIDO_SHIMEI_KANJI            :=      RECGAKUREIBO.SHIMEI_KANJI;              --児童氏名漢字
--             rRECODE.HYOJI_SEINENGAPI             :=      JIDO_BTH_OUT;                           --児童生年月日
            IF GKBFKHMCTRL(RECGAKUREIBO.KOJIN_NO, g_rOPRT.CHOHYOID, '0', g_sATENA, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN
              rRECODE.JIDO_SHIMEI_KANA             :=      o_sSHIMEIKANA;                          --児童氏名カナ
              rRECODE.JIDO_SHIMEI_KANJI            :=      o_sSHIMEI;                              --児童氏名漢字
              rRECODE.HYOJI_SEINENGAPI             :=      o_sBIRTHDAY;                            --児童生年月日
            END IF;
-- 2024/07/02 ZCZL.wangqiwei Update end
            rRECODE.JIDO_HYOJI_SEIBETSU          :=      RECGAKUREIBO.SEIBETSU;                  --児童性別
-- 2024/07/02 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--             rRECODE.JIDO_JUSHO                   :=      JIDO_JUSHO;                             --児童住所
--             rRECODE.HOGOSHA_SHIMEI_KANA          :=      RECGAKUREIBO.HOGOSYA_SHIMEI_KANA;       --保護者氏名カナ
--             rRECODE.HOGOSHA_SHIMEI_KANJI         :=      RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI;      --保護者氏名漢字
            IF g_sSIENJYUSYO = 1 THEN 
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
              -- rRECODE.JIDO_JUSHO                   :=      GAAPK0030.FDVJUSHO('GKB', RECGAKUREIBO.KOJIN_NO , g_sTANTOCODE , 
              --                                                                  g_sWSNUM , JIDO_JUSHO ,nPRMCTL,2 );     --児童住所
              rRECODE.JIDO_JUSHO                   :=     GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
            ELSE
              rRECODE.JIDO_JUSHO                   :=      JIDO_JUSHO;                             --児童住所
            END IF;
            IF GKBFKHMCTRL(RECGAKUREIBO.KOJIN_NO, g_rOPRT.CHOHYOID, '1', g_sATENA, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN
            rRECODE.HOGOSHA_SHIMEI_KANA          :=      o_sSHIMEIKANA;       --保護者氏名カナ
            rRECODE.HOGOSHA_SHIMEI_KANJI         :=      o_sSHIMEI;           --保護者氏名漢字
            END IF;
-- 2024/07/02 ZCZL.wangqiwei Update end
            rRECODE.ZOKUGARA                     :=      ZOKUGARA;                               --続柄
-- 2024/07/02 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--          rRECODE.HOGOSHA_JUSHO                :=      HOGO_JUSHO;                             --保護者住所
            IF g_sSIENJYUSYO = 1 THEN 
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
              -- rRECODE.HOGOSHA_JUSHO              :=      GAAPK0030.FDVJUSHO('GKB', RECGAKUREIBO.HOGOSYA_KOJIN_NO , g_sTANTOCODE , 
              --                                                                    g_sWSNUM , HOGO_JUSHO ,nPRMCTL,2 );     --保護者住所
              rRECODE.HOGOSHA_JUSHO              :=       GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
            ELSE
              rRECODE.HOGOSHA_JUSHO              :=      HOGO_JUSHO;                             --保護者住所
            END IF;
-- 2024/07/02 ZCZL.wangqiwei Update end
            rRECODE.SHOGAKKO_MEI                 :=      RECGAKUREIBO.SYOGAKOMEI;                --小学校名
            rRECODE.SHOGAKKO_NYUGAKU_BI          :=      SYO_NYUGAKU_OUT;                        --小学校入学日
            rRECODE.SHOGAKKO_TENNYUGAKU_BI       :=      SYO_TENNYUGAKU_OUT;                     --小学校転入学日
            rRECODE.SHOGAKKO_TENGAKU_BI          :=      SYO_TENGAKU_OUT;                        --小学校転学日
            rRECODE.SHOGAKKO_SOTSUGYO_BI         :=      SYO_SOTUGYO_OUT;                        --小学校卒業日
            rRECODE.TYUGAKOMEI                   :=      RECGAKUREIBO.TYUGAKOMEI;                --中学校名
            rRECODE.TYUGAKO_NYUGAKU_BI           :=      TYU_NYUGAKU_OUT;                        --中学校入学日
            rRECODE.TYUGAKO_TENNYUGAKU_BI        :=      TYU_TENNYUGAKU_OUT;                     --中学校転入学日
            rRECODE.TYUGAKO_TENGAKU_BI           :=      TYU_TENGAKU_OUT;                        --中学校転学日
            rRECODE.TYUGAKO_SOTSUGYO_BI          :=      TYU_SOTUGYO_OUT;                        --中学校卒業日
-- 2024/06/26 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発の標準化対応
--             rRECODE.KUIKIGAI_GAKKO_MEI           :=      RECGAKUREIBO.KUIKIGAIMEI;               --区域外学校名
--             rRECODE.KUIKIGAI_SETISYA             :=      RECGAKUREIBO.KUIKIGAI_SETISYA;          --区域外学校設置者名
--             rRECODE.KUIKIGAI_NYUGAKU_BI          :=      GAI_NYUGAKU_OUT;                        --区域外学校入学日
--             rRECODE.KUIKIGAI_TENNYUGAKU_BI       :=      GAI_TENNYUGAKU_OUT;                     --区域外学校転入学日
--             rRECODE.KUIKIGAI_TENTAIGAKU_BI       :=      GAI_TENTAI_OUT;                         --区域外学校転退学日
--             rRECODE.KUIKIGAI_TENGAKU_BI          :=      GAI_TENGAKU_OUT;                        --区域外学校転学日
--             rRECODE.KUIKIGAI_TAIGAKU_BI          :=      GAI_TAIGAKU_OUT;                        --区域外学校退学日
--             rRECODE.KUIKIGAI_SOTSUGYO_BI         :=      GAI_SOTUGYO_OUT;                        --区域外学校卒業日
--             rRECODE.YOGOGAKOMEI                  :=      RECGAKUREIBO.YOGOGAKOMEI;               --養護学校名
--             rRECODE.YOGOGAKO_SETISYA             :=      RECGAKUREIBO.YOGOGAKO_SETISYA;          --養護学校設置者名
--             rRECODE.YOGOGAKO_NYUGAKU_BI          :=      YOG_NYUGAKU_OUT;                        --養護学校入学日
--             rRECODE.YOGOGAKO_TENNYUGAKU_BI       :=      YOG_TENNYUGAKU_OUT;                     --養護学校転入学日
--             rRECODE.YOGOGAKO_TENTAIGAKU_BI       :=      YOG_TENTAI_OUT;                         --養護学校転退学日
--             rRECODE.YOGOGAKO_TENGAKU_BI          :=      YOG_TENGAKU_OUT;                        --養護学校転学日
--             rRECODE.YOGOGAKO_TAIGAKU_BI          :=      YOG_TAIGAKU_OUT;                        --養護学校退学日
--             rRECODE.YOGOGAKO_SOTSUGYO_BI         :=      YOG_SOTUGYO_OUT;                        --養護学校卒業日
-- 2024/06/26 ZCZL.wangqiwei Delete end
            rRECODE.YUYO_KYOKA_BI                :=      YUYO_KYOKA_OUT;                         --猶予許可日
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 STR            
--  2025/07/14 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA18187
              --IF RECGAKUREIBO.YUYO_JIYU_CD IS NOT NULL THEN
              IF RECGAKUREIBO.YUYO_JIYU_CD IS NOT NULL AND TRIM(RECGAKUREIBO.YUYO_JIYU_CD) <> '00' THEN
--  2025/07/14 CTC.HJF UPDATE End
                SELECT
                MEISHO
                INTO
                YUYO_JIYU
                FROM
                KKATCD 
                WHERE
                TRIM(gyoumuCode) = 'GKB' 
                AND TRIM(codeCode) = 029 
                AND TRIM(groupCode) = 0001 
                AND TRIM(anycode) = RECGAKUREIBO.YUYO_JIYU_CD;
              ELSE
--  2025/05/16 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                --RETURN NULL;  
                YUYO_JIYU := NULL;
--  2025/05/16 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応                
                END IF;
            rRECODE.YUYO_JIYU                    :=      YUYO_JIYU;                              --猶予許可事由          
--            rRECODE.YUYO_JIYU                    :=      RECGAKUREIBO.YUYO_JIYU;                 --猶予許可事由
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 END            
            
            rRECODE.YUYO_KAISI_BI                :=      YUYO_KAISI_OUT;                         --猶予開始日
            rRECODE.YUYO_SYURYO_BI               :=      YUYO_SYURYO_OUT;                        --猶予終了日
            rRECODE.YUYO_FUKUGAKU_BI             :=      YUYO_FUKUGAKU_OUT;                      --猶予復学日
            rRECODE.MENJO_KYOKA_BI               :=      MENJO_KYOKA_OUT;                        --免除許可日
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 STR            
--  2025/07/14 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA18187
              --IF RECGAKUREIBO.MENJO_JIYU_CD IS NOT NULL THEN
                IF RECGAKUREIBO.MENJO_JIYU_CD IS NOT NULL AND TRIM(RECGAKUREIBO.MENJO_JIYU_CD) <> '00'  THEN
--  2025/07/14 CTC.HJF UPDATE End
                SELECT
                MEISHO
                INTO
                MENJO_JIYU
                FROM
                KKATCD 
                WHERE
                TRIM(gyoumuCode) = 'GKB' 
                AND TRIM(codeCode) = 029 
                AND TRIM(groupCode) = 0001 
                AND TRIM(anycode) = RECGAKUREIBO.MENJO_JIYU_CD;
              ELSE
--  2025/05/16 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
                --RETURN NULL;
                MENJO_JIYU := NULL;
--  2025/05/16 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応  
                END IF;
            rRECODE.MENJO_JIYU                    :=      MENJO_JIYU;                              --猶予許可事由               
           -- rRECODE.MENJO_JIYU                   :=      RECGAKUREIBO.MENJO_JIYU;                --免除許可事由
--  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 END                       
            rRECODE.MENJO_FUKUGAKU_BI            :=      MENJO_FUKUGAKU_OUT;                     --免除復学日
-- 2024/07/02 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--             rRECODE.TOKUSOKU_BI1                 :=      TOKUSOKU_BI1_OUT;                       --督促年月日１
--             rRECODE.TOKUSOKU_NAIYO1              :=      RECGAKUREIBO.TOKUSOKU_NAIYO1;           --督促内容１
--             rRECODE.TOKUSOKU_BI2                 :=      TOKUSOKU_BI2_OUT;                       --督促年月日２
--             rRECODE.TOKUSOKU_NAIYO2              :=      RECGAKUREIBO.TOKUSOKU_NAIYO2;           --督促内容２
--             rRECODE.TOKUSOKU_BI3                 :=      TOKUSOKU_BI3_OUT;                       --督促年月日３
--             rRECODE.TOKUSOKU_NAIYO3              :=      RECGAKUREIBO.TOKUSOKU_NAIYO3;           --督促内容３
--             rRECODE.TOKUSOKU_BI4                 :=      TOKUSOKU_BI4_OUT;                       --督促年月日４
--             rRECODE.TOKUSOKU_NAIYO4              :=      RECGAKUREIBO.TOKUSOKU_NAIYO4;           --督促内容４
--             rRECODE.TOKUSOKU_BI5                 :=      TOKUSOKU_BI5_OUT;                       --督促年月日５
--             rRECODE.TOKUSOKU_NAIYO5              :=      RECGAKUREIBO.TOKUSOKU_NAIYO5;           --督促内容５
--             rRECODE.IDO_BI1                      :=      IDO_BI1_OUT;                            --異動事由年月日１
--             rRECODE.IDO_JIYU1                    :=      RECGAKUREIBO.IDO_JIYU1;                 --異動事由１
--             rRECODE.IDO_BI2                      :=      IDO_BI2_OUT;                            --異動事由年月日２
--             rRECODE.IDO_JIYU2                    :=      RECGAKUREIBO.IDO_JIYU2;                 --異動事由２
--             rRECODE.IDO_BI3                      :=      IDO_BI3_OUT;                            --異動事由年月日３
--             rRECODE.IDO_JIYU3                    :=      RECGAKUREIBO.IDO_JIYU3;                 --異動事由３
--             rRECODE.IDO_BI4                      :=      IDO_BI4_OUT;                            --異動事由年月日４
--             rRECODE.IDO_JIYU4                    :=      RECGAKUREIBO.IDO_JIYU4;                 --異動事由４
--             rRECODE.IDO_BI5                      :=      IDO_BI5_OUT;                            --異動事由年月日５
--             rRECODE.IDO_JIYU5                    :=      RECGAKUREIBO.IDO_JIYU5;                 --異動事由５
--             rRECODE.IDO_BI6                      :=      IDO_BI6_OUT;                            --異動事由年月日６
--             rRECODE.IDO_JIYU6                    :=      RECGAKUREIBO.IDO_JIYU6;                 --異動事由６
--             rRECODE.IDO_BI7                      :=      IDO_BI7_OUT;                            --異動年月日７
--             rRECODE.IDO_JIYU7                    :=      RECGAKUREIBO.IDO_JIYU7;                 --異動事由７
--             rRECODE.IDO_BI8                      :=      IDO_BI8_OUT;                            --異動年月日８
--             rRECODE.IDO_JIYU8                    :=      RECGAKUREIBO.IDO_JIYU8;                 --異動事由８
--             rRECODE.IDO_BI9                      :=      IDO_BI9_OUT;                            --異動年月日９
--             rRECODE.IDO_JIYU9                    :=      RECGAKUREIBO.IDO_JIYU9;                 --異動事由９
--             rRECODE.IDO_BI10                     :=      IDO_BI10_OUT;                           --異動年月日１０
--             rRECODE.IDO_JIYU10                   :=      RECGAKUREIBO.IDO_JIYU10;                --異動事由１０
--             IRTN_KYOUIKU := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',g_sIinkai,ACONSPRM_KYOUIKU,o_LENGTH);
            --督促年月日1-5と督促内容1-5の取得 
            TOKUSOKU_BIS    := A_CONS_PRM();
            TOKUSOKU_NAIYOS := A_CONS_PRM();
            TOKUSOKU_BIS.EXTEND;
            TOKUSOKU_NAIYOS.EXTEND;
            TOKUSOKU_BIS(1)           :=  RECGAKUREIBO.TOKUSOKU_BI10;
            TOKUSOKU_NAIYOS(1)        :=  RECGAKUREIBO.TOKUSOKU_NAIYO10;
            TOKUSOKU_BIS.EXTEND;
            TOKUSOKU_NAIYOS.EXTEND;
            TOKUSOKU_BIS(2)           :=  RECGAKUREIBO.TOKUSOKU_BI9;
            TOKUSOKU_NAIYOS(2)        :=  RECGAKUREIBO.TOKUSOKU_NAIYO9;
            TOKUSOKU_BIS.EXTEND;
            TOKUSOKU_NAIYOS.EXTEND;
            TOKUSOKU_BIS(3)           :=  RECGAKUREIBO.TOKUSOKU_BI8;
            TOKUSOKU_NAIYOS(3)        :=  RECGAKUREIBO.TOKUSOKU_NAIYO8;
            TOKUSOKU_BIS.EXTEND;
            TOKUSOKU_NAIYOS.EXTEND;
            TOKUSOKU_BIS(4)           :=  RECGAKUREIBO.TOKUSOKU_BI7;
            TOKUSOKU_NAIYOS(4)        :=  RECGAKUREIBO.TOKUSOKU_NAIYO7;
            TOKUSOKU_BIS.EXTEND;
            TOKUSOKU_NAIYOS.EXTEND;
            TOKUSOKU_BIS(5)           :=  RECGAKUREIBO.TOKUSOKU_BI6;
            TOKUSOKU_NAIYOS(5)        :=  RECGAKUREIBO.TOKUSOKU_NAIYO6;
            TOKUSOKU_BIS.EXTEND;
            TOKUSOKU_NAIYOS.EXTEND;
            TOKUSOKU_BIS(6)           :=  RECGAKUREIBO.TOKUSOKU_BI5;
            TOKUSOKU_NAIYOS(6)        :=  RECGAKUREIBO.TOKUSOKU_NAIYO5;
            TOKUSOKU_BIS.EXTEND;
            TOKUSOKU_NAIYOS.EXTEND;
            TOKUSOKU_BIS(7)           :=  RECGAKUREIBO.TOKUSOKU_BI4;
            TOKUSOKU_NAIYOS(7)        :=  RECGAKUREIBO.TOKUSOKU_NAIYO4;
            TOKUSOKU_BIS.EXTEND;
            TOKUSOKU_NAIYOS.EXTEND;
            TOKUSOKU_BIS(8)           :=  RECGAKUREIBO.TOKUSOKU_BI3;
            TOKUSOKU_BIS.EXTEND;
            TOKUSOKU_NAIYOS.EXTEND;
            TOKUSOKU_BIS(9)           :=  RECGAKUREIBO.TOKUSOKU_BI2;
            TOKUSOKU_NAIYOS(9)        :=  RECGAKUREIBO.TOKUSOKU_NAIYO2;
            TOKUSOKU_BIS.EXTEND;
            TOKUSOKU_NAIYOS.EXTEND;
            TOKUSOKU_BIS(10)          :=  RECGAKUREIBO.TOKUSOKU_BI1;
            TOKUSOKU_NAIYOS(10)       :=  RECGAKUREIBO.TOKUSOKU_NAIYO1;

            TOKUSOKU_BI    := A_CONS_PRM();
            TOKUSOKU_NAIYO := A_CONS_PRM();
            FOR i IN 1..10 LOOP
--  2024/11/06 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00443横展開対応
              --IF TOKUSOKU_NAIYOS(i) <> ' ' AND TOKUSOKU_BIS(i) <> 0 THEN 
                 TOKUSOKU_BI.EXTEND;
                 TOKUSOKU_NAIYO.EXTEND;
--  2024/11/06 ZCZL.WANGYUNING ADD 0.3.000.002:IT_GKB_00443横展開対応
              IF TOKUSOKU_NAIYOS(i) <> ' ' AND TOKUSOKU_BIS(i) <> 0 THEN 
                 TOKUSOKU_BI(N)      := TOKUSOKU_BIS(i);
                 TOKUSOKU_NAIYO(N)   := TOKUSOKU_NAIYOS(i);
                 N  := N + 1;
              END IF;
              IF N = 6 THEN 
                 EXIT;
              END IF;
            END LOOP;
-- 2025/01/31 JPJYS.GL UPDATE ST_GKB_TMP00019対応 start
--            IF TOKUSOKU_BI IS NOT NULL AND TOKUSOKU_NAIYO IS NOT NULL THEN 
--                IF FLG = 1 AND TOKUSOKU_NAIYO(INDX) IS NOT NULL THEN 
--                   rRECODE.TOKUSOKU_BI1      := TOKUSOKU_BI(INDX);
--                   rRECODE.TOKUSOKU_NAIYO1   := TOKUSOKU_NAIYO(INDX);
--                   FLG   := FLG + 1;
--                   INDX  := INDX + 1;
--                ELSIF FLG = 2 AND TOKUSOKU_NAIYO(INDX) IS NOT NULL THEN 
--                   rRECODE.TOKUSOKU_BI2      := TOKUSOKU_BI(INDX);
--                   rRECODE.TOKUSOKU_NAIYO2   := TOKUSOKU_NAIYO(INDX);
--                   FLG   := FLG + 1;
--                   INDX  := INDX + 1;
--                ELSIF FLG = 3 AND TOKUSOKU_NAIYO(INDX) IS NOT NULL THEN 
--                   rRECODE.TOKUSOKU_BI3      := TOKUSOKU_BI(INDX);
--                   rRECODE.TOKUSOKU_NAIYO3   := TOKUSOKU_NAIYO(INDX);
--                   FLG   := FLG + 1;
--                   INDX  := INDX + 1;
--                ELSIF FLG = 4 AND TOKUSOKU_NAIYO(INDX) IS NOT NULL THEN 
--                   rRECODE.TOKUSOKU_BI4      := TOKUSOKU_BI(INDX);
--                   rRECODE.TOKUSOKU_NAIYO4   := TOKUSOKU_NAIYO(INDX);
--                   FLG   := FLG + 1;
--                   INDX  := INDX + 1;
--                ELSIF FLG = 5 AND TOKUSOKU_NAIYO(INDX) IS NOT NULL THEN
--                   rRECODE.TOKUSOKU_BI5      := TOKUSOKU_BI(INDX);
--                   rRECODE.TOKUSOKU_NAIYO5   := TOKUSOKU_NAIYO(INDX);
--                   FLG   := FLG + 1;
--                   INDX  := INDX + 1;
--                ELSE 
--                  EXIT;
--                END IF; 
--             END IF;
        FOR i IN 1..5 LOOP
            BEGIN
            IF TOKUSOKU_BI IS NOT NULL AND TOKUSOKU_NAIYO IS NOT NULL THEN
                IF FLG = 1 AND TOKUSOKU_NAIYO(INDX) IS NOT NULL THEN
                  --  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 STR
                  -- rRECODE.TOKUSOKU_BI1      := TOKUSOKU_BI(INDX);
                    rRECODE.TOKUSOKU_BI1      := TOKUSOKU_BI1_OUT;
                    --  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 END
                   rRECODE.TOKUSOKU_NAIYO1   := TOKUSOKU_NAIYO(INDX);
                   FLG   := FLG + 1;
                   INDX  := INDX + 1;
                ELSIF FLG = 2 AND TOKUSOKU_NAIYO(INDX) IS NOT NULL THEN
                  --  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 STR
                   --rRECODE.TOKUSOKU_BI2      := TOKUSOKU_BI(INDX);
                    rRECODE.TOKUSOKU_BI2      := TOKUSOKU_BI2_OUT;
                    --  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 END
                   rRECODE.TOKUSOKU_NAIYO2   := TOKUSOKU_NAIYO(INDX);
                   FLG   := FLG + 1;
                   INDX  := INDX + 1;
                ELSIF FLG = 3 AND TOKUSOKU_NAIYO(INDX) IS NOT NULL THEN
                  --  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 STR
                  -- rRECODE.TOKUSOKU_BI3      := TOKUSOKU_BI(INDX);
                    rRECODE.TOKUSOKU_BI3      := TOKUSOKU_BI3_OUT;
                    --  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 END
                   rRECODE.TOKUSOKU_NAIYO3   := TOKUSOKU_NAIYO(INDX);
                   FLG   := FLG + 1;
                   INDX  := INDX + 1;
                ELSIF FLG = 4 AND TOKUSOKU_NAIYO(INDX) IS NOT NULL THEN
                  --  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応S TR
                  -- rRECODE.TOKUSOKU_BI4      := TOKUSOKU_BI(INDX);
                   rRECODE.TOKUSOKU_BI4      := TOKUSOKU_BI4_OUT;
                   --  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 END
                   rRECODE.TOKUSOKU_NAIYO4   := TOKUSOKU_NAIYO(INDX);
                   FLG   := FLG + 1;
                   INDX  := INDX + 1;
                ELSIF FLG = 5 AND TOKUSOKU_NAIYO(INDX) IS NOT NULL THEN
                  --  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応STR
                  -- rRECODE.TOKUSOKU_BI5      := TOKUSOKU_BI(INDX);
                   rRECODE.TOKUSOKU_BI5      := TOKUSOKU_BI5_OUT;
                   --  2025/02/07 JPJYS.LIZIZHONG UPDATE 0.3.000.006:ST_GKB_TMP00047の対応 END
                   rRECODE.TOKUSOKU_NAIYO5   := TOKUSOKU_NAIYO(INDX);
                   FLG   := FLG + 1;
                   INDX  := INDX + 1;
                ELSE
                  EXIT;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(FLG||INDX);
        END;
        END LOOP;
-- 2025/01/31 JPJYS.GL UPDATE ST_GKB_TMP00019対応 end

             rRECODE.IDO_BI1                      :=      NULL;                            --異動事由年月日１
             rRECODE.IDO_JIYU1                    :=      NULL;                            --異動事由１
             rRECODE.IDO_BI2                      :=      NULL;                            --異動事由年月日２
             rRECODE.IDO_JIYU2                    :=      NULL;                            --異動事由２
             rRECODE.IDO_BI3                      :=      NULL;                            --異動事由年月日３
             rRECODE.IDO_JIYU3                    :=      NULL;                            --異動事由３
             rRECODE.IDO_BI4                      :=      NULL;                            --異動事由年月日４
             rRECODE.IDO_JIYU4                    :=      NULL;                            --異動事由４
             rRECODE.IDO_BI5                      :=      NULL;                            --異動事由年月日５
             rRECODE.IDO_JIYU5                    :=      NULL;                            --異動事由５
             rRECODE.IDO_BI6                      :=      NULL;                            --異動事由年月日６
             rRECODE.IDO_JIYU6                    :=      NULL;                            --異動事由６
             rRECODE.IDO_BI7                      :=      NULL;                            --異動年月日７
             rRECODE.IDO_JIYU7                    :=      NULL;                            --異動事由７
             rRECODE.IDO_BI8                      :=      NULL;                            --異動年月日８
             rRECODE.IDO_JIYU8                    :=      NULL;                            --異動事由８
             rRECODE.IDO_BI9                      :=      NULL;                            --異動年月日９
             rRECODE.IDO_JIYU9                    :=      NULL;                            --異動事由９
             rRECODE.IDO_BI10                     :=      NULL;                            --異動年月日１０
             rRECODE.IDO_JIYU10                   :=      NULL;                            --異動事由１０
            IRTN_KYOUIKU := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',0,ACONSPRM_KYOUIKU,o_LENGTH);
-- 2024/07/02 ZCZL.wangqiwei Update start End
            IF IRTN_KYOUIKU = 1 THEN
               ACONSPRM_KYOUIKU := A_CONS_PRM();
               ACONSPRM_KYOUIKU.EXTEND;
               ACONSPRM_KYOUIKU.EXTEND;
               ACONSPRM_KYOUIKU(1) := ' ';
               ACONSPRM_KYOUIKU.EXTEND;
               ACONSPRM_KYOUIKU(2) := ' ';
               ACONSPRM_KYOUIKU.EXTEND;
               ACONSPRM_KYOUIKU(3) := ' ';
               ACONSPRM_KYOUIKU.EXTEND;
               ACONSPRM_KYOUIKU(4) := ' ';
               ACONSPRM_KYOUIKU.EXTEND;
               ACONSPRM_KYOUIKU(5) := ' ';
               ACONSPRM_KYOUIKU.EXTEND;
               ACONSPRM_KYOUIKU(6) := ' ';
               ACONSPRM_KYOUIKU.EXTEND;
               ACONSPRM_KYOUIKU(7) := ' ';
               ACONSPRM_KYOUIKU.EXTEND;
               ACONSPRM_KYOUIKU(8) := ' ';
            ELSE
              WHILE (o_LENGTH < 8) LOOP
                  ACONSPRM_KYOUIKU.EXTEND;
                  ACONSPRM_KYOUIKU(o_LENGTH+1) := ' ';
                  o_LENGTH := o_LENGTH + 1;
              END LOOP;
            END IF;
            rRECODE.KYOIKU_KAI_MEI               :=      ACONSPRM_KYOUIKU(1);                                                                           --教育委員会名
            rRECODE.GAKKO_CD                     :=      IGAKO_CD;                                                                                      --学校コード
            rRECODE.GAKKO_MEI                    :=      GAKKOUMEI;                                                                                     --学校名
            rRECODE.JIDO_GYOSEIKU_CD             :=      RECGAKUREIBO.GYOSEIKU_CD;                                                                      --児童行政区コード
            rRECODE.JIDO_GYOSEIKU_MEI            :=      GAAPK0030.FGYOSEIKUMEI(RECGAKUREIBO.SANTEIDANTAI_CD,RECGAKUREIBO.GYOSEIKU_CD);                 --児童行政区名
            rRECODE.CD2                          :=      RECGAKUREIBO.HOGOSYA_GYOSEIKU_CD;                                                              --保護者行政区コード
            rRECODE.MEISHO2                      :=      GAAPK0030.FGYOSEIKUMEI(RECGAKUREIBO.HOGOSYA_SANTEIDANTAI_CD,RECGAKUREIBO.HOGOSYA_GYOSEIKU_CD); --保護者行政区名
            rRECODE.CD3                          :=      NULL;                                                                                          --予備コード
            rRECODE.MEISHO3                      :=      NULL;                                                                                          --予備名称
            -- 外国人の場合、本名を出力
            --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.004:IT_GKB_00711の対応 START
--            IF RECGAKUREIBO.JINKAKU_KBN = 1 THEN
            --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.004:IT_GKB_00711の対応 END
              rRECODE.GKJ_JIDO_HONMYO_KANA         :=      RECGAKUREIBO.HONMYO_KANA;                                                                      --外国人児童本名かな
              rRECODE.GKJ_JIDO_HONMYO_KANJI        :=      RECGAKUREIBO.HONMYO_KANJI;                                                                     --外国人児童本名漢字
              HONMYO_KANA := RECGAKUREIBO.HONMYO_KANA;
              HONMYO_KANJI := RECGAKUREIBO.HONMYO_KANJI;
            --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.004:IT_GKB_00711の対応 START
--            ELSE
--              rRECODE.GKJ_JIDO_HONMYO_KANA         :=      NULL;                                                                      --外国人児童本名かな
--              rRECODE.GKJ_JIDO_HONMYO_KANJI        :=      NULL;                                                                     --外国人児童本名漢字
--              HONMYO_KANA := '';
--              HONMYO_KANJI := '';
--            END IF;
            --  2024/12/03 JPJYS.SHAXUE UPDATE 0.3.000.004:IT_GKB_00711の対応 END
            o_ACONSPRM := NULL;
            o_LENGTH := 0;
            I_RTN := GAAPK0030.FGETATENA( RECGAKUREIBO.HOGOSYA_KOJIN_NO,
                                        'GKB',
                                        ISAKUSEIBI,
                                        RA1,
                                        RA2 );
            IF I_RTN = 0 THEN
                IF(RA1.JINKAKU_KBN = 1) THEN
                    -- 外国人保護者本名かな
                    rRECODE.GKJ_HOGOSHA_HONMYO_KANA      :=      RA1.HONMYO_KANA;                                                                --外国人保護者本名かな
                    -- 外国人保護者本名漢字
                    rRECODE.GKJ_HOGOSHA_HONMYO_KANJI     :=      RA1.HONMYO_KANJI;                                                                --外国人保護者本名漢字
                    HOGOSYA_HONMYO_KANA := RA1.HONMYO_KANA;
                    HOGOSYA_HONMYO_KANJI := RA1.HONMYO_KANJI;
                ELSE
                  -- 外国人保護者本名かな
                  rRECODE.GKJ_HOGOSHA_HONMYO_KANA      :=      NULL;                                                                               --外国人保護者本名かな
                  -- 外国人保護者本名漢字
                  rRECODE.GKJ_HOGOSHA_HONMYO_KANJI     :=      NULL;                                                                              --外国人保護者本名漢字
                  HOGOSYA_HONMYO_KANA := '';
                  HOGOSYA_HONMYO_KANJI := '';
                END IF;
            ELSE
                -- 外国人保護者本名かな
                rRECODE.GKJ_HOGOSHA_HONMYO_KANA      :=      NULL;                                                                               --外国人保護者本名かな
                -- 外国人保護者本名漢字
                rRECODE.GKJ_HOGOSHA_HONMYO_KANJI     :=      NULL;                                                                              --外国人保護者本名漢字
            END IF;
            --外国人場合
            IF RECGAKUREIBO.JINKAKU_KBN = 1 THEN
            -- 表示児童氏名かな
             VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SIMEI(1),N_NAIYO_CD_JIDO,
                              TRIM(RECGAKUREIBO.SHIMEI_KANA),TRIM(HONMYO_KANA));
             rRECODE.JIDO_HONMYO_KANA             :=      VEDIT_GO_DATA;                                                                                 --表示児童氏名かな
            -- 表示児童氏名漢字
             VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SIMEI(1),N_NAIYO_CD_JIDO,
                              TRIM(RECGAKUREIBO.SHIMEI_KANJI),TRIM(HONMYO_KANJI));
             rRECODE.JIDO_HONMYO_KANJI            :=  VEDIT_GO_DATA;                                                                                     --表示児童氏名漢字
            ELSE
              IF ACONSPRM_SIMEI(1) = 1 THEN
                -- 表示児童氏名かな
                IF  TRIM(HONMYO_KANA) IS NOT NULL THEN
                  rRECODE.JIDO_HONMYO_KANA             :=      HONMYO_KANA;                                                                                 --表示児童氏名かな
                ELSE
                  rRECODE.JIDO_HONMYO_KANA             :=      RECGAKUREIBO.SHIMEI_KANA;                                                                    --表示児童氏名かな
                END IF;
                -- 表示児童氏名漢字
                IF TRIM(HONMYO_KANJI) IS NOT NULL THEN
                  rRECODE.JIDO_HONMYO_KANJI            :=     HONMYO_KANJI;                                                                                  --表示児童氏名漢字
                ELSE
                  rRECODE.JIDO_HONMYO_KANJI            :=     RECGAKUREIBO.SHIMEI_KANJI;                                                                                                --表示児童氏名漢字
                END IF;
               ELSE
-- 2025/06/27 CTC.HJF DELETE Start 1.0.010.000:IT_GKB_00003対応
                 --rRECODE.JIDO_HONMYO_KANA             :=      RECGAKUREIBO.SHIMEI_KANA;                                                                      --表示児童氏名かな
                 --rRECODE.JIDO_HONMYO_KANJI            :=      RECGAKUREIBO.SHIMEI_KANJI;                                                                                               --表示児童氏名漢字
-- 2025/06/27 CTC.HJF DELETE End
-- 2025/06/27 CTC.HJF ADD Start 1.0.010.000:IT_GKB_00003対応
                  IF GKBFKHMCTRL(RECGAKUREIBO.KOJIN_NO, g_rOPRT.CHOHYOID, '0', g_sATENA, o_sSHIMEIKANA, o_sSHIMEI, o_sBIRTHDAY) = 0 THEN
                     rRECODE.JIDO_HONMYO_KANA             :=      o_sSHIMEIKANA;                          --表示児童氏名かな
                     rRECODE.JIDO_HONMYO_KANJI            :=      o_sSHIMEI;                              --表示児童氏名漢字
                  END IF;
-- 2025/06/27 CTC.HJF ADD End
               END IF;
            END IF;
            IF RA1.JINKAKU_KBN = 1 THEN
              -- 表示保護者氏名かな
              VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SIMEI(1),N_NAIYO_CD_JIDO,
                               TRIM(RECGAKUREIBO.HOGOSYA_SHIMEI_KANA),TRIM(HOGOSYA_HONMYO_KANA));
              rRECODE.HYOJI_HOGOSHA_SHIMEI_KANA    :=    VEDIT_GO_DATA;                                                                                      --表示保護者氏名かな
              -- 表示保護者氏名漢字
              VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SIMEI(1),N_NAIYO_CD_JIDO,
                               TRIM(RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI),TRIM(HOGOSYA_HONMYO_KANJI));
              rRECODE.HOGOSHA_HONMYO_KANJI         :=    VEDIT_GO_DATA;                                                                                      --表示保護者氏名漢字
            ELSE
              IF ACONSPRM_SIMEI(1) = 1 THEN
                -- 表示保護者氏名かな
                IF  TRIM(HOGOSYA_HONMYO_KANA) IS NOT NULL THEN
                  rRECODE.HYOJI_HOGOSHA_SHIMEI_KANA    :=      HOGOSYA_HONMYO_KANA;                                                                          --表示保護者氏名かな
                ELSE
                  rRECODE.HYOJI_HOGOSHA_SHIMEI_KANA    :=      RECGAKUREIBO.HOGOSYA_SHIMEI_KANA;                                                             --表示保護者氏名かな
                END IF;
                -- 表示保護者氏名漢字
                IF TRIM(HOGOSYA_HONMYO_KANJI) IS NOT NULL THEN
                  rRECODE.HOGOSHA_HONMYO_KANJI         :=    HOGOSYA_HONMYO_KANJI;                                                                           --表示保護者氏名漢字
                ELSE
                  rRECODE.HOGOSHA_HONMYO_KANJI         :=     RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI;                                                             --表示保護者氏名漢字
                END IF;
              ELSE
                rRECODE.HYOJI_HOGOSHA_SHIMEI_KANA    :=      RECGAKUREIBO.HOGOSYA_SHIMEI_KANA;                                                                --表示保護者氏名かな
                rRECODE.HOGOSHA_HONMYO_KANJI         :=      RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI;                                                               --表示保護者氏名漢字
              END IF;
            END IF;
-- 2024/06/26 ZCZL.wangqiwei Update 0.3.000.000:新WizLIFE2次開発の標準化対応
--             rRECODE.KOJIN_NO                     :=       RECGAKUREIBO.KOJIN_NO;                                                                               --個人番号
            rRECODE.KOJIN_NO                     :=       g_sKojinNo;                                                                               --個人番号
            -- 連番印字制御
            IRTN := KKAPK0030.FPRMSHUTOKU('GKB','00RENBAN',0,o_ACONSPRM,o_LENGTH);
            IF IRTN =1 THEN
               o_ACONSPRM := A_CONS_PRM();
               o_ACONSPRM.EXTEND;
               o_ACONSPRM.EXTEND;
               o_ACONSPRM(1) := 0;
            ELSE
                WHILE (o_LENGTH < 1) LOOP
                  o_ACONSPRM.EXTEND;
                  o_ACONSPRM(o_LENGTH+1) := 0;
                  o_LENGTH := o_LENGTH + 1;
                END LOOP;
            END IF;
            IF o_ACONSPRM(1) = 0 THEN
                rRECODE.HYOJI_CHOHYO_NO              :=     ' ';                                                                                                --表示帳票連番
            ELSIF o_ACONSPRM(1) = 1 THEN
                rRECODE.HYOJI_CHOHYO_NO              :=     LPAD(RECGAKUREIBO.CHOHYO_NO,5,' ');                                                                 --表示帳票連番
            ELSIF o_ACONSPRM(1) = 2 THEN
                rRECODE.HYOJI_CHOHYO_NO              :=     GAKKOUMEI || '-' || LPAD(RECGAKUREIBO.CHOHYO_NO,5,' ');                                                                                                    --表示帳票連番
            ELSIF o_ACONSPRM(1) = 3 THEN
                rRECODE.HYOJI_CHOHYO_NO              :=      LPAD(IGAKO_CD,5,' ') || '-' || LPAD(RECGAKUREIBO.CHOHYO_NO,5,' ');                                                                                        --表示帳票連番
            ELSIF o_ACONSPRM(1) = 4 THEN
                rRECODE.HYOJI_CHOHYO_NO              :=     GAKKOUMEI || '-' || GAAPK0030.FGYOSEIKUMEI(RECGAKUREIBO.SANTEIDANTAI_CD,RECGAKUREIBO.GYOSEIKU_CD) || '-' || LPAD(RECGAKUREIBO.CHOHYO_NO,5,' ');            --表示帳票連番
            ELSIF o_ACONSPRM(1) = 5 THEN
                rRECODE.HYOJI_CHOHYO_NO              :=     LPAD(IGAKO_CD,5,' ') || '-' || GAAPK0030.FGYOSEIKUMEI(RECGAKUREIBO.SANTEIDANTAI_CD,RECGAKUREIBO.GYOSEIKU_CD) || '-' || LPAD(RECGAKUREIBO.CHOHYO_NO,5,' '); --表示帳票連番
            ELSE
                rRECODE.HYOJI_CHOHYO_NO              :=      ' ';                                                                                               --表示帳票連番
            END IF;
            IF RECGAKUREIBO.HOGOSYA_KOJIN_NO <> 0 THEN
                IRTN := GKBFKZKGMGET(1, RECGAKUREIBO.ZOKUGARA1, RECGAKUREIBO.ZOKUGARA2, RECGAKUREIBO.ZOKUGARA3, RECGAKUREIBO.ZOKUGARA4, o_VZOKUGARAMEI, o_IHERR);
                IF IRTN = 0 THEN
                  rRECODE.HOGOSHA_KANKEI               :=  o_VZOKUGARAMEI;                                                                                      --保護者との関係
                END IF;
            ELSE
                rRECODE.HOGOSHA_KANKEI               :=  NULL;                                                                                                  --保護者との関係
            END IF;
            IF RECGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN > 0 THEN
              rRECODE.SHOGAKKO_TENNYUGAKU_GAKUNEN  :=   RECGAKUREIBO.SYOGAKO_TENNYUGAKU_GAKUNEN || '学年';                                                      --小学校転入学学年
            ELSE
              rRECODE.SHOGAKKO_TENNYUGAKU_GAKUNEN  :=    ' ';                                                                                                   --小学校転入学学年
            END IF;
            IF RECGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN > 0 THEN
              rRECODE.SHOGAKKO_TENGAKU_GAKUNEN     :=    RECGAKUREIBO.SYOGAKO_TENGAKU_GAKUNEN || '学年';                                                        --小学校転学学年
            ELSE
              rRECODE.SHOGAKKO_TENGAKU_GAKUNEN     :=   ' ';                                                                                                    --小学校転学学年
            END IF;
            IF RECGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN > 0 THEN
              rRECODE.TYUGAKO_TENNYUGAKU_GAKUNEN   :=    RECGAKUREIBO.TYUGAKO_TENNYUGAKU_GAKUNEN || '学年';                                                    --中学校転入学学年
            ELSE
              rRECODE.TYUGAKO_TENNYUGAKU_GAKUNEN   :=     ' ';                                                                                                 --中学校転入学学年
            END IF;
            IF RECGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN > 0 THEN
              rRECODE.TYUGAKO_TENGAKU_GAKUNEN      :=   RECGAKUREIBO.TYUGAKO_TENGAKU_GAKUNEN || '学年';                                                        --中学校転学学年
            ELSE
              rRECODE.TYUGAKO_TENGAKU_GAKUNEN      :=     ' ';                                                                                                 --中学校転学学年
            END IF;
-- 2024/06/26 ZCZL.wangqiwei Delete start 0.3.000.000:新WizLIFE2次開発の標準化対応
--             IF RECGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN > 0 THEN
--               rRECODE.KUIKIGAI_TENNYUGAKU_GAKUNEN  :=    RECGAKUREIBO.KUIKIGAI_TENNYUGAKU_GAKUNEN || '学年';                                                   --区域外転入学学年
--             ELSE
--               rRECODE.KUIKIGAI_TENNYUGAKU_GAKUNEN  := ' ';                                                                                                     --区域外転入学学年
--             END IF;
--             IF RECGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN > 0 THEN
--               rRECODE.KUIKIGAI_TENGAKU_GAKUNEN     :=   RECGAKUREIBO.KUIKIGAI_TENGAKU_GAKUNEN || '学年';                                                       --区域外転学学年
--             ELSE
--               rRECODE.KUIKIGAI_TENGAKU_GAKUNEN     :=      ' ';                                                                                                --区域外転学学年
--             END IF;
--             IF RECGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN > 0 THEN
--               rRECODE.KUIKIGAI_TAIGAKU_GAKUNEN     :=    RECGAKUREIBO.KUIKIGAI_TAIGAKU_GAKUNEN || '学年';                                                       --区域外退学学年
--             ELSE
--               rRECODE.KUIKIGAI_TAIGAKU_GAKUNEN     :=     ' ';                                                                                                  --区域外退学学年
--             END IF;
--             IF RECGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN > 0 THEN
--               rRECODE.YOGOGAKO_TENNYUGAKU_GAKUNEN  :=     RECGAKUREIBO.YOGOGAKO_TENNYUGAKU_GAKUNEN || '学年';                                                   --盲聾養護転入学学年
--             ELSE 
--               rRECODE.YOGOGAKO_TENNYUGAKU_GAKUNEN  :=     ' ';                                                                                                  --盲聾養護転入学学年
--             END IF;
--             IF RECGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN > 0 THEN
--               rRECODE.YOGOGAKO_TENGAKU_GAKUNEN     :=  RECGAKUREIBO.YOGOGAKO_TENGAKU_GAKUNEN || '学年';                                                         --盲聾養護転学学年
--             ELSE
--               rRECODE.YOGOGAKO_TENGAKU_GAKUNEN     :=   ' ';                                                                                                    --盲聾養護転学学年
--             END IF;
--             IF RECGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN > 0 THEN
--               rRECODE.YOGOGAKO_TAIGAKU_GAKUNEN     :=  RECGAKUREIBO.YOGOGAKO_TAIGAKU_GAKUNEN || '学年';                                                         --盲聾養護退学学年
--             ELSE
--               rRECODE.YOGOGAKO_TAIGAKU_GAKUNEN     :=    ' ';                                                                                                   --盲聾養護退学学年
--             END IF;
-- 2024/06/26 ZCZL.wangqiwei Delete end
            rRECODE.SHUGAKU                      :=   RECGAKUREIBO.SHUGAKU;                                                                                     --就学状況
            rRECODE.IDO_JIKO                     :=   RECGAKUREIBO.IDOJIKO;                                                                                     --異動事項
            rRECODE.KYOIKU_YAKUSHOKU_MEI         :=   ACONSPRM_KYOUIKU(2);                                                                                      --教育委員会役職名
            rRECODE.KYOIKU_SHUCHO_MEI            :=   ACONSPRM_KYOUIKU(3);                                                                                      --教育委員会首長名
            rRECODE.KYOIKU_RITSU_MEI             :=   ACONSPRM_KYOUIKU(4);                                                                                      --教育委員会立名
            IF ACONSPRM_KYOUIKU(5) IS NOT NULL AND LENGTH(ACONSPRM_KYOUIKU(5)) > 3 THEN
              VHOGOSHA_YUBIN_NO := SUBSTR(ACONSPRM_KYOUIKU(5),1,3)||'-'||SUBSTR(ACONSPRM_KYOUIKU(5),4);
              VHOGOSHA_YUBIN_NO := TRANSLATE( VHOGOSHA_YUBIN_NO, '1234567890-', '１２３４５６７８９０−' );
              rRECODE.KYOIKU_YUBIN_NO              := VHOGOSHA_YUBIN_NO;                                                                                        --教育委員会郵便番号
            ELSE
              rRECODE.KYOIKU_YUBIN_NO              :=     ' ';                                                                                                  --教育委員会郵便番号
            END IF;
            rRECODE.KYOIKU_JUSHO                 :=  ACONSPRM_KYOUIKU(6);                                                                                       --教育委員会住所
            rRECODE.KYOIKU_TEL                   :=  ACONSPRM_KYOUIKU(7);                                                                                       --教育委員会電話
            rRECODE.KYOIKU_TEL_NAISEN            :=  ACONSPRM_KYOUIKU(8);                                                                                       --教育委員会電話内線
            rRECODE.JIDO_ZENJUSHO                :=  FUNC_GET_ZENJUSHO(RECGAKUREIBO.KOJIN_NO);                                                                  --児童前住所
            rRECODE.HOGOSHA_ZENJUSHO             :=  FUNC_GET_ZENJUSHO(RECGAKUREIBO.HOGOSYA_KOJIN_NO);                                                          --保護者前住所
-- 2024/07/02 ZCZL.wangqiwei Add start 0.3.000.000:新WizLIFE2次開発の標準化対応
            rRECODE.S_TAIGAKU_BI                 :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.S_TAIGAKU_BI, 0, 3, 0, '*');                                            --小学校退学日
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.S_TAIGAKU_GAKUNEN > 0 THEN
              rRECODE.S_TAIGAKU_GAKUNEN  :=   RECGAKUREIBO.S_TAIGAKU_GAKUNEN || '学年'; 
            ELSE
              rRECODE.S_TAIGAKU_GAKUNEN            :=    ' ';  
              --rRECODE.S_TAIGAKU_GAKUNEN          :=  GKAFKGKNGTEQ(RECGAKUREIBO.S_TAIGAKU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.T_TAIGAKU_BI                 :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.T_TAIGAKU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.T_TAIGAKU_GAKUNEN > 0 THEN
              rRECODE.T_TAIGAKU_GAKUNEN  :=   RECGAKUREIBO.T_TAIGAKU_GAKUNEN || '学年'; 
            ELSE
              rRECODE.T_TAIGAKU_GAKUNEN            :=    ' ';  
            --rRECODE.T_TAIGAKU_GAKUNEN            :=  GKAFKGKNGTEQ(RECGAKUREIBO.T_TAIGAKU_GAKUNEN);
             END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.KUIKIGAI_S_MEI               :=  GKAFKGKOGTEQ(4,RECGAKUREIBO.KUIKIGAI_S_CD);
            rRECODE.KUIKIGAI_S_NYUGAKU_BI        :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.KUIKIGAI_S_NYUGAKU_BI, 0, 3, 0, '*');
            rRECODE.KUIKIGAI_S_TENNYU_BI         :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.KUIKIGAI_S_TENNYU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.KUIKIGAI_S_TENNYU_GAKUNEN > 0 THEN
              rRECODE.KUIKIGAI_S_TENNYU_GAKUNEN   :=   RECGAKUREIBO.KUIKIGAI_S_TENNYU_GAKUNEN || '学年';
            ELSE
              rRECODE.KUIKIGAI_S_TENNYU_GAKUNEN    :=     ' ';  
              --rRECODE.KUIKIGAI_S_TENNYU_GAKUNEN    :=  GKAFKGKNGTEQ(RECGAKUREIBO.KUIKIGAI_S_TENNYU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.KUIKIGAI_S_TENGAKU_BI        :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.KUIKIGAI_S_TENGAKU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.KUIKIGAI_S_TENGAKU_GAKUNEN > 0 THEN
              rRECODE.KUIKIGAI_S_TENGAKU_GAKUNEN := RECGAKUREIBO.KUIKIGAI_S_TENGAKU_GAKUNEN || '学年';
            ELSE
              rRECODE.KUIKIGAI_S_TENGAKU_GAKUNEN   :=     ' ';  
            --rRECODE.KUIKIGAI_S_TENGAKU_GAKUNEN   :=  GKAFKGKNGTEQ(RECGAKUREIBO.KUIKIGAI_S_TENGAKU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.KUIKIGAI_S_TAIGAKU_BI        :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.KUIKIGAI_S_TAIGAKU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.KUIKIGAI_S_TAIGAKU_GAKUNEN > 0 THEN
              rRECODE.KUIKIGAI_S_TAIGAKU_GAKUNEN := RECGAKUREIBO.KUIKIGAI_S_TAIGAKU_GAKUNEN || '学年';
            ELSE
              rRECODE.KUIKIGAI_S_TAIGAKU_GAKUNEN   :=       ' '; 
            --rRECODE.KUIKIGAI_S_TAIGAKU_GAKUNEN   :=  GKAFKGKNGTEQ(RECGAKUREIBO.KUIKIGAI_S_TAIGAKU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.KUIKIGAI_S_SOTSUGYO_BI       :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.KUIKIGAI_S_SOTSUGYO_BI, 0, 3, 0, '*');
            rRECODE.KUIKIGAI_T_MEI               :=  GKAFKGKOGTEQ(4,RECGAKUREIBO.KUIKIGAI_T_CD);
            rRECODE.KUIKIGAI_T_NYUGAKU_BI        :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.KUIKIGAI_T_NYUGAKU_BI, 0, 3, 0, '*');
            rRECODE.KUIKIGAI_T_TENNYU_BI         :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.KUIKIGAI_T_TENNYU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.KUIKIGAI_T_TENNYU_GAKUNEN > 0 THEN
              rRECODE.KUIKIGAI_T_TENNYU_GAKUNEN := RECGAKUREIBO.KUIKIGAI_T_TENNYU_GAKUNEN || '学年';
            ELSE
              rRECODE.KUIKIGAI_T_TENNYU_GAKUNEN    :=        ' '; 
            --rRECODE.KUIKIGAI_T_TENNYU_GAKUNEN    :=  GKAFKGKNGTEQ(RECGAKUREIBO.KUIKIGAI_T_TENNYU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.KUIKIGAI_T_TENGAKU_BI        :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.KUIKIGAI_T_TENGAKU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.KUIKIGAI_T_TENGAKU_GAKUNEN > 0 THEN
              rRECODE.KUIKIGAI_T_TENGAKU_GAKUNEN := RECGAKUREIBO.KUIKIGAI_T_TENGAKU_GAKUNEN || '学年';
            ELSE
              rRECODE.KUIKIGAI_T_TENGAKU_GAKUNEN   :=         ' ';  
            --rRECODE.KUIKIGAI_T_TENGAKU_GAKUNEN   :=  GKAFKGKNGTEQ(RECGAKUREIBO.KUIKIGAI_T_TENGAKU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.KUIKIGAI_T_TAIGAKU_BI        :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.KUIKIGAI_T_TAIGAKU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.KUIKIGAI_T_TAIGAKU_GAKUNEN > 0 THEN
              rRECODE.KUIKIGAI_T_TAIGAKU_GAKUNEN := RECGAKUREIBO.KUIKIGAI_T_TAIGAKU_GAKUNEN || '学年';
            ELSE
              rRECODE.KUIKIGAI_T_TAIGAKU_GAKUNEN   :=          ' ';  
            --rRECODE.KUIKIGAI_T_TAIGAKU_GAKUNEN   :=  GKAFKGKNGTEQ(RECGAKUREIBO.KUIKIGAI_T_TAIGAKU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.KUIKIGAI_T_SOTSUGYO_BI       :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.KUIKIGAI_T_SOTSUGYO_BI, 0, 3, 0, '*');
            rRECODE.SHIEN_S_MEI                  :=  GKAFKGKOGTEQ(3,RECGAKUREIBO.SHIEN_S_CD);
            rRECODE.SHIEN_S_NYUGAKU_BI           :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.SHIEN_S_NYUGAKU_BI, 0, 3, 0, '*');
            rRECODE.SHIEN_S_TENNYU_BI            :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.SHIEN_S_TENNYU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.SHIEN_S_TENNYU_GAKUNEN > 0 THEN
              rRECODE.SHIEN_S_TENNYU_GAKUNEN := RECGAKUREIBO.SHIEN_S_TENNYU_GAKUNEN || '学年';
            ELSE
              rRECODE.SHIEN_S_TENNYU_GAKUNEN       :=           ' ';  
            --rRECODE.SHIEN_S_TENNYU_GAKUNEN       :=  GKAFKGKNGTEQ(RECGAKUREIBO.SHIEN_S_TENNYU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.SHIEN_S_TENGAKU_BI           :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.SHIEN_S_TENGAKU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.SHIEN_S_TENGAKU_GAKUNEN > 0 THEN
              rRECODE.SHIEN_S_TENGAKU_GAKUNEN := RECGAKUREIBO.SHIEN_S_TENGAKU_GAKUNEN || '学年';
            ELSE
              rRECODE.SHIEN_S_TENGAKU_GAKUNEN      :=            ' ';  
            --rRECODE.SHIEN_S_TENGAKU_GAKUNEN      :=  GKAFKGKNGTEQ(RECGAKUREIBO.SHIEN_S_TENGAKU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.SHIEN_S_TAIGAKU_BI           :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.SHIEN_S_TAIGAKU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.SHIEN_S_TAIGAKU_GAKUNEN > 0 THEN
              rRECODE.SHIEN_S_TAIGAKU_GAKUNEN := RECGAKUREIBO.SHIEN_S_TAIGAKU_GAKUNEN || '学年';
            ELSE
              rRECODE.SHIEN_S_TAIGAKU_GAKUNEN      :=           ' ';  
            --rRECODE.SHIEN_S_TAIGAKU_GAKUNEN      :=  GKAFKGKNGTEQ(RECGAKUREIBO.SHIEN_S_TAIGAKU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.SHIEN_S_SOTSUGYO_BI          :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.SHIEN_S_SOTSUGYO_BI, 0, 3, 0, '*');
            rRECODE.SHIEN_T_MEI                  :=  GKAFKGKOGTEQ(3,RECGAKUREIBO.SHIEN_T_CD);
            rRECODE.SHIEN_T_NYUGAKU_BI           :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.SHIEN_T_NYUGAKU_BI, 0, 3, 0, '*');
            rRECODE.SHIEN_T_TENNYU_BI            :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.SHIEN_T_TENNYU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.SHIEN_T_TENNYU_GAKUNEN > 0 THEN
              rRECODE.SHIEN_T_TENNYU_GAKUNEN := RECGAKUREIBO.SHIEN_T_TENNYU_GAKUNEN || '学年';
            ELSE
              rRECODE.SHIEN_T_TENNYU_GAKUNEN       :=             ' ';  
            --rRECODE.SHIEN_T_TENNYU_GAKUNEN       :=  GKAFKGKNGTEQ(RECGAKUREIBO.SHIEN_T_TENNYU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.SHIEN_T_TENGAKU_BI           :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.SHIEN_T_TENGAKU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.SHIEN_T_TENGAKU_GAKUNEN > 0 THEN
              rRECODE.SHIEN_T_TENGAKU_GAKUNEN := RECGAKUREIBO.SHIEN_T_TENGAKU_GAKUNEN || '学年';
            ELSE
               rRECODE.SHIEN_T_TENGAKU_GAKUNEN      :=          ' ';  
            --rRECODE.SHIEN_T_TENGAKU_GAKUNEN      :=  GKAFKGKNGTEQ(RECGAKUREIBO.SHIEN_T_TENGAKU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.SHIEN_T_TAIGAKU_BI           :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.SHIEN_T_TAIGAKU_BI, 0, 3, 0, '*');
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 START 
            IF RECGAKUREIBO.SHIEN_T_TAIGAKU_GAKUNEN > 0 THEN
              rRECODE.SHIEN_T_TAIGAKU_GAKUNEN := RECGAKUREIBO.SHIEN_T_TAIGAKU_GAKUNEN || '学年';
            ELSE
              rRECODE.SHIEN_T_TAIGAKU_GAKUNEN      :=          ' ';  
            --rRECODE.SHIEN_T_TAIGAKU_GAKUNEN      :=  GKAFKGKNGTEQ(RECGAKUREIBO.SHIEN_T_TAIGAKU_GAKUNEN);
            END IF;
--  2025/02/06 JPJYS.GONGYANYAN UPDATE 0.3.000.005:ST_GKB_TMP00044の対応 END 
            rRECODE.SHIEN_T_SOTSUGYO_BI          :=  KKAPK0020.FDAYEDIT20(RECGAKUREIBO.SHIEN_T_SOTSUGYO_BI, 0, 3, 0, '*');
            --児童生徒の基本情報
            I_RTN := GAAPK0030.FGETATENA(RECGAKUREIBO.KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), rGABTATENAKIHON, rGABTSOFUSAKI);
            --抑止区分の判定
            I_RTN := GAAPK0030.FGETDV(RECGAKUREIBO.KOJIN_NO, rGABTATENAKIHON.SETAI_NO, TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), 'GKB', 0,
                                      nKOJINSETAIKBN, nYOKUSHIKBN, nIDOYOKUSHIKBN, nHAKKOYOKUSHIKBN, nSHOKAIYOKUSHIKBN, vSHORICHUIKBN);
--  2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
            --IF nYOKUSHIKBN = 1 OR nYOKUSHIKBN = 2 THEN
            IF 0 < nYOKUSHIKBN AND nYOKUSHIKBN < 99 THEN
--  2025/06/04 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
              rRECODE.TAISYOSYA_KBN := '対象';             --対象者区分
            ELSE 
              rRECODE.TAISYOSYA_KBN := '対象ではない';       --対象者区分
            END IF;
            --支援措置対象者情報取得する
            I_RTN := FUNC_GACTKANRI_WK(RECGAKUREIBO.KOJIN_NO);
            --支援措置対象者情報は登録されている場合
            IF I_RTN = 0 THEN
              FOR i IN 1..ICNT LOOP
                --支援措置申出者管理_申出者情報に情報を登録されている場合
--  2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
                --IF v_TAISHOSHAKBN(i) IS NOT NULL THEN
                IF v_TAISHOSHAKBN(i) IS NOT NULL OR v_SHIENSOCHIKBN(i)IS NOT NULL THEN
--  2025/06/04 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
                  IF v_SHIENSOCHIKAISHIBI(i) IS NOT NULL THEN 
                    nGAITO_KARA := TO_NUMBER(v_SHIENSOCHIKAISHIBI(i));
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00286横展開対応
--                    rRECODE.GAITO_KARA  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(v_SHIENSOCHIKAISHIBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);              --支援措置開始年月日
                    rRECODE.GAITO_KARA  := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(v_SHIENSOCHIKAISHIBI(i)), 12);              --支援措置開始年月日
                  END IF;
                  IF v_KARISHIENSOCHIKAISHIBI(i) <> 99999999 AND v_SHIENSOCHIKAISHIBI(i) IS NULL THEN 
                    nGAITO_KARA := TO_NUMBER(v_KARISHIENSOCHIKAISHIBI(i));
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00286横展開対応
--                    rRECODE.GAITO_KARA  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(v_KARISHIENSOCHIKAISHIBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);          --支援措置開始年月日
                    rRECODE.GAITO_KARA  := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(v_KARISHIENSOCHIKAISHIBI(i)), 12);          --支援措置開始年月日
                  END IF;
                  IF v_SHIENSOCHIKAIJOBI(i) IS NOT NULL THEN
                    nGAITO_MADE := TO_NUMBER(v_SHIENSOCHIKAIJOBI(i));
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00286横展開対応
--                    rRECODE.GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(v_SHIENSOCHIKAIJOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);                --支援措置終了年月日
                    rRECODE.GAITO_MADE := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(v_SHIENSOCHIKAIJOBI(i)), 12);                --支援措置終了年月日
                  END IF;
                  IF v_SHIENSOCHIKAIJOBI(i) IS NULL AND v_SHIENSOCHISHURYOBI(i) <> 99999999 THEN
                    nGAITO_MADE := TO_NUMBER(v_SHIENSOCHISHURYOBI(i));
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00286横展開対応
--                    rRECODE.GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(v_SHIENSOCHISHURYOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);               --支援措置終了年月日
                    rRECODE.GAITO_MADE := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(v_SHIENSOCHISHURYOBI(i)), 12);               --支援措置終了年月日
                  END IF;
                  IF v_SHIENSOCHIKAIJOBI(i) IS NULL AND v_SHIENSOCHISHURYOBI(i) IS NULL AND v_KARISHIENSOCHISHURYOBI(i) <> 99999999 THEN 
                    nGAITO_MADE := TO_NUMBER(v_KARISHIENSOCHISHURYOBI(i));
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00286横展開対応
--                    rRECODE.GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(v_KARISHIENSOCHISHURYOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);            --支援措置終了年月日
                    rRECODE.GAITO_MADE := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(v_KARISHIENSOCHISHURYOBI(i)), 12);            --支援措置終了年月日
                  END IF;
                  IF v_SHIENSOCHIKAIJOBI(i) IS NULL AND v_SHIENSOCHISHURYOBI(i) = 99999999 AND v_KARISHIENSOCHISHURYOBI(i) = 99999999 THEN 
                     rRECODE.GAITO_MADE := NULL;                                                                                                     --支援措置終了年月日
                  END IF;
                  EXIT;
                --支援措置申出者管理_申出者情報に情報を登録されてない場合
                ELSIF v_TOROKU_GYOMU(i) IS NULL THEN
                  nGAITO_KARA := TO_NUMBER(v_SHIENSOCHIKAISHIBI(i));
                  nGAITO_MADE := TO_NUMBER(v_SHIENSOCHISHURYOBI(i));
--  2024/11/02 ZCZL.WANGMING UPDATE 0.3.000.003:IT_GKB_00286横展開対応
--                  rRECODE.GAITO_KARA := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(v_SHIENSOCHIKAISHIBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);            --支援措置開始年月日(その他業務)
--                  rRECODE.GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(v_SHIENSOCHISHURYOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);            --支援措置終了年月日(その他業務)
                  rRECODE.GAITO_KARA := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(v_SHIENSOCHIKAISHIBI(i)), 12);            --支援措置開始年月日(その他業務)
                  rRECODE.GAITO_MADE := KKAPK0020.FDateFmt(GKAPK00020.FGETSTRDATE_SLASH(v_SHIENSOCHISHURYOBI(i)), 12);            --支援措置終了年月日(その他業務)
                END IF;
              END LOOP;
            ELSE
              --支援措置対象者情報で取得できない場合
              rRECODE.GAITO_KARA := NULL;
              rRECODE.GAITO_MADE := NULL;
            END IF;
            IF rRECODE.GAITO_MADE IS NULL AND rRECODE.GAITO_KARA IS NULL THEN
              rRECODE.SHIEN_KBN := NULL;                                                   --支援措置区分
            ELSE
              IF nGAITO_KARA <= TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) AND nGAITO_MADE >= TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) THEN
                rRECODE.SHIEN_KBN := '支援中';                                             --支援措置区分
              END IF;
              IF nGAITO_MADE < TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) THEN
                rRECODE.SHIEN_KBN := '支援終了';                                           --支援措置区分
              END IF;
            END IF;
            rRECODE.YOSHIKI_NO := rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO ;
-- 2024/07/02 ZCZL.wangqiwei Add end
            rRECODE.BREAK_NO                     :=  NULL;                                                                                                      --改ページキー
            rRECODE.WSNUM                        :=  g_sWSNUM;                                                                                                  --端末番号
            rRECODE.BATCHKBN                     :=  c_ONLINE;                                                                                                  --即時バッチ区分
            rRECODE.JOBNUM                       :=  g_nJOBNUM;                                                                                                 --ジョブNO
-- 2024/07/01 ZCZL.wangqiwei Update start 0.3.000.000:新WizLIFE2次開発の標準化対応
--            INSERT INTO GKBWL050R001 VALUES rRECODE;
            FOR i IN 1..g_sHAKOUTEXT LOOP
--  2024/11/15 ZCZL.WANGYUNING ADD START 0.3.000.003:IT_GKB_00539横展開対応
              nROWNUM := nROWNUM + 1;
              rRECODE.NO                           :=      nROWNUM;                                --ソート順
--  2024/11/15 ZCZL.WANGYUNING ADD END
              INSERT INTO GKBWL050R001 VALUES rRECODE;
            END LOOP;
-- 2024/07/01 ZCZL.wangqiwei Update end
            -- 一意的なレコードなので複数回繰り返すことはないので脱出
            EXIT;
        -- ループの終端
        END LOOP;
        -- カーソルを閉じる
        CLOSE GAKUREIBO;
        -- 例外エラー
        EXCEPTION
          -- 該当なし
          WHEN NO_DATA_FOUND THEN
            IF GAKUREIBO%ISOPEN THEN
               CLOSE GAKUREIBO;
            END IF;
            -- 該当なしは正常終了とする
            IFRET := c_ISUCCESS;
          -- その他
          WHEN OTHERS THEN
            IF GAKUREIBO%ISOPEN THEN
               CLOSE GAKUREIBO;
            END IF;
            -- その他エラー
            IFRET := c_INOT_SUCCESS;
            -- SQL情報取得
            o_SqlCode := SQLCODE;
            o_SqlMsg  := SUBSTR(SQLERRM, 1, 250);
            g_sMESSAGE := g_sMESSAGE || o_SqlCode || o_SqlMsg;
        -- 例外エラー終端
        END;
        -- 終了
        RETURN IFRET;
    END FUNC_GET_JIDO_REC;
    --------------------------------------------------------
    --  機能概要      : メインビジネスロジック処理
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        ERR                   EXCEPTION;
    BEGIN
        BEGIN
          -- 関数開始
          bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');
          -- エラーコードの初期化
          o_SqlCode := 0;
          -- エラーメッセージの初期化
          o_SqlMsg := '';
          -- ＣＳＶ作成
          DELETE FROM GKBWL050R001 WHERE  WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
          I_RTN := FUNC_GET_JIDO_REC();
          IF I_RTN <> c_ISUCCESS THEN
            RAISE ERR;
          END IF;
          bRTN := FUNC_O20CSV(i_sGYOUMUCODE,'GKBWL050R001',i_sCHOHYOID);
        EXCEPTION
          -- その他エラー
          WHEN OTHERS THEN
            -- SQL情報取得
            o_SqlCode := SQLCODE;
            o_SqlMsg  := SUBSTR(SQLERRM, 1, 250);
            g_sMESSAGE := g_sMESSAGE || o_SqlCode || o_SqlMsg;
            RAISE ERR;
          END;  
        -- 関数終了
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理終了');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
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
    --  作成者／作成日: ZCZL.ZHANGLEI 2024/01/05
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
END GKBPA00040;
/