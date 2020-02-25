# postgis_rack_app
Rack application with a postGIS database. Performs simple functions based on user input.

This rack application has three functions:

-It can take an array of GeoJSON Points or a GeometryCollection in a POST request, and insert them into its postgres database.

-If sent a GET request with a GeoJSON Point and a radius integer, it will return all points within a number of meters equal to the radius of the given point.

-If sent a GET request with a GeoJSON Polygon, it will return all points that fall within that polygon

This program requires an instance of Postgres 9.4 with PostGIS 2.5 installed. A fitting docker container with usage instructions can be found here:

https://hub.docker.com/r/mdillon/postgis

To start the docker instance, install docker-compose, navigate to the directory with your docker-compose.yml file, and run the following command in a terminal:

`docker-compose up -d db`

To start the rack server, run the following command in a terminal:

`/path/to/rackup -Ilib /path/to/geojson_rack_app.ru`

To run the test suite, run the following command while the rack server is running:

`ruby /path/to/geojson_rack_app_tester.rb`

To lint the files, install the rubocop gem and run the following command in a terminal:

`rubocop -a /path/to/file`

To render the software documentation, install rdoc and navigate to the project directory, then run the following command:

`rdoc`
