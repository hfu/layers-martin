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
    @used_ids = {}
  end

  def run
    log "reading #{@root_url}"
    read_document(@root_url, [])

    FileUtils.rm_rf(@out_dir)
    FileUtils.mkdir_p(@out_dir)

    tile_records = []

    @layers.each do |record|
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
        name: layer['title'] || source_id,
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

  def build_tilejson(source_id, layer, url, record)
    tilejson = {
      'tilejson' => '3.0.0',
      'name' => layer['title'] || source_id,
      'tiles' => [url],
      'scheme' => 'xyz'
    }

    tilejson['attribution'] = layer['attribution'] if layer.key?('attribution')
    tilejson['description'] = layer['html'] if layer.key?('html')
    tilejson['minzoom'] = layer['minZoom'] if layer.key?('minZoom')
    tilejson['maxzoom'] = layer['maxZoom'] if layer.key?('maxZoom')

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
        'failures' => @failures.length
      },
      'fetched_files' => @fetched_files,
      'excluded' => @excluded,
      'warnings' => @warnings,
      'id_changes' => @id_changes,
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
