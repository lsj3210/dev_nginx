local typedefs = require "kong.db.schema.typedefs"

return {
  name = "openapi-kafka-log",
  fields = {
    { config = {
        type = "record",
        fields = {
          { kafka_broker_list = { required = true, type = "array", elements = { type = "string" }, },  },
          { kafka_topic = { required = true, type = "string"  },  },
        },
    }, },
  }
}
