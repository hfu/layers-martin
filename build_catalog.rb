#!/usr/bin/env ruby
# frozen_string_literal: true

# build_catalog.rb
#
# Convert GSI layers.txt into a static Martin-compatible catalog.
#
# Outputs:
#   docs/catalog
#   docs/catalog.json
#   docs/{id}
#   docs/{id}.json
#   docs/index.html
#   docs/manifest.json
#   docs/report.json
#
# Design policy:
# - Martin-compatible paths are primary: /catalog and /{sourceID}
# - .json copies are generated for GitHub Pages/debugging convenience
# - catalog does not contain TileJSON links
# - include only image/MVT tile sources: png, jpg, jpeg, webp, pbf, mvt
# - exclude geojson, topojson, txt, kml and unknown formats from catalog
# - keep html / attribution as original strings
# - keep GSI layers.txt keys without a gsi: prefix where useful
# - do not expand subdomains; report non-empty subdomains or {s} URLs as warnings
# - include MVT/PBF but omit vector_layers, reporting that omission as a warning

require 'json'
require 'net/http'
require 'uri'
require 'fileutils'
require 'digest/sha1'
require 'time'
require 'set'
require 'optparse'

class GsiLayersToStaticMartin
  ROOT_DEFAULT = 'https://maps.gsi.go.jp/layers_txt/layers.txt'

  INCLUDED_EXTENSIONS = %w[.png .jpg .jpeg .webp .pbf .mvt].freeze

  CONTENT_TYPES = {
    '.png' => 'image/png',
    '.jpg' => 'image/jpeg',
    '.jpeg' => 'image/jpeg',
    '.webp' => 'image/webp',
    '.pbf' => 'application/x-protobuf',
    '.mvt' => 'application/x-protobuf'
  }.freeze

  # Layers sourced from https://maps.gsi.go.jp/sar/... are per-event, per-observation-date-pair
  # InSAR (ALOS/ALOS-2/ALOS-4) interferogram snapshots. They are not stable base layers and
  # currently make up ~80% of all candidate layers (~10,500 of ~12,600), which would overwhelm
  # a Staff/Cartographer catalog consumer. Suppress them from the main catalog but keep every
  # one recorded in report.json (reason: sar_observation_snapshot) so the policy stays auditable
  # and reversible. See HANDOVER.md "レイヤー抑制方針" for the full rationale.
  SAR_SOURCE_PREFIX = 'https://maps.gsi.go.jp/sar/'

  # Aircraft SAR ("航空機SAR画像") observation snapshots are the same kind of
  # per-event, per-observation-date/angle noise as SAR_SOURCE_PREFIX targets,
  # just hosted outside maps.gsi.go.jp/sar/ (e.g. layers6.txt), so they are
  # identified by category path instead of URL. Much smaller in volume
  # (~17 layers) but suppressed on the same principle. See DECISIONS.md D15.
  AIRCRAFT_SAR_PATH_PREFIX = '航空機SAR画像'

  # layers.txt's own "attribution" field is essentially always absent or an
  # empty string (0 of 1,861 layers had a non-empty value as of 2026-07-02).
  # A per-tile-host default is used to fill it in, but only for hosts
  # confirmed (by reading their "html" field) to serve a single organization's
  # data. "maps.gsi.go.jp" and "disaportaldata.gsi.go.jp" are deliberately
  # excluded: both were found to also host other agencies' data under the
  # same host (e.g. "rinya", forest photos credited to 林野庁, on
  # maps.gsi.go.jp), so a host-based default there would misattribute ~2% of
  # entries. See DECISIONS.md D16.
  TILE_HOST_ATTRIBUTION = {
    'tiles.gsj.jp' => '産業技術総合研究所地質調査総合センター',
    'gbank.gsj.jp' => '産業技術総合研究所地質調査総合センター',
    'nlftp.mlit.go.jp' => '国土交通省',
    'www.j-shis.bosai.go.jp' => '防災科学技術研究所'
  }.freeze

  MARTIN_RESERVED_IDS = Set.new(%w[
    _ catalog config font health help index manifest metrics refresh reload sprite status
  ]).freeze

  attr_reader :root_url, :out_dir

  def initialize(root_url:, out_dir:, verbose: true)
    @root_url = root_url
    @out_dir = out_dir
    @verbose = verbose

    @visited_urls = Set.new
    @fetched_files = []
    @layers = []
    @groups_seen = 0
    @failures = []
    @excluded = []
    @warnings = []
    @id_changes = []
    @attribution_defaults = []
    @legend_image_urls_found = 0
    @used_ids = {}
  end

  def run
    log "reading #{@root_url}"
    read_document(@root_url, [])

    # layers0.txt holds the base maps (std/pale/blank/english/ort) and is not
    # linked from the root layers.txt tree at all -- it has to be fetched
    # explicitly or the catalog ends up with no background maps. See
    # DECISIONS.md D13.
    layers0_url = absolute_url('layers0.txt', @root_url)
    log "reading #{layers0_url}"
    read_document(layers0_url, ['背景地図'])

    FileUtils.rm_rf(@out_dir)
    FileUtils.mkdir_p(@out_dir)

    canonical_index_by_url = compute_canonical_index_by_url

    tile_records = []

    @layers.each_with_index do |record, index|
      layer = record[:layer]
      url = normalize_tile_url(layer['url'].to_s)
      ext = extension_for(url)

      unless INCLUDED_EXTENSIONS.include?(ext)
        @excluded << exclusion_record(record, url, 'unsupported_extension', ext)
        next
      end

      unless tile_template?(url)
        @excluded << exclusion_record(record, url, 'not_xyz_tile_template', ext)
        next
      end

      if record[:source_url].to_s.start_with?(SAR_SOURCE_PREFIX)
        @excluded << exclusion_record(record, url, 'sar_observation_snapshot', ext)
        next
      end

      if (record[:path] || []).any? { |p| p.to_s.start_with?(AIRCRAFT_SAR_PATH_PREFIX) }
        @excluded << exclusion_record(record, url, 'aircraft_sar_observation_snapshot', ext)
        next
      end

      canonical_index = canonical_index_by_url[url]
      if canonical_index && canonical_index != index
        @excluded << exclusion_record(record, url, 'duplicate_url_reference', ext)
        next
      end

      warn_subdomains(layer, record)

      source_id = resolve_source_id(layer, url, record[:path])
      tilejson = build_tilejson(source_id, layer, url, record)
      content_type = CONTENT_TYPES.fetch(ext)

      if %w[.pbf .mvt].include?(ext)
        @warnings << {
          type: 'vector_layers_omitted',
          id: source_id,
          title: layer['title'],
          url: url,
          action: 'mvt_included_without_vector_layers'
        }
      end

      write_json(File.join(@out_dir, source_id), tilejson)
      write_json(File.join(@out_dir, "#{source_id}.json"), tilejson)

      tile_records << {
        id: source_id,
        name: tilejson['name'],
        content_type: content_type,
        tilejson: tilejson
      }
    end

    catalog = build_catalog(tile_records)
    write_json(File.join(@out_dir, 'catalog'), catalog)
    write_json(File.join(@out_dir, 'catalog.json'), catalog)

    write_json(File.join(@out_dir, 'manifest.json'), build_manifest(tile_records))
    write_json(File.join(@out_dir, 'report.json'), build_report(tile_records))
    write_index(tile_records)

    log "done: #{tile_records.length} sources included, #{@excluded.length} layers excluded, #{@warnings.length} warnings"
  end

  private

  def log(message)
    warn message if @verbose
  end

  # layers.txt commonly re-lists the same tile source (identical normalized
  # tiles URL) under multiple LayerGroup branches, sometimes under a
  # disaster-context alias id (conventionally prefixed with "_", e.g.
  # "_relief_20160830" aliasing "relief") or a UI-variant id unrelated to the
  # tile's own name (e.g. "gsi-compare-photo", a time-series-slider view of
  # the "seamlessphoto" tiles). These are the same rendered tile source, not
  # distinct layers, so only one canonical occurrence is kept in the catalog;
  # the rest are recorded in report.json as "duplicate_url_reference".
  #
  # Canonical selection, in order: (1) not a disaster-context alias id,
  # (2) id matches the tile's own /xyz/{id}/ URL segment, since that is the
  # name the tile source declares for itself independent of which menu it is
  # listed under, (3) first-seen order as a deterministic tiebreak.
  def compute_canonical_index_by_url
    groups = Hash.new { |h, k| h[k] = [] }
    @layers.each_with_index do |record, index|
      url = normalize_tile_url(record[:layer]['url'].to_s)
      groups[url] << index
    end

    canonical_index_by_url = {}
    groups.each do |url, indices|
      next if indices.length <= 1

      xyz_id = xyz_id_from_url(url)
      canonical_index_by_url[url] = indices.min_by { |i| canonical_rank(@layers[i][:layer], xyz_id, i) }
    end
    canonical_index_by_url
  end

  def canonical_rank(layer, xyz_id, index)
    id = layer['id'].to_s
    alias_rank = id.start_with?('_') ? 1 : 0
    xyz_match_rank = (xyz_id && id == xyz_id) ? 0 : 1
    [alias_rank, xyz_match_rank, index]
  end

  def read_document(url, path)
    absolute_url = absolute_url(url, @root_url)
    return if @visited_urls.include?(absolute_url)

    @visited_urls << absolute_url

    begin
      text = fetch_text(absolute_url)
      data = JSON.parse(strip_bom(text))
      @fetched_files << { url: absolute_url, bytes: text.bytesize }
    rescue StandardError => e
      @failures << { url: absolute_url, error: e.class.to_s, message: e.message }
      return
    end

    case data
    when Array
      data.each do |item|
        if item.is_a?(Hash) && item['url']
          read_document(absolute_url(item['url'], absolute_url), path)
        elsif item.is_a?(Hash)
          walk_entry(item, absolute_url, path)
        end
      end
    when Hash
      entries = data['layers'] || data['entries'] || []
      entries.each { |entry| walk_entry(entry, absolute_url, path) } if entries.is_a?(Array)
    else
      @warnings << { type: 'unexpected_document_type', url: absolute_url, class: data.class.to_s }
    end
  end

  def walk_entry(item, base_url, path)
    return unless item.is_a?(Hash)

    type = item['type']
    title = item['title'] || item['id']

    if type == 'Layer' || (item.key?('url') && type != 'LayerGroup')
      @layers << { source_url: base_url, path: path, layer: item }
      return
    end

    if type == 'LayerGroup' || item.key?('entries') || item.key?('src')
      @groups_seen += 1
      next_path = title ? path + [title] : path

      read_document(absolute_url(item['src'], base_url), next_path) if item['src']

      entries = item['entries'] || []
      entries.each { |entry| walk_entry(entry, base_url, next_path) } if entries.is_a?(Array)
    end
  end

  def fetch_text(url)
    uri = URI.parse(url)
    raise "unsupported URI scheme: #{uri.scheme}" unless %w[http https].include?(uri.scheme)

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'gsi-layers-to-static-martin/0.1.0'
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        response.body.dup.force_encoding('UTF-8')
      when Net::HTTPRedirection
        location = response['location']
        raise "redirect without Location: #{url}" unless location

        fetch_text(absolute_url(location, url))
      else
        raise "HTTP #{response.code} #{response.message}: #{url}"
      end
    end
  end

  def strip_bom(text)
    text.sub(/^\xEF\xBB\xBF/, '')
  end

  def absolute_url(href, base)
    URI.join(base, href).to_s
  rescue StandardError
    href.to_s
  end

  def normalize_tile_url(url)
    s = url.to_s.strip
    s = s.gsub(%r{/\s+\{z\}}, '/{z}')
         .gsub(%r{/\s+\{x\}}, '/{x}')
         .gsub(%r{/\s+\{y\}}, '/{y}')
         .gsub(%r{\{z\}/\s+\{x\}/\s+\{y\}}, '{z}/{x}/{y}')
    s
  end

  def tile_template?(url)
    url.include?('{z}') && url.include?('{x}') && url.include?('{y}') && absolute_http_url?(url)
  end

  def absolute_http_url?(url)
    # URI.parse rejects tile templates like {z}/{x}/{y} as invalid URIs,
    # so validate scheme/host against a placeholder-substituted copy.
    uri = URI.parse(url.gsub(/\{[^}]*\}/, 'x'))
    %w[http https].include?(uri.scheme) && uri.host
  rescue URI::InvalidURIError
    false
  end

  def extension_for(url)
    path = begin
      URI.parse(url).path
    rescue URI::InvalidURIError
      url.split('?').first
    end
    ext = File.extname(path.to_s).downcase
    ext.empty? ? '(none)' : ext
  end

  LEGEND_IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .svg .webp].freeze

  # `legendUrl` and `html` are inconsistent across layers.txt entries: some
  # have legendUrl pointing directly at an image, some have no legendUrl but
  # embed a legend <img> inside html, some link to a legend image with an
  # <a href="...jpg">凡例を表示</a> anchor (e.g. lcmfc2 治水地形分類図), some
  # have neither. See DECISIONS.md D18. Returns
  # [url, :direct | :html_extracted | :html_link] or nil.
  def legend_image_source(layer)
    # URLs in layers.txt occasionally carry stray surrounding whitespace (e.g.
    # legendUrl "https://maps.gsi.go.jp/legend/2015_relief_sakurajima.jpg "),
    # which would otherwise defeat the image-extension check. Strip everywhere.
    legend_url = layer['legendUrl'].to_s.strip
    if !legend_url.empty? && absolute_http_url?(legend_url) && LEGEND_IMAGE_EXTENSIONS.include?(extension_for(legend_url))
      return [legend_url, :direct]
    end

    html = layer['html'].to_s
    match = html.match(/<img[^>]+src=["']([^"']+)["']/i)
    if match
      img_src = match[1].strip
      return [img_src, :html_extracted] if absolute_http_url?(img_src)
    end

    # Anchor-linked legend image: GSI often exposes the legend not as an <img>
    # but as a link (<a href=".../legend/xxx_legend.jpg">凡例を表示</a>). Only
    # accept an anchor whose href is an image and that is clearly a legend --
    # href under a /legend/ path, or anchor text mentioning 凡例 -- so we don't
    # mistake an unrelated image link (a photo, a "解説" page, etc.) for a legend.
    html.scan(%r{<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>}im).each do |raw_href, text|
      href = raw_href.strip
      next unless absolute_http_url?(href)
      next unless LEGEND_IMAGE_EXTENSIONS.include?(extension_for(href))
      return [href, :html_link] if href.include?('/legend/') || text.include?('凡例')
    end

    nil
  end

  def exclusion_record(record, url, reason, ext)
    layer = record[:layer]
    {
      id: layer['id'],
      title: layer['title'],
      url: url,
      reason: reason,
      extension: ext,
      source_url: record[:source_url],
      path: record[:path]
    }
  end

  def warn_subdomains(layer, record)
    subdomains = layer['subdomains']
    if !subdomains.nil? && subdomains.to_s != ''
      @warnings << {
        type: 'subdomains_present',
        id: layer['id'],
        title: layer['title'],
        subdomains: subdomains,
        source_url: record[:source_url],
        action: 'kept_as_is_no_expansion'
      }
    end

    url = layer['url'].to_s
    return unless url.include?('{s}') || url.include?('{subdomain}')

    @warnings << {
      type: 's_placeholder_present',
      id: layer['id'],
      title: layer['title'],
      url: url,
      source_url: record[:source_url],
      action: 'not_expanded_initial_version'
    }
  end

  def resolve_source_id(layer, url, path)
    raw_candidate = first_present(
      layer['id'],
      xyz_id_from_url(url),
      slug_from_path_title(path, layer['title'])
    )

    base = sanitize_id(raw_candidate)
    base = "layer_#{short_hash([url, path, layer['title']].join('|'))}" if base.empty?

    original = base
    if MARTIN_RESERVED_IDS.include?(base)
      base = "gsi_#{base}"
      @id_changes << { original: original, resolved: base, reason: 'martin_reserved_id' }
    end

    if @used_ids.key?(base)
      resolved = "#{base}_#{short_hash([url, path, layer['title']].join('|'))}"
      @id_changes << { original: base, resolved: resolved, reason: 'duplicate_id' }
      base = resolved
    end

    @used_ids[base] = true
    base
  end

  def first_present(*values)
    values.find { |v| !v.nil? && v.to_s.strip != '' }.to_s
  end

  def xyz_id_from_url(url)
    normalized = normalize_tile_url(url)
    match = normalized.match(%r{/xyz/([^/]+)/\{z\}/\{x\}/\{y\}\.[A-Za-z0-9]+})
    match && match[1]
  end

  def slug_from_path_title(path, title)
    source = (path + [title]).compact.join('-')
    sanitize_id(source)
  end

  def sanitize_id(value)
    s = value.to_s.strip.downcase
    s = s.gsub(/[^a-z0-9._-]+/, '-')
    s = s.gsub(/-+/, '-')
    s = s.gsub(/\A[-._]+|[-._]+\z/, '')
    s
  end

  def short_hash(value)
    Digest::SHA1.hexdigest(value.to_s)[0, 8]
  end

  def default_attribution_for(source_id, url)
    host = URI.parse(url.gsub(/\{[^}]*\}/, 'x')).host
    attribution = TILE_HOST_ATTRIBUTION[host]
    return nil unless attribution

    @attribution_defaults << { id: source_id, host: host, attribution: attribution }
    attribution
  rescue URI::InvalidURIError
    nil
  end

  # TileJSON's "name" is a standard field meant to be a plain display label,
  # distinct from "html"/"description"/"attribution" (D4: kept as raw HTML on
  # purpose) and from "title" (D5: raw GSI key passed through verbatim). Some
  # GSI titles embed markup (e.g. "土石流<br>(黄は警戒区域、赤は特別警戒区域)"),
  # which would otherwise leak literal tags into "name". Strip tags/entities
  # here; the original markup is still available in "title" and "html".
  def plain_text_name(title, fallback)
    text = title.to_s
              .gsub(/<[^>]*>/, ' ')
              .gsub('&nbsp;', ' ')
              .gsub('&amp;', '&')
              .gsub('&lt;', '<')
              .gsub('&gt;', '>')
              .gsub(/\s+/, ' ')
              .strip
    text.empty? ? fallback : text
  end

  def build_tilejson(source_id, layer, url, record)
    tilejson = {
      'tilejson' => '3.0.0',
      'name' => plain_text_name(layer['title'], source_id),
      'tiles' => [url],
      'scheme' => 'xyz'
    }

    attribution = layer['attribution'].to_s.strip
    if attribution.empty?
      default_attribution = default_attribution_for(source_id, url)
      attribution = default_attribution if default_attribution
    end
    tilejson['attribution'] = attribution unless attribution.empty?

    tilejson['description'] = layer['html'] if layer.key?('html')
    tilejson['minzoom'] = layer['minZoom'] if layer.key?('minZoom')
    tilejson['maxzoom'] = layer['maxZoom'] if layer.key?('maxZoom')

    legend_source = legend_image_source(layer)
    if legend_source
      legend_url, origin = legend_source
      tilejson['legend_image_url'] = legend_url
      @legend_image_urls_found += 1
      if origin == :html_extracted
        @warnings << {
          type: 'legend_image_extracted_from_html',
          id: source_id,
          url: legend_url,
          action: 'no_legendUrl_image_available_scraped_first_img_tag_from_html'
        }
      elsif origin == :html_link
        @warnings << {
          type: 'legend_image_extracted_from_html_link',
          id: source_id,
          url: legend_url,
          action: 'no_legendUrl_or_img_available_used_legend_anchor_href_from_html'
        }
      end
    end

    center = center_from_area(layer['area'])
    tilejson['center'] = center if center

    bounds = bounds_from_layer(layer['bounds'])
    tilejson['bounds'] = bounds if bounds

    # Preserve useful GSI/layers.txt fields without a gsi: prefix.
    %w[
      id title maxZoom maxNativeZoom legendUrl iconUrl styleurl html cocotile area bounds
      tileSize errorTileUrl subdomains
    ].each do |key|
      tilejson[key] = layer[key] if layer.key?(key)
    end

    tilejson['source_url'] = record[:source_url]
    tilejson['path'] = record[:path]

    tilejson
  end

  def center_from_area(area)
    return nil unless area.is_a?(Hash)
    return nil unless area.key?('lng') && area.key?('lat')

    center = [area['lng'], area['lat']]
    center << area['zoom'] if area.key?('zoom')
    center
  end

  def bounds_from_layer(bounds)
    # TileJSON expects [west, south, east, north].
    # GSI/Leaflet-style bounds may be [[south, west], [north, east]].
    return nil unless bounds.is_a?(Array)

    if bounds.length == 4 && bounds.all? { |v| v.is_a?(Numeric) }
      return bounds
    end

    if bounds.length == 2 && bounds[0].is_a?(Array) && bounds[1].is_a?(Array)
      south, west = bounds[0]
      north, east = bounds[1]
      return [west, south, east, north] if [west, south, east, north].all? { |v| v.is_a?(Numeric) }
    end

    nil
  end

  def build_catalog(tile_records)
    tiles = {}
    tile_records.sort_by { |r| r[:id] }.each do |record|
      tiles[record[:id]] = {
        'name' => record[:name],
        'content_type' => record[:content_type]
      }
    end

    {
      'tiles' => tiles,
      'sprites' => {},
      'fonts' => {},
      'styles' => {}
    }
  end

  def build_manifest(tile_records)
    {
      'generated_at' => Time.now.utc.iso8601,
      'generator' => 'gsi-layers-to-static-martin',
      'generator_version' => '0.1.0',
      'input_root' => @root_url,
      'output_layout' => 'martin-static-docs-id-and-json',
      'included_extensions' => INCLUDED_EXTENSIONS,
      'excluded_extensions' => %w[.geojson .topojson .txt .kml],
      'fetched_files' => @fetched_files.length,
      'layers_seen' => @layers.length,
      'tiles_included' => tile_records.length,
      'layers_excluded' => @excluded.length,
      'warnings' => @warnings.length
    }
  end

  def build_report(tile_records)
    excluded_by_reason = Hash.new(0)
    @excluded.each { |e| excluded_by_reason[e[:reason].to_s] += 1 }

    {
      'summary' => {
        'input_root' => @root_url,
        'visited_urls' => @visited_urls.length,
        'fetched_files' => @fetched_files.length,
        'groups_seen' => @groups_seen,
        'layers_seen' => @layers.length,
        'tiles_included' => tile_records.length,
        'layers_excluded' => @excluded.length,
        'excluded_by_reason' => excluded_by_reason,
        'warnings' => @warnings.length,
        'attribution_defaults' => @attribution_defaults.length,
        'legend_image_urls_found' => @legend_image_urls_found,
        'failures' => @failures.length
      },
      'fetched_files' => @fetched_files,
      'excluded' => @excluded,
      'warnings' => @warnings,
      'id_changes' => @id_changes,
      'attribution_defaults' => @attribution_defaults,
      'failures' => @failures
    }
  end

  def write_json(path, object)
    File.write(path, JSON.pretty_generate(object) + "\n")
  end

  def write_index(tile_records)
    rows = tile_records.sort_by { |r| r[:id] }.map do |record|
      id = escape_html(record[:id])
      name = escape_html(record[:name])
      content_type = escape_html(record[:content_type])
      %(<tr><td><a href="./#{id}">#{id}</a></td><td>#{name}</td><td>#{content_type}</td></tr>)
    end.join("\n")

    html = <<~HTML
      <!doctype html>
      <html lang="ja">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>GSI layers.txt static Martin catalog</title>
        <style>
          body { font-family: system-ui, sans-serif; margin: 2rem; line-height: 1.5; }
          table { border-collapse: collapse; width: 100%; }
          th, td { border-bottom: 1px solid #ddd; padding: .4rem .5rem; text-align: left; }
          code { background: #f4f4f4; padding: .1rem .25rem; }
        </style>
      </head>
      <body>
        <h1>GSI layers.txt static Martin catalog</h1>
        <p><a href="./catalog">catalog</a> / <a href="./catalog.json">catalog.json</a></p>
        <p>Sources: #{tile_records.length}</p>
        <table>
          <thead><tr><th>ID</th><th>Name</th><th>Content-Type</th></tr></thead>
          <tbody>
      #{rows}
          </tbody>
        </table>
      </body>
      </html>
    HTML

    File.write(File.join(@out_dir, 'index.html'), html)
  end

  def escape_html(value)
    value.to_s
         .gsub('&', '&amp;')
         .gsub('<', '&lt;')
         .gsub('>', '&gt;')
         .gsub('"', '&quot;')
  end
end

options = {
  root: GsiLayersToStaticMartin::ROOT_DEFAULT,
  out: 'docs',
  verbose: true
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby build_catalog.rb [options]'

  opts.on('--root URL', 'Root layers.txt URL') { |v| options[:root] = v }
  opts.on('--out DIR', 'Output directory, default: docs') { |v| options[:out] = v }
  opts.on('--quiet', 'Suppress progress logs') { options[:verbose] = false }
end.parse!

GsiLayersToStaticMartin.new(
  root_url: options[:root],
  out_dir: options[:out],
  verbose: options[:verbose]
).run
