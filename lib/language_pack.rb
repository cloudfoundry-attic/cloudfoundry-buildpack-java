require "pathname"
require "language_pack/web_xml_config"
require "language_pack/java"
require "language_pack/java_web"
require "language_pack/spring"
require "language_pack/grails"

# General Language Pack module
module LanguagePack

  # detects which language pack to use
  # @param [Array] first argument is a String of the build directory
  # @return [LanguagePack] the {LanguagePack} detected
  def self.detect(*args)
    Dir.chdir(args.first)

    pack = [ Grails, Spring, JavaWeb, Java ].detect do |klass|
      klass.use?
    end

    pack ? pack.new(*args) : nil
  end

end


