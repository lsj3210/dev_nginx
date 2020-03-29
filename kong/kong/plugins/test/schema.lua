local function server_port(given_value, given_config)
  -- Custom validation
  if given_value > 65534 then
    return false, "port value too high"
  end

  -- If environment is "development", 8080 will be the default port
  if given_config.environment == "development" then
    return true, nil, {port = 8080}
  end
end

return {
  fields = {
    environment = {type = "string", required = true, enum = {"production", "development"}},
    server = {
      type = "table",
      schema = {
        fields = {
          host = {type = "url", default = "http://example.com"},
          port = {type = "number", func = server_port, default = 80}
        }
      }
    }
  }
}