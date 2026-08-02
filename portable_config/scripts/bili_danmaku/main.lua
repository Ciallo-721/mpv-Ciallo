local options = require 'mp.options'

local opts = {
    font_size = 50,
    font_name = "sans-serif",
    alpha = 0.95,
    duration_marquee = 8,
    duration_still = 6,
    reserve_bottom = 0,
    reduce_comment = false,
}
options.read_options(opts, "bili_danmaku")

local directory = mp.get_script_directory()
local py_path = directory .. "\\danmaku2ass.py"
local py_path2 = directory .. "\\niconvert.pyw"
local xmlfile = directory .. "\\bilitemp.danmaku.xml"
local assfile = directory .. "\\bilitemp.ass"
local xmlfiletemp = directory .. "\\bilitemp.danmaku.xml.part"

local function get_video_res()
    local w = mp.get_property_number("width")
    local h = mp.get_property_number("height")

    if not w or not h or w <= 0 or h <= 0 then
        return "1920x1080"
    end

    return string.format("%dx%d", math.floor(w), math.floor(h))
end

local function get_convert_args()
    local res = get_video_res()
    local args = {
        'python', py_path,
        '-s', res,
        '-fs', tostring(opts.font_size),
        '-a', tostring(opts.alpha),
        '-dm', tostring(opts.duration_marquee),
        '-ds', tostring(opts.duration_still),
        '-p', tostring(opts.reserve_bottom),
        '-o', assfile,
        xmlfile
    }
    if opts.reduce_comment then
        table.insert(args, #args, "-r")
    end
    return args
end

function loadsub()
	local biliurl = mp.get_property("path")
	local download = { 'yt-dlp', biliurl, '--skip-download', '--write-subs', '--retries', '3', '--paths', directory, '--output', 'bilitemp.%(ext)s' }
    local convert = get_convert_args()
	local convert2 = {
        'python', py_path2, '-o', assfile,
        '+f', opts.font_name,
        '+s', tostring(opts.font_size),
        '+l', '0', '+a', 'async', xmlfile
    }

	if biliurl:lower():match("bilibili") and biliurl:lower():match("http") then
		mp.register_event("file-loaded", setvf)
		mp.command_native_async({
			name = 'subprocess',
			playback_only = false,
			capture_stdout = true,
			args = download
		},function(success, result, error)
			if result.status == 0 then
				mp.command_native_async({
					name = 'subprocess',
					playback_only = false,
					capture_stdout = true,
					args = convert
				},function(success, result, error)
					if result.status == 0 then
						setsub()
					else
                        mp.msg.warn("danmaku2ass转换失败，尝试niconvert")
						mp.command_native_async({
							name = 'subprocess',
							playback_only = false,
							capture_stdout = true,
							args = convert2
						},function(success, result, error)
							if result.status == 0 then
								setsub()
                            else
                                mp.msg.error("两种转换工具均失败，无法生成弹幕")
							end
						end)
					end
				end)
			else
                mp.msg.warn("yt-dlp下载弹幕失败，切换BBDown")
                loadsub2()
            end
		end)
	end
end

function loadsub2 ()
	local biliurl = mp.get_property("path")
	local download2 = { 'BBDown', biliurl, '--danmaku-only', '--work-dir', directory, '-F', 'bilitemp.danmaku' }
    local convert = get_convert_args()
	local convert2 = {
        'python', py_path2, '-o', assfile,
        '+f', opts.font_name,
        '+s', tostring(opts.font_size),
        '+l', '0', '+a', 'async', xmlfile
    }

	mp.command_native_async({
		name = 'subprocess',
		playback_only = false,
		capture_stdout = true,
		args = download2
		},function(success, result, error)
			if result.status == 0 then
				mp.command_native_async({
					name = 'subprocess',
					playback_only = false,
					capture_stdout = true,
					args = convert
				},function(success, result, error)
					if result.status == 0 then
						setsub()
					else
						mp.command_native_async({
							name = 'subprocess',
							playback_only = false,
							capture_stdout = true,
							args = convert2
						},function(success, result, error)
							if result.status ~= 0 then
								mp.commandv("vf", "clr", "")
							end
					  end)
					end
				  end)
			else
                mp.msg.error("BBDown下载弹幕失败")
                mp.commandv("vf", "clr", "")
            end
		end)
end

function setsub()
	mp.commandv("sub-add", assfile)
    mp.msg.info("弹幕加载完成，画布分辨率：" .. get_video_res())
end

function setvf()
	local display = mp.get_property_number("display-fps")
	local arg3 = 'lavfi="fps=fps=' .. display .. ':round=down"'
	if mp.get_property_native("container-fps") < 58 then
		mp.commandv("vf", "set", arg3)
	end
end

function unloadsub()
	mp.set_property_native("options/sub-file-paths", "")
	mp.set_property("sub-auto", "fuzzy")
	mp.commandv("vf", "clr", "")
end

function clean()
    if assfile then
        pcall(os.remove, xmlfile)
        pcall(os.remove, assfile)
        pcall(os.remove, xmlfiletemp)
    end
end

mp.register_event("start-file", loadsub)
mp.register_event("end-file", unloadsub)
mp.register_event("shutdown", clean)