import base64
import json
from datetime import datetime


def bit_base64(b64, timestamp):
    buff = base64.b64decode(b64)
    r = [timestamp]
    for b in buff:
        for j in range(8):
            r.append((b >> j) & 1)
    return r


def byte_base64(b64, timestamp):
    buff = base64.b64decode(b64)
    r = [timestamp]
    for b in buff:
        r.append(b)
    return r


def word_base64(b64, timestamp):
    buff = base64.b64decode(b64)
    r = [timestamp]
    for i in range(0, len(buff), 2):
        r.append((buff[i + 1] << 8) | buff[i])
    return r


def dword_base64(b64, timestamp):
    buff = base64.b64decode(b64)
    r = [timestamp]
    for i in range(0, len(buff), 4):
        r.append(
            buff[i] | (buff[i + 1] << 8) | (buff[i + 2] << 16) | (buff[i + 3] << 24)
        )
    return r


def apply_range(old_arr, start, end, new_vals):
    arr = []
    arr.append(new_vals[0])

    i = 1
    j = 1
    while i < start:
        arr.append(old_arr[i] if i < len(old_arr) else None)
        i += 1

    while i <= end:
        arr.append(new_vals[j] if j < len(new_vals) else None)
        i += 1
        j += 1

    while i < len(old_arr):
        arr.append(old_arr[i])
        i += 1

    return arr


def init_dev():
    return {
        "I": [],
        "O": [],
        "AI": [],
        "AO": [],
        "M": [],
        "MB": [],
        "MW": [],
        "MD": [],
        "ID": [],
        "N": [""] * 9,
        "NB": [""] * 9,
        "NW": [""] * 9,
        "ND": [""] * 9,
        "STATE": "",
        "DEVLOCATION": {"LONGITUDE": "", "LATITUDE": ""},
        "DATE": "",
        "TIME": "",
        "DEVNAME": "",
        "VERS": "",
        "BUILD": "",
        "MAC": "",
        "IPSET": {},
        "PROGNAME": "",
        "EMAIL": {},
        "CYC": {},
        "USER": "",
        "EXTSTATE": {},
        "DIAG_CNT": "",
        "DIAG_TIME": "",
        "DIAG_LIST": [],
        "IOX": False,
    }


def decode_parse(jdata_str):
    if not jdata_str:
        return None
    try:
        p_data = json.loads(jdata_str)
    except json.JSONDecodeError:
        return None

    dev = init_dev()
    now_ts = datetime.now().isoformat()

    if "SYSINFO" in p_data:
        for k, v in p_data["SYSINFO"].items():
            if k in ["EXTSTATE", "IPSET", "CYC", "EMAIL"]:
                dev[k] = v
            elif k == "STATE":
                dev[k] = "RUN" if v == "RUN" else "STOP"
            elif k == "EXTBUS":
                dev["IOX"] = v == "1"
            elif k == "DEVLOCATION":
                lng, lat = v.get("LONGITUDE"), v.get("LATITUDE")
                if lng and str(lng) != "0":
                    dev["DEVLOCATION"]["LONGITUDE"] = float(lng) / 1000000.0
                else:
                    dev["DEVLOCATION"]["LONGITUDE"] = lng
                if lat and str(lat) != "0":
                    dev["DEVLOCATION"]["LATITUDE"] = float(lat) / 1000000.0
                else:
                    dev["DEVLOCATION"]["LATITUDE"] = lat
            else:
                dev[k] = v

    def apply_single(arr_key, items):
        for item in items:
            if "V" in item:
                while len(dev[arr_key]) <= item["INDEX"]:
                    dev[arr_key].append(None)
                dev[arr_key][item["INDEX"]] = item["V"]

    def apply_range_wrap(arr_key, items, decode_fn):
        for item in items:
            if "V" in item:
                dev[arr_key] = apply_range(
                    dev.get(arr_key, []),
                    item["START"],
                    item["END"],
                    decode_fn(item["V"], now_ts),
                )

    if "OPERANDS" in p_data:
        for k, c in p_data["OPERANDS"].items():
            if k == "MWSINGLE":
                apply_single("MW", c)
            elif k == "MWRANGE":
                apply_range_wrap("MW", c, word_base64)
            elif k == "MBSINGLE":
                apply_single("MB", c)
            elif k == "MBRANGE":
                apply_range_wrap("MB", c, byte_base64)
            elif k == "MDSINGLE":
                apply_single("MD", c)
            elif k == "MDRANGE":
                apply_range_wrap("MD", c, dword_base64)
            elif k == "MSINGLE":
                apply_single("M", c)
            elif k == "MRANGE":
                apply_range_wrap("M", c, bit_base64)
            elif k == "ISINGLE":
                apply_single("I", c)
            elif k == "IRANGE":
                apply_range_wrap("I", c, bit_base64)
            elif k == "OSINGLE":
                apply_single("O", c)
            elif k == "ORANGE":
                apply_range_wrap("O", c, bit_base64)
            elif k == "AISINGLE":
                apply_single("AI", c)
            elif k == "AIRANGE":
                apply_range_wrap("AI", c, dword_base64)
            elif k == "AOSINGLE":
                apply_single("AO", c)
            elif k == "AORANGE":
                apply_range_wrap("AO", c, dword_base64)
            elif k == "IDSINGLE":
                apply_single("ID", c)
            elif k == "IDRANGE":
                apply_range_wrap("ID", c, bit_base64)

    return dev
