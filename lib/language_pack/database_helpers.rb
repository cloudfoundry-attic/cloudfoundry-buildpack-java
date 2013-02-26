module LanguagePack::DatabaseHelpers

  # Notice: when you update the versions of these drivers, you MIGHT add/update the resource files such as module.xml for Jboss
  SERVICE_DRIVER_HASH = {
    "mysql" => {
      :search_pattern => "*mysql-connector-java-*.jar",
      :url  => "http://search.maven.org/remotecontent?filepath=mysql/mysql-connector-java/5.1.12/mysql-connector-java-5.1.12.jar",
      :module_path => File.join("com", "mysql", "main")
    },
    "postgresql" => {
      :search_pattern => "*postgresql-*.jdbc*.jar",
      :url => "http://search.maven.org/remotecontent?filepath=postgresql/postgresql/9.0-801.jdbc4/postgresql-9.0-801.jdbc4.jar",
      :module_path => File.join("org", "postgresql", "main")
    }
  }.freeze

  def get_database_drivers
    SERVICE_DRIVER_HASH
  end

  def install_database_drivers
    added_jars = []
    Dir.chdir("lib") do
      SERVICE_DRIVER_HASH.each_pair do |name, driver_info|
         search_pattern = driver_info[:search_pattern]
         url = driver_info[:url]
         unless !Dir.glob(search_pattern).empty?
           fetch_package(File.basename(url), File.dirname(url))
           added_jars << File.basename(url)
         end
      end
    end
    added_jars
  end

  def get_database_driver_info(driver_name)
    driver_info = SERVICE_DRIVER_HASH[driver_name]
    driver_info[:installed_path] = File.join("lib", File.basename(driver_info[:url]))
    driver_info
  end
end
