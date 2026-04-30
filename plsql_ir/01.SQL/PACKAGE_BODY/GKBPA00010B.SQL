CREATE OR REPLACE PACKAGE BODY GKBPA00010
--1.0.106.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 健康診断通知書／健康診断票出力（即時）
--  機能概要      : 個人番号と履歴連番をキーにして健康診断通知書／健康診断票を出力する。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.CONGDAN 2024/01/05
--------------------------------------------------------
--  変更履歴
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
--  2024/06/03 ZCZL.QINYUE UPDATE 0.3.000.000:新WizLIFE２次開発
--  2024/08/20 ZCZL.WANGM UPDATE 0.3.000.001:IT_GKB_00018対応
--  2024/09/04 ZCZL.JIANGJUN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00452対応
--  2024/11/13 JPJYS.WENGSILIANG UPDATE 0.3.000.004:IT_GKB_00510対応
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.004:IT_GKB_00539横展開対応
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00625対応
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00730対応
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:品質強化：IT_GKB_10001対応
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応
--  2025/01/09 JPJYS.LIJINGHUI UPDATE 0.3.000.009:品質強化：IT_GKB_10132対応
--  2025/05/15 CTC.LIUJUNHAO UPDATE 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
--  2025/07/18 CTC.HJF UPDATE 1.0.010.001:GKB_QA17896対応
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
    g_sBUNSHONUMLIST              NVARCHAR2(1000);             --文書番号情報（リスト）
    g_sMESSAGE                    NVARCHAR2(4000);             --メッセージ返却用
    g_rOPRT                       KKATOPRT%ROWTYPE;            --オンラインジョブステップ情報
    g_sCSV_RCNT                   NVARCHAR2(1000);             --CSVファイル出力件数
    g_sCSVFILENAME                NVARCHAR2(1000);             --CSVファイル名
    g_sPRTFILENAME                NVARCHAR2(1000);             --印刷ファイル名
    g_sSTARTDATE                  NVARCHAR2(23);               -- 開始時刻
    g_VSQLMSG                     NVARCHAR2(1000);
    g_NSQLCODE                    NUMBER;
    g_NKOJIN_NO                   NUMBER;
    g_NRIREKI_RENBAN              NUMBER;
    g_NHASSO_NO                   NUMBER;
    g_NHASSO_BI                   NUMBER;
    g_NIINKAI                     NUMBER;
    --パラメータ変数
    ------------------------------------------------------------------------------
    --  定数宣言
    ------------------------------------------------------------------------------
      -- 処理結果
      c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
      c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
      -- 帳票区分
      c_CHOHYO_KBN   CONSTANT   NUMBER(2)  := 1;         -- 健康診断通知書
    ------------------------------------------------------------------------------
    --  変数宣言
    ------------------------------------------------------------------------------
      -- ERROR関連 --
      I_RTN           PLS_INTEGER;     -- 戻り値

      i_IKIJYUNBI     PLS_INTEGER;     -- 基準日
      VKIJUNBI        PLS_INTEGER;     -- 年齢計算用基準日
      BRTN            BOOLEAN;         -- サブルーチンの戻り値
      ISAKUSEIBI      PLS_INTEGER;
      -- 収発名
      VSYUHATU_MEI    NVARCHAR2(12);
      --公印ファイル名取得
      VGYOMU          NVARCHAR2(100);  --業務毎公印ファイル名
--  2024/08/20 ZCZL.WANGM ADD Start 0.3.000.001:IT_GKB_00018対応
      o_vKATAGAKI1          NVARCHAR2(1000);
      o_vKATAGAKI2          NVARCHAR2(1000);
--  2024/08/20 ZCZL.WANGM ADD End
--  2024/08/20 ZCZL.WANGM DELETE Start 0.3.000.001:IT_GKB_00018対応
--      VNINSHO_KATAGAKI     NVARCHAR2(100);
--      VNINSHO_SHIMEI       NVARCHAR2(40);
--  2024/08/20 ZCZL.WANGM DELETE Start 0.3.000.001:IT_GKB_00018対応
      NNENDO          PLS_INTEGER;
      VHYOUJINENDO    NVARCHAR2(30);
      ISIMEYISYUTURYOKUSEGYO             PLS_INTEGER;      -- 宛先の氏名出力制御
      IKYOUIKUIINKAIJOUHOU               PLS_INTEGER;      -- 教育委員会情報
      ICHOUHYOURENBANINZIKOUMOKU         PLS_INTEGER;      -- 帳票連番印字項目制御
      o_ATENA_PRM                         A_CONS_PRM;       -- パラメータの配列1
      o_LENGTH                           NUMBER;           -- パラメータの配列の長度1
      o_KYOIKUPRM                         A_CONS_PRM;       -- パラメータの配列2
      o_RENBAN_PRM                         A_CONS_PRM;       -- パラメータの配列3
      GAKOKU_CD                          NVARCHAR2(60);
      GAKOKUMEI_2                        NVARCHAR2(60);
      GAKOKUMEI_1                        NVARCHAR2(60);
      GAKOKUMEI                          NVARCHAR2(60);
      ATESAKI_JODAN                      NVARCHAR2(110);
      ATESAKI_GEDAN                      NVARCHAR2(110);
      VTANTO_TEL                         NVARCHAR2(60);
      VTANTO_YUBIN_NO                    NVARCHAR2(60);
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応      
      --VTANTO_JUSHO                       NVARCHAR2(60);
      VTANTO_JUSHO                       NVARCHAR2(100);
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応
      JIDO_YUBIN_NO                      NVARCHAR2(10);  -- 郵便番号
      JIDO_YUBIN_NOBC                    NVARCHAR2(30);  -- 郵便番号BC
      JIDO_CHOMEI                        NVARCHAR2(40);  -- 町名
      JIDO_BANCHI                        NVARCHAR2(40);  -- 番地
      JIDO_KATAGAKI                      NVARCHAR2(60);  -- 方書
      ATESAKI_YUBIN_NO                   NVARCHAR2(10);
      ATESAKI_YUBIN_NOBC                 NVARCHAR2(30);
      ATESAKI_CHOMEI                     NVARCHAR2(40);
      ATESAKI_BANCHI                     NVARCHAR2(40);
      ATESAKI_KATAGAKI                   NVARCHAR2(60);
      VTANTO_YAKUSHOKU_MEI               NVARCHAR2(60);
      VTANTO_SHUTHOU_MEI                 NVARCHAR2(60);
      VTANTO_RITSU_MEI                   NVARCHAR2(60);
      VTANTO_TEL_NAISEN                  NVARCHAR2(60);
      HYOJI_CHOHYO_NO                    NVARCHAR2(90);
      NCHOHYO_NO                         NUMBER;
      GYOSEIKUMEI                        NVARCHAR2(60);
      VYUBIN_NO                          NVARCHAR2(60);
      HASSO_BI                           PLS_INTEGER;   --処理条件４.発行日
      NCHOHYO_NO2                        NVARCHAR2(6);     -- ZZZZ9表示連番
      IGAKKO_CD2                         NVARCHAR2(5);     -- ZZZZ9学校コード
--  2024/06/28 ZCZL.qinyue Delete start 0.3.000.000:新WizLIFE２次開発
--        o_SHIMEIPRM      A_CONS_PRM;   --氏名印字.制御ﾊﾟﾗﾒｰﾀ
--        BPRMFLG_001      BOOLEAN;
--        BPRMFLG_002      BOOLEAN;
--  2024/06/28 ZCZL.qinyue Delete end
        BPRMFLG_003      BOOLEAN;
        BPRMFLG_004      BOOLEAN;
       o_YMD2           NVARCHAR2(30);
       N_NAIYO_CD       GKBTSHIMEIJKN.NAIYO_CD%TYPE;
       KYOIKUKAI_RENRAKUSAKI  NVARCHAR2(100);
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
       g_vCHOHYO_KBN                     NVARCHAR2(1000);  --帳票区分
       g_nATENAKBN                        NVARCHAR2(1000);  --宛先
       g_sBUNSHO                        NVARCHAR2(1000);  --文書番号
       g_nSHIENSOCHIKBN                        NVARCHAR2(1000);  --支援措置対象住所非表示
       g_nHAKKOBUSUU                     NVARCHAR2(1000);  --発行部数
       g_sTXTKANSADATE                        NVARCHAR2(1000);  --実施日
       g_nKAISHIJIKAN                        NVARCHAR2(1000);  --開始時間
       g_nUKETSUKEJIKAN                        NVARCHAR2(1000);  --受付時間
       g_KAIJOU                        NVARCHAR2(1000);  --受付会場
       g_sTOKUKIJIKO                        NVARCHAR2(1000);  --特記事項
       g_sBIKO                        NVARCHAR2(1000);  --備考
       g_nGKB010_INDEX                   NUMBER;          --健康診断通知書_インデックス番号
       g_vGKB010_CTL                     NVARCHAR2(1000); --健康診断通知書_出力制御
       g_vGKB020_CTL                     NVARCHAR2(1000); --学健康診断票_出力制御
       g_aSHIMEIJKN_CHOHYOPRM            A_CONS_PRM;
       g_aSHIMEIPRM                      A_CONS_PRM;
       g_vTOIAWASESAKI1                  NVARCHAR2(1000);
       g_vTOIAWASESAKI2                  NVARCHAR2(1000);
       g_vTOIAWASESAKI3                  NVARCHAR2(1000);
       g_nCOUNT                          NUMBER;
       o_vSHIMEI                         NVARCHAR2(1000);
       g_rBUNNUMINF                      KKAPK0040.MR_BUNNUMSRCINF; -- 文書番号情報(構造体)
       g_rBUNNUMEDITKEKA                 KKAPK0040.MR_BUNNUMEDITKEKA; --文書番号編集結果
       g_vBUNSHO_NO                      NVARCHAR2(100);
--  2024/06/03 ZCZL.ZHANGLEI ADD END
--  2024/09/04 ZCZL.JIANGJUN Add Start 0.3.000.002:8月1日認識合わせの横展開
       g_sDATEED                         NVARCHAR2(1000);             --発付年月日変数
--  2024/09/04 ZCZL.JIANGJUN Add End
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00730対応 START
       TXTKANSADATE_OUT                  NVARCHAR2(100);
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00730対応 END
    ------------------------------------------------------------------------------
    --  カーソル定義
    ------------------------------------------------------------------------------
      CURSOR GAKUREIBO(p_KojinNo IN NUMBER, p_RirekiRenban IN NUMBER) IS
        SELECT
               A.HOGOSYA_KOJIN_NO,
               NVL(B1.SHIMEI_KANA,' ') SHIMEI_KANA,
               NVL(B1.SHIMEI_KANJI,' ') SHIMEI_KANJI,
               DECODE(NVL(B1.SEIBETSU,0),1,'男',2,'女',' ') SEIBETSU,
               NVL(B1.SEINENGAPI,0) SEINENGAPI,
               NVL(B2.SHIMEI_KANA,' ') HOGOSYA_SHIMEI_KANA,
               NVL(B2.SHIMEI_KANJI,' ') HOGOSYA_SHIMEI_KANJI,

               NVL(C.DATE1,0) IDATE1,
               NVL(C.DATE2,0) IDATE2,
               NVL(C.DATE3,0) IDATE3,
               NVL(C.DATE4,0) IDATE4,
               NVL(C.DATE5,0) IDATE5,
               NVL(C.KOMOKU1,' ') VKOMOKU1,
               NVL(C.KOMOKU2,' ') VKOMOKU2,
               NVL(C.KOMOKU3,' ') VKOMOKU3,
               NVL(C.KOMOKU4,' ') VKOMOKU4,
               NVL(C.KOMOKU5,' ') VKOMOKU5,
               NVL(C.KOMOKU6,' ') VKOMOKU6,
               NVL(C.KOMOKU7,' ') VKOMOKU7,
               NVL(C.KOMOKU8,' ') VKOMOKU8,
               NVL(C.KOMOKU9,' ') VKOMOKU9,
               NVL(C.KOMOKU10,' ') VKOMOKU10,
               NVL(F1.ZOKUGARAMEI,' ') ZOKUGARAMEI1,
               NVL(F2.ZOKUGARAMEI,' ') ZOKUGARAMEI2,
               NVL(F3.ZOKUGARAMEI,' ') ZOKUGARAMEI3,
               NVL(F4.ZOKUGARAMEI,' ') ZOKUGARAMEI4
               ,NVL(A.SYOGAKO_CD,0) SYOGAKO_CD
               ,NVL(A.SYOGAKO_TENGAKU_BI,0) SYOGAKO_TENGAKU_BI
               ,NVL(A.SYOGAKO_SOTSUGYO_BI,0) SYOGAKO_SOTSUGYO_BI
               ,NVL(A.KUIKIGAI_CD,0) KUIKIGAI_CD
               ,NVL(A.KUIKIGAI_TENGAKU_BI,0) KUIKIGAI_TENGAKU_BI
               ,NVL(A.KUIKIGAI_TAIGAKU_BI,0) KUIKIGAI_TAIGAKU_BI
               ,NVL(A.KUIKIGAI_SOTSUGYO_BI,0) KUIKIGAI_SOTSUGYO_BI
               ,NVL(A.YOGOGAKO_CD,0) YOGOGAKO_CD
               ,NVL(A.YOGOGAKO_TENGAKU_BI,0) YOGOGAKO_TENGAKU_BI
               ,NVL(A.YOGOGAKO_TAIGAKU_BI,0) YOGOGAKO_TAIGAKU_BI
               ,NVL(A.YOGOGAKO_SOTSUGYO_BI,0) YOGOGAKO_SOTSUGYO_BI
               ,A.CHOHYO_NO NCHOHYO_NO
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
               ,NVL(A.KUNISHIRITSU_CD,0) KUNISHIRITSU_CD
               ,NVL(A.KUNISHIRITSU_TENGAKU_BI,0)  KUNISHIRITSU_TENGAKU_BI
               ,NVL(A.KUNISHIRITSU_TAIGAKU_BI,0)  KUNISHIRITSU_TAIGAKU_BI
               ,NVL(A.KUNISHIRITSU_SOTSUGYO_BI,0) KUNISHIRITSU_SOTSUGYO_BI
--  2024/06/03 ZCZL.ZHANGLEI ADD END
          FROM GKBTGAKUREIBO A,
               GABTATENAKIHON B1,
               GABTATENAKIHON B2,
               GKBTTSUCHISHOJKN C,
               GKBTZOKUGARA F1,
               GKBTZOKUGARA F2,
               GKBTZOKUGARA F3,
               GKBTZOKUGARA F4
         WHERE A.HOGOSYA_KOJIN_NO = B2.KOJIN_NO(+)
           AND A.HOGOSYA_ZOKUGARA1 = F1.ZOKUGARA_CD(+)
           AND A.HOGOSYA_ZOKUGARA2 = F2.ZOKUGARA_CD(+)
           AND A.HOGOSYA_ZOKUGARA3 = F3.ZOKUGARA_CD(+)
           AND A.HOGOSYA_ZOKUGARA4 = F4.ZOKUGARA_CD(+)
           AND A.RIREKI_RENBAN = p_RirekiRenban
           AND B1.KOJIN_NO = p_KojinNo
           AND B1.KOJIN_NO = A.KOJIN_NO(+)
--  2024/06/04 ZCZL.ZHANGLEI UPDATE 0.3.000.000:新WizLIFE２次開発
           --AND C.CHOHYO_KBN(+) = c_CHOHYO_KBN
           AND C.CHOHYO_KBN(+) = g_vCHOHYO_KBN
           AND A.SYOGAKO_CD = C.GAKO_CD(+)
           AND F1.ZOKUGARA_KBN(+) = 2
           AND F2.ZOKUGARA_KBN(+) = 2
           AND F3.ZOKUGARA_KBN(+) = 2
           AND F4.ZOKUGARA_KBN(+) = 2;
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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

    --------------------------------------------------------------------------------------------------
    --  機能概要      : 教育委員会連絡先を取得
    --  パラメータ    : i_SEIGYORENBAN
    --                  i_EQNAME
    --                  i_EQTELNO
    --                  i_EQNAISENNO
    --  モジュール区分: 内部関数
    --  戻り値        : 文字列
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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
    --  機能概要      : 市町村名取得
    --  パラメータ    : o_USERMEI
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
    --------------------------------------------------------------------------------
    PROCEDURE PROC_GET_USER(o_USERMEI OUT NVARCHAR2) IS
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
    BEGIN
      I_RTN := KKAPK0030.FKYOTU(i_IKIJYUNBI, o_IUSER_ID, o_IGAPPEI_BI,
                                o_IJICHI_CD, o_IUSER_KBN,
                                o_VKENMEI, o_VGUNSHIMEI, o_VUSERMEI,
                                o_VSHUCHOMEI,o_VSHUCHONINSHOBUN,
                                o_VYUBIN_NO, o_VSHOZAICHI, o_VTEL_NO);
      o_USERMEI := o_VUSERMEI;
    END PROC_GET_USER;
    --------------------------------------------------------------------------------
    --  機能概要      : 日付変換
    --  パラメータ    : i_YMD
    --                  o_YMD
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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
--  2024/06/28 ZCZL.qinyue Delete start 0.3.000.000:新WizLIFE２次開発
/*
    --------------------------------------------------------------------------------
    --  機能概要      : 制御のフラグをセットするのを行う
    --  パラメータ    : i_KOJIN_NO
    --                  o_NAIYO_CD
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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
           AND CHOHYO_ID = 'GKB010R001';
        IF o_NAIYO_CD = 0 THEN
          ZERO_FLG  := TRUE;
        END IF;
      EXCEPTION
        --データを取得しない場合
        WHEN NO_DATA_FOUND THEN
        NODATAFOUND_FLG  := TRUE;
      END;
      --氏名印字.制御ﾊﾟﾗﾒｰﾀ(4)が1の場合
      IF o_SHIMEIPRM(4) = 1 THEN
        BPRMFLG_001  := TRUE;
      END IF;
      --本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(4)が4、6場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(4) IN (4, 6) THEN
          BPRMFLG_002  := TRUE;
        END IF;
      END IF;
      -- 本名使用制御管理情報が存在する、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(4)が3、4、5、6場合
      IF NOT NODATAFOUND_FLG AND NOT ZERO_FLG THEN
        IF o_SHIMEIPRM(4) IN(3,4,5,6) THEN
          BPRMFLG_003  := TRUE;
        END IF;
      END IF;
        -- 本名使用制御管理情報が存在しない、かつ氏名印字.制御ﾊﾟﾗﾒｰﾀ(4)が4、5場合
      IF NODATAFOUND_FLG OR ZERO_FLG THEN
        IF o_SHIMEIPRM(4) IN (4, 5) THEN
          BPRMFLG_004  := TRUE;
        END IF;
      END IF;
    RETURN 0;
    END FUNC_PRMFLGSET;
    --------------------------------------------------------------------------------
    --  機能概要      : 日付変換2
    --  パラメータ    : i_KBN
    --                  i_YMD
    --                  o_YMD
    --  モジュール区分: 内部関数
    --  戻り値        : なし
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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
              --GKBPK00010.GKBFYMDEDT1より取得した表示生年月日
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
    --  機能概要      : 制御を行う
    --  パラメータ    : i_HONMYO
    --                  i_SHIMEI
    --                  o_SET
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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
--  2024/06/28 ZCZL.qinyue Delete end
    --------------------------------------------------------------------------------
    --  機能概要      : レコードの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
    --------------------------------------------------------------------------------
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
--  2024/06/03 ZCZL.ZHANGLEI DELETE START 0.3.000.000:新WizLIFE２次開発
      -- 児童生年月日
--       JIDO_BTH_IN          PLS_INTEGER;
--  2024/06/03 ZCZL.ZHANGLEI DELETE END
      --児童年齢
      INENREI              PLS_INTEGER;
--  2024/06/03 ZCZL.ZHANGLEI DELETE START 0.3.000.000:新WizLIFE２次開発
      -- 出力用児童生年月日
--       JIDO_BTH_OUT         NVARCHAR2(11);
--  2024/06/03 ZCZL.ZHANGLEI DELETE END
      -- 出力用発送日
      HASSOBI_OUT          NVARCHAR2(11);
      --出力用児童年齢
      NENREI_OUT           NVARCHAR2(3);
      -- 出力用郵便番号
      YUBIN_NO_OUT         NVARCHAR2(10);   -- 保護者郵便番号
      JIDO_YUBIN_NO_OUT    NVARCHAR2(10);   --児童郵便番号
      -- 日付
      DATE_IN              PLS_INTEGER;
      -- 出力用日付
      DATE1_OUT            NVARCHAR2(11);
      DATE2_OUT            NVARCHAR2(11);
      DATE3_OUT            NVARCHAR2(11);
      DATE4_OUT            NVARCHAR2(11);
      DATE5_OUT            NVARCHAR2(11);
      -- 市町村名
--  2025/05/15 CTC.LIUJUNHAO ADD START 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応      
      --USER_MEI             NVARCHAR2(40);
      USER_MEI             NVARCHAR2(100);
--  2025/05/15 CTC.LIUJUNHAO ADD END 1.0.004.000:GKB_QA13659_教育委員会連絡先が20桁以上の場合異常終了対応  
      VDATE_MEI1           NVARCHAR2(40);
      VDATE_MEI2           NVARCHAR2(40);
      VDATE_MEI3           NVARCHAR2(40);
      VDATE_MEI4           NVARCHAR2(40);
      VDATE_MEI5           NVARCHAR2(40);
      VKOMOKU_MEI1         NVARCHAR2(40);
      VKOMOKU_MEI2         NVARCHAR2(40);
      VKOMOKU_MEI3         NVARCHAR2(40);
      VKOMOKU_MEI4         NVARCHAR2(40);
      VKOMOKU_MEI5         NVARCHAR2(40);
      VKOMOKU_MEI6         NVARCHAR2(40);
      VKOMOKU_MEI7         NVARCHAR2(40);
      VKOMOKU_MEI8         NVARCHAR2(40);
      VKOMOKU_MEI9         NVARCHAR2(40);
      VKOMOKU_MEI10        NVARCHAR2(40);
      -- 宛名情報取得用
      RATENA_HOGOSHA GABTATENAKIHON%ROWTYPE;
      RSOFU_HOGOSHA  GABTSOFUSAKI%ROWTYPE;
      -- 児童宛名情報取得用
      RATENA_JIDO    GABTATENAKIHON%ROWTYPE;
      RSOFU_JIDO     GABTSOFUSAKI%ROWTYPE;
      VJIDO_YUBIN_NO        NVARCHAR2(10);  -- 児童郵便番号
      VJIDO_YUBIN_NOBC      NVARCHAR2(30);  -- 児童郵便番号ＢＣ
      VJIDO_CHOMEI          NVARCHAR2(40);  -- 児童町名
      VJIDO_BANCHI          NVARCHAR2(40);  -- 児童番地
      VJIDO_KATAGAKI        NVARCHAR2(60);  -- 児童方書
      VHOGO_YUBIN_NO        NVARCHAR2(10);  -- 保護者郵便番号
      VHOGO_YUBIN_NOBC      NVARCHAR2(30);  -- 保護者郵便番号ＢＣ
      VHOGO_CHOMEI          NVARCHAR2(40);  -- 保護者町名
      VHOGO_BANCHI          NVARCHAR2(40);  -- 保護者番地
      VHOGO_KATAGAKI        NVARCHAR2(60);  -- 保護者方書
--  2024/12/10 JPJYS.LIUHUAIQI ADD 0.3.000.007:品質強化：IT_GKB_00001対応 START
      VSOFU_ATENA           NVARCHAR2(100); -- 送付先宛名
--  2024/12/10 JPJYS.LIUHUAIQI ADD 0.3.000.007:品質強化：IT_GKB_00001対応 END
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 Start
      VSEINENGABI           NVARCHAR2(100);   --生年月日
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 End
      NSHIMEI_KANJI         NVARCHAR2(100); -- 氏名漢字
      rRECODE               GKBWL010R001%ROWTYPE;
      nCOUNT                NUMBER := 0;
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
      vCHOMEI_BANCHI        NVARCHAR2(1000); -- 住所マスク文字列
--  2024/09/04 ZCZL.JIANGJUN ADD 0.3.000.002:8月1日認識合わせの横展開
      vCHOMEI_BANCHI1       NVARCHAR2(1000);
      nPRMCTL               NUMBER;
      vDUMMY                NVARCHAR2(1000);
      VKOIN_SHORYAKU        NVARCHAR2(1000); --公印省略
      VKOIN_CHUSHAKU        NVARCHAR2(1000); --公印注釈
      VTSUCHIBUN            NVARCHAR2(1000); --通知文
      VCHOHYO_MEI           NVARCHAR2(1000); --帳票名
      VBIKO_TITLE           NVARCHAR2(1000); --備考タイトル
      VYOSHIKI_BANGO_SETTOGO    NVARCHAR2(1000); --様式番号接頭語
      NYOSHIKI_BANGO            NUMBER;          --様式番号
      VYOSHIKI_BANGO_SETSUBIGO  NVARCHAR2(1000); --様式番号接尾語
--  2024/06/03 ZCZL.ZHANGLEI ADD END
    BEGIN
      -- 正常終了
      IFRET := c_ISUCCESS;
       NSHIMEI_KANJI := NULL;                      --氏名漢字
      BEGIN
        -- 収発名を取得する
        BEGIN
          SELECT SHUHATS_MEI
                ,DATE_MEI1,DATE_MEI2,DATE_MEI3,DATE_MEI4,DATE_MEI5,
                 KOMOKU_MEI1,KOMOKU_MEI2,KOMOKU_MEI3,KOMOKU_MEI4,KOMOKU_MEI5,
                 KOMOKU_MEI6,KOMOKU_MEI7,KOMOKU_MEI8,KOMOKU_MEI9,KOMOKU_MEI10
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
                ,KOIN_SHORYAKU,KOIN_CHUSHAKU,TSUCHIBUN,CHOHYO_MEI,BIKO_TITLE,YOSHIKI_BANGO_SETTOGO,YOSHIKI_BANGO,YOSHIKI_BANGO_SETSUBIGO
            INTO VSYUHATU_MEI
                ,VDATE_MEI1,VDATE_MEI2,VDATE_MEI3,VDATE_MEI4,VDATE_MEI5,
                 VKOMOKU_MEI1,VKOMOKU_MEI2,VKOMOKU_MEI3,VKOMOKU_MEI4,VKOMOKU_MEI5,
                 VKOMOKU_MEI6,VKOMOKU_MEI7,VKOMOKU_MEI8,VKOMOKU_MEI9,VKOMOKU_MEI10
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
                ,VKOIN_SHORYAKU,VKOIN_CHUSHAKU,VTSUCHIBUN,VCHOHYO_MEI,VBIKO_TITLE,VYOSHIKI_BANGO_SETTOGO,NYOSHIKI_BANGO,VYOSHIKI_BANGO_SETSUBIGO
           FROM GKBTTSUCHISHOKANRI
             WHERE CHOHYO_KBN = c_CHOHYO_KBN;
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
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
            VKOIN_SHORYAKU := '';
            VKOIN_CHUSHAKU := '';
            VTSUCHIBUN     := '';
            VCHOHYO_MEI    := '';
            VBIKO_TITLE    := '';
            VYOSHIKI_BANGO_SETTOGO := '';
            NYOSHIKI_BANGO := '';
            VYOSHIKI_BANGO_SETSUBIGO := '';
--  2024/06/03 ZCZL.ZHANGLEI ADD END
        END;
        -- カーソルのオープン
        OPEN GAKUREIBO(g_NKOJIN_NO, g_NRIREKI_RENBAN);
        -- レコード参照
        FETCH GAKUREIBO INTO RECGAKUREIBO;
        -- ループ開始
        LOOP
          -- 読むレコードが無い場合ループから抜け出す
          EXIT WHEN GAKUREIBO%NOTFOUND;
          IF g_NHASSO_BI > 0 THEN
            -- 保護者宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(RECGAKUREIBO.HOGOSYA_KOJIN_NO, 'GKB', g_NHASSO_BI,
                                       RATENA_HOGOSHA, RSOFU_HOGOSHA);
            -- 児童宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(g_NKOJIN_NO, 'GKB', g_NHASSO_BI,
                                       RATENA_JIDO, RSOFU_JIDO);
          ELSE
            -- 保護者宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(RECGAKUREIBO.HOGOSYA_KOJIN_NO, 'GKB', ISAKUSEIBI,
                                       RATENA_HOGOSHA, RSOFU_HOGOSHA);
            -- 児童宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(g_NKOJIN_NO, 'GKB', ISAKUSEIBI,
                                       RATENA_JIDO, RSOFU_JIDO);
          END IF;
--  2024/06/28 ZCZL.qinyue Delete 0.3.000.000:新WizLIFE２次開発
--       I_RTN  := FUNC_PRMFLGSET(RATENA_JIDO.KOJIN_NO,N_NAIYO_CD);
          -- 続柄フラグの初期化
          ZOKUGARA_FLAG := TRUE;
          -- 続柄の初期化
          ZOKUGARA := '';
          -- ４回ループする
          FOR IDX IN 1..4 LOOP
            -- ループ変数による分岐
            CASE IDX
              -- 続柄１
              WHEN 1 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI1;
              -- 続柄２
              WHEN 2 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI2;
              -- 続柄３
              WHEN 3 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI3;
              -- 続柄４
              WHEN 4 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI4;
            END CASE;
            -- 取得した続柄が存在する場合
            IF ZOKUGARA_IN <> ' ' THEN
              -- 続柄が設定されていない場合
              IF ZOKUGARA_FLAG = TRUE THEN
                -- 続柄フラグを設定
                ZOKUGARA_FLAG := FALSE;
                -- 続柄を設定
                ZOKUGARA := ZOKUGARA_IN;
              -- 続柄が設定されている場合
              ELSE
                -- 続柄を付与する
                ZOKUGARA := ZOKUGARA || 'の' || ZOKUGARA_IN;
              END IF;
            END IF;
          END LOOP;

          -- 児童住所
          IF RSOFU_JIDO.KOJIN_NO > 0 AND
             (RSOFU_HOGOSHA.TEKIYO_BI <= HASSO_BI )AND
             ((RSOFU_HOGOSHA.SHURYO_BI >= HASSO_BI) OR (RSOFU_HOGOSHA.SHURYO_BI = 0)) THEN
            VJIDO_YUBIN_NO    := RSOFU_JIDO.YUBIN_NO;
            VJIDO_YUBIN_NOBC  := RSOFU_JIDO.YUBIN_NOBC;
            VJIDO_CHOMEI      := RSOFU_JIDO.CHOMEI;
            VJIDO_BANCHI      := RSOFU_JIDO.BANCHI;
            VJIDO_KATAGAKI    := RSOFU_JIDO.KATAGAKI;
          ELSE
            VJIDO_YUBIN_NO    := RATENA_JIDO.YUBIN_NO;
            VJIDO_YUBIN_NOBC  := RATENA_JIDO.YUBIN_NOBC;
            VJIDO_CHOMEI      := RATENA_JIDO.CHOMEI;
            VJIDO_BANCHI      := RATENA_JIDO.BANCHI;
            VJIDO_KATAGAKI    := RATENA_JIDO.KATAGAKI;
          END IF;
          -- 検診票用の住所は宛名住所を使用
          JIDO_JUSHO := GAAPK0010.FADDRESSEDIT( 1, '',  RATENA_JIDO.CHOMEI ,RATENA_JIDO.BANCHI, RATENA_JIDO.KATAGAKI, '');
          -- 保護者住所
          IF RSOFU_HOGOSHA.KOJIN_NO > 0 AND
             (RSOFU_HOGOSHA.TEKIYO_BI <= HASSO_BI) AND
             ((RSOFU_HOGOSHA.SHURYO_BI >= HASSO_BI) OR (RSOFU_HOGOSHA.SHURYO_BI = 0)) THEN
            VHOGO_YUBIN_NO    := RSOFU_HOGOSHA.YUBIN_NO;
            VHOGO_YUBIN_NOBC  := RSOFU_HOGOSHA.YUBIN_NOBC;
            VHOGO_CHOMEI      := RSOFU_HOGOSHA.CHOMEI;
            VHOGO_BANCHI      := RSOFU_HOGOSHA.BANCHI;
            VHOGO_KATAGAKI    := RSOFU_HOGOSHA.KATAGAKI;
          ELSE
            VHOGO_YUBIN_NO    := RATENA_HOGOSHA.YUBIN_NO;
            VHOGO_YUBIN_NOBC  := RATENA_HOGOSHA.YUBIN_NOBC;
            VHOGO_CHOMEI      := RATENA_HOGOSHA.CHOMEI;
            VHOGO_BANCHI      := RATENA_HOGOSHA.BANCHI;
            VHOGO_KATAGAKI    := RATENA_HOGOSHA.KATAGAKI;
          END IF;
          -- 検診票用の住所は宛名住所を使用
          HOGO_JUSHO := GAAPK0010.FADDRESSEDIT( 1, '',  RATENA_HOGOSHA.CHOMEI , RATENA_HOGOSHA.BANCHI , RATENA_HOGOSHA.KATAGAKI, '');
--  2024/06/03 ZCZL.ZHANGLEI DELETE START 0.3.000.000:新WizLIFE２次開発
          -- 児童生年月日の取得
--           JIDO_BTH_IN := RECGAKUREIBO.SEINENGAPI;
          -- 出力用児童生年月日の取得
--           PROC_GET_YMD(JIDO_BTH_IN, JIDO_BTH_OUT);
--           IF (RATENA_JIDO.JINKAKU_KBN != 0) THEN
--               PROC_GET_YMD1(RATENA_JIDO.JINKAKU_KBN,JIDO_BTH_IN, JIDO_BTH_OUT);
--           END IF;
--  2024/06/03 ZCZL.ZHANGLEI DELETE END
          -- 児童年齢の取得
          VKIJUNBI := (KKAPK0020.FDAYNENDO(g_NHASSO_BI,0) + 1) * 10000 + 101;
          IF RECGAKUREIBO.SEINENGAPI = 0 THEN
            INENREI := NULL;
          ELSE
            INENREI := KKAPK0020.FAgeGet(RECGAKUREIBO.SEINENGAPI, VKIJUNBI);
          END IF;
          NENREI_OUT :=  TO_CHAR(INENREI);
          -- 発送日の取得
          PROC_GET_YMD(g_NHASSO_BI, HASSOBI_OUT);
          NNENDO := KKAPK0020.FDAYNENDO(g_NHASSO_BI,0);
          IF NVL(NNENDO,0) = 0 THEN
            VHYOUJINENDO := '';
          ELSE
            PROC_GET_YMD(NNENDO * 10000 + 401,VHYOUJINENDO);
            VHYOUJINENDO := SUBSTR(VHYOUJINENDO,1,4);
          END IF;
          --市町村名の取得
          PROC_GET_USER(USER_MEI);
          --郵便番号
          IF LENGTH(VHOGO_YUBIN_NO) > 0 THEN
            YUBIN_NO_OUT := SUBSTR(VHOGO_YUBIN_NO,1,3)||'-'||SUBSTR(VHOGO_YUBIN_NO,4);
            YUBIN_NO_OUT := TRANSLATE(YUBIN_NO_OUT, '1234567890-', '１２３４５６７８９０－');
          ELSE
            YUBIN_NO_OUT := NULL;
          END IF;
           GYOSEIKUMEI := GAAPK0030.FGYOSEIKUMEI(RATENA_JIDO.SANTEIDANTAI_CD,RATENA_JIDO.GYOSEIKU_CD);
          IF RECGAKUREIBO.SYOGAKO_CD != 0 AND RECGAKUREIBO.SYOGAKO_TENGAKU_BI = 0 AND RECGAKUREIBO.SYOGAKO_SOTSUGYO_BI = 0 THEN
            GAKOKU_CD := RECGAKUREIBO.SYOGAKO_CD;
          ELSIF RECGAKUREIBO.KUIKIGAI_CD != 0 AND RECGAKUREIBO.KUIKIGAI_TENGAKU_BI = 0 AND RECGAKUREIBO.KUIKIGAI_TAIGAKU_BI = 0 AND RECGAKUREIBO.KUIKIGAI_SOTSUGYO_BI = 0 THEN
            GAKOKU_CD := RECGAKUREIBO.KUIKIGAI_CD;
          ELSIF RECGAKUREIBO.YOGOGAKO_CD != 0 AND RECGAKUREIBO.YOGOGAKO_TENGAKU_BI = 0 AND RECGAKUREIBO.YOGOGAKO_TAIGAKU_BI = 0 AND RECGAKUREIBO.YOGOGAKO_SOTSUGYO_BI = 0 THEN
            GAKOKU_CD := RECGAKUREIBO.YOGOGAKO_CD;
          ELSE
            GAKOKU_CD := ' ';
          END IF;
          IF RECGAKUREIBO.SYOGAKO_CD != 0 AND RECGAKUREIBO.SYOGAKO_TENGAKU_BI = 0 AND RECGAKUREIBO.SYOGAKO_SOTSUGYO_BI = 0 THEN
            BEGIN
              SELECT SYOGAKOMEI INTO GAKOKUMEI_2 FROM GKBTSHOGAKKO WHERE SYOGAKO_CD = GAKOKU_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
               GAKOKUMEI_1 := NULL;
            END;
            GAKOKUMEI_1 := GAKOKUMEI_2;
          ELSIF RECGAKUREIBO.KUIKIGAI_CD != 0 AND RECGAKUREIBO.KUIKIGAI_TENGAKU_BI = 0 AND RECGAKUREIBO.KUIKIGAI_TAIGAKU_BI = 0 AND RECGAKUREIBO.KUIKIGAI_SOTSUGYO_BI = 0 THEN
            BEGIN
              SELECT KUIKIGAIMEI INTO GAKOKUMEI_2 FROM GKBTKUIKIGAI WHERE KUIKIGAI_CD = GAKOKU_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
               GAKOKUMEI_1 := NULL;
            END;
            GAKOKUMEI_1 := GAKOKUMEI_2;
          ELSIF RECGAKUREIBO.YOGOGAKO_CD != 0 AND RECGAKUREIBO.YOGOGAKO_TENGAKU_BI = 0 AND RECGAKUREIBO.YOGOGAKO_TAIGAKU_BI = 0 AND RECGAKUREIBO.YOGOGAKO_SOTSUGYO_BI = 0 THEN
            BEGIN
              SELECT YOGOGAKOMEI INTO GAKOKUMEI_2 FROM GKBTYOGOGAKKO WHERE YOGOGAKO_CD = GAKOKU_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
               GAKOKUMEI_1 := NULL;
            END;
            GAKOKUMEI_1 := GAKOKUMEI_2;
          ELSE
            GAKOKUMEI_1 := ' ';
          END IF;
          -- 児童郵便番号
          IF LENGTH(VJIDO_YUBIN_NO) > 0 THEN
            JIDO_YUBIN_NO_OUT := SUBSTR(VJIDO_YUBIN_NO,1,3)||'-'||SUBSTR(VJIDO_YUBIN_NO,4);
            JIDO_YUBIN_NO_OUT := TRANSLATE(JIDO_YUBIN_NO_OUT, '1234567890-', '１２３４５６７８９０－');
          ELSE
            JIDO_YUBIN_NO_OUT := NULL;
          END IF;
          -- 日付の取得
          DATE_IN := RECGAKUREIBO.IDATE1;
          PROC_GET_YMD(DATE_IN, DATE1_OUT);
          DATE_IN := RECGAKUREIBO.IDATE2;
          PROC_GET_YMD(DATE_IN, DATE2_OUT);
          DATE_IN := RECGAKUREIBO.IDATE3;
          PROC_GET_YMD(DATE_IN, DATE3_OUT);
          DATE_IN := RECGAKUREIBO.IDATE4;
          PROC_GET_YMD(DATE_IN, DATE4_OUT);
          DATE_IN := RECGAKUREIBO.IDATE5;
          PROC_GET_YMD(DATE_IN, DATE5_OUT);
          -- 連番
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.007:IT_GKB_00539横展開対応
          --nCOUNT := nCOUNT + 1;
          rRECODE := NULL;
--  2024/11/15 ZCZL.WANGYUNING UPDATE 0.3.000.007:IT_GKB_00539横展開対応
          --rRECODE.NO                       := nCOUNT;                    --ソート順
          rRECODE.NENDO                    := VHYOUJINENDO;              --年度
          rRECODE.KAIPAGE_CD               := NULL;                      --改頁コード
          rRECODE.KAIPAGE                  := NULL;                      --改頁
          rRECODE.SAKUSEIBI                := NULL;                      --作成日
          rRECODE.RENBAN                   := '1';                       --連番
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
          rRECODE.BUNSHO_NO := g_vBUNSHO_NO;                 --文書番号
--  2024/06/03 ZCZL.ZHANGLEI UPDATE START 0.3.000.000:新WizLIFE２次開発
          /*-- 児童氏名かな
          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
            I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANA,RATENA_JIDO.SHIMEI_KANA,RECGAKUREIBO.SHIMEI_KANA);
          END IF;
          rRECODE.JIDO_SHIMEI_KANA         := RECGAKUREIBO.SHIMEI_KANA;              --就学予定者氏名かな
          -- 児童氏名漢字
          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
            I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,RECGAKUREIBO.SHIMEI_KANJI);
          END IF;
          rRECODE.JIDO_SHIMEI_KANJI        := RECGAKUREIBO.SHIMEI_KANJI;              --児童氏名漢字
          rRECODE.KANJI_SEINENGAPI         := NULL;                                   --漢字生年月日*/
          I_RTN := GKBFKHMCTRL(RATENA_JIDO.KOJIN_NO,g_rOPRT.Chohyoid,0,g_vGKB010_CTL,rRECODE.JIDO_SHIMEI_KANA,   -- 児童氏名かな
                                                                                     rRECODE.JIDO_SHIMEI_KANJI,  -- 児童氏名漢字
                                                                                     rRECODE.KANJI_SEINENGAPI);  --漢字生年月日
--  2024/06/03 ZCZL.ZHANGLEI UPDATE END
          -- 児童性別
          rRECODE.SEIBETSU                 := RECGAKUREIBO.SEIBETSU;                  --性別
          rRECODE.HOGOSHA_SHIMEI_JODAN     := NULL;                                   --保護者氏名上段
          rRECODE.HOGOSHA_SHIMEI_GEDAN     := NULL;                                   --保護者氏名下段
          rRECODE.JUSHO_JODAN              := NULL;                                   --住所上
          rRECODE.JUSHO_GEDAN              := NULL;                                   --住所下
          rRECODE.GYOSEIKU_MEI             := GYOSEIKUMEI;                            --行政区名
          -- 学校名
          GAKOKUMEI := GAKOKUMEI_1;
          rRECODE.GAKKOKU_MEI              := GAKOKUMEI;                              --学校区名
          rRECODE.SANTEIDANTAI_MEI         := NULL;                                   --算定団体名
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
          vCHOMEI_BANCHI := GAAPK0010.FADDRESSEDIT( 1, NULL,  VHOGO_CHOMEI ,VHOGO_BANCHI, NULL, NULL);
--  2024/09/04 ZCZL.JIANGJUN UPDATE START 0.3.000.002:8月1日認識合わせの横展開
--          vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', RECGAKUREIBO.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vCHOMEI_BANCHI, nPRMCTL, 2);
          -- 支援措置対象住所非表示＝0(有)、DV該当の場合
--          IF g_nSHIENSOCHIKBN = 1 AND nPRMCTL = 1 THEN
--            rRECODE.ATESAKI_YUBIN_NO         := '';             --宛先郵便番号
--            rRECODE.ATESAKI_CHOMEI_BANCHI    := vCHOMEI_BANCHI; --宛先町名番地
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
          --vCHOMEI_BANCHI1 := GAAPK0030.FDVJUSHO('GKB', RECGAKUREIBO.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vCHOMEI_BANCHI, nPRMCTL, 2);
          --IF g_nSHIENSOCHIKBN = 1 AND nPRMCTL = 1 THEN
          IF g_nSHIENSOCHIKBN = 1  THEN
            vCHOMEI_BANCHI1 := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
            rRECODE.ATESAKI_YUBIN_NO         := '';              --宛先郵便番号
            rRECODE.ATESAKI_CHOMEI_BANCHI    := vCHOMEI_BANCHI1; --宛先町名番地
--  2024/09/04 ZCZL.JIANGJUN UPDATE END
            rRECODE.ATESAKI_KATAGAKI         := '';             --宛先方書
          ELSE
--  2024/06/03 ZCZL.ZHANGLEI ADD END
          -- 郵便番号
          rRECODE.ATESAKI_YUBIN_NO         := YUBIN_NO_OUT;                           --宛先郵便番号
          -- 町名番地
--  2024/09/04 ZCZL.JIANGJUN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--          rRECODE.ATESAKI_CHOMEI_BANCHI    := VHOGO_CHOMEI || VHOGO_BANCHI;           --宛先町名番地
          rRECODE.ATESAKI_CHOMEI_BANCHI    := vCHOMEI_BANCHI;
          -- 方書
          rRECODE.ATESAKI_KATAGAKI         := VHOGO_KATAGAKI;                         --宛先方書
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
          END IF;
--  2024/06/03 ZCZL.ZHANGLEI UPDATE START 0.3.000.000:新WizLIFE２次開発
--             IF o_ATENA_PRM(1) IN (1,3) THEN
--                   IF (RSOFU_JIDO.KOJIN_NO > 0) AND
--                          (RSOFU_JIDO.TEKIYO_BI <= HASSO_BI) AND
--                          (RSOFU_JIDO.SHURYO_BI >= HASSO_BI OR RSOFU_JIDO.SHURYO_BI = 0) THEN
--                          IF RSOFU_JIDO.SHIMEI_KANJI IS NOT NULL THEN
--                             NSHIMEI_KANJI := RSOFU_JIDO.SHIMEI_KANJI;
--                          ELSE
--                             NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
--                            IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
--                              I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
--                            END IF;
--                          END IF;
--                       ELSE
--                          NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
--                          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
--                            I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
--                          END IF;
--                       END IF;
--                        IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
--                           IF o_ATENA_PRM(3) = 1 THEN
--                              ATESAKI_JODAN := ' (' ||NSHIMEI_KANJI ||'　様) ';
--                           ELSE
--                              ATESAKI_JODAN := NSHIMEI_KANJI||'　様';
--                           END IF;
--                        ELSE
--                           ATESAKI_JODAN := '';
--                        END IF;
--             ELSE
--            処理条件９(宛先制御.制御ﾊﾟﾗﾒｰﾀ(1)=1,3 以外の場合)
--                   IF (RSOFU_HOGOSHA.KOJIN_NO > 0)
--                          AND (RSOFU_HOGOSHA.TEKIYO_BI <= HASSO_BI)
--                          AND (RSOFU_HOGOSHA.SHURYO_BI >= HASSO_BI
--                          OR RSOFU_HOGOSHA.SHURYO_BI = 0) THEN
--                          IF RSOFU_HOGOSHA.SHIMEI_KANJI IS NOT NULL THEN
--                             NSHIMEI_KANJI := RSOFU_HOGOSHA.SHIMEI_KANJI;
--                          ELSE
--                             NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
--                            IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
--                              I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                            END IF;
--                          END IF;
--                       ELSE
--                           NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
--                          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
--                            I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                          END IF;
--                       END IF;
--                       IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
--                          IF o_ATENA_PRM(2) = 1 THEN
--                             ATESAKI_JODAN := '(' ||NSHIMEI_KANJI||'　様)';
--                          ELSE
--                             ATESAKI_JODAN := NSHIMEI_KANJI||'　様';
--                          END IF;
--                       ELSE
--                          ATESAKI_JODAN := '';
--                       END IF;
--             END IF;
--             IF o_ATENA_PRM(1) IN (2,3) THEN
--                  IF o_ATENA_PRM(1) = 2 THEN
--                  IF (RSOFU_JIDO.KOJIN_NO > 0) AND
--                         (RSOFU_JIDO.TEKIYO_BI <= HASSO_BI) AND
--                         (RSOFU_JIDO.SHURYO_BI >= HASSO_BI OR RSOFU_JIDO.SHURYO_BI = 0) THEN
--                         IF RSOFU_JIDO.SHIMEI_KANJI IS NOT NULL THEN
--                            NSHIMEI_KANJI := RSOFU_JIDO.SHIMEI_KANJI;
--                         ELSE
--                            NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
--                            IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
--                              I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
--                            END IF;
--                         END IF;
--                      ELSE
--                            NSHIMEI_KANJI := RATENA_JIDO.SHIMEI_KANJI;
--                            IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
--                              I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,NSHIMEI_KANJI);
--                            END IF;
--                      END IF;
--                      IF o_ATENA_PRM(3) = 1 THEN
--                        ATESAKI_GEDAN := '(' ||NSHIMEI_KANJI||'　様)';
--                      ELSE
--                        ATESAKI_GEDAN := NSHIMEI_KANJI||'　様';
--                      END IF;
--                  ELSE
--                 IF (RSOFU_HOGOSHA.KOJIN_NO > 0)
--                        AND (RSOFU_HOGOSHA.TEKIYO_BI <= HASSO_BI)
--                        AND (RSOFU_HOGOSHA.SHURYO_BI >= HASSO_BI
--                         OR RSOFU_HOGOSHA.SHURYO_BI = 0) THEN
--                        IF RSOFU_HOGOSHA.SHIMEI_KANJI IS NOT NULL THEN
--                           NSHIMEI_KANJI := RSOFU_HOGOSHA.SHIMEI_KANJI;
--                        ELSE
--                           NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
--                          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
--                            I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                          END IF;
--                        END IF;
--                     ELSE
--                         NSHIMEI_KANJI := RATENA_HOGOSHA.SHIMEI_KANJI;
--                        IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
--                          I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,NSHIMEI_KANJI);
--                        END IF;
--                     END IF;
--                     IF LENGTH(TRIM(NSHIMEI_KANJI)) > 0 THEN
--                       IF o_ATENA_PRM(2) = 1 THEN
--                         ATESAKI_GEDAN := '(' ||NSHIMEI_KANJI||'　様)';
--                       ELSE
--                       ATESAKI_GEDAN := NSHIMEI_KANJI||'　様';
--                       END IF;
--                     END IF;
--                 END IF;
--             ELSE
--                   ATESAKI_GEDAN := '';
--             END IF;
--          rRECODE.ATESAKI_JODAN            := ATESAKI_JODAN;           --宛先上段
--           rRECODE.ATESAKI_GEDAN            := ATESAKI_GEDAN;           --宛先下段
          -- 児童生年月日
--           rRECODE.SEINENGAPI               := JIDO_BTH_OUT;           --生年月日
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:品質強化：IT_GKB_00001対応 START
          I_RTN := GKBFKHMCTRL(RATENA_JIDO.KOJIN_NO, g_rOPRT.Chohyoid, 1, g_vGKB010_CTL, vDUMMY,
--                                                                                     rRECODE.ATESAKI_JODAN,  --宛先上段
                                                                                     VSOFU_ATENA,
--  2024/09/04 ZCZL.JIANGJUN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--                                                                                     vDUMMY);
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 Start
                                                                                     --rRECODE.SEINENGAPI);
                                                                                     vDUMMY);
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 End
          rRECODE.ATESAKI_JODAN            := VSOFU_ATENA ||'　様';      --宛先上段
--  2024/12/10 JPJYS.LIUHUAIQI UPDATE 0.3.000.007:品質強化：IT_GKB_00001対応 END
          rRECODE.ATESAKI_GEDAN            := NULL;                     --宛先下段
--  2024/09/04 ZCZL.JIANGJUN DEL 0.3.000.002:8月1日認識合わせの横展開
--          rRECODE.SEINENGAPI               := vDUMMY;                   --生年月日
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 Start
I_RTN := GKBFKHMCTRL(RATENA_JIDO.KOJIN_NO, g_rOPRT.Chohyoid, 0, g_vGKB010_CTL, vDUMMY,
                                                                               vDUMMY,
                                                                               rRECODE.SEINENGAPI);
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 End
--  2024/06/03 ZCZL.ZHANGLEI ADD END
          -- 児童年齢
          rRECODE.NENREI                   := NULL;                     --年齢
          -- 児童住所
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
--  2024/09/04 ZCZL.JIANGJUN UPDATE START 0.3.000.002:8月1日認識合わせの横展開
--          vCHOMEI_BANCHI := GAAPK0010.FADDRESSEDIT( 1, NULL,  VHOGO_CHOMEI ,VHOGO_BANCHI, VHOGO_KATAGAKI, NULL);
--          vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', RECGAKUREIBO.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vCHOMEI_BANCHI, nPRMCTL, 2);

--          IF g_nSHIENSOCHIKBN = 1 AND nPRMCTL = 1 THEN
--            rRECODE.JIDO_JUSHO             := vCHOMEI_BANCHI; --宛先町名番地
--          ELSE
--  2024/06/03 ZCZL.ZHANGLEI ADD END
--          rRECODE.JIDO_JUSHO               := JIDO_JUSHO;              --児童現住所
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
--          END IF;
          vCHOMEI_BANCHI  := GAAPK0010.FADDRESSEDIT( 1, NULL, VJIDO_CHOMEI ,VJIDO_BANCHI, VJIDO_KATAGAKI, NULL);
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
          --vCHOMEI_BANCHI1 := GAAPK0030.FDVJUSHO('GKB', RECGAKUREIBO.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vCHOMEI_BANCHI, nPRMCTL, 2);
          --IF g_nSHIENSOCHIKBN = 1 AND nPRMCTL = 1 THEN
          IF g_nSHIENSOCHIKBN = 1 THEN
            vCHOMEI_BANCHI1 := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
            rRECODE.JIDO_JUSHO             := vCHOMEI_BANCHI1;              --宛先町名番地
          ELSE
            rRECODE.JIDO_JUSHO             := vCHOMEI_BANCHI;               --児童現住所
          END IF;
--  2024/09/04 ZCZL.JIANGJUN UPDATE END
--  2024/06/03 ZCZL.ZHANGLEI UPDATE START 0.3.000.000:新WizLIFE２次開発
/*
          -- 保護者氏名かな
          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
            I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANA,RATENA_HOGOSHA.SHIMEI_KANA,RECGAKUREIBO.HOGOSYA_SHIMEI_KANA);
          END IF;
          rRECODE.HOGOSHA_SHIMEI_KANA      := RECGAKUREIBO.HOGOSYA_SHIMEI_KANA;              --保護者氏名カナ
          -- 保護者氏名漢字
          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
            I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI);
          END IF;
          rRECODE.HOGOSHA_SHIMEI_KANJI     := RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI;              --保護者氏名漢字*/
          I_RTN := GKBFKHMCTRL(RATENA_JIDO.KOJIN_NO, g_rOPRT.Chohyoid, 1, g_vGKB010_CTL,rRECODE.HOGOSHA_SHIMEI_KANA, --保護者氏名カナ
                                                                                     rRECODE.HOGOSHA_SHIMEI_KANJI,  --保護者氏名漢字
                                                                                     vDUMMY);
--  2024/06/03 ZCZL.ZHANGLEI UPDATE END
          -- 保護者住所
          rRECODE.CHOMEI_BANCHI_KATAGAKI   := HOGO_JUSHO;              --町名番地方書
          -- 続柄
--  2024/09/04 ZCZL.JIANGJUN UPDATE START 0.3.000.002:8月1日認識合わせの横展開
--          rRECODE.JIDO_ZOKUGARAMEI         := ZOKUGARA;              --児童との関係
--          USER_MEI := o_KYOIKUPRM(1);
--          rRECODE.KYOIKU_KAI_MEI           := USER_MEI;              --教育委員会名
          vCHOMEI_BANCHI := GAAPK0010.FADDRESSEDIT( 1, NULL,  VHOGO_CHOMEI ,VHOGO_BANCHI, VHOGO_KATAGAKI, NULL);
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
          --vCHOMEI_BANCHI1 := GAAPK0030.FDVJUSHO('GKB', RECGAKUREIBO.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vCHOMEI_BANCHI, nPRMCTL, 2);
          --IF g_nSHIENSOCHIKBN = 1 AND nPRMCTL = 1 THEN
          IF g_nSHIENSOCHIKBN =  1 THEN
            vCHOMEI_BANCHI1 := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
            rRECODE.JIDO_ZOKUGARAMEI             := vCHOMEI_BANCHI1;
          ELSE
            rRECODE.JIDO_ZOKUGARAMEI             := vCHOMEI_BANCHI;
          END IF;
          rRECODE.KYOIKU_KAI_MEI           := o_vKATAGAKI1;
--  2024/09/04 ZCZL.JIANGJUN UPDATE END
--  2024/09/04 ZCZL.JIANGJUN UPDATE Start 0.3.000.002:8月1日認識合わせの横展開
          -- 発送日
--          rRECODE.HASSOBI                  := HASSOBI_OUT;              --発送日
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 Start
          --rRECODE.HASSOBI                  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(g_sDATEED, 'YYYY/MM/DD'), 'YYYY/MM/DD'), 12);              --発送日
            rRECODE.HASSOBI                  := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(TO_NUMBER(REPLACE(g_sDATEED,'/','')),0,3),' ','')); --発送日
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 End
          -- 発送番号
--          rRECODE.SYUHATU_MEI              := VSYUHATU_MEI  ||  '第 '  ||  g_NHASSO_NO ||  ' 号';              --収発名
          rRECODE.SYUHATU_MEI              := NULL;              --収発名
--  2024/09/04 ZCZL.JIANGJUN UPDATE End
          -- 公印
          rRECODE.KOIN_PATH                := VGYOMU;    -- 業務毎公印ファイル名（.bmp）              --公印パス
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
--  2024/09/04 ZCZL.JIANGJUN UPDATE Start 0.3.000.002:8月1日認識合わせの横展開
--           IF VGYOMU = NULL THEN
--             rRECODE.KOIN_SHORYAKU := VKOIN_SHORYAKU; --公印（省略）
--             rRECODE.KOIN_CHUSHAKU := VKOIN_CHUSHAKU;  --公印（注釈）
--           ELSE
--             rRECODE.KOIN_SHORYAKU := NULL;  --公印（省略）
--             rRECODE.KOIN_CHUSHAKU := NULL;  --公印（注釈）
--           END IF;
          IF VGYOMU IS NULL THEN
            rRECODE.KOIN_SHORYAKU := VKOIN_SHORYAKU; --公印（省略）
            rRECODE.KOIN_CHUSHAKU := NULL;  --公印（注釈）
          ELSE
            rRECODE.KOIN_SHORYAKU := NULL;  --公印（省略）
            rRECODE.KOIN_CHUSHAKU := VKOIN_CHUSHAKU;  --公印（注釈）
          END IF;
--  2024/09/04 ZCZL.JIANGJUN UPDATE End
          rRECODE.CHOHYO_MEI := VCHOHYO_MEI;  --帳票名
          rRECODE.TSUCHIBUN := VTSUCHIBUN;    --通知文
--  2024/11/05 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00452対応
          --rRECODE.TOKKIJIKO := g_KAIJOU;      --特記事項
          rRECODE.TOKKIJIKO := g_sTOKUKIJIKO; --特記事項
--  2024/06/03 ZCZL.ZHANGLEI ADD END
          VTANTO_TEL := o_KYOIKUPRM(7);
          VTANTO_YUBIN_NO := SUBSTR(o_KYOIKUPRM(5),1,3) || '-' || SUBSTR(o_KYOIKUPRM(5),4);
          VTANTO_YUBIN_NO := TRANSLATE(VTANTO_YUBIN_NO, '1234567890-', '１２３４５６７８９０－');
          VTANTO_JUSHO := o_KYOIKUPRM(6);
          rRECODE.KYOIKU_TEL               := VTANTO_TEL;               --委員会電話番号
          rRECODE.KYOIKU_YUBIN_NO          := VTANTO_YUBIN_NO;          --委員会郵便番号
          rRECODE.KYOIKU_JUSHO             := VTANTO_JUSHO;             --委員会住所
          -- カスタマーバーコード
          rRECODE.HASSO_NO                 := VHOGO_YUBIN_NOBC;              --発送番号
--  2024/11/13 JPJYS.WENGSILIANG UPDATE 0.3.000.004:IT_GKB_00510対応 START
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00730対応 START
--          -- 日付１
--          rRECODE.DATE1                    := DATE1_OUT;              --日付１
          -- 日付１
--          rRECODE.DATE1                    := g_sTXTKANSADATE;        --日付１
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応
        -- PROC_GET_YMD(g_sTXTKANSADATE, TXTKANSADATE_OUT);
        --  rRECODE.DATE1                    := TXTKANSADATE_OUT;       --日付１
          rRECODE.DATE1                    := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(g_sTXTKANSADATE,0,3),' ',''));
--  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00730対応 END
--  2024/11/13 JPJYS.WENGSILIANG UPDATE 0.3.000.004:IT_GKB_00510対応 END
          -- 日付２
          rRECODE.DATE2                    := DATE2_OUT;              --日付2
          -- 日付３
          rRECODE.DATE3                    := DATE3_OUT;              --日付3
          -- 日付４
          rRECODE.DATE4                    := DATE4_OUT;              --日付4
          -- 日付５
          rRECODE.DATE5                    := DATE5_OUT;              --日付5
--  2024/11/13 JPJYS.WENGSILIANG UPDATE 0.3.000.004:IT_GKB_00510対応 START
--          -- 項目１
--          rRECODE.KOMOKU1                  := RECGAKUREIBO.VKOMOKU1 || ',';              --項目１
--          -- 項目２
--          rRECODE.KOMOKU2                  := RECGAKUREIBO.VKOMOKU2 || ',';              --項目2
--          -- 項目３
--          rRECODE.KOMOKU3                  := RECGAKUREIBO.VKOMOKU3 || ',';              --項目3
          -- 項目１
          rRECODE.KOMOKU1                  := g_nKAISHIJIKAN;                            --項目１
          -- 項目２
          rRECODE.KOMOKU2                  := g_nUKETSUKEJIKAN;                          --項目2
          -- 項目３
          rRECODE.KOMOKU3                  := g_KAIJOU;                                  --項目3
--  2024/11/13 JPJYS.WENGSILIANG UPDATE 0.3.000.004:IT_GKB_00510対応 END
          -- 項目４
          rRECODE.KOMOKU4                  := RECGAKUREIBO.VKOMOKU4 || ',';              --項目4
          -- 項目５
          rRECODE.KOMOKU5                  := RECGAKUREIBO.VKOMOKU5 || ',';              --項目5
          -- 項目６
          rRECODE.KOMOKU6                  := RECGAKUREIBO.VKOMOKU6 || ',';              --項目6
          -- 項目７
          rRECODE.KOMOKU7                  := RECGAKUREIBO.VKOMOKU7 || ',';              --項目7
          -- 項目８
          rRECODE.KOMOKU8                  := RECGAKUREIBO.VKOMOKU8 || ',';              --項目8
          -- 項目９
          rRECODE.KOMOKU9                  := RECGAKUREIBO.VKOMOKU9 || ',';              --項目9
          -- 項目１０
          rRECODE.KOMOKU10                 := RECGAKUREIBO.VKOMOKU10 || ',';             --項目１0
--  2024/06/03 ZCZL.ZHANGLEI UPDATE 0.3.000.000:新WizLIFE２次開発
          --rRECODE.DATE_MEI1                := VDATE_MEI1;             --日付名称１
--  2024/11/13 JPJYS.WENGSILIANG UPDATE 0.3.000.004:IT_GKB_00510対応 START
--          rRECODE.DATE_MEI1                := g_sTXTKANSADATE;             --日付名称１
          rRECODE.DATE_MEI1                := VDATE_MEI1;             --日付名称１
--  2024/11/13 JPJYS.WENGSILIANG UPDATE 0.3.000.004:IT_GKB_00510対応 END
          rRECODE.DATE_MEI2                := VDATE_MEI2;             --日付名称２
          rRECODE.DATE_MEI3                := VDATE_MEI3;             --日付名称３
          rRECODE.DATE_MEI4                := VDATE_MEI4;             --日付名称４
          rRECODE.DATE_MEI5                := VDATE_MEI5;             --日付名称５
--  2024/06/03 ZCZL.ZHANGLEI UPDATE START 0.3.000.000:新WizLIFE２次開発
          /*rRECODE.KOMOKU_MEI1              := VKOMOKU_MEI1;           --項目名称１
          rRECODE.KOMOKU_MEI2              := VKOMOKU_MEI2;           --項目名称２
          rRECODE.KOMOKU_MEI3              := VKOMOKU_MEI3;           --項目名称３*/
--  2024/11/13 JPJYS.WENGSILIANG UPDATE 0.3.000.004:IT_GKB_00510対応 START
--          rRECODE.KOMOKU_MEI1              := g_nKAISHIJIKAN;           --項目名称１
--          rRECODE.KOMOKU_MEI2              := g_nUKETSUKEJIKAN;           --項目名称２
--          rRECODE.KOMOKU_MEI3              := g_KAIJOU;           --項目名称３
          rRECODE.KOMOKU_MEI1              := VKOMOKU_MEI1;           --項目名称１
          rRECODE.KOMOKU_MEI2              := VKOMOKU_MEI2;           --項目名称２
          rRECODE.KOMOKU_MEI3              := VKOMOKU_MEI3;           --項目名称３
--  2024/11/13 JPJYS.WENGSILIANG UPDATE 0.3.000.004:IT_GKB_00510対応 END
--  2024/06/03 ZCZL.ZHANGLEI UPDATE END
          rRECODE.KOMOKU_MEI4              := VKOMOKU_MEI4;           --項目名称４
          rRECODE.KOMOKU_MEI5              := VKOMOKU_MEI5;           --項目名称５
          rRECODE.KOMOKU_MEI6              := VKOMOKU_MEI6;           --項目名称６
          rRECODE.KOMOKU_MEI7              := VKOMOKU_MEI7;           --項目名称７
          rRECODE.KOMOKU_MEI8              := VKOMOKU_MEI8;           --項目名称８
          rRECODE.KOMOKU_MEI9              := VKOMOKU_MEI9;           --項目名称９
          rRECODE.KOMOKU_MEI10             := VKOMOKU_MEI10;          --項目名称１０
          rRECODE.GAKKO_CD                 := GAKOKU_CD;              --学校コード
--  2024/08/20 ZCZL.WANGM UPDATE Start 0.3.000.001:IT_GKB_00018対応
--          rRECODE.NINSHOSHAKATAGAKI        := VNINSHO_KATAGAKI;       --認証方書
--          rRECODE.NINSHOSHAMEI             := VNINSHO_SHIMEI;         --認証氏名
          rRECODE.NINSHOSHAKATAGAKI        := o_vKATAGAKI1 || o_vKATAGAKI2;       --認証方書
          rRECODE.NINSHOSHAMEI             := o_vSHIMEI;         --認証氏名
--  2024/08/20 ZCZL.WANGM UPDATE End
          IF RSOFU_JIDO.KOJIN_NO > 0 AND
             (RSOFU_JIDO.TEKIYO_BI <= HASSO_BI) AND
             ((RSOFU_JIDO.SHURYO_BI >= HASSO_BI) OR (RSOFU_JIDO.SHURYO_BI = 0)) THEN
            JIDO_YUBIN_NO := RSOFU_JIDO.YUBIN_NO;
            JIDO_YUBIN_NOBC := RSOFU_JIDO.YUBIN_NOBC;
            JIDO_CHOMEI     := RSOFU_JIDO.CHOMEI;
            JIDO_BANCHI     := RSOFU_JIDO.BANCHI;
            JIDO_KATAGAKI   := RSOFU_JIDO.KATAGAKI;
          ELSE
            JIDO_YUBIN_NO := RATENA_JIDO.YUBIN_NO;
            JIDO_YUBIN_NOBC := RATENA_JIDO.YUBIN_NOBC;
            JIDO_CHOMEI     := RATENA_JIDO.CHOMEI;
            JIDO_BANCHI     := RATENA_JIDO.BANCHI;
            JIDO_KATAGAKI   := RATENA_JIDO.KATAGAKI;
          END IF;
            IF o_ATENA_PRM(1) IN (1,3) THEN
              ATESAKI_YUBIN_NO   := JIDO_YUBIN_NO;
              ATESAKI_YUBIN_NOBC := JIDO_YUBIN_NOBC;
              ATESAKI_CHOMEI     := JIDO_CHOMEI;
              ATESAKI_BANCHI     := JIDO_BANCHI;
              ATESAKI_KATAGAKI   := JIDO_KATAGAKI;
            ELSE
              ATESAKI_YUBIN_NO   := VHOGO_YUBIN_NO;
              ATESAKI_YUBIN_NOBC := VHOGO_YUBIN_NOBC;
              ATESAKI_CHOMEI     := VHOGO_CHOMEI;
              ATESAKI_BANCHI     := VHOGO_BANCHI;
              ATESAKI_KATAGAKI   := VHOGO_KATAGAKI;
            END IF;
          NCHOHYO_NO2 := TRIM(RECGAKUREIBO.NCHOHYO_NO);
          NCHOHYO_NO2 := LPAD(NCHOHYO_NO2,5,' ');
          IGAKKO_CD2 := TRIM(TO_CHAR(GAKOKU_CD));
          IGAKKO_CD2 := LPAD(IGAKKO_CD2,5,' ');
              IF o_RENBAN_PRM(1) = 0 THEN
                HYOJI_CHOHYO_NO := ' ';
              ELSIF o_RENBAN_PRM(1) = 1 THEN
                HYOJI_CHOHYO_NO := NCHOHYO_NO2;
              ELSIF o_RENBAN_PRM(1) = 2 THEN
                HYOJI_CHOHYO_NO := LTRIM(GAKOKUMEI) || '-' || NCHOHYO_NO2;
              ELSIF o_RENBAN_PRM(1) = 3 THEN
                HYOJI_CHOHYO_NO := IGAKKO_CD2 || '-' || NCHOHYO_NO2;
              ELSIF o_RENBAN_PRM(1) = 4 THEN
                HYOJI_CHOHYO_NO := LTRIM(GAKOKUMEI) || '-' || LTRIM(GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
              ELSIF o_RENBAN_PRM(1) = 5 THEN
                HYOJI_CHOHYO_NO := IGAKKO_CD2 || '-' || LTRIM(GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
              ELSE
                HYOJI_CHOHYO_NO := ' ';
              END IF;
          VTANTO_YAKUSHOKU_MEI := o_KYOIKUPRM(2);
          VTANTO_SHUTHOU_MEI   := o_KYOIKUPRM(3);
          VTANTO_RITSU_MEI     := o_KYOIKUPRM(4);
          VTANTO_TEL_NAISEN    := o_KYOIKUPRM(8);
          rRECODE.JIDO_YUBIN_NO            := JIDO_YUBIN_NO;               --児童郵便番号
          rRECODE.JIDO_SOFU_YUBIN_NOBC     := JIDO_YUBIN_NOBC;             --児童カスタマバーコード
          rRECODE.JIDO_CHOMEI_BANCHI       := JIDO_CHOMEI || JIDO_BANCHI;  --児童町名番地
          rRECODE.JIDO_KATAGAKI            := JIDO_KATAGAKI;               --児童方書
            IF LENGTH(ATESAKI_YUBIN_NO) > 0 THEN
              VYUBIN_NO := SUBSTR(ATESAKI_YUBIN_NO,1,3)||'-'||SUBSTR(ATESAKI_YUBIN_NO,4);
              VYUBIN_NO := TRANSLATE(VYUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
              rRECODE.YUBIN_NO                 := VYUBIN_NO;               --郵便番号
            ELSE
              rRECODE.YUBIN_NO                 := ATESAKI_YUBIN_NO;        --郵便番号
            END IF;
          rRECODE.BC_NO                    := ATESAKI_YUBIN_NOBC;                   --カスタマバーコード
          rRECODE.CHOMEI_BANCHI            := ATESAKI_CHOMEI || ATESAKI_BANCHI;     --町名番地
          rRECODE.KATAGAKI                 := ATESAKI_KATAGAKI;                     --方書
          rRECODE.KYOIKU_YAKUSHOKU_MEI     := VTANTO_YAKUSHOKU_MEI;                 --委員会役職名
--  2024/06/03 ZCZL.ZHANGLEI UPDATE 0.3.000.000:新WizLIFE２次開発
          --rRECODE.KYOIKU_SHUCHO_MEI        := VTANTO_SHUTHOU_MEI;                   --委員会首長名
          rRECODE.KYOIKU_SHUCHO_MEI        := o_vSHIMEI;                            --委員会首長名
          rRECODE.KYOIKU_RITSU_MEI         := VTANTO_RITSU_MEI;                     --委員会立区名
          rRECODE.KYOIKU_TEL_NAISEN        := VTANTO_TEL_NAISEN;                    --委員会内線
          rRECODE.HYOJI_CHOHYO_NO          := HYOJI_CHOHYO_NO;                      --表示帳票連番
          KYOIKUKAI_RENRAKUSAKI := GET_EQRENRAKUSAKI(0, o_KYOIKUPRM(1), o_KYOIKUPRM(7), o_KYOIKUPRM(8));
          rRECODE.KYOIKU_RENRAKUSAKI       := KYOIKUKAI_RENRAKUSAKI;                --教育委員会連絡先
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
          rRECODE.BIKO                     := g_sBIKO;                           --備考
          rRECODE.TOIAWASESAKI1            := g_vTOIAWASESAKI1;                     --お問い合わせ先1
          rRECODE.TOIAWASESAKI2            := g_vTOIAWASESAKI2;                     --お問い合わせ先2
          rRECODE.TOIAWASESAKI3            := g_vTOIAWASESAKI3;                     --お問い合わせ先3
          rRECODE.YOSHIKI_NO               := VYOSHIKI_BANGO_SETTOGO || NYOSHIKI_BANGO || VYOSHIKI_BANGO_SETSUBIGO; --様式番号
-- 2025/07/18 CTC.HJF UPDATE Start 1.0.010.001:GKB_QA17896
          rRECODE.YOSHIKI_NO := KKAPK0010.FALPZENHANHENKAN(rRECODE.YOSHIKI_NO ,0,'');
-- 2025/07/18 CTC.HJF UPDATE END
          rRECODE.BIKO_TITLE               := VBIKO_TITLE;                        --備考タイトル
--  2024/06/03 ZCZL.ZHANGLEI ADD END
          rRECODE.BREAK_NO                 := NULL;                                 --改ページキー
          rRECODE.WSNUM                    := g_sWSNUM;                             --端末番号
          rRECODE.BATCHKBN                 := c_ONLINE;                             --即時バッチ区分
          rRECODE.JOBNUM                   := 0;                                    --ジョブNO
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
          FOR i IN 1..g_nHAKKOBUSUU LOOP
--  2024/11/15 ZCZL.WANGYUNING ADD START 0.3.000.004:IT_GKB_00539横展開対応
          nCOUNT := nCOUNT + 1;
          rRECODE.NO                       := nCOUNT;                    --ソート順
--  2024/11/15 ZCZL.WANGYUNING ADD END
          INSERT INTO GKBWL010R001 VALUES rRECODE;
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
          END LOOP;
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
          g_NSQLCODE := SQLCODE;
          g_VSQLMSG  := SUBSTR(SQLERRM, 1, 250);
          -- カーソルが開いていたらクローズ
          IF GAKUREIBO%ISOPEN THEN
            CLOSE GAKUREIBO;
          END IF;
          -- エラーメッセージ表示
          DBMS_OUTPUT.PUT_LINE('例外エラー：' || g_NSQLCODE);
          DBMS_OUTPUT.PUT_LINE(g_VSQLMSG);
      -- 例外エラー終端
      END;
      -- 終了
      RETURN IFRET;
    END FUNC_GET_JIDO_REC;
    --------------------------------------------------------------------------------
    --  機能概要      : レコード2の作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 0,異常 <> 0
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_REC2 RETURN NUMBER IS
      -- カーソル定義
      RECGAKUREIBO         GAKUREIBO%ROWTYPE;
      -- ループ用
      IDX                  PLS_INTEGER;
      -- 戻り値
      IFRET                PLS_INTEGER;
      -- 児童住所
      JIDO_JUSHO           NVARCHAR2(150);
      -- 保護者住所
      HOGO_JUSHO           NVARCHAR2(140);
      -- 続柄取得用
      ZOKUGARA_IN          NVARCHAR2(20);
      -- 続柄フラグ
      ZOKUGARA_FLAG        BOOLEAN;
      -- 続柄
      ZOKUGARA             NVARCHAR2(20);
      -- 生年月日
      VSEINENGAPPI         NVARCHAR2(50);
--  2024/06/03 ZCZL.ZHANGLEI DELETE START 0.3.000.000:新WizLIFE２次開発
      -- 児童生年月日
--       JIDO_BTH_IN          PLS_INTEGER;
--  2024/06/03 ZCZL.ZHANGLEI DELETE END
      --児童年齢
      INENREI              PLS_INTEGER;
--  2024/06/03 ZCZL.ZHANGLEI DELETE START 0.3.000.000:新WizLIFE２次開発
      -- 出力用児童生年月日
--       JIDO_BTH_OUT         NVARCHAR2(11);
--  2024/06/03 ZCZL.ZHANGLEI DELETE END
      -- 出力用発送日
      HASSOBI_OUT          NVARCHAR2(11);
      --出力用児童年齢
      NENREI_OUT           NVARCHAR2(3);
      -- 出力用郵便番号
      YUBIN_NO_OUT         NVARCHAR2(10);   -- 保護者郵便番号
      JIDO_YUBIN_NO_OUT    NVARCHAR2(10);   -- 児童郵便番号
      -- 日付
      DATE_IN              PLS_INTEGER;
      -- 出力用日付
      DATE1_OUT            NVARCHAR2(11);
      DATE2_OUT            NVARCHAR2(11);
      DATE3_OUT            NVARCHAR2(11);
      DATE4_OUT            NVARCHAR2(11);
      DATE5_OUT            NVARCHAR2(11);
      -- 市町村名
      USER_MEI             NVARCHAR2(40);
      VDATE_MEI1           NVARCHAR2(40);
      VDATE_MEI2           NVARCHAR2(40);
      VDATE_MEI3           NVARCHAR2(40);
      VDATE_MEI4           NVARCHAR2(40);
      VDATE_MEI5           NVARCHAR2(40);
      VKOMOKU_MEI1         NVARCHAR2(40);
      VKOMOKU_MEI2         NVARCHAR2(40);
      VKOMOKU_MEI3         NVARCHAR2(40);
      VKOMOKU_MEI4         NVARCHAR2(40);
      VKOMOKU_MEI5         NVARCHAR2(40);
      VKOMOKU_MEI6         NVARCHAR2(40);
      VKOMOKU_MEI7         NVARCHAR2(40);
      VKOMOKU_MEI8         NVARCHAR2(40);
      VKOMOKU_MEI9         NVARCHAR2(40);
      VKOMOKU_MEI10        NVARCHAR2(40);
      -- 宛名情報取得用
      RATENA_HOGOSHA GABTATENAKIHON%ROWTYPE;
      RSOFU_HOGOSHA  GABTSOFUSAKI%ROWTYPE;
      -- 児童宛名情報取得用
      RATENA_JIDO    GABTATENAKIHON%ROWTYPE;
      RSOFU_JIDO     GABTSOFUSAKI%ROWTYPE;
      VJIDO_YUBIN_NO        NVARCHAR2(10);  -- 児童郵便番号
      VJIDO_YUBIN_NOBC      NVARCHAR2(30);  -- 児童郵便番号ＢＣ
      VJIDO_CHOMEI          NVARCHAR2(40);  -- 児童町名
      VJIDO_BANCHI          NVARCHAR2(40);  -- 児童番地
      VJIDO_KATAGAKI        NVARCHAR2(60);  -- 児童方書
      VHOGO_YUBIN_NO        NVARCHAR2(10);  -- 保護者郵便番号
      VHOGO_YUBIN_NOBC      NVARCHAR2(30);  -- 保護者郵便番号ＢＣ
      VHOGO_CHOMEI          NVARCHAR2(40);  -- 保護者町名
      VHOGO_BANCHI          NVARCHAR2(40);  -- 保護者番地
      VHOGO_KATAGAKI        NVARCHAR2(60);  -- 保護者方書
      rRECODE               GKBWL020R001%ROWTYPE;
      nCOUNT                NUMBER := 0;
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
      vCHOMEI_BANCHI        NVARCHAR2(1000); -- 住所マスク文字列
--  2024/09/04 ZCZL.JIANGJUN ADD 0.3.000.002:8月1日認識合わせの横展開
      vCHOMEI_BANCHI1       NVARCHAR2(1000);
      nPRMCTL               NUMBER;
      vDUMMY                NVARCHAR2(1000);
      VYOSHIKI_BANGO_SETTOGO    NVARCHAR2(1000); --様式番号接頭語
      NYOSHIKI_BANGO            NUMBER;          --様式番号
      VYOSHIKI_BANGO_SETSUBIGO  NVARCHAR2(1000); --様式番号接尾語
--  2024/06/03 ZCZL.ZHANGLEI ADD END
    BEGIN
      -- 正常終了
      IFRET := c_ISUCCESS;
      BEGIN
        -- 収発名を取得する
        BEGIN
          SELECT SHUHATS_MEI
                ,DATE_MEI1,DATE_MEI2,DATE_MEI3,DATE_MEI4,DATE_MEI5,
                 KOMOKU_MEI1,KOMOKU_MEI2,KOMOKU_MEI3,KOMOKU_MEI4,KOMOKU_MEI5,
                 KOMOKU_MEI6,KOMOKU_MEI7,KOMOKU_MEI8,KOMOKU_MEI9,KOMOKU_MEI10
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
                ,YOSHIKI_BANGO_SETTOGO,YOSHIKI_BANGO,YOSHIKI_BANGO_SETSUBIGO
            INTO VSYUHATU_MEI
                ,VDATE_MEI1,VDATE_MEI2,VDATE_MEI3,VDATE_MEI4,VDATE_MEI5,
                 VKOMOKU_MEI1,VKOMOKU_MEI2,VKOMOKU_MEI3,VKOMOKU_MEI4,VKOMOKU_MEI5,
                 VKOMOKU_MEI6,VKOMOKU_MEI7,VKOMOKU_MEI8,VKOMOKU_MEI9,VKOMOKU_MEI10
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
                ,VYOSHIKI_BANGO_SETTOGO,NYOSHIKI_BANGO,VYOSHIKI_BANGO_SETSUBIGO
           FROM GKBTTSUCHISHOKANRI
--  2024/06/03 ZCZL.ZHANGLEI UPDATE 0.3.000.000:新WizLIFE２次開発
--             WHERE CHOHYO_KBN = c_CHOHYO_KBN;
             WHERE CHOHYO_KBN = 7;
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
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
            VYOSHIKI_BANGO_SETTOGO := '';
            NYOSHIKI_BANGO := '';
            VYOSHIKI_BANGO_SETSUBIGO := '';
--  2024/06/03 ZCZL.ZHANGLEI ADD END
        END;
        -- カーソルのオープン
        OPEN GAKUREIBO(g_NKOJIN_NO, g_NRIREKI_RENBAN);
        -- レコード参照
        FETCH GAKUREIBO INTO RECGAKUREIBO;
        -- ループ開始
        LOOP
          -- 読むレコードが無い場合ループから抜け出す
          EXIT WHEN GAKUREIBO%NOTFOUND;
          IF g_NHASSO_BI > 0 THEN
            -- 保護者宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(RECGAKUREIBO.HOGOSYA_KOJIN_NO, 'GKB', g_NHASSO_BI,
                                       RATENA_HOGOSHA, RSOFU_HOGOSHA);
            -- 児童宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(g_NKOJIN_NO, 'GKB', g_NHASSO_BI,
                                       RATENA_JIDO, RSOFU_JIDO);
          ELSE
            -- 保護者宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(RECGAKUREIBO.HOGOSYA_KOJIN_NO, 'GKB', ISAKUSEIBI,
                                       RATENA_HOGOSHA, RSOFU_HOGOSHA);
            -- 児童宛名情報取得
            I_RTN := GAAPK0030.FGETATENA(g_NKOJIN_NO, 'GKB', ISAKUSEIBI,
                                       RATENA_JIDO, RSOFU_JIDO);
          END IF;
--  2024/06/28 ZCZL.qinyue Delete 0.3.000.000:新WizLIFE２次開発
--           I_RTN  := FUNC_PRMFLGSET(RATENA_JIDO.KOJIN_NO,N_NAIYO_CD);
          -- 続柄フラグの初期化
          ZOKUGARA_FLAG := TRUE;
          -- 続柄の初期化
          ZOKUGARA := '';
          -- ４回ループする
          FOR IDX IN 1..4 LOOP
            -- ループ変数による分岐
            CASE IDX
              -- 続柄１
              WHEN 1 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI1;
              -- 続柄２
              WHEN 2 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI2;
              -- 続柄３
              WHEN 3 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI3;
              -- 続柄４
              WHEN 4 THEN ZOKUGARA_IN := RECGAKUREIBO.ZOKUGARAMEI4;
            END CASE;
            -- 取得した続柄が存在する場合
            IF ZOKUGARA_IN <> ' ' THEN
              -- 続柄が設定されていない場合
              IF ZOKUGARA_FLAG = TRUE THEN
                -- 続柄フラグを設定
                ZOKUGARA_FLAG := FALSE;
                -- 続柄を設定
                ZOKUGARA := ZOKUGARA_IN;
              -- 続柄が設定されている場合
              ELSE
                -- 続柄を付与する
                ZOKUGARA := ZOKUGARA || 'の' || ZOKUGARA_IN;
              END IF;
            END IF;
          END LOOP;
--  2025/01/09 JPJYS.LIJINGHUI UPDATE 0.3.000.009:品質強化：IT_GKB_10132対応  Start
        /* 
         IF RSOFU_JIDO.KOJIN_NO > 0 AND
             (RSOFU_HOGOSHA.TEKIYO_BI <= HASSO_BI )AND
             ((RSOFU_HOGOSHA.SHURYO_BI >= HASSO_BI) OR (RSOFU_HOGOSHA.SHURYO_BI = 0)) THEN
            VJIDO_YUBIN_NO    := RSOFU_JIDO.YUBIN_NO;
            VJIDO_YUBIN_NOBC  := RSOFU_JIDO.YUBIN_NOBC;
            VJIDO_CHOMEI      := RSOFU_JIDO.CHOMEI;
            VJIDO_BANCHI      := RSOFU_JIDO.BANCHI;
            VJIDO_KATAGAKI    := RSOFU_JIDO.KATAGAKI;
          ELSE
          */
            VJIDO_YUBIN_NO    := RATENA_JIDO.YUBIN_NO;
            VJIDO_YUBIN_NOBC  := RATENA_JIDO.YUBIN_NOBC;
            VJIDO_CHOMEI      := RATENA_JIDO.CHOMEI;
            VJIDO_BANCHI      := RATENA_JIDO.BANCHI;
            VJIDO_KATAGAKI    := RATENA_JIDO.KATAGAKI;
          -- END IF;
--  2025/01/09 JPJYS.LIJINGHUI UPDATE 0.3.000.009:品質強化：IT_GKB_10132対応  End
          -- 検診票用の住所は宛名住所を使用
          JIDO_JUSHO := GAAPK0010.FADDRESSEDIT( 1, '',  RATENA_JIDO.CHOMEI ,RATENA_JIDO.BANCHI, RATENA_JIDO.KATAGAKI, '');
          -- 保護者住所
          IF RSOFU_HOGOSHA.KOJIN_NO > 0 AND
             (RSOFU_HOGOSHA.TEKIYO_BI <= HASSO_BI) AND
             ((RSOFU_HOGOSHA.SHURYO_BI >= HASSO_BI) OR (RSOFU_HOGOSHA.SHURYO_BI = 0)) THEN
            VHOGO_YUBIN_NO    := RSOFU_HOGOSHA.YUBIN_NO;
            VHOGO_YUBIN_NOBC  := RSOFU_HOGOSHA.YUBIN_NOBC;
            VHOGO_CHOMEI      := RSOFU_HOGOSHA.CHOMEI;
            VHOGO_BANCHI      := RSOFU_HOGOSHA.BANCHI;
            VHOGO_KATAGAKI    := RSOFU_HOGOSHA.KATAGAKI;
          ELSE
            VHOGO_YUBIN_NO    := RATENA_HOGOSHA.YUBIN_NO;
            VHOGO_YUBIN_NOBC  := RATENA_HOGOSHA.YUBIN_NOBC;
            VHOGO_CHOMEI      := RATENA_HOGOSHA.CHOMEI;
            VHOGO_BANCHI      := RATENA_HOGOSHA.BANCHI;
            VHOGO_KATAGAKI    := RATENA_HOGOSHA.KATAGAKI;
          END IF;
          -- 検診票用の住所は宛名住所を使用
          HOGO_JUSHO := GAAPK0010.FADDRESSEDIT( 1, '',  RATENA_HOGOSHA.CHOMEI , RATENA_HOGOSHA.BANCHI , RATENA_HOGOSHA.KATAGAKI, '');
--  2024/06/03 ZCZL.ZHANGLEI DELETE START 0.3.000.000:新WizLIFE２次開発
          -- 児童生年月日の取得
--           JIDO_BTH_IN := RECGAKUREIBO.SEINENGAPI;
          -- 出力用児童生年月日の取得
--           PROC_GET_YMD(JIDO_BTH_IN, JIDO_BTH_OUT);
--           IF (RATENA_JIDO.JINKAKU_KBN != 0) THEN
--               PROC_GET_YMD1(RATENA_JIDO.JINKAKU_KBN,JIDO_BTH_IN, JIDO_BTH_OUT);
--           END IF;
--  2024/06/03 ZCZL.ZHANGLEI DELETE END
          -- 児童年齢の取得
          VKIJUNBI := (KKAPK0020.FDAYNENDO(g_NHASSO_BI,0) + 1) * 10000 + 101;
          IF RECGAKUREIBO.SEINENGAPI = 0 THEN
            INENREI := NULL;
          ELSE
            INENREI := KKAPK0020.FAgeGet(RECGAKUREIBO.SEINENGAPI, VKIJUNBI);
          END IF;
          NENREI_OUT :=  TO_CHAR(INENREI);
          -- 発送日の取得
          PROC_GET_YMD(g_NHASSO_BI, HASSOBI_OUT);
          NNENDO := KKAPK0020.FDAYNENDO(g_NHASSO_BI,0);
          IF NVL(NNENDO,0) = 0 THEN
            VHYOUJINENDO := '';
          ELSE
            PROC_GET_YMD(NNENDO * 10000 + 401,VHYOUJINENDO);
            VHYOUJINENDO := SUBSTR(VHYOUJINENDO,1,4);
          END IF;
          --市町村名の取得
          PROC_GET_USER(USER_MEI);
          --郵便番号
          IF LENGTH(VHOGO_YUBIN_NO) > 0 THEN
            YUBIN_NO_OUT := SUBSTR(VHOGO_YUBIN_NO,1,3)||'-'||SUBSTR(VHOGO_YUBIN_NO,4);
            YUBIN_NO_OUT := TRANSLATE(YUBIN_NO_OUT, '1234567890-', '１２３４５６７８９０－');
          ELSE
            YUBIN_NO_OUT := NULL;
          END IF;
          IF RECGAKUREIBO.SYOGAKO_CD != 0 AND RECGAKUREIBO.SYOGAKO_TENGAKU_BI = 0 AND RECGAKUREIBO.SYOGAKO_SOTSUGYO_BI = 0 THEN
            GAKOKU_CD := RECGAKUREIBO.SYOGAKO_CD;
          ELSIF RECGAKUREIBO.KUIKIGAI_CD != 0 AND RECGAKUREIBO.KUIKIGAI_TENGAKU_BI = 0 AND RECGAKUREIBO.KUIKIGAI_TAIGAKU_BI = 0 AND RECGAKUREIBO.KUIKIGAI_SOTSUGYO_BI = 0 THEN
            GAKOKU_CD := RECGAKUREIBO.KUIKIGAI_CD;
          ELSIF RECGAKUREIBO.YOGOGAKO_CD != 0 AND RECGAKUREIBO.YOGOGAKO_TENGAKU_BI = 0 AND RECGAKUREIBO.YOGOGAKO_TAIGAKU_BI = 0 AND RECGAKUREIBO.YOGOGAKO_SOTSUGYO_BI = 0 THEN
            GAKOKU_CD := RECGAKUREIBO.YOGOGAKO_CD;
          ELSE
            GAKOKU_CD := ' ';
          END IF;
          IF RECGAKUREIBO.SYOGAKO_CD != 0 AND RECGAKUREIBO.SYOGAKO_TENGAKU_BI = 0 AND RECGAKUREIBO.SYOGAKO_SOTSUGYO_BI = 0 THEN
            BEGIN
              SELECT SYOGAKOMEI INTO GAKOKUMEI_2 FROM GKBTSHOGAKKO WHERE SYOGAKO_CD = GAKOKU_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
               GAKOKUMEI_1 := NULL;
            END;
            GAKOKUMEI_1 := GAKOKUMEI_2;
          ELSIF RECGAKUREIBO.KUIKIGAI_CD != 0 AND RECGAKUREIBO.KUIKIGAI_TENGAKU_BI = 0 AND RECGAKUREIBO.KUIKIGAI_TAIGAKU_BI = 0 AND RECGAKUREIBO.KUIKIGAI_SOTSUGYO_BI = 0 THEN
            BEGIN
              SELECT KUIKIGAIMEI INTO GAKOKUMEI_2 FROM GKBTKUIKIGAI WHERE KUIKIGAI_CD = GAKOKU_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
               GAKOKUMEI_1 := NULL;
            END;
            GAKOKUMEI_1 := GAKOKUMEI_2;
          ELSIF RECGAKUREIBO.YOGOGAKO_CD != 0 AND RECGAKUREIBO.YOGOGAKO_TENGAKU_BI = 0 AND RECGAKUREIBO.YOGOGAKO_TAIGAKU_BI = 0 AND RECGAKUREIBO.YOGOGAKO_SOTSUGYO_BI = 0 THEN
            BEGIN
              SELECT YOGOGAKOMEI INTO GAKOKUMEI_2 FROM GKBTYOGOGAKKO WHERE YOGOGAKO_CD = GAKOKU_CD;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
               GAKOKUMEI_1 := NULL;
            END;
            GAKOKUMEI_1 := GAKOKUMEI_2;
          ELSE
            GAKOKUMEI_1 := ' ';
          END IF;
          -- 児童郵便番号
          IF LENGTH(VJIDO_YUBIN_NO) > 0 THEN
            JIDO_YUBIN_NO_OUT := SUBSTR(VJIDO_YUBIN_NO,1,3)||'-'||SUBSTR(VJIDO_YUBIN_NO,4);
            JIDO_YUBIN_NO_OUT := TRANSLATE(JIDO_YUBIN_NO_OUT, '1234567890-', '１２３４５６７８９０－');
          ELSE
            JIDO_YUBIN_NO_OUT := NULL;
          END IF;
           GYOSEIKUMEI := GAAPK0030.FGYOSEIKUMEI(RATENA_JIDO.SANTEIDANTAI_CD,RATENA_JIDO.GYOSEIKU_CD);
          -- 日付の取得
          DATE_IN := RECGAKUREIBO.IDATE1;
          PROC_GET_YMD(DATE_IN, DATE1_OUT);
          DATE_IN := RECGAKUREIBO.IDATE2;
          PROC_GET_YMD(DATE_IN, DATE2_OUT);
          DATE_IN := RECGAKUREIBO.IDATE3;
          PROC_GET_YMD(DATE_IN, DATE3_OUT);
          DATE_IN := RECGAKUREIBO.IDATE4;
          PROC_GET_YMD(DATE_IN, DATE4_OUT);
          DATE_IN := RECGAKUREIBO.IDATE5;
          PROC_GET_YMD(DATE_IN, DATE5_OUT);
          -- 連番
          nCOUNT := nCOUNT + 1;
          rRECODE := NULL;
          rRECODE.NO                      := nCOUNT;            --ソート順
          rRECODE.NENDO                   := VHYOUJINENDO;      --年度
          rRECODE.KAIPAGE_CD              := NULL;              --改頁コード
          rRECODE.KAIPAGE                 := NULL;              --改頁
          rRECODE.SAKUSEIBI               := NULL;              --作成日
          rRECODE.RENBAN                  := '1';               --連番
--  2024/06/03 ZCZL.ZHANGLEI UPDATE START 0.3.000.000:新WizLIFE２次開発
          /*-- 児童氏名かな
          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
            I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANA,RATENA_JIDO.SHIMEI_KANA,RECGAKUREIBO.SHIMEI_KANA);
          END IF;
          rRECODE.JIDO_SHIMEI_KANA        := RECGAKUREIBO.SHIMEI_KANA;      --児童氏名カナ
          -- 児童氏名漢字
          IF RATENA_JIDO.JINKAKU_KBN = 1 THEN
            I_RTN  := FUNC_SEIGYO_SET(RATENA_JIDO.HONMYO_KANJI,RATENA_JIDO.SHIMEI_KANJI,RECGAKUREIBO.SHIMEI_KANJI);
          END IF;
          rRECODE.JIDO_SHIMEI_KANJI       := RECGAKUREIBO.SHIMEI_KANJI;      --児童氏名漢字*/
--  2024/06/03 ZCZL.ZHANGLEI UPDATE END
          I_RTN := GKBFKHMCTRL(RATENA_JIDO.KOJIN_NO,g_rOPRT.Chohyoid,0,g_vGKB020_CTL,rRECODE.JIDO_SHIMEI_KANA,   -- 児童氏名カナ
                                                                                     rRECODE.JIDO_SHIMEI_KANJI,  -- 児童氏名漢字
                                                                                     vDUMMY);
          rRECODE.JISSHI_BI               := NULL;                           --実施日
          -- 児童性別
          rRECODE.JIDO_HYOJI_SEIBETSU     := RECGAKUREIBO.SEIBETSU;          --児童性別
          rRECODE.HOGOSHA_SHIMEI_JODAN    := NULL;                           --保護者氏名上段
          rRECODE.HOGOSHA_SHIMEI_GEDAN    := NULL;                           --保護者氏名下段
          rRECODE.JUSHO_JODAN             := NULL;                           --住所上
          rRECODE.JUSHO_GEDAN             := NULL;                           --住所下
          rRECODE.GYOSEIKU_MEI            := GYOSEIKUMEI;                    --行政区名
          -- 学校名
          GAKOKUMEI := GAKOKUMEI_1;
          rRECODE.GAKKOKU_MEI             := GAKOKUMEI;                      --学校区名
          rRECODE.SANTEIDANTAI_MEI        := NULL;                           --算定団体名
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
          vCHOMEI_BANCHI := GAAPK0010.FADDRESSEDIT( 1, NULL,  VHOGO_CHOMEI ,VHOGO_BANCHI, NULL, NULL);
--  2024/09/04 ZCZL.JIANGJUN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--          vCHOMEI_BANCHI := GAAPK0030.FDVJUSHO('GKB', RATENA_JIDO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vCHOMEI_BANCHI, nPRMCTL, 2);
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
          --vCHOMEI_BANCHI1 := GAAPK0030.FDVJUSHO('GKB', RATENA_JIDO.KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vCHOMEI_BANCHI, nPRMCTL, 2);
          -- 郵便番号
          --IF g_nSHIENSOCHIKBN = 1 AND nPRMCTL = 1 THEN
          IF g_nSHIENSOCHIKBN = 1 THEN
            vCHOMEI_BANCHI1 := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
            rRECODE.YUBIN_NO                := '';      --郵便番号
--  2024/09/04 ZCZL.JIANGJUN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--            rRECODE.CHOMEI_BANCHI           := vCHOMEI_BANCHI;    --町名番地
            rRECODE.CHOMEI_BANCHI           := vCHOMEI_BANCHI1;
            rRECODE.KATAGAKI                := '';      --かたがき
          ELSE
--  2024/06/03 ZCZL.ZHANGLEI ADD END
          -- 郵便番号
          rRECODE.YUBIN_NO                := YUBIN_NO_OUT;      --郵便番号
          -- 町名番地
--  2024/09/04 ZCZL.JIANGJUN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--          rRECODE.CHOMEI_BANCHI           := VHOGO_CHOMEI || VHOGO_BANCHI;    --町名番号
          rRECODE.CHOMEI_BANCHI           := vCHOMEI_BANCHI;
          -- 方書
          rRECODE.KATAGAKI                := VHOGO_KATAGAKI;      --かたがき
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
          END IF;
          -- 児童生年月日
          rRECODE.HOGOSHA_SHIMEI_SAMA     := NULL;              --保護者氏名様
--  2024/06/03 ZCZL.ZHANGLEI UPDATE 0.3.000.000:新WizLIFE２次開発
          --rRECODE.KANJI_SEINENGAPI        := JIDO_BTH_OUT;      --漢字生年月日
          I_RTN := GKBFKHMCTRL(RATENA_JIDO.KOJIN_NO,g_rOPRT.Chohyoid,0,g_vGKB010_CTL,vDUMMY,
                                                                                     vDUMMY,
                                                                                     rRECODE.KANJI_SEINENGAPI);  --漢字生年月日
          -- 児童年齢
          rRECODE.JIDO_NENREI             := NENREI_OUT;        --児童年齢
          -- 児童住所
--  2024/09/04 ZCZL.JIANGJUN UPDATE 0.3.000.002:8月1日認識合わせの横展開
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
--          IF g_nSHIENSOCHIKBN = 1 AND nPRMCTL = 1 THEN
--            rRECODE.JIDO_JUSHO              := vCHOMEI_BANCHI;        --児童住所
--          ELSE
--  2024/06/03 ZCZL.ZHANGLEI ADD END
--          rRECODE.JIDO_JUSHO              := JIDO_JUSHO;        --児童住所

--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
 --         END IF;
--  2024/09/04 ZCZL.JIANGJUN UPDATE END
          vCHOMEI_BANCHI  := GAAPK0010.FADDRESSEDIT( 1, NULL,  VJIDO_CHOMEI ,VJIDO_BANCHI, VJIDO_KATAGAKI, NULL);
          --  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 Start
          --vCHOMEI_BANCHI1 := GAAPK0030.FDVJUSHO('GKB', RECGAKUREIBO.HOGOSYA_KOJIN_NO, g_sTANTOCODE, g_sWSNUM, vCHOMEI_BANCHI, nPRMCTL, 2);
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
          --vCHOMEI_BANCHI1 := GAAPK0030.FDVJUSHO('GKB', g_NKOJIN_NO, g_sTANTOCODE, g_sWSNUM, vCHOMEI_BANCHI, nPRMCTL, 2);
          --  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 End
          --IF g_nSHIENSOCHIKBN = 1 AND nPRMCTL = 1 THEN
          IF g_nSHIENSOCHIKBN = 1 THEN
            vCHOMEI_BANCHI1 := GKBPK00010.FGETJUSHOMSG();
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
            rRECODE.JIDO_JUSHO             := vCHOMEI_BANCHI1;     --児童住所（DV該当者）
          ELSE
            rRECODE.JIDO_JUSHO             := vCHOMEI_BANCHI;      --児童住所
          END IF;
--  2024/06/03 ZCZL.ZHANGLEI UPDATE START 0.3.000.000:新WizLIFE２次開発
          /*-- 保護者氏名かな
          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
            I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANA,RATENA_HOGOSHA.SHIMEI_KANA,RECGAKUREIBO.HOGOSYA_SHIMEI_KANA);
          END IF;
          rRECODE.HOGOSHA_SHIMEI_KANA     := RECGAKUREIBO.HOGOSYA_SHIMEI_KANA;      --保護者氏名カナ
          -- 保護者氏名漢字
          IF RATENA_HOGOSHA.JINKAKU_KBN = 1 THEN
            I_RTN  := FUNC_SEIGYO_SET(RATENA_HOGOSHA.HONMYO_KANJI,RATENA_HOGOSHA.SHIMEI_KANJI,RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI);
          END IF;
          rRECODE.HOGOSHA_SHIMEI_KANJI    := RECGAKUREIBO.HOGOSYA_SHIMEI_KANJI;      --保護者氏名漢字
          -- 保護者住所
          rRECODE.HOGOSHA_JUSHO           := HOGO_JUSHO;      --保護者住所
          -- 続柄
          rRECODE.ZOKUGARA                := ZOKUGARA;        --続柄*/
          rRECODE.HOGOSHA_SHIMEI_KANA     := '';      --保護者氏名カナ
          rRECODE.HOGOSHA_SHIMEI_KANJI    := '';      --保護者氏名漢字         
          rRECODE.HOGOSHA_JUSHO           := '';      --保護者住所        
          rRECODE.ZOKUGARA                := '';      --続柄
--  2024/06/03 ZCZL.ZHANGLEI UPDATE END
          USER_MEI := o_KYOIKUPRM(1);
          rRECODE.KYOIKU_KAI_MEI          := USER_MEI;        --教育委員会名
          -- 発送日
          rRECODE.HASSOBI                 := HASSOBI_OUT;     --発送日
          -- 日付１
          --  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 Start
          --rRECODE.DATE1                   := DATE1_OUT;       --日付１
          rRECODE.DATE1                   := TO_MULTI_BYTE(REPLACE(KKAPK0020.FDAYEDIT20(g_sTXTKANSADATE,0,3),' ',''));
          --  2024/12/18 JPJYS.SONGSHIHAO UPDATE 0.3.000.008:品質強化：IT_GKB_10046,IT_GKB_10047,IT_GKB_10048,IT_GKB_10049,IT_GKB_10050対応 End
          rRECODE.BC_NO                   := VHOGO_YUBIN_NOBC;      --カスタマバーコード

            VTANTO_YAKUSHOKU_MEI := o_KYOIKUPRM(2);
            VTANTO_SHUTHOU_MEI   := o_KYOIKUPRM(3);
            VTANTO_RITSU_MEI     := o_KYOIKUPRM(4);
            VTANTO_TEL_NAISEN    := o_KYOIKUPRM(8);
            VTANTO_TEL := o_KYOIKUPRM(7);
            VTANTO_YUBIN_NO := SUBSTR(o_KYOIKUPRM(5),1,3) || '-' || SUBSTR(o_KYOIKUPRM(5),4);
            VTANTO_YUBIN_NO := TRANSLATE(VTANTO_YUBIN_NO, '1234567890-', '１２３４５６７８９０－');
            VTANTO_JUSHO := o_KYOIKUPRM(6);
          rRECODE.TANTO_YAKUSHOKU_MEI     := VTANTO_YAKUSHOKU_MEI;    --担当役職名
          rRECODE.TANTO_SHUTHOU_MEI       := VTANTO_SHUTHOU_MEI;      --担当首長名
          rRECODE.RITSU_MEI               := VTANTO_RITSU_MEI;        --担当会立名
          rRECODE.TANTO_YUBIN_NO          := VTANTO_YUBIN_NO;         --担当郵便番号
          rRECODE.TANTO_JUSHO             := VTANTO_JUSHO;            --担当住所
          rRECODE.TANTO_TEL               := VTANTO_TEL;              --担当電話番号
          rRECODE.TANTO_TEL_NAISEN        := VTANTO_TEL_NAISEN;       --担当内線番号
          -- 日付２
          rRECODE.DATE2                   := DATE2_OUT;                  --日付２
          -- 日付３
          rRECODE.DATE3                   := DATE3_OUT;                  --日付3
          -- 日付４
          rRECODE.DATE4                   := DATE4_OUT;                  --日付4
          -- 日付５
          rRECODE.DATE5                   := DATE5_OUT;                  --日付5
          -- 項目１
          rRECODE.KOMOKU1                 := RECGAKUREIBO.VKOMOKU1;      --項目１
          -- 項目２
          rRECODE.KOMOKU2                 := RECGAKUREIBO.VKOMOKU2;      --項目2
          -- 項目３
          rRECODE.KOMOKU3                 := RECGAKUREIBO.VKOMOKU3;      --項目3
          -- 項目４
          rRECODE.KOMOKU4                 := RECGAKUREIBO.VKOMOKU4;      --項目4
          -- 項目５
          rRECODE.ISHI_SHOKEN             := RECGAKUREIBO.VKOMOKU5;      --担当医師所見
          -- 項目６
          rRECODE.SHIKA_ISHI_SHOKEN       := RECGAKUREIBO.VKOMOKU6;      --担当歯科医師所見
          -- 項目７
          rRECODE.KOMOKU7                 := RECGAKUREIBO.VKOMOKU7;      --項目7
          -- 項目８
          rRECODE.KOMOKU8                 := RECGAKUREIBO.VKOMOKU8;      --項目8
          -- 項目９
          rRECODE.KOMOKU9                 := RECGAKUREIBO.VKOMOKU9;      --項目9
          -- 項目１０
          rRECODE.KOMOKU10                := RECGAKUREIBO.VKOMOKU10;     --項目10
          rRECODE.DATE_MEI1               := VDATE_MEI1;                 --日付名１
          rRECODE.DATE_MEI2               := VDATE_MEI2;                 --日付名２
          rRECODE.DATE_MEI3               := VDATE_MEI3;                 --日付名３
          rRECODE.DATE_MEI4               := VDATE_MEI4;                 --日付名４
          rRECODE.DATE_MEI5               := VDATE_MEI5;                 --日付名５
          rRECODE.KOMOKU_MEI1             := VKOMOKU_MEI1;               --項目名１
          rRECODE.KOMOKU_MEI2             := VKOMOKU_MEI2;               --項目名２
          rRECODE.KOMOKU_MEI3             := VKOMOKU_MEI3;               --項目名３
          rRECODE.KOMOKU_MEI4             := VKOMOKU_MEI4;               --項目名４
--  2024/06/03 ZCZL.ZHANGLEI UPDATE START 0.3.000.000:新WizLIFE２次開発
          --rRECODE.KOMOKU_MEI5             := VKOMOKU_MEI5;               --項目名５
          --rRECODE.KOMOKU_MEI6             := VKOMOKU_MEI6;               --項目名６
          rRECODE.KOMOKU_MEI5             := '';                         --項目名５
          rRECODE.KOMOKU_MEI6             := '';                         --項目名６
--  2024/06/03 ZCZL.ZHANGLEI UPDATE END
          rRECODE.KOMOKU_MEI7             := VKOMOKU_MEI7;               --項目名７
          rRECODE.KOMOKU_MEI8             := VKOMOKU_MEI8;               --項目名８
          rRECODE.KOMOKU_MEI9             := VKOMOKU_MEI9;               --項目名９
          rRECODE.KOMOKU_MEI10            := VKOMOKU_MEI10;              --項目名１０
          rRECODE.GAKKO_CD                := GAKOKU_CD;                  --学校コード

          NCHOHYO_NO2 := TRIM(RECGAKUREIBO.NCHOHYO_NO);
          NCHOHYO_NO2 := LPAD(NCHOHYO_NO2,5,' ');
          IGAKKO_CD2 := TRIM(TO_CHAR(GAKOKU_CD));
          IGAKKO_CD2 := LPAD(IGAKKO_CD2,5,' ');
              IF o_RENBAN_PRM(1) = 0 THEN
                HYOJI_CHOHYO_NO := ' ';
              ELSIF o_RENBAN_PRM(1) = 1 THEN
                HYOJI_CHOHYO_NO := NCHOHYO_NO2;
              ELSIF o_RENBAN_PRM(1) = 2 THEN
                HYOJI_CHOHYO_NO := LTRIM(GAKOKUMEI) || '-' || NCHOHYO_NO2;
              ELSIF o_RENBAN_PRM(1) = 3 THEN
                HYOJI_CHOHYO_NO := IGAKKO_CD2 || '-' || NCHOHYO_NO2;
              ELSIF o_RENBAN_PRM(1) = 4 THEN
                HYOJI_CHOHYO_NO := LTRIM(GAKOKUMEI) || '-' || LTRIM(GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
              ELSIF o_RENBAN_PRM(1) = 5 THEN
                HYOJI_CHOHYO_NO := IGAKKO_CD2 || '-' || LTRIM(GYOSEIKUMEI) || '-' || NCHOHYO_NO2;
              ELSE
                HYOJI_CHOHYO_NO := ' ';
              END IF;
          rRECODE.HYOJI_CHOHYO_NO         := HYOJI_CHOHYO_NO;            --表示帳票連番
          KYOIKUKAI_RENRAKUSAKI := GET_EQRENRAKUSAKI(1, o_KYOIKUPRM(1), o_KYOIKUPRM(7), o_KYOIKUPRM(8));
          rRECODE.KYOIKU_RENRAKUSAKI      := KYOIKUKAI_RENRAKUSAKI;      --教育委員会連絡先
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
          rRECODE.YOSHIKI_NO              := VYOSHIKI_BANGO_SETTOGO || NYOSHIKI_BANGO || VYOSHIKI_BANGO_SETSUBIGO; --様式番号
          rRECODE.BREAK_NO                := NULL;                       --改ページキー
          rRECODE.WSNUM                   := g_sWSNUM;                   --端末番号
          rRECODE.BATCHKBN                := c_ONLINE;                   --即時バッチ区分
          rRECODE.JOBNUM                  := 0;                          --ジョブNO
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
          FOR i IN 1..g_nHAKKOBUSUU LOOP
          INSERT INTO GKBWL020R001 VALUES rRECODE;
--  2024/06/03 ZCZL.ZHANGLEI ADD 0.3.000.000:新WizLIFE２次開発
          END LOOP;
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
          g_NSQLCODE := SQLCODE;
          g_VSQLMSG  := SUBSTR(SQLERRM, 1, 250);
          -- カーソルが開いていたらクローズ
          IF GAKUREIBO%ISOPEN THEN
            CLOSE GAKUREIBO;
          END IF;
          -- エラーメッセージ表示
          DBMS_OUTPUT.PUT_LINE('例外エラー：' || g_NSQLCODE);
          DBMS_OUTPUT.PUT_LINE(g_VSQLMSG);
      -- 例外エラー終端
      END;
      -- 終了
      RETURN IFRET;
    END FUNC_GET_JIDO_REC2;

    --------------------------------------------------------
    --  機能概要      : オンライン処理パラメータ取得処理
    --  パラメータ    : i_vPARAM 処理パラメータテキスト
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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
                     g_NKOJIN_NO           := aCSV_TBL(i);       -- 個人番号
                WHEN 2 THEN
                     g_NRIREKI_RENBAN      := aCSV_TBL(i);       -- 履歴連番
--  2024/06/03 ZCZL.ZHANGLEI UPDATE START 0.3.000.000:新WizLIFE２次開発
                /*
                WHEN 3 THEN
                     g_NHASSO_NO           := aCSV_TBL(i);       -- 発送番号
                WHEN 4 THEN
                     g_NHASSO_BI           := aCSV_TBL(i);       -- 発送日
                WHEN 5 THEN
                     g_NIINKAI             := aCSV_TBL(i);       -- コンスタント連番*/
                WHEN 3 THEN
                    g_vCHOHYO_KBN         := aCSV_TBL(i);       -- 帳票区分
                WHEN 4 THEN
                    g_NHASSO_BI           := aCSV_TBL(i);       -- 発送日
                WHEN 5 THEN
                    g_nATENAKBN            := aCSV_TBL(i);      -- 宛先
                WHEN 6 THEN
                    g_NIINKAI             := aCSV_TBL(i);       -- 変数.制御コンスタント連番(非表示項目)
                WHEN 7 THEN
                    g_sBUNSHO             := aCSV_TBL(i);       -- 文書番号
                WHEN 8 THEN
                    g_nSHIENSOCHIKBN      := aCSV_TBL(i);       -- 支援措置対象住所非表示
                WHEN 9 THEN
                    g_nHAKKOBUSUU         := aCSV_TBL(i);       -- 発行部数
                WHEN 10 THEN
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00730対応  START
                    --g_sTXTKANSADATE       := aCSV_TBL(i);       -- 実施日
                    g_sTXTKANSADATE       := TO_NUMBER(aCSV_TBL(i));   -- 実施日
--  2024/12/09 JPJYS.GYY UPDATE 0.3.000.006:仕様変更　IT_GKB_00730対応  END
                WHEN 11 THEN
                    g_nKAISHIJIKAN        := aCSV_TBL(i);       -- 開始時間
                WHEN 12 THEN
                    g_nUKETSUKEJIKAN      := aCSV_TBL(i);       -- 受付時間
                WHEN 13 THEN
                    g_KAIJOU              := aCSV_TBL(i);       -- 受付会場
                WHEN 14 THEN
                    g_sTOKUKIJIKO         := aCSV_TBL(i);       -- 特記事項
                WHEN 15 THEN
                    g_sBIKO               := aCSV_TBL(i);       -- 備考
--  2024/06/03 ZCZL.ZHANGLEI UPDATE END
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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
    --  機能概要      : メインビジネスロジック処理
    --  パラメータ    : i_sGYOUMUCODE   業務コード
    --                : i_sCHOHYOID     帳票ID
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
    --------------------------------------------------------
    FUNCTION FUNC_O10MAIN (i_sGYOUMUCODE  IN NVARCHAR2,
                           i_sCHOHYOID    IN NVARCHAR2)
        RETURN BOOLEAN
    IS
        bRTN                  BOOLEAN;                    --戻る値
        nDUMMY                NUMBER;
        vDUMMY                NVARCHAR2(100);
        o_nDAIRIKBN           NUMBER;
--  2024/08/20 ZCZL.WANGM DELETE Start 0.3.000.001:IT_GKB_00018対応
--        o_vKATAGAKI1          NVARCHAR2(1000);
--        o_vKATAGAKI2          NVARCHAR2(1000);
--  2024/08/20 ZCZL.WANGM DELETE End
--  2024/06/03 ZCZL.ZHANGLEI DELETE 0.3.000.000:新WizLIFE２次開発
        --o_vSHIMEI             NVARCHAR2(1000);
        eEXCEPTION            EXCEPTION;
    BEGIN
        -- 関数開始
        bRTN := FUNC_SETLOG (g_rOPRT.CHOHYONAME || 'メイン処理', 0, 0, '', '', '処理開始');

        BEGIN
          -- エラーコードの初期化
          g_NSQLCODE := 0;
          -- エラーメッセージの初期化
          g_VSQLMSG := '';
          ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
          -- 基準日セット
          i_IKIJYUNBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
          IF TO_NUMBER(g_NHASSO_BI) = 0 THEN
            HASSO_BI := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
          ELSE
            HASSO_BI := g_NHASSO_BI;
          END IF;
          --公印ファイル名取得
          bRTN := KKBPK5551.FNINSHOGet(NVL(g_rOPRT.NINSHOCODE,0),                   --認証コード
                                              g_sWSNUM,                             --端末番号
                                               TO_DATE(i_IKIJYUNBI,'YYYYMMDD'),     --基準日
                                               o_nDAIRIKBN,                         --認証者の本人・代理区分
                                               o_vKATAGAKI1,                        --認証者の肩書上段
                                               o_vKATAGAKI2,                        --認証者の肩書下段
                                               o_vSHIMEI,                           --認証者の氏名
                                               VGYOMU);                             --公印ファイル名
          -- 帳票独自の認証者を取得する
--  2024/08/20 ZCZL.WANGM DELETE Start 0.3.000.001:IT_GKB_00018対応
--          KKAPK0030.SNinshGet(i_IKIJYUNBI,
--                                   nDUMMY,
--                                   VNINSHO_SHIMEI,
--                                   vDUMMY,
--                                   vDUMMY,
--                                   VNINSHO_KATAGAKI);
--  2024/08/20 ZCZL.WANGM DELETE End
          -- 宛先の氏名出力制御を取得する
          o_ATENA_PRM := A_CONS_PRM();
          ISIMEYISYUTURYOKUSEGYO     := KKAPK0030.FPRMSHUTOKU('GKB','00ATENA',2,o_ATENA_PRM,o_LENGTH);
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
--  2024/06/03 ZCZL.ZHANGLEI UPDATE START 0.3.000.000:新WizLIFE２次開発
            /*I_RTN := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,o_SHIMEIPRM,o_LENGTH);
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
            ELSE
              WHILE (o_LENGTH < 5) LOOP
                o_SHIMEIPRM.EXTEND;
                o_SHIMEIPRM(o_LENGTH+1) := 0;
                o_LENGTH := o_LENGTH + 1;
              END LOOP;
            END IF;*/
          --外国人　氏名・生年月日制御帳票(ID)
          g_aSHIMEIJKN_CHOHYOPRM := A_CONS_PRM();
          I_RTN := KKAPK0030.FCTGetR('GKB','SHIMEIJKN_CHOHYO','0000',1,g_aSHIMEIJKN_CHOHYOPRM);
          IF I_RTN = 0 THEN
            FOR i IN 1..g_aSHIMEIJKN_CHOHYOPRM.COUNT LOOP
              IF g_aSHIMEIJKN_CHOHYOPRM(i) = 'GKB010R001' THEN
                g_nGKB010_INDEX := i;
              END IF;
            END LOOP;
          END IF;
          --本名・通称名　出力制御
          g_aSHIMEIPRM := A_CONS_PRM();
          I_RTN := KKAPK0030.FCTGetR('GKB','EQSHIMEI','0000',0,g_aSHIMEIPRM);
          IF I_RTN = 0 THEN
            g_vGKB010_CTL := g_aSHIMEIPRM(g_nGKB010_INDEX);
            g_vGKB020_CTL := g_aSHIMEIPRM(g_nGKB010_INDEX);
          END IF;
--  2024/06/03 ZCZL.ZHANGLEI UPDATE END
          -- 教育委員会情報を取得する
          o_KYOIKUPRM := A_CONS_PRM();
          IKYOUIKUIINKAIJOUHOU       := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',g_NIINKAI,o_KYOIKUPRM,o_LENGTH);
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
              WHILE (o_LENGTH < 8) LOOP
                o_KYOIKUPRM.EXTEND;
                o_KYOIKUPRM(o_LENGTH+1) := ' ';
                o_LENGTH := o_LENGTH + 1;
              END LOOP;
            END IF;
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
          g_vTOIAWASESAKI1 := o_KYOIKUPRM(1); --教育委員会名
          g_vTOIAWASESAKI2 := o_KYOIKUPRM(6); --住所
          g_vTOIAWASESAKI3 := o_KYOIKUPRM(7); --電話番号
--  2024/06/03 ZCZL.ZHANGLEI ADD END
          -- 帳票連番印字項目の制御を取得する
           o_RENBAN_PRM := A_CONS_PRM();
          ICHOUHYOURENBANINZIKOUMOKU := KKAPK0030.FPRMSHUTOKU('GKB','00RENBAN',0,o_RENBAN_PRM,o_LENGTH);
            IF ICHOUHYOURENBANINZIKOUMOKU = 1 THEN
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
--  2024/06/03 ZCZL.ZHANGLEI ADD START 0.3.000.000:新WizLIFE２次開発
          -- 文書番号情報取得
          g_rBUNNUMINF := KKBPK5551.FBUNNUMINF(g_sBUNSHONUMLIST);
          --文書番号編集結果を取得
          g_rBUNNUMEDITKEKA := g_rBUNNUMINF.UOUT;
          -- 文書番号印字ありの場合
          IF g_rBUNNUMEDITKEKA.NUMUMUFLG = 0 THEN
            g_vBUNSHO_NO := g_rBUNNUMEDITKEKA.NUM;                 --文書番号
--  2024/09/04 ZCZL.JIANGJUN Add Start 0.3.000.002:8月1日認識合わせの横展開
          ELSE
            g_vBUNSHO_NO := NULL;                                  --文書番号
--  2024/09/04 ZCZL.JIANGJUN Add End
          END IF;
--  2024/06/03 ZCZL.ZHANGLEI ADD END
--  2024/09/04 ZCZL.JIANGJUN Add Start 0.3.000.002:8月1日認識合わせの横展開
          -- 発付年月日変数
          IF g_rBUNNUMEDITKEKA.DATEUMUFLG = 0 THEN
              --文書入力画面で文書日付印字ありのとき設定
--  2024/11/21 ZCZL.WANGYUNING UPDATE 0.3.000.005:IT_GKB_00625対応
              --g_sDATEED := g_rBUNNUMEDITKEKA.DATEED;
              g_sDATEED := g_rBUNNUMEDITKEKA.BUNDATE;
          ELSE
              g_sDATEED := '';
          END IF;
--  2024/09/04 ZCZL.JIANGJUN Add End
          IF  g_rOPRT.Chohyonum = 101  THEN
              DELETE FROM GKBWL010R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
              -- ＣＳＶ作成
              I_RTN := FUNC_GET_JIDO_REC();
              -- 正常に終了
              IF I_RTN = c_ISUCCESS THEN
                -- 処理状態出力
                DBMS_OUTPUT.PUT_LINE('『学齢簿帳票情報出力』正常終了');
              -- 異常終了
              ELSE
                -- 処理状態出力
                DBMS_OUTPUT.PUT_LINE('『学齢簿帳票情報出力』異常終了');
              END IF;
          ELSIF  g_rOPRT.Chohyonum = 201 THEN
              DELETE FROM GKBWL020R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_ONLINE;
              -- ＣＳＶ2作成
              I_RTN := FUNC_GET_JIDO_REC2();
              -- 正常に終了
              IF I_RTN = c_ISUCCESS THEN
                 -- 処理状態出力
                DBMS_OUTPUT.PUT_LINE('『学齢簿帳票情報出力』正常終了');
              -- 異常終了
              ELSE
                -- 処理状態出力
                DBMS_OUTPUT.PUT_LINE('『学齢簿帳票情報出力』異常終了');
              END IF;
           END IF;
        -- 例外
        EXCEPTION
          -- その他エラー
          WHEN OTHERS THEN
            -- SQL情報取得
            g_NSQLCODE := SQLCODE;
            g_VSQLMSG  := SUBSTR(SQLERRM, 1, 250);
            g_sMESSAGE := g_NSQLCODE || '|' || g_VSQLMSG;
            RAISE eEXCEPTION;
        END;

        --CSVファイル出力
        CASE g_rOPRT.CHOHYONUM
          WHEN 101 THEN
            --健康診断通知書
            bRTN := FUNC_O20CSV(i_sGYOUMUCODE,'GKBWL010R001',i_sCHOHYOID);
          WHEN 201 THEN
            --健康診断票
            bRTN := FUNC_O20CSV(i_sGYOUMUCODE,'GKBWL020R001',i_sCHOHYOID);
          ELSE
            NULL;
        END CASE;

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
    --  作成者／作成日: ZCZL.CONGDAN 2024/01/05
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
END GKBPA00010;
/
