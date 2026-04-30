# GKB0010Repository

## 1. 目的
`GKB0010Repository` は **Spring の DAO コンポーネント** として、学齢簿・保護者・通知書等に関する多数の SQL 取得処理を提供します。  
コード中に業務概要のコメントはありませんので、上記の説明はクラス名とメソッドシグネチャからの **推測** です。

## 2. 主要メソッド
| メソッド | 戻り値 | 説明 |
|----------|--------|------|
| `selectBIKOSENTAKU_001(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 備考情報（基本テーブル部分）を取得 |
| `selectGETBIKO_002(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 備考取得（基本テーブル部分） |
| `selectGABVATENAALL_003(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 保護者宛名異動履歴取得 |
| `selectGABVATENAALL_004(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 児童生徒宛名異動履歴取得 |
| `selectGKBTHYODAIKANRI_005()` | `ArrayList<Map<String, Object>>` | 通知書タイトル取得 |
| `selectGABTATENAKIHON_006(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 候補者一覧取得 |
| `selectninshobunSentaku_007(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 認証情報（基本テーブル）取得 |
| `selectgetNinshobun_008(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 認証情報（基本テーブル）取得 |
| `selectGKBTGAKUREIBO_001(String)` | `ArrayList<String>` | 学齢簿生徒履歴連番リスト取得 |
| `selectGKBTGAKUREIBO_002([GakureiboSearchCondition])` | `GakureiboShokaiData` | 学齢簿情報取得 |
| `selectGKBTGAKUREIBO_003([GakureiboSearchCondition])` | `HogosyaData` | 保護者情報取得 |
| `selectGABTIDOJIYU_001(String)` | `String` | 異動事由取得 |
| `selectGKBTSHIMEIJKN_001(String)` | `Integer` | 本名使用制御管理データ数取得 |
| `selectGKBFKZKGMGET_001(Map<String, Object>)` | `void` | 続柄名取得 |
| `selectGKBFKZKGMGET_002(Map<String, Object>)` | `void` | 続柄名取得 |
| `selectGKAFKGKOGTEQ_001(Map<String, Object>)` | `void` | 学校名取得 |
| `selectGKBTGAKUNEN_001(String)` | `Map<String, String>` | 学年マスタ情報取得 |
| `selectGKBTSHOGAKKO_001(String)` | `Map<String, String>` | 小学校情報取得 |
| `selectGKBTCHUGAKKO_001(String)` | `Map<String, String>` | 中学校情報取得 |
| `selectGKBTYOGOGAKKO_001(String)` | `Map<String, String>` | 盲聾養護学校情報取得 |
| `selectGKBTKUIKIGAI_001(String)` | `Map<String, String>` | 区域外学校情報取得 |
| `selectGKBTKUNISIRITSUGAKKO_001(String)` | `Map<String, String>` | 国・私立学校情報取得 |
| `selectGKBTMSGAKUKYUCD_001(String, String, String)` | `Map<String, Object>` | 学級区分情報取得 |
| `selectGKBFKGKKUGET_001(Map<String, Object>)` | `void` | 校区情報取得 |
| `selectFDateSW_001(Map<String, Object>)` | `void` | 西暦→和暦変換 |
| `selectGKBTGAKUREIBO_004(String)` | `List<Map<String, String>>` | 兄弟情報取得 |
| `selectGKBTKUIKIGAIKANRI_001(String)` | `int` | 区域外管理データ件数取得 |
| `select_GKBTGAKUREIBO_001(String)` | `GkbtgakureiboData` | 最新学齢簿データ取得 |
| `select_GKBTGAKUREIBO_002(String)` | `List<GkbtgakureiboData>` | 学齢簿データリスト取得 |
| `select_GABTATENARIREKI_001(String, String)` | `GabtatenakihonData` | 宛名情報取得（履歴連番指定） |
| `select_GABTATENAKIHON_001(String, String)` | `GabtatenakihonData` | 児童宛名情報取得 |
| `select_GABTATENAKIHON_002(String, String)` | `GabtatenakihonData` | 保護者宛名情報取得 |
| `select_GABVATENAALL_002(String)` | `GabtatenakihonData` | 宛名情報取得 |
| `selectGKBTGAKUNENRIREKI_003(String)` | `Gkbtgkunenrireki` | 学年最新履歴取得 |
| `selectGKBTMSGAKKU_001(GabtatenakihonData)` | `List<Map<String, Object>>` | 小学校区情報取得 |
| `selectGKBTMSGAKKU_002(GabtatenakihonData)` | `List<Map<String, Object>>` | 小学校区情報取得 |
| `selectGKBTMSGAKKU_003(GabtatenakihonData)` | `List<Map<String, Object>>` | 中学校区情報取得 |
| `selectGKBTMSGAKKU_004(GabtatenakihonData)` | `List<Map<String, Object>>` | 中学校区情報取得 |
| `selectGKBTMSGAKKU_005(Map<String, Object>)` | `List<Map<String, Object>>` | 就学可能校取得 |
| `selectGKBTMSGAKKU_006(Map<String, Object>)` | `List<Map<String, Object>>` | 就学可能校取得 |
| `selectGKBTMSGAKKU_007(Map<String, Object>)` | `List<Map<String, Object>>` | 就学可能校取得 |
| `selectGKBTMSGAKKU_008(Map<String, Object>)` | `List<Map<String, Object>>` | 就学可能校取得 |
| `selectGABTJUKIIDO_001(String)` | `Map<String, Object>` | 住民記録異動情報取得 |
| `select_GKBTGAKUREIBO_003(String)` | `String` | 学齢簿前履歴処理日取得 |
| `select_GKBWSKT1_001(String)` | `Map<String, Object>` | 不就学の申請取得 |
| `select_GKBWSKT2_001(String)` | `Map<String, Object>` | 就学猶予・免除の申請取得 |
| `select_GKBWSKT3_001(String)` | `Map<String, Object>` | 就学校変更の申請取得 |
| `select_GKBWSKT4_001(String)` | `Map<String, Object>` | 区域外就学の申請取得 |
| `selectGKBTSHOGAKKO_002(String)` | `List<String>` | 小学校コード取得（学校名から） |
| `selectGKBTCHUGAKKO_002(String)` | `List<String>` | 中学校コード取得（学校名から） |
| `selectGKBTGAKUREIBO_009(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 学齢簿情報取得 |
| `selectGABTATENAKIHON_010(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 宛名基本リストから宛名情報取得 |
| `selectGKBTTSUCHISHOKANRI_011()` | `ArrayList<Map<String, Object>>` | 帳票選択情報取得 |
| `selectGABTATENAKIHON_012(String)` | `ArrayList<Map<String, Object>>` | 保護者一覧取得 |
| `selectGKBTTSUCHISHOJKN_013(Map<String, Object>)` | `Map<String, Object>` | 通知書条件テーブル取得 |
| `selectGABTATENAKIHON_014(Long)` | `Map<String, Object>` | 仮更新者・確認更新画面遷移時処理 |
| `selectGKBTTSUCHIBUNMEN_015(int)` | `ArrayList<Map<String, Object>>` | 通知文面設定テーブル取得 |
| `selectGKAFKHAKKOR_016(Map<String, Object>)` | `int` | 帳票発行履歴作成結果 |
| `selectGKBTSHOGAKKO_017(int)` | `Map<String, Object>` | 小学校名マスタ取得 |
| `selectGKBTCHUGAKKO_018(int)` | `Map<String, Object>` | 中学校名マスタ取得 |
| `selectGKBTYOGOGAKKO_019(int)` | `Map<String, Object>` | 盲聾養護学校名マスタ取得 |
| `selectGKBTKUIKIGAI_020(int)` | `Map<String, Object>` | 区域外学校名マスタ取得 |
| `selectGKBTKUNISIRITSUGAKKO_021(int)` | `Map<String, Object>` | 国・私立学校名マスタ取得 |
| `selectGKBTGAKUNEN_022(int)` | `Map<String, Object>` | 学年マスタ取得 |
| `selectGABTATENAKIHON_023(String)` | `Map<String, Object>` | 宛名情報取得 |
| `selectGKBTSHUGAKURIREKI_024(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 就学履歴情報取得 |
| `selectGKBTKOSHINLOG_025(Map<String, Object>)` | `int` | 更新ログ件数取得 |
| `selectGABTATENAKIHON_027(String)` | `Map<String, Object>` | 宛名番号リストから生年月日・履歴番号取得 |
| `funKKAPK0020_FAGEGET(Map<String, Object>)` | `Map<String, Object>` | 年齢取得 |
| `selectGKBTGAKUREIBO_028(Map<String, Object>)` | `Map<String, Object>` | 小・中学校区コード取得 |
| `selectGKBFKGCGET_029(Map<String, Object>)` | `void` | 学校コード取得（共通関数） |
| `selectJIBTJUKIIDO_030(String)` | `ArrayList<Map<String, Object>>` | 対象児童の世帯員取得 |
| `selectGKBTGAKUNENRIREKI_001(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 学年履歴取得 |
| `selectGAKKO_001(Map<String, Object>)` | `Map<String, Object>` | 学校名取得 |
| `selectGKBTGAKUNEN_002(Map<String, Object>)` | `Map<String, Object>` | 学年名取得 |
| `selectGKBTMSGAKUKYUCD_002(Map<String, Object>)` | `Map<String, Object>` | 学級名取得 |
| `selectKKATCD_001(Map<String, Object>)` | `Map<String, Object>` | 学級区分取得 |
| `selectGKBTGAKUREIBO_010(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 学齢簿照会（履歴取得） |
| `selectGKBTGAKUREIBO_011(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 学齢簿異動（履歴取得） |
| `selectGKBTGAKUNENRIREKI_002(Map<String, Object>)` | `ArrayList<Map<String, Object>>` | 学年履歴取得 |
| `selectGKBTSHUGAKURIREKI_001(String)` | `ArrayList<GakureiboShokaiHistoryData>` | 就学変更履歴情報取得（リスト） |
| `selectGKBTSHUGAKURIREKI_002(String)` | `GakureiboShokaiHistoryData` | 就学変更履歴情報取得（単体） |
| `selectGABTGYOSEIJOHOJKN_001(GabtatenakihonData)` | `List<Map<String, Object>>` | 就学指定校取得 |
| `selectGABTATENAKIHON_002(String)` | `GabtatenakihonData` | 宛名基本情報取得 |
| `selectGKBTGAKUREIBO_029(String)` | `Integer` | 学齢簿データ取得 |
| `selectGABTATENAKIHON_004(String)` | `ArrayList<Map<String, Object>>` | 宛名情報取得 |
| `selectGABTATENAKIHON_005(String)` | `ArrayList<Map<String, Object>>` | 宛名情報取得 |
| `selectGKBTGAKUREIBO_006(String)` | `GkbtgakureiboData` | 学齢簿データ取得 |

> **注**: 上記はインタフェースに定義された全メソッドの抜粋です。実装は MyBatis の XML マッピングに委譲されます。

## 3. 依存関係
| 依存クラス / ライブラリ | 用途 |
|--------------------------|------|
| `org.springframework.stereotype.Repository` | Spring に DAO として認識させる |
| `java.util.Map` / `java.util.List` / `java.util.ArrayList` | パラメータ・結果格納 |
| `org.apache.ibatis.annotations.Param` | MyBatis のパラメータ名指定 |
| `jp.co.jip.gkb0000.domain.helper.GabtatenakihonData` | 宛名基本データ |
| `jp.co.jip.gkb0000.domain.helper.GakureiboSearchCondition` | 学齢簿検索条件 |
| `jp.co.jip.gkb0000.domain.helper.GakureiboShokaiData` | 学齢簿情報 |
| `jp.co.jip.gkb0000.domain.helper.GakureiboShokaiHistoryData` | 学齢簿変更履歴 |
| `jp.co.jip.gkb0000.domain.helper.GkbtgakureiboData` | 学齢簿データ |
| `jp.co.jip.gkb0000.domain.helper.Gkbtgkunenrireki` | 学年履歴 |
| `jp.co.jip.gkb0000.domain.helper.HogosyaData` | 保護者情報 |
| `org.apache.ibatis.annotations.Param` | MyBatis の SQL パラメータ名指定 |

> **注**: 依存関係はインタフェースのインポート文およびメソッドシグネチャから抽出しています。実装クラスや XML マッピングファイルにさらに依存がある可能性があります。

## 4. ビジネスフロー
`GKB0010Repository` は多数の取得系メソッドを提供し、呼び出し側（主に Service 層）から以下のようなフローで利用されます。

1. **検索条件作成** – Service 層で `Map` や `*SearchCondition` オブジェクトを組み立てる。  
2. **リポジトリ呼び出し** – 該当メソッドを呼び出し、SQL が実行され結果が取得される。  
3. **結果加工** – 取得した `Map`/`List`/`Data` オブジェクトを Service 層で業務ロジックに合わせて加工。  
4. **画面/帳票へ渡す** – 加工済みデータを Controller 層や帳票生成ロジックへ渡す。  

このフローは各メソッドごとに同様で、特定のビジネスロジックは Service 層で実装されます。  

---