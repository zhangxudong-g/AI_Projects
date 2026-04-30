/*
 * @(#)GKB0030Repository.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb0100.domain.repository;

import java.util.ArrayList;
import java.util.Map;

import org.springframework.stereotype.Repository;

/**
 * タイトル：GKB0030Repository
 * 
 * @author ZCZL.chengjx
 * @version GKB_0.2.000.000 2023/12/04
 */
@Repository
public interface GKB0030Repository {
    /**
     * 成人者検索条件の取得処理
     * 
     * @param paramsMap 検索条件
     * @return 成人者検索条件のリスト
     */
    public ArrayList<Map<String, Object>> selectGKBTSEIJINKENSAKUJOKEN_001(Map<String, Object> paramsMap);
    /**
     * 検索条件履歴の追加処理
     * 
     * @param paramsMap 検索条件履歴のマップ
     */
    public void insertGKBTSEIJINKENSAKUJOKEN_002(Map<String, Object> paramsMap);
    /**
     * 成人者検索条件に、同じ職員番号と、表示文字列があれば削除を行うＳＱＬ
     * 
     * @param paramsMap 削除条件
     */
    public void deleteGKBTSEIJINKENSAKUJOKEN_003(Map<String, Object> paramsMap);
    /**
     * 成人者検索条件に、最古のデータ（最小の作成日と時間）を削除するＳＱＬ
     * 
     * @param paramsMap 削除条件
     */
    public void deleteGKBTSEIJINKENSAKUJOKEN_004(Map<String, Object> paramsMap);
    /**
     * 成人者検索条件に、職員番号での検索条件の件数を取得するＳＱＬ
     * 
     * @param paramsMap 検索条件
     * @return 検索条件の件数
     */
    public ArrayList<Map<String, Object>> selectGKBTSEIJINKENSAKUJOKEN_005(Map<String, Object> paramsMap);
    /**
     * 成人者検索対象者の取得処理
     * 
     * @param paramsMap 検索条件
     * @return 成人者検索対象者
     */
    public ArrayList<Map<String, Object>> selectGKBTSEIJINKENSAKUTAISHO_006(Map<String, Object> paramsMap);
    /**
     * 成人者検索対象の追加処理
     * 
     * @param paramsMap 成人者検索対象
     */
    public void insertGKBTSEIJINKENSAKUTAISHO_007(Map<String, Object> paramsMap);
    /**
     * 成人者検索対象に、同じ職員番号と、年度、整理番号列があれば削除を行うＳＱＬ
     * 
     * @param paramsMap 成人者検索対象
     */
    public void deleteGKBTSEIJINKENSAKUTAISHO_008(Map<String, Object> paramsMap);
    /**
     * 成人者検索対象に、最古のデータ（最小の作成日と時間）を削除するＳＱＬ
     * 
     * @param paramsMap 成人者検索対象
     */
    public void deleteGKBTSEIJINKENSAKUTAISHO_009(Map<String, Object> paramsMap);
    /**
     * 成人者検索対象に、職員番号での成人者検索対象の件数を取得するＳＱＬ
     * 
     * @param paramsMap 検索条件
     * @return 成人者検索対象の件数
     */
    public ArrayList<Map<String, Object>> selectGKBTSEIJINKENSAKUTAISHO_010(Map<String, Object> paramsMap);
    /**
     * 成人者検索結果候補者一覧の取得
     * 
     * @param paramsMap 検索条件
     * @return 成人者検索結果候補者一覧リスト
     */
    public ArrayList<Map<String, Object>> selectGKBTSEIJINSHA_011(Map<String, Object> paramsMap);
    /**
     * 成人者の最大整理番号を取得する
     * 
     * @param paramsMap 成人者の最大整理番号
     */
    public ArrayList<Map<String, Object>> selectGKBTSEIJINSHA_012(Map<String, Object> paramsMap);
    /**
     * 成人者入力画面のヘルパー情報の取得
     * 
     * @param paramsMap 検索条件
     * @return 成人者入力画面のヘルパー情報
     */
    public ArrayList<Map<String, Object>> selectGKBTSEIJINSHA_013(Map<String, Object> paramsMap);
    /**
     * 世帯主情報の変更
     * 
     * @param paramsMap パラメータ
     */
    public void selectEAPFSETAINUSHI_014(Map<String, Object> paramsMap);
    /**
     * 成人者入力画面情報の取得
     * 
     * @param paramsMap 検索条件
     * @return 成人者入力画面情報
     */
    public ArrayList<Map<String, Object>> selectGABTJUKIIDO_015(Map<String, Object> paramsMap);
    /**
     * 成人式通知書管理一覧を取得
     * 
     * @return 成人式通知書管理一覧
     */
    public ArrayList<Map<String, Object>> selectGKBTTSUCHISHOKANRISEIJIN_016();
    /**
     * 帳票名管理一覧を取得
     * 
     * @return 帳票名管理一覧
     */
    public ArrayList<Map<String, Object>> selectGKBTTSUCHISHOKANRISEIJIN_016_1();
    /**
     * 成人式通知書条件を取得
     * 
     * @param paramsMap 検索条件
     * @return 成人式通知書条件
     */
    public ArrayList<Map<String, Object>> selectGKBTTSUCHISHOJKNSEIJIN_017(Map<String, Object> paramsMap);
    /**
     * 成人式通知書条件情報を取得
     * 
     * @param paramsMap 検索条件
     * @return 成人式通知書条件情報
     */
    public ArrayList<Map<String, Object>> selectGKBTTSUCHISHOJKNSEIJIN_018(Map<String, Object> paramsMap);
    /**
     * 通知書条件情報の更新
     * 
     * @param paramsMap 通知書条件情報
     */
    public void updateGKBTTSUCHISHOJKNSEIJIN_019(Map<String, Object> paramsMap);
    /**
     * 通知書条件情報の追加
     * 
     * @param paramsMap 通知書条件情報
     */
    public void insertGKBTTSUCHISHOJKNSEIJIN_020(Map<String, Object> paramsMap);
    /**
     * 成人者入力情報の校区、行政区の更新処理
     * 
     * @param paramsMap 成人者入力情報
     */
    public void updateGKBTSEIJINSHA_021(Map<String, Object> paramsMap);
    /**
     * 成人者入力情報の出欠区分の更新処理
     * 
     * @param paramsMap 成人者入力情報
     */
    public void updateGKBTSEIJINSHA_022(Map<String, Object> paramsMap);
    /**
     * 成人者帳票番号を取得
     * 
     * @param paramsMap 帳票情報
     */
    public ArrayList<Map<String, Object>> selectKKATOPRT_01(Map<String, Object> paramsMap);
    
    /**
     * sqlID "selectKKATCD_001" を実行する<br>
     * @param input  情報
     * @return  学校情報
     */
    public ArrayList<Map<String, Object>> selectKKATCD_001(Map<String, Object> paramsMap);
}