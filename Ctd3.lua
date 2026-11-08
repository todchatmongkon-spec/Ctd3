--// ================== Fluent ==================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
	Title = "Tod999 Hub | ctd",
	SubTitle = "Free no key",
	TabWidth = 160,
	Size = UDim2.fromOffset(580, 460),
	Acrylic = true,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.LeftControl,
})

-- ==========================================
-- ปุ่มเปิด/ปิด UI สำหรับ Mobile (RGB)
-- ==========================================
 
-- ลบปุ่มเก่าถ้ามี
pcall(function()
	game:GetService("CoreGui"):FindFirstChild("Tod999_MenuButton"):Destroy()
end)
 
-- สร้าง GUI
local MenuGui = Instance.new("ScreenGui")
MenuGui.Name = "Tod999_MenuButton"
MenuGui.ResetOnSpawn = false
MenuGui.Parent = game:GetService("CoreGui")
 
-- สร้างปุ่ม
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Parent = MenuGui
ToggleBtn.Size = UDim2.fromOffset(60, 60)
ToggleBtn.Position = UDim2.new(0.1, 0, 0.2, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
ToggleBtn.TextColor3 = Color3.new(1,1,1)
ToggleBtn.Text = "T"
ToggleBtn.TextSize = 16
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Active = true
ToggleBtn.Draggable = true
ToggleBtn.BorderSizePixel = 0
 
-- มุมโค้ง
local Corner = Instance.new("UICorner")
Corner.Parent = ToggleBtn
Corner.CornerRadius = UDim.new(0, 12)
 
-- ขอบปุ่ม
local Stroke = Instance.new("UIStroke")
Stroke.Parent = ToggleBtn
Stroke.Thickness = 2
Stroke.Color = Color3.fromRGB(255,255,255)
 
-- กดเปิด/ปิด Fluent UI
ToggleBtn.MouseButton1Click:Connect(function()
	Window:Minimize()
end)
 
-- ==========================================
-- RGB สีวิ่งบนตัวอักษร
-- ==========================================
task.spawn(function()
	local hue = 0
 
	while ToggleBtn and ToggleBtn.Parent do
		hue += 0.01
		if hue >= 1 then
			hue = 0
		end
 
		local rgb = Color3.fromHSV(hue, 1, 1)
 
		-- ตัวอักษร RGB
		ToggleBtn.TextColor3 = rgb
 
		-- ขอบ RGB
		Stroke.Color = rgb
 
		-- พื้นหลังคงเดิม
		ToggleBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
 
		task.wait(0.03)
	end
end)


local Tabs = {
    Fame = Window:AddTab({ Title = "ออโต้join/เลือกความยาก", Icon = "home" }),
	Main = Window:AddTab({ Title = "บันทึกการเล่น", Icon = "circle-dot" }),
	Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

local Options = Fluent.Options

--// ================== Services ==================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

--// ================== Player ==================
local player = Players.LocalPlayer

--// ================== Workspace ==================
local elevatorsFolder = workspace:WaitForChild("Elevators")

--// ================== Config ==================
local FOLDER = "Tod999 Hub"
local DEFAULT_BASE = "Todctd"
local SAMPLE_RATE = 1 / 20          -- บันทึกตำแหน่ง 20 ครั้ง/วินาที
local NO_FILE = "(ไม่มีไฟล์)"
local playDelay = 10                -- รอกี่วินาทีก่อนเริ่มเล่น (ปรับได้ใน UI)

local hasFS = typeof(writefile) == "function" and typeof(readfile) == "function"
	and typeof(isfile) == "function" and typeof(makefolder) == "function"
	and typeof(isfolder) == "function" and typeof(listfiles) == "function"
local canDelete = typeof(delfile) == "function"

--// ================== State ==================
local baseName = DEFAULT_BASE
local recordTarget = nil   -- ไฟล์ที่จะบันทึกลง (ไม่มี .json)
local playTarget = nil     -- ไฟล์ที่จะเล่น
local frames, events = {}, {}
local recording, playing, autoPlay = false, false, false
local autoSession = 0
local startTime = 0
local recordConn = nil
local suppressRemote = false
local statusText = "ว่าง"

local function notify(title, content)
	Fluent:Notify({ Title = title, Content = content, Duration = 4 })
end

--// ================== Utility ==================
local function getCharacterParts()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid")
end

local function now()
	return os.clock() - startTime
end

local function round(n)
	return math.floor(n * 1000 + 0.5) / 1000
end

--// ================== File helpers ==================
local function ensureFolder()
	if hasFS and not isfolder(FOLDER) then makefolder(FOLDER) end
end

local function filePath(name)
	return FOLDER .. "/" .. name .. ".json"
end

-- เหลือเฉพาะ A-Z a-z 0-9 _ -
local function sanitize(text)
	local cleaned = tostring(text or ""):gsub("[^%w_%-]", "")
	return cleaned
end

-- อ่านชื่อจากช่อง Input โดยตรงทุกครั้ง (ไม่ต้องกด Enter)
local function getBaseName()
	local raw = ""
	if Options and Options.RecordName then
		raw = Options.RecordName.Value or ""
	end

	local cleaned = sanitize(raw)

	if raw ~= "" and cleaned == "" then
		notify("ชื่อไฟล์ใช้ไม่ได้", "ใช้ได้เฉพาะ A-Z, 0-9, _ และ - จะใช้ชื่อ " .. DEFAULT_BASE .. " แทน")
	end

	return cleaned ~= "" and cleaned or DEFAULT_BASE
end

-- GG -> GG1 -> GG2 ...
local function nextFileName(base)
	if not hasFS then return base end
	if not isfile(filePath(base)) then return base end
	local i = 1
	while isfile(filePath(base .. i)) do i += 1 end
	return base .. i
end

local function listJsonFiles()
	local names = {}
	if not hasFS or not isfolder(FOLDER) then return names end
	for _, path in ipairs(listfiles(FOLDER)) do
		local name = path:match("([^/\\]+)%.json$")
		if name then table.insert(names, name) end
	end
	table.sort(names)
	return names
end

local function readRecord(name)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(filePath(name)))
	end)
	if ok and type(data) == "table" then return data end
end

local function hasData(name)
	local d = readRecord(name)
	return d ~= nil and type(d.frames) == "table" and #d.frames > 1
end

--// ================== Serialize ==================
local function getPath(inst)
	local path = {}
	while inst and inst ~= game do
		table.insert(path, 1, inst.Name)
		inst = inst.Parent
	end
	return path
end

local function resolvePath(path)
	local cur = game
	for _, name in ipairs(path or {}) do
		cur = cur:FindFirstChild(name)
		if not cur then return nil end
	end
	return cur
end

local function decodeEnum(s)
	local enumType, item = tostring(s):match("^Enum%.(%w+)%.(%w+)$")
	if not enumType then return nil end
	local ok, result = pcall(function() return Enum[enumType][item] end)
	return ok and result or nil
end

local function encodeValue(v)
	local t = typeof(v)
	if t == "number" then return round(v)
	elseif t == "string" or t == "boolean" then return v
	elseif t == "Vector3" then return { __t = "V3", x = round(v.X), y = round(v.Y), z = round(v.Z) }
	elseif t == "CFrame" then
		local c = { v:GetComponents() }
		for i = 1, 12 do c[i] = round(c[i]) end
		return { __t = "CF", c = c }
	elseif t == "Instance" then return { __t = "Inst", path = getPath(v) }
	elseif t == "EnumItem" then return { __t = "Enum", e = tostring(v) }
	elseif t == "table" then
		local o = {}
		for k, x in pairs(v) do o[tostring(k)] = encodeValue(x) end
		return o
	end
	return { __t = "nil" }
end

local function decodeValue(v)
	if type(v) ~= "table" then return v end
	if v.__t == "V3" then return Vector3.new(v.x, v.y, v.z)
	elseif v.__t == "CF" then return CFrame.new(table.unpack(v.c))
	elseif v.__t == "Inst" then return resolvePath(v.path)
	elseif v.__t == "Enum" then return decodeEnum(v.e)
	elseif v.__t == "nil" then return nil end
	local o = {}
	for k, x in pairs(v) do o[k] = decodeValue(x) end
	return o
end

local function saveRecording(name)
	ensureFolder()
	local data = {
		version = 1,
		created = os.time(),
		duration = round(frames[#frames].t),
		frames = {},
		events = {},
	}

	for i, f in ipairs(frames) do
		local c = { f.cf:GetComponents() }
		for j = 1, 12 do c[j] = round(c[j]) end
		data.frames[i] = { t = round(f.t), c = c }
	end

	for i, ev in ipairs(events) do
		if ev.kind == "input" then
			data.events[i] = { t = round(ev.t), kind = "input", id = tostring(ev.id), down = ev.down }
		else
			local args = {}
			for j = 1, ev.args.n do args[j] = encodeValue(ev.args[j]) end
			data.events[i] = {
				t = round(ev.t), kind = "remote",
				path = getPath(ev.remote), args = args, n = ev.args.n,
			}
		end
	end

	writefile(filePath(name), HttpService:JSONEncode(data))
end

local function loadRecording(name)
	local data = readRecord(name)
	if not data or type(data.frames) ~= "table" then return nil end

	local f, e = {}, {}
	for i, fr in ipairs(data.frames) do
		f[i] = { t = fr.t, cf = CFrame.new(table.unpack(fr.c)) }
	end

	for _, ev in ipairs(data.events or {}) do
		if ev.kind == "input" then
			local id = decodeEnum(ev.id)
			if id then table.insert(e, { t = ev.t, kind = "input", id = id, down = ev.down }) end
		elseif ev.kind == "remote" then
			local remote = resolvePath(ev.path)
			if remote and remote:IsA("RemoteEvent") then
				local n = ev.n or #ev.args
				local args = { n = n }
				for j = 1, n do args[j] = decodeValue(ev.args[j]) end
				table.insert(e, { t = ev.t, kind = "remote", remote = remote, args = args })
			end
		end
	end
	return f, e
end

--// ================== Remote + Actions ==================
local function fireRemote(remote, ...)
	if suppressRemote then return end
	remote:FireServer(...)
	if recording then
		table.insert(events, { t = now(), kind = "remote", remote = remote, args = table.pack(...) })
	end
end

-- ใส่ action ของปุ่มตรงนี้ (ยิง Remote ผ่าน fireRemote เสมอ)
local actions = {
	-- ตัวอย่าง:
	-- [Enum.KeyCode.E] = function(down)
	-- 	if down then fireRemote(game.ReplicatedStorage.Remotes.Interact) end
	-- end,
}

local function runAction(id, down)
	local fn = actions[id]
	if fn then
		local ok, err = pcall(fn, down)
		if not ok then warn("Action error:", err) end
	end
end

--// ================== Record ==================
local function startRecording()
	if recording or playing then return false end
	local root = getCharacterParts()
	frames, events = {}, {}
	recording = true
	startTime = os.clock()
	local lastSample = -math.huge

	recordConn = RunService.Heartbeat:Connect(function()
		if not root.Parent then return end
		local t = now()
		if t - lastSample >= SAMPLE_RATE then
			lastSample = t
			table.insert(frames, { t = t, cf = root.CFrame })
		end
	end)
	return true
end

local function stopRecording()
	recording = false
	if recordConn then
		recordConn:Disconnect()
		recordConn = nil
	end
end

--// ================== Playback ==================
local function playRecording(f, e)
	if recording or playing or #f < 2 then return end
	local root, hum = getCharacterParts()
	playing = true
	root.Anchored = true
	hum.AutoRotate = false
	root.CFrame = f[1].cf

	local fi, ei = 1, 1
	local start = os.clock()
	local total = math.max(f[#f].t, #e > 0 and e[#e].t or 0)

	while playing and root.Parent do
		local elapsed = os.clock() - start

		-- เล่น events ที่ถึงเวลา
		while ei <= #e and e[ei].t <= elapsed do
			local ev = e[ei]
			if ev.kind == "input" then
				suppressRemote = true
				runAction(ev.id, ev.down)
				suppressRemote = false
			elseif ev.kind == "remote" then
				pcall(function()
					ev.remote:FireServer(table.unpack(ev.args, 1, ev.args.n))
				end)
			end
			ei += 1
		end

		-- เล่นตำแหน่ง (lerp)
		while fi < #f and f[fi + 1].t < elapsed do fi += 1 end
		if fi >= #f then
			root.CFrame = f[#f].cf
		else
			local a, b = f[fi], f[fi + 1]
			local alpha = (elapsed - a.t) / math.max(b.t - a.t, 1e-6)
			root.CFrame = a.cf:Lerp(b.cf, math.clamp(alpha, 0, 1))
		end

		statusText = string.format("กำลังเล่น %s.json %.1f/%.1fs", playTarget or "?", elapsed, total)
		if fi >= #f and ei > #e then break end
		RunService.Heartbeat:Wait()
	end

	playing = false
	suppressRemote = false
	if root.Parent then
		root.Anchored = false
		hum.AutoRotate = true
	end
end

--// ================== Input ==================
local function isRecordableInput(input)
	local t = input.UserInputType
	return t == Enum.UserInputType.Keyboard
		or t == Enum.UserInputType.MouseButton1
		or t == Enum.UserInputType.MouseButton2
end

local function onInput(input, gameProcessed, down)
	if gameProcessed or playing or not isRecordableInput(input) then return end
	local id = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode or input.UserInputType
	if recording then
		table.insert(events, { t = now(), kind = "input", id = id, down = down })
	end
	runAction(id, down)
end

UserInputService.InputBegan:Connect(function(i, gp) onInput(i, gp, true) end)
UserInputService.InputEnded:Connect(function(i, gp) onInput(i, gp, false) end)

--// ================== UI (Fluent) ==================
local StatusParagraph = Tabs.Main:AddParagraph({
	Title = "สถานะ",
	Content = "ว่าง",
})

local function refreshDropdowns()
	local all = listJsonFiles()
	local saved = {}
	for _, n in ipairs(all) do
		if hasData(n) then table.insert(saved, n) end
	end
	if Options.RecordFile then Options.RecordFile:SetValues(#all > 0 and all or { NO_FILE }) end
	if Options.SavedFile then Options.SavedFile:SetValues(#saved > 0 and saved or { NO_FILE }) end
	if Options.DeleteFile then Options.DeleteFile:SetValues(#all > 0 and all or { NO_FILE }) end
end

Tabs.Main:AddSection("บันทึกการเล่น")

Tabs.Main:AddInput("RecordName", {
	Title = "ตั้งชื่อที่จะบันทึกการเล่น",
	Default = "",
	Placeholder = "พิมพ์ชื่อเป็นภาษาอังกฤษ เช่น GG",
	Numeric = false,
	Finished = false, -- อัปเดตทันทีที่พิมพ์
	Callback = function(Text)
		local cleaned = sanitize(Text)
		baseName = cleaned ~= "" and cleaned or DEFAULT_BASE
		statusText = "ชื่อไฟล์: " .. baseName .. ".json"
	end,
})

Tabs.Main:AddButton({
	Title = "สร้างไฟล์ที่ตั้งชื่อสำหรับบันทึกการเล่น",
	Description = "สร้างไฟล์ใน " .. FOLDER,
	Callback = function()
		if not hasFS then
			notify("ผิดพลาด", "ตัวรันไม่รองรับการเขียนไฟล์")
			return
		end

		ensureFolder()
		baseName = getBaseName()              -- อ่านชื่อล่าสุดจากช่อง
		local name = nextFileName(baseName)   -- GG -> GG1 -> GG2 ...

		writefile(filePath(name), HttpService:JSONEncode({ version = 1, frames = {}, events = {} }))
		recordTarget = name
		refreshDropdowns()
		Options.RecordFile:SetValue(name)

		statusText = "สร้างไฟล์ " .. name .. ".json แล้ว"
		notify("สร้างไฟล์แล้ว", FOLDER .. "/" .. name .. ".json")
	end,
})

Tabs.Main:AddDropdown("RecordFile", {
	Title = "เลือกไฟล์ที่จะบันทึกการเล่น",
	Values = { NO_FILE },
	Multi = false,
	Default = 1,
	Callback = function(Value)
		if not Value or Value == NO_FILE then return end
		recordTarget = Value
		statusText = "จะบันทึกลง " .. Value .. ".json"
	end,
})

Tabs.Main:AddToggle("RecordToggle", {
	Title = "เปิดปิดบันทึกการเล่น",
	Description = "ปิดแล้วจะเซฟเป็นไฟล์ JSON",
	Default = false,
	Callback = function(Value)
		if Value then
			if autoPlay or playing then
				Options.RecordToggle:SetValue(false)
				statusText = "ปิดออโต้เล่นก่อนบันทึก"
				notify("บันทึกไม่ได้", statusText)
				return
			end
			if startRecording() then statusText = "กำลังบันทึก" end
		else
			if not recording then return end
			stopRecording()

			if #frames < 2 then
				statusText = "ข้อมูลน้อยเกินไป ไม่ได้บันทึก"
				notify("ไม่ได้บันทึก", statusText)
				return
			end
			if not hasFS then
				notify("ผิดพลาด", "ตัวรันไม่รองรับการเขียนไฟล์")
				return
			end

			ensureFolder()
			baseName = getBaseName()
			local name = recordTarget or nextFileName(baseName)
			local ok, err = pcall(saveRecording, name)
			if ok then
				statusText = "บันทึกลง " .. name .. ".json แล้ว"
				notify("บันทึกสำเร็จ", FOLDER .. "/" .. name .. ".json")
				recordTarget = nil -- รอบหน้าสร้างไฟล์ใหม่ GG1, GG2...
				refreshDropdowns()
			else
				statusText = "บันทึกไม่สำเร็จ"
				notify("บันทึกไม่สำเร็จ", tostring(err))
			end
		end
	end,
})

Tabs.Main:AddSection("เล่นซ้ำ")

Tabs.Main:AddDropdown("SavedFile", {
	Title = "เลือกไฟล์ที่บันทึกแล้ว",
	Values = { NO_FILE },
	Multi = false,
	Default = 1,
	Callback = function(Value)
		if not Value or Value == NO_FILE then return end
		playTarget = Value
		statusText = "เลือกเล่น " .. Value .. ".json"
	end,
})

Tabs.Main:AddButton({
	Title = "รีเฟรชรายชื่อไฟล์",
	Callback = function()
		refreshDropdowns()
		notify("รีเฟรชแล้ว", "อัปเดตรายชื่อไฟล์ใน " .. FOLDER)
	end,
})

-- นับถอยหลังก่อนเล่น (ยกเลิกได้ถ้าปิด Toggle)
local function countdown(seconds, session, roundNo)
	if seconds > 0 then
		notify("ออโต้เล่น", string.format("รอบที่ %d จะเริ่มใน %d วินาที", roundNo, seconds))
	end
	for i = seconds, 1, -1 do
		if not autoPlay or session ~= autoSession then return false end
		statusText = string.format("รอบที่ %d เริ่มเล่น %s.json ใน %d วิ", roundNo, playTarget or "?", i)
		pcall(function() StatusParagraph:SetDesc(statusText) end)
		task.wait(1)
	end
	return autoPlay and session == autoSession
end

Tabs.Main:AddSlider("PlayDelay", {
	Title = "รอก่อนเริ่มเล่น (วินาที)",
	Description = "นับถอยหลังก่อนเล่นทุกรอบ/ไม่ต้องไปรับก็ได้ครับ",
	Default = 10,
	Min = 0,
	Max = 60,
	Rounding = 0,
	Callback = function(Value)
		playDelay = math.floor(tonumber(Value) or 10)
	end,
})

local function failAuto(msg)
	autoPlay = false
	Options.AutoPlayToggle:SetValue(false)
	statusText = msg
	notify("ออโต้เล่นไม่ได้", msg)
end

Tabs.Main:AddToggle("AutoPlayToggle", {
	Title = "ออโต้เล่นไฟล์ที่บันทึก",
	Description = "เล่นวนซ้ำจนกว่าจะปิด",
	Default = false,
	Callback = function(Value)
		autoSession += 1
		local session = autoSession
		autoPlay = Value

		if not Value then
			if playing then statusText = "ปิดออโต้เล่นแล้ว" end
			playing = false
			return
		end
		if recording then return failAuto("หยุดบันทึกก่อนเล่น") end
		if not playTarget then return failAuto("เลือกไฟล์ที่บันทึกแล้วก่อน") end

		task.spawn(function()
			local f, e = loadRecording(playTarget)
			if not f or #f < 2 then
				return failAuto("อ่านไฟล์ไม่ได้หรือไฟล์ว่าง")
			end

			local roundNo = 0
			while autoPlay and session == autoSession do
				roundNo += 1
				if not countdown(playDelay, session, roundNo) then break end
				playRecording(f, e)
				if not autoPlay or session ~= autoSession then break end
				statusText = "เล่นจบรอบที่ " .. roundNo
			end
		end)
	end,
})

--// ================== ลบไฟล์ ==================
Tabs.Main:AddSection("ลบไฟล์")

local deleteTarget = nil

-- ลบไฟล์ 1 ไฟล์ คืนค่า true ถ้าสำเร็จ
local function deleteRecordFile(name)
	if recording and recordTarget == name then
		notify("ลบไม่ได้", name .. ".json กำลังถูกบันทึกอยู่")
		return false
	end
	if (playing or autoPlay) and playTarget == name then
		notify("ลบไม่ได้", "ปิดออโต้เล่น " .. name .. ".json ก่อน")
		return false
	end

	local ok, err = pcall(delfile, filePath(name))
	if not ok then
		notify("ลบไม่สำเร็จ", tostring(err))
		return false
	end

	if recordTarget == name then recordTarget = nil end
	if playTarget == name then playTarget = nil end
	if deleteTarget == name then deleteTarget = nil end
	return true
end

local function confirm(title, content, onConfirm)
	Window:Dialog({
		Title = title,
		Content = content,
		Buttons = {
			{ Title = "ลบ", Callback = onConfirm },
			{ Title = "ยกเลิก", Callback = function() end },
		},
	})
end

Tabs.Main:AddDropdown("DeleteFile", {
	Title = "เลือกไฟล์ที่จะลบ",
	Values = { NO_FILE },
	Multi = false,
	Default = 1,
	Callback = function(Value)
		if not Value or Value == NO_FILE then
			deleteTarget = nil
			return
		end
		deleteTarget = Value
	end,
})

Tabs.Main:AddButton({
	Title = "ลบไฟล์ที่เลือก",
	Description = "ลบถาวร กู้คืนไม่ได้",
	Callback = function()
		if not canDelete then
			notify("ผิดพลาด", "ตัวรันไม่รองรับการลบไฟล์ (delfile)")
			return
		end
		if not deleteTarget then
			notify("ยังไม่ได้เลือก", "เลือกไฟล์ที่จะลบก่อน")
			return
		end

		local name = deleteTarget
		confirm("ยืนยันการลบ", "ต้องการลบ " .. name .. ".json ใช่ไหม?", function()
			if deleteRecordFile(name) then
				refreshDropdowns()
				statusText = "ลบ " .. name .. ".json แล้ว"
				notify("ลบแล้ว", FOLDER .. "/" .. name .. ".json")
			end
		end)
	end,
})

Tabs.Main:AddButton({
	Title = "ลบไฟล์ทั้งหมด",
	Description = "ลบไฟล์บันทึกทุกไฟล์ใน " .. FOLDER .. " (ไม่ลบ Settings)",
	Callback = function()
		if not canDelete then
			notify("ผิดพลาด", "ตัวรันไม่รองรับการลบไฟล์ (delfile)")
			return
		end

		local all = listJsonFiles()
		if #all == 0 then
			notify("ไม่มีไฟล์", "ไม่มีไฟล์ให้ลบ")
			return
		end

		confirm("ยืนยันการลบทั้งหมด", "ต้องการลบไฟล์ทั้งหมด " .. #all .. " ไฟล์ใช่ไหม?", function()
			local count = 0
			for _, name in ipairs(all) do
				if deleteRecordFile(name) then count += 1 end
			end
			refreshDropdowns()
			statusText = "ลบแล้ว " .. count .. "/" .. #all .. " ไฟล์"
			notify("ลบเสร็จ", statusText)
		end)
	end,
})



--// ตัวละครตายระหว่างบันทึก
player.CharacterAdded:Connect(function()
	if recording then
		stopRecording()
		statusText = "ตัวละครตาย หยุดบันทึกแล้ว"
		notify("หยุดบันทึก", "ตัวละครตาย ข้อมูลยังอยู่ ปิด Toggle เพื่อเซฟ")
	end
end)

-- ตัวแปรตั้งค่าเริ่มต้น
local SELECTED_MAP = "Toilet city"
local AUTO_JOIN_ENABLED = false -- สถานะเปิด/ปิดการออโต้ Join

local WAIT_TIME = 11
local CHECK_RADIUS = 8      -- ครึ่งความกว้างลิฟต์ (studs)
local TELEPORT_HEIGHT = 4   -- ยกตัวขึ้นตอนวาร์ป

local MAPS = {
	["Toilet city"]  = {"Elevator1", "Elevator2", "Elevator3", "Elevator4"},
	["Desert"]       = {"Elevator5", "Elevator6", "Elevator7", "Elevator8"},
	["Cameraman HQ"] = {"Elevator9", "Elevator10", "Elevator11", "Elevator12"},
	["Toilet HQ"]    = {"Elevator13", "Elevator14", "Elevator15", "Elevator16"},
}

-- 1. สร้าง Dropdown สำหรับเลือกแมพ
Tabs.Fame:AddDropdown("MapDropdown", {
    Title = "เลือกแมพที่จะเล่น",
    Values = {"Toilet city", "Desert", "Cameraman HQ", "Toilet HQ"},
    Default = "Toilet city",
    Callback = function(Value)
        SELECTED_MAP = Value
        Fluent:Notify({
            Title = "เปลี่ยนแมพสำเร็จ",
            Content = "เปลี่ยนเป้าหมายไปที่แมพ: " .. Value,
            Duration = 3
        })
    end
})

-- 2. สร้าง Toggle สำหรับเปิด-ปิดระบบออโต้ Join แมพที่เลือก
Tabs.Fame:AddToggle("AutoJoinToggle", {
    Title = "เปิด/ปิด ออโต้ Join แมพที่เลือก",
    Default = false,
    Callback = function(Value)
        AUTO_JOIN_ENABLED = Value
        if Value then
            Fluent:Notify({
                Title = "เปิดระบบออโต้ Join",
                Content = "กำลังเริ่มค้นหาและวาร์ปลิฟต์ในแมพ: " .. SELECTED_MAP,
                Duration = 3
            })
        else
            Fluent:Notify({
                Title = "ปิดระบบออโต้ Join",
                Content = "หยุดการทำงานชั่วคราว",
                Duration = 3
            })
        end
    end
})

-- ดึงรายชื่อลิฟต์ตามแมพที่เลือกปัจจุบัน
local function getElevatorNames()
	return MAPS[SELECTED_MAP] or {}
end

-- เช็คว่ามีผู้เล่นยืนอยู่ในลิฟต์ไหม
local function isElevatorOccupied(elevator)
	local elevatorPosition = elevator:GetPivot().Position

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local character = otherPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")

			if rootPart then
				local offset = rootPart.Position - elevatorPosition
				if math.abs(offset.X) <= CHECK_RADIUS
					and math.abs(offset.Z) <= CHECK_RADIUS
					and offset.Y >= -2 and offset.Y <= 8 then
					return true
				end
			end
		end
	end

	return false
end

-- วาร์ปไปที่ลิฟต์
local function teleportToElevator(elevator)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end

	character:PivotTo(elevator:GetPivot() * CFrame.new(0, TELEPORT_HEIGHT, 0))
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	return true
end

-- รันลูปเช็คและวาร์ป (ทำงานเมื่อเปิด Toggle และมี Elevator อยู่จริงเท่านั้น)
task.spawn(function()
	while true do
		if AUTO_JOIN_ENABLED then
			local elevatorFound = false

			for _, elevatorName in ipairs(getElevatorNames()) do
				local elevator = elevatorsFolder:FindFirstChild(elevatorName)

				-- เช็คว่ามี Elevator ตัวนี้อยู่จริงไหม และไม่มีคนยืนอยู่
				if elevator then
					elevatorFound = true
					if not isElevatorOccupied(elevator) then
						if teleportToElevator(elevator) then
							print("วาร์ปไปยัง:", elevatorName, "ในแมพ:", SELECTED_MAP)
							break
						end
					end
				end
			end

			-- ถ้าวนลูปแล้วไม่เจอ Elevator ในโฟลเดอร์เลย จะข้ามไป ไม่ทำอะไร
			if not elevatorFound then
				-- สามารถเปิดคอมเมนต์บรรทัดล่างนี้ดูใน Console ได้หากต้องการดีบัก
				-- warn("ไม่พบ Elevator ในแมพ:", SELECTED_MAP)
			end
		end

		task.wait(WAIT_TIME)
	end
end)

Tabs.Fame:AddSection("เลือกโหมด")

local autoVoteEnabled = false
local selectedAutoMode = "Normal"

local function SendVote(modeName)
    local args = { modeName }
    local remote = game:GetService("ReplicatedStorage")
        :WaitForChild("ModuleLoader")
        :WaitForChild("Shared")
        :WaitForChild("Network")
        :WaitForChild("RemoteEvent")
        :WaitForChild("ModeVote")
        
    remote:FireServer(unpack(args))
end

-- สร้าง Dropdown ครบทุกโหมด (Easy, Normal, Hard, Insane, Nightmare)
local Dropdown = Tabs.Main:AddDropdown("ModeDropdown", {
    Title = "เลือกโหมด" ,
    Values = {"Easy", "Normal", "Hard", "Insane", "Nightmare"},
    Multi = false,
    Default = "Easy",
})

Dropdown:OnChanged(function(Value)
    if Value then
        selectedAutoMode = Value
    end
end)

-- ปุ่ม Toggle เปิด/ปิด Auto Vote
local Toggle = Tabs.Main:AddToggle("AutoVoteToggle", {
    Title = "Auto Vote",
    Description = "ส่งโหวตอัตโนมัติตามโหมดที่เลือก",
    Default = false
})

Toggle:OnChanged(function(Value)
    autoVoteEnabled = Value
    
    if autoVoteEnabled then
        Fluent:Notify({
            Title = "Auto Vote",
            Content = "เริ่มระบบ Auto Vote: " .. selectedAutoMode,
            Duration = 3
        })
        
        task.spawn(function()
            while autoVoteEnabled do
                SendVote(selectedAutoMode)
                task.wait(2) -- ปรับระยะเวลาหน่วงในการโหวต (วินาที)
            end
        end)
    else
        Fluent:Notify({
            Title = "Auto Vote",
            Content = "ปิดระบบ Auto Vote แล้ว",
            Duration = 3
        })
    end
end)

-- ปุ่มกดโหวต Manual ทันที 1 ครั้ง
Tabs.Main:AddButton({
    Title = "โหวตทันที (Manual Vote)",
    Description = "ส่งโหวตโหมดที่เลือกทันที 1 ครั้ง",
    Callback = function()
        SendVote(selectedAutoMode)
        Fluent:Notify({
            Title = "Vote Sent",
            Content = "ส่งโหวตโหมด: " .. selectedAutoMode,
            Duration = 3
        })
    end
})

-- ตัวแปรควบคุมการทำงาน
local autoReplayEnabled = false
local delayTime = 3  -- เวลาหน่วงเริ่มต้น (วินาที)

-- ดึง RemoteEvent ตามที่คุณกำหนด
local remoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("ModuleLoader"):WaitForChild("Shared"):WaitForChild("Network"):WaitForChild("RemoteEvent"):WaitForChild("PlayAgain")

-- เพิ่ม Toggle สำหรับเปิด-ปิด Auto Replay
local Toggle = Tabs.Main:AddToggle("AutoReplayToggle", {
    Title = "เปิด/ปิด Auto Replay", 
    Default = false
})

Toggle:OnChanged(function()
    autoReplayEnabled = Options.AutoReplayToggle.Value
    if autoReplayEnabled then
        Fluent:Notify({
            Title = "ระบบทำงานแล้ว",
            Content = "Auto Replay เริ่มทำงาน...",
            Duration = 3
        })
    else
        Fluent:Notify({
            Title = "หยุดการทำงาน",
            Content = "Auto Replayสज़ถูกปิดแล้ว",
            Duration = 3
        })
    end
end)

-- เพิ่ม Slider สำหรับปรับเวลาหน่วง (Delay)
local Slider = Tabs.Main:AddSlider("DelaySlider", {
    Title = "หน่วงเวลา (วินาที)",
    Description = "ปรับระยะเวลาก่อนกดเล่นซ้ำอีกรอบ",
    Default = 3,
    Min = 1,
    Max = 10,
    Rounding = 1,
})

Slider:OnChanged(function(Value)
    delayTime = Value
end)

-- ลูปการทำงานเบื้องหลัง
task.spawn(function()
    while true do
        if autoReplayEnabled then
            pcall(function()
                remoteEvent:FireServer()
            end)
        end
        task.wait(delayTime)
    end
end)

-- อ้างอิง RemoteEvent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WaveSkipRemote = ReplicatedStorage:WaitForChild("ModuleLoader")
    :WaitForChild("Shared")
    :WaitForChild("Network")
    :WaitForChild("RemoteEvent")
    :WaitForChild("WaveSkip")

local autoSkipEnabled = false

-- เพิ่ม Toggle Switch ใน Fluent UI
local Toggle = Tabs.Fame:AddToggle("AutoSkipWave", {
    Title = "Auto Skip Wave",
    Default = false
})

Toggle:OnChanged(function(Value)
    autoSkipEnabled = Value
    
    if autoSkipEnabled then
        task.spawn(function()
            while autoSkipEnabled do
                pcall(function()
                    WaveSkipRemote:FireServer()
                end)
                task.wait(1)
            end
        end)
    end
})

-- ==========================================
-- TOD999 HUB FREE | CONFIG SYSTEM
-- ==========================================

-- ตั้งค่า SaveManager
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
SaveManager:BuildConfigSection(Tabs.Settings)

-- ==========================================
-- CONFIG STARTUP
-- ==========================================

task.spawn(function()

    -- โหลด Config เมื่อเริ่มต้น
    pcall(function()
        SaveManager:Load("TodConfigctd")
    end)

    -- บันทึก Config ทุก 1 วินาที
    while not Fluent.Unloaded do
        task.wait(1)

        pcall(function()
            SaveManager:Save("TodConfigctd")
        end)
    end

end)
