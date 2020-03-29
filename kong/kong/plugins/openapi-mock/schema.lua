-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/9/3
-- Desc: abtest plugin 
--

local typedefs = require "kong.db.schema.typedefs"

return {
    name = "openapi-mock",
    fields = {
        { consumer = typedefs.no_consumer },
        { run_on = typedefs.run_on_first },
        { protocols = typedefs.protocols_http },
        { config = { 
            type     = "record",
            required = true,
            fields = { 
                { mock = { 
                    type     = "record",
                    required = true,
                    fields = { 
                        { delay = { type = "number", between = { 0, 3000 }, default = 0 }, },
                        { body = { type = "string", required = true }, },
                        { code = { type = "number", default = 200 }, },
                        { headers = { 
                            type = "array",
                            required = true, 
                            elements = { 
                                type = "record",
                                fields = { 
                                    { key = { type = "string", required = true }, },
                                    { value = { type = "string", required = true }, },
                                },
                            },
                        }, },
                    },
                }, },
            },            
        }, },
    },
}