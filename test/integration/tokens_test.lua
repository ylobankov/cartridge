local fio = require('fio')
local t = require('luatest')
local clock = require('clock')
local g = t.group('tokens')



local test_helper = require('test.helper')

local helpers = require('cluster.test_helpers')
local utils = require('cluster.utils')

local cluster

local function add_token(token_name)
    local server = cluster.main_server
    return server:graphql({
        query =[[
        mutation($name: String!){
            cluster{
                add_access_token(name: $name) {
                    name
                    token
                    hash
                    created_at
                    updated_at
                    enabled
                    hash_algorithm
                }
            }
        }]],
        variables = { name = token_name },
    })
end

g.before_all = function()
    cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = test_helper.server_command,
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router', 'vshard-storage'},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            },
        },
    })
    cluster:start()
end
g.after_all = function()
    cluster:stop()
    fio.rmtree(cluster.datadir)
end

g.test_add_token = function()
    local server = cluster.main_server
    local token_name = 'token_1'

    local res = add_token(token_name)

    t.assert_equals(type(res.data.cluster.add_access_token.name), 'string')
    t.assert_equals(type(res.data.cluster.add_access_token.token), 'string')
    t.assert_equals(type(res.data.cluster.add_access_token.hash), 'string')
    t.assert_equals(res.data.cluster.add_access_token.enabled, true)

    local res_filtered_tokens = server:graphql({
        query =[[
        query($name: String!){
            cluster{
                access_tokens(part_name: $name) {
                    name
                    hash
                    created_at
                    updated_at
                    enabled
                    hash_algorithm
                }
            }
        }]],
        variables = { name = token_name },
    })

    local res_token = res_filtered_tokens.data.cluster.access_tokens[1]

    t.assert_equals(res_token.name, token_name)
    t.assert_equals(res_token.enabled, true)
end


g.test_list_tokens = function()
    local server = cluster.main_server
    local token_names = {}
    local token_count = 10
    for i=token_count, 1, -1 do
        table.insert(token_names, 0, 'token_list_' .. i)
    end

    for _, token_name in ipairs(token_names) do
        local res = add_token(token_name)
        t.assert_equals(type(res.data.cluster.add_access_token.name), 'string')
        t.assert_equals(type(res.data.cluster.add_access_token.token), 'string')
        t.assert_equals(type(res.data.cluster.add_access_token.hash), 'string')
        t.assert_equals(res.data.cluster.add_access_token.enabled, true)
    end





    local res_tokens = server:graphql({
        query =[[
        query{
            cluster{
                access_tokens {
                    name
                    hash
                    created_at
                    updated_at
                    enabled
                    hash_algorithm
                }
            }
        }]],
    })

    local count_find_tokens = 0
    local access_tokens = res_tokens.data.cluster.access_tokens

    for _, t in ipairs(access_tokens) do
        for _, token_name in ipairs(token_names) do
            if t.name == token_name then
                count_find_tokens = count_find_tokens + 1
            end
        end
    end
    t.assert_equals(count_find_tokens, token_count - 1)
end

g.test_duplicate_token = function()
    local server = cluster.main_server
    local token_name = 'token_2'

    local res = add_token(token_name)

    t.assert_equals(res.data.cluster.add_access_token.name, token_name)
    t.assert_equals(res.data.cluster.add_access_token.enabled, true)

    local ok, res2 = pcall(server.graphql, server, {
        query =[[
        mutation($name: String!){
            cluster{
                add_access_token(name: $name) {
                    name
                    token
                    hash
                    created_at
                    updated_at
                    enabled
                    hash_algorithm
                }
            }
        }]],
        variables = { name = token_name },
    })


    t.assert_equals(ok, false)
    t.assert_equals(type(res2:find('collision name')), 'number')
end

g.test_regenerate_token = function()
    local server = cluster.main_server
    local token_name = 'token_3'

    local res = add_token(token_name)

    t.assert_equals(res.data.cluster.add_access_token.name, token_name)
    t.assert_equals(type(res.data.cluster.add_access_token.token), 'string')
    t.assert_equals(type(res.data.cluster.add_access_token.hash), 'string')
    t.assert_equals(res.data.cluster.add_access_token.enabled, true)

    local hash = res.data.cluster.add_access_token.hash


    local res2 = server:graphql({
        query = [[
        mutation ($hash: String!) {
            cluster {
                regenerate_access_token(hash: $hash) {
                    name
                    token
                    hash
                    updated_at
                    created_at
                    enabled
                }
            }
        }
        ]],
        variables = { hash = hash },
    })


    t.assert_equals(res2.data.cluster.regenerate_access_token.name, token_name)
    t.assert_equals(type(res2.data.cluster.regenerate_access_token.token), 'string')
    t.assert_equals(type(res2.data.cluster.regenerate_access_token.hash), 'string')
    t.assert_equals(res2.data.cluster.regenerate_access_token.hash ~= hash, true)
    t.assert_equals(res2.data.cluster.regenerate_access_token.enabled, true)
end

g.test_disabled_enabled_token = function()
    local server = cluster.main_server
    local token_name = 'token_4'

    local res = add_token(token_name)

    local hash = res.data.cluster.add_access_token.hash


    local res2 = server:graphql({
        query = [[
        mutation ($hash: String!) {
            cluster {
                disable_token(hash: $hash) {
                    name
                    enabled
                }
            }
        }
        ]],
        variables = { hash = hash },
    })


    t.assert_equals(res2.data.cluster.disable_token.name, token_name)
    t.assert_equals(res2.data.cluster.disable_token.enabled, false)

    local res_tokens = server:graphql({
        query =[[
        query{
            cluster{
                access_tokens {
                    name
                    enabled
                }
            }
        }]],
    })
    local found_disabled = false
    for _, token in ipairs(res_tokens.data.cluster.access_tokens) do
        if token.name == token_name then
            found_disabled = true
            t.assert_equals(token.enabled, false)
        end
    end

    t.assert_equals(found_disabled, true)

    local res3 = server:graphql({
        query = [[
        mutation ($hash: String!) {
            cluster {
                enable_token(hash: $hash) {
                    name
                    enabled
                }
            }
        }
        ]],
        variables = { hash = hash },
    })


    t.assert_equals(res3.data.cluster.enable_token.name, token_name)
    t.assert_equals(res3.data.cluster.enable_token.enabled, true)

    local res_after_tokens = server:graphql({
        query =[[
        query{
            cluster{
                access_tokens {
                    name
                    enabled
                }
            }
        }]],
    })
    local found_enabled = false
    for _, token in ipairs(res_after_tokens.data.cluster.access_tokens) do
        if token.name == token_name then
            found_enabled = true
            t.assert_equals(token.enabled, true)
        end
    end
    t.assert_equals(found_enabled, true)
end

g.test_rename_token = function()
    local server = cluster.main_server
    local token_name = 'token_5'

    local res = add_token(token_name)

    local hash = res.data.cluster.add_access_token.hash

    t.assert_equals(res.data.cluster.add_access_token.name, token_name)

    local new_name = 'token_new_name5'


    local res2 = server:graphql({
        query = [[
        mutation ($hash: String!, $name: String!) {
            cluster {
                rename_token(hash: $hash, name: $name) {
                    name
                    hash
                }
            }
        }
        ]],
        variables = { hash = hash, name = new_name },
    })

    t.assert_equals(res2.data.cluster.rename_token.name, new_name)
    t.assert_equals(res2.data.cluster.rename_token.hash, hash)


    local res_tokens = server:graphql({
        query =[[
        query{
            cluster{
                access_tokens {
                    name
                    enabled
                    hash
                }
            }
        }]],
    })
    local found_renamed = false
    for _, token in ipairs(res_tokens.data.cluster.access_tokens) do
        if token.hash == hash then
            found_renamed = true
            t.assert_equals(token.name, new_name)
        end
    end

    t.assert_equals(found_renamed, true)
end

g.test_download_tokens = function()
    local server = cluster.main_server
    local token_name = 'uploaded_token_1'

    add_token(token_name)

    local tokens = server:download_tokens()
    local found = false
    for _, t in ipairs(tokens) do
        if t.name == token_name then
            found = true
        end
    end
    t.assert_equals(found, true)
end

g.test_upload_tokens = function()
    local server = cluster.main_server
    local token_name = 'uploaded_token_2'

    local hash = utils.password_digest('password')

    local token_list = {
        {
            name = token_name,
            enabled=true,
            hash=hash,
            hash_algorithm="sha512",
            updated_at=clock.time64(),
            created_at=clock.time64(),
        }
    }

    server:upload_tokens(token_list)

    local tokens = server:download_tokens()
    local found = false
    for _, t in ipairs(tokens) do
        if t.name == token_name and t.hash == hash then
            found = true
        end
    end
    t.assert_equals(found, true)
end

g.test_double_upload_tokens = function()
    local server = cluster.main_server
    local token_name = 'uploaded_token_3'

    local hash = utils.password_digest('password_3')

    local token_list = {
        {
            name = token_name,
            enabled=true,
            hash=hash,
            hash_algorithm="sha512",
            updated_at=clock.time64(),
            created_at=clock.time64(),
        }
    }

    server:upload_tokens(token_list)

    local tokens = server:download_tokens()
    local found = false
    for _, t in ipairs(tokens) do
        if t.name == token_name and t.hash == hash then
            found = true
        end
    end
    t.assert_equals(found, true)

    local ok, res = pcall(server.upload_tokens, server, token_list)

    t.assert_equals(ok, false)
    t.assert_equals(type(res.response.body:find('collision')), 'number')


end


