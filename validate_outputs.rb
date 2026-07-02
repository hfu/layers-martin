#!/usr/bin/env ruby
# frozen_string_literal: true

# validate_outputs.rb
#
# Validate that build_catalog.rb produced a usable catalog, not just that it
# ran without raising. build_catalog.rb intentionally never raises on
# per-layer problems (fetch failures, bad URLs, etc.) -- it records them in
# report.json and keeps going, so a completely empty or broken catalog can
# still exit 0. This script re-checks the actual output content and exits
# non-zero (with a clear reason) when something is actually wrong, so CI
# stops silently shipping a hollow catalog.

require 'json'
require 'set'
require 'optparse'

class ValidationError < StandardError; end

class OutputsValidator
  MARTIN_RESERVED_IDS = Set.new(%w[
    _ catalog config font health help index manifest metrics refresh reload sprite status
  ]).freeze

  def initialize(docs_dir:, min_tiles:)
    @docs_dir = docs_dir
    @min_tiles = min_tiles
    @errors = []
  end

  def run
    check_required_files_exist
    catalog = check_catalog_json_matches_copy
    report = load_json(path_for('report.json'))

    check_tiles_included_floor(report)
    check_no_fetch_failures(report)
    check_catalog_matches_tile_records(catalog, report)
    check_no_reserved_ids(catalog)
    check_per_source_files(catalog)

    if @errors.empty?
      puts "validate_outputs: OK (#{catalog['tiles'].length} sources)"
      true
    else
      warn "validate_outputs: FAILED (#{@errors.length} problem(s))"
      @errors.each { |e| warn "  - #{e}" }
      false
    end
  end

  private

  def path_for(name)
    File.join(@docs_dir, name)
  end

  def load_json(path)
    JSON.parse(File.read(path))
  rescue Errno::ENOENT
    raise ValidationError, "missing file: #{path}"
  rescue JSON::ParserError => e
    raise ValidationError, "invalid JSON in #{path}: #{e.message}"
  end

  def check_required_files_exist
    %w[catalog catalog.json manifest.json report.json index.html].each do |name|
      path = path_for(name)
      @errors << "missing required file: #{path}" unless File.exist?(path)
    end
  end

  def check_catalog_json_matches_copy
    catalog = load_json(path_for('catalog'))
    catalog_json = load_json(path_for('catalog.json'))
    @errors << 'docs/catalog and docs/catalog.json content differ' if catalog != catalog_json
    catalog
  end

  def check_tiles_included_floor(report)
    included = report.dig('summary', 'tiles_included').to_i
    return if included >= @min_tiles

    @errors << "tiles_included (#{included}) is below the expected floor (#{@min_tiles}); " \
               'the catalog may be silently empty or badly truncated'
  end

  def check_no_fetch_failures(report)
    failures = report['failures'] || []
    return if failures.empty?

    @errors << "#{failures.length} fetch/parse failure(s) recorded in report.json: " \
               "#{failures.first(3).map { |f| f['url'] }.join(', ')}#{failures.length > 3 ? ', ...' : ''}"
  end

  def check_catalog_matches_tile_records(catalog, report)
    catalog_ids = catalog['tiles'].keys.to_set
    included = report.dig('summary', 'tiles_included').to_i

    unless catalog_ids.length == included
      @errors << "catalog has #{catalog_ids.length} tiles but report.json summary.tiles_included is #{included}"
    end
  end

  def check_no_reserved_ids(catalog)
    collisions = catalog['tiles'].keys.to_set & MARTIN_RESERVED_IDS
    return if collisions.empty?

    @errors << "catalog contains Martin-reserved source IDs: #{collisions.to_a.join(', ')}"
  end

  def check_per_source_files(catalog)
    seen_tile_urls = {}

    catalog['tiles'].each_key do |id|
      plain_path = path_for(id)
      json_path = "#{plain_path}.json"

      unless File.exist?(plain_path)
        @errors << "missing docs/#{id} for catalog entry"
        next
      end
      unless File.exist?(json_path)
        @errors << "missing docs/#{id}.json for catalog entry"
        next
      end

      tilejson = load_json(plain_path)
      tilejson_copy = load_json(json_path)
      @errors << "docs/#{id} and docs/#{id}.json content differ" if tilejson != tilejson_copy

      check_tilejson_shape(id, tilejson)
      check_duplicate_tile_url(id, tilejson, seen_tile_urls)
    end
  end

  def check_tilejson_shape(id, tilejson)
    @errors << "docs/#{id}: tilejson field is not \"3.0.0\"" unless tilejson['tilejson'] == '3.0.0'

    tiles = tilejson['tiles']
    if !tiles.is_a?(Array) || tiles.empty?
      @errors << "docs/#{id}: tiles array is missing or empty"
      return
    end

    url = tiles.first
    unless url.start_with?('http://', 'https://')
      @errors << "docs/#{id}: tiles[0] is not an absolute URL (#{url})"
    end
    unless url.include?('{z}') && url.include?('{x}') && url.include?('{y}')
      @errors << "docs/#{id}: tiles[0] is missing {z}/{x}/{y} placeholders (#{url})"
    end

    legend_image_url = tilejson['legend_image_url']
    if legend_image_url && !legend_image_url.start_with?('http://', 'https://')
      @errors << "docs/#{id}: legend_image_url is not an absolute URL (#{legend_image_url})"
    end
  end

  def check_duplicate_tile_url(id, tilejson, seen_tile_urls)
    url = tilejson['tiles']&.first
    return unless url

    if seen_tile_urls.key?(url)
      @errors << "docs/#{id} and docs/#{seen_tile_urls[url]} both serve the same tiles URL " \
                 '(duplicate-URL suppression should have caught this, see DECISIONS.md D10)'
    else
      seen_tile_urls[url] = id
    end
  end
end

options = { docs: 'docs', min_tiles: 1000 }

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby validate_outputs.rb [options]'

  opts.on('--docs DIR', 'Output directory to validate, default: docs') { |v| options[:docs] = v }
  opts.on('--min-tiles N', Integer, 'Minimum acceptable tiles_included, default: 1000') { |v| options[:min_tiles] = v }
end.parse!

begin
  ok = OutputsValidator.new(docs_dir: options[:docs], min_tiles: options[:min_tiles]).run
  exit(ok ? 0 : 1)
rescue ValidationError => e
  warn "validate_outputs: FAILED (#{e.message})"
  exit 1
end
