local log = require('log')
local json = require('json').new()

json.cfg({
    encode_use_tostring = true,
})

local function http_finalize_error(http_code, err)
    log.error(tostring(err))
    return {
        status = http_code,
        headers = {
            ['content-type'] = "application/json",
        },
        body = json.encode(err),
    }
end

local function read_request_body(req)
    local req_body = req:read()
    local content_type = req.headers['content-type'] or ''
    local multipart, boundary = content_type:match('(multipart/form%-data); boundary=(.+)')
    if multipart == 'multipart/form-data' then
        -- RFC 2046 http://www.ietf.org/rfc/rfc2046.txt
        -- 5.1.1.  Common Syntax
        -- The boundary delimiter line is then defined as a line
        -- consisting entirely of two hyphen characters ("-", decimal value 45)
        -- followed by the boundary parameter value from the Content-Type header
        -- field, optional linear whitespace, and a terminating CRLF.
        --
        -- string.match takes a pattern, thus we have to prefix any characters
        -- that have a special meaning with % to escape them.
        -- A list of special characters is ().+-*?[]^$%
        local boundary_line = string.gsub('--'..boundary, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
        local _, form_body = req_body:match(
            boundary_line .. '\r\n' ..
                '(.-\r\n)' .. '\r\n' .. -- headers
                '(.-)' .. '\r\n' .. -- body
                boundary_line
        )
        req_body = form_body
    end
    return req_body
end

return {
    http_finalize_error = http_finalize_error,
    read_request_body = read_request_body,
}
