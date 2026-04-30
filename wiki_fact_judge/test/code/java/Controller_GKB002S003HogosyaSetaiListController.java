/*
 * @(#)GKB002S003HogosyaSetaiListController.java
 *
 * Copyright (c) 2024 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.gkb0000.app.gkb0020;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Vector;

import javax.inject.Inject;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.ModelAndView;

import jp.co.jip.gaa000.common.bean.dto.KyuUserDTO;
import jp.co.jip.gaa000.common.dao.GAA000CommonDao;
import jp.co.jip.gkb000.common.dao.GKB000CommonUtil;
import jp.co.jip.gkb000.common.helper.Gakureibo;
import jp.co.jip.gkb000.common.helper.GakureiboSyokaiView;
import jp.co.jip.gkb000.common.helper.MessageNo;
import jp.co.jip.gkb000.common.helper.ScreenHistory;
import jp.co.jip.gkb000.common.helper.SetaiList;
import jp.co.jip.gkb000.common.util.CommonFunction;
import jp.co.jip.gkb000.common.util.CommonGakureiboIdo;
import jp.co.jip.gkb000.common.util.KyoikuConstants;
import jp.co.jip.gkb000.common.util.KyoikuMsgConstants;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetMessageService;
import jp.co.jip.gkb000.service.gkb000.GKB000_GetSetaiJohoService;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetMessageOutBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetSetaiJohoInBean;
import jp.co.jip.gkb000.service.gkb000.io.GKB000_GetSetaiJohoOutBean;
import jp.co.jip.gkb000.app.base.ActionForm;
import jp.co.jip.gkb000.app.base.ActionMapping;
import jp.co.jip.gkb000.app.base.ActionMappingConfigContext;
import jp.co.jip.gkb000.app.base.BaseSessionSyncController;
import jp.co.jip.gkb000.app.gkb000.form.ErrorMessageForm;
import jp.co.jip.gkb000.app.gkb0020.form.GKB002S004GakureiboIdoForm;
import jp.co.jip.gkb0000.app.helper.HogosyaListParaView;
import jp.co.jip.gkb0000.app.helper.HogosyaListView;
import jp.co.jip.gkb000.common.util.DateUtil;
import jp.co.jip.wizlife.fw.bean.view.ResultFrameInfo;
import jp.co.jip.wizlife.fw.kka000.consts.CasConstants;
import jp.co.jip.wizlife.fw.kka000.dao.KKA000CommonUtil;

/**
 * GKB002S003HogosyaSetaiListController
 * タイトル: 保護者情報の表示を行
 * @author ZCZL.Gaolu
 * @version GKB_0.2.000.000 2023/12/18
 */
@Controller
public class GKB002S003HogosyaSetaiListController  extends BaseSessionSyncController {

    @Inject
    GKB000_GetSetaiJohoService gkb000_GetSetaiJohoService;
    
    @Inject
    GKB000_GetMessageService gkb000_GetMessageService;
    
    @Inject
    ActionMappingConfigContext actionMappingConfigContext;

    @Inject
    GAA000CommonDao gaa000CommonDao;
    
    @Inject
    GKB000CommonUtil gkb000CommonUtil;

    @Inject
    KKA000CommonUtil kka000CommonUtil;

    private static final String REQUEST_MAPPING_PATH = "/GKB002S003HogosyaSetaiListController";

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

  // 学齢簿共通関数クラスを定義
  CommonGakureiboIdo g = new CommonGakureiboIdo();

  /*************************************************************************************************
   *
   *　メイン
   *
   ************************************************************************************************/

  /**
   * 保護者情報表示のメインプロセス
   *
   * @param mapping ActionMapping
   * @param frm アクションにマッピングされたアクションフォームクラス
   * @param req HttpServletRequest
   * @param res HttpServletResponse
   * @throws Exception
   * @return 正常時："success" エラー時："error"
   */
  public ModelAndView doMainProcessing(ActionMapping mapping,
                                        ActionForm frm,
                                        HttpServletRequest req,
                                        HttpServletResponse res,
                                        ModelAndView mv
                                        ) throws Exception {

    // 処理結果
    String strPrcsAns = createPatternView(frm, req);

    // フレーム情報の設定
    setFrameInfo(strPrcsAns, frm, req, res);

    // 遷移先を返す
    return(mapping.findForward(strPrcsAns).toModelAndView(mv));
  }

  /**
   * 学齢簿表示の後処理を行います。
   * ここでは、フレーム制御情報をセットしています。
   *
   * @param mapping ActionMapping
   * @param form ActionForm
   * @param request HttpServletRequest
   * @param response HttpServletResponse
   * @throws Exception
   */
  public void doPostProcessing(ActionMapping mapping,
                               ActionForm form,
                               HttpServletRequest request,
                               HttpServletResponse response)
                        throws Exception {}

  /*************************************************************************************************
   *
   *　初期表示
   *
   ************************************************************************************************/

  /**
   * 保護者情報を表示用に編集を行いセッションに格納します。
   *
   * @param frm アクションにマッピングされたアクションフォームクラス
   * @param req HttpServletRequest
   * @return 処理結果
   * @see jp.co.rkkcs.framework.util.CalendarConv
   */
  protected String createPatternView(ActionForm frm, HttpServletRequest req){

    // エラーチェック
    if(errorCheck(req)) return(KyoikuConstants.CS_FORWARD_ERROR);

    // 学齢簿の配列の定義
    Vector arrayGakureibo = new Vector();
    // 保護者情報の配列の定義
    Vector arrayHogosya = new Vector();
    // 表示用保護者情報の配列の定義
    Vector arrayHogosyaDisp = new Vector();
    // 学齢簿クラスオブジェクトの定義
    Gakureibo gakureibo = new Gakureibo();
    // 世帯情報クラスオブジェクトの定義
    SetaiList setaiList = new SetaiList();
    // 学齢簿アクションフォームクラスの定義
    GKB002S004GakureiboIdoForm gakureiboIdoForm = new GKB002S004GakureiboIdoForm();
    // 学齢簿表示クラスオブジェクトの定義
    GakureiboSyokaiView gakureiboIdoView = new GakureiboSyokaiView();
    // 保護者情報表示クラスオブジェクトの定義
    HogosyaListView hogosyaListView = new HogosyaListView();
    // 保護者情報表示制御クラスオブジェクトの定義
    HogosyaListParaView hogosyaListParaView = new HogosyaListParaView();

    // 頁選択コンボの内容
    String[] strPageNumber;

    // 行開始位置
    int intRowStart;
    // 次項行開始位置
    int intNextRow;
    // データ件数
    int intDataCount;
    // 頁数
    int intPageCount;
    // 現在頁
    int intPage;
    // １頁表示最大行数
    int intMaxRow = KyoikuConstants.CS_HOGOSYALIST_MAXROW;
    // ループ用の変数
    int intIdx;

    // 学齢簿情報の配列を取得
    arrayGakureibo = (Vector)gkb000CommonUtil.getSession(req, "GKB_011_01_VECTOR");
    // 表示用学齢簿情報を取得
    gakureiboIdoView = (GakureiboSyokaiView)gkb000CommonUtil.getSession(req, "GKB_011_01_VIEW");
    // 学齢簿アクションフォームクラスの定義
    gakureiboIdoForm = (GKB002S004GakureiboIdoForm) frm;
    // 学齢簿画面の内容を学齢簿画面表示情報クラスに設定
    gakureiboIdoView = CommonGakureiboIdo.setGakureiboForm(gakureiboIdoView, gakureiboIdoForm);
    // 現在表示中の学齢簿情報を取得
    gakureibo = (Gakureibo) arrayGakureibo.get(gakureiboIdoView.getPage() - 1);
    // 処理日を取得
    String strProcessDay = (String)gkb000CommonUtil.getSession(req, KyoikuConstants.CS_INPUT_PROCESSDATE);

    // 保護者情報（世帯情報）の配列を取得
    arrayHogosya = getArraySetaiList(req, gakureibo.getKojinNo(), strProcessDay);

    // 現在頁の取得
    intPage = 1;
    // データ件数の取得
    intDataCount = arrayHogosya.size();
    // 頁数の取得
    intPageCount = (int)((intDataCount - 1) / intMaxRow) + 1;
    // 行開始位置
    intRowStart = (intPage - 1) * intMaxRow;
    // 次項行開始位置
    intNextRow = intPage * intMaxRow;
    // 頁選択コンボの内容格納領域の確保
    strPageNumber = new String[intPageCount];

    /**
     * データ出力情報の生成
     */

    // ビジネスロジックはここから
    for(intIdx=intRowStart; intIdx < intNextRow; intIdx++){

      // データ件数を超えた場合はループから抜け出す
      if( intIdx >= intDataCount ) break;

      // 配列から１件分の指定データを取得
      setaiList = (SetaiList)arrayHogosya.get(intIdx);
      // 世帯情報を表示用保護者情報に設定
      hogosyaListView = setDispDataSetai(setaiList, intIdx + 1);
      // 編集後のデータを追加
      arrayHogosyaDisp.add(hogosyaListView);
    }

    // 件数が１頁で表示できる最大行数に満たない場合、ダミーのパターンクラスを作成する
    for(intIdx = intDataCount; intIdx < intNextRow; intIdx++){

      // 表示用保護者情報の初期化（初期化した内容が入っている。空状態。）
      hogosyaListView = new HogosyaListView();
      // 空の内容をそのまま追加
      arrayHogosyaDisp.add(hogosyaListView);
    }

    /**
     * 画面オブジェクトの選択制御
     */

    // 開始頁の場合は前頁ボタンクリックできない
    if( intPage > 1 ){
      // 前項ボタンはクリック可
      hogosyaListParaView.setBtnPreviousDisabled(false);
    }else{
      // 前頁ボタンはクリック不可
      hogosyaListParaView.setBtnPreviousDisabled(true);
    }

    // 最終頁の場合は次項ボタンはクリックできない
    if( intPage < intPageCount ){
      // 次項ボタンはクリック可
      hogosyaListParaView.setBtnNextDisabled(false);
    }else{
      // 次項ボタンはクリック不可
      hogosyaListParaView.setBtnNextDisabled(true);
    }

    // １頁で表示できる場合は頁選択コンボと頁選択ボタンは選択不可になる
    if( intDataCount < intMaxRow ){
      // 頁選択コンボの選択不可
      hogosyaListParaView.setCmbPageChangeDisabled(true);
      // 頁選択ボタンの選択不可
      hogosyaListParaView.setBtnPageChangeDisabled(true);
    } else {
      // 頁選択コンボの選択可
      hogosyaListParaView.setCmbPageChangeDisabled(false);
      // 頁選択ボタンの選択可
      hogosyaListParaView.setBtnPageChangeDisabled(false);
    }

    /**
     * その他出力情報の設定
     */

    // 頁選択コンボの内容作成
    for (intIdx = 0; intIdx < intPageCount; intIdx++){
      // 頁を設定
      strPageNumber[intIdx] = "" + (intIdx + 1);
    }

    // 頁選択コンボの内容を設定
    hogosyaListParaView.setCmbPageNumber(strPageNumber);
    // データ件数を設定
    hogosyaListParaView.setSelectCount(intDataCount);
    // 頁数を設定
    hogosyaListParaView.setPageCount(intPageCount);
    // 現在頁を設定
    hogosyaListParaView.setPresentPage(intPage);

    /**
     * セッション
     */

    // セッションに学齢簿画面表示情報を格納
    gkb000CommonUtil.setSession(req, "GKB_011_01_VIEW", gakureiboIdoView);
    // セッションに保護者情報の配列を格納
    gkb000CommonUtil.setSession(req, "GKB_000_03_VECTOR", arrayHogosya);
    // セッションに表示用保護者情報を格納
    gkb000CommonUtil.setSession(req, "GKB_000_03_VIEW", arrayHogosyaDisp);
    // セッションに画面制御情報を格納
    gkb000CommonUtil.setSession(req, "GKB_000_03_CONTROL", hogosyaListParaView);

    // 処理結果
    return(KyoikuConstants.CS_FORWARD_SUCCESS);

  }

  /*************************************************************************************************
   *
   *　取得、設定
   *
   ************************************************************************************************/

  /**
   * 世帯情報を表示用保護者情報クラスに格納して返します。
   *
   * @param setaiList 世帯情報
   * @param intRow 行番号
   * @return 表示用保護者情報クラス
   */
  protected HogosyaListView setDispDataSetai(SetaiList setaiList, int intRow){

    // 表示用保護者情報クラスオブジェクトの定義
    HogosyaListView hogosyaListView = new HogosyaListView();

    // 行番号
    hogosyaListView.setRowNo(intRow);
    // 個人番号
    hogosyaListView.setKojinNo("" + setaiList.getKojinNo());
    // 氏名かな
    hogosyaListView.setShimeiKana(gkb000CommonUtil.nullToSpace(setaiList.getShimeiKana()));
    // 氏名漢字
    hogosyaListView.setShimeiKanji(gkb000CommonUtil.nullToSpace(setaiList.getShimeiKanji()));
    // 性別
    hogosyaListView.setSeibetsu(gkb000CommonUtil.displaySex((int)(setaiList.getSeibetsu())));
    // 生年月日
    hogosyaListView.setSeinengapi(gkb000CommonUtil.nullToSpace(kka000CommonUtil.format(kka000CommonUtil.getSeireki2Wareki(setaiList.getSeinengapi()),3)));
    // 世帯番号
    hogosyaListView.setSetaiNo("" + setaiList.getSetaiNo());
    // 続柄
    hogosyaListView.setZokugaramei(gkb000CommonUtil.nullToSpace(setaiList.getZokugaramei()));
    // 郵便番号
    hogosyaListView.setYubinNo(gkb000CommonUtil.nullToSpace(gkb000CommonUtil.getYubinBango(setaiList.getYubinNo())));
    // 現住所
    hogosyaListView.setJusho(gkb000CommonUtil.nullToSpace(CommonFunction.cutNull(setaiList.getChomei())
                                         + CommonFunction.cutNull(setaiList.getBanchi())
                                         + CommonFunction.cutNull(setaiList.getKatagaki())));
    hogosyaListView.setJusho(gkb000CommonUtil.nullToSpace(CommonFunction.cutNull(setaiList.getChomei())
                           + CommonFunction.cutNull(setaiList.getBanchi())
                     + "　"
                     + CommonFunction.cutNull(setaiList.getKatagaki())));
    // 旧自治体
    hogosyaListView.setKyuJichitai(getKyuJititai((int)setaiList.getSanteiDantaiCd()));
    // 地区
    hogosyaListView.setChiku(getChiku((int)setaiList.getSanteiDantaiCd(), setaiList.getChikuCd()));
    // 行政区
    hogosyaListView.setGyoseiku(getGyoseiku((int)setaiList.getSanteiDantaiCd(), setaiList.getGyoseikuCd()));
    // 班
    String hanCd = String.valueOf(setaiList.getHanCd());
    String hanNm = getHan((int)setaiList.getSanteiDantaiCd(), setaiList.getHanCd());
    hogosyaListView.setGyoseiku(gaa000CommonDao.editHan(hanCd, hanNm));
    // 喪失事由
    hogosyaListView.setJuminNakunaruJiyu(gkb000CommonUtil.nullToSpace(setaiList.getJuminNakunaruJiyu()));

    // 表示用保護者情報を返す
    return(hogosyaListView);

  }

  /**
   * 世帯情報の配列を取得します。
   *
   * @param req request
   * @param lngKojinNo 個人番号
   * @param strProcessDay 処理日
   * @return 世帯情報の配列
   */
  protected Vector getArraySetaiList(HttpServletRequest req, long lngKojinNo, String strProcessDay){

    // 世帯情報の配列を定義
    Vector arrayOldSetai = new Vector();
    // １６歳以上世帯情報の配列を定義
    Vector arrayNewSetai = new Vector();
    // 世帯情報クラスオブジェクトの定義
    SetaiList setaiList = new SetaiList();

    // 処理日を西暦に変換
    int intProcessDay = kka000CommonUtil.getWareki2Seireki(strProcessDay);

    // エラーを捕捉
    try{

      // 世帯情報の配列取得InBean定義
      GKB000_GetSetaiJohoInBean getSetaiJohoInBean = new GKB000_GetSetaiJohoInBean();
      // 個人番号を設定
      getSetaiJohoInBean.setKojinNo(lngKojinNo);
      // 世帯情報の配列取得イベントレスポンスオブジェクトを定義
      GKB000_GetSetaiJohoOutBean getSetaiJohoOutBean = gkb000_GetSetaiJohoService.perform(getSetaiJohoInBean);
      // 世帯情報の配列を取得
      arrayOldSetai = getSetaiJohoOutBean.getSetaiVector();

      // 世帯情報の中から16歳以上の者を抽出
      for(int intIdx=0;intIdx<arrayOldSetai.size();intIdx++){
        // 世帯情報を取得
        setaiList = (SetaiList)arrayOldSetai.get(intIdx);
        // 16歳以上と自分以外の場合は新規リストに追加
        if(setaiList.getKojinNo() != lngKojinNo
        && CommonFunction.getOver16JudgmentDay(setaiList.getSeinengapi() ,intProcessDay)) arrayNewSetai.add(setaiList);
      }

    // エラーの場合
    }catch(Exception e){

      // エラーメッセージ表示
      e.printStackTrace();

    }
    // 世帯情報の配列を返す
    return(arrayNewSetai);
  }

  /**
   * エラーチェックの結果を返します。
   *
   * @param req request
   * @return チェック結果 true: エラー　false: 異常なし
   */
  protected boolean errorCheck(HttpServletRequest req){

    // ログイン情報がセッションタイムアウトの場合
    if(gkb000CommonUtil.isTimeOut(req)){
      // エラー処理
      return(setError(req, KyoikuMsgConstants.EQ_ERROR_TIMEOUT) != "");
    }

    // 学齢簿情報の配列がセッションに格納されていない場合
    if(!gkb000CommonUtil.isSession(req, "GKB_011_01_VECTOR")){
      // エラー処理
      return(setError(req, KyoikuMsgConstants.EQ_GAKUREIBO_01) != "");
    }

    // 表示用学齢簿情報の配列がセッションに格納されていない場合
    if(!gkb000CommonUtil.isSession(req, "GKB_011_01_VIEW")){
      // エラー処理
      return(setError(req, KyoikuMsgConstants.EQ_GAKUREIBO_01) != "");
    }

    // 処理日がセッションに格納されていない場合１
    if(!gkb000CommonUtil.isSession(req, KyoikuConstants.CS_INPUT_PROCESSDATE)){
      // エラー処理
      return(setError(req, KyoikuMsgConstants.EQ_GAKUREIBO_67) != "");
    }

    // 処理日がセッションに格納されていない場合２
    if(gkb000CommonUtil.CInt("" + gkb000CommonUtil.getSession(req, KyoikuConstants.CS_INPUT_PROCESSDATE)) == 0){
      // エラー処理
      return(setError(req, KyoikuMsgConstants.EQ_GAKUREIBO_67) != "");
    }

    // 異常なし
    return(false);

  }

  /**
   * 戻り先、再表示先を設定します。
   *
   * @param forward 処理結果
   * @param frm アクションにマッピングされたアクションフォームクラス
   * @param request HttpServletRequest
   * @param response HttpServletResponse
   * @throws Exception
   */
  public void setFrameInfo(String forward,
                           ActionForm frm,
                           HttpServletRequest request,
                           HttpServletResponse response)
                           throws Exception  {

    // フレーム制御情報をセッションに埋め込む
    ResultFrameInfo frameInfo = new ResultFrameInfo();
    // 画面履歴Helper生成
    ScreenHistory screenhistory = new ScreenHistory();

    // 処理に成功した場合
    if (forward.equals(KyoikuConstants.CS_FORWARD_SUCCESS)) {

      // メニュー番号を取得
      int intMenuNo = gkb000CommonUtil.CInt(request.getParameter("menu_no"));
      // 個人番号を取得
      long lngKojinNo = gkb000CommonUtil.CLng(request.getParameter("kojin_no"));

      // 画面タイトル
      screenhistory.setScreenname(KyoikuConstants.CS_GAMEN_HOGOSYAKENSAKU);
      // 画面履歴情報をセッションから取り出して編集ルーチンで履歴編集する
      ArrayList al = gkb000CommonUtil.ScrHist((ArrayList)gkb000CommonUtil.getSession(request, "GKB_SCREENHISTORY"),screenhistory);

      // 「戻る」の戻り先を設定
      frameInfo.setFrameReturnAction(request.getContextPath() +"/GKB001S001Controller.do?menu_no=2&shoriFlg=1&kojin_no=" + lngKojinNo);
      frameInfo.setFrameReturnTarget("_self");
      frameInfo.setFrameReturnLinktype("link");

      // 「再表示」の表示先を設定
      frameInfo.setFrameRefreshAction(request.getContextPath() +"/GKB002S002HogosyaSetaiListChangeController.do?menu_no=2&kojin_no=" + lngKojinNo);
      frameInfo.setFrameRefreshTarget("_self");
      frameInfo.setFrameRefreshLinktype("link");

      // 画面履歴情報をセッションに埋める
      gkb000CommonUtil.setSession(request, "GKB_SCREENHISTORY", al);
      // 画面に表示する履歴文字列をセッションに埋める
      gkb000CommonUtil.setSession(request, "GKB_DSPRIREKI", gkb000CommonUtil.dspHist(al));
      // フレーム情報をセッションに埋める
      gkb000CommonUtil.setSession(request, CasConstants.CAS_FRAME_INFO, frameInfo);

    // 処理に失敗した場合
    }else{

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
   *　共通関数
   *
   ************************************************************************************************/

  /**
   * 旧自治体名を取得します。
   *
   * @param intSanteiDantaiCd 算定団体コード
   * @return 旧自治体名
   */
  public String getKyuJititai(int intSanteiDantaiCd){
      SimpleDateFormat format = new SimpleDateFormat(DateUtil.YYYYMMDD);
      String operateDate = format.format(new Date(System.currentTimeMillis()));
      int kijunbi = Integer.parseInt(operateDate);

      KyuUserDTO KyuUserDTO = gaa000CommonDao.getSanteidantai(intSanteiDantaiCd, kijunbi);
      return KyuUserDTO.getUsermei();
  }

  /**
   * 地区名を取得します。
   *
   * @param intSanteiDantaiCd 算定団体コード
   * @param intChikuCd 地区コード
   * @return 地区名
   */
  public String getChiku(int intSanteiDantaiCd, int intChikuCd){

    return gaa000CommonDao.getChiku(intSanteiDantaiCd, intChikuCd);

  }

  /**
   * 行政区名を取得します。
   *
   * @param intSanteiDantaiCd 算定団体コード
   * @param intGyoseikuCd 行政区コード
   * @return 行政区名
   */
  public String getGyoseiku(int intSanteiDantaiCd, int intGyoseikuCd){

    return gaa000CommonDao.getGyoseiku(intSanteiDantaiCd, intGyoseikuCd);

  }

  /**
   * 班名を取得します。
   *
   * @param intSanteiDantaiCd 算定団体コード
   * @param intHanCd 班コード
   * @return 行政区名
   */
  public String getHan(int intSanteiDantaiCd, long intHanCd){

    return gaa000CommonDao.getHan(intSanteiDantaiCd, intHanCd);

  }

  /**
   * 小学校区名を取得します。
   *
   * @param intSanteiDantaiCd 算定団体コード
   * @param intShogakuCd 小学校区コード
   * @return 小学校区名
   */
  public String getShogakoku(int intSanteiDantaiCd, int intShogakuCd){

    return gaa000CommonDao.getShogaku(intSanteiDantaiCd, intShogakuCd);

  }

  /**
   * 中学校区名を取得します。
   *
   * @param intSanteiDantaiCd 算定団体コード
   * @param intChugakuCd 中学校区名コード
   * @return 中学校区名
   */
  public String getChugakoku(int intSanteiDantaiCd, int intChugakuCd){

    return gaa000CommonDao.getChugaku(intSanteiDantaiCd, intChugakuCd);

  }

  /**
   * エラー処理を行います。
   *
   * @param req HttpServletRequest
   * @param intErrorNo エラー番号
   * @return "error"
   */
  public String setError(HttpServletRequest req, int intErrorNo) {

    ArrayList list = new ArrayList();
    list.add(new MessageNo(intErrorNo));
    GKB000_GetMessageInBean inBean = new GKB000_GetMessageInBean();
    inBean.setMessageNoList(list);

    try {
      GKB000_GetMessageOutBean outBean = gkb000_GetMessageService.perform(inBean);
      ErrorMessageForm errform = new ErrorMessageForm();
      errform.setErrorList(outBean.getErrors());
      errform.setWarningList(outBean.getWarnings());
      setModelMessage(errform, req);
    }catch(Exception ex) {
      ex.printStackTrace();
    }
    return KyoikuConstants.CS_FORWARD_ERROR;
  }

}
