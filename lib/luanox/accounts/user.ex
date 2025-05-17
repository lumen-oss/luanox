defmodule LuaNox.Accounts.User do
  alias Ueberauth.Auth
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    # Used to uniquely identify the user in the database
    field :provider, :string
    field :username, :string
    field :aka, :string

    timestamps(type: :utc_datetime)
  end

  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  def oauth_changeset(user, %Auth{} = auth) do
    if !Auth.valid?(auth) do
      add_error(user, :ueberauth, "invalid auth")
      user
    else
      attrs = %{
        provider: auth.provider,
        username: auth.info.name,
        aka: auth.info.nickname
      }

      user
      |> email_changeset(%{email: auth.info.email}, validate_email: true)
      |> cast(attrs, [:provider, :username, :aka])
      |> unique_constraint([:provider, :username])
      |> validate_provider()
      |> validate_aka()
    end
  end

  defp validate_provider(changeset) do
    changeset
    |> validate_required([:provider])
    |> validate_subset(:provider, ["github", "gitlab"])
  end

  defp validate_aka(changeset) do
    changeset =
      changeset
      |> validate_length(:aka, min: 1, max: 20)
      |> validate_format(:aka, ~r/^[a-zA-Z0-9_\-]+$/,
        message: "only allows letters, numbers and underscores"
      )

    username = changeset |> get_field(:username)
    aka = changeset |> get_field(:aka)

    if username_exists?(username) && is_nil(aka) do
      changeset
      |> validate_required([:aka])
    else
      changeset
    end
  end

  defp username_exists?(username) do
    !is_nil(LuaNox.Accounts.get_user_by_username(username))
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, LuaNox.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end
end
