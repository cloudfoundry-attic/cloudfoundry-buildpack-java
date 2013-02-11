require "yaml"
require "fileutils"

module LanguagePack
  class Java

    DEFAULT_JDK_VERSION = "1.6".freeze
    JDK_URL_1_6 = "https://s3.amazonaws.com/heroku-jvm-langpack-java/openjdk6-u25-heroku-temaki.tar.gz".freeze
    JDK_URL_1_7="https://s3.amazonaws.com/heroku-jvm-langpack-java/openjdk7-u7-heroku-temaki-b30.tar.gz".freeze
    JDK_URL_1_8="https://s3.amazonaws.com/heroku-jvm-langpack-java/openjdk8-lambda-preview.tar.gz".freeze

    def self.use?
      Dir.glob("**/*.jar").any? || Dir.glob("**/*.class").any?
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
      jdk_tarball = "#{jdk_dir}/jdk.tar.gz"

      download_jdk jdk_tarball

      puts "Unpacking JDK to #{jdk_dir}"
      tar_output = run_with_err_output "tar pxzf #{jdk_tarball} -C #{jdk_dir}"

      FileUtils.rm_rf jdk_tarball
      unless File.exists?("#{jdk_dir}/bin/java")
        puts "Unable to retrieve the JDK"
        puts tar_output
        exit 1
      end
    end

    def java_version
      @java_version ||= \
      begin
        files = Dir.glob("**/system.properties")
        if !files.empty?
          system_properties(files.first)["java.runtime.version"] || DEFAULT_JDK_VERSION
        else
          DEFAULT_JDK_VERSION
        end
      end
    end

    def download_jdk(jdk_tarball)
      puts "Downloading JDK: #{jdk_download_url}"
      run_with_err_output "curl --silent --location #{jdk_download_url} --output #{jdk_tarball}"
    end

    def jdk_dir
      ".jdk"
    end

    def jdk_download_url
     # TODO OS Suffix stuff for Mac?
     LanguagePack::Java.const_get("JDK_URL_#{java_version.gsub(/\./, '_')}")
    rescue
      raise "Unsupported Java version: #{java_version}"
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
    def run_with_err_output(command)
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

    private
    def system_properties(system_props_file)
      properties = {}
      IO.foreach(system_props_file) do |line|
        properties[$1.strip] = $2 if line =~ /([^=]*)=(.*)\/\/(.*)/ || line =~ /([^=]*)=(.*)/
      end
      properties
    end
  end
end
