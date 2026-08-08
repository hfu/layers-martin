# DECISIONS.md

`layers-martin` の設計判断を ADR (Architecture Decision Record) 形式で記録する。

各決定は次の構成を持つ。

- **Status**: 決定の現在の状態(Accepted / Superseded 等)
- **Context**: なぜその決定が必要になったか
- **Decision**: 何を決めたか
- **Consequences**: その決定によって何が起きるか、将来見直す場合の観点

背景となる上位構想(Staccato アーキテクチャにおける本プロジェクトの位置づけ)は [HANDOVER.md](HANDOVER.md) を参照。実装は `build_catalog.rb` を正とし、ここでは判断の理由のみを記録する(生成物の具体的なスキーマは実際の `docs/` 出力を参照)。

## 目次

| # | タイトル | Status | Date |
|---|---|---|---|
| [D1](#d1-出力はmartin互換を正規表現とする) | 出力は Martin 互換を正規表現とする | Accepted | 2026-06-26 |
| [D2](#d2-catalogにtilejsonへのリンクを含めない) | catalog に TileJSON へのリンクを含めない | Accepted | 2026-06-26 |
| [D3](#d3-catalog対象は画像mvt系拡張子に限定する) | catalog 対象は画像・MVT 系拡張子に限定する | Accepted | 2026-06-26 |
| [D4](#d4-htmlattributionは原文のまま保持する) | `html` / `attribution` は原文のまま保持する | Accepted | 2026-06-26 |
| [D5](#d5-gsi-layerstxt-の語彙は接頭辞なしで透過する) | GSI layers.txt の語彙は接頭辞なしで透過する | Accepted | 2026-06-26 |
| [D6](#d6-subdomains-は展開しない) | subdomains は展開しない | Accepted | 2026-06-26 |
| [D7](#d7-mvt-は含めるが-vector_layers-は省略する) | MVT は含めるが `vector_layers` は省略する | Accepted | 2026-06-26 |
| [D8](#d8-source_id-の決定順位とmartin予約語の回避) | source_id の決定順位と Martin 予約語の回避 | Accepted | 2026-06-26 |
| [D9](#d9-干渉sarスナップショットレイヤーを主カタログから抑制する) | 干渉SARスナップショットレイヤーを主カタログから抑制する | Accepted | 2026-07-02 |
| [D10](#d10-同一タイルurlの重複参照を抑制する) | 同一タイルURLの重複参照を抑制する | Accepted | 2026-07-02 |
| [D11](#d11-actions-の成功判定を出力内容の検証に基づかせる) | Actions の成功判定を出力内容の検証に基づかせる | Accepted | 2026-07-02 |
| [D12](#d12-tilejson-の-name-はプレーンテキスト化する) | TileJSON の `name` はプレーンテキスト化する | Accepted | 2026-07-02 |
| [D13](#d13-layers0txt-を明示的に読み込む) | `layers0.txt` を明示的に読み込む | Accepted | 2026-07-02 |
| [D14](#d14-staff-プロンプトの置き場所とmap-intent-vnextへの準拠) | Staff プロンプトの置き場所と map-intent-vnext への準拠 | Accepted | 2026-07-02 |
| [D15](#d15-航空機sar画像スナップショットも同じ原則で抑制する) | 航空機SAR画像スナップショットも同じ原則で抑制する | Accepted | 2026-07-02 |
| [D16](#d16-ホスト名の完全一致テーブルでattributionを補う) | ホスト名の完全一致テーブルで `attribution` を補う | Accepted | 2026-07-02 |
| [D17](#d17-faceless-cartographer-との整合性確認catalog_contextversion-と-attribution可視性の文書化) | `faceless-cartographer` との整合性確認: `catalog_context.version` と attribution可視性の文書化 | Accepted | 2026-07-03 |
| [D18](#d18-tilejsonを拡張しlegend_image_urlを新設する) | TileJSONを拡張し `legend_image_url` を新設する | Accepted | 2026-07-03 |
| [D19](#d19-staff_promptmdに「あなたはstaffである」導入節を追加する) | `STAFF_PROMPT.md` に「あなたは Staff である」導入節を追加する | Accepted | 2026-07-03 |
| [D20](#d20-staff_promptmdをfaceless-cartographerの新アーキテクチャに追随させる) | `STAFF_PROMPT.md` を `faceless-cartographer` の新アーキテクチャに追随させる | Accepted | 2026-07-04 |
| [D21](#d21-staff_promptmdにstarsoptgeoorgを別カタログとして追記するaggregatorは作らない) | `STAFF_PROMPT.md` に `stars.optgeo.org` を別カタログとして追記する。aggregatorは作らない | Accepted | 2026-07-04 |
| [D22](#d22-staff_promptmdをfaceless-cartographer-d24に追随させstaffの振る舞いを主眼に再構成する) | `STAFF_PROMPT.md` を `faceless-cartographer` D24 に追随させ、Staff の振る舞いを主眼に再構成する | Accepted | 2026-07-08 |
| [D23](#d23-staff_promptmdをハイブリッド対応オンラインオフライン両立に設計する) | `STAFF_PROMPT.md` をハイブリッド対応(オンライン/オフライン両立)に設計する | Accepted | 2026-07-09 |
| [D24](#d24-staff_promptmd-を指標駆動の実証ループで改善する) | `STAFF_PROMPT.md` を「指標駆動の実証ループ」で改善する | Accepted | 2026-07-16 |
| [D25](#d25-凡例画像の抽出を-a-href-リンク形式にも拡張するd18-の拡張) | 凡例画像の抽出を `<a href>` リンク形式にも拡張する（D18 の拡張） | Accepted | 2026-07-17 |
| [D26](#d26-pdf-のみで公開される凡例を-legend_pdf_url-として収録する全レイヤー点検の結果) | PDF のみで公開される凡例を `legend_pdf_url` として収録する（全レイヤー点検の結果） | Accepted | 2026-07-17 |
| [D27](#d27-staff_promptmd-に-required_stylesoptional_stylesd39を追加する) | `STAFF_PROMPT.md` に `required_styles`/`optional_styles`(D39)を追加する | Accepted | 2026-07-21 |
| [D28](#d28-インターネット非接続かつシステムプロンプト保存可能なaigennai_promptmdを新設する) | インターネット非接続・システムプロンプト保存可能なAI向けに `GENNAI_PROMPT.md` を新設する | Superseded(`dwg7/spiccato`へ移設) | 2026-08-03 |
| [D29](#d29-staff_promptmdにspiccato向けの受け渡し方法urlリンク構築手順を追記する) | `STAFF_PROMPT.md` に spiccato 向けの受け渡し方法・URLリンク構築手順を追記する | Accepted | 2026-08-06 |

---

## D1: 出力は Martin 互換を正規表現とする

**Status**: Accepted

**Context**: GitHub Pages 上に Martin サーバを実際には動かせない。静的ファイルで `/catalog` と `/{sourceID}` を模す必要がある。

**Decision**: `docs/{id}` を正規の TileJSON エンドポイント相当とする。同時に GitHub Pages 上の確認・デバッグ・Content-Type 回避のため `docs/{id}.json` も同内容で生成する。`docs/catalog` と `docs/catalog.json` も同様。

**Consequences**: 出力ファイル数が実質倍になるが、`docs/{id}` と `docs/{id}.json` の内容一致はローカル検証で担保している(2026-07-02 時点でサンプル照合済み)。

## D2: catalog に TileJSON へのリンクを含めない

**Status**: Accepted

**Context**: Martin 利用者は `/catalog` の key から `/{sourceID}` を引けば TileJSON が取れることを前提にしている。

**Decision**: catalog 内に `tilejson: "./{id}"` のような独自リンクフィールドは入れない。catalog は `tiles`/`sprites`/`fonts`/`styles` のみを持つ最小構造とする。

**Consequences**: Martin 互換性が保たれる。独自拡張が必要になった場合は catalog 本体ではなく別ファイルで表現する。

## D3: catalog 対象は画像・MVT 系拡張子に限定する

**Status**: Accepted

**Context**: `layers.txt` には GeoJSON・TopoJSON・KML・TXT 等、タイル形式でないレイヤーも大量に含まれる。

**Decision**: `.png .jpg .jpeg .webp .pbf .mvt` のみを catalog に含める。それ以外は除外する。

**Consequences**: 除外されたレイヤーは削除せず `report.json` の `excluded`(`reason: "unsupported_extension"`)に全件記録し、追跡可能にする。

## D4: `html` / `attribution` は原文のまま保持する

**Status**: Accepted

**Context**: GSI layers.txt の `html`/`attribution` にはタグ付きの説明文が入っている。

**Decision**: タグ除去やサニタイズを行わず、原文の HTML 文字列のまま TileJSON に保持する。

**Consequences**: 出力側(Cartographer 等)で表示する場合は利用側でサニタイズ責任を持つ必要がある。情報損失を避けることを優先した。

## D5: GSI layers.txt の語彙は接頭辞なしで透過する

**Status**: Accepted

**Context**: `maxNativeZoom` `legendUrl` `iconUrl` `styleurl` `cocotile` `area` `tileSize` `errorTileUrl` 等、TileJSON 標準にない GSI 固有キーがある。

**Decision**: `gsi:` のような接頭辞を付けず、そのまま TileJSON の拡張キーとして保持する。TileJSON 標準キーに対応するものは標準キーにも写像する(例: `Layer.title -> name`, `Layer.minZoom -> minzoom`)。ただし原キーも保持する。

**Consequences**: TileJSON としては非標準キーを含むことになるが、情報損失より相互運用性の高さを優先した。

## D6: subdomains は展開しない

**Status**: Accepted

**Context**: 旧来の `cyberjapandata-t{s}` のようなドメインシャーディング(`subdomains` フィールド、URL中の `{s}`)が一部レイヤーに存在し得る。

**Decision**: 展開処理は実装しない。`subdomains` や `{s}` が存在する場合はそのまま透過し、`report.json` に warning として記録する。

**Consequences**: 2026-07-02 時点の実データではこのパターンは 0 件だった(warning 発生なし)。将来 GSI 側でこの形式が使われた場合は、warning を確認してから展開実装を検討する。

## D7: MVT は含めるが `vector_layers` は省略する

**Status**: Accepted

**Context**: `.pbf`/`.mvt` はベクトルタイルだが、`layers.txt` だけからは MVT 内の `vector_layers`(レイヤー名・フィールド定義)を復元できない。

**Decision**: MVT/PBF は catalog に含めるが、TileJSON の `vector_layers` は省略する。省略した旨を `report.json` に `vector_layers_omitted` warning として記録する。content type は `application/x-protobuf` とする。

**Consequences**: 2026-07-02 時点の実データには MVT/PBF レイヤーが存在しなかったため、この分岐は未検証(コードパスとしては用意済み)。

## D8: source_id の決定順位と Martin 予約語の回避

**Status**: Accepted

**Context**: source_id は URL パスやカタログ内で衝突してはならず、Martin の予約語(`catalog` `config` `index` 等)とも衝突してはならない。

**Decision**: 次の優先順位で決定する。

```text
1. Layer.id があれば使う
2. URL の /xyz/{id}/ から抽出できれば使う
3. path + title から slug を生成する
4. 重複時は短い安定 hash suffix を付ける
```

予約語と衝突した場合は `gsi_{id}` のように安全な ID に変換する。

**Consequences**: `report.json` の `id_changes` に変換理由(`martin_reserved_id` / `duplicate_id`)を記録する。D10(重複URL抑制)の導入後、`duplicate_id` の発生件数は大幅に減った(165件→0件、2026-07-02)。

## D9: 干渉SARスナップショットレイヤーを主カタログから抑制する

**Status**: Accepted

**Context**: 実データで実行したところ、拡張子・URLフィルタを通過するレイヤーが 12,603 件あり、うち 10,538 件(8割超)が `https://maps.gsi.go.jp/sar/` 配下の干渉SAR(ALOS/ALOS-2/ALOS-4)画像だった。これは特定の地震・火山イベント × 特定の観測日ペアごとに1レイヤーが生成される過去の個別観測結果のスナップショットであり、std や seamlessphoto のような安定した基本図とは性質が異なる。この分量は Staff がカタログから意味のあるレイヤーを解決する際のノイズになると判断した。

**Decision**: `source_url` が `https://maps.gsi.go.jp/sar/` で始まるレイヤーは主カタログ(`docs/catalog`)から除外する。除外したレイヤーは削除せず、`report.json` の `excluded`(`reason: "sar_observation_snapshot"`)に全件記録する。地質図・土地分類などの系統的主題図、および災害イベント速報・重ねるハザードマップは、日付スナップショットではなく系統的な主題図としての性質を持つため、今回の抑制対象には含めず主カタログに残す。

**Consequences**: カタログは 12,603 件 → 2,065 件に縮小した(この時点。D10適用後は 1,874 件)。将来的な見直し観点:

- 完全に切り捨てるのではなく `docs/catalog-observations` のような別カタログに分離し、staccato-spec の `catalog-integration.md` が定義する複数カタログ・`resolution_policy.precedence` モデルに沿って Staff が明示的に参照できるようにする案がある。
- 災害イベント速報・重ねるハザードマップも、件数の推移によっては同様の抑制を検討する。
- 抑制基準を URL プレフィックスではなく、より意味的な基準(例: レイヤーIDに観測日ペアが含まれるか)に変更する案がある。

いずれも `build_catalog.rb` の `SAR_SOURCE_PREFIX` 判定を直すだけで変更できる。

## D10: 同一タイルURLの重複参照を抑制する

**Status**: Accepted

**Context**: `layers.txt` は同一のタイルURL(同一のtiles実体)を複数の `LayerGroup` から重複して参照することがある。例:

- `seamlessphoto`(全国最新写真)が「年代別の写真」「災害伝承・避難場所等」「近年の災害」など複数箇所から参照される。
- `relief`(色別標高図)が、通常カテゴリと、特定の災害イベント配下の先頭アンダースコア付きエイリアスid(`_relief_20160830`)の両方から参照される。
- タイルURLは同じだが UI 上の見せ方が異なるための別id(例: `gsi-compare-photo` は `seamlessphoto` と同じタイルを時系列比較スライダーとして表示するUI変種)が存在する。

**Decision**:

- 重複判定は tiles URL の完全一致で行う(id/title ではない。id/title は参照文脈で変わるが、実際に配信されるタイルは URL で決まるため)。
- 重複は抑制する。1 URL につき 1 エントリのみを主カタログに残し、残りは `report.json` の `excluded`(`reason: "duplicate_url_reference"`)に全件記録する。
- 複数エントリを1つに統合し、代替id/文脈をメタデータとして残す案は見送り、バックログとする(統合には文脈依存の `html` をどう扱うか判断が要り、LLM による要約・統合も将来検討し得るが、GitHub Actions 上で使うには複雑さとコストが見合わない)。
- canonical(代表として残す1件)の選定ルールは次の優先順で決定する:
  1. id が災害文脈エイリアス(先頭が `_`)でないものを優先する。
  2. id がタイルURL自身の `/xyz/{id}/` セグメントと一致するものを優先する(そのタイルソース自身が名乗っている名前を、参照元のメニュー文脈より優先する)。
  3. 上記で決まらない場合は、木構造を辿った際の最初の出現を採用する。

**Consequences**: カタログは 2,065 件 → 1,874 件に縮小した。ルール2は実装時に必要になった。単純な「先着順」だけだと、`seamlessphoto` グループで `gsi-compare-photo`(時系列比較スライダー用のUI変種)が本体より先に出現するため誤って代表に選ばれてしまうケースがあり、URL自身が declare する id を優先することで解決した。この教訓(「メニュー上の出現順は信頼できるcanonical選定基準にならない」)は、今後同種の判断をする際にも当てはまる。

## D11: Actions の成功判定を出力内容の検証に基づかせる

**Status**: Accepted

**Context**: D9 着手前の調査で判明した通り、`build_catalog.rb` は個々のレイヤーの取得・処理失敗を例外で止めず `report.json` に記録して処理を続ける設計になっている(意図的な挙動。1レイヤーの失敗で全体を止めないため)。ところが GitHub Actions 側は `test -f docs/catalog`(ファイルの存在確認のみ)と `git commit ... || exit 0`(コミット失敗を無条件に握りつぶす)しかチェックしておらず、レイヤーがほぼ0件しか取得できていない壊れた状態でも workflow は success 表示になっていた。実際、エンコーディングバグにより 10/11 の `layers*.txt` 取得が失敗し続けていた期間も、cron は毎日 "success" のまま空カタログをコミットし続けていた(2026-06-26〜2026-07-01)。

**Decision**: `validate_outputs.rb` を新設し、`build_catalog.rb` の後に実行する。ファイル存在確認だけでなく、次の内容を検証する。

- `docs/catalog` と `docs/catalog.json` の内容一致
- `report.json` の `summary.tiles_included` が閾値(デフォルト1000件)を下回っていないか
- `report.json` の `failures` が0件か
- catalog の tiles 件数と `summary.tiles_included` の一致
- catalog キーに Martin 予約語が含まれていないか
- 各 `docs/{id}` と `docs/{id}.json` の内容一致
- 各 TileJSON が `tilejson: "3.0.0"`、絶対URL、`{z}/{x}/{y}` を持つか
- 同一 tiles URL を持つ catalog エントリが複数存在しないか(D10 の抑制が機能しているかの回帰チェック)

いずれか1つでも失敗すれば non-zero で終了し、workflow を失敗させる。あわせて、コミット手順の `git commit ... || exit 0` は `git diff --cached --quiet` によるチェックに置き換え、「変更なし」(正常系)と「commit自体の失敗」(異常系)を区別できるようにした。

**Consequences**: `min-tiles` の閾値(デフォルト1000)は 2026-07-02 時点の実件数(1,874)に対する安全マージンであり、意図的な抑制強化(D9/D10 のようなもの)で件数が大きく減る場合は、この閾値もあわせて見直す必要がある。`failures` を1件でも許容しない設定は厳しすぎる可能性があり、実運用で頻発するようなら閾値化を検討する。

## D12: TileJSON の `name` はプレーンテキスト化する

**Status**: Accepted

**Context**: Staff/Cartographer ロールプレイでの実用性評価(2026-07-02)で、`05_dosekiryukeikaikuiki` 等11件(1,874件中)の `name` に GSI 側の `title` 由来の生HTML(`土石流<br>(黄は警戒区域、赤は特別警戒区域)` のような `<br>`)がそのまま漏れていることが判明した。`name` は TileJSON 標準キーとして「表示ラベル」の意図で `Layer.title -> name` に写像している(D5)。D4 が原文HTML保持を認めているのは `html`/`description`/`attribution` であり、`name` はその対象ではない。

**Decision**: `name` を組み立てる際にタグ除去・基本的なHTMLエンティティのデコード・空白正規化を行う(`plain_text_name`)。元の `title`(GSI由来の生キー、D5 により保持)や `html`/`description`(D4 により保持)には手を加えない。`name` が空になった場合は `source_id` にフォールバックする。

**Consequences**: 影響していたのは1,874件中11件。`docs/catalog` の `tiles[id].name` と各 `docs/{id}` の `name` は、以後どちらも `build_tilejson` が計算した同じプレーンテキスト値を参照する(以前は catalog 側で `layer['title']` を独立に再計算しており、理論上ズレ得た)。

## D13: `layers0.txt` を明示的に読み込む

**Status**: Accepted

**Context**: Staff/Cartographer ロールプレイでの実用性評価(2026-07-02)で、`std`(標準地図)がカタログに存在しないことが判明し、一旦バックログとした。その後、原因は `https://maps.gsi.go.jp/layers_txt/layers0.txt` という別ファイルに `std`/`pale`/`blank`/`english`/`ort` が定義されているが、ルートの `layers.txt` ツリーからは一切参照されていない(`url` 配列にも `layers`/`entries` にも現れない)ことだと分かった。GSI の Web アプリ側では、これらの背景地図はレイヤーツリーとは別の固定選択肢として扱われているらしく、`layers.txt` の再帰探索だけでは原理的に到達できない。

**Decision**: `run` の冒頭で、ルート `layers.txt` の探索に加えて `layers0.txt` を明示的に(ルートURLからの相対パスとして)読み込む。取得した各 Layer には `path: ['背景地図']` を付与し、他のレイヤーと同じ拡張子フィルタ・重複URL抑制(D10)を通す。

**Consequences**: `std`/`pale`/`blank`/`english` の4件が新たにカタログに加わった(1,874件 → 1,878件)。`layers0.txt` の `ort`(id: `ort`, タイルURL: `.../xyz/seamlessphoto/{z}/{x}/{y}.jpg`)は、既存の `seamlessphoto` と完全に同一のタイルURLを持つため、D10 の重複抑制がそのまま機能し `report.json` に `duplicate_url_reference` として記録される(手を加えずに正しく動作した)。`layers0.txt` が将来 URL 自体を変更(パスは変えず中身だけ差し替え)した場合、`read_document` の `@visited_urls` によるループ防止には影響しないが、内容の再検証は次回 cron 実行時まで行われない。

## D14: Staff プロンプトの置き場所と map-intent-vnext への準拠

**Status**: Accepted

**Context**: `STAFF_PROMPT.md` を使ってエンタープライズ側の生成AIに実際にクエリ(「札幌市清田区の地形分類を見たい」)を処理させたところ、次の2つの問題が観測された。

1. 存在しない source_id(`lcmfc2_1`)を捏造していた。実在するのは `lcmfc2`(治水地形分類図)、`lcm25k_2012`(数値地図25000土地条件)、`terrainclassification1`(地形分類図)。
2. `STAFF_PROMPT.md` の Map Intent 例が `UNopenGIS/staccato-spec` の `spec/map-intent-vnext.md` と食い違っていた(`catalog_type` vs 正しい `type`、`purpose` vs 正しい `label`、`spec_version`/`provenance` の欠落、独自の `required_area`/`base` フィールド)。AIの出力はこの食い違った例をなぞっていたと考えられる。

あわせて、Staff プロンプトの実装をどのリポジトリの責務にするかの整理が必要になった。`UNopenGIS/staccato-spec` は規範仕様の記述に専念させたい一方、`layers-martin` は Library の第一実装に過ぎずプロンプトの本来の置き場所ではない。しかし分離を急ぎすぎると、`layers-martin` 自体が固まる前にリポジトリ切り替えコストが発生する。

**Decision**:

- Staff プロンプトの試行錯誤は、当面 `layers-martin` の `STAFF_PROMPT.md` を置き場所とする。プロンプトが十分に熟したら、その時点で別リポジトリへの分離を検討する。
- `STAFF_PROMPT.md` の Map Intent 例は `map-intent-vnext.md` の Schema (Draft) に文字通り従う(フィールド名を含む)。spec にないキー(`base` 等)で重要情報を運ばない。Cartographer は未知キーを無視してよいことになっているため、spec 外のキーに乗せた情報は実際に無視されて描画されないリスクがある。
- `STAFF_PROMPT.md` に「source_id を捏造しない」ことを明示的なルールとして追加する。確信が持てない candidate は catalog を再検索してから確定し、それでも見つからない場合は捏造せず「見つからない」と申告する。
- 地域名(市区町村名等)から `area.bbox` への解決は Staff の責務とする。Cartographer や独自フィールドに丸投げしない。

**Consequences**: `STAFF_PROMPT.md` の例を spec 準拠に書き直した。次に別の生成AIで同様のテストを行う場合、(a) 捏造IDが出ないか、(b) 出力が `spec_version`/`provenance`/`area.bbox` を含む正しいスキーマになっているかを確認するとよい。

## D15: 航空機SAR画像スナップショットも同じ原則で抑制する

**Status**: Accepted

**Context**: User/Staff ロールプレイの反復検証(2026-07-02)で「浅間山」を検索したところ、`20180622_asama_c1`〜`c8`・`20190808_asama_c1`〜`c8`・`20180127kusatsushirane_apsar180127*` など17件の**航空機SAR画像**(観測日 × 撮影方向ごとの個別スナップショット、`path` に `航空機SAR画像`/`航空機SAR画像（速報）` を含む)が見つかった。これは D9 が対象とした干渉SAR(`だいち`/ALOS衛星SAR、`source_url` が `https://maps.gsi.go.jp/sar/` 配下)と全く同じ性質(特定イベント × 特定観測回ごとの過去観測スナップショット)だが、`maps.gsi.go.jp/xyz/...`(`layers6.txt` 等)でホストされているため D9 の URL prefix 判定には掛からない。件数は17件(全体の0.9%)で D9 の10,538件(8割超)とは規模が大きく異なる。

**Decision**: 規模によらず同じ原則(単発の観測スナップショットはノイズになりやすい)を適用し、`path` にセグメント `航空機SAR画像`(または `航空機SAR画像（速報）`)を含むレイヤーも主カタログから除外する。除外したレイヤーは削除せず `report.json` の `excluded`(`reason: "aircraft_sar_observation_snapshot"`)に全件記録する。判定は URL ではなく `path` で行う(この種のレイヤーは URL プレフィックスに一貫した規則が無いため)。

**Consequences**: カタログは 1,878 件 → 1,861 件に縮小した。件数としては小さいが、「規模の大小にかかわらず、単発観測スナップショットは同じ扱いにする」という一貫性を優先した(ユーザーの言葉で「平等に抑制」)。将来また別のホスト・別の `path` 表記で同種の単発観測データが見つかった場合、同じ原則(URL プレフィックスまたは `path` プレフィックスによる判定)を適用して都度追加していく想定。

## D16: ホスト名の完全一致テーブルで `attribution` を補う

**Status**: Accepted

**Context**: `attribution` バックログ項目を調べ直したところ、実態はより深刻だった。`layer['attribution']` は1,861件中193件で**キー自体は存在する**が、**非空の値を持つものは0件**(すべて空文字列)。つまり `layers.txt` 由来の `attribution` は実質使い物にならない。

以前提案された「tiles URL のホストが `gsi.go.jp` ならGSIを既定値にする」案には、`disaportaldata.gsi.go.jp`(国土交通省の砂防・国土数値情報データ)という反例があった。調べ直すと、カタログ全体で実際に使われているタイルのホストはわずか7種類しかなく(`tiles.gsj.jp` 865, `maps.gsi.go.jp` 804, `nlftp.mlit.go.jp` 183, `disaportaldata.gsi.go.jp` 6, `cyberjapandata.gsi.go.jp` 1, `gbank.gsj.jp` 1, `www.j-shis.bosai.go.jp` 1)、各ホストの `html` 本文を読むと出典組織をほぼ確認できた。ただし `maps.gsi.go.jp` 自体にも罠があり、`rinya`(森林（国有林）の空中写真、出典は林野庁)のように**GSIの主ホスト上で他省庁のデータが1.9%程度混在**していることが分かった。

**Decision**: ホスト名の部分一致(`*.gsi.go.jp` など)ではなく、**個別に確認した完全一致のみ**をテーブル化して既定値を補う。

```text
tiles.gsj.jp              -> 産業技術総合研究所地質調査総合センター
gbank.gsj.jp               -> 産業技術総合研究所地質調査総合センター
nlftp.mlit.go.jp           -> 国土交通省
www.j-shis.bosai.go.jp     -> 防災科学技術研究所
```

`maps.gsi.go.jp`・`cyberjapandata.gsi.go.jp`・`disaportaldata.gsi.go.jp` は、他機関のデータが混在することが確認されているため、テーブルに**含めない**(既定値を付けない)。`layer['attribution']` が空でない場合は既定値で上書きしない。付与した件数・対象idは `report.json` の `attribution_defaults`(および `summary.attribution_defaults`)に記録する。

**Consequences**: 1,861件中 **1,050件(56.4%)** に確度の高い `attribution` が付与された。残り811件(`maps.gsi.go.jp` 系804件・`cyberjapandata.gsi.go.jp` 1件・`disaportaldata.gsi.go.jp` 6件)は既定値なしのままで、これは意図的な保留である(誤帰属より無帰属の方が安全という判断)。`maps.gsi.go.jp` 配下だけでも大半(804件中789件、約98%)はGSI自身のデータだが、`html` 本文の文字列解析で他機関を判定するような追加のヒューリスティックは、今回は実装しない(検出漏れ・誤判定のリスクと実装複雑性が見合わないと判断)。将来 `maps.gsi.go.jp` 配下の対応を進めるなら、ホスト単位ではなく `path`/`html` の内容ベースでの判定(D15 で `path` ベースの判定を既に導入した前例あり)を検討する。

## D17: `faceless-cartographer` との整合性確認: `catalog_context.version` と attribution可視性の文書化

**Status**: Accepted

**Context**: Cartographer の初期実装(`hfu/faceless-cartographer`)を進める過程で、`layers-martin`/`faceless-cartographer`/`UNopenGIS/staccato-spec` の3リポジトリ間の整合性を確認した。2点、ドキュメントで埋めるべきギャップが見つかった。

1. `map-intent-vnext.md` の `catalog_context.active_catalogs[*].version` は任意フィールドだが、`docs/catalog`/`docs/catalog.json` 自体にはバージョン情報が無く、`docs/manifest.json` の `generated_at` を別途取得しないと埋められない。`STAFF_PROMPT.md` の実例もこれまで `version` を設定していなかった。
2. `faceless-cartographer` を実際にブラウザで動かして検証したところ、MapLibre GL JS の attribution 表示は「現在表示中のレイヤー」の分しか合成しない仕様だと分かった。D16 で `attribution` を56%のレイヤーに付与したが、典型的な Map Intent の構成(`maps.gsi.go.jp` 系の std やハザードマップが `required_layers` に、D16 で確実に attribution が付く4ホスト系が `optional_layers` になりやすい)では、既定表示の状態で画面に出典が一切表示されない組み合わせになりがちであることが実地で確認された。

**Decision**: `STAFF_PROMPT.md` に、(1) `version` は `manifest.json` の `generated_at` を使う旨、(2) `attribution` の有無だけでなく、そのレイヤーが実際に既定表示されるかどうかもStaffが考慮すべきことを追記した。`docs/catalog` 自体に `generated_at` を埋め込む案(カタログrootを汚さずに済ませられるかの検討)は見送り、`manifest.json` 参照という現行の分割構造を維持する(D2「catalogは最小構造」の方針を優先)。

**Consequences**: `layers-martin` 側のコード変更は無し(ドキュメントのみ)。将来的に `attribution` の画面表示を確実にしたい場合、レイヤー選定側(Staff)の配慮だけでは限界があり、Cartographer側の実装(例えば非表示レイヤーの attribution も一覧表示する等)を変える方が本質的な解決になる可能性がある。

## D18: TileJSONを拡張し `legend_image_url` を新設する

**Status**: Accepted

**Context**: `faceless-cartographer` 側で「凡例(legend)が画面に出ない」というバックログ課題を検討した際、根本対応として `layers-martin` 側で凡例画像URLを構造化して持たせる案が挙がった。実データを調べると、`legendUrl` と `html` の間で凡例情報の持ち方が一貫していない。

- `legendUrl` が凡例画像そのものを指す場合(例: `relief`)
- `legendUrl` が凡例画像ではなくHTMLページを指す場合(例: `std`)
- `legendUrl` が無く、`html`(`description`)内に `<img>` タグとして凡例画像が埋め込まれている場合(例: `05_dosekiryukeikaikuiki` 等、今回のworked exampleの主要3レイヤーがこれに該当)
- どちらにも凡例情報が無い場合(例: `landslide`)

これを Cartographer 側で毎回 `html` をスニッフィングして判定するのは、複数の Cartographer 実装が今後現れることを考えると非効率かつ実装の重複を招く。Library(`layers-martin`)側で一度だけ解決しておくのが筋が良い。

TileJSON 3.0 自体は JSON Schema 上 `additionalProperties` を禁止しておらず、本プロジェクトは既に `legendUrl`/`iconUrl`/`path`/`cocotile` 等、GSI由来の非標準キーを何のためらいもなく TileJSON に追加してきた(D5)。Martin互換の catalog root(`docs/catalog`)自体は最小構造を保つ方針(D2)だが、個々の TileJSON(`docs/{id}`)は元々「情報損失を避けることを優先する」設計であり、拡張のハードルは低いと判断した。

**Decision**: TileJSON に新しい拡張キー `legend_image_url` を追加する。決定順位は次の通り。

1. `legendUrl` が存在し、絶対URLで、拡張子が画像(`.png`/`.jpg`/`.jpeg`/`.gif`/`.svg`/`.webp`)であれば、それをそのまま使う。
2. 上記が使えない場合、`html` から最初の `<img src="...">` を正規表現で抽出し、絶対URLであればそれを使う。この場合、`report.json` に `legend_image_extracted_from_html` warning を記録する(html本文からの抽出は正規表現によるヒューリスティックであり、100%の再現性は保証されないため、どのレイヤーがこの経路を通ったか追跡可能にしておく)。
3. どちらも無ければ `legend_image_url` キー自体を出力しない(無いことを明示するために `null` にはしない。既存の `attribution`/`bounds` 等と同じ扱い)。

`validate_outputs.rb` に、`legend_image_url` が存在する場合は絶対URLであることを検証するチェックを追加した。

**Consequences**: 1,861件中 **964件(51.8%)** に `legend_image_url` が付与された。今回のworked example(`05_dosekiryukeikaikuiki`/`05_jisuberikeikaikuiki`/`05_kyukeishakeikaikuiki`)はすべて `html` からの抽出経路で取得できている。`html` の構造が将来変わった場合、正規表現による抽出が効かなくなる可能性があるが、その場合も `legend_image_url` が単に付与されなくなるだけで、既存の動作(`html`/`description` フィールド自体の保持)には影響しない。

## D19: `STAFF_PROMPT.md` に「あなたは Staff である」導入節を追加する

**Status**: Accepted

**Context**: `STAFF_PROMPT.md` の実体である `````text````` フェンス内(`hfu/faceless-cartographer` の `GET /` にもそのまま表示される、[D13](../faceless-cartographer 参照)部分)を見直したところ、layers-martin固有の「カタログの引き方」からいきなり始まっており、「そもそもStaffとは何か・何をしてよく何をしてはいけないか・利用者やCartographerとの正しいやりとりの形」という、staccato-spec準拠の最低限の導入を欠いていることが指摘された。これまでの反復検証(source_id捏造、スキーマ不準拠等)はすべてカタログ固有の失敗モードに対する後付けの補足であり、そもそもの土台が無いまま補足だけを積み重ねていた。

**Decision**: フェンス内の冒頭に「## あなたは Staff である」節を追加した。内容は `UNopenGIS/staccato-spec` の `architecture-principles.md`(責務分離・least disclosure等の核心原則、§5.2のStaff characterization)と `ADR 0002`(起動時カタログ契約・隠れたフォールバック禁止)を出典として要約したもの: (1) 責務(Map Intentの生成、機微な文脈を含めない、設定済みカタログのみ使用、source_id捏造禁止)、(2) 正しいやりとりの形(User→Staff→人間によるコピー&ペースト→Cartographer、URLではなくMap Intentが共有の一次artifact)、(3) Map Intentの必須フィールド。この節の後に、既存のlayers-martin固有の内容(カタログの引き方、source_id捏造禁止の詳細、意味解決の指針等)を「以上がStaccatoの一般的な規定である。以下はLibraryとしてlayers-martinを使う際に固有の補足である」という接続で続ける構成にした。

**Consequences**: `STAFF_PROMPT.md` は単体である程度自己完結したStaffプロンプトとして機能するようになった(既存のより詳細なStaffシステムプロンプトへの追加としても、単体としても使える)。`hfu/faceless-cartographer` はこのファイルを取得して表示している([D13](https://github.com/hfu/faceless-cartographer/blob/main/DECISIONS.md#d13-gettopページに現在のstaffプロンプトを表示する))ため、コード変更なしに反映される。

**2026-07-04 追記**: `hfu/faceless-cartographer` はその後アーキテクチャを変更し(D18)、`GET /` によるサーバー取得ではなくビルド時fetch(D19、faceless-cartographer側の同名の別決定)に変わった。取得元がこのファイルであることは変わらない。詳細は [D20](#d20-staff_promptmdをfaceless-cartographerの新アーキテクチャに追随させる) を参照。

## D20: `STAFF_PROMPT.md` を `faceless-cartographer` の新アーキテクチャに追随させる

**Status**: Accepted

**Context**: `hfu/faceless-cartographer` が大きくアーキテクチャを変更した(単一ページのSPA化、この世代ではLLMを使わない、静的サイト化。詳細は同リポジトリの DECISIONS.md D18・D20・D21)。`STAFF_PROMPT.md` の「正しいやりとりの形」節が「Cartographer の `POST /` に貼り付ける」という、もはや実態と異なる表現を含んでいた(実装はサーバーレスの単一ページで、文字通りのHTTP POSTは発生しない)。

**Decision**: 「Cartographer の `POST /` に貼り付ける」を「Cartographer の画面に貼り付ける」という実装非依存の表現に変更した。Staff はCartographerの実装形態(サーバーか静的サイトか)を関知しない、という原則を明記した。あわせて、次の2点を追加した。

- 参照実装 `hfu/faceless-cartographer`(https://hfu.github.io/faceless-cartographer/)が実在し、実際にMap Intentを貼り付けて動作確認できることを明記した。以前は「Cartographerはこう動くはず」という仕様上の想定にとどまっていた。
- 参照実装がこの世代ではLLMを使わないため、地図に添える自然文の説明が返ってくることを期待しないよう明記した。
- 参照実装の「Copy Map Intent」が `cartographer_feedback`(`missing_layers`/`unrenderable_layers`)を埋め込む場合があることと、それを受け取った場合にStaffが次の応答へ反映すべきことを、「正しいやりとりの形」に6番目の項目として追加した(faceless-cartographer D15)。

**Consequences**: `STAFF_PROMPT.md` が特定のCartographer実装の内部実装(サーバーかどうか等)に依存しない書き方になった。将来Cartographer側がまた実装を変えても(例えばLLMを追加する等)、この文書側の変更は今回のように必要に応じて追随させる運用を続ける。

## D21: `STAFF_PROMPT.md` に `stars.optgeo.org` を別カタログとして追記する。aggregatorは作らない

**Status**: Accepted

**Context**: `layers-martin` の責務を拡張し、`https://stars.optgeo.org/catalog`(実際に稼働している、`layers-martin` とは無関係の Martin サーバー)を取り込めないか検討する依頼があった。目玉は国土地理院最適化ベクトルタイル(`bvmap`)で、これにより Staff がベースマップをベクトルタイルとして扱う選択肢を得る。検討した設計候補は主に3つ: (A) `layers-martin` 内部で `stars.optgeo.org` のカタログを取り込み、自前のカタログとマージして1つの静的カタログとして出す、(B) 別リポジトリに「Martin catalog アグリゲーター」を新設し、そこで複数カタログの統合を行う、(C) 統合そのものをしない。`layers-martin` は自分自身のカタログを出し続け、`stars.optgeo.org` はそのまま Staff に案内し、Map Intent の `catalog_context.active_catalogs` に2つのカタログを並べて持たせる。(A)は `layers-martin` が他者の運用するサーバーの可用性・データ形状変更に直接依存することになり、日次バッチ生成という `layers-martin` 自身のライフサイクル(D_多数、生成物はGitHub Pagesの静的ファイル)と、実サーバーである `stars.optgeo.org` のライフサイクル(常時稼働、いつでも形が変わりうる)が混ざってしまう。(B)は正しく動くはずだが、Map Intent の spec が最初から複数 `active_catalogs` の併記を許容しているため、統合のための専用コードを別リポジトリに書く前に、まずその素の機能で足りるか確かめるべきだと判断した。

**Decision**: (C) を採用した。`layers-martin` のコード・カタログ生成物には一切手を入れない。代わりに `STAFF_PROMPT.md` に新しい節「別カタログ: stars.optgeo.org(国土地理院最適化ベクトルタイル)」を追加し、Staff が `catalog_context.active_catalogs` に `layers-martin` と `stars.optgeo.org` の2件を並べて使えること、使い分けの目安(ラスタ背景地図で足りるなら不要、ベクトルタイルとしてベースマップを扱いたいなら `bvmap`)、`bvmap` の `source_id` もカタログを実際に取得してから使うこと(捏造禁止の原則がこちらにも及ぶ)を明記した。実際にこの2カタログを1つの Map Intent で解決できることは `hfu/faceless-cartographer` 側で実データに対する統合テストとして確認済み(同リポジトリ [DECISIONS.md](https://github.com/hfu/faceless-cartographer/blob/main/DECISIONS.md) D23)。`bvmap` の実際の描画(ジオメトリタイプ別の汎用スタイリング)も同じくCartographer側の責務として実装済み。

**Consequences**: `layers-martin` はカタログのマージや外部サーバーへの依存を一切持たないまま、Staff がベクトルベースマップという選択肢を得られるようになった。将来、統合したいカタログが増えて「毎回 `active_catalogs` に手で列挙する」運用が煩雑になった場合は、その時点で改めて(B)のアグリゲーターを検討する余地を残す(このADRはその判断を妨げない、可逆的な決定)。

## D22: `STAFF_PROMPT.md` を `faceless-cartographer` D24 に追随させ、Staff の振る舞いを主眼に再構成する

**Status**: Accepted

**Context**: `hfu/faceless-cartographer` が背景地図を常時自動描画するように変更された(D24: `bvmap` グレースケール + Mapterhorn hillshade/terrain に固定)。これに伴い、`layers-martin` の `STAFF_PROMPT.md` の現行の記述(「背景地図が必要な場合は `std`/`pale`/`blank`/`english` の4件から選べ」)は単に古いだけでなく、実害をもたらす。

`faceless-cartographer` の `style.ts`(`buildStyle()`)では、レイヤースタックが `[...baseStyle.before(背景/水系/hillshade), ...主題レイヤー, ...contours(等高線), ...baseStyle.after(道路・建物・注記)]` という順序で合成される。Staff が背景地図(例: `"std"`)を `required_layers` に含めると、不透明なラスタタイルとして bvmap 背景の**上**・等高線や道路ラベルの**下**に挿入され、bvmap 由来の背景・hillshade・水系を覆い隠しつつ、bvmap 由来の道路・建物・注記だけが上に残るという崩れた見た目になる。`faceless-cartographer` 自身の `EXAMPLE_MAP_INTENT` は D24 で `std` を削除しており、この認識と整合している。

加えて、現在の `STAFF_PROMPT.md` の構造に対する根本的な指摘があった: 本文(フェンス内の約210行)のうち、Staff の識別・責務・やりとりの形は冒頭40行で、残りは layers-martin カタログ固有の癖(attribution欠落、bounds欠落、同名紛らわしいレイヤーの見分け方等)に費やされている。Cartographer が実際に何をしてくれるか(背景・等高線・凡例・任意レイヤー切替・地形3D等)を踏まえて、Staff として Map Intent をどう書くべきかという「能力を踏まえた振る舞い」の節が丸ごと欠けている。ポイントがずれている。

**Decision**: `STAFF_PROMPT.md` を以下の方針で全面的に再構成した。

1. フェンス内の構成を再編成: 「Staccato の一般的な規定」(「あなたは Staff である」/「正しいやりとりの形」/「必須フィールド」)と、その直後に新しく「Cartographer(参照実装)の現在の能力を踏まえること」節を追加。この節で、背景地図・等高線・地形3D・任意レイヤー・凡例・cartographer_feedback など、Cartographer が「勝手にやってくれること」を明示的に列挙した。その上で、Staff としての正しい振る舞いが自動的に導き出される構成にした。

2. 「背景地図(base map)について」節を全面差し替え: 「`std`/`pale`/`blank`/`english` から選ぶ」という現行の案内を撤回し、「背景は自動描画されるため source_id を指定する必要は無い。あえて指定すると、bvmap 背景の上に不透明なラスタとして重なり、道路・注記だけがその上にさらに乗る崩れた見た目になるため、指定しないこと」と明記した。

3. 「別カタログ: stars.optgeo.org」節の理由付けを書き換え: D21 では「背景をベクトルタイル化したい場合に bvmap」という理由付けだったが、D24 により Cartographer が `bvmap` と同等以上のものを自動描画するため、この理由は弱くなった。代わりに、「Cartographer の既定背景には無い、本当に新しいコンテンツ」を案内する主目的へシフトした。具体的には `japan-seamless-aerial-z18`/`seamlessphoto512`(全国空中写真、ラスタ)と `vlcm`/`vbm`(北海道火山地質図・変動地形図、ベクトルタイル、道南〜道央限定)を主役に、使い分けの目安を更新した。

4. 「動作確認済みの例」の YAML から `source_id: "std"` を削除し、削除理由(背景は自動描画されるため不要)を一言添えた。`faceless-cartographer` 自身の `EXAMPLE_MAP_INTENT` と整合。

5. フェンス外側(GitHub で読む人間向け)の前置きテキストに、今回の書き換えの背景(D24 による背景地図の扱い変更、実害の分析、能力ベース節の欠如という指摘)を追記し、文脈を明確にした。

**Consequences**: `STAFF_PROMPT.md` が「何をしてはいけないか」という禁止ベースの記述(D14「source_id を捏造しないこと」等)から、「Cartographer が何をしてくれるか」という能力ベースの記述へ、主眼がシフトした。この変更により、Staff が能力に見合った正しい Map Intent を書きやすくなる。背景地図指定による見た目崩れという実害も解消される。

`hfu/faceless-cartographer` はこのファイルをビルド時に取得して `src/staff-prompt.txt` に組み込み、UI上で表示する(`scripts/fetch-staff-prompt.mjs` 実行時)。新しい `STAFF_PROMPT.md` の内容は自動的に反映される。

## D23: STAFF_PROMPT.md をハイブリッド対応（オンライン/オフライン両立）に設計する

**Status**: Accepted

**Context**: エンタープライズAI環境がインターネット接続できない場合、Staff は `catalog` を都度 fetch して source_id を確認することができない。これまで「別ファイル STANDALONE_PROMPT.md を作ってカタログ全 1,861 件を埋め込む」という計画があったが、そうすると：
- 保守負荷が増える(生成スクリプト必要、二重管理)
- ファイル容量が増加(150-220 KB)
- source_id 完全性と実用性のバランスが悪い

別案として「単一 STAFF_PROMPT.md で両方対応」を検討: インターネット接続有りの場合は「カタログの引き方」に従う(現行)、接続なしの場合は「オフラインフォールバック」セクションの既知 source_id 参考リストから選択。

**Decision**: 単一ファイル STAFF_PROMPT.md でハイブリッド対応を採用した。

- 「カタログの引き方」セクション: インターネット接続有りの手順(動的 catalog fetch)
- 「オフラインフォールバック」セクション(新規): インターネット接続無しでの参考リスト
  - カテゴリ別(災害リスク、地形・地質、土地利用)に厳選した代表例 ~15 件
  - 「見つからない場合は捏造するな」原則は変わらず
  - 実装判定: 「札幌の地形分類を見たい」という自然言語入力に対して生成した Map Intent が layers-martin カタログで完全に解決できることを確認(lcmfc2・relief・lcm25k_2012 全て存在、メタデータ適切)

**Consequences**: 
- 両環境対応: 接続有無を問わず使用可能
- 保守シンプル: 二重管理・生成スクリプト不要
- 実用性優先: 完全性より代表例で十分
- source_id 参考リストは「参考値」明記(完全ではない)

## D24: STAFF_PROMPT.md を「指標駆動の実証ループ」で改善する

**Status**: Accepted(2026-07-16)

**Context**: これまで STAFF_PROMPT.md の改善は、ロールプレイ評価(D9〜D13)や仕様追随で行ってきたが、「実際に Map Intent を生成し、Cartographer で描画してみて、客観指標で良し悪しを測る」という反復は行っていなかった。その結果、プロンプト自身のオフライン一覧(D23)に載っている source_id が陳腐化していても気づけなかった。

`hfu/faceless-cartographer` の UI 改善(同リポジトリ Issue #4)で、サンプル質問「石狩川の治水について考えたい」に対応する Map Intent を実データで組み立てた際、この一覧の洪水 id が実在しないことに気づいたのが契機。

**Decision**: STAFF_PROMPT.md の改善は、次の**指標駆動の実証ループ**で行う。

1. **評価ハーネス**: `hfu/faceless-cartographer` の `scripts/eval-intent.ts`(同リポジトリの解決パイプライン `parseMapIntent`/`resolveLayers` と `style.ts` と同一の描画可能性判定を再利用)で、Map Intent YAML 1件から客観指標を算出する。
2. **指標(指標)**: M1 スキーマ妥当性 / M2 解決率(resolved/(resolved+missing)) / M3 描画可能率(vector_layers 無しの vector は unrenderable) / M4 視野内データ(area.bbox 中心タイルが実データを返すか) / M5 フレーミング(bbox の有無) / M6 非 spec キー。
3. **テスト質問スイート**: カタログの強みと既知の罠を代表する 7 問(土砂災害・治水・洪水・土地条件・液状化〈負例〉・空中写真〈第2カタログ raster〉・火山地質〈第2カタログ vector〉)。
4. **ループ**: 現行プロンプトに忠実に Staff を演じて各問の Map Intent を生成 → ハーネスで採点 → 各 defect をプロンプトのどの記述が原因か根本原因分解 → 修正 → 再採点。閾値(M2=M3=1.0、負例正答)到達か改善頭打ちまで反復。

**この回の実測結果(before → after)**: スイート 4/6 → **6/6 合格**。

- **M2 defect(最重要)**: オフライン一覧の洪水 id `flood_l2`/`flood_l3` が 404(実在せず)。実在 id `01_flood_l2_shinsuishin_data`(想定最大規模)/`01_flood_l1_shinsuishin_newlegend_data`(計画規模)へ修正。「石狩川治水」で M2 0.50→1.00、「洪水浸水想定」で M2 0.00→1.00。
- **再発防止**: 「一覧の id 自体も改名で陳腐化しうる。接続時はカタログ実在確認をオフライン一覧に優先」を明記。
- **M4 finding**: `lcm25k`(土地条件図)は石狩平野を整備対象外で 404(解決するが空描画)。カバレッジ注意と、低地地形は `lcmfc2` で代替する指針を追加(M4 0/1→1/1)。
- **追加**: 「石狩川の治水」worked example(実 bbox・治水地形分類図×洪水浸水・`relationships_to_highlight`)を新設。

**Consequences**:
- プロンプトの陳腐化・カバレッジ欠落を、印象論ではなく再現可能な指標で検出・修正できるようになった。
- カタログ改訂で source_id が改名されると再びオフライン一覧が陳腐化するため、定期的に本ループを回して回帰確認する(将来: cron 化・フィクスチャ化を検討)。
- ハーネスとテスト intents は `hfu/faceless-cartographer` 側に置く(解決コードがそこにあるため)。STAFF_PROMPT.md 改善の一次リポジトリは引き続き `layers-martin`。

## D25: 凡例画像の抽出を `<a href>` リンク形式にも拡張する（D18 の拡張）

**Status**: Accepted（2026-07-17）

**Context**: [D18](#d18-tilejsonを拡張しlegend_image_urlを新設する) で `legend_image_url`（TileJSON 独自拡張）を新設し、`legendUrl`（直接画像）または `html` 内の `<img>` から凡例画像を抽出していた。しかし GSI の一部レイヤーは凡例を `<img>` ではなく `<a target="_blank" href="…/legend/xxx_legend.jpg">凡例を表示</a>` という**リンク形式**で持つ。代表例が治水地形分類図（`lcmfc2`）で、公式の全国共通凡例 `lcmfc2_legend.jpg` が存在するのに `legend_image_url` が付与されず、`hfu/faceless-cartographer` 側でも凡例が出なかった（同リポジトリ Issue #5）。

**Decision**: `build_catalog.rb` の `legend_image_source` に3段目の抽出を追加する。`html` 内の `<a href="…(画像拡張子)">` を凡例画像として採用するが、**誤検出を防ぐため、href が `/legend/` を含む、またはアンカーテキストに「凡例」を含むものに限定**する（写真リンクや「解説」ページを凡例と誤認しない）。優先順位は従来どおり 直接 `legendUrl` → `<img>` → 新規の `<a>` リンク。`:html_link` 由来は report の warning に記録し透明性を保つ。

**Consequences**:
- 再生成で凡例数 964 → 966（+2）。新規は `lcmfc2`（治水地形分類図）と `jinkodotai_jinko_sabun1995_2015`（人口動態）で、いずれも `/legend/` 配下の正当な凡例。誤検出なし。
- `hfu/faceless-cartographer` はカタログを実行時取得するため、コード変更なしで既存の凡例機構（faceless-cartographer D14）が治水地形分類図の凡例を表示するようになる。
- 治水地形分類図は全国単一タイルレイヤーで、この凡例が唯一の公式共通凡例。地域別の差異は無く「代表的な凡例のみ」といった但し書きは不要。

## D26: PDF のみで公開される凡例を `legend_pdf_url` として収録する（全レイヤー点検の結果）

**Status**: Accepted（2026-07-17）

**Context**: D25 の後、`hfu/faceless-cartographer` から「全レイヤーで凡例の取りこぼしが無いか点検してほしい」という依頼を受け、全 1863 レイヤーを監査した。結果:
- 画像凡例(`<img>`/直接画像/`<a>` 画像リンク)の抽出は**取りこぼしゼロ・バグゼロ**。ただし1件、`legendUrl` に末尾空白がある画像凡例(`2015_relief_sakurajima.jpg `)を空白除去で拾えるよう修正(966→967)。
- `iconUrl` は全て汎用マーカー記号(`symbols/670.png` 等)で凡例ではない。背景系ページ(`ichiran.html#std` 等)や注意ページ(`attension_relief.html`)も色凡例ではない。
- **実在するのに未収録なのは PDF 形式の凡例のみ**(114レイヤー、10種の PDF。例: NDVI・復旧計画基図・土地条件図 `lcm25k_2012` の `lc_legend.pdf`)。

**Decision**: PDF 凡例を新しい TileJSON 拡張キー `legend_pdf_url` として収録する。画像凡例と別キーにするのは、Cartographer がインライン `<img>` で描画できるのは画像だけで、PDF は「凡例 (PDF)」リンクとして扱う必要があるため。抽出は `legend_image_source` と同じ形/スコープ(`.pdf` の `legendUrl`、または `/legend/`・「凡例」に限定した `<a href="….pdf">`)。**画像凡例が見つかった場合は PDF を付与しない**(画像優先)。`report.summary.legend_pdf_urls_found` に件数を記録。`validate_outputs.rb` も `legend_pdf_url` の絶対URL検証を追加。

**Consequences**:
- 再生成で `legend_pdf_url` を 124 レイヤーに付与(画像凡例 967 とは重複なし)。差分は該当レイヤーのみ(誤検出なし)。
- `hfu/faceless-cartographer` 側は `legend_pdf_url` があり画像凡例が無いレイヤーに「凡例 (PDF)」リンクを表示する(同リポジトリの対応が必要。画像凡例と違い無改修では出ない)。
- これで「画像でもPDFでも、GSI が凡例を公開しているレイヤーは全て Cartographer から辿れる」状態になった。GSI が凡例を公開していない 762 レイヤーは対象外。

## D27: `STAFF_PROMPT.md` に `required_styles`/`optional_styles`(D39)を追加する

**Status**: Accepted

**Context**: `hfu/faceless-cartographer` の Issue #6 を受け、同リポジトリが Map Intent に `required_styles`/`optional_styles`(`style_id` でスタイル全体を参照できるフィールド、D39)を追加した。`stars-optgeo`(実際に稼働している Martin サーバー)は既にこのカタログに `vlcm`(火山土地条件図)・`vbm`(火山基本図)を完成済みスタイルとして公開済み(`GET /style/{style_id}`、`hfu/kitavolca` の色分け・記号化を反映)。

しかし本 `STAFF_PROMPT.md` は `required_styles` を一切教えておらず、`vlcm`/`vbm` は「別カタログ: stars.optgeo.org」節に `required_layers` の `source_id` としてのみ記載されていた(D22 の頃からの記述)。この状態では、「北海道の火山土地条件図を見たい」という利用者の問いに対し、Staff が `required_styles` ベースの Map Intent を生成することは原理的に不可能だった(プロンプトが教えていない機能を使えるはずがない)。この欠落は `hfu/faceless-cartographer` 側がフォーム初期値をドロップダウン切り替え式にする作業(同リポジトリ D40)の過程で発見された。

**Decision**: `STAFF_PROMPT.md` に以下を追加した。

1. 「Map Intent の必須フィールド」節: `required_layers` **または** `required_styles` のどちらか1件以上でよい旨を明記。
2. 「別カタログ: stars.optgeo.org」節の「使い分けの目安」: 利用者が「完成した主題図そのもの」を求めている場合は `required_styles`/`optional_styles` を優先する旨のガイダンスを追加(従来の `required_layers` 参照は「個別データ層として扱いたい場合」に限定)。
3. 新節「完成した主題図が欲しい場合: `required_styles`(D39)」: `stars-optgeo` の `styles` エンドポイントの説明、YAML例、注意点(`style_id` も捏造しない、`layers-martin` は `styles` を持たない等)。
4. 「動作確認済みの例3: 『北海道の火山土地条件図を見たい』」を追加(`required_styles: [vlcm]` + `optional_styles: [vbm]`)。

**検証**: 単に文章を書くだけでなく、`hfu/faceless-cartographer` 側で以下の経験的検証を行った(同リポジトリ D40 参照)。

- 更新後のプロンプト全文のみを与えた独立エージェントに、プロンプト自身の動作確認済み例3とは異なる具体例(「恵山の火山土地条件図が見たい」、有珠山ではなく恵山)で Staff を演じさせ、`required_styles: [{style_id: "vlcm"}]` を正しく導けることを確認した。単なる例3のコピペではなく、一般的な使い分け指針からの汎化であることを担保するため、あえて異なる火山を選んでいる。
- 生成された Map Intent は `hfu/faceless-cartographer` の評価ハーネス(`scripts/eval-intent.ts`、`resolveStyles` 対応に拡張済み)で M1〜M5 すべて合格を確認済み。

**Consequences**:
- 「北海道の火山土地条件図を見たい」のような、完成した主題図を求める問いに対して、Staff が正しく `required_styles` を使えるようになった。
- `hfu/faceless-cartographer` 側は、この検証済みの問い・Map Intent ペアを `scripts/example-intents/07-volcano-land-condition-map.yaml`(プロンプトの例3と同一)・`08-volcano-land-condition-map-esan.yaml`(恵山、汎化の証拠)としてフィクスチャ化し、フォームのドロップダウン選択肢にも採用した(同リポジトリ D40)。
- `UNopenGIS/staccato-spec` への ADR 提案(ADR 0007、Proposed)も別途提出済み。

## D28: インターネット非接続・システムプロンプト保存可能なAI向けに `GENNAI_PROMPT.md` を新設する

**Status**: Superseded(2026-08-03、`dwg7/spiccato` へ移設。理由は本項末尾の追記を参照)

**2026-08-03追記(Superseded)**: `GENNAI_PROMPT.md` は本リポジトリから削除し、`dwg7/spiccato` 側で管理することにした。理由: 内容の大部分(`#q=`リンク構築規則)がspiccato固有のインタフェース(DECISIONS.md D6/D8 in `dwg7/spiccato`)に依存しており、`layers-martin` は特定のCartographer実装に依存しないLibraryであるべき、という本リポジトリの一貫した立場([D21](#d21-staff_promptmdにstarsoptgeoorgを別カタログとして追記するaggregatorは作らない)の「Cartographer実装に依存しない」判断と同種)に反していた。さらに同日、埋め込み範囲を「精選版」から「既知のノイズ系統を除く全カタログ」へ拡大する判断もあったため、生成ロジックごとspiccato側(Node.js、`scripts/build-gennai-prompt.mjs`)に移設した。以下は移設前の元の決定内容(記録として残す)。

**Context**: `dwg7/spiccato`(このカタログを使う Cartographer 実装の1つ、`hfu/faceless-cartographer` の第三世代)が、Staffを使う「スタイル」をノーマル(`STAFF_PROMPT.md` の貼り付け)以外にも増やす取り組みの一環として、政府AI「源内」(デジタル庁、AWS製OSS `Generative AI Use Cases` ベース)向けの検討を行った。源内はシステムプロンプトを保存できる一方、インターネットに一切アクセスできない(Web検索・fetchが使えない構成)。実際の文字数上限は未確認だが、保守的に8,000字を目標とすることになった。

この課題自体は本リポジトリで過去に検討済みである: 下記「バックログ」の `STANDALONE_PROMPT.md` 案(取り消し線あり)がほぼ同じ動機で提起されたが、D23 が「全カタログ埋め込み+生成スクリプトは保守負荷が高すぎる」と判断し、単一 `STAFF_PROMPT.md` 内のハイブリッド対応(小さな「オフラインフォールバック」節)を採用する形で決着していた。しかし D23 の解は `STAFF_PROMPT.md` 全体(34,497字)の一部として存在するものであり、**ファイル全体としては8,000字に収まらない**。源内のような厳しい文字数制約がある環境には、D23 の解決策そのままでは対応できない、という D23 が想定していなかったギャップが残っていた。

**Decision**: `STANDALONE_PROMPT.md` 案(全1,861件embedding、生成スクリプトによる自動化、日次cron再生成)は採用しない。D23 の判断(保守負荷・実用性とのバランス)は今回も妥当と判断し、そのまま踏襲する。

代わりに `GENNAI_PROMPT.md` を新設した。設計方針:

- **自動生成しない、手動保守**。ソースコードから生成するスクリプトを新たに書かない。D23 の「二重管理を避ける」判断を継承しつつ、`STAFF_PROMPT.md` 本体とは別に「オフライン専用・文字数制約あり」という異なる制約を持つ用途向けの、意図的に薄いドキュメントとして位置づける。
- **`STAFF_PROMPT.md` の既存の実証済み文章を土台に、抜粋・圧縮して構成する**。新規に内容を考案するのではなく、「あなたはStaffである」「責務」「Map Intentの必須フィールド」「背景地図について」「オフラインフォールバック」の各既存節、および `source_id` を捏造しないことという最重要ルールを土台にした。「意味解決の指針」「既知の欠落」「カタログの引き方」(インターネット接続前提のため無関係)、および3件の詳細なYAML例は文字数予算のため割愛した。
- **`#q=` リンクを直接構築する指示に置き換えた**。`STAFF_PROMPT.md` の「正しいやりとりの形」ステップ3(Map IntentをコピーしてCartographerに貼り付ける)は、spiccato(`dwg7/spiccato`)を前提に「`https://dwg7.github.io/spiccato/#q=...` の形でリンクを直接構築して提示する」に置き換えた。`goal`パラメータは省略を指示している(spiccato側で自動生成される、D6/D8) — 長い日本語文をURLに含めると伝送経路での破損リスクが増えるという、このセッション自体で実際に踏んだ教訓([dwg7/spiccato](https://github.com/dwg7/spiccato) DECISIONS.md D8/D9のfeedbackメモリ)を直接反映している。`required_styles`/`optional_styles`(stars-optgeoのvlcm/vbm)は`#q=`で表現できないため、その場合のみMap Intent YAMLをそのまま提示する指示にした。
- **既存のオフラインフォールバック一覧(約15件)を土台に、実在確認の上で軽微に拡充**した。新たに `terrainclassification1`(地形分類図、国交省土地履歴調査)を追加 — `STAFF_PROMPT.md` の「source_idを捏造しないこと」節が類似候補の一例として既に言及していたが、オフライン一覧自体には未収録だった。掲載した全14件のsource_id/style_id(layers-martin 10件・stars-optgeo 4件)は、執筆時点の実カタログ(`catalog.json`・`stars.optgeo.org/catalog`)に対して個別に存在確認済み。
- **文字数**: 3,966字(目標8,000字に対して十分な余裕を残した)。D23の「完全性より代表例で十分」という判断を踏襲し、余裕があるからといって埋めるのではなく、タイトに保つことを優先した。実際の源内の上限が判明した場合、この文書の分量を再検討する(現時点では拡張の必要は無いと判断)。

**Consequences**: `GENNAI_PROMPT.md` を追加。生成スクリプト・CI変更は無い(手動保守のため)。source_idの陳腐化リスクは `STAFF_PROMPT.md` のオフラインフォールバック節と同様に残る(D23が既に受容済みのリスクと同種) — 定期的に `STAFF_PROMPT.md` の該当節と突き合わせて更新する運用とする。上記「バックログ」の `STANDALONE_PROMPT.md` 案は、この決定によって改めて「不採用のまま」であることを明確にした(ファイル内に本Dへのポインタを追記)。

**実機検証(2026-08-03)**: `dwg7/spiccato` のサイトに埋め込まれた3件のサンプル質問すべてで、`GENNAI_PROMPT.md`の内容だけを使って(実カタログをfetchせず)Map Intent/リンクを構築し、spiccatoの本番相当ビルドで実際に描画できることを確認した。

1. 「令和8年熊本地震の災害対応正射画像(速報)を見たい」→ `#q=`リンク(`20260729kumamoto_yatsushiro_0729do_sokuho`)。欠落レイヤー無し。この事例のため、`## 例`節に個別のsource_idを明示的な「動作確認済みの例」として追記した(頻出カテゴリの一般化ではなく、このリポジトリの実際のflagshipデモに対する具体的な回答として)。
2. 「石狩川の治水について考えたい」→ `#q=`リンク(`lcmfc2`・`01_flood_l2_shinsuishin_data`)。欠落レイヤー無し。
3. 「北海道の火山土地条件図を見たい」→ Map Intent YAML(`required_styles: [vlcm]`・`optional_styles: [vbm]`)をspiccatoの貼り付けフォームに投入。欠落レイヤー無し。この検証の過程で、YAML例に`area.bbox`が欠けていた(全国表示にフォールバックしてしまう)不備を発見・修正した。

いずれもコンソールエラー無し。

## バックログ(未決定・保留)

### ~~エンタープライズ向けスタンドアロン版Staffプロンプット(`STANDALONE_PROMPT.md` 案)~~

**2026-08-03追記**: この案自体は今回も不採用のまま。ただし動機となった課題(インターネット非接続環境向けのStaffプロンプト)は、D28として一度は本リポジトリ側で決着させた(その時点では手動保守・数千字程度の精選版)。同日中に、埋め込み範囲を「既知のノイズ系統を除く全カタログ」へ拡大し、かつ内容がspiccato固有のインタフェースに依存することから、`dwg7/spiccato`側(`GENNAI_PROMPT.md`、`scripts/build-gennai-prompt.mjs`)へ丸ごと移設した(D28はSuperseded、詳細は同項参照)。本リポジトリはカタログ生成(`build_catalog.rb`)に専念する。

インターネットに接続できないエンタープライズAI環境では、Staffは `catalog`/`{id}` を都度fetchすることができない。現在の `STAFF_PROMPT.md` は「カタログを取得して調べる」ことを前提にしており、そのままでは使えない。

layers-martinのメタデータのエッセンスをすべて詰め込んだ、fetch不要のスタンドアロン版プロンプトが必要。設計にあたって検討が要る点:

1. **source_id一覧をどこまで埋め込むか**: 「捏造しない」原則を維持するには、実在するsource_idの一覧が無いと原理的に守れない。1,861件全部(id+name、TSV的に1行ずつなら150〜220KB程度と試算)を埋め込むか、カテゴリ(`path`)ごとの代表例に絞るか。前者は確実だがプロンプトが巨大になる。後者は「捏造しない」原則が弱まる(未掲載のidについては相変わらず確認できない)。
2. **生成の自動化**: 手書きでは1,861件を維持できない。`build_catalog.rb` の出力から `STANDALONE_PROMPT.md`(または生成物としての別ファイル)を自動生成するスクリプトが要る。毎日のcronでカタログ本体と一緒に再生成する形が自然。
3. **どこまでの情報を1件ごとに埋め込むか**: id+nameだけか、pathも含めるか(意味解決の精度に効くが容量も増える)。bounds/attribution/legend_image_urlの有無まで埋め込むかどうか。
4. **ファイル名**: 「STANDALONE_PROMPT.md」は仮称。より洗練された名前を検討する(例: `OFFLINE_STAFF_PROMPT.md`、`STAFF_PROMPT_FULL.md` 等)。
5. **`hfu/faceless-cartographer` 側への影響**: `GET /` が表示している「現在のStaffプロンプト」は、通常インターネット接続がある環境向けの `STAFF_PROMPT.md` のままでよいか、スタンドアロン版へのリンクも追加するか。

規模が大きいため、着手は別途判断する。

Staff/Cartographer ロールプレイでの実用性評価(2026-07-02)で見つかったが、まだ決定していない項目。

- **`maps.gsi.go.jp`/`cyberjapandata.gsi.go.jp`/`disaportaldata.gsi.go.jp` 配下(811件)の `attribution` 欠落**。D16 で意図的に保留(上記参照)。
- **`bounds`(46.2%)/`center`(4.6%)の欠落**。地理的カバレッジで足切りや自動フィットができない。対応は保留。
- **重複レイヤーの統合**(D10 で見送り済み)。

## D29: `STAFF_PROMPT.md` に spiccato 向けの受け渡し方法・URLリンク構築手順を追記する

**Status**: Accepted

**Context**: `dwg7/spiccato`(`hfu/faceless-cartographer`の第三世代、URLに状態を持たせる設計、同リポジトリ`DECISIONS.md` D2)を実際に使い込む中で、`STAFF_PROMPT.md`の「正しいやりとりの形」がこの前提と正面から食い違っていることが分かった:

- 第3項は「Map Intentをコピーして画面に貼り付ける」を唯一の受け渡し方法として記述しており、spiccatoが実際に想定するリンク直接構築という方法に触れていなかった。
- 第5項「共有の一次artifactは Map Intent のテキスト自体である。URLを共有手段として扱ってはならない。」は、spiccatoの設計と**正面から矛盾**していた。

この提案は2026-08-03時点で一度検討され(`/Users/hfu/spiccato`側のセッションでscratchpadに草稿として作成済み、`hfu/faceless-cartographer` D32のURL共有一回限り方針や`ADR 0001`との関係も踏まえて既に実機検証済みだった)、当時は適用を見送っていた。今回、spiccato側での作業(D10〜D15)を経て、この方向転換を`STAFF_PROMPT.md`自体にも反映すべきと判断した。

**Decision**:

- 「正しいやりとりの形」第3項・第5項を、対象Cartographerで条件分岐する形に差し替えた。`hfu/faceless-cartographer`は従来通り(貼り付け、`ADR 0001`のまま)、`dwg7/spiccato`はリンク直接構築(URL自体が一次artifact、`ADR 0001`の文言からの意図的な転換であることを明記)。どちらを対象にするかはStaffの関知するところではなく、利用者の指示・文脈に依存する、という立場を明記した。
- 新設セクション「spiccato 向けURLの構築 (#q=、推奨)」「spiccato 向けURLの構築 (#m=、コード実行環境が必要)」を追加。spiccato `DECISIONS.md` D3・D6の内容(deflate-raw圧縮+base64url、query string形式)を、コードを持たないStaffでも実行できる手順として明記した。
- 副産物として見つかった実務上の注意(`catalog`拡張子無しは`content-type: application/octet-stream`で返り、Web取得ツールによってはバイナリ扱いされる。`.json`付きを常用すべき)を、新設セクションと既存の「カタログの引き方」の両方に反映した。実際に`curl -I`で再確認済み。
- リンク提示時は生URLでなく`[説明文](URL)`形式のMarkdownハイパーリンクにすることも明記した(可読性のため、以前から美観上の要請として指摘されていた点)。

**Decision(範囲外としたもの)**: Staffが「対象のCartographerがどちらか」をどう判定するかは、利用者の初期指示や過去のやりとりに委ねる(自動判定ロジックは提案しない)。`hfu/faceless-cartographer`側の記述(同リポジトリD32のURL共有に関する記述)への変更は提案しない。両実装は並存する前提。

**Consequences**: `STAFF_PROMPT.md`が初めてspiccatoを明示的に扱うようになった。今後spiccato側の`#q=`/`#m=`仕様が変わった場合(dwg7/spiccato DECISIONS.md参照)、この2節も追随して更新する必要がある。

## D30: `dwg7/spiccato` Issue #1(テストレポート)の提案を反映する

**Status**: Accepted

**Context**: `dwg7/spiccato`側のセッションで、[Issue #1](https://github.com/dwg7/spiccato/issues/1)(M365 CopilotによるSTAFF_PROMPT.md/GENNAI_PROMPT.mdの評価レポート)への対応として、GENNAI_PROMPT.mdと合わせてSTAFF_PROMPT.mdにも同趣旨の改善を反映する判断があった(dwg7/spiccato DECISIONS.md D17参照)。D15・D29が確立した「STAFF_PROMPT.mdとGENNAI_PROMPT.mdは内容面で対応するよう保守する」方針を踏襲する。

**Decision**: 以下4点をSTAFF_PROMPT.mdに反映した(GENNAI_PROMPT.md側の対応する変更はdwg7/spiccato D17参照):

1. **bboxの扱いの明記**(2026-08-07に方針転換、下記追記参照): 当初は「地域・範囲の解決は Staff の責務」節に、「地名から十分な確信を持ってbboxを解決できない場合、細かい座標を推測で作らない。より広い既知の範囲に広げるか、`area.bbox`を`null`のまま残す方を優先する」という、source_id捏造と同列にnullフォールバックを推奨する一文を追加した。
2. **選定手順の強化**: 「source_id を捏造しないこと」節の「似た名前の候補が複数ある場合」を、(1)完全一致・強い意味一致を優先、(2)複数候補があれば主候補を`required_layers`・次点を`optional_layers`に、(3)対応する候補が無ければ「見つからない」と言う、という3段の手順として書き直した。
3. **`name`パラメータの日本語エンコーディング**: 「spiccato 向けURLの構築 (#q=、推奨)」節の`name`の説明に、「可能ならURLエンコードする。ただし確実にエンコードできる自信が無い場合は、日本語のままでもよい」という一文を追加した。リンク提示時の説明文については、同節が既にD29で「必ず`[説明文](URL)`形式のMarkdownハイパーリンクで提示する」ことを規定済みだったため、重複追加はしなかった。
4. **`generated_at`の扱い**: 「動作確認済みの例3」(`required_styles`、D39)のYAML例の直後に、「利用可能な現在日時を確信を持って把握できる場合のみISO8601で埋める。現在日時を確信できない場合は省略してよい」という注記を追加した。

**Consequences**: `STAFF_PROMPT.md`の4箇所を変更。GENNAI_PROMPT.mdとの内容対応(D15・D29の方針)を継続している。

**2026-08-07追記(bboxの扱いを方針転換)**: ユーザーから、上記1.の判断(source_idの捏造と同列にbboxのnullフォールバックを推奨する)を変更する指示があった。理由: source_idの捏造と地理的範囲の推測はユーザー体験への影響が異なる。**捏造されたsource_idは検索・描画のエラーという、利用者が対処しようのない失敗を生む**が、**bboxの粗い推測は「見たい範囲がおおむね画面に入っている」という、利用者が地図上でズーム・パンして自分で補正できる状態**を生むに過ぎない。`area.bbox`を`null`のまま利用者に「範囲を特定できない」と伝える設計は、利用者の手間を増やし体験を損なう。このため、「地域・範囲の解決は Staff の責務」節を「**bboxは十分な確信が持てなくてもベストエフォートで推測することを推奨し、狭すぎるより広めに見積もる方を優先する**」という逆方向の指針に書き換えた。「動作確認済みの例」(`bbox: null`)のコメントも、確信が持てなくても推測値を入れることを促す内容に書き換えた(この例自体は地域名がプレースホルダの汎用テンプレートであり、特定の検証済み数値を持たないため、コメント変更のみで足りる)。選定手順・source_id捏造防止の原則自体は変更していない — 変わったのはbboxという一つのフィールドの扱いのみ(GENNAI_PROMPT.md側の対応する変更はdwg7/spiccato DECISIONS.md D17参照)。

## D31: Staffの応答はUSER向けであり、内部規範の遵守を表明する必要はない

**Status**: Accepted

**Context**: `dwg7/spiccato`側のセッションで、Issue #2(GENNAI/Sonnetによる4件のロールプレイテスト)の熊本地震の例をD17で「捏造防止が正しく機能している好例」として記録した際、Staffが「それらしいidを作ることはしません」とUSERに向けて応答していた。ユーザーから、この応答の**内容**(実在しないレイヤーを捏造しなかったこと)は正しいが、**その事実をUSERに向けて表明すること自体**が誤りだという指摘があった。

Staccatoアーキテクチャの4者モデル(User/Staff/Cartographer/Library)において、StaffはUSER(利用者)に直面する。「捏造しません」という表明は、Staffが規範を守っているかを検証したい開発者には有用な情報だが、地図が欲しいだけのUSERには何の役にも立たない。この問題は、`STAFF_PROMPT.md`の捏造防止に関する指示文自体が「それらしい id を作らず『見つからない』と正直に伝える」という、ほぼそのままUSER向け応答のテンプレートとして機能してしまう書き方になっていたことに起因する(モデルが指示文の言い回しをほぼそのまま応答に転写した)。dwg7/spiccato側の対応するDECISIONS.mdはD18。

**Decision**: 「## あなたは Staff である」節の「### 責務」直後・「### 正しいやりとりの形」の直前に、新セクション「### 応答は利用者(顧客)向けであること」を追加した。

内容の骨子:

- StaffはUSER(利用者)に直面するコンシェルジュであり、開発者に向けて説明しているわけではない。「捏造しません」「正直にお伝えします」のように内部規範の遵守を表明することは、利用者には不要な情報である。**捏造はしないが、捏造しなかったこと自体を成果として述べる必要はない**。
- 該当データが見つからない場合、事実(例:「現在のカタログには対象データがありません」)を簡潔に伝える。「それらしい id を作ることはしません」のような、自分の振る舞いへの言及は含めない。
- 可能な範囲で代替案(範囲を広げる、近い候補を使う、任意レイヤーとして残す等)を添え、次に取れる行動を示す。コンシェルジュとして、常にベストエフォートのMap Intent/URLを返すことを目指す。
- 応答は、利用者が地図を見て意思決定するために必要な情報に絞る。判断の内部プロセスの説明は最小限にする。

あわせて、「source_id を捏造しないこと」節・「意味解決の指針」節にあった「正直に『見つからない』と伝える」というUSER向け応答のテンプレートをそのまま含んでいた2箇所の文言を、「見つからない旨を利用者に簡潔に伝える」という、内部規範への言及を含まない表現に書き換えた。**内部規範(捏造しないこと)自体は一切変更していない** — 変わったのは、その規範をUSERにどう伝えるか(あるいは伝えないか)という表現面のみ。

**Consequences**: `STAFF_PROMPT.md`の3箇所を変更。GENNAI_PROMPT.mdとの内容対応(D15・D29の方針)を継続している(dwg7/spiccato DECISIONS.md D18)。
