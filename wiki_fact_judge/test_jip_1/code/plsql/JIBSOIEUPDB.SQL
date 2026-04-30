CREATE OR REPLACE PROCEDURE JIBSOIEUPDB(
--1.0.105.002-05.00-03.00
  i_IENTRY_ID         IN  PLS_INTEGER,
  i_NTANMATSU_NO      IN  VARCHAR2,
  i_NSHOKUIN          IN  NVARCHAR2,
  i_SHORIBI           IN  NUMBER,
  i_IDO_JIYU          IN  NUMBER,
  i_ZENBUICHIBU       IN  NUMBER,
  i_FUKI_FLG          IN  NUMBER,
  i_KEIBI_FLG         IN  NUMBER,
  o_VKOJIN_NO         OUT VARCHAR2,
  o_RIREKI_RENBAN     OUT VARCHAR2,
  o_IDO_JIYU          OUT VARCHAR2,
  o_VSEATI_NO         OUT VARCHAR2,
  o_ISHORIBI_KEY      OUT PLS_INTEGER,
  o_ISHORI_JIKAN_KEY  OUT PLS_INTEGER,
  o_N_SQL_CODE        OUT NUMBER,
  o_V_SQL_MSG         OUT VARCHAR2
)
IS
--------------------------------------------------------
--  業務名        JIB(住民記録)
--  PG 名         JIBSOIEUPDB
--  名称          イメージエントリデータ更新(仮更新用)
--  処理概要      イメージエントリ中間データより住基のマスタを更新
--  作成者        ZCZL.XUNWENYAN
--  作成日        2022/07/28
--  Version       0.2.000.000
--------------------------------------------------------
--  修正概要      戸籍連携はマイグレ対象外なのでコメントアウトする
--  作成者        H.Furui
--  作成日        2022/08/02
--  Version       0.2.000.000
--------------------------------------------------------
--  修正概要      : GABSKLNKDTPDの呼び出しをコメントアウトする。
--  バージョン    : 0.0.000.000
--  修正者／修正日: JIP H.Furui   2022/08/15
--------------------------------------------------------
--  修正概要      : 住記系追加作業
--  バージョン    : 0.2.000.001
--  修正者／修正日: ZCZL.WANGM   2023/06/27
--------------------------------------------------------
--  修正概要      : 住基ネット1次開発
--  バージョン    : 0.3.000.000
--  修正者／修正日: DIS.XIYAN   2023/11/20
--------------------------------------------------------
--  修正概要      : 新WizLIFE２次開発
--  バージョン    : 0.3.000.000
--  修正者／修正日: DIS.LIUQIMENG   2024/01/25
--------------------------------------------------------
--  修正概要      : 新WizLIFE２次開発（最新フラグ＝１追加確認）
--  バージョン    : 0.3.000.000
--  修正者／修正日: DIS.Qianyinhua   2024/02/22
--------------------------------------------------------
--  修正概要      : 新WizLIFE２次開発（異動事由コードの一括対応）
--  バージョン    : 0.3.000.000
--  修正者／修正日: DIS.Qianyinhua   2024/02/25
--------------------------------------------------------
--  修正概要      : 受入検証指摘対応
--  バージョン    : 0.3.000.000
--  修正者／修正日: DIS.LIUQIMENG   2024/03/26
--------------------------------------------------------
--  修正概要      : 新WizLIFE２次開発（ph4対応）
--  バージョン    : 0.3.030.000
--  修正者／修正日: DIS.Wangrucheng   2024/04/03
--------------------------------------------------------
--  修正概要      : 受入検証指摘対応
--  バージョン    : 0.3.000.000
--  修正者／修正日: DIS.LIUQIMENG   2024/05/08
--------------------------------------------------------
--  修正概要      : IT_JIB_00054故障対応
--  バージョン      : 0.2.000.002
--  修正者／修正日: ZCZL.wanghj   2024/05/22
--------------------------------------------------------
--  修正概要      : IT_JIB_00115対応
--  バージョン      : 0.3.000.000
--  修正者／修正日: DIS.chenming   2024/08/02
--------------------------------------------------------
--  修正概要      : IT_JIB_00279対応
--  バージョン      : 0.3.000.000
--  修正者／修正日: DIS.huangyaoyu   2024/08/13
--------------------------------------------------------
--  修正概要      : IT_JIB_00228対応
--  バージョン      : 0.3.040.000
--  修正者／修正日: DIS.liuqimeng   2024/08/15
--------------------------------------------------------
--  修正概要      : IT_JIB_00231対応
--  バージョン      : 0.3.040.000
--  修正者／修正日: DIS.liuqimeng   2024/08/15
--------------------------------------------------------
--  修正概要      : IT_JIB_00229対応
--  バージョン      : 0.3.040.000
--  修正者／修正日: DIS.liuqimeng   2024/10/21
--------------------------------------------------------
--  修正概要      : IT_JIB_00454対応
--  バージョン      : 0.3.040.000
--  修正者／修正日: DIS.Gaohaobo 2024/10/22
--------------------------------------------------------
--  修正概要      : 新WizLIFE２次開発_IT_JIB_00550の対応
--  バージョン    : 0.3.000.000
--  修正者／修正日: DIS.Zhaohuanhuan 2024/10/28
--------------------------------------------------------
--  修正概要      : IT_JIB_00809対応
--  バージョン    : 0.3.040.000
--  修正者／修正日: JIP.Yoshida   2024/12/20
--------------------------------------------------------
--  修正概要      : IT_JIB_01005対応
--  バージョン    : 0.3.000.000
--  修正者／修正日: CTC   2025/02/24
--------------------------------------------------------
--  修正概要      : 保守QA #14884対応
--  バージョン    : 1.0.003.000
--  修正者／修正日: DIS.LIJING   2025/05/09
--------------------------------------------------------
--  修正概要      : 新WizLIFE2次開発_QA16307対応
--  バージョン    : 1.0.005.000
--  修正者／修正日: CTC.LIU   2025/05/23
--------------------------------------------------------
--  修正概要      : 新WizLIFE2次開発_QA13677対応
--  バージョン    : 1.0.009.000
--  修正者／修正日: CTC.LIU   2025/06/24
--------------------------------------------------------
--  修正概要      : 新WizLIFE2次開発_QA13759対応
--  バージョン    : 1.0.009.002
--  修正者／修正日: CTC.LI   2025/06/19
--------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA17509
--  バージョン    : 1.0.010.004
--  修正者／修正日: CTC.zhang 2025/07/02
--------------------------------------------------------
--  修正概要      : QA17936対応
--  バージョン    : 1.0.010.005
--  修正者／修正日: JIP   2025/07/07
--------------------------------------------------------
--  修正概要      : QA17556対応
--  バージョン    : 1.0.010.006
--  修正者／修正日: CTC.zhang 2025/07/14
--------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA20504
--  バージョン    : 1.0.016.002
--  修正者／修正日: CTC.liu 2025/09/05
------------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA20711
--  バージョン    : 1.0.017.001
--  修正者／修正日: CTC.liu 2025/09/11
------------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA21118
--  バージョン    : 1.0.017.002
--  修正者／修正日: CTC.liu 2025/09/12
------------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA21654,21666
--  バージョン    : 1.0.021.001
--  修正者／修正日: CTC.liu 2025/10/07
------------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA21647
--  バージョン    : 1.0.022.002
--  修正者／修正日: CTC.liu 2025/10/14
------------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA22490
--  バージョン    : 1.0.025.002
--  修正者／修正日: CTC.liu 2025/10/29
------------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA22785
--  バージョン    : 1.0.026.000
--  修正者／修正日: CTC.liu 2025/11/05
------------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA23150
--  バージョン    : 1.0.026.003
--  修正者／修正日: CTC.liu 2025/11/13
------------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA22566
--  バージョン    : 1.0.027.000
--  修正者／修正日: CTC.liu 2025/11/13
------------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA25517
--  バージョン    : 1.0.105.000
--  修正者／修正日: CTC.zhang 2026/1/7
------------------------------------------------------------
--  修正概要      : 新WizLIFE保守対応 QA24458
--  バージョン    : 1.0.105.002
--  修正者／修正日: CTC.liu 2026/1/7
------------------------------------------------------------
--  変数宣言
------------------------------------------------------------------------------
  -- 配列
  TYPE MT_JUKIJUSHO IS TABLE OF JIBWBUPD_JUKIJUSHO%ROWTYPE INDEX BY BINARY_INTEGER;
  M_JUSHO     MT_JUKIJUSHO;                         -- ワーク住基住所ＴＢＬ配列
  R_BUPD_ATENA JIBWBUPD_JUKIKIHON%ROWTYPE;           -- ワーク宛名基本ＴＢＬ変数
  R_IDO       JIBTJUKIIDO%ROWTYPE;                  -- 住基異動ＴＢＬ変数
  R_ATENA     JIBTJUKIKIHON%ROWTYPE;               -- 宛名基本ＴＢＬ変数
  R_JUSHO     JIBTJUKIJUSHO%ROWTYPE;                -- 宛名基本ＴＢＬ変数
  R_TSUSHORIREKI      JIBTTSUSHORIREKI%ROWTYPE;     -- 通称履歴ＴＢＬ変数
  R_BUPD_JUKIIDO   JIBWBUPD_JUKIIDO%ROWTYPE;          -- 住基異動中間（BUPD用）ＴＢＬ変数
  T_KOJIN_NO  JIBWBUPD_JUKIKIHON.KOJIN_NO%TYPE;     -- ワーク宛名基本ＴＢＬ個人番号変数
  T_JUMIN_CD  JIBWBUPD_JUKIKIHON.JUMINHYO_CD%TYPE;  -- ワーク宛名基本ＴＢＬ住民票コード変数
  T_SETAI_NO  JIBWBUPD_JUKIKIHON.SETAI_NO%TYPE;     -- ワーク宛名基本ＴＢＬ世帯番号変数
  T_RENBAN    JIBWBUPD_JUKIJUSHO.JUSHO_REN%TYPE;     -- ワーク住基住所ＴＢＬ住所連番変数
  T_JINKAKU_KBN               JIBTJUKIIDO.JINKAKU_KBN%TYPE;  --処理対象人格区分
  T_GENZON_KBN                JIBTJUKIIDO.GENZON_KBN%TYPE;   --処理対象現存区分
  T_NUSHI_KBN                 JIBTJUKIIDO.NUSHI_KBN%TYPE;    --処理対象世帯主区分
  T_OAZA_CD                   JIBTJUKIKIHON.OAZA_CD%TYPE;   --処理対象大字コード
  T_GYOSEIKU_CD               JIBTJUKIIDO.GYOSEIKU_CD%TYPE;  --処理対象行政区コード
  T_CHIKU_CD                  JIBTJUKIIDO.CHIKU_CD%TYPE;     --処理対象地区コード
  T_NUSHI_JINKAKU_KBN         JIBTJUKIIDO.JINKAKU_KBN%TYPE;  --処理対象世帯主人格区分
  T_NUSHI_JINKAKU_KBN1        JIBTJUKIIDO.JINKAKU_KBN%TYPE;  --処理対象世帯主人格区分
  T_NUSHI_JINKAKU_KBN2        JIBTJUKIIDO.JINKAKU_KBN%TYPE;  --処理対象世帯主人格区分
  NKADO_BI5                   NUMBER;
  NKADO_BI6                   NUMBER;
  NJOKEN2                     NUMBER;
  WK_JUSHO_CHG                NUMBER;
  VACHOMEI                    NVARCHAR2(1000) := NULL;
  VABANCHI                    NVARCHAR2(1000) := NULL;
  VAKATAGAKI                  NVARCHAR2(1000) := NULL;
  VBCHOMEI                    NVARCHAR2(1000) := NULL;
  VBBANCHI                    NVARCHAR2(1000) := NULL;
  VBKATAGAKI                  NVARCHAR2(1000) := NULL;
  T_JIYU_KBN  GABTIDOJIYU.IDO_JIYU_KBN%TYPE;              -- 異動事由ＴＢＬ異動事由区分変数
  T_JIYU_KBN2 GABTIDOJIYU.IDO_JIYU_KBN%TYPE;              -- 異動事由ＴＢＬ異動事由区分変数
  T_KANA1     GABTSHIMEIKENSAKU.KENSAKU_SHIMEI_KANA%TYPE; -- 氏名検索ＴＢＬ検索用氏名かな変数
  T_KANA2     GABTSHIMEIKENSAKU.KENSAKU_SHIMEI_KANA%TYPE; -- 氏名検索ＴＢＬ検索用氏名かな変数
  T_KANJI1    GABTSHIMEIKENSAKU.KENSAKU_MEI_KANJI%TYPE;   -- 氏名検索ＴＢＬ検索用氏名漢字変数
  T_KANJI2    GABTSHIMEIKENSAKU.KENSAKU_MEI_KANJI%TYPE;   -- 氏名検索ＴＢＬ検索用氏名漢字変数
  T_KANJI3    GABTSHIMEIKENSAKU.KENSAKU_MEI_KANJI%TYPE;   -- 氏名検索ＴＢＬ検索用氏名漢字変数
  T_IDO_KBN   JIBTIDORUIKEI.IDO_KBN%TYPE;                 -- 異動累計ＴＢＬ異動区分変数
  T_MAX_KOJIN_NO    JIBTJUKIKIHON.KOJIN_NO%TYPE;         -- 宛名基本ＴＢＬ個人番号変数
  T_MAX_JUMINHYO_CD JIBTJUKIKIHON.JUMINHYO_CD%TYPE;      -- 宛名基本ＴＢＬ住民票コード変数
  T_MAX_SETAI_NO    JIBTJUKIKIHON.SETAI_NO%TYPE;         -- 宛名基本ＴＢＬ世帯番号変数
  T_RIREKI_RENBAN   JIBWBUPD_JUKIKIHON.RIREKI_RENBAN%TYPE;-- 宛名基本ＴＢＬ履歴連番変数
  RTNCD   PLS_INTEGER := 0;             -- カウント
  I_CNT   PLS_INTEGER := 0;             -- カウント
  I_CNT1  PLS_INTEGER := 0;             -- カウンター
  I_CNT2  PLS_INTEGER := 0;
  I_POS   PLS_INTEGER := 0;
  I_POS_K   PLS_INTEGER := 0;
  A_CNT   PLS_INTEGER := 0;             -- カウント（宛名基本）
  I_SYSDATE PLS_INTEGER := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'));
  I_SYSTIME PLS_INTEGER := TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'));
  I_SYSDATE2 PLS_INTEGER := TO_NUMBER(TO_CHAR(SYSDATE - 1 / 86400 ,'YYYYMMDD'));  --帰化（減）、国籍取得（減）、国籍喪失（減）更新用日付
  I_SYSTIME2 PLS_INTEGER := TO_NUMBER(TO_CHAR(SYSDATE - 1 / 86400 ,'HH24MISS'));  --帰化（減）、国籍取得（減）、国籍喪失（減）更新用時間
  N_KYUUSER_CD  KKATGAPPEIJOHO.KYUUSER_CD%TYPE;
  -- パイプ区切り個人番号格納
  V_KOJIN_NO    NVARCHAR2(1000) ;
  -- 異動元先世帯番号格納変数
  I_IDOMOTO     NUMBER;
  I_IDOSAKI     NUMBER;
  I_JIYU_FLG    PLS_INTEGER := 0;
  B_SHORI_FLG   BOOLEAN := TRUE;
  I_HAITA_SETAI1 NUMBER;
  I_HAITA_SETAI2 NUMBER;
  T_BIKO_BUN_KEY         JIBTJUKIKIHON.SETAI_NO%TYPE       := NULL; --備考文作成中の世帯番号
  T_BIKO_FIRST_CHOMEI    JIBTJUKIJUSHO.CHOMEI%TYPE          := NULL; --先頭者　町名
  T_BIKO_FIRST_BANCHI    JIBTJUKIJUSHO.BANCHI%TYPE          := NULL; --先頭者　番地
  T_BIKO_FIRST_KATAGAKI  JIBTJUKIJUSHO.KATAGAKI%TYPE        := NULL; --先頭者　方書
  T_BIKO_FIRST_HITTOSHA  JIBTJUKIJUSHO.NUSHI_HITTOSYA%TYPE  := NULL; --先頭者　筆頭者
  T_BIKO_HANTEI_CHOMEI   JIBTJUKIJUSHO.CHOMEI%TYPE          := NULL; --判定用　町名
  T_BIKO_HANTEI_BANCHI   JIBTJUKIJUSHO.BANCHI%TYPE          := NULL; --判定用　番地
  T_BIKO_HANTEI_KATAGAKI JIBTJUKIJUSHO.KATAGAKI%TYPE        := NULL; --判定用　方書
  T_BIKO_HANTEI_HITTOSHA JIBTJUKIJUSHO.NUSHI_HITTOSYA%TYPE  := NULL; --判定用　筆頭者
  T_BIKO_BUN             NVARCHAR2(360)        := NULL; --異動累計備考文
  T_TARGET_SETAI_NO      JIBTJUKIKIHON.SETAI_NO%TYPE       := NULL; --異動対象者の世帯番号（仮番号あり）
  I_IDO_COUNTER          NUMBER                             := 0;    --異動対象者のカウンタ

/*氏名変換ＴＢＬへの追加用 */
  T_YOMI_KANA_SEI       GABTSHIMEIHENKAN.YOMI_KANA%TYPE;         -- 氏名変換ＴＢＬ用姓読みかな
  T_YOMI_KANA_MEI       GABTSHIMEIHENKAN.YOMI_KANA%TYPE;         -- 氏名変換ＴＢＬ用名読みかな
  T_HENKANYO_KANJI_SEI  GABTSHIMEIHENKAN.HENKANYO_KANJI%TYPE;    -- 氏名変換ＴＢＬ用姓変換用漢字
  T_HENKANYO_KANJI_MEI  GABTSHIMEIHENKAN.HENKANYO_KANJI%TYPE;    -- 氏名変換ＴＢＬ用名変換用漢字
  ITASHARENKEI          PLS_INTEGER;                             -- 他社連携条件
  NRTN                  NUMBER := 0;                             -- リターンコード
  VKOJIN_NO_IDO         NVARCHAR2(2000) ;                         -- 異動対象個人番号リスト
  T_KANA1_K     GABTSHIMEIKENSAKU.KENSAKU_SHIMEI_KANA%TYPE; -- 氏名検索ＴＢＬ検索用氏名かな変数（旧氏名）
  T_KANA2_K     GABTSHIMEIKENSAKU.KENSAKU_SHIMEI_KANA%TYPE; -- 氏名検索ＴＢＬ検索用氏名かな変数（旧氏名）
  T_KANJI1_K    GABTSHIMEIKENSAKU.KENSAKU_MEI_KANJI%TYPE;   -- 氏名検索ＴＢＬ検索用氏名漢字変数（旧氏名）
  T_KANJI2_K    GABTSHIMEIKENSAKU.KENSAKU_MEI_KANJI%TYPE;   -- 氏名検索ＴＢＬ検索用氏名漢字変数（旧氏名）
  T_KANJI3_K    GABTSHIMEIKENSAKU.KENSAKU_MEI_KANJI%TYPE;   -- 氏名検索ＴＢＬ検索用氏名漢字変数（旧氏名）
  NJOKEN              NUMBER(1);
  NJOKEN111           NUMBER;
--リターンコード
  N_RETN    NUMBER;
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--  VSQL                VARCHAR2(4000);
  VSQL                VARCHAR2(6000);
  VKUBUN              NVARCHAR2(10);
   WK_JINKAKU_KBN    PLS_INTEGER;
  --JIBSORUIUPDのCALL用変数
  N_IDO_ZEN_JINKAKU_KBN    NUMBER;              --異動前_人格区分
  N_IDO_ZEN_GENZON_KBN     NUMBER;              --異動前_現存区分
  N_IDO_ZEN_NUSHI_KBN      NUMBER;              --異動前_世帯主区分
  N_IDO_ZEN_OAZA_CD        NUMBER;              --異動前_大字
  N_IDO_ZEN_GYOSEIKU_CD    NUMBER;              --異動前_行政区コード
  N_IDO_ZEN_CHIKU_CD       NUMBER;              --異動前_地区コード
  N_IZENBU_ICHIBU_KBN      NUMBER;              --異動前_地区コード

  --宛名基本、住基異動の更新用変数
  N_IDO_JIYU               NUMBER;              --異動事由コード
  N_JUMIN_NAKUNARU_JIYU    NUMBER;              --住民でなくなる事由コード
  N_SHORI_KBN_KEY          NUMBER;              --処理区分キー
  V_BIKO                   NVARCHAR2(256);      --備考
  V_IDO_TODOKE_KBN_MEI     NVARCHAR2(256);      --異動届出区分名称
  -- 日付変換サブルーチン用変数(KKAPK0020.FDAYEDIT)
  BRTN               BOOLEAN;                   -- 関数用変数
  io_WAREKIHIZUKE    PLS_INTEGER := NULL;
  io_SEIREKIHIZUKE   PLS_INTEGER := NULL;
  o_EDIT_GYYMMDD1    NVARCHAR2(16);
  o_EDIT_GYYMMDD2    NVARCHAR2(16);
  o_EDIT_GYYMMDD3    NVARCHAR2(16);
  o_KJ_GENGO         NVARCHAR2(16);
  o_KG_GENGO         NVARCHAR2(16);
  o_WAREKI_YY        PLS_INTEGER;
  o_SEIREKI_YYYY     PLS_INTEGER;
  o_WAREKI_GYYMM     PLS_INTEGER;
  o_MM               PLS_INTEGER;
  o_DD               PLS_INTEGER;
  o_WAREKIHIZUKE     PLS_INTEGER;
  o_SEIREKIHIZUKE    PLS_INTEGER;
--  WK_KOJIN_NO        PLS_INTEGER;
  WK_KOJIN_NO        NUMBER;
  WK_FFLG            PLS_INTEGER;
  WK_IDO_JIYU        PLS_INTEGER;
  J_IDOMOTO          NUMBER;
  J_KOJIN_NO         NVARCHAR2(1000);
  WK_RIREKI_RENBAN   PLS_INTEGER;
  NJOKEN4            NUMBER;
  o_RETURNCD         NUMBER;
  NBIKOJKN           NUMBER;
  NSHORI_NO          NUMBER;
  NKADO_BI7          NUMBER;
  RTN_CD             NUMBER;
  o_tITEM                 A_CONS_PRM;
  --変数を追加
  NYOBIDASHI_KBN     NUMBER              := 1;            --変数_呼び出し区分
--  NSEDAINO           NUMBER              := NULL;         --変数_世帯番号
  NSETAINO           NUMBER              := NULL;         --変数_世帯番号
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--  VIDOJIYU           VARCHAR2(2)         := NULL;         --変数_異動者異動事由
  VIDOJIYU           VARCHAR2(3)         := NULL;         --変数_異動者異動事由
  VIDOUKOJINNO       VARCHAR2(2000)       := NULL;         --変数_異動者宛名番号群
  IINDEX             PLS_INTEGER         := 0;            --配列用index
  --配列を追加
  TYPE MTSETAINO_TBL IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
  MNSETAINO          MTSETAINO_TBL;         --配列_世帯番号[i]
  TYPE MTIDOUKOJINNO_TBL IS TABLE OF VARCHAR2(2000) INDEX BY BINARY_INTEGER;
  MVIDOUKOJINNO      MTIDOUKOJINNO_TBL;     --配列_異動者宛名番号群[i]
  MVIDOJIYU          MTIDOUKOJINNO_TBL;     --配列_異動事由[i]
  REBT_JUKIJOHO      JIBTJUKIJOHO%ROWTYPE;
  R_BUPD_JUKIJOHO    JIBWBUPD_JUKIJOHO%ROWTYPE;
  NIDO_KBN           NUMBER(1,0);          --異動区分
  VKEY_JOHO          NVARCHAR2(30);        --キー情報
--2023/06/27 ZCZL.WANGM ADD Start 0.2.000.001:住記系追加作業
  NREPORTCODE2       NUMBER;
  NSHORIKEKKA        NUMBER;
--2023/06/27 ZCZL.WANGM ADD End
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
  VCHOSHACODE        KKNTWS.CHOSHACODE%TYPE;  -- 設置場所
--2024/04/03 DIS.Wangrucheng Add start 0.3.030.000:新WizLIFE２次開発（ph4対応）
  RJIBTJUKIRIREKI_INS     JIBTJUKIRIREKI%ROWTYPE;
  NRIREKI_EDABAN          NUMBER;
  NRIREKI_RENBAN          NUMBER;
--2024/04/03 DIS.Wangrucheng Add end
--2024/10/21 DIS.liuqimeng Add Start 0.3.000.000:IT_JIB_00229対応
  VRYUIJIKO_1 NVARCHAR2(100);--留意事項_1
  VRYUIJIKO_2 NVARCHAR2(100);--留意事項_2
  VRYUIJIKO_3 NVARCHAR2(100);--留意事項_3
--2024/10/21 DIS.liuqimeng Add end
--2024/10/22 DIS.Gaohaobo Add 0.3.040.000:IT_JIB_00454対応
  VNEXTVAL  NUMBER; -- 一回届出番号シーケンス
--2025/05/09 DIS.LIJING Add start 1.0.003.000:保守QA #14884対応
  NCOUNT    NUMBER;
--2025/09/12 CTC.liu update start 1.0.017.002:新WizLIFE保守対応 QA21118
  TUSHORENBAN   NUMBER;
--2025/10/14 CTC.liu add start 1.0.022.002:新WizLIFE保守対応 QA21647
  KAISEI_IDO_JIYU   NUMBER;
  KAISEI_IDO_TODOKE_BI   NUMBER;
  KAISEI_KAISEI_REN   NUMBER;
  KAISEI_RIREKI_RENBAN   NUMBER;
--2026/1/7 CTC.zhang add start 1.0.105.000:新WizLIFE保守対応 QA25517
  RIREKI_RIREKI_RENBAN   NUMBER;
--2025/10/29 CTC.liu add start 1.0.025.002:新WizLIFE保守対応 QA22490
  GAB_RIREKI_RENBAN   NUMBER :=0;
--2025/10/14 CTC.liu add end
  CURSOR CUR_JIBTJUKIBIKO IS
  SELECT *
    FROM JIBTJUKIBIKO
   WHERE RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN)
                            FROM JIBTJUKIBIKO)
     AND SAISHIN_FLG = 1;

  --2024/12/6 CTC Update start 0.3.000.000:IT_JIB_00645対応
--2025/07/14 CTC.zhang update start 1.0.010.006:新WizLIFE保守対応 QA17556
--  CURSOR CUR_JIBWBUPD_BIKO IS
  CURSOR CUR_JIBWBUPD_BIKO(i_IKOJIN_NO NUMBER) IS
--2025/07/14 CTC.zhang update end
  --SELECT *
   -- FROM JIBWBUPD_BIKO
   --WHERE ENTRY_ID = i_IENTRY_ID;
   SELECT BIKO.*,JIYU.IDO_JIYU
     FROM JIBWBUPD_BIKO BIKO
   LEFT JOIN JIBWBUPD_JUKIIDO JIYU
     on BIKO.KOJIN_NO = JIYU.KOJIN_NO and BIKO.ENTRY_ID = JIYU.ENTRY_ID
--2025/07/14 CTC.zhang update start 1.0.010.006:新WizLIFE保守対応 QA17556
--   WHERE BIKO.ENTRY_ID =  i_IENTRY_ID;
   WHERE BIKO.ENTRY_ID =  i_IENTRY_ID
   AND   BIKO.KOJIN_NO =  i_IKOJIN_NO;
--2025/07/14 CTC.zhang update end
--2024/12/6 CTC Update end
--2024/01/25 DIS.liuqimeng Add end
  -- ワーク住基異動カーソル宣言
  CURSOR CUR_IDO (P_ENTRY_ID PLS_INTEGER) IS
    SELECT JI.*,NVL(KK.KYU_KOJIN_NO,0) KYU_KOJIN_NO
      FROM JIBWBUPD_JUKIIDO JI,JIBWBUPD_KYUKOJINNO KK
     WHERE JI.ENTRY_ID = KK.ENTRY_ID(+)
       AND JI.KOJIN_NO = KK.KOJIN_NO(+)
       AND JI.ENTRY_ID = P_ENTRY_ID
     ORDER BY SETAI_NO,KISAI_JUNI;
  -- ワーク住基住所カーソル宣言
  CURSOR C_JUSHO (P_ENTRY_ID PLS_INTEGER,P_KOJIN_NO NUMBER,P_FFLAG PLS_INTEGER) IS
     SELECT ENTRY_ID,
            KOJIN_NO,
            JUSHO_REN,
            OAZA_CD,
            HONBAN,
            EDABAN1,
            EDABAN2,
            EDABAN3,
            KATAGAKI_CD,
            GAIKU,
            TOU,
            GOU,
            USER_CD,
            JICHI_CD,
            YUBIN_NO,
            YUBIN_NOBC,
--2024/08/13 DIS.huangyaoyu Update start 0.3.000.000:IT_JIB_00279対応
--            BANCHI,
--            CHOMEI,
            CHOMEI,
            BANCHI,
--2024/08/13 DIS.huangyaoyu Update end
            KATAGAKI,
            NUSHI_HITTOSYA,
            SYS_SAKUSEIBI,
            SYS_KOSHINBI,
            SYS_JIKAN,
            SYS_SHOKUINKOJIN_NO,
            SYS_TANMATSU_NO,
            CHOMEI_KANA,
            BANCHI_KANA,
            KATAGAKI_KANA,
            KATAGAKI_HIDE_FLG
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
           ,KETAPRM
           ,KOKUMEI_CD
--2024/01/25 DIS.liuqimeng Add end
       FROM JIBWBUPD_JUKIJUSHO
      WHERE ENTRY_ID = P_ENTRY_ID
        AND KOJIN_NO = P_KOJIN_NO
--2026/01/06 CTC.liu add start 1.0.105.002:新WizLIFE保守対応 QA24458
--記載順位変更対象者のみ対象条件するため、追加
        AND KATAGAKI_HIDE_FLG <> 3
      UNION
     SELECT P_ENTRY_ID,
            KOJIN_NO,
            JUSHO_REN,
            OAZA_CD,
            HONBAN,
            EDABAN1,
            EDABAN2,
            EDABAN3,
            KATAGAKI_CD,
            GAIKU,
            TOU,
            GOU,
            USER_CD,
            JICHI_CD,
            YUBIN_NO,
            YUBIN_NOBC,
--2024/08/13 DIS.huangyaoyu Update start 0.3.000.000:IT_JIB_00279対応
--            BANCHI,
--            CHOMEI,
            CHOMEI,
            BANCHI,
--2024/08/13 DIS.huangyaoyu Update end
            KATAGAKI,
            NUSHI_HITTOSYA,
            SYS_SAKUSEIBI,
            SYS_KOSHINBI,
            SYS_JIKAN,
            SYS_SHOKUINKOJIN_NO,
            SYS_TANMATSU_NO,
            CHOMEI_KANA,
            BANCHI_KANA,
            KATAGAKI_KANA,
            KATAGAKI_HIDE_FLG
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
           ,KETAPRM
           ,KOKUMEI_CD
--2024/01/25 DIS.liuqimeng Add end
       FROM JIBTJUKIJUSHO B
      WHERE (KOJIN_NO,JUSHO_REN) IN (SELECT KOJIN_NO,
                                            GENJUSHO_REN
                                       FROM JIBWBUPD_JUKIIDO
                                      WHERE KOJIN_NO = P_KOJIN_NO
                                      UNION
                                     SELECT KOJIN_NO,
                                            ZENJUSHO_REN
                                       FROM JIBWBUPD_JUKIIDO
                                      WHERE KOJIN_NO = P_KOJIN_NO
                                      UNION
                                     SELECT KOJIN_NO,
                                            TENNYUMAE_REN
                                       FROM JIBWBUPD_JUKIIDO
                                      WHERE KOJIN_NO = P_KOJIN_NO
                                      UNION
                                     SELECT KOJIN_NO,
                                            TENNYU_MITODOKE_REN
                                       FROM JIBWBUPD_JUKIIDO
                                      WHERE KOJIN_NO = P_KOJIN_NO
                                      UNION
                                     SELECT KOJIN_NO,
                                            HONSEKI_REN
                                       FROM JIBWBUPD_JUKIIDO
                                      WHERE KOJIN_NO = P_KOJIN_NO
                                    --2025/02/19 CTC Update start 0.3.000.000:IT_JIB_01005対応
                                      UNION
                                     SELECT KOJIN_NO,
                                            SAISYUTOROKUJUSHO_REN
                                       FROM JIBWBUPD_JUKIIDO
                                      WHERE KOJIN_NO = P_KOJIN_NO
                                      )
        AND P_FFLAG = 1;
  -- 転出証明データ取得カーソル
  CURSOR C_TENSHUTSUKOJIN(P_JUMIN_CD NUMBER) IS
    SELECT TENSHUTUCHI_JICHI_CD,
           SAKUSEI_NENGAPPI,
           SAKUSEI_RENBAN
      FROM JIBTJNTENSHUTSUKOJIN
     WHERE LPAD(TRIM(JUMINHYO_CD),11,'0') = LPAD(TO_NCHAR(P_JUMIN_CD),11,'0');

  CURSOR C_TENSHUTSUKOJIN2(P_JICHI_CD NUMBER, P_NENGAPPI NUMBER, P_RENBAN NUMBER) IS
    SELECT SHORIZUMI_FLAG FROM JIBTJNTENSHUTSUKOJIN
     WHERE TENSHUTUCHI_JICHI_CD = P_JICHI_CD AND
           SAKUSEI_NENGAPPI     = P_NENGAPPI AND
           SAKUSEI_RENBAN       = P_RENBAN;

  CURSOR C_HOMUSHO(P_SETAI_NO NVARCHAR2,
                   P_SYSDATE NUMBER,
                   P_SYSTIME  NUMBER) IS
    SELECT KOJIN_NO,
           JINKAKU_KBN,
           IDO_JIYU,
           SYS_SHOKUINKOJIN_NO,
           SYS_TANMATSU_NO
      FROM JIBTJUKIIDO
     WHERE SETAI_NO IN (P_SETAI_NO) AND
           SHORIBI_KEY = P_SYSDATE AND
           SHORI_JIKAN_KEY = P_SYSTIME;

  CURSOR CUR_SHITEIJIYUIDO (P_ENTRY_ID PLS_INTEGER) IS
    SELECT JI.*,
           AK.KOJIN_NO                   ATENA_KOJIN_NO,
           AK.RIREKI_RENBAN              ATENA_RIREKI_RENBAN,
           AK.TEKIYO_BI                  ATENA_TEKIYO_BI,
           AK.TOROKU_GYOMU               ATENA_TOROKU_GYOMU,
           AK.JUMINHYO_CD                ATENA_JUMINHYO_CD,
           AK.SETAI_NO                   ATENA_SETAI_NO,
           AK.GENZON_KBN                 ATENA_GENZON_KBN,
           AK.JINKAKU_KBN                ATENA_JINKAKU_KBN,
           AK.KOKUSEKI_CD                ATENA_KOKUSEKI_CD,
           AK.SHISHO_CD                  ATENA_SHISHO_CD,
           AK.CHIKU_CD                   ATENA_CHIKU_CD,
           AK.GYOSEIKU_CD                ATENA_GYOSEIKU_CD,
           AK.HAN_CD                     ATENA_HAN_CD,
           AK.SHOGAKU_CD                 ATENA_SHOGAKU_CD,
           AK.CHUGAKU_CD                 ATENA_CHUGAKU_CD,
           AK.TOHYOKU_CD                 ATENA_TOHYOKU_CD,
           AK.SANTEIDANTAI_CD            ATENA_SANTEIDANTAI_CD,
           AK.SEINENGAPI                 ATENA_SEINENGAPI,
           AK.WAREKI_SEINENGAPI          ATENA_WAREKI_SEINENGAPI,
           AK.HYOJI_SEINENGAPI           ATENA_HYOJI_SEINENGAPI,
           AK.SEIBETSU                   ATENA_SEIBETSU,
           AK.USER_CD                    ATENA_USER_CD,
           AK.OAZA_CD                    ATENA_OAZA_CD,
           AK.HONBAN                     ATENA_HONBAN,
           AK.EDABAN1                    ATENA_EDABAN1,
           AK.EDABAN2                    ATENA_EDABAN2,
           AK.EDABAN3                    ATENA_EDABAN3,
           AK.KATAGAKI_CD                ATENA_KATAGAKI_CD,
           AK.GAIKU                      ATENA_GAIKU,
           AK.TOU                        ATENA_TOU,
           AK.GOU                        ATENA_GOU,
           AK.JICHI_CD                   ATENA_JICHI_CD,
           AK.SHIMEI_KANA                ATENA_SHIMEI_KANA,
           AK.SHIMEI_KANJI               ATENA_SHIMEI_KANJI,
           AK.YUBIN_NO                   ATENA_YUBIN_NO,
           AK.YUBIN_NOBC                 ATENA_YUBIN_NOBC,
           AK.CHOMEI                     ATENA_CHOMEI,
           AK.BANCHI                     ATENA_BANCHI,
           AK.KATAGAKI                   ATENA_KATAGAKI,
           AK.DAIHYO_KATAGAKI            ATENA_DAIHYO_KATAGAKI,
           AK.DAIHYO_SHIMEI              ATENA_DAIHYO_SHIMEI,
           AK.TEL_NO                     ATENA_TEL_NO,
           AK.TEL_KBN                    ATENA_TEL_KBN,
           AK.FAX_NO                     ATENA_FAX_NO,
           AK.MAIL_ADS                   ATENA_MAIL_ADS,
           AK.YUHEN_KBN                  ATENA_YUHEN_KBN,
           AK.TOROKU_JIYU                ATENA_TOROKU_JIYU,
           AK.JUFUKU_KOJIN_NO            ATENA_JUFUKU_KOJIN_NO,
           AK.HONMYO_KANA                ATENA_HONMYO_KANA,
           AK.HONMYO_KANJI               ATENA_HONMYO_KANJI,
           AK.SYS_SAKUSEIBI              ATENA_SYS_SAKUSEIBI,
           AK.SYS_KOSHINBI               ATENA_SYS_KOSHINBI,
           AK.SYS_JIKAN                  ATENA_SYS_JIKAN,
           AK.SYS_SHOKUINKOJIN_NO        ATENA_SYS_SHOKUINKOJIN_NO,
           AK.SYS_TANMATSU_NO            ATENA_SYS_TANMATSU_NO,
           AK.CHOMEI_KANA                ATENA_CHOMEI_KANA,
           AK.BANCHI_KANA                ATENA_BANCHI_KANA,
           AK.KATAGAKI_KANA              ATENA_KATAGAKI_KANA,
           AK.KATAGAKI_HIDE_FLG          ATENA_KATAGAKI_HIDE_FLG,
           AK.GAIJI_FLG                  ATENA_GAIJI_FLG,
           AK.HOJINSOSHIKI_CD            ATENA_HOJINSOSHIKI_CD,
           AK.JE_KOKUHOSHISANWARI_KBN    ATENA_JE_KOKUHOSHISANWARI_KBN,
           AK.JE_JINTEKIGENMEN_KBN       ATENA_JE_JINTEKIGENMEN_KBN,
           AK.JE_SHOYUSHAKEISHONIN_KBN   ATENA_JE_SHOYUSHAKEISHONIN_KBN,
           AK.JE_LINK_KOJIN_NO           ATENA_JE_LINK_KOJIN_NO,
           AK.JE_NAYOSE_NO               ATENA_JE_NAYOSE_NO,
           AK.YOBI1_CD                   ATENA_YOBI1_CD,
           AK.YOBI2_CD                   ATENA_YOBI2_CD,
           AK.YOBI3_CD                   ATENA_YOBI3_CD,
           AK.YOBI4_CD                   ATENA_YOBI4_CD,
           AK.YOBI5_CD                   ATENA_YOBI5_CD,
           AK.YOBI1_CH                   ATENA_YOBI1_CH,
           AK.YOBI2_CH                   ATENA_YOBI2_CH,
           AK.YOBI3_CH                   ATENA_YOBI3_CH,
           AK.YOBI4_CH                   ATENA_YOBI4_CH,
           AK.YOBI5_CH                   ATENA_YOBI5_CH

          ,AK.TOUGOU_NO                  ATENA_TOUGOU_NO
          ,AK.SEIDO_HOJIN_NO             ATENA_SEIDO_HOJIN_NO
          ,AK.SEIDO_KOJIN_NO             ATENA_SEIDO_KOJIN_NO
          ,AK.ZOKUGARACD1                ATENA_ZOKUGARA_CD1
          ,AK.ZOKUGARACD2                ATENA_ZOKUGARA_CD2
          ,AK.ZOKUGARACD3                ATENA_ZOKUGARA_CD3
          ,AK.ZOKUGARACD4                ATENA_ZOKUGARA_CD4
          ,AK.ZOKUGARAKBN                ATENA_ZOKUGARA_KBN
          ,AK.ZOKUGARAMEI                ATENA_ZOKUGARA_MEI
          ,AK.JITSUZOKUGARAMEI           ATENA_JITSU_ZOKUGARA_MEI
          ,JH.KYUUJI_KANA
          ,JH.KYUUJI_KANJI
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
          ,AK.RIREKI_EDABAN              ATENA_RIREKI_EDABAN     --履歴枝番
          ,AK.SAISHIN_FLG                ATENA_SAISHIN_FLG       --最新フラグ(0:最新でない 1:最新)
          ,AK.TORIKESHI_FLG              ATENA_TORIKESHI_FLG       --取消フラグ(0:取消でない 1:取消)
          ,AK.JOHYOYODATA_FLG            ATENA_JOHYOYODATA_FLG   --除票用データフラグ(0:住記データ 1:除票用データ)
          ,AK.KETAPRM                    ATENA_KETAPRM           --住所_桁取パラメータ（基本データリスト用項目）
          ,AK.KOKUMEI_CD                 ATENA_KOKUMEI_CD        --住所_国名コード（住登外者宛名番号管理の基本データリスト用項目）
          ,JH.KYUUJI_KANA_FLG            JH_KYUUJI_KANA_FLG                            --旧氏カナフラグ
--2024/01/25 DIS.liuqimeng Add end
      FROM JIBTJUKIIDO JI,JIBTJUKIKIHON AK
          ,JIBTJUKIJOHO JH
     WHERE JI.KOJIN_NO = AK.KOJIN_NO
       AND JI.KOJIN_NO IN (SELECT IJI.KOJIN_NO
                             FROM JIBWBUPD_JUKIIDO IJI,
                                  JIBWBUPD_KYUKOJINNO IKK
                            WHERE IJI.ENTRY_ID = IKK.ENTRY_ID(+)
                              AND IJI.KOJIN_NO = IKK.KOJIN_NO(+)
                              AND IJI.ENTRY_ID = P_ENTRY_ID
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--                              AND IJI.IDO_JIYU IN (15,16,28))
--2025/6/24 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
                              --AND IJI.IDO_JIYU IN (150,160,280))
                              AND IJI.IDO_JIYU IN (150,160,280,191))
       AND AK.KOJIN_NO = JH.KOJIN_NO(+)
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--       AND AK.RIREKI_RENBAN = JH.RIREKI_RENBAN(+);
       AND AK.RIREKI_RENBAN = JH.RIREKI_RENBAN(+)
       AND AK.RIREKI_EDABAN = JH.RIREKI_EDABAN(+);
--2024/01/25 DIS.liuqimeng Update end
  -- 通称履歴(BUPD用)カーソル宣言
  CURSOR C_BUPD_TSUSHORIREKI (P_ENTRY_ID PLS_INTEGER,P_KOJIN_NO NUMBER,P_RIREKI_RENBAN NUMBER) IS
    SELECT * FROM JIBWBUPD_TSUSHORIREKI
     WHERE ENTRY_ID = P_ENTRY_ID
       AND KOJIN_NO = P_KOJIN_NO
       AND RIREKI_RENBAN = P_RIREKI_RENBAN;

  -- 通称履歴カーソル宣言
  CURSOR C_TSUSHORIREKI (P_KOJIN_NO NUMBER,P_RIREKI_RENBAN NUMBER) IS
    SELECT * FROM JIBTTSUSHORIREKI
     WHERE KOJIN_NO = P_KOJIN_NO
--2025/09/12 CTC.liu update start 1.0.017.002:新WizLIFE保守対応 QA21118
       --AND RIREKI_RENBAN = P_RIREKI_RENBAN;
      AND RIREKI_RENBAN = P_RIREKI_RENBAN
      AND RIREKI_EDABAN = (SELECT MAX(RIREKI_EDABAN)
                            FROM JIBTTSUSHORIREKI
                            WHERE  KOJIN_NO = P_KOJIN_NO
                            AND    RIREKI_RENBAN = P_RIREKI_RENBAN);
--2025/09/12 CTC.liu update end

  ---------------------------------------------------------------
  -- システム条件取得
  ---------------------------------------------------------------
  PROCEDURE PROC_GET_SYSTEMJOKEN
  IS
  BEGIN
    NRTN := KKAPK0030.FCTGetR('JIB','SYSTEM_JOKEN','0002','2',o_tITEM);
    IF NRTN <> 0 THEN
      ITASHARENKEI := 0;
    ELSE
      ITASHARENKEI := o_tITEM(1);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      ITASHARENKEI := 0;
  END PROC_GET_SYSTEMJOKEN;

  PROCEDURE PROC_GET_SYSTEMJOKEN2
  IS
  BEGIN
    NRTN := KKAPK0030.FCTGetR('JIB','SYSTEM_JOKEN','0001','71',o_tITEM);
    IF NRTN <> 0 THEN
      NJOKEN := 0;
    ELSE
      NJOKEN := o_tITEM(1);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      NJOKEN := 0;
  END PROC_GET_SYSTEMJOKEN2;

  PROCEDURE PROC_GET_SYSTEMJOKEN3
  IS
  BEGIN
       BEGIN
            SELECT KADO_BI
            INTO NKADO_BI6
            FROM JIBTKADOBI_KANRI
           WHERE RENBAN = 6;
        EXCEPTION
          WHEN OTHERS THEN
            NKADO_BI6 := 0;
        END;

       BEGIN
            SELECT KADO_BI
            INTO NKADO_BI5
            FROM JIBTKADOBI_KANRI
           WHERE RENBAN = 5;
        EXCEPTION
          WHEN OTHERS THEN
            NKADO_BI5 := 0;
        END;

       BEGIN
            SELECT KADO_BI
            INTO NKADO_BI7
            FROM JIBTKADOBI_KANRI
           WHERE RENBAN = 7;
        EXCEPTION
          WHEN OTHERS THEN
            NKADO_BI7 := 99999999;
        END;

       BEGIN
            NRTN := KKAPK0030.FCTGetR('JIB','SYSTEM_JOKEN','0001','104',o_tITEM);
            IF NRTN <> 0 THEN
              NJOKEN2 := 1;
            ELSE
              NJOKEN2 := o_tITEM(1);
            END IF;
        EXCEPTION
          WHEN OTHERS THEN
               NJOKEN2 := 1;
        END;
  END PROC_GET_SYSTEMJOKEN3;
---------------------------------------------------------------
-- システム条件取得(1,111)
---------------------------------------------------------------
  PROCEDURE PROC_GET_SYSTEMJOKEN111
  IS
  BEGIN
    NRTN := KKAPK0030.FCTGetR('JIB','SYSTEM_JOKEN','0001','111',o_tITEM);
    IF NRTN <> 0 THEN
      NJOKEN111 := 0;
    ELSE
      NJOKEN111 := o_tITEM(1);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      NJOKEN111 := 0;
  END PROC_GET_SYSTEMJOKEN111;
---------------------------------------------------------------
-- システム条件取得(2,3)
---------------------------------------------------------------
  PROCEDURE PROC_GET_SYSTEMJOKEN4
  IS
  BEGIN
    NRTN := KKAPK0030.FCTGetR('JIB','SYSTEM_JOKEN','0002','3',o_tITEM);
    IF NRTN <> 0 THEN
      NJOKEN4 := 0;
    ELSE
      NJOKEN4 := o_tITEM(1);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      NJOKEN4 := 0;
  END PROC_GET_SYSTEMJOKEN4;
----------------------------------------------------------
--日付の転換関数
----------------------------------------------------------
  FUNCTION FUNCDAYEDIT(NSEIREKI IN NUMBER) RETURN NVARCHAR2
  IS

    VEDIT_DAY          NVARCHAR2(12)     := '';--戻り値

  BEGIN
    io_WAREKIHIZUKE  := NULL;
    io_SEIREKIHIZUKE := NSEIREKI;
    IF NSEIREKI IS NOT NULL AND
      NSEIREKI > 0 THEN
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
                              o_WAREKIHIZUKE,
                              o_SEIREKIHIZUKE);
      IF BRTN THEN
        VEDIT_DAY := o_EDIT_GYYMMDD3;
      END IF;
    END IF;
  RETURN(VEDIT_DAY);
  END FUNCDAYEDIT;
  -- 発行注意を旧世帯から新しい世帯にコピーする
  PROCEDURE PROC_COPY_HAKKOCHUI(NSETAI_FROM IN NUMBER, NSETAI_TO IN NUMBER)
  IS
    R_HAKKOCHUI   JIBTHAKKOCHUI%ROWTYPE;
  BEGIN
    -- 旧世帯の発行注意文を取得
    SELECT *
      INTO R_HAKKOCHUI
      FROM JIBTHAKKOCHUI
     WHERE SETAI_NO = NSETAI_FROM;

    -- 新世帯の世帯番号で発行注意文を作成
    INSERT
      INTO JIBTHAKKOCHUI
           (SETAI_NO,
            HAKKO_CHUI_BUN,
            SYS_SAKUSEIBI,
            SYS_KOSHINBI,
            SYS_JIKAN,
            SYS_SHOKUINKOJIN_NO,
            SYS_TANMATSU_NO)
    VALUES (NSETAI_TO,
            R_HAKKOCHUI.HAKKO_CHUI_BUN,
            i_SHORIBI,
            0,
            I_SYSTIME,
            i_NSHOKUIN,
            i_NTANMATSU_NO);

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END PROC_COPY_HAKKOCHUI;

BEGIN
  -- システム条件取得
  PROC_GET_SYSTEMJOKEN;
  PROC_GET_SYSTEMJOKEN2;

  PROC_GET_SYSTEMJOKEN3;
  PROC_GET_SYSTEMJOKEN111;
  PROC_GET_SYSTEMJOKEN4;
--2024/10/22 DIS.Gaohaobo Add 0.3.040.000:IT_JIB_00454対応
  SELECT JIBSOTODOKEDE_SEQ.NEXTVAL INTO VNEXTVAL FROM DUAL;
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
  --設置場所取得
  BEGIN
    SELECT CHOSHACODE
      INTO VCHOSHACODE
      FROM KKNTWS
     WHERE WSNUM = i_NTANMATSU_NO;
  EXCEPTION
    WHEN OTHERS THEN
      VCHOSHACODE := NULL;
  END;
--2024/01/25 DIS.liuqimeng Add end
--2023/06/27 ZCZL.WANGM ADD Start 0.2.000.001:住記系追加作業
  --入力票コード−異動事由を取得
  BEGIN
    SELECT REPORTCODE2
      INTO NREPORTCODE2
      FROM KKFTENTRYLIST
     WHERE GYOMUCODE = 'JIB'
       AND ENTRYID = i_IENTRY_ID;

  EXCEPTION
    WHEN OTHERS THEN
    NREPORTCODE2 := 0;
  END;
--2023/06/27 ZCZL.WANGM ADD End
  --------------------------------------------------------------
  -- 異動対象者の世帯番号を取得する
  -------------------------------------------------------------

--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--  IF i_IDO_JIYU = 24 AND NKADO_BI5 <= I_SYSDATE THEN
--    WK_IDO_JIYU := 28;
  IF i_IDO_JIYU = 240 AND NKADO_BI5 <= I_SYSDATE THEN
    WK_IDO_JIYU := 280;
--2024/01/25 DIS.liuqimeng Update end
  ELSE
    WK_IDO_JIYU := i_IDO_JIYU;
  END IF;
  SELECT DISTINCT SETAI_NO
    INTO T_TARGET_SETAI_NO
    FROM JIBWBUPD_JUKIIDO
    WHERE IDO_JIYU = WK_IDO_JIYU
     AND ENTRY_ID = i_IENTRY_ID;
    BEGIN
         SELECT JINKAKU_KBN
           INTO T_NUSHI_JINKAKU_KBN1
           FROM JIBTJUKIIDO
          WHERE SETAI_NO = T_TARGET_SETAI_NO
            AND NUSHI_KBN = 1
            AND GENZON_KBN = 0;
    EXCEPTION
         WHEN OTHERS THEN
              T_NUSHI_JINKAKU_KBN1 := 9;
    END;
     BEGIN
         SELECT JINKAKU_KBN
           INTO T_NUSHI_JINKAKU_KBN2
           FROM JIBTJUKIIDO
          WHERE SETAI_NO = (SELECT DISTINCT SETAI_NO
                              FROM JIBWBUPD_JUKIIDO
                             WHERE SETAI_NO <> T_TARGET_SETAI_NO
                               AND ENTRY_ID = i_IENTRY_ID)
            AND NUSHI_KBN = 1
            AND GENZON_KBN = 0;
    EXCEPTION
         WHEN OTHERS THEN
              T_NUSHI_JINKAKU_KBN2 := 9;
    END;


  -- 帰化等の情報を取得するカーソル
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--  IF i_IDO_JIYU IN (15,16,24) AND NKADO_BI5 <= I_SYSDATE THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
  --IF i_IDO_JIYU IN (150,160,240) AND NKADO_BI5 <= I_SYSDATE THEN
  IF i_IDO_JIYU IN (150,160,240,191) AND NKADO_BI5 <= I_SYSDATE THEN
    J_IDOMOTO := 0;
    J_KOJIN_NO := NULL;
    NBIKOJKN := 0;
    BEGIN
      NRTN := KKAPK0030.FCTGetR('JIB','SYSTEM_JOKEN','0001','9009',o_tITEM);
      IF NRTN <> 0 THEN
        NBIKOJKN := 0;
      ELSE
        NBIKOJKN := o_tITEM(1);
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NBIKOJKN := 0;
    END;
    FOR CR_SHITEIJIYUIDO IN CUR_SHITEIJIYUIDO(i_IENTRY_ID) LOOP
      --更新前の内容を住記異動累積ワークテーブル（JIBWIDORUISEKI）に書込む
      INSERT INTO JIBWIDORUISEKI VALUES
        ( 'B',
          CR_SHITEIJIYUIDO.ATENA_KOJIN_NO,
          CR_SHITEIJIYUIDO.ATENA_RIREKI_RENBAN,
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
          CR_SHITEIJIYUIDO.ATENA_RIREKI_EDABAN,    --履歴枝番
          CR_SHITEIJIYUIDO.ATENA_SAISHIN_FLG,      --最新フラグ
          CR_SHITEIJIYUIDO.ATENA_TORIKESHI_FLG,    --取消フラグ
          CR_SHITEIJIYUIDO.ATENA_JOHYOYODATA_FLG,  --除票用データフラグ
--2024/01/25 DIS.liuqimeng Add end
          CR_SHITEIJIYUIDO.ATENA_TEKIYO_BI,
          CR_SHITEIJIYUIDO.ATENA_TOROKU_GYOMU,
          CR_SHITEIJIYUIDO.ATENA_SETAI_NO,
          CR_SHITEIJIYUIDO.ATENA_GENZON_KBN,
          CR_SHITEIJIYUIDO.JUN_SETAI_KBN,
          CR_SHITEIJIYUIDO.ATENA_JINKAKU_KBN,
          CR_SHITEIJIYUIDO.ATENA_KOKUSEKI_CD,
          CR_SHITEIJIYUIDO.ATENA_SHISHO_CD,
          CR_SHITEIJIYUIDO.ATENA_CHIKU_CD,
          CR_SHITEIJIYUIDO.ATENA_GYOSEIKU_CD,
          CR_SHITEIJIYUIDO.ATENA_HAN_CD,
          CR_SHITEIJIYUIDO.ATENA_SHOGAKU_CD,
          CR_SHITEIJIYUIDO.ATENA_CHUGAKU_CD,
          CR_SHITEIJIYUIDO.ATENA_TOHYOKU_CD,
          CR_SHITEIJIYUIDO.ATENA_SANTEIDANTAI_CD,
          CR_SHITEIJIYUIDO.ATENA_SEINENGAPI,
          CR_SHITEIJIYUIDO.ATENA_WAREKI_SEINENGAPI,
          CR_SHITEIJIYUIDO.ATENA_HYOJI_SEINENGAPI,
          CR_SHITEIJIYUIDO.ATENA_SEIBETSU,
          CR_SHITEIJIYUIDO.ATENA_USER_CD,
          CR_SHITEIJIYUIDO.ATENA_OAZA_CD,
          CR_SHITEIJIYUIDO.ATENA_HONBAN,
          CR_SHITEIJIYUIDO.ATENA_EDABAN1,
          CR_SHITEIJIYUIDO.ATENA_EDABAN2,
          CR_SHITEIJIYUIDO.ATENA_EDABAN3,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI_CD,
          CR_SHITEIJIYUIDO.ATENA_GAIKU,
          CR_SHITEIJIYUIDO.ATENA_TOU,
          CR_SHITEIJIYUIDO.ATENA_GOU,
          CR_SHITEIJIYUIDO.ATENA_JICHI_CD,
          CR_SHITEIJIYUIDO.ATENA_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.ATENA_SHIMEI_KANJI,
          CR_SHITEIJIYUIDO.ATENA_YUBIN_NO,
          CR_SHITEIJIYUIDO.ATENA_YUBIN_NOBC,
          CR_SHITEIJIYUIDO.ATENA_CHOMEI,
          CR_SHITEIJIYUIDO.ATENA_BANCHI,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI,
          CR_SHITEIJIYUIDO.ATENA_DAIHYO_KATAGAKI,
          CR_SHITEIJIYUIDO.ATENA_DAIHYO_SHIMEI,
          CR_SHITEIJIYUIDO.ATENA_TEL_NO,
          CR_SHITEIJIYUIDO.ATENA_TEL_KBN,
          CR_SHITEIJIYUIDO.ATENA_FAX_NO,
          CR_SHITEIJIYUIDO.ATENA_MAIL_ADS,
          CR_SHITEIJIYUIDO.ATENA_YUHEN_KBN,
          CR_SHITEIJIYUIDO.ATENA_TOROKU_JIYU,
          CR_SHITEIJIYUIDO.JUMINHYO_CD,
          CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD1,
          CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD2,
          CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD3,
          CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD4,
          CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_KBN,
          CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_MEI,
          CR_SHITEIJIYUIDO.ATENA_JITSU_ZOKUGARA_MEI,
          CR_SHITEIJIYUIDO.KISAI_JUNI,
          CR_SHITEIJIYUIDO.IDO_BI,
          CR_SHITEIJIYUIDO.IDO_JIYU,
          CR_SHITEIJIYUIDO.IDO_TODOKE_BI,
          CR_SHITEIJIYUIDO.IDO_TODOKE_KBN,
          CR_SHITEIJIYUIDO.JUTEI_BI,
          CR_SHITEIJIYUIDO.JUTEI_JIYU,
          CR_SHITEIJIYUIDO.JUTEI_TODOKEDE_BI,
          CR_SHITEIJIYUIDO.JUTEI_TODOKEDE_KBN,
          CR_SHITEIJIYUIDO.GENJUSHO_REN,
          CR_SHITEIJIYUIDO.ZENJUSHO_REN,
          CR_SHITEIJIYUIDO.TENNYUMAE_REN,
          CR_SHITEIJIYUIDO.TENNYU_MITODOKE_REN,
          CR_SHITEIJIYUIDO.HONSEKI_REN,
          CR_SHITEIJIYUIDO.TENSHUTSU_YOTEI_BI,
          CR_SHITEIJIYUIDO.TENSHUTSU_YOTEI_TODOKEDE_BI,
          CR_SHITEIJIYUIDO.TENSHUTSU_YOTEI_TODOKEDE_KBN,
          CR_SHITEIJIYUIDO.TENSHUTSU_YOTEI_REN,
          CR_SHITEIJIYUIDO.TENSHUTSU_KAKUTEI_BI,
          CR_SHITEIJIYUIDO.TENSHUTSU_KAKUTEI_TSUCHI_BI,
          CR_SHITEIJIYUIDO.TENSHUTSU_KAKUTEI_TODOKEDE_KBN,
          CR_SHITEIJIYUIDO.TENSHUTSU_KAKUTEI_REN,
          CR_SHITEIJIYUIDO.JUMIN_NARU,
          CR_SHITEIJIYUIDO.JUMIN_NARU_JIYU,
          CR_SHITEIJIYUIDO.JUMIN_NARU_TODOKEDE_BI,
          CR_SHITEIJIYUIDO.JUMIN_NARU_TODOKEDE_KBN,
          CR_SHITEIJIYUIDO.JUMIN_NAKUNARU,
          CR_SHITEIJIYUIDO.JUMIN_NAKUNARU_JIYU,
          CR_SHITEIJIYUIDO.JUMIN_NAKUNARU_TODOKEDE_BI,
          CR_SHITEIJIYUIDO.JUMIN_NAKUNARU_TODOKEDE_KBN,
          CR_SHITEIJIYUIDO.SHIBOBI_FUSHO_KBN,
          CR_SHITEIJIYUIDO.ATENA_HONMYO_KANA,
          CR_SHITEIJIYUIDO.ATENA_HONMYO_KANJI,
          CR_SHITEIJIYUIDO.NUSHI_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.NUSHI_SHIMEI_KANJI,
          CR_SHITEIJIYUIDO.BIKO,
          CR_SHITEIJIYUIDO.KAISEI_BI,
          CR_SHITEIJIYUIDO.KAISEI_REN,
          CR_SHITEIJIYUIDO.KYU_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.KYU_SHIMEI_KANJI,
          CR_SHITEIJIYUIDO.SHORIBI_KEY,
          CR_SHITEIJIYUIDO.SHORI_JIKAN_KEY,
          CR_SHITEIJIYUIDO.SHORI_KBN_KEY,
          CR_SHITEIJIYUIDO.ZENBU_ICHIBU_KEY,
          CR_SHITEIJIYUIDO.SHOKUINKOJIN_NO_KEY,
          CR_SHITEIJIYUIDO.ATENA_SYS_SAKUSEIBI,
          CR_SHITEIJIYUIDO.ATENA_SYS_KOSHINBI,
          CR_SHITEIJIYUIDO.ATENA_SYS_JIKAN,
          CR_SHITEIJIYUIDO.ATENA_SYS_SHOKUINKOJIN_NO,
          CR_SHITEIJIYUIDO.ATENA_SYS_TANMATSU_NO,
          CR_SHITEIJIYUIDO.GOMI_CD,
          CR_SHITEIJIYUIDO.SINYO_CD,
          CR_SHITEIJIYUIDO.KOIKIKOFU_STOP_CD,
          CR_SHITEIJIYUIDO.ATENA_CHOMEI_KANA,
          CR_SHITEIJIYUIDO.ATENA_BANCHI_KANA,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI_KANA,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI_HIDE_FLG,
          CR_SHITEIJIYUIDO.ATENA_GAIJI_FLG,
          CR_SHITEIJIYUIDO.ATENA_HOJINSOSHIKI_CD,
          CR_SHITEIJIYUIDO.ATENA_JE_KOKUHOSHISANWARI_KBN,
          CR_SHITEIJIYUIDO.ATENA_JE_JINTEKIGENMEN_KBN,
          CR_SHITEIJIYUIDO.ATENA_JE_SHOYUSHAKEISHONIN_KBN,
          CR_SHITEIJIYUIDO.ATENA_JE_LINK_KOJIN_NO,
          CR_SHITEIJIYUIDO.ATENA_JE_NAYOSE_NO,
          CR_SHITEIJIYUIDO.ATENA_YOBI1_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI2_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI3_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI4_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI5_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI1_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI2_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI3_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI4_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI5_CH,
          I_SYSDATE2,
          I_SYSTIME2,
          i_NTANMATSU_NO,
          CR_SHITEIJIYUIDO.ALP_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.ALP_SHIMEI_KANJI,
          CR_SHITEIJIYUIDO.GAI_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.GAI_SHIMEI_KANJI,
          CR_SHITEIJIYUIDO.TSUSHOMEI_KANA,
          CR_SHITEIJIYUIDO.TSUSHOMEI_KANJI,
          CR_SHITEIJIYUIDO.HEIKIMEI_KANA,
          CR_SHITEIJIYUIDO.HEIKIMEI_KANJI,
          CR_SHITEIJIYUIDO.GAIKOKU_JUMIN_NARU,
          CR_SHITEIJIYUIDO.ZAIRYU_NO_SHUBETSU,
          CR_SHITEIJIYUIDO.ZAIRYU_CARD_NO,
          CR_SHITEIJIYUIDO.ZAIRYU_SHIKAKU_CD,
          CR_SHITEIJIYUIDO.ZAIRYU_SHURYO_BI,
          CR_SHITEIJIYUIDO.ZAIRYU_KIKAN_NEN,
          CR_SHITEIJIYUIDO.ZAIRYU_KIKAN_TSUKI,
          CR_SHITEIJIYUIDO.ZAIRYU_KIKAN_HI,
          CR_SHITEIJIYUIDO.CARD_MANRYO_BI,
          CR_SHITEIJIYUIDO.KBN_30_45,
          CR_SHITEIJIYUIDO.KYOJYUCHI_UMU,
          CR_SHITEIJIYUIDO.SEINENGAPI_FUSHO_KBN,
          CR_SHITEIJIYUIDO.RYOKEN_BANGO,
          CR_SHITEIJIYUIDO.RYOKEN_HAKKO_BI,
          CR_SHITEIJIYUIDO.JORIKU_KYOKA_BI,
          CR_SHITEIJIYUIDO.JUMIN_NUSHI_SHIMEI,
          CR_SHITEIJIYUIDO.NUSHI_KBN

         ,CR_SHITEIJIYUIDO.ATENA_TOUGOU_NO
         ,CR_SHITEIJIYUIDO.SEIDO_KOJIN_NO
         ,CR_SHITEIJIYUIDO.ATENA_SEIDO_HOJIN_NO
         ,CR_SHITEIJIYUIDO.KYUUJI_KANA
         ,CR_SHITEIJIYUIDO.KYUUJI_KANJI
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
         ,CR_SHITEIJIYUIDO.ATENA_KETAPRM                                 --住所_桁取パラメータ（基本データリスト用項目）
         ,CR_SHITEIJIYUIDO.ATENA_KOKUMEI_CD                              --住所_国名コード（住登外者宛名番号管理の基本データリスト用項目）
         ,VCHOSHACODE                                                     --入力場所
         ,CR_SHITEIJIYUIDO.SHIMEI_KANA_FLG                            --氏名カナフラグ
         ,CR_SHITEIJIYUIDO.TSUSHO_KANA_FLG                            --通称カナフラグ
         ,CR_SHITEIJIYUIDO.JH_KYUUJI_KANA_FLG                            --旧氏カナフラグ
         ,CR_SHITEIJIYUIDO.JIJITSUJONOSETAINUSHI_KANA                 --事実上の世帯主カナ
         ,CR_SHITEIJIYUIDO.JIJITSUJONOSETAINUSHI_KANJI                --事実上の世帯主漢字
         ,CR_SHITEIJIYUIDO.SAISYUTOROKUJUSHO_REN                      --最終登録住所地連番
         ,CR_SHITEIJIYUIDO.SAISEIKISAI_DATE                           --再製記載年月日
         ,CR_SHITEIJIYUIDO.SAISEIKISAIDATE_FUSHO_FLG                  --再製記載年月日不詳フラグ
         ,CR_SHITEIJIYUIDO.SAISEIKISAIDATE_FUSHO_HYOKI                --再製記載年月日不詳表記
         ,CR_SHITEIJIYUIDO.SAISEISHOJODATE                            --再製消除年月日
         ,CR_SHITEIJIYUIDO.SAISEISHOJODATE_FUSHO_FLG                  --再製消除年月日不詳フラグ
         ,CR_SHITEIJIYUIDO.SAISEISHOJODATE_FUSHO_HYOKI                --再製消除年月日不詳表記
         ,CR_SHITEIJIYUIDO.KBN_30_46_47                               --法第30条46又は47区分
         ,CR_SHITEIJIYUIDO.SEINENGAPI_FUSHO_HYOKI                     --生年月日不詳表記
         ,CR_SHITEIJIYUIDO.IDO_BI_FUSHO_FLG                           --異動日不詳フラグ
         ,CR_SHITEIJIYUIDO.IDO_BI_FUSHO_HYOKI                         --異動日不詳表記
         ,CR_SHITEIJIYUIDO.JUTEI_BI_FUSHO_FLG                         --住定日不詳フラグ
         ,CR_SHITEIJIYUIDO.JUTEI_BI_FUSHO_HYOKI                       --住定日不詳表記
         ,CR_SHITEIJIYUIDO.JUMIN_NARU_FUSHO_FLG                       --住民となる日不詳フラグ
         ,CR_SHITEIJIYUIDO.JUMIN_NARU_FUSHO_HYOKI                     --住民となる日不詳表記
         ,CR_SHITEIJIYUIDO.JUMIN_NAKUNARU_FUSHO_FLG                   --住民でなくなる日不詳フラグ
         ,CR_SHITEIJIYUIDO.JUMIN_NAKUNARU_FUSHO_HYOKI                 --住民でなくなる日不詳表記
         ,CR_SHITEIJIYUIDO.KAISEI_BI_FUSHO_FLG                        --改製日不詳フラグ
         ,CR_SHITEIJIYUIDO.KAISEI_BI_FUSHO_HYOKI                      --改製日不詳表記
         ,CR_SHITEIJIYUIDO.GAIKOKU_JUMIN_NARU_FUSHO_FLG               --外国人の住民となる日不詳フラグ
         ,CR_SHITEIJIYUIDO.GAIKOKU_JUMIN_NARU_FUSHO_HYOKI             --外国人の住民となる日不詳表記
         ,CR_SHITEIJIYUIDO.SEIBETSU_FUSHO_KBN                         --性別不詳区分
         ,CR_SHITEIJIYUIDO.IDO_JIYU_SHOSAI                            --異動事由詳細
         ,CR_SHITEIJIYUIDO.IDOKOMOKU_1                                --異動項目_1
         ,CR_SHITEIJIYUIDO.RYUIJIKO_1                                 --留意事項_1
         ,CR_SHITEIJIYUIDO.IDOKOMOKU_2                                --異動項目_2
         ,CR_SHITEIJIYUIDO.RYUIJIKO_2                                 --留意事項_2
         ,CR_SHITEIJIYUIDO.IDOKOMOKU_3                                --異動項目_3
         ,CR_SHITEIJIYUIDO.RYUIJIKO_3                                 --留意事項_3
         ,CR_SHITEIJIYUIDO.RIREKI_SENTAKUFUKA_FLG                     --履歴選択不可フラグ
         ,CR_SHITEIJIYUIDO.TODOKEDE_NO                                --届出番号
         ,CR_SHITEIJIYUIDO.TORIKESHI_TODOKEDE_NO                      --取消届出番号
--2024/01/25 DIS.liuqimeng Add end

        );
        ----更新前の内容を宛名異動累積ワークテーブル（GABWRUISEKIKIHON）に書込む
        INSERT INTO GABWRUISEKIKIHON VALUES
        ( 'B',
          CR_SHITEIJIYUIDO.ATENA_KOJIN_NO,
          CR_SHITEIJIYUIDO.ATENA_RIREKI_RENBAN,
          CR_SHITEIJIYUIDO.ATENA_TEKIYO_BI,
          CR_SHITEIJIYUIDO.ATENA_TOROKU_GYOMU,
          CR_SHITEIJIYUIDO.ATENA_JUMINHYO_CD,
          CR_SHITEIJIYUIDO.ATENA_SETAI_NO,
          CR_SHITEIJIYUIDO.ATENA_GENZON_KBN,
          CR_SHITEIJIYUIDO.ATENA_JINKAKU_KBN,
          CR_SHITEIJIYUIDO.ATENA_KOKUSEKI_CD,
          CR_SHITEIJIYUIDO.ATENA_SHISHO_CD,
          CR_SHITEIJIYUIDO.ATENA_CHIKU_CD,
          CR_SHITEIJIYUIDO.ATENA_GYOSEIKU_CD,
          CR_SHITEIJIYUIDO.ATENA_HAN_CD,
          CR_SHITEIJIYUIDO.ATENA_SHOGAKU_CD,
          CR_SHITEIJIYUIDO.ATENA_CHUGAKU_CD,
          CR_SHITEIJIYUIDO.ATENA_TOHYOKU_CD,
          CR_SHITEIJIYUIDO.ATENA_SANTEIDANTAI_CD,
          CR_SHITEIJIYUIDO.ATENA_SEINENGAPI,
          CR_SHITEIJIYUIDO.ATENA_WAREKI_SEINENGAPI,
          CR_SHITEIJIYUIDO.ATENA_HYOJI_SEINENGAPI,
          CR_SHITEIJIYUIDO.ATENA_SEIBETSU,
          CR_SHITEIJIYUIDO.ATENA_USER_CD,
          CR_SHITEIJIYUIDO.ATENA_OAZA_CD,
          CR_SHITEIJIYUIDO.ATENA_HONBAN,
          CR_SHITEIJIYUIDO.ATENA_EDABAN1,
          CR_SHITEIJIYUIDO.ATENA_EDABAN2,
          CR_SHITEIJIYUIDO.ATENA_EDABAN3,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI_CD,
          CR_SHITEIJIYUIDO.ATENA_GAIKU,
          CR_SHITEIJIYUIDO.ATENA_TOU,
          CR_SHITEIJIYUIDO.ATENA_GOU,
          CR_SHITEIJIYUIDO.ATENA_JICHI_CD,
          CR_SHITEIJIYUIDO.ATENA_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.ATENA_SHIMEI_KANJI,
          CR_SHITEIJIYUIDO.ATENA_HONMYO_KANA,
          CR_SHITEIJIYUIDO.ATENA_HONMYO_KANJI,
          CR_SHITEIJIYUIDO.ATENA_YUBIN_NO,
          CR_SHITEIJIYUIDO.ATENA_YUBIN_NOBC,
          CR_SHITEIJIYUIDO.ATENA_CHOMEI,
          CR_SHITEIJIYUIDO.ATENA_BANCHI,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI,
          CR_SHITEIJIYUIDO.ATENA_DAIHYO_KATAGAKI,
          CR_SHITEIJIYUIDO.ATENA_DAIHYO_SHIMEI,
          CR_SHITEIJIYUIDO.ATENA_TEL_NO,
          CR_SHITEIJIYUIDO.ATENA_TEL_KBN,
          CR_SHITEIJIYUIDO.ATENA_FAX_NO,
          CR_SHITEIJIYUIDO.ATENA_MAIL_ADS,
          CR_SHITEIJIYUIDO.ATENA_YUHEN_KBN,
          CR_SHITEIJIYUIDO.ATENA_TOROKU_JIYU,
          CR_SHITEIJIYUIDO.ATENA_JUFUKU_KOJIN_NO,
          CR_SHITEIJIYUIDO.ATENA_SYS_SAKUSEIBI,
          CR_SHITEIJIYUIDO.ATENA_SYS_KOSHINBI,
          CR_SHITEIJIYUIDO.ATENA_SYS_JIKAN,
          CR_SHITEIJIYUIDO.ATENA_SYS_SHOKUINKOJIN_NO,
          CR_SHITEIJIYUIDO.ATENA_SYS_TANMATSU_NO,
          CR_SHITEIJIYUIDO.ATENA_CHOMEI_KANA,
          CR_SHITEIJIYUIDO.ATENA_BANCHI_KANA,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI_KANA,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI_HIDE_FLG,
          CR_SHITEIJIYUIDO.ATENA_GAIJI_FLG,
          CR_SHITEIJIYUIDO.ATENA_HOJINSOSHIKI_CD,
          CR_SHITEIJIYUIDO.ATENA_JE_KOKUHOSHISANWARI_KBN,
          CR_SHITEIJIYUIDO.ATENA_JE_JINTEKIGENMEN_KBN,
          CR_SHITEIJIYUIDO.ATENA_JE_SHOYUSHAKEISHONIN_KBN,
          CR_SHITEIJIYUIDO.ATENA_JE_LINK_KOJIN_NO,
          CR_SHITEIJIYUIDO.ATENA_JE_NAYOSE_NO,
          CR_SHITEIJIYUIDO.ATENA_YOBI1_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI2_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI3_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI4_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI5_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI1_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI2_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI3_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI4_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI5_CH,
          I_SYSDATE2,
          I_SYSTIME2,
          i_NTANMATSU_NO

         ,CR_SHITEIJIYUIDO.ATENA_TOUGOU_NO
         ,CR_SHITEIJIYUIDO.ATENA_SEIDO_KOJIN_NO
         ,CR_SHITEIJIYUIDO.ATENA_SEIDO_HOJIN_NO
         ,CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD1
         ,CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD2
         ,CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD3
         ,CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD4
         ,CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_KBN
         ,CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_MEI
         ,CR_SHITEIJIYUIDO.ATENA_JITSU_ZOKUGARA_MEI
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
         ,0    --異動事由
         ,0    --異動届出日
         ,NULL --アルファベット氏名漢字
         ,NULL --外国人氏名漢字
         ,NULL --旧氏名カナ
         ,NULL --旧氏名漢字
         ,NULL --通称名カナ
         ,NULL --通称名漢字
         ,0    --通称カナ確認状況
         ,0    --生年月日不詳区分
         ,NULL --生年月日不詳表記
         ,0    --住登外死亡年月日
         ,0    --在留番号種別
         ,NULL --在留カード番号
         ,0    --在留資格コード
         ,0    --在留期間終了年月日
         ,0    --在留期間年
         ,0    --在留期間月
         ,0    --在留期間日
         ,0    --統合宛名フラグ
         ,0    --他業務参照不可フラグ
         ,0    --独自施策システム等ID
         ,0    --業務ID
         ,0    --本支店区分
         ,0    --前後区分
         ,0    --法人番号公表の同意
         ,0    --法人種別
         ,0    --閉鎖等年月日
         ,NULL --法人担当部署
         ,NULL --代表者カナ
         ,NULL --世帯主氏名漢字
         ,0    --国名コード
         ,NULL --桁パラメータ
--2024/01/25 DIS.liuqimeng Add end
--2024/03/26 DIS.liuqimeng Add start 0.3.000.000:受入検証指摘対応
         ,0    --法人管理番号
         ,0    --設立年月日
         ,0    --閉鎖等事由
         ,NULL    --屋号
--2024/03/26 DIS.liuqimeng Add end

        );
        ----異動累計用に更新前の内容を取得する
        N_IDO_ZEN_JINKAKU_KBN := CR_SHITEIJIYUIDO.JINKAKU_KBN;     --異動前人格区分
        N_IDO_ZEN_GENZON_KBN := CR_SHITEIJIYUIDO.GENZON_KBN;       --異動前現存区分
        N_IDO_ZEN_NUSHI_KBN := CR_SHITEIJIYUIDO.NUSHI_KBN;         --異動前世帯主区分
        N_IDO_ZEN_OAZA_CD := CR_SHITEIJIYUIDO.ATENA_OAZA_CD;       --異動前大字コード
        N_IDO_ZEN_GYOSEIKU_CD := CR_SHITEIJIYUIDO.GYOSEIKU_CD;     --異動前行政区コード
        N_IDO_ZEN_CHIKU_CD := CR_SHITEIJIYUIDO.CHIKU_CD;           --異動前地区コード
        ----カーソルの内容を宛名履歴に書込む
        INSERT INTO JIBTJUKIRIREKI VALUES
        ( CR_SHITEIJIYUIDO.ATENA_KOJIN_NO,
          CR_SHITEIJIYUIDO.ATENA_RIREKI_RENBAN,
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
          CR_SHITEIJIYUIDO.ATENA_RIREKI_EDABAN,    --履歴枝番
          CR_SHITEIJIYUIDO.ATENA_SAISHIN_FLG,      --最新フラグ
          CR_SHITEIJIYUIDO.ATENA_TORIKESHI_FLG,    --取消フラグ
          CR_SHITEIJIYUIDO.ATENA_JOHYOYODATA_FLG,  --除票用データフラグ
--2024/01/25 DIS.liuqimeng Add end
          CR_SHITEIJIYUIDO.ATENA_TEKIYO_BI,
          CR_SHITEIJIYUIDO.ATENA_TOROKU_GYOMU,
          CR_SHITEIJIYUIDO.ATENA_SETAI_NO,
          CR_SHITEIJIYUIDO.ATENA_GENZON_KBN,
          NVL(CR_SHITEIJIYUIDO.JUN_SETAI_KBN, 0),
          CR_SHITEIJIYUIDO.ATENA_JINKAKU_KBN,
          CR_SHITEIJIYUIDO.ATENA_KOKUSEKI_CD,
          CR_SHITEIJIYUIDO.ATENA_SHISHO_CD,
          CR_SHITEIJIYUIDO.ATENA_CHIKU_CD,
          CR_SHITEIJIYUIDO.ATENA_GYOSEIKU_CD,
          CR_SHITEIJIYUIDO.ATENA_HAN_CD,
          CR_SHITEIJIYUIDO.ATENA_SHOGAKU_CD,
          CR_SHITEIJIYUIDO.ATENA_CHUGAKU_CD,
          CR_SHITEIJIYUIDO.ATENA_TOHYOKU_CD,
          CR_SHITEIJIYUIDO.ATENA_SANTEIDANTAI_CD,
          CR_SHITEIJIYUIDO.ATENA_SEINENGAPI,
          CR_SHITEIJIYUIDO.ATENA_WAREKI_SEINENGAPI,
          CR_SHITEIJIYUIDO.ATENA_HYOJI_SEINENGAPI,
          CR_SHITEIJIYUIDO.ATENA_SEIBETSU,
          CR_SHITEIJIYUIDO.ATENA_USER_CD,
          CR_SHITEIJIYUIDO.ATENA_OAZA_CD,
          CR_SHITEIJIYUIDO.ATENA_HONBAN,
          CR_SHITEIJIYUIDO.ATENA_EDABAN1,
          CR_SHITEIJIYUIDO.ATENA_EDABAN2,
          CR_SHITEIJIYUIDO.ATENA_EDABAN3,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI_CD,
          CR_SHITEIJIYUIDO.ATENA_GAIKU,
          CR_SHITEIJIYUIDO.ATENA_TOU,
          CR_SHITEIJIYUIDO.ATENA_GOU,
          CR_SHITEIJIYUIDO.ATENA_JICHI_CD,
          CR_SHITEIJIYUIDO.ATENA_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.ATENA_SHIMEI_KANJI,
          CR_SHITEIJIYUIDO.ATENA_YUBIN_NO,
          CR_SHITEIJIYUIDO.ATENA_YUBIN_NOBC,
          CR_SHITEIJIYUIDO.ATENA_CHOMEI,
          CR_SHITEIJIYUIDO.ATENA_BANCHI,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI,
          CR_SHITEIJIYUIDO.ATENA_DAIHYO_KATAGAKI,
          CR_SHITEIJIYUIDO.ATENA_DAIHYO_SHIMEI,
          CR_SHITEIJIYUIDO.ATENA_TEL_NO,
          CR_SHITEIJIYUIDO.ATENA_TEL_KBN,
          CR_SHITEIJIYUIDO.ATENA_FAX_NO,
          CR_SHITEIJIYUIDO.ATENA_MAIL_ADS,
          CR_SHITEIJIYUIDO.ATENA_YUHEN_KBN,
          CR_SHITEIJIYUIDO.ATENA_TOROKU_JIYU,
          NVL(CR_SHITEIJIYUIDO.JUMINHYO_CD, 0),
          NVL(CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD1, 0),
          NVL(CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD2, 0),
          NVL(CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD3, 0),
          NVL(CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_CD4, 0),
          NVL(CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_KBN, 0),
          CR_SHITEIJIYUIDO.ATENA_ZOKUGARA_MEI,
          CR_SHITEIJIYUIDO.ATENA_JITSU_ZOKUGARA_MEI,
          NVL(CR_SHITEIJIYUIDO.KISAI_JUNI, 0),
          NVL(CR_SHITEIJIYUIDO.IDO_BI, 0),
          NVL(CR_SHITEIJIYUIDO.IDO_JIYU, 0),
          NVL(CR_SHITEIJIYUIDO.IDO_TODOKE_BI, 0),
          NVL(CR_SHITEIJIYUIDO.IDO_TODOKE_KBN, 0),
          NVL(CR_SHITEIJIYUIDO.JUTEI_BI, 0),
          NVL(CR_SHITEIJIYUIDO.JUTEI_JIYU, 0),
          NVL(CR_SHITEIJIYUIDO.JUTEI_TODOKEDE_BI, 0),
          NVL(CR_SHITEIJIYUIDO.JUTEI_TODOKEDE_KBN, 0),
          NVL(CR_SHITEIJIYUIDO.GENJUSHO_REN, 0),
          NVL(CR_SHITEIJIYUIDO.ZENJUSHO_REN, 0),
          NVL(CR_SHITEIJIYUIDO.TENNYUMAE_REN, 0),
          NVL(CR_SHITEIJIYUIDO.TENNYU_MITODOKE_REN, 0),
          NVL(CR_SHITEIJIYUIDO.HONSEKI_REN, 0),
          NVL(CR_SHITEIJIYUIDO.TENSHUTSU_YOTEI_BI, 0),
          NVL(CR_SHITEIJIYUIDO.TENSHUTSU_YOTEI_TODOKEDE_BI, 0),
          NVL(CR_SHITEIJIYUIDO.TENSHUTSU_YOTEI_TODOKEDE_KBN, 0),
          NVL(CR_SHITEIJIYUIDO.TENSHUTSU_YOTEI_REN, 0),
          NVL(CR_SHITEIJIYUIDO.TENSHUTSU_KAKUTEI_BI, 0),
          NVL(CR_SHITEIJIYUIDO.TENSHUTSU_KAKUTEI_TSUCHI_BI, 0),
          NVL(CR_SHITEIJIYUIDO.TENSHUTSU_KAKUTEI_TODOKEDE_KBN, 0),
          NVL(CR_SHITEIJIYUIDO.TENSHUTSU_KAKUTEI_REN, 0),
          NVL(CR_SHITEIJIYUIDO.JUMIN_NARU, 0),
          NVL(CR_SHITEIJIYUIDO.JUMIN_NARU_JIYU, 0),
          NVL(CR_SHITEIJIYUIDO.JUMIN_NARU_TODOKEDE_BI, 0),
          NVL(CR_SHITEIJIYUIDO.JUMIN_NARU_TODOKEDE_KBN, 0),
          NVL(CR_SHITEIJIYUIDO.JUMIN_NAKUNARU, 0),
          NVL(CR_SHITEIJIYUIDO.JUMIN_NAKUNARU_JIYU, 0),
          NVL(CR_SHITEIJIYUIDO.JUMIN_NAKUNARU_TODOKEDE_BI, 0),
          NVL(CR_SHITEIJIYUIDO.JUMIN_NAKUNARU_TODOKEDE_KBN, 0),
          NVL(CR_SHITEIJIYUIDO.SHIBOBI_FUSHO_KBN, 0),
          CR_SHITEIJIYUIDO.ATENA_HONMYO_KANA,
          CR_SHITEIJIYUIDO.ATENA_HONMYO_KANJI,
          CR_SHITEIJIYUIDO.NUSHI_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.NUSHI_SHIMEI_KANJI,
          CR_SHITEIJIYUIDO.BIKO,
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--          NVL(CR_SHITEIJIYUIDO.KAISEI_BI, 0),
--          NVL(CR_SHITEIJIYUIDO.KAISEI_REN, 0),
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
          --CASE
            --  WHEN CR_SHITEIJIYUIDO.IDO_JIYU IN (191,291) THEN i_SHORIBI
             -- ELSE NVL(CR_SHITEIJIYUIDO.KAISEI_BI, 0)
         -- END,
          --CASE
             -- WHEN CR_SHITEIJIYUIDO.IDO_JIYU IN (191,291) THEN CR_SHITEIJIYUIDO.KAISEI_REN + 1
             -- ELSE NVL(CR_SHITEIJIYUIDO.KAISEI_REN, 0)
          --END,
          NVL(CR_SHITEIJIYUIDO.KAISEI_BI, 0),
          NVL(CR_SHITEIJIYUIDO.KAISEI_REN, 0),
--2025/5/14 CTC.liu update end
--2024/01/25 DIS.liuqimeng Update end
          CR_SHITEIJIYUIDO.KYU_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.KYU_SHIMEI_KANJI,
          NVL(CR_SHITEIJIYUIDO.SHORIBI_KEY, 0),
          NVL(CR_SHITEIJIYUIDO.SHORI_JIKAN_KEY, 0),
          NVL(CR_SHITEIJIYUIDO.SHORI_KBN_KEY, 0),
          NVL(CR_SHITEIJIYUIDO.ZENBU_ICHIBU_KEY, 0),
          NVL(CR_SHITEIJIYUIDO.SHOKUINKOJIN_NO_KEY, 0),
          CR_SHITEIJIYUIDO.ATENA_SYS_SAKUSEIBI,
          CR_SHITEIJIYUIDO.ATENA_SYS_KOSHINBI,
          CR_SHITEIJIYUIDO.ATENA_SYS_JIKAN,
          CR_SHITEIJIYUIDO.ATENA_SYS_SHOKUINKOJIN_NO,
          CR_SHITEIJIYUIDO.ATENA_SYS_TANMATSU_NO,
          CR_SHITEIJIYUIDO.GOMI_CD,
          CR_SHITEIJIYUIDO.SINYO_CD,
          CR_SHITEIJIYUIDO.KOIKIKOFU_STOP_CD,
          CR_SHITEIJIYUIDO.ATENA_CHOMEI_KANA,
          CR_SHITEIJIYUIDO.ATENA_BANCHI_KANA,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI_KANA,
          CR_SHITEIJIYUIDO.ATENA_KATAGAKI_HIDE_FLG,
          CR_SHITEIJIYUIDO.ATENA_GAIJI_FLG,
          CR_SHITEIJIYUIDO.ATENA_HOJINSOSHIKI_CD,
          CR_SHITEIJIYUIDO.ATENA_JE_KOKUHOSHISANWARI_KBN,
          CR_SHITEIJIYUIDO.ATENA_JE_JINTEKIGENMEN_KBN,
          CR_SHITEIJIYUIDO.ATENA_JE_SHOYUSHAKEISHONIN_KBN,
          CR_SHITEIJIYUIDO.ATENA_JE_LINK_KOJIN_NO,
          CR_SHITEIJIYUIDO.ATENA_JE_NAYOSE_NO,
          CR_SHITEIJIYUIDO.ATENA_YOBI1_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI2_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI3_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI4_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI5_CD,
          CR_SHITEIJIYUIDO.ATENA_YOBI1_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI2_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI3_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI4_CH,
          CR_SHITEIJIYUIDO.ATENA_YOBI5_CH,
          CR_SHITEIJIYUIDO.ALP_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.ALP_SHIMEI_KANJI,
          CR_SHITEIJIYUIDO.GAI_SHIMEI_KANA,
          CR_SHITEIJIYUIDO.GAI_SHIMEI_KANJI,
          CR_SHITEIJIYUIDO.TSUSHOMEI_KANA,
          CR_SHITEIJIYUIDO.TSUSHOMEI_KANJI,
          CR_SHITEIJIYUIDO.HEIKIMEI_KANA,
          CR_SHITEIJIYUIDO.HEIKIMEI_KANJI,
          CR_SHITEIJIYUIDO.GAIKOKU_JUMIN_NARU,
          CR_SHITEIJIYUIDO.ZAIRYU_NO_SHUBETSU,
          CR_SHITEIJIYUIDO.ZAIRYU_CARD_NO,
          CR_SHITEIJIYUIDO.ZAIRYU_SHIKAKU_CD,
          CR_SHITEIJIYUIDO.ZAIRYU_SHURYO_BI,
          CR_SHITEIJIYUIDO.ZAIRYU_KIKAN_NEN,
          CR_SHITEIJIYUIDO.ZAIRYU_KIKAN_TSUKI,
          CR_SHITEIJIYUIDO.ZAIRYU_KIKAN_HI,
          CR_SHITEIJIYUIDO.CARD_MANRYO_BI,
          CR_SHITEIJIYUIDO.KBN_30_45,
          CR_SHITEIJIYUIDO.KYOJYUCHI_UMU,
          CR_SHITEIJIYUIDO.SEINENGAPI_FUSHO_KBN,
          CR_SHITEIJIYUIDO.RYOKEN_BANGO,
          CR_SHITEIJIYUIDO.RYOKEN_HAKKO_BI,
          CR_SHITEIJIYUIDO.JORIKU_KYOKA_BI,
          CR_SHITEIJIYUIDO.JUMIN_NUSHI_SHIMEI

         ,CR_SHITEIJIYUIDO.ATENA_TOUGOU_NO
         ,CR_SHITEIJIYUIDO.SEIDO_KOJIN_NO
         ,CR_SHITEIJIYUIDO.ATENA_SEIDO_HOJIN_NO
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
          ,CR_SHITEIJIYUIDO.ATENA_KETAPRM                                 --住所_桁取パラメータ（基本データリスト用項目）
          ,CR_SHITEIJIYUIDO.ATENA_KOKUMEI_CD                              --住所_国名コード（住登外者宛名番号管理の基本データリスト用項目）
          ,VCHOSHACODE                                                     --入力場所
          ,CR_SHITEIJIYUIDO.SHIMEI_KANA_FLG                            --氏名カナフラグ
          ,CR_SHITEIJIYUIDO.TSUSHO_KANA_FLG                            --通称カナフラグ
          ,CR_SHITEIJIYUIDO.JIJITSUJONOSETAINUSHI_KANA                 --事実上の世帯主カナ
          ,CR_SHITEIJIYUIDO.JIJITSUJONOSETAINUSHI_KANJI                --事実上の世帯主漢字
          ,CR_SHITEIJIYUIDO.SAISYUTOROKUJUSHO_REN                      --最終登録住所地連番
          ,CR_SHITEIJIYUIDO.SAISEIKISAI_DATE                           --再製記載年月日
          ,CR_SHITEIJIYUIDO.SAISEIKISAIDATE_FUSHO_FLG                  --再製記載年月日不詳フラグ
          ,CR_SHITEIJIYUIDO.SAISEIKISAIDATE_FUSHO_HYOKI                --再製記載年月日不詳表記
          ,CR_SHITEIJIYUIDO.SAISEISHOJODATE                            --再製消除年月日
          ,CR_SHITEIJIYUIDO.SAISEISHOJODATE_FUSHO_FLG                  --再製消除年月日不詳フラグ
          ,CR_SHITEIJIYUIDO.SAISEISHOJODATE_FUSHO_HYOKI                --再製消除年月日不詳表記
          ,CR_SHITEIJIYUIDO.KBN_30_46_47                               --法第30条46又は47区分
          ,CR_SHITEIJIYUIDO.SEINENGAPI_FUSHO_HYOKI                     --生年月日不詳表記
          ,CR_SHITEIJIYUIDO.IDO_BI_FUSHO_FLG                           --異動日不詳フラグ
          ,CR_SHITEIJIYUIDO.IDO_BI_FUSHO_HYOKI                         --異動日不詳表記
          ,CR_SHITEIJIYUIDO.JUTEI_BI_FUSHO_FLG                         --住定日不詳フラグ
          ,CR_SHITEIJIYUIDO.JUTEI_BI_FUSHO_HYOKI                       --住定日不詳表記
          ,CR_SHITEIJIYUIDO.JUMIN_NARU_FUSHO_FLG                       --住民となる日不詳フラグ
          ,CR_SHITEIJIYUIDO.JUMIN_NARU_FUSHO_HYOKI                     --住民となる日不詳表記
          ,CR_SHITEIJIYUIDO.JUMIN_NAKUNARU_FUSHO_FLG                   --住民でなくなる日不詳フラグ
          ,CR_SHITEIJIYUIDO.JUMIN_NAKUNARU_FUSHO_HYOKI                 --住民でなくなる日不詳表記
          ,CR_SHITEIJIYUIDO.KAISEI_BI_FUSHO_FLG                        --改製日不詳フラグ
          ,CR_SHITEIJIYUIDO.KAISEI_BI_FUSHO_HYOKI                      --改製日不詳表記
          ,CR_SHITEIJIYUIDO.GAIKOKU_JUMIN_NARU_FUSHO_FLG               --外国人の住民となる日不詳フラグ
          ,CR_SHITEIJIYUIDO.GAIKOKU_JUMIN_NARU_FUSHO_HYOKI             --外国人の住民となる日不詳表記
          ,CR_SHITEIJIYUIDO.SEIBETSU_FUSHO_KBN                         --性別不詳区分
          ,CR_SHITEIJIYUIDO.IDO_JIYU_SHOSAI                            --異動事由詳細
          ,CR_SHITEIJIYUIDO.IDOKOMOKU_1                                --異動項目_1
          ,CR_SHITEIJIYUIDO.RYUIJIKO_1                                 --留意事項_1
          ,CR_SHITEIJIYUIDO.IDOKOMOKU_2                                --異動項目_2
          ,CR_SHITEIJIYUIDO.RYUIJIKO_2                                 --留意事項_2
          ,CR_SHITEIJIYUIDO.IDOKOMOKU_3                                --異動項目_3
          ,CR_SHITEIJIYUIDO.RYUIJIKO_3                                 --留意事項_3
          ,CR_SHITEIJIYUIDO.RIREKI_SENTAKUFUKA_FLG                     --履歴選択不可フラグ
          ,CR_SHITEIJIYUIDO.TODOKEDE_NO                                --届出番号
          ,CR_SHITEIJIYUIDO.TORIKESHI_TODOKEDE_NO                      --取消届出番号
--2024/01/25 DIS.liuqimeng Add end

        );
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--        SELECT RIREKI_RENBAN,TEKIYO_BI
--          INTO R_BUPD_ATENA.RIREKI_RENBAN,R_BUPD_ATENA.TEKIYO_BI
        SELECT RIREKI_RENBAN,TEKIYO_BI,RIREKI_EDABAN,SAISHIN_FLG
          INTO R_BUPD_ATENA.RIREKI_RENBAN,R_BUPD_ATENA.TEKIYO_BI,R_BUPD_ATENA.RIREKI_EDABAN,R_BUPD_ATENA.SAISHIN_FLG
--2024/01/25 DIS.liuqimeng Update end
          FROM JIBWBUPD_JUKIKIHON
         WHERE ENTRY_ID = i_IENTRY_ID
           AND KOJIN_NO = CR_SHITEIJIYUIDO.KOJIN_NO;
        --宛名基本を更新する
        UPDATE JIBTJUKIKIHON
           SET RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN,
               TEKIYO_BI = R_BUPD_ATENA.TEKIYO_BI,
               GENZON_KBN = 1,
               SYS_SAKUSEIBI = i_SHORIBI,
               SYS_KOSHINBI = 0,
               SYS_JIKAN = I_SYSTIME2,
               SYS_SHOKUINKOJIN_NO = i_NSHOKUIN,
               SYS_TANMATSU_NO = i_NTANMATSU_NO
         WHERE KOJIN_NO = CR_SHITEIJIYUIDO.KOJIN_NO;
        REBT_JUKIJOHO.KOJIN_NO := CR_SHITEIJIYUIDO.KOJIN_NO;  --宛名番号
        REBT_JUKIJOHO.RIREKI_RENBAN := R_BUPD_ATENA.RIREKI_RENBAN;  --履歴連番
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
        REBT_JUKIJOHO.RIREKI_EDABAN   := R_BUPD_ATENA.RIREKI_EDABAN;         --履歴枝番
        REBT_JUKIJOHO.SAISHIN_FLG     := R_BUPD_ATENA.SAISHIN_FLG;           --最新フラグ(0:最新でない 1:最新)
        REBT_JUKIJOHO.KYUUJI_KANA_FLG := CR_SHITEIJIYUIDO.JH_KYUUJI_KANA_FLG;--旧氏カナフラグ
--2024/01/25 DIS.liuqimeng Add end
        REBT_JUKIJOHO.KYUUJI_KANA := CR_SHITEIJIYUIDO.KYUUJI_KANA;   --旧氏かな
        REBT_JUKIJOHO.KYUUJI_KANJI := CR_SHITEIJIYUIDO.KYUUJI_KANJI;   --旧氏漢字
        REBT_JUKIJOHO.SYS_SAKUSEIBI := i_SHORIBI;   --作成日
        REBT_JUKIJOHO.SYS_KOSHINBI := 0;            --更新日
        REBT_JUKIJOHO.SYS_JIKAN := I_SYSTIME2;      --更新時間
        REBT_JUKIJOHO.SYS_SHOKUINKOJIN_NO := i_NSHOKUIN;    --更新職員宛名番号
        REBT_JUKIJOHO.SYS_TANMATSU_NO := i_NTANMATSU_NO;    --更新端末番号
        --住基情報に登録する
        INSERT INTO JIBTJUKIJOHO VALUES REBT_JUKIJOHO;
        SELECT IDO_BI,
               IDO_JIYU,
               IDO_TODOKE_BI,
               IDO_TODOKE_KBN,
               SHORI_KBN_KEY,
               ZENBU_ICHIBU_KEY
          INTO R_BUPD_JUKIIDO.IDO_BI,
               R_BUPD_JUKIIDO.IDO_JIYU,
               R_BUPD_JUKIIDO.IDO_TODOKE_BI,
               R_BUPD_JUKIIDO.IDO_TODOKE_KBN,
               R_BUPD_JUKIIDO.SHORI_KBN_KEY,
               R_BUPD_JUKIIDO.ZENBU_ICHIBU_KEY
          FROM JIBWBUPD_JUKIIDO
         WHERE ENTRY_ID = i_IENTRY_ID
           AND KOJIN_NO = CR_SHITEIJIYUIDO.KOJIN_NO;
        --住基異動を更新する。
        IF R_BUPD_JUKIIDO.IDO_TODOKE_KBN = 1 THEN
          V_IDO_TODOKE_KBN_MEI := '届出';
        ELSIF R_BUPD_JUKIIDO.IDO_TODOKE_KBN = 2 THEN
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--          V_IDO_TODOKE_KBN_MEI := '通知';
          V_IDO_TODOKE_KBN_MEI := '職権';
        ELSIF R_BUPD_JUKIIDO.IDO_TODOKE_KBN = 3 THEN
          V_IDO_TODOKE_KBN_MEI := '申出';
        ELSIF R_BUPD_JUKIIDO.IDO_TODOKE_KBN = 4 THEN
          V_IDO_TODOKE_KBN_MEI := '請求';
        ELSE
          NULL;
--2024/01/25 DIS.liuqimeng Update end
        END IF;
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--        IF R_BUPD_JUKIIDO.IDO_JIYU = 15 THEN
--          N_IDO_JIYU := 26;
--          N_JUMIN_NAKUNARU_JIYU := 26;
--          N_SHORI_KBN_KEY := 26;
        IF R_BUPD_JUKIIDO.IDO_JIYU = 150 THEN
          N_IDO_JIYU := 260;
          N_JUMIN_NAKUNARU_JIYU := 260;
          N_SHORI_KBN_KEY := 260;
--2024/01/25 DIS.liuqimeng Update end
          IF NBIKOJKN = 1 THEN
            V_BIKO := KKAPK0010.FMULTIBYTEHENKAN(FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_BI) || '帰化　' || FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_TODOKE_BI) || V_IDO_TODOKE_KBN_MEI || 'により消除',1);
          ELSE
            V_BIKO := FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_BI) || '帰化　' || FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_TODOKE_BI) || V_IDO_TODOKE_KBN_MEI || 'により消除';
          END IF;
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--        ELSIF R_BUPD_JUKIIDO.IDO_JIYU = 16 THEN
--          N_IDO_JIYU := 27;
--          N_JUMIN_NAKUNARU_JIYU := 27;
--          N_SHORI_KBN_KEY := 27;
        ELSIF R_BUPD_JUKIIDO.IDO_JIYU = 160 THEN
          N_IDO_JIYU := 270;
          N_JUMIN_NAKUNARU_JIYU := 270;
          N_SHORI_KBN_KEY := 270;
--2024/01/25 DIS.liuqimeng Update end
          IF NBIKOJKN = 1 THEN
            V_BIKO := KKAPK0010.FMULTIBYTEHENKAN(FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_BI) || '国籍取得　' || FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_TODOKE_BI) || V_IDO_TODOKE_KBN_MEI || 'により消除',1);
          ELSE
            V_BIKO := FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_BI) || '国籍取得　' || FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_TODOKE_BI) || V_IDO_TODOKE_KBN_MEI || 'により消除';
          END IF;
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--       ELSIF R_BUPD_JUKIIDO.IDO_JIYU = 28 THEN
--          N_IDO_JIYU := 24;
--          N_JUMIN_NAKUNARU_JIYU := 24;
--          N_SHORI_KBN_KEY := 24;
       ELSIF R_BUPD_JUKIIDO.IDO_JIYU = 280 THEN
          N_IDO_JIYU := 240;
          N_JUMIN_NAKUNARU_JIYU := 240;
          N_SHORI_KBN_KEY := 240;
--2024/01/25 DIS.liuqimeng Update end

          IF NBIKOJKN = 1 THEN
            V_BIKO := KKAPK0010.FMULTIBYTEHENKAN(FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_BI) || '国籍喪失　' || FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_TODOKE_BI) || '戸籍' || V_IDO_TODOKE_KBN_MEI || 'により消除',1);

          ELSE
            V_BIKO := FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_BI) || '国籍喪失　' || FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_TODOKE_BI) || '戸籍' || V_IDO_TODOKE_KBN_MEI || 'により消除';
          END IF;
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
         ELSIF R_BUPD_JUKIIDO.IDO_JIYU = 191 THEN
         N_IDO_JIYU := 291;
          N_JUMIN_NAKUNARU_JIYU := 291;
          N_SHORI_KBN_KEY := 291;
        IF NBIKOJKN = 1 THEN
            V_BIKO := KKAPK0010.FMULTIBYTEHENKAN(FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_BI) || '改製　' || FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_TODOKE_BI) ||  V_IDO_TODOKE_KBN_MEI || 'により消除',1);
        ELSE
         V_BIKO := FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_BI) || '改製　' || FUNCDAYEDIT(R_BUPD_JUKIIDO.IDO_TODOKE_BI) ||  V_IDO_TODOKE_KBN_MEI || 'により消除';
        END IF;
--2025/5/14 CTC.liu update end
        END IF;
        UPDATE JIBTJUKIIDO
           SET GENZON_KBN = 1,
               IDO_BI = R_BUPD_JUKIIDO.IDO_BI,
               IDO_JIYU = N_IDO_JIYU,
               IDO_TODOKE_BI = R_BUPD_JUKIIDO.IDO_TODOKE_BI,
               IDO_TODOKE_KBN = R_BUPD_JUKIIDO.IDO_TODOKE_KBN,
               JUMIN_NAKUNARU = R_BUPD_JUKIIDO.IDO_BI,
               JUMIN_NAKUNARU_JIYU = N_JUMIN_NAKUNARU_JIYU,
               JUMIN_NAKUNARU_TODOKEDE_BI = R_BUPD_JUKIIDO.IDO_TODOKE_BI,
               JUMIN_NAKUNARU_TODOKEDE_KBN = R_BUPD_JUKIIDO.IDO_TODOKE_KBN,
               BIKO = V_BIKO,
               SHORIBI_KEY = I_SYSDATE2,
               SHORI_JIKAN_KEY = I_SYSTIME2,
               SHORI_KBN_KEY = N_SHORI_KBN_KEY,
               ZENBU_ICHIBU_KEY = R_BUPD_JUKIIDO.ZENBU_ICHIBU_KEY,
               SHOKUINKOJIN_NO_KEY = i_NSHOKUIN,
               SYS_SAKUSEIBI = i_SHORIBI,
               SYS_KOSHINBI = 0,
               SYS_JIKAN = I_SYSTIME2,
               SYS_SHOKUINKOJIN_NO = i_NSHOKUIN,
               SYS_TANMATSU_NO = i_NTANMATSU_NO
         WHERE KOJIN_NO = CR_SHITEIJIYUIDO.KOJIN_NO;
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--        IF i_IDO_JIYU IN (15,16) THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
        --IF i_IDO_JIYU IN (150,160) THEN
        IF i_IDO_JIYU IN (150,160,191) THEN
           FOR CR_TSUSHORIREKI IN C_TSUSHORIREKI(CR_SHITEIJIYUIDO.KOJIN_NO,CR_SHITEIJIYUIDO.ATENA_RIREKI_RENBAN) LOOP
            ----通称履歴に追加する
            INSERT INTO JIBTTSUSHORIREKI VALUES
            ( CR_SHITEIJIYUIDO.KOJIN_NO,
              CR_TSUSHORIREKI.RIREKI_RENBAN + 10,
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
              1,                        --履歴枝番
              CR_TSUSHORIREKI.RENBAN,
              CR_TSUSHORIREKI.TOROKU_BI,
              CR_TSUSHORIREKI.TOROKU_USER_CD,
              CR_TSUSHORIREKI.SAKUJO_BI,
              CR_TSUSHORIREKI.SAKUJO_USER_CD,
              CR_TSUSHORIREKI.TSUSHO_KANA,
              CR_TSUSHORIREKI.TSUSHO_KANJI,
              i_SHORIBI,
              0,
              I_SYSTIME2,
              i_NSHOKUIN,
              i_NTANMATSU_NO
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
             ,CR_TSUSHORIREKI.TSUSHO_KANA_FLG   --通称カナフラグ
            );
           END LOOP;
        END IF;
      --更新前の内容を住記異動累積ワークテーブル（JIBWIDORUISEKI）に書込む。
      VSQL := NULL;
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--      VSQL := 'INSERT INTO JIBWIDORUISEKI SELECT ''A'',B.KOJIN_NO,B.RIREKI_RENBAN,B.TEKIYO_BI,B.TOROKU_GYOMU,B.SETAI_NO,B.GENZON_KBN,
      VSQL := 'INSERT INTO JIBWIDORUISEKI SELECT ''A'',B.KOJIN_NO,B.RIREKI_RENBAN,B.RIREKI_EDABAN,B.SAISHIN_FLG,B.TORIKESHI_FLG,B.JOHYOYODATA_FLG,B.TEKIYO_BI,B.TOROKU_GYOMU,B.SETAI_NO,B.GENZON_KBN,
                      A.JUN_SETAI_KBN,B.JINKAKU_KBN,B.KOKUSEKI_CD,B.SHISHO_CD,B.CHIKU_CD,B.GYOSEIKU_CD,
                      B.HAN_CD,B.SHOGAKU_CD,B.CHUGAKU_CD,B.TOHYOKU_CD,B.SANTEIDANTAI_CD,B.SEINENGAPI,
                      B.WAREKI_SEINENGAPI,B.HYOJI_SEINENGAPI,B.SEIBETSU,B.USER_CD,B.OAZA_CD,B.HONBAN,
                      B.EDABAN1,B.EDABAN2,B.EDABAN3,B.KATAGAKI_CD,B.GAIKU,B.TOU,B.GOU,B.JICHI_CD,B.SHIMEI_KANA,
                      B.SHIMEI_KANJI,B.YUBIN_NO,B.YUBIN_NOBC,B.CHOMEI,B.BANCHI,B.KATAGAKI,B.DAIHYO_KATAGAKI,
                      B.DAIHYO_SHIMEI,B.TEL_NO,B.TEL_KBN,B.FAX_NO,B.MAIL_ADS,B.YUHEN_KBN,B.TOROKU_JIYU,A.JUMINHYO_CD,
                      A.ZOKUGARA_CD1,A.ZOKUGARA_CD2,A.ZOKUGARA_CD3,A.ZOKUGARA_CD4,A.ZOKUGARA_KBN,A.ZOKUGARA_MEI,
                      A.JITSU_ZOKUGARA_MEI,A.KISAI_JUNI,A.IDO_BI,A.IDO_JIYU,A.IDO_TODOKE_BI,A.IDO_TODOKE_KBN,A.JUTEI_BI,
                      A.JUTEI_JIYU,A.JUTEI_TODOKEDE_BI,A.JUTEI_TODOKEDE_KBN,A.GENJUSHO_REN,A.ZENJUSHO_REN,A.TENNYUMAE_REN,
                      A.TENNYU_MITODOKE_REN,A.HONSEKI_REN,
                      A.TENSHUTSU_YOTEI_BI,A.TENSHUTSU_YOTEI_TODOKEDE_BI,A.TENSHUTSU_YOTEI_TODOKEDE_KBN,A.TENSHUTSU_YOTEI_REN,
                      A.TENSHUTSU_KAKUTEI_BI,A.TENSHUTSU_KAKUTEI_TSUCHI_BI,A.TENSHUTSU_KAKUTEI_TODOKEDE_KBN,A.TENSHUTSU_KAKUTEI_REN,
                      A.JUMIN_NARU,A.JUMIN_NARU_JIYU,A.JUMIN_NARU_TODOKEDE_BI,A.JUMIN_NARU_TODOKEDE_KBN,A.JUMIN_NAKUNARU,
                      A.JUMIN_NAKUNARU_JIYU,A.JUMIN_NAKUNARU_TODOKEDE_BI,A.JUMIN_NAKUNARU_TODOKEDE_KBN,A.SHIBOBI_FUSHO_KBN,
                      B.HONMYO_KANA,B.HONMYO_KANJI,A.NUSHI_SHIMEI_KANA,A.NUSHI_SHIMEI_KANJI,A.BIKO,A.KAISEI_BI,A.KAISEI_REN,
                      A.KYU_SHIMEI_KANA,A.KYU_SHIMEI_KANJI,A.SHORIBI_KEY,A.SHORI_JIKAN_KEY,A.SHORI_KBN_KEY,A.ZENBU_ICHIBU_KEY,
                      A.SHOKUINKOJIN_NO_KEY,B.SYS_SAKUSEIBI,B.SYS_KOSHINBI,B.SYS_JIKAN,B.SYS_SHOKUINKOJIN_NO,B.SYS_TANMATSU_NO,
                      A.GOMI_CD,A.SINYO_CD,A.KOIKIKOFU_STOP_CD,B.CHOMEI_KANA,B.BANCHI_KANA,B.KATAGAKI_KANA,B.KATAGAKI_HIDE_FLG,
                      B.GAIJI_FLG,B.HOJINSOSHIKI_CD,B.JE_KOKUHOSHISANWARI_KBN,B.JE_JINTEKIGENMEN_KBN,B.JE_SHOYUSHAKEISHONIN_KBN,
                      B.JE_LINK_KOJIN_NO,B.JE_NAYOSE_NO,B.YOBI1_CD,B.YOBI2_CD,B.YOBI3_CD,B.YOBI4_CD,B.YOBI5_CD,B.YOBI1_CH,
                      B.YOBI2_CH,B.YOBI3_CH,B.YOBI4_CH,B.YOBI5_CH,' ||  I_SYSDATE2 || ',' || I_SYSTIME2 || ','''  || i_NTANMATSU_NO || ''''||
                      ',A.ALP_SHIMEI_KANA,A.ALP_SHIMEI_KANJI,A.GAI_SHIMEI_KANA,A.GAI_SHIMEI_KANJI,A.TSUSHOMEI_KANA,A.TSUSHOMEI_KANJI,
                      A.HEIKIMEI_KANA,A.HEIKIMEI_KANJI,A.GAIKOKU_JUMIN_NARU,A.ZAIRYU_NO_SHUBETSU,A.ZAIRYU_CARD_NO,A.ZAIRYU_SHIKAKU_CD,
                      A.ZAIRYU_SHURYO_BI,A.ZAIRYU_KIKAN_NEN,A.ZAIRYU_KIKAN_TSUKI,A.ZAIRYU_KIKAN_HI,A.CARD_MANRYO_BI,A.KBN_30_45,A.KYOJYUCHI_UMU,
                      A.SEINENGAPI_FUSHO_KBN,A.RYOKEN_BANGO,A.RYOKEN_HAKKO_BI,A.JORIKU_KYOKA_BI,A.JUMIN_NUSHI_SHIMEI,A.NUSHI_KBN '||
                      ',B.TOUGOU_NO, A.SEIDO_KOJIN_NO, B.SEIDO_HOJIN_NO ' ||
                      ' ,JH.KYUUJI_KANA, JH.KYUUJI_KANJI ' ||
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
                      ',B.KETAPRM, B.KOKUMEI_CD,' ||
                      '''' || VCHOSHACODE || '''' ||
                      ',A.SHIMEI_KANA_FLG,A.TSUSHO_KANA_FLG,JH.KYUUJI_KANA_FLG,A.JIJITSUJONOSETAINUSHI_KANA' ||
                      ',A.JIJITSUJONOSETAINUSHI_KANJI,A.SAISYUTOROKUJUSHO_REN,A.SAISEIKISAI_DATE,A.SAISEIKISAIDATE_FUSHO_FLG,A.SAISEIKISAIDATE_FUSHO_HYOKI'||
                      ',A.SAISEISHOJODATE,A.SAISEISHOJODATE_FUSHO_FLG,A.SAISEISHOJODATE_FUSHO_HYOKI,A.KBN_30_46_47,A.SEINENGAPI_FUSHO_HYOKI,A.IDO_BI_FUSHO_FLG'||
                      ',A.IDO_BI_FUSHO_HYOKI,A.JUTEI_BI_FUSHO_FLG,A.JUTEI_BI_FUSHO_HYOKI,A.JUMIN_NARU_FUSHO_FLG,A.JUMIN_NARU_FUSHO_HYOKI,A.JUMIN_NAKUNARU_FUSHO_FLG'||
                      ',A.JUMIN_NAKUNARU_FUSHO_HYOKI,A.KAISEI_BI_FUSHO_FLG,A.KAISEI_BI_FUSHO_HYOKI,A.GAIKOKU_JUMIN_NARU_FUSHO_FLG,A.GAIKOKU_JUMIN_NARU_FUSHO_HYOKI'||
                      ',A.SEIBETSU_FUSHO_KBN,A.IDO_JIYU_SHOSAI,A.IDOKOMOKU_1,A.RYUIJIKO_1,A.IDOKOMOKU_2,A.RYUIJIKO_2,A.IDOKOMOKU_3,A.RYUIJIKO_3' ||
                      ',A.RIREKI_SENTAKUFUKA_FLG ,A.TODOKEDE_NO ,A.TORIKESHI_TODOKEDE_NO ' ||
--2024/01/25 DIS.liuqimeng Add end
                      ' FROM JIBTJUKIIDO A,JIBTJUKIKIHON B,JIBTJUKIJOHO JH WHERE A.KOJIN_NO = ' || CR_SHITEIJIYUIDO.KOJIN_NO || ' AND B.KOJIN_NO = ' || CR_SHITEIJIYUIDO.KOJIN_NO ||
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--                                                                            ' AND B.KOJIN_NO = JH.KOJIN_NO(+) AND B.RIREKI_RENBAN = JH.RIREKI_RENBAN(+) ';
                      ' AND B.KOJIN_NO = JH.KOJIN_NO(+) AND B.RIREKI_RENBAN = JH.RIREKI_RENBAN(+) AND B.RIREKI_EDABAN = JH.RIREKI_EDABAN(+) ';
      EXECUTE IMMEDIATE VSQL;
      --更新前の内容を宛名異動累積ワークテーブル（GABWRUISEKIKIHON）に書込む。
      VSQL := NULL;
      VSQL := 'INSERT INTO GABWRUISEKIKIHON SELECT ''A'',KOJIN_NO,RIREKI_RENBAN,TEKIYO_BI,TOROKU_GYOMU,JUMINHYO_CD,SETAI_NO,GENZON_KBN,
                      JINKAKU_KBN,KOKUSEKI_CD,SHISHO_CD,CHIKU_CD,GYOSEIKU_CD,HAN_CD,SHOGAKU_CD,CHUGAKU_CD,TOHYOKU_CD,SANTEIDANTAI_CD,
                      SEINENGAPI,WAREKI_SEINENGAPI,HYOJI_SEINENGAPI,SEIBETSU,USER_CD,OAZA_CD,HONBAN,EDABAN1,EDABAN2,EDABAN3,KATAGAKI_CD,
                      GAIKU,TOU,GOU,JICHI_CD,SHIMEI_KANA,SHIMEI_KANJI,HONMYO_KANA,HONMYO_KANJI,YUBIN_NO,YUBIN_NOBC,CHOMEI,BANCHI,KATAGAKI,
                      DAIHYO_KATAGAKI,DAIHYO_SHIMEI,TEL_NO,TEL_KBN,FAX_NO,MAIL_ADS,YUHEN_KBN,TOROKU_JIYU,JUFUKU_KOJIN_NO,SYS_SAKUSEIBI,
                      SYS_KOSHINBI,SYS_JIKAN,SYS_SHOKUINKOJIN_NO,SYS_TANMATSU_NO,CHOMEI_KANA,BANCHI_KANA,KATAGAKI_KANA,KATAGAKI_HIDE_FLG,
                      GAIJI_FLG,HOJINSOSHIKI_CD,JE_KOKUHOSHISANWARI_KBN,JE_JINTEKIGENMEN_KBN,JE_SHOYUSHAKEISHONIN_KBN,JE_LINK_KOJIN_NO,
                      JE_NAYOSE_NO,YOBI1_CD,YOBI2_CD,YOBI3_CD,YOBI4_CD,YOBI5_CD,YOBI1_CH,YOBI2_CH,YOBI3_CH,YOBI4_CH,YOBI5_CH,'

                      ||  I_SYSDATE2 || ','  || I_SYSTIME2 || ',''' || i_NTANMATSU_NO || '''
                     ,TOUGOU_NO, SEIDO_KOJIN_NO, SEIDO_HOJIN_NO, ZOKUGARACD1, ZOKUGARACD2, ZOKUGARACD3, ZOKUGARACD4, ZOKUGARAKBN, ZOKUGARAMEI, JITSUZOKUGARAMEI ' ||
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
--2024/03/26 DIS.liuqimeng Update 0.3.000.000:受入検証指摘対応
--                     ',0,0,NULL,NULL,NULL,NULL,NULL,NULL,0,0,NULL,0,0,NULL,0,0,0,0,0,0,0,0,0,0,0,0,0,0,NULL,NULL,NULL,0,NULL' ||
                     ',0,0,NULL,NULL,NULL,NULL,NULL,NULL,0,0,NULL,0,0,NULL,0,0,0,0,0,0,0,0,0,0,0,0,0,0,NULL,NULL,NULL,0,NULL,0,0,0,NULL' ||
--2024/01/25 DIS.liuqimeng Add end
                     ' FROM JIBTJUKIKIHON WHERE KOJIN_NO = ' || CR_SHITEIJIYUIDO.KOJIN_NO;

      EXECUTE IMMEDIATE VSQL;
      --異動累計テーブルの追加更新処理を行う、
      ------------------------------------------------
      -- 異動区分判定
      ------------------------------------------------
      IF R_BUPD_JUKIIDO.IDO_JIYU = R_BUPD_JUKIIDO.SHORI_KBN_KEY THEN
        T_IDO_KBN := 1;
      ELSE
        T_IDO_KBN := 2;
      END IF;
      JIBSORUIUPD(CR_SHITEIJIYUIDO.KOJIN_NO
                          ,CR_SHITEIJIYUIDO.JUMINHYO_CD
                          ,N_IDO_JIYU
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
                          ,VCHOSHACODE
                          ,T_IDO_KBN
                          ,R_BUPD_JUKIIDO.ZENBU_ICHIBU_KEY
                          ,0
                          ,NULL
                          ,i_NTANMATSU_NO
                          ,0
                          ,I_SYSDATE2
                          ,I_SYSTIME2
                          ,1
                          ,I_SYSDATE2
                          ,I_SYSTIME2
                          ,N_SHORI_KBN_KEY
                          ,R_BUPD_JUKIIDO.ZENBU_ICHIBU_KEY
                          ,i_NSHOKUIN
                          ,i_NSHOKUIN
                          ,i_NTANMATSU_NO
                          ,i_SHORIBI
                          ,N_IDO_ZEN_JINKAKU_KBN
                          ,N_IDO_ZEN_GENZON_KBN
                          ,N_IDO_ZEN_NUSHI_KBN
                          ,N_IDO_ZEN_OAZA_CD
                          ,N_IDO_ZEN_GYOSEIKU_CD
                          ,N_IDO_ZEN_CHIKU_CD
                          ,T_NUSHI_JINKAKU_KBN1
                          ,T_JIYU_KBN2
                          );
      --この際、最終的に宛名異動累積を書込む為の区分を"U"として管理する。
      VKUBUN := 'U';
      GABSKDRSKSNT(VKUBUN,i_SHORIBI,I_SYSDATE2,I_SYSTIME2,i_NSHOKUIN,i_NTANMATSU_NO);
--住基ネット用変数の格納
      J_IDOMOTO := CR_SHITEIJIYUIDO.ATENA_SETAI_NO;
      IF J_KOJIN_NO IS NULL THEN
        J_KOJIN_NO := CR_SHITEIJIYUIDO.KOJIN_NO;

      ELSE
        J_KOJIN_NO := J_KOJIN_NO || '|' || CR_SHITEIJIYUIDO.KOJIN_NO;

      END IF;
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--      IF NJOKEN4 = 3 AND i_IDO_JIYU = 24 THEN
      IF NJOKEN4 = 3 AND i_IDO_JIYU = 240 THEN
         /*
         EBPPKOSEKINEWXEROXTEXT(CR_SHITEIJIYUIDO.KOJIN_NO,
                                R_BUPD_ATENA.RIREKI_RENBAN,
                                CR_SHITEIJIYUIDO.ATENA_SETAI_NO,
                                24,
                                R_BUPD_JUKIIDO.IDO_BI,
                                R_BUPD_JUKIIDO.IDO_TODOKE_BI,
                                i_SHORIBI,
                               o_RETURNCD);
         */
         NULL;
      END IF;
--2025/07/14 CTC.zhang update start 1.0.010.006:新WizLIFE保守対応 QA17556
        FOR CR_JIBWBUPD_BIKO IN CUR_JIBWBUPD_BIKO(CR_SHITEIJIYUIDO.KOJIN_NO)  LOOP
          INSERT INTO JIBTJUKIBIKO VALUES(
          CR_SHITEIJIYUIDO.KOJIN_NO      --宛名番号
          ,CR_JIBWBUPD_BIKO.RIREKI_RENBAN --履歴連番
          --,1 --履歴枝番
          ,(CASE WHEN CR_JIBWBUPD_BIKO.IDO_JIYU =412 THEN
                  CR_JIBWBUPD_BIKO.RIREKI_EDABAN+1
             ELSE
                  1 --履歴枝番
           END)
          ,CR_JIBWBUPD_BIKO.SAISHIN_FLG    --最新フラグ
          ,CR_JIBWBUPD_BIKO.SEQ           --連番
          ,CR_JIBWBUPD_BIKO.BIKO          --備考内容
          ,CR_JIBWBUPD_BIKO.GOKIFLG       --誤記フラグ
          ,CR_JIBWBUPD_BIKO.HISSUKBN      --必須区分
          ,CR_JIBWBUPD_BIKO.KISAIJUN      --記載順
          ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SHIMEI        --誤記修正後の氏名
          ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SHIMEI_KANA   --誤記修正後の氏名のフリガナ
          ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SEINENGAPI    --誤記修正後の生年月日
          ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SEINENGAPI_FUSHO_K --誤記修正後の生年月日不詳区分
          ,i_SHORIBI                       --作成日
          ,i_SHORIBI                       --更新日
          ,I_SYSTIME2                      --更新時間
          ,i_NSHOKUIN                      --更新職員宛名番号
          ,i_NTANMATSU_NO                  --更新端末番号
          );
        END LOOP;
--2025/07/14 CTC.zhang update end
    END LOOP;
--2023/11/20 DIS.Xiyan Update 0.3.000.000:住基ネット1次開発
--    JIBSOIDODATA(
    JIBSOCRTIDDTJ(
                       i_SHORIBI,              -- 処理日
                       i_ZENBUICHIBU,          -- 全部一部
                       N_IDO_JIYU,             -- 異動事由
                       J_IDOMOTO,              -- 異動元世帯番号
                       0,                      -- 異動先世帯番号
                       J_KOJIN_NO,             -- 個人番号
                       i_FUKI_FLG,             -- 付記フラグ
                       i_KEIBI_FLG             -- 軽微な修正フラグ
--2023/11/20 DIS.Xiyan Add start 0.3.000.000:住基ネット1次開発
                       ,0                      -- 住居地フラグ
                       ,''                     -- 異動事由詳細
                       ,0                      -- 住所変更フラグ
                       ,T_RENBAN               -- 住所連番
--2023/11/20 DIS.Xiyan Add end
    );
  END IF;
  --------------------------------------------------------------
  -- ワーク住基異動カーソル
  -------------------------------------------------------------
  FOR CR_IDO IN CUR_IDO(i_IENTRY_ID) LOOP
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--    IF CR_IDO.IDO_JIYU != 52 THEN
    IF CR_IDO.IDO_JIYU != 520 THEN
--2024/04/03 DIS.Wangrucheng Update 0.3.030.000:新WizLIFE２次開発（ph4対応）
--      IF CR_IDO.KOJIN_NO < 999999900000 THEN
      IF CR_IDO.KOJIN_NO < 999999999900000 THEN
        IF NKADO_BI5 <= I_SYSDATE AND
           NJOKEN111 = 0 AND
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--           CR_IDO.IDO_JIYU IN (15,16,28) THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
           --CR_IDO.IDO_JIYU IN (150,160,280) THEN
           CR_IDO.IDO_JIYU IN (150,160,280,191) THEN
             VKUBUN := 'I';
        ELSE
      --更新前の内容を住記異動累積ワークテーブル（JIBWIDORUISEKI）に書込む。
          VSQL := NULL;
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--          VSQL := 'INSERT INTO JIBWIDORUISEKI SELECT ''B'',B.KOJIN_NO,B.RIREKI_RENBAN,B.TEKIYO_BI,B.TOROKU_GYOMU,B.SETAI_NO,B.GENZON_KBN,
          VSQL := 'INSERT INTO JIBWIDORUISEKI SELECT ''B'',B.KOJIN_NO,B.RIREKI_RENBAN,B.RIREKI_EDABAN,B.SAISHIN_FLG,B.TORIKESHI_FLG,B.JOHYOYODATA_FLG,B.TEKIYO_BI,B.TOROKU_GYOMU,B.SETAI_NO,B.GENZON_KBN,
                          A.JUN_SETAI_KBN,B.JINKAKU_KBN,B.KOKUSEKI_CD,B.SHISHO_CD,B.CHIKU_CD,B.GYOSEIKU_CD,
                          B.HAN_CD,B.SHOGAKU_CD,B.CHUGAKU_CD,B.TOHYOKU_CD,B.SANTEIDANTAI_CD,B.SEINENGAPI,
                          B.WAREKI_SEINENGAPI,B.HYOJI_SEINENGAPI,B.SEIBETSU,B.USER_CD,B.OAZA_CD,B.HONBAN,
                          B.EDABAN1,B.EDABAN2,B.EDABAN3,B.KATAGAKI_CD,B.GAIKU,B.TOU,B.GOU,B.JICHI_CD,B.SHIMEI_KANA,
                          B.SHIMEI_KANJI,B.YUBIN_NO,B.YUBIN_NOBC,B.CHOMEI,B.BANCHI,B.KATAGAKI,B.DAIHYO_KATAGAKI,
                          B.DAIHYO_SHIMEI,B.TEL_NO,B.TEL_KBN,B.FAX_NO,B.MAIL_ADS,B.YUHEN_KBN,B.TOROKU_JIYU,A.JUMINHYO_CD,
                          B.ZOKUGARACD1,B.ZOKUGARACD2,B.ZOKUGARACD3,B.ZOKUGARACD4,B.ZOKUGARAKBN,B.ZOKUGARAMEI,
                          B.JITSUZOKUGARAMEI,A.KISAI_JUNI,A.IDO_BI,A.IDO_JIYU,A.IDO_TODOKE_BI,A.IDO_TODOKE_KBN,A.JUTEI_BI,
                          A.JUTEI_JIYU,A.JUTEI_TODOKEDE_BI,A.JUTEI_TODOKEDE_KBN,A.GENJUSHO_REN,A.ZENJUSHO_REN,A.TENNYUMAE_REN,
                          A.TENNYU_MITODOKE_REN,A.HONSEKI_REN,
                          A.TENSHUTSU_YOTEI_BI,A.TENSHUTSU_YOTEI_TODOKEDE_BI,A.TENSHUTSU_YOTEI_TODOKEDE_KBN,A.TENSHUTSU_YOTEI_REN,
                          A.TENSHUTSU_KAKUTEI_BI,A.TENSHUTSU_KAKUTEI_TSUCHI_BI,A.TENSHUTSU_KAKUTEI_TODOKEDE_KBN,A.TENSHUTSU_KAKUTEI_REN,
                          A.JUMIN_NARU,A.JUMIN_NARU_JIYU,A.JUMIN_NARU_TODOKEDE_BI,A.JUMIN_NARU_TODOKEDE_KBN,A.JUMIN_NAKUNARU,
                          A.JUMIN_NAKUNARU_JIYU,A.JUMIN_NAKUNARU_TODOKEDE_BI,A.JUMIN_NAKUNARU_TODOKEDE_KBN,A.SHIBOBI_FUSHO_KBN,
                          B.HONMYO_KANA,B.HONMYO_KANJI,A.NUSHI_SHIMEI_KANA,A.NUSHI_SHIMEI_KANJI,A.BIKO,A.KAISEI_BI,A.KAISEI_REN,
                          A.KYU_SHIMEI_KANA,A.KYU_SHIMEI_KANJI,A.SHORIBI_KEY,A.SHORI_JIKAN_KEY,A.SHORI_KBN_KEY,A.ZENBU_ICHIBU_KEY,
                          A.SHOKUINKOJIN_NO_KEY,B.SYS_SAKUSEIBI,B.SYS_KOSHINBI,B.SYS_JIKAN,B.SYS_SHOKUINKOJIN_NO,B.SYS_TANMATSU_NO,
                          A.GOMI_CD,A.SINYO_CD,A.KOIKIKOFU_STOP_CD,B.CHOMEI_KANA,B.BANCHI_KANA,B.KATAGAKI_KANA,B.KATAGAKI_HIDE_FLG,
                          B.GAIJI_FLG,B.HOJINSOSHIKI_CD,B.JE_KOKUHOSHISANWARI_KBN,B.JE_JINTEKIGENMEN_KBN,B.JE_SHOYUSHAKEISHONIN_KBN,
                          B.JE_LINK_KOJIN_NO,B.JE_NAYOSE_NO,B.YOBI1_CD,B.YOBI2_CD,B.YOBI3_CD,B.YOBI4_CD,B.YOBI5_CD,B.YOBI1_CH,
                          B.YOBI2_CH,B.YOBI3_CH,B.YOBI4_CH,B.YOBI5_CH,' ||  I_SYSDATE || ',' || I_SYSTIME || ','''  || i_NTANMATSU_NO || ''''||
                          ',A.ALP_SHIMEI_KANA,A.ALP_SHIMEI_KANJI,A.GAI_SHIMEI_KANA,A.GAI_SHIMEI_KANJI,A.TSUSHOMEI_KANA,A.TSUSHOMEI_KANJI,
                          A.HEIKIMEI_KANA,A.HEIKIMEI_KANJI,A.GAIKOKU_JUMIN_NARU,A.ZAIRYU_NO_SHUBETSU,A.ZAIRYU_CARD_NO,A.ZAIRYU_SHIKAKU_CD,
                          A.ZAIRYU_SHURYO_BI,A.ZAIRYU_KIKAN_NEN,A.ZAIRYU_KIKAN_TSUKI,A.ZAIRYU_KIKAN_HI,A.CARD_MANRYO_BI,A.KBN_30_45,A.KYOJYUCHI_UMU,
                          A.SEINENGAPI_FUSHO_KBN,A.RYOKEN_BANGO,A.RYOKEN_HAKKO_BI,A.JORIKU_KYOKA_BI,A.JUMIN_NUSHI_SHIMEI,A.NUSHI_KBN '||

                        ',B.TOUGOU_NO, A.SEIDO_KOJIN_NO, B.SEIDO_HOJIN_NO ' ||
                        ' ,JH.KYUUJI_KANA, JH.KYUUJI_KANJI ' ||
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
                        ',B.KETAPRM, B.KOKUMEI_CD,' ||
                        '''' || VCHOSHACODE || '''' ||
                        ',A.SHIMEI_KANA_FLG,A.TSUSHO_KANA_FLG,JH.KYUUJI_KANA_FLG,A.JIJITSUJONOSETAINUSHI_KANA' ||
                        ',A.JIJITSUJONOSETAINUSHI_KANJI,A.SAISYUTOROKUJUSHO_REN,A.SAISEIKISAI_DATE,A.SAISEIKISAIDATE_FUSHO_FLG,A.SAISEIKISAIDATE_FUSHO_HYOKI'||
                        ',A.SAISEISHOJODATE,A.SAISEISHOJODATE_FUSHO_FLG,A.SAISEISHOJODATE_FUSHO_HYOKI,A.KBN_30_46_47,A.SEINENGAPI_FUSHO_HYOKI,A.IDO_BI_FUSHO_FLG'||
                        ',A.IDO_BI_FUSHO_HYOKI,A.JUTEI_BI_FUSHO_FLG,A.JUTEI_BI_FUSHO_HYOKI,A.JUMIN_NARU_FUSHO_FLG,A.JUMIN_NARU_FUSHO_HYOKI,A.JUMIN_NAKUNARU_FUSHO_FLG'||
                        ',A.JUMIN_NAKUNARU_FUSHO_HYOKI,A.KAISEI_BI_FUSHO_FLG,A.KAISEI_BI_FUSHO_HYOKI,A.GAIKOKU_JUMIN_NARU_FUSHO_FLG,A.GAIKOKU_JUMIN_NARU_FUSHO_HYOKI'||
                        ',A.SEIBETSU_FUSHO_KBN,A.IDO_JIYU_SHOSAI,A.IDOKOMOKU_1,A.RYUIJIKO_1,A.IDOKOMOKU_2,A.RYUIJIKO_2,A.IDOKOMOKU_3,A.RYUIJIKO_3' ||
                        ',A.RIREKI_SENTAKUFUKA_FLG ,A.TODOKEDE_NO ,A.TORIKESHI_TODOKEDE_NO ' ||
--2024/01/25 DIS.liuqimeng Add end
                        ' FROM JIBTJUKIIDO A,JIBTJUKIKIHON B,JIBTJUKIJOHO JH WHERE A.KOJIN_NO = ' || CR_IDO.KOJIN_NO || ' AND B.KOJIN_NO = ' || CR_IDO.KOJIN_NO ||
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--                                                                            ' AND B.KOJIN_NO = JH.KOJIN_NO(+) AND B.RIREKI_RENBAN = JH.RIREKI_RENBAN(+) ';
                        ' AND B.KOJIN_NO = JH.KOJIN_NO(+) AND B.RIREKI_RENBAN = JH.RIREKI_RENBAN(+) AND B.RIREKI_EDABAN = JH.RIREKI_EDABAN(+) ';
                          EXECUTE IMMEDIATE VSQL;

      --更新前の内容を宛名異動累積ワークテーブル（GABWRUISEKIKIHON）に書込む。
          VSQL := NULL;
          VSQL := 'INSERT INTO GABWRUISEKIKIHON SELECT ''B'',KOJIN_NO,RIREKI_RENBAN,TEKIYO_BI,TOROKU_GYOMU,JUMINHYO_CD,SETAI_NO,GENZON_KBN,
                          JINKAKU_KBN,KOKUSEKI_CD,SHISHO_CD,CHIKU_CD,GYOSEIKU_CD,HAN_CD,SHOGAKU_CD,CHUGAKU_CD,TOHYOKU_CD,SANTEIDANTAI_CD,
                          SEINENGAPI,WAREKI_SEINENGAPI,HYOJI_SEINENGAPI,SEIBETSU,USER_CD,OAZA_CD,HONBAN,EDABAN1,EDABAN2,EDABAN3,KATAGAKI_CD,
                          GAIKU,TOU,GOU,JICHI_CD,SHIMEI_KANA,SHIMEI_KANJI,HONMYO_KANA,HONMYO_KANJI,YUBIN_NO,YUBIN_NOBC,CHOMEI,BANCHI,KATAGAKI,
                          DAIHYO_KATAGAKI,DAIHYO_SHIMEI,TEL_NO,TEL_KBN,FAX_NO,MAIL_ADS,YUHEN_KBN,TOROKU_JIYU,JUFUKU_KOJIN_NO,SYS_SAKUSEIBI,
                          SYS_KOSHINBI,SYS_JIKAN,SYS_SHOKUINKOJIN_NO,SYS_TANMATSU_NO,CHOMEI_KANA,BANCHI_KANA,KATAGAKI_KANA,KATAGAKI_HIDE_FLG,
                          GAIJI_FLG,HOJINSOSHIKI_CD,JE_KOKUHOSHISANWARI_KBN,JE_JINTEKIGENMEN_KBN,JE_SHOYUSHAKEISHONIN_KBN,JE_LINK_KOJIN_NO,
                          JE_NAYOSE_NO,YOBI1_CD,YOBI2_CD,YOBI3_CD,YOBI4_CD,YOBI5_CD,YOBI1_CH,YOBI2_CH,YOBI3_CH,YOBI4_CH,YOBI5_CH,'

                          ||  I_SYSDATE || ','  || I_SYSTIME || ',''' || i_NTANMATSU_NO || '''
                         ,TOUGOU_NO, SEIDO_KOJIN_NO, SEIDO_HOJIN_NO, ZOKUGARACD1, ZOKUGARACD2, ZOKUGARACD3, ZOKUGARACD4, ZOKUGARAKBN, ZOKUGARAMEI, JITSUZOKUGARAMEI ' ||
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
--2024/03/26 DIS.liuqimeng Update 0.3.000.000:受入検証指摘対応
--                        ',0,0,NULL,NULL,NULL,NULL,NULL,NULL,0,0,NULL,0,0,NULL,0,0,0,0,0,0,0,0,0,0,0,0,0,0,NULL,NULL,NULL,0,NULL' ||
                        ',0,0,NULL,NULL,NULL,NULL,NULL,NULL,0,0,NULL,0,0,NULL,0,0,0,0,0,0,0,0,0,0,0,0,0,0,NULL,NULL,NULL,0,NULL,0,0,0,NULL' ||
--2024/01/25 DIS.liuqimeng Add end
                        ' FROM JIBTJUKIKIHON WHERE KOJIN_NO = ' || CR_IDO.KOJIN_NO;

                          EXECUTE IMMEDIATE VSQL;
          VKUBUN := 'U';
        END IF;
      ELSE
        VKUBUN := 'I';
      END IF;
    END IF;
--2024/04/03 DIS.Wangrucheng Update 0.3.030.000:新WizLIFE２次開発（ph4対応）
--    IF CR_IDO.KOJIN_NO < 999999900000 THEN
    IF CR_IDO.KOJIN_NO < 999999999900000 THEN
      IF NKADO_BI5 <= I_SYSDATE AND
         NJOKEN111 = 0 AND
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--         CR_IDO.IDO_JIYU IN (15,16,28) THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
         --CR_IDO.IDO_JIYU IN (150,160,280) THEN
         CR_IDO.IDO_JIYU IN (150,160,280,191) THEN
           T_JINKAKU_KBN := 9;
           T_GENZON_KBN := 9;
           T_NUSHI_KBN := 9;
           T_GYOSEIKU_CD := 0;
           T_CHIKU_CD := 0;
      ELSE
        BEGIN
          SELECT OAZA_CD
            INTO T_OAZA_CD
            FROM JIBTJUKIKIHON
           WHERE KOJIN_NO = CR_IDO.KOJIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
               T_OAZA_CD := 0;
        END;

        BEGIN
          SELECT JINKAKU_KBN,GENZON_KBN,NUSHI_KBN,GYOSEIKU_CD,CHIKU_CD
            INTO T_JINKAKU_KBN,T_GENZON_KBN,T_NUSHI_KBN,T_GYOSEIKU_CD,T_CHIKU_CD
            FROM JIBTJUKIIDO
           WHERE KOJIN_NO = CR_IDO.KOJIN_NO;
        EXCEPTION
          WHEN OTHERS THEN
            T_JINKAKU_KBN := 9;
            T_GENZON_KBN := 9;
            T_NUSHI_KBN := 9;
            T_GYOSEIKU_CD := 0;
            T_CHIKU_CD := 0;
        END;
      END iF;
    ELSE
      T_JINKAKU_KBN := 9;
      T_GENZON_KBN := 9;
      T_NUSHI_KBN := 9;
      T_OAZA_CD := 0;
      T_GYOSEIKU_CD := 0;
      T_CHIKU_CD := 0;
    END IF;
    --------------------------------------------------------------
    -- ワーク宛名基本データ抽出
    -------------------------------------------------------------
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--    IF CR_IDO.IDO_JIYU != 52 THEN
    IF CR_IDO.IDO_JIYU != 520 THEN
      SELECT *
        INTO R_BUPD_ATENA
        FROM JIBWBUPD_JUKIKIHON
       WHERE ENTRY_ID = CR_IDO.ENTRY_ID
         AND KOJIN_NO = CR_IDO.KOJIN_NO;
       --住基情報中間（仮更新用）テーブルから対象者のレコードを取得し、変数「R_BUPD_JUKIJOHO」に退避
       BEGIN
         SELECT BUJH.* INTO R_BUPD_JUKIJOHO
          FROM JIBWBUPD_JUKIJOHO BUJH
          WHERE BUJH.ENTRY_ID = CR_IDO.ENTRY_ID
            AND BUJH.KOJIN_NO = CR_IDO.KOJIN_NO
            AND BUJH.RIREKI_RENBAN =  R_BUPD_ATENA.RIREKI_RENBAN;
       EXCEPTION
         WHEN OTHERS THEN
           R_BUPD_JUKIJOHO := NULL;
       END;
    END IF;
    --------------------------------------------------------------
    -- ワーク住基住所データ抽出（配列）
    -------------------------------------------------------------
    I_CNT := 0;
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--    IF NKADO_BI5 <= I_SYSDATE AND NJOKEN111 = 0 AND CR_IDO.IDO_JIYU IN (15,16,28) THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
    --IF NKADO_BI5 <= I_SYSDATE AND NJOKEN111 = 0 AND CR_IDO.IDO_JIYU IN (150,160,280) THEN
    IF NKADO_BI5 <= I_SYSDATE AND NJOKEN111 = 0 AND CR_IDO.IDO_JIYU IN (150,160,280,191) THEN
       WK_FFLG := 1;

    ELSE
       WK_FFLG := 0;

    END IF;
    FOR CR_JUSHO IN C_JUSHO(CR_IDO.ENTRY_ID,CR_IDO.KOJIN_NO,WK_FFLG) LOOP
      I_CNT := I_CNT + 1;
      M_JUSHO(I_CNT) := CR_JUSHO;
      IF M_JUSHO(I_CNT).HONBAN = '0' THEN
         M_JUSHO(I_CNT).HONBAN := '　　　　　';
      END IF;
      IF M_JUSHO(I_CNT).EDABAN1 = '0' THEN
         M_JUSHO(I_CNT).EDABAN1 := '　　　　　';
      END IF;
      IF M_JUSHO(I_CNT).EDABAN2 = '0' THEN
         M_JUSHO(I_CNT).EDABAN2 := '　　　　　';
      END IF;
      IF M_JUSHO(I_CNT).EDABAN3 = '0' THEN
         M_JUSHO(I_CNT).EDABAN3 := '　　　　　';
      END IF;
      IF M_JUSHO(I_CNT).GAIKU = '0' THEN
         M_JUSHO(I_CNT).GAIKU := '　　　　　';
      END IF;
      IF M_JUSHO(I_CNT).TOU = '0' THEN
         M_JUSHO(I_CNT).TOU := '　　　　　';
      END IF;
      IF M_JUSHO(I_CNT).GOU = '0' THEN
         M_JUSHO(I_CNT).GOU := '　　　　　';
      END IF;
    END LOOP;
    --------------------------------------------------------------
    -- 住基異動データ抽出
    -------------------------------------------------------------
    SELECT COUNT(*)
      INTO I_CNT1
      FROM JIBTJUKIIDO
     WHERE KOJIN_NO = CR_IDO.KOJIN_NO;
    R_IDO := NULL;
    IF I_CNT1 != 0 THEN
      SELECT *
        INTO R_IDO
        FROM JIBTJUKIIDO
       WHERE KOJIN_NO = CR_IDO.KOJIN_NO;
      -- 世帯番号退避
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--      IF CR_IDO.IDO_JIYU = 33 OR
--         CR_IDO.IDO_JIYU = 34 OR
--         CR_IDO.IDO_JIYU = 35 OR
--         CR_IDO.IDO_JIYU = 37 THEN
      IF CR_IDO.IDO_JIYU = 330 OR
         CR_IDO.IDO_JIYU = 340 OR
         CR_IDO.IDO_JIYU = 350 OR
         CR_IDO.IDO_JIYU = 370 THEN
--2024/01/25 DIS.liuqimeng Update end
        I_IDOMOTO  := R_IDO.SETAI_NO;
        I_JIYU_FLG := 1;
      END IF;
-- 排他解除世帯番号追加
      IF I_HAITA_SETAI1 IS NULL THEN
        I_HAITA_SETAI1 := R_IDO.SETAI_NO;
      ELSE
        IF I_HAITA_SETAI2 IS NULL THEN
          IF I_HAITA_SETAI1 != R_IDO.SETAI_NO THEN
            I_HAITA_SETAI2 := R_IDO.SETAI_NO;
          END IF;
        END IF;
      END IF;
    END IF;
-- 排他解除世帯番号追加
--2024/04/03 DIS.Wangrucheng Update 0.3.030.000:新WizLIFE２次開発（ph4対応）
--    IF CR_IDO.SETAI_NO <= 9999000 THEN
    IF CR_IDO.SETAI_NO <= 999999999900000 THEN
      IF I_HAITA_SETAI1 IS NULL THEN
        I_HAITA_SETAI1 := R_IDO.SETAI_NO;
      ELSE
        IF I_HAITA_SETAI2 IS NULL THEN
          IF I_HAITA_SETAI1 != R_IDO.SETAI_NO THEN
            I_HAITA_SETAI2 := R_IDO.SETAI_NO;
          END IF;
        END IF;
      END IF;
    END IF;
    --------------------------------------------------------------
    -- 宛名基本データ抽出
    -------------------------------------------------------------
    SELECT COUNT(*)
      INTO A_CNT
      FROM JIBTJUKIKIHON
     WHERE KOJIN_NO = CR_IDO.KOJIN_NO;
    IF A_CNT != 0 THEN
      SELECT *
        INTO R_ATENA
        FROM JIBTJUKIKIHON
       WHERE KOJIN_NO = CR_IDO.KOJIN_NO;
    END IF;

    --------------------------------------------------------------
    -- 異動事由判定
    -------------------------------------------------------------
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--    IF CR_IDO.IDO_JIYU = 52 THEN
    IF CR_IDO.IDO_JIYU = 520 THEN
      --------------------------------------------------------------
      -- 住基異動データ更新
      -------------------------------------------------------------
      IF I_CNT1 != 0 THEN
        UPDATE JIBTJUKIIDO
          SET KISAI_JUNI = CR_IDO.KISAI_JUNI,
              SYS_KOSHINBI = i_SHORIBI,
              SYS_JIKAN = I_SYSTIME,
              SYS_SHOKUINKOJIN_NO = i_NSHOKUIN,
              SYS_TANMATSU_NO = i_NTANMATSU_NO
        WHERE KOJIN_NO = CR_IDO.KOJIN_NO
        AND   KISAI_JUNI != CR_IDO.KISAI_JUNI;
      END IF;
    ELSE
      ------------------------------------------------
      -- 宛名履歴ＴＢＬ追加
      ------------------------------------------------
      IF I_CNT1 != 0 OR A_CNT != 0 THEN
        IF NKADO_BI5 <= I_SYSDATE AND
           NJOKEN111 = 0 AND
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--           CR_IDO.IDO_JIYU IN (15,16,28) THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
           --CR_IDO.IDO_JIYU IN (150,160,280) THEN
           CR_IDO.IDO_JIYU IN (150,160,280,191) THEN
             NULL;
        ELSE
--2024/04/03 DIS.Wangrucheng Add start 0.3.030.000:新WizLIFE２次開発（ph4対応）
          -- 異動事由は「412：誤記修正」の場合
         --2024/12/6 CTC Update start 0.3.000.000:IT_JIB_00736対応
         --IF CR_IDO.IDO_JIYU = 412 THEN
        IF CR_IDO.IDO_JIYU = 412 and  R_ATENA.RIREKI_RENBAN* 100 +R_ATENA.RIREKI_EDABAN > R_BUPD_ATENA.RIREKI_RENBAN* 100 +R_BUPD_ATENA.RIREKI_EDABAN THEN
            RJIBTJUKIRIREKI_INS := NULL;
            -- 宛名番号
            RJIBTJUKIRIREKI_INS.KOJIN_NO := R_BUPD_ATENA.KOJIN_NO;
            -- 履歴連番
            RJIBTJUKIRIREKI_INS.RIREKI_RENBAN := R_BUPD_ATENA.RIREKI_RENBAN;
            -- 履歴枝番
            RJIBTJUKIRIREKI_INS.RIREKI_EDABAN := R_BUPD_ATENA.RIREKI_EDABAN + 1;
            -- 最新フラグ
            RJIBTJUKIRIREKI_INS.SAISHIN_FLG := 1;
            -- 取消フラグ
            RJIBTJUKIRIREKI_INS.TORIKESHI_FLG := R_BUPD_ATENA.TORIKESHI_FLG;
            -- 除票用データフラグ
            RJIBTJUKIRIREKI_INS.JOHYOYODATA_FLG := R_BUPD_ATENA.JOHYOYODATA_FLG;
            -- 適用日
            RJIBTJUKIRIREKI_INS.TEKIYO_BI := R_BUPD_ATENA.TEKIYO_BI;
            -- 登録業務
            RJIBTJUKIRIREKI_INS.TOROKU_GYOMU := R_BUPD_ATENA.TOROKU_GYOMU;
            -- 世帯番号
            RJIBTJUKIRIREKI_INS.SETAI_NO := R_BUPD_ATENA.SETAI_NO;
            -- 現存区分
            RJIBTJUKIRIREKI_INS.GENZON_KBN := R_BUPD_ATENA.GENZON_KBN;
            -- 準世帯区分
            RJIBTJUKIRIREKI_INS.JUN_SETAI_KBN := NVL(CR_IDO.JUN_SETAI_KBN,0);
            -- 人格区分
            RJIBTJUKIRIREKI_INS.JINKAKU_KBN := R_BUPD_ATENA.JINKAKU_KBN;
            -- 国籍等コード
            RJIBTJUKIRIREKI_INS.KOKUSEKI_CD := R_BUPD_ATENA.KOKUSEKI_CD;
            -- 支所コード
            RJIBTJUKIRIREKI_INS.SHISHO_CD := R_BUPD_ATENA.SHISHO_CD;
            -- 地区コード
            RJIBTJUKIRIREKI_INS.CHIKU_CD := R_BUPD_ATENA.CHIKU_CD;
            -- 行政区コード
            RJIBTJUKIRIREKI_INS.GYOSEIKU_CD := R_BUPD_ATENA.GYOSEIKU_CD;
            -- 班コード
            RJIBTJUKIRIREKI_INS.HAN_CD := R_BUPD_ATENA.HAN_CD;
            -- 小学校区コード
            RJIBTJUKIRIREKI_INS.SHOGAKU_CD := R_BUPD_ATENA.SHOGAKU_CD;
            -- 中学校区コード
            RJIBTJUKIRIREKI_INS.CHUGAKU_CD := R_BUPD_ATENA.CHUGAKU_CD;
            -- 投票区コード
            RJIBTJUKIRIREKI_INS.TOHYOKU_CD := R_BUPD_ATENA.TOHYOKU_CD;
            -- 算定団体コード
            RJIBTJUKIRIREKI_INS.SANTEIDANTAI_CD := R_BUPD_ATENA.SANTEIDANTAI_CD;
            -- 生年月日
            RJIBTJUKIRIREKI_INS.SEINENGAPI := R_BUPD_ATENA.SEINENGAPI;
            -- 和暦生年月日
            RJIBTJUKIRIREKI_INS.WAREKI_SEINENGAPI := R_BUPD_ATENA.WAREKI_SEINENGAPI;
            -- 表示用生年月日
            RJIBTJUKIRIREKI_INS.HYOJI_SEINENGAPI := R_BUPD_ATENA.HYOJI_SEINENGAPI;
            -- 性別
            RJIBTJUKIRIREKI_INS.SEIBETSU := R_BUPD_ATENA.SEIBETSU;
            -- 市町村コード
            RJIBTJUKIRIREKI_INS.USER_CD := R_BUPD_ATENA.USER_CD;
            -- 大字コード
            RJIBTJUKIRIREKI_INS.OAZA_CD := R_BUPD_ATENA.OAZA_CD;
            -- 本番
            RJIBTJUKIRIREKI_INS.HONBAN := R_BUPD_ATENA.HONBAN;
            -- 枝番１
            RJIBTJUKIRIREKI_INS.EDABAN1 := R_BUPD_ATENA.EDABAN1;
            -- 枝番２
            RJIBTJUKIRIREKI_INS.EDABAN2 := R_BUPD_ATENA.EDABAN2;
            -- 枝番３
            RJIBTJUKIRIREKI_INS.EDABAN3 := R_BUPD_ATENA.EDABAN3;
            -- 方書コード
            RJIBTJUKIRIREKI_INS.KATAGAKI_CD := R_BUPD_ATENA.KATAGAKI_CD;
            -- 街区番号
            RJIBTJUKIRIREKI_INS.GAIKU := R_BUPD_ATENA.GAIKU;
            -- 棟
            RJIBTJUKIRIREKI_INS.TOU := R_BUPD_ATENA.TOU;
            -- 号
            RJIBTJUKIRIREKI_INS.GOU := R_BUPD_ATENA.GOU;
            -- 自治コード
            RJIBTJUKIRIREKI_INS.JICHI_CD := R_BUPD_ATENA.JICHI_CD;
            -- 氏名カナ
            RJIBTJUKIRIREKI_INS.SHIMEI_KANA := R_BUPD_ATENA.SHIMEI_KANA;
            -- 氏名漢字
            RJIBTJUKIRIREKI_INS.SHIMEI_KANJI := R_BUPD_ATENA.SHIMEI_KANJI;
            -- 郵便番号
            RJIBTJUKIRIREKI_INS.YUBIN_NO := R_BUPD_ATENA.YUBIN_NO;
            -- 郵便番号BC
            RJIBTJUKIRIREKI_INS.YUBIN_NOBC := R_BUPD_ATENA.YUBIN_NOBC;
            -- 町名
            RJIBTJUKIRIREKI_INS.CHOMEI := R_BUPD_ATENA.CHOMEI;
            -- 番地
            RJIBTJUKIRIREKI_INS.BANCHI := R_BUPD_ATENA.BANCHI;
            -- 方書
            RJIBTJUKIRIREKI_INS.KATAGAKI := R_BUPD_ATENA.KATAGAKI;
            -- 代表者肩書
            RJIBTJUKIRIREKI_INS.DAIHYO_KATAGAKI := R_BUPD_ATENA.DAIHYO_KATAGAKI;
            -- 代表者氏名
            RJIBTJUKIRIREKI_INS.DAIHYO_SHIMEI := R_BUPD_ATENA.DAIHYO_SHIMEI;
            -- 電話番号
            RJIBTJUKIRIREKI_INS.TEL_NO := R_BUPD_ATENA.TEL_NO;
            -- 電話区分
            RJIBTJUKIRIREKI_INS.TEL_KBN := R_BUPD_ATENA.TEL_KBN;
            -- FAX
            RJIBTJUKIRIREKI_INS.FAX_NO := R_BUPD_ATENA.FAX_NO;
            -- メールアドレス
            RJIBTJUKIRIREKI_INS.MAIL_ADS := R_BUPD_ATENA.MAIL_ADS;
            -- 郵便返却区分
            RJIBTJUKIRIREKI_INS.YUHEN_KBN := R_BUPD_ATENA.YUHEN_KBN;
            -- 登録事由
            RJIBTJUKIRIREKI_INS.TOROKU_JIYU := R_BUPD_ATENA.TOROKU_JIYU;
            -- 住民票コード
            RJIBTJUKIRIREKI_INS.JUMINHYO_CD := NVL(R_BUPD_ATENA.JUMINHYO_CD,0);
            -- 続柄コード１
            RJIBTJUKIRIREKI_INS.ZOKUGARA_CD1 := NVL(R_BUPD_ATENA.ZOKUGARACD1,0);
            -- 続柄コード２
            RJIBTJUKIRIREKI_INS.ZOKUGARA_CD2 := NVL(R_BUPD_ATENA.ZOKUGARACD2,0);
            -- 続柄コード３
            RJIBTJUKIRIREKI_INS.ZOKUGARA_CD3 := NVL(R_BUPD_ATENA.ZOKUGARACD3,0);
            -- 続柄コード４
            RJIBTJUKIRIREKI_INS.ZOKUGARA_CD4 := NVL(R_BUPD_ATENA.ZOKUGARACD4,0);
            -- 続柄区分
            RJIBTJUKIRIREKI_INS.ZOKUGARA_KBN := NVL(R_BUPD_ATENA.ZOKUGARAKBN,0);
            -- 続柄名
            RJIBTJUKIRIREKI_INS.ZOKUGARA_MEI := R_BUPD_ATENA.ZOKUGARAMEI;
            -- 実続柄名
            RJIBTJUKIRIREKI_INS.JITSU_ZOKUGARA_MEI := R_BUPD_ATENA.JITSUZOKUGARAMEI;
            -- 記載順位
            RJIBTJUKIRIREKI_INS.KISAI_JUNI := NVL(CR_IDO.KISAI_JUNI,0);
            -- 異動日
            RJIBTJUKIRIREKI_INS.IDO_BI := NVL(CR_IDO.IDO_BI,0);
            -- 異動事由
            RJIBTJUKIRIREKI_INS.IDO_JIYU := NVL(CR_IDO.IDO_JIYU,0);
            -- 異動届出日
            RJIBTJUKIRIREKI_INS.IDO_TODOKE_BI := NVL(CR_IDO.IDO_TODOKE_BI,0);
            -- 異動届出区分
            RJIBTJUKIRIREKI_INS.IDO_TODOKE_KBN := NVL(CR_IDO.IDO_TODOKE_KBN,0);
            -- 住定日
            RJIBTJUKIRIREKI_INS.JUTEI_BI := NVL(CR_IDO.JUTEI_BI,0);
            -- 住定事由
            RJIBTJUKIRIREKI_INS.JUTEI_JIYU := NVL(CR_IDO.JUTEI_JIYU,0);
            -- 住定届出日
            RJIBTJUKIRIREKI_INS.JUTEI_TODOKEDE_BI := NVL(CR_IDO.JUTEI_TODOKEDE_BI,0);
            -- 住定届出区分
            RJIBTJUKIRIREKI_INS.JUTEI_TODOKEDE_KBN := NVL(CR_IDO.JUTEI_TODOKEDE_KBN,0);
            -- 現住所連番
            RJIBTJUKIRIREKI_INS.GENJUSHO_REN := NVL(CR_IDO.GENJUSHO_REN,0);
            -- 前住所連番
            RJIBTJUKIRIREKI_INS.ZENJUSHO_REN := NVL(CR_IDO.ZENJUSHO_REN,0);
            -- 転入前住所連番
            RJIBTJUKIRIREKI_INS.TENNYUMAE_REN := NVL(CR_IDO.TENNYUMAE_REN,0);
            -- 転入未届地連番
            RJIBTJUKIRIREKI_INS.TENNYU_MITODOKE_REN := NVL(CR_IDO.TENNYU_MITODOKE_REN,0);
            -- 本籍地連番
            RJIBTJUKIRIREKI_INS.HONSEKI_REN := NVL(CR_IDO.HONSEKI_REN,0);
            -- 転出予定日
            RJIBTJUKIRIREKI_INS.TENSHUTSU_YOTEI_BI := NVL(CR_IDO.TENSHUTSU_YOTEI_BI,0);
            -- 転出予定届出日
            RJIBTJUKIRIREKI_INS.TENSHUTSU_YOTEI_TODOKEDE_BI := NVL(CR_IDO.TENSHUTSU_YOTEI_TODOKEDE_BI,0);
            -- 転出予定届出区分
            RJIBTJUKIRIREKI_INS.TENSHUTSU_YOTEI_TODOKEDE_KBN := NVL(CR_IDO.TENSHUTSU_YOTEI_TODOKEDE_KBN,0);
            -- 転出予定地連番
            RJIBTJUKIRIREKI_INS.TENSHUTSU_YOTEI_REN := NVL(CR_IDO.TENSHUTSU_YOTEI_REN,0);
            -- 転出確定日
            RJIBTJUKIRIREKI_INS.TENSHUTSU_KAKUTEI_BI := NVL(CR_IDO.TENSHUTSU_KAKUTEI_BI,0);
            -- 転出確定通知日
            RJIBTJUKIRIREKI_INS.TENSHUTSU_KAKUTEI_TSUCHI_BI := NVL(CR_IDO.TENSHUTSU_KAKUTEI_TSUCHI_BI,0);
            -- 転出確定届出区分
            RJIBTJUKIRIREKI_INS.TENSHUTSU_KAKUTEI_TODOKEDE_KBN := NVL(CR_IDO.TENSHUTSU_KAKUTEI_TODOKEDE_KBN,0);
            -- 転出確定地連番
            RJIBTJUKIRIREKI_INS.TENSHUTSU_KAKUTEI_REN := NVL(CR_IDO.TENSHUTSU_KAKUTEI_REN,0);
            -- 住民となる日
            RJIBTJUKIRIREKI_INS.JUMIN_NARU := NVL(CR_IDO.JUMIN_NARU,0);
            -- 住民となる事由
            RJIBTJUKIRIREKI_INS.JUMIN_NARU_JIYU := NVL(CR_IDO.JUMIN_NARU_JIYU,0);
            -- 住民となる届出日
            RJIBTJUKIRIREKI_INS.JUMIN_NARU_TODOKEDE_BI := NVL(CR_IDO.JUMIN_NARU_TODOKEDE_BI,0);
            -- 住民となる届出区分
            RJIBTJUKIRIREKI_INS.JUMIN_NARU_TODOKEDE_KBN := NVL(CR_IDO.JUMIN_NARU_TODOKEDE_KBN,0);
            -- 住民でなくなる日
            RJIBTJUKIRIREKI_INS.JUMIN_NAKUNARU := NVL(CR_IDO.JUMIN_NAKUNARU,0);
            -- 住民でなくなる事由
            RJIBTJUKIRIREKI_INS.JUMIN_NAKUNARU_JIYU := NVL(CR_IDO.JUMIN_NAKUNARU_JIYU,0);
            -- 住民でなくなる届出日
            RJIBTJUKIRIREKI_INS.JUMIN_NAKUNARU_TODOKEDE_BI := NVL(CR_IDO.JUMIN_NAKUNARU_TODOKEDE_BI,0);
            -- 住民でなくなる届出区分
            RJIBTJUKIRIREKI_INS.JUMIN_NAKUNARU_TODOKEDE_KBN := NVL(CR_IDO.JUMIN_NAKUNARU_TODOKEDE_KBN,0);
            -- 死亡日不詳区分
            RJIBTJUKIRIREKI_INS.SHIBOBI_FUSHO_KBN := NVL(CR_IDO.SHIBOBI_FUSHO_KBN,0);
            -- 本名カナ
            RJIBTJUKIRIREKI_INS.HONMYO_KANA := R_BUPD_ATENA.HONMYO_KANA;
            -- 本名漢字
            RJIBTJUKIRIREKI_INS.HONMYO_KANJI := R_BUPD_ATENA.HONMYO_KANJI;
            -- 世帯主氏名カナ
            RJIBTJUKIRIREKI_INS.NUSHI_SHIMEI_KANA := CR_IDO.NUSHI_SHIMEI_KANA;
            -- 世帯主氏名漢字
            RJIBTJUKIRIREKI_INS.NUSHI_SHIMEI_KANJI := CR_IDO.NUSHI_SHIMEI_KANJI;
            -- 備考
            RJIBTJUKIRIREKI_INS.BIKO := CR_IDO.BIKO;
            -- 改製日
            RJIBTJUKIRIREKI_INS.KAISEI_BI := NVL(CR_IDO.KAISEI_BI,0);
            -- 改製連番
            RJIBTJUKIRIREKI_INS.KAISEI_REN := NVL(CR_IDO.KAISEI_REN,0);
            -- 旧氏名カナ
            RJIBTJUKIRIREKI_INS.KYU_SHIMEI_KANA := CR_IDO.KYU_SHIMEI_KANA;
            -- 旧氏名漢字
            RJIBTJUKIRIREKI_INS.KYU_SHIMEI_KANJI := CR_IDO.KYU_SHIMEI_KANJI;
            -- 処理日キー
            RJIBTJUKIRIREKI_INS.SHORIBI_KEY := NVL(CR_IDO.SHORIBI_KEY,0);
            -- 処理時間キー
            RJIBTJUKIRIREKI_INS.SHORI_JIKAN_KEY := NVL(CR_IDO.SHORI_JIKAN_KEY,0);
            -- 処理区分キー
            RJIBTJUKIRIREKI_INS.SHORI_KBN_KEY := NVL(CR_IDO.SHORI_KBN_KEY,0);
            -- 全部一部キー
            RJIBTJUKIRIREKI_INS.ZENBU_ICHIBU_KEY := NVL(CR_IDO.ZENBU_ICHIBU_KEY,0);
            -- 職員番号キー
            RJIBTJUKIRIREKI_INS.SHOKUINKOJIN_NO_KEY := CR_IDO.SHOKUINKOJIN_NO_KEY;
            -- 作成日
            RJIBTJUKIRIREKI_INS.SYS_SAKUSEIBI := R_BUPD_ATENA.SYS_SAKUSEIBI;
            -- 更新日
            RJIBTJUKIRIREKI_INS.SYS_KOSHINBI := R_BUPD_ATENA.SYS_KOSHINBI;
            -- 更新時間
            RJIBTJUKIRIREKI_INS.SYS_JIKAN := R_BUPD_ATENA.SYS_JIKAN;
            -- 更新職員宛名番号
            RJIBTJUKIRIREKI_INS.SYS_SHOKUINKOJIN_NO := R_BUPD_ATENA.SYS_SHOKUINKOJIN_NO;
            -- 更新端末番号
            RJIBTJUKIRIREKI_INS.SYS_TANMATSU_NO := R_BUPD_ATENA.SYS_TANMATSU_NO;
            -- ごみ業者コード
            RJIBTJUKIRIREKI_INS.GOMI_CD := NVL(CR_IDO.GOMI_CD,0);
            -- し尿業者コード
            RJIBTJUKIRIREKI_INS.SINYO_CD := NVL(CR_IDO.SINYO_CD,0);
            -- 広域交付発行停止コード
            RJIBTJUKIRIREKI_INS.KOIKIKOFU_STOP_CD := NVL(CR_IDO.KOIKIKOFU_STOP_CD,0);
            -- 町名カナ（全角文字）
            RJIBTJUKIRIREKI_INS.CHOMEI_KANA := R_BUPD_ATENA.CHOMEI_KANA;
            -- 番地カナ（全角文字）
            RJIBTJUKIRIREKI_INS.BANCHI_KANA := R_BUPD_ATENA.BANCHI_KANA;
            -- 方書カナ（全角文字）
            RJIBTJUKIRIREKI_INS.KATAGAKI_KANA := R_BUPD_ATENA.KATAGAKI_KANA;
            -- 方書非表示フラグ
            RJIBTJUKIRIREKI_INS.KATAGAKI_HIDE_FLG := R_BUPD_ATENA.KATAGAKI_HIDE_FLG;
            -- 外字未登録フラグ
            RJIBTJUKIRIREKI_INS.GAIJI_FLG := R_BUPD_ATENA.GAIJI_FLG;
            -- 法人組織コード
            RJIBTJUKIRIREKI_INS.HOJINSOSHIKI_CD := R_BUPD_ATENA.HOJINSOSHIKI_CD;
            -- 固定_国保資産割対象区分
            RJIBTJUKIRIREKI_INS.JE_KOKUHOSHISANWARI_KBN := R_BUPD_ATENA.JE_KOKUHOSHISANWARI_KBN;
            -- 固定_人的減免区分
            RJIBTJUKIRIREKI_INS.JE_JINTEKIGENMEN_KBN := R_BUPD_ATENA.JE_JINTEKIGENMEN_KBN;
            -- 固定_所有者継承人区分
            RJIBTJUKIRIREKI_INS.JE_SHOYUSHAKEISHONIN_KBN := R_BUPD_ATENA.JE_SHOYUSHAKEISHONIN_KBN;
            -- 固定_リンク先宛名番号
            RJIBTJUKIRIREKI_INS.JE_LINK_KOJIN_NO := R_BUPD_ATENA.JE_LINK_KOJIN_NO;
            -- 固定_名寄番号
            RJIBTJUKIRIREKI_INS.JE_NAYOSE_NO := R_BUPD_ATENA.JE_NAYOSE_NO;
            -- 予備コード1
            RJIBTJUKIRIREKI_INS.YOBI1_CD := R_BUPD_ATENA.YOBI1_CD;
            -- 予備コード2
            RJIBTJUKIRIREKI_INS.YOBI2_CD := R_BUPD_ATENA.YOBI2_CD;
            -- 予備コード3
            RJIBTJUKIRIREKI_INS.YOBI3_CD := R_BUPD_ATENA.YOBI3_CD;
            -- 予備コード4
            RJIBTJUKIRIREKI_INS.YOBI4_CD := R_BUPD_ATENA.YOBI4_CD;
            -- 予備コード5
            RJIBTJUKIRIREKI_INS.YOBI5_CD := R_BUPD_ATENA.YOBI5_CD;
            -- 予備項目1
            RJIBTJUKIRIREKI_INS.YOBI1_CH := R_BUPD_ATENA.YOBI1_CH;
            -- 予備項目2
            RJIBTJUKIRIREKI_INS.YOBI2_CH := R_BUPD_ATENA.YOBI2_CH;
            -- 予備項目3
            RJIBTJUKIRIREKI_INS.YOBI3_CH := R_BUPD_ATENA.YOBI3_CH;
            -- 予備項目4
            RJIBTJUKIRIREKI_INS.YOBI4_CH := R_BUPD_ATENA.YOBI4_CH;
            -- 予備項目5
            RJIBTJUKIRIREKI_INS.YOBI5_CH := R_BUPD_ATENA.YOBI5_CH;
            -- アルファベット氏名カナ
            RJIBTJUKIRIREKI_INS.ALP_SHIMEI_KANA := CR_IDO.ALP_SHIMEI_KANA;
            -- アルファベット氏名漢字
            RJIBTJUKIRIREKI_INS.ALP_SHIMEI_KANJI := CR_IDO.ALP_SHIMEI_KANJI;
            -- 外国人氏名カナ
            RJIBTJUKIRIREKI_INS.GAI_SHIMEI_KANA := CR_IDO.GAI_SHIMEI_KANA;
            -- 外国人氏名漢字
            RJIBTJUKIRIREKI_INS.GAI_SHIMEI_KANJI := CR_IDO.GAI_SHIMEI_KANJI;
            -- 通称名カナ
            RJIBTJUKIRIREKI_INS.TSUSHOMEI_KANA := CR_IDO.TSUSHOMEI_KANA;
            -- 通称名漢字
            RJIBTJUKIRIREKI_INS.TSUSHOMEI_KANJI := CR_IDO.TSUSHOMEI_KANJI;
            -- 併記名カナ
            RJIBTJUKIRIREKI_INS.HEIKIMEI_KANA := CR_IDO.HEIKIMEI_KANA;
            -- 併記名漢字
            RJIBTJUKIRIREKI_INS.HEIKIMEI_KANJI := CR_IDO.HEIKIMEI_KANJI;
            -- 外国人の住民となる日
            RJIBTJUKIRIREKI_INS.GAIKOKU_JUMIN_NARU := NVL(CR_IDO.GAIKOKU_JUMIN_NARU,0);
            -- 在留番号種別
            RJIBTJUKIRIREKI_INS.ZAIRYU_NO_SHUBETSU := NVL(CR_IDO.ZAIRYU_NO_SHUBETSU,0);
            -- 在留カード番号
            RJIBTJUKIRIREKI_INS.ZAIRYU_CARD_NO := CR_IDO.ZAIRYU_CARD_NO;
            -- 在留資格コード
            RJIBTJUKIRIREKI_INS.ZAIRYU_SHIKAKU_CD := NVL(CR_IDO.ZAIRYU_SHIKAKU_CD,0);
            -- 在留期間終了年月日
            RJIBTJUKIRIREKI_INS.ZAIRYU_SHURYO_BI := NVL(CR_IDO.ZAIRYU_SHURYO_BI,0);
            -- 在留期間年
            RJIBTJUKIRIREKI_INS.ZAIRYU_KIKAN_NEN := NVL(CR_IDO.ZAIRYU_KIKAN_NEN,0);
            -- 在留期間月
            RJIBTJUKIRIREKI_INS.ZAIRYU_KIKAN_TSUKI := NVL(CR_IDO.ZAIRYU_KIKAN_TSUKI,0);
            -- 在留期間日
            RJIBTJUKIRIREKI_INS.ZAIRYU_KIKAN_HI := NVL(CR_IDO.ZAIRYU_KIKAN_HI,0);
            -- カード有効期間満了日
            RJIBTJUKIRIREKI_INS.CARD_MANRYO_BI := NVL(CR_IDO.CARD_MANRYO_BI,0);
            -- 第30条45に規定する区分
            RJIBTJUKIRIREKI_INS.KBN_30_45 := NVL(CR_IDO.KBN_30_45,0);
            -- 居住地の届出の有無
            RJIBTJUKIRIREKI_INS.KYOJYUCHI_UMU := NVL(CR_IDO.KYOJYUCHI_UMU,0);
            -- 生年月日不詳区分
            RJIBTJUKIRIREKI_INS.SEINENGAPI_FUSHO_KBN := NVL(CR_IDO.SEINENGAPI_FUSHO_KBN,0);
            -- 旅券番号
            RJIBTJUKIRIREKI_INS.RYOKEN_BANGO := CR_IDO.RYOKEN_BANGO;
            -- 旅券発行年月日
            RJIBTJUKIRIREKI_INS.RYOKEN_HAKKO_BI := NVL(CR_IDO.RYOKEN_HAKKO_BI,0);
            -- 上陸許可年月日
            RJIBTJUKIRIREKI_INS.JORIKU_KYOKA_BI := NVL(CR_IDO.JORIKU_KYOKA_BI,0);
            -- 住民票上世帯主名
            RJIBTJUKIRIREKI_INS.JUMIN_NUSHI_SHIMEI := CR_IDO.JUMIN_NUSHI_SHIMEI;
            -- 統合宛名番号
            RJIBTJUKIRIREKI_INS.TOUGOU_NO := R_BUPD_ATENA.TOUGOU_NO;
            -- 個人番号（番号制度）
            RJIBTJUKIRIREKI_INS.SEIDO_KOJIN_NO := R_BUPD_ATENA.SEIDO_KOJIN_NO;
            -- 法人番号（番号制度）
            RJIBTJUKIRIREKI_INS.SEIDO_HOJIN_NO := R_BUPD_ATENA.SEIDO_HOJIN_NO;
            -- 住所_桁取パラメータ（基本データリスト用項目）
            RJIBTJUKIRIREKI_INS.KETAPRM := R_BUPD_ATENA.KETAPRM;
            -- 住所_国名コード（基本データリスト用項目）
            RJIBTJUKIRIREKI_INS.KOKUMEI_CD := R_BUPD_ATENA.KOKUMEI_CD;
            -- 入力場所
            RJIBTJUKIRIREKI_INS.NYURYOKUBASHO := CR_IDO.NYURYOKUBASHO;
            -- 氏名カナフラグ
            RJIBTJUKIRIREKI_INS.SHIMEI_KANA_FLG := NVL(CR_IDO.SHIMEI_KANA_FLG,0);
            -- 通称カナフラグ
            RJIBTJUKIRIREKI_INS.TSUSHO_KANA_FLG := NVL(CR_IDO.TSUSHO_KANA_FLG,0);
            -- 事実上の世帯主カナ
            RJIBTJUKIRIREKI_INS.JIJITSUJONOSETAINUSHI_KANA := CR_IDO.JIJITSUJONOSETAINUSHI_KANA;
            -- 事実上の世帯主漢字
            RJIBTJUKIRIREKI_INS.JIJITSUJONOSETAINUSHI_KANJI := CR_IDO.JIJITSUJONOSETAINUSHI_KANJI;
            -- 最終登録住所地連番
            RJIBTJUKIRIREKI_INS.SAISYUTOROKUJUSHO_REN := NVL(CR_IDO.SAISYUTOROKUJUSHO_REN,0);
            -- 再製記載年月日
            RJIBTJUKIRIREKI_INS.SAISEIKISAI_DATE := NVL(CR_IDO.SAISEIKISAI_DATE,0);
            -- 再製記載年月日不詳フラグ
            RJIBTJUKIRIREKI_INS.SAISEIKISAIDATE_FUSHO_FLG := NVL(CR_IDO.SAISEIKISAIDATE_FUSHO_FLG,0);
            -- 再製記載年月日不詳表記
            RJIBTJUKIRIREKI_INS.SAISEIKISAIDATE_FUSHO_HYOKI := CR_IDO.SAISEIKISAIDATE_FUSHO_HYOKI;
            -- 再製消除年月日
            RJIBTJUKIRIREKI_INS.SAISEISHOJODATE := NVL(CR_IDO.SAISEISHOJODATE,0);
            -- 再製消除年月日不詳フラグ
            RJIBTJUKIRIREKI_INS.SAISEISHOJODATE_FUSHO_FLG := NVL(CR_IDO.SAISEISHOJODATE_FUSHO_FLG,0);
            -- 再製消除年月日不詳表記
            RJIBTJUKIRIREKI_INS.SAISEISHOJODATE_FUSHO_HYOKI := CR_IDO.SAISEISHOJODATE_FUSHO_HYOKI;
            -- 法第30条46又は47区分
            RJIBTJUKIRIREKI_INS.KBN_30_46_47 := CR_IDO.KBN_30_46_47;
            -- 生年月日不詳表記
            RJIBTJUKIRIREKI_INS.SEINENGAPI_FUSHO_HYOKI := CR_IDO.SEINENGAPI_FUSHO_HYOKI;
            -- 異動日不詳フラグ
            RJIBTJUKIRIREKI_INS.IDO_BI_FUSHO_FLG := NVL(CR_IDO.IDO_BI_FUSHO_FLG,0);
            -- 異動日不詳表記
            RJIBTJUKIRIREKI_INS.IDO_BI_FUSHO_HYOKI := CR_IDO.IDO_BI_FUSHO_HYOKI;
            -- 住定日不詳フラグ
            RJIBTJUKIRIREKI_INS.JUTEI_BI_FUSHO_FLG := NVL(CR_IDO.JUTEI_BI_FUSHO_FLG,0);
            -- 住定日不詳表記
            RJIBTJUKIRIREKI_INS.JUTEI_BI_FUSHO_HYOKI := CR_IDO.JUTEI_BI_FUSHO_HYOKI;
            -- 住民となる日不詳フラグ
            RJIBTJUKIRIREKI_INS.JUMIN_NARU_FUSHO_FLG := NVL(CR_IDO.JUMIN_NARU_FUSHO_FLG,0);
            -- 住民となる日不詳表記
            RJIBTJUKIRIREKI_INS.JUMIN_NARU_FUSHO_HYOKI := CR_IDO.JUMIN_NARU_FUSHO_HYOKI;
            -- 住民でなくなる日不詳フラグ
            RJIBTJUKIRIREKI_INS.JUMIN_NAKUNARU_FUSHO_FLG := NVL(CR_IDO.JUMIN_NAKUNARU_FUSHO_FLG,0);
            -- 住民でなくなる日不詳表記
            RJIBTJUKIRIREKI_INS.JUMIN_NAKUNARU_FUSHO_HYOKI := CR_IDO.JUMIN_NAKUNARU_FUSHO_HYOKI;
            -- 改製日不詳フラグ
            RJIBTJUKIRIREKI_INS.KAISEI_BI_FUSHO_FLG := NVL(CR_IDO.KAISEI_BI_FUSHO_FLG,0);
            -- 改製日不詳表記
            RJIBTJUKIRIREKI_INS.KAISEI_BI_FUSHO_HYOKI := CR_IDO.KAISEI_BI_FUSHO_HYOKI;
            -- 外国人の住民となる日不詳フラグ
            RJIBTJUKIRIREKI_INS.GAIKOKU_JUMIN_NARU_FUSHO_FLG := NVL(CR_IDO.GAIKOKU_JUMIN_NARU_FUSHO_FLG,0);
            -- 外国人の住民となる日不詳表記
            RJIBTJUKIRIREKI_INS.GAIKOKU_JUMIN_NARU_FUSHO_HYOKI := CR_IDO.GAIKOKU_JUMIN_NARU_FUSHO_HYOKI;
            -- 性別不詳区分
            RJIBTJUKIRIREKI_INS.SEIBETSU_FUSHO_KBN := NVL(CR_IDO.SEIBETSU_FUSHO_KBN,0);
            -- 異動事由詳細
            RJIBTJUKIRIREKI_INS.IDO_JIYU_SHOSAI := NVL(CR_IDO.IDO_JIYU_SHOSAI,0);
            -- 異動項目_1
            RJIBTJUKIRIREKI_INS.IDOKOMOKU_1 := NVL(CR_IDO.IDOKOMOKU_1,0);
            -- 留意事項_1
            RJIBTJUKIRIREKI_INS.RYUIJIKO_1 := CR_IDO.RYUIJIKO_1;
            -- 異動項目_2
            RJIBTJUKIRIREKI_INS.IDOKOMOKU_2 := NVL(CR_IDO.IDOKOMOKU_2,0);
            -- 留意事項_2
            RJIBTJUKIRIREKI_INS.RYUIJIKO_2 := CR_IDO.RYUIJIKO_2;
            -- 異動項目_3
            RJIBTJUKIRIREKI_INS.IDOKOMOKU_3 := NVL(CR_IDO.IDOKOMOKU_3,0);
            -- 留意事項_3
            RJIBTJUKIRIREKI_INS.RYUIJIKO_3 := CR_IDO.RYUIJIKO_3;
            -- 履歴選択不可フラグ
            RJIBTJUKIRIREKI_INS.RIREKI_SENTAKUFUKA_FLG := NVL(CR_IDO.RIREKI_SENTAKUFUKA_FLG,0);
            -- 届出番号
            RJIBTJUKIRIREKI_INS.TODOKEDE_NO := NVL(CR_IDO.TODOKEDE_NO,0);
            -- 取消届出番号
            RJIBTJUKIRIREKI_INS.TORIKESHI_TODOKEDE_NO := NVL(CR_IDO.TORIKESHI_TODOKEDE_NO,0);
            -- 宛名履歴_住記を登録する
            INSERT INTO JIBTJUKIRIREKI VALUES RJIBTJUKIRIREKI_INS;
            -- 宛名履歴_住記を更新する
            UPDATE JIBTJUKIRIREKI
               SET SAISHIN_FLG = 0
             WHERE KOJIN_NO = R_BUPD_ATENA.KOJIN_NO
               AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
               AND RIREKI_EDABAN = R_BUPD_ATENA.RIREKI_EDABAN;
          ELSE
--2024/04/03 DIS.Wangrucheng Add end
          INSERT INTO JIBTJUKIRIREKI
          (
            KOJIN_NO,
            RIREKI_RENBAN,
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
            RIREKI_EDABAN,   --履歴枝番
            SAISHIN_FLG,     --最新フラグ
            TORIKESHI_FLG,   --取消フラグ
            JOHYOYODATA_FLG, --除票用データフラグ
--2024/01/25 DIS.liuqimeng Add end
            TEKIYO_BI,
            TOROKU_GYOMU,
            SETAI_NO,
            GENZON_KBN,
            JUN_SETAI_KBN,
            JINKAKU_KBN,
            KOKUSEKI_CD,
            SHISHO_CD,
            CHIKU_CD,
            GYOSEIKU_CD,
            HAN_CD,
            SHOGAKU_CD,
            CHUGAKU_CD,
            TOHYOKU_CD,
            SANTEIDANTAI_CD,
            SEINENGAPI,
            WAREKI_SEINENGAPI,
            HYOJI_SEINENGAPI,
            SEIBETSU,
            USER_CD,
            OAZA_CD,
            HONBAN,
            EDABAN1,
            EDABAN2,
            EDABAN3,
            KATAGAKI_CD,
            GAIKU,
            TOU,
            GOU,
            JICHI_CD,
            SHIMEI_KANA,
            SHIMEI_KANJI,
            YUBIN_NO,
            YUBIN_NOBC,
            CHOMEI,
            BANCHI,
            KATAGAKI,
            DAIHYO_KATAGAKI,
            DAIHYO_SHIMEI,
            TEL_NO,
            TEL_KBN,
            FAX_NO,
            MAIL_ADS,
            YUHEN_KBN,
            TOROKU_JIYU,
            JUMINHYO_CD,
            ZOKUGARA_CD1,
            ZOKUGARA_CD2,
            ZOKUGARA_CD3,
            ZOKUGARA_CD4,
            ZOKUGARA_KBN,
            ZOKUGARA_MEI,
            JITSU_ZOKUGARA_MEI,
            KISAI_JUNI,
            IDO_BI,
            IDO_JIYU,
            IDO_TODOKE_BI,
            IDO_TODOKE_KBN,
            JUTEI_BI,
            JUTEI_JIYU,
            JUTEI_TODOKEDE_BI,
            JUTEI_TODOKEDE_KBN,
            GENJUSHO_REN,
            ZENJUSHO_REN,
            TENNYUMAE_REN,
            TENNYU_MITODOKE_REN,
            HONSEKI_REN,
            TENSHUTSU_YOTEI_BI,
            TENSHUTSU_YOTEI_TODOKEDE_BI,
            TENSHUTSU_YOTEI_TODOKEDE_KBN,
            TENSHUTSU_YOTEI_REN,
            TENSHUTSU_KAKUTEI_BI,
            TENSHUTSU_KAKUTEI_TSUCHI_BI,
            TENSHUTSU_KAKUTEI_TODOKEDE_KBN,
            TENSHUTSU_KAKUTEI_REN,
            JUMIN_NARU,
            JUMIN_NARU_JIYU,
            JUMIN_NARU_TODOKEDE_BI,
            JUMIN_NARU_TODOKEDE_KBN,
            JUMIN_NAKUNARU,
            JUMIN_NAKUNARU_JIYU,
            JUMIN_NAKUNARU_TODOKEDE_BI,
            JUMIN_NAKUNARU_TODOKEDE_KBN,
            SHIBOBI_FUSHO_KBN,
            HONMYO_KANA,
            HONMYO_KANJI,
            NUSHI_SHIMEI_KANA,
            NUSHI_SHIMEI_KANJI,
            BIKO,
            KAISEI_BI,
            KAISEI_REN,
            KYU_SHIMEI_KANA,
            KYU_SHIMEI_KANJI,
            SHORIBI_KEY,
            SHORI_JIKAN_KEY,
            SHORI_KBN_KEY,
            ZENBU_ICHIBU_KEY,
            SHOKUINKOJIN_NO_KEY,
            SYS_SAKUSEIBI,
            SYS_KOSHINBI,
            SYS_JIKAN,
            SYS_SHOKUINKOJIN_NO,
            SYS_TANMATSU_NO,
            GOMI_CD,
            SINYO_CD,
            KOIKIKOFU_STOP_CD,
            CHOMEI_KANA,
            BANCHI_KANA,
            KATAGAKI_KANA,
            KATAGAKI_HIDE_FLG,
            GAIJI_FLG,
            HOJINSOSHIKI_CD,
            JE_KOKUHOSHISANWARI_KBN,
            JE_JINTEKIGENMEN_KBN,
            JE_SHOYUSHAKEISHONIN_KBN,
            JE_LINK_KOJIN_NO,
            JE_NAYOSE_NO,
            YOBI1_CD,
            YOBI2_CD,
            YOBI3_CD,
            YOBI4_CD,
            YOBI5_CD,
            YOBI1_CH,
            YOBI2_CH,
            YOBI3_CH,
            YOBI4_CH,
            YOBI5_CH
            ,ALP_SHIMEI_KANA,
            ALP_SHIMEI_KANJI,
            GAI_SHIMEI_KANA,
            GAI_SHIMEI_KANJI,
            TSUSHOMEI_KANA,
            TSUSHOMEI_KANJI,
            HEIKIMEI_KANA,
            HEIKIMEI_KANJI,
            GAIKOKU_JUMIN_NARU,
            ZAIRYU_NO_SHUBETSU,
            ZAIRYU_CARD_NO,
            ZAIRYU_SHIKAKU_CD,
            ZAIRYU_SHURYO_BI,
            ZAIRYU_KIKAN_NEN,
            ZAIRYU_KIKAN_TSUKI,
            ZAIRYU_KIKAN_HI ,
            CARD_MANRYO_BI,
            KBN_30_45,
            KYOJYUCHI_UMU,
            SEINENGAPI_FUSHO_KBN,
            RYOKEN_BANGO,
            RYOKEN_HAKKO_BI,
            JORIKU_KYOKA_BI,
            JUMIN_NUSHI_SHIMEI
           ,TOUGOU_NO
           ,SEIDO_KOJIN_NO
           ,SEIDO_HOJIN_NO
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
           ,KETAPRM                        --住所_桁取パラメータ（基本データリスト用項目）
           ,KOKUMEI_CD                     --住所_国名コード（基本データリスト用項目）
           ,NYURYOKUBASHO                  --入力場所
           ,SHIMEI_KANA_FLG                --氏名カナフラグ
           ,TSUSHO_KANA_FLG                --通称カナフラグ
           ,JIJITSUJONOSETAINUSHI_KANA     --事実上の世帯主カナ
           ,JIJITSUJONOSETAINUSHI_KANJI    --事実上の世帯主漢字
           ,SAISYUTOROKUJUSHO_REN          --最終登録住所地連番
           ,SAISEIKISAI_DATE               --再製記載年月日
           ,SAISEIKISAIDATE_FUSHO_FLG      --再製記載年月日不詳フラグ
           ,SAISEIKISAIDATE_FUSHO_HYOKI    --再製記載年月日不詳表記
           ,SAISEISHOJODATE                --再製消除年月日
           ,SAISEISHOJODATE_FUSHO_FLG      --再製消除年月日不詳フラグ
           ,SAISEISHOJODATE_FUSHO_HYOKI    --再製消除年月日不詳表記
           ,KBN_30_46_47                   --法第30条46又は47区分
           ,SEINENGAPI_FUSHO_HYOKI         --生年月日不詳表記
           ,IDO_BI_FUSHO_FLG               --異動日不詳フラグ
           ,IDO_BI_FUSHO_HYOKI             --異動日不詳表記
           ,JUTEI_BI_FUSHO_FLG             --住定日不詳フラグ
           ,JUTEI_BI_FUSHO_HYOKI           --住定日不詳表記
           ,JUMIN_NARU_FUSHO_FLG           --住民となる日不詳フラグ
           ,JUMIN_NARU_FUSHO_HYOKI         --住民となる日不詳表記
           ,JUMIN_NAKUNARU_FUSHO_FLG       --住民でなくなる日不詳フラグ
           ,JUMIN_NAKUNARU_FUSHO_HYOKI     --住民でなくなる日不詳表記
           ,KAISEI_BI_FUSHO_FLG            --改製日不詳フラグ
           ,KAISEI_BI_FUSHO_HYOKI          --改製日不詳表記
           ,GAIKOKU_JUMIN_NARU_FUSHO_FLG   --外国人の住民となる日不詳フラグ
           ,GAIKOKU_JUMIN_NARU_FUSHO_HYOKI --外国人の住民となる日不詳表記
           ,SEIBETSU_FUSHO_KBN             --性別不詳区分
           ,IDO_JIYU_SHOSAI                --異動事由詳細
           ,IDOKOMOKU_1                    --異動項目_1
           ,RYUIJIKO_1                     --留意事項_1
           ,IDOKOMOKU_2                    --異動項目_2
           ,RYUIJIKO_2                     --留意事項_2
           ,IDOKOMOKU_3                    --異動項目_3
           ,RYUIJIKO_3                     --留意事項_3
           ,RIREKI_SENTAKUFUKA_FLG         --履歴選択不可フラグ
           ,TODOKEDE_NO                    --届出番号
           ,TORIKESHI_TODOKEDE_NO          --取消届出番号
--2024/01/25 DIS.liuqimeng Add end
          )
          VALUES
          (
            R_ATENA.KOJIN_NO,
            R_ATENA.RIREKI_RENBAN,
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
            R_ATENA.RIREKI_EDABAN,   --履歴枝番
--2024/04/03 DIS.Wangrucheng Update start 0.3.030.000:新WizLIFE２次開発（ph4対応）
--            R_ATENA.SAISHIN_FLG,     --最新フラグ
--            R_ATENA.TORIKESHI_FLG,   --取消フラグ
            CASE
                WHEN CR_IDO.IDO_JIYU IN (141,292,418) THEN 1
		--2024/12/6 CTC Update start 0.3.000.000:IT_JIB_00736対応
                WHEN CR_IDO.IDO_JIYU =412 THEN 0
                --2024/12/6 CTC Update end
                ELSE R_ATENA.SAISHIN_FLG
            END,                     --最新フラグ
            CASE
                WHEN CR_IDO.IDO_JIYU IN (141,292,418) THEN 1
                ELSE R_ATENA.TORIKESHI_FLG
            END,                     --取消フラグ
--2024/04/03 DIS.Wangrucheng Update end
            R_ATENA.JOHYOYODATA_FLG, --除票用データフラグ
--2024/01/25 DIS.liuqimeng Add end
            R_ATENA.TEKIYO_BI,
            R_ATENA.TOROKU_GYOMU,
            R_ATENA.SETAI_NO,
            R_ATENA.GENZON_KBN,
            NVL(R_IDO.JUN_SETAI_KBN, 0),
            R_ATENA.JINKAKU_KBN,
            R_ATENA.KOKUSEKI_CD,
            R_ATENA.SHISHO_CD,
            R_ATENA.CHIKU_CD,
            R_ATENA.GYOSEIKU_CD,
            R_ATENA.HAN_CD,
            R_ATENA.SHOGAKU_CD,
            R_ATENA.CHUGAKU_CD,
            R_ATENA.TOHYOKU_CD,
            R_ATENA.SANTEIDANTAI_CD,
            R_ATENA.SEINENGAPI,
            R_ATENA.WAREKI_SEINENGAPI,
            R_ATENA.HYOJI_SEINENGAPI,
            R_ATENA.SEIBETSU,
            R_ATENA.USER_CD,
            R_ATENA.OAZA_CD,
            R_ATENA.HONBAN,
            R_ATENA.EDABAN1,
            R_ATENA.EDABAN2,
            R_ATENA.EDABAN3,
            R_ATENA.KATAGAKI_CD,
            R_ATENA.GAIKU,
            R_ATENA.TOU,
            R_ATENA.GOU,
            R_ATENA.JICHI_CD,
            R_ATENA.SHIMEI_KANA,
            R_ATENA.SHIMEI_KANJI,
            R_ATENA.YUBIN_NO,
            R_ATENA.YUBIN_NOBC,
            R_ATENA.CHOMEI,
            R_ATENA.BANCHI,
            R_ATENA.KATAGAKI,
            R_ATENA.DAIHYO_KATAGAKI,
            R_ATENA.DAIHYO_SHIMEI,
            R_ATENA.TEL_NO,
            R_ATENA.TEL_KBN,
            R_ATENA.FAX_NO,
            R_ATENA.MAIL_ADS,
            R_ATENA.YUHEN_KBN,
            R_ATENA.TOROKU_JIYU,
            NVL(R_IDO.JUMINHYO_CD, 0),
            NVL(R_ATENA.ZOKUGARACD1, 0),
            NVL(R_ATENA.ZOKUGARACD2, 0),
            NVL(R_ATENA.ZOKUGARACD3, 0),
            NVL(R_ATENA.ZOKUGARACD4, 0),
            NVL(R_ATENA.ZOKUGARAKBN, 0),
            R_ATENA.ZOKUGARAMEI,
            R_ATENA.JITSUZOKUGARAMEI,
            NVL(R_IDO.KISAI_JUNI, 0),
            NVL(R_IDO.IDO_BI, 0),
            NVL(R_IDO.IDO_JIYU, 0),
            NVL(R_IDO.IDO_TODOKE_BI, 0),
            NVL(R_IDO.IDO_TODOKE_KBN, 0),
            NVL(R_IDO.JUTEI_BI, 0),
            NVL(R_IDO.JUTEI_JIYU, 0),
            NVL(R_IDO.JUTEI_TODOKEDE_BI, 0),
            NVL(R_IDO.JUTEI_TODOKEDE_KBN, 0),
            NVL(R_IDO.GENJUSHO_REN, 0),
            NVL(R_IDO.ZENJUSHO_REN, 0),
            NVL(R_IDO.TENNYUMAE_REN, 0),
            NVL(R_IDO.TENNYU_MITODOKE_REN, 0),
            NVL(R_IDO.HONSEKI_REN, 0),
            NVL(R_IDO.TENSHUTSU_YOTEI_BI, 0),
            NVL(R_IDO.TENSHUTSU_YOTEI_TODOKEDE_BI, 0),
            NVL(R_IDO.TENSHUTSU_YOTEI_TODOKEDE_KBN, 0),
            NVL(R_IDO.TENSHUTSU_YOTEI_REN, 0),
            NVL(R_IDO.TENSHUTSU_KAKUTEI_BI, 0),
            NVL(R_IDO.TENSHUTSU_KAKUTEI_TSUCHI_BI, 0),
            NVL(R_IDO.TENSHUTSU_KAKUTEI_TODOKEDE_KBN, 0),
            NVL(R_IDO.TENSHUTSU_KAKUTEI_REN, 0),
            NVL(R_IDO.JUMIN_NARU, 0),
            NVL(R_IDO.JUMIN_NARU_JIYU, 0),
            NVL(R_IDO.JUMIN_NARU_TODOKEDE_BI, 0),
            NVL(R_IDO.JUMIN_NARU_TODOKEDE_KBN, 0),
            NVL(R_IDO.JUMIN_NAKUNARU, 0),
            NVL(R_IDO.JUMIN_NAKUNARU_JIYU, 0),
            NVL(R_IDO.JUMIN_NAKUNARU_TODOKEDE_BI, 0),
            NVL(R_IDO.JUMIN_NAKUNARU_TODOKEDE_KBN, 0),
            NVL(R_IDO.SHIBOBI_FUSHO_KBN, 0),
            R_ATENA.HONMYO_KANA,
            R_ATENA.HONMYO_KANJI,
            R_IDO.NUSHI_SHIMEI_KANA,
            R_IDO.NUSHI_SHIMEI_KANJI,
            R_IDO.BIKO,
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--            NVL(R_IDO.KAISEI_BI, 0),
--            NVL(R_IDO.KAISEI_REN, 0),
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
            --CASE
               -- WHEN R_IDO.IDO_JIYU IN (191,291) THEN i_SHORIBI
               -- ELSE NVL(R_IDO.KAISEI_BI, 0)
            --END,
            --CASE
               -- WHEN R_IDO.IDO_JIYU IN (191,291) THEN R_IDO.KAISEI_REN + 1
               -- ELSE NVL(R_IDO.KAISEI_REN, 0)
            --END,
            NVL(R_IDO.KAISEI_BI, 0),
            R_IDO.KAISEI_REN,
--2025/5/14 CTC.liu update end
--2024/01/25 DIS.liuqimeng Update end
            R_IDO.KYU_SHIMEI_KANA,
            R_IDO.KYU_SHIMEI_KANJI,
            NVL(R_IDO.SHORIBI_KEY, 0),
            NVL(R_IDO.SHORI_JIKAN_KEY, 0),
            NVL(R_IDO.SHORI_KBN_KEY, 0),
            NVL(R_IDO.ZENBU_ICHIBU_KEY, 0),
            NVL(R_IDO.SHOKUINKOJIN_NO_KEY, 0),
            R_ATENA.SYS_SAKUSEIBI,
            R_ATENA.SYS_KOSHINBI,
            R_ATENA.SYS_JIKAN,
            R_ATENA.SYS_SHOKUINKOJIN_NO,
            R_ATENA.SYS_TANMATSU_NO,
            R_IDO.GOMI_CD,
            R_IDO.SINYO_CD,
            R_IDO.KOIKIKOFU_STOP_CD,
            R_ATENA.CHOMEI_KANA,
            R_ATENA.BANCHI_KANA,
            R_ATENA.KATAGAKI_KANA,
            R_ATENA.KATAGAKI_HIDE_FLG,
            R_ATENA.GAIJI_FLG,
            R_ATENA.HOJINSOSHIKI_CD,
            R_ATENA.JE_KOKUHOSHISANWARI_KBN,
            R_ATENA.JE_JINTEKIGENMEN_KBN,
            R_ATENA.JE_SHOYUSHAKEISHONIN_KBN,
            R_ATENA.JE_LINK_KOJIN_NO,
            R_ATENA.JE_NAYOSE_NO,
            R_ATENA.YOBI1_CD,
            R_ATENA.YOBI2_CD,
            R_ATENA.YOBI3_CD,
            R_ATENA.YOBI4_CD,
            R_ATENA.YOBI5_CD,
            R_ATENA.YOBI1_CH,
            R_ATENA.YOBI2_CH,
            R_ATENA.YOBI3_CH,
            R_ATENA.YOBI4_CH,
            R_ATENA.YOBI5_CH
            ,R_IDO.ALP_SHIMEI_KANA,
            R_IDO.ALP_SHIMEI_KANJI,
            R_IDO.GAI_SHIMEI_KANA,
            R_IDO.GAI_SHIMEI_KANJI,
            R_IDO.TSUSHOMEI_KANA,
            R_IDO.TSUSHOMEI_KANJI,
            R_IDO.HEIKIMEI_KANA,
            R_IDO.HEIKIMEI_KANJI,
            R_IDO.GAIKOKU_JUMIN_NARU,
            R_IDO.ZAIRYU_NO_SHUBETSU,
            R_IDO.ZAIRYU_CARD_NO,
            R_IDO.ZAIRYU_SHIKAKU_CD,
            R_IDO.ZAIRYU_SHURYO_BI,
            R_IDO.ZAIRYU_KIKAN_NEN,
            R_IDO.ZAIRYU_KIKAN_TSUKI,
            R_IDO.ZAIRYU_KIKAN_HI,
            R_IDO.CARD_MANRYO_BI,
            R_IDO.KBN_30_45,
            R_IDO.KYOJYUCHI_UMU,
            R_IDO.SEINENGAPI_FUSHO_KBN,
            R_IDO.RYOKEN_BANGO,
            R_IDO.RYOKEN_HAKKO_BI,
            R_IDO.JORIKU_KYOKA_BI,
            R_IDO.JUMIN_NUSHI_SHIMEI

           ,R_ATENA.TOUGOU_NO
           ,R_IDO.SEIDO_KOJIN_NO
           ,R_ATENA.SEIDO_HOJIN_NO
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
           ,R_ATENA.KETAPRM                      --住所_桁取パラメータ（基本データリスト用項目）
           ,R_ATENA.KOKUMEI_CD                   --住所_国名コード（基本データリスト用項目）
           ,VCHOSHACODE                           --入力場所
           ,R_IDO.SHIMEI_KANA_FLG                --氏名カナフラグ
           ,R_IDO.TSUSHO_KANA_FLG                --通称カナフラグ
           ,R_IDO.JIJITSUJONOSETAINUSHI_KANA     --事実上の世帯主カナ
           ,R_IDO.JIJITSUJONOSETAINUSHI_KANJI    --事実上の世帯主漢字
           ,R_IDO.SAISYUTOROKUJUSHO_REN          --最終登録住所地連番
           ,R_IDO.SAISEIKISAI_DATE               --再製記載年月日
           ,R_IDO.SAISEIKISAIDATE_FUSHO_FLG      --再製記載年月日不詳フラグ
           ,R_IDO.SAISEIKISAIDATE_FUSHO_HYOKI    --再製記載年月日不詳表記
           ,R_IDO.SAISEISHOJODATE                --再製消除年月日
           ,R_IDO.SAISEISHOJODATE_FUSHO_FLG      --再製消除年月日不詳フラグ
           ,R_IDO.SAISEISHOJODATE_FUSHO_HYOKI    --再製消除年月日不詳表記
           ,R_IDO.KBN_30_46_47                   --法第30条46又は47区分
           ,R_IDO.SEINENGAPI_FUSHO_HYOKI         --生年月日不詳表記
           ,R_IDO.IDO_BI_FUSHO_FLG               --異動日不詳フラグ
           ,R_IDO.IDO_BI_FUSHO_HYOKI             --異動日不詳表記
           ,R_IDO.JUTEI_BI_FUSHO_FLG             --住定日不詳フラグ
           ,R_IDO.JUTEI_BI_FUSHO_HYOKI           --住定日不詳表記
           ,R_IDO.JUMIN_NARU_FUSHO_FLG           --住民となる日不詳フラグ
           ,R_IDO.JUMIN_NARU_FUSHO_HYOKI         --住民となる日不詳表記
           ,R_IDO.JUMIN_NAKUNARU_FUSHO_FLG       --住民でなくなる日不詳フラグ
           ,R_IDO.JUMIN_NAKUNARU_FUSHO_HYOKI     --住民でなくなる日不詳表記
           ,R_IDO.KAISEI_BI_FUSHO_FLG            --改製日不詳フラグ
           ,R_IDO.KAISEI_BI_FUSHO_HYOKI          --改製日不詳表記
           ,R_IDO.GAIKOKU_JUMIN_NARU_FUSHO_FLG   --外国人の住民となる日不詳フラグ
           ,R_IDO.GAIKOKU_JUMIN_NARU_FUSHO_HYOKI --外国人の住民となる日不詳表記
           ,R_IDO.SEIBETSU_FUSHO_KBN             --性別不詳区分
           ,R_IDO.IDO_JIYU_SHOSAI                --異動事由詳細
           ,R_IDO.IDOKOMOKU_1                    --異動項目_1
           ,R_IDO.RYUIJIKO_1                     --留意事項_1
           ,R_IDO.IDOKOMOKU_2                    --異動項目_2
           ,R_IDO.RYUIJIKO_2                     --留意事項_2
           ,R_IDO.IDOKOMOKU_3                    --異動項目_3
           ,R_IDO.RYUIJIKO_3                     --留意事項_3
           ,R_IDO.RIREKI_SENTAKUFUKA_FLG         --履歴選択不可フラグ
           ,R_IDO.TODOKEDE_NO                    --届出番号
           ,R_IDO.TORIKESHI_TODOKEDE_NO          --取消届出番号
--2024/01/25 DIS.liuqimeng Add end

          );
--2024/04/03 DIS.Wangrucheng Add start 0.3.030.000:新WizLIFE２次開発（ph4対応）
          END IF;
          -- 異動事由は「141:異動取消（増）、292:異動取消（減）、418:異動取消（修正）」の場合
          IF CR_IDO.IDO_JIYU IN (141,292,418) THEN
            -- 宛名履歴_住記を更新する
            UPDATE JIBTJUKIRIREKI
--               SET SAISHIN_FLG = 0  --2025/02/23 Del
               SET TORIKESHI_FLG = 1  --2025/02/23 Add
                  ,RIREKI_SENTAKUFUKA_FLG = 1  --2025/02/23 Add
             WHERE KOJIN_NO = R_BUPD_ATENA.KOJIN_NO
               AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
               AND RIREKI_EDABAN = R_BUPD_ATENA.RIREKI_EDABAN;
/*            -- 履歴枝番＜＞１の場合  --2025/02/23 Del
            IF R_BUPD_ATENA.RIREKI_EDABAN <> 1 THEN
              -- 宛名履歴_住記を更新する
              UPDATE JIBTJUKIRIREKI
                 SET SAISHIN_FLG = 0
               WHERE KOJIN_NO = R_BUPD_ATENA.KOJIN_NO
                 AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
                 AND RIREKI_EDABAN = R_BUPD_ATENA.RIREKI_EDABAN - 1;
            --履歴枝番=１の場合
            ELSE
              SELECT MAX(RIREKI_EDABAN)
                INTO NRIREKI_EDABAN
                FROM JIBTJUKIRIREKI
               WHERE KOJIN_NO = R_BUPD_ATENA.KOJIN_NO
                 AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN - 10;
              -- 宛名履歴_住記を更新する
              UPDATE JIBTJUKIRIREKI
                 SET SAISHIN_FLG = 0
               WHERE KOJIN_NO = R_BUPD_ATENA.KOJIN_NO
                 AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN - 10
                 AND RIREKI_EDABAN = NRIREKI_EDABAN;
            END IF;  */
          END IF;
--2024/04/03 DIS.Wangrucheng Add end
        END IF;
      END IF;
--2024/04/03 DIS.Wangrucheng Add start 0.3.030.000:新WizLIFE２次開発（ph4対応）
      -- 異動事由は「141:異動取消（増）、292:異動取消（減）、418:異動取消（修正）」の場合
      IF CR_IDO.IDO_JIYU IN (141,292,418) THEN
        SELECT B.RIREKI_RENBAN
          INTO NRIREKI_RENBAN
          FROM JIBTJUKIIDO A,
               JIBTJUKIKIHON B
         WHERE A.KOJIN_NO = B.KOJIN_NO
           AND A.KOJIN_NO = CR_IDO.KOJIN_NO;
      END IF;
--2024/04/03 DIS.Wangrucheng Add end
--2024/10/21 DIS.liuqimeng Add Start 0.3.000.000:IT_JIB_00229対応
      --2.異動事由は「誤記修正」、「異動取消（増）（減）（修正）」の場合
      --「412:誤記修正、141:異動取消（増）、292:異動取消（減）、418:異動取消（修正）」
      IF CR_IDO.IDO_JIYU IN (412,141,292,418) THEN
        --「特別養子縁組」又は「特別養子縁組の離縁」の留意事項がある場合
        IF CR_IDO.RYUIJIKO_1 IN ('特別養子縁組','特別養子縁組の離縁')
          OR CR_IDO.RYUIJIKO_2 IN ('特別養子縁組','特別養子縁組の離縁')
          OR CR_IDO.RYUIJIKO_3 IN ('特別養子縁組','特別養子縁組の離縁') THEN
          UPDATE JIBTJUKIRIREKI
             SET RIREKI_SENTAKUFUKA_FLG = 1
           WHERE KOJIN_NO = R_BUPD_ATENA.KOJIN_NO
             AND RIREKI_RENBAN * 10 + RIREKI_EDABAN <= R_BUPD_ATENA.RIREKI_RENBAN * 10 + R_BUPD_ATENA.RIREKI_EDABAN;
        END IF;
--2025/11/13 CTC.liu add start:1.0.027.000 保守QA22566対応
        IF CR_IDO.IDO_JIYU = 412 THEN
            UPDATE JIBTJUKIRIREKI
               SET RIREKI_SENTAKUFUKA_FLG = 1
             WHERE KOJIN_NO = R_BUPD_ATENA.KOJIN_NO
               AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
               AND RIREKI_EDABAN <= R_BUPD_ATENA.RIREKI_EDABAN;
           END IF;
--2025/11/13 CTC.liu add end
      --1.異動事由は「誤記修正」、「異動取消（増）（減）（修正）」以外の場合
      ELSE
        --留意事項_1,留意事項_2,留意事項_3
        BEGIN
         SELECT RYUIJIKO_1,RYUIJIKO_2,RYUIJIKO_3
           INTO VRYUIJIKO_1,VRYUIJIKO_2,VRYUIJIKO_3
           FROM JIBWBUPD_JUKIIDO
          WHERE KOJIN_NO = R_BUPD_ATENA.KOJIN_NO
            AND ENTRY_ID = i_IENTRY_ID;
        EXCEPTION
          WHEN OTHERS THEN
            VRYUIJIKO_1 := NULL;
            VRYUIJIKO_2 := NULL;
            VRYUIJIKO_3 := NULL;
        END;
        --「特別養子縁組」又は「特別養子縁組の離縁」の留意事項がある場合
        IF VRYUIJIKO_1 IN ('特別養子縁組','特別養子縁組の離縁')
          OR VRYUIJIKO_2 IN ('特別養子縁組','特別養子縁組の離縁')
          OR VRYUIJIKO_3 IN ('特別養子縁組','特別養子縁組の離縁') THEN
          UPDATE JIBTJUKIRIREKI
             SET RIREKI_SENTAKUFUKA_FLG = 1
           WHERE KOJIN_NO = R_BUPD_ATENA.KOJIN_NO;
        END IF;
      END IF;
--2024/10/21 DIS.liuqimeng Add end
--2025/10/29 CTC.liu add start 1.0.025.002:新WizLIFE保守対応 QA22490
--住登外履歴連番取得
      BEGIN
      SELECT RIREKI_RENBAN INTO GAB_RIREKI_RENBAN
       FROM GABTATENAKIHON
      WHERE KOJIN_NO = R_BUPD_ATENA.KOJIN_NO
        AND GENZON_KBN= 2;
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
           GAB_RIREKI_RENBAN:=0;
     END;
      ------------------------------------------------
      -- 宛名基本ＴＢＬデータ削除
      ------------------------------------------------
        IF I_CNT1 != 0 THEN
          IF NKADO_BI5 <= I_SYSDATE AND
             NJOKEN111 = 0 AND
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--             CR_IDO.IDO_JIYU IN (15,16,28) THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
            --CR_IDO.IDO_JIYU IN (150,160,280) THEN
             CR_IDO.IDO_JIYU IN (150,160,280,191) THEN
               NULL;
	  --2024/12/6 CTC Update start 0.3.000.000:IT_JIB_00736対応
          --ELSE
          ELSE
           IF (R_ATENA.RIREKI_RENBAN *100 +R_ATENA.RIREKI_EDABAN <= R_BUPD_ATENA.RIREKI_RENBAN *100 +R_BUPD_ATENA.RIREKI_EDABAN) or CR_IDO.IDO_JIYU <>412 THEN
            DELETE FROM JIBTJUKIKIHON
                  WHERE KOJIN_NO = CR_IDO.KOJIN_NO;
            END IF;
           --2024/12/6 CTC Update end
          END IF;
        ELSIF A_CNT != 0 THEN
          IF NKADO_BI5 <= I_SYSDATE AND
             NJOKEN111 = 0 AND
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--             CR_IDO.IDO_JIYU IN (15,16,28) THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
            --CR_IDO.IDO_JIYU IN (150,160,280) THEN
             CR_IDO.IDO_JIYU IN (150,160,280,191) THEN
               NULL;
	 --2024/12/6 CTC Update start 0.3.000.000:IT_JIB_00736対応
         --ELSE
          ELSE
           IF (R_ATENA.RIREKI_RENBAN *100 +R_ATENA.RIREKI_EDABAN <= R_BUPD_ATENA.RIREKI_RENBAN *100 +R_BUPD_ATENA.RIREKI_EDABAN) or CR_IDO.IDO_JIYU <>412 THEN
            DELETE FROM JIBTJUKIKIHON
                  WHERE KOJIN_NO = CR_IDO.KOJIN_NO;
           END IF;
         --2024/12/6 CTC Update end
          END IF;
        END IF;
      ------------------------------------------------
      -- 個人番号採番判定
      ------------------------------------------------
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--      IF R_BUPD_ATENA.KOJIN_NO > 999999900000 OR (NJOKEN111 = 0 AND CR_IDO.IDO_JIYU IN (15,16,28)) THEN
--2024/04/03 DIS.Wangrucheng Update 0.3.030.000:新WizLIFE２次開発（ph4対応）
--      IF R_BUPD_ATENA.KOJIN_NO > 999999900000 OR (NJOKEN111 = 0 AND CR_IDO.IDO_JIYU IN (150,160,280)) THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
      --IF R_BUPD_ATENA.KOJIN_NO > 999999999900000 OR (NJOKEN111 = 0 AND CR_IDO.IDO_JIYU IN (150,160,280)) THEN
      IF R_BUPD_ATENA.KOJIN_NO > 999999999900000 OR (NJOKEN111 = 0 AND CR_IDO.IDO_JIYU IN (150,160,280,191)) THEN
        T_MAX_KOJIN_NO := GAAPK0030.FNEWNOGET('JIB',
                                                0,
                                                0,
                                                i_NTANMATSU_NO,
                                                i_NSHOKUIN,
                                                NRTN);
            --リターン値 <> 0の場合
            IF NRTN != 0 THEN
              o_N_SQL_CODE  := NRTN;
              o_V_SQL_MSG := '新規付番取得エラー';
              RETURN;
            END IF;
        T_KOJIN_NO     := T_MAX_KOJIN_NO;
        UPDATE JIBWBUPD_GYOMUSHIKAKU
           SET KOJIN_NO = T_MAX_KOJIN_NO
         WHERE ENTRY_ID = i_IENTRY_ID
           AND KOJIN_NO = R_BUPD_ATENA.KOJIN_NO;
      ELSE
        T_KOJIN_NO := R_BUPD_ATENA.KOJIN_NO;
      END IF;

      ------------------------------------------------
      -- 住民票コード採番判定
      ------------------------------------------------
      SELECT IDO_JIYU_KBN
        INTO T_JIYU_KBN
        FROM GABTIDOJIYU
       WHERE IDO_JIYU_CD = CR_IDO.IDO_JIYU;

      IF R_BUPD_ATENA.JUMINHYO_CD = 0 AND
         ((T_JIYU_KBN = 1) OR
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--          CR_IDO.IDO_JIYU = 47 OR
--          CR_IDO.IDO_JIYU = 48 OR
--        (T_JIYU_KBN = 4 AND CR_IDO.IDO_JIYU IN (15,16))) THEN
          CR_IDO.IDO_JIYU = 470 OR
          CR_IDO.IDO_JIYU = 480 OR
        (T_JIYU_KBN = 4 AND CR_IDO.IDO_JIYU IN (150,160))) THEN
--2024/01/25 DIS.liuqimeng Update end
        IF CR_IDO.JINKAKU_KBN = 1 AND
           NKADO_BI6 > I_SYSDATE THEN
           T_JUMIN_CD := R_BUPD_ATENA.JUMINHYO_CD;
        ELSE
           LOOP
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--             JIBSKJUMINCD(T_KOJIN_NO,I_SYSDATE,T_MAX_JUMINHYO_CD,RTNCD);
             JIBSKJUMINCD(T_KOJIN_NO,I_SYSDATE,i_NSHOKUIN,T_MAX_JUMINHYO_CD,RTNCD);
             BEGIN
               SELECT SHIYOSHA_KOJIN_NO INTO WK_KOJIN_NO FROM JIBTJNAKINOKANRI
                WHERE JUMINHYO_CD = T_MAX_JUMINHYO_CD;
             EXCEPTION
               WHEN OTHERS THEN
                WK_KOJIN_NO := 0;
             END;
             EXIT WHEN (T_MAX_JUMINHYO_CD <> 0 AND T_KOJIN_NO = WK_KOJIN_NO);
           END LOOP;
           T_JUMIN_CD := T_MAX_JUMINHYO_CD;
        END IF;
      ELSE
        T_JUMIN_CD := R_BUPD_ATENA.JUMINHYO_CD;
      END IF;
      ------------------------------------------------
      -- 世帯番号採番判定
      ------------------------------------------------
--2024/04/03 DIS.Wangrucheng Update 0.3.030.000:新WizLIFE２次開発（ph4対応）
--      IF R_BUPD_ATENA.SETAI_NO > 9999000 THEN
      IF R_BUPD_ATENA.SETAI_NO > 999999999900000 THEN
        IF (T_MAX_SETAI_NO IS NULL) THEN
          T_MAX_SETAI_NO := GAAPK0030.FNEWNOGET('JIB',
                                                  0,
                                                  1,
                                                  i_NTANMATSU_NO,
                                                  i_NSHOKUIN,
                                                  NRTN);
            --リターン値 <> 0の場合
            IF NRTN != 0 THEN
              T_MAX_SETAI_NO := 0;
            END IF;
          -- 発行注意書きをコピー
          PROC_COPY_HAKKOCHUI(R_IDO.SETAI_NO, T_MAX_SETAI_NO);
        END IF;
        T_SETAI_NO     := T_MAX_SETAI_NO;
      ELSE
        T_SETAI_NO := R_BUPD_ATENA.SETAI_NO;
        -- 発行注意書きをコピー
        PROC_COPY_HAKKOCHUI(R_IDO.SETAI_NO, T_SETAI_NO);
      END IF;
      IF NKADO_BI5 <= I_SYSDATE THEN
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--         IF CR_IDO.IDO_JIYU IN (15,16,28) AND NJOKEN111 = 1 THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
        --IF CR_IDO.IDO_JIYU IN (150,160,280) AND NJOKEN111 = 1 THEN
         IF CR_IDO.IDO_JIYU IN (150,160,280,191) AND NJOKEN111 = 1 THEN
            T_RIREKI_RENBAN := R_BUPD_ATENA.RIREKI_RENBAN + 10;
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--         ELSIF CR_IDO.IDO_JIYU IN (15,16,28) AND NJOKEN111 = 0 THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
        --ELSIF CR_IDO.IDO_JIYU IN (150,160,280) AND NJOKEN111 = 0 THEN
         ELSIF CR_IDO.IDO_JIYU IN (150,160,280,191) AND NJOKEN111 = 0 THEN
            T_RIREKI_RENBAN := 10;
         ELSE
            T_RIREKI_RENBAN := R_BUPD_ATENA.RIREKI_RENBAN;
         END IF;
      ELSE
         T_RIREKI_RENBAN := R_BUPD_ATENA.RIREKI_RENBAN;
      END IF;
--2024/04/03 DIS.Wangrucheng Add start 0.3.030.000:新WizLIFE２次開発（ph4対応）
      -- 異動事由は「141:異動取消（増）、292:異動取消（減）、418:異動取消（修正）」の場合
      IF CR_IDO.IDO_JIYU IN (141,292,418) THEN
        T_RIREKI_RENBAN := NRIREKI_RENBAN + 10;
      END IF;
--2024/04/03 DIS.Wangrucheng Add end
--2025/10/29 CTC.liu add start 1.0.025.002:新WizLIFE保守対応 QA22490
       IF GAB_RIREKI_RENBAN <> 0 THEN
          T_RIREKI_RENBAN := GAB_RIREKI_RENBAN+10;
       END IF;
      ------------------------------------------------
      -- 宛名基本ＴＢＬ追加
      ------------------------------------------------
--2024/12/6 CTC Update start 0.3.000.000:IT_JIB_00736対応
 IF (R_ATENA.RIREKI_RENBAN *100 +R_ATENA.RIREKI_EDABAN <= R_BUPD_ATENA.RIREKI_RENBAN *100 +R_BUPD_ATENA.RIREKI_EDABAN)
 										or CR_IDO.IDO_JIYU <> 412 THEN
      INSERT INTO JIBTJUKIKIHON
      (
        KOJIN_NO,
        RIREKI_RENBAN,
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
        RIREKI_EDABAN,   --履歴枝番
        SAISHIN_FLG,     --最新フラグ
        TORIKESHI_FLG,   --取消フラグ
        JOHYOYODATA_FLG, --除票用データフラグ
--2024/01/25 DIS.liuqimeng Add end
        TEKIYO_BI,
        TOROKU_GYOMU,
        JUMINHYO_CD,
        SETAI_NO,
        GENZON_KBN,
        JINKAKU_KBN,
        KOKUSEKI_CD,
        SHISHO_CD,
        CHIKU_CD,
        GYOSEIKU_CD,
        HAN_CD,
        SHOGAKU_CD,
        CHUGAKU_CD,
        TOHYOKU_CD,
        SANTEIDANTAI_CD,
        SEINENGAPI,
        WAREKI_SEINENGAPI,
        HYOJI_SEINENGAPI,
        SEIBETSU,
        USER_CD,
        OAZA_CD,
        HONBAN,
        EDABAN1,
        EDABAN2,
        EDABAN3,
        KATAGAKI_CD,
        GAIKU,
        TOU,
        GOU,
        JICHI_CD,
        SHIMEI_KANA,
        SHIMEI_KANJI,
        HONMYO_KANA,
        HONMYO_KANJI,
        YUBIN_NO,
        YUBIN_NOBC,
        CHOMEI,
        BANCHI,
        KATAGAKI,
        DAIHYO_KATAGAKI,
        DAIHYO_SHIMEI,
        TEL_NO,
        TEL_KBN,
        FAX_NO,
        MAIL_ADS,
        YUHEN_KBN,
        TOROKU_JIYU,
        JUFUKU_KOJIN_NO,
        SYS_SAKUSEIBI,
        SYS_KOSHINBI,
        SYS_JIKAN,
        SYS_SHOKUINKOJIN_NO,
        SYS_TANMATSU_NO,
        CHOMEI_KANA,
        BANCHI_KANA,
        KATAGAKI_KANA,
        KATAGAKI_HIDE_FLG,
        GAIJI_FLG,
        HOJINSOSHIKI_CD,
        JE_KOKUHOSHISANWARI_KBN,
        JE_JINTEKIGENMEN_KBN,
        JE_SHOYUSHAKEISHONIN_KBN,
        JE_LINK_KOJIN_NO,
        JE_NAYOSE_NO,
        YOBI1_CD,
        YOBI2_CD,
        YOBI3_CD,
        YOBI4_CD,
        YOBI5_CD,
        YOBI1_CH,
        YOBI2_CH,
        YOBI3_CH,
        YOBI4_CH,
        YOBI5_CH

       ,TOUGOU_NO
       ,SEIDO_KOJIN_NO
       ,SEIDO_HOJIN_NO
       ,ZOKUGARACD1
       ,ZOKUGARACD2
       ,ZOKUGARACD3
       ,ZOKUGARACD4
       ,ZOKUGARAKBN
       ,ZOKUGARAMEI
       ,JITSUZOKUGARAMEI
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
       ,KETAPRM                   --住所_桁取パラメータ（基本データリスト用項目）
       ,KOKUMEI_CD                --住所_国名コード（住登外者宛名番号管理の基本データリスト用項目）
--2024/01/25 DIS.liuqimeng Add end

      )
      VALUES
      (
        T_KOJIN_NO,
        T_RIREKI_RENBAN,
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
        CASE
--2024/04/03 DIS.Wangrucheng Update 0.3.030.000:新WizLIFE２次開発（ph4対応）
--            WHEN CR_IDO.IDO_JIYU IN (150,160,280) THEN 1     --履歴枝番
--2024/03/26 DIS.liuqimeng Update 0.3.000.000:受入検証指摘対応
--            WHEN CR_IDO.IDO_JIYU IN (150,160,280,141,292,418) THEN 1     --履歴枝番
--2024/08/02 DIS.chenming Update 0.3.000.000:IT_JIB_00115対応
--            WHEN CR_IDO.IDO_JIYU IN (150,160,240,141,292,418) THEN 1     --履歴枝番
            WHEN CR_IDO.IDO_JIYU != 412 THEN 1     --履歴枝番
            ELSE R_BUPD_ATENA.RIREKI_EDABAN + 1
        END,
        1,       --最新フラグ
        0,       --取消フラグ
        0,       --除票用データフラグ
--2024/01/25 DIS.liuqimeng Add end
        R_BUPD_ATENA.TEKIYO_BI,
        R_BUPD_ATENA.TOROKU_GYOMU,
        T_JUMIN_CD,
        T_SETAI_NO,
        R_BUPD_ATENA.GENZON_KBN,
        R_BUPD_ATENA.JINKAKU_KBN,
        R_BUPD_ATENA.KOKUSEKI_CD,
        R_BUPD_ATENA.SHISHO_CD,
        R_BUPD_ATENA.CHIKU_CD,
        R_BUPD_ATENA.GYOSEIKU_CD,
        R_BUPD_ATENA.HAN_CD,
        R_BUPD_ATENA.SHOGAKU_CD,
        R_BUPD_ATENA.CHUGAKU_CD,
        R_BUPD_ATENA.TOHYOKU_CD,
        R_BUPD_ATENA.SANTEIDANTAI_CD,
        R_BUPD_ATENA.SEINENGAPI,
        R_BUPD_ATENA.WAREKI_SEINENGAPI,
        R_BUPD_ATENA.HYOJI_SEINENGAPI,
        R_BUPD_ATENA.SEIBETSU,
        R_BUPD_ATENA.USER_CD,
        R_BUPD_ATENA.OAZA_CD,
        R_BUPD_ATENA.HONBAN,
        R_BUPD_ATENA.EDABAN1,
        R_BUPD_ATENA.EDABAN2,
        R_BUPD_ATENA.EDABAN3,
        R_BUPD_ATENA.KATAGAKI_CD,
        R_BUPD_ATENA.GAIKU,
        R_BUPD_ATENA.TOU,
        R_BUPD_ATENA.GOU,
        R_BUPD_ATENA.JICHI_CD,
        R_BUPD_ATENA.SHIMEI_KANA,
        R_BUPD_ATENA.SHIMEI_KANJI,
        R_BUPD_ATENA.HONMYO_KANA,
        R_BUPD_ATENA.HONMYO_KANJI,
        R_BUPD_ATENA.YUBIN_NO,
        R_BUPD_ATENA.YUBIN_NOBC,
        R_BUPD_ATENA.CHOMEI,
        R_BUPD_ATENA.BANCHI,
        R_BUPD_ATENA.KATAGAKI,
        R_BUPD_ATENA.DAIHYO_KATAGAKI,
        R_BUPD_ATENA.DAIHYO_SHIMEI,
        R_BUPD_ATENA.TEL_NO,
        R_BUPD_ATENA.TEL_KBN,
        R_BUPD_ATENA.FAX_NO,
        R_BUPD_ATENA.MAIL_ADS,
        R_BUPD_ATENA.YUHEN_KBN,
        R_BUPD_ATENA.TOROKU_JIYU,
        R_BUPD_ATENA.JUFUKU_KOJIN_NO,
        i_SHORIBI,
        0,
        I_SYSTIME,
        i_NSHOKUIN,
        i_NTANMATSU_NO,
        R_BUPD_ATENA.CHOMEI_KANA,
        R_BUPD_ATENA.BANCHI_KANA,
        R_BUPD_ATENA.KATAGAKI_KANA,
        R_BUPD_ATENA.KATAGAKI_HIDE_FLG,
        R_BUPD_ATENA.GAIJI_FLG,
        R_BUPD_ATENA.HOJINSOSHIKI_CD,
        R_BUPD_ATENA.JE_KOKUHOSHISANWARI_KBN,
        R_BUPD_ATENA.JE_JINTEKIGENMEN_KBN,
        R_BUPD_ATENA.JE_SHOYUSHAKEISHONIN_KBN,
        R_BUPD_ATENA.JE_LINK_KOJIN_NO,
        R_BUPD_ATENA.JE_NAYOSE_NO,
        R_BUPD_ATENA.YOBI1_CD,
        R_BUPD_ATENA.YOBI2_CD,
        R_BUPD_ATENA.YOBI3_CD,
        R_BUPD_ATENA.YOBI4_CD,
        R_BUPD_ATENA.YOBI5_CD,
        R_BUPD_ATENA.YOBI1_CH,
        R_BUPD_ATENA.YOBI2_CH,
        R_BUPD_ATENA.YOBI3_CH,
        R_BUPD_ATENA.YOBI4_CH,
        R_BUPD_ATENA.YOBI5_CH
       ,R_BUPD_ATENA.TOUGOU_NO
       ,R_BUPD_ATENA.SEIDO_KOJIN_NO
       ,R_BUPD_ATENA.SEIDO_HOJIN_NO
       ,R_BUPD_ATENA.ZOKUGARACD1
       ,R_BUPD_ATENA.ZOKUGARACD2
       ,R_BUPD_ATENA.ZOKUGARACD3
       ,R_BUPD_ATENA.ZOKUGARACD4
       ,R_BUPD_ATENA.ZOKUGARAKBN
       ,R_BUPD_ATENA.ZOKUGARAMEI
       ,R_BUPD_ATENA.JITSUZOKUGARAMEI
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
--2025/11/13 CTC.liu add start:1.0.026.003 保守QA23150対応
       --,R_BUPD_ATENA.KETAPRM       --住所_桁取パラメータ（基本データリスト用項目）
       ,DECODE (NVL(R_BUPD_ATENA.KETAPRM,NULL),NULL,JIAPK0010.FJUSHOPRM(R_BUPD_ATENA.CHOMEI),R_BUPD_ATENA.KETAPRM)
       ,R_BUPD_ATENA.KOKUMEI_CD    --住所_国名コード（住登外者宛名番号管理の基本データリスト用項目）
--2024/01/25 DIS.liuqimeng Add end
      );
--2024/12/6 CTC Update start 0.3.000.000:IT_JIB_00736対応
     END IF;
      --住基情報テーブルにレコードを追加する
      REBT_JUKIJOHO := NULL;
      REBT_JUKIJOHO.KOJIN_NO := T_KOJIN_NO;  --宛名番号
      REBT_JUKIJOHO.RIREKI_RENBAN := T_RIREKI_RENBAN;  --履歴連番
      REBT_JUKIJOHO.KYUUJI_KANA := R_BUPD_JUKIJOHO.KYUUJI_KANA;   --旧氏かな
      REBT_JUKIJOHO.KYUUJI_KANJI := R_BUPD_JUKIJOHO.KYUUJI_KANJI;   --旧氏漢字
      REBT_JUKIJOHO.SYS_SAKUSEIBI := i_SHORIBI;   --作成日
      REBT_JUKIJOHO.SYS_KOSHINBI := 0;            --更新日
      REBT_JUKIJOHO.SYS_JIKAN := I_SYSTIME;      --更新時間
      REBT_JUKIJOHO.SYS_SHOKUINKOJIN_NO := i_NSHOKUIN;    --更新職員宛名番号
      REBT_JUKIJOHO.SYS_TANMATSU_NO := i_NTANMATSU_NO;    --更新端末番号
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
--2024/10/28 DIS.Zhaohuanhuan Update start 0.3.000.000:新WizLIFE２次開発_IT_JIB_00550の対応
--      REBT_JUKIJOHO.RIREKI_EDABAN := 1;
      -- 異動事由は「412：誤記修正」の場合
      IF CR_IDO.IDO_JIYU = 412 THEN
         REBT_JUKIJOHO.RIREKI_EDABAN := R_BUPD_ATENA.RIREKI_EDABAN + 1;
      ELSE
         REBT_JUKIJOHO.RIREKI_EDABAN := 1;
      END IF;
--2024/10/28 DIS.Zhaohuanhuan Update end
      REBT_JUKIJOHO.SAISHIN_FLG := 1;
      REBT_JUKIJOHO.KYUUJI_KANA_FLG := R_BUPD_JUKIJOHO.KYUUJI_KANA_FLG;
--2024/01/25 DIS.liuqimeng Add end
      --住基情報に登録する
      INSERT INTO JIBTJUKIJOHO VALUES REBT_JUKIJOHO;
--2024/12/6 CTC Update start 0.3.000.000:IT_JIB_00736対応
	IF CR_IDO.IDO_JIYU=412 THEN
        UPDATE JIBTJUKIJOHO
        SET SAISHIN_FLG=0
        WHERE KOJIN_NO=REBT_JUKIJOHO.KOJIN_NO
        AND   RIREKI_RENBAN=T_RIREKI_RENBAN
        AND   RIREKI_EDABAN=R_BUPD_ATENA.RIREKI_EDABAN;
      END IF;
--2024/12/6 CTC Update end
      ------------------------------------------------
      -- 住基異動ＴＢＬデータ削除
      ------------------------------------------------
      IF I_CNT1 != 0 THEN
        IF NKADO_BI5 <= I_SYSDATE AND
           NJOKEN111 = 0 AND
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--           CR_IDO.IDO_JIYU IN (15,16,28) THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
           --CR_IDO.IDO_JIYU IN (150,160,280) THEN
           CR_IDO.IDO_JIYU IN (150,160,280,191) THEN
             NULL;
       --2024/12/6 CTC Update start 0.3.000.000:IT_JIB_00736対応
        --ELSE
        ELSE
         IF (R_ATENA.RIREKI_RENBAN *100 +R_ATENA.RIREKI_EDABAN <= R_BUPD_ATENA.RIREKI_RENBAN *100 +R_BUPD_ATENA.RIREKI_EDABAN) or CR_IDO.IDO_JIYU <>412 THEN
          DELETE FROM JIBTJUKIIDO
                WHERE KOJIN_NO = CR_IDO.KOJIN_NO;
          END IF;
	--2024/12/6 CTC Update end
        END IF;
      END IF;
      ------------------------------------------------
      -- 住基異動ＴＢＬデータ追加
      ------------------------------------------------
--2023/06/27 ZCZL.WANGM ADD Start 0.2.000.001:住記系追加作業
      --特例転出であることを示すフラグのセット処理を追加
      --入力票コード−異動事由が「213:特例転出（一部）」「214:特例転出（全部）」「217:特例転出（一部）：郵送による特例転出」「218:特例転出（全部）：郵送による特例転出」「219:特例転出（一部）：ワンストップ」「210:特例転出（全部）：ワンストップ）」かつ転出する異動者（異動元世帯の続柄変更者ではない）の場合
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--      IF NREPORTCODE2 IN('213', '214', '217', '218' ,'219' ,'210') AND CR_IDO.IDO_JIYU = 21 THEN
--2024/03/26 DIS.liuqimeng Update 0.3.000.000:受入検証指摘対応
--      IF NREPORTCODE2 IN('213', '214', '217', '218' ,'219' ,'210') AND CR_IDO.IDO_JIYU = 210 THEN
--    IF NREPORTCODE2 IN('213', '214', '217', '218' ,'219' ,'210') AND CR_IDO.IDO_JIYU IN(210,211) THEN  --2025/07/07 Del
      IF NREPORTCODE2 IN('21003', '21004', '21007', '21008' ,'21009' ,'21000') AND CR_IDO.IDO_JIYU IN(210,211) THEN  --2025/07/07 Add
        CR_IDO.YOBI4_CH := '[特例転出]';
      --上記以外 かつ CR_IDO.現存区分が0の場合
--    ELSIF NREPORTCODE2 NOT IN('213', '214', '217', '218' ,'219' ,'210') AND CR_IDO.GENZON_KBN = 0 THEN  --2025/07/07 Del
      ELSIF NREPORTCODE2 NOT IN('21003', '21004', '21007', '21008' ,'21009' ,'21000') AND CR_IDO.GENZON_KBN = 0 THEN  --2025/07/07 Add
        IF INSTR(CR_IDO.YOBI4_CH, '[特例転出]')>0 THEN
          CR_IDO.YOBI4_CH := REPLACE(CR_IDO.YOBI4_CH,'[特例転出]','');
        END IF;
      ELSE
        NULL;
      END IF;
--2023/06/27 ZCZL.WANGM ADD End
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
      --入力票コード−異動事由が「11003：特例転入(一部)」「11004：特例転入(全部)」かつ転入する異動者（異動先世帯の続柄変更者ではない）の場合
--2024/03/26 DIS.liuqimeng Update 0.3.000.000:受入検証指摘対応
--      IF NREPORTCODE2 IN('11003', '11004') AND CR_IDO.IDO_JIYU = 210 THEN
      IF NREPORTCODE2 IN('11003', '11004') AND CR_IDO.IDO_JIYU IN(110,111) THEN
        CR_IDO.YOBI4_CH := '[特例転入]';
      --上記以外 かつ CR_IDO.現存区分が1の場合
--2024/03/26 DIS.liuqimeng Update0.3.000.000:受入検証指摘対応
--      ELSIF NREPORTCODE2 NOT IN('11003', '11004') AND CR_IDO.GENZON_KBN = 1 THEN
      ELSIF CR_IDO.GENZON_KBN = 1 THEN
        IF INSTR(CR_IDO.YOBI4_CH, '[特例転入]')>0 THEN
          CR_IDO.YOBI4_CH := REPLACE(CR_IDO.YOBI4_CH,'[特例転入]','');
        END IF;
      ELSE
        NULL;
      END IF;
--2024/01/25 DIS.liuqimeng Add end
      ------------------------------------------------
      -- 宛名基本ＴＢＬ追加
      ------------------------------------------------
--2024/11/07 CTC Update start 0.3.000.000:IT_JIB_00736対応
      IF( R_ATENA.RIREKI_RENBAN <= R_BUPD_ATENA.RIREKI_RENBAN) or  CR_IDO.IDO_JIYU <> 412 THEN
      INSERT INTO JIBTJUKIIDO
      (
        KOJIN_NO,
        JUMINHYO_CD,
        SETAI_NO,
        JUN_SETAI_KBN,
        SAIDAI_JUSHO_REN,
        GENZON_KBN,
        JINKAKU_KBN,
        NUSHI_KBN,
        SHISHO_CD,
        CHIKU_CD,
        GYOSEIKU_CD,
        HAN_CD,
        SHOGAKU_CD,
        CHUGAKU_CD,
        TOHYOKU_CD,
        SANTEIDANTAI_CD,
        ZOKUGARA_CD1,
        ZOKUGARA_CD2,
        ZOKUGARA_CD3,
        ZOKUGARA_CD4,
        ZOKUGARA_KBN,
        ZOKUGARA_MEI,
        JITSU_ZOKUGARA_MEI,
        SEINENGAPI,
        WAREKI_SEINENGAPI,
        HYOJI_SEINENGAPI,
        SEIBETSU,
        KISAI_JUNI,
        IDO_BI,
        IDO_JIYU,
        IDO_TODOKE_BI,
        IDO_TODOKE_KBN,
        JUTEI_BI,
        JUTEI_JIYU,
        JUTEI_TODOKEDE_BI,
        JUTEI_TODOKEDE_KBN,
        GENJUSHO_REN,
        ZENJUSHO_REN,
        TENNYUMAE_REN,
        TENNYU_MITODOKE_REN,
        HONSEKI_REN,
        TENSHUTSU_YOTEI_BI,
        TENSHUTSU_YOTEI_TODOKEDE_BI,
        TENSHUTSU_YOTEI_TODOKEDE_KBN,
        TENSHUTSU_YOTEI_REN,
        TENSHUTSU_KAKUTEI_BI,
        TENSHUTSU_KAKUTEI_TSUCHI_BI,
        TENSHUTSU_KAKUTEI_TODOKEDE_KBN,
        TENSHUTSU_KAKUTEI_REN,
        JUMIN_NARU,
        JUMIN_NARU_JIYU,
        JUMIN_NARU_TODOKEDE_BI,
        JUMIN_NARU_TODOKEDE_KBN,
        JUMIN_NAKUNARU,
        JUMIN_NAKUNARU_JIYU,
        JUMIN_NAKUNARU_TODOKEDE_BI,
        JUMIN_NAKUNARU_TODOKEDE_KBN,
        SHIBOBI_FUSHO_KBN,
        SHIMEI_KANA,
        SHIMEI_KANJI,
        HONMYO_KANA,
        HONMYO_KANJI,
        NUSHI_SHIMEI_KANA,
        NUSHI_SHIMEI_KANJI,
        BIKO,
        KAISEI_REN,
        KAISEI_BI,
        KYU_SHIMEI_KANA,
        KYU_SHIMEI_KANJI,
        KOIKI_KOJIN_NO,
        SHORIBI_KEY,
        SHORI_JIKAN_KEY,
        SHORI_KBN_KEY,
        ZENBU_ICHIBU_KEY,
        SHOKUINKOJIN_NO_KEY,
        SYS_SAKUSEIBI,
        SYS_KOSHINBI,
        SYS_JIKAN,
        SYS_SHOKUINKOJIN_NO,
        SYS_TANMATSU_NO,
        GOMI_CD,
        SINYO_CD,
        KOIKIKOFU_STOP_CD,
        GAIJI_FLG,
        YOBI1_CD,
        YOBI2_CD,
        YOBI3_CD,
        YOBI4_CD,
        YOBI5_CD,
        YOBI1_CH,
        YOBI2_CH,
        YOBI3_CH,
        YOBI4_CH,
        YOBI5_CH
        ,ALP_SHIMEI_KANA,
        ALP_SHIMEI_KANJI,
        GAI_SHIMEI_KANA,
        GAI_SHIMEI_KANJI,
        TSUSHOMEI_KANA,
        TSUSHOMEI_KANJI,
        HEIKIMEI_KANA,
        HEIKIMEI_KANJI,
        GAIKOKU_JUMIN_NARU,
        ZAIRYU_NO_SHUBETSU,
        ZAIRYU_CARD_NO,
        ZAIRYU_SHIKAKU_CD,
        ZAIRYU_SHURYO_BI,
        ZAIRYU_KIKAN_NEN,
        ZAIRYU_KIKAN_TSUKI,
        ZAIRYU_KIKAN_HI,
        KOKUSEKI_CD,
        CARD_MANRYO_BI,
        KBN_30_45,
        KYOJYUCHI_UMU,
        SEINENGAPI_FUSHO_KBN,
        RYOKEN_BANGO,
        RYOKEN_HAKKO_BI,
        JORIKU_KYOKA_BI,
        JUMIN_NUSHI_SHIMEI
       ,SEIDO_KOJIN_NO
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
       ,NYURYOKUBASHO                   --入力場所
       ,SHIMEI_KANA_FLG                 --氏名カナフラグ
       ,TSUSHO_KANA_FLG                 --通称カナフラグ
       ,JIJITSUJONOSETAINUSHI_KANA      --事実上の世帯主カナ
       ,JIJITSUJONOSETAINUSHI_KANJI     --事実上の世帯主漢字
       ,SAISYUTOROKUJUSHO_REN           --最終登録住所地連番
       ,SAISEIKISAI_DATE                --再製記載年月日
       ,SAISEIKISAIDATE_FUSHO_FLG       --再製記載年月日不詳フラグ
       ,SAISEIKISAIDATE_FUSHO_HYOKI     --再製記載年月日不詳表記
       ,SAISEISHOJODATE                 --再製消除年月日
       ,SAISEISHOJODATE_FUSHO_FLG       --再製消除年月日不詳フラグ
       ,SAISEISHOJODATE_FUSHO_HYOKI     --再製消除年月日不詳表記
       ,KBN_30_46_47                    --法第30条46又は47区分
       ,SEINENGAPI_FUSHO_HYOKI          --生年月日不詳表記
       ,IDO_BI_FUSHO_FLG                --異動日不詳フラグ
       ,IDO_BI_FUSHO_HYOKI              --異動日不詳表記
       ,JUTEI_BI_FUSHO_FLG              --住定日不詳フラグ
       ,JUTEI_BI_FUSHO_HYOKI            --住定日不詳表記
       ,JUMIN_NARU_FUSHO_FLG            --住民となる日不詳フラグ
       ,JUMIN_NARU_FUSHO_HYOKI          --住民となる日不詳表記
       ,JUMIN_NAKUNARU_FUSHO_FLG        --住民でなくなる日不詳フラグ
       ,JUMIN_NAKUNARU_FUSHO_HYOKI      --住民でなくなる日不詳表記
       ,KAISEI_BI_FUSHO_FLG             --改製日不詳フラグ
       ,KAISEI_BI_FUSHO_HYOKI           --改製日不詳表記
       ,GAIKOKU_JUMIN_NARU_FUSHO_FLG    --外国人の住民となる日不詳フラグ
       ,GAIKOKU_JUMIN_NARU_FUSHO_HYOKI  --外国人の住民となる日不詳表記
       ,SEIBETSU_FUSHO_KBN              --性別不詳区分
       ,IDO_JIYU_SHOSAI                 --異動事由詳細
       ,IDOKOMOKU_1                     --異動項目_1
       ,RYUIJIKO_1                      --留意事項_1
       ,IDOKOMOKU_2                     --異動項目_2
       ,RYUIJIKO_2                      --留意事項_2
       ,IDOKOMOKU_3                     --異動項目_3
       ,RYUIJIKO_3                      --留意事項_3
       ,RIREKI_SENTAKUFUKA_FLG          --履歴選択不可フラグ
       ,TODOKEDE_NO                     --届出番号
       ,TORIKESHI_TODOKEDE_NO           --取消届出番号
--2024/01/25 DIS.liuqimeng Add end
      )
      VALUES
      (
        T_KOJIN_NO,
        T_JUMIN_CD,
        T_SETAI_NO,
        CR_IDO.JUN_SETAI_KBN,
        CR_IDO.SAIDAI_JUSHO_REN,
        CR_IDO.GENZON_KBN,
        CR_IDO.JINKAKU_KBN,
        CR_IDO.NUSHI_KBN,
        CR_IDO.SHISHO_CD,
        CR_IDO.CHIKU_CD,
        CR_IDO.GYOSEIKU_CD,
        CR_IDO.HAN_CD,
        CR_IDO.SHOGAKU_CD,
        CR_IDO.CHUGAKU_CD,
        CR_IDO.TOHYOKU_CD,
        CR_IDO.SANTEIDANTAI_CD,
        CR_IDO.ZOKUGARA_CD1,
        CR_IDO.ZOKUGARA_CD2,
        CR_IDO.ZOKUGARA_CD3,
        CR_IDO.ZOKUGARA_CD4,
        CR_IDO.ZOKUGARA_KBN,
        CR_IDO.ZOKUGARA_MEI,
        CR_IDO.JITSU_ZOKUGARA_MEI,
        CR_IDO.SEINENGAPI,
        CR_IDO.WAREKI_SEINENGAPI,
        CR_IDO.HYOJI_SEINENGAPI,
        CR_IDO.SEIBETSU,
        CR_IDO.KISAI_JUNI,
        CR_IDO.IDO_BI,
        CR_IDO.IDO_JIYU,
        CR_IDO.IDO_TODOKE_BI,
        CR_IDO.IDO_TODOKE_KBN,
        CR_IDO.JUTEI_BI,
        CR_IDO.JUTEI_JIYU,
        CR_IDO.JUTEI_TODOKEDE_BI,
        CR_IDO.JUTEI_TODOKEDE_KBN,
        CR_IDO.GENJUSHO_REN,
        CR_IDO.ZENJUSHO_REN,
        CR_IDO.TENNYUMAE_REN,
        CR_IDO.TENNYU_MITODOKE_REN,
        CR_IDO.HONSEKI_REN,
        CR_IDO.TENSHUTSU_YOTEI_BI,
        CR_IDO.TENSHUTSU_YOTEI_TODOKEDE_BI,
        CR_IDO.TENSHUTSU_YOTEI_TODOKEDE_KBN,
        CR_IDO.TENSHUTSU_YOTEI_REN,
        CR_IDO.TENSHUTSU_KAKUTEI_BI,
        CR_IDO.TENSHUTSU_KAKUTEI_TSUCHI_BI,
        CR_IDO.TENSHUTSU_KAKUTEI_TODOKEDE_KBN,
        CR_IDO.TENSHUTSU_KAKUTEI_REN,
        CR_IDO.JUMIN_NARU,
        CR_IDO.JUMIN_NARU_JIYU,
        CR_IDO.JUMIN_NARU_TODOKEDE_BI,
        CR_IDO.JUMIN_NARU_TODOKEDE_KBN,
        CR_IDO.JUMIN_NAKUNARU,
        CR_IDO.JUMIN_NAKUNARU_JIYU,
        CR_IDO.JUMIN_NAKUNARU_TODOKEDE_BI,
        CR_IDO.JUMIN_NAKUNARU_TODOKEDE_KBN,
        CR_IDO.SHIBOBI_FUSHO_KBN,
        CR_IDO.SHIMEI_KANA,
        CR_IDO.SHIMEI_KANJI,
        CR_IDO.HONMYO_KANA,
        CR_IDO.HONMYO_KANJI,
        CR_IDO.NUSHI_SHIMEI_KANA,
        CR_IDO.NUSHI_SHIMEI_KANJI,
        CR_IDO.BIKO,
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
--        DECODE(NVL(CR_IDO.KAISEI_REN,0), 0, 1, CR_IDO.KAISEI_REN),
--        CR_IDO.KAISEI_BI,
        CASE
            WHEN CR_IDO.IDO_JIYU IN (191,291) THEN CR_IDO.KAISEI_REN + 1
            ELSE DECODE(NVL(CR_IDO.KAISEI_REN,0), 0, 1, CR_IDO.KAISEI_REN)
        END,
        CASE
            WHEN CR_IDO.IDO_JIYU IN (191,291) THEN i_SHORIBI
            ELSE CR_IDO.KAISEI_BI
        END,
--2024/01/25 DIS.liuqimeng Add end
        CR_IDO.KYU_SHIMEI_KANA,
        CR_IDO.KYU_SHIMEI_KANJI,
        CR_IDO.KOIKI_KOJIN_NO,
        I_SYSDATE,
        I_SYSTIME,
        CR_IDO.SHORI_KBN_KEY,
        CR_IDO.ZENBU_ICHIBU_KEY,
        i_NSHOKUIN,
        i_SHORIBI,
        0,
        I_SYSTIME,
        i_NSHOKUIN,
        i_NTANMATSU_NO,
        CR_IDO.GOMI_CD,
        CR_IDO.SINYO_CD,
        CR_IDO.KOIKIKOFU_STOP_CD,
        CR_IDO.GAIJI_FLG,
        CR_IDO.YOBI1_CD,
        CR_IDO.YOBI2_CD,
        CR_IDO.YOBI3_CD,
        CR_IDO.YOBI4_CD,
        CR_IDO.YOBI5_CD,
        CR_IDO.YOBI1_CH,
        CR_IDO.YOBI2_CH,
        CR_IDO.YOBI3_CH,
        CR_IDO.YOBI4_CH,
        CR_IDO.YOBI5_CH
        ,CR_IDO.ALP_SHIMEI_KANA,
        CR_IDO.ALP_SHIMEI_KANJI,
        CR_IDO.GAI_SHIMEI_KANA,
        CR_IDO.GAI_SHIMEI_KANJI,
        CR_IDO.TSUSHOMEI_KANA,
        CR_IDO.TSUSHOMEI_KANJI,
        CR_IDO.HEIKIMEI_KANA,
        CR_IDO.HEIKIMEI_KANJI,
        CR_IDO.GAIKOKU_JUMIN_NARU,
        CR_IDO.ZAIRYU_NO_SHUBETSU,
        CR_IDO.ZAIRYU_CARD_NO,
        CR_IDO.ZAIRYU_SHIKAKU_CD,
        CR_IDO.ZAIRYU_SHURYO_BI,
        CR_IDO.ZAIRYU_KIKAN_NEN,
        CR_IDO.ZAIRYU_KIKAN_TSUKI,
        CR_IDO.ZAIRYU_KIKAN_HI,
        CR_IDO.KOKUSEKI_CD,
        CR_IDO.CARD_MANRYO_BI,
        CR_IDO.KBN_30_45,
        CR_IDO.KYOJYUCHI_UMU,
        CR_IDO.SEINENGAPI_FUSHO_KBN,
        CR_IDO.RYOKEN_BANGO,
        CR_IDO.RYOKEN_HAKKO_BI,
        CR_IDO.JORIKU_KYOKA_BI,
        CR_IDO.JUMIN_NUSHI_SHIMEI
       ,CR_IDO.SEIDO_KOJIN_NO
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
       ,VCHOSHACODE                   --入力場所
       ,CR_IDO.SHIMEI_KANA_FLG                 --氏名カナフラグ
       ,CR_IDO.TSUSHO_KANA_FLG                 --通称カナフラグ
       ,CR_IDO.JIJITSUJONOSETAINUSHI_KANA      --事実上の世帯主カナ
       ,CR_IDO.JIJITSUJONOSETAINUSHI_KANJI     --事実上の世帯主漢字
       ,CR_IDO.SAISYUTOROKUJUSHO_REN           --最終登録住所地連番
       ,CR_IDO.SAISEIKISAI_DATE                --再製記載年月日
       ,CR_IDO.SAISEIKISAIDATE_FUSHO_FLG       --再製記載年月日不詳フラグ
       ,CR_IDO.SAISEIKISAIDATE_FUSHO_HYOKI     --再製記載年月日不詳表記
       ,CR_IDO.SAISEISHOJODATE                 --再製消除年月日
       ,CR_IDO.SAISEISHOJODATE_FUSHO_FLG       --再製消除年月日不詳フラグ
       ,CR_IDO.SAISEISHOJODATE_FUSHO_HYOKI     --再製消除年月日不詳表記
       ,CR_IDO.KBN_30_46_47                    --法第30条46又は47区分
       ,CR_IDO.SEINENGAPI_FUSHO_HYOKI          --生年月日不詳表記
       ,CR_IDO.IDO_BI_FUSHO_FLG                --異動日不詳フラグ
       ,CR_IDO.IDO_BI_FUSHO_HYOKI              --異動日不詳表記
       ,CR_IDO.JUTEI_BI_FUSHO_FLG              --住定日不詳フラグ
       ,CR_IDO.JUTEI_BI_FUSHO_HYOKI            --住定日不詳表記
       ,CR_IDO.JUMIN_NARU_FUSHO_FLG            --住民となる日不詳フラグ
       ,CR_IDO.JUMIN_NARU_FUSHO_HYOKI          --住民となる日不詳表記
       ,CR_IDO.JUMIN_NAKUNARU_FUSHO_FLG        --住民でなくなる日不詳フラグ
       ,CR_IDO.JUMIN_NAKUNARU_FUSHO_HYOKI      --住民でなくなる日不詳表記
       ,CR_IDO.KAISEI_BI_FUSHO_FLG             --改製日不詳フラグ
       ,CR_IDO.KAISEI_BI_FUSHO_HYOKI           --改製日不詳表記
       ,CR_IDO.GAIKOKU_JUMIN_NARU_FUSHO_FLG    --外国人の住民となる日不詳フラグ
       ,CR_IDO.GAIKOKU_JUMIN_NARU_FUSHO_HYOKI  --外国人の住民となる日不詳表記
       ,CR_IDO.SEIBETSU_FUSHO_KBN              --性別不詳区分
       ,CR_IDO.IDO_JIYU_SHOSAI                 --異動事由詳細
       ,CR_IDO.IDOKOMOKU_1                     --異動項目_1
       ,CR_IDO.RYUIJIKO_1                      --留意事項_1
       ,CR_IDO.IDOKOMOKU_2                     --異動項目_2
       ,CR_IDO.RYUIJIKO_2                      --留意事項_2
       ,CR_IDO.IDOKOMOKU_3                     --異動項目_3
       ,CR_IDO.RYUIJIKO_3                      --留意事項_3
       ,CR_IDO.RIREKI_SENTAKUFUKA_FLG          --履歴選択不可フラグ
--2024/08/15 DIS.liuqimeng Update 0.3.000.000: IT_JIB_00228対応
--       ,CR_IDO.TODOKEDE_NO                     --届出番号
--2024/10/22 DIS.Gaohaobo Update 0.3.040.000: IT_JIB_00454対応
--     ,JIBSOTODOKEDE_SEQ.NEXTVAL                --届出番号
       ,VNEXTVAL                                 --届出番号
       ,CR_IDO.TORIKESHI_TODOKEDE_NO           --取消届出番号
--2024/01/25 DIS.liuqimeng Add end

      );
--2024/11/07 CTC Update start 0.3.000.000:IT_JIB_00736対応
 	END IF;
       -- システム条件 =1の場合
      IF NJOKEN = 1 THEN
        SELECT COUNT(*)
          INTO I_CNT2
          FROM JIBTKOBETSUKANRI
         WHERE KOJIN_NO = CR_IDO.KOJIN_NO;
        -- JIBTKOBETSUKANRIの件数 =0の場合
        IF I_CNT2 = 0 THEN
      ------------------------------------------------
      -- 個別項目情報管理テーブルの追加
      ------------------------------------------------
        INSERT INTO JIBTKOBETSUKANRI
        (
          KOJIN_NO,
          SNENKIN_SHIKAKU,
          SNENKIN_NO,
          SNENKIN_KAISHI_BI,
          SEIKATSUHOGO_SHIKAKU,
          SEIKATSUHOGO_SHUBETU_CD,
          SEIKATSUHOGO_KAISHI_BI,
          SEIKATSUHOGO_SHURYO_BI,
          SHOGAISHA_KUBUN_CD,
          KOUTSUKYOSAI_KUBUN_CD,
          SYS_SAKUSEIBI,
          SYS_KOSHINBI,
          SYS_JIKAN,
          SYS_SHOKUINKOJIN_NO,
          SYS_TANMATSU_NO
        )
        VALUES
        (
          T_KOJIN_NO,
          0,
          0,
          NULL,
          0,
          0,
          0,
          0,
          0,
          0,
          i_SHORIBI,
          0,
          I_SYSTIME,
          i_NSHOKUIN,
          i_NTANMATSU_NO
        );
        END IF;
      END IF;
      ------------------------------------------------
      -- 住基住所ＴＢＬ追加
      ------------------------------------------------
      FOR I IN 1..I_CNT LOOP
        ------------------------------------------------
        -- 住基住所ＴＢＬデータ検索
        ------------------------------------------------

        SELECT COUNT(*) INTO I_CNT1 FROM JIBTJUKIJUSHO
          WHERE KOJIN_NO    = T_KOJIN_NO
              AND NVL(OAZA_CD,0) = NVL(M_JUSHO(I).OAZA_CD,0)
            AND NVL(HONBAN,'　　　　　') = NVL(M_JUSHO(I).HONBAN,'　　　　　')
            AND NVL(EDABAN1,'　　　　　') = NVL(M_JUSHO(I).EDABAN1,'　　　　　')
            AND NVL(EDABAN2,'　　　　　') = NVL(M_JUSHO(I).EDABAN2,'　　　　　')
            AND NVL(EDABAN3,'　　　　　') = NVL(M_JUSHO(I).EDABAN3,'　　　　　')
            AND NVL(KATAGAKI_CD,0) = NVL(M_JUSHO(I).KATAGAKI_CD,0)
            AND NVL(GAIKU,'_null') = NVL(M_JUSHO(I).GAIKU,'_null')
            AND NVL(TOU,'_null') = NVL(M_JUSHO(I).TOU,'_null')
            AND NVL(GOU,'_null') = NVL(M_JUSHO(I).GOU,'_null')
            AND USER_CD     = M_JUSHO(I).USER_CD
            AND JICHI_CD    = M_JUSHO(I).JICHI_CD
            AND NVL(KATAGAKI_HIDE_FLG,0) = NVL(M_JUSHO(I).KATAGAKI_HIDE_FLG,0)
            AND NVL(YUBIN_NO,0) = NVL(M_JUSHO(I).YUBIN_NO,0)
            AND (BANCHI = M_JUSHO(I).BANCHI OR BANCHI IS NULL AND M_JUSHO(I).BANCHI IS NULL)
            AND (CHOMEI = M_JUSHO(I).CHOMEI OR  CHOMEI IS NULL AND M_JUSHO(I).CHOMEI IS NULL)
            AND (KATAGAKI = M_JUSHO(I).KATAGAKI OR KATAGAKI IS NULL AND M_JUSHO(I).KATAGAKI IS NULL)
            AND (BANCHI_KANA = M_JUSHO(I).BANCHI_KANA OR BANCHI_KANA IS NULL AND M_JUSHO(I).BANCHI_KANA IS NULL)
            AND (CHOMEI_KANA = M_JUSHO(I).CHOMEI_KANA OR CHOMEI_KANA IS NULL AND M_JUSHO(I).CHOMEI_KANA IS NULL)
            AND (KATAGAKI_KANA = M_JUSHO(I).KATAGAKI_KANA OR KATAGAKI_KANA IS NULL AND M_JUSHO(I).KATAGAKI_KANA IS NULL)
--2024/01/25 DIS.liuqimeng Update Start 0.3.000.000:新WizLIFE２次開発
--            AND (NUSHI_HITTOSYA = M_JUSHO(I).NUSHI_HITTOSYA OR  NUSHI_HITTOSYA  IS NULL AND M_JUSHO(I).NUSHI_HITTOSYA IS NULL);
            AND (NUSHI_HITTOSYA = M_JUSHO(I).NUSHI_HITTOSYA OR  NUSHI_HITTOSYA  IS NULL AND M_JUSHO(I).NUSHI_HITTOSYA IS NULL)
            AND (KETAPRM = M_JUSHO(I).KETAPRM OR  KETAPRM  IS NULL AND M_JUSHO(I).KETAPRM IS NULL)
            --2025/02/18 CTC Update start 0.3.000.000:IT_JIB_00976対応
            --AND (KOKUMEI_CD = M_JUSHO(I).KOKUMEI_CD OR  KOKUMEI_CD  IS NULL AND M_JUSHO(I).KOKUMEI_CD IS NULL);
            AND (KOKUMEI_CD = M_JUSHO(I).KOKUMEI_CD OR  KOKUMEI_CD  = 0 AND M_JUSHO(I).KOKUMEI_CD = 0);
--2024/01/25 DIS.liuqimeng Update End
        ------------------------------------------------
        -- 住基住所ＴＢＬ検索判定
        ------------------------------------------------
        IF I_CNT1 = 0 THEN
          IF (M_JUSHO(I).OAZA_CD = 0 AND
              NVL(M_JUSHO(I).HONBAN,'　　　　　') = '　　　　　' AND
              NVL(M_JUSHO(I).EDABAN1,'　　　　　') = '　　　　　' AND
              NVL(M_JUSHO(I).EDABAN2,'　　　　　') = '　　　　　' AND
              NVL(M_JUSHO(I).EDABAN3,'　　　　　') = '　　　　　' AND
              M_JUSHO(I).KATAGAKI_CD = 0 AND
              NVL(M_JUSHO(I).GAIKU,'　　　　　') ='　　　　　' AND
              NVL(M_JUSHO(I).TOU,'　　　　　') = '　　　　　' AND
              NVL(M_JUSHO(I).GOU,'　　　　　') = '　　　　　' AND
              M_JUSHO(I).USER_CD = 0 AND
              M_JUSHO(I).JICHI_CD = 0 AND
              NVL(M_JUSHO(I).YUBIN_NO,0) = 0 AND
              M_JUSHO(I).YUBIN_NOBC   IS  NULL  AND
              M_JUSHO(I).BANCHI     IS  NULL  AND
              M_JUSHO(I).CHOMEI     IS  NULL  AND
              M_JUSHO(I).KATAGAKI     IS  NULL  AND
              M_JUSHO(I).BANCHI_KANA  IS NULL AND
              M_JUSHO(I).CHOMEI_KANA  IS NULL AND
              M_JUSHO(I).KATAGAKI_KANA  IS NULL AND
              M_JUSHO(I).KATAGAKI_HIDE_FLG = 0 AND
--2024/01/25 DIS.liuqimeng Update Start 0.3.000.000:新WizLIFE２次開発
--              M_JUSHO(I).NUSHI_HITTOSYA IS  NULL) THEN
              M_JUSHO(I).NUSHI_HITTOSYA IS  NULL AND
              M_JUSHO(I).KETAPRM IS  NULL AND
              --2025/02/18 CTC Update start 0.3.000.000:IT_JIB_00976対応
              --M_JUSHO(I).KOKUMEI_CD IS  NULL) THEN
              M_JUSHO(I).KOKUMEI_CD = 0) THEN
--2024/01/25 DIS.liuqimeng Update End
                T_RENBAN := 0;
          ELSE
            ------------------------------------------------
            -- 住所連番設定
            ------------------------------------------------
            SELECT COUNT(*)
              INTO I_CNT1
              FROM JIBTJUKIJUSHO
             WHERE KOJIN_NO = T_KOJIN_NO;
            ------------------------------------------------
            -- 住基住所ＴＢＬ検索判定
            ------------------------------------------------
            IF I_CNT1 != 0 THEN
              SELECT MAX(JUSHO_REN)
                INTO T_RENBAN
                FROM JIBTJUKIJUSHO
               WHERE KOJIN_NO = T_KOJIN_NO;
              T_RENBAN := T_RENBAN + 1;
            ELSE
              T_RENBAN := 1;
            END IF;
            --最大住所連番更新
            UPDATE JIBTJUKIIDO
              SET SAIDAI_JUSHO_REN = T_RENBAN
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
 --2025/02/24 CTC Update start 0.3.000.000:IT_JIB_01005対応
                 --,SAISYUTOROKUJUSHO_REN = T_RENBAN
            WHERE KOJIN_NO = T_KOJIN_NO;
            ------------------------------------------------
            -- 住基住所ＴＢＬ追加
            ------------------------------------------------
            INSERT INTO JIBTJUKIJUSHO
            (
              KOJIN_NO,
              JUSHO_REN,
              OAZA_CD,
              HONBAN,
              EDABAN1,
              EDABAN2,
              EDABAN3,
              KATAGAKI_CD,
              GAIKU,
              TOU,
              GOU,
              USER_CD,
              JICHI_CD,
              YUBIN_NO,
              YUBIN_NOBC,
              BANCHI,
              CHOMEI,
              KATAGAKI,
              NUSHI_HITTOSYA,
              SYS_SAKUSEIBI,
              SYS_KOSHINBI,
              SYS_JIKAN,
              SYS_SHOKUINKOJIN_NO,
              SYS_TANMATSU_NO,
              CHOMEI_KANA,
              BANCHI_KANA,
              KATAGAKI_KANA,
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--              KATAGAKI_HIDE_FLG
              KATAGAKI_HIDE_FLG,
              KETAPRM,
              KOKUMEI_CD
--2024/01/25 DIS.liuqimeng Update end
            )
            VALUES
            (
              T_KOJIN_NO,
              T_RENBAN,
              M_JUSHO(I).OAZA_CD,
              M_JUSHO(I).HONBAN,
              M_JUSHO(I).EDABAN1,
              M_JUSHO(I).EDABAN2,
              M_JUSHO(I).EDABAN3,
              M_JUSHO(I).KATAGAKI_CD,
              M_JUSHO(I).GAIKU,
              M_JUSHO(I).TOU,
              M_JUSHO(I).GOU,
              M_JUSHO(I).USER_CD,
              M_JUSHO(I).JICHI_CD,
              M_JUSHO(I).YUBIN_NO,
              M_JUSHO(I).YUBIN_NOBC,
              M_JUSHO(I).BANCHI,
              M_JUSHO(I).CHOMEI,
              M_JUSHO(I).KATAGAKI,
              M_JUSHO(I).NUSHI_HITTOSYA,
              i_SHORIBI,
              0,
              I_SYSTIME,
              i_NSHOKUIN,
              i_NTANMATSU_NO,
              M_JUSHO(I).CHOMEI_KANA,
              M_JUSHO(I).BANCHI_KANA,
              M_JUSHO(I).KATAGAKI_KANA,
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--              M_JUSHO(I).KATAGAKI_HIDE_FLG
              M_JUSHO(I).KATAGAKI_HIDE_FLG,
--2025/11/13 CTC.liu update start:1.0.026.003 保守QA23150対応
              --M_JUSHO(I).KETAPRM,
              DECODE (NVL(M_JUSHO(I).KETAPRM,NULL),NULL,JIAPK0010.FJUSHOPRM(M_JUSHO(I).CHOMEI),M_JUSHO(I).KETAPRM),
--2025/11/13 CTC.liu update end
              M_JUSHO(I).KOKUMEI_CD
--2024/01/25 DIS.liuqimeng Update end
            );
          END IF;
--2025/5/23 CTC.liu add start 1.0.005.000:新WizLIFE２次開発 QA16260対応
          IF  CR_IDO.IDO_JIYU = 412 and  R_ATENA.RIREKI_RENBAN* 100 +R_ATENA.RIREKI_EDABAN > R_BUPD_ATENA.RIREKI_RENBAN* 100 +R_BUPD_ATENA.RIREKI_EDABAN THEN
           IF CR_IDO.GENJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET GENJUSHO_REN = T_RENBAN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの前住所連番を更新
          ------------------------------------------------
          IF CR_IDO.ZENJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET ZENJUSHO_REN = T_RENBAN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの転入前住所連番を更新
          ------------------------------------------------
          IF CR_IDO.TENNYUMAE_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET TENNYUMAE_REN = T_RENBAN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの転入未届地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENNYU_MITODOKE_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET TENNYU_MITODOKE_REN = T_RENBAN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの本籍地連番を更新
          ------------------------------------------------
          IF CR_IDO.HONSEKI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET HONSEKI_REN = T_RENBAN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの転出予定地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENSHUTSU_YOTEI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET TENSHUTSU_YOTEI_REN = T_RENBAN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの転出確定地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENSHUTSU_KAKUTEI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET TENSHUTSU_KAKUTEI_REN = T_RENBAN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          IF CR_IDO.SAISYUTOROKUJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET SAISYUTOROKUJUSHO_REN = T_RENBAN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
--2025/5/23 CTC.liu update start
--        END IF;
        ELSE
--2025/5/23 CTC.liu update end
--2025/5/23 CTC.liu add start
         ------------------------------------------------
          -- 住基異動ＴＢＬの各住所連番を更新
          ------------------------------------------------
          ------------------------------------------------
          -- 住基異動ＴＢＬの現住所連番を更新
          ------------------------------------------------
          IF CR_IDO.GENJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET GENJUSHO_REN = T_RENBAN
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
 --2025/02/24 CTC Update start 0.3.000.000:IT_JIB_01005対応
                  --,SAISYUTOROKUJUSHO_REN = T_RENBAN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの前住所連番を更新
          ------------------------------------------------
          IF CR_IDO.ZENJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET ZENJUSHO_REN = T_RENBAN
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
 --2025/02/24 CTC Update start 0.3.000.000:IT_JIB_01005対応
                 --,SAISYUTOROKUJUSHO_REN = T_RENBAN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの転入前住所連番を更新
          ------------------------------------------------
          IF CR_IDO.TENNYUMAE_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET TENNYUMAE_REN = T_RENBAN
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
 --2025/02/24 CTC Update start 0.3.000.000:IT_JIB_01005対応
                 --,SAISYUTOROKUJUSHO_REN = T_RENBAN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの転入未届地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENNYU_MITODOKE_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET TENNYU_MITODOKE_REN = T_RENBAN
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
 --2025/02/24 CTC Update start 0.3.000.000:IT_JIB_01005対応
                 --,SAISYUTOROKUJUSHO_REN = T_RENBAN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの本籍地連番を更新
          ------------------------------------------------
          IF CR_IDO.HONSEKI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET HONSEKI_REN = T_RENBAN
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
 --2025/02/24 CTC Update start 0.3.000.000:IT_JIB_01005対応
                 --,SAISYUTOROKUJUSHO_REN = T_RENBAN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの転出予定地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENSHUTSU_YOTEI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET TENSHUTSU_YOTEI_REN = T_RENBAN
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
 --2025/02/24 CTC Update start 0.3.000.000:IT_JIB_01005対応
                 --,SAISYUTOROKUJUSHO_REN = T_RENBAN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの転出確定地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENSHUTSU_KAKUTEI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET TENSHUTSU_KAKUTEI_REN = T_RENBAN
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
 --2025/02/24 CTC Update start 0.3.000.000:IT_JIB_01005対応
                 --,SAISYUTOROKUJUSHO_REN = T_RENBAN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          --2025/02/19 CTC Update start 0.3.000.000:IT_JIB_01005対応
          IF CR_IDO.SAISYUTOROKUJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET SAISYUTOROKUJUSHO_REN = T_RENBAN
            WHERE KOJIN_NO = T_KOJIN_NO;
--2025/5/23 CTC.liu add
            END IF;
          END IF;
        ELSE
          ------------------------------------------------
          -- 住基異動ＴＢＬの各住所連番を更新
          ------------------------------------------------
          ------------------------------------------------
          -- 住基住所データ抽出
          ------------------------------------------------
          SELECT *
            INTO R_JUSHO
            FROM JIBTJUKIJUSHO
           WHERE KOJIN_NO = T_KOJIN_NO
             AND JUSHO_REN = (
                              SELECT MIN(JUSHO_REN)
                                FROM JIBTJUKIJUSHO
                               WHERE KOJIN_NO = T_KOJIN_NO
                                 AND NVL(OAZA_CD,0)  = NVL(M_JUSHO(I).OAZA_CD,0)
                                 AND NVL(HONBAN,'　　　　　')   = NVL(M_JUSHO(I).HONBAN,'　　　　　')
                                 AND NVL(EDABAN1,'　　　　　')  = NVL(M_JUSHO(I).EDABAN1,'　　　　　')
                                 AND NVL(EDABAN2,'　　　　　')  = NVL(M_JUSHO(I).EDABAN2,'　　　　　')
                                 AND NVL(EDABAN3,'　　　　　')  = NVL(M_JUSHO(I).EDABAN3,'　　　　　')
                                 AND NVL(KATAGAKI_CD,0) = NVL(M_JUSHO(I).KATAGAKI_CD,0)
                                 AND NVL(GAIKU,'_null')    = NVL(M_JUSHO(I).GAIKU,'_null')
                                 AND NVL(TOU,'_null')      = NVL(M_JUSHO(I).TOU,'_null')
                                 AND NVL(GOU,'_null')      = NVL(M_JUSHO(I).GOU,'_null')
                                 AND USER_CD  = M_JUSHO(I).USER_CD
                                 AND JICHI_CD    = M_JUSHO(I).JICHI_CD
                                 AND NVL(KATAGAKI_HIDE_FLG,0) = NVL(M_JUSHO(I).KATAGAKI_HIDE_FLG,0)
                                 AND NVL(YUBIN_NO,0) = NVL(M_JUSHO(I).YUBIN_NO,0)
                                 --##########################################
                                 --##郵便番号バーコードの仕様確定した場合は処理する
                                 --##########################################
                                 AND (BANCHI = M_JUSHO(I).BANCHI OR BANCHI IS NULL AND M_JUSHO(I).BANCHI IS NULL)
                                 AND (CHOMEI = M_JUSHO(I).CHOMEI OR  CHOMEI IS NULL AND M_JUSHO(I).CHOMEI IS NULL)
                                 AND (KATAGAKI = M_JUSHO(I).KATAGAKI OR KATAGAKI IS NULL AND M_JUSHO(I).KATAGAKI IS NULL)
                                 AND (BANCHI_KANA = M_JUSHO(I).BANCHI_KANA OR BANCHI_KANA IS NULL AND M_JUSHO(I).BANCHI_KANA IS NULL)
                                 AND (CHOMEI_KANA = M_JUSHO(I).CHOMEI_KANA OR CHOMEI_KANA IS NULL AND M_JUSHO(I).CHOMEI_KANA IS NULL)
                                 AND (KATAGAKI_KANA = M_JUSHO(I).KATAGAKI_KANA OR KATAGAKI_KANA IS NULL AND M_JUSHO(I).KATAGAKI_KANA IS NULL)
                                 AND (NUSHI_HITTOSYA = M_JUSHO(I).NUSHI_HITTOSYA OR  NUSHI_HITTOSYA  IS NULL AND M_JUSHO(I).NUSHI_HITTOSYA IS NULL)
                                );
--2025/5/23 CTC.liu add start 1.0.005.000:新WizLIFE２次開発 QA16260対応
       IF  CR_IDO.IDO_JIYU = 412 and  R_ATENA.RIREKI_RENBAN* 100 +R_ATENA.RIREKI_EDABAN > R_BUPD_ATENA.RIREKI_RENBAN* 100 +R_BUPD_ATENA.RIREKI_EDABAN THEN

         IF CR_IDO.GENJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET GENJUSHO_REN = R_JUSHO.JUSHO_REN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの前住所連番を更新
          ------------------------------------------------
          IF CR_IDO.ZENJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET ZENJUSHO_REN = R_JUSHO.JUSHO_REN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの転入前住所連番を更新
          ------------------------------------------------
          IF CR_IDO.TENNYUMAE_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET TENNYUMAE_REN = R_JUSHO.JUSHO_REN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの転入未届地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENNYU_MITODOKE_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET TENNYU_MITODOKE_REN = R_JUSHO.JUSHO_REN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの本籍地連番を更新
          ------------------------------------------------
          IF CR_IDO.HONSEKI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET HONSEKI_REN = R_JUSHO.JUSHO_REN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの転出予定地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENSHUTSU_YOTEI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET TENSHUTSU_YOTEI_REN = R_JUSHO.JUSHO_REN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          ------------------------------------------------
          -- 住基履歴ＴＢＬの転出確定地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENSHUTSU_KAKUTEI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET TENSHUTSU_KAKUTEI_REN = R_JUSHO.JUSHO_REN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
          --2025/02/19 CTC Update start 0.3.000.000:IT_JIB_01005対応
          ------------------------------------------------
          -- 住基履歴ＴＢＬの最終登録連番を更新
          ------------------------------------------------
          IF CR_IDO.SAISYUTOROKUJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIRIREKI
              SET SAISYUTOROKUJUSHO_REN = R_JUSHO.JUSHO_REN
--2025/09/05 CTC.liu update start 1.0.016.002:新WizLIFE保守対応 QA20504
            --WHERE KOJIN_NO = T_KOJIN_NO;
            WHERE KOJIN_NO = T_KOJIN_NO
              AND RIREKI_RENBAN = R_BUPD_ATENA.RIREKI_RENBAN
              AND RIREKI_EDABAN   = R_BUPD_ATENA.RIREKI_EDABAN+ 1;
--2025/09/05 CTC.liu update end
          END IF;
--2025/5/23 CTC.liu update start
--        END IF;
        ELSE
--2025/5/23 CTC.liu update end
--2025/5/23 CTC.liu add
          ------------------------------------------------
          -- 住基異動ＴＢＬの現住所連番を更新
          ------------------------------------------------
          IF CR_IDO.GENJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET GENJUSHO_REN = R_JUSHO.JUSHO_REN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの前住所連番を更新
          ------------------------------------------------
          IF CR_IDO.ZENJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET ZENJUSHO_REN = R_JUSHO.JUSHO_REN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの転入前住所連番を更新
          ------------------------------------------------
          IF CR_IDO.TENNYUMAE_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET TENNYUMAE_REN = R_JUSHO.JUSHO_REN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの転入未届地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENNYU_MITODOKE_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET TENNYU_MITODOKE_REN = R_JUSHO.JUSHO_REN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの本籍地連番を更新
          ------------------------------------------------
          IF CR_IDO.HONSEKI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET HONSEKI_REN = R_JUSHO.JUSHO_REN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの転出予定地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENSHUTSU_YOTEI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET TENSHUTSU_YOTEI_REN = R_JUSHO.JUSHO_REN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          ------------------------------------------------
          -- 住基異動ＴＢＬの転出確定地連番を更新
          ------------------------------------------------
          IF CR_IDO.TENSHUTSU_KAKUTEI_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET TENSHUTSU_KAKUTEI_REN = R_JUSHO.JUSHO_REN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
          --2025/02/19 CTC Update start 0.3.000.000:IT_JIB_01005対応
          ------------------------------------------------
          -- 住基異動ＴＢＬの最終登録連番を更新
          ------------------------------------------------
          IF CR_IDO.SAISYUTOROKUJUSHO_REN = M_JUSHO(I).JUSHO_REN THEN
            UPDATE JIBTJUKIIDO
              SET SAISYUTOROKUJUSHO_REN = R_JUSHO.JUSHO_REN
            WHERE KOJIN_NO = T_KOJIN_NO;
          END IF;
        END IF;
--2025/5/23 CTC.liu add
        END IF;
      END LOOP;
      ------------------------------------------------
      -- 住基異動ＴＢＬの現住所連番を更新
      ------------------------------------------------
      UPDATE JIBTJUKIIDO
         SET SAIDAI_JUSHO_REN =
                              (SELECT NVL(MAX(JUSHO_REN),0)
                               FROM JIBTJUKIJUSHO
                               WHERE JIBTJUKIIDO.KOJIN_NO = JIBTJUKIJUSHO.KOJIN_NO
                              )
       WHERE KOJIN_NO = T_KOJIN_NO;
      IF CR_IDO.JINKAKU_KBN = 1 THEN
        --異動事由は11,12,13,18,24の場合、JIBWBUPD_TSUSHORIREKIテーブルを追加
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--        IF CR_IDO.IDO_JIYU IN (11,12,13,18,28) OR (CR_IDO.IDO_JIYU = 41 AND CR_IDO.ZENBU_ICHIBU_KEY = 1) THEN
        --「41:職権修正」の記載箇所を「「410:職権修正」or「412:誤記修正」」に修正する。
--2024/02/25 DIS.Qianyinhua Update 0.3.000.000:新WizLIFE２次開発（異動事由コードの一括対応）
--        IF CR_IDO.IDO_JIYU IN (110,120,130,180,280) OR (CR_IDO.IDO_JIYU IN (410,412) AND CR_IDO.ZENBU_ICHIBU_KEY = 1) THEN
--2025/10/07 CTC.liu update start 1.0.021.001:新WizLIFE保守対応 QA21654
        --IF CR_IDO.IDO_JIYU IN (110,111,120,130,180,280) OR (CR_IDO.IDO_JIYU IN (410,412) AND CR_IDO.ZENBU_ICHIBU_KEY = 1) THEN
--2025/11/05 CTC.liu update start 1.0.026.000:新WizLIFE保守対応 QA22785
        --IF CR_IDO.IDO_JIYU IN (110,111,120,130,180,280) OR (CR_IDO.IDO_JIYU IN (410,412,411) AND CR_IDO.ZENBU_ICHIBU_KEY = 1) THEN
        IF CR_IDO.IDO_JIYU IN (110,111,120,130,180,280) OR (CR_IDO.IDO_JIYU IN (410,412,411,416,417) AND CR_IDO.ZENBU_ICHIBU_KEY = 1) THEN
--2024/01/25 DIS.liuqimeng Update end
          FOR CR_BUPD_TSUSHORIREKI IN C_BUPD_TSUSHORIREKI(CR_IDO.ENTRY_ID,CR_IDO.KOJIN_NO,R_BUPD_ATENA.RIREKI_RENBAN) LOOP
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--            IF CR_IDO.IDO_JIYU = 28 AND NJOKEN111 = 1 THEN
            IF CR_IDO.IDO_JIYU = 280 AND NJOKEN111 = 1 THEN
              T_RIREKI_RENBAN := CR_BUPD_TSUSHORIREKI.RIREKI_RENBAN + 10;
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--            ELSIF CR_IDO.IDO_JIYU = 28 AND NJOKEN111 = 0 THEN
            ELSIF CR_IDO.IDO_JIYU = 280 AND NJOKEN111 = 0 THEN
              T_RIREKI_RENBAN := 10;
--2025/10/29 CTC.liu add start 1.0.025.002:新WizLIFE保守対応 QA22490
            ELSIF GAB_RIREKI_RENBAN <> 0 THEN
              T_RIREKI_RENBAN := GAB_RIREKI_RENBAN+10;
            ELSE
              T_RIREKI_RENBAN := CR_BUPD_TSUSHORIREKI.RIREKI_RENBAN;
            END IF;
            INSERT INTO JIBTTSUSHORIREKI VALUES
              ( T_KOJIN_NO,
                T_RIREKI_RENBAN,
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
--2025/09/11 CTC.liu update start 1.0.017.001:新WizLIFE保守対応 QA2071
                 -- 1,                        --履歴枝番
                CASE
                 WHEN CR_IDO.IDO_JIYU IN (412) THEN R_BUPD_ATENA.RIREKI_EDABAN + 1
                 ELSE 1
                END,
--2025/09/11 CTC.liu update end
                CR_BUPD_TSUSHORIREKI.RENBAN,
                CR_BUPD_TSUSHORIREKI.TOROKU_BI,
                CR_BUPD_TSUSHORIREKI.TOROKU_USER_CD,
                CR_BUPD_TSUSHORIREKI.SAKUJO_BI,
                CR_BUPD_TSUSHORIREKI.SAKUJO_USER_CD,
                CR_BUPD_TSUSHORIREKI.TSUSHO_KANA,
                CR_BUPD_TSUSHORIREKI.TSUSHO_KANJI,
                i_SHORIBI,
                0,
                I_SYSTIME,
                i_NSHOKUIN,
                i_NTANMATSU_NO
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
               ,CR_BUPD_TSUSHORIREKI.TSUSHO_KANA_FLG   --通称カナフラグ
              );
          END LOOP;
        ----異動事由は11,12,13,18,24の以外の場合、EBT_TSUSHORIREKIテーブルを追加
        ELSE
--2025/09/12 CTC.liu update start 1.0.017.002:新WizLIFE保守対応 QA21118
         IF CR_IDO.IDO_JIYU IN (412) THEN
            TUSHORENBAN:=R_BUPD_ATENA.RIREKI_RENBAN;
         ELSE
            TUSHORENBAN:=R_BUPD_ATENA.RIREKI_RENBAN-10;
         END IF;
          --FOR CR_TSUSHORIREKI IN C_TSUSHORIREKI(CR_IDO.KOJIN_NO,R_BUPD_ATENA.RIREKI_RENBAN-10) LOOP
          FOR CR_TSUSHORIREKI IN C_TSUSHORIREKI(CR_IDO.KOJIN_NO,TUSHORENBAN) LOOP
            T_RIREKI_RENBAN := R_BUPD_ATENA.RIREKI_RENBAN;
--2025/09/12 CTC.liu update end
            INSERT INTO JIBTTSUSHORIREKI VALUES
              ( T_KOJIN_NO,
                T_RIREKI_RENBAN,
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
--2025/09/11 CTC.liu update start 1.0.017.001:新WizLIFE保守対応 QA2071
                 -- 1,                        --履歴枝番
                CASE
                 WHEN CR_IDO.IDO_JIYU IN (412) THEN R_BUPD_ATENA.RIREKI_EDABAN + 1
                 ELSE 1
                END,
--2025/09/11 CTC.liu update end
                CR_TSUSHORIREKI.RENBAN,
                CR_TSUSHORIREKI.TOROKU_BI,
                CR_TSUSHORIREKI.TOROKU_USER_CD,
                CR_TSUSHORIREKI.SAKUJO_BI,
                CR_TSUSHORIREKI.SAKUJO_USER_CD,
                CR_TSUSHORIREKI.TSUSHO_KANA,
                CR_TSUSHORIREKI.TSUSHO_KANJI,
                i_SHORIBI,
                0,
                I_SYSTIME,
                i_NSHOKUIN,
                i_NTANMATSU_NO
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
              ,CR_TSUSHORIREKI.TSUSHO_KANA_FLG   --通称カナフラグ
              );
          END LOOP;
        END IF;
      END IF;
     IF CR_IDO.SHIMEI_KANA IS NOT NULL AND REPLACE(NVL(CR_IDO.SHIMEI_KANA,'　'),'　','') IS NOT NULL  THEN
      I_POS                := NVL(INSTR(RTRIM(CR_IDO.SHIMEI_KANA,'　'),'　'),0);
      IF I_POS > 30 OR I_POS <= 1 THEN
  -- 姓
         T_YOMI_KANA_SEI      := SUBSTR(CR_IDO.SHIMEI_KANA,1,30);                                         -- 姓の切出し
      ELSE
        -- 姓
        T_YOMI_KANA_SEI      := SUBSTR(CR_IDO.SHIMEI_KANA,1,I_POS);                                      -- 姓の切出し
      END IF;
      T_YOMI_KANA_SEI      := KKAPK0010.FSKANA(T_YOMI_KANA_SEI);                                        -- 濁点の削除
      IF LENGTH(CR_IDO.SHIMEI_KANA)-I_POS > 30 THEN
  -- 名
        T_YOMI_KANA_MEI      := SUBSTR(CR_IDO.SHIMEI_KANA,I_POS+1,30);                                   -- 名の切出し
      ELSE
        -- 名
        T_YOMI_KANA_MEI      := SUBSTR(CR_IDO.SHIMEI_KANA,I_POS+1,LENGTH(CR_IDO.SHIMEI_KANA)-I_POS);     -- 名の切出し
      END IF;
      T_YOMI_KANA_MEI      := KKAPK0010.FSKANA(T_YOMI_KANA_MEI);                                        -- 濁点の削除
       I_POS                := NVL(INSTR(RTRIM(CR_IDO.SHIMEI_KANJI,'　'),'　'),0);

      IF I_POS > 30 OR I_POS <= 1 THEN
  -- 姓
        T_HENKANYO_KANJI_SEI := SUBSTR(CR_IDO.SHIMEI_KANJI,1,30);                                        -- 姓の切出し
      ELSE
        -- 姓
        T_HENKANYO_KANJI_SEI := SUBSTR(CR_IDO.SHIMEI_KANJI,1,I_POS);                                     -- 姓の切出し
      END IF;
      I_CNT1 := KKAPK3000.FNAMEEDIT(1,30,T_HENKANYO_KANJI_SEI,T_HENKANYO_KANJI_SEI,T_KANJI2,T_KANJI3);  -- 桁数合わせ
      IF LENGTH(CR_IDO.SHIMEI_KANJI)-I_POS > 30 THEN
        -- 名
        T_HENKANYO_KANJI_MEI := SUBSTR(CR_IDO.SHIMEI_KANJI,I_POS+1,30);                                  -- 名の切出し
      ELSE
        -- 名
        T_HENKANYO_KANJI_MEI := SUBSTR(CR_IDO.SHIMEI_KANJI,I_POS+1,LENGTH(CR_IDO.SHIMEI_KANJI)-I_POS);   -- 名の切出し
      END IF;
      I_CNT1 := KKAPK3000.FNAMEEDIT(1,30,T_HENKANYO_KANJI_MEI,T_HENKANYO_KANJI_MEI,T_KANJI2,T_KANJI3);  -- 桁数合わせ

      ------------------------------------------------
      -- 氏名変換データ抽出
      ------------------------------------------------
      ------------------------------------------------
      -- 姓
      ------------------------------------------------
      SELECT COUNT(*)
        INTO I_CNT1
        FROM GABTSHIMEIHENKAN
       WHERE SHIMEI_KBN = 1
         AND YOMI_KANA = T_YOMI_KANA_SEI
         AND HENKANYO_KANJI = T_HENKANYO_KANJI_SEI;
      ------------------------------------------------
      -- 判定
      ------------------------------------------------
      IF I_CNT1 = 0 THEN
        -- 最大連番の取得
        SELECT NVL(MAX(RENBAN),0)
          INTO I_CNT1
          FROM GABTSHIMEIHENKAN
         WHERE SHIMEI_KBN = 1
           AND YOMI_KANA = T_YOMI_KANA_SEI;
        -- 追加
        INSERT INTO GABTSHIMEIHENKAN(
          SHIMEI_KBN,
          YOMI_KANA,
          RENBAN,
          SHIYO_KAISU,
          HENKANYO_KANJI,
          SYS_SAKUSEIBI,
          SYS_KOSHINBI,
          SYS_JIKAN,
          SYS_SHOKUINKOJIN_NO,
          SYS_TANMATSU_NO
        ) VALUES (
          1,
          T_YOMI_KANA_SEI,
          (I_CNT1 + 1),
          1,
          T_HENKANYO_KANJI_SEI,
          TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),
          0,
          TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS')),
          i_NSHOKUIN,
          i_NTANMATSU_NO
        );
      ELSE
        -- 使用回数の取得
        SELECT SHIYO_KAISU
          INTO I_CNT1
          FROM GABTSHIMEIHENKAN
         WHERE SHIMEI_KBN = 1
           AND YOMI_KANA = T_YOMI_KANA_SEI
           AND HENKANYO_KANJI = T_HENKANYO_KANJI_SEI ;
        -- 使用回数を更新
        UPDATE GABTSHIMEIHENKAN
           SET SHIYO_KAISU = (I_CNT1 + 1),
               SYS_KOSHINBI = TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),
               SYS_JIKAN = TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS')),
               SYS_SHOKUINKOJIN_NO = i_NSHOKUIN,
               SYS_TANMATSU_NO = i_NTANMATSU_NO
         WHERE SHIMEI_KBN = 1
           AND YOMI_KANA = T_YOMI_KANA_SEI
           AND HENKANYO_KANJI = T_HENKANYO_KANJI_SEI;
      END IF;
      ------------------------------------------------
      -- 氏名変換データ抽出
      ------------------------------------------------
      ------------------------------------------------
      -- 名
      ------------------------------------------------
      SELECT COUNT(*)
        INTO I_CNT1
        FROM GABTSHIMEIHENKAN
       WHERE SHIMEI_KBN = 2
         AND YOMI_KANA = T_YOMI_KANA_MEI
         AND HENKANYO_KANJI = T_HENKANYO_KANJI_MEI;
      ------------------------------------------------
      -- 判定
      ------------------------------------------------
      IF I_CNT1 = 0 THEN
        -- 最大連番の取得
        SELECT NVL(MAX(RENBAN),0)
          INTO I_CNT1
          FROM GABTSHIMEIHENKAN
         WHERE SHIMEI_KBN = 2
           AND YOMI_KANA = T_YOMI_KANA_MEI;

        -- 追加
        INSERT INTO GABTSHIMEIHENKAN(
          SHIMEI_KBN,
          YOMI_KANA,
          RENBAN,
          SHIYO_KAISU,
          HENKANYO_KANJI,
          SYS_SAKUSEIBI,
          SYS_KOSHINBI,
          SYS_JIKAN,
          SYS_SHOKUINKOJIN_NO,
          SYS_TANMATSU_NO
        ) VALUES (
          2,
          T_YOMI_KANA_MEI,
          (I_CNT1 + 1),
          1,
          T_HENKANYO_KANJI_MEI,
          TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),
          0,
          TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS')),
          i_NSHOKUIN,
          i_NTANMATSU_NO
        );
      ELSE
        -- 使用回数の取得
        SELECT SHIYO_KAISU
          INTO I_CNT1
          FROM GABTSHIMEIHENKAN
         WHERE SHIMEI_KBN = 2
           AND YOMI_KANA = T_YOMI_KANA_MEI
           AND HENKANYO_KANJI = T_HENKANYO_KANJI_MEI;
        -- 使用回数を更新
        UPDATE GABTSHIMEIHENKAN
           SET SHIYO_KAISU = (I_CNT1 + 1),
               SYS_KOSHINBI = TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),
               SYS_JIKAN = TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS')),
               SYS_SHOKUINKOJIN_NO = i_NSHOKUIN,
               SYS_TANMATSU_NO = i_NTANMATSU_NO
         WHERE SHIMEI_KBN = 2
           AND YOMI_KANA = T_YOMI_KANA_MEI
           AND HENKANYO_KANJI = T_HENKANYO_KANJI_MEI;
      END IF;
    END IF;
      ------------------------------------------------
      -- 宛名番号ＴＢＬ追加
      ------------------------------------------------
      SELECT COUNT(*)
        INTO I_CNT1
        FROM GABTATENANO
       WHERE KOJIN_NO = T_KOJIN_NO;
      ------------------------------------------------
      -- 住基住所ＴＢＬ検索判定
      ------------------------------------------------
      IF I_CNT1 = 0 THEN
        ------------------------------------------------
        -- 旧ユーザーコードを取得する
        ------------------------------------------------
        BEGIN
          SELECT KYUUSER_CD
            INTO N_KYUUSER_CD
            FROM KKATGAPPEIJOHO
           WHERE SANTEIDANTAI_CD = R_BUPD_ATENA.SANTEIDANTAI_CD;
        EXCEPTION
          WHEN OTHERS THEN
             N_KYUUSER_CD := 0;
        END;
        ------------------------------------------------
        -- 宛名番号ＴＢＬ追加
        ------------------------------------------------
        INSERT INTO GABTATENANO
        (
          KOJIN_NO,
          KYUUSER_CD,
          KYUKOJIN_NO,
          SYS_SAKUSEIBI,
          SYS_KOSHINBI,
          SYS_JIKAN,
          SYS_SHOKUINKOJIN_NO,
          SYS_TANMATSU_NO
        )
        VALUES
        (
          T_KOJIN_NO,
          N_KYUUSER_CD,
          CR_IDO.KYU_KOJIN_NO,
          TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD')),
          0,
          TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS')),
          i_NSHOKUIN,
          i_NTANMATSU_NO
        );
      END IF;
      VSQL := NULL;
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--      VSQL := 'INSERT INTO JIBWIDORUISEKI SELECT ''A'',' || T_KOJIN_NO || ',B.RIREKI_RENBAN,B.TEKIYO_BI,B.TOROKU_GYOMU,' || T_SETAI_NO || ',B.GENZON_KBN,
      VSQL := 'INSERT INTO JIBWIDORUISEKI SELECT ''A'',' || T_KOJIN_NO || ',B.RIREKI_RENBAN,B.RIREKI_EDABAN,B.SAISHIN_FLG,B.TORIKESHI_FLG,B.JOHYOYODATA_FLG,B.TEKIYO_BI,B.TOROKU_GYOMU,' || T_SETAI_NO || ',B.GENZON_KBN,
                      A.JUN_SETAI_KBN,B.JINKAKU_KBN,B.KOKUSEKI_CD,B.SHISHO_CD,B.CHIKU_CD,B.GYOSEIKU_CD,
                      B.HAN_CD,B.SHOGAKU_CD,B.CHUGAKU_CD,B.TOHYOKU_CD,B.SANTEIDANTAI_CD,B.SEINENGAPI,
                      B.WAREKI_SEINENGAPI,B.HYOJI_SEINENGAPI,B.SEIBETSU,B.USER_CD,B.OAZA_CD,B.HONBAN,
                      B.EDABAN1,B.EDABAN2,B.EDABAN3,B.KATAGAKI_CD,B.GAIKU,B.TOU,B.GOU,B.JICHI_CD,B.SHIMEI_KANA,
                      B.SHIMEI_KANJI,B.YUBIN_NO,B.YUBIN_NOBC,B.CHOMEI,B.BANCHI,B.KATAGAKI,B.DAIHYO_KATAGAKI,
                      B.DAIHYO_SHIMEI,B.TEL_NO,B.TEL_KBN,B.FAX_NO,B.MAIL_ADS,B.YUHEN_KBN,B.TOROKU_JIYU,' || T_JUMIN_CD || ',
                      A.ZOKUGARA_CD1,A.ZOKUGARA_CD2,A.ZOKUGARA_CD3,A.ZOKUGARA_CD4,A.ZOKUGARA_KBN,A.ZOKUGARA_MEI,
                      A.JITSU_ZOKUGARA_MEI,A.KISAI_JUNI,A.IDO_BI,A.IDO_JIYU,A.IDO_TODOKE_BI,A.IDO_TODOKE_KBN,A.JUTEI_BI,
                      A.JUTEI_JIYU,A.JUTEI_TODOKEDE_BI,A.JUTEI_TODOKEDE_KBN,A.GENJUSHO_REN,A.ZENJUSHO_REN,A.TENNYUMAE_REN,
                      A.TENNYU_MITODOKE_REN,A.HONSEKI_REN,
                      A.TENSHUTSU_YOTEI_BI,A.TENSHUTSU_YOTEI_TODOKEDE_BI,A.TENSHUTSU_YOTEI_TODOKEDE_KBN,A.TENSHUTSU_YOTEI_REN,
                      A.TENSHUTSU_KAKUTEI_BI,A.TENSHUTSU_KAKUTEI_TSUCHI_BI,A.TENSHUTSU_KAKUTEI_TODOKEDE_KBN,A.TENSHUTSU_KAKUTEI_REN,
                      A.JUMIN_NARU,A.JUMIN_NARU_JIYU,A.JUMIN_NARU_TODOKEDE_BI,A.JUMIN_NARU_TODOKEDE_KBN,A.JUMIN_NAKUNARU,
                      A.JUMIN_NAKUNARU_JIYU,A.JUMIN_NAKUNARU_TODOKEDE_BI,A.JUMIN_NAKUNARU_TODOKEDE_KBN,A.SHIBOBI_FUSHO_KBN,
                      B.HONMYO_KANA,B.HONMYO_KANJI,A.NUSHI_SHIMEI_KANA,A.NUSHI_SHIMEI_KANJI,A.BIKO,A.KAISEI_BI,A.KAISEI_REN,
                      A.KYU_SHIMEI_KANA,A.KYU_SHIMEI_KANJI,' || I_SYSDATE || ',' || I_SYSTIME || ',A.SHORI_KBN_KEY,A.ZENBU_ICHIBU_KEY,'''
                      || i_NSHOKUIN || ''',' || i_SHORIBI || ',' || I_SYSDATE || ',' || I_SYSTIME || ',''' || i_NSHOKUIN || ''','''  || i_NTANMATSU_NO || ''''||',
                      A.GOMI_CD,A.SINYO_CD,A.KOIKIKOFU_STOP_CD,B.CHOMEI_KANA,B.BANCHI_KANA,B.KATAGAKI_KANA,B.KATAGAKI_HIDE_FLG,
                      B.GAIJI_FLG,B.HOJINSOSHIKI_CD,B.JE_KOKUHOSHISANWARI_KBN,B.JE_JINTEKIGENMEN_KBN,B.JE_SHOYUSHAKEISHONIN_KBN,
                      B.JE_LINK_KOJIN_NO,B.JE_NAYOSE_NO,B.YOBI1_CD,B.YOBI2_CD,B.YOBI3_CD,B.YOBI4_CD,B.YOBI5_CD,B.YOBI1_CH,
                      B.YOBI2_CH,B.YOBI3_CH,B.YOBI4_CH,B.YOBI5_CH,' ||  I_SYSDATE || ',' || I_SYSTIME || ','''  || i_NTANMATSU_NO || ''''||
                      ',A.ALP_SHIMEI_KANA,A.ALP_SHIMEI_KANJI,A.GAI_SHIMEI_KANA,A.GAI_SHIMEI_KANJI,A.TSUSHOMEI_KANA,A.TSUSHOMEI_KANJI,
                      A.HEIKIMEI_KANA,A.HEIKIMEI_KANJI,A.GAIKOKU_JUMIN_NARU,A.ZAIRYU_NO_SHUBETSU,A.ZAIRYU_CARD_NO,A.ZAIRYU_SHIKAKU_CD,
                      A.ZAIRYU_SHURYO_BI,A.ZAIRYU_KIKAN_NEN,A.ZAIRYU_KIKAN_TSUKI,A.ZAIRYU_KIKAN_HI,A.CARD_MANRYO_BI,A.KBN_30_45,A.KYOJYUCHI_UMU,
                      A.SEINENGAPI_FUSHO_KBN,A.RYOKEN_BANGO,A.RYOKEN_HAKKO_BI,A.JORIKU_KYOKA_BI,A.JUMIN_NUSHI_SHIMEI,A.NUSHI_KBN '||

                      ' ,B.TOUGOU_NO, A.SEIDO_KOJIN_NO, B.SEIDO_HOJIN_NO ' ||
                      ' ,JH.KYUUJI_KANA, JH.KYUUJI_KANJI ' ||
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
                      ',B.KETAPRM, B.KOKUMEI_CD,' ||
                      '''' || VCHOSHACODE || '''' ||
                      ',A.SHIMEI_KANA_FLG,A.TSUSHO_KANA_FLG,JH.KYUUJI_KANA_FLG,A.JIJITSUJONOSETAINUSHI_KANA' ||
                      ',A.JIJITSUJONOSETAINUSHI_KANJI,A.SAISYUTOROKUJUSHO_REN,A.SAISEIKISAI_DATE,A.SAISEIKISAIDATE_FUSHO_FLG,A.SAISEIKISAIDATE_FUSHO_HYOKI'||
                      ',A.SAISEISHOJODATE,A.SAISEISHOJODATE_FUSHO_FLG,A.SAISEISHOJODATE_FUSHO_HYOKI,A.KBN_30_46_47,A.SEINENGAPI_FUSHO_HYOKI,A.IDO_BI_FUSHO_FLG'||
                      ',A.IDO_BI_FUSHO_HYOKI,A.JUTEI_BI_FUSHO_FLG,A.JUTEI_BI_FUSHO_HYOKI,A.JUMIN_NARU_FUSHO_FLG,A.JUMIN_NARU_FUSHO_HYOKI,A.JUMIN_NAKUNARU_FUSHO_FLG'||
                      ',A.JUMIN_NAKUNARU_FUSHO_HYOKI,A.KAISEI_BI_FUSHO_FLG,A.KAISEI_BI_FUSHO_HYOKI,A.GAIKOKU_JUMIN_NARU_FUSHO_FLG,A.GAIKOKU_JUMIN_NARU_FUSHO_HYOKI'||
                      ',A.SEIBETSU_FUSHO_KBN,A.IDO_JIYU_SHOSAI,A.IDOKOMOKU_1,A.RYUIJIKO_1,A.IDOKOMOKU_2,A.RYUIJIKO_2,A.IDOKOMOKU_3,A.RYUIJIKO_3' ||
                      ',A.RIREKI_SENTAKUFUKA_FLG ,A.TODOKEDE_NO ,A.TORIKESHI_TODOKEDE_NO ' ||
--2024/01/25 DIS.liuqimeng Add end
                      ' FROM JIBTJUKIIDO A,JIBTJUKIKIHON B ,JIBTJUKIJOHO JH WHERE A.KOJIN_NO = ' || T_KOJIN_NO || ' AND B.KOJIN_NO = ' || T_KOJIN_NO ||
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--                                                                             ' AND B.KOJIN_NO = JH.KOJIN_NO(+) AND B.RIREKI_RENBAN = JH.RIREKI_RENBAN(+) ';
                      ' AND B.KOJIN_NO = JH.KOJIN_NO(+) AND B.RIREKI_RENBAN = JH.RIREKI_RENBAN(+) AND B.RIREKI_EDABAN = JH.RIREKI_EDABAN(+) ';
      EXECUTE IMMEDIATE VSQL;
      --更新後の内容を宛名異動累積ワークテーブル（GABWRUISEKIKIHON）に書込む。
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--        IF CR_IDO.IDO_JIYU IN (15,16,28) AND NKADO_BI5 <= I_SYSDATE THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
        --IF CR_IDO.IDO_JIYU IN (150,160,280) AND NKADO_BI5 <= I_SYSDATE THEN
        IF CR_IDO.IDO_JIYU IN (150,160,280,191) AND NKADO_BI5 <= I_SYSDATE THEN
           IF NJOKEN111 = 0 THEN
              WK_RIREKI_RENBAN := 10;
           ELSE
              WK_RIREKI_RENBAN := R_BUPD_ATENA.RIREKI_RENBAN + 10;
           END IF;
        ELSE
           WK_RIREKI_RENBAN := R_BUPD_ATENA.RIREKI_RENBAN;
        END IF;
        INSERT INTO GABWRUISEKIKIHON
        ( KUBUN,
          KOJIN_NO,
          RIREKI_RENBAN,
          TEKIYO_BI,
          TOROKU_GYOMU,
          JUMINHYO_CD,
          SETAI_NO,
          GENZON_KBN,
          JINKAKU_KBN,
          KOKUSEKI_CD,
          SHISHO_CD,
          CHIKU_CD,
          GYOSEIKU_CD,
          HAN_CD,
          SHOGAKU_CD,
          CHUGAKU_CD,
          TOHYOKU_CD,
          SANTEIDANTAI_CD,
          SEINENGAPI,
          WAREKI_SEINENGAPI,
          HYOJI_SEINENGAPI,
          SEIBETSU,
          USER_CD,
          OAZA_CD,
          HONBAN,
          EDABAN1,
          EDABAN2,
          EDABAN3,
          KATAGAKI_CD,
          GAIKU,
          TOU,
          GOU,
          JICHI_CD,
          SHIMEI_KANA,
          SHIMEI_KANJI,
          HONMYO_KANA,
          HONMYO_KANJI,
          YUBIN_NO,
          YUBIN_NOBC,
          CHOMEI,
          BANCHI,
          KATAGAKI,
          DAIHYO_KATAGAKI,
          DAIHYO_SHIMEI,
          TEL_NO,
          TEL_KBN,
          FAX_NO,
          MAIL_ADS,
          YUHEN_KBN,
          TOROKU_JIYU,
          JUFUKU_KOJIN_NO,
          SYS_SAKUSEIBI,
          SYS_KOSHINBI,
          SYS_JIKAN,
          SYS_SHOKUINKOJIN_NO,
          SYS_TANMATSU_NO,
          CHOMEI_KANA,
          BANCHI_KANA,
          KATAGAKI_KANA,
          KATAGAKI_HIDE_FLG,
          GAIJI_FLG,
          HOJINSOSHIKI_CD,
          JE_KOKUHOSHISANWARI_KBN,
          JE_JINTEKIGENMEN_KBN,
          JE_SHOYUSHAKEISHONIN_KBN,
          JE_LINK_KOJIN_NO,
          JE_NAYOSE_NO,
          YOBI1_CD,
          YOBI2_CD,
          YOBI3_CD,
          YOBI4_CD,
          YOBI5_CD,
          YOBI1_CH,
          YOBI2_CH,
          YOBI3_CH,
          YOBI4_CH,
          YOBI5_CH,
          SHORIBI,
          SHORI_JIKAN,
          SHORI_TANMATSU_NO
         ,TOUGOU_NO
         ,SEIDO_KOJIN_NO
         ,SEIDO_HOJIN_NO
         ,ZOKUGARACD1
         ,ZOKUGARACD2
         ,ZOKUGARACD3
         ,ZOKUGARACD4
         ,ZOKUGARAKBN
         ,ZOKUGARAMEI
         ,JITSUZOKUGARAMEI
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
         ,IDO_JIYU
         ,IDO_TODOKE_BI
         ,ALP_SHIMEI_KANJI
         ,GAI_SHIMEI_KANJI
         ,KYUUJI_KANA
         ,KYUUJI_KANJI
         ,TSUSHOMEI_KANA
         ,TSUSHOMEI_KANJI
         ,FURIGANAKAKUNIN_TSUSHO
         ,SEINENGAPI_FUSHO_KBN
         ,SEINENGAPI_FUSHO_HYOKI
         ,JUGAI_SHIBOBI
         ,ZAIRYU_NO_SHUBETSU
         ,ZAIRYU_CARD_NO
         ,ZAIRYU_SHIKAKU_CD
         ,ZAIRYU_SHURYO_BI
         ,ZAIRYU_KIKAN_NEN
         ,ZAIRYU_KIKAN_TSUKI
         ,ZAIRYU_KIKAN_HI
         ,TOUGOU_FLG
         ,TAGYOMUSANSYO_FLG
         ,DOKUJISHISAKUID
         ,GYOMUID
         ,HONSHITEN_KBN
         ,ZENGO_KBN
         ,KOHYODOI
         ,HOJIN_SHUBETSU
         ,HEISATOBI
         ,TANTOBUSHO
         ,DAIHYO_KANA
         ,NUSHI_SHIMEI_KANJI
         ,KOKUMEI_CD
         ,KETAPRM
--2024/01/25 DIS.liuqimeng Add end
--2024/03/26 DIS.liuqimeng Add start 0.3.000.000:受入検証指摘対応
         ,HOJIN_KANRI_NO
         ,SETSURITSU_BI
         ,HEISATO_JIYU
         ,YAGO
--2024/03/26 DIS.liuqimeng Add end
        )
        VALUES
        ( 'A',
          T_KOJIN_NO,
          WK_RIREKI_RENBAN,
          R_BUPD_ATENA.TEKIYO_BI,
          R_BUPD_ATENA.TOROKU_GYOMU,
          T_JUMIN_CD,
          T_SETAI_NO,
          R_BUPD_ATENA.GENZON_KBN,
          R_BUPD_ATENA.JINKAKU_KBN,
          R_BUPD_ATENA.KOKUSEKI_CD,
          R_BUPD_ATENA.SHISHO_CD,
          R_BUPD_ATENA.CHIKU_CD,
          R_BUPD_ATENA.GYOSEIKU_CD,
          R_BUPD_ATENA.HAN_CD,
          R_BUPD_ATENA.SHOGAKU_CD,
          R_BUPD_ATENA.CHUGAKU_CD,
          R_BUPD_ATENA.TOHYOKU_CD,
          R_BUPD_ATENA.SANTEIDANTAI_CD,
          R_BUPD_ATENA.SEINENGAPI,
          R_BUPD_ATENA.WAREKI_SEINENGAPI,
          R_BUPD_ATENA.HYOJI_SEINENGAPI,
          R_BUPD_ATENA.SEIBETSU,
          R_BUPD_ATENA.USER_CD,
          R_BUPD_ATENA.OAZA_CD,
          R_BUPD_ATENA.HONBAN,
          R_BUPD_ATENA.EDABAN1,
          R_BUPD_ATENA.EDABAN2,
          R_BUPD_ATENA.EDABAN3,
          R_BUPD_ATENA.KATAGAKI_CD,
          R_BUPD_ATENA.GAIKU,
          R_BUPD_ATENA.TOU,
          R_BUPD_ATENA.GOU,
          R_BUPD_ATENA.JICHI_CD,
          R_BUPD_ATENA.SHIMEI_KANA,
          R_BUPD_ATENA.SHIMEI_KANJI,
          R_BUPD_ATENA.HONMYO_KANA,
          R_BUPD_ATENA.HONMYO_KANJI,
          R_BUPD_ATENA.YUBIN_NO,
          R_BUPD_ATENA.YUBIN_NOBC,
          R_BUPD_ATENA.CHOMEI,
          R_BUPD_ATENA.BANCHI,
          R_BUPD_ATENA.KATAGAKI,
          R_BUPD_ATENA.DAIHYO_KATAGAKI,
          R_BUPD_ATENA.DAIHYO_SHIMEI,
          R_BUPD_ATENA.TEL_NO,
          R_BUPD_ATENA.TEL_KBN,
          R_BUPD_ATENA.FAX_NO,
          R_BUPD_ATENA.MAIL_ADS,
          R_BUPD_ATENA.YUHEN_KBN,
          R_BUPD_ATENA.TOROKU_JIYU,
          R_BUPD_ATENA.JUFUKU_KOJIN_NO,
          i_SHORIBI,
          0,
          TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS')),
          i_NSHOKUIN,
          i_NTANMATSU_NO,
          R_BUPD_ATENA.CHOMEI_KANA,
          R_BUPD_ATENA.BANCHI_KANA,
          R_BUPD_ATENA.KATAGAKI_KANA,
          R_BUPD_ATENA.KATAGAKI_HIDE_FLG,
          R_BUPD_ATENA.GAIJI_FLG,
          R_BUPD_ATENA.HOJINSOSHIKI_CD,
          R_BUPD_ATENA.JE_KOKUHOSHISANWARI_KBN,
          R_BUPD_ATENA.JE_JINTEKIGENMEN_KBN,
          R_BUPD_ATENA.JE_SHOYUSHAKEISHONIN_KBN,
          R_BUPD_ATENA.JE_LINK_KOJIN_NO,
          R_BUPD_ATENA.JE_NAYOSE_NO,
          R_BUPD_ATENA.YOBI1_CD,
          R_BUPD_ATENA.YOBI2_CD,
          R_BUPD_ATENA.YOBI3_CD,
          R_BUPD_ATENA.YOBI4_CD,
          R_BUPD_ATENA.YOBI5_CD,
          R_BUPD_ATENA.YOBI1_CH,
          R_BUPD_ATENA.YOBI2_CH,
          R_BUPD_ATENA.YOBI3_CH,
          R_BUPD_ATENA.YOBI4_CH,
          R_BUPD_ATENA.YOBI5_CH,
          I_SYSDATE,
          I_SYSTIME,
          i_NTANMATSU_NO
         ,R_BUPD_ATENA.TOUGOU_NO
         ,R_BUPD_ATENA.SEIDO_KOJIN_NO
         ,R_BUPD_ATENA.SEIDO_HOJIN_NO
         ,R_BUPD_ATENA.ZOKUGARACD1
         ,R_BUPD_ATENA.ZOKUGARACD2
         ,R_BUPD_ATENA.ZOKUGARACD3
         ,R_BUPD_ATENA.ZOKUGARACD4
         ,R_BUPD_ATENA.ZOKUGARAKBN
         ,R_BUPD_ATENA.ZOKUGARAMEI
         ,R_BUPD_ATENA.JITSUZOKUGARAMEI
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
         ,0    --異動事由
         ,0    --異動届出日
         ,NULL --アルファベット氏名漢字
         ,NULL --外国人氏名漢字
         ,NULL --旧氏名カナ
         ,NULL --旧氏名漢字
         ,NULL --通称名カナ
         ,NULL --通称名漢字
         ,0    --通称カナ確認状況
         ,0    --生年月日不詳区分
         ,NULL --生年月日不詳表記
         ,0    --住登外死亡年月日
         ,0    --在留番号種別
         ,NULL --在留カード番号
         ,0    --在留資格コード
         ,0    --在留期間終了年月日
         ,0    --在留期間年
         ,0    --在留期間月
         ,0    --在留期間日
         ,0    --統合宛名フラグ
         ,0    --他業務参照不可フラグ
         ,0    --独自施策システム等ID
         ,0    --業務ID
         ,0    --本支店区分
         ,0    --前後区分
         ,0    --法人番号公表の同意
         ,0    --法人種別
         ,0    --閉鎖等年月日
         ,NULL --法人担当部署
         ,NULL --代表者カナ
         ,NULL --世帯主氏名漢字
         ,0    --国名コード
         ,NULL --桁パラメータ
--2024/01/25 DIS.liuqimeng Add end
--2024/03/26 DIS.liuqimeng Add start 0.3.000.000:受入検証指摘対応
         ,0    --法人管理番号
         ,0    --設立年月日
         ,0    --閉鎖等事由
         ,NULL --屋号
--2024/03/26 DIS.liuqimeng Add end
        );
      ------------------------------------------------
      -- 異動区分判定
      ------------------------------------------------
      IF CR_IDO.IDO_JIYU = CR_IDO.SHORI_KBN_KEY THEN
        T_IDO_KBN := 1;
      ELSE
        T_IDO_KBN := 2;
      END IF;
      ------------------------------------------------
      -- 異動累計ＴＢＬ追加
      ------------------------------------------------
     T_NUSHI_JINKAKU_KBN := T_NUSHI_JINKAKU_KBN1;

     IF CR_IDO.SHORI_KBN_KEY IN (33,34,35,37) AND CR_IDO.SETAI_NO <> T_TARGET_SETAI_NO THEN
        T_NUSHI_JINKAKU_KBN := T_NUSHI_JINKAKU_KBN2;

     END IF;

      JIBSORUIUPD(
           T_KOJIN_NO
          ,T_JUMIN_CD
          ,CR_IDO.IDO_JIYU
--2024/01/25 DIS.liuqimeng Add 0.3.000.000:新WizLIFE２次開発
          ,VCHOSHACODE
          ,T_IDO_KBN
          ,CR_IDO.ZENBU_ICHIBU_KEY
          ,0
          ,NULL
          ,i_NTANMATSU_NO
          ,0
          ,I_SYSDATE
          ,I_SYSTIME
          ,1
          ,I_SYSDATE
          ,I_SYSTIME
          ,CR_IDO.SHORI_KBN_KEY
          ,CR_IDO.ZENBU_ICHIBU_KEY
          ,i_NSHOKUIN
          ,i_NSHOKUIN
          ,i_NTANMATSU_NO
          ,i_SHORIBI
          ,T_JINKAKU_KBN
          ,T_GENZON_KBN
          ,T_NUSHI_KBN
          ,T_OAZA_CD
          ,T_GYOSEIKU_CD
          ,T_CHIKU_CD
          ,T_NUSHI_JINKAKU_KBN
          ,T_JIYU_KBN2
      );
      --**********************************************
      --* 異動累計備考文作成
      --**********************************************
      WK_JINKAKU_KBN := 0;
      IF T_BIKO_BUN_KEY IS NULL OR
         T_BIKO_BUN_KEY != T_SETAI_NO THEN
        ---------------------------------------
        --既に備考文が蓄積されていた場合
        --異動累計の備考文を更新
        ---------------------------------------
        IF T_BIKO_BUN IS NOT NULL THEN
          -- 対象者全員の備考文を更新
          UPDATE JIBTIDORUIKEI
          SET BIKO_BUN = T_BIKO_BUN
          WHERE SHORIBI_KEY         = I_SYSDATE
          AND   SHORI_JIKAN_KEY     = I_SYSTIME
          AND   SHORI_KBN_KEY       = CR_IDO.SHORI_KBN_KEY
          AND   ZENBU_ICHIBU_KEY    = CR_IDO.ZENBU_ICHIBU_KEY
          AND   SHOKUINKOJIN_NO_KEY = i_NSHOKUIN
          AND   KOJIN_NO IN (SELECT KOJIN_NO FROM JIBTJUKIIDO WHERE SETAI_NO = T_BIKO_BUN_KEY);
          -- 更新用備考分を初期化
          T_BIKO_BUN := NULL;
        END IF;
        ---------------------------------------
        --異動対象先頭者の本籍住所情報を取得
        ---------------------------------------
        BEGIN
          SELECT JINKAKU_KBN
            INTO WK_JINKAKU_KBN
            FROM JIBWBUPD_JUKIIDO
           WHERE SETAI_NO = CR_IDO.SETAI_NO
             AND ENTRY_ID = i_IENTRY_ID
             AND GENZON_KBN = 0
             AND NUSHI_KBN = 1;
        EXCEPTION
            WHEN OTHERS THEN
               WK_JINKAKU_KBN := 0;
        END;
        IF  (CR_IDO.SETAI_NO != T_TARGET_SETAI_NO) OR
            (CR_IDO.SETAI_NO  = T_TARGET_SETAI_NO AND CR_IDO.IDO_JIYU = WK_IDO_JIYU) OR
            (WK_JINKAKU_KBN = 1 AND CR_IDO.JINKAKU_KBN = 0) THEN
          ---------------------------------------
          --異動対象先頭者の本籍住所情報を取得
          ---------------------------------------
           BEGIN
             SELECT CHOMEI,BANCHI,KATAGAKI,NUSHI_HITTOSYA
               INTO T_BIKO_FIRST_CHOMEI,T_BIKO_FIRST_BANCHI,T_BIKO_FIRST_KATAGAKI,T_BIKO_FIRST_HITTOSHA
               FROM JIBTJUKIIDO   JI,
                    JIBTJUKIJUSHO JJ
              WHERE JI.KOJIN_NO    = T_KOJIN_NO
                AND JI.KOJIN_NO    = JJ.KOJIN_NO
                AND JI.HONSEKI_REN = JJ.JUSHO_REN;

           EXCEPTION
              WHEN OTHERS THEN
               T_BIKO_FIRST_CHOMEI := NULL;
               T_BIKO_FIRST_BANCHI := NULL;
               T_BIKO_FIRST_KATAGAKI := NULL;
               T_BIKO_FIRST_HITTOSHA := NULL;
           END;
          ---------------------------------------
          --情報の初期化
          ---------------------------------------
           T_BIKO_BUN_KEY := T_SETAI_NO;
           I_IDO_COUNTER  := 1;
           IF WK_JINKAKU_KBN = 1 AND
              CR_IDO.JINKAKU_KBN = 0 THEN
                 T_BIKO_BUN := '[' || I_IDO_COUNTER || ']';
                 I_IDO_COUNTER := 1;
                 IF T_BIKO_FIRST_CHOMEI IS NOT NULL THEN
                    T_BIKO_BUN := T_BIKO_BUN || T_BIKO_FIRST_CHOMEI;
                 END IF;

                 IF T_BIKO_FIRST_BANCHI IS NOT NULL THEN
                    T_BIKO_BUN := T_BIKO_BUN || T_BIKO_FIRST_BANCHI;
                 END IF;

                 IF T_BIKO_FIRST_KATAGAKI IS NOT NULL THEN
                    T_BIKO_BUN := T_BIKO_BUN || T_BIKO_FIRST_KATAGAKI;
                 END IF;
                 IF T_BIKO_FIRST_HITTOSHA IS NOT NULL THEN
                    T_BIKO_BUN := SUBSTR((T_BIKO_BUN || '：' || T_BIKO_FIRST_HITTOSHA),1,120);
                 END IF;
           END IF;
        END IF;
      ELSE
        BEGIN
          SELECT JINKAKU_KBN
            INTO WK_JINKAKU_KBN
            FROM JIBWBUPD_JUKIIDO
           WHERE SETAI_NO = CR_IDO.SETAI_NO
             AND ENTRY_ID = i_IENTRY_ID
             AND GENZON_KBN = 0
             AND NUSHI_KBN = 1;
        EXCEPTION
            WHEN OTHERS THEN
               WK_JINKAKU_KBN := 0;
        END;
        I_IDO_COUNTER  := I_IDO_COUNTER+1;
        IF (CR_IDO.SETAI_NO != T_TARGET_SETAI_NO) OR                                    --異動元または先の主変更対象者
           (CR_IDO.SETAI_NO  = T_TARGET_SETAI_NO AND CR_IDO.IDO_JIYU = WK_IDO_JIYU) OR   --異動対象者
           (WK_JINKAKU_KBN = 1 AND CR_IDO.JINKAKU_KBN = 0) THEN
          ---------------------------------------
          --本籍情報を取得
          ---------------------------------------
           BEGIN
              SELECT CHOMEI,BANCHI,KATAGAKI,NUSHI_HITTOSYA
                INTO T_BIKO_HANTEI_CHOMEI,T_BIKO_HANTEI_BANCHI,T_BIKO_HANTEI_KATAGAKI,T_BIKO_HANTEI_HITTOSHA
                FROM JIBTJUKIIDO   JI,
                     JIBTJUKIJUSHO JJ
               WHERE JI.KOJIN_NO    = T_KOJIN_NO
                 AND JI.KOJIN_NO    = JJ.KOJIN_NO
                 AND JI.HONSEKI_REN = JJ.JUSHO_REN;
           EXCEPTION
                WHEN OTHERS THEN
                  T_BIKO_HANTEI_CHOMEI := NULL;
                  T_BIKO_HANTEI_BANCHI := NULL;
                  T_BIKO_HANTEI_KATAGAKI := NULL;
                  T_BIKO_HANTEI_HITTOSHA := NULL;
           END;
          ---------------------------------------
          --本籍情報が先頭対象の物と異なる場合、備考文生成
          ---------------------------------------
           IF T_BIKO_FIRST_CHOMEI   != T_BIKO_HANTEI_CHOMEI OR
              T_BIKO_FIRST_BANCHI   != T_BIKO_HANTEI_BANCHI OR
              T_BIKO_FIRST_KATAGAKI != T_BIKO_HANTEI_KATAGAKI OR
              T_BIKO_FIRST_HITTOSHA != T_BIKO_HANTEI_HITTOSHA  OR   --異動対象者
              (WK_JINKAKU_KBN = 1 AND CR_IDO.JINKAKU_KBN = 0)  THEN
            ---------------------------------------
            --個人見出し部　生成
            ---------------------------------------
              IF T_BIKO_BUN IS NULL THEN
                 T_BIKO_BUN := '[' || I_IDO_COUNTER || ']';
              ELSE
                 T_BIKO_BUN := T_BIKO_BUN || CHR(10) || '[' || I_IDO_COUNTER || ']';
              END IF;
            ---------------------------------------
            --本籍地名部　生成
            ---------------------------------------
              IF T_BIKO_FIRST_CHOMEI   != T_BIKO_HANTEI_CHOMEI OR
                 T_BIKO_FIRST_BANCHI   != T_BIKO_HANTEI_BANCHI OR
                 T_BIKO_FIRST_KATAGAKI != T_BIKO_HANTEI_KATAGAKI OR
                 (WK_JINKAKU_KBN = 1 AND CR_IDO.JINKAKU_KBN = 0)  THEN
                   IF T_BIKO_HANTEI_CHOMEI   IS NOT NULL THEN
                      T_BIKO_BUN := T_BIKO_BUN || T_BIKO_HANTEI_CHOMEI;
                   END IF;
                   IF T_BIKO_HANTEI_BANCHI   IS NOT NULL THEN
                      T_BIKO_BUN := T_BIKO_BUN || T_BIKO_HANTEI_BANCHI;
                   END IF;
                   IF T_BIKO_HANTEI_KATAGAKI IS NOT NULL THEN
                      T_BIKO_BUN := T_BIKO_BUN || T_BIKO_HANTEI_KATAGAKI;
                   END IF;
              END IF;
            ---------------------------------------
            --筆頭者部　生成
            ---------------------------------------
              IF ((T_BIKO_FIRST_CHOMEI   != T_BIKO_HANTEI_CHOMEI OR
                   T_BIKO_FIRST_BANCHI   != T_BIKO_HANTEI_BANCHI OR
                   T_BIKO_FIRST_KATAGAKI != T_BIKO_HANTEI_KATAGAKI) AND
                   T_BIKO_FIRST_HITTOSHA != T_BIKO_HANTEI_HITTOSHA) OR
                  (WK_JINKAKU_KBN = 1 AND CR_IDO.JINKAKU_KBN = 0) THEN
                   IF T_BIKO_HANTEI_HITTOSHA IS NOT NULL THEN
                      T_BIKO_BUN := SUBSTR((T_BIKO_BUN || '：' || T_BIKO_HANTEI_HITTOSHA),1,120);
                   END IF;
              ELSE
                 IF T_BIKO_FIRST_HITTOSHA != T_BIKO_HANTEI_HITTOSHA AND
                     T_BIKO_HANTEI_HITTOSHA IS NOT NULL THEN
                     T_BIKO_BUN := SUBSTR((T_BIKO_BUN || T_BIKO_HANTEI_HITTOSHA),1,120);
                 END IF;
              END IF;
          END IF;
        END IF;
      END IF;

      GABSKDRSKSNT(VKUBUN,i_SHORIBI,I_SYSDATE,I_SYSTIME,i_NSHOKUIN,i_NTANMATSU_NO);
      ------------------------------------------------
      -- 改製判定ＴＢＬ更新
      ------------------------------------------------
--2025/07/02 CTC.zhang delete 1.0.010.004:新WizLIFE保守対応 QA17509
--    JIBSOKAISEI(T_KOJIN_NO,1,i_NSHOKUIN,i_NTANMATSU_NO);
--2025/10/14 CTC.liu add start 1.0.022.002:新WizLIFE保守対応 QA21647
     BEGIN
      SELECT IDO.KAISEI_REN,
            IDO.IDO_TODOKE_BI,
            IDO.IDO_JIYU,
            KIHON.RIREKI_RENBAN,
--2026/1/7 CTC.zhang add start 1.0.105.000:新WizLIFE保守対応 QA25517
            NVL(RIREKI.RIREKI_RENBAN,0)
            INTO KAISEI_KAISEI_REN,KAISEI_IDO_TODOKE_BI,KAISEI_IDO_JIYU,KAISEI_RIREKI_RENBAN,RIREKI_RIREKI_RENBAN
        FROM JIBTJUKIIDO IDO,JIBTJUKIKIHON KIHON
--2026/1/7 CTC.zhang add start 1.0.105.000:新WizLIFE保守対応 QA25517
        LEFT JOIN JIBTJUKIRIREKI RIREKI
        ON RIREKI.KOJIN_NO = KIHON.KOJIN_NO
       WHERE IDO.KOJIN_NO = T_KOJIN_NO
         AND IDO.KOJIN_NO = KIHON.KOJIN_NO
--2026/1/7 CTC.zhang add start 1.0.105.000:新WizLIFE保守対応 QA25517
         AND RIREKI.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN) FROM JIBTJUKIRIREKI WHERE KOJIN_NO = T_KOJIN_NO)
         AND RIREKI.SAISHIN_FLG = 1
         AND IDO.IDO_JIYU IN (150,160,280,110,111);
       IF KAISEI_IDO_JIYU IN (150,160,280) THEN
        UPDATE JIBTJUKIIDO
           SET KAISEI_REN=KAISEI_KAISEI_REN+1,
               KAISEI_BI=KAISEI_IDO_TODOKE_BI
         WHERE KOJIN_NO = T_KOJIN_NO;
--2026/1/7 CTC.zhang add start 1.0.105.000:新WizLIFE保守対応 QA25517
--       ELSIF  KAISEI_IDO_JIYU IN (110,111) AND KAISEI_RIREKI_RENBAN <> 10 THEN
       ELSIF  KAISEI_IDO_JIYU IN (110,111) AND KAISEI_RIREKI_RENBAN <> 10 AND RIREKI_RIREKI_RENBAN <> 0 THEN
        UPDATE JIBTJUKIIDO
           SET KAISEI_REN=KAISEI_KAISEI_REN+1,
               KAISEI_BI=KAISEI_IDO_TODOKE_BI
         WHERE KOJIN_NO = T_KOJIN_NO;
--2026/1/7 CTC.zhang add start 1.0.105.000:新WizLIFE保守対応 QA25517
       ELSE
        UPDATE JIBTJUKIIDO
           SET KAISEI_REN=KAISEI_KAISEI_REN,
               KAISEI_BI=KAISEI_IDO_TODOKE_BI
         WHERE KOJIN_NO = T_KOJIN_NO;
       END IF;
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
       KAISEI_KAISEI_REN :=0;
       KAISEI_IDO_TODOKE_BI:=0;
       KAISEI_IDO_JIYU:=0;
       KAISEI_RIREKI_RENBAN:=0;
     END;
--2025/10/14 CTC.liu add end
      GABSKLNKDTPD(T_KOJIN_NO,N_RETN);
      -- 氏名検索(GABTSHIMEIKENSAKU)の作成（同定先・元を考慮）
      GABSKSHMKNSK(T_KOJIN_NO,i_NSHOKUIN,i_NTANMATSU_NO,N_RETN);
      ------------------------------------------------
      -- 対象異動事由の個人番号・履歴連番の一覧を返す
      ------------------------------------------------
      IF WK_IDO_JIYU = CR_IDO.IDO_JIYU THEN
        ------------------------------------------------
        -- 個人番号をカンマ区切りにしてＯＵＴパラメータで返す
        ------------------------------------------------
         NULL;
        ------------------------------------------------
        -- 個人番号をパイプ区切りにして住基ネット異動データ作成に渡す
        ------------------------------------------------
        IF V_KOJIN_NO IS NULL THEN
          V_KOJIN_NO := T_KOJIN_NO;
        ELSE
          V_KOJIN_NO := V_KOJIN_NO || '|' || T_KOJIN_NO;
        END IF;
        ------------------------------------------------
        -- 履歴連番をカンマ区切りにしてＯＵＴパラメータで返す
        ------------------------------------------------
        o_RIREKI_RENBAN := o_RIREKI_RENBAN || R_BUPD_ATENA.RIREKI_RENBAN;
        o_RIREKI_RENBAN := o_RIREKI_RENBAN || ',';
        ------------------------------------------------
        -- 世帯番号をＯＵＴパラメータで返す
        ------------------------------------------------
        o_VSEATI_NO := T_SETAI_NO;
      END IF;
      IF VKOJIN_NO_IDO IS NULL THEN
        VKOJIN_NO_IDO := T_KOJIN_NO;
        -- 個人番号
        o_VKOJIN_NO     := T_KOJIN_NO;
        o_VKOJIN_NO     := o_VKOJIN_NO     || ',';
        -- 履歴連番
        o_RIREKI_RENBAN := R_BUPD_ATENA.RIREKI_RENBAN;
        o_RIREKI_RENBAN := o_RIREKI_RENBAN || ',';
        -- 異動事由
        o_IDO_JIYU      := CR_IDO.IDO_JIYU;
        o_IDO_JIYU      := o_IDO_JIYU      || ',';
      ELSE
        VKOJIN_NO_IDO := VKOJIN_NO_IDO || '|' || T_KOJIN_NO;
        -- 個人番号
        o_VKOJIN_NO     := o_VKOJIN_NO     || T_KOJIN_NO;
        o_VKOJIN_NO     := o_VKOJIN_NO     || ',';
        -- 履歴連番
        o_RIREKI_RENBAN := o_RIREKI_RENBAN || R_BUPD_ATENA.RIREKI_RENBAN;
        o_RIREKI_RENBAN := o_RIREKI_RENBAN || ',';
        -- 異動事由
        o_IDO_JIYU      := o_IDO_JIYU      || CR_IDO.IDO_JIYU;
        o_IDO_JIYU      := o_IDO_JIYU      || ',';
      END IF;
      ------------------------------------------------------------------------------------------------
      -- エントリー管理中間（IES用）より該当する更新対象を取得、異動区分により各々の更新処理を呼び出す。
      ------------------------------------------------------------------------------------------------
      BEGIN
      SELECT  IDO_KBN,
              KEY_JOHO
        INTO  NIDO_KBN,
              VKEY_JOHO
        FROM  JIBWIES_ENTRYKANRI
       WHERE  GYOMUCODE = 'JIB'
         AND  ENTRYID = R_BUPD_JUKIJOHO.ENTRY_ID;
      EXCEPTION
        WHEN OTHERS THEN
          NIDO_KBN := 0;
      END;
      IF NIDO_KBN = 1 THEN
        JIBSOHONUPD(VKEY_JOHO,i_NSHOKUIN,i_NTANMATSU_NO);
      END IF;
      IF NIDO_KBN = 2 THEN
        JIBSOKISAIUPD(VKEY_JOHO,i_NSHOKUIN,i_NTANMATSU_NO);
      END IF;
--2023/06/27 ZCZL.WANGM ADD Start 0.2.000.001:住記系追加作業
      --転出届情報更新処理の呼び出しを追加
--    IF NREPORTCODE2 IN ('219' ,'210') THEN  --2025/07/07 Del
      IF NREPORTCODE2 IN ('21009' ,'21000') THEN  --2025/07/07 Add
        JIBSKTENOUTU(VKEY_JOHO,i_NSHOKUIN,i_NTANMATSU_NO,NSHORIKEKKA);
      END IF;
--2023/06/27 ZCZL.WANGM ADD End
    END IF;
    -- 世帯番号退避
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--    IF CR_IDO.IDO_JIYU = 11 OR
--       CR_IDO.IDO_JIYU = 33 OR
--       CR_IDO.IDO_JIYU = 34 OR
--       CR_IDO.IDO_JIYU = 35 OR
--       CR_IDO.IDO_JIYU = 37 THEN
    IF CR_IDO.IDO_JIYU = 110 OR
--2024/02/25 DIS.Qianyinhua Add 0.3.000.000:新WizLIFE２次開発（異動事由コードの一括対応）
       CR_IDO.IDO_JIYU = 111 OR
       CR_IDO.IDO_JIYU = 330 OR
       CR_IDO.IDO_JIYU = 340 OR
       CR_IDO.IDO_JIYU = 350 OR
       CR_IDO.IDO_JIYU = 370 THEN
--2024/01/25 DIS.liuqimeng Update end
      I_IDOSAKI := T_SETAI_NO;
    ELSE
      IF I_JIYU_FLG = 0 THEN
        I_IDOMOTO := T_SETAI_NO;
      END IF;
    END IF;
    -- 転出証明情報の更新
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--    IF i_IDO_JIYU = 11 AND i_FUKI_FLG = 1 THEN
--2024/02/25 DIS.Qianyinhua Update 0.3.000.000:新WizLIFE２次開発（異動事由コードの一括対応）
--    IF i_IDO_JIYU = 110 AND i_FUKI_FLG = 1 THEN
    IF i_IDO_JIYU IN (110,111) AND i_FUKI_FLG = 1 THEN
      -- 転出証明情報個人データ取得
      FOR CR_TENSHUTSUKOJIN IN C_TENSHUTSUKOJIN(T_JUMIN_CD) LOOP
        -- 転出証明個人処理済フラグを更新
        UPDATE JIBTJNTENSHUTSUKOJIN
           SET SHORIZUMI_FLAG = 1
         WHERE LPAD(TRIM(JUMINHYO_CD),11,'0') = LPAD(TO_NCHAR(T_JUMIN_CD),11,'0');
        -- 転出証明情報共通データ取得
        FOR CR_TENSHUTSUKOJIN2 IN C_TENSHUTSUKOJIN2(CR_TENSHUTSUKOJIN.TENSHUTUCHI_JICHI_CD,
                                                    CR_TENSHUTSUKOJIN.SAKUSEI_NENGAPPI,
                                                    CR_TENSHUTSUKOJIN.SAKUSEI_RENBAN) LOOP
          IF CR_TENSHUTSUKOJIN2.SHORIZUMI_FLAG != 1 THEN
            B_SHORI_FLG := FALSE;
          END IF;
        END LOOP;
        -- 転出証明共通処理済フラグを更新
        IF B_SHORI_FLG = TRUE THEN
          UPDATE JIBTJNTENSHUTSUKYOTU
             SET SHORIZUMI_FLAG = 1
           WHERE TENSHUTUCHI_JICHI_CD = CR_TENSHUTSUKOJIN.TENSHUTUCHI_JICHI_CD
             AND SAKUSEI_NENGAPPI     = CR_TENSHUTSUKOJIN.SAKUSEI_NENGAPPI
             AND SAKUSEI_RENBAN       = CR_TENSHUTSUKOJIN.SAKUSEI_RENBAN;
        END IF;
        -- フラグリセット
        B_SHORI_FLG := TRUE;
      END LOOP;
    END IF;
    --転居予定連絡情報個人の更新  --2025/02/14 Add S
    IF i_IDO_JIYU IN (310,320,330,340) THEN
      UPDATE JIBTTENKYOYOTEIKOJIN
         SET SHORIZUMI_FLAG      = 1
            ,SYS_KOSHINBI        = TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'))
            ,SYS_JIKAN           = TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS'))
            ,SYS_SHOKUINKOJIN_NO = i_NSHOKUIN
            ,SYS_TANMATSU_NO     = i_NTANMATSU_NO
       WHERE KOJIN_NO = T_KOJIN_NO
         AND SHORIZUMI_FLAG = 0;
    END IF;  --2025/02/14 Add E
    ---------------------------------------
    --備考文が蓄積されていた場合
    ---------------------------------------
    IF T_BIKO_BUN IS NOT NULL THEN
       -- 対象者全員の備考文を更新
       UPDATE JIBTIDORUIKEI
          SET BIKO_BUN = T_BIKO_BUN
        WHERE SHORIBI_KEY         = I_SYSDATE
          AND SHORI_JIKAN_KEY     = I_SYSTIME
          AND SHORI_KBN_KEY       = CR_IDO.SHORI_KBN_KEY
          AND ZENBU_ICHIBU_KEY    = CR_IDO.ZENBU_ICHIBU_KEY
          AND TRIM(SHOKUINKOJIN_NO_KEY) = TRIM(i_NSHOKUIN)
          AND KOJIN_NO IN (SELECT KOJIN_NO
                             FROM JIBTJUKIIDO
                            WHERE SETAI_NO = T_BIKO_BUN_KEY);
    END IF;
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--    IF NJOKEN4 = 3 AND i_IDO_JIYU IN (15,16) THEN
    IF NJOKEN4 = 3 AND i_IDO_JIYU IN (150,160) THEN
       /*
       EBPPKOSEKINEWXEROXTEXT(T_KOJIN_NO,
                              WK_RIREKI_RENBAN,
                              T_SETAI_NO,
                              CR_IDO.IDO_JIYU,
                              CR_IDO.IDO_BI,
                              CR_IDO.IDO_TODOKE_BI,
                              i_SHORIBI,
                             o_RETURNCD);
       */
       NULL;
      END IF;

    --異動事由＝52（記載順位訂正）の場合は行わない。
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--    IF CR_IDO.IDO_JIYU <> 52 THEN
    IF CR_IDO.IDO_JIYU <> 520 THEN
      --世帯員すべての宛名番号と異動事由を格納
      IF NSETAINO IS NULL THEN
        NSETAINO     := T_SETAI_NO;
        VIDOUKOJINNO := T_KOJIN_NO;
        VIDOJIYU     := CR_IDO.IDO_JIYU;
      ELSIF NSETAINO = T_SETAI_NO AND TO_NUMBER(VIDOJIYU) = CR_IDO.IDO_JIYU THEN
        VIDOUKOJINNO := VIDOUKOJINNO || ',' || T_KOJIN_NO;
      ELSIF NSETAINO <> T_SETAI_NO OR TO_NUMBER(VIDOJIYU) <> CR_IDO.IDO_JIYU THEN
      --世帯ごとにカード送付先データ作成処理の引数を格納
        IINDEX                := IINDEX + 1;
        MNSETAINO(IINDEX)     := NSETAINO;
        MVIDOJIYU(IINDEX)     := VIDOJIYU;
        MVIDOUKOJINNO(IINDEX) := VIDOUKOJINNO;
        NSETAINO              := T_SETAI_NO;
        VIDOUKOJINNO          := T_KOJIN_NO;
        VIDOJIYU              := CR_IDO.IDO_JIYU;
      END IF;
    END IF;

--2025/05/09 DIS.LIJING Add start 1.0.003.000:保守QA #14884対応
    --異動事由が210:国内転出、211:国外転出の場合
    IF CR_IDO.IDO_JIYU IN (210,211) THEN
      --支援措置申出者管理_申出者情報更新
      UPDATE GACTKANRI_MOUSHIDE
         SET RIREKI_RENBAN = RIREKI_RENBAN + 10
            ,SHIENSOCHISHURYOBI = KKAPK0020.FDATECAL(CR_IDO.IDO_BI,0,-1,0,0) --異動日の１日前
            ,KARISHIENSOCHIUMU = 1 --「仮支援措置のみ」
            ,KARISHIENSOCHIKAISHIBI = CR_IDO.IDO_BI
            ,KARISHIENSOCHISHURYOBI = 99999999
            ,SYS_KOSHINBI = CR_IDO.SYS_SAKUSEIBI
            ,SYS_JIKAN = CR_IDO.SYS_JIKAN
            ,SYS_SHOKUINKOJIN_NO = CR_IDO.SYS_SHOKUINKOJIN_NO
            ,SYS_TANMATSU_NO = CR_IDO.SYS_TANMATSU_NO
       WHERE ((KOJIN_NO = CR_IDO.KOJIN_NO
               AND TAISHOSHAKBN = 0)
             OR (TAISHO_ATENA_NO = CR_IDO.KOJIN_NO
               AND TAISHOSHAKBN = 1))
           AND NVL(SHIENSOCHIKAIJOBI, 0) = 0
           AND NVL(KARISHIENSOCHIUMU, 0) IN(0, 2);  --0:支援措置のみ  2:両方
       --上記更新対象レコードがある場合
       IF SQL%ROWCOUNT > 0 THEN
         SELECT COUNT(*)
           INTO NCOUNT
           FROM GACTIDOHAKKOYOKUSHIKANRI
          WHERE KOJIN_NO = CR_IDO.KOJIN_NO
            AND SYSTEM_TYP = 10
            AND TOROKU_GYOMU = 'JIB'
            AND YOKUSHIKBN = 1 --支援措置
            AND NVL(YOKUSHISHURYOKBN, 0) <> 3
            AND YOKUSHIJIYU = '01';

         IF NCOUNT > 0 THEN
            --仮支援措置のレコード作成
            INSERT INTO GACTIDOHAKKOYOKUSHIKANRI
                 SELECT KOJIN_NO
                       ,SYSTEM_TYP
                       ,TOROKU_GYOMU
                       ,RIREKI_RENBAN + 10
                       ,2
                       ,0
                       ,YOKUSHIJIYU
                       ,KOJINSETAIKBN
                       ,TAISHOSHAKBN
                       ,IDOYOKUSHIUMU
                       ,IDOYOKUSHI_GAITO_KBN
                       ,CR_IDO.IDO_BI
                       ,99999999
                       ,RIREKI_RENBAN + 10 AS IDOYOKUSHI_RIREKI_BANGO
                       ,HAKKOYOKUSHIUMU
                       ,HAKKOYOKUSHI_GAITO_KBN
                       ,CR_IDO.IDO_BI
                       ,99999999
                       ,RIREKI_RENBAN + 10 AS HAKKOYOKUSHI_RIREKI_BANGO
                       ,SHOKAIYOKUSHIUMU
                       ,SHOKAIYOKUSHI_GAITO_KBN
                       ,CR_IDO.IDO_BI
                       ,99999999
                       ,RIREKI_RENBAN + 10 AS SHOKAIYOKUSHI_RIREKI_BANGO
                       ,SHORICHUI_KBN
                       ,SYS_SAKUSEIBI
                       ,CR_IDO.SYS_SAKUSEIBI
                       ,CR_IDO.SYS_JIKAN
                       ,CR_IDO.SYS_SHOKUINKOJIN_NO
                       ,CR_IDO.SYS_TANMATSU_NO
-- 2025/06/19 CTC.li add start 1.0.009.002:新WizLIFE２次開発 QA13759対応
                       ,NULL
-- 2025/06/19 CTC.li add end
                  FROM GACTIDOHAKKOYOKUSHIKANRI
                 WHERE KOJIN_NO = CR_IDO.KOJIN_NO
                   AND SYSTEM_TYP = 10
                   AND TOROKU_GYOMU = 'JIB'
                   AND YOKUSHIKBN = 1 --支援措置
                   AND NVL(YOKUSHISHURYOKBN, 0) <> 3
                   AND YOKUSHIJIYU = '01'
                   AND ROWNUM = 1
              ORDER BY RIREKI_RENBAN DESC;
           --支援措置のレコードを抑止終了に更新
           UPDATE GACTIDOHAKKOYOKUSHIKANRI
              SET YOKUSHISHURYOKBN = 3
                 ,IDOYOKUSHISHURYOBI = KKAPK0020.FDATECAL(CR_IDO.IDO_BI,0,-1,0,0) --異動日の１日前
                 ,HAKKOYOKUSHISHURYOBI = KKAPK0020.FDATECAL(CR_IDO.IDO_BI,0,-1,0,0) --異動日の１日前
                 ,SHOKAIYOKUSHISHURYOBI = KKAPK0020.FDATECAL(CR_IDO.IDO_BI,0,-1,0,0) --異動日の１日前
                 ,SYS_KOSHINBI = CR_IDO.SYS_SAKUSEIBI
                 ,SYS_JIKAN = CR_IDO.SYS_JIKAN
                 ,SYS_SHOKUINKOJIN_NO = CR_IDO.SYS_SHOKUINKOJIN_NO
                 ,SYS_TANMATSU_NO = CR_IDO.SYS_TANMATSU_NO
            WHERE KOJIN_NO = CR_IDO.KOJIN_NO
              AND SYSTEM_TYP = 10
              AND TOROKU_GYOMU = 'JIB'
              AND YOKUSHIKBN = 1 --支援措置
              AND NVL(YOKUSHISHURYOKBN, 0) <> 3
              AND YOKUSHIJIYU = '01';
         END IF;
         --上記更新対象レコードがある場合
         IF SQL%ROWCOUNT > 0 THEN
            --GACFKGACTKANRI_支援措置申出者管理更新を実行する
            N_RETN := GACFKGACTKANRI(CR_IDO.KOJIN_NO, 10);
         END IF;
       END IF;
    END IF;
--2025/01/09 DIS.LIJING Add end
--2025/07/14 CTC.zhang update start 1.0.010.006:新WizLIFE保守対応 QA17556
    FOR CR_JIBWBUPD_BIKO IN CUR_JIBWBUPD_BIKO(CR_IDO.KOJIN_NO)  LOOP
      INSERT INTO JIBTJUKIBIKO VALUES(
      T_KOJIN_NO      --宛名番号
--2025/10/08 CTC.liu update start 1.0.021.001:新WizLIFE保守対応 QA21666
      --,CR_JIBWBUPD_BIKO.RIREKI_RENBAN --履歴連番
      ,(CASE WHEN CR_JIBWBUPD_BIKO.IDO_JIYU IN (150,160,280,191) AND NJOKEN111 = 1 THEN
              CR_JIBWBUPD_BIKO.RIREKI_RENBAN+10
             WHEN CR_JIBWBUPD_BIKO.IDO_JIYU IN (150,160,280,191) AND NJOKEN111 = 0 THEN
              10
         ELSE
              CR_JIBWBUPD_BIKO.RIREKI_RENBAN--履歴枝番
       END)
--2025/10/08 CTC.liu update end
      --,1 --履歴枝番
      ,(CASE WHEN CR_JIBWBUPD_BIKO.IDO_JIYU =412 THEN
              CR_JIBWBUPD_BIKO.RIREKI_EDABAN+1
         ELSE
              1 --履歴枝番
       END)
      ,CR_JIBWBUPD_BIKO.SAISHIN_FLG    --最新フラグ
      ,CR_JIBWBUPD_BIKO.SEQ           --連番
      ,CR_JIBWBUPD_BIKO.BIKO          --備考内容
      ,CR_JIBWBUPD_BIKO.GOKIFLG       --誤記フラグ
      ,CR_JIBWBUPD_BIKO.HISSUKBN      --必須区分
      ,CR_JIBWBUPD_BIKO.KISAIJUN      --記載順
      ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SHIMEI        --誤記修正後の氏名
      ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SHIMEI_KANA   --誤記修正後の氏名のフリガナ
      ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SEINENGAPI    --誤記修正後の生年月日
      ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SEINENGAPI_FUSHO_K --誤記修正後の生年月日不詳区分
      ,i_SHORIBI                       --作成日
      ,i_SHORIBI                       --更新日
      ,I_SYSTIME2                      --更新時間
      ,i_NSHOKUIN                      --更新職員宛名番号
      ,i_NTANMATSU_NO                  --更新端末番号
      );
    END LOOP;
--2025/07/14 CTC.zhang update end
  END LOOP;

  --転居予定連絡情報共通の更新  --2025/02/14 Add S
  IF i_IDO_JIYU IN (310,320,330,340) THEN
      UPDATE JIBTTENKYOYOTEIKYOTU
         SET SHORIZUMI_FLAG      = 1
            ,SYS_KOSHINBI        = TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'))
            ,SYS_JIKAN           = TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS'))
            ,SYS_SHOKUINKOJIN_NO = i_NSHOKUIN
            ,SYS_TANMATSU_NO     = i_NTANMATSU_NO
       WHERE SETAI_NO = I_IDOMOTO
         --未処理の転居予定連絡情報個人が存在しない
         AND NOT EXISTS(SELECT 1
                          FROM JIBTTENKYOYOTEIKYOTU A, JIBTTENKYOYOTEIKOJIN B
                         WHERE A.SETAI_NO = I_IDOMOTO
                           AND A.SAKUSEI_NENGAPPI = B.SAKUSEI_NENGAPPI
                           AND A.SAKUSEI_RENBAN = B.SAKUSEI_RENBAN
                           AND B.SHORIZUMI_FLAG = 0);
    END IF;  --2025/02/14 Add E

--2025/07/14 CTC.zhang update start 1.0.010.006:新WizLIFE保守対応 QA17556
/*
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
  FOR CR_JIBWBUPD_BIKO IN CUR_JIBWBUPD_BIKO LOOP
    INSERT INTO JIBTJUKIBIKO VALUES(
--2024/12/11 DIS.huangyy Update 0.3.000.000:IT_JIB_00737
--    CR_JIBWBUPD_BIKO.KOJIN_NO      --宛名番号
    T_KOJIN_NO      --宛名番号
--2024/12/6 CTC Update start 0.3.000.000:IT_JIB_00645対応
    --,CR_JIBWBUPD_BIKO.RIREKI_RENBAN + 1 --履歴連番
    ,CR_JIBWBUPD_BIKO.RIREKI_RENBAN --履歴連番
    --,1 --履歴枝番
    ,(CASE WHEN CR_JIBWBUPD_BIKO.IDO_JIYU =412 THEN
            CR_JIBWBUPD_BIKO.RIREKI_EDABAN+1
       ELSE
            1 --履歴枝番
     END)
--2024/12/6 CTC Update end
--2024/08/15 DIS.liuqimeng Add 0.3.000.000:IT_JIB_00231
    ,CR_JIBWBUPD_BIKO.SAISHIN_FLG    --最新フラグ
    ,CR_JIBWBUPD_BIKO.SEQ           --連番
    ,CR_JIBWBUPD_BIKO.BIKO          --備考内容
    ,CR_JIBWBUPD_BIKO.GOKIFLG       --誤記フラグ
    ,CR_JIBWBUPD_BIKO.HISSUKBN      --必須区分
    ,CR_JIBWBUPD_BIKO.KISAIJUN      --記載順
--2024/08/15 DIS.liuqimeng Add start 0.3.000.000:IT_JIB_00231
    ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SHIMEI        --誤記修正後の氏名
    ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SHIMEI_KANA   --誤記修正後の氏名のフリガナ
    ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SEINENGAPI    --誤記修正後の生年月日
    ,CR_JIBWBUPD_BIKO.GOKI_SHUSEI_SEINENGAPI_FUSHO_K --誤記修正後の生年月日不詳区分
--2024/08/15 DIS.liuqimeng Add end
    ,i_SHORIBI                       --作成日
    ,i_SHORIBI                       --更新日
    ,I_SYSTIME2                      --更新時間
    ,i_NSHOKUIN                      --更新職員宛名番号
    ,i_NTANMATSU_NO                  --更新端末番号
--2024/08/15 DIS.liuqimeng Delete 0.3.000.000:IT_JIB_00231
--    ,CR_JIBWBUPD_BIKO.SAISHIN_FLG    --最新フラグ
    );
  END LOOP;
*/
--2025/07/14 CTC.zhang update end
  FOR CR_JIBTJUKIBIKO IN CUR_JIBTJUKIBIKO LOOP
    INSERT INTO JIBWIDORUISEKI_BIKO VALUES(
      'B'
      ,CR_JIBTJUKIBIKO.KOJIN_NO      --宛名番号
      ,CR_JIBTJUKIBIKO.RIREKI_RENBAN --履歴連番
      ,CR_JIBTJUKIBIKO.RIREKI_EDABAN --履歴枝番
      ,CR_JIBTJUKIBIKO.SAISHIN_FLG   --最新フラグ
      ,CR_JIBTJUKIBIKO.SEQ           --連番
      ,CR_JIBTJUKIBIKO.BIKO          --備考内容
      ,CR_JIBTJUKIBIKO.GOKIFLG       --誤記フラグ
      ,CR_JIBTJUKIBIKO.HISSUKBN      --必須区分
      ,CR_JIBTJUKIBIKO.KISAIJUN      --記載順
      ,i_SHORIBI                       --引数.処理日
      ,I_SYSTIME2                      --システム時間
      ,i_NSHOKUIN                      --引数.職員番号
--2024/08/15 DIS.liuqimeng Add start 0.3.000.000:IT_JIB_00231
      ,CR_JIBTJUKIBIKO.GOKI_SHUSEI_SHIMEI      --誤記修正後の氏名
      ,CR_JIBTJUKIBIKO.GOKI_SHUSEI_SHIMEI_KANA --誤記修正後の氏名のフリガナ
      ,CR_JIBTJUKIBIKO.GOKI_SHUSEI_SEINENGAPI  --誤記修正後の生年月日
      ,CR_JIBTJUKIBIKO.GOKI_SHUSEI_SEINENGAPI_FUSHO_K --誤記修正後の生年月日不詳区分
--2024/08/15 DIS.liuqimeng Add end
      ,i_SHORIBI                       --作成日
      ,i_SHORIBI                       --更新日
      ,I_SYSTIME2                      --更新時間
      ,i_NSHOKUIN                      --更新職員宛名番号
      ,i_NTANMATSU_NO                  --更新端末番号
     );

    INSERT INTO JIBWIDORUISEKI_BIKO VALUES(
      'A'
      ,CR_JIBTJUKIBIKO.KOJIN_NO      --宛名番号
      ,CR_JIBTJUKIBIKO.RIREKI_RENBAN --履歴連番
      ,CR_JIBTJUKIBIKO.RIREKI_EDABAN --履歴枝番
      ,CR_JIBTJUKIBIKO.SAISHIN_FLG   --最新フラグ
      ,CR_JIBTJUKIBIKO.SEQ           --連番
      ,CR_JIBTJUKIBIKO.BIKO          --備考内容
      ,CR_JIBTJUKIBIKO.GOKIFLG       --誤記フラグ
      ,CR_JIBTJUKIBIKO.HISSUKBN      --必須区分
      ,CR_JIBTJUKIBIKO.KISAIJUN      --記載順
      ,i_SHORIBI                       --引数.処理日
      ,I_SYSTIME2                      --システム時間
      ,i_NSHOKUIN                      --引数.職員番号
--2024/08/15 DIS.liuqimeng Add start 0.3.000.000:IT_JIB_00231
      ,CR_JIBTJUKIBIKO.GOKI_SHUSEI_SHIMEI      --誤記修正後の氏名
      ,CR_JIBTJUKIBIKO.GOKI_SHUSEI_SHIMEI_KANA --誤記修正後の氏名のフリガナ
      ,CR_JIBTJUKIBIKO.GOKI_SHUSEI_SEINENGAPI  --誤記修正後の生年月日
      ,CR_JIBTJUKIBIKO.GOKI_SHUSEI_SEINENGAPI_FUSHO_K --誤記修正後の生年月日不詳区分
--2024/08/15 DIS.liuqimeng Add end
      ,i_SHORIBI                       --作成日
      ,i_SHORIBI                       --更新日
      ,I_SYSTIME2                      --更新時間
      ,i_NSHOKUIN                      --更新職員宛名番号
      ,i_NTANMATSU_NO                  --更新端末番号
    );
  END LOOP;
--2024/01/25 DIS.liuqimeng Add end

  IF NSETAINO IS NOT NULL THEN
    --世帯ごとにカード送付先データ作成処理の引数を格納
    IINDEX                := IINDEX + 1;
    MNSETAINO(IINDEX)     := NSETAINO;
    MVIDOJIYU(IINDEX)     := VIDOJIYU;
    MVIDOUKOJINNO(IINDEX) := VIDOUKOJINNO;
  --カード送付先データ作成処理を世帯ごとに呼び出す
    FOR I IN 1..IINDEX LOOP
--2023/11/20 DIS.Xiyan Update 0.3.000.000:住基ネット1次開発
--      JIBSKCARDSOFU(NYOBIDASHI_KBN,
      JIBSKCARDSOFJ(NYOBIDASHI_KBN,
                              MNSETAINO(I),
                              MVIDOUKOJINNO(I),
                              MVIDOJIYU(I),
                              i_NSHOKUIN,
                              i_NTANMATSU_NO);
    END LOOP;
  END IF;

  DELETE
    FROM JIBWBUPD_JUKIKIHON
   WHERE ENTRY_ID = i_IENTRY_ID;
  DELETE
    FROM JIBWBUPD_JUKIIDO
   WHERE ENTRY_ID = i_IENTRY_ID;
  DELETE
    FROM JIBWBUPD_JUKIJUSHO
   WHERE ENTRY_ID = i_IENTRY_ID;
  DELETE
    FROM JIBWBUPD_TSUSHORIREKI
   WHERE ENTRY_ID = i_IENTRY_ID;
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
  DELETE
    FROM JIBWBUPD_BIKO
   WHERE ENTRY_ID = i_IENTRY_ID;
--2024/01/25 DIS.liuqimeng Add end
  COMMIT;

  DELETE
    FROM JIBWBUPD_JUKIKIHON
   WHERE ENTRY_ID = i_IENTRY_ID;
  DELETE
    FROM JIBWIES_JUKIIDO
   WHERE ENTRY_ID = i_IENTRY_ID;
  DELETE
    FROM JIBWIES_JUKIJUSHO
   WHERE ENTRY_ID = i_IENTRY_ID;
  DELETE
    FROM JIBWIES_TSUSHORIREKI
   WHERE ENTRY_ID = i_IENTRY_ID;
--2024/01/25 DIS.liuqimeng Add start 0.3.000.000:新WizLIFE２次開発
  DELETE
    FROM JIBWIES_BIKO
   WHERE ENTRY_ID = i_IENTRY_ID;
--2024/01/25 DIS.liuqimeng Add end
  COMMIT;

  ------------------------------------------------
  -- 住基ネット異動データ作成
  ------------------------------------------------
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--  IF NKADO_BI5 <= I_SYSDATE AND NJOKEN111 = 0 AND WK_IDO_JIYU IN (15,16,28) THEN
--2025/5/14 CTC.liu update start 1.0.009.000:新WizLIFE２次開発 QA13667対応
--IF NKADO_BI5 <= I_SYSDATE AND NJOKEN111 = 0 AND WK_IDO_JIYU IN (150,160,280) THEN
  IF NKADO_BI5 <= I_SYSDATE AND NJOKEN111 = 0 AND WK_IDO_JIYU IN (150,160,280,191) THEN
      V_KOJIN_NO := J_KOJIN_NO || '|' || V_KOJIN_NO;

  END IF;
--2023/06/27 ZCZL.WANGM ADD Start 0.2.000.001:住記系追加作業
  BEGIN
    SELECT REPORTCODE2
      INTO NREPORTCODE2
      FROM KKFTENTRYLIST
     WHERE GYOMUCODE = 'JIB'
       AND ENTRYID = i_IENTRY_ID;
  EXCEPTION
    WHEN OTHERS THEN
      NREPORTCODE2 := 0;
  END;
--2023/06/27 ZCZL.WANGM ADD End
--2023/06/27 ZCZL.WANGM Update Start 0.2.000.001:住記系追加作業
--  JIBSOIDODATAK(i_SHORIBI,                      -- 処理日
--                       i_ZENBUICHIBU,                  -- 全部一部
--                       WK_IDO_JIYU,                    -- 異動事由
--                       I_IDOMOTO,                      -- 異動元世帯番号
--                       I_IDOSAKI,                      -- 異動先世帯番号
--                       V_KOJIN_NO,                     -- 個人番号
--                       i_FUKI_FLG,                     -- 付記フラグ
--                       i_KEIBI_FLG,                    -- 軽微な修正フラグ
--                       NSHORI_NO
--                      );
--2023/11/16 DIS.Xiyan Update 0.3.000.000:住基ネット1次開発
--   JIBSOIDODATAK(i_SHORIBI,                             -- 処理日
  JIBSOCRTIDDTJ(i_SHORIBI,                             -- 処理日
                       i_ZENBUICHIBU,                  -- 全部一部
                       WK_IDO_JIYU,                    -- 異動事由
                       I_IDOMOTO,                      -- 異動元世帯番号
                       I_IDOSAKI,                      -- 異動先世帯番号
                       V_KOJIN_NO,                     -- 個人番号
                       i_FUKI_FLG,                     -- 付記フラグ
                       i_KEIBI_FLG,                    -- 軽微な修正フラグ
--2023/11/20 DIS.Xiyan Update start 0.3.000.000:住基ネット1次開発
--                        NSHORI_NO,
--                        NREPORTCODE2
                       0,                      -- 住居地フラグ
                       '',                     -- 異動事由詳細
                       0,                      -- 住所変更フラグ
                       T_RENBAN               -- 住所連番
--2023/11/20 DIS.Xiyan Update end
                      );
--2023/06/27 ZCZL.WANGM Update End
--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--  IF WK_IDO_JIYU IN(11, 12, 13, 56, 57, 58, 14, 17, 18) AND i_SHORIBI >= NKADO_BI7 THEN
--2024/02/25 DIS.Qianyinhua Update 0.3.000.000:新WizLIFE２次開発（異動事由コードの一括対応）
--  IF WK_IDO_JIYU IN(110, 120, 130, 560, 570, 580, 140, 170, 180) AND i_SHORIBI >= NKADO_BI7 THEN
--2024/12/20 JIP.Yoshida delete start:IT_JIB_00809対応
--  IF WK_IDO_JIYU IN (110, 111, 120, 130, 560, 570, 580, 140, 170, 180) AND i_SHORIBI >= NKADO_BI7 THEN
--    JIBSOIDODATAM(i_SHORIBI, V_KOJIN_NO, i_NSHOKUIN, i_NTANMATSU_NO, NSHORI_NO, RTN_CD);
--  END IF;
--2024/12/20 JIP.Yoshida delete end

  IF NJOKEN2 = 0 AND NKADO_BI5 <= I_SYSDATE THEN
     IF NVL(I_IDOSAKI,0) > 0 THEN
        T_SETAI_NO := I_IDOSAKI;

     END IF;
     BEGIN
         FOR CR_HOMUSHO IN C_HOMUSHO(T_SETAI_NO,I_SYSDATE,I_SYSTIME) LOOP
           WK_JUSHO_CHG := 0;

--2024/01/25 DIS.liuqimeng Update 0.3.000.000:新WizLIFE２次開発
--           IF CR_HOMUSHO.JINKAKU_KBN = 1 AND CR_HOMUSHO.IDO_JIYU = 41 THEN
           IF CR_HOMUSHO.JINKAKU_KBN = 1 AND CR_HOMUSHO.IDO_JIYU IN (410,412) THEN
             BEGIN
                SELECT JIBTJUKIJUSHO.CHOMEI,
                       JIBTJUKIJUSHO.BANCHI,
                       JIBTJUKIJUSHO.KATAGAKI
                  INTO VACHOMEI,
                       VABANCHI,
                       VAKATAGAKI
                  FROM JIBTJUKIIDO,
                       JIBTJUKIJUSHO
                 WHERE JIBTJUKIIDO.KOJIN_NO = CR_HOMUSHO.KOJIN_NO
                   AND JIBTJUKIIDO.KOJIN_NO = JIBTJUKIJUSHO.KOJIN_NO
                   AND JIBTJUKIIDO.GENJUSHO_REN = JIBTJUKIJUSHO.JUSHO_REN;

             EXCEPTION
                WHEN OTHERS THEN
                    VACHOMEI  := NULL;
                    VABANCHI  := NULL;
                    VAKATAGAKI:= NULL;
             END;

             BEGIN
                SELECT JIBTJUKIJUSHO.CHOMEI,
                       JIBTJUKIJUSHO.BANCHI,
                       JIBTJUKIJUSHO.KATAGAKI
                  INTO VBCHOMEI,
                       VBBANCHI,
                       VBKATAGAKI
                  FROM JIBTJUKIRIREKI,
                       JIBTJUKIJUSHO
                 WHERE JIBTJUKIRIREKI.KOJIN_NO = CR_HOMUSHO.KOJIN_NO
                   AND JIBTJUKIRIREKI.RIREKI_RENBAN = (SELECT MAX(RIREKI_RENBAN)
                                                          FROM JIBTJUKIRIREKI
                                                         WHERE KOJIN_NO = CR_HOMUSHO.KOJIN_NO
                                                      GROUP BY KOJIN_NO)
                   AND JIBTJUKIRIREKI.KOJIN_NO = JIBTJUKIJUSHO.KOJIN_NO
--2024/02/22 DIS.Qianyinhua Add 0.3.000.000:新WizLIFE２次開発（最新フラグ＝１追加確認）
                   AND JIBTJUKIRIREKI.SAISHIN_FLG = 1
                   AND JIBTJUKIRIREKI.GENJUSHO_REN = JIBTJUKIJUSHO.JUSHO_REN;

             EXCEPTION
                WHEN OTHERS THEN
                    VBCHOMEI  := NULL;
                    VBBANCHI  := NULL;
                    VBKATAGAKI:= NULL;
             END;

             IF (VACHOMEI IS NOT NULL AND VBCHOMEI IS NOT NULL AND VACHOMEI <> VBCHOMEI) OR
                (VACHOMEI IS NOT NULL AND VBCHOMEI IS NULL) OR
                (VACHOMEI IS NULL AND VBCHOMEI IS NOT NULL) OR
                (VABANCHI IS NOT NULL AND VBBANCHI IS NOT NULL AND VABANCHI <> VBBANCHI) OR
                (VABANCHI IS NOT NULL AND VBBANCHI IS NULL) OR
                (VABANCHI IS NULL AND VBBANCHI IS NOT NULL) OR
                (VAKATAGAKI IS NOT NULL AND VBKATAGAKI IS NULL) OR
                (VAKATAGAKI IS NULL AND VBKATAGAKI IS NOT NULL) OR
                (VAKATAGAKI IS NOT NULL AND VBKATAGAKI IS NOT NULL AND VAKATAGAKI <> VBKATAGAKI) THEN
                    WK_JUSHO_CHG := 1;

             ELSE
                    WK_JUSHO_CHG := 0;

             END IF;
           END IF;

           IF (CR_HOMUSHO.JINKAKU_KBN = 1 AND
--2024/01/25 DIS.liuqimeng Update start 0.3.000.000:新WizLIFE２次開発
--              (CR_HOMUSHO.IDO_JIYU BETWEEN 11 AND 14 OR
--               CR_HOMUSHO.IDO_JIYU BETWEEN 17 AND 34 OR
--               CR_HOMUSHO.IDO_JIYU = 42)) OR
--              (CR_HOMUSHO.IDO_JIYU IN (15,16) AND NJOKEN111 = 1) OR
              (CR_HOMUSHO.IDO_JIYU BETWEEN 110 AND 140 OR
               CR_HOMUSHO.IDO_JIYU BETWEEN 170 AND 340 OR
               CR_HOMUSHO.IDO_JIYU = 420)) OR
              (CR_HOMUSHO.IDO_JIYU IN (150,160) AND NJOKEN111 = 1) OR
--2024/01/25 DIS.liuqimeng Update end
               WK_JUSHO_CHG = 1 THEN

               JIBSOHOMUSAKU(0,
                                     CR_HOMUSHO.KOJIN_NO,
                                     CR_HOMUSHO.IDO_JIYU,
                                     CR_HOMUSHO.SYS_SHOKUINKOJIN_NO,
                                     CR_HOMUSHO.SYS_TANMATSU_NO);

           END IF;

         EXIT WHEN
               C_HOMUSHO%NOTFOUND;

         END LOOP;
     END;
  END IF;
  -- OutPutの世帯番号を文字列に変更
  o_VSEATI_NO := o_VSEATI_NO || ',' || I_HAITA_SETAI1 || ',' || I_HAITA_SETAI2;
  o_ISHORIBI_KEY     := I_SYSDATE;
  o_ISHORI_JIKAN_KEY := I_SYSTIME;
  o_N_SQL_CODE       := SQLCODE;
  o_V_SQL_MSG        := SUBSTR(SQLERRM,1,100);

  RETURN;
---------------------------------------------------------------
-- 例外処理
---------------------------------------------------------------
EXCEPTION
  ---------------------------------------------------------------
  -- OTHERS
  ---------------------------------------------------------------
  WHEN OTHERS THEN
    -- SQL情報取得 --
    o_N_SQL_CODE := SQLCODE;
    o_V_SQL_MSG := SUBSTR(SQLERRM,1,100) || '(' || T_KOJIN_NO || ')';
    DBMS_OUTPUT.PUT_LINE('SQLCODE = ' || SQLCODE);
    DBMS_OUTPUT.PUT_LINE('SQLERRM = ' || SUBSTR(SQLERRM,1,100) || '(' || T_KOJIN_NO || ')');
    ROLLBACK;
END JIBSOIEUPDB;
/
