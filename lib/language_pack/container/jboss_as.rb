require "fileutils"
require "language_pack/util"
require "language_pack/container/base"

class LanguagePack::Container::JbossAS < LanguagePack::Container::WebContainer

  JBOSSAS_URL = "http://download.jboss.org/jbossas/7.1/jboss-as-7.1.1.Final/jboss-as-7.1.1.Final.tar.gz".freeze
  JBOSSAS_VERSION = "7.1.1".freeze
  JBOSSAS_DISCARDED_FILES =  %w[copyright.txt LICENSE.txt README.txt docs/. standalone/deployments/. welcome-content/.]

  def self.use?
    use_with_hint?(self.to_s, :container) do
      File.exists?("WEB-INF/jboss-web.xml") || Dir.glob(File.join("WEB-INF", "*-ds.xml")).count > 0 || Dir.glob(File.join("WEB-INF/classes/META-INF", "persistence.xml")).count > 0
    end
  end

  def self.web_root
    "standalone/deployments/ROOT.war"
  end

  def initialize(name, build_path)
    @name = name
    @version = JBOSSAS_VERSION
    @discarded_files = JBOSSAS_DISCARDED_FILES
    @url = JBOSSAS_URL
    @build_path = build_path
  end

  def name_pattern
    "jboss-as-*"
  end

  def installed_bin_file
    "standalone.sh"
  end

  alias_method :install_database_drivers_ori, :install_database_drivers
  def install_database_drivers
    added_jars = []
    get_database_drivers.each_pair do |name, driver_info|
      search_pattern = driver_info[:search_pattern]
      if Dir.glob(File.join("modules", "**", search_pattern)).empty?
        url = driver_info[:url]
        module_path = File.join("modules", driver_info[:module_path])
        FileUtils.mkdir_p(module_path)
        Dir.chdir(module_path) do
          puts "Downloading Database Driver: #{url}"
          fetch_package(File.basename(url), File.dirname(url))
          # module.xml file will be copied when invoke copy_resources_to_build_path
        end
        added_jars << File.basename(url)
      end
    end
    added_jars
  end

  def repack_webapp
    root_path = File.join("#{@build_path}", self.class.web_root)
    # copy out the deployable datasources *-ds.xml in webapp to standalone/deployments
    Dir.glob(File.join(root_path, "WEB-INF" ,"*-ds.xml")).each do |f|
      run_with_err_output "mv #{f} #{File.dirname(root_path)}"
    end
    # repack webapp
    root_war = File.basename(self.class.web_root)
    Dir.chdir(root_path) do
      run_with_err_output "export JAVA_HOME=#{@build_path}/.jdk; export PATH=$JAVA_HOME/bin:$PATH; jar cvf #{root_war} *"
      run_with_err_output "mv #{root_war} #{File.join(@build_path, "." + root_war)}"
    end
    raise "Fail to repack the web app" unless File.exists?(File.join(@build_path, "."+root_war))
    run_with_err_output "rm -rf #{root_path}"
    run_with_err_output "mv #{File.join(@build_path, "." + root_war)} #{root_path}"
  end

  def get_database_driver_info(driver_name)
    driver_info = get_database_drivers[driver_name]
    driver_info[:installed_path] = File.join("modules", driver_info[:module_path] ,File.basename(driver_info[:url]))
    driver_info
  end

  def default_process_types
    {
      "web" => "./bin/#{installed_bin_file}"
    }
  end

end
