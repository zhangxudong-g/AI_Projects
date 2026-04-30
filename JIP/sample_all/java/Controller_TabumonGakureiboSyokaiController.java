/*
 * @(#)TabumonGakureiboSyokaiController.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb000.app.gkb000;

import java.util.ArrayList;
import java.util.Vector;

import javax.inject.Inject;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.ModelAndView;

import jp.co.jip.gkb000.app.base.ActionForm;
import jp.co.jip.gkb000.app.base.ActionMapping;
import jp.co.jip.gkb000.app.base.BaseSessionSyncController;
import jp.co.jip.gkb000.app.gkb000.form.ErrorMessageForm;
import jp.co.jip.gkb000.common.dao.GKB000CommonDao;
import jp.co.jip.gkb000.common.dao.GKB000CommonUtil;
import jp.co.jip.gkb000.common.helper.Gakureibo;
import jp.co.jip.gkb000.common.helper.GakureiboSyokaiView;
import jp.co.jip.gkb000.common.helper.MessageNo;
import jp.co.jip.gkb000.common.helper.ScreenHistory;
import jp.co.jip.gkb000.common.helper.SetaiList;
import jp.co.jip.gkb000.common.helper.SystemInfo;
import jp.co.jip.gkb000.common.util.KyoikuConstants;
import jp.co.jip.gkb000.common.util.KyoikuMsgConstants;
import jp.co.jip.gkb000.common.util.TabumonShokaiConstants;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetGakureiboJohoService;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetHogosyaSetGakureiboService;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetMessageService;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetSetaiJohoService;
import jp.co.jip.gkb000.service.gkb000.GKB000_ShimeiJknService;
import jp.co.jip.gkb000.service.gkb000.GKB000_SystemInfoService;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetGakureiboJohoInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetGakureiboJohoOutBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetHogosyaSetGakureiboInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetHogosyaSetGakureiboOutBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageOutBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetSetaiJohoInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetSetaiJohoOutBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetSystemInfoInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetSystemInfoOutBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_ShimeiJknInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_ShimeiJknOutBean;
import jp.co.jip.jia000.common.dao.JIA000CommonDao;
import jp.co.jip.wizlife.fw.bean.view.Result;
import jp.co.jip.wizlife.fw.bean.view.ResultFrameInfo;
import jp.co.jip.wizlife.fw.kka000.bean.dto.TabumonShokaiDTO;
import jp.co.jip.wizlife.fw.kka000.consts.CasConstants;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonUtil;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000GlobalSetDao;

/**
 * 学齢簿情報画面表示を行うWeb層Controllerクラス
 * 
 * 
 * @author ZCZL.zhangguorong
 * @version GKB_0.2.000.000 2023/12/19
 */
@Controller
public class TabumonGakureiboSyokaiController extends BaseSessionSyncController {

    @Inject
    GKB000_SystemInfoService systemInfoService;

    @Inject
    GKB000_GetMessageService getMessageService;

    @Inject
    GKB000_GetSetaiJohoService getSetaiJohoService;

    @Inject
    GKB000_GetGakureiboJohoService getGakureiboJohoService;

    @Inject
    GKB000_GetHogosyaSetGakureiboService getHogosyaSetGakureiboService;

    @Inject
    GKB000_ShimeiJknService shimeiJknService;

    @Inject
    JIA000CommonDao jia000commonDao;

    @Inject
    GKB000CommonUtil gkb000CommonUtil;

    @Inject
    KKA000CommonUtil kka000CommonUtil;
    
    @Inject
    GKB000CommonDao gkb000CommonDao;
    
    @Inject
    KKA000GlobalSetDao kka000GlobalSetDao;

    private static final String REQUEST_MAPPING_PATH = "/TabumonGakureiboSyokaiController";

    /**
     * アクションフォーム自動初期化(固定)
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
        kka000GlobalSetDao.kkaProIni();
        return this.execute(actionMappingConfigContext.getActionMappingByPath(REQUEST_MAPPING_PATH), form, request,
                response, mv);
    }


    /**
     * 教育世帯情報画面表示のメインプロセス
     * 
     * @param mapping      ActionMapping
     * @param form         GakureiboSeniActionアクションにマッピングされたアクションフォームクラス(TabumonSetaiSyokaiForm)
     * @param request      HttpServletRequest
     * @param response     HttpServletResponse
     * @param ModelAndView mv
     * @throws Exception
     * @return ModelAndView
     */
    @Override
    public ModelAndView doMainProcessing(ActionMapping mapping, ActionForm form, HttpServletRequest request,
            HttpServletResponse response, ModelAndView mv) throws Exception {
        
        String forward = "";
        Result result = new Result();
        HttpSession session = request.getSession();
        session.removeAttribute(KyoikuConstants.CS_RESULT);

        gkb000CommonUtil.setSession(request, KyoikuConstants.CS_RESULT, result);

        TabumonShokaiDTO taH = (TabumonShokaiDTO) session.getAttribute(TabumonShokaiConstants.CS_TABUMON_HEL);

        try {
            session.setAttribute("KOMOKU_KOSHO", jia000commonDao.getKomokuKoshou());

            // ***就学履歴関連の表示を行うかどうかのシステム条件を取得し、セッションに格納***//
            int sysJkn = 0;
            sysJkn = this.getEQTSystemJoken(request, 101);
            request.getSession().setAttribute("SYS_JOKEN_SHUGAKURIREKI01", String.valueOf(sysJkn));

            // 学齢簿情報を取得
            if (createGakureiboIdoView(taH.getKojin_no(), request).equals(KyoikuConstants.CS_FORWARD_SUCCESS)) {
                // 学齢簿照会画面情報の生成と設定
                // 学齢簿の配列を取得
                Vector arrayGakureibo = (Vector) request.getSession().getAttribute("GKB_011_01_VECTOR");

                // 学齢簿情報
                GakureiboSyokaiView gakureiboIdoView = (GakureiboSyokaiView) gkb000CommonUtil.getSession(request,
                        "GKB_011_01_VIEW");

                if (gakureiboIdoView != null) {
                    // 本名使用制御管理情報取得
                    GKB000_ShimeiJknInBean inBean = new GKB000_ShimeiJknInBean();
                    inBean.setKojinNo(Long.parseLong(gakureiboIdoView.getKojinNo()));

                    GKB000_ShimeiJknOutBean outBean = shimeiJknService.perform(inBean);

                    // 本名使用制御管理情報をクリア
                    session.removeAttribute("GKB_ShimeiJkn");
                    // 本名使用制御管理情報をセッションに格納
                    session.setAttribute("GKB_ShimeiJkn", outBean.getShimeiJkn());
                }

                if (arrayGakureibo.size() < 1) {
                    // 学齢簿表示クラスオブジェクトの定義
                    GakureiboSyokaiView gakureiboSyokaiView = new GakureiboSyokaiView();

                    // エラーの概要
                    result.setMessage("対象のデータが存在しません。");
                    gkb000CommonUtil.setSession(request, KyoikuConstants.CS_RESULT, result);

                    // セッションに学齢簿の配列を格納
                    gkb000CommonUtil.setSession(request, "GKB_001_02_VECTOR", arrayGakureibo);
                    // セッションに表示用学齢簿を格納
                    gkb000CommonUtil.setSession(request, "GKB_001_02_VIEW", gakureiboSyokaiView);

                    // 処理成功
                    forward = KyoikuConstants.CS_FORWARD_SUCCESS;
                } else {
                    if (gkb000CommonUtil.createGakureiboSyokaiView(request, 1, arrayGakureibo)) {
                        // 処理成功
                        forward = KyoikuConstants.CS_FORWARD_SUCCESS;
                    } else {
                        // エラー
                        forward = KyoikuConstants.CS_FORWARD_ERROR;
                    }
                }
            } else {
                // エラー
                forward = KyoikuConstants.CS_FORWARD_SUCCESS;
            }

            // 戻り先、再表示先の指定
            setSetaiSyokaiFrameInfo(forward, form, request);
            // メニュー番号が１以外の場合は学齢簿異動
        } catch (Exception e) {
            // ResultステータスにＮＧセット
            result.setStatus(KyoikuConstants.CN_STATUS_NG);
            // エラーの概要
            result.setMessage("画面情報取得に失敗しました。");
            // エラーの詳細
            result.setDescription(e.getMessage());
            // エラーメッセージ
            result.setDescription(e.getMessage());
            // 処理結果をセッションに埋める
            gkb000CommonUtil.setSession(request, KyoikuConstants.CS_RESULT, result);

            e.printStackTrace();
            forward = KyoikuConstants.CS_FORWARD_ERROR;
        }

        // 処理結果をセッションに埋める
        return mapping.findForward(forward).toModelAndView(mv);
    }

    /**
     * 学齢簿を表示用に編集を行いセッションに格納します。
     * 
     * @param long kojinNo
     * @param req  HttpServletRequest
     * @return 処理結果
     */
    protected String createGakureiboIdoView(long kojinNo, HttpServletRequest req) {

        // 学齢簿の配列の定義
        Vector arrayGakureibo;

        // 学齢簿の取得
        arrayGakureibo = getArrayGakureibo(req, kojinNo);

        // 学齢簿が無い場合
        if (!gkb000CommonUtil.isExistenceGakureibo(arrayGakureibo, 1)) {
            GakureiboSyokaiView gakureiboSyokaiView = new GakureiboSyokaiView();
            // 学齢簿情報有無FLGを設定
            gakureiboSyokaiView.setGakureiboDisabled(true);
            gakureiboSyokaiView.setNinibit("0000000000000000000000000000000000000000");
            gkb000CommonUtil.setSession(req, "GKB_ShimeiJkn", null);
            // 「現住所」に「 」は表示する。
            gakureiboSyokaiView.setHogoYubinNo("");
            // 「個人番号」に「 」は表示する。
            gakureiboSyokaiView.setKojinNo("");
            gakureiboSyokaiView.setJidoSetaiNo("");
            // 「世帯番号」に「〒」は表示する。
            gakureiboSyokaiView.setHogoSetaiNo("");
            gakureiboSyokaiView.setHogoKojinNo("");
            int idoBtnPrm = this.getEQTSystemJoken(req, 122);
            gakureiboSyokaiView.setIdoBtnPrm(idoBtnPrm);
            // セッションに表示用学齢簿を格納
            gkb000CommonUtil.setSession(req, "GKB_001_02_VIEW", gakureiboSyokaiView);
            Result result = new Result();

            result.setMessage("学齢簿情報が存在しません。");

            gkb000CommonUtil.setSession(req, KyoikuConstants.CS_RESULT, result);
            return KyoikuConstants.CS_FORWARD_ERROR;
        }

        // 学齢簿情報をセッションに設定、エラー番号を取得
        int intErrNo = gkb000CommonUtil.createGakureiboView(req, 1, arrayGakureibo);

        // 処理に成功した場合
        if (intErrNo == 0) {

            // 処理結果
            return (KyoikuConstants.CS_FORWARD_SUCCESS);

            // 処理に失敗した場合
        } else {

            // エラー処理
            return (setError(req, intErrNo));
        }

    }

    /**
     * 世帯情報を表示用に編集を行いセッションに格納します。
     *
     * @param req HttpServletRequest
     * @return 処理結果
     */
    protected String createSetaiSyokaiView(HttpServletRequest req) {

        // エラーチェック
        if (errorCheck(req))
            return (KyoikuConstants.CS_FORWARD_ERROR);

        // 学齢簿の配列の定義
        Vector arrayGakureibo = new Vector();
        // 世帯情報の配列の定義
        Vector arraySetai = new Vector();
        // 学齢簿クラスオブジェクトの定義
        Gakureibo gakureibo = new Gakureibo();
        // 学齢簿表示クラスオブジェクトの定義
        GakureiboSyokaiView gakureiboIdoView = new GakureiboSyokaiView();

        // 学齢簿情報の配列を取得
        arrayGakureibo = (Vector) gkb000CommonUtil.getSession(req, "GKB_011_01_VECTOR");
        // 表示用学齢簿情報を取得
        gakureiboIdoView = (GakureiboSyokaiView) gkb000CommonUtil.getSession(req, "GKB_011_01_VIEW");
        // 現在表示中の学齢簿情報を取得
        gakureibo = (Gakureibo) arrayGakureibo.get(gakureiboIdoView.getPage() - 1);
        TabumonShokaiDTO taH = (TabumonShokaiDTO) gkb000CommonUtil.getSession(req,
                TabumonShokaiConstants.CS_TABUMON_HEL);

        // 世帯情報の配列を取得
        arraySetai = getArraySetaiList(req, gakureibo.getKojinNo());

        // 世帯情報をセッションに設定
        if (gkb000CommonUtil.createSetaiSyokaiView(req, arraySetai)) {

            // 処理成功
            return (KyoikuConstants.CS_FORWARD_SUCCESS);

            // エラーの場合
        } else {

            // エラー
            return (KyoikuConstants.CS_FORWARD_ERROR);
        }

    }

    /**
     * 学齢簿の配列を取得します。
     *
     * @param req        request
     * @param lngKojinNo 個人番号
     * @return 学齢簿の配列
     */
    protected Vector getArrayGakureibo(HttpServletRequest req, long lngKojinNo) {

        // 学齢簿情報クラスの定義
        Gakureibo gakureibo = new Gakureibo();
        // 学齢簿の配列を定義
        Vector arrayGakureibo = new Vector();

        TabumonShokaiDTO taH = (TabumonShokaiDTO) gkb000CommonUtil.getSession(req,
                TabumonShokaiConstants.CS_TABUMON_HEL);

        // 処理日を西暦に変換
        int intProcessDay = kka000CommonUtil.getWareki2Seireki(String.valueOf(taH.getNendo()));
        // メニュー番号
        int intMenuNo = 0;

        // エラーを捕捉
        try {

            // 学齢簿の配列取得イベントオブジェクトを定義
            GKB000_GetGakureiboJohoInBean getGakureiboJohoInBean = new GKB000_GetGakureiboJohoInBean();
            // 個人番号を設定
            getGakureiboJohoInBean.setKojinNo(lngKojinNo);
            // 処理日を設定
            getGakureiboJohoInBean.setProcessDay(intProcessDay);
            // メニュー番号を設定
            getGakureiboJohoInBean.setMenuNo(intMenuNo);
            // 学齢簿の配列取得イベントレスポンスオブジェクトを定義
            GKB000_GetGakureiboJohoOutBean getGakureiboJohoOutBean = getGakureiboJohoService
                    .perform(getGakureiboJohoInBean);
            // 学校情報を取得
            arrayGakureibo = getGakureiboJohoOutBean.getGakureiboVector();

            // 最新の学齢簿を取得
            if (arrayGakureibo.size() > 0) {

                // 学齢簿の取得
                gakureibo = (Gakureibo) arrayGakureibo.get(arrayGakureibo.size() - 1);

                // 保護者の個人番号がゼロの場合
                if (gakureibo.getHogoKojinNo() == 0) {

                    if (intMenuNo == 11) {
                        // 保護者個人番号を設定
                        gakureibo.setHogoKojinNo(gkb000CommonDao.getHogosha(intProcessDay, gakureibo.getKojinNo()));
                    }
                    // 学齢簿取得イベントオブジェクトを定義
                    GKB000_GetHogosyaSetGakureiboInBean getHSGE = new GKB000_GetHogosyaSetGakureiboInBean();
                    // 学齢簿を設定
                    getHSGE.setGakureibo(gakureibo);
                    // 学齢簿取得イベントレスポンスオブジェクトを定義
                    GKB000_GetHogosyaSetGakureiboOutBean getHGSER = getHogosyaSetGakureiboService.perform(getHSGE);
                    // 学齢簿を取得
                    gakureibo = getHGSER.getGakureibo();
                    // 学齢簿を元に戻す
                    arrayGakureibo.set(arrayGakureibo.size() - 1, gakureibo);
                }
            }

            // エラーの場合
        } catch (Exception e) {

            // エラーメッセージ表示
            e.printStackTrace();

        }

        // 学齢簿の配列を返す
        return (arrayGakureibo);

    }

    /**
     * 世帯情報の配列を取得します。
     *
     * @param req            request
     * @param lngJidoKojinNo 児童個人番号
     * @return 世帯情報の配列
     */
    protected Vector getArraySetaiList(HttpServletRequest req, long lngJidoKojinNo) {

        // 世帯情報の配列を定義
        Vector arrayOldSetai = new Vector();
        // 自分以外の世帯情報の配列を定義
        Vector arrayNewSetai = new Vector();
        // 世帯情報クラスオブジェクトの定義
        SetaiList setaiList = new SetaiList();

        // エラーを捕捉
        try {

            // 世帯情報の配列取得イベントオブジェクトを定義
            GKB000_GetSetaiJohoInBean inBean = new GKB000_GetSetaiJohoInBean();
            // 個人番号を設定
            inBean.setKojinNo(lngJidoKojinNo);
            // 世帯情報の配列取得イベントレスポンスオブジェクトを定義
            GKB000_GetSetaiJohoOutBean outBean = getSetaiJohoService.perform(inBean);
            // 世帯情報の配列を取得
            arrayOldSetai = outBean.getSetaiVector();

            // 世帯情報の中から16歳以上の者を抽出
            for (int intIdx = 0; intIdx < arrayOldSetai.size(); intIdx++) {
                // 世帯情報を取得
                setaiList = (SetaiList) arrayOldSetai.get(intIdx);
                // 自分以外の場合は新規リストに追加
                if (setaiList.getKojinNo() != lngJidoKojinNo)
                    arrayNewSetai.add(setaiList);
            }

            // エラーの場合
        } catch (Exception e) {

            // エラーメッセージ表示
            e.printStackTrace();

        }

        // 世帯情報の配列を返す
        return (arrayNewSetai);

    }

    /**
     * エラーチェックの結果を返します。
     *
     * @param req request
     * @return チェック結果 true: エラー false: 異常なし
     */
    protected boolean errorCheck(HttpServletRequest req) {

        // 学齢簿情報の配列がセッションに格納されていない場合
        if (gkb000CommonUtil.getSession(req, "GKB_011_01_VECTOR") == null) {
            // エラー処理
            return (setError(req, KyoikuMsgConstants.EQ_GAKUREIBO_01) != "");
        }

        // 表示用学齢簿情報の配列がセッションに格納されていない場合
        if (gkb000CommonUtil.getSession(req, "GKB_011_01_VIEW") == null) {
            // エラー処理
            return (setError(req, KyoikuMsgConstants.EQ_GAKUREIBO_01) != "");
        }

        // 異常なし
        return (false);

    }

    /**
     * エラー処理を行います。
     *
     * @param req        HttpServletRequest
     * @param intErrorNo エラー番号
     * @return "error"
     */
    public String setError(HttpServletRequest req, int intErrorNo) {

        ArrayList<MessageNo> list = new ArrayList<MessageNo>();
        list.add(new MessageNo(intErrorNo));
        GKB000_GetMessageInBean inBean = new GKB000_GetMessageInBean();
        inBean.setMessageNoList(list);

        try {
            GKB000_GetMessageOutBean res = getMessageService.perform(inBean);
            ErrorMessageForm errform = new ErrorMessageForm();
            errform.setErrorList(res.getErrors());
            errform.setWarningList(res.getWarnings());
            setModelMessage(errform, req);
        } catch (Exception ex) {
            ex.printStackTrace();
        }

        return KyoikuConstants.CS_FORWARD_ERROR;

    }

    /**
     * 世帯照会 戻り先、再表示先を設定します。
     *
     * @param forward 処理結果
     * @param frm     アクションにマッピングされたアクションフォームクラス
     * @param request HttpServletRequest
     * @throws Exception
     */
    public void setSetaiSyokaiFrameInfo(String forward, ActionForm frm, HttpServletRequest request) throws Exception {

        HttpSession session = request.getSession();
        TabumonShokaiDTO taH = (TabumonShokaiDTO) session.getAttribute(TabumonShokaiConstants.CS_TABUMON_HEL);

        // フレーム制御情報をセッションに埋め込む
        ResultFrameInfo frameInfo = new ResultFrameInfo();
        // 画面履歴Helper生成
        ScreenHistory screenhistory = new ScreenHistory();

        // 画面表示履歴
        screenhistory.setScreenname(KyoikuConstants.CS_GAMEN_JIDOSYOKAI);
        // 画面履歴情報をセッションから取り出して編集ルーチンで履歴編集する
        ArrayList al = gkb000CommonUtil.ScrHist((ArrayList) gkb000CommonUtil.getSession(request, "GKB_SCREENHISTORY"),
                screenhistory);

        String returnAction = "";
        // 他部門照会：直接学齢簿より遷移
        if (taH.getGyomunai_kbn() == TabumonShokaiConstants.CN_GAKUREIBO) {
            returnAction = "/TabumonShokaiCloseController.do";
        } else {
            returnAction = "/TabumonSetaiSyokaiController.do";
        }
        // 「戻る」の戻り先を設定
        frameInfo.setFrameReturnAction(request.getContextPath() + returnAction);
        frameInfo.setFrameReturnTarget("_self");
        frameInfo.setFrameReturnLinktype("link");

        // 「再表示」の表示先を設定
        frameInfo.setFrameRefreshAction(request.getContextPath() + "/TabumonGakureiboSyokaiController.do");
        frameInfo.setFrameRefreshTarget("_self");
        frameInfo.setFrameRefreshLinktype("link");

        session.setAttribute(TabumonShokaiConstants.CS_FRAME_INFO, frameInfo);

        // 画面履歴情報をセッションに埋める
        gkb000CommonUtil.setSession(request, "GKB_SCREENHISTORY", al);
        // 画面に表示する履歴文字列をセッションに埋める
        gkb000CommonUtil.setSession(request, "GKB_DSPRIREKI", gkb000CommonUtil.dspHist(al));
        // フレーム情報をセッションに埋める
        gkb000CommonUtil.setSession(request, CasConstants.CAS_FRAME_INFO, frameInfo);

    }

    /**
     * 教育のシステム条件取得
     * 
     * @param req    request
     * @param renban 条件連番
     * @return 条件(0:ｼﾅｲ,1:ｽﾙ)
     */
    protected int getEQTSystemJoken(HttpServletRequest req, int renban) {
        int systemJoken = 0;
        // エラーを捕捉
        try {

            GKB000_GetSystemInfoInBean inBean = new GKB000_GetSystemInfoInBean();

            inBean.setRenban(renban);
            // システム条件の取得
            GKB000_GetSystemInfoOutBean sysJokenEvres = systemInfoService.perform(inBean);

            if (sysJokenEvres.getResult().getStatus() == KyoikuConstants.CN_STATUS_OK) {
                ArrayList sysJkn = sysJokenEvres.getSystemList();

                if (sysJkn != null && sysJkn.size() != 0) {
                    SystemInfo systemInfo = (SystemInfo) sysJkn.get(0);
                    systemJoken = systemInfo.getValue();
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return systemJoken;
    }

    /**
     * 児童候補者画面選択の後処理を行います。 ここでは、フレーム制御情報をセットしています。
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
}
