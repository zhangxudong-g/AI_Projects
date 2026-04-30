/*
 * @(#)JIA100S003_InsertHakkoLogService.java
 *
 * Copyright (c) 2022 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.jia0000.domain.service.jia1000;

import javax.inject.Inject;

import org.springframework.stereotype.Service;

import jp.co.jip.jia0000.domain.jia1000.dao.JIA100S003_ShomeiShoHakkoDao;
import jp.co.jip.jia0000.domain.service.jia1000.io.JIA100S003_InsertHakkoLogInBean;
import jp.co.jip.jia0000.domain.service.jia1000.io.JIA100S003_InsertHakkoLogOutBean;
import jp.co.jip.jia0000.domain.util.JIAConstants;
import jp.co.jip.wizlife.fw.kka100.web.session.GlobalSessionValueFW;

/**
 * <p>発行ログ作成を行うEJBActionクラス。<p>
 * 
 * @author zczl.zhaoyanwu
 * @version JIA_0.2.000.000 2022/05/27
 * -----------------------------------------------------------------------------------------------
 * 変更履歴
 * 2022/09/05 ZCZL.dongy Update JIA_0.2.000.012:印刷修正
 * 2024/04/09 DIS.zhukai Update 0.3.030.000:新WizLIFE２次開発
 * -----------------------------------------------------------------------------------------------
 */
@Service
public class JIA100S003_InsertHakkoLogService {

    @Inject
    JIA100S003_ShomeiShoHakkoDao shomeiShoHakkoDao;

//2024/04/09 DIS.zhukai Add start 0.3.030.000:新WizLIFE２次開発
    /**
     * グローバル変数クラス定義
     */
    @Inject
    private GlobalSessionValueFW globalValueFW;
//2024/04/09 DIS.zhukai Add end

    /**
     * 発行ログ作成を行うEJBを呼び出します。
     *
     * @param inBean イベントクラス（EB06_InsertHakkoLogEvent）
     * @return 処理結果を格納したイベントレスポンス（EB06_InsertHakkoLogEventResponse）
     */
    public JIA100S003_InsertHakkoLogOutBean perform(JIA100S003_InsertHakkoLogInBean inBean) {

        JIA100S003_InsertHakkoLogOutBean outBean = new JIA100S003_InsertHakkoLogOutBean();

        outBean.setFlg(false);
        String reportUri = null;

//2022/09/05 ZCZL.dongy Update start JIA_0.2.000.012:印刷修正
//        reportUri = shomeiShoHakkoDao.printSokujiChohyo(inBean.getShomeishoInfo(), inBean.getKaiseiharaJuminhyoInfo(),
//                inBean.getBikobunInfo(), inBean.getTanmatsu_no(), inBean.getChohyoID());
//2024/04/09 DIS.zhukai Update start 0.3.030.000:新WizLIFE２次開発
//      reportUri = shomeiShoHakkoDao.printSokujiChohyo(inBean);
        if (!inBean.getMojiafurePrintFlg()) {
            reportUri = shomeiShoHakkoDao.printSokujiChohyo(inBean);
            inBean.setReportUri(reportUri);
        } else {
            reportUri = inBean.getReportUri();
        }

        // 文字溢れと未登録外字とカスタマーバーコードエラーを取得する
        int printMonjiGaijiChkFlag = globalValueFW.getPrintMonjiGaijiChkFlag();
        // 文字溢れチェックフラグの取得
        int mojiafureChkFlag = globalValueFW.getMojiafureChkFlag();
        // 文字溢チェックを判断
        boolean mojiafurePrintHantanFlg = false;
        // 印刷プレビュー・印刷を実行初回の場合
        if (!inBean.getMojiafurePrintFlg()) {
            if (printMonjiGaijiChkFlag == 0) {
                mojiafurePrintHantanFlg = true;
            }
        } else {
            // 文字溢れエラーがない または 帳票IDが「異動届出書」の場合
            if (printMonjiGaijiChkFlag == 0 || (printMonjiGaijiChkFlag > 0 && mojiafureChkFlag == 0) || JIAConstants.EBPR_IDOTODOKE_N_CODE.equals(inBean.isChohyo_kbn())) {
                mojiafurePrintHantanFlg = true;
            }
        }
//2024/04/09 DIS.zhukai Update end
//2022/09/05 ZCZL.dongy Update end

        if (reportUri != null) {
          if ("true".equals(inBean.getShomeishoInfo().getBgFlg())) {
//2024/04/09 DIS.zhukai Add 0.3.030.000:新WizLIFE２次開発
              if (mojiafurePrintHantanFlg) {
                shomeiShoHakkoDao.insertBgHakkoLog(inBean.getKojin_no(), inBean.isHonseki_hyoji_kbn(), inBean.isNushi_hyoji_kbn(),
                        inBean.isBiko_hyouji_kbn(), inBean.isJumincd_hyoji_kbn(), inBean.isChohyo_kbn(),
                        inBean.isZenbu_ichibu_kbn(), inBean.getHakkobi(), inBean.getHakko_maisu(), inBean.getShinsei_kbn(),
                        inBean.isHosyu(), inBean.getShokuin_kojin_no(), inBean.getTanmatsu_no(), inBean.getUketukeno(),
                        inBean.getChohyoID(), inBean.getChohyoidx(), inBean.isZairyucdno_hyoji_kbn(),
                        inBean.isZairyushikaku_hyoji_kbn(), inBean.isKokuseki_hyoji_kbn(),
                        inBean.isZairyukikan_hyoji_kbn(), inBean.isManryo_hyoji_kbn(), inBean.iskbn30_45_hyoji_kbn(),
                        inBean.getShinsei_shimei(), inBean.getShomeishoInfo().getKoyoin_hyoji(),
                        inBean.getShomeishoInfo().getNinshobun(), inBean.isKojinNo_hyoji_kbn(),
                        inBean.getSeibetsuHyojiKbn(), inBean.getShomeishoInfo().getChohyo_shubetsu(),
                        inBean.getShomeishoInfo().getRireki_hyoji(), inBean.getKaiseiharaJuminhyoInfo());
//2024/04/09 DIS.zhukai Add 0.3.030.000:新WizLIFE２次開発
                }
            } else {
                boolean isHakkoLog = false;
                int hakkoRireki = inBean.getShomeishoInfo().getHakkoRireki();
                int hakkoRirekiRyoho = inBean.getShomeishoInfo().getHakkoRirekiRyoho();
                // 発行履歴チェックボックス表示なし（発行履歴更新あり）（現行通り）
                if (hakkoRireki == 0)
                    isHakkoLog = true;
                // 発行履歴更新あり
                if (hakkoRireki == 1) {
                    if (hakkoRirekiRyoho == 0) {
                        // 印刷ボタン及び印刷プレビューボタンの両方とも発行履歴を更新する（現行通り）
                        isHakkoLog = true;
                    } else {
                        // 印刷プレビューボタンだけ発行履歴を更新しない（印刷ボタンは発行履歴を更新する）
                        if (inBean.getShomeishoInfo().isPreview()) {
                            isHakkoLog = false;
                        } else {
                            isHakkoLog = true;
                        }
                    }

                }
//2024/04/09 DIS.zhukai Update 0.3.030.000:新WizLIFE２次開発
//                if (isHakkoLog == true) {
                if (isHakkoLog == true && mojiafurePrintHantanFlg) {
                    // 画面「その他証明書発行」で「住民票コード通知書」が選択されている場合、「公用印」を０にセット
                    if (inBean.getShomeishoInfo().getChohyo_shubetsu() == 5) {
                        inBean.getShomeishoInfo().setKoyoin_hyoji(0);
                    }
                    shomeiShoHakkoDao.insertHakkoLog(inBean.getKojin_no(), inBean.isHonseki_hyoji_kbn(), inBean.isNushi_hyoji_kbn(),
                            inBean.isBiko_hyouji_kbn(), inBean.isJumincd_hyoji_kbn(), inBean.isChohyo_kbn(),
                            inBean.isZenbu_ichibu_kbn(), inBean.getHakkobi(), inBean.getHakko_maisu(),
                            inBean.getShinsei_kbn(), inBean.isHosyu(), inBean.getShokuin_kojin_no(),
                            inBean.getTanmatsu_no(), inBean.isZairyucdno_hyoji_kbn(), inBean.isZairyushikaku_hyoji_kbn(),
                            inBean.isKokuseki_hyoji_kbn(), inBean.isZairyukikan_hyoji_kbn(), inBean.isManryo_hyoji_kbn(),
                            inBean.iskbn30_45_hyoji_kbn(), inBean.getShinsei_shimei(),
                            inBean.getShomeishoInfo().getKoyoin_hyoji(), inBean.getShomeishoInfo().getNinshobun(),
                            inBean.isKojinNo_hyoji_kbn(), inBean.getSeibetsuHyojiKbn(),
                            inBean.getShomeishoInfo().getChohyo_shubetsu(), inBean.getShomeishoInfo().getRireki_hyoji(),
                            inBean.getKaiseiharaJuminhyoInfo());
                    outBean.setFlg(true);
                }

            }
        }
        outBean.setResultValue(reportUri);
        return outBean;
    }
}
