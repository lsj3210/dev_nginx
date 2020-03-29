local helpers = require("kong.openapi.Helpers");
files = require("kong.openapi.Files");
local open_api_config = require "kong.openapi.Config"
local open_api_utils = require "kong.openapi.Utils"

local open_api_proxy_cache = require "kong.openapi.ProxyCache"

local cjson_decode = require("cjson").decode
local cjson_encode = require("cjson").encode


local kong_url = "http://10.168.0.69:8001"

local function get(url)

				 	  local http = require "resty.http"
				      local httpc = http.new()
				      local res, err = httpc:request_uri(url, {
				        method = "GET",
				        
				        headers = {
				          ["Content-Type"] = "application/json",
				        },
				        keepalive_timeout = 5,
				        keepalive_pool = 10
				      })
				      
				      if not res then
				        -- ngx.say("failed to request: ", err)
				        return false,nil
				      end
				     
	
					 if res.status == 200 then
				      		local json_value = cjson_decode(res.body)
				      		return true,json_value

				      else

				      	 	return  false,nil	

				      end

end


--获取网关提供的 Api 信息
-- data_object_path = '/routes'   获取网关的所有路由信息
-- data_object_path = '/plugins'  获取网关的所有插件信息
local function get_kong_object(data_object_path)
				 			     
				 local paths = uri
				 local object_data_list = {};
				 local result = {};
				 --routes_list  routes_list_page routes_data next_route_value x z  data_list
				 local next_falg = false
				 local success,object_data = get(kong_url..data_object_path)
				
    			 if success then

    			
				 	object_data_list[1] = object_data

				 	-- 下一页路由地址
				 	if object_data.next ~= nil and object_data.next ~=ngx.null then

						 	local i = 2
						 	next_falg = true
						 	local next_url = object_data.next
							while(next_falg)
							do
								
								-- 获取下一页路信息
								local next_route_success,next_object_value = get(kong_url..next_url)
								if next_route_success then
									object_data_list[i] = next_object_value
									i = i + 1 
									-- 没有更多信息了
									if next_object_value.next == nil or next_object_value.next  ==ngx.null  then
										next_falg = false


									end
								else
									next_falg = false
									
								end

							   
							end


					end


					local j = 1

					-- 循环所有 分页的对象信息 、返回总的对象列表
					for key, value in pairs(object_data_list) do  
								
								for y, routes in pairs(value.data) do
						
										j = j +1
										result[j] = routes
										

										

										
								end
								

					end 

		
					if j >= 1 then
						
						return true,result
					else
						return  false,nil
					end

	
				else

				 	return  false,nil
				end

end

local function get_routes_object(uri)

			local success,data = get_kong_object("/routes")
			local routes = nil
			if success then	
					local host_name =open_api_utils.getHostName()


					
					for key, value in pairs(data) do

						
						if (type(value)=="table") then
							  if value.hosts ~= ngx.null  and value.paths~= ngx.null  then

										
										if value.hosts[1] == host_name and value.paths[1] == uri then
												routes = value
												break
										
											 
										end



								end

							

						

						end

							

										
					end

					if routes~=nil then
						
						return true,routes
					else
						ngx.log(ngx.CRIT, 'not found  ')  
						return false,nil
					end

				 	

			else
				 	

				 	 
				 	return false,nil
			end
				 	



end


return {


			get_plugin = function(uri)
				 
				 
				 local success ,routes_object  =get_routes_object(uri)
				 local result = nil
				 if success then
				 		
				 		ngx.log(ngx.CRIT, 'success-------------------------routes')  		
				 		local routes_id = routes_object.id
				 		local service_id = nil
						if routes_object.service ~= ngx.null  and routes_object.service~=nil  then
							service_id = routes_object.service.id
						end				 		

					    success,plugins_object = get_kong_object("/plugins")
						
						if success then	
							
							ngx.log(ngx.CRIT, 'success-------------------------plugins')  		
							-- 优先查找 routes 上的插件
							for key, plugin in pairs(plugins_object) do  

								if plugin.name == "openapi-fault" then
										if plugin.route ~= ngx.null and plugin.route~=nil then

											if routes_id == plugin.route.id and plugin.enabled then

													result = plugin
													break
											end 

								

										end

								end
							end 

							if result~=nil then

								return true,result
							end
							
							for key, plugin in pairs(plugins_object) do  

								if plugin.name == "openapi-fault" then
										if plugin.service ~= ngx.null  and plugin.service~=nil  then

											if service_id == plugin.service.id and plugin.enabled then

													result = plugin
													break
											end 

								

										end

								end
							end 


							if result~=nil then

								return true,result
							end

	
						end
				end

				return false,nil

		    end,
		    buildJumpParms=function(plugins,uri)


                                local request_uri = ngx.var.request_uri; 
                                cocurrent = ngx.var.cocurrent 
                                cocurrent_concurrency = ngx.var.cocurrent_concurrency 
                                cocurrent_strategy = ngx.var.cocurrent_strategy 

                                ngx.var.fault = "true"                
                                ngx.var.fault_strategy = plugins.config.strategy
                                ngx.header["fault"]= ngx.var.fault
                                ngx.header["fault_strategy"]= ngx.var.fault_strategy

                                

                                Kong = require 'kong'
                                Kong.customLog()

                                --返回源码
                                if(plugins.config.strategy==1) then
    
                                    return false,nil
                                end
                                -- 缓存数据
                                if(plugins.config.strategy==2 ) then


                                	local cache_key =  open_api_utils.getProxyCacheKey()  
									local ttl, err, data = proxy_cache:peek(cache_key)
									if err then
									    ngx.log(ngx.ERR, "could not peek cache: ", err)
									    open_api_utils.writeCacheLog("cachename------------过期 ")    
									    return false,nil 
									end

                             		jump_url = '/openapi/fault?name='..cache_key..'&optype=2&uri='..uri..'&cocurrent='..cocurrent..'&cocurrent_concurrency='..cocurrent_concurrency..'&cocurrent_strategy='..cocurrent_strategy
                                    return true,jump_url

                                    
 

                                end
                                -- 托底
                                if(plugins.config.strategy==3 ) then
                                   
                                  	jump_url = '/openapi/fault?bottomJson='..plugins.config.bottomJson..'&optype=3'..'&cocurrent='..cocurrent..'&cocurrent_concurrency='..cocurrent_concurrency..'&cocurrent_strategy='..cocurrent_strategy
                                    return true,jump_url


                                end
                      
                                if(plugins.config.strategy==4 ) then
                                	local cache_key =  open_api_utils.getProxyCacheKey()  
                                    
				                    
                                	-- 判断是否存在缓存数据、 如果存在缓存数据、 直接输出缓存数据
				                    local ttl, err, data = proxy_cache:peek(cache_key)
									if err then
                                            -- jump_url = '/fallback_dispose?key='..key..'&optype=3'..'&status='..status..'&cache=false&bottom=true&upstreamurl='..upstream_url
                                            jump_url = '/openapi/fault?bottomJson='..plugins.config.bottomJson..'&optype=3'..'&cocurrent='..cocurrent..'&cocurrent_concurrency='..cocurrent_concurrency..'&cocurrent_strategy='..cocurrent_strategy
                                            return true,jump_url
								

                                    else
                                
                                            jump_url = '/openapi/fault?name='..cache_key..'&optype=2&uri='..uri..'&cocurrent='..cocurrent..'&cocurrent_concurrency='..cocurrent_concurrency..'&cocurrent_strategy='..cocurrent_strategy
                                            return true,jump_url

				                    end

                         

                                end



			end

}