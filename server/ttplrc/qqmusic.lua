--qqmusic.lua
import("network/http_client.lua")
local lcurl         = require("lcurl")
local ljson         = require("lcjson")
local lcrypt        = require("lcrypt")

local qget          = quanta.get
local log_err       = logger.err
local log_info      = logger.info
local jdecode       = ljson.decode
local smatch        = string.match
local sformat       = string.format
local luencode      = lcurl.url_encode
local lb64decode    = lcrypt.b64_decode

local http_client   = qget("http_client")

local PAGE_NUM      = 10
local CHANNEL       = "QQMusic"
local SEARCH_URL    = "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?new_json=1&n=%s&w=%s"
local DOWNLOAD_URL  = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?format=json&g_tk=5381&songmid=%s"

local QQMusic = singleton()
local prop = property(QQMusic)
prop:reader("id", 10000)
prop:reader("hidlist", {})
prop:reader("midlist", {})

function QQMusic:__init()
end

function QQMusic:get_mid(hid)
    return self.hidlist[hid]
end

function QQMusic:fmt_mid(mid)
    if not self.midlist[mid] then
        self.id = self.id + 1
        if self.id > 2000000000 then
            self.id = 10000
            self.midlist = {}
            self.hidlist = {}
        end
        self.midlist[mid] = self.id
        self.hidlist[self.id] = mid
        return self.id
    end
    return self.midlist[mid]
end

function QQMusic:fmt_singer(qsinger)
    local singers = {}
    for _, item in pairs(qsinger) do
        singers[#singers + 1] = item.name
    end
    return table.concat(singers, "、")
end

function QQMusic:search(artist, title)
    local search_text = sformat("%s %s", title, artist)
    log_info("QQMusic:download title=%s, artist=%s", title, artist)
    local search_url = sformat(SEARCH_URL, PAGE_NUM, luencode(search_text))
    local ok, status, res = http_client:call_get(search_url, {})
    if not ok then
        log_err("QQMusic:search ok=%s, status=%s", ok, status)
        return 404
    end
    local result = {}
    local callback = jdecode(smatch(res, "callback%((.+)%)"))
    for _, item in pairs(callback.data.song.list) do
        result[#result + 1] = {
            id_sou = item.mid,
            id = self:fmt_mid(item.mid),
            artist = self:fmt_singer(item.singer),
            title = sformat("【%s】%s", CHANNEL, item.name)
        }
    end
    return result
end

function QQMusic:download(hid)
    local mid = self:get_mid(tonumber(hid))
    log_info("QQMusic:download hid=%s, mid=%s", hid, mid)
    local download_url = sformat(DOWNLOAD_URL, mid)
    local headers = { referer = "https://c.y.qq.com/" }
    local ok, status, res = http_client:call_get(download_url, {}, headers)
    if not ok then
        log_err("QQMusic:download ok=%s, status=%s", ok, status)
        return 404
    end
    local jres = jdecode(res)
    local lyric = jres.lyric
    local b64lyric = lb64decode(lyric)
    --[[
    双语字段，暂不支持
    local trans = jres.trans
    local b64trans = lb64decode(trans)
    ]]
    return b64lyric
end

quanta.qqmusic = QQMusic()

return QQMusic
