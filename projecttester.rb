require_relative 'racktest'
require 'sequel'
require 'httparty'
require "test/unit"

class ProjectTester < Test::Unit::TestCase
	# Tests gotta start with "test_"
	def test_blah
		# You can also use post, put, delete, head, options in the same fashion
		response = HTTParty.get('http://localhost:9292/?query_string=')
		puts response.body, response.code, response.message, response.headers.inspect
	end
	#Tests to make sure non-post and non-get requests are rejected; tests for invalid data types;
end
