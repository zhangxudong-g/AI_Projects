CREATE OR REPLACE PACKAGE GKBPK00010 IS
--1.0.450.000-02.02-02.02
-----------------------------------------------------------------------------------------------------------
--  業務名      GKB（教育）
--  PG名        GKBPK00010
--  名称        総合行政システム　教育共通サブルーチンパッケージ
--  作成者      ZCZL.GUOXU
--  作成日      2024/01/22
--  VERSION     0.2.000.000
-----------------------------------------------------------------------------------------------------------    
--  変更履歴
--  2024/06/03 ZCZL.muzhilin Update 0.3.000.000:新WizLIFE２次開発
--  2025/09/18 CTC.XIAOMINGBO UPDATE 1.0.106.000:GKB_QA20943対応
--  2024/11/11 BOK.GoHou Update 1.0.400.000:標準入出力機能開発(出力分)
--  2025/06/05 BOK.GoHou Update 1.0.400.000:標準入出力機能開発(出力分)
-----------------------------------------------------------------------------------------------------------
--  2025/09/18 CTC.XIAOMINGBO UPDATE START 1.0.106.000:GKB_QA20943対応
    --------------------------------------------------------------------------------
    --  機能概要      : 制御住所
    --  モジュール区分: 内部関数
    --  戻り値        : 住所マスク文字列  NVARCHAR2(100)
    --  バージョン    : Ver 1.0.106.000
    --  作成者／作成日: CTC.XIAOMINGBO 2025/09/18
    --------------------------------------------------------------------------------
FUNCTION FGETJUSHOMSG RETURN NVARCHAR2;
--  2025/09/18 CTC.XIAOMINGBO UPDATE END
FUNCTION FGCODCHK( i_GAKO_CD IN NVARCHAR2 ) RETURN NUMBER;

----------------------------------------------------------------------------------------------------
--帳票連番使用有無チェック
----------------------------------------------------------------------------------------------------
FUNCTION FRBCHK( i_IRENBAN IN NVARCHAR2 ) RETURN NUMBER;
----------------------------------------------------------------------------------------------------
--学年チェック
----------------------------------------------------------------------------------------------------
FUNCTION FGKNCHK( i_IGAKUNEN IN NVARCHAR2 ) RETURN NUMBER;
----------------------------------------------------------------------------------------------------
--基準日取得１
----------------------------------------------------------------------------------------------------
FUNCTION FKJBGET(i_NHAKOUBI IN NUMBER,i_NRENBAN_FLG IN NUMBER,	
	o_NKIJUNBI OUT NUMBER) RETURN NUMBER;
----------------------------------------------------------------------------------------------------
--基準日取得２
----------------------------------------------------------------------------------------------------
FUNCTION FKJBGET2(i_NHAKOUBI IN NUMBER,i_NRENBAN_FLG IN NUMBER,	
	i_NTAISYOUNENDO IN NUMBER,o_NKIJUNBI OUT NUMBER) RETURN NUMBER;
----------------------------------------------------------------------------------------------------
--学校コード変換
----------------------------------------------------------------------------------------------------
FUNCTION FGKOCDTR( i_GAKO_CD IN NVARCHAR2 ,o_TEMP_GAKO_CD OUT NVARCHAR2) RETURN NUMBER ;
----------------------------------------------------------------------------------------------------
--  名称         外国人生年月日フォーマット変換
--  処理概要     入力の生年月日よりフォーマット変換を行う。
--  引き数       i_SEINENGAPI   生年月日（YYYYMMDD）
--                              0:「YYYY.MM.DD」形式の生年月日
--                              1:「GYY.MM.DD」形式の生年月日
--                              0:「YYYY年MM月DD日」形式の生年月日
--                              1:「平成YY年MM月DD日」形式の生年月日
--  戻り値　　　 0:正常 1:異常
--  作成者      ZCZL.GUOXU
--  作成日      2024/01/22
--  VERSION     0.2.000.000
----------------------------------------------------------------------------------------------------
FUNCTION FYMDEDT1( i_SEINENGAPI IN PLS_INTEGER, o_YMD1 OUT NVARCHAR2,
                         o_YMD2 OUT NVARCHAR2) RETURN NUMBER ;
----------------------------------------------------------------------------------------------------
--  名称         生年月日フォーマット変換(EQT_CSVJKNで使用)
--  処理概要     日本人と外国人は生年月日を異なる形式で編集
--  引き数       i_SEINENGAPI   人格区分(1桁) || 生年月日（YYYYMMDD）
--               o_YMD1         日本人の場合、「平成YY年MM月DD日」の形式
--                              外国人の場合、
--                                   0:「YYYY年MM月DD日」形式
--                                   1:「GYY.MM.DD」形式
--               o_RTN          0:正常　1:異常
--  作成者      ZCZL.GUOXU
--  作成日      2024/01/22
--  VERSION     0.2.000.000
----------------------------------------------------------------------------------------------------
PROCEDURE FYMDEDT2( i_SEINENGAPI IN NVARCHAR2, o_YMD OUT NVARCHAR2,o_RTN OUT PLS_INTEGER) ;
----------------------------------------------------------------------------------------------------
-- 2024/06/11 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
----------------------------------------------------------------------------------------------------
--任意ビット名称取得
----------------------------------------------------------------------------------------------------
-- FUNCTION FGETNMS( i_NCTLCONS_SEQ IN NUMBER ,o_TITLE OUT NVARCHAR2,
--                               o_NINIMEISHO OUT A_CONS_PRM) RETURN NUMBER;
----------------------------------------------------------------------------------------------------
-- 2024/06/11 ZCZL.muzl Delete end
----------------------------------------------------------------------
--児童が外国人の世帯の保護者取得
----------------------------------------------------------------------
FUNCTION FGKJHGS(i_IKIJYUNBI IN NUMBER,i_NJIDO_NO IN NUMBER,
                                o_NHOGOSHA_NO OUT NUMBER, o_VHOGOSHA_NM OUT NVARCHAR2  ) RETURN PLS_INTEGER;
----------------------------------------------------------------------------
--  名称       テーブルデータ件数カウント
--             GKBFKTBLCNT／KHKPK0010.FTABLECOUNTより流用新規
--  処理概要   対象TBLから対象の条件で件数を取得する
--  引き数
--  INPUT      i_FROM    件数を取得するテーブル
--  INPUT      i_WHERE   抽出条件
--  戻り値     NCOUNT    データ件数
--  作成者      ZCZL.GUOXU
--  作成日      2024/01/22
--  VERSION     0.2.000.000
----------------------------------------------------------------------------
FUNCTION FTCOUNT(i_FROM IN  NVARCHAR2,
                    i_WHERE IN NVARCHAR2
                    )RETURN NUMBER;
------------------------------------------------------------------
--  保護者情報取得
--    児童個人番号、基準日を基に保護者を検索する
------------------------------------------------------------------
FUNCTION  FHOGOSHA(    i_IKIJYUNBI     IN  PLS_INTEGER,
                        i_NJIDO_NO      IN  NUMBER,
                        o_NHOGOSHA_NO   OUT NUMBER) RETURN  PLS_INTEGER;
------------------------------------------------------------------
--  保護者情報取得（OUT　保護者名付き）
--    児童個人番号、基準日を基に保護者を検索する
------------------------------------------------------------------
FUNCTION  FHOGOSHA2(    i_IKIJYUNBI    IN  PLS_INTEGER,
                        i_NJIDO_NO      IN  NUMBER,
                        o_NHOGOSHA_NO   OUT NUMBER,
                        o_VHOGOSHA_NM   OUT NVARCHAR2 ) RETURN  PLS_INTEGER;

-- 2024/11/11 BOK.GoHou Add start 1.0.400.000:標準入出力機能開発(出力分)
--------------------------------------------------------
--  名称          : 仮学校コード・名称取得
--  機能概要      : 引数による分岐に基づきOUTパラメータ(仮学校コード・名称)へ値を設定する。
--  パラメータ    : i_NTYUGAKO_NYUGAKU_BI             中学校_入学年月日
--                : i_NTYUGAKO_TENNYUGAKU_BI          中学校_転入学年月日
--                : i_NKARIGAKO_S_FLG                 仮学校フラグ(小学校)
--                : i_NKARIGAKO_T_FLG                 仮学校フラグ(中学校)
--                : i_VMONBUKAGAKUSHO_GAKOCODE_S      文部科学省学校コード(小学校)
--                : i_VMONBUKAGAKUSHO_GAKOCODE_T      文部科学省学校コード(中学校)
--                : i_VSGAKONAME                      小学校名
--                : i_VTGAKONAME                      中学校名
--                : o_VKARIGAKOCODE                   仮学校コード
--                : o_VKARIGAKONAME                   仮学校名
--  モジュール区分: PUBLIC(外部関数)
--  戻り値        : 引数をNUMBER型にした数字データ
--  バージョン    : Ver 1.0.400.000
--  作成者／作成日: BOK GoHou   2024/11/11
--------------------------------------------------------
  FUNCTION FGETKARIGAKKO(i_NTYUGAKO_NYUGAKU_BI        IN  NUMBER,
                         i_NTYUGAKO_TENNYUGAKU_BI     IN  NUMBER,
                         i_NKARIGAKO_S_FLG            IN  NUMBER,
                         i_NKARIGAKO_T_FLG            IN  NUMBER,
                         i_VMONBUKAGAKUSHO_GAKOCODE_S IN  NVARCHAR2,
                         i_VMONBUKAGAKUSHO_GAKOCODE_T IN  NVARCHAR2,
                         i_VSGAKONAME                 IN  NVARCHAR2,
                         i_VTGAKONAME                 IN  NVARCHAR2,
                         o_VKARIGAKOCODE              OUT NVARCHAR2,
                         o_VKARIGAKONAME              OUT NVARCHAR2) RETURN NUMBER;
-- 2024/11/11 BOK.GoHou Add end
-- 2025/06/05 BOK.GoHou Add start 1.0.400.000:標準入出力機能開発(出力分)
------------------------------------------------------------------
--  名称          : 学校区分コード・学校等コード取得
--  機能概要      : 引数として渡された文部科学省学校コードから学校区分コードと学校等コードを取得する。
--  パラメータ    : i_VMGAKKO_CD             文部科学省学校コード
--                : o_NGAKOUKUBUN           学校区分コード
--                : o_NGAKOUNADO_CD         学校等コード
--  モジュール区分: PUBLIC(外部関数)
--  戻り値        : 引数をNUMBER型にした数字データ（正常:0、異常:1）
--  バージョン    : Ver 1.0.400.000
--  作成者／作成日: BOK GoHou   2025/06/05
------------------------------------------------------------------
FUNCTION  FGETGAKKO_KBN_CD(i_VMGAKKO_CD     IN  NVARCHAR2,
                           o_NGAKOUKUBUN      OUT  NUMBER,
                           o_NGAKOUNADO_CD   OUT NUMBER) RETURN  NUMBER;
-- 2025/06/05 BOK.GoHou Add end

END GKBPK00010;
/
