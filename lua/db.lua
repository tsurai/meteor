pcall(require, "luarocks.require")
local redis = require 'redis'
db = nil

local params = {
    host = '127.0.0.1',
    port = 6379,
}

info('initializing redis database')
db = redis.connect(params)
