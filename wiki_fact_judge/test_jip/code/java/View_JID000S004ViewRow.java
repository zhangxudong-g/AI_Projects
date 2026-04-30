/*
 * @(#)JID000S004ViewRow.java
 *
 * Copyright (c) 2022 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.jid0000.app.helper;

/**
 * 世帯照会画面に対応するViewRow。
 * @author zczl.dongbl
 * @version JID_0.2.000.000 2022/05/19
 *-----------------------------------------------------------------------------------------------
 * 変更履歴
 * 2023/10/19 DIS.SongLiang Add 0.3.000.000:新WizLIFE２次開発
 * -----------------------------------------------------------------------------------------------
 */
public class JID000S004ViewRow extends AbstractViewRow {

    /**
     * serialVersionUID.
     */
    private static final long serialVersionUID = 1L;

    /** 明細欄ＮＯ */
    private String dsp_no;

    /**
     * 明細欄ＮＯの設定
     * 
     * @param dsp_no 明細欄ＮＯ
     */
    public void setDsp_no(String dsp_no) {
        this.dsp_no = dsp_no;
    }

    /**
     * 明細欄ＮＯの取得
     * 
     * @return 明細欄ＮＯ
     */
    public String getDsp_no() {
        return toViewValue(dsp_no);
    }


    /** 明細欄氏名かな */
    private String shimei_kana;

    /**
     * 明細欄氏名かなの設定
     * 
     * @param shimei_kana
     *            明細欄氏名かな
     */
    public void setShimei_kana(String shimei_kana) {
        this.shimei_kana = shimei_kana;
    }

    /**
     * 明細欄氏名かなの取得
     * 
     * @return 明細欄氏名かな
     */
    public String getShimei_kana() {
        return toViewValue(shimei_kana,18);
    }

    //------------------------------------------------------

    /** 明細欄氏名漢字 */
    private String shimei_kanji;

    /**
     * 明細欄氏名漢字の設定
     * 
     * @param shimei_kanji
     *            明細欄氏名漢字
     */
    public void setShimei_kanji(String shimei_kanji) {
        this.shimei_kanji = shimei_kanji;
    }

    /**
     * 明細欄氏名漢字の取得
     * 
     * @return 明細欄氏名漢字
     */
    public String getShimei_kanji() {
        return toViewValue(shimei_kanji,18);
    }

    //------------------------------------------------------

    /** 明細欄登録区分 */
    private String touroku_kbn;

    /**
     * 明細欄登録区分の設定
     * 
     * @param touroku_kbn
     *            明細欄登録区分
     */
    public void setTouroku_kbn(String touroku_kbn) {
        this.touroku_kbn = touroku_kbn;
    }

    /**
     * 明細欄登録区分の取得
     * 
     * @return 明細欄登録区分
     */
    public String getTouroku_kbn() {
        return toViewValue(touroku_kbn);
    }

    /** 明細欄交付状態 */
    private String kofu_kbn;

    /**
     * 明細欄交付状態の設定
     * 
     * @param touroku_jyotai
     *            明細欄交付状態
     */
    public void setKofu_kbn(String kofu_kbn) {
        this.kofu_kbn = kofu_kbn;
    }

    /**
     * 明細欄交付状態の取得
     * 
     * @return 明細欄交付状態
     */
    public String getKofu_kbn() {
        return toViewValue(kofu_kbn);
    }

    /** 明細欄個人番号 */
    private String kojin_no;

    /**
     * 明細欄個人番号の設定
     * 
     * @param kojin_no
     *            明細欄個人番号
     */
    public void setKojin_no(String kojin_no) {
        this.kojin_no = kojin_no;
    }

    /**
     * 明細欄個人番号の取得
     * 
     * @return 明細欄個人番号
     */
    public String getKojin_no() {
        return toViewValue(kojin_no);
    }

    /** 明細欄カード番号 */
    private String card_no;

    /**
     * 明細欄カード番号の取得
     * 
     * @return inkan_no を戻します。
     */
    public String getCard_no() {
        return card_no;
    }

    /**
     * 明細欄カード番号の設定
     */
    public void setCard_no(String card_no) {
        this.card_no = card_no;
    }

    /** 明細欄生年月日 */
    private String seinengapi;

    /**
     * 明細欄生年月日の設定
     * 
     * @param seinengapi
     *            明細欄生年月日
     */
    public void setSeinengapi(String seinengapi) {
        this.seinengapi = seinengapi;
    }

    /**
     * 明細欄生年月日の取得
     * 
     * @return 明細欄生年月日
     */
    public String getSeinengapi() {
        return toViewValue(seinengapi);
    }

    /** 明細欄チェック用生年月日 */
    private String seinengapi_chk;

    /**
     * 明細欄チェック用生年月日の設定
     * 
     * @param seinengapi_chk
     *            明細欄チェック用生年月日
     */
    public void setSeinengapi_chk(String seinengapi_chk) {
        this.seinengapi_chk = seinengapi_chk;
    }

    /**
     * 明細欄チェック用生年月日の取得
     * 
     * @return 明細欄チェック用生年月日
     */
    public String getSeinengapi_chk() {
        return toViewValue(seinengapi_chk);
    }

    /** 明細欄性別 */
    private String seibetsu;

    /**
     * 明細欄性別の設定
     * 
     * @param seibetsu
     *            明細欄性別
     */
    public void setSeibetsu(String seibetsu) {
        this.seibetsu = seibetsu;
    }

    /**
     * 明細欄性別の取得
     * 
     * @return 明細欄性別
     */
    public String getSeibetsu() {
        return toViewValue(seibetsu);
    }

    /** 明細欄続柄名 */
    private String zokugara_mei;

    /**
     * 明細欄続柄名の設定
     * 
     * @param zokugara_mei
     *            明細欄続柄名
     */
    public void setZokugara_mei(String zokugara_mei) {
        this.zokugara_mei = zokugara_mei;
    }

    /**
     * 明細欄続柄名の取得
     * 
     * @return 明細欄続柄名
     */
    public String getZokugara_mei() {
        return toViewValue(zokugara_mei);
    }

    /**
     * エラー区分 0:OK
     */
    private int hakko_error = 0;

    /**
     * エラー区分の設定
     * 
     * @return エラー区分
     */
    public void setHakko_error(int flg) {
        this.hakko_error = flg;
    }

    /**
     * エラー区分の取得
     * 
     * @return エラー区分
     */
    public int getHakko_error() {
        return this.hakko_error;
    }

    /**
     * 廃止日
     */
    private String haishi_bi ;

    /**
     * 廃止日の設定
     * 
     * @return エラー区分
     */
    public void setHaishi_bi(String haishi_bi) {
        this.haishi_bi = haishi_bi;
    }

    /**
     * 廃止日の取得
     * 
     * @return 廃止日
     */
    public String getHaishi_bi() {
        return this.haishi_bi;
    }

    private int gunzenkun = 0;
    
    
    /**
     * @return gunzenkun を戻します。
     */
    public int getGunzenkun() {
        return gunzenkun;
    }
    /**
     * @param gunzenkun gunzenkun を設定。
     */
    public void setGunzenkun(int gunzenkun) {
        this.gunzenkun = gunzenkun;
    }

    /** 
     * 法定代理人氏名 
     */
    private String hoteiDairininShimei = "";
    
    /**
     * 法定代理人氏名の取得
     * @return hoteiDairininShimei 法定代理人氏名
     */
    public String getHoteiDairininShimei() {
         return this.hoteiDairininShimei;
    }

    /**
     * 法定代理人氏名の設定
     * @param hoteiDairininShimei 法定代理人氏名
     */
    public void setHoteiDairininShimei(String hoteiDairininShimei) {
         this.hoteiDairininShimei = hoteiDairininShimei;
    }
//2023/10/19 DIS.SongLiang Add start 0.3.000.000:新WizLIFE２次開発
    
    /** 生年月日不詳表記 */
    private String seinengapiFushoHyoki = "";
    
    /**
     * 生年月日不詳表記の取得
     * 
     * @return seinengapiFushoHyoki 生年月日不詳表記
     */
    public String getSeinengapiFushoHyoki() {
        return seinengapiFushoHyoki;
    }
    /**
     * 生年月日不詳表記の設定
     * 
     * @param seinengapiFushoHyoki 生年月日不詳表記
     */
    public void setSeinengapiFushoHyoki(String seinengapiFushoHyoki) {
        this.seinengapiFushoHyoki = seinengapiFushoHyoki;
    }
//2023/10/19 DIS.SongLiang Add end
}