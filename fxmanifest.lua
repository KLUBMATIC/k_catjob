fx_version 'cerulean'
game 'gta5'

name 'k_catjob'
author 'KLUBMATIC'
description 'Street catalytic converter theft system with XP, shop, ps-dispatch and anti-abuse.'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
}

shared_script 'config.lua'

client_scripts {
    'client/*.lua',
}

server_scripts {
    'server/*.lua',
}
