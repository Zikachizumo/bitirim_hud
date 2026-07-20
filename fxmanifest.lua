fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bitirim_hud'
author 'bitirim'
description 'Premium HUD (Qbox) — status / money / info / vehicle / minimap'
version '2.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/cl_hud.lua',
    'client/clock.lua'
}

server_scripts {
    'server/sv_hud.lua',
    'server/clock.lua'
}

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/icons/*.svg'
}

dependencies {
    'qbx_core',
    'ox_lib'
}
