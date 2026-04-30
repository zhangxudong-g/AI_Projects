## 概要概説
このファイル **GKBEKENSU_RECORD.SQL** は、データベース層で使用される **オブジェクト型 `GKBEKENSU_RECORD`** を定義しています。  
- **目的**: 画面やバッチ処理で扱う「件数」情報を一括で受け渡すための構造体。  
- **システム内での位置付け**: PL/SQL のプロシージャ/ファンクションやカーソルの結果セットとして利用され、`INFO`/`INPUT`/`OUTPUT` の区分別に件数データを保持します。  

> **重要なシンボル**  
> - `GKBEKENSU_RECORD` (オブジェクト型)  
> - `CNT` : 件数 (NUMBER)  
> - `NAIYOU` : 件数名称 (NVARCHAR2(1000))  
> - `KBN` : 件数区分 (NUMBER) – `0: INFO`, `1: INPUT`, `2: OUTPUT`

## コードレベル洞察
### オブジェクト型定義

```sql
CREATE OR REPLACE TYPE GKBEKENSU_RECORD FORCE AS OBJECT (
     CNT     NUMBER,          --件数
     NAIYOU  NVARCHAR2(1000), --件数名称
     KBN     NUMBER           --件数区分 INFO：0、INPUT：1、OUTPUT：2
);
/
```

| 属性 | データ型 | 意味・用途 | 補足 |
|------|----------|------------|------|
| `CNT` | `NUMBER` | 件数そのもの | 集計結果や処理件数を格納 |
| `NAIYOU` | `NVARCHAR2(1000)` | 件数の名称・説明 | 日本語文字列を想定 |
| `KBN` | `NUMBER` | 件数の区分 | `0`=INFO、`1`=INPUT、`2`=OUTPUT と固定 |

- **`FORCE`** オプションは、依存オブジェクトが存在しなくても型を作成できるようにし、デプロイ時の順序依存を緩和します。  
- この型は **スカラー型** ではなく **オブジェクト型** であるため、テーブルのカラムや PL/SQL のコレクション (`TABLE OF GKBEKENSU_RECORD`) に直接使用可能です。  

### 典型的な利用シーン
1. **集計結果の返却**  
   ```sql
   SELECT GKBEKENSU_RECORD(cnt, '処理件数', 1) INTO v_rec FROM ...;
   ```
2. **コレクションでのバルク操作**  
   ```sql
   TYPE rec_tab IS TABLE OF GKBEKENSU_RECORD;
   v_tab rec_tab;
   SELECT GKBEKENSU_RECORD(cnt, name, kbn) BULK COLLECT INTO v_tab FROM ...;
   ```

## 依存関係と関係
- **他モジュールからの参照**  
  - PL/SQL パッケージやストアドプロシージャで `GKBEKENSU_RECORD` を戻り値またはパラメータとして使用。  
  - テーブル定義で `GKBEKENSU_RECORD` をオブジェクト型カラムとして使用するケースは稀ですが、可能です。  

- **関連ファイル**  
  - 同一スキーマ内で `GKBEKENSU_RECORD` を利用する SQL/PLSQL ファイルは、`GKBEKENSU_*.SQL` 系列に集約されていることが多いです。  

- **リンク**  
  - [`GKBEKENSU_RECORD` 型定義](http://localhost:3000/projects/all/wiki?file_path=D:/code-wiki/projects/all/sample_all/sql/GKBEKENSU_RECORD.SQL)

---

### 新規開発者へのアドバイス
- **型の変更は慎重に**: 既存の PL/SQL ロジックやコレクションがこの型に依存しているため、属性追加やデータ型変更は影響範囲を事前に検索（`grep -r GKBEKENSU_RECORD`）してください。  
- **テストケースの追加**: 変更後は、`GKBEKENSU_RECORD` を使用する全プロシージャ/関数の単体テストを実行し、`KBN` の区分ロジックが正しく機能することを確認します。  
- **ドキュメントの一貫性**: 新たに属性を追加した場合は、本 Wiki ページとコードコメントの両方を更新し、利用者が即座に把握できるようにしてください。