return [[
charset UTF-8;

> if anonymous_reports then
${{SYSLOG_REPORTS}}
> end

error_log ${{PROXY_ERROR_LOG}} ${{LOG_LEVEL}};

log_format main '$time_iso8601'
'   $scheme'
'   $request_method'
'   $host'
'   $request_uri'
'   $status'
'   $request_time'
'   $upstream_response_time'
'   $remote_addr'
'   $server_addr'
'   $upstream_addr'
'   $bytes_sent'
'   $upstream_cache_status'
'   $upstream_status'
'   $http_referer'
'   $http_user_agent'
'   $http_x_forwarded_for';

> if nginx_optimizations then
>-- send_timeout 60s;          # default value
>-- keepalive_timeout 75s;     # default value
>-- client_body_timeout 60s;   # default value
>-- client_header_timeout 60s; # default value
>-- tcp_nopush on;             # disabled until benchmarked
>-- proxy_buffer_size 128k;    # disabled until benchmarked
>-- proxy_buffers 4 256k;      # disabled until benchmarked
>-- proxy_busy_buffers_size 256k; # disabled until benchmarked
>-- reset_timedout_connection on; # disabled until benchmarked
> end

client_max_body_size ${{CLIENT_MAX_BODY_SIZE}};
proxy_ssl_server_name on;
underscores_in_headers on;
fastcgi_intercept_errors on;
proxy_intercept_errors on;
proxy_ignore_client_abort on;

proxy_buffer_size 64k;
proxy_buffers 4 64k;
proxy_busy_buffers_size 128k;
proxy_temp_file_write_size 128k;

proxy_next_upstream http_502 http_503 http_504 error timeout invalid_header non_idempotent;
proxy_next_upstream_tries 2;


lua_package_path '${{LUA_PACKAGE_PATH}};;';
lua_package_cpath '${{LUA_PACKAGE_CPATH}};;';
lua_socket_pool_size ${{LUA_SOCKET_POOL_SIZE}};
lua_max_running_timers 4096;
lua_max_pending_timers 16384;
lua_shared_dict kong                5m;
lua_shared_dict kong_db_cache       ${{MEM_CACHE_SIZE}};
> if database == "off" then
lua_shared_dict kong_db_cache_2     ${{MEM_CACHE_SIZE}};
> end
lua_shared_dict kong_db_cache_miss   12m;
> if database == "off" then
lua_shared_dict kong_db_cache_miss_2 12m;
> end
lua_shared_dict kong_locks          8m;
lua_shared_dict kong_process_events 5m;
lua_shared_dict kong_cluster_events 5m;
lua_shared_dict kong_healthchecks   5m;

lua_shared_dict static_config_cache   5m;
lua_shared_dict proxy_cache 256m;
lua_shared_dict proxy_cache_miss 12m;
lua_shared_dict proxy_cache_locks          8m;
lua_shared_dict proxy_cache_flag 128m;

lua_shared_dict resty_circuit_breake_timeout_new   10m;
lua_shared_dict resty_circuit_breake_timeout_old   10m;
lua_shared_dict kong_proxy_cache 10240m;

lua_shared_dict kong_rate_limiting_counters 12m;
> if database == "cassandra" then
lua_shared_dict kong_cassandra      5m;
lua_shared_dict my_limit_req_store 100m;
> end
lua_socket_log_errors off;
> if lua_ssl_trusted_certificate then
lua_ssl_trusted_certificate '${{LUA_SSL_TRUSTED_CERTIFICATE}}';
> end
lua_ssl_verify_depth ${{LUA_SSL_VERIFY_DEPTH}};

# injected nginx_http_* directives
> for _, el in ipairs(nginx_http_directives)  do
$(el.name) $(el.value);
> end

init_by_lua_block {
    Kong = require 'kong'
    Kong.init()
}

init_worker_by_lua_block {
    Kong.init_worker()
}


> if #proxy_listeners > 0 then
upstream kong_upstream {
    server 0.0.0.1;
    balancer_by_lua_block {
        Kong.balancer()
    }
> if upstream_keepalive > 0 then
    keepalive ${{UPSTREAM_KEEPALIVE}};
> end
}

server {
    large_client_header_buffers 4 16k;
    server_name kong;
    set $resp_body "";
    lua_need_request_body on;
    resolver 8.8.8.8 192.168.252.24 192.168.252.25 ;
> for i = 1, #proxy_listeners do
    listen $(proxy_listeners[i].listener);
> end
    # error_page 400 404 408 411 412 413 414 417 494 /kong_error_handler;
    # error_page 500 502 503 504 /handle_openapi_error_handler;

    access_log ${{PROXY_ACCESS_LOG}} main;
    error_log ${{PROXY_ERROR_LOG}} ${{LOG_LEVEL}};

    client_body_buffer_size ${{CLIENT_BODY_BUFFER_SIZE}};

> if proxy_ssl_enabled then
    ssl_certificate ${{SSL_CERT}};
    ssl_certificate_key ${{SSL_CERT_KEY}};
    ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_certificate_by_lua_block {
        Kong.ssl_certificate()
    }

    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ${{SSL_CIPHERS}};
> end

> if client_ssl then
    proxy_ssl_certificate ${{CLIENT_SSL_CERT}};
    proxy_ssl_certificate_key ${{CLIENT_SSL_CERT_KEY}};
> end

    real_ip_header     ${{REAL_IP_HEADER}};
    real_ip_recursive  ${{REAL_IP_RECURSIVE}};
> for i = 1, #trusted_ips do
    set_real_ip_from   $(trusted_ips[i]);
> end

    # injected nginx_proxy_* directives
> for _, el in ipairs(nginx_proxy_directives) do
    $(el.name) $(el.value);
> end

    location / {
        default_type                     '';
        set $resp_body                   '';
        set $ctx_ref                     '';
        set $upstream_te                 '';
        set $upstream_host               '';
        set $upstream_upgrade            '';
        set $upstream_connection         '';
        set $upstream_scheme             '';
        set $upstream_uri                '';
        set $upstream_x_forwarded_for    '';
        set $upstream_x_forwarded_proto  '';
        set $upstream_x_forwarded_host   '';
        set $upstream_x_forwarded_port   '';
        set $abtesthost 'default';
        set $abtesturis 'default';
        rewrite_by_lua_block {
            Kong.rewrite()
        }

        set $cocurrent '';
        set $cocurrent_strategy '';
        set $cocurrent_concurrency '';
        set $cocurrent_remark '';
        set $cocurrent_bottomJson '';

        set $cache '';
        set $cache_percentage '';

        set $fault '';
        set $fault_strategy '';
        set $fault_enabled '';
        set $fault_bottomJson '';

        set $mock '';
        set $mock_bottomJson '';
        
        
        access_by_lua_block {
            Kong.access()
        }

        proxy_http_version 1.1;
        proxy_set_header   TE                $upstream_te;
        proxy_set_header   Host              $upstream_host;
        proxy_set_header   Upgrade           $upstream_upgrade;
        proxy_set_header   Connection        $upstream_connection;
        proxy_set_header   X-Forwarded-For   $upstream_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $upstream_x_forwarded_proto;
        proxy_set_header   X-Forwarded-Host  $upstream_x_forwarded_host;
        proxy_set_header   X-Forwarded-Port  $upstream_x_forwarded_port;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_pass_header  Server;
        proxy_pass_header  Date;
        proxy_ssl_name     $upstream_host;
        proxy_pass         $upstream_scheme://kong_upstream$upstream_uri;

        header_filter_by_lua_block {
            Kong.header_filter()
        }

        body_filter_by_lua_block {
            Kong.body_filter()
        }

        log_by_lua_block {
            Kong.log()
        }
    }

    location = /kong_error_handler {
        internal;
        uninitialized_variable_warn off;
        resolver 8.8.8.8;
        content_by_lua_block {
            Kong.handle_error()
        }

        header_filter_by_lua_block {
            Kong.header_filter()
        }

        body_filter_by_lua_block {
            Kong.body_filter()
        }

        log_by_lua_block {
            Kong.log()
        }
    }

    location = /handle_openapi_error_handler {
        internal;
        uninitialized_variable_warn off;
        resolver 8.8.8.8;
        content_by_lua_block {
            Kong.handle_openapi_error()
        }
    }

    location = /openapi/proxyCache {
        resolver 8.8.8.8;
        content_by_lua_block {
            Kong.proxyCache()
         }
    }
    


    location = /openapi/cocurrent {
        resolver 8.8.8.8;
        content_by_lua_block {
            Kong.cocurrentData()
        }
    }
    location = /openapi/mock {
        resolver 8.8.8.8;
        content_by_lua_block {
            local conf = ngx.req.get_uri_args()
            local content = require 'kong.plugins.openapi-mock.content'
            content.mock_data(conf)
        }
    }
    location = /openapi/api-filter {
        resolver 8.8.8.8;
        content_by_lua_block {
            local conf = ngx.req.get_uri_args()
            local work = require 'kong.plugins.openapi-api-filter.work'
            work.content(conf)
        }
        log_by_lua_block {
            Kong.log()
        }
    }
    location = /openapi/fault {
        resolver 8.8.8.8;
        content_by_lua_block {
            Kong.faultData()
        }
        log_by_lua_block {
            Kong.log()
        }
    }
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
}
> end

> if #admin_listeners > 0 then
server {
    server_name kong_admin;
> for i = 1, #admin_listeners do
    listen $(admin_listeners[i].listener);
> end

    access_log ${{ADMIN_ACCESS_LOG}};
    error_log ${{ADMIN_ERROR_LOG}} ${{LOG_LEVEL}};

    client_max_body_size 10m;
    client_body_buffer_size 10m;

> if admin_ssl_enabled then
    ssl_certificate ${{ADMIN_SSL_CERT}};
    ssl_certificate_key ${{ADMIN_SSL_CERT_KEY}};
    ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;

    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ${{SSL_CIPHERS}};
> end

    # injected nginx_admin_* directives
> for _, el in ipairs(nginx_admin_directives) do
    $(el.name) $(el.value);
> end

    location / {
        default_type application/json;
        content_by_lua_block {
            Kong.serve_admin_api()
        }
    }

    location /nginx_status {
        internal;
        access_log off;
        stub_status;
    }

    location /robots.txt {
        return 200 'User-agent: *\nDisallow: /';
    }
}
> end
]]
