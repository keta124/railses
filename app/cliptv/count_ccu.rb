require 'elasticsearch'
require_relative 'influx_connection'
class Cliptv
  class << self
    def get_data_es
      client = Elasticsearch::Client.new host:'192.168.142.100:9200'
      index = 'logstash-*'
      body = {
        "size": 0,
        "query": {
          "filtered": {
            "query": {
              "query_string": {
                "query": "response:[200 TO 299]",
                "analyze_wildcard": true
              }
            },
            "filter": {
              "range": {
                "time_write_log": {
                  "gte": "now-10d",
                  "lte": "1513036800",
                  "format": "epoch_second"
                }
              }
            }
          }
        },
        "aggs": {
          "timestamp": {
            "date_histogram": {
              "field": "time_write_log",
              "interval": "15m",
              "time_zone": "Asia/Jakarta",
              "min_doc_count": 1
            },
            "aggs": {
              "num_ip": {
                "cardinality": {
                  "field": "client_ip.raw",
                  "precision_threshold": 10000
                }
              }
            }
          }
        }
      }
      response = client.search index: index, body: body
      response["aggregations"]["timestamp"]["buckets"].map{|e| [e["key"],e["num_ip"]["value"]]}
    end
    def execute
      es_data = get_data_es
      es_data.each do |a|
        point = {
                values: {
                  ccu: a[1]
                },
                timestamp: (a[0]/1000).to_i
              }
        InfluxConnection.connection.write_point 'cliptv_ccu', point
      end
    end
  end
end
Cliptv.execute