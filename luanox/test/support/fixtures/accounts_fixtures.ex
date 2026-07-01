defmodule LuaNox.AccountsFixtures do
  import Ecto.Query
  alias LuaNox.Accounts
  alias LuaNox.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"
  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{email: unique_user_email()})
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    email = attrs[:email] || unique_user_email()
    unique = System.unique_integer([:positive])

    user =
      %LuaNox.Accounts.User{}
      |> LuaNox.Accounts.User.email_changeset(%{email: email})
      |> Ecto.Changeset.change(%{
        provider: "github",
        username: "unconfirmed_#{unique}",
        aka: "User #{unique}"
      })
      |> LuaNox.Repo.insert!()

    Map.merge(user, Map.drop(attrs, [:email]))
  end

  def user_fixture(attrs \\ %{}) do
    email = attrs[:email] || unique_user_email()
    unique = System.unique_integer([:positive])

    user =
      %LuaNox.Accounts.User{}
      |> LuaNox.Accounts.User.email_changeset(%{email: email})
      |> Ecto.Changeset.change(%{
        confirmed_at: DateTime.utc_now(:second),
        provider: "github",
        username: "user_#{unique}",
        aka: "User #{unique}"
      })
      |> LuaNox.Repo.insert!()

    Map.merge(user, Map.drop(attrs, [:email]))
  end

  def user_scope_fixture, do: Scope.for_user(user_fixture())
  def user_scope_fixture(user), do: Scope.for_user(user)

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    LuaNox.Repo.update_all(
      from(t in Accounts.UserToken, where: t.token == ^token),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    LuaNox.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)
    LuaNox.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
