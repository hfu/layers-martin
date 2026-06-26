# layers-martin starter

This starter converts GSI `layers.txt` into a static Martin-compatible catalog.

## Run

```sh
ruby build_catalog.rb --root https://maps.gsi.go.jp/layers_txt/layers.txt --out docs
```

## Outputs

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

## Policy

- `docs/{id}` is the primary Martin-like TileJSON endpoint.
- `docs/{id}.json` is a debugging and GitHub Pages convenience copy.
- `catalog` does not include TileJSON links.
- Included tile formats: `.png`, `.jpg`, `.jpeg`, `.webp`, `.pbf`, `.mvt`.
- Excluded formats, such as `.geojson`, `.topojson`, `.txt`, `.kml`, are recorded in `report.json`.
- `html` and `attribution` are preserved as original strings.
- GSI layers.txt keys such as `maxNativeZoom`, `legendUrl`, `styleurl`, `cocotile` are preserved without a `gsi:` prefix.
