# frozen_string_literal: true

require "logger"
$logger = Logger.new(STDOUT)

require "tokenizers"
require "awesome_print"
require "json"
require "active_support"
require "active_support/configurable" # interface for configuration objects
require "active_support/dependencies/autoload"


Dir.glob(File.join(File.expand_path(__dir__), "dru", "utils", "*.rb")).each do |utility|
  require_relative "#{utility}"
end

module Dru
  class DruError < StandardError; end
  # Your code goes here...

  extend ::ActiveSupport::Autoload
  include ::ActiveSupport::Configurable

  config_accessor :zod_schema_directories, :vocabulary

  eager_autoload do 
    autoload :Parser
  end
end

require_relative "dru/version"
