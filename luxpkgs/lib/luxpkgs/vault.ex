defmodule Luxpkgs.Vault do
  use Cloak.Vault, otp_app: :luxpkgs
end

defmodule Luxpkgs.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: Luxpkgs.Vault
end
