require "yaml"
require "fileutils"

module LanguagePack
  class Java

    DEFAULT_JDK_VERSION="1.6"
    JDK_URL_1_6="https://s3.amazonaws.com/heroku-jvm-langpack-java/openjdk6-u25-heroku-temaki.tar.gz"

    def self.use?
      # TODO detect standalone Java apps
      false
    end

    attr_reader :build_path, :cache_path

    # changes directory to the build_path
    # @param [String] the path of the build dir
    # @param [String] the path of the cache dir
    def initialize(build_path, cache_path=nil)
      @build_path = build_path
      @cache_path = cache_path
    end

    def name
      "Java"
    end

    def compile
      Dir.chdir(build_path) do
        install_java
        setup_profiled
      end
    end

    def install_java
      FileUtils.mkdir_p jdk_dir
      jdk_tarball="#{jdk_dir}/jdk.tar.gz"
      puts "Downloading JDK: #{jdk_download_url}"
      run("curl --silent --location #{jdk_download_url} --output #{jdk_tarball}")
      puts "Unpacking JDK to #{jdk_dir}"
      run("tar pxzf #{jdk_tarball} -C #{jdk_dir}")
      FileUtils.rm_rf jdk_tarball
      unless File.exists?("#{jdk_dir}/bin/java")
        puts "Unable to retrieve the JDK"
        exit 1
      end
    end

    def detect_java_version
      # TODO how to choose version
      DEFAULT_JDK_VERSION
    end

    def jdk_dir
      ".jdk"
    end

    def jdk_download_url
     # TODO OS Suffix stuff for Mac?
      LanguagePack::Java.const_get("JDK_URL_#{detect_java_version.gsub(/\./, '_')}")
    end

    def java_opts
      {
          "-Xmx" => "$MEMORY_LIMIT",
          "-Xms" => "$MEMORY_LIMIT",
          "-Djava.io.tmpdir=" => "$TMPDIR"
      }
    end

    def release
      {
          "addons" => [],
          "config_vars" => {},
          "default_process_types" => default_process_types
      }.to_yaml
    end

    def default_process_types
      {}
    end

    # run a shell comannd and pipe stderr to stdout
    # @param [String] command to be run
    # @return [String] output of stdout and stderr
    def run(command)
      %x{ #{command} 2>&1 }
    end

    def setup_profiled
      set_env_override "JAVA_HOME", "$HOME/#{jdk_dir}"
      set_env_override "PATH", "$HOME/#{jdk_dir}/bin:$PATH"
      set_env_default "JAVA_OPTS", java_opts.map{|k,v| "#{k}#{v}"}.join(' ')
    end

    def add_to_profiled(string)
      FileUtils.mkdir_p "#{build_path}/.profile.d"
      File.open("#{build_path}/.profile.d/java.sh", "a") do |file|
        file.puts string
      end
    end

    def set_env_default(key, val)
      add_to_profiled "export #{key}=${#{key}:-#{val}}"
    end

    def set_env_override(key, val)
      add_to_profiled %{export #{key}="#{val.gsub('"','\"')}"}
    end
  end
end