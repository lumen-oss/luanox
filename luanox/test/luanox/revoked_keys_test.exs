defmodule LuaNox.RevokedKeysTest do
  use LuaNox.DataCase

  alias LuaNox.RevokedKeys

  describe "is_revoked?/1" do
    test "returns true for a revoked JWT" do
      scope = LuaNox.AccountsFixtures.user_scope_fixture()
      jwt = LuaNox.RevokedKeysFixtures.revoked_key_fixture(scope)

      assert RevokedKeys.is_revoked?(jwt) == true
    end

    test "returns false for a non-revoked JWT" do
      scope = LuaNox.AccountsFixtures.user_scope_fixture()

      {:ok, jwt, _claims} =
        LuaNox.Guardian.encode_and_sign(scope.user, %{
          "allowed_packages" => scope.package_whitelist,
          "write_restriction" => scope.write_restricted
        })

      assert RevokedKeys.is_revoked?(jwt) == false
    end

    test "returns error for invalid JWT" do
      assert {:error, _} = RevokedKeys.is_revoked?("invalid.jwt.token")
    end
  end

  describe "create_revoked_key/2" do
    test "creates a revoked key with valid JWT" do
      scope = LuaNox.AccountsFixtures.user_scope_fixture()

      {:ok, jwt, _claims} =
        LuaNox.Guardian.encode_and_sign(scope.user, %{
          "allowed_packages" => scope.package_whitelist,
          "write_restriction" => scope.write_restricted
        })

      assert {:ok} = RevokedKeys.create_revoked_key(scope, %{revoked_key: jwt})
    end

    test "returns error with invalid JWT" do
      scope = LuaNox.AccountsFixtures.user_scope_fixture()

      assert {:error, %Ecto.Changeset{}} =
               RevokedKeys.create_revoked_key(scope, %{revoked_key: "invalid"})
    end

    test "returns error with insufficient permissions" do
      assert {:error, :insufficient_permissions} =
               RevokedKeys.create_revoked_key(nil, %{revoked_key: "test"})
    end
  end
end
