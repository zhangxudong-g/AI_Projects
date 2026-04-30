/*
 * @(#)GKB0010Repository.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb0000.domain.repository;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.apache.ibatis.annotations.Param;
import org.springframework.stereotype.Repository;

import jp.co.jip.gkb0000.domain.helper.GabtatenakihonData;
import jp.co.jip.gkb0000.domain.helper.GakureiboSearchCondition;
import jp.co.jip.gkb0000.domain.helper.GakureiboShokaiData;
import jp.co.jip.gkb0000.domain.helper.GakureiboShokaiHistoryData;
import jp.co.jip.gkb0000.domain.helper.GkbtgakureiboData;
import jp.co.jip.gkb0000.domain.helper.Gkbtgkunenrireki;
import jp.co.jip.gkb0000.domain.helper.HogosyaData;

/**
 * タイトル：GKB0010Repository
 * 
 * @author ZCZL.chengjx
 * @version GKB_0.2.000.000 2023/12/04
 * ---------------------------------------------------------------------------------------------------
 * 変更履歴
 * 2024/06/03 zczl.wangdi Add GKB_0.3.000.000:新WizLIFE2次開発
 * 2024/06/07 zczl.wangj Add GKB_0.3.000.000:新WizLIFE2次開発
 * 2024/06/11 ZCZL.xuhongyu Add GKB_0.3.000.000:新WizLIFE2次開発 
 * 2024/06/18 zczl.gengming Add GKB_0.3.000.000:新WizLIFE2次開発
 * 2025/05/27 ZCZL.DY Update 1.0.006.000:GK_QA13923(16522)_二次対応依頼_就学指定校を修正
 * 2025/10/01 CTC.GL UPDATE 1.0.107.001:GKB_21701対応
 * 2025/12/16 ZCZL.chengjx Add 1.0.404.000:新WizLIFE保守対応 QA23166
 * ---------------------------------------------------------------------------------------------------
 */
@Repository
public interface GKB0010Repository {

    /**
     * [備考情報]の取得処理(備考情報（基本テーブル部分）を取得するSQL)
     *
     * @param param Map<String, Object> 情報
     * @return ArrayList<Map<String, Object>> 情報
     */
    public ArrayList<Map<String, Object>> selectBIKOSENTAKU_001(Map<String, Object> param);

    /**
     * 備考取得(備考情報（基本テーブル部分）を取得するSQL)
     *
     * @param param Map<String, Object> 情報
     * @return ArrayList<Map<String, Object>> 情報
     */
    public ArrayList<Map<String, Object>> selectGETBIKO_002(Map<String, Object> param);

    /**
     * 保護者宛名異動履歴
     * @param param
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGABVATENAALL_003(Map<String, Object> param);
    
    /**
     * 児童生徒宛名異動履歴
     * @param param
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGABVATENAALL_004(Map<String, Object> param);
    
    /**
     * 通知書タイトルの取得
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTHYODAIKANRI_005();
    
    /**
     * 候補者一覧取得
     * @param param
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGABTATENAKIHON_006(Map<String, Object> param);
    
    /**
     * 認証情報（基本テーブル部分）を取得するSQL
     * @param map
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectninshobunSentaku_007(Map<String, Object> map);
    
    /**
     * 認証情報（基本テーブル部分）を取得するSQL
     * @param map
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectgetNinshobun_008(Map<String, Object> map);
    
// 2024/06/07 zczl.wangj Add start GKB_0.3.000.000:新WizLIFE2次開発
    /**
     * 学齢簿生徒履歴連番リスト取得SQL
     * @param atenaNo 宛名番号
     * @return 学齢簿生徒履歴連番リスト
     */
    public ArrayList<String> selectGKBTGAKUREIBO_001(String kojinNo);
    /**
     * 学齢簿情報取得
     * @param condition 検索条件
     * @return 学齢簿情報
     */
    public GakureiboShokaiData selectGKBTGAKUREIBO_002(GakureiboSearchCondition condition);
    /**
     * 保護者情報取得
     * @param condition 検索条件
     * @return 保護者情報
     */
    public HogosyaData selectGKBTGAKUREIBO_003(GakureiboSearchCondition condition);
    /**
     * 異動事由取得
     * @param jiyuCd 異動事由コード
     * @return 異動事由
     */
    public String selectGABTIDOJIYU_001(String jiyuCd);
    /**
     * 本名使用制御管理データ数を取得
     * @param kojinNo 宛名番号
     * @return 本名使用制御管理データ数
     */
    public Integer selectGKBTSHIMEIJKN_001(String kojinNo);
    /**
     * 続柄名取得
     * @param param パラメータ
     */
    public void selectGKBFKZKGMGET_001(Map<String, Object> param);
    /**
     * 続柄名取得
     * @param param パラメータ
     */
    public void selectGKBFKZKGMGET_002(Map<String, Object> param);
    /**
     * 学校名取得
     * @param param パラメータ
     */
    public void selectGKAFKGKOGTEQ_001(Map<String, Object> param);
    /**
     * 学年マスタ情報取得
     * @param gakunenCd 学年コード
     * @return 学年マスタデータ
     */
    public Map<String, String> selectGKBTGAKUNEN_001(String gakunenCd);
    /**
     * 小学校情報取得
     * @param gakkoCd
     * @return 小学校情
     */
    public Map<String, String> selectGKBTSHOGAKKO_001(String gakkoCd);
    /**
     * 中学校情報取得
     * @param gakkoCd
     * @return 小学校情
     */
    public Map<String, String> selectGKBTCHUGAKKO_001(String gakkoCd);
    /**
     * 盲聾養護学校情報取得
     * @param gakkoCd
     * @return 小学校情
     */
    public Map<String, String> selectGKBTYOGOGAKKO_001(String gakkoCd);
    /**
     * 区域外学校情報取得
     * @param gakkoCd
     * @return 小学校情
     */
    public Map<String, String> selectGKBTKUIKIGAI_001(String gakkoCd);
    /**
     * 国・私立学校情報取得
     * @param gakkoCd
     * @return 小学校情
     */
    public Map<String, String> selectGKBTKUNISIRITSUGAKKO_001(String gakkoCd);
    /**
     * 学級区分情報取得
     * @param gakkoKbnCd 学校区分コード
     * @param gakkoCd 学校コード
     * @param gakukyuCd 学級コード
     * @return 学級区分情報
     */
    public Map<String, Object> selectGKBTMSGAKUKYUCD_001(@Param(value = "gakkoKbnCd")String gakkoKbnCd, @Param(value = "gakkoCd")String gakkoCd, @Param(value = "gakukyuCd")String gakukyuCd);
    /**
     * 校区情報取得
     * @param param パラメータ
     */
    public void selectGKBFKGKKUGET_001(Map<String, Object> param);
    /**
     * 西暦→和暦変換
     * @param param パラメータ
     */
    public void selectFDateSW_001(Map<String, Object> param);
    /**
     * 兄弟情報取得
     * @param kojinNo 保護者宛名番号
     * @return 兄弟情報配列
     */
    public List<Map<String, String>> selectGKBTGAKUREIBO_004(String kojinNo);
    /**
     * 区域外管理データ件数取得
     * @param kojinNo 宛名番号
     * @return 区域外管理データ件数
     */
    public int selectGKBTKUIKIGAIKANRI_001(String kojinNo);
    /**
     * 最新学齢簿データ取得
     * @param kojinNo 宛名番号
     * @return 最新学齢簿データ
     */
    GkbtgakureiboData select_GKBTGAKUREIBO_001(String kojinNo);
    
    /**
     * 学齢簿データリスト取得
     * @param kojinNo 宛名番号
     * @return 学齢簿データリスト取得
     */
    List<GkbtgakureiboData> select_GKBTGAKUREIBO_002(String kojinNo);
    /**
     * 宛名情報取得
     * @param kojinNo 宛名番号
     * @param rirekiRenban 履歴連番
     * @return 宛名情報
     */
    GabtatenakihonData select_GABTATENARIREKI_001(@Param(value = "kojinNo") String kojinNo, @Param(value = "rirekiRenban") String rirekiRenban);
    /**
     * 児童宛名情報取得
     * @param kojinNo 宛名番号
     * @param rirekiRenban 履歴連番
     * @return 宛名情報
     */
    GabtatenakihonData select_GABTATENAKIHON_001(@Param(value = "kojinNo") String kojinNo, @Param(value = "rirekiRenban") String rirekiRenban);
    /**
     * 保護者宛名情報取得
     * @param kojinNo 宛名番号
     * @param rirekiRenban 履歴連番
     * @return 宛名情報
     */
    GabtatenakihonData select_GABTATENAKIHON_002(@Param(value = "kojinNo") String kojinNo, @Param(value = "rirekiRenban") String rirekiRenban);
    /**
     * 宛名情報取得
     * @param kojinNo 宛名番号
     * @return 宛名情報
     */
    GabtatenakihonData select_GABVATENAALL_002(String kojinNo);
    /**
     * 学年最新履歴取得
     * @param kojinNo
     * @return 学年最新履歴
     */
    Gkbtgkunenrireki selectGKBTGAKUNENRIREKI_003(String kojinNo);
    /**
     * 小学校区情報取得
     * @param joken 児童宛名情報
     * @return 学校区情報
     */
    List<Map<String, Object>> selectGKBTMSGAKKU_001(GabtatenakihonData joken);
    /**
     * 小学校区情報取得
     * @param joken 児童宛名情報
     * @return 学校区情報
     */
    List<Map<String, Object>> selectGKBTMSGAKKU_002(GabtatenakihonData joken);
    /**
     * 中学校区情報取得
     * @param joken 児童宛名情報
     * @return 学校区情報
     */
    List<Map<String, Object>> selectGKBTMSGAKKU_003(GabtatenakihonData joken);
    /**
     * 中学校区情報取得
     * @param joken 児童宛名情報
     * @return 学校区情報
     */
    List<Map<String, Object>> selectGKBTMSGAKKU_004(GabtatenakihonData joken);
    /**
     * 就学可能校取得
     * @param joken 条件
     * @return 就学可能校リスト
     */
    List<Map<String, Object>> selectGKBTMSGAKKU_005(Map<String, Object> joken);
    /**
     * 就学可能校取得
     * @param joken 条件
     * @return 就学可能校リスト
     */
    List<Map<String, Object>> selectGKBTMSGAKKU_006(Map<String, Object> joken);
    /**
     * 就学可能校取得
     * @param joken 条件
     * @return 就学可能校リスト
     */
    List<Map<String, Object>> selectGKBTMSGAKKU_007(Map<String, Object> joken);
    /**
     * 就学可能校取得
     * @param joken 条件
     * @return 就学可能校リスト
     */
    List<Map<String, Object>> selectGKBTMSGAKKU_008(Map<String, Object> joken);
    /**
     * 住民記録異動情報取得
     * @param kojinNo 宛名番号
     * @return 住民記録異動情報
     */
    Map<String, Object> selectGABTJUKIIDO_001(String kojinNo);
    /**
     * 学齢簿前履歴処理日取得
     * @param kojinNo 宛名番号
     * @return 学齢簿前履歴処理日
     */
    String select_GKBTGAKUREIBO_003(String kojinNo);
    /**
     * 不就学の申請
     * @param shinseiKanriRenban 申請管理連番
     * @return 不就学の申請データ
     */
    Map<String, Object> select_GKBWSKT1_001(String shinseiKanriRenban);
    /**
     * 就学猶予・免除の申請
     * @param shinseiKanriRenban 申請管理連番
     * @return 就学猶予・免除の申請データ
     */
    Map<String, Object> select_GKBWSKT2_001(String shinseiKanriRenban);
    /**
     * 就学校変更の申請
     * @param shinseiKanriRenban 申請管理連番
     * @return 就学校変更の申請データ
     */
    Map<String, Object> select_GKBWSKT3_001(String shinseiKanriRenban);
    /**
     * 区域外就学の申請
     * @param shinseiKanriRenban 申請管理連番
     * @return 区域外就学の申請データ
     */
    Map<String, Object> select_GKBWSKT4_001(String shinseiKanriRenban);
    /**
     * 小学校名より、学校コード取得
     * @param gakkoMei
     * @return 学校コード
     */
    List<String> selectGKBTSHOGAKKO_002(String gakkoMei);
    /**
     * 中学校名より、学校コード取得
     * @param gakkoMei
     * @return 学校コード
     */
    List<String> selectGKBTCHUGAKKO_002(String gakkoMei);
// 2024/06/07 zczl.wangj Add end
    
// 2024/06/03 ZCZL.wangdi Add Start GKB_0.3.000.000:新WizLIFE2次開発
    /**
     * 学齢簿情報を取得する
     * @param map
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUREIBO_009(Map<String, Object> map);
    /**
     * 受パラメータ.宛名基本リストを用いて宛名基本から宛名情報を取得する
     * @param kojinNoList 宛名番号リスト
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGABTATENAKIHON_010(Map<String, Object> param);
    
    /**
     * 帳票選択情報の取得
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTTSUCHISHOKANRI_011();

    /**
     * 保護者一覧取得
     * @param kojinNo 宛名番号
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGABTATENAKIHON_012(String kojinNo);

    /**
     * 通知書条件テーブルから情報取得
     * @param paramMap
     * @return Map<String, Object> 
     */
    public Map<String, Object> selectGKBTTSUCHISHOJKN_013(Map<String, Object> paramMap);
    /**
     * 仮更新者・確認更新画面から遷移した際の処理
     * @param kojinNo 宛名番号
     * @return Map<String, Object> 
     */
    public Map<String, Object> selectGABTATENAKIHON_014(Long kojinNo);
    
    /**
     * 通知文面設定テーブルから情報取得
     * @param chohyoKbn
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTTSUCHIBUNMEN_015(int chohyoKbn);
    
    /**
     * 帳票発行履歴作成
     * @param paramMap
     * @return 処理結果（０：正常終了、1：異常終了）
     */
    public int selectGKAFKHAKKOR_016(Map<String, Object> paramMap);
    /**
     * 小学校名マスタから情報取得
     * @param tennyumaeGakoCd 転入前学校区分
     * @return Map<String, Object>
     */
    public Map<String, Object> selectGKBTSHOGAKKO_017(int tennyumaeGakoCd);
    /**
     * 中学校名マスタから情報取得
     * @param tennyumaeGakoCd 転入前学校区分
     * @return Map<String, Object>
     */
    public Map<String, Object> selectGKBTCHUGAKKO_018(int tennyumaeGakoCd);
    /**
     * 盲聾養護学校名マスタから情報取得
     * @param tennyumaeGakoCd 転入前学校区分
     * @return Map<String, Object>
     */
    public Map<String, Object> selectGKBTYOGOGAKKO_019(int tennyumaeGakoCd);
    /**
     * 区域外学校名マスタから情報取得
     * @param tennyumaeGakoCd 転入前学校区分
     * @return Map<String, Object>
     */
    public Map<String, Object> selectGKBTKUIKIGAI_020(int tennyumaeGakoCd);
    /**
     * 国・私立学校名マスタから情報取得
     * @param tennyumaeGakoCd 転入前学校区分
     * @return Map<String, Object>
     */
    public Map<String, Object> selectGKBTKUNISIRITSUGAKKO_021(int tennyumaeGakoCd);
    
    /**
     * 学年を用いて学年マスタからレコードを取得する
     * @param gakunenCd 学年
     * @return Map<String, Object>
     */
    public Map<String, Object> selectGKBTGAKUNEN_022(int gakunenCd);
    
    /**
     * 宛名情報を取得する
     * @param kojinNo
     * @return
     */
    public Map<String, Object> selectGABTATENAKIHON_023(String kojinNo);
    /**
     * 就学履歴情報を取得する
     * @param paramMap
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTSHUGAKURIREKI_024(Map<String, Object> paramMap);
    /**
     * 更新ログテーブルの件数を取得
     * @param paramMap
     * @return 件数
     */
    public int selectGKBTKOSHINLOG_025(Map<String, Object> param);

    /**
     * 宛名番号リストの宛名番号を用いて、生年月日、履歴番号を取得
     * @param kojinNo
     * @return Map<String, Object>
     */
    public Map<String, Object> selectGABTATENAKIHON_027(String kojinNo);
    /**
     * 年齢取得
     * @param param
     * @return 年齢
     */
    public Map<String, Object> funKKAPK0020_FAGEGET(Map<String, Object> param);
    /**
     * 小学校区コード、中学校区コードを取得
     * @param param
     * @return
     */
    public Map<String, Object> selectGKBTGAKUREIBO_028(Map<String, Object> param);
    
    /**
     * 共通関数の学校コード取得
     * @param gakoParam
     */
    public void selectGKBFKGCGET_029(Map<String, Object> gakoParam);
    
    /**
     * 対象児童の世帯員を取得する
     * @param kojinNo 宛名番号
     * @return
     */
    public ArrayList<Map<String, Object>> selectJIBTJUKIIDO_030(String kojinNo);
// 2024/06/03 ZCZL.wangdi Add End

    
//2024/06/11 ZCZL.xuhongyu Add start GKB_0.3.000.000:新WizLIFE2次開発 
    /**
     * 学年履歴取得
     * @param param
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUNENRIREKI_001(Map<String, Object> param);
    
    /**
     * 学校名取得
     * @param param
     * @return Map<String, Object>
     */
    public Map<String, Object> selectGAKKO_001(Map<String, Object> param);
    
    /**
     * 学年名取得
     * @param param
     * @return Map<String, Object>
     */
    public Map<String, Object> selectGKBTGAKUNEN_002(Map<String, Object> param);
    
    /**
     * 学級名取得
     * @param param
     * @return Map<String, Object>
     */
    public Map<String, Object> selectGKBTMSGAKUKYUCD_002(Map<String, Object> param);
    
    /**
     * 学級区分取得
     * @param param
     * @return Map<String, Object>
     */
    public Map<String, Object> selectKKATCD_001(Map<String, Object> param);
    
    /**
     * 学齢簿照会 学齢簿履歴取得
     * @param param
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUREIBO_010(Map<String, Object> param);
    
    /**
     * 学齢簿異動 学齢簿履歴取得
     * @param param
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUREIBO_011(Map<String, Object> param);
    
    /**
     * 学年履歴取得
     * @param param
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUNENRIREKI_002(Map<String, Object> param);
//2024/06/11 ZCZL.xuhongyu Add end
// 2024/06/07 zczl.gengming Add start GKB_0.3.000.000:新WizLIFE2次開発
    /**
     * 就学変更履歴情報の取得
     * @param String
     * @return ArrayList<GakureiboShokaiHistoryData>
     */
    public ArrayList<GakureiboShokaiHistoryData> selectGKBTSHUGAKURIREKI_001(String kojin_no);
    /**
     * 就学変更履歴情報の取得
     * @param String
     * @return ArrayList<GakureiboShokaiHistoryData>
     */
    public GakureiboShokaiHistoryData selectGKBTSHUGAKURIREKI_002(String kojin_no);

//2025/05/27 ZCZL.DY Update 1.0.006.000:GK_QA13923(16522)_二次対応依頼_就学指定校を修正
//    /**
//     * 学校コード情報の取得
//     * @param GabtatenakihonData
//     * @return String
//     */
//    public List<String> selectGAKKOCODE_001(GabtatenakihonData gabtatenakihonData);
    /**
     * 就学指定校の取得
     * @param gabtatenakihonData GabtatenakihonData
     * @return Map
     */
    public List<Map<String, Object>> selectGABTGYOSEIJOHOJKN_001(GabtatenakihonData gabtatenakihonData);
//2025/05/27 ZCZL.DY Update end

    /**
     * 宛名基本情報の取得
     * @param String
     * @return GabtatenakihonData
     */
    public GabtatenakihonData selectGABTATENAKIHON_002(String kojinNo);
// 2024/06/07 zczl.gengming Add end

//2025/10/01 CTC.GL UPDATE START 1.0.107.001:GKB_21701対応
    public Integer selectGKBTGAKUREIBO_029(String kojinNo);
    
    public ArrayList<Map<String, Object>> selectGABTATENAKIHON_004(String kojinNo);
    
    public ArrayList<Map<String, Object>> selectGABTATENAKIHON_005(String kojinNo);
//2025/10/01 CTC.GL UPDATE END
// 2025/12/16 ZCZL.chengjx Add 1.0.404.000:新WizLIFE保守対応 QA23166
    public GkbtgakureiboData selectGKBTGAKUREIBO_006(String kojinNo);
}