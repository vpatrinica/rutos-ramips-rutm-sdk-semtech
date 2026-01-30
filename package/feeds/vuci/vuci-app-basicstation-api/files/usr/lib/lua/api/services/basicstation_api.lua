local FunctionService = require("api/FunctionService")
local ConfigService = require("api/ConfigService")
local fs = require("api/fs")

local BasicStation = FunctionService:new()

---
--- Function Endpoints
---

-- GET /api/basicstation/services/basicstation/log
function BasicStation:GET_TYPE_log()
    local log_path = "/tmp/basicstation/log"
    local content = fs.read(log_path) or ""
    
    return self:ResponseOK({
        log = content
    })
end

-- Certificate file paths and UCI option mappings
local CERT_FILES = {
    trust = { path = "/etc/basicstation/tc.trust", uci_option = "trust" },
    key   = { path = "/etc/basicstation/tc.key",   uci_option = "key" },
    crt   = { path = "/etc/basicstation/tc.crt",   uci_option = "crt" }
}

function BasicStation:UPLOAD_init()
    local function handle_request(upload_request)
        if #upload_request.files > 1 then
            return false, { code = 5, error = "Only uploading a single file is allowed", source = "filename" }
        end

        -- Determine file type from upload field name
        local file = upload_request.files[1]
        local cert_type = file.fieldname or "trust"
        local cert_info = CERT_FILES[cert_type]
        
        if not cert_info then
            return false, { code = 5, error = "Invalid certificate type: " .. tostring(cert_type), source = "fieldname" }
        end
        
        -- Save to fixed path based on cert type
        file.location = cert_info.path
        file.cert_type = cert_type  -- Store for after_upload_hook
        return true
    end

    return { handle_request = handle_request }
end

function BasicStation:UPLOAD_after_upload_hook(upload_request)
    local file = upload_request.files[1]
    local path = file.location
    local cert_type = file.cert_type or "trust"
    local cert_info = CERT_FILES[cert_type]
    
    if cert_info then
        -- Update UCI option to point to the uploaded file
        local cursor = require("vuci.uci").cursor()
        cursor:set("basicstation", "auth", cert_info.uci_option, path)
        cursor:commit("basicstation")
    end
    
    -- Set file permissions (readable by basicstation service, private key more restrictive)
    if cert_type == "key" then
        os.execute("chmod 600 " .. path)  -- Private key - owner read/write only
    else
        os.execute("chmod 644 " .. path)  -- Certificates - world readable
    end
    
    return { path = path, type = cert_type }
end

---
--- Config Service for UCI access
---

local Config = ConfigService:new()

-- Station Section
local Station = Config:section("basicstation", "station")
Station:make_primary()

local idGenIf = Station:option("idGenIf")
-- Custom write to also update routerid path (matching LuCI behavior)
idGenIf.write = function(self, section, value)
    local cursor = require("vuci.uci").cursor()
    cursor:set("basicstation", section, "idGenIf", value)
    cursor:set("basicstation", section, "routerid", "/sys/class/net/" .. value .. "/address")
    cursor:commit("basicstation")
end

Station:option("stationid").readonly = true
Station:option("logLevel")
Station:option("logSize").datatype = "range(1, 10)"
Station:option("logRotate").datatype = "range(1, 10)"

-- Authentication Section
local Auth = Config:section("basicstation", "auth")

Auth:option("cred")
Auth:option("mode")
Auth:option("addr")
Auth:option("port").datatype = "uinteger"
Auth:option("token")
Auth:option("key")
Auth:option("crt")
Auth:option("trust")

-- Radio Configuration (SX130x)
local Sx130x = Config:section("basicstation", "sx130x")

Sx130x:option("comif")
Sx130x:option("devpath")
Sx130x:option("pps").datatype = "boolean"
Sx130x:option("public").datatype = "boolean"
Sx130x:option("clksrc")
Sx130x:option("radio0")
Sx130x:option("radio1")

-- RF Configuration
local RfConf = Config:section("basicstation", "rfconf")

RfConf:option("type")
RfConf:option("txEnable").datatype = "boolean"
RfConf:option("freq").datatype = "uinteger"
RfConf:option("antennaGain").datatype = "uinteger"
RfConf:option("rssiOffset").datatype = "float"
RfConf:option("useRssiTcomp")

-- RSSI Tcomp
local RssiTcomp = Config:section("basicstation", "rssitcomp")

RssiTcomp:option("coeff_a").datatype = "float"
RssiTcomp:option("coeff_b").datatype = "float"
RssiTcomp:option("coeff_c").datatype = "float"
RssiTcomp:option("coeff_d").datatype = "float"
RssiTcomp:option("coeff_e").datatype = "float"

-- TX Gain Lookup Table
local TxLut = Config:section("basicstation", "txlut")

TxLut:option("rfPower").datatype = "uinteger"
TxLut:option("paGain").datatype = "boolean"
TxLut:option("pwrIdx").datatype = "range(0, 22)"
TxLut:option("usedBy", { list = true })

-- Merge config service into function service
BasicStation.config = Config

return BasicStation
