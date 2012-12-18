require "language_pack/java"

# TODO logging
module LanguagePack
  class JavaWeb < Java

    TOMCAT_URL =  "http://archive.apache.org/dist/tomcat/tomcat-6/v6.0.35/bin/apache-tomcat-6.0.35.tar.gz"

    def self.use?
      # TODO this assumes WAR is getting unzipped.  Safe assumption w/out custom vmc?
      File.exists?("WEB-INF/web.xml")
    end

    def compile
      Dir.chdir(build_path) do
        install_java
        install_tomcat
        remove_tomcat_files
        copy_webapp_to_tomcat
        move_tomcat_to_root
        #install_database_drivers
        #install_insight
        configure_server_xml
        setup_profiled
      end
    end

    def install_tomcat
      FileUtils.mkdir_p tomcat_dir
      tomcat_tarball="#{tomcat_dir}/tomcat.tar.gz"
      puts "Downloading Tomcat: #{TOMCAT_URL}"
      run("curl --silent --location #{TOMCAT_URL} --output #{tomcat_tarball}")
      puts "Unpacking Tomcat to #{tomcat_dir}"
      run("tar xzf #{tomcat_tarball} -C #{tomcat_dir} && mv #{tomcat_dir}/apache-tomcat*/* #{tomcat_dir} && " +
              "rm -rf #{tomcat_dir}/apache-tomcat*")
      FileUtils.rm_rf tomcat_tarball
      unless File.exists?("#{tomcat_dir}/bin/catalina.sh")
        puts "Unable to retrieve Tomcat"
        exit 1
      end
    end

    def remove_tomcat_files
      %w[NOTICE RELEASE-NOTES RUNNING.txt LICENSE temp/. webapps/. work/.].each do |file|
        FileUtils.rm_rf("#{tomcat_dir}/#{file}")
      end
    end

    def tomcat_dir
      ".tomcat"
    end

    def copy_webapp_to_tomcat
      # TODO would be easier if app weren't already expanded in root dir
      run("mkdir #{tomcat_dir}/webapps/ROOT && mv * #{tomcat_dir}/webapps/ROOT")
    end

    def move_tomcat_to_root
      run("mv #{tomcat_dir}/* . && rm -rf #{tomcat_dir}")
    end

    def configure_server_xml
      FileUtils.cp(File.expand_path('../../../resources/server.xml', __FILE__), "conf")
    end

    def setup_profiled
      super
      #TODO JAVA_OPTS from super + http.port
    end

    def default_process_types
      {
        "web" => "./bin/catalina.sh run"
      }
    end
  end
end