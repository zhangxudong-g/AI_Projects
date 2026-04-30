/*
 * @(#)GKB000EntityRepository.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb000.common.repository;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import org.springframework.stereotype.Repository;

import jp.co.jip.gkb000.common.entity.GkbtGakunenEntity;
import jp.co.jip.gkb000.common.entity.GkbtGenjiyuEntity;
import jp.co.jip.gkb000.common.entity.GkbtIdobunEntity;
import jp.co.jip.gkb000.common.entity.GkbtKuikigaiEntity;
import jp.co.jip.gkb000.common.entity.GkbtMenjojiyuEntity;
import jp.co.jip.gkb000.common.entity.GkbtSeijinsyaEntity;
import jp.co.jip.gkb000.common.entity.GkbtSyogakoEntity;
import jp.co.jip.gkb000.common.entity.GkbtTokusokuEntity;
import jp.co.jip.gkb000.common.entity.GkbtTyugakoEntity;
import jp.co.jip.gkb000.common.entity.GkbtYogogakoEntity;
import jp.co.jip.gkb000.common.entity.GkbtYuyojiyuEntity;
import jp.co.jip.gkb000.common.entity.GkbtZokugaraEntity;

/**
 * タイトル：GKB000EntityRepository
 * 
 * @author zczl.gongbw
 * @version GKB_0.2.000.000 2023/12/05
 * 
 * ------------------------------------------------------------------------------
 * 変更履歴
 * 2024/06/04 ZCZL.zhaoyan Add GKB_0.3.000.000:新WizLIFE２次開発
 * 2024/06/04 ZCZL.ruanxuan Add GKB_0.3.000.000:新WizLIFE２次開発
 * 2024/06/04 ZCZL.niutong Update GKB_rev.0.3.000.000:新WizLIFE２次開発
 * 2024/06/05 zczl.niutong Add  GKB_rev.0.3.000.000:新WizLIFE２次開発 
 * 2024/06/14 zczl.wanghaonan Update  GKB_0.3.000.000:新WizLIFE２次開発
 * 2025/10/28 ZCZL.dy Add 1.0.204.000:[GKC_就学援助]QA#17003保守対応_追加処理修正
 * ------------------------------------------------------------------------------
 */
@Repository
public interface GKB000EntityRepository {

    // GkbtGakunenEntity
    void insertGKBTGAKUNEN_001(GkbtGakunenEntity record);

    GkbtGakunenEntity selectGKBTGAKUNEN_002(Integer gakunenCd);

    void updateGKBTGAKUNEN_003(GkbtGakunenEntity record);
    
    void deleteGKBTGAKUNEN_004(Integer gakunenCd);
    
    // GkbtSeijinsyaEntity
    GkbtSeijinsyaEntity selectGKBTSEIJINSHA_005(GkbtSeijinsyaEntity record);
    
    void insertGKBTSEIJINSHA_006(GkbtSeijinsyaEntity record);
    
    void updateGKBTSEIJINSHA_007(GkbtSeijinsyaEntity record);

    void deleteGKBTSEIJINSHA_008(GkbtSeijinsyaEntity record);
    
    // GkbtKuikigaiEntity
    void insertGKBTKUIKIGAI_009(GkbtKuikigaiEntity record);
    
    void updateGKBTKUIKIGAI_010(GkbtKuikigaiEntity record);
    
    GkbtKuikigaiEntity selectGKBTKUIKIGAI_011(Integer kuikigaiCd);
// 2024/06/04 ZCZL.zhaoyan Update GKB_0.3.000.000:新WizLIFE２次開発
//    void deleteGKBTKUIKIGAI_012(Integer kuikigaiCd);
    void deleteGKBTKUIKIGAI_012(GkbtKuikigaiEntity record);
    
    // GkbtTyugakoEntity
    void insertGKBTCHUGAKKO_013(GkbtTyugakoEntity record);
    
    GkbtTyugakoEntity selectGKBTCHUGAKKO_014(Integer tyugakoCd);
    
    void updateGKBTCHUGAKKO_015(GkbtTyugakoEntity record);
// 2024/06/14 ZCZL.wanghaonan Update GKB_0.3.000.000:新WizLIFE２次開発
//    void deleteGKBTCHUGAKKO_016(Integer tyugakoCd);
    void deleteGKBTCHUGAKKO_016(GkbtTyugakoEntity record);
    
    // GkbtYogogakoEntity
    void insertGKBTYOGOGAKKO_017(GkbtYogogakoEntity record);

    GkbtYogogakoEntity selectGKBTYOGOGAKKO_018(Integer yogogakoCd);
    
    void updateGKBTYOGOGAKKO_019(GkbtYogogakoEntity record);
//2024/06/04 zczl.niutong Update  GKB_rev.0.3.000.000:新WizLIFE２次開発 
//    void deleteGKBTYOGOGAKKO_020(Integer yogogakoCd);
      void deleteGKBTYOGOGAKKO_020(GkbtYogogakoEntity eqtYogogako);
//2024/06/05 zczl.niutong Add  GKB_rev.0.3.000.000:新WizLIFE２次開発 
      ArrayList<Map<String, Object>>  selectGKBTYOGOGAKKO_050(HashMap<String, Object> param);
    
    // GkbtYuyojiyuEntity
    void insertGKBTYUYOJIYU_021(GkbtYuyojiyuEntity record);
    
    GkbtYuyojiyuEntity selectGKBTYUYOJIYU_022(Integer yuyoJiyuCd);
    
    void updateGKBTYUYOJIYU_023(GkbtYuyojiyuEntity record);

    void deleteGKBTYUYOJIYU_024(Integer yuyoJiyuCd);

    // GkbtZokugaraEntityKey
    void insertGKBTZOKUGARA_025(GkbtZokugaraEntity record);
    
    GkbtZokugaraEntity selectGKBTZOKUGARA_026(GkbtZokugaraEntity record);

    void updateGKBTZOKUGARA_027(GkbtZokugaraEntity record);
    
    void deleteGKBTZOKUGARA_028(GkbtZokugaraEntity record);

    // GkbtGenjiyuEntity
    void insertGKBTGENJIYU_029(GkbtGenjiyuEntity record);
    
    GkbtGenjiyuEntity selectGKBTGENJIYU_030(Integer genJiyuCd);

    void updateGKBTGENJIYU_031(GkbtGenjiyuEntity record);

    void deleteGKBTGENJIYU_032(Integer genJiyuCd);
    
    // GkbtIdobunEntity
    void insertGKBTIDOBUN_033(GkbtIdobunEntity record);
    
    GkbtIdobunEntity selectGKBTIDOBUN_034(Integer idoBunCd);

    void updateGKBTIDOBUN_035(GkbtIdobunEntity record);

    void deleteGKBTIDOBUN_036(Integer idoBunCd);
    
    // GkbtMenjojiyuEntity
    void insertGKBTMENJOJIYU_037(GkbtMenjojiyuEntity record);
    
    GkbtMenjojiyuEntity selectGKBTMENJOJIYU_038(Integer menjoJiyuCd);
    
    void updateGKBTMENJOJIYU_039(GkbtMenjojiyuEntity record);

    void deleteGKBTMENJOJIYU_040(Integer menjoJiyuCd);
    
    // GkbtTokusokuEntity
    void insertGKBTTOKUSOKU_041(GkbtTokusokuEntity record);
    
    GkbtTokusokuEntity selectGKBTTOKUSOKU_042(Integer tokusokuCd);

    void updateGKBTTOKUSOKU_043(GkbtTokusokuEntity record);

    void deleteGKBTTOKUSOKU_044(Integer tokusokuCd);
    
    // GkbtSyogakoEntity
    void insertGKBTSHOGAKKO_045(GkbtSyogakoEntity record);
    
    GkbtSyogakoEntity selectGKBTSHOGAKKO_046(Integer syogakoCd);
    
    void updateGKBTSHOGAKKO_047(GkbtSyogakoEntity record);

    void deleteGKBTSHOGAKKO_048(Integer syogakoCd);
//2024/06/03 ZCZL.ruanxuan Add start GKB_0.3.000.000:新WizLIFE２次開発

    void updateGKBTSHOGAKKO_049(GkbtSyogakoEntity record);
//2024/06/03 ZCZL.ruanxuan Add end
//2024/06/06 ZCZL.zhaoyan Add GKB_0.3.000.000:新WizLIFE２次開発
    ArrayList<Map<String, Object>>  selectGKBTYOGOGAKKO_051(HashMap<String, Object> param);
//2024/06/06 ZCZL.ruanxuan Add GKB_0.3.000.000:新WizLIFE２次開発
    ArrayList<Map<String, Object>>selectGKBTSHOGAKKO_052(HashMap<String, Object> param);
//2024/06/14 ZCZL.wanghaonan Add GKB_0.3.000.000:新WizLIFE２次開発
    ArrayList<Map<String, Object>>  selectGKBTCHUGAKKO_017(HashMap<String, Object> param);

//2025/10/28 ZCZL.dy Add start 1.0.204.000:[GKC_就学援助]QA#17003保守対応_追加処理修正
    /** 入力した小学校コードは論理削除の学校コードチェック */
    public String selectGKBTSHOGAKKO_053(HashMap<String, Object> param);

    /** 入力した中学校コードは論理削除の学校コードチェック */
    public String selectGKBTCHUGAKKO_054(Map<String, Object> param);

    /** 入力した区域外学校コードは論理削除の学校コードチェック */
    public String selectGKBTKUIKIGAI_055(Map<String, Object> param);

    /** 入力した盲聾養護学校コードは論理削除の学校コードチェック */
    public String selectGKBTYOGOGAKKO_056(Map<String, Object> param);

    /** 入力した国・私立学校コードは論理削除の学校コードチェック */
    public String selectGKBTKUNISIRITSUGAKKO_057(Map<String, Object> param);
//2025/10/28 ZCZL.dy Add end
}