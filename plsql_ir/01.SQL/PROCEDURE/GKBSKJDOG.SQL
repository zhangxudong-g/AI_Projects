CREATE OR REPLACE PROCEDURE        GKBSKJDOG
--1.0.000.000-02.02-02.02
(
    i_NKOJIN_NO        IN NUMBER,
    o_RG     OUT GKBTGAKUREIBO%ROWTYPE,
    o_NERR          OUT NUMBER
) IS
------------------------------------------------------------------------------
--  業務名      GKB（教育）
--  PG名        GKBSKJDOG
--  名称        児童情報取得サブ
--  処理概要    個人番号をキーとして児童情報を返す。
--  引き数      i_NKOJIN_NO     児童個人番号
--              o_RG            学齢簿のレコード
--              o_NERR          変換結果
--  作成者      ZCZL.LIKEWEN
--  作成日      2024/01/06
--  Version     0.3.000.000
--------------------------------------------------------
--  変更履歴
--  2024/06/04 ZCZL.wangyunhan Add 0.3.000.000:新WizLIFE２次開発
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--  定数宣言
------------------------------------------------------------------------------
    c_BERROR       CONSTANT  BOOLEAN :=  FALSE;
    c_BNORMALEND   CONSTANT  BOOLEAN :=  TRUE;
    -- 処理結果
    c_ISUCCESS     CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOT_SUCCESS CONSTANT  PLS_INTEGER := -1;        -- 異常
    -- 戻り値
    c_IOK          CONSTANT  PLS_INTEGER := 0;         -- 正常
    c_INOTFOUND    CONSTANT  PLS_INTEGER := 1;         -- 該当なし
    c_IERR         CONSTANT  PLS_INTEGER := 2;         -- その他エラー
------------------------------------------------------------------------------
--  変数宣言
------------------------------------------------------------------------------
    -- ERROR関連 --
    N_SQL_CODE      NUMBER;             -- SQLエラーコード
    V_SQL_MSG       NVARCHAR2(255);     -- SQLエラーメッセージ
    I_RTN           PLS_INTEGER;
    IMRIREKI_RENBAN PLS_INTEGER;
------------------------------------------------------------------------------
--  カーソル定義
------------------------------------------------------------------------------
    -- 児童情報取得ＳＱＬ（個人番号）
    CURSOR CJIDO1(p_NKOJIN_NO IN NUMBER) IS
        SELECT 
               KOJIN_NO,
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
               RIREKI_RENBAN_EDA,
               GENZON_KBN,
               ZO_JIYU_CD,
               ZO_NENGAPI,
               TOKUSOKU_JIYU1,
               TOKUSOKU_JURI_BI1,
               TOKUSOKU_JIYU2,
               TOKUSOKU_JURI_BI2,
               TOKUSOKU_JIYU3,
               TOKUSOKU_JURI_BI3,
               TOKUSOKU_JIYU4,
               TOKUSOKU_JURI_BI4,
               TOKUSOKU_JIYU5,
               TOKUSOKU_JURI_BI5,
               TOKUSOKU_BI6 ,
               TOKUSOKU_NAIYO6, 
               TOKUSOKU_JIYU6,
               TOKUSOKU_JURI_BI6,
               TOKUSOKU_BI7,
               TOKUSOKU_NAIYO7, 
               TOKUSOKU_JIYU7,
               TOKUSOKU_JURI_BI7,
               TOKUSOKU_BI8,
               TOKUSOKU_NAIYO8, 
               TOKUSOKU_JIYU8,
               TOKUSOKU_JURI_BI8,
               TOKUSOKU_BI9,
               TOKUSOKU_NAIYO9, 
               TOKUSOKU_JIYU9,
               TOKUSOKU_JURI_BI9,
               TOKUSOKU_BI10,
               TOKUSOKU_NAIYO10, 
               TOKUSOKU_JIYU10,
               TOKUSOKU_JURI_BI10,
               YUYO_JIYU_CD,
               YUYO_NENSU,
               MENJO_JIYU_CD,
               MENJO_KAISI_BI,
               MENJO_SYURYO_BI,
               MENJO_NENSU,
               GAKKO_KBN_CD,
               GAKUKYU_CD,
               SEIBETSU,
               JOTAI,
               TENNYUMAE_GAKKO_KBN,
               TENNYUMAE_GAKKO_CD,
               TENNYUMAE_GAKUNEN,
               GENKYURYUCHI_FLG,
               GENKYURYUCHI_KETTEI_BI,
               GENKYURYUCHI_KAISI_BI,
               GENKYURYUCHI_SYURYOBI,
               GENKYURYUCHI_RIYU,
               SHITEI_SYOGAKO_CD,
               SHITEI_TYUGAKO_CD,
               HENKO_GAKUNEN_SYOGAKO,
               HENKO_GAKUNEN_TYUGAKO,
               HENKO_SHINSEI_BI,
               HENKO_KYOKA_BI,
               HENKO_KBN,
               HENKO_KAISI_BI,
               HENKO_SYURYO_BI,
               HENKO_KYOKA_RIYU,
               HENKO_JIYU,
               HENKO_HUKYOKA_RIYU, 
               KIBO_GAKKO_KBN_CD,
               KIBO_SYOGAKKO_CD,
               KIBO_TYUGAKKO_CD,
               KIBO_UKETSUKE_BI_SYOGAKO,
               KIBO_UKETSUKE_BI_TYUGAKO,
               KUIKIGAISHUGAKU_FLG,
               KUIKIGAISHUGAKU_SHINSEI_BI,
               KUIKIGAISHUGAKU_KYOKA_BI,
               KUIKIGAISHUGAKU_KAISI_BI,
               KUIKIGAISHUGAKU_SYURYO_BI,
               KUIKIGAISHUGAKU_JIYU,
               KUIKIGAISHUGAKU_KYOKA_RIYU,
               KUIKIGAISHUGAKU_HUKYOKA_RIYU, 
               HUSHUGAKU_KAISI_BI,
               HUSHUGAKU_SYURYO_BI,
               HUSHUGAKU_RIYU,
               KUNISHIRITSU_CD,
               KUNISHIRITSU_NYUGAKU_BI,
               KUNISHIRITSU_TENNYUGAKU_BI,
               KUNISHIRITSU_TENNYUGAKU_GAKUNEN,
               KUNISHIRITSU_TENGAKU_BI,
               KUNISHIRITSU_TENGAKU_GAKUNEN,
               KUNISHIRITSU_TAIGAKU_BI,
               KUNISHIRITSU_TAIGAKU_GAKUNEN,
               KUNISHIRITSU_SOTSUGYO_BI,
               KUNISHIRITSU_KAISI_BI,
               KUNISHIRITSU_SYURYO_BI,
               TSUSHOMEI_KANA, 
               TSUSHOMEI_KANJI, 
               HOGOSYA_TSUSHOMEI_KANA, 
               HOGOSYA_TSUSHOMEI_KANJI, 
               GRB_HENKO_TODOKEDE_BI,
               GRB_HENKO_BI,
               GRB_HENKO_JIYU,
               BIKO, 
               IDO_BI,
               TODOKEDE_BI,
               SHINSEI_KANRI_RENBAN,
               IDOJI_ATENA_RIREKI_RENBAN,
               HOGOSYA_IDOJI_RIREKI_RENBAN,
               SHOGAKKOKU_CD, 
               CHUGAKKOKU_CD, 
               SAKUJO_FLG,
-- 2024/06/04 ZCZL.wangyunhan Add end
               SAISHIN_KBN,
               GEN_JIYU_CD,
               ZOKUGARA1,
               ZOKUGARA2,
               ZOKUGARA3,
               ZOKUGARA4,
               HOGOSYA_KOJIN_NO,
               HOGOSYA_ZOKUGARA1,
               HOGOSYA_ZOKUGARA2,
               HOGOSYA_ZOKUGARA3,
               HOGOSYA_ZOKUGARA4,
               SYOGAKO_CD,
               TYUGAKO_CD,
               GEN_NENGAPI,
               SYOGAKO_NYUGAKU_BI,
               SYOGAKO_TENNYUGAKU_BI,
               SYOGAKO_TENGAKU_BI,
               SYOGAKO_SOTSUGYO_BI,
               TYUGAKO_NYUGAKU_BI,
               TYUGAKO_TENNYUGAKU_BI,
               TYUGAKO_TENGAKU_BI,
               TYUGAKO_SOTSUGYO_BI,
               KUIKIGAI_CD,
               KUIKIGAI_SETISYA,
               KUIKIGAI_NYUGAKU_BI,
               KUIKIGAI_TENNYUGAKU_BI,
               KUIKIGAI_TENGAKU_BI,
               KUIKIGAI_TAIGAKU_BI,
               KUIKIGAI_SOTSUGYO_BI,
               YOGOGAKO_CD,
               YOGOGAKO_SETISYA,
               YOGOGAKO_NYUGAKU_BI,
               YOGOGAKO_TENNYUGAKU_BI,
               YOGOGAKO_TENGAKU_BI,
               YOGOGAKO_TAIGAKU_BI,
               YOGOGAKO_SOTSUGYO_BI,
               YUYO_KYOKA_BI,
               YUYO_JIYU,
               YUYO_KAISI_BI,
               YUYO_SYURYO_BI,
               YUYO_FUKUGAKU_BI ,
               MENJO_KYOKA_BI ,
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
               IDO_JIYU6 ,
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
               GAKUNEN,                        --'学年'                  
               SHORIBI,                        --'処理日'                
               SHUGAKU,                        --'就学状況'              
               IDOJIKO,                        --'異動事項'              
               CHOHYO_NO,                      --'帳票連番'              
               SYOGAKO_TENNYUGAKU_GAKUNEN,     --'小学校転入学 学年'     
               SYOGAKO_TENGAKU_GAKUNEN,        --'小学校転学 学年'       
               TYUGAKO_TENNYUGAKU_GAKUNEN,     --'中学校転入学 学年'     
               TYUGAKO_TENGAKU_GAKUNEN,        --'中学校転学 学年'       
               KUIKIGAI_TENNYUGAKU_GAKUNEN,    --'区域外転入学 学年'     
               KUIKIGAI_TENGAKU_GAKUNEN,       --'区域外転学 学年'       
               KUIKIGAI_TAIGAKU_GAKUNEN,       --'区域外退学 学年'       
               YOGOGAKO_TENNYUGAKU_GAKUNEN,    --'盲聾養護学校転入学 学年
               YOGOGAKO_TENGAKU_GAKUNEN,       --'盲聾養護学校転学 学年' 
               YOGOGAKO_TAIGAKU_GAKUNEN,       --'盲聾養護学校退学 学年' 
               RIREKI_RENBAN
          FROM
               GKBTGAKUREIBO
         WHERE KOJIN_NO = p_NKOJIN_NO
           AND RIREKI_RENBAN = IMRIREKI_RENBAN;
--------------------------------------------------------------------------------
-- レコード初期化
--------------------------------------------------------------------------------
PROCEDURE PROC_REC_SHOKIKA(i_REC OUT GKBTGAKUREIBO%ROWTYPE) IS
BEGIN
               i_REC.KOJIN_NO := 0;
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
               i_REC.RIREKI_RENBAN_EDA := 0;
               i_REC.GENZON_KBN := 0;
               i_REC.ZO_JIYU_CD := 0;
               i_REC.ZO_NENGAPI := 0;
               i_REC.TOKUSOKU_JIYU1 := 0;
               i_REC.TOKUSOKU_JURI_BI1 := 0;
               i_REC.TOKUSOKU_JIYU2 := 0;
               i_REC.TOKUSOKU_JURI_BI2 := 0;
               i_REC.TOKUSOKU_JIYU3 := 0;
               i_REC.TOKUSOKU_JURI_BI3 := 0;
               i_REC.TOKUSOKU_JIYU4 := 0;
               i_REC.TOKUSOKU_JURI_BI4 := 0;
               i_REC.TOKUSOKU_JIYU5 := 0;
               i_REC.TOKUSOKU_JURI_BI5 := 0;
               i_REC.TOKUSOKU_BI6  := 0;
               i_REC.TOKUSOKU_NAIYO6 := ' '; 
               i_REC.TOKUSOKU_JIYU6 := 0;
               i_REC.TOKUSOKU_JURI_BI6 := 0;
               i_REC.TOKUSOKU_BI7 := 0;
               i_REC.TOKUSOKU_NAIYO7 := ' '; 
               i_REC.TOKUSOKU_JIYU7 := 0;
               i_REC.TOKUSOKU_JURI_BI7 := 0;
               i_REC.TOKUSOKU_BI8 := 0;
               i_REC.TOKUSOKU_NAIYO8 := ' '; 
               i_REC.TOKUSOKU_JIYU8 := 0;
               i_REC.TOKUSOKU_JURI_BI8 := 0;
               i_REC.TOKUSOKU_BI9 := 0;
               i_REC.TOKUSOKU_NAIYO9 := ' '; 
               i_REC.TOKUSOKU_JIYU9 := 0;
               i_REC.TOKUSOKU_JURI_BI9 := 0;
               i_REC.TOKUSOKU_BI10 := 0;
               i_REC.TOKUSOKU_NAIYO10 := ' '; 
               i_REC.TOKUSOKU_JIYU10 := 0;
               i_REC.TOKUSOKU_JURI_BI10 := 0;
               i_REC.YUYO_JIYU_CD := 0;
               i_REC.YUYO_NENSU := 0;
               i_REC.MENJO_JIYU_CD := 0;
               i_REC.MENJO_KAISI_BI := 0;
               i_REC.MENJO_SYURYO_BI := 0;
               i_REC.MENJO_NENSU := 0;
               i_REC.GAKKO_KBN_CD := 0;
               i_REC.GAKUKYU_CD := 0;
               i_REC.SEIBETSU := 0;
               i_REC.JOTAI := 0;
               i_REC.TENNYUMAE_GAKKO_KBN := 0;
               i_REC.TENNYUMAE_GAKKO_CD := 0;
               i_REC.TENNYUMAE_GAKUNEN := 0;
               i_REC.GENKYURYUCHI_FLG := 0;
               i_REC.GENKYURYUCHI_KETTEI_BI := 0;
               i_REC.GENKYURYUCHI_KAISI_BI := 0;
               i_REC.GENKYURYUCHI_SYURYOBI := 0;
               i_REC.GENKYURYUCHI_RIYU := 0;
               i_REC.SHITEI_SYOGAKO_CD := 0;
               i_REC.SHITEI_TYUGAKO_CD := 0;
               i_REC.HENKO_GAKUNEN_SYOGAKO := 0;
               i_REC.HENKO_GAKUNEN_TYUGAKO := 0;
               i_REC.HENKO_SHINSEI_BI := 0;
               i_REC.HENKO_KYOKA_BI := 0;
               i_REC.HENKO_KBN := 0;
               i_REC.HENKO_KAISI_BI := 0;
               i_REC.HENKO_SYURYO_BI := 0;
               i_REC.HENKO_KYOKA_RIYU := 0;
               i_REC.HENKO_JIYU := 0;
               i_REC.HENKO_HUKYOKA_RIYU := ' '; 
               i_REC.KIBO_GAKKO_KBN_CD := 0;
               i_REC.KIBO_SYOGAKKO_CD := 0;
               i_REC.KIBO_TYUGAKKO_CD := 0;
               i_REC.KIBO_UKETSUKE_BI_SYOGAKO := 0;
               i_REC.KIBO_UKETSUKE_BI_TYUGAKO := 0;
               i_REC.KUIKIGAISHUGAKU_FLG := 0;
               i_REC.KUIKIGAISHUGAKU_SHINSEI_BI := 0;
               i_REC.KUIKIGAISHUGAKU_KYOKA_BI := 0;
               i_REC.KUIKIGAISHUGAKU_KAISI_BI := 0;
               i_REC.KUIKIGAISHUGAKU_SYURYO_BI := 0;
               i_REC.KUIKIGAISHUGAKU_JIYU := 0;
               i_REC.KUIKIGAISHUGAKU_KYOKA_RIYU := 0;
               i_REC.KUIKIGAISHUGAKU_HUKYOKA_RIYU := ' '; 
               i_REC.HUSHUGAKU_KAISI_BI := 0;
               i_REC.HUSHUGAKU_SYURYO_BI := 0;
               i_REC.HUSHUGAKU_RIYU := 0;
               i_REC.KUNISHIRITSU_CD := 0;
               i_REC.KUNISHIRITSU_NYUGAKU_BI := 0;
               i_REC.KUNISHIRITSU_TENNYUGAKU_BI := 0;
               i_REC.KUNISHIRITSU_TENNYUGAKU_GAKUNEN := 0;
               i_REC.KUNISHIRITSU_TENGAKU_BI := 0;
               i_REC.KUNISHIRITSU_TENGAKU_GAKUNEN := 0;
               i_REC.KUNISHIRITSU_TAIGAKU_BI := 0;
               i_REC.KUNISHIRITSU_TAIGAKU_GAKUNEN := 0;
               i_REC.KUNISHIRITSU_SOTSUGYO_BI := 0;
               i_REC.KUNISHIRITSU_KAISI_BI := 0;
               i_REC.KUNISHIRITSU_SYURYO_BI := 0;
               i_REC.TSUSHOMEI_KANA := ' '; 
               i_REC.TSUSHOMEI_KANJI := ' '; 
               i_REC.HOGOSYA_TSUSHOMEI_KANA := ' '; 
               i_REC.HOGOSYA_TSUSHOMEI_KANJI := ' '; 
               i_REC.GRB_HENKO_TODOKEDE_BI := 0;
               i_REC.GRB_HENKO_BI := 0;
               i_REC.GRB_HENKO_JIYU := 0;
               i_REC.BIKO := ' '; 
               i_REC.IDO_BI := 0;
               i_REC.TODOKEDE_BI := 0;
               i_REC.SHINSEI_KANRI_RENBAN := 0;
               i_REC.IDOJI_ATENA_RIREKI_RENBAN := 0;
               i_REC.HOGOSYA_IDOJI_RIREKI_RENBAN := 0;
               i_REC.SHOGAKKOKU_CD := ' '; 
               i_REC.CHUGAKKOKU_CD := ' '; 
               i_REC.SAKUJO_FLG := 0;
-- 2024/06/04 ZCZL.wangyunhan Add end
               i_REC.ZOKUGARA1 := 0;
               i_REC.ZOKUGARA2 := 0;
               i_REC.ZOKUGARA3 := 0;
               i_REC.ZOKUGARA4 := 0;
               i_REC.HOGOSYA_KOJIN_NO := 0;
               i_REC.HOGOSYA_ZOKUGARA1 := 0;
               i_REC.HOGOSYA_ZOKUGARA2 := 0;
               i_REC.HOGOSYA_ZOKUGARA3 := 0;
               i_REC.HOGOSYA_ZOKUGARA4 := 0;
               i_REC.SYOGAKO_CD := 0;
               i_REC.TYUGAKO_CD := 0;
               i_REC.GEN_JIYU_CD := 0;                              
               i_REC.SAISHIN_KBN := 0;
               i_REC.GEN_NENGAPI := 0;
               i_REC.SYOGAKO_TENGAKU_BI := 0;                              
               i_REC.SYOGAKO_SOTSUGYO_BI := 0;
               i_REC.TYUGAKO_TENGAKU_BI := 0;                              
               i_REC.TYUGAKO_SOTSUGYO_BI := 0;
               i_REC.RIREKI_RENBAN := 0;
               i_REC.SYOGAKO_NYUGAKU_BI := 0;
               i_REC.SYOGAKO_TENNYUGAKU_BI := 0;
               i_REC.SYOGAKO_TENGAKU_BI := 0;
               i_REC.TYUGAKO_NYUGAKU_BI := 0;
               i_REC.TYUGAKO_TENNYUGAKU_BI := 0;
               i_REC.TYUGAKO_TENGAKU_BI := 0;
               i_REC.KUIKIGAI_CD := 0;
               i_REC.KUIKIGAI_SETISYA := ' ';      
               i_REC.KUIKIGAI_NYUGAKU_BI := 0;
               i_REC.KUIKIGAI_TENNYUGAKU_BI := 0; 
               i_REC.KUIKIGAI_TENGAKU_BI := 0;
               i_REC.KUIKIGAI_TAIGAKU_BI := 0;
               i_REC.KUIKIGAI_SOTSUGYO_BI := 0;  
               i_REC.YOGOGAKO_CD := 0;                    
               i_REC.YOGOGAKO_SETISYA := ' ';                            
               i_REC.YOGOGAKO_NYUGAKU_BI := 0;
               i_REC.YOGOGAKO_TENNYUGAKU_BI := 0;
               i_REC.YOGOGAKO_TENGAKU_BI := 0;    
               i_REC.YOGOGAKO_TAIGAKU_BI := 0; 
               i_REC.YOGOGAKO_SOTSUGYO_BI := 0;                                
               i_REC.YUYO_KYOKA_BI := 0;          
               i_REC.YUYO_JIYU := ' ';                                          
               i_REC.YUYO_KAISI_BI := 0;          
               i_REC.YUYO_SYURYO_BI := 0;         
               i_REC.YUYO_FUKUGAKU_BI := 0;       
               i_REC.MENJO_KYOKA_BI := 0;         
               i_REC.MENJO_JIYU := ' ';            
               i_REC.MENJO_FUKUGAKU_BI := 0;      
               i_REC.IDO_BI1 := 0;                
               i_REC.IDO_JIYU1 := ' ';             
               i_REC.IDO_BI2 := 0;                
               i_REC.IDO_JIYU2 := ' ';             
               i_REC.IDO_BI3 := 0;                
               i_REC.IDO_JIYU3 := ' ';             
               i_REC.IDO_BI4 := 0;                
               i_REC.IDO_JIYU4 := ' ';             
               i_REC.IDO_BI5 := 0;                
               i_REC.IDO_JIYU5 := ' ';             
               i_REC.IDO_BI6 := 0;                
               i_REC.IDO_JIYU6 := ' ';             
               i_REC.IDO_BI7 := 0;                
               i_REC.IDO_JIYU7 := ' ';             
               i_REC.IDO_BI8 := 0;                
               i_REC.IDO_JIYU8 := ' ';             
               i_REC.IDO_BI9 := 0;                
               i_REC.IDO_JIYU9 := ' ';             
               i_REC.IDO_BI10 := 0;               
               i_REC.IDO_JIYU10 := ' ';            
               i_REC.TOKUSOKU_BI1 := 0;           
               i_REC.TOKUSOKU_NAIYO1 := ' ';       
               i_REC.TOKUSOKU_BI2 := 0;           
               i_REC.TOKUSOKU_NAIYO2 := ' ';       
               i_REC.TOKUSOKU_BI3 := 0;           
               i_REC.TOKUSOKU_NAIYO3 := ' ';       
               i_REC.TOKUSOKU_BI4 := 0;           
               i_REC.TOKUSOKU_NAIYO4 := ' ';       
               i_REC.TOKUSOKU_BI5 := 0;           
               i_REC.TOKUSOKU_NAIYO5 := ' ';    
               i_REC.GAKUNEN := 0;                      --'学年'
               i_REC.SHORIBI := 0;                      --'処理日'
               i_REC.SHUGAKU := ' ';                    --'就学状況'
               i_REC.IDOJIKO := ' ';                    --'異動事項'
               i_REC.CHOHYO_NO := 0;                    --'帳票連番'
               i_REC.SYOGAKO_TENNYUGAKU_GAKUNEN := 0;   --'小学校転入学 学年'
               i_REC.SYOGAKO_TENGAKU_GAKUNEN := 0;      --'小学校転学 学年'
               i_REC.TYUGAKO_TENNYUGAKU_GAKUNEN := 0;   --'中学校転入学 学年'
               i_REC.TYUGAKO_TENGAKU_GAKUNEN := 0;      --'中学校転学 学年'
               i_REC.KUIKIGAI_TENNYUGAKU_GAKUNEN := 0;  --'区域外転入学 学年'
               i_REC.KUIKIGAI_TENGAKU_GAKUNEN := 0;     --'区域外転学 学年'
               i_REC.KUIKIGAI_TAIGAKU_GAKUNEN := 0;     --'区域外退学 学年'
               i_REC.YOGOGAKO_TENNYUGAKU_GAKUNEN := 0;  --'盲聾養護学校転入学 学年'
               i_REC.YOGOGAKO_TENGAKU_GAKUNEN := 0;     --'盲聾養護学校転学 学年'
               i_REC.YOGOGAKO_TAIGAKU_GAKUNEN := 0;     --'盲聾養護学校退学 学年'
END PROC_REC_SHOKIKA;
--------------------------------------------------------------------------------
-- レコードの作成
--------------------------------------------------------------------------------
FUNCTION FUNC_GET_JIDO_REC(i_REC OUT GKBTGAKUREIBO%ROWTYPE) RETURN NUMBER IS
    IFRET                PLS_INTEGER;                -- 戻り値
    RCJIDO               CJIDO1%ROWTYPE;             -- 取得ＳＱＬのレコードワーク
BEGIN
    IFRET := c_ISUCCESS;  -- 正常終了
    o_NERR := c_INOTFOUND;       -- 該当なし
           SELECT MAX(RIREKI_RENBAN)
             INTO IMRIREKI_RENBAN
             FROM GKBTGAKUREIBO
            WHERE KOJIN_NO = i_NKOJIN_NO;

    BEGIN

            -- カーソルのオープン
            OPEN CJIDO1(i_NKOJIN_NO);
            FETCH CJIDO1 INTO RCJIDO;
        LOOP
                IF CJIDO1%NOTFOUND THEN

                -- 取得できていない場合は脱出
                    o_NERR := c_INOTFOUND;
                    EXIT;
                END IF;
    -- レコードの初期化
    PROC_REC_SHOKIKA(o_RG);
            -- ＊＊＊ レコードへ値をセットする ＊＊＊
               i_REC.KOJIN_NO := RCJIDO.KOJIN_NO;
-- 2024/06/04 ZCZL.wangyunhan Add start 0.3.000.000:新WizLIFE２次開発
               i_REC.RIREKI_RENBAN_EDA := RCJIDO.RIREKI_RENBAN_EDA;
               i_REC.GENZON_KBN := RCJIDO.GENZON_KBN;
               i_REC.ZO_JIYU_CD := RCJIDO.ZO_JIYU_CD;
               i_REC.ZO_NENGAPI := RCJIDO.ZO_NENGAPI;
               i_REC.TOKUSOKU_JIYU1 := RCJIDO.TOKUSOKU_JIYU1;
               i_REC.TOKUSOKU_JURI_BI1 := RCJIDO.TOKUSOKU_JURI_BI1;
               i_REC.TOKUSOKU_JIYU2 := RCJIDO.TOKUSOKU_JIYU2;
               i_REC.TOKUSOKU_JURI_BI2 := RCJIDO.TOKUSOKU_JURI_BI2;
               i_REC.TOKUSOKU_JIYU3 := RCJIDO.TOKUSOKU_JIYU3;
               i_REC.TOKUSOKU_JURI_BI3 := RCJIDO.TOKUSOKU_JURI_BI3;
               i_REC.TOKUSOKU_JIYU4 := RCJIDO.TOKUSOKU_JIYU4;
               i_REC.TOKUSOKU_JURI_BI4 := RCJIDO.TOKUSOKU_JURI_BI4;
               i_REC.TOKUSOKU_JIYU5 := RCJIDO.TOKUSOKU_JIYU5;
               i_REC.TOKUSOKU_JURI_BI5 := RCJIDO.TOKUSOKU_JURI_BI5;
               i_REC.TOKUSOKU_BI6  := RCJIDO.TOKUSOKU_BI6;
               i_REC.TOKUSOKU_NAIYO6 := RCJIDO.TOKUSOKU_NAIYO6; 
               i_REC.TOKUSOKU_JIYU6 := RCJIDO.TOKUSOKU_JIYU6;
               i_REC.TOKUSOKU_JURI_BI6 := RCJIDO.TOKUSOKU_JURI_BI6;
               i_REC.TOKUSOKU_BI7 := RCJIDO.TOKUSOKU_BI7;
               i_REC.TOKUSOKU_NAIYO7 := RCJIDO.TOKUSOKU_NAIYO7; 
               i_REC.TOKUSOKU_JIYU7 := RCJIDO.TOKUSOKU_JIYU7;
               i_REC.TOKUSOKU_JURI_BI7 := RCJIDO.TOKUSOKU_JURI_BI7;
               i_REC.TOKUSOKU_BI8 := RCJIDO.TOKUSOKU_BI8;
               i_REC.TOKUSOKU_NAIYO8 := RCJIDO.TOKUSOKU_NAIYO8; 
               i_REC.TOKUSOKU_JIYU8 := RCJIDO.TOKUSOKU_JIYU8;
               i_REC.TOKUSOKU_JURI_BI8 := RCJIDO.TOKUSOKU_JURI_BI8;
               i_REC.TOKUSOKU_BI9 := RCJIDO.TOKUSOKU_BI9;
               i_REC.TOKUSOKU_NAIYO9 := RCJIDO.TOKUSOKU_NAIYO9; 
               i_REC.TOKUSOKU_JIYU9 := RCJIDO.TOKUSOKU_JIYU9;
               i_REC.TOKUSOKU_JURI_BI9 := RCJIDO.TOKUSOKU_JURI_BI9;
               i_REC.TOKUSOKU_BI10 := RCJIDO.TOKUSOKU_BI10;
               i_REC.TOKUSOKU_NAIYO10 := RCJIDO.TOKUSOKU_NAIYO10; 
               i_REC.TOKUSOKU_JIYU10 := RCJIDO.TOKUSOKU_JIYU10;
               i_REC.TOKUSOKU_JURI_BI10 := RCJIDO.TOKUSOKU_JURI_BI10;
               i_REC.YUYO_JIYU_CD := RCJIDO.YUYO_JIYU_CD;
               i_REC.YUYO_NENSU := RCJIDO.YUYO_NENSU;
               i_REC.MENJO_JIYU_CD := RCJIDO.MENJO_JIYU_CD;
               i_REC.MENJO_KAISI_BI := RCJIDO.MENJO_KAISI_BI;
               i_REC.MENJO_SYURYO_BI := RCJIDO.MENJO_SYURYO_BI;
               i_REC.MENJO_NENSU := RCJIDO.MENJO_NENSU;
               i_REC.GAKKO_KBN_CD := RCJIDO.GAKKO_KBN_CD;
               i_REC.GAKUKYU_CD := RCJIDO.GAKUKYU_CD;
               i_REC.SEIBETSU := RCJIDO.SEIBETSU;
               i_REC.JOTAI := RCJIDO.JOTAI;
               i_REC.TENNYUMAE_GAKKO_KBN := RCJIDO.TENNYUMAE_GAKKO_KBN;
               i_REC.TENNYUMAE_GAKKO_CD := RCJIDO.TENNYUMAE_GAKKO_CD;
               i_REC.TENNYUMAE_GAKUNEN := RCJIDO.TENNYUMAE_GAKUNEN;
               i_REC.GENKYURYUCHI_FLG := RCJIDO.GENKYURYUCHI_FLG;
               i_REC.GENKYURYUCHI_KETTEI_BI := RCJIDO.GENKYURYUCHI_KETTEI_BI;
               i_REC.GENKYURYUCHI_KAISI_BI := RCJIDO.GENKYURYUCHI_KAISI_BI;
               i_REC.GENKYURYUCHI_SYURYOBI := RCJIDO.GENKYURYUCHI_SYURYOBI;
               i_REC.GENKYURYUCHI_RIYU := RCJIDO.GENKYURYUCHI_RIYU;
               i_REC.SHITEI_SYOGAKO_CD := RCJIDO.SHITEI_SYOGAKO_CD;
               i_REC.SHITEI_TYUGAKO_CD := RCJIDO.SHITEI_TYUGAKO_CD;
               i_REC.HENKO_GAKUNEN_SYOGAKO := RCJIDO.HENKO_GAKUNEN_SYOGAKO;
               i_REC.HENKO_GAKUNEN_TYUGAKO := RCJIDO.HENKO_GAKUNEN_TYUGAKO;
               i_REC.HENKO_SHINSEI_BI := RCJIDO.HENKO_SHINSEI_BI;
               i_REC.HENKO_KYOKA_BI := RCJIDO.HENKO_KYOKA_BI;
               i_REC.HENKO_KBN := RCJIDO.HENKO_KBN;
               i_REC.HENKO_KAISI_BI := RCJIDO.HENKO_KAISI_BI;
               i_REC.HENKO_SYURYO_BI := RCJIDO.HENKO_SYURYO_BI;
               i_REC.HENKO_KYOKA_RIYU := RCJIDO.HENKO_KYOKA_RIYU;
               i_REC.HENKO_JIYU := RCJIDO.HENKO_JIYU;
               i_REC.HENKO_HUKYOKA_RIYU := RCJIDO.HENKO_HUKYOKA_RIYU; 
               i_REC.KIBO_GAKKO_KBN_CD := RCJIDO.KIBO_GAKKO_KBN_CD;
               i_REC.KIBO_SYOGAKKO_CD := RCJIDO.KIBO_SYOGAKKO_CD;
               i_REC.KIBO_TYUGAKKO_CD := RCJIDO.KIBO_TYUGAKKO_CD;
               i_REC.KIBO_UKETSUKE_BI_SYOGAKO := RCJIDO.KIBO_UKETSUKE_BI_SYOGAKO;
               i_REC.KIBO_UKETSUKE_BI_TYUGAKO := RCJIDO.KIBO_UKETSUKE_BI_TYUGAKO;
               i_REC.KUIKIGAISHUGAKU_FLG := RCJIDO.KUIKIGAISHUGAKU_FLG;
               i_REC.KUIKIGAISHUGAKU_SHINSEI_BI := RCJIDO.KUIKIGAISHUGAKU_SHINSEI_BI;
               i_REC.KUIKIGAISHUGAKU_KYOKA_BI := RCJIDO.KUIKIGAISHUGAKU_KYOKA_BI;
               i_REC.KUIKIGAISHUGAKU_KAISI_BI := RCJIDO.KUIKIGAISHUGAKU_KAISI_BI;
               i_REC.KUIKIGAISHUGAKU_SYURYO_BI := RCJIDO.KUIKIGAISHUGAKU_SYURYO_BI;
               i_REC.KUIKIGAISHUGAKU_JIYU := RCJIDO.KUIKIGAISHUGAKU_JIYU;
               i_REC.KUIKIGAISHUGAKU_KYOKA_RIYU := RCJIDO.KUIKIGAISHUGAKU_KYOKA_RIYU;
               i_REC.KUIKIGAISHUGAKU_HUKYOKA_RIYU := RCJIDO.KUIKIGAISHUGAKU_HUKYOKA_RIYU; 
               i_REC.HUSHUGAKU_KAISI_BI := RCJIDO.HUSHUGAKU_KAISI_BI;
               i_REC.HUSHUGAKU_SYURYO_BI := RCJIDO.HUSHUGAKU_SYURYO_BI;
               i_REC.HUSHUGAKU_RIYU := RCJIDO.HUSHUGAKU_RIYU;
               i_REC.KUNISHIRITSU_CD := RCJIDO.KUNISHIRITSU_CD;
               i_REC.KUNISHIRITSU_NYUGAKU_BI := RCJIDO.KUNISHIRITSU_NYUGAKU_BI;
               i_REC.KUNISHIRITSU_TENNYUGAKU_BI := RCJIDO.KUNISHIRITSU_TENNYUGAKU_BI;
               i_REC.KUNISHIRITSU_TENNYUGAKU_GAKUNEN := RCJIDO.KUNISHIRITSU_TENNYUGAKU_GAKUNEN;
               i_REC.KUNISHIRITSU_TENGAKU_BI := RCJIDO.KUNISHIRITSU_TENGAKU_BI;
               i_REC.KUNISHIRITSU_TENGAKU_GAKUNEN := RCJIDO.KUNISHIRITSU_TENGAKU_GAKUNEN;
               i_REC.KUNISHIRITSU_TAIGAKU_BI := RCJIDO.KUNISHIRITSU_TAIGAKU_BI;
               i_REC.KUNISHIRITSU_TAIGAKU_GAKUNEN := RCJIDO.KUNISHIRITSU_TAIGAKU_GAKUNEN;
               i_REC.KUNISHIRITSU_SOTSUGYO_BI := RCJIDO.KUNISHIRITSU_SOTSUGYO_BI;
               i_REC.KUNISHIRITSU_KAISI_BI := RCJIDO.KUNISHIRITSU_KAISI_BI;
               i_REC.KUNISHIRITSU_SYURYO_BI := RCJIDO.KUNISHIRITSU_SYURYO_BI;
               i_REC.TSUSHOMEI_KANA := RCJIDO.TSUSHOMEI_KANA; 
               i_REC.TSUSHOMEI_KANJI := RCJIDO.TSUSHOMEI_KANJI; 
               i_REC.HOGOSYA_TSUSHOMEI_KANA := RCJIDO.HOGOSYA_TSUSHOMEI_KANA; 
               i_REC.HOGOSYA_TSUSHOMEI_KANJI := RCJIDO.HOGOSYA_TSUSHOMEI_KANJI; 
               i_REC.GRB_HENKO_TODOKEDE_BI := RCJIDO.GRB_HENKO_TODOKEDE_BI;
               i_REC.GRB_HENKO_BI := RCJIDO.GRB_HENKO_BI;
               i_REC.GRB_HENKO_JIYU := RCJIDO.GRB_HENKO_JIYU;
               i_REC.BIKO := RCJIDO.BIKO; 
               i_REC.IDO_BI := RCJIDO.IDO_BI;
               i_REC.TODOKEDE_BI := RCJIDO.TODOKEDE_BI;
               i_REC.SHINSEI_KANRI_RENBAN := RCJIDO.SHINSEI_KANRI_RENBAN;
               i_REC.IDOJI_ATENA_RIREKI_RENBAN := RCJIDO.IDOJI_ATENA_RIREKI_RENBAN;
               i_REC.HOGOSYA_IDOJI_RIREKI_RENBAN := RCJIDO.HOGOSYA_IDOJI_RIREKI_RENBAN;
               i_REC.SHOGAKKOKU_CD := RCJIDO.SHOGAKKOKU_CD; 
               i_REC.CHUGAKKOKU_CD := RCJIDO.CHUGAKKOKU_CD; 
               i_REC.SAKUJO_FLG := RCJIDO.SAKUJO_FLG;
-- 2024/06/04 ZCZL.wangyunhan Add end
               i_REC.ZOKUGARA1 := RCJIDO.ZOKUGARA1;
               i_REC.ZOKUGARA2 := RCJIDO.ZOKUGARA2;
               i_REC.ZOKUGARA3 := RCJIDO.ZOKUGARA3;
               i_REC.ZOKUGARA4 := RCJIDO.ZOKUGARA4;
               i_REC.HOGOSYA_KOJIN_NO := RCJIDO.HOGOSYA_KOJIN_NO;
               i_REC.HOGOSYA_ZOKUGARA1 := RCJIDO.HOGOSYA_ZOKUGARA1;
               i_REC.HOGOSYA_ZOKUGARA2 := RCJIDO.HOGOSYA_ZOKUGARA2;
               i_REC.HOGOSYA_ZOKUGARA3 := RCJIDO.HOGOSYA_ZOKUGARA3;
               i_REC.HOGOSYA_ZOKUGARA4 := RCJIDO.HOGOSYA_ZOKUGARA4;
               i_REC.SYOGAKO_CD := RCJIDO.SYOGAKO_CD;
               i_REC.TYUGAKO_CD := RCJIDO.TYUGAKO_CD;
               i_REC.GEN_JIYU_CD := RCJIDO.GEN_JIYU_CD;
               i_REC.SAISHIN_KBN := RCJIDO.SAISHIN_KBN;
               i_REC.GEN_NENGAPI := RCJIDO.GEN_NENGAPI;
               i_REC.SYOGAKO_TENGAKU_BI := RCJIDO.SYOGAKO_TENGAKU_BI;
               i_REC.SYOGAKO_SOTSUGYO_BI := RCJIDO.SYOGAKO_SOTSUGYO_BI;
               i_REC.TYUGAKO_TENGAKU_BI := RCJIDO.TYUGAKO_TENGAKU_BI;
               i_REC.TYUGAKO_SOTSUGYO_BI := RCJIDO.TYUGAKO_SOTSUGYO_BI;
               i_REC.RIREKI_RENBAN := RCJIDO.RIREKI_RENBAN;
               i_REC.SYOGAKO_NYUGAKU_BI := RCJIDO.SYOGAKO_NYUGAKU_BI;
               i_REC.SYOGAKO_TENNYUGAKU_BI := RCJIDO.SYOGAKO_TENNYUGAKU_BI;
               i_REC.SYOGAKO_TENGAKU_BI := RCJIDO.SYOGAKO_TENGAKU_BI;
               i_REC.TYUGAKO_NYUGAKU_BI := RCJIDO.TYUGAKO_NYUGAKU_BI;
               i_REC.TYUGAKO_TENNYUGAKU_BI := RCJIDO.TYUGAKO_TENNYUGAKU_BI;
               i_REC.TYUGAKO_TENGAKU_BI := RCJIDO.TYUGAKO_TENGAKU_BI;
               i_REC.KUIKIGAI_CD := RCJIDO.KUIKIGAI_CD;
               i_REC.KUIKIGAI_SETISYA := RCJIDO.KUIKIGAI_SETISYA;
               i_REC.KUIKIGAI_NYUGAKU_BI := RCJIDO.KUIKIGAI_NYUGAKU_BI;
               i_REC.KUIKIGAI_TENNYUGAKU_BI := RCJIDO.KUIKIGAI_TENNYUGAKU_BI; 
               i_REC.KUIKIGAI_TENGAKU_BI := RCJIDO.KUIKIGAI_TENGAKU_BI;
               i_REC.KUIKIGAI_TAIGAKU_BI := RCJIDO.KUIKIGAI_TAIGAKU_BI;
               i_REC.KUIKIGAI_SOTSUGYO_BI := RCJIDO.KUIKIGAI_SOTSUGYO_BI;
               i_REC.YOGOGAKO_CD := RCJIDO.YOGOGAKO_CD;
               i_REC.YOGOGAKO_SETISYA := RCJIDO.YOGOGAKO_SETISYA;
               i_REC.YOGOGAKO_NYUGAKU_BI := RCJIDO.YOGOGAKO_NYUGAKU_BI;
               i_REC.YOGOGAKO_TENNYUGAKU_BI := RCJIDO.YOGOGAKO_TENNYUGAKU_BI;
               i_REC.YOGOGAKO_TENGAKU_BI := RCJIDO.YOGOGAKO_TENGAKU_BI;    
               i_REC.YOGOGAKO_TAIGAKU_BI := RCJIDO.YOGOGAKO_TAIGAKU_BI;
               i_REC.YOGOGAKO_SOTSUGYO_BI := RCJIDO.YOGOGAKO_SOTSUGYO_BI;
               i_REC.YUYO_KYOKA_BI := RCJIDO.YUYO_KYOKA_BI;
               i_REC.YUYO_JIYU := RCJIDO.YUYO_JIYU;
               i_REC.YUYO_KAISI_BI := RCJIDO.YUYO_KAISI_BI;
               i_REC.YUYO_SYURYO_BI := RCJIDO.YUYO_SYURYO_BI;
               i_REC.YUYO_FUKUGAKU_BI := RCJIDO.YUYO_FUKUGAKU_BI;
               i_REC.MENJO_KYOKA_BI := RCJIDO.MENJO_KYOKA_BI;
               i_REC.MENJO_JIYU := RCJIDO.MENJO_JIYU;
               i_REC.MENJO_FUKUGAKU_BI := RCJIDO.MENJO_FUKUGAKU_BI;
               i_REC.IDO_BI1 := RCJIDO.IDO_BI1;
               i_REC.IDO_JIYU1 := RCJIDO.IDO_JIYU1;
               i_REC.IDO_BI2 := RCJIDO.IDO_BI2;
               i_REC.IDO_JIYU2 := RCJIDO.IDO_JIYU2;
               i_REC.IDO_BI3 := RCJIDO.IDO_BI3;
               i_REC.IDO_JIYU3 := RCJIDO.IDO_JIYU3;
               i_REC.IDO_BI4 := RCJIDO.IDO_BI4;
               i_REC.IDO_JIYU4 := RCJIDO.IDO_JIYU4;
               i_REC.IDO_BI5 := RCJIDO.IDO_BI5;
               i_REC.IDO_JIYU5 := RCJIDO.IDO_JIYU5;
               i_REC.IDO_BI6 := RCJIDO.IDO_BI6;
               i_REC.IDO_JIYU6 := RCJIDO.IDO_JIYU6;
               i_REC.IDO_BI7 := RCJIDO.IDO_BI7;
               i_REC.IDO_JIYU7 := RCJIDO.IDO_JIYU7;
               i_REC.IDO_BI8 := RCJIDO.IDO_BI8;
               i_REC.IDO_JIYU8 := RCJIDO.IDO_JIYU8;
               i_REC.IDO_BI9 := RCJIDO.IDO_BI9;
               i_REC.IDO_JIYU9 := RCJIDO.IDO_JIYU9;
               i_REC.IDO_BI10 := RCJIDO.IDO_BI10;
               i_REC.IDO_JIYU10 := RCJIDO.IDO_JIYU10;
               i_REC.TOKUSOKU_BI1 := RCJIDO.TOKUSOKU_BI1;
               i_REC.TOKUSOKU_NAIYO1 := RCJIDO.TOKUSOKU_NAIYO1;
               i_REC.TOKUSOKU_BI2 := RCJIDO.TOKUSOKU_BI2;
               i_REC.TOKUSOKU_NAIYO2 := RCJIDO.TOKUSOKU_NAIYO2;
               i_REC.TOKUSOKU_BI3 := RCJIDO.TOKUSOKU_BI3;
               i_REC.TOKUSOKU_NAIYO3 := RCJIDO.TOKUSOKU_NAIYO3;
               i_REC.TOKUSOKU_BI4 := RCJIDO.TOKUSOKU_BI4;
               i_REC.TOKUSOKU_NAIYO4 := RCJIDO.TOKUSOKU_NAIYO4;
               i_REC.TOKUSOKU_BI5 := RCJIDO.TOKUSOKU_BI5;
               i_REC.TOKUSOKU_NAIYO5 := RCJIDO.TOKUSOKU_NAIYO5;
               i_REC.GAKUNEN := RCJIDO.GAKUNEN;                                         --'学年'                  
               i_REC.SHORIBI := RCJIDO.SHORIBI;                                         --'処理日'                
               i_REC.SHUGAKU := RCJIDO.SHUGAKU;                                         --'就学状況'              
               i_REC.IDOJIKO := RCJIDO.IDOJIKO;                                         --'異動事項'              
               i_REC.CHOHYO_NO := RCJIDO.CHOHYO_NO;                                     --'帳票連番'              
               i_REC.SYOGAKO_TENNYUGAKU_GAKUNEN := RCJIDO.SYOGAKO_TENNYUGAKU_GAKUNEN;   --'小学校転入学 学年'     
               i_REC.SYOGAKO_TENGAKU_GAKUNEN := RCJIDO.SYOGAKO_TENGAKU_GAKUNEN;         --'小学校転学 学年'       
               i_REC.TYUGAKO_TENNYUGAKU_GAKUNEN := RCJIDO.TYUGAKO_TENNYUGAKU_GAKUNEN;   --'中学校転入学 学年'     
               i_REC.TYUGAKO_TENGAKU_GAKUNEN := RCJIDO.TYUGAKO_TENGAKU_GAKUNEN;         --'中学校転学 学年'       
               i_REC.KUIKIGAI_TENNYUGAKU_GAKUNEN := RCJIDO.KUIKIGAI_TENNYUGAKU_GAKUNEN; --'区域外転入学 学年'     
               i_REC.KUIKIGAI_TENGAKU_GAKUNEN := RCJIDO.KUIKIGAI_TENGAKU_GAKUNEN;       --'区域外転学 学年'       
               i_REC.KUIKIGAI_TAIGAKU_GAKUNEN := RCJIDO.KUIKIGAI_TAIGAKU_GAKUNEN;       --'区域外退学 学年'       
               i_REC.YOGOGAKO_TENNYUGAKU_GAKUNEN := RCJIDO.YOGOGAKO_TENNYUGAKU_GAKUNEN; --'盲聾養護学校転入学 学年
               i_REC.YOGOGAKO_TENGAKU_GAKUNEN := RCJIDO.YOGOGAKO_TENGAKU_GAKUNEN;       --'盲聾養護学校転学 学年' 
               i_REC.YOGOGAKO_TAIGAKU_GAKUNEN := RCJIDO.YOGOGAKO_TAIGAKU_GAKUNEN;       --'盲聾養護学校退学 学年' 
            o_NERR := c_ISUCCESS;        --正常終了
            EXIT;       -- 一意的なレコードなので複数回繰り返すことはないので脱出
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
        -- 該当なし
            IFRET := c_ISUCCESS;          -- 該当なしは正常終了とする
            o_NERR := c_INOTFOUND;
        WHEN OTHERS THEN
        -- その他エラー
            IFRET := c_INOT_SUCCESS;
            -- SQL情報取得
            N_SQL_CODE := SQLCODE;
            V_SQL_MSG  := SUBSTR(SQLERRM, 1, 250);
            -- その他エラー
            o_NERR := c_IERR;
    END;
    -- 終了
    RETURN IFRET;
END FUNC_GET_JIDO_REC;

--------------------------------------------------------------------------------
-- メイン処理
--------------------------------------------------------------------------------
BEGIN

    -- 作成
    I_RTN := FUNC_GET_JIDO_REC(o_RG);

    IF I_RTN <> c_ISUCCESS OR
       o_NERR = c_INOTFOUND THEN
    -- エラーの場合、再度初期化する
        -- ）レコードの初期化
        PROC_REC_SHOKIKA(o_RG);
    END IF;
EXCEPTION
-- その他エラー 
    WHEN OTHERS THEN
        -- その他エラー
        o_NERR := c_IERR;
END GKBSKJDOG;
/
