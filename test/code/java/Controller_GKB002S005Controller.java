/*
 * @(#)GKB002S005Controller.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb0000.app.gkb0020;

import java.util.ArrayList;
import java.util.Vector;

import javax.inject.Inject;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.ModelAndView;

import jp.co.jip.gkb000.common.dao.GKB000CommonUtil;
import jp.co.jip.gkb000.common.helper.GakureiboSyokaiView;
import jp.co.jip.gkb000.common.helper.KuikigaiKanriList;
import jp.co.jip.gkb000.common.helper.MessageNo;
import jp.co.jip.gkb000.common.helper.ScreenHistory;
import jp.co.jip.gkb000.common.util.KyoikuConstants;
import jp.co.jip.gkb000.common.util.KyoikuMsgConstants;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetMessageService;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetWkKuikigaiService;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageOutBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetWkKuikigaiKanriInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetWkKuikigaiKanriOutBean;
import jp.co.jip.gkb000.app.base.ActionForm;
import jp.co.jip.gkb000.app.base.ActionMapping;
import jp.co.jip.gkb000.app.base.BaseSessionSyncController;
import jp.co.jip.gkb000.app.gkb000.form.ErrorMessageForm;
import jp.co.jip.gkb000.app.helper.KuikigaiKanriListView;
import jp.co.jip.gkb000.app.helper.PageView;
import jp.co.jip.gkb0000.app.gkb0020.form.GKB002S005Form;
import jp.co.jip.gkb0000.app.helper.KuikigaiKanriListParaView;
import jp.co.jip.wizlife.fw.bean.view.Result;
import jp.co.jip.wizlife.fw.bean.view.ResultFrameInfo;
import jp.co.jip.wizlife.fw.kka000.consts.CasConstants;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonUtil;

/**
 * 就学履歴の表示
 * 
 * @author ZCZL.wangchenyang
 * @version GKB_0.2.000.000 2023/12/18
 */
@Controller
public class GKB002S005Controller extends BaseSessionSyncController {

    @Inject
    GKB000_GetWkKuikigaiService service;

    @Inject
    GKB000_GetMessageService messageService;

    @Inject
    GKB000CommonUtil gkb000CommonUtil;

    @Inject
    KKA000CommonUtil kka000CommonUtil;

    private static final String REQUEST_MAPPING_PATH = "/GKB002S005Controller";

    @ModelAttribute(MODELATTRIBUTE_NAME)
    public ActionForm setUpForm(HttpServletRequest request) {
        return setModelAttribute(request);
    }

    @RequestMapping(REQUEST_MAPPING_PATH + ".do")
    @Override
    public ModelAndView doAction(@ModelAttribute(MODELATTRIBUTE_NAME) ActionForm form, HttpServletRequest request,
            HttpServletResponse response, ModelAndView mv) throws Exception {
        return this.execute(actionMappingConfigContext.getActionMappingByPath(REQUEST_MAPPING_PATH), form, request,
                response, mv);
    }

    // コンストラクタ
    public GKB002S005Controller() {
    }

    /*************************************************************************************************
     *
     * メイン
     *
     ************************************************************************************************/

    /**
     * 就学履歴表示のメインプロセス
     *
     * @param mapping ActionMapping
     * @param frm     アクションにマッピングされたアクションフォームクラス
     * @param req     HttpServletRequest
     * @param res     HttpServletResponse
     * @throws Exception
     * @return 正常時："success" エラー時："error"
     */
    @Override
    public ModelAndView doMainProcessing(ActionMapping mapping, ActionForm form, HttpServletRequest request,
            HttpServletResponse response, ModelAndView mv) throws Exception {
        // 処理結果
        String strPrcsAns = DivergeProcess(form, request);

        // フレーム情報の設定
        setFrameInfo(strPrcsAns, form, request, response);

        // 遷移先を返す
        return (mapping.findForward(strPrcsAns).toModelAndView(mv));
    }

    /**
     * 就学履歴表示の後処理を行います。 ここでは、フレーム制御情報をセットしています。
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
    }

    /*************************************************************************************************
     *
     * 処理分岐ルーチン
     *
     ************************************************************************************************/

    /**
     * 就学履歴画面イベント処理分岐
     *
     * @param frm アクションにマッピングされたアクションフォームクラス
     * @param req HttpServletRequest
     * @return 正常時："success" エラー時："error"
     */
    protected String DivergeProcess(ActionForm frm, HttpServletRequest req) {

        // 処理結果
        String strPrcsAns = "";

        // エラーチェック
        if (errorCheck(frm, req))
            return (KyoikuConstants.CS_FORWARD_ERROR);

        // 画面内容を保持しているオブジェクトを設定
        GKB002S005Form sRirekiForm = (GKB002S005Form) frm;
        // アクションフォームの内容が空の場合は初期化する
        if (sRirekiForm == null)
            sRirekiForm = new GKB002S005Form();
        // 処理番号を取得
        int intMode = sRirekiForm.getPrcsMode();
        PageView pgView = (PageView) gkb000CommonUtil.getSession(req, "GKB_PAGE_VIEW");
        try {
            if (intMode == 2) {
                pgView.setDispFlag("2");
            } else if (intMode == 3) {
                pgView.setDispFlag("3");
            } else if (intMode == 4) {
                pgView.setDispFlag("4");
            } else {
                ;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        pgView.setUpdateFlag("none");

        gkb000CommonUtil.setSession(req, "GKB_PAGE_VIEW", pgView);
        // 更新処理の場合
        if (intMode > -1 && intMode < 5) {

            // データ抽出生成処理
            strPrcsAns = createPatternView(req, sRirekiForm);

            // 不正な場合
        } else {

            // エラー処理
            strPrcsAns = setError(req, KyoikuMsgConstants.EQ_ERROR_UNJUST_OPERATION);
        }

        // 遷移先を返す
        return (strPrcsAns);
    }

    /*************************************************************************************************
     *
     * 初期表示、再表示
     *
     ************************************************************************************************/

    /**
     * 就学履歴を表示用に編集を行いセッションに格納します。
     *
     * @param req            HttpServletRequest
     * @param GKB002S005Form 就学履歴アクションフォーム
     * @return 処理結果
     * @see GKB002S005Form
     */
    protected String createPatternView(HttpServletRequest req, GKB002S005Form sRirekiForm) {

        // 学齢簿の配列の定義
        Vector arrayGakureibo = new Vector();
        // 表示用学齢簿情報を取得
        GakureiboSyokaiView giv = (GakureiboSyokaiView) gkb000CommonUtil.getSession(req, "GKB_011_01_VIEW");
        // 表示用就学履歴の配列の定義
        Vector arrayShuRireki = getKuikigaiKanri(req, giv.getKojinNo(), giv.getRirekiRenban());
        // 就学履歴の件数取得
        int intCount = getSRirekiCount(arrayShuRireki);
        // 就学履歴画面制御情報の取得
        KuikigaiKanriListParaView paraView = getSRirekiParaView(giv, intCount);
        // 就学履歴画面情報の取得
        KuikigaiKanriListView vpara = getsRirekiForm(arrayShuRireki, sRirekiForm, intCount);
        // セッションに表示用就学履歴の配列を格納
        if (arrayShuRireki.size() <= 10) {
            gkb000CommonUtil.setSession(req, "GKB_011_05_VECTOR", arrayShuRireki);
        } else {
            Vector vSRireki = new Vector();

            for (int i = 0; i < 10; i++) {
                vSRireki.add(arrayShuRireki.get(i));
            }
            gkb000CommonUtil.setSession(req, "GKB_011_05_VECTOR", vSRireki);
        }

        // セッションに表示用就学履歴を格納
        gkb000CommonUtil.setSession(req, "GKB_011_05_VIEW", sRirekiForm);
        // セッションに就学履歴画面制御情報を格納
        gkb000CommonUtil.setSession(req, "GKB_011_05_CONTROL", paraView);
        // パラメータを格納
        gkb000CommonUtil.setSession(req, "GKB_PARA_VIEW", vpara);
        // 処理結果
        return (KyoikuConstants.CS_FORWARD_SUCCESS);

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
    protected Vector getKuikigaiKanri(HttpServletRequest req, String kojinNo, String rirekiRenban) {

        // 区域外管理クラスオブジェクトの定義
        Vector kuikigaikVector = new Vector();
        Vector kgViewVector = new Vector(); // 表示用
        // 区域外管理クラスオブジェクトの定義
        KuikigaiKanriList kuikigaiList = new KuikigaiKanriList();
        // 表示用区域外管理クラスオブジェクトの定義
        KuikigaiKanriListView kuikigaiKanriListv = new KuikigaiKanriListView();

        // エラーを捕捉
        try {
            // 区域外管理の配列取得イベントオブジェクトを定義
            GKB000_GetWkKuikigaiKanriInBean inBean = new GKB000_GetWkKuikigaiKanriInBean();
            // 個人番号を設定
            kuikigaiList.setKojinNo(Long.parseLong(kojinNo));
            // 履歴連番（区域外管理マスタでは、履歴リンク）を設定
            kuikigaiList.setRirekiLnk(Integer.parseInt(rirekiRenban));
            inBean.setKuikigaiList(kuikigaiList);
            // 区域外情報の配列取得イベントレスポンスオブジェクトを定義
            GKB000_GetWkKuikigaiKanriOutBean outBean = service.perform(inBean);
            // 区域外情報の配列を取得
            kuikigaikVector = outBean.getKuikigaiVector();
            Result result = outBean.getResult();
            // 表示用のヘルパーに格納して、再度ベクトルに入れる
            for (int i = 0; i < kuikigaikVector.size(); i++) {
                KuikigaiKanriListView kuikigaiView = new KuikigaiKanriListView();
                KuikigaiKanriList kuikigai = new KuikigaiKanriList();
                kuikigai = (KuikigaiKanriList) kuikigaikVector.get(i);
                kuikigaiView.setKojinNo(String.valueOf(kuikigai.getKojinNo()));
                kuikigaiView.setRirekiLnk(String.valueOf(kuikigai.getRirekiLink()));
                kuikigaiView.setKuikigaisCd(String.valueOf(kuikigai.getKuikigaisCd()));
                kuikigaiView.setKuikigaisMei(String.valueOf(kuikigai.getKuikigaisMei()));
                kuikigaiView.setRirekiRenban(String.valueOf(kuikigai.getRirekiRenban()));
                kuikigaiView.setKgKaishibi(String.valueOf(kuikigai.getKgKaishibi()));
                kuikigaiView.setKgShuryobi(String.valueOf(kuikigai.getKgShuryobi()));
                kuikigaiView.setDispKgKaishibi(gkb000CommonUtil.nullToSpace(
                        kka000CommonUtil.format(kka000CommonUtil.getSeireki2Wareki(kuikigai.getKgKaishibi()), 3)));
                kuikigaiView.setDispKgShuryobi(gkb000CommonUtil.nullToSpace(
                        kka000CommonUtil.format(kka000CommonUtil.getSeireki2Wareki(kuikigai.getKgShuryobi()), 3)));
                kuikigaiView.setBiko(gkb000CommonUtil.nullToSpace(String.valueOf(kuikigai.getBiko())));
                kuikigaiView.setKuikigaiKbn(String.valueOf(kuikigai.getKuikigaiKbn()));
                kuikigaiView.setKgGakkoMei(String.valueOf(kuikigai.getKgGakkoMei()));
                kuikigaiView.setKgGakkoCd(String.valueOf(kuikigai.getKgGakkoCd()));
                // 就学履歴の配列に追加
                kgViewVector.add(kuikigaiView);
            }
            if ((kgViewVector.size() == 0) || (kgViewVector.size() % 10 != 0)) {
                // 件数が１０件に満たない場合、ダミーのパターンクラスを作成する
                for (int i = (kgViewVector.size() % 10); i < 10; i++) {
                    KuikigaiKanriListView SListView = new KuikigaiKanriListView();
                    SListView.setKojinNo(" ");
                    SListView.setRirekiLnk(" ");
                    SListView.setRirekiRenban(" ");
                    SListView.setKuikigaisCd(" ");
                    SListView.setKuikigaisMei(" ");
                    SListView.setKgKaishibi(" ");
                    SListView.setKgShuryobi(" ");
                    SListView.setBiko(" ");
                    SListView.setKuikigaiKbn(" ");
                    SListView.setKgGakkoCd(" ");
                    SListView.setKgGakkoMei(" ");
                    kgViewVector.add(SListView);
                }
            }
            // エラーの場合
        } catch (Exception e) {
            // エラーメッセージ表示
            e.printStackTrace();
        }
        // 区域外情報の配列を返す
        return (kgViewVector);
    }

    /**
     * 就学履歴画面制御情報を返します。
     *
     * @param giv      表示用学齢簿クラス
     * @param intCount 就学履歴の件数
     * @return 就学履歴画面制御情報
     * @see GakureiboSyokaiView
     */
    protected KuikigaiKanriListParaView getSRirekiParaView(GakureiboSyokaiView giv, int intCount) {

        // 就学履歴画面制御情報クラスの定義
        KuikigaiKanriListParaView kuikigaiKanriListParaView = new KuikigaiKanriListParaView();

        // メニュー番号
        kuikigaiKanriListParaView.setMenuNo(giv.getMenuNo());
        // 追加ボタン制御
        kuikigaiKanriListParaView.setBtnInsertDisabled(intCount == 10);
        // 修正ボタン制御
        kuikigaiKanriListParaView.setBtnEditDisabled(intCount == 0);
        // 削除ボタン制御
        kuikigaiKanriListParaView.setBtnDeleteDisabled(intCount == 0);
        // 更新ボタン制御
        kuikigaiKanriListParaView.setBtnUpdateDisabled(false);

        // 就学履歴画面制御情報を返す
        return (kuikigaiKanriListParaView);
    }

    /**
     * 就学履歴画面情報を返します。
     *
     * @param arrayShuRireki 就学履歴の配列
     * @param sRirekiForm    就学履歴画面アクションフォーム
     * @param intCount       就学履歴の件数
     * @return 就学履歴画面情報
     * @see GKB002S005Form
     */
    protected KuikigaiKanriListView getsRirekiForm(Vector arrayShuRireki, GKB002S005Form sRirekiForm, int intCount) {

        // パラメータの定義＆初期化
        int rirekiRenban = 0;
        int kuikigaiKbn = 0;
        int kgGakkoCd = 0;
        String kgGakkoMei = " ";
        int kuikigaisCd = 0;
        String kuikigaisMei = " ";
        int kgKaishibi = 0;
        int kgShuryobi = 0;
        String biko = " ";

        // パラメータにformの内容をセット
        rirekiRenban = sRirekiForm.getCurrentRirekiRenban();
        kuikigaiKbn = sRirekiForm.getCurrentKuikigaiKbn();
        kgGakkoCd = sRirekiForm.getCurrentKgGakkoCd();
        kgGakkoMei = sRirekiForm.getCurrentKgGakkoMei();
        kuikigaisCd = sRirekiForm.getCurrentKuikigaisCd();
        kuikigaisMei = sRirekiForm.getCurrentKuikigaisMei();
        kgKaishibi = sRirekiForm.getCurrentKgKaishibi();
        kgShuryobi = sRirekiForm.getCurrentKgShuryobi();
        biko = sRirekiForm.getCurrentBiko();
        // パラメータセット用のViewを定義
        KuikigaiKanriListView parav = new KuikigaiKanriListView();

        // 追加更新、追加の場合
        if (sRirekiForm.getPrcsMode() == 1 || sRirekiForm.getPrcsMode() == 2) {
            parav.setRirekiRenban("");
            parav.setKuikigaiKbn("");
            parav.setKgGakkoCd("");
            parav.setKgGakkoMei("");
            parav.setKuikigaisCd("");
            parav.setKuikigaisMei("");
            parav.setKgKaishibi("");
            parav.setKgShuryobi("");
            parav.setBiko("");
            parav.setDispKgKaishibi("");
            parav.setDispKgShuryobi("");
        } else {
            // 区域外種別コード
            parav.setRirekiRenban(String.valueOf(rirekiRenban));
            parav.setKuikigaiKbn(String.valueOf(kuikigaiKbn));
            parav.setKgGakkoCd(String.valueOf(kgGakkoCd));
            parav.setKgGakkoMei(kgGakkoMei);
            parav.setKuikigaisCd(String.valueOf(kuikigaisCd));
            parav.setKuikigaisMei(kuikigaisMei);
            parav.setKgKaishibi(String.valueOf(kgKaishibi));
            parav.setKgShuryobi(String.valueOf(kgShuryobi));
            parav.setDispKgKaishibi(gkb000CommonUtil
                    .nullToSpace(kka000CommonUtil.format(kka000CommonUtil.getSeireki2Wareki(kgKaishibi), 3)));
            parav.setDispKgShuryobi(gkb000CommonUtil
                    .nullToSpace(kka000CommonUtil.format(kka000CommonUtil.getSeireki2Wareki(kgShuryobi), 3)));
            parav.setBiko(biko);
        }

        // 再表示、更新処理の場合
        if (sRirekiForm.getPrcsMode() == 0 || sRirekiForm.getPrcsMode() == 5) {
            // 選択モード
            sRirekiForm.setDispMode(0);
            // オプションボタンの初期選択位置
            if (intCount > 0)
                sRirekiForm.setOptNo(1);
            // 再表示、更新処理以外の場合
        } else {
            // 更新モード
            sRirekiForm.setDispMode(sRirekiForm.getPrcsMode());
            // オプションボタンの初期選択位置
            if (sRirekiForm.getOptNo() > 0)
                sRirekiForm.setSelNo(sRirekiForm.getOptNo());
        }
        // labelの設定
        if (sRirekiForm.getPrcsMode() == 2) {
            sRirekiForm.setLabel("追加");
        } else if (sRirekiForm.getPrcsMode() == 3) {
            sRirekiForm.setLabel("修正");
        } else if (sRirekiForm.getPrcsMode() == 4) {
            sRirekiForm.setLabel("削除");
        }

        // 処理番号
        sRirekiForm.setPrcsMode(0);

        // 就学履歴画面アクションフォームを返す
        return (parav);
    }

    /**
     * 就学履歴の件数を返します。
     *
     * @param arrayShuRireki 就学履歴の配列
     * @return 就学履歴の件数
     * @see KuikigaiKanriListView
     */
    private int getSRirekiCount(Vector arrayShuRireki) {

        // 表示用学齢簿情報クラスの定義
        KuikigaiKanriListView kuikigaiKanriListView = new KuikigaiKanriListView();
        // 件数
        int intCount = 0;

        // 就学履歴１〜１０
        for (int intIdx = 0; intIdx < arrayShuRireki.size(); intIdx++) {
            // 就学履歴を取得
            kuikigaiKanriListView = (KuikigaiKanriListView) arrayShuRireki.get(intIdx);
            // 就学履歴がある場合はカウントする
            if ((kuikigaiKanriListView.getKuikigaisCd().trim().length() != 0)
                    || (kuikigaiKanriListView.getKgKaishibi().trim().length() != 0))
                intCount++;
        }

        // 件数を返す
        return (intCount);

    }

    /**
     * エラーチェックの結果を返します。
     *
     * @param frm アクションにマッピングされたアクションフォームクラス
     * @param req request
     * @return チェック結果 true: エラー false: 異常なし
     */
    protected boolean errorCheck(ActionForm frm, HttpServletRequest req) {

        // エラーリスト
        ArrayList errList = new ArrayList();

        // 画面内容を保持しているオブジェクトを設定
        GKB002S005Form sRirekiForm = (GKB002S005Form) frm;
        GKB002S005Form sform = (GKB002S005Form) gkb000CommonUtil.getSession(req, "GKB_011_05_VIEW");
        // アクションフォームの内容が空の場合は初期化する
        if (sRirekiForm == null)
            sRirekiForm = new GKB002S005Form();

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

        // 表示モードが不正な場合
        if (sRirekiForm.getPrcsMode() < 0 || sRirekiForm.getPrcsMode() > 5) {

            // エラー処理
            return (setError(req, KyoikuMsgConstants.EQ_ERROR_UNJUST_OPERATION) != "");
        }
        // 更新処理の場合（削除を除く）
        if (sRirekiForm.getPrcsMode() == 5 && sRirekiForm.getPrcsMode() != 4) {

            // 区域外種別が選択されていなかった場合
            if ((sRirekiForm.getCurrentKuikigaisCd() == 0) && (sform.getCurrentKuikigaisCd() == 0)) {

                // エラーメッセージ追加
                errList.add(new MessageNo(KyoikuMsgConstants.EQ_GAKUREIBO_104));
            }

            // 区域外開始日が入力されていなかった場合
            if ((sRirekiForm.getCurrentKgKaishibi() == 0) && (sform.getCurrentKgKaishibi() == 0)) {

                // エラーメッセージ追加
                errList.add(new MessageNo(KyoikuMsgConstants.EQ_GAKUREIBO_105));
            }
        }

        // エラーが発生していた場合はエラー処理を行う
        if (errList.size() > 0)
            return (setError(req, errList) != "");

        // 異常なし
        return (false);

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

        // 処理に成功した場合
        if (forward.equals(KyoikuConstants.CS_FORWARD_SUCCESS)) {

            // 「戻る」の戻り先を設定
            frameInfo.setFrameReturnAction(request.getContextPath() + "/GKB002S004GakureiboIdoController.do");
            frameInfo.setFrameReturnTarget("_self");
            frameInfo.setFrameReturnLinktype("link");

            // 「再表示」の表示先を設定
            frameInfo.setFrameRefreshAction(request.getContextPath() + "/GKB002S005Controller.do");
            frameInfo.setFrameRefreshTarget("_self");
            frameInfo.setFrameRefreshLinktype("link");

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

    /*************************************************************************************************
     *
     * 共通関数
     *
     ************************************************************************************************/

    /**
     * エラー処理を行います。
     *
     * @param req    HttpServletRequest
     * @param errNum エラー番号
     * @return "error"
     * @see jp.co.rkkcs.framework.helper.UpdateInfo
     */
    public String setError(HttpServletRequest req, int errNum) {

        ArrayList list = new ArrayList();
        list.add(new MessageNo(errNum));

        return setError(req, list);

    }

    /**
     * エラー処理を行います。
     *
     * @param req  HttpServletRequest
     * @param list エラーリスト
     * @return "error"
     * @see jp.co.rkkcs.framework.helper.UpdateInfo
     */
    public String setError(HttpServletRequest req, ArrayList list) {

        GKB000_GetMessageInBean inBean = new GKB000_GetMessageInBean();
        inBean.setMessageNoList(list);

        try {
            GKB000_GetMessageOutBean outBean = messageService.perform(inBean);
            ErrorMessageForm errform = new ErrorMessageForm();
            errform.setErrorList(outBean.getErrors());
            errform.setWarningList(outBean.getWarnings());
            setModelMessage(errform, req);
        } catch (Exception ex) {
            ex.printStackTrace();
        }
        return KyoikuConstants.CS_FORWARD_ERROR;
    }

}