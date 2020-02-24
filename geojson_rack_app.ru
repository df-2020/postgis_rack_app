# frozen_string_literal: true

require_relative 'geojson_rack_app'

use Rack::ShowExceptions
run Rack::GeojsonRackApp.new
