local zlib = require"zlib"

-- dict used by the SPDY protocol
local spdy_dict = "optionsheadpostputdeletetraceaccept:accept-charset:accept-encoding:accept-language:accept-ranges:age:allow:authorization:cache-control:connection:content-base:content-encoding:content-language:content-length:content-location:content-md5:content-range:content-type:date:etag:expect:expires:from:host:if-match:if-modified-since:if-none-match:if-range:if-unmodified-since:last-modified:location:max-forwards:pragma:proxy-authenticate:proxy-authorization:range:referer:retry-after:server:trailer:transfer-encoding:upgrade:user-agent:vary:via:warning:www-authenticate:methodgetstatus200 OKversionHTTP/1.1urlpublicset-cookie:keep-aliveorigin:100101201202205206300302303304305306307402405406407408409410411412413414415416417502504505203 Non-Authoritative Information204 No Content301 Moved Permanently400 Bad Request401 Unauthorized403 Forbidden404 Not Found500 Internal Server Error501 Not Implemented503 Service UnavailableJan Feb Mar Apr May Jun Jul Aug Sept Oct Nov Dec 00:00:00 Mon, Tue, Wed, Thu, Fri, Sat, Sun, GMTchunked,text/html,image/png,image/jpg,image/gif,application/xml,application/xhtml+xml,text/plain,text/javascript,publicprivatemax-age=gzip,deflate,sdchcharset=utf-8charset=iso-8859-1,utf-,*,enq=0."

local dataToDeflate = {}
print("Generating test data...")
for i = 0, 10000 do
       table.insert(dataToDeflate, string.sub(tostring(math.random()), 3))
end
dataToDeflate = table.concat(dataToDeflate)

print("Length of data to deflate", #dataToDeflate)

local buffer = {}
local func = function(data)
       table.insert(buffer, data)
end

stream = zlib.deflate(func, nil, nil, nil, nil, nil, spdy_dict)     --best compression, deflated
stream:write(dataToDeflate)
--stream:flush("sync")
--stream:flush()
stream:close()

--local deflatedData = string.sub(table.concat(buffer), 3)      -- needed for IE
local deflatedData = table.concat(buffer)
print(#deflatedData)

streamIn = zlib.inflate(deflatedData, nil, spdy_dict)
local inflatedData = streamIn:read()
assert(dataToDeflate == inflatedData,
       table.concat{"inflated data: ", inflatedData, "\n",
                    "deflated_data: ", dataToDeflate, "\n"})
