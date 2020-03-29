--
-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2018/8/4
-- Desc: send nginx access log to kafka
--

-- local BasePlugin = require "kong.plugins.base_plugin"
local basic_serializer = require "kong.plugins.openapi-kafka-log.custom-basic"
local cjson = require "cjson"
local kafka_producer = require "kong.plugins.openapi-kafka-log.kafka.producer"

local OpenApiLogHandler = {}

OpenApiLogHandler.PRIORITY = 7
OpenApiLogHandler.VERSION = "1.0.0"


---从右侧遍历字符串，取指定字符的前后字符串
-- @param strurl  待解取字符串；
--        strchar 指定字符串；
--        bafter= true 取指定字符后字符串
-- @return 截取后的字符串
-- end --
local function string_helper( strurl, strchar, bafter)
  local ts = string.reverse(strurl)
  local param1, param2 = string.find(ts, strchar)
  local m = string.len(strurl) - param2 + 1
  local result
  if (bafter == true) then
      result = string.sub(strurl, m+1, string.len(strurl))
  else
      result = string.sub(strurl, 1, m-1)
  end
  return result
end

-- get int part
local function get_int_part(x)
  if x<= 0 then
      return math.ceil(x)
  end
  if math.ceil(x) == x then
      x = math.ceil(x)
  else
      x = math.ceil(x)-1
  end
  return x
end

-- send all log to kafka
local function send_log_to_kafka(premature, conf, message)
  if premature then
    return
  end

  local ok, err
  local broker_list = {}
  local topic = conf.kafka_topic

  for i=1,#conf.kafka_broker_list do
    tb_tmp = {}
    tb_tmp.host = string_helper(conf.kafka_broker_list[i],':',false)
    tb_tmp.port = string_helper(conf.kafka_broker_list[i],':',true)
    -- ngx.log(ngx.ERR, "host:"..tb_tmp.host.." port:"..tb_tmp.port)
    broker_list[#broker_list+1]=tb_tmp
  end

  local bp = kafka_producer:new(broker_list, { producer_type = "async", batch_num = 500, keepalive_size = 200, keepalive_timeout = 5000 })
  local p_key = tostring(os.clock())
  local ok, err = bp:send(topic, p_key, message)
  if not ok then
      ngx.log(ngx.ERR, "failed to send log: ", err)
      return
  end
end

-- func lijian add for get appname and teamid and cluster_id
function get_appname_and_teamid_and_clusterid(_name)
    local str_split = "__"
    local app_name, team_id,cluster_id = nil,nil,nil
    local p_app = string.find(_name,str_split)
    if p_app ~= nil then
        app_name = string.sub(_name,1,p_app-1)
        local sub_team = string.sub(_name,p_app+#str_split,#_name)
        local p_team = string.find(sub_team,str_split)
        if p_team ~= nil then
            team_id = string.sub(sub_team,1,p_team-1)
            local sub_cluster = string.sub(sub_team,p_team+#str_split,#sub_team)
            local p_cluster = string.find(sub_cluster,str_split)
            if p_cluster ~= nil then
              cluster_id = string.sub(sub_cluster,1,p_cluster-1)
            end
        end
    end
    return app_name,team_id,cluster_id
end

function OpenApiLogHandler:log(conf)
  -- OpenApiLogHandler.super.log(self)
  -- get log message
  local message = basic_serializer.serialize(ngx)
  -- get team_id and app_name and cluster_id
  local service = message["service"]
  if service ~= nil then
    local service_name = service["name"]
    local app_name,team_id,cluster_id = get_appname_and_teamid_and_clusterid(service_name)
    -- app name
    if app_name ~= nil then
      message["app_name"] = app_name
    end
    -- team id
    if team_id ~= nil then
      message["team_id"] = team_id
    end
    -- cluster id
    if cluster_id ~= nil then
      message["cluster_id"] = cluster_id
    end
  end
  -- upstream addr
  if ngx.var.upstream_addr ~= nil and string.len(ngx.var.upstream_addr) ~= 0 then
      message["upstream_addr"] = ngx.var.upstream_addr
  end
  
  -- server_addr
  if ngx.var.server_addr ~= nil and string.len(ngx.var.server_addr) ~= 0 then
      message["server_addr"] = ngx.var.server_addr
  end
 
  -- @timestamp
  -- local tmp = ngx.req.start_time()
  -- local tmp_date = os.date("%Y-%m-%dT%H:%M:%S",ngx.req.start_time())
  -- local result = get_int_part((tmp-get_int_part(tmp))* 1000)
  -- message["@timestamp"] = tmp_date.."."..result.."Z"
  message["@timestamp"] = message["started_at_date"]..".000Z"
  
  -- send log message
  local msg = cjson.encode(message)
  -- ngx.log(ngx.ERR,msg)
  local ok, err = ngx.timer.at(0, send_log_to_kafka, conf, msg)
  if not ok then
    ngx.log(ngx.ERR, "[".. self._name .."] failed to create timer: ", err)
  end

end

return OpenApiLogHandler
