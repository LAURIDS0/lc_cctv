-- =====================================================================
--  lc_cctv - server
--  Every site is an lc_hack terminal with a security network behind it.
--  The player breaks into the NVR, finds the cameras and views them with
--  "view <ip>": every camera opens in its own window on the desktop.
--  The live view itself is part of lc_hack (camera machines).
-- =====================================================================

local config = require 'config'
local network = require 'server.network'

local function hasItem(source)
    if not config.item or GetResourceState('ox_inventory') ~= 'started' then return true end
    return (exports.ox_inventory:Search(source, 'count', config.item) or 0) > 0
end

---Creates (or replaces) the terminal of a site, with a new network
local function createSite(site)
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
            desktop = site.desktop == nil and config.desktop or site.desktop or 'ubuntu', -- Cameras need a desktop
            subnet = 20 + subnet,
        }),
        canUse = function(source)
            if not hasItem(source) then return false, 'You are missing something to do this.' end
            return true
        end,
    })
end

local function createAll()
    for _, site in ipairs(config.sites or {}) do
        if type(site.name) == 'string' and site.coords and site.cameras then createSite(site)
        else print('^3[lc_cctv] a site needs a name, coords and cameras^0') end
    end
end

CreateThread(function()
    createAll()
    -- New networks and passwords now and then, so players can't reuse old ones
    while config.refresh and config.refresh > 0 do
        Wait(config.refresh * 1000)
        createAll()
    end
end)

-- Terminals live in lc_hack: create them again when it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'lc_hack' then createAll() end
end)

-- A test site where the admin stands, with four cameras looking at it from around
if config.testCommand then
    lib.addCommand(config.testCommand.name, {
        help = 'Create an lc_cctv test site at your position',
        restricted = config.testCommand.restricted or nil,
    }, function(source)
        local c = GetEntityCoords(GetPlayerPed(source))
        local cameras = {}
        for i, angle in ipairs({ 0, 90, 180, 270 }) do
            local rad = math.rad(angle)
            -- 8 m away and 4 m up, looking back at the spot
            cameras[i] = {
                label = ('Test %d'):format(i),
                coords = vector3(c.x - math.sin(rad) * 8.0, c.y + math.cos(rad) * 8.0, c.z + 4.0),
                rotation = vector3(-25.0, 0.0, angle + 180.0),
                fov = 60.0,
            }
        end
        createSite({ name = 'testsite', label = 'Test Site', coords = c, cameras = cameras })
        TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = 'Test site created where you stand.' })
    end)
end
