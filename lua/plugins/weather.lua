local http = require("socket.http")
local json = require("json")

local Weather = {}

function Weather.init()

end

function Weather.cleanup()

end

function Weather.name()
    return "Weather"
end

function Weather.description()
    return "no description"
end

local function url_encode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str
end

local function api_call(payload)
    local url = "https://query.yahooapis.com/v1/public/yql?format=json&q="..url_encode(payload)
    local body, code, _, _ = http.request(url)
    assert(code == 200, "An API error has occured. Got status code: "..code)

    local json_data = json.decode(body)
    assert(json_data ~= nil, "Failed to parse JSON data")

    return json_data
end

function Weather.listen(from, to, input)
    input = input:lower()

    if string.match(input, "show my weather") ~= nil then
        local location = db:get('weather.user.'..from)
        assert(location ~= nil, from..": you have to tell me your location first")

        local query = "select * from weather.forecast where woeid in (select woeid from geo.places(1) where text=\""..location.."\")"
        local _, data = assert(pcall(api_call, query))

        if data["query"]["count"] ~= 0 then
            local data = data["query"]["results"]["channel"]

            local temp_unit = data["units"]["temperature"]
            local speed_unit = data["units"]["speed"]

            local location = data["location"]["city"] .. "," .. data["location"]["region"] .. ", " .. data["location"]["country"]
            local condition = data["item"]["condition"]["text"]

            local today = data["item"]["forecast"][1]
            local temp = data["item"]["condition"]["temp"] .. temp_unit .. " [" .. today["low"] .. temp_unit .. "/" .. today["high"] .. temp_unit .. "]"

            local wind = data["wind"]["chill"] .. temp_unit .. " from " .. data["wind"]["direction"] .. " with " .. data["wind"]["speed"] .. speed_unit

            local tomorrow = data["item"]["forecast"][2]
            local forecast = tomorrow["day"] .. ", " .. tomorrow["date"] .. ": " .. tomorrow["text"] .. " [" .. tomorrow["low"] .. temp_unit .. "/" .. tomorrow["high"] .. temp_unit .. "]"

            local str = "%s :: %s :: Temp %s :: Wind %s :: Forecast %s"
            return str:format(location, condition, temp, wind, forecast)
        else
            return "no results found"
        end
        return nil
    else
        location = string.match(input, "set my location to (.*)")
        if location ~= nil then
            db:set('weather.user.'..from, location)
            return from..": your location has been saved"
        end
    end

    return nil
end

return Weather
