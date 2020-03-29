local rawget, rawset, setmetatable = rawget, rawset, setmetatable

local str_lower = string.lower

local _M = {
    _VERSION = '0.12',
}

function _M.new()
    local mt = {
        normalised = {},
    }

    mt.__index = function(t, k)
        return rawget(t, mt.normalised[str_lower(k)])
    end

    mt.__newindex = function(t, k, v)
        local k_normalised = str_lower(k)
        if not mt.normalised[k_normalised] then
            mt.normalised[k_normalised] = k
            rawset(t, k, v)
        else
            rawset(t, mt.normalised[k_normalised], v)
        end
    end

    return setmetatable({}, mt)
end

return _M
