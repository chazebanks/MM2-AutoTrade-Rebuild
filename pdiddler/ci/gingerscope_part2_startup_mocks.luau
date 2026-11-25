-- Offline regression of the unchanged historical Part 2 and startup gate.
-- Every clock, GUI node, input call, and stack dependency is in memory.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local part2Source = fs.readFile("pdiddler/pdiddler2.lua")
local knownGood = fs.readFile("pdiddler/pdiddler2_KNOWN_GOOD.lua")
local stackSource = fs.readFile("pdiddler/pdiddler_success_stack_1_2_3scanner.lua")
assert(part2Source == knownGood, "historical Part 2 copies differ")

local function equal(actual, expected, description)
    assert(actual == expected, description .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local guiClasses = {Frame = true, TextLabel = true, TextButton = true, ImageButton = true}
local function node(parent, class, name, text, x)
    local item = {
        Parent = parent,
        ClassName = class,
        Name = name,
        Text = text,
        Visible = true,
        Enabled = true,
        AbsolutePosition = {X = x or 0, Y = 10},
        AbsoluteSize = {X = 30, Y = 20},
        Children = {},
    }
    if parent then
        table.insert(parent.Children, item)
    end

    function item:IsA(query)
        return query == self.ClassName or (query == "GuiObject" and guiClasses[self.ClassName] == true)
    end

    function item:GetDescendants()
        local result = {}
        local function addChildren(root)
            for _, child in ipairs(root.Children) do
                table.insert(result, child)
                addChildren(child)
            end
        end
        addChildren(self)
        return result
    end

    function item:GetFullName()
        return self.Parent and self.Parent:GetFullName() .. "." .. self.Name or self.Name
    end
    return item
end

local function fixture(options)
    local now = 0
    local fixtureGui = node(nil, "PlayerGui", "MemoryPlayerGui")
    local optionalGui = node(nil, "CoreGui", "MemoryCoreGui")
    local screen = node(fixtureGui, "ScreenGui", "MemoryScreen")
    local tablet = node(screen, "Frame", "DevicePicker")
    local friend = node(screen, "Frame", "FriendPrompt")
    local pressed, mouse = {}, {}

    tablet.Visible = options.tablet == true
    friend.Visible = options.friend == true

    local function button(parent, name, text, x, disappear)
        local control = node(parent, "TextButton", name, text, x)
        function control:Activate()
            table.insert(pressed, self.Name)
            if disappear then
                self.Parent.Visible = false
            end
        end
        return control
    end

    button(tablet, "Phone", "Phone", 30, false)
    button(tablet, "Tablet", "iPad", 60, options.dismissTablet)
    node(friend, "TextLabel", "Title", "Joining a friend?")
    button(friend, "Join", "Join", 90, false)
    button(friend, "Play", "Play anyway", 120, options.dismissFriend)
    button(node(screen, "Frame", "Unrelated"), "UnrelatedPlay", "Play", 150, false)

    local mockGame = {}
    local services = {
        CoreGui = optionalGui,
        Players = {
            LocalPlayer = {
                FindFirstChildOfClass = function(_, class)
                    equal(class, "PlayerGui", "only reads the synthetic player GUI")
                    return fixtureGui
                end,
            },
        },
        VirtualInputManager = {
            SendMouseButtonEvent = function(_, x, y, mouseButton, down, target, pointer)
                assert(target == mockGame, "input target must be in memory")
                equal(y, 20, "mock button center y")
                equal(mouseButton, 0, "mock mouse button")
                equal(pointer, 0, "mock pointer channel")
                table.insert(mouse, {x = x, down = down})
            end,
        },
    }
    function mockGame:GetService(name)
        return assert(services[name], "unexpected service in offline Part 2")
    end

    local env = {
        game = mockGame,
        os = {clock = function() return now end},
        task = {
            wait = function(seconds)
                now += seconds
                assert(now < 40, "startup must finish within the synthetic clock limit")
                if options.tabletAt and now >= options.tabletAt then
                    tablet.Visible = true
                end
                if options.friendAt and now >= options.friendAt then
                    friend.Visible = true
                end
            end,
        },
        ipairs = ipairs,
        math = math,
        pcall = pcall,
        print = function() end,
        tostring = tostring,
        type = type,
        warn = function() end,
    }
    return {
        env = env, pressed = pressed, mouse = mouse,
        clock = function() return now end,
        mockGame = mockGame,
    }
end

local function runPart2(case)
    return luau.load(part2Source, {environment = case.env, injectGlobals = false})().run()
end

local function checkClicks(case, expectedNames, expectedX)
    equal(table.concat(case.pressed, ","), table.concat(expectedNames, ","), "ordered local activations")
    equal(#case.mouse, #expectedX * 2, "mock pointer down-up count")
    for index, x in ipairs(expectedX) do
        local down, up = case.mouse[index * 2 - 1], case.mouse[index * 2]
        equal(down.x, x, "mock pointer down center")
        equal(up.x, x, "mock pointer up center")
        equal(down.down, true, "mock pointer down first")
        equal(up.down, false, "mock pointer up last")
    end
end

do
    local case = fixture({tablet = true, friend = true, dismissTablet = true, dismissFriend = true})
    equal(runPart2(case), true, "both prompts dismissed")
    checkClicks(case, {"Tablet", "Play"}, {75, 135})
end

do
    local case = fixture({})
    equal(runPart2(case), true, "both optional prompts absent")
    checkClicks(case, {}, {})
    assert(case.clock() >= 28 and case.clock() < 28.4, "both bounded waits finish with no input")
end

do
    local case = fixture({tablet = true, dismissTablet = true, friendAt = 4})
    equal(runPart2(case), true, "friend prompt absent during its polling window")
    checkClicks(case, {"Tablet"}, {75})
    assert(case.clock() >= 3.65 and case.clock() < 4, "late friend prompt is not polled")
end

do
    local case = fixture({tablet = true, friend = true})
    equal(runPart2(case), false, "persistent Tablet picker blocks downstream startup")
    checkClicks(case, {"Tablet", "Tablet", "Tablet", "Tablet"}, {75, 75, 75, 75})
    assert(case.clock() < 5, "Tablet retry limit ends the stage")
end

do
    local case = fixture({tabletAt = 24.75, friend = true})
    equal(runPart2(case), false, "late Tablet picker expires without Play")
    checkClicks(case, {"Tablet"}, {75})
    assert(case.clock() >= 25 and case.clock() < 26.15, "only the in-progress click and waits overrun expiry")
end

do
    local case = fixture({tablet = true, dismissTablet = true, friend = true})
    equal(runPart2(case), false, "visible friend prompt that does not dismiss blocks readiness")
    checkClicks(case, {"Tablet", "Play", "Play", "Play"}, {75, 135, 135, 135})
    assert(case.clock() >= 3.65 and case.clock() < 5, "friend timeout ends the stage")
end

local function runStack(case, part1Ready)
    local modules = {}
    local function marker(name)
        table.insert(modules, name)
    end
    local stubs = {
        ["pdiddler1.lua"] = "return {run=function() mark('part1'); return ready end}",
        ["pdiddler2.lua"] = part2Source,
        ["pdiddler3_scanner_KNOWN_GOOD_v5.lua"] = "mark('scanner'); return {}",
    }
    case.env.mark = marker
    case.env.ready = part1Ready
    case.env.error = error
    case.env.loadstring = function(source)
        return luau.load(source, {environment = case.env, injectGlobals = false})
    end
    function case.mockGame:HttpGet(url)
        local name = url:match("/([^/]+)$")
        local source = assert(stubs[name], "unexpected historical stack dependency")
        marker("load " .. name)
        return source
    end
    local result = luau.load(stackSource, {environment = case.env, injectGlobals = false})()
    return result, table.concat(modules, ",")
end

do
    local case = fixture({tablet = true, friend = true, dismissTablet = true, dismissFriend = true})
    local result, modules = runStack(case, false)
    equal(result, false, "Part 1 gate stops startup")
    equal(modules, "load pdiddler1.lua,part1", "Part 2 is not loaded before Part 1 readiness")
    checkClicks(case, {}, {})
end

do
    local case = fixture({tablet = true, friend = true})
    local result, modules = runStack(case, true)
    equal(result, false, "Part 2 failure stops stack")
    equal(modules, "load pdiddler1.lua,part1,load pdiddler2.lua", "scanner dependency is not loaded")
    checkClicks(case, {"Tablet", "Tablet", "Tablet", "Tablet"}, {75, 75, 75, 75})
end

do
    local case = fixture({tablet = true, friend = true, dismissTablet = true, dismissFriend = true})
    local result, modules = runStack(case, true)
    equal(result, true, "Part 2 readiness unblocks the scanner dependency")
    equal(modules, "load pdiddler1.lua,part1,load pdiddler2.lua,load pdiddler3_scanner_KNOWN_GOOD_v5.lua,scanner",
        "startup dependency order")
    checkClicks(case, {"Tablet", "Play"}, {75, 135})
end

print("PASS: 9 offline Part 2/startup scenarios")
