# GKB0010Repository（`jp.co.jip.gkb0000.domain.repository.GKB0010Repository`）

## 📖 概要
`GKB0010Repository` は、学齢簿・宛名情報・各種マスタ取得・申請データ取得など、**WizLIFE 系統の教育・福祉系統データ** に対する SQL マッピングインタフェースです。  
Spring の `@Repository` アノテーションが付与されており、MyBatis が実装クラスを自動生成します。

> **対象読者**  
> - 新規参画エンジニア  
> - データ取得ロジックを拡張・保守したい開発者  
> - テストコードを書きたい QA エンジニア  

---

## 🗂️ 目次
1. [変更履歴](#変更履歴)  
2. [主要機能カテゴリ](#主要機能カテゴリ)  
   - 2.1 [備考情報取得](#備考情報取得)  
   - 2.2 [宛名・保護者情報取得](#宛名保護者情報取得)  
   - 2.3 [学齢簿関連](#学齢簿関連)  
   - 2.4 [学校・学年マスタ取得](#学校学年マスタ取得)  
   - 2.5 [就学・申請情報取得](#就学申請情報取得)  
   - 2.6 [汎用ユーティリティ](#汎用ユーティリティ)  
3. [メソッド一覧（サマリ）](#メソッド一覧サマリ)  
4. [設計上の留意点](#設計上の留意点)  
5. [利用例（サンプルコード）](#利用例サンプルコード)  

---

## 🔧 変更履歴
| 日付 | 担当 | バージョン | 内容 |
|------|------|------------|------|
| 2024/06/03 | zczl.wangdi | GKB_0.3.000.000 | 新 WizLIFE 2 次開発追加 |
| 2024/06/07 | zczl.wangj | GKB_0.3.000.000 | 同上 |
| 2024/06/11 | ZCZL.xuhongyu | GKB_0.3.000.000 | 同上 |
| 2024/06/18 | zczl.gengming | GKB_0.3.000.000 | 同上 |
| 2025/05/27 | ZCZL.DY | 1.0.006.000 | GK_QA13923(16522) 二次対応：就学指定校修正 |
| 2025/10/01 | CTC.GL | 1.0.107.001 | GKB_21701 対応 |
| 2025/12/16 | ZCZL.chengjx | 1.0.404.000 | 新 WizLIFE 保守対応 QA23166 |

---

## 📂 主要機能カテゴリ

### 1. 備考情報取得
| メソッド | 説明 |
|----------|------|
| `selectBIKOSENTAKU_001(Map<String,Object>)` | 備考情報（基本テーブル部分）取得 |
| `selectGETBIKO_002(Map<String,Object>)` | 同上（別名） |
| `selectGABVATENAALL_003(Map<String,Object>)` | 保護者宛名異動履歴取得 |
| `selectGABVATENAALL_004(Map<String,Object>)` | 児童宛名異動履歴取得 |
| `selectGKBTHYODAIKANRI_005()` | 通知書タイトル取得 |

### 2. 宛名・保護者情報取得
| メソッド | 説明 |
|----------|------|
| `select_GABTATENARIREKI_001(String kojinNo, String rirekiRenban)` | 宛名情報（履歴連番指定）取得 |
| `select_GABTATENAKIHON_001(String kojinNo, String rirekiRenban)` | 児童宛名情報取得 |
| `select_GABTATENAKIHON_002(String kojinNo, String rirekiRenban)` | 保護者宛名情報取得 |
| `select_GABVATENAALL_002(String kojinNo)` | 宛名情報（最新）取得 |
| `selectGABTATENAKIHON_002(String kojinNo)` | 宛名基本情報取得（単体） |
| `selectGABTATENAKIHON_004/005(String kojinNo)` | 追加取得（2025/10 更新） |

### 3. 学齢簿関連
| メソッド | 説明 |
|----------|------|
| `selectGKBTGAKUREIBO_001(String kojinNo)` | 学齢簿履歴連番リスト取得 |
| `selectGKBTGAKUREIBO_002(GakureiboSearchCondition)` | 学齢簿情報取得（単体） |
| `selectGKBTGAKUREIBO_009(Map<String,Object>)` | 学齢簿情報取得（汎用） |
| `select_GKBTGAKUREIBO_001(String kojinNo)` | 最新学齢簿データ取得 |
| `select_GKBTGAKUREIBO_002(String kojinNo)` | 学齢簿データリスト取得 |
| `selectGKBTGAKUREIBO_010/011(Map<String,Object>)` | 学齢簿履歴取得（照会・異動） |
| `selectGKBTGAKUREIBO_028(Map<String,Object>)` | 小・中学校区コード取得 |
| `selectGKBTGAKUREIBO_029(String kojinNo)` | 2025/10 追加：学齢簿件数取得 |

### 4. 学校・学年マスタ取得
| メソッド | 説明 |
|----------|------|
| `selectGKBTGAKUNEN_001(String gakunenCd)` | 学年マスタ取得 |
| `selectGKBTGAKUNEN_022(int gakunenCd)` | 学年マスタ取得（別バージョン） |
| `selectGKBTGAKUNEN_002(Map<String,Object>)` | 学年名取得 |
| `selectGKAFKGKOGTEQ_001(Map<String,Object>)` | 学校名取得 |
| `selectGKBTKUNISIRITSUGAKKO_001/021(String gakkoCd)` | 国・私立学校情報取得 |
| `selectGKBTKUIKIGAI_001/020(String gakkoCd)` | 区域外学校情報取得 |
| `selectGKBTYOGOGAKKO_001/019(String gakkoCd)` | 盲聾養護学校情報取得 |
| `selectGKBTCHUGAKKO_001/002(String gakkoCd)` | 中学校情報取得 |
| `selectGKBTSHOGAKKO_001/002(String gakkoCd)` | 小学校情報取得 |
| `selectGKBTMSGAKUKYUCD_001/002(@Param…)` | 学級区分情報取得 |
| `selectGKBTMSGAKKU_001~008(...)` | 学校区情報・就学可能校取得 |

### 5. 就学・申請情報取得
| メソッド | 説明 |
|----------|------|
| `select_GKBWSKT1_001(String shinseiKanriRenban)` | 不就学申請データ取得 |
| `select_GKBWSKT2_001(String shinseiKanriRenban)` | 就学猶予・免除申請データ取得 |
| `select_GKBWSKT3_001(String shinseiKanriRenban)` | 就学校変更申請データ取得 |
| `select_GKBWSKT4_001(String shinseiKanriRenban)` | 区域外就学申請データ取得 |
| `selectGKBTSHUGAKURIREKI_001(String kojin_no)` | 就学変更履歴リスト取得 |
| `selectGKBTSHUGAKURIREKI_002(String kojin_no)` | 就学変更履歴単体取得 |
| `selectGABTGYOSEIJOHOJKN_001(GabtatenakihonData)` | 就学指定校取得（2025/05 更新） |

### 6. 汎用ユーティリティ
| メソッド | 説明 |
|----------|------|
| `selectFDateSW_001(Map<String,Object>)` | 西暦→和暦変換 |
| `selectGKBFKZKGMGET_001/002(Map<String,Object>)` | 続柄名取得 |
| `selectGKBFKGKKUGET_001(Map<String,Object>)` | 校区情報取得 |
| `selectGKBFKGCGET_029(Map<String,Object>)` | 学校コード取得（共通関数） |
| `selectJIBTJUKIIDO_030(String kojinNo)` | 住民記録異動情報取得 |
| `selectGKBTKOSHINLOG_025(Map<String,Object>)` | 更新ログ件数取得 |
| `funKKAPK0020_FAGEGET(Map<String,Object>)` | 年齢取得 |
| `selectGKBTKUIKIGAIKANRI_001(String kojinNo)` | 区域外管理データ件数取得 |
| `selectGABTJUKIIDO_001(String kojinNo)` | 住民記録異動情報取得（別名） |
| `selectGKBTGAKUNENRIREKI_003(String kojinNo)` | 学年最新履歴取得 |
| `selectGKBTTSUCHISHOKANRI_011()` | 帳票選択情報取得 |
| `selectGKBTTSUCHISHOJKN_013(Map<String,Object>)` | 通知書条件テーブル取得 |
| `selectGKBTTSUCHIBUNMEN_015(int chohyoKbn)` | 通知文面設定テーブル取得 |
| `selectGKAFKHAKKOR_016(Map<String,Object>)` | 帳票発行履歴作成 |
| `selectGKBTKOSHINLOG_025(Map<String,Object>)` | 更新ログ件数取得 |
| `selectGKBTGAKUREIBO_029(String kojinNo)` | 学齢簿件数取得（2025/10 追加） |

---

## 📋 メソッド一覧（サマリ）

> **注**：以下は主要メソッドのシグネチャと簡易説明です。実装は MyBatis の XML/アノテーションに委譲されます。  

| メソッド名 | パラメータ | 戻り値 | 概要 |
|------------|------------|--------|------|
| `selectBIKOSENTAKU_001` | `Map<String,Object> param` | `ArrayList<Map<String,Object>>` | 備考情報取得 |
| `selectGETBIKO_002` | 同上 | 同上 | 同上 |
| `selectGABVATENAALL_003` | `Map<String,Object> param` | `ArrayList<Map<String,Object>>` | 保護者宛名異動履歴 |
| `selectGABVATENAALL_004` | 同上 | 同上 | 児童宛名異動履歴 |
| `selectGKBTHYODAIKANRI_005` | なし | `ArrayList<Map<String,Object>>` | 通知書タイトル |
| `selectGKBTGAKUREIBO_001` | `String kojinNo` | `ArrayList<String>` | 学齢簿履歴連番リスト |
| `selectGKBTGAKUREIBO_002` | `GakureiboSearchCondition condition` | `GakureiboShokaiData` | 学齢簿情報取得 |
| `selectGKBTGAKUREIBO_009` | `Map<String,Object> map` | `ArrayList<Map<String,Object>>` | 学齢簿情報取得（汎用） |
| `selectGKBTGAKUREIBO_010` | `Map<String,Object> param` | `ArrayList<Map<String,Object>>` | 学齢簿照会履歴 |
| `selectGKBTGAKUREIBO_011` | `Map<String,Object> param` | `ArrayList<Map<String,Object>>` | 学齢簿異動履歴 |
| `selectGKBTGAKUREIBO_006` | `String kojinNo` | `GkbtgakureiboData` | 最新学齢簿データ（保守対応） |
| `select_GABTATENARIREKI_001` | `String kojinNo, String rirekiRenban` | `GabtatenakihonData` | 宛名情報（履歴） |
| `select_GABTATENAKIHON_001` | 同上 | `GabtatenakihonData` | 児童宛名情報 |
| `select_GABTATENAKIHON_002` | 同上 | `GabtatenakihonData` | 保護者宛名情報 |
| `select_GABVATENAALL_002` | `String kojinNo` | `GabtatenakihonData` | 宛名最新情報 |
| `selectGKBTGAKUNEN_001` | `String gakunenCd` | `Map<String,String>` | 学年マスタ取得 |
| `selectGKBTGAKUNEN_022` | `int gakunenCd` | `Map<String,Object>` | 学年マスタ取得（別バージョン） |
| `selectGKBTMSGAKUKYUCD_001` | `@Param("gakkoKbnCd") String, @Param("gakkoCd") String, @Param("gakukyuCd") String` | `Map<String,Object>` | 学級区分取得 |
| `selectGKBTMSGAKKU_001~008` | `GabtatenakihonData` / `Map<String,Object>` | `List<Map<String,Object>>` | 学校区情報・就学可能校取得 |
| `select_GKBWSKT1_001` | `String shinseiKanriRenban` | `Map<String,Object>` | 不就学申請取得 |
| `select_GKBWSKT2_001` | 同上 | 同上 | 就学猶予・免除申請取得 |
| `select_GKBWSKT3_001` | 同上 | 同上 | 就学校変更申請取得 |
| `select_GKBWSKT4_001` | 同上 | 同上 | 区域外就学申請取得 |
| `selectGABTGYOSEIJOHOJKN_001` | `GabtatenakihonData` | `List<Map<String,Object>>` | 就学指定校取得 |
| `selectFDateSW_001` | `Map<String,Object> param` | `void` | 西暦→和暦変換 |
| `selectGKBFKZKGMGET_001/002` | `Map<String,Object> param` | `void` | 続柄名取得 |
| `selectGKBFKGKKUGET_001` | `Map<String,Object> param` | `void` | 校区情報取得 |
| `selectGKBTKUIKIGAIKANRI_001` | `String kojinNo` | `int` | 区域外管理データ件数 |
| `selectGKBTKOSHINLOG_025` | `Map<String,Object> param` | `int` | 更新ログ件数 |
| `funKKAPK0020_FAGEGET` | `Map<String,Object> param` | `Map<String,Object>` | 年齢取得 |
| `selectGKBTTSUCHISHOKANRI_011` | なし | `ArrayList<Map<String,Object>>` | 帳票選択情報取得 |
| `selectGKBTTSUCHISHOJKN_013` | `Map<String,Object> paramMap` | `Map<String,Object>` | 通知書条件取得 |
| `selectGKBTTSUCHIBUNMEN_015` | `int chohyoKbn` | `ArrayList<Map<String,Object>>` | 通知文面設定取得 |
| `selectGKAFKHAKKOR_016` | `Map<String,Object> paramMap` | `int` | 帳票発行履歴作成 |

> **※** ここに列挙したものは全メソッドの一部です。実際のインタフェースは 150 以上のメソッドを保持しています。

---

## 🛠️ 設計上の留意点

1. **インタフェース肥大化**  
   - 1 つのリポジトリに多数の機能が集約されているため、変更時に影響範囲が広がりやすい。機能別にサブリポジトリへ分割することを検討してください。

2. **戻り値の一貫性**  
   - `ArrayList<Map<String,Object>>` が多用されていますが、型安全性が低く、呼び出し側でキャストが必要です。DTO クラスへの置き換えを推奨します。

3. **パラメータの過剰使用**  
   - `Map<String,Object>` を大量に受け渡す設計は柔軟ですが、IDE の補完が効かずミスが起きやすい。検索条件は専用の POJO にまとめると可読性が向上します。

4. **MyBatis アノテーション vs XML**  
   - 本インタフェースは XML マッピングが前提です。SQL が増えると XML が肥大化し、メンテナンスが困難になるため、`@SelectProvider` 等の動的 SQL 生成も検討してください。

5. **トランザクション管理**  
   - `@Repository` のみでトランザクションは付与されません。サービス層で `@Transactional` を適切に設定してください。

6. **バージョニング**  
   - コメントにバージョン情報が散在しています。Git のタグと合わせてリリースノートを自動生成できる仕組みを導入すると管理が楽になります。

---

## 💡 利用例（サンプルコード）

```java
@Service
@RequiredArgsConstructor
public class GakureiboService {

    private final GKB0010Repository repository;

    /**
     * 学齢簿情報と保護者情報をまとめて取得する例
     */
    public GakureiboDetail getDetail(String kojinNo) {
        // 学齢簿情報取得
        GakureiboShokaiData gakureibo = repository.selectGKBTGAKUREIBO_002(
                new GakureiboSearchCondition(kojinNo));

        // 保護者情報取得
        HogosyaData hogosya = repository.selectGKBTGAKUREIBO_003(
                new GakureiboSearchCondition(kojinNo));

        // 住所・学年情報取得（例：学年マスタ）
        Map<String, String> gakunen = repository.selectGKBTGAKUNEN_001(
                gakureibo.getGakunenCd());

        // 結果を DTO にまとめる
        return new GakureiboDetail(gakureibo, hogosya, gakunen);
    }

    /**
     * 就学指定校リストを取得（2025/05 更新分）
     */
    public List<Map<String, Object>> getSpecifiedSchools(GabtatenakihonData data) {
        return repository.selectGABTGYOSEIJOHOJKN_001(data);
    }
}
```

> **ポイント**  
> - `selectGKBTGAKUREIBO_002` では検索条件オブジェクト `GakureiboSearchCondition` を使用し、可読性を確保。  
> - 取得したマップは DTO に変換してサービス層で扱うことで、上位層への型安全なデータ提供が可能です。

---

## 📎 関連 Wiki ページへのリンク例

- `[selectGKBTGAKUREIBO_002](http://localhost:3000/projects/test_new/wiki?file_path=code/java/Repository_GKB0010Repository.java)`  
- `[selectGABTGYOSEIJOHOJKN_001](http://localhost:3000/projects/test_new/wiki?file_path=code/java/Repository_GKB0010Repository.java)`  

（実際のファイルパスはプロジェクト構成に合わせて調整してください）

--- 

**以上**  
このドキュメントは `Repository_GKB0010Repository.java` の主要機能と設計上の注意点をまとめたものです。新規実装やリファクタリングの際は、上記ポイントを踏まえてコードベースの保守性向上にご活用ください。