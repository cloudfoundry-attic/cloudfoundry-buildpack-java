require "language_pack/java"

module LanguagePack
  class Play < Java

    include LanguagePack::PackageFetcher
    include LanguagePack::DatabaseHelpers
    include LanguagePack::AutostagingHelpers

    JPA_PLUGIN_JAR = "play-jpa-plugin-0.6.6.jar"

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
        installed_drivers = install_database_drivers
        copy_autostaging_jar "lib"
        if play_20? || uses_jpa?
          copy_jpa_plugin
          installed_drivers << JPA_PLUGIN_JAR
        end
        modify_start_script(installed_drivers << LanguagePack::AutostagingHelpers::AUTOSTAGING_JAR)
      end
    end

    def java_opts
      super.merge({ "-Dhttp.port=" => "$PORT" })
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

    def uses_jpa?
      !Dir.glob("lib/play.play-java-jpa*.jar").empty?
    end

    def play_20?
      !Dir.glob("lib/play.play_*-2.0.*.jar").empty?
    end

    def copy_jpa_plugin
      FileUtils.chdir("lib") do
        fetch_package JPA_PLUGIN_JAR
      end
    end

    def play_app_dir
      dirs = Dir.glob("*").select do |x|
        File.directory?(x) && File.exists?("#{x}/start") && File.exists?("#{x}/lib")
      end
      return dirs.first if dirs.size == 1
      raise "Play app not detected. Please run 'play dist' and push the resulting zip file"
    end

    def modify_start_script(libraries)
      start_cmd = File.read "start"
      matched_string, classpath = /(?: -cp \"(.+)\" | -cp (\S+) )/.match(start_cmd).to_a.select { |x| x }
      unless matched_string && classpath
        puts "Could not modify the start script to include auto-reconfiguration. Leaving the script unmodified"
        return
      end

      modified_string = matched_string.gsub(classpath, "#{classpath}#{libraries.map {|x| ":`dirname $0`/lib/#{x}"}.join("")}")
      start_cmd.gsub!(matched_string, modified_string)

      File.open("start", 'w') {|f| f.write(start_cmd.gsub(/play\.core\.server\.NettyServer/, "org.cloudfoundry.reconfiguration.play.Bootstrap")) }
    end
  end
end
