-- =====================================================================
--  lc_cctv - server
--  Every site is an lc_hack terminal with a security network behind it.
--  Root on the NVR turns the cameras in the site's area off for a while.
--  Other resources find out with the exports, the events and
--  GlobalState.lc_cctv (also readable on clients).
-- =====================================================================

local config = require 'config'
local network = require 'server.network'

local offline = {} -- site name -> os.time() when it can be hacked again
local blind = {}   -- site name -> { site, label, coords, radius, untilTime }

local function inventoryStarted()
    return GetResourceState('ox_inventory') == 'started'
end

local function hasItem(source)
    if not config.item or not inventoryStarted() then return true end
    return (exports.ox_inventory:Search(source, 'count', config.item) or 0) > 0
end

local function safeCall(fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then print(('^1[lc_cctv] error in callback: %s^0'):format(err)) end
end

-- ---------- Blind areas ----------

---Shares the blind areas with every client (GlobalState.lc_cctv)
local function publish()
    local list = {}
    for _, area in pairs(blind) do list[#list + 1] = area end
    GlobalState.lc_cctv = list
end

---Turns the cameras of a site back on
local function restore(name)
    if not blind[name] then return end
    blind[name] = nil
    publish()
    TriggerEvent('lc_cctv:restored', name)
    TriggerClientEvent('lc_cctv:restored', -1, name)
    safeCall(config.onRestored, name)
end

---Turns the cameras of a site off
---@param site table
---@param duration number seconds
---@param source? number the player who did it
local function disable(site, duration, source)
    local area = site.area or { coords = site.coords, radius = 50.0 }
    local untilTime = os.time() + duration
    blind[site.name] = {
        site = site.name,
        label = site.label,
        coords = { x = area.coords.x, y = area.coords.y, z = area.coords.z },
        radius = area.radius or 50.0,
        untilTime = untilTime,
    }
    publish()
    TriggerEvent('lc_cctv:disabled', site.name, duration, source)
    TriggerClientEvent('lc_cctv:disabled', -1, site.name, duration)
    safeCall(config.onDisabled, source, site.name, duration)

    SetTimeout(duration * 1000, function()
        -- Unless it was turned off again meanwhile
        if blind[site.name] and blind[site.name].untilTime <= os.time() then restore(site.name) end
    end)
end

---Is a position inside an area whose cameras are off?
---@param coords vector3
---@return boolean blind, string? site
local function isAreaBlind(coords)
    for name, area in pairs(blind) do
        local dx, dy, dz = coords.x - area.coords.x, coords.y - area.coords.y, coords.z - area.coords.z
        if math.sqrt(dx * dx + dy * dy + dz * dz) <= area.radius then return true, name end
    end
    return false
end

exports('isAreaBlind', isAreaBlind)
exports('getBlindAreas', function() return GlobalState.lc_cctv or {} end)

-- ---------- Sites ----------

local sites = {}

local createSite
createSite = function(site)
    sites[site.name] = site
    local subnet = 20
    for c in site.name:gmatch('.') do subnet = (subnet * 31 + c:byte()) % 200 end

    exports.lc_hack:createTerminal({
        name = 'lc_cctv:' .. site.name,
        coords = site.coords,
        label = ('Use %s security computer'):format(site.label),
        radius = site.radius,
        screen = site.screen,
        config = network.build(site, {
            attempts = config.attempts,
            desktop = site.desktop == nil and config.desktop or site.desktop or nil,
            subnet = 20 + subnet,
            cameras = site.cameras or 6,
        }),
        canUse = function(source)
            if blind[site.name] then return false, 'The cameras are already off.' end
            if (offline[site.name] or 0) > os.time() then return false, 'The security system is locked. Try again later.' end
            if not hasItem(source) then return false, 'You are missing something to do this.' end
            return true
        end,
        onSuccess = function(source)
            offline[site.name] = os.time() + (site.cooldown or config.cooldown)
            disable(site, site.duration or config.duration, source)
            TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = ('%s cameras are off'):format(site.label) })
            createSite(site) -- New network and passwords for the next one
        end,
    })
end

---Turns a site's cameras off from another resource, e.g. after a power cut
---@param name string
---@param duration? number seconds
---@return boolean done false if the site doesn't exist
exports('disableCameras', function(name, duration)
    local site = sites[name]
    if not site then return false end
    disable(site, duration or site.duration or config.duration)
    return true
end)

---Turns a site's cameras back on
exports('restoreCameras', restore)

local function createAll()
    for _, site in ipairs(config.sites or {}) do
        if type(site.name) == 'string' and site.coords then createSite(site)
        else print('^3[lc_cctv] a site needs a name and coords^0') end
    end
end

CreateThread(function()
    publish()
    createAll()
end)

-- Terminals live in lc_hack: create them again when it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'lc_hack' then createAll() end
end)

-- A test site where the admin stands
if config.testCommand then
    lib.addCommand(config.testCommand.name, {
        help = 'Create an lc_cctv test site at your position',
        restricted = config.testCommand.restricted or nil,
    }, function(source)
        local coords = GetEntityCoords(GetPlayerPed(source))
        createSite({ name = 'testsite', label = 'Test Site', coords = coords, area = { coords = coords, radius = 50.0 }, duration = 60 })
        TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = 'Test site created where you stand.' })
    end)
end
