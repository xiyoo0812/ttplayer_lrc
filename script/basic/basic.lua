--basic.lua

--系统扩展函数名字空间
math_ext    = math_ext or {}
table_ext   = table_ext or {}
string_ext  = string_ext or {}

--加载basic文件
import("enum.lua")
import("class.lua")
import("mixin.lua")
import("property.lua")
import("constant.lua")
import("basic/math.lua")
import("basic/table.lua")
import("basic/string.lua")
import("basic/logger.lua")
import("basic/console.lua")
import("basic/listener.lua")
import("basic/signal.lua")
import("basic/environ.lua")

local log_err       = logger.err
local sformat       = string.format
local dgetinfo      = debug.getinfo
local dtraceback    = debug.traceback

--函数装饰器: 保护性的调用指定函数,如果出错则写日志
--主要用于一些C回调函数,它们本身不写错误日志
--通过这个装饰器,方便查错
function quanta.xpcall(func, format, ...)
    local ok, err = xpcall(func, dtraceback, ...)
    if not ok then
        log_err(format, err)
    end
end

function quanta.xpcall_quit(func, format, ...)
    local ok, err = xpcall(func, dtraceback, ...)
    if not ok then
        log_err(format, err)
        quanta.run = nil
    end
end

function quanta.try_call(func, time, ...)
    while time > 0 do
        time = time - 1
        if func(...) then
            return true
        end
    end
    return false
end

function quanta.enum(ename, ekey)
    local eobj = enum(ename)
    if not eobj then
        local info = dgetinfo(2, "S")
        log_err(sformat("[quanta][enum] %s not initial! source(%s:%s)", ename, info.short_src, info.linedefined))
        return
    end
    local eval = eobj[ekey]
    if not eval then
        local info = dgetinfo(2, "S")
        log_err(sformat("[quanta][enum] %s.%s not defined! source(%s:%s)", ename, ekey, info.short_src, info.linedefined))
        return
    end
    return eval
end
