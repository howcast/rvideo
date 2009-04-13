module RVideo # :nodoc:
  # To inspect a video or audio file, initialize an Inspector object.
  # 
  #   file = RVideo::Inspector.new(options_hash)
  # 
  # Inspector accepts three options: file, raw_response, and ffmpeg_binary.
  # Either raw_response or file is required; ffmpeg binary is optional. 
  # 
  # :file is a path to a file to be inspected.
  # 
  # :raw_response is the full output of "ffmpeg -i [file]". If the
  # :raw_response option is used, RVideo will not actually inspect a file;
  # it will simply parse the provided response. This is useful if your
  # application has already collected the ffmpeg -i response, and you don't
  # want to call it again.
  # 
  # :ffmpeg_binary is an optional argument that specifies the path to the
  # ffmpeg binary to be used. If a path is not explicitly declared, RVideo
  # will assume that ffmpeg exists in the Unix path. Type "which ffmpeg" to
  # check if ffmpeg is installed and exists in your operating system's path.
  class Inspector
    attr_reader :filename, :path, :full_filename, :raw_response, :raw_metadata
    
    attr_accessor :ffmpeg_binary
    
    def initialize(options = {})
      if not (options[:raw_response] or options[:file])
        raise ArgumentError, "Must supply either an input file or a pregenerated response"
      end
      
      if options[:raw_response]
        initialize_with_raw_response(options[:raw_response])
      elsif options[:file]
        initialize_with_file(options[:file], options[:ffmpeg_binary])
      end

      metadata = /(Input \#.*)\n.+\n\Z/m.match(@raw_response)
      
      if /Unknown format/i.match(@raw_response) || metadata.nil?
        @unknown_format = true
      elsif /Duration: N\/A/im.match(@raw_response)
        # in this case, we can at least still get the container type
        @unreadable_file = true
        @raw_metadata = metadata[1]
      else
        @raw_metadata = metadata[1]
      end
    end
    
    def initialize_with_raw_response(raw_response)
      @raw_response = raw_response
    end
    
    def initialize_with_file(file, ffmpeg_binary = nil)
      if ffmpeg_binary
        @ffmpeg_binary = ffmpeg_binary
        if not FileTest.exist?(@ffmpeg_binary)
          raise "ffmpeg could not be found (trying #{@ffmpeg_binary})" 
        end
      else
        # assume it is in the unix path
        if not FileTest.exist?(`which ffmpeg`.chomp)
          raise "ffmpeg could not be found (expected ffmpeg to be found in the Unix path)"
        end
        @ffmpeg_binary = "ffmpeg"
      end
      
      if not FileTest.exist?(file.gsub('"',''))
        raise TranscoderError::InputFileNotFound, "File not found (#{file})"
      end
      
      @full_filename = file
      @filename      = File.basename(@full_filename)
      @path          = File.dirname(@full_filename)
      
      @raw_response = `#{@ffmpeg_binary} -i #{@full_filename.shell_quoted} 2>&1`
    end
    
    # Returns true if the file can be read successfully. Returns false otherwise.
    def valid?
      not invalid?
    end
    
    # Returns false if the file can be read successfully. Returns false otherwise.
    def invalid?
      @unknown_format or @unreadable_file
    end
    
    # True if the format is not understood ("Unknown Format")
    def unknown_format?
      @unknown_format ? true : false
    end
    
    # True if the file is not readable ("Duration: N/A, bitrate: N/A")
    def unreadable_file?
      @unreadable_file ? true : false
    end
    
    # Does the file have an audio stream?
    def audio?
      not audio_match.nil?
    end
    
    # Does the file have a video stream?
    def video?
      not video_match.nil?
    end
    
    # Returns the version of ffmpeg used, In practice, this may or may not be 
    # useful.
    #
    # Examples:
    #
    #   SVN-r6399
    #   CVS
    #
    def ffmpeg_version
      @ffmpeg_version = @raw_response.split("\n").first.split("version").last.split(",").first.strip
    end
    
    # Returns the configuration options used to build ffmpeg.
    #
    # Example:
    #
    #   --enable-mp3lame --enable-gpl --disable-ffplay --disable-ffserver
    #     --enable-a52 --enable-xvid
    #
    def ffmpeg_configuration 
      /(\s*configuration:)(.*)\n/.match(@raw_response)[2].strip
    end
    
    # Returns the versions of libavutil, libavcodec, and libavformat used by
    # ffmpeg.
    #
    # Example:
    #
    #   libavutil version: 49.0.0
    #   libavcodec version: 51.9.0
    #   libavformat version: 50.4.0
    #
    def ffmpeg_libav
      /^(\s*lib.*\n)+/.match(@raw_response)[0].split("\n").each {|l| l.strip! }
    end
    
    # Returns the build description for ffmpeg.
    #
    # Example:
    #
    #   built on Apr 15 2006 04:58:19, gcc: 4.0.1 (Apple Computer, Inc. build
    #     5250)
    #
    def ffmpeg_build
      /(\n\s*)(built on.*)(\n)/.match(@raw_response)[2]
    end
    
    # Returns the container format for the file. Instead of returning a single
    # format, this may return a string of related formats.
    #
    # Examples:
    #
    #   "avi"
    #
    #   "mov,mp4,m4a,3gp,3g2,mj2"
    #
    def container
      return nil if @unknown_format
      /Input \#\d+\,\s*(\S+),\s*from/.match(@raw_metadata)[1]
    end
    
    # The duration of the movie, as a string.
    #
    # Example:
    #
    #   "00:00:24.4"  # 24.4 seconds
    #
    def raw_duration
      return nil unless valid?
      /Duration:\s*([0-9\:\.]+),/.match(@raw_metadata)[1]
    end
    
    # The duration of the movie in milliseconds, as an integer.
    #
    # Example: 
    #
    #   24400         # 24.4 seconds
    #
    # Note that the precision of the duration is in tenths of a second, not 
    # thousandths, but milliseconds are a more standard unit of time than
    # deciseconds.
    #
    def duration
      return nil unless valid?
      
      units = raw_duration.split(":")
      (units[0].to_i * 60 * 60 * 1000) + (units[1].to_i * 60 * 1000) + (units[2].to_f * 1000).to_i
    end
    
    # The bitrate of the movie.
    #
    # Example:
    #   
    #  3132
    #
    def bitrate
      return nil unless valid?
      bitrate_match[1].to_i
    end
    
    # The bitrate units used. In practice, this may always be kb/s.
    #
    # Example:
    #   
    #   "kb/s"
    #
    def bitrate_units
      return nil unless valid?
      bitrate_match[2]
    end
    
    def bitrate_with_units
      "#{bitrate} #{bitrate_units}"
    end
    
    def audio_bit_rate
      return nil unless audio?
      audio_match[7].to_i
    end
    
    def audio_bit_rate_units
      return nil unless audio?
      audio_match[8]
    end
    
    def audio_bit_rate_with_units
      "#{audio_bit_rate} #{audio_bit_rate_units}"
    end
    
    def audio_stream
      return nil unless valid?
      
      match = /\n\s*Stream.*Audio:.*\n/.match(@raw_response)
      match[0].strip if match
    end
    
    # The audio codec used.
    #
    # Example:
    #
    #   "aac"
    #
    def audio_codec
      return nil unless audio?
      audio_match[2]
    end
    
    # The sampling rate of the audio stream.
    #
    # Example:
    #
    #   44100
    #
    def audio_sample_rate
      return nil unless audio?
      audio_match[3].to_i
    end
    
    # The units used for the sampling rate. May always be Hz.
    #
    # Example:
    #
    #   "Hz"
    #
    def audio_sample_rate_units
      return nil unless audio?
      audio_match[4]
    end
    alias_method :audio_sample_units, :audio_sample_rate_units
    
    def audio_sample_rate_with_units
      "#{audio_sample_rate} #{audio_sample_rate_units}"
    end
    
    # The channels used in the audio stream.
    #
    # Examples:
    #   "stereo"
    #   "mono"
    #   "5:1"
    #
    def audio_channels_string
      return nil unless audio?
      audio_match[5]
    end
    
    def audio_channels
      return nil unless audio?

      case audio_match[5]
      when "mono"   then 1
      when "stereo" then 2
      else
        raise RuntimeError, "Unknown number of channels: #{audio_channels}"
      end
    end
    
    # This should almost always return 16, 
    # as the vast majority of audio is 16 bit.
    def audio_sample_bit_depth
      return nil unless audio?
      audio_match[6].to_i
    end
    
    # The ID of the audio stream (useful for troubleshooting).
    #
    # Example:
    #   #0.1
    #
    def audio_stream_id
      return nil unless audio?
      audio_match[1]
    end
    
    def video_stream
      return nil unless valid?
      
      match = /\n\s*Stream.*Video:.*\n/.match(@raw_response)
      match[0].strip unless match.nil?
    end
    
    # The ID of the video stream (useful for troubleshooting).
    #
    # Example:
    #   #0.0
    #
    def video_stream_id
      return nil unless video?
      video_match[1]
    end
    
    # The video codec used.
    #
    # Example:
    #
    #   "mpeg4"
    #
    def video_codec
      return nil unless video?
      video_match[3]
    end
    
    # The colorspace of the video stream.
    #
    # Example:
    #
    #   "yuv420p"
    #
    def video_colorspace
      return nil unless video?
      video_match[4]
    end
    
    # The width of the video in pixels.
    def width
      return nil unless video?
      video_match[5].to_i
    end
    
    # The height of the video in pixels.
    def height
      return nil unless video?
      video_match[6].to_i
    end
    
    # width x height, as a string.
    #
    # Examples:
    #   320x240
    #   1280x720
    #
    def resolution
      return nil unless video?
      "#{width}x#{height}"
    end
    
    def pixel_aspect_ratio
      return nil unless video?
      video_match[7]
    end
    
    def display_aspect_ratio
      return nil unless video?
      video_match[8]
    end
    
    # The portion of the overall bitrate the video is responsible for.
    def video_bit_rate
      return nil unless video?
      video_match[9]
    end
    
    def video_bit_rate_units
      return nil unless video?
      video_match[10]
    end
    
    # The frame rate of the video in frames per second
    #
    # Example:
    #
    #   "29.97"
    #
    def fps
      return nil unless video?
      video_match[2] or video_match[11]
    end
    alias_method :framerate, :fps
    
    def time_base
      return nil unless video?
      video_match[12]
    end
    
    def codec_time_base
      return nil unless video?
      video_match[13]
    end
    
    private

    def bitrate_match
      /bitrate: ([0-9\.]+)\s*(.*)\s+/.match(@raw_metadata)
    end
    
    ###
    # I am wondering how reliable it would be to simplify a lot 
    # of this regexp parsery by using split(/\s*,\s*/) - Seth
    
    SEP = '(?:,\s*)'
    VAL = '([^,]+)'
    
    RATE = '([\d.]+k?)'
    
    AUDIO_MATCH_PATTERN = /
      Stream\s+(.*?)[,:\(\[].*?\s*
      Audio:\s+
      #{VAL}#{SEP}           # codec
      #{RATE}\s+(\w*)#{SEP}? # sample rate
      ([a-zA-Z:]*)#{SEP}?    # channels
      (?:s(\d+)#{SEP}?)?     # audio sample bit depth
      (?:(\d+)\s+(\S+))?     # audio bit rate
    /x
    
    def audio_match
      return nil unless valid?
      AUDIO_MATCH_PATTERN.match(audio_stream)
    end
    
    FPS = 'fps(?:\(r\))?'
    
	# FIXME tbn/tbc may need braced alternatives, too: tb(n) / tb(c) - not tested
	# not fixing as of yet because it renumbers backrefs
    VIDEO_MATCH_PATTERN = /
      Stream\s*(\#[\d.]+)(?:[\(\[].+?[\)\]])?\s*                  # stream id
      [,:]\s*                                                     
      (?:#{RATE}\s*#{FPS}[,:]\s*)?                                # frame rate, older builds
      Video:\s*                                                   
      #{VAL}#{SEP}                                                # codec
      (?:#{VAL}#{SEP})?                                           # color space
      (\d+)x(\d+)                                                 # resolution
        (?:\s*\[?(?:PAR\s*(\d+:\d+))?\s*(?:DAR\s*(\d+:\d+))?\]?)? # pixel and display aspect ratios
        #{SEP}?
      (?:#{RATE}\s*(kb\/s)#{SEP}?)?                               # video bit rate
      (?:#{RATE}\s*(?:tb\(?r\)?|#{FPS})#{SEP}?)?                  # frame rate
      (?:#{RATE}\s*tbn#{SEP}?)?                                   # time base
      (?:#{RATE}\s*tbc#{SEP}?)?                                   # codec time base
    /x
    
    def video_match
      return nil unless valid?
      VIDEO_MATCH_PATTERN.match(video_stream)
    end
  end
end
