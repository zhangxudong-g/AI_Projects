CREATE OR REPLACE PROCEDURE GKBSKIDOTCH (i_SHORI_BI    IN NUMBER,
--1.0.004.000-02.02-02.02
                                           i_SHORI_JIKAN IN NUMBER,
                                           i_TANMATU     IN VARCHAR2,
                                           i_SHOKUIN_NO  IN VARCHAR2,
                                           i_CHOHYO_ID   IN VARCHAR2, 
                                           i_CHOHYO_ID_S IN VARCHAR2 DEFAULT NULL,
                                           i_NRENBAN     IN NUMBER,
-- 2025/05/20 ZCZL.wanghj Add start 1.0.004.000:認証コード名を取得
                                           i_vKOINFILENAME IN VARCHAR2,
                                           i_vKATAGAKI1    IN VARCHAR2,
                                           i_vSHUCHOMEI    IN VARCHAR2, 
-- 2025/05/20 ZCZL.wanghj Add end
                                           i_BATCH       IN  PLS_INTEGER DEFAULT 2
                                           )
-------------------------------------------------------------------
--  業務名       GKB（教育）
--  PG 名        GKBSKIDOTCH
--  名称         異動通知CSV作成
--  処理概要     異動通知中間ファイルよりCSVファイルを作成する
--  引き数       i_SHORI_BI      システム日付
--               i_SHORI_JIKAN   システム時間
--               i_TANMATU       端末番号
--               i_SHOKUIN_NO    職員個人番号
--               i_CHOHYO_ID     帳票ＩＤ（定義体名）
--               i_CHOHYO_ID_S   帳票ＩＤ（新１年生用定義体名）
--                               (１回のコールで 2つ CSVファイルを作成するときに使用)
--  作成者       ZCZL.LIKEWEN
--  作成日       2024/01/06
--  Version      0.2.000.000
-------------------------------------------------------------------
--  変更履歴
--  2024/03/13 ZCZL.LIKEWEN Update 0.2.000.001:教育残作業対応
--  2024/05/08 ZCZL.WUCAO Update 0.2.000.002:512_GKB_00034対応
--  2024/06/03 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--  2024/11/12 ZCZL.ZHANGLEI UPDATE 0.3.000.003:IT_GKB_00468仕様変更対応
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10106、IT_GKB_10107対応
--  2025/05/20 ZCZL.wanghj Update 1.0.004.000:認証コード名を取得
-------------------------------------------------------------------
IS
--------------------------------------------------------------------
--  定数宣言
--------------------------------------------------------------------
  c_BERROR      CONSTANT BOOLEAN := FALSE;
  c_BNORMALEND  CONSTANT BOOLEAN := TRUE;
  c_ISIN1NEN_FLG_SHIN1NEN      CONSTANT PLS_INTEGER := 1;
  c_ISIN1NEN_FLG_NOT_SHIN1NEN  CONSTANT PLS_INTEGER := 0;
--------------------------------------------------------------------
--  変数宣言
--------------------------------------------------------------------
  BRTN            BOOLEAN;                -- ステータス
  I_RTN           PLS_INTEGER;            -- 戻り値（共通）
  -- 動的ＳＱＬ
  VSQL            VARCHAR2(4000);         -- SQL文字列用
  VSORT_CLM       NVARCHAR2(2000);
--  2024/05/08 ZCZL.WUCAO Add Start 0.2.000.002:512_GKB_00034対応
    --------------------------------------------------------
    --  機能概要      : 日付を編集して返すサブプロシージャ
    --  モジュール区分: 内部関数
    --  処理概要      日付を編集して返すサブプロシージャ
    --                ＯＵＴパラメータは必ず文字列で返す
    --  作成者／作成日: ZCZL.WUCAO 2024/05/08
    --------------------------------------------------------
    PROCEDURE PROC_DAYEDIT(i_sDATE IN NVARCHAR2,o_sDATE OUT NVARCHAR2, RetValue OUT PLS_INTEGER)
    IS
      s_TEMP            NVARCHAR2(100);
    BEGIN

      IF LENGTHB(i_sDATE) > 0 THEN
        IF LENGTHB(i_sDATE) > 8 AND SUBSTR(i_sDATE,1,1) = '1' THEN
           s_TEMP := SUBSTR(i_sDATE,2);
           JIBSKDAYEDIT4(s_TEMP,o_sDATE, RetValue);
        ELSIF LENGTHB(i_sDATE) > 8 AND SUBSTR(i_sDATE,1,1) = '0' THEN
           s_TEMP := SUBSTR(i_sDATE,2);
           JIBSKDAYEDIT2(s_TEMP,o_sDATE, RetValue);
        ELSE
           JIBSKDAYEDIT2(i_sDATE,o_sDATE, RetValue);
        END IF;
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
        o_sDATE := TO_MULTI_BYTE(REPLACE(o_sDATE,' ',''));
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10106、IT_GKB_10107対応 END
      ELSE
        o_sDATE := NULL;
      END IF;

    END PROC_DAYEDIT;
--  2024/05/08 ZCZL.WUCAO Add End
-- 2024/03/15 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------
    --  機能概要      : 異動通知書作成
    --  パラメータ    : i_VSQL
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/07
    --------------------------------------------------------
--     FUNCTION FUNC_CREATE_CSV_001 (i_VSQL IN NVARCHAR2 )RETURN BOOLEAN
--     IS
--         bRTN                      BOOLEAN;                    --戻る値
--         TYPE ref_CUR              IS REF CURSOR;              --カーソル定義
--         CUR_WKRE                  ref_CUR;                    --動態カーソル
--         CR_WK                     GKBWIDOTSUCHI%ROWTYPE;      --カーソルのレコード
--         r_WKRECORD                GKBWL290R001%ROWTYPE;
--         nROWNO                    NUMBER := 0;
--     BEGIN

--         OPEN CUR_WKRE FOR i_VSQL;
--         LOOP
--           FETCH CUR_WKRE INTO CR_WK;
--           EXIT WHEN CUR_WKRE%NOTFOUND;
--           nROWNO := nROWNO + 1;
--           r_WKRECORD := NULL;
--           r_WKRECORD.NO                      := nROWNO;                       --ソート順
--           r_WKRECORD.KOIN_SHUCHO             := CR_WK.KYOIKU_KOIN_MEI;        --公印１
--           r_WKRECORD.SHIKUCHOSON_KATAGAKI    := CR_WK.SHUCHO_MEI;             --市町村長認証肩書
--           r_WKRECORD.SHIKUCHOSON_CHOMEI      := CR_WK.NINSHO_KATAGAKI;        --市町村長名
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SHORI_BI, r_WKRECORD.SAKUSEIBI, I_RTN);         --作成日
--           PROC_DAYEDIT(CR_WK.SHORI_BI, r_WKRECORD.SAKUSEIBI, I_RTN);           --作成日
--           r_WKRECORD.HYOJI_GAKKOCHO          := CR_WK.GAKKOCHO;               --表示用学校長
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.TODOKEDE_BI, r_WKRECORD.NYUGAKU_SHITEIBI, I_RTN); --入学指定日
--           PROC_DAYEDIT(CR_WK.TODOKEDE_BI, r_WKRECORD.NYUGAKU_SHITEIBI, I_RTN); --入学指定日
--           r_WKRECORD.KYOIKU_KAI_MEI          := CR_WK.KYOIKUKAI_MEI;          --教育委員会名
--           r_WKRECORD.TEKIYO                  := CR_WK.IDO_JIYU_MEI;           --摘要
--           r_WKRECORD.NEW_JUSHO1              := CR_WK.NEW_CHOMEI;             --新住所１
--           r_WKRECORD.NEW_JUSHO2              := CR_WK.NEW_BANCHI;             --新住所２
--           r_WKRECORD.OLD_JUSHO1              := CR_WK.OLD_CHOMEI;             --旧住所１
--           r_WKRECORD.OLD_JUSHO2              := CR_WK.OLD_BANCHI;             --旧住所２
--           r_WKRECORD.NEW_GAKKO               := CR_WK.NEW_GAKKO;              --新学校名
--           r_WKRECORD.OLD_GAKKO_MEI           := CR_WK.OLD_GAKKO;              --旧学校名
--           r_WKRECORD.SHIMEI_KANJI_1          := CR_WK.SHIMEI_KANJI_1;         --氏名漢字１
--           r_WKRECORD.SEIBETSU_1              := CR_WK.SEIBETSU_1;             --性別１
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_1, r_WKRECORD.SEINENGAPI_1, I_RTN);  --生年月日１
--           PROC_DAYEDIT(CR_WK.SEINENGAPI_1, r_WKRECORD.SEINENGAPI_1, I_RTN);   --生年月日１
--           r_WKRECORD.GAKUNEN_1               := CR_WK.GAKUNEN_1;              --学年１
--           r_WKRECORD.HOGOSHA_SHIMEI_KANJI_1  := CR_WK.HOGOSHA_KANJI_1;        --保護者名漢字１
--           r_WKRECORD.SHIMEI_KANJI_2          := CR_WK.SHIMEI_KANJI_2;         --氏名漢字２
--           r_WKRECORD.SEIBETSU_2              := CR_WK.SEIBETSU_2;             --性別２
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_2, r_WKRECORD.SEINENGAPI_2, I_RTN);  --生年月日２
--           PROC_DAYEDIT(CR_WK.SEINENGAPI_2, r_WKRECORD.SEINENGAPI_2, I_RTN);   --生年月日２
--           r_WKRECORD.GAKUNEN_2               := CR_WK.GAKUNEN_2;              --学年２
--           r_WKRECORD.HOGOSHA_SHIMEI_KANJI_2  := CR_WK.HOGOSHA_KANJI_2;        --保護者名漢字２
--           r_WKRECORD.SHIMEI_KANJI_3          := CR_WK.SHIMEI_KANJI_3;         --氏名漢字３
--           r_WKRECORD.SEIBETSU_3              := CR_WK.SEIBETSU_3;             --性別３
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_3, r_WKRECORD.SEINENGAPI_3, I_RTN);  --生年月日３
--           PROC_DAYEDIT(CR_WK.SEINENGAPI_3, r_WKRECORD.SEINENGAPI_3, I_RTN);  --生年月日３
--           r_WKRECORD.GAKUNEN_3               := CR_WK.GAKUNEN_3;              --学年３
--           r_WKRECORD.HOGOSHA_SHIMEI_KANJI_3  := CR_WK.HOGOSHA_KANJI_3;        --保護者名漢字３
--  2024/05/08 ZCZL.WUCAO UPDATE Start 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.TODOKEDE_BI, r_WKRECORD.IDO_TODOKE_BI, I_RTN);  --異動届出日
--          JIBSKDAYEDIT2(CR_WK.IDO_BI, r_WKRECORD.IDO_BI, I_RTN);              --異動日
--           PROC_DAYEDIT(CR_WK.TODOKEDE_BI, r_WKRECORD.IDO_TODOKE_BI, I_RTN);   --異動届出日
--           PROC_DAYEDIT(CR_WK.IDO_BI, r_WKRECORD.IDO_BI, I_RTN);               --異動日
--  2024/05/08 ZCZL.WUCAO UPDATE End
--           r_WKRECORD.KYOIKU_BIKO             := REPLACE(CR_WK.GAKKO_BIKO, chr(13)||chr(10),'#');             --委員会備考
--           r_WKRECORD.SHUCHO_NINSHOBUN        := CR_WK.KYOIKU_BIKO;            --首長認証
--           r_WKRECORD.KYOIKU_NINSHO           := CR_WK.GAKKO_NINSHO;           --委員会認証
--           r_WKRECORD.TITLE                   := CR_WK.TITLE;                  --表題
--           r_WKRECORD.SHIMEI_KANA_1           := CR_WK.SHIMEI_KANA_1;          --氏名かな１
--           r_WKRECORD.SHIMEI_KANA_2           := CR_WK.SHIMEI_KANA_2;          --氏名かな２
--           r_WKRECORD.SHIMEI_KANA_3           := CR_WK.SHIMEI_KANA_3;          --氏名かな３
--           r_WKRECORD.NEW_GYOSEIKU_MEI        := CR_WK.GYOSEIKU_MEI;           --新行政区名
--           r_WKRECORD.OLD_GYOSEIKU_MEI        := CR_WK.OLD_GYOSEIKU_MEI;       --旧行政区名
--           r_WKRECORD.IDO_JIKO                := REPLACE(CR_WK.IDOJIKO,chr(13)||chr(10),'#');                --異動事項
--           r_WKRECORD.SHUGAKU                 := REPLACE(CR_WK.SHUGAKU,chr(13)||chr(10),'#');                --就学状況
--           r_WKRECORD.KYOIKU_YAKUSHOKU_MEI    := CR_WK.KYOIKU_YAKUSHOKU_MEI;   --教育委員会役職名
--           r_WKRECORD.KYOIKU_SHUCHO_MEI       := CR_WK.KYOIKU_SHUTHOU_MEI;     --教育委員会首長名
--           r_WKRECORD.SHIMEI_BIKO1            := CR_WK.SHIMEI_BIKO1;           --氏名備考１
--           r_WKRECORD.SHIMEI_BIKO2            := CR_WK.SHIMEI_BIKO2;           --氏名備考２
--           r_WKRECORD.SHIMEI_BIKO3            := CR_WK.SHIMEI_BIKO3;           --氏名備考３
--           r_WKRECORD.SHIMEI_BIKO4            := CR_WK.SHIMEI_BIKO4;           --氏名備考４
--           r_WKRECORD.SHIMEI_BIKO5            := CR_WK.SHIMEI_BIKO5;           --氏名備考５
--           r_WKRECORD.SHIMEI_BIKO6            := CR_WK.SHIMEI_BIKO6;           --氏名備考６
--           r_WKRECORD.HOGOSHA_SHIMEI_KANA_1   := CR_WK.HOGOSHA_KANA_1;         --保護者名かな１
--           r_WKRECORD.HOGOSHA_SHIMEI_KANA_2   := CR_WK.HOGOSHA_KANA_2;         --保護者名かな２
--           r_WKRECORD.HOGOSHA_SHIMEI_KANA_3   := CR_WK.HOGOSHA_KANA_3;         --保護者名かな３
--           r_WKRECORD.HOGOSHA_KANKEI_1        := CR_WK.HOGOSHA_TSUDUKIGARA_1;  --保護者との関係１
--           r_WKRECORD.HOGOSHA_KANKEI_2        := CR_WK.HOGOSHA_TSUDUKIGARA_2;  --保護者との関係２
--           r_WKRECORD.HOGOSHA_KANKEI_3        := CR_WK.HOGOSHA_TSUDUKIGARA_3;  --保護者との関係３
--           r_WKRECORD.JIDO_KANKEI_1           := CR_WK.TSUDUKIGARA_1;          --生徒との関係１
--           r_WKRECORD.JIDO_KANKEI_2           := CR_WK.TSUDUKIGARA_2;          --生徒との関係２
--           r_WKRECORD.JIDO_KANKEI_3           := CR_WK.TSUDUKIGARA_3;          --生徒との関係３
--           r_WKRECORD.NEW_JUSHO3              := CR_WK.NEW_KATAGAKI;           --新住所３
--           r_WKRECORD.OLD_JUSHO3              := CR_WK.OLD_KATAGAKI;           --旧住所３
--           r_WKRECORD.TENNYUGAKU_BI_MEI       := CR_WK.TENNYUGAKU_BI_MEI;      --転入学年月日名
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.TENNYUGAKU_BI, r_WKRECORD.TENNYUGAKU_BI, I_RTN); --転入学年月
--           PROC_DAYEDIT(CR_WK.TENNYUGAKU_BI, r_WKRECORD.TENNYUGAKU_BI, I_RTN); --転入学年月
--           r_WKRECORD.BREAK_NO                := NULL;                         --改ページキー
--           r_WKRECORD.WSNUM                   := i_TANMATU;                    --端末番号
--           r_WKRECORD.BATCHKBN                := i_BATCH;                      --バッチ区分
--           r_WKRECORD.JOBNUM                  := i_NRENBAN;                    --ジョブNO

--           INSERT INTO GKBWL290R001 VALUES r_WKRECORD;

--         END LOOP;
--         IF CUR_WKRE%ISOPEN THEN
--           CLOSE CUR_WKRE;
--         END IF;
--         RETURN TRUE;
--     EXCEPTION
--       WHEN OTHERS THEN
--         IF CUR_WKRE%ISOPEN THEN
--           CLOSE CUR_WKRE;
--         END IF;
--         RETURN FALSE;
--     END FUNC_CREATE_CSV_001;
    --------------------------------------------------------
    --  機能概要      : 変更通知書作成
    --  パラメータ    : i_VSQL
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/07
    --------------------------------------------------------
--     FUNCTION FUNC_CREATE_CSV_002 (i_VSQL IN NVARCHAR2 )RETURN BOOLEAN
--     IS
--         bRTN                      BOOLEAN;                    --戻る値
--         TYPE ref_CUR              IS REF CURSOR;              --カーソル定義
--         CUR_WKRE                  ref_CUR;                    --動態カーソル
--         CR_WK                     GKBWIDOTSUCHI%ROWTYPE;      --カーソルのレコード
--         r_WKRECORD                GKBWL290R002%ROWTYPE;
--         nROWNO                    NUMBER := 0;
--     BEGIN

--         OPEN CUR_WKRE FOR i_VSQL;
--         LOOP
--           FETCH CUR_WKRE INTO CR_WK;
--           EXIT WHEN CUR_WKRE%NOTFOUND;
--           nROWNO := nROWNO + 1;
--           r_WKRECORD := NULL;
--           r_WKRECORD.NO                      := nROWNO;                       --ソート順
--           r_WKRECORD.TITLE                   := CR_WK.TITLE;                  --表題
--           r_WKRECORD.KOIN_SHUCHO             := CR_WK.KYOIKU_KOIN_MEI;        --公印１
--           r_WKRECORD.KOIN_SHORYAKU           := CR_WK.YOBI4;                  --公印省略文
--           r_WKRECORD.HYOJI_GAKKOCHO          := CR_WK.GAKKOCHO;               --表示用学校長
--           r_WKRECORD.GAKKO_NINSHO            := CR_WK.GAKKO_NINSHO;           --学校認証文
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SHORI_BI, r_WKRECORD.SAKUSEIBI, I_RTN);         --作成日
--           PROC_DAYEDIT(CR_WK.SHORI_BI, r_WKRECORD.SAKUSEIBI, I_RTN);          --作成日
--           r_WKRECORD.KYOIKU_KAI_MEI          := CR_WK.KYOIKUKAI_MEI;          --教育委員会名
--           r_WKRECORD.TEKIYO                  := CR_WK.IDO_JIYU_MEI;           --摘要
--           r_WKRECORD.GAKUNEN_1               := CR_WK.GAKUNEN_1;              --学年１
--           r_WKRECORD.JIDO_SHIMEI_KANA1       := CR_WK.SHIMEI_KANA_1;          --児童氏名かな１
--           r_WKRECORD.JIDO_SHIMEI_KANJI1      := CR_WK.SHIMEI_KANJI_1;         --児童氏名漢字１
--           r_WKRECORD.JIDO_SHIMEI_KANA2       := CR_WK.SHIMEI_KANA_2;          --児童氏名かな２
--           r_WKRECORD.JIDO_SHIMEI_KANJI2      := CR_WK.SHIMEI_KANJI_2;         --児童氏名漢字２
--           r_WKRECORD.NEW_JUSHO1              := CR_WK.NEW_CHOMEI;             --新住所１
--           r_WKRECORD.NEW_JUSHO2              := CR_WK.NEW_BANCHI;             --新住所２
--           r_WKRECORD.NEW_JUSHO3              := CR_WK.NEW_KATAGAKI;           --新住所３
--           r_WKRECORD.OLD_JUSHO1              := CR_WK.OLD_CHOMEI;             --旧住所１
--           r_WKRECORD.OLD_JUSHO2              := CR_WK.OLD_BANCHI;             --旧住所２
--           r_WKRECORD.OLD_JUSHO3              := CR_WK.OLD_KATAGAKI;           --旧住所３
--           r_WKRECORD.HOGOSHA_KANKEI_1        := CR_WK.HOGOSHA_TSUDUKIGARA_1;  --保護者との関係１
--           r_WKRECORD.HOGOSHA_KANKEI_2        := CR_WK.HOGOSHA_TSUDUKIGARA_2;  --保護者との関係２
--           r_WKRECORD.HOGOSHA_SHIMEI_KANA_1   := CR_WK.HOGOSHA_KANA_1;         --保護者名かな１
--           r_WKRECORD.HOGOSHA_SHIMEI_KANJI_1  := CR_WK.HOGOSHA_KANJI_1;        --保護者名漢字１
--           r_WKRECORD.HOGOSHA_SHIMEI_KANA_2   := CR_WK.HOGOSHA_KANA_2;         --保護者名かな２
--           r_WKRECORD.HOGOSHA_SHIMEI_KANJI_2  := CR_WK.HOGOSHA_KANJI_2;        --保護者名漢字２
--           r_WKRECORD.NEW_JUSHO4              := CR_WK.HOGOSHA_NEW_CHOMEI;     --新住所４
--           r_WKRECORD.NEW_JUSHO5              := CR_WK.HOGOSHA_NEW_BANCHI;     --新住所５
--           r_WKRECORD.NEW_JUSHO6              := CR_WK.HOGOSHA_NEW_KATAGAKI;   --新住所６
--           r_WKRECORD.OLD_JUSHO4              := CR_WK.HOGOSHA_OLD_CHOMEI;     --旧住所４
--           r_WKRECORD.OLD_JUSHO5              := CR_WK.HOGOSHA_OLD_BANCHI;     --旧住所５
--           r_WKRECORD.OLD_JUSHO6              := CR_WK.HOGOSHA_OLD_KATAGAKI;   --旧住所６
--           r_WKRECORD.IDO_JIKO                := REPLACE(CR_WK.IDOJIKO,chr(13)||chr(10),'#');    --異動事項
--           r_WKRECORD.TENNYUGAKU_BI_MEI       := CR_WK.TENNYUGAKU_BI_MEI;      --転入学年月日名
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(NVL(CR_WK.TENNYUGAKU_BI,0), r_WKRECORD.TENNYUGAKU_BI, I_RTN);           --転入学年月
--           PROC_DAYEDIT(NVL(CR_WK.TENNYUGAKU_BI,0), r_WKRECORD.TENNYUGAKU_BI, I_RTN);           --転入学年月
--           r_WKRECORD.SHUGAKU                 := REPLACE(CR_WK.SHUGAKU,chr(13)||chr(10),'#');    --就学状況
--  2024/05/08 ZCZL.WUCAO UPDATE Start 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(NVL(CR_WK.TODOKEDE_BI,0), r_WKRECORD.IDO_TODOKE_BI, I_RTN);             --異動届出日
--          JIBSKDAYEDIT2(NVL(CR_WK.IDO_BI,0), r_WKRECORD.IDO_BI, I_RTN);       --異動日
--           PROC_DAYEDIT(NVL(CR_WK.TODOKEDE_BI,0), r_WKRECORD.IDO_TODOKE_BI, I_RTN);             --異動届出日
--           PROC_DAYEDIT(NVL(CR_WK.IDO_BI,0), r_WKRECORD.IDO_BI, I_RTN);       --異動日
--  2024/05/08 ZCZL.WUCAO UPDATE End
--           r_WKRECORD.KYOIKU_BIKO             := REPLACE(CR_WK.GAKKO_BIKO,chr(13)||chr(10),'#'); --委員会備考
--           r_WKRECORD.SHIMEI_BIKO1            := CR_WK.SHIMEI_BIKO1;           --氏名備考１
--           r_WKRECORD.SHIMEI_BIKO2            := CR_WK.SHIMEI_BIKO2;           --氏名備考２
--           r_WKRECORD.SHIMEI_BIKO3            := CR_WK.SHIMEI_BIKO3;           --氏名備考３
--           r_WKRECORD.SHIMEI_BIKO4            := CR_WK.SHIMEI_BIKO4;           --氏名備考４
--           r_WKRECORD.SHIMEI_BIKO5            := CR_WK.SHIMEI_BIKO5;           --氏名備考５
--           r_WKRECORD.SHIMEI_BIKO6            := CR_WK.SHIMEI_BIKO6;           --氏名備考６
--           r_WKRECORD.NEW_GAKKO               := CR_WK.NEW_GAKKO;              --新学校名
--           r_WKRECORD.OLD_GAKKO_MEI           := CR_WK.OLD_GAKKO;              --旧学校名
--           r_WKRECORD.NEW_GYOSEIKU_MEI        := CR_WK.GYOSEIKU_MEI;           --新行政区名
--           r_WKRECORD.OLD_GYOSEIKU_MEI        := CR_WK.OLD_GYOSEIKU_MEI;       --旧行政区名
--           r_WKRECORD.SEIBETSU_1              := CR_WK.SEIBETSU_1;             --性別１
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_1, r_WKRECORD.SEINENGAPI_1, I_RTN);  --生年月日１
--           PROC_DAYEDIT(CR_WK.SEINENGAPI_1, r_WKRECORD.SEINENGAPI_1, I_RTN);  --生年月日１
--           r_WKRECORD.BREAK_NO                := NULL;                         --改ページキー
--           r_WKRECORD.WSNUM                   := i_TANMATU;                    --端末番号
--           r_WKRECORD.BATCHKBN                := i_BATCH;                      --バッチ区分
--           r_WKRECORD.JOBNUM                  := i_NRENBAN;                    --ジョブNO

--           INSERT INTO GKBWL290R002 VALUES r_WKRECORD;

--         END LOOP;
--         IF CUR_WKRE%ISOPEN THEN
--           CLOSE CUR_WKRE;
--         END IF;
--         RETURN TRUE;
--     EXCEPTION
--       WHEN OTHERS THEN
--         IF CUR_WKRE%ISOPEN THEN
--           CLOSE CUR_WKRE;
--         END IF;
--         RETURN FALSE;
--     END FUNC_CREATE_CSV_002;
    --------------------------------------------------------
    --  機能概要      : 変更通知リスト作成
    --  パラメータ    : i_VSQL
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/07
    --------------------------------------------------------
--     FUNCTION FUNC_CREATE_CSV_003 (i_VSQL IN NVARCHAR2 )RETURN BOOLEAN
--     IS
--         bRTN                      BOOLEAN;                    --戻る値
--         TYPE ref_CUR              IS REF CURSOR;              --カーソル定義
--         CUR_WKRE                  ref_CUR;                    --動態カーソル
--         CR_WK                     GKBWIDOTSUCHI%ROWTYPE;      --カーソルのレコード
--         r_WKRECORD                GKBWL290R003%ROWTYPE;
--         nROWNO                    NUMBER := 0;
--     BEGIN

--         OPEN CUR_WKRE FOR i_VSQL;
--         LOOP
--           FETCH CUR_WKRE INTO CR_WK;
--           EXIT WHEN CUR_WKRE%NOTFOUND;
--           nROWNO := nROWNO + 1;
--           r_WKRECORD := NULL;
--           r_WKRECORD.NO                        := nROWNO;                          --ソート順
--  2024/05/08 ZCZL.WUCAO UPDATE Start 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.YOBI1, r_WKRECORD.KAISHI_SEIREKI, I_RTN);            --異動開始日
--          JIBSKDAYEDIT2(CR_WK.YOBI2, r_WKRECORD.SHURYO_SEIREKI, I_RTN);            --異動終了日
--           PROC_DAYEDIT(CR_WK.YOBI1, r_WKRECORD.KAISHI_SEIREKI, I_RTN);            --異動開始日
--           PROC_DAYEDIT(CR_WK.YOBI2, r_WKRECORD.SHURYO_SEIREKI, I_RTN);            --異動終了日
--  2024/05/08 ZCZL.WUCAO UPDATE End
--           r_WKRECORD.GAKKO_MEI                 := CR_WK.GAKKOCHO;                  --学校名
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SHORI_BI, r_WKRECORD.SAKUSEIBI, I_RTN);              --作成年月日
--           PROC_DAYEDIT(CR_WK.SHORI_BI, r_WKRECORD.SAKUSEIBI, I_RTN);              --作成年月日
--           r_WKRECORD.OLD_SHIMEI_KANA           := CR_WK.SHIMEI_KANA_2;             --旧児童氏名かな
--           r_WKRECORD.OLD_SHIMEI_KANJI          := CR_WK.SHIMEI_KANJI_2;            --旧児童氏名漢字
--           r_WKRECORD.OLD_CHOMEI                := CR_WK.OLD_CHOMEI;                --旧児童生徒−町名
--           r_WKRECORD.OLD_BANCHI                := CR_WK.OLD_BANCHI;                --旧児童生徒−地番
--           r_WKRECORD.OLD_KATAGAKI              := CR_WK.OLD_KATAGAKI;              --旧児童生徒−方書
--           r_WKRECORD.OLD_HOGOSHA_TSUDUKIGARA   := CR_WK.HOGOSHA_TSUDUKIGARA_2;     --旧保護者との続柄
--           r_WKRECORD.OLD_GAKKO                 := CR_WK.OLD_GAKKO;                 --旧学校
--           r_WKRECORD.OLD_HOGOSHA_SHIMEI_KANA   := CR_WK.HOGOSHA_KANA_2;            --旧保護者氏名かな
--           r_WKRECORD.OLD_HOGOSHA_SHIMEI_KANJI  := CR_WK.HOGOSHA_KANJI_2;           --旧保護者氏名漢字
--           r_WKRECORD.OLD_HOGOSHA_CHOMEI        := CR_WK.HOGOSHA_OLD_CHOMEI;        --旧保護者−町名
--           r_WKRECORD.OLD_HOGOSHA_BANCHI        := CR_WK.HOGOSHA_OLD_BANCHI;        --旧保護者−地番
--           r_WKRECORD.OLD_HOGOSHA_KATAGAKI      := CR_WK.HOGOSHA_OLD_KATAGAKI;      --旧保護者−方書
--           r_WKRECORD.NEW_JIDO_SHIMEI_KANA      := CR_WK.SHIMEI_KANA_1;             --新児童氏名かな
--           r_WKRECORD.NEW_JIDO_SHIMEI_KANJI     := CR_WK.SHIMEI_KANJI_1;            --新児童氏名漢字
--           r_WKRECORD.NEW_CHOMEI                := CR_WK.NEW_CHOMEI;                --新児童生徒−町名
--           r_WKRECORD.NEW_BANCHI                := CR_WK.NEW_BANCHI;                --新児童生徒−地番
--           r_WKRECORD.NEW_KATAGAKI              := CR_WK.NEW_KATAGAKI;              --新児童生徒−方書
--           r_WKRECORD.NEW_HOGOSHA_TSUDUKIGARA   := CR_WK.HOGOSHA_TSUDUKIGARA_1;     --新保護者との続柄
--           r_WKRECORD.NEW_GAKKO                 := CR_WK.NEW_GAKKO;                 --新学校
--           r_WKRECORD.NEW_HOGOSHA_SHIMEI_KANA   := CR_WK.HOGOSHA_KANA_1;            --新保護者氏名かな
--           r_WKRECORD.NEW_HOGOSHA_SHIMEI_KANJI  := CR_WK.HOGOSHA_KANJI_1;           --新保護者氏名漢字
--           r_WKRECORD.NEW_HOGOSHA_CHOMEI        := CR_WK.HOGOSHA_NEW_CHOMEI;        --新保護者−町名
--           r_WKRECORD.NEW_HOGOSHA_BANCHI        := CR_WK.HOGOSHA_NEW_BANCHI;        --新保護者−地番
--           r_WKRECORD.NEW_HOGOSHA_KATAGAKI      := CR_WK.HOGOSHA_NEW_KATAGAKI;      --新保護者−方書
--           r_WKRECORD.JIDO_KOJIN_NO             := NVL(CR_WK.KOJIN_NO_1,0);         --児童個人番号
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_1, r_WKRECORD.SEINENGAPI, I_RTN);         --生年月日
--           PROC_DAYEDIT(CR_WK.SEINENGAPI_1, r_WKRECORD.SEINENGAPI, I_RTN);         --生年月日
--           r_WKRECORD.SEIBETSU                  := CR_WK.SEIBETSU_1;                --性別
--           r_WKRECORD.GAKUNEN                   := CR_WK.GAKUNEN_1;                 --学年
--           r_WKRECORD.SETAI_NO                  := NVL(CR_WK.SETAI_NO,0);           --世帯番号
--           r_WKRECORD.HOGOSHA_KOJIN_NO          := NVL(CR_WK.HOGOSHA_KOJIN_NO_1,0); --保護者個人番号
--  2024/05/08 ZCZL.WUCAO UPDATE Start 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.IDO_BI, r_WKRECORD.IDO_BI, I_RTN);                   --異動日
--          JIBSKDAYEDIT2(CR_WK.TODOKEDE_BI, r_WKRECORD.TODOKEDEBI, I_RTN);          --届出日
--           PROC_DAYEDIT(CR_WK.IDO_BI, r_WKRECORD.IDO_BI, I_RTN);                   --異動日
--           PROC_DAYEDIT(CR_WK.TODOKEDE_BI, r_WKRECORD.TODOKEDEBI, I_RTN);          --届出日
--  2024/05/08 ZCZL.WUCAO UPDATE End
--           r_WKRECORD.IDO_JIYU                  := CR_WK.IDO_JIYU_MEI;              --異動事由
--           r_WKRECORD.BIKO                      := REPLACE(CR_WK.GAKKO_BIKO,chr(13)||chr(10),'#');                --備考
--           r_WKRECORD.JINKAKU_KBN               := NVL(CR_WK.YOBI3,0);              --人格区分
--           r_WKRECORD.BREAK_NO                  := NULL;                            --改ページキー
--           r_WKRECORD.WSNUM                     := i_TANMATU;                       --端末番号
--           r_WKRECORD.BATCHKBN                  := i_BATCH;                         --バッチ区分
--           r_WKRECORD.JOBNUM                    := i_NRENBAN;                       --ジョブNO

--           INSERT INTO GKBWL290R003 VALUES r_WKRECORD;

--         END LOOP;
--         IF CUR_WKRE%ISOPEN THEN
--           CLOSE CUR_WKRE;
--         END IF;
--         RETURN TRUE;
--     EXCEPTION
--       WHEN OTHERS THEN
--         IF CUR_WKRE%ISOPEN THEN
--           CLOSE CUR_WKRE;
--         END IF;
--         RETURN FALSE;
--     END FUNC_CREATE_CSV_003;
-- 2024/06/03 ZCZL.muzl Delete end
    --------------------------------------------------------
    --  機能概要      : 教育異動通知書（即時）作成
    --  パラメータ    : i_VSQL
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/07
    --------------------------------------------------------
-- 2025/05/20 ZCZL.wanghj Update start 1.0.004.000:認証コード名を取得
--    FUNCTION FUNC_CREATE_CSV_004 (i_VSQL IN NVARCHAR2 )RETURN BOOLEAN
    FUNCTION FUNC_CREATE_CSV_004 (i_VSQL          IN NVARCHAR2,
                              i_vKOINFILENAME IN VARCHAR2,
                              i_vKATAGAKI1    IN VARCHAR2,
                              i_vSHUCHOMEI    IN VARCHAR2)RETURN BOOLEAN         
-- 2025/05/20 ZCZL.wanghj Update end
    IS
        bRTN                      BOOLEAN;                    --戻る値
        TYPE ref_CUR              IS REF CURSOR;              --カーソル定義
        CUR_WKRE                  ref_CUR;                    --動態カーソル
        CR_WK                     GKBWIDOTSUCHI%ROWTYPE;      --カーソルのレコード
        r_WKRECORD                GKBWL090R001%ROWTYPE;
        nROWNO                    NUMBER := 0;
    BEGIN

        OPEN CUR_WKRE FOR i_VSQL;
        LOOP
          FETCH CUR_WKRE INTO CR_WK;
          EXIT WHEN CUR_WKRE%NOTFOUND;
          nROWNO := nROWNO + 1;
          r_WKRECORD := NULL;
          r_WKRECORD.NO                      := nROWNO;                        --ソート順
-- 2025/05/20 ZCZL.wanghj Update start 1.0.004.000:認証コード名を取得
--          r_WKRECORD.KOIN_SHUCHO             := CR_WK.KYOIKU_KOIN_MEI;         --公印１
--          r_WKRECORD.SHIKUCHOSON_KATAGAKI    := CR_WK.NINSHO_KATAGAKI;         --市町村長認証肩書
--          r_WKRECORD.SHIKUCHOSON_CHOMEI      := CR_WK.SHUCHO_MEI;              --市町村長名
          r_WKRECORD.KOIN_SHUCHO             := i_vKOINFILENAME;         --公印１
          r_WKRECORD.SHIKUCHOSON_KATAGAKI    := i_vKATAGAKI1;         --市町村長認証肩書
          r_WKRECORD.SHIKUCHOSON_CHOMEI      := i_vSHUCHOMEI;              --市町村長名
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SHORI_BI, r_WKRECORD.SAKUSEIBI, I_RTN);          --作成日
          PROC_DAYEDIT(CR_WK.SHORI_BI, r_WKRECORD.SAKUSEIBI, I_RTN);          --作成日
          r_WKRECORD.HYOJI_GAKKOCHO          := CR_WK.GAKKOCHO;                --表示用学校長
          r_WKRECORD.KYOIKU_KAI_MEI          := CR_WK.IINKAI_MEI;              --教育委員会名
          r_WKRECORD.TEKIYO                  := CR_WK.IDO_JIYU_MEI;            --摘要
--2024/06/04 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--           r_WKRECORD.NEW_JUSHO1              := CR_WK.NEW_CHOMEI;              --新住所１
          --  2024/11/12 ZCZL.ZHANGLEI UPDATE 0.3.000.006:IT_GKB_00468仕様変更対応   
          --r_WKRECORD.NEW_JUSHO1              := REPLACE(CR_WK.NEW_CHOMEI,chr(13)||chr(10),'#');              --新住所１
          r_WKRECORD.NEW_JUSHO1              := REPLACE(CR_WK.NEW_JUSHO,chr(13)||chr(10),'#');              --新住所１
          r_WKRECORD.NEW_JUSHO2              := CR_WK.NEW_BANCHI;              --新住所２
--2024/06/04 ZCZL.muzl Update 0.3.000.000:新WizLIFE２次開発
--           r_WKRECORD.OLD_JUSHO1              := CR_WK.OLD_CHOMEI;              --旧住所１
          --  2024/11/12 ZCZL.ZHANGLEI UPDATE 0.3.000.006:IT_GKB_00468仕様変更対応   
          --r_WKRECORD.OLD_JUSHO1              := REPLACE(CR_WK.OLD_CHOMEI,chr(13)||chr(10),'#');              --旧住所１
          r_WKRECORD.OLD_JUSHO1              := REPLACE(CR_WK.OLD_JUSHO,chr(13)||chr(10),'#');              --旧住所１
          r_WKRECORD.OLD_JUSHO2              := CR_WK.OLD_BANCHI;              --旧住所２
          r_WKRECORD.NEW_GAKKO               := CR_WK.NEW_GAKKO;               --新学校名
          r_WKRECORD.OLD_GAKKO_MEI           := CR_WK.OLD_GAKKO;               --旧学校名
          r_WKRECORD.SHIMEI_KANJI_1          := CR_WK.SHIMEI_KANJI_1;          --氏名漢字１
          r_WKRECORD.SHIMEI_KANA_1           := CR_WK.SHIMEI_KANA_1;           --氏名かな１
          r_WKRECORD.SEIBETSU_1              := CR_WK.SEIBETSU_1;              --性別１
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_1, r_WKRECORD.SEINENGAPI_1, I_RTN);   --生年月日１
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10106、IT_GKB_10107対応 START
--          PROC_DAYEDIT(CR_WK.SEINENGAPI_1, r_WKRECORD.SEINENGAPI_1, I_RTN);   --生年月日１
          r_WKRECORD.SEINENGAPI_1            := CR_WK.SEINENGAPI_1;            --生年月日
--  2024/12/23 JPJYS.LIUHUAIQI UPDATE 0.3.000.004:品質強化：IT_GKB_10106、IT_GKB_10107対応 END
          r_WKRECORD.GAKUNEN_1               := CR_WK.GAKUNEN_1;               --学年１
          r_WKRECORD.HOGOSHA_SHIMEI_KANJI_1  := CR_WK.HOGOSHA_KANJI_1;         --保護者名漢字１
          r_WKRECORD.SHIMEI_KANJI_2          := CR_WK.SHIMEI_KANJI_2;          --氏名漢字２
          r_WKRECORD.SHIMEI_KANA_2           := CR_WK.SHIMEI_KANA_2;           --氏名かな２
          r_WKRECORD.SEIBETSU_2              := CR_WK.SEIBETSU_2;              --性別２
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_2, r_WKRECORD.SEINENGAPI_2, I_RTN);   --生年月日２
          PROC_DAYEDIT(CR_WK.SEINENGAPI_2, r_WKRECORD.SEINENGAPI_2, I_RTN);   --生年月日２
          r_WKRECORD.GAKUNEN_2               := CR_WK.GAKUNEN_2;               --学年２
          r_WKRECORD.HOGOSHA_SHIMEI_KANJI_2  := CR_WK.HOGOSHA_KANJI_2;         --保護者名漢字２
          r_WKRECORD.SHIMEI_KANJI_3          := CR_WK.SHIMEI_KANJI_3;          --氏名漢字３
          r_WKRECORD.SHIMEI_KANA_3           := CR_WK.SHIMEI_KANA_3;           --氏名かな３
          r_WKRECORD.SEIBETSU_3              := CR_WK.SEIBETSU_3;              --性別３
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_3, r_WKRECORD.SEINENGAPI_3, I_RTN);   --生年月日３
          PROC_DAYEDIT(CR_WK.SEINENGAPI_3, r_WKRECORD.SEINENGAPI_3, I_RTN);   --生年月日３
          r_WKRECORD.GAKUNEN_3               := CR_WK.GAKUNEN_3;               --学年３
          r_WKRECORD.HOGOSHA_SHIMEI_KANJI_3  := CR_WK.HOGOSHA_KANJI_3;         --保護者名漢字３
--  2024/05/08 ZCZL.WUCAO UPDATE Start 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.TODOKEDE_BI, r_WKRECORD.IDO_TODOKE_BI, I_RTN);   --異動届出日
--          JIBSKDAYEDIT2(CR_WK.IDO_BI, r_WKRECORD.IDO_BI, I_RTN);               --異動日
          PROC_DAYEDIT(CR_WK.TODOKEDE_BI, r_WKRECORD.IDO_TODOKE_BI, I_RTN);   --異動届出日
          PROC_DAYEDIT(CR_WK.IDO_BI, r_WKRECORD.IDO_BI, I_RTN);               --異動日
--  2024/05/08 ZCZL.WUCAO UPDATE End
          r_WKRECORD.KYOIKU_BIKO             := REPLACE(CR_WK.GAKKO_BIKO, chr(13)||chr(10),'#');              --委員会備考
          r_WKRECORD.IDO_JIYU_MEI            := CR_WK.GAKKO_NINSHO;            --異動事由名
          r_WKRECORD.SHUCHO_NINSHOBUN        := CR_WK.KYOIKU_NINSHO;           --首長認証
          r_WKRECORD.TITLE                   := CR_WK.TITLE;                   --表題
          r_WKRECORD.NEW_GYOSEIKU_MEI        := CR_WK.GYOSEIKU_MEI;            --新行政区名
          r_WKRECORD.OLD_GYOSEIKU_MEI        := CR_WK.OLD_GYOSEIKU_MEI;        --旧行政区名
          r_WKRECORD.PAGE_NUM                := NVL(CR_WK.PAGE,0);             --ページ番号
          r_WKRECORD.HOGOSHA_SHIMEI_KANA_1   := CR_WK.HOGOSHA_KANA_1;          --保護者名かな１
          r_WKRECORD.HOGOSHA_SHIMEI_KANA_2   := CR_WK.HOGOSHA_KANA_2;          --保護者名かな２
          r_WKRECORD.HOGOSHA_SHIMEI_KANA_3   := CR_WK.HOGOSHA_KANA_3;          --保護者名かな３
          r_WKRECORD.JIDO_KANKEI_1           := CR_WK.TSUDUKIGARA1;            --生徒との関係１
          r_WKRECORD.JIDO_KANKEI_2           := CR_WK.TSUDUKIGARA2;            --生徒との関係２
          r_WKRECORD.JIDO_KANKEI_3           := CR_WK.TSUDUKIGARA3;            --生徒との関係３
          r_WKRECORD.HOGOSHA_KANKEI_1        := CR_WK.HOGOSHA_TSUDUKIGARA_1;   --保護者との関係１
          r_WKRECORD.HOGOSHA_KANKEI_2        := CR_WK.HOGOSHA_TSUDUKIGARA_2;   --保護者との関係２
          r_WKRECORD.HOGOSHA_KANKEI_3        := CR_WK.HOGOSHA_TSUDUKIGARA_3;   --保護者との関係３
          r_WKRECORD.IDO_JIKO                := REPLACE(CR_WK.IDOJIKO,chr(13)||chr(10),'#');                 --異動事項
          r_WKRECORD.SHUGAKU                 := REPLACE(CR_WK.SHUGAKU,chr(13)||chr(10),'#');                 --就学状況
          r_WKRECORD.KYOIKU_YAKUSHOKU_MEI    := CR_WK.KYOIKU_YAKUSHOKU_MEI;    --教育委員会役職名
          r_WKRECORD.KYOIKU_SHUCHO_MEI       := CR_WK.KYOIKU_SHUTHOU_MEI;      --教育委員会首長名
          r_WKRECORD.SHIMEI_BIKO1            := CR_WK.SHIMEI_BIKO1;            --氏名備考１
          r_WKRECORD.SHIMEI_BIKO2            := CR_WK.SHIMEI_BIKO2;            --氏名備考２
          r_WKRECORD.SHIMEI_BIKO3            := CR_WK.SHIMEI_BIKO3;            --氏名備考３
          r_WKRECORD.SHIMEI_BIKO4            := CR_WK.SHIMEI_BIKO4;            --氏名備考４
          r_WKRECORD.SHIMEI_BIKO5            := CR_WK.SHIMEI_BIKO5;            --氏名備考５
          r_WKRECORD.SHIMEI_BIKO6            := CR_WK.SHIMEI_BIKO6;            --氏名備考６
          r_WKRECORD.NEW_JUSHO3              := CR_WK.NEW_KATAGAKI;            --新住所３
          r_WKRECORD.OLD_JUSHO3              := CR_WK.OLD_KATAGAKI;            --旧住所３
          r_WKRECORD.TENNYUGAKU_BI_MEI       := CR_WK.TENNYUGAKU_BI_MEI;       --転入学年月日名
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.TENNYUGAKU_BI, r_WKRECORD.TENNYUGAKU_BI, I_RTN); --転入学年月日
          PROC_DAYEDIT(CR_WK.TENNYUGAKU_BI, r_WKRECORD.TENNYUGAKU_BI, I_RTN); --転入学年月日
--2024/06/04 ZCZL.muzl Add start 0.3.000.000:新WizLIFE２次開発
          r_WKRECORD.BUNSHO_NO                  :=CR_WK.BUNSHO_NO;                     --文書番号
          r_WKRECORD.HAKKO_NENGAPI              :=CR_WK.HAKKO_NENGAPI;                 --発行年月日
          r_WKRECORD.KOIN_SHORYAKU              :=CR_WK.KOIN_SHORYAKU;                 --公印（省略）
          r_WKRECORD.KOIN_CHUSHAKU              :=CR_WK.KOIN_CHUSHAKU;                 --公印（注釈）
          r_WKRECORD.SOFU_YUBIN                 :=CR_WK.SOFU_YUBIN;                    --送付先郵便番号
          r_WKRECORD.SOFU_JUSHO                 :=CR_WK.SOFU_JUSHO;                    --送付先住所
          r_WKRECORD.SOFU_KATAGAKI              :=CR_WK.SOFU_KATAGAKI;                 --送付先方書
          r_WKRECORD.SOFU_ATENA                 :=CR_WK.SOFU_ATENA;                    --送付先宛名
          r_WKRECORD.YUBIN_NOBC                 :=CR_WK.YUBIN_NOBC;                    --カスタマバーコード
          r_WKRECORD.TSUCHI_BUN                 :=REPLACE(CR_WK.TSUCHIBUN,chr(13)||chr(10),'#');                    --通知文
          r_WKRECORD.OLD_SHIMEI_KANA            :=CR_WK.OLD_SHIMEI_KANA;               --旧氏名カナ
          r_WKRECORD.OLD_SHIMEI_KANJI           :=CR_WK.OLD_SHIMEI_KANJI;              --旧氏名漢字
          r_WKRECORD.OLD_HOGOSHA_SHIMEI_KANA    :=CR_WK.OLD_HOGOSHA_SHIMEI_KANA;       --旧保護者名カナ
          r_WKRECORD.OLD_HOGOSHA_SHIMEI_KANJI   :=CR_WK.OLD_HOGOSHA_SHIMEI_KANJI;      --旧保護者名漢字
          r_WKRECORD.OLD_GAKUNEN                :=CR_WK.OLD_GAKUNEN;                   --旧学年
          r_WKRECORD.TOIAWASESAKI1              :=CR_WK.TOIAWASESAKI1;                 --お問い合わせ先
          r_WKRECORD.TOIAWASESAKI2              :=CR_WK.TOIAWASESAKI2;                 --お問い合わせ先住所
          r_WKRECORD.TOIAWASESAKI3              :=CR_WK.TOIAWASESAKI3;                 --お問い合わせ先電話番号
          r_WKRECORD.YOSHIKI_NO                 :=CR_WK.YOSHIKI_NO;                    --様式番号
--2024/06/04 ZCZL.muzl Add end
          r_WKRECORD.BREAK_NO                := NULL;                          --改ページキー
          r_WKRECORD.WSNUM                   := i_TANMATU;                     --端末番号
          r_WKRECORD.BATCHKBN                := i_BATCH;                       --バッチ区分
          r_WKRECORD.JOBNUM                  := i_NRENBAN;                     --ジョブNO

          INSERT INTO GKBWL090R001 VALUES r_WKRECORD;

        END LOOP;
        IF CUR_WKRE%ISOPEN THEN
          CLOSE CUR_WKRE;
        END IF;
        RETURN TRUE;
    EXCEPTION
      WHEN OTHERS THEN
        IF CUR_WKRE%ISOPEN THEN
          CLOSE CUR_WKRE;
        END IF;
        RETURN FALSE;
    END FUNC_CREATE_CSV_004;

--2024/06/04 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
    --------------------------------------------------------
    --  機能概要      : 教育異動通知書（即時）作成_OL
    --  パラメータ    : i_VSQL
    --  モジュール区分: 内部関数
    --  戻り値        : 正常 TRUE,その他 FALSE
    --  バージョン    : Ver 0.2.000.000
    --  作成者／作成日: ZCZL.LIKEWEN 2024/01/18
    --------------------------------------------------------
--     FUNCTION FUNC_CREATE_CSV_005 (i_VSQL IN NVARCHAR2 )RETURN BOOLEAN
--     IS
--         bRTN                      BOOLEAN;                    --戻る値
--         TYPE ref_CUR              IS REF CURSOR;              --カーソル定義
--         CUR_WKRE                  ref_CUR;                    --動態カーソル
--         CR_WK                     GKBWIDOTSUCHI%ROWTYPE;      --カーソルのレコード
--         r_WKRECORD                GKBWL600R001%ROWTYPE;
--         nROWNO                    NUMBER := 0;
--     BEGIN

--         OPEN CUR_WKRE FOR i_VSQL;
--         LOOP
--           FETCH CUR_WKRE INTO CR_WK;
--           EXIT WHEN CUR_WKRE%NOTFOUND;
--           nROWNO := nROWNO + 1;
--           r_WKRECORD := NULL;
--           r_WKRECORD.NO                      := nROWNO;                        --ソート順
--           r_WKRECORD.KOIN_SHUCHO             := CR_WK.KYOIKU_KOIN_MEI;         --公印１
--           r_WKRECORD.SHIKUCHOSON_KATAGAKI    := CR_WK.NINSHO_KATAGAKI;         --市町村長認証肩書
--           r_WKRECORD.SHIKUCHOSON_CHOMEI      := CR_WK.SHUCHO_MEI;              --市町村長名
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SHORI_BI, r_WKRECORD.SAKUSEIBI, I_RTN);          --作成日
--           PROC_DAYEDIT(CR_WK.SHORI_BI, r_WKRECORD.SAKUSEIBI, I_RTN);           --作成日
--           r_WKRECORD.HYOJI_GAKKOCHO          := CR_WK.GAKKOCHO;                --表示用学校長
--           r_WKRECORD.KYOIKU_KAI_MEI          := CR_WK.KYOIKUKAI_MEI;           --教育委員会名
--           r_WKRECORD.TEKIYO                  := CR_WK.IDO_JIYU_MEI;            --摘要
--           r_WKRECORD.NEW_JUSHO1              := CR_WK.NEW_CHOMEI;              --新住所１
--           r_WKRECORD.NEW_JUSHO2              := CR_WK.NEW_BANCHI;              --新住所２
--           r_WKRECORD.OLD_JUSHO1              := CR_WK.OLD_CHOMEI;              --旧住所１
--           r_WKRECORD.OLD_JUSHO2              := CR_WK.OLD_BANCHI;              --旧住所２
--           r_WKRECORD.NEW_GAKKO               := CR_WK.NEW_GAKKO;               --新学校名
--           r_WKRECORD.OLD_GAKKO_MEI           := CR_WK.OLD_GAKKO;               --旧学校名
--           r_WKRECORD.SHIMEI_KANJI_1          := CR_WK.SHIMEI_KANJI_1;          --氏名漢字１
--           r_WKRECORD.SHIMEI_KANA_1           := CR_WK.SHIMEI_KANA_1;           --氏名かな１
--           r_WKRECORD.SEIBETSU_1              := CR_WK.SEIBETSU_1;              --性別１
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_1, r_WKRECORD.SEINENGAPI_1, I_RTN);   --生年月日１
--           PROC_DAYEDIT(CR_WK.SEINENGAPI_1, r_WKRECORD.SEINENGAPI_1, I_RTN);   --生年月日１
--           r_WKRECORD.GAKUNEN_1               := CR_WK.GAKUNEN_1;               --学年１
--           r_WKRECORD.HOGOSHA_SHIMEI_KANJI_1  := CR_WK.HOGOSHA_KANJI_1;         --保護者名漢字１
--           r_WKRECORD.SHIMEI_KANJI_2          := CR_WK.SHIMEI_KANJI_2;          --氏名漢字２
--           r_WKRECORD.SHIMEI_KANA_2           := CR_WK.SHIMEI_KANA_2;           --氏名かな２
--           r_WKRECORD.SEIBETSU_2              := CR_WK.SEIBETSU_2;              --性別２
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_2, r_WKRECORD.SEINENGAPI_2, I_RTN);   --生年月日２
--           PROC_DAYEDIT(CR_WK.SEINENGAPI_2, r_WKRECORD.SEINENGAPI_2, I_RTN);   --生年月日２
--           r_WKRECORD.GAKUNEN_2               := CR_WK.GAKUNEN_2;               --学年２
--           r_WKRECORD.HOGOSHA_SHIMEI_KANJI_2  := CR_WK.HOGOSHA_KANJI_2;         --保護者名漢字２
--           r_WKRECORD.SHIMEI_KANJI_3          := CR_WK.SHIMEI_KANJI_3;          --氏名漢字３
--           r_WKRECORD.SHIMEI_KANA_3           := CR_WK.SHIMEI_KANA_3;           --氏名かな３
--           r_WKRECORD.SEIBETSU_3              := CR_WK.SEIBETSU_3;              --性別３
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.SEINENGAPI_3, r_WKRECORD.SEINENGAPI_3, I_RTN);   --生年月日３
--           PROC_DAYEDIT(CR_WK.SEINENGAPI_3, r_WKRECORD.SEINENGAPI_3, I_RTN);   --生年月日３
--           r_WKRECORD.GAKUNEN_3               := CR_WK.GAKUNEN_3;               --学年３
--           r_WKRECORD.HOGOSHA_SHIMEI_KANJI_3  := CR_WK.HOGOSHA_KANJI_3;         --保護者名漢字３
--  2024/05/08 ZCZL.WUCAO UPDATE Start 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.TODOKEDE_BI, r_WKRECORD.IDO_TODOKE_BI, I_RTN);   --異動届出日
--          JIBSKDAYEDIT2(CR_WK.IDO_BI, r_WKRECORD.IDO_BI, I_RTN);               --異動日
--           PROC_DAYEDIT(CR_WK.TODOKEDE_BI, r_WKRECORD.IDO_TODOKE_BI, I_RTN);   --異動届出日
--           PROC_DAYEDIT(CR_WK.IDO_BI, r_WKRECORD.IDO_BI, I_RTN);               --異動日
--  2024/05/08 ZCZL.WUCAO UPDATE End 
--           r_WKRECORD.KYOIKU_BIKO             := REPLACE(CR_WK.KYOIKU_BIKO,'@','#');              --委員会備考
--           r_WKRECORD.SHUCHO_NINSHOBUN        := CR_WK.GAKKO_NINSHO;            --首長認証
--           r_WKRECORD.KYOIKU_NINSHO           := CR_WK.KYOIKU_NINSHO;           --委員会認証
--           r_WKRECORD.TITLE                   := CR_WK.TITLE;                   --表題
--           r_WKRECORD.NEW_GYOSEIKU_MEI        := CR_WK.GYOSEIKU_MEI;            --新行政区名
--           r_WKRECORD.OLD_GYOSEIKU_MEI        := CR_WK.OLD_GYOSEIKU_MEI;        --旧行政区名
--           r_WKRECORD.PAGE_NUM                := NVL(CR_WK.PAGE,0);             --ページ番号
--           r_WKRECORD.HOGOSHA_SHIMEI_KANA_1   := CR_WK.HOGOSHA_KANA_1;          --保護者名かな１
--           r_WKRECORD.HOGOSHA_SHIMEI_KANA_2   := CR_WK.HOGOSHA_KANA_2;          --保護者名かな２
--           r_WKRECORD.HOGOSHA_SHIMEI_KANA_3   := CR_WK.HOGOSHA_KANA_3;          --保護者名かな３
--           r_WKRECORD.JIDO_KANKEI_1           := CR_WK.TSUDUKIGARA_1;           --生徒との関係１
--           r_WKRECORD.JIDO_KANKEI_2           := CR_WK.TSUDUKIGARA_2;           --生徒との関係２
--           r_WKRECORD.JIDO_KANKEI_3           := CR_WK.TSUDUKIGARA_3;           --生徒との関係３
--           r_WKRECORD.HOGOSHA_KANKEI_1        := CR_WK.HOGOSHA_TSUDUKIGARA_1;   --保護者との関係１
--           r_WKRECORD.HOGOSHA_KANKEI_2        := CR_WK.HOGOSHA_TSUDUKIGARA_2;   --保護者との関係２
--           r_WKRECORD.HOGOSHA_KANKEI_3        := CR_WK.HOGOSHA_TSUDUKIGARA_3;   --保護者との関係３
--           r_WKRECORD.IDO_JIKO                := REPLACE(CR_WK.IDOJIKO,chr(13)||chr(10),'#');                 --異動事項
--           r_WKRECORD.SHUGAKU                 := REPLACE(CR_WK.SHUGAKU,chr(13)||chr(10),'#');                 --就学状況
--           r_WKRECORD.KYOIKU_YAKUSHOKU_MEI    := CR_WK.KYOIKU_YAKUSHOKU_MEI;    --教育委員会役職名
--           r_WKRECORD.KYOIKU_SHUCHO_MEI       := CR_WK.KYOIKU_SHUTHOU_MEI;      --教育委員会首長名
--           r_WKRECORD.SHIMEI_BIKO1            := CR_WK.SHIMEI_BIKO1;            --氏名備考１
--           r_WKRECORD.SHIMEI_BIKO2            := CR_WK.SHIMEI_BIKO2;            --氏名備考２
--           r_WKRECORD.SHIMEI_BIKO3            := CR_WK.SHIMEI_BIKO3;            --氏名備考３
--           r_WKRECORD.SHIMEI_BIKO4            := CR_WK.SHIMEI_BIKO4;            --氏名備考４
--           r_WKRECORD.SHIMEI_BIKO5            := CR_WK.SHIMEI_BIKO5;            --氏名備考５
--           r_WKRECORD.SHIMEI_BIKO6            := CR_WK.SHIMEI_BIKO6;            --氏名備考６
--           r_WKRECORD.NEW_JUSHO3              := CR_WK.NEW_KATAGAKI;            --新住所３
--           r_WKRECORD.OLD_JUSHO3              := CR_WK.OLD_KATAGAKI;            --旧住所３
--  2024/05/08 ZCZL.WUCAO UPDATE 0.2.000.002:512_GKB_00034対応
--          JIBSKDAYEDIT2(CR_WK.TENNYUGAKU_BI, r_WKRECORD.TENNYUGAKU_BI, I_RTN); --転入学年月日
--           PROC_DAYEDIT(CR_WK.TENNYUGAKU_BI, r_WKRECORD.TENNYUGAKU_BI, I_RTN); --転入学年月日
--           r_WKRECORD.TENNYUGAKU_BI_MEI       := CR_WK.TENNYUGAKU_BI_MEI;       --転入学年月日名
--           r_WKRECORD.BREAK_NO                := NULL;                          --改ページキー
--           r_WKRECORD.WSNUM                   := i_TANMATU;                     --端末番号
--           r_WKRECORD.BATCHKBN                := i_BATCH;                       --バッチ区分
--           r_WKRECORD.JOBNUM                  := i_NRENBAN;                     --ジョブNO

--           INSERT INTO GKBWL600R001 VALUES r_WKRECORD;

--         END LOOP;
--         IF CUR_WKRE%ISOPEN THEN
--           CLOSE CUR_WKRE;
--         END IF;
--         RETURN TRUE;
--     EXCEPTION
--       WHEN OTHERS THEN
--         IF CUR_WKRE%ISOPEN THEN
--           CLOSE CUR_WKRE;
--         END IF;
--         RETURN FALSE;
--     END FUNC_CREATE_CSV_005;
--2024/06/04 ZCZL.muzl Delete end
--------------------------------------------------------------------
--  ＣＳＶ作成
--------------------------------------------------------------------
  FUNCTION FUNCOUT_CSV(i_ISHIN1NEN_FLG IN PLS_INTEGER DEFAULT -1)
    RETURN BOOLEAN
  IS
    BRTN        BOOLEAN;  -- ステータス
    EXCP        EXCEPTION;
  BEGIN

    -- 異動通知中間ファイル取得
    VSQL := 'SELECT * FROM GKBWIDOTSUCHI';
    IF i_ISHIN1NEN_FLG >= 0 THEN
      VSQL := VSQL || ' WHERE SHIN1NEN_REC_FLG = ' || TO_NUMBER(i_ISHIN1NEN_FLG);
    END IF;
    IF  LENGTHB(VSORT_CLM) > 0 THEN
      VSQL := VSQL || ' ORDER BY ' || VSORT_CLM; 
    END IF;

    --帳票出力CSVの作成
    CASE i_CHOHYO_ID
--2024/06/04 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
      -- 異動通知書
--       WHEN 'GKB290R001' THEN
--         bRTN := FUNC_CREATE_CSV_001(VSQL);
      -- 変更通知書
--       WHEN 'GKB290R002' THEN
--         bRTN := FUNC_CREATE_CSV_002(VSQL);
      -- 変更通知リスト
--       WHEN 'GKB290R003' THEN
--         bRTN := FUNC_CREATE_CSV_003(VSQL);
--2024/06/04 ZCZL.muzl Delete end
      -- 教育異動通知書（即時）
      WHEN 'GKB090R001' THEN
-- 2025/05/20 ZCZL.wanghj Update 1.0.004.000:認証コード名を取得
--        bRTN := FUNC_CREATE_CSV_004(VSQL);
        bRTN := FUNC_CREATE_CSV_004(VSQL, i_vKOINFILENAME, i_vKATAGAKI1, i_vSHUCHOMEI);
--2024/06/04 ZCZL.muzl Delete start 0.3.000.000:新WizLIFE２次開発
      -- 教育異動通知書（即時）_OL
      --  2024/03/13 ZCZL.LIKEWEN Update START 0.2.000.001:教育残作業対応
      --WHEN 'GKB060R001' THEN
--       WHEN 'GKB600R001' THEN
      --  2024/03/13 ZCZL.LIKEWEN Update END
--         bRTN := FUNC_CREATE_CSV_005(VSQL);
--2024/06/04 ZCZL.muzl Delete end
      ELSE
        NULL;
    END CASE;
    IF NOT bRTN THEN
      RAISE EXCP;
    END IF;
    RETURN(c_BNORMALEND);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(c_BERROR);
  END FUNCOUT_CSV;
--------------------------------------------------------------------
--  メイン
--------------------------------------------------------------------
BEGIN
  -- SORT条件初期化
  VSORT_CLM := '';
  -- 新１年生用帳票ファイル名が与えられなかった場合は従来どおり
  -- 1つだけ CSVファイルを作成する
  IF i_CHOHYO_ID_S IS NULL THEN
    -- SORT条件指定（変更通知書、変更通知リスト）
    IF i_CHOHYO_ID = 'GKB290R002' THEN   -- 変更通知書
        VSORT_CLM := ' GAKKOCHO, IDO_BI, SHIMEI_KANA_1, SETAI_NO, KOJIN_NO_1';
    ELSIF i_CHOHYO_ID = 'GKB290R003' THEN     -- 変更通知リスト
        VSORT_CLM := ' GAKKOCHO, IDO_BI, SHIMEI_KANA_1, SETAI_NO, KOJIN_NO_1';
    ELSE
      VSORT_CLM := '';
    END IF;
    -- CSV作成
    BRTN := FUNCOUT_CSV;
    IF BRTN = c_BERROR THEN
      RETURN;
    END IF;
  ELSE
    FOR ISHIN1NEN_FLG IN c_ISIN1NEN_FLG_NOT_SHIN1NEN..c_ISIN1NEN_FLG_SHIN1NEN LOOP
      -- CSV作成
      BRTN := FUNCOUT_CSV(ISHIN1NEN_FLG);
      IF BRTN = c_BERROR THEN
        RETURN;
      END IF;
    END LOOP;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END GKBSKIDOTCH;
/
