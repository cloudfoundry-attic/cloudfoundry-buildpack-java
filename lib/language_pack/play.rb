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
        make_start_executable
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
      # Play dists unpack to a dir named for app.  Assume that is the only non-dot entry
      app_dir = Dir.glob("*").first
      run_with_err_output "cp -a #{File.join(app_dir, "*")} ."
      FileUtils.rm_rf app_dir
    end

    def make_start_executable
      raise "Missing start script. Please run 'play dist' and push the resulting zip file" if !File.exists?("start")
      FileUtils.chmod(0744, "start")
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