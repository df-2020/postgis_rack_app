require_relative "geojson_rack_app"
require "test/unit"

class GeojsonRackAppTester < Test::Unit::TestCase
  def test_point_posting
    uri = URI("http://localhost:9292/")

    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/geo+json")

    req.body = {
        "type": "LineString",
        "coordinates": [
            [0.0, 0.0],
            [1.0, 1.0]
        ],
        "srid": 4001
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body, response.code, response.message, response.header.inspect

    req.body = {
        "type": "Feature",
        "geometry": {
            "type": "Point",
            "coordinates": [125.6, 10.1]
        },
        "properties": {
            "name": "Dinagat Islands"
        },
        "srid": 4002
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body, response.code, response.message, response.header.inspect

    # There is a limitation with rgeo/geo_json where it will throw an error when given an invalid polygon;
    # as a result, the below case is commented out until a workaround is found.
    # req.body = {
    #     "type": "Polygon",
    #     "coordinates": [
    #         [
    #             [2.0, 6.0],
    #             [3.0, 5.0],
    #             [4.0, 4.0],
    #             [5.0, 3.0],
    #             [6.0, 2.0]
    #         ]
    #     ]
    # }.to_json
    # response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    #   http.request(req)
    # end
    # puts response.body, response.code, response.message, response.header.inspect

    req.body = {
				"type": "MultiLineString",
        "coordinates": [
            [
                [7.0, 0.0],
                [8.0, 1.0]
            ],
            [
                [9.0, 2.0],
                [10.0, 3.0]
            ]
        ],
        "srid": 4003
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body, response.code, response.message, response.header.inspect


    req.body = {
        "type": "GeometryCollection",
        "geometries": [{
                           "type": "Point",
                           "coordinates": [102.5, 5.5]
                       }, {
                           "type": "LineString",
                           "coordinates": [
                               [101.0, 0.0],
                               [102.0, 1.0]
                           ]
                       }]
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body, response.code, response.message, response.header.inspect
  end

  def test_radius_function
    uri = URI("http://localhost:9292/")
    req = Net::HTTP::Get.new(uri)

    req.body = {
        "type": "Point",
        "coordinates": [100.0, 0.0],
        "radius": 3
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body, response.code, response.message, response.header.inspect
  end

  def test_polygon_function
    uri = URI("http://localhost:9292/")
    req = Net::HTTP::Get.new(uri)

    req.body = {
        "type": "Polygon",
        "coordinates": [
            [
								[102.0, 6.0],
                [102.0, 5.0],
                [103.0, 5.0],
                [103.0, 6.0],
                [102.0, 6.0]
            ]
        ]
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body, response.code, response.message, response.header.inspect
  end
end
