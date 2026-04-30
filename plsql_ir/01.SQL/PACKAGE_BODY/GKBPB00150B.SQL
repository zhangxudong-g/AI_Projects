CREATE OR REPLACE PACKAGE BODY GKBPB00150
--1.0.452.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 学齢簿情報チェックリスト作成
--  機能概要      : 学齢簿情報と住基情報のチェックリストを作成する。
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
--------------------------------------------------------
--  変更履歴
--  2024/06/17 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00098の対応
--  2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.002:IT_GKB_00338の対応
--  2024/12/16 JPJYS.SONGSHIHAO UPDATE 0.3.000.003:IT_GKB_10045の対応
--  2024/12/26 JIP.KF 修正ミスを是正
--  2025/01/14 JPJYS.LIJINGHUI UPDATE 0.3.000.004:学区マスタ横展開の対応
--  2025/04/30 CTC.LIUJUNHAO UPDATE 1.0.003.000:GKB_QA13755_全員が支援措置対象者の旨を印字される対応
--  2025/10/08 CTC.LIUJUNHAO UPDATE 1.0.108.000:GKB_QA20569対応
--  2026/01/07 CTC.HJF UPDATE START 1.0.452.000:GKB_QA24133対応
---------------------------------------------------------
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
    g_nKENSAKU                      NUMBER := 0;                     --件数
    g_nCSVKENSAKU                   NUMBER := 0;                     --CSV件数

    g_nTIME NUMBER;  --時分秒

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --パラメータ変数
    --条件
    g_vJYOUKEN1  NVARCHAR2(500);
    g_vJYOUKEN2  NVARCHAR2(500);
    g_vJYOUKEN3  NVARCHAR2(500);
    g_vJYOUKEN4  NVARCHAR2(500);
-- 2024/06/12 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
    g_vMSG         NVARCHAR2(4000);
    g_vERRTMPMSG   NVARCHAR2(1000);
    g_vKOKUMEI1    NVARCHAR2(1000);   -- 児童生徒国籍
    g_vKOKUMEI2    NVARCHAR2(1000);   -- 保護者国籍
    g_nGAKOKUCD    NUMBER;            -- 学校区
-- 2024/06/12 ZCZL.muzl Add end
    --------------------------------------------------------------------
    --  定数宣言
    --------------------------------------------------------------------
    c_BERROR          CONSTANT BOOLEAN       := FALSE;
    c_BNORMALEND      CONSTANT BOOLEAN       := TRUE;
    c_VTBLNAME        CONSTANT NVARCHAR2(20) := 'GKBWCHECK';      -- テーブル名
    --------------------------------------------------------------------
    --  変数宣言
    --------------------------------------------------------------------
    -- 処理条件の取得用変数
    IKAISHI_SEINENGAPI          PLS_INTEGER;        -- 抽出開始生年月日
    ISHURYO_SEINENGAPI          PLS_INTEGER;        -- 抽出終了生年月日
    IGAKUNEN                    PLS_INTEGER;        -- 学年
    IGAKO_KBN                   PLS_INTEGER;        -- 学校区分

    -- 集計用変数
    BRTN                        BOOLEAN;            -- ステータス
    IRTN                        PLS_INTEGER;        -- ステータス
    VSQLERRM                    NVARCHAR2(256);     -- エラーメッセージ
    IZOKUGARAERR                PLS_INTEGER;        -- 続柄編集エラー
    ISYSDATE                    PLS_INTEGER := 0;   -- システム日付
    IROWCNT                     PLS_INTEGER := 0;   -- 入力件数
    NSQLCODE                    NUMBER;             -- エラーコード

    -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
    io_IWAREKIHIZUKE            PLS_INTEGER := 0;
    io_ISEIREKIHIZUKE           PLS_INTEGER := 0;
    o_VEDIT_GYYMMDD1            NVARCHAR2(16);
    o_VEDIT_GYYMMDD2            NVARCHAR2(16);
    o_VEDIT_GYYMMDD3            NVARCHAR2(16);
    o_VKJ_GENGO                 NVARCHAR2(16);
    o_VKG_GENGO                 NVARCHAR2(16);
    o_IWAREKI_YY                PLS_INTEGER;
    o_ISEIREKI_YYYY             PLS_INTEGER;
    o_IWAREKI_GYYMM             PLS_INTEGER;
    o_IMM                       PLS_INTEGER;
    o_IDD                       PLS_INTEGER;
    o_IWAREKIHIZUKE             PLS_INTEGER;
    o_ISEIREKIHIZUKE            PLS_INTEGER;

    -- 稼動ユーザー情報
    o_IUSER_ID                  PLS_INTEGER;
    o_IGAPPEI_BI                PLS_INTEGER;
    o_IJICHI_CD                 PLS_INTEGER;
    o_IUSER_KBN                 PLS_INTEGER;
    o_VKENMEI                   NVARCHAR2(1000);
    o_VGUNSHIMEI                NVARCHAR2(1000);
    o_VUSERMEI                  NVARCHAR2(1000);
    o_VSHUCHOMEI                NVARCHAR2(1000);
    o_VSHUNYUNINSHOBUN          NVARCHAR2(1000);
    o_VYUBIN_NO                 NVARCHAR2(1000);
    o_VSHOZAICHI                NVARCHAR2(1000);
    o_VTEL_NO                   NVARCHAR2(1000);

    -- カーソル
    CURSOR CTAISHO( p_IKAISHI_SEINENGAPI IN PLS_INTEGER,
                    p_ISHURYO_SEINENGAPI IN PLS_INTEGER,
                    p_IGAKUNEN           IN PLS_INTEGER,
                    p_IGAKO_KBN          IN PLS_INTEGER ) IS
    SELECT 1 AS ERR_KBN,
           A.KOJIN_NO,
           A.SETAI_NO,
           A.GYOSEIKU_CD,
           A.HAN_CD,
           DECODE(p_IGAKO_KBN,1,A.SHOGAKU_CD,A.CHUGAKU_CD) AS ATENA_GAKU_CD,
           A.SANTEIDANTAI_CD,
           A.SEINENGAPI,
           A.HYOJI_SEINENGAPI,
           A.SEIBETSU,
           A.SHIMEI_KANA,
           A.SHIMEI_KANJI,
           A.YUBIN_NO,
           A.CHOMEI,
           A.BANCHI,
           A.KATAGAKI,
           0 AS JUMIN_NAKUNARU,
           0 AS JUMIN_NAKUNARU_JIYU,
--  2026/01/07 CTC.HJF UPDATE START 1.0.452.000:GKB_QA24133対応
           --0 AS GAKUNEN_CD,
           CAST(NULL AS NUMBER) AS GAKUNEN_CD,
--  2026/01/07 CTC.HJF UPDATE END
           0 AS HOGOSYA_KOJIN_NO,
           0 AS ZOKUGARA1,
           0 AS ZOKUGARA2,
           0 AS ZOKUGARA3,
           0 AS ZOKUGARA4,
           0 AS HOGOSYA_ZOKUGARA1,
           0 AS HOGOSYA_ZOKUGARA2,
           0 AS HOGOSYA_ZOKUGARA3,
           0 AS HOGOSYA_ZOKUGARA4,
           0 AS GAKOKU_CD,
--  2024/06/06 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
           0 AS RIREKI_RENBAN
      FROM GABTATENAKIHON  A
     WHERE A.SEINENGAPI BETWEEN p_IKAISHI_SEINENGAPI AND p_ISHURYO_SEINENGAPI
       AND A.GENZON_KBN = 0
       AND NOT EXISTS (SELECT G.KOJIN_NO
                         FROM GKBTGAKUREIBO G
                        WHERE G.KOJIN_NO = A.KOJIN_NO
                          AND G.GEN_NENGAPI = 0
--  2024/06/06 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
                          AND G.SAISHIN_KBN  = 0
                          AND G.SAKUJO_FLG   = 0)
--  2024/06/06 ZCZL.muzl Add
     UNION ALL
    SELECT 2 AS ERR_KBN,
           A.KOJIN_NO,
           A.SETAI_NO,
           A.GYOSEIKU_CD,
           A.HAN_CD,
           DECODE(p_IGAKO_KBN,1,A.SHOGAKU_CD,A.CHUGAKU_CD) AS ATENA_GAKU_CD,
           A.SANTEIDANTAI_CD,
           A.SEINENGAPI,
           A.HYOJI_SEINENGAPI,
           A.SEIBETSU,
           A.SHIMEI_KANA,
           A.SHIMEI_KANJI,
           A.YUBIN_NO,
           A.CHOMEI,
           A.BANCHI,
           A.KATAGAKI,
           J.JUMIN_NAKUNARU,
           J.JUMIN_NAKUNARU_JIYU,
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応           
           --L.GAKUNEN_CD,
           G.GAKUNEN AS GAKUNEN_CD,
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応            
           G.HOGOSYA_KOJIN_NO,
           G.ZOKUGARA1,
           G.ZOKUGARA2,
           G.ZOKUGARA3,
           G.ZOKUGARA4,
           G.HOGOSYA_ZOKUGARA1,
           G.HOGOSYA_ZOKUGARA2,
           G.HOGOSYA_ZOKUGARA3,
           G.HOGOSYA_ZOKUGARA4,
           DECODE(p_IGAKO_KBN,1,G.SYOGAKO_CD,G.TYUGAKO_CD) AS GAKOKU_CD,
--  2024/06/06 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00098の対応
--           G.RIREKI_RENBAN
           0 AS RIREKI_RENBAN
      FROM GABTJUKIIDO     J,
           GABTATENAKIHON  A,
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応            
           --GKBTGAKUNENLNK L,
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応             
           GKBTGAKUREIBO   G
     WHERE G.SAISHIN_KBN  = 0
       AND G.GEN_NENGAPI  = 0
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応        
     --AND L.KOJIN_NO     = G.KOJIN_NO
     --AND L.GAKUNEN_CD   = p_IGAKUNEN
       AND G.GAKUNEN   = p_IGAKUNEN
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応        
       AND A.KOJIN_NO     = G.KOJIN_NO
       AND A.GENZON_KBN   IN(1,2)
       AND J.KOJIN_NO     = G.KOJIN_NO
--  2024/06/06 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
       AND G.SAKUJO_FLG   = 0
     UNION ALL
    SELECT 3 AS ERR_KBN,
           A.KOJIN_NO,
           A.SETAI_NO,
           A.GYOSEIKU_CD,
           A.HAN_CD,
           DECODE(p_IGAKO_KBN,1,A.SHOGAKU_CD,A.CHUGAKU_CD) AS ATENA_GAKU_CD,
           A.SANTEIDANTAI_CD,
           A.SEINENGAPI,
           A.HYOJI_SEINENGAPI,
           A.SEIBETSU,
           A.SHIMEI_KANA,
           A.SHIMEI_KANJI,
           A.YUBIN_NO,
           A.CHOMEI,
           A.BANCHI,
           A.KATAGAKI,
           0 AS JUMIN_NAKUNARU,
           0 AS JUMIN_NAKUNARU_JIYU,
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応  
           --L.GAKUNEN_CD,
           G.GAKUNEN AS GAKUNEN_CD,
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応             
           G.HOGOSYA_KOJIN_NO,
           G.ZOKUGARA1,
           G.ZOKUGARA2,
           G.ZOKUGARA3,
           G.ZOKUGARA4,
           G.HOGOSYA_ZOKUGARA1,
           G.HOGOSYA_ZOKUGARA2,
           G.HOGOSYA_ZOKUGARA3,
           G.HOGOSYA_ZOKUGARA4,
           DECODE(p_IGAKO_KBN,1,G.SYOGAKO_CD,G.TYUGAKO_CD) AS GAKOKU_CD,
--  2024/06/06 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00098の対応
--           G.RIREKI_RENBAN
           0 AS RIREKI_RENBAN
      FROM GABTATENAKIHON  A,
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応        
           --GKBTGAKUNENLNK L,
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応             
           GKBTGAKUREIBO   G
     WHERE G.SAISHIN_KBN  = 0
--  2024/06/06 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
       AND G.SAKUJO_FLG   = 0
       AND G.GEN_NENGAPI  = 0
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応        
     --AND L.KOJIN_NO     = G.KOJIN_NO
     --AND L.GAKUNEN_CD   = p_IGAKUNEN
       AND G.GAKUNEN   = p_IGAKUNEN
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応 
       AND A.KOJIN_NO     = G.KOJIN_NO
       AND A.SEINENGAPI NOT BETWEEN p_IKAISHI_SEINENGAPI AND p_ISHURYO_SEINENGAPI
     UNION ALL
    SELECT 3 AS ERR_KBN,
           A.KOJIN_NO,
           A.SETAI_NO,
           A.GYOSEIKU_CD,
           A.HAN_CD,
           DECODE(p_IGAKO_KBN,1,A.SHOGAKU_CD,A.CHUGAKU_CD) AS ATENA_GAKU_CD,
           A.SANTEIDANTAI_CD,
           A.SEINENGAPI,
           A.HYOJI_SEINENGAPI,
           A.SEIBETSU,
           A.SHIMEI_KANA,
           A.SHIMEI_KANJI,
           A.YUBIN_NO,
           A.CHOMEI,
           A.BANCHI,
           A.KATAGAKI,
           0 AS JUMIN_NAKUNARU,
           0 AS JUMIN_NAKUNARU_JIYU,
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応            
           --L.GAKUNEN_CD,
           G.GAKUNEN AS GAKUNEN_CD,
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応  
           G.HOGOSYA_KOJIN_NO,
           G.ZOKUGARA1,
           G.ZOKUGARA2,
           G.ZOKUGARA3,
           G.ZOKUGARA4,
           G.HOGOSYA_ZOKUGARA1,
           G.HOGOSYA_ZOKUGARA2,
           G.HOGOSYA_ZOKUGARA3,
           G.HOGOSYA_ZOKUGARA4,
           DECODE(p_IGAKO_KBN,1,G.SYOGAKO_CD,G.TYUGAKO_CD) AS GAKOKU_CD
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00098の対応
           ,0 AS RIREKI_RENBAN
      FROM GABTATENAKIHON  A,
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応      
           --GKBTGAKUNENLNK L,
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応           
           GKBTGAKUREIBO   G
     WHERE G.SAISHIN_KBN  = 0
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00098の対応
       AND G.SAKUJO_FLG   = 0
       AND G.GEN_NENGAPI  = 0
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応        
     --AND L.KOJIN_NO     = G.KOJIN_NO
     --AND L.GAKUNEN_CD   = p_IGAKUNEN
       AND G.GAKUNEN   <> p_IGAKUNEN
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応 
       AND A.KOJIN_NO     = G.KOJIN_NO
       AND A.SEINENGAPI BETWEEN p_IKAISHI_SEINENGAPI AND p_ISHURYO_SEINENGAPI
     UNION ALL
    SELECT 4 AS ERR_KBN,
           A.KOJIN_NO,
           A.SETAI_NO,
           A.GYOSEIKU_CD,
           A.HAN_CD,
           DECODE(p_IGAKO_KBN,1,A.SHOGAKU_CD,A.CHUGAKU_CD) AS ATENA_GAKU_CD,
           A.SANTEIDANTAI_CD,
           A.SEINENGAPI,
           A.HYOJI_SEINENGAPI,
           A.SEIBETSU,
           A.SHIMEI_KANA,
           A.SHIMEI_KANJI,
           A.YUBIN_NO,
           A.CHOMEI,
           A.BANCHI,
           A.KATAGAKI,
           0 AS JUMIN_NAKUNARU,
           0 AS JUMIN_NAKUNARU_JIYU,
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応  
           --L.GAKUNEN_CD,
           G.GAKUNEN AS GAKUNEN_CD,
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応 
           G.HOGOSYA_KOJIN_NO,
           G.ZOKUGARA1,
           G.ZOKUGARA2,
           G.ZOKUGARA3,
           G.ZOKUGARA4,
           G.HOGOSYA_ZOKUGARA1,
           G.HOGOSYA_ZOKUGARA2,
           G.HOGOSYA_ZOKUGARA3,
           G.HOGOSYA_ZOKUGARA4,
           DECODE(p_IGAKO_KBN,1,G.SYOGAKO_CD,G.TYUGAKO_CD) AS GAKOKU_CD,
--  2024/06/06 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
           G.RIREKI_RENBAN
      FROM GABTATENAKIHON  A,
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応         
           --GKBTGAKUNENLNK L,
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応              
           GKBTGAKUREIBO   G
     WHERE G.SAISHIN_KBN  = 0
--  2024/06/06 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
       AND G.SAKUJO_FLG   = 0
       AND G.GEN_NENGAPI  = 0
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応        
     --AND L.KOJIN_NO     = G.KOJIN_NO
     --AND L.GAKUNEN_CD   = p_IGAKUNEN
       AND G.GAKUNEN    = p_IGAKUNEN
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応 
       AND A.KOJIN_NO     = G.KOJIN_NO    
       AND DECODE(p_IGAKO_KBN,1,G.SYOGAKO_CD,G.TYUGAKO_CD) <> DECODE(p_IGAKO_KBN,1,A.SHOGAKU_CD,A.CHUGAKU_CD)      
-- 2024/06/06 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
     UNION ALL
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応        
    --SELECT  5 AS ERR_KBN
    SELECT  51 AS ERR_KBN
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応      
           ,A.KOJIN_NO
           ,A.SETAI_NO
           ,A.GYOSEIKU_CD
           ,A.HAN_CD
           ,DECODE(p_IGAKO_KBN,1,A.SHOGAKU_CD,A.CHUGAKU_CD) AS ATENA_GAKU_CD
           ,A.SANTEIDANTAI_CD
           ,A.SEINENGAPI
           ,A.HYOJI_SEINENGAPI
           ,A.SEIBETSU
           ,A.SHIMEI_KANA
           ,A.SHIMEI_KANJI
           ,A.YUBIN_NO
           ,A.CHOMEI
           ,A.BANCHI
           ,A.KATAGAKI
           ,0 AS JUMIN_NAKUNARU
           ,0 AS JUMIN_NAKUNARU_JIYU
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応  
           --L.GAKUNEN_CD,
           ,G.GAKUNEN AS GAKUNEN_CD
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応 
           ,G.HOGOSYA_KOJIN_NO
           ,G.ZOKUGARA1
           ,G.ZOKUGARA2
           ,G.ZOKUGARA3
           ,G.ZOKUGARA4
           ,G.HOGOSYA_ZOKUGARA1
           ,G.HOGOSYA_ZOKUGARA2
           ,G.HOGOSYA_ZOKUGARA3
           ,G.HOGOSYA_ZOKUGARA4
           ,DECODE(p_IGAKO_KBN,1,G.SYOGAKO_CD,G.TYUGAKO_CD) AS GAKOKU_CD
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00098の対応
--           ,G.RIREKI_RENBAN
           ,0 AS RIREKI_RENBAN
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応             
      --FROM GABTATENAKIHON  A,GKBTGAKUREIBO  G,GKBTGAKUNENLNK L
      FROM GABTATENAKIHON  A,GKBTGAKUREIBO  G
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応        
     WHERE G.KOJIN_NO      = A.KOJIN_NO
       AND A.SEINENGAPI   >= IKAISHI_SEINENGAPI
       AND A.SEINENGAPI   <= ISHURYO_SEINENGAPI
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応        
       --AND L.GAKUNEN_CD    = IGAKUNEN
       --AND G.GAKKO_KBN_CD  = IGAKO_KBN      
       AND G.SAISHIN_KBN   = 0
       --AND G.SAKUJO_FLG    = 0; --2024/12/26 JIP.KF        
       AND G.SAKUJO_FLG    = 0
       ORDER BY
        SEINENGAPI;
       --2024/12/16 JPJYS.SONGSHIHAO UPDATE 0.3.000.003:IT_GKB_10045の対応 Start
       --AND L.KOJIN_NO    = G.KOJIN_NO --2024/12/26 JIP.KF
       --AND L.KOJIN_NO    = G.KOJIN_NO;
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応         
       --2024/12/16 JPJYS.SONGSHIHAO UPDATE 0.3.000.003:IT_GKB_10045の対応 End         
-- 2024/06/06 ZCZL.muzl Add end
    -- 中間ファイル用
    RWORK                       GKBWCHECK%ROWTYPE;
    -- カーソル用
    RTAISHO                     CTAISHO%ROWTYPE;
    
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        V_txtSeinenGappiStart      NVARCHAR2(20);
        V_txtSeinenGappiEnd        NVARCHAR2(20);
        v_cmbGakunen               DBMS_UTILITY.MAXNAME_ARRAY;
        v_cmbGakkoKbn              DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        -- 抽出開始生年月日 期間(開始)
        V_txtSeinenGappiStart := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSeinenGappiStart');
        g_vJYOUKEN1 := KKAPK0020.FDAYEDIT20((TO_NUMBER(REPLACE(V_txtSeinenGappiStart,'/',''))),0,0);
        -- 抽出終了生年月日 期間(終了)
        V_txtSeinenGappiEnd := KKBPK5551.GETPARMS(g_nJOBNUM,'txtSeinenGappiEnd');
        g_vJYOUKEN2 := KKAPK0020.FDAYEDIT20((TO_NUMBER(REPLACE(V_txtSeinenGappiEnd,'/',''))),0,0);
        -- 学年
        v_cmbGakunen  := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGakunen');
        g_vJYOUKEN3   := v_cmbGakunen(1);
        -- 学校区分
        v_cmbGakkoKbn := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGakkoKbn');
        g_vJYOUKEN4   := v_cmbGakkoKbn(1);
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
-- 2024/06/12 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
        nMSG                          NVARCHAR2(100);
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
-- 2024/06/12 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
        -- 条件入力チェック
        -- 単項目チェック・相関チェック
        g_vMSG := '';
        g_vERRTMPMSG := '';
-- 2024/06/12 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
       --条件１の入力条件の日付等の妥当性チェック
       nMSG := KKBPK5551.FJOKENDATECHK('GKB',g_sSHORIID,0,1,1,g_vJYOUKEN1 );
       IF nMSG IS NOT NULL THEN
          g_vMSG := g_vMSG || g_sGYOUMUCODE || nMSG;
        END IF;
-- 2024/06/12 ZCZL.muzl Add end
        --条件１のチェック
        -- 開始年月の数値型変換でエラーの場合
        bRTN := KKAPK0010.FISNUMERIC( g_vJYOUKEN1 );
        IF bRTN = FALSE THEN
          --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.002:IT_GKB_00338の対応
          --g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,開始年月が正しくありません。,;';
          g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出開始生年月日 期間(開始)が正しくありません。,;';
          g_vMSG := g_vMSG || g_vERRTMPMSG;
        END IF;
        -- 開始年月の年月チェックでエラーの場合
        bRTN := KKAPK0020.FISDATEW( g_vJYOUKEN1 );
        IF bRTN = FALSE THEN
          --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.002:IT_GKB_00338の対応
          --g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,開始年月が正しくありません。,;';
          g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出開始生年月日 期間(開始)が正しくありません。,;';
          g_vMSG := g_vMSG || g_vERRTMPMSG;
        END IF;
        --条件２のチェック
-- 2024/06/12 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
       --条件2の入力条件の日付等の妥当性チェック
       nMSG := KKBPK5551.FJOKENDATECHK('GKB',g_sSHORIID,0,2,1,g_vJYOUKEN2 );
       IF nMSG IS NOT NULL THEN
          g_vMSG := g_vMSG || g_sGYOUMUCODE || nMSG;
        END IF;
-- 2024/06/12 ZCZL.muzl Add end
        -- 終了年月の数値型変換でエラーの場合
        bRTN := KKAPK0010.FISNUMERIC( g_vJYOUKEN2 );
        IF bRTN = FALSE THEN
          --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.002:IT_GKB_00338の対応
          --g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,終了年月が正しくありません。,;';
          g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出終了生年月日 期間(終了)が正しくありません。,;';
          g_vMSG := g_vMSG || g_vERRTMPMSG;
        END IF;
        -- 終了年月の年月チェックでエラーの場合
        bRTN := KKAPK0020.FISDATEW( g_vJYOUKEN2 );
        IF bRTN = FALSE THEN
          --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.002:IT_GKB_00338の対応
          --g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,終了年月が正しくありません。,;';
          g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出終了生年月日 期間(終了)が正しくありません。,;';
          g_vMSG := g_vMSG || g_vERRTMPMSG;
        END IF;
        -- 変数.開始年月 > 変数.終了年月の場合
        IF g_vJYOUKEN1 > g_vJYOUKEN2 THEN
          --2024/10/21 ZCZL.LIUDI UPDATE 0.3.000.002:IT_GKB_00338の対応
          --g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,開始年月、終了年月の関係が正しくありません。,;';
          g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出開始生年月日 期間(開始)、抽出終了生年月日 期間(終了)の関係が正しくありません。,;';
          g_vMSG := g_vMSG || g_vERRTMPMSG;
        END IF;
        -- 学年がない場合
        IF g_vJYOUKEN3 IS NULL THEN
          g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,学年が正しくありません。,;';
          g_vMSG := g_vMSG || g_vERRTMPMSG;
        END IF;
        -- 学校区分がない場合
        IF g_vJYOUKEN4 IS NULL THEN
          g_vERRTMPMSG := g_sGYOUMUCODE || ',99999,学校区分が正しくありません。,;';
          g_vMSG := g_vMSG || g_vERRTMPMSG;
        END IF;
        o_vRESULT := g_vMSG;
-- 2024/06/12 ZCZL.muzl Add end

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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
        g_oKENSU_LIST.EXTEND(2);
-- 2024/12/26 JIP.KF Rep start
--        g_oKENSU_LIST(1) :=GKBEKENSU_RECORD(g_nKENSAKU,'入力 就学校変更満了通知書対象件数',1);
--        g_oKENSU_LIST(2) :=GKBEKENSU_RECORD(g_nCSVKENSAKU,'出力 就学校変更満了通知書ＣＳＶ',2);
        g_oKENSU_LIST(1) :=GKBEKENSU_RECORD(g_nKENSAKU,'入力 学齢簿情報チェック一覧対象件数',1);
        g_oKENSU_LIST(2) :=GKBEKENSU_RECORD(g_nCSVKENSAKU,'出力 学齢簿情報チェック一覧ＣＳＶ',2);
-- 2024/12/26 JIP.KF Rep start
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

    --------------------------------------------------------------------
    --  日付西暦変換
    --------------------------------------------------------------------
    FUNCTION FUNC_SEIREKI_HENKAN( i_IWAREKI IN PLS_INTEGER ) RETURN PLS_INTEGER IS
      BRTN   BOOLEAN;
    BEGIN
      io_IWAREKIHIZUKE  := i_IWAREKI;
      io_ISEIREKIHIZUKE := NULL;
      BRTN := KKAPK0020.FDAYEDIT( io_IWAREKIHIZUKE,
                                   io_ISEIREKIHIZUKE,
                                   o_VEDIT_GYYMMDD1,
                                   o_VEDIT_GYYMMDD2,
                                   o_VEDIT_GYYMMDD3,
                                   o_VKJ_GENGO,
                                   o_VKG_GENGO,
                                   o_IWAREKI_YY,
                                   o_ISEIREKI_YYYY,
                                   o_IWAREKI_GYYMM,
                                   o_IMM,
                                   o_IDD,
                                   o_IWAREKIHIZUKE,
                                   o_ISEIREKIHIZUKE );
      RETURN io_ISEIREKIHIZUKE;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 0;
    END FUNC_SEIREKI_HENKAN;

    --------------------------------------------------------------------
    --  初期処理
    --------------------------------------------------------------------
    PROCEDURE PROC_INITIAL( o_BRTN OUT BOOLEAN ) IS
    BEGIN
      -- システム日付取得
      ISYSDATE := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
      --処理条件の取得
      IKAISHI_SEINENGAPI := FUNC_SEIREKI_HENKAN( g_vJYOUKEN1 );  -- 抽出開始生年月日
      ISHURYO_SEINENGAPI := FUNC_SEIREKI_HENKAN( g_vJYOUKEN2 );  -- 抽出終了生年月日
      IGAKUNEN           := NVL(g_vJYOUKEN3, 0);                 -- 学年
      IGAKO_KBN          := NVL(g_vJYOUKEN4, 0);                 -- 学校区分
      o_BRTN     := c_BNORMALEND;
    END PROC_INITIAL;

    --------------------------------------------------------------------
    --  稼働ユーザー情報取得
    --------------------------------------------------------------------
    PROCEDURE PROC_GET_KYOTSU( i_IKIJYUNBI IN  PLS_INTEGER,
                               o_BRTN      OUT BOOLEAN ) IS
      IRTN PLS_INTEGER;
    BEGIN
      -- 稼動ユーザ情報取得
      IRTN := KKAPK0030.FKYOTU( i_IKIJYUNBI,
                                 o_IUSER_ID,
                                 o_IJICHI_CD,
                                 o_IGAPPEI_BI,
                                 o_IUSER_KBN,
                                 o_VGUNSHIMEI,
                                 o_VUSERMEI,
                                 o_VSHUCHOMEI,
                                 o_VKENMEI,
                                 o_VSHUNYUNINSHOBUN,
                                 o_VYUBIN_NO,
                                 o_VSHOZAICHI,
                                 o_VTEL_NO);
      IF IRTN = 0 THEN
        o_BRTN := c_BNORMALEND;
      ELSE
        BRTN   := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'PROC_GET_KYOTSU', 1, '', '', SUBSTR('稼動ユーザー情報の取得が異常終了しました。', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        o_BRTN := c_BERROR;
      END IF;
    END PROC_GET_KYOTSU;

    --------------------------------------------------------------------
    --  学校区名取得
    --------------------------------------------------------------------
    FUNCTION FUNC_GET_GAKOMEI( i_IGAKO_KBN IN  PLS_INTEGER,
                               i_IGAKO_CD  IN  PLS_INTEGER ) RETURN NVARCHAR2 IS
      VGAKOMEI  NVARCHAR2(60);
    BEGIN
      IF i_IGAKO_KBN = 1 THEN     -- 小学校
        SELECT SYOGAKOMEI
          INTO VGAKOMEI
          FROM GKBTSHOGAKKO
         WHERE SYOGAKO_CD = i_IGAKO_CD;
      ELSIF i_IGAKO_KBN = 2 THEN  -- 中学校
        SELECT TYUGAKOMEI
          INTO VGAKOMEI
          FROM GKBTCHUGAKKO
         WHERE TYUGAKO_CD = i_IGAKO_CD;
      END IF;
      RETURN VGAKOMEI;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_GET_GAKOMEI;

    --------------------------------------------------------------------
    --  学年名取得
    --------------------------------------------------------------------
    FUNCTION FUNC_GET_GAKUNENMEI( i_IGAKUNEN IN  PLS_INTEGER ) RETURN NVARCHAR2 IS
      VGAKUNEN  NVARCHAR2(60);
    BEGIN
      SELECT GAKUNENMEI
        INTO VGAKUNEN
        FROM GKBTGAKUNEN
       WHERE GAKUNEN_CD = i_IGAKUNEN;
      RETURN VGAKUNEN;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_GET_GAKUNENMEI;

    --------------------------------------------------------------------
    --  学校区名取得（住記）
    --------------------------------------------------------------------
    FUNCTION FUNC_GET_GAKOMEI_JUKI( i_IGAKO_KBN         IN  PLS_INTEGER,
                                    i_IGAKO_CD          IN  PLS_INTEGER,
                                    i_ISANTEIDANTAI_CD  IN  PLS_INTEGER ) RETURN NVARCHAR2 IS
      VGAKOMEI          NVARCHAR2(60);
      ISANTEIDANTAI_CD  PLS_INTEGER;
    BEGIN
      -- 算定団体コード
      If ISYSDATE >= o_IGAPPEI_BI THEN
        ISANTEIDANTAI_CD := 1;
      ELSE
        ISANTEIDANTAI_CD := i_ISANTEIDANTAI_CD;
      END IF;
      IF i_IGAKO_KBN = 1 THEN     -- 小学校
        VGAKOMEI := GAAPK0030.FSHOGAKUMEI( ISANTEIDANTAI_CD, i_IGAKO_CD );
      ELSIF i_IGAKO_KBN = 2 THEN  -- 中学校
        VGAKOMEI := GAAPK0030.FCHUGAKUMEI( ISANTEIDANTAI_CD, i_IGAKO_CD );
      END IF;
      RETURN VGAKOMEI;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_GET_GAKOMEI_JUKI;

    --------------------------------------------------------------------
    --  備考編集
    --------------------------------------------------------------------
    FUNCTION FUNC_EDIT_BIKO( i_IERR_KBN             IN  PLS_INTEGER,
                             i_IJUMIN_NAKUNARU_JIYU IN  PLS_INTEGER ) RETURN NVARCHAR2 IS
      VBIKO  NVARCHAR2(20);
-- 2024/06/12 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
      nKOJINSETAIKBN         NUMBER;
      nYOKUSHIKBN            NUMBER;
      nIDOYOKUSHIKBN         NUMBER;
      nHAKKOYOKUSHIKBN       NUMBER;
      nSHOKAIYOKUSHIKBN      NUMBER;
      vSHORICHUIKBN          NVARCHAR2(20);
      vTOUGOUNO              NVARCHAR2(20);
      nSYSTEMTYP             NUMBER;
      nRTN                   NUMBER;
      nKBN1                  NUMBER;
      nKBN2                  NUMBER;
-- 2024/06/12 ZCZL.muzl Add end
    BEGIN
-- 2024/06/12 ZCZL.muzl Update start 0.3.000.000:新WizLIFE２次開発
--       IF i_IERR_KBN = 1 THEN
--         VBIKO := '学齢簿情報なし';
--       ELSIF i_IERR_KBN = 2 THEN
--         VBIKO := GAAPK0030.FIDOJIYUMEI( i_IJUMIN_NAKUNARU_JIYU );
--       ELSIF i_IERR_KBN = 3 THEN
--         VBIKO := '学年不一致';
--       ELSIF i_IERR_KBN = 4 THEN
--         VBIKO := '学校区不一致';
--       END IF;
      -- 児童の抑止判定
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応  
   IF  i_IERR_KBN = 5 THEN      
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応     
      nRTN := GAAPK0030.FGETDV(RWORK.JIDO_KOJIN_NO,RWORK.SETAI_NO,TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),'GKB',2,
               nKOJINSETAIKBN,nYOKUSHIKBN,nIDOYOKUSHIKBN,nHAKKOYOKUSHIKBN,nSHOKAIYOKUSHIKBN,vSHORICHUIKBN,vTOUGOUNO,nSYSTEMTYP);
--  2025/04/30 CTC.LIUJUNHAO ADD START 1.0.003.000:GKB_QA13755_全員が支援措置対象者の旨を印字される対応
      --IF nYOKUSHIKBN > 0 THEN
      IF nYOKUSHIKBN > 0 AND nYOKUSHIKBN < 99 THEN 
--  2025/04/30 CTC.LIUJUNHAO ADD END 1.0.003.000:GKB_QA13755_全員が支援措置対象者の旨を印字される対応
        nKBN1 := 1 ;   -- 対象者は支援措置該当と判定する
      ELSE
        nKBN1 := 0 ;   -- 対象者は支援措置非該当であると判定する
      END IF;
      -- 保護者の抑止判定
      nRTN := GAAPK0030.FGETDV(RWORK.HOGOSHA_KOJIN_NO,RWORK.SETAI_NO,TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),'GKB',2,
               nKOJINSETAIKBN,nYOKUSHIKBN,nIDOYOKUSHIKBN,nHAKKOYOKUSHIKBN,nSHOKAIYOKUSHIKBN,vSHORICHUIKBN,vTOUGOUNO,nSYSTEMTYP);
--  2025/04/30 CTC.LIUJUNHAO ADD START 1.0.003.000:GKB_QA13755_全員が支援措置対象者の旨を印字される対応
      --IF nYOKUSHIKBN > 0 THEN 
      IF nYOKUSHIKBN > 0 AND nYOKUSHIKBN < 99 THEN
--  2025/04/30 CTC.LIUJUNHAO ADD END 1.0.003.000:GKB_QA13755_全員が支援措置対象者の旨を印字される対応
        nKBN2 := 1 ;   -- 対象者は支援措置該当と判定する
      ELSE
        nKBN2 := 0 ;   -- 対象者は支援措置非該当であると判定する
      END IF;
      -- 支援措置対象者情報を備考にセットする
      IF nKBN1 = 1 AND nKBN2 = 0 THEN
        VBIKO := '支援措置対象（児童）';
      ELSIF nKBN1 = 0 AND nKBN2 = 1 THEN
        VBIKO := '支援措置対象（保護者）';
      ELSIF nKBN1 = 1 AND nKBN2 = 1 THEN
        VBIKO := '支援措置対象（児童・保護者）';
      ELSE
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応      
        --NULL;
        VBIKO := NULL;
      END IF;
   END IF;   
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応       
-- 2024/06/12 ZCZL.muzl Update end
      RETURN VBIKO;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_EDIT_BIKO;

    --------------------------------------------------------------------
    --  エラー区分名称
    --------------------------------------------------------------------
    FUNCTION FUNC_EDIT_ERR_KBN( i_IERR_KBN IN  PLS_INTEGER ) RETURN NVARCHAR2 IS
      VERR_KBN  NVARCHAR2(20);
    BEGIN
      IF i_IERR_KBN = 1 THEN
        VERR_KBN := '学齢簿情報なし';
      ELSIF i_IERR_KBN = 2 THEN
        VERR_KBN := '住記喪失';
      ELSIF i_IERR_KBN = 3 THEN
        VERR_KBN := '学年不一致';
      ELSIF i_IERR_KBN = 4 THEN
        VERR_KBN := '学校区不一致';
-- 2024/06/12 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
      ELSIF i_IERR_KBN = 5 THEN
        VERR_KBN := '支援措置対象';
-- 2024/06/12 ZCZL.muzl Add end
      END IF;
      RETURN VERR_KBN;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END FUNC_EDIT_ERR_KBN;

    --------------------------------------------------------------------
    --  中間ファイル編集
    --------------------------------------------------------------------
    PROCEDURE PROC_EDIT_WK( o_BRTN OUT BOOLEAN ) IS
      BRTN                BOOLEAN;
      IRTN                PLS_INTEGER;
      RATENA_HOGO         GABTATENAKIHON%ROWTYPE;
      RSOFU_HOGO          GABTSOFUSAKI%ROWTYPE;
-- 2024/06/18 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
      vKOKUMEI_KANA            NVARCHAR2(120);          -- 国名カナ
      vKOKUMEI_ALP             NVARCHAR2(120);          -- 国名アルファベット
-- 2025/01/14 JPJYS.LIJINGHUI UPDATE 0.3.000.004:学区マスタ横展開の対応  Start
--      o_vSYOGAKU_CD            NUMBER;                  -- 小学校区コード
      o_vSYOGAKU_CD            GKBTGAKUREIBO.SYOGAKO_CD%TYPE;       -- 小学校区コード      
--      o_vTYUGAKU_CD            NUMBER;                  -- 中学校区コード
      o_vTYUGAKU_CD            GKBTGAKUREIBO.TYUGAKO_CD%TYPE;       -- 中学校区コード
-- 2025/01/14 JPJYS.LIJINGHUI UPDATE 0.3.000.004:学区マスタ横展開の対応  End
      o_vSYOGAKU_NM            NVARCHAR2(300);          -- 小学校区名
      o_vTYUGAKU_NM            NVARCHAR2(300);          -- 中学校区名
-- 2024/06/18 ZCZL.muzl Add end
    BEGIN
-- 2024/06/06 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
      -- 宛名情報取得（児童生徒）
      IRTN := GAAPK0030.FGETATENA( RTAISHO.KOJIN_NO,
                                 'GKB',
                                 ISYSDATE,
                                 RATENA_HOGO,
                                 RSOFU_HOGO );
      -- 国籍コードより、児童生徒の国籍名称を取得する。
      IRTN := GKAFKKKMGET(RATENA_HOGO.KOKUSEKI_CD,vKOKUMEI_KANA,g_vKOKUMEI1,vKOKUMEI_ALP);
-- 2024/06/06 ZCZL.muzl Add end
      -- 宛名情報取得（保護者）
      IRTN := GAAPK0030.FGETATENA( RTAISHO.HOGOSYA_KOJIN_NO,
                                 'GKB',
                                 ISYSDATE,
                                 RATENA_HOGO,
                                 RSOFU_HOGO );
-- 2024/06/12 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
      IRTN := GKAFKKKMGET(RATENA_HOGO.KOKUSEKI_CD,vKOKUMEI_KANA,g_vKOKUMEI2,vKOKUMEI_ALP);
      -- 学校区は学齢簿から取得、戻り値を設定する。
-- 2025/01/14 JPJYS.LIJINGHUI UPDATE 0.3.000.004:学区マスタ横展開の対応  Start
      --IF GKBFKGKKUGET(RTAISHO.KOJIN_NO,RTAISHO.RIREKI_RENBAN,o_vSYOGAKU_CD,o_vSYOGAKU_NM,o_vTYUGAKU_CD,o_vTYUGAKU_NM) = 0 THEN
        IF IGAKO_KBN = 1 THEN
          BEGIN
            SELECT SYOGAKO_CD
              INTO
                   o_vSYOGAKU_CD
              FROM
                   GKBTGAKUREIBO
             WHERE
                   KOJIN_NO = RTAISHO.KOJIN_NO
               AND RIREKI_RENBAN =RTAISHO.RIREKI_RENBAN;
          EXCEPTION
                 WHEN OTHERS THEN
                   o_vSYOGAKU_CD := 0;
          END;
          g_nGAKOKUCD := o_vSYOGAKU_CD;
        ELSIF IGAKO_KBN = 2 THEN
          BEGIN
            SELECT TYUGAKO_CD
              INTO
                   o_vTYUGAKU_CD
              FROM
                   GKBTGAKUREIBO
             WHERE
                   KOJIN_NO = RTAISHO.KOJIN_NO
               AND RIREKI_RENBAN =RTAISHO.RIREKI_RENBAN;
          EXCEPTION
                 WHEN OTHERS THEN
                   o_vTYUGAKU_CD := 0;
          END;
          g_nGAKOKUCD := o_vTYUGAKU_CD;
        END IF;
   --   END IF;
-- 2025/01/14 JPJYS.LIJINGHUI UPDATE 0.3.000.004:学区マスタ横展開の対応  End
-- 2024/06/12 ZCZL.muzl Add end
      RWORK                        := NULL;
      RWORK.JIDO_KOJIN_NO          := RTAISHO.KOJIN_NO;           -- 児童個人番号
      RWORK.JIDO_SHIMEI_KANA       := RTAISHO.SHIMEI_KANA;        -- 児童氏名かな
      RWORK.JIDO_SHIMEI_KANJI      := RTAISHO.SHIMEI_KANJI;       -- 児童氏名
      RWORK.SEINENGAPI             := RTAISHO.SEINENGAPI;         -- 生年月日
      RWORK.HYOJI_SEINENGAPI       := RTAISHO.SEINENGAPI;         -- 表示用生年月日
      RWORK.SEIBETSU               := RTAISHO.SEIBETSU;           -- 性別
      -- 表示用性別
      IF RTAISHO.SEIBETSU = 1 THEN
        RWORK.HYOJI_SEIBETSU       := '男';
      ELSIF RTAISHO.SEIBETSU = 2 THEN
        RWORK.HYOJI_SEIBETSU       := '女';
      ELSE
        RWORK.HYOJI_SEIBETSU       := '';
      END IF;
      -- 保護者との関係
      IRTN := GKBFKZKGMGET( 1,
                            RTAISHO.ZOKUGARA1,
                            RTAISHO.ZOKUGARA2,
                            RTAISHO.ZOKUGARA3,
                            RTAISHO.ZOKUGARA4,
                            RWORK.ZOKUGARAMEI1,
                            IZOKUGARAERR );
-- 2024/06/12 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
      RWORK.JIDO_KOKUSEKI          := g_vKOKUMEI1;                  -- 児童生徒国籍
      RWORK.SETAI_NO               := RTAISHO.SETAI_NO;           -- 世帯番号
      RWORK.HOGOSHA_KOJIN_NO       := RTAISHO.HOGOSYA_KOJIN_NO;   -- 保護者個人番号
      RWORK.HOGOSHA_SHIMEI_KANA    := RATENA_HOGO.SHIMEI_KANA;    -- 保護者氏名かな
      RWORK.HOGOSHA_SHIMEI_KANJI   := RATENA_HOGO.SHIMEI_KANJI;   -- 保護者氏名漢字
-- 2024/06/12 ZCZL.muzl Add 0.3.000.000:新WizLIFE２次開発
      RWORK.HOGOSHA_KOKUSEKI       := g_vKOKUMEI2;                  -- 保護者国籍
      -- 児童生徒との関係
      IRTN := GKBFKZKGMGET( 2,
                            RTAISHO.HOGOSYA_ZOKUGARA1,
                            RTAISHO.HOGOSYA_ZOKUGARA2,
                            RTAISHO.HOGOSYA_ZOKUGARA3,
                            RTAISHO.HOGOSYA_ZOKUGARA4,
                            RWORK.ZOKUGARAMEI2,
                            IZOKUGARAERR );
      RWORK.GAKUNEN_CD             := RTAISHO.GAKUNEN_CD;         -- 学年コード
      -- 学年名
      RWORK.GAKUNENMEI             := FUNC_GET_GAKUNENMEI( RTAISHO.GAKUNEN_CD );
      RWORK.ATENA_GAKU_CD          := RTAISHO.ATENA_GAKU_CD;      -- 宛名学校区コード
      -- 学校区名取得（住記）
      RWORK.ATENA_GAKU_MEI         := FUNC_GET_GAKOMEI_JUKI( IGAKO_KBN,
                                                             RTAISHO.ATENA_GAKU_CD,
                                                             RTAISHO.SANTEIDANTAI_CD );
-- 2024/06/12 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--       RWORK.GAKOKU_CD              := RTAISHO.GAKOKU_CD;          -- 学校区コード
      RWORK.GAKOKU_CD              := g_nGAKOKUCD;          -- 学校区コード
      -- 学校区名取得
      RWORK.GAKOKUMEI              := FUNC_GET_GAKOMEI( IGAKO_KBN,
                                                        RTAISHO.GAKOKU_CD );
      RWORK.GYOSEIKU_CD            := RTAISHO.GYOSEIKU_CD;        -- 行政区コード
      -- 行政区名取得
      RWORK.GYOSEIKUMEI            := GAAPK0030.FGYOSEIKUMEI( RTAISHO.SANTEIDANTAI_CD, RTAISHO.GYOSEIKU_CD );
      RWORK.HAN_CD                 := RTAISHO.HAN_CD;             -- 班コード
      -- 班名取得
      RWORK.HANMEI                 := GAAPK0030.FHANMEI( RTAISHO.SANTEIDANTAI_CD, RTAISHO.HAN_CD );
      RWORK.SANTEIDANTAI_CD        := RTAISHO.SANTEIDANTAI_CD;    -- 算定団体コード
      -- 算定団体名称取得
      IRTN := GAAPK0030.FJICHINAME( RTAISHO.SANTEIDANTAI_CD,
                                     RWORK.SANTEIDANTAIMEI );
      RWORK.YUBIN_NO               := RTAISHO.YUBIN_NO;           -- 郵便番号
      RWORK.CHOMEI                 := RTAISHO.CHOMEI;             -- 町名
      RWORK.BANCHI                 := RTAISHO.BANCHI;             -- 番地
      RWORK.KATAGAKI               := RTAISHO.KATAGAKI;           -- 方書
      -- 備考
      RWORK.BIKO                   := FUNC_EDIT_BIKO( RTAISHO.ERR_KBN,
                                                      RTAISHO.JUMIN_NAKUNARU_JIYU );
      RWORK.SOSHITSUBI             := RTAISHO.JUMIN_NAKUNARU;     -- 喪失日
      RWORK.KAIPEJI_CD             := RTAISHO.ERR_KBN;            -- 改ページコード
      RWORK.KAIPEJI                := FUNC_EDIT_ERR_KBN( RTAISHO.ERR_KBN );     -- 改ページ名称
      RWORK.SAKUSEIBI              := ISYSDATE;                   -- 作成日
      -- 宛名情報取得（保護者）
      IRTN := GAAPK0030.FGETATENA(RTAISHO.KOJIN_NO, 'GKB', ISYSDATE, RATENA_HOGO, RSOFU_HOGO);
      RWORK.JINKAKU_KBN := RATENA_HOGO.JINKAKU_KBN;
      o_BRTN                       := c_BNORMALEND;
    EXCEPTION
      WHEN OTHERS THEN
        NSQLCODE := SQLCODE;
        ROLLBACK;
        BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'PROC_EDIT_WK', 1, SQLCODE, SQLERRM, SUBSTR('中間ファイル編集が異常終了しました。' || SQLERRM(NSQLCODE), 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        o_BRTN := c_BERROR;
    END PROC_EDIT_WK;

    --------------------------------------------------------------------------------
    --  中間ファイル出力
    --------------------------------------------------------------------------------
    PROCEDURE PROC_OUT_WK(o_BRTN OUT BOOLEAN) IS
      BRTN  BOOLEAN;  -- リターンコード
    BEGIN
      BEGIN
        INSERT INTO GKBWCHECK VALUES RWORK;
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00098の対応
        g_nKENSAKU := g_nKENSAKU + 1;
        o_BRTN := c_BNORMALEND;
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応        
                --次の人のため、初期化する
                RTAISHO                          := NULL;  
                RWORK                            := NULL;    
--  2025/10/08 CTC.LIUJUNHAO UPDATE END  1.0.108.000:GKB_QA20569対応
      EXCEPTION
        WHEN OTHERS THEN
          NSQLCODE := SQLCODE;
          ROLLBACK;
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'PROC_OUT_WK', 1, SQLCODE, SQLERRM, SUBSTR('中間ファイル出力が異常終了しました。' || SQLERRM(NSQLCODE), 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          o_BRTN := c_BERROR;
      END;
    END PROC_OUT_WK;

    --------------------------------------------------------
    --  機能概要      : 作表処理１
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        eException       EXCEPTION;
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応  
     JIDOHOGOSHA_MARK         NUMBER;                   --児童生徒保護者判定マーク
      nKOJINSETAIKBN         NUMBER;
      nYOKUSHIKBN            NUMBER;
      nIDOYOKUSHIKBN         NUMBER;
      nHAKKOYOKUSHIKBN       NUMBER;
      nSHOKAIYOKUSHIKBN      NUMBER;
      vSHORICHUIKBN          NVARCHAR2(20);
      vTOUGOUNO              NVARCHAR2(20);
      nSYSTEMTYP             NUMBER;
      nRTN                   NUMBER;
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応          
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        -- 初期処理
        PROC_INITIAL( BRTN );
        IF BRTN = c_BERROR THEN
          RAISE eException;
        END IF;
        -- 稼動ユーザー情報取得
        PROC_GET_KYOTSU( ISYSDATE, BRTN );
        IF BRTN = c_BERROR THEN
          RAISE eException;
        END IF;
        -- 中間ファイル削除
        IRTN := KKAPK3000.FTRUNCATE( c_VTBLNAME, VSQLERRM );
        IF IRTN <> 0 THEN
          BRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR('中間ファイル削除処理が異常終了しました。' || VSQLERRM, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          RAISE eException;
        END IF;
        -- 対象データ取得
        FOR CRTAISHO IN CTAISHO( IKAISHI_SEINENGAPI,
                                 ISHURYO_SEINENGAPI,
                                 IGAKUNEN,
                                 IGAKO_KBN ) LOOP
          RTAISHO := CRTAISHO;
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応          
      IF  RTAISHO.ERR_KBN = 51 THEN      
            JIDOHOGOSHA_MARK  := 0;
            nRTN := GAAPK0030.FGETDV(RTAISHO.KOJIN_NO,RTAISHO.SETAI_NO,TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),'GKB',2,
                     nKOJINSETAIKBN,nYOKUSHIKBN,nIDOYOKUSHIKBN,nHAKKOYOKUSHIKBN,nSHOKAIYOKUSHIKBN,vSHORICHUIKBN,vTOUGOUNO,nSYSTEMTYP);
            IF nYOKUSHIKBN > 0 AND nYOKUSHIKBN < 99 THEN 
              JIDOHOGOSHA_MARK  := 1 ;   -- 対象者は支援措置該当と判定する
            ELSE
              JIDOHOGOSHA_MARK  := JIDOHOGOSHA_MARK ;   -- 対象者は支援措置非該当であると判定する
            END IF;
            -- 保護者の抑止判定
            nRTN := GAAPK0030.FGETDV(RTAISHO.HOGOSYA_KOJIN_NO,RTAISHO.SETAI_NO,TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),'GKB',2,
                     nKOJINSETAIKBN,nYOKUSHIKBN,nIDOYOKUSHIKBN,nHAKKOYOKUSHIKBN,nSHOKAIYOKUSHIKBN,vSHORICHUIKBN,vTOUGOUNO,nSYSTEMTYP);
            IF nYOKUSHIKBN > 0 AND nYOKUSHIKBN < 99 THEN 
              JIDOHOGOSHA_MARK  := 1 ;   -- 対象者は支援措置該当と判定する
            ELSE
              JIDOHOGOSHA_MARK  := JIDOHOGOSHA_MARK ;   -- 対象者は支援措置非該当であると判定する
            END IF;
            
            IF JIDOHOGOSHA_MARK = 1 THEN
               RTAISHO.ERR_KBN := 5;
            ELSE
               RTAISHO.ERR_KBN := 51;
            END IF;
            JIDOHOGOSHA_MARK  := 0;
            nYOKUSHIKBN    := 0; 
          END IF;
        IF  RTAISHO.ERR_KBN IN (1,2,3,4,5) THEN
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応                      
          IROWCNT := IROWCNT + 1;
          -- 中間ファイル編集
          PROC_EDIT_WK( BRTN );
          IF BRTN = c_BERROR THEN
            RAISE eException;
          END IF;
          -- 中間ファイル出力
          PROC_OUT_WK( BRTN );
          IF BRTN = c_BERROR THEN
            RAISE eException;
          END IF;
--  2025/10/08 CTC.LIUJUNHAO UPDATE START 1.0.108.000:GKB_QA20569対応           
        ELSE
          CONTINUE;
        END IF;
--  2025/10/08 CTC.LIUJUNHAO UPDATE END 1.0.108.000:GKB_QA20569対応            
        END LOOP;
        -- CSV作成
        GKBSBCHKLCSV( g_nJOBNUM,
                      g_sTANTOCODE,
                      g_sWSNUM,
                      g_nTIME,
                      NULL,
                      c_VTBLNAME,
                      BRTN,
                      g_rJSTP.Orderbyclause,
                      c_BATCH );
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD 0.3.000.001:8月1日認識合わせの横展開とIT_GKB_00098の対応
        g_nCSVKENSAKU := GKBFKTBLCNT('GKBWL320R001', ' BATCHKBN = ' || c_BATCH || ' AND WSNUM = ''' || g_sWSNUM || '''');
        -- 帳票出力CSVの作成
        bRTN := FUNC_B11CSV('GKBWL320R001');

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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
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
END GKBPB00150;
/
