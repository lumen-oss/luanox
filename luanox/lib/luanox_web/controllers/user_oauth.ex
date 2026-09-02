defmodule LuaNoxWeb.UserOauth do
  use LuaNoxWeb, :controller

  plug(Ueberauth)

  require Logger

  def callback(%{assigns: %{ueberauth_failure: %Ueberauth.Failure{}}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate")
    |> redirect(to: ~p"/")
  end

  def callback(%{assigns: %{ueberauth_auth: %Ueberauth.Auth{} = auth}} = conn, _params) do
    case LuaNox.Accounts.get_user_by_auth(auth) do
      %LuaNox.Accounts.User{} = user ->
        user = refresh_avatar(user, auth.info.image)

        conn
        |> LuaNoxWeb.UserAuth.log_in_user(user)

      nil when is_nil(auth.info.email) ->
        auth_stripped = %{
          provider: auth.provider,
          info: %{
            nickname: auth.info.nickname,
            name: auth.info.name,
            email: auth.info.email,
            image: auth.info.image
          }
        }

        conn
        |> put_session(:oauth_signup_token, auth_stripped)
        |> redirect(to: ~p"/provide-email")

      nil ->
        # User doesn't exist but has email from OAuth, create the user
        case LuaNox.Accounts.register_user(auth) do
          {:ok, user} ->
            conn
            |> put_flash(:info, "Account created successfully.")
            |> LuaNoxWeb.UserAuth.log_in_user(user)

          {:error, changeset} ->
            Logger.error("Failed to create user from OAuth, see changeset:")
            Logger.error(inspect(changeset))

            conn
            |> put_flash(:error, "Authentication succeeded, but failed to create user.")
            |> redirect(to: ~p"/")
        end
    end
  end

  def complete_signup(conn, %{"user" => %{"email" => email}, "token" => token}) do
    auth = get_session(conn, :oauth_signup_token)

    # The email has already been set and the user has navigated to the page in an unnatural way
    if not is_nil(auth.info.email) do
      conn
      |> put_flash(
        :error,
        "Unable to modify account with public email. Please try authenticating again."
      )
      |> redirect(to: ~p"/login")
    else
      ueberauth = %Ueberauth.Auth{
        provider: auth.provider,
        info: %Ueberauth.Auth.Info{
          nickname: auth.info.nickname,
          name: auth.info.name,
          email: email,
          image: auth.info.image
        }
      }

      case LuaNox.Accounts.register_user(ueberauth) do
        {:ok, user} ->
          conn
          |> put_flash(:info, "Account created successfully.")
          |> LuaNoxWeb.UserAuth.log_in_user(user)

        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Failed to create account. Please check your email.")
          |> redirect(to: ~p"/provide-email")
      end
    end
  end

  def complete_signup(conn, _params) do
    conn
    |> put_flash(:error, "Missing required parameters. Please try authenticating again.")
    |> redirect(to: ~p"/login")
  end

  defp refresh_avatar(user, image) when is_binary(image) do
    case LuaNox.Accounts.update_user_avatar(user, image) do
      {:ok, user} -> user
      {:error, _changeset} -> user
    end
  end

  defp refresh_avatar(user, _image), do: user
end