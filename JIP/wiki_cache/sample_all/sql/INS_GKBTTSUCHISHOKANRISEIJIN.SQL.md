## 概要概述
**ファイル**: `INS_GKBTTSUCHISHOKANRISEIJIN.SQL`  
**目的**: `GKBTTSUCHISHOKANRISEIJIN` テーブルに、成人式案内通知書のテンプレートレコードを 1 件挿入する SQL スクリプトです。  
**システム上の位置付け**:  
- 本テーブルは「通知書（案内文）管理」機能のマスタ/テンプレート領域です。  
- 本 INSERT は、システム初期化時や新規テンプレート追加時に実行され、通知書生成ロジックが参照するデータを提供します。  

> **重要ポイント**  
> - `CHOHYO_KBN = '1'` は「案内通知書」カテゴリを示す固定値です。  
> - `SYS_SHOKUINKOJIN_NO` と `SYS_TANMATU_NO` はシステム管理用のメタ情報で、バージョン管理や更新者トラッキングに利用されます。  

---

## コード級洞察

### 1. INSERT 文全体の流れ
| 手順 | 内容 |
|------|------|
| **1** | `GKBTTSUCHISHOKANRISEIJIN` テーブルへレコードを追加 |
| **2** | 各カラムに対して固定文字列・数値・NULL を設定 |
| **3** | `DATE_MEI3` 以降の本文は文字列結合 (`||`) で改行コード (`CHR(13)||CHR(10)`) を埋め込み、可読性のある通知文を構築 |
| **4** | `SYS_SAKUSEIBI` に `20251201`（作成日）を設定、`SYS_KOSHINBI` は `0`（未更新） |
| **5** | `SYS_JIKAN` は `0`（デフォルト）、`SYS_SHOKUINKOJIN_NO` に `'90002'`、`SYS_TANMATU_NO` に `'1.0.000.000'` を設定 |
| **6** | スクリプトは `/` で終了し、SQL*Plus 等のクライアントで実行可能 |

### 2. カラム別意味合い

| カラム | 目的・意味 | 例・備考 |
|--------|------------|----------|
| `CHOHYO_KBN` | 通知書種別コード（固定 `'1'`） | `'1'` = 案内通知書 |
| `CHOHYO_MEI` | 通知書名称 | `'成人式案内通知書'` |
| `HYOJI_JUN` | 表示順序 | `1`（一覧で最上位） |
| `SHUHATS_MEI` | 主題名（本テンプレートでは未使用） | `NULL` |
| `DATE_MEI1`〜`DATE_MEI5` | 日付項目ラベル | `'開催日'`、残りは `NULL` |
| `KOMOKU_MEI1`〜`KOMOKU_MEI10` | 項目ラベル（場所・時間等） | `'開催場所'`, `'受付時間'`, `'開始時間'` など |
| `KOIN_SHORYAKU` | 公印省略表記 | `'（公印省略）'` |
| `KOIN_CHUSHAKU` | 公印注釈 | `'※この通知書は、黒色の電子公印を使用しています。'` |
| `TSUCHIBUN` | 本文（可変部分） | 成人式の祝辞と案内文を改行付きで結合 |
| `SYS_SAKUSEIBI` | 作成日（YYYYMMDD） | `20251201` |
| `SYS_KOSHINBI` | 更新日（未設定は `0`） | `0` |
| `SYS_JIKAN` | 時間情報（未使用） | `0` |
| `SYS_SHOKUINKOJIN_NO` | 作成者社員番号 | `'90002'` |
| `SYS_TANMATU_NO` | バージョン管理番号 | `'1.0.000.000'` |

### 3. 文字列結合と改行処理
```sql
'　このたび成人の日を迎えられますことを心からお祝い申し上げます。' || CHR(13) || CHR(10) ||
'下記のとおりはたちの集いを開催しますので、ご出席くださるようご案内いたします。'
```
- `CHR(13)` と `CHR(10)` はそれぞれ CR と LF。  
- これにより、通知書本文が **2 行** に分割され、印刷・画面表示時に正しい改行が保持されます。

### 4. 例外・エラーハンドリング
- 本スクリプトは単一の INSERT 文であり、SQL*Plus 等のクライアントが自動的にトランザクションをロールバックします。  
- **想定される例外**  
  - `ORA-00001: unique constraint (PK_GKBTTSUCHISHOKANRISEIJIN) violated` → 同一キーが既に存在する場合。  
  - `ORA-00942: table or view does not exist` → テーブルが未作成の場合。  

> **対策**: デプロイ前にテーブル定義と PK 制約を確認し、必要に応じて `INSERT /*+ IGNORE_ROW_ON_DUPKEY_INDEX(...) */` で重複を無視するか、事前に `DELETE`/`MERGE` に置き換える。

---

## 依存関係と関係

| 参照先/参照元 | 関係の概要 |
|--------------|------------|
| `GKBTTSUCHISHOKANRISEIJIN` テーブル | 本 INSERT がデータを投入する対象。テーブル定義は別ファイル（例: `DDL_GKBTTSUCHISHOKANRISEIJIN.SQL`）で管理。 |
| 通知書生成ロジック (`通知書作成バッチ`、`通知書プレビュー画面`) | `CHOHYO_KBN`、`CHOHYO_MEI` でテンプレートを検索し、`TSUCHIBUN` 等の項目を差し込み表示。 |
| `SYS_SHOKUINKOJIN_NO` / `SYS_TANMATU_NO` | システム監査テーブルやバージョン管理機構と連携し、変更履歴を追跡。 |

> **リンク例**:  
> - テーブル定義: [`GKBTTSUCHISHOKANRISEIJIN テーブル定義`](http://localhost:3000/projects/all/wiki?file_path=D:/code-wiki/projects/all/sample_all/sql/DDL_GKBTTSUCHISHOKANRISEIJIN.SQL)  
> - 本スクリプト: [`INSERT 文`](http://localhost:3000/projects/all/wiki?file_path=D:/code-wiki/projects/all/sample_all/sql/INS_GKBTTSUCHISHOKANRISEIJIN.SQL)

---

## まとめ（新規開発者へのアドバイス）

1. **テンプレート追加・修正**はこの INSERT を編集し、`CHOHYO_MEI` や本文 (`TSUCHIBUN`) を変更すれば即座に反映できます。  
2. **重複防止**が必要な場合は、PK 制約を確認し、`MERGE` 文へ置き換えるか、スクリプト実行前に対象レコードの有無をチェックしてください。  
3. **改行コード**は `CHR(13)||CHR(10)` で明示的に埋め込んでいるため、他の DB クライアントでも同様に表示されます。  
4. **メタ情報** (`SYS_*` カラム) はデプロイ自動化スクリプトで動的に設定できるようにすると、バージョン管理が楽になります。  

以上が `INS_GKBTTSUCHISHOKANRISEIJIN.SQL` の全体像と、今後の保守・拡張に役立つポイントです。