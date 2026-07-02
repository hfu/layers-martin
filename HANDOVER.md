# HANDOVER.md

## 件名

GSI `layers.txt` を Martin 互換の静的カタログ／TileJSON 群へ変換するプロジェクト引継ぎ

## 目的

国土地理院が提供する `layers.txt` 群を再帰的に読み取り、MapLibre Martin の次の API モデルに近い静的 JSON 群へ変換する。

- `/catalog`: 利用可能なタイルソース一覧
- `/{sourceID}`: 各タイルソースの TileJSON

GitHub Pages では Martin サーバを動かさず、`docs/` 配下に静的ファイルとして配置する。タイル実体は GSI 等の既存タイル URL を参照し、このプロジェクトではカタログおよび TileJSON メタデータのみを生成する。

このプロジェクトは、GSI `layers.txt` を完全保存するアーカイブではなく、Martin 型クライアントが使いやすい軽量なタイルソースカタログを作ることを目的とする。元データへの忠実性は優先するが絶対条件ではなく、Martin/TileJSON 互換性やカタログの実用性を壊すものは正すか除外する。何を正した／除外したかは常に `report.json` に記録し、追跡可能にする。

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

具体的な設計判断とその理由は [DECISIONS.md](DECISIONS.md) を参照。Staff がこのカタログを実際に解決に使う際の使い方(既知の欠落への対処を含む)は [STAFF_PROMPT.md](STAFF_PROMPT.md) を参照。

## 現在の状態(2026-07-02 時点)

- 実装は `build_catalog.rb`(単一 Ruby スクリプト)。`docs/` に生成物一式を出力し、GitHub Actions(`build-catalog.yml`)が毎日 cron で再生成・コミットする。
- 主カタログは **1,861 件**。ルート `layers.txt` に加え `layers0.txt`([D13](DECISIONS.md#d13-layers0txt-を明示的に読み込む)、`std`/`pale`/`blank`/`english` 等の背景地図の在処)も読み込んでいる。拡張子除外・干渉SAR抑制([D9](DECISIONS.md#d9-干渉sarスナップショットレイヤーを主カタログから抑制する))・航空機SAR抑制([D15](DECISIONS.md#d15-航空機sar画像スナップショットも同じ原則で抑制する))・重複URL抑制([D10](DECISIONS.md#d10-同一タイルurlの重複参照を抑制する))を経てこの件数になっている。除外理由の内訳は `docs/report.json` の `summary.excluded_by_reason` を参照。
- `attribution` は約56%のレイヤーに自動付与されている([D16](DECISIONS.md#d16-ホスト名の完全一致テーブルでattributionを補う)、検証済みホストのみの完全一致テーブルによる)。
- GitHub Actions の成功判定は `validate_outputs.rb`([D11](DECISIONS.md#d11-actions-の成功判定を出力内容の検証に基づかせる))でカタログ内容そのものを検証するようになっている(ファイル存在確認だけだった旧版では、実質空のカタログでも success 表示になっていた)。
- Cartographer の実装(`hfu/faceless-cartographer`)との整合性確認を行い、`STAFF_PROMPT.md` に `catalog_context.version` の埋め方(`manifest.json` の `generated_at`)と、attribution が実際に画面表示されるかはレイヤーの既定表示状態にも依存する旨を追記した([D17](DECISIONS.md#d17-faceless-cartographer-との整合性確認catalog_contextversion-と-attribution可視性の文書化))。
- 既知のバックログ(詳細は [DECISIONS.md](DECISIONS.md) の「バックログ」節):
  - D10 で見送った「重複レイヤーの統合」。
  - `maps.gsi.go.jp` 系(811件)の `attribution` 欠落(D16 で意図的に保留)。
  - `bounds`/`center` が過半数のレイヤーで欠落している。

## 参照情報

- GSI Maps のルート `layers.txt` は `https://maps.gsi.go.jp/layers_txt/layers.txt`。
- GitHub 上では `gsi-cyberjapan/gsimaps` の `gh-pages` ブランチに `layers_txt/layers.txt` および `layers1.txt`〜`layers7.txt` 等が存在する。
- 現在確認できるルート `layers.txt` は、`layers_topic_...txt` や `layers1.txt`〜`layers7.txt` への `url` 配列を持つ。
- `layers-dot-txt-spec` では、レイヤ定義は `Layer` または `LayerGroup` によって構成され、`LayerGroup` は `entries` または `src` により下位レイヤを持つ。
- Martin は `/catalog` でソース一覧、`/{sourceID}` で Source TileJSON、`/{sourceID}/{z}/{x}/{y}` でタイルを返すモデルである。
- TileJSON 3.0.0 では `tilejson` と `tiles` が必須であり、`tiles` は絶対 URL の配列である。

## 次の担当者へ

出力フォーマットの正確な仕様は `build_catalog.rb` と、実際に生成された `docs/` 以下のファイルを直接参照するのが最も確実(ドキュメントの二重管理を避けるため、生成例のスキーマはここには置いていない)。設計判断の背景を知りたい場合は [DECISIONS.md](DECISIONS.md) を参照。
