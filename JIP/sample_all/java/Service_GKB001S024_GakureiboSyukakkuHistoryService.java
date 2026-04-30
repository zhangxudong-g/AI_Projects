/*
 * @(#)GKB001S024_GakureiboSyukakkuHistoryService.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb0000.domain.service.gkb0010;

import java.util.List;

import javax.inject.Inject;

import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Service;

import jp.co.jip.gkb000.common.util.KyoikuConstants;
import jp.co.jip.gkb0000.domain.gkb0010.dao.GKB001S024_GakureiboSyukakkuHistoryDao;
import jp.co.jip.gkb0000.domain.helper.GakureiboShokaiHistoryData;
import jp.co.jip.gkb0000.domain.helper.GkbtgakureiboData;
import jp.co.jip.gkb0000.domain.repository.GKB0010Repository;
import jp.co.jip.gkb0000.domain.service.gkb0010.io.GKB001S024_GakureiboSyukakkuHistoryInBean;
import jp.co.jip.gkb0000.domain.service.gkb0010.io.GKB001S024_GakureiboSyukakkuHistoryOutBean;

/**
 * 学齢簿情報取得サービス
 * @author zczl.wangj
 * @version GKB_0.3.000.000 2024/06/12
 * ------------------------------------------------------------------------------------------
 * 変更履歴
 * 2024/09/25 zczl.cuicy Update 0.3.000.006:IT_GKB_00151
 * 2025/12/16 ZCZL.chengjx Add 1.0.404.000:新WizLIFE保守対応 QA23166
 * ------------------------------------------------------------------------------------------
 */
@Service
public class GKB001S024_GakureiboSyukakkuHistoryService {


    /** 最新 */
    private static final String NEW = "最新";
    /** 履歴 */
    private static final String RIREKI = "履歴";
    
    private static final String NONE = "なし";
    @Inject
    private GKB001S024_GakureiboSyukakkuHistoryDao gKB001S024_GakureiboSyukakkuHistoryDao;
// 2025/12/16 ZCZL.chengjx Add Start 1.0.404.000:新WizLIFE保守対応 QA23166
    @Inject
    private GKB0010Repository gkb0010Repository;
// 2025/12/16 ZCZL.chengjx Add End
    public GKB001S024_GakureiboSyukakkuHistoryOutBean perform(GKB001S024_GakureiboSyukakkuHistoryInBean inBean) {
        GKB001S024_GakureiboSyukakkuHistoryOutBean res = new GKB001S024_GakureiboSyukakkuHistoryOutBean();
        // 履歴リストを取得
        List<GakureiboShokaiHistoryData> rirekiRenbanList = gKB001S024_GakureiboSyukakkuHistoryDao.getGakureiboShokaiHistoryList(inBean.getKojinNo());
        if (rirekiRenbanList.size() == 0) {
            res.getResult().setStatus(KyoikuConstants.CN_STATUS_NONE);
            res.setRirekiDisp(NONE);
            res.setCount("1");
            res.setTotal("1");
            res.setUe(true);
            res.setShita(true);
// 2025/12/16 ZCZL.chengjx Add Start 1.0.404.000:新WizLIFE保守対応 QA23166
            GkbtgakureiboData gakureiboData = gkb0010Repository.selectGKBTGAKUREIBO_006(inBean.getKojinNo());
            res.setGkbtgakureiboData(gakureiboData);
// 2025/12/16 ZCZL.chengjx Add End
            return res;
        }
        if (rirekiRenbanList.size() == 1) {
            res.setUe(true);
            res.setShita(true);
        }
// 2024/09/25 zczl.cuicy Update Start 0.3.000.006:IT_GKB_00151
//      int pageIndex = inBean.getPageIndex();
        Integer pageIndex = inBean.getPageIndex();
        if (null == pageIndex || pageIndex > rirekiRenbanList.size()) {
            pageIndex = rirekiRenbanList.size();
        }
//      if (0 == pageIndex) {
        if (0 == pageIndex - 1) {
//          // 履歴情報 
//          res.setRirekiDisp(NEW);
// 2024/09/25 zczl.cuicy Update End
            // 上フラグ
            res.setUe(true);
        } else {
// 2024/09/25 zczl.cuicy Update 0.3.000.006:IT_GKB_00151
//          if(rirekiRenbanList.size() == pageIndex + 1) {
            if (rirekiRenbanList.size() == pageIndex) {
                // 下フラグ
                res.setShita(true);
            }
// 2024/09/25 zczl.cuicy Delete 0.3.000.006:IT_GKB_00151
//          // 履歴情報 
//          res.setRirekiDisp(RIREKI);
        }
        // 就学変更履歴情報
// 2024/09/25 zczl.cuicy Update Start 0.3.000.006:IT_GKB_00151
//      GakureiboShokaiHistoryData historyData = rirekiRenbanList.get(pageIndex);
        GakureiboShokaiHistoryData historyData = rirekiRenbanList.get(rirekiRenbanList.size() - pageIndex);
        if (StringUtils.equals("0", historyData.getSaishinFlg())) {
            // 履歴情報 
            res.setRirekiDisp(NEW);
        } else {
            // 履歴情報 
            res.setRirekiDisp(RIREKI);
        }
// 2024/09/25 zczl.cuicy Update End
        res.setGakureiboShokaiHistoryData(historyData);
// 2025/12/16 ZCZL.chengjx Add Start 1.0.404.000:新WizLIFE保守対応 QA23166
        GkbtgakureiboData gakureiboData = gkb0010Repository.selectGKBTGAKUREIBO_006(inBean.getKojinNo());
        res.setGkbtgakureiboData(gakureiboData);
// 2025/12/16 ZCZL.chengjx Add End
        // ページ数
// 2024/09/25 zczl.cuicy Update 0.3.000.006:IT_GKB_00151
//      res.setCount(String.valueOf(pageIndex + 1));
        res.setCount(String.valueOf(pageIndex));
        // 総ページ数
        res.setTotal(String.valueOf(rirekiRenbanList.size()));
        // ステータス設置
        res.getResult().setStatus(KyoikuConstants.CN_STATUS_OK);
        return res;
    }
    
    
}
