local https = require("ssl.https")
local json = require("json")

local Wanikani = {}

function Wanikani.init()

end

function Wanikani.cleanup()

end

function Wanikani.name()
    return "Wanikani"
end

function Wanikani.description()
    return "This plugin offers various Wanikani related functionalities using their API. After adding your API key it's possible to query your study queue and show general stats"
end

function Wanikani.help()
    return "N/A"
end

local function api_call(from, endpoint)
    local key = db:get('wk.'..from)
    assert(key ~= nil, from..": you have to tell me your api key first")

    local url = "https://www.wanikani.com/api/user/"..key.."/"..endpoint
    local body, code, _, _ = https.request(url)
    assert(code == 200, "An API error has occured. Got status code: "..code)

    local json_data = json.decode(body)
    assert(json_data ~= nil, "Failed to parse JSON data")

    return json_data.requested_information
end

function Wanikani.listen(from, to, input)
    input = input:lower()

    if input == "!wk" or input == "show my review count" then
        local _, data = assert(pcall(api_call, from, "study-queue"))

        time = "now"
        diff = os.difftime(data.next_review_date, os.time())
        if diff > 0 then
            time = math.ceil(diff/60/60).." hours"
        end

        local str = "Lessons: %d - Reviews: %d - Next: %s - Hour: %d - Day: %s"
        local ret = str:format(data.lessons_available,
            data.reviews_available,
            time,
            data.reviews_available_next_hour,
            data.reviews_available_next_day)

        return ret
    elseif input == "!is" or input == "show my wanikani stats" then
        local _, data = assert(pcall(api_call, from, "srs-distribution"))

        local str = "Apprentice: %d - Guru: %d - Master: %d - Enlightend: %d - Burned: %d"
        local ret = str:format(data.apprentice.total,
            data.guru.total,
            data.master.total,
            data.enlighten.total,
            data.burned.total)

        return ret
    else
        local key = string.match(input, "set my wanikani api key to (%w*)")
        if key ~= nil then
            db:set('wk.'..from, key)
            return from..": your wanikani API key has been saved"
        end
    end

    return nil
end

return Wanikani
