module LanguagePack::AutostagingHelpers

  AUTORECONFIG_VERSION = "0.7.1"
  AUTORECONFIG_JAR = "auto-reconfiguration-#{AUTORECONFIG_VERSION}.jar"
  REPO_URL = "https://s3.amazonaws.com/maven.springframework.org/milestone/org/cloudfoundry/auto-reconfiguration/#{AUTORECONFIG_VERSION}"

  def copy_autostaging_jar(destination_dir)
    FileUtils.chdir(destination_dir) do
      fetch_package(AUTORECONFIG_JAR, REPO_URL)
    end
  end
end