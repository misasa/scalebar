# Read-only preflight. Run from the checkout after fetching origin/master and tags.
# Usage: ruby script/verify_release.rb TAG COMMIT paginated-releases.json
require 'json'
require 'open3'
require 'rubygems'

tag, commit, releases_path = ARGV
abort 'Expected TAG COMMIT releases.json' unless ARGV.length == 3
spec = Gem::Specification.load('scalebar.gemspec')
abort 'Cannot load scalebar.gemspec' unless spec
version = spec.version.to_s
abort 'Release version must have three stable numeric components' unless version.match?(/\A(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\z/)
abort 'Tag version differs from gemspec version' unless tag == "v#{version}"
filename = "scalebar-#{version}.gem"
abort 'Gem filename differs from release version' unless spec.file_name == filename

git = lambda do |*args|
  stdout, stderr, status = Open3.capture3('git', *args)
  abort "Git check failed: #{stderr}" unless status.success?
  stdout.strip
end
head = git.call('rev-parse', 'HEAD')
tag_commit = git.call('rev-parse', '--verify', "refs/tags/#{tag}^{commit}")
abort 'Tag, event commit and checkout commit differ' unless head == commit && tag_commit == commit
_, _, status = Open3.capture3('git', 'merge-base', '--is-ancestor', commit, 'refs/remotes/origin/master')
abort 'Release commit is not contained in origin/master' unless status.success?
tags = git.call('tag', '--list').lines.map(&:strip)
abort "Legacy version tag already exists: #{version}" if tags.include?(version)

pages = JSON.parse(File.read(releases_path))
abort 'Invalid Release API response' unless pages.is_a?(Array) && pages.all? { |page| page.is_a?(Array) }
pages.flatten(1).each do |release|
  abort 'Invalid Release API entry' unless release.is_a?(Hash) &&
    release['tag_name'].is_a?(String) && release['assets'].is_a?(Array)
  same_version = release.fetch('tag_name').sub(/\Av/, '') == version
  same_asset = release.fetch('assets').any? { |asset| asset.fetch('name') == filename }
  abort "Release for version #{version} already exists (including drafts)" if same_version || same_asset
end
puts filename
