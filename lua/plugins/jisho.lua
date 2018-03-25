local http = require("ssl.https")
local json = require("json")

local Jisho = {}

function Jisho.init()

end

function Jisho.cleanup()

end

function Jisho.name()
    return "Jisho"
end

function Jisho.description()
    return "no description"
end

function Jisho.help()
    return "N/A"
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
    local url = "https://jisho.org/api/v1/search/words?keyword="..url_encode(payload)
    local body, code, _, _ = http.request(url)
    assert(code == 200, "An API error has occured. Got status code: "..code)

    local json_data = json.decode(body)
    assert(json_data ~= nil, "Failed to parse JSON data")

    return json_data
end

function Jisho.listen(from, to, input)
    input = input:lower()

    local word = string.match(input, "!jisho (.*)")
    if word == nil then
        word = string.match(input, "lookup (.*)")
    end

    if word ~= nil then
        local _, data = assert(pcall(api_call, word))
        assert(#data.data ~= 0, "No results found")
        data = data.data

        local kanji = data[1].japanese[1].word
        local hiragana = data[1].japanese[1].reading
        local meanings = ""
        for key, val in pairs(data[1].senses) do
            if #val.parts_of_speech > 0 then
                meanings = meanings.."["..table.concat(val.parts_of_speech, ", ").."] "
            end
            meanings = meanings..key..". "..table.concat(val.english_definitions, ", ").." "
        end

        local str = "%s (%s): %s"
        return str:format(kanji, hiragana, meanings, pos)
    end

    return nil
end

return Jisho
