-- =====================================================================
--  lc_cctv - config
--  Only loaded on the server.
-- =====================================================================

return {
    -- ox_inventory: an item needed to use a security computer. false = none.
    item = false,

    -- Wrong passwords allowed per hack
    attempts = 3,

    -- Desktop of the guard's computer: 'ubuntu', 'kali', 'macos', 'chromeos', 'mint', 'fedora'
    -- or 'random'. The camera windows need a desktop. A site can set its own.
    desktop = 'random',

    -- Seconds between new networks and passwords for every site. Hacks paused at a
    -- terminal are lost when it happens. false = never (only on restart).
    refresh = 3600,

    -- Admin command that creates a test site where you stand, with four cameras. false = no command.
    testCommand = { name = 'cctvtest', restricted = 'group.admin' },

    -- The security rooms. Every site is a computer in the world (an lc_hack terminal).
    --   name      unique, lowercase: used in hostnames, e.g. 'bank-nvr01'
    --   label     the building's name
    --   coords    where the guard's computer is
    --   cameras   the cameras: { label, coords, rotation, fov }
    --             rotation = vec3(pitch, roll, heading): pitch below 0 looks down
    --   desktop?, radius?, screen?  see the documentation
    sites = {
        -- {
        --     name = 'bank',
        --     label = 'Pacific Standard',
        --     coords = vec3(264.5, 219.8, 101.7),
        --     cameras = {
        --         { label = 'Lobby', coords = vec3(240.2, 213.5, 110.5), rotation = vec3(-20.0, 0.0, 250.0), fov = 70.0 },
        --         { label = 'Vault', coords = vec3(255.1, 228.6, 103.9), rotation = vec3(-30.0, 0.0, 160.0), fov = 60.0 },
        --     },
        -- },
    },
}
