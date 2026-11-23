-- =====================================================================
--  lc_cctv - config
--  Only loaded on the server.
-- =====================================================================

return {
    -- ox_inventory: an item needed to use a security computer. false = none.
    item = false,

    -- Wrong passwords allowed per hack
    attempts = 3,

    -- Desktop of the guard's computer: 'ubuntu', 'kali', 'macos', 'chromeos', 'mint', 'fedora',
    -- 'random' or false for a terminal only. A site can set its own.
    desktop = 'random',

    -- Seconds the cameras stay off. A site can set its own.
    duration = 300,

    -- Seconds before a site can be hacked again (counted from the hack). A site can set its own.
    cooldown = 1800,

    -- Admin command that creates a test site where you stand. false = no command.
    testCommand = { name = 'cctvtest', restricted = 'group.admin' },

    -- The security rooms. Every site is a computer in the world (an lc_hack terminal).
    --   name     unique, lowercase: used in hostnames, e.g. 'bank-nvr01'
    --   label    the building's name
    --   coords   where the guard's computer is
    --   area     the area its cameras cover: { coords = vec3(...), radius = 60.0 }
    --   cameras?, duration?, cooldown?, desktop?, radius?, screen?  see the documentation
    sites = {
        -- {
        --     name = 'bank',
        --     label = 'Pacific Standard',
        --     coords = vec3(264.5, 219.8, 101.7),
        --     area = { coords = vec3(255.0, 225.0, 101.0), radius = 60.0 },
        -- },
    },

    -- Called on the server when cameras go off and come back on. Tell your dispatch,
    -- camera or police scripts here.
    ---@param source number The player who hacked it
    ---@param site string The site's name
    ---@param duration number Seconds
    onDisabled = function(source, site, duration)
    end,

    ---@param site string
    onRestored = function(site)
    end,
}
