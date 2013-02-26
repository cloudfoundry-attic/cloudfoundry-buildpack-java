require "language_pack/java"
require "language_pack/container"
require "language_pack/database_helpers"
require "language_pack/util"

# TODO logging
module LanguagePack
  class JavaWeb < Java

    def self.use?
      use_with_hint?(self.to_s) do
        ret = File.exists?("WEB-INF/web.xml")
        Container::WebContainer.get_supported_containers.each do |_, sub_class|
          return true if sub_class.use?
        end unless ret
        ret
      end
    end

    attr_reader :container

    def initialize(build_path, cache_path=nil)
      super(build_path, cache_path)
      @container = create_container
    end

    def name
      "Java Web - #{container.name}"
    end

    def get_specified_container
      system_properties["java_web.container.name"]
    end

    def get_detected_container
      Container::WebContainer.get_supported_containers.each do |idx_name, sub_class|
        return idx_name if sub_class.use?
      end
      nil
    end

    def get_default_container
      Container::WebContainer.get_supported_containers.first[0]
    end

    def create_container
      container_idx_name = get_specified_container || get_detected_container || get_default_container
      Container::WebContainer.create(container_idx_name, build_path)
    end

    def install_container
      if container.nil?
        puts "Not suitable AppServer/Container."
        exit 1
      end
      unless container.install
        puts "Unable to install #{container.name}"
        exit 1
      end
    end

    def configure_container
      container.configure if container
    end

    def repack_webapp_in_container
      container.repack_webapp if container
    end

    def compile
      Dir.chdir(build_path) do
        install_java
        install_container
        configure_container
        setup_profiled
        yield self if block_given?
        repack_webapp_in_container
      end
    end

    def java_opts
      opts = super.merge({ "-Dhttp.port=" => "$VCAP_APP_PORT" })
      container.java_opts(opts)
    end

    def default_process_types
      container.default_process_types
    end

    def webapp_path
      File.join(build_path, container.web_root)
    end
  end
end
