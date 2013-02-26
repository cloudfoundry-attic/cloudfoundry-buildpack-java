require "fileutils"
require "language_pack/util"
require "language_pack/database_helpers"

module LanguagePack
  module Container
  end
end

class LanguagePack::Container::WebContainer

  include LanguagePack::Util
  include LanguagePack::PackageFetcher
  include LanguagePack::DatabaseHelpers

  @@supported_containers = {}
  @@default_container = nil

  class << self
    def create(idx_name, build_path)
      sub_class = @@supported_containers[idx_name]
      sub_class.nil? ? nil : sub_class.new(idx_name, build_path)
    end

    def register(idx_name)
      @@supported_containers[idx_name] = self
    end

    def get_supported_containers
      @@supported_containers
    end

    def use?
      false
    end

    def web_root
      raise NotImplementedError, "Must specify the web root directory such as webapps/ROOT for tomcat"
    end

  end

  attr_reader :name, :version, :discarded_files, :url

  def container_dir
    ".#{name}"
  end

  def container_tarball
    File.join(container_dir, "#{name}.tar.gz")
  end

  def name_pattern
    raise NotImplementedError, "Subclass should implement a method to return name pattern"
  end

  def installed_bin_file
    raise NotImplementedError, "Subclass should implement a mehtod to return file to verify the installation"
  end

  def web_root
    self.class.web_root
  end

  def java_opts(opts)
    opts
  end

  def default_process_types
    raise NotImplementedError, "Subclass should implement the method to return default process types"
  end

  def download
    puts "Downloading #{name}-#{version}: #{url}"
    fetch_package(File.basename(url), File.dirname(url))
    FileUtils.mv File.basename(url), container_tarball
  end

  def install
    FileUtils.mkdir_p container_dir
    download
    puts "Unpacking #{name} to #{container_dir}"
    run_with_err_output("tar xzf #{container_tarball} -C #{container_dir} && " +
                        "mv #{container_dir}/#{name_pattern}*/* #{container_dir} && " +
                        "rm -rf #{container_dir}/#{name_pattern}*")
    return verify_install
  ensure
    FileUtils.rm_rf container_tarball
  end

  def verify_install
    File.exists?("#{container_dir}/bin/#{installed_bin_file}")
  end

  def configure
    remove_files_in_container
    copy_webapp_to_container
    move_to_build_path
    install_database_drivers
    #install_insight
    copy_resources_to_build_path
  end

  def copy_webapp_to_container
    run_with_err_output("mkdir -p #{container_dir}/#{web_root} && mv * #{container_dir}/#{web_root}")
  end

  def remove_files_in_container
    discarded_files.each do |file|
      FileUtils.rm_rf("#{container_dir}/#{file}")
    end if discarded_files
  end

  def move_to_build_path
    run_with_err_output("mv #{container_dir}/* #{@build_path} && rm -rf #{container_dir}")
  end

  def copy_resources_to_build_path
    run_with_err_output("cp -r #{File.expand_path("../../../../resources/#{name}", __FILE__)}/* #{@build_path}")
  end

  def repack_webapp
  end

end
