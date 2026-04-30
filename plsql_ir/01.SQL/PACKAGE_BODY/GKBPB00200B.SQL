CREATE OR REPLACE PACKAGE BODY GKBPB00200
--1.0.203.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 異動者一覧表(H24住基法改正　施行日後)
--  機能概要      : 異動の事由ごとに、対象者の一覧表を作成
--                  外国人の異動は住民記録データを参照
--  バージョン    : Ver 0.2.000.000
--  作成者／作成日: ZCZL.LIKEWEN 2024/01/06
--------------------------------------------------------
--  変更履歴
--  2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
--  2024/10/30 ZCZL.WANGYUNING UPDATE 0.3.000.003:IT_GKB_00213仕様変更対応
--  2025/01/14 JPJYS.YANGXIHAN UPDATE 0.3.000.004:学区マスタ関連修正方針対応
--  2025/02/07 JPJYS.WUZHENGDONG UPDATE 0.3.000.005:ST_GKB_TMP00045 対応
-- 2025/02/08 JPJYS.GONGYANYAN Update 0.3.000.006:ST_GKB_TMP00045 対応
-- 2025/02/08 JPJYS.GONGYANYAN Update 0.3.000.007:資産比較対応
-- 2025/05/08 CTC.GL UPDATE 1.0.003.000:GKB_QA13680対応
-- 2025/06/16 CTC.LIUJUNHAO UPDATE 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
-- 2025/09/29 JIP.Makishima Update 1.0.107.000:GKB_QA20860_住記異動者一覧表の氏名等を最新情報で表示するよう対応
-- 2025/10/24 CTC.GL UPDATE 1.0.203.000:GKB_QA21357対応
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
-- 2024/06/12 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
    g_nINDEX                      NUMBER         := 0;
    g_nTIME NUMBER;  --時分秒
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
    g_nDAY  NUMBER;  --日付
-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --パラメータ変数
    --条件
    g_vJYOUKEN1  NVARCHAR2(500);
    g_vJYOUKEN2  NVARCHAR2(500);
    g_vJYOUKEN3  NVARCHAR2(500);
    g_vJYOUKEN4  NVARCHAR2(500);
    g_vJYOUKEN5  NVARCHAR2(500);
    g_vJYOUKEN6  NVARCHAR2(500);
    g_vJYOUKEN7  NVARCHAR2(500);
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--     g_vJYOUKEN8  NVARCHAR2(500);
    VSQLERRM         NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
    VIDO_JIYU        NVARCHAR2(256);    -- 異動事由コード
-- 2024/06/12 ZCZL.wangyunhan Update end 
    VMSG NVARCHAR2(4000);
    IRTN PLS_INTEGER;
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
    ---------------------------------------------------------------------
    -- 定数宣言
    ---------------------------------------------------------------------
    -- 学校区分
    c_IEAGAKKO_SYOGAKO   CONSTANT PLS_INTEGER := 1;  -- 小学校
    c_IEAGAKKO_TYUGAKO   CONSTANT PLS_INTEGER := 2;  -- 中学校
    c_IEQGAKKO_SYOGAKO   CONSTANT PLS_INTEGER := 3;  -- 小学校
    c_IEQGAKKO_TYUGAKO   CONSTANT PLS_INTEGER := 4;  -- 中学校
    c_IEQGAKKO_KUIKIGAI  CONSTANT PLS_INTEGER := 5;  -- 区域外
    c_IEQGAKKO_YOGOGAKO  CONSTANT PLS_INTEGER := 6;  -- 養護学校

    c_IRETOK             CONSTANT PLS_INTEGER := 0;  -- 正常終了
    c_IERR               CONSTANT PLS_INTEGER := 1;  -- 異常
    -- 帳票系
    -- 帳票タイトル
    c_VCHOHYO_NAME010    CONSTANT NVARCHAR2(100) := '住記異動者一覧';
    c_VCHOHYO_NAME011    CONSTANT NVARCHAR2(100) := '住記異動者一覧（世帯構成員異動）';
    -- 項目名称
    c_VCHOHYO_ITEM010    CONSTANT NVARCHAR2(50)  := '異動者氏名';
    c_VCHOHYO_ITEM011    CONSTANT NVARCHAR2(50)  := '児童・生徒氏名';
    c_VCHOHYO_ITEM020    CONSTANT NVARCHAR2(50)  := '世帯主名';
    c_VCHOHYO_ITEM021    CONSTANT NVARCHAR2(50)  := '世帯員氏名';
    c_VCHOHYO_ITEM030    CONSTANT NVARCHAR2(50)  := '';
    c_VCHOHYO_ITEM031    CONSTANT NVARCHAR2(50)  := '続柄（住記）';

    ---------------------------------------------------------------------
    -- 変数宣言
    ---------------------------------------------------------------------
    --抽出項目格納変数
    R_WKB                     GKBWIDOICHIRAN%ROWTYPE;
    --稼働ユーザー情報取得用変数
    o_IUSER_ID                PLS_INTEGER;
    o_IGAPPEI_BI              PLS_INTEGER;
    o_IJICHI_CD               PLS_INTEGER;
    o_IUSER_KBN               PLS_INTEGER;
    o_VGUNSHIMEI              NVARCHAR2(30);
    --各資格取得サブルーチン用変数
    B_RTN                     BOOLEAN   := TRUE;  --サブルーチン戻り値（共通）
    I_RTN                     PLS_INTEGER;        --サブルーチン戻り値
    R_GAKUREIBO               GKBTGAKUREIBO%ROWTYPE;    -- 学齢簿情報取得用
    NIDOCNT                   NUMBER(8);          --カーソルレコード件数
    NSYSJKN                   NUMBER(1);          --システム条件
    VKADOSHI                  VARCHAR2(40);       --稼働市町村名
    NSEINENGAPI_KAISHI        NUMBER(8);          --開始生年月日
    NSEINENGAPI_SHURYO        NUMBER(8);          --終了生年月日
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
    N_CHUSHUTSU_KAISHI        NUMBER(8);          --開始処理日
    N_CHUSHUTSU_SHURYO        NUMBER(8);          --終了処理日
-- 2024/06/12 ZCZL.wangyunhan Add end 
    NSHUKEI_KBN               NUMBER(8);          --集計区分取得用
    NSORT_KBN                 NUMBER(8);          --並び替え条件用（西条市対応）
    NJINKAKU_KBN              NUMBER(8);
    NSETAI_IDOKBN             NUMBER(8);          --世帯構成員の異動抽出区分（条件８）
    NSEIBETSU                 NUMBER(3);          --性別編集前
    NJUSHO                    NUMBER(3);          --現住所連番
    NZENJUSHO                 NUMBER(3);          --前住所連番
    NTENNYU                   NUMBER(3);          --転入前住所連番
    NHONSEKI                  NUMBER(3);          --本籍地連番
    NTENSHUTSU                NUMBER(3);          --転出予定地連番
    NTENKAKU                  NUMBER(3);          --転出確定地連番
    VKADO                     NVARCHAR2(40);      --稼働市町村名
    VEDCHOMEI                 NVARCHAR2(140);     --町名編集用
    VBIKO                     NVARCHAR2(120);     --備考編集用
    VERRMSG                   NVARCHAR2(256)
      :=  '住民異動届一覧表の作成処理が異常終了しました。'; --ログ出力用メッセージ
    VERRTMPMSG                NVARCHAR2(1000);
    VLOGMSG                   NVARCHAR2(256)  :=  '';       --ログ出力用メッセージ
    VLOGKBN                   NVARCHAR2(5);       --集計区分ログメッセージ用
    VRENBAN                   NUMBER(3);          --住所連番
    V_KIJUNBI                 NVARCHAR2(16) := '';
    V_SAKUSEIBI               NVARCHAR2(16) := '';
    V_KAISHIBI                NVARCHAR2(16) := '';
    V_SHURYOBI                NVARCHAR2(16) := '';
    V_SEINENGAPI_KAISHIBI     NVARCHAR2(16) := '';
    V_SEINENGAPI_SHURYOBI     NVARCHAR2(16) := '';
    V_IDOBI                   NVARCHAR2(16) := '';
    V_TODOKEBI                NVARCHAR2(16) := '';
    I_NENDOMATSU_BI           PLS_INTEGER;        -- 年度末日付(年度末年齢を算出するために使用)
    I_NENDOMATSU_NENREI       PLS_INTEGER;        -- 年度末年齢

    I_GAKKO_KBN               PLS_INTEGER;        -- 教育学校区分(小学校、中学校など)
    I_EQGAKKO_CD              PLS_INTEGER;        -- 教育学校コード
    I_EQIDOBI                 PLS_INTEGER;        -- 教育異動日(入学日、卒業日など)
    I_EQIDOBI_KBNGOTO         PLS_INTEGER;        -- 教育異動日(学校区分ごと: 小学校なら小学校の中での最新の異動日)
    I_TORIKOMI_KBN            PLS_INTEGER;        -- 取り込み区分
    IGAKUNEN_CD               PLS_INTEGER;
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD START 0.3.000.001:8月1日認識合わせの横展開
    g_nROWNUM                NUMBER;                        --変数.対象者件数
    g_nCSVNUM                NUMBER;                        --変数.CSV出力件数
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD END
   
    ---------------------------------------------------------------------
    -- カーソル宣言
    ---------------------------------------------------------------------
    -- 異動累計情報取得カーソル
    CURSOR C_IDORK( NKAISHI NUMBER,
                    NSHURYO NUMBER,
                    NSEINENGAPI_KAISHI NUMBER,
                    NSEINENGAPI_SHURYO NUMBER
                    ) IS
      SELECT I.KOJIN_NO,
             I.IDO_JIYU,
             I.SHORIBI_KEY,
             I.SHORI_JIKAN_KEY,
             I.SHORI_KBN_KEY,
             I.ZENBU_ICHIBU_KEY,
             I.SHOKUINKOJIN_NO_KEY,
             I.HAIKAN_KBN,
             I.BIKO_BUN,
             I.SHORIBI
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--          FROM JIBTIDORUIKEI I
--        WHERE I.SHORIBI_KEY  BETWEEN NKAISHI AND NSHURYO
--          AND I.IDO_JIYU BETWEEN 11 AND 54
--          AND I.IDO_JIYU NOT IN (51,52)
--          AND (EXISTS (SELECT G.KOJIN_NO
--                         FROM GKBTGAKUNENLNK G ,GABTATENAKIHON J2
--                        WHERE G.KOJIN_NO = I.KOJIN_NO
--                          AND G.KOJIN_NO = J2.KOJIN_NO
--                          AND J2.SEINENGAPI BETWEEN NSEINENGAPI_KAISHI AND NSEINENGAPI_SHURYO
--                          AND G.GAKUNEN_CD BETWEEN 0 AND 9)
--          OR EXISTS (SELECT J.KOJIN_NO
--                        FROM GABTATENAKIHON J
--                       WHERE J.KOJIN_NO = I.KOJIN_NO
--                         AND J.SEINENGAPI BETWEEN NSEINENGAPI_KAISHI AND NSEINENGAPI_SHURYO))
             ,SJ.SHIMEI_KANA   AS SJSHIMEI_KANA
             ,SJ.SHIMEI_KANJI  AS SJSHIMEI_KANJI
             ,SJ.KOKUSEKI_CD   AS SJKOKUSEKI_CD
             ,SJ.YUBIN_NO      AS SJYUBIN_NO
             ,SJ.CHOMEI        AS SJCHOMEI
             ,SJ.BANCHI        AS SJBANCHI
             ,SJ.KOJIN_NO      AS SJKOJIN_NO
             ,SJ.SEINENGAPI    AS SJSEINENGAPI
             ,SJ.KATAGAKI      AS SJKATAGAKI
             ,SJ.ZOKUGARA_MEI  AS SJZOKUGARA_MEI
             ,SJ.SETAI_NO      AS SJSETAI_NO
             ,SJ.JINKAKU_KBN   AS SJJINKAKU_KBN
             ,SH.SHIMEI_KANA   AS SHSHIMEI_KANA
             ,SH.SHIMEI_KANJI  AS SHSHIMEI_KANJI
             ,SH.KOKUSEKI_CD   AS SHKOKUSEKI_CD
             ,SH.YUBIN_NO      AS SHYUBIN_NO
             ,SH.CHOMEI        AS SHCHOMEI
             ,SH.BANCHI        AS SHBANCHI
             ,SH.KOJIN_NO      AS SHKOJIN_NO
             ,SH.SEINENGAPI    AS SHSEINENGAPI
             ,SH.KATAGAKI      AS SHKATAGAKI
             ,SH.ZOKUGARA_MEI  AS SHZOKUGARA_MEI
             ,SH.SETAI_NO      AS SHSETAI_NO
             ,SH.JINKAKU_KBN   AS SHJINKAKU_KBN
             ,GKBTGAKUREIBO.GAKKO_KBN_CD
             ,GKBTGAKUREIBO.RIREKI_RENBAN
             ,GKBTGAKUREIBO.HOGOSYA_KOJIN_NO
             ,GKBTGAKUREIBO.SYOGAKO_CD
             ,GKBTGAKUREIBO.TYUGAKO_CD
             ,GKBTGAKUREIBO.KOJIN_NO AS BOKOJIN_NO
             ,GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1
             ,GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2
             ,GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3
             ,GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4
             ,GKBTGAKUREIBO.TODOKEDE_BI
             ,GKBTGAKUREIBO.SEIBETSU
             ,GKBTGAKUREIBO.GAKUNEN
             ,GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI
             ,GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA
             ,GKBTGAKUREIBO.SHORIBI AS BOSHORIBI
             ,GKBTGAKUREIBO.IDO_BI
             ,GKBTGAKUREIBO.KUIKIGAI_CD
             ,GKBTGAKUREIBO.YOGOGAKO_CD
             ,GKBTGAKUREIBO.GAKUKYU_CD
       FROM JIBTIDORUIKEI I,GKBTGAKUREIBO,GABVATENAALL SJ,GABVATENAALL SH
       WHERE I.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO
       AND GKBTGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN = SJ.RIREKI_RENBAN 
       AND GKBTGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN = SH.RIREKI_RENBAN 
       AND GKBTGAKUREIBO.KOJIN_NO = SJ.KOJIN_NO 
       AND GKBTGAKUREIBO.HOGOSYA_KOJIN_NO = SH.KOJIN_NO 
       AND SJ.KOJIN_NO = I.KOJIN_NO
       AND SH.KOJIN_NO = I.KOJIN_NO
         AND I.SHORIBI_KEY  BETWEEN NKAISHI AND NSHURYO
         AND I.IDO_JIYU IN (VIDO_JIYU)
         AND (EXISTS (SELECT G.KOJIN_NO
                        FROM GKBTGAKUREIBO G ,GABVATENAALL J2
                       WHERE G.KOJIN_NO = I.KOJIN_NO
                         AND G.KOJIN_NO = J2.KOJIN_NO
                         AND J2.SEINENGAPI BETWEEN NSEINENGAPI_KAISHI AND NSEINENGAPI_SHURYO
                         AND G.GAKUNEN BETWEEN 0 AND 9
                         AND G.SAISHIN_KBN = 0 
                         AND G.SAKUJO_FLG = 0)
         OR EXISTS (SELECT J.KOJIN_NO
                       FROM GABVATENAALL J
                      WHERE J.KOJIN_NO = I.KOJIN_NO
                        AND J.SEINENGAPI BETWEEN NSEINENGAPI_KAISHI AND NSEINENGAPI_SHURYO
                        AND I.SHORIBI_KEY BETWEEN N_CHUSHUTSU_KAISHI AND N_CHUSHUTSU_SHURYO)
         OR EXISTS (SELECT G.KOJIN_NO
                      FROM GKBTGAKUREIBO G,GABVATENAALL H2
                     WHERE G.KOJIN_NO = I.KOJIN_NO
                       AND G.KOJIN_NO = H2.KOJIN_NO
                       AND I.SHORIBI_KEY BETWEEN N_CHUSHUTSU_KAISHI AND N_CHUSHUTSU_SHURYO
                       AND G.SAISHIN_KBN = 0 
                       AND G.SAKUJO_FLG = 0))
-- 2024/06/12 ZCZL.wangyunhan Update end 
          ORDER BY I.SHORIBI,I.IDO_JIYU;

    -- 教育に登録された児童が存在する世帯員から異動者を抽出
    -- 異動累計情報取得カーソル
    CURSOR C_IDORK_SETAI( NKAISHI NUMBER,
                    NSHURYO NUMBER,
                    NSEINENGAPI_KAISHI NUMBER,
                    NSEINENGAPI_SHURYO NUMBER) IS
      SELECT AT.SETAI_NO
             , AT.KOJIN_NO
             , AT.IDO_JIYU
             , AT.SHORIBI_KEY
             , AT.SHORI_JIKAN_KEY
             , AT.SHORI_KBN_KEY
             , AT.ZENBU_ICHIBU_KEY
             , AT.SHOKUINKOJIN_NO_KEY
             , 0 AS SHORIBI
             , GK.JIDO_KOJIN_NO     JIDO_KOJIN_NO
             , GK.SHIMEI_KANA       JIDO_SHIMEI_KANA
             , GK.SHIMEI_KANJI      JIDO_SHIMEI_KANJI
             , GK.WAREKI_SEINENGAPI JIDO_WAREKI_SEINENGAPI
             , GK.SEINENGAPI        JIDO_SEINENGAPI
             , GK.ZOKUGARAMEI       JIDO_ZOKUGARA_MEI
             , GK.SEIBETSU          JIDO_SEIBETSU
        FROM GABVATENAALL AT
             ,( 
               SELECT GL.KOJIN_NO JIDO_KOJIN_NO, EA.*
                 FROM GKBTGAKUNENLNK GL ,GABTATENAKIHON EA
                WHERE GL.KOJIN_NO   = EA.KOJIN_NO
                  AND EA.SEINENGAPI BETWEEN NSEINENGAPI_KAISHI AND NSEINENGAPI_SHURYO
                  AND GL.GAKUNEN_CD BETWEEN 0 AND 9
             ) GK
        WHERE 
              AT.SHORIBI_KEY  BETWEEN NKAISHI AND NSHURYO
-- 2025/05/08 CTC.GL UPDATE Start 1.0.003.000:GKB_QA13680対応
          --AND AT.IDO_JIYU BETWEEN 11 AND 54
          --AND AT.IDO_JIYU NOT IN (51,52)
          AND AT.IDO_JIYU IN (VIDO_JIYU)
-- 2025/05/08 CTC.GL UPDATE End
          AND AT.SETAI_NO = GK.SETAI_NO
          AND AT.JINKAKU_KBN   IN ( CASE WHEN NJINKAKU_KBN = 0 THEN NJINKAKU_KBN
                                         WHEN NJINKAKU_KBN = 1 THEN NJINKAKU_KBN
                                    ELSE AT.JINKAKU_KBN END )
      ORDER BY SHORIBI_KEY, IDO_JIYU, SETAI_NO, JIDO_KOJIN_NO, KOJIN_NO;

    -- 住記情報取得カーソル
    CURSOR C_ATENAALL( i_KOJIN_NO NUMBER,
                       i_SHORIBI_KEY NUMBER,
                       i_SHORI_JIKAN_KEY NUMBER,
                       i_SHORI_KBN_KEY NUMBER,
                       i_ZENBU_ICHIBU_KEY NUMBER,
                       i_SHOKUINKOJIN_NO_KEY CHAR ) IS
      SELECT *
        FROM GABVATENAALL
       WHERE KOJIN_NO            =i_KOJIN_NO
         AND SHORIBI_KEY         =i_SHORIBI_KEY
         AND SHORI_JIKAN_KEY     =i_SHORI_JIKAN_KEY
         AND SHORI_KBN_KEY       =i_SHORI_KBN_KEY
         AND ZENBU_ICHIBU_KEY    =i_ZENBU_ICHIBU_KEY
         AND SHOKUINKOJIN_NO_KEY =i_SHOKUINKOJIN_NO_KEY
         AND JINKAKU_KBN         IN ( CASE WHEN NJINKAKU_KBN = 0 THEN NJINKAKU_KBN
                                           WHEN NJINKAKU_KBN = 1 THEN NJINKAKU_KBN
                                           ELSE JINKAKU_KBN END );
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
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応 
        g_nDAY := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));--システム日付
-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応 
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
        v_cmbShukeiKbn           DBMS_UTILITY.MAXNAME_ARRAY;
        v_cmbJinkakuKbn          DBMS_UTILITY.MAXNAME_ARRAY;
-- 2024/06/12 ZCZL.wangyunhan Delete 0.3.000.000:新WizLIFE２次開発
--         v_cmbSetaikoseiinIdosha  DBMS_UTILITY.MAXNAME_ARRAY;
    BEGIN
        -- 処理開始日 期間(開始)
        g_vJYOUKEN1              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShoriKikanStart');
        -- 処理終了日 期間(終了)
        g_vJYOUKEN2              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShoriKikanEnd');
        -- 抽出開始生年月日 期間(開始)
        g_vJYOUKEN3              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSeinenGappiStart');
        -- 抽出終了生年月日 期間(終了)
        g_vJYOUKEN4              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSeinenGappiEnd');
        -- 集計区分
        v_cmbShukeiKbn           := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbShukeiKbn');
        g_vJYOUKEN5              := v_cmbShukeiKbn(1);
        -- 改頁・ソート区分
        g_vJYOUKEN6              := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKaipageSortKbn');
        -- 人格区分
        v_cmbJinkakuKbn          := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbJinkakuKbn');
        g_vJYOUKEN7              := v_cmbJinkakuKbn(1);
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
        -- 世帯構成員の異動者
--         v_cmbSetaikoseiinIdosha  := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbSetaikoseiinIdosha');
--         g_vJYOUKEN8              := v_cmbSetaikoseiinIdosha(1);
-- 2024/06/12 ZCZL.wangyunhan Delete end 
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

    ----------------------------------------------------------------------------------------------------
    --日付チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    BRET BOOLEAN;
    BEGIN
      IRET := 0;
      --日付
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
    END FUNCHIZUKECHK;
    ----------------------------------------------------------------------------------------------------
    --人格区分チェック
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCZINKAKUKUBUNCHK( i_IZINKAKUKUBUN IN NVARCHAR2 ) RETURN NUMBER IS
    IRET PLS_INTEGER;
    IZINKAKUKUBUN PLS_INTEGER;
    BEGIN
      IRET := 0;

      BEGIN

       IZINKAKUKUBUN := TO_NUMBER(NVL(i_IZINKAKUKUBUN,0));
           IF NOT IZINKAKUKUBUN IN (0,1,2) THEN
              IRET := 1;
           END IF;

     EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      RETURN(IRET);
    END FUNCZINKAKUKUBUNCHK;
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
-- 2024/06/12 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
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
        VMSG := '';
        VERRTMPMSG := '';
        IRTN := 0;
        --条件１のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN1 );
        IF IRTN <> 0 THEN
          --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
          --VERRTMPMSG := g_sGYOUMUCODE || ',99999,処理開始日が正しくありません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,処理開始日 期間(開始)が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
       --条件１の入力条件の日付等の妥当性チェック
       nMSG := KKBPK5551.FJOKENDATECHK('GKB',g_sSHORIID,0,1,1,g_vJYOUKEN1 );
       IF nMSG IS NOT NULL THEN
          VMSG := VMSG || g_sGYOUMUCODE || nMSG;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end 
        --条件２のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN2 );
        IF IRTN <> 0 THEN
          --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
          --VERRTMPMSG := g_sGYOUMUCODE || ',99999,処理終了日が正しくありません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,処理終了日 期間(終了)が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
       --条件2の入力条件の日付等の妥当性チェック
       nMSG := KKBPK5551.FJOKENDATECHK('GKB',g_sSHORIID,0,2,1,g_vJYOUKEN2 );
       IF nMSG IS NOT NULL THEN
          VMSG := VMSG || g_sGYOUMUCODE || nMSG;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end 
        --日付の大小チェック
        IF VMSG IS NULL AND g_vJYOUKEN1 > g_vJYOUKEN2 THEN
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--           VERRTMPMSG := g_sGYOUMUCODE || ',99999,処理開始日と処理終了日の大小関係が誤っています。,;';
          --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
          --VERRTMPMSG := g_sGYOUMUCODE || ',99999,開始年月日、終了日の関係が正しくありません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,処理開始日 期間(開始)、処理終了日 期間(終了)の関係が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF;

        --条件３のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN3 );
        IF IRTN <> 0 THEN
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,開始生年月日が正しくありません。,;';
          --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
          --VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出開始生年月日が正しくありません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出開始生年月日 期間(開始)が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
       --条件3の入力条件の日付等の妥当性チェック
        nMSG := KKBPK5551.FJOKENDATECHK('GKB',g_sSHORIID,0,3,1,g_vJYOUKEN3 );
       IF nMSG IS NOT NULL THEN
--  2024/09/04 ZCZL.LIUCHANGQUAN DEL 0.3.000.001:8月1日認識合わせの横展開
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,開始生年月日が正しくありません。,;';
          VMSG := VMSG || g_sGYOUMUCODE || nMSG;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end 
        --条件４のチェック
        IRTN := FUNCHIZUKECHK( g_vJYOUKEN4 );
        IF IRTN <> 0 THEN
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--          VERRTMPMSG := g_sGYOUMUCODE || ',99999,終了生年月日が正しくありません。,;';
          --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
          --VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出終了生年月日が正しくありません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出終了生年月日 期間(終了)が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
       --条件4の入力条件の日付等の妥当性チェック
       nMSG := KKBPK5551.FJOKENDATECHK('GKB',g_sSHORIID,0,4,1,g_vJYOUKEN4 );
       IF nMSG IS NOT NULL THEN
          VMSG := VMSG || g_sGYOUMUCODE || nMSG;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end
        --日付の大小チェック
        IF VMSG IS NULL AND g_vJYOUKEN3 > g_vJYOUKEN4 THEN
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--           VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出開始生年月日と抽出終了生年月日の大小関係が誤っています。,;';
          --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
          --VERRTMPMSG := g_sGYOUMUCODE || ',99999,開始年月日、終了日の関係が正しくありません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出開始生年月日 期間(開始)、抽出終了生年月日 期間(終了)の関係が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF;

        --条件５のチェック
        IRTN := NVL( g_vJYOUKEN5, 0 );
        IF IRTN < 0 OR IRTN > 3 THEN
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発   
--           VERRTMPMSG := g_sGYOUMUCODE || ',99999,集計区分が正しくありません。,;';
          --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
          --VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出区分選択が正しくありません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出区分(集計区分)選択が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF;

-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        --条件6のチェック
        IRTN := NVL( g_vJYOUKEN6, 0 );
        IF IRTN < 0 OR IRTN > 1 THEN
          --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
          --VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出区分選択が正しくありません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出区分(改頁・ソート区分)選択が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end 

        --条件７のチェック
        IRTN := FUNCZINKAKUKUBUNCHK( g_vJYOUKEN7 );
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.001:8月1日認識合わせの横展開
--        IF IRTN > 2 THEN
        IF IRTN <> 0 THEN
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--           VERRTMPMSG := g_sGYOUMUCODE || ',99999,人格区分が正しくありません。,;';
          --  2024/10/18 ZCZL.ZHANGLEI UPDATE 0.3.000.002:IT_GKB_00079仕様変更対応
          --VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出区分選択が正しくありません。,;';
          VERRTMPMSG := g_sGYOUMUCODE || ',99999,抽出区分(人格区分)選択が正しくありません。,;';
          VMSG := VMSG || VERRTMPMSG;
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
        --条件８のチェック
--         IRTN := NVL( g_vJYOUKEN8, 0 );
--         IF IRTN < 0 OR IRTN > 1 THEN
--           VERRTMPMSG := g_sGYOUMUCODE || ',99999,世帯構成員の異動者区分が正しくありません。,;';
--           VMSG := VMSG || VERRTMPMSG;
--         END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete end 
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
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------------------------------
    --  機能概要      : ファイル作成処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.wangyunhan 2024/06/14
    --------------------------------------------------------------------------------
    FUNCTION FUNC_CSV_CREATE RETURN NUMBER IS
        VSQL               NVARCHAR2(3000);  
        --CSV出力用
        TYPE               ref_CUR_DOUTAI IS REF CURSOR;    --カーソル定義
        C1                 ref_CUR_DOUTAI;                  --動態カーソル
        CR1                GKBWIDOICHIRAN%ROWTYPE;          --C1カーソルのレコード
        TEXTDATA           NVARCHAR2(3000);                 -- テキストデータ 
        nOUTCSVCNT         NUMBER;                          --CSV出力件数
        nGYOMU_CD          NVARCHAR2(3);                   --業務コード
        nGROUP_CD          NVARCHAR2(10);                   --グループコード
        nSHORIMEI          NVARCHAR2(100);                   --処理名
        IRTN               BOOLEAN;
        BRTN               NUMBER;
        iRIREKI            NUMBER;
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD 0.3.000.001:8月1日認識合わせの横展開
        nROWNUM                       NUMBER := 0;
    BEGIN
       --関数開始
       IRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ファイル作成処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
       --SQL文
       VSQL := 'SELECT * FROM GKBWIDOICHIRAN ';--WHERE WSNUM = '|| g_sWSNUM ||' AND BATCHKBN　=　2';
       --ソート条件があれば付加
       --VSQL := VSQL || ' ORDER BY ' || g_rJSTP.ORDERBYCLAUSE;
       iRIREKI := 0;
       BRTN := KKAPK0090.FDLWorkOpen('GKBWDB002001',iRIREKI,1,'住記異動者一覧CSVワーク','JYUKIIDOICHIRAN.csv','',g_sTANTOCODE,g_sWSNUM,'');
--  2024/10/30 ZCZL.WANGYUNING ADD 0.3.000.003:IT_GKB_00213仕様変更対応
       TEXTDATA := '';
       TEXTDATA := '児童生徒氏名';
       TEXTDATA := TEXTDATA ||','|| '児童生徒カナ氏名';
       TEXTDATA := TEXTDATA ||','|| '児童生徒の生年月日';
       TEXTDATA := TEXTDATA ||','|| '児童生徒性別';
       TEXTDATA := TEXTDATA ||','|| '児童生徒国籍';
       TEXTDATA := TEXTDATA ||','|| '学校名';
       TEXTDATA := TEXTDATA ||','|| '学年';
       TEXTDATA := TEXTDATA ||','|| '保護者氏名';
       TEXTDATA := TEXTDATA ||','|| '保護者カナ氏名';
       TEXTDATA := TEXTDATA ||','|| '児童生徒との関係';
       TEXTDATA := TEXTDATA ||','|| '保護者国籍';
       TEXTDATA := TEXTDATA ||','|| '児童生徒続柄';
       TEXTDATA := TEXTDATA ||','|| '児童生徒異動事由';
       TEXTDATA := TEXTDATA ||','|| '異動年月日';
       TEXTDATA := TEXTDATA ||','|| '届出年月日';
       TEXTDATA := TEXTDATA ||','|| '児童生徒住所';
       TEXTDATA := TEXTDATA ||','|| '指定小学校区';
       TEXTDATA := TEXTDATA ||','|| '指定中学校区';
       TEXTDATA := TEXTDATA ||','|| '世帯主氏名';
       
       --ワークテーブルテキスト出力
       BRTN := KKAPK0090.FDLWorkPutNC(TEXTDATA,'UTF8',1);
       IF BRTN = 1 THEN  
           RETURN c_ERR;
       END IF;
--  2024/10/30 ZCZL.WANGYUNING ADD END     
      --CSVファイル作成処理
       OPEN C1 FOR VSQL;
       LOOP
         FETCH C1 INTO CR1;
         EXIT WHEN C1%NOTFOUND;
         TEXTDATA := '';
         TEXTDATA := TEXTDATA || CR1.IDOSHA_SHIMEI_KANJI;          --児童生徒氏名
         TEXTDATA := TEXTDATA ||','|| CR1.IDOSHA_SHIMEI_KANA;      --異動者氏名かな
         TEXTDATA := TEXTDATA ||','|| CR1.SEINENGAPI;              --児童生徒の生年月日
         TEXTDATA := TEXTDATA ||','|| CR1.SEIBETSU;                --児童生徒性別
         TEXTDATA := TEXTDATA ||','|| CR1.JIDO_KOKUSEKI;           --児童生徒国籍
         TEXTDATA := TEXTDATA ||','|| CR1.GAKKO_MEI;               --学校名
         TEXTDATA := TEXTDATA ||','|| CR1.GAKU_NEN;                --学年
         TEXTDATA := TEXTDATA ||','|| CR1.HOGOSHA_SHIMEI_KANJI;    --保護者氏名
         TEXTDATA := TEXTDATA ||','|| CR1.HOGOSHA_SHIMEI_KANA;     --保護者カナ氏名 
         TEXTDATA := TEXTDATA ||','|| CR1.JIDO_ZOKUGARAMEI;        --保護者国籍 
         TEXTDATA := TEXTDATA ||','|| CR1.HOGOSHA_KOKUSEKI;        --児童生徒との関係
         TEXTDATA := TEXTDATA ||','|| CR1.ZOKUGARA;                --児童生徒続柄 
         TEXTDATA := TEXTDATA ||','|| CR1.IDO_JIYU_MEI;            --児童生徒異動事由
         TEXTDATA := TEXTDATA ||','|| CR1.IDO_BI;                  --異動年月日
         TEXTDATA := TEXTDATA ||','|| CR1.TODOKEDEBI;              --届出年月日
         TEXTDATA := TEXTDATA ||','|| CR1.JIDO_JUSHO;              --児童生徒住所
         TEXTDATA := TEXTDATA ||','|| CR1.SHITEI_SHOGAKKOKU;       --指定小学校区
         TEXTDATA := TEXTDATA ||','|| CR1.SHITEI_TYUGAKOKU;        --指定中学校区
         TEXTDATA := TEXTDATA ||','|| CR1.NUSHI_SHIMEI_KANJI;      --世帯主氏名
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD START 0.3.000.001:8月1日認識合わせの横展開
         --ワークテーブルテキスト出力
         BRTN := KKAPK0090.FDLWorkPutNC(TEXTDATA,'UTF8',1);
         IF BRTN = 1 THEN  
             RETURN c_ERR;
          END IF;
         --CSV出力件数 のカウントアップを行う。
         nROWNUM := nROWNUM + 1;
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD END
         END LOOP;
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD START 0.3.000.001:8月1日認識合わせの横展開
         IF C1%ISOPEN THEN
           CLOSE C1;
         END IF;
         --ワークテーブルテキスト出力
--         BRTN := KKAPK0090.FDLWorkPutNC(TEXTDATA,'UTF8',1);
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD END
         --CSV出力件数 のカウントアップを行う。
--         VSQL := 'SELECT COUNT(1) FROM GKBWIDOICHIRAN  ';--WHERE ';
--          VSQL := VSQL || ' WSNUM = ' || '''' || g_sWSNUM || '''';
--          VSQL := VSQL || ' AND BATCHKBN = 2';
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.001:8月1日認識合わせの横展開
        -- グローバル変数.CSV出力件数
        g_nCSVNUM := nROWNUM;
--         EXECUTE IMMEDIATE VSQL INTO g_oKENSU_LIST(1).CNT;
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_nCSVNUM,'出力　'||'住記異動者一覧ＣＳＶ',2);
         --0件の場合、CSVを出力しない
--        IF nOUTCSVCNT = 0 THEN
--            IRTN := FUNC_SETLOG(g_rJSTP.CHOHYONAME || 'ファイル作成処理', 0, '', '', 'GKBWIDOICHIRAN' || 'テーブル、' ||  'の件数が0件ので、CSVを出力しません。終了', g_sTANTOCODE, g_sWSNUM, 1);
--            RETURN c_ERR;
--        END IF;
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE END
        --ファイルをクローズする。
        BRTN := KKAPK0090.FDLWorkClose();
        --ダウンロード設定用情報の取得を行う。
        IRTN := KKBPK5551.FKKBVJCTLGET(g_nJOBNUM,nGYOMU_CD,nGROUP_CD,nSHORIMEI);
        IF IRTN THEN 
           BRTN := KKAPK0090.FDLCtlPut(nGYOMU_CD,nGROUP_CD,nSHORIMEI,g_nJOBNUM);
        END IF;
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.001:8月1日認識合わせの横展開
        --対象者件数のカウントアップを行う。
--        EXECUTE IMMEDIATE VSQL INTO g_rJSTP.SHORIRECCNT;
         --関数終了
--        IRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ファイル作成処理', 0, '', '', '終了', g_sTANTOCODE, g_sWSNUM, 1);
        IRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_CSV_CREATE', 0, '', '', '住記異動者一覧ＣＳＶ' || nROWNUM || '件を出力しました。', g_sTANTOCODE, g_sWSNUM, 1);
--  2024/09/04 ZCZL.LIUCHANGQUAN UPDATE END
        -- 終了
        RETURN c_OK;
    EXCEPTION
        WHEN OTHERS THEN
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD START 0.3.000.001:8月1日認識合わせの横展開
--            IRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'ファイル作成処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
            IRTN:= FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_CSV_CREATE', 1, SQLCODE, SQLERRM, 'ＣＳＶファイルの書き出し処理が異常終了しました。', g_sTANTOCODE, g_sWSNUM, 1);
            IF C1%ISOPEN THEN
              CLOSE C1;
            END IF;
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD END
        RETURN c_ERR;
    END FUNC_CSV_CREATE;
-- 2024/06/12 ZCZL.wangyunhan Add end 
    
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
              DBMS_OUTPUT.PUT_LINE(SQLERRM);
              RAISE eEXCEPTION;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END PROC_KENSUSET;


    ----------------------------------------------
    --平成XX年XX月XX日に変換
    ----------------------------------------------
    FUNCTION HIZUKE( n_DAY IN NUMBER , TYPE IN NUMBER ) RETURN NVARCHAR2 IS
      VDAY          NVARCHAR2(16) := '';      --戻り値
      NDAY          NUMBER(8);                --変換前日付
      --日付変換サブルーチン用変数
      IOUT1         PLS_INTEGER := null;
      IOUT2         PLS_INTEGER := null;
      NOUT2         NVARCHAR2(16);
      NOUT3         NVARCHAR2(16);
      NOUT4         NVARCHAR2(16);
      NOUT5         NVARCHAR2(16);
      NOUT6         NVARCHAR2(16);
      IOUT7         PLS_INTEGER;
      IOUT8         PLS_INTEGER;
      IOUT9         PLS_INTEGER;
      IOUT10        PLS_INTEGER;
      IOUT11        PLS_INTEGER;
      IOUT12        PLS_INTEGER;
      IOUT13        PLS_INTEGER;
    BEGIN
      NDAY := n_DAY;
      IF NDAY > 0 THEN
        IF NDAY > 10000000 THEN
          IOUT2 := NDAY;
        ELSE
          IOUT1 := NDAY;
        END IF;
        --日付編集サブルーチン呼び出し
        B_RTN := KKAPK0020.FDAYEDIT( IOUT1, IOUT2, NOUT2, NOUT3, NOUT4, NOUT5, NOUT6, IOUT7, IOUT8,
                                      IOUT9, IOUT10, IOUT11, IOUT12, IOUT13);
        --ログ出力
        IF B_RTN THEN
          IF TYPE = 1 THEN
            VDAY  := NOUT2;
          ELSIF TYPE = 2 THEN
            VDAY  := NOUT3;
          ELSIF TYPE = 3 THEN
            VDAY  := NOUT4;
          ELSIF TYPE = 4 THEN
            VDAY  := IOUT13;
          ELSIF TYPE = 5 THEN
            VDAY  := IOUT12;
          END IF;
        ELSE
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'HIZUKE', 1, '', '', SUBSTR(VERRMSG || ':FDAYEDIT', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          VDAY  := '';
        END IF;
      END IF;
      RETURN (VDAY);
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END HIZUKE;
    ----------------------------------------------
    --住所連番から住所情報を取得
    ----------------------------------------------
    FUNCTION GETADDR( n_REN IN NUMBER, n_KNO IN NUMBER,
              v_CHOMEI OUT NVARCHAR2, v_BANCHI OUT NVARCHAR2,
              v_KATAGAKI OUT NVARCHAR2, n_JICHI OUT NUMBER,
              v_YUBIN OUT NVARCHAR2, v_YUBIN_BC OUT NVARCHAR2 ) RETURN BOOLEAN IS
      BEGIN
        SELECT CHOMEI,
             BANCHI,
             KATAGAKI,
             USER_CD,
             YUBIN_NO,
             YUBIN_NOBC
          INTO v_CHOMEI,
             v_BANCHI,
             v_KATAGAKI,
             n_JICHI,
             v_YUBIN,
             v_YUBIN_BC
         FROM GABTJUKIJUSHO
         WHERE JUSHO_REN = n_REN
           AND KOJIN_NO = n_KNO;
        B_RTN := TRUE;
        RETURN (B_RTN);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_CHOMEI    := '';
          v_BANCHI    := '';
          v_KATAGAKI  := '';
          n_JICHI     := '';
          v_YUBIN     := '';
          v_YUBIN_BC  := '';
          B_RTN := TRUE;
          RETURN (B_RTN);
        WHEN OTHERS THEN
          DBMS_OUTPUT.PUT_LINE('KOJIN_NO:' || n_KNO);
          DBMS_OUTPUT.PUT_LINE('JUSHO_REN:' || n_REN);
          B_RTN := FALSE;
          RETURN (B_RTN);
    END GETADDR;
    ----------------------------------------------
    --異動事由コードから事由名を取得
    ----------------------------------------------
    FUNCTION GETJIYU( n_JIYUCD IN NUMBER,
              v_JIYU OUT NVARCHAR2 ) RETURN BOOLEAN IS
      BEGIN
-- 2025/02/08 JPJYS.GONGYANYAN Update 0.3.000.007:資産比較対応 START
        --IF n_JIYUCD > 0 AND n_JIYUCD <62 THEN
        IF n_JIYUCD > 0 AND n_JIYUCD <620 THEN
-- 2025/02/08 JPJYS.GONGYANYAN Update 0.3.000.007:資産比較対応 END
          SELECT IDO_JIYU_MEI
            INTO v_JIYU
            FROM GABTIDOJIYU
           WHERE IDO_JIYU_CD = n_JIYUCD;
        END IF;
        B_RTN := TRUE;
        RETURN (B_RTN);
      EXCEPTION
        WHEN OTHERS THEN
          B_RTN := FALSE;
          RETURN (B_RTN);
    END GETJIYU;
    ----------------------------------------------
    --大字以降を取得
    ----------------------------------------------
    FUNCTION CHOMEIEDIT( v_KADO IN NVARCHAR2, v_CHOMEI IN NVARCHAR2 ) RETURN NVARCHAR2 IS
      vKADO     NVARCHAR2(40) := v_KADO;      --稼働市町村名
      vEDCHOMEI NVARCHAR2(40) := v_CHOMEI;    --町名（大字混み）
      BEGIN
        VEDCHOMEI := GAAPK0010.FADDRESSEDIT( 2,
                            vEDCHOMEI,
                            '', '', '',
                            vKADO );
        RETURN (VEDCHOMEI);
    END CHOMEIEDIT;
    --------------------------------------------------------------------------------
    -- 処理条件をセット 
    --------------------------------------------------------------------------------
    FUNCTION FUNCSET_JOKEN RETURN PLS_INTEGER IS
      w_IRTN           PLS_INTEGER; -- リターンコード

    BEGIN

      w_IRTN := c_IRETOK;
      -- 条件１　条件抽出開始日
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--       R_WKB.JKN_CHUSHUTSU_KAISHI  := TO_NUMBER(HIZUKE(g_vJYOUKEN1,4));
      R_WKB.JKN_CHUSHUTSU_KAISHI  := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN1);
      N_CHUSHUTSU_KAISHI          := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN1);
-- 2024/06/12 ZCZL.wangyunhan Update end 
      -- 条件２　終了日
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発 
--       R_WKB.JKN_CHUSHUTSU_SHURYO  := TO_NUMBER(HIZUKE(g_vJYOUKEN2,4));
      R_WKB.JKN_CHUSHUTSU_SHURYO  := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN2);
      N_CHUSHUTSU_SHURYO          := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN2);
-- 2024/06/12 ZCZL.wangyunhan Update end   
      -- 条件３　条件抽出生年月日開始日
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発 
--       NSEINENGAPI_KAISHI          := TO_NUMBER(HIZUKE(g_vJYOUKEN3,4));
--       R_WKB.JKN_SEINENGAPI_KAISHI := TO_NUMBER(HIZUKE(g_vJYOUKEN3,4));
      NSEINENGAPI_KAISHI          := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN3);
      R_WKB.JKN_SEINENGAPI_KAISHI := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN3);
-- 2024/06/12 ZCZL.wangyunhan Update end 
      -- 条件４　条件抽出生年月日終了日
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発 
--       NSEINENGAPI_SHURYO          := TO_NUMBER(HIZUKE(g_vJYOUKEN4,4));
--       R_WKB.JKN_SEINENGAPI_SHURYO := TO_NUMBER(HIZUKE(g_vJYOUKEN4,4));
      NSEINENGAPI_SHURYO          := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN4);
      R_WKB.JKN_SEINENGAPI_SHURYO := KKAPK0020.FNENDOHENKAN(g_vJYOUKEN4);
-- 2024/06/12 ZCZL.wangyunhan Update end 
      -- 条件５　集計区分
      NSHUKEI_KBN                 := TO_NUMBER( g_vJYOUKEN5 );
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
      IF NSHUKEI_KBN NOT IN (0,1,2,3) THEN 
        RETURN c_IERR;
      END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end 
      -- 条件６　改頁・ソート区分
      NSORT_KBN                   := TO_NUMBER( g_vJYOUKEN6 );
      IF NSORT_KBN IS NULL THEN
        NSORT_KBN := 0;
      END IF;

      -- 条件７　人格区分（0：日本人、1：外国人、2：全て）
      NJINKAKU_KBN                := TO_NUMBER( g_vJYOUKEN7 );
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
      IF NJINKAKU_KBN NOT IN (0,1,2) THEN 
        RETURN c_IERR;
      END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end 
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
      -- 条件８　世帯構成員の異動者（0：対象外、1：対象）
--       NSETAI_IDOKBN               := TO_NUMBER( NVL(g_vJYOUKEN8,0) );
--       IF NSETAI_IDOKBN = 1 THEN
--         NSORT_KBN := 4;
--       END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete end 
      RETURN w_IRTN;
    EXCEPTION
      WHEN OTHERS THEN
        w_IRTN := c_IERR;
        RETURN w_IRTN;

    END FUNCSET_JOKEN;
    ----------------------------------------------------------------------
    -- ワーク変数を初期化する
    ----------------------------------------------------------------------
    PROCEDURE PROCWK_CLEAR (R_WKB IN OUT GKBWIDOICHIRAN%ROWTYPE
                           )   IS
    BEGIN

        R_WKB.SHUKEI_KBN                  := '';
        R_WKB.JKN_KIJUN_BI                := '';
        R_WKB.JKN_SAKUSEI_BI              := '';
-- 2025/02/6 JPJYS.WUZHENGDONG Update 0.3.000.005:ST_GKB_TMP00045 対応 Start
--        R_WKB.TODOFUKEN_MEI               := '';
-- 2025/02/6 JPJYS.WUZHENGDONG Update 0.3.000.005:ST_GKB_TMP00045 対応 End
        R_WKB.ZENPAGE                     := 0;
        R_WKB.PAGE                        := 0;
        R_WKB.KOJIN_NO                    := NULL;
        R_WKB.SETAI_NO                    := NULL;
        R_WKB.GENZON_KBN                  := NULL;
        R_WKB.JUN_SETAI_KBN               := NULL;
        R_WKB.JINKAKU_KBN                 := 0;
        R_WKB.SHISHO_MEI                  := '';
        R_WKB.SHISHO_CD                   := NULL;
        R_WKB.CHIKUMEI                    := '';
        R_WKB.CHIKU_CD                    := NULL;
        R_WKB.GYOSEIKU_MEI                := '';
        R_WKB.GYOSEIKU_CD                 := NULL;
        R_WKB.HAN_MEI                     := '';
        R_WKB.HAN_CD                      := NULL;
        R_WKB.SHOGAKU_MEI                 := '';
        R_WKB.SHOGAKU_CD                  := NULL;
        R_WKB.CHUGAKU_MEI                 := '';
        R_WKB.CHUGAKU_CD                  := NULL;
        R_WKB.TOHYOKU_MEI                 := '';
        R_WKB.TOHYOKU_CD                  := NULL;
        R_WKB.KYUJICHI_MEI                := '';
        R_WKB.SANTEIDANTAI_CD             := NULL;
        R_WKB.SEINENGAPI                  := NULL;
        R_WKB.WAREKI_SEINENGAPI           := NULL;
        R_WKB.HYOJI_SEINENGAPI            := '';
        R_WKB.NENREI                      := NULL;
        R_WKB.SEIBETSU                    := NULL;
        R_WKB.USERMEI                     := '';
        R_WKB.JICHI_CD                    := NULL;
        R_WKB.OAZA_MEI                    := '';
        R_WKB.OAZA_CD                     := NULL;
        R_WKB.HONBAN                      := '';
        R_WKB.EDABAN1                     := '';
        R_WKB.EDABAN2                     := '';
        R_WKB.EDABAN3                     := '';
        R_WKB.GAIKU                       := '';
        R_WKB.TOU                         := '';
        R_WKB.GOU                         := '';
        R_WKB.SHIMEI_KANA                 := '';
        R_WKB.SHIMEI_KANJI                := '';
        R_WKB.YUBIN_NO                    := '';
        R_WKB.YUBIN_NOBC                  := '';
        R_WKB.CHOMEI                      := '';
        R_WKB.BANCHI                      := '';
        R_WKB.KATAGAKI                    := '';
        R_WKB.TEL_NO                      := '';
        R_WKB.TEL_KBN                     := NULL;
        R_WKB.FAX                         := '';
        R_WKB.MAIL_ADS                    := '';
        R_WKB.JUMINHYO_CD                 := NULL;
        R_WKB.ZOKUGARA_MEI                := '';
        R_WKB.JITSU_ZOKUGARA_MEI          := '';
        R_WKB.KISAI_JUNI                  := NULL;
        R_WKB.IDO_BI                      := '';
        R_WKB.IDO_JIYU_MEI                := '';
        R_WKB.IDO_JIYU                    := NULL;
        R_WKB.IDO_TODOKE_BI               := '';
        R_WKB.JUTEI_BI                    := '';
        R_WKB.JUTEI_JIYU_MEI              := '';
        R_WKB.JUTEI_JIYU                  := NULL;
        R_WKB.JUTEI_TODOKEDE_BI           := '';
        R_WKB.ZEN_CHOMEI                  := '';
        R_WKB.ZEN_BANCHI                  := '';
        R_WKB.ZEN_KATAGAKI                := '';
        R_WKB.ZEN_JICHI_CD                := '';
        R_WKB.ZEN_YUBIN_NO                := '';
        R_WKB.TENNYU_CHOMEI               := '';
        R_WKB.TENNYU_BANCHI               := '';
        R_WKB.TENNYU_KATAGAKI             := '';
        R_WKB.TENNYU_JICHI_CD             := NULL;
        R_WKB.TENNYU_YUBIN_NO             := '';
        R_WKB.HONSEKI_CHOMEI              := '';
        R_WKB.HONSEKI_BANCHI              := '';
        R_WKB.HONSEKI_KATAGAKI            := '';
        R_WKB.HONSEKI_JICHI_CD            := NULL;
        R_WKB.HONSEKI_YUBIN_NO            := '';
        R_WKB.TENSHUTSU_YOTEI_BI          := '';
        R_WKB.TENSHUTSU_YOTEI_TODOKEDE_BI := '';
        R_WKB.TENSHUTSU_CHOMEI            := '';
        R_WKB.TENSHUTSU_BANCHI            := '';
        R_WKB.TENSHUTSU_KATAGAKI          := '';
        R_WKB.TENSHUTSU_JICHI_CD          := NULL;
        R_WKB.TENSHUTSU_YUBIN_NO          := '';
        R_WKB.TENSHUTSU_KAKUTEI_BI        := '';
        R_WKB.KAKUTEI_TSUCHI_BI           := '';
        R_WKB.TENKAKU_CHOMEI              := '';
        R_WKB.TENKAKU_BANCHI              := '';
        R_WKB.TENKAKU_KATAGAKI            := '';
        R_WKB.TENKAKU_JICHI_CD            := NULL;
        R_WKB.TENKAKU_YUBIN_NO            := '';
        R_WKB.JUMIN_NARU                  := '';
        R_WKB.JUMIN_NARU_JIYUMEI          := '';
        R_WKB.JUMIN_NARU_JIYU             := NULL;
        R_WKB.JUMIN_NARU_TODOKEDE_BI      := '';
        R_WKB.JUMIN_NAKUNARU              := '';
        R_WKB.JUMIN_NAKU_JIYUMEI          := '';
        R_WKB.JUMIN_NAKUNARU_JIYU         := NULL;
        R_WKB.JUMIN_NAKUNARU_TODOKEDE_BI  := '';
        R_WKB.HONMYO_KANA                 := '';
        R_WKB.HONMYO_KANJI                := '';
        R_WKB.NUSHI_SHIMEI_KANA           := '';
        R_WKB.NUSHI_SHIMEI_KANJI          := '';
        R_WKB.BIKO_1                      := '';
        R_WKB.BIKO_2                      := NULL;
        R_WKB.BIKO_3                      := NULL;
        R_WKB.KAISEI_BI                   := '';
        R_WKB.KAISEI_REN                  := NULL;
        R_WKB.SHORIBI_KEY                 := NULL;
        R_WKB.SHORI_JIKAN_KEY             := NULL;
        R_WKB.SHORI_KBN_KEY               := NULL;
        R_WKB.ZENBU_ICHIBU_KEY            := NULL;
        R_WKB.ZENBU_ICHIBU_KBN            := '';
        R_WKB.SHOKUINKOJIN_NO_KEY         := NULL;
        R_WKB.KOKUHO_SHIKAKU              := '';
        R_WKB.NENKIN_SHIKAKU              := '';
        R_WKB.NENKIN_NO                   := '';
        R_WKB.JIDO_TEATE_SHIKAKU          := '';
        R_WKB.KAIGO_SHIKAKU               := '';
        R_WKB.INKAN_SHIKAKU               := '';
        R_WKB.HAIKAN_KBN                  := NULL;
        R_WKB.INKAN_NO                    := '';
        R_WKB.HOGOSHA                     := '';
        R_WKB.EQGAKKOKU_CD                := NULL;
        R_WKB.EQGAKKOKU_MEI               := '';
        R_WKB.EAGAKKOKU_CD                := NULL;
        R_WKB.EAGAKKOKU_MEI               := '';
        R_WKB.KOSHINSHOKUIN_MEI           := '';
-- 2025/02/6 JPJYS.WUZHENGDONG Update 0.3.000.005:ST_GKB_TMP00045 対応 Start
--        R_WKB.SHICHOSON_CHOMEI            := '';
--        R_WKB.SHICHOSON_NINSHOBUN         := '';
--        R_WKB.SHICHOSON_YUBINNO           := '';
--        R_WKB.SHICHOSON_SHOZAICHI         := '';
--        R_WKB.SHICHOSON_TEL               := '';
-- 2025/02/6 JPJYS.WUZHENGDONG Update 0.3.000.005:ST_GKB_TMP00045 対応 End
        R_WKB.GAKKO_KBN                   := NULL;
        R_WKB.SYS_SAKUSEIBI               := NULL;
        R_WKB.SYS_KOSHINBI                := NULL;
        R_WKB.SYS_JIKAN                   := NULL;
        R_WKB.SYS_TANMATSU_NO             := g_sWSNUM;
        R_WKB.JIDO_KOJIN_NO               := NULL;    --児童宛名番号
        R_WKB.SETAI_SEIBETSU              := NULL;    --世帯員性別用
    END PROCWK_CLEAR;
    --------------------------------------------------------------------------------
    --宛名情報をワーク変数へセット
    --------------------------------------------------------------------------------
    FUNCTION FUNCSET_EAV_ATENA (R_WKB IN OUT GKBWIDOICHIRAN%ROWTYPE,
                                R_ATENA  IN  GABVATENAALL%ROWTYPE,
                                i_FLG    IN  INTEGER
                           )  RETURN PLS_INTEGER IS
      w_IRTN           PLS_INTEGER;
    BEGIN
        R_WKB.KOJIN_NO            := R_ATENA.KOJIN_NO;
        R_WKB.SETAI_NO            := R_ATENA.SETAI_NO;
        R_WKB.GENZON_KBN          := R_ATENA.GENZON_KBN;
        R_WKB.JUN_SETAI_KBN       := R_ATENA.JUN_SETAI_KBN;
        R_WKB.JINKAKU_KBN         := R_ATENA.JINKAKU_KBN;
        R_WKB.SHISHO_CD           := R_ATENA.SHISHO_CD;
        R_WKB.CHIKU_CD            := R_ATENA.CHIKU_CD;
        R_WKB.GYOSEIKU_CD         := R_ATENA.GYOSEIKU_CD;
        R_WKB.HAN_CD              := R_ATENA.HAN_CD;
        R_WKB.SHOGAKU_CD          := R_ATENA.SHOGAKU_CD;
        R_WKB.CHUGAKU_CD          := R_ATENA.CHUGAKU_CD;
        R_WKB.TOHYOKU_CD          := R_ATENA.TOHYOKU_CD;
        R_WKB.SANTEIDANTAI_CD     := R_ATENA.SANTEIDANTAI_CD;
        R_WKB.SEINENGAPI          := R_ATENA.SEINENGAPI;
        R_WKB.WAREKI_SEINENGAPI   := R_ATENA.WAREKI_SEINENGAPI;
        R_WKB.HYOJI_SEINENGAPI    := R_ATENA.HYOJI_SEINENGAPI;
        R_WKB.JICHI_CD            := R_ATENA.USER_CD;
        R_WKB.OAZA_CD             := R_ATENA.OAZA_CD;
        R_WKB.HONBAN              := R_ATENA.HONBAN;
        R_WKB.EDABAN1             := R_ATENA.EDABAN1;
        R_WKB.EDABAN2             := R_ATENA.EDABAN2;
        R_WKB.EDABAN3             := R_ATENA.EDABAN3;
        R_WKB.GAIKU               := R_ATENA.GAIKU;
        R_WKB.TOU                 := R_ATENA.TOU;
        R_WKB.GOU                 := R_ATENA.GOU;
        R_WKB.SHIMEI_KANA         := R_ATENA.SHIMEI_KANA;
        R_WKB.SHIMEI_KANJI        := R_ATENA.SHIMEI_KANJI;
        R_WKB.TEL_NO              := R_ATENA.TEL_NO;
        R_WKB.TEL_KBN             := R_ATENA.TEL_KBN;
        R_WKB.FAX                 := R_ATENA.FAX_NO;
        R_WKB.MAIL_ADS            := R_ATENA.MAIL_ADS;
        R_WKB.JUMINHYO_CD         := R_ATENA.JUMINHYO_CD;
        R_WKB.ZOKUGARA_MEI        := R_ATENA.ZOKUGARA_MEI;
        R_WKB.JITSU_ZOKUGARA_MEI  := R_ATENA.JITSU_ZOKUGARA_MEI;
        R_WKB.KISAI_JUNI          := R_ATENA.KISAI_JUNI;
        R_WKB.IDO_BI              := R_ATENA.IDO_BI;
        R_WKB.IDO_JIYU            := R_ATENA.IDO_JIYU;
        R_WKB.IDO_TODOKE_BI       := R_ATENA.IDO_TODOKE_BI;
        R_WKB.JUTEI_BI            := R_ATENA.JUTEI_BI;
        R_WKB.JUTEI_JIYU          := R_ATENA.JUTEI_JIYU;
        R_WKB.JUTEI_TODOKEDE_BI   := R_ATENA.JUTEI_TODOKEDE_BI;
        R_WKB.TENSHUTSU_YOTEI_BI  := R_ATENA.TENSHUTSU_YOTEI_BI;
        R_WKB.TENSHUTSU_YOTEI_TODOKEDE_BI := R_ATENA.TENSHUTSU_YOTEI_TODOKEDE_BI;
        R_WKB.TENSHUTSU_KAKUTEI_BI := R_ATENA.TENSHUTSU_KAKUTEI_BI;
        R_WKB.KAKUTEI_TSUCHI_BI   := R_ATENA.TENSHUTSU_KAKUTEI_TSUCHI_BI;
        R_WKB.JUMIN_NARU          := R_ATENA.JUMIN_NARU;
        R_WKB.JUMIN_NARU_JIYU     := R_ATENA.JUMIN_NARU_JIYU;
        R_WKB.JUMIN_NARU_TODOKEDE_BI := R_ATENA.JUMIN_NARU_TODOKEDE_BI;
        R_WKB.JUMIN_NAKUNARU      := R_ATENA.JUMIN_NAKUNARU;
        R_WKB.JUMIN_NAKUNARU_JIYU := R_ATENA.JUMIN_NAKUNARU_JIYU;
        R_WKB.JUMIN_NAKUNARU_TODOKEDE_BI := R_ATENA.JUMIN_NAKUNARU_TODOKEDE_BI;
        R_WKB.HONMYO_KANA         := R_ATENA.HONMYO_KANA;
        R_WKB.HONMYO_KANJI        := R_ATENA.HONMYO_KANJI;

        IF i_FLG = 0 THEN
          R_WKB.NUSHI_SHIMEI_KANA    := R_ATENA.NUSHI_SHIMEI_KANA;
          R_WKB.NUSHI_SHIMEI_KANJI   := R_ATENA.NUSHI_SHIMEI_KANJI;
          R_WKB.JITSU_ZOKUGARA_MEI   := '';
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--         ELSE
--           世帯員を含める場合、世帯員の氏名かな・漢字をセット
--           R_WKB.NUSHI_SHIMEI_KANA    := R_ATENA.SHIMEI_KANA;
--           R_WKB.NUSHI_SHIMEI_KANJI   := R_ATENA.SHIMEI_KANJI;
--           世帯員の続柄を「実続柄」に再セット
--           R_WKB.JITSU_ZOKUGARA_MEI   := R_ATENA.ZOKUGARA_MEI;
--           性別編集
--           IF R_ATENA.SEIBETSU = 1 THEN
--             R_WKB.SETAI_SEIBETSU := '男';
--           ELSIF R_ATENA.SEIBETSU = 2 THEN
--             R_WKB.SETAI_SEIBETSU := '女';
--           END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete end 
        END IF;
        
        R_WKB.KAISEI_BI  := R_ATENA.KAISEI_BI;
        R_WKB.KAISEI_REN := R_ATENA.KAISEI_REN;

        R_WKB.SHORIBI_KEY         := R_ATENA.SHORIBI_KEY;               --処理日キー
        R_WKB.SHORI_JIKAN_KEY     := R_ATENA.SHORI_JIKAN_KEY;           --処理時間キー
        R_WKB.SHORI_KBN_KEY       := R_ATENA.SHORI_KBN_KEY;             --処理区分キー
        R_WKB.ZENBU_ICHIBU_KEY    := R_ATENA.ZENBU_ICHIBU_KEY;          --全部一部キー
        R_WKB.SHOKUINKOJIN_NO_KEY := R_ATENA.SHOKUINKOJIN_NO_KEY;       --職員宛名番号キー

        NSEIBETSU                 := R_ATENA.SEIBETSU;
        NJUSHO                    := R_ATENA.GENJUSHO_REN;
        NZENJUSHO                 := R_ATENA.ZENJUSHO_REN;
        NTENNYU                   := R_ATENA.TENNYUMAE_REN;
        NHONSEKI                  := R_ATENA.HONSEKI_REN;
        NTENSHUTSU                := R_ATENA.TENSHUTSU_YOTEI_REN;
        NTENKAKU                  := R_ATENA.TENSHUTSU_KAKUTEI_REN;
        VBIKO                     := R_ATENA.BIKO;
      RETURN w_IRTN;
    EXCEPTION
      WHEN OTHERS THEN
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_EAV_ATENA', 1, SQLCODE, SQLERRM, SUBSTR(VERRMSG || ':FUNCSET_EAV_ATENA', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        RETURN c_IERR;
    END FUNCSET_EAV_ATENA;
    --------------------------------------------------------------------------------
    -- 更新用ワーク変数にセット
    --------------------------------------------------------------------------------
    FUNCTION FUNCGET_GAKKO_JOHO ( R_WKB IN OUT GKBWIDOICHIRAN%ROWTYPE,
                                  i_FLG IN INTEGER ) RETURN PLS_INTEGER IS
      w_IRTN           PLS_INTEGER;
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--      n_KOJIN_NO       NUMBER(12);
      n_KOJIN_NO       NUMBER(15);

    BEGIN

      w_IRTN := c_IRETOK;
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--       IF i_FLG <> 0 THEN
--         n_KOJIN_NO := R_WKB.JIDO_KOJIN_NO;
--       ELSE
      IF i_FLG = 0 THEN
        n_KOJIN_NO := R_WKB.KOJIN_NO;
      END IF;
-- 2024/06/12 ZCZL.wangyunhan Update end 
      

      -- 学年情報取得
      BEGIN
        SELECT GAKUNEN_CD
          INTO IGAKUNEN_CD
          FROM GKBTGAKUNENLNK
         WHERE KOJIN_NO = n_KOJIN_NO;
      EXCEPTION
        WHEN OTHERS THEN
          IGAKUNEN_CD := -1;
      END;

      -- 学校情報取得
        R_GAKUREIBO     := null;
        I_GAKKO_KBN     := 0;
        I_EQGAKKO_CD    := 0;
        I_EQIDOBI       := 0;
        I_TORIKOMI_KBN  := 1;
      BEGIN
        SELECT *
          INTO R_GAKUREIBO
          FROM GKBTGAKUREIBO
         WHERE KOJIN_NO = n_KOJIN_NO
           AND SAISHIN_KBN = 0
           AND GEN_NENGAPI = 0;

          -- 小学校情報をチェック
          I_EQIDOBI_KBNGOTO := GREATEST(R_GAKUREIBO.SYOGAKO_NYUGAKU_BI, R_GAKUREIBO.SYOGAKO_TENNYUGAKU_BI,
                                        R_GAKUREIBO.SYOGAKO_TENGAKU_BI, R_GAKUREIBO.SYOGAKO_SOTSUGYO_BI);
          IF I_EQIDOBI <= I_EQIDOBI_KBNGOTO THEN
            -- 小学校のデータがあれば入れる(異動日には小学校での最新の異動日)
            I_GAKKO_KBN   := c_IEQGAKKO_SYOGAKO;
            I_EQGAKKO_CD  := R_GAKUREIBO.SYOGAKO_CD;
            I_EQIDOBI     := I_EQIDOBI_KBNGOTO;
          END IF;
          -- 中学校情報をチェック
          I_EQIDOBI_KBNGOTO := GREATEST(R_GAKUREIBO.TYUGAKO_NYUGAKU_BI, R_GAKUREIBO.TYUGAKO_TENNYUGAKU_BI,
                                        R_GAKUREIBO.TYUGAKO_TENGAKU_BI, R_GAKUREIBO.TYUGAKO_SOTSUGYO_BI);
          IF I_EQIDOBI <= I_EQIDOBI_KBNGOTO THEN
            -- 中学校のデータが新しければ入れる(異動日には中学校での最新の異動日)
            I_GAKKO_KBN   := c_IEQGAKKO_TYUGAKO;
            I_EQGAKKO_CD  := R_GAKUREIBO.TYUGAKO_CD;
            I_EQIDOBI     := I_EQIDOBI_KBNGOTO;
          END IF;
          -- 区域外情報をチェック
          I_EQIDOBI_KBNGOTO := GREATEST(R_GAKUREIBO.KUIKIGAI_NYUGAKU_BI, R_GAKUREIBO.KUIKIGAI_TENNYUGAKU_BI,
                                        R_GAKUREIBO.KUIKIGAI_TENGAKU_BI, R_GAKUREIBO.KUIKIGAI_TAIGAKU_BI,
                                        R_GAKUREIBO.KUIKIGAI_SOTSUGYO_BI);
          IF I_EQIDOBI <= I_EQIDOBI_KBNGOTO THEN
            -- 区域外のデータが新しければ入れる(異動日には区域外での最新の異動日)
            I_GAKKO_KBN   := c_IEQGAKKO_KUIKIGAI;
            I_EQGAKKO_CD  := R_GAKUREIBO.KUIKIGAI_CD;
            I_EQIDOBI     := I_EQIDOBI_KBNGOTO;
          END IF;
          -- 養護学校情報をチェック
          I_EQIDOBI_KBNGOTO := GREATEST(R_GAKUREIBO.YOGOGAKO_NYUGAKU_BI, R_GAKUREIBO.YOGOGAKO_TENNYUGAKU_BI,
                                    R_GAKUREIBO.YOGOGAKO_TENGAKU_BI, R_GAKUREIBO.YOGOGAKO_TAIGAKU_BI,
                                    R_GAKUREIBO.YOGOGAKO_SOTSUGYO_BI);
          IF I_EQIDOBI <= I_EQIDOBI_KBNGOTO THEN
            -- 養護学校のデータが新しければ入れる(異動日には養護学校での最新の異動日)
            I_GAKKO_KBN   := c_IEQGAKKO_YOGOGAKO;
            I_EQGAKKO_CD  := R_GAKUREIBO.YOGOGAKO_CD;
            I_EQIDOBI     := I_EQIDOBI_KBNGOTO;
          END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          R_GAKUREIBO    := NULL;
          I_GAKKO_KBN    := 0;
          I_EQGAKKO_CD   := 0;
          I_EQIDOBI      := 0;
      END;

      -- 教育学校区コード
      R_WKB.EQGAKKOKU_CD := I_EQGAKKO_CD;

      -- 教育学校区名
      BEGIN
        CASE I_GAKKO_KBN
          WHEN c_IEQGAKKO_SYOGAKO THEN  -- 小学校の場合
            SELECT SYOGAKOMEI, TORIKOMI_KBN
              INTO R_WKB.EQGAKKOKU_MEI, I_TORIKOMI_KBN
              FROM GKBTSHOGAKKO
             WHERE SYOGAKO_CD = R_WKB.EQGAKKOKU_CD;

         WHEN c_IEQGAKKO_TYUGAKO THEN   -- 中学校の場合
           SELECT TYUGAKOMEI, TORIKOMI_KBN
             INTO R_WKB.EQGAKKOKU_MEI, I_TORIKOMI_KBN
             FROM GKBTCHUGAKKO
            WHERE TYUGAKO_CD = R_WKB.EQGAKKOKU_CD;

          WHEN c_IEQGAKKO_KUIKIGAI THEN -- 区域外の場合
            SELECT KUIKIGAIMEI
              INTO R_WKB.EQGAKKOKU_MEI
              FROM GKBTKUIKIGAI
             WHERE KUIKIGAI_CD = R_WKB.EQGAKKOKU_CD;

          WHEN c_IEQGAKKO_YOGOGAKO THEN -- 養護学校の場合
            SELECT YOGOGAKOMEI
              INTO R_WKB.EQGAKKOKU_MEI
              FROM GKBTYOGOGAKKO
             WHERE YOGOGAKO_CD = R_WKB.EQGAKKOKU_CD;

          ELSE
            R_WKB.EQGAKKOKU_MEI := NULL;
            I_TORIKOMI_KBN      := 1;
        END CASE;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          R_WKB.EQGAKKOKU_MEI := NULL;
      END;

      -- 住記学校区コード＆住記学校区名
      IF IGAKUNEN_CD >= 0 AND 6 >= IGAKUNEN_CD THEN
        R_WKB.EAGAKKOKU_CD := R_WKB.SHOGAKU_CD;
        IF R_WKB.JKN_KIJUN_BI >= o_IGAPPEI_BI THEN
          R_WKB.EAGAKKOKU_MEI := GAAPK0030.FSHOGAKUMEI( 1, R_WKB.SHOGAKU_CD );
        ELSE
          R_WKB.EAGAKKOKU_MEI := GAAPK0030.FSHOGAKUMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.SHOGAKU_CD );
        END IF;
        IF I_GAKKO_KBN = 0 THEN
          I_GAKKO_KBN := c_IEAGAKKO_SYOGAKO;
        END IF;

      ELSIF IGAKUNEN_CD >= 7 AND 9 >= IGAKUNEN_CD THEN
        R_WKB.EAGAKKOKU_CD := R_WKB.CHUGAKU_CD;
        IF R_WKB.JKN_KIJUN_BI >= o_IGAPPEI_BI THEN
          R_WKB.EAGAKKOKU_MEI := GAAPK0030.FCHUGAKUMEI( 1, R_WKB.CHUGAKU_CD );
        ELSE
          R_WKB.EAGAKKOKU_MEI := GAAPK0030.FCHUGAKUMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.CHUGAKU_CD );
        END IF;
        IF I_GAKKO_KBN = 0 THEN
          I_GAKKO_KBN := c_IEAGAKKO_TYUGAKO;
        END IF;
      ELSIF IGAKUNEN_CD = -1 THEN
        -- 学年リンクにデータがない場合は年度末の年齢を元に学校名を取得
        IF I_NENDOMATSU_NENREI BETWEEN 6 AND 12 THEN
          R_WKB.EAGAKKOKU_CD := R_WKB.SHOGAKU_CD;
          IF R_WKB.JKN_KIJUN_BI >= o_IGAPPEI_BI THEN
            R_WKB.EAGAKKOKU_MEI := GAAPK0030.FSHOGAKUMEI( 1, R_WKB.SHOGAKU_CD );
          ELSE
            R_WKB.EAGAKKOKU_MEI := GAAPK0030.FSHOGAKUMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.SHOGAKU_CD );
          END IF;
          IF I_GAKKO_KBN = 0 THEN
            I_GAKKO_KBN := c_IEAGAKKO_SYOGAKO;
          END IF;
        ELSIF I_NENDOMATSU_NENREI BETWEEN 13 AND 15 THEN
          R_WKB.EAGAKKOKU_CD := R_WKB.CHUGAKU_CD;
          IF R_WKB.JKN_KIJUN_BI >= o_IGAPPEI_BI THEN
            R_WKB.EAGAKKOKU_MEI := GAAPK0030.FCHUGAKUMEI( 1, R_WKB.CHUGAKU_CD );
          ELSE
            R_WKB.EAGAKKOKU_MEI := GAAPK0030.FCHUGAKUMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.CHUGAKU_CD );
          END IF;
          IF I_GAKKO_KBN = 0 THEN
            I_GAKKO_KBN := c_IEAGAKKO_TYUGAKO;
          END IF;
        ELSE
          R_WKB.EAGAKKOKU_CD := 0;
          R_WKB.EAGAKKOKU_MEI := '';
        END IF;
      ELSE
        R_WKB.EAGAKKOKU_CD := 0;
        R_WKB.EAGAKKOKU_MEI := '';
      END IF;

      RETURN w_IRTN;

    EXCEPTION
      WHEN OTHERS THEN
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_GAKKO_JOHO', 1, SQLCODE, SQLERRM, SUBSTR(VERRMSG || ':FUNCGET_GAKKO_JOHO', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
      RETURN w_IRTN;
    END FUNCGET_GAKKO_JOHO;

    --------------------------------------------------------------------------------
    -- 更新用ワーク変数にセット
    --------------------------------------------------------------------------------
    FUNCTION FUNCSET_DATA_WK ( i_FLG  IN INTEGER ) RETURN PLS_INTEGER IS

      w_IRTN           PLS_INTEGER;
      w_VDUMMY         NVARCHAR2(30);
      ERR              EXCEPTION;
    BEGIN
      w_IRTN := c_IRETOK;

          --連番カウント
          R_WKB.RENBAN := R_WKB.RENBAN + 1;
          --条件基準日の取得
          SELECT TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) INTO R_WKB.JKN_KIJUN_BI FROM DUAL;
          --条件作成日の取得
          SELECT TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) INTO R_WKB.JKN_SAKUSEI_BI FROM DUAL;
          --システム作成日
          SELECT TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) INTO R_WKB.SYS_SAKUSEIBI FROM DUAL;
          I_NENDOMATSU_BI := (KKAPK0020.FDAYNENDO(R_WKB.JKN_KIJUN_BI, 0) + 1) * 10000 + 401;
          IF R_WKB.SEINENGAPI = 0 THEN
            I_NENDOMATSU_NENREI := NULL;
          ELSE
            I_NENDOMATSU_NENREI := KKAPK0020.FAgeGet(TO_CHAR(R_WKB.SEINENGAPI), TO_CHAR(I_NENDOMATSU_BI));
          END IF;
          --システム更新日
          R_WKB.SYS_KOSHINBI := 0;
          --システム更新時間
          SELECT TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS')) INTO R_WKB.SYS_JIKAN FROM DUAL;

          ----------------------------------------------------
          --住所情報取得
          ----------------------------------------------------
          --現住所
          IF NJUSHO > 0 THEN
            B_RTN := GETADDR( NJUSHO, R_WKB.KOJIN_NO,
                              R_WKB.CHOMEI, R_WKB.BANCHI, R_WKB.KATAGAKI,
                              R_WKB.JICHI_CD, R_WKB.YUBIN_NO, R_WKB.YUBIN_NOBC );
            --町名編集（システム条件＝１のときは大字以降を出力）
            IF NSYSJKN = 1 THEN
              R_WKB.CHOMEI := CHOMEIEDIT( VKADOSHI, R_WKB.CHOMEI );
            END IF;
          END IF;
          --前住所
          IF NZENJUSHO > 0 THEN
            B_RTN := GETADDR( NZENJUSHO, R_WKB.KOJIN_NO,
                              R_WKB.ZEN_CHOMEI, R_WKB.ZEN_BANCHI, R_WKB.ZEN_KATAGAKI,
                              R_WKB.ZEN_JICHI_CD, R_WKB.ZEN_YUBIN_NO, w_VDUMMY );
            --町名編集（システム条件＝１のときは大字以降を出力）
            IF NSYSJKN = 1 THEN
              R_WKB.ZEN_CHOMEI := CHOMEIEDIT( VKADOSHI, R_WKB.ZEN_CHOMEI );
            END IF;
          END IF;
          --転入前住所 転入・住所設定は転入元、転居は前住所、転出は転出先、確定は確定地、その他は備考
          --を出力するように変更
          IF R_WKB.IDO_JIYU =11 OR R_WKB.IDO_JIYU =18 THEN
            VRENBAN := NTENNYU;
          ELSIF R_WKB.IDO_JIYU = 21 THEN
            VRENBAN := NTENSHUTSU;
          ELSIF R_WKB.IDO_JIYU > 30 AND R_WKB.IDO_JIYU < 35 THEN
            VRENBAN := NZENJUSHO;
          ELSIF R_WKB.IDO_JIYU = 45 THEN
            VRENBAN := NTENKAKU;
          ELSE
            VRENBAN := 0;
          END IF;

          IF VRENBAN > 0 THEN
            B_RTN := GETADDR( VRENBAN, R_WKB.KOJIN_NO,
                              R_WKB.TENNYU_CHOMEI, R_WKB.TENNYU_BANCHI, R_WKB.TENNYU_KATAGAKI,
                              R_WKB.TENNYU_JICHI_CD, R_WKB.TENNYU_YUBIN_NO, w_VDUMMY  );
            --町名編集（システム条件＝１のときは大字以降を出力）
            IF NSYSJKN = 1 THEN
              R_WKB.TENNYU_CHOMEI := CHOMEIEDIT( VKADOSHI, R_WKB.TENNYU_CHOMEI );
            END IF;
          ELSE
            R_WKB.TENNYU_CHOMEI := SUBSTR(VBIKO,1,40);
            R_WKB.TENNYU_BANCHI := SUBSTR(VBIKO,41,80);
            R_WKB.TENNYU_KATAGAKI := SUBSTR(VBIKO,81,140);
          END IF;
          --本籍地住所
          IF NHONSEKI > 0 THEN
            B_RTN := GETADDR( NHONSEKI, R_WKB.KOJIN_NO,
                              R_WKB.HONSEKI_CHOMEI, R_WKB.HONSEKI_BANCHI, R_WKB.HONSEKI_KATAGAKI,
                              R_WKB.HONSEKI_JICHI_CD, R_WKB.HONSEKI_YUBIN_NO, w_VDUMMY  );
            --町名編集（システム条件＝１のときは大字以降を出力）
            IF NSYSJKN = 1 THEN
              R_WKB.HONSEKI_CHOMEI := CHOMEIEDIT( VKADOSHI, R_WKB.HONSEKI_CHOMEI );
            END IF;
          END IF;
          --転出予定地住所
          IF NTENSHUTSU > 0 THEN
            B_RTN := GETADDR( NTENSHUTSU, R_WKB.KOJIN_NO,
                              R_WKB.TENSHUTSU_CHOMEI, R_WKB.TENSHUTSU_BANCHI, R_WKB.TENSHUTSU_KATAGAKI,
                              R_WKB.TENSHUTSU_JICHI_CD, R_WKB.TENSHUTSU_YUBIN_NO, w_VDUMMY );
            --町名編集（システム条件＝１のときは大字以降を出力）
            IF NSYSJKN = 1 THEN
              R_WKB.TENSHUTSU_CHOMEI := CHOMEIEDIT( VKADOSHI, R_WKB.TENSHUTSU_CHOMEI );
            END IF;
          END IF;
          --転出確定地住所
          IF NTENKAKU > 0 THEN
            B_RTN := GETADDR( NTENKAKU, R_WKB.KOJIN_NO,
                              R_WKB.TENKAKU_CHOMEI, R_WKB.TENKAKU_BANCHI, R_WKB.TENKAKU_KATAGAKI,
                              R_WKB.TENKAKU_JICHI_CD, R_WKB.TENKAKU_YUBIN_NO, w_VDUMMY  );
            --町名編集（システム条件＝１のときは大字以降を出力）
            IF NSYSJKN = 1 THEN
              R_WKB.TENKAKU_CHOMEI := CHOMEIEDIT( VKADOSHI, R_WKB.TENKAKU_CHOMEI );
            END IF;
          END IF;
          --ログ出力
          IF B_RTN THEN
            NULL;
          ELSE
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_DATA_WK', 1, '', '', SUBSTR(VERRMSG || ':GETADDR', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
            return c_IERR;
            RAISE ERR;
          END IF;
          ----------------------------------------------------
          --事由名取得
          ----------------------------------------------------
          B_RTN := GETJIYU( R_WKB.IDO_JIYU, R_WKB.IDO_JIYU_MEI );                   --異動事由
          B_RTN := GETJIYU( R_WKB.JUTEI_JIYU, R_WKB.JUTEI_JIYU_MEI );               --住定事由
          B_RTN := GETJIYU( R_WKB.JUMIN_NARU_JIYU, R_WKB.JUMIN_NARU_JIYUMEI );      --住民となる事由
          B_RTN := GETJIYU( R_WKB.JUMIN_NAKUNARU_JIYU, R_WKB.JUMIN_NAKU_JIYUMEI );  --住民でなくなる事由
          --ログ出力
          IF B_RTN THEN
            NULL;
          ELSE
              B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_DATA_WK', 1, '', '', SUBSTR(VERRMSG || ':GETJIYU', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
            return c_IERR;
            RAISE ERR;
          END IF;
          --支所名取得
          IF TRIM(R_WKB.SHISHO_CD) = '0' THEN
            R_WKB.SHISHO_MEI := NULL;
          ELSE
            BEGIN
              SELECT MEISHO
                INTO R_WKB.SHISHO_MEI
                FROM KKATCD
               WHERE TRIM(ANYCODE) = TRIM(R_WKB.SHISHO_CD)
                 AND GYOUMUCODE = 'KKN'
                 AND TRIM(CODECODE) = '001'
                 AND GROUPCODE = '0000';
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                R_WKB.SHISHO_MEI := NULL;
            END;
          END IF;
          --合併日以降は算定団体コード＝１の内容を取得する
          --地区名取得
          IF R_WKB.JKN_KIJUN_BI >= o_IGAPPEI_BI THEN
            R_WKB.CHIKUMEI      := GAAPK0030.FCHIKUMEI( 1, R_WKB.CHIKU_CD );
          ELSE
            R_WKB.CHIKUMEI      := GAAPK0030.FCHIKUMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.CHIKU_CD );
          END IF;
          --行政区名取得
          IF R_WKB.JKN_KIJUN_BI >= o_IGAPPEI_BI THEN
            R_WKB.GYOSEIKU_MEI  := GAAPK0030.FGYOSEIKUMEI( 1, R_WKB.GYOSEIKU_CD );
          ELSE
            R_WKB.GYOSEIKU_MEI  := GAAPK0030.FGYOSEIKUMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.GYOSEIKU_CD );
          END IF;
          --班名取得
          IF R_WKB.JKN_KIJUN_BI >= o_IGAPPEI_BI THEN
            R_WKB.HAN_MEI       := GAAPK0030.FHANMEI( 1, R_WKB.HAN_CD );
          ELSE
            R_WKB.HAN_MEI       := GAAPK0030.FHANMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.HAN_CD );
          END IF;
          --小学校区名取得
          IF R_WKB.JKN_KIJUN_BI >= o_IGAPPEI_BI THEN
            R_WKB.SHOGAKU_MEI   := GAAPK0030.FSHOGAKUMEI( 1, R_WKB.SHOGAKU_CD );
          ELSE
            R_WKB.SHOGAKU_MEI   := GAAPK0030.FSHOGAKUMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.SHOGAKU_CD );
          END IF;
          IF R_WKB.JKN_KIJUN_BI >= o_IGAPPEI_BI THEN
            R_WKB.CHUGAKU_MEI   := GAAPK0030.FCHUGAKUMEI( 1, R_WKB.CHUGAKU_CD );
          ELSE
            R_WKB.CHUGAKU_MEI   := GAAPK0030.FCHUGAKUMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.CHUGAKU_CD );
          END IF;
          --投票区名取得
          IF R_WKB.JKN_KIJUN_BI >= o_IGAPPEI_BI THEN
            R_WKB.TOHYOKU_MEI   := GAAPK0030.FTOHYOKUMEI( 1, R_WKB.TOHYOKU_CD );
          ELSE
            R_WKB.TOHYOKU_MEI   := GAAPK0030.FTOHYOKUMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.TOHYOKU_CD );
          END IF;
          --旧自治体名取得
          I_RTN                 := GAAPK0030.FJICHINAME( R_WKB.SANTEIDANTAI_CD, R_WKB.KYUJICHI_MEI );
          --市町村名取得
          R_WKB.USERMEI         := GAAPK0030.FSHIKUCHOSON( R_WKB.JICHI_CD );
          --大字名取得
          R_WKB.OAZA_MEI        := GAAPK0030.FOAZAMEI( R_WKB.SANTEIDANTAI_CD, R_WKB.OAZA_CD );
          --年齢取得
          IF R_WKB.SEINENGAPI = 0 THEN
            R_WKB.NENREI          := NULL;
          ELSE
            R_WKB.NENREI          := KKAPK0020.FAgeGet( TO_CHAR(R_WKB.SEINENGAPI), TO_CHAR(R_WKB.JKN_KIJUN_BI));
          END IF;

          --備考文１，２、３
          --備考１に備考タイトルをセットする
          R_WKB.BIKO_1 := NULL;
          IF R_WKB.IDO_JIYU = 11 THEN
            R_WKB.BIKO_1 := '転入元';
          ELSIF R_WKB.IDO_JIYU = 21 THEN
            R_WKB.BIKO_1 := '転出先';
          ELSIF R_WKB.IDO_JIYU BETWEEN 31 AND 34 THEN
            R_WKB.BIKO_1 := '前住所';
          ELSIF R_WKB.IDO_JIYU = 45 THEN
            R_WKB.BIKO_1 := '確定地';
          ELSE
            R_WKB.BIKO_1 := '備考';
          END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--           IF i_FLG <> 0 THEN
--             R_WKB.BIKO_1 := '備考';
--           END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete end 
          IF NSETAI_IDOKBN = 0 THEN
            R_WKB.CHOHYO_TITLE := c_VCHOHYO_NAME010;
            R_WKB.BIKO_2 := c_VCHOHYO_ITEM010;
            R_WKB.BIKO_3 := c_VCHOHYO_ITEM020;
            R_WKB.BIKO_4 := c_VCHOHYO_ITEM030;
          ELSE
            R_WKB.CHOHYO_TITLE := c_VCHOHYO_NAME011;
            R_WKB.BIKO_2 := c_VCHOHYO_ITEM011;
            R_WKB.BIKO_3 := c_VCHOHYO_ITEM021;
            R_WKB.BIKO_4 := c_VCHOHYO_ITEM031;
          END IF;

          --全部一部区分編集
          IF R_WKB.ZENBU_ICHIBU_KEY = 1 THEN
            R_WKB.ZENBU_ICHIBU_KBN := '一部';
          ELSIF R_WKB.ZENBU_ICHIBU_KEY = 2 THEN
            R_WKB.ZENBU_ICHIBU_KBN := '全部';
          END IF;
          --廃鑑区分編集
          --更新職員名取得
          BEGIN
            SELECT SUBSTR(NVL(TANTONAME,''),1,100) AS SYOKUIN_SHIMEI INTO R_WKB.KOSHINSHOKUIN_MEI
              FROM KKNTTN
             WHERE TANTOCODE  = g_sTANTOCODE
               AND YUKOKIKANFR <= SYSDATE
               AND (YUKOKIKANTO >= SYSDATE
                OR YUKOKIKANTO IS NULL);
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              R_WKB.KOSHINSHOKUIN_MEI := NULL;
          END;
          ----------------------------------------------------
          --日付編集(和暦変換せず単にNVARCHAR2型に変換)
          ----------------------------------------------------
          R_WKB.JKN_KIJUN_BI                  := TO_CHAR( R_WKB.JKN_KIJUN_BI );                 --条件基準日
          R_WKB.JKN_SAKUSEI_BI                := TO_CHAR( R_WKB.JKN_SAKUSEI_BI );               --条件作成日
          R_WKB.JKN_CHUSHUTSU_KAISHI          := g_vJYOUKEN1;                                   --条件抽出開始日
          R_WKB.JKN_CHUSHUTSU_SHURYO          := g_vJYOUKEN2;                                   --条件抽出終了日
          R_WKB.JKN_SEINENGAPI_KAISHI         := g_vJYOUKEN3;                                   --生年月日開始日
          R_WKB.JKN_SEINENGAPI_SHURYO         := g_vJYOUKEN4;                                   --生年月日終了日
          R_WKB.IDO_BI                        := TO_CHAR( R_WKB.IDO_BI );                       --異動日
          R_WKB.IDO_TODOKE_BI                 := TO_CHAR( R_WKB.IDO_TODOKE_BI );                --異動届出日
          R_WKB.JUTEI_BI                      := TO_CHAR( R_WKB.JUTEI_BI );                     --住定日
          R_WKB.JUTEI_TODOKEDE_BI             := TO_CHAR( R_WKB.JUTEI_TODOKEDE_BI );            --住定届出日
          R_WKB.TENSHUTSU_YOTEI_BI            := TO_CHAR( R_WKB.TENSHUTSU_YOTEI_BI );           --転出予定日
          R_WKB.TENSHUTSU_YOTEI_TODOKEDE_BI   := TO_CHAR( R_WKB.TENSHUTSU_YOTEI_TODOKEDE_BI );  --転出予定届出日
          R_WKB.TENSHUTSU_KAKUTEI_BI          := TO_CHAR( R_WKB.TENSHUTSU_KAKUTEI_BI );         --転出確定日
          R_WKB.KAKUTEI_TSUCHI_BI             := TO_CHAR( R_WKB.KAKUTEI_TSUCHI_BI );            --転出確定通知日
          R_WKB.JUMIN_NARU                    := TO_CHAR( R_WKB.JUMIN_NARU );                   --住民となる日
          R_WKB.JUMIN_NARU_TODOKEDE_BI        := TO_CHAR( R_WKB.JUMIN_NARU_TODOKEDE_BI );       --住民となる届出日
          R_WKB.JUMIN_NAKUNARU                := TO_CHAR( R_WKB.JUMIN_NAKUNARU );               --住民でなくなる日
          R_WKB.JUMIN_NAKUNARU_TODOKEDE_BI    := TO_CHAR( R_WKB.JUMIN_NAKUNARU_TODOKEDE_BI );   --住民でなくなる届出日
          R_WKB.KAISEI_BI                     := TO_CHAR( R_WKB.KAISEI_BI );                    --改製日
          V_IDOBI       := HIZUKE(R_WKB.IDO_BI,1);
          V_TODOKEBI    := HIZUKE(R_WKB.IDO_TODOKE_BI,1);

          w_IRTN := FUNCGET_GAKKO_JOHO(R_WKB, i_FLG);
          --集計区分編集
          IF NSORT_KBN IN (1, 2, 3, 4) THEN
            IF I_GAKKO_KBN >= 3 THEN
              R_WKB.SHUKEI_KBN := R_WKB.EQGAKKOKU_MEI;
            ELSE
              R_WKB.SHUKEI_KBN := R_WKB.EAGAKKOKU_MEI;
            END IF;
            VLOGKBN := '学校区毎';
          ELSE
            IF NSHUKEI_KBN = 0 THEN
              R_WKB.SHUKEI_KBN := '全体';
              VLOGKBN := '全体';
            ELSIF NSHUKEI_KBN = 1 THEN
              R_WKB.SHUKEI_KBN := R_WKB.KYUJICHI_MEI;
              VLOGKBN := '旧自治体毎';
            ELSIF NSHUKEI_KBN = 2 THEN
              R_WKB.SHUKEI_KBN := R_WKB.SHISHO_MEI;
              VLOGKBN := '支所毎';
            ELSIF NSHUKEI_KBN = 3 THEN
              IF I_GAKKO_KBN >= 3 THEN
                R_WKB.SHUKEI_KBN := R_WKB.EQGAKKOKU_MEI;
              ELSE
                R_WKB.SHUKEI_KBN := R_WKB.EAGAKKOKU_MEI;
              END IF;
              VLOGKBN := '学校毎';
            END IF;
          END IF;

          --性別編集
          IF NSEIBETSU = 1 THEN
            R_WKB.SEIBETSU := '男';
          ELSIF NSEIBETSU = 2 THEN
            R_WKB.SEIBETSU := '女';
          ELSE
            R_WKB.SEIBETSU := '';
            R_WKB.EQGAKKOKU_MEI := '';
            R_WKB.EAGAKKOKU_MEI := '';
          END IF;

          -- 学校区分
          R_WKB.GAKKO_KBN            := I_GAKKO_KBN;

          R_WKB.JKN_KIJUN_BI         := V_KIJUNBI;
          R_WKB.JKN_SAKUSEI_BI       := V_SAKUSEIBI;
          R_WKB.JKN_CHUSHUTSU_KAISHI := V_KAISHIBI;
          R_WKB.JKN_CHUSHUTSU_SHURYO := V_SHURYOBI;
          R_WKB.JKN_SEINENGAPI_KAISHI := V_SEINENGAPI_KAISHIBI;
          R_WKB.JKN_SEINENGAPI_SHURYO := V_SEINENGAPI_SHURYOBI;

          ----------------------------------------------
          --中間TBL書き込み
          ----------------------------------------------
          BEGIN
            INSERT INTO GKBWIDOICHIRAN VALUES R_WKB;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                NULL;
              WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('失敗宛名番号：' || R_WKB.KOJIN_NO);
                DBMS_OUTPUT.PUT_LINE('SQLCODE：' || SQLCODE);
                DBMS_OUTPUT.PUT_LINE('ERR：' || SQLERRM);
          END;
          COMMIT;
      RETURN w_IRTN;

    EXCEPTION
      WHEN OTHERS THEN
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCSET_DATA_WK', 1, SQLCODE, SQLERRM, SUBSTR(VERRMSG || ':FUNCSET_DATA_WK', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        RETURN c_IERR;
    END FUNCSET_DATA_WK;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
--    --------------------------------------------------------
--    --  機能概要      : 件数表で対応メッセージが含めか
--    --  パラメータ    : i_vKENSUU_NAIYOU 件数表のタイトル
--    --  モジュール区分: 内部関数
--    --  戻り値        : 含める TRUE,  含めいない FALSE
--    --  バージョン    : Ver 0.2.000.000
--    --  作成者／作成日: ZCZL.GUOXU 2024/1/2
--    --------------------------------------------------------
--    FUNCTION FUNC_CHECK_KENSUU(i_vKENSUU_NAIYOU VARCHAR2) RETURN BOOLEAN IS
--    BEGIN
--        IF g_oKENSU_LIST IS NULL OR g_oKENSU_LIST.COUNT = 0 THEN
--          RETURN FALSE;
--        END IF;
--        FOR i IN 1..g_oKENSU_LIST.COUNT LOOP
--           --同じタイトルを含めて、一つを設定する
--           IF g_oKENSU_LIST(i).NAIYOU = i_vKENSUU_NAIYOU THEN
--               RETURN TRUE;
--           END IF;
--        END LOOP;
--        RETURN FALSE;
--    END FUNC_CHECK_KENSUU;
-- 2024/06/12 ZCZL.wangyunhan Add end 
-- 2024/06/12 ZCZL.wangyunhan DELETE start 0.3.000.000:新WizLIFE２次開発
--   --------------------------------------------------------------------------------
--    --  機能概要      : 住記異動者一覧CSVワークの作成
--    --  パラメータ    : なし
--    --  モジュール区分: 内部関数
--    --  戻り値        : 正常 TRUE,その他 FALSE
--    --  バージョン    : Ver 0.2.000.000
--    --  作成者／作成日: ZCZL.WANGYUNHAN 2024/01/02
--    --------------------------------------------------------------------------------
--    FUNCTION FUNC_SET_JIDO_WK_CSVFILE RETURN BOOLEAN IS
--
--        bRTN                BOOLEAN;                    -- 戻り値
--        --動的SQL(1)（中間TBL項目取得用）
--        VSQL      NVARCHAR2(2000);                    --SQL文字列用
--        --CSV出力用
--        TYPE  ref_CUR_DOUTAI IS REF CURSOR;           --カーソル定義
--        C1    ref_CUR_DOUTAI;                         --動態カーソル
--        CR1   GKBWIDOICHIRAN%ROWTYPE;                 --C1カーソルのレコード
--        r_WKRECORD001 GKBWDB002001%ROWTYPE;
--        nROWNO NUMBER;
--    BEGIN
--        VSQL := 'SELECT * FROM GKBWIDOICHIRAN';
--
--
--  --CSVファイル作成処理
--  OPEN C1 FOR VSQL;
--  LOOP
--    FETCH C1 INTO CR1;
--    EXIT WHEN C1%NOTFOUND;
--           nROWNO := nROWNO + 1;
--    r_WKRECORD001 := NULL;
--    r_WKRECORD001.RIREKISEQ               := nROWNO;                                 --ソート順
--    r_WKRECORD001.FILESEQ                 := CR1.USERMEI;                            --市区町村名
--    r_WKRECORD001.FILENAME                := CR1.CHOHYO_TITLE;                       --帳票タイトル
--    r_WKRECORD001.CONSERVE_FILENAME       := CR1.SHUKEI_KBN;                         --集計区分
--    r_WKRECORD001.CONSERVE_PATH           := CR1.JKN_CHUSHUTSU_KAISHI;               --条件抽出開始日
--    r_WKRECORD001.DATAKBN                 := CR1.JKN_CHUSHUTSU_SHURYO;               --条件抽出終了日
--    r_WKRECORD001.ROWNUMBER               := CR1.JKN_SEINENGAPI_KAISHI;              --生年月日始
--   -- r_WKRECORD001.DATA                    := '1';                             --項目名０１
--    r_WKRECORD001.CNT                     := CR1.BIKO_3;                             --項目名０２
--    r_WKRECORD001.OUTPUT_STATUS           := CR1.BIKO_4;                             --項目名０３
--    r_WKRECORD001.DOWNLOAD_STATUS         := CR1.IDO_JIYU_MEI;                       --異動事由
--    r_WKRECORD001.DOWNLOAD_TANTOCODE      := CR1.SHIMEI_KANA;                        --異動者氏名かな
--    r_WKRECORD001.DOWNLOAD_SHORIDATETIME  := CR1.SHIMEI_KANJI;                       --異動者氏名漢字
--    r_WKRECORD001.DOWNLOAD_SHORIWSNUM     := CR1.ZOKUGARA_MEI;                       --続柄
--    r_WKRECORD001.RECUPDTANTOCODE         := CR1.SEIBETSU;                           --性別
--    r_WKRECORD001.RECUPDDATETIME          := CR1.NUSHI_SHIMEI_KANJI;                 --世帯主名
--    r_WKRECORD001.RECUPDWSNUM             := CR1.CHOMEI;                             --町名
--    r_WKRECORD001.RECUPDKBNCODE           := CR1.BANCHI;                             --番地
-- 
--           INSERT INTO GKBWDB002001 VALUES r_WKRECORD001;
--            
--        END LOOP;
--          IF C1%ISOPEN THEN
--    CLOSE C1;
--   END IF;
--        
--        -- 終了
--        RETURN bRTN;
--   EXCEPTION
--        WHEN OTHERS THEN
--            bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, SQLCODE, SQLERRM, '異常終了', g_sTANTOCODE, g_sWSNUM, 1);
--            RAISE;
--    END FUNC_SET_JIDO_WK_CSVFILE;
-- 2024/06/12 ZCZL.wangyunhan DELETE end 
    --------------------------------------------------------------------------------
    --i_FLG = 0:就学児童又は年齢条件に該当かつ異動者
    --        1:就学児童の世帯員を含めた異動者
    --------------------------------------------------------------------------------
    FUNCTION FUNCGET_DATA ( i_FLG  IN INTEGER ) RETURN PLS_INTEGER IS

      w_IRTN                      PLS_INTEGER;
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--      w_JIDO_KOJIN_NO             NUMBER(12);
      w_JIDO_KOJIN_NO             NUMBER(15);
      w_IDO_JIYU                  NUMBER(2);
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
      SHOGAKKOKUCD       NVARCHAR2(100);   --小学校区コード
      SHOGAKKOKUMEI      NVARCHAR2(100);   --小学校区名
      TYUGAKOKUCD        NVARCHAR2(100);   --中学校区コード
      TYUGAKOKUMEI       NVARCHAR2(100);   --中学校区名
      RATENA_REC         GABTATENAKIHON%ROWTYPE;
      RSOFU_REC          GABTSOFUSAKI%ROWTYPE;
-- 2025/06/16 CTC.LIUJUNHAO UPDATE 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
      JDRATENA_REC         GABTATENAKIHON%ROWTYPE;
      JDRSOFU_REC          GABTSOFUSAKI%ROWTYPE;
      JD_IRTN                      PLS_INTEGER;
      HG_IRTN                      PLS_INTEGER;
      HOGOSHA_ATENANO      NUMBER(15);
      GKHOGOSHA_ATENANO    NUMBER(15);
      GKZOKUGARA1          NUMBER(2);
      GKZOKUGARA2          NUMBER(2);
      GKZOKUGARA3          NUMBER(2);
      GKZOKUGARA4          NUMBER(2);
      HOGOSHA_SETAINUSI    NVARCHAR2(100);
-- 2025/06/16 CTC.LIUJUNHAO UPDATE 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
      oKOKUSEKI          NVARCHAR2(100);   --国名
      oJIDO_KOKUSEKI     NVARCHAR2(100);   --児童生徒国籍
      oHOGOSHA_KOKUSEKI  NVARCHAR2(100);   --保護者国籍
      oKOKUMEI_ALPHABET  NVARCHAR2(5000);  -- 国名アルファベット
      oZOKUGARA_MEI      NVARCHAR2(100);   --続柄名
      oERRMSG            NVARCHAR2(100);   --エラーコード
      oJUSHO             NVARCHAR2(100);   --住所
      oGAKKOMEI          NVARCHAR2(100);   --学校名
      oKAKKOCD           NVARCHAR2(100);   --学校コード
      oGAKONEN           NVARCHAR2(100);   --学年
      oGAKUCD            NVARCHAR2(100);   --学年コード
      oMGAKKO_CD         NVARCHAR2(100);   --文部科学省学校コード
      vSQL                              VARCHAR2(32767);
      VFROM  NVARCHAR2(250);
      NKENSU NUMBER := 0;  -- 変数.件数カウント
         KOJIN_NO                        JIBTIDORUIKEI.KOJIN_NO%TYPE:=NULL;
         IDO_JIYU                        JIBTIDORUIKEI.IDO_JIYU%TYPE:=NULL;
         SHORIBI_KEY                     JIBTIDORUIKEI.SHORIBI_KEY%TYPE:=NULL;
         SHORI_JIKAN_KEY                 JIBTIDORUIKEI.SHORI_JIKAN_KEY%TYPE:=NULL;
         SHORI_KBN_KEY                   JIBTIDORUIKEI.SHORI_KBN_KEY%TYPE:=NULL;
         ZENBU_ICHIBU_KEY                JIBTIDORUIKEI.ZENBU_ICHIBU_KEY%TYPE:=NULL;
         SHOKUINKOJIN_NO_KEY             JIBTIDORUIKEI.SHOKUINKOJIN_NO_KEY%TYPE:=NULL;
         HAIKAN_KBN                      JIBTIDORUIKEI.HAIKAN_KBN%TYPE:=NULL;
         BIKO_BUN                        JIBTIDORUIKEI.BIKO_BUN%TYPE:=NULL;
         SHORIBI                         JIBTIDORUIKEI.SHORIBI%TYPE:=NULL;
        SJSHIMEI_KANA                      GABVATENAALL.SHIMEI_KANA%TYPE:=NULL;
        SJSHIMEI_KANJI                     GABVATENAALL.SHIMEI_KANJI%TYPE :=NULL;
        SJKOKUSEKI_CD                      GABVATENAALL.KOKUSEKI_CD%TYPE   :=NULL;
        SJYUBIN_NO                         GABVATENAALL.YUBIN_NO%TYPE      :=NULL;
        SJCHOMEI                           GABVATENAALL.CHOMEI%TYPE:=NULL;
        SJBANCHI                           GABVATENAALL.BANCHI%TYPE:=NULL;
        SJKOJIN_NO                         GABVATENAALL.KOJIN_NO%TYPE      :=NULL;
        SJSEINENGAPI                       GABVATENAALL.SEINENGAPI%TYPE    :=NULL;
        SJKATAGAKI                         GABVATENAALL.KATAGAKI%TYPE      :=NULL;
        SJZOKUGARA_MEI                     GABVATENAALL.ZOKUGARA_MEI%TYPE  :=NULL;
        SJSETAI_NO                         GABVATENAALL.SETAI_NO%TYPE      :=NULL;
        SJJINKAKU_KBN                      GABVATENAALL.JINKAKU_KBN%TYPE         :=NULL;
        SHSHIMEI_KANA                      GABVATENAALL.SHIMEI_KANA%TYPE:=NULL;
        SHSHIMEI_KANJI                     GABVATENAALL.SHIMEI_KANJI%TYPE :=NULL;
        SHKOKUSEKI_CD                      GABVATENAALL.KOKUSEKI_CD%TYPE   :=NULL;
        SHYUBIN_NO                         GABVATENAALL.YUBIN_NO%TYPE:=NULL;
        SHCHOMEI                           GABVATENAALL.CHOMEI%TYPE:=NULL;
        SHBANCHI                           GABVATENAALL.BANCHI%TYPE:=NULL;
        SHKOJIN_NO                         GABVATENAALL.KOJIN_NO%TYPE     :=NULL;
        SHSEINENGAPI                       GABVATENAALL.SEINENGAPI%TYPE :=NULL;
        SHKATAGAKI                         GABVATENAALL.KATAGAKI%TYPE    :=NULL;
        SHZOKUGARA_MEI                     GABVATENAALL.ZOKUGARA_MEI%TYPE  :=NULL;
        SHSETAI_NO                         GABVATENAALL.SETAI_NO%TYPE  :=NULL;
        SHJINKAKU_KBN                      GABVATENAALL.JINKAKU_KBN%TYPE:=NULL;
        GAKKO_KBN_CD                       GKBTGAKUREIBO.GAKKO_KBN_CD%TYPE:=NULL;
        RIREKI_RENBAN                      GKBTGAKUREIBO.RIREKI_RENBAN%TYPE:=NULL;
        HOGOSYA_KOJIN_NO                   GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE:=NULL;
        SYOGAKO_CD                         GKBTGAKUREIBO.SYOGAKO_CD%TYPE:=NULL;
        TYUGAKO_CD                         GKBTGAKUREIBO.TYUGAKO_CD%TYPE:=NULL;
        BOKOJIN_NO                         GKBTGAKUREIBO.KOJIN_NO%TYPE:=NULL;
        HOGOSYA_ZOKUGARA1                  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1%TYPE:=NULL;
        HOGOSYA_ZOKUGARA2                  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2%TYPE:=NULL;
        HOGOSYA_ZOKUGARA3                  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3%TYPE:=NULL;
        HOGOSYA_ZOKUGARA4                  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4%TYPE:=NULL;
        TODOKEDE_BI                        GKBTGAKUREIBO.TODOKEDE_BI%TYPE:=NULL;
        SEIBETSU                           GKBTGAKUREIBO.SEIBETSU%TYPE:=NULL;
        GAKUNEN                            GKBTGAKUREIBO.GAKUNEN%TYPE:=NULL;
        HOGOSYA_TSUSHOMEI_KANJI            GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI%TYPE:=NULL;
        HOGOSYA_TSUSHOMEI_KANA             GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA%TYPE:=NULL;
        BOSHORIBI                          GKBTGAKUREIBO.SHORIBI%TYPE:=NULL;
        IDO_BI                             GKBTGAKUREIBO.IDO_BI%TYPE:=NULL;
        KUIKIGAI_CD                        GKBTGAKUREIBO.KUIKIGAI_CD%TYPE:=NULL;
        YOGOGAKO_CD                        GKBTGAKUREIBO.YOGOGAKO_CD%TYPE:=NULL;
        GAKUKYU_CD                         GKBTGAKUREIBO.GAKUKYU_CD%TYPE:=NULL;
      
       TYPE MC_CURSOR IS REF CURSOR;
       cCURSOR                           MC_CURSOR;
       TYPE MR_PRINTPRM IS RECORD(
         KOJIN_NO                        JIBTIDORUIKEI.KOJIN_NO%TYPE,
         IDO_JIYU                        JIBTIDORUIKEI.IDO_JIYU%TYPE,
         SHORIBI_KEY                     JIBTIDORUIKEI.SHORIBI_KEY%TYPE,
         SHORI_JIKAN_KEY                 JIBTIDORUIKEI.SHORI_JIKAN_KEY%TYPE,
         SHORI_KBN_KEY                   JIBTIDORUIKEI.SHORI_KBN_KEY%TYPE,
         ZENBU_ICHIBU_KEY                JIBTIDORUIKEI.ZENBU_ICHIBU_KEY%TYPE,
         SHOKUINKOJIN_NO_KEY             JIBTIDORUIKEI.SHOKUINKOJIN_NO_KEY%TYPE,
         HAIKAN_KBN                      JIBTIDORUIKEI.HAIKAN_KBN%TYPE,
         BIKO_BUN                        JIBTIDORUIKEI.BIKO_BUN%TYPE,
         SHORIBI                         JIBTIDORUIKEI.SHORIBI%TYPE,
        SJSHIMEI_KANA                      GABVATENAALL.SHIMEI_KANA%TYPE,
        SJSHIMEI_KANJI                     GABVATENAALL.SHIMEI_KANJI%TYPE, 
        SJKOKUSEKI_CD                      GABVATENAALL.KOKUSEKI_CD%TYPE,   
        SJYUBIN_NO                         GABVATENAALL.YUBIN_NO%TYPE,      
        SJCHOMEI                           GABVATENAALL.CHOMEI%TYPE,
        SJBANCHI                           GABVATENAALL.BANCHI%TYPE,
        SJKOJIN_NO                         GABVATENAALL.KOJIN_NO%TYPE,      
        SJSEINENGAPI                       GABVATENAALL.SEINENGAPI%TYPE,    
        SJKATAGAKI                         GABVATENAALL.KATAGAKI%TYPE,      
        SJZOKUGARA_MEI                     GABVATENAALL.ZOKUGARA_MEI%TYPE,  
        SJSETAI_NO                         GABVATENAALL.SETAI_NO%TYPE,      
        SJJINKAKU_KBN                      GABVATENAALL.JINKAKU_KBN%TYPE,         
        SHSHIMEI_KANA                      GABVATENAALL.SHIMEI_KANA%TYPE,
        SHSHIMEI_KANJI                     GABVATENAALL.SHIMEI_KANJI%TYPE, 
        SHKOKUSEKI_CD                      GABVATENAALL.KOKUSEKI_CD%TYPE,   
        SHYUBIN_NO                         GABVATENAALL.YUBIN_NO%TYPE,
        SHCHOMEI                           GABVATENAALL.CHOMEI%TYPE,
        SHBANCHI                           GABVATENAALL.BANCHI%TYPE,
        SHKOJIN_NO                         GABVATENAALL.KOJIN_NO%TYPE,     
        SHSEINENGAPI                       GABVATENAALL.SEINENGAPI%TYPE, 
        SHKATAGAKI                         GABVATENAALL.KATAGAKI%TYPE,    
        SHZOKUGARA_MEI                     GABVATENAALL.ZOKUGARA_MEI%TYPE,  
        SHSETAI_NO                         GABVATENAALL.SETAI_NO%TYPE,  
        SHJINKAKU_KBN                      GABVATENAALL.JINKAKU_KBN%TYPE,
        GAKKO_KBN_CD                       GKBTGAKUREIBO.GAKKO_KBN_CD%TYPE,
        RIREKI_RENBAN                      GKBTGAKUREIBO.RIREKI_RENBAN%TYPE,
        HOGOSYA_KOJIN_NO                   GKBTGAKUREIBO.HOGOSYA_KOJIN_NO%TYPE,
        SYOGAKO_CD                         GKBTGAKUREIBO.SYOGAKO_CD%TYPE,
        TYUGAKO_CD                         GKBTGAKUREIBO.TYUGAKO_CD%TYPE,
        BOKOJIN_NO                         GKBTGAKUREIBO.KOJIN_NO%TYPE,
        HOGOSYA_ZOKUGARA1                  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1%TYPE,
        HOGOSYA_ZOKUGARA2                  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2%TYPE,
        HOGOSYA_ZOKUGARA3                  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3%TYPE,
        HOGOSYA_ZOKUGARA4                  GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4%TYPE,
        TODOKEDE_BI                        GKBTGAKUREIBO.TODOKEDE_BI%TYPE,
        SEIBETSU                           GKBTGAKUREIBO.SEIBETSU%TYPE,
        GAKUNEN                            GKBTGAKUREIBO.GAKUNEN%TYPE,
        HOGOSYA_TSUSHOMEI_KANJI            GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI%TYPE,
        HOGOSYA_TSUSHOMEI_KANA             GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA%TYPE,
        BOSHORIBI                          GKBTGAKUREIBO.SHORIBI%TYPE,
        IDO_BI                             GKBTGAKUREIBO.IDO_BI%TYPE,
        KUIKIGAI_CD                        GKBTGAKUREIBO.KUIKIGAI_CD%TYPE,
        YOGOGAKO_CD                        GKBTGAKUREIBO.YOGOGAKO_CD%TYPE,
        GAKUKYU_CD                         GKBTGAKUREIBO.GAKUKYU_CD%TYPE
       );
       CR_IDORK                             MR_PRINTPRM;
    BEGIN
        vSQL := '';
        vSQL := vSQL ||'      SELECT I.KOJIN_NO,';
        vSQL := vSQL ||'             I.IDO_JIYU,';
        vSQL := vSQL ||'             I.SHORIBI_KEY,';
        vSQL := vSQL ||'             I.SHORI_JIKAN_KEY,';
        vSQL := vSQL ||'             I.SHORI_KBN_KEY,';
        vSQL := vSQL ||'             I.ZENBU_ICHIBU_KEY,';
        vSQL := vSQL ||'             I.SHOKUINKOJIN_NO_KEY,';
        vSQL := vSQL ||'             I.HAIKAN_KBN,';
        vSQL := vSQL ||'             I.BIKO_BUN,';
        vSQL := vSQL ||'             I.SHORIBI';
        vSQL := vSQL ||'             ,SJ.SHIMEI_KANA   AS SJSHIMEI_KANA';
        vSQL := vSQL ||'             ,SJ.SHIMEI_KANJI  AS SJSHIMEI_KANJI';
        vSQL := vSQL ||'             ,SJ.KOKUSEKI_CD   AS SJKOKUSEKI_CD';
        vSQL := vSQL ||'             ,SJ.YUBIN_NO      AS SJYUBIN_NO';
        vSQL := vSQL ||'             ,SJ.CHOMEI        AS SJCHOMEI';
        vSQL := vSQL ||'             ,SJ.BANCHI        AS SJBANCHI';
        vSQL := vSQL ||'             ,SJ.KOJIN_NO      AS SJKOJIN_NO';
        vSQL := vSQL ||'             ,SJ.SEINENGAPI    AS SJSEINENGAPI';
        vSQL := vSQL ||'             ,SJ.KATAGAKI      AS SJKATAGAKI';
        vSQL := vSQL ||'             ,SJ.ZOKUGARA_MEI  AS SJZOKUGARA_MEI';
        vSQL := vSQL ||'             ,SJ.SETAI_NO      AS SJSETAI_NO';
        vSQL := vSQL ||'             ,SJ.JINKAKU_KBN   AS SJJINKAKU_KBN';
        vSQL := vSQL ||'             ,SH.SHIMEI_KANA   AS SHSHIMEI_KANA';
        vSQL := vSQL ||'             ,SH.SHIMEI_KANJI  AS SHSHIMEI_KANJI';
        vSQL := vSQL ||'             ,SH.KOKUSEKI_CD   AS SHKOKUSEKI_CD';
        vSQL := vSQL ||'             ,SH.YUBIN_NO      AS SHYUBIN_NO';
        vSQL := vSQL ||'             ,SH.CHOMEI        AS SHCHOMEI';
        vSQL := vSQL ||'             ,SH.BANCHI        AS SHBANCHI';
        vSQL := vSQL ||'             ,SH.KOJIN_NO      AS SHKOJIN_NO';
        vSQL := vSQL ||'             ,SH.SEINENGAPI    AS SHSEINENGAPI';
        vSQL := vSQL ||'             ,SH.KATAGAKI      AS SHKATAGAKI';
        vSQL := vSQL ||'             ,SH.ZOKUGARA_MEI  AS SHZOKUGARA_MEI';
        vSQL := vSQL ||'             ,SH.SETAI_NO      AS SHSETAI_NO';
        vSQL := vSQL ||'             ,SH.JINKAKU_KBN   AS SHJINKAKU_KBN';
-- 2025/02/08 JPJYS.GONGYANYAN Update 0.3.000.006:ST_GKB_TMP00045 対応 Start        
        /*vSQL := vSQL ||'             ,GKBTGAKUREIBO.GAKKO_KBN_CD';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.RIREKI_RENBAN';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.HOGOSYA_KOJIN_NO';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.SYOGAKO_CD';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.TYUGAKO_CD';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.KOJIN_NO AS BOKOJIN_NO';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.HOGOSYA_ZOKUGARA1';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.HOGOSYA_ZOKUGARA2';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.HOGOSYA_ZOKUGARA3';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.HOGOSYA_ZOKUGARA4';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.TODOKEDE_BI';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.SEIBETSU';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.GAKUNEN';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANJI';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.HOGOSYA_TSUSHOMEI_KANA';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.SHORIBI AS BOSHORIBI';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.IDO_BI';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.KUIKIGAI_CD';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.YOGOGAKO_CD';
        vSQL := vSQL ||'             ,GKBTGAKUREIBO.GAKUKYU_CD';*/
        vSQL := vSQL ||'             ,GK.GAKKO_KBN_CD';
        vSQL := vSQL ||'             ,GK.RIREKI_RENBAN';
        vSQL := vSQL ||'             ,GK.HOGOSYA_KOJIN_NO';
        vSQL := vSQL ||'             ,GK.SYOGAKO_CD';
        vSQL := vSQL ||'             ,GK.TYUGAKO_CD';
        vSQL := vSQL ||'             ,GK.KOJIN_NO AS BOKOJIN_NO';
        vSQL := vSQL ||'             ,GK.HOGOSYA_ZOKUGARA1';
        vSQL := vSQL ||'             ,GK.HOGOSYA_ZOKUGARA2';
        vSQL := vSQL ||'             ,GK.HOGOSYA_ZOKUGARA3';
        vSQL := vSQL ||'             ,GK.HOGOSYA_ZOKUGARA4';
        vSQL := vSQL ||'             ,GK.TODOKEDE_BI';
        vSQL := vSQL ||'             ,GK.SEIBETSU';
        vSQL := vSQL ||'             ,GK.GAKUNEN';
        vSQL := vSQL ||'             ,GK.HOGOSYA_TSUSHOMEI_KANJI';
        vSQL := vSQL ||'             ,GK.HOGOSYA_TSUSHOMEI_KANA';
        vSQL := vSQL ||'             ,GK.SHORIBI AS BOSHORIBI';
        vSQL := vSQL ||'             ,GK.IDO_BI';
        vSQL := vSQL ||'             ,GK.KUIKIGAI_CD';
        vSQL := vSQL ||'             ,GK.YOGOGAKO_CD';
        vSQL := vSQL ||'             ,GK.GAKUKYU_CD';
-- 2025/02/08 JPJYS.GONGYANYAN Update 0.3.000.006:ST_GKB_TMP00045 対応 END
-- 2025/02/08 JPJYS.GONGYANYAN Update 0.3.000.006:ST_GKB_TMP00045 対応 Start
        --vSQL := vSQL ||'       FROM JIBTIDORUIKEI I,GKBTGAKUREIBO,GABVATENAALL SJ,GABVATENAALL SH';
        --vSQL := vSQL ||'       WHERE I.KOJIN_NO = GKBTGAKUREIBO.KOJIN_NO';
        --vSQL := vSQL ||'       AND GKBTGAKUREIBO.IDOJI_ATENA_RIREKI_RENBAN = SJ.RIREKI_RENBAN ';
        --vSQL := vSQL ||'       AND GKBTGAKUREIBO.HOGOSYA_IDOJI_RIREKI_RENBAN = SH.RIREKI_RENBAN ';
        --vSQL := vSQL ||'       AND GKBTGAKUREIBO.KOJIN_NO = SJ.KOJIN_NO ';
        --vSQL := vSQL ||'       AND GKBTGAKUREIBO.HOGOSYA_KOJIN_NO = SH.KOJIN_NO ';
        vSQL := vSQL ||'              FROM JIBTIDORUIKEI I';
        vSQL := vSQL ||'              LEFT JOIN GKBTGAKUREIBO GK';
        vSQL := vSQL ||'              ON I.KOJIN_NO = GK.KOJIN_NO';
        vSQL := vSQL ||'              AND GK.SAISHIN_KBN = 0';
        vSQL := vSQL ||'              LEFT JOIN GABVATENAALL SJ';
        vSQL := vSQL ||'              ON SJ.KOJIN_NO = NVL(GK.KOJIN_NO,I.KOJIN_NO)';
        vSQL := vSQL ||'              AND SJ.RIREKI_RENBAN = NVL(GK.IDOJI_ATENA_RIREKI_RENBAN,SJ.RIREKI_RENBAN)';
        vSQL := vSQL ||'              LEFT JOIN GABVATENAALL SH';
        vSQL := vSQL ||'              ON SH.KOJIN_NO = NVL(GK.HOGOSYA_KOJIN_NO,NULL)';
        vSQL := vSQL ||'              AND SH.RIREKI_RENBAN = NVL(GK.HOGOSYA_IDOJI_RIREKI_RENBAN,NULL)';
-- 2025/02/6 JPJYS.WUZHENGDONG Update 0.3.000.005:ST_GKB_TMP00045 対応 Start
--        vSQL := vSQL ||'       AND SJ.KOJIN_NO = I.KOJIN_NO';
--        vSQL := vSQL ||'       AND SH.KOJIN_NO = I.KOJIN_NO';
--        vSQL := vSQL ||'       AND GKBTGAKUREIBO.SAISHIN_KBN = 0 ';
-- 2025/02/08 JPJYS.GONGYANYAN Update 0.3.000.006:ST_GKB_TMP00045 対応 END
-- 2025/02/6 JPJYS.WUZHENGDONG Update 0.3.000.005:ST_GKB_TMP00045 対応 End
        vSQL := vSQL ||'         WHERE I.SHORIBI_KEY  BETWEEN ' || R_WKB.JKN_CHUSHUTSU_KAISHI || ' AND '  || R_WKB.JKN_CHUSHUTSU_SHURYO || '';
        vSQL := vSQL ||'         AND I.IDO_JIYU IN (' || VIDO_JIYU ||')';
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
IF NSEINENGAPI_KAISHI <> 0 AND NSEINENGAPI_SHURYO <> 0 AND N_CHUSHUTSU_KAISHI = 0 AND N_CHUSHUTSU_SHURYO = 0 THEN
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応   
        vSQL := vSQL ||'         AND (EXISTS (SELECT G.KOJIN_NO';
        vSQL := vSQL ||'                        FROM GKBTGAKUREIBO G ,GABVATENAALL J2';
        vSQL := vSQL ||'                       WHERE G.KOJIN_NO = I.KOJIN_NO';
        vSQL := vSQL ||'                         AND G.KOJIN_NO = J2.KOJIN_NO';
        vSQL := vSQL ||'                         AND J2.SEINENGAPI BETWEEN ' || NSEINENGAPI_KAISHI || ' AND '|| NSEINENGAPI_SHURYO || '';
        vSQL := vSQL ||'                         AND G.GAKUNEN BETWEEN 0 AND 9';
        vSQL := vSQL ||'                         AND G.SAISHIN_KBN = 0 ';
        --vSQL := vSQL ||'                         AND G.SAKUJO_FLG = 0)';
        vSQL := vSQL ||'                         AND G.SAKUJO_FLG = 0))';
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応        
END IF;         
IF  NSEINENGAPI_KAISHI <> 0 AND NSEINENGAPI_SHURYO <> 0 AND N_CHUSHUTSU_KAISHI <> 0 AND N_CHUSHUTSU_SHURYO <> 0 THEN          
        --vSQL := vSQL ||'         OR EXISTS (SELECT J.KOJIN_NO';
        vSQL := vSQL ||'         AND (EXISTS (SELECT J.KOJIN_NO';
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応   
        vSQL := vSQL ||'                       FROM GABVATENAALL J';
        vSQL := vSQL ||'                      WHERE J.KOJIN_NO = I.KOJIN_NO';
        vSQL := vSQL ||'                        AND J.SEINENGAPI BETWEEN ' || NSEINENGAPI_KAISHI || ' AND ' || NSEINENGAPI_SHURYO || '';
        --vSQL := vSQL ||'                        AND I.SHORIBI_KEY BETWEEN ' || N_CHUSHUTSU_KAISHI || ' AND ' || N_CHUSHUTSU_SHURYO || ')';
        vSQL := vSQL ||'                        AND I.SHORIBI_KEY BETWEEN ' || N_CHUSHUTSU_KAISHI || ' AND ' || N_CHUSHUTSU_SHURYO || '))';        
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
END IF;  
IF  NSEINENGAPI_KAISHI = 0 AND NSEINENGAPI_SHURYO = 0 AND N_CHUSHUTSU_KAISHI  <> 0 AND N_CHUSHUTSU_SHURYO <> 0 THEN    
        --vSQL := vSQL ||'         OR EXISTS (SELECT G.KOJIN_NO';
        vSQL := vSQL ||'         AND (EXISTS (SELECT G.KOJIN_NO';     
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応   
        vSQL := vSQL ||'                      FROM GKBTGAKUREIBO G,GABVATENAALL H2';
        vSQL := vSQL ||'                     WHERE G.KOJIN_NO = I.KOJIN_NO';
        vSQL := vSQL ||'                       AND G.KOJIN_NO = H2.KOJIN_NO';
        vSQL := vSQL ||'                       AND I.SHORIBI_KEY BETWEEN ' || N_CHUSHUTSU_KAISHI || ' AND ' || N_CHUSHUTSU_SHURYO || '';
        vSQL := vSQL ||'                       AND G.SAISHIN_KBN = 0 ';
        vSQL := vSQL ||'                       AND G.SAKUJO_FLG = 0))';
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応          
END IF;
-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応  
        vSQL := vSQL ||'          ORDER BY I.SHORIBI,I.IDO_JIYU';

-- 2024/06/12 ZCZL.wangyunhan Add end
    --BEGIN

      w_IRTN := c_IRETOK;
      w_JIDO_KOJIN_NO        := 0;
      w_IDO_JIYU := NULL;
      

-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
      --異動累計TBL取得件数
       --IF i_FLG = 0 THEN
--           FOR CR_IDORK IN C_IDORK( R_WKB.JKN_CHUSHUTSU_KAISHI, R_WKB.JKN_CHUSHUTSU_SHURYO, NSEINENGAPI_KAISHI, NSEINENGAPI_SHURYO  )  LOOP
       OPEN cCURSOR FOR vSQL;
          BEGIN
          LOOP
              FETCH cCURSOR INTO CR_IDORK;
              EXIT WHEN cCURSOR%NOTFOUND;   
-- 2024/06/12 ZCZL.wangyunhan Update end 
            --初期化
            PROCWK_CLEAR(R_WKB);
            --住記情報を取得しワーク変数にセット
            FOR CR_ATENAALL IN C_ATENAALL(CR_IDORK.KOJIN_NO,
                                          CR_IDORK.SHORIBI_KEY,
                                          CR_IDORK.SHORI_JIKAN_KEY,
                                          CR_IDORK.SHORI_KBN_KEY,
                                          CR_IDORK.ZENBU_ICHIBU_KEY,
                                          CR_IDORK.SHOKUINKOJIN_NO_KEY ) LOOP
                                      
               --基礎情報をワーク変数にセット
               w_IRTN := FUNCSET_EAV_ATENA( R_WKB, CR_ATENAALL, i_FLG );
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
--児童生徒基本情報取得
-- 2025/09/29 JIP.Makishima Update 1.0.107.000:GKB_QA20860_住記異動者一覧表の氏名等を最新情報で表示するよう対応
--        JD_IRTN := GAAPK0030.FGETATENA2(CR_IDORK.KOJIN_NO,'GKB',g_nTIME,JDRATENA_REC,JDRSOFU_REC);
        JD_IRTN := GAAPK0030.FGETATENA2(CR_IDORK.KOJIN_NO,'GKB',g_nDAY,JDRATENA_REC,JDRSOFU_REC);
   BEGIN
        SELECT GK.HOGOSYA_KOJIN_NO,GK.HOGOSYA_ZOKUGARA1,GK.HOGOSYA_ZOKUGARA2,GK.HOGOSYA_ZOKUGARA3,GK.HOGOSYA_ZOKUGARA4
        INTO GKHOGOSHA_ATENANO,GKZOKUGARA1,GKZOKUGARA2,GKZOKUGARA3,GKZOKUGARA4
        FROM GKBTGAKUREIBO GK
        WHERE
             GK.KOJIN_NO = CR_IDORK.KOJIN_NO
        AND  GK.SAISHIN_KBN = 0
        AND  GK.SAKUJO_FLG = 0    
        AND  GK.RIREKI_RENBAN = (
                 SELECT MAX(RIREKI_RENBAN)
                 FROM GKBTGAKUREIBO
                 WHERE KOJIN_NO = GK.KOJIN_NO
                 AND   SAISHIN_KBN = 0
                 AND   SAKUJO_FLG = 0);
       EXCEPTION
           WHEN NO_DATA_FOUND THEN          
               GKHOGOSHA_ATENANO:= NULL;
               GKZOKUGARA1:= NULL;
               GKZOKUGARA2:= NULL;
               GKZOKUGARA3:= NULL;
               GKZOKUGARA4:= NULL;                      
       END;                                      
        I_RTN := GKAFKKKMGET(NVL(CR_IDORK.SJKOKUSEKI_CD,JDRATENA_REC.KOKUSEKI_CD),oKOKUSEKI,oJIDO_KOKUSEKI,oKOKUMEI_ALPHABET);        
        R_WKB.JIDO_KOKUSEKI         := oJIDO_KOKUSEKI;                  --児童生徒国籍
        --R_WKB.IDOSHA_SHIMEI_KANA    := CR_IDORK.SJSHIMEI_KANA;                --異動者氏名かな
        R_WKB.IDOSHA_SHIMEI_KANA    := NVL(CR_IDORK.SJSHIMEI_KANA,JDRATENA_REC.SHIMEI_KANA);                --異動者氏名かな
-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応 
-- 2025/02/08 JPJYS.GONGYANYAN Update 0.3.000.006:ST_GKB_TMP00045 対応　START
       -- R_WKB.SHIMEI_KANJI          := CR_IDORK.SJSHIMEI_KANJI;
-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応  
        --R_WKB.IDOSHA_SHIMEI_KANJI   := CR_IDORK.SJSHIMEI_KANJI;                --異動者氏名漢字          
        R_WKB.IDOSHA_SHIMEI_KANJI   := NVL(CR_IDORK.SJSHIMEI_KANJI,JDRATENA_REC.SHIMEI_KANJI);               --異動者氏名漢字
-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応 
-- 2025/02/08 JPJYS.GONGYANYAN Update 0.3.000.006:ST_GKB_TMP00045 対応　END
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
        /*R_WKB.IDOSHA_SEINENGAPI     := CR_IDORK.SJSEINENGAPI;                  --異動者生年月日                   
        R_WKB.ZOKUGARA              := CR_IDORK.SJZOKUGARA_MEI;                 --続柄名*/
        R_WKB.IDOSHA_SEINENGAPI     := NVL(CR_IDORK.SJSEINENGAPI,JDRATENA_REC.SEINENGAPI);                  --異動者生年月日                   
        R_WKB.ZOKUGARA              := NVL(CR_IDORK.SJZOKUGARA_MEI,JDRATENA_REC.ZOKUGARAMEI);                 --続柄名
-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
        R_WKB.TODOKEDEBI            := CR_IDORK.TODOKEDE_BI;                 --届出年月日
        --学年
          IF CR_IDORK.BOKOJIN_NO IS NOT NULL THEN
             -- 学校等コード(小学校)
             R_WKB.GAKU_NEN := GKAFKGKNGTEQ(CR_IDORK.GAKUNEN);
          ELSE 
             I_NENDOMATSU_BI := (KKAPK0020.FDAYNENDO(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')), 0) + 1) * 10000 + 401;
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応             
             --I_NENDOMATSU_NENREI := KKAPK0020.FAgeGet(TO_CHAR(CR_IDORK.SJSEINENGAPI), TO_CHAR(I_NENDOMATSU_BI));
             I_NENDOMATSU_NENREI := KKAPK0020.FAgeGet(TO_CHAR(NVL(CR_IDORK.SJSEINENGAPI,JDRATENA_REC.SEINENGAPI)), TO_CHAR(I_NENDOMATSU_BI));
-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応 
             --学年コード
             oGAKUCD := I_NENDOMATSU_NENREI -6;
             IF I_NENDOMATSU_NENREI <= 12 THEN 
                I_GAKKO_KBN := 1;
             END IF;
             IF I_NENDOMATSU_NENREI >= 13 AND I_NENDOMATSU_NENREI <= 15 THEN 
                I_GAKKO_KBN := 2;
             END IF;
             --小学校
             IF I_GAKKO_KBN = 1 THEN 
               --小学校文部科学省学校コード
               BEGIN
-- 2025/01/14 JPJYS.YANGXIHAN UPDATE 0.3.000.004:学区マスタ関連修正方針対応 STR         
--               SELECT MGAKKO_CD INTO oMGAKKO_CD FROM GKBTSHOGAKKO WHERE SYOGAKO_CD = GKBFKGKCDGET(1,CR_IDORK.BOKOJIN_NO,999);
                 SELECT MGAKKO_CD INTO oMGAKKO_CD FROM GKBTSHOGAKKO WHERE SYOGAKO_CD = CR_IDORK.SYOGAKO_CD;
-- 2025/01/14 JPJYS.YANGXIHAN UPDATE 0.3.000.004:学区マスタ関連修正方針対応 END        
               EXCEPTION
               WHEN OTHERS THEN
                 oMGAKKO_CD := NULL;
               END;
               IF SUBSTR(oMGAKKO_CD,1,2) = 'C2' THEN
                  SELECT GIMUKYOIKU_GAKUNENMEI INTO R_WKB.GAKU_NEN FROM GKBTGAKUNEN WHERE GAKUNEN_CD = oGAKUCD;
               END IF;
             --中学校
             ELSIF I_GAKKO_KBN = 2 THEN 
               --中学校文部科学省学校コード
               BEGIN
-- 2025/01/14 JPJYS.YANGXIHAN UPDATE 0.3.000.004:学区マスタ関連修正方針対応 STR
--               SELECT MGAKKO_CD INTO oMGAKKO_CD FROM GKBTCHUGAKKO WHERE TYUGAKO_CD = GKBFKGKCDGET(2,CR_IDORK.BOKOJIN_NO,999);
                 SELECT MGAKKO_CD INTO oMGAKKO_CD FROM GKBTCHUGAKKO WHERE TYUGAKO_CD = CR_IDORK.TYUGAKO_CD;
-- 2025/01/14 JPJYS.YANGXIHAN UPDATE 0.3.000.004:学区マスタ関連修正方針対応 END         
               EXCEPTION
               WHEN OTHERS THEN
                 oMGAKKO_CD := NULL;
               END;
               IF SUBSTR(oMGAKKO_CD,1,2) = 'C2' THEN
                  BEGIN
                  SELECT GIMUKYOIKU_GAKUNENMEI INTO R_WKB.GAKU_NEN FROM GKBTGAKUNEN WHERE GAKUNEN_CD = oGAKUCD;
                  EXCEPTION
                  WHEN OTHERS THEN
                    R_WKB.GAKU_NEN := NULL;
                  END;
               END IF;
             ELSE 
               --学年取得(学年マスタの学年名を取得してセットする)。
               BEGIN
                 SELECT GAKUNENMEI INTO R_WKB.GAKU_NEN FROM GKBTGAKUNEN WHERE GAKUNEN_CD = oGAKUCD;
               EXCEPTION
               WHEN OTHERS THEN
                 R_WKB.GAKU_NEN := NULL;
               END;
             END IF;
          END IF;
-- 2025/01/14 JPJYS.YANGXIHAN UPDATE 0.3.000.004:学区マスタ関連修正方針対応 STR      
--      IF GKBFKGKKUGET(CR_ATENAALL.KOJIN_NO,CR_ATENAALL.RIREKI_RENBAN,SHOGAKKOKUCD,SHOGAKKOKUMEI,TYUGAKOKUCD,TYUGAKOKUMEI) = 0 THEN 
--      　　R_WKB.SHITEI_SHOGAKKOKU := SHOGAKKOKUMEI;          --指定小学校区
--      　　R_WKB.SHITEI_TYUGAKOKU  := TYUGAKOKUMEI;           --指定中学校区
          R_WKB.SHITEI_SHOGAKKOKU := CR_IDORK.SYOGAKO_CD;          --指定小学校区
          R_WKB.SHITEI_TYUGAKOKU  := CR_IDORK.TYUGAKO_CD;           --指定中学校区          
--      END IF;
-- 2025/01/14 JPJYS.YANGXIHAN UPDATE 0.3.000.004:学区マスタ関連修正方針対応 END    
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
         HG_IRTN  := GKBPK00010.FHOGOSHA(g_nDAY,CR_IDORK.KOJIN_NO,HOGOSHA_ATENANO);    
         --w_IRTN := GAAPK0030.FGETATENA2(CR_IDORK.SHKOJIN_NO,'GKB',g_nTIME,RATENA_REC,RSOFU_REC);
-- 2025/09/29 JIP.Makishima Update 1.0.107.000:GKB_QA20860_住記異動者一覧表の氏名等を最新情報で表示するよう対応
--         w_IRTN := GAAPK0030.FGETATENA2(COALESCE(CR_IDORK.SHKOJIN_NO,GKHOGOSHA_ATENANO,HOGOSHA_ATENANO),'GKB',g_nTIME,RATENA_REC,RSOFU_REC);
         w_IRTN := GAAPK0030.FGETATENA2(COALESCE(CR_IDORK.SHKOJIN_NO,GKHOGOSHA_ATENANO,HOGOSHA_ATENANO),'GKB',g_nDAY,RATENA_REC,RSOFU_REC);
-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
         IF w_IRTN = 0 THEN 
           R_WKB.HOGOSHA_SHIMEI_KANA   := RATENA_REC.SHIMEI_KANA;         --保護者氏名カナ
           R_WKB.HOGOSHA_SHIMEI_KANJI  := RATENA_REC.SHIMEI_KANJI;        --保護者氏名
         END IF;
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応              
         --I_RTN := GKAFKKKMGET(CR_IDORK.SJKOKUSEKI_CD,oKOKUSEKI,oHOGOSHA_KOKUSEKI,oKOKUMEI_ALPHABET);
         I_RTN := GKAFKKKMGET(NVL(CR_IDORK.SJKOKUSEKI_CD,RATENA_REC.KOKUSEKI_CD),oKOKUSEKI,oHOGOSHA_KOKUSEKI,oKOKUMEI_ALPHABET);  
         R_WKB.HOGOSHA_KOKUSEKI         := oHOGOSHA_KOKUSEKI;                  --保護者国籍
          --続柄コードに応じて続柄名称を取得する
         /*IF CR_ATENAALL.ZOKUGARA_CD1 IS NULL AND CR_ATENAALL.ZOKUGARA_CD2 IS NULL AND CR_ATENAALL.ZOKUGARA_CD3 IS NULL AND CR_ATENAALL.ZOKUGARA_CD4 IS NULL THEN
            R_WKB.JIDO_ZOKUGARAMEI    := NULL;
         ELSE
           w_IRTN := GKBFKZKGMGET(2,CR_ATENAALL.ZOKUGARA_CD1,CR_ATENAALL.ZOKUGARA_CD2,CR_ATENAALL.ZOKUGARA_CD3,CR_ATENAALL.ZOKUGARA_CD4,oZOKUGARA_MEI,oERRMSG);
           IF w_IRTN = 0 THEN
               R_WKB.JIDO_ZOKUGARAMEI    := oZOKUGARA_MEI;               --児童生徒との関係
            ELSE
               R_WKB.JIDO_ZOKUGARAMEI    := NULL;                        --児童生徒との関係
            END IF;
         END IF;*/
         IF GKZOKUGARA1 IS NOT NULL AND GKZOKUGARA2 IS NOT NULL AND GKZOKUGARA3 IS NOT NULL AND GKZOKUGARA4 IS NOT NULL THEN
              w_IRTN := GKBFKZKGMGET(2,GKZOKUGARA1,GKZOKUGARA2,GKZOKUGARA3,GKZOKUGARA4,oZOKUGARA_MEI,oERRMSG);
          IF w_IRTN = 0 THEN
               R_WKB.JIDO_ZOKUGARAMEI    := oZOKUGARA_MEI;               --児童生徒との関係
            ELSE
               R_WKB.JIDO_ZOKUGARAMEI    := NULL;                        --児童生徒との関係
            END IF;
         END IF;   
            
         IF R_WKB.JIDO_ZOKUGARAMEI IS NULL THEN 
            IF RATENA_REC.ZOKUGARACD1 IS NULL AND RATENA_REC.ZOKUGARACD2 IS NULL AND RATENA_REC.ZOKUGARACD3 IS NULL AND RATENA_REC.ZOKUGARACD4 IS NULL THEN
               R_WKB.JIDO_ZOKUGARAMEI    := NULL;
            ELSE
               w_IRTN := GKBFKZKGMGET(2,RATENA_REC.ZOKUGARACD1,RATENA_REC.ZOKUGARACD2,RATENA_REC.ZOKUGARACD3,RATENA_REC.ZOKUGARACD4,oZOKUGARA_MEI,oERRMSG);
              IF w_IRTN = 0 THEN
                 R_WKB.JIDO_ZOKUGARAMEI    := oZOKUGARA_MEI;               --児童生徒との関係
              ELSE
                 R_WKB.JIDO_ZOKUGARAMEI    := NULL;                        --児童生徒との関係
              END IF;
            END IF;
         END IF;       
         --住所編集取得、児童生徒住所を取得する       
         --R_WKB.JIDO_JUSHO  := GAAPK0010.FADDRESSEDIT(1,NULL,CR_IDORK.SJCHOMEI,CR_IDORK.SJBANCHI,CR_IDORK.SJKATAGAKI,NULL);  --児童生徒住所
         R_WKB.JIDO_JUSHO  := GAAPK0010.FADDRESSEDIT(1,NULL,NVL(CR_IDORK.SJCHOMEI,JDRATENA_REC.CHOMEI),NVL(CR_IDORK.SJBANCHI,JDRATENA_REC.BANCHI),NVL(CR_IDORK.SJKATAGAKI,JDRATENA_REC.KATAGAKI),NULL);  --児童生徒住所
-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応         
         --学校名
         IF CR_IDORK.BOKOJIN_NO IS NOT NULL THEN 
           --小学校名
           IF CR_IDORK.SYOGAKO_CD IS NOT NULL THEN 
              R_WKB.GAKKO_MEI := GKAFKGKOGTEQ(CR_IDORK.GAKKO_KBN_CD,CR_IDORK.SYOGAKO_CD);  
           END IF;
           --中学校名
--  2025/10/24 CTC.GL UPDATE START 1.0.203.000:GKB_QA21357対応
           --IF CR_IDORK.TYUGAKO_CD IS NOT NULL THEN 
           IF CR_IDORK.TYUGAKO_CD IS NOT NULL AND CR_IDORK.TYUGAKO_CD != 0 THEN 
--  2025/10/24 CTC.GL UPDATE END
              R_WKB.GAKKO_MEI := GKAFKGKOGTEQ(CR_IDORK.GAKKO_KBN_CD,CR_IDORK.TYUGAKO_CD);
           END IF;
         ELSE  
           --小学校名
           IF I_GAKKO_KBN = 1 THEN 
             BEGIN
               SELECT SYOGAKOMEI INTO R_WKB.GAKKO_MEI FROM GKBTSHOGAKKO WHERE SYOGAKO_CD = GKBFKGKCDGET(1,CR_IDORK.BOKOJIN_NO,999);
             EXCEPTION
             WHEN OTHERS THEN
               R_WKB.GAKKO_MEI := NULL;
             END;
           END IF;
           --中学校名
           IF I_GAKKO_KBN = 2 THEN 
             BEGIN
               SELECT TYUGAKOMEI INTO R_WKB.GAKKO_MEI FROM GKBTCHUGAKKO WHERE TYUGAKO_CD = GKBFKGKCDGET(2,CR_IDORK.BOKOJIN_NO,999);
             EXCEPTION
             WHEN OTHERS THEN
               R_WKB.GAKKO_MEI := NULL;
             END;
           END IF;
         END IF ;
-- 2025/06/16 CTC.LIUJUNHAO ADD START 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応
IF JDRATENA_REC.NUSHI_SHIMEI_KANJI IS NOT NULL THEN
         R_WKB.NUSHI_SHIMEI_KANJI := NVL(R_WKB.NUSHI_SHIMEI_KANJI,JDRATENA_REC.NUSHI_SHIMEI_KANJI) ;
ELSE
         R_WKB.NUSHI_SHIMEI_KANJI := NULL;           
END IF;                               
IF R_WKB.NUSHI_SHIMEI_KANJI IS NULL THEN
BEGIN
        SELECT AT.NUSHI_SHIMEI_KANJI
        INTO HOGOSHA_SETAINUSI
        FROM GABVATENAALL AT
        WHERE
             AT.SETAI_NO = JDRATENA_REC.SETAI_NO
        AND  NUSHI_SHIMEI_KANJI IS NOT NULL   
        AND  AT.RIREKI_RENBAN = (
                 SELECT MAX(RIREKI_RENBAN)
                 FROM GABVATENAALL
                 WHERE SETAI_NO = AT.SETAI_NO)
-- 2025/09/29 JIP.Makishima Update 1.0.107.000:GKB_QA20860_住記異動者一覧表の氏名等を最新情報で表示するよう対応
--                 ORDER BY IDO_BI
                 ORDER BY IDO_BI DESC
                 FETCH FIRST 1 ROW ONLY;
       EXCEPTION
           WHEN NO_DATA_FOUND THEN          
               HOGOSHA_SETAINUSI:= NULL;
           WHEN OTHERS THEN          
               HOGOSHA_SETAINUSI:= NULL;       
       END;
       IF HOGOSHA_SETAINUSI IS NOT NULL THEN
         R_WKB.NUSHI_SHIMEI_KANJI :=HOGOSHA_SETAINUSI;
       ELSIF R_WKB.JIDO_ZOKUGARAMEI='世帯主' THEN
         R_WKB.NUSHI_SHIMEI_KANJI:= R_WKB.HOGOSHA_SHIMEI_KANJI;
       ELSE
         R_WKB.NUSHI_SHIMEI_KANJI:= R_WKB.NUSHI_SHIMEI_KANJI;  
       END IF;  
END IF;

-- 2025/06/16 CTC.LIUJUNHAO ADD END 1.0.009.000:GKB_QA16777_氏名表示されず、生年月日範囲不正対応         
-- 2024/06/12 ZCZL.wangyunhan Add end
                 --頁、連番のカウントアップを行う
                 NKENSU := NKENSU +1;
                 --各ワーク項目の変換等を行なう
                 w_IRTN := FUNCSET_DATA_WK( i_FLG );
-- 2024/06/12 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
            END LOOP;
          END LOOP;
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD START 0.3.000.001:8月1日認識合わせの横展開
         --グローバル変数.対象者件数
         g_nROWNUM := NKENSU;
         g_nINDEX := g_nINDEX + 1;
         g_oKENSU_LIST.EXTEND(1);
         g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_nROWNUM,'入力　'||'住記異動者一覧対象件数',1);
--  2024/09/04 ZCZL.LIUCHANGQUAN ADD END
       --END IF;
        CLOSE cCURSOR;
     END;
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発  
--        g_nINDEX := g_oKENSU_LIST.COUNT;
        -- 3-1.学級一括設定ワークの件数カウント・セット
--        VFROM := '住記異動者一覧対象件数';
        -- 3-1-1.変数.件数カウント := 件数カウント計算（GKBFKTBLCNT）を使用して件数をカウントする。
--        NKENSU := GKBFKTBLCNT('GKBWIDOICHIRAN',NULL);
        -- 3-1-2.共通関数（FUNC_CHECK_KENSUU）を使用し、INPUTデータを件数表データテーブルにセットする。
--        IF NOT FUNC_CHECK_KENSUU(VFROM) THEN
--          g_nINDEX := g_nINDEX + 1;
--          g_oKENSU_LIST.EXTEND(1);
--          g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NKENSU,'入力 ' || VFROM,1);
--        END IF;
-- 2024/06/12 ZCZL.wangyunhan Update end 
      --世帯員を含めた異動者を取得
--       IF i_FLG = 1 THEN
--           FOR CR_IDORK IN C_IDORK_SETAI( R_WKB.JKN_CHUSHUTSU_KAISHI, R_WKB.JKN_CHUSHUTSU_SHURYO, NSEINENGAPI_KAISHI, NSEINENGAPI_SHURYO ) LOOP
-- 
            --住記情報を取得しワーク変数にセット
--             FOR CR_ATENAALL IN C_ATENAALL(CR_IDORK.KOJIN_NO,
--                                           CR_IDORK.SHORIBI_KEY,
--                                           CR_IDORK.SHORI_JIKAN_KEY,
--                                           CR_IDORK.SHORI_KBN_KEY,
--                                           CR_IDORK.ZENBU_ICHIBU_KEY,
--                                           CR_IDORK.SHOKUINKOJIN_NO_KEY ) LOOP
-- 
               --基礎情報をワーク変数にセット
--                w_IRTN := FUNCSET_EAV_ATENA( R_WKB, CR_ATENAALL, i_FLG );
               --児童宛名番号・氏名かな・漢字・性別・生年月日　再セット
--                R_WKB.JIDO_KOJIN_NO          := CR_IDORK.JIDO_KOJIN_NO;
--                R_WKB.SEINENGAPI             := CR_IDORK.JIDO_SEINENGAPI;
--                IF CR_IDORK.JIDO_KOJIN_NO <> w_JIDO_KOJIN_NO THEN
--                  R_WKB.SHIMEI_KANA            := CR_IDORK.JIDO_SHIMEI_KANA;
--                  R_WKB.SHIMEI_KANJI           := CR_IDORK.JIDO_SHIMEI_KANJI;
--                  R_WKB.WAREKI_SEINENGAPI      := CR_IDORK.JIDO_WAREKI_SEINENGAPI;
--                  R_WKB.ZOKUGARA_MEI           := CR_IDORK.JIDO_ZOKUGARA_MEI;
--                  NSEIBETSU                    := CR_IDORK.JIDO_SEIBETSU;
--                ELSE
--                  R_WKB.SHIMEI_KANA            := '';
--                  R_WKB.SHIMEI_KANJI           := '';
--                  R_WKB.WAREKI_SEINENGAPI      := '';
--                  R_WKB.ZOKUGARA_MEI           := '';
--                  R_WKB.SEIBETSU               := '';
--                  NSEIBETSU                    := 0;
--                END IF;
-- 
               --各ワーク項目の変換等を行なう
--                w_IRTN := FUNCSET_DATA_WK( i_FLG );
--             END LOOP;
--             w_JIDO_KOJIN_NO       := R_WKB.JIDO_KOJIN_NO;   --児童宛名番号
--             w_IDO_JIYU            := R_WKB.IDO_JIYU;
--           END LOOP;
--       END IF;
-- 2024/06/12 ZCZL.wangyunhan Delete end
      RETURN w_IRTN;

    EXCEPTION
      WHEN OTHERS THEN
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNCGET_DATA', 1, SQLCODE, SQLERRM, SUBSTR(VERRMSG || ':FUNCGET_DATA', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        IF cCURSOR%ISOPEN THEN
          CLOSE cCURSOR;
        END IF;
        RETURN c_IERR;
    END FUNCGET_DATA;
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
        o_tITEM          A_CONS_PRM;
        eEXCEPTION       EXCEPTION;
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発 
        VFROM  NVARCHAR2(250);
        NKENSU NUMBER := 0;  -- 変数.件数カウント
-- 2024/06/12 ZCZL.wangyunhan Delete end
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);

        -- バッチ条件チェック
        I_RTN := FUNCSET_JOKEN();
        IF I_RTN <> c_IRETOK THEN
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR(VERRMSG || ':FUNCSET_JOKEN', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        END IF;

        --条件基準日の取得
        SELECT TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) INTO R_WKB.JKN_KIJUN_BI FROM DUAL;

        --県名,首長名等取得
        I_RTN := KKAPK0030.FKYOTU( R_WKB.JKN_KIJUN_BI,               --基準日
                                   o_IUSER_ID,
                                   o_IJICHI_CD,
                                   o_IGAPPEI_BI,
                                   o_IUSER_KBN,
                                   o_VGUNSHIMEI,
                                   VKADOSHI,                         --稼働市町村名
                                   R_WKB.SHICHOSON_CHOMEI,           --市町村長名
                                   R_WKB.TODOFUKEN_MEI,              --都道府県名
                                   R_WKB.SHICHOSON_NINSHOBUN,        --市町村長認証文
                                   R_WKB.SHICHOSON_YUBINNO,          --市町村郵便番号
                                   R_WKB.SHICHOSON_SHOZAICHI,        --市町村所在地
                                   R_WKB.SHICHOSON_TEL);             --市町村代表電話

        --ログ出力
        IF B_RTN THEN
          NULL;
        ELSE
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', SUBSTR(VERRMSG || ':FKYOTU', 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
          RAISE eEXCEPTION;
        END IF;

        V_KIJUNBI                   := HIZUKE(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),3);
        V_SAKUSEIBI                 := HIZUKE(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),3);
        V_KAISHIBI                  := HIZUKE(R_WKB.JKN_CHUSHUTSU_KAISHI,3);
        V_SHURYOBI                  := HIZUKE(R_WKB.JKN_CHUSHUTSU_SHURYO,3);
        V_SEINENGAPI_KAISHIBI       := HIZUKE(R_WKB.JKN_SEINENGAPI_KAISHI,3); 
        V_SEINENGAPI_SHURYOBI       := HIZUKE(R_WKB.JKN_SEINENGAPI_SHURYO,3);
        --職員番号
        R_WKB.SYS_SHOKUINKOJIN_NO   := g_sTANTOCODE;
        --システム条件取得
        I_RTN := KKAPK0030.FCTGetR('JIB','SYSTEM_JOKEN','0030',1,o_tITEM);
        IF I_RTN = 0 THEN
            NSYSJKN := o_tITEM(1);
        END IF;
        --ワーク初期化
        DELETE GKBWIDOICHIRAN;
        COMMIT;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        I_RTN := KKAPK3000.FTRUNCATE('GKBWIDOICHIRAN', VSQLERRM);
        IF I_RTN = c_ERR THEN
          -- エラーで帰ってきた場合
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', SUBSTR(VSQLERRM, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        END IF;
        -- 制御パラメータ取得を取得する
        o_tITEM :=  A_CONS_PRM();
-- 2025/05/08 CTC.GL UPDATE Start 1.0.003.000:GKB_QA13680対応
        --I_RTN := KKAPK0030.FCTGetR('GKB', 'IDOJIYU', '0000', 1, o_tITEM);
        I_RTN := KKAPK0030.FCTGetR('GKB', 'IDOJIYU', '0000', 0, o_tITEM);
-- 2025/05/08 CTC.GL UPDATE End
          VIDO_JIYU := '';
          FOR i IN 1..o_tITEM.COUNT LOOP
              IF i = 1 THEN
                IF o_tITEM(i) IS NOT NULL THEN
                 VIDO_JIYU := o_tITEM(i) ;
                END IF;
              ELSE
                IF o_tITEM(i) IS NOT NULL THEN
                VIDO_JIYU := VIDO_JIYU || ',' || o_tITEM(i);
                END IF;
             END IF;
           END LOOP;
-- 2024/06/12 ZCZL.wangyunhan Add end 
        --対象データの抽出とワークへセット
        R_WKB.RENBAN := 0;
        IF I_RTN = c_IRETOK THEN
          I_RTN := FUNCGET_DATA(NSETAI_IDOKBN);
        END IF;
        COMMIT;
        --中間TBL書き込み件数取得
        SELECT COUNT(*)
          INTO NIDOCNT
          FROM GKBWIDOICHIRAN;
        --件数ログ出力
        VSQLERRM := '中間マスタに処理データ' || NIDOCNT || '件を更新しました。';
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', SUBSTR(VSQLERRM, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        --件数ログ出力
        VSQLERRM := VLOGKBN || '分の異動データ' || NIDOCNT || '件を更新しました。';
        B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', SUBSTR(VSQLERRM, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        --初期化
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発  
--         DELETE FROM GKBWL280R001 WHERE WSNUM = g_sWSNUM AND BATCHKBN = c_BATCH;
--  2024/09/04 ZCZL.LIUCHANGQUAN DEL 0.3.000.001:8月1日認識合わせの横展開
--        DELETE FROM GKBWDB002001 WHERE RECUPDWSNUM = g_sWSNUM AND RECUPDKBNCODE = 2;
       
-- 2024/06/12 ZCZL.wangyunhan Update end  
        ----------------------------------------------
        --バッチ処理ワークCSV作成ストアド呼び出し
        ----------------------------------------------
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発 
--         GKBSBIDOIRCSV( g_nJOBNUM, g_sTANTOCODE, ' ', ' ', NSORT_KBN ,g_sWSNUM, g_nTIME, g_rJSTP.Orderbyclause, c_BATCH);
         --bRTN := FUNC_SET_JIDO_WK_CSVFILE;
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        --ＣＳＶファイル作成
        I_RTN := FUNC_CSV_CREATE();
        IF I_RTN = c_ERR THEN
          -- エラーで帰ってきた場合
          B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', SUBSTR(VSQLERRM, 1, 256), g_sTANTOCODE, g_sWSNUM, 1);
        END IF;
--  2024/09/04 ZCZL.LIUCHANGQUAN DELETE 0.3.000.001:8月1日認識合わせの横展開
--         g_oKENSU_LIST(1).CNT := GKBFKTBLCNT('GKBWDB002001',NULL);
-- 2024/06/12 ZCZL.wangyunhan Add end 
 -- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発  
--        g_nINDEX := g_oKENSU_LIST.COUNT;
        -- 3-1.学級一括設定ワークの件数カウント・セット
--        VFROM := '住記異動者一覧ＣＳＶ';  
        -- 3-1-1.変数.件数カウント := 件数カウント計算（GKBFKTBLCNT）を使用して件数をカウントする。
--        NKENSU := GKBFKTBLCNT('GKBWDB002001',NULL);
        -- 3-1-2.共通関数（FUNC_CHECK_KENSUU）を使用し、INPUTデータを件数表データテーブルにセットする。
--        IF NOT FUNC_CHECK_KENSUU(VFROM) THEN
--          g_nINDEX := g_nINDEX + 1;
--          g_oKENSU_LIST.EXTEND(1);
--          g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(NKENSU,'出力 ' || VFROM,1);
--        END IF;
-- 2024/06/12 ZCZL.wangyunhan Update end 
        -- 帳票出力CSVの作成
-- 2024/06/12 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--         bRTN := FUNC_B11CSV('GKBWL280R001');
--  2024/09/04 ZCZL.LIUCHANGQUAN DELETE 0.3.000.001:8月1日認識合わせの横展開
--         bRTN := FUNC_B11CSV('GKBWDB002001');
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
END GKBPB00200;
/