defmodule LuaNox.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias LuaNox.Repo

  alias LuaNox.Accounts.{User, UserToken}

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
end
