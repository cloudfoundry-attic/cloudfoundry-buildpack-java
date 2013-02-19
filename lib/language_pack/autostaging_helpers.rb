module LanguagePack::AutostagingHelpers

  AUTOSTAGING_JAR = "auto-reconfiguration-0.6.6.jar"

  # TODO get this from a URL
  def copy_autostaging_jar(destination_dir)
    FileUtils.cp(File.join(File.expand_path('../../../resources', __FILE__), AUTOSTAGING_JAR),
                 destination_dir)
  end
end