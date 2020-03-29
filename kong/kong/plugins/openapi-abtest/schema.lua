-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/8/12
-- Desc: abtest plugin 
--

local typedefs = require "kong.db.schema.typedefs"

local STAT_TYPE = {
    "subnet",
    "weight",
    "cookie",
    "arg",
    "header",
    "region",
}

local STAT_REPORT_SWITCH = {
    "on",
    "off",
}

local STAT_STATUS = {
    "init",
    "runing",
    "pause",
    "end",
}

return {
    name = "openapi-abtest",
    fields = { 
        { consumer = typedefs.no_consumer },
        { run_on = typedefs.run_on_first },
        { protocols = typedefs.protocols_http },
        { config = {
            type     = "record",
            required = true,
            fields = {
                { abtest = { 
                    type     = "array",
                    required = true,
                    elements = { 
                        type   = "record",
                        fields = { 
                            { case_id   = { type = "string", required = true }, }, -- id
                            { name = { type = "string", required = true }, }, -- name
                            { desc = { type = "string" }, }, -- desc
                            { rule = { type = "string", one_of = STAT_TYPE, default = "subnet", required = true }, }, -- type
                            { urls = { 
                                type = "array",
                                required = true, 
                                elements = { 
                                    type = "record",
                                    fields = {
                                        { url = { type = "string", required = true }, }, -- url
                                        { version = { type = "string", required = true }, }, -- version
                                        { conf_object = { 
                                            type   = "record",
                                            fields = { 
                                                { key = { type = "string" }, },
                                                { value = { type = "string" }, },
                                            }, 
                                        }, }, -- cookie/arg/header conf
                                        { conf_array = { type = "array", elements = { type = "string" }, }, }, -- subnet/region conf
                                        { conf_num = { type = "number", between = { 0, 100 }, }, }, --weight conf
                                    },
                                },
                            }, },
                            { report = { 
                                type = "record",
                                fields = { 
                                    { switch = { type = "string", one_of = STAT_REPORT_SWITCH, default = "off" }, },
                                    { who = { type = "array", default = {}, elements = { type = "string" }, }, },
                                },
                            }, }, -- report
                            { interval = { 
                                type = "record",
                                fields = { 
                                    { start_date = { type = "string" }, },
                                    { stop_date = { type = "string" }, },
                                },
                            }, }, -- time interval
                            { status = { type = "string", one_of = STAT_STATUS, required = true, default = "init" }, }, -- status
                        }, 
                    },
                },},
            },
        }, },
    },
}