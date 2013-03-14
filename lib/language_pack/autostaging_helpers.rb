module LanguagePack::AutostagingHelpers

  AUTOSTAGING_JAR = "auto-reconfiguration-0.6.6.jar"

  def copy_autostaging_jar(destination_dir)
    FileUtils.chdir(destination_dir) do
      fetch_package AUTOSTAGING_JAR
    end
  end
end