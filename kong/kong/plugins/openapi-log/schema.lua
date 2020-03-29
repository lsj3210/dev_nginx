local typedefs = require "kong.db.schema.typedefs"

return {
  name = "openapi-log",
  fields = {
    { config = {
        type = "record",
        fields = {
          { host = typedefs.host({ required = true }), },
          { port = typedefs.port({ required = true }), },
          { timeout = { type = "number", default = 10000 }, },
          { keepalive = { type = "number", default = 60000 }, },
          { tls = { type = "boolean", default = false }, },
          { tls_sni = { type = "string" }, },
        },
    }, },
  }
}
