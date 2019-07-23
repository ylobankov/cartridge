local fio = require('fio')
local t = require('luatest')
local g = t.group('multijoin')

local test_helper = require('test.helper')

local helpers = require('cluster.test_helpers')

local cluster
local servers

g.before_all = function()
    cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = test_helper.server_command,
        replicasets = {
            {
                alias = 'firstling',
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            }
        },
    })

    servers = {}
    for i = 1, 3 do
        local http_port = 8090 + i
        local advertise_port = 13310 + i
        local alias = string.format('i%d', i)

        servers[alias] = helpers.Server:new({
            alias = alias,
            command = test_helper.server_command,
            workdir = fio.pathjoin(cluster.datadir, alias),
            cluster_cookie = cluster.cookie,
            http_port = http_port,
            advertise_port = advertise_port,
            instance_uuid = helpers.uuid('b', 'b', i),
        })
    end

    for _, server in pairs(servers) do
        server:start()
    end
    cluster:start()
end

g.after_all = function()
    for _, server in pairs(servers or {}) do
        server:stop()
    end
    cluster:stop()

    fio.rmtree(cluster.datadir)
    cluster = nil
    servers = nil
end

local query_join = [[
    mutation join_server(
        $uri: String!
        $uuid: String!
        $async: Boolean
        $timeout: Float
    ) {
        join_server(
            uri: $uri
            async: $async
            timeout: $timeout
            instance_uuid: $uuid
        )
    }
]]

local query_status = [[
    query servers_status(
        $uuid: String!
    ) {
        servers(uuid: $uuid) {
            status
        }
    }
]]

g.test_async = function()
    local srv = servers['i1']
    local response = cluster.main_server:graphql({
        query = query_join,
        variables = {
            uri = srv.advertise_uri,
            uuid = srv.instance_uuid,
            async = true,
            timeout = 1,
        }
    })

    t.assertEquals(response.data.join_server, true)

    t.assertEquals(
        cluster.main_server:graphql({
            query = query_status,
            variables = {
                uuid = srv.instance_uuid,
            }
        }).data.servers[1],
        {status = 'unconfigured'}
    )

    cluster:wait_until_healthy()

    t.assertEquals(
        cluster.main_server:graphql({
            query = query_status,
            variables = {
                uuid = srv.instance_uuid,
            }
        }).data.servers[1],
        {status = 'healthy'}
    )
end

g.test_sync_good = function()
    local srv = servers['i2']
    local response = cluster.main_server:graphql({
        query = query_join,
        variables = {
            uri = srv.advertise_uri,
            uuid = srv.instance_uuid,
            async = false,
            timeout = 10,
        }
    })

    t.assertEquals(response.data.join_server, true)

    t.assertEquals(
        cluster.main_server:graphql({
            query = query_status,
            variables = {
                uuid = srv.instance_uuid,
            }
        }).data.servers[1],
        {status = 'healthy'}
    )
end

g.test_sync_timeout = function()
    local srv = servers['i3']
    t.assertErrorMsgContains(
        ('Timeout connecting %q'):format(srv.advertise_uri),

        cluster.main_server.graphql,
        cluster.main_server, {
        query = query_join,
        variables = {
            uri = srv.advertise_uri,
            uuid = srv.instance_uuid,
            async = false,
            timeout = 0.001,
        }
    })

    t.assertEquals(
        cluster.main_server:graphql({
            query = query_status,
            variables = {
                uuid = srv.instance_uuid,
            }
        }).data.servers[1],
        {status = 'unconfigured'}
    )

    cluster:wait_until_healthy()

    t.assertEquals(
        cluster.main_server:graphql({
            query = query_status,
            variables = {
                uuid = srv.instance_uuid,
            }
        }).data.servers[1],
        {status = 'healthy'}
    )
end
