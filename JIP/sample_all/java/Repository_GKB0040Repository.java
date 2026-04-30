/*
 * @(#)GKB0040Repository.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb000.common.repository;

import java.util.ArrayList;
import java.util.Map;

import org.springframework.stereotype.Repository;

/**
 * タイトル：GKB0040Repository
 * 
 * @author ZCZL.chengjx
 * @version GKB_0.2.000.000 2023/12/04
 * -----------------------------------------------------------------------
 * 変更履歴
 * 2024/06/06 ZCZL.linan Update GKB_0.3.000.000:新WizLIFE２次開発
 * -----------------------------------------------------------------------
 */
@Repository
public interface GKB0040Repository {

    /**
     * 学年一覧を取得
     * 
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUNEN_001();

    /**
     * 減事由一覧を取得
     * 
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTGENJIYU_002();

    /**
     * 減事由一覧（取込区分＝１）の取得を行います。 ---- GKBTGENJIYU
     * 
     * @param Map<String, Object> map
     */
    public ArrayList<Map<String, Object>> select_GKBTGENJIYU_003();

    /**
     * 異動事由一覧取得を行います。 ---- GABTIDOJIYU
     * 
     * @param Map<String, Object> map
     */
    public ArrayList<Map<String, Object>> select_GABTIDOJIYU_004();

    /**
     * 異動文一覧を取得。 ---- GKBTIDOBUN
     * 
     * @param Map<String, Object> map
     */
    public ArrayList<Map<String, Object>> selectGKBTIDOBUN_005();

    /**
     * 就学免除事由一覧を取得を行います。 ---- GKBTMENJOJIYU
     * 
     * @param Map<String, Object> map
     */
    public ArrayList<Map<String, Object>> select_GKBTMENJOJIYU_006();

    /**
     * 就学援助民生委員情報一覧を取得を行います。 ---- GKBTMINSEIIIN
     * 
     * @param Map<String, Object> map
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> select_GKBTMINSEIIIN_007(Map<String, Object> map);

    /**
     * 就学援助民生委員情報取得。 ---- GKBTMINSEIIIN
     * 
     * @param Map<String, Object> map
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> select_GKBTMINSEIIIN_008(Map<String, Object> map);

    /**
     * 就学援助民生委員情報登録。 ---- GKBTMINSEIIIN
     * 
     * @param Map<String, Object> map
     */
    public void insert_GKBTMINSEIIIN_009(Map<String, Object> map);

    /**
     * 就学援助民生委員情報更新。 ---- GKBTMINSEIIIN
     * 
     * @param Map<String, Object> map
     */
    public void update_GKBTMINSEIIIN_010(Map<String, Object> map);

    /**
     * 就学援助民生委員情報削除。 ---- GKBTMINSEIIIN
     * 
     * @param Map<String, Object> map
     */
    public void delete_GKBTMINSEIIIN_011(Map<String, Object> map);

    /**
     * 小学校一覧を取得 ---- GKBTSHOGAKKO
     * 
     * @return ArrayList<Map<String,Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTSHOGAKKO_022();

    /**
     * 学齢簿を取得 ---- GKBTGAKUREIBO
     * 
     * @param map
     * @return ArrayList<Map<String,Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTGAKUREIBO_023(Map<String, Object> map);

    /**
     * 小学校一覧（取込区分＝１）の取得 ---- EGKBTSHOGAKKO
     * 
     * @return ArrayList<Map<String,Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTSHOGAKKO_024();

    /**
     * 小学校区一覧取得 ---- GABTGYOSEIJOHO
     * 
     * @return ArrayList<Map<String,Object>>
     */
    public ArrayList<Map<String, Object>> selectGABTGYOSEIJOHO_025();

    /**
     * 督促事項一覧取得を行います。 ---- GKBTTOKUSOKU
     * 
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> select_GKBTTOKUSOKU_026();

    /**
     * 通知書条件情報一覧取得を行います。 ---- GKBTTSUCHISHOKANRI
     * 
     * @return ArrayList<Map<String, Object>>
     */

    public ArrayList<Map<String, Object>> select_GKBTTSUCHISHOKANRI_027();

    /**
     * 通知書条件情報の更新を行います。 ---- GKBTTSUCHISHOKANRI
     * 
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> select_GKBTTSUCHISHOKANRI_028(Map<String, Object> paramsMap);

    /**
     * 通知書条件情報の更新を行います。 ---- GKBTTSUCHISHOKANRI
     * 
     */
    public void insert_GKBTTSUCHISHOKANRI_029(Map<String, Object> paramsMap);

    /**
     * 通知書条件情報の更新を行います。 ---- GKBTTSUCHISHOKANRI
     * 
     */
    public void update_GKBTTSUCHISHOKANRI_030(Map<String, Object> paramsMap);

    /**
     * 通知書条件情報の更新を行います。 ---- GKBTTSUCHISHOKANRI
     * 
     */
    public void delete_GKBTTSUCHISHOKANRI_031(Map<String, Object> paramsMap);

    /**
     * 通知書条件情報一覧取得を行います。 ---- GKBTTSUCHISHOKANRISEIJIN
     * 
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTTSUCHISHOKANRISEIJIN_032();

    /**
     * 通知書条件情報の更新を行います。 ---- GKBTTSUCHISHOKANRISEIJIN
     * 
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTTSUCHISHOKANRISEIJIN_033(Map<String, Object> paramsMap);

    /**
     * GKBTTSUCHISHOKANRISEIJINデータ作成 ---- GKBTTSUCHISHOKANRISEIJIN
     * 
     * @return void
     */
    public void insertGKBTTSUCHISHOKANRISEIJIN_034(Map<String, Object> paramsMap);

    /**
     * 更新処理。 ---- GKBTTSUCHISHOKANRISEIJIN
     * 
     * @return void
     */
    public void updateGKBTTSUCHISHOKANRISEIJIN_035(Map<String, Object> paramsMap);

    /**
     * 削除処理。 ---- GKBTTSUCHISHOKANRISEIJIN
     * 
     * @return void
     */
    public void deleteGKBTTSUCHISHOKANRISEIJIN_036(Map<String, Object> paramsMap);

    /**
     * 中学校一覧（取込区分＝１）の取得を行います
     * 
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGKBTCHUGAKKO_037();

    /**
     * 中学校区一覧取得を行います
     * 
     * @return ArrayList<Map<String, Object>>
     */
    public ArrayList<Map<String, Object>> selectGABTGYOSEIJOHO_038();
// 2024/06/06 zczl.linan Update start GKB_rev.0.3.000.000:新WizLIFE２次開発
    /**
     * 就学指定校マスタ一覧を取得。 ---- GKBTMSSHUGAKUSHITEIKOU
     * 
     * @param Map<String, Object> map
     */
    public ArrayList<Map<String, Object>> selectGKBTMSSHUGAKUSHITEIKOU_039(Map<String, Object> paramsMap);
    /**
     * 就学指定校マスタ情報の登録を行います。 ---- GKBTMSSHUGAKUSHITEIKOU
     * 
     */
    public void insertGKBTMSSHUGAKUSHITEIKOU_041(Map<String, Object> paramsMap);

    /**
     * 就学指定校マスタ情報の更新を行います。 ---- GKBTMSSHUGAKUSHITEIKOU
     * 
     */
    public void updateGKBTMSSHUGAKUSHITEIKOU_043(Map<String, Object> paramsMap);
    /**
     * 就学指定校仮マスタ一覧を取得。 ---- GKBTMSSHUGAKUSHITEIKOUKR
     * 
     * @param Map<String, Object> map
     */
    public ArrayList<Map<String, Object>> selectGKBTMSSHUGAKUSHITEIKOUKR_040(Map<String, Object> paramsMap);
    /**
     * 就学指定校仮マスタ情報の登録を行います。 ---- GKBTMSSHUGAKUSHITEIKOUKR
     * 
     */
    public void insertGKBTMSSHUGAKUSHITEIKOUKR_042(Map<String, Object> paramsMap);

    /**
     * 就学指定校仮マスタ情報の更新を行います。 ---- GKBTMSSHUGAKUSHITEIKOUKR
     * 
     */
    public void updateGKBTMSSHUGAKUSHITEIKOUKR_044(Map<String, Object> paramsMap);
    
    /**
     * 登録処理。 ---- KKATCD
     * 
     * @return void
     */
    public void insertKKATCD_045(Map<String, Object> paramsMap);

    /**
     * 更新処理。 ---- KKATCD
     * 
     * @return void
     */
    public void updateKKATCD_046(Map<String, Object> paramsMap);

    /**
     * 削除処理。 ---- KKATCD
     * 
     * @return void
     */
    public void deleteKKATCD_047(Map<String, Object> paramsMap);
    
    /**
     * コード管理情報の取得。 ---- KKATCD
     * 
     * @param Map<String, Object> map
     */
    public ArrayList<Map<String, Object>> selectKKATCD_048(Map<String, Object> paramsMap);

    /**
     * コード管理情報の取得。 ---- KKATCD
     * 
     * @param Map<String, Object> map
     */
    public ArrayList<Map<String, Object>> selectKKATCD_049(Map<String, Object> paramsMap);

    /**
     * 分類選択ドロップリストに設定する情報の取得方法。 ---- KKATCDT
     * 
     * @param Map<String, Object> map
     */
    public ArrayList<Map<String, Object>> selectKKATCDT_050();
    
    /**
     * 就学指定校マスタ情報の削除を行います。 ---- GKBTMSSHUGAKUSHITEIKOU
     * 
     */
    public void updateGKBTMSSHUGAKUSHITEIKOU_045(Map<String, Object> paramsMap);
    
    /**
     * 就学指定校仮マスタ情報の削除を行います。 ---- GKBTMSSHUGAKUSHITEIKOUKR
     * 
     */
    public void updateGKBTMSSHUGAKUSHITEIKOUKR_046(Map<String, Object> paramsMap);
    
    /**
     * 選択学校がすでに登録チェック。 ---- GKBTMSSHUGAKUSHITEIKOU就学指定校マスタ
     * 
     */
    public ArrayList<Map<String, Object>> selectGKBTMSSHUGAKUSHITEIKOU_051(Map<String, Object> paramsMap);
    
    /**
     * 選択学校がすでに登録チェック。 ---- GKBTMSSHUGAKUSHITEIKOUKR就学指定校仮マスタ
     * 
     */
    public ArrayList<Map<String, Object>> selectGKBTMSSHUGAKUSHITEIKOUKR_052(Map<String, Object> paramsMap);
// 2024/06/06 zczl.linan Update end
}