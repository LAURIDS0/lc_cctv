-- =====================================================================
--  lc_cctv - client
--  Lets client scripts ask if a position is in an area whose cameras
--  are off. The server keeps the list in GlobalState.lc_cctv.
-- =====================================================================

---Is a position inside an area whose cameras are off?
---@param coords? vector3 Defaults to the player's position
---@return boolean blind, string? site
local function isBlind(coords)
    coords = coords or GetEntityCoords(cache.ped)
    for _, area in ipairs(GlobalState.lc_cctv or {}) do
        if #(coords - vector3(area.coords.x, area.coords.y, area.coords.z)) <= area.radius then return true, area.site end
    end
    return false
end

exports('isBlind', isBlind)
