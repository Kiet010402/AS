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

-- Biến lưu trạng thái summon
local selectedSummonAmount = ConfigSystem.CurrentConfig.SummonAmount or "x1"
local autoSummonEnabled = ConfigSystem.CurrentConfig.AutoSummon or false
local autoSummonLoop = nil
local autoSellRarities = {
    Rare = ConfigSystem.CurrentConfig.AutoSellRare or false,
    Epic = ConfigSystem.CurrentConfig.AutoSellEpic or false,
    Legendary = ConfigSystem.CurrentConfig.AutoSellLegendary or false
}

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

-- Tạo tab Shop
local ShopTab = Window:AddTab({
    Title = "Shop",
    Icon = "rbxassetid://7734056747"
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

-- Thêm section Redeem Code
local RedeemSection = SettingsTab:AddSection("Redeem Code")

-- Function để redeem tất cả code
local function redeemAllCodes()
    local codes = {"Release", "SorryForDelay", "SorryForShutdown"}
    
    for _, code in ipairs(codes) do
        local success, err = pcall(function()
            local args = {
                code
            }
            game:GetService("ReplicatedStorage"):WaitForChild("Event"):WaitForChild("Codes"):FireServer(unpack(args))
            print("Đã redeem code: " .. code)
            
            -- Đợi một chút giữa các lần redeem để tránh spam server
            wait(0.5)
        end)
        
        if not success then
            warn("Lỗi khi redeem code " .. code .. ": " .. tostring(err))
        end
    end
    
    print("Đã redeem tất cả các code!")
end

-- Nút để redeem tất cả code
RedeemSection:AddButton({
    Title = "Redeem All Codes",
    Callback = function()
        redeemAllCodes()
    end
})

-- Thêm section Summon trong tab Shop
local SummonSection = ShopTab:AddSection("Summon")

-- Hàm để thực hiện summon
local function performSummon()
    local success, err = pcall(function()
        local summonAmount = selectedSummonAmount -- Lấy trực tiếp giá trị (đã là "1" hoặc "10")
        local args = {
            tonumber(summonAmount)
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Event"):WaitForChild("Summon"):FireServer(unpack(args))
        print("Đã summon: " .. summonAmount)
    end)
    
    if not success then
        warn("Lỗi khi summon: " .. tostring(err))
    end
end

-- Hàm để mô phỏng một click chuột
local function simulateClick()
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Lấy kích thước màn hình hiện tại
    local guiInset = game:GetService("GuiService"):GetGuiInset()
    local screenSize = workspace.CurrentCamera.ViewportSize
    
    -- Tính toán vị trí trung tâm màn hình (vị trí tốt nhất để click)
    local centerX = screenSize.X / 2
    local centerY = screenSize.Y / 2
    
    -- Tạo click tại trung tâm màn hình
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
    wait(0.05) -- Độ trễ nhỏ
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
    
    -- Thử click thêm vài vị trí nếu cần thiết (4 góc màn hình)
    local testPositions = {
        {X = centerX, Y = centerY}, -- Trung tâm
        {X = centerX * 0.9, Y = centerY * 1.5}, -- Phía dưới 
        {X = centerX * 1.5, Y = centerY * 0.9}, -- Phía phải
        {X = centerX * 0.5, Y = centerY * 0.5}  -- Phía trên bên trái
    }
    
    for _, pos in ipairs(testPositions) do
        if pos.X > 0 and pos.X < screenSize.X and pos.Y > 0 and pos.Y < screenSize.Y then
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
            wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
            wait(0.05)
        end
    end
    
    print("Đã thực hiện click tự động trên màn hình " .. screenSize.X .. "x" .. screenSize.Y)
end

-- Hàm để cập nhật trạng thái Auto Sell
local function updateAutoSell(rarity, enabled)
    local success, err = pcall(function()
        local args = {
            "AutoSell",
            rarity
        }
        
        if enabled then
            game:GetService("ReplicatedStorage"):WaitForChild("Event"):WaitForChild("Setting"):FireServer(unpack(args))
            print("Đã bật Auto Sell cho " .. rarity)
        else
            -- Nếu tắt, cũng gửi event tương tự để toggle
            game:GetService("ReplicatedStorage"):WaitForChild("Event"):WaitForChild("Setting"):FireServer(unpack(args))
            print("Đã tắt Auto Sell cho " .. rarity)
        end
    end)
    
    if not success then
        warn("Lỗi khi cập nhật Auto Sell: " .. tostring(err))
    end
end

-- Dropdown để chọn số lượng summon
SummonSection:AddDropdown("SummonAmountDropdown", {
    Title = "Summon",
    Values = {"1", "10"},
    Multi = false,
    Default = selectedSummonAmount,
    Callback = function(Value)
        selectedSummonAmount = Value
        ConfigSystem.CurrentConfig.SummonAmount = Value
        ConfigSystem.SaveConfig()
        print("Đã chọn summon amount: " .. Value)
    end
})

-- Dropdown cho Auto Sell
SummonSection:AddDropdown("AutoSellDropdown", {
    Title = "Auto Sell",
    Values = {"Rare", "Epic", "Legendary"},
    Multi = true,
    Default = autoSellRarities,
    Callback = function(Values)
        -- Kiểm tra các giá trị đã thay đổi
        for rarity, newValue in pairs(Values) do
            if autoSellRarities[rarity] ~= newValue then
                autoSellRarities[rarity] = newValue
                updateAutoSell(rarity, newValue)
            end
        end
        
        -- Cập nhật cấu hình
        ConfigSystem.CurrentConfig.AutoSellRare = autoSellRarities.Rare
        ConfigSystem.CurrentConfig.AutoSellEpic = autoSellRarities.Epic
        ConfigSystem.CurrentConfig.AutoSellLegendary = autoSellRarities.Legendary
        ConfigSystem.SaveConfig()
        
        -- Hiển thị thông báo
        local selectedTypes = {}
        if autoSellRarities.Rare then table.insert(selectedTypes, "Rare") end
        if autoSellRarities.Epic then table.insert(selectedTypes, "Epic") end
        if autoSellRarities.Legendary then table.insert(selectedTypes, "Legendary") end
        
        if #selectedTypes > 0 then
            print("Đã bật Auto Sell cho: " .. table.concat(selectedTypes, ", "))
        else
            print("Đã tắt Auto Sell")
        end
    end
})

-- Nút Summon ngay lập tức
SummonSection:AddButton({
    Title = "Summon Now",
    Callback = function()
        performSummon()
    end
})

-- Toggle Auto Summon
SummonSection:AddToggle("AutoSummonToggle", {
    Title = "Auto Summon",
    Default = autoSummonEnabled,
    Callback = function(Value)
        autoSummonEnabled = Value
        ConfigSystem.CurrentConfig.AutoSummon = Value
        ConfigSystem.SaveConfig()
        
        if autoSummonEnabled then
            print("Auto Summon đã được bật")
            
            -- Hủy vòng lặp cũ nếu có
            if autoSummonLoop then
                autoSummonLoop:Disconnect()
                autoSummonLoop = nil
            end
            
            -- Tạo vòng lặp mới
            spawn(function()
                while autoSummonEnabled do
                    -- Thực hiện summon
                    performSummon()
                    
                    -- Đợi 1 giây
                    wait(1)
                    
                    -- Xác định số lần click dựa trên loại summon
                    local clickCount = selectedSummonAmount == "1" and 2 or 11
                    print("Đang thực hiện " .. clickCount .. " lần click cho summon " .. selectedSummonAmount)
                    
                    -- Thực hiện click theo số lần đã xác định
                    for i = 1, clickCount do
                        if not autoSummonEnabled then break end
                        simulateClick()
                        wait(0.2) -- Đợi 0.2 giây giữa các lần click
                    end
                    
                    -- Đợi thêm 1 giây trước khi thực hiện summon tiếp theo
                    wait(1)
                end
            end)
        else
            print("Auto Summon đã được tắt")
            
            -- Hủy vòng lặp nếu có
            if autoSummonLoop then
                autoSummonLoop:Disconnect()
                autoSummonLoop = nil
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
    for _, tab in pairs({InfoTab, PlayTab, ShopTab, SettingsTab}) do
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
