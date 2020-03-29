-- Copyright 2018 Demo Inc.
-- Author    : lijian@demo.com.cn
-- Describe  : concat static files

return {
    --1 设置 支持的 MIME types
    mime_types = {"css:text/css","js:application/x-javascript"},

    --2 设置 是否允许混杂不同的MIME types 允许为true,不允许为false
    different_mime = false,

    --3 设置 最大能接受的文件数量
    max_files = 50,

    --4 设置 不通文件之间添加分隔符
    file_separator = "\n",

    --5 设置 是否忽略读取错误的文件,忽略为true,不忽略为 false
    ignore_error_file = true,

    --6 设置 允许的uri路径
    allow_uri = {"/com/com.ashx","/com/bo.ashx","/com/co.ashx","/comu/bo.ashx","/comu/co.ashx"}, 

    --7 设置 静态资源所在位置
    s3_ip = "http://10.27.2.151",  
    s3_host = "s3img.in.demo.com.cn",
    s3_url_prefix = "/x.autoimg.cn",
    s3_no_url_prefix = {"/mall"}, --已字典中配置开头的资源去掉 x.autoimg.cn url前缀

    --8 设置 后端请求s3存储的http客户端连接池大小
    http_client_pool = 100,
  
    --9 设置 后端请求s3存储的http客户端连接保活时间
    http_keepalive = 6000,

    --10 设置 后端请求s3存储的http请求超时时间
    http_timeout = 3000,
}
