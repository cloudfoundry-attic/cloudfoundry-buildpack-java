require "fileutils"

module LanguagePack
  module Util

    # run a shell comannd and pipe stderr to stdout
    # @param [String] command to be run
    # @return [String] output of stdout and stderr
    def run_with_err_output(command)
      %x{ #{command} 2>&1 }
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def use_with_hint?(name, &block)
        return true if detect_with_hint_file(name)
        if block.call
          puts "block return true"
          set_detected_hint_file(name)
          return true
        end
        return false
      end

      def detected_hint_file
        ".language_pack_detected"
      end

      def detect_with_hint_file(name)
        begin
          File.exists?(detected_hint_file) && (File.open(detected_hint_file, 'r') { |f| f.read }) == name
        rescue => e
          false
        end
      end

      def set_detected_hint_file(name)
        File.open(detected_hint_file, 'w') do |f|
          f.write(name)
        end
      end
    end

  end
end
