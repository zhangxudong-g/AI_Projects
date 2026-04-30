# GKB001S024_GakureiboSyukakkuHistoryService

## 1. 目的
`GKB001S024_GakureiboSyukakkuHistoryService` は **学齢簿情報取得サービス** です。  
入力された個人番号（`kojinNo`）に対して、就学変更履歴を取得し、最新・履歴の表示情報やページング情報を組み立てて返却します。

## 2. 主要方法

| 方法 | 戻り値 | 説明 |
|------|--------|------|
| `perform(GKB001S024_GakureiboSyukakkuHistoryInBean inBean)` | `GKB001S024_GakureiboSyukakkuHistoryOutBean` | 個人番号から就学変更履歴リストを取得し、ページング・表示フラグ・関連学齢簿データを設定して返す。 |

## 3. 依存関係

| 依存 | 用途 |
|------|------|
| `[GKB001S024_GakureiboSyukakkuHistoryDao](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/GKB001S024_GakureiboSyukakkuHistoryDao.java)` | 履歴リスト取得（`getGakureiboShokaiHistoryList`） |
| `[GKB0010Repository](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/GKB0010Repository.java)` | 学齢簿マスタデータ取得（`selectGKBTGAKUREIBO_006`） |
| `KyoikuConstants` | ステータス定数（`CN_STATUS_NONE`, `CN_STATUS_OK`） |
| `StringUtils`（Apache Commons Lang） | 文字列比較（`equals`） |
| `[GakureiboShokaiHistoryData](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/GakureiboShokaiHistoryData.java)` | 履歴データ保持クラス |
| `[GkbtgakureiboData](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/GkbtgakureiboData.java)` | 学齢簿マスタデータ保持クラス |
| `[GKB001S024_GakureiboSyukakkuHistoryInBean](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/GKB001S024_GakureiboSyukakkuHistoryInBean.java)` | 入力パラメータ（個人番号、ページインデックス） |
| `[GKB001S024_GakureiboSyukakkuHistoryOutBean](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/GKB001S024_GakureiboSyukakkuHistoryOutBean.java)` | 出力パラメータ（履歴データ、表示フラグ、ページ情報） |

## 4. 业务流程

```mermaid
sequenceDiagram
    participant Service as GKB001S024_GakureiboSyukakkuHistoryService
    participant Dao as GKB001S024_GakureiboSyukakkuHistoryDao
    participant Repo as GKB0010Repository
    participant InBean as GKB001S024_GakureiboSyukakkuHistoryInBean
    participant OutBean as GKB001S024_GakureiboSyukakkuHistoryOutBean

    Service->>Dao: getGakureiboShokaiHistoryListkojinNo["getGakureiboShokaiHistoryList (kojinNo)"]
    alt 履歴リストが空
        Service->>Repo: selectGKBTGAKUREIBO_006kojinNo["selectGKBTGAKUREIBO_006 (kojinNo)"]
        Service->>OutBean: set status = NONE, set flags, set count/total = 1, set gakureiboData
    else 履歴リストが1件以上
        Service->>Service: 計算 pageIndex, 判定 上/下 フラグ
        Service->>Dao: get historyDataindexbasedonpageIndex["historyData (index based on pageIndex)"]
        Service->>Service: 判定 NEW / RIREKI 表示
        Service->>Repo: selectGKBTGAKUREIBO_006kojinNo["selectGKBTGAKUREIBO_006 (kojinNo)"]
        Service->>OutBean: set historyData, gakureiboData, count, total, status = OK
    end
    Service->>Client: return OutBean
```

このフローは、履歴が存在しない場合と存在する場合の二通りの処理を分岐し、ページング情報と表示フラグを適切に設定してクライアントへ返却します。