defmodule LuaNox.Guardian do
  alias LuaNox.Accounts.Scope
  alias LuaNox.Accounts.User
  use Guardian, otp_app: :luanox

  def subject_for_token(%User{id: id}, %{
        "allowed_packages" => _,
        "write_restriction" => _
      }) do
    {:ok, to_string(id)}
  end

  def subject_for_token(%User{}, _claims) do
    {:error, :invalid_claims}
  end

  def subject_for_token(_, _) do
    {:error, :expected_user_struct}
  end

  def resource_from_claims(%{
        "sub" => id,
        "allowed_packages" => allowed_packages,
        "write_restriction" => write_restriction
      }) do
    # TODO: Check if the key hasn't been revoked
    case LuaNox.Accounts.get_user(id) do
      %User{} = user ->
        {:ok,
         Scope.for_jwt(%{
           user: user,
           package_whitelist: allowed_packages,
           write_restricted: write_restriction
         })}

      nil ->
        {:error, :user_not_found}
    end
  end

  def resource_from_claims(_claims) do
    {:error, :invalid_token_not_enough_claims}
  end
end
