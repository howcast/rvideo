module RVideo # :nodoc:
  module Tools  # :nodoc:
  
    # AbstractTool is an interface to every transcoder tool class 
    # (e.g. ffmpeg, flvtool2). Called by the Transcoder class.
    class AbstractTool

      def self.assign(cmd, options = {})
        tool_name = cmd.split(" ").first
        begin
          tool = "RVideo::Tools::#{tool_name.underscore.classify}".constantize.send(:new, cmd, options)
        # rescue NameError, /uninitialized constant/
          # raise TranscoderError::UnknownTool, "The recipe tried to use the '#{tool_name}' tool, which does not exist."
        rescue => e
          RVideo.logger.info e.message
          RVideo.logger.info e.backtrace.join("\n")
          raise e
        end
      end
  
  
      module InstanceMethods
        # Defines abstract methods in the convention of "format_#{attribute}" 
        # which are meant to be redefined by classes including this behavior.
        def self.abstract_attribute_formatter(*names)
          names.map { |n| "format_#{n}" }.each do |name|
            class_eval %{
              def #{name}(params = {})
                raise ParameterError,
                  "The #{self.class} tool has not implemented the :#{name} method."
              end
            }, __FILE__, __LINE__
          end
        end
    
        abstract_attribute_formatter :resolution, :deinterlace, :fps,
          :video_bit_rate, :video_bit_rate_tolerance,
          :video_bit_rate_min, :video_bit_rate_max,
          :audio_channels, :audio_bit_rate, :audio_sample_rate
    
        ###
    
        attr_reader :options, :command, :raw_result
        attr_writer :original
    
        def initialize(raw_command, options = {})
          @raw_command = raw_command
          @options = HashWithIndifferentAccess.new(options)
          @command = interpolate_variables(raw_command)
        end

        def execute
          @output_params = {}
      
          # Dump the log output into a temp file
          log_temp_file_name = "/tmp/transcode_output_#{Time.now.to_i}.txt"
    
          final_command = "#{@command} 2>#{log_temp_file_name}"

          # nice the command if option :nice was given
          # accepts a number 1..19 (nice value) or anything evaluating to true
          unless RUBY_PLATFORM.downcase.include?("mswin")
            if @options.has_key? :nice
              if (1..19) === @options[:nice]
                final_command = "nice -n#{@options[:nice]} #{final_command}"
              elsif @options[:nice]
                final_command = "nice #{final_command}"
              end
            end
          end

          RVideo.logger.info("\nExecuting Command: #{final_command}\n")
          do_execute final_command
      
          populate_raw_result(log_temp_file_name)
      
          RVideo.logger.info("Result: \n#{@raw_result}")
          parse_result(@raw_result)
      
          # Cleanup log file
          begin
            File.delete(log_temp_file_name)
          rescue Exception  => e
            RVideo.logger.error("Failed to delete output log file: #{log_temp_file_name}, e=#{e}")
          end
        end
    
        # Wrapper around the system call, for whenever we need to 
        # hook on or redefine this without messing with Kernel
        def do_execute(command)
          system command
        end
    
        #
        # Magic parameters
        #
        def temp_dir
          if @options['output_file']
            "#{File.dirname(@options['output_file'])}/"
          else
            ""
          end
        end
    
        ###
        # FPS aka framerate
    
        def fps
          format_fps(get_fps)
        end
    
        def get_fps
          inspect_original if @original.nil?
          fps = @options['fps'] || ""
          case fps
          when "copy"
            get_original_fps
          else
            get_specific_fps
          end
        end
    
        def get_original_fps
          return {} if @original.fps.nil?
          { :fps => @original.fps }
        end
    
        def get_specific_fps
          { :fps => @options['fps'] }
        end
    
        ###
        # Resolution

        def deinterlace
          format_deinterlace(get_deinterlace)
        end

        def get_deinterlace
          { :deinterlace => @options['deinterlace'] ? true : false }
        end

        def resolution
          format_resolution(get_resolution)
        end

        def get_resolution
          inspect_original if @original.nil?
      
          case @options['resolution']
          when "copy"      then get_original_resolution
          when "width"     then get_fit_to_width_resolution
          when "height"    then get_fit_to_height_resolution
          when "letterbox" then get_letterbox_resolution
          else
            if @options["width"] and not @options["height"]
              get_fit_to_width_resolution
            elsif @options["height"] and not @options["width"]
              get_fit_to_height_resolution
            elsif @options["width"] and @options["height"]
              get_specific_resolution
            else
              get_original_resolution
            end
          end
        end

        def get_fit_to_width_resolution
          w = @options['width']
      
          raise TranscoderError::ParameterError,
            "invalid width of '#{w}' for fit to width" unless valid_dimension?(w)
      
          h = calculate_height(@original.width, @original.height, w)
      
          { :scale => { :width => w, :height => h } }
        end
    
        def get_fit_to_height_resolution
          h = @options['height']
      
          raise TranscoderError::ParameterError,
            "invalid height of '#{h}' for fit to height" unless valid_dimension?(h)
      
          w = calculate_width(@original.width, @original.height, h)
      
          { :scale => { :width => w, :height => h } }
        end
    
        def get_letterbox_resolution
          lw = @options['width'].to_i
          lh = @options['height'].to_i
      
          raise TranscoderError::ParameterError,
            "invalid width of '#{lw}' for letterbox" unless valid_dimension?(lw)
          raise TranscoderError::ParameterError,
            "invalid height of '#{lh}' for letterbox" unless valid_dimension?(lh)
      
          w = calculate_width(@original.width, @original.height, lh)
          h = calculate_height(@original.width, @original.height, lw)
      
          if w > lw
            w = lw
            h = calculate_height(@original.width, @original.height, lw)
          else
            h = lh
            w = calculate_width(@original.width, @original.height, lh)
          end
      
          { :scale     => { :width => w,  :height => h  },
            :letterbox => { :width => lw, :height => lh } }
        end
    
        def get_original_resolution
          { :scale => { :width => @original.width, :height => @original.height } }
        end

        def get_specific_resolution
          w = @options['width']
          h = @options['height']
      
          raise TranscoderError::ParameterError,
            "invalid width of '#{w}' for specific resolution" unless valid_dimension?(w)
          raise TranscoderError::ParameterError,
            "invalid height of '#{h}' for specific resolution" unless valid_dimension?(h)
      
          { :scale => { :width => w, :height => h } }
        end
    
        def calculate_width(ow, oh, h)
          w = ((ow.to_f / oh.to_f) * h.to_f).to_i
          (w.to_f / 16).round * 16
        end

        def calculate_height(ow, oh, w)
          h = (w.to_f / (ow.to_f / oh.to_f)).to_i
          (h.to_f / 16).round * 16
        end
    
        def valid_dimension?(dim)
          dim.to_i > 0
        end
    
        ###
        # Audio channels
    
        def audio_channels
          format_audio_channels(get_audio_channels)
        end

        def get_audio_channels
          channels = @options['audio_channels'] || ""
          case channels
          when "stereo"
            get_stereo_audio
          when "mono"
            get_mono_audio
          else
            {}
          end
        end
    
        def get_stereo_audio
          { :channels => "2" }
        end
    
        def get_mono_audio
          { :channels => "1" }
        end
    
        def get_specific_audio_bit_rate
          { :bit_rate => @options['audio_bit_rate'] }
        end
    
        def get_specific_audio_sample_rate
          { :sample_rate => @options['audio_sample_rate'] }
        end
    
        ###
        # Audio bit rate
    
        def audio_bit_rate
          format_audio_bit_rate(get_audio_bit_rate)
        end
    
        def get_audio_bit_rate
          bit_rate = @options['audio_bit_rate'] || ""
          case bit_rate
          when ""
            {}
          else
            get_specific_audio_bit_rate
          end
        end
    
        ###
        # Audio sample rate
    
        def audio_sample_rate
          format_audio_sample_rate(get_audio_sample_rate)
        end
    
        def get_audio_sample_rate
          sample_rate = @options['audio_sample_rate'] || ""
          case sample_rate
          when ""
            {}
          else
            get_specific_audio_sample_rate
          end
        end
    
        ###
        # Video quality
    
        def video_quality
          format_video_quality(get_video_quality)
        end
    
        def get_video_quality
          quality = @options['video_quality'] || 'medium'
          
          { :video_quality => quality }.
            merge!(get_fps).
            merge!(get_resolution).
            merge!(get_video_bit_rate)
        end
        
        def video_bit_rate
          format_video_bit_rate(get_video_bit_rate)
        end
        
        def get_video_bit_rate
          { :video_bit_rate => @options["video_bit_rate"] }
        end
        
        def video_bit_rate_tolerance
          format_video_bit_rate_tolerance(get_video_bit_rate_tolerance)
        end
        
        def get_video_bit_rate_tolerance
          { :video_bit_rate_tolerance => @options["video_bit_rate_tolerance"] }
        end
        
        def video_bit_rate_min
          format_video_bit_rate_min(get_video_bit_rate_min)
        end
        
        def get_video_bit_rate_min
          { :video_bit_rate_min => @options["video_bit_rate_min"] }
        end
        
        def video_bit_rate_max
          format_video_bit_rate_max(get_video_bit_rate_max)
        end
        
        def get_video_bit_rate_max
          { :video_bit_rate_max => @options["video_bit_rate_max"] }
        end

      private
        
        VARIABLE_INTERPOLATION_SCAN_PATTERN = /[^\\]\$[-_a-zA-Z]+\$/
        
        def interpolate_variables(raw_command)
          raw_command.scan(VARIABLE_INTERPOLATION_SCAN_PATTERN).each do |match|
            match = match[0..0] == "$" ? match : match[1..(match.size - 1)]
            match.strip!
            
            value = if ["$input_file$", "$output_file$"].include?(match)
              matched_variable(match).to_s.shell_quoted
            else
              matched_variable(match).to_s
            end
            
            raw_command.gsub!(match, value)
          end
          raw_command.gsub("\\$", "$")
        end
        
        #
        # Strip the $s. First, look for a supplied option that matches the
        # variable name. If one is not found, look for a method that matches.
        # If not found, raise ParameterError exception.
        # 
        
        def matched_variable(match)
          variable_name = match.gsub("$","")
          if self.respond_to? variable_name
            self.send(variable_name)
          elsif @options.key?(variable_name) 
            @options[variable_name]
          else
            raise TranscoderError::ParameterError,
              "command is looking for the #{variable_name} parameter, but it was not provided. (Command: #{@raw_command})"
          end
        end
        
    
        def inspect_original
          @original = Inspector.new(:file => options[:input_file])
        end
    
        # Pulls the interesting bits of the temp log file into memory.  This is fairly tool-specific, so
        # it's doubtful that this default version is going to work without being overridded.
        def populate_raw_result(temp_file_name)
          @raw_result = `tail -n 500 #{temp_file_name}`
        end
    
      end # InstanceMethods
    end

  end
end
