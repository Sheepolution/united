local united = {}
united.__index = united

local enum_meta = {
    __index    = function(_, k) error("Attempt to index non-existant enum '" .. tostring(k) .. "'.", 2) end,
    __newindex = function() error("Attempt to write to static enum", 2) end,
}

local enum_ids = {}

function united.enum(...)
    local values = { ... }

    if type(values[1]) == "table" then
        values = values[1]
    end

    local enum = {}

    local id
    repeat
        id = "_" .. tostring(math.random(1000, 9999))
    until not enum_ids[id]

    enum_ids[id] = true

    for i = 1, #values do
        enum[values[i]] = values[i] .. id
    end

    return setmetatable(enum, enum_meta)
end

local ignore_type = united.enum { "config", "lock", "check", "current", "all" }

united.ignore = ignore_type

local function findStateType(self, state)
    return self._stateToType[state]
end

local function executeFunction(self, state, data, name, ...)
    local functions = data.functions
    local propName = name

    if functions[propName] == nil then
        local name_state = self.names[state]
        name_state = name_state:sub(1, 1):lower() .. name_state:sub(2)
        local f = self._object[name_state .. name]

        if f then
            functions[propName] = f
            return f(self._object, ...)
        else
            functions[propName] = false
        end
    else
        if functions[propName] then
            return functions[propName](self._object, ...)
        end
    end
end

local function canGoToState(self, state, ignoreTypes)
    local stateType = findStateType(self, state)

    if self._currentStates[stateType] == state and not (ignoreTypes and ignoreTypes[ignore_type.current]) then
        -- We are already in this state
        return false
    end

    if self.locks[stateType] and not (ignoreTypes and ignoreTypes[ignore_type.lock]) then
        return false
    end

    local data = self.stateData[stateType][state]

    if not (ignoreTypes and ignoreTypes[ignore_type.check]) then
        local result = executeFunction(self, state, data, "Check")
        if result == false then
            return false
        end
    end

    if data.all then
        return true
    end

    if not (ignoreTypes and ignoreTypes[ignore_type.config]) then
        for k, v in pairs(self._currentStates) do
            if data.list[v] ~= data.list[k] then
                return false
            end
        end
    end

    return true
end

function united.new(object, ...)
    local self = {}

    self._object = object
    self._currentStates = {}
    self._stateData = {}
    self._stateToType = {}
    self._stateStack = {}
    self._names = {}
    self._locks = {}
    self._callbacks = {}

    for _, statetype in ipairs({ ... }) do
        self._stateData[statetype] = {}
        for k, v in pairs(statetype) do
            if not self._currentStates[statetype] then
                self._currentStates[statetype] = v
            end

            self._stateData[statetype][v] = { all = true, functions = {} }
            self._stateToType[v] = statetype
            self._names[v] = k
            self._stateStack[statetype] = {}
        end
    end

    return setmetatable(self, united)
end

function united:update(dt)
    for k, v in pairs(self._currentStates) do
        executeFunction(self, v, self._stateData[k][v], "Update", dt)
    end
end

function united:configure(configuration)
    for state, conditions in pairs(configuration) do
        local stateType = findStateType(self, state)

        local data = self._stateData[stateType][state]

        data.all = false

        data.list = {}
        for k, v in pairs(conditions) do
            local stateType2 = findStateType(self, k)
            if data.list[stateType2] == nil then
                data.list[stateType2] = v and true or nil
            end

            data.list[k] = true
        end

        self._stateData[state] = data
    end

    return self
end

function united:setCallback(stateType, f)
    self._callbacks[stateType] = f
    return self
end

function united:get(stateType)
    return self._currentStates[stateType]
end

function united:key(stateType)
    return self._names[self._currentStates[stateType]]
end

function united:is(state)
    for _, v in pairs(self._currentStates) do
        if v == state then
            return true
        end
    end

    return false
end

function united:to(state, ignore)
    if ignore and (ignore == true or (type(ignore) == "table" and ignore[ignore_type.All])) then
        ignore = {
            [ignore_type.config] = true,
            [ignore_type.lock] = true,
            [ignore_type.check] = true,
            [ignore_type.current] = true,
        }
    elseif ignore and type(ignore) == "string" then
        ignore = { [ignore] = true }
    end

    local stateType = findStateType(self, state)
    if not canGoToState(self, state, ignore) then
        return false
    end

    local current = self._currentStates[stateType]
    if current and current ~= state then
        executeFunction(self, current, self._stateData[stateType][current], "Exit")
    end

    local new_current = self._currentStates[stateType]
    if new_current ~= current then
        -- The state changed during the exit function
        return false
    end

    if self._callbacks[stateType] then
        self._callbacks[stateType](self._object, current, state)
    end

    executeFunction(self, state, self._stateData[stateType][state], "Enter")

    new_current = self._currentStates[stateType]
    if new_current ~= current then
        -- The state changed during the enter function
        return false
    end

    self._currentStates[stateType] = state

    if ignore and ignore[ignore_type.lock] then
        -- Break the lock
        self._locks[stateType] = nil
    end

    return true
end

function united:push(state, ignore)
    local stateType = findStateType(self, state)
    local current = self._currentStates[stateType]
    if self:to(state, ignore) then
        local stack = self._stateStack[stateType]
        if not stack[#stack] == current then
            stack[#stack + 1] = current
        end
        stack[#stack + 1] = state
    end

    return false
end

function united:pop(stateType)
    local stack = self._stateStack[stateType or self._defaultStateType]
    if #stack > 0 then
        local state = stack[#stack]
        stack[#stack] = nil
        self:to(state, true)
        return true
    end
    return false
end

function united:lock(state)
    if type(state) == "string" then
        local stateType = findStateType(self, state)

        if self._currentStates[stateType] ~= state then
            return false
        end

        self._locks[stateType] = state
        return true
    end

    local stateType = state or self._defaultStateType

    self._locks[stateType] = self._currentStates[stateType]
    return true
end

function united:unlock(state)
    if type(state) == "string" then
        local stateType = findStateType(self, state)
        if self._locks[stateType] == state then
            self._locks[stateType] = nil
            return true
        end
        return false
    end

    self._locks[state or self._defaultStateType] = nil
    return true
end

return united
