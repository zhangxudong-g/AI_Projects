CREATE OR REPLACE PACKAGE GKBPA00190
--1.0.000.000-02.02-02.02
--------------------------------------------------------
--  サブシステム名: GKB（教育）
--  プログラム名  : オンラインパラメータ取得処理
--  機能概要      : 学校選択制案内書および学校選択制調査書の即時帳票を印刷する場合に呼び出される。
--                  標準仕様の帳票レイアウトに合わせた項目を出力する。
--                  KyoikuIdoTsuchishoPreviewEJBBean.javaで呼び出す用。
--  バージョン    : Ver 0.3.000.000
--  作成者／作成日: ZCZL.Lvjq 2024/06/03
--------------------------------------------------------
--  変更履歴
--  2024/11/06 ZCZL.WANGYUNING UPDATE 0.3.000.001:IT_GKB_00455の対応
--------------------------------------------------------
IS
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
    --                : o_sMESSAGE           発行番号
    --                : o_sBUNSHONUM         文書番号
    --  戻り値        : なし
    --  モジュール区分: 外部関数
    --  バージョン    : Ver 0.3.000.000
    --  作成者／作成日: ZCZL.Lvjq 2024/01/18
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
--  2024/11/06 ZCZL.WANGYUNING UPDATE START 0.3.000.001:IT_GKB_00455の対応 
                      --o_sMESSAGE          OUT NVARCHAR2,
                      --o_sSETAICNT         OUT NVARCHAR2,
                      --o_sBUNSHONUM        OUT NVARCHAR2);
                      o_sMESSAGE          OUT NVARCHAR2);
--  2024/11/06 ZCZL.WANGYUNING UPDATE END
END GKBPA00190;
/
