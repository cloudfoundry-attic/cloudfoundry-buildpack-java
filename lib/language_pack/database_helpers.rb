module LanguagePack::DatabaseHelpers

  SERVICE_DRIVER_HASH = {
    "*mysql-connector-java-*.jar" =>
        "http://search.maven.org/remotecontent?filepath=mysql/mysql-connector-java/5.1.12/mysql-connector-java-5.1.12.jar",
    "*postgresql-*.jdbc*.jar" =>
        "http://search.maven.org/remotecontent?filepath=postgresql/postgresql/9.0-801.jdbc4/postgresql-9.0-801.jdbc4.jar"
  }.freeze

  def install_database_drivers
    added_jars = []
    Dir.chdir("lib") do
      SERVICE_DRIVER_HASH.each_pair do |search_pattern, url|
         unless !Dir.glob(search_pattern).empty?
           fetch_package(File.basename(url), File.dirname(url))
           added_jars << File.basename(url)
         end
      end
    end
    added_jars
  end
end