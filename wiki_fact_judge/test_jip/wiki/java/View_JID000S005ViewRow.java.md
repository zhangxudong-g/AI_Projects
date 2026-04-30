# [JID000S005ViewRow](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/View_JID000S005ViewRow.java)

## 1. 目的
`JID000S005ViewRow` は **申請書発行** 画面において、日本人および外国人の場合に対応する **ViewRow**（画面表示用データ保持クラス）です。  
**注意**: コード中に業務詳細のコメントはありませんが、クラス名と Javadoc から上記の目的を推測しています。

## 核心字段

| フィールド | 型 | 説明 |
|------------|----|------|
| `sikensuNo` | `String` | シーケンスNO(1〜) |
| `sikensuChk` | `boolean` | シーケンス(チェックボックス) |
| `sikensuChkEnable` | `boolean` | シーケンス(チェックボックスENABLE) |
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