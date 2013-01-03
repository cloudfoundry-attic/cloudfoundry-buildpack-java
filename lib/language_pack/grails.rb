require "language_pack/spring"

module LanguagePack
  class Grails < Spring
    GRAILS_WEB_DIR = "WEB-INF/lib/grails-web/".freeze

    CONTEXT_PARAMS = {
        contextConfigLocation: 'classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml'
    }.freeze

    SERVLET = {
        dispatcherServletClass: "org.codehaus.groovy.grails.web.servlet.GrailsDispatcherServlet"
    }.freeze

    def self.use?
      Dir.glob("#{GRAILS_WEB_DIR}/*.jar").any? || Dir.glob("#{WEBAPP_DIR}#{GRAILS_WEB_DIR}/*.jar").any?
    end
  end
end