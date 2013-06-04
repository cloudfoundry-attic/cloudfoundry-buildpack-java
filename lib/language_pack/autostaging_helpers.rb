module LanguagePack::AutostagingHelpers

  AUTOSTAGING_JAR = "auto-reconfiguration-0.6.7.jar"
  REPO_URL = "https://s3.amazonaws.com/maven.springframework.org/milestone/org/cloudfoundry/auto-reconfiguration/0.6.7"

  def copy_autostaging_jar(destination_dir)
    FileUtils.chdir(destination_dir) do
      fetch_package(AUTOSTAGING_JAR, REPO_URL)
    end
  end
end