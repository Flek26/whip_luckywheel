fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'whip_luckywheel'
description 'The casino\'s Lucky Wheel on whip: GTA\'s own wheel and moves, one spin a day, prizes paid through whip, a car on the podium.'
version '0.1.0'
author 'Flek'

shared_script '@whip_core/lib/satellite.lua'
shared_script 'config.lua'
client_scripts {
    'client/main.lua',
}
server_scripts {
    'server/main.lua',
}

dependency 'whip_core'
whip_requires '1.0'
