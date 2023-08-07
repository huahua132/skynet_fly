package = "luajwtjitsi"
version = "3.0-0"

source = {
	url = "git://github.com/jitsi/luajwtjitsi/",
	tag = "v3.0",
}

description = {
	summary = "JSON Web Tokens for Lua",
	detailed = "Very fast and compatible with pyjwt, php-jwt, ruby-jwt, node-jwt-simple and others",
	homepage = "https://github.com/jitsi/luajwtjitsi/",
	license = "MIT <http://opensource.org/licenses/MIT>"
}

dependencies = {
	"lua >= 5.1",
	"luaossl >= 20190731-0",
	"lua-cjson == 2.1.0-1",
	"basexx >= 0.4.1-1"
}

build = {
	type = "builtin",
	modules = {
		luajwtjitsi = "luajwtjitsi.lua"
	},
	copy_directories = {
		"test"
	}
}
