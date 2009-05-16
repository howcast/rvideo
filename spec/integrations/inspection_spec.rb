require File.dirname(__FILE__) + "/../spec_helper"

module RVideo
  describe Inspector, "with boat.avi" do
    before :each do
      @i = Inspector.new :file => spec_file("boat.avi")
    end
    
    it "is valid" do
      assert @i.valid?
    end
    
    it "knows the bitrate" do
      assert_equal 2078, @i.bitrate
    end
    
    it "knows the bitrate units" do
      assert_equal "kb/s", @i.bitrate_units
    end
    
    it "gives the bitrate and units together" do
      assert_equal "2078 kb/s", @i.bitrate_with_units
    end
    
    it "knows the duration in milliseconds" do
      assert_equal 15160, @i.duration
    end
    
    it "gives the duration as a string with : separating units of time" do
      assert_equal "00:00:15.16", @i.raw_duration
    end
    
    ###
    
    it "knows the video codec" do
      assert_equal "mjpeg", @i.video_codec
    end
    
    it "knows the resolution" do
      assert_equal "320x240", @i.resolution
    end
    
    it "knows the width" do
      assert_equal 320, @i.width
    end
    
    it "knows the height" do
      assert_equal 240, @i.height
    end
    
    ###
    
    it "knows the audio codec" do
      assert_equal "adpcm_ima_wav", @i.audio_codec
    end
    
    it "knows the audio sample rate" do
      assert_equal 11025, @i.audio_sample_rate
    end
    
    it "knows the audio sample rate units" do
      assert_equal "Hz", @i.audio_sample_rate_units
    end
    
    it "gives the audio sample rate and units together" do
      assert_equal "11025 Hz", @i.audio_sample_rate_with_units
    end
    
    it "knows the audio channels" do
      assert_equal 1, @i.audio_channels
    end
    
    it "gives the audio channels as a string" do
      assert_equal "mono", @i.audio_channels_string
    end
    
    it "knows the audio bit rate" do
      assert_equal 44, @i.audio_bit_rate
    end
    
    it "knows the audio bit rate units" do
      assert_equal "kb/s", @i.audio_bit_rate_units
    end
    
    it "gives the audio bit rate with units" do
      assert_equal "44 kb/s", @i.audio_bit_rate_with_units
    end
    
    it "knows the audio sample bit depth" do
      assert_equal 16, @i.audio_sample_bit_depth
    end
    
    # Input #0, avi, from 'spec/files/boat.avi':
    #   Duration: 00:00:15.16, start: 0.000000, bitrate: 2078 kb/s
    #     Stream #0.0: Video: mjpeg, yuvj420p, 320x240, 15.10 tbr, 15.10 tbn, 15.10 tbc
    #     Stream #0.1: Audio: adpcm_ima_wav, 11025 Hz, mono, s16, 44 kb/s
  end
  
  describe Inspector, "with kites.mp4" do
    before :each do
      @i = Inspector.new :file => spec_file("kites.mp4")
    end
    
    it "knows the pixel aspect ratio" do
      assert_equal "1:1", @i.pixel_aspect_ratio
    end
    
    it "knows the display aspect ratio" do
      assert_equal "11:9", @i.display_aspect_ratio
    end
  end
end
