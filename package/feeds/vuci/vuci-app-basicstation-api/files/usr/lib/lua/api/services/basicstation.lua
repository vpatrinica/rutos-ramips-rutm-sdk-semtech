local BasicService = require("api/BasicService")
local fs = require("nixio.fs")
local uci = require("vuci.uci")

local BasicStation = BasicService:new("basicstation")

local function log(msg)
    if msg:sub(1,1) == "-" then msg = " " .. msg end
    os.execute(string.format("logger -t BASICSTATION '%s'", msg:gsub("'", "'\\''")))
end

log("BASICSTATION REFACTORED SERVICE LOADED")

-- Method Dispatchers
function BasicStation:GET(method, sid, query)
    local func = self["GET_" .. tostring(method)]
    if func then return func(self, sid, query) end
    return self:ResponseNotFound({ error = "Method not found", method = method })
end

function BasicStation:POST(method, ...)
    local func = self["POST_" .. tostring(method)]
    if func then return func(self, ...) end
    return self:ResponseNotFound({ error = "Method not found", method = method })
end

function BasicStation:DELETE(method, sid, query)
    local func = self["DELETE_" .. tostring(method)]
    if func then return func(self, sid, query) end
    return self:ResponseNotFound({ error = "Method not found", method = method })
end

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

-- GET /api/basicstation/config[/:sid]
function BasicStation:GET_config(sid)
    log("GET_config: " .. (sid or "all"))
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

-- POST /api/basicstation/config[/:sid]
function BasicStation:POST_config(sid, query, body)
    log("POST_config: " .. (sid or "new"))
    local cursor = uci.cursor()
    
    -- If no sid, we might be creating a new section or updating multiple
    if not sid or sid == "" then
        if type(body) ~= "table" then return self:ResponseBadRequest("Invalid body") end
        -- Basic logic: if body has .type and .name, it's a new section
        local stype = body[".type"] or body["type"]
        local sname = body[".name"] or body["name"]
        if stype then
            sname = cursor:add("basicstation", stype)
            for k, v in pairs(body) do
                if k:sub(1,1) ~= "." and k ~= "id" and k ~= "type" then
                    cursor:set("basicstation", sname, k, v)
                end
            end
            cursor:commit("basicstation")
            return self:ResponseOK({ [".name"] = sname })
        end
        return self:ResponseBadRequest("Missing section type")
    end

    -- Update existing section
    if type(body) ~= "table" then return self:ResponseBadRequest("Invalid body") end
    for k, v in pairs(body) do
        if k:sub(1,1) ~= "." and k ~= "id" then
            cursor:set("basicstation", sid, k, v)
        end
    end
    cursor:commit("basicstation")
    return self:ResponseOK()
end

-- DELETE /api/basicstation/config/:sid
function BasicStation:DELETE_config(sid)
    log("DELETE_config: " .. (sid or "nil"))
    if not sid or sid == "" then return self:ResponseBadRequest("Missing SID") end
    local cursor = uci.cursor()
    cursor:delete("basicstation", sid)
    cursor:commit("basicstation")
    return self:ResponseOK()
end

-- GET /api/basicstation/log
function BasicStation:GET_log()
    local log_path = "/tmp/basicstation/log"
    if not fs.access(log_path) then
        return self:ResponseOK({ log = "" })
    end

    local f = io.open(log_path, "r")
    local content = ""
    if f then
        content = f:read("*all")
        f:close()
    end

    return self:ResponseOK({ log = content })
end

-- DELETE /api/basicstation/log
function BasicStation:DELETE_log()
    local log_path = "/tmp/basicstation/log"
    if fs.access(log_path) then
        os.execute("truncate -s 0 " .. log_path)
    end
    return self:ResponseOK()
end

-- GET /api/basicstation/status
function BasicStation:GET_status()
    -- Check if station process is running.
    -- Usually basicstation init script shows status, but we can also check for 'station' process
    local running = os.execute("pgrep -f 'station' >/dev/null 2>&1") == 0
    -- Fallback/Alternative: use init script if preferred
    -- local running = os.execute("/etc/init.d/basicstation status >/dev/null 2>&1") == 0
    
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
            os.execute("mkdir -p /etc/basicstation")
        end

        local file = upload_request.files[1]
        local cert_type = file.fieldname or "trust"
        local cert_info = CERT_FILES[cert_type]

        if not cert_info then
            return false, { code = 5, error = "Invalid certificate type" }
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
        os.execute("chmod 600 " .. file.location)
    else
        os.execute("chmod 644 " .. file.location)
    end
    
    return { path = file.location, type = cert_type }
end

return BasicStation
