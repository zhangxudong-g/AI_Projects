/*
 * @(#)GKB0020Repository.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb000.common.repository;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Repository;

import jp.co.jip.gkb000.common.helper.GabtAtenakihonData;

/**
 * タイトル：GKB0020Repository
 * 
 * @author ZCZL.chengjx
 * @version GKB_0.2.000.000 2023/12/04
 * -----------------------------------------------------------------------
 * 変更履歴
 * 2024/06/03 ZCZL.zhanghf Add GKB_0.3.000.000:新WizLIFE２次開発
 * 2024/06/06 ZCZL.dongyunhe 0.3.000.000:新WizLIFE２次開発(更新確認用)
 * 2025/09/08 zczl.wangj add 1.0.104.000:GKB_教育QA#20548(保守案件#null)保守対応新入学児童を保護者変更すると学校コード・入学予定日が消えて就学状況が就学中に変更される
 * 2025/09/17 ZCZL.dy Add 1.0.105.000:GKB_QA21006_製造依頼_学校区修正
 * 2026/01/06 ZCZL.dy Add 1.0.452.000:[GKB_教育]QA#22292_学級情報取得修正
 * -----------------------------------------------------------------------
 */
@Repository
public interface GKB0020Repository {
    /**
     * 学級の取得
     * 
     * @param param
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTMSGAKUKYUCD_001(Map<String, Object> param);

    /**
     * 学級の追加
     * 
     * @param param
     */
    public void insertGKBTMSGAKUKYUCD_002(Map<String, Object> param);

    /**
     * 学級の修正
     * 
     * @param param
     */
    public void updateGKBTMSGAKUKYUCD_003(Map<String, Object> param);

    /**
     * 学級の削除
     * 
     * @param param
     */
    public void deleteGKBTMSGAKUKYUCD_004(Map<String, Object> param);

    /**
     * 学級コードの重複チェック
     * 
     * @param param
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTMSGAKUKYUCD_005(Map<String, Object> param);

//2024/06/06 ZCZL.dongyunhe Delete start 0.3.000.000:新WizLIFE２次開発(更新確認用)//TODO
    /**
     * 学齢簿の追加用履歴連番取得参照
     * 
     * @param mapParameta
     * @return
     */
    public ArrayList<HashMap<String, Object>> selectGKBTGAKUREIBO_006(Map<String, Object> mapParameta);

    /**
     * 学齢簿を削除した後、最新履歴連番取得参照データを取得
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUREIBO_007(Map<String, Object> map);

    /**
     * 学齢簿を削除した後、最新履歴連番に相応する学年を取得
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUREIBO_008(Map<String, Object> map);

    /**
     * 学齢簿の参照ＳＱＬ文を生成して返します
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUREIBO_009(Map<String, Object> map);

    /**
     * 学齢簿の参照ＳＱＬ文を生成して返します
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUREIBO_010(Map<String, Object> map);

    /**
     * 学齢簿の異動履歴、督促事項参照ＳＱＬ文を生成し
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUREIBO_011(Map<String, Object> map);

    /**
     * 学齢簿の最新区分更新
     * 
     * @param map
     */
    public void updateGKBTGAKUREIBO_012(Map<String, Object> map);

    /**
     * 学齢簿の最新履歴を最新区分"0"にする更新ＳＱＬ文を生成
     * 
     * @param map
     */
    public void updateGKBTGAKUREIBO_013(Map<String, Object> map);

    /**
     * 学齢リンク参照ＳＱＬ文を生成して返します
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUNENLNK_014(Map<String, Object> map);

    /**
     * 学齢リンク追加
     * 
     * @param map
     */
    public void insertGKBTGAKUNENLNK_015(Map<String, Object> map);

    /**
     * 学齢リンク更新
     * 
     * @param map3
     */
    public void updateGKBTGAKUNENLNK_016(Map<String, Object> map3);

    /**
     * 学齢簿の更新
     * 
     * @param map
     */
    public void updateGKBTGAKUREIBO_017(Map<String, Object> map);

    /**
     * 学齢簿の異動履歴、督促履歴の更新
     * 
     * @param map
     */
    public void updateGKBTGAKUREIBO_018(Map<String, Object> map);

    /**
     * 学齢簿の追加
     * 
     * @param map
     */
    public void insertGKBTGAKUREIBO_019(Map<String, Object> map);

    /**
     * 学年リンク更新
     * 
     * @param map
     */
    public void updateGKBTGAKUNENLNK_020(Map<String, Object> map);

    /**
     * 学齢簿の削除
     * 
     * @param mapDel
     */
    public void deleteGKBTGAKUREIBO_021(Map<String, Object> mapDel);

    /**
     * 学齢簿の削除
     * 
     * @param map
     */
    public void deleteGKBTGAKUNENLNK_022(Map<String, Object> map);

    /**
     * 任意ビット参照
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTNINIBIT_023(Map<String, Object> map);

    /**
     * 任意ビット情報を削除する
     * 
     * @param mapNiniBit
     */
    public void deleteGKBTNINIBIT_024(Map<String, Object> mapNiniBit);

    /**
     * 学齢簿更新ステート
     * 
     * @param map
     */
    public void updateGKBTGAKUREIBO_025(Map<String, Object> map);

    /**
     * 学齢リンク更新ステート
     * 
     * @param map
     */
    public void updateGKBTGAKUNENLNK_026(Map<String, Object> map);

    /**
     * 任意ビット更新
     * 
     * @param map
     */
    public void updateGKBTNINIBIT_027(Map<String, Object> map);

    /**
     * 任意ビット追加
     * 
     * @param map
     */
    public void insertGKBTNINIBIT_028(Map<String, Object> map);

    /**
     * 学齢簿の個人番号付け替え更新
     * 
     * @param map
     */
    public void updateGKBTGAKUREIBO_029(Map<String, Object> map);

    /**
     * 区域外管理の個人番号付け替え更新
     * 
     * @param map
     */
    public void updateGKBTKUIKIGAIKANRI_030(Map<String, Object> map);

    /**
     * 任意ビットの個人番号付け替え更新
     * 
     * @param map
     */
    public void updateGKBTNINIBIT_031(Map<String, Object> map);

    /**
     * 就学時健康診断結果の個人番号付け替え更新
     * 
     * @param map
     */
    public void updateGKBTSHINDANKEKKA_032(Map<String, Object> map);

    /**
     * 就学援助情報管理の個人番号付け替え更新
     * 
     * @param map
     */
    public void updateGKBTSHUGAKUENJO_033(Map<String, Object> map);
//2024/06/06 ZCZL.dongyunhe Delete end

    /**
     * 設定内容コードを取得
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTSHIMEIJKN_034(Map<String, Object> map);

    /**
     * 本名使用制御管理情報取得
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTSHIMEIJKN_035(Map<String, Object> map);

    /**
     * 本名使用制御管理情報追加
     * 
     * @param map
     */
    public void insertGKBTSHIMEIJKN_036(Map<String, Object> map);

    /**
     * 本名使用制御管理更新
     * 
     * @param map
     */
    public void updateGKBTSHIMEIJKN_037(Map<String, Object> map);

//2024/06/06 ZCZL.dongyunhe Add start GKB_0.3.000.000:新WizLIFE２次開発
    /**
     * 端末管理情報(KKNTWS)テーブルの部課コード(BUKACODE)を取得する。
     * @param map 条件
     * @return 結果
     */
    public Map<String, Object> selectKKNTWS_001(Map<String, Object> map);
    /**
     * 部課情報(KKNTBK)の部課名を取得する。
     * @param map 条件
     * @return 結果
     */
    public Map<String, Object> selectKKNTBK_001(Map<String, Object> map);
    /**
     * 学齢簿の最新履歴の論理削除
     * @param map 条件
     */
    public void deleteGKBTGAKUREIBO_001(Map<String, Object> map);
    /**
     * 学齢簿の該当個人の最新データ取得
     * @param map 条件
     * @return 結果
     */
    public List<Map<String, Object>> selectGKBTGAKUREIBO_001(Map<String, Object> map);
    /**
     * 学齢簿の該当個人の最新履歴連番取得
     * @param map 条件
     * @return 結果
     */
    public Map<String, Object> selectGKBTGAKUREIBO_002(Map<String, Object> map);
    /**
     * 学齢簿の異動時宛名基本履歴連番を取得する
     * @param map 条件
     * @return 結果
     */
    public Map<String, Object> selectGKBTGAKUREIBO_003(Map<String, Object> map);
    /**
     * 学齢簿の該当個人の指定履歴データ取得
     * @param map 条件
     * @return 結果
     */
    public List<Map<String, Object>> selectGKBTGAKUREIBO_004(Map<String, Object> map);
    /**
     * 学齢簿のデータを履歴化する
     * @param map 条件
     */
    public void updateGKBTGAKUREIBO_001(Map<String, Object> map);
    /**
     * 学齢簿へデータを追加する
     * @param map 条件
     */
    public void insertGKBTGAKUREIBO_001(Map<String, Object> map);

    /**
     * 学年履歴の最新履歴の論理削除
     * @param map 条件
     */
    public void deleteGKBTGAKUNENRIREKI_001(Map<String, Object> map);
    /**
     * 学年履歴の該当個人の最新データ取得
     * @param map 条件
     * @return 結果
     */
    public List<Map<String, Object>> selectGKBTGAKUNENRIREKI_002(Map<String, Object> map);
    /**
     * 学年履歴の該当個人の最新履歴連番取得
     * @param map 条件
     * @return 結果
     */
    public Map<String, Object> selectGKBTGAKUNENRIREKI_003(Map<String, Object> map);
    /**
     * 学年履歴のデータを履歴化する
     * @param map 条件
     */
    public void updateGKBTGAKUNENRIREKI_001(Map<String, Object> map);
    /**
     * 学年履歴へデータを追加する
     * @param map 条件
     */
    public void insertGKBTGAKUNENRIREKI_001(Map<String, Object> map);

    /**
     * 就学履歴の最新履歴の論理削除
     * @param map 条件
     */
    public void deleteGKBTSHUGAKURIREKI_001(Map<String, Object> map);
    /**
     * 就学履歴の該当個人の最新データ取得
     * @param map 条件
     * @return 結果
     */
    public List<Map<String, Object>> selectGKBTSHUGAKURIREKI_001(Map<String, Object> map);
    /**
     * 就学履歴の該当個人の最新履歴連番取得
     * @param map 条件
     * @return 結果
     */
    public Map<String, Object> selectGKBTSHUGAKURIREKI_002(Map<String, Object> map);
    /**
     * 就学履歴のデータを履歴化する
     * @param map 条件
     */
    public void updateGKBTSHUGAKURIREKI_001(Map<String, Object> map);
    /**
     * 就学履歴へデータを追加する
     * @param map 条件
     */
    public void insertGKBTSHUGAKURIREKI_001(Map<String, Object> map);
//2024/06/06 ZCZL.dongyunhe Add end

//2024/06/03 ZCZL.zhanghf Add start GKB_0.3.000.000:新WizLIFE２次開発
    /**
     * 申請処理状況、申請管理取込情報取得
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTSSJ_001(Map<String, Object> map);

    /**
     * 申請管理取込情報の修正
     * 
     * @param map
     */
    public void updateGKBTSKT_001(Map<String, Object> map);
    
    /**
     * 申請処理状況の取得取得
     * 
     * @param map
     * @return
     */
    public ArrayList<Map<String, Object>> selectGKBTSSJ_002(Map<String, Object> map);
    
    /**
     * 申請処理状況をインサート処理
     * 
     * @param map
     */
    public void insert_GKBTSSJ_003(Map<String, Object> map);
    
    /**
     * 申請管理取込情報の修正
     * 
     * @param map
     */
    public void updateGKBTSSJ_004(Map<String, Object> map);
    
    /**
     * 申請処理状況の削除
     * 
     * @param param
     */
    public void deleteGKBTSSJ_005(Map<String, Object> param);
//2024/06/03 ZCZL.zhanghf Add end

//2024/06/19 ZCZL.shizhiwen Add start GKB_0.3.000.000:新WizLIFE２次開発
    /**
     * 異動事由選択画面学齢簿情報の取得
     * 
     * @param kojinNo
     * @return
     */
    public List<Map<String, Object>> selectGKBTGAKUREIBO_012(long kojinNo);
    
    /**
     * 宛名管理他業務参照情報の取得
     * 
     * @param kojinNo
     * @return
     */
    public Map<String, Object> selectGABVATENAALL_001(Map<String, Object> map);
    
    /**
     * 宛名基本情報の取得
     * 
     * @param kojinNo
     * @return
     */
    public Map<String, Object> selectGABTATENAKIHON_001(long kojinNo);
    
    /**
     * 本名使用制御管理データ数を取得
     * @param kojinNo 宛名番号
     * @return 本名使用制御管理データ数
     */
    public Integer selectGKBTSHIMEIJKN_001(long kojinNo);
    
    /**
     * 表示用続柄取得
     * 
     * @param map
     */
    public void selectGKBFKZKGMGET2_001(Map<String, Object> map);
    
    /**
     * 学年履歴の取得
     * 
     * @param kojinNo
     * @return
     */
    public Map<String, Object> selectGKBTGAKUNENRIREKI_001(long kojinNo);
    
    /**
     * 就学履歴の取得
     * 
     * @param kojinNo
     * @return
     */
    public Map<String, Object> selectGKBTSHUGAKURIREKI_003(long kojinNo);
    
    /**
     * 住記異動の取得
     * 
     * @param kojinNo
     * @return
     */
    public Map<String, Object> selectGABTJUKIIDO_001(long kojinNo);
    
    /**
     * 学年名取得
     * 
     * @param map
     */
    public void selectGKAFKGKNGTEQ_001(Map<String, Object> map);
    
    /**
     * 学級名取得
     * 
     * @param map
     */
    public void selectGKAFKGKKGTEQ_001(Map<String, Object> map);
    
    /**
     * 住民でなくなる事由名取得
     * 
     * @param jiyuCd
     */
    public String selectGABTIDOJIYU_001(int jiyuCd);
    
    /**
     * 学齢簿の最新年度取得
     * 
     */
    public int selectGKBTKOSHINLOG_001();
    
//2024/06/19 ZCZL.shizhiwen Add end
// 2025/09/08 zczl.wangj add start 1.0.104.000:GKB_教育QA#20548(保守案件#null)保守対応新入学児童を保護者変更すると学校コード・入学予定日が消えて就学状況が就学中に変更される
    /**
     * 就学履歴データ数取得
     * @param kojinNo 個人番号
     * @return 就学履歴データ数
     */
    public int selectGKBTSHUGAKURIREKI_004(String kojinNo);
// 2025/09/08 zczl.wangj add end

//2025/09/17 ZCZL.dy Add start 1.0.105.000:GKB_QA21006_製造依頼_学校区修正
    /**
     * 宛名基本情報の取得
     * 
     * @param kojinNo 遷移パラメータ.児童生徒の宛名番号
     * @return GabtAtenakihonData
     */
    public GabtAtenakihonData selectGABTATENAKIHON_005(long kojinNo);

    /**
     * 就学指定校の取得
     * @param gabtatenakihonData GabtAtenakihonData
     * @return Map
     */
    public List<Map<String, Object>> selectGABTGYOSEIJOHOJKN_006(GabtAtenakihonData gabtatenakihonData);
//2025/09/17 ZCZL.dy Add end

//2026/01/06 ZCZL.dy Add start 1.0.452.000:[GKB_教育]QA#22292_学級情報取得修正
    /**
     * 学級区分情報取得
     * @param map
     * @return 学級区分情報
     */
    public Map<String, Object> selectGKBTMSGAKUKYUCD_007(Map<String, Object> param);
//2026/01/06 ZCZL.dy Add end
}