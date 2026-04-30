/*
 * @(#)GKB003S004Controller.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb0100.app.gkb0030;

import java.util.ArrayList;

import javax.inject.Inject;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.ModelAndView;

import jp.co.jip.gaa000.common.bean.dto.GABTATENAKIHON01DTO;
import jp.co.jip.gaa000.common.dao.GAA000CommonDao;
import jp.co.jip.gkb000.app.base.ActionForm;
import jp.co.jip.gkb000.app.base.ActionMapping;
import jp.co.jip.gkb000.app.base.ActionMappingConfigContext;
import jp.co.jip.gkb000.app.base.BaseSessionSyncController;
import jp.co.jip.gkb000.app.gkb000.form.ErrorMessageForm;
import jp.co.jip.gkb000.app.helper.SeijinKohoshaView;
import jp.co.jip.gkb000.app.helper.SeijinTorokuView;
import jp.co.jip.gkb000.common.dao.GKB000CommonUtil;
import jp.co.jip.gkb000.common.helper.KyoikuLoginInfo;
import jp.co.jip.gkb000.common.helper.MessageNo;
import jp.co.jip.gkb000.common.helper.ScreenHistory;
import jp.co.jip.gkb000.common.helper.SeijinKensakuJoken;
import jp.co.jip.gkb000.common.helper.SeijinKohosha;
import jp.co.jip.gkb000.common.util.KyoikuConstants;
import jp.co.jip.gkb000.common.util.KyoikuMsgConstants;
import jp.co.jip.gkb000.common.util.ViewGadgets;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetMessageService;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageOutBean;
import jp.co.jip.gkb0100.app.gkb0030.form.GKB003S000SeijinTorokuForm;
import jp.co.jip.gkb0100.domain.service.gkb0030.GKB003S004_GetSeijinTorokuService;
import jp.co.jip.gkb0100.domain.service.gkb0030.io.GKB003S004_GetSeijinTorokuInBean;
import jp.co.jip.gkb0100.domain.service.gkb0030.io.GKB003S004_GetSeijinTorokuOutBean;
import jp.co.jip.jia000.common.bean.Setainushi;
import jp.co.jip.jia000.common.dao.JIA000CommonDao;
import jp.co.jip.wizlife.fw.bean.view.Result;
import jp.co.jip.wizlife.fw.bean.view.ResultFrameInfo;
import jp.co.jip.wizlife.fw.kka000.consts.CasConstants;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonUtil;

/**
 * GKB003S004Controller
 * タイトル: 成人者登録画面表示（初期表示）
 * @author ZCZL.Gaolu
 * @version GKB_0.2.000.000 2023/12/15
 */
@Controller
public class GKB003S004Controller extends BaseSessionSyncController{

    @Inject
    GKB003S004_GetSeijinTorokuService gkb003S004_GetSeijinTorokuService;
    
    @Inject
    GKB000_GetMessageService gkb000_GetMessageService;
    
    @Inject
    ActionMappingConfigContext actionMappingConfigContext;
    
    @Inject
    KKA000CommonUtil kka000CommonUtil;
    
    @Inject
    JIA000CommonDao jia000CommonDao;
    
    @Inject
    GAA000CommonDao gaa000CommonDao;
    
    @Inject
    GKB000CommonUtil gkb000CommonUtil;

    private static final String REQUEST_MAPPING_PATH = "/GKB003S004Controller";

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
   * 成人者登録画面［登録］ボタン押下処理のメインプロセス
   * @param  mapping ActionMapping
   * @param  form SeijinTorokuActionアクションにマッピングされたアクションフォームクラス(GKB003S000SeijinTorokuForm)
   * @param  request HttpServletRequest
   * @param  response HttpServletResponse
   * @throws Exception
   * @return 正常時："success"　入力エラー時："error"  例外エラー時："error2"
   */
  public ModelAndView doMainProcessing(ActionMapping mapping, ActionForm form,
                                        HttpServletRequest request, HttpServletResponse response,ModelAndView mv)
    throws Exception{

    String forward = "";

    // セッション情報
    HttpSession session = request.getSession();

    KyoikuLoginInfo loginInfo = (KyoikuLoginInfo)session.getAttribute(KyoikuConstants.CS_LOGIN_INFO);
    if (loginInfo == null) {
      //セッションタイムアウト
      sysError(request, KyoikuMsgConstants.EQ_ERROR_TIMEOUT);
      forward = KyoikuConstants.CS_FORWARD_ERROR2;
      request.setAttribute("actionForward", forward);
      return mapping.findForward(forward).toModelAndView(mv);
    }

    // 処理結果を格納するヘルパークラス
    Result result = new Result();

    // アクションフォームをセット
    GKB003S000SeijinTorokuForm frm = (GKB003S000SeijinTorokuForm) form;

    // 入力項目チェック
    if(!inputCheck(form, request))
    {
      // 処理結果（異常終了）のセット
      forward = KyoikuConstants.CS_FORWARD_ERROR;
      request.setAttribute("actionForward", forward);
      // 処理結果を返す
      return mapping.findForward(forward).toModelAndView(mv);
    }

    try
    {

      // 成人者登録画面の登録者取得用イベントを実行開始します
      // ※ 検索画面の候補者一覧と同様
      GKB003S004_GetSeijinTorokuInBean torokuInBean = createInBean(form, request);

      // 登録者取得
      GKB003S004_GetSeijinTorokuOutBean outBean = gkb003S004_GetSeijinTorokuService.perform(torokuInBean);

      // 処理結果を取得
      result = outBean.getResult();

      // 取得した登録者をセット
      // ※ １件しか取得しないがリストで取得している
      ArrayList list = outBean.getSeijinKohoshaList();

      // 処理結果をセッションにセット
      session.setAttribute(KyoikuConstants.CS_RESULT, result);

      //セッション変数より登録者リスト取得
      SeijinTorokuView torokuV = (SeijinTorokuView)session.getAttribute("GKB_SeijinToroku");

      if (result.getStatus() == KyoikuConstants.CN_STATUS_NG)
      {
        //エラーの場合
        // 処理結果にエラーをセット
        forward = KyoikuConstants.CS_FORWARD_ERROR;
        request.setAttribute("actionForward", forward);
        // 処理結果を返す
        return mapping.findForward(forward).toModelAndView(mv);
      }
      else
      {
        //成功だった場合
        // 処理結果を正常終了にする
        forward = KyoikuConstants.CS_FORWARD_SUCCESS;
      }

      if (list.size() >= 1)
      {
        //取得結果が１件以上の場合（正常にリストが取得できた）
        // ※ １件しか取得しないはず

        // 候補者一人分づつのデータを取り出す
        // ※ １件だけしか返さないので先頭を取得
        SeijinKohosha kohosha = (SeijinKohosha) list.get(0);

        // 表示用登録者のヘルパー（行イメージ）をセット
        SeijinKohoshaView kohoshaV = new SeijinKohoshaView();

        // 画面に表示される値ではないが引数として必要
        kohoshaV.setLnendo(String.valueOf(kohosha.getNendo()));           // 年度（西暦）
        kohoshaV.setLseiri_no(String.valueOf(kohosha.getSeiri_no()));     // 整理番号

        //個人番号
        kohoshaV.setLkojin_no(String.valueOf(kohosha.getKojin_no()));
        //性別
        kohoshaV.setLseibetsu(gkb000CommonUtil.displaySex(kohosha.getSeibetsu()));

        String wareki = " ";
        if (kohosha.getSeinengapi() != 0) {
          // 和暦変換をする処理の準備
          // 西暦 → 和暦変換を行う
          wareki = kka000CommonUtil.format(kka000CommonUtil.getSeireki2Wareki(kohosha.getSeinengapi()));
        }
        //生年月日（和暦）
        kohoshaV.setLseinengapi(wareki);

        //世帯番号
        kohoshaV.setLsetai_no(String.valueOf(kohosha.getSetai_no()));
        //氏名かな
        kohoshaV.setLshimei_kana(kohosha.getShimei_kana());
        //氏名漢字
        kohoshaV.setLshimei_kanji(kohosha.getShimei_kanji());
        //住所
        String jusho = "";
        if (kohosha.getJyusyo() != null)
        {
          jusho = kohosha.getJyusyo();
        }
        kohoshaV.setLjyusyo(jusho);

         //セッション変数より処理日を取得
        String processDate = (String)request.getSession().getAttribute(KyoikuConstants.CS_INPUT_PROCESSDATE);
        int seirekiDate = kka000CommonUtil.getWareki2Seireki(processDate);    //西暦変換

        //世帯主情報取得
        Setainushi aanushi = jia000CommonDao.getSetainushi( kohosha.getKojin_no(), seirekiDate );
        if (aanushi != null)
        {
            GABTATENAKIHON01DTO nushijoho = gaa000CommonDao.getAtenaJoho( aanushi.getSetainushiNo(), "GKB", seirekiDate );

          if (nushijoho != null)
          {
            //世帯主名漢字
            kohoshaV.setLhogosya_nm(nushijoho.getATENA_SHIMEI_KANJI());
          }
          else
          {
            //世帯主名漢字
            kohoshaV.setLhogosya_nm("");
          }
        }
        else
        {
          //世帯主名漢字
          kohoshaV.setLhogosya_nm("");
        }


        //行政区
        kohoshaV.setLgyosei_ku(String.valueOf(kohosha.getGyosei_ku()));
        //現存区分
        kohoshaV.setLgenzon_kbn(ViewGadgets.displayGenzon(kohosha.getGenzon_kbn()));
        //出欠区分
        // ※ 出欠区分はテーブルの値ではなく、入力された値をセットする（入力された値に更新するため）
        kohosha.setSyuketsu_kbn(Integer.valueOf(frm.getSyuketsu_kbn()).intValue());
        kohoshaV.setLsyuketsu_kbn(ViewGadgets.displaySyuketsu(kohosha.getSyuketsu_kbn()));

        // ＊＊＊ 登録者をリストに追加するが、以前のリストの下にセットする
        //       ただし、初期状態では空データが入っているので初回のみ値をセットしなおす ＊＊＊
        // 表示用のリストをセット
        ArrayList hyojiV = torokuV.getLhyojiList();
        ArrayList torokuL = torokuV.getLtorokuList();
        ArrayList dataV = torokuV.getLdataList();
        // 表示退避用リストの先頭行ををセット
        SeijinKohoshaView hyoji = (SeijinKohoshaView) dataV.get(0);

        // 先頭行に値が入っていれば、追加
        // はいっていなければ新規作成
        if (hyoji.getLnendo().equals(" ") == false &&
            hyoji.getLnendo().equals("") == false)
        {
          boolean tuikaFlg = true;
          for (int i = 0; i < dataV.size(); i ++)
          {
            SeijinKohoshaView oldHelper = (SeijinKohoshaView)dataV.get(i);

            // 一覧の個人番号と検索で取得した個人番号が一致した場合追加しない
            if (Long.parseLong(oldHelper.getLkojin_no()) == kohosha.getKojin_no())
            {
              tuikaFlg = false;
              break;
            }
          }
          if (tuikaFlg)
          {
            // 登録するリストの下に追加
            dataV.add(kohoshaV);      // 表示退避用
            hyojiV = dataV;           // 表示用（退避用のリストの値から直接すべてをセット）
            torokuL.add(kohosha);     // 更新用
          }
        }
        else
        {
          // 新たにリストを作成してセット
          hyojiV.clear();             // 空白リストをクリア
          dataV.clear();              // 空白リストをクリア
          torokuL.clear();            // 空白リストをクリア

          dataV.add(kohoshaV);        // 表示退避用
          hyojiV.add(kohoshaV);       // 表示用
          torokuL.add(kohosha);       // 更新用
        }

        //総件数
        torokuV.setSokensu(hyojiV.size());
        //総頁数
        torokuV.setSopagesu();
        //現頁数（追加された登録者を常に見るために現頁は最終頁とする）
        torokuV.setGenpagesu(torokuV.getSopagesu());

        // リストをクラスへセット
        torokuV.setLhyojiList(hyojiV);
        torokuV.setLtorokuList(torokuL);
        torokuV.setLdataList(dataV);

        // 入力した値の入力項目をクリアし、出欠区分を初期位置へセット
        torokuV.setCrNendo("");                 // 年度
        torokuV.setCrSeiri_no("");              // 整理番号
        torokuV.setCrSyuketsu_kbn(torokuV.getCrDefSyuketsu_kbn());   // 出欠区分

        // 取得した内容をセッションにセット
        session.setAttribute("GKB_SeijinToroku", torokuV);

      }
      else
      {
        //１件も取得できなかった場合もエラー
        //ResultステータスにＮＧセット
        result.setStatus(KyoikuConstants.CN_STATUS_NG);
        //エラーの概要
        result.setMessage("登録対象者がありません。");
        // 処理結果にエラーをセット
        forward = KyoikuConstants.CS_FORWARD_ERROR;

        // 処理結果をセッションに埋める
        session.setAttribute("GKB_RESULT",result);

        request.setAttribute("actionForward", forward);

        // 処理結果を返す
        return mapping.findForward(forward).toModelAndView(mv);
      }

      // 処理結果のセット（正常終了）
      forward = KyoikuConstants.CS_FORWARD_SUCCESS;
    }
    catch (Exception e)
    {
      //ResultステータスにＮＧセット
      result.setStatus(KyoikuConstants.CN_STATUS_NG);
      //エラーの概要
      result.setMessage("成人者登録情報取得に失敗しました。");
      //エラーの詳細
      result.setDescription(e.getMessage());
      //エラーメッセージ
      result.setDescription(e.getMessage());
      e.printStackTrace();
      // 処理結果のセット（異常終了）
      forward = KyoikuConstants.CS_FORWARD_ERROR;
    }

    // 画面履歴Helper生成
    ScreenHistory screenhistory = new ScreenHistory();
    screenhistory.setScreenname(KyoikuConstants.CS_GAMEN_SEIJINTOROKU);
    // 画面履歴情報をセッションから取り出して編集ルーチンで履歴編集する。
    ArrayList al = gkb000CommonUtil.ScrHist((ArrayList)session.getAttribute("GKB_SCREENHISTORY"),screenhistory);
    // 画面履歴情報をセッションに埋める
    session.setAttribute("GKB_SCREENHISTORY",al);
    // 画面に表示する履歴文字列をセッションに埋める
    session.setAttribute("GKB_DSPRIREKI", gkb000CommonUtil.dspHist(al));
    // 処理結果をセッションに埋める
    session.setAttribute("GKB_RESULT",result);
    request.setAttribute("actionForward", forward);

    // 処理結果を返す
    return mapping.findForward(forward).toModelAndView(mv);
  }

  /**
   * 入力項目のチェックを行います
   * @param form 入力フォーム
   * @param request HTTPリクエスト
   * @return true:正常 false:エラーあり
   */
  public boolean inputCheck(ActionForm form, HttpServletRequest request)
  {

    String errMsg = " ";
    Result result = new Result();

    // アクションフォームをセット
    GKB003S000SeijinTorokuForm chkForm = (GKB003S000SeijinTorokuForm) form;

    // セッション情報をセット
    HttpSession session = request.getSession();

    // セッションから成人者登録画面の入力項目をセット
    SeijinTorokuView torokuV = (SeijinTorokuView) session.getAttribute("GKB_SeijinToroku");

    // 入力した値を入力項目のクラスへセット
    torokuV.setCrNendo(chkForm.getNendo());                 // 年度
    torokuV.setCrSeiri_no(chkForm.getSeiri_no());           // 整理番号
    torokuV.setCrSyuketsu_kbn(chkForm.getSyuketsu_kbn());   // 出欠区分

    // 成人者登録画面の入力値をセッションへ貼り付ける
    session.setAttribute("GKB_SeijinToroku",torokuV);

    // 処理結果をセッションに埋める
    session.setAttribute("GKB_RESULT",result);

    // 年度の入力必須チェック
    if (chkForm.getNendo().equals(""))
    {
      errMsg = "年度を入力して下さい。";
      result.setMessage(errMsg);
      return false;
    }

    // 年度が日付として認識できるか？
    // ※ 和暦数値でセットされているので西暦に変換
    if (kka000CommonUtil.getWareki2SeirekiNendo(chkForm.getNendo()) == 0)
    {
      errMsg = "年度が正しく入力されていません。";
      result.setMessage(errMsg);
      return false;
    }

    // 整理番号の入力必須チェック
    if (chkForm.getSeiri_no().equals(""))
    {
      errMsg = "整理番号を入力して下さい。";
      result.setMessage(errMsg);
      return false;
    }

    // 整理番号の入力必須チェック（ゼロ以下の入力は禁止）
    if (Integer.valueOf(chkForm.getSeiri_no()).intValue() <= 0)
    {
      errMsg = "整理番号を入力して下さい。";
      result.setMessage(errMsg);
      return false;
    }

    // 出力区分の入力必須チェック
    // ※ [0]：欠席、[1]：出席以外の値は許可しない
    if (!(chkForm.getSyuketsu_kbn().equals("0") ||
          chkForm.getSyuketsu_kbn().equals("1")))
    {
      errMsg = "出力区分を入力して下さい。";
      result.setMessage(errMsg);
      return false;
    }

    return true;
  }

  /**
   * 成人者登録画面登録者情報取得を行うためのイベントクラスを生成します
   * @param form GetSeijinTorokuActionアクションにマッピングされたアクションフォームクラス(GKB003S000SeijinTorokuForm)
   * @param request HttpServletRequest
   * @return GKB003S004_GetSeijinTorokuInBean
   */
  protected GKB003S004_GetSeijinTorokuInBean createInBean(ActionForm form, HttpServletRequest request) {

    // イベントをセット
    GKB003S004_GetSeijinTorokuInBean inBean = new GKB003S004_GetSeijinTorokuInBean();

    // アクションフォームをセット
    GKB003S000SeijinTorokuForm setForm = (GKB003S000SeijinTorokuForm) form;

    // イベントに渡す引数のクラスをセット
    SeijinKensakuJoken kensakuV = new SeijinKensakuJoken();

    // 引数をセット
    // ※ 出欠区分はセットしない
    //    （出欠区分が、検索条件対象となるため） ← （成人者検索と同様の取得ロジックを使用しているため）
    kensakuV.setNendo(kka000CommonUtil.getWareki2SeirekiNendo(Integer.valueOf(setForm.getNendo()).intValue())); // 年度
    kensakuV.setSeiri_no(Integer.valueOf(setForm.getSeiri_no()).intValue()); // 整理番号

    // イベントに対して引数をセット
    inBean.setSeijinKensakuJoken(kensakuV);

    return inBean;
  }

  /**
   * エラー処理
   * @param request HTTPリクエスト
   * @param msgNo メッセージ番号
   */
  public void sysError(HttpServletRequest request, int msgNo) {

    ArrayList list = new ArrayList();
    list.add(new MessageNo(msgNo));
    GKB000_GetMessageInBean inBean = new GKB000_GetMessageInBean();
    inBean.setMessageNoList(list);
    try {
      GKB000_GetMessageOutBean outBean = gkb000_GetMessageService.perform(inBean);
      ErrorMessageForm errform = new ErrorMessageForm();
      errform.setErrorList(outBean.getErrors());
      errform.setWarningList(outBean.getWarnings());
      setModelMessage(errform, request);
    }
    catch(Exception ex) {
      ex.printStackTrace();
    }
    return;
  }

  /**
   * 成人者登録の後処理を行います。
   * ここでは、フレーム制御情報をセットしています。
   * @param mapping ActionMapping
   * @param form ActionForm
   * @param request HttpServletRequest
   * @param response HttpServletResponse
   * @throws Exception
   */
  public void doPostProcessing(ActionMapping mapping, ActionForm form,
                               HttpServletRequest request, HttpServletResponse response)
    throws Exception{

    String forWard = (String)request.getAttribute("actionForward");

    // フレーム制御情報をセッションに埋め込む
    ResultFrameInfo frameInfo = new ResultFrameInfo();
    if (forWard == KyoikuConstants.CS_FORWARD_SUCCESS) {
      // 正常
      frameInfo.setFrameReturnAction(request.getContextPath() +"/GKB000S000KyoikuSeijinMenuController.do"); // 「戻る」の戻り先
      frameInfo.setFrameReturnTarget("_self");
      frameInfo.setFrameReturnLinktype("link");
      frameInfo.setFrameRefreshAction(request.getContextPath() +"/GKB003S000SeijinTorokuController.do"); // 「再表示」表示先
      frameInfo.setFrameRefreshTarget("_self");
      frameInfo.setFrameRefreshLinktype("link");
    }
    else {
      // エラー
      frameInfo.setFrameReturnAction(request.getContextPath() +"/GKB000S000KyoikuSeijinMenuController.do"); // 「戻る」の戻り先
      frameInfo.setFrameReturnTarget("_self");
      frameInfo.setFrameReturnLinktype("link");
      frameInfo.setFrameRefreshAction(""); // 「再表示」は使用不可
    }

    HttpSession session = request.getSession();
    session.setAttribute(CasConstants.CAS_FRAME_INFO, frameInfo);
  }

}