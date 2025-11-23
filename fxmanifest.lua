fx_version 'cerulean'
game 'gta5'

author 'KLUBMATIC'
description 'Catalytic Converter Scrapper Job'
version '1.5.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    'data/vehicles.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@qb-core/server/export.lua',
    'server/main.lua',
}
