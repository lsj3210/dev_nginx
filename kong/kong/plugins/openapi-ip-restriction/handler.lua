-- local BasePlugin = require "kong.plugins.base_plugin"
local iputils = require "resty.iputils"


local FORBIDDEN = 403


-- cache of parsed CIDR values
local cache = {}


local IpRestrictionHandler = {}

IpRestrictionHandler.PRIORITY = 990
IpRestrictionHandler.VERSION = "2.0.0"

local function cidr_cache(cidr_tab)
  local cidr_tab_len = #cidr_tab
  local parsed_cidrs = kong.table.new(cidr_tab_len, 0) -- table of parsed cidrs to return

  -- build a table of parsed cidr blocks based on configured
  -- cidrs, either from cache or via iputils parse
  -- TODO dont build a new table every time, just cache the final result
  -- best way to do this will require a migration (see PR details)
  for i = 1, cidr_tab_len do
    local cidr        = cidr_tab[i]
    local parsed_cidr = cache[cidr]

    if parsed_cidr then
      parsed_cidrs[i] = parsed_cidr

    else
      -- if we dont have this cidr block cached,
      -- parse it and cache the results
      local lower, upper = iputils.parse_cidr(cidr)
      cache[cidr] = { lower, upper }
      parsed_cidrs[i] = cache[cidr]
    end
  end

  return parsed_cidrs
end

-- function IpRestrictionHandler:new()
--   IpRestrictionHandler.super.new(self, "ip-restriction")
-- end

function IpRestrictionHandler:init_worker()
  -- IpRestrictionHandler.super.init_worker(self)
  local ok, err = iputils.enable_lrucache()
  if not ok then
    kong.log.err("could not enable lrucache: ", err)
  end
end
local function getIP()
    local ClientIP = ngx.req.get_headers()["X-Real-IP"]
    if ClientIP == nil then
        ClientIP = ngx.req.get_headers()["X-Forwarded-For"]
        if ClientIP then
            local colonPos = string.find(ClientIP, ' ')
            if colonPos then
                ClientIP = string.sub(ClientIP, 1, colonPos - 1) 
            end
        end
    end
    if ClientIP == nil then
        ClientIP = ngx.var.remote_addr
    end
    if ClientIP then 
        ClientIP = ClientIP
    end
    return ClientIP
end
function IpRestrictionHandler:access(conf)
  -- IpRestrictionHandler.super.access(self)
  local block = false
  local binary_remote_addr = ngx.var.binary_remote_addr

  if not binary_remote_addr then
    return kong.response.exit(FORBIDDEN, { message = "Cannot identify the client IP address, unix domain sockets are not supported." })
  end

  local ip = getIP()
  if conf.iswhite and #conf.list > 0 then
     block = not iputils.ip_in_cidrs(ip, cidr_cache(conf.list))
  else
     block = iputils.ip_in_cidrs(ip, cidr_cache(conf.list))
  end

  if block then
    return kong.response.exit(FORBIDDEN, { message = "Your IP address is not allowed" })
  end
end

return IpRestrictionHandler