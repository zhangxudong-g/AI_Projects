CREATE OR REPLACE PACKAGE BODY GKBPB00160
--1.0.404.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : 学齢簿
--  機能概要      : 学齢簿および学齢名簿を作成する
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
--------------------------------------------------------
--  変更履歴
--  2024/04/22 ZCZL.WUCAO UPDATE 0.2.000.001:512_GKB_00027対応
--  2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No187
--  2024/08/12 ZCZL.YANGXINYU UPDATE 0.3.000.002:受入検証対応No182_2回目
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.003:8月1日認識合わせの横展開
--  2024/10/17 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更：IT_GKB_00205、IT_GKB_00206対応
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.005:IT_GKB_00429対応横展開
--  2024/11/06 ZCZL.ZHANGLEI UPDATE 0.3.000.006:IT_GKB_00474対応
--  2024/11/11 ZCZL.WANGYUNING UPDATE 0.3.000.007:IT_GKB_00524対応
--  2024/11/14 ZCZL.WANGMING UPDATE 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.009:学校コードリスト仕様変更IT_GKB_00090の対応
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応
--  2025/05/19 ZCZL.WANGMING UPDATE 1.0.004.000: GKB_QA14775(保守2208)_卒業年月日入力なしの対応
--  2025/06/04 CTC.LIUJUNHAO UPDATE 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
--  2025/10/24 CTC.GYY UPDATE 1.0.203.000:GKB_QA22525対応
--  2025/12/19 CTC.XW UPDATE 1.0.404.000:GKB_QA23714対応
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

    --実行回数とステップ数
    g_nSTEP_MAX NUMBER := 0;
    g_nSTEP_INDEX NUMBER := 0;

    --パラメータ変数
    VMSG  NVARCHAR2(4000);
    IRTN  PLS_INTEGER;
    ICHK1 PLS_INTEGER;
    ICHK2 PLS_INTEGER;
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
    ICHK3 PLS_INTEGER;
    ICHK4 PLS_INTEGER;
    ICHK5 PLS_INTEGER;
    ICHK6 PLS_INTEGER;
    g_GAKUNENNPO_INDEXNO    NUMBER;                     --学齢簿_インデックス番号
    g_GAKUNEIMEI_INDEXNO    NUMBER;                     --学齢名簿_インデックス番号
    g_GAKUNENNPOSEIGYO      NVARCHAR2(1000);            --学齢簿_出力制御
    g_GAKUNEIMEISEIGYO      NVARCHAR2(1000);            --学齢名簿_出力制御
    rGKBTTSUCHISHOKANRITY   GKBTTSUCHISHOKANRI%ROWTYPE; --通知書管理情報
    nCOUNT                  PLS_INTEGER;                --抽出件数
    g_nINDEX                NUMBER := 0;
--  2024/10/17 ZCZL.WANGMING ADD START 0.3.000.004:仕様変更：IT_GKB_00206対応
    g_cOUNTKUREIBO          NUMBER := 0;                --学齢簿件数
    g_cOUNTKUREIBOMEI       NUMBER := 0;                --学齢名簿件数
--  2024/10/17 ZCZL.WANGMING ADD END
-- 2024/06/04 ZCZL.wangyunhan Add end
------------------------------------------------------------------------------
--  カーソル定義
------------------------------------------------------------------------------
 TYPE TYPECURSOR  IS REF CURSOR;
 
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
    
    -- 正常メッセージの値
    c_VOK_MSG01    CONSTANT  NVARCHAR2(256) := '学齢簿作成処理が正常終了しました。';
    -- エラーメッセージの値
    c_VERR_MSG01   CONSTANT  NVARCHAR2(256) := '学齢簿作成処理が異常終了しました。';
    -- 児童生徒ワーク
    c_VTABLE       CONSTANT  NVARCHAR2(128) := 'GKBWJIDOSHINNYUGAKU';
    c_VGTABLE      CONSTANT  NVARCHAR2(128) := 'GKBWGAKUREIBO';
    c_VLTABLE      CONSTANT  NVARCHAR2(128) := 'GKBTGAKUNENLNK_TEST';
    -- １頁の最大行数
    c_IMAXROWS     CONSTANT  PLS_INTEGER := 15;
    
------------------------------------------------------------------------------
--  変数宣言
------------------------------------------------------------------------------
    ISAKUSEIBI               PLS_INTEGER;
    RG                       GKBTGAKUREIBO%ROWTYPE;
    RA                       GABTATENAKIHON%ROWTYPE;
    RB                       GABTATENAKIHON%ROWTYPE;
    RC                       GABTSOFUSAKI%ROWTYPE;
    RASO                     GABTSOFUSAKI%ROWTYPE;
    IGAKO_CD                 PLS_INTEGER;
    IMRIREKI_RENBAN          PLS_INTEGER;
    VGAKOMEI                 NVARCHAR2(60);  
    VSEINENGAPI              NVARCHAR2(11);
    VSEIBETSU                NVARCHAR2(2);
-- 2024/06/04 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
--     VSETAI_NO                NVARCHAR2(7);
    VSETAI_NO                NVARCHAR2(15);
    VGYOSEIKU_MEI            NVARCHAR2(20);
    VHAN_MEI                 NVARCHAR2(20);
--  2024/10/31 ZCZL.WANGMING UPDATE 0.3.000.005:IT_GKB_00429対応横展開
--    VSANTEIDANTAI_MEI        NVARCHAR2(20);
    VSANTEIDANTAI_MEI        GKBWGAKUREIBO.SANTEIDANTAIMEI%TYPE;
    VHYOUJINENDO             NVARCHAR2(10);
    VSASKUSEIBI              NVARCHAR2(30);
    VHOGOSHA_SHIMEI_JODAN    NVARCHAR2(30);
    VHOGOSHA_SHIMEI_GEDAN    NVARCHAR2(30);
    VJUSHO_JODAN             NVARCHAR2(30);
    VJUSHO_GEDAN             NVARCHAR2(30);
    VCNT                     NVARCHAR2(6);
    VZOKUGARAMEI1            NVARCHAR2(30);
    VZOKUGARAMEI2            NVARCHAR2(30);
    VTYUGAKOMEI              NVARCHAR2(60);  
    VGAKUNENMEI              NVARCHAR2(20);
    NGAKUNENSEI              NUMBER;
    VGAKUNENSEI              NVARCHAR2(20);
    IKAISISEINENGAPI         PLS_INTEGER;
    VKAISISEINENGAPI         NVARCHAR2(14);
    ISHURYOSEINENGAPI        PLS_INTEGER;
    VSHURYOSEINENGAPI        NVARCHAR2(14);
    IHOGOSHA_ZOKUGARA1       PLS_INTEGER;
    IJUMIN_NARU_JIYU         PLS_INTEGER;
    IJUMIN_NARU              PLS_INTEGER;
    IKAISIGAKUNEN            PLS_INTEGER;
    VKAISIGAKUNEN            NVARCHAR2(2);
    ISHURYOGAKUNEN           PLS_INTEGER;
    VSHURYOGAKUNEN           NVARCHAR2(2);
    ISHOGAKO_CD              PLS_INTEGER;
    VSHOGAKOMEI              NVARCHAR2(60);  
    ISYOGAKO_NYUGAKU_BI      PLS_INTEGER;
    VSYOGAKO_NYUGAKU_BI      NVARCHAR2(22);
    VSYOGAKO_TENNYUGAKU_BI   NVARCHAR2(22);  
    VSYOGAKO_TENGAKU_BI      NVARCHAR2(22);
    VSYOGAKO_SOTSUGYO_BI     NVARCHAR2(22);
    ITYUGAKO_CD              PLS_INTEGER;
    VTYUGAKO_NYUGAKU_BI      NVARCHAR2(22);
    VTYUGAKO_TENNYUGAKU_BI   NVARCHAR2(22);  
    VTYUGAKO_TENGAKU_BI      NVARCHAR2(22);
    VTYUGAKO_SOTSUGYO_BI     NVARCHAR2(22);
    VKUIKIGAIMEI             NVARCHAR2(60);  
    VKUIKIGAI_NYUGAKU_BI     NVARCHAR2(22);
    VKUIKIGAI_TENNYUGAKU_BI  NVARCHAR2(22);  
    VKUIKIGAI_TENTAIGAKU_BI  NVARCHAR2(22);
    VKUIKIGAI_TENGAKU_BI     NVARCHAR2(22);  
    VKUIKIGAI_TAIGAKU_BI     NVARCHAR2(22);  
    VKUIKIGAI_SOTSUGYO_BI    NVARCHAR2(22);
    VYOGOGAKOMEI             NVARCHAR2(60);  
    VYOGOGAKO_NYUGAKU_BI     NVARCHAR2(22);
    VYOGOGAKO_TENNYUGAKU_BI  NVARCHAR2(22);  
    VYOGOGAKO_TENTAIGAKU_BI  NVARCHAR2(22);
    VYOGOGAKO_TENGAKU_BI     NVARCHAR2(22);  
    VYOGOGAKO_TAIGAKU_BI     NVARCHAR2(22);  
    VYOGOGAKO_SOTSUGYO_BI    NVARCHAR2(22);
    VYUYO_KYOKA_BI           NVARCHAR2(22);
    VYUYO_KAISI_BI           NVARCHAR2(22);
    VYUYO_SYURYO_BI          NVARCHAR2(22);
    VYUYO_FUKUGAKU_BI        NVARCHAR2(22);
    VMENJO_KYOKA_BI          NVARCHAR2(22);
    VMENJO_FUKUGAKU_BI       NVARCHAR2(22);
    VIDO_BI1                 NVARCHAR2(22);
    VIDO_BI2                 NVARCHAR2(22);
    VIDO_BI3                 NVARCHAR2(22);
    VIDO_BI4                 NVARCHAR2(22);
    VIDO_BI5                 NVARCHAR2(22);
    VIDO_BI6                 NVARCHAR2(22);
    VIDO_BI7                 NVARCHAR2(22);
    VIDO_BI8                 NVARCHAR2(22);
    VIDO_BI9                 NVARCHAR2(22);
    VIDO_BI10                NVARCHAR2(22);
    VTOKUSOKU_BI1            NVARCHAR2(22);
    VTOKUSOKU_BI2            NVARCHAR2(22);
    VTOKUSOKU_BI3            NVARCHAR2(22);
    VTOKUSOKU_BI4            NVARCHAR2(22);
    VTOKUSOKU_BI5            NVARCHAR2(22);
--  2024/08/05 ZCZL.YANGXINYU ADD START 0.3.000.001:受入検証対応No182
    VTOKUSOKU_BI6            NVARCHAR2(22);
    VTOKUSOKU_BI7            NVARCHAR2(22);
    VTOKUSOKU_BI8            NVARCHAR2(22);
    VTOKUSOKU_BI9            NVARCHAR2(22);
    VTOKUSOKU_BI10            NVARCHAR2(22);
--  2024/08/05 ZCZL.YANGXINYU ADD END

    INYUGAKU_NENDO           PLS_INTEGER;
    NGAKUNENNENDO            PLS_INTEGER;
    VGAKUNENNENDO            NVARCHAR2(10);
    IKAIPEJI_KBN             PLS_INTEGER;
    ICNTM                    BINARY_INTEGER :=0; -- 学齢名簿レコードカウント
    VUSERMEI                 NVARCHAR2(40);      --市町村名
    IMAX                     BINARY_INTEGER;
    VRENBAN                  NVARCHAR2(1);       -- 帳票連番使用有無
    NRENBAN                  NUMBER;             -- 帳票連番使用有無
    VHAKOBI                  NVARCHAR2(16);      -- 発行日
    NHAKOBI                  NUMBER;             -- 発行日
    NSAKUSEIBI               NUMBER;             -- 基準日の取得
--  2024/11/14 ZCZL.WANGYUNING UPDATE 0.3.000.009:学校コードリスト仕様変更IT_GKB_00090の対応
    --VSYOGAKOCD               NVARCHAR2(100);     -- 小学校コード
    --VTYUGAKOCD               NVARCHAR2(100);     -- 中学校コード
    --VKUIKIGAICD              NVARCHAR2(100);     -- 区域外学校コード
    --VYOGOGAKOCD              NVARCHAR2(100);     -- 盲聾養護学校コード
    VSYOGAKOCD               NVARCHAR2(3000);     -- 小学校コード
    VTYUGAKOCD               NVARCHAR2(3000);     -- 中学校コード
    VKUIKIGAICD              NVARCHAR2(3000);     -- 区域外学校コード
    VYOGOGAKOCD              NVARCHAR2(3000);     -- 盲聾養護学校コード
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--     VNINIBIT                 NVARCHAR2(10);      -- 任意ビット項目
    VSOTSUGYOYMD             NVARCHAR2(100);      --卒業年月日
    VIDOBISTARTYMD           NVARCHAR2(100);     -- 異動日　範囲（開始）
    VIDOBIENDYMD             NVARCHAR2(100);     -- 異動日　範囲（終了）
    VSYORIBISTARTYMD         NVARCHAR2(100);     -- 処理日　範囲（開始）
    VSYORIBIENDYMD           NVARCHAR2(100);     -- 処理日　範囲（終了）
-- 2024/06/04 ZCZL.wangyunhan Update end
    NCHOHYO_NO2              NVARCHAR2(6);       -- ZZZZ9表示連番
    IGAKKO_CD2               NVARCHAR2(5);       -- ZZZZ9学校コード
    RA1                      GABTATENAKIHON%ROWTYPE;
    RA2                      GABTSOFUSAKI%ROWTYPE;
    TYPE GAKUREIBO_REC IS RECORD
    (
-- 2024/06/12 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--     KOJIN_NO            NUMBER,
--     RIREKI_RENBAN       NUMBER,
--     KOJIN_RIREKI_RENBAN NUMBER,
--     GAKUNEN             NUMBER,
--     NINIBIT1            NUMBER,
--     HOGOSYA_KOJIN_NO    NUMBER
     KOJIN_NO                       NUMBER,      --学齢簿.宛名番号
     RIREKI_RENBAN_EDA              NUMBER,      --学齢簿.児童生徒_個人履歴番号枝番
     S_TAIGAKU_BI                   NUMBER,      --就学履歴.小学校_退学年月日
     S_TAIGAKU_GAKUNEN              NUMBER,      --就学履歴.小学校_退学学年
     T_TAIGAKU_BI                   NUMBER,      --就学履歴.中学校_退学年月日
     T_TAIGAKU_GAKUNEN              NUMBER,      --就学履歴.中学校_退学学年
     KUIKIGAI_S_CD                  NUMBER,      --就学履歴.区域外就学_小学校コード
     KUIKIGAI_S_NYUGAKU_BI          NUMBER,      --就学履歴.区域外就学_小学校_入学年月日
     KUIKIGAI_S_TENNYU_BI           NUMBER,      --就学履歴.区域外就学_小学校_転入学年月日
     KUIKIGAI_S_TENNYU_GAKUNEN      NUMBER,      --就学履歴.区域外就学_小学校_転入学学年
     KUIKIGAI_S_TENGAKU_BI          NUMBER,      --就学履歴.区域外就学_小学校_転学年月日
     KUIKIGAI_S_TENGAKU_GAKUNEN     NUMBER,      --就学履歴.区域外就学_小学校_転学学年
     KUIKIGAI_S_TAIGAKU_BI          NUMBER,      --就学履歴.区域外就学_小学校_退学年月日
     KUIKIGAI_S_TAIGAKU_GAKUNEN     NUMBER,      --就学履歴.区域外就学_小学校_退学学年
     KUIKIGAI_S_SOTSUGYO_BI         NUMBER,      --就学履歴.区域外就学_小学校_卒業年月日
     KUIKIGAI_T_CD                  NUMBER,      --就学履歴.区域外就学_中学校コード
     KUIKIGAI_T_NYUGAKU_BI          NUMBER,      --就学履歴.区域外就学_中学校_入学年月日
     KUIKIGAI_T_TENNYU_BI           NUMBER,      --就学履歴.区域外就学_中学校_転入学年月日
     KUIKIGAI_T_TENNYU_GAKUNEN      NUMBER,      --就学履歴.区域外就学_中学校_転入学学年
     KUIKIGAI_T_TENGAKU_BI          NUMBER,      --就学履歴.区域外就学_中学校_転学年月日
     KUIKIGAI_T_TENGAKU_GAKUNEN     NUMBER,      --就学履歴.区域外就学_中学校_転学学年
     KUIKIGAI_T_TAIGAKU_BI          NUMBER,      --就学履歴.区域外就学_中学校_退学年月日
     KUIKIGAI_T_TAIGAKU_GAKUNEN     NUMBER,      --就学履歴.区域外就学_中学校_退学学年
     KUIKIGAI_T_SOTSUGYO_BI         NUMBER,      --就学履歴.区域外就学_中学校_卒業年月日
     SHIEN_S_CD                     NUMBER,      --就学履歴.特別支援学校_小学校コード
     SHIEN_S_NYUGAKU_BI             NUMBER,      --就学履歴.特別支援学校_小学校部_入学年月日
     SHIEN_S_TENNYU_BI              NUMBER,      --就学履歴.特別支援学校_小学校部_転入学年月日
     SHIEN_S_TENNYU_GAKUNEN         NUMBER,      --就学履歴.特別支援学校_小学校部_転入学学年
     SHIEN_S_TENGAKU_BI             NUMBER,      --就学履歴.特別支援学校_小学校部_転学年月日
     SHIEN_S_TENGAKU_GAKUNEN        NUMBER,      --就学履歴.特別支援学校_小学校部_転学学年
     SHIEN_S_TAIGAKU_BI             NUMBER,      --就学履歴.特別支援学校_小学校部_退学年月日
     SHIEN_S_TAIGAKU_GAKUNEN        NUMBER,      --就学履歴.特別支援学校_小学校部_退学学年
     SHIEN_S_SOTSUGYO_BI            NUMBER,      --就学履歴.特別支援学校_小学校部_卒業年月日
     SHIEN_T_CD                     NUMBER,      --就学履歴.特別支援学校_中学校コード
     SHIEN_T_NYUGAKU_BI             NUMBER,      --就学履歴.特別支援学校_中学校部_入学年月日
     SHIEN_T_TENNYU_BI              NUMBER,      --就学履歴.特別支援学校_中学校部_転入学年月日
     SHIEN_T_TENNYU_GAKUNEN         NUMBER,      --就学履歴.特別支援学校_中学校部_転入学学年
     SHIEN_T_TENGAKU_BI             NUMBER,      --就学履歴.特別支援学校_中学校部_転学年月日
     SHIEN_T_TENGAKU_GAKUNEN        NUMBER,      --就学履歴.特別支援学校_中学校部_転学学年
     SHIEN_T_TAIGAKU_BI             NUMBER,      --就学履歴.特別支援学校_中学校部_退学年月日
     SHIEN_T_TAIGAKU_GAKUNEN        NUMBER,      --就学履歴.特別支援学校_中学校部_退学学年
     SHIEN_T_SOTSUGYO_BI            NUMBER,      --就学履歴.特別支援学校_中学校部_卒業年月日
     RIREKI_RENBAN                  NUMBER,      --学齢簿.履歴連番
     GAKUNEN                        NUMBER,      --学齢簿.学年
     HOGOSYA_KOJIN_NO               NUMBER       --学齢簿.保護者宛名番号
-- 2024/06/12 ZCZL.wangyunhan Update end
    );
    GAKUREIBO_RECC        GAKUREIBO_REC;
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
   --支援措置対象者情報
   TYPE GACTKANRI_REC IS RECORD
    (
    SETAIYOKUSHIKBN           NUMBER,
    TOROKU_GYOMU              NVARCHAR2(3),
    SHIENSOCHIKBN             NUMBER,
    SHIENSOCHISHURYOKBN       NUMBER,
    SHIENSOCHIKAISHIBI        NUMBER,
    SHIENSOCHISHURYOBI        NUMBER,
    TAISHOSHAKBN              NUMBER,
    KARISHIENSOCHIKAISHIBI    NUMBER,
    KARISHIENSOCHISHURYOBI    NUMBER,
    SHIENSOCHIKAIJOBI         NUMBER
    );   
   GACTKANRI_RECC        GACTKANRI_REC;
   VSETAIYOKUSHIKBN         A_CONS_PRM := A_CONS_PRM();   --世帯抑止区分   
   VTOROKU_GYOMU            A_CONS_PRM := A_CONS_PRM();   --登録業務    
   VSHIENSOCHIKBN           A_CONS_PRM := A_CONS_PRM();   --支援措置区分   
   VSHIENSOCHISHURYOKBN     A_CONS_PRM := A_CONS_PRM();   --支援措置終了区分  
   VSHIENSOCHIKAISHIBI      A_CONS_PRM := A_CONS_PRM();  --支援措置開始年月日 
   VSHIENSOCHISHURYOBI      A_CONS_PRM := A_CONS_PRM(); --支援措置終了年月日 
   VTAISHOSHAKBN            A_CONS_PRM := A_CONS_PRM();   --支援措置対象者区分 
   VKARISHIENSOCHIKAISHIBI  A_CONS_PRM := A_CONS_PRM();   --仮支援措置開始年月日 
   VKARISHIENSOCHISHURYOBI  A_CONS_PRM := A_CONS_PRM();   --仮支援措置終了年月日 
   VSHIENSOCHIKAIJOBI       A_CONS_PRM := A_CONS_PRM();   --措置解除日 
-- 2024/06/04 ZCZL.wangyunhan Add end 

    -- 変数
    ACONSPRM_KYOUIKU      A_CONS_PRM;
    ACONSPRM_RENBAN       A_CONS_PRM;
    ACONSPRM_SHIMEI       A_CONS_PRM;
    NLENGTH               NUMBER;
    TEMPNO                NUMBER;
    NSHORIBI              NUMBER;
    IRTN_RENBAN           NUMBER;
    IRTN_KYOUIKU          NUMBER;
    IRTN_SHIMEI          NUMBER;
    TYPE MTHIZUKE_REC IS RECORD(
      GAKO_KBN     BINARY_INTEGER, --学校区分
      GAKO_CD      PLS_INTEGER,    --学校コード
      IN_D         PLS_INTEGER,    --入学年月日OR転入学年月日
      OUT_D        PLS_INTEGER     --転学年月日OR退学年月日OR卒業年月日
    );
    TYPE MHIZUKE_TYPE IS TABLE OF MTHIZUKE_REC INDEX BY BINARY_INTEGER;
    -- 関数用戻り値変数（外部関数からの戻り値をセット）
    BRTN            BOOLEAN;
    B_RTN           BOOLEAN;
    I_RTN           PLS_INTEGER;
    -- 処理条件（画面からの引数）
    VNENDO          NVARCHAR2(15);      -- 対象年度
    VGAKUNEN        NVARCHAR2(15);      -- 学年
    VSYURYOGAKUNEN  NVARCHAR2(15);      -- 終了学年
    -- 処理条件の取得用変数
    TYPE MTJOKEN_TYPE IS TABLE OF NVARCHAR2(15) INDEX BY BINARY_INTEGER;  -- 処理条件の値の配列宣言
    o_MJYOUKEN      MTJOKEN_TYPE;
    -- 取得したデータのワーク領域
    TYPE MTJIDO_TYPE IS TABLE OF GKBWJIDOSHINNYUGAKU%ROWTYPE INDEX BY BINARY_INTEGER;
    MJIDO_WORK MTJIDO_TYPE;
    TYPE MTGAKUREIBO_TYPE IS TABLE OF GKBWGAKUREIBO%ROWTYPE INDEX BY BINARY_INTEGER;
    MGAKUREIBO_WORK MTGAKUREIBO_TYPE;
    TYPE MTGAKUNEN_LNK_TYPE IS TABLE OF GKBTGAKUNEN%ROWTYPE INDEX BY BINARY_INTEGER;
    MGAKUNEN_LNK_WORK MTGAKUNEN_LNK_TYPE;
    TYPE MTNENDO_TYPE IS TABLE OF GKBWGAKUREIBO%ROWTYPE INDEX BY BINARY_INTEGER;
    MNENDO_WORK MTNENDO_TYPE;
    -- ソート条件のレコード
    TYPE MTORDER_REC IS RECORD
    (
        ID      NUMBER(2),              -- 番号（基本的には配列値に１加算された値）
        NAME    NVARCHAR2(100),         -- 項目名
        P_NAME  NVARCHAR2(100),         -- 改頁項目名
        C_NAME  NVARCHAR2(100),         -- 改頁　学年　項目名
        BIKO    NVARCHAR2(100)          -- 備考（日本語名）
    );
    -- ソート条件のワーク領域
    TYPE MTORDER_TYPE IS TABLE OF MTORDER_REC INDEX BY BINARY_INTEGER;
    MORDER_WORK MTORDER_TYPE;
    -- 名簿作成のレコード
    TYPE MTMEIBO_REC IS RECORD
    (
    NENDO              NVARCHAR2(12),
    NENDO1             NVARCHAR2(12),
    NENDO2             NVARCHAR2(12),
    NENDO3             NVARCHAR2(12),
    NENDO4             NVARCHAR2(12),
    NENDO5             NVARCHAR2(12),
    NENDO6             NVARCHAR2(12),
    NENDO7             NVARCHAR2(12),
    NENDO8             NVARCHAR2(12),
    NENDO9             NVARCHAR2(12),
    KAIPEJI_CD         NVARCHAR2(500),
    KAIPEJI            NVARCHAR2(500),
    RENBAN             NVARCHAR2(10),
    JIDO_SHIMEI_KANJI  NVARCHAR2(100),
    JIDO_SHIMEI_KANA   NVARCHAR2(100)
    , JIDO_HONMYO_KANJI  NVARCHAR2(100)
    , JIDO_HONMYO_KANA   NVARCHAR2(100)
    ,CD1                 NVARCHAR2(10),
    MEISHO1              NVARCHAR2(30),
    CD2                  NVARCHAR2(10),
    MEISHO2              NVARCHAR2(30),
    CD3                  NVARCHAR2(10),
    MEISHO3              NVARCHAR2(30),
    CHOHYO_NO            NVARCHAR2(30),
    KIJUN_BI             NVARCHAR2(30),
    JIDO_JINKAKU_KBN     NVARCHAR2(500),
    KOJIN_NO             NVARCHAR2(500)
    ,JINKAKU_KBN         GKBWGAKUREIBO.JINKAKU_KBN%TYPE
    );
    MMEIBO_REC         MTMEIBO_REC;
    
    -- 帳票ソート条件の取得用変数
    TYPE MTSORT_TYPE IS TABLE OF NUMBER(2) INDEX BY BINARY_INTEGER;  -- ソート条件の値の配列宣言
    o_NBREAK         NUMBER(2);
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
    -- 共通情報取得用変数(KKAPK0030.FKYOTU)
    o_IUSER_ID                  PLS_INTEGER; -- 市町村コード
    o_ITEKIYO_BI                PLS_INTEGER; -- 適用日
    o_IGAPPEI_BI                PLS_INTEGER; -- 合併日付
    o_IJICHI_CD                 PLS_INTEGER; -- 自治コード
    o_IUSER_KBN                 PLS_INTEGER; -- 市町村区分
    o_VKENMEI                   NVARCHAR2(30); -- 県名
    o_VGUNSHIMEI                NVARCHAR2(30); -- 郡市名
    o_VUSERMEI                  NVARCHAR2(40); -- 市町村名
    o_VSHUCHOMEI                NVARCHAR2(40); -- 首長名
    o_VSHUCHONINSHOBUN          NVARCHAR2(100); -- 首長認証文
    o_BSHUCHOKOIN               BLOB; -- 首長公印
    o_VSHUNYUMEI                NVARCHAR2(40); -- 収入役名
    o_VSHUNYUNINSHOBUN          NVARCHAR2(100); -- 収入役認証文
    o_BSHUNYUKOIN               BLOB; -- 収入役公印
    o_VYUBIN_NO                 NVARCHAR2(10); -- 郵便番号
    o_VSHOZAICHI                NVARCHAR2(200); -- 所在地
    o_VTEL_NO                   NVARCHAR2(20); -- 代表電話番号
    o_VFAX_NO                   NVARCHAR2(20); -- 代表FAX
    o_VMAIL_ADS                 NVARCHAR2(100); -- メールアドレス
    o_VURL                      NVARCHAR2(100); -- URL
    o_ISHUCHODAIRI_KAISHI_BI    PLS_INTEGER; -- 首長職務代理開始日
    o_ISHUCHODAIRI_SHURYO_BI    PLS_INTEGER; -- 首長職務代理終了日
    o_VSHUCHODAIRISHA           NVARCHAR2(40); -- 首長職務代理者
    o_VSHUCHODAIRIRIYU          NVARCHAR2(100); -- 首長職務代理理由
    o_VSHUCHODAIRININSHOBUN     NVARCHAR2(100); -- 首長職務代理認証文
    o_BSHUCHODAIRIKOIN          BLOB; -- 首長職務代理公印
    o_ISHUNYUDAIRI_KAISHI_BI    PLS_INTEGER; -- 収入役職務代理開始日
    o_ISHUNYUDAIRI_SHURYO_BI    PLS_INTEGER; -- 収入役職務代理終了日
    o_VSHUNYUDAIRISHA           NVARCHAR2(40); -- 収入役職務代理者
    o_VSHUNYUDAIRIRIYU          NVARCHAR2(100); -- 収入役職務代理理由
    o_VSHUNYUDAIRININSHOBUN     NVARCHAR2(100); -- 収入役職務代理認証文
    o_BSHUNYUDAIRIKOIN          BLOB; -- 入役職務代理公印
    o_VNINSHUCHOMEI             NVARCHAR2(40); -- 認証用首長名
    o_VNINSHUCHONINSHOBUN       NVARCHAR2(100); -- 認証用首長認証文
    o_BNINSHOSHUCHOKOIN         BLOB; -- 認証用首長公印
    o_VNINSHOSHUNYUMEI          NVARCHAR2(40); -- 認証用収入役名
    o_VNINSHOSHUNYUNINSHOBUN    NVARCHAR2(100); -- 認証用収入役認証文
    o_BNINSHOSHUNYUKOIN         BLOB; -- 認証用収入役公印
    VSQLERRM         NVARCHAR2(256);    -- 外部関数から返ってくるエラーメッセージ
    VPAGENM          NVARCHAR2(500);    -- 改頁項目名
    VPAGEFD          NVARCHAR2(500);    -- 改頁項目値
    --  処理条件チェック用戻る値
    NSYOGAKOKYOIKUIINKAI_CD       NUMBER(2);  --小学校教育委員会
    NTYUGAKOKYOIKUIINKAI_CD       NUMBER(2);  --中学校教育委員会
    NKUIKIGAIKYOIKUIINKAI_CD      NUMBER(2);  --区域外学校教育委員会
    NYOGOGAKOKYOIKUIINKAI_CD      NUMBER(2);  --養護学校養護教育委員会
    BPRMFLG_001      BOOLEAN;
    BPRMFLG_002      BOOLEAN;
    BPRMFLG_003      BOOLEAN;
    BPRMFLG_004      BOOLEAN;
    o_YMD2           NVARCHAR2(30);
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
    IKIJUN_NENDO     PLS_INTEGER ;  
    ISYS_NENDO       PLS_INTEGER ;  
    --画面から条件
    g_vJYOUKEN1  NVARCHAR2(500);
    g_vJYOUKEN2  NVARCHAR2(500);
    g_vJYOUKEN3  NVARCHAR2(500);
    g_vJYOUKEN4  NVARCHAR2(500);
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.009:学校コードリスト仕様変更IT_GKB_00090の対応
    --g_vJYOUKEN5  NVARCHAR2(500);
    --g_vJYOUKEN6  NVARCHAR2(500);
    --g_vJYOUKEN7  NVARCHAR2(500);
    --g_vJYOUKEN8  NVARCHAR2(500);
    g_vJYOUKEN5  NVARCHAR2(3000);
    g_vJYOUKEN6  NVARCHAR2(3000);
    g_vJYOUKEN7  NVARCHAR2(3000);
    g_vJYOUKEN8  NVARCHAR2(3000);
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--     g_vJYOUKEN9  NVARCHAR2(500);
    g_vJYOUKEN9   NVARCHAR2(500);
    g_vJYOUKEN10  NVARCHAR2(500);
    g_vJYOUKEN11  NVARCHAR2(500);
    g_vJYOUKEN12  NVARCHAR2(500);
    g_vJYOUKEN13  NVARCHAR2(500);
-- 2024/06/04 ZCZL.wangyunhan Add end
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
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
    --  2024/09/09 ZCZL.LIUCHANGQUAN add start 0.3.000.003:8月1日認識合わせの横展開
    --------------------------------------------------------
    --  機能概要      : 日付の変換YYYYMMDD→YYYY/MM/DD
    --  パラメータ    : i_sDATE       日付
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.LIUCHANGQUAN 2024/09/09
    --------------------------------------------------------
    FUNCTION FUNC_CONV_DATE(i_sDATE IN  NVARCHAR2) RETURN NVARCHAR2
    IS
        sDATE_NAIBU                   NVARCHAR2(100);   --ステップ名
    BEGIN
        IF i_sDATE IS NULL OR i_sDATE = '0' THEN
            RETURN NULL;
        END IF;

        IF LENGTH(i_sDATE) <> 8 THEN
            RETURN i_sDATE;
        END IF;
        sDATE_NAIBU := SUBSTR(i_sDATE, 1, 4) || '/' || SUBSTR(i_sDATE, 5, 2) || '/' || SUBSTR(i_sDATE, 7, 2);

        RETURN sDATE_NAIBU;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END FUNC_CONV_DATE;
    --  2024/09/09 ZCZL.LIUCHANGQUAN add end 0.3.000.003:8月1日認識合わせの横展開
    --------------------------------------------------------
    --  機能概要      : バッチ初期処理
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
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
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.009:学校コードリスト仕様変更IT_GKB_00090の対応
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
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応 START
--            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 4, 3));
            nGAKOUCD_TMP := TO_NUMBER(SUBSTR(aGAKOCD(i), 1, 3));
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応 END
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
    --  機能概要      : バッチ処理画面入力値取得
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B01PINIT
        RETURN BOOLEAN
    IS
        v_cmbGakunenStart           DBMS_UTILITY.MAXNAME_ARRAY;
        v_cmbGakunenEnd             DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/10/17 ZCZL.WANGMING DELETE 0.3.000.004:仕様変更：IT_GKB_00205対応
--        v_txtChohyoRenbanShiyoUmu   DBMS_UTILITY.MAXNAME_ARRAY;
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--         v_cmbShogaiCd               DBMS_UTILITY.MAXNAME_ARRAY;
        v_SotsugyoYmd               NVARCHAR2(100);             -- 卒業年月日
        v_IdobiStartYmd             NVARCHAR2(100);             -- 異動日　範囲（開始）
        v_IdobiEndYmd               NVARCHAR2(100);             -- 異動日　範囲（終了）
        v_SyoribiStartYmd           NVARCHAR2(100);             -- 処理日　範囲（開始）
        v_SyoribiEndYmd             NVARCHAR2(100);             -- 処理日　範囲（終了）
 -- 2024/06/04 ZCZL.wangyunhan Update end
--  2024/11/14 ZCZL.WANGYUNING ADD START 0.3.000.009:学校コードリスト仕様変更IT_GKB_00090の対応
        objShogakkoCd              DBMS_UTILITY.MAXNAME_ARRAY;
        objChugakkoCd              DBMS_UTILITY.MAXNAME_ARRAY;
        objKuikigaiGakkoCd         DBMS_UTILITY.MAXNAME_ARRAY;
        objTokubetsuShienGakkoCd   DBMS_UTILITY.MAXNAME_ARRAY;
--  2024/11/23 JPJYS.SONGSHIHAO ADD 0.3.000.011:IT_GKB_00675対応 START
        bRTN                       BOOLEAN;
        sVJYOUKEN05                NVARCHAR2(1000);
        sVJYOUKEN06                NVARCHAR2(1000);
        sVJYOUKEN07                NVARCHAR2(1000);
        sVJYOUKEN08                NVARCHAR2(1000);
--  2024/11/23 JPJYS.SONGSHIHAO ADD 0.3.000.011:IT_GKB_00675対応 END
--  2024/11/14 ZCZL.WANGYUNING ADD END
    BEGIN
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        --バッチ処理条件設定（初期値設定）
        g_vJYOUKEN3  := '1';
        g_vJYOUKEN4  := '';
-- 2024/06/04 ZCZL.wangyunhan Add end
        v_cmbGakunenStart := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGakunenStart');
        g_vJYOUKEN1 := v_cmbGakunenStart(1);                                              -- 開始学年 範囲(開始)
        v_cmbGakunenEnd := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbGakunenEnd');
        g_vJYOUKEN2 := v_cmbGakunenEnd(1);                                                -- 終了学年 範囲(終了)
--  2024/10/17 ZCZL.WANGMING DELETE 0.3.000.004:仕様変更：IT_GKB_00205対応
--        v_txtChohyoRenbanShiyoUmu := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbChohyoRenbanShiyoUmu');
--        g_vJYOUKEN3 := v_txtChohyoRenbanShiyoUmu(1);                                      -- 帳票連番使用有無
        g_vJYOUKEN4 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKijunBi');                       -- 基準日
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.009:学校コードリスト仕様変更IT_GKB_00090の対応
        --g_vJYOUKEN5 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtShogakkoCd');                    -- 小学校コード
        objShogakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtShogakkoCd');
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応 START
--        g_vJYOUKEN5 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShogakkoCd',0, objShogakkoCd);
        sVJYOUKEN05 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtShogakkoCd',0, objShogakkoCd);

        bRTN := FUNC_GET_GAKOCD(sVJYOUKEN05, g_vJYOUKEN5);
        IF NOT bRTN THEN
        RETURN FALSE;
        END IF;
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応 END
        --g_vJYOUKEN6 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtChugakkoCd');                    -- 中学校コード
        objChugakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtChugakkoCd');
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応 START
--        g_vJYOUKEN6 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtChugakkoCd',0, objChugakkoCd);
        sVJYOUKEN06 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtChugakkoCd',0, objChugakkoCd);

        bRTN := FUNC_GET_GAKOCD(sVJYOUKEN06, g_vJYOUKEN6);
        IF NOT bRTN THEN
        RETURN FALSE;
        END IF;
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応 END
        --g_vJYOUKEN7 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtKuikigaiGakkoCd');               -- 区域外学校コード
        objKuikigaiGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtKuikigaiGakkoCd');
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応 START
--        g_vJYOUKEN7 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuikigaiGakkoCd',0, objKuikigaiGakkoCd);
        sVJYOUKEN07 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtKuikigaiGakkoCd',0, objKuikigaiGakkoCd);

        bRTN := FUNC_GET_GAKOCD(sVJYOUKEN07, g_vJYOUKEN7);
        IF NOT bRTN THEN
        RETURN FALSE;
        END IF;
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応 END
        --g_vJYOUKEN8 := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtTokubetsuShienGakkoCd');         -- 特別支援学校コード
        objTokubetsuShienGakkoCd := KKBPK5551.GETPARMARRAYS (g_nJOBNUM, 'txtTokubetsuShienGakkoCd');
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応 START
--        g_vJYOUKEN8 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtTokubetsuShienGakkoCd',0, objTokubetsuShienGakkoCd);
        sVJYOUKEN08 := KKBPK5551.FGETSPRM(g_sGYOUMUCODE,g_sSHORIID,'txtTokubetsuShienGakkoCd',0, objTokubetsuShienGakkoCd);

        bRTN := FUNC_GET_GAKOCD(sVJYOUKEN08, g_vJYOUKEN8);
        IF NOT bRTN THEN
        RETURN FALSE;
        END IF;
--  2024/11/23 JPJYS.SONGSHIHAO UPDATE 0.3.000.011:IT_GKB_00675対応 END
--  2024/11/14 ZCZL.WANGYUNING UPDATE END
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--         v_cmbShogaiCd := KKBPK5551.GETPARMARRAYS(g_nJOBNUM, 'cmbShogaiCd');               
--         g_vJYOUKEN9 := v_cmbShogaiCd(1);                                                  -- 障害コード
         v_SotsugyoYmd := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSotsugyoYmd');                 -- 卒業年月日 
         g_vJYOUKEN9  := KKAPK0020.FDAYEDIT20(v_SotsugyoYmd,0,0);
         v_IdobiStartYmd := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtIdobiStartYmd');
         g_vJYOUKEN10 := KKAPK0020.FDAYEDIT20(v_IdobiStartYmd,0,0);                                              -- 異動日　範囲（開始）
         v_IdobiEndYmd := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtIdobiEndYmd');
         g_vJYOUKEN11 := KKAPK0020.FDAYEDIT20(v_IdobiEndYmd,0,0);                                                -- 異動日　範囲（終了）
         v_SyoribiStartYmd := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSyoribiStartYmd');
         g_vJYOUKEN12 := KKAPK0020.FDAYEDIT20(v_SyoribiStartYmd,0,0);                                            -- 処理日　範囲（開始）
         v_SyoribiEndYmd := KKBPK5551.GETPARMS(g_nJOBNUM, 'txtSyoribiEndYmd');
         g_vJYOUKEN13 := KKAPK0020.FDAYEDIT20(v_SyoribiEndYmd,0,0);                                              -- 異動日　範囲（終了）
-- 2024/06/04 ZCZL.wangyunhan Update end
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
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
    --  機能概要      : 開始学年と終了学年の大小チェック
    --  パラメータ    : i_VGAKUNEN1
    --              i_VGAKUNEN2
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIKAKUCHK(i_VGAKUNEN1 IN NVARCHAR2,
                           i_VGAKUNEN2 IN NVARCHAR2) RETURN NUMBER IS
      IRET     PLS_INTEGER;
      SGAKUNEN PLS_INTEGER;
      EGAKUNEN PLS_INTEGER;

    BEGIN
      IRET     := 0;
      SGAKUNEN := TO_NUMBER(i_VGAKUNEN1);
      EGAKUNEN := TO_NUMBER(i_VGAKUNEN2);
      --開始学年と終了学年の大小チェック
      IF SGAKUNEN > EGAKUNEN THEN
        IRET := 1;
      END IF;
      RETURN(IRET);
    END;
    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 学年チェック
    --  パラメータ    : i_VGAKUNEN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCGAKUNENCHK(i_VGAKUNEN IN NVARCHAR2) RETURN NUMBER IS
      IRET    PLS_INTEGER;
      GAKUNEN PLS_INTEGER;
    BEGIN
      IRET := 0;
      --学年
      BEGIN
        IF i_VGAKUNEN IS NULL THEN
          IRET := 1;
        ELSE
          GAKUNEN := TO_NUMBER(i_VGAKUNEN);
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
    END;
--  2024/10/17 ZCZL.WANGMING DELETE START 0.3.000.004:仕様変更：IT_GKB_00205対応
--    ----------------------------------------------------------------------------------------------------
--    --  機能概要      : 帳票連番使用有無チェック
--    --  パラメータ    : i_IRENBAN
--    --  モジュール区分: 内部関数
--    --  戻り値        : 正常 TRUE,その他 FALSE
--    --  バージョン    : Ver 0.2.000.000
--    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
--    ----------------------------------------------------------------------------------------------------
--    FUNCTION FUNCRENBANCHK(i_IRENBAN IN NVARCHAR2) RETURN NUMBER IS
--      IRET PLS_INTEGER;
--      IRENBAN PLS_INTEGER;
--    BEGIN
--      IRET := 0;
--
--      BEGIN
--        IRENBAN := TO_NUMBER(i_IRENBAN);
--        IF i_IRENBAN IS NOT NULL THEN
--          IF NOT i_IRENBAN IN (0, 1) THEN
--            IRET := 1;
--          END IF;
--        END IF;
--      EXCEPTION
--        WHEN OTHERS THEN
--          IRET := 1;
--      END;
--
--      RETURN(IRET);
--    END;
--  2024/10/17 ZCZL.WANGMING DELETE END
    ----------------------------------------------------------------------------------------------------
    --  機能概要      : 学級コードチェック
    --  パラメータ    : i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCGAKYUCHK(i_GAKYU IN VARCHAR) RETURN NUMBER IS
      IRET    PLS_INTEGER;
      GAKYU PLS_INTEGER;
    BEGIN
      IRET := 0;
      --学級コード
      BEGIN
        IF i_GAKYU IS NULL THEN
          IRET := 0;
        ELSIF LENGTH(i_GAKYU) = 1 THEN
          GAKYU := TO_NUMBER(i_GAKYU);
        ELSE
          IRET := 1;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IRET := 1;
      END;

      IF IRET = 0 THEN
        IF GAKYU > 9 THEN
          IRET := 1;
        END IF;
      END IF;

      RETURN(IRET);
    END;
    ----------------------------------------------------------------------------------------------------
    --  機能概要      : （発行日）日付チェック
    --  パラメータ    : i_VHIZUKE
    --               i_IRENBAN
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    ----------------------------------------------------------------------------------------------------
    FUNCTION FUNCHIZUKECHK( i_VHIZUKE IN NVARCHAR2, i_IRENBAN IN NVARCHAR2) RETURN NUMBER IS
    IRET PLS_INTEGER ;
    BRET BOOLEAN ;
    TEMP_DATE DATE;
    BEGIN
      IRET := 0 ;
      --日付
      BEGIN
        IF i_IRENBAN = '1' AND i_VHIZUKE IS NOT NULL THEN
           IF LENGTH(i_VHIZUKE) <> 7 THEN
              IRET := 1;
           ELSE
              IWAREKIHIDUKEIO  := TO_NUMBER(i_VHIZUKE);
              ISEIREKIHIDUKEIO := 0;
           END IF;
        END IF;


      IF IRET = 0 AND LENGTH(IWAREKIHIDUKEIO) = 7 AND i_IRENBAN = '1'  THEN
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
    --  機能概要      : 画面入力値チェック
    --  パラメータ    : i_nJOBNUM      ジョブナンバー
    --                  o_vRESULT      処理結果
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------
    PROCEDURE PBPRMCHK(i_nJOBNUM IN  NUMBER,
                       o_vRESULT OUT NVARCHAR2)
    IS
        bRTN                          BOOLEAN;  --戻り値
--  2024/11/14 ZCZL.WANGMING ADD 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
        ICHK1                        NUMBER := 0;
        
    BEGIN
        VMSG  := '';
        IRTN  := 0;
        ICHK1 := 0;
        ICHK2 := 0;
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        ICHK3 := 0;
        ICHK4 := 0;
        ICHK5 := 0;
        ICHK6 := 0;
-- 2024/06/04 ZCZL.wangyunhan Add end  
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
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
--  2024/10/17 ZCZL.WANGMING UPDATE START 0.3.000.004:仕様変更：IT_GKB_00205対応
--        IF g_vJYOUKEN1 IS NULL AND g_vJYOUKEN2 IS NULL AND g_vJYOUKEN3 IS NULL AND g_vJYOUKEN4 IS NULL AND g_vJYOUKEN5 IS NULL AND 
        IF g_vJYOUKEN1 IS NULL AND g_vJYOUKEN2 IS NULL AND g_vJYOUKEN4 IS NULL AND g_vJYOUKEN5 IS NULL AND 
           g_vJYOUKEN6 IS NULL AND g_vJYOUKEN7 IS NULL AND g_vJYOUKEN8 IS NULL AND g_vJYOUKEN9 IS NULL AND g_vJYOUKEN10 IS NULL AND 
           g_vJYOUKEN11 IS NULL AND g_vJYOUKEN12 IS NULL AND g_vJYOUKEN13 IS NULL THEN 
           VMSG  := g_sGYOUMUCODE || ',99999,処理条件を設定してください。,;';
        END IF;
-- 2024/06/12 ZCZL.wangyunhan Add end 
        --条件１のチェック
        IRTN := FUNCGAKUNENCHK(g_vJYOUKEN1);
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--         IF IRTN <> 0 THEN
--  2025/10/24 CTC.GYY UPDATE 1.0.203.000:GKB_QA22525対応 START
        --IF IRTN <> 0 OR g_vJYOUKEN1 NOT IN ('1','2','3','4','5','6','7','8','9','99') THEN
        IF IRTN <> 0 OR g_vJYOUKEN1 NOT IN ('0','1','2','3','4','5','6','7','8','9','99') THEN
--  2025/10/24 CTC.GYY UPDATE 1.0.203.000:GKB_QA22525対応 END
          ICHK1 := 1;
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--           VMSG  := g_sGYOUMUCODE || ',99999,開始学年が正しくありません。,;';
          VMSG  := g_sGYOUMUCODE || ',99999,開始学年　範囲（開始）が正しくありません。,;';
        END IF;
        --条件２のチェック
        IRTN := FUNCGAKUNENCHK(g_vJYOUKEN2);
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--         IF IRTN <> 0 THEN
--  2025/10/24 CTC.GYY UPDATE 1.0.203.000:GKB_QA22525対応 START
        --IF IRTN <> 0 OR g_vJYOUKEN2 NOT IN ('1','2','3','4','5','6','7','8','9','99') THEN
        IF IRTN <> 0 OR g_vJYOUKEN2 NOT IN ('0','1','2','3','4','5','6','7','8','9','99') THEN
--  2025/10/24 CTC.GYY UPDATE 1.0.203.000:GKB_QA22525対応 END
          ICHK2 := 1;
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発  
--           VMSG := VMSG || g_sGYOUMUCODE || ',99999,終了学年が正しくありません。,;';
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,終了学年　範囲（終了）が正しくありません。,;';
        END IF;
        --条件１と条件２の大小チェックを行う。
        IF ICHK1 = 0 AND ICHK2 = 0 THEN
          IRTN := FUNCHIKAKUCHK(g_vJYOUKEN1, g_vJYOUKEN2);
          IF IRTN <> 0 THEN
            VMSG := VMSG ||
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発 
--                     g_sGYOUMUCODE || ',99999,開始学年と終了学年の大小関係が誤っています。,;';
                    g_sGYOUMUCODE || ',99999,開始学年　範囲（開始）、終了学年　範囲（終了）の関係が正しくありません。,;';
          END IF;
        END IF;
--  2024/10/17 ZCZL.WANGMING DELETE START 0.3.000.004:仕様変更：IT_GKB_00205対応
--        --条件３のチェックチェックを行う。
--        IRTN := FUNCRENBANCHK(g_vJYOUKEN3);
--        IF IRTN <> 0 THEN
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,帳票連番使用有無が正しくありません。,;';
--        END IF;
--  2024/10/17 ZCZL.WANGMING DELETE END
        --条件４のチェックチェックを行う。
--  2024/10/17 ZCZL.WANGMING UPDATE START 0.3.000.004:仕様変更：IT_GKB_00205対応
--        IRTN := FUNCHIZUKECHK(g_vJYOUKEN4, g_vJYOUKEN4);
--        IF IRTN <> 0 THEN
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
--        END IF;
        bRTN := KKAPK0010.FISNUMERIC(g_vJYOUKEN4);
        IF bRTN THEN
          -- 基準日の妥当性チェック
          bRTN := KKAPK0020.FISDATEW(g_vJYOUKEN4);
          IF bRTN = FALSE THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
          END IF;
        ELSE
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日が正しくありません。,;';
        END IF;
--  2024/10/17 ZCZL.WANGMING UPDATE END

        --基準日の年度がシステム日付の年度ではない場合エラー
        IKIJUN_NENDO := KKAPK0020.FDAYNENDO(0,g_vJYOUKEN4);
        IKIJUN_NENDO := KKAPK0020.FNENDO(IKIJUN_NENDO,1);
        ISYS_NENDO   := KKAPK0020.FDAYNENDO(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),0);
        IF IRTN = 0 AND IKIJUN_NENDO != ISYS_NENDO THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,基準日には年度内を指定してください。,;' ;
        END IF;
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--         条件５のチェックチェックを行う。
--         IRTN := GKBPK00010.FGCODCHK(g_vJYOUKEN5);
--         IF IRTN <> 0 THEN
--           VMSG := VMSG || g_sGYOUMUCODE || ',99999,小学校コードが正しくありません。,;';
--         END IF;
--         条件６のチェックチェックを行う。
--         IRTN := GKBPK00010.FGCODCHK(g_vJYOUKEN6);
--         IF IRTN <> 0 THEN
--           VMSG := VMSG || g_sGYOUMUCODE || ',99999,中学校コードが正しくありません。,;';
--         END IF;
--         条件７のチェックチェックを行う。
--         IRTN := GKBPK00010.FGCODCHK(g_vJYOUKEN7);
--         IF IRTN <> 0 THEN
--           VMSG := VMSG || g_sGYOUMUCODE || ',99999,区域外学校コードが正しくありません。,;';
--         END IF;
--         条件８のチェックチェックを行う。
--         IRTN := GKBPK00010.FGCODCHK(g_vJYOUKEN8);
--         IF IRTN <> 0 THEN
--           '条件８：盲聾養護コードが正しくありません。';
--           VMSG := VMSG || g_sGYOUMUCODE || ',99999,特別支援学校コードが正しくありません。,;';   
--         END IF;
        --条件９のチェックチェックを行う。
--         IRTN := FUNCGAKYUCHK(g_vJYOUKEN9);
--         IF IRTN <> 0 THEN
          --'条件９：学級コードが正しくありません。';
--           VMSG := VMSG || g_sGYOUMUCODE || ',99999,障害コードが正しくありません。,;';           
--         END IF;
        --条件５、６、７、８のチェックチェックを行う。
        --学校コード（小、中、区域外、特別支援のどれも）未入力の場合
        IF GKBPK00010.FGCODCHK(g_vJYOUKEN5) <> 0 AND GKBPK00010.FGCODCHK(g_vJYOUKEN6) <> 0 AND GKBPK00010.FGCODCHK(g_vJYOUKEN7) <> 0 AND GKBPK00010.FGCODCHK(g_vJYOUKEN8) <> 0 THEN
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,学校コードを入力してください。,;'; 
        END IF;
        --条件９のチェックチェックを行う。
        --卒業年月日の数値型変換エラーの場合
        --卒業年月日の年月チェックエラーの場合
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--        IF KKAPK0010.FIsNum(g_vJYOUKEN9) <> 0 OR KKBPK5551.FJOKENDATECHK('GKB', g_sSHORIID, 0, 11, 1, g_vJYOUKEN9) IS NOT NULL THEN
--            VMSG := VMSG || g_sGYOUMUCODE || ',99999,卒業年月日が正しくありません。,;';
--        END IF ;
--  2024/11/21 JPJYS.LIUHUAIQI DELETE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--        IF KKAPK0010.FISNUMERIC(g_vJYOUKEN9) = FALSE THEN 
--          VMSG := VMSG || g_sGYOUMUCODE || ',99999,卒業年月日が正しくありません。,;';
--          ICHK1 := 1;
--        ELSE
--  2024/11/21 JPJYS.LIUHUAIQI DELETE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
        --日付チェック
        IF g_vJYOUKEN9 IS NOT NULL THEN
            bRTN := KKAPK0020.FISDATEW(TO_NUMBER(g_vJYOUKEN9));
            IF NOT bRTN THEN
                VMSG := VMSG || g_sGYOUMUCODE || ',99999,卒業年月日が正しくありません。,;';
                ICHK1 := 1;
            END IF;
        END IF;
--  2024/11/21 JPJYS.LIUHUAIQI DELETE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--        END IF;
--  2024/11/21 JPJYS.LIUHUAIQI DELETE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
        IF ICHK1 = 0 THEN
          IF KKBPK5551.FJOKENDATECHK('GKB', g_sSHORIID, 0, 11, 1, g_vJYOUKEN9) IS NOT NULL THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,卒業年月日が正しくありません。,;';
          END IF;
        END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
        --卒業年月日が未入力かつ学年（開始）と学年（終了）のいずれも未入力の場合
        IF FUNCGAKUNENCHK(g_vJYOUKEN1) <> 0 AND FUNCGAKUNENCHK(g_vJYOUKEN2) <> 0 AND KKAPK0010.FIsNum(g_vJYOUKEN9) <> 0 THEN 
          VMSG := VMSG || g_sGYOUMUCODE || ',99999,学年または卒業年月日を入力してください。,;';
        END IF ;
        --条件10のチェックチェックを行う。
        --異動日　範囲（開始）の数値型変換エラーの場合
        --異動日　範囲（開始）の妥当性チェック(でエラーの場合
        IF KKAPK0010.FISNUMERIC (g_vJYOUKEN10) = FALSE OR KKAPK0020.FISDATEW(g_vJYOUKEN10) = FALSE OR KKBPK5551.FJOKENDATECHK('GKB', g_sSHORIID, 0, 12, 1, g_vJYOUKEN10) IS NOT NULL THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,異動日　範囲（開始）が正しくありません。,;';
            ICHK3 := 1;
        END IF;
        --条件11のチェックチェックを行う。
        --異動日　範囲（終了）の数値型変換エラーの場合
        --異動日　範囲（終了）の数値型変換エラーの場合
        IF KKAPK0010.FISNUMERIC (g_vJYOUKEN11) = FALSE OR KKAPK0020.FISDATEW(g_vJYOUKEN11) = FALSE OR KKBPK5551.FJOKENDATECHK('GKB', g_sSHORIID, 0, 13, 1, g_vJYOUKEN11) IS NOT NULL THEN 
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,異動日　範囲（終了）が正しくありません。,;';
            ICHK4 := 1;
        END IF;
        -- 異動日（開始） > 異動日（終了）の場合
        IF ICHK3 = 0 AND ICHK4 = 0 THEN
          IRTN := FUNCHIKAKUCHK(g_vJYOUKEN10, g_vJYOUKEN11);
          IF IRTN <> 0 THEN
            VMSG := VMSG ||
                    g_sGYOUMUCODE || ',99999,異動日（開始）、異動日（終了）の関係が正しくありません。,;';
          END IF;
        END IF;
        --条件12のチェックチェックを行う。
        -- 処理日　範囲（開始）の数値型変換エラーの場合
        IF KKAPK0010.FISNUMERIC (g_vJYOUKEN12) = FALSE OR KKAPK0020.FISDATEW(g_vJYOUKEN12) = FALSE OR KKBPK5551.FJOKENDATECHK('GKB', g_sSHORIID, 0, 14, 1, g_vJYOUKEN12) IS NOT NULL THEN
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,処理日　範囲（開始）が正しくありません。,;';
            ICHK5 := 1;
        END IF;
        --条件13のチェックチェックを行う。
        --処理日　範囲（終了）の数値型変換エラーの場合
        IF KKAPK0010.FISNUMERIC (g_vJYOUKEN13) = FALSE OR KKAPK0020.FISDATEW(g_vJYOUKEN13) = FALSE OR KKBPK5551.FJOKENDATECHK('GKB', g_sSHORIID, 0, 15, 1, g_vJYOUKEN13) IS NOT NULL THEN 
            VMSG := VMSG || g_sGYOUMUCODE || ',99999,処理日　範囲（終了）が正しくありません。,;';
            ICHK6 := 1;
        END IF;
        --処理日（開始） > 処理日（終了）の場合
        IF ICHK5 = 0 AND ICHK6 = 0 THEN
          IRTN := FUNCHIKAKUCHK(g_vJYOUKEN12, g_vJYOUKEN13);
          IF IRTN <> 0 THEN
            VMSG := VMSG ||
                    g_sGYOUMUCODE || ',99999,処理日（開始）、処理日（終了）の関係が正しくありません。,;';
          END IF;
        END IF;
-- 2024/06/04 ZCZL.wangyunhan Update end 
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
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
    --  機能概要      : 制御のフラグをセットするのを行う
    --  パラメータ    : i_KOJIN_NO
    --            : i_PRM
    --            : o_NAIYO_CD
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------------------------------
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
         WHERE KOJIN_NO = i_KOJIN_NO AND CHOHYO_ID = 'GKB050R001';
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
    END;
    --------------------------------------------------------------------------------
    --  機能概要      : 日付変換2
    --  パラメータ    : i_KBN
    --            : i_YMD
    --            : i_NAIYO_CD_PRM
    --            : o_YMD
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------------------------------
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
      o_YMD1           NVARCHAR2(20);
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

    --------------------------------------------------------------------------------
    --  パラメータ    : i_KOJIN_NO
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------------------------------
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
    --'（転出前）';
           VZEN_JUSHO := GAAPK0010.FADDRESSEDIT( 1, '',  VGEN_CHOMEI, VGEN_BANCHI, VGEN_KATAGAKI, '') || '（転出前）';

       --前住所を表示
       ELSIF NZENJUSHO_REN > 0 THEN
    --'（転居前）';
           VZEN_JUSHO := GAAPK0010.FADDRESSEDIT( 1, '', VZEN_CHOMEI, VZEN_BANCHI, VZEN_KATAGAKI, '') || '（転居前）';
       END IF;
      RETURN VZEN_JUSHO;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN VZEN_JUSHO;
    END FUNC_GET_ZENJUSHO;
    ---------------------------------------------------------------------------------
    --  機能概要      : 基準日対象チェック
    --  パラメータ    : RG
    --            : i_KIJYUNBI
    --            : MHIZUKE
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    ---------------------------------------------------------------------------------
    PROCEDURE PROC_CHECK_KIJUN(RG         IN GKBTGAKUREIBO%ROWTYPE,
                               i_KIJYUNBI IN NUMBER,
                               MHIZUKE    IN OUT MHIZUKE_TYPE)
    IS
    BEGIN
        --変数初期化
        FOR IDX IN 1..4 LOOP
          MHIZUKE(IDX).GAKO_KBN   := 0;
          MHIZUKE(IDX).IN_D       := 0;
          MHIZUKE(IDX).OUT_D      := 0;
        END LOOP;
        --区域外
        IF RG.KUIKIGAI_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.KUIKIGAI_NYUGAKU_BI    > 0 THEN MHIZUKE(1).IN_D := RG.KUIKIGAI_NYUGAKU_BI;   END IF;
          IF RG.KUIKIGAI_TENNYUGAKU_BI > 0 THEN MHIZUKE(1).IN_D := RG.KUIKIGAI_TENNYUGAKU_BI;END IF;
          ----転学年月日OR退学年月日OR卒業年月日
          IF RG.KUIKIGAI_TENGAKU_BI    > 0 THEN MHIZUKE(1).OUT_D := RG.KUIKIGAI_TENGAKU_BI;  END IF;
          IF RG.KUIKIGAI_TAIGAKU_BI    > 0 THEN MHIZUKE(1).OUT_D := RG.KUIKIGAI_TAIGAKU_BI;  END IF;
          IF RG.KUIKIGAI_SOTSUGYO_BI   > 0 THEN MHIZUKE(1).OUT_D := RG.KUIKIGAI_SOTSUGYO_BI; END IF;
          --基準日時点の判定
          IF  MHIZUKE(1).IN_D = 0 AND MHIZUKE(1).OUT_D = 0 THEN
            MHIZUKE(1).GAKO_KBN := 0;
          ELSIF  MHIZUKE(1).IN_D <= i_KIJYUNBI AND (i_KIJYUNBI <= MHIZUKE(1).OUT_D OR MHIZUKE(1).OUT_D = 0) THEN
            MHIZUKE(1).GAKO_KBN := 1;
          ELSIF RG.GAKUNEN = 0 AND (i_KIJYUNBI <= MHIZUKE(1).OUT_D OR MHIZUKE(1).OUT_D = 0) THEN
            MHIZUKE(1).GAKO_KBN := 1;
          END IF;
        END IF;
        --特別支援学校
        IF RG.YOGOGAKO_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.YOGOGAKO_NYUGAKU_BI    > 0 THEN MHIZUKE(2).IN_D := RG.YOGOGAKO_NYUGAKU_BI;   END IF;
          IF RG.YOGOGAKO_TENNYUGAKU_BI > 0 THEN MHIZUKE(2).IN_D := RG.YOGOGAKO_TENNYUGAKU_BI;END IF;
          ----転学年月日OR退学年月日OR卒業年月日
          IF RG.YOGOGAKO_TENGAKU_BI    > 0 THEN MHIZUKE(2).OUT_D := RG.YOGOGAKO_TENGAKU_BI;  END IF;
          IF RG.YOGOGAKO_TAIGAKU_BI    > 0 THEN MHIZUKE(2).OUT_D := RG.YOGOGAKO_TAIGAKU_BI;  END IF;
          IF RG.YOGOGAKO_SOTSUGYO_BI   > 0 THEN MHIZUKE(2).OUT_D := RG.YOGOGAKO_SOTSUGYO_BI; END IF;
          --基準日時点の判定
          IF  MHIZUKE(2).IN_D = 0 AND MHIZUKE(2).OUT_D = 0 THEN
            MHIZUKE(2).GAKO_KBN := 0;
          ELSIF MHIZUKE(2).IN_D <= i_KIJYUNBI AND (i_KIJYUNBI <= MHIZUKE(2).OUT_D OR MHIZUKE(2).OUT_D = 0) THEN
            MHIZUKE(2).GAKO_KBN := 1;
          ELSIF RG.GAKUNEN = 0 AND (i_KIJYUNBI <= MHIZUKE(2).OUT_D OR MHIZUKE(2).OUT_D = 0) THEN
            MHIZUKE(2).GAKO_KBN := 1;
          END IF;
        END IF;
        --小学校
        IF  RG.SYOGAKO_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.SYOGAKO_NYUGAKU_BI    > 0 THEN MHIZUKE(3).IN_D := RG.SYOGAKO_NYUGAKU_BI;     END IF;
          IF RG.SYOGAKO_TENNYUGAKU_BI > 0 THEN MHIZUKE(3).IN_D := RG.SYOGAKO_TENNYUGAKU_BI;  END IF;
          ----転学年月日OR卒業年月日
          IF RG.SYOGAKO_TENGAKU_BI    > 0 THEN MHIZUKE(3).OUT_D := RG.SYOGAKO_TENGAKU_BI;    END IF;
          IF RG.SYOGAKO_SOTSUGYO_BI   > 0 THEN MHIZUKE(3).OUT_D := RG.SYOGAKO_SOTSUGYO_BI;   END IF;
          --基準日時点の判定
          IF  MHIZUKE(3).IN_D = 0 AND MHIZUKE(3).OUT_D = 0 THEN
            MHIZUKE(3).GAKO_KBN := 0;
          ELSIF MHIZUKE(3).IN_D <= i_KIJYUNBI AND (i_KIJYUNBI <= MHIZUKE(3).OUT_D OR MHIZUKE(3).OUT_D = 0) THEN
            MHIZUKE(3).GAKO_KBN := 1;
          ELSIF RG.GAKUNEN = 0 AND (i_KIJYUNBI <= MHIZUKE(3).OUT_D OR MHIZUKE(3).OUT_D = 0) THEN
            MHIZUKE(3).GAKO_KBN := 1;
          END IF;
        END IF;
        --中学校
        IF  RG.TYUGAKO_CD <> 0 THEN
          ----入学年月日OR転入学年月日
          IF RG.TYUGAKO_NYUGAKU_BI    > 0 THEN MHIZUKE(4).IN_D := RG.TYUGAKO_NYUGAKU_BI;     END IF;
          IF RG.TYUGAKO_TENNYUGAKU_BI > 0 THEN MHIZUKE(4).IN_D := RG.TYUGAKO_TENNYUGAKU_BI;  END IF;
          ----転学年月日OR卒業年月日
          IF RG.TYUGAKO_TENGAKU_BI    > 0 THEN MHIZUKE(4).OUT_D := RG.TYUGAKO_TENGAKU_BI;    END IF;
          IF RG.TYUGAKO_SOTSUGYO_BI   > 0 THEN MHIZUKE(4).OUT_D := RG.TYUGAKO_SOTSUGYO_BI;   END IF;
          --基準日時点の判定
          IF  MHIZUKE(4).IN_D = 0 AND MHIZUKE(4).OUT_D = 0 THEN
            MHIZUKE(4).GAKO_KBN := 0;
          ELSIF MHIZUKE(4).IN_D <= i_KIJYUNBI AND (i_KIJYUNBI <= MHIZUKE(4).OUT_D OR MHIZUKE(4).OUT_D = 0) THEN
            MHIZUKE(4).GAKO_KBN := 1;
          END IF;
        END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END PROC_CHECK_KIJUN;
    ---------------------------------------------------------------------------------
    --  機能概要      : 対象学校が入力した学校条件に含まれるかチェック
    --  パラメータ    : GAKO_CD   : 対象学校コード
    --            : GAKO_JOKEN: 入力した学校コード
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    ---------------------------------------------------------------------------------
    FUNCTION FUNC_CHECK_GAKO(GAKO_CD IN PLS_INTEGER,GAKO_JOKEN IN NVARCHAR2) RETURN PLS_INTEGER IS
    P_SQL      VARCHAR2(2000);
    I_COUNT    PLS_INTEGER;
    CRGAKO     TYPECURSOR;
    BEGIN
      I_COUNT := 0;
      IF GAKO_JOKEN IS NOT NULL THEN
          P_SQL := 'SELECT COUNT(1) FROM DUAL ';
          P_SQL := P_SQL || 'WHERE ' || GAKO_CD || ' IN (' || GAKO_JOKEN || ')';
          EXECUTE IMMEDIATE  P_SQL;
          OPEN CRGAKO  FOR P_SQL;
          LOOP
            FETCH  CRGAKO INTO I_COUNT ;
            EXIT WHEN CRGAKO%NOTFOUND;
          END LOOP;
      END IF;
      RETURN I_COUNT;
    END FUNC_CHECK_GAKO;
-- 2024/06/07 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------------------------------
    --  機能概要      : 支援措置対象者情報
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.wangyunhan 2024/06/06
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GACTKANRI_WK RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        IRET                PLS_INTEGER;                -- 戻り値
        BRET                BOOLEAN;                    -- 戻り値
        IFRET               PLS_INTEGER;                -- 戻り値
        VSQL                NVARCHAR2(10000);           -- ＳＱＬ文
        GACTKANRI           TYPECURSOR;
        nINDEX              NUMBER := 0;
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        --ＳＱＬ文
        VSQL := '';
        VSQL := VSQL || ' SELECT';
        VSQL := VSQL || '     SONOTAGYOMU.SETAIYOKUSHIKBN                                    ';
        VSQL := VSQL || '     , SONOTAGYOMU.TOROKU_GYOMU                                     ';
        VSQL := VSQL || '     , SONOTAGYOMU.SHIENSOCHIKBN                                    ';
        VSQL := VSQL || '     , SONOTAGYOMU.SHIENSOCHISHURYOKBN                              ';
        VSQL := VSQL || '     , SONOTAGYOMU.SHIENSOCHIKAISHIBI                               ';
        VSQL := VSQL || '     , SONOTAGYOMU.SHIENSOCHISHURYOBI                               ';
        VSQL := VSQL || '     , NULL AS  TAISHOSHAKBN                                        ';
        VSQL := VSQL || '     , NULL AS  KARISHIENSOCHIKAISHIBI                              ';
        VSQL := VSQL || '     , NULL AS  KARISHIENSOCHISHURYOBI                              ';
        VSQL := VSQL || '     , NULL AS  SHIENSOCHIKAIJOBI                                   ';
        VSQL := VSQL || ' FROM                                                               ';
        VSQL := VSQL || '     GACTKANRI_SONOTAGYOMU SONOTAGYOMU                              ';
--  2024/08/12 ZCZL.YANGXINYU DELETE 0.3.000.002:受入検証対応No182_2回目
--        VSQL := VSQL || '     , GACTKANRI_MOUSHIDE                                           ';
        VSQL := VSQL || ' WHERE                                                              ';
        VSQL := VSQL || '     SONOTAGYOMU.TOROKU_GYOMU = ''GKB''                             ';
        VSQL := VSQL || '     AND SONOTAGYOMU.KOJIN_NO = '|| GAKUREIBO_RECC.KOJIN_NO ||'     ';
        VSQL := VSQL || '     AND SONOTAGYOMU.SHIENSOCHIKBN IN (1, 2)                        ';
-- 2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
        --VSQL := VSQL || '     AND SONOTAGYOMU.SHIENSOCHISHURYOKBN <> 3                       ';
        VSQL := VSQL || '     AND NVL(SONOTAGYOMU.SHIENSOCHISHURYOKBN, 0) <> 3               ';
        --IF VSOTSUGYOYMD IS NULL THEN
        IF VSOTSUGYOYMD IS NULL  OR VSOTSUGYOYMD = 0 THEN  
-- 2025/06/04 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
           VSQL := VSQL || ' AND SONOTAGYOMU.SHIENSOCHIKAISHIBI <= TO_NUMBER(TO_CHAR(SYSDATE,''YYYYMMDD'')) ';
        ELSE 
           VSQL := VSQL || ' AND SONOTAGYOMU.SHIENSOCHIKAISHIBI <= '|| VSOTSUGYOYMD ||' ';
        END IF; 
        VSQL := VSQL || ' AND SONOTAGYOMU.RIREKI_NO = (                                 ';
        VSQL := VSQL || '     SELECT                                                    ';
        VSQL := VSQL || '         MAX(RIREKI_NO)                                        ';
        VSQL := VSQL || '     FROM                                                      ';
        VSQL := VSQL || '         GACTKANRI_SONOTAGYOMU                                 ';
        VSQL := VSQL || '     WHERE                                                     ';
        VSQL := VSQL || '         KOJIN_NO = SONOTAGYOMU.KOJIN_NO                       ';
        VSQL := VSQL || '         AND TOROKU_GYOMU = SONOTAGYOMU.TOROKU_GYOMU           ';
        VSQL := VSQL || '         AND SHIENSOCHIKBN = SONOTAGYOMU.SHIENSOCHIKBN         ';
        VSQL := VSQL || '         AND SHIENSOCHIKAISHIBI = SONOTAGYOMU.SHIENSOCHIKAISHIBI ';
        VSQL := VSQL || ' )                                                             ';
        VSQL := VSQL || ' UNION ALL                                                     ';
        VSQL := VSQL || ' SELECT                                                        ';
        VSQL := VSQL || '       NULL  AS SETAIYOKUSHIKBN                                ';
        VSQL := VSQL || '     , NULL  AS TOROKU_GYOMU                                   ';
        VSQL := VSQL || '     , NULL  AS SHIENSOCHIKBN                                  ';
        VSQL := VSQL || '     , NULL  AS SHIENSOCHISHURYOKBN                            ';
        VSQL := VSQL || '     , MOUSHIDE.SHIENSOCHIKAISHIBI                             ';
        VSQL := VSQL || '     , MOUSHIDE.SHIENSOCHISHURYOBI                             ';
        VSQL := VSQL || '     , MOUSHIDE.TAISHOSHAKBN                                   ';
        VSQL := VSQL || '     , MOUSHIDE.KARISHIENSOCHIKAISHIBI                         ';
        VSQL := VSQL || '     , MOUSHIDE.KARISHIENSOCHISHURYOBI                         ';
        VSQL := VSQL || '     , MOUSHIDE.SHIENSOCHIKAIJOBI                              ';
        VSQL := VSQL || ' FROM                                                          ';
--  2024/08/12 ZCZL.YANGXINYU UPDATE START 0.3.000.002:受入検証対応No182_2回目
--        VSQL := VSQL || '     GACTKANRI_SONOTAGYOMU SONOTAGYOMU                         ';
--        VSQL := VSQL || '     , GACTKANRI_MOUSHIDE MOUSHIDE                             ';
        VSQL := VSQL || '      GACTKANRI_MOUSHIDE MOUSHIDE                             ';
--  2024/08/12 ZCZL.YANGXINYU UPDATE END
        VSQL := VSQL || ' WHERE                                                         ';
        VSQL := VSQL || '     MOUSHIDE.KOJIN_NO IN (                                    ';
        VSQL := VSQL || '         SELECT                                                ';
        VSQL := VSQL || '             KOJIN_NO                                          ';
        VSQL := VSQL || '         FROM                                                  ';
        VSQL := VSQL || '             GACTKANRI_MOUSHIDE                                ';
        VSQL := VSQL || '         WHERE                                                 ';
        VSQL := VSQL || '     '|| GAKUREIBO_RECC.KOJIN_NO ||' = TAISHO_ATENA_NO  ';
        VSQL := VSQL || '             AND TAISHOSHAKBN = 1                              ';
        VSQL := VSQL || '         UNION ALL                                             ';
        VSQL := VSQL || '         SELECT                                                ';
        VSQL := VSQL || '             KOJIN_NO                                          ';
        VSQL := VSQL || '         FROM                                                  ';
        VSQL := VSQL || '             GACTKANRI_MOUSHIDE                                ';
        VSQL := VSQL || '         WHERE                                                 ';
        VSQL := VSQL || '            '|| GAKUREIBO_RECC.KOJIN_NO ||'= KOJIN_NO   ';
        VSQL := VSQL || '             AND TAISHOSHAKBN = 0                              ';
        VSQL := VSQL || '     )                                                         ';
        VSQL := VSQL || '     AND MOUSHIDE.TAISHOSHAKBN = 0                             ';
        VSQL := VSQL || '     AND                                                       ';
-- 2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
        IF VSOTSUGYOYMD IS NULL OR VSOTSUGYOYMD = 0 THEN
-- 2025/06/04 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
--  2024/08/12 ZCZL.YANGXINYU UPDATE 0.3.000.002:受入検証対応No182_2回目
--           VSQL := VSQL || '  (                                                             ';
           VSQL := VSQL || '  ((                                                             ';
           VSQL := VSQL || '        MOUSHIDE.SHIENSOCHIKAISHIBI <= TO_NUMBER(TO_CHAR(SYSDATE,''YYYYMMDD''))                  ';
           VSQL := VSQL || '        AND DECODE(                                        ';
           VSQL := VSQL || '                NVL(MOUSHIDE.SHIENSOCHIKAIJOBI, 0)             ';
           VSQL := VSQL || '                , 0                                             ';
           VSQL := VSQL || '                , 99999999,MOUSHIDE.SHIENSOCHISHURYOBI                                      ';
           VSQL := VSQL || '            ) >= TO_NUMBER(TO_CHAR(SYSDATE,''YYYYMMDD''))         ';
           VSQL := VSQL || '    )                                                           ';
           VSQL := VSQL || '    OR (                                                        ';
           VSQL := VSQL || '        MOUSHIDE.KARISHIENSOCHIKAISHIBI <= TO_NUMBER(TO_CHAR(SYSDATE,''YYYYMMDD''))              ';
           VSQL := VSQL || '        AND DECODE(                                        ';
           VSQL := VSQL || '                NVL(MOUSHIDE.SHIENSOCHIKAIJOBI, 0)         ';
           VSQL := VSQL || '                , 0                                             ';
           VSQL := VSQL || '                , 99999999,MOUSHIDE.KARISHIENSOCHISHURYOBI                                      ';
           VSQL := VSQL || '            ) >= TO_NUMBER(TO_CHAR(SYSDATE,''YYYYMMDD''))       ';
--  2024/08/12 ZCZL.YANGXINYU UPDATE  0.3.000.002:受入検証対応No182_2回目
--           VSQL := VSQL || '    )                                                           ';
           VSQL := VSQL || '    ))                                                           ';
        ELSE  
--  2024/08/12 ZCZL.YANGXINYU UPDATE  0.3.000.002:受入検証対応No182_2回目
--           VSQL := VSQL || '        (MOUSHIDE.SHIENSOCHIKAISHIBI <= '|| VSOTSUGYOYMD ||'       ';
           VSQL := VSQL || '        ((MOUSHIDE.SHIENSOCHIKAISHIBI <= '|| VSOTSUGYOYMD ||'       ';
           VSQL := VSQL || '        AND DECODE(                                           ';
           VSQL := VSQL || '                NVL(MOUSHIDE.SHIENSOCHIKAIJOBI, 0)                ';
           VSQL := VSQL || '                , 0                                                ';
           VSQL := VSQL || '                , 99999999 ,MOUSHIDE.SHIENSOCHISHURYOBI                                        ';
           VSQL := VSQL || '            ) >= '|| VSOTSUGYOYMD ||'                              ';
           VSQL := VSQL || '    )                                                              ';
           VSQL := VSQL || '    OR (                                                           ';
           VSQL := VSQL || '        MOUSHIDE.KARISHIENSOCHIKAISHIBI <= '|| VSOTSUGYOYMD ||'    ';
           VSQL := VSQL || '        AND DECODE(                                           ';
           VSQL := VSQL || '                NVL(MOUSHIDE.SHIENSOCHIKAIJOBI, 0)            ';
           VSQL := VSQL || '                , 0                                                ';
           VSQL := VSQL || '                , 99999999,MOUSHIDE.KARISHIENSOCHISHURYOBI                                         ';
           VSQL := VSQL || '            ) >= '|| VSOTSUGYOYMD ||'                              ';
--  2024/08/12 ZCZL.YANGXINYU UPDATE  0.3.000.002:受入検証対応No182_2回目
--           VSQL := VSQL || '    )                                                              ';
           VSQL := VSQL || '    ))                                                              ';
        END IF; 
--  2024/08/12 ZCZL.YANGXINYU UPDATE 0.3.000.002:受入検証対応No182_2回目
--        VSQL := VSQL || '  AND SONOTAGYOMU.RIREKI_NO = (                                 ';
        VSQL := VSQL || '  AND MOUSHIDE.RIREKI_RENBAN = (                                 ';
        VSQL := VSQL || '      SELECT                                                 ';
        VSQL := VSQL || '          MAX(RIREKI_RENBAN)                                 ';
        VSQL := VSQL || '      FROM                                                   ';
        VSQL := VSQL || '          GACTKANRI_MOUSHIDE                                 ';
        VSQL := VSQL || '      WHERE                                                  ';
        VSQL := VSQL || '          KOJIN_NO = MOUSHIDE.KOJIN_NO                       ';
        VSQL := VSQL || '          AND TAISHOSHAKBN = MOUSHIDE.TAISHOSHAKBN          ';
        VSQL := VSQL || '  ) ';
            OPEN GACTKANRI  FOR VSQL;
            LOOP
                FETCH  GACTKANRI INTO GACTKANRI_RECC;
                EXIT WHEN GACTKANRI%NOTFOUND;
                nINDEX := nINDEX + 1;
                VSETAIYOKUSHIKBN.EXTEND;
                VTOROKU_GYOMU.EXTEND;
                VSHIENSOCHIKBN.EXTEND;
                VSHIENSOCHISHURYOKBN.EXTEND;
                VSHIENSOCHIKAISHIBI.EXTEND;
                VSHIENSOCHISHURYOBI.EXTEND;
                VTAISHOSHAKBN.EXTEND;
                VKARISHIENSOCHIKAISHIBI.EXTEND;
                VKARISHIENSOCHISHURYOBI.EXTEND;
                VSHIENSOCHIKAIJOBI.EXTEND;
                VSETAIYOKUSHIKBN(nINDEX)         := GACTKANRI_RECC.SETAIYOKUSHIKBN;
                VTOROKU_GYOMU(nINDEX)            := GACTKANRI_RECC.TOROKU_GYOMU;
                VSHIENSOCHIKBN(nINDEX)           := GACTKANRI_RECC.SHIENSOCHIKBN;
                VSHIENSOCHISHURYOKBN(nINDEX)     := GACTKANRI_RECC.SHIENSOCHISHURYOKBN;
                VSHIENSOCHIKAISHIBI(nINDEX)      := GACTKANRI_RECC.SHIENSOCHIKAISHIBI;
                VSHIENSOCHISHURYOBI(nINDEX)      := GACTKANRI_RECC.SHIENSOCHISHURYOBI;
                VTAISHOSHAKBN(nINDEX)            := GACTKANRI_RECC.TAISHOSHAKBN;
                VKARISHIENSOCHIKAISHIBI(nINDEX)  := GACTKANRI_RECC.KARISHIENSOCHIKAISHIBI;
                VKARISHIENSOCHISHURYOBI(nINDEX)  := GACTKANRI_RECC.KARISHIENSOCHISHURYOBI;
                VSHIENSOCHIKAIJOBI(nINDEX)       := GACTKANRI_RECC.SHIENSOCHIKAIJOBI;
            END LOOP;
            CLOSE GACTKANRI;
        -- 終了
        RETURN FRET;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD START 0.3.000.003:8月1日認識合わせの横展開
          IF GACTKANRI%ISOPEN THEN
              CLOSE GACTKANRI;
          END IF;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
          IFRET := c_INOTFOUND;
      RETURN IFRET;
    -- その他エラー
        WHEN OTHERS THEN
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD START 0.3.000.003:8月1日認識合わせの横展開
            IF GACTKANRI%ISOPEN THEN
                CLOSE GACTKANRI;
            END IF;
--  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
            ROLLBACK;       -- 処理前に戻す
            IFRET := c_INOT_SUCCESS;      -- 異常終了
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GACTKANRI_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
            DBMS_OUTPUT.put_line('err :' || SQLERRM);
        RETURN IFRET;
    END FUNC_GACTKANRI_WK;
-- 2024/06/04 ZCZL.wangyunhan Add end
    --------------------------------------------------------------------------------
    --  機能概要      : 学齢簿中間レコードの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK RETURN NUMBER IS
        IFRET                PLS_INTEGER;                -- 戻り値
        NNENDO              PLS_INTEGER;                -- 年度
        NGAKUNEN_CD              NUMBER;                -- 学年コード
        NSYURYOGAKUNEN_CD   NUMBER;                     -- 終了学年コード
        IRTNA               PLS_INTEGER;
        IRTNSANTEIDANTAI    PLS_INTEGER;
        IRTNAH              PLS_INTEGER;
        ICNT                BINARY_INTEGER;             -- 戻り値
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        I_RTN           PLS_INTEGER;
        IRET                PLS_INTEGER;                -- 戻り値
        ISETAIKBN           PLS_INTEGER;
        IYOKUSIKBN          PLS_INTEGER;
        IDOYOKUKBN          PLS_INTEGER;
        IHAKKOYOKUKBN       PLS_INTEGER;
        ISYOUKOUYOKUSIKBN   PLS_INTEGER;
        ISHORIBICYUIKBN     PLS_INTEGER;
        nGAITO_KARA             NUMBER;                     --支援措置開始年月日
        nGAITO_MADE             NUMBER;                     --支援措置終了年月日
        IMAX                BINARY_INTEGER;             -- 戻り値
        IMIN                BINARY_INTEGER;             -- 戻り値
-- 2024/06/04 ZCZL.wangyunhan Add end
        BRTNSASKUSEIBI      BOOLEAN;
        IJUSHO_NAGASA       PLS_INTEGER;
        ISHIMEINAGASA       PLS_INTEGER;
        IRTNZOKUGARA1        PLS_INTEGER;
        IRTNZOKUGARAHERR1    PLS_INTEGER;
        IRTNZOKUGARA2        PLS_INTEGER;
        IRTNZOKUGARAHERR2    PLS_INTEGER;
        NPRTN                NUMBER;
        IRTN                 PLS_INTEGER;
        BRTN                 BOOLEAN;
        ICNTN                BINARY_INTEGER;
--  2025/05/19 ZCZL.WANGMING UPDATE 1.0.004.000: GKB_QA14775(保守2208)_卒業年月日入力なしの対応
--        VSQLSEL             VARCHAR2(2000);
        VSQLSEL             VARCHAR2(10000);
        --基準日使用変数
        VEDIT_GYYMMDD1   NVARCHAR2(20);
        VEDIT_GYYMMDD2   NVARCHAR2(20);
        VEDIT_GYYMMDD3   NVARCHAR2(20);
        VKG_GENGO        NVARCHAR2(20);
        IWAREKI_YY       PLS_INTEGER;
        ISEIREKI_YYYY    PLS_INTEGER;
        IWAREKI_GYYMM    PLS_INTEGER;
        IMM              PLS_INTEGER;
        IDD              PLS_INTEGER;
        IOWAREKIHIZUKE   PLS_INTEGER;
        ISEIREKIHIZUKE   PLS_INTEGER;
        IWAREKI          PLS_INTEGER;
        ISEIREKI         PLS_INTEGER;
        o_NISAKUSEIBI    NUMBER(8,0);
        NKYOIKUIINKAI_CD NUMBER(2,0);  --教育委員会コード
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--        KOJINNO3            NUMBER(12):=0;            --個人番号 個人番号の最新と履歴を区別するため
        KOJINNO3            NUMBER(15):=0;            --個人番号 個人番号の最新と履歴を区別するため
        MHIZUKE     MHIZUKE_TYPE;  --読込レコード用
        MHIZUKE_SAV MHIZUKE_TYPE;  --保持用
        IGAKO_KBN           BINARY_INTEGER := 0 ;  --該当する学校区分
        BOUT_FLG2           BOOLEAN := FALSE;      --出力ﾌﾗｸﾞ
        BOUT_FLG3           BOOLEAN;               --出力ﾌﾗｸﾞ
        VGAKO_JOKEN         BOOLEAN;               --学校条件
        N_NAIYO_CD_JIDO     GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;  
        o_RATENA_REC        GABTATENAKIHON%ROWTYPE;
        o_RSOFU_REC         GABTSOFUSAKI%ROWTYPE;
        CRATENA             TYPECURSOR;
--  2024/08/05 ZCZL.YANGXINYU ADD START 0.3.000.001:受入検証対応No182
        o_sSHIMEI_KANA      NVARCHAR2(150); 
        o_sSHIMEI_KANJI     NVARCHAR2(150);
        o_sSEINENGAPI       NVARCHAR2(150); 
--  2024/08/05 ZCZL.YANGXINYU ADD END

    BEGIN
        IFRET := c_INOTFOUND;                 -- 該当なし
        IKAISIGAKUNEN := TO_NUMBER(VKAISIGAKUNEN);        -- 開始学年
        ISHURYOGAKUNEN := TO_NUMBER(VSHURYOGAKUNEN);        -- 終了学年
        ISEIREKI := NULL;
        IWAREKI := NHAKOBI;
        BRTN := KKAPK0020.FDAYEDIT(NHAKOBI,
                                    ISEIREKI,
                                    VEDIT_GYYMMDD3,
                                    VEDIT_GYYMMDD2,
                                    VKUIKIGAI_TENTAIGAKU_BI,
                                    VKJ_GENGO,
                                    VKG_GENGO,
                                    IWAREKI_YY,
                                    ISEIREKI_YYYY,
                                    IWAREKI_GYYMM,
                                    IMM,
                                    IDD,
                                    IOWAREKIHIZUKE,
                                    ISEIREKIHIZUKE);
        I_RTN := GKBPK00010.FKJBGET(ISEIREKI,NRENBAN,o_NISAKUSEIBI);
            IF I_RTN = 1 THEN
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
                RETURN IFRET;
            END IF;
        ISAKUSEIBI := o_NISAKUSEIBI;
        --学校条件指定・未指定
        IF VSYOGAKOCD IS NULL AND VTYUGAKOCD IS NULL AND VKUIKIGAICD IS NULL AND VYOGOGAKOCD IS NULL THEN
          VGAKO_JOKEN := FALSE;
        ELSE
          VGAKO_JOKEN := TRUE;
        END IF;
        --本名・通称名出力制御を取得する。
        IRTN_SHIMEI := KKAPK0030.FPRMSHUTOKU('GKB','EQSHIMEI',0,ACONSPRM_SHIMEI,NLENGTH);
          IF IRTN_SHIMEI = 1 THEN
             ACONSPRM_SHIMEI := A_CONS_PRM();
             ACONSPRM_SHIMEI.EXTEND;
             ACONSPRM_SHIMEI.EXTEND;
             ACONSPRM_SHIMEI(1) := 0;
             ACONSPRM_SHIMEI.EXTEND;
             ACONSPRM_SHIMEI(2) := 0;
             ACONSPRM_SHIMEI.EXTEND;
             ACONSPRM_SHIMEI(3) := 0;
          ELSE
             WHILE (NLENGTH < 3) LOOP
               ACONSPRM_SHIMEI.EXTEND;
               ACONSPRM_SHIMEI(NLENGTH+1) := 0;
               NLENGTH := NLENGTH + 1;
             END LOOP;
          END IF;

        -- ワーク領域の初期化
        MJIDO_WORK.DELETE;
        MGAKUREIBO_WORK.DELETE;
        MGAKUNEN_LNK_WORK.DELETE;
        MNENDO_WORK.DELETE;
     -- 年度の索引付表初期化
     FOR ICNTN IN 1..9 LOOP
         MNENDO_WORK(ICNTN).NENDO := ' ';
     END LOOP;
        ICNT := 0;
        BEGIN
            -- 取得したデータを読み終えるまで繰り返す（取得データ件数が０件の場合、エラーにはならずそのまま下の処理へいく）
                    --カーソル定義
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'A.KOJIN_NO, ';
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
            VSQLSEL := VSQLSEL || ' A.RIREKI_RENBAN_EDA, ';
            VSQLSEL := VSQLSEL || ' B.S_TAIGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.S_TAIGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.T_TAIGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.T_TAIGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_S_CD, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_S_NYUGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_S_TENNYU_BI, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_S_TENNYU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_S_TENGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_S_TENGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_S_TAIGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_S_TAIGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_S_SOTSUGYO_BI, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_T_CD, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_T_NYUGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_T_TENNYU_BI, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_T_TENNYU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_T_TENGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_T_TENGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_T_TAIGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_T_TAIGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.KUIKIGAI_T_SOTSUGYO_BI, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_S_CD, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_S_NYUGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_S_TENNYU_BI, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_S_TENNYU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_S_TENGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_S_TENGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_S_TAIGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_S_TAIGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_S_SOTSUGYO_BI, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_T_CD, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_T_NYUGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_T_TENNYU_BI, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_T_TENNYU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_T_TENGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_T_TENGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_T_TAIGAKU_BI, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_T_TAIGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' B.SHIEN_T_SOTSUGYO_BI, ';
-- 2024/06/04 ZCZL.wangyunhan Add end 
            VSQLSEL := VSQLSEL || 'A.RIREKI_RENBAN, ';
            VSQLSEL := VSQLSEL || 'A.GAKUNEN, ';
-- 2024/06/04 ZCZL.wangyunhan Delete 0.3.000.000:新WizLIFE２次開発
--             VSQLSEL := VSQLSEL || 'B.NINIBIT1, ';
            VSQLSEL := VSQLSEL || 'A.HOGOSYA_KOJIN_NO ';
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBTGAKUREIBO A, ';
            ---- 基準日の取得
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--             VSQLSEL := VSQLSEL || 'GKBTNINIBIT B ';
            VSQLSEL := VSQLSEL || 'GKBTSHUGAKURIREKI B ';
            VSQLSEL := VSQLSEL || 'WHERE  ';
            VSQLSEL := VSQLSEL || '    A.KOJIN_NO = B.KOJIN_NO ';    
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発                
--             VSQLSEL := VSQLSEL || 'AND A.RIREKI_RENBAN = B.RIREKI_RENBAN ';    
            VSQLSEL := VSQLSEL || ' AND A.RIREKI_RENBAN =B.KOJIN_RIREKI_RENBAN ';
--  2025/05/19 ZCZL.WANGMING UPDATE 1.0.004.000: GKB_QA14775(保守2208)_卒業年月日入力なしの対応
--            IF VSOTSUGYOYMD IS NULL THEN 
            IF VSOTSUGYOYMD IS NULL OR VSOTSUGYOYMD = 0 THEN
              VSQLSEL := VSQLSEL || ' AND A.SAISHIN_KBN = 0 ';
              VSQLSEL := VSQLSEL || ' AND A.SAKUJO_FLG = 0 ';
              VSQLSEL := VSQLSEL || ' AND A.GEN_NENGAPI = 0 ';
              VSQLSEL := VSQLSEL || ' AND A.GAKUNEN >= '|| VKAISIGAKUNEN ||' ';
              VSQLSEL := VSQLSEL || ' AND A.GAKUNEN <= '|| VSHURYOGAKUNEN ||' ';
              VSQLSEL := VSQLSEL || ' AND B.NENDO =' || KKAPK0020.FDAYNENDO(TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),0);
              VSQLSEL := VSQLSEL || ' AND B.SAISHIN_FLG = 0 ';
              VSQLSEL := VSQLSEL || ' AND B.SAKUJO_FLG = 0 ';
              VSQLSEL := VSQLSEL || ' AND B.SHUGAKU_RIREKI_RENBAN = (SELECT MAX(SHUGAKU_RIREKI_RENBAN) FROM GKBTSHUGAKURIREKI ';
              VSQLSEL := VSQLSEL || '                                WHERE KOJIN_NO = B.KOJIN_NO AND KOJIN_RIREKI_RENBAN = B.KOJIN_RIREKI_RENBAN ) ';
              IF VIDOBISTARTYMD IS NOT NULL  OR VIDOBIENDYMD IS NOT NULL THEN 
                VSQLSEL := VSQLSEL || ' AND (A.IDO_BI >= '|| VIDOBISTARTYMD  ||' ';
                VSQLSEL := VSQLSEL || ' OR A.IDO_BI <= '|| VIDOBIENDYMD ||') ';
              END IF;
              IF VSYORIBISTARTYMD IS NOT NULL  OR VSYORIBIENDYMD IS NOT NULL THEN 
                VSQLSEL := VSQLSEL || ' AND (A.SHORIBI >= '|| VSYORIBISTARTYMD  ||' ';
                VSQLSEL := VSQLSEL || ' OR A.SHORIBI <= '|| VSYORIBIENDYMD ||') ';
              END IF;
              IF VSYOGAKOCD IS NOT NULL THEN 
                VSQLSEL := VSQLSEL || 'AND ((A.SYOGAKO_NYUGAKU_BI <> 0 ';
                VSQLSEL := VSQLSEL || ' OR A.SYOGAKO_TENNYUGAKU_BI <> 0 )';
                VSQLSEL := VSQLSEL || ' AND A.SYOGAKO_TENGAKU_BI = 0 ';
                VSQLSEL := VSQLSEL || ' AND A.SYOGAKO_SOTSUGYO_BI = 0 ';
--  2024/08/12 ZCZL.YANGXINYU UPDATE 0.3.000.002:受入検証対応No182_2回目
--                VSQLSEL := VSQLSEL || ' AND A.TYUGAKO_CD IN ('|| VSYOGAKOCD ||'))';
                VSQLSEL := VSQLSEL || ' AND A.SYOGAKO_CD IN ('|| VSYOGAKOCD ||'))';
              END IF;
              IF VTYUGAKOCD IS NOT NULL THEN 
                VSQLSEL := VSQLSEL || ' AND ((A.TYUGAKO_NYUGAKU_BI <> 0 ';
                VSQLSEL := VSQLSEL || ' OR A.TYUGAKO_TENNYUGAKU_BI <> 0) ';
                VSQLSEL := VSQLSEL || ' AND A.TYUGAKO_TENGAKU_BI = 0 ';
                VSQLSEL := VSQLSEL || ' AND A.TYUGAKO_SOTSUGYO_BI = 0 ';
                VSQLSEL := VSQLSEL || ' AND A.TYUGAKO_CD IN ('|| VTYUGAKOCD ||')) ';
              END IF;
              IF VKUIKIGAICD IS NOT NULL THEN 
                VSQLSEL := VSQLSEL || 'AND (( A.KUIKIGAI_NYUGAKU_BI <> 0 ';
                VSQLSEL := VSQLSEL || ' OR A.KUIKIGAI_TENNYUGAKU_BI <> 0) ';
                VSQLSEL := VSQLSEL || ' AND A.KUIKIGAI_TENGAKU_BI = 0 ';
                VSQLSEL := VSQLSEL || ' AND A.KUIKIGAI_SOTSUGYO_BI = 0 ';
                VSQLSEL := VSQLSEL || ' AND A.KUIKIGAI_CD IN ('|| VKUIKIGAICD ||')) ';
              END IF;
              IF VYOGOGAKOCD IS NOT NULL THEN 
                VSQLSEL := VSQLSEL || ' AND (( A.YOGOGAKO_NYUGAKU_BI <> 0 ';
                VSQLSEL := VSQLSEL || ' OR A.YOGOGAKO_TENNYUGAKU_BI <> 0) ';
                VSQLSEL := VSQLSEL || ' AND A.YOGOGAKO_TENGAKU_BI = 0 ';
                VSQLSEL := VSQLSEL || ' AND A.YOGOGAKO_SOTSUGYO_BI = 0 ';
                VSQLSEL := VSQLSEL || ' AND A.YOGOGAKO_CD IN ('|| VYOGOGAKOCD ||'))';
              END IF;
            ELSE
              VSQLSEL := VSQLSEL || ' AND B.NENDO = '|| KKAPK0020.FDAYNENDO(VSOTSUGYOYMD,0);
              VSQLSEL := VSQLSEL || ' AND B.SHUGAKU_RIREKI_RENBAN = (SELECT MAX(SHUGAKU_RIREKI_RENBAN) FROM GKBTSHUGAKURIREKI ';
              VSQLSEL := VSQLSEL || '                                WHERE KOJIN_NO = B.KOJIN_NO AND KOJIN_RIREKI_RENBAN = B.KOJIN_RIREKI_RENBAN ) ';
              VSQLSEL := VSQLSEL || ' AND B.SAKUJO_FLG = 0 ';
              IF VSYOGAKOCD IS NOT NULL THEN 
                VSQLSEL := VSQLSEL || ' AND B.S_SOTSUGYO_BI = '|| VSOTSUGYOYMD ||' ';
              END IF;
              IF VTYUGAKOCD IS NOT NULL THEN 
                VSQLSEL := VSQLSEL || ' AND B.T_SOTSUGYO_BI = '|| VSOTSUGYOYMD ||' ';
              END IF;
              IF VKUIKIGAICD IS NOT NULL THEN 
                VSQLSEL := VSQLSEL || ' AND (B.KUIKIGAI_S_SOTSUGYO_BI = '|| VSOTSUGYOYMD ||' OR ';
                VSQLSEL := VSQLSEL || '  B.KUIKIGAI_T_SOTSUGYO_BI = '|| VSOTSUGYOYMD ||') ';
              END IF;
              IF VYOGOGAKOCD IS NOT NULL THEN 
                VSQLSEL := VSQLSEL || ' AND (B.SHIEN_S_SOTSUGYO_BI = '|| VSOTSUGYOYMD ||' OR ';
                VSQLSEL := VSQLSEL || '  B.SHIEN_T_SOTSUGYO_BI = '|| VSOTSUGYOYMD ||') ';
              END IF;
            END IF;
-- 2024/06/04 ZCZL.wangyunhan Update end
              VSQLSEL := VSQLSEL || ' ORDER BY A.KOJIN_NO,A.RIREKI_RENBAN DESC ';  
            EXECUTE IMMEDIATE  VSQLSEL;
            OPEN CRATENA  FOR VSQLSEL;
            LOOP
                FETCH  CRATENA INTO GAKUREIBO_RECC;
                EXIT WHEN CRATENA%NOTFOUND;
               VSHOGAKOMEI        := '';
               VTYUGAKOMEI        := '';
               VKUIKIGAIMEI       := '';
               VYOGOGAKOMEI       := '';
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--                GKBSKJDOG2(GAKUREIBO_RECC.KOJIN_NO,GAKUREIBO_RECC.RIREKI_RENBAN,RG,NPRTN);
               GKBSKJDOG2(GAKUREIBO_RECC.KOJIN_NO,GAKUREIBO_RECC.RIREKI_RENBAN,GAKUREIBO_RECC.RIREKI_RENBAN_EDA,RG,NPRTN);
               /*****   チェック１：基準日判断  ここから   ******/
               --まず読込レコードが基準日時点のデータかチェック
               PROC_CHECK_KIJUN(RG,ISAKUSEIBI,MHIZUKE);
               --個人番号が変わる場合、保持用変数も初期化
               IF KOJINNO3 <> RG.KOJIN_NO THEN
                 KOJINNO3 := RG.KOJIN_NO;
                 IGAKO_KBN   := 0;
                 BOUT_FLG2   := FALSE;
                 BOUT_FLG3   := FALSE;
                 --IDX=1:区域外、2:特別支援、3:小学校、4:中学校
                 FOR IDX IN 1..4 LOOP
                     MHIZUKE_SAV(IDX).GAKO_KBN   := 0;
                     MHIZUKE_SAV(IDX).GAKO_CD    := 0;
                     MHIZUKE_SAV(IDX).IN_D       := 0;
                     MHIZUKE_SAV(IDX).OUT_D      := 0;
                 END LOOP;
                 --区域外、養護学校、小学校、中学校順位で基準日時点に在学したか確認
                 FOR IDX IN 1..4 LOOP
                   IF MHIZUKE(IDX).GAKO_KBN > 0 THEN         --読込レコードが基準日対象の場合
                     IGAKO_KBN := IDX;                        --基準日時点のを最初に見つかったのが対象になる
                     BOUT_FLG2 := TRUE;
                   END IF;
                   EXIT WHEN BOUT_FLG2 = TRUE;
                 END LOOP;
                 MHIZUKE_SAV   := MHIZUKE;
               ELSE                                          --MAX以前の履歴の場合
                 --同じ個人番号で既に基準日対象レコードが見つかった場合、次へ飛ばす
                 --基準日には該当するが、他の条件を満たさない場合、次へ飛ばす
                 IF BOUT_FLG3 THEN GOTO continue;END IF;
                 --区域外、養護学校、小学校、中学校順位で基準日時点に在学したか確認
                 FOR IDX IN 1..4 LOOP
                   IF MHIZUKE(IDX).GAKO_KBN > 0 THEN         --読込レコードが基準日対象の場合
                     IF MHIZUKE(IDX).IN_D >= MHIZUKE_SAV(IDX).IN_D THEN  --読込レコード＞＝前回の入日付の入日付の場合、前回ので判断
                       --前回ので判断する場合、学校が変わるとスキップ
                       IF MHIZUKE_SAV(IDX).GAKO_CD = MHIZUKE(IDX).GAKO_CD
                        AND MHIZUKE_SAV(IDX).IN_D <= ISAKUSEIBI AND (ISAKUSEIBI <= MHIZUKE_SAV(IDX).OUT_D OR MHIZUKE_SAV(IDX).OUT_D = 0)
                       THEN
                         IF BOUT_FLG2 = FALSE THEN
                           IGAKO_KBN := IDX;                        --基準日時点のを最初に見つかったのが対象になる
                           BOUT_FLG2 := TRUE;
                         END IF;
                       END IF;
                     ELSE                                            --今回ので判断
                       IF BOUT_FLG2 = FALSE THEN
                         IGAKO_KBN := IDX;
                         BOUT_FLG2 := TRUE;
                       END IF;
                       MHIZUKE_SAV(IDX)   := MHIZUKE(IDX);
                     END IF;
                   END IF;
                 END LOOP;
               END IF;
               /*****   チェック１：基準日判断  ここまで    ******/
               /*****   チェック２：学年判断  ここから    ******/
               --開始学年より小さいあるいは終了学年より大きい場合、該当個人番号はスキップ
               IF BOUT_FLG2 = TRUE AND (RG.GAKUNEN < IKAISIGAKUNEN OR RG.GAKUNEN > ISHURYOGAKUNEN) THEN
                 BOUT_FLG3 := TRUE;
                 GOTO continue;
               END IF;
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
               /*****   チェック２：学年判断  ここまで    ******/
               /*****   チェック３：任意ビット条件の対象か判断 ここから *****/
               --基準日に該当する且つ任意ビットの指定がある且つ指定条件に該当しなければ、該当個人番号はスキップ
--                IF BOUT_FLG2 = TRUE AND VNINIBIT IS NOT NULL AND GAKUREIBO_RECC.NINIBIT1 != VNINIBIT THEN
--                    BOUT_FLG3 := TRUE;
--                    GOTO continue;
--                END IF;
-- 2024/06/04 ZCZL.wangyunhan Delete end
               /*****   チェック３：任意ビット条件の対象か判断 ここまで *****/
               /*****   チェック４：学校コード条件の対象か判断 ここから *****/
               --基準日には該当するが学校条件に該当しなければ、該当個人番号はスキップ
               --区域外
               IF IGAKO_KBN = 1 AND VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.KUIKIGAI_CD,VKUIKIGAICD) = 0 THEN
                 BOUT_FLG3 := TRUE;
                 GOTO continue;
               END IF;
               --特別支援学校
               IF IGAKO_KBN = 2 AND VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.YOGOGAKO_CD,VYOGOGAKOCD) = 0 THEN
                 BOUT_FLG3 := TRUE;
                 GOTO continue;
               END IF;
               --小学校
               IF IGAKO_KBN = 3 AND VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.SYOGAKO_CD,VSYOGAKOCD) = 0 THEN
                 BOUT_FLG3 := TRUE;
                 GOTO continue;
               END IF;
               --中学校
               IF IGAKO_KBN = 4 AND VGAKO_JOKEN = TRUE AND FUNC_CHECK_GAKO(RG.TYUGAKO_CD,VTYUGAKOCD) = 0 THEN
                 BOUT_FLG3 := TRUE;
                 GOTO continue;
               END IF;
               /*****   チェック４：学校コード条件の対象か判断 ここまで *****/
               --上記のチェックが通らない場合、次のレコードへ行く
               IF BOUT_FLG2 = FALSE THEN  GOTO continue;END IF;
               --条件該当レコードが一件見つかった場合、次へ行かないようにフラグを設定
               BOUT_FLG3 := TRUE;
                IF NPRTN = 0 THEN
                 IRTN := GAAPK0030.FGETATENA(  RG.KOJIN_NO,
                                            'GKB',
                                            ISAKUSEIBI,
                                            RA,
                                            RASO);
                 IWAREKIHIZUKE := 0;    
                 BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                              RA.SEINENGAPI,
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
                 IF RA.SEIBETSU = 1 THEN
                    VSEIBETSU := '男';
                 ELSIF RA.SEIBETSU = 2 THEN
                       VSEIBETSU := '女';
                 END IF;
                 IF RG.HOGOSYA_KOJIN_NO <> 0 THEN
                    IRTN := GAAPK0030.FGETATENA(  RG.HOGOSYA_KOJIN_NO,
                                                'GKB',
                                                ISAKUSEIBI,
                                                RB,
                                                RC);
                      IRTN := GKBFKZKGMGET(1,
                                           RG.ZOKUGARA1,
                                           RG.ZOKUGARA2,
                                           RG.ZOKUGARA3,
                                           RG.ZOKUGARA4,
                                           VZOKUGARAMEI1,
                                           IRTNZOKUGARAHERR1);
                      IRTN := GKBFKZKGMGET(2,
                                           RG.HOGOSYA_ZOKUGARA1,
                                           RG.HOGOSYA_ZOKUGARA2,
                                           RG.HOGOSYA_ZOKUGARA3,
                                           RG.HOGOSYA_ZOKUGARA4,
                                           VZOKUGARAMEI2,
                                           IRTNZOKUGARAHERR2);
--  2024/08/05 ZCZL.YANGXINYU UPDATE START 0.3.000.001:受入検証対応No182
                      IF g_rJSTP.CHOHYOID ='GKB050R001' THEN
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--                         IRET := GKBFKHMCTRL(GAKUREIBO_RECC.HOGOSYA_KOJIN_NO,
                         IRET := GKBFKHMCTRL(GAKUREIBO_RECC.KOJIN_NO,
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
                                             g_rJSTP.CHOHYOID,
                                             --  2024/11/06 ZCZL.ZHANGLEI UPDATE 0.3.000.006:IT_GKB_00474対応
                                             --0,
                                             1,
                                             g_GAKUNENNPOSEIGYO,
                                             o_sSHIMEI_KANA,
                                             o_sSHIMEI_KANJI,
                                             o_sSEINENGAPI);
                      ELSIF g_rJSTP.CHOHYOID ='GKB200R002' THEN
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--                         IRET := GKBFKHMCTRL(GAKUREIBO_RECC.HOGOSYA_KOJIN_NO,
                         IRET := GKBFKHMCTRL(GAKUREIBO_RECC.KOJIN_NO,
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
                                             g_rJSTP.CHOHYOID,
                                             --0,
                                             1,
                                             g_GAKUNEIMEISEIGYO,
                                             o_sSHIMEI_KANA,
                                             o_sSHIMEI_KANJI,
                                             o_sSEINENGAPI);
                      END IF; 
                      MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := o_sSHIMEI_KANA;
                      MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := o_sSHIMEI_KANJI;
--                      MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := RB.SHIMEI_KANA;
--                      MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := RB.SHIMEI_KANJI;
--  2024/08/05 ZCZL.YANGXINYU UPDATE END
                      MGAKUREIBO_WORK(ICNT).CHOMEI := RB.CHOMEI;
                      MGAKUREIBO_WORK(ICNT).BANCHI := RB.BANCHI;
                      MGAKUREIBO_WORK(ICNT).KATAGAKI := RB.KATAGAKI;
                 ELSE
                      -- 保護者個人番号が０のときNULL
                      MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA := NULL;
                      MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI := NULL;
                      MGAKUREIBO_WORK(ICNT).CHOMEI := NULL;
                      MGAKUREIBO_WORK(ICNT).BANCHI := NULL;
                      MGAKUREIBO_WORK(ICNT).KATAGAKI := NULL;
                      VZOKUGARAMEI1 := NULL;
                      VZOKUGARAMEI2 := NULL;
                      RB.GYOSEIKU_CD := 0;
                      RB.SANTEIDANTAI_CD := 0;
                 END IF;
                 BEGIN
                  SELECT GAKUNENMEI
                    INTO VGAKUNENMEI
                    FROM GKBTGAKUNEN
                   WHERE GAKUNEN_CD = GAKUREIBO_RECC.GAKUNEN;
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      VGAKUNENMEI := ' ';
                  END;
                 IF RG.SYOGAKO_CD > 0 THEN 
                 BEGIN
                  SELECT NVL(KYOIKUIINKAI_CD,0)
                    INTO NSYOGAKOKYOIKUIINKAI_CD
                    FROM GKBTSHOGAKKO
                    WHERE SYOGAKO_CD = RG.SYOGAKO_CD;
                  EXCEPTION
                    WHEN OTHERS THEN
                      NSYOGAKOKYOIKUIINKAI_CD := NULL ;
                  END;
                 BEGIN
                  SELECT SYOGAKOMEI
                    INTO VSHOGAKOMEI
                    FROM GKBTSHOGAKKO
                    WHERE SYOGAKO_CD = RG.SYOGAKO_CD;
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      DBMS_OUTPUT.PUT_LINE('該当小学校なし　'||RG.SYOGAKO_CD||' '||RG.KOJIN_NO);
                      VSHOGAKOMEI := ' ';
                  END;
                  END IF;
    -- 小学校入学日
                  IF RG.SYOGAKO_NYUGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                    BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                 RG.SYOGAKO_NYUGAKU_BI,
                                                 VEDIT_GYYMMDD3,
                                                 VEDIT_GYYMMDD2,
                                                 VSYOGAKO_NYUGAKU_BI,
                                                 VKJ_GENGO,
                                                 VKG_GENGO,
                                                 INYUGAKU_NENDO,
                                                 ISEIREKI_YYYY,
                                                 IWAREKI_GYYMM,
                                                 IMM,
                                                 IDD,
                                                 IOWAREKIHIZUKE,
                                                 ISEIREKIHIZUKE);
                  ELSE
                    VSYOGAKO_NYUGAKU_BI :=' ';
                  END IF;
    -- 小学校転入学日
                  IF RG.SYOGAKO_TENNYUGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                    BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                 RG.SYOGAKO_TENNYUGAKU_BI,
                                                 VEDIT_GYYMMDD3,
                                                 VEDIT_GYYMMDD2,
                                                 VSYOGAKO_TENNYUGAKU_BI,
                                                 VKJ_GENGO,
                                                 VKG_GENGO,
                                                 INYUGAKU_NENDO,
                                                 ISEIREKI_YYYY,
                                                 IWAREKI_GYYMM,
                                                 IMM,
                                                 IDD,
                                                 IOWAREKIHIZUKE,
                                                 ISEIREKIHIZUKE);
                  ELSE
                    VSYOGAKO_TENNYUGAKU_BI :=' ';
                  END IF;
    -- 小学校転学日
                  IF RG.SYOGAKO_TENGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.SYOGAKO_TENGAKU_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VSYOGAKO_TENGAKU_BI,
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
                        VSYOGAKO_TENGAKU_BI := ' ';
                  END IF;
    -- 小学校卒業日
                  IF RG.SYOGAKO_SOTSUGYO_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.SYOGAKO_SOTSUGYO_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VSYOGAKO_SOTSUGYO_BI,
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
                        VSYOGAKO_SOTSUGYO_BI := ' ';
                 END IF;
                 IF RG.TYUGAKO_CD > 0 THEN 
                  BEGIN
                   SELECT NVL(KYOIKUIINKAI_CD,0)
                     INTO NTYUGAKOKYOIKUIINKAI_CD
                     FROM GKBTCHUGAKKO
                     WHERE TYUGAKO_CD = RG.TYUGAKO_CD;
                   EXCEPTION
                     WHEN OTHERS THEN
                       NTYUGAKOKYOIKUIINKAI_CD := NULL;
                   END;
                  BEGIN
                   SELECT TYUGAKOMEI
                     INTO VTYUGAKOMEI
                     FROM GKBTCHUGAKKO
                     WHERE TYUGAKO_CD = RG.TYUGAKO_CD;
                   EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                       DBMS_OUTPUT.PUT_LINE('該当中学校なし　'||RG.TYUGAKO_CD||' '||RG.KOJIN_NO);
                       VTYUGAKOMEI := ' ';
                   END;
                  END IF;    
    -- 中学校入学日
                  IF RG.TYUGAKO_NYUGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                    BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                 RG.TYUGAKO_NYUGAKU_BI,
                                                 VEDIT_GYYMMDD3,
                                                 VEDIT_GYYMMDD2,
                                                 VTYUGAKO_NYUGAKU_BI,
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
                    VTYUGAKO_NYUGAKU_BI :=' ';
                  END IF;
    -- 中学校転入学日
                  IF RG.TYUGAKO_TENNYUGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                    BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                 RG.TYUGAKO_TENNYUGAKU_BI,
                                                 VEDIT_GYYMMDD3,
                                                 VEDIT_GYYMMDD2,
                                                 VTYUGAKO_TENNYUGAKU_BI,
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
                    VTYUGAKO_TENNYUGAKU_BI :=' ';
                  END IF;
    -- 中学校転学日
                  IF RG.TYUGAKO_TENGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.TYUGAKO_TENGAKU_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VTYUGAKO_TENGAKU_BI,
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
                        VTYUGAKO_TENGAKU_BI := ' ';
                  END IF;
    -- 中学校卒業日
                  IF RG.TYUGAKO_SOTSUGYO_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.TYUGAKO_SOTSUGYO_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VTYUGAKO_SOTSUGYO_BI,
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
                        VTYUGAKO_SOTSUGYO_BI := ' ';
                  END IF;
                  IF RG.KUIKIGAI_CD > 0 THEN 
                  BEGIN
                   SELECT NVL(KYOIKUIINKAI_CD,0)
                     INTO NKUIKIGAIKYOIKUIINKAI_CD
                     FROM GKBTKUIKIGAI
                     WHERE KUIKIGAI_CD = RG.KUIKIGAI_CD;
                   EXCEPTION
                     WHEN OTHERS THEN
                       NKUIKIGAIKYOIKUIINKAI_CD := NULL;
                   END;
                  BEGIN
                   SELECT KUIKIGAIMEI
                     INTO VKUIKIGAIMEI
                     FROM GKBTKUIKIGAI
                     WHERE KUIKIGAI_CD = RG.KUIKIGAI_CD;
                   EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                       DBMS_OUTPUT.PUT_LINE('該当区域外学校なし　'||RG.KUIKIGAI_CD||' '||RG.KOJIN_NO);
                       VKUIKIGAIMEI := ' ';
                   END;
                   END IF;    
    -- 区域外学校入学日
                  IF RG.KUIKIGAI_NYUGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                  BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                               RG.KUIKIGAI_NYUGAKU_BI,
                                               VEDIT_GYYMMDD3,
                                               VEDIT_GYYMMDD2,
                                               VKUIKIGAI_NYUGAKU_BI,
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
                    VKUIKIGAI_NYUGAKU_BI :=' ';
                  END IF;
    -- 区域外学校転入学日
                  IF RG.KUIKIGAI_TENNYUGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                  BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                               RG.KUIKIGAI_TENNYUGAKU_BI,
                                               VEDIT_GYYMMDD3,
                                               VEDIT_GYYMMDD2,
                                               VKUIKIGAI_TENNYUGAKU_BI,
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
                    VKUIKIGAI_TENNYUGAKU_BI :=' ';
                  END IF;
    -- 区域外学校転学日
                  IF RG.KUIKIGAI_TENGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                  BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                               RG.KUIKIGAI_TENGAKU_BI,
                                               VEDIT_GYYMMDD3,
                                               VEDIT_GYYMMDD2,
                                               VKUIKIGAI_TENGAKU_BI,
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
                    VKUIKIGAI_TENGAKU_BI :=' ';
                  END IF;
    -- 区域外学校退学日
                  IF RG.KUIKIGAI_TAIGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                  BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                               RG.KUIKIGAI_TAIGAKU_BI,
                                               VEDIT_GYYMMDD3,
                                               VEDIT_GYYMMDD2,
                                               VKUIKIGAI_TAIGAKU_BI,
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
                    VKUIKIGAI_TAIGAKU_BI :=' ';
                  END IF;
    -- 区域外学校転退学日
                  IF RG.KUIKIGAI_TENGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.KUIKIGAI_TENGAKU_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VKUIKIGAI_TENTAIGAKU_BI,
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
                        IF RG.KUIKIGAI_TAIGAKU_BI <> 0 THEN
                      IWAREKIHIZUKE := 0;    
                           BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                        RG.KUIKIGAI_TAIGAKU_BI,
                                                        VEDIT_GYYMMDD3,
                                                        VEDIT_GYYMMDD2,
                                                        VKUIKIGAI_TENTAIGAKU_BI,
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
                              VKUIKIGAI_TENTAIGAKU_BI := ' ';
                        END IF;
                  END IF;
    -- 区域外学校卒業日
                  IF RG.KUIKIGAI_SOTSUGYO_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.KUIKIGAI_SOTSUGYO_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VKUIKIGAI_SOTSUGYO_BI,
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
                        VKUIKIGAI_SOTSUGYO_BI := ' ';
                  END IF;
                  IF RG.YOGOGAKO_CD > 0 THEN    
                  BEGIN
                   SELECT NVL(KYOIKUIINKAI_CD,0)
                     INTO NYOGOGAKOKYOIKUIINKAI_CD
                     FROM GKBTYOGOGAKKO
                     WHERE YOGOGAKO_CD = RG.YOGOGAKO_CD;
                   EXCEPTION
                     WHEN OTHERS THEN
                       NYOGOGAKOKYOIKUIINKAI_CD := NULL;
                   END;
                  BEGIN
                   SELECT YOGOGAKOMEI
                     INTO VYOGOGAKOMEI
                     FROM GKBTYOGOGAKKO
                     WHERE YOGOGAKO_CD = RG.YOGOGAKO_CD;
                   EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                       DBMS_OUTPUT.PUT_LINE('該当盲聾養護学校なし　'||RG.YOGOGAKO_CD||' '||RG.KOJIN_NO);
                       VYOGOGAKOMEI := ' ';
                   END;
                   END IF;    
    -- 養護学校入学日
                  IF RG.YOGOGAKO_NYUGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                  BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                               RG.YOGOGAKO_NYUGAKU_BI,
                                               VEDIT_GYYMMDD3,
                                               VEDIT_GYYMMDD2,
                                               VYOGOGAKO_NYUGAKU_BI,
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
                    VYOGOGAKO_NYUGAKU_BI :=' ';
                  END IF;
    -- 養護学校転入学日
                  IF RG.YOGOGAKO_TENNYUGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                  BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                               RG.YOGOGAKO_TENNYUGAKU_BI,
                                               VEDIT_GYYMMDD3,
                                               VEDIT_GYYMMDD2,
                                               VYOGOGAKO_TENNYUGAKU_BI,
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
                    VYOGOGAKO_TENNYUGAKU_BI :=' ';
                  END IF;
    -- 養護学校転学日
                  IF RG.YOGOGAKO_TENGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                  BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                               RG.YOGOGAKO_TENGAKU_BI,
                                               VEDIT_GYYMMDD3,
                                               VEDIT_GYYMMDD2,
                                               VYOGOGAKO_TENGAKU_BI,
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
                    VYOGOGAKO_TENGAKU_BI :=' ';
                  END IF;
    -- 養護学校退学日
                  IF RG.YOGOGAKO_TAIGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                  BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                               RG.YOGOGAKO_TAIGAKU_BI,
                                               VEDIT_GYYMMDD3,
                                               VEDIT_GYYMMDD2,
                                               VYOGOGAKO_TAIGAKU_BI,
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
                    VYOGOGAKO_TAIGAKU_BI :=' ';
                  END IF;
    -- 養護学校転退学日
                  IF RG.YOGOGAKO_TENGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.YOGOGAKO_TENGAKU_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VYOGOGAKO_TENTAIGAKU_BI,
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
                        IF RG.YOGOGAKO_TAIGAKU_BI <> 0 THEN
                      IWAREKIHIZUKE := 0;    
                           BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                        RG.YOGOGAKO_TAIGAKU_BI,
                                                        VEDIT_GYYMMDD3,
                                                        VEDIT_GYYMMDD2,
                                                        VYOGOGAKO_TENTAIGAKU_BI,
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
                              VYOGOGAKO_TENTAIGAKU_BI := ' ';
                        END IF;
                  END IF;
    -- 養護学校卒業日
                  IF RG.YOGOGAKO_SOTSUGYO_BI <> 0 THEN
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.YOGOGAKO_SOTSUGYO_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VYOGOGAKO_SOTSUGYO_BI,
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
                        VYOGOGAKO_SOTSUGYO_BI := ' ';
                  END IF;
                  IF RG.YUYO_KYOKA_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.YUYO_KYOKA_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VYUYO_KYOKA_BI,
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
                        VYUYO_KYOKA_BI := ' ';
                  END IF;
                  IF RG.YUYO_KYOKA_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.YUYO_KYOKA_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VYUYO_KYOKA_BI,
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
                        VYUYO_KYOKA_BI := ' ';
                  END IF;
                  IF RG.YUYO_KAISI_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.YUYO_KAISI_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VYUYO_KAISI_BI,
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
                        VYUYO_KAISI_BI := ' ';
                  END IF;
                  IF RG.YUYO_SYURYO_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.YUYO_SYURYO_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VYUYO_SYURYO_BI,
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
                        VYUYO_SYURYO_BI := ' ';
                  END IF;
                  IF RG.YUYO_FUKUGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.YUYO_FUKUGAKU_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VYUYO_FUKUGAKU_BI,
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
                        VYUYO_FUKUGAKU_BI := ' ';
                  END IF;
                  IF RG.MENJO_KYOKA_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.MENJO_KYOKA_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VMENJO_KYOKA_BI,
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
                        VMENJO_KYOKA_BI := ' ';
                  END IF;
                  IF RG.MENJO_FUKUGAKU_BI <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.MENJO_FUKUGAKU_BI,
                                                  VEDIT_GYYMMDD3,
                                                  VEDIT_GYYMMDD2,
                                                  VMENJO_FUKUGAKU_BI,
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
                        VMENJO_FUKUGAKU_BI := ' ';
                  END IF;
                  IF RG.IDO_BI1 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.IDO_BI1,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VIDO_BI1,               
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
                        VIDO_BI1 := ' ';
                  END IF;
                  IF RG.IDO_BI2 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.IDO_BI2,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VIDO_BI2,               
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
                        VIDO_BI2 := ' ';
                  END IF;
                  IF RG.IDO_BI3 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.IDO_BI3,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VIDO_BI3,               
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
                        VIDO_BI3 := ' ';
                  END IF;
                  IF RG.IDO_BI4 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.IDO_BI4,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VIDO_BI4,               
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
                        VIDO_BI4 := ' ';
                  END IF;
                  IF RG.IDO_BI5 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.IDO_BI5,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VIDO_BI5,               
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
                        VIDO_BI5 := ' ';
                  END IF;
                  IF RG.IDO_BI6 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.IDO_BI6,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VIDO_BI6,               
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
                        VIDO_BI6 := ' ';
                  END IF;
                  IF RG.IDO_BI7 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.IDO_BI7,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VIDO_BI7,               
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
                        VIDO_BI7 := ' ';
                  END IF;
                  IF RG.IDO_BI8 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.IDO_BI8,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VIDO_BI8,               
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
                        VIDO_BI8 := ' ';
                  END IF;
                  IF RG.IDO_BI9 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.IDO_BI9,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VIDO_BI9,               
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
                        VIDO_BI9 := ' ';
                  END IF;
                  IF RG.IDO_BI10 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.IDO_BI10,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VIDO_BI10,              
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
                        VIDO_BI10 := ' ';
                  END IF;
                  IF RG.TOKUSOKU_BI1 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.TOKUSOKU_BI1,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VTOKUSOKU_BI1,          
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
                        VTOKUSOKU_BI1 := ' ';
                  END IF;
                  IF RG.TOKUSOKU_BI2 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.TOKUSOKU_BI2,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VTOKUSOKU_BI2,          
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
                        VTOKUSOKU_BI2 := ' ';
                  END IF;
                  IF RG.TOKUSOKU_BI3 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.TOKUSOKU_BI3,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VTOKUSOKU_BI3,          
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
                        VTOKUSOKU_BI3 := ' ';
                  END IF;
                  IF RG.TOKUSOKU_BI4 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.TOKUSOKU_BI4,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VTOKUSOKU_BI4,          
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
                        VTOKUSOKU_BI4 := ' ';
                  END IF;
                  IF RG.TOKUSOKU_BI5 <> 0 THEN
                    IWAREKIHIZUKE := 0;    
                     BRTN := KKAPK0020.FDAYEDIT( IWAREKIHIZUKE,
                                                  RG.TOKUSOKU_BI5,
                                                  VEDIT_GYYMMDD2,
                                                  VEDIT_GYYMMDD3,
                                                  VTOKUSOKU_BI5,          
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
                        VTOKUSOKU_BI5 := ' ';
                  END IF; 
                  -- 表題の編集
                  IF RG.SYOGAKO_NYUGAKU_BI <> 0 THEN
                     FOR ICNTN IN 1..9 LOOP
                         --就学する年度を表題には表示する
                         NNENDO := INYUGAKU_NENDO;
                         VHYOUJINENDO := KKAPK0020.FNENDOEDIT(0,          --和暦415が入る時は0
                                                               NNENDO,
                                                               3);
                         NGAKUNENNENDO := INYUGAKU_NENDO + ICNTN - 1;
                         VGAKUNENNENDO := KKAPK0020.FNENDOEDIT(0,
                                                                NGAKUNENNENDO,
                                                                2);
                         MNENDO_WORK(ICNTN).NENDO := VGAKUNENNENDO||'年度';
                     END LOOP;
                  ELSE
                    IF RG.SYOGAKO_TENNYUGAKU_BI <> 0 THEN
                                                               
                         NNENDO := KKAPK0020.FNENDO(INYUGAKU_NENDO,1) - RG.SYOGAKO_TENNYUGAKU_GAKUNEN + 1;
                         VHYOUJINENDO := KKAPK0020.FNENDOEDIT(1,
                                                               NNENDO,
                                                               3);
                         FOR ICNTN IN 1..9 LOOP
                            NGAKUNENNENDO := NNENDO + ICNTN - 1;
                            VGAKUNENNENDO := KKAPK0020.FNENDOEDIT(1,
                                                                   NGAKUNENNENDO,
                                                                   2);
                            MNENDO_WORK(ICNTN).NENDO := VGAKUNENNENDO||'年度';
                         END LOOP;
                    END IF;
                        NULL;
                  END IF;
                  --小学校
                  IF IGAKO_KBN = 3 THEN
                      IKAIPEJI_KBN := 1;                   --　1 = 現在小学生
                      IGAKO_CD := RG.SYOGAKO_CD;
                      VGAKOMEI := VSHOGAKOMEI;
                      NKYOIKUIINKAI_CD := NSYOGAKOKYOIKUIINKAI_CD;
                  END IF;
                  --中学校
                  IF IGAKO_KBN = 4 THEN
                      IKAIPEJI_KBN := 2;              --　2 = 現在中学生
                      IGAKO_CD := RG.TYUGAKO_CD;
                      VGAKOMEI := VTYUGAKOMEI;
                      NKYOIKUIINKAI_CD := NTYUGAKOKYOIKUIINKAI_CD;
                  END IF;
                  --区域外学校
                  IF IGAKO_KBN = 1 THEN
                      IKAIPEJI_KBN := 3;              --　3 = 現在区域外学生
                      IGAKO_CD := RG.KUIKIGAI_CD;
                      VGAKOMEI := VKUIKIGAIMEI;
                      NKYOIKUIINKAI_CD := NKUIKIGAIKYOIKUIINKAI_CD;
                  END IF;
                  --養護学校
                  IF IGAKO_KBN = 2 THEN
                      IKAIPEJI_KBN := 4;              --　4 = 現在盲聾養護学生
                      IGAKO_CD := RG.YOGOGAKO_CD;
                      VGAKOMEI := VYOGOGAKOMEI;
                      NKYOIKUIINKAI_CD := NYOGOGAKOKYOIKUIINKAI_CD;
                  END IF;
                  VGYOSEIKU_MEI := GAAPK0030.FGYOSEIKUMEI(RA.SANTEIDANTAI_CD,RA.GYOSEIKU_CD);
                  VHAN_MEI := GAAPK0030.FHANMEI(RA.SANTEIDANTAI_CD,
                                                 RA.HAN_CD);
                  IRTN := GAAPK0030.FJICHINAME(RA.SANTEIDANTAI_CD,VSANTEIDANTAI_MEI);
                 -- 児童生徒個人番号より宛名情報取得
                 IRTN := GAAPK0030.FGETATENA( GAKUREIBO_RECC.HOGOSYA_KOJIN_NO,
                                              'GKB',
                                               ISAKUSEIBI,
                                               RA1,
                                               RA2 );
                 -- 教育委員会情報
        -- 教育委員会情報
                IF NKYOIKUIINKAI_CD IS NOT NULL THEN
                  IRTN_KYOUIKU := KKAPK0030.FPRMSHUTOKU('GKB','00KYOIKUKAI',NKYOIKUIINKAI_CD,ACONSPRM_KYOUIKU,NLENGTH);
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
                      WHILE (NLENGTH < 8) LOOP
                          ACONSPRM_KYOUIKU.EXTEND;
                          ACONSPRM_KYOUIKU(NLENGTH+1) := ' ';
                          NLENGTH := NLENGTH + 1;
                      END LOOP;
                   END IF;
                   MGAKUREIBO_WORK(ICNT).KYOIKUKAI_MEI           := ACONSPRM_KYOUIKU(1); --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(１)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI    := ACONSPRM_KYOUIKU(2); --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(２)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_SHUTHOU_MEI      := ACONSPRM_KYOUIKU(3); --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(３)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_RITSU_MEI        := ACONSPRM_KYOUIKU(4); --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(４)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_YUBIN_NO         := ACONSPRM_KYOUIKU(5); --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(５)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_JUSHO            := ACONSPRM_KYOUIKU(6); --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(６)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_TEL              := ACONSPRM_KYOUIKU(7); --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(７)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_TEL_NAISEN       := ACONSPRM_KYOUIKU(8); --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(８)
                 ELSE
                   MGAKUREIBO_WORK(ICNT).KYOIKUKAI_MEI           := NULL; --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(１)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI    := NULL; --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(２)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_SHUTHOU_MEI      := NULL; --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(３)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_RITSU_MEI        := NULL; --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(４)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_YUBIN_NO         := NULL; --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(５)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_JUSHO            := NULL; --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(６)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_TEL              := NULL; --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(７)
                   MGAKUREIBO_WORK(ICNT).KYOIKU_TEL_NAISEN       := NULL; --教育委員会情報.制御ﾊﾟﾗﾒｰﾀ(８)
                 END IF;
                 -- 連番印字制御
                 NCHOHYO_NO2 := TRIM(RG.CHOHYO_NO);
                 NCHOHYO_NO2 := LPAD(NCHOHYO_NO2,5,' ');
                 IGAKKO_CD2 := TRIM(TO_CHAR(IGAKO_CD));
                 IGAKKO_CD2 := LPAD(IGAKKO_CD2,5,' ');
                 IF ACONSPRM_RENBAN(1) = 0 THEN
                     MGAKUREIBO_WORK(ICNT).HYOJI_CHOHYO_NO := ' ';
                 ELSIF ACONSPRM_RENBAN(1) = 1 THEN
                     MGAKUREIBO_WORK(ICNT).HYOJI_CHOHYO_NO := NCHOHYO_NO2;
                 ELSIF ACONSPRM_RENBAN(1) = 2 THEN
                     MGAKUREIBO_WORK(ICNT).HYOJI_CHOHYO_NO := LTRIM(VGAKOMEI)||'-'||NCHOHYO_NO2;
                 ELSIF ACONSPRM_RENBAN(1) = 3 THEN
                     MGAKUREIBO_WORK(ICNT).HYOJI_CHOHYO_NO := IGAKKO_CD2||'-'||NCHOHYO_NO2;
                 ELSIF ACONSPRM_RENBAN(1) = 4 THEN
                     MGAKUREIBO_WORK(ICNT).HYOJI_CHOHYO_NO := LTRIM(VGAKOMEI)||'-'||LTRIM(VGYOSEIKU_MEI)||'-'||NCHOHYO_NO2;
                 ELSIF ACONSPRM_RENBAN(1) = 5 THEN
                     MGAKUREIBO_WORK(ICNT).HYOJI_CHOHYO_NO := IGAKKO_CD2||'-'||LTRIM(VGYOSEIKU_MEI) ||'-'||NCHOHYO_NO2;
                 ELSE
                     MGAKUREIBO_WORK(ICNT).HYOJI_CHOHYO_NO := ' ';
                 END IF;
                 --基準日「平成○年○月○日」フォーマットに変換
                 IWAREKIHIZUKE := 0;
                 BRTN := KKAPK0020.FDAYEDIT(IWAREKIHIZUKE,  ISAKUSEIBI,
                                             VEDIT_GYYMMDD1, VEDIT_GYYMMDD2,
                                             VEDIT_GYYMMDD3, VKJ_GENGO,
                                             VKG_GENGO,      IWAREKI_YY,
                                             ISEIREKI_YYYY,  IWAREKI_GYYMM,
                                             IMM,            IDD,
                                             IWAREKIHIZUKE,  ISEIREKIHIZUKE );
                 MGAKUREIBO_WORK(ICNT).KIJUN_BI := VEDIT_GYYMMDD3;
                 MGAKUREIBO_WORK(ICNT).KOJIN_NO := RG.KOJIN_NO;


--  2024/08/05 ZCZL.YANGXINYU ADD START 0.3.000.001:受入検証対応No182
                 IF g_rJSTP.CHOHYOID ='GKB050R001' THEN
                    IRET := GKBFKHMCTRL(GAKUREIBO_RECC.KOJIN_NO,
                                        g_rJSTP.CHOHYOID,
                                        0,
                                        g_GAKUNENNPOSEIGYO,
                                        MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA,
                                        MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI,
                                        MGAKUREIBO_WORK(ICNT).HYOJI_SEINENGAPI);
                 ELSIF g_rJSTP.CHOHYOID ='GKB200R002' THEN
                    IRET := GKBFKHMCTRL(GAKUREIBO_RECC.KOJIN_NO,
                                        g_rJSTP.CHOHYOID,
                                        0,
                                        g_GAKUNEIMEISEIGYO,
                                        MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA,
                                        MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI,
                                        MGAKUREIBO_WORK(ICNT).HYOJI_SEINENGAPI);
                 END IF; 
--  2024/08/05 ZCZL.YANGXINYU ADD END
--  2024/08/05 ZCZL.YANGXINYU DELETE START 0.3.000.001:受入検証対応No182
--                 MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA := RA.SHIMEI_KANA;
--                 MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI := RA.SHIMEI_KANJI;
--  2024/08/05 ZCZL.YANGXINYU DELETE END
                 MGAKUREIBO_WORK(ICNT).JIDO_JINKAKU_KBN := RA.JINKAKU_KBN;
                 MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANA := RA.HONMYO_KANA;
                 MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANJI := RA.HONMYO_KANJI;
                 MGAKUREIBO_WORK(ICNT).SEINENGAPI := RA.SEINENGAPI;
--  2024/08/05 ZCZL.YANGXINYU DELETE 0.3.000.001:受入検証対応No182
--                 MGAKUREIBO_WORK(ICNT).HYOJI_SEINENGAPI := VSEINENGAPI;
                 MGAKUREIBO_WORK(ICNT).KANJI_SEINENGAPI := RA.HYOJI_SEINENGAPI;
--  2024/11/21 JPJYS.LIUHUAIQI DELETE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--                 IF RA.JINKAKU_KBN != 0 THEN
--                    --本名・通称名出力制御を取得する。
--                    IRTN  := FUNC_PRMFLGSET(MGAKUREIBO_WORK(ICNT).KOJIN_NO,ACONSPRM_SHIMEI(1),N_NAIYO_CD_JIDO);
--                    PROC_GET_YMD1(RA.JINKAKU_KBN,RA.SEINENGAPI,N_NAIYO_CD_JIDO, MGAKUREIBO_WORK(ICNT).KANJI_SEINENGAPI);
--                 END IF;
--  2024/11/21 JPJYS.LIUHUAIQI DELETE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
                 MGAKUREIBO_WORK(ICNT).SEIBETSU := RA.SEIBETSU;
                 MGAKUREIBO_WORK(ICNT).HYOJI_SEIBETSU := VSEIBETSU;
                 MGAKUREIBO_WORK(ICNT).ZOKUGARAMEI1 := VZOKUGARAMEI1;
                 MGAKUREIBO_WORK(ICNT).JIDO_CHOMEI := RA.CHOMEI;
                 MGAKUREIBO_WORK(ICNT).JIDO_BANCHI := RA.BANCHI;
                 MGAKUREIBO_WORK(ICNT).JIDO_KATAGAKI := RA.KATAGAKI;
                 MGAKUREIBO_WORK(ICNT).HOGOSHA_KOJIN_NO := RG.HOGOSYA_KOJIN_NO;
                 MGAKUREIBO_WORK(ICNT).ZOKUGARAMEI2 := VZOKUGARAMEI2;
                 MGAKUREIBO_WORK(ICNT).SETAI_NO := RA.SETAI_NO;
                 MGAKUREIBO_WORK(ICNT).GAKUNEN_CD := GAKUREIBO_RECC.GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).GAKUNENMEI := VGAKUNENMEI;
                 MGAKUREIBO_WORK(ICNT).GYOSEIKU_CD := RA.GYOSEIKU_CD;
                 MGAKUREIBO_WORK(ICNT).GYOSEIKUMEI := VGYOSEIKU_MEI;
                 MGAKUREIBO_WORK(ICNT).HAN_CD := RA.HAN_CD;
                 MGAKUREIBO_WORK(ICNT).HANMEI := VHAN_MEI;
                 MGAKUREIBO_WORK(ICNT).SANTEIDANTAI_CD := RA.SANTEIDANTAI_CD;
                 MGAKUREIBO_WORK(ICNT).SANTEIDANTAIMEI := VSANTEIDANTAI_MEI;
                 MGAKUREIBO_WORK(ICNT).SYOGAKO_CD := RG.SYOGAKO_CD;
                 MGAKUREIBO_WORK(ICNT).SYOGAKOMEI := VSHOGAKOMEI;
                 MGAKUREIBO_WORK(ICNT).SYOGAKO_NYUGAKU_BI := VSYOGAKO_NYUGAKU_BI;
                 MGAKUREIBO_WORK(ICNT).SYOGAKO_TENNYUGAKU_BI := VSYOGAKO_TENNYUGAKU_BI;       
                 MGAKUREIBO_WORK(ICNT).SYOGAKO_TENGAKU_BI := VSYOGAKO_TENGAKU_BI;
                 MGAKUREIBO_WORK(ICNT).SYOGAKO_SOTSUGYO_BI := VSYOGAKO_SOTSUGYO_BI;
                 MGAKUREIBO_WORK(ICNT).TYUGAKO_CD := RG.TYUGAKO_CD;
                 MGAKUREIBO_WORK(ICNT).TYUGAKOMEI := VTYUGAKOMEI;
                 MGAKUREIBO_WORK(ICNT).TYUGAKO_NYUGAKU_BI := VTYUGAKO_NYUGAKU_BI;
                 MGAKUREIBO_WORK(ICNT).TYUGAKO_TENNYUGAKU_BI := VTYUGAKO_TENNYUGAKU_BI;       
                 MGAKUREIBO_WORK(ICNT).TYUGAKO_TENGAKU_BI := VTYUGAKO_TENGAKU_BI;
                 MGAKUREIBO_WORK(ICNT).TYUGAKO_SOTSUGYO_BI := VTYUGAKO_SOTSUGYO_BI;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_CD := RG.KUIKIGAI_CD;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAIMEI := VKUIKIGAIMEI;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_SETISYA := RG.KUIKIGAI_SETISYA;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_NYUGAKU_BI := VKUIKIGAI_NYUGAKU_BI;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENNYUGAKU_BI := VKUIKIGAI_TENNYUGAKU_BI;     
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENTAIGAKU_BI := VKUIKIGAI_TENTAIGAKU_BI;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENGAKU_BI := VKUIKIGAI_TENGAKU_BI;           
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_TAIGAKU_BI := VKUIKIGAI_TAIGAKU_BI;           
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_SOTSUGYO_BI := VKUIKIGAI_SOTSUGYO_BI;
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_CD := RG.YOGOGAKO_CD;
                 MGAKUREIBO_WORK(ICNT).YOGOGAKOMEI := VYOGOGAKOMEI;
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_SETISYA := RG.YOGOGAKO_SETISYA;
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_NYUGAKU_BI := VYOGOGAKO_NYUGAKU_BI;
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENNYUGAKU_BI := VYOGOGAKO_TENNYUGAKU_BI;     
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENTAIGAKU_BI := VYOGOGAKO_TENTAIGAKU_BI;
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENGAKU_BI := VYOGOGAKO_TENGAKU_BI;           
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_TAIGAKU_BI := VYOGOGAKO_TAIGAKU_BI;           
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_SOTSUGYO_BI := VYOGOGAKO_SOTSUGYO_BI;
                 MGAKUREIBO_WORK(ICNT).YUYO_KYOKA_BI := VYUYO_KYOKA_BI;
                 MGAKUREIBO_WORK(ICNT).YUYO_JIYU := RG.YUYO_JIYU;
                 MGAKUREIBO_WORK(ICNT).YUYO_KAISI_BI := VYUYO_KAISI_BI;
                 MGAKUREIBO_WORK(ICNT).YUYO_SYURYO_BI := VYUYO_SYURYO_BI;
                 MGAKUREIBO_WORK(ICNT).YUYO_FUKUGAKU_BI := VYUYO_FUKUGAKU_BI;
                 MGAKUREIBO_WORK(ICNT).MENJO_KYOKA_BI := VMENJO_KYOKA_BI;
                 MGAKUREIBO_WORK(ICNT).MENJO_JIYU := RG.MENJO_JIYU;
                 MGAKUREIBO_WORK(ICNT).MENJO_FUKUGAKU_BI := VMENJO_FUKUGAKU_BI;
                 MGAKUREIBO_WORK(ICNT).IDO_BI1 := VIDO_BI1;
                 MGAKUREIBO_WORK(ICNT).IDO_JIYU1 := RG.IDO_JIYU1;
                 MGAKUREIBO_WORK(ICNT).IDO_BI2 := VIDO_BI2;
                 MGAKUREIBO_WORK(ICNT).IDO_JIYU2 := RG.IDO_JIYU2;
                 MGAKUREIBO_WORK(ICNT).IDO_BI3 := VIDO_BI3;
                 MGAKUREIBO_WORK(ICNT).IDO_JIYU3 := RG.IDO_JIYU3;
                 MGAKUREIBO_WORK(ICNT).IDO_BI4 := VIDO_BI4;
                 MGAKUREIBO_WORK(ICNT).IDO_JIYU4 := RG.IDO_JIYU4;
                 MGAKUREIBO_WORK(ICNT).IDO_BI5 := VIDO_BI5;
                 MGAKUREIBO_WORK(ICNT).IDO_JIYU5 := RG.IDO_JIYU5;
                 MGAKUREIBO_WORK(ICNT).IDO_BI6 := VIDO_BI6;
                 MGAKUREIBO_WORK(ICNT).IDO_JIYU6 := RG.IDO_JIYU6;
                 MGAKUREIBO_WORK(ICNT).IDO_BI7 := VIDO_BI7;
                 MGAKUREIBO_WORK(ICNT).IDO_JIYU7 := RG.IDO_JIYU7;
                 MGAKUREIBO_WORK(ICNT).IDO_BI8 := VIDO_BI8;
                 MGAKUREIBO_WORK(ICNT).IDO_JIYU8 := RG.IDO_JIYU8;
                 MGAKUREIBO_WORK(ICNT).IDO_BI9 := VIDO_BI9;
                 MGAKUREIBO_WORK(ICNT).IDO_JIYU9 := RG.IDO_JIYU9;
                 MGAKUREIBO_WORK(ICNT).IDO_BI10 := VIDO_BI10;
                 MGAKUREIBO_WORK(ICNT).IDO_JIYU10 := RG.IDO_JIYU10;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI1 := VTOKUSOKU_BI1;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO1 := RG.TOKUSOKU_NAIYO1;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI2 := VTOKUSOKU_BI2;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO2 := RG.TOKUSOKU_NAIYO2;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI3 := VTOKUSOKU_BI3;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO3 := RG.TOKUSOKU_NAIYO3;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI4 := VTOKUSOKU_BI4;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO4 := RG.TOKUSOKU_NAIYO4;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI5 := VTOKUSOKU_BI5;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO5 := RG.TOKUSOKU_NAIYO5;
--  2024/08/05 ZCZL.YANGXINYU ADD START 0.3.000.001:受入検証対応No182
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI6 := VTOKUSOKU_BI6;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO6:= RG.TOKUSOKU_NAIYO6;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI7 := VTOKUSOKU_BI7;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO7:= RG.TOKUSOKU_NAIYO7;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI8 := VTOKUSOKU_BI8;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO8:= RG.TOKUSOKU_NAIYO8;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI9 := VTOKUSOKU_BI9;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO9:= RG.TOKUSOKU_NAIYO9;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI10 := VTOKUSOKU_BI10;
                 MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO10     := RG.TOKUSOKU_NAIYO10;
--  2024/08/05 ZCZL.YANGXINYU ADD END
                 MGAKUREIBO_WORK(ICNT).NENDO := VHYOUJINENDO||'年度';
                 MGAKUREIBO_WORK(ICNT).NENDO1 := MNENDO_WORK(1).NENDO;
                 MGAKUREIBO_WORK(ICNT).NENDO2 := MNENDO_WORK(2).NENDO;
                 MGAKUREIBO_WORK(ICNT).NENDO3 := MNENDO_WORK(3).NENDO;
                 MGAKUREIBO_WORK(ICNT).NENDO4 := MNENDO_WORK(4).NENDO;
                 MGAKUREIBO_WORK(ICNT).NENDO5 := MNENDO_WORK(5).NENDO;
                 MGAKUREIBO_WORK(ICNT).NENDO6 := MNENDO_WORK(6).NENDO;
                 MGAKUREIBO_WORK(ICNT).NENDO7 := MNENDO_WORK(7).NENDO;
                 MGAKUREIBO_WORK(ICNT).NENDO8 := MNENDO_WORK(8).NENDO;
                 MGAKUREIBO_WORK(ICNT).NENDO9 := MNENDO_WORK(9).NENDO;
                 MGAKUREIBO_WORK(ICNT).KAIPEJI_KBN := IKAIPEJI_KBN;
                 MGAKUREIBO_WORK(ICNT).KAIPEJI_CD := ' ';
                 MGAKUREIBO_WORK(ICNT).KAIPEJI := ' ';
                 MGAKUREIBO_WORK(ICNT).RENBAN := 0;
                 MGAKUREIBO_WORK(ICNT).GAKO_CD := IGAKO_CD;
                 MGAKUREIBO_WORK(ICNT).GAKOMEI := VGAKOMEI;
                 -- 児童行政区コード、行政区名
                 MGAKUREIBO_WORK(ICNT).CD1 := RA.GYOSEIKU_CD;
                 MGAKUREIBO_WORK(ICNT).MEISHO1 := GAAPK0030.FGYOSEIKUMEI(RA.SANTEIDANTAI_CD,RA.GYOSEIKU_CD);
                 -- 保護者行政区コード、行政区名
                 MGAKUREIBO_WORK(ICNT).CD2 := RB.GYOSEIKU_CD;
                 MGAKUREIBO_WORK(ICNT).MEISHO2 := GAAPK0030.FGYOSEIKUMEI(RB.SANTEIDANTAI_CD,RB.GYOSEIKU_CD);
                 MGAKUREIBO_WORK(ICNT).CD3 := NULL;
                 MGAKUREIBO_WORK(ICNT).MEISHO3 := '';
                 MGAKUREIBO_WORK(ICNT).HOGOSHA_JINKAKU_KBN := RA1.JINKAKU_KBN;
                 MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANA := RA1.HONMYO_KANA;
                 MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANJI := RA1.HONMYO_KANJI;
                 MGAKUREIBO_WORK(ICNT).SYOGAKO_TENNYUGAKU_GAKUNEN := RG.SYOGAKO_TENNYUGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).SYOGAKO_TENGAKU_GAKUNEN := RG.SYOGAKO_TENGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).TYUGAKO_TENNYUGAKU_GAKUNEN := RG.TYUGAKO_TENNYUGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).TYUGAKO_TENGAKU_GAKUNEN := RG.TYUGAKO_TENGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENNYUGAKU_GAKUNEN := RG.KUIKIGAI_TENNYUGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENGAKU_GAKUNEN := RG.KUIKIGAI_TENGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_TAIGAKU_GAKUNEN := RG.KUIKIGAI_TAIGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENNYUGAKU_GAKUNEN := RG.YOGOGAKO_TENNYUGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENGAKU_GAKUNEN := RG.YOGOGAKO_TENGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).YOGOGAKO_TAIGAKU_GAKUNEN := RG.YOGOGAKO_TAIGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).SHUGAKU_ZYOKYO := REPLACE(REPLACE(REPLACE(RG.SHUGAKU, chr(10), '#'), chr(13), '#'),'##','#');  
                 MGAKUREIBO_WORK(ICNT).IDO_ZIYU := REPLACE(REPLACE(REPLACE(RG.IDOJIKO, chr(10), '#'), chr(13), '#'),'##','#');   
   
--2024/06/12 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--                  MGAKUREIBO_WORK(ICNT).GAKKYU_CD := GAKUREIBO_RECC.NINIBIT1;
                 MGAKUREIBO_WORK(ICNT).CHOHYO_NO := RG.CHOHYO_NO;
                 --児童前住所
                 MGAKUREIBO_WORK(ICNT).JIDO_ZENJUSHO := FUNC_GET_ZENJUSHO(RG.KOJIN_NO);
                 --保護者前住所
                 MGAKUREIBO_WORK(ICNT).HOGOSHA_ZENJUSHO := FUNC_GET_ZENJUSHO(RG.HOGOSYA_KOJIN_NO);
                 IRTN := GAAPK0030.FGETATENA(RG.KOJIN_NO, 'GKB', TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')), o_RATENA_REC, o_RSOFU_REC);
                 MGAKUREIBO_WORK(ICNT).JINKAKU_KBN := o_RATENA_REC.JINKAKU_KBN;
--  2024/08/05 ZCZL.YANGXINYU ADD START 0.3.000.001:受入検証対応No182
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.003:8月1日認識合わせの横展開
--                 MGAKUREIBO_WORK(ICNT).S_TAIGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.S_TAIGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).S_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.S_TAIGAKU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).T_TAIGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.T_TAIGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).T_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.T_TAIGAKU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_MEI := GKAFKGKOGTEQ(1,GAKUREIBO_RECC.KUIKIGAI_S_CD);
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_NYUGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.KUIKIGAI_S_NYUGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.KUIKIGAI_S_TENNYU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_S_TENNYU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.KUIKIGAI_S_TENGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_S_TENGAKU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.KUIKIGAI_S_TAIGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_S_TAIGAKU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_SOTSUGYO_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.KUIKIGAI_S_SOTSUGYO_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_MEI := GKAFKGKOGTEQ(2,GAKUREIBO_RECC.KUIKIGAI_T_CD);
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_NYUGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.KUIKIGAI_T_NYUGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.KUIKIGAI_T_TENNYU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_T_TENNYU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.KUIKIGAI_T_TENGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_T_TENGAKU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.KUIKIGAI_T_TAIGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_T_TAIGAKU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_SOTSUGYO_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.KUIKIGAI_T_SOTSUGYO_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).YOGO_S_MEI := GKAFKGKOGTEQ(3,GAKUREIBO_RECC.SHIEN_S_CD);
--                 MGAKUREIBO_WORK(ICNT).YOGO_S_NYUGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.SHIEN_S_NYUGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.SHIEN_S_NYUGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_GAKUNEN := GAKUREIBO_RECC.SHIEN_S_TENNYU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.SHIEN_S_TENGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_GAKUNEN := GAKUREIBO_RECC.SHIEN_S_TENGAKU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.SHIEN_S_TAIGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.SHIEN_S_TAIGAKU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).YOGO_S_SOTSUGYO_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.SHIEN_S_SOTSUGYO_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).YOGO_T_MEI := GKAFKGKOGTEQ(4,GAKUREIBO_RECC.SHIEN_T_CD);
--                 MGAKUREIBO_WORK(ICNT).YOGO_T_NYUGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.SHIEN_T_NYUGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.SHIEN_T_TENNYU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_GAKUNEN := GAKUREIBO_RECC.SHIEN_T_TENNYU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.SHIEN_T_TENGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_GAKUNEN := GAKUREIBO_RECC.SHIEN_T_TENGAKU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.SHIEN_T_TAIGAKU_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.SHIEN_T_TAIGAKU_GAKUNEN;
--                 MGAKUREIBO_WORK(ICNT).YOGO_T_SOTSUGYO_BI := TO_CHAR(TO_DATE(GAKUREIBO_RECC.SHIEN_T_SOTSUGYO_BI,'YYYYMMDD'), 'YYYY/MM/DD');
--                 MGAKUREIBO_WORK(ICNT).GAKKO_KBN_CD := RG.GAKKO_KBN_CD;

                 MGAKUREIBO_WORK(ICNT).S_TAIGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.S_TAIGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).S_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.S_TAIGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).T_TAIGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.T_TAIGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).T_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.T_TAIGAKU_GAKUNEN;
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_MEI := GKAFKGKOGTEQ(1,GAKUREIBO_RECC.KUIKIGAI_S_CD);
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_MEI := GKAFKGKOGTEQ(4,GAKUREIBO_RECC.KUIKIGAI_S_CD);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_NYUGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.KUIKIGAI_S_NYUGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.KUIKIGAI_S_TENNYU_BI);
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_S_TENNYU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.KUIKIGAI_S_TENGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_S_TENGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.KUIKIGAI_S_TAIGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_S_TAIGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_SOTSUGYO_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.KUIKIGAI_S_SOTSUGYO_BI);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_MEI := GKAFKGKOGTEQ(2,GAKUREIBO_RECC.KUIKIGAI_T_CD);
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_MEI := GKAFKGKOGTEQ(4,GAKUREIBO_RECC.KUIKIGAI_T_CD);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_NYUGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.KUIKIGAI_T_NYUGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.KUIKIGAI_T_TENNYU_BI);
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_T_TENNYU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.KUIKIGAI_T_TENGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_T_TENGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.KUIKIGAI_T_TAIGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.KUIKIGAI_T_TAIGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_SOTSUGYO_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.KUIKIGAI_T_SOTSUGYO_BI);
                 MGAKUREIBO_WORK(ICNT).YOGO_S_MEI := GKAFKGKOGTEQ(3,GAKUREIBO_RECC.SHIEN_S_CD);
                 MGAKUREIBO_WORK(ICNT).YOGO_S_NYUGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.SHIEN_S_NYUGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.SHIEN_S_NYUGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_GAKUNEN := GAKUREIBO_RECC.SHIEN_S_TENNYU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.SHIEN_S_TENGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_GAKUNEN := GAKUREIBO_RECC.SHIEN_S_TENGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.SHIEN_S_TAIGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.SHIEN_S_TAIGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).YOGO_S_SOTSUGYO_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.SHIEN_S_SOTSUGYO_BI);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--                 MGAKUREIBO_WORK(ICNT).YOGO_T_MEI := GKAFKGKOGTEQ(4,GAKUREIBO_RECC.SHIEN_T_CD);
                 MGAKUREIBO_WORK(ICNT).YOGO_T_MEI := GKAFKGKOGTEQ(3,GAKUREIBO_RECC.SHIEN_T_CD);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
                 MGAKUREIBO_WORK(ICNT).YOGO_T_NYUGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.SHIEN_T_NYUGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.SHIEN_T_TENNYU_BI);
                 MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_GAKUNEN := GAKUREIBO_RECC.SHIEN_T_TENNYU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.SHIEN_T_TENGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_GAKUNEN := GAKUREIBO_RECC.SHIEN_T_TENGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.SHIEN_T_TAIGAKU_BI);
                 MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_GAKUNEN := GAKUREIBO_RECC.SHIEN_T_TAIGAKU_GAKUNEN;
                 MGAKUREIBO_WORK(ICNT).YOGO_T_SOTSUGYO_BI := FUNC_CONV_DATE(GAKUREIBO_RECC.SHIEN_T_SOTSUGYO_BI);
                 MGAKUREIBO_WORK(ICNT).GAKKO_KBN_CD := RG.GAKKO_KBN_CD;
--  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE END
--  2024/08/05 ZCZL.YANGXINYU ADD END
--2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
--  2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
                  --IF VSOTSUGYOYMD IS NULL THEN
                  IF VSOTSUGYOYMD IS NULL  OR VSOTSUGYOYMD = 0 THEN
--  2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応 
                    IRET := GAAPK0030.FGETDV(MGAKUREIBO_WORK(ICNT).KOJIN_NO,MGAKUREIBO_WORK(ICNT).SETAI_NO,
                                   TO_CHAR(SYSDATE,'YYYYMMDD'),'GBK',0,ISETAIKBN,IYOKUSIKBN,IDOYOKUKBN,IHAKKOYOKUKBN,
                                   ISYOUKOUYOKUSIKBN,ISHORIBICYUIKBN);
                  ELSE
                    IRET := GAAPK0030.FGETDV(MGAKUREIBO_WORK(ICNT).KOJIN_NO,MGAKUREIBO_WORK(ICNT).SETAI_NO,
                                   VSOTSUGYOYMD,'GBK',0,ISETAIKBN,IYOKUSIKBN,IDOYOKUKBN,IHAKKOYOKUKBN,
                                   ISYOUKOUYOKUSIKBN,ISHORIBICYUIKBN);
                  END IF;
-- 2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
                  --IF IYOKUSIKBN NOT IN (1,2) THEN
                  IF 0 < IYOKUSIKBN AND  IYOKUSIKBN < 99 THEN  
-- 2025/06/04 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                    MNENDO_WORK(ICNT).TAISHOSHA_KBN := '対象';
                    MGAKUREIBO_WORK(ICNT).TAISHOSHA_KBN := '対象';
                  ELSE
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                    MNENDO_WORK(ICNT).TAISHOSHA_KBN := '対象ではない';
                    MGAKUREIBO_WORK(ICNT).TAISHOSHA_KBN := '対象ではない';
                  END IF;
                   --支援措置対象者情報取得する
                I_RTN := FUNC_GACTKANRI_WK;
                 IF I_RTN = 0 THEN
                  --FOR i IN 1..GACTKANRI_RECC.COUNT LOOP
                  FOR i IN 1..VSETAIYOKUSHIKBN.COUNT LOOP
                    --支援措置申出者管理_申出者情報に情報を登録されている場合
-- 2025/06/04 CTC.LIUJUNHAO ADD START 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
                    --IF VTOROKU_GYOMU(i) IS NOT NULL THEN
                    IF VTOROKU_GYOMU(i) IS NOT NULL OR VSHIENSOCHIKBN(i) IS NOT NULL OR VTAISHOSHAKBN(i) IS NOT NULL THEN
-- 2025/06/04 CTC.LIUJUNHAO ADD END 1.0.007.000:GKB_QA13919_全員が支援措置対象者の旨を印字される対応
                      IF VSHIENSOCHIKAISHIBI(i) <> 99999999 THEN 
                        nGAITO_KARA := TO_NUMBER(VSHIENSOCHIKAISHIBI(i));
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                        MNENDO_WORK(ICNT).GAITO_KARA  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VSHIENSOCHIKAISHIBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);              --支援措置開始年月日
                        --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.003:8月1日認識合わせの横展開
                        --MGAKUREIBO_WORK(ICNT).GAITO_KARA  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VSHIENSOCHIKAISHIBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);              --支援措置開始年月日
                        MGAKUREIBO_WORK(ICNT).GAITO_KARA  := KKAPK0020.FDateFmt(FUNC_CONV_DATE(VSHIENSOCHIKAISHIBI(i)), 12);              --支援措置開始年月日
                      END IF;
                       IF VSHIENSOCHIKAISHIBI(i) IS NULL AND VKARISHIENSOCHIKAISHIBI(i) <> 99999999 THEN 
                        nGAITO_KARA := TO_NUMBER(VKARISHIENSOCHIKAISHIBI(i));
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                        MNENDO_WORK(ICNT).GAITO_KARA  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VKARISHIENSOCHIKAISHIBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);          --支援措置開始年月日
                        --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.003:8月1日認識合わせの横展開
                        --MGAKUREIBO_WORK(ICNT).GAITO_KARA  := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VKARISHIENSOCHIKAISHIBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);          --支援措置開始年月日
                        MGAKUREIBO_WORK(ICNT).GAITO_KARA  := KKAPK0020.FDateFmt(FUNC_CONV_DATE(VKARISHIENSOCHIKAISHIBI(i)), 12);          --支援措置開始年月日
                      END IF;
                       IF VSHIENSOCHIKAIJOBI(i) IS NULL THEN
                        nGAITO_MADE := TO_NUMBER(VSHIENSOCHIKAIJOBI(i));
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                        MNENDO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VSHIENSOCHIKAIJOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);                --支援措置終了年月日
                        --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.003:8月1日認識合わせの横展開
                        --MGAKUREIBO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VSHIENSOCHIKAIJOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);                --支援措置終了年月日
                        MGAKUREIBO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(FUNC_CONV_DATE(VSHIENSOCHIKAIJOBI(i)), 12);                --支援措置終了年月日
                      END IF;
                       IF VSHIENSOCHIKAIJOBI(i) IS NULL AND VSHIENSOCHISHURYOBI(i) <> 99999999 THEN
                        nGAITO_MADE := TO_NUMBER(VSHIENSOCHISHURYOBI(i));
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                        MNENDO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VSHIENSOCHISHURYOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);               --支援措置終了年月日
                        --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.003:8月1日認識合わせの横展開
                        --MGAKUREIBO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VSHIENSOCHISHURYOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);               --支援措置終了年月日
                        MGAKUREIBO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(FUNC_CONV_DATE(VSHIENSOCHISHURYOBI(i)), 12);               --支援措置終了年月日
                      END IF;
                      IF VSHIENSOCHIKAIJOBI(i) IS NULL AND VSHIENSOCHISHURYOBI(i) IS NULL AND VKARISHIENSOCHISHURYOBI(i) <> 99999999 THEN
                        nGAITO_MADE := TO_NUMBER(VKARISHIENSOCHISHURYOBI(i));
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                       MNENDO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VKARISHIENSOCHISHURYOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);            --支援措置終了年月日
                       --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE 0.3.000.003:8月1日認識合わせの横展開
                       --MGAKUREIBO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VKARISHIENSOCHISHURYOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);            --支援措置終了年月日
                       MGAKUREIBO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(FUNC_CONV_DATE(VKARISHIENSOCHISHURYOBI(i)), 12);            --支援措置終了年月日
                      END IF;
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
                      IF MGAKUREIBO_WORK(ICNT).GAITO_MADE IS NULL AND MGAKUREIBO_WORK(ICNT).GAITO_KARA IS NULL THEN
                       MGAKUREIBO_WORK(ICNT).SHIEN_KBN := NULL;                                                   --支援措置区分
                      ELSE
                           IF nGAITO_KARA <= TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) AND nGAITO_MADE >= TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) THEN
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                             MNENDO_WORK(ICNT).SHIEN_KBN := '支援中';                                             --支援措置区分
                             MGAKUREIBO_WORK(ICNT).SHIEN_KBN := '支援中';                                             --支援措置区分
                           ELSIF nGAITO_MADE < TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')) THEN
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                             MNENDO_WORK(ICNT).SHIEN_KBN := '支援終了';                                           --支援措置区分
                             MGAKUREIBO_WORK(ICNT).SHIEN_KBN := '支援終了';                                           --支援措置区分
                           END IF;
                      END IF;
                     EXIT;
                      --支援措置申出者管理_申出者情報に情報を登録されてない場合
                    ELSIF VTOROKU_GYOMU(i) IS NULL THEN
                      nGAITO_KARA := TO_NUMBER(VKARISHIENSOCHIKAISHIBI(i));
                      nGAITO_MADE := TO_NUMBER(VSHIENSOCHISHURYOBI(i));
--  2024/08/05 ZCZL.YANGXINYU ADD START 0.3.000.001:受入検証対応No182
--                      MNENDO_WORK(ICNT).GAITO_KARA := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VKARISHIENSOCHIKAISHIBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);            --支援措置開始年月日(その他業務)
--                      MNENDO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VSHIENSOCHISHURYOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);            --支援措置終了年月日(その他業務)
--                      IF MNENDO_WORK(ICNT).GAITO_MADE IS NULL AND MNENDO_WORK(ICNT).GAITO_KARA IS NULL THEN
--                       MNENDO_WORK(ICNT).SHIEN_KBN := NULL;                                                   --支援措置区分
                      --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.003:8月1日認識合わせの横展開
                      --MGAKUREIBO_WORK(ICNT).GAITO_KARA := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VKARISHIENSOCHIKAISHIBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);            --支援措置開始年月日(その他業務)
                      --MGAKUREIBO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(TO_CHAR(TO_DATE(VSHIENSOCHISHURYOBI(i),'YYYY/MM/DD'),'YYYY/MM/DD'), 12);            --支援措置終了年月日(その他業務)
                      MGAKUREIBO_WORK(ICNT).GAITO_KARA := KKAPK0020.FDateFmt(FUNC_CONV_DATE(VKARISHIENSOCHIKAISHIBI(i)), 12);            --支援措置開始年月日(その他業務)
                      MGAKUREIBO_WORK(ICNT).GAITO_MADE := KKAPK0020.FDateFmt(FUNC_CONV_DATE(VSHIENSOCHISHURYOBI(i)), 12);            --支援措置終了年月日(その他業務)
                      --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE END
                      IF MGAKUREIBO_WORK(ICNT).GAITO_MADE IS NULL AND MGAKUREIBO_WORK(ICNT).GAITO_KARA IS NULL THEN
                       MGAKUREIBO_WORK(ICNT).SHIEN_KBN := NULL;                                                   --支援措置区分
--  2024/08/05 ZCZL.YANGXINYU ADD END
                      ELSE
                        IF nGAITO_KARA <= TO_NUMBER(VSOTSUGYOYMD) AND nGAITO_MADE >= TO_NUMBER(VSOTSUGYOYMD) THEN
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                           MNENDO_WORK(ICNT).SHIEN_KBN := '支援中';                                             --支援措置区分
                           MGAKUREIBO_WORK(ICNT).SHIEN_KBN := '支援中';                                             --支援措置区分
                        ELSIF nGAITO_MADE < TO_NUMBER(VSOTSUGYOYMD) THEN
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--                           MNENDO_WORK(ICNT).SHIEN_KBN := '支援終了'; 
                           MGAKUREIBO_WORK(ICNT).SHIEN_KBN := '支援終了';
                        END IF;
                      END IF;
                    END IF;
                  END LOOP;
                ELSE
                  --支援措置対象者情報で取得できない場合
--  2024/08/05 ZCZL.YANGXINYU UPDATE START 0.3.000.001:受入検証対応No182
--                  MNENDO_WORK(ICNT).GAITO_KARA := NULL;
--                  MNENDO_WORK(ICNT).GAITO_MADE := NULL;
                  MGAKUREIBO_WORK(ICNT).GAITO_KARA := NULL;
                  MGAKUREIBO_WORK(ICNT).GAITO_MADE := NULL;
--  2024/08/05 ZCZL.YANGXINYU UPDATE END
                END IF;               
--2024/06/04 ZCZL.wangyunhan Add end                         
                 ICNT := ICNT + 1;               -- カウントアップ
                 IFRET := c_ISUCCESS;              -- 正常終了
            ELSE
                  NULL;
            END IF;
            <<continue>>
              NULL;
            END LOOP;
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
    --  機能概要      : 学齢簿ワーク中間テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------------------------------
    FUNCTION FUNC_INSERT_JIDO_WK RETURN NUMBER IS
        IFRET               PLS_INTEGER;                -- 戻り値
        IRET                PLS_INTEGER;                -- 戻り値
        BRET                BOOLEAN;                    -- 戻り値
        ICNT                BINARY_INTEGER;             -- 戻り値
        IMAX                BINARY_INTEGER;             -- 戻り値
        IMIN                BINARY_INTEGER;             -- 戻り値
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        ISETAIKBN           PLS_INTEGER;
        IYOKUSIKBN          PLS_INTEGER;
        IDOYOKUKBN          PLS_INTEGER;
        IHAKKOYOKUKBN       PLS_INTEGER;
        ISYOUKOUYOKUSIKBN   PLS_INTEGER;
        ISHORIBICYUIKBN     PLS_INTEGER;
-- 2024/06/04 ZCZL.wangyunhan Add end
    BEGIN
        IFRET := c_ISUCCESS;                  -- 正常終了
        -- ワーク領域の最終位置を取得
        IMAX := MGAKUREIBO_WORK.LAST;
        -- ワーク領域の先頭位置を取得
        IMIN := MGAKUREIBO_WORK.FIRST;

        BEGIN
            -- ワーク領域の件数分繰り返し処理を行う
          FOR ICNT IN IMIN..IMAX LOOP
                INSERT INTO
                GKBWGAKUREIBO
       (
        KOJIN_NO,
        JIDO_SHIMEI_KANA,
        JIDO_SHIMEI_KANJI,
        SEINENGAPI,
        HYOJI_SEINENGAPI,
        KANJI_SEINENGAPI,
        SEIBETSU,
        HYOJI_SEIBETSU,
        ZOKUGARAMEI1,
        JIDO_CHOMEI,
        JIDO_BANCHI,
        JIDO_KATAGAKI,
        HOGOSHA_KOJIN_NO,
        HOGOSHA_SHIMEI_KANA,
        HOGOSHA_SHIMEI_KANJI,
        ZOKUGARAMEI2,
        CHOMEI,
        BANCHI,
        KATAGAKI,
        SETAI_NO,
        GAKUNEN_CD,
        GAKUNENMEI,
        GYOSEIKU_CD,
        GYOSEIKUMEI,
        HAN_CD,
        HANMEI,
        SANTEIDANTAI_CD,
        SANTEIDANTAIMEI,
        SYOGAKO_CD,
        SYOGAKOMEI,
        SYOGAKO_NYUGAKU_BI,
        SYOGAKO_TENNYUGAKU_BI,              
        SYOGAKO_TENGAKU_BI,
        SYOGAKO_SOTSUGYO_BI,
        TYUGAKO_CD,
        TYUGAKOMEI,
        TYUGAKO_NYUGAKU_BI,
        TYUGAKO_TENNYUGAKU_BI,              
        TYUGAKO_TENGAKU_BI,
        TYUGAKO_SOTSUGYO_BI,
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--         KUIKIGAI_CD,
--         KUIKIGAIMEI,
-- 2024/06/04 ZCZL.wangyunhan Delete end 
        KUIKIGAI_SETISYA,
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--         KUIKIGAI_NYUGAKU_BI,
--         KUIKIGAI_TENNYUGAKU_BI,             
--         KUIKIGAI_TENTAIGAKU_BI,
--         KUIKIGAI_TENGAKU_BI,                
--         KUIKIGAI_TAIGAKU_BI,                
--         KUIKIGAI_SOTSUGYO_BI,
--         YOGOGAKO_CD,
--         YOGOGAKOMEI,
-- 2024/06/04 ZCZL.wangyunhan Delete end 
        YOGOGAKO_SETISYA,
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--         YOGOGAKO_NYUGAKU_BI,
--         YOGOGAKO_TENNYUGAKU_BI,             
--         YOGOGAKO_TENTAIGAKU_BI,
--         YOGOGAKO_TENGAKU_BI,                
--         YOGOGAKO_TAIGAKU_BI,                
--         YOGOGAKO_SOTSUGYO_BI,
-- 2024/06/04 ZCZL.wangyunhan Delete end 
        YUYO_KYOKA_BI,
        YUYO_JIYU,
        YUYO_KAISI_BI,
        YUYO_SYURYO_BI,
        YUYO_FUKUGAKU_BI,
        MENJO_KYOKA_BI,
        MENJO_JIYU,
        MENJO_FUKUGAKU_BI,
        IDO_BI1,
        IDO_JIYU1,
        IDO_BI2,
        IDO_JIYU2,
        IDO_BI3,
        IDO_JIYU3,
        IDO_BI4,
        IDO_JIYU4,
        IDO_BI5,
        IDO_JIYU5,
        IDO_BI6,
        IDO_JIYU6,
        IDO_BI7,
        IDO_JIYU7,
        IDO_BI8,
        IDO_JIYU8,
        IDO_BI9,
        IDO_JIYU9,
        IDO_BI10,
        IDO_JIYU10,
        TOKUSOKU_BI1,
        TOKUSOKU_NAIYO1,
        TOKUSOKU_BI2,
        TOKUSOKU_NAIYO2,
        TOKUSOKU_BI3,
        TOKUSOKU_NAIYO3,
        TOKUSOKU_BI4,
        TOKUSOKU_NAIYO4,
        TOKUSOKU_BI5,
        TOKUSOKU_NAIYO5,
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        TOKUSOKU_BI6,
        TOKUSOKU_NAIYO6,
        TOKUSOKU_BI7,
        TOKUSOKU_NAIYO7,
        TOKUSOKU_BI8,
        TOKUSOKU_NAIYO8,
        TOKUSOKU_BI9,
        TOKUSOKU_NAIYO9,
        TOKUSOKU_BI10,
        TOKUSOKU_NAIYO10,
-- 2024/06/04 ZCZL.wangyunhan Add end 
        NENDO,
        NENDO1,
        NENDO2,
        NENDO3,
        NENDO4,
        NENDO5,
        NENDO6,
        NENDO7,
        NENDO8,
        NENDO9,
        KAIPEJI_KBN,
        KAIPEJI_CD,
        KAIPEJI,
        RENBAN,
        GAKO_CD,
        GAKOMEI
        ,
        CD1,
        MEISHO1,
        CD2,
        MEISHO2,
        CD3,
        MEISHO3
        , JIDO_JINKAKU_KBN
        , JIDO_HONMYO_KANA
        , JIDO_HONMYO_KANJI ,
        HOGOSHA_JINKAKU_KBN,
        HOGOSHA_HONMYO_KANA,
        HOGOSHA_HONMYO_KANJI,
        SYOGAKO_TENNYUGAKU_GAKUNEN,
        SYOGAKO_TENGAKU_GAKUNEN,
        TYUGAKO_TENNYUGAKU_GAKUNEN,
        TYUGAKO_TENGAKU_GAKUNEN,
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--         KUIKIGAI_TENNYUGAKU_GAKUNEN,
--         KUIKIGAI_TENGAKU_GAKUNEN,
--         KUIKIGAI_TAIGAKU_GAKUNEN,
--         YOGOGAKO_TENNYUGAKU_GAKUNEN,
--         YOGOGAKO_TENGAKU_GAKUNEN,
--         YOGOGAKO_TAIGAKU_GAKUNEN,
-- 2024/06/04 ZCZL.wangyunhan Delete end 
        SHUGAKU_ZYOKYO,
        IDO_ZIYU,
        GAKKYU_CD,
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
        KIJUN_BI,
        JIDO_ZENJUSHO,          --児童前住所
        HOGOSHA_ZENJUSHO        --保護者前住所
        ,JINKAKU_KBN,
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        S_TAIGAKU_BI,
        S_TAIGAKU_GAKUNEN,
        T_TAIGAKU_BI,
        T_TAIGAKU_GAKUNEN,
        KUIKIGAI_S_MEI,
        KUIKIGAI_S_NYUGAKU_BI,
        KUIKIGAI_S_TENNYU_BI,
        KUIKIGAI_S_TENNYU_GAKUNEN,
        KUIKIGAI_S_TENGAKU_BI,
        KUIKIGAI_S_TENGAKU_GAKUNEN,
        KUIKIGAI_S_TAIGAKU_BI,
        KUIKIGAI_S_TAIGAKU_GAKUNEN,
        KUIKIGAI_S_SOTSUGYO_BI,
        KUIKIGAI_T_MEI,
        KUIKIGAI_T_NYUGAKU_BI,
        KUIKIGAI_T_TENNYU_BI,
        KUIKIGAI_T_TENNYU_GAKUNEN,
        KUIKIGAI_T_TENGAKU_BI,
        KUIKIGAI_T_TENGAKU_GAKUNEN,
        KUIKIGAI_T_TAIGAKU_BI,
        KUIKIGAI_T_TAIGAKU_GAKUNEN,
        KUIKIGAI_T_SOTSUGYO_BI,
        YOGO_S_MEI,
        YOGO_S_NYUGAKU_BI,
        YOGO_S_TENNYU_BI,
        YOGO_S_TENNYU_GAKUNEN,
        YOGO_S_TENGAKU_BI,
        YOGO_S_TENGAKU_GAKUNEN,
        YOGO_S_TAIGAKU_BI,
        YOGO_S_TAIGAKU_GAKUNEN,
        YOGO_S_SOTSUGYO_BI,
        YOGO_T_MEI,
        YOGO_T_NYUGAKU_BI,
        YOGO_T_TENNYU_BI,
        YOGO_T_TENNYU_GAKUNEN,
        YOGO_T_TENGAKU_BI,
        YOGO_T_TENGAKU_GAKUNEN,
        YOGO_T_TAIGAKU_BI,
        YOGO_T_TAIGAKU_GAKUNEN,
        YOGO_T_SOTSUGYO_BI,
        SHIEN_KBN,
        TAISHOSHA_KBN,
        GAITO_KARA,
        GAITO_MADE,
        GAKKO_KBN_CD
-- 2024/06/04 ZCZL.wangyunhan Add end 
        )
       VALUES
       (
       MGAKUREIBO_WORK(ICNT).KOJIN_NO,
       MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA,
       MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI,
       MGAKUREIBO_WORK(ICNT).SEINENGAPI,
       MGAKUREIBO_WORK(ICNT).HYOJI_SEINENGAPI,
       MGAKUREIBO_WORK(ICNT).KANJI_SEINENGAPI ,
       MGAKUREIBO_WORK(ICNT).SEIBETSU,
       MGAKUREIBO_WORK(ICNT).HYOJI_SEIBETSU,
       MGAKUREIBO_WORK(ICNT).ZOKUGARAMEI1,
       MGAKUREIBO_WORK(ICNT).JIDO_CHOMEI,
       MGAKUREIBO_WORK(ICNT).JIDO_BANCHI,
       MGAKUREIBO_WORK(ICNT).JIDO_KATAGAKI,
       MGAKUREIBO_WORK(ICNT).HOGOSHA_KOJIN_NO,
       MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA,
       MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI,
       MGAKUREIBO_WORK(ICNT).ZOKUGARAMEI2,
       MGAKUREIBO_WORK(ICNT).CHOMEI,
       MGAKUREIBO_WORK(ICNT).BANCHI,
       MGAKUREIBO_WORK(ICNT).KATAGAKI,
       MGAKUREIBO_WORK(ICNT).SETAI_NO,
       MGAKUREIBO_WORK(ICNT).GAKUNEN_CD,
       MGAKUREIBO_WORK(ICNT).GAKUNENMEI,
       MGAKUREIBO_WORK(ICNT).GYOSEIKU_CD,
       MGAKUREIBO_WORK(ICNT).GYOSEIKUMEI,
       MGAKUREIBO_WORK(ICNT).HAN_CD,
       MGAKUREIBO_WORK(ICNT).HANMEI,
       MGAKUREIBO_WORK(ICNT).SANTEIDANTAI_CD,
       MGAKUREIBO_WORK(ICNT).SANTEIDANTAIMEI,
       MGAKUREIBO_WORK(ICNT).SYOGAKO_CD,
       MGAKUREIBO_WORK(ICNT).SYOGAKOMEI,
       MGAKUREIBO_WORK(ICNT).SYOGAKO_NYUGAKU_BI,
       MGAKUREIBO_WORK(ICNT).SYOGAKO_TENNYUGAKU_BI,             
       MGAKUREIBO_WORK(ICNT).SYOGAKO_TENGAKU_BI,
       MGAKUREIBO_WORK(ICNT).SYOGAKO_SOTSUGYO_BI,
       MGAKUREIBO_WORK(ICNT).TYUGAKO_CD,
       MGAKUREIBO_WORK(ICNT).TYUGAKOMEI,
       MGAKUREIBO_WORK(ICNT).TYUGAKO_NYUGAKU_BI,
       MGAKUREIBO_WORK(ICNT).TYUGAKO_TENNYUGAKU_BI,             
       MGAKUREIBO_WORK(ICNT).TYUGAKO_TENGAKU_BI,
       MGAKUREIBO_WORK(ICNT).TYUGAKO_SOTSUGYO_BI,
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--        MGAKUREIBO_WORK(ICNT).KUIKIGAI_CD,
--        MGAKUREIBO_WORK(ICNT).KUIKIGAIMEI,
-- 2024/06/04 ZCZL.wangyunhan Delete end 
       MGAKUREIBO_WORK(ICNT).KUIKIGAI_SETISYA,
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--        MGAKUREIBO_WORK(ICNT).KUIKIGAI_NYUGAKU_BI,
--        MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENNYUGAKU_BI,            
--        MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENTAIGAKU_BI,
--        MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENGAKU_BI,               
--        MGAKUREIBO_WORK(ICNT).KUIKIGAI_TAIGAKU_BI,               
--        MGAKUREIBO_WORK(ICNT).KUIKIGAI_SOTSUGYO_BI,
--        MGAKUREIBO_WORK(ICNT).YOGOGAKO_CD ,
--        MGAKUREIBO_WORK(ICNT).YOGOGAKOMEI,
-- 2024/06/04 ZCZL.wangyunhan Delete end 
       MGAKUREIBO_WORK(ICNT).YOGOGAKO_SETISYA,
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--        MGAKUREIBO_WORK(ICNT).YOGOGAKO_NYUGAKU_BI,
--        MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENNYUGAKU_BI,            
--        MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENTAIGAKU_BI,
--        MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENGAKU_BI,               
--        MGAKUREIBO_WORK(ICNT).YOGOGAKO_TAIGAKU_BI,               
--        MGAKUREIBO_WORK(ICNT).YOGOGAKO_SOTSUGYO_BI,
-- 2024/06/04 ZCZL.wangyunhan Delete end 
       MGAKUREIBO_WORK(ICNT).YUYO_KYOKA_BI,
       MGAKUREIBO_WORK(ICNT).YUYO_JIYU ,
       MGAKUREIBO_WORK(ICNT).YUYO_KAISI_BI,
       MGAKUREIBO_WORK(ICNT).YUYO_SYURYO_BI,
       MGAKUREIBO_WORK(ICNT).YUYO_FUKUGAKU_BI,
       MGAKUREIBO_WORK(ICNT).MENJO_KYOKA_BI,
       MGAKUREIBO_WORK(ICNT).MENJO_JIYU,
       MGAKUREIBO_WORK(ICNT).MENJO_FUKUGAKU_BI,
       MGAKUREIBO_WORK(ICNT).IDO_BI1,
       MGAKUREIBO_WORK(ICNT).IDO_JIYU1,
       MGAKUREIBO_WORK(ICNT).IDO_BI2,
       MGAKUREIBO_WORK(ICNT).IDO_JIYU2,
       MGAKUREIBO_WORK(ICNT).IDO_BI3,
       MGAKUREIBO_WORK(ICNT).IDO_JIYU3,
       MGAKUREIBO_WORK(ICNT).IDO_BI4,
       MGAKUREIBO_WORK(ICNT).IDO_JIYU4,
       MGAKUREIBO_WORK(ICNT).IDO_BI5,
       MGAKUREIBO_WORK(ICNT).IDO_JIYU5,
       MGAKUREIBO_WORK(ICNT).IDO_BI6,
       MGAKUREIBO_WORK(ICNT).IDO_JIYU6,
       MGAKUREIBO_WORK(ICNT).IDO_BI7,
       MGAKUREIBO_WORK(ICNT).IDO_JIYU7,
       MGAKUREIBO_WORK(ICNT).IDO_BI8,
       MGAKUREIBO_WORK(ICNT).IDO_JIYU8,
       MGAKUREIBO_WORK(ICNT).IDO_BI9,
       MGAKUREIBO_WORK(ICNT).IDO_JIYU9,
       MGAKUREIBO_WORK(ICNT).IDO_BI10,
       MGAKUREIBO_WORK(ICNT).IDO_JIYU10,
       MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI1,
       MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO1,
       MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI2,
       MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO2,
       MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI3,
       MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO3,
       MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI4,
       MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO4,
       MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI5,
       MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO5,
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
       RG.TOKUSOKU_BI6,
       RG.TOKUSOKU_NAIYO6,
       RG.TOKUSOKU_BI7,
       RG.TOKUSOKU_NAIYO7,
       RG.TOKUSOKU_BI8,
       RG.TOKUSOKU_NAIYO8,
       RG.TOKUSOKU_BI9,
       RG.TOKUSOKU_NAIYO9,
       RG.TOKUSOKU_BI10,
       RG.TOKUSOKU_NAIYO10,
-- 2024/06/04 ZCZL.wangyunhan Add end
       MGAKUREIBO_WORK(ICNT).NENDO,
       MGAKUREIBO_WORK(ICNT).NENDO1,
       MGAKUREIBO_WORK(ICNT).NENDO2,
       MGAKUREIBO_WORK(ICNT).NENDO3,
       MGAKUREIBO_WORK(ICNT).NENDO4,
       MGAKUREIBO_WORK(ICNT).NENDO5,
       MGAKUREIBO_WORK(ICNT).NENDO6,
       MGAKUREIBO_WORK(ICNT).NENDO7,
       MGAKUREIBO_WORK(ICNT).NENDO8,
       MGAKUREIBO_WORK(ICNT).NENDO9,
       MGAKUREIBO_WORK(ICNT).KAIPEJI_KBN,
       MGAKUREIBO_WORK(ICNT).KAIPEJI_CD,
       MGAKUREIBO_WORK(ICNT).KAIPEJI,
       MGAKUREIBO_WORK(ICNT).RENBAN,
       MGAKUREIBO_WORK(ICNT).GAKO_CD,
       MGAKUREIBO_WORK(ICNT).GAKOMEI
       ,
       MGAKUREIBO_WORK(ICNT).CD1,
       MGAKUREIBO_WORK(ICNT).MEISHO1,
       MGAKUREIBO_WORK(ICNT).CD2,
       MGAKUREIBO_WORK(ICNT).MEISHO2,
       MGAKUREIBO_WORK(ICNT).CD3,
       MGAKUREIBO_WORK(ICNT).MEISHO3
        , MGAKUREIBO_WORK(ICNT).JIDO_JINKAKU_KBN
        , MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANA
        , MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANJI,
       MGAKUREIBO_WORK(ICNT).HOGOSHA_JINKAKU_KBN,
       MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANA,
       MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANJI,
       MGAKUREIBO_WORK(ICNT).SYOGAKO_TENNYUGAKU_GAKUNEN,
       MGAKUREIBO_WORK(ICNT).SYOGAKO_TENGAKU_GAKUNEN,
       MGAKUREIBO_WORK(ICNT).TYUGAKO_TENNYUGAKU_GAKUNEN,
       MGAKUREIBO_WORK(ICNT).TYUGAKO_TENGAKU_GAKUNEN,
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--        MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENNYUGAKU_GAKUNEN,
--        MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENGAKU_GAKUNEN,
--        MGAKUREIBO_WORK(ICNT).KUIKIGAI_TAIGAKU_GAKUNEN,
--        MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENNYUGAKU_GAKUNEN,
--        MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENGAKU_GAKUNEN,
--        MGAKUREIBO_WORK(ICNT).YOGOGAKO_TAIGAKU_GAKUNEN,
-- 2024/06/04 ZCZL.wangyunhan Delete end 
       MGAKUREIBO_WORK(ICNT).SHUGAKU_ZYOKYO,
       MGAKUREIBO_WORK(ICNT).IDO_ZIYU,
       MGAKUREIBO_WORK(ICNT).GAKKYU_CD,
       MGAKUREIBO_WORK(ICNT).KYOIKUKAI_MEI,
       MGAKUREIBO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI,
       MGAKUREIBO_WORK(ICNT).KYOIKU_SHUTHOU_MEI,
       MGAKUREIBO_WORK(ICNT).KYOIKU_RITSU_MEI,
       MGAKUREIBO_WORK(ICNT).KYOIKU_YUBIN_NO,
       MGAKUREIBO_WORK(ICNT).KYOIKU_JUSHO,
       MGAKUREIBO_WORK(ICNT).KYOIKU_TEL,
       MGAKUREIBO_WORK(ICNT).KYOIKU_TEL_NAISEN,
       MGAKUREIBO_WORK(ICNT).CHOHYO_NO,
       MGAKUREIBO_WORK(ICNT).HYOJI_CHOHYO_NO,
       MGAKUREIBO_WORK(ICNT).KIJUN_BI,
       MGAKUREIBO_WORK(ICNT).JIDO_ZENJUSHO,     --児童前住所
       MGAKUREIBO_WORK(ICNT).HOGOSHA_ZENJUSHO   --保護者前住所
        ,MGAKUREIBO_WORK(ICNT).JINKAKU_KBN
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        ,MGAKUREIBO_WORK(ICNT).S_TAIGAKU_BI,
        MGAKUREIBO_WORK(ICNT).S_TAIGAKU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).T_TAIGAKU_BI,
        MGAKUREIBO_WORK(ICNT).T_TAIGAKU_GAKUNEN,
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--        GKAFKGKOGTEQ(1,GAKUREIBO_RECC.KUIKIGAI_S_CD),
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_MEI,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_NYUGAKU_BI,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_BI,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_BI,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_BI,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_SOTSUGYO_BI,
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--        GKAFKGKOGTEQ(2,GAKUREIBO_RECC.KUIKIGAI_T_CD),
         MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_MEI,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_NYUGAKU_BI,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_BI,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_BI,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_BI,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_SOTSUGYO_BI,
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--        GKAFKGKOGTEQ(3,GAKUREIBO_RECC.SHIEN_S_CD),
         MGAKUREIBO_WORK(ICNT).YOGO_S_MEI,
        MGAKUREIBO_WORK(ICNT).YOGO_S_NYUGAKU_BI,
        MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_BI,
        MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_BI,
        MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_BI,
        MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).YOGO_S_SOTSUGYO_BI,
--  2024/08/05 ZCZL.YANGXINYU UPDATE 0.3.000.001:受入検証対応No182
--        GKAFKGKOGTEQ(4,GAKUREIBO_RECC.SHIEN_T_CD),
         MGAKUREIBO_WORK(ICNT).YOGO_T_MEI,
        MGAKUREIBO_WORK(ICNT).YOGO_T_NYUGAKU_BI,
        MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_BI,
        MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_BI,
        MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_BI,
        MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_GAKUNEN,
        MGAKUREIBO_WORK(ICNT).YOGO_T_SOTSUGYO_BI,
--  2024/08/05 ZCZL.YANGXINYU UPDATE START 0.3.000.001:受入検証対応No182
--          MNENDO_WORK(ICNT).SHIEN_KBN,
--          MNENDO_WORK(ICNT).TAISHOSHA_KBN,
--          MNENDO_WORK(ICNT).GAITO_KARA,
--          MNENDO_WORK(ICNT).GAITO_MADE,
--          MNENDO_WORK(ICNT).GAKKO_KBN_CD
          MGAKUREIBO_WORK(ICNT).SHIEN_KBN,
          MGAKUREIBO_WORK(ICNT).TAISHOSHA_KBN,
          MGAKUREIBO_WORK(ICNT).GAITO_KARA,
          MGAKUREIBO_WORK(ICNT).GAITO_MADE,
          MGAKUREIBO_WORK(ICNT).GAKKO_KBN_CD
--  2024/08/05 ZCZL.YANGXINYU UPDATE END 
-- 2024/06/04 ZCZL.wangyunhan Add end 
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
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_INSERT_JIDO_WK', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        -- 終了
        RETURN IFRET;
    EXCEPTION
    -- その他エラー
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
    --------------------------------------------------------------------------------
    --  機能概要      : 学齢簿中間テーブルの作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GET_JIDO_WK_CSV RETURN NUMBER IS
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
        RREC                GKBWGAKUREIBO%ROWTYPE;      -- 入学通知台帳のレコード変数
        NROWS               NUMBER;                     --
        IPAGECNT            PLS_INTEGER;                -- 頁数
        IGYOCNT             PLS_INTEGER;                -- 行番号
        IGYORENBAN          PLS_INTEGER;                -- 行連番
        VPAGENAME           NVARCHAR2(500);             -- 改頁項目名のワーク
        VPAGEWORK           NVARCHAR2(500);             -- 改頁項目値のワーク
        VPAGEFIELD          NVARCHAR2(500);             -- 改頁項目値のワーク
        IRTN                PLS_INTEGER;                -- 戻り値
        vOrderbyclause      NVARCHAR2(2000);
    BEGIN
        FRET := c_ISUCCESS;                  -- 正常終了
        VPAGEWORK := '';
        IGYOCNT := 0;
        ICNT := 0;
        MJIDO_WORK.DELETE;                   -- ワーク領域の初期化
        MGAKUREIBO_WORK.DELETE;
        MGAKUNEN_LNK_WORK.DELETE;
        
        IF NRENBAN = 0 THEN
           VSQLORDER := ' KAIPEJI_KBN,GAKO_CD,GAKUNEN_CD,GYOSEIKU_CD,CHOHYO_NO ';
        ELSE
          CASE g_rJSTP.CHOHYOID
          -- ソート条件取得
          WHEN 'GKB050R001' THEN
            VSQLORDER := FUNC_GETSORTCOLS(501);
          -- ソート条件取得
          WHEN 'GKB200R002' THEN
            VSQLORDER := FUNC_GETSORTCOLS(2002);
          ELSE
            NULL;
          END CASE;
        END IF;
        
        VPAGEFD := 'KAIPEJI_KBN||GAKO_CD||GAKUNEN_CD';
        VPAGENM := 'GAKOMEI';
        
        -- ［ORDER BY］句を付加
        IF KKAPK0010.FTrim(VSQLORDER) IS NOT NULL THEN
          VSQLORDER := ' ORDER BY ' || VSQLORDER;
        END IF;

        BEGIN
            -- 出力データ取得ＳＱＬの構文
            VSQLSEL := '';
            VSQLSEL := VSQLSEL || 'SELECT ';
            VSQLSEL := VSQLSEL || 'NENDO, ';
            VSQLSEL := VSQLSEL || 'NENDO1, ';
            VSQLSEL := VSQLSEL || 'NENDO2, ';
            VSQLSEL := VSQLSEL || 'NENDO3, ';
            VSQLSEL := VSQLSEL || 'NENDO4, ';
            VSQLSEL := VSQLSEL || 'NENDO5, ';
            VSQLSEL := VSQLSEL || 'NENDO6, ';
            VSQLSEL := VSQLSEL || 'NENDO7, ';
            VSQLSEL := VSQLSEL || 'NENDO8, ';
            VSQLSEL := VSQLSEL || 'NENDO9, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_KBN, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI_CD, ';
            VSQLSEL := VSQLSEL || 'KAIPEJI, ';
            VSQLSEL := VSQLSEL || 'RENBAN, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'JIDO_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'KANJI_SEINENGAPI, ';
            VSQLSEL := VSQLSEL || 'HYOJI_SEIBETSU, ';
            VSQLSEL := VSQLSEL || 'JIDO_CHOMEI, ';
            VSQLSEL := VSQLSEL || 'JIDO_BANCHI, ';
            VSQLSEL := VSQLSEL || 'JIDO_KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANA, ';
            VSQLSEL := VSQLSEL || 'HOGOSHA_SHIMEI_KANJI, ';
            VSQLSEL := VSQLSEL || 'ZOKUGARAMEI2, ';
            VSQLSEL := VSQLSEL || 'CHOMEI, ';
            VSQLSEL := VSQLSEL || 'BANCHI, ';
            VSQLSEL := VSQLSEL || 'KATAGAKI, ';
            VSQLSEL := VSQLSEL || 'SYOGAKOMEI, ';
            VSQLSEL := VSQLSEL || 'SYOGAKO_NYUGAKU_BI, ';
            VSQLSEL := VSQLSEL || 'SYOGAKO_TENNYUGAKU_BI, ';              
            VSQLSEL := VSQLSEL || 'SYOGAKO_TENGAKU_BI, ';
            VSQLSEL := VSQLSEL || 'SYOGAKO_SOTSUGYO_BI, ';
            VSQLSEL := VSQLSEL || 'TYUGAKOMEI, ';
            VSQLSEL := VSQLSEL || 'TYUGAKO_NYUGAKU_BI, ';
            VSQLSEL := VSQLSEL || 'TYUGAKO_TENNYUGAKU_BI, ';              
            VSQLSEL := VSQLSEL || 'TYUGAKO_TENGAKU_BI, ';
            VSQLSEL := VSQLSEL || 'TYUGAKO_SOTSUGYO_BI, ';
            VSQLSEL := VSQLSEL || 'KUIKIGAIMEI, ';
            VSQLSEL := VSQLSEL || 'KUIKIGAI_SETISYA, ';
            VSQLSEL := VSQLSEL || 'KUIKIGAI_NYUGAKU_BI, ';
            VSQLSEL := VSQLSEL || 'KUIKIGAI_TENNYUGAKU_BI, ';             
            VSQLSEL := VSQLSEL || 'KUIKIGAI_TENTAIGAKU_BI, ';
            VSQLSEL := VSQLSEL || 'KUIKIGAI_TENGAKU_BI, ';                
            VSQLSEL := VSQLSEL || 'KUIKIGAI_TAIGAKU_BI, ';                
            VSQLSEL := VSQLSEL || 'KUIKIGAI_SOTSUGYO_BI, ';
            VSQLSEL := VSQLSEL || 'YOGOGAKOMEI, ';
            VSQLSEL := VSQLSEL || 'YOGOGAKO_SETISYA, ';
            VSQLSEL := VSQLSEL || 'YOGOGAKO_NYUGAKU_BI, ';
            VSQLSEL := VSQLSEL || 'YOGOGAKO_TENNYUGAKU_BI, ';             
            VSQLSEL := VSQLSEL || 'YOGOGAKO_TENTAIGAKU_BI, ';
            VSQLSEL := VSQLSEL || 'YOGOGAKO_TENGAKU_BI, ';                
            VSQLSEL := VSQLSEL || 'YOGOGAKO_TAIGAKU_BI, ';                
            VSQLSEL := VSQLSEL || 'YOGOGAKO_SOTSUGYO_BI, ';
            VSQLSEL := VSQLSEL || 'YUYO_KYOKA_BI, ';
            VSQLSEL := VSQLSEL || 'YUYO_JIYU, ';
            VSQLSEL := VSQLSEL || 'YUYO_KAISI_BI, ';
            VSQLSEL := VSQLSEL || 'YUYO_SYURYO_BI, ';
            VSQLSEL := VSQLSEL || 'YUYO_FUKUGAKU_BI, ';
            VSQLSEL := VSQLSEL || 'MENJO_KYOKA_BI, ';
            VSQLSEL := VSQLSEL || 'MENJO_JIYU, ';
            VSQLSEL := VSQLSEL || 'MENJO_FUKUGAKU_BI, ';
            VSQLSEL := VSQLSEL || 'IDO_BI1, ';
            VSQLSEL := VSQLSEL || 'IDO_JIYU1, ';
            VSQLSEL := VSQLSEL || 'IDO_BI2, ';
            VSQLSEL := VSQLSEL || 'IDO_JIYU2, ';
            VSQLSEL := VSQLSEL || 'IDO_BI3, ';
            VSQLSEL := VSQLSEL || 'IDO_JIYU3, ';
            VSQLSEL := VSQLSEL || 'IDO_BI4, ';
            VSQLSEL := VSQLSEL || 'IDO_JIYU4, ';
            VSQLSEL := VSQLSEL || 'IDO_BI5, ';
            VSQLSEL := VSQLSEL || 'IDO_JIYU5, ';
            VSQLSEL := VSQLSEL || 'IDO_BI6, ';
            VSQLSEL := VSQLSEL || 'IDO_JIYU6, ';
            VSQLSEL := VSQLSEL || 'IDO_BI7, ';
            VSQLSEL := VSQLSEL || 'IDO_JIYU7, ';
            VSQLSEL := VSQLSEL || 'IDO_BI8, ';
            VSQLSEL := VSQLSEL || 'IDO_JIYU8, ';
            VSQLSEL := VSQLSEL || 'IDO_BI9, ';
            VSQLSEL := VSQLSEL || 'IDO_JIYU9, ';
            VSQLSEL := VSQLSEL || 'IDO_BI10, ';
            VSQLSEL := VSQLSEL || 'IDO_JIYU10, ';
            VSQLSEL := VSQLSEL || 'TOKUSOKU_BI1, ';
            VSQLSEL := VSQLSEL || 'TOKUSOKU_NAIYO1, ';
            VSQLSEL := VSQLSEL || 'TOKUSOKU_BI2, ';
            VSQLSEL := VSQLSEL || 'TOKUSOKU_NAIYO2, ';
            VSQLSEL := VSQLSEL || 'TOKUSOKU_BI3, ';
            VSQLSEL := VSQLSEL || 'TOKUSOKU_NAIYO3, ';
            VSQLSEL := VSQLSEL || 'TOKUSOKU_BI4, ';
            VSQLSEL := VSQLSEL || 'TOKUSOKU_NAIYO4, ';
            VSQLSEL := VSQLSEL || 'TOKUSOKU_BI5, ';
            VSQLSEL := VSQLSEL || 'TOKUSOKU_NAIYO5, ';
            VSQLSEL := VSQLSEL || 'GAKO_CD, ';
            VSQLSEL := VSQLSEL || 'GAKOMEI, ';
            IF NRENBAN = 0 THEN
                IF ACONSPRM_RENBAN(1) IN(1,2,3)THEN
                    VSQLSEL := VSQLSEL || 'GAKO_CD' || ' KAIPEJI_CD,';
                    VSQLSEL := VSQLSEL || 'GAKOMEI' || ' KAIPEJI';
                ELSIF ACONSPRM_RENBAN(1) IN(4,5) THEN
                    VSQLSEL := VSQLSEL || 'GAKO_CD || GYOSEIKU_CD' || ' KAIPEJI_CD,';
                    VSQLSEL := VSQLSEL || 'GAKOMEI || '' '' || GYOSEIKUMEI' || ' KAIPEJI';
                ELSE
                  VSQLSEL := VSQLSEL || 'null as KAIPEJI_CD, ';           -- 改頁値を設定
                  VSQLSEL := VSQLSEL || 'null as KAIPEJI ';            -- 改頁名を設定
                END IF;
            ELSE
              VSQLSEL := VSQLSEL || VPAGEFD || ' KAIPEJI_CD, ';            -- 改頁値を設定
              VSQLSEL := VSQLSEL || VPAGENM || ' KAIPEJI ';                -- 改頁名を設定
            END IF;
            VSQLSEL := VSQLSEL || ',CD1, ';
            VSQLSEL := VSQLSEL || 'MEISHO1, ';
            VSQLSEL := VSQLSEL || 'CD2, ';
            VSQLSEL := VSQLSEL || 'MEISHO2, ';
            VSQLSEL := VSQLSEL || 'CD3, ';
            VSQLSEL := VSQLSEL || 'MEISHO3 ';
            VSQLSEL := VSQLSEL || ', JIDO_JINKAKU_KBN ';
            VSQLSEL := VSQLSEL || ', JIDO_HONMYO_KANA ';
            VSQLSEL := VSQLSEL || ', JIDO_HONMYO_KANJI, ';
            VSQLSEL := VSQLSEL || ' HOGOSHA_JINKAKU_KBN, ';
            VSQLSEL := VSQLSEL || ' HOGOSHA_HONMYO_KANA, ';
            VSQLSEL := VSQLSEL || ' HOGOSHA_HONMYO_KANJI, ';
            VSQLSEL := VSQLSEL || ' SYOGAKO_TENNYUGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' SYOGAKO_TENGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' TYUGAKO_TENGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' TYUGAKO_TENGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' KUIKIGAI_TENNYUGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' KUIKIGAI_TENGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' KUIKIGAI_TAIGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' YOGOGAKO_TENNYUGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' YOGOGAKO_TENGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' YOGOGAKO_TAIGAKU_GAKUNEN, ';
            VSQLSEL := VSQLSEL || ' SHUGAKU_ZYOKYO, ';
            VSQLSEL := VSQLSEL || ' IDO_ZIYU, ';
            VSQLSEL := VSQLSEL || ' GAKKYU_CD, ';
            VSQLSEL := VSQLSEL || ' KYOIKUKAI_MEI, ';
            VSQLSEL := VSQLSEL || ' KYOIKU_YAKUSHOKU_MEI, ';
            VSQLSEL := VSQLSEL || ' KYOIKU_SHUTHOU_MEI, ';
            VSQLSEL := VSQLSEL || ' KYOIKU_RITSU_MEI, ';
            VSQLSEL := VSQLSEL || ' KYOIKU_YUBIN_NO, ';
            VSQLSEL := VSQLSEL || ' KYOIKU_JUSHO, ';
            VSQLSEL := VSQLSEL || ' KYOIKU_TEL, ';
            VSQLSEL := VSQLSEL || ' KYOIKU_TEL_NAISEN, ';
            VSQLSEL := VSQLSEL || ' CHOHYO_NO, ';
            VSQLSEL := VSQLSEL || ' HYOJI_CHOHYO_NO, ';
            VSQLSEL := VSQLSEL || ' KIJUN_BI, ';
            VSQLSEL := VSQLSEL || ' KOJIN_NO, ';
            VSQLSEL := VSQLSEL || ' ZOKUGARAMEI1, ';
            VSQLSEL := VSQLSEL || ' JIDO_ZENJUSHO, ';     --児童前住所
            VSQLSEL := VSQLSEL || ' HOGOSHA_ZENJUSHO ';   --保護者前住所
            VSQLSEL := VSQLSEL || ' ,JINKAKU_KBN ';
--  2024/08/05 ZCZL.YANGXINYU ADD START 0.3.000.001:受入検証対応No182
            VSQLSEL := VSQLSEL || ' ,TOKUSOKU_BI6 ';
            VSQLSEL := VSQLSEL || ' ,TOKUSOKU_NAIYO6 ';
            VSQLSEL := VSQLSEL || ' ,TOKUSOKU_BI7 ';
            VSQLSEL := VSQLSEL || ' ,TOKUSOKU_NAIYO7 ';
            VSQLSEL := VSQLSEL || ' ,TOKUSOKU_BI8 ';
            VSQLSEL := VSQLSEL || ' ,TOKUSOKU_NAIYO8 ';
            VSQLSEL := VSQLSEL || ' ,TOKUSOKU_BI9 ';
            VSQLSEL := VSQLSEL || ' ,TOKUSOKU_NAIYO9 ';
            VSQLSEL := VSQLSEL || ' ,TOKUSOKU_BI10 ';
            VSQLSEL := VSQLSEL || ' ,TOKUSOKU_NAIYO10 ';
            VSQLSEL := VSQLSEL || ' ,S_TAIGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,S_TAIGAKU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,T_TAIGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,T_TAIGAKU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_S_MEI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_S_NYUGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_S_TENNYU_BI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_S_TENNYU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_S_TENGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_S_TENGAKU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_S_TAIGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_S_TAIGAKU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_S_SOTSUGYO_BI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_T_MEI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_T_NYUGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_T_TENNYU_BI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_T_TENNYU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_T_TENGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_T_TENGAKU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_T_TAIGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_T_TAIGAKU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,KUIKIGAI_T_SOTSUGYO_BI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_S_MEI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_S_NYUGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_S_TENNYU_BI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_S_TENNYU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,YOGO_S_TENGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_S_TENGAKU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,YOGO_S_TAIGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_S_TAIGAKU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,YOGO_S_SOTSUGYO_BI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_T_MEI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_T_NYUGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_T_TENNYU_BI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_T_TENNYU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,YOGO_T_TENGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_T_TENGAKU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,YOGO_T_TAIGAKU_BI ';
            VSQLSEL := VSQLSEL || ' ,YOGO_T_TAIGAKU_GAKUNEN ';
            VSQLSEL := VSQLSEL || ' ,YOGO_T_SOTSUGYO_BI ';
            VSQLSEL := VSQLSEL || ' ,SHIEN_KBN ';
            VSQLSEL := VSQLSEL || ' ,TAISHOSHA_KBN ';
            VSQLSEL := VSQLSEL || ' ,GAITO_KARA ';
            VSQLSEL := VSQLSEL || ' ,GAITO_MADE ';
            VSQLSEL := VSQLSEL || ' ,GAKKO_KBN_CD ';
--  2024/11/11 ZCZL.WANGYUNING ADD 0.3.000.007:IT_GKB_00524対応
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--            VSQLSEL := VSQLSEL || ' ,SEINENGAPI ';
            VSQLSEL := VSQLSEL || ' ,HYOJI_SEINENGAPI ';
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
--  2024/08/05 ZCZL.YANGXINYU ADD END
            VSQLSEL := VSQLSEL || 'FROM ';
            VSQLSEL := VSQLSEL || 'GKBWGAKUREIBO ';
            -- ひとつのＳＱＬ文にする
            VSQL := VSQLSEL || VSQLORDER;
            -- カーソルのオープン
            I_CUR := DBMS_SQL.OPEN_CURSOR;
            -- ＳＱＬ文の解析
            DBMS_SQL.PARSE(I_CUR, VSQL, DBMS_SQL.NATIVE);
            -- 取得する列の定義
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  1, RREC.NENDO,  12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  2, RREC.NENDO1, 12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  3, RREC.NENDO2, 12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  4, RREC.NENDO3, 12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  5, RREC.NENDO4, 12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  6, RREC.NENDO5, 12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  7, RREC.NENDO6, 12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  8, RREC.NENDO7, 12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  9, RREC.NENDO8, 12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 10, RREC.NENDO9, 12);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 11, RREC.KAIPEJI_KBN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 12, RREC.KAIPEJI_CD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 13, RREC.KAIPEJI, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 14, RREC.RENBAN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 15, RREC.JIDO_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 16, RREC.JIDO_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 17, RREC.KANJI_SEINENGAPI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 18, RREC.HYOJI_SEIBETSU, 1);
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.JIDO_CHOMEI, 40);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.JIDO_BANCHI, 40);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.JIDO_KATAGAKI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 19, RREC.JIDO_CHOMEI, 136);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 20, RREC.JIDO_BANCHI, 50);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 21, RREC.JIDO_KATAGAKI, 300);
-- 2024/06/04 ZCZL.wangyunhan Update end
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 22, RREC.HOGOSHA_SHIMEI_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 23, RREC.HOGOSHA_SHIMEI_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 24, RREC.ZOKUGARAMEI2, 30);
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.CHOMEI, 40);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.BANCHI, 40);
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.KATAGAKI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 25, RREC.CHOMEI, 136);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 26, RREC.BANCHI, 50);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 27, RREC.KATAGAKI, 300);
-- 2024/06/04 ZCZL.wangyunhan Update end
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 28, RREC.SYOGAKOMEI, 60);             
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 29, RREC.SYOGAKO_NYUGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 30, RREC.SYOGAKO_TENNYUGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 31, RREC.SYOGAKO_TENGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 32, RREC.SYOGAKO_SOTSUGYO_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 33, RREC.TYUGAKOMEI, 60);             
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 34, RREC.TYUGAKO_NYUGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 35, RREC.TYUGAKO_TENNYUGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 36, RREC.TYUGAKO_TENGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 37, RREC.TYUGAKO_SOTSUGYO_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 38, RREC.KUIKIGAIMEI, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 39, RREC.KUIKIGAI_SETISYA, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 40, RREC.KUIKIGAI_NYUGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 41, RREC.KUIKIGAI_TENNYUGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 42, RREC.KUIKIGAI_TENTAIGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 43, RREC.KUIKIGAI_TENGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 44, RREC.KUIKIGAI_TAIGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 45, RREC.KUIKIGAI_SOTSUGYO_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 46, RREC.YOGOGAKOMEI, 60);            
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 47, RREC.YOGOGAKO_SETISYA, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 48, RREC.YOGOGAKO_NYUGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 49, RREC.YOGOGAKO_TENNYUGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 50, RREC.YOGOGAKO_TENTAIGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 51, RREC.YOGOGAKO_TENGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 52, RREC.YOGOGAKO_TAIGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 53, RREC.YOGOGAKO_SOTSUGYO_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 54, RREC.YUYO_KYOKA_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 55, RREC.YUYO_JIYU, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 56, RREC.YUYO_KAISI_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 57, RREC.YUYO_SYURYO_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 58, RREC.YUYO_FUKUGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 59, RREC.MENJO_KYOKA_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 60, RREC.MENJO_JIYU, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 61, RREC.MENJO_FUKUGAKU_BI, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 62, RREC.IDO_BI1, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 63, RREC.IDO_JIYU1, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 64, RREC.IDO_BI2, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 65, RREC.IDO_JIYU2, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 66, RREC.IDO_BI3, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 67, RREC.IDO_JIYU3, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 68, RREC.IDO_BI4, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 69, RREC.IDO_JIYU4, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 70, RREC.IDO_BI5, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 71, RREC.IDO_JIYU5, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 72, RREC.IDO_BI6, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 73, RREC.IDO_JIYU6, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 74, RREC.IDO_BI7, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 75, RREC.IDO_JIYU7, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 76, RREC.IDO_BI8, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 77, RREC.IDO_JIYU8, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 78, RREC.IDO_BI9, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 79, RREC.IDO_JIYU9, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 80, RREC.IDO_BI10, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 81, RREC.IDO_JIYU10, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 82, RREC.TOKUSOKU_BI1, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 83, RREC.TOKUSOKU_NAIYO1, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 84, RREC.TOKUSOKU_BI2, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 85, RREC.TOKUSOKU_NAIYO2, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 86, RREC.TOKUSOKU_BI3, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 87, RREC.TOKUSOKU_NAIYO3, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 88, RREC.TOKUSOKU_BI4, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 89, RREC.TOKUSOKU_NAIYO4, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 90, RREC.TOKUSOKU_BI5, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 91, RREC.TOKUSOKU_NAIYO5, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 92, RREC.GAKO_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 93, RREC.GAKOMEI, 60);                
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 94, VPAGEFD, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 95, VPAGENM, 500);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 96, RREC.CD1);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 97, RREC.MEISHO1, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 98, RREC.CD2);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 99, RREC.MEISHO2, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 100, RREC.CD3);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 101, RREC.MEISHO3, 30);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 102, RREC.JIDO_JINKAKU_KBN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 103, RREC.JIDO_HONMYO_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 104, RREC.JIDO_HONMYO_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 105,  RREC.HOGOSHA_JINKAKU_KBN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 106,  RREC.HOGOSHA_HONMYO_KANA, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 107,  RREC.HOGOSHA_HONMYO_KANJI, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 108,  RREC.SYOGAKO_TENNYUGAKU_GAKUNEN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 109,  RREC.SYOGAKO_TENGAKU_GAKUNEN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 110,  RREC.TYUGAKO_TENNYUGAKU_GAKUNEN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 111,  RREC.TYUGAKO_TENGAKU_GAKUNEN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 112, RREC.KUIKIGAI_TENNYUGAKU_GAKUNEN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 113, RREC.KUIKIGAI_TENGAKU_GAKUNEN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 114, RREC.KUIKIGAI_TAIGAKU_GAKUNEN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 115, RREC.YOGOGAKO_TENNYUGAKU_GAKUNEN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 116, RREC.YOGOGAKO_TENGAKU_GAKUNEN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 117, RREC.YOGOGAKO_TAIGAKU_GAKUNEN);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 118, RREC.SHUGAKU_ZYOKYO, 300);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 119, RREC.IDO_ZIYU, 300);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 120, RREC.GAKKYU_CD);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 121, RREC.KYOIKUKAI_MEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 122, RREC.KYOIKU_YAKUSHOKU_MEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 123, RREC.KYOIKU_SHUTHOU_MEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 124, RREC.KYOIKU_RITSU_MEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 125, RREC.KYOIKU_YUBIN_NO, 10);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 126, RREC.KYOIKU_JUSHO, 100);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 127, RREC.KYOIKU_TEL, 20);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 128, RREC.KYOIKU_TEL_NAISEN, 10);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 129, RREC.CHOHYO_NO);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 130, RREC.HYOJI_CHOHYO_NO, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 131, RREC.KIJUN_BI, 16);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 132, RREC.KOJIN_NO);
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 133, RREC.ZOKUGARAMEI1, 30);
    --児童前住所
    --保護者前住所
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 134, RREC.JIDO_ZENJUSHO,    150);     --児童前住所
--            DBMS_SQL.DEFINE_COLUMN(I_CUR, 135, RREC.HOGOSHA_ZENJUSHO, 150);     --保護者前住所
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 134, RREC.JIDO_ZENJUSHO,    486);     --児童前住所
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 135, RREC.HOGOSHA_ZENJUSHO, 486);     --保護者前住所
-- 2024/06/04 ZCZL.wangyunhan Update end
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 136, RREC.JINKAKU_KBN);  --保護者前住所
--  2024/08/05 ZCZL.YANGXINYU ADD START 0.3.000.001:受入検証対応No182
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  137, RREC.TOKUSOKU_BI6, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  138, RREC.TOKUSOKU_NAIYO6, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  139, RREC.TOKUSOKU_BI7, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  140, RREC.TOKUSOKU_NAIYO7, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  141, RREC.TOKUSOKU_BI8, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  142, RREC.TOKUSOKU_NAIYO8, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  143, RREC.TOKUSOKU_BI9, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  144, RREC.TOKUSOKU_NAIYO9, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  145, RREC.TOKUSOKU_BI10, 22);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  146, RREC.TOKUSOKU_NAIYO10, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  147, RREC.S_TAIGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  148, RREC.S_TAIGAKU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  149, RREC.T_TAIGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  150, RREC.T_TAIGAKU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  151, RREC.KUIKIGAI_S_MEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  152, RREC.KUIKIGAI_S_NYUGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  153, RREC.KUIKIGAI_S_TENNYU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  154, RREC.KUIKIGAI_S_TENNYU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  155, RREC.KUIKIGAI_S_TENGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  156, RREC.KUIKIGAI_S_TENGAKU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  157, RREC.KUIKIGAI_S_TAIGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  158, RREC.KUIKIGAI_S_TAIGAKU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  159, RREC.KUIKIGAI_S_SOTSUGYO_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  160, RREC.KUIKIGAI_T_MEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  161, RREC.KUIKIGAI_T_NYUGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  162, RREC.KUIKIGAI_T_TENNYU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  163, RREC.KUIKIGAI_T_TENNYU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  164, RREC.KUIKIGAI_T_TENGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  165, RREC.KUIKIGAI_T_TENGAKU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  166, RREC.KUIKIGAI_T_TAIGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  167, RREC.KUIKIGAI_T_TAIGAKU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  168, RREC.KUIKIGAI_T_SOTSUGYO_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  169, RREC.YOGO_S_MEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  170, RREC.YOGO_S_NYUGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  171, RREC.YOGO_S_TENNYU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  172, RREC.YOGO_S_TENNYU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  173, RREC.YOGO_S_TENGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  174, RREC.YOGO_S_TENGAKU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  175, RREC.YOGO_S_TAIGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  176, RREC.YOGO_S_TAIGAKU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  177, RREC.YOGO_S_SOTSUGYO_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  178, RREC.YOGO_T_MEI, 60);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  179, RREC.YOGO_T_NYUGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  180, RREC.YOGO_T_TENNYU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  181, RREC.YOGO_T_TENNYU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  182, RREC.YOGO_T_TENGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  183, RREC.YOGO_T_TENGAKU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  184, RREC.YOGO_T_TAIGAKU_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  185, RREC.YOGO_T_TAIGAKU_GAKUNEN );
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  186, RREC.YOGO_T_SOTSUGYO_BI, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  187, RREC.SHIEN_KBN, 6);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  188, RREC.TAISHOSHA_KBN, 6);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  189, RREC.GAITO_KARA, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  190, RREC.GAITO_MADE, 11);
            DBMS_SQL.DEFINE_COLUMN(I_CUR,  191, RREC.GAKKO_KBN_CD );
--  2024/11/11 ZCZL.WANGYUNING ADD 0.3.000.007:IT_GKB_00524対応
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--            DBMS_SQL.DEFINE_COLUMN(I_CUR,  192, RREC.SEINENGAPI );
            DBMS_SQL.DEFINE_COLUMN(I_CUR, 192, RREC.HYOJI_SEINENGAPI, 22);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
--  2024/08/05 ZCZL.YANGXINYU ADD END
            -- ＳＱＬ実行
            NROWS := DBMS_SQL.EXECUTE(I_CUR);
            LOOP
                --FETCH（行の取り出し）
                IF DBMS_SQL.FETCH_ROWS(I_CUR) > 0 THEN
                    -- ワーク領域へセット
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  1, MGAKUREIBO_WORK(ICNT).NENDO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  2, MGAKUREIBO_WORK(ICNT).NENDO1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  3, MGAKUREIBO_WORK(ICNT).NENDO2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  4, MGAKUREIBO_WORK(ICNT).NENDO3);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  5, MGAKUREIBO_WORK(ICNT).NENDO4);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  6, MGAKUREIBO_WORK(ICNT).NENDO5);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  7, MGAKUREIBO_WORK(ICNT).NENDO6);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  8, MGAKUREIBO_WORK(ICNT).NENDO7);
                    DBMS_SQL.COLUMN_VALUE(I_CUR,  9, MGAKUREIBO_WORK(ICNT).NENDO8);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 10, MGAKUREIBO_WORK(ICNT).NENDO9);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 11, MGAKUREIBO_WORK(ICNT).KAIPEJI_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 12, MGAKUREIBO_WORK(ICNT).KAIPEJI_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 13, MGAKUREIBO_WORK(ICNT).KAIPEJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 15, MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 16, MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 17, MGAKUREIBO_WORK(ICNT).KANJI_SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 18, MGAKUREIBO_WORK(ICNT).HYOJI_SEIBETSU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 19, MGAKUREIBO_WORK(ICNT).JIDO_CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 20, MGAKUREIBO_WORK(ICNT).JIDO_BANCHI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 21, MGAKUREIBO_WORK(ICNT).JIDO_KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 22, MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 23, MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 24, MGAKUREIBO_WORK(ICNT).ZOKUGARAMEI2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 25, MGAKUREIBO_WORK(ICNT).CHOMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 26, MGAKUREIBO_WORK(ICNT).BANCHI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 27, MGAKUREIBO_WORK(ICNT).KATAGAKI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 28, MGAKUREIBO_WORK(ICNT).SYOGAKOMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 29, MGAKUREIBO_WORK(ICNT).SYOGAKO_NYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 30, MGAKUREIBO_WORK(ICNT).SYOGAKO_TENNYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 31, MGAKUREIBO_WORK(ICNT).SYOGAKO_TENGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 32, MGAKUREIBO_WORK(ICNT).SYOGAKO_SOTSUGYO_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 33, MGAKUREIBO_WORK(ICNT).TYUGAKOMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 34, MGAKUREIBO_WORK(ICNT).TYUGAKO_NYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 35, MGAKUREIBO_WORK(ICNT).TYUGAKO_TENNYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 36, MGAKUREIBO_WORK(ICNT).TYUGAKO_TENGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 37, MGAKUREIBO_WORK(ICNT).TYUGAKO_SOTSUGYO_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 38, MGAKUREIBO_WORK(ICNT).KUIKIGAIMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 39, MGAKUREIBO_WORK(ICNT).KUIKIGAI_SETISYA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 40, MGAKUREIBO_WORK(ICNT).KUIKIGAI_NYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 41, MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENNYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 42, MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENTAIGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 43, MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 44, MGAKUREIBO_WORK(ICNT).KUIKIGAI_TAIGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 45, MGAKUREIBO_WORK(ICNT).KUIKIGAI_SOTSUGYO_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 46, MGAKUREIBO_WORK(ICNT).YOGOGAKOMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 47, MGAKUREIBO_WORK(ICNT).YOGOGAKO_SETISYA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 48, MGAKUREIBO_WORK(ICNT).YOGOGAKO_NYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 49, MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENNYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 50, MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENTAIGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 51, MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 52, MGAKUREIBO_WORK(ICNT).YOGOGAKO_TAIGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 53, MGAKUREIBO_WORK(ICNT).YOGOGAKO_SOTSUGYO_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 54, MGAKUREIBO_WORK(ICNT).YUYO_KYOKA_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 55, MGAKUREIBO_WORK(ICNT).YUYO_JIYU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 56, MGAKUREIBO_WORK(ICNT).YUYO_KAISI_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 57, MGAKUREIBO_WORK(ICNT).YUYO_SYURYO_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 58, MGAKUREIBO_WORK(ICNT).YUYO_FUKUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 59, MGAKUREIBO_WORK(ICNT).MENJO_KYOKA_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 60, MGAKUREIBO_WORK(ICNT).MENJO_JIYU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 61, MGAKUREIBO_WORK(ICNT).MENJO_FUKUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 62, MGAKUREIBO_WORK(ICNT).IDO_BI1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 63, MGAKUREIBO_WORK(ICNT).IDO_JIYU1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 64, MGAKUREIBO_WORK(ICNT).IDO_BI2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 65, MGAKUREIBO_WORK(ICNT).IDO_JIYU2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 66, MGAKUREIBO_WORK(ICNT).IDO_BI3);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 67, MGAKUREIBO_WORK(ICNT).IDO_JIYU3);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 68, MGAKUREIBO_WORK(ICNT).IDO_BI4);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 69, MGAKUREIBO_WORK(ICNT).IDO_JIYU4);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 70, MGAKUREIBO_WORK(ICNT).IDO_BI5);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 71, MGAKUREIBO_WORK(ICNT).IDO_JIYU5);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 72, MGAKUREIBO_WORK(ICNT).IDO_BI6);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 73, MGAKUREIBO_WORK(ICNT).IDO_JIYU6);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 74, MGAKUREIBO_WORK(ICNT).IDO_BI7);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 75, MGAKUREIBO_WORK(ICNT).IDO_JIYU7);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 76, MGAKUREIBO_WORK(ICNT).IDO_BI8);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 77, MGAKUREIBO_WORK(ICNT).IDO_JIYU8);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 78, MGAKUREIBO_WORK(ICNT).IDO_BI9);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 79, MGAKUREIBO_WORK(ICNT).IDO_JIYU9);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 80, MGAKUREIBO_WORK(ICNT).IDO_BI10);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 81, MGAKUREIBO_WORK(ICNT).IDO_JIYU10);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 82, MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 83, MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 84, MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 85, MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 86, MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI3);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 87, MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO3);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 88, MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI4);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 89, MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO4);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 90, MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI5);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 91, MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO5);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 92, MGAKUREIBO_WORK(ICNT).GAKO_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 93, MGAKUREIBO_WORK(ICNT).GAKOMEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 94, VPAGEFIELD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 95, VPAGENAME);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 96, MGAKUREIBO_WORK(ICNT).CD1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 97, MGAKUREIBO_WORK(ICNT).MEISHO1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 98, MGAKUREIBO_WORK(ICNT).CD2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 99, MGAKUREIBO_WORK(ICNT).MEISHO2);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 100, MGAKUREIBO_WORK(ICNT).CD3);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 101, MGAKUREIBO_WORK(ICNT).MEISHO3);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 102, MGAKUREIBO_WORK(ICNT).JIDO_JINKAKU_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 103, MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 104, MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 105, MGAKUREIBO_WORK(ICNT).HOGOSHA_JINKAKU_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 106, MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 107, MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANJI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 108, MGAKUREIBO_WORK(ICNT).SYOGAKO_TENNYUGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 109, MGAKUREIBO_WORK(ICNT).SYOGAKO_TENGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 110, MGAKUREIBO_WORK(ICNT).TYUGAKO_TENNYUGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 111, MGAKUREIBO_WORK(ICNT).TYUGAKO_TENGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 112, MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENNYUGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 113, MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 114, MGAKUREIBO_WORK(ICNT).KUIKIGAI_TAIGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 115, MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENNYUGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 116, MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 117, MGAKUREIBO_WORK(ICNT).YOGOGAKO_TAIGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 118, MGAKUREIBO_WORK(ICNT).SHUGAKU_ZYOKYO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 119, MGAKUREIBO_WORK(ICNT).IDO_ZIYU);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 120, MGAKUREIBO_WORK(ICNT).GAKKYU_CD);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 121, MGAKUREIBO_WORK(ICNT).KYOIKUKAI_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 122, MGAKUREIBO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 123, MGAKUREIBO_WORK(ICNT).KYOIKU_SHUTHOU_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 124, MGAKUREIBO_WORK(ICNT).KYOIKU_RITSU_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 125, MGAKUREIBO_WORK(ICNT).KYOIKU_YUBIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 126, MGAKUREIBO_WORK(ICNT).KYOIKU_JUSHO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 127, MGAKUREIBO_WORK(ICNT).KYOIKU_TEL);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 128, MGAKUREIBO_WORK(ICNT).KYOIKU_TEL_NAISEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 129, MGAKUREIBO_WORK(ICNT).CHOHYO_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 130, MGAKUREIBO_WORK(ICNT).HYOJI_CHOHYO_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 131, MGAKUREIBO_WORK(ICNT).KIJUN_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 132, MGAKUREIBO_WORK(ICNT).KOJIN_NO);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 133, MGAKUREIBO_WORK(ICNT).ZOKUGARAMEI1);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 134, MGAKUREIBO_WORK(ICNT).JIDO_ZENJUSHO);     --児童前住所
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 135, MGAKUREIBO_WORK(ICNT).HOGOSHA_ZENJUSHO);  --保護者前住所
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 136, MGAKUREIBO_WORK(ICNT).JINKAKU_KBN);
--  2024/08/05 ZCZL.YANGXINYU ADD START 0.3.000.001:受入検証対応No182
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 137, MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI6);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 138, MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO6);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 139, MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI7);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 140, MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO7);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 141, MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI8);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 142, MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO8);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 143, MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI9);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 144, MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO9);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 145, MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI10);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 146, MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO10);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 147, MGAKUREIBO_WORK(ICNT).S_TAIGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 148, MGAKUREIBO_WORK(ICNT).S_TAIGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 149, MGAKUREIBO_WORK(ICNT).T_TAIGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 150, MGAKUREIBO_WORK(ICNT).T_TAIGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 151, MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 152, MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_NYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 153, MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 154, MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 155, MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 156, MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 157, MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 158, MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 159, MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_SOTSUGYO_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 160, MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 161, MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_NYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 162, MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 163, MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 164, MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 165, MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 166, MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 167, MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 168, MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_SOTSUGYO_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 169, MGAKUREIBO_WORK(ICNT).YOGO_S_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 170, MGAKUREIBO_WORK(ICNT).YOGO_S_NYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 171, MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 172, MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 173, MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 174, MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 175, MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 176, MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 177, MGAKUREIBO_WORK(ICNT).YOGO_S_SOTSUGYO_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 178, MGAKUREIBO_WORK(ICNT).YOGO_T_MEI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 179, MGAKUREIBO_WORK(ICNT).YOGO_T_NYUGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 180, MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 181, MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 182, MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 183, MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 184, MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 185, MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_GAKUNEN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 186, MGAKUREIBO_WORK(ICNT).YOGO_T_SOTSUGYO_BI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 187, MGAKUREIBO_WORK(ICNT).SHIEN_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 188, MGAKUREIBO_WORK(ICNT).TAISHOSHA_KBN);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 189, MGAKUREIBO_WORK(ICNT).GAITO_KARA);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 190, MGAKUREIBO_WORK(ICNT).GAITO_MADE);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 191, MGAKUREIBO_WORK(ICNT).GAKKO_KBN_CD);
--  2024/11/11 ZCZL.WANGYUNING ADD 0.3.000.007:IT_GKB_00524対応
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--                    DBMS_SQL.COLUMN_VALUE(I_CUR, 192, MGAKUREIBO_WORK(ICNT).SEINENGAPI);
                    DBMS_SQL.COLUMN_VALUE(I_CUR, 192, MGAKUREIBO_WORK(ICNT).HYOJI_SEINENGAPI);
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
--  2024/08/05 ZCZL.YANGXINYU ADD END                   
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
                    MGAKUREIBO_WORK(ICNT).RENBAN := IGYORENBAN;     -- 連番
                    MGAKUREIBO_WORK(ICNT).KAIPEJI := VPAGENAME;   -- 改頁名
                    MGAKUREIBO_WORK(ICNT).KAIPEJI_CD := VPAGEWORK; -- 改頁コード
                    -- 改ページコードと改ページ名の設定
                    IF VPAGEFD = '' THEN
                        MJIDO_WORK(ICNT).KAIPEJI_CD := '';
                        MJIDO_WORK(ICNT).KAIPEJI := '';
                        MJIDO_WORK(ICNT).RENBAN := ICNT +1;
                    END IF;
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
                -- 処理ログの出力
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_GET_JIDO_WK_CSV', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        END;
        RETURN FRET;
    END FUNC_GET_JIDO_WK_CSV;
    --------------------------------------------------------------------------------
    --  機能概要      : 学齢簿レコードの作成
    --  パラメータ    : MMEIBO_REC
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------------------------------
    FUNCTION FUNC_REC_MEIBO(MMEIBO_REC OUT MTMEIBO_REC) RETURN NUMBER IS
        VHANTEI_CD          NVARCHAR2(500);
        IFRET               NUMBER;
    BEGIN
        IFRET := 0;
        --名簿作成レコード初期化
        MMEIBO_REC.NENDO := ' ';
        MMEIBO_REC.NENDO1 := ' ';
        MMEIBO_REC.NENDO2 := ' ';
        MMEIBO_REC.NENDO3 := ' ';
        MMEIBO_REC.NENDO4 := ' ';
        MMEIBO_REC.NENDO5 := ' ';
        MMEIBO_REC.NENDO6 := ' ';
        MMEIBO_REC.NENDO7 := ' ';
        MMEIBO_REC.NENDO8 := ' ';
        MMEIBO_REC.NENDO9 := ' ';
        MMEIBO_REC.KAIPEJI_CD := ' ';
        MMEIBO_REC.KAIPEJI := ' ';
        MMEIBO_REC.RENBAN := ' ';
        MMEIBO_REC.JIDO_SHIMEI_KANJI := ' ';
        MMEIBO_REC.JIDO_SHIMEI_KANA  := ' ';
        MMEIBO_REC.CD1 := ' ';
        MMEIBO_REC.MEISHO1 := ' ';
        MMEIBO_REC.CD2 := ' ';
        MMEIBO_REC.MEISHO2 := ' ';
        MMEIBO_REC.CD3 := ' ';
        MMEIBO_REC.MEISHO3 := ' ';
        MMEIBO_REC.JIDO_HONMYO_KANJI := ' ';
        MMEIBO_REC.JIDO_HONMYO_KANA := ' ';
        MMEIBO_REC.JIDO_JINKAKU_KBN    := ' ';
        MMEIBO_REC.KOJIN_NO            := ' ';
        MMEIBO_REC.NENDO := MGAKUREIBO_WORK(ICNTM).NENDO;
        MMEIBO_REC.NENDO1 := MGAKUREIBO_WORK(ICNTM).NENDO1;
        MMEIBO_REC.NENDO2 := MGAKUREIBO_WORK(ICNTM).NENDO2;
        MMEIBO_REC.NENDO3 := MGAKUREIBO_WORK(ICNTM).NENDO3;
        MMEIBO_REC.NENDO4 := MGAKUREIBO_WORK(ICNTM).NENDO4;
        MMEIBO_REC.NENDO5 := MGAKUREIBO_WORK(ICNTM).NENDO5;
        MMEIBO_REC.NENDO6 := MGAKUREIBO_WORK(ICNTM).NENDO6;
        MMEIBO_REC.NENDO7 := MGAKUREIBO_WORK(ICNTM).NENDO7;
        MMEIBO_REC.NENDO8 := MGAKUREIBO_WORK(ICNTM).NENDO8;
        MMEIBO_REC.NENDO9 := MGAKUREIBO_WORK(ICNTM).NENDO9;
        MMEIBO_REC.KAIPEJI_CD := MGAKUREIBO_WORK(ICNTM).KAIPEJI_CD;
        MMEIBO_REC.KAIPEJI := MGAKUREIBO_WORK(ICNTM).KAIPEJI;
        MMEIBO_REC.RENBAN            := MGAKUREIBO_WORK(ICNTM).RENBAN;
        MMEIBO_REC.JIDO_SHIMEI_KANJI := MGAKUREIBO_WORK(ICNTM).JIDO_SHIMEI_KANJI;
        MMEIBO_REC.JIDO_SHIMEI_KANA  := MGAKUREIBO_WORK(ICNTM).JIDO_SHIMEI_KANA;
        MMEIBO_REC.CD1 := MGAKUREIBO_WORK(ICNTM).CD1;
        MMEIBO_REC.MEISHO1 := MGAKUREIBO_WORK(ICNTM).MEISHO1;
        MMEIBO_REC.CD2 := MGAKUREIBO_WORK(ICNTM).CD2;
        MMEIBO_REC.MEISHO2 := MGAKUREIBO_WORK(ICNTM).MEISHO2;
        MMEIBO_REC.CD3 := MGAKUREIBO_WORK(ICNTM).CD3;
        MMEIBO_REC.MEISHO3 := MGAKUREIBO_WORK(ICNTM).MEISHO3;
        IF MGAKUREIBO_WORK(ICNTM).JIDO_JINKAKU_KBN = 1 THEN
          MMEIBO_REC.JIDO_HONMYO_KANJI := MGAKUREIBO_WORK(ICNTM).JIDO_HONMYO_KANJI;
          MMEIBO_REC.JIDO_HONMYO_KANA := MGAKUREIBO_WORK(ICNTM).JIDO_HONMYO_KANA;
        END IF;
        MMEIBO_REC.CHOHYO_NO :=  MGAKUREIBO_WORK(ICNTM).CHOHYO_NO;
        MMEIBO_REC.KIJUN_BI :=  MGAKUREIBO_WORK(ICNTM).KIJUN_BI;
        MMEIBO_REC.JIDO_JINKAKU_KBN    := MGAKUREIBO_WORK(ICNTM).JIDO_JINKAKU_KBN;
        MMEIBO_REC.KOJIN_NO            := MGAKUREIBO_WORK(ICNTM).KOJIN_NO;
        MMEIBO_REC.JINKAKU_KBN            := MGAKUREIBO_WORK(ICNTM).JINKAKU_KBN;
        ICNTM := ICNTM + 1;
        RETURN IFRET;
    EXCEPTION
        WHEN OTHERS THEN
        RETURN IFRET;
    END FUNC_REC_MEIBO;
    --------------------------------------------------------------------------------
    --  機能概要      : 氏名印字制御ﾊﾟﾗﾒｰﾀの設定の編集
    --  パラメータ    : NSEIGYO_IN_FLG
    --             : NKANRI_FLG
    --             : VSHIMEI_DATA
    --             : VHONMYO_DATA
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------------------------------
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
        IF VSHIMEI_DATA IS NOT NULL THEN
          VRETURN := VSHIMEI_DATA;
        ELSE
          VRETURN := VHONMYO_DATA;
        END IF;
      ELSE
        IF VSHIMEI_DATA IS NOT NULL THEN
          VRETURN := VSHIMEI_DATA;
        ELSE
          VRETURN := VHONMYO_DATA;
        END IF;
      END IF;
      RETURN VRETURN;
    END FUNC_SET_SEIGYO;
-- 2024/06/11 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
   --------------------------------------------------------------------------------
    --  機能概要      : 学齢簿ワークデータの抽出
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.wangyunhan 2024/06/11
    --------------------------------------------------------------------------------
    FUNCTION FUNC_GKBWGAKUREIBO_DATA RETURN BOOLEAN IS
      VSQL                 NVARCHAR2(5000);     --SQL文
      MNENDO_DATA          GKBWGAKUREIBO%ROWTYPE;
      ICNTN                NUMBER:=0;
      BRTN                 BOOLEAN;
      --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.003:8月1日認識合わせの横展開
      -- カーソル
     --CURSOR GAKUREIBODATA IS
     --    SELECT * 
     --    FROM 
     --       GKBWGAKUREIBO 
     --    ORDER BY 
     --      g_rJSTP.ORDERBYCLAUSE;
      TYPE cur_REF IS REF CURSOR;
      GAKUREIBODATA    cur_REF;
      --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE END
   BEGIN
      --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE START 0.3.000.003:8月1日認識合わせの横展開
      --FOR MNENDO_DATA IN GAKUREIBODATA LOOP
      vSQL := 'SELECT *  FROM GKBWGAKUREIBO ';
      IF KKAPK0010.FTrim(g_rJSTP.ORDERBYCLAUSE) IS NOT NULL THEN
          vSQL := vSQL || ' ORDER BY ' || g_rJSTP.ORDERBYCLAUSE;
      END IF;
      OPEN GAKUREIBODATA FOR VSQL;
      LOOP
        FETCH GAKUREIBODATA INTO MNENDO_DATA;
      --  2024/09/09 ZCZL.LIUCHANGQUAN UPDATE END
        EXIT WHEN GAKUREIBODATA%NOTFOUND;
        ICNTN := ICNTN + 1;
        --値設定
        MNENDO_WORK(ICNTN).KOJIN_NO := MNENDO_DATA.KOJIN_NO;
        MNENDO_WORK(ICNTN).JIDO_SHIMEI_KANA := MNENDO_DATA.JIDO_SHIMEI_KANA;
        MNENDO_WORK(ICNTN).JIDO_SHIMEI_KANJI := MNENDO_DATA.JIDO_SHIMEI_KANJI;
        MNENDO_WORK(ICNTN).SEINENGAPI := MNENDO_DATA.SEINENGAPI;
        MNENDO_WORK(ICNTN).HYOJI_SEINENGAPI := MNENDO_DATA.HYOJI_SEINENGAPI;
        MNENDO_WORK(ICNTN).KANJI_SEINENGAPI := MNENDO_DATA.KANJI_SEINENGAPI;
        MNENDO_WORK(ICNTN).SEIBETSU := MNENDO_DATA.SEIBETSU;
        MNENDO_WORK(ICNTN).HYOJI_SEIBETSU := MNENDO_DATA.HYOJI_SEIBETSU;
        MNENDO_WORK(ICNTN).ZOKUGARAMEI1 := MNENDO_DATA.ZOKUGARAMEI1;
        MNENDO_WORK(ICNTN).JIDO_CHOMEI := MNENDO_DATA.JIDO_CHOMEI;
        MNENDO_WORK(ICNTN).JIDO_BANCHI := MNENDO_DATA.JIDO_BANCHI;
        MNENDO_WORK(ICNTN).JIDO_KATAGAKI := MNENDO_DATA.JIDO_KATAGAKI;
        MNENDO_WORK(ICNTN).HOGOSHA_KOJIN_NO := MNENDO_DATA.HOGOSHA_KOJIN_NO;
        MNENDO_WORK(ICNTN).HOGOSHA_SHIMEI_KANA := MNENDO_DATA.HOGOSHA_SHIMEI_KANA;
        MNENDO_WORK(ICNTN).HOGOSHA_SHIMEI_KANJI := MNENDO_DATA.HOGOSHA_SHIMEI_KANJI;
        MNENDO_WORK(ICNTN).ZOKUGARAMEI2 := MNENDO_DATA.ZOKUGARAMEI2;
        MNENDO_WORK(ICNTN).CHOMEI := MNENDO_DATA.CHOMEI;
        MNENDO_WORK(ICNTN).BANCHI := MNENDO_DATA.BANCHI;
        MNENDO_WORK(ICNTN).KATAGAKI := MNENDO_DATA.KATAGAKI;
        MNENDO_WORK(ICNTN).SETAI_NO := MNENDO_DATA.SETAI_NO;
        MNENDO_WORK(ICNTN).GAKUNEN_CD := MNENDO_DATA.GAKUNEN_CD;
        MNENDO_WORK(ICNTN).GAKUNENMEI := MNENDO_DATA.GAKUNENMEI;
        MNENDO_WORK(ICNTN).GYOSEIKU_CD := MNENDO_DATA.GYOSEIKU_CD;
        MNENDO_WORK(ICNTN).GYOSEIKUMEI := MNENDO_DATA.GYOSEIKUMEI;
        MNENDO_WORK(ICNTN).HAN_CD := MNENDO_DATA.HAN_CD;
        MNENDO_WORK(ICNTN).HANMEI := MNENDO_DATA.HANMEI;
        MNENDO_WORK(ICNTN).SANTEIDANTAI_CD := MNENDO_DATA.SANTEIDANTAI_CD;
        MNENDO_WORK(ICNTN).SANTEIDANTAIMEI := MNENDO_DATA.SANTEIDANTAIMEI;
        MNENDO_WORK(ICNTN).SYOGAKO_CD := MNENDO_DATA.SYOGAKO_CD;
        MNENDO_WORK(ICNTN).SYOGAKOMEI := MNENDO_DATA.SYOGAKOMEI;
        MNENDO_WORK(ICNTN).SYOGAKO_NYUGAKU_BI := MNENDO_DATA.SYOGAKO_NYUGAKU_BI;
        MNENDO_WORK(ICNTN).SYOGAKO_TENNYUGAKU_BI := MNENDO_DATA.SYOGAKO_TENNYUGAKU_BI;
        MNENDO_WORK(ICNTN).SYOGAKO_TENGAKU_BI := MNENDO_DATA.SYOGAKO_TENGAKU_BI;
        MNENDO_WORK(ICNTN).SYOGAKO_SOTSUGYO_BI := MNENDO_DATA.SYOGAKO_SOTSUGYO_BI;
        MNENDO_WORK(ICNTN).TYUGAKO_CD := MNENDO_DATA.TYUGAKO_CD;
        MNENDO_WORK(ICNTN).TYUGAKOMEI := MNENDO_DATA.TYUGAKOMEI;
        MNENDO_WORK(ICNTN).TYUGAKO_NYUGAKU_BI := MNENDO_DATA.TYUGAKO_NYUGAKU_BI;
        MNENDO_WORK(ICNTN).TYUGAKO_TENNYUGAKU_BI := MNENDO_DATA.TYUGAKO_TENNYUGAKU_BI;
        MNENDO_WORK(ICNTN).TYUGAKO_TENGAKU_BI := MNENDO_DATA.TYUGAKO_TENGAKU_BI;
        MNENDO_WORK(ICNTN).TYUGAKO_SOTSUGYO_BI := MNENDO_DATA.TYUGAKO_SOTSUGYO_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_CD := MNENDO_DATA.KUIKIGAI_CD;
        MNENDO_WORK(ICNTN).KUIKIGAIMEI := MNENDO_DATA.KUIKIGAIMEI;
        MNENDO_WORK(ICNTN).KUIKIGAI_SETISYA := MNENDO_DATA.KUIKIGAI_SETISYA;
        MNENDO_WORK(ICNTN).KUIKIGAI_NYUGAKU_BI := MNENDO_DATA.KUIKIGAI_NYUGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_TENNYUGAKU_BI := MNENDO_DATA.KUIKIGAI_TENNYUGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_TENTAIGAKU_BI := MNENDO_DATA.KUIKIGAI_TENTAIGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_TENGAKU_BI := MNENDO_DATA.KUIKIGAI_TENGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_TAIGAKU_BI := MNENDO_DATA.KUIKIGAI_TAIGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_SOTSUGYO_BI := MNENDO_DATA.KUIKIGAI_SOTSUGYO_BI;
        MNENDO_WORK(ICNTN).YOGOGAKO_CD := MNENDO_DATA.YOGOGAKO_CD;
        MNENDO_WORK(ICNTN).YOGOGAKOMEI := MNENDO_DATA.YOGOGAKOMEI;
        MNENDO_WORK(ICNTN).YOGOGAKO_SETISYA := MNENDO_DATA.YOGOGAKO_SETISYA;
        MNENDO_WORK(ICNTN).YOGOGAKO_NYUGAKU_BI := MNENDO_DATA.YOGOGAKO_NYUGAKU_BI;
        MNENDO_WORK(ICNTN).YOGOGAKO_TENNYUGAKU_BI := MNENDO_DATA.YOGOGAKO_TENNYUGAKU_BI;
        MNENDO_WORK(ICNTN).YOGOGAKO_TENTAIGAKU_BI := MNENDO_DATA.YOGOGAKO_TENTAIGAKU_BI;
        MNENDO_WORK(ICNTN).YOGOGAKO_TENGAKU_BI := MNENDO_DATA.YOGOGAKO_TENGAKU_BI;
        MNENDO_WORK(ICNTN).YOGOGAKO_TAIGAKU_BI := MNENDO_DATA.YOGOGAKO_TAIGAKU_BI;
        MNENDO_WORK(ICNTN).YOGOGAKO_SOTSUGYO_BI := MNENDO_DATA.YOGOGAKO_SOTSUGYO_BI;
        MNENDO_WORK(ICNTN).YUYO_KYOKA_BI := MNENDO_DATA.YUYO_KYOKA_BI;
        MNENDO_WORK(ICNTN).YUYO_JIYU := MNENDO_DATA.YUYO_JIYU;
        MNENDO_WORK(ICNTN).YUYO_KAISI_BI := MNENDO_DATA.YUYO_KAISI_BI;
        MNENDO_WORK(ICNTN).YUYO_SYURYO_BI := MNENDO_DATA.YUYO_SYURYO_BI;
        MNENDO_WORK(ICNTN).YUYO_FUKUGAKU_BI := MNENDO_DATA.YUYO_FUKUGAKU_BI;
        MNENDO_WORK(ICNTN).MENJO_KYOKA_BI := MNENDO_DATA.MENJO_KYOKA_BI;
        MNENDO_WORK(ICNTN).MENJO_JIYU := MNENDO_DATA.MENJO_JIYU;
        MNENDO_WORK(ICNTN).MENJO_FUKUGAKU_BI := MNENDO_DATA.MENJO_FUKUGAKU_BI;
        MNENDO_WORK(ICNTN).IDO_BI1 := MNENDO_DATA.IDO_BI1;
        MNENDO_WORK(ICNTN).IDO_JIYU1 := MNENDO_DATA.IDO_JIYU1;
        MNENDO_WORK(ICNTN).IDO_BI2 := MNENDO_DATA.IDO_BI2;
        MNENDO_WORK(ICNTN).IDO_JIYU2 := MNENDO_DATA.IDO_JIYU2;
        MNENDO_WORK(ICNTN).IDO_BI3 := MNENDO_DATA.IDO_BI3;
        MNENDO_WORK(ICNTN).IDO_JIYU3 := MNENDO_DATA.IDO_JIYU3;
        MNENDO_WORK(ICNTN).IDO_BI4 := MNENDO_DATA.IDO_BI4;
        MNENDO_WORK(ICNTN).IDO_JIYU4 := MNENDO_DATA.IDO_JIYU4;
        MNENDO_WORK(ICNTN).IDO_BI5 := MNENDO_DATA.IDO_BI5;
        MNENDO_WORK(ICNTN).IDO_JIYU5 := MNENDO_DATA.IDO_JIYU5;
        MNENDO_WORK(ICNTN).IDO_BI6 := MNENDO_DATA.IDO_BI6;
        MNENDO_WORK(ICNTN).IDO_JIYU6 := MNENDO_DATA.IDO_JIYU6;
        MNENDO_WORK(ICNTN).IDO_BI7 := MNENDO_DATA.IDO_BI7;
        MNENDO_WORK(ICNTN).IDO_JIYU7 := MNENDO_DATA.IDO_JIYU7;
        MNENDO_WORK(ICNTN).IDO_BI8 := MNENDO_DATA.IDO_BI8;
        MNENDO_WORK(ICNTN).IDO_JIYU8 := MNENDO_DATA.IDO_JIYU8;
        MNENDO_WORK(ICNTN).IDO_BI9 := MNENDO_DATA.IDO_BI9;
        MNENDO_WORK(ICNTN).IDO_JIYU9 := MNENDO_DATA.IDO_JIYU9;
        MNENDO_WORK(ICNTN).IDO_BI10 := MNENDO_DATA.IDO_BI10;
        MNENDO_WORK(ICNTN).IDO_JIYU10 := MNENDO_DATA.IDO_JIYU10;
        MNENDO_WORK(ICNTN).TOKUSOKU_BI1 := MNENDO_DATA.TOKUSOKU_BI1;
        MNENDO_WORK(ICNTN).TOKUSOKU_NAIYO1 := MNENDO_DATA.TOKUSOKU_NAIYO1;
        MNENDO_WORK(ICNTN).TOKUSOKU_BI2 := MNENDO_DATA.TOKUSOKU_BI2;
        MNENDO_WORK(ICNTN).TOKUSOKU_NAIYO2 := MNENDO_DATA.TOKUSOKU_NAIYO2;
        MNENDO_WORK(ICNTN).TOKUSOKU_BI3 := MNENDO_DATA.TOKUSOKU_BI3;
        MNENDO_WORK(ICNTN).TOKUSOKU_NAIYO3 := MNENDO_DATA.TOKUSOKU_NAIYO3;
        MNENDO_WORK(ICNTN).TOKUSOKU_BI4 := MNENDO_DATA.TOKUSOKU_BI4;
        MNENDO_WORK(ICNTN).TOKUSOKU_NAIYO4 := MNENDO_DATA.TOKUSOKU_NAIYO4;
        MNENDO_WORK(ICNTN).TOKUSOKU_BI5 := MNENDO_DATA.TOKUSOKU_BI5;
        MNENDO_WORK(ICNTN).TOKUSOKU_NAIYO5 := MNENDO_DATA.TOKUSOKU_NAIYO5;
        MNENDO_WORK(ICNTN).TOKUSOKU_BI6 := MNENDO_DATA.TOKUSOKU_BI6;
        MNENDO_WORK(ICNTN).TOKUSOKU_NAIYO6 := MNENDO_DATA.TOKUSOKU_NAIYO6;
        MNENDO_WORK(ICNTN).TOKUSOKU_BI7 := MNENDO_DATA.TOKUSOKU_BI7;
        MNENDO_WORK(ICNTN).TOKUSOKU_NAIYO7 := MNENDO_DATA.TOKUSOKU_NAIYO7;
        MNENDO_WORK(ICNTN).TOKUSOKU_BI8 := MNENDO_DATA.TOKUSOKU_BI8;
        MNENDO_WORK(ICNTN).TOKUSOKU_NAIYO8 := MNENDO_DATA.TOKUSOKU_NAIYO8;
        MNENDO_WORK(ICNTN).TOKUSOKU_BI9 := MNENDO_DATA.TOKUSOKU_BI9;
        MNENDO_WORK(ICNTN).TOKUSOKU_NAIYO9 := MNENDO_DATA.TOKUSOKU_NAIYO9;
        MNENDO_WORK(ICNTN).TOKUSOKU_BI10 := MNENDO_DATA.TOKUSOKU_BI10;
        MNENDO_WORK(ICNTN).TOKUSOKU_NAIYO10 := MNENDO_DATA.TOKUSOKU_NAIYO10;
        MNENDO_WORK(ICNTN).NENDO := MNENDO_DATA.NENDO;
        MNENDO_WORK(ICNTN).NENDO1 := MNENDO_DATA.NENDO1;
        MNENDO_WORK(ICNTN).NENDO2 := MNENDO_DATA.NENDO2;
        MNENDO_WORK(ICNTN).NENDO3 := MNENDO_DATA.NENDO3;
        MNENDO_WORK(ICNTN).NENDO4 := MNENDO_DATA.NENDO4;
        MNENDO_WORK(ICNTN).NENDO5 := MNENDO_DATA.NENDO5;
        MNENDO_WORK(ICNTN).NENDO6 := MNENDO_DATA.NENDO6;
        MNENDO_WORK(ICNTN).NENDO7 := MNENDO_DATA.NENDO7;
        MNENDO_WORK(ICNTN).NENDO8 := MNENDO_DATA.NENDO8;
        MNENDO_WORK(ICNTN).NENDO9 := MNENDO_DATA.NENDO9;
        MNENDO_WORK(ICNTN).KAIPEJI_KBN := MNENDO_DATA.KAIPEJI_KBN;
        MNENDO_WORK(ICNTN).KAIPEJI_CD := MNENDO_DATA.KAIPEJI_CD;
        MNENDO_WORK(ICNTN).KAIPEJI := MNENDO_DATA.KAIPEJI;
        MNENDO_WORK(ICNTN).RENBAN := MNENDO_DATA.RENBAN;
        MNENDO_WORK(ICNTN).GAKO_CD := MNENDO_DATA.GAKO_CD;
        MNENDO_WORK(ICNTN).GAKOMEI := MNENDO_DATA.GAKOMEI;
        MNENDO_WORK(ICNTN).CD1 := MNENDO_DATA.CD1;
        MNENDO_WORK(ICNTN).MEISHO1 := MNENDO_DATA.MEISHO1;
        MNENDO_WORK(ICNTN).CD2 := MNENDO_DATA.CD2;
        MNENDO_WORK(ICNTN).MEISHO2 := MNENDO_DATA.MEISHO2;
        MNENDO_WORK(ICNTN).CD3 := MNENDO_DATA.CD3;
        MNENDO_WORK(ICNTN).MEISHO3 := MNENDO_DATA.MEISHO3;
        MNENDO_WORK(ICNTN).JIDO_JINKAKU_KBN := MNENDO_DATA.JIDO_JINKAKU_KBN;
        MNENDO_WORK(ICNTN).JIDO_HONMYO_KANA := MNENDO_DATA.JIDO_HONMYO_KANA;
        MNENDO_WORK(ICNTN).JIDO_HONMYO_KANJI := MNENDO_DATA.JIDO_HONMYO_KANJI;
        MNENDO_WORK(ICNTN).HOGOSHA_JINKAKU_KBN := MNENDO_DATA.HOGOSHA_JINKAKU_KBN;
        MNENDO_WORK(ICNTN).HOGOSHA_HONMYO_KANA := MNENDO_DATA.HOGOSHA_HONMYO_KANA;
        MNENDO_WORK(ICNTN).HOGOSHA_HONMYO_KANJI := MNENDO_DATA.HOGOSHA_HONMYO_KANJI;
        MNENDO_WORK(ICNTN).SYOGAKO_TENNYUGAKU_GAKUNEN := MNENDO_DATA.SYOGAKO_TENNYUGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).SYOGAKO_TENGAKU_GAKUNEN := MNENDO_DATA.SYOGAKO_TENGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).TYUGAKO_TENNYUGAKU_GAKUNEN := MNENDO_DATA.TYUGAKO_TENNYUGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).TYUGAKO_TENGAKU_GAKUNEN := MNENDO_DATA.TYUGAKO_TENGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).KUIKIGAI_TENNYUGAKU_GAKUNEN := MNENDO_DATA.KUIKIGAI_TENNYUGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).KUIKIGAI_TENGAKU_GAKUNEN := MNENDO_DATA.KUIKIGAI_TENGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).KUIKIGAI_TAIGAKU_GAKUNEN := MNENDO_DATA.KUIKIGAI_TAIGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).YOGOGAKO_TENNYUGAKU_GAKUNEN := MNENDO_DATA.YOGOGAKO_TENNYUGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).YOGOGAKO_TENGAKU_GAKUNEN := MNENDO_DATA.YOGOGAKO_TENGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).YOGOGAKO_TAIGAKU_GAKUNEN := MNENDO_DATA.YOGOGAKO_TAIGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).SHUGAKU_ZYOKYO := MNENDO_DATA.SHUGAKU_ZYOKYO;
        MNENDO_WORK(ICNTN).IDO_ZIYU := MNENDO_DATA.IDO_ZIYU;
        MNENDO_WORK(ICNTN).GAKKYU_CD := MNENDO_DATA.GAKKYU_CD;
        MNENDO_WORK(ICNTN).KYOIKUKAI_MEI := MNENDO_DATA.KYOIKUKAI_MEI;
        MNENDO_WORK(ICNTN).KYOIKU_YAKUSHOKU_MEI := MNENDO_DATA.KYOIKU_YAKUSHOKU_MEI;
        MNENDO_WORK(ICNTN).KYOIKU_SHUTHOU_MEI := MNENDO_DATA.KYOIKU_SHUTHOU_MEI;
        MNENDO_WORK(ICNTN).KYOIKU_RITSU_MEI := MNENDO_DATA.KYOIKU_RITSU_MEI;
        MNENDO_WORK(ICNTN).KYOIKU_YUBIN_NO := MNENDO_DATA.KYOIKU_YUBIN_NO;
        MNENDO_WORK(ICNTN).KYOIKU_JUSHO := MNENDO_DATA.KYOIKU_JUSHO;
        MNENDO_WORK(ICNTN).KYOIKU_TEL := MNENDO_DATA.KYOIKU_TEL;
        MNENDO_WORK(ICNTN).KYOIKU_TEL_NAISEN := MNENDO_DATA.KYOIKU_TEL_NAISEN;
        MNENDO_WORK(ICNTN).CHOHYO_NO := MNENDO_DATA.CHOHYO_NO;
        MNENDO_WORK(ICNTN).HYOJI_CHOHYO_NO := MNENDO_DATA.HYOJI_CHOHYO_NO;
        MNENDO_WORK(ICNTN).KIJUN_BI := MNENDO_DATA.KIJUN_BI;
        MNENDO_WORK(ICNTN).JIDO_ZENJUSHO := MNENDO_DATA.JIDO_ZENJUSHO;
        MNENDO_WORK(ICNTN).HOGOSHA_ZENJUSHO := MNENDO_DATA.HOGOSHA_ZENJUSHO;
        MNENDO_WORK(ICNTN).JINKAKU_KBN := MNENDO_DATA.JINKAKU_KBN;
        MNENDO_WORK(ICNTN).S_TAIGAKU_BI := MNENDO_DATA.S_TAIGAKU_BI;
        MNENDO_WORK(ICNTN).S_TAIGAKU_GAKUNEN := MNENDO_DATA.S_TAIGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).T_TAIGAKU_BI := MNENDO_DATA.T_TAIGAKU_BI;
        MNENDO_WORK(ICNTN).T_TAIGAKU_GAKUNEN := MNENDO_DATA.T_TAIGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).KUIKIGAI_S_MEI := MNENDO_DATA.KUIKIGAI_S_MEI;
        MNENDO_WORK(ICNTN).KUIKIGAI_S_NYUGAKU_BI := MNENDO_DATA.KUIKIGAI_S_NYUGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_S_TENNYU_BI := MNENDO_DATA.KUIKIGAI_S_TENNYU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_S_TENNYU_GAKUNEN := MNENDO_DATA.KUIKIGAI_S_TENNYU_GAKUNEN;
        MNENDO_WORK(ICNTN).KUIKIGAI_S_TENGAKU_BI := MNENDO_DATA.KUIKIGAI_S_TENGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_S_TENGAKU_GAKUNEN := MNENDO_DATA.KUIKIGAI_S_TENGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).KUIKIGAI_S_TAIGAKU_BI := MNENDO_DATA.KUIKIGAI_S_TAIGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_S_TAIGAKU_GAKUNEN := MNENDO_DATA.KUIKIGAI_S_TAIGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).KUIKIGAI_S_SOTSUGYO_BI := MNENDO_DATA.KUIKIGAI_S_SOTSUGYO_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_T_MEI := MNENDO_DATA.KUIKIGAI_T_MEI;
        MNENDO_WORK(ICNTN).KUIKIGAI_T_NYUGAKU_BI := MNENDO_DATA.KUIKIGAI_T_NYUGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_T_TENNYU_BI := MNENDO_DATA.KUIKIGAI_T_TENNYU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_T_TENNYU_GAKUNEN := MNENDO_DATA.KUIKIGAI_T_TENNYU_GAKUNEN;
        MNENDO_WORK(ICNTN).KUIKIGAI_T_TENGAKU_BI := MNENDO_DATA.KUIKIGAI_T_TENGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_T_TENGAKU_GAKUNEN := MNENDO_DATA.KUIKIGAI_T_TENGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).KUIKIGAI_T_TAIGAKU_BI := MNENDO_DATA.KUIKIGAI_T_TAIGAKU_BI;
        MNENDO_WORK(ICNTN).KUIKIGAI_T_TAIGAKU_GAKUNEN := MNENDO_DATA.KUIKIGAI_T_TAIGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).KUIKIGAI_T_SOTSUGYO_BI := MNENDO_DATA.KUIKIGAI_T_SOTSUGYO_BI;
        MNENDO_WORK(ICNTN).YOGO_S_MEI := MNENDO_DATA.YOGO_S_MEI;
        MNENDO_WORK(ICNTN).YOGO_S_NYUGAKU_BI := MNENDO_DATA.YOGO_S_NYUGAKU_BI;
        MNENDO_WORK(ICNTN).YOGO_S_TENNYU_BI := MNENDO_DATA.YOGO_S_TENNYU_BI;
        MNENDO_WORK(ICNTN).YOGO_S_TENNYU_GAKUNEN := MNENDO_DATA.YOGO_S_TENNYU_GAKUNEN;
        MNENDO_WORK(ICNTN).YOGO_S_TENGAKU_BI := MNENDO_DATA.YOGO_S_TENGAKU_BI;
        MNENDO_WORK(ICNTN).YOGO_S_TENGAKU_GAKUNEN := MNENDO_DATA.YOGO_S_TENGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).YOGO_S_TAIGAKU_BI := MNENDO_DATA.YOGO_S_TAIGAKU_BI;
        MNENDO_WORK(ICNTN).YOGO_S_TAIGAKU_GAKUNEN := MNENDO_DATA.YOGO_S_TAIGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).YOGO_S_SOTSUGYO_BI := MNENDO_DATA.YOGO_S_SOTSUGYO_BI;
        MNENDO_WORK(ICNTN).YOGO_T_MEI := MNENDO_DATA.YOGO_T_MEI;
        MNENDO_WORK(ICNTN).YOGO_T_NYUGAKU_BI := MNENDO_DATA.YOGO_T_NYUGAKU_BI;
        MNENDO_WORK(ICNTN).YOGO_T_TENNYU_BI := MNENDO_DATA.YOGO_T_TENNYU_BI;
        MNENDO_WORK(ICNTN).YOGO_T_TENNYU_GAKUNEN := MNENDO_DATA.YOGO_T_TENNYU_GAKUNEN;
        MNENDO_WORK(ICNTN).YOGO_T_TENGAKU_BI := MNENDO_DATA.YOGO_T_TENGAKU_BI;
        MNENDO_WORK(ICNTN).YOGO_T_TENGAKU_GAKUNEN := MNENDO_DATA.YOGO_T_TENGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).YOGO_T_TAIGAKU_BI := MNENDO_DATA.YOGO_T_TAIGAKU_BI;
        MNENDO_WORK(ICNTN).YOGO_T_TAIGAKU_GAKUNEN := MNENDO_DATA.YOGO_T_TAIGAKU_GAKUNEN;
        MNENDO_WORK(ICNTN).YOGO_T_SOTSUGYO_BI := MNENDO_DATA.YOGO_T_SOTSUGYO_BI;
        MNENDO_WORK(ICNTN).SHIEN_KBN := MNENDO_DATA.SHIEN_KBN;
        MNENDO_WORK(ICNTN).TAISHOSHA_KBN := MNENDO_DATA.TAISHOSHA_KBN;
        MNENDO_WORK(ICNTN).GAITO_KARA := MNENDO_DATA.GAITO_KARA;
        MNENDO_WORK(ICNTN).GAITO_MADE := MNENDO_DATA.GAITO_MADE;
        MNENDO_WORK(ICNTN).GAKKO_KBN_CD := MNENDO_DATA.GAKKO_KBN_CD;
        END LOOP;
      --  2024/09/09 ZCZL.LIUCHANGQUAN ADD 0.3.000.003:8月1日認識合わせの横展開
      CLOSE GAKUREIBODATA;
      RETURN TRUE;
    EXCEPTION
      WHEN OTHERS THEN
        --  2024/09/09 ZCZL.LIUCHANGQUAN ADD START 0.3.000.003:8月1日認識合わせの横展開
        IF GAKUREIBODATA%ISOPEN THEN
          CLOSE GAKUREIBODATA;
        END IF;
        --  2024/09/09 ZCZL.LIUCHANGQUAN ADD END
        RETURN FALSE;
    END FUNC_GKBWGAKUREIBO_DATA;
-- 2024/06/11 ZCZL.wangyunhan Add end 
    --------------------------------------------------------------------------------
    --  機能概要      : 学齢簿の作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        IRET                PLS_INTEGER;                -- 戻り値
        BRET                BOOLEAN;                    -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMAX                BINARY_INTEGER;             -- 最大値（出力件数）
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        VDATA               NVARCHAR2(3000);            -- データ（１レコード分）
        VYUBIN_NO           NVARCHAR2(60);              -- 郵便番号編集用
        N_NAIYO_CD_JIDO     GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;
        VEDIT_GO_DATA       NVARCHAR2(1000) := '';
        VADDRESS            NVARCHAR2(150);             --住所編集用
        rRECODE1            GKBWL050R001%ROWTYPE;
        nROWNUM             NUMBER;
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        iSHIMEI_KANA        NVARCHAR2(150); 
        iSHIMEI_KANJI       NVARCHAR2(150);
        iSEINENGAPI         NVARCHAR2(150); 
        iSHIMEI_KANA2       NVARCHAR2(150); 
        iSHIMEI_KANJI2      NVARCHAR2(150);
        iSEINENGAPI2        NVARCHAR2(150); 
        o_tITEM             A_CONS_PRM;                 --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
        FLG                     NUMBER :=1;
        TOKUSOKU_BI             A_CONS_PRM;          --督促年月日
        TOKUSOKU_NAIYO          A_CONS_PRM;          --督促内容
        INDX                    NUMBER := 10;
-- 2024/06/04 ZCZL.wangyunhan Add end
    BEGIN
        FRET := c_ISUCCESS;                       -- 正常終了
        IMAX := MGAKUREIBO_WORK.LAST;             -- ワーク領域の件数の最大値
        IMIN := MGAKUREIBO_WORK.FIRST;            -- ワーク領域の件数の最小値
        nROWNUM := 0;
        -- 取得した件数分繰り返す
        FOR ICNT IN IMIN..IMAX LOOP
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
--  2024/08/05 ZCZL.YANGXINYU DELETE START 0.3.000.001:受入検証対応No187
--            IRET := GKBFKHMCTRL(MGAKUREIBO_WORK(ICNT).KOJIN_NO,g_rJSTP.CHOHYOID,0,g_GAKUNENNPOSEIGYO,iSHIMEI_KANA,iSHIMEI_KANJI,iSEINENGAPI);
--            IRET := GKBFKHMCTRL(MGAKUREIBO_WORK(ICNT).HOGOSHA_KOJIN_NO,g_rJSTP.CHOHYOID,1,g_GAKUNENNPOSEIGYO,iSHIMEI_KANA2,iSHIMEI_KANJI2,iSEINENGAPI2);
--  2024/08/05 ZCZL.YANGXINYU DELETE END            
-- 2024/06/04 ZCZL.wangyunhan Add end
            rRECODE1                       :=   NULL                                        ;
            nROWNUM                        :=   nROWNUM + 1                                 ;
            rRECODE1.NO                    :=   nROWNUM                                     ;-- ソート順
            rRECODE1.RENBAN                :=   MGAKUREIBO_WORK(ICNT).RENBAN                ;-- 連番
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--             rRECODE1.JIDO_SHIMEI_KANA      :=   MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA      ;-- 児童氏名カナ
--             rRECODE1.JIDO_SHIMEI_KANJI     :=   MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI     ;-- 児童氏名漢字
--             rRECODE1.HYOJI_SEINENGAPI      :=   MGAKUREIBO_WORK(ICNT).KANJI_SEINENGAPI      ;-- 児童生年月日
--  2024/08/05 ZCZL.YANGXINYU UPDATE START 0.3.000.001:受入検証対応No187
--            rRECODE1.JIDO_SHIMEI_KANA      :=  iSHIMEI_KANA  ;-- 児童氏名カナ
--            rRECODE1.JIDO_SHIMEI_KANJI     :=  iSHIMEI_KANJI ;-- 児童氏名漢字
--            rRECODE1.HYOJI_SEINENGAPI      :=  iSEINENGAPI   ;-- 児童生年月日
             rRECODE1.JIDO_SHIMEI_KANA      :=   MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA      ;-- 児童氏名カナ
             rRECODE1.JIDO_SHIMEI_KANJI     :=   MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI     ;-- 児童氏名漢字
--  2024/11/11 ZCZL.WANGYUNING UPDATE 0.3.000.007:IT_GKB_00524対応
             --rRECODE1.HYOJI_SEINENGAPI      :=   MGAKUREIBO_WORK(ICNT).KANJI_SEINENGAPI      ;-- 児童生年月日
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--             rRECODE1.HYOJI_SEINENGAPI      :=   MGAKUREIBO_WORK(ICNT).SEINENGAPI      ;-- 児童生年月日
             rRECODE1.HYOJI_SEINENGAPI      :=   MGAKUREIBO_WORK(ICNT).HYOJI_SEINENGAPI      ;-- 児童生年月日
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
--  2024/08/05 ZCZL.YANGXINYU UPDATE END          
-- 2024/06/04 ZCZL.wangyunhan Update end
            rRECODE1.JIDO_HYOJI_SEIBETSU   :=   MGAKUREIBO_WORK(ICNT).HYOJI_SEIBETSU        ;-- 児童性別
            VADDRESS := '';
            VADDRESS := GAAPK0010.FADDRESSEDIT( 1, '',  MGAKUREIBO_WORK(ICNT).JIDO_CHOMEI, MGAKUREIBO_WORK(ICNT).JIDO_BANCHI, MGAKUREIBO_WORK(ICNT).JIDO_KATAGAKI, '');
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--            rRECODE1.JIDO_JUSHO            :=  NULL                                        ;-- 児童住所
            rRECODE1.JIDO_JUSHO            :=  VADDRESS                                    ;-- 児童住所
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
            rRECODE1.HOGOSHA_SHIMEI_KANA   :=  MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA   ;-- 保護者氏名カナ
            rRECODE1.HOGOSHA_SHIMEI_KANJI  :=  MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI  ;-- 保護者氏名漢字
            rRECODE1.ZOKUGARA              :=  MGAKUREIBO_WORK(ICNT).ZOKUGARAMEI2          ;-- 続柄
            VADDRESS := '';
            VADDRESS := GAAPK0010.FADDRESSEDIT( 1, '',  MGAKUREIBO_WORK(ICNT).CHOMEI, MGAKUREIBO_WORK(ICNT).BANCHI, MGAKUREIBO_WORK(ICNT).KATAGAKI, '');
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 Start
--            rRECODE1.HOGOSHA_JUSHO          :=      NULL                                          ;-- 保護者住所
            rRECODE1.HOGOSHA_JUSHO          :=      VADDRESS                                      ;-- 保護者住所
--  2024/11/21 JPJYS.LIUHUAIQI UPDATE 0.3.000.010:IT_GKB_00586,IT_GKB_00616,IT_GKB_00627,IT_GKB_00628,IT_GKB_00640,IT_GKB_00644対応 End
            rRECODE1.SHOGAKKO_MEI           :=      MGAKUREIBO_WORK(ICNT).SYOGAKOMEI              ;-- 小学校名
            rRECODE1.SHOGAKKO_NYUGAKU_BI    :=      MGAKUREIBO_WORK(ICNT).SYOGAKO_NYUGAKU_BI      ;-- 小学校入学日
            rRECODE1.SHOGAKKO_TENNYUGAKU_BI :=      MGAKUREIBO_WORK(ICNT).SYOGAKO_TENNYUGAKU_BI   ;-- 小学校転入学日
            rRECODE1.SHOGAKKO_TENGAKU_BI    :=      MGAKUREIBO_WORK(ICNT).SYOGAKO_TENGAKU_BI      ;-- 小学校転学日
            rRECODE1.SHOGAKKO_SOTSUGYO_BI   :=      MGAKUREIBO_WORK(ICNT).SYOGAKO_SOTSUGYO_BI     ;-- 小学校卒業日
            rRECODE1.TYUGAKOMEI             :=      MGAKUREIBO_WORK(ICNT).TYUGAKOMEI              ;-- 中学校名
            rRECODE1.TYUGAKO_NYUGAKU_BI     :=      MGAKUREIBO_WORK(ICNT).TYUGAKO_NYUGAKU_BI      ;-- 中学校入学日
            rRECODE1.TYUGAKO_TENNYUGAKU_BI  :=      MGAKUREIBO_WORK(ICNT).TYUGAKO_TENNYUGAKU_BI   ;-- 中学校転入学日
            rRECODE1.TYUGAKO_TENGAKU_BI     :=      MGAKUREIBO_WORK(ICNT).TYUGAKO_TENGAKU_BI      ;-- 中学校転学日
            rRECODE1.TYUGAKO_SOTSUGYO_BI    :=      MGAKUREIBO_WORK(ICNT).TYUGAKO_SOTSUGYO_BI     ;-- 中学校卒業日
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--             rRECODE1.KUIKIGAI_GAKKO_MEI     :=      MGAKUREIBO_WORK(ICNT).KUIKIGAIMEI             ;-- 区域外学校名
--             rRECODE1.KUIKIGAI_SETISYA       :=      MGAKUREIBO_WORK(ICNT).KUIKIGAI_SETISYA        ;-- 区域外学校設置者名
--             rRECODE1.KUIKIGAI_NYUGAKU_BI    :=      MGAKUREIBO_WORK(ICNT).KUIKIGAI_NYUGAKU_BI     ;-- 区域外学校入学日
--             rRECODE1.KUIKIGAI_TENNYUGAKU_BI :=      MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENNYUGAKU_BI  ;-- 区域外学校転入学日
--             rRECODE1.KUIKIGAI_TENTAIGAKU_BI :=      MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENTAIGAKU_BI  ;-- 区域外学校転退学日
--             rRECODE1.KUIKIGAI_TENGAKU_BI    :=      MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENGAKU_BI     ;-- 区域外学校転学日
--             rRECODE1.KUIKIGAI_TAIGAKU_BI    :=      MGAKUREIBO_WORK(ICNT).KUIKIGAI_TAIGAKU_BI     ;-- 区域外学校退学日
--             rRECODE1.KUIKIGAI_SOTSUGYO_BI   :=      MGAKUREIBO_WORK(ICNT).KUIKIGAI_SOTSUGYO_BI    ;-- 区域外学校卒業日
--             rRECODE1.YOGOGAKOMEI            :=      MGAKUREIBO_WORK(ICNT).YOGOGAKOMEI             ;-- 養護学校名
--             rRECODE1.YOGOGAKO_SETISYA       :=      MGAKUREIBO_WORK(ICNT).YOGOGAKO_SETISYA        ;-- 養護学校設置者名
--             rRECODE1.YOGOGAKO_NYUGAKU_BI    :=      MGAKUREIBO_WORK(ICNT).YOGOGAKO_NYUGAKU_BI     ;-- 養護学校入学日
--             rRECODE1.YOGOGAKO_TENNYUGAKU_BI :=      MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENNYUGAKU_BI  ;-- 養護学校転入学日
--             rRECODE1.YOGOGAKO_TENTAIGAKU_BI :=      MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENTAIGAKU_BI  ;-- 養護学校転退学日
--             rRECODE1.YOGOGAKO_TENGAKU_BI    :=      MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENGAKU_BI     ;-- 養護学校転学日
--             rRECODE1.YOGOGAKO_TAIGAKU_BI    :=      MGAKUREIBO_WORK(ICNT).YOGOGAKO_TAIGAKU_BI     ;-- 養護学校退学日
--             rRECODE1.YOGOGAKO_SOTSUGYO_BI   :=      MGAKUREIBO_WORK(ICNT).YOGOGAKO_SOTSUGYO_BI    ;-- 養護学校卒業日
-- 2024/06/04 ZCZL.wangyunhan Delete end
            rRECODE1.YUYO_KYOKA_BI          :=      MGAKUREIBO_WORK(ICNT).YUYO_KYOKA_BI           ;-- 猶予許可日
            rRECODE1.YUYO_JIYU              :=      MGAKUREIBO_WORK(ICNT).YUYO_JIYU               ;-- 猶予許可事由
            rRECODE1.YUYO_KAISI_BI          :=      MGAKUREIBO_WORK(ICNT).YUYO_KAISI_BI           ;-- 猶予開始日
            rRECODE1.YUYO_SYURYO_BI         :=      MGAKUREIBO_WORK(ICNT).YUYO_SYURYO_BI          ;-- 猶予終了日
            rRECODE1.YUYO_FUKUGAKU_BI       :=      MGAKUREIBO_WORK(ICNT).YUYO_FUKUGAKU_BI        ;-- 猶予復学日
            rRECODE1.MENJO_KYOKA_BI         :=      MGAKUREIBO_WORK(ICNT).MENJO_KYOKA_BI          ;-- 免除許可日
            rRECODE1.MENJO_JIYU             :=      MGAKUREIBO_WORK(ICNT).MENJO_JIYU              ;-- 免除許可事由
            rRECODE1.MENJO_FUKUGAKU_BI      :=      MGAKUREIBO_WORK(ICNT).MENJO_FUKUGAKU_BI       ;-- 免除復学日
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--             rRECODE1.TOKUSOKU_BI1           :=      MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI1            ;-- 督促年月日１
--             rRECODE1.TOKUSOKU_NAIYO1        :=      MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO1         ;-- 督促内容１
--             rRECODE1.TOKUSOKU_BI2           :=      MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI2            ;-- 督促年月日２
--             rRECODE1.TOKUSOKU_NAIYO2        :=      MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO2         ;-- 督促内容２
--             rRECODE1.TOKUSOKU_BI3           :=      MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI3            ;-- 督促年月日３
--             rRECODE1.TOKUSOKU_NAIYO3        :=      MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO3         ;-- 督促内容３
--             rRECODE1.TOKUSOKU_BI4           :=      MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI4            ;-- 督促年月日４
--             rRECODE1.TOKUSOKU_NAIYO4        :=      MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO4         ;-- 督促内容４
--             rRECODE1.TOKUSOKU_BI5           :=      MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI5            ;-- 督促年月日５
--             rRECODE1.TOKUSOKU_NAIYO5        :=      MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO5         ;-- 督促内容５
              TOKUSOKU_BI := A_CONS_PRM();
              TOKUSOKU_NAIYO := A_CONS_PRM();
              TOKUSOKU_BI.Extend(10);
              TOKUSOKU_NAIYO.Extend(10);
            --督促年月日1-10と督促内容1-10の取得
                  IF MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI10 IS NOT NULL AND MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO10 IS NOT NULL THEN 
                     TOKUSOKU_BI(10)    := MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI10;
                     TOKUSOKU_NAIYO(10) := MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO10;
                  END IF;
                  IF MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI9 IS NOT NULL AND MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO9 IS NOT NULL THEN 
                     TOKUSOKU_BI(9)    := MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI9;
                     TOKUSOKU_NAIYO(9) := MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO9;
                  END IF;
                  IF MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI8 IS NOT NULL AND MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO8 IS NOT NULL THEN 
                     TOKUSOKU_BI(8)    := MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI8;
                     TOKUSOKU_NAIYO(8) := MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO8;
                  END IF;
                  IF MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI7 IS NOT NULL AND MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO7 IS NOT NULL THEN 
                     TOKUSOKU_BI(7)    := MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI7;
                     TOKUSOKU_NAIYO(7) := MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO7;
                  END IF;
                  IF MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI6 IS NOT NULL AND MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO6 IS NOT NULL THEN 
                     TOKUSOKU_BI(6)    := MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI6;
                     TOKUSOKU_NAIYO(6) := MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO6;
                  END IF;
                  IF MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI5 IS NOT NULL AND MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO5 IS NOT NULL THEN 
                     TOKUSOKU_BI(5)    := MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI5;
                     TOKUSOKU_NAIYO(5) := MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO5;
                  END IF;
                  IF MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI4 IS NOT NULL AND MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO4 IS NOT NULL THEN 
                     TOKUSOKU_BI(4)    := MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI4;
                     TOKUSOKU_NAIYO(4) := MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO4;
                  END IF;
                  IF MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI3 IS NOT NULL AND MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO3 IS NOT NULL THEN 
                     TOKUSOKU_BI(3)    := MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI3;
                     TOKUSOKU_NAIYO(3) := MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO3;
                  END IF;
                  IF MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI2 IS NOT NULL AND MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO2 IS NOT NULL THEN 
                     TOKUSOKU_BI(2)    := MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI2;
                     TOKUSOKU_NAIYO(2) := MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO2;
                  END IF;
                  IF MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI1 IS NOT NULL AND MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO1 IS NOT NULL THEN 
                     TOKUSOKU_BI(1)    := MGAKUREIBO_WORK(ICNT).TOKUSOKU_BI1;
                     TOKUSOKU_NAIYO(1) := MGAKUREIBO_WORK(ICNT).TOKUSOKU_NAIYO1;
                  END IF;
            --督促年月日1-5と督促内容1-5の取得 
               FOR i IN 1..10 LOOP
                 IF TOKUSOKU_BI(i) IS NOT NULL AND TOKUSOKU_NAIYO(i) IS NOT NULL THEN 
                     IF FLG = 1 THEN 
                        rRECODE1.TOKUSOKU_BI1      := TOKUSOKU_BI(i);
                        rRECODE1.TOKUSOKU_NAIYO1   := TOKUSOKU_NAIYO(i);
                        FLG  := FLG + 1;
                     ELSIF FLG = 2 THEN 
                        rRECODE1.TOKUSOKU_BI2      := TOKUSOKU_BI(i);
                        rRECODE1.TOKUSOKU_NAIYO2   := TOKUSOKU_NAIYO(i);
                        FLG  := FLG + 1;
                     ELSIF FLG = 3 THEN 
                        rRECODE1.TOKUSOKU_BI3      := TOKUSOKU_BI(i);
                        rRECODE1.TOKUSOKU_NAIYO3   := TOKUSOKU_NAIYO(i);
                        FLG  := FLG + 1;
                     ELSIF FLG = 4 THEN 
                        rRECODE1.TOKUSOKU_BI4      := TOKUSOKU_BI(i);
                        rRECODE1.TOKUSOKU_NAIYO4   := TOKUSOKU_NAIYO(i);
                        FLG  := FLG + 1;
                     ELSIF FLG = 5 THEN
                        rRECODE1.TOKUSOKU_BI5      := TOKUSOKU_BI(i);
                        rRECODE1.TOKUSOKU_NAIYO5   := TOKUSOKU_NAIYO(i);
                        FLG  := FLG + 1;
                     ELSE 
                       EXIT;
                     END IF; 
                  END IF;
               END LOOP;
-- 2024/06/12 ZCZL.wangyunhan Update end 
            rRECODE1.IDO_JIYU5              :=      MGAKUREIBO_WORK(ICNT).IDO_JIYU5               ;-- 異動事由５
            rRECODE1.IDO_BI6                :=      MGAKUREIBO_WORK(ICNT).IDO_BI6                 ;-- 異動事由年月日６
            rRECODE1.IDO_JIYU6              :=      MGAKUREIBO_WORK(ICNT).IDO_JIYU6               ;-- 異動事由６
            rRECODE1.IDO_BI7                :=      MGAKUREIBO_WORK(ICNT).IDO_BI7                 ;-- 異動年月日７
            rRECODE1.IDO_JIYU7              :=      MGAKUREIBO_WORK(ICNT).IDO_JIYU7               ;-- 異動事由７
            rRECODE1.IDO_BI8                :=      MGAKUREIBO_WORK(ICNT).IDO_BI8                 ;-- 異動年月日８
            rRECODE1.IDO_JIYU8              :=      MGAKUREIBO_WORK(ICNT).IDO_JIYU8               ;-- 異動事由８
            rRECODE1.IDO_BI9                :=      MGAKUREIBO_WORK(ICNT).IDO_BI9                 ;-- 異動年月日９
            rRECODE1.IDO_JIYU9              :=      MGAKUREIBO_WORK(ICNT).IDO_JIYU9               ;-- 異動事由９
            rRECODE1.IDO_BI10               :=      MGAKUREIBO_WORK(ICNT).IDO_BI10                ;-- 異動年月日１０
            rRECODE1.IDO_JIYU10             :=      MGAKUREIBO_WORK(ICNT).IDO_JIYU10              ;-- 異動事由１０
            rRECODE1.KYOIKU_KAI_MEI         :=      MGAKUREIBO_WORK(ICNT).KYOIKUKAI_MEI           ;-- 教育委員会名
            rRECODE1.GAKKO_CD               :=      MGAKUREIBO_WORK(ICNT).GAKO_CD                 ;-- 学校コード
            rRECODE1.GAKKO_MEI              :=      NULL                                          ;-- 学校名
            rRECODE1.JIDO_GYOSEIKU_CD       :=      MGAKUREIBO_WORK(ICNT).CD1                     ;-- 児童行政区コード
            rRECODE1.JIDO_GYOSEIKU_MEI      :=      MGAKUREIBO_WORK(ICNT).MEISHO1                 ;-- 児童行政区名
            rRECODE1.CD2                    :=      MGAKUREIBO_WORK(ICNT).CD2                     ;-- 保護者行政区コード
            rRECODE1.MEISHO2                :=      MGAKUREIBO_WORK(ICNT).MEISHO2                 ;-- 保護者行政区名
            rRECODE1.CD3                    :=      MGAKUREIBO_WORK(ICNT).CD3                     ;-- 予備コード
            rRECODE1.MEISHO3                :=      MGAKUREIBO_WORK(ICNT).MEISHO3                 ;-- 予備名称

            -- 外国人の場合、本名かな・本名漢字を出力する
            IF MGAKUREIBO_WORK(ICNT).JIDO_JINKAKU_KBN = 1 THEN
               rRECODE1.GKJ_JIDO_HONMYO_KANA      :=    MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANA                  ;-- 外国人児童本名かな
               rRECODE1.GKJ_JIDO_HONMYO_KANJI     :=    MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANJI                 ;-- 外国人児童本名漢字
            ELSE
              rRECODE1.GKJ_JIDO_HONMYO_KANA      :=    NULL;
              rRECODE1.GKJ_JIDO_HONMYO_KANJI     :=    NULL;
            END IF;
            IF MGAKUREIBO_WORK(ICNT).HOGOSHA_JINKAKU_KBN = 1 THEN
              rRECODE1.GKJ_HOGOSHA_HONMYO_KANA  :=   MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANA               ;--外国人保護者本名かな
            ELSE
              rRECODE1.GKJ_HOGOSHA_HONMYO_KANA  := NULL;
            END IF;
            IF MGAKUREIBO_WORK(ICNT).HOGOSHA_JINKAKU_KBN  = 1 THEN
              rRECODE1.GKJ_HOGOSHA_HONMYO_KANJI   :=   MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANJI            ;--外国人保護者本名漢字
            ELSE
              rRECODE1.GKJ_HOGOSHA_HONMYO_KANJI   :=   NULL;
            END IF;
            --  2024/11/06 ZCZL.ZHANGLEI ADD START 0.3.000.006:IT_GKB_00474対応
            rRECODE1.JIDO_HONMYO_KANA := MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA;     -- 表示児童氏名かな
            rRECODE1.JIDO_HONMYO_KANJI := MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI;    -- 表示児童氏名漢字
            rRECODE1.HYOJI_HOGOSHA_SHIMEI_KANA := MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA; -- 表示保護者氏名カナ
            rRECODE1.HOGOSHA_HONMYO_KANJI := MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;     -- 表示保護者氏名漢字
            --  2024/11/06 ZCZL.ZHANGLEI ADD END
            --  2024/11/06 ZCZL.ZHANGLEI DEL START 0.3.000.006:IT_GKB_00474対応
            --児童の制御情報を取得
            -- 表示児童氏名かな
              --外国人場合
            --IF MGAKUREIBO_WORK(ICNT).JIDO_JINKAKU_KBN = 1 THEN
            -- IRTN  := FUNC_PRMFLGSET(MGAKUREIBO_WORK(ICNT).KOJIN_NO,ACONSPRM_SHIMEI(1),N_NAIYO_CD_JIDO);  
            -- VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(1),N_NAIYO_CD_JIDO,
            --                  TRIM(MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA),TRIM(MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANA));
            -- rRECODE1.JIDO_HONMYO_KANA    :=    VEDIT_GO_DATA;
            --ELSE
            -- --外国人以外場合
            -- IF ACONSPRM_SHIMEI(1) = 1 THEN
            --   IF  MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANA IS NOT NULL THEN
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--                  rRECODE1.JIDO_HONMYO_KANA    :=  MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANA;
           --      rRECODE1.JIDO_HONMYO_KANA    :=  iSHIMEI_KANA;
           --    ELSE
           --      rRECODE1.JIDO_HONMYO_KANA    :=  MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA;
           --    END IF;
           --  ELSE
           --    rRECODE1.JIDO_HONMYO_KANA    :=  MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANA;
           --  END IF;
           -- END IF;
           -- -- 表示児童氏名漢字
           --  --外国人場合
           -- IF MGAKUREIBO_WORK(ICNT).JIDO_JINKAKU_KBN = 1 THEN
           --  VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(1),N_NAIYO_CD_JIDO,
           --                   TRIM(MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI),TRIM(MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANJI));
           --  rRECODE1.JIDO_HONMYO_KANJI   :=   VEDIT_GO_DATA;
           -- ELSE
           --  --外国人以外の場合
           --  IF ACONSPRM_SHIMEI(1) = 1 THEN
           --    IF MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANJI IS NOT NULL THEN
-- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
--                   rRECODE1.JIDO_HONMYO_KANJI   :=   MGAKUREIBO_WORK(ICNT).JIDO_HONMYO_KANJI;
            --      rRECODE1.JIDO_HONMYO_KANJI   :=  iSHIMEI_KANJI;
            --   ELSE
            --      rRECODE1.JIDO_HONMYO_KANJI   :=   MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI;
            --   END IF;
            -- ELSE
            --   rRECODE1.JIDO_HONMYO_KANJI   :=   MGAKUREIBO_WORK(ICNT).JIDO_SHIMEI_KANJI;
            -- END IF;
            --END IF;
            --  2024/11/06 ZCZL.ZHANGLEI DEL END
            -- 表示保護者氏名かな
--  2024/08/12 ZCZL.YANGXINYU UPDATE START 0.3.000.002:受入検証対応No182
--             --外国人場合
--            IF MGAKUREIBO_WORK(ICNT).HOGOSHA_JINKAKU_KBN = 1 THEN
--             VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(1),N_NAIYO_CD_JIDO,
--                              TRIM(MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA),TRIM(MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANA));
--             rRECODE1.HYOJI_HOGOSHA_SHIMEI_KANA    :=     VEDIT_GO_DATA;
--            ELSE
--             --外国人以外の場合
--             IF ACONSPRM_SHIMEI(1) = 1 THEN
--               IF MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANA IS NOT NULL THEN
---- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
----                  rRECODE1.HYOJI_HOGOSHA_SHIMEI_KANA    :=  MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANA;
--                 rRECODE1.HYOJI_HOGOSHA_SHIMEI_KANA    :=    iSHIMEI_KANA2;
--               ELSE
--                 rRECODE1.HYOJI_HOGOSHA_SHIMEI_KANA    :=    MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;
--               END IF;
--             ELSE
--               rRECODE1.HYOJI_HOGOSHA_SHIMEI_KANA    :=    MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;
--             END IF;
--            END IF;
            rRECODE1.HYOJI_HOGOSHA_SHIMEI_KANA    :=    MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANA;
--  2024/08/12 ZCZL.YANGXINYU UPDATE END     
            -- 表示保護者氏名漢字
--  2024/08/12 ZCZL.YANGXINYU UPDATE START 0.3.000.002:受入検証対応No182
--             --外国人場合
--            IF MGAKUREIBO_WORK(ICNT).HOGOSHA_JINKAKU_KBN = 1 THEN
--             VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(1),N_NAIYO_CD_JIDO,
--                              TRIM(MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI),TRIM(MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANJI));
--             rRECODE1.HOGOSHA_HONMYO_KANJI     :=     VEDIT_GO_DATA;
--            ELSE
--             IF ACONSPRM_SHIMEI(1) = 1 THEN
--               IF MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANJI IS NOT NULL THEN
---- 2024/06/04 ZCZL.wangyunhan Update 0.3.000.000:新WizLIFE２次開発
----                   rRECODE1.HOGOSHA_HONMYO_KANJI    :=     MGAKUREIBO_WORK(ICNT).HOGOSHA_HONMYO_KANJI;
--                  rRECODE1.HOGOSHA_HONMYO_KANJI    :=    iSHIMEI_KANJI2;
--               ELSE
--                  rRECODE1.HOGOSHA_HONMYO_KANJI    :=     MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;
--               END IF;
--             ELSE
--               rRECODE1.HOGOSHA_HONMYO_KANJI    :=     MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;
--             END IF;
--            END IF;
           rRECODE1.HOGOSHA_HONMYO_KANJI    :=     MGAKUREIBO_WORK(ICNT).HOGOSHA_SHIMEI_KANJI;
--  2024/08/12 ZCZL.YANGXINYU UPDATE END
           rRECODE1.KOJIN_NO    :=     MGAKUREIBO_WORK(ICNT).KOJIN_NO;
           -- 表示帳票連番
           IF NRENBAN = 0 THEN
               rRECODE1.HYOJI_CHOHYO_NO    :=   MGAKUREIBO_WORK(ICNT).HYOJI_CHOHYO_NO;
           ELSE
               rRECODE1.HYOJI_CHOHYO_NO    :=   MGAKUREIBO_WORK(ICNT).RENBAN;
           END IF;
           rRECODE1.HOGOSHA_KANKEI     :=   MGAKUREIBO_WORK(ICNT).ZOKUGARAMEI1;
           IF MGAKUREIBO_WORK(ICNT).SYOGAKO_TENNYUGAKU_GAKUNEN > 0 THEN
             rRECODE1.SHOGAKKO_TENNYUGAKU_GAKUNEN   :=   MGAKUREIBO_WORK(ICNT).SYOGAKO_TENNYUGAKU_GAKUNEN || '学年';
           ELSE
             rRECODE1.SHOGAKKO_TENNYUGAKU_GAKUNEN   :=   NULL;
           END IF;
           IF MGAKUREIBO_WORK(ICNT).SYOGAKO_TENGAKU_GAKUNEN > 0 THEN
             rRECODE1.SHOGAKKO_TENGAKU_GAKUNEN     :=    MGAKUREIBO_WORK(ICNT).SYOGAKO_TENGAKU_GAKUNEN || '学年';
           ELSE
             rRECODE1.SHOGAKKO_TENGAKU_GAKUNEN     :=    NULL;
           END IF;
           IF MGAKUREIBO_WORK(ICNT).TYUGAKO_TENNYUGAKU_GAKUNEN > 0 THEN
             rRECODE1.TYUGAKO_TENNYUGAKU_GAKUNEN   :=   MGAKUREIBO_WORK(ICNT).TYUGAKO_TENNYUGAKU_GAKUNEN || '学年';
           ELSE
             rRECODE1.TYUGAKO_TENNYUGAKU_GAKUNEN   :=   NULL;
           END IF;
           IF MGAKUREIBO_WORK(ICNT).TYUGAKO_TENGAKU_GAKUNEN > 0 THEN
             rRECODE1.TYUGAKO_TENGAKU_GAKUNEN  :=    MGAKUREIBO_WORK(ICNT).TYUGAKO_TENGAKU_GAKUNEN || '学年';
           ELSE
             rRECODE1.TYUGAKO_TENGAKU_GAKUNEN  :=   NULL;
           END IF;
-- 2024/06/04 ZCZL.wangyunhan Delete start 0.3.000.000:新WizLIFE２次開発
--            IF MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENNYUGAKU_GAKUNEN > 0 THEN
--              rRECODE1.KUIKIGAI_TENNYUGAKU_GAKUNEN  :=  MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENNYUGAKU_GAKUNEN || '学年';
--            ELSE
--              rRECODE1.KUIKIGAI_TENNYUGAKU_GAKUNEN  :=  NULL;
--            END IF;
--            IF MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENGAKU_GAKUNEN > 0 THEN
--              rRECODE1.KUIKIGAI_TENGAKU_GAKUNEN  :=    MGAKUREIBO_WORK(ICNT).KUIKIGAI_TENGAKU_GAKUNEN || '学年';
--            ELSE
--              rRECODE1.KUIKIGAI_TENGAKU_GAKUNEN  :=    NULL;
--            END IF;
--            IF MGAKUREIBO_WORK(ICNT).KUIKIGAI_TAIGAKU_GAKUNEN > 0 THEN
--              rRECODE1.KUIKIGAI_TAIGAKU_GAKUNEN  :=   MGAKUREIBO_WORK(ICNT).KUIKIGAI_TAIGAKU_GAKUNEN || '学年';
--            ELSE
--              rRECODE1.KUIKIGAI_TAIGAKU_GAKUNEN  :=   NULL;
--            END IF;
--            IF MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENNYUGAKU_GAKUNEN > 0 THEN
--              rRECODE1.YOGOGAKO_TENNYUGAKU_GAKUNEN  :=   MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENNYUGAKU_GAKUNEN || '学年';
--            ELSE
--              rRECODE1.YOGOGAKO_TENNYUGAKU_GAKUNEN  :=   NULL;
--            END IF;
--            IF MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENGAKU_GAKUNEN > 0 THEN
--              rRECODE1.YOGOGAKO_TENGAKU_GAKUNEN  :=   MGAKUREIBO_WORK(ICNT).YOGOGAKO_TENGAKU_GAKUNEN || '学年';
--            ELSE
--              rRECODE1.YOGOGAKO_TENGAKU_GAKUNEN  :=   NULL;
--            END IF;
--            IF MGAKUREIBO_WORK(ICNT).YOGOGAKO_TAIGAKU_GAKUNEN > 0 THEN
--              rRECODE1.YOGOGAKO_TAIGAKU_GAKUNEN  :=    MGAKUREIBO_WORK(ICNT).YOGOGAKO_TAIGAKU_GAKUNEN || '学年';
--            ELSE
--              rRECODE1.YOGOGAKO_TAIGAKU_GAKUNEN  :=    NULL;
--            END IF;
-- 2024/06/04 ZCZL.wangyunhan Delete end 
           rRECODE1.SHUGAKU              :=  MGAKUREIBO_WORK(ICNT).SHUGAKU_ZYOKYO         ;-- 就学状況
           rRECODE1.IDO_JIKO             :=  MGAKUREIBO_WORK(ICNT).IDO_ZIYU               ;-- 異動事項
           rRECODE1.KYOIKU_YAKUSHOKU_MEI :=  MGAKUREIBO_WORK(ICNT).KYOIKU_YAKUSHOKU_MEI   ;-- 教育委員会役職名
           rRECODE1.KYOIKU_SHUCHO_MEI    :=  MGAKUREIBO_WORK(ICNT).KYOIKU_SHUTHOU_MEI     ;-- 教育委員会首長名
           rRECODE1.KYOIKU_RITSU_MEI     :=  MGAKUREIBO_WORK(ICNT).KYOIKU_RITSU_MEI       ;-- 教育委員会立名

           IF LENGTH(MGAKUREIBO_WORK(ICNT).KYOIKU_YUBIN_NO) > 0 THEN
               VYUBIN_NO := SUBSTR(MGAKUREIBO_WORK(ICNT).KYOIKU_YUBIN_NO,1,3)||'-'||SUBSTR(MGAKUREIBO_WORK(ICNT).KYOIKU_YUBIN_NO,4);
               VYUBIN_NO := TRANSLATE(VYUBIN_NO, '1234567890-', '１２３４５６７８９０－' );
               rRECODE1.KYOIKU_YUBIN_NO  :=   VYUBIN_NO;
           ELSE
               rRECODE1.KYOIKU_YUBIN_NO  :=   NULL;
           END IF;
           rRECODE1.KYOIKU_JUSHO         :=    MGAKUREIBO_WORK(ICNT).KYOIKU_JUSHO        ;-- 教育委員会住所
           rRECODE1.KYOIKU_TEL           :=    MGAKUREIBO_WORK(ICNT).KYOIKU_TEL          ;-- 教育委員会電話
           rRECODE1.KYOIKU_TEL_NAISEN    :=    MGAKUREIBO_WORK(ICNT).KYOIKU_TEL_NAISEN   ;-- 教育委員会電話内線
           rRECODE1.JIDO_ZENJUSHO        :=    MGAKUREIBO_WORK(ICNT).JIDO_ZENJUSHO       ;-- 児童前住所
           rRECODE1.HOGOSHA_ZENJUSHO     :=    MGAKUREIBO_WORK(ICNT).HOGOSHA_ZENJUSHO    ;-- 保護者前住所
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
--  2024/08/05 ZCZL.YANGXINYU UPDATE START 0.3.000.001:受入検証対応No182
--           rRECODE1.S_TAIGAKU_BI        := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).S_TAIGAKU_BI,1);                            -- 小学校退学日
--           rRECODE1.S_TAIGAKU_GAKUNEN   := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).S_TAIGAKU_GAKUNEN);            -- 小学校退学学年
--           rRECODE1.T_TAIGAKU_BI        := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).T_TAIGAKU_BI,1);                            -- 中学校退学日
--           rRECODE1.T_TAIGAKU_GAKUNEN   := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).T_TAIGAKU_GAKUNEN);            -- 中学校退学学年
--           rRECODE1.KUIKIGAI_S_MEI      := MNENDO_WORK(ICNT).KUIKIGAI_S_MEI ;                            -- 区域外就学小学校学校名
--           rRECODE1.KUIKIGAI_S_NYUGAKU_BI      := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).KUIKIGAI_S_NYUGAKU_BI,1);              -- 区域外就学小学校入学年月日
--           rRECODE1.KUIKIGAI_S_TENNYU_BI       := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).KUIKIGAI_S_TENNYU_BI,1);                                -- 区域外就学小学校転入学日
--           rRECODE1.KUIKIGAI_S_TENNYU_GAKUNEN  := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).KUIKIGAI_S_TENNYU_GAKUNEN);                 -- 区域外就学小学校転入学学年
--           rRECODE1.KUIKIGAI_S_TENGAKU_BI      := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).KUIKIGAI_S_TENGAKU_BI,1);                               -- 区域外就学小学校転学日
--           rRECODE1.KUIKIGAI_S_TENGAKU_GAKUNEN := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).KUIKIGAI_S_TENGAKU_GAKUNEN);                --区域外就学小学校転学学年
--           rRECODE1.KUIKIGAI_S_TAIGAKU_BI      := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_BI,1);                               -- 区域外就学小学校退学日
--           rRECODE1.KUIKIGAI_S_TAIGAKU_GAKUNEN := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_GAKUNEN);                -- 区域外就学小学校退学学年
--           rRECODE1.KUIKIGAI_S_SOTSUGYO_BI     := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).KUIKIGAI_S_SOTSUGYO_BI,1);                              -- 区域外就学小学校卒業年月日
--           rRECODE1.KUIKIGAI_T_MEI             := MNENDO_WORK(ICNT).KUIKIGAI_T_MEI;                                          -- 区域外就学中学校学校名
--           rRECODE1.KUIKIGAI_T_NYUGAKU_BI      := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).KUIKIGAI_T_NYUGAKU_BI,1);                               -- 区域外就学中学校入学年月日編集用 
--           rRECODE1.KUIKIGAI_T_TENNYU_BI       := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).KUIKIGAI_T_TENNYU_BI,1);                                -- 区域外就学中学校転入学日編集用 
--           rRECODE1.KUIKIGAI_T_TENNYU_GAKUNEN  := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).KUIKIGAI_T_TENNYU_GAKUNEN);                 -- 区域外就学中学校転入学学年
--           rRECODE1.KUIKIGAI_T_TENGAKU_BI      := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).KUIKIGAI_T_TENGAKU_BI,1);
--           rRECODE1.KUIKIGAI_T_TENGAKU_GAKUNEN := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).KUIKIGAI_T_TENGAKU_GAKUNEN);                -- 区域外就学中学校転学学年
--           rRECODE1.KUIKIGAI_T_TAIGAKU_BI      := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_BI,1);
--           rRECODE1.KUIKIGAI_T_TAIGAKU_GAKUNEN := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_GAKUNEN);                -- 区域外就学中学校退学学年
--           rRECODE1.KUIKIGAI_T_SOTSUGYO_BI     := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).KUIKIGAI_T_SOTSUGYO_BI,1);
--           rRECODE1.SHIEN_S_MEI                := MNENDO_WORK(ICNT).YOGO_S_MEI ;                                            -- 特別支援学校小学校部学校名
--           rRECODE1.SHIEN_S_NYUGAKU_BI         := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).YOGO_S_NYUGAKU_BI,1);
--           rRECODE1.SHIEN_S_TENNYU_BI          := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).YOGO_S_TENNYU_BI,1);
--           rRECODE1.SHIEN_S_TENNYU_GAKUNEN     := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).YOGO_S_TENNYU_GAKUNEN);                    -- 特別支援学校小学校部転入学学年
--           rRECODE1.SHIEN_S_TENGAKU_BI         := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).YOGO_S_TENGAKU_BI,1);
--           rRECODE1.SHIEN_S_TENGAKU_GAKUNEN    := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).YOGO_S_TENGAKU_GAKUNEN);                   -- 特別支援学校小学校部転学学年
--           rRECODE1.SHIEN_S_TAIGAKU_BI         := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).YOGO_S_TAIGAKU_BI,1);
--           rRECODE1.SHIEN_S_TAIGAKU_GAKUNEN    := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).YOGO_S_TAIGAKU_GAKUNEN);                   -- 特別支援学校小学校部転学学年
--           rRECODE1.SHIEN_S_SOTSUGYO_BI        := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).YOGO_S_SOTSUGYO_BI,1);                -- 特別支援学校小学校部卒業年月日編集用
--           rRECODE1.SHIEN_T_MEI                := MNENDO_WORK(ICNT).YOGO_T_MEI;                                             -- 特別支援学校中学校部学校名
--           rRECODE1.SHIEN_T_NYUGAKU_BI         := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).YOGO_T_NYUGAKU_BI,1);
--           rRECODE1.SHIEN_T_TENNYU_BI          := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).YOGO_T_TENNYU_BI,1);
--           rRECODE1.SHIEN_T_TENNYU_GAKUNEN     := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).YOGO_T_TENNYU_GAKUNEN);                    -- 特別支援学校中学校部転入学学年
--           rRECODE1.SHIEN_T_TENGAKU_BI         := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).YOGO_T_TENGAKU_BI,1);
--           rRECODE1.SHIEN_T_TENGAKU_GAKUNEN    := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).YOGO_T_TENGAKU_GAKUNEN);                   -- 特別支援学校中学校部転学学年
--           rRECODE1.SHIEN_T_TAIGAKU_BI         := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).YOGO_T_TAIGAKU_BI,1);
--           rRECODE1.SHIEN_T_TAIGAKU_GAKUNEN    := GKAFKGKNGTEQ(MNENDO_WORK(ICNT).YOGO_T_TAIGAKU_GAKUNEN);                    -- 特別支援学校中学校部退学学年
--           rRECODE1.SHIEN_T_SOTSUGYO_BI        := KKAPK0020.FDateFmt(MNENDO_WORK(ICNT).YOGO_T_SOTSUGYO_BI,1); 
--           rRECODE1.SHIEN_KBN                  := MNENDO_WORK(ICNT).SHIEN_KBN;       --支援措置区分
--           rRECODE1.TAISYOSYA_KBN              := MNENDO_WORK(ICNT).TAISHOSHA_KBN;   --対象者区分
--           rRECODE1.GAITO_KARA                 := MNENDO_WORK(ICNT).GAITO_KARA;      --支援措置開始年月日
--           rRECODE1.GAITO_MADE                 := MNENDO_WORK(ICNT).GAITO_MADE;      --支援措置終了年月日
           rRECODE1.S_TAIGAKU_BI        := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).S_TAIGAKU_BI,1);                            -- 小学校退学日
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.S_TAIGAKU_GAKUNEN   := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).S_TAIGAKU_GAKUNEN);            -- 小学校退学学年
           IF MGAKUREIBO_WORK(ICNT).S_TAIGAKU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).S_TAIGAKU_GAKUNEN IS NULL THEN
             rRECODE1.S_TAIGAKU_GAKUNEN   := NULL;            -- 小学校退学学年
           ELSE
             rRECODE1.S_TAIGAKU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).S_TAIGAKU_GAKUNEN || '学年';            -- 小学校退学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.T_TAIGAKU_BI        := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).T_TAIGAKU_BI,1);                            -- 中学校退学日
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.T_TAIGAKU_GAKUNEN   := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).T_TAIGAKU_GAKUNEN);            -- 中学校退学学年
           IF MGAKUREIBO_WORK(ICNT).T_TAIGAKU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).T_TAIGAKU_GAKUNEN IS NULL THEN
             rRECODE1.T_TAIGAKU_GAKUNEN   := NULL;            -- 中学校退学学年
           ELSE
             rRECODE1.T_TAIGAKU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).T_TAIGAKU_GAKUNEN || '学年';            -- 中学校退学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.KUIKIGAI_S_MEI      := MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_MEI ;                            -- 区域外就学小学校学校名
           rRECODE1.KUIKIGAI_S_NYUGAKU_BI      := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_NYUGAKU_BI,1);              -- 区域外就学小学校入学年月日
           rRECODE1.KUIKIGAI_S_TENNYU_BI       := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_BI,1);                                -- 区域外就学小学校転入学日
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.KUIKIGAI_S_TENNYU_GAKUNEN  := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_GAKUNEN);                 -- 区域外就学小学校転入学学年
           IF MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_GAKUNEN IS NULL THEN
             rRECODE1.KUIKIGAI_S_TENNYU_GAKUNEN   := NULL;            -- 区域外就学小学校転入学学年
           ELSE
             rRECODE1.KUIKIGAI_S_TENNYU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENNYU_GAKUNEN || '学年';            -- 区域外就学小学校転入学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.KUIKIGAI_S_TENGAKU_BI      := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_BI,1);                               -- 区域外就学小学校転学日
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.KUIKIGAI_S_TENGAKU_GAKUNEN := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_GAKUNEN);                --区域外就学小学校転学学年
           IF MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_GAKUNEN IS NULL THEN
             rRECODE1.KUIKIGAI_S_TENGAKU_GAKUNEN   := NULL;            -- 区域外就学小学校転学学年
           ELSE
             rRECODE1.KUIKIGAI_S_TENGAKU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TENGAKU_GAKUNEN || '学年';            -- 区域外就学小学校転学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.KUIKIGAI_S_TAIGAKU_BI      := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_BI,1);                               -- 区域外就学小学校退学日
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.KUIKIGAI_S_TAIGAKU_GAKUNEN := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_GAKUNEN);                -- 区域外就学小学校退学学年
           IF MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_GAKUNEN IS NULL THEN
             rRECODE1.KUIKIGAI_S_TAIGAKU_GAKUNEN   := NULL;            -- 区域外就学小学校退学学年
           ELSE
             rRECODE1.KUIKIGAI_S_TAIGAKU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_TAIGAKU_GAKUNEN || '学年';            -- 区域外就学小学校退学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.KUIKIGAI_S_SOTSUGYO_BI     := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).KUIKIGAI_S_SOTSUGYO_BI,1);                              -- 区域外就学小学校卒業年月日
           rRECODE1.KUIKIGAI_T_MEI             := MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_MEI;                                          -- 区域外就学中学校学校名
           rRECODE1.KUIKIGAI_T_NYUGAKU_BI      := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_NYUGAKU_BI,1);                               -- 区域外就学中学校入学年月日編集用
           rRECODE1.KUIKIGAI_T_TENNYU_BI       := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_BI,1);                                -- 区域外就学中学校転入学日編集用
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.KUIKIGAI_T_TENNYU_GAKUNEN  := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_GAKUNEN);                 -- 区域外就学中学校転入学学年
           IF MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_GAKUNEN IS NULL THEN
             rRECODE1.KUIKIGAI_T_TENNYU_GAKUNEN   := NULL;            -- 区域外就学中学校転入学学年
           ELSE
             rRECODE1.KUIKIGAI_T_TENNYU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENNYU_GAKUNEN || '学年';            -- 区域外就学中学校転入学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.KUIKIGAI_T_TENGAKU_BI      := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_BI,1);
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.KUIKIGAI_T_TENGAKU_GAKUNEN := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_GAKUNEN);                -- 区域外就学中学校転学学年
           IF MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_GAKUNEN IS NULL THEN
             rRECODE1.KUIKIGAI_T_TENGAKU_GAKUNEN   := NULL;            -- 区域外就学中学校転学学年
           ELSE
             rRECODE1.KUIKIGAI_T_TENGAKU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TENGAKU_GAKUNEN || '学年';            -- 区域外就学中学校転学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.KUIKIGAI_T_TAIGAKU_BI      := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_BI,1);
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.KUIKIGAI_T_TAIGAKU_GAKUNEN := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_GAKUNEN);                -- 区域外就学中学校退学学年
           IF MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_GAKUNEN IS NULL THEN
             rRECODE1.KUIKIGAI_T_TAIGAKU_GAKUNEN   := NULL;            -- 区域外就学中学校退学学年
           ELSE
             rRECODE1.KUIKIGAI_T_TAIGAKU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_TAIGAKU_GAKUNEN || '学年';            -- 区域外就学中学校退学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.KUIKIGAI_T_SOTSUGYO_BI     := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).KUIKIGAI_T_SOTSUGYO_BI,1);
           rRECODE1.SHIEN_S_MEI                := MGAKUREIBO_WORK(ICNT).YOGO_S_MEI ;                                            -- 特別支援学校小学校部学校名
           rRECODE1.SHIEN_S_NYUGAKU_BI         := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).YOGO_S_NYUGAKU_BI,1);
           rRECODE1.SHIEN_S_TENNYU_BI          := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_BI,1);
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.SHIEN_S_TENNYU_GAKUNEN     := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_GAKUNEN);                    -- 特別支援学校小学校部転入学学年
           IF MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_GAKUNEN IS NULL THEN
             rRECODE1.SHIEN_S_TENNYU_GAKUNEN   := NULL;            -- 特別支援学校小学校部転入学学年
           ELSE
             rRECODE1.SHIEN_S_TENNYU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).YOGO_S_TENNYU_GAKUNEN || '学年';            -- 特別支援学校小学校部転入学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.SHIEN_S_TENGAKU_BI         := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_BI,1);
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.SHIEN_S_TENGAKU_GAKUNEN    := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_GAKUNEN);                   -- 特別支援学校小学校部転学学年
           IF MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_GAKUNEN IS NULL THEN
             rRECODE1.SHIEN_S_TENGAKU_GAKUNEN   := NULL;            -- 特別支援学校小学校部転学学年
           ELSE
             rRECODE1.SHIEN_S_TENGAKU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).YOGO_S_TENGAKU_GAKUNEN || '学年';            -- 特別支援学校小学校部転学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.SHIEN_S_TAIGAKU_BI         := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_BI,1);
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.SHIEN_S_TAIGAKU_GAKUNEN    := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_GAKUNEN);                   -- 特別支援学校小学校部転学学年
           IF MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_GAKUNEN IS NULL THEN
             rRECODE1.SHIEN_S_TAIGAKU_GAKUNEN   := NULL;            -- 特別支援学校小学校部転学学年
           ELSE
             rRECODE1.SHIEN_S_TAIGAKU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).YOGO_S_TAIGAKU_GAKUNEN || '学年';            -- 特別支援学校小学校部転学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.SHIEN_S_SOTSUGYO_BI        := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).YOGO_S_SOTSUGYO_BI,1);                -- 特別支援学校小学校部卒業年月日編集用
           rRECODE1.SHIEN_T_MEI                := MGAKUREIBO_WORK(ICNT).YOGO_T_MEI;                                             -- 特別支援学校中学校部学校名
           rRECODE1.SHIEN_T_NYUGAKU_BI         := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).YOGO_T_NYUGAKU_BI,1);
           rRECODE1.SHIEN_T_TENNYU_BI          := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_BI,1);
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.SHIEN_T_TENNYU_GAKUNEN     := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_GAKUNEN);                    -- 特別支援学校中学校部転入学学年
           IF MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_GAKUNEN IS NULL THEN
             rRECODE1.SHIEN_T_TENNYU_GAKUNEN   := NULL;            -- 特別支援学校中学校部転入学学年
           ELSE
             rRECODE1.SHIEN_T_TENNYU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).YOGO_T_TENNYU_GAKUNEN || '学年';            -- 特別支援学校中学校部転入学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.SHIEN_T_TENGAKU_BI         := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_BI,1);
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.SHIEN_T_TENGAKU_GAKUNEN    := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_GAKUNEN);                   -- 特別支援学校中学校部転学学年
           IF MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_GAKUNEN IS NULL THEN
             rRECODE1.SHIEN_T_TENGAKU_GAKUNEN   := NULL;            -- 特別支援学校中学校部転学学年
           ELSE
             rRECODE1.SHIEN_T_TENGAKU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).YOGO_T_TENGAKU_GAKUNEN || '学年';            -- 特別支援学校中学校部転学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.SHIEN_T_TAIGAKU_BI         := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_BI,1);
--  2024/11/14 ZCZL.WANGMING UPDATE START 0.3.000.008:仕様変更　ID：IT_GKB_00518、IT_GKB_00519対応
--           rRECODE1.SHIEN_T_TAIGAKU_GAKUNEN    := GKAFKGKNGTEQ(MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_GAKUNEN);                    -- 特別支援学校中学校部退学学年
           IF MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_GAKUNEN = 0 OR MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_GAKUNEN IS NULL THEN
             rRECODE1.SHIEN_T_TAIGAKU_GAKUNEN   := NULL;            -- 特別支援学校中学校部退学学年
           ELSE
             rRECODE1.SHIEN_T_TAIGAKU_GAKUNEN   := MGAKUREIBO_WORK(ICNT).YOGO_T_TAIGAKU_GAKUNEN || '学年';            -- 特別支援学校中学校部退学学年
           END IF;
--  2024/11/14 ZCZL.WANGMING UPDATE END
           rRECODE1.SHIEN_T_SOTSUGYO_BI        := KKAPK0020.FDateFmt(MGAKUREIBO_WORK(ICNT).YOGO_T_SOTSUGYO_BI,1);
           rRECODE1.SHIEN_KBN                  := MGAKUREIBO_WORK(ICNT).SHIEN_KBN;       --支援措置区分
           rRECODE1.TAISYOSYA_KBN              := MGAKUREIBO_WORK(ICNT).TAISHOSHA_KBN;   --対象者区分
           rRECODE1.GAITO_KARA                 := MGAKUREIBO_WORK(ICNT).GAITO_KARA;      --支援措置開始年月日
           rRECODE1.GAITO_MADE                 := MGAKUREIBO_WORK(ICNT).GAITO_MADE;      --支援措置終了年月日
--  2024/08/05 ZCZL.YANGXINYU UPDATE END
           rRECODE1.YOSHIKI_NO                 := rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO || rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO;       --様式番号
-- 2024/06/04 ZCZL.wangyunhan Add end 
           rRECODE1.BREAK_NO             :=    NULL                                      ;
           rRECODE1.WSNUM                :=    g_sWSNUM                                  ;
           rRECODE1.BATCHKBN             :=    c_BATCH                                   ;
           rRECODE1.JOBNUM               :=    g_nJOBNUM                                 ;
           INSERT INTO GKBWL050R001 VALUES rRECODE1;
            
--  2024/10/17 ZCZL.WANGMING ADD 0.3.000.004:仕様変更：IT_GKB_00206対応
           --グローバル変数.学齢簿CSV出力件数 に CSVファイル出力件数 をセットする
           g_cOUNTKUREIBO := nROWNUM;
        END LOOP;
        
        -- 終了
        RETURN FRET;
    EXCEPTION
        WHEN OTHERS THEN
            FRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE;
    --------------------------------------------------------------------------------
    --  機能概要      : 学齢名簿の作成
    --  パラメータ    : なし
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------------------------------
    FUNCTION FUNC_SET_JIDO_WK_CSVFILE_MEIBO RETURN NUMBER IS
        FRET                PLS_INTEGER;                -- 戻り値
        IRET                PLS_INTEGER;                -- 戻り値
        BRET                BOOLEAN;                    -- 戻り値
        ICNT                BINARY_INTEGER;             -- カウント
        IMIN                BINARY_INTEGER;             -- 最小値（出力件数）
        VDATA               NVARCHAR2(3000);            -- データ（１レコード分）
        IRTN                NUMBER;
        MMEIBO_REC          MTMEIBO_REC;
        II                  PLS_INTEGER;
        N_NAIYO_CD_JIDO     GKBTSHIMEIJKN.NAIYO_CD%TYPE := 0;
        VEDIT_GO_DATA       NVARCHAR2(1000) := 0;
        rRECODE2            GKBWL200R002%ROWTYPE;
        nROWNUM             NUMBER;
-- 2024/06/06 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        iSHIMEI_KANA        NVARCHAR2(150); 
        iSHIMEI_KANJI       NVARCHAR2(150);
        iSEINENGAPI         NVARCHAR2(150); 
-- 2024/06/06 ZCZL.wangyunhan Add end
    BEGIN
        FRET := c_ISUCCESS;                       -- 正常終了
        IMAX := MGAKUREIBO_WORK.LAST;             -- ワーク領域の件数の最大値
        IMIN := MGAKUREIBO_WORK.FIRST;            -- ワーク領域の件数の最小値
        nROWNUM := 0;                             -- 取得した件数分繰り返す
      LOOP
          EXIT WHEN ICNTM > IMAX;
-- 2024/06/06 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
--  2024/08/05 ZCZL.YANGXINYU DELETE 0.3.000.001:受入検証対応No187
--          IRET := GKBFKHMCTRL(MGAKUREIBO_WORK(ICNTM).KOJIN_NO,g_rJSTP.CHOHYOID,0,g_GAKUNENNPOSEIGYO,iSHIMEI_KANA,iSHIMEI_KANJI,iSEINENGAPI);
          IRTN := FUNC_REC_MEIBO(MMEIBO_REC);
          rRECODE2                        :=    NULL                            ;
          nROWNUM                         :=    nROWNUM + 1                     ;
          rRECODE2.NO                     :=    nROWNUM                         ;-- ソート順
          rRECODE2.NENDO                  :=    MMEIBO_REC.NENDO                ;-- 年度
          rRECODE2.NENDO1                 :=    MMEIBO_REC.NENDO1               ;-- 年度１
          rRECODE2.NENDO2                 :=    MMEIBO_REC.NENDO2               ;-- 年度２
          rRECODE2.NENDO3                 :=    MMEIBO_REC.NENDO3               ;-- 年度３
          rRECODE2.NENDO4                 :=    MMEIBO_REC.NENDO4               ;-- 年度４
          rRECODE2.NENDO5                 :=    MMEIBO_REC.NENDO5               ;-- 年度５
          rRECODE2.NENDO6                 :=    MMEIBO_REC.NENDO6               ;-- 年度６
          rRECODE2.NENDO7                 :=    MMEIBO_REC.NENDO7               ;-- 年度７
          rRECODE2.NENDO8                 :=    MMEIBO_REC.NENDO8               ;-- 年度８
          rRECODE2.NENDO9                 :=    MMEIBO_REC.NENDO9               ;-- 年度９
          rRECODE2.KAIPAGE_CD             :=    MMEIBO_REC.KAIPEJI_CD           ;-- 改頁コード
          rRECODE2.KAIPAGE_MEI            :=    MMEIBO_REC.KAIPEJI              ;-- 改頁名
          rRECODE2.JIDO_SHIMEI_KANA       :=    MMEIBO_REC.JIDO_SHIMEI_KANA     ;-- 児童氏名かな
          rRECODE2.JIDO_SHIMEI_KANJI      :=    MMEIBO_REC.JIDO_SHIMEI_KANJI    ;-- 児童氏名漢字
          rRECODE2.CHOHYO_RENBAN          :=    MMEIBO_REC.RENBAN               ;-- 帳票連番
          rRECODE2.JIDO_GYOSEIKU_CD       :=    MMEIBO_REC.CD1                  ;-- 児童行政区コード
          rRECODE2.JIDO_GYOSEIKU_MEI      :=    MMEIBO_REC.MEISHO1              ;-- 児童行政区名
          rRECODE2.CD2                    :=    MMEIBO_REC.CD2                  ;-- 保護者行政区コード
          rRECODE2.MEISHO2                :=    MMEIBO_REC.MEISHO2              ;-- 保護者行政区名
          rRECODE2.CD3                    :=    MMEIBO_REC.CD3                  ;-- 予備コード
          rRECODE2.MEISHO3                :=    MMEIBO_REC.MEISHO3              ;-- 予備名称
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--           rRECODE2.GKJ_JIDO_HONMYO_KANA   :=    MMEIBO_REC.JIDO_HONMYO_KANA     ;-- 外国人児童本名かな
--           rRECODE2.GKJ_JIDO_HONMYO_KANJI  :=    MMEIBO_REC.JIDO_HONMYO_KANJI    ;-- 外国人児童本名漢字
--  2024/08/05 ZCZL.YANGXINYU UPDATE START 0.3.000.001:受入検証対応No187
--          rRECODE2.GKJ_JIDO_HONMYO_KANA   :=   iSHIMEI_KANA   ;   -- 外国人児童本名かな
--          rRECODE2.GKJ_JIDO_HONMYO_KANJI  :=   iSHIMEI_KANJI    ; -- 外国人児童本名漢字
          rRECODE2.GKJ_JIDO_HONMYO_KANA   :=    MMEIBO_REC.JIDO_HONMYO_KANA     ;-- 外国人児童本名かな
          rRECODE2.GKJ_JIDO_HONMYO_KANJI  :=    MMEIBO_REC.JIDO_HONMYO_KANJI    ;-- 外国人児童本名漢字
--  2024/08/05 ZCZL.YANGXINYU UPDATE END          
-- 2024/06/04 ZCZL.wangyunhan Update end
          --  2024/11/06 ZCZL.ZHANGLEI ADD START 0.3.000.006:IT_GKB_00474対応  
          rRECODE2.JIDO_HONMYO_KANA  := MMEIBO_REC.JIDO_SHIMEI_KANA;            -- 表示児童氏名かな
          rRECODE2.JIDO_HONMYO_KANJI := MMEIBO_REC.JIDO_SHIMEI_KANJI;           -- 表示児童氏名漢字
          --  2024/11/06 ZCZL.ZHANGLEI ADD END     
          --  2024/11/06 ZCZL.ZHANGLEI DEL START 0.3.000.006:IT_GKB_00474対応   
          --児童の制御情報を取得
          --BEGIN
          --  SELECT NAIYO_CD INTO N_NAIYO_CD_JIDO FROM GKBTSHIMEIJKN
          --    WHERE KOJIN_NO = MMEIBO_REC.KOJIN_NO AND CHOHYO_ID = 'GKB200R002';
          --EXCEPTION
          --  WHEN OTHERS THEN
          --    N_NAIYO_CD_JIDO := 0;
          --END;
          -- 表示児童氏名かな
          --外国人場合
          --IF MMEIBO_REC.JIDO_JINKAKU_KBN = 1 THEN
          --  VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(2),N_NAIYO_CD_JIDO,
          --                  TRIM(MMEIBO_REC.JIDO_SHIMEI_KANA),TRIM(MMEIBO_REC.JIDO_HONMYO_KANA));
          --  rRECODE2.JIDO_HONMYO_KANA  :=    VEDIT_GO_DATA    ;-- 表示児童氏名かな
          --ELSE
          --  --外国人以外場合
          --  IF ACONSPRM_SHIMEI(2) = 1 THEN
          --    IF  MMEIBO_REC.JIDO_HONMYO_KANA <>  ' ' THEN
          --      rRECODE2.JIDO_HONMYO_KANA :=  MMEIBO_REC.JIDO_HONMYO_KANA ;
          --    ELSE
          --      rRECODE2.JIDO_HONMYO_KANA :=  MMEIBO_REC.JIDO_SHIMEI_KANA ;
          --    END IF;
          --  ELSE
          --    rRECODE2.JIDO_HONMYO_KANA := MMEIBO_REC.JIDO_SHIMEI_KANA ;
          --  END IF;
          --END IF;
          -- 表示児童氏名漢字
          --外国人場合
          --IF MMEIBO_REC.JIDO_JINKAKU_KBN = 1 THEN
          --  VEDIT_GO_DATA := FUNC_SET_SEIGYO(ACONSPRM_SHIMEI(2),N_NAIYO_CD_JIDO,
          --                  TRIM(MMEIBO_REC.JIDO_SHIMEI_KANJI),TRIM(MMEIBO_REC.JIDO_HONMYO_KANJI));
          --  rRECODE2.JIDO_HONMYO_KANJI :=  VEDIT_GO_DATA ;
          --ELSE
          --  --外国人以外の場合
          --  IF ACONSPRM_SHIMEI(2) = 1 THEN
          --    IF MMEIBO_REC.JIDO_HONMYO_KANJI <>  ' ' THEN
          --      rRECODE2.JIDO_HONMYO_KANJI := MMEIBO_REC.JIDO_HONMYO_KANJI;
          --    ELSE
          --      rRECODE2.JIDO_HONMYO_KANJI := MMEIBO_REC.JIDO_SHIMEI_KANJI;
          --    END IF;
          --  ELSE
          --    rRECODE2.JIDO_HONMYO_KANJI := MMEIBO_REC.JIDO_SHIMEI_KANJI;
          --  END IF;
          --END IF;
          --  2024/11/06 ZCZL.ZHANGLEI DEL END
          -- 表示帳票連番
          IF NRENBAN = 0 THEN
            rRECODE2.RENBAN := MMEIBO_REC.CHOHYO_NO;
          ELSE
            rRECODE2.RENBAN := MMEIBO_REC.RENBAN;
          END IF;
          -- 基準日
          rRECODE2.KIJUNBI := MMEIBO_REC.KIJUN_BI;
          rRECODE2.JINKAKU_KBN := MMEIBO_REC.JINKAKU_KBN;
          rRECODE2.BREAK_NO := NULL;
          rRECODE2.WSNUM := g_sWSNUM;
          rRECODE2.BATCHKBN := c_BATCH;
          rRECODE2.JOBNUM := g_nJOBNUM;
          INSERT INTO GKBWL200R002 VALUES rRECODE2;
--  2024/10/17 ZCZL.WANGMING UPDATE 0.3.000.004:仕様変更：IT_GKB_00206対応
          --グローバル変数.学齢名簿CSV出力件数 に CSVファイル出力件数 をセットする
          g_cOUNTKUREIBOMEI := nROWNUM;
        END LOOP;
        -- 終了
        RETURN FRET;
    EXCEPTION
        WHEN OTHERS THEN
            FRET := c_INOT_SUCCESS;      -- 異常終了
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- 処理ログの出力
            B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || 'FUNC_SET_JIDO_WK_CSVFILE_MEIBO', 1, SQLCODE, SQLERRM, c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
        RETURN FRET;
    END FUNC_SET_JIDO_WK_CSVFILE_MEIBO;
    --------------------------------------------------------
    --  機能概要      : CSV出力処理
    --  パラメータ    : i_TBLNAME    テーブル名
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------
    PROCEDURE PROC_KENSUSET
    IS
      bRTN                          BOOLEAN;  --戻り値
      eEXCEPTION                    EXCEPTION;
    BEGIN
-- 2024/06/12 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        --学齢簿対象件数
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(nCOUNT, '入力 学齢簿対象件数', 1);
        --学齢簿ＣＳＶ件数
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
--  2024/10/17 ZCZL.WANGMING UPDATE START 0.3.000.004:仕様変更：IT_GKB_00206対応
--        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_rJSTP.SHORIRECCNT, '出力 学齢簿ＣＳＶ', 2);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_cOUNTKUREIBO, '出力 学齢簿ＣＳＶ', 2);
        --学齢名簿件数
        g_nINDEX := g_nINDEX + 1;
        g_oKENSU_LIST.EXTEND(1);
        g_oKENSU_LIST(g_nINDEX) := GKBEKENSU_RECORD(g_cOUNTKUREIBOMEI, '出力 学齢名簿件数', 2);
--  2024/10/17 ZCZL.WANGMING UPDATE END
-- 2024/06/12 ZCZL.wangyunhan Add end
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
    --------------------------------------------------------
    FUNCTION FUNC_B10SAKUHYO1
        RETURN BOOLEAN
    IS
        bRTN             BOOLEAN;  --戻り値
        ERR              EXCEPTION;
-- 2024/06/04 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
        o_tITEM          A_CONS_PRM;   --項目内容（ｾﾐｺﾛﾝで分割したもの）の配列
    BEGIN
        g_nSAKUHYOLOGSEQ := g_nSAKUHYOLOGSEQ + 1;
        --関数開始
        bRTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', '開始', g_sTANTOCODE, g_sWSNUM, 1);
        --複数な帳票の場合、該当ロジックあり
        --変数の初期について、該当処理内作成しますか？判断要
        --帳票IDに関連な変数にIF内で書く
        IF g_nSTEP_INDEX = 1 THEN
            --ワークテーブル削除
             DELETE FROM GKBWL050R001 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
            --ワークテーブル削除
             DELETE FROM GKBWL200R002 WHERE BATCHKBN = c_BATCH AND WSNUM = g_sWSNUM;
            COMMIT;
            --帳票出力CSVの作成
            -- 取得した条件をそれぞれの変数へセット
            VKAISIGAKUNEN  := g_vJYOUKEN1;    -- 開始学年
            VSHURYOGAKUNEN := g_vJYOUKEN2;    -- 終了学年
            VRENBAN         := g_vJYOUKEN3;    -- 帳票連番使用有無
            NRENBAN         := TO_NUMBER(VRENBAN);
            VHAKOBI         := g_vJYOUKEN4;        -- 発行日
            NHAKOBI         := TO_NUMBER(VHAKOBI);  -- 発行日
--  2024/11/14 ZCZL.WANGYUNING UPDATE START 0.3.000.009:学校コードリスト仕様変更IT_GKB_00090の対応            
            --IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN5,VSYOGAKOCD);  --小学校コード
            --IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN6,VTYUGAKOCD);  --中学校コード
            --IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN7,VKUIKIGAICD);  --区域外学校コード
            --IRTN := GKBPK00010.FGKOCDTR(g_vJYOUKEN8,VYOGOGAKOCD);  --盲聾養護学校コード
--  2025/12/19 CTC.XW UPDATE START 1.0.404.000:GKB_QA23714対応
            --bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN5,VSYOGAKOCD);  --小学校コード
            --bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN6,VTYUGAKOCD);  --中学校コード
            --bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN7,VKUIKIGAICD);  --区域外学校コード
            --bRTN := FUNC_GET_GAKOCD(g_vJYOUKEN8,VYOGOGAKOCD);  --盲聾養護学校コード
            IF g_vJYOUKEN5 IS NOT NULL THEN  --小学校コード
             VSYOGAKOCD := g_vJYOUKEN5;
            END IF;
            IF g_vJYOUKEN6 IS NOT NULL THEN  --中学校コード
             VTYUGAKOCD := g_vJYOUKEN6;
            END IF;
            IF g_vJYOUKEN7 IS NOT NULL THEN  --区域外学校コード
             VKUIKIGAICD := g_vJYOUKEN7;
            END IF;
            IF g_vJYOUKEN8 IS NOT NULL THEN  --盲聾養護学校コード
             VYOGOGAKOCD := g_vJYOUKEN8;
            END IF;
--  2025/12/19 CTC.XW UPDATE END
--  2024/11/14 ZCZL.WANGYUNING UPDATE END 
-- 2024/06/04 ZCZL.wangyunhan Update start 0.3.000.000:新WizLIFE２次開発
--             VNINIBIT        := g_vJYOUKEN9;    -- 学級コード（任意ビット１）
            VSOTSUGYOYMD     := KKAPK0010.FSTRCNV(KKAPK0020.FNENDOHENKAN(g_vJYOUKEN9),1);      -- 卒業年月日
            VIDOBISTARTYMD   := KKAPK0010.FSTRCNV(KKAPK0020.FNENDOHENKAN(g_vJYOUKEN10),1);     -- 開始異動日　
            VIDOBIENDYMD     := KKAPK0010.FSTRCNV(KKAPK0020.FNENDOHENKAN(g_vJYOUKEN11),1);     -- 終了異動日　
            VSYORIBISTARTYMD := KKAPK0010.FSTRCNV(KKAPK0020.FNENDOHENKAN(g_vJYOUKEN12),1);     -- 開始処理日　
            VSYORIBIENDYMD   := KKAPK0010.FSTRCNV(KKAPK0020.FNENDOHENKAN(g_vJYOUKEN13),1);     -- 終了処理日　
-- 2024/06/04 ZCZL.wangyunhan Update end
            -- 教育委員会情報
            IRTN_RENBAN := KKAPK0030.FPRMSHUTOKU('GKB','00RENBAN',0,ACONSPRM_RENBAN,NLENGTH);
            IF IRTN_RENBAN =1 THEN
              ACONSPRM_RENBAN := A_CONS_PRM();
              ACONSPRM_RENBAN.EXTEND;
              ACONSPRM_RENBAN.EXTEND;
              ACONSPRM_RENBAN(1) := 0;
            ELSE
              WHILE (NLENGTH < 1) LOOP
                ACONSPRM_RENBAN.EXTEND;
                ACONSPRM_RENBAN(NLENGTH+1) := 0;
                NLENGTH := NLENGTH + 1;
              END LOOP;
            END IF;

            -- 市町村名の設定
            ISAKUSEIBI :=  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
              IRTN := KKAPK0030.FKYOTU( ISAKUSEIBI,
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
--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
          END IF;
            -- 学齢簿ワークのデータ全件削除
             I_RTN := KKAPK3000.FTRUNCATE(c_VGTABLE, VSQLERRM);
            IF I_RTN = c_INOT_SUCCESS THEN
              -- エラーで帰ってきた場合
              B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 1, '', '', c_VERR_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
              GOTO ERROR_EXIT;
            END IF;
--  2024/08/05 ZCZL.YANGXINYU ADD START 0.3.000.001:受入検証対応No187
          -- システム制御設定を取得する
          -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する
          o_tITEM :=  A_CONS_PRM();
          I_RTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, o_tITEM);
          IF I_RTN = 0 THEN
            FOR i IN 1..o_tITEM.COUNT LOOP
              IF o_tITEM(i) = 'GKB050R001' THEN
                g_GAKUNENNPO_INDEXNO := i;
                EXIT;
              END IF;
            END LOOP;
            FOR i IN 1..o_tITEM.COUNT LOOP
              IF o_tITEM(i) = 'GKB200R002' THEN
                g_GAKUNEIMEI_INDEXNO := i;
                EXIT;
              END IF;
            END LOOP;
          END IF;
          -- 「本名・通称名　出力制御」のリストを取得する
          o_tITEM := A_CONS_PRM();
          o_tITEM.EXTEND;
          I_RTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, o_tITEM);
          CASE g_rJSTP.CHOHYOID
            WHEN 'GKB050R001' THEN
              g_GAKUNENNPOSEIGYO := o_tITEM(g_GAKUNENNPO_INDEXNO);
            WHEN 'GKB200R002' THEN
              g_GAKUNEIMEISEIGYO := o_tITEM(g_GAKUNEIMEI_INDEXNO);
          END CASE;
--  2024/08/05 ZCZL.YANGXINYU ADD END         
            -- 学齢簿中間データ作成
            I_RTN := FUNC_GET_JIDO_WK;
            IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
              IF I_RTN = c_INOTFOUND THEN
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
--  2024/04/22 ZCZL.WUCAO ADD 0.2.000.001:512_GKB_00027対応
                GOTO END_EXIT;
              END IF;
              GOTO ERROR_EXIT;
            END IF;
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
            --援措置対象者情報取得
            I_RTN := FUNC_GACTKANRI_WK;
            -- エラーで帰ってきた場合
            IF I_RTN <> c_ISUCCESS THEN
              IF I_RTN = c_INOTFOUND THEN
                B_RTN := FUNC_SETLOG (g_rJSTP.CHOHYONAME || '作表処理', 0, '', '', c_VOK_MSG01, g_sTANTOCODE, g_sWSNUM, 1);
                GOTO END_EXIT;
              END IF;
              GOTO ERROR_EXIT;
            END IF;
-- 2024/06/04 ZCZL.wangyunhan Add end 
            -- ワークテーブル作成
            I_RTN := FUNC_INSERT_JIDO_WK;
            IF I_RTN = c_INOT_SUCCESS THEN
              -- エラーで帰ってきた場合
              GOTO ERROR_EXIT;
            END IF;
--  2024/04/22 ZCZL.WUCAO DELETE 0.2.000.001:512_GKB_00027対応
--        END IF;
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
        nCOUNT := GKBFKTBLCNT('GKBWGAKUREIBO',NULL);
--  2024/08/05 ZCZL.YANGXINYU DELETE START 0.3.000.001:受入検証対応No187        
--        -- システム制御設定を取得する
--        -- 「外国人　氏名・生年月日制御帳票(ID)」のリストを取得する
--        o_tITEM :=  A_CONS_PRM();
--        I_RTN := KKAPK0030.FCTGetR('GKB', 'SHIMEIJKN_CHOHYO', '0000', 1, o_tITEM);
--        IF I_RTN = 0 THEN
--          FOR i IN 1..o_tITEM.COUNT LOOP
--            IF o_tITEM(i) = 'GKB050R001' THEN
--              g_GAKUNENNPO_INDEXNO := i;
--               EXIT;
--            END IF;
--          END LOOP;
--          FOR i IN 1..o_tITEM.COUNT LOOP
--            IF o_tITEM(i) = 'GKB200R002' THEN
--              g_GAKUNEIMEI_INDEXNO := i;
--               EXIT;
--            END IF;
--          END LOOP;
--        END IF;
--       -- 「本名・通称名　出力制御」のリストを取得する
--        o_tITEM := A_CONS_PRM();
--        o_tITEM.EXTEND;
--        I_RTN := KKAPK0030.FCTGetR('GKB', 'EQSHIMEI', '0000', 0, o_tITEM);
--        CASE g_rJSTP.CHOHYOID
--           WHEN 'GKB050R001' THEN
--             g_GAKUNENNPOSEIGYO := o_tITEM(g_GAKUNENNPO_INDEXNO);
--           WHEN 'GKB200R002' THEN
--             g_GAKUNEIMEISEIGYO := o_tITEM(g_GAKUNEIMEI_INDEXNO);
--        END CASE;
--  2024/08/05 ZCZL.YANGXINYU DELETE START        
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
          WHERE CHOHYO_KBN = 8;
        EXCEPTION
          WHEN OTHERS THEN
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETTOGO := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO := NULL;
            rGKBTTSUCHISHOKANRITY.YOSHIKI_BANGO_SETSUBIGO := NULL;
        END; 
-- 2024/06/04 ZCZL.wangyunhan Add end 
        -- 学齢簿中間データ作成（ＣＳＶ用）
        I_RTN := FUNC_GET_JIDO_WK_CSV;
        IF I_RTN <> c_ISUCCESS THEN
          -- エラーで帰ってきた場合
          GOTO ERROR_EXIT;
        END IF;
        CASE g_rJSTP.CHOHYOID
          WHEN 'GKB050R001' THEN
-- 2024/06/11 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
            bRTN := FUNC_GKBWGAKUREIBO_DATA;
            -- 学齢簿中間ＣＳＶファイル作成
            I_RTN := FUNC_SET_JIDO_WK_CSVFILE;
            IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
              GOTO ERROR_EXIT;
            END IF;
          WHEN 'GKB200R002' THEN
-- 2024/06/11 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
            bRTN := FUNC_GKBWGAKUREIBO_DATA;
            -- 学齢名簿中間ＣＳＶファイル作成
            I_RTN := FUNC_SET_JIDO_WK_CSVFILE_MEIBO;
            IF I_RTN <> c_ISUCCESS THEN
              -- エラーで帰ってきた場合
              GOTO ERROR_EXIT;
            END IF;
        END CASE;
        --異常の場合、この標示に移動する
        <<ERROR_EXIT>>
         --帳票出力CSVの作成
        CASE g_rJSTP.CHOHYOID
           WHEN 'GKB050R001' THEN
             --CSV出力処理
             bRTN := FUNC_B11CSV ('GKBWL050R001');
           WHEN 'GKB200R002' THEN
             --CSV出力処理
             bRTN := FUNC_B11CSV ('GKBWL200R002');
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
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
    --  作成者／作成日: ZCZL.ZHANGXIANGYU 2024/01/02
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
END  GKBPB00160;
/
