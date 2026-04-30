CREATE OR REPLACE PROCEDURE ZLBSBKZTSHLST(i_NRENBAN             IN  NUMBER,   --処理登録連番
--1.1.200.000
                                                       i_NSHOKUIN            IN  CHAR,   --職員番号
                                                       i_NVTANMATSU           IN  NVARCHAR2,--端末番号
                                                       i_NTIME               IN  NUMBER,   --時分秒
                                                       i_KARA_NENGAPPI       IN  NUMBER,   --から日付
                                                       i_MADE_NENGAPPI       IN  NUMBER,   --まで日付
                                                       i_KIJUN_NENGAPPI      IN  NUMBER,   --基準日
                                                       i_SHORIKBN_TAISHO     IN  NUMBER DEFAULT 0,   --処理区分コード_課税対象(DEFAULT:0)
                                                       i_SHORIKBN_HENKOUNASI IN  NUMBER DEFAULT 0,   --処理区分コード_変更無し(DEFAULT:0)
                                                       o_NRTN                OUT NUMBER    --処理結果（0:正常終了、1:異常終了）
)
-------------------------------------------------------------------------------------
--  業務名        ZLB（国民健康保険税）
--  PG 名         ZLBSBKZTSHLST
--  名称          計算対象世帯一覧の一括作成処理
--  処理概要      一括計算(仮算定、本算定当初、本算定月例、過年度）において、件数表を出力する。
--                また、計算対象世帯、計算保留世帯の一覧表を作成する。
--  作成者        ZCZL.ZHANGDAN
--  作成日        2023/08/01
--  Version      0.2.000.000
-------------------------------------------------------------------------------------
--  変更履歴
--  2025/12/10 JIP.SUZUKI UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00107 ログの区分修正
-------------------------------------------------------------------------------
IS
--変数定義
  IRTN              NUMBER := 0;
--ログ出力用
  BRTN              BOOLEAN;
  NSTEP             NUMBER := 0;
  VLOG              NVARCHAR2(256);
  NCONT             NUMBER := 0;
  --------------------------------------------------------------------------
  --  名称        ログ出力
  --  引数        i_NTRENBAN    登録連番
  --              io_ISTEP      ログステップ番号(２桁)
  --              i_IRETURN     リターンコード(２桁)
  --              i_VLOG        出力ログ
  --------------------------------------------------------------------------
  PROCEDURE PRINT_LOG(i_NTRENBAN IN     NUMBER,
                    io_ISTEP   IN OUT PLS_INTEGER,
                    i_IRETURN  IN     PLS_INTEGER,
                    i_VLOG     IN     NVARCHAR2
                   ) IS
    BRTN              BOOLEAN ;
    IMAX_STEP_NO      PLS_INTEGER ;
  BEGIN
    -- STEP_NO が重複していないかチェック
    SELECT MAX( STEPNUM ) INTO IMAX_STEP_NO
      FROM KKBTJLOG
     WHERE JOBNUM = i_NTRENBAN ;
    -- 重複していたら置き換える
    IF  io_ISTEP <= IMAX_STEP_NO  THEN
      io_ISTEP  :=  IMAX_STEP_NO + 1 ;
    END IF ;
    -- ステップ番号の桁数は２桁、ログの桁数は２５６桁
    IF  io_ISTEP < 100  THEN

      IF i_IRETURN = 0 THEN
        --オンライン
        IF i_NRENBAN = 0 THEN
          BRTN := KKBPK5551.FSETOLOG (i_NVTANMATSU, TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'), 'ZLBSBKZTSHLST', 0, 0, '','', SUBSTR( i_VLOG, 1, 256 ));
        ELSE
          BRTN := KKBPK5551.FSETBLOG (i_NRENBAN, 'ZLBSBKZTSHLST', 0, '', '', SUBSTR( i_VLOG, 1, 256 ) , i_NSHOKUIN, i_NVTANMATSU);
        END IF;
      ELSE
        IF SQLCODE = 0 THEN
          --オンライン
          IF i_NRENBAN = 0 THEN
            BRTN := KKBPK5551.FSETOLOG (i_NVTANMATSU, TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'), 'ZLBSBKZTSHLST', 1, 0, '','', SUBSTR( i_VLOG, 1, 256 ));
          ELSE
            BRTN := KKBPK5551.FSETBLOG (i_NRENBAN, 'ZLBSBKZTSHLST', 1, '', '', SUBSTR( i_VLOG, 1, 256 ) , i_NSHOKUIN, i_NVTANMATSU);
          END IF;
        ELSE
          --オンライン
          IF i_NRENBAN = 0 THEN
            BRTN := KKBPK5551.FSETOLOG (i_NVTANMATSU, TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'), 'ZLBSBKZTSHLST', 1, 0, SQLCODE, SQLERRM, SUBSTR( i_VLOG, 1, 256 ));
          ELSE
            BRTN := KKBPK5551.FSETBLOG (i_NRENBAN, 'ZLBSBKZTSHLST', 1, SQLCODE, SQLERRM, SUBSTR( i_VLOG, 1, 256 ) , i_NSHOKUIN, i_NVTANMATSU);
          END IF;
        END IF;
      END IF;

      io_ISTEP := io_ISTEP + 1;
    END IF;
  END PRINT_LOG;
-----------------------------------------------------------
--  合併期日取得
-----------------------------------------------------------
FUNCTION FUNCGAPPEBI RETURN PLS_INTEGER IS
  IWRTN  PLS_INTEGER  := 0;
  nFCTGetRRTN     PLS_INTEGER; 
  aCTLPRMITM      A_CONS_PRM;
BEGIN
  BEGIN 
    --合併日
    nFCTGetRRTN := KKAPK0030.FCTGetR ('KKA', '01UNIONDATE', '0000', 0, aCTLPRMITM);
    IF nFCTGetRRTN = 0 THEN
        IWRTN := aCTLPRMITM(1);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      VLOG  := SQLERRM || ' FUNCGAPPEBI ';
      NSTEP := 5;
      PRINT_LOG( i_NRENBAN, NSTEP, 1, VLOG);  --ログ出力
  END;
  RETURN (IWRTN) ;
END FUNCGAPPEBI ;
------------------------------------------------------------------------------
--  課税対象ＷＫ引続作成
------------------------------------------------------------------------------
FUNCTION FUNC_KAZEITAISHO RETURN PLS_INTEGER IS
BEGIN
  IRTN := 0;
  BEGIN
   IF i_SHORIKBN_TAISHO = 1 THEN
      INSERT INTO ZLBWKAZEITAISHO
                (SELECT KOKU_SETAI_NO, NENDO, NENDO_BUN, SYS_TANMATSU_NO, 1 
                   FROM ZLBTKEISAN_TAISHO 
                  WHERE SYS_TANMATSU_NO = i_NVTANMATSU  
              INTERSECT 
                 SELECT KOKU_SETAI_NO, CHOTEI_NENDO, NENDO_BUN, SYS_TANMATSU_NO, 1 
                   FROM ZLBTKIHON_MID 
                  WHERE SYS_TANMATSU_NO = i_NVTANMATSU);
   END IF;
   IF i_SHORIKBN_HENKOUNASI = 1 THEN
      INSERT INTO ZLBWKAZEITAISHO
           (SELECT KOKU_SETAI_NO, NENDO, NENDO_BUN, SYS_TANMATSU_NO, 3 
              FROM ZLBTKEISAN_TAISHO 
             WHERE SYS_TANMATSU_NO = i_NVTANMATSU  
             MINUS 
            SELECT KOKU_SETAI_NO, CHOTEI_NENDO, NENDO_BUN, SYS_TANMATSU_NO, 3 
              FROM ZLBTKIHON_MID 
             WHERE SYS_TANMATSU_NO = i_NVTANMATSU);
   END IF;
  EXCEPTION
    WHEN  OTHERS  THEN
      IRTN  :=  1;
  END;
  RETURN IRTN;
END FUNC_KAZEITAISHO;
------------------------------------------------------------------------------
--  課税対象ＷＫリスト作成
------------------------------------------------------------------------------
FUNCTION FUNC_KAZEITAISHOLST RETURN PLS_INTEGER IS
--パラメータ定義
  NSHORIID          NVARCHAR2(40);  --処理ID
  NSHORINAME        NVARCHAR2(60);  --処理名
  NSHO_NO           NVARCHAR2(20);  --証番号
  NTSUCHI_NO        NUMBER;         --通知書番号
  NNUSHI_KOJIN_NO   NUMBER;         --世帯主個人番号
  NNUSHI_KANJI      NVARCHAR2(100); --世帯主氏名漢字
 o_RATENA_REC       GABTATENAKIHON%ROWTYPE;
 o_RSOFU_REC        GABTSOFUSAKI%ROWTYPE;
  --カーソル定義
  CURSOR CKAZEITAISHO IS
         SELECT *
           FROM ZLBWKAZEITAISHO
          WHERE SYS_TANMATSU_NO = i_NVTANMATSU  
       ORDER BY KOKU_SETAI_NO,NENDO,NENDO_BUN,SHORI_KBN;
BEGIN
  IRTN := 0;
  BEGIN
  -- 帳票情報の取得
   BEGIN
    SELECT t2.SHORIID, t1.SHORINAME
      INTO NSHORIID, NSHORINAME
      FROM KKBTSCTL t1, KKBTJCTL t2
     WHERE t2.GYOUMUCODE = t1.GYOUMUCODE
       AND t2.SHORIID = t1.SHORIID
       AND t2.SHORISH = t1.SHORISH
       AND t2.JOBNUM = i_NRENBAN;
   EXCEPTION
     WHEN  OTHERS  THEN
       IRTN  :=  1;
   END;
   FOR RKAZEITAISHO IN CKAZEITAISHO LOOP
      -- 証番号の取得
       NSHO_NO := KHSFKGETSHONO(i_KIJUN_NENGAPPI, FUNCGAPPEBI, RKAZEITAISHO.KOKU_SETAI_NO);

         -- 通知書番号の取得
         BEGIN
             SELECT NUSHI_KOJIN_NO, TSUCHI_NO INTO NNUSHI_KOJIN_NO, NTSUCHI_NO
               FROM ZLBTKIHON_N
              WHERE KOKU_SETAI_NO = RKAZEITAISHO.KOKU_SETAI_NO
                AND NENDO_BUN     = RKAZEITAISHO.NENDO_BUN
                AND CHOTEI_NENDO  = RKAZEITAISHO.NENDO;
         EXCEPTION
           WHEN NO_DATA_FOUND THEN
               NTSUCHI_NO := NULL;
               NNUSHI_KOJIN_NO := NULL;
           WHEN OTHERS THEN
               NTSUCHI_NO := NULL;
               NNUSHI_KOJIN_NO := NULL;
         END;
         IF NNUSHI_KOJIN_NO IS NULL OR NNUSHI_KOJIN_NO = 0 THEN
           BEGIN
             SELECT NUSHI_KOJIN_NO
               INTO NNUSHI_KOJIN_NO
               FROM KHSTSETAI
               WHERE KOKU_SETAI_NO = RKAZEITAISHO.KOKU_SETAI_NO;
           EXCEPTION
             WHEN NO_DATA_FOUND THEN
               NNUSHI_KOJIN_NO := 0;
             WHEN  OTHERS  THEN
               NNUSHI_KOJIN_NO := 0;
           END;
         END IF;

       -- 世帯主氏名漢字の取得
       IRTN            := GAAPK0030.FGETATENA(NNUSHI_KOJIN_NO,'ZLB',i_KIJUN_NENGAPPI,o_RATENA_REC,o_RSOFU_REC);
       IF IRTN <> 0 THEN
          NNUSHI_KANJI    := NULL;
       ELSE
          NNUSHI_KANJI    := o_RATENA_REC.SHIMEI_KANJI;
       END IF;
       -- ZLBWKAZEITAISHOLSTへデータをインサートする
       INSERT INTO ZLBWKAZEITAISHOLST
            VALUES(NSHORIID
                  ,NSHORINAME
                  ,TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'))
                  ,i_KIJUN_NENGAPPI
                  ,i_KARA_NENGAPPI
                  ,i_MADE_NENGAPPI
                  ,RKAZEITAISHO.NENDO
                  ,RKAZEITAISHO.NENDO_BUN
                  ,NSHO_NO
                  ,RKAZEITAISHO.KOKU_SETAI_NO
                  ,NTSUCHI_NO
                  ,NNUSHI_KOJIN_NO
                  ,NNUSHI_KANJI
                  ,RKAZEITAISHO.SHORI_KBN
                  ,TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'))
                  ,TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDD'))
                  ,TO_NUMBER(TO_CHAR(SYSDATE,'HH24MISS'))
                  ,i_NSHOKUIN
                  ,i_NVTANMATSU);
        NCONT := NCONT + 1;
   END LOOP;
  EXCEPTION
    WHEN  OTHERS  THEN
      IRTN  :=  1;
  END;
  RETURN IRTN;
END FUNC_KAZEITAISHOLST;
------------------------------------------------------------------------------
--  時間の取得
------------------------------------------------------------------------------
FUNCTION FUNCGETTIME RETURN NVARCHAR2 IS
BEGIN
    RETURN (TO_CHAR(SYSDATE, 'HH24:MI:SS'));
END FUNCGETTIME;
------------------------------------------------------------------------------
--  メイン
------------------------------------------------------------------------------
BEGIN
-- 主処理を開始する際に、メッセージを出力する
  VLOG  :=  'ZLBWKAZEITAISHOLST' || 'テーブル初期化作成開始（'|| 'ZLBSBKZTSHLST' || ' ' || FUNCGETTIME || '）';
  NSTEP := 1;
  PRINT_LOG(i_NRENBAN,  NSTEP,  0, VLOG);  --ログ出力
--  使用テーブルクリア
  KHSPK00100.STRUNCATE('ZLBWKAZEITAISHOLST');
--  課税対象ＷＫ引続作成
  IRTN := FUNC_KAZEITAISHO;
--  IRTN = 0 の時、処理続く
  IF IRTN <> 0 THEN
     VLOG  :=  '課税対象ＷＫ引続作成が異常終了しました' ||'（' || 'ZLBSBKZTSHLST' || ' FUNC_KAZEITAISHO ' || FUNCGETTIME || '）';
     NSTEP := 6;
     PRINT_LOG(  i_NRENBAN,  NSTEP,  1, VLOG);  --ログ出力
     GOTO ERROR_EXIT;
  END IF;
--課税対象ＷＫリスト作成
  IRTN := FUNC_KAZEITAISHOLST;
  IF IRTN <> 0 THEN
     VLOG  :=  '課税対象ＷＫリストの作成が異常終了しました' ||'（' || 'ZLBSBKZTSHLST' || ' FUNC_KAZEITAISHOLST ' || FUNCGETTIME || '）';
     PRINT_LOG(  i_NRENBAN,  NSTEP,  1, VLOG);  --ログ出力
     GOTO ERROR_EXIT;
  END IF;
--  データチェック
  <<ERROR_EXIT>>
  IF  IRTN <> 0 THEN
    o_NRTN  :=  1;
     VLOG  :=  '課税対象ＷＫリストの作成に失敗しました' || '（'|| 'ZLBSBKZTSHLST' || ' ' || FUNCGETTIME || '）';
     NSTEP := 8;
     PRINT_LOG(  i_NRENBAN,  NSTEP,  1, VLOG);  --ログ出力
  ELSE
    o_NRTN  :=  0;
     VLOG  :=  '課税対象ＷＫリスト作成は' || NCONT || '件分作成されました' ||'（'|| 'ZLBSBKZTSHLST' || ' ' || FUNCGETTIME || '）';
     NSTEP := 7;
--  2025/12/10 JIP.SUZUKI UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00107 ログの区分修正
--     PRINT_LOG(  i_NRENBAN,  NSTEP,  1, VLOG);  --ログ出力
     PRINT_LOG(  i_NRENBAN,  NSTEP,  0, VLOG);  --ログ出力
  END IF;
END ZLBSBKZTSHLST;
/
