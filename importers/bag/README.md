# BAG importer

Running `ruby bag.rb` imports Dutch building and address data from the [BAG](http://www.kadaster.nl/BAG) into the CitySDK LD API. This data was used to create the [map of all 9,866,539 buildings in the Netherlands](http://code.waag.org/buildings/).

To run the BAG importer, you should have a PostgreSQL database containing the BAG data, as well as some CitySDK LD-specific views and tables. This is documented below.

By default, all scripts and documentation expect `bag` as the database name, and a PostgreSQL server running on localhost:5432, and `postgres` as user and password. You can change this by editing `config.json`, and the parameters in the `psql` call below.

## Download and import BAG data

Install PostgreSQL and PostGIS, download data from [NLExtract](http://nlextract.nl/) and import into database `bag`. Details can be found in [NLExtract's documentation](https://nlextract.readthedocs.org/en/latest/bagextract.html).

## Create CitySDK LD-specific BAG views and tables

The BAG importer needs some flattened and generalized, created by `bag.sql`. Before running the importer, run

    psql -h localhost -U postgres -f bag.sql -d bag
