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
2. `STAFF_PROMPT.md` の Map Intent 例が `unopengis/staccato-spec` の `spec/map-intent-vnext.md` と食い違っていた(`catalog_type` vs 正しい `type`、`purpose` vs 正しい `label`、`spec_version`/`provenance` の欠落、独自の `required_area`/`base` フィールド)。AIの出力はこの食い違った例をなぞっていたと考えられる。

あわせて、Staff プロンプトの実装をどのリポジトリの責務にするかの整理が必要になった。`unopengis/staccato-spec` は規範仕様の記述に専念させたい一方、`layers-martin` は Library の第一実装に過ぎずプロンプトの本来の置き場所ではない。しかし分離を急ぎすぎると、`layers-martin` 自体が固まる前にリポジトリ切り替えコストが発生する。

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

**Context**: Cartographer の初期実装(`hfu/faceless-cartographer`)を進める過程で、`layers-martin`/`faceless-cartographer`/`unopengis/staccato-spec` の3リポジトリ間の整合性を確認した。2点、ドキュメントで埋めるべきギャップが見つかった。

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

**Decision**: フェンス内の冒頭に「## あなたは Staff である」節を追加した。内容は `unopengis/staccato-spec` の `architecture-principles.md`(責務分離・least disclosure等の核心原則、§5.2のStaff characterization)と `ADR 0002`(起動時カタログ契約・隠れたフォールバック禁止)を出典として要約したもの: (1) 責務(Map Intentの生成、機微な文脈を含めない、設定済みカタログのみ使用、source_id捏造禁止)、(2) 正しいやりとりの形(User→Staff→人間によるコピー&ペースト→Cartographer、URLではなくMap Intentが共有の一次artifact)、(3) Map Intentの必須フィールド。この節の後に、既存のlayers-martin固有の内容(カタログの引き方、source_id捏造禁止の詳細、意味解決の指針等)を「以上がStaccatoの一般的な規定である。以下はLibraryとしてlayers-martinを使う際に固有の補足である」という接続で続ける構成にした。

**Consequences**: `STAFF_PROMPT.md` は単体である程度自己完結したStaffプロンプトとして機能するようになった(既存のより詳細なStaffシステムプロンプトへの追加としても、単体としても使える)。`hfu/faceless-cartographer` は `GET /` でこのファイルを動的取得して表示している([D13](https://github.com/hfu/faceless-cartographer/blob/main/DECISIONS.md#d13-gettopページに現在のstaffプロンプトを表示する))ため、コード変更なしに反映される。

## バックログ(未決定・保留)

### エンタープライズ向けスタンドアロン版Staffプロンプット(`STANDALONE_PROMPT.md` 案、仮称)

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
