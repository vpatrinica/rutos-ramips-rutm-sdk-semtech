local BasicService = require("api/BasicService")
local fs = require("nixio.fs")
local uci = require("vuci.uci")

local BasicStation = BasicService:new("basicstation")

-- Allow file uploads: skip the service_group validation that rejects
-- paths not in service_groups_enum (which only has "config" and "actions").
BasicStation.disable_upload_service_group_check = true

function BasicStation:UPLOAD_validate_path()
    -- Accept any upload path; UPLOAD_init handles validation
    return true
end

local function log(msg)
    if msg:sub(1,1) == "-" then msg = " " .. msg end
    os.execute(string.format("logger -t BASICSTATION '%s'", msg:gsub("'", "'\\''")))
end

log("BASICSTATION SERVICE LOADED v14")

-- Helper: Get all UCI configuration as an array of sections
function BasicStation:get_all_config()
    local cursor = uci.cursor()
    local data = {}
    cursor:foreach("basicstation", nil, function(s)
        s[".name"] = s[".name"]
        s["id"] = s[".name"]
        table.insert(data, s)
    end)
    return data
end

-- Helper: Get sections by type
function BasicStation:get_sections_by_type(stype)
    local cursor = uci.cursor()
    local data = {}
    cursor:foreach("basicstation", stype, function(s)
        s[".name"] = s[".name"]
        s["id"] = s[".name"]
        table.insert(data, s)
    end)
    return data
end

-- GET_TYPE_config: handles /api/basicstation/config[/:sid]
-- NOTE: BasicService dispatches via GET_TYPE_%s pattern (not GET_%s)
function BasicStation:GET_TYPE_config(sid)
    if type(sid) == "table" then sid = sid.sid end
    log("GET_TYPE_config: " .. tostring(sid or "all"))
    if not sid or sid == "" then
        return self:ResponseOK(self:get_all_config())
    end

    local cursor = uci.cursor()
    local section = cursor:get_all("basicstation", sid)
    if not section then
        return self:ResponseNotFound({ error = "Section not found", source = "UCI", section = sid })
    end
    section[".name"] = sid
    section["id"] = sid
    return self:ResponseOK(section)
end

-- Action-based save to bypass potential PUT restrictions in BasicService bytecode
function BasicStation:POST_action_save_config(data)
    log("Action save_config called")
    
    -- VUCI Action data can be in data or data.data depending on axios config
    local group = data.service_group or (data.data and data.data.service_group)
    local sid = data.sid or (data.data and data.data.sid)
    local payload = data.data and data.data.data or data.data or data
    
    if not group or type(payload) ~= "table" then
        log("Invalid action payload: group=" .. tostring(group))
        return self:Response(400, { success = false, error = "Missing group or data payload" })
    end
    
    return self:handle_uci_save(group, sid, payload)
end

function BasicStation:handle_uci_save(group, sid, data)
    local u = uci.cursor()
    local config = "basicstation"
    local section_name = sid
    local section_type = (group ~= "config") and group or nil

    log(string.format("Saving UCI: group=%s, sid=%s", tostring(group), tostring(sid)))

    if not section_name or section_name == "" then
        if section_type then
            section_name = u:add(config, section_type)
        else
            return self:Response(400, { success = false, error = "Section SID required" })
        end
    end

    local exists = u:get_all(config, section_name)
    if not exists then
        if section_type then
            u:section(config, section_type, section_name)
        else
            return self:Response(404, { success = false, error = "Section not found: " .. tostring(section_name) })
        end
    end

    for k, v in pairs(data) do
        if type(k) == "string" and k:sub(1,1) ~= "." and k ~= "id" then
            if type(v) == "table" then
                u:set_list(config, section_name, k, v)
            elseif type(v) == "boolean" then
                u:set(config, section_name, k, v and "1" or "0")
            else
                u:set(config, section_name, k, tostring(v))
            end
        end
    end

    if u:commit(config) then
        log("UCI commit successful for " .. tostring(section_name))
        return self:ResponseOK({ success = true, data = { sid = section_name } })
    end

    log("UCI commit failed for " .. config)
    return self:Response(500, { success = false, error = "UCI commit failed" })
end

-- Low-level PUT override to fix 500 Internal Server Errors from the framework
function BasicStation:PUT(params, data)
    log("BasicStation:PUT called (low-level)")
    log("PUT params: " .. tostring(params))
    log("PUT data: " .. tostring(data))
    local group = "config"
    local sid = nil
    
    if type(params) == "table" then
        group = params.service_group or group
        sid = params.sid
    end

    log(string.format("PUT params: group=%s, sid=%s", tostring(group), tostring(sid)))

    local payload = data
    if type(data) == "table" and data.data then
        payload = data.data
    end
    
    if payload == nil or (type(payload) == "table" and not next(payload)) then
        log("PUT Payload is empty or nil, ignoring gracefully")
        return self:ResponseOK({ success = true, ignored = true })
    end

    if type(payload) == "table" then
        local keys = {}
        for k in pairs(payload) do table.insert(keys, k) end
        log("PUT payload: table with keys: " .. table.concat(keys, ", "))
    elseif type(payload) == "string" then
        log("PUT payload is string, attempting JSON decode: " .. payload:sub(1, 200))
        local ok, decoded = pcall(function()
            local json = require("cjson")
            return json.decode(payload)
        end)
        if ok and type(decoded) == "table" then
            payload = decoded
            local keys = {}
            for k in pairs(payload) do table.insert(keys, k) end
            log("PUT JSON decoded, keys: " .. table.concat(keys, ", "))
        else
            log("PUT Error: Failed to decode JSON string")
            return self:Response(400, { success = false, error = "Invalid data payload: not a table or valid JSON" })
        end
    else
        log("PUT Error: Payload is an unsupported type")
        return self:Response(400, { success = false, error = "Invalid data payload type" })
    end

    return self:handle_uci_save(group, sid, payload)
end

function BasicStation:POST(params, data)
    log("BasicStation:POST called")
    
    if type(params) == "table" and params.service_group == "actions" then
        local action = params.sid
        log("Action detected: " .. tostring(action))
        if action == "save_config" then
            return self:POST_action_save_config(data)
        end
    end

    return self:PUT(params, data)
end

function BasicStation:DELETE(params)
    local sid = params and params.sid
    log("BasicStation:DELETE called for sid: " .. tostring(sid))
    
    if not sid or sid == "" then
        return self:Response(400, { success = false, error = "Section ID is required" })
    end

    local u = uci.cursor()
    if u:delete("basicstation", sid) and u:commit("basicstation") then
        return self:ResponseOK({ success = true })
    end
    
    return self:Response(500, { success = false, error = "Failed to delete section" })
end

-- GET_TYPE_rfconf: handles /api/basicstation/config/rfconf
function BasicStation:GET_TYPE_rfconf()
    log("GET_TYPE_rfconf")
    return self:ResponseOK(self:get_sections_by_type("rfconf"))
end

-- GET_TYPE_rssitcomp: handles /api/basicstation/config/rssitcomp
function BasicStation:GET_TYPE_rssitcomp()
    log("GET_TYPE_rssitcomp")
    return self:ResponseOK(self:get_sections_by_type("rssitcomp"))
end

-- GET_TYPE_txlut: handles /api/basicstation/txlut
function BasicStation:GET_TYPE_txlut()
    log("GET_TYPE_txlut")
    return self:ResponseOK(self:get_sections_by_type("txlut"))
end

-- GET_TYPE_log: handles /api/basicstation/log
function BasicStation:GET_TYPE_log()
    log("GET_TYPE_log called")
    local log_path = "/tmp/basicstation/log"
    local content = ""

    local f = io.open(log_path, "r")
    if f then
        content = f:read("*all") or ""
        f:close()
    end

    return self:ResponseOK({ log = content })
end

-- GET_TYPE_clear_log: handles GET /api/basicstation/clear_log
function BasicStation:GET_TYPE_clear_log()
    log("GET_TYPE_clear_log called")
    local log_path = "/tmp/basicstation/log"
    os.execute(": > " .. log_path .. " 2>/dev/null")
    return self:ResponseOK({ cleared = true })
end

-- GET_TYPE_status: handles /api/basicstation/status
function BasicStation:GET_TYPE_status()
    log("GET_TYPE_status called")
    local running = os.execute("pgrep -f 'station' >/dev/null 2>&1") == 0
    return self:ResponseOK({ running = running })
end

-- UPLOAD support
function BasicStation:UPLOAD_init()
    local CERT_FILES = {
        trust = { path = "/etc/basicstation/tc.trust" },
        key   = { path = "/etc/basicstation/tc.key" },
        crt   = { path = "/etc/basicstation/tc.crt" }
    }

    local function handle_request(upload_request)
        if not upload_request or not upload_request.files or #upload_request.files == 0 then
            return false, { code = 5, error = "No files uploaded" }
        end

        if not fs.access("/etc/basicstation") then
            os.execute("mkdir -p /etc/basicstation && chmod 755 /etc/basicstation")
        end

        local file = upload_request.files[1]
        local cert_type = upload_request.parameters and upload_request.parameters.option

        if not cert_type and upload_request.parameters then
            cert_type = upload_request.parameters.cert_type
        end

        if not cert_type then
            local fname = (file.filename or ""):lower()
            if fname:match("key") then cert_type = "key"
            elseif fname:match("crt") then cert_type = "crt"
            else cert_type = "trust" end
        end

        local cert_info = CERT_FILES[cert_type]
        if not cert_info then
            return false, { code = 5, error = "Invalid certificate type: " .. tostring(cert_type) }
        end

        if fs.access(cert_info.path) then
            fs.remove(cert_info.path)
        end

        file.location = cert_info.path
        file.cert_type = cert_type
        return true
    end

    return { handle_request = handle_request }
end

function BasicStation:UPLOAD_after_upload_hook(upload_request)
    local file = upload_request.files[1]
    local cert_type = file.cert_type

    local cursor = uci.cursor()
    cursor:set("basicstation", "auth", cert_type, file.location)
    cursor:commit("basicstation")

    if cert_type == "key" then
        os.execute("chmod 0600 " .. file.location)
    else
        os.execute("chmod 0644 " .. file.location)
    end

    return { path = file.location, type = cert_type }
end

return BasicStation
