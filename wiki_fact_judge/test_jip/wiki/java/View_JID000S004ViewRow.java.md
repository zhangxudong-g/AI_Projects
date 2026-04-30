# JID000S004ViewRow

## 1. 目的
`JID000S004ViewRow` は世帯照会画面（JID000S004）に対応する **ViewRow**（データ転送オブジェクト）です。画面表示用の各項目を保持し、`toViewValue` メソッドを通じて表示用フォーマットに変換します。  
このクラスは `extends [AbstractViewRow](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/AbstractViewRow.java)` しています。

## 2. 核心字段

| フィールド | 型 | 説明 |
|------------|----|------|
| `dsp_no` | `String` | 明細欄ＮＯ |
| `shimei_kana` | `String` | 明細欄氏名かな |
| `shimei_kanji` | `String` | 明細欄氏名漢字 |
| `touroku_kbn` | `String` | 明細欄登録区分 |
| `kofu_kbn` | `String` | 明細欄交付状態 |
| `kojin_no` | `String` | 明細欄個人番号 |
| `card_no` | `String` | 明細欄カード番号 |
| `seinengapi` | `String` | 明細欄生年月日 |
| `seinengapi_chk` | `String` | 明細欄チェック用生年月日 |
| `seibetsu` | `String` | 明細欄性別 |
| `zokugara_mei` | `String` | 明細欄続柄名 |
| `hakko_error` | `int` | エラー区分（0: OK） |
| `haishi_bi` | `String` | 廃止日 |
| `gunzenkun` | `int` | （用途不明） |
| `hoteiDairininShimei` | `String` | 法定代理人氏名 |
| `seinengapiFushoHyoki` | `String` | 生年月日不詳表記 |