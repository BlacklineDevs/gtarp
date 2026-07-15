fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ModernGrindTech'
version '0.1.0'
description 'palm6 pulse — live city director: population-aware Pulse Windows + modifier bus'

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/sv_framework.lua',   -- framework adapter — loads before server logic
    'server/main.lua',
}

-- palm6_gangs / palm6_market / palm6_mdt / palm6_eventguard / palm6_discord are
-- SOFT deps (every sibling call is pcall-wrapped) — pulse boots + runs inert-safe
-- if any are absent, so they are deliberately NOT listed here.
dependencies { 'ox_lib', 'oxmysql', 'qbx_core' }
