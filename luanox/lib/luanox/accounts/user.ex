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

  def unique_username(%LuaNox.Accounts.User{} = user), do: user.username

  def oauth_changeset(user, %Auth{} = auth) do
    attrs = %{
      provider: to_string(auth.provider),
      # TODO: Github does this for some reason. We must test if gitlab does this too
      username: auth.info.nickname,
      aka: auth.info.name
    }

    user
    |> email_changeset(%{email: auth.info.email})
    |> cast(attrs, [:provider, :username, :aka])
    |> validate_required([:username])
    |> unique_constraint([:provider, :username])
    |> validate_provider()

    # |> validate_aka()
  end

  defp validate_provider(changeset) do
    changeset
    |> validate_required(:provider)
    |> validate_inclusion(:provider, ["github", "gitlab"])
  end

  defp validate_aka(changeset) do
    changeset =
      changeset
      |> unique_constraint(:aka)
      |> validate_length(:aka, min: 1, max: 20)
      |> validate_format(:aka, ~r/^[a-zA-Z0-9_\-]+$/,
        message: "only allows letters, numbers and underscores"
      )

    username = get_field(changeset, :username)
    aka = get_field(changeset, :aka)

    if username_exists?(username) && is_nil(aka) do
      validate_required(changeset, [:aka])
    else
      changeset
    end
  end

  defp username_exists?(username) do
    !is_nil(LuaNox.Accounts.get_user_by_username(username))
  end

  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
  end
end
