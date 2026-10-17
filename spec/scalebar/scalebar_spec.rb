require 'spec_helper'

RSpec.describe Scalebar::Scalebar do
  describe 'calibration and geometry', :specification do
    # The JPEG has 1914 x 1537 pixels; its independent JEOL sidecar records
    # the same dimensions, magnification 7.837 and stage coordinates in mm.
    it 'reads JPEG dimensions independently of the sidecar' do
      app = app_for('--magnification=2')
      expect(app.dimensions).to eq([1914, 1537])
      expect(app.length).to eq(1914)
      expect(app.normalized_dimensions).to eq([100.0, 80.3030303030303])
    end

    it 'reads magnification and stage coordinates from the JEOL sidecar' do
      app = app_for(metadata: true)
      expect(app.magnification).to eq(7.837)
      expect(app.stage_position).to eq([57.656, 15.152])
      expect(app.locate).to eq([57656.0, 15152.0])
    end

    it 'uses the image header when sidecar dimensions disagree', :characterization, specification: false do
      prepare_image(metadata: true)
      File.write(File.join(@work_dir, 'Dag340B1-Mg.txt'), "CM_MAG 2\nCM_FULL_SIZE 1 1\n")
      app = described_class.new(StringIO.new, [image_path])
      app.parse_option
      expect(app.dimensions).to eq([1914, 1537])
    end

    # JEOL's 2x image represents a 60 mm field on its 120 mm reference.
    # Thus 1914 pixels span 60,000 um: 31.9 pixels per mm.
    it 'converts a 2x image into mm, um and pixels without losing a factor of 1000' do
      app = app_for('--magnification=2')
      expect(app.length_in_mm).to eq(60.0)
      expect(app.length_in_um).to eq(60000.0)
      expect(app.width).to eq(60000.0)
      expect(app.pixels_per_um).to be_within(1e-12).of(0.0319)
      expect(app.width_in_um).to be_within(1e-8).of(60000.0)
      expect(app.height_in_um).to be_within(1e-8).of(48181.81818181818)
    end

    it 'converts a supplied 60 mm field into magnification 2' do
      expect(app_for('--width=60').magnification).to eq(2.0)
    end

    it 'centers physical extents on the stage origin when coordinates are absent' do
      app = app_for('--magnification=2')
      expect(app.stage_position).to eq([0, 0])
      expect(app.x_range[0]).to be_within(1e-8).of(-30000.0)
      expect(app.x_range[1]).to be_within(1e-8).of(30000.0)
      expect(app.y_range[0]).to be_within(1e-8).of(-24090.90909090909)
      expect(app.y_range[1]).to be_within(1e-8).of(24090.90909090909)
    end

    it 'translates field extents by stage coordinates converted from mm to um' do
      app = app_for('--magnification=2')
      app.stage_position = [10.0, -20.0]
      expect(app.locate).to eq([10000.0, -20000.0])
      expect(app.x_range[0]).to be_within(1e-8).of(-20000.0)
      expect(app.x_range[1]).to be_within(1e-8).of(40000.0)
      expect(app.y_range[0]).to be_within(1e-8).of(-44090.90909090909)
      expect(app.y_range[1]).to be_within(1e-8).of(4090.90909090909)
    end
  end

  describe 'scale bar sizing', :characterization do
    # Existing policy: the largest power of ten um <= the reference field.
    # Literals protect decade boundaries, without prescribing a new policy.
    [[9.999, 1000.0], [10.0, 10000.0], [10.001, 10000.0], [60.0, 10000.0]].each do |width_mm, bar_um|
      it "chooses a #{bar_um.to_i} um bar for a #{width_mm} mm reference field" do
        expect(app_for("--width=#{width_mm}").scale_length_on_stage).to eq(bar_um)
      end
    end

    it 'draws a 10 mm bar as 319 pixels in the 1914 pixel, 60 mm landscape field' do
      expect(app_for('--width=60').scale_length_on_image).to be_within(1e-10).of(319.0)
    end

    it 'preserves the current portrait normalization and horizontal bar policy' do
      path = File.join(@work_dir, 'portrait.png')
      write_png(path, 60, 120)
      app = described_class.new(StringIO.new, ['--width=60', path])
      app.parse_option
      expect(app.dimensions).to eq([60, 120])
      expect(app.length).to eq(120)
      expect(app.normalized_dimensions).to eq([50.0, 100.0])
      expect(app.width_in_um).to eq(30000.0)
      # Known inconsistency: the horizontal bar uses a 60 mm reference,
      # but longest-edge calibration makes the horizontal extent 30 mm.
      expect(app.scale_length_on_image).to eq(10.0)
    end
  end

  describe '.generate_absolute_ticks', :specification do
    # A 1000-pixel field at 0.1 pixel/um spans 10,000 um. A 2000 um
    # pitch is 200 pixels, or 20 percentage points in overpic coordinates.
    it 'places aligned ticks every 20 percent, including both endpoints' do
      ticks = described_class.generate_absolute_ticks([0, 10000], 0.1, 1000, 2000)
      expect(ticks.map { |tick| tick[:um] }).to eq([0, 2000, 4000, 6000, 8000, 10000])
      expect(ticks.map { |tick| tick[:prop] }).to eq([0.0, 20.0, 40.0, 60.0, 80.0, 100.0])
    end

    it 'includes neighboring ticks outside an unaligned positive field' do
      ticks = described_class.generate_absolute_ticks([1000.0, 11000.0], 0.1, 1000, 2000.0)
      expect(ticks.map { |tick| tick[:um] }).to eq([0, 2000, 4000, 6000, 8000, 10000, 12000])
      expect(ticks.map { |tick| tick[:prop] }).to eq([-10.0, 10.0, 30.0, 50.0, 70.0, 90.0, 110.0])
    end

    it 'rounds negative stage coordinates outward rather than toward zero' do
      ticks = described_class.generate_absolute_ticks([-1000.0, 9000.0], 0.1, 1000, 2000.0)
      expect(ticks.map { |tick| tick[:um] }).to eq([-2000, 0, 2000, 4000, 6000, 8000, 10000])
      expect(ticks.map { |tick| tick[:prop] }).to eq([-10.0, 10.0, 30.0, 50.0, 70.0, 90.0, 110.0])
    end

    it 'uses micrometers for a 500 um pitch independently of pixel density' do
      ticks = described_class.generate_absolute_ticks([0, 1000], 0.2, 200, 500)
      expect(ticks).to eq([{um: 0, prop: 0.0}, {um: 500, prop: 50.0}, {um: 1000, prop: 100.0}])
    end
  end

  describe 'input precedence and defaults', :characterization do
    it 'retains integer-division truncation for direct integer tick inputs' do
      # Known limitation outside the normal CLI's floating-point coordinate
      # pipeline: integer division omits the outer tick at 12,000 um.
      ticks = described_class.generate_absolute_ticks([1000, 11000], 0.1, 1000, 2000)
      expect(ticks.map { |tick| tick[:um] }).to eq([0, 2000, 4000, 6000, 8000, 10000])
    end

    it 'gives an existing sidecar precedence over explicit width and magnification' do
      expect(app_for('--width=60', '--magnification=2', metadata: true).magnification).to eq(7.837)
    end

    it 'gives explicit magnification precedence over explicit width' do
      expect(app_for('--width=60', '--magnification=4').magnification).to eq(4.0)
    end

    it 'leaves an image uncalibrated without width, magnification or a sidecar' do
      app = app_for
      expect(app.magnification).to be_nil
      expect(app.width).to be_nil
    end

    it 'does not fall back to width when an existing sidecar lacks magnification' do
      prepare_image
      File.write(File.join(@work_dir, 'Dag340B1-Mg.txt'), "CM_TITLE uncalibrated\n")
      app = described_class.new(StringIO.new, ['--width=60', image_path])
      app.parse_option
      expect(app.magnification).to be_nil
    end
  end
end
