defmodule LuxpkgsWeb.UserLive.SetupTotp do
  use LuxpkgsWeb, :live_view

  alias Luxpkgs.Accounts
  alias Luxpkgs.Accounts.TOTP

  def mount(_params, session, socket) do
    user =
      cond do
        session["pending_totp_user_id"] ->
          Accounts.get_user(session["pending_totp_user_id"])

        session["user_token"] ->
          case Accounts.get_user_by_session_token(session["user_token"]) do
            {user, _token_inserted_at} -> user
            _ -> nil
          end

        true ->
          nil
      end

    if user do
      if Accounts.User.has_totp?(user) do
        {:ok, redirect(socket, to: ~p"/settings")}
      else
        {secret, secret_base32} = pending_secret(user)

        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:secret_base32, secret_base32)
         |> assign(:uri, TOTP.uri(user, secret))
         |> assign(:page_title, "Set Up Two-Factor Authentication")}
      end
    else
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  defp pending_secret(user) do
    case Cachex.get(:totp_setup, user.id) do
      {:ok, secret_base32} when is_binary(secret_base32) ->
        {Base.decode32!(secret_base32, padding: false), secret_base32}

      _ ->
        secret = NimbleTOTP.secret()
        secret_base32 = Base.encode32(secret, padding: false)
        Cachex.put(:totp_setup, user.id, secret_base32, ttl: :timer.minutes(15))
        {secret, secret_base32}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={nil}>
      <div class="flex min-h-[calc(100vh-116px)] md:min-h-[calc(100vh-124px)] bg-base-200">
        <div class="max-w-md w-full space-y-8 py-16 mx-auto px-6">
          <div class="text-center space-y-4">
            <div class="flex justify-center">
              <div class="bg-primary p-6">
                <.icon name={:shield_check} type={:outline} class="size-8 text-primary-content" />
              </div>
            </div>
            <h1 class="text-2xl font-bold text-base-content">Set Up Two-Factor Authentication</h1>
            <p class="text-sm text-base-content/70">
              Scan the QR code below with your authenticator app (e.g., Google Authenticator, Authy).
            </p>
          </div>

          <div class="bg-base-100 border border-base-300 rounded-box p-6 space-y-6">
            <div class="flex justify-center">
              <div class="bg-white p-4 rounded-box">
                {EQRCode.encode(@uri) |> EQRCode.svg(width: 200) |> raw()}
              </div>
            </div>

            <div>
              <p class="text-xs text-base-content/60 mb-1">Or enter this secret manually:</p>
              <code class="block text-sm font-mono bg-base-200 border border-base-300 px-3 py-2 break-all select-all rounded-box">
                {@secret_base32}
              </code>
            </div>

            <div class="bg-warning/10 border border-warning/30 rounded-box p-3 text-sm text-warning">
              Save this secret in a safe place. You will need it if you lose access to your authenticator app.
            </div>

            <.form for={%{}} action={~p"/setup-totp/complete"} method="post" class="space-y-4">
              <input type="hidden" name="secret" value={@secret_base32} />
              <.input
                name="code"
                value=""
                type="text"
                label="Verification Code"
                placeholder="Enter 6-digit code"
                required
                autocomplete="one-time-code"
                inputmode="numeric"
                pattern="[0-9]*"
                maxlength="6"
              />

              <button type="submit" class="btn btn-primary min-w-full font-semibold">
                <.icon name={:check} type={:outline} class="size-4" /> Verify and Complete Setup
              </button>
            </.form>
          </div>

          <div class="text-center">
            <.link
              navigate={~p"/login"}
              class="link link-hover inline-flex items-center text-sm font-medium"
            >
              <.icon name={:arrow_left} type={:outline} class="size-4 mr-2" />
              Cancel and try a different login method
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
