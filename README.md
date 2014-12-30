# CitySDK LD API - Amsterdam instance

Data importers, demos and web service daemons for the [Amsterdam instance](http://api.citysdk.waag.org) of the [CitySDK LD API](https://github.com/waagsociety/citysdk-ld).

All importers need the `CITYSDK_CONFIG` environment variable set to the path of a CitySDK LD API configuration file. This file specifies an API endpoint URL, as well as login credentials. An example file is available in the [CitySDK LD repository](https://github.com/waagsociety/citysdk-ld/blob/master/config.example.json). You can set `CITYSDK_CONFIG` with `export`:

    export CITYSDK_CONFIG=<path to CitySDK configuration file>
