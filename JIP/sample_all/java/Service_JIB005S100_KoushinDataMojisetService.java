/*
 * @(#)JIB005S100_KoushinDataMojisetService.java
 *
 * Copyright (c) 2022 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.jib0000.domain.service.jib0050;

import java.util.ArrayList;

import javax.inject.Inject;

import org.springframework.stereotype.Service;

import jp.co.jip.jib000.util.JIBUtil;
import jp.co.jip.jib0000.domain.jib0050.dao.JIB005S100_KoushinDataMojisetDao;
import jp.co.jip.jib0000.domain.jib0050.dao.dto.JIB005S100_KoushinDataMojisetInfo;
import jp.co.jip.jib0000.domain.service.jib0050.io.JIB005S100_KoushinDataMojisetInBean;
import jp.co.jip.jib0000.domain.service.jib0050.io.JIB005S100_KoushinDataMojisetOutBean;

/**
 * 更新データ文字特定Serviceクラス。
 * 
 * @author zczl.yuchufei
 * @version JIB_0.2.000.000 2022/05/10
 *-------------------------------------------------------------------------
 * 変更履歴
 * 2024/02/20 zczl.dongy Add 0.3.020.100:マージ作業
 *-------------------------------------------------------------------------
 */
@Service
public class JIB005S100_KoushinDataMojisetService {

    @Inject
    private JIB005S100_KoushinDataMojisetDao koushinDataMojisetDao;

    /**
     * 更新データ文字特定DAOを呼び出します
     * 
     * @param 更新データ文字特定のInBeanクラス
     * @return 更新データ文字特定のOutBeanクラス
     */
    public JIB005S100_KoushinDataMojisetOutBean perform(JIB005S100_KoushinDataMojisetInBean koushinDataMojisetInBean) {

        JIB005S100_KoushinDataMojisetOutBean koushinDataMojisetOutBean = new JIB005S100_KoushinDataMojisetOutBean();
        // 明細エリアデータを取得する。
        if ("MEISAI_DATA_KENSAKU".equals(koushinDataMojisetInBean.getShoriKbn())) {
            if ("51_7".equals(koushinDataMojisetInBean.getProcNo())) {
                // 画面明細エリア通知の関連情報「住民票記載事項」
                koushinDataMojisetOutBean
                        .setGamenMeisaiTsutiJoho(koushinDataMojisetDao.getJuminhyo(koushinDataMojisetInBean));
            } else {
                // 画面明細エリア通知の関連情報「本籍照合通知」
                koushinDataMojisetOutBean
                        .setGamenMeisaiTsutiJoho(koushinDataMojisetDao.getHonsekishogo(koushinDataMojisetInBean));
            }
            // 画面明細エリアWIZLIFEの関連情報
            koushinDataMojisetOutBean
                    .setGamenMeisaiWizJoho(koushinDataMojisetDao.getJuki(koushinDataMojisetInBean.getKojinNo()));
            // ヘーダエリアデータを取得する。
        } else if ("HEAD_DATA_KENSAKU".equals(koushinDataMojisetInBean.getShoriKbn())) {
            // 画面外字文字の関連情報
            koushinDataMojisetOutBean.setGamenHeadJoho(
                    koushinDataMojisetDao.getMojihenkanJoho(koushinDataMojisetInBean.getGaijiMojiCd()));
            // データを更新する。
        } else if ("DATA_UPDATE".equals(koushinDataMojisetInBean.getShoriKbn())) {
//2024/02/20 zczl.dongy Add start 0.3.020.100:マージ作業
            ArrayList<JIB005S100_KoushinDataMojisetInfo> koushinData = koushinDataMojisetInBean
                    .getMojihenkanTableUpdateData();
            // 初期表示でWizLIFE文字コードが取得できなかった場合だけチェックを行う。
            if (JIBUtil.isEmpty(koushinData.get(0).getWizlifeCdCheckKbn())) {
                String checkResult = koushinDataMojisetDao.checkUpdate(koushinDataMojisetInBean);
                if (!JIBUtil.isEmpty(checkResult)) {
                    koushinDataMojisetOutBean.setChkKekka(checkResult);
                    return koushinDataMojisetOutBean;
                }
            }
//2024/02/20 zczl.dongy Add end
            koushinDataMojisetDao.doUpdate(koushinDataMojisetInBean);
        }

        return koushinDataMojisetOutBean;
    }
}
