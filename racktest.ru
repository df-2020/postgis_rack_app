# frozen_string_literal: true

require_relative 'racktest'

use Rack::ShowExceptions
run Rack::Racktest.new
