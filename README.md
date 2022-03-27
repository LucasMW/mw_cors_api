# MW_CORS_API Server

Implements an API for proxying requests.
It also implements other non generic requests

## Running the server
for http:

    usage: ./cors_api.exe [port]

for https:

    usage: ./cors_api.exe [port] [certificate_path] [key_path]

use: --debug for enabling localhost

## Using the API

POST /json 
send request descriptor in the body

#### for HTTP.GET:
    {
        "method" : "get",
        "url" : "https://trends.gab.com/trend-feed/json",
        "headers":  {:}
    }

#### for HTTP.POST:
    {
        "method" : "get",
        "url" : "https://trends.gab.com/trend-feed/json",
        "body": {...},
        "headers": {:}
    }
