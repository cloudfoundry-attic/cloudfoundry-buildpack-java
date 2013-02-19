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
           puts "Downloading Database Driver: #{url}"
           run_with_err_output("curl --silent --location #{url} --remote-name")
           added_jars << File.basename(url)
         end
      end
    end
    added_jars
  end
end