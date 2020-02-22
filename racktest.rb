# frozen_string_literal: true

require 'rack'
require 'sequel'

module Rack
  class Racktest
    # connect to the POSTGRES server
    DB = Sequel.connect('postgres://geojson:geojson@localhost:5432/geojson_development')
    DB["CREATE TABLE IF NOT EXISTS geojson_points (point_id serial PRIMARY KEY, point_geog geography(POINT))"]
    QS = "SELECT srid, auth_name, auth_srid, proj4text FROM spatial_ref_sys WHERE cast(SRID as text) LIKE ?"
    @result = ""
    #evn is the environment, containing QUERY_STRING, REQUEST_METHOD, SERVER_NAME, etc. This is how geojson data will be fed to the app
    def call(env)
      # User is giving geojson points; add them to table
      if env[REQUEST_METHOD] == "POST" && env[CONTENT_TYPE] == "application/geo+json"
        env[QUERY_STRING].each do |point|
          #put point into table;
        end
      elsif env[REQUEST_METHOD] == "GET" # Endpoint 2 or 3; if given a point and an int, calc the points with radius; if a polygon, find points within it
        #Endpoint 2: Use ST_PointInsideCircle?
        #Endpont 3: Use ST_CONTAINS?
        @result = DB[QS, "38%"]
      end


      # content = ["<title>My Little Rack App!</title>",
      #            "<p>", "QUERY STRING: ",env[QUERY_STRING] || "", "</p>","<p>","REQUEST METHOD: ",env[REQUEST_METHOD] || "","</p>",
      #            "<p>","CONTENT TYPE: ",env[CONTENT_TYPE] || "","</p>","<p>","<a href='#{URI.encode_www_form("CONTENT_TYPE" => "application/geo+json", "REQUEST_METHOD" => "GET", "QUERY_STRING" => qs)}'>","Post it","</a>","</p>",
      # "<p>","RESULT: ","result","</p>"]
      content = ""
      @result.each do |row|
        row.each do |e|
          content = content + e.join(",")
        end
      end
      # Calculate the CONTENT_SIZE by tallying up the size of each element in the content array
#  inject(0) means put the value 0 into the first element, ie. a
      #length = content.inject(0) { |a, e| a + e.size }.to_s
      length = content.length.to_s
#Below is rack's response, consisting of a Status Code, Headers, and a Body.
#For the GET requests to our app, this is where results will be returned to the user (ie, all points within radius of some point they gave us)
      [200, { CONTENT_TYPE => "text/html", CONTENT_LENGTH => length }, [content]]

    end

  end
end

if $0 == __FILE__
  # :nocov:
  require_relative '../rack'
  Rack::Server.start(
    app: Rack::ShowExceptions.new(Rack::Lint.new(Rack::Racktest.new)), Port: 9292
  )
  # :nocov:
end
