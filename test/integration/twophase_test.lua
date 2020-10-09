local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = require('digest').urandom(6):hex(),

        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {{
                    alias = 'router',
                    instance_uuid = helpers.uuid('a', 'a', 1),
                    advertise_port = 13301,
                    http_port = 8081
                }}
            },
            {
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                servers = {{
                    alias = 'server',
                    instance_uuid = helpers.uuid('b', 'b', 1),
                    advertise_port = 13302,
                    http_port = 8082
                }}
            },
        }
    })

    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_prepare_config_releases()
    local function gql_simple_apply_cfg()
        return g.cluster.main_server:graphql({
            query = [[
                mutation { cluster { schema(as_yaml: "{}") {} } }
            ]],
            raise = false,
        })
    end

    local server = g.cluster:server('server')

    -- monkeypatch of prepare_config at twophase:
    -- call origin patch_config and sleep after that, to get netboxcall timeout error on initiator
    -- of patch_clusterwide
    server.net_box:eval([[
        _G._old__cartridge_clusterwide_config_prepare_2pc = _G.__cartridge_clusterwide_config_prepare_2pc
        _G.__cartridge_clusterwide_config_prepare_2pc = function(...)
            local ok, err = _G._old__cartridge_clusterwide_config_prepare_2pc(...)
            if err ~= nil then
                return nil, err
            end
            -- to create timeout
            require('fiber').sleep(6)
            return ok
        end
    ]])


    local resp = gql_simple_apply_cfg()
    local errors = resp.errors[1]
    t.assert_covers(errors.extensions, {
        ["io.tarantool.errors.class_name"] = 'NetboxCallError'
    })
    t.assert_equals(errors.message, 'Timeout exceeded')

    -- restore old prepare function
    local ok, err = server.net_box:eval([[
        _G.__cartridge_clusterwide_config_prepare_2pc = _G._old__cartridge_clusterwide_config_prepare_2pc
    ]])

    local resp = gql_simple_apply_cfg()
    local errors = resp.errors[1]
    t.assert_covers(errors.extensions, {
        ["io.tarantool.errors.class_name"] = 'Prepare2pcError'
    })
    t.assert_equals(errors.message, 'Two-phase commit is locked')
end
