/*
 * @(#)GKB004S011SetZokugaraController.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb0200.app.gkb0040;

import java.util.ArrayList;
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

import jp.co.jip.gkb000.app.base.ActionForm;
import jp.co.jip.gkb000.app.base.ActionMapping;
import jp.co.jip.gkb000.app.base.BaseSessionSyncController;
import jp.co.jip.gkb000.app.gkb000.form.ErrorMessageForm;
import jp.co.jip.gkb000.app.helper.PageView;
import jp.co.jip.gkb000.app.helper.ZokugaraListView;
import jp.co.jip.gkb000.app.helper.ZokugaraParaView;
import jp.co.jip.gkb000.common.dao.GKB000CommonUtil;
import jp.co.jip.gkb000.common.helper.JokenItem;
import jp.co.jip.gkb000.common.helper.KyoikuLoginInfo;
import jp.co.jip.gkb000.common.helper.MessageNo;
import jp.co.jip.gkb000.common.helper.ZokugaraList;
import jp.co.jip.gkb000.common.util.KyoikuConstants;
import jp.co.jip.gkb000.common.util.KyoikuMsgConstants;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetMessageService;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageOutBean;
import jp.co.jip.gkb000.service.gkb0040.GKB004S011_GetZokugaraListService;
import jp.co.jip.gkb000.service.gkb0040.io.GKB004S011_GetZokugaraListInBean;
import jp.co.jip.gkb000.service.gkb0040.io.GKB004S011_GetZokugaraListOutBean;
import jp.co.jip.gkb0200.app.gkb0040.form.GKB004S011SetZokugaraForm;
import jp.co.jip.gkb0200.domain.service.gkb0040.GKB004S011_SetZokugaraService;
import jp.co.jip.gkb0200.domain.service.gkb0040.io.GKB004S011_SetZokugaraInBean;
import jp.co.jip.gkb0200.domain.service.gkb0040.io.GKB004S011_SetZokugaraOutBean;
import jp.co.jip.wizlife.fw.bean.view.Result;
import jp.co.jip.wizlife.fw.bean.view.ResultFrameInfo;
import jp.co.jip.wizlife.fw.kka000.consts.CasConstants;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonDao;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonUtil;
import jp.co.jip.wizlife.fw.kka000.dao.dto.UpdateInfo;

/**
 * 続柄情報更新のController
 * 
 * @author ZCZL.zhangjiawen
 * @version GKB_0.2.000.000 2023/12/18
 * -----------------------------------------------------------------------------------------------------------------------------------
 * 変更履歴
 * 2024/07/31 zczl.cuicy Add GKB_0.3.000.002:新WizLIFE2次開発
 * -----------------------------------------------------------------------------------------------------------------------------------
 */
@Controller
public class GKB004S011SetZokugaraController extends BaseSessionSyncController {

    private static final String REQUEST_MAPPING_PATH = "/GKB004S011SetZokugaraController";

    @Inject
    GKB004S011_SetZokugaraService gKB004S011_SetZokugaraService;

    @Inject
    GKB004S011_GetZokugaraListService gKB004S011_GetZokugaraListService;

    @Inject
    GKB000_GetMessageService gKB000_GetMessageService;

    @Inject
    KKA000CommonUtil kka000CommonUtil;

    @Inject
    GKB000CommonUtil gkb000CommonUtil;
// 2024/07/31 zczl.cuicy Add GKB_0.3.000.002: 新WizLIFE2次開発
    @Inject
    private KKA000CommonDao kka000CommonDao;

    public GKB004S011SetZokugaraController() {
    }

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

    /**
     * 続柄情報更新のメインプロセス
     * 
     * @param mapping  ActionMapping
     * @param form     SetZokugaraアクションにマッピングされたアクションフォームクラス(SetZokugaraActionForm)
     * @param request  HttpServletRequest
     * @param response HttpServletResponse
     * @throws Exception
     * @return 正常時："success" エラー時："error"
     */
    public ModelAndView doMainProcessing(ActionMapping mapping, ActionForm form, HttpServletRequest request,
            HttpServletResponse response, ModelAndView mv) throws Exception {
        String forward = "";
        String syoriKbn = "";

        HttpSession session = request.getSession();
        KyoikuLoginInfo loginInfo = (KyoikuLoginInfo) session.getAttribute(KyoikuConstants.CS_LOGIN_INFO);
        if (loginInfo == null) {
            // セッションタイムアウト
            sysError(request, KyoikuMsgConstants.EQ_ERROR_TIMEOUT);
            forward = KyoikuConstants.CS_FORWARD_ERROR;
            request.setAttribute("actionForward", forward);
            return mapping.findForward(forward).toModelAndView(mv);
        }

        // GKB004S011SetZokugaraFormクラスからパラメータに格納
        GKB004S011SetZokugaraForm modifyForm = (GKB004S011SetZokugaraForm) form;
        syoriKbn = modifyForm.getSyoriKbn();

        // 画面最適化_エラー画面変更
        ZokugaraParaView vZokugaraPara = (ZokugaraParaView) session.getAttribute("GKB_PARA_VIEW");
        vZokugaraPara.setZokugaraCd(modifyForm.getCurrentZokugaraCd());
        vZokugaraPara.setZokugaramei(modifyForm.getCurrentZokugaramei());
        session.setAttribute("GKB_PARA_VIEW", vZokugaraPara);

        // 入力項目チェック
        if (!inputCheck(modifyForm, request)) {
            // 画面最適化_エラー画面変更
            request.setAttribute("errorHassei", "true");
            request.setAttribute("radioValue", modifyForm.getRadioValue());
            request.setAttribute("SelectNextPageValue", String.valueOf(modifyForm.getSelectNextPage()));
            forward = KyoikuConstants.CS_FORWARD_ERROR;
            request.setAttribute("actionForward", forward);
            return mapping.findForward(forward).toModelAndView(mv);
        }

        try {
            // 続柄情報更新Eventクラスを生成
            GKB004S011_SetZokugaraInBean setevent = (GKB004S011_SetZokugaraInBean) createSetEvent(form, request,
                    loginInfo);
            // 続柄情報更新EventResponseクラスより、続柄情報更新データを取得する。
            GKB004S011_SetZokugaraOutBean setres = gKB004S011_SetZokugaraService.perform(setevent);
            Result setresult = setres.getResult();
            if (!setres.isError()) {

                // 続柄一覧選択Eventクラスを生成
                GKB004S011_GetZokugaraListInBean getevent = (GKB004S011_GetZokugaraListInBean) createGetEvent(form,
                        request);
                // 続柄一覧EventResponseクラスより、続柄一覧データを取得する。
                GKB004S011_GetZokugaraListOutBean getres = gKB004S011_GetZokugaraListService.perform(getevent);
                Result getresult = getres.getResult();
                if (getresult.getStatus() == KyoikuConstants.CN_STATUS_OK) {

                    // View をセッションに格納
                    Vector vAllZokugara = createZokugaraListView(getres.getZokugaraVector());
                    session.setAttribute("GKB_ALL_ZOKUGARA", vAllZokugara);
                    // 更新後の一覧画面表示情報取得

                    // 画面最適化_エラー画面変更
                    JokenItem jokenItem = getJokenItem(gkb000CommonUtil.CInt(modifyForm.getCurrentZokugaraCd()),
                            getres.getZokugaraVector());

                    PageView newPg = createPageView(vAllZokugara, jokenItem, getresult);
                    newPg.setUpdateFlag(syoriKbn); // 画面に｢更新しました｣を表示
                    session.setAttribute("GKB_PAGE_VIEW", newPg);

                    if (vAllZokugara.size() <= 10) {
                        session.setAttribute("GKB_ZOKUGARA", vAllZokugara);
                    } else {
                        Vector vZokugara = new Vector();
                        session.setAttribute("GKB_ALL_ZOKUGARA", vAllZokugara);
                        for (int i = 0; i < 10; i++) {
                            vZokugara.add(vAllZokugara.get(i + (newPg.getCurrentPage() - 1) * 10));
                        }
                        session.setAttribute("GKB_ZOKUGARA", vZokugara);
                    }
                    // 追加・削除した項目のある頁を表示させるためコードを置き換える。
                    if (syoriKbn.equals("add") || syoriKbn.equals("delete")) {
                        ZokugaraParaView vPara = new ZokugaraParaView();
                        vPara.setZokugaraCd(String.valueOf(jokenItem.getItemCd()));
                        vPara.setZokugaraKbn(String.valueOf(modifyForm.getCurrentZokugaraKbn()));
                        session.setAttribute("GKB_PARA_VIEW", vPara);
                    }
// 2024/07/31 zczl.cuicy Add Start GKB_0.3.000.002: 新WizLIFE2次開発
                    String screenName = "続柄名（児童生徒との関係）設定";
                    if (1 == modifyForm.getCurrentZokugaraKbn()) screenName = "続柄名（保護者との関係）設定";
                    // 5.設定変更
                    this.kka000CommonDao.accessLog(KyoikuConstants.CS_GYOMU_CODE, screenName, 5, "", "", null, StringUtils.join(screenName, "画面"), "00");
// 2024/07/31 zczl.cuicy Add End
                    forward = KyoikuConstants.CS_FORWARD_SUCCESS;
                }
                // エラー
                else {
                    sysError(request, KyoikuMsgConstants.EQ_KYOTU_01); // 予期せぬエラー);
                    forward = KyoikuConstants.CS_FORWARD_ERROR;

                    // 画面最適化_エラー画面変更
                    request.setAttribute("errorHassei", "true");
                    request.setAttribute("radioValue", modifyForm.getRadioValue());
                    request.setAttribute("SelectNextPageValue", String.valueOf(modifyForm.getSelectNextPage()));
                }
            }
            // EJB層での論理エラー
            else {
                ErrorMessageForm frm = new ErrorMessageForm();
                frm.setErrorList(setres.getErrors());
                frm.setWarningList(setres.getWarnings());
                session.setAttribute("ErrorMessageForm", frm);
                setModelMessage(frm, request);
                forward = KyoikuConstants.CS_FORWARD_ERROR;

                // 画面最適化_エラー画面変更
                request.setAttribute("errorHassei", "true");
                request.setAttribute("radioValue", modifyForm.getRadioValue());
                request.setAttribute("SelectNextPageValue", String.valueOf(modifyForm.getSelectNextPage()));
            }
        } catch (Exception e) {
            e.printStackTrace();
            sysError(request, KyoikuMsgConstants.EQ_KYOTU_01); // 予期せぬエラー);
            forward = KyoikuConstants.CS_FORWARD_ERROR;
        }
        request.setAttribute("actionForward", forward);
        return mapping.findForward(forward).toModelAndView(mv);
    }

    /**
     * 入力項目のチェックを行います
     * 
     * @param form    入力フォーム
     * @param request HTTPリクエスト
     * @return true:正常 false:エラーあり
     */
    public boolean inputCheck(ActionForm form, HttpServletRequest request) {

        ArrayList list = new ArrayList();
        GKB004S011SetZokugaraForm chkForm = (GKB004S011SetZokugaraForm) form;

        // 画面最適化_エラー画面変更
        if (gkb000CommonUtil.CInt(chkForm.getCurrentZokugaraCd()) == 0) {

            list.add(new MessageNo(KyoikuMsgConstants.EQ_ZOKUGARA_01)); // コード未入力
        }
        if ((chkForm.getCurrentZokugaramei() == null) || (chkForm.getCurrentZokugaramei().length() < 1)) {
            list.add(new MessageNo(KyoikuMsgConstants.EQ_ZOKUGARA_02)); // 名称未入力
        }

        if (!list.isEmpty()) {
            GKB000_GetMessageInBean evnt = new GKB000_GetMessageInBean();
            evnt.setMessageNoList(list);
            try {
                GKB000_GetMessageOutBean res = gKB000_GetMessageService.perform(evnt);
                ErrorMessageForm errform = new ErrorMessageForm();
                errform.setErrorList(res.getErrors());
                errform.setWarningList(res.getWarnings());
                setModelMessage(errform, request);
            } catch (Exception ex) {
                ex.printStackTrace();
            }
            return false;
        } else {
            return true;
        }
    }

    /**
     * 続柄情報更新を行うためのイベントクラスを生成します。 イベントクラスには、入力された内容をセットします。
     * 
     * @param form      SetZokugaraアクションにマッピングされたアクションフォームクラス(SetZokugaraActionForm)
     * @param request   HttpServletRequest
     * @param loginInfo KyoikuLoginInfo
     * @return イベントクラス（GKB004S011_SetZokugaraInBean）
     */
    protected GKB004S011_SetZokugaraInBean createSetEvent(ActionForm form, HttpServletRequest request,
            KyoikuLoginInfo loginInfo) {

        String syoriKbn = "";
        int zokugaraCd;
        int zokugaraKbn;
        String zokugaramei = "";

        // GKB004S011SetZokugaraFormクラスからパラメータに格納
        GKB004S011SetZokugaraForm modifyForm = (GKB004S011SetZokugaraForm) form;
        syoriKbn = modifyForm.getSyoriKbn();

        // 画面最適化_エラー画面変更
        zokugaraCd = gkb000CommonUtil.CInt(modifyForm.getCurrentZokugaraCd());

        zokugaraKbn = modifyForm.getCurrentZokugaraKbn();
        zokugaramei = modifyForm.getCurrentZokugaramei();

        GKB004S011_SetZokugaraInBean event = new GKB004S011_SetZokugaraInBean();

        ZokugaraList zokugaraList = new ZokugaraList();
        zokugaraList.setSyoriKbn(syoriKbn);
        zokugaraList.setZokugaraKbn(zokugaraKbn);
        zokugaraList.setZokugaraCd(zokugaraCd);
        zokugaraList.setZokugaramei(zokugaramei);

        event.setZokugaraList(zokugaraList);

        String currentTime = kka000CommonUtil.getCurrentTimeString(); // YYYY/MM/DD HH24:MI:SS の文字列形式
        // 更新情報
        UpdateInfo updInfo = new UpdateInfo();
        updInfo.setUpdateDate((int) kka000CommonUtil.convString2Date(currentTime)); // 更新日
        updInfo.setUpdateTime((int) kka000CommonUtil.convString2Time(currentTime)); // 更新時間
        updInfo.setKojinNo(loginInfo.getUserId()); // 更新ユーザ
        updInfo.setMachineName(loginInfo.getComputerName()); // 端末番号
        event.setUpdateInfo(updInfo);

        return event;
    }

    /**
     * 続柄一覧取得を行うためのイベントクラスを生成します
     * 
     * @param form    SetZokugaraアクションにマッピングされたアクションフォームクラス(SetZokugaraActionForm)
     * @param request HttpServletRequest
     * @return イベントクラス（GetZokugaraListEvent）
     */
    protected GKB004S011_GetZokugaraListInBean createGetEvent(ActionForm form, HttpServletRequest request) {

        GKB004S011SetZokugaraForm frm = (GKB004S011SetZokugaraForm) form;
        ZokugaraList zokugara = new ZokugaraList();
        zokugara.setZokugaraKbn(frm.getCurrentZokugaraKbn());
        GKB004S011_GetZokugaraListInBean event = new GKB004S011_GetZokugaraListInBean();
        event.setZokugaraList(zokugara);
        return event;
    }

    /**
     * 取得した続柄設定情報を表示用のBean配列に変換します
     * 
     * @param ZokugaraData 続柄情報
     * @return 表示用Bean(ZokugaraListView)のVector
     * @see EQ_kyoiku.helper.ZokugaraLIstView
     */
    protected Vector createZokugaraListView(Vector ZokugaraData) {

        Vector ZokugaraVector = new Vector();
        try {
            // 続柄データ（zokugarayListView）を作成し値リストをセット。
            for (int cnt = 0; cnt < ZokugaraData.size(); cnt++) {
                ZokugaraListView SListView = new ZokugaraListView();
                ZokugaraList SList = (ZokugaraList) ZokugaraData.get(cnt);

                SListView.setZokugaraCd(String.valueOf(SList.getZokugaraCd()));
                SListView.setZokugaramei(SList.getZokugaramei());
                ZokugaraVector.add(SListView);
            }

            if ((ZokugaraVector.size() == 0) || (ZokugaraVector.size() % 10 != 0)) {
                // 件数が１０件に満たない場合、ダミーのパターンクラスを作成する
                for (int i = (ZokugaraVector.size() % 10); i < 10; i++) {
                    ZokugaraListView SListView = new ZokugaraListView();
                    SListView.setZokugaraCd(" ");
                    SListView.setZokugaramei(" ");
                    ZokugaraVector.add(SListView);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        return ZokugaraVector;
    }

    /**
     * 続柄設定情報を表示用のBean配列に変換します
     * 
     * @param ZokugaraListView 続柄情報
     * @return 表示用Bean(PageView)のVector
     * @see EQ_kyoiku.helper.PageView
     */
    protected PageView createPageView(Vector ZokugaraListView, JokenItem jokenItem, Result result) {
        int pgCnt; // 総ページ数
        int cpgCnt; // 現ページ
        PageView pgView = new PageView();
        Vector selectOptions = new Vector();

        if (ZokugaraListView.size() % 10 != 0) {
            pgCnt = (int) (ZokugaraListView.size() / 10) + 1;
        } else {
            pgCnt = (int) ZokugaraListView.size() / 10;
        }
        pgView.setPageMax(pgCnt);

        if (jokenItem.getItemNo() % 10 != 0) {
            cpgCnt = (int) (jokenItem.getItemNo() / 10) + 1;
        } else {
            cpgCnt = (int) jokenItem.getItemNo() / 10;
        }
        pgView.setCurrentPage(cpgCnt);

        pgView.setItemCount(result.getCount());
        pgView.setDispFlag("none");

        for (int i = 1; i <= pgCnt; i++) {
            selectOptions.add(String.valueOf(i));
        }

        pgView.setSelectOptions(selectOptions);
        return pgView;
    }

    /**
     * 更新した続柄コードより条件一覧表示情報を取得します
     * 
     * @param zokugaraCd   更新した続柄コード
     * @param ZokugaraData 続柄情報
     * @return JokenItem
     */
    protected JokenItem getJokenItem(int zokugaraCd, Vector ZokugaraData) {

        boolean search = true;
        int itemCd = zokugaraCd;
        int itemNo = 1;
        JokenItem jItem = new JokenItem();

        // コードサーチ : 追加・修正時は更新した項目、削除時は削除した一つ後（最終の場合は一つ前）の項目
        for (int cnt = 0; cnt < ZokugaraData.size(); cnt++) {
            ZokugaraList SList = (ZokugaraList) ZokugaraData.get(cnt);
            if (search) {
                itemCd = SList.getZokugaraCd();
                itemNo = cnt + 1;
                if (zokugaraCd <= SList.getZokugaraCd()) {
                    search = false;
                    break;
                }
            }
        }

        jItem.setItemCd(itemCd); // コード
        jItem.setItemNo(itemNo); // データ番号
        return jItem;
    }

    /**
     * エラー処理
     * 
     * @param request HTTPリクエスト
     * @param msgNo   メッセージ番号
     */
    public void sysError(HttpServletRequest request, int msgNo) {

        ArrayList list = new ArrayList();
        list.add(new MessageNo(msgNo));
        GKB000_GetMessageInBean evnt = new GKB000_GetMessageInBean();
        evnt.setMessageNoList(list);
        try {
            GKB000_GetMessageOutBean res = gKB000_GetMessageService.perform(evnt);
            ErrorMessageForm errform = new ErrorMessageForm();
            errform.setErrorList(res.getErrors());
            errform.setWarningList(res.getWarnings());
            setModelMessage(errform, request);
        } catch (Exception ex) {
            ex.printStackTrace();
        }
        return;
    }

    /**
     * 続柄情報更新の後処理を行います。 ここでは、フレーム制御情報をセットしています。
     * 
     * @param mapping  ActionMapping
     * @param form     ActionForm
     * @param request  HttpServletRequest
     * @param response HttpServletResponse
     * @throws Exception
     * @see jp.co.rkkcs.framework.helper.ResultFrameInfo
     */
    public void doPostProcessing(ActionMapping mapping, ActionForm form, HttpServletRequest request,
            HttpServletResponse response) throws Exception {
        String forWard = (String) request.getAttribute("actionForward");

        // フレーム制御情報をセッションに埋め込む
        ResultFrameInfo frameInfo = new ResultFrameInfo();
        if (forWard == KyoikuConstants.CS_FORWARD_SUCCESS) {
            // 正常
            frameInfo.setFrameReturnAction(request.getContextPath() + "/GKB000S000KyoikuJokenMenuController.do"); // 「戻る」の戻り先
            frameInfo.setFrameReturnTarget("_self");
            frameInfo.setFrameReturnLinktype("link");
            frameInfo.setFrameRefreshAction(request.getContextPath() + "/GKB004S011Controller.do"); // 「再表示」表示先
            frameInfo.setFrameRefreshTarget("_self");
            frameInfo.setFrameRefreshLinktype("link");
        } else {
            // エラー
            // 「再表示」は使用不可
            frameInfo.setFrameReturnAction(request.getContextPath() + "/GKB000S000KyoikuJokenMenuController.do"); // 「戻る」の戻り先
            frameInfo.setFrameReturnTarget("_self");
            frameInfo.setFrameReturnLinktype("link");
            frameInfo.setFrameRefreshAction(request.getContextPath() + "/GKB004S011Controller.do"); // 「再表示」表示先
            frameInfo.setFrameRefreshTarget("_self");
            frameInfo.setFrameRefreshLinktype("link");
        }

        HttpSession session = request.getSession();
        session.setAttribute(CasConstants.CAS_FRAME_INFO, frameInfo);
    }
}
