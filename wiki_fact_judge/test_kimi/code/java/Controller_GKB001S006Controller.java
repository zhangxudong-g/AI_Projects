/*
 * @(#)GKB001S006Controller.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb0000.app.gkb0010;

import java.util.ArrayList;
import java.util.Vector;

import javax.inject.Inject;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.lang3.math.NumberUtils;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.ModelAndView;

import jp.co.jip.gkb000.app.base.ActionForm;
import jp.co.jip.gkb000.app.base.ActionMapping;
import jp.co.jip.gkb000.app.base.BaseSessionSyncController;
import jp.co.jip.gkb000.app.gkb000.form.ErrorMessageForm;
import jp.co.jip.gkb000.app.gkb000.form.GakureiboSyokaiForm;
import jp.co.jip.gkb000.app.helper.KuikigaiKanriListView;
import jp.co.jip.gkb000.common.dao.GKB000CommonUtil;
import jp.co.jip.gkb000.common.helper.Gakureibo;
import jp.co.jip.gkb000.common.helper.GakureiboSyokaiView;
import jp.co.jip.gkb000.common.helper.KuikigaiKanriList;
import jp.co.jip.gkb000.common.helper.MessageNo;
import jp.co.jip.gkb000.common.helper.ScreenHistory;
import jp.co.jip.gkb000.common.util.CommonGakureiboSyokai;
import jp.co.jip.gkb000.common.util.KyoikuConstants;
import jp.co.jip.gkb000.common.util.KyoikuMsgConstants;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetGakureiboJohoService;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetKuikigaiService;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetMessageService;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetGakureiboJohoInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetGakureiboJohoOutBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetKuikigaiKanriInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetKuikigaiKanriOutBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageOutBean;
import jp.co.jip.wizlife.fw.bean.view.ResultFrameInfo;
import jp.co.jip.wizlife.fw.kka000.consts.CasConstants;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonUtil;

/**
 * タイトル: GKB001S006Controller
 * 説明: 学齢簿表示を行うweb層Controllerクラス
 * 
 * @author zczl.jiangxiaoxin
 * @version GKB_0.2.000.000 2023/12/18
 */
@Controller
public class GKB001S006Controller extends BaseSessionSyncController {
    @Inject
    GKB000_GetGakureiboJohoService gkb000_GetGakureiboJohoService;

    @Inject
    GKB000_GetMessageService gkb000_GetMessageService;
    
    @Inject
    GKB000_GetKuikigaiService gkb000_GetKuikigaiService;
    
    @Inject
    GKB000CommonUtil gkb000CommonUtil;

    @Inject
    KKA000CommonUtil kka000CommonUtil;

    private static final String REQUEST_MAPPING_PATH = "/GKB001S006Controller";

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
    public GKB001S006Controller() {
    }

    // 学齢簿照会共通関数クラスの定義
    CommonGakureiboSyokai g = new CommonGakureiboSyokai();

    /*************************************************************************************************
     *
     * メイン
     *
     ************************************************************************************************/

    /**
     * 学齢簿のメインプロセス
     *
     * @param mapping ActionMapping
     * @param form    アクションにマッピングされたアクションフォームクラス
     * @param req     HttpServletRequest
     * @param res     HttpServletResponse
     * @throws Exception
     * @return 正常時："success1" or "success2" エラー時："error"
     */
    @Override
    public ModelAndView doMainProcessing(ActionMapping mapping, ActionForm form, HttpServletRequest req,
            HttpServletResponse res, ModelAndView mv) throws Exception {

        // 処理結果
        String strPrcsAns = DivergeProcess(form, req);

        // フレーム情報の設定
        setFrameInfo(strPrcsAns, form, req, res);

        // 遷移先を返す

        return mapping.findForward(strPrcsAns).toModelAndView(mv);

    }

    /**
     * 学校情報一覧表示の後処理を行います。 ここでは、フレーム制御情報をセットしています。
     *
     * @param mapping  ActionMapping
     * @param form     ActionForm
     * @param request  HttpServletRequest
     * @param response HttpServletResponse
     * @throws Exception
     * @see jp.co.rkkcs.framework.helper.ResultFrameInfo
     */
    @Override
    public void doPostProcessing(ActionMapping mapping, ActionForm form, HttpServletRequest request,
            HttpServletResponse response) throws Exception {
    }

    /*************************************************************************************************
     *
     * 処理分岐ルーチン
     *
     ************************************************************************************************/

    /**
     * 学齢簿照会画面イベント処理分岐
     *
     * @param form アクションにマッピングされたアクションフォームクラス
     * @param req  HttpServletRequest
     * @return 正常時："success" エラー時："error"
     */
    protected String DivergeProcess(ActionForm form, HttpServletRequest req) {

        // 処理結果
        String strPrcsAns;
        // 処理番号
        int intPrcsNo;

        // ログイン情報がセッションタイムアウトの場合
        if (gkb000CommonUtil.isTimeOut(req))
            return (setError(req, KyoikuMsgConstants.EQ_ERROR_TIMEOUT));
        // 画面内容を保持しているオブジェクトを設定
        GakureiboSyokaiForm gakureiboSyokaiForm = (GakureiboSyokaiForm) form;
        // アクションフォームの内容が空の場合はオブジェクトを初期化する
        if (gakureiboSyokaiForm == null)
            gakureiboSyokaiForm = new GakureiboSyokaiForm();

        // 処理モードの取得
        intPrcsNo = gakureiboSyokaiForm.getPrcs_no();

        // モードによる分岐
        switch (intPrcsNo) {

        // 初期表示または再表示の場合
        case 0:
            // データ抽出生成処理
            strPrcsAns = createPatternView(form, req);
            // ブロックからの脱出
            break;

        // 前履歴ボタンが押された場合
        case 1:
            // 前履歴データ生成処理
            strPrcsAns = createPatternPageChangeView(form, req, -1);
            // ブロックからの脱出
            break;

        // 次履歴ボタンが押された場合
        case 2:
            // 次履歴データ生成処理
            strPrcsAns = createPatternPageChangeView(form, req, 1);
            // ブロックからの脱出
            break;

        // その他の場合
        default:
            // エラー
            strPrcsAns = KyoikuConstants.CS_FORWARD_ERROR;
        }

        // 遷移先を返す
        return (strPrcsAns);
    }

    /*************************************************************************************************
     *
     * 初期表示
     *
     ************************************************************************************************/

    /**
     * 学齢簿を表示用に編集を行いセッションに格納します。
     *
     * @param form ActionForm
     * @param req  HttpServletRequest
     * @return 処理結果
     * @see jp.co.rkkcs.framework.util.CalendarConv
     */
    protected String createPatternView(ActionForm form, HttpServletRequest req) {

        // 学齢簿の配列の定義
        Vector arrayGakureibo;
        // 学齢簿クラスオブジェクトの定義
        Gakureibo gakureibo = new Gakureibo();
        // 学齢簿表示クラスオブジェクトの定義
        GakureiboSyokaiView gakureiboSyokaiView = new GakureiboSyokaiView();

        // 処理日を取得
        String strProcessDay = (String) gkb000CommonUtil.getSession(req, KyoikuConstants.CS_INPUT_PROCESSDATE);
        // 処理日を西暦に変換
        int intProcessDay = kka000CommonUtil.getWareki2Seireki(strProcessDay);

        // 画面内容を保持しているオブジェクトを設定
        GakureiboSyokaiForm gakureiboSyokaiForm = (GakureiboSyokaiForm) form;
        // アクションフォームの内容が空の場合はオブジェクトを初期化する
        if (gakureiboSyokaiForm == null)
            gakureiboSyokaiForm = new GakureiboSyokaiForm();

        // メニュー番号
        int intMenuNo = gakureiboSyokaiForm.getMenu_no();
        // 個人番号
        long lngKojinNo = gakureiboSyokaiForm.getKojin_no();
        // 学齢簿の取得
        arrayGakureibo = getArrayGakureibo(req, lngKojinNo, intMenuNo);

        // 頁の取得
        int intPage = arrayGakureibo.size();

        // 学齢簿が存在する場合
        if (arrayGakureibo.size() != 0) {

            // 最新の学齢簿を取得
            gakureibo = (Gakureibo) arrayGakureibo.get(intPage - 1);
            // 表示用の学齢簿を取得
            gakureiboSyokaiView = gkb000CommonUtil.setDispDataGakureibo(gakureibo, intProcessDay, req);
            // メニュー番号
            gakureiboSyokaiView.setMenuNo(intMenuNo);
            // 頁数
            gakureiboSyokaiView.setPageCount(intPage);
            // 現在頁
            gakureiboSyokaiView.setPage(intPage);

            // セッションに学齢簿の配列を格納
            gkb000CommonUtil.setSession(req, "GKB_001_02_VECTOR", arrayGakureibo);
            // セッションに表示用学齢簿を格納
            gkb000CommonUtil.setSession(req, "GKB_001_02_VIEW", gakureiboSyokaiView);

            // 処理結果
            return (KyoikuConstants.CS_FORWARD_SUCCESS);

        } else {

            // 処理結果
            return (setError(req, KyoikuMsgConstants.EQ_GAKUREIBO_01));
        }

    }

    /**
     * 指定された履歴の学齢簿を表示用に編集を行いセッションに格納します。
     *
     * @param form    ActionForm
     * @param req     HttpServletRequest
     * @param intPlus 頁増分
     * @return 処理結果
     * @see jp.co.rkkcs.framework.util.CalendarConv
     */
    protected String createPatternPageChangeView(ActionForm form, HttpServletRequest req, int intPlus) {

        // 学齢簿の配列の定義
        Vector arrayGakureibo;
        // 学齢簿クラスオブジェクトの定義
        Gakureibo gakureibo = new Gakureibo();
        // 学齢簿表示クラスオブジェクトの定義
        GakureiboSyokaiView gakureiboSyokaiView = new GakureiboSyokaiView();

        // 画面内容を保持しているオブジェクトを設定
        GakureiboSyokaiForm gakureiboSyokaiForm = (GakureiboSyokaiForm) form;
        // アクションフォームの内容が空の場合はオブジェクトを初期化する
        if (gakureiboSyokaiForm == null)
            gakureiboSyokaiForm = new GakureiboSyokaiForm();

        // メニュー番号
        int intMenuNo = gakureiboSyokaiForm.getMenu_no();
        // 個人番号
        long lngKojinNo = gakureiboSyokaiForm.getKojin_no();
        // 学齢簿の取得
        arrayGakureibo = (Vector) gkb000CommonUtil.getSession(req, "GKB_001_02_VECTOR");
        // 頁の取得
        int intPage = (int) gakureiboSyokaiForm.getPage() + intPlus;

        // 処理日を取得
        String strProcessDay = (String) gkb000CommonUtil.getSession(req, KyoikuConstants.CS_INPUT_PROCESSDATE);
        // 処理日を西暦に変換
        int intProcessDay = kka000CommonUtil.getWareki2Seireki(strProcessDay);

        // 学齢簿が存在する場合
        if (arrayGakureibo.size() != 0) {

            // 最新の学齢簿を取得
            gakureibo = (Gakureibo) arrayGakureibo.get(intPage - 1);
            // 表示用の学齢簿を取得
            gakureiboSyokaiView = gkb000CommonUtil.setDispDataGakureibo(gakureibo, intProcessDay, req);
            // メニュー番号
            gakureiboSyokaiView.setMenuNo(intMenuNo);
            // 頁数
            gakureiboSyokaiView.setPageCount(arrayGakureibo.size());
            // 現在頁
            gakureiboSyokaiView.setPage(intPage);

            // セッションに学齢簿の配列を格納
            gkb000CommonUtil.setSession(req, "GKB_001_02_VECTOR", arrayGakureibo);
            // セッションに表示用学齢簿を格納
            gkb000CommonUtil.setSession(req, "GKB_001_02_VIEW", gakureiboSyokaiView);

//***区域外管理リストを取得してセッションに格納***//
            KuikigaiKanriListView kuikigaiKanriListv = new KuikigaiKanriListView();
            kuikigaiKanriListv = getNewKuikigaiKanri(req, gakureiboSyokaiView.getKojinNo(),
                    gakureiboSyokaiView.getRirekiRenban());
            req.getSession().setAttribute("GKB_001_05_VIEW", kuikigaiKanriListv);
            // 処理結果
            return (KyoikuConstants.CS_FORWARD_SUCCESS);

        } else {

            // 処理結果
            return (KyoikuConstants.CS_FORWARD_ERROR);
        }

    }

    /*************************************************************************************************
     *
     * 取得、設定
     *
     ************************************************************************************************/

    /**
     * 学齢簿の配列を取得します。
     *
     * @param req        request
     * @param lngKojinNo 個人番号
     * @param intMenuNo  メニュー番号
     * @return 学齢簿の配列
     */
    protected Vector getArrayGakureibo(HttpServletRequest req, long lngKojinNo, int intMenuNo) {

        // 学齢簿の配列を定義
        Vector arrayGakureibo = new Vector();

        // エラーを捕捉
        try {

            // 学齢簿の配列取得イベントオブジェクトを定義
            GKB000_GetGakureiboJohoInBean getGakureiboJohoInBean = new GKB000_GetGakureiboJohoInBean();

            // 個人番号を設定
            getGakureiboJohoInBean.setKojinNo(lngKojinNo);

            // メニュー番号を設定
            getGakureiboJohoInBean.setMenuNo(intMenuNo);

            // 学齢簿の配列取得イベントレスポンスオブジェクトを定義
            GKB000_GetGakureiboJohoOutBean getGakureiboJohoOutBean = gkb000_GetGakureiboJohoService
                    .perform(getGakureiboJohoInBean);

            // 学校情報を取得
            arrayGakureibo = getGakureiboJohoOutBean.getGakureiboVector();

            // エラーの場合
        } catch (Exception e) {

            // エラーメッセージ表示
            e.printStackTrace();

        }

        // 学齢簿の配列を返す
        return (arrayGakureibo);

    }

    /**
     * 区域外管理テーブルの配列を取得します。
     *
     * @param req            request
     * @param lngJidoKojinNo 児童個人番号
     * @param rirekiRenban   履歴連番
     * @param strProcessDay  処理日
     * @return 世帯情報の配列
     */
    protected KuikigaiKanriListView getNewKuikigaiKanri(HttpServletRequest req, String kojinNo, String rirekiRenban) {

        // 区域外管理クラスオブジェクトの定義
        Vector kuikigaikVector = new Vector();
        // 区域外管理クラスオブジェクトの定義
        KuikigaiKanriList wkKgList = new KuikigaiKanriList();
        KuikigaiKanriList kuikigaiList = new KuikigaiKanriList();
        // 表示用区域外管理クラスオブジェクトの定義
        KuikigaiKanriListView kuikigaiKanriListv = new KuikigaiKanriListView();

        // エラーを捕捉
        try {

            // 区域外管理の配列取得イベントオブジェクトを定義
            GKB000_GetKuikigaiKanriInBean getKuikigaiKanriInBean = new GKB000_GetKuikigaiKanriInBean();
            // 個人番号を設定
            kuikigaiList.setKojinNo(Long.parseLong(kojinNo));
            // 履歴連番（区域外管理マスタでは、履歴リンク）を設定
            kuikigaiList.setRirekiLnk(Integer.parseInt(rirekiRenban));
            getKuikigaiKanriInBean.setKuikigaiList(kuikigaiList);
            // 区域外情報の配列取得イベントレスポンスオブジェクトを定義
            GKB000_GetKuikigaiKanriOutBean getKuikigaiKanriOutBean = gkb000_GetKuikigaiService.perform(getKuikigaiKanriInBean);
            // 区域外情報の配列を取得
            kuikigaikVector = getKuikigaiKanriOutBean.getKuikigaiVector();
            // 取得したVectorの最新区分
            for (int listCnt = 0; listCnt < kuikigaikVector.size(); listCnt++) {
                // 区域外情報を取得
                wkKgList = (KuikigaiKanriList) kuikigaikVector.get(listCnt);
                // 区域外情報の最新区分が0の場合にのみ、returnのhelperにセット
                if (wkKgList.getSaishinKbn() == 0) {
                    kuikigaiKanriListv.setKojinNo(kojinNo);
                    kuikigaiKanriListv.setRirekiLnk(rirekiRenban);
                    kuikigaiKanriListv.setRirekiRenban(String.valueOf(wkKgList.getRirekiRenban()));
                    kuikigaiKanriListv.setKgGakkoCd(String.valueOf(wkKgList.getKgGakkoCd()));
                    kuikigaiKanriListv.setKuikigaisCd(String.valueOf(wkKgList.getKuikigaisCd()));
                    kuikigaiKanriListv.setKgKaishibi(String.valueOf(wkKgList.getKgKaishibi()));
                    kuikigaiKanriListv.setKgShuryobi(String.valueOf(wkKgList.getKgShuryobi()));
                    kuikigaiKanriListv.setDispKgKaishibi(kka000CommonUtil.format(kka000CommonUtil.getSeireki2Wareki(wkKgList.getKgKaishibi()),3));
                    kuikigaiKanriListv.setDispKgShuryobi(kka000CommonUtil.format(kka000CommonUtil.getSeireki2Wareki(wkKgList.getKgShuryobi()),3));
                    kuikigaiKanriListv.setBiko(wkKgList.getBiko());
                    kuikigaiKanriListv.setKuikigaisMei(wkKgList.getKuikigaisMei());
                }
            }
            // エラーの場合
        } catch (Exception e) {

            // エラーメッセージ表示
            e.printStackTrace();

        }

        // 区域外情報の配列を返す
        return (kuikigaiKanriListv);

    }

    /**
     * 戻り先、再表示先を設定します。
     *
     * @param forward  処理結果
     * @param frm      アクションにマッピングされたアクションフォームクラス
     * @param req      HttpServletRequest
     * @param response HttpServletResponse
     * @throws Exception
     */
    public void setFrameInfo(String forward, ActionForm frm, HttpServletRequest req, HttpServletResponse response)
            throws Exception {

        // フレーム制御情報をセッションに埋め込む
        ResultFrameInfo frameInfo = new ResultFrameInfo();
        // 画面履歴Helper生成
        ScreenHistory screenhistory = new ScreenHistory();

        // 処理に成功した場合
        if (forward.equals(KyoikuConstants.CS_FORWARD_SUCCESS)) {

            // 画面履歴表示
            screenhistory.setScreenname(KyoikuConstants.CS_GAMEN_JIDOSYOKAI);

            // メニュー番号を取得
            int intMenuNo = NumberUtils.toInt(req.getParameter("menu_no"));
            // 個人番号を取得
            String strKojinNo = "" + req.getParameter("kojin_no");

            // 世帯照会から遷移してきた場合
            if (intMenuNo == 1) {

                // 「戻る」の戻り先を設定
                frameInfo.setFrameReturnAction(req.getContextPath() + "/GKB002S001SetaiSyokaiController.do?kojin_no="
                        + strKojinNo + "&menu_no=" + intMenuNo);
                frameInfo.setFrameReturnTarget("_self");
                frameInfo.setFrameReturnLinktype("link");

                // 世帯照会以外から遷移してきた場合
            } else {

                // 「戻る」の戻り先を設定
                frameInfo.setFrameReturnAction(
                        req.getContextPath() + "/GKB000S000JidoKensakuController.do?menu_no=" + intMenuNo);
                frameInfo.setFrameReturnTarget("_self");
                frameInfo.setFrameReturnLinktype("link");
            }

            // 「再表示」の表示先を設定
            frameInfo.setFrameRefreshAction(
                    req.getContextPath() + "/GKB001S006Controller.do?kojin_no=" + strKojinNo + "&menu_no=" + intMenuNo);
            frameInfo.setFrameRefreshTarget("_self");
            frameInfo.setFrameRefreshLinktype("link");

            // 画面履歴情報をセッションから取り出して編集ルーチンで履歴編集する
            ArrayList al = gkb000CommonUtil.ScrHist((ArrayList) gkb000CommonUtil.getSession(req, "GKB_SCREENHISTORY"), screenhistory);
            // 画面履歴情報をセッションに埋める
            gkb000CommonUtil.setSession(req, "GKB_SCREENHISTORY", al);
            // 画面に表示する履歴文字列をセッションに埋める
            gkb000CommonUtil.setSession(req, "GKB_DSPRIREKI", gkb000CommonUtil.dspHist(al));
            // フレーム情報をセッションに埋める
            gkb000CommonUtil.setSession(req, CasConstants.CAS_FRAME_INFO, frameInfo);

            // 処理に失敗した場合
        } else {

            // 戻るボタンは使用不可
            frameInfo.setFrameReturnAction("");
            // 再表示も不可
            frameInfo.setFrameRefreshAction("");

            // フレーム情報をセッションに埋める
            gkb000CommonUtil.setSession(req, CasConstants.CAS_FRAME_INFO, frameInfo);
        }

    }

    /*************************************************************************************************
     *
     * 共通関数
     *
     ************************************************************************************************/

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
            setModelMessage(errform, req);
        } catch (Exception ex) {
            ex.printStackTrace();
        }

        return KyoikuConstants.CS_FORWARD_ERROR;

    }

}
