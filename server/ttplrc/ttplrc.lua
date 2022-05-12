-- ttplrc.lua
import("ttplrc/qqmusic.lua")
import("driver/unicode.lua")

local qget          = quanta.get
local log_err       = logger.err
local log_debug     = logger.debug
local sformat       = string.format

local qqmusic       = qget("qqmusic")
local unicode       = qget("unicode")

local RESTEMPLATE = "\t<lrc id='%s' artist='%s' title='%s'></lrc>\r\n"
local function serarch_parse(data)
    local buff = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<result>\n"
    for _, song in pairs(data) do
        buff = buff .. sformat(RESTEMPLATE, song.id, song.artist, song.title)
    end
    buff = buff .. "</result>"
    return buff
end

local on_get = function(path, query, headers)
    local lrcid = query["dl?Id"]
    if not lrcid then
        --search
        local title = unicode:sdecode(query["Title"])
        local artist = unicode:sdecode(query["sh?Artist"])
        log_debug("ttplayer lrc search: title: %s, artist: %s\n", title, artist)
        local ok, res = pcall(function()
            local data = qqmusic:search(artist, title)
            return serarch_parse(data)
        end)
        if not ok then
            log_err("ttplayer lrc search ok=%s, res=%s", ok, res)
            return res
        end
        return res
    end
    --download
    log_debug("ttplayer lrc download: lrcid: %s", lrcid)
    local ok, res = pcall(function()
        return qqmusic:download(lrcid)
    end)
    if not ok then
        log_err("ttplayer lrc download ok=%s, res=%s", ok, res)
        return res
    end
    return res
end

local HttpServer = import("network/http_server.lua")
local server = HttpServer("0.0.0.0:8888")
server:register_get("*", on_get)
quanta.server = server
