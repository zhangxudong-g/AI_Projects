/*
 * @(#)GakureiboPrintOutController.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb000.app.gkb000;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Hashtable;
import java.util.List;
import java.util.Vector;

import javax.inject.Inject;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.ModelAndView;

import jp.co.jip.gaa000.common.dao.GAA000CommonDao;
import jp.co.jip.gaa000.common.dao.param.GetDVShikakuParam;
import jp.co.jip.gkb000.app.base.ActionForm;
import jp.co.jip.gkb000.app.base.ActionMapping;
import jp.co.jip.gkb000.app.base.BaseSessionSyncController;
import jp.co.jip.gkb000.app.gkb000.form.ErrorMessageForm;
import jp.co.jip.gkb000.app.gkb000.form.GakureiboPrintOutForm;
import jp.co.jip.gkb000.app.helper.PrintOutView;
import jp.co.jip.gkb000.common.dao.GKB000CommonUtil;
import jp.co.jip.gkb000.common.helper.CodeHelper;
import jp.co.jip.gkb000.common.helper.GakureiboSyokaiView;
import jp.co.jip.gkb000.common.helper.MessageNo;
import jp.co.jip.gkb000.common.helper.ScreenHistory;
import jp.co.jip.gkb000.common.util.CommonFunction;
import jp.co.jip.gkb000.common.util.CommonGakureiboIdo;
import jp.co.jip.gkb000.common.util.KyoikuConstants;
import jp.co.jip.gkb000.common.util.KyoikuMsgConstants;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetMessageService;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageOutBean;
import jp.co.jip.wizlife.ModalDialogUtil.ModalDialogAction;
import jp.co.jip.wizlife.fw.bean.view.ResultFrameInfo;
import jp.co.jip.wizlife.fw.kka000.bean.dto.KKATCT02DTO;
import jp.co.jip.wizlife.fw.kka000.consts.CasConstants;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonDao;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonUtil;
import jp.co.jip.wizlife.fw.kka000.dao.param.GetCtInforParam;
import jp.co.jip.wizlife.fw.kka100.dao.param.GetCTListParam;

/**
 * タイトル: GakureiboPrintOutController 
 * 説明: 帳票発行画面の表示を行うweb層
 * 
 * @author ZCZL.LIUFANGYUAN
 * @version GKB_0.2.000.000 2023/12/15
 * -------------------------------------------------------------------------------------------------
 * 変更履歴
 * 2024/09/10 zczl.cuicy Update GKB_0.3.000.002:新WizLIFE2次開発
 * 2024/11/11 ZCZL.wangyibo Update GKB_0.3.000.020:故障対応
 * -------------------------------------------------------------------------------------------------
 */

@Controller
public class GakureiboPrintOutController extends BaseSessionSyncController {

    @Inject
    GKB000_GetMessageService gkb000_GetMessageService;

    @Inject
    KKA000CommonUtil kka000CommonUtil;

    @Inject
    GAA000CommonDao gaa000CommonDao;

    @Inject
    KKA000CommonDao kka000CommonDao;

    @Inject
    GKB000CommonUtil gkb000CommonUtil;

    private static final String REQUEST_MAPPING_PATH = "/GakureiboPrintOutController";

    /**
     * アクションフォーム自動初期化(固定)
     * 
     * @param request
     * @return
     */
    @ModelAttribute(MODELATTRIBUTE_NAME)
    public ActionForm setUpForm(HttpServletRequest request) {
        return setModelAttribute(request);
    }

    /**
     * 入口
     */
    @RequestMapping(REQUEST_MAPPING_PATH + ".do")
    @Override
    public ModelAndView doAction(@ModelAttribute(MODELATTRIBUTE_NAME) ActionForm form, HttpServletRequest request,
            HttpServletResponse response, ModelAndView mv) throws Exception {
        return this.execute(actionMappingConfigContext.getActionMappingByPath(REQUEST_MAPPING_PATH), form, request,
                response, mv);
    }

    // コンストラクタ
    public GakureiboPrintOutController() {
    }

    // 学齢簿共通関数クラスを定義
    CommonGakureiboIdo g = new CommonGakureiboIdo();

    /**
     * 帳票発行画面表示のメインプロセス
     *
     * @param mapping ActionMapping
     * @param frm     アクションにマッピングされたアクションフォームクラス
     * @param req     HttpServletRequest
     * @param res     HttpServletResponse
     * @throws Exception
     * @return 正常時："success" エラー時："error"
     */

    @Override
    public ModelAndView doMainProcessing(ActionMapping mapping, ActionForm frm, HttpServletRequest req,
            HttpServletResponse res, ModelAndView mv) throws Exception {

        // 処理結果
        String strPrcsAns = sessionSave(frm, req);

        // フレーム情報の設定
        setFrameInfo(strPrcsAns, frm, req, res);

        // 遷移先を返す
        return (mapping.findForward(strPrcsAns)).toModelAndView(mv);
    }

    /**
     * 帳票発行画面表示の後処理を行います。 ここでは、フレーム制御情報をセットしています。
     *
     * @param mapping  ActionMapping
     * @param form     ActionForm
     * @param request  HttpServletRequest
     * @param response HttpServletResponse
     * @throws Exception
     */
    public void doPostProcessing(ActionMapping mapping, ActionForm form, HttpServletRequest request,
            HttpServletResponse response) throws Exception {
    }

    /**
     * 表示用学齢簿情報のセッション保持処理を行います。
     *
     * @param frm アクションにマッピングされたアクションフォームクラス
     * @param req HttpServletRequest
     * @return 処理結果
     * @see CalendarConv
     */
    protected String sessionSave(ActionForm frm, HttpServletRequest req) {

        HttpSession session = req.getSession();
        session.removeAttribute("ErrorMessageForm");
        GakureiboPrintOutForm form = (GakureiboPrintOutForm) frm;
        if (false != form.getBtnContinueDisable()) {
            // エラーチェック
            if (errorCheck(req)) {
                if ("GakureiboSyokai".equals(form.getPageNum())) {
                    return ("GakureiboSyokai");
                }
                if ("GakureiboIdo".equals(form.getPageNum())) {
                    return ("GakureiboIdo");
                }
                if ("true".equals(req.getParameter("refreshFlg"))) {
                    return ("GakureiboPrintOut");
                }
            }
        }

        // 表示用学齢簿情報を取得
        GakureiboSyokaiView giv = (GakureiboSyokaiView) gkb000CommonUtil.getSession(req, "GKB_011_01_VIEW");
        // 初期化
        giv.setPrcsMode(0);
        giv.setChohyoSelectNo(1);
        giv.setTsuchisho(1);
        // 通知書区分
        giv.setReportURI(" ");

        // 照会以外の場合
        if (CommonFunction.PInt(req, "menu_no") != 1 && CommonFunction.PInt(req, "menu_no") != 2
                && CommonFunction.PInt(req, "rdsp") != 1) {

            // 学齢簿画面の内容を学齢簿画面表示情報クラスに設定
            giv = g.setGakureiboPara(req, giv);
        }
        String mitourokugaijiumu = "";
        String processDate = (String) session.getAttribute(KyoikuConstants.CS_INPUT_PROCESSDATE);
        int seirekiDate = kka000CommonUtil.getWareki2Seireki(processDate);

        try {
            String[] result = gaa000CommonDao.getGaijiMitouroku(Long.parseLong(giv.getKojinNo()), "GKB", seirekiDate);
            if (null == result[0]) {
                result[0] = "0";
            }
            // 宛名未登録外字有無の取得
            mitourokugaijiumu = result[0];
        } catch (Exception e) {
            String[] result = new String[1];
        }
        giv.setMitourokugaijiFlg(mitourokugaijiumu);
        // セッションに学齢簿画面表示情報を格納
        gkb000CommonUtil.setSession(req, "GKB_011_01_VIEW", giv);
        // 本名使用制御管理情報をセッションに格納
        gkb000CommonUtil.setSession(req, "GKB_ShimeiJkn", form.getShimeiJkn());

        // 帳票発行情報を初期化します
        session.removeAttribute("GKB_PRINT_OUT_VIEW");

        PrintOutView view = new PrintOutView();
        SimpleDateFormat format = new SimpleDateFormat("yyyyMMdd");

        view.setHassobi(Integer.parseInt(format.format(new Date(System.currentTimeMillis()))));
        gkb000CommonUtil.setSession(req, "GKB_PRINT_OUT_VIEW", view);

        // 教育委員会を設定
        CodeHelper helper3 = null;
        Vector kyouikuList = new Vector();

        GetCtInforParam inforParam = new GetCtInforParam("GKB", "00HAKKO", "0000", 0);
        int cnt = kka000CommonDao.getCtInfor(inforParam);
        String[] hassoNo = inforParam.getItem();
        if (cnt > 0 && StringUtils.isNotEmpty(hassoNo[0]) && hassoNo.length != 0) {
            String hassoNoTemp1 = (String) hassoNo[0];
            String hassoNoTemp2 = (String) hassoNo[1];
            session.setAttribute(KyoikuConstants.HASSONOFLAG, hassoNoTemp1);
            session.setAttribute(KyoikuConstants.NYUGAKUFLAG, hassoNoTemp2);
        } else {
            session.setAttribute(KyoikuConstants.HASSONOFLAG, "0");
            session.setAttribute(KyoikuConstants.NYUGAKUFLAG, "0");
        }
        String[] kyouiku = null;
        // データが存在しない場合は、BLANKフラグ
        boolean kyouikuFlag = false;
        GetCTListParam ctListParam = new GetCTListParam();
        ctListParam.setGyoumuCode("GKB");
        ctListParam.setCtlprmCode("00KYOIKUKAI");
        ctListParam.setGroupCode("0000");
        List<KKATCT02DTO> paramStrArray = kka000CommonDao.getCtList(ctListParam);
        if (paramStrArray != null && paramStrArray.size() != 0) {
            for (int i = 0; i < paramStrArray.size(); i++) {
                KKATCT02DTO kkatct02dto = (KKATCT02DTO) paramStrArray.get(i);
                inforParam = new GetCtInforParam("GKB", "00KYOIKUKAI", "0000", kkatct02dto.getCtlPrmSeq());
                cnt = kka000CommonDao.getCtInfor(inforParam);
                kyouiku = inforParam.getItem();
                if ((cnt > 0 && StringUtils.isNotEmpty(kyouiku[0])) || kyouiku.length != 0) {
                    helper3 = new CodeHelper();
                    helper3.setCode(i);
                    helper3.setCodeMei(kyouiku[0]);
                    kyouikuList.add(helper3);
                    kyouikuFlag = true;
                }
            }

        }
        // データが存在場合
        if (kyouikuFlag) {
            // 教育委員会データセット
            session.setAttribute("kyouikuFlag", "true");
            // 教育委員会を設定
            session.setAttribute("GKB_KyouikuList", kyouikuList);
        } else {
            // データが存在しない場合
            session.setAttribute("kyouikuFlag", "false");
        }
// 2024/09/10 zczl.cuicy Update GKB_0.3.000.002:新WizLIFE2次開発
//      this.createLog(Long.parseLong(giv.getKojinNo()), Integer.parseInt(giv.getJidoSetaiNo()), 2, 11, "帳票発行", req);
        this.createLog(giv.getKojinNo(), giv.getJidoSetaiNo(), 2, 11, "帳票発行", req);
        // 処理結果
        return (KyoikuConstants.CS_FORWARD_SUCCESS);
    }

    /**
     * ログ作成
     * 
     * @param kojinNo
     * @param setaiNo
     * @param dokujiCode
     * @param request
     * @return
     */
// 2024/09/10 zczl.cuicy Update GKB_0.3.000.002:新WizLIFE2次開発
//  private int createLog(long kojinNo, int setaiNo, int shiyoKbn, int naiyoKbn, String dokujiCode,
    private int createLog(String kojinNo, String setaiNo, int shiyoKbn, int naiyoKbn, String dokujiCode,
            HttpServletRequest request) {
        int kekka = 0;

        try {
// 2024/09/10 zczl.cuicy Update GKB_0.3.000.002:新WizLIFE2次開発
//          kka000CommonDao.accessLog("GKB", dokujiCode, naiyoKbn, Long.toString(kojinNo), Integer.toString(setaiNo),
            kka000CommonDao.accessLog("GKB", dokujiCode, naiyoKbn, kojinNo, setaiNo,
                    null, dokujiCode, "00");
        } catch (Exception e) {
            e.printStackTrace();
        }
        return kekka;
    }

    /**
     * エラーチェックの結果を返します。
     *
     * @param req request
     * @return チェック結果 true: エラー false: 異常なし
     */
    protected boolean errorCheck(HttpServletRequest req) {
        HttpSession session = req.getSession();

        // ログイン情報がセッションタイムアウトの場合
        if (gkb000CommonUtil.isTimeOut(req)) {
            // エラー処理
            return (setError(req, KyoikuMsgConstants.EQ_ERROR_TIMEOUT) != "");
        }

        // 表示用学齢簿情報の配列がセッションに格納されていない場合
        if (!gkb000CommonUtil.isSession(req, "GKB_011_01_VIEW")) {
            // エラー処理
            return (setError(req, KyoikuMsgConstants.EQ_GAKUREIBO_01) != "");
        }

        // 表示用学齢簿情報を取得
        GakureiboSyokaiView giv = (GakureiboSyokaiView) gkb000CommonUtil.getSession(req, "GKB_011_01_VIEW");
        // 処理日をセッションに埋め込む
        String shoriBi = (String) session.getAttribute(KyoikuConstants.CS_INPUT_PROCESSDATE);
        // 処理日を西暦変換
        int processDateSreki = this.processDateCnv(shoriBi);

        int gaitoKbn = 0;
        boolean dvGaitoshaFlg = false;
        // 基準日時点のＤＶ規制の該当区分を取得（保護者）
        if (this.lnullToValue(giv.getHogoKojinNo()) > 0) {
// 2024/11/11 ZCZL.wangyibo Update start GKB_0.3.000.020:IT_GKC_00459故障対応
//            gaitoKbn = gaa000CommonDao.getDVShikaku(this.lnullToValue(giv.getHogoKojinNo()), 0, processDateSreki);
            GetDVShikakuParam shikakuParam = gaa000CommonDao.getDVShikaku(this.lnullToValue(giv.getHogoKojinNo()), 0, processDateSreki, "GKB", 3);
            gaitoKbn = shikakuParam.getShikakuKbn();
// 2024/11/11 ZCZL.wangyibo Update end
            if (gaitoKbn > 0) {
                dvGaitoshaFlg = true;
            }
            if (gaitoKbn == 1) {
                setError(req, KyoikuMsgConstants.EQ_WARNING_DV);
            } else if (gaitoKbn == 2) {
                setError(req, KyoikuMsgConstants.EQ_ERROR_DV);
            }
        }
        // 基準日時点のＤＶ規制の該当区分を取得（児童）
        if (this.lnullToValue(giv.getKojinNo()) > 0) {
// 2024/11/11 ZCZL.wangyibo Update start GKB_0.3.000.020:IT_GKC_00459故障対応
//            gaitoKbn = gaa000CommonDao.getDVShikaku(this.lnullToValue(giv.getKojinNo()), 0, processDateSreki);
            GetDVShikakuParam shikakuParam = gaa000CommonDao.getDVShikaku(this.lnullToValue(giv.getHogoKojinNo()), 0, processDateSreki, "GKB", 3);
            gaitoKbn = shikakuParam.getShikakuKbn();
// 2024/11/11 ZCZL.wangyibo Update end
            if (gaitoKbn > 0) {
                dvGaitoshaFlg = true;
            }
            if (gaitoKbn == 1) {
                setError(req, KyoikuMsgConstants.EQ_WARNING_DV);
            } else if (gaitoKbn == 2) {
                setError(req, KyoikuMsgConstants.EQ_ERROR_DV);
            }
        }

        // DV対象者の場合
        if (dvGaitoshaFlg) {
            // エラー処理
            return (true);
        }
        // 異常なし
        return (false);
    }

    /**
     * String型をlong型に変換
     * 
     * @param value
     * @return
     */
    private long lnullToValue(String value) {
        long ret = 0;

        if (value == null) {
            return 0;
        }
        if (value.equals("")) {
            ret = 0;
        } else {
            ret = Long.parseLong(value);
        }

        return ret;
    }

    /**
     * 戻り先、再表示先を設定します。
     *
     * @param forward  処理結果
     * @param frm      アクションにマッピングされたアクションフォームクラス
     * @param request  HttpServletRequest
     * @param response HttpServletResponse
     * @throws Exception
     */
    public void setFrameInfo(String forward, ActionForm frm, HttpServletRequest request, HttpServletResponse response)
            throws Exception {

        // フレーム制御情報をセッションに埋め込む
        ResultFrameInfo frameInfo = new ResultFrameInfo();
        // 画面履歴Helper生成
        ScreenHistory screenhistory = new ScreenHistory();
        // 帳票発行画面情報の取得
        GakureiboPrintOutForm gPrintOutForm = (GakureiboPrintOutForm) frm;

        // 処理に成功した場合
        if (forward.equals(KyoikuConstants.CS_FORWARD_SUCCESS)) {

            // メニュー番号を取得
            int intMenuNo = gkb000CommonUtil.CInt(request.getParameter("menu_no"));
            // 個人番号を取得
            long lngKojinNo = gkb000CommonUtil.CLng(request.getParameter("kojin_no"));

            // 画面タイトル
            screenhistory.setScreenname(KyoikuConstants.CS_GAMEN_CHOHYOHAKKO);
            // 画面履歴情報をセッションから取り出して編集ルーチンで履歴編集する
            ArrayList al = gkb000CommonUtil
                    .ScrHist((ArrayList) gkb000CommonUtil.getSession(request, "GKB_SCREENHISTORY"), screenhistory);
            // 「戻る」と「再表示」処理の追加
            if (intMenuNo == 1) {
                // 「戻る」の戻り先を設定
                frameInfo.setFrameReturnAction(request.getContextPath() + "/GakureiboSyokaiController.do?menu_no="
                        + intMenuNo + "&kojin_no=" + lngKojinNo);
                frameInfo.setFrameReturnTarget("_self");
                frameInfo.setFrameReturnLinktype("link");

                // 「再表示」の表示先を設定
                frameInfo.setFrameRefreshAction(request.getContextPath() + "/GakureiboPrintOutController.do?menu_no="
                        + intMenuNo + "&kojin_no=" + lngKojinNo + "&refreshFlg=" + "true");
                frameInfo.setFrameRefreshTarget("_self");
                frameInfo.setFrameRefreshLinktype("link");
            } else {
                // 「戻る」の戻り先を設定
                if ((KyoikuConstants.CS_GAMEN_TENKO + "（" + KyoikuConstants.CS_GAMEN_TENGAKU + "）")
                        .equals(gkb000CommonUtil.getSession(request, "GKB_011_01_TITLE"))
                        || (KyoikuConstants.CS_GAMEN_TENKO + "（" + KyoikuConstants.CS_GAMEN_TENNYUGAKU + "）")
                                .equals(gkb000CommonUtil.getSession(request, "GKB_011_01_TITLE"))) {
                    frameInfo.setFrameReturnAction(request.getContextPath()
                            + "/GKB002S004GakureiboIdoController.do?menu_no=" + intMenuNo + "&kojin_no=" + lngKojinNo);
                } else {
                    frameInfo.setFrameReturnAction(request.getContextPath() + "/GakureiboSyokaiController.do?menu_no="
                            + intMenuNo + "&kojin_no=" + lngKojinNo);
                }
                frameInfo.setFrameReturnTarget("_self");
                frameInfo.setFrameReturnLinktype("link");

                // 「再表示」の表示先を設定
                frameInfo.setFrameRefreshAction(request.getContextPath() + "/GakureiboPrintOutController.do?menu_no="
                        + intMenuNo + "&kojin_no=" + lngKojinNo + "&rdsp=1");
                frameInfo.setFrameRefreshTarget("_self");
                frameInfo.setFrameRefreshLinktype("link");
            }

            // 画面履歴情報をセッションに埋める
            gkb000CommonUtil.setSession(request, "GKB_SCREENHISTORY", al);
            // 画面に表示する履歴文字列をセッションに埋める
            gkb000CommonUtil.setSession(request, "GKB_DSPRIREKI", gkb000CommonUtil.dspHist(al));
            // フレーム情報をセッションに埋める
            gkb000CommonUtil.setSession(request, CasConstants.CAS_FRAME_INFO, frameInfo);
            // 処理に失敗した場合
        } else {
            // 戻るボタンは使用不可
            frameInfo.setFrameReturnAction("");
            // 再表示も不可
            frameInfo.setFrameRefreshAction("");

            // フレーム情報をセッションに埋める
            gkb000CommonUtil.setSession(request, CasConstants.CAS_FRAME_INFO, frameInfo);
        }

    }

    /**
     * 処理日の西暦変換を行います
     * 
     * @param processDate 処理日
     * @return 西暦日付
     */
    protected int processDateCnv(String processDate) {
        int seirekiDate = kka000CommonUtil.getWareki2Seireki(processDate); // 処理日を西暦変換
        return seirekiDate;
    }

    /**
     * エラー処理を行います。
     *
     * @param req        HttpServletRequest
     * @param intErrorNo エラー番号
     * @return "error"
     * @see jp.co.rkkcs.framework.helper.UpdateInfo
     */
    public String setError(HttpServletRequest req, int intErrorNo) {

        ArrayList list = new ArrayList();
        list.add(new MessageNo(intErrorNo));
        GKB000_GetMessageInBean inBean = new GKB000_GetMessageInBean();
        inBean.setMessageNoList(list);

        try {
            GKB000_GetMessageOutBean res = gkb000_GetMessageService.perform(inBean);
            ErrorMessageForm errform = new ErrorMessageForm();
            errform.setErrorList(res.getErrors());
            errform.setWarningList(res.getWarnings());
            ModalDialogAction action = new ModalDialogAction();
            action.setAsynchronous(false);
            Hashtable params = new Hashtable();
            params.put("menu_no", String.valueOf(gkb000CommonUtil.CInt(req.getParameter("menu_no"))));
            params.put("kojin_no", String.valueOf(gkb000CommonUtil.CInt(req.getParameter("kojin_no"))));
            action.setParameters(params);
            errform.setModalNextAction(action);
            setModelMessage(errform, req);
        } catch (Exception ex) {
            ex.printStackTrace();
        }
        return KyoikuConstants.CS_FORWARD_ERROR;
    }

}
