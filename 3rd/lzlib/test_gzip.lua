
local gzip = require 'gzip'

local function line(header, c)
    header = header or ''
    c = c or '-'
    print(string.rep(string.sub(c, 1, 1), 78 - string.len(header))..header)
end


line(' gzip', '=')

line(' gzip writing')
local loops = 1000
local testfile = "test.gz"

local of = gzip.open(testfile, "wb9")

if (not of) then
    error("Failed to open file test.gz for writing")
end

for i = 1, loops do
    of:write(i, "\n")
end

of:close()

local i = 0
for l in gzip.lines(testfile) do
    i = i + 1
    if (tostring(i) ~= l) then
        error(tostring(i))
    end
end

assert(i == loops)
print('Ok.')
line(' gzip reading')

local inf = gzip.open(testfile)

if (not inf) then
    error("Failed to open file test.gz for reading")
end

for i = 1, loops do
    if (tostring(i) ~= inf:read("*l")) then
        error(tostring(i))
    end
end

inf:close()

print('Ok.')
if false then
	line(' compress seek')

	of = gzip.open(testfile, "wb1")

	if (not of) then
		error("Failed to open file test.gz for writing")
	end

	assert(of:seek("cur", 5) == 5)
	assert(of:seek("set", 10) == 10)

	of:write("1")

	of:close()

	print('Ok.')

	line(' uncompress seek')

	inf = gzip.open(testfile)

	if (not inf) then
		error("Failed to open file test.gz for reading")
	end

	assert(inf:seek("set", 6) == 6)
	assert(inf:seek("set", 4) == 4)
	assert(inf:seek("cur", 1) == 5)
	assert(inf:seek("cur", -1) == 4)
	assert(inf:seek("cur", 1) == 5)
	assert(inf:seek("set", 6) == 6)

	inf:read(4)

	assert(inf:read(1) == "1")

	inf:close()

	print('Ok.')

end

os.remove(testfile)

line(' gzip', '=')
