--
-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2018/8/4
-- Desc: send nginx access log to kafka
--

local BasePlugin = require "kong.plugins.base_plugin"
local basic_serializer = require "kong.plugins.auto-log.basic"
local cjson = require "cjson"
local kafka_producer = require "resty.kafka.producer"
local url = require "socket.url"
local string_format = string.format

local AutoLogHandler = {}

AutoLogHandler.PRIORITY = 7
AutoLogHandler.VERSION = "2.0.0"

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

-- 判断元素是否在array中
local function is_in_array(b,list)
  if not list then
    return false
  end
  if list then
    for k, v in pairs(list) do
      if v.tableName ==b then
        return true
      end
    end
  end
end

--判断元素是否存在table中
function is_in_table(value, tbl)
  for k,v in ipairs(tbl) do
    if v == value then
      return true;
    end
  end
  return false;
end

-- 生成http请求字符串
local function generate_post_payload(method, content_type, parsed_url, body)
  local url
  if parsed_url.query then
    url = parsed_url.path .. "?" .. parsed_url.query
  else
    url = parsed_url.path
  end
  local headers = string_format(
    "%s %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: %s\r\nContent-Length: %s\r\n",
    method:upper(), url, parsed_url.host, content_type, #body)
  if parsed_url.userinfo then
    local auth_header = string_format(
      "Authorization: Basic %s\r\n",
      ngx.encode_base64(parsed_url.userinfo)
    )
    headers = headers .. auth_header
  end
  --ngx.log(ngx.ERR,string_format("%s\r\n%s", headers, body))
  return string_format("%s\r\n%s", headers, body)
end

-- 解析url
local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == HTTP then
      parsed_url.port = 80
     elseif parsed_url.scheme == HTTPS then
      parsed_url.port = 443
     end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end
  return parsed_url
end

-- 发送错误日志到http服务
local function send_error(premature, conf, body, name)
  if premature then
    return
  end
  name = "[" .. name .. "] "

  local ok, err
  local parsed_url = parse_url(conf.http_addr)
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)

  local sock = ngx.socket.tcp()
  sock:settimeout(10000)

  ok, err = sock:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  if parsed_url.scheme == HTTPS then
    local _, err = sock:sslhandshake(true, host, false)
    if err then
      ngx.log(ngx.ERR, name .. "failed to do SSL handshake with " .. host .. ":" .. tostring(port) .. ": ", err)
    end
  end

  ok, err = sock:send(generate_post_payload("POST", "application/json", parsed_url, body))
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
  end

  ok, err = sock:setkeepalive(60000)
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to keepalive to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end
end

-- 发送全量日志到kafka服务
local function send_all(premature, conf, message)
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

  local bp = kafka_producer:new(broker_list, { producer_type = "async" })
  local p_key = tostring(os.clock())
  local ok, err = bp:send(topic, p_key, message)
  if not ok then
      ngx.log(ngx.ERR, "[".. self._name .."] failed to send log: ", err)
      return
  end
end

-- function AutoLogHandler:new()
--   AutoLogHandler.super.new(self, "auto-log")
-- end

function AutoLogHandler:log(conf)
 --  AutoLogHandler.super.log(self)
  -- 1.发送错误日志到http server
  --ngx.log(ngx.ERR,ngx.status)
  --ngx.log(ngx.ERR,conf.error_report[1])
  --switch = conf.error_report[1]
  --if switch == "on" then
  --  local tmp = is_in_table(tostring(ngx.status),conf.error_status)

  --  if tmp then
  --    local error_msg = cjson.encode(basic_serializer.serialize_error(ngx))
  --    local ok, err = ngx.timer.at(0, send_error, conf, error_msg, self._name)
  --    if not ok then
  --      ngx.log(ngx.ERR, "[" .. self._name .. "] failed to create timer: ", err)
  --    end
  --  end
  -- end

  -- 2.发送全量日志到kafka
  -- local message = cjson.encode(basic_serializer.serialize_all(ngx))
  -- local message = cjson.encode(basic_serializer.serialize_part(ngx))
  local message = basic_serializer.serialize_new(ngx)
  --ngx.log(ngx.ERR,message)
  local ok, err = ngx.timer.at(0, send_all, conf, message)
  if not ok then
    ngx.log(ngx.ERR, "[".. self._name .."] failed to create timer: ", err)
  end
end

return AutoLogHandler
