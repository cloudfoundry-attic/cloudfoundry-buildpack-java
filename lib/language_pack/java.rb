require "yaml"
require "fileutils"

module LanguagePack
  class Java
    include LanguagePack::PackageFetcher

    DEFAULT_JDK_VERSION = "1.7".freeze

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
      @java_version ||= system_properties["java.runtime.version"] || DEFAULT_JDK_VERSION
    end

    def system_properties
      files = Dir.glob("**/system.properties")
      (!files.empty?) ? properties(files.first) :  {}
    end

    def download_jdk(jdk_tarball)
      puts "Downloading JDK..."
      fetched_package = fetch_jdk_package(java_version)
      FileUtils.mv fetched_package, jdk_tarball
    end

    def jdk_dir
      ".jdk"
    end

    def java_opts
      {
        "-Xmx" => "$MEMORY_LIMIT",
        "-Xms" => "$MEMORY_LIMIT",
        "-Djava.io.tmpdir=" => '\"$TMPDIR\"'

      # Temp disable due to crazy variable expansion issues in bash.
      #,
      #  "-XX:OnOutOfMemoryError=" => '\"echo oome killing pid: %p && kill -9 %p\"'
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
      FileUtils.mkdir_p "#{build_path}/.profile.d"
      File.open("#{build_path}/.profile.d/java.sh", "a") { |file| file.puts(bash_script) }
    end

    private

    def bash_script
      <<-BASH
#!/bin/bash
export JAVA_HOME="$HOME/#{jdk_dir}"
export PATH="$HOME/#{jdk_dir}/bin:$PATH"
export JAVA_OPTS=${JAVA_OPTS:-"#{java_opts.map{ |k, v| "#{k}#{v}" }.join(' ')}"}
export LANG="${LANG:-en_US.UTF-8}"

if [ -n "$VCAP_DEBUG_MODE" ]; then
  if [ "$VCAP_DEBUG_MODE" = "run" ]; then
    export JAVA_OPTS="$JAVA_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,address=$VCAP_DEBUG_PORT,server=y,suspend=n"
  elif [ "$VCAP_DEBUG_MODE" = "suspend" ]; then
    export JAVA_OPTS="$JAVA_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,address=$VCAP_DEBUG_PORT,server=y,suspend=y"
  fi
fi
      BASH
    end

    def properties(props_file)
      properties = {}
      IO.foreach(props_file) do |line|
        if line =~ /([^=]*)=(.*)\/\/(.*)/ || line =~ /([^=]*)=(.*)/
          case $2
          when "true"
            properties[$1.strip] = true
          when "false"
            properties[$1.strip] = false
          else
            properties[$1.strip] = $2
          end
        end
      end
      properties
    end
  end
end
