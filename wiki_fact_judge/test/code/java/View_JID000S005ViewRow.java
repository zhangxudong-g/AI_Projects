/*
 * @(#)JID000S005ViewRow.java
 *
 * Copyright (c) 2022 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.jid0000.app.helper;

/**
 * 申請書発行・日本人と外国人の場合画面に対応するViewRow。
 * 
 * @author zczl.qizhiqiang
 * @version JID_0.2.000.000 2022/05/17
 * -----------------------------------------------------------------------------------------------
 * 変更履歴
 * 2023/10/18 DIS.Sunlu Add 0.3.000.000:新WizLIFE２次開発
 * -----------------------------------------------------------------------------------------------
 */
public class JID000S005ViewRow extends AbstractViewRow {

    /**
     * serialVersionUID.
     */
    private static final long serialVersionUID = 1L;

    /** シーケンスNO(1〜) */
    private String sikensuNo = null;

    /** シーケンス(チェックボックス) */
    private boolean sikensuChk = false;

    /** シーケンス(チェックボックスENABLE) */
    private boolean sikensuChkEnable = false;

    /** 氏名漢字(text) */
    private String namekanjiTxt = null;

    /** 生年月日(text) */
    private String seinengapi = null;

    /** 住基異動の性別(text) */
    private String seibetsuTxt = null;

    /** 住基異動の続柄名(text) */
    private String zokugara_meiTxt = null;

    /** 住基異動(text) */
    private String jukiidoTxt = null;

    /** DV(text) */
    private String DVTxt = null;

    /** 住記(text) */
    private String jyuukiTxt = null;

    /** 外国(text) */
    private String gaikokuTxt = null;

    /** 印鑑 */
    private String inkanTxt = null;

    /** カード番号 */
    private String cardNo = null;

    /** DV フラグ */
    private int dvredflg;

    /** 住記フラグ */
    private int jyuukiredflg;

    /** 外国フラグ */
    private int gaikokuredflg;

    /** 印鑑フラグ */
    private int inkanredflg;

    /** カードフラグ */
    private int cardredflg;

    /** 個人番号 */
    private String kojinNo = "";

    /** 住民票写し交付申請書エラーコード */
    private int errzhuCode = 0;

    /** 印鑑登録証明書交付申請書エラーコード */
    private int errinkanCode = 0;

    /** 登録原票記載事項証明書交付請求書エラーコード */
    private int errforeignCode = 0;

    /** 外字未登録フラグ */
    private int gaijiflg = 0;

//2023/10/18 DIS.Sunlu Add start 0.3.000.000:新WizLIFE２次開発
    /** 生年月日不詳表記 */
    private String seinengapiFushoHyoki = "";

    /**
     * @return 生年月日不詳表記
     */
    public String getSeinengapiFushoHyoki() {
        return seinengapiFushoHyoki;
    }

    /**
     * @param 生年月日不詳表記を設定。
     */
    public void setSeinengapiFushoHyoki(String seinengapiFushoHyoki) {
        this.seinengapiFushoHyoki = seinengapiFushoHyoki;
    }
//2023/10/18 DIS.Sunlu Add end
    /**
     * @return カード番号
     */
    public String getCardNo() {
        return toViewValue(cardNo);
    }

    /**
     * @param カード番号を設定。
     */
    public void setCardNo(String cardNo) {
        this.cardNo = cardNo;
    }

    /**
     * @return 印鑑
     */
    public String getInkanTxt() {
        return toViewValue(inkanTxt);
    }

    /**
     * @param 印鑑を設定。
     */
    public void setInkanTxt(String inkanTxt) {
        this.inkanTxt = inkanTxt;
    }

    /**
     * @return DV(text)
     */
    public String getDVTxt() {
        return toViewValue(DVTxt);
    }

    /**
     * @param DV(text)を設定。
     */
    public void setDVTxt(String txt) {
        DVTxt = txt;
    }

    /**
     * @return 住基異動(text)
     */
    public String getJukiidoTxt() {
        return toViewValue(jukiidoTxt);
    }

    /**
     * @param 住基異動(text)を設定。
     */
    public void setJukiidoTxt(String jukiidoTxt) {
        this.jukiidoTxt = jukiidoTxt;
    }

    /**
     * @return 住記(text)
     */
    public String getJyuukiTxt() {
        return toViewValue(jyuukiTxt);
    }

    /**
     * @param 住記(text)を設定。
     */
    public void setJyuukiTxt(String jyuukiTxt) {
        this.jyuukiTxt = jyuukiTxt;
    }

    /**
     * @return 氏名漢字(text)
     */
    public String getNamekanjiTxt() {
        return toViewValue(namekanjiTxt);
    }

    /**
     * @param 氏名漢字(text)を設定。
     */
    public void setNamekanjiTxt(String namekanjiTxt) {
        this.namekanjiTxt = namekanjiTxt;
    }

    /**
     * @return 住基異動の性別(text)
     */
    public String getSeibetsuTxt() {
        return toViewValue(seibetsuTxt);
    }

    /**
     * @param 住基異動の性別(text)を設定。
     */
    public void setSeibetsuTxt(String seibetsuTxt) {
        this.seibetsuTxt = seibetsuTxt;
    }

    /**
     * @return 生年月日(text)
     */
    public String getSeinengapi() {
        return toViewValue(seinengapi);
    }

    /**
     * @param 生年月日(text)を設定。
     */
    public void setSeinengapi(String seinengapi) {
        this.seinengapi = seinengapi;
    }

    /**
     * @return シーケンス(チェックボックス)
     */
    public boolean isSikensuChk() {
        return sikensuChk;
    }

    /**
     * @param シーケンス(チェックボックスENABLE)を設定。
     */
    public void setSikensuChk(boolean sikensuChk) {
        this.sikensuChk = sikensuChk;
    }

    /**
     * @return シーケンス(チェックボックス) を戻します。
     */
    public boolean isSikensuChkEnable() {
        return sikensuChkEnable;
    }

    /**
     * @param シーケンス(チェックボックスENABLE) を設定。
     */
    public void setSikensuChkEnable(boolean sikensuChkEnable) {
        this.sikensuChkEnable = sikensuChkEnable;
    }

    /**
     * @return シーケンスNO(1〜)
     */
    public String getSikensuNo() {
        return toViewValue(sikensuNo);
    }

    /**
     * @param シーケンスNO(1〜)を設定。
     */
    public void setSikensuNo(String sikensuNo) {
        this.sikensuNo = sikensuNo;
    }

    /**
     * @return 住基異動の続柄名(text)
     */
    public String getZokugara_meiTxt() {
        return toViewValue(zokugara_meiTxt);
    }

    /**
     * @param 住基異動の続柄名(text)を設定。
     */
    public void setZokugara_meiTxt(String zokugara_meiTxt) {
        this.zokugara_meiTxt = zokugara_meiTxt;
    }

    /**
     * @return DV フラグ
     */
    public int getDvredflg() {
        return dvredflg;
    }

    /**
     * @param DV フラグを設定。
     */
    public void setDvredflg(int dvredflg) {
        this.dvredflg = dvredflg;
    }

    /**
     * @return カードフラグ
     */
    public int getCardredflg() {
        return cardredflg;
    }

    /**
     * @param カードフラグを設定。
     */
    public void setCardredflg(int cardredflg) {
        this.cardredflg = cardredflg;
    }

    /**
     * @return 印鑑フラグ
     */
    public int getInkanredflg() {
        return inkanredflg;
    }

    /**
     * @param 印鑑フラグを設定。
     */
    public void setInkanredflg(int inkanredflg) {
        this.inkanredflg = inkanredflg;
    }

    /**
     * @return 住記フラグ
     */
    public int getJyuukiredflg() {
        return jyuukiredflg;
    }

    /**
     * @param 住記フラグを設定。
     */
    public void setJyuukiredflg(int jyuukiredflg) {
        this.jyuukiredflg = jyuukiredflg;
    }

    /**
     * @return 個人番号
     */
    public String getKojinNo() {
        return kojinNo;
    }

    /**
     * @param 個人番号を設定。
     */
    public void setKojinNo(String kojinNo) {
        this.kojinNo = kojinNo;
    }

    /**
     * @return 印鑑登録証明書交付申請書エラーコード
     */
    public int getErrinkanCode() {
        return errinkanCode;
    }

    /**
     * @param 印鑑登録証明書交付申請書エラーコードを設定。
     */
    public void setErrinkanCode(int errinkanCode) {
        this.errinkanCode = errinkanCode;
    }

    /**
     * @return 住民票写し交付申請書エラーコード
     */
    public int getErrzhuCode() {
        return errzhuCode;
    }

    /**
     * @param 住民票写し交付申請書エラーコードを設定。
     */
    public void setErrzhuCode(int errzhuCode) {
        this.errzhuCode = errzhuCode;
    }

    /**
     * @return 外字未登録フラグ
     */
    public int getGaijiflg() {
        return gaijiflg;
    }

    /**
     * @param 外字未登録フラグを設定。
     */
    public void setGaijiflg(int gaijiflg) {
        this.gaijiflg = gaijiflg;
    }

    /**
     * @return 外国フラグ
     */
    public int getGaikokuredflg() {
        return gaikokuredflg;
    }

    /**
     * @param 外国フラグを設定。
     */
    public void setGaikokuredflg(int gaikokuredflg) {
        this.gaikokuredflg = gaikokuredflg;
    }

    /**
     * @return 外国(text)
     */
    public String getGaikokuTxt() {
        return toViewValue(gaikokuTxt);
    }

    /**
     * @param 外国(text)を設定。
     */
    public void setGaikokuTxt(String gaikokuTxt) {
        this.gaikokuTxt = gaikokuTxt;
    }

    /**
     * @return 登録原票記載事項証明書交付請求書エラーコード
     */
    public int getErrforeignCode() {
        return errforeignCode;
    }

    /**
     * @param 登録原票記載事項証明書交付請求書エラーコードを設定。
     */
    public void setErrforeignCode(int errforeignCode) {
        this.errforeignCode = errforeignCode;
    }
//2024/01/31 DIS.Sunlu Add start 0.3.000.000:抑止判定関数一括対応
    /**
     * 点滅表示有無
     */
    private String binkFlg = "";
    
    /**
     * 点滅表示有無の取得
     * @return binkFlg
     */
    public String getBinkFlg() {
        return binkFlg;
    }
    /**
     * 点滅表示有無の設定
     * @param binkFlg binkFlg
     */
    public void setBinkFlg(String binkFlg) {
        this.binkFlg = binkFlg;
    }
//2024/01/31 DIS.Sunlu Add end
}