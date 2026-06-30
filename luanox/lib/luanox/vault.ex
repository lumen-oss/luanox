defmodule LuaNox.Vault do
  use Cloak.Vault, otp_app: :luanox
end

defmodule LuaNox.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: LuaNox.Vault
end
