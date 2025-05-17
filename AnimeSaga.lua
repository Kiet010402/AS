-- Anime Saga Script

-- Hệ thống kiểm soát logs
local LogSystem = {
    Enabled = true, -- Mặc định bật logs
    WarningsEnabled = true -- Mặc định bật cả warnings
}

-- Ghi đè hàm print để kiểm soát logs
local originalPrint = print
print = function(...)
    if LogSystem.Enabled then
        originalPrint(...)
    end
end

-- Ghi đè hàm warn để kiểm soát warnings
local originalWarn = warn
warn = function(...)
    if LogSystem.WarningsEnabled then
        originalWarn(...)
    end
end

-- Tải thư viện Fluent
local success, err = pcall(function()
    Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
    SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
    InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
end)

if not success then
    warn("Lỗi khi tải thư viện Fluent: " .. tostring(err))
    -- Thử tải từ URL dự phòng
    pcall(function()
        Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Fluent.lua"))()
        SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
        InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
    end)
end

if not Fluent then
    error("Không thể tải thư viện Fluent. Vui lòng kiểm tra kết nối internet hoặc executor.")
    return
end

-- Utility function để kiểm tra và lấy service/object một cách an toàn
local function safeGetService(serviceName)
    local success, service = pcall(function()
        return game:GetService(serviceName)
    end)
    return success and service or nil
end

-- Utility function để kiểm tra và lấy child một cách an toàn
local function safeGetChild(parent, childName, waitTime)
    if not parent then return nil end
    
    local child = parent:FindFirstChild(childName)
    
    -- Chỉ sử dụng WaitForChild nếu thực sự cần thiết
    if not child and waitTime and waitTime > 0 then
        local success, result = pcall(function()
            return parent:WaitForChild(childName, waitTime)
        end)
        if success then child = result end
    end
    
    return child
end

-- Utility function để lấy đường dẫn đầy đủ một cách an toàn
local function safeGetPath(startPoint, path, waitTime)
    if not startPoint then return nil end
    waitTime = waitTime or 0.5 -- Giảm thời gian chờ mặc định xuống 0.5 giây
    
    local current = startPoint
    for _, name in ipairs(path) do
        if not current then return nil end
        current = safeGetChild(current, name, waitTime)
    end
    
    return current
end

-- Hệ thống lưu trữ cấu hình
local ConfigSystem = {}
ConfigSystem.FileName = "AnimeSagaConfig_" .. game:GetService("Players").LocalPlayer.Name .. ".json"
ConfigSystem.DefaultConfig = {
    -- Các cài đặt mặc định
    UITheme = "Amethyst",
    
    -- Cài đặt log
    LogsEnabled = true,
    WarningsEnabled = true,
    
    -- Cài đặt Story
    SelectedMap = 1,
    SelectedAct = 1,
    SelectedDifficulty = 1,
    AutoJoinStory = false,
    
    -- Cài đặt Auto Gameplay
    AutoAttack = false,
    AutoSkill1 = false,
    AutoSkill2 = false,
    AutoSkill3 = false,
    
    -- Các cài đặt khác sẽ được thêm vào sau
}
ConfigSystem.CurrentConfig = {}

-- Cache cho ConfigSystem để giảm lượng I/O
ConfigSystem.LastSaveTime = 0
ConfigSystem.SaveCooldown = 2 -- 2 giây giữa các lần lưu
ConfigSystem.PendingSave = false

-- Hàm để lưu cấu hình
ConfigSystem.SaveConfig = function()
    -- Kiểm tra thời gian từ lần lưu cuối
    local currentTime = os.time()
    if currentTime - ConfigSystem.LastSaveTime < ConfigSystem.SaveCooldown then
        -- Đã lưu gần đây, đánh dấu để lưu sau
        ConfigSystem.PendingSave = true
        return
    end
    
    local success, err = pcall(function()
        local HttpService = game:GetService("HttpService")
        writefile(ConfigSystem.FileName, HttpService:JSONEncode(ConfigSystem.CurrentConfig))
    end)
    
    if success then
        ConfigSystem.LastSaveTime = currentTime
        ConfigSystem.PendingSave = false
    else
        warn("Lưu cấu hình thất bại:", err)
    end
end

-- Hàm để tải cấu hình
ConfigSystem.LoadConfig = function()
    local success, content = pcall(function()
        if isfile(ConfigSystem.FileName) then
            return readfile(ConfigSystem.FileName)
        end
        return nil
    end)
    
    if success and content then
        local success2, data = pcall(function()
            local HttpService = game:GetService("HttpService")
            return HttpService:JSONDecode(content)
        end)
        
        if success2 and data then
            -- Merge with default config to ensure all settings exist
            for key, value in pairs(ConfigSystem.DefaultConfig) do
                if data[key] == nil then
                    data[key] = value
                end
            end
            
        ConfigSystem.CurrentConfig = data
        
        -- Cập nhật cài đặt log
        if data.LogsEnabled ~= nil then
            LogSystem.Enabled = data.LogsEnabled
        end
        
        if data.WarningsEnabled ~= nil then
            LogSystem.WarningsEnabled = data.WarningsEnabled
        end
        
        return true
        end
    end
    
    -- Nếu tải thất bại, sử dụng cấu hình mặc định
        ConfigSystem.CurrentConfig = table.clone(ConfigSystem.DefaultConfig)
        ConfigSystem.SaveConfig()
        return false
    end

-- Thiết lập timer để lưu định kỳ nếu có thay đổi chưa lưu
spawn(function()
    while wait(5) do
        if ConfigSystem.PendingSave then
            ConfigSystem.SaveConfig()
        end
    end
end)

-- Tải cấu hình khi khởi động
ConfigSystem.LoadConfig()

-- Thông tin người chơi
local playerName = game:GetService("Players").LocalPlayer.Name

-- Biến lưu trạng thái story
local selectedMap = ConfigSystem.CurrentConfig.SelectedMap or 1
local selectedAct = ConfigSystem.CurrentConfig.SelectedAct or 1
local selectedDifficulty = ConfigSystem.CurrentConfig.SelectedDifficulty or 1
local autoJoinStoryEnabled = ConfigSystem.CurrentConfig.AutoJoinStory or false
local autoJoinStoryLoop = nil

-- Biến lưu trạng thái gameplay
local autoAttackEnabled = ConfigSystem.CurrentConfig.AutoAttack or false
local autoSkill1Enabled = ConfigSystem.CurrentConfig.AutoSkill1 or false
local autoSkill2Enabled = ConfigSystem.CurrentConfig.AutoSkill2 or false
local autoSkill3Enabled = ConfigSystem.CurrentConfig.AutoSkill3 or false
local autoAttackLoop = nil
local autoSkill1Loop = nil
local autoSkill2Loop = nil
local autoSkill3Loop = nil

-- Tạo Window
local Window = Fluent:CreateWindow({
    Title = "HT Hub | Anime Saga",
    SubTitle = "",
    TabWidth = 140,
    Size = UDim2.fromOffset(450, 350),
    Acrylic = true,
    Theme = ConfigSystem.CurrentConfig.UITheme or "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Tạo tab Info
local InfoTab = Window:AddTab({
    Title = "Info",
    Icon = "rbxassetid://7733964719"
})

-- Tạo tab Play
local PlayTab = Window:AddTab({
    Title = "Play",
    Icon = "rbxassetid://7743871480"
})

-- Tạo tab In-game
local InGameTab = Window:AddTab({
    Title = "In-game",
    Icon = "rbxassetid://7743866529"
})

-- Thêm hỗ trợ Logo khi minimize
repeat task.wait(0.25) until game:IsLoaded()
getgenv().Image = "rbxassetid://90319448802378" -- ID tài nguyên hình ảnh logo
getgenv().ToggleUI = "LeftControl" -- Phím để bật/tắt giao diện

-- Tạo logo để mở lại UI khi đã minimize
task.spawn(function()
    local success, errorMsg = pcall(function()
        if not getgenv().LoadedMobileUI == true then 
            getgenv().LoadedMobileUI = true
            local OpenUI = Instance.new("ScreenGui")
            local ImageButton = Instance.new("ImageButton")
            local UICorner = Instance.new("UICorner")
            
            -- Kiểm tra môi trường
            if syn and syn.protect_gui then
                syn.protect_gui(OpenUI)
                OpenUI.Parent = game:GetService("CoreGui")
            elseif gethui then
                OpenUI.Parent = gethui()
            else
                OpenUI.Parent = game:GetService("CoreGui")
            end
            
            OpenUI.Name = "OpenUI"
            OpenUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            
            ImageButton.Parent = OpenUI
            ImageButton.BackgroundColor3 = Color3.fromRGB(105,105,105)
            ImageButton.BackgroundTransparency = 0.8
            ImageButton.Position = UDim2.new(0.9,0,0.1,0)
            ImageButton.Size = UDim2.new(0,50,0,50)
            ImageButton.Image = getgenv().Image
            ImageButton.Draggable = true
            ImageButton.Transparency = 0.2
            
            UICorner.CornerRadius = UDim.new(0,200)
            UICorner.Parent = ImageButton
            
            -- Khi click vào logo sẽ mở lại UI
            ImageButton.MouseButton1Click:Connect(function()
                game:GetService("VirtualInputManager"):SendKeyEvent(true,getgenv().ToggleUI,false,game)
            end)
        end
    end)
    
    if not success then
        warn("Lỗi khi tạo nút Logo UI: " .. tostring(errorMsg))
    end
end)

-- Tự động chọn tab Info khi khởi động
Window:SelectTab(1) -- Chọn tab đầu tiên (Info)

-- Thêm section thông tin trong tab Info
local InfoSection = InfoTab:AddSection("Thông tin")

InfoSection:AddParagraph({
    Title = "Anime Saga",
    Content = "Phiên bản: 1.0 Beta\nTrạng thái: Hoạt động"
})

InfoSection:AddParagraph({
    Title = "Người phát triển",
    Content = "Script được phát triển bởi Dương Tuấn và ghjiukliop"
})

-- Thêm section Story trong tab Play
local StorySection = PlayTab:AddSection("Story")

-- Hàm để tham gia Story
local function joinStory()
    local success, err = pcall(function()
        -- Bước 1: Tạo phòng
        local args1 = {
            "Create",
            "Story",
            selectedMap,  -- Map (1 = Leaf Village, 2 = Marine Island, 3 = Red Light District, 4 = West City)
            selectedAct,  -- Act (1-5)
            selectedDifficulty,  -- Difficulty (1 = Normal, 2 = Hard, 3 = Nightmare)
            false
        }
        
        game:GetService("ReplicatedStorage"):WaitForChild("Event"):WaitForChild("JoinRoom"):FireServer(unpack(args1))
        
        -- Chờ một chút giữa hai lệnh
        wait(1)
        
        -- Bước 2: Teleport vào gameplay
        local args2 = {
            [1] = "TeleGameplay",
            [2] = "Story",
            [3] = selectedMap,  -- Map (1 = Leaf Village, 2 = Marine Island, 3 = Red Light District, 4 = West City)
            [4] = selectedAct,  -- Act (1-5)
            [5] = selectedDifficulty,  -- Difficulty (1 = Normal, 2 = Hard, 3 = Nightmare)
            [6] = false
        }
        
        game:GetService("ReplicatedStorage").Event.JoinRoom:FireServer(unpack(args2))
        
        -- Hiển thị thông báo
        local mapNames = {"Leaf Village", "Marine Island", "Red Light District", "West City"}
        local difficultyNames = {"Normal", "Hard", "Nightmare"}
        
        print("Đã tham gia Story: " .. mapNames[selectedMap] .. " - Act " .. selectedAct .. " - " .. difficultyNames[selectedDifficulty])
    end)
    
    if not success then
        warn("Lỗi khi tham gia Story: " .. tostring(err))
        return false
    end
    
    return true
end

-- Kiểm tra xem người chơi đã ở trong map chưa
local function isPlayerInMap()
    -- Implement checking logic here
    return false -- Placeholder
end

-- Dropdown để chọn Map
StorySection:AddDropdown("MapDropdown", {
    Title = "Choose Map",
    Values = {"Leaf Village", "Marine Island", "Red Light District", "West City"},
    Multi = false,
    Default = selectedMap,
    Callback = function(Value)
        local mapIndex = {
            ["Leaf Village"] = 1,
            ["Marine Island"] = 2,
            ["Red Light District"] = 3,
            ["West City"] = 4
        }
        
        selectedMap = mapIndex[Value]
        ConfigSystem.CurrentConfig.SelectedMap = selectedMap
        ConfigSystem.SaveConfig()
        print("Đã chọn map: " .. Value .. " (index: " .. selectedMap .. ")")
    end
})

-- Dropdown để chọn Act
StorySection:AddDropdown("ActDropdown", {
    Title = "Choose Act",
    Values = {"1", "2", "3", "4", "5"},
    Multi = false,
    Default = tostring(selectedAct),
    Callback = function(Value)
        selectedAct = tonumber(Value)
        ConfigSystem.CurrentConfig.SelectedAct = selectedAct
        ConfigSystem.SaveConfig()
        print("Đã chọn act: " .. Value)
    end
})

-- Dropdown để chọn Difficulty
StorySection:AddDropdown("DifficultyDropdown", {
    Title = "Difficulty",
    Values = {"Normal", "Hard", "Nightmare"},
    Multi = false,
    Default = ({"Normal", "Hard", "Nightmare"})[selectedDifficulty],
    Callback = function(Value)
        local difficultyIndex = {
            ["Normal"] = 1,
            ["Hard"] = 2,
            ["Nightmare"] = 3
        }
        
        selectedDifficulty = difficultyIndex[Value]
        ConfigSystem.CurrentConfig.SelectedDifficulty = selectedDifficulty
        ConfigSystem.SaveConfig()
        print("Đã chọn difficulty: " .. Value .. " (index: " .. selectedDifficulty .. ")")
    end
})

-- Toggle Auto Join Story
StorySection:AddToggle("AutoJoinStoryToggle", {
    Title = "Auto Join Story",
    Default = autoJoinStoryEnabled,
    Callback = function(Value)
        autoJoinStoryEnabled = Value
        ConfigSystem.CurrentConfig.AutoJoinStory = Value
        ConfigSystem.SaveConfig()
        
        if autoJoinStoryEnabled then
            print("Auto Join Story đã được bật")
            
            -- Thực hiện tham gia Story ngay lập tức
            spawn(function()
                if not isPlayerInMap() then
                    joinStory()
                else
                    print("Đang ở trong map, Auto Join Story sẽ hoạt động khi bạn rời khỏi map")
                end
            end)
            
            -- Tạo vòng lặp Auto Join Story
            spawn(function()
                while autoJoinStoryEnabled and wait(5) do -- Kiểm tra mỗi 5 giây
                    if not isPlayerInMap() then
                        joinStory()
                    end
                end
            end)
        else
            print("Auto Join Story đã được tắt")
        end
    end
})

-- Thêm nút Join Story ngay lập tức
StorySection:AddButton({
    Title = "Join Story Now",
    Callback = function()
        joinStory()
    end
})

-- Thêm section thiết lập trong tab Settings
local SettingsTab = Window:AddTab({
    Title = "Settings",
    Icon = "rbxassetid://6031280882"
})

local SettingsSection = SettingsTab:AddSection("Thiết lập")

-- Dropdown chọn theme
SettingsSection:AddDropdown("ThemeDropdown", {
    Title = "Chọn Theme",
    Values = {"Dark", "Light", "Darker", "Aqua", "Amethyst"},
    Multi = false,
    Default = ConfigSystem.CurrentConfig.UITheme or "Dark",
    Callback = function(Value)
        ConfigSystem.CurrentConfig.UITheme = Value
        ConfigSystem.SaveConfig()
        print("Đã chọn theme: " .. Value)
    end
})

-- Thêm section Redeem Codes
local RedeemSection = SettingsTab:AddSection("Redeem Codes")

-- Nút Redeem All Codes
RedeemSection:AddButton({
    Title = "Redeem All Codes",
    Callback = function()
        local codes = {
            "Release",
            "SorryForDelay",
            "SorryForShutdown",
            "50KActive",
            "1MVisits",
            "InBugSagaWeTrust"
        }
        
        -- Redeem tất cả code
        spawn(function()
            for _, code in ipairs(codes) do
                local success, err = pcall(function()
                    local args = {
                        code
                    }
                    game:GetService("ReplicatedStorage"):WaitForChild("Event"):WaitForChild("Codes"):FireServer(unpack(args))
                end)
                
                if success then
                    print("Đã redeem code: " .. code)
                else
                    warn("Lỗi khi redeem code " .. code .. ": " .. tostring(err))
                end
                
                -- Đợi một khoảng thời gian ngắn giữa các lần redeem
                wait(0.5)
            end
            
            -- Hiển thị thông báo khi đã redeem xong tất cả codes
            print("Đã redeem tất cả các codes!")
        end)
    end
})

-- Thêm input box cho custom code
local customCodeInput = nil
customCodeInput = RedeemSection:AddInput("CustomCodeInput", {
    Title = "Custom Code",
    Placeholder = "Nhập code tại đây",
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        if Value and Value ~= "" then
            local success, err = pcall(function()
                local args = {
                    Value
                }
                game:GetService("ReplicatedStorage"):WaitForChild("Event"):WaitForChild("Codes"):FireServer(unpack(args))
            end)
            
            if success then
                print("Đã redeem code: " .. Value)
                -- Reset input box sau khi redeem
                if customCodeInput and customCodeInput.Set then
                    customCodeInput:Set("")
                end
            else
                warn("Lỗi khi redeem code " .. Value .. ": " .. tostring(err))
            end
        end
    end
})

-- Auto Save Config
local function AutoSaveConfig()
    spawn(function()
        while wait(5) do -- Lưu mỗi 5 giây
            pcall(function()
                ConfigSystem.SaveConfig()
            end)
        end
    end)
end

-- Thêm event listener để lưu ngay khi thay đổi giá trị
local function setupSaveEvents()
    for _, tab in pairs({InfoTab, PlayTab, InGameTab, SettingsTab}) do
        if tab and tab._components then
            for _, element in pairs(tab._components) do
                if element and element.OnChanged then
                    element.OnChanged:Connect(function()
                        pcall(function()
                            ConfigSystem.SaveConfig()
                        end)
                    end)
                end
            end
        end
    end
end

-- Tích hợp với SaveManager
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

-- Thay đổi cách lưu cấu hình để sử dụng tên người chơi
InterfaceManager:SetFolder("HTHubAS")
SaveManager:SetFolder("HTHubAS/" .. playerName)

-- Thêm thông tin vào tab Settings
SettingsTab:AddParagraph({
    Title = "Cấu hình tự động",
    Content = "Cấu hình của bạn đang được tự động lưu theo tên nhân vật: " .. playerName
})

SettingsTab:AddParagraph({
    Title = "Phím tắt",
    Content = "Nhấn LeftControl để ẩn/hiện giao diện"
})

-- Thực thi tự động lưu cấu hình
AutoSaveConfig()

-- Thiết lập events
setupSaveEvents()

print("HT Hub | Anime Saga đã được tải thành công!")

-- Thêm section Play trong tab In-game
local InGamePlaySection = InGameTab:AddSection("Play")

-- Hàm để tìm và click vào nút Attack
local function clickAttackButton()
    local success, err = pcall(function()
        local player = game:GetService("Players").LocalPlayer
        if not player then return end
        
        local playerGui = player:FindFirstChild("PlayerGui")
        if not playerGui then return end
        
        local mobileGui = playerGui:FindFirstChild("Mobile")
        if not mobileGui then return end
        
        local attackButton = mobileGui:FindFirstChild("Attack")
        if not attackButton then return end
        
        -- Click vào nút Attack
        local events = {"MouseButton1Click", "MouseButton1Down", "Activated"}
        for _, event in ipairs(events) do
            for _, connection in pairs(getconnections(attackButton[event])) do
                connection:Fire()
            end
        end
        
        print("Đã click vào nút Attack")
    end)
    
    if not success then
        warn("Lỗi khi click Attack: " .. tostring(err))
    end
end

-- Hàm để thực hiện Skill 1
local function useSkill1()
    local success, err = pcall(function()
        local args = {
            "Skill1",
            CFrame.new(-390.00030517578125, 163.38278198242188, 1122.468994140625, -0.845065176486969, 0, -0.5346632599830627, 0, 1, 0, 0.5346632599830627, 0, -0.845065176486969),
            vector.create(-1128.170166015625, -6865.42529296875, 8184.06982421875),
            "OnSkill"
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Skill"):FireServer(unpack(args))
        print("Đã sử dụng Skill 1")
    end)
    
    if not success then
        warn("Lỗi khi sử dụng Skill 1: " .. tostring(err))
    end
end

-- Hàm để thực hiện Skill 2
local function useSkill2()
    local success, err = pcall(function()
        local args = {
            "Skill2",
            CFrame.new(-388.95867919921875, 163.37965393066406, 1124.019775390625, -0.8311628699302673, 0, -0.5560290217399597, 0, 1, 0, 0.5560290217399597, 0, -0.8311628699302673),
            vector.create(-2418.949462890625, -6208.8984375, 8547.421875),
            "EndHold"
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Skill"):FireServer(unpack(args))
        print("Đã sử dụng Skill 2")
    end)
    
    if not success then
        warn("Lỗi khi sử dụng Skill 2: " .. tostring(err))
    end
end

-- Hàm để thực hiện Skill 3
local function useSkill3()
    local success, err = pcall(function()
        local args = {
            "Skill3",
            CFrame.new(-390.00030517578125, 163.3827667236328, 1122.4691162109375, -0.8357381820678711, 0, -0.5491281747817993, 0, 1, 0, 0.5491281747817993, 0, -0.8357381820678711),
            vector.create(-1917.0269775390625, -2864.61767578125, 10521.283203125),
            "OnSkill"
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Skill"):FireServer(unpack(args))
        print("Đã sử dụng Skill 3")
    end)
    
    if not success then
        warn("Lỗi khi sử dụng Skill 3: " .. tostring(err))
    end
end

-- Toggle Auto Attack
InGamePlaySection:AddToggle("AutoAttackToggle", {
    Title = "Auto Attack",
    Default = autoAttackEnabled,
    Callback = function(Value)
        autoAttackEnabled = Value
        ConfigSystem.CurrentConfig.AutoAttack = Value
        ConfigSystem.SaveConfig()
        
        if autoAttackEnabled then
            print("Auto Attack đã được bật")
            
            -- Hủy vòng lặp cũ nếu có
            if autoAttackLoop then
                autoAttackLoop:Disconnect()
                autoAttackLoop = nil
            end
            
            -- Tạo vòng lặp mới
            spawn(function()
                while autoAttackEnabled and wait(0.1) do -- Click mỗi 0.1 giây
                    clickAttackButton()
                end
            end)
        else
            print("Auto Attack đã được tắt")
            
            -- Hủy vòng lặp nếu có
            if autoAttackLoop then
                autoAttackLoop:Disconnect()
                autoAttackLoop = nil
            end
        end
    end
})

-- Toggle Auto Skill 1
InGamePlaySection:AddToggle("AutoSkill1Toggle", {
    Title = "Auto Skill 1",
    Default = autoSkill1Enabled,
    Callback = function(Value)
        autoSkill1Enabled = Value
        ConfigSystem.CurrentConfig.AutoSkill1 = Value
        ConfigSystem.SaveConfig()
        
        if autoSkill1Enabled then
            print("Auto Skill 1 đã được bật")
            
            -- Hủy vòng lặp cũ nếu có
            if autoSkill1Loop then
                autoSkill1Loop:Disconnect()
                autoSkill1Loop = nil
            end
            
            -- Tạo vòng lặp mới
            spawn(function()
                while autoSkill1Enabled and wait(2) do -- Sử dụng mỗi 2 giây
                    useSkill1()
                end
            end)
        else
            print("Auto Skill 1 đã được tắt")
            
            -- Hủy vòng lặp nếu có
            if autoSkill1Loop then
                autoSkill1Loop:Disconnect()
                autoSkill1Loop = nil
            end
        end
    end
})

-- Toggle Auto Skill 2
InGamePlaySection:AddToggle("AutoSkill2Toggle", {
    Title = "Auto Skill 2",
    Default = autoSkill2Enabled,
    Callback = function(Value)
        autoSkill2Enabled = Value
        ConfigSystem.CurrentConfig.AutoSkill2 = Value
        ConfigSystem.SaveConfig()
        
        if autoSkill2Enabled then
            print("Auto Skill 2 đã được bật")
            
            -- Hủy vòng lặp cũ nếu có
            if autoSkill2Loop then
                autoSkill2Loop:Disconnect()
                autoSkill2Loop = nil
            end
            
            -- Tạo vòng lặp mới
            spawn(function()
                while autoSkill2Enabled and wait(5) do -- Sử dụng mỗi 5 giây
                    useSkill2()
                end
            end)
        else
            print("Auto Skill 2 đã được tắt")
            
            -- Hủy vòng lặp nếu có
            if autoSkill2Loop then
                autoSkill2Loop:Disconnect()
                autoSkill2Loop = nil
            end
        end
    end
})

-- Toggle Auto Skill 3
InGamePlaySection:AddToggle("AutoSkill3Toggle", {
    Title = "Auto Skill 3",
    Default = autoSkill3Enabled,
    Callback = function(Value)
        autoSkill3Enabled = Value
        ConfigSystem.CurrentConfig.AutoSkill3 = Value
        ConfigSystem.SaveConfig()
        
        if autoSkill3Enabled then
            print("Auto Skill 3 đã được bật")
            
            -- Hủy vòng lặp cũ nếu có
            if autoSkill3Loop then
                autoSkill3Loop:Disconnect()
                autoSkill3Loop = nil
            end
            
            -- Tạo vòng lặp mới
            spawn(function()
                while autoSkill3Enabled and wait(8) do -- Sử dụng mỗi 8 giây
                    useSkill3()
                end
            end)
        else
            print("Auto Skill 3 đã được tắt")
            
            -- Hủy vòng lặp nếu có
            if autoSkill3Loop then
                autoSkill3Loop:Disconnect()
                autoSkill3Loop = nil
            end
        end
    end
})
