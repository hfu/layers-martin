# HANDOVER.md

## 件名

GSI `layers.txt` を Martin 互換の静的カタログ／TileJSON 群へ変換するプロジェクト引継ぎ

## 目的

国土地理院が提供する `layers.txt` 群を再帰的に読み取り、MapLibre Martin の次の API モデルに近い静的 JSON 群へ変換する。

- `/catalog`: 利用可能なタイルソース一覧
- `/{sourceID}`: 各タイルソースの TileJSON

GitHub Pages では Martin サーバを動かさず、`docs/` 配下に静的ファイルとして配置する。タイル実体は GSI 等の既存タイル URL を参照し、このプロジェクトではカタログおよび TileJSON メタデータのみを生成する。

## 上位構想: Staccato アーキテクチャにおける位置づけ

`layers-martin` は単独のツールではなく、`unopengis/staccato-spec` が定義する Staff-Cartographer アーキテクチャの一部として構想されている（`UNopenGIS/7#936` が親issue、`UNopenGIS/7#938` が本プロジェクトのissue）。

Staccato は次の 4 者モデルを定義する。

```text
User          問いを投げる
Staff         エンタープライズ内で動作し、問いを解釈して Map Intent (YAML) を生成する
Cartographer  インターネット側で動作し、Map Intent を受け取って MapLibre GL JS で描画する
Library       カタログメタデータと地理空間リソースを公開する
```

`layers-martin` は、この **Library** 役割の最初の実装である。Staff は起動時に設定されたカタログからしかレイヤーを解決してはならず、Cartographer は Map Intent だけから確定的に描画できなければならない。そのため Library が出す情報は、GSI `layers.txt` の忠実な複製である必要はなく、Staff・Cartographer が扱いやすい形に正規化されている必要がある。

staccato-spec の `spec/catalog-integration.md` は、タイル中心のカタログ（`martin`, `layers_txt`）に対して **TileJSON 3.0 (collection) を正準の消費モデル**とすることを定めており、`spec/layers_txt_to_tilejson.md` は本プロジェクトが行っている `layers.txt → TileJSON` 変換とほぼ同内容の変換ガイドを示している。両者は独立に収束したものであり、方針の一致は意図的なものとして扱ってよい。

### 設計方針への反映

この位置づけから、本プロジェクトの変換方針は次のスタンスを取る。

- 元データへの忠実性は優先するが、絶対条件ではない。GSI `layers.txt` の語彙・`html`・`attribution` は可能な限り原文保持する（下記「確定した初期方針」参照）。
- 一方で、Martin/TileJSON 互換性を壊すもの（予約語 ID との衝突、`{s}` や空白混入など不正な URL、Martin が扱えない拡張子）は、無条件に温存せず、正すか除外する。
- 何を正した／除外したかは必ず `report.json` に記録し、追跡可能にする。「忠実性を保ちつつ、直すべきものは直す」というキュレーションの妥当性は、この記録可能性によって担保される。

## レイヤー抑制方針

実データで実行したところ、拡張子・URLフィルタを通過するレイヤーが 12,603 件にのぼることが判明した(2026-07-02 時点)。内訳を調べると、次の構成だった。

```text
干渉SAR（source_url が https://maps.gsi.go.jp/sar/ 配下）  10,538 件
災害イベント速報・重ねるハザードマップ等                        466 件
地質図（G50K 等）・土地分類など系統的主題図                  1,112 件
標準地図・写真・標高等の基本図・その他                          487 件
```

`干渉SAR` は、ALOS/ALOS-2/ALOS-4 による干渉SAR画像であり、特定の地震・火山イベント × 特定の観測日ペアごとに1レイヤーが生成される構造になっている（例: `2007/02/23～2007/04/10_AR`）。これは std や seamlessphoto のような安定した基本図とは性質が異なり、過去の個別観測結果のスナップショットである。この 10,538 件がカタログの 8 割超を占め、Staff がカタログから意味のあるレイヤーを解決する際のノイズになると判断した。

### 決定（2026-07-02）

- **干渉SAR（`source_url` が `https://maps.gsi.go.jp/sar/` で始まるレイヤー）は、主カタログ (`docs/catalog`) から除外する。**
- 除外した干渉SARレイヤーは削除せず、`report.json` の `excluded`（`reason: "sar_observation_snapshot"`）に全件記録する。`report.json` の `summary.excluded_by_reason` で件数を追跡できる。
- **地質図・土地分類などの系統的主題図（図郭単位で細分化されているが日付スナップショットではないもの）と、災害イベント速報・重ねるハザードマップは、今回は抑制対象に含めず、主カタログに残す。** 主題図は std/seamlessphoto と同様に安定したカタログの一部として扱う。

### 今後見直す場合の観点

この抑制はカタログサイズ抑制のための初期判断であり、絶対的な方針ではない。将来的に次のような見直しがあり得る。

- 干渉SARを完全に切り捨てるのではなく、`docs/catalog-observations` のような別カタログに分離し、Staff が catalog_type ごとに precedence を設定して明示的に参照できるようにする（staccato-spec の `catalog-integration.md` が定義する複数カタログ・resolution_policy モデルに沿う形）。
- 災害イベント速報・重ねるハザードマップについても、件数の推移によっては同様の抑制を検討する。
- 抑制基準を `source_url` の URL プレフィックスではなく、より意味的な基準（例: レイヤーIDに観測日ペアが含まれるか）に変更する。

いずれの場合も、`report.json` に除外理由と件数が残っていることが前提であり、抑制ルールの変更は `build_catalog.rb` 内の該当箇所（`SAR_SOURCE_PREFIX` 判定）を直すだけで良いようにしてある。

## 重複レイヤーの抑制方針

`layers.txt` は、同一のタイルURL（同一のtiles実体）を複数の `LayerGroup` から重複して参照することがある。例:

- `全国最新写真（シームレス）`（id: `seamlessphoto`）が「年代別の写真」「災害伝承・避難場所等」「近年の災害」配下など複数箇所から参照される。
- `色別標高図`（id: `relief`）が、通常の「標高・土地の凹凸」配下と、特定の災害イベント配下（`_relief_20160830` のような先頭アンダースコア付きの災害文脈エイリアスid）の両方から参照される。
- タイルURLは同じだが、UI上の見せ方が異なるための別id（例: `gsi-compare-photo` は `seamlessphoto` と同じタイルを時系列比較スライダーとして表示するUI変種）が存在する。

### 決定（2026-07-02）

- **重複判定は tiles URL の完全一致で行う**（id/titleではない。idやtitleは参照文脈によって変わるが、実際に配信されるタイルはURLで決まるため）。
- **重複は抑制する**。1つのURLにつき1エントリのみを主カタログに残し、残りは `report.json` の `excluded`（`reason: "duplicate_url_reference"`）に全件記録する。
- **複数エントリを1つに統合し、代替id/文脈をメタデータとして残す案は見送り、バックログとする。** 統合には文脈依存の`html`をどう扱うか判断が要り、LLMによる要約・統合も将来検討し得るが、GitHub Actions上で使うには複雑さとコストが見合わない。
- **canonical（代表として残す1件）の選定ルールは次の優先順で決定する**:
  1. idが災害文脈エイリアス（先頭が `_`）でないものを優先する。
  2. idがタイルURL自身の `/xyz/{id}/` セグメントと一致するものを優先する（そのタイルソース自身が名乗っている名前を、参照元のメニュー文脈より優先する）。
  3. 上記で決まらない場合は、木構造を辿った際の最初の出現を採用する。

ルール2は実装時に必要になった。単純な「先着順」だけだと、`seamlessphoto`グループで`gsi-compare-photo`（時系列比較スライダー用のUI変種）が`seamlessphoto`本体より先に出現するため誤って代表に選ばれてしまうケースがあった。URL自身が declare する id を優先することで解決した。

## 参照情報

- GSI Maps のルート `layers.txt` は `https://maps.gsi.go.jp/layers_txt/layers.txt`。
- GitHub 上では `gsi-cyberjapan/gsimaps` の `gh-pages` ブランチに `layers_txt/layers.txt` および `layers1.txt`〜`layers7.txt` 等が存在する。
- 現在確認できるルート `layers.txt` は、`layers_topic_...txt` や `layers1.txt`〜`layers7.txt` への `url` 配列を持つ。
- `layers-dot-txt-spec` では、レイヤ定義は `Layer` または `LayerGroup` によって構成され、`LayerGroup` は `entries` または `src` により下位レイヤを持つ。
- Martin は `/catalog` でソース一覧、`/{sourceID}` で Source TileJSON、`/{sourceID}/{z}/{x}/{y}` でタイルを返すモデルである。
- TileJSON 3.0.0 では `tilejson` と `tiles` が必須であり、`tiles` は絶対 URL の配列である。

## 確定した初期方針

### 1. 出力は Martin 互換を優先する

`docs/{id}` を正規の TileJSON エンドポイント相当として生成する。

同時に、GitHub Pages 上での確認・デバッグ・Content-Type 回避のため、`docs/{id}.json` も同内容で生成する。

```text
docs/
  catalog
  catalog.json
  {id}
  {id}.json
  index.html
  manifest.json
  report.json
```

### 2. catalog には TileJSON へのリンクを入れない

Martin 利用者は `/catalog` の key から `/{sourceID}` を引けば TileJSON が取れることを理解している前提とし、catalog 内に `tilejson: "./{id}"` のような独自リンクは入れない。

catalog は Martin 互換性を優先し、原則として次のような最小構造とする。

```json
{
  "tiles": {
    "std": {
      "name": "標準地図",
      "content_type": "image/png"
    }
  },
  "sprites": {},
  "fonts": {},
  "styles": {}
}
```

### 3. catalog 対象は画像・MVT 系に限定する

catalog に含める対象は、MapLibre / Martin 型クライアントが扱いやすいタイルソースに限定する。

含める拡張子:

```text
.png
.jpg
.jpeg
.webp
.pbf
.mvt
```

除外する拡張子・形式:

```text
.geojson
.topojson
.txt
.kml
その他不明な形式
```

除外されたレイヤは `report.json` に記録する。これにより catalog は軽量化しつつ、将来再検討可能な情報は保持する。

### 4. `html` / `attribution` は原文 HTML のまま保持する

初期実装では、`html` および `attribution` はタグ除去やサニタイズを行わず、原文のまま TileJSON に保持する。

例:

```json
{
  "tilejson": "3.0.0",
  "name": "色別標高図",
  "tiles": [
    "https://maps.gsi.go.jp/xyz/relief/{z}/{x}/{y}.png"
  ],
  "attribution": "原文 attribution",
  "html": "<div class='layer_text'>...</div>"
}
```

### 5. GSI layers.txt の語彙は接頭辞なしで透過する

`gsi:` 接頭辞は付けない。

以下のような GSI layers.txt 由来のキーは、可能な限りそのまま TileJSON 拡張キーとして保持する。

```text
maxNativeZoom
legendUrl
iconUrl
styleurl
html
cocotile
area
tileSize
errorTileUrl
```

TileJSON 標準キーに自然に対応するものは標準キーにも写像する。

```text
Layer.title       -> name
Layer.url         -> tiles[0]
Layer.attribution -> attribution
Layer.minZoom     -> minzoom
Layer.maxZoom     -> maxzoom
Layer.area        -> center, 変換可能な場合
Layer.bounds      -> bounds, 変換可能な場合
```

ただし、原キーも保持してよい。情報損失を避けることを優先する。

### 6. subdomains は展開しない

現在の実データでは、旧来の `cyberjapandata-t{s}` と `subdomains: "123"` 型のドメインシャーディングは主要経路として扱わなくてよい。

初期実装では次の方針とする。

```text
- subdomains の展開処理は実装しない。
- subdomains が存在する場合はそのまま透過する。
- subdomains が非空の場合は warning として report.json に記録する。
- url に {s} が含まれる場合も warning として report.json に記録する。
```

### 7. MVT は catalog に含めるが `vector_layers` は省略する

`.pbf` / `.mvt` は catalog に含める。

ただし、`layers.txt` だけから MVT 内の `vector_layers` や fields を確実に復元できないため、初期実装では `vector_layers` は省略する。

MVT レイヤについては `report.json` に `vector_layers_omitted` の警告を残す。

```json
{
  "tilejson": "3.0.0",
  "name": "example vector tile",
  "tiles": [
    "https://example.com/{z}/{x}/{y}.pbf"
  ],
  "scheme": "xyz"
}
```

catalog 側の content type は初期版では Martin の例に寄せて次とする。

```text
.pbf / .mvt -> application/x-protobuf
```

### 8. source_id は安定性を優先する

source ID は次の優先順位で決定する。

```text
1. Layer.id があれば使う
2. URL の /xyz/{id}/ から抽出できれば使う
3. path + title から slug を生成する
4. 重複時は短い安定 hash suffix を付ける
```

Martin の予約語は避ける。

```text
_
catalog
config
font
health
help
index
manifest
metrics
refresh
reload
sprite
status
```

予約語に衝突した場合は、例えば `gsi_{id}` のように安全な ID に変換する。

## 変換パイプライン

```text
1. ルート layers.txt を取得する
2. ルートが [{"url": "..."}] 形式であれば各 URL を取得する
3. {"layers": [...]} 形式であれば layers 配列を読む
4. LayerGroup.entries を再帰的にたどる
5. LayerGroup.src を相対 URL 解決して再帰的にたどる
6. Layer を抽出する
7. URL 拡張子で画像・MVT 系にフィルタする
8. source_id を決定する
9. TileJSON 3.0.0 を生成する
10. docs/{id} と docs/{id}.json に同内容を書き出す
11. Martin 風 catalog を docs/catalog と docs/catalog.json に書き出す
12. 除外、警告、重複処理、取得失敗を report.json に出力する
13. 実行メタデータを manifest.json に出力する
```

## 実装構成案

```text
scripts/
  build_catalog.py
  layers_reader.py
  tilejson_mapper.py
  martin_catalog.py
  validate_outputs.py
  utils.py
```

### `layers_reader.py`

責務:

- URL 取得
- JSON パース
- 相対 URL 解決
- `url` 配列形式のルート処理
- `layers` 配列の処理
- `LayerGroup.entries` の再帰処理
- `LayerGroup.src` の再帰処理
- 循環参照防止
- レイヤツリーパスの保持

出力例:

```json
{
  "source_url": "https://maps.gsi.go.jp/layers_txt/layers2.txt",
  "path": ["標高・土地の凹凸"],
  "layer": {
    "type": "Layer",
    "id": "relief",
    "title": "色別標高図",
    "url": "https://maps.gsi.go.jp/xyz/relief/{z}/{x}/{y}.png"
  }
}
```

### `tilejson_mapper.py`

責務:

- 対象拡張子判定
- URL 正規化
- source_id 決定
- TileJSON 3.0.0 生成
- content type 推定
- bounds / center の可能な範囲での変換
- GSI 語彙の透過
- warning 生成

### `martin_catalog.py`

責務:

- TileJSON 群から Martin 風 catalog 生成
- `tiles.{source_id}.name` 生成
- `tiles.{source_id}.content_type` 生成
- `sprites`, `fonts`, `styles` の空オブジェクト生成
- `tilejson` リンク等の非 Martin 的独自リンクは生成しない

### `validate_outputs.py`

責務:

- `docs/catalog` と `docs/catalog.json` の内容一致確認
- `docs/{id}` と `docs/{id}.json` の内容一致確認
- catalog の key と生成済み TileJSON の対応確認
- TileJSON に `tilejson: "3.0.0"` があること確認
- TileJSON に `tiles` が 1 件以上あること確認
- `tiles` の URL が絶対 URL であること確認
- `{z}`, `{x}`, `{y}` が存在すること確認

## URL 正規化方針

GitHub の表示または実データにより、次のような空白が混入して見える場合がある。

```text
https://maps.gsi.go.jp/xyz/relief/ {z}/ {x}/ {y}.png
```

実装では安全側で次を行う。

```text
"/ {z}" -> "/{z}"
"/ {x}" -> "/{x}"
"/ {y}" -> "/{y}"
"{z}/ {x}/ {y}" -> "{z}/{x}/{y}"
URL 全体の前後空白除去
```

ただし、URL の意味を変える過剰な正規化は避ける。

## content_type 推定

```text
.png       -> image/png
.jpg       -> image/jpeg
.jpeg      -> image/jpeg
.webp      -> image/webp
.pbf       -> application/x-protobuf
.mvt       -> application/x-protobuf
```

除外対象:

```text
.geojson   -> excluded: unsupported_extension
.topojson  -> excluded: unsupported_extension
.txt       -> excluded: unsupported_extension
.kml       -> excluded: unsupported_extension
その他     -> excluded: unsupported_extension
```

## TileJSON 生成例

### 入力 Layer 例

```json
{
  "type": "Layer",
  "id": "relief",
  "title": "色別標高図",
  "url": "https://maps.gsi.go.jp/xyz/relief/{z}/{x}/{y}.png",
  "cocotile": true,
  "maxZoom": 18,
  "maxNativeZoom": 15,
  "legendUrl": "https://maps.gsi.go.jp/legend/attension_relief.html",
  "html": "<div class='layer_text'><p>標高に応じて色分けした地図です。</p></div>"
}
```

### 出力 `docs/relief` および `docs/relief.json`

```json
{
  "tilejson": "3.0.0",
  "name": "色別標高図",
  "tiles": [
    "https://maps.gsi.go.jp/xyz/relief/{z}/{x}/{y}.png"
  ],
  "scheme": "xyz",
  "maxzoom": 18,
  "maxZoom": 18,
  "maxNativeZoom": 15,
  "legendUrl": "https://maps.gsi.go.jp/legend/attension_relief.html",
  "html": "<div class='layer_text'><p>標高に応じて色分けした地図です。</p></div>",
  "cocotile": true,
  "source_url": "https://maps.gsi.go.jp/layers_txt/layers2.txt",
  "path": [
    "標高・土地の凹凸"
  ]
}
```

## catalog 生成例

```json
{
  "tiles": {
    "relief": {
      "name": "色別標高図",
      "content_type": "image/png"
    },
    "afm": {
      "name": "活断層図（都市圏活断層図）",
      "content_type": "image/png"
    }
  },
  "sprites": {},
  "fonts": {},
  "styles": {}
}
```

## report.json 仕様案

`report.json` には、変換対象外、警告、取得失敗、ID 重複、予約語衝突等を記録する。

```json
{
  "summary": {
    "input_root": "https://maps.gsi.go.jp/layers_txt/layers.txt",
    "fetched_files": 0,
    "layers_seen": 0,
    "tiles_included": 0,
    "layers_excluded": 0,
    "warnings": 0
  },
  "excluded": [
    {
      "id": "afm_spec",
      "title": "諸元情報",
      "url": "https://maps.gsi.go.jp/xyz/afm_spec/{z}/{x}/{y}.geojson",
      "reason": "unsupported_extension",
      "extension": ".geojson"
    }
  ],
  "warnings": [
    {
      "type": "subdomains_present",
      "id": "example",
      "subdomains": "123",
      "action": "kept_as_is_no_expansion"
    },
    {
      "type": "s_placeholder_present",
      "id": "example",
      "url": "https://cyberjapandata-t{s}.gsi.go.jp/xyz/example/{z}/{x}/{y}.png",
      "action": "not_expanded_initial_version"
    },
    {
      "type": "vector_layers_omitted",
      "id": "example_mvt",
      "action": "mvt_included_without_vector_layers"
    }
  ],
  "id_changes": [
    {
      "original": "catalog",
      "resolved": "gsi_catalog",
      "reason": "martin_reserved_id"
    }
  ],
  "failures": []
}
```

## manifest.json 仕様案

```json
{
  "generated_at": "2026-06-26T00:00:00Z",
  "generator": "gsi-layers-to-static-martin",
  "generator_version": "0.1.0",
  "input_root": "https://maps.gsi.go.jp/layers_txt/layers.txt",
  "output_layout": "martin-static-docs-id-and-json",
  "included_extensions": [
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".pbf",
    ".mvt"
  ],
  "excluded_extensions": [
    ".geojson",
    ".topojson",
    ".txt",
    ".kml"
  ]
}
```

## GitHub Actions 案

```yaml
name: build-catalog

on:
  workflow_dispatch:
  schedule:
    - cron: "0 18 * * *"

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: python scripts/build_catalog.py --root https://maps.gsi.go.jp/layers_txt/layers.txt --out docs
      - run: python scripts/validate_outputs.py --docs docs
      - run: git diff -- docs
      - name: Commit changes
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add docs
          git commit -m "Update static Martin catalog" || exit 0
          git push
```

## 実装時の検査項目

```text
1. url に {z}, {x}, {y} があるか
2. url が絶対 URL か
3. url の拡張子が画像・MVT 系か
4. url に {s} が残っていないか
5. subdomains が非空でないか
6. source_id が Martin 予約語でないか
7. source_id が重複していないか
8. docs/{id} と docs/{id}.json の内容が一致するか
9. docs/catalog と docs/catalog.json の内容が一致するか
10. catalog の tiles key と生成済み docs/{id} が一致するか
```

## エラー方針

- 取得不能な URL は変換全体を止めず、`report.json` に記録する。
- JSON パース不能なファイルはスキップし、`report.json` に記録する。
- `url` がない Layer は TileJSON 化せず、`report.json` に記録する。
- 対象外拡張子の Layer は catalog から除外し、`report.json` に記録する。
- ID 重複は安定 hash suffix で解決する。
- Martin 予約語との衝突は安全な ID に変換する。
- MVT の `vector_layers` 未生成はエラーではなく warning とする。

## 完了条件

- `docs/catalog` が生成される。
- `docs/catalog.json` が生成される。
- `docs/{id}` が生成される。
- `docs/{id}.json` が生成される。
- `docs/{id}` と `docs/{id}.json` の内容が一致する。
- 生成された全 TileJSON に `tilejson: "3.0.0"` がある。
- 生成された全 TileJSON に 1 つ以上の `tiles` がある。
- catalog の `tiles` に含まれる source ID について、対応する `docs/{id}` が存在する。
- `.geojson`, `.topojson`, `.txt`, `.kml` は catalog に含まれない。
- 除外レイヤ、警告、取得失敗、ID 変更が `report.json` に記録される。

## 現時点で追加の大きな意思決定は不要

初期実装に必要な主要方針は確定した。

次の作業は、以下の順に進める。

1. この HANDOVER に基づき `scripts/build_catalog.py` の初版を実装する。
2. 実際に `layers.txt` を再帰取得して `report.json` を確認する。
3. `subdomains` または `{s}` が実データに残っていないか、実行結果で再確認する。
4. 生成された catalog の件数、除外件数、MVT 件数を確認する。
5. MapLibre から代表レイヤを読み込む簡易確認ページ `docs/index.html` を追加する。

## 次の担当者へのメモ

このプロジェクトは、GSI `layers.txt` を完全保存するアーカイブではなく、Martin 型クライアントが使いやすい軽量なタイルソースカタログを作ることが目的である。

したがって、初期版では画像・MVT 系に限定し、GeoJSON、TopoJSON、TXT、KML 等は catalog から外す。除外情報は `report.json` に残す。`html` や `attribution` は原文保持とし、GSI layers.txt の語彙は接頭辞なしで透過する。

Martin 互換性を最優先し、`/catalog` と `/{sourceID}` に相当する `docs/catalog` と `docs/{id}` を正規出力とする。`.json` 付きファイルは実用上の確認・デバッグ用の同内容コピーである。
