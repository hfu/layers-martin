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

`layers-martin` は単独のツールではなく、`UNopenGIS/staccato-spec` が定義する Staff-Cartographer アーキテクチャの一部として構想されている（`UNopenGIS/7#936` が親issue、`UNopenGIS/7#938` が本プロジェクトのissue）。

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

## 現在の状態(2026-07-05 時点)

- 実装は `build_catalog.rb`(単一 Ruby スクリプト)。`docs/` に生成物一式を出力し、GitHub Actions(`build-catalog.yml`)が毎日 cron で再生成・コミットする。
- 主カタログは **1,861 件**。ルート `layers.txt` に加え `layers0.txt`([D13](DECISIONS.md#d13-layers0txt-を明示的に読み込む)、`std`/`pale`/`blank`/`english` 等の背景地図の在処)も読み込んでいる。拡張子除外・干渉SAR抑制([D9](DECISIONS.md#d9-干渉sarスナップショットレイヤーを主カタログから抑制する))・航空機SAR抑制([D15](DECISIONS.md#d15-航空機sar画像スナップショットも同じ原則で抑制する))・重複URL抑制([D10](DECISIONS.md#d10-同一タイルurlの重複参照を抑制する))を経てこの件数になっている。除外理由の内訳は `docs/report.json` の `summary.excluded_by_reason` を参照。
- `attribution` は約56%のレイヤーに自動付与されている([D16](DECISIONS.md#d16-ホスト名の完全一致テーブルでattributionを補う)、検証済みホストのみの完全一致テーブルによる)。
- `legend_image_url`(独自拡張キー)を約52%のレイヤーに付与している([D18](DECISIONS.md#d18-tilejsonを拡張しlegend_image_urlを新設する))。`legendUrl` が凡例画像を直接指さない/存在しない場合に、`html` から凡例画像を抽出する。
- GitHub Actions の成功判定は `validate_outputs.rb`([D11](DECISIONS.md#d11-actions-の成功判定を出力内容の検証に基づかせる))でカタログ内容そのものを検証するようになっている(ファイル存在確認だけだった旧版では、実質空のカタログでも success 表示になっていた)。
- Cartographer の実装(`hfu/faceless-cartographer`)との整合性確認を行い、`STAFF_PROMPT.md` に `catalog_context.version` の埋め方(`manifest.json` の `generated_at`)と、attribution が実際に画面表示されるかはレイヤーの既定表示状態にも依存する旨を追記した([D17](DECISIONS.md#d17-faceless-cartographer-との整合性確認catalog_contextversion-と-attribution可視性の文書化))。
- `STAFF_PROMPT.md` の実行可能プロンプト部分に、staccato-spec準拠の「あなたはStaffである」導入節(責務・正しいやりとりの形・Map Intent必須フィールド)を追加した([D19](DECISIONS.md#d19-staff_promptmdに「あなたはstaffである」導入節を追加する))。以前はlayers-martin固有の使い方からいきなり始まっており、Staffとしての基礎が欠けていた。
- `hfu/faceless-cartographer` がSPA・LLM無し・静的サイトへとアーキテクチャを変更したことを受け、`STAFF_PROMPT.md` の「Cartographer の `POST /` に貼り付ける」という実装依存の表現を「Cartographer の画面に貼り付ける」に改め、参照実装が実在すること・LLMを使わないこと・`cartographer_feedback` の環流を明記した([D20](DECISIONS.md#d20-staff_promptmdをfaceless-cartographerの新アーキテクチャに追随させる))。
- `layers-martin` の責務拡張として、実際に稼働している別の Martin サーバー `stars.optgeo.org/catalog`(国土地理院最適化ベクトルタイル `bvmap` を含む)を取り込めないか検討した結果、`layers-martin` 側のコード・カタログ生成物には手を入れず、`STAFF_PROMPT.md` に「別カタログ」として案内する形にとどめた([D21](DECISIONS.md#d21-staff_promptmdにstarsoptgeoorgを別カタログとして追記するaggregatorは作らない))。統合用のaggregatorリポジトリは不要と判断した — Map Intent の `catalog_context.active_catalogs` が複数カタログの併記をもともと許容しているため。`bvmap` の実際の描画(ジオメトリタイプ別の汎用スタイリング)は `hfu/faceless-cartographer` 側で実装済み(同リポジトリ D23)。
- D21 の内容(`stars.optgeo.org` を別カタログとして案内)は `hfu/faceless-cartographer` 側で実データによる統合テストと実ブラウザでのスクリーンショット確認まで完了した(同リポジトリ D23): `layers-martin` の `std` と `stars.optgeo.org` の `bvmap` を1つの Map Intent の `active_catalogs` から同時解決し、`bvmap` の実際の道路・水域・建物ポリゴンが描画されることまで確認済み。`layers-martin` 側は無変更のまま。
- `faceless-cartographer` が背景地図を常時自動描画(D24: bvmap グレースケール + Mapterhorn)に変更したことを受け、`STAFF_PROMPT.md` を全面的に再構成した([D22](DECISIONS.md#d22-staff_promptmdをfaceless-cartographer-d24に追随させstaffの振る舞いを主眼に再構成する))。背景地図指定の禁止を明示し(あえて指定すると見た目が崩れる)、新しく「Cartographer の現在の能力を踏まえること」節を追加。Staff としての正しい振る舞いが能力から自動的に導き出される構成にした。別カタログ(`stars.optgeo.org`)の案内も、「ベクトルベースマップの選択肢」から「Cartographer の既定背景には無いコンテンツ(全国空中写真・北海道火山図)」へと主目的をシフトさせ、`japan-seamless-aerial-z18`/`seamlessphoto512`/`vlcm`/`vbm` を中心に更新した。
- `STAFF_PROMPT.md` をハイブリッド対応（オンライン/オフライン両立）に設計した([D23](DECISIONS.md#d23-staff_promptmdをハイブリッド対応オンラインオフライン両立に設計する))。インターネット接続なしの環境でも Map Intent を組み立てられるよう、「オフラインフォールバック」セクションを追加。カテゴリ別(災害リスク、地形・地質、土地利用)に代表的な source_id ~15 件を列挙。二重ファイル化(STANDALONE_PROMPT.md)ではなく、単一ファイル内で両方の手順を並記することで保守を簡潔化。「札幌の地形分類を見たい」という自然言語入力に対するテスト実装により、layers-martin カタログで完全解決可能なことを確認済み。
- (運用メモ、`layers-martin` 自身にも当てはまる)GitHub Pages の branch-based デプロイ(このプロジェクトも `hfu/faceless-cartographer` も `build_type: legacy` で同じ仕組み)は、ビルド自体が成功していても「Deployment failed, try again later」で失敗することがまれにある(`faceless-cartographer` 側で2回観測)。自動生成される `pages build and deployment` ワークフローはリポジトリの `.github/workflows/` には存在せず修正できないため、症状が出た場合は `gh api repos/hfu/layers-martin/pages/builds -X POST` で再実行すれば通常は解消する。
- **2026-07-21**: `hfu/faceless-cartographer` の `required_styles`/`optional_styles`(D39、Map Intent から `style_id` でスタイル全体を参照できる新フィールド)を `STAFF_PROMPT.md` に反映した([D27](DECISIONS.md#d27-staff_promptmdに-required_stylesoptional_stylesd39-を追加する))。`stars-optgeo` が公開済みの `vlcm`(火山土地条件図)・`vbm`(火山基本図)スタイルを、利用者が「完成した主題図そのもの」を求めている場合に使うよう案内する節・使い分けの目安・動作確認済みの例3を追加。単なる文書追記に留めず、独立エージェントにプロンプト自身の例とは異なる具体例(恵山)で Staff を演じさせ、`required_styles` が正しく汎化して生成されることを実証してから確定した(検証プロセスの詳細は `hfu/faceless-cartographer` DECISIONS.md D40 参照)。
- **2026-08-03**: インターネット非接続・システムプロンプト保存可能なAI(政府AI「源内」等)向けに `GENNAI_PROMPT.md` を一時的に新設したが、同日中に `dwg7/spiccato` 側へ移設した([D28](DECISIONS.md#d28-インターネット非接続かつシステムプロンプト保存可能なaigennai_promptmdを新設する)、Superseded)。理由: 内容の大部分がspiccato固有の`#q=`リンク構築規則であり、Cartographer実装に依存しないという本リポジトリの立場に反していたため。加えて同日、埋め込み範囲を精選版から全カタログ(既知のノイズ系統を除く)へ拡大する判断もあり、生成ロジックごとspiccato側(`scripts/build-gennai-prompt.mjs`)に移した。本リポジトリには残らない。詳細はspiccato側のDECISIONS.mdを参照。
- 既知のバックログ(詳細は [DECISIONS.md](DECISIONS.md) の「バックログ」節):
  - D10 で見送った「重複レイヤーの統合」。
  - `maps.gsi.go.jp` 系(811件)の `attribution` 欠落(D16 で意図的に保留)。
  - インターネット接続できないエンタープライズAI向けの、fetch不要なスタンドアロン版Staffプロンプト(仮称`STANDALONE_PROMPT.md`、全カタログ埋め込み構想)は本リポジトリでの実装としては不採用のまま。動機となった課題自体は`dwg7/spiccato`側の`GENNAI_PROMPT.md`で解決している(D28、上記、Superseded)。
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
