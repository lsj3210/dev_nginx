-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/8/12
-- Desc: abtest plugin 
--

local ngx    = ngx
local kong   = kong
local util   = require "kong.plugins.openapi-abtest.utils"
local cookie = require "kong.plugins.openapi-abtest.cookie"
local algorithm = require "kong.plugins.openapi-abtest.algorithm"


local _M = {}

--
-- func for func switch
--
_M.func_switch = {
    [util.TYPE_COOKIE] = function(_url, _id, _headers, _cookies, _args)
        _M.do_cookie(_id, _url, _cookies, util.H_TYPE_COOKIE)
    end,
    [util.TYPE_ARG] = function(_url, _id, _headers, _cookies, _args)
        _M.do_arg(_id, _url, _args, util.H_TYPE_ARG)
    end,
    [util.TYPE_HEADER] = function(_url, _id, _headers, _cookies, _args)
        _M.do_header(_id, _url, _headers, util.H_TYPE_HEADER)
    end,
    [util.TYPE_SUBNET] = function(_url, _id, _headers, _cookies, _args)
        _M.do_subnet(_id, _url, util.H_TYPE_SUBNET)
    end,
    [util.TYPE_WEIGHT] = function(_url, _id, _headers, _cookies, _args)
        _M.do_weight(_id, _url, util.H_TYPE_WEIGHT)
    end,
    [util.TYPE_REGION] = function(_url, _id, _headers, _cookies, _args)
        _M.do_region(_id, _url, util.H_TYPE_REGION)
    end,
}

--
-- func for set bypass flag
--
function _M.set_bypass_flag()
    ngx.ctx.abtest_id = util.H_TYPE_PASS
    ngx.ctx.abtest_url = util.H_TYPE_PASS
    ngx.ctx.abtest_version = util.H_TYPE_PASS
    ngx.ctx.abtest_type = util.H_TYPE_PASS
    
    ngx.header[util.H_CASE_ID] = util.STR_PASS
    ngx.header[util.H_CASE_URI] = util.STR_PASS
    ngx.header[util.H_CASE_URI_VERSION] = util.STR_PASS
    ngx.header[util.H_CASE_TYPE] = util.STR_PASS
end

--
-- func for set hit flag
--
function _M.set_hit_flag(_id, _url, _flag, _type)
    ngx.ctx.abtest_id = _id
    ngx.ctx.abtest_url = _url
    ngx.ctx.abtest_version = _flag
    ngx.ctx.abtest_type = _type
    
    ngx.header[util.H_CASE_ID] = _id
    ngx.header[util.H_CASE_URI] = _url
    ngx.header[util.H_CASE_URI_VERSION] = _flag
    ngx.header[util.H_CASE_TYPE] = _type
end


--
-- func do for arg
--
function _M.do_arg(_id, _url, _args, _h_type)
    local to_url = _url[util.KEY_URL]
    local to_version = _url[util.KEY_VERSION]
    local rule_key = _url[util.KEY_CONF_OBJECT][util.KEY_KEY]
    local rule_value = _url[util.KEY_CONF_OBJECT][util.KEY_VALUE]
    local v = _args[rule_key]
    if v == rule_value then
        _M.set_hit_flag(_id, to_url, to_version, _h_type)
        ngx.var.upstream_uri = to_url
        return true
    else
        return false
    end 
end

--
-- func do for header
--
function _M.do_header(_id, _url, _headers, _h_type)
    local to_url = _url[util.KEY_URL]
    local to_version = _url[util.KEY_VERSION]
    local rule_key = _url[util.KEY_CONF_OBJECT][util.KEY_KEY]
    local rule_value = _url[util.KEY_CONF_OBJECT][util.KEY_VALUE]
    local v = _headers[rule_key]
    if v == rule_value then
        _M.set_hit_flag(_id, to_url, to_version, _h_type)
        ngx.var.upstream_uri = to_url
        return true
    else
        return false
    end 
end

--
-- func do for cookie
--
function _M.do_cookie(_id, _url, _cookies, _h_type)
    if _cookies == nil then
        return false
    end
    
    local to_url = _url[util.KEY_URL]
    local to_version = _url[util.KEY_VERSION]
    local rule_key = _url[util.KEY_CONF_OBJECT][util.KEY_KEY]
    local rule_value = _url[util.KEY_CONF_OBJECT][util.KEY_VALUE]
    local v = _cookies[rule_key]
    if v == rule_value then
        _M.set_hit_flag(_id, to_url, to_version, _h_type)
        ngx.var.upstream_uri = to_url
        return true
    else
        return false
    end 
end


--
-- func do for subnet 
--
function _M.do_subnet(_id, _url, _h_type)
    local to_url = _url[util.KEY_URL]
    local to_version = _url[util.KEY_VERSION]
    local subnets = _url[util.KEY_CONF_ARRAY]
    local client_ip = util.get_client_ip()
    local ret = false
    for i = 1, #subnets do
        local sub = subnets[i]
        local ok = algorithm.subnet_is_belong(client_ip,sub)
        if ok then
            ret = true
            _M.set_hit_flag(_id, to_url, to_version, _h_type)
            ngx.var.upstream_uri = to_url
            break
        end
    end    
    return ret
end

--
-- func do for weight
--
function _M.do_weight(_id, _url, _h_type)

    local weight_map = {}
    local weight_num = 0
    for i = 1, #_url do
        local num = _url[i][util.KEY_CONF_NUM]
        weight_num = weight_num + num
        table.insert(weight_map, tostring(num))
    end
    table.insert(weight_map, tostring(util.NUM_WEIGHT_ALL - weight_num))
    local all = table.concat(weight_map, ",")
    local no = algorithm.weighted_random(all) + 1
    if no > #_url then 
        return false
    else
        local to_url = _url[no][util.KEY_URL]
        local to_version =  _url[no][util.KEY_VERSION]
        _M.set_hit_flag(_id, to_url, to_version, _h_type)
        ngx.var.upstream_uri = to_url
        return true
    end
    -- kong.log.err(ret)
end

--
-- func do for region
--
function _M.do_region(_id, _url, _h_type)
    local to_url = _url[util.KEY_URL]
    local to_version = _url[util.KEY_VERSION]
    local regions = _url[util.KEY_CONF_ARRAY]
    local client_ip = util.get_client_ip()
    local ret = false
    for i = 1, #regions do
        local _province = regions[i]
        local ok = util.check_region(client_ip, _province)
        if ok then
            ret = true
            _M.set_hit_flag(_id, to_url, to_version, _h_type)
            ngx.var.upstream_uri = to_url
            break
        end
    end
    return ret
end

--
-- func for do case
-- 
function _M.do_case(_type, _id, _urls, _headers, _cookies, _args)
    local func = _M.func_switch[_type]
    if func then
        if _type == util.TYPE_WEIGHT then
            local ok_ = func(_urls, ngx.null, _headers, _cookies, _args)
            return true
        else
            for i = 1, #_urls do
                local ok_ = func(_urls[i], _id, _headers, _cookies, _args)
                if ok then
                    break
                end
            end

            if ngx.ctx.abtest_id == ngx.null and ngx.ctx.abtest_url == ngx.null and 
                ngx.ctx.abtest_version == ngx.null and ngx.ctx.abtest_type == ngx.null then
                return false
            else
                return true
            end
        end
    end
end


function _M.run(_conf)
    ngx.ctx.abtest_id      = ngx.null
    ngx.ctx.abtest_url     = ngx.null
    ngx.ctx.abtest_version = ngx.null
    ngx.ctx.abtest_type    = ngx.null

    local headers_ = ngx.req.get_headers()
    local args_ = ngx.req.get_uri_args()
    local cookies_ = cookie:new():get_all()

    local cases = _conf[util.KEY_ABTEST]

    local run_cases_ = {}
    for i = 1, #cases do
        local case_ = cases[i]
        local status_ = case_[util.KEY_STATUS]
        if status_ == util.STATUS_START then
            run_cases_[#run_cases_+1] = case_
        end         
    end

    for j = 1, #run_cases_ do
        local rule_ = run_cases_[j][util.KEY_RULE]
        local urls_ = run_cases_[j][util.KEY_URLS]
        local id_ = run_cases_[j][util.KEY_ID]
        local ok_ = _M.do_case(rule_, id_, urls_, headers_, cookies_, args_)
        if ok_ then
            break
        end
    end

    if ngx.ctx.abtest_id == ngx.null and ngx.ctx.abtest_url == ngx.null and 
        ngx.ctx.abtest_version == ngx.null and ngx.ctx.abtest_type == ngx.null then
        _M.set_bypass_flag()
    end

end

return _M