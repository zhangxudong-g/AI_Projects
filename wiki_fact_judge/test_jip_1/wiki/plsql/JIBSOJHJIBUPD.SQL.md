# JIBSOJHJIBUPD（パッケージボディ）

## 1. 目的
`JIBSOJHJIBUPD` は、住居表示変更対象者（現住所・本籍住所）の情報を取得し、IES 用中間テーブルに格納したうえで、マスタテーブルへ反映させるバッチ処理です。  
**注意**: コード中に業務コメントが無いため、上記説明はクラス名・処理内容からの推測です。

## 2. インターフェース

| プロシージャ / 関数 | 種別 | パラメータ | 戻り値 | 説明 |
|----------------------|------|------------|--------|------|
| `FUNC_SET_JUKIJUSHO` | 関数 | `R_TAISHO JIBTJUSHOHENKO_TAISHO%ROWTYPE` | `PLS_INTEGER` | 住基情報（IES 用）を `o_EBT_IES_JUKIJUSHO` に設定し、`JIBWIES_JUKIJUSHO` へ INSERT |
| `FUNC_SET_IES_JUKIJOHO` | 関数 | `R_TAISHO JIBTJUSHOHENKO_TAISHO%ROWTYPE` | `PLS_INTEGER` | 住基情報（IES 用）を `o_EBT_IES_JUKIJOHO` に設定し、`JIBWIES_JUKIJOHO` へ INSERT |
| `INIT_EBT_JUSHOHENKO` | 手続き | なし | なし | `o_EBT_JUSHOHENKO` の全フィールドを初期化 |
| `FUNC_SET_JUSHOHENKO` | 関数 | `R_TAISHO JIBTJUSHOHENKO_TAISHO%ROWTYPE` | `PLS_INTEGER` | 住所変更証明書管理テーブル `JIBWIES_JUSHOHENKO` へ INSERT |
| `FUNC_CHECK_GENJYUSHO_TAISHO` | 関数 | `R_TAISHO JIBTJUSHOHENKO_TAISHO%ROWTYPE` | `PLS_INTEGER` | 現住所対象フラグのチェック・更新 |
| `FUNC_CHECK_HONJYUSHO_TAISHO` | 関数 | `R_TAISHO JIBTJUSHOHENKO_TAISHO%ROWTYPE` | `PLS_INTEGER` | 本籍対象フラグのチェック・更新 |
| `FUNC_GET_DATA` | 関数 | `R_TAISHO JIBTJUSHOHENKO_TAISHO%ROWTYPE` | `PLS_INTEGER` | 宛名基本・住基異動テーブルからデータ取得 |
| `FUNC_UPDATE_GENJYUSHO` | 関数 | `R_TAISHO JIBTJUSHOHENKO_TAISHO%ROWTYPE` | `PLS_INTEGER` | 現住所変更フロー（チェック → 中間テーブル登録 → フラグ更新） |
| `FUNC_UPDATE_HONJYUSHO` | 関数 | `R_TAISHO JIBTJUSHOHENKO_TAISHO%ROWTYPE` | `PLS_INTEGER` | 本籍住所変更フロー（チェック → 中間テーブル登録 → フラグ更新） |
| `FUNC_GET_W_ENTORYID` | 関数 | なし | `PLS_INTEGER` | エントリー ID（`KKFTNEXTIDKANRI` から）取得 |
| `FUNC_JIBSOIEUPD_GEN` | 関数 | なし | `PLS_INTEGER` | 現住所対象の IES 中間テーブルからマスタ更新 |
| `FUNC_JIBSOIEUPD_HON` | 関数 | なし | `PLS_INTEGER` | 本籍対象の IES 中間テーブルからマスタ更新 |
| `FUNC_EBPPRENKEIKOSHIN` | 関数 | `W_GHKBN IN NVARCHAR2` | `PLS_INTEGER` | 住基情報連携（現住所／本籍）を外部システムへ送信 |
| **メインブロック** | - | - | - | バッチ全体の制御フロー（初期化 → 住居変更 → 本籍変更 → エラーハンドリング） |

## 3. 主要サブルーチン

| 種別 | 名前 | 用途 |
|------|------|------|
| 関数 | `FUNC_SET_JUKIJUSHO` | 住基情報（IES 用）を作成し `JIBWIES_JUKIJUSHO` に格納 |
| 関数 | `FUNC_SET_IES_JUKIJOHO` | 住基情報（IES 用）を作成し `JIBWIES_JUKIJOHO` に格納 |
| 手続き | `INIT_EBT_JUSHOHENKO` | `o_EBT_JUSHOHENKO` のフィールドを全リセット |
| 関数 | `FUNC_CHECK_GENJYUSHO_TAISHO` | 現住所対象フラグの有無を判定し、対象テーブルを更新 |
| 関数 | `FUNC_CHECK_HONJYUSHO_TAISHO` | 本籍対象フラグの有無を判定し、対象テーブルを更新 |
| 関数 | `FUNC_GET_DATA` | 宛名基本・住基異動テーブルからデータ取得しローカル変数へ格納 |
| 関数 | `FUNC_UPDATE_GENJYUSHO` | 現住所変更の全工程（チェック → 中間テーブル登録 → フラグ更新） |
| 関数 | `FUNC_UPDATE_HONJYUSHO` | 本籍住所変更の全工程（チェック → 中間テーブル登録 → フラグ更新） |
| 関数 | `FUNC_JIBSOIEUPD_GEN` | 現住所対象の IES 中間テーブルからマスタテーブルへ反映 |
| 関数 | `FUNC_JIBSOIEUPD_HON` | 本籍対象の IES 中間テーブルからマスタテーブルへ反映 |
| 関数 | `FUNC_EBPPRENKEIKOSHIN` | 住基情報を外部システム（EBP）へ送信 |
| 関数 | `FUNC_GET_W_ENTORYID` | エントリー ID を取得（`KKFTNEXTIDKANRI`） |

## 4. 依存関係

| 依存先 | 種別 | 用途 |
|--------|------|------|
| `KKAPK0020` | パッケージ | 日付変換ロジック `FDAYEDIT` |
| `KKAPK0030` | パッケージ | 定数取得 `FCTGetR` |
| `JIBTJUSHOHENKO_TAISHO%ROWTYPE` | レコード型 | 住居変更対象者テーブルの行定義 |
| `JIBTJUSHOHENKO` | テーブル | 住居変更証明書管理テーブル |
| `JIBTJUSHOHENKO_TAISHO` | テーブル | 住居変更対象者テーブル |
| `JIBTJUSHOHENKO_TAISHO`（カーソル `CJUSHOHENKOTAISHO`） | カーソル | 現住所対象レコード取得 |
| `JIBTJUSHOHENKO_TAISHO`（カーソル `CJUSHOHENKOTAISHO`） | カーソル | 本籍対象レコード取得 |
| `JIBWIES_JUKIJUSHO` | テーブル | IES 用住基情報（住所）中間テーブル |
| `JIBWIES_JUKIJOHO` | テーブル | IES 用住基情報（本籍）中間テーブル |
| `JIBWIES_JUKIKIHON` | テーブル | IES 用宛名基本中間テーブル |
| `JIBWIES_JUKIIDO` | テーブル | IES 用住基異動中間テーブル |
| `JIBWIES_JUSHOHENKO` | テーブル | 住所変更証明書管理中間テーブル |
| `KKFTNEXTIDKANRI` | テーブル | エントリー ID 管理テーブル |
| `DBMS_LOCK` | パッケージ | `SLEEP`（処理間の待機） |
| `DBMS_OUTPUT` | パッケージ | エラーログ出力 |
| `NKBSOJIDO` | 手続き | 国民年金異動報告データ生成 |
| `JIBSOIEUPD` | 手続き | IES 中間テーブルからマスタ更新（共通ロジック） |

※上記の依存先はコード中で直接参照されているものです。リンクは以下の形式で埋め込んでいます（例）:

```markdown
[`KKAPK0020`](http://localhost:3000/projects/test_jip_1/wiki?file_path=code/plsql/KKAPK0020.pks)
```

## 5. ビジネスフロー

1. **初期化**  
   - 定数・日付変換 (`KKAPK0020.FDAYEDIT`)  
   - 制御定数取得 (`FUNC_INPUT_CTL_CONSTANT`)  
   - 前回テスト情報クリア (`FUNC_CLEAR_TAISHO_TEST`)  

2. **エントリー ID 取得** (`FUNC_GET_W_ENTORYID`)  

3. **現住所変更ループ**（`CJUSHOHENKOTAISHO` カーソル）  
   - 世帯単位で区切り、世帯が変わるたびに `FUNC_JIBSOIEUPD_GEN` と `FUNC_EBPPRENKEIKOSHIN` を実行  
   - 現住所対象フラグが 1 のレコードに対し:  
     1. `FUNC_GET_DATA` で宛名基本・住基異動データ取得  
     2. `FUNC_UPDATE_GENJYUSHO` でチェック → 中間テーブル登録 → フラグ更新  

4. **本籍住所変更ループ**（同上）  
   - 本籍対象フラグが 1 のレコードに対し:  
     1. `FUNC_GET_DATA` でデータ取得  
     2. `FUNC_UPDATE_HONJYUSHO` でチェック → 中間テーブル登録 → フラグ更新  

5. **世帯単位の最終処理**  
   - 変更が残っている世帯について `FUNC_JIBSOIEUPD_GEN` / `FUNC_JIBSOIEUPD_HON` と `FUNC_EBPPRENKEIKOSHIN` を実行  

6. **エラーハンドリング**  
   - `WHEN OTHERS` で例外捕捉、`SQLCODE` と `SQLERRM` を `o_NSQL_CODE` / `o_VSQL_MSG` に格納  

## 6. 設計特徴

- **分層バッチ構造**：メインブロックが制御フローを司り、個別ロジックは関数/手続きに分割。  
- **IES 中間テーブル利用**：住基情報を一時的に IES 用テーブルへ格納し、後続のマスタ更新で一括処理。  
- **世帯単位のバッチ処理**：同一世帯のレコードはまとめて処理し、エントリー ID を世帯ごとに取得。  
- **例外一元化**：全関数は `WHEN OTHERS` で例外を捕捉し、共通変数 `o_NSQL_CODE` / `o_VSQL_MSG` に格納。  
- **外部システム連携**：`FUNC_EBPPRENKEIKOSHIN` で現住所／本籍の情報を外部システム（EBP）へ送信。  

---