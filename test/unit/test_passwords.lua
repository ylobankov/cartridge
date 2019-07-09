local tap = require("tap")
local test = tap.test("cluster.passwords")
local passwords = require('cluster.passwords')

local check_policy = passwords.check_password_policy


-- TODO: test 
test:plan( --[[ Require know tests number ]] 1 )

--[[
    min_length = '?number',

    alphabet = '?string',

    calculate_entropy = '?function',
    min_entropy = '?number',

    has_lowercase = '?boolean',
    has_uppercase = '?boolean',
    has_numbers = '?boolean',

    special_alphabet = '?string',
    has_special_symbols = '?boolean',
--]]

test:is(check_policy("abcd", {min_length = 4}), nil, 'min lentgh')

test:check()