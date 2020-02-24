# frozen_string_literal: true

require "rack"
require "sequel"
require "rgeo/geo_json"

module Rack
  class GeojsonRackApp
    # connect to the POSTGRES server
    DB = Sequel.connect("postgres://geojson:geojson@localhost:5432/geojson_development")
    DB.run("CREATE TABLE IF NOT EXISTS geojson_points (point_id serial PRIMARY KEY, point_geom geometry(POINT), srid integer DEFAULT 3857)")
    @result = nil
    # evn is the environment, containing QUERY_STRING, REQUEST_METHOD, SERVER_NAME, etc. This is how geojson data will be fed to the app
    def call(env)
      # Read the input from the user
      input = env["rack.input"].read
      srid = "3857"
      # If an SRID is supplied, use it in place of our default
      if JSON.parse(input)["srid"].to_s != ""
        srid = JSON.parse(input)["srid"].to_s
      end
      # User is giving geojson points; add them to table
      if env["REQUEST_METHOD"] == "POST" && env["CONTENT_TYPE"] == "application/geo+json"
        # Statement to retrieve all X coordinates from the input points
        x_parser = "SELECT ST_X((ST_DumpPoints(ST_GeomFromEWKT(?))).geom)"
        # Statement to retrieve all Y coordinates from the input points
        y_parser = "SELECT ST_Y((ST_DumpPoints(ST_GeomFromEWKT(?))).geom)"
        decoded_input = RGeo::GeoJSON.decode(input)
        # If the decoded input lacks a as_text method, then it is not valid geojson input;
        # return an error code to the requester
        unless decoded_input.class.method_defined? :as_text
          content = "Input is not a valid geojson type."
          length = content.length.to_s
          return [500, {CONTENT_TYPE => "text/html", CONTENT_LENGTH => length}, [content]]
        end
        x_coords = DB[x_parser, RGeo::GeoJSON.decode(input).as_text].all
        y_coords = DB[y_parser, RGeo::GeoJSON.decode(input).as_text].all

        x_coords.each_with_index do |x_coord, index|
          puts "X/Y : " + x_coord[:st_x].to_s + "/" + y_coords[index][:st_y].to_s
          # put point into table; "all" invocation is necessary for data to be commited to DB; save as 3857 for distance calculations
          DB["INSERT INTO geojson_points(point_geom, srid) VALUES (ST_GeomFromEWKT('POINT(? ?)'), ?)", x_coord[:st_x], y_coords[index][:st_y], srid].all
        end
      elsif env["REQUEST_METHOD"] == "GET" # Endpoint 2 or 3; if given a point and an int, calc the points with radius; if a polygon, find points within it
        decoded_input = RGeo::GeoJSON.decode(input)
        puts "CLASS: " + decoded_input.class.to_s
        if decoded_input.class.to_s == "RGeo::Cartesian::PointImpl"
          puts "Decoded input: " + decoded_input.as_text
          puts "Radius: " + JSON.parse(input)["radius"].to_s
          qs = "SELECT gp.point_id, ST_AsText(gp.point_geom) FROM geojson_points gp WHERE ST_DWithin(ST_GeomFromEWKT(?), gp.point_geom, ?) = TRUE"
          # Extended Well-Known text (EWKT)
          ewkt = "SRID=" + srid + ";" + decoded_input.as_text
          results = DB[qs, ewkt, JSON.parse(input)["radius"]]
          results.each do |r|
            puts "RADIUS RESULT: " + r.to_s
          end
        elsif decoded_input.class.to_s == "RGeo::Cartesian::PolygonImpl"
          qs = "SELECT gp.point_id FROM geojson_points gp WHERE ST_Contains(ST_GeomFromEWKT(?), gp.point_geom) = TRUE"
          # Extended Well-Known text (EWKT)
          ewkt = "SRID=" + srid + ";" + decoded_input.as_text
          # Append the SRID for distance calculations
          results = DB[qs, ewkt].all
          results.each do |r|
            puts "POLY RESULT: " + r.to_s
          end
        end
      end

      content = ""
      @result&.each do |row|
        row.each do |e|
          content += e.join(",")
        end
      end
      # Calculate the CONTENT_SIZE by tallying up the size of each element in the content array
      #  inject(0) means put the value 0 into the first element, ie. a
      length = content.length.to_s
      # Below is rack's response, consisting of a Status Code, Headers, and a Body.
      # For the GET requests to our app, this is where results will be returned to the user (ie, all points within radius of some point they gave us)
      [200, {CONTENT_TYPE => "text/html", CONTENT_LENGTH => length}, [content]]

    end

  end
end

# Start the Rack server, based on code from rack's lobster.rb example application
if $0 == __FILE__
  # :nocov:
  require_relative "../rack"
  Rack::Server.start(
      app: Rack::ShowExceptions.new(Rack::Lint.new(Rack::GeojsonRackApp.new)), Port: 9292
  )
  # :nocov:
end
