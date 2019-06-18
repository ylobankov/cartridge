#!/usr/bin/env tarantool

local log = require('log')
local yaml = require('yaml').new()
local errors = require('errors')
local checks = require('checks')

local auth = require('cluster.auth')
-- local tokens = require('cluster.tokens')
local gql_types = require('cluster.graphql.types')
local http_utils = require('cluster.http-utils')
local confapplier = require('cluster.confapplier')

local module_name = 'cluster.webui.api-tokens'

local gql_type_token = gql_types.object({
    name = 'Token',
    description = 'Auth token apps',
    fields = {
        name = gql_types.string.nonNull,
        secret = gql_types.string,
        enabled = gql_types.boolean.nonNull,
        created_at = gql_types.long.nonNull,
        updated_at = gql_types.long.nonNull,
    }
})

local function tokens(_, args)
    checks('?', {name = '?string'})

    if args.name ~= nil then
        local token, err = auth.get_token(args.name)

        if token == nil then
            return nil, err
        end

        return {token}
    else
        return auth.list_tokens()
    end
end

local function create_token(_, args)
    checks('?', {name = 'string'})
    return auth.create_token(args.name)
end

local function remove_token(_, args)
    checks('?', {name = 'string'})
    return auth.remove_token(args.name)
end

local function rename_token(_, args)
    checks('?', {name = 'string', rename = 'string'})
    return auth.edit_token(args.name, {rename = args.rename})
end

local function enable_token(_, args)
    checks('?', {name = 'string'})
    return auth.edit_token(args.name, {disabled = false})
end

local function disable_token(_, args)
    checks('?', {name = 'string'})
    return auth.edit_token(args.name, {disabled = true})
end

local function regenerate_token(_, args)
    checks('?', {name = 'string'})
    return auth.edit_token(args.name, {regenerate = true})
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
        name = 'tokens',
        doc = 'List access tokens',
        args = {
            name = gql_types.string,
        },
        kind = gql_types.list(gql_type_token).nonNull,
        callback = module_name .. '.tokens',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'rename_token',
        doc = 'Rename access token',
        args = {
            name = gql_types.string.nonNull,
            rename = gql_types.string.nonNull,
        },
        kind = gql_type_token.nonNull,
        callback = module_name .. '.' .. 'rename_token',
    })

    local function add_token_mutation(name, doc)
        graphql.add_mutation({
            prefix = 'cluster',
            name = name,
            doc = doc,
            args = {
                name = gql_types.string.nonNull,
            },
            kind = gql_type_token.nonNull,
            callback = module_name .. '.' .. name,
        })
    end

    add_token_mutation('create_token', 'Create access token')
    add_token_mutation('remove_token', 'Remove access token')
    add_token_mutation('enable_token', 'Enable access token')
    add_token_mutation('disable_token', 'Disable access token')
    add_token_mutation('regenerate_token', 'Regenerate access token secret')
end

return {
    init = init,

    tokens = tokens,
    create_token = create_token,
    remove_token = remove_token,
    rename_token = rename_token,
    enable_token = enable_token,
    disable_token = disable_token,
    regenerate_token = regenerate_token,
}
