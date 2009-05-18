require File.dirname(__FILE__) + '/../spec_helper'

def setup_ffmpeg_spec
  @options = {
    :input_file => spec_file("kites.mp4"),
    :output_file => "bar",
    :width => "320", :height => "240"
  }
  @simple_avi = "ffmpeg -i $input_file$ -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 $resolution$ -y $output_file$"
  @ffmpeg = RVideo::Tools::Ffmpeg.new(@simple_avi, @options)
end

def parsing_result(result_fixture_key)
  lambda { @ffmpeg.send(:parse_result, ffmpeg_result(result_fixture_key)) }
end

module RVideo
  module Tools
  
    describe Ffmpeg do
      before do
        setup_ffmpeg_spec
      end
      
      it "should initialize with valid arguments" do
        @ffmpeg.class.should == Ffmpeg
      end
      
      it "should have the correct tool_command" do
        @ffmpeg.tool_command.should == 'ffmpeg'
      end
      
      it "should call parse_result on execute, with a ffmpeg result string" do
        @ffmpeg.should_receive(:parse_result).once.with /\AFFmpeg version/
        @ffmpeg.execute
      end
      
      it "should mixin AbstractTool" do
        Ffmpeg.included_modules.include?(AbstractTool::InstanceMethods).should be_true
      end
      
      it "should set supported options successfully" do
        @ffmpeg.options[:resolution].should == @options[:resolution]
        @ffmpeg.options[:input_file].should == @options[:input_file]
        @ffmpeg.options[:output_file].should == @options[:output_file]
      end
      
    end
    
    describe Ffmpeg, " magic variables" do
      before do
        @options = {
          :input_file  => spec_file("boat.avi"),
          :output_file => "test"
        }
        
        Ffmpeg.video_bit_rate_parameter = Ffmpeg::DEFAULT_VIDEO_BIT_RATE_PARAMETER
      end
      
      it 'supports copying the originsl :fps' do
        @options.merge! :fps => "copy"
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame $fps$ -s 320x240 -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 15.10 -s 320x240 -y '#{@options[:output_file]}'"
      end
      
      it 'supports :width and :height options to build :resolution' do
        @options.merge! :width => "640", :height => "360"
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 $resolution$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 -s 640x360 -y '#{@options[:output_file]}'"
      end
      
      it 'supports calculated :height' do
        @options.merge! :width => "640"
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 $resolution$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 -s 640x480 -y '#{@options[:output_file]}'"
      end
      
      it 'supports calculated :width' do
        @options.merge! :height => "360"
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 $resolution$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 -s 480x360 -y '#{@options[:output_file]}'"
      end
      
      it 'supports :resolution' do
        @options.merge! :resolution => "640x360"
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 $resolution$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 -s 640x360 -y '#{@options[:output_file]}'"
      end
      
      ###
      
      it 'supports :video_bit_rate' do
        @options.merge! :video_bit_rate => 666
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $video_bit_rate$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -b 666k -y '#{@options[:output_file]}'"
      end
      
      it "supports :video_bit_rate and configurable command flag" do
        Ffmpeg.video_bit_rate_parameter = "v"
        @options.merge! :video_bit_rate => 666
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $video_bit_rate$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -v 666k -y '#{@options[:output_file]}'"
      end
      
      ###
      
      it "supports :video_bit_rate_tolerance" do
        @options.merge! :video_bit_rate_tolerance => 666
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $video_bit_rate_tolerance$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -bt 666k -y '#{@options[:output_file]}'"
      end
      
      ###
      
      it "supports :video_bit_rate_max and :video_bit_rate_min" do
        @options.merge! :video_bit_rate => 666, :video_bit_rate_min => 666, :video_bit_rate_max => 666
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $video_bit_rate$ $video_bit_rate_min$ $video_bit_rate_max$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -b 666k -minrate 666k -maxrate 666k -y '#{@options[:output_file]}'"
      end

      it "supports :deinterlace => true" do
        @options.merge! :deinterlace => true
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $deinterlace$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -deinterlace -y '#{@options[:output_file]}'"
      end

      it "handles :deinterlace => false correct" do
        @options.merge! :deinterlace => false
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $deinterlace$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}'  -y '#{@options[:output_file]}'"
      end
      
      ###
      
      # TODO for these video quality specs we might want to show that the expected
      # bitrate is calculated based on dimensions and framerate so you can better 
      # understand it without going to the source.
      
      it "supports :video_quality => 'low'" do
        @options.merge! :video_quality => "low"
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $video_quality$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -b 96k -crf 30 -me zero -subq 1 -refs 1 -threads auto -y '#{@options[:output_file]}'"
      end
      
      it "supports :video_quality => 'medium'" do
        @options.merge! :video_quality => "medium"
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $video_quality$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -b 128k -crf 22 -flags +loop -cmp +sad -partitions +parti4x4+partp8x8+partb8x8 -flags2 +mixed_refs -me hex -subq 3 -trellis 1 -refs 2 -bf 3 -b_strategy 1 -coder 1 -me_range 16 -g 250 -y '#{@options[:output_file]}'"
      end
      
      it "supports :video_quality => 'high'" do
        @options.merge! :video_quality => "high"
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $video_quality$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -b 322k -crf 18 -flags +loop -cmp +sad -partitions +parti4x4+partp8x8+partb8x8 -flags2 +mixed_refs -me full -subq 6 -trellis 1 -refs 3 -bf 3 -b_strategy 1 -coder 1 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -y '#{@options[:output_file]}'"
      end
      
      ###
      
      it "supports :video_quality => 'low' with arbitrary :video_bit_rate" do
        @options.merge! :video_quality => "low", :video_bit_rate => 666
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $video_quality$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -b 666k -crf 30 -me zero -subq 1 -refs 1 -threads auto -y '#{@options[:output_file]}'"
      end
      
      it "supports :video_quality => 'medium' with arbitrary :video_bit_rate" do
        @options.merge! :video_quality => "medium", :video_bit_rate => 666
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $video_quality$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -b 666k -crf 22 -flags +loop -cmp +sad -partitions +parti4x4+partp8x8+partb8x8 -flags2 +mixed_refs -me hex -subq 3 -trellis 1 -refs 2 -bf 3 -b_strategy 1 -coder 1 -me_range 16 -g 250 -y '#{@options[:output_file]}'"
      end
      
      it "supports :video_quality => 'high' with arbitrary :video_bit_rate" do
        @options.merge! :video_quality => "high", :video_bit_rate => 666
        ffmpeg = Ffmpeg.new("ffmpeg -i $input_file$ $video_quality$ -y $output_file$", @options)
        ffmpeg.command.should == "ffmpeg -i '#{@options[:input_file]}' -b 666k -crf 18 -flags +loop -cmp +sad -partitions +parti4x4+partp8x8+partb8x8 -flags2 +mixed_refs -me full -subq 6 -trellis 1 -refs 3 -bf 3 -b_strategy 1 -coder 1 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -y '#{@options[:output_file]}'"
      end

      it "should support passthrough scaled and rounded height" do
        options = {:input_file => spec_file("kites.mp4"), :output_file => "bar", :width => "640"}
        command = "ffmpeg -i $input_file$ -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 $resolution$ -y $output_file$"
        ffmpeg = Ffmpeg.new(command, options)
        ffmpeg.command.should == "ffmpeg -i '#{options[:input_file]}' -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 -s 640x528 -y 'bar'"
      end

      it "should support passthrough scaled and rounded width" do
        options = {:input_file => spec_file("kites.mp4"), :output_file => "bar", :height => "360"}
        command = "ffmpeg -i $input_file$ -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 $resolution$ -y $output_file$"
        ffmpeg = Ffmpeg.new(command, options)
        ffmpeg.command.should == "ffmpeg -i '#{options[:input_file]}' -ar 44100 -ab 64 -vcodec xvid -acodec libmp3lame -r 29.97 -s 448x360 -y 'bar'"
      end
    end
    
    describe Ffmpeg, " when parsing a result" do
      before do
        setup_ffmpeg_spec
        
        @result  = ffmpeg_result(:result1)
        @result2 = ffmpeg_result(:result2)
        @result3 = ffmpeg_result(:result3)
        @result4 = ffmpeg_result(:result4)
      end
      
      it "should create correct result metadata" do
        @ffmpeg.send(:parse_result, @result).should be_true
        @ffmpeg.frame.should == '4126'
        @ffmpeg.output_fps.should be_nil
        @ffmpeg.q.should == '31.0'
        @ffmpeg.size.should == '5917kB'
        @ffmpeg.time.should == '69.1'
        @ffmpeg.output_bitrate.should == '702.0kbits/s'
        @ffmpeg.video_size.should == "2417kB"
        @ffmpeg.audio_size.should == "540kB"
        @ffmpeg.header_size.should == "0kB"
        @ffmpeg.overhead.should == "100.140277%"
        @ffmpeg.psnr.should be_nil
      end
      
      it "should create correct result metadata (2)" do
        @ffmpeg.send(:parse_result, @result2).should be_true
        @ffmpeg.frame.should == '584'
        @ffmpeg.output_fps.should be_nil
        @ffmpeg.q.should == '6.0'
        @ffmpeg.size.should == '708kB'
        @ffmpeg.time.should == '19.5'
        @ffmpeg.output_bitrate.should == '297.8kbits/s'
        @ffmpeg.video_size.should == "49kB"
        @ffmpeg.audio_size.should == "153kB"
        @ffmpeg.header_size.should == "0kB"
        @ffmpeg.overhead.should == "250.444444%"
        @ffmpeg.psnr.should be_nil
      end
      
      it "should create correct result metadata (3)" do
        @ffmpeg.send(:parse_result, @result3).should be_true
        @ffmpeg.frame.should == '273'
        @ffmpeg.output_fps.should == "31"
        @ffmpeg.q.should == '10.0'
        @ffmpeg.size.should == '398kB'
        @ffmpeg.time.should == '5.9'
        @ffmpeg.output_bitrate.should == '551.8kbits/s'
        @ffmpeg.video_size.should == "284kB"
        @ffmpeg.audio_size.should == "92kB"
        @ffmpeg.header_size.should == "0kB"
        @ffmpeg.overhead.should == "5.723981%"
        @ffmpeg.psnr.should be_nil
      end
      
      it "should create correct result metadata (4)" do
        @ffmpeg.send(:parse_result, @result4).should be_true
        @ffmpeg.frame.should be_nil
        @ffmpeg.output_fps.should be_nil
        @ffmpeg.q.should be_nil
        @ffmpeg.size.should == '1080kB'
        @ffmpeg.time.should == '69.1'
        @ffmpeg.output_bitrate.should == '128.0kbits'
        @ffmpeg.video_size.should == "0kB"
        @ffmpeg.audio_size.should == "1080kB"
        @ffmpeg.header_size.should == "0kB"
        @ffmpeg.overhead.should == "0.002893%"
        @ffmpeg.psnr.should be_nil
      end
      
      it "ffmpeg should calculate PSNR if it is turned on" do
        @ffmpeg.send(:parse_result, @result.gsub("Lsize=","LPSNR=Y:33.85 U:37.61 V:37.46 *:34.77 size=")).should be_true
        @ffmpeg.psnr.should == "Y:33.85 U:37.61 V:37.46 *:34.77"
      end
    end
    
    context Ffmpeg, "result parsing should raise an exception" do
      before do
        setup_ffmpeg_spec
        @results = load_fixture :ffmpeg_results
      end
      
      specify "when a param is missing a value" do
        parsing_result(:param_missing_value).
          should raise_error(TranscoderError::InvalidCommand, /Expected .+ for .+ but found: .+/)
      end
      
      specify "when codec not supported" do
        parsing_result(:amr_nb_not_supported).
          should raise_error(TranscoderError::InvalidFile, "Codec amr_nb not supported by this build of ffmpeg")
      end
      
      specify "when not passed a command" do
        parsing_result(:missing_command).
          should raise_error(TranscoderError::InvalidCommand, "must pass a command to ffmpeg")
      end
      
      specify "when given a broken command" do
        parsing_result(:broken_command).
          should raise_error(TranscoderError::InvalidCommand, "Unable for find a suitable output format for 'foo'")
      end
      
      specify "when the output file has no streams" do
        parsing_result(:output_has_no_streams).
          should raise_error(TranscoderError, /Output file does not contain.*stream/)
      end
      
      specify "when given a missing input file" do
        parsing_result(:missing_input_file).
          should raise_error(TranscoderError::InvalidFile, /I\/O error: .+/)
      end
      
      specify "when given a file it can't handle"
      
      specify "when cancelled halfway through"
    
      specify "when receiving unexpected results" do
        parsing_result(:unexpected_results).
          should raise_error(TranscoderError::UnexpectedResult, 'foo - bar')
      end
      
      specify "with an unsupported codec" do
        @ffmpeg.original = Inspector.new(:raw_response => files('kites2'))
        
        parsing_result(:unsupported_codec).
          should raise_error(TranscoderError::InvalidFile, /samr/)
      end
      
      specify "when a stream cannot be written" do
        parsing_result(:unwritable_stream).
          should raise_error(TranscoderError, /flv doesnt support.*incorrect codec/)
      end
      
    end
  end
end
