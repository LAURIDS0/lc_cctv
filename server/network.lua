-- =====================================================================
--  lc_cctv - network
--  Builds a new security network for every hack:
--    the guard's workstation  ->  the NVR (records the cameras)  ->  the cameras
--  The NVR's web panel gives its login away. Its camera list (with the
--  cameras' IPs and passwords) is root only, and its root password is
--  hidden on it. The cameras are on their own network, which only the
--  NVR can reach, so the player views them from the NVR ("view <ip>").
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

---A vector (vector3 or table) as a plain table, so it can be sent to the NUI
local function vec(v, default)
    v = v or default or {}
    return { x = tonumber(v.x) or 0.0, y = tonumber(v.y) or 0.0, z = tonumber(v.z) or 0.0 }
end

local function page(title, body)
    return ('<!DOCTYPE html>\n<html>\n<head><title>%s</title></head>\n<body>\n<h1>%s</h1>\n%s\n</body>\n</html>'):format(title, title, body)
end

---Builds the hack for one site.
---@param site { name: string, label: string, cameras: table[] }
---@param options { attempts: number, desktop?: string, subnet: number }
---@return table config A HackConfig for lc_hack (no target: the player views cameras until they close it)
function network.build(site, options)
    local office = ('10.%d.1.'):format(options.subnet)
    local camNet = ('10.%d.2.'):format(options.subnet)
    local nvrHost = site.name .. '-nvr01'
    local login = network.password()
    local root = network.password()

    local workstation = {
        ip = office .. '20',
        host = site.name .. '-sec01',
        user = pick(GUARDS),
        desktop = options.desktop,
        attempts = options.attempts,
        target = false,
        files = {
            ['/etc/hosts'] = ('127.0.0.1\tlocalhost\n%s40\t%s'):format(office, nvrHost),
            ['~/Desktop/shift_notes.txt'] = ('%s security - night shift\n- The cameras are recorded on %s\n- The web panel is at http://%s/\n- Report broken cameras to IT'):format(site.label, nvrHost, nvrHost),
        },
    }

    -- The NVR sits on the office network and on the camera network
    local nvr = {
        ip = { office .. '40', camNet .. '1' },
        host = nvrHost,
        user = 'admin',
        password = login,
        rootPassword = root,
        ports = { 22, 80 },
        firewall = { allow = { workstation.ip }, open = { 80 } },
        processes = { '/opt/nvr/bin/nvrd --config /etc/nvr/nvr.conf', '/usr/sbin/nginx -g daemon on;' },
        locked = { '/etc/nvr/cameras.conf' },
        files = {},
    }

    -- The cameras: machines on the camera network, only the NVR may connect
    local machines, lines = { nvr }, {}
    for i, cam in ipairs(site.cameras or {}) do
        local ip = camNet .. (100 + i)
        local password = network.password()
        local id = ('cam%02d'):format(i)
        machines[#machines + 1] = {
            ip = ip,
            host = ('%s-%s'):format(site.name, id),
            user = 'admin',
            password = password,
            ports = { 80, 554 },
            firewall = { allow = { camNet .. '1' } },
            camera = { coords = vec(cam.coords), rotation = vec(cam.rotation, { x = -15.0 }), fov = tonumber(cam.fov) or 60.0 },
            files = { ['/etc/camera.conf'] = ('[camera]\nname=%s\nstream=rtsp://0.0.0.0:554/stream1'):format(cam.label or id) },
        }
        lines[#lines + 1] = ('%s\t%-16s rtsp://admin:%s@%s:554/stream1'):format(id, cam.label or id, password, ip)
        nvr.files[('/srv/recordings/%s/2026-11-22.mp4'):format(id)] = '\0\0\0\24ftypisom\0\0(video)'
    end
    nvr.files['/etc/nvr/cameras.conf'] = '# id\tname\t\t stream\n' .. table.concat(lines, '\n')
    nvr.files['/opt/nvr/README'] = 'The camera list is in /etc/nvr/cameras.conf (root only). View a camera with: view <ip>'

    -- Where the NVR's web login is given away
    local loginClue = math.random(3)
    local form = '<form><input name="user"> <input name="pass" type="password"> <button>Log in</button></form>'
    if loginClue == 1 then
        nvr.files['/var/www/html/index.html'] = page(site.label .. ' NVR', ('%s\n<!-- TODO remove before go-live: admin / %s -->'):format(form, login))
    elseif loginClue == 2 then
        nvr.files['/var/www/html/index.html'] = page(site.label .. ' NVR', form .. '\n<p>First time here? Read the <a href="install/README.txt">install notes</a>.</p>')
        nvr.files['/var/www/html/install/README.txt'] = ('NVR install notes\n\n1. Mount the cameras\n2. Log in with the default account: admin / %s\n3. Change the password (!)'):format(login)
    else
        nvr.files['/var/www/html/index.html'] = page(site.label .. ' NVR', form .. '\n<p>Forgot your password? Ask the security office.</p>')
        workstation.files['~/Desktop/nvr_login.txt'] = ('NVR web + ssh\nuser: admin\npass (base64): %s'):format(network.base64(login))
    end

    -- Where the NVR's root password is hidden
    local rootClue = pick({
        { '/etc/nvr/nvr.conf', ('[nvr]\nretention_days=30\nlisten=0.0.0.0:80\n\n[maintenance]\nroot_password=%s\n'):format(root) },
        { '/opt/nvr/bin/nvrd', ('\127ELF\2\1\1\0libnvr.so\0rtsp_open\0MAINT_ROOT=%s\0nvrd 3.2.1\0'):format(root) },
        { '/home/admin/.bash_history', ('ls /srv/recordings\nsudo -s\n%s\ncat /etc/nvr/cameras.conf\nexit'):format(root) },
    })
    nvr.files[rootClue[1]] = rootClue[2]
    nvr.files['/etc/nvr/nvr.conf.bak'] = ('# old config\n[maintenance]\nroot_password=%s\n'):format(otherPassword(root))
    workstation.files['~/Documents/old_passwords.txt'] = ('NVR (before the update): admin / %s'):format(otherPassword(login))

    workstation.network = machines
    return workstation
end

return network
