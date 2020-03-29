local helpers = require("kong.openapi.Helpers");
files = require("kong.openapi.Files");
local open_api_config = require "kong.openapi.Config"
local open_api_cutils = require "kong.openapi.Utils"
local cjson_decode = require("cjson").decode
local cjson_encode = require("cjson").encode
local redis = require "resty.redis"
local reports = require "kong.reports"
local timestamp = require "kong.tools.timestamp"
local sock_opts = {}
local function is_present(str)
  return str and str ~= "" and str ~= null
end


local function get(request_uri,num_retries,domain)
    open_api_cutils.writeAutoRegLog(" start fetch " .. request_uri)    
   local http = require "resty.http"
    local httpc = http.new()
    httpc:set_timeout(1000)
    local res, err = nil
    while(num_retries > 0 and res == nil)
    do
        open_api_cutils.writeAutoRegLog( "try request_uri" .. request_uri)
        res, err = httpc:request_uri(request_uri, {
            method = "GET",   
          headers = {
                ["scheme"] = "http",
                ["accept"] = "*/*",
                -- ["accept-encoding"] = "gzip",
               ["cache-control"] = "no-cache",
               ["pragma"] = "no-cache",
               ["host"] = domain,
            } ,            
       })
        if res == nil then 
          return nil
        end
        open_api_cutils.writeAutoRegLog("res.status="..res.status)
        if res.status == 404 or  res.status ==302 then 
              res = nil
              break
        end
        num_retries = num_retries - 1 
        open_api_cutils.writeAutoRegLog("num retries: " .. num_retries)
  
    end

    http:close()
    if res == nil then 
       return nil
    end
    return res.body

 
end

local function getIndeedRequest(uri)



		if kong.router.get_service() then
		  	local host = kong.router.get_service().host
		  	local upstream_url = nil
		  	local domain = nil
			local isMatching = string.match(host, '(%w+%.)')
			local url ="http://"..open_api_config.kong.admin.."/upstreams/"..host.."/targets"
			--获取targets 信息
			local body =get(url,3,host)
			if(body~=nil) then
				  			
				  			local response = cjson_decode(body);
				  			if #response.data>0 then
								for i=1,#response.data do

									if response.data[i].weight>0 then
										upstream_url = 'http://'..response.data[i].target..uri
										
										break
									end
									
								    
								end

				  			end
				  			
			end
			if isMatching and upstream_url==nil then
				domain = host
				upstream_url = 'http://'..host..uri
			

			end

			if upstream_url~=nil then
			   local upstream_responseBody  = get(upstream_url,1,domain)	
			   if upstream_responseBody ~= nil then
			   		ngx.log(ngx.CRIT, "设置缓存------------ "..upstream_responseBody) 
			   		return upstream_responseBody
			   end
			  
			end


		  	return nil,nil
		  	
		else
			
		  	return nil,nil
		end

end 


return {
		  ["local"] = {
		    --已测试
		    get = function(cache_key,uri,second)


					local data, err = proxy_cache:get(cache_key,{ ttl = second ,shm_set_tries=3},getIndeedRequest, uri)
					if err then
						ngx.log(ngx.ERR, "could not retrieve user: ", err)
						return
					end
					if(data==nil) then
			        
			        		return false,nil
			       	else
			       	  		
							return true,data

					end

		    end,
		    set = function(minute,cache_val)
			end
		  },
		  ["file"] = {
		  	--已测试
		    get = function(cache_key,uri,second)
		    		local filePath = files:getFilePath(uri) ~= nil and files:getFilePath(uri) or uri;
					local filename = cache_key .. '.cache';
					local indeed_filePath =  open_api_config.cache.path .. filePath
					local file = helpers:rtrim( indeed_filePath, '/' ) .. '/' .. filename;
					if files:file_exists( file ) == false then
						return false,nil;
					end
					local result = nil 
					local file_content= files:readFile(file)
					if (type(res)=="table") then
						local strs = {};
	                    for key, value in pairs(file_content) do  
	                               strs[key] = value;
	                               ngx.log(ngx.CRIT, "value------------ "..value)    
	                    end 
                    	 result = table.concat(strs);

                    else
                    	 result = file_content
                    end
                    if result==nil or result == "proxy_response_cache_flag" then
                    	return false,nil;

                    end
         			ngx.log(ngx.CRIT, "返回文件缓存------------ ")    
                    return true,result;


		    end,
		    --已测试
		    set = function(minute,cache_val)
		    		local uri = ngx.var.uri
					local cache_key = open_api_cutils.getProxyCacheKey()  
					local filePath = files:getFilePath(uri) ~= nil and files:getFilePath(uri) or uri;
					local indeed_filePath =  open_api_config.cache.path .. filePath
					local filename = cache_key .. '.cache';
					files:mkdirs(indeed_filePath);
					files:write( helpers:rtrim( indeed_filePath, '/' ) .. '/' .. filename, cache_val);



					

			end



		  },
		  ["redis"] = {
		  	--已测试
		    get = function(cache_key,uri,second)
		    		
					local red = redis:new()
					red:set_timeout(open_api_config.redis_timeout)
      				sock_opts.pool = open_api_config.redis_database and
                       open_api_config.redis_host .. ":" .. open_api_config.redis_port ..
                       ":" .. open_api_config.redis_database
			      	local ok, err = red:connect(open_api_config.redis_host, open_api_config.redis_port,
			                                  sock_opts)
				    if not ok then

				        kong.log.err("failed to connect to Redis: ", err)
				        return nil, err
				    end
                  
				    local times, err = red:get_reused_times()
				    if err then
				        kong.log.err("failed to get connect reused times: ", err)
				        return nil, err
				    end
				    if times == 0 then
				        if is_present(open_api_config.redis_password) then
				          local ok, err = red:auth(open_api_config.redis_password)
				          if not ok then
				            kong.log.err("failed to auth Redis: ", err)
				            return nil, err
				          end
				        end

				    end
				    
				    if open_api_config.redis_database ~= 0 then
			          -- Only call select first time, since we know the connection is shared
			          -- between instances that use the same redis database

			          local ok, err = red:select(open_api_config.redis_database)
			          if not ok then
			            kong.log.err("failed to change Redis database: ", err)
			            return nil, err
			          end
			        end
				    reports.retrieve_redis_version(red)
				    local current_value, err = red:get(cache_key)
				      if err then
				        return nil, err
				      end
				    
				    if current_value == null then
				        return nil
				    end

				    local ok, err = red:set_keepalive(10000, 100)
				    if not ok then
				        kong.log.err("failed to set Redis keepalive: ", err)
				     end

				    return true,current_value

		    end,
		    --已测试
		    set = function(minute,cache_val)
		    		
					local cache_key = open_api_cutils.getProxyCacheKey()  
					ngx.log(ngx.CRIT, 'cache_key-----'..cache_key)	
					local red = redis:new()
					red:set_timeout(open_api_config.redis_timeout)
      				sock_opts.pool = open_api_config.redis_database and
                       open_api_config.redis_host .. ":" .. open_api_config.redis_port ..
                       ":" .. open_api_config.redis_database
			      	local ok, err = red:connect(open_api_config.redis_host, open_api_config.redis_port,
			                                  sock_opts)
				    if not ok then

				        kong.log.err("failed to connect to Redis: ", err)
				        return nil, err
				    end

				    local times, err = red:get_reused_times()
				    if err then
				        kong.log.err("failed to get connect reused times: ", err)
				        return nil, err
				    end
				    if times == 0 then
				        if is_present(open_api_config.redis_password) then
				          local ok, err = red:auth(open_api_config.redis_password)
				          if not ok then
				            kong.log.err("failed to auth Redis: ", err)
				            return nil, err
				          end
				        end

				    end
				    
				    if open_api_config.redis_database ~= 0 then
			          -- Only call select first time, since we know the connection is shared
			          -- between instances that use the same redis database

			          local ok, err = red:select(open_api_config.redis_database)
			          if not ok then
			            kong.log.err("failed to change Redis database: ", err)
			            return nil, err
			          end
			        end
				    reports.retrieve_redis_version(red)
					red:set(cache_key, cache_val)
				    local expire_in_second = 60*minute
				    red:expire(cache_key,expire_in_second)
			      	local ok, err = red:set_keepalive(10000, 100)
			      	if not ok then
			        	kong.log.err("failed to set Redis keepalive: ", err)
			        	return nil, err
			      	end
					

			end



		  }

}