defmodule LuaNox.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias LuaNox.Repo

  alias LuaNox.Accounts.{User, UserRecoveryCode, UserToken}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  def get_user_by_auth(%Ueberauth.Auth{} = auth) do
    # First, try to find user by provider + username
    # This handles cases where GitHub users don't have public emails
    provider = to_string(auth.provider)

    # Goddamn GitHub naming conventions calling the account name "nickname", and the account nickname "name".
    # NOTE: this might need refactoring later once we add support for more providers.
    username = auth.info.nickname

    case Repo.get_by(User, provider: provider, username: username) do
      %User{} = user ->
        user

      nil ->
        # Fallback to email-based lookup for legacy compatibility
        # NOTE: I'm unsure whether we should keep this fallback or not, but it's here for now.
        if auth.info.email do
          get_user_by_email(auth.info.email)
        else
          nil
        end
    end
  end

  def user_count do
    Repo.one(from(u in User, select: count(u.id)))
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

  ## User registration

  @doc """
  Registers a user from a successful oauth login.

  ## Examples

      iex> register_user(%Ueberauth.Auth{} = auth)
      {:ok, %User{}}
  """
  def register_user(%Ueberauth.Auth{} = auth) do
    %User{}
    |> User.oauth_changeset(auth)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Updates the user's avatar URL, e.g. from a fresh OAuth login.
  """
  def update_user_avatar(%User{} = user, avatar_url) when is_binary(avatar_url) do
    user
    |> Ecto.Changeset.change(%{avatar_url: avatar_url})
    |> User.validate_avatar_url()
    |> Repo.update()
  end

  def update_bio(%User{} = user, bio) do
    user
    |> User.bio_changeset(bio)
    |> Repo.update()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

## Two-factor authentication

  @doc """
  Returns true if the user has TOTP two-factor authentication enabled.
  """
  def totp_enabled?(%User{} = user), do: is_binary(user.totp_secret)

  @doc """
  Generates a new TOTP secret.
  """
  def generate_totp_secret, do: NimbleTOTP.secret() |> Base.encode32(padding: false)

  @doc """
  Enables TOTP for the user after verifying the given code against the secret.

  Returns `{:ok, user}` on success or `{:error, :invalid_code}` when the
  verification code does not match.
  """
  def enable_totp(%User{} = user, secret, code) when is_binary(code) do
    if NimbleTOTP.valid?(Base.decode32!(secret), code) do
      user
      |> Ecto.Changeset.change(%{totp_secret: secret})
      |> Repo.update()
    else
      {:error, :invalid_code}
    end
  end

  @doc """
  Disables TOTP for the user after verifying a valid code.

  Also deletes all recovery codes.
  """
  def disable_totp(%User{} = user, code) when is_binary(code) do
    if verify_totp(user, code) do
      user
      |> Ecto.Changeset.change(%{totp_secret: nil})
      |> Repo.update()
      |> case do
        {:ok, user} ->
          Repo.delete_all(
            from(rc in UserRecoveryCode, where: rc.user_id == ^user.id)
          )

          {:ok, user}

        error ->
          error
      end
    else
      {:error, :invalid_code}
    end
  end

  @doc """
  Verifies a TOTP code against the user's secret.

  Returns false when the user does not have TOTP enabled.
  """
  def verify_totp(%User{} = user, code) when is_binary(code) do
    secret = Base.decode32!(user.totp_secret)
    time = System.os_time(:second)

    totp_enabled?(user) &&
      (NimbleTOTP.valid?(secret, code, time: time) or
         NimbleTOTP.valid?(secret, code, time: time - 30))
  end

  def verify_totp(_user, _code), do: false

  @doc """
  Generates 10 new single-use recovery codes for the user.

  The plaintext codes are returned exactly once and must be shown to the
  user. Only their hashes are stored.
  """
  def generate_recovery_codes(%User{} = user) do
    Repo.delete_all(from rc in UserRecoveryCode, where: rc.user_id == ^user.id)

    codes = Enum.map(1..10, fn _ -> :crypto.strong_rand_bytes(12) |> Base.encode32(padding: false) end)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.insert_all(UserRecoveryCode, Enum.map(codes, fn code ->
      %{
        user_id: user.id,
        code_hash: Argon2.hash_pwd_salt(code),
        inserted_at: now,
        updated_at: now
      }
    end))

    codes
  end

  @doc """
  Verifies a single-use recovery code, marking it as used on success.
  """
  def verify_recovery_code(%User{} = user, code) when is_binary(code) do
    user = Repo.preload(user, :recovery_codes)

    case Enum.find(user.recovery_codes, &(is_nil(&1.used_at) && Argon2.verify_pass(code, &1.code_hash))) do
      %UserRecoveryCode{} = recovery_code ->
        {:ok,
         recovery_code
         |> Ecto.Changeset.change(%{used_at: DateTime.utc_now() |> DateTime.truncate(:second)})
         |> Repo.update()}

      _ ->
        {:error, :invalid_code}
    end
  end

  @doc """
  Verifies either a TOTP or a recovery code for the user.

  Returns `{:ok, user}` on success or `{:error, :invalid_code}`.
  """
  def verify_2fa(%User{} = user, code) when is_binary(code) do
    cond do
      verify_totp(user, code) ->
        {:ok, user}

      match?({:ok, _}, verify_recovery_code(user, code)) ->
        {:ok, user}

      true ->
        {:error, :invalid_code}
    end
  end

  def verify_2fa(_user, _code), do: {:error, :invalid_code}
end
