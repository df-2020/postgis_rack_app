# frozen_string_literal: true

require "rack"
require "sequel"
require "rgeo/geo_json"

module Rack
  class GeojsonRackApp
    # Connect to the POSTGRES server and save the connection as a constant
    DB = Sequel.connect("postgres://geojson:geojson@localhost:5432/geojson_development")
    # If the geojson_points table does not exist in our DB, create it
    DB.run("CREATE TABLE IF NOT EXISTS geojson_points (point_id serial PRIMARY KEY, point_geom geometry(POINT), srid integer DEFAULT 3857)")
    @srid = nil
    @decoded_input = nil
    @result = nil
    # evn is the environment, containing QUERY_STRING, REQUEST_METHOD, SERVER_NAME, etc. This is how geojson data will be fed to the app
    def call(env)
      # Read the input from the user
      input = env["rack.input"].read
      # We've been given an array, presumably composed of point objects.
      # Decode them into GeoJSON and insert them
      if JSON.parse(input).class.to_s == "Array"
        return insert_array_of_points(input)
      end
      # If an SRID is supplied, use it. Oherwise, use our default.
      parsed_srid = JSON.parse(input)["srid"].to_s
      @srid = if !parsed_srid.nil? && !parsed_srid.empty?
        parsed_srid
      else
        @srid = "3857"
      end
      # Decode the input into GeoJSON
      @decoded_input = RGeo::GeoJSON.decode(input)
      # If the decoded input lacks a as_text method, then it is not valid GeoJSON Geometry;
      # return an error code to the requester
      unless @decoded_input.class.method_defined? :as_text
        content = "Input is not a valid GeoJSON Geometry type."
        return [500, {CONTENT_TYPE => "text/html", CONTENT_LENGTH => content.length.to_s}, [content]]
      end
      # User is giving geojson points; add them to table
      if env["REQUEST_METHOD"] == "POST" && env["CONTENT_TYPE"] == "application/geo+json"
        insert_points
      elsif env["REQUEST_METHOD"] == "GET"
        # The input is a Point; find all other points within the given radius
        if @decoded_input.class.to_s == "RGeo::Cartesian::PointImpl"
          radius = JSON.parse(input)["radius"]
          points_within_radius(radius)
        # The input is a Polygon; find all points that lie within the polygon
        elsif @decoded_input.class.to_s == "RGeo::Cartesian::PolygonImpl"
          points_within_polygon
        # The Input is invalid
        else
          content = "Invalid GeoJSON object; Please GET with only a GeoJSON Point or Polygon."
          [500, {CONTENT_TYPE => "text/html", CONTENT_LENGTH => content.length.to_s}, [content]]
        end
      else
        content = "Invalid request; Please issue a GET with either a GeoJSON Polygon, or a GeoJSON Point with an integer radius, or issue a POST with an array of GeoJSON Points or a GeometryCollection."
        [500, {CONTENT_TYPE => "text/html", CONTENT_LENGTH => content.length.to_s}, [content]]
      end
    end

    private

    # Method to insert points from a POST request into our DB
    def insert_points
      # Retrieve all X coordinates from the input points
      x_parser = "SELECT ST_X((ST_DumpPoints(ST_GeomFromEWKT(?))).geom)"
      x_coords = DB[x_parser, @decoded_input.as_text].all
      # Retrieve all Y coordinates from the input points
      y_parser = "SELECT ST_Y((ST_DumpPoints(ST_GeomFromEWKT(?))).geom)"
      y_coords = DB[y_parser, @decoded_input.as_text].all

      x_coords.each_with_index do |x_coord, index|
        # put point into table; "all" invocation is necessary for data to be commited to DB; save SRID into point's geometry as well as in table column
        DB["INSERT INTO geojson_points(point_geom, srid) VALUES (ST_GeomFromEWKT('SRID=?;POINT(? ?)'), ?)", Integer(@srid), x_coord[:st_x], y_coords[index][:st_y], @srid].all
      end
      content = "Inserted " + x_coords.length.to_s + " points into the database."
      [200, {CONTENT_TYPE => "text/html", CONTENT_LENGTH => content.length.to_s}, [content]]
    end

    # Method to calculate which points in our DB fall within the given radius value from a given point
    def points_within_radius(radius)
      qs = "SELECT gp.point_id, ST_AsText(gp.point_geom) FROM geojson_points gp WHERE ST_DWithin(ST_GeomFromEWKT(?), gp.point_geom, ?) = TRUE"
      # Extended Well-Known text (EWKT)
      ewkt = "SRID=" + @srid + ";" + @decoded_input.as_text
      results = DB[qs, ewkt, radius].all
      content = results.to_json #convert to geojson
      [200, {CONTENT_TYPE => "application/geo+json", CONTENT_LENGTH => content.length.to_s}, [content]]
    end

    # Method to determine which points in our DB fall within a given Polygon from a GET request
    def points_within_polygon
      qs = "SELECT gp.point_id FROM geojson_points gp WHERE ST_Contains(ST_GeomFromEWKT(?), gp.point_geom) = TRUE"
      # Extended Well-Known text (EWKT)
      ewkt = "SRID=" + @srid + ";" + @decoded_input.as_text
      # Append the SRID for distance calculations
      results = DB[qs, ewkt].all
      content = results.to_json #convert to geojson?
      [200, {CONTENT_TYPE => "application/geo+json", CONTENT_LENGTH => content.length.to_s}, [content]]
    end

    def insert_array_of_points(array_of_points)
      # Initialize SRID
      @srid = "3857"
      number_of_inserts = 0
      JSON.parse(array_of_points).each do |point|
        @decoded_input = RGeo::GeoJSON.decode(point)
        insert_points
        number_of_inserts += 1
      end
      content = "Inserted " + number_of_inserts.to_s + " points into the database."
      [200, {CONTENT_TYPE => "text/html", CONTENT_LENGTH => content.length.to_s}, [content]]
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
