-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/8/12
-- Desc: abtest plugin 
--

local ngx = ngx

local _M = {}

_M.TYPE_SUBNET  = "subnet"
_M.TYPE_WEIGHT  = "weight"
_M.TYPE_COOKIE  = "cookie"
_M.TYPE_ARG     = "arg"
_M.TYPE_HEADER  = "header"
_M.TYPE_REGION  = "region"

_M.H_TYPE_SUBNET  = "By-Subnet"
_M.H_TYPE_WEIGHT  = "By-Weight"
_M.H_TYPE_COOKIE  = "By-Cookie"
_M.H_TYPE_ARG     = "By-Arg"
_M.H_TYPE_HEADER  = "By-Header"
_M.H_TYPE_REGION  = "By-Region"
_M.H_TYPE_PASS    = "By-Pass"

_M.H_CASE_ID          = "ABTest-Case-Id"
_M.H_CASE_TYPE        = "ABTest-Case-Type"
_M.H_CASE_URI         = "ABTest-Uri"
_M.H_CASE_URI_VERSION = "ABTest-Uri-Version"

_M.X_REAL_IP = "X-Real-IP"
_M.X_F_F     = "X-Forwarded-For"

_M.STATUS_INIT   = "init"
_M.STATUS_START  = "runing"
_M.STATUS_PAUSE  = "pause"
_M.STATUS_FINISH = "end"

_M.KEY_ABTEST      = "abtest"
_M.KEY_ID          = "case_id"
_M.KEY_NAME        = "name"
_M.KEY_DESC        = "desc"
_M.KEY_RULE        = "rule"
_M.KEY_URLS        = "urls"
_M.KEY_URL         = "url"
_M.KEY_VERSION     = "version"
_M.KEY_CONF_OBJECT = "conf_object"
_M.KEY_KEY         = "key"
_M.KEY_VALUE       = "value"
_M.KEY_CONF_ARRAY  = "conf_array"
_M.KEY_CONF_NUM    = "conf_num"
_M.KEY_REPORT      = "report"
_M.KEY_SWITCH      = "switch"
_M.KEY_WHO         = "who"
_M.KEY_INTERVAL    = "interval"
_M.KEY_START_DATE  = "start_date"
_M.KEY_STOP_DATE   = "stop_date"
_M.KEY_STATUS      = "status"

_M.STR_PASS = "pass"

_M.NUM_WEIGHT_ALL = 100

_M.CONF_IPLIB_HOST = "lnglat.openapi.corpdemo.com"
_M.CONF_IPLIB_VIP  = "10.23.3.95"
_M.CONF_IPLIB_URL  = "/api/v2/ipArea/getArea?ipinfo="
_M.CONF_IPLIB_AUTH = "Basic Y2xvdWQtZ2F0ZXdheS1rb25nOkhpdW5pNDJ4TGE=" -- cloud-gateway-kong/Hiuni42xLa
_M.CONF_HTTP_TIMEOUT = 100
_M.CONF_HTTP_KEEPALIVE = 5000
_M.CONF_HTTP_CLIENT_POOL = 500



-- func for str split
function _M.str_split(_string, _pattern)
    local ret = {} 
    local fpat = "(.-)" .. _pattern
    local last_end = 1
    local s, e, cap = _string:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(ret,cap)
        end
        last_end = e+1
        s, e, cap = _string:find(fpat, last_end)
    end
    if last_end <= #_string then
        cap = _string:sub(last_end)
        table.insert(ret, cap)
    end
    return ret
end

-- func for get client ip
function _M.get_client_ip()
    local client_ip = ngx.req.get_headers()[_M.X_REAL_IP]
    if client_ip == nil then
        client_ip = ngx.req.get_headers()[_M.X_F_F]
        if client_ip then
            local pos = string.find(client_ip, ' ')
            if pos then
                client_ip = string.sub(client_ip, 1, pos - 1)
            end
        end
    end
    if client_ip == nil then
        client_ip = ngx.var.remote_addr
    end
    return client_ip
end


-- func for get Ranom by weight
function _M.get_ranom_by_weight(items, weights)
    local sum = 0
    for i = 1, #weights do
        sum = sum + weights[i]
    end
    -- math.randomseed(tostring(ngx.now()):reverse():sub(1, 6))
    local compare = math.random(1, sum)
    local index = 1
    while sum > 0 do
        sum = sum - weights[index]
        if sum < compare then
            return items[index]
        end
        index = index + 1
    end
    return nil
end

-- func for check region
function _M.check_region(_client_ip, _province)
    local ret = false

    local req_url_tb = {}
    table.insert(req_url_tb, "http://")
    table.insert(req_url_tb, _M.CONF_IPLIB_VIP)
    table.insert(req_url_tb, _M.CONF_IPLIB_URL)
    table.insert(req_url_tb, _client_ip)
    local req_url = table.concat(req_url_tb, "")

    local http = require "kong.plugins.openapi-abtest.http"
    local http_conn = http.new()
    http_conn:set_timeout(_M.CONF_HTTP_TIMEOUT)
    local res, err = http_conn:request_uri(req_url, {
        method = "GET",
        headers = {
            ["Content-Type"] = "application/json",
            ["Host"]= _M.CONF_IPLIB_HOST,
            ["Authorization"] = _M.CONF_IPLIB_AUTH,
        },
        keepalive_timeout = _M.CONF_HTTP_TIMEOUT,
        keepalive_pool = _M.CONF_HTTP_CLIENT_POOL
    })
    if not res then
        kong.log.err("failed to send http request: ", err)
    else
        local status = res.status
        if status == 200 then
            local tmp = require("cjson").decode(res.body)
            if tmp["message"] == "ok" and tmp["result"] ~= nil and tmp["result"]["list"] ~= nil then
                local province = tmp["result"]["list"][1]["province"]
                if province == _province then
                    ret = true
                end
            else
                kong.log.err("parse ip info failed")
            end
        else
            kong.log.err("get ip info from [", req_url, "] faild, http code is ", status)
        end
    end

    return ret
end

return _M
