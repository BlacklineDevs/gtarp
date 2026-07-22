fx_version 'cerulean'
game 'gta5'

name 'palm6_threads'
description 'PALM6 Threads - player custom clothing (Phase 0 spike)'
author 'MGT'
version '0.0.1'

shared_script 'shared/config.lua'
client_script 'client/debug.lua'

-- Addon-clothing metadata. FILL THIS with the base-template's actual .meta filename(s)
-- once the known-good pack is dropped into meta/ (Stage A). The freemode component ymt
-- for a male torso is usually mp_m_freemode_01.meta; female is mp_f_freemode_01.meta.
data_file 'SHOP_PED_APPAREL_META_FILE' 'meta/mp_m_freemode_01.meta'

files {
    'meta/*.meta',
    'meta/*.ymt',
}

-- NOTE: the stream/ folder auto-mounts loose .ydd/.ytd assets; no manifest entry needed.
-- Streaming addon clothing beyond ~9 slots requires a Cfx Element Club Argentum key
-- (verify PALM6's current tier before enabling on prod).
