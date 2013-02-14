require "language_pack/java"

module LanguagePack
  class Play < Java

    include LanguagePack::DatabaseHelpers
    include LanguagePack::AutostagingHelpers

    def self.use?
      Dir.glob("**/lib/play.*.jar").any?
    end

    def name
      "Play"
    end

    def compile
      Dir.chdir(build_path) do
        super
        move_app_to_root
        install_database_drivers
        configure_autostaging
      end
    end

    def java_opts
      super.merge({ "-Dhttp.port=" => "$VCAP_APP_PORT" })
    end

    def default_process_types
      { "web" => "./start $JAVA_OPTS" }
    end

    private
    def move_app_to_root
      app_dir = play_app_dir
      run_with_err_output "cp -a #{File.join(app_dir, "*")} ."
      FileUtils.rm_rf app_dir
    end


    def play_app_dir
      dirs = Dir.glob("*").select do |x|
        File.directory?(x) && File.exists?("#{x}/start") && File.exists?("#{x}/lib")
      end
      return dirs.first if dirs.size == 1
      raise "Play app not detected. Please run 'play dist' and push the resulting zip file"
    end

    def configure_autostaging
      puts "Configuring autostaging"
      copy_autostaging_jar "lib"
      start_cmd = File.read "start"
      File.open("start", "w") do |file|
        file.write start_cmd.gsub(/play\.core\.server\.NettyServer/, "org.cloudfoundry.reconfiguration.play.Bootstrap")
      end
    end
  end
end