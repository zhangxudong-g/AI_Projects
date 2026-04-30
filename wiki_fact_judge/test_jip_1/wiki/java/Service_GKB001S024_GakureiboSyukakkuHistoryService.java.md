# GKB001S024_GakureiboSyukakkuHistoryService

## 1. 目的
`GKB001S024_GakureiboSyukakkuHistoryService` は **学齢簿情報取得サービス** です。  
学齢簿（学籍情報）の最新データおよび履歴データを取得し、画面表示用に整形して返却します。

## 2. 核心字段

| フィールド | 型 | 説明 |
|------------|----|------|
| `NEW` | `String` | 「最新」表示用定数 |
| `RIREKI` | `String` | 「履歴」表示用定数 |
| `NONE` | `String` | データなし表示用定数 |
| `gKB001S024_GakureiboSyukakkuHistoryDao` | `GKB001S024_GakureiboSyukakkuHistoryDao` | 学齢簿履歴取得 DAO（`@Inject`） |
| `gkb0010Repository` | `GKB0010Repository` | 学齢簿基本情報取得リポジトリ（`@Inject`） |

## 3. 依存関係

| 依存クラス | 用途 |
|------------|------|
| [`GKB001S024_GakureiboSyukakkuHistoryDao`](../dao/GKB001S024_GakureiboSyukakkuHistoryDao.java) | 学齢簿履歴データの取得 |
| [`GKB0010Repository`](../repository/GKB0010Repository.java) | 学齢簿基本情報（`GKBTGAKUREIBO_006`）の取得 |
| `KyoikuConstants` | ステータス定数（`CN_STATUS_NONE`、`CN_STATUS_OK`） |
| `StringUtils` (Apache Commons) | 文字列比較に使用 |

## 4. ビジネスフロー

1. **履歴リスト取得**  
   `gKB001S024_GakureiboSyukakkuHistoryDao.getGakureiboShokaiHistoryList` で対象個人番号の履歴リストを取得。

2. **履歴が無い場合**  
   - ステータスを `CN_STATUS_NONE` に設定。  
   - 表示項目 `RIREKI` を `なし` に設定。  
   - ページ情報を `1/1`、上下フラグを `true` に設定。  
   - `gkb0010Repository.selectGKBTGAKUREIBO_006` で基本情報を取得し、結果に格納して返却。

3. **履歴が1件のみの場合**  
   - 上下フラグを両方 `true` に設定。

4. **ページインデックス算出**  
   - `inBean.getPageIndex()` が `null` またはリストサイズを超える場合は最大インデックスに補正。  
   - インデックスが `0`（最初のページ）なら上フラグ `true`。  
   - インデックスがリストサイズと同じ場合は下フラグ `true`。

5. **対象履歴データ取得**  
   - `rirekiRenbanList.get(rirekiRenbanList.size() - pageIndex)` で対象データを取得。  
   - `SaishinFlg` が `"0"` のときは表示項目を `最新`、それ以外は `履歴` に設定。

6. **基本情報取得**  
   - `gkb0010Repository.selectGKBTGAKUREIBO_006` で学齢簿基本情報を取得し、結果に格納。

7. **ページ情報設定**  
   - 現在ページ番号 `count` を `pageIndex`（1ベースではなく0ベース）で設定。  
   - 総ページ数 `total` をリストサイズで設定。

8. **ステータス設定**  
   - ステータスを `CN_STATUS_OK` に設定し、結果を返却。

## 5. 設計特徴

- **Spring @Service** によるコンポーネント定義と DI（`@Inject`）で依存関係を注入。  
- **定数利用**（`NEW`、`RIREKI`、`NONE`）で表示文字列を一元管理。  
- **ページングロジック** を手動で実装し、履歴データの前後フラグ（上下）を制御。  
- **リポジトリと DAO の組み合わせ** により、履歴データと基本情報を同時取得。  
- **Apache Commons Lang3** の `StringUtils.equals` を使用し、文字列比較の安全性を確保。  