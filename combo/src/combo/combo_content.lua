-- Copyright 2018 demo Inc.
-- Author    : lijian@demo.com.cn
-- Describe  : concat static files

local conf = require "config"
local http = require "http"
local iconv = require "iconv"

local plog = ngx.log
local ERR = ngx.ERR

local _M = {
    _VERSION = "18.08.29",
}

_M.do_iconv = function (from,to,text)  
    local cd = iconv.new(to .. "//TRANSLIT", from)
    local ostr, err = cd:iconv(text)
    if err == iconv.ERROR_INCOMPLETE then
        return "/* ERROR: Incomplete input.(utf8 bom) */"
    elseif err == iconv.ERROR_INVALID then
        return "/* ERROR: Invalid input(utf8 bom). */"
    elseif err == iconv.ERROR_NO_MEMORY then
        return "/* ERROR: Failed to allocate memory(utf8 bom).*/"
    elseif err == iconv.ERROR_UNKNOWN then
        return "/* ERROR: There was an unknown error(utf8 bom). */"
    end
    return ostr
end

_M.remove_utf8_bom = function(ret)
    return string.char( string.byte(ret,4,string.len(ret)) )
    --return string.byte(ret,4,string.len(ret))
end

_M.is_utf8_bom = function(ret)
    if string.byte(ret,1)==239 and string.byte(ret,2)==187 and string.byte(ret,3)==191 then
        return true
    end
    return false
end

_M.is_utf16 = function(ret)
    if string.byte(ret,1)==255 and string.byte(ret,2)==254 then
        return true
    end
    if string.byte(ret,1)==254 and string.byte(ret,2)==255 then
        return true
    end
    return false 
end

_M.is_utf32 = function(ret)
    if string.byte(ret,1)==0 and string.byte(ret,2)==0 and string.byte(ret,3)==254 and string.byte(ret,4)==255 then
        return true
    end
    if string.byte(ret,1)==255 and string.byte(ret,2)==254 and string.byte(ret,3)==0 and string.byte(ret,4)==0 then
        return true
    end
    return false
end

-- func string split
_M.string_split = function(_str,_reps)
    local res = {}
    if type(_str) ~= nil then
        string.gsub(_str,'[^'.._reps..']+',function (w) table.insert(res,w) end)
    end
    return res
end

--func delete duplicate elements for array
_M.delete_duplicate = function(_array)
   local tmp={} 
   local check = {};
   local n = {};
   for key , value in pairs(_array) do
       if not check[value] then
           n[key] = value
           check[value] = value
       end
    end
    for key , value in pairs(n) do
        table.insert(tmp,value)
    end
    return tmp
end

-- func sent http get request
_M.http_get = function(_url,_header)
    -- plog(ERR,_url)
    local conn = http.new()
    conn:set_timeout(conf.http_timeout)
    local res, err = conn:request_uri(_url, {
        method = "GET",
        headers = _header,
        keepalive_timeout = conf.http_keepalive,
        keepalive_pool = conf.http_client_pool
    })
    if not res then
        -- ngx.say("failed to request: ", err)
        return nil,nil,nil
    end
    return res.status, res.headers, res.body
end

-- func is no_url_prefix
_M.is_no_url_prefix = function(_url)
    local ret = false
    local t_list = conf.s3_no_url_prefix
    for i=1,#t_list do
        if string.len(_url) > string.len(t_list[i]) then
            --plog(ERR,string.sub(_url,1,string.len(t_list[i])))
            if t_list[i] == string.sub(_url,1,string.len(t_list[i])) then
                return true
            end
        end
    end
    return ret
end

-- func gen files  
_M.gen_files = function(_files,_contentype,_charset)
    -- local starttime = ngx.now() * 1000
    local all = {}
    local headers = { 
        ["Content-Type"] = _contentype,
        ["Host"]= conf.s3_host,
    }
    --local real = _M.delete_duplicate(_files)
    for i=1,#_files do
        local url_prefix = conf.s3_ip..conf.s3_url_prefix
        if _M.is_no_url_prefix(_files[i]) then
            url_prefix = conf.s3_ip
        end
        local status,headers,body = _M.http_get(url_prefix.._files[i], headers)
        plog(ERR,status)
        if status == 200 then
            table.insert(all, "/* Append File:".._files[i].." */")
            if _M.is_utf8_bom(body) then
                --body = _M.remove_utf8_bom(body) bug TODO
                body = _M.do_iconv("utf8","gb2312",body)
                body = _M.do_iconv("gb2312",_charset,body)
            end
            if _M.is_utf16(body) then
                body = _M.do_iconv("utf16",_charset,body)
            end
            --plog(ERR,string.byte(ret,1))
            --plog(ERR,string.byte(ret,2))
            --plog(ERR,body)
            table.insert(all,body)
        else
            plog(ERR,status)
            plog(ERR,"get file from s3 error,please check s3.")
            table.insert(all,"/* Path Not Exist:".._files[i].." */")   
        end
    end
    -- ngx.update_time()
    -- local endtime = ngx.now() * 1000  
    return table.concat(all, "\n")
end

-- func uri check
_M.uri_check = function(_uri)
    local list = conf.allow_uri
    for i = 1, #list do
       if _uri == list[i] then
           return true
       end
    end
    return false    
end

--func path type check
_M.path_type_check = function(_paths)
    local first = _M.string_split(_paths[1],".")
    local tmp = first[#first]
    for i =2, #_paths do
        local split = _M.string_split(_paths[i],".")
        if tmp ~= split[#split] then
            return false
        end
    end
    return true
end

-- func get charset
_M.get_charset = function (_uri)
    if string.sub(_uri,2,5) == "comu" then
        return "utf-8"
    else
        return "gb2312"
    end
end

-- func get content_type
_M.get_content_type = function(_uri)
    local ctype = conf.mime_types
    local type_map = {}
    for i = 1,#ctype do
        local tmp = _M.string_split(ctype[i],":")
        type_map[tmp[1]] = tmp[2]       
    end
    local _tmp = _M.string_split(_uri,".")
    return type_map[_tmp[#_tmp]]
end

_M.path_parse = function(_path)
    local _,c = string.gsub(_path,'%[','')
    local left = string.sub(_path,1,1)
    local right = string.sub(_path,string.len(_path),string.len(_path))
    -- path=a.js,b.js,c.js情况
    if c == 0 then
        local list = _M.string_split(_path,',')
        return list
    -- path=[/a/,b.js,c.js]或者 path=[/a/b.js,c.js]的情况
    elseif c == 1 and left == "[" and right == "]" then
        local real = string.sub(_path,2,string.len(_path)-1)
        local list = _M.string_split(real,',')
        local first = list[1]
        -- 第一个为资源路径(不表示一个资源)
        if string.sub(first,string.len(first),string.len(first)) == '/' then
            local new_list = {}
            for i = 2, #list do
                table.insert(new_list, first..list[i])
            end
            return new_list
        -- 第一个为带资源路径的资源
        else
            local new_list = {}
            local tmp = string.reverse(first)
            local _, t = string.find(tmp, '/')
            local pos = string.len(tmp) - t + 1
            local base_path = string.sub(first, 1, pos)
            table.insert(new_list, first)
            for i = 2, #list do
                table.insert(new_list, base_path..list[i])
            end
            return new_list
        end
    --path=a.js,[/b/,c.js],[/d/e/f.js,k.js].kk.js的情况
    else
        local ret = {}
        local tmpt = {}
        local tt = _M.string_split(_path,',')
        for i = 1,#tt do
            local _,c1 = string.gsub(tt[i],'%[','')
            local _,c2 = string.gsub(tt[i],'%]','')
            if c1 == 0 and c2 == 0 then
                table.insert(ret,tt[i])  
            elseif c1 == 1 and c2 == 0 then
                table.insert(tmpt,tt[i])
            elseif c1 == 0 and c2 == 1 then
                table.insert(tmpt,tt[i])
                local sub = _M.path_parse(table.concat(tmpt,','))
                for j = 1, #sub do
                    table.insert(ret,sub[j])
                end
                tmpt = {}
            else
            end
        end
        return ret
    end
end

_M.main = function()
    
    -- check url
    local uri = ngx.var.uri
    -- if not _M.uri_check(uri) then 
    --    ngx.say("This uri ["..uri.."] is not allowd.")
    --    return 
    -- end
    
    -- parse paths
    local paths = ngx.var.arg_path
    if (not paths) or (paths == '') then
        ngx.say("/* This args path is empty,please check. */")
        return 
    end

    paths = string.gsub(paths, "|", "/")
    paths = string.lower(paths)
    -- plog(ERR,paths)

    local ret = _M.path_parse(paths)
    -- plog(ERR,#ret)

    -- check allowed file num
    if #ret > conf.max_files then
       ngx.say("/* The number of files is greater than the given value ("..tostring(conf.max_files).."),please check. */")
       return
    end

    -- check path type
    if not conf.different_mime and not  _M.path_type_check(ret) then
        ngx.say("/* This is not allowed to request different types(MIME types) of files. */")
        return
    end

    -- delete muti files
    ret = _M.delete_duplicate(ret)

    -- get charset
    local charset = _M.get_charset(uri)
    
    -- get content-type
    local content_type = _M.get_content_type(ret[1])
    if content_type then
        ngx.var.new_content_type = content_type..";charset="..charset
        --ngx.var.new_content_type = content_type
    else
        ngx.say("/* path file error. please check */")
        plog(ERR,"path file error,please check.")
        return
    end

    -- gen files
    local all =  _M.gen_files(ret,ngx.var.new_content_type,charset)
    -- local all = _M.gen_files(ret,content_type)
    
    -- return    
    ngx.say(all)
   
end

_M.main()

