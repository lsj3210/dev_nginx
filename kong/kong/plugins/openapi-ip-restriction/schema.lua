local typedefs = require "kong.db.schema.typedefs"


return {
  name = "openapi-ip-restriction",
  fields = {

    { run_on = typedefs.run_on_first },
    { config = {
        type = "record",
        fields = {
        
          { list = { type = "array", required = true ,elements = typedefs.cidr, }, },
          { iswhite = {type = "boolean", default = true, }, },
        },
      },
    },
  }
}
