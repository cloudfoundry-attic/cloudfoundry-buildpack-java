require "fileutils"
require "language_pack/util"
require "language_pack/container/base"

class LanguagePack::Container::Tomcat < LanguagePack::Container::WebContainer

  TOMCAT_URL = "http://archive.apache.org/dist/tomcat/tomcat-7/v7.0.37/bin/apache-tomcat-7.0.37.tar.gz".freeze
  TOMCAT_VERSION = "7.0.37".freeze
  TOMCAT_DISCARDED_FILES = %w[NOTICE RELEASE-NOTES RUNNING.txt LICENSE temp/. webapps/. work/. logs]

  def self.use?
    File.exists?("WEB-INF/web.xml")
  end

  def self.web_root
    "webapps/ROOT"
  end

  def initialize(name, build_path)
    @name = name
    @version = TOMCAT_VERSION
    @discarded_files = TOMCAT_DISCARDED_FILES
    @url = TOMCAT_URL
    @build_path = build_path
  end

  def name_pattern
    "apache-tomcat-*"
  end

  def installed_bin_file
    "catalina.sh"
  end

  def default_process_types
    {
      "web" => "./bin/#{installed_bin_file} run"
    }
  end

  def java_opts(opts)
    opts = super(opts)
    opts.delete("-Djava.io.tmpdir=")
    opts
  end

end
