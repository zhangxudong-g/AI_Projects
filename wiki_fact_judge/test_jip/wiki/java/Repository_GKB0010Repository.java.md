# GKB0010Repository

## 1. 目的
`GKB0010Repository` は **Spring の DAO コンポーネント** で、学齢簿（学籍情報）や保護者・児童の宛名情報、各種マスタデータ、就学関連申請データなど、幅広い業務テーブルに対する **SELECT 系統の SQL 実行メソッド** を提供します。  
**注意**: コード中に業務目的の明示的なコメントは無く、クラス名とメソッドの Javadoc から推測した目的です。

## 2. 主要メソッド
| メソッド | 戻り値 | 説明 |
|---|---|---|
| `selectBIKOSENTAKU_001(Map<String, Object> param)` | `ArrayList<Map<String, Object>>` | 備考情報（基本テーブル部分）を取得 |
| `selectGETBIKO_002(Map<String, Object> param)` | `ArrayList<Map<String, Object>>` | 備考取得（基本テーブル部分） |
| `selectGABVATENAALL_003(Map<String, Object> param)` | `ArrayList<Map<String, Object>>` | 保護者宛名異動履歴取得 |
| `selectGABVATENAALL_004(Map<String, Object> param)` | `ArrayList<Map<String, Object>>` | 児童生徒宛名異動履歴取得 |
| `selectGKBTHYODAIKANRI_005()` | `ArrayList<Map<String, Object>>` | 通知書タイトル取得 |
| `selectGABTATENAKIHON_006(Map<String, Object> param)` | `ArrayList<Map<String, Object>>` | 候補者一覧取得 |
| `selectninshobunSentaku_007(Map<String, Object> map)` | `ArrayList<Map<String, Object>>` | 認証情報（基本テーブル）取得 |
| `selectgetNinshobun_008(Map<String, Object> map)` | `ArrayList<Map<String, Object>>` | 認証情報（基本テーブル）取得 |
| `selectGKBTGAKUREIBO_001(String kojinNo)` | `ArrayList<String>` | 学齢簿生徒履歴連番リスト取得 |
| `selectGKBTGAKUREIBO_002(GakureiboSearchCondition condition)` | `GakureiboShokaiData` | 学齢簿情報取得 |
| `selectGKBTGAKUREIBO_003(GakureiboSearchCondition condition)` | `HogosyaData` | 保護者情報取得 |
| `selectGABTIDOJIYU_001(String jiyuCd)` | `String` | 異動事由取得 |
| `selectGKBTSHIMEIJKN_001(String kojinNo)` | `Integer` | 本名使用制御管理データ数取得 |
| `selectGKBFKZKGMGET_001(Map<String, Object> param)` | `void` | 続柄名取得 |
| `selectGKBFKZKGMGET_002(Map<String, Object> param)` | `void` | 続柄名取得 |
| `selectGKAFKGKOGTEQ_001(Map<String, Object> param)` | `void` | 学校名取得 |
| `selectGKBTGAKUNEN_001(String gakunenCd)` | `Map<String, String>` | 学年マスタ情報取得 |
| `selectGKBTSHOGAKKO_001(String gakkoCd)` | `Map<String, String>` | 小学校情報取得 |
| `selectGKBTCHUGAKKO_001(String gakkoCd)` | `Map<String, String>` | 中学校情報取得 |
| `selectGKBTYOGOGAKKO_001(String gakkoCd)` | `Map<String, String>` | 盲聾養護学校情報取得 |
| `selectGKBTKUIKIGAI_001(String gakkoCd)` | `Map<String, String>` | 区域外学校情報取得 |
| `selectGKBTKUNISIRITSUGAKKO_001(String gakkoCd)` | `Map<String, String>` | 国・私立学校情報取得 |
| `selectGKBTMSGAKUKYUCD_001(String gakkoKbnCd, String gakkoCd, String gakukyuCd)` | `Map<String, Object>` | 学級区分情報取得 |
| `selectGKBFKGKKUGET_001(Map<String, Object> param)` | `void` | 校区情報取得 |
| `selectFDateSW_001(Map<String, Object> param)` | `void` | 西暦→和暦変換 |
| `selectGKBTGAKUREIBO_004(String kojinNo)` | `List<Map<String, String>>` | 兄弟情報取得 |
| `selectGKBTKUIKIGAIKANRI_001(String kojinNo)` | `int` | 区域外管理データ件数取得 |
| `select_GKBTGAKUREIBO_001(String kojinNo)` | `GkbtgakureiboData` | 最新学齢簿データ取得 |
| `select_GKBTGAKUREIBO_002(String kojinNo)` | `List<GkbtgakureiboData>` | 学齢簿データリスト取得 |
| `select_GABTATENARIREKI_001(String kojinNo, String rirekiRenban)` | `GabtatenakihonData` | 宛名情報取得（履歴） |
| `select_GABTATENAKIHON_001(String kojinNo, String rirekiRenban)` | `GabtatenakihonData` | 児童宛名情報取得 |
| `select_GABTATENAKIHON_002(String kojinNo, String rirekiRenban)` | `GabtatenakihonData` | 保護者宛名情報取得 |
| `select_GABVATENAALL_002(String kojinNo)` | `GabtatenakihonData` | 宛名情報取得 |
| `selectGKBTGAKUNENRIREKI_003(String kojinNo)` | `Gkbtgkunenrireki` | 学年最新履歴取得 |
| `selectGKBTMSGAKKU_001(GabtatenakihonData joken)` | `List<Map<String, Object>>` | 小学校区情報取得 |
| `selectGKBTMSGAKKU_002(GabtatenakihonData joken)` | `List<Map<String, Object>>` | 小学校区情報取得 |
| `selectGKBTMSGAKKU_003(GabtatenakihonData joken)` | `List<Map<String, Object>>` | 中学校区情報取得 |
| `selectGKBTMSGAKKU_004(GabtatenakihonData joken)` | `List<Map<String, Object>>` | 中学校区情報取得 |
| `selectGKBTMSGAKKU_005(Map<String, Object> joken)` | `List<Map<String, Object>>` | 就学可能校取得 |
| `selectGKBTMSGAKKU_006(Map<String, Object> joken)` | `List<Map<String, Object>>` | 就学可能校取得 |
| `selectGKBTMSGAKKU_007(Map<String, Object> joken)` | `List<Map<String, Object>>` | 就学可能校取得 |
| `selectGKBTMSGAKKU_008(Map<String, Object> joken)` | `List<Map<String, Object>>` | 就学可能校取得 |
| `selectGABTJUKIIDO_001(String kojinNo)` | `Map<String, Object>` | 住民記録異動情報取得 |
| `select_GKBTGAKUREIBO_003(String kojinNo)` | `String` | 学齢簿前履歴処理日取得 |
| `select_GKBWSKT1_001(String shinseiKanriRenban)` | `Map<String, Object>` | 不就学の申請取得 |
| `select_GKBWSKT2_001(String shinseiKanriRenban)` | `Map<String, Object>` | 就学猶予・免除の申請取得 |
| `select_GKBWSKT3_001(String shinseiKanriRenban)` | `Map<String, Object>` | 就学校変更の申請取得 |
| `select_GKBWSKT4_001(String shinseiKanriRenban)` | `Map<String, Object>` | 区域外就学の申請取得 |
| `selectGKBTSHOGAKKO_002(String gakkoMei)` | `List<String>` | 小学校名から学校コード取得 |
| `selectGKBTCHUGAKKO_002(String gakkoMei)` | `List<String>` | 中学校名から学校コード取得 |
| `selectGKBTGAKUREIBO_009(Map<String, Object> map)` | `ArrayList<Map<String, Object>>` | 学齢簿情報取得 |
| `selectGABTATENAKIHON_010(Map<String, Object> param)` | `ArrayList<Map<String, Object>>` | 宛名基本リストから宛名情報取得 |
| `selectGKBTTSUCHISHOKANRI_011()` | `ArrayList<Map<String, Object>>` | 帳票選択情報取得 |
| `selectGABTATENAKIHON_012(String kojinNo)` | `ArrayList<Map<String, Object>>` | 保護者一覧取得 |
| `selectGKBTTSUCHISHOJKN_013(Map<String, Object> paramMap)` | `Map<String, Object>` | 通知書条件テーブル取得 |
| `selectGABTATENAKIHON_014(Long kojinNo)` | `Map<String, Object>` | 仮更新者・確認更新画面遷移処理 |
| `selectGKBTTSUCHIBUNMEN_015(int chohyoKbn)` | `ArrayList<Map<String, Object>>` | 通知文面設定テーブル取得 |
| `selectGKAFKHAKKOR_016(Map<String, Object> paramMap)` | `int` | 帳票発行履歴作成 |
| `selectGKBTSHOGAKKO_017(int tennyumaeGakoCd)` | `Map<String, Object>` | 小学校名マスタ取得 |
| `selectGKBTCHUGAKKO_018(int tennyumaeGakoCd)` | `Map<String, Object>` | 中学校名マスタ取得 |
| `selectGKBTYOGOGAKKO_019(int tennyumaeGakoCd)` | `Map<String, Object>` | 盲聾養護学校名マスタ取得 |
| `selectGKBTKUIKIGAI_020(int tennyumaeGakoCd)` | `Map<String, Object>` | 区域外学校名マスタ取得 |
| `selectGKBTKUNISIRITSUGAKKO_021(int tennyumaeGakoCd)` | `Map<String, Object>` | 国・私立学校名マスタ取得 |
| `selectGKBTGAKUNEN_022(int gakunenCd)` | `Map<String, Object>` | 学年マスタ取得 |
| `selectGABTATENAKIHON_023(String kojinNo)` | `Map<String, Object>` | 宛名情報取得 |
| `selectGKBTSHUGAKURIREKI_024(Map<String, Object> paramMap)` | `ArrayList<Map<String, Object>>` | 就学履歴情報取得 |
| `selectGKBTKOSHINLOG_025(Map<String, Object> param)` | `int` | 更新ログ件数取得 |
| `selectGABTATENAKIHON_027(String kojinNo)` | `Map<String, Object>` | 宛名番号リストから生年月日・履歴番号取得 |
| `funKKAPK0020_FAGEGET(Map<String, Object> param)` | `Map<String, Object>` | 年齢取得 |
| `selectGKBTGAKUREIBO_028(Map<String, Object> param)` | `Map<String, Object>` | 小学校区コード・中学校区コード取得 |
| `selectGKBFKGCGET_029(Map<String, Object> gakoParam)` | `void` | 学校コード取得（共通関数） |
| `selectJIBTJUKIIDO_030(String kojinNo)` | `ArrayList<Map<String, Object>>` | 対象児童の世帯員取得 |
| `selectGKBTGAKUNENRIREKI_001(Map<String, Object> param)` | `ArrayList<Map<String, Object>>` | 学年履歴取得 |
| `selectGAKKO_001(Map<String, Object> param)` | `Map<String, Object>` | 学校名取得 |
| `selectGKBTGAKUNEN_002(Map<String, Object> param)` | `Map<String, Object>` | 学年名取得 |
| `selectGKBTMSGAKUKYUCD_002(Map<String, Object> param)` | `Map<String, Object>` | 学級名取得 |
| `selectKKATCD_001(Map<String, Object> param)` | `Map<String, Object>` | 学級区分取得 |
| `selectGKBTGAKUREIBO_010(Map<String, Object> param)` | `ArrayList<Map<String, Object>>` | 学齢簿照会 学齢簿履歴取得 |
| `selectGKBTGAKUREIBO_011(Map<String, Object> param)` | `ArrayList<Map<String, Object>>` | 学齢簿異動 学齢簿履歴取得 |
| `selectGKBTGAKUNENRIREKI_002(Map<String, Object> param)` | `ArrayList<Map<String, Object>>` | 学年履歴取得 |
| `selectGKBTSHUGAKURIREKI_001(String kojin_no)` | `ArrayList<GakureiboShokaiHistoryData>` | 就学変更履歴情報取得（一覧） |
| `selectGKBTSHUGAKURIREKI_002(String kojin_no)` | `GakureiboShokaiHistoryData` | 就学変更履歴情報取得（単体） |
| `selectGABTGYOSEIJOHOJKN_001(GabtatenakihonData gabtatenakihonData)` | `List<Map<String, Object>>` | 就学指定校取得 |
| `selectGABTATENAKIHON_002(String kojinNo)` | `GabtatenakihonData` | 宛名基本情報取得 |
| `selectGKBTGAKUREIBO_029(String kojinNo)` | `Integer` | 学齢簿データ件数取得 |
| `selectGABTATENAKIHON_004(String kojinNo)` | `ArrayList<Map<String, Object>>` | 宛名情報取得（一覧） |
| `selectGABTATENAKIHON_005(String kojinNo)` | `ArrayList<Map<String, Object>>` | 宛名情報取得（一覧） |
| `selectGKBTGAKUREIBO_006(String kojinNo)` | `GkbtgakureiboData` | 学齢簿データ取得 |

## 3. 依存関係
| 依存 | 用途 |
|---|---|
| `org.springframework.stereotype.Repository` | Spring が DAO コンポーネントとして認識 |
| `org.apache.ibatis.annotations.Param` | MyBatis のパラメータバインディングに使用 |
| 各 `jp.co.jip.gkb0000.domain.helper.*` クラス | メソッドの引数・戻り値として使用されるヘルパー/データオブジェクト |

---