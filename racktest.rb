# frozen_string_literal: true

require 'rack'
require 'sequel'
require 'rgeo/geo_json'

module Rack
  class Racktest
    # connect to the POSTGRES server
    DB = Sequel.connect('postgres://geojson:geojson@localhost:5432/geojson_development')
    DB.run("CREATE TABLE IF NOT EXISTS geojson_points (point_id serial PRIMARY KEY, point_geog geography(POINT))")
    QS = "SELECT srid, auth_name, auth_srid, proj4text FROM spatial_ref_sys WHERE cast(SRID as text) LIKE ?"
    @result = nil
    #evn is the environment, containing QUERY_STRING, REQUEST_METHOD, SERVER_NAME, etc. This is how geojson data will be fed to the app
    def call(env)
      # User is giving geojson points; add them to table
      if env["REQUEST_METHOD"] == "POST" && env["CONTENT_TYPE"] == "application/geo+json"
        x_parser = "SELECT ST_X((ST_DumpPoints(ST_GeomFromText(?))).geom)"
        y_parser = "SELECT ST_Y((ST_DumpPoints(ST_GeomFromText(?))).geom)"
        input = env['rack.input'].read
        puts "INPUT: " + input
        decoded_input = RGeo::GeoJSON.decode(input)
        puts "CLASS: " + decoded_input.class.to_s
        # If the decoded input lacks a as_text method, then it is not valid geojson input;
        # return an error code to the requester
        unless decoded_input.class.method_defined? :as_text
          content = "Input is not a valid geojson type."
          length = content.length.to_s
          return [500, { CONTENT_TYPE => "text/html", CONTENT_LENGTH => length }, [content]]
        end
        x_coords = DB[x_parser, RGeo::GeoJSON.decode(input).as_text].all
        y_coords = DB[y_parser, RGeo::GeoJSON.decode(input).as_text].all

        x_coords.each_with_index do |x_coord, index|
            puts "X/Y : " + x_coord[:st_x].to_s + "/" + y_coords[index][:st_y].to_s
            # put point into table; "all" invocation is necessary for data to be commited to DB
            DB["INSERT INTO geojson_points(point_geog) VALUES (ST_GeomFromText('POINT(? ?)'))", x_coord[:st_x], y_coords[index][:st_y]].all
        end
      elsif env["REQUEST_METHOD"] == "GET" # Endpoint 2 or 3; if given a point and an int, calc the points with radius; if a polygon, find points within it
        #Endpoint 2: Use ST_PointInsideCircle?
        #Endpont 3: Use ST_CONTAINS?
        @result = DB[QS, "38%"]
      end

      content = ""
      if @result != nil
        @result.each do |row|
          row.each do |e|
            content = content + e.join(",")
          end
        end
      end
      # Calculate the CONTENT_SIZE by tallying up the size of each element in the content array
#  inject(0) means put the value 0 into the first element, ie. a
      length = content.length.to_s
#Below is rack's response, consisting of a Status Code, Headers, and a Body.
#For the GET requests to our app, this is where results will be returned to the user (ie, all points within radius of some point they gave us)
      [200, { CONTENT_TYPE => "text/html", CONTENT_LENGTH => length }, [content]]

    end

  end
end

# Start the Rack server
if $0 == __FILE__
  # :nocov:
  require_relative '../rack'
  Rack::Server.start(
    app: Rack::ShowExceptions.new(Rack::Lint.new(Rack::Racktest.new)), Port: 9292
  )
  # :nocov:
end
