# JID000S005ViewRow

## 1. 目的
`JID000S005ViewRow` は **申請書発行・日本人と外国人の場合画面に対応する ViewRow**（データ転送オブジェクト）です。画面表示に必要な項目を保持し、`AbstractViewRow` の機能を継承してビュー側で利用されます。  

**注意**: 目的はクラスの Javadoc から直接取得しています。

## 2. 核心字段

| フィールド | 型 | 説明 |
|------------|----|------|
| `sikensuNo` | `String` | シーケンスNO(1〜) |
| `sikensuChk` | `boolean` | シーケンス(チェックボックス) |
| `sikensuChkEnable` | `boolean` | シーケンス(チェックボックス) の有効/無効 |
| `namekanjiTxt` | `String` | 氏名漢字(text) |
| `seinengapi` | `String` | 生年月日(text) |
| `seinengapiFushoHyoki` | `String` | 生年月日不詳表記 |
| `seibetsuTxt` | `String` | 住基異動の性別(text) |
| `zokugara_meiTxt` | `String` | 住基異動の続柄名(text) |
| `jukiidoTxt` | `String` | 住基異動(text) |
| `DVTxt` | `String` | DV(text) |
| `jyuukiTxt` | `String` | 住記(text) |
| `gaikokuTxt` | `String` | 外国(text) |
| `inkanTxt` | `String` | 印鑑 |
| `cardNo` | `String` | カード番号 |
| `dvredflg` | `int` | DV フラグ |
| `jyuukiredflg` | `int` | 住記フラグ |
| `gaikokuredflg` | `int` | 外国フラグ |
| `inkanredflg` | `int` | 印鑑フラグ |
| `cardredflg` | `int` | カードフラグ |
| `kojinNo` | `String` | 個人番号 |
| `errzhuCode` | `int` | 住民票写し交付申請書エラーコード |
| `errinkanCode` | `int` | 印鑑登録証明書交付申請書エラーコード |
| `errforeignCode` | `int` | 登録原票記載事項証明書交付請求書エラーコード |
| `gaijiflg` | `int` | 外字未登録フラグ |
| `binkFlg` | `String` | 点滅表示有無 |