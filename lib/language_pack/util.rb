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
      def use_with_hint?(name, hint_type, &block)
        if detect_with_hint_file(name, hint_type)
          return true
        end
        if block.call
          set_detected_hint_file(name, hint_type)
          return true
        end
        return false
      end

      def detected_hint_file(hint_type)
        case hint_type
        when :pack
          ".language_pack_detected"
        when :container
          ".container_detected"
        end
      end

      def detect_with_hint_file(name, hint_type)
        hint_file = detected_hint_file(hint_type)
        begin
          File.exists?(hint_file) && (File.open(hint_file, 'r') { |f| f.read }) == name
        rescue => e
          false
        end
      end

      def set_detected_hint_file(name, hint_type)
        hint_file = detected_hint_file(hint_type)
        File.open(hint_file, 'w') do |f|
          f.write(name)
        end
      end
    end

  end
end
