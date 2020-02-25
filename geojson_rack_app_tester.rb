# frozen_string_literal: true

require_relative 'geojson_rack_app'
require 'test/unit'

##
# Tester for the GeojsonRackApp. Submits requests to the application, and compares the results to expected outputs.
class GeojsonRackAppTester < Test::Unit::TestCase
  ##
  # Test cases for sending points via a POST request
  def test_point_posting
    uri = URI('http://localhost:9292/')

    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/geo+json')

    req.body = {
      "type": 'LineString',
      "coordinates": [
        [0.0, 0.0],
        [1.0, 1.0]
      ],
      "srid": 4001
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    assert_equal('200', response.code)
    assert_equal('OK', response.message)

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

    req.body = {
      "type": 'MultiLineString',
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

    assert_equal('200', response.code)
    assert_equal('OK', response.message)

    req.body = {
      "type": 'GeometryCollection',
      "geometries": [{
        "type": 'Point',
        "coordinates": [-91.147385, 30.471165] # Baton Rouge
      }, {
        "type": 'LineString',
        "coordinates": [
          [-90.071533, 29.951065], # New Orleans
          [-89.961602, 29.945504] # Chalmette
        ]
      }]
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    assert_equal('200', response.code)
    assert_equal('OK', response.message)

    req.body = [{
      "type": 'Point',
      "coordinates": [-90.02944, 29.90222] # Terrytown
    }, {
      "type": 'Point',
      "coordinates": [-90.07806, 30.36917] # Mandeville
    }, {
      "type": 'Point',
      "coordinates": [-90.1975, 30.4958] # Goodbee
    }].to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    assert_equal('200', response.code)
    assert_equal('OK', response.message)
  end

  ##
  # Test cases for determining which points fall within the radius of a given point
  def test_radius_function
    uri = URI('http://localhost:9292/')
    req = Net::HTTP::Get.new(uri)

    req.body = {
      "type": 'Point',
      "coordinates": [-90.17750, 29.99778], # Metairie
      "radius": 3000
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    assert_equal('200', response.code)
    assert_equal('OK', response.message)
    assert_equal('[]', response.body)

    req.body = {
        "type": 'Point',
        "coordinates": [-90.16167, 30.40722], # Madisonville
        "radius": 10000
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    assert_equal('200', response.code)
    assert_equal('OK', response.message)
    assert_equal('[{"point":"POINT(-90.07806 30.36917)"}]', response.body)

    req.body = {
        "type": 'Point',
        "coordinates": [-74.00597, 40.71427], # New York City, New York
        "radius": 19000
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    assert_equal('200', response.code)
    assert_equal('OK', response.message)
    assert_equal('[]', response.body)
  end

  ##
  # Test cases for determining which points fall within the area of the given polygon
  def test_polygon_function
    uri = URI('http://localhost:9292/')
    req = Net::HTTP::Get.new(uri)

    req.body = {
      "type": 'Polygon', # Polygon with no points inside it
      "coordinates": [
        [
          [67.0, 6.0],
          [67.0, 5.0],
          [68.0, 5.0],
          [68.0, 6.0],
          [67.0, 6.0]
        ]
      ]
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    assert_equal('200', response.code)
    assert_equal('OK', response.message)
    assert_equal('[]', response.body)

    req.body = {
        "type": 'Polygon', # Polygon which should contain New Orleans
        "coordinates": [
            [
                [-91.147385, 30.471165], # Baton Rouge
                [-90.07806, 30.36917], # Mandeville
                [-90.02944, 29.90222], # Terrytown
                [-91.147385, 30.471165] # Baton Rouge
            ]
        ]
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    assert_equal('200', response.code)
    assert_equal('OK', response.message)
    assert_equal('[{"point":"POINT(-90.071533 29.951065)"}]', response.body) # New Orleans

    req.body = {
        "type": 'Polygon', # Massive Polygon which should contain all Louisiana points (Something's wrong, doesn't contain Madisonville or Metairiefpt)
        "coordinates": [
            [
                [-74.00597, 40.71427], # New York City, New York
                [-97.74306, 30.26715], # Austin, Texas
                [-82.45843, 27.94752], # Tampa, Florida
                [-74.00597, 40.71427] # New York City, New York
            ]
        ]
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    assert_equal('200', response.code)
    assert_equal('OK', response.message)
    assert_equal('[{"point":"POINT(-91.147385 30.471165)"},{"point":"POINT(-90.071533 29.951065)"},{"point":"POINT(-89.961602 29.945504)"},{"point":"POINT(-90.02944 29.90222)"},{"point":"POINT(-90.07806 30.36917)"},{"point":"POINT(-90.1975 30.4958)"}]', response.body)
  end
end
