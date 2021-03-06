#!/usr/bin/env ruby

require 'optparse'
require 'pathname'
require 'json'
require 'fileutils'

# Cleans up all images not referenced by a tag.
class Application
  attr_reader :base_dir

  def initialize(args)
    @base_dir = Pathname.new('/var/lib/docker/registry')
    @args = args
  end

  def optparser
    @optparser ||= OptionParser.new do |opts|
      opts.banner = <<-BANNER
Usage: #{opts.program_name} [options]

Removes orphaned or dangling images from Docker Registry v1.
      BANNER

      opts.separator ''

      opts.on(
        '-d',
        '--directory DIRECTORY',
        "The directory where the registry data is stored (default #{base_dir})"
      ) do |d|
        dir = Pathname.new(d).expand_path
        fail "#{dir} is not a directory!" unless dir.directory?
        @base_dir = dir
      end

      opts.on(
        '-s',
        '--saftey-margin SECONDS',
        "How many seconds an image must exist on disk before it can be removed (default #{safety_margin_seconds})"
      ) do |s|
        @safety_margin_seconds = Integer(s)
      end
    end
  end

  def log_stream
    @log_stream ||= File.open('/tmp/docker-remove-orphan-images.log', 'a')
      .tap { |l| l.puts "*** STARTING AT #{Time.now} ***" }
  end

  def info(str)
    puts "INFO: #{str}"
  end

  def repository_dir
    base_dir + 'repositories'
  end

  def image_dir
    base_dir + 'images'
  end

  def libraries
    @libraries ||= repository_dir
      .children
      .select(&:directory?)
  end

  def repositories
    @repositories ||= libraries
      .map(&:children)
      .flatten
      .select(&:directory?)
  end

  def tags
    @tags ||= repositories
      .map(&:children)
      .flatten
      .select { |p| p.basename.to_s =~ /^tag_/ }
  end

  def all_image_hashes
    @all_image_hashes ||= image_dir
      .children
      .select(&:directory?)
      .select { |p| (p + '_checksum').exist? }
      .reject { |p| (p + '_checksum').mtime >= timestamp }
      .map(&:basename)
      .map(&:to_s)
  end

  def used_image_hashes
    @used_image_hashes ||= tags
      .map(&:read)
      .map(&:chomp)
      .map { |h| image_dir + h + 'ancestry' }
      .select(&:file?)
      .map { |p| JSON.load p }
      .flatten
      .sort
      .uniq
  end

  def unused_image_hashes
    @unused_image_hashes ||= all_image_hashes - used_image_hashes
  end

  def safety_margin_seconds
    @safety_margin_seconds ||= 60 * 60
  end

  def timestamp
    @timestamp ||= Time.new - safety_margin_seconds
  end

  def remove_index_references!
    repositories.each do |repo|
      filename = repo + '_index_images'
      original_index = JSON.load filename.read
      modified_index = original_index.reject { |x| unused_image_hashes.include? x['id'] }
      next if original_index.size == modified_index.size

      info "Updating index for #{repo}"
      filename.open('w') { |f| f.write modified_index.to_json }
    end
  end

  def remove_unused_images!
    unused_image_hashes.each do |hash|
      filename = image_dir + hash
      info "Removing #{hash}"
      FileUtils.rm_rf filename
    end
  end

  def run
    optparser.parse!
    remove_index_references!
    remove_unused_images!
  ensure
    log_stream.close unless log_stream.closed?
  end
end

Application.new(ARGV).run if $PROGRAM_NAME == __FILE__
