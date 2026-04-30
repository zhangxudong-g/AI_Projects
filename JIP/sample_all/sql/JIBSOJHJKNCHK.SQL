CREATE OR REPLACE PROCEDURE JIBSOJHJKNCHK(
--1.0.000.000-05.00-03.00
                                                        i_NSHORIBI              IN  NUMBER,
                                                        i_VMACHINE_NAME         IN  NVARCHAR2,
                                                        i_NSHOKUIN_NO           IN  NVARCHAR2,
                                                        o_NSQL_CODE             OUT NUMBER,
                                                        o_VSQL_MSG              OUT NVARCHAR2)
IS
--------------------------------------------------------
--  業務名        JIB(住民記録)
--  PG 名         JIBSOJHJKNCHK
--  名称          住居表示変更条件FDデータチェック
--  処理概要      媒体データ内容臨時保存用テーブル(JIBWJUSHOHENKO_TMP)より住居
--                表示変更条件FDデータを読み込み、データの内容をチェックする。データ
--                内容が不正の場合はエラーデータテーブル(JIBTJUSHOHENKO_JKN_ERR)に
--                出力する
--  作成者        ZCZL.DUANDONGLIN
--  作成日        2022/07/28
--  Version       0.2.000.000
--------------------------------------------------------
--  修正概要      : 支所CDをCHAR(3)に変更
--  バージョン    : 0.0.000.000
--  修正者／修正日: JIP H.Furui   2022/08/19
--------------------------------------------------------
--------------------------------------------------------------------------------
--  カーソル定義
--------------------------------------------------------------------------------
    CURSOR CFD_FILE IS
      SELECT A.DATA
        FROM JIBWJUSHOHENKO_TMP A;

------------------------------------------------------------------------------
--  定数宣言
------------------------------------------------------------------------------
  -- 処理結果
  c_ISUCCESS       CONSTANT  PLS_INTEGER := 0;         -- 正常
  c_INOT_SUCCESS   CONSTANT  PLS_INTEGER := -1;        -- 異常
  c_IRETNG         CONSTANT  PLS_INTEGER := 1;
  -- JIBTJUSHOHENKO_JKNの削除を行う
  c_VTABLE         CONSTANT  NVARCHAR2(128) :=   'JIBTJUSHOHENKO_JKN_ERR';
  c_VTABLE1        CONSTANT  NVARCHAR2(128) :=   'JIBWJUSHOHENKO_KEY';
  --旧自治体区分
  I_JICHI_KBN      CONSTANT  NUMBER := 1;
------------------------------------------------------------------------------
--  変数宣言
------------------------------------------------------------------------------
  RTN                       PLS_INTEGER;
  VSQLERRM                  NVARCHAR2(256);
  TACONSPRM                 A_CONS_PRM;  --配列
  NPRM_LENGTH               NUMBER;      --配列の長
  CTLPRM1                   NUMBER;
  CTLPRM2                   NUMBER;
  CTLPRM3                   NUMBER;
  CTLPRM4                   NUMBER;
  CTLPRM5                   NUMBER;
  CTLPRM6                   NUMBER;
  CTLPRM7                   NUMBER;
  CTLPRM8                   NUMBER;
  CTLPRM9                   NUMBER;
  VDATA                     NVARCHAR2(3000);
  NCOUNT                    NUMBER := 1;
  NPOINT                    NUMBER := 0;
  NENTER_POINT              NUMBER;
  NUM                       NUMBER := 0;
  NDATACOUNT                NUMBER := 0; --入力データ件数
  NERRDATACOUNT             NUMBER := 0; --エラーデータ件数
  NERRORFLG                 NUMBER := 0; --エラーデータ有無(0:無, 1:有)

  VBF_CITY_CD               NVARCHAR2(100);
  VBF_JICHI_CD              NVARCHAR2(100);
  VBF_OAZA_CD               NVARCHAR2(100);
  VBF_HONBAN                NVARCHAR2(100);
  VBF_EDABAN1               NVARCHAR2(100);
  VBF_EDABAN2               NVARCHAR2(100);
  VBF_EDABAN3               NVARCHAR2(100);
  VBF_BANCHI_HENSHU_TYPE    NVARCHAR2(100);
  VAF_CITY_CD               NVARCHAR2(100);
  VAF_JICHI_CD              NVARCHAR2(100);
  VAF_OAZA_CD               NVARCHAR2(100);
  VAF_HONBAN                NVARCHAR2(100);
  VAF_EDABAN1               NVARCHAR2(100);
  VAF_EDABAN2               NVARCHAR2(100);
  VAF_EDABAN3               NVARCHAR2(100);
  VAF_BANCHI_HENSHU_TYPE    NVARCHAR2(100);
  VAF_YUBIN_NO              NVARCHAR2(100);
  VSHISHO_CD                NVARCHAR2(100);
  VCHIKU_CD                 NVARCHAR2(100);
  VGYOSEIKU_CD              NVARCHAR2(100);
  VHAN_CD                   NVARCHAR2(100);
  VSHOGAKU_CD               NVARCHAR2(100);
  VCHUGAKU_CD               NVARCHAR2(100);
  VTOHYOKU_CD               NVARCHAR2(100);
  VGOMI_CD                  NVARCHAR2(100);
  VSINYO_CD                 NVARCHAR2(100);

  RJUSHOHENKO_JKN_ERR       JIBTJUSHOHENKO_JKN_ERR%ROWTYPE;
  RJUSHOHENKO_KEY           JIBWJUSHOHENKO_KEY%ROWTYPE;
  VCDERR                    NVARCHAR2(20);
  IRET                      NUMBER;
  NINDEX                    NUMBER;
  NAMOUNT                   INTEGER;
  NBAK_INDEX                NUMBER  := 1;
  NBLOB_BUFFER              RAW(30000);
  NOFFSET                   INTEGER := 1;
  BRET                      BOOLEAN;
  BOUT_ISNULL               BOOLEAN;
  NSQLCOUNT                 NUMBER;
  NJOKEN                    NUMBER;
  W_ERRFLG                  PLS_INTEGER;
  W_ERRFLG1                 NVARCHAR2(300);
  W_ERRFLG2                 NVARCHAR2(20);
  V_ERRFLG                  NVARCHAR2(10);
  --住所からの行政情報自動設定の項目宣言
  O_GYOSEIKU_CD             NUMBER;
  O_HANCD                   NUMBER;
  O_SHOGAKU_CD              NUMBER;
  O_CHUGAKU_CD              NUMBER;
  O_TOHYOKU_CD              NUMBER;
--2022/08/19 H.Furui Mod Start
--  O_SHISHO_CD               NUMBER;
  O_SHISHO_CD               CHAR(3);
--2022/08/19 H.Furui Mod End
  O_CHIKU_CD                NUMBER;
  O_SANTEIDANTAI_CD         NUMBER;
  O_SQLCODE                 NUMBER;
  --文字列中に記号のチェック
  BKIGOUFLG1                BOOLEAN;
  BKIGOUFLG2                BOOLEAN;
  BKIGOUFLG3                BOOLEAN;
  BKIGOUFLG4                BOOLEAN;
  BKIGOUFLG5                BOOLEAN;
  BKIGOUFLG6                BOOLEAN;
  o_tITEM                   A_CONS_PRM;
  nRTN                      PLS_INTEGER;
--------------------------------------------------------------------------------
--数値チェック
--------------------------------------------------------------------------------
FUNCTION EBPFCHKNUMERIC(i_VCHAR IN NVARCHAR2, o_ISNULL OUT BOOLEAN)RETURN BOOLEAN IS
BRTN        BOOLEAN;

BEGIN
  o_ISNULL := FALSE;
  IF i_VCHAR IS NULL THEN
    BRTN := FALSE;
    o_ISNULL := TRUE;
  ELSIF TRIM(TRANSLATE(i_VCHAR,'0123456789','          ')) IS NULL THEN
    BRTN := TRUE;
  ELSE
    BRTN := FALSE;
  END IF;
  
  RETURN BRTN;

END EBPFCHKNUMERIC;
--------------------------------------------------------------------------------
--桁数チェック
--------------------------------------------------------------------------------
FUNCTION EBPFCHKIKETASU(i_VCHAR IN NVARCHAR2,i_IKETASU  IN PLS_INTEGER) RETURN BOOLEAN IS
BRTN        BOOLEAN;

BEGIN

  -- 桁数チェック
  IF i_IKETASU <> 0 THEN
    IF ( LENGTH(i_VCHAR) > i_IKETASU ) THEN
      BRTN := FALSE;
    ELSE
      BRTN := TRUE;
    END IF;
  END IF;
  
  RETURN BRTN;

END EBPFCHKIKETASU;
--------------------------------------------------------------------------------
--コード変換チェック
--------------------------------------------------------------------------------
FUNCTION EBPFCHKCDHENKOU(i_VCHAR  IN NVARCHAR2,i_NKEN  IN NUMBER)RETURN NUMBER IS
NSQL_COUNT   NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO NSQL_COUNT
      FROM GABTGYOSEIJOHO
     WHERE GYOSEI_JOHO_CD = i_VCHAR
       AND GYOSEI_JOHO_KBN=i_NKEN
       AND KYU_JICHITAI_KBN=1;
      RETURN NSQL_COUNT;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NSQL_COUNT := 0;
     WHEN OTHERS THEN
       NSQL_COUNT := 0;
    RETURN NSQL_COUNT;

END EBPFCHKCDHENKOU;
--------------------------------------------------------------------------------
FUNCTION EBPFCHKCDHENKOU1(i_VCHAR  IN NVARCHAR2,i_NKEN  IN NUMBER)RETURN NUMBER IS
NSQL_COUNT   NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO NSQL_COUNT
      FROM KKATCD
     WHERE 
        GYOUMUCODE = 'JIB' 
        AND TRIM(ANYCODE) = TRIM(i_VCHAR)
        AND TRIM(CODECODE) = TO_CHAR(TRIM(i_NKEN),'FM000')
        AND GROUPCODE = '0000';
      RETURN NSQL_COUNT;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NSQL_COUNT := 0;
     WHEN OTHERS THEN
       NSQL_COUNT := 0;
    RETURN NSQL_COUNT;

END EBPFCHKCDHENKOU1;
--------------------------------------------------------------------------------
--その他のチェック（項目相関チェックやキイ項目の同番チェック）
--------------------------------------------------------------------------------
FUNCTION EBPFCHKSONOTA(i_VCITYCD IN NVARCHAR2,i_VOAZACD IN NVARCHAR2,i_VHONBAN IN NVARCHAR2,
                       i_VEDABAN1 IN NVARCHAR2,i_VEDABAN2 IN NVARCHAR2,i_VEDABAN3 IN NVARCHAR2)
                       RETURN NUMBER IS

NSQL_COUNT   NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO NSQL_COUNT
      FROM JIBWJUSHOHENKO_KEY
     WHERE BF_CITY_CD = i_VCITYCD
       AND BF_OAZA_CD = i_VOAZACD
       AND BF_HONBAN  = i_VHONBAN
       AND BF_EDABAN1 = i_VEDABAN1
       AND BF_EDABAN2 = i_VEDABAN2
       AND BF_EDABAN3 = i_VEDABAN3;
      RETURN NSQL_COUNT;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NSQL_COUNT := 0;
     WHEN OTHERS THEN
       NSQL_COUNT := 0;
    RETURN NSQL_COUNT;

END EBPFCHKSONOTA;
--------------------------------------------------------------------------------
--変更前の住所コード（BF_CITY_CD, BF_OAZA_CD, BF_HONBAN, BF_EDABAN1, BF_EDABAN2, BF_EDABAN3）が
--ここまでのチェックでエラーが無い場合
--?I同番
PROCEDURE EBPFTOONAJIBANCHK(i_BFCITYCD IN NVARCHAR2,i_BFOAZACD IN NVARCHAR2,i_BFHONBAN IN NVARCHAR2,
                           i_BFEDABAN1 IN NVARCHAR2,i_BFEDABAN2 IN NVARCHAR2,i_BFEDABAN3 IN NVARCHAR2) IS
V_BFEDABAN1   NVARCHAR2(20);
V_BFEDABAN2   NVARCHAR2(20);
V_BFEDABAN3   NVARCHAR2(20);
BEGIN

  IF i_BFEDABAN1 IS NULL THEN
     V_BFEDABAN1 := 0;
  ELSE
     V_BFEDABAN1 := i_BFEDABAN1;
  END IF;

  IF i_BFEDABAN2 IS NULL THEN
     V_BFEDABAN2 := 0;
  ELSE
     V_BFEDABAN2 := i_BFEDABAN2;
  END IF;

  IF i_BFEDABAN3 IS NULL THEN
     V_BFEDABAN3 := 0;
  ELSE
     V_BFEDABAN3 := i_BFEDABAN3;
  END IF;

  --同番チェック用ワークテーブル(JIBWJUSHOHENKO_KEY)を読込む。
  NSQLCOUNT := EBPFCHKSONOTA(i_BFCITYCD , i_BFOAZACD , i_BFHONBAN , V_BFEDABAN1 , V_BFEDABAN2 , V_BFEDABAN3);

  IF NSQLCOUNT > 0 THEN
    RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR || '$';
    RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR || '$';
    RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR  := RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR  || '$';
    RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR || '$';
    RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR || '$';
    RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR || '$';
  END IF;

END EBPFTOONAJIBANCHK;
--------------------------------------------------------------------------------
--エラーデータ初期化処理
--------------------------------------------------------------------------------
PROCEDURE PROCCLEAR IS
BEGIN
  RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR            := '';
  RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR           := '';
  RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR            := '';
  RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR             := '';
  RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR            := '';
  RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR            := '';
  RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR            := '';
  RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR := '';
  RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR            := '';
  RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR           := '';
  RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR            := '';
  RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR             := '';
  RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR            := '';
  RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR            := '';
  RJUSHOHENKO_JKN_ERR.AF_EDABAN3_ERR            := '';
  RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR := '';
  RJUSHOHENKO_JKN_ERR.AF_YUBIN_NO_ERR           := '';
  RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR             := '';
  RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR              := '';
  RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR           := '';
  RJUSHOHENKO_JKN_ERR.HAN_CD_ERR                := '';
  RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR            := '';
  RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR            := '';
  RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR            := '';
  RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR               := '';
  RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR              := '';
END PROCCLEAR;
--------------------------------------------------------------------------------
-- メイン処理                                                                 --
--------------------------------------------------------------------------------
BEGIN
  -- １．初期処理
  -- ?@テーブル「JIBTJUSHOHENKO_JKN_ERR」のデータを削除する。
  RTN := KKAPK3000.FTRUNCATE(c_VTABLE, VSQLERRM);
  IF RTN <> 0 THEN
    o_NSQL_CODE := c_INOT_SUCCESS;
    o_VSQL_MSG  := SUBSTR(TO_CHAR(SQLERRM),1,255);
    RETURN;
  END IF;

  --?@テーブル「JIBWJUSHOHENKO_KEY」のデータを削除する。
  RTN := KKAPK3000.FTRUNCATE(c_VTABLE1, VSQLERRM);
  IF RTN <> 0 THEN
    o_NSQL_CODE := c_INOT_SUCCESS;
    o_VSQL_MSG  := SUBSTR(TO_CHAR(SQLERRM),1,255);
    RETURN;
  END IF;

  -- ?A行政情報設定用の制御パラメータを取得する。
  RTN := KKAPK0030.FPRMSHUTOKU('JIB',
                                '00JHGYOSEIJOHO',
                                '0',
                                TACONSPRM,
                                NPRM_LENGTH);
  --パラメータを取得できない場合、ディフォト値ゼロを設定する。
  IF ((RTN = c_ISUCCESS) AND (TACONSPRM.LAST IS NULL)) OR
      (RTN = c_IRETNG) THEN
    CTLPRM1 := 0;
    CTLPRM2 := 0;
    CTLPRM3 := 0;
    CTLPRM4 := 0;
    CTLPRM5 := 0;
    CTLPRM6 := 0;
    CTLPRM7 := 0;
    CTLPRM8 := 0;
    CTLPRM9 := 0;
  ELSE
    FOR ICNT IN TACONSPRM.FIRST..TACONSPRM.LAST LOOP
      CASE ICNT
        WHEN 1 THEN
          CTLPRM1 := NVL(TACONSPRM(1),0);
        WHEN 2 THEN
          CTLPRM2 := NVL(TACONSPRM(2),0);
        WHEN 3 THEN
          CTLPRM3 := NVL(TACONSPRM(3),0);
        WHEN 4 THEN
          CTLPRM4 := NVL(TACONSPRM(4),0);
        WHEN 5 THEN
          CTLPRM5 := NVL(TACONSPRM(5),0);
        WHEN 6 THEN
          CTLPRM6 := NVL(TACONSPRM(6),0);
        WHEN 7 THEN
          CTLPRM7 := NVL(TACONSPRM(7),0);
        WHEN 8 THEN
          CTLPRM8 := NVL(TACONSPRM(8),0);
        WHEN 9 THEN
          CTLPRM9 := NVL(TACONSPRM(9),0);
        ELSE
          NULL;
      END CASE;
    END LOOP;
  END IF;

  -- ２．データ抽出
  FOR RCFD_FILE IN CFD_FILE LOOP

    -- 第一個ENTERキーの位置を取得する
    NINDEX                         := DBMS_LOB.INSTR(RCFD_FILE.DATA,UTL_RAW.CAST_TO_RAW(CHR(13)),1,NCOUNT);
    NAMOUNT                        := NINDEX - 1;
    WHILE NINDEX <> NBAK_INDEX LOOP

    --エラーデータ初期化処理
    PROCCLEAR;

    IF NINDEX = 0 THEN
      --一行データのみ
      IF NBAK_INDEX = 1 THEN
        VDATA                      := CONVERT(UTL_RAW.CAST_TO_VARCHAR2(RCFD_FILE.DATA), 'UTF8', 'JA16SJIS');
      ELSE
        NAMOUNT                    := DBMS_LOB.GETLENGTH(RCFD_FILE.DATA) - NBAK_INDEX - 1;
        NBLOB_BUFFER               := DBMS_LOB.SUBSTR(RCFD_FILE.DATA,NAMOUNT,NBAK_INDEX + 2);
        VDATA                      := CONVERT(UTL_RAW.CAST_TO_VARCHAR2(NBLOB_BUFFER), 'UTF8', 'JA16SJIS');
      END IF;
      NBAK_INDEX                   := 0;
    --複数行データの場合
    ELSE
      NBLOB_BUFFER                 := DBMS_LOB.SUBSTR(RCFD_FILE.DATA,NAMOUNT,NOFFSET);
      NOFFSET := NOFFSET + NAMOUNT + 2;
      VDATA                        := CONVERT(UTL_RAW.CAST_TO_VARCHAR2(NBLOB_BUFFER), 'UTF8', 'JA16SJIS');
    END IF;
    VDATA                          := REPLACE(VDATA,'"','');
    NDATACOUNT                     := NDATACOUNT + 1;

    --毎行データ中に、データがある場合
    IF LENGTH(TRIM(VDATA)) > 0 THEN
      VDATA                        := VDATA || ',,,,,,,,,,,,,,,,,,,,,,,,,,';

-- １、変更前市区町村コード
      NPOINT                       := INSTR(VDATA, ',');
      VBF_CITY_CD                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VBF_CITY_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VBF_CITY_CD,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR || '#';
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR IS NULL THEN
        BEGIN
          SELECT COUNT(*)
            INTO NSQLCOUNT
            FROM GABTSHIKUCHOSON
           WHERE JICHI_CD = VBF_CITY_CD;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NSQLCOUNT := 0;
          WHEN OTHERS THEN
            NSQLCOUNT := 0;
        END;
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR || '@';
        END IF;
      END IF;

-- ２、変更前自治コード
      NPOINT                       := INSTR(VDATA, ',');
      VBF_JICHI_CD                 := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VBF_JICHI_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VBF_JICHI_CD,6);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR || '#';
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR IS NULL THEN
        BEGIN
          SELECT COUNT(*)
            INTO NSQLCOUNT
            FROM GABTSHIKUCHOSON
           WHERE JICHITAI_CD = VBF_JICHI_CD;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NSQLCOUNT := 0;
          WHEN OTHERS THEN
            NSQLCOUNT := 0;
        END;
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR || '@';
        END IF;
      END IF;

-- ３、変更前大字コード
      NPOINT                       := INSTR(VDATA, ',');
      VBF_OAZA_CD                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VBF_OAZA_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VBF_OAZA_CD,6);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR || '#';
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR IS NULL THEN
        BEGIN
          SELECT COUNT(*)
            INTO NSQLCOUNT
            FROM GABTOAZA
           WHERE OAZA_CD = VBF_OAZA_CD;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NSQLCOUNT := 0;
          WHEN OTHERS THEN
            NSQLCOUNT := 0;
        END;
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR := RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR || '@';
        END IF;
      END IF;

-- ４、変更前本番
      NPOINT                       := INSTR(VDATA, ',');
      VBF_HONBAN                   := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VBF_HONBAN,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VBF_HONBAN,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR || '#';
      END IF;

-- ５、変更前枝番１
      NPOINT                       := INSTR(VDATA, ',');
      VBF_EDABAN1                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      IF VBF_EDABAN1 IS NOT NULL THEN
        --?@データタイプのチェック
        BRET := EBPFCHKNUMERIC(VBF_EDABAN1,BOUT_ISNULL);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR := '*';
        END IF;

        --?Aデータ長のチェック
        BRET := EBPFCHKIKETASU(VBF_EDABAN1,5);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR || '&';
        END IF;
      END IF;

-- ６、変更前枝番２
      NPOINT                       := INSTR(VDATA, ',');
      VBF_EDABAN2                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      IF VBF_EDABAN2 IS NOT NULL THEN
        --?@データタイプのチェック
        BRET := EBPFCHKNUMERIC(VBF_EDABAN2,BOUT_ISNULL);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR := '*';
        END IF;

        --?Aデータ長のチェック
        BRET := EBPFCHKIKETASU(VBF_EDABAN2,5);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR || '&';
        END IF;
      END IF;

-- ７、変更前枝番３
      NPOINT                       := INSTR(VDATA, ',');
      VBF_EDABAN3                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      IF VBF_EDABAN3 IS NOT NULL THEN
        --?@データタイプのチェック
        BRET := EBPFCHKNUMERIC(VBF_EDABAN3,BOUT_ISNULL);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR := '*';
        END IF;

        --?Aデータ長のチェック
        BRET := EBPFCHKIKETASU(VBF_EDABAN3,5);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR || '&';
        END IF;
      END IF;

-- ８、変更前番地編集タイプ
      NPOINT                       := INSTR(VDATA, ',');
      VBF_BANCHI_HENSHU_TYPE       := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VBF_BANCHI_HENSHU_TYPE,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VBF_BANCHI_HENSHU_TYPE,2);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR := RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR := RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR || '#';
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR IS NULL THEN
        BEGIN
          SELECT COUNT(*)
            INTO NSQLCOUNT
            FROM GABTBANCHIHENSHU
           WHERE BANCHI_HENSHU_CD = VBF_BANCHI_HENSHU_TYPE;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NSQLCOUNT := 0;
          WHEN OTHERS THEN
            NSQLCOUNT := 0;
        END;
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR := RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR || '@';
        END IF;
      END IF;

-- ９、変更後市区町村コード
      NPOINT                       := INSTR(VDATA, ',');
      VAF_CITY_CD                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VAF_CITY_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VAF_CITY_CD,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR := RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR := RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR || '#';
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR IS NULL THEN
        BEGIN
          SELECT COUNT(*)
            INTO NSQLCOUNT
            FROM GABTSHIKUCHOSON
           WHERE JICHI_CD = VAF_CITY_CD;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NSQLCOUNT := 0;
          WHEN OTHERS THEN
            NSQLCOUNT := 0;
        END;
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR := RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR || '@';
        END IF;
      END IF;

-- １０、変更後自治コード
      NPOINT                       := INSTR(VDATA, ',');
      VAF_JICHI_CD                 := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VAF_JICHI_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VAF_JICHI_CD,6);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR := RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR := RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR || '#';
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR IS NULL THEN
        BEGIN
          SELECT COUNT(*)
            INTO NSQLCOUNT
            FROM GABTSHIKUCHOSON
           WHERE JICHITAI_CD = VAF_JICHI_CD;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NSQLCOUNT := 0;
          WHEN OTHERS THEN
            NSQLCOUNT := 0;
        END;
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR := RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR || '@';
        END IF;
      END IF;

-- １１、変更後大字コード
      NPOINT                       := INSTR(VDATA, ',');
      VAF_OAZA_CD                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VAF_OAZA_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VAF_OAZA_CD,6);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR := RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR := RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR || '#';
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR IS NULL THEN
        BEGIN
          SELECT COUNT(*)
            INTO NSQLCOUNT
            FROM GABTOAZA
           WHERE OAZA_CD = VAF_OAZA_CD;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NSQLCOUNT := 0;
          WHEN OTHERS THEN
            NSQLCOUNT := 0;
        END;
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR := RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR || '@';
        END IF;
      END IF;

-- １２、変更後本番
      NPOINT                       := INSTR(VDATA, ',');
      VAF_HONBAN                   := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VAF_HONBAN,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VAF_HONBAN,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR || '#';
      END IF;

--１３、変更後枝番１
      NPOINT                       := INSTR(VDATA, ',');
      VAF_EDABAN1                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      IF VAF_EDABAN1 IS NOT NULL THEN
        --?@データタイプのチェック
        BRET := EBPFCHKNUMERIC(VAF_EDABAN1,BOUT_ISNULL);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR := '*';
        END IF;

        --?Aデータ長のチェック
        BRET := EBPFCHKIKETASU(VAF_EDABAN1,5);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR || '&';
        END IF;
      END IF;

-- １４、変更後枝番２
      NPOINT                       := INSTR(VDATA, ',');
      VAF_EDABAN2                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      IF VAF_EDABAN2 IS NOT NULL THEN
        --?@データタイプのチェック
        BRET := EBPFCHKNUMERIC(VAF_EDABAN2,BOUT_ISNULL);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR := '*';
        END IF;

        --?Aデータ長のチェック
        BRET := EBPFCHKIKETASU(VAF_EDABAN2,5);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR || '&';
        END IF;
      END IF;

-- １５、変更後枝番３
      NPOINT                       := INSTR(VDATA, ',');
      VAF_EDABAN3                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);
      IF VAF_EDABAN3 IS NOT NULL THEN
        --?@データタイプのチェック
        BRET := EBPFCHKNUMERIC(VAF_EDABAN3,BOUT_ISNULL);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.AF_EDABAN3_ERR := '*';
        END IF;

        --?Aデータ長のチェック
        BRET := EBPFCHKIKETASU(VAF_EDABAN3,5);
        IF BRET = FALSE THEN
          RJUSHOHENKO_JKN_ERR.AF_EDABAN3_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN3_ERR || '&';
        END IF;
      END IF;

-- １６、変更後番地編集タイプ
      NPOINT                       := INSTR(VDATA, ',');
      VAF_BANCHI_HENSHU_TYPE       := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VAF_BANCHI_HENSHU_TYPE,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VAF_BANCHI_HENSHU_TYPE,2);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR := RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR := RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR || '#';
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR IS NULL THEN
        BEGIN
          SELECT COUNT(*)
            INTO NSQLCOUNT
            FROM GABTBANCHIHENSHU
           WHERE BANCHI_HENSHU_CD = VAF_BANCHI_HENSHU_TYPE;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NSQLCOUNT := 0;
          WHEN OTHERS THEN
            NSQLCOUNT := 0;
        END;
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR := RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR || '@';
        END IF;
      END IF;

-- １７、変更後郵便番号
      NPOINT                       := INSTR(VDATA, ',');
      VAF_YUBIN_NO                 := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VAF_YUBIN_NO,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_YUBIN_NO_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VAF_YUBIN_NO,7);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.AF_YUBIN_NO_ERR := RJUSHOHENKO_JKN_ERR.AF_YUBIN_NO_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.AF_YUBIN_NO_ERR := RJUSHOHENKO_JKN_ERR.AF_YUBIN_NO_ERR || '#';
      END IF;

-- １８、支所コード
      NPOINT                       := INSTR(VDATA, ',');
      VSHISHO_CD                   := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VSHISHO_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VSHISHO_CD,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR := RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF CTLPRM9 = 1 AND BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR := RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR || '#';
      ELSIF CTLPRM9 <> 1 AND BOUT_ISNULL = FALSE THEN
        IF VSHISHO_CD <> '0' AND VSHISHO_CD <> '' AND VSHISHO_CD IS NOT NULL THEN	--2013/08/02 T.ABE ADD
           RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR := RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR || '#';
        END IF;										--2013/08/02 T.ABE ADD
      END IF;

      --?Cコード変換チェック
--      IF RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR IS NULL THEN				--2013/08/02 T.ABE DEL
--2013/08/02 T.ABE ADD Start
      IF RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR IS NULL
         AND VSHISHO_CD <> '0' AND VSHISHO_CD <> '' AND VSHISHO_CD IS NOT NULL THEN
--2013/08/02 T.ABE ADD End
        BEGIN
          SELECT COUNT(*)
            INTO NSQLCOUNT
            FROM KKATCD
           WHERE 
              GYOUMUCODE = 'KKN'
              AND   CODECODE ='001'
              AND   GROUPCODE = '0000' 
              AND   TO_CHAR(TRIM(ANYCODE),'FM000') =TO_CHAR(TRIM(VSHISHO_CD),'FM000');
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NSQLCOUNT := 0;
          WHEN OTHERS THEN
            NSQLCOUNT := 0;
        END;
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR := RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR || '@';
        END IF;
      END IF;

-- １９、地区コード
      NPOINT                       := INSTR(VDATA, ',');
      VCHIKU_CD                    := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VCHIKU_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VCHIKU_CD,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR := RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF CTLPRM2 = 1 AND BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR := RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR || '#';
      ELSIF CTLPRM2 <> 1 AND BOUT_ISNULL = FALSE THEN
        IF VCHIKU_CD <> '0' AND VCHIKU_CD <> '' AND VCHIKU_CD IS NOT NULL THEN	--2013/08/02 T.ABE ADD
           RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR := RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR || '#';
        END IF;									--2013/08/02 T.ABE ADD
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR IS NULL
         AND VCHIKU_CD <> '0' AND VCHIKU_CD <> '' AND VCHIKU_CD IS NOT NULL THEN
        NSQLCOUNT := EBPFCHKCDHENKOU(VCHIKU_CD,1);
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR := RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR || '@';
        END IF;
      END IF;

-- ２０、行政区コード
      NPOINT                       := INSTR(VDATA, ',');
      VGYOSEIKU_CD                 := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VGYOSEIKU_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VGYOSEIKU_CD,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR := RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF CTLPRM1 = 1 AND BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR := RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR || '#';
      ELSIF CTLPRM1 <> 1 AND BOUT_ISNULL = FALSE THEN
        IF VGYOSEIKU_CD <> '0' AND VGYOSEIKU_CD <> '' AND VGYOSEIKU_CD IS NOT NULL THEN		--2013/08/02 T.ABE ADD
           RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR := RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR || '#';
        END IF;											--2013/08/02 T.ABE ADD
      END IF;

      --?Cコード変換チェック
--      IF RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR IS NULL THEN					--2013/08/02 T.ABE DEL
      IF RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR IS NULL						--2013/08/02 T.ABE ADD
         AND VGYOSEIKU_CD <> '0' AND VGYOSEIKU_CD <> '' AND VGYOSEIKU_CD IS NOT NULL THEN	--2013/08/02 T.ABE ADD
        NSQLCOUNT := EBPFCHKCDHENKOU(VGYOSEIKU_CD,2);
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR := RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR || '@';
        END IF;
      END IF;

-- ２１、班コード
      NPOINT                       := INSTR(VDATA, ',');
      VHAN_CD                      := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VHAN_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.HAN_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VHAN_CD,15);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.HAN_CD_ERR := RJUSHOHENKO_JKN_ERR.HAN_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF CTLPRM3 = 1 AND BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.HAN_CD_ERR := RJUSHOHENKO_JKN_ERR.HAN_CD_ERR || '#';
      ELSIF CTLPRM3 <> 1 AND BOUT_ISNULL = FALSE THEN
        IF VHAN_CD <> '0' AND VHAN_CD <> '' AND VHAN_CD IS NOT NULL THEN
           RJUSHOHENKO_JKN_ERR.HAN_CD_ERR := RJUSHOHENKO_JKN_ERR.HAN_CD_ERR || '#';
        END IF;										--2013/08/02 T.ABE ADD
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.HAN_CD_ERR IS NULL	
         AND VHAN_CD <> '0' AND VHAN_CD <> '' AND VHAN_CD IS NOT NULL THEN
        BEGIN
             nRTN := KKAPK0030.FCTGetR('JIB','SYSTEM_JOKEN','0001',1,o_tITEM);
              IF nRTN = 0 THEN
                NJOKEN := o_tITEM(1);
              ELSE 
                NJOKEN := 0;
              END IF;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NJOKEN := 0;
          WHEN OTHERS THEN
            NJOKEN := 0;
        END;
        NSQLCOUNT := EBPFCHKCDHENKOU(VHAN_CD,3);
        IF NJOKEN = 1 THEN
          IF NSQLCOUNT = 0 THEN
            RJUSHOHENKO_JKN_ERR.HAN_CD_ERR := RJUSHOHENKO_JKN_ERR.HAN_CD_ERR || '@';
          END IF;
        END IF;
      END IF;

-- ２２、小学校コード
      NPOINT                       := INSTR(VDATA, ',');
      VSHOGAKU_CD                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VSHOGAKU_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VSHOGAKU_CD,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR := RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF CTLPRM4 = 1 AND BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR := RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR || '#';
      ELSIF CTLPRM4 <> 1 AND BOUT_ISNULL = FALSE THEN
        IF VSHOGAKU_CD <> '0' AND VSHOGAKU_CD <> '' AND VSHOGAKU_CD IS NOT NULL THEN
           RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR := RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR || '#';
        END IF;
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR IS NULL
         AND VSHOGAKU_CD <> '0' AND VSHOGAKU_CD <> '' AND VSHOGAKU_CD IS NOT NULL THEN
        NSQLCOUNT := EBPFCHKCDHENKOU(VSHOGAKU_CD,4);
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR := RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR || '@';
        END IF;
      END IF;

-- ２３、中学校コード
      NPOINT                       := INSTR(VDATA, ',');
      VCHUGAKU_CD                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VCHUGAKU_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VCHUGAKU_CD,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR := RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF CTLPRM5 = 1 AND BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR := RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR || '#';
      ELSIF CTLPRM5 <> 1 AND BOUT_ISNULL = FALSE THEN
        IF VCHUGAKU_CD <> '0' AND VCHUGAKU_CD <> '' AND VCHUGAKU_CD IS NOT NULL THEN
           RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR := RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR || '#';
        END IF;
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR IS NULL	
         AND VCHUGAKU_CD <> '0' AND VCHUGAKU_CD <> '' AND VCHUGAKU_CD IS NOT NULL THEN
        NSQLCOUNT := EBPFCHKCDHENKOU(VCHUGAKU_CD,5);
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR := RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR || '@';
        END IF;
      END IF;

-- ２４、投票区コード
      NPOINT                       := INSTR(VDATA, ',');
      VTOHYOKU_CD                  := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VTOHYOKU_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VTOHYOKU_CD,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR := RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF CTLPRM6 = 1 AND BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR := RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR || '#';
      ELSIF CTLPRM6 <> 1 AND BOUT_ISNULL = FALSE THEN
        IF VTOHYOKU_CD <> '0' AND VTOHYOKU_CD <> '' AND VTOHYOKU_CD IS NOT NULL THEN
           RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR := RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR || '#';
        END IF;	
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR IS NULL	
         AND VTOHYOKU_CD <> '0' AND VTOHYOKU_CD <> '' AND VTOHYOKU_CD IS NOT NULL THEN
        NSQLCOUNT := EBPFCHKCDHENKOU(VTOHYOKU_CD,6);
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR := RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR || '@';
        END IF;
      END IF;

-- ２５、ごみ業者コード
      NPOINT                       := INSTR(VDATA, ',');
      VGOMI_CD                     := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VGOMI_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VGOMI_CD,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR := RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF CTLPRM7 = 1 AND BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR := RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR || '#';
      ELSIF CTLPRM7 <> 1 AND BOUT_ISNULL = FALSE THEN
        IF VGOMI_CD <> '0' AND VGOMI_CD <> '' AND VGOMI_CD IS NOT NULL THEN
           RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR := RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR || '#';
        END IF;	
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR IS NULL
         AND VGOMI_CD <> '0' AND VGOMI_CD <> '' AND VGOMI_CD IS NOT NULL THEN
        NSQLCOUNT := EBPFCHKCDHENKOU1(VGOMI_CD,30);
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR := RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR || '@';
        END IF;
      END IF;

-- ２６、し尿業者コード
      NPOINT                       := INSTR(VDATA, ',');
      VSINYO_CD                    := TRIM(SUBSTR(VDATA, 1, NPOINT - 1));
      VDATA                        := SUBSTR(VDATA, NPOINT + 1);

      --?@データタイプのチェック
      BRET := EBPFCHKNUMERIC(VSINYO_CD,BOUT_ISNULL);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR := '*';
      END IF;

      --?Aデータ長のチェック
      BRET := EBPFCHKIKETASU(VSINYO_CD,5);
      IF BRET = FALSE THEN
        RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR := RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR || '&';
      END IF;

      --?B必須項目のチェック
      IF CTLPRM8 = 1 AND BOUT_ISNULL = TRUE THEN
        RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR := RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR || '#';
      ELSIF CTLPRM8 <> 1 AND BOUT_ISNULL = FALSE THEN
        IF VSINYO_CD <> '0' AND VSINYO_CD <> '' AND VSINYO_CD IS NOT NULL THEN
           RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR := RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR || '#';
        END IF;	
      END IF;

      --?Cコード変換チェック
      IF RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR IS NULL
         AND VSINYO_CD <> '0' AND VSINYO_CD <> '' AND VSINYO_CD IS NOT NULL THEN
        NSQLCOUNT := EBPFCHKCDHENKOU1(VSINYO_CD,31);
        IF NSQLCOUNT = 0 THEN
          RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR := RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR || '@';
        END IF;
      END IF;

      --その他のチェック
      --BF_EDABAN1その他チェック 
      --?@相関1
      IF VBF_EDABAN1 IS NOT NULL THEN
        IF VBF_HONBAN IS NULL THEN
          RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR || '%';
          RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR || '%';
        END IF;
      END IF;

      --BF_EDABAN2その他チェック
      --?A相関2
      W_ERRFLG := 0;
      IF VBF_EDABAN2 IS NOT NULL THEN
        IF VBF_HONBAN IS NULL THEN
          RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR || '%';
          W_ERRFLG := 1;
        END IF;
        IF VBF_EDABAN1 IS NULL THEN
          RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR || '%';
          W_ERRFLG := 1;
        END IF;
      END IF;
      IF W_ERRFLG = 1 THEN
        RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR || '%';
      END IF;

      --BF_EDABAN3その他チェック
      --?B相関3
      W_ERRFLG := 0;
      IF VBF_EDABAN3 IS NOT NULL THEN
        IF VBF_HONBAN IS NULL THEN
          RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR || '%';
          W_ERRFLG := 1;
        END IF;
        IF VBF_EDABAN1 IS NULL THEN
          RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR || '%';
          W_ERRFLG := 1;
        END IF;
        IF VBF_EDABAN2 IS NULL THEN
          RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR || '%';
          W_ERRFLG := 1;
        END IF;
      END IF;
      IF W_ERRFLG = 1 THEN
        RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR || '%';
      END IF;

      --?I同番
      IF RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR IS NULL AND RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR IS NULL AND 
         RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR IS NULL AND RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR IS NULL AND 
         RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR IS NULL AND RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR IS NULL THEN
        EBPFTOONAJIBANCHK(VBF_CITY_CD , VBF_OAZA_CD , VBF_HONBAN , VBF_EDABAN1 , VBF_EDABAN2 , VBF_EDABAN3);
      END IF;

      --BF_BANCHI_HENSHU_TYPEその他チェック
      --?C相関4
      W_ERRFLG := 0;
      IF RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR IS NULL THEN
        IF VBF_BANCHI_HENSHU_TYPE > 20 THEN
          IF VBF_EDABAN1 IS NULL THEN
            RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;
        IF VBF_BANCHI_HENSHU_TYPE > 30 THEN
          IF VBF_EDABAN2 IS NULL THEN
            RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;
        IF VBF_BANCHI_HENSHU_TYPE > 40 THEN
          IF VBF_EDABAN3 IS NULL THEN
            RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR := RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;
      END IF;
      IF W_ERRFLG = 1 THEN
        RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR := RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR || '%';
      END IF;

      --AF_EDABAN1その他チェック
      --?D相関5
      IF VAF_EDABAN1 IS NOT NULL THEN
        IF VAF_HONBAN IS NULL THEN
          RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR || '%';
          RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR || '%';
        END IF;
      END IF;

      --AF_EDABAN2その他チェック
      --?E相関6
      W_ERRFLG := 0;
      IF VAF_EDABAN2 IS NOT NULL THEN
        IF VAF_HONBAN IS NULL THEN
          RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR || '%';
          W_ERRFLG := 1;
        END IF;
        IF VAF_EDABAN1 IS NULL THEN
          RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR || '%';
          W_ERRFLG := 1;
        END IF;
      END IF;
      IF W_ERRFLG = 1 THEN
        RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR || '%';
      END IF;

      --AF_EDABAN3その他チェック
      --?F相関7
      W_ERRFLG := 0;
      IF VAF_EDABAN3 IS NOT NULL THEN
        IF VAF_HONBAN IS NULL THEN
          RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR || '%';
          W_ERRFLG := 1;
        END IF;
        IF VAF_EDABAN1 IS NULL THEN
          RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR || '%';
          W_ERRFLG := 1;
        END IF;
        IF VAF_EDABAN2 IS NULL THEN
          RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR || '%';
          W_ERRFLG := 1;
        END IF;
      END IF;
      IF W_ERRFLG = 1 THEN
        RJUSHOHENKO_JKN_ERR.AF_EDABAN3_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN3_ERR || '%';
      END IF;

      --AF_BANCHI_HENSHU_TYPEその他チェック
      --?G相関8
      W_ERRFLG := 0;
      IF RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR IS NULL THEN
        IF VAF_BANCHI_HENSHU_TYPE > 20 THEN
          IF VAF_EDABAN1 IS NULL THEN
            RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;
        IF VAF_BANCHI_HENSHU_TYPE > 30 THEN
          IF VAF_EDABAN2 IS NULL THEN
            RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;
        IF VAF_BANCHI_HENSHU_TYPE > 40 THEN
          IF VAF_EDABAN3 IS NULL THEN
            RJUSHOHENKO_JKN_ERR.AF_EDABAN3_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN3_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;
      END IF;
      IF W_ERRFLG = 1 THEN
        RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR := RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR || '%';
      END IF;

      --SHISHO_CDその他チェック
      --住所からの行政情報取得する
      IF (RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR IS NULL) AND
         (RJUSHOHENKO_JKN_ERR.AF_HONBAN IS NULL) AND
         (RJUSHOHENKO_JKN_ERR.AF_EDABAN1 IS NULL) AND
         (RJUSHOHENKO_JKN_ERR.AF_EDABAN2 IS NULL) THEN
        JIBSKGYOSEGET(I_JICHI_KBN,
                               VAF_OAZA_CD,
                               VAF_HONBAN,
                               VAF_EDABAN1,
                               VAF_EDABAN2,
                               O_GYOSEIKU_CD,
                               O_HANCD,
                               O_SHOGAKU_CD,
                               O_CHUGAKU_CD,
                               O_TOHYOKU_CD,
                               O_SHISHO_CD,
                               O_CHIKU_CD,
                               O_SANTEIDANTAI_CD,
                               O_SQLCODE);
        --?H相関9-1
        W_ERRFLG := 0;
        IF CTLPRM9 = 2 THEN
          IF O_SHISHO_CD IS NULL OR O_SHISHO_CD = 0 THEN
            RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR := RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;

        --?H相関9-2
        IF CTLPRM2 = 2 THEN
          IF O_CHIKU_CD IS NULL OR O_CHIKU_CD = 0 THEN
            RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR := RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;

        --?H相関9-3
        IF CTLPRM1 = 2 THEN
          IF O_GYOSEIKU_CD IS NULL OR O_GYOSEIKU_CD = 0 THEN
            RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR := RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;

        --?H相関9-4
        IF CTLPRM3 = 2 THEN
          IF O_HANCD IS NULL OR O_HANCD = 0 THEN
            RJUSHOHENKO_JKN_ERR.HAN_CD_ERR := RJUSHOHENKO_JKN_ERR.HAN_CD_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;

        --?H相関9-5
        IF CTLPRM4 = 2 THEN
          IF O_SHOGAKU_CD IS NULL OR O_SHOGAKU_CD = 0 THEN
            RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR := RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;

        --?H相関9-6
        IF CTLPRM5 = 2 THEN
          IF O_CHUGAKU_CD IS NULL OR O_CHUGAKU_CD = 0 THEN
            RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR := RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;

        --?H相関9-7
        IF CTLPRM6 = 2 THEN
          IF O_TOHYOKU_CD IS NULL OR O_TOHYOKU_CD = 0 THEN
            RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR := RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR || '%';
            W_ERRFLG := 1;
          END IF;
        END IF;

        --?H-end.
        IF W_ERRFLG = 1 THEN
          RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR := RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR || '%';
          RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR := RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR || '%';
          RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR || '%';
          RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR := RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR || '%';
        END IF;
      END IF;

      --同番チェック用ワークテーブルの更新処理
      --データチェック処理で不正の無かったデータは同番チェック用ワークテーブルに出力する。
      IF RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR IS NULL AND  RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR IS NULL AND
         RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR IS NULL AND  RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR   IS NULL AND
         RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR IS NULL AND  RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR  IS NULL AND
         RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR IS NULL AND  RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR IS NULL AND
         RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR IS NULL AND  RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR IS NULL AND
         RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR IS NULL AND  RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR   IS NULL AND
         RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR IS NULL AND  RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR  IS NULL AND
         RJUSHOHENKO_JKN_ERR.AF_EDABAN3_ERR IS NULL AND  RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR IS NULL AND
         RJUSHOHENKO_JKN_ERR.AF_YUBIN_NO_ERR IS NULL AND  RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR  IS NULL AND
         RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR   IS NULL AND  RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR IS NULL AND
         RJUSHOHENKO_JKN_ERR.HAN_CD_ERR     IS NULL AND  RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR  IS NULL AND
         RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR IS NULL AND  RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR  IS NULL AND
         RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR    IS NULL AND  RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR    IS NULL THEN

        --変更前市町村コード
        RJUSHOHENKO_KEY.BF_CITY_CD := VBF_CITY_CD;

        --変更前大字コード
        RJUSHOHENKO_KEY.BF_OAZA_CD := VBF_OAZA_CD;

        --変更前本番
        RJUSHOHENKO_KEY.BF_HONBAN  := NVL(VBF_HONBAN,0);

        --変更前枝番１
        RJUSHOHENKO_KEY.BF_EDABAN1 := NVL(VBF_EDABAN1,0);

        --変更前枝番２
        RJUSHOHENKO_KEY.BF_EDABAN2 := NVL(VBF_EDABAN2,0);

        --変更前枝番３
        RJUSHOHENKO_KEY.BF_EDABAN3 := NVL(VBF_EDABAN3,0);

        --作成日
        RJUSHOHENKO_KEY.SYS_SAKUSEIBI := i_NSHORIBI;

        --更新日
        RJUSHOHENKO_KEY.SYS_KOSHINBI := 0;

        --更新時間
        RJUSHOHENKO_KEY.SYS_JIKAN  := TO_CHAR(SYSDATE, 'HH24MISS');

        --更新職員個人番号
        RJUSHOHENKO_KEY.SYS_SHOKUINKOJIN_NO := i_NSHOKUIN_NO;

        --更新端末番号
        RJUSHOHENKO_KEY.SYS_TANMATSU_NO := i_VMACHINE_NAME;

        BEGIN
          INSERT INTO JIBWJUSHOHENKO_KEY VALUES RJUSHOHENKO_KEY;
        EXCEPTION
          WHEN OTHERS THEN
            ROLLBACK;
            -- SQL情報取得
            o_NSQL_CODE := c_INOT_SUCCESS;
            o_VSQL_MSG  := SUBSTR(TO_CHAR(SQLERRM),1,255);
            RETURN;
        END;
      ELSE
      --エラーデータの更新処理
      --データチェック処理で不正の有ったデータはエラーデータテーブル(JIBTJUSHOHENKO_JKN_ERR)に出力する。
        --レコード連番
        RJUSHOHENKO_JKN_ERR.RENBAN := NDATACOUNT;

        W_ERRFLG1 := RJUSHOHENKO_JKN_ERR.BF_CITY_CD_ERR  || RJUSHOHENKO_JKN_ERR.BF_JICHI_CD_ERR || RJUSHOHENKO_JKN_ERR.BF_OAZA_CD_ERR ||
                     RJUSHOHENKO_JKN_ERR.BF_HONBAN_ERR   || RJUSHOHENKO_JKN_ERR.BF_EDABAN1_ERR  || RJUSHOHENKO_JKN_ERR.BF_EDABAN2_ERR ||
                     RJUSHOHENKO_JKN_ERR.BF_EDABAN3_ERR  || RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE_ERR || RJUSHOHENKO_JKN_ERR.AF_CITY_CD_ERR ||
                     RJUSHOHENKO_JKN_ERR.AF_JICHI_CD_ERR || RJUSHOHENKO_JKN_ERR.AF_OAZA_CD_ERR  || RJUSHOHENKO_JKN_ERR.AF_HONBAN_ERR  ||
                     RJUSHOHENKO_JKN_ERR.AF_EDABAN1_ERR  || RJUSHOHENKO_JKN_ERR.AF_EDABAN2_ERR  || RJUSHOHENKO_JKN_ERR.AF_EDABAN3_ERR ||
                     RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE_ERR || RJUSHOHENKO_JKN_ERR.AF_YUBIN_NO_ERR || RJUSHOHENKO_JKN_ERR.SHISHO_CD_ERR ||
                     RJUSHOHENKO_JKN_ERR.CHIKU_CD_ERR    || RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD_ERR || RJUSHOHENKO_JKN_ERR.HAN_CD_ERR     ||
                     RJUSHOHENKO_JKN_ERR.SHOGAKU_CD_ERR  || RJUSHOHENKO_JKN_ERR.CHUGAKU_CD_ERR  || RJUSHOHENKO_JKN_ERR.TOHYOKU_CD_ERR ||
                     RJUSHOHENKO_JKN_ERR.GOMI_CD_ERR     || RJUSHOHENKO_JKN_ERR.SINYO_CD_ERR;
        W_ERRFLG2 := '';
        BKIGOUFLG1 := FALSE;
        BKIGOUFLG2 := FALSE;
        BKIGOUFLG3 := FALSE;
        BKIGOUFLG4 := FALSE;
        BKIGOUFLG5 := FALSE;
        BKIGOUFLG6 := FALSE;
        FOR ICNT1 IN 1..LENGTH(W_ERRFLG1) LOOP
          V_ERRFLG := TRIM(SUBSTR(W_ERRFLG1,ICNT1,1));
          IF V_ERRFLG = '*' THEN
            BKIGOUFLG1 := TRUE;	
          ELSIF V_ERRFLG = '&' THEN
            BKIGOUFLG2 := TRUE;
          ELSIF V_ERRFLG = '#' THEN
            BKIGOUFLG3 := TRUE;
          ELSIF V_ERRFLG = '@' THEN
            BKIGOUFLG4 := TRUE;
          ELSIF V_ERRFLG = '%' THEN
            BKIGOUFLG5 := TRUE;
          ELSIF V_ERRFLG = '$' THEN
            BKIGOUFLG6 := TRUE;
          END IF;
        END LOOP;
        IF BKIGOUFLG1 = TRUE THEN
          W_ERRFLG2 := '*';
        END IF;
        IF BKIGOUFLG2 = TRUE THEN
          W_ERRFLG2 := W_ERRFLG2 || '&';
        END IF;
        IF BKIGOUFLG3 = TRUE THEN
          W_ERRFLG2 := W_ERRFLG2 || '#';
        END IF;
        IF BKIGOUFLG4 = TRUE THEN
          W_ERRFLG2 := W_ERRFLG2 || '@';
        END IF;
        IF BKIGOUFLG5 = TRUE THEN
          W_ERRFLG2 := W_ERRFLG2 || '%';
        END IF;
        IF BKIGOUFLG6 = TRUE THEN
          W_ERRFLG2 := W_ERRFLG2 || '$';
        END IF;
        --代表エラーフラグ
        RJUSHOHENKO_JKN_ERR.ERRFLG := SUBSTR(W_ERRFLG2,1,10);

        --変更前市町村コード
        RJUSHOHENKO_JKN_ERR.BF_CITY_CD := SUBSTR(VBF_CITY_CD,1,10);

        --変更前自治コード（CD付）
        RJUSHOHENKO_JKN_ERR.BF_JICHI_CD := SUBSTR(VBF_JICHI_CD,1,10);

        --変更前大字コード
        RJUSHOHENKO_JKN_ERR.BF_OAZA_CD := SUBSTR(VBF_OAZA_CD,1,10);

        --変更前本番
        RJUSHOHENKO_JKN_ERR.BF_HONBAN := SUBSTR(VBF_HONBAN,1,10);

        --変更前枝番１
        RJUSHOHENKO_JKN_ERR.BF_EDABAN1 := SUBSTR(VBF_EDABAN1,1,10);

        --変更前枝番２
        RJUSHOHENKO_JKN_ERR.BF_EDABAN2 := SUBSTR(VBF_EDABAN2,1,10);

        --変更前枝番３
        RJUSHOHENKO_JKN_ERR.BF_EDABAN3 := SUBSTR(VBF_EDABAN3,1,10);

        --変更前番地編集タイプ
        RJUSHOHENKO_JKN_ERR.BF_BANCHI_HENSHU_TYPE := SUBSTR(VBF_BANCHI_HENSHU_TYPE,1,10);

        --変更後市町村コード
        RJUSHOHENKO_JKN_ERR.AF_CITY_CD := SUBSTR(VAF_CITY_CD,1,10);

        --変更後自治コード（CD付）
        RJUSHOHENKO_JKN_ERR.AF_JICHI_CD := SUBSTR(VAF_JICHI_CD,1,10);

        --変更後大字コード
        RJUSHOHENKO_JKN_ERR.AF_OAZA_CD := SUBSTR(VAF_OAZA_CD,1,10);

        --変更後本番
        RJUSHOHENKO_JKN_ERR.AF_HONBAN := SUBSTR(VAF_HONBAN,1,10);

        --変更後枝番１
        RJUSHOHENKO_JKN_ERR.AF_EDABAN1 := SUBSTR(VAF_EDABAN1,1,10);

        --変更後枝番２
        RJUSHOHENKO_JKN_ERR.AF_EDABAN2 := SUBSTR(VAF_EDABAN2,1,10);

        --変更後枝番３
        RJUSHOHENKO_JKN_ERR.AF_EDABAN3 := SUBSTR(VAF_EDABAN3,1,10);

        --変更後番地編集タイプ
        RJUSHOHENKO_JKN_ERR.AF_BANCHI_HENSHU_TYPE := SUBSTR(VAF_BANCHI_HENSHU_TYPE,1,10);

        --変更後郵便番号
        RJUSHOHENKO_JKN_ERR.AF_YUBIN_NO := SUBSTR(VAF_YUBIN_NO,1,20);

        --支所コード
        RJUSHOHENKO_JKN_ERR.SHISHO_CD := SUBSTR(VSHISHO_CD,1,10);

        --地区コード
        RJUSHOHENKO_JKN_ERR.CHIKU_CD := SUBSTR(VCHIKU_CD,1,10);

        --行政区コード
        RJUSHOHENKO_JKN_ERR.GYOSEIKU_CD := SUBSTR(VGYOSEIKU_CD,1,10);

        --班コード
        RJUSHOHENKO_JKN_ERR.HAN_CD := SUBSTR(VHAN_CD,1,20);

        --小学校コード
        RJUSHOHENKO_JKN_ERR.SHOGAKU_CD := SUBSTR(VSHOGAKU_CD,1,10);

        --中学校コード
        RJUSHOHENKO_JKN_ERR.CHUGAKU_CD := SUBSTR(VCHUGAKU_CD,1,10);

        --投票区コード
        RJUSHOHENKO_JKN_ERR.TOHYOKU_CD := SUBSTR(VTOHYOKU_CD,1,10);

        --ごみ業者コード
        RJUSHOHENKO_JKN_ERR.GOMI_CD := SUBSTR(VGOMI_CD,1,10);

        --し尿業者コード
        RJUSHOHENKO_JKN_ERR.SINYO_CD := SUBSTR(VSINYO_CD,1,10);

        --作成日
        RJUSHOHENKO_JKN_ERR.SYS_SAKUSEIBI := i_NSHORIBI;

        --更新日
        RJUSHOHENKO_JKN_ERR.SYS_KOSHINBI := 0;

        --更新時間
        RJUSHOHENKO_JKN_ERR.SYS_JIKAN := TO_CHAR(SYSDATE, 'HH24MISS');

        --更新職員個人番号
        RJUSHOHENKO_JKN_ERR.SYS_SHOKUINKOJIN_NO := i_NSHOKUIN_NO;

        --更新端末番号
        RJUSHOHENKO_JKN_ERR.SYS_TANMATSU_NO := i_VMACHINE_NAME;

        BEGIN
          INSERT INTO JIBTJUSHOHENKO_JKN_ERR VALUES RJUSHOHENKO_JKN_ERR;
          NERRDATACOUNT := NERRDATACOUNT + 1;
          NERRORFLG := 1;
        EXCEPTION
          WHEN OTHERS THEN
            ROLLBACK;
            -- SQL情報取得
            o_NSQL_CODE := c_INOT_SUCCESS;
            o_VSQL_MSG  := SUBSTR(TO_CHAR(SQLERRM),1,255);
            RETURN;
        END;
      END IF;
    END IF;

    NCOUNT                         := NCOUNT + 1;
    -- 最後一行データがない場合
    IF NINDEX <> 0 THEN
      NBAK_INDEX                   := NINDEX;
    END IF;
    NINDEX                         := DBMS_LOB.INSTR(RCFD_FILE.DATA,UTL_RAW.CAST_TO_RAW(CHR(13)),1,NCOUNT);
    NAMOUNT                        := NINDEX - NOFFSET;
    END LOOP;
  END LOOP;

  COMMIT;

  -- データを抽出しない場合、-1をo_NSQLCODEにセットする。
  IF NERRORFLG = 1 THEN
    o_NSQL_CODE   := c_INOT_SUCCESS;
  ELSE
    o_NSQL_CODE   := c_ISUCCESS;
  END IF;

  EXCEPTION
  /* その他エラー */
  WHEN OTHERS THEN
    ROLLBACK;
    -- SQL情報取得
    o_NSQL_CODE := c_INOT_SUCCESS;
    o_VSQL_MSG  := SUBSTR(TO_CHAR(SQLERRM),1,255);
END;
/
