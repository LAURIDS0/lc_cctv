-- FX Information
fx_version 'cerulean'
lua54 'yes'
game 'gta5'

-- Resource Information
name 'lc_cctv'
author 'LC Development'
version '1.0.0'
repository 'https://github.com/LAURIDS0/lc_cctv'
description 'Hack security rooms and turn the cameras off for a while, built on lc_hack'

-- Manifest
shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'lc_hack',
}
