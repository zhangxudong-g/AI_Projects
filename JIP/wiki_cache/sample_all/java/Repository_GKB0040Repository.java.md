## 📄 GKB0040Repository（`jp.co.jip.gkb000.common.repository.GKB0040Repository`）

### 1. 概要概説
- **役割**  
  `GKB0040Repository` は Spring の `@Repository` インタフェースとして定義され、データベースの **参照・更新系 SQL を呼び出す** ためのメソッド群を提供します。  
  主に **就学援助・学校マスタ・通知書条件** など、WizLIFE 系統の業務テーブルに対する CRUD を一元化しています。

- **システム内での位置付け**  
  - Service 層から呼び出され、ビジネスロジックは Service に、SQL 実装は MyBatis の XML マッピングファイルに委譲。  
  - 変更履歴から分かるように、2024/06/06 の **新 WizLIFE 2 次開発** で多数メソッドが追加され、機能拡張が行われました。

- **重要な概念**  
  - **「_」で始まるメソッド名**は、テーブルエイリアス（例：`GKBTGENJIYU`）を示す慣例。  
  - **番号サフィックス（_001, _002 …）**は、要件定義書や設計書での「処理番号」と対応し、変更履歴追跡を容易にします。  
  - 返却型はすべて `ArrayList<Map<String, Object>>`（SELECT 系）か `void`（INSERT/UPDATE/DELETE 系）で、**汎用的なマップ構造**を採用しているため、呼び出し側はカラム名で値を取得します。

---

### 2. コード級洞察

#### 2.1 メソッド構成（機能別に分類）

| カテゴリ | 主なテーブル（エイリアス） | 代表的メソッド（リンク） |
|---|---|---|
| **学年・減事由** | `GKBTGAKUNEN`, `GKBTGENJIYU` | [selectGKBTGAKUNEN_001](http://localhost:3000/projects/all/wiki?file_path=D:/code-wiki/projects/all/sample_all/java/Repository_GKB0040Repository.java) |
| **異動・文書** | `GABTIDOJIYU`, `GKBTIDOBUN` | [select_GABTIDOJIYU_004](http://localhost:3000/projects/all/wiki?file_path=D:/code-wiki/projects/all/sample_all/java/Repository_GKB0040Repository.java) |
| **就学援助・民生委員** | `GKBTMINSEIIIN` | [select_GKBTMINSEIIIN_007](http://localhost:3000/projects/all/wiki?file_path=D:/code-wiki/projects/all/sample_all/java/Repository_GKB0040Repository.java) |
| **学校マスタ** | `GKBTSHOGAKKO`, `GKBTCHUGAKKO` | [selectGKBTSHOGAKKO_022](http://localhost:3000/projects/all/wiki?file_path=D:/code-wiki/projects/all/sample_all/java/Repository_GKB0040Repository.java) |
| **通知書条件** | `GKBTTSUCHISHOKANRI`, `GKBTTSUCHISHOKANRISEIJIN` | [select_GKBTTSUCHISHOKANRI_027](http://localhost:3000/projects/all/wiki?file_path=D:/code-wiki/projects/all/sample_all/java/Repository_GKB0040Repository.java) |
| **コード管理** | `KKATCD`, `KKATCDT` | [selectKKATCD_048](http://localhost:3000/projects/all/wiki?file_path=D:/code-wiki/projects/all/sample_all/java/Repository_GKB0040Repository.java) |
| **就学指定校マスタ** | `GKBTMSSHUGAKUSHITEIKOU`, `GKBTMSSHUGAKUSHITEIKOUKR` | [selectGKBTMSSHUGAKUSHITEIKOU_039](http://localhost:3000/projects/all/wiki?file_path=D:/code-wiki/projects/all/sample_all/java/Repository_GKB0040Repository.java) |

> **ポイント**  
> - **SELECT 系**はすべて `ArrayList<Map<String, Object>>` を返す。  
> - **INSERT / UPDATE / DELETE 系**は `void` で、パラメータは `Map<String, Object>`。  
> - メソッド名に **「select」** が付くものは必ず取得系、**「insert」/「update」/「delete」** が付くものは変更系です。

#### 2.2 呼び出し例（疑似コード）

```java
@Service
public class GkbService {
    @Autowired
    private GKB0040Repository repo;

    // 学年一覧取得
    public List<Map<String, Object>> getGrades() {
        return repo.selectGKBTGAKUNEN_001();
    }

    // 就学援助民生委員情報登録
    public void registerMinsEiIn(Map<String, Object> data) {
        repo.insert_GKBTMINSEIIIN_009(data);
    }
}
```

- **パラメータの構造**は、SQL の `WHERE` 条件や `INSERT` のカラム名と 1 対 1 に対応します。  
- **例外処理**は Spring の `DataAccessException` 系がスローされるので、Service 層で捕捉・変換してください。

#### 2.3 設計上の留意点

| 項目 | 内容 | 推奨対応 |
|---|---|---|
| **型安全性** | `Map<String, Object>` はコンパイル時にキー・型が保証されない | 必要に応じて DTO クラスへ変換し、Service 層でラップする |
| **メソッド数の肥大化** | 40 以上のメソッドが単一インタフェースに集約 | 機能別にサブリポジトリへ分割（例：`GkbSchoolRepository`, `GkbNotificationRepository`） |
| **SQL の可視化** | 実装は MyBatis XML に委譲されるため、コードだけではロジックが不明 | XML マッピングファイルへのリンクを Wiki に追加すると保守性が向上 |
| **トランザクション管理** | 複数更新が必要なケースは Service 層で `@Transactional` を付与 | 変更系メソッド呼び出しは必ず同一トランザクション内で実行 |

---

### 3. 依存関係と関係図

```mermaid
flowchart LR
    subgraph Service
        S1["業務ロジック"] -->|"呼び出し"| R["GKB0040Repository"]
    end
    subgraph MyBatis
        R -->|"SQL マッピング"| X["XML Mapper"]
    end
    subgraph DB
        X -->|"JDBC"| DB["(RDBMS)"]
    end
    classDef repo fill:#f9f,stroke:#333,stroke-width:2px;
    class R repo;
```

- **Service 層** → **GKB0040Repository**（インタフェース）  
- **Repository** → **MyBatis XML Mapper**（`src/main/resources/mapper/...`）  
- **Mapper** → **RDBMS**（Oracle / PostgreSQL 等）  

---

### 4. 今後の拡張・保守ポイント

1. **メソッド命名の統一**  
   - `select_` 系は `select` に統一し、サフィックスは設計書の番号に合わせるだけに留めると可読性が上がります。

2. **DTO への置き換え**  
   - `Map<String, Object>` から POJO（例：`GradeDto`, `SchoolDto`）へ変更し、型安全と IDE 補完を活かす。

3. **リポジトリ分割**  
   - 大規模化が予想されるので、**機能別サブインタフェース**（例：`SchoolRepository`, `NotificationRepository`）を作成し、`@Repository` の実装クラスで `extends` させる。

4. **テスト戦略**  
   - MyBatis の XML が外部依存になるため、**Mapper テスト**は H2 などのインメモリ DB で実行し、SQL の正当性を検証。

---

### 5. 参考リンク

- **MyBatis XML マッピング例**（同プロジェクト内）  
  `src/main/resources/mapper/GKB0040Mapper.xml`（※実際のパスはプロジェクト構成に合わせてリンクしてください）

- **Service 層サンプル**  
  `src/main/java/jp/co/jip/gkb000/service/GkbService.java`

- **Spring Data JPA との比較**（設計検討資料）  
  `docs/architecture/RepositoryComparison.md`

--- 

> **新規開発者へのメッセージ**  
> このインタフェースは「**テーブルごとの CRUD を名前で一意に表現**」することを目的に作られています。  
> まずは **どのテーブル・業務フロー**に関係するメソッドかを把握し、**Service → Repository → Mapper → DB** の流れを追うことが理解の近道です。  
> 必要に応じて上記のリファクタリング案を検討し、保守しやすいコードベースへ徐々に移行してください。