local package_name = "radix-router"
local package_version = "dev"
local rockspec_revision = "1"
local github_account_name = "vm-001"
local github_repo_name = "lua-radix-router"
local git_checkout = package_version == "dev" and "main" or ("version_"..package_version)

package = package_name
version = package_version .. "-" .. rockspec_revision

source = {
  url = "git+https://github.com/"..github_account_name.."/"..github_repo_name..".git",
  branch = git_checkout
}

description = {
  summary = "radix-router",
  detailed = [[
  ]],
  license = "MIT",
  homepage = "https://github.com/"..github_account_name.."/"..github_repo_name,
}

dependencies = {
  "lua >= 5.1, < 5.5"
}

build = {
  type = "builtin",
  modules = {
    ["radix-router"] = "src/router.lua",
    ["radix-router.options"] = "src/options.lua",
    ["radix-router.route"] = "src/route.lua",
    ["radix-router.trie"] = "src/trie.lua",
    ["radix-router.utils"] = "src/utils.lua",
    ["radix-router.constants"] = "src/constants.lua",
    ["radix-router.iterator"] = "src/iterator.lua",
    ["radix-router.parser"] = "src/parser/parser.lua",
    ["radix-router.parser.style.default"] = "src/parser/style/default.lua",
    ["radix-router.matcher"] = "src/matcher/matcher.lua",
    ["radix-router.matcher.host"] = "src/matcher/host.lua",
    ["radix-router.matcher.method"] = "src/matcher/method.lua",
  },
}
