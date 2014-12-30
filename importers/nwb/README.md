# NWB importer

Imports all road segments from [Nationaal Wegenbestand](https://data.overheid.nl/data/dataset/nationaal-wegen-bestand-wegen-wms) into  CitySDK-LD. Expects local PostgreSQL database `ndw`, containing table `wegvakken`. NWB roads are used to link with traffic data from [NDW](http://ndw.nu/). See this [github repo](https://github.com/waagsociety/ndw) on how to create this NDW database.

See `ndw` [repository](https://github.com/waagsociety/ndw) for information about obtaining data, creating NDW database, and details about linking NDW DATEX II real-time traffic flow data to NWB road segments.


