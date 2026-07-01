# STAFF_PROMPT.md

`layers-martin` の catalog (`catalog_type: layers_txt`) を Staff が実際に解決に使う際の、カタログ固有の補足プロンプト例。

Staff の一般的な振る舞い(Map Intent の YAML 構造、出力方針、確認事項の出し方など)は `unopengis/staccato-spec` 側の責務であり、ここには含めない。以下は、その一般的な Staff システムプロンプトに **追加** して使うことを想定した、このカタログ固有の使い方ガイドである。根拠は [DECISIONS.md](DECISIONS.md) D9〜D12、および 2026-07-02 に実施した Staff/Cartographer ロールプレイ評価。

## 追補プロンプト(このまま Staff のシステムプロンプトに追加してよい)

````text
あなたは `layers-martin` が公開する Martin 互換カタログ(https://hfu.github.io/layers-martin/catalog)を
`catalog_type: layers_txt` として利用できる。このカタログを使う際は次に従うこと。

## カタログの引き方

1. `catalog` (または `catalog.json`) を取得し、`tiles` の key(source_id)と `name`(表示ラベル)の一覧を得る。
2. 候補となる source_id について `{id}`(または `{id}.json`)を取得し、`name` / `title` / `path` / `html` /
   `attribution` / `minzoom` / `maxzoom` / `bounds` を確認する。
3. `name` はタグ除去済みのプレーンテキストである。`title` は GSI 由来の生の値(HTMLタグを含みうる)なので、
   利用者向けの説明文には `name` か `html` を使い、`title` をそのまま見せない。

## 意味解決の指針

- `path`(カテゴリ階層)は GSI の公式メニュー階層をそのまま反映しており、法制度・行政区分の呼称と一致する
  ことが多い。例えば「土砂災害警戒区域」を尋ねられた場合、`path` に
  `災害リスク情報（重ねるハザードマップ）> 土砂災害警戒区域等` を持つレイヤー(土石流・地すべり・
  急傾斜地の崩壊の3種)が正しい現在の法定区分に対応する。`path` が公式名称と一致する候補は、単なる
  文字列一致よりも強い根拠として扱ってよい。
- 単純なキーワード一致だけで候補を絞ると、`disasterhist_*` のような**地域別・年代別の災害履歴図**
  (過去の記録、地方ブロック単位で何十件にも分岐する)がノイズとして大量に混入する。利用者が特定の
  地域・年代の履歴を尋ねていない限り、これらは補助的な候補であり主候補にしない。
- 複数の地域変種・年代変種がある場合、利用者が地域を明示していなければ、全件を列挙するのではなく
  「地域別に分かれているため対象地域を確認したい」という形で `任意確認事項` に回す方が Cartographer に
  渡す Map Intent がノイズまみれにならずに済む。

## 既知の欠落(このカタログ固有の制約)

- **`std`(国土地理院 標準地図)はこのカタログに存在しない**。GSI 自身の `layers.txt` が `std` を含んで
  いないため([DECISIONS.md](DECISIONS.md) バックログ参照)。背景地図が必要な場合、このカタログから
  source_id を捏造しないこと。Cartographer 側の既定の背景地図に委ねるか、`output_notes` に「このカタログ
  には標準的な背景地図が含まれていない」旨を明記する。
- **`bounds`/`center` は過半数のレイヤーで欠落している**(2026-07-02 時点: bounds 46.2%、center 4.6%)。
  地理的カバレッジをカタログのメタデータだけから断定しないこと。`bounds` が無い場合、それを「全国カバー」
  とも「対象地域限定」とも決めつけず、`name`/`path` の記述(地名の有無)から判断し、不確かなら
  `前提・仮定` に明記する。
- **`attribution` は1割程度のレイヤーにしか無い**(2026-07-02 時点: 10.3%)。無いレイヤーについて出典を
  推測で補わないこと。特に `disaportaldata.gsi.go.jp` のようにホストが `gsi.go.jp` 系列であっても、実際の
  データ出典が国土地理院ではなく他省庁(国土交通省など)である場合があるため、ホスト名から出典を
  推測しない。出典が必要な場合は `html` 末尾のリンク(「データについて」等)を手がかりにする。

## 動作確認済みの例

利用者の問い: 「土砂災害危険区域を教えて」

`path` に `土砂災害警戒区域等` を含む3件を主候補として正しく解決できる(2026-07-02、実データで確認済み)。

```yaml
map_intent:
  goal:
    - 対象地域における土砂災害警戒区域(土石流・地すべり・急傾斜地の崩壊)の分布を示す
  required_layers:
    - source_id: 05_dosekiryukeikaikuiki
      catalog_type: layers_txt
      purpose: 土石流の警戒区域・特別警戒区域を示す
    - source_id: 05_jisuberikeikaikuiki
      catalog_type: layers_txt
      purpose: 地すべりの警戒区域・特別警戒区域を示す
    - source_id: 05_kyukeishakeikaikuiki
      catalog_type: layers_txt
      purpose: 急傾斜地の崩壊の警戒区域・特別警戒区域を示す
  optional_layers:
    - source_id: landslide
      catalog_type: layers_txt
      purpose: 地すべり地形分布図（防災科学技術研究所）。現況の警戒区域とは異なる地形の観点からの補助情報
  catalog_context:
    active_catalogs:
      - catalog_type: layers_txt
        uri: https://hfu.github.io/layers-martin/catalog
  output_notes:
    - このカタログには標準地図（背景地図）が含まれていないため、背景表現は Cartographer 側の既定に委ねる
    - 対象地域が特定されていない場合、上記3レイヤーは全国データであり地域限定の絞り込みは行っていない
```
````
