# [JID000S004ViewRow](http://localhost:3000/projects/test_jip_1/wiki?file_path=code/java/View_JID000S004ViewRow.java)

## 1. 目的
`JID000S004ViewRow` は世帯照会画面に対応する **ViewRow** です。画面表示用のデータを保持し、`AbstractViewRow` の機能を継承してビュー値の変換を行います。

## 2. 核心字段

| フィールド | 型 | 説明 |
|------------|----|------|
| `dsp_no` | String | 明細欄ＮＯ |
| `shimei_kana` | String | 明細欄氏名かな（全角 18 文字まで） |
| `shimei_kanji` | String | 明細欄氏名漢字（全角 18 文字まで） |
| `touroku_kbn` | String | 明細欄登録区分 |
| `kofu_kbn` | String | 明細欄交付状態 |
| `kojin_no` | String | 明細欄個人番号 |
| `card_no` | String | 明細欄カード番号 |
| `seinengapi` | String | 明細欄生年月日 |
| `seinengapi_chk` | String | 明細欄チェック用生年月日 |
| `seibetsu` | String | 明細欄性別 |
| `zokugara_mei` | String | 明細欄続柄名 |
| `hakko_error` | int | エラー区分（0: OK） |
| `haishi_bi` | String | 廃止日 |
| `gunzenkun` | int | 予備項目（0 で初期化） |
| `hoteiDairininShimei` | String | 法定代理人氏名 |
| `seinengapiFushoHyoki` | String | 生年月日不詳表記 |

**注意**: コード中にビジネスロジックは含まれておらず、主に画面表示用データの保持と `toViewValue` によるフォーマット変換を行うだけです。