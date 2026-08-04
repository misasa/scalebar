require 'spec_helper'
require 'scalebar'

module Scalebar
describe Scalebar do
#		let(:output) { double('output').as_null_object }
	before(:each) do
		#@tmp_path = File.expand_path('../../../tmp',__FILE__)
		setup_empty_dir('tmp')
	end

	describe "#run with -h" do
		let(:cui){ Scalebar.new(myout, args)}
		let(:args){ ['-h'] }
		it "show help" do
			puts "-" * 30
			expect{cui.run}.to raise_error(SystemExit)
			puts "-" * 30
		end
	end


	describe "#length" do
		let(:cui){ Scalebar.new(myout, args) }
		let(:args){ [image_path] }
		let(:image_path){ 'tmp/Dag340B1-Mg.jpg' }
		let(:txt_path){ 'tmp/Dag340B1-Mg.txt' }
		let(:magnification){ 2.0 }
		before(:each) do
			setup_file(image_path)
			File.open(txt_path, 'w'){|f|
				f.puts sprintf("CM_MAG %.1f\n", magnification)
			}
			cui.parse_option
		end
		it { expect(cui.length_in_mm).to be_eql(60.0) }
		it { expect(cui.length_in_um).to be_eql(60000.0) }
		it { expect(cui.pixels_per_um).to be_eql(cui.length/60000.0) }
	end

	describe "#parse_txt" do
		let(:cui){ Scalebar.new(myout, args) }
		let(:args){ [image_path] }
		let(:image_path){ 'tmp/Dag340B1-Mg.jpg' }
		let(:txt_path){ 'tmp/Dag340B1-Mg.txt' }
		before(:each) do
			info_text =<<EOF
$CM_TITLE Dag340B1
$CM_SIGNAL Mg
$CM_MAG 7.837
$CM_FULL_SIZE 1914 1537
$CM_STAGE_POS 57.656 15.152 0.0 0.0 0.0 0
EOF
			File.open(txt_path, 'w'){|f|
				f.puts info_text
			}
			cui.parse_option
		end
		it { expect(cui.stage_position).to be_eql([57.656, 15.152]) }
		it { expect(cui.magnification).to be_eql(7.837) }
	end

	describe ".generate_absolute_ticks" do
	#generate_absolute_ticks(range_in_um, pixels_per_um, length, tick_in_um)
		subject{ Scalebar.generate_absolute_ticks(range_in_um, pixels_per_um, length, tick_in_um) } 
		let(:range_in_um){ [50000.009, 65311.99] }
		let(:pixels_per_um){ 0.125 }
		let(:length){ 1914 }
		let(:tick_in_um){ 500 }
		it {
			expect(subject).not_to be_nil
		}
	end

	describe "#run with image" do
		let(:cui){ Scalebar.new(myout, args) }
		let(:args){ [image_path] }
		let(:image_path){ 'tmp/Dag340B1-Mg.jpg' }
		let(:tex_path){ 'tmp/Dag340B1-Mg.tex' }

		before(:each) do
			setup_file(image_path)
		end

		it "not set magnification" do
			cui.run
			expect(cui.magnification).to be_nil
		end

		it "output tex without scalebar" do
			cui.run
			expect(File.open(tex_path).read).not_to match(/Magnification of image \|\S+\|/)
			expect(File.open(tex_path).read).not_to match(/line/)
		end

	end

	describe "#run with image and -m" do
		let(:cui){ Scalebar.new(myout, args) }
		let(:magnification){ 2.0 }
		let(:args){ [image_path, '-m', magnification.to_s] }
		let(:image_path){ 'tmp/Dag340B1-Mg.jpg' }
		let(:tex_path){ 'tmp/Dag340B1-Mg.tex' }

		before(:each) do
			setup_file(image_path)
			#allow(cui).to receive(:get_magnification)
		end

		it "set magnification" do
			cui.run
			expect(cui.magnification).to be_eql(magnification)
		end

		it "output tex with scalebar" do
			cui.run
			expect(File.open(tex_path).read).to match(/Magnification of image \|\S+\| relative to 12 cm is \|2.000\|/)
			expect(File.open(tex_path).read).to match(/line/)
		end


	end

	describe "#run with image and -w" do
		let(:cui){ Scalebar.new(myout, args) }
		let(:width){ 60.0 }
		let(:args){ [image_path, '-w', width.to_s] }
		let(:image_path){ 'tmp/Dag340B1-Mg.jpg' }
		let(:tex_path){ 'tmp/Dag340B1-Mg.tex' }

		before(:each) do
			setup_file(image_path)
		end

		it "set magnification" do
			cui.run
			expect(cui.magnification).to be_eql(120/width)
		end

		it "output tex with scalebar" do
			cui.run
			expect(File.open(tex_path).read).to match(/Magnification of image \|\S+\| relative to 12 cm is \|2.000\|/)
			expect(File.open(tex_path).read).to match(/line/)
		end
	end


	describe "#run with image and image.tex" do
		let(:cui){ Scalebar.new(myout, args) }
		let(:args){ [image_path] }
		let(:image_path){ 'tmp/Dag340B1-Mg.jpg' }
		let(:tex_path){ 'tmp/Dag340B1-Mg.tex' }

		before(:each) do
			setup_file(image_path)
			File.open(tex_path, 'w'){|f|
				f.puts "Hello World"
			}
#			allow(cui).to receive(:gets_magnification).and_return(2.0)
		end

		# it "require input of magnification" do
		# 	expect(cui).to receive(:gets_magnification).and_return(2.0)
		# 	cui.run
		# end

		it "should not overwrite image.tex" do
			cui.run
			expect(File.open(tex_path).read).to be_eql("Hello World\n")
		end
	end


	describe "#run with image and txt" do
		let(:cui){ Scalebar.new(myout, args) }
		let(:args){ [image_path] }
		let(:image_path){ 'tmp/Dag340B1-Mg.jpg' }
		let(:tex_path){ 'tmp/Dag340B1-Mg.tex' }
		let(:txt_path){ 'tmp/Dag340B1-Mg.txt' }

		before(:each) do
			setup_file(image_path)
			setup_file(txt_path)
		end

		it "generate tex" do
			cui.run
			expect(File.exist?(tex_path)).to be_truthy
		end


	end


	describe "#run with image and txt -g" do
		let(:cui){ Scalebar.new(myout, args) }
		let(:args){ [image_path, '-g', '1.0'] }
		let(:image_path){ 'tmp/Dag340B1-Mg.jpg' }
		let(:tex_path){ 'tmp/Dag340B1-Mg.tex' }
		let(:txt_path){ 'tmp/Dag340B1-Mg.txt' }

		before(:each) do
			setup_file(image_path)
			setup_file(txt_path)
		end

		it "call generate_tex_with_grid" do
			expect(cui).to receive(:generate_tex).with(1.0)
			cui.run
		end

		it "generate tex with grid" do
			cui.run
			expect(File.exist?(tex_path)).to be_truthy
			expect(File.open(tex_path).read).to match(/Grids of \|\S+\| micro meter pitch are drawn\./)
			expect(File.open(tex_path).read).to match(/multiput/)
		end
	end

	describe "#run with image -g without txt" do
		let(:cui){ Scalebar.new(myout, args) }
		let(:args){ [image_path, '-g', '1.0'] }
		let(:image_path){ 'tmp/Dag340B1-Mg.jpg' }
		let(:tex_path){ 'tmp/Dag340B1-Mg.tex' }

		before(:each) do
			setup_file(image_path)
#			allow(cui).to receive(:gets_magnification).and_return(7.84)
		end


		it "call generate_tex_with_grid" do
			expect(cui).to receive(:generate_tex).with(1.0)
			cui.run
		end

		it "generate tex without grid" do
			cui.run
			expect(File.exist?(tex_path)).to be_truthy
			expect(File.open(tex_path).read).not_to match(/Grids of \|\S+\| micro meter pitch are drawn\./)
			expect(File.open(tex_path).read).not_to match(/multiput/)
		end
	end

end
end
