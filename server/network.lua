-- =====================================================================
--  lc_cctv - network
--  Builds a new security network for every hack: the guard's
--  workstation and the NVR (the server that records the cameras).
--  The NVR's web panel gives away its login, and its root password is
--  hidden somewhere on it. New passwords in new places every time.
--  Plain Lua without FiveM natives, so it can be tested on its own.
-- =====================================================================

local network = {}

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz'
local GUARDS = { 'guard', 'security', 'nightshift', 'jholt', 'mberg', 'tnash' }

---base64 of a text, so players can decode it with "base64 -d"
---@param data string
---@return string
function network.base64(data)
    return ((data:gsub('.', function(c)
        local bits, byte = '', c:byte()
        for i = 8, 1, -1 do bits = bits .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and '1' or '0') end
        return bits
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(bits)
        if #bits < 6 then return '' end
        local n = 0
        for i = 1, 6 do n = n + (bits:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return B64:sub(n + 1, n + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

---A random password like 'Kxq7#Lpw'
---@return string
function network.password()
    local out = {}
    for i = 1, 8 do
        local n = math.random(#LETTERS)
        out[i] = i == 4 and ('#!$%&'):sub(n % 5 + 1, n % 5 + 1) or i % 3 == 0 and tostring(math.random(0, 9)) or LETTERS:sub(n, n)
    end
    return table.concat(out)
end

local function otherPassword(password)
    local other
    repeat other = network.password() until other ~= password
    return other
end

local function pick(list)
    return list[math.random(#list)]
end

local function page(title, body)
    return ('<!DOCTYPE html>\n<html>\n<head><title>%s</title></head>\n<body>\n<h1>%s</h1>\n%s\n</body>\n</html>'):format(title, title, body)
end

---Builds the hack for one site.
---@param site { name: string, label: string }
---@param options { attempts: number, desktop?: string, subnet: number, cameras: number }
---@return table config A HackConfig for lc_hack (the target is the NVR)
function network.build(site, options)
    local net = ('10.%d.1.'):format(options.subnet)
    local guard = pick(GUARDS)
    local nvrHost = site.name .. '-nvr01'
    local login = network.password()
    local root = network.password()
    local cameras = math.max(1, options.cameras or 6)

    local workstation = {
        ip = net .. '20',
        host = site.name .. '-sec01',
        user = guard,
        desktop = options.desktop,
        attempts = options.attempts,
        target = net .. '40',
        files = {
            ['/etc/hosts'] = ('127.0.0.1\tlocalhost\n%s40\t%s'):format(net, nvrHost),
            ['~/Desktop/shift_notes.txt'] = ('%s security - night shift\n- Camera feeds are recorded on %s\n- The web panel is at http://%s/\n- Report broken cameras to IT'):format(site.label, nvrHost, nvrHost),
        },
    }

    local nvr = {
        ip = net .. '40',
        host = nvrHost,
        user = 'admin',
        password = login,
        rootPassword = root,
        ports = { 22, 80 },
        firewall = { allow = { workstation.ip }, open = { 80 } },
        processes = { '/opt/nvr/bin/nvrd --config /etc/nvr/nvr.conf', '/usr/sbin/nginx -g daemon on;' },
        files = {},
    }

    -- The camera list and recordings, so it looks like the real thing
    local cameraLines = {}
    for i = 1, cameras do
        local id = ('cam%02d'):format(i)
        cameraLines[#cameraLines + 1] = ('%s\trtsp://10.%d.2.%d/stream1\trecording'):format(id, options.subnet, 100 + i)
        nvr.files[('/srv/recordings/%s/2026-11-22.mp4'):format(id)] = '\0\0\0\24ftypisom\0\0(video)'
    end
    nvr.files['/etc/nvr/cameras.conf'] = '# id\tstream\tstate\n' .. table.concat(cameraLines, '\n')

    -- Where the NVR's web login is given away: an HTML comment, an install
    -- note the panel links to, or a note on the guard's desktop (base64)
    local loginClue = math.random(3)
    if loginClue == 1 then
        nvr.files['/var/www/html/index.html'] = page(site.label .. ' NVR', ('<form><input name="user"> <input name="pass" type="password"> <button>Log in</button></form>\n<!-- TODO remove before go-live: admin / %s -->'):format(login))
    elseif loginClue == 2 then
        nvr.files['/var/www/html/index.html'] = page(site.label .. ' NVR', '<form><input name="user"> <input name="pass" type="password"> <button>Log in</button></form>\n<p>First time here? Read the <a href="install/README.txt">install notes</a>.</p>')
        nvr.files['/var/www/html/install/README.txt'] = ('NVR install notes\n\n1. Mount the cameras\n2. Log in with the default account: admin / %s\n3. Change the password (!)'):format(login)
    else
        nvr.files['/var/www/html/index.html'] = page(site.label .. ' NVR', '<form><input name="user"> <input name="pass" type="password"> <button>Log in</button></form>\n<p>Forgot your password? Ask the security office.</p>')
        workstation.files['~/Desktop/nvr_login.txt'] = ('NVR web + ssh\nuser: admin\npass (base64): %s'):format(network.base64(login))
    end

    -- Where the NVR's root password is hidden
    local rootClue = pick({
        { '/etc/nvr/nvr.conf', ('[nvr]\nretention_days=30\nlisten=0.0.0.0:80\n\n[maintenance]\nroot_password=%s\n'):format(root) },
        { '/opt/nvr/bin/nvrd', ('\127ELF\2\1\1\0libnvr.so\0rtsp_open\0MAINT_ROOT=%s\0nvrd 3.2.1\0'):format(root) },
        { '/home/admin/.bash_history', ('cat /etc/nvr/cameras.conf\nsudo -s\n%s\nsystemctl restart nvrd\nexit'):format(root) },
    })
    nvr.files[rootClue[1]] = rootClue[2]
    -- A password that is no longer used, to cost careless players an attempt
    nvr.files['/etc/nvr/nvr.conf.bak'] = ('# old config\n[maintenance]\nroot_password=%s\n'):format(otherPassword(root))
    workstation.files['~/Documents/old_passwords.txt'] = ('NVR (before the update): admin / %s'):format(otherPassword(login))

    workstation.network = { nvr }
    return workstation
end

return network
