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
        "coordinates": [30.471165, -91.147385] # Baton Rouge
      }, {
        "type": 'LineString',
        "coordinates": [
          [29.951065, -90.071533], # New Orleans
          [29.945504, -89.961602] # Chalmette
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
      "coordinates": [29.90222, -90.02944] # Terrytown
    }, {
      "type": 'Point',
      "coordinates": [30.36917, -90.07806] # Mandeville
    }, {
      "type": 'Point',
      "coordinates": [30.4958, -90.1975] # Goodbee
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
      "coordinates": [29.99778, -90.17750], # Metairie
      "radius": 30000
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body

    assert_equal('200', response.code)
    assert_equal('OK', response.message)

    req.body = {
        "type": 'Point',
        "coordinates": [30.40722, -90.16167], # Madisonville
        "radius": 25000
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body

    assert_equal('200', response.code)
    assert_equal('OK', response.message)

    req.body = {
        "type": 'Point',
        "coordinates": [40.71427, -74.00597], # New York City, New York
        "radius": 19000
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body

    assert_equal('200', response.code)
    assert_equal('OK', response.message)
  end

  ##
  # Test cases for determining which points fall within the area of the given polygon
  def test_polygon_function
    uri = URI('http://localhost:9292/')
    req = Net::HTTP::Get.new(uri)

    req.body = {
      "type": 'Polygon',
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
    puts response.body

    assert_equal('200', response.code)
    assert_equal('OK', response.message)

    req.body = {
        "type": 'Polygon',
        "coordinates": [
            [
                [30.471165, -91.147385], # Baton Rouge
                [30.36917, -90.07806], # Mandeville
                [29.90222, -90.02944], # Terrytown
                [30.471165, -91.147385] # Baton Rouge
            ]
        ]
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body

    assert_equal('200', response.code)
    assert_equal('OK', response.message)

    req.body = {
        "type": 'Polygon',
        "coordinates": [
            [
                [40.71427, -74.00597], # New York City, New York
                [30.26715, -97.74306], # Austin, Texas
                [27.94752, -82.45843], # Tampa, Florida
                [40.71427, -74.00597] # New York City, New York
            ]
        ]
    }.to_json
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    puts response.body

    assert_equal('200', response.code)
    assert_equal('OK', response.message)
  end
end
