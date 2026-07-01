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
