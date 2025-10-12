local passes, fails, undefined = 0, 0, 0
local running = 0

local function getGlobal(path)
	local value = getfenv(0)
	for name in string.gmatch(path, "[^.]+") do
		value = value and rawget(value, name)
		if not value then return nil end
	end
	return value
end

local function test(name, aliases, callback)
	running += 1
	task.spawn(function()
		local global = getGlobal(name)
		if not callback then
			print("⏺️ " .. name)
		elseif not global then
			fails += 1
			warn("⛔ " .. name)
		else
			local success, message = pcall(callback)
			if success then
				passes += 1
				print("✅ " .. name .. (message and " • " .. tostring(message) or ""))
			else
				fails += 1
				warn("⛔ " .. name .. " failed: " .. tostring(message))
			end
		end
		local undefinedAliases = {}
		for _, alias in ipairs(aliases or {}) do
			if getGlobal(alias) == nil then
				table.insert(undefinedAliases, alias)
			end
		end
		if #undefinedAliases > 0 then
			undefined += 1
			warn("⚠️ " .. table.concat(undefinedAliases, ", "))
		end
		running -= 1
	end)
end

print("\n")
print("UNC+ Environment Checker")
print("✅ - Pass, ⛔ - Fail, ⏺️ - Function missing, ⚠️ - Missing aliases\n")

task.defer(function()
	repeat task.wait() until running == 0
	local total = passes + fails
	local rate = total > 0 and math.floor((passes / total) * 100 + 0.5) or 0
	print("\n")
	print("UNC+ Summary")
	print("✅ Tested with a " .. rate .. "% success rate (" .. passes .. " out of " .. total .. ")")
	print("⛔ " .. fails .. " tests failed")
	print("⚠️ " .. undefined .. " globals are missing functions")
end)

-- Cache

test("cache.invalidate", {}, function()
	local cacheLib = getGlobal("cache")
	assert(cacheLib and cacheLib.invalidate, "cache.invalidate is missing")
	local container = Instance.new("Folder")
	local part = Instance.new("Part")
	part.Parent = container
	cacheLib.invalidate(container:FindFirstChild("Part"))
	assert(container:FindFirstChild("Part") == nil, "cache.invalidate did not remove reference properly")
end)

test("cache.iscached", {}, function()
	local cacheLib = getGlobal("cache")
	assert(cacheLib and cacheLib.iscached and cacheLib.invalidate, "cache methods missing")
	local part = Instance.new("Part")
	local wasCached = pcall(cacheLib.iscached, part)
	if wasCached then
		assert(cacheLib.iscached(part), "Part should be cached")
		cacheLib.invalidate(part)
		assert(not cacheLib.iscached(part), "Part should not be cached after invalidate()")
	end
end)

test("cache.replace", {}, function()
	local cacheLib = getGlobal("cache")
	assert(cacheLib and cacheLib.replace, "cache.replace missing")
	local part = Instance.new("Part")
	local fire = Instance.new("Fire")
	cacheLib.replace(part, fire)
	assert(part ~= fire, "cache.replace did not replace instance properly")
end)

test("cloneref", {}, function()
	local clonerefFunc = getGlobal("cloneref")
	assert(clonerefFunc, "cloneref missing")
	local part = Instance.new("Part")
	local clone = clonerefFunc(part)
	assert(part ~= clone, "cloneref should return a different reference")
	clone.Name = "Test"
	assert(part.Name == "Test", "cloneref should reference the same underlying instance")
end)

test("compareinstances", {}, function()
	local compareFunc = getGlobal("compareinstances")
	assert(compareFunc, "compareinstances missing")
	local part = Instance.new("Part")
	local clone = (getGlobal("cloneref") and cloneref(part)) or part
	assert(part ~= clone, "cloneref did not create separate reference")
	assert(compareFunc(part, clone), "compareinstances should identify cloneref as same instance")
end)

-- Closures

local function shallowEqual(t1, t2)
	if t1 == t2 then
		return true
	end
	local UNIQUE_TYPES = {
		["function"] = true,
		["table"] = true,
		["userdata"] = true,
		["thread"] = true,
	}
	for k, v in pairs(t1) do
		if UNIQUE_TYPES[type(v)] then
			if type(t2[k]) ~= type(v) then
				return false
			end
		elseif t2[k] ~= v then
			return false
		end
	end
	for k, v in pairs(t2) do
		if UNIQUE_TYPES[type(v)] then
			if type(t1[k]) ~= type(v) then
				return false
			end
		elseif t1[k] ~= v then
			return false
		end
	end
	return true
end

test("checkcaller", {}, function()
	local func = getGlobal("checkcaller")
	assert(func and func() == true, "Main scope should return true")
end)

test("clonefunction", {}, function()
	local cloneFunc = getGlobal("clonefunction")
	assert(cloneFunc, "clonefunction missing")
	local function test()
		return "success"
	end
	local copy = cloneFunc(test)
	assert(test() == copy(), "Clone should return same result")
	assert(test ~= copy, "Clone should not be identical")
end)

test("getcallingscript", {}, function()
	local func = getGlobal("getcallingscript")
	assert(func, "getcallingscript missing")
	local scriptObj = func()
	assert(typeof(scriptObj) == "Instance" or scriptObj == nil, "Invalid return from getcallingscript")
end)

test("getscriptclosure", {"getscriptfunction"}, function()
	local func = getGlobal("getscriptclosure")
	assert(func, "getscriptclosure missing")
	local module = game:GetService("CoreGui") and game:GetService("CoreGui"):FindFirstChild("RobloxGui")
	if not module then return end
	module = module:FindFirstChild("Modules") and module.Modules:FindFirstChild("Common") and module.Modules.Common:FindFirstChild("Constants")
	if not module then return end
	local constants = getrenv().require(module)
	local generated = func(module)()
	assert(constants ~= generated, "Generated module should differ from original")
	assert(shallowEqual(constants, generated), "Generated module should be shallow equal")
end)

test("hookfunction", {"replaceclosure"}, function()
	local func = getGlobal("hookfunction") or getGlobal("replaceclosure")
	assert(func, "hookfunction missing")
	local function test()
		return true
	end
	local ref = func(test, function()
		return false
	end)
	assert(test() == false, "Hooked function did not override result")
	assert(ref() == true, "Original function should still return true")
	assert(test ~= ref, "Original and reference should differ")
end)

test("iscclosure", {}, function()
	local func = getGlobal("iscclosure")
	assert(func, "iscclosure missing")
	assert(func(print) == true, "print should be a C closure")
	assert(func(function() end) == false, "Executor Lua function should not be C closure")
end)

test("islclosure", {}, function()
	local func = getGlobal("islclosure")
	assert(func, "islclosure missing")
	assert(func(print) == false, "print should not be a Lua closure")
	assert(func(function() end) == true, "Executor Lua function should be a Lua closure")
end)

test("isexecutorclosure", {"checkclosure", "isourclosure"}, function()
	local func = getGlobal("isexecutorclosure") or getGlobal("checkclosure") or getGlobal("isourclosure")
	assert(func, "isexecutorclosure missing")
	assert(func(func) == true, "Should return true for executor global")
	local nc = getGlobal("newcclosure")
	if nc then
		assert(func(nc(function() end)) == true, "Should return true for new C closure")
	end
	assert(func(function() end) == true, "Should return true for executor Lua closure")
	assert(func(print) == false, "Should return false for Roblox global")
end)

test("loadstring", {}, function()
	local func = getGlobal("loadstring")
	assert(func, "loadstring missing")
	local ok, result = pcall(function()
		local simple = assert(func("return ... + 1"))(1)
		assert(simple == 2, "Simple math failed")
		local _, err = func("f")
		assert(type(err) == "string", "Did not return error message on invalid code")
	end)
	assert(ok, "loadstring test failed")
end)

test("newcclosure", {}, function()
	local func = getGlobal("newcclosure")
	assert(func, "newcclosure missing")
	local function test()
		return true
	end
	local c = func(test)
	assert(test() == c(), "C closure should behave like original")
	assert(test ~= c, "C closure should differ from original")
	local ic = getGlobal("iscclosure")
	if ic then
		assert(ic(c), "New C closure should be a C closure")
	end
end)

-- Console

test("rconsoleclear", {"consoleclear"}, function()
	local func = getGlobal("rconsoleclear") or getGlobal("consoleclear")
	assert(func, "rconsoleclear missing")
	func()
end)

test("rconsolecreate", {"consolecreate"}, function()
	local func = getGlobal("rconsolecreate") or getGlobal("consolecreate")
	assert(func, "rconsolecreate missing")
	func()
end)

test("rconsoledestroy", {"consoledestroy"}, function()
	local func = getGlobal("rconsoledestroy") or getGlobal("consoledestroy")
	assert(func, "rconsoledestroy missing")
	func()
end)

test("rconsoleinput", {"consoleinput"}, function()
	local func = getGlobal("rconsoleinput") or getGlobal("consoleinput")
	assert(func, "rconsoleinput missing")
end)

test("rconsoleprint", {"consoleprint"}, function()
	local func = getGlobal("rconsoleprint") or getGlobal("consoleprint")
	assert(func, "rconsoleprint missing")
	func("✅ Console print test successful\n")
end)

test("rconsolesettitle", {"rconsolename", "consolesettitle"}, function()
	local func = getGlobal("rconsolesettitle") or getGlobal("rconsolename") or getGlobal("consolesettitle")
	assert(func, "rconsolesettitle missing")
	func("UNC+ Console Test")
end)

-- Crypt

test("crypt.base64encode", {"crypt.base64.encode", "crypt.base64_encode", "base64.encode", "base64_encode"}, function()
	local cryptLib = getGlobal("crypt")
	assert(cryptLib and cryptLib.base64encode, "crypt.base64encode missing")
	assert(cryptLib.base64encode("test") == "dGVzdA==", "Base64 encoding failed")
end)

test("crypt.base64decode", {"crypt.base64.decode", "crypt.base64_decode", "base64.decode", "base64_decode"}, function()
	local cryptLib = getGlobal("crypt")
	assert(cryptLib and cryptLib.base64decode, "crypt.base64decode missing")
	assert(cryptLib.base64decode("dGVzdA==") == "test", "Base64 decoding failed")
end)

test("crypt.encrypt", {}, function()
	local cryptLib = getGlobal("crypt")
	assert(cryptLib and cryptLib.encrypt and cryptLib.decrypt and cryptLib.generatekey, "crypt library incomplete")
	local key = cryptLib.generatekey()
	local encrypted, iv = cryptLib.encrypt("test", key, nil, "CBC")
	assert(iv ~= nil, "crypt.encrypt should return an IV")
	local decrypted = cryptLib.decrypt(encrypted, key, iv, "CBC")
	assert(decrypted == "test", "Decryption failed")
end)

test("crypt.decrypt", {}, function()
	local cryptLib = getGlobal("crypt")
	assert(cryptLib and cryptLib.encrypt and cryptLib.decrypt and cryptLib.generatekey, "crypt library incomplete")
	local key, iv = cryptLib.generatekey(), cryptLib.generatekey()
	local encrypted = cryptLib.encrypt("test", key, iv, "CBC")
	local decrypted = cryptLib.decrypt(encrypted, key, iv, "CBC")
	assert(decrypted == "test", "Decryption failed")
end)

test("crypt.generatebytes", {}, function()
	local cryptLib = getGlobal("crypt")
	assert(cryptLib and cryptLib.generatebytes and cryptLib.base64decode, "crypt.generatebytes missing")
	local size = math.random(10, 100)
	local bytes = cryptLib.generatebytes(size)
	assert(#cryptLib.base64decode(bytes) == size, "Decoded result should be " .. size .. " bytes long (got " .. #cryptLib.base64decode(bytes) .. ")")
end)

test("crypt.generatekey", {}, function()
	local cryptLib = getGlobal("crypt")
	assert(cryptLib and cryptLib.generatekey and cryptLib.base64decode, "crypt.generatekey missing")
	local key = cryptLib.generatekey()
	assert(#cryptLib.base64decode(key) == 32, "Generated key should decode to 32 bytes")
end)

test("crypt.hash", {}, function()
	local cryptLib = getGlobal("crypt")
	assert(cryptLib and cryptLib.hash, "crypt.hash missing")
	local algorithms = {'sha1', 'sha384', 'sha512', 'md5', 'sha256', 'sha3-224', 'sha3-256', 'sha3-512'}
	for _, algorithm in ipairs(algorithms) do
		local hash = cryptLib.hash("test", algorithm)
		assert(hash, "crypt.hash('" .. algorithm .. "') returned nil")
	end
end)

--- Debug

test("debug.getconstant", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.getconstant, "debug.getconstant missing")

	local function testFn()
		print("Hello, world!")
	end
	assert(dbg.getconstant(testFn, 1) == "print", "First constant must be print")
	assert(dbg.getconstant(testFn, 2) == nil, "Second constant must be nil")
	assert(dbg.getconstant(testFn, 3) == "Hello, world!", "Third constant must be 'Hello, world!'")
end)

test("debug.getconstants", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.getconstants, "debug.getconstants missing")

	local function testFn()
		local num = 50000
		print("Hello, world!", num, warn)
	end

	local constants = dbg.getconstants(testFn)
	assert(type(constants) == "table", "debug.getconstants should return a table")
	assert(constants[1] == 50000, "First constant must be 50000")
	assert(constants[2] == "print", "Second constant must be print")
	assert(constants[3] == nil, "Third constant must be nil")
	assert(constants[4] == "Hello, world!", "Fourth constant must be 'Hello, world!'")
	assert(constants[5] == "warn", "Fifth constant must be warn")
end)

test("debug.getinfo", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.getinfo, "debug.getinfo missing")

	local expected = {
		source = "string",
		short_src = "string",
		func = "function",
		what = "string",
		currentline = "number",
		name = "string",
		nups = "number",
		numparams = "number",
		is_vararg = "number",
	}

	local function testFn(...)
		print(...)
	end

	local info = dbg.getinfo(testFn)
	assert(type(info) == "table", "debug.getinfo should return a table")

	for k, v in pairs(expected) do
		assert(info[k] ~= nil, "Missing '" .. k .. "' field")
		assert(type(info[k]) == v, "Expected " .. k .. " to be " .. v .. " (got " .. type(info[k]) .. ")")
	end
end)

test("debug.getproto", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.getproto, "debug.getproto missing")

	local function outer()
		local function inner()
			return true
		end
	end

	local proto = dbg.getproto(outer, 1, true)
	assert(proto and proto[1], "Failed to get inner function prototype")

	local realproto = dbg.getproto(outer, 1)
	assert(proto[1]() == true, "Inner function did not return true")

	if not realproto or not realproto() then
		return "Proto return values disabled on this executor"
	end
end)

test("debug.getprotos", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.getprotos, "debug.getprotos missing")

	local function outer()
		local function a() return true end
		local function b() return true end
		local function c() return true end
	end

	for i in ipairs(dbg.getprotos(outer)) do
		local proto = dbg.getproto(outer, i, true)
		assert(proto and proto[1] and proto[1](), "Failed to get inner proto " .. i)
	end
end)

test("debug.getstack", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.getstack, "debug.getstack missing")

	local concat = "a" .. "b"
	assert(dbg.getstack(1, 1) == "ab", "First item in stack should be 'ab'")
	assert(dbg.getstack(1)[1] == "ab", "First item in stack table should be 'ab'")
end)

test("debug.getupvalue", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.getupvalue, "debug.getupvalue missing")

	local upvalue = function() end
	local function testFn()
		print(upvalue)
	end
	assert(dbg.getupvalue(testFn, 1) == upvalue, "Unexpected value from debug.getupvalue")
end)

test("debug.getupvalues", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.getupvalues, "debug.getupvalues missing")

	local upvalue = function() end
	local function testFn()
		print(upvalue)
	end
	local ups = dbg.getupvalues(testFn)
	assert(ups[1] == upvalue, "Unexpected upvalue result")
end)

test("debug.setconstant", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.setconstant, "debug.setconstant missing")

	local function testFn()
		return "fail"
	end

	dbg.setconstant(testFn, 1, "success")
	assert(testFn() == "success", "debug.setconstant did not modify the constant")
end)

test("debug.setstack", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.setstack, "debug.setstack missing")

	local function testFn()
		return "fail", dbg.setstack(1, 1, "success")
	end

	assert(testFn() == "success", "debug.setstack did not modify the stack item")
end)

test("debug.setupvalue", {}, function()
	local dbg = getGlobal("debug")
	assert(dbg and dbg.setupvalue, "debug.setupvalue missing")

	local function upv()
		return "fail"
	end
	local function testFn()
		return upv()
	end

	dbg.setupvalue(testFn, 1, function()
		return "success"
	end)

	assert(testFn() == "success", "debug.setupvalue did not modify upvalue")
end)

-- Filesystem

local function safe(p)
	return type(p) == "function"
end

if safe(isfolder) and safe(makefolder) and safe(delfolder) then
	if isfolder(".tests") then
		pcall(delfolder, ".tests")
	end
	pcall(makefolder, ".tests")
end

test("readfile", {}, function()
	assert(safe(writefile) and safe(readfile), "Filesystem APIs not found")
	writefile(".tests/readfile.txt", "success")
	assert(readfile(".tests/readfile.txt") == "success", "Did not return the correct file contents")
end)

test("listfiles", {}, function()
	assert(safe(listfiles) and safe(makefolder) and safe(writefile), "Missing filesystem functions")

	makefolder(".tests/listfiles")
	writefile(".tests/listfiles/test_1.txt", "success")
	writefile(".tests/listfiles/test_2.txt", "success")

	local files = listfiles(".tests/listfiles")
	assert(type(files) == "table", "listfiles should return a table")
	assert(#files == 2, "Did not return the correct number of files")
	assert(isfile(files[1]), "Returned path is not a file")
	assert(readfile(files[1]) == "success", "File content mismatch")

	makefolder(".tests/listfiles_2")
	makefolder(".tests/listfiles_2/test_1")
	makefolder(".tests/listfiles_2/test_2")

	local folders = listfiles(".tests/listfiles_2")
	assert(type(folders) == "table", "listfiles should return a table for folders")
	assert(#folders == 2, "Did not return correct folder count")
	assert(isfolder(folders[1]), "Returned path is not a folder")
end)

test("writefile", {}, function()
	assert(safe(writefile) and safe(readfile), "Filesystem APIs missing")

	writefile(".tests/writefile.txt", "success")
	assert(readfile(".tests/writefile.txt") == "success", "Did not write/read correctly")

	local ok, err = pcall(function()
		writefile(".tests/writefile", "success")
	end)

	if not ok then
		return "Executor requires file extension in writefile"
	end
end)

test("makefolder", {}, function()
	assert(safe(makefolder) and safe(isfolder), "Missing folder APIs")
	makefolder(".tests/makefolder")
	assert(isfolder(".tests/makefolder"), "Failed to create folder")
end)

test("appendfile", {}, function()
	assert(safe(appendfile) and safe(readfile) and safe(writefile), "Missing file APIs")

	writefile(".tests/appendfile.txt", "su")
	appendfile(".tests/appendfile.txt", "cce")
	appendfile(".tests/appendfile.txt", "ss")
	assert(readfile(".tests/appendfile.txt") == "success", "Did not append file correctly")
end)

test("isfile", {}, function()
	assert(safe(isfile) and safe(writefile), "Missing isfile/writefile")

	writefile(".tests/isfile.txt", "success")
	assert(isfile(".tests/isfile.txt") == true, "Should return true for file")
	assert(isfile(".tests") == false, "Should return false for folder")
	assert(isfile(".tests/doesnotexist.txt") == false, "Should return false for nonexistent file")
end)

test("isfolder", {}, function()
	assert(safe(isfolder), "Missing isfolder")
	assert(isfolder(".tests"), "Should return true for folder")
	assert(isfolder(".tests/doesnotexist.txt") == false, "Should return false for nonexistent path")
end)

test("delfolder", {}, function()
	assert(safe(delfolder) and safe(makefolder) and safe(isfolder), "Missing folder APIs")

	makefolder(".tests/delfolder")
	delfolder(".tests/delfolder")
	assert(not isfolder(".tests/delfolder"), "Failed to delete folder")
end)

test("delfile", {}, function()
	assert(safe(delfile) and safe(isfile) and safe(writefile), "Missing file APIs")

	writefile(".tests/delfile.txt", "Hello, world!")
	delfile(".tests/delfile.txt")
	assert(isfile(".tests/delfile.txt") == false, "Failed to delete file")
end)

test("loadfile", {}, function()
	assert(safe(writefile) and safe(loadfile), "Missing loadfile APIs")

	writefile(".tests/loadfile.txt", "return ... + 1")
	assert(assert(loadfile(".tests/loadfile.txt"))(1) == 2, "Failed to load and execute file with args")

	writefile(".tests/loadfile.txt", "f")
	local callback, err = loadfile(".tests/loadfile.txt")
	assert(err and not callback, "Should return an error for compiler error")
end)

test("dofile", {}, function()
	assert(safe(dofile) and safe(writefile), "Missing dofile/writefile")
	writefile(".tests/dofile.lua", "return 'success'")
	local result = dofile(".tests/dofile.lua")
	assert(result == "success", "dofile did not execute correctly")
end)

-- Input

test("isrbxactive", {"isgameactive"}, function()
	assert(type(isrbxactive()) == "boolean", "Did not return a boolean value")
end)

test("mouse1click", {}, function()
	if not mouse1click then return "mouse1click missing" end
	assert(pcall(mouse1click), "mouse1click failed to execute")
end)

test("mouse1press", {}, function()
	if not mouse1press then return "mouse1press missing" end
	assert(pcall(mouse1press), "mouse1press failed to execute")
end)

test("mouse1release", {}, function()
	if not mouse1release then return "mouse1release missing" end
	assert(pcall(mouse1release), "mouse1release failed to execute")
end)

test("mouse2click", {}, function()
	if not mouse2click then return "mouse2click missing" end
	assert(pcall(mouse2click), "mouse2click failed to execute")
end)

test("mouse2press", {}, function()
	if not mouse2press then return "mouse2press missing" end
	assert(pcall(mouse2press), "mouse2press failed to execute")
end)

test("mouse2release", {}, function()
	if not mouse2release then return "mouse2release missing" end
	assert(pcall(mouse2release), "mouse2release failed to execute")
end)

test("mousemoveabs", {}, function()
	if not mousemoveabs then return "mousemoveabs missing" end
	assert(pcall(mousemoveabs, 150, 150), "mousemoveabs failed")
end)

test("mousemoverel", {}, function()
	if not mousemoverel then return "mousemoverel missing" end
	assert(pcall(mousemoverel, 5, 5), "mousemoverel failed")
end)

test("mousescroll", {}, function()
	if not mousescroll then return "mousescroll missing" end
	assert(pcall(mousescroll, 1), "mousescroll failed")
end)

test("keypress", {}, function()
	if not keypress then return "keypress missing" end
	assert(pcall(keypress, Enum.KeyCode.E), "keypress failed for KeyCode.E")
end)

test("keyrelease", {}, function()
	if not keyrelease then return "keyrelease missing" end
	assert(pcall(keyrelease, Enum.KeyCode.E), "keyrelease failed for KeyCode.E")
end)

test("keyboard_press", {"keytap", "keyboardpress"}, function()
	if not (keypress and keyrelease) then return "keyboard input missing" end
	assert(pcall(function()
		keypress(Enum.KeyCode.F)
		task.wait(0.05)
		keyrelease(Enum.KeyCode.F)
	end), "keyboard_press simulation failed")
end)

test("touchpress", {}, function()
	if not touchpress then return "touchpress missing" end
	assert(pcall(touchpress, 100, 100), "touchpress failed")
end)

test("touchrelease", {}, function()
	if not touchrelease then return "touchrelease missing" end
	assert(pcall(touchrelease, 100, 100), "touchrelease failed")
end)

test("touchmove", {}, function()
	if not touchmove then return "touchmove missing" end
	assert(pcall(touchmove, 150, 150), "touchmove failed")
end)

test("inputpress", {}, function()
	if not inputpress then return "inputpress missing" end
	assert(pcall(inputpress, "MouseButton1"), "inputpress failed for MouseButton1")
end)

test("inputrelease", {}, function()
	if not inputrelease then return "inputrelease missing" end
	assert(pcall(inputrelease, "MouseButton1"), "inputrelease failed for MouseButton1")
end)

test("inputmove", {}, function()
	if not inputmove then return "inputmove missing" end
	assert(pcall(inputmove, 200, 200), "inputmove failed")
end)

test("virtualinputmanager", {"VirtualInputManager", "vim"}, function()
	local vimService = game:GetService("VirtualInputManager")
	assert(vimService, "VirtualInputManager not accessible")
	assert(typeof(vimService) == "Instance", "VirtualInputManager is not a valid instance")
end)

test("UserInputService", {"uis"}, function()
	local uis = game:GetService("UserInputService")
	assert(uis, "UserInputService not accessible")
	assert(uis:IsA("UserInputService"), "Did not return a valid UserInputService")
end)

-- Instances

test("fireclickdetector", {}, function()
	local detector = Instance.new("ClickDetector")
	fireclickdetector(detector, 50, "MouseHoverEnter")
end)

test("getcallbackvalue", {}, function()
	local bindable = Instance.new("BindableFunction")
	local function test()
	end
	bindable.OnInvoke = test
	assert(getcallbackvalue(bindable, "OnInvoke") == test, "Did not return the correct value")
end)

test("getconnections", {}, function()
	local types = {
		Enabled = "boolean",
		ForeignState = "boolean",
		LuaConnection = "boolean",
		Function = "function",
		Thread = "thread",
		Fire = "function",
		Defer = "function",
		Disconnect = "function",
		Disable = "function",
		Enable = "function",
	}
	local bindable = Instance.new("BindableEvent")
	bindable.Event:Connect(function() end)
	local connection = getconnections(bindable.Event)[1]
	for k, v in pairs(types) do
		assert(connection[k] ~= nil, "Did not return a table with a '" .. k .. "' field")
		assert(type(connection[k]) == v, "Did not return a table with " .. k .. " as a " .. v .. " (got " .. type(connection[k]) .. ")")
	end
end)

test("getcustomasset", {}, function()
	writefile(".tests/getcustomasset.txt", "success")
	local contentId = getcustomasset(".tests/getcustomasset.txt")
	assert(type(contentId) == "string", "Did not return a string")
	assert(#contentId > 0, "Returned an empty string")
	assert(string.match(contentId, "rbxasset://") == "rbxasset://", "Did not return an rbxasset url")
end)

test("gethiddenproperty", {}, function()
	local fire = Instance.new("Fire")
	local property, isHidden = gethiddenproperty(fire, "size_xml")
	assert(property == 5, "Did not return the correct value")
	assert(isHidden == true, "Did not return whether the property was hidden")
end)

test("sethiddenproperty", {}, function()
	local fire = Instance.new("Fire")
	local hidden = sethiddenproperty(fire, "size_xml", 10)
	assert(hidden, "Did not return true for the hidden property")
	assert(gethiddenproperty(fire, "size_xml") == 10, "Did not set the hidden property")
end)

test("gethui", {}, function()
	assert(typeof(gethui()) == "Instance", "Did not return an Instance")
end)

test("getinstances", {}, function()
	assert(getinstances()[1]:IsA("Instance"), "The first value is not an Instance")
end)

test("getnilinstances", {}, function()
	assert(getnilinstances()[1]:IsA("Instance"), "The first value is not an Instance")
	assert(getnilinstances()[1].Parent == nil, "The first value is not parented to nil")
end)

test("isscriptable", {}, function()
	local fire = Instance.new("Fire")
	assert(isscriptable(fire, "size_xml") == false, "Did not return false for a non-scriptable property (size_xml)")
	assert(isscriptable(fire, "Size") == true, "Did not return true for a scriptable property (Size)")
end)

test("setscriptable", {}, function()
	local fire = Instance.new("Fire")
	local wasScriptable = setscriptable(fire, "size_xml", true)
	assert(wasScriptable == false, "Did not return false for a non-scriptable property (size_xml)")
	assert(isscriptable(fire, "size_xml") == true, "Did not set the scriptable property")
	fire = Instance.new("Fire")
	assert(isscriptable(fire, "size_xml") == false, "setscriptable persists between unique instances")
end)

test("setrbxclipboard", {}, function()
	if not setrbxclipboard then return "setrbxclipboard missing" end
	assert(pcall(setrbxclipboard, "Test clipboard value"), "Failed to set Roblox clipboard")
end)

-- Metatable

test("getrawmetatable", {}, function()
	local metatable = { __metatable = "Locked!" }
	local object = setmetatable({}, metatable)
	assert(getrawmetatable(object) == metatable, "Did not return the metatable")
end)

test("hookmetamethod", {}, function()
	local object = setmetatable({}, { __index = newcclosure(function() return false end), __metatable = "Locked!" })
	local ref = hookmetamethod(object, "__index", function() return true end)
	assert(object.test == true, "Failed to hook a metamethod and change the return value")
	assert(ref() == false, "Did not return the original function")
end)

test("getnamecallmethod", {}, function()
	local method
	local ref
	ref = hookmetamethod(game, "__namecall", function(...)
		if not method then
			method = getnamecallmethod()
		end
		return ref(...)
	end)
	game:GetService("Lighting")
	assert(method == "GetService", "Did not get the correct method (GetService)")
end)

test("isreadonly", {}, function()
	local object = {}
	table.freeze(object)
	assert(isreadonly(object), "Did not return true for a read-only table")
end)

test("setrawmetatable", {}, function()
	local object = setmetatable({}, { __index = function() return false end, __metatable = "Locked!" })
	local objectReturned = setrawmetatable(object, { __index = function() return true end })
	assert(object, "Did not return the original object")
	assert(object.test == true, "Failed to change the metatable")
	if objectReturned then
		return objectReturned == object and "Returned the original object" or "Did not return the original object"
	end
end)

test("setreadonly", {}, function()
	local object = { success = false }
	table.freeze(object)
	setreadonly(object, false)
	object.success = true
	assert(object.success, "Did not allow the table to be modified")
end)

-- Miscellaneous

test("identifyexecutor", {"getexecutorname"}, function()
	local name, version = identifyexecutor()
	assert(type(name) == "string", "Did not return a string for the name")
	return type(version) == "string" and "Returns version as a string" or "Does not return version"
end)

test("lz4compress", {}, function()
	local raw = "Hello, world!"
	local compressed = lz4compress(raw)
	assert(type(compressed) == "string", "Compression did not return a string")
	assert(lz4decompress(compressed, #raw) == raw, "Decompression did not return the original string")
end)

test("lz4decompress", {}, function()
	local raw = "Hello, world!"
	local compressed = lz4compress(raw)
	assert(type(compressed) == "string", "Compression did not return a string")
	assert(lz4decompress(compressed, #raw) == raw, "Decompression did not return the original string")
end)

test("messagebox", {})

test("queue_on_teleport", {"queueonteleport"})

test("request", {"http.request", "http_request"}, function()
	local response = request({
		Url = "https://httpbin.org/user-agent",
		Method = "GET",
	})
	assert(type(response) == "table", "Response must be a table")
	assert(response.StatusCode == 200, "Did not return a 200 status code")
	local data = game:GetService("HttpService"):JSONDecode(response.Body)
	assert(type(data) == "table" and type(data["user-agent"]) == "string", "Did not return a table with a user-agent key")
	return "User-Agent: " .. data["user-agent"]
end)

test("setclipboard", {"toclipboard"})

test("setfpscap", {}, function()
	local renderStepped = game:GetService("RunService").RenderStepped
	local function step()
		renderStepped:Wait()
		local sum = 0
		for _ = 1, 5 do
			sum += 1 / renderStepped:Wait()
		end
		return math.round(sum / 5)
	end
	setfpscap(60)
	local step60 = step()
	setfpscap(0)
	local step0 = step()
	return step60 .. "fps @60 • " .. step0 .. "fps @0"
end)

-- Scripts

test("getgc", {}, function()
	local gc = getgc()
	assert(type(gc) == "table", "Did not return a table")
	assert(#gc > 0, "Did not return a table with any values")
end)

test("getgenv", {}, function()
	getgenv().__TEST_GLOBAL = true
	assert(__TEST_GLOBAL, "Failed to set a global variable")
	getgenv().__TEST_GLOBAL = nil
end)

test("getloadedmodules", {}, function()
	local modules = getloadedmodules()
	assert(type(modules) == "table", "Did not return a table")
	assert(#modules > 0, "Did not return a table with any values")
	assert(typeof(modules[1]) == "Instance", "First value is not an Instance")
	assert(modules[1]:IsA("ModuleScript"), "First value is not a ModuleScript")
end)

test("getrenv", {}, function()
	assert(_G ~= getrenv()._G, "The variable _G in the executor is identical to _G in the game")
end)

test("getrunningscripts", {}, function()
	local scripts = getrunningscripts()
	assert(type(scripts) == "table", "Did not return a table")
	assert(#scripts > 0, "Did not return a table with any values")
	assert(typeof(scripts[1]) == "Instance", "First value is not an Instance")
	assert(scripts[1]:IsA("ModuleScript") or scripts[1]:IsA("LocalScript"), "First value is not a ModuleScript or LocalScript")
end)

test("getscriptbytecode", {"dumpstring"}, function()
	local animate = game:GetService("Players").LocalPlayer.Character and game:GetService("Players").LocalPlayer.Character:FindFirstChild("Animate")
	assert(animate, "Animate script not found")
	local bytecode = getscriptbytecode(animate)
	assert(type(bytecode) == "string", "Did not return a string for Animate script")
end)

test("getscripthash", {}, function()
	local animate = game:GetService("Players").LocalPlayer.Character and game:GetService("Players").LocalPlayer.Character:FindFirstChild("Animate")
	assert(animate, "Animate script not found")
	local clone = animate:Clone()
	local hash = getscripthash(clone)
	local source = clone.Source
	clone.Source = "print('Hello, world!')"
	task.defer(function()
		clone.Source = source
	end)
	local newHash = getscripthash(clone)
	assert(hash ~= newHash, "Did not return a different hash for a modified script")
	assert(newHash == getscripthash(clone), "Did not return the same hash for a script with the same source")
end)

test("getscripts", {}, function()
	local scripts = getscripts()
	assert(type(scripts) == "table", "Did not return a table")
	assert(#scripts > 0, "Did not return a table with any values")
	assert(typeof(scripts[1]) == "Instance", "First value is not an Instance")
	assert(scripts[1]:IsA("ModuleScript") or scripts[1]:IsA("LocalScript"), "First value is not a ModuleScript or LocalScript")
end)

test("getsenv", {}, function()
	local animate = game:GetService("Players").LocalPlayer.Character and game:GetService("Players").LocalPlayer.Character:FindFirstChild("Animate")
	assert(animate, "Animate script not found")
	local env = getsenv(animate)
	assert(type(env) == "table", "Did not return a table for Animate script")
	assert(env.script == animate, "The script global is not identical to Animate")
end)

test("getthreadidentity", {"getidentity", "getthreadcontext"}, function()
	assert(type(getthreadidentity()) == "number", "Did not return a number")
end)

test("setthreadidentity", {"setidentity", "setthreadcontext"}, function()
	setthreadidentity(3)
	assert(getthreadidentity() == 3, "Did not set the thread identity")
end)

-- Drawing

test("Drawing", {}, function()
	assert(Drawing ~= nil, "Drawing library not found")
end)

test("Drawing.new", {}, function()
	local drawing = Drawing.new("Square")
	assert(drawing ~= nil, "Failed to create Drawing object")
	drawing.Visible = false
	local success = pcall(function()
		drawing:Destroy()
	end)
	assert(success, "Drawing:Destroy() should not throw an error")
end)

test("Drawing.Fonts", {}, function()
	assert(type(Drawing.Fonts) == "table", "Drawing.Fonts is not a table")
	assert(Drawing.Fonts.UI == 0, "Incorrect ID for UI font")
	assert(Drawing.Fonts.System == 1, "Incorrect ID for System font")
	assert(Drawing.Fonts.Plex == 2, "Incorrect ID for Plex font")
	assert(Drawing.Fonts.Monospace == 3, "Incorrect ID for Monospace font")
end)

test("isrenderobj", {}, function()
	local drawing = Drawing.new("Image")
	drawing.Visible = true
	assert(isrenderobj(drawing) == true, "Did not return true for Drawing object")
	assert(isrenderobj(newproxy()) == false, "Did not return false for invalid object")
	drawing:Destroy()
end)

test("getrenderproperty", {}, function()
	local drawing = Drawing.new("Image")
	drawing.Visible = true
	assert(type(getrenderproperty(drawing, "Visible")) == "boolean", "Did not return a boolean for Visible")
	local ok, result = pcall(function()
		return getrenderproperty(drawing, "Color")
	end)
	if not ok or result == nil then
		return "Image.Color not supported"
	end
	drawing:Destroy()
end)

test("setrenderproperty", {}, function()
	local drawing = Drawing.new("Square")
	drawing.Visible = true
	setrenderproperty(drawing, "Visible", false)
	assert(drawing.Visible == false, "Did not set Visible to false")
	drawing:Destroy()
end)

test("cleardrawcache", {}, function()
	cleardrawcache()
end)

-- WebSocket

test("WebSocket", {}, function()
	assert(WebSocket ~= nil, "WebSocket library not found")
end)

test("WebSocket.connect", {}, function()
	local types = {
		Send = "function",
		Close = "function",
		OnMessage = {"table", "userdata"},
		OnClose = {"table", "userdata"},
	}
	local ws = WebSocket.connect("ws://echo.websocket.events")
	assert(type(ws) == "table" or type(ws) == "userdata", "Did not return a table or userdata")
	for k, v in pairs(types) do
		if type(v) == "table" then
			assert(table.find(v, type(ws[k])), "Did not return a " .. table.concat(v, ", ") .. " for " .. k .. " (got " .. type(ws[k]) .. ")")
		else
			assert(type(ws[k]) == v, "Did not return a " .. v .. " for " .. k .. " (got " .. type(ws[k]) .. ")")
		end
	end
	ws:Close()
end)