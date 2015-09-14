#!/usr/bin/env ruby

require 'optparse'
require 'pathname'
require 'json'
require 'fileutils'

# Cleans up all images not referenced by a tag.
class Application
  attr_reader :base_dir

  def initialize(args)
    @base_dir = Pathname.new('/data/registry')
    @args = args
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
      .reject { |p| p.mtime >= timestamp }
  end

  def all_image_hashes
    @all_image_hashes ||= image_dir
      .children
      .select(&:directory?)
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

  def timestamp
    @timestamp ||= Time.new - (60 * 60)
  end

  def info(str)
    puts "INFO: #{str}"
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
    remove_index_references!
    remove_unused_images!
  end
end

Application.new(ARGV).run if $PROGRAM_NAME == __FILE__
