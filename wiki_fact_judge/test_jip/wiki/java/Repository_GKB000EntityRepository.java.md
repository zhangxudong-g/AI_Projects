# GKB000EntityRepository

## 1. 目的
`GKB000EntityRepository` は **Spring の DAO コンポーネント** として、`jp.co.jip.gkb000.common.entity` パッケージに属する各種エンティティに対する **INSERT / SELECT / UPDATE / DELETE** の CRUD 操作を提供します。  
※コード中に業務目的の記述はありませんが、クラス名とコメントから上記の役割であることが確認できます。

## 2. 管理エンティティ

### GkbtGakunenEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTGAKUNEN_001(GkbtGakunenEntity record)` | 新規登録 |
| `GkbtGakunenEntity selectGKBTGAKUNEN_002(Integer gakunenCd)` | 取得 |
| `void updateGKBTGAKUNEN_003(GkbtGakunenEntity record)` | 更新 |
| `void deleteGKBTGAKUNEN_004(Integer gakunenCd)` | 削除 |
> エンティティ: [`GkbtGakunenEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtGakunenEntity.java)

### GkbtSeijinsyaEntity
| メソッド | 説明 |
|----------|------|
| `GkbtSeijinsyaEntity selectGKBTSEIJINSHA_005(GkbtSeijinsyaEntity record)` | 取得 |
| `void insertGKBTSEIJINSHA_006(GkbtSeijinsyaEntity record)` | 新規登録 |
| `void updateGKBTSEIJINSHA_007(GkbtSeijinsyaEntity record)` | 更新 |
| `void deleteGKBTSEIJINSHA_008(GkbtSeijinsyaEntity record)` | 削除 |
> エンティティ: [`GkbtSeijinsyaEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtSeijinsyaEntity.java)

### GkbtKuikigaiEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTKUIKIGAI_009(GkbtKuikigaiEntity record)` | 新規登録 |
| `void updateGKBTKUIKIGAI_010(GkbtKuikigaiEntity record)` | 更新 |
| `GkbtKuikigaiEntity selectGKBTKUIKIGAI_011(Integer kuikigaiCd)` | 取得 |
| `void deleteGKBTKUIKIGAI_012(GkbtKuikigaiEntity record)` | 削除 |
> エンティティ: [`GkbtKuikigaiEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtKuikigaiEntity.java)

### GkbtTyugakoEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTCHUGAKKO_013(GkbtTyugakoEntity record)` | 新規登録 |
| `GkbtTyugakoEntity selectGKBTCHUGAKKO_014(Integer tyugakoCd)` | 取得 |
| `void updateGKBTCHUGAKKO_015(GkbtTyugakoEntity record)` | 更新 |
| `void deleteGKBTCHUGAKKO_016(GkbtTyugakoEntity record)` | 削除 |
> エンティティ: [`GkbtTyugakoEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtTyugakoEntity.java)

### GkbtYogogakoEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTYOGOGAKKO_017(GkbtYogogakoEntity record)` | 新規登録 |
| `GkbtYogogakoEntity selectGKBTYOGOGAKKO_018(Integer yogogakoCd)` | 取得 |
| `void updateGKBTYOGOGAKKO_019(GkbtYogogakoEntity record)` | 更新 |
| `void deleteGKBTYOGOGAKKO_020(GkbtYogogakoEntity eqtYogogako)` | 削除 |
| `ArrayList<Map<String, Object>> selectGKBTYOGOGAKKO_050(HashMap<String, Object> param)` | 条件検索（リスト取得） |
> エンティティ: [`GkbtYogogakoEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtYogogakoEntity.java)

### GkbtYuyojiyuEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTYUYOJIYU_021(GkbtYuyojiyuEntity record)` | 新規登録 |
| `GkbtYuyojiyuEntity selectGKBTYUYOJIYU_022(Integer yuyoJiyuCd)` | 取得 |
| `void updateGKBTYUYOJIYU_023(GkbtYuyojiyuEntity record)` | 更新 |
| `void deleteGKBTYUYOJIYU_024(Integer yuyoJiyuCd)` | 削除 |
> エンティティ: [`GkbtYuyojiyuEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtYuyojiyuEntity.java)

### GkbtZokugaraEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTZOKUGARA_025(GkbtZokugaraEntity record)` | 新規登録 |
| `GkbtZokugaraEntity selectGKBTZOKUGARA_026(GkbtZokugaraEntity record)` | 取得 |
| `void updateGKBTZOKUGARA_027(GkbtZokugaraEntity record)` | 更新 |
| `void deleteGKBTZOKUGARA_028(GkbtZokugaraEntity record)` | 削除 |
> エンティティ: [`GkbtZokugaraEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtZokugaraEntity.java)

### GkbtGenjiyuEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTGENJIYU_029(GkbtGenjiyuEntity record)` | 新規登録 |
| `GkbtGenjiyuEntity selectGKBTGENJIYU_030(Integer genJiyuCd)` | 取得 |
| `void updateGKBTGENJIYU_031(GkbtGenjiyuEntity record)` | 更新 |
| `void deleteGKBTGENJIYU_032(Integer genJiyuCd)` | 削除 |
> エンティティ: [`GkbtGenjiyuEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtGenjiyuEntity.java)

### GkbtIdobunEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTIDOBUN_033(GkbtIdobunEntity record)` | 新規登録 |
| `GkbtIdobunEntity selectGKBTIDOBUN_034(Integer idoBunCd)` | 取得 |
| `void updateGKBTIDOBUN_035(GkbtIdobunEntity record)` | 更新 |
| `void deleteGKBTIDOBUN_036(Integer idoBunCd)` | 削除 |
> エンティティ: [`GkbtIdobunEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtIdobunEntity.java)

### GkbtMenjojiyuEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTMENJOJIYU_037(GkbtMenjojiyuEntity record)` | 新規登録 |
| `GkbtMenjojiyuEntity selectGKBTMENJOJIYU_038(Integer menjoJiyuCd)` | 取得 |
| `void updateGKBTMENJOJIYU_039(GkbtMenjojiyuEntity record)` | 更新 |
| `void deleteGKBTMENJOJIYU_040(Integer menjoJiyuCd)` | 削除 |
> エンティティ: [`GkbtMenjojiyuEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtMenjojiyuEntity.java)

### GkbtTokusokuEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTTOKUSOKU_041(GkbtTokusokuEntity record)` | 新規登録 |
| `GkbtTokusokuEntity selectGKBTTOKUSOKU_042(Integer tokusokuCd)` | 取得 |
| `void updateGKBTTOKUSOKU_043(GkbtTokusokuEntity record)` | 更新 |
| `void deleteGKBTTOKUSOKU_044(Integer tokusokuCd)` | 削除 |
> エンティティ: [`GkbtTokusokuEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtTokusokuEntity.java)

### GkbtSyogakoEntity
| メソッド | 説明 |
|----------|------|
| `void insertGKBTSHOGAKKO_045(GkbtSyogakoEntity record)` | 新規登録 |
| `GkbtSyogakoEntity selectGKBTSHOGAKKO_046(Integer syogakoCd)` | 取得 |
| `void updateGKBTSHOGAKKO_047(GkbtSyogakoEntity record)` | 更新 |
| `void deleteGKBTSHOGAKKO_048(Integer syogakoCd)` | 削除 |
| `void updateGKBTSHOGAKKO_049(GkbtSyogakoEntity record)` | 更新（追加） |
| `ArrayList<Map<String, Object>> selectGKBTYOGOGAKKO_051(HashMap<String, Object> param)` | 条件検索（リスト取得） |
| `ArrayList<Map<String, Object>> selectGKBTSHOGAKKO_052(HashMap<String, Object> param)` | 条件検索（リスト取得） |
| `ArrayList<Map<String, Object>> selectGKBTCHUGAKKO_017(HashMap<String, Object> param)` | 条件検索（リスト取得） |
| `String selectGKBTSHOGAKKO_053(HashMap<String, Object> param)` | 小学校コードの論理削除チェック |
| `String selectGKBTCHUGAKKO_054(Map<String, Object> param)` | 中学校コードの論理削除チェック |
| `String selectGKBTKUIKIGAI_055(Map<String, Object> param)` | 区域外学校コードの論理削除チェック |
| `String selectGKBTYOGOGAKKO_056(Map<String, Object> param)` | 盲聾養護学校コードの論理削除チェック |
| `String selectGKBTKUNISIRITSUGAKKO_057(Map<String, Object> param)` | 国・私立学校コードの論理削除チェック |
> エンティティ: [`GkbtSyogakoEntity`](http://localhost:3000/projects/test_jip/wiki?file_path=code/java/jp/co/jip/gkb000/common/entity/GkbtSyogakoEntity.java)

## 3. 依存関係
| 依存 | 用途 |
|------|------|
| `org.springframework.stereotype.Repository` | Spring が DAO コンポーネントとして認識 |
| `jp.co.jip.gkb000.common.entity.*` | CRUD 対象エンティティ（上記表参照） |