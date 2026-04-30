/*
 * @(#)JIB006S002_ShichosonDataShokaiService.java
 *
 * Copyright (c) 2022 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.jib0000.domain.service.jib0060;

import java.util.HashMap;
import java.util.List;
import java.util.Vector;

import javax.inject.Inject;

import org.springframework.stereotype.Service;

import jp.co.jip.jia000.common.dao.JIA000CommonDao;
import jp.co.jip.jia000.common.dao.param.GetCodeListNumsortParam;
import jp.co.jip.jib000.dao.dto.JIB000_Codejoho;
import jp.co.jip.jib0000.domain.jib0060.dao.JIB006S002_ShichosonDataShokaiDao;
import jp.co.jip.jib0000.domain.jib0060.dao.dto.JIB006S002_ShichosonDataShokaiInfo;
import jp.co.jip.jib0000.domain.service.jib0060.io.JIB006S002_ShichosonDataShokaiInBean;
import jp.co.jip.jib0000.domain.service.jib0060.io.JIB006S002_ShichosonDataShokaiOutBean;
import jp.co.jip.wizlife.fw.bean.dto.KKATCDDTO;

/**
 * 市町村通知照会画面用Serviceクラス。
 * 
 * @author zczl.hejl
 * @version JIC_0.2.000.000 2022/04/28
 * -----------------------------------------------------------------------------------------------
 * 変更履歴
 * 2024/01/15 DIS.yangtiantian Update 0.3.000.000:新WizLIFE２次開発
 * -----------------------------------------------------------------------------------------------
 */
@Service
public class JIB006S002_ShichosonDataShokaiService {
    @Inject
    private JIB006S002_ShichosonDataShokaiDao shichosonDataShokaiDao;
//2024/01/15 DIS.yangtiantian Add start 0.3.000.000:新WizLIFE２次開発
    @Inject
    JIA000CommonDao jia000CommonDao;
//2024/01/15 DIS.yangtiantian Add end
    /**
     * 市町村通知照会画面を行うDaoを呼び出します。
     *
     * @param inBean InBeanクラス（JIB006S002_ShichosonDataShokaiInBean）
     * @return 処理結果を格納したOutBean（JIB006S002_ShichosonDataShokaiOutBean）
     */
    public JIB006S002_ShichosonDataShokaiOutBean perform(JIB006S002_ShichosonDataShokaiInBean inBean) {
        JIB006S002_ShichosonDataShokaiOutBean outBean = new JIB006S002_ShichosonDataShokaiOutBean();
        
        String actionKbn = inBean.getActionKbn();
        
        // 初期化
        if ("init".equals(actionKbn)) {
            Vector<JIB000_Codejoho> idojiyuList = shichosonDataShokaiDao.getIdojiyuCmb();
//2024/01/09 DIS.yangtiantian Update start 0.3.000.000:新WizLIFE２次開発
//            Vector<JIB000_Codejoho> shoriJotaiList = shichosonDataShokaiDao.getShoriJotaiCmb("49", "");
            //共通部品「jia000CommonDao.getCodeList_numsort」を呼び出し、数値としての順番で表示する。
            List<KKATCDDTO> kkatcdList = jia000CommonDao.getCodeList_numsort(new GetCodeListNumsortParam("JIB", "049", "0000"));
            //処理状態コンボ
            Vector<JIB000_Codejoho> shoriJotaiList = new Vector<JIB000_Codejoho>();
            //処理状態の設定
            for (int i = 0; i < kkatcdList.size(); i++) {
                KKATCDDTO kkatcd = kkatcdList.get(i);
                JIB000_Codejoho codejoho = new JIB000_Codejoho();
                codejoho.setCode(kkatcd.getAnycode());
                codejoho.setCode_mei(kkatcd.getMeisho());
                shoriJotaiList.add(codejoho);
            }
//2024/01/09 DIS.yangtiantian Update end 
            Vector<JIB006S002_ShichosonDataShokaiInfo> shokaiList = shichosonDataShokaiDao
                    .getShichonsonData(inBean.getSearchJoken());
            outBean.setIdojiyuList(idojiyuList);
            outBean.setShoriJotaiList(shoriJotaiList);
            outBean.setShokaiList(shokaiList);
            
            // システム条件の運用区分
            String sysSoshinKbn = shichosonDataShokaiDao.getSysSoshinKbn();
            outBean.setSysSoshinKbn(sysSoshinKbn);
        }
        // 検索
        else if ("search".equals(actionKbn)) {
            Vector<JIB006S002_ShichosonDataShokaiInfo> shokaiList = shichosonDataShokaiDao
                    .getShichonsonData(inBean.getSearchJoken());
            outBean.setShokaiList(shokaiList);
        }
        // 削除
        else if ("delete".equals(actionKbn)) {
            shichosonDataShokaiDao.deleteShichonsonData(inBean.getData(),
                    inBean.getCommonParam().getUserInfo().getUserId(),
                    inBean.getCommonParam().getUserInfo().getComputerName());
        }
        // 送信
        else if ("send".equals(actionKbn)) {
            HashMap<String, Object> rtnMap = shichosonDataShokaiDao.soshin(inBean.getData(),
                    inBean.getCommonParam().getUserInfo().getUserId(),
                    inBean.getCommonParam().getUserInfo().getComputerName());
            outBean.setSoshinMap(rtnMap);
        }
        
        return outBean;
    }
}
