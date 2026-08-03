# layers-martin

国土地理院の `layers.txt` を再帰的に読み取り、Martin 互換の `/catalog` と `/{sourceID}` TileJSON を GitHub Pages 向けに静的生成するためのプロジェクトです。

Repository description:

```text
Static Martin-compatible catalog generator from GSI layers.txt
```

## このプロジェクトの目的

`layers-martin` は、国土地理院が提供する `layers.txt` 群を Martin 型の発見 API に近い静的 JSON 群へ変換します。

Martin では、概念的に次のような API モデルが使われます。

```text
/catalog       利用可能なタイルソース一覧
/{sourceID}    各タイルソースの TileJSON
```

このプロジェクトでは Martin サーバを動かすのではなく、GitHub Pages で配信できる静的ファイルとして、同等に扱いやすいカタログと TileJSON を生成します。

タイル実体は複製せず、GSI 等の既存タイル URL を参照します。生成するのは、あくまで発見用のメタデータです。

## Staffプロンプト

このカタログを実際に使う生成AI(Staccatoアーキテクチャの**Staff**役)向けのシステムプロンプトも、このリポジトリで管理しています。

- [STAFF_PROMPT.md](STAFF_PROMPT.md) — 通常版。カタログをその場でfetchできる環境向け(インターネット接続前提)。
- [GENNAI_PROMPT.md](GENNAI_PROMPT.md) — タイトなオフライン版。システムプロンプトは保存できるがインターネットに一切アクセスできない生成AI(例: 政府AI「源内」)向け。約4,000字。設計判断は [DECISIONS.md](DECISIONS.md) D28 を参照。

どちらも `dwg7/spiccato`(このカタログを使うCartographer実装)のフォーム画面から直接コピーできます: <https://dwg7.github.io/spiccato/>

## 背景

地理院地図の `layers.txt` には、多数のレイヤ定義が階層的に収録されています。

一方、Martin や MapLibre 系の利用では、次のような単純な発見モデルが扱いやすいです。

```text
1. /catalog を取得して source ID の一覧を得る
2. /{sourceID} を取得して TileJSON を得る
3. TileJSON の tiles URL を使って地図クライアントからタイルを読む
```

`layers-martin` は、この 2 つの世界をつなぐための変換器です。

## 変換方針

初期版では、`layers.txt` の全内容を完全保存するアーカイブではなく、Martin 型クライアントが扱いやすい軽量なタイルソースカタログを作ることを優先します。

### 含めるレイヤ

catalog に含める対象は、画像タイルおよび MVT 系タイルに限定します。

```text
.png
.jpg
.jpeg
.webp
.pbf
.mvt
```

### 除外するレイヤ

次の形式は catalog から除外します。

```text
.geojson
.topojson
.txt
.kml
その他不明な形式
```

除外したレイヤは捨てずに、`docs/report.json` に記録します。

これにより、catalog を軽量に保ちながら、将来の再検討材料を残します。

### HTML と attribution の扱い

`layers.txt` の `html` および `attribution` は、初期実装では原文のまま保持します。

タグ除去やサニタイズは行いません。

### GSI layers.txt 由来のキー

次のような GSI `layers.txt` 由来のキーは、`gsi:` 接頭辞を付けず、可能な限りそのまま TileJSON の拡張キーとして保持します。

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

TileJSON 標準キーに自然に対応するものは、標準キーにも写像します。

```text
Layer.title        -> name
Layer.url          -> tiles[0]
Layer.attribution  -> attribution
Layer.minZoom      -> minzoom
Layer.maxZoom      -> maxzoom
Layer.area         -> center、変換可能な場合
Layer.bounds       -> bounds、変換可能な場合
```

### `legend_image_url`(独自拡張キー)

`legendUrl` が凡例画像を直接指していない、または存在しない場合に備え、`html` 内に埋め込まれた凡例画像を抽出した
独自拡張キー `legend_image_url` を付与します(存在する場合のみ)。決定順位や抽出方法の詳細は
[DECISIONS.md](DECISIONS.md) D18 を参照してください。

## 出力構成

生成されるファイルは `docs/` 配下に置かれます。

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

### `docs/catalog`

Martin 互換を意識した catalog です。

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

catalog には、TileJSON への相対リンクは入れません。

Martin を使い慣れた利用者であれば、catalog の key を見て `/{sourceID}` を取得すれば TileJSON が得られる、というモデルが分かるためです。

### `docs/catalog.json`

`docs/catalog` と同じ内容です。

GitHub Pages 上での確認、デバッグ、Content-Type 問題の回避を目的として生成します。

### `docs/{id}`

Martin の `/{sourceID}` に相当する TileJSON です。

例:

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

### `docs/{id}.json`

`docs/{id}` と同じ内容です。

こちらも確認・デバッグ用のコピーです。

### `docs/report.json`

変換時の除外、警告、取得失敗、ID 変更などを記録します。

例:

```json
{
  "summary": {
    "input_root": "https://maps.gsi.go.jp/layers_txt/layers.txt",
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
  "warnings": []
}
```

### `docs/manifest.json`

生成日時、入力 URL、ジェネレータ名、対象拡張子などの実行メタデータを記録します。

### `docs/index.html`

人間がブラウザで確認するための簡易インデックスページです。

## source ID の決定方法

source ID は、安定性を優先して次の順で決定します。

```text
1. Layer.id があれば使う
2. URL の /xyz/{id}/ から抽出できれば使う
3. path + title から slug を生成する
4. 重複時は短い安定 hash suffix を付ける
```

Martin の予約語との衝突は避けます。

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

予約語に衝突した場合は、例えば `gsi_catalog` のように安全な ID に変換します。

## subdomains の扱い

初期実装では `subdomains` の展開は行いません。

現在の HTTPS / HTTP2 / HTTP3 環境では、旧来のドメインシャーディングは主要経路として扱わなくてよい、という判断です。

方針は次のとおりです。

```text
- subdomains は展開しない
- subdomains が存在する場合は、そのまま TileJSON に透過する
- subdomains が非空の場合は warning として report.json に記録する
- URL に {s} または {subdomain} が含まれる場合も warning として記録する
```

## MVT の扱い

`.pbf` および `.mvt` は catalog に含めます。

ただし、`layers.txt` だけから MVT 内の `vector_layers` や fields を確実に復元できないため、初期実装では `vector_layers` は省略します。

その場合、`report.json` に `vector_layers_omitted` warning を記録します。

MVT の `content_type` は初期実装では次とします。

```text
application/x-protobuf
```

## URL 正規化

実データまたは GitHub 表示上、タイル URL に次のような空白が混入して見える場合があります。

```text
https://maps.gsi.go.jp/xyz/relief/ {z}/ {x}/ {y}.png
```

スクリプトでは安全側で次の正規化を行います。

```text
"/ {z}" -> "/{z}"
"/ {x}" -> "/{x}"
"/ {y}" -> "/{y}"
"{z}/ {x}/ {y}" -> "{z}/{x}/{y}"
```

ただし、URL の意味を変えるような過剰な正規化は行いません。

## 使い方

Ruby が動作する環境で次を実行します。

```sh
ruby build_catalog.rb   --root https://maps.gsi.go.jp/layers_txt/layers.txt   --out docs
```

オプション:

```text
--root URL    入力 layers.txt のルート URL
--out DIR     出力ディレクトリ。既定値は docs
--quiet       進捗ログを抑制
```

## GitHub Pages での公開

GitHub Pages の公開元を `docs/` に設定すると、次のような URL で利用できます。

```text
https://hfu.github.io/layers-martin/catalog
https://hfu.github.io/layers-martin/std
https://hfu.github.io/layers-martin/std.json
```

## GitHub Actions での自動更新

`.github/workflows/build-catalog.yml` を配置すると、手動実行または定期実行で `docs/` を更新できます。

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
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
      - run: ruby build_catalog.rb --root https://maps.gsi.go.jp/layers_txt/layers.txt --out docs
      - run: test -f docs/catalog
      - run: test -f docs/catalog.json
      - run: git diff -- docs
      - name: Commit changes
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add docs
          git commit -m "Update static Martin catalog" || exit 0
          git push
```

## 実装ファイル

初期構成はシンプルです。

```text
build_catalog.rb
README.md
.github/workflows/build-catalog.yml
```

将来的には、必要に応じて次のように分割できます。

```text
scripts/
  build_catalog.rb
  layers_reader.rb
  tilejson_mapper.rb
  martin_catalog.rb
  validate_outputs.rb
  utils.rb
```

## 検査項目

実装・運用では、少なくとも次を確認します。

```text
1. URL に {z}, {x}, {y} があるか
2. URL が絶対 URL か
3. URL の拡張子が画像・MVT 系か
4. URL に {s} が残っていないか
5. subdomains が非空でないか
6. source ID が Martin 予約語でないか
7. source ID が重複していないか
8. docs/{id} と docs/{id}.json の内容が一致するか
9. docs/catalog と docs/catalog.json の内容が一致するか
10. catalog の tiles key と生成済み docs/{id} が一致するか
```

## このプロジェクトがしないこと

初期版では、次は行いません。

```text
- タイル実体の複製
- Martin サーバの起動
- GeoJSON / TopoJSON / TXT / KML レイヤの catalog 収録
- MVT の vector_layers 自動推定
- subdomains の自動展開
- html / attribution のサニタイズ
- styleurl から MapLibre Style JSON への変換
```

## 今後の候補

- `report.json` を用いた変換品質の可視化
- MapLibre GL JS による確認ページの強化
- MVT の `vector_layers` 補完方法の検討
- `styleurl` の処理方針の検討
- catalog の差分更新レポート
- GitHub Actions 実行結果のサマリ出力

## ライセンス

このリポジトリ発祥のドキュメントやコードは CC0 です。

既存の GSI データ、地理院タイル、Martin、MapLibre 関連のライセンスや利用条件を確認した上で、このリポジトリのライセンスを設定してください。

## 謝辞

このプロジェクトは、国土地理院の `layers.txt` と、Martin / MapLibre 型のシンプルなタイル発見モデルを接続するための実験的な取り組みです。

国連オープンGISイニシアティブ DWG 7 国連スマート地図グループの活動に資する、軽量で再利用可能なカタログ生成の実装を目指します。
