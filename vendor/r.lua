local jua = nil
local idPatt = "#R%d+"

local callbackRegistry = {}

local function gfind(str, patt)
    local t = {}
    for found in str:gmatch(patt) do
        table.insert(t, found)
    end

    if #t > 0 then
        return t
    else
        return nil
    end
end

local function findID(url)
    local found = gfind(url, idPatt)
    if not found then
        return -1
    end
    return tonumber(found[#found]:sub(found[#found]:find("%d+")))
end

local function newID()
    for i = 1, math.huge do
        if not callbackRegistry[i] then
            return i
        end
    end
end

local function trimID(url)
    local found = gfind(url, idPatt)
    local s, e = url:find(found[#found])
    return url:sub(1, s-1)
end

function request(callback, url, headers, postData)
    local id = newID()
    local newUrl = url .. "#R" .. id
    callbackRegistry[id] = callback
    http.request(newUrl, postData, headers)
end

function init(jua)
    jua = jua
    jua.on("http_success", function(event, url, handle)
        local id = findID(url)
        if callbackRegistry[id] then
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].success then
                callbackRegistry[id].success(true, trimID(url), handle)
            else
                callbackRegistry[id](true, trimID(url), handle)
            end
            callbackRegistry[id] = nil
        end
    end)

    jua.on("http_failure", function(event, url, handle)
        local id = findID(url)
        if callbackRegistry[id] then
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].failure then
                callbackRegistry[id].failure(false, trimID(url), handle)
            else
                callbackRegistry[id](false, trimID(url), handle)
            end
            callbackRegistry[id] = nil
        end
    end)
end

return {
    request = request,
    init = init
}
