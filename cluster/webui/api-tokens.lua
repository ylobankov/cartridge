#!/usr/bin/env tarantool

local log = require('log')
local yaml = require('yaml').new()

local tokens = require('cluster.tokens')
local gql_types = require('cluster.graphql.types')
local errors = require('errors')
local http_utils = require('cluster.http-utils')
local auth = require('cluster.auth')
local confapplier = require('cluster.confapplier')

local module_name = 'cluster.webui.api-tokens'

local gql_type_token = gql_types.object({
    name = 'ClusterApplicationToken',
    description = 'A token that will be used in apps',
    fields = {
        hash = gql_types.string.nonNull,
        token = gql_types.string,
        created_at = gql_types.long.nonNull,
        updated_at = gql_types.long.nonNull,
        name = gql_types.string.nonNull,
        enabled = gql_types.boolean.nonNull,
        hash_algorithm = gql_types.string.nonNull,
    }
})

local function list_tokens(_, args)
    return tokens.list_tokens(args.part_name)
end

local function add_token(_, args)
    return tokens.add_token(args.name)
end

local function enable_token(_, args)
    return tokens.set_token_enabled(args.hash, true)
end

local function disable_token(_, args)
    return tokens.set_token_enabled(args.hash, false)
end


local function rename_token(_, args)
    return tokens.rename_token(args.hash, args.name)
end


local function regenerate_token(_, args)
    return tokens.regenerate_token(args.hash)
end

local e_download_tokens = errors.new_class('Tokens download failed')
local function download_tokens_handler(req)
    if not auth.check_request(req) then
        local err = e_download_tokens:new('Unauthorized')
        return http_utils.http_finalize_error(401, err)
    end

    local current_tokens = tokens.list_tokens()

    return {
        status = 200,
        headers = {
            ['content-type'] = "application/yaml",
            ['content-disposition'] = 'attachment; filename="tokens.yml"',
        },
        body = yaml.encode(current_tokens)
    }
end

local e_upload_tokens = errors.new_class('Tokens upload failed')
local e_decode_yaml = errors.new_class('Decoding YAML failed')
local function upload_tokens_handler(req)
    if not auth.check_request(req) then
        local err = e_upload_tokens:new('Unauthorized')
        return http_utils.http_finalize_error(401, err)
    end

    if confapplier.get_readonly() == nil then
        local err = e_upload_tokens:new('Cluster isn\'t bootsrapped yet')
        return http_utils.http_finalize_error(409, err)
    end

    local req_body = http_utils.read_request_body(req)

    local file_tokens, err = nil
    if req_body == nil then
        err = e_upload_tokens:new('Request body must not be empty')
    else
        file_tokens, err = e_decode_yaml:pcall(yaml.decode, req_body)
    end

    if err ~= nil then
        return http_utils.http_finalize_error(400, err)
    elseif type(file_tokens) ~= 'table' then
        err = e_upload_tokens:new('Tokens must be a table')
        return http_utils.http_finalize_error(400, err)
    elseif next(file_tokens) == nil then
        err = e_upload_tokens:new('Tokens must not be empty')
        return http_utils.http_finalize_error(400, err)
    end

    local process_error = tokens.process_tokens(file_tokens)

    if process_error then
        return http_utils.http_finalize_error(400, process_error)
    end

    log.warn('Tokens uploaded')

    return { status = 200 }
end

local function init(httpd, graphql)
    httpd:route({
        path = '/admin/tokens',
        method = 'PUT'
    }, upload_tokens_handler)
    httpd:route({
        path = '/admin/tokens',
        method = 'GET'
    }, download_tokens_handler)

    graphql.add_callback({
        prefix = 'cluster',
        name = 'access_tokens',
        doc = 'Fetch all access tokens',
        args = {
            part_name = gql_types.string,
        },
        kind = gql_types.list(gql_type_token.nonNull),
        callback = module_name .. '.list_tokens',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'add_access_token',
        doc = 'Add access token',
        args = {
            name = gql_types.string.nonNull
        },
        kind = gql_type_token.nonNull,
        callback = module_name .. '.add_token',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'regenerate_access_token',
        doc = 'Regenerate access token',
        args = {
            hash = gql_types.string.nonNull,
        },
        kind = gql_type_token.nonNull,
        callback = module_name .. '.regenerate_token',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'rename_token',
        doc = 'Rename access token',
        args = {
            hash = gql_types.string.nonNull,
            name = gql_types.string.nonNull,
        },
        kind = gql_type_token.nonNull,
        callback = module_name .. '.rename_token',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'enable_token',
        doc = 'Enable access token',
        args = {
            hash = gql_types.string.nonNull,
        },
        kind = gql_type_token.nonNull,
        callback = module_name .. '.enable_token',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'disable_token',
        doc = 'Disable access token',
        args = {
            hash = gql_types.string.nonNull,
        },
        kind = gql_type_token.nonNull,
        callback = module_name .. '.disable_token',
    })
end

return {
    init = init,

    add_token = add_token,
    list_tokens = list_tokens,
    regenerate_token = regenerate_token,
    enable_token = enable_token,
    disable_token = disable_token,
    rename_token = rename_token,

    gql_type_token = gql_type_token,
}
