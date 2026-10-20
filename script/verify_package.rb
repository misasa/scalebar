# Verify a built archive and its installed CLI without changing user gems.
# Run after bundle install: bundle exec ruby script/verify_package.rb path.gem
require 'bundler'
require 'rubygems/package'
require 'rbconfig'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'digest'
require_relative '../lib/scalebar/version'

root = File.expand_path('..', __dir__)
archive = File.expand_path(ARGV.fetch(0))
package = Gem::Package.new(archive)
raise 'Invalid gem archive' unless package.verify
raise 'Package version differs from source' unless package.spec.version.to_s == Scalebar::VERSION

files = package.contents
required = %w[bin/image-scalebar lib/scalebar.rb lib/scalebar/scalebar.rb lib/scalebar/version.rb README.md LICENSE.txt]
raise "Missing packaged files: #{required - files}" unless (required - files).empty?
forbidden = files.reject { |file| required.include?(file) || file.match?(%r{\Alib/.+\.rb\z}) }
raise "Unexpected packaged files: #{forbidden}" unless forbidden.empty?
raise 'Wrong license metadata' unless package.spec.licenses == ['GPL-3.0-or-later']
raise 'Missing executable metadata' unless package.spec.executables.include?('image-scalebar')

# Use the already resolved dependencies; never fetch or replace user gems.
dependency_paths = (Gem.path + Gem.loaded_specs.values.map(&:base_dir)).uniq
Dir.mktmpdir('scalebar-package-') do |directory|
  home = File.join(directory, 'gems')
  environment = {'GEM_HOME' => home, 'GEM_PATH' => ([home] + dependency_paths).join(File::PATH_SEPARATOR)}
  execute = lambda do |*arguments|
    stdout, stderr, status = Open3.capture3(environment, RbConfig.ruby, *arguments, chdir: directory)
    raise "Command failed (#{status.exitstatus}): #{arguments.inspect}\n#{stdout}\n#{stderr}" unless status.success?
    [stdout, stderr]
  end

  Bundler.with_unbundled_env do
    execute.call('-S', 'gem', 'install', '--local', '--no-document', '--ignore-dependencies', archive)
    # Check the installed code, not a source-checkout require or an older gem.
    stdout, = execute.call('-rscalebar/version', '-e',
      'puts Scalebar::VERSION; puts Gem.loaded_specs.fetch("scalebar").full_gem_path')
    installed_version, installed_path = stdout.lines.map(&:strip)
    raise 'Installed version differs from source' unless installed_version == Scalebar::VERSION
    expected_path = File.join(home, 'gems', package.spec.full_name)
    # macOS exposes the same temporary directory through /var and /private/var.
    unless installed_path && File.realpath(installed_path) == File.realpath(expected_path)
      raise "Loaded scalebar outside the isolated installation: #{installed_path.inspect} (expected #{expected_path.inspect})"
    end
    cli = File.join(home, 'bin/image-scalebar')
    stdout, = execute.call(cli, '--help')
    raise 'Help is missing its usage' unless stdout.include?('image-scalebar [options] imagefile')

    [
      ['metadata', true, []],
      ['metadata_grid', true, ['--grid=1']],
      ['manual_width', false, ['--width=60']],
      ['manual_magnification', false, ['--magnification=2']],
      ['image_only', false, []],
      ['uncalibrated_grid', false, ['--grid=1']]
    ].each do |name, metadata, options|
      work = File.join(directory, name)
      FileUtils.mkdir_p(work)
      image = File.join(work, 'Dag340B1-Mg.jpg')
      tex = File.join(work, 'Dag340B1-Mg.tex')
      FileUtils.cp(File.join(root, 'spec/fixtures/files/Dag340B1-Mg.jpg'), image)
      if metadata
        FileUtils.cp(File.join(root, 'spec/fixtures/files/Dag340B1-Mg.txt'), work)
      end
      execute.call(cli, *options, image)
      actual = File.read(tex).gsub(/\d{2}-[A-Za-z]{3}-\d{4} \d{2}:\d{2}:\d{2}/, '<TIMESTAMP>')
      expected = File.read(File.join(root, 'spec/fixtures/latex', "#{name}.tex"))
      raise "Installed gem changed #{name} output" unless actual == expected
      before = Digest::SHA256.file(tex).hexdigest
      _, stderr = execute.call(cli, *options, image)
      raise "Installed gem overwrote #{name} output" unless Digest::SHA256.file(tex).hexdigest == before && stderr.include?('already exists')
      puts "PASS installed gem: #{name} generation and non-overwrite"
    end
  end
end
puts "PASS #{package.spec.full_name}: archive, isolated installation, help and LaTeX output"
