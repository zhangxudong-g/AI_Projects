/*
 * @(#)GKB002S023_GakureiboInitService.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb0000.domain.service.gkb0020;

import java.util.List;
import java.util.Map;

import javax.inject.Inject;

import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.math.NumberUtils;
import org.springframework.stereotype.Service;

import jp.co.jip.gkb000.common.dao.GKB000CommonDao;
import jp.co.jip.gkb000.common.dao.GKB000CommonUtil;
import jp.co.jip.gkb000.common.util.GKBUtil;
import jp.co.jip.gkb000.common.util.KyoikuConstants;
import jp.co.jip.gkb0000.domain.gkb0020.dao.GKB002S021_GakureiboDao;
import jp.co.jip.gkb0000.domain.gkb0020.dao.GKB002S023_SyugakkuHennkouDao;
import jp.co.jip.gkb0000.domain.helper.GabtatenakihonData;
import jp.co.jip.gkb0000.domain.helper.GkbtgakureiboData;
import jp.co.jip.gkb0000.domain.helper.GkbtgakureiboSyuugakuHennkoData;
import jp.co.jip.gkb0000.domain.service.gkb0020.io.GKB002S023_GakureiboInitInBean;
import jp.co.jip.gkb0000.domain.service.gkb0020.io.GKB002S023_GakureiboInitOutBean;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonDao;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonUtil;
import jp.co.jip.wizlife.fw.kka000.dao.param.GetCtInforParam;
import jp.co.jip.wizlife.fw.kka100.dao.KKA100GetCTDao;

/**
 * 学年履歴就学学校変更初期処理サービス
 *
 * @author zczl.gengm
 * @version GKB_0.3.000.000 2024/07/26
 * ------------------------------------------------------------------------------------------------
 * 変更履歴
 * 2024/10/21 zczl.cuicy Update GKB_0.3.000.022:仕様変更
 * 2025/04/27 zczl.zhanghf Update GKB_1.0.003.000:「小学0年」と表示されるため改善
 * 2025/05/27 ZCZL.DY Update 1.0.006.000:GK_QA13923(16522)_二次対応依頼_就学指定校を修正
 * 2025/06/12 ZCZL.DY Update 1.0.009.000:GK_QA16455(16920)_二次対応依頼
 * 2025/10/11 ZCZL.DY Update 1.0.201.000:GKB_教育保守_チケット対応(QA16960)_チェック修正
 * ------------------------------------------------------------------------------------------------
 */
@Service
public class GKB002S023_GakureiboInitService {
    @Inject
    GKB002S021_GakureiboDao gkb002s021_GakureiboDao;
    
    @Inject
    KKA000CommonUtil kka000CommonUtil;
    
    @Inject
    KKA000CommonDao kka000CommonDao;

    @Inject
    GKB000CommonUtil gkb000CommonUtil;

    @Inject
    GKB000CommonDao gkb000CommonDao;
    
    @Inject
    private GKB002S023_SyugakkuHennkouDao gkb002S023_SyugakkuHennkouDao;

    @Inject
    KKA100GetCTDao ciUtilDao;
    
    public GKB002S023_GakureiboInitOutBean perform(GKB002S023_GakureiboInitInBean inBean) {
        GKB002S023_GakureiboInitOutBean out = new GKB002S023_GakureiboInitOutBean();
        // 学齢部基本情報の取得
        GkbtgakureiboData gkbtgakureiboData = inBean.getGkbtgakureiboData();
        // 児童基本情報の取得
        GabtatenakihonData jodoAtenaData = inBean.getJodoAtenaData();
        
        GkbtgakureiboSyuugakuHennkoData view = new GkbtgakureiboSyuugakuHennkoData();
        if(null != gkbtgakureiboData) {
            // 希望就学校情報
            // 学齢簿.就学指定校_小学校
// 2024/10/21 zczl.cuicy Update GKB_0.3.000.022:仕様変更
//          view.setShiteiSyogakoName(gkb000CommonDao.getGakkoName(this.nullToZero(gkbtgakureiboData.getShiteiSyogakoCd()), 1));
// 2025/04/27 zczl.zhanghf Update GKB_1.0.003.000:「小学0年」と表示されるため改善
//          if (StringUtils.isNotEmpty(gkbtgakureiboData.getShiteiSyogakoCd())) view.setShiteiSyogakoName(gkb000CommonDao.getGakkoName(Integer.parseInt(gkbtgakureiboData.getShiteiSyogakoCd()), 1));
            if (StringUtils.isNotEmpty(gkbtgakureiboData.getShiteiSyogakoCd()) && "0".equals(gkbtgakureiboData.getShiteiSyogakoCd())) view.setShiteiSyogakoName(gkb000CommonDao.getGakkoName(Integer.parseInt(gkbtgakureiboData.getShiteiSyogakoCd()), 1));
            // 就学校変更_開始学年_小学校
// 2024/10/21 zczl.cuicy Update Start GKB_0.3.000.022:仕様変更
//          view.setHenkoGakunenSyogakoName(gkb000CommonDao.getGakuNennName(this.nullToZero(gkbtgakureiboData.getHenkoGakunenSyogako()),
//                  this.nullToZero(gkbtgakureiboData.getShiteiSyogakoCd()), 1));
// 2025/04/27 zczl.zhanghf Update GKB_1.0.003.000:「小学0年」と表示されるため改善
//          if (StringUtils.isNotEmpty(gkbtgakureiboData.getShiteiSyogakoCd()) && StringUtils.isNotEmpty(gkbtgakureiboData.getHenkoGakunenSyogako())) {
            if (StringUtils.isNotEmpty(gkbtgakureiboData.getShiteiSyogakoCd()) && StringUtils.isNotEmpty(gkbtgakureiboData.getHenkoGakunenSyogako())  && "0".equals(gkbtgakureiboData.getShiteiSyogakoCd())  && "0".equals(gkbtgakureiboData.getHenkoGakunenSyogako())) {
                String gakuNennName = gkb000CommonDao.getGakuNennName(Integer.parseInt(gkbtgakureiboData.getHenkoGakunenSyogako()), Integer.parseInt(gkbtgakureiboData.getShiteiSyogakoCd()), 1);
                view.setHenkoGakunenSyogakoName(gakuNennName);
            }
// 2024/10/21 zczl.cuicy Update End
            // 希望就学校_小学校
            if (NumberUtils.toInt(gkbtgakureiboData.getKiboTyugakkoCd()) == 0 && NumberUtils.toInt(gkbtgakureiboData.getKiboSyogakkoCd()) > 0) {
                if ("1".equals(gkbtgakureiboData.getKiboGakkoKbnCd()) || "3".equals(gkbtgakureiboData.getKiboGakkoKbnCd())
                        || "4".equals(gkbtgakureiboData.getKiboGakkoKbnCd()) || "5".equals(gkbtgakureiboData.getKiboGakkoKbnCd())) {
                    view.setKiboSyogakkoName(gkb000CommonDao.getGakkoName(this.nullToZero(gkbtgakureiboData.getKiboSyogakkoCd()),
                            Integer.valueOf(gkbtgakureiboData.getKiboGakkoKbnCd())));
                }
            }
            // 希望就学校_受付年月日_小学校
            view.setKiboUketsukeBiSyogakoDsp(this.getDate(this.nullToZero(gkbtgakureiboData.getKiboUketsukeBiSyogako())));
            

            // 学齢簿.就学指定校_中学校
// 2024/10/21 zczl.cuicy Update GKB_0.3.000.022:仕様変更
//          view.setShiteiTyugakoName(gkb000CommonDao.getGakkoName(this.nullToZero(gkbtgakureiboData.getShiteiTyugakoCd()), 2));
// 2025/04/27 zczl.zhanghf Update GKB_1.0.003.000:「小学0年」と表示されるため改善
//          if (StringUtils.isNotEmpty(gkbtgakureiboData.getShiteiTyugakoCd())) view.setShiteiTyugakoName(gkb000CommonDao.getGakkoName(Integer.parseInt(gkbtgakureiboData.getShiteiTyugakoCd()), 2));
            if (StringUtils.isNotEmpty(gkbtgakureiboData.getShiteiTyugakoCd()) && "0".equals(gkbtgakureiboData.getShiteiTyugakoCd())) view.setShiteiTyugakoName(gkb000CommonDao.getGakkoName(Integer.parseInt(gkbtgakureiboData.getShiteiTyugakoCd()), 2));
            // 就学校変更_開始学年_中学校
// 2024/10/21 zczl.cuicy Update Start GKB_0.3.000.022:仕様変更
//          view.setHenkoGakunenTyugakoName(gkb000CommonDao.getGakuNennName(this.nullToZero(gkbtgakureiboData.getHenkoGakunenTyugako()),
//                  this.nullToZero(gkbtgakureiboData.getShiteiTyugakoCd()), 2));
// 2025/04/27 zczl.zhanghf Update GKB_1.0.003.000:「小学0年」と表示されるため改善
//          if (StringUtils.isNotEmpty(gkbtgakureiboData.getShiteiTyugakoCd()) && StringUtils.isNotEmpty(gkbtgakureiboData.getHenkoGakunenTyugako())) {
            if (StringUtils.isNotEmpty(gkbtgakureiboData.getShiteiTyugakoCd()) && StringUtils.isNotEmpty(gkbtgakureiboData.getHenkoGakunenTyugako()) && "0".equals(gkbtgakureiboData.getShiteiTyugakoCd()) && "0".equals(gkbtgakureiboData.getHenkoGakunenTyugako())) {
                String gakuNennName = gkb000CommonDao.getGakuNennName(Integer.parseInt(gkbtgakureiboData.getHenkoGakunenTyugako()), Integer.parseInt(gkbtgakureiboData.getShiteiTyugakoCd()), 2);
                view.setHenkoGakunenTyugakoName(gakuNennName);
            }
// 2024/10/21 zczl.cuicy Update End
            // 希望就学校_中学校
            if (NumberUtils.toInt(gkbtgakureiboData.getKiboTyugakkoCd()) > 0) {
                if ("2".equals(gkbtgakureiboData.getKiboGakkoKbnCd()) || "3".equals(gkbtgakureiboData.getKiboGakkoKbnCd())
                        || "4".equals(gkbtgakureiboData.getKiboGakkoKbnCd()) || "5".equals(gkbtgakureiboData.getKiboGakkoKbnCd())) {
                    view.setKiboTyugakkoName(gkb000CommonDao.getGakkoName(this.nullToZero(gkbtgakureiboData.getKiboTyugakkoCd()),
                            Integer.valueOf(gkbtgakureiboData.getKiboGakkoKbnCd())));
                }
            }
            
            // 希望就学校_受付年月日_中学校
            view.setKiboUketsukeBiTyugakoDsp(this.getDate(this.nullToZero(gkbtgakureiboData.getKiboUketsukeBiTyugako())));
            
            // 就学校変更情報
            // 就学校変更_申請年月日
            view.setHenkoShinseiBiDsp(this.getDate(this.nullToZero(gkbtgakureiboData.getHenkoShinseiBi())));
            // 就学校変更_許可年月日
            view.setHenkoKyokaBiDsp(this.getDate(this.nullToZero(gkbtgakureiboData.getHenkoKyokaBi())));
            // 就学校変更_期間
            view.setHenkoKaisiBiDsp(this.getDate(this.nullToZero(gkbtgakureiboData.getHenkoKaisiBi())));
            view.setHenkoSyuryoBiDsp(this.getDate(this.nullToZero(gkbtgakureiboData.getHenkoSyuryoBi())));
            
            
            // 区域外就学
            // 区域外就学_申請年月日
            view.setKuikigaishugakuShinseiBiDsp(this.getDate(this.nullToZero(gkbtgakureiboData.getKuikigaishugakuShinseiBi())));
            // 区域外就学_許可年月日
            view.setKuikigaishugakuKyokaBiDsp(this.getDate(this.nullToZero(gkbtgakureiboData.getKuikigaishugakuKyokaBi())));
            
            // 区域外就学_期間
            view.setKuikigaishugakuKaisiBiDsp(this.getDate(this.nullToZero(gkbtgakureiboData.getKuikigaishugakuKaisiBi())));
            view.setKuikigaishugakuSyuryoBiDsp(this.getDate(this.nullToZero(gkbtgakureiboData.getKuikigaishugakuSyuryoBi())));
//2025/06/12 ZCZL.DY Add start 1.0.009.000:GK_QA16455(16920)_二次対応依頼
            view.setShiteiSyogakoCd(gkbtgakureiboData.getShiteiSyogakoCd());
            view.setShiteiSyogakoName(gkb000CommonDao.getGakkoName(this.nullToZero(gkbtgakureiboData.getShiteiSyogakoCd()), 1));
//2025/10/11 ZCZL.DY Update start 1.0.201.000:GKB_教育保守_チケット対応(QA16960)_チェック修正
//            view.setShiteiTyuGakoCd(gkbtgakureiboData.getShiteiSyogakoCd());
//            view.setShiteiTyugakoName(gkb000CommonDao.getGakkoName(this.nullToZero(gkbtgakureiboData.getShiteiSyogakoCd()), 2));
            view.setShiteiTyuGakoCd(gkbtgakureiboData.getShiteiTyugakoCd());
            view.setShiteiTyugakoName(gkb000CommonDao.getGakkoName(this.nullToZero(gkbtgakureiboData.getShiteiTyugakoCd()), 2));
//2025/10/11 ZCZL.DY Update end
//2025/06/12 ZCZL.DY Add end
        } else {
            GetCtInforParam param = new GetCtInforParam(KyoikuConstants.GYOMU_CODE_GKB, "00GAKKU_KANRI", "0000", 0);
            int result = kka000CommonDao.getCtInfor(param);
            String seigyoKbn = StringUtils.EMPTY;
            if (result > 0) {
                //学区管理区分を取得する。（0=住所、1=行政区）
                seigyoKbn = param.getItem()[0];
            }
//2025/05/27 ZCZL.DY Add start 1.0.006.000:GK_QA13923(16522)_二次対応依頼_就学指定校を修正
            if (StringUtils.isAllEmpty(seigyoKbn)) {
                seigyoKbn = "0";
            }
//2025/05/27 ZCZL.DY Add end
            //宛名基本情報
            GabtatenakihonData atenakihon = new GabtatenakihonData();
            atenakihon = gkb002S023_SyugakkuHennkouDao.getgabtatenakihon(jodoAtenaData.getKojinNo());
            atenakihon.setGakkoKanriKbn(seigyoKbn);
//2025/05/27 ZCZL.DY Update start 1.0.006.000:GK_QA13923(16522)_二次対応依頼_就学指定校を修正
//            atenakihon.setShoChuGakkoFlg("1");
//            String shoGakkoCode = gkb002S023_SyugakkuHennkouDao.getGakkoCode(atenakihon);
//            view.setShiteiSyogakoCd(shoGakkoCode);
//            view.setShiteiSyogakoName(gkb000CommonDao.getGakkoName(this.nullToZero(shoGakkoCode), 1));
//            
//            atenakihon.setShoChuGakkoFlg("2");
//            String chuGakkoCode = gkb002S023_SyugakkuHennkouDao.getGakkoCode(atenakihon);
//            view.setShiteiTyuGakoCd(chuGakkoCode);
//            view.setShiteiTyugakoName(gkb000CommonDao.getGakkoName(this.nullToZero(chuGakkoCode), 2));
            atenakihon.setSanteidantaiCd(inBean.getJodoAtenaData().getSanteidantaiCd());
            List<Map<String, Object>> gakkoList = gkb002S023_SyugakkuHennkouDao.getShiteiGakko(atenakihon);
            if (!gakkoList.isEmpty()) {
                Map<String, Object> shoGakkoCode = gakkoList.get(0);
                view.setShiteiSyogakoCd(GKBUtil.getStringValue(shoGakkoCode, "SYOGAKO_CD"));
                view.setShiteiSyogakoName(GKBUtil.getStringValue(shoGakkoCode, "SYOGAKOMEI"));
                view.setShiteiTyuGakoCd(GKBUtil.getStringValue(shoGakkoCode, "TYUGAKO_CD"));
                view.setShiteiTyugakoName(GKBUtil.getStringValue(shoGakkoCode, "TYUGAKOMEI"));
            }
//2025/05/27 ZCZL.DY Update end
        }
        out.setGkbtgakureiboSyuugakuHennkoData(view);
        return out;
        
    }
    

    /**
     * 表示用日付に変換
     * 
     * @param date
     * @return dateDsp
     */
    private String getDate(int date) {
        String dateDsp = "";

        if (date != 0) {
            // 表示用の日付に変換(X99.99.99の形)
            dateDsp = kka000CommonUtil.format(kka000CommonUtil.getSeireki2Wareki(date), 3, 11, 0);
        }

        return dateDsp;
    }

    /**
     * NullStringを0に変換
     * 
     * @param value
     * @return
     */
    private int nullToZero(String value) {
        int ret = 0;

        if (StringUtils.isNotEmpty(value)) {
            ret = Integer.valueOf(value);
        } else {
            ret = 0;
        }

        return ret;
    }
}
