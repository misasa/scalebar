require 'fileutils'
require 'tmpdir'
require 'stringio'
require 'open3'
require 'rbconfig'
require 'zlib'
require 'scalebar'

module FixtureHelpers
  FIXTURES = File.expand_path('fixtures/files', __dir__)
  CLI = File.expand_path('../bin/image-scalebar', __dir__)
  LIB = File.expand_path('../lib', __dir__)

  def image_path
    File.join(@work_dir, 'Dag340B1-Mg.jpg')
  end

  def tex_path
    File.join(@work_dir, 'Dag340B1-Mg.tex')
  end

  def prepare_image(metadata: false)
    FileUtils.cp(File.join(FIXTURES, 'Dag340B1-Mg.jpg'), image_path)
    FileUtils.cp(File.join(FIXTURES, 'Dag340B1-Mg.txt'), @work_dir) if metadata
    image_path
  end

  def app_for(*options, metadata: false)
    prepare_image(metadata: metadata)
    app = Scalebar::Scalebar.new(StringIO.new, options + [image_path])
    app.parse_option
    app
  end

  def run_cli(*arguments)
    Open3.capture3(RbConfig.ruby, '-I', LIB, CLI, *arguments, chdir: @work_dir)
  end

  def normalized_tex(text)
    text.gsub(/\d{2}-[A-Za-z]{3}-\d{4} \d{2}:\d{2}:\d{2}/, '<TIMESTAMP>')
  end

  # A real RGB PNG checks portrait geometry without mocking Dimensions.
  def write_png(path, width, height)
    chunk = lambda do |type, data|
      [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
    end
    pixels = ("\0" + "\0\0\0" * width) * height
    data = "\x89PNG\r\n\x1a\n".b
    data << chunk.call('IHDR', [width, height, 8, 2, 0, 0, 0].pack('NNCCCCC'))
    data << chunk.call('IDAT', Zlib::Deflate.deflate(pixels))
    data << chunk.call('IEND', ''.b)
    File.binwrite(path, data)
  end
end

RSpec.configure do |config|
  config.include FixtureHelpers
  config.order = :random
  config.disable_monkey_patching!
  config.around do |example|
    Dir.mktmpdir('scalebar-spec-') do |directory|
      @work_dir = directory
      example.run
    end
  end
end
