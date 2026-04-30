# GKB000EntityRepository

## 1. 目的
`GKB000EntityRepository` は **Spring の DAO コンポーネント** として、複数のエンティティに対する **INSERT / SELECT / UPDATE / DELETE** の CRUD 操作を提供します。  
**注意**: コード中に業務目的のコメントはありません。クラス名とメソッド名から推測した目的です。

## 2. 主要メソッド

| メソッド | 戻り値 | 説明 |
|----------|--------|------|
| `insertGKBTGAKUNEN_001(GkbtGakunenEntity)` | なし | 学年情報を新規登録 |
| `selectGKBTGAKUNEN_002(Integer)` | `GkbtGakunenEntity` | 学年コードで学年情報を取得 |
| `updateGKBTGAKUNEN_003(GkbtGakunenEntity)` | なし | 学年情報を更新 |
| `deleteGKBTGAKUNEN_004(Integer)` | なし | 学年コードで学年情報を削除 |
| `selectGKBTSEIJINSHA_005(GkbtSeijinsyaEntity)` | `GkbtSeijinsyaEntity` | 生徒情報を取得 |
| `insertGKBTSEIJINSHA_006(GkbtSeijinsyaEntity)` | なし | 生徒情報を新規登録 |
| `updateGKBTSEIJINSHA_007(GkbtSeijinsyaEntity)` | なし | 生徒情報を更新 |
| `deleteGKBTSEIJINSHA_008(GkbtSeijinsyaEntity)` | なし | 生徒情報を削除 |
| `insertGKBTKUIKIGAI_009(GkbtKuikigaiEntity)` | なし | 休学情報を新規登録 |
| `updateGKBTKUIKIGAI_010(GkbtKuikigaiEntity)` | なし | 休学情報を更新 |
| `selectGKBTKUIKIGAI_011(Integer)` | `GkbtKuikigaiEntity` | 休学コードで情報取得 |
| `deleteGKBTKUIKIGAI_012(GkbtKuikigaiEntity)` | なし | 休学情報を削除 |
| `insertGKBTCHUGAKKO_013(GkbtTyugakoEntity)` | なし | 中学区情報を新規登録 |
| `selectGKBTCHUGAKKO_014(Integer)` | `GkbtTyugakoEntity` | 中学区コードで取得 |
| `updateGKBTCHUGAKKO_015(GkbtTyugakoEntity)` | なし | 中学区情報を更新 |
| `deleteGKBTCHUGAKKO_016(GkbtTyugakoEntity)` | なし | 中学区情報を削除 |
| `insertGKBTYOGOGAKKO_017(GkbtYogogakoEntity)` | なし | 養護学校情報を新規登録 |
| `selectGKBTYOGOGAKKO_018(Integer)` | `GkbtYogogakoEntity` | 養護学校コードで取得 |
| `updateGKBTYOGOGAKKO_019(GkbtYogogakoEntity)` | なし | 養護学校情報を更新 |
| `deleteGKBTYOGOGAKKO_020(GkbtYogogakoEntity)` | なし | 養護学校情報を削除 |
| `selectGKBTYOGOGAKKO_050(HashMap<String,Object>)` | `ArrayList<Map<String,Object>>` | 養護学校情報の検索結果リスト取得 |
| `insertGKBTYUYOJIYU_021(GkbtYuyojiyuEntity)` | なし | 受給情報を新規登録 |
| `selectGKBTYUYOJIYU_022(Integer)` | `GkbtYuyojiyuEntity` | 受給コードで取得 |
| `updateGKBTYUYOJIYU_023(GkbtYuyojiyuEntity)` | なし | 受給情報を更新 |
| `deleteGKBTYUYOJIYU_024(Integer)` | なし | 受給情報を削除 |
| `insertGKBTZOKUGARA_025(GkbtZokugaraEntity)` | なし | 続柄情報を新規登録 |
| `selectGKBTZOKUGARA_026(GkbtZokugaraEntity)` | `GkbtZokugaraEntity` | 続柄情報取得 |
| `updateGKBTZOKUGARA_027(GkbtZokugaraEntity)` | なし | 続柄情報を更新 |
| `deleteGKBTZOKUGARA_028(GkbtZokugaraEntity)` | なし | 続柄情報を削除 |
| `insertGKBTGENJIYU_029(GkbtGenjiyuEntity)` | なし | 現職情報を新規登録 |
| `selectGKBTGENJIYU_030(Integer)` | `GkbtGenjiyuEntity` | 現職コードで取得 |
| `updateGKBTGENJIYU_031(GkbtGenjiyuEntity)` | なし | 現職情報を更新 |
| `deleteGKBTGENJIYU_032(Integer)` | なし | 現職情報を削除 |
| `insertGKBTIDOBUN_033(GkbtIdobunEntity)` | なし | 位置分情報を新規登録 |
| `selectGKBTIDOBUN_034(Integer)` | `GkbtIdobunEntity` | 位置分コードで取得 |
| `updateGKBTIDOBUN_035(GkbtIdobunEntity)` | なし | 位置分情報を更新 |
| `deleteGKBTIDOBUN_036(Integer)` | なし | 位置分情報を削除 |
| `insertGKBTMENJOJIYU_037(GkbtMenjojiyuEntity)` | なし | 面接情報を新規登録 |
| `selectGKBTMENJOJIYU_038(Integer)` | `GkbtMenjojiyuEntity` | 面接コードで取得 |
| `updateGKBTMENJOJIYU_039(GkbtMenjojiyuEntity)` | なし | 面接情報を更新 |
| `deleteGKBTMENJOJIYU_040(Integer)` | なし | 面接情報を削除 |
| `insertGKBTTOKUSOKU_041(GkbtTokusokuEntity)` | なし | 特則情報を新規登録 |
| `selectGKBTTOKUSOKU_042(Integer)` | `GkbtTokusokuEntity` | 特則コードで取得 |
| `updateGKBTTOKUSOKU_043(GkbtTokusokuEntity)` | なし | 特則情報を更新 |
| `deleteGKBTTOKUSOKU_044(Integer)` | なし | 特則情報を削除 |
| `insertGKBTSHOGAKKO_045(GkbtSyogakoEntity)` | なし | 小学校情報を新規登録 |
| `selectGKBTSHOGAKKO_046(Integer)` | `GkbtSyogakoEntity` | 小学校コードで取得 |
| `updateGKBTSHOGAKKO_047(GkbtSyogakoEntity)` | なし | 小学校情報を更新 |
| `deleteGKBTSHOGAKKO_048(Integer)` | なし | 小学校情報を削除 |
| `updateGKBTSHOGAKKO_049(GkbtSyogakoEntity)` | なし | 小学校情報の追加更新 |
| `selectGKBTYOGOGAKKO_051(HashMap<String,Object>)` | `ArrayList<Map<String,Object>>` | 養護学校検索結果取得 |
| `selectGKBTSHOGAKKO_052(HashMap<String,Object>)` | `ArrayList<Map<String,Object>>` | 小学校検索結果取得 |
| `selectGKBTCHUGAKKO_017(HashMap<String,Object>)` | `ArrayList<Map<String,Object>>` | 中学区検索結果取得 |
| `selectGKBTSHOGAKKO_053(HashMap<String,Object>)` | `String` | 小学校コードの論理削除チェック |
| `selectGKBTCHUGAKKO_054(Map<String,Object>)` | `String` | 中学区コードの論理削除チェック |
| `selectGKBTKUIKIGAI_055(Map<String,Object>)` | `String` | 休学コードの論理削除チェック |
| `selectGKBTYOGOGAKKO_056(Map<String,Object>)` | `String` | 養護学校コードの論理削除チェック |
| `selectGKBTKUNISIRITSUGAKKO_057(Map<String,Object>)` | `String` | 国・私立学校コードの論理削除チェック |

## 3. 依存関係

| 依存クラス | 用途 |
|------------|------|
| `org.springframework.stereotype.Repository` | Spring が DAO コンポーネントとして認識 |
| `GkbtGakunenEntity` | 学年情報エンティティ |
| `GkbtSeijinsyaEntity` | 生徒情報エンティティ |
| `GkbtKuikigaiEntity` | 休学情報エンティティ |
| `GkbtTyugakoEntity` | 中学区情報エンティティ |
| `GkbtYogogakoEntity` | 養護学校情報エンティティ |
| `GkbtYuyojiyuEntity` | 受給情報エンティティ |
| `GkbtZokugaraEntity` | 続柄情報エンティティ |
| `GkbtGenjiyuEntity` | 現職情報エンティティ |
| `GkbtIdobunEntity` | 位置分情報エンティティ |
| `GkbtMenjojiyuEntity` | 面接情報エンティティ |
| `GkbtTokusokuEntity` | 特則情報エンティティ |
| `GkbtSyogakoEntity` | 小学校情報エンティティ |

※エンティティクラスへのリンク例（相対パスはプロジェクト構成に合わせて調整してください）  
`[GkbtGakunenEntity](http://localhost:3000/projects/test_jip_1/wiki?file_path=code/java/GkbtGakunenEntity.java)`  
`[GkbtSeijinsyaEntity](http://localhost:3000/projects/test_jip_1/wiki?file_path=code/java/GkbtSeijinsyaEntity.java)`  
（以下同様に各エンティティへリンク）

## 4. 設計特徴

- **DAO パターン**: `@Repository` アノテーションで DAO として登録し、エンティティ単位の CRUD メソッドを提供。  
- **Spring DI**: Spring コンテナがインターフェース実装を自動生成し、サービス層から注入可能。  
- **大量メソッド**: 各エンティティごとに INSERT / SELECT / UPDATE / DELETE を個別に定義し、SQL マッピングの可読性を確保。  
- **論理削除チェック**: 特定コードが論理削除対象かどうかを文字列で返すメソッドを追加し、データ整合性を保護。  

---