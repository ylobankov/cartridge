local confapplier = require('cluster.confapplier')
local uuid = require('uuid')
local clock = require('clock')
local errors = require('errors')
local utils = require('cluster.utils')
local checks = require('checks')
local token_add_error = errors.new_class("token_add_error")


local TOKEN_CONFIG_KEY = 'cluster_application_tokens_acl'

local function add_token(name)
    checks('string')

    local token_acl, err = confapplier.get_deepcopy(TOKEN_CONFIG_KEY)
    if err ~= nil then
        return nil, err
    end

    if token_acl == nil then
        token_acl = {}
    end

    local token = uuid.str()
    local hash = utils.password_digest(token)
    local created_at = clock.time64()
    local updated_at = clock.time64()


    local new = {
        name = name,
        hash = hash,
        enabled = true,
        created_at = created_at,
        updated_at = updated_at,
        hash_algorithm = 'sha512',
    }

    local collision_fields = {'hash', 'name'}

    for _, tuple in pairs(token_acl)  do
        for _, field_name in pairs(collision_fields) do
            if tuple[field_name] == new[field_name]  then
                return nil, token_add_error:new("Failed to insert new authentication token: collision " .. field_name)
            end
        end
    end

    token_acl[hash] = table.copy(new)

    local ok, err = confapplier.patch_clusterwide({[TOKEN_CONFIG_KEY] = token_acl})
    if not ok then
        return nil, err
    end

    --The only one single place to view token
    new.token = token
    return new
end

local function remove_token(hash)
    checks('string')

    local token_acl, err = confapplier.get_deepcopy(TOKEN_CONFIG_KEY)
    if err ~= nil then
        return nil, err
    end

    if token_acl == nil or token_acl[hash] == nil then
        return nil, token_add_error:new('No token found %s', hash)
    end

    local old = token_acl[hash]
    token_acl[hash] = nil

    local ok, err = confapplier.patch_clusterwide({[TOKEN_CONFIG_KEY] = token_acl})
    if not ok then
        return nil, err
    end

    return old
end



local function list_tokens(part_name)
    checks('?string')
    local filter_name = part_name or ''
    local result = {}

    local token_acl = confapplier.get_readonly(TOKEN_CONFIG_KEY) or {}
    for hash, val in pairs(token_acl) do
        local find_point = string.find(val.name, filter_name)
        if find_point then
            local token_info = {
                hash = hash,
                name = val.name,
                created_at = val.created_at,
                updated_at = val.updated_at,
                enabled = val.enabled,
                hash_algorithm = val.hash_algorithm,
            }
            table.insert(result, token_info)
        end
    end

    return result
end

local function validate_token(token)
    checks({
        name = 'string',
        hash = 'string',
        enabled = 'boolean',
        created_at = 'uint64',
        updated_at = 'uint64',
        hash_algorithm = 'string',
    })
    return nil
end

local function process_tokens(tokens)
    checks('table')
    local token_acl, err = confapplier.get_deepcopy(TOKEN_CONFIG_KEY)
    if err ~= nil then
        return err
    end

    if token_acl == nil then
        token_acl = {}
    end

    local collision_fields = {'hash', 'name'}

    for _, token in ipairs(tokens) do
        local ok, validation_error = pcall(validate_token, token)
        if validation_error then
            return validation_error
        end

        for _, tuple in pairs(token_acl)  do
            for _, field_name in pairs(collision_fields) do
                if tuple[field_name] == token[field_name]  then
                    return token_add_error:new("Failed to insert new authentication token: collision " .. field_name)
                end
            end
        end

        token_acl[token.hash] = table.copy(token)
    end

    local ok, err = confapplier.patch_clusterwide({[TOKEN_CONFIG_KEY] = token_acl})
    if not ok then
        return err
    end

    return nil
end

local function set_token_enabled(hash, enabled)
    checks('string', 'boolean')

    local token_acl = confapplier.get_deepcopy(TOKEN_CONFIG_KEY) or {}

    if token_acl == nil or token_acl[hash] == nil then
        return nil, token_add_error:new('No token found %s', hash)
    end

    local updated_tuple = table.copy(token_acl[hash])

    updated_tuple.enabled = enabled
    updated_tuple.updated_at = clock.time64()
    token_acl[hash] = updated_tuple

    local ok, err = confapplier.patch_clusterwide({[TOKEN_CONFIG_KEY] = token_acl})
    if not ok then
        return nil, err
    end

    return updated_tuple
end

local function rename_token(hash, name)
    checks('string', 'string')

    local token_acl = confapplier.get_deepcopy(TOKEN_CONFIG_KEY) or {}

    if token_acl == nil or token_acl[hash] == nil then
        return nil, token_add_error:new('No token found %s', name)
    end

    local updated_tuple = table.copy(token_acl[hash])

    updated_tuple.name = name
    updated_tuple.updated_at = clock.time64()

    token_acl[hash] = table.copy(updated_tuple)

    local ok, err = confapplier.patch_clusterwide({[TOKEN_CONFIG_KEY] = token_acl})
    if not ok then
        return nil, err
    end

    return updated_tuple
end


local function regenerate_token(hash)
    checks('string')

    local token_acl = confapplier.get_deepcopy(TOKEN_CONFIG_KEY) or {}

    if token_acl == nil or token_acl[hash] == nil then
        return nil, token_add_error:new('No token found %s', hash)
    end

    local regenerated_token = table.copy(token_acl[hash])
    token_acl[hash] = nil

    local new_token = uuid.str()
    local new_hash = utils.password_digest(new_token)
    regenerated_token.updated_at = clock.time64()
    regenerated_token.created_at = clock.time64()

    regenerated_token.hash = new_hash

    token_acl[new_hash] = table.copy(regenerated_token)


    local ok, err = confapplier.patch_clusterwide({[TOKEN_CONFIG_KEY] = token_acl})
    if not ok then
        return nil, err
    end

    regenerated_token.token = new_token

    return regenerated_token
end


local function get_token_from_request(request)
    -- DO NOT USE just request:param() - it reads body and next handler work failed
    return request.headers['auth-token'] or request:query_param('auth-token')
end

local function get_token_info(token)
    local token_acl, err = confapplier.get_readonly(TOKEN_CONFIG_KEY)
    if err ~= nil then
        return nil
    end

    -- If we have never initialized acl list we can get nil in token_acl
    if token_acl == nil then
        return nil
    end

    local digest = utils.password_digest(token)

    local info = token_acl[digest]
    if info == nil or info.enabled == false then
        return nil
    end

    return {
        uid = digest,
        name = info.name }
end

local function check_token(token)
    local res = get_token_info(token)
    if res == nil then
        return false
    end
    return true
end

local function get_token_by_name(name)
    local token_acl = confapplier.get_readonly(TOKEN_CONFIG_KEY) or {}
    for _, val in pairs(token_acl) do
        if val.name == name then
            return val
        end
    end
    return nil
end

return {
    add_token = add_token,
    remove_token = remove_token,
    list_tokens = list_tokens,
    process_tokens = process_tokens,
    set_token_enabled = set_token_enabled,
    rename_token = rename_token,
    regenerate_token = regenerate_token,

    get_token_from_request = get_token_from_request,
    get_token_info = get_token_info,
    get_token_by_name = get_token_by_name,
    check_token = check_token,

    TOKEN_CONFIG_KEY = TOKEN_CONFIG_KEY,

}
