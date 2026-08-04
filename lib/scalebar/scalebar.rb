module Scalebar

	class Scalebar
		attr_accessor :argv, :params, :image_path, :basename, :length, :output_path, :magnification, :stage_position


	  def self.generate_absolute_ticks(range_in_um, pixels_per_um, length, tick_in_um)
	    a_um = (range_in_um[1] -  range_in_um[0]).abs
	    tick_min_um = (range_in_um[0]/tick_in_um).floor*tick_in_um
	    tick_max_um = (range_in_um[1]/tick_in_um).ceil*tick_in_um
	    a = (a_um * pixels_per_um).ceil
	    a_prop = a/length.to_f * 100
	    tick_in_pixels = pixels_per_um * tick_in_um
	    tick_in_prop = tick_in_pixels/length.to_f * 100
	    num_ticks = (a_prop/tick_in_prop).ceil
	    s = - (range_in_um[0] - tick_min_um) * pixels_per_um / length.to_f * 100
	    ticks = []
	    ticks_in_um = []
	    ((tick_min_um/tick_in_um).to_i).upto((tick_max_um/tick_in_um).to_i) do |t|
	      ticks_in_um << t * tick_in_um
	    end
	    ticks_in_um.each_with_index do |t, idx|
	      h = Hash.new
	      h[:um] = t
	      h[:prop] = s + idx * tick_in_prop
	      ticks << h
	    end
	    return ticks
	  end

	  def self.get_alphabet(n)
	    ('A'[0].ord + n).chr
	  end

	  def initialize(output, argv = ARGV)
	    @io = output
	    @params = cmd_options(argv)
	    @argv = argv
	  end

	  def cmd_options(argv=ARGV)
	    Optimist::options(argv) do
	        # banner "  Usage: scalebar imagefile"
	      banner  <<"EOS"
NAME
  #{File.basename($0, '.*')} - Put scalebar on image

SYNOPSIS
  #{File.basename($0, '.*')} [options] imagefile

HISTORY
  June 14, 2016: Document revised by TK
  April 24, 2015: Add grid capability by YY
  April 23, 2015: Add online documentation by TK
  April 10, 2015: Rename scalebar as #{File.basename($0, '.*')} by MY

DESCRIPTION
  Put scalebar on image.  Create a LaTeX file that includes
  scale bar or scale grids with indexes.

  On launch, this program looks for `imagefile.txt', which is
  image-property file created by JEOL JSM-7001F, that is often
  referred as an imajeoletry file.  Based on the information, a LaTeX
  file that includes the image file with scale bar is created.  In a
  case where no `imagefile.txt' was found, feed width of image by
  yourself.

EXAMPLE
  $ ls
  Suiton.png Suiton.txt
  $ image-scalebar --grid=1 Suiton.png
  writing |./Suiton.tex|...
  $ ls
  Suiton.png Suiton.txt Suiton.tex

TIPS
  When you want to utilize imageometry, call `spots-warp'.  Create
  stagelist.txt and estimate width of an image.  The detail steps are
  shown below.  Note that this only works when edge of x is longer
  than edge of y.

  CMD> dir
  mnt-NM-61.jpg   mnt-NM-61.geo
  mnt-NM-61_.jpg  mnt-NM-61_.geo  stagelist.txt
  CMD> type stagelist.txt
  Class	Name	X-Locate	Y-Locate	Data
  0	x=-50	-50	0
  0	x=+50	50	0
  CMD> spots-warp stagelist.txt -a mnt-NM-61_.geo
  Class	Name	X-Locate	Y-Locate	Data
  0	x=-50	-6709.499	512.209
  0	x=+50	17471.030	512.209
  R> (17471.030-(-6709.499))/1000
  [1] 24.18053
  CMD> image-scalebar --width 24.18053 --grid=1 mnt-NM-61_.jpg
  writing to |./mnt-NM-61_.tex|...

SEE ALSO
  spots0
  spots.m
  spots-warp in gem package -- multi_stage <https://gitlab.misasa.okayama-u.ac.jp/gems/multi_stage>
  https://github.com/misasa/scalebar
  https://github.com/misasa/scalebar/blob/master/bin/image-scalebar

TECHNICAL NOTE
  JEOL defines magnification relative to 12 cm width.

IMPLEMENTATION
  Copyright (C) 2013-2020 Okayama University
  License GPLv3+: GNU GPL version 3 or later

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3, or (at your option)
  any later version.

OPTIONS
EOS
	#  -g, --grid=<pitch>         Impose grid with pitch in mm (not implemented)
	  #      opt :output, "Specify output filename", :type => :string
	      opt :magnification, "Specify magnification", :type => :float
	      opt :width, "Specify width in mm", :type => :float
	      opt :grid, "Impose grid with pitch in mm", :type => :float
	  #      opt :yes, "Answer yes for all questions", :type => :boolean
	    end
	  end

	  def normalized_dimensions
			Dimensions.dimensions(@image_path)
	  end

	  def self.normalized_dimensions(filename)
	  	d = self.dimensions(filename)
	  	l = self.length(filename)
	  	[d[0]/l.to_f * 100, d[1]/l.to_f * 100]
	  end

	 	def width
	 		return unless magnification
	 		1000 * 12.0 * 10.0 / magnification
	 	end

	 	def image_file
	 		File.basename(image_path, ".*")
	 	end

	 	def dimensions
	 		@dimensions = Dimensions.dimensions(image_path) unless @dimensions
	 		@dimensions
	 	end

	 	def length
	 		@length = dimensions.max unless @length
	 		@length
	 	end

	 	def normalized_dimensions
	 		@normalized_dimensions = [dimensions[0]/length.to_f * 100, dimensions[1]/length.to_f * 100] unless @normalized_dimensions
	 		@normalized_dimensions
	 	end

	 	def scale_length_on_stage
	# 		@scale_length_on_stage = 10 ** (Math::log10(width).round - 1) unless @scale_length_on_stage
	 		@scale_length_on_stage = 10 ** (Math::log10(width).floor) unless @scale_length_on_stage
	 		@scale_length_on_stage
	 	end

	 	def scale_length_on_image
			@scale_length_on_image = scale_length_on_stage / width * dimensions[0] unless @scale_length_on_image
			@scale_length_on_image
	 	end

	 	def info_path
	 		File.join(File.dirname(image_path), basename + ".txt")
	 	end

		def textfile2array(path)
			a = []
			File.open(path).each do |line|
			  a << line.chomp!
			end
			a
		end


	 	def parse_info
			STDERR.puts "reading |#{info_path}|..."
	    info = File.open(info_path).read
	    if m = /CM_MAG (.+)/.match(info)
	      @magnification = m[1].to_f
	    end

	    if m = /CM_FULL_SIZE (\S+) (\S+)/.match(info)
	      @full_size = [m[1].to_i, m[2].to_i]
	    end

	    if m = /CM_STAGE_POS (\S+) (\S+) (\S+) (\S+) (\S+) 0/.match(info)
	      @stage_position = [m[1].to_f, m[2].to_f]
	    end
	 	end

	  def gets_magnification
	    STDERR.print "width of image in mm: "
	    input = STDIN.gets.chomp
	 	  #@magnification = 12.0 * 10.0 / input.to_f
	    #@magnification = input.to_f
	    12.0 * 10.0 / input.to_f
	  end

	  def length_in_mm
	    12.0 * 10 / magnification
	  end

	  def length_in_um
	    length_in_mm * 1000
	  end

	  def pixels_per_um
	    length/length_in_um
	  end

	  def width_in_um
	    dimensions[0]/pixels_per_um
	  end

	  def locate
	    [@stage_position[0] * 1000, @stage_position[1] * 1000]
	  end

	  def x_range
	    origin = locate[0]
	    l = width_in_um / 2.0
	    [origin - l, origin + l]
	  end

	  def height_in_um
	    dimensions[1]/pixels_per_um
	  end

	  def y_range
	    origin = locate[1]
	    l = height_in_um / 2.0
	    [origin - l, origin + l]
	  end

	  def parse_option
	    Optimist::die "invalid args" if argv.size < 1
	    @image_path = argv.shift
	    @dirname = File.dirname(@image_path)
	    @basename = File.basename(@image_path, ".*")
	    @extname = File.extname(@image_path)
	    @output_path = File.join(@dirname,@basename + ".tex")

	    @magnification = nil

	    if File.exist?(info_path)
	      parse_info
	    elsif params[:magnification]
	      @magnification = params[:magnification]
	    elsif params[:width]
	      @magnification = 120 / params[:width]
	    # else
	    #   @magnification = gets_magnification
	    end

	    unless @stage_position
	      @stage_position = [0, 0]
	    end

	    @tick_in_mm = 1.0
	    if params[:grid]
	      @tick_in_mm = params[:grid]
	    end
	#    Trollop::die "specify magnification" unless magnification
	  end

	  def run
	    parse_option
	    if File.exist?(output_path)
	      STDERR.puts "|#{output_path}| already exists."
	    else
	      generate_tex(params[:grid])
	    end
	  end

	  def get_timestamp
	    timestamp = Time.now.strftime("%d-%b-%Y %H:%M:%S")
	  end

	  def format(float, fmt = "%.2f")
	    sprintf(fmt,float)
	  end

	  def tick_in_um
	    @tick_in_mm * 1000
	  end


	  def generate_tex(grid_in_mm = nil)
	    timestamp = get_timestamp
	    STDERR.puts "writing to |#{output_path}|..."
	    io = File.open(output_path, "w")
	    io.puts '%%%'
	    io.puts '%%% Generated by |image-scalebar| on ' + timestamp
	    if magnification
	      io.puts '%%% ' + sprintf("Magnification of image |%s| relative to 12 cm is |%.3f|", basename, magnification )
	      io.puts '%%% ' + sprintf("Scalebar of |%.0f| micro meter is drawn.", scale_length_on_stage )
	      if grid_in_mm
	        io.puts '%%% ' + sprintf("Grids of |%.0f| micro meter pitch are drawn.", grid_in_mm * 1000 )
	      end
	    end
	    io.puts '%%%'
	    io.puts '% \\documentclass[12pt]{article}'
	    io.puts '% \\usepackage[margin=0.5in,a4paper]{geometry}'
	    io.puts '% \\usepackage{color,pmlatex}'
	    io.puts '% \\usepackage{pict2e}'
	    io.puts '% \\begin{document}'
	    io.puts '% \\begin{figure}[htbp]'
	    io.puts '% \\centering'
	    io.puts '% \\vspace{1ex}'
	    io.puts sprintf('\\begin{overpic}[width=0.49\\textwidth]{%s}', image_file)
	    io.puts sprintf('  \\put(1,74){\\colorbox{white}{(\\sublabel{%s}) \\nolinkurl{%s}}}', basename, basename)
	    io.puts '  % ' + sprintf('(\\subref{%s}) \\nolinkurl{%s}', basename, basename)
	    io.puts sprintf('  \\put(1,3){\\colorbox{white}{\\bf \\Huge \\nolinkurl{%s}}}', basename)
	    if magnification
	  # io.puts '  \\color{red}'
	      io.puts '  \\color{white}'
	      io.puts sprintf("  \\linethickness{4pt}")
	      io.puts sprintf("  \\put(1,1){\\line(1,0){%.1f}}", scale_length_on_image/length.to_f*100 )
	      io.puts '  \\color{black}'
	      io.puts sprintf("  \\linethickness{2pt}")
	      io.puts sprintf("  \\put(1,1){\\line(1,0){%.1f}}", scale_length_on_image/length.to_f*100 )
	      if grid_in_mm
	        io.puts draw_grids
	      end
	    end
	    io.puts '\\end{overpic}'
	    if magnification
	      io.puts '% ' + sprintf('\\caption{An image of \\nolinkurl{%s} with scale on %s.}', basename, timestamp)
	    else
	      io.puts '% ' + sprintf('\\caption{An image of \\nolinkurl{%s} on %s.}', basename, timestamp)
	    end
	    io.puts '% ' + sprintf('\\label{spots:%s at %s}', basename, timestamp)
	    io.puts '% \\end{figure}'
	    io.puts '% \\end{document}'
	    io.close
	  end

	  def draw_grids
	    width_in_prop = dimensions[0] / length.to_f * 100
	    height_in_prop = dimensions[1] / length.to_f * 100

	    tick_in_pixels = pixels_per_um * tick_in_um
	    tick_in_prop = tick_in_pixels/length.to_f * 100

	    x_ticks = self.class.generate_absolute_ticks(x_range, pixels_per_um, length, tick_in_um)
	    y_ticks = self.class.generate_absolute_ticks(y_range, pixels_per_um, length, tick_in_um)

	    text_color = "black"
	    line_color = "white"
	    tex = []
	    tex << "\n  % draw grids"
	    tex << "  \\linethickness{0.1pt}"
	    tex << "  \\multiput(#{format(x_ticks[1][:prop])},0.0)(#{format(tick_in_prop)}, 0.0){#{x_ticks.size - 2}}{\\textcolor{#{line_color}}{ \\line(0,1){ #{format(height_in_prop)} }} }"
	    tex << "  \\multiput(0.0, #{format(y_ticks[1][:prop])})(0.0, #{format(tick_in_prop)}){#{y_ticks.size - 2}}{\\textcolor{#{line_color}}{ \\line(1,0){ #{format(width_in_prop)} }} }"
	    tex << "\n  % draw scale on rulers"
	    tex << "  \\linethickness{0.5pt}"
	    tex << "  \\multiput(#{format(x_ticks[0][:prop], '%.3f') }, 0.0)(#{format(tick_in_prop, '%.3f')}, 0.0){#{x_ticks.size}}{\\textcolor{#{line_color}}{ \\line(0,1){ #{format(tick_in_prop/10)} }} }"
	    tex << "  \\multiput(0.0, #{format(y_ticks[0][:prop], '%.3f') })(0.0, #{format(tick_in_prop, '%.3f')}){#{y_ticks.size}}{\\textcolor{#{line_color}}{ \\line(1,0){ #{format(tick_in_prop/10)} }} }"
	    tex << "\n  % draw 1/10 scale on rulers"
	    tex << "  \\linethickness{0.1pt}"
	    tex << "  \\multiput(#{format(x_ticks[1][:prop] - tick_in_prop ,'%.3f') },0.0)(#{format(tick_in_prop/10, '%.3f')}, 0.0){#{(x_ticks.size - 1) * 10}}{\\textcolor{#{line_color}}{ \\line(0,1){ #{format(tick_in_prop/20)} }} }"
	    tex << "  \\multiput(0.0, #{format(y_ticks[1][:prop] - tick_in_prop, '%.3f') })(0.0, #{format(tick_in_prop/10, '%.3f')}){#{(y_ticks.size - 1) * 10}}{\\textcolor{#{line_color}}{ \\line(1,0){ #{format(tick_in_prop/20)} }} }"
	    tex << "\n  % define grid name"
	    x_ticks[0...-1].each_with_index do |x_tick, index|
	      tex << "  \\put(#{format(x_tick[:prop])},#{format(height_in_prop + tick_in_prop/4)}){\\textcolor{#{text_color}}{\\makebox(#{format(tick_in_prop)},#{format(tick_in_prop/2)}){\\textbf{ #{self.class.get_alphabet(index)} }}}}"
	    end
	    y_ticks.reverse[1..-1].each_with_index do |y_tick, index|
	      tex << "  \\put(#{format(width_in_prop)},#{format(y_tick[:prop])}){\\textcolor{#{text_color}}{\\makebox(#{format(tick_in_prop/2)},#{format(tick_in_prop)})[l]{\\textbf{ #{index + 1} }}}}"
	    end
	    tex << "\n  % define x y in mm"
	    x_ticks[1...-1].each_with_index do |x_tick, index|
	      tex << "  \\put(#{format(x_tick[:prop] - tick_in_prop/2)},#{format(-tick_in_prop/2)}){\\textcolor{#{text_color}}{\\makebox(#{format(tick_in_prop)},#{format(tick_in_prop/4)}){ \\scriptsize $#{format(x_tick[:um]/1000, '%.0f')}$ }}}"
	    end
	    y_ticks[1...-1].reverse.each_with_index do |y_tick, index|
	      tex << "  \\put(#{format(- tick_in_prop/4)},#{format(y_tick[:prop] - tick_in_prop/2)}){\\textcolor{#{text_color}}{\\makebox(#{format(tick_in_prop/4)},#{format(tick_in_prop)})[r]{ \\scriptsize $#{format(y_tick[:um]/1000, '%.0f')}$ }}}"
	    end
	    tex << "  \\put(#{format(tick_in_prop)},#{format(-tick_in_prop * 1.5)}){\\textcolor{#{text_color}}{mosaic ($\\times$#{format(magnification)})}}"
	    tex.join("\n")
	  end


	end

end
