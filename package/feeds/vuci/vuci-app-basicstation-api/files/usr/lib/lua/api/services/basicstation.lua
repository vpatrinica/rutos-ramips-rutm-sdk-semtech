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

log("BASICSTATION SERVICE LOADED v20")

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
    log("Action save_config raw data keys: " .. (function()
        if type(data) ~= "table" then return tostring(data) end
        local keys = {} for k in pairs(data) do table.insert(keys, tostring(k)) end
        return table.concat(keys, ", ")
    end)())

    -- Accept both frontend format (section/data) and framework format (service_group/sid)
    local group = data.section or data.service_group
                  or (data.data and (data.data.section or data.data.service_group))
    local sid   = data.sid or (data.data and data.data.sid)
    local payload = data.data or data

    -- If group came from 'section' field (named sections like station/auth/sx130x),
    -- treat it as both the group and the sid
    if group and not sid then
        sid = group
    end

    -- For named sections (station, auth, sx130x), group is "config"
    local named_sections = { station = true, auth = true, sx130x = true }
    local effective_group = named_sections[group] and "config" or (group or "config")

    log(string.format("Action save_config: group=%s, effective_group=%s, sid=%s",
        tostring(group), tostring(effective_group), tostring(sid)))

    if type(payload) ~= "table" then
        log("Invalid action payload: payload is not a table")
        return self:Response(400, { success = false, error = "Missing data payload" })
    end

    -- Remove wrapper keys that aren't UCI options
    payload.section = nil
    payload.service_group = nil
    payload.sid = nil

    return self:handle_uci_save(effective_group, sid, payload)
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
            local ok, err = pcall(function()
                if type(v) == "table" then
                    -- UCI set() accepts tables for list-type options
                    u:set(config, section_name, k, v)
                elseif type(v) == "boolean" then
                    u:set(config, section_name, k, v and "1" or "0")
                else
                    u:set(config, section_name, k, tostring(v))
                end
            end)
            if not ok then
                log(string.format("UCI set error for %s.%s.%s: %s", config, section_name, k, tostring(err)))
            end
        end
    end

    local commit_ok, commit_err = pcall(function() u:commit(config) end)
    if commit_ok then
        log("UCI commit successful for " .. tostring(section_name))
        return self:ResponseOK({ success = true, data = { sid = section_name } })
    end

    log("UCI commit failed for " .. config .. ": " .. tostring(commit_err))
    return self:Response(500, { success = false, error = "UCI commit failed: " .. tostring(commit_err) })
end

-- Low-level PUT override to fix 500 Internal Server Errors from the framework
function BasicStation:PUT_TYPE_config(params, data)
    return self:PUT(params, data)
end

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
        -- Check if it's an array of objects
        if payload[1] and type(payload[1]) == "table" then
            log("PUT payload: array of tables detected, iterating handles")
            local has_error = false
            for _, section_payload in ipairs(payload) do
                local section_sid = section_payload[".name"] or section_payload["name"] or sid
                local res = self:handle_uci_save(group, section_sid, section_payload)
                if type(res) == "table" and res.status ~= 200 then
                    has_error = true
                end
            end
            if has_error then
                return self:Response(500, { success = false, error = "Partial commit failures occurred" })
            else
                return self:ResponseOK({ success = true })
            end
        else
            local keys = {}
            for k in pairs(payload) do table.insert(keys, k) end
            log("PUT payload: table with keys: " .. table.concat(keys, ", "))
            return self:handle_uci_save(group, sid, payload)
        end
    elseif type(payload) == "string" then
        log("PUT payload is string, attempting JSON decode: " .. payload:sub(1, 200))
        local ok, decoded = pcall(function()
            local json = require("cjson")
            return json.decode(payload)
        end)
        if ok and type(decoded) == "table" then
            -- Note: For simplicity, assume string decodes are objects not arrays
            local keys = {}
            for k in pairs(decoded) do table.insert(keys, k) end
            log("PUT JSON decoded, keys: " .. table.concat(keys, ", "))
            return self:handle_uci_save(group, sid, decoded)
        else
            log("PUT Error: Failed to decode JSON string")
            return self:Response(400, { success = false, error = "Invalid data payload: not a table or valid JSON" })
        end
    else
        log("PUT Error: Payload is an unsupported type")
        return self:Response(400, { success = false, error = "Invalid data payload type" })
    end
end

function BasicStation:POST(params, data)
    log("BasicStation:POST called (v20)")

    -- The VUCI dispatcher stores the parsed HTTP body in self.arguments
    local args = self.arguments
    log("POST self.arguments type: " .. type(args))

    -- Dump self keys for diagnostics (first time only)
    local self_keys = {}
    for k, v in pairs(self) do
        table.insert(self_keys, k .. "=" .. type(v))
    end
    log("POST self keys: " .. table.concat(self_keys, ", "))

    -- Try to get data from self.arguments or self.arguments.data
    local body = nil
    if type(args) == "table" then
        local args_keys = {}
        for k in pairs(args) do table.insert(args_keys, tostring(k)) end
        log("POST arguments keys: " .. table.concat(args_keys, ", "))

        -- The body could be in args directly or in args.data
        if args.section and args.data then
            body = args
        elseif args.data and type(args.data) == "table" then
            body = args.data
        end
    end

    -- Also try params and data arguments directly
    if not body then
        if type(data) == "table" and data.section then
            body = data
        elseif type(params) == "table" and params.section then
            body = params
        end
    end

    if body and body.section and body.data then
        log("POST dispatching to save_config, section=" .. tostring(body.section))
        return self:POST_action_save_config(body)
    end

    log("POST: no actionable body found, returning OK")
    return self:ResponseOK({ success = true, ignored = true })
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

-- GET_TYPE_station: handles /api/basicstation/config/station
function BasicStation:GET_TYPE_station()
    log("GET_TYPE_station")
    local items = self:get_sections_by_type("station")
    return self:ResponseOK(items and #items > 0 and items[1] or {})
end

function BasicStation:PUT_TYPE_station(params, data)
    if type(params) == "table" then params.service_group = "station" else params = { service_group = "station" } end
    return self:PUT(params, data)
end

-- GET_TYPE_auth: handles /api/basicstation/config/auth
function BasicStation:GET_TYPE_auth()
    log("GET_TYPE_auth")
    local items = self:get_sections_by_type("auth")
    return self:ResponseOK(items and #items > 0 and items[1] or {})
end

function BasicStation:PUT_TYPE_auth(params, data)
    if type(params) == "table" then params.service_group = "auth" else params = { service_group = "auth" } end
    return self:PUT(params, data)
end

-- GET_TYPE_sx130x: handles /api/basicstation/config/sx130x
function BasicStation:GET_TYPE_sx130x()
    log("GET_TYPE_sx130x")
    local items = self:get_sections_by_type("sx130x")
    return self:ResponseOK(items and #items > 0 and items[1] or {})
end

function BasicStation:PUT_TYPE_sx130x(params, data)
    if type(params) == "table" then params.service_group = "sx130x" else params = { service_group = "sx130x" } end
    return self:PUT(params, data)
end

-- GET_TYPE_rfconf: handles /api/basicstation/config/rfconf
function BasicStation:GET_TYPE_rfconf()
    log("GET_TYPE_rfconf")
    return self:ResponseOK(self:get_sections_by_type("rfconf"))
end

function BasicStation:PUT_TYPE_rfconf(params, data)
    if type(params) == "table" then params.service_group = "rfconf" else params = { service_group = "rfconf" } end
    return self:PUT(params, data)
end

-- GET_TYPE_rssitcomp: handles /api/basicstation/config/rssitcomp
function BasicStation:GET_TYPE_rssitcomp()
    log("GET_TYPE_rssitcomp")
    return self:ResponseOK(self:get_sections_by_type("rssitcomp"))
end

function BasicStation:PUT_TYPE_rssitcomp(params, data)
    if type(params) == "table" then params.service_group = "rssitcomp" else params = { service_group = "rssitcomp" } end
    return self:PUT(params, data)
end

-- GET_TYPE_txlut: handles /api/basicstation/txlut
function BasicStation:GET_TYPE_txlut()
    log("GET_TYPE_txlut")
    return self:ResponseOK(self:get_sections_by_type("txlut"))
end

function BasicStation:PUT_TYPE_txlut(params, data)
    if type(params) == "table" then params.service_group = "txlut" else params = { service_group = "txlut" } end
    return self:PUT(params, data)
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
