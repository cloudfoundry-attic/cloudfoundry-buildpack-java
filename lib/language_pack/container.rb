require 'language_pack/container/tomcat'
require 'language_pack/container/jboss_as'

LanguagePack::Container::JbossAS.register("jboss-as")
LanguagePack::Container::Tomcat.register("tomcat")
