--clock_mgr.lua

local pairs         = pairs
local odate         = os.date
local otime         = os.time
local qget          = quanta.get
local qenum         = quanta.enum
local log_info      = logger.info
local log_warn      = logger.warn
local sig_check     = signal.check
local collectgarbage= collectgarbage

local timer_mgr     = qget("timer_mgr")
local thread_mgr    = qget("thread_mgr")

local HALF_MS       = qenum("PeriodTime", "HALF_MS")
local SECOND_5_MS   = qenum("PeriodTime", "SECOND_5_MS")

local UpdateMgr = singleton()
local prop = property(UpdateMgr)
prop:reader("last_day", 0)
prop:reader("last_hour", 0)
prop:reader("last_minute", 0)
prop:reader("quit_objs", {})
prop:reader("hour_objs", {})
prop:reader("frame_objs", {})
prop:reader("second_objs", {})
prop:reader("minute_objs", {})

function UpdateMgr:__init()
    --注册订阅
    self:attach_quit(timer_mgr)
    self:attach_frame(timer_mgr)
    self:attach_second(thread_mgr)
    self:attach_minute(thread_mgr)
    --注册5秒定时器
    timer_mgr:loop(SECOND_5_MS, function()
        --执行gc
        collectgarbage("step", 1)
        --检查文件更新
        quanta.reload()
    end)
end

function UpdateMgr:update(now_ms, clock_ms)
    --业务更新
    thread_mgr:fork(function()
        local diff_ms = clock_ms - quanta.clock_ms
        if diff_ms > HALF_MS then
            log_warn("[UpdateMgr][update] last frame exec too long(%d ms)!", diff_ms)
        end
        --帧更新
        local frame = quanta.frame + 1
        for obj in pairs(self.frame_objs) do
            obj:on_frame(clock_ms, frame)
        end
        quanta.frame = frame
        quanta.now_ms = now_ms
        quanta.clock_ms = clock_ms
        --秒更新
        local now = otime()
        if now == quanta.now then
            return
        end
        quanta.now = now
        for obj in pairs(self.second_objs) do
            obj:on_second(clock_ms)
        end
        --检查信号
        self:sig_check()
        --分更新
        local time = odate("t", now)
        if time.min == self.last_minute then
            return
        end
        self.last_minute = time.min
        for obj in pairs(self.minute_objs) do
            obj:on_minute(clock_ms)
        end
        --时更新
        if time.hour == self.last_hour then
            return
        end
        self.last_hour = time.hour
        for obj in pairs(self.hour_objs) do
            obj:on_hour(clock_ms, time.hour)
        end
        --gc
        collectgarbage("collect")
    end)
end

function UpdateMgr:sig_check()
    if sig_check() then
        log_info("[UpdateMgr][sig_check]service quit for signal !")
        for obj in pairs(self.quit_objs) do
            obj:on_quit()
        end
        quanta.run = nil
    end
end

--添加对象到小时更新循环
function UpdateMgr:attach_hour(obj)
    if not obj.on_hour then
        log_warn("[UpdateMgr][attach_hour] obj(%s) isn't on_hour method!", obj)
        return
    end
    self.hour_objs[obj] = true
end

function UpdateMgr:detach_hour(obj)
    self.hour_objs[obj] = nil
end

--添加对象到分更新循环
function UpdateMgr:attach_minute(obj)
    if not obj.on_minute then
        log_warn("[UpdateMgr][attach_minute] obj(%s) isn't on_minute method!", obj)
        return
    end
    self.minute_objs[obj] = true
end

function UpdateMgr:detach_minute(obj)
    self.minute_objs[obj] = nil
end

--添加对象到秒更新循环
function UpdateMgr:attach_second(obj)
    if not obj.on_second then
        log_warn("[UpdateMgr][attach_second] obj(%s) isn't on_second method!", obj)
        return
    end
    self.second_objs[obj] = true
end

function UpdateMgr:detach_second(obj)
    self.second_objs[obj] = nil
end

--添加对象到帧更新循环
function UpdateMgr:attach_frame(obj)
    if not obj.on_frame then
        log_warn("[UpdateMgr][attach_frame] obj(%s) isn't on_frame method!", obj)
        return
    end
    self.frame_objs[obj] = true
end

function UpdateMgr:detach_frame(obj)
    self.frame_objs[obj] = nil
end

--添加对象到程序退出通知列表
function UpdateMgr:attach_quit(obj)
    if not obj.on_quit then
        log_warn("[UpdateMgr][attach_quit] obj(%s) isn't on_quit method!", obj)
        return
    end
    self.quit_objs[obj] = true
end

function UpdateMgr:detach_quit(obj)
    self.quit_objs[obj] = nil
end

quanta.update_mgr = UpdateMgr()

return UpdateMgr
