-- Fork from https://github.com/wbond/puremagic
-- puremagic 1.0.1
-- Copyright (c) 2014 Will Bond <will@wbond.net>
-- Licensed under the MIT license.

local ebml_parse_section
local ebml_id_and_length
local ebml_length

local function basename(path)
    local basename_match = path:match('[/\\]([^/\\]+)$')
    if basename_match then
        return basename_match, nil
    end

    return path, nil
end


local function extension(path)
    path = path:lower()
    local tar_match = path:match('%.(tar%.[^.]+)$')
    if tar_match then
        return tar_match
    end
    if path:sub(#path - 11, #path) == '.numbers.zip' then
        return 'numbers.zip'
    end
    if path:sub(#path - 9, #path) == '.pages.zip' then
        return 'pages.zip'
    end
    if path:sub(#path - 7, #path) == '.key.zip' then
        return 'key.zip'
    end
    return path:match('%.([^.]+)$')
end


local function in_table(value, list)
    for i=1, #list do
        if list[i] == value then
            return true
        end
    end
    return false
end


local function string_to_bit_table(chars)
    local output = {}
    for char in chars:gmatch('.') do
        local num = string.byte(char)
        local bits = {0, 0, 0, 0, 0, 0, 0, 0}
        for bit=8, 1, -1 do
            if num > 0 then
                bits[bit] = math.fmod(num, 2)
                num = (num - bits[bit]) / 2
            end
        end
        table.insert(output, bits)
    end
    return output
end


local function bit_table_to_string(bits)
    local output = {}
    for i = 1, #bits do
        local num = tonumber(table.concat(bits[i]), 2)
        table.insert(output, string.format('%c', num))
    end
    return table.concat(output)
end


local function bitwise_and(a, b)
    local a_bytes = string_to_bit_table(a)
    local b_bytes = string_to_bit_table(b)

    local output = {}
    for i = 1, #a_bytes do
        local bits = {0, 0, 0, 0, 0, 0, 0, 0}
        for j = 1, 8 do
            if a_bytes[i][j] == 1 and b_bytes[i][j] == 1 then
                bits[j] = 1
            else
                bits[j] = 0
            end
        end
        table.insert(output, bits)
    end

    return bit_table_to_string(output)
end


-- Unpack a little endian byte string into an integer
local function unpack_le(chars)
    local bit_table = string_to_bit_table(chars)
    -- Merge the bits into a string of 1s and 0s
    local result = {}
    for i=1, #bit_table do
        result[#chars + 1 - i] = table.concat(bit_table[i])
    end
    return tonumber(table.concat(result), 2)
end


-- Unpack a big endian byte string into an integer
local function unpack_be(chars)
    local bit_table = string_to_bit_table(chars)
    -- Merge the bits into a string of 1s and 0s
    for i=1, #bit_table do
        bit_table[i] = table.concat(bit_table[i])
    end
    return tonumber(table.concat(bit_table), 2)
end


-- Takes the first 4-8k of an EBML file and identifies if it is matroska or webm
-- and it it contains just video or just audio.
local function ebml_parse(content)
    local position = 1
    local length = #content

    local header_token, header_value, used_bytes = ebml_parse_section(content)
    position = position + used_bytes


    if header_token ~= '\x1AE\xDF\xA3' then
        return nil, 'Unable to find EBML ID'
    end

    -- The matroska spec sets the default doctype to be 'matroska', however
    -- many file specify this anyway. The other option is 'webm'.
    local doctype = 'matroska'
    if header_value['B\x82'] then
        doctype = header_value['B\x82']
    end

    if doctype ~= 'matroska' and doctype ~= 'webm' then
        return nil, 'Unknown EBML doctype'
    end

    local segment_position = nil
    local track_position
    local has_video = false
    local found_tracks = false

    while position <= length do
        local ebml_id, ebml_value, _used_bytes = ebml_parse_section(content:sub(position, length))
        position = position + _used_bytes

        -- Segment
        if ebml_id == '\x18S\x80g' then
            segment_position = position
        end

        -- Meta seek information
        if ebml_id == '\x11M\x9Bt' then
            -- Look for the seek info about the tracks token
            for _, child in ipairs(ebml_value['M\xBB']) do
                if child['S\xAB'] == '\x16T\xAEk' then
                    track_position = segment_position + unpack_be(child['S\xAC'])
                    position = track_position
                    break
                end
            end
        end

        -- Track
        if ebml_id == '\x16T\xAEk' then
            found_tracks = true
            -- Scan through each track looking for video
            for _, child in ipairs(ebml_value['\xAE']) do
                -- Look to see if the track type is video
                if unpack_be(child['\x83']) == 1 then
                    has_video = true
                    break
                end
            end
            break
        end
    end

    if found_tracks and not has_video then
        if doctype == 'matroska' then
            return 'audio/x-matroska'
        else
            return 'audio/webm'
        end
    end

    if doctype == 'matroska' then
        return 'video/x-matroska'
    else
        return 'video/webm'
    end
end


-- Parses a section of an EBML document, returning the EBML ID at the beginning,
-- plus the value as a table with child EBML IDs as keys and the number of
-- bytes from the content that contained the ID and value
function ebml_parse_section(content)
    local ebml_id, element_length, used_bytes = ebml_id_and_length(content)

    -- Don't parse the segment since it is the whole file!
    if ebml_id == '\x18\x53\x80\x67' then
        return ebml_id, nil, used_bytes
    end

    local ebml_value = content:sub(used_bytes + 1, used_bytes + element_length)
    used_bytes = used_bytes + element_length

    -- We always parse the return value of level 0/1 elements
    local recursive_parse = false
    if #ebml_id == 4 then
        recursive_parse = true

    -- We need Seek information
    elseif ebml_id == '\x4D\xBB' then
        recursive_parse = true

    -- We want the top-level of TrackEntry to grab the TrackType
    elseif ebml_id == '\xAE' then
        recursive_parse = true
    end

    if recursive_parse then
        local buffer = ebml_value
        ebml_value = {}

        -- Track which child entries have been converted to an array
        local array_children = {}

        while #buffer > 0 do
            local child_ebml_id, child_ebml_value, child_used_bytes = ebml_parse_section(buffer)

            if array_children[child_ebml_id] then
                table.insert(ebml_value[child_ebml_id], child_ebml_value)

            -- Single values are just stores by themselves
            elseif ebml_value[child_ebml_id] == nil then
                -- Force seek info and tracks to be arrays even if there is only one
                if child_ebml_id == 'M\xBB' or child_ebml_id == '\xAE' then
                    child_ebml_value = {child_ebml_value}
                    array_children[child_ebml_id] = true
                end
                ebml_value[child_ebml_id] = child_ebml_value

            -- If there is already a value for the ID, turn it into a table
            else
                ebml_value[child_ebml_id] = {ebml_value[child_ebml_id], child_ebml_value}
                array_children[child_ebml_id] = true
            end

            -- Move past the part we've parsed
            buffer = buffer:sub(child_used_bytes + 1, #buffer)
        end
    end

    return ebml_id, ebml_value, used_bytes
end


-- Should accept 12+ bytes, will return the ebml id, the data length and the
-- number of bytes that were used to hold those values.
function ebml_id_and_length(chars)
    -- The ID is encoded the same way as the length, however, we don't want
    -- to remove the length bits from the ID value or intepret it as an
    -- unsigned int since all of the documentation online references the IDs in
    -- encoded form.
    local _, id_length = ebml_length(chars:sub(1, 4))
    local ebml_id = chars:sub(1, id_length)

    local remaining = chars:sub(id_length + 1, id_length + 8)
    local element_length, used_bytes = ebml_length(remaining)

    return ebml_id, element_length, id_length + used_bytes
end


-- Should accept 8+ bytes, will return the data length plus the number of bytes
-- that were used to hold the data length.
function ebml_length(chars)
    -- We substring chars to ensure we don't build a huge table we don't need
    local bit_tables = string_to_bit_table(chars:sub(1, 8))

    local value_length = 1
    for i=1, #bit_tables[1] do
        if bit_tables[1][i] == 0 then
            value_length = value_length + 1
        else
            -- Clear the indicator bit so the rest of the byte
            bit_tables[1][i] = 0
            break
        end
    end

    local bits = {}
    for i=1, value_length do
        table.insert(bits, table.concat(bit_tables[i]))
    end

    return tonumber(table.concat(bits), 2), value_length
end


local function binary_tests(content, ext)
    local length = #content
    local _1_8   = content:sub(1, 8)
    local _1_7   = content:sub(1, 7)
    local _1_6   = content:sub(1, 6)
    local _1_5   = content:sub(1, 5)
    local _1_4   = content:sub(1, 4)
    local _1_3   = content:sub(1, 3)
    local _1_2   = content:sub(1, 2)
    local _9_12  = content:sub(9, 12)


    -- Images
    if _1_4 == '\xC5\xD0\xD3\xC6' then
        -- With a Windows-format EPS, the file starts right after a 30-byte
        -- header, or a 30-byte header followed by two bytes of padding
        if content:sub(33, 42) == '%!PS-Adobe' or content:sub(31, 40) == '%!PS-Adobe' then
            return 'application/postscript'
        end
    end

    if _1_8 == '%!PS-Ado' and content:sub(9, 10) == 'be' then
        return 'application/postscript'
    end

    if _1_4 == 'MM\x00*' or _1_4 == 'II*\x00' then
        return 'image/tiff'
    end

    if _1_8 == '\x89PNG\r\n\x1A\n' then
        return 'image/png'
    end

    if _1_6 == 'GIF87a' or _1_6 == 'GIF89a' then
        return 'image/gif'
    end

    if _1_4 == 'RIFF' and _9_12 == 'WEBP' then
        return 'image/webp'
    end

    if _1_2 == 'BM' and length > 14 and in_table(content:sub(15, 15), {'\x0C', '(', '@', '\x80'}) then
        return 'image/x-ms-bmp'
    end

    local normal_jpeg    = length > 10 and in_table(content:sub(7, 10), {'JFIF', 'Exif'})
    local photoshop_jpeg = length > 24 and _1_4 == '\xFF\xD8\xFF\xED' and content:sub(21, 24) == '8BIM'
    if normal_jpeg or photoshop_jpeg then
        return 'image/jpeg'
    end

    if _1_4 == '8BPS' then
        return 'image/vnd.adobe.photoshop'
    end

    if _1_8 == '\x00\x00\x00\x0CjP  ' and _9_12 == '\r\n\x87\n' then
        return 'image/jp2'
    end

    if _1_4 == '\x00\x00\x01\x00' then
        return 'application/vnd.microsoft.icon'
    end


    -- Audio/Video
    if _1_4 == '\x1AE\xDF\xA3' and length > 1000 then
        local mimetype = ebml_parse(content)

        if mimetype then
            return mimetype
        end
    end

    if _1_4 == 'MOVI' then
        if in_table(content:sub(5, 8), {'moov', 'mdat'}) then
            return 'video/quicktime'
        end
    end

    if length > 8 and content:sub(5, 8) == 'ftyp' then
        local lower_9_12 = _9_12:lower()

        local video_mp4 = {'avc1', 'isom', 'iso2', 'mp41', 'mp42', 'mmp4', 'ndsc', 'ndsh', 'ndsm', 'ndsp',
                           'ndss', 'ndxc', 'ndxh', 'ndxm', 'ndxp', 'ndxs', 'f4v ', 'f4p ', 'm4v '}
        if in_table(lower_9_12, video_mp4) then
            return 'video/mp4'
        end

        if in_table(lower_9_12, {'msnv', 'ndas', 'f4a ', 'f4b ', 'm4a ', 'm4b ', 'm4p '}) then
            return 'audio/mp4'
        end

        if in_table(lower_9_12, {'3g2a', '3g2b', '3g2c', 'kddi'}) then
            return 'video/3gpp2'
        end

        if in_table(lower_9_12, {'3ge6', '3ge7', '3gg6', '3gp1', '3gp2', '3gp3', '3gp4', '3gp5', '3gp6', '3gs7'}) then
            return 'video/3gpp'
        end

        if lower_9_12 == 'mqt ' or lower_9_12 == 'qt  ' then
            return 'video/quicktime'
        end

        if lower_9_12 == 'jp2 ' then
            return 'image/jp2'
        end
    end

    -- MP3
    if bitwise_and(_1_2, '\xFF\xF6') == '\xFF\xF2' then
        local byte_3 = content:sub(3, 3)
        if bitwise_and(byte_3, '\xF0') ~= '\xF0' and bitwise_and(byte_3, "\x0C") ~= "\x0C" then
            return 'audio/mpeg'
        end
    end
    if _1_3 == 'ID3' then
        return 'audio/mpeg'
    end

    if _1_4 == 'fLaC' then
        return 'audio/x-flac'
    end

    if _1_8 == '0&\xB2u\x8Ef\xCF\x11' then
        -- Without writing a full-on ASF parser, we can just scan for the
        -- UTF-16 string "AspectRatio"
        if content:find('\x00A\x00s\x00p\x00e\x00c\x00t\x00R\x00a\x00t\x00i\x00o', 1, true) then
            return 'video/x-ms-wmv'
        end
        return 'audio/x-ms-wma'
    end

    if _1_4 == 'RIFF' and _9_12 == 'AVI ' then
        return 'video/x-msvideo'
    end

    if _1_4 == 'RIFF' and _9_12 == 'WAVE' then
        return 'audio/x-wav'
    end

    if _1_4 == 'FORM' and _9_12 == 'AIFF' then
        return 'audio/x-aiff'
    end

    if _1_4 == 'OggS' then
        local _29_33 = content:sub(29, 33)
        if _29_33 == '\x01vorb' then
            return 'audio/vorbis'
        end
        if _29_33 == '\x07FLAC' then
            return 'audio/x-flac'
        end
        if _29_33 == 'OpusH' then
            return 'audio/ogg'
        end
        -- Theora and OGM
        if _29_33 == '\x80theo' or _29_33 == 'vide' then
            return 'video/ogg'
        end
    end

    if _1_3 == 'FWS' or _1_3 == 'CWS' then
        return 'application/x-shockwave-flash'
    end

    if _1_3 == 'FLV' then
        return 'video/x-flv'
    end


    if _1_5 == '%PDF-' then
        return 'application/pdf'
    end

    if _1_5 == '{\\rtf' then
        return 'text/rtf'
    end


    -- Office '97-2003 formats
    if _1_8 == '\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1' then
        if in_table(ext, {'xls', 'csv', 'tab'}) then
            return 'application/vnd.ms-excel'
        end
        if ext == 'ppt' then
            return 'application/vnd.ms-powerpoint'
        end
        -- We default to word since we need something if the extension isn't recognized
        return 'application/msword'
    end

    if _1_8 == '\x09\x04\x06\x00\x00\x00\x10\x00' then
        return 'application/vnd.ms-excel'
    end

    if _1_6 == '\xDB\xA5\x2D\x00\x00\x00'
        or _1_5 == '\x50\x4F\x5E\x51\x60'
        or _1_4 == '\xFE\x37\x00\x23'
        or _1_3 == '\x94\xA6\x2E' then
        return 'application/msword'
    end

    if _1_4 == 'PK\x03\x04' then
        -- Office XML formats
        if ext == 'xlsx' then
            return 'application/vnd.ms-excel'
        end

        if ext == 'pptx' then
            return 'application/vnd.ms-powerpoint'
        end

        if ext == 'docx' then
            return 'application/msword'
        end

        -- Open Office formats
        if ext == 'ods' then
            return 'application/vnd.oasis.opendocument.spreadsheet'
        end

        if ext == 'odp' then
            return 'application/vnd.oasis.opendocument.presentation'
        end

        if ext == 'odt' then
            return 'application/vnd.oasis.opendocument.text'
        end

        -- iWork - some programs like Mac Mail change the filename to
        -- .numbers.zip, etc
        if ext == 'pages' or ext == 'pages.zip' then
          return 'application/vnd.apple.pages'
        end
        if ext == 'key' or ext == 'key.zip' then
            return 'application/vnd.apple.keynote'
        end
        if ext == 'numbers' or ext == 'numbers.zip' then
            return 'application/vnd.apple.numbers'
        end

        -- Otherwise just a zip
        return 'application/zip'
    end


    -- Archives
    if length > 257 then
        if content:sub(258, 263) == 'ustar\x00' then
            return 'application/x-tar'
        end
        if content:sub(258, 265) == 'ustar\x40\x40\x00' then
            return 'application/x-tar'
        end
    end

    if _1_7 == 'Rar!\x1A\x07\x00' or _1_8 == 'Rar!\x1A\x07\x01\x00' then
        return 'application/x-rar-compressed'
    end

    if _1_2 == '\x1F\x9D' then
        return 'application/x-compress'
    end

    if _1_2 == '\x1F\x8B' then
        return 'application/x-gzip'
    end

    if _1_3 == 'BZh' then
        return 'application/x-bzip2'
    end

    if _1_6 == '\xFD7zXZ\x00' then
        return 'application/x-xz'
    end

    if _1_6 == '7z\xBC\xAF\x27\x1C' then
        return 'application/x-7z-compressed'
    end

    if _1_2 == 'MZ' then
        local pe_header_start = unpack_le(content:sub(61, 64))
        local signature = content:sub(pe_header_start + 1, pe_header_start + 4)

        if signature == 'PE\x00\x00' then
            local image_file_header_start = pe_header_start + 5
            local characteristics = content:sub(image_file_header_start + 18, image_file_header_start + 19)
            local is_dll = bitwise_and(characteristics, '\x20\x00') == '\x20\x00'

            if is_dll then
                return 'application/x-msdownload'
            end

            return 'application/octet-stream'
        end
    end

    return nil
end


local function text_tests(content)
    local lower_content = content:lower()

    if content:find('^%%!PS-Adobe') then
        return 'application/postscript'
    end

    if lower_content:find('<?php', 1, true) or content:find('<?=', 1, true) then
        return 'application/x-httpd-php'
    end

    if lower_content:find('^%s*<%?xml') then
        if content:find('<svg') then
            return 'image/svg+xml'
        end
        if lower_content:find('<!doctype html') then
            return 'application/xhtml+xml'
        end
        if content:find('<rss') then
            return 'application/rss+xml'
        end
        return 'application/xml'
    end

    if lower_content:find('^%s*<html') or lower_content:find('^%s*<!doctype') then
        return 'text/html'
    end

    if lower_content:find('^#![/a-z0-9]+ ?python') then
        return 'application/x-python'
    end

    if lower_content:find('^#![/a-z0-9]+ ?perl') then
        return 'application/x-perl'
    end

    if lower_content:find('^#![/a-z0-9]+ ?ruby') then
        return 'application/x-ruby'
    end

    if lower_content:find('^#![/a-z0-9]+ ?php') then
        return 'application/x-httpd-php'
    end

    if lower_content:find('^#![/a-z0-9]+ ?bash') then
        return 'text/x-shellscript'
    end

    return nil
end


local ext_map = {
    css   = 'text/css',
    csv   = 'text/csv',
    htm   = 'text/html',
    html  = 'text/html',
    xhtml = 'text/html',
    ics   = 'text/calendar',
    js    = 'application/javascript',
    php   = 'application/x-httpd-php',
    php3  = 'application/x-httpd-php',
    php4  = 'application/x-httpd-php',
    php5  = 'application/x-httpd-php',
    inc   = 'application/x-httpd-php',
    pl    = 'application/x-perl',
    cgi   = 'application/x-perl',
    py    = 'application/x-python',
    rb    = 'application/x-ruby',
    rhtml = 'application/x-ruby',
    rss   = 'application/rss+xml',
    sh    = 'text/x-shellscript',
    tab   = 'text/tab-separated-values',
    vcf   = 'text/x-vcard',
    xml   = 'application/xml'
}

local function ext_tests(ext)
    local mimetype = ext_map[ext]
    if mimetype then
        return mimetype
    end
    return 'text/plain'
end


local _M = {}


function _M.via_path(path, filename)
    local f, err = io.open(path, 'r')
    if not f then
        return nil, err
    end

    local content = f:read(4096)
    f:close()

    if not filename then
        filename = basename(path)
    end

    return _M.via_content(content, filename)
end


function _M.via_content(content, filename)
    local ext = extension(filename)

    -- If there are no low ASCII chars and no easily distinguishable tokens,
    -- we need to detect by file extension

    local mimetype = binary_tests(content, ext)
    if mimetype then
        return mimetype
    end

    -- Binary-looking files should have been detected so far
    if content:find('[%z\x01-\x08\x0B\x0C\x0E-\x1F]') then
        return 'application/octet-stream'
    end

    mimetype = text_tests(content)
    if mimetype then
        return mimetype
    end

    return ext_tests(ext)
end

return _M
