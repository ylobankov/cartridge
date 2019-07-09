#!/usr/bin/env tarantool

local checks = require('checks')
local errors = require('errors')


local e_not_enough_lenght = errors.new_class('Password has not enough lenth')
local e_not_enough_entropy = errors.new_class('Password has not enough entropy')
local e_alphabet_violation = errors.new_class('Password does not included in alphabet*')

local e_no_lowecase = errors.new_class('Password must have at least 1 lowercase letter')
local e_no_uppercase = errors.new_class('Password must have at least 1 uppercase letter')
local e_no_numbers = errors.new_class('Password must have at least 1 number [1-9]')
local e_no_special_symbols = errors.new_class('Password must have at least 1 special symbol')

local e_entopy_calculation_failed = errors.new_class('Entopy calculation failed')


local consts = {
    number_0 = string.byte("0"),
    number_9 = string.byte("9"),
    letter_A = string.byte("A"),
    letter_Z = string.byte("Z"),
    letter_a = string.byte("a"),
    letter_z = string.byte("z"),
}


local function check_alphabet(str, alphabet)
    for i = 1, str:len() do
        if alphabet:find(str:sub(i, i)) == nil then
            return false
        end
    end
    return true
end


local function check_entropy(password, calculate_entropy, min_entropy)
    return e_entopy_calculation_failed:pcall(function() 
        return calculate_entropy(password) >= min_entropy
    end)
end


local function check_symbols(str, predicate, number)
    number = number or 1
    local counter = 0

    for idx = 1, str:len() do
        if predicate(str:byte(idx)) then
            counter = counter + 1
            if counter >= number then
                return true
            end
        end
    end

    return false
end


local function check_password_policy(password, policy)
    checks('string', {
        min_length = '?number',

        alphabet = '?string',

        calculate_entropy = '?function',
        min_entropy = '?number',

        has_lowercase = '?boolean',
        has_uppercase = '?boolean',
        has_numbers = '?boolean',

        special_alphabet = '?string',
        has_special_symbols = '?boolean',
    })

    if policy.min_length ~= nil and password:len() < policy.min_length then
        return e_not_enough_lenght
    end

    if policy.alphabet ~= nil 
    and not check_alphabet(password, policy.alphabet) then
        return e_alphabet_violation
    end

    if policy.calculate_entropy ~= nil 
    and policy.min_entropy ~= nil then 
        local is_enough, err = check_entropy(password, 
            policy.calculate_entropy, policy.min_entropy)
        if err ~= nil then
            return err
        end
        if not is_enough then
            return e_not_enough_entropy
        end
    end

    if policy.has_numbers ~= nil then
        local is_number = function(c) 
            return c >= consts.number_0 and c <= consts.number_9 
        end
        if not check_symbols(password, is_number) then
            return e_no_numbers
        end
    end

    if policy.has_lowercase ~= nil then
        local is_lowercase = function(c) 
            return c >= consts.letter_a and c <= consts.letter_z 
        end
        if not check_symbols(password, is_lowercase) then
            return e_no_lowecase
        end
    end

    if policy.has_uppercase ~= nil then
        local is_uppercase = function(c) 
            return c >= consts.letter_A and c <= consts.letter_Z
        end
        if not check_symbols(password, is_uppercase) then
            return e_no_uppercase
        end
    end

    if policy.has_uppercase ~= nil then
        local is_uppercase = function(c) 
            return c >= consts.letter_A and c <= consts.letter_Z
        end
        if not check_symbols(password, is_uppercase) then
            return e_no_uppercase
        end
    end

    if policy.has_special_symbols ~= nil and policy.special_alphabet ~= nil then
        local is_special_symbols = function(c) 
            return policy.special_alphabet:find(string.char(c)) ~= nil
        end
        if not check_symbols(password, is_uppercase) then
            return e_no_special_symbols
        end
    end

    return nil
end


return {
    check_password_policy = check_password_policy,
}