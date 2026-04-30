/*
 * @(#)JIB007S001_GetGksJknService.java
 *
 * Copyright (c) 2022 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.jib0000.domain.service.jib0070;

import java.util.ArrayList;

import javax.inject.Inject;

import org.springframework.stereotype.Service;

import jp.co.jip.jib000.jib0070.dao.dto.JIB007S001_GyoseiKihonSelectJoken;
import jp.co.jip.jib000.service.jib000.JIB000_GetGyoseijohoListService;
import jp.co.jip.jib000.service.jib000.io.JIB000_GetGyoseijohoListInBean;
import jp.co.jip.jib000.service.jib000.io.JIB000_GetGyoseijohoListOutBean;
import jp.co.jip.jib000.service.jib0070.io.JIB007S001_GksJknOutBean;
import jp.co.jip.jib0000.domain.jib0070.dao.JIB007S001_GksJokenDao;
import jp.co.jip.jib0000.domain.service.jib0070.io.JIB007S001_GetGksJknInBean;
import jp.co.jip.wizlife.fw.bean.view.Result;

/**
 * タイトル: JIB007S001_GetGksJknService
 * 
 * @author zczl.xieshun
 * @version JIB_0.2.000.000 2022/05/26
 */

@Service
public class JIB007S001_GetGksJknService {

    @Inject
    private JIB007S001_GksJokenDao gksJokenDao;
    @Inject
    JIB000_GetGyoseijohoListService getGyoseijohoListService;

    public JIB007S001_GetGksJknService() {
    }

    public JIB007S001_GksJknOutBean perform(JIB007S001_GetGksJknInBean inBean) {

        JIB007S001_GksJknOutBean outBean = new JIB007S001_GksJknOutBean();
        Result result = new Result();

        JIB007S001_GyoseiKihonSelectJoken jokenInfo = null;

        ArrayList sortList = new ArrayList();
        ArrayList breakList = new ArrayList();
        ArrayList bikoList = new ArrayList();
        ArrayList gyoseikuList = new ArrayList();
        ArrayList hanList = new ArrayList();
        ArrayList chikuList = new ArrayList();
        ArrayList shogakkokuList = new ArrayList();
        ArrayList kyujichiList = new ArrayList();

        try {

            try {
                String shokuinKojinNo = inBean.getShokuinKojinNo();
                jokenInfo = gksJokenDao.getJoken(shokuinKojinNo ,inBean.getRireki_renban());
            } catch (Exception e) {
                result.setStatus( -1); // 取得失敗
                result.setSummary("条件の取得に失敗しました");
                throw e;
            }

            try {
                sortList = gksJokenDao.getKomokuList(1);
                breakList = gksJokenDao.getKomokuList(2);
                bikoList = gksJokenDao.getKomokuList(3);
            } catch (Exception e) {
                result.setStatus( -1); // 取得失敗
                result.setSummary("項目名情報の取得に失敗しました");
                throw e;
            }

            Result kyotuResult = null;

            try {
                // 1:地区、2:行政区、3:隣保班
                int sdCode = inBean.getSanteidantaiCode();
                JIB000_GetGyoseijohoListInBean kyotuInBean = new JIB000_GetGyoseijohoListInBean();
                JIB000_GetGyoseijohoListOutBean kyotuOutBean = new JIB000_GetGyoseijohoListOutBean();
                kyotuInBean.setSanteidantai_cd(sdCode);
                kyotuInBean.setKensaku_kana(new String());
                kyotuInBean.setGyosei_joho_kbn(1);
                kyotuOutBean = getGyoseijohoListService.perform(kyotuInBean);
                chikuList = kyotuOutBean.getGyoseijohoList();
                kyotuResult = kyotuOutBean.getResult();
                if (kyotuResult.getStatus()!=0) {
                    throw new Exception();
                }
                kyotuInBean.setSanteidantai_cd(sdCode);
                kyotuInBean.setKensaku_kana(new String());
                kyotuInBean.setGyosei_joho_kbn(2);
                kyotuOutBean = getGyoseijohoListService.perform(kyotuInBean);
                gyoseikuList = kyotuOutBean.getGyoseijohoList();
                kyotuResult = kyotuOutBean.getResult();
                if (kyotuResult.getStatus()!=0) {
                    throw new Exception();
                }
                kyotuInBean.setSanteidantai_cd(sdCode);
                kyotuInBean.setKensaku_kana(new String());
                kyotuInBean.setGyosei_joho_kbn(3);
                kyotuOutBean = getGyoseijohoListService.perform(kyotuInBean);
                hanList = kyotuOutBean.getGyoseijohoList();
                kyotuResult = kyotuOutBean.getResult();
                if (kyotuResult.getStatus()!=0) {
                    throw new Exception();
                }
                 kyotuInBean.setSanteidantai_cd(sdCode);
                 kyotuInBean.setKensaku_kana(new String());
                 kyotuInBean.setGyosei_joho_kbn(4);
                 kyotuOutBean = getGyoseijohoListService.perform(kyotuInBean);
                 shogakkokuList = kyotuOutBean.getGyoseijohoList();
                 kyotuResult = kyotuOutBean.getResult();
                 if (kyotuResult.getStatus()!=0) {
                     throw new Exception();
                 }
            } catch (Exception e) {
                if (kyotuResult==null) {
                    result.setStatus( -1); // 取得失敗
                    result.setSummary("行政情報取得に失敗しました");
                } else {
                    result = kyotuResult;
                }
                throw e;
            }

        } catch(Exception e) {
            e.printStackTrace();
            result.setCount(0);
            result.setStatus(-1);  //異常終了
            String summary = result.getSummary();
            if (summary.equals("") || summary==null) {
                result.setSummary("エラーが発生しました");
            }
            result.setDescription(e.getLocalizedMessage());
        } finally {
            outBean.setGksJoken(jokenInfo);
            outBean.setSortKomokuList(sortList);
            outBean.setBreakKomokuList(breakList);
            outBean.setBikoKomokuList(bikoList);
            outBean.setChikuList(chikuList);
            outBean.setGyoseikuList(gyoseikuList);
            outBean.setHanList(hanList);
            outBean.setShogakkokuList(shogakkokuList);
            outBean.setResult(result);
        }
        return outBean;
    }

}
