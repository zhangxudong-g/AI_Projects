# 📄 `JID000S005ViewRow` クラス Wiki

**ファイルパス**  
`/projects/test_new/code/java/View_JID000S005ViewRow.java`

---

## 目次
1. [概要](#概要)  
2. [クラスの役割](#クラスの役割)  
3. [主なフィールド一覧](#主なフィールド一覧)  
4. [主要メソッド](#主要メソッド)  
5. [使用例](#使用例)  
6. [設計上のポイント・決定理由](#設計上のポイント決定理由)  
7. [注意点・改善余地](#注意点改善余地)  
8. [関連リンク](#関連リンク)  

---

## 概要
`JID000S005ViewRow` は、**申請書発行画面**（日本人・外国人共通）に対応した **ViewRow** オブジェクトです。  
画面上の各項目（氏名、出生年月日、性別、続柄等）を保持し、`AbstractViewRow` の共通ロジック（`toViewValue` など）を継承して UI へ安全に値を渡します。

---

## クラスの役割
| 目的 | 内容 |
|------|------|
| **データ保持** | 画面に表示する各項目の文字列・フラグを保持 |
| **UI 変換** | `AbstractViewRow` が提供する `toViewValue` を通じて、`null` や空文字列を安全に UI 表示用に変換 |
| **エラーフラグ管理** | 住民票・印鑑証明書・外国人証明書等のエラーコード・フラグを保持し、画面でのエラーハンドリングに利用 |
| **拡張性** | 2023/10/18 の WizLIFE 2次開発や 2024/01/31 の点滅表示フラグ追加など、要件変更に対してフィールドを追加しやすい構造 |

---

## 主なフィールド一覧
| フィールド | 型 | 説明 |
|------------|----|------|
| `sikensuNo` | `String` | シーケンス番号（1〜） |
| `sikensuChk` / `sikensuChkEnable` | `boolean` | シーケンスのチェック状態・有効状態 |
| `namekanjiTxt` | `String` | 氏名（漢字） |
| `seinengapi` | `String` | 生年月日（テキスト） |
| `seinengapiFushoHyoki` | `String` | **2023/10/18 追加**：生年月日不詳表記 |
| `seibetsuTxt` | `String` | 性別 |
| `zokugara_meiTxt` | `String` | 続柄名 |
| `jukiidoTxt` | `String` | 住基異動 |
| `DVTxt` | `String` | DV |
| `jyuukiTxt` | `String` | 住記 |
| `gaikokuTxt` | `String` | 外国 |
| `inkanTxt` | `String` | 印鑑 |
| `cardNo` | `String` | カード番号 |
| `dvredflg`, `jyuukiredflg`, `gaikokuredflg`, `inkanredflg`, `cardredflg` | `int` | 各種フラグ（0: OFF, 1: ON） |
| `kojinNo` | `String` | 個人番号 |
| `errzhuCode`, `errinkanCode`, `errforeignCode` | `int` | 各種エラーコード |
| `gaijiflg` | `int` | 外字未登録フラグ |
| `binkFlg` | `String` | **2024/01/31 追加**：点滅表示有無（空文字列 or `"1"` 等） |

> **注**：全ての文字列フィールドは `toViewValue` 経由で取得することで、`null` が空文字列に変換され UI での NullPointer を防止します。

---

## 主要メソッド
### 取得系（Getter）
```java
public String getNamekanjiTxt();      // 氏名（漢字）取得
public String getSeinengapi();        // 生年月日取得
public String getSeinengapiFushoHyoki(); // 生年月日不詳表記取得（追加分）
public boolean isSikensuChk();        // シーケンスチェック状態取得
public int getDvredflg();             // DV フラグ取得
// ... 省略（他フィールドも同様に getter が実装）
```

### 設定系（Setter）
```java
public void setNamekanjiTxt(String v);
public void setSeinengapi(String v);
public void setSeinengapiFushoHyoki(String v); // 追加分
public void setSikensuChk(boolean v);
public void setDvredflg(int v);
// ... 省略
```

### 取得時の共通ロジック
- 文字列系 getter は `return toViewValue(field);` を呼び出し、`null` → `""` の安全変換を実施。
- フラグ系 getter はそのまま `int`/`boolean` を返却。

---

## 使用例
```java
// ViewRow の生成（例: コントローラやサービス層で使用）
JID000S005ViewRow row = new JID000S005ViewRow();

// データ設定
row.setNamekanjiTxt("山田 太郎");
row.setSeinengapi("1990/01/01");
row.setSeibetsuTxt("男性");
row.setSikensuChk(true);
row.setDvredflg(1);   // DV 有効

// UI へ渡す（例: JSP/Thymeleaf のモデルに設定）
model.addAttribute("viewRow", row);
```

> **ポイント**  
> - 文字列取得は必ず `getXXX()`（内部で `toViewValue` が走る）を通す。  
> - フラグは `int` で管理されるため、`0/1` のみを想定していることに注意。

---

## 設計上のポイント・決定理由
| 項目 | 理由 |
|------|------|
| **継承 `AbstractViewRow`** | 画面表示用の共通ロジック（`toViewValue` 等）を再利用し、Null安全性を一元管理 |
| **フィールドをすべて `private` + getter/setter** | カプセル化により将来的なバリデーションやロジック追加が容易 |
| **エラーフラグ・コードを個別に保持** | 画面ごとに異なるエラー表示ロジックが必要なため、細分化して保持 |
| **2023/10/18 の追加項目** (`seinengapiFushoHyoki`) | 生年月日不詳のケースが要件に追加されたため、既存構造に最小変更で拡張 |
| **2024/01/31 の点滅表示フラグ** (`binkFlg`) | UI 側で点滅表示の有無を制御する要件が出たため、文字列で柔軟に拡張可能にした |
| **`int` フラグ** vs `boolean` | 既存システムが `0/1` の整数でフラグ管理しているため、互換性を保つために `int` を採用 |

---

## 注意点・改善余地
1. **フィールド数が多い**  
   - 現在は画面項目が増えるたびにフィールドを追加している。将来的に **Map<String, Object>** で動的に項目管理する設計にリファクタリングすると、コード量削減と柔軟性向上が期待できる。

2. **フラグの型統一**  
   - `boolean` と `int` が混在している。全フラグを `boolean` に統一し、必要に応じて `int` → `boolean` の変換ロジックを `AbstractViewRow` に持たせると、呼び出し側がシンプルになる。

3. **バリデーション**  
   - 現在 setter は単純代入のみ。入力値の長さチェックやフォーマット検証（例: 生年月日が `yyyy/MM/dd` か）を追加すると、データ不整合の防止に役立つ。

4. **ドキュメント自動生成**  
   - JavaDoc が不十分（パラメータ名だけのコメント）。IDE の自動生成ツールや `javadoc` の設定を見直し、**日本語**での詳細説明を付与すると、保守性が向上する。

---

## 関連リンク
- **抽象基底クラス**  
  `[AbstractViewRow](http://localhost:3000/projects/test_new/wiki?file_path=code/java/AbstractViewRow.java)`

- **画面テンプレート（例）**  
  `[JID000S005画面 JSP](http://localhost:3000/projects/test_new/wiki?file_path=webapp/WEB-INF/jsp/JID000S005.jsp)`

- **エラーフラグ定義**  
  `[ErrorCodeEnum](http://localhost:3000/projects/test_new/wiki?file_path=code/java/ErrorCodeEnum.java)`

--- 

*この Wiki は Code Wiki プロジェクトの標準テンプレートに沿って作成されています。必要に応じて項目の追加・修正を行ってください。*