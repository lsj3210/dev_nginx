-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/8/12
-- Desc: abtest plugin 
--

local subnet= require "subnet"
local algorithm = require "algorithm"
print(type(algorithm))
print(algorithm.subnet_is_belong("192.168.0.1","192.168.0.0/24"))

local weight = "2,3,5"

-- algorithm.init_weighted_random()
local ret0 = 0
local ret1 = 0
local ret2 = 0
local c = 0
while (c < 10000) do
  local ret = algorithm.weighted_random(weight)
  if ret == 0 then
     ret0 = ret0 + 1
  end
  if ret == 1 then
     ret1 = ret1 + 1
  end
  if ret == 2 then
     ret2 = ret2 + 1
  end
  c = c + 1
end 

print(ret0)
print(ret1)
print(ret2)

