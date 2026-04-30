CREATE OR REPLACE PACKAGE BODY GKBPA00020
--1.0.106.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 入学通知書作成（即時）
--  機能概要      : 個人番号と履歴連番をキーにして入学通知書を出力する。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/04
--------------------------------------------------------
--  変更履歴
--  2024/06/03 ZCZL.LIUHUAJUN UPDATE 0.3.000.000:新WizLIFE２次開発
--  2024/09/05 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/10/24 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00089対応
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00433対応  
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00539横展開対応
--  2024/12/05 ZCZL.BUYANAN UPDATE 0.3.000.005:仕様変更　IT_GKB_00719対応
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00724対応
--  2024/12/10 JPJYS.LIZIZHONG UPDATE 0.3.000.007:品質強化IT_GKB_10004故障対応
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化IT_GKB_10003故障対応
--  2024/12/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:仕様変更IT_GKB_10044の対応
--  2024/12/19 JPJYS.SHAXUE UPDATE 0.3.000.010:品質強化IT_GKB_10051故障対応
--  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応
--  2025/01/08 JPJYS.LIJINGHUI UPDATE 0.3.000.012:品質強化IT_GKB_10195対応
--  2025/05/15 CTC.LIUJUNHAO UPDATE 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
--  2025/09/11 CTC.XIAOMINGBO UPDATE 1.0.105.000:GKB_QA20562対応
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
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
    g_NKOJIN_NO                   NUMBER;
    g_NRIREKI_RENBAN              NUMBER;
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--     g_NHASSO_NO                   NUMBER;
--     g_NHASSOBI                    NUMBER;
--     g_NNYUGAKU_KIJITSU            NUMBER;
    g_nCHOHYOKBN                  NUMBER;                      --帳票区分
    g_NHASSOBI                    NUMBER;                      --発送日
    g_nATENAKBN                   NUMBER;                      --宛先
    g_nKYOIKUKAI                  NUMBER;                      --教育委員会
    g_sBUNSHOLIST                 NVARCHAR2(1000);             --文書番号（リスト）
    g_nSHIENSOCHIKBN              NUMBER;                      --支援措置対象住所非表示
    g_nHAKKOSU                    NUMBER;                      --発行部数
    g_sNYUGAKKOMEI                NVARCHAR2(1000);             --入学校名
    g_nNYUGAKUKIJITSU             NVARCHAR2(1000);             --入学期日
    g_nNYUGAKUSHIKIBI             NVARCHAR2(1000);             --入学式日
--  2024/10/24 ZCZL.WANGYUNING UPDATE 0.3.000.002:IT_GKB_00089対応
    --g_nKAISHIJIKAN                NUMBER;                      --開始時間
    --g_nUKETSUKEJIKAN              NUMBER;                      --受付時間
    g_nKAISHIJIKAN                NVARCHAR2(1000);                      --開始時間
    g_nUKETSUKEJIKAN              NVARCHAR2(1000);                      --受付時間
--  2024/10/24 ZCZL.WANGYUNING UPDATE END
    g_sTOKUKIJIKO                 NVARCHAR2(1000);             --特記事項
    g_sBIKO                       NVARCHAR2(1000);             --備考
    g_rBUNNUMSRCINF               KKAPK0040.MR_BUNNUMSRCINF;   --文書番号情報（構造体）
    g_rBUNNUMEDITKEKA             KKAPK0040.MR_BUNNUMEDITKEKA; --文書番号編集結果
    g_rBUNSHONUM                  NVARCHAR2(1000);             --文書番号
    g_aSHIMEIJKN_CHOHYOPRM        A_CONS_PRM;                  --「外国人　氏名・生年月日制御帳票(ID)」のリスト
    g_aEQSHIMEIPRM                A_CONS_PRM;                  --「本名・通称名　出力制御」のリスト
    g_nGKBPA00020_INDEX           NUMBER;                      --入学通知書_インデックス番号
    g_nGKBPA00020_CTL             NUMBER;                      --入学通知書_出力制御
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
    g_NIINKAI                     NUMBER;
    g_VSQLMSG                     NVARCHAR2(1000);
    g_NSQLCODE                    NUMBER;
    -- 処理結果
    c_ISUCCESS                    CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS                CONSTANT  PLS_INTEGER := -1;        -- 異常
    -- 帳票区分
    c_CHOHYO_KBN_S                CONSTANT  PLS_INTEGER := 2;         -- 小学校入学通知
    c_CHOHYO_KBN_T                CONSTANT  PLS_INTEGER := 3;         -- 中学校入学通知
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
    -- ERROR関連 --
    I_RTN           PLS_INTEGER;     -- 戻り値
    -- ＣＳＶファイル操作
    BRTN            BOOLEAN;         -- サブルーチンの戻り値
    ISAKUSEIBI      PLS_INTEGER;
    -- 収発名
    VSYUHATU_MEI    NVARCHAR2(12);
    --公印ファイル名取得
    VGYOMU          NVARCHAR2(100);  --業務毎公印ファイル名
    VTANTO_TEL      NVARCHAR2(60);
    VDATE_MEI1      NVARCHAR2(40);
    VDATE_MEI2      NVARCHAR2(40);
    VDATE_MEI3      NVARCHAR2(40);
    VDATE_MEI4      NVARCHAR2(40);
    VDATE_MEI5      NVARCHAR2(40);
    VKOMOKU_MEI1    NVARCHAR2(40);
    VKOMOKU_MEI2    NVARCHAR2(40);
    VKOMOKU_MEI3    NVARCHAR2(40);
    VKOMOKU_MEI4    NVARCHAR2(40);
    VKOMOKU_MEI5    NVARCHAR2(40);
    VKOMOKU_MEI6    NVARCHAR2(40);
    VKOMOKU_MEI7    NVARCHAR2(40);
    VKOMOKU_MEI8    NVARCHAR2(40);
    VKOMOKU_MEI9    NVARCHAR2(40);
    VKOMOKU_MEI10   NVARCHAR2(40);
    -- 宛名情報取得用
    RATENA_HOGOSHA GABTATENAKIHON%ROWTYPE;
    RSOFU_HOGOSHA  GABTSOFUSAKI%ROWTYPE;
    -- 児童宛名情報取得用
    RATENA_JIDO    GABTATENAKIHON%ROWTYPE;
    RSOFU_JIDO     GABTSOFUSAKI%ROWTYPE;
    NNENDO         PLS_INTEGER;
    VHYOUJINENDO   NVARCHAR2(30);
    ISIMEYISYUTURYOKUSEGYO             PLS_INTEGER;      -- 宛先の氏名出力制御
    IKYOUIKUIINKAIJOUHOU               PLS_INTEGER;      -- 教育委員会情報
    ICHOUHYOURENBANINZIKOUMOKU         PLS_INTEGER;      -- 帳票連番印字項目制御
    VACONSPRM1                         A_CONS_PRM;       -- パラメータの配列1
    NLENGTH1                           NUMBER;           -- パラメータの配列の長度1
    VACONSPRM2                         A_CONS_PRM;       -- パラメータの配列2
    NLENGTH2                           NUMBER;           -- パラメータの配列の長度2
    VACONSPRM3                         A_CONS_PRM;       -- パラメータの配列3
    NLENGTH3                           NUMBER;           -- パラメータの配列の長度3
    GYOSEIKUMEI                        NVARCHAR2(15);
    ATESAKI_JODAN                      NVARCHAR2(110);   
    ATESAKI_GEDAN                      NVARCHAR2(110);   
    GAKOKU_CD                          NUMBER;
    ATESAKI_YUBIN_NO                   NVARCHAR2(10);
    ATESAKI_YUBIN_NOBC                 NVARCHAR2(30);
    ATESAKI_CHOMEI                     NVARCHAR2(40);
    ATESAKI_BANCHI                     NVARCHAR2(40);
    ATESAKI_KATAGAKI                   NVARCHAR2(60);
    VTANTO_YAKUSHOKU_MEI               NVARCHAR2(60);
    VTANTO_SHUTHOU_MEI                 NVARCHAR2(60);
    VTANTO_RITSU_MEI                   NVARCHAR2(60);
    VTANTO_YUBIN                       NVARCHAR2(60);
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応    
    --VTANTO_JUSHO                       NVARCHAR2(60);
    VTANTO_JUSHO                       NVARCHAR2(100);
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
    VTANTO_TEL_NAISEN                  NVARCHAR2(60);
    HYOJI_CHOHYO_NO                    NVARCHAR2(90);    
    NCHOHYO_NO2                        NVARCHAR2(6);     -- 表示連番
    VGAKOKU_CD2                        NVARCHAR2(5);     -- 学校コード
    HASSOBI                            PLS_INTEGER;
    NSHIMEI_KANJI                      NVARCHAR2(110);       --氏名漢字
    o_SHIMEIPRM                        A_CONS_PRM;           --氏名印字.制御ﾊﾟﾗﾒｰﾀ
    o_LENGTH                           NUMBER;
    BPRMFLG_001                        BOOLEAN;
    BPRMFLG_002                        BOOLEAN;
    BPRMFLG_003                        BOOLEAN;
    BPRMFLG_004                        BOOLEAN;
    o_YMD2                             NVARCHAR2(30);
    N_NAIYO_CD                         GKBTSHIMEIJKN.NAIYO_CD%TYPE;
    KYOIKUKAI_RENRAKUSAKI NVARCHAR2(100);
--  2024/09/05 ZCZL.WANGMING ADD 0.3.000.001:8月1日認識合わせの横展開
    g_sDATEED                   NVARCHAR2(1000);             --発付年月日変数
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00724対応 START
    NYUGAKUSHIKIBI_OUT                  NVARCHAR2(100);  
    NYUGAKUKIJITSU_OUT                  NVARCHAR2(100);
    --  2024/12/19 JPJYS.SHAXUE UPDATE 0.3.000.010:品質強化IT_GKB_10051故障対応　START
    n_HASSOBI                           NVARCHAR2(100);
    --  2024/12/19 JPJYS.SHAXUE UPDATE 0.3.000.010:品質強化IT_GKB_10051故障対応　END 
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00724対応 END
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
--2024/06/03 ZCZL.LIUHUAJUN UPDATE 0.3.000.000:新WizLIFE２次開発
--     CURSOR GAKUREIBO(p_NKOJIN_NO IN NUMBER, p_NRIREKI_RENBAN IN NUMBER) IS
    CURSOR GAKUREIBO IS
      SELECT A.HOGOSYA_KOJIN_NO,     --保護者個人番号
--2024/06/03 ZCZL.LIUHUAJUN ADD 0.3.000.000:新WizLIFE２次開発
             A.KOJIN_NO,
             A.SYOGAKO_CD,
             A.TYUGAKO_CD,
             A.ZOKUGARA1,
             A.ZOKUGARA2,
             A.ZOKUGARA3,
             A.ZOKUGARA4,
             A.HOGOSYA_ZOKUGARA1,
             A.HOGOSYA_ZOKUGARA2,
             A.HOGOSYA_ZOKUGARA3,
             A.HOGOSYA_ZOKUGARA4,
             NVL(B1.SHIMEI_KANJI,' ') SHIMEI_KANJI,
             NVL(B1.SEINENGAPI,0) SEINENGAPI,
             NVL(B1.SEIBETSU,0) SEIBETSU,
             NVL(B1.SHIMEI_KANA,' ') SHIMEI_KANA,
             NVL(B2.SHIMEI_KANA,' ') HOGOSYA_SHIMEI_KANA,
             NVL(B2.SHIMEI_KANJI,' ') HOGOSYA_SHIMEI_KANJI,
             NVL(C1.DATE1,0) IDATE11,
             NVL(C1.DATE2,0) IDATE12,
             NVL(C1.DATE3,0) IDATE13,
             NVL(C1.DATE4,0) IDATE14,
             NVL(C1.DATE5,0) IDATE15,
             NVL(C1.KOMOKU1,' ') VKOMOKU11,
             NVL(C1.KOMOKU2,' ') VKOMOKU12,
             NVL(C1.KOMOKU3,' ') VKOMOKU13,
             NVL(C1.KOMOKU4,' ') VKOMOKU14,
             NVL(C1.KOMOKU5,' ') VKOMOKU15,
             NVL(C1.KOMOKU6,' ') VKOMOKU16,
             NVL(C1.KOMOKU7,' ') VKOMOKU17,
             NVL(C1.KOMOKU8,' ') VKOMOKU18,
             NVL(C1.KOMOKU9,' ') VKOMOKU19,
             NVL(C1.KOMOKU10,' ') VKOMOKU110,
             NVL(C2.DATE1,0) IDATE21,
             NVL(C2.DATE2,0) IDATE22,
             NVL(C2.DATE3,0) IDATE23,
             NVL(C2.DATE4,0) IDATE24,
             NVL(C2.DATE5,0) IDATE25,
             NVL(C2.KOMOKU1,' ') VKOMOKU21,
             NVL(C2.KOMOKU2,' ') VKOMOKU22,
             NVL(C2.KOMOKU3,' ') VKOMOKU23,
             NVL(C2.KOMOKU4,' ') VKOMOKU24,
             NVL(C2.KOMOKU5,' ') VKOMOKU25,
             NVL(C2.KOMOKU6,' ') VKOMOKU26,
             NVL(C2.KOMOKU7,' ') VKOMOKU27,
             NVL(C2.KOMOKU8,' ') VKOMOKU28,
             NVL(C2.KOMOKU9,' ') VKOMOKU29,
             NVL(C2.KOMOKU10,' ') VKOMOKU210,
             NVL(G.SYOGAKOMEI,' ') GAKOKUMEI,
             A.CHOHYO_NO NCHOHYO_NO,
--2024/06/03 ZCZL.LIUHUAJUN ADD 0.3.000.000:新WizLIFE２次開発
             A.GAKKO_KBN_CD GAKKO_KBN_CD,
             B1.GYOSEIKU_CD,
             B1.SANTEIDANTAI_CD
        FROM GKBTGAKUREIBO A,
             GABTATENAKIHON B1,
             GABTATENAKIHON B2,
             GKBTTSUCHISHOJKN C1,
             GKBTTSUCHISHOJKN C2,
             GKBTSHOGAKKO G,
             GKBTCHUGAKKO H
       WHERE A.HOGOSYA_KOJIN_NO = B2.KOJIN_NO(+)
         AND A.SYOGAKO_CD = G.SYOGAKO_CD(+)
         AND A.TYUGAKO_CD = H.TYUGAKO_CD(+)
--2024/06/28 ZCZL.QINYUE ADD 0.3.000.000:新WizLIFE２次開発
         AND A.RIREKI_RENBAN = g_NRIREKI_RENBAN
--2024/06/03 ZCZL.LIUHUAJUN UPDATE 0.3.000.000:新WizLIFE２次開発
--          AND C1.CHOHYO_KBN(+) = c_CHOHYO_KBN_S
         AND C1.CHOHYO_KBN(+) = g_nCHOHYOKBN
         AND A.SYOGAKO_CD = C1.GAKO_CD(+)
--2024/06/03 ZCZL.LIUHUAJUN UPDATE 0.3.000.000:新WizLIFE２次開発
--          AND C2.CHOHYO_KBN(+) = c_CHOHYO_KBN_T
         AND C2.CHOHYO_KBN(+) = g_nCHOHYOKBN
         AND A.TYUGAKO_CD = C2.GAKO_CD(+)
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--          AND A.RIREKI_RENBAN = p_NRIREKI_RENBAN
--          AND B1.KOJIN_NO = p_NKOJIN_NO
         AND A.RIREKI_RENBAN = g_NRIREKI_RENBAN
         AND B1.KOJIN_NO = g_NKOJIN_NO
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
         AND B1.KOJIN_NO = A.KOJIN_NO(+);
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/04
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/04
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/04
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
                     g_NKOJIN_NO         := aCSV_TBL(i);         -- 個人番号
                WHEN 2 THEN
                     g_NRIREKI_RENBAN    := aCSV_TBL(i);         -- 履歴連番
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--                 WHEN 3 THEN
--                      g_NHASSO_NO         := aCSV_TBL(i);         -- 発送番号
--                 WHEN 4 THEN
--                      g_NHASSOBI          := aCSV_TBL(i);         -- 発送日
--                 WHEN 5 THEN
--                      g_NNYUGAKU_KIJITSU  := aCSV_TBL(i);         -- 入学期日
--                 WHEN 6 THEN
--                      g_NIINKAI           := aCSV_TBL(i);         -- 教育委員会の連番
                WHEN 3 THEN
                     g_nCHOHYOKBN        := aCSV_TBL(i);         -- 帳票区分
                WHEN 4 THEN
                     g_NHASSOBI          := aCSV_TBL(i);         -- 発送日
                WHEN 5 THEN
                     g_nATENAKBN         := aCSV_TBL(i);         -- 宛先
                WHEN 6 THEN
                     g_nKYOIKUKAI        := aCSV_TBL(i);         -- 教育委員会
                WHEN 7 THEN
                     g_sBUNSHOLIST       := aCSV_TBL(i);         -- 文書番号（リスト）
                WHEN 8 THEN
                     g_nSHIENSOCHIKBN    := aCSV_TBL(i);         -- 支援措置対象住所非表示
                WHEN 9 THEN
                     g_nHAKKOSU          := aCSV_TBL(i);         -- 発行部数
                WHEN 10 THEN
                     g_sNYUGAKKOMEI      := aCSV_TBL(i);         -- 入学校名
                WHEN 11 THEN
 --  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00724対応  START                 
                     --g_nNYUGAKUKIJITSU   := aCSV_TBL(i);         -- 入学期日
                     g_nNYUGAKUKIJITSU   := TO_NUMBER(aCSV_TBL(i));         
                WHEN 12 THEN
                     --g_nNYUGAKUSHIKIBI   := aCSV_TBL(i);         -- 入学式日
                     g_nNYUGAKUSHIKIBI   := TO_NUMBER(aCSV_TBL(i)); 
 --  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00724対応  END    
                WHEN 13 THEN               
                     g_nKAISHIJIKAN      := aCSV_TBL(i);         -- 開始時間
                WHEN 14 THEN
                     g_nUKETSUKEJIKAN    := aCSV_TBL(i);         -- 受付時間
                WHEN 15 THEN
                     g_sTOKUKIJIKO       := aCSV_TBL(i);         -- 特記事項
                WHEN 16 THEN
                     g_sBIKO             := aCSV_TBL(i);         -- 備考
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/04
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/04
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
    --------------------------------------------------------------------------------------------------
    -- 教育委員会連絡先を取得
    --------------------------------------------------------------------------------------------------
    FUNCTION GET_EQRENRAKUSAKI(i_SEIGYORENBAN IN NUMBER
                              ,i_EQNAME       IN GKBWJIDOSHINDAN.KYOIKUKAI_MEI%TYPE
                              ,i_EQTELNO      IN GKBWJIDOSHINDAN.KYOIKU_TEL%TYPE
                              ,i_EQNAISENNO   IN GKBWJIDOSHINDAN.KYOIKU_TEL_NAISEN%TYPE) RETURN VARCHAR2 IS
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応                     
      --EQRENRAKUSAKI  NVARCHAR2(100);  --教育委員会連絡先
      EQRENRAKUSAKI  NVARCHAR2(1000);  --教育委員会連絡先
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
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
    --------------------------------------------------------------------------------
    -- 市町村名取得
    --------------------------------------------------------------------------------
    PROCEDURE PROC_GET_USER(o_USERMEI OUT NVARCHAR2) IS
    -- 共通情報取得用変数(KKAPK0030.FKYOTU)
      i_IKIJYUNBI                 PLS_INTEGER;
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
    BEGIN
      i_IKIJYUNBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
      I_RTN := KKAPK0030.FKYOTU(i_IKIJYUNBI, 
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
                                o_VTEL_NO
                                );
      o_USERMEI := o_VUSERMEI;
    END PROC_GET_USER;
    --------------------------------------------------------------------------------
    -- 日付変換
    --------------------------------------------------------------------------------
    PROCEDURE PROC_GET_YMD(i_YMD IN NUMBER, o_YMD OUT NVARCHAR2) IS
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
      BRTN:=KKAPK0020.FDAYEDIT(io_WAREKIHIZUKE,
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
        o_YMD := o_EDIT_GYYMMDD3;
      ELSE
        o_YMD := ' ';
      END IF;
    END PROC_GET_YMD;
--2024/06/03 ZCZL.LIUHUAJUN DELETE START 0.3.000.000:新WizLIFE２次開発
/*
    --------------------------------------------------------------------------------
    -- 制御のフラグをセットするのを行う
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
           AND CHOHYO_ID = 'GKB030R001';
        IF o_NAIYO_CD = 0 THEN
          ZERO_FLG  := TRUE;
        END IF;
      EXCEPTION
        --データを取得しない場合
        WHEN NO_DATA_FOUND THEN
        NODATAFOUND_FLG  := TRUE;
      END;
      --氏名印字.制御ﾊﾟﾗﾒｰﾀ(6)が1の場合
      IF o_SHIMEIPRM(6) = 1 THEN
        BPRMFLG_001  := TRUE;
      END IF;
      --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(6)が4、6場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(6) IN (4, 6) THEN
          BPRMFLG_002  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在する、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(6)が3、4、5、6場合
      IF NOT NODATAFOUND_FLG AND NOT ZERO_FLG THEN
        IF o_SHIMEIPRM(6) IN(3,4,5,6) THEN
          BPRMFLG_003  := TRUE;
        END IF;
      END IF;
        -- 本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(6)が4、5場合「生年月日」
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(6) IN (4, 5) THEN
          BPRMFLG_004  := TRUE;
        END IF;
      END IF;
    RETURN 0;
    END;
      --------------------------------------------------------------------------------
      -- 日付変換2
      --------------------------------------------------------------------------------
      PROCEDURE PROC_GET_YMD1(i_KBN IN NUMBER,i_YMD IN NUMBER, o_YMD OUT NVARCHAR2) IS
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
                I_RTN := GKBPK00010.FYMDEDT1(i_YMD,o_YMD,o_YMD2);
                o_YMD    := o_YMD2;  
              ELSIF BPRMFLG_003 THEN
                -- 和暦で表示生年月日
                IF N_NAIYO_CD IN(11,21) THEN
                  o_YMD    := o_EDIT_GYYMMDD3;      
                -- 西暦で表示生年月日
                ELSIF N_NAIYO_CD IN(12,22) THEN
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
    --------------------------------------------------------------------------------
    -- 制御を行う
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
--2024/06/03 ZCZL.LIUHUAJUN DELETE END
    --------------------------------------------------------------------------------
    -- レコードの作成
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC RETURN NUMBER IS
      -- カーソル定義
      RECGAKUREIBO         GAKUREIBO%ROWTYPE;
      -- ループ用
      -- 戻り値
      IFRET                PLS_INTEGER;
--2024/06/03 ZCZL.LIUHUAJUN DELETE START 0.3.000.000:新WizLIFE２次開発      
      -- 児童生年月日
--       JIDO_BTH_IN          PLS_INTEGER;
      -- 出力用児童生年月日
--       JIDO_BTH_OUT         NVARCHAR2(11);
      -- 出力用入学期日
--      NYUGAKUKIJITU_OUT    NVARCHAR2(11);
--2024/06/03 ZCZL.LIUHUAJUN DELETE END
      -- 出力用発送日
      HASSOBI_OUT          NVARCHAR2(11);
      -- 出力用郵便番号
      YUBIN_NO_OUT         NVARCHAR2(10);
      VYUBIN_NOBC          NVARCHAR2(30);  --郵便番号BC
      VCHOMEI              NVARCHAR2(40);  --町名
      VBANCHI              NVARCHAR2(40);  --番地
      VKATAGAKI            NVARCHAR2(60);  --方書
      VJIDO_YUBIN_NO       NVARCHAR2(10);  -- 郵便番号
      VJIDO_YUBIN_NOBC     NVARCHAR2(30);  -- 郵便番号BC
      VJIDO_CHOMEI         NVARCHAR2(40);  -- 町名
      VJIDO_BANCHI         NVARCHAR2(40);  -- 番地
      VJIDO_KATAGAKI       NVARCHAR2(60);  -- 方書
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_00003対応 START
      VSOFU_ATENA          NVARCHAR2(100); -- 送付先宛名
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_00003対応 END
      -- 日付
      DATE_IN              PLS_INTEGER;
      -- 出力用日付
      DATE1_OUT            NVARCHAR2(11);
      DATE2_OUT            NVARCHAR2(11);
      DATE3_OUT            NVARCHAR2(11);
      DATE4_OUT            NVARCHAR2(11);
      DATE5_OUT            NVARCHAR2(11);
      -- 出力用項目
      KOMOKU1_OUT          NVARCHAR2(120);
      KOMOKU2_OUT          NVARCHAR2(120);
      KOMOKU3_OUT          NVARCHAR2(120);
      KOMOKU4_OUT          NVARCHAR2(120);
      KOMOKU5_OUT          NVARCHAR2(120);
      KOMOKU6_OUT          NVARCHAR2(120);
      KOMOKU7_OUT          NVARCHAR2(120);
      KOMOKU8_OUT          NVARCHAR2(120);
      KOMOKU9_OUT          NVARCHAR2(120);
      KOMOKU10_OUT         NVARCHAR2(120);
      -- 市町村名
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
      --USER_MEI             NVARCHAR2(40);
      USER_MEI             NVARCHAR2(100);
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
      VSEIBETSU            NVARCHAR2(1);     --表示用性別
      VZOKUGARAMEI1        NVARCHAR2(30);    --続柄名１
      VZOKUGARAMEI2        NVARCHAR2(30);    --続柄名２
      IRTNZOKUGARA1        PLS_INTEGER;
      IRTNZOKUGARAHERR1    PLS_INTEGER;
      IRTNZOKUGARA2        PLS_INTEGER;
      IRTNZOKUGARAHERR2    PLS_INTEGER;
      o_nDAIRIKBN          NVARCHAR2(1000);
      o_vKATAGAKI1         NVARCHAR2(1000);
      o_vKATAGAKI2         NVARCHAR2(1000);
      o_vSHIMEI            NVARCHAR2(1000);
      o_vKOINFILENAME      NVARCHAR2(1000);
      rRECODE1             GKBWL030R001%ROWTYPE;
      nROWNUM              NUMBER := 0;
--2024/06/03 ZCZL.LIUHUAJUN ADD START 0.3.000.000:新WizLIFE２次開発
      o_vSHIMEIKANA        GKBWL030R001.JIDO_SHIMEI_KANA%TYPE;
      o_vSHIMEIKANJI       GKBWL030R001.JIDO_SHIMEI_KANJI%TYPE;
      o_vBIRTHDAY          GKBWL030R001.HYOJI_SEINENGAPI%TYPE;
      o_vSHIMEIKANA_H      GKBWL030R001.HOGOSHA_SHIMEI_KANA%TYPE;
      o_vSHIMEIKANJI_H     GKBWL030R001.HOGOSHA_SHIMEI_KANJI%TYPE; 
      o_vBIRTHDAY_H        GKBWL030R001.HYOJI_SEINENGAPI%TYPE;
      io_vYUBIN_NO         GKBWL030R001.YUBIN_NO%TYPE;
      vJYUSHO              NVARCHAR2(400);
--  2024/09/05 ZCZL.WANGMING ADD 0.3.000.001:8月1日認識合わせの横展開
      vJYUSHO1             NVARCHAR2(400);
      nHANTEIKEKKA         PLS_INTEGER;
      vKOIN_SHORYAKU           GKBTTSUCHISHOKANRI.KOIN_SHORYAKU%TYPE;
      vKOIN_CHUSHAKU           GKBTTSUCHISHOKANRI.KOIN_CHUSHAKU%TYPE;
      vTSUCHIBUN               GKBTTSUCHISHOKANRI.TSUCHIBUN%TYPE;
      vCHOHYO_MEI              GKBTTSUCHISHOKANRI.CHOHYO_MEI%TYPE;
      vBIKO_TITLE              GKBTTSUCHISHOKANRI.BIKO_TITLE%TYPE;
      vYOSHIKI_BANGO_SETTOGO   GKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETTOGO%TYPE;
      vYOSHIKI_BANGO           GKBTTSUCHISHOKANRI.YOSHIKI_BANGO%TYPE;
      vYOSHIKI_BANGO_SETSUBIGO GKBTTSUCHISHOKANRI.YOSHIKI_BANGO_SETSUBIGO%TYPE;
--2024/06/03 ZCZL.LIUHUAJUN ADD END
    BEGIN
      -- 正常終了
      IFRET := c_ISUCCESS;
      BEGIN
        -- 教育委員会電話番号取得
        VTANTO_TEL := VACONSPRM2(7);
        -- カーソルのオープン
--2024/06/03 ZCZL.LIUHUAJUN UPDATE 0.3.000.000:新WizLIFE２次開発
--        OPEN GAKUREIBO(g_NKOJIN_NO, g_NRIREKI_RENBAN);
        OPEN GAKUREIBO;
        -- レコード参照
        FETCH GAKUREIBO INTO RECGAKUREIBO;
        -- ループ開始
        LOOP
          -- 読むレコードが無い場合ループから抜け出す
          EXIT WHEN GAKUREIBO%NOTFOUND;
          -- 保護者宛名情報取得
          IF g_NHASSOBI > 0 THEN
            I_RTN := GAAPK0030.FGETATENA(RECGAKUREIBO.HOGOSYA_KOJIN_NO, 'GKB', g_NHASSOBI,
                                       RATENA_HOGOSHA, RSOFU_HOGOSHA);
          ELSE
            I_RTN := GAAPK0030.FGETATENA(RECGAKUREIBO.HOGOSYA_KOJIN_NO, 'GKB', ISAKUSEIBI,
                                       RATENA_HOGOSHA, RSOFU_HOGOSHA);
          END IF;
          -- 児童宛名情報取得
          IF g_NHASSOBI > 0 THEN
            I_RTN := GAAPK0030.FGETATENA(g_NKOJIN_NO, 'GKB', g_NHASSOBI,
                                       RATENA_JIDO, RSOFU_JIDO);
          ELSE
            I_RTN := GAAPK0030.FGETATENA(g_NKOJIN_NO, 'GKB', ISAKUSEIBI,
                                       RATENA_JIDO, RSOFU_JIDO);
          END IF;
--2024/06/03 ZCZL.LIUHUAJUN DELETE START 0.3.000.000:新WizLIFE２次開発
--          I_RTN  := FUNC_PRMFLGSET(RATENA_JIDO.KOJIN_NO,N_NAIYO_CD);
--          -- 児童生年月日の取得
--          JIDO_BTH_IN := RECGAKUREIBO.SEINENGAPI;
--          -- 出力用児童生年月日の取得
--          PROC_GET_YMD(JIDO_BTH_IN, JIDO_BTH_OUT);
--          IF (RATENA_JIDO.JINKAKU_KBN != 0) THEN
--              PROC_GET_YMD1(RATENA_JIDO.JINKAKU_KBN,JIDO_BTH_IN, JIDO_BTH_OUT);
--          END IF;
--          -- 入学期日の取得
--          PROC_GET_YMD(g_NNYUGAKU_KIJITSU, NYUGAKUKIJITU_OUT);
--          NNENDO := KKAPK0020.FDAYNENDO(g_NNYUGAKU_KIJITSU,0);
--          -- 入学期日の取得
--          NNENDO := KKAPK0020.FDAYNENDO(g_nNYUGAKUKIJITSU,0);
--2024/06/03 ZCZL.LIUHUAJUN DELETE END
          IF NVL(NNENDO,0) = 0 THEN
            VHYOUJINENDO := '';
          ELSE
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--            PROC_GET_YMD(NNENDO * 10000 + 401,VHYOUJINENDO);
--            VHYOUJINENDO := SUBSTR(VHYOUJINENDO,1,4);
            VHYOUJINENDO := SUBSTR(g_nNYUGAKUKIJITSU,1,4);
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
          END IF;
          -- 発送日の取得
          PROC_GET_YMD(g_NHASSOBI, HASSOBI_OUT);
          --市町村名の取得
          PROC_GET_USER(USER_MEI);
          --郵便番号
          IF RSOFU_HOGOSHA.KOJIN_NO > 0 AND
             (RSOFU_HOGOSHA.TEKIYO_BI <= HASSOBI) AND
             ((RSOFU_HOGOSHA.SHURYO_BI >= HASSOBI) OR (RSOFU_HOGOSHA.SHURYO_BI = 0)) THEN
            IF LENGTH(RSOFU_HOGOSHA.YUBIN_NO) > 0 THEN
              YUBIN_NO_OUT := SUBSTR(RSOFU_HOGOSHA.YUBIN_NO,1,3)||'-'||SUBSTR(RSOFU_HOGOSHA.YUBIN_NO,4);
              YUBIN_NO_OUT := TRANSLATE(YUBIN_NO_OUT, '1234567890-', '１２３４５６７８９０－');  
            ELSE
              YUBIN_NO_OUT := NULL;
            END IF;
            VYUBIN_NOBC := RSOFU_HOGOSHA.YUBIN_NOBC;
            VCHOMEI     := RSOFU_HOGOSHA.CHOMEI;
            VBANCHI     := RSOFU_HOGOSHA.BANCHI;
            VKATAGAKI   := RSOFU_HOGOSHA.KATAGAKI;
          ELSE
            IF LENGTH(RATENA_HOGOSHA.YUBIN_NO) > 0 THEN
              YUBIN_NO_OUT := SUBSTR(RATENA_HOGOSHA.YUBIN_NO,1,3)||'-'||SUBSTR(RATENA_HOGOSHA.YUBIN_NO,4);
              YUBIN_NO_OUT := TRANSLATE(YUBIN_NO_OUT, '1234567890-', '１２３４５６７８９０－');  
            ELSE
              YUBIN_NO_OUT := NULL;
            END IF;
            VYUBIN_NOBC := RATENA_HOGOSHA.YUBIN_NOBC;
            VCHOMEI     := RATENA_HOGOSHA.CHOMEI;
            VBANCHI     := RATENA_HOGOSHA.BANCHI;
            VKATAGAKI   := RATENA_HOGOSHA.KATAGAKI;
          END IF;
          IF RSOFU_JIDO.KOJIN_NO > 0 AND
             (RSOFU_JIDO.TEKIYO_BI <= HASSOBI) AND
             ((RSOFU_JIDO.SHURYO_BI >= HASSOBI) OR (RSOFU_JIDO.SHURYO_BI = 0)) THEN
            IF LENGTH(RSOFU_JIDO.YUBIN_NO) > 0 THEN
              VJIDO_YUBIN_NO := SUBSTR(RSOFU_JIDO.YUBIN_NO,1,3)||'-'||SUBSTR(RSOFU_JIDO.YUBIN_NO,4);
              VJIDO_YUBIN_NO := TRANSLATE(VJIDO_YUBIN_NO, '1234567890-', '１２３４５６７８９０－');
            ELSE
              VJIDO_YUBIN_NO := NULL;
            END IF;
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
            --VJIDO_YUBIN_NOBC := RSOFU_JIDO.YUBIN_NOBC;
            --VJIDO_CHOMEI     := RSOFU_JIDO.CHOMEI;
            --VJIDO_BANCHI     := RSOFU_JIDO.BANCHI;
            --VJIDO_KATAGAKI   := RSOFU_JIDO.KATAGAKI;
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END
          ELSE
            IF LENGTH(RATENA_JIDO.YUBIN_NO) > 0 THEN
              VJIDO_YUBIN_NO := SUBSTR(RATENA_JIDO.YUBIN_NO,1,3)||'-'||SUBSTR(RATENA_JIDO.YUBIN_NO,4);
              VJIDO_YUBIN_NO := TRANSLATE(VJIDO_YUBIN_NO, '1234567890-', '１２３４５６７８９０－');
            ELSE
              VJIDO_YUBIN_NO := NULL;
            END IF;
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
            --VJIDO_YUBIN_NOBC := RATENA_JIDO.YUBIN_NOBC;
            --VJIDO_CHOMEI     := RATENA_JIDO.CHOMEI;
            --VJIDO_BANCHI     := RATENA_JIDO.BANCHI;
            --VJIDO_KATAGAKI   := RATENA_JIDO.KATAGAKI;
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END
          END IF;
          --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
            VJIDO_YUBIN_NOBC := RATENA_JIDO.YUBIN_NOBC;
            VJIDO_CHOMEI     := RATENA_JIDO.CHOMEI;
            VJIDO_BANCHI     := RATENA_JIDO.BANCHI;
            VJIDO_KATAGAKI   := RATENA_JIDO.KATAGAKI;
          --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END
          IRTNZOKUGARA1 := GKBFKZKGMGET(1,
                                        RECGAKUREIBO.ZOKUGARA1,
                                        RECGAKUREIBO.ZOKUGARA2,
                                        RECGAKUREIBO.ZOKUGARA3,
                                        RECGAKUREIBO.ZOKUGARA4,
                                        VZOKUGARAMEI1,
                                        IRTNZOKUGARAHERR1);
          IRTNZOKUGARA2 := GKBFKZKGMGET(2,
                                        RECGAKUREIBO.HOGOSYA_ZOKUGARA1,
                                        RECGAKUREIBO.HOGOSYA_ZOKUGARA2,
                                        RECGAKUREIBO.HOGOSYA_ZOKUGARA3,
                                        RECGAKUREIBO.HOGOSYA_ZOKUGARA4,
                                        VZOKUGARAMEI2,
                                        IRTNZOKUGARAHERR2);
          -- ＣＳＶ出力用変数の初期化
          rRECODE1                   :=   NULL                   ;
--  2024/11/15 ZCZL.WANGYUNING UPDATE START 0.3.000.004:IT_GKB_00539横展開対応
          --nROWNUM                    :=   nROWNUM + 1            ;
          --rRECODE1.NO                :=   nROWNUM                ;-- ソート順
--  2024/11/15 ZCZL.WANGYUNING UPDATE END
          -- 連番
          rRECODE1.NENDO             :=   VHYOUJINENDO           ;
          rRECODE1.KAIPAGE_CD        :=   NULL                   ;
          rRECODE1.KAIPAGE_MEI       :=   NULL                   ;
          rRECODE1.KIJUNBI           :=   NULL                   ;
          rRECODE1.RENBAN            :=   1                      ;

--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--          -- 児童氏名かな
--          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
--            I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANA,RATENA_JIDO.SHIMEI_KANA,RECGAKUREIBO.SHIMEI_KANA);
--          END IF;
--          rRECODE1.JIDO_SHIMEI_KANA := RECGAKUREIBO.SHIMEI_KANA;                                   --児童氏名かな
--
--          -- 児童氏名漢字
--          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
--            I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,RECGAKUREIBO.SHIMEI_KANJI);
--          END IF;
--          rRECODE1.JIDO_SHIMEI_KANJI    := RECGAKUREIBO.SHIMEI_KANJI;                                --児童生徒氏名漢字
--          rRECODE1.HYOJI_SEINENGAPI     := NULL;                                                     --表示生年月日
          -- 児童生徒の本名使用制御判定
          I_RTN := GKBFKHMCTRL(RECGAKUREIBO.KOJIN_NO, g_rOPRT.CHOHYOID, 0, g_nGKBPA00020_CTL, o_vSHIMEIKANA, o_vSHIMEIKANJI, o_vBIRTHDAY);
          IF I_RTN = 0 THEN
            -- 児童氏名かな
            rRECODE1.JIDO_SHIMEI_KANA  := o_vSHIMEIKANA;
            -- 児童氏名漢字
            rRECODE1.JIDO_SHIMEI_KANJI := o_vSHIMEIKANJI;
            -- 表示生年月日
            rRECODE1.HYOJI_SEINENGAPI  := o_vBIRTHDAY;
          END IF;
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
  --  2024/12/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:仕様変更IT_GKB_10044の対応
          IF g_nCHOHYOKBN = 2 THEN     
              rRECODE1.JIDO_SHIMEI_LAB := '児童氏名';
          ELSIF g_nCHOHYOKBN = 3 THEN
              rRECODE1.JIDO_SHIMEI_LAB := '生徒氏名';
          END IF;
  --  2024/12/17 JPJYS.SONGSHIHAO UPDATE 0.3.000.009:仕様変更IT_GKB_10044の対応
          -- 性別
          VSEIBETSU := NULL;
          IF RECGAKUREIBO.SEIBETSU = 1 THEN
            VSEIBETSU := '男';
          ELSIF RECGAKUREIBO.SEIBETSU = 2 THEN
            VSEIBETSU := '女';
          END IF;
          rRECODE1.HYOJI_SEIBETSU     := VSEIBETSU;                                                  
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--          -- 保護者氏名かな
--          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
--            I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANA,RATENA_HOGOSHA.SHIMEI_KANA,RECGAKUREIBO.HOGOSYA_SHIMEI_KANA);
--          END IF;
--          rRECODE1.HOGOSHA_SHIMEI_KANA    :=  RECGAKUREIBO.HOGOSYA_SHIMEI_KANA;                      --保護者氏名かな
--          -- 保護者氏名漢字
--          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
--            I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI);
--          END IF;
--          rRECODE1.HOGOSHA_SHIMEI_KANJI     :=   RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI;
          -- 保護者の本名使用制御判定
             I_RTN := GKBFKHMCTRL(RECGAKUREIBO.KOJIN_NO, g_rOPRT.CHOHYOID, 1, g_nGKBPA00020_CTL, o_vSHIMEIKANA_H, o_vSHIMEIKANJI_H, o_vBIRTHDAY_H);

          IF I_RTN = 0 THEN
            -- 保護者氏名かな
            rRECODE1.HOGOSHA_SHIMEI_KANA  := o_vSHIMEIKANA_H;
            -- 保護者氏名漢字
            rRECODE1.HOGOSHA_SHIMEI_KANJI := o_vSHIMEIKANJI_H;
          END IF;
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
          rRECODE1.JUSHO_JODAN    :=       NULL;
          rRECODE1.JUSHO_GEDAN    :=       NULL;
          GYOSEIKUMEI      := GAAPK0030.FGYOSEIKUMEI(RECGAKUREIBO.SANTEIDANTAI_CD,RECGAKUREIBO.GYOSEIKU_CD);
          rRECODE1.GYOSEIKU_MEI   :=   GYOSEIKUMEI;
          IF RECGAKUREIBO.TYUGAKO_CD = 0 THEN
            -- 小学校名
--  2024/12/05 ZCZL.BUYANAN UPDATE 0.3.000.005:仕様変更　IT_GKB_00719対応
--             rRECODE1.GAKKO_MEI    :=  RECGAKUREIBO.GAKOKUMEI;
            rRECODE1.GAKKO_MEI    :=  g_sNYUGAKKOMEI;
            -- 収発名を取得する
            BEGIN
              SELECT SHUHATS_MEI
                     ,DATE_MEI1,DATE_MEI2,DATE_MEI3,DATE_MEI4,DATE_MEI5,
                     KOMOKU_MEI1,KOMOKU_MEI2,KOMOKU_MEI3,KOMOKU_MEI4,KOMOKU_MEI5,
                     KOMOKU_MEI6,KOMOKU_MEI7,KOMOKU_MEI8,KOMOKU_MEI9,KOMOKU_MEI10
--2024/06/03 ZCZL.LIUHUAJUN ADD 0.3.000.000:新WizLIFE２次開発
                     ,KOIN_SHORYAKU,KOIN_CHUSHAKU,TSUCHIBUN,CHOHYO_MEI,BIKO_TITLE,YOSHIKI_BANGO_SETTOGO,YOSHIKI_BANGO,YOSHIKI_BANGO_SETSUBIGO
                INTO VSYUHATU_MEI
                     ,VDATE_MEI1,VDATE_MEI2,VDATE_MEI3,VDATE_MEI4,VDATE_MEI5,
                     VKOMOKU_MEI1,VKOMOKU_MEI2,VKOMOKU_MEI3,VKOMOKU_MEI4,VKOMOKU_MEI5,
                     VKOMOKU_MEI6,VKOMOKU_MEI7,VKOMOKU_MEI8,VKOMOKU_MEI9,VKOMOKU_MEI10
--2024/06/03 ZCZL.LIUHUAJUN ADD 0.3.000.000:新WizLIFE２次開発
                     ,vKOIN_SHORYAKU,vKOIN_CHUSHAKU,vTSUCHIBUN,vCHOHYO_MEI,vBIKO_TITLE,vYOSHIKI_BANGO_SETTOGO,vYOSHIKI_BANGO,vYOSHIKI_BANGO_SETSUBIGO
                FROM GKBTTSUCHISHOKANRI
--2024/06/03 ZCZL.LIUHUAJUN UPDATE 0.3.000.000:新WizLIFE２次開発
--                WHERE CHOHYO_KBN = c_CHOHYO_KBN_S;
               WHERE CHOHYO_KBN = g_nCHOHYOKBN;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                VSYUHATU_MEI := '';
                VDATE_MEI1 := '';
                VDATE_MEI2 := '';
                VDATE_MEI3 := '';
                VDATE_MEI4 := '';
                VDATE_MEI5 := '';
                VKOMOKU_MEI1 := '';
                VKOMOKU_MEI2 := '';
                VKOMOKU_MEI3 := '';
                VKOMOKU_MEI4 := '';
                VKOMOKU_MEI5 := '';
                VKOMOKU_MEI6 := '';
                VKOMOKU_MEI7 := '';
                VKOMOKU_MEI8 := '';
                VKOMOKU_MEI9 := '';
                VKOMOKU_MEI10 := ''; 
--2024/06/03 ZCZL.LIUHUAJUN ADD START 0.3.000.000:新WizLIFE２次開発
                vKOIN_SHORYAKU := NULL;
                vKOIN_CHUSHAKU := NULL;
                vTSUCHIBUN := '';
                vCHOHYO_MEI := '';
                vBIKO_TITLE := '';
                vYOSHIKI_BANGO_SETTOGO := '';
                vYOSHIKI_BANGO := '';
                vYOSHIKI_BANGO_SETSUBIGO := '';
--2024/06/03 ZCZL.LIUHUAJUN ADD END
            END;
            --公印ファイル名取得
             BRTN := KKBPK5551.FNINSHOGet (NVL(g_rOPRT.NINSHOCODE,0),  
                                             g_sWSNUM,        
                                             TO_DATE(ISAKUSEIBI,'YYYYMMDD'),
                                             o_nDAIRIKBN,
                                             o_vKATAGAKI1,
                                             o_vKATAGAKI2,
                                             o_vSHIMEI,
                                             o_vKOINFILENAME 
                                             );
             VGYOMU := o_vKOINFILENAME;                       --業務毎公印ファイル名                                   
            -- 日付の取得
            DATE_IN := RECGAKUREIBO.IDATE11;
            PROC_GET_YMD(DATE_IN, DATE1_OUT);
            DATE_IN := RECGAKUREIBO.IDATE12;
            PROC_GET_YMD(DATE_IN, DATE2_OUT);
            DATE_IN := RECGAKUREIBO.IDATE13;
            PROC_GET_YMD(DATE_IN, DATE3_OUT);
            DATE_IN := RECGAKUREIBO.IDATE14;
            PROC_GET_YMD(DATE_IN, DATE4_OUT);
            DATE_IN := RECGAKUREIBO.IDATE15;
            PROC_GET_YMD(DATE_IN, DATE5_OUT);
            KOMOKU1_OUT := RECGAKUREIBO.VKOMOKU11;
            KOMOKU2_OUT := RECGAKUREIBO.VKOMOKU12;
            KOMOKU3_OUT := RECGAKUREIBO.VKOMOKU13;
            KOMOKU4_OUT := RECGAKUREIBO.VKOMOKU14;
            KOMOKU5_OUT := RECGAKUREIBO.VKOMOKU15;
            KOMOKU6_OUT := RECGAKUREIBO.VKOMOKU16;
            KOMOKU7_OUT := RECGAKUREIBO.VKOMOKU17;
            KOMOKU8_OUT := RECGAKUREIBO.VKOMOKU18;
            KOMOKU9_OUT := RECGAKUREIBO.VKOMOKU19;
            KOMOKU10_OUT := RECGAKUREIBO.VKOMOKU110;
          ELSE
            -- 中学校名
--  2024/12/05 ZCZL.BUYANAN UPDATE 0.3.000.005:仕様変更　IT_GKB_00719対応
--             rRECODE1.GAKKO_MEI    := RECGAKUREIBO.GAKOKUMEI;
            rRECODE1.GAKKO_MEI    := g_sNYUGAKKOMEI;
            -- 収発名を取得する
            BEGIN
              SELECT SHUHATS_MEI
                     ,DATE_MEI1,DATE_MEI2,DATE_MEI3,DATE_MEI4,DATE_MEI5,
                     KOMOKU_MEI1,KOMOKU_MEI2,KOMOKU_MEI3,KOMOKU_MEI4,KOMOKU_MEI5,
                     KOMOKU_MEI6,KOMOKU_MEI7,KOMOKU_MEI8,KOMOKU_MEI9,KOMOKU_MEI10
--2024/06/03 ZCZL.LIUHUAJUN ADD 0.3.000.000:新WizLIFE２次開発
                     ,KOIN_SHORYAKU,KOIN_CHUSHAKU,TSUCHIBUN,CHOHYO_MEI,BIKO_TITLE,YOSHIKI_BANGO_SETTOGO,YOSHIKI_BANGO,YOSHIKI_BANGO_SETSUBIGO
                INTO VSYUHATU_MEI
                     ,VDATE_MEI1,VDATE_MEI2,VDATE_MEI3,VDATE_MEI4,VDATE_MEI5,
                     VKOMOKU_MEI1,VKOMOKU_MEI2,VKOMOKU_MEI3,VKOMOKU_MEI4,VKOMOKU_MEI5,
                     VKOMOKU_MEI6,VKOMOKU_MEI7,VKOMOKU_MEI8,VKOMOKU_MEI9,VKOMOKU_MEI10
--2024/06/03 ZCZL.LIUHUAJUN ADD 0.3.000.000:新WizLIFE２次開発
                     ,vKOIN_SHORYAKU,vKOIN_CHUSHAKU,vTSUCHIBUN,vCHOHYO_MEI,vBIKO_TITLE,vYOSHIKI_BANGO_SETTOGO,vYOSHIKI_BANGO,vYOSHIKI_BANGO_SETSUBIGO
                FROM GKBTTSUCHISHOKANRI
--2024/06/03 ZCZL.LIUHUAJUN UPDATE 0.3.000.000:新WizLIFE２次開発
--                WHERE CHOHYO_KBN = c_CHOHYO_KBN_T;
               WHERE CHOHYO_KBN = g_nCHOHYOKBN;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                VSYUHATU_MEI := '';
                VDATE_MEI1 := '';
                VDATE_MEI2 := '';
                VDATE_MEI3 := '';
                VDATE_MEI4 := '';
                VDATE_MEI5 := '';
                VKOMOKU_MEI1 := '';
                VKOMOKU_MEI2 := '';
                VKOMOKU_MEI3 := '';
                VKOMOKU_MEI4 := '';
                VKOMOKU_MEI5 := '';
                VKOMOKU_MEI6 := '';
                VKOMOKU_MEI7 := '';
                VKOMOKU_MEI8 := '';
                VKOMOKU_MEI9 := '';
                VKOMOKU_MEI10 := '';
--2024/06/03 ZCZL.LIUHUAJUN ADD START 0.3.000.000:新WizLIFE２次開発
                vKOIN_SHORYAKU := '';
                vKOIN_CHUSHAKU := '';
                vTSUCHIBUN := '';
                vCHOHYO_MEI := '';
                vBIKO_TITLE := '';
                vYOSHIKI_BANGO_SETTOGO := '';
                vYOSHIKI_BANGO := '';
                vYOSHIKI_BANGO_SETSUBIGO := '';
--2024/06/03 ZCZL.LIUHUAJUN ADD END
            END;
            --公印ファイル名取得
            BRTN := KKBPK5551.FNINSHOGet (NVL(g_rOPRT.NINSHOCODE,0),    
                                             g_sWSNUM,        
                                             TO_DATE(ISAKUSEIBI,'YYYYMMDD'),
                                             o_nDAIRIKBN,
                                             o_vKATAGAKI1,
                                             o_vKATAGAKI2,
                                             o_vSHIMEI,
                                             o_vKOINFILENAME 
                                             );
             VGYOMU := o_vKOINFILENAME;                       --業務毎公印ファイル名
            -- 日付の取得
            DATE_IN := RECGAKUREIBO.IDATE21;
            PROC_GET_YMD(DATE_IN, DATE1_OUT);
            DATE_IN := RECGAKUREIBO.IDATE22;
            PROC_GET_YMD(DATE_IN, DATE2_OUT);
            DATE_IN := RECGAKUREIBO.IDATE23;
            PROC_GET_YMD(DATE_IN, DATE3_OUT);
            DATE_IN := RECGAKUREIBO.IDATE24;
            PROC_GET_YMD(DATE_IN, DATE4_OUT);
            DATE_IN := RECGAKUREIBO.IDATE25;
            PROC_GET_YMD(DATE_IN, DATE5_OUT);
            KOMOKU1_OUT := RECGAKUREIBO.VKOMOKU21;
            KOMOKU2_OUT := RECGAKUREIBO.VKOMOKU22;
            KOMOKU3_OUT := RECGAKUREIBO.VKOMOKU23;
            KOMOKU4_OUT := RECGAKUREIBO.VKOMOKU24;
            KOMOKU5_OUT := RECGAKUREIBO.VKOMOKU25;
            KOMOKU6_OUT := RECGAKUREIBO.VKOMOKU26;
            KOMOKU7_OUT := RECGAKUREIBO.VKOMOKU27;
            KOMOKU8_OUT := RECGAKUREIBO.VKOMOKU28;
            KOMOKU9_OUT := RECGAKUREIBO.VKOMOKU29;
            KOMOKU10_OUT := RECGAKUREIBO.VKOMOKU210;
          END IF;
          rRECODE1.SANTEIDANTAI_MEI    :=   NULL;
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--          -- 郵便番号
--          rRECODE1.YUBIN_NO    :=   YUBIN_NO_OUT ;
--          -- 町名番地
--          rRECODE1.CHOMEI_BANCHI:=VCHOMEI || VBANCHI ;
--          -- 方書
--          rRECODE1.KATAGAKI:= VKATAGAKI ;
          vJYUSHO := GAAPK0010.FADDRESSEDIT( 1, NULL,  VCHOMEI ,VBANCHI, NULL, NULL);
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
          -- IF g_nSHIENSOCHIKBN = 1 THEN


          --   -- 抑止住所編集
          --   vJYUSHO := GAAPK0030.FDVJUSHO('GKB'
          --                                 ,RECGAKUREIBO.HOGOSYA_KOJIN_NO
          --                                 ,g_sTANTOCODE
          --                                 ,g_sWSNUM
          --                                 ,vJYUSHO
          --                                 ,nHANTEIKEKKA,
          --                                 2);
          --   IF nHANTEIKEKKA = 1 THEN
          --       -- 郵便番号
          --       rRECODE1.YUBIN_NO := NULL;
          --       -- 町名番地
          --       rRECODE1.CHOMEI_BANCHI := vJYUSHO;
          --       -- 方書
          --       rRECODE1.KATAGAKI := NULL;
          --   ELSE
          --       -- 郵便番号
          --       rRECODE1.YUBIN_NO := YUBIN_NO_OUT;
          --       -- 町名番地
          --       rRECODE1.CHOMEI_BANCHI := VCHOMEI || VBANCHI;
          --       -- 方書
          --       rRECODE1.KATAGAKI := VKATAGAKI;
          --   END IF;
          -- END IF;
          IF g_nSHIENSOCHIKBN = 1 THEN
            -- 抑止住所編集
                vJYUSHO := GKBPK00010.FGETJUSHOMSG();
                -- 郵便番号
                rRECODE1.YUBIN_NO := NULL;
                -- 町名番地
                rRECODE1.CHOMEI_BANCHI := vJYUSHO;
                -- 方書
                rRECODE1.KATAGAKI := NULL;
          ELSE
                -- 郵便番号
                rRECODE1.YUBIN_NO := YUBIN_NO_OUT;
                -- 町名番地
                rRECODE1.CHOMEI_BANCHI := VCHOMEI || VBANCHI;
                -- 方書
                rRECODE1.KATAGAKI := VKATAGAKI;

          END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
/*
              -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=1,3の場合
              IF VACONSPRM1(1) IN (1,3) THEN
                    IF (RSOFU_JIDO.KOJIN_NO > 0) AND 
                       (RSOFU_JIDO.TEKIYO_BI <= HASSOBI) AND 
                       (RSOFU_JIDO.SHURYO_BI >= HASSOBI OR  RSOFU_JIDO.SHURYO_BI = 0) THEN
                       IF RSOFU_JIDO.SHIMEI_KANJI IS NOT NULL THEN
                          NSHIMEI_KANJI := RSOFU_JIDO.SHIMEI_KANJI;
                       ELSE
                          NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                            I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                          END IF;
                       END IF;
                    ELSE
                       NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                       IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                         I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                       END IF;
                    END IF;
                -- SHIMEI_KANJI Is Not Nullの場合
                IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
                  -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(2)=1の場合
                  IF VACONSPRM1(3) = 1 THEN
                    ATESAKI_JODAN := '（'||NSHIMEI_KANJI||'　様）';
                  -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(2)=1以外の場合
                  ELSE
                    ATESAKI_JODAN := NSHIMEI_KANJI||'　様';
                  END IF;
                -- SHIMEI_KANJI Is Nullの場合
                ELSE
                  ATESAKI_JODAN := '';
                END IF;
              -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=1,3以外の場合
              ELSE
                          IF (RSOFU_HOGOSHA.KOJIN_NO  > 0) AND 
                       (RSOFU_HOGOSHA.TEKIYO_BI <= HASSOBI) AND 
                       (RSOFU_HOGOSHA.SHURYO_BI >= HASSOBI OR  RSOFU_HOGOSHA.SHURYO_BI = 0) THEN
                       IF RSOFU_HOGOSHA.SHIMEI_KANJI IS NOT NULL THEN
                          NSHIMEI_KANJI := RSOFU_HOGOSHA.SHIMEI_KANJI;
                       ELSE
                          NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                            I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                          END IF;
                       END IF;
                    ELSE
                       NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                       IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                         I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                       END IF;
                    END IF;
                -- HOGOSYA_SHIMEI_KANJI Is Not Nullの場合
                IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
                  -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(2)=1の場合
                  IF VACONSPRM1(2) = 1 THEN
                    ATESAKI_JODAN := '（'||NSHIMEI_KANJI||'　様）';
                  -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(2)=1以外の場合
                  ELSE
                    ATESAKI_JODAN := NSHIMEI_KANJI||'　様';
                  END IF;
                -- HOGOSYA_SHIMEI_KANJI Is Nullの場合
                ELSE
                  ATESAKI_JODAN := '';
                END IF;
              END IF;
              -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=2,3の場合
              IF VACONSPRM1(1) IN (2,3) THEN
                -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=2の場合
                IF VACONSPRM1(1) = 2 THEN
                          IF (RSOFU_JIDO.KOJIN_NO > 0) AND 
                       (RSOFU_JIDO.TEKIYO_BI <= HASSOBI) AND 
                       (RSOFU_JIDO.SHURYO_BI >= HASSOBI OR  RSOFU_JIDO.SHURYO_BI = 0) THEN
                       IF RSOFU_JIDO.SHIMEI_KANJI IS NOT NULL THEN
                          NSHIMEI_KANJI := RSOFU_JIDO.SHIMEI_KANJI;
                       ELSE
                          NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                            I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                          END IF;
                       END IF;
                    ELSE
                       NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
                       IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
                         I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
                       END IF;
                    END IF;
                  -- SHIMEI_KANJI Is Not Nullの場合
                  IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
                    -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(3)=1の場合
                    IF VACONSPRM1(3) = 1 THEN
                      ATESAKI_GEDAN := '（'||NSHIMEI_KANJI||'　様）';
                    -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(3)=1以外の場合
                    ELSE
                      ATESAKI_GEDAN := NSHIMEI_KANJI||'　様';
                    END IF;
                  -- SHIMEI_KANJI Is Nullの場合
                  ELSE
                  ATESAKI_GEDAN := '';
                  END IF;
                -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=3の場合
                ELSE
                          IF (RSOFU_HOGOSHA.KOJIN_NO  > 0) AND 
                       (RSOFU_HOGOSHA.TEKIYO_BI <= HASSOBI) AND 
                       (RSOFU_HOGOSHA.SHURYO_BI >= HASSOBI OR  RSOFU_HOGOSHA.SHURYO_BI = 0) THEN
                       IF RSOFU_HOGOSHA.SHIMEI_KANJI IS NOT NULL THEN
                          NSHIMEI_KANJI := RSOFU_HOGOSHA.SHIMEI_KANJI;
                       ELSE
                          NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                            I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                          END IF;
                       END IF;
                    ELSE
                       NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
                       IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
                         I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
                       END IF;
                    END IF;
                  -- HOGOSYA_SHIMEI_KANJI Is Not Nullの場合
                  IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
                    -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(3)=1の場合
                    IF VACONSPRM1(2) = 1 THEN
                      ATESAKI_GEDAN := '（'||NSHIMEI_KANJI||'　様）';
                    -- 宛先出力制御.制御ﾊﾟﾗﾒｰﾀ(3)=1以外の場合
                    ELSE
                      ATESAKI_GEDAN := NSHIMEI_KANJI||'　様';
                    END IF;
                  -- HOGOSYA_SHIMEI_KANJI Is Nullの場合
                  ELSE
                    ATESAKI_GEDAN := '';
                  END IF;
                END IF;
              -- 宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=2,3以外の場合
              ELSE
                ATESAKI_GEDAN := ' ';
              END IF;
          rRECODE1.ATESAKI_JODAN:=ATESAKI_JODAN ;         --宛先上段
          rRECODE1.ATESAKI_GEDAN:= ATESAKI_GEDAN ;        --宛先下段
          rRECODE1.KANJI_SEINENGAPI:= JIDO_BTH_OUT ;      --漢字生年月日
*/
          I_RTN := GKBFKHMCTRL(RECGAKUREIBO.KOJIN_NO, g_rOPRT.CHOHYOID, 1, g_nGKBPA00020_CTL, o_vSHIMEIKANA_H, 
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_00003対応 START
--                                                                                     rRECODE1.ATESAKI_JODAN,  --宛先上段
                                                                                     VSOFU_ATENA,
                                                                                     o_vBIRTHDAY_H);
          rRECODE1.ATESAKI_JODAN := VSOFU_ATENA||'　様';  --宛先上段
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.008:品質強化：IT_GKB_00003対応 END
          rRECODE1.ATESAKI_GEDAN := NULL ;                 --宛先下段
--  2024/09/05 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--          rRECODE1.KANJI_SEINENGAPI:= NULL ;              --漢字生年月日
          rRECODE1.KANJI_SEINENGAPI:= o_vBIRTHDAY ;              --漢字生年月日
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
          -- 市町村名
          USER_MEI := VACONSPRM2(1);
--2024/06/03 ZCZL.LIUHUAJUN UPDATE 0.3.000.000:新WizLIFE２次開発
--           rRECODE1.KYOIKU_KAI_MEI:= USER_MEI ;            --教育委員会名
          rRECODE1.KYOIKU_KAI_MEI:= o_vKATAGAKI1 ;        --教育委員会名
          rRECODE1.NYUGAKU_KIJITU:= g_nNYUGAKUKIJITSU ;   --入学期日
--  2024/09/05 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--          rRECODE1.HASSOBI:= HASSOBI_OUT ;                --発送日
--  2024/12/19 JPJYS.SHAXUE UPDATE 0.3.000.010:品質強化IT_GKB_10051故障対応　START
          --rRECODE1.HASSOBI:= KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_sDATEED, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);       --発送日
          n_HASSOBI:= KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_sDATEED, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);
          rRECODE1.HASSOBI:= REGEXP_REPLACE(
                TRANSLATE(REPLACE(REPLACE(n_HASSOBI, ' ', ''), '　', ''), '0123456789', '０１２３４５６７８９'),
                '(０)([１-９])', 
                '\2', 
                1, 
                0, 
                'c'
                );        --発送日
--  2024/12/19 JPJYS.SHAXUE UPDATE 0.3.000.010:品質強化IT_GKB_10051故障対応　END
--2024/06/03 ZCZL.LIUHUAJUN UPDATE 0.3.000.000:新WizLIFE２次開発
--           rRECODE1.HASSO_NO:= VSYUHATU_MEI  ||  '第 '  ||  g_NHASSO_NO ||  ' 号'  ||  ',';    --発送番号
          rRECODE1.HASSO_NO:= VSYUHATU_MEI  ||  '第 '  ||  g_rBUNSHONUM ||  ' 号'  ||  ',';    --発送番号
          rRECODE1.KOIN_PATH:= VGYOMU ;    --公印パス
          rRECODE1.TANTO_TEL:= VTANTO_TEL  ;              --電話番号

            IF LENGTH(VACONSPRM2(5)) > 0 THEN
              VTANTO_YUBIN := SUBSTR(VACONSPRM2(5),1,3) || '-' || SUBSTR(VACONSPRM2(5),4);
              VTANTO_YUBIN := TRANSLATE(VTANTO_YUBIN, '1234567890-', '１２３４５６７８９０－');
            ELSE
              VTANTO_YUBIN := '';
            END IF;
          VTANTO_JUSHO := VACONSPRM2(6);
          rRECODE1.TANTO_YUBIN_NO:=VTANTO_YUBIN ;       --担当郵便番号
          rRECODE1.TANTO_JUSHO:= VTANTO_JUSHO ;         --担当住所
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--           rRECODE1.YUBIN_NOBC:= VYUBIN_NOBC ;           --郵便番号ＢＣ
          -- 変数.支援措置対象住所非表示＝1(有)の場合
          IF g_nSHIENSOCHIKBN = 1 THEN
            rRECODE1.YUBIN_NOBC := NULL;                --郵便番号ＢＣ
          ELSE
            rRECODE1.YUBIN_NOBC:= VYUBIN_NOBC ;           --郵便番号ＢＣ
--  2024/09/05 ZCZL.WANGMING DELETE START 0.3.000.001:8月1日認識合わせの横展開
--            rRECODE1.YUBIN_NO := YUBIN_NO_OUT;           -- 郵便番号
--            rRECODE1.CHOMEI_BANCHI := VCHOMEI || VBANCHI;     -- 町名番地
--            rRECODE1.KATAGAKI := VKATAGAKI;             -- 方書
--  2024/09/05 ZCZL.WANGMING DELETE END
          END IF;
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
--  2024/12/05 ZCZL.BUYANAN UPDATE START 0.3.000.005:仕様変更　IT_GKB_00719対応
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00724対応 START
--           rRECODE1.DATE1:= DATE1_OUT ;                  --日付１
--           rRECODE1.DATE2:= DATE2_OUT ;                  --日付２
--          rRECODE1.DATE1:= g_nNYUGAKUSHIKIBI ;          --入学式日
--          rRECODE1.DATE2:= g_nNYUGAKUKIJITSU ;          --入学期日
          PROC_GET_YMD(g_nNYUGAKUSHIKIBI, NYUGAKUSHIKIBI_OUT);--入学式日
          PROC_GET_YMD(g_nNYUGAKUKIJITSU, NYUGAKUKIJITSU_OUT);--入学期日
          --  2024/12/19 JPJYS.SHAXUE UPDATE 0.3.000.010:品質強化IT_GKB_10051故障対応 START
          --rRECODE1.DATE1:= NYUGAKUSHIKIBI_OUT ;          --入学式日
          rRECODE1.DATE1:=REGEXP_REPLACE(
                TRANSLATE(REPLACE(REPLACE(NYUGAKUSHIKIBI_OUT, ' ', ''), '　', ''), '0123456789', '０１２３４５６７８９'),
                '(０)([１-９])', 
                '\2', 
                1, 
                0, 
                'c'
                );--入学式日
          --rRECODE1.DATE2:= NYUGAKUKIJITSU_OUT ;          --入学期日
          rRECODE1.DATE2:=REGEXP_REPLACE(
                TRANSLATE(REPLACE(REPLACE(NYUGAKUKIJITSU_OUT, ' ', ''), '　', ''), '0123456789', '０１２３４５６７８９'),
                '(０)([１-９])', 
                '\2', 
                1, 
                0, 
                'c'
                );--入学期日
          --  2024/12/19 JPJYS.SHAXUE UPDATE 0.3.000.010:品質強化IT_GKB_10051故障対応 END
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00724対応 END
--  2024/12/05 ZCZL.BUYANAN UPDATE END
          rRECODE1.DATE3:= DATE3_OUT ;                  --日付３
          rRECODE1.DATE4:= DATE4_OUT ;                  --日付４
          rRECODE1.DATE5:= DATE5_OUT ;                  --日付５
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--          rRECODE1.KOMOKU1:= KOMOKU1_OUT ;              --項目１
--          rRECODE1.KOMOKU2:= KOMOKU2_OUT ;              --項目２
          rRECODE1.KOMOKU1:= g_nKAISHIJIKAN ;           --項目１
          rRECODE1.KOMOKU2:= g_nUKETSUKEJIKAN ;         --項目２
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
          rRECODE1.KOMOKU3:= KOMOKU3_OUT ;              --項目３
          rRECODE1.KOMOKU4:= KOMOKU4_OUT ;              --項目４
          rRECODE1.KOMOKU5:= KOMOKU5_OUT ;              --項目５
          rRECODE1.KOMOKU6:= KOMOKU6_OUT ;              --項目６
          rRECODE1.KOMOKU7:= KOMOKU7_OUT ;              --項目７
          rRECODE1.KOMOKU8:= KOMOKU8_OUT ;              --項目８
          rRECODE1.KOMOKU9:= KOMOKU9_OUT ;              --項目９
          rRECODE1.KOMOKU10:= KOMOKU10_OUT ;            --項目１０
          rRECODE1.DATE_MEI1:= VDATE_MEI1 ;             --日付名称１
          rRECODE1.DATE_MEI2:= VDATE_MEI2 ;             --日付名称２
          rRECODE1.DATE_MEI3:= VDATE_MEI3 ;             --日付名称３
          rRECODE1.DATE_MEI4:= VDATE_MEI4 ;             --日付名称４
          rRECODE1.DATE_MEI5:= VDATE_MEI5 ;             --日付名称５
          rRECODE1.KOMOKU_MEI1:= VKOMOKU_MEI1 ;         --項目名称１
          rRECODE1.KOMOKU_MEI2:= VKOMOKU_MEI2 ;         --項目名称２
          rRECODE1.KOMOKU_MEI3:= VKOMOKU_MEI3 ;         --項目名称３
          rRECODE1.KOMOKU_MEI4:= VKOMOKU_MEI4 ;         --項目名称４
          rRECODE1.KOMOKU_MEI5:= VKOMOKU_MEI5 ;         --項目名称５
          rRECODE1.KOMOKU_MEI6:= VKOMOKU_MEI6 ;         --項目名称６
          rRECODE1.KOMOKU_MEI7:= VKOMOKU_MEI7 ;         --項目名称７
          rRECODE1.KOMOKU_MEI8:= VKOMOKU_MEI8 ;         --項目名称８
          rRECODE1.KOMOKU_MEI9:= VKOMOKU_MEI9 ;         --項目名称９
          rRECODE1.KOMOKU_MEI10:= VKOMOKU_MEI10 ;       --項目名称１０
          GAKOKU_CD := RECGAKUREIBO.SYOGAKO_CD;
          rRECODE1.GAKKO_CD:= GAKOKU_CD ;               --学校コード
          rRECODE1.ZOKUGARAMEI1:= VZOKUGARAMEI1 ;       --続柄１
          rRECODE1.ZOKUGARAMEI2:= VZOKUGARAMEI2 ;       --続柄２
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--           rRECODE1.JIDO_YUBIN_NO:= VJIDO_YUBIN_NO ;     --児童郵便番号
--           rRECODE1.JIDO_YUBIN_NOBC:= VJIDO_YUBIN_NOBC ; --児童郵便番号ＢＣ
--           rRECODE1.JIDO_CHOMEI_BANCHI:= VJIDO_CHOMEI || VJIDO_BANCHI ;--児童町名番地
--           rRECODE1.JIDO_KATAGAKI:= VJIDO_KATAGAKI ;     --児童方書
          --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
          vJYUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, VJIDO_CHOMEI, VJIDO_BANCHI, NULL, NULL);
          --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END
          -- 変数.支援措置対象住所非表示＝1(有)の場合
          IF g_nSHIENSOCHIKBN = 1 THEN
            rRECODE1.JIDO_YUBIN_NO:= NULL ;             --児童郵便番号
            rRECODE1.JIDO_YUBIN_NOBC:= NULL ;           --児童郵便番号ＢＣ
            -- 抑止住所編集
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
            --vJYUSHO := GAAPK0010.FADDRESSEDIT(1, NULL, VJIDO_CHOMEI, VJIDO_BANCHI, NULL, NULL);
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END
--  2024/09/05 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--            vJYUSHO := GAAPK0030.FDVJUSHO('GKB', RATENA_JIDO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vJYUSHO, nHANTEIKEKKA, 2);
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
            --vJYUSHO1 := GAAPK0030.FDVJUSHO('GKB', RATENA_JIDO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vJYUSHO, nHANTEIKEKKA, 2);
            vJYUSHO1 := GKBPK00010.FGETJUSHOMSG();
            --IF nHANTEIKEKKA = 1 THEN
--  2024/09/05 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--              rRECODE1.JIDO_CHOMEI_BANCHI := vJYUSHO;   --児童町名番地
              rRECODE1.JIDO_CHOMEI_BANCHI := vJYUSHO1;
              rRECODE1.JIDO_KATAGAKI := NULL;           --児童方書
--             ELSE
-- --  2024/09/05 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
-- --              rRECODE1.JIDO_CHOMEI_BANCHI:= VJIDO_CHOMEI || VJIDO_BANCHI ;  --児童町名番地
--               rRECODE1.JIDO_CHOMEI_BANCHI:= vJYUSHO;
--               rRECODE1.JIDO_KATAGAKI:= VJIDO_KATAGAKI ;                     --児童方書
--             END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
          ELSE
--  2024/12/10 JPJYS.LIZIZHONG UPDATE 0.3.000.007:品質強化故障対応　STR       
            rRECODE1.JIDO_CHOMEI_BANCHI:= vJYUSHO;        --児童町名番地
            rRECODE1.JIDO_KATAGAKI:= VJIDO_KATAGAKI ;     --児童方書
--  2024/12/10 JPJYS.LIZIZHONG UPDATE 0.3.000.007:品質強化故障対応　END            
            rRECODE1.JIDO_YUBIN_NO:= VJIDO_YUBIN_NO ;     --児童郵便番号
            rRECODE1.JIDO_YUBIN_NOBC:= VJIDO_YUBIN_NOBC ; --児童郵便番号ＢＣ
            rRECODE1.YUBIN_NO := YUBIN_NO_OUT;            -- 郵便番号
            rRECODE1.CHOMEI_BANCHI := VCHOMEI || VBANCHI; -- 町名番地
            rRECODE1.KATAGAKI := VKATAGAKI;               -- 方書
          END IF;
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
            --IF VACONSPRM1(1) IN (1,3) THEN
            --  ATESAKI_YUBIN_NO   := VJIDO_YUBIN_NO;
            --  ATESAKI_YUBIN_NOBC := VJIDO_YUBIN_NOBC;
            --  ATESAKI_CHOMEI     := VJIDO_CHOMEI;
            --  ATESAKI_BANCHI     := VJIDO_BANCHI;
            --  ATESAKI_KATAGAKI   := VJIDO_KATAGAKI;
            --ELSE
            --  ATESAKI_YUBIN_NO   := YUBIN_NO_OUT;
            --  ATESAKI_YUBIN_NOBC := VYUBIN_NOBC;
            --  ATESAKI_CHOMEI     := VCHOMEI;
            --  ATESAKI_BANCHI     := VBANCHI;
            --  ATESAKI_KATAGAKI   := VKATAGAKI;
            --END IF;
            ATESAKI_YUBIN_NO   := YUBIN_NO_OUT;
            ATESAKI_YUBIN_NOBC := VYUBIN_NOBC;
            ATESAKI_CHOMEI     := VCHOMEI;
            ATESAKI_BANCHI     := VBANCHI;
            ATESAKI_KATAGAKI   := VKATAGAKI;
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END
          VTANTO_YAKUSHOKU_MEI := VACONSPRM2(2);
          VTANTO_SHUTHOU_MEI   := VACONSPRM2(3);
          VTANTO_RITSU_MEI     := VACONSPRM2(4);
          VTANTO_TEL_NAISEN    := VACONSPRM2(8);
          --  2024/12/05 ZCZL.BUYANAN DEL 0.3.000.005:仕様変更　IT_GKB_00719対応
          --rRECODE1.ATESAKI_YUBIN_NO:=ATESAKI_YUBIN_NO ;                         --宛先郵便番号
          --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
          rRECODE1.BC_NO:= ATESAKI_YUBIN_NOBC ;                                 --カスタマバーコード
          --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END
          --  2024/12/05 ZCZL.BUYANAN 0.3.000.005:仕様変更　IT_GKB_00719対応
          --rRECODE1.ATESAKI_CHOMEI_BANCHI:= ATESAKI_CHOMEI || ATESAKI_BANCHI ;   --宛先町名番地
          --  2024/12/05 ZCZL.BUYANAN ADD START 0.3.000.005:仕様変更　IT_GKB_00719対応
          --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
          -- IF g_nSHIENSOCHIKBN = 1 THEN
          IF g_nSHIENSOCHIKBN = 1 THEN
          -- IF nHANTEIKEKKA = 1 THEN
           --2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END  
            rRECODE1.ATESAKI_YUBIN_NO := NULL;
            rRECODE1.ATESAKI_CHOMEI_BANCHI:= GKBPK00010.FGETJUSHOMSG();
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
            rRECODE1.BC_NO:= NULL; 
            rRECODE1.ATESAKI_KATAGAKI:= NULL;
            --2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END
          ELSE
            rRECODE1.ATESAKI_YUBIN_NO:=ATESAKI_YUBIN_NO ;                         --宛先郵便番号
            rRECODE1.ATESAKI_CHOMEI_BANCHI:= ATESAKI_CHOMEI || ATESAKI_BANCHI ;   --宛先町名番地
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
            rRECODE1.BC_NO:= ATESAKI_YUBIN_NOBC ;                                 --カスタマバーコード
            rRECODE1.ATESAKI_KATAGAKI:= ATESAKI_KATAGAKI ;                        --宛先方書
            --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END
          END IF;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
          --  2024/12/05 ZCZL.BUYANAN ADD END
          --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 START
          --rRECODE1.ATESAKI_KATAGAKI:= ATESAKI_KATAGAKI ;                        --宛先方書
          --  2024/12/23 JPJYS.ZHANGYUNSONG UPDATE 0.3.000.011:品質強化IT_GKB_10100、IT_GKB_10111対応 END
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--          rRECODE1.YAKUSHOKU_MEI:=VTANTO_YAKUSHOKU_MEI ;                        --役職名
--          rRECODE1.SHUCHO_MEI:= VTANTO_SHUTHOU_MEI ;                            --首長名
          rRECODE1.YAKUSHOKU_MEI := o_vKATAGAKI1 ;                              --役職名
          rRECODE1.SHUCHO_MEI := o_vSHIMEI ;                                    --首長名
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
          rRECODE1.TANTO_RITSU_MEI:= VTANTO_RITSU_MEI ;                         --担当立名
          rRECODE1.TANTO_TEL_NAISEN:= VTANTO_TEL_NAISEN ;                       --担当番号内線
          NCHOHYO_NO2 := TRIM(RECGAKUREIBO.NCHOHYO_NO);
          NCHOHYO_NO2 := LPAD(NCHOHYO_NO2,5,' ');
          IF GAKOKU_CD IS NOT NULL THEN
            VGAKOKU_CD2 := TRIM(TO_CHAR(GAKOKU_CD));
            VGAKOKU_CD2 := LPAD(VGAKOKU_CD2,5,' ');
          ELSE
            VGAKOKU_CD2 := NULL;
          END IF;
              IF VACONSPRM3(1) = 0 THEN
                HYOJI_CHOHYO_NO := ' ';
              ELSIF VACONSPRM3(1) = 1 THEN
                HYOJI_CHOHYO_NO := NCHOHYO_NO2;
              ELSIF VACONSPRM3(1) = 2 THEN
                HYOJI_CHOHYO_NO := LTRIM(RECGAKUREIBO.GAKOKUMEI) || '-' || NCHOHYO_NO2;
              ELSIF VACONSPRM3(1) = 3 THEN
                HYOJI_CHOHYO_NO := VGAKOKU_CD2 || '-' || NCHOHYO_NO2;
              ELSIF VACONSPRM3(1) = 4 THEN
                HYOJI_CHOHYO_NO := LTRIM(RECGAKUREIBO.GAKOKUMEI) || '-' || LTRIM(GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
              ELSIF VACONSPRM3(1) = 5 THEN
                HYOJI_CHOHYO_NO := VGAKOKU_CD2 || '-' || LTRIM(GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
              ELSE
                HYOJI_CHOHYO_NO := ' ';
              END IF;
          rRECODE1.HYOJI_CHOHYO_NO:=HYOJI_CHOHYO_NO;                   --表示帳票連番
          KYOIKUKAI_RENRAKUSAKI := GET_EQRENRAKUSAKI(3, VACONSPRM2(1), VACONSPRM2(7), VACONSPRM2(8));
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--          rRECODE1.KYOIKU_RENRAKUSAKI:= KYOIKUKAI_RENRAKUSAKI;         --教育委員会連絡先
          rRECODE1.KYOIKU_RENRAKUSAKI := o_vSHIMEI;                      --教育委員会連絡先
          rRECODE1.BUNSHO_NO := g_rBUNSHONUM;                            --文書番号
          -- 公印ファイル名を取得できる場合
--  2024/09/05 ZCZL.WANGMING UPDATE 0.3.000.001:8月1日認識合わせの横展開
--          IF VGYOMU IS NOT NULL THEN
--            rRECODE1.KOIN_SHORYAKU := vKOIN_SHORYAKU;                    --公印省略
--            rRECODE1.KOIN_CHUSHAKU := vKOIN_CHUSHAKU;                    --公印注釈
--          END IF;
          IF VGYOMU IS NULL THEN
            rRECODE1.KOIN_SHORYAKU := vKOIN_SHORYAKU;                    --公印省略
            rRECODE1.KOIN_CHUSHAKU := NULL;                              --公印注釈
          ELSE
            rRECODE1.KOIN_SHORYAKU := NULL;                              --公印省略
            rRECODE1.KOIN_CHUSHAKU := vKOIN_CHUSHAKU;                    --公印注釈
          END IF;
--  2024/09/05 ZCZL.WANGMING UPDATE END
          rRECODE1.TITLE := vCHOHYO_MEI;                                      --通知書タイトル 
          rRECODE1.TSUCHIBUN := REPLACE(vTSUCHIBUN, chr(13)||chr(10),'#');    --通知文
          rRECODE1.TOKKIJIKO := REPLACE(g_sTOKUKIJIKO, chr(13)||chr(10),'#'); --特記事項
          rRECODE1.BIKO := REPLACE(g_sBIKO, chr(13)||chr(10),'#');       --備考
          rRECODE1.TOIAWASESAKI1 := VACONSPRM2(1);                       --お問い合わせ先１
          rRECODE1.TOIAWASESAKI2 := VACONSPRM2(6);                       --お問い合わせ先２
          rRECODE1.TOIAWASESAKI3 := VACONSPRM2(7);                       --お問い合わせ先３
          rRECODE1.YOSHIKI_NO := vYOSHIKI_BANGO_SETTOGO || vYOSHIKI_BANGO || vYOSHIKI_BANGO_SETSUBIGO; --様式番号
--  2025/01/08 JPJYS.LIJINGHUI ADD 0.3.000.012:品質強化IT_GKB_10195対応  Start           
          rRECODE1.YOSHIKI_NO := REPLACE(REPLACE(KKAPK0010.FMULTIBYTEHENKAN(rRECODE1.YOSHIKI_NO, 0),' ',''),'　',''); --様式番号
--  2025/01/08 JPJYS.LIJINGHUI ADD 0.3.000.012:品質強化IT_GKB_10195対応  End           
          rRECODE1.BIKO_TITLE := vBIKO_TITLE;                            --備考タイトル
--  2025/09/11 CTC.XIAOMINGBO UPDATE START 1.0.105.000:GKB_QA20562対応
          rRECODE1.GAKKO_KBN_CD := LPAD(TO_CHAR(RECGAKUREIBO.GAKKO_KBN_CD),2,'0');            --学校区分コード     
          --rRECODE1.GAKKO_KBN_CD := RECGAKUREIBO.GAKKO_KBN_CD;            --学校区分コード    
--  2025/09/11 CTC.XIAOMINGBO UPDATE END 
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
          rRECODE1.BREAK_NO := NULL;
          rRECODE1.WSNUM := g_sWSNUM;
          rRECODE1.BATCHKBN := c_ONLINE;
          rRECODE1.JOBNUM := g_nJOBNUM;
--2024/06/03 ZCZL.LIUHUAJUN UPDATE START 0.3.000.000:新WizLIFE２次開発
--          INSERT INTO GKBWL030R001 VALUES rRECODE1;
          FOR i IN 1..g_nHAKKOSU LOOP
--  2024/11/15 ZCZL.WANGYUNING ADD START 0.3.000.004:IT_GKB_00539横展開対応
            nROWNUM                    :=   nROWNUM + 1            ;
            rRECODE1.NO                :=   nROWNUM                ;-- ソート順
--  2024/11/15 ZCZL.WANGYUNING ADD END
            INSERT INTO GKBWL030R001 VALUES rRECODE1;
          END LOOP;
--2024/06/03 ZCZL.LIUHUAJUN UPDATE END
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
          -- 該当なしは正常終了とする
          IFRET := c_ISUCCESS;
          -- カーソルが開いていたらクローズ
          IF GAKUREIBO%ISOPEN THEN
            CLOSE GAKUREIBO;
          END IF;
        -- その他
        WHEN OTHERS THEN
          -- その他エラー
          IFRET := c_INOT_SUCCESS;
          -- SQL情報取得
          g_sMESSAGE  := SUBSTR(SQLERRM, 1, 250);
          -- カーソルが開いていたらクローズ
          IF GAKUREIBO%ISOPEN THEN
            CLOSE GAKUREIBO;
          END IF;
          -- エラーメッセージ表示
          DBMS_OUTPUT.PUT_LINE('例外エラー：' || SQLCODE);
          DBMS_OUTPUT.PUT_LINE(g_sMESSAGE);
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/04
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        ERR                   EXCEPTION;
--2024/06/03 ZCZL.LIUHUAJUN ADD 0.3.000.000:新WizLIFE２次開発
        nRTN                  NUMBER;
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');
        DELETE FROM GKBWL030R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
        BEGIN
          -- エラーコードの初期化
          g_NSQLCODE := 0;
          -- エラーメッセージの初期化
          g_VSQLMSG := '';
          -- エラーメッセージの初期化
          g_sMESSAGE := '';
--2024/06/03 ZCZL.LIUHUAJUN ADD START 0.3.000.000:新WizLIFE２次開発
          -- 文書番号情報取得
          g_rBUNNUMSRCINF := KKBPK5551.FBunNumInf (g_sBUNSHONUMLIST);
          --文書番号編集結果を取得
          g_rBUNNUMEDITKEKA := g_rBUNNUMSRCINF.UOUT;
          -- 文書番号印字ありの場合
          IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
              g_rBUNSHONUM := g_rBUNNUMEDITKEKA.NUM;  -- 文書番号
          ELSE
              g_rBUNSHONUM := NULL;  -- 文書番号
          END IF;
--  2024/09/05 ZCZL.WANGMING ADD START 0.3.000.001:8月1日認識合わせの横展開
          -- 発付年月日変数
          IF g_rBUNNUMEDITKEKA.DATEUMUFLG = 0 THEN
              --文書入力画面で文書日付印字ありのとき設定
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00433対応  
              --g_sDATEED := g_rBUNNUMEDITKEKA.DATEED;
              g_sDATEED := g_rBUNNUMEDITKEKA.BUNDATE;
          ELSE
              g_sDATEED := '';
          END IF;
--  2024/09/05 ZCZL.WANGMING ADD END
--2024/06/03 ZCZL.LIUHUAJUN ADD END
          -- 宛先の氏名出力制御を取得
          ISIMEYISYUTURYOKUSEGYO     := KKAPK0030.FPRMSHUTOKU('GKB','00ATENA',4,VACONSPRM1,NLENGTH1);
            IF ISIMEYISYUTURYOKUSEGYO = 1 THEN
                          VACONSPRM1 := A_CONS_PRM();
                          VACONSPRM1.EXTEND;
                          VACONSPRM1.EXTEND;
                          VACONSPRM1(1) := 0;
                          VACONSPRM1.EXTEND;
                          VACONSPRM1(2) := 0;
                          VACONSPRM1.EXTEND;
                          VACONSPRM1(3) := 0;
                          VACONSPRM1.EXTEND;
                          VACONSPRM1(4) := 0;
            ELSE
              WHILE (NLENGTH1 < 4) LOOP   
                VACONSPRM1.EXTEND;
                VACONSPRM1(NLENGTH1+1) := 0;
                NLENGTH1 := NLENGTH1 + 1;
              END LOOP;
            END IF;
            I_RTN := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,o_SHIMEIPRM,o_LENGTH);
            IF I_RTN  = 1 THEN
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
              o_SHIMEIPRM.EXTEND;
              o_SHIMEIPRM(6) := 0;
            ELSE
              WHILE (o_LENGTH < 6) LOOP   
                o_SHIMEIPRM.EXTEND;
                o_SHIMEIPRM(o_LENGTH+1) := 0;
                o_LENGTH := o_LENGTH + 1;
              END LOOP;
            END IF;
          -- 教育委員会情報を取得
--2024/06/03 ZCZL.LIUHUAJUN UPDATE 0.3.000.000:新WizLIFE２次開発
--           IKYOUIKUIINKAIJOUHOU       := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',g_NIINKAI,VACONSPRM2,NLENGTH2);
            IKYOUIKUIINKAIJOUHOU       := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',g_nKYOIKUKAI,VACONSPRM2,NLENGTH2);
            IF IKYOUIKUIINKAIJOUHOU = 1 THEN
                          VACONSPRM2 := A_CONS_PRM();
                          VACONSPRM2.EXTEND;
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(1) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(2) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(3) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(4) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(5) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(6) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(7) := ' ';
                          VACONSPRM2.EXTEND;
                          VACONSPRM2(8) := ' ';
            ELSE
              WHILE (NLENGTH2 < 8) LOOP
                VACONSPRM2.EXTEND;
                VACONSPRM2(NLENGTH2+1) := ' ';
                NLENGTH2 := NLENGTH2 + 1;
              END LOOP;
            END IF;
--2024/06/03 ZCZL.LIUHUAJUN ADD START 0.3.000.000:新WizLIFE２次開発
          --外国人　氏名・生年月日制御帳票(ID)
          g_aSHIMEIJKN_CHOHYOPRM := A_CONS_PRM();
          nRTN := KKAPK0030.FCTGetR('GKB','SHIMEIJKN_CHOHYO','0000',1,g_aSHIMEIJKN_CHOHYOPRM);
          IF nRTN = 0 THEN
            FOR i IN 1..g_aSHIMEIJKN_CHOHYOPRM.COUNT LOOP
              IF g_aSHIMEIJKN_CHOHYOPRM(i) = 'GKB030R001' THEN
                g_nGKBPA00020_INDEX := i;  -- 入学通知書_インデックス番号
                EXIT;
              END IF;
            END LOOP;
          END IF;
          --本名・通称名　出力制御
          g_aEQSHIMEIPRM := A_CONS_PRM();
          nRTN := KKAPK0030.FCTGetR('GKB','EQSHIMEI','0000',0,g_aEQSHIMEIPRM);
          IF nRTN = 0 AND g_nGKBPA00020_INDEX < g_aEQSHIMEIPRM.COUNT THEN
            g_nGKBPA00020_CTL := TO_NUMBER(g_aEQSHIMEIPRM(g_nGKBPA00020_INDEX));  -- 入学通知書_出力制御
          END IF;
--2024/06/03 ZCZL.LIUHUAJUN ADD END
          -- 帳票連番印字項目の制御を取得
          ICHOUHYOURENBANINZIKOUMOKU := KKAPK0030.FPRMSHUTOKU('GKB','00RENBAN',0,VACONSPRM3,NLENGTH3);
            IF ICHOUHYOURENBANINZIKOUMOKU = 1 THEN
                          VACONSPRM3 := A_CONS_PRM();
                          VACONSPRM3.EXTEND;
                          VACONSPRM3.EXTEND;
                          VACONSPRM3(1) := 0;
            ELSE
              WHILE (NLENGTH3 < 1) LOOP
                VACONSPRM3.EXTEND;
                VACONSPRM3(NLENGTH3+1) := 0;
                NLENGTH3 := NLENGTH3 + 1;
              END LOOP;
            END IF;
          IF TO_NUMBER(g_NHASSOBI) = 0 THEN
           HASSOBI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
          ELSE
           HASSOBI := g_NHASSOBI;
          END IF;
          ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
          -- ＣＳＶ作成
          I_RTN := FUNC_GET_JIDO_REC;
          -- 正常に終了
          IF I_RTN = c_ISUCCESS THEN
            -- 処理状態出力
            DBMS_OUTPUT.PUT_LINE('『入学通知書出力』正常終了');
          -- 異常終了
          ELSE
            -- 処理状態出力
            DBMS_OUTPUT.PUT_LINE('『入学通知書出力』異常終了');
          END IF;
        -- 例外
        EXCEPTION
          -- その他エラー
          WHEN OTHERS THEN
            -- SQL情報取得
            g_NSQLCODE := SQLCODE;
            g_VSQLMSG  := SUBSTR(SQLERRM, 1, 250);
            -- エラーメッセージ表示
            g_sMESSAGE := g_NSQLCODE || '|' || g_VSQLMSG;
            RAISE ERR;
        END;

        --帳票出力CSVの作成
        bRTN := FUNC_O20CSV(i_sGYOUMUCODE, 'GKBWL030R001', i_sCHOHYOID);

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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/04
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
END GKBPA00020;
/