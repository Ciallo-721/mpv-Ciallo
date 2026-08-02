-- 右键：短按快进5秒，长按3倍速（暂停时长按可预览，松手即停）

local speed_multiplier = 3.0
local hold_threshold = 0.5
local is_speeding = false
local timer = nil
local pre_hold_speed = 1.0 
local was_paused = false -- 记录按下前的暂停状态

local function speed_on()
    is_speeding = true
    -- 捕获加速前的精确速度和暂停状态
    pre_hold_speed = mp.get_property_number("speed")
    was_paused = mp.get_property_bool("pause")
    
    mp.set_property("speed", speed_multiplier)
    mp.set_property("pause", "no") -- 强制取消暂停，让视频开始播放
    mp.set_osd_ass(0, 0, "▶▶▶ " .. speed_multiplier .. "x 倍速播放中")
end

local function speed_off()
    -- 恢复到之前的速度
    mp.set_property("speed", pre_hold_speed)
    mp.set_osd_ass(0, 0, "")
    is_speeding = false
    
    -- 如果按下前是暂停的，松开时重新暂停
    if was_paused then
        mp.set_property("pause", "yes")
    end
    
end

local function handle_hold(event, default_command)
    if event.event == "down" then
        -- 按下时启动计时器
        timer = mp.add_timeout(hold_threshold, speed_on)
    elseif event.event == "up" then
        -- 松开时取消计时器
        if timer then 
            timer:kill()
            timer = nil 
        end
        
        if is_speeding then 
            -- 如果正在倍速，松开则恢复正常
            speed_off() 
        else 
            -- 如果没有达到长按时间，执行默认操作（快进）
            mp.command(default_command) 
        end
    end
end

-- 绑定键盘右键（短按快进 5 秒，长按 3 倍速）
mp.add_forced_key_binding("RIGHT", "speed_right", function(e)
    handle_hold(e, "seek 5 exact")
end, {complex = true})