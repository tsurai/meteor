local http = require("socket.http")
local json = require("json")

local Lastfm = {}

function Lastfm.init()
    print("[lua][lastfm] initializing")
end

function Lastfm.cleanup()
    print("[lua][lastfm] cleanup")
end

function Lastfm.name()
    return "Lastfm"
end

function Lastfm.description()
    return "no description"
end

local function api_call(from, endpoint, payload)
    local key = db:get('lastfm.apikey')
    assert(key ~= nil, "I currently have no last.fm API key set")

    local username = db:get('lastfm.user.'..from)
    assert(username ~= nil, from..": you have to tell me your last.fm username first")

    local url = "http://ws.audioscrobbler.com/2.0/?method="..endpoint.."&user="..username.."&api_key="..key.."&format=json"..payload
    local body, code, _, _ = http.request(url)
    assert(code == 200, "An API error has occured. Got status code: "..code)

    local json_data = json.decode(body)
    assert(json_data ~= nil, "Failed to parse JSON data")

    return json_data
end

function Lastfm.listen(from, to, input)
    input = input:lower()

    if string.match(input, "show now playing") ~= nil then
        local _, data = assert(pcall(api_call, from, "user.getrecenttracks", "&limit=1"))

        data = data.recenttracks
        assert(#data.track ~= 0, from..": I can't find any played tracks")

        local artist = data.track[1].artist["#text"]
        local track = data.track[1].name
        local mbid = data.track[1].artist.mbid

        local tags = {}
        if mbid ~= nil then
            local _, data = assert(pcall(api_call, from, "artist.gettoptags", "&mbid="..mbid))
            for key, val in pairs(data.toptags.tag) do
                if tonumber(key) > 5 then break end
                table.insert(tags, val.name)
            end
        end

        local str = "Now playing: %s - %s [%s]"
        return str:format(artist, track, table.concat(tags, ", "))
   else
        username = string.match(input, "set my lastfm username to (%w*)")
        if username ~= nil then
            db:set('lastfm.user.'..from, username)
            return from..": your lastfm username has been saved"
        end
    end

    return nil
end

return Lastfm
