gem_home = "~/gems"
ENV['GEM_HOME'] = gem_home
ENV['GEM_PATH'] = gem_home
system "mkdir -p #{gem_home}"
system "gem install nokogiri --no-rdoc --no-ri 2>/dev/null" unless `gem list`.include?('nokogiri')
require "nokogiri"
