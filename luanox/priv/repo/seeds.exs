# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     LuaNox.Repo.insert!(%LuaNox.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias LuaNox.RevokedKeys.RevokedKey
alias LuaNox.Packages.Release
alias LuaNox.Accounts.User
alias LuaNox.Repo
alias LuaNox.Packages.Package

Repo.delete_all(RevokedKey)
Repo.delete_all(Release)
Repo.delete_all(Package)
Repo.delete_all(User)

luanox_rockspec = """
rockspec_format = "3.0"
package = "luanox"
version = "1.0.0-1"
source = {
  url = "git+https://github.com/lumen-oss/luanox",
  tag = "v1.0.0"
}
description = {
  summary = "A package manager for Lua",
  detailed = [[
    LuaNox is a modern package manager for Lua, providing a curated
    registry of Lua packages with seamless installation and management.
  ]],
  homepage = "https://github.com/lumen-oss/luanox",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {
    luanox = "src/luanox/init.lua"
  }
}
"""

File.write!(
  Application.app_dir(:luanox, "priv/static/releases/luanox-1.0.0-1.rockspec"),
  luanox_rockspec
)

luarocks_rockspec = """
rockspec_format = "3.0"
package = "luarocks"
version = "0.2.0-1"
source = {
  url = "git+https://github.com/lumen-oss/luarocks",
  tag = "v0.2.0"
}
description = {
  summary = "A package manager for Lua",
  detailed = [[
    LuaRocks is a package manager for the Lua programming language.
    It allows you to install and manage Lua libraries and C modules.
  ]],
  homepage = "https://github.com/lumen-oss/luarocks",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {
    luarocks = "src/luarocks/init.lua"
  }
}
"""

File.write!(
  Application.app_dir(:luanox, "priv/static/releases/luarocks-0.2.0-1.rockspec"),
  luarocks_rockspec
)

user =
  Repo.insert!(%User{
    email: "admin@example.com",
    provider: "github",
    username: "admin",
    aka: "admin"
  })

package =
  Repo.insert!(%Package{
    name: "luanox",
    summary:
      "A particularly long summary for the package to test line clamping in the UI. This summary is intentionally made long so that we can observe how the line clamping behaves in the user interface.",
    description: "Full description of the package",
    user_id: user.id
  })

Repo.insert!(%Release{
  version: "1.0.0",
  rockspec_path: "luanox-1.0.0-1.rockspec",
  package_id: package.id
})

Repo.insert!(%Release{
  version: "1.0.1",
  rockspec_path: "luanox-1.0.0-1.rockspec",
  package_id: package.id
})

# ------------------------------------------------

package2 =
  Repo.insert!(%Package{
    name: "luarocks",
    summary: "The other epic Lua site",
    description: "Full description of the package",
    user_id: user.id
  })

Repo.insert!(%Release{
  version: "0.2.0",
  rockspec_path: "luarocks-0.2.0-1.rockspec",
  package_id: package2.id
})

# ------------------------------------------------

package3 =
  Repo.insert!(%Package{
    name: "sweetie.nvim",
    summary: "Neovim colorscheme",
    description: "A clean, delightful and highly customizable Neovim colorscheme written in Lua",
    user_id: user.id
  })

Repo.insert!(%Release{
  version: "3.2.0",
  rockspec: "<content>",
  package_id: package3.id
})

# ------------------------------------------------

# Add a bunch of filler packages

for i <- 1..25 do
  package4 =
    Repo.insert!(%Package{
      name: "busted-#{i}",
      summary: "Elegant Lua unit testing",
      description: "Full description of the package",
      user_id: user.id
    })

  Repo.insert!(%Release{
    version: "2.#{i}.0",
    rockspec: "<content>",
    package_id: package4.id
  })
end
