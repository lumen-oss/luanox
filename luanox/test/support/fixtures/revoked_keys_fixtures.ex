defmodule LuaNox.RevokedKeysFixtures do
  def revoked_key_fixture(scope, jwt \\ nil) do
    jwt =
      jwt ||
        case LuaNox.Guardian.encode_and_sign(scope.user, %{
               "allowed_packages" => scope.package_whitelist,
               "write_restriction" => scope.write_restricted
             }) do
          {:ok, jwt, _claims} -> jwt
        end

    {:ok} = LuaNox.RevokedKeys.create_revoked_key(scope, %{revoked_key: jwt})
    jwt
  end
end
