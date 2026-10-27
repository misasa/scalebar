require 'spec_helper'
require 'digest'

RSpec.describe 'image-scalebar CLI' do
  describe 'documented command-line behavior', :specification do
    it 'prints usable help and exits successfully without writing files' do
      stdout, stderr, status = run_cli('--help')
      expect(status.exitstatus).to eq(0)
      expect(stdout).to include('image-scalebar [options] imagefile', '--magnification', '--width', '--grid')
      expect(stderr).to be_empty
      expect(Dir.children(@work_dir)).to be_empty
    end

    it 'rejects a missing image argument with a nonzero exit and no output file' do
      _, stderr, status = run_cli
      # Optimist currently exits -1 (255 on POSIX); the public contract
      # requires failure, not a particular upstream diagnostic code.
      expect(status.success?).to be(false)
      expect(stderr).to include('invalid args')
      expect(Dir.children(@work_dir)).to be_empty
    end

    [['--unknown-option'], ['--width=invalid'], ['--magnification=invalid'], ['--grid=invalid']].each do |options|
      it "rejects #{options.first} without creating LaTeX" do
        prepare_image
        _, stderr, status = run_cli(*options, image_path)
        expect(status.success?).to be(false)
        expect(stderr).not_to be_empty
        expect(File.exist?(tex_path)).to be(false)
      end
    end

    it 'accepts options after the image filename' do
      prepare_image
      _, _, status = run_cli(image_path, '-w', '60')
      expect(status.exitstatus).to eq(0)
      expect(File.read(tex_path)).to include('relative to 12 cm is |2.000|')
    end

    it 'does not overwrite an existing LaTeX file, including its modification time' do
      prepare_image(metadata: true)
      original = "Existing user document\n"
      File.write(tex_path, original)
      File.utime(Time.at(946684800), Time.at(946684800), tex_path)
      before = File.stat(tex_path).mtime
      _, stderr, status = run_cli(image_path)
      expect(status.exitstatus).to eq(0)
      expect(stderr).to include('already exists')
      expect(File.binread(tex_path)).to eq(original)
      expect(File.stat(tex_path).mtime).to eq(before)
    end
  end

  describe 'LaTeX output', :characterization do
    # Captured from master 192e966; only timestamps are normalized. Geometry
    # specs independently verify numbers, while snapshots protect output format.
    [
      ['metadata', true, []],
      ['metadata_grid', true, ['--grid=1']],
      ['manual_width', false, ['--width=60']],
      ['manual_magnification', false, ['--magnification=2']],
      ['image_only', false, []],
      ['uncalibrated_grid', false, ['--grid=1']]
    ].each do |name, metadata, options|
      it "preserves baseline #{name} output and leaves input files unchanged" do
        prepare_image(metadata: metadata)
        inputs = Dir.glob(File.join(@work_dir, '*')).map { |path| [path, Digest::SHA256.file(path).hexdigest] }
        _, _, status = run_cli(*options, image_path)
        expect(status.exitstatus).to eq(0)
        expected = File.read(File.join(__dir__, 'fixtures/latex', "#{name}.tex"))
        expect(normalized_tex(File.read(tex_path))).to eq(expected)
        inputs.each { |path, digest| expect(Digest::SHA256.file(path).hexdigest).to eq(digest) }
      end
    end
  end

  describe 'LaTeX scale and grid values', :specification do
    [
      ['0.0006', '100 nm'],
      ['0.006', '1 \\textmu{}m'],
      ['0.06', '10 \\textmu{}m'],
      ['0.6', '100 \\textmu{}m'],
      ['6', '1 mm'],
      ['60', '10 mm']
    ].each do |width_mm, label|
      it "labels the scale bar as #{label} for a #{width_mm} mm field" do
        prepare_image
        _, _, status = run_cli("--width=#{width_mm}", image_path)
        expect(status.exitstatus).to eq(0)
        tex = File.read(tex_path)
        expect(tex).to include("\\put(1,3){\\colorbox{white}{\\bf \\Huge #{label}}}")
        expect(tex).not_to include('\\put(1,3){\\colorbox{white}{\\bf \\Huge \\nolinkurl')
      end
    end

    it 'omits the scale label when no calibration is available' do
      prepare_image
      _, _, status = run_cli(image_path)
      expect(status.exitstatus).to eq(0)
      expect(File.read(tex_path)).not_to include('\\put(1,3)')
    end

    it 'writes a 10,000 um bar as 16.7 percent of a 60 mm landscape field' do
      prepare_image
      _, _, status = run_cli('--width=60', image_path)
      expect(status.exitstatus).to eq(0)
      tex = File.read(tex_path)
      # One sixth of 60 mm is 10 mm (10,000 um); overpic uses percent.
      expect(tex).to include('Scalebar of |10000| micro meter is drawn.')
      expect(tex.scan('\\line(1,0){16.7}').length).to eq(2)
      expect(tex).to include('\\linethickness{4pt}', '\\linethickness{2pt}', '\\end{overpic}')
      expect(tex).not_to include('\\multiput')
    end

    it 'writes a 1 mm grid at 10 percent pitch in a synthetic 10 mm square field' do
      path = File.join(@work_dir, 'square.png')
      write_png(path, 100, 100)
      _, _, status = run_cli('--width=10', '--grid=1', path)
      expect(status.exitstatus).to eq(0)
      tex = File.read(File.join(@work_dir, 'square.tex'))
      # 100 pixels span 10 mm. Each 1 mm step is 10 pixels / 10 percent.
      # Ticks span -5 to +5 mm, with nine interior grid lines.
      expect(tex).to include('Grids of |1000| micro meter pitch are drawn.')
      expect(tex).to include('\\multiput(10.00,0.0)(10.00, 0.0){9}')
      expect(tex).to include('\\multiput(0.0, 10.00)(0.0, 10.00){9}')
      expect(tex).to include('\\makebox(10.00,5.00){\\textbf{ A }}')
      expect(tex).to include('\\scriptsize $-4$', '\\scriptsize $4$')
    end
  end

  describe 'unsupported inputs retained for compatibility', :characterization do
    # Failure boundaries, not desirable validation. Fixes need a separate
    # behavior-change proposal; see DEVELOPMENT.md.
    it 'fails for a calibrated nonexistent image without promising atomic output' do
      _, stderr, status = run_cli('--width=60', File.join(@work_dir, 'missing.jpg'))
      expect(status.success?).to be(false)
      expect(stderr).not_to be_empty
    end

    it 'currently writes a reference to a nonexistent uncalibrated image' do
      # Without calibration, the renderer never reads the image header.
      _, _, status = run_cli(File.join(@work_dir, 'missing.jpg'))
      expect(status.exitstatus).to eq(0)
      expect(File.read(File.join(@work_dir, 'missing.tex'))).to include('\\begin{overpic}[width=0.49\\textwidth]{missing}')
    end

    it 'fails for an unreadable image format' do
      File.write(image_path, 'not an image')
      _, stderr, status = run_cli('--width=60', image_path)
      expect(status.success?).to be(false)
      expect(stderr).not_to be_empty
    end

    [['--width=0'], ['--magnification=0'], ['--width=-1'], ['--grid=0', '--width=60']].each do |options|
      it "retains a failing exit for #{options.join(' ')} without redefining diagnostics" do
        prepare_image
        _, stderr, status = run_cli(*options, image_path)
        expect(status.success?).to be(false)
        expect(stderr).not_to be_empty
      end
    end
  end
end
