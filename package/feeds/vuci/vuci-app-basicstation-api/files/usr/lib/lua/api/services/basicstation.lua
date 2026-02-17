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

log("BASICSTATION SERVICE LOADED v8")

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
-- Clears the BasicStation log file. Uses GET because BasicService only
-- dispatches GET_TYPE_%s (not DELETE_TYPE_%s or POST_TYPE_%s for config).
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

-- NOTE: POST/PUT/DELETE for config sections are handled by the VUCI
-- framework's standard UCI API (/api/uci), not by custom endpoints here.
-- BasicService only dispatches GET_TYPE_%s for GET requests and POST_action
-- for POST requests (action-based pattern).  Config CRUD goes through
-- vuci-form / vuci-named-section components in the frontend.

-- UPLOAD support
--
-- The tlt-upload Vue component sends multipart/form-data with two fields:
--   "option" = the name prop value (e.g., "key", "crt", "trust")
--   "file"   = the actual file content
-- The formdata_parser only recognizes fields named "file" as file uploads;
-- all other fields go into upload_request.parameters.
-- So cert_type comes from upload_request.parameters.option, NOT from
-- file.content_disposition.name (which is stripped by the framework).
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

        -- tlt-upload sends the name prop as parameters.option
        local cert_type = upload_request.parameters
            and upload_request.parameters.option

        -- Fallback: try cert_type parameter (for curl/manual testing)
        if not cert_type and upload_request.parameters then
            cert_type = upload_request.parameters.cert_type
        end

        -- Final fallback: infer from filename
        if not cert_type then
            local fname = (file.filename or ""):lower()
            if fname:match("key") then
                cert_type = "key"
            elseif fname:match("crt") then
                cert_type = "crt"
            else
                cert_type = "trust"
            end
        end

        local cert_info = CERT_FILES[cert_type]
        if not cert_info then
            return false, { code = 5, error = "Invalid certificate type: " .. tostring(cert_type) }
        end

        -- Remove existing target file before the framework moves the new one.
        -- The framework uses nixio.fs.move() which on cross-device moves (tmpfs→overlay)
        -- fails with EACCES if the target file exists and is owned by root, because
        -- uhttpd cannot overwrite it. Removing first lets the move create a fresh file
        -- in the world-writable directory, which uhttpd can do.
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

    -- chmod via os.execute since nixio.fs.chmod may run as uhttpd user
    if cert_type == "key" then
        os.execute("chmod 0600 " .. file.location)
    else
        os.execute("chmod 0644 " .. file.location)
    end

    return { path = file.location, type = cert_type }
end

return BasicStation
