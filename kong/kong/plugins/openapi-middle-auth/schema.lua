return {
    fields = {
      type = {required = true, type = "array",enum = {"docker", "cmdb", "monitor", "intranet","dba","dba-hmac","oa"}},
      user = {type = "string"},
      pwd = {type = "string"},
      token = {type = "string"},
      token_url = {type = "string"},
    }
  }
