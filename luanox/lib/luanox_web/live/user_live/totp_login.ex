defmodule LuaNoxWeb.UserLive.TotpLogin do
  use LuaNoxWeb, :live_view

  def mount(_params, session, socket) do
    user_id = session["pending_2fa_user_id"]

    if is_nil(user_id) do
      {:ok, socket |> redirect(to: ~p"/login")}
    else
      {:ok,
       socket
       |> assign(:user_id, user_id)
       |> assign(:page_title, "Two-Factor Authentication")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex-1 flex items-center">
        <div class="max-w-sm w-full space-y-4 py-8 mx-auto">
          <div class="flex justify-center">
            <div class="bg-primary p-6 rounded-box">
              <.icon name={:shield} type={:outline} class="size-8 text-primary-content" />
            </div>
          </div>

          <.header class="text-center">
            <h1 class="text-2xl font-bold text-base-content">Two-Factor Authentication</h1>
            <:subtitle>
              <div class="mt-4 text-base text-base-content/70">
                Enter the 6-digit code from your authenticator app,
                <br />or a recovery code.
              </div>
            </:subtitle>
          </.header>

          <div class="bg-base-200 border border-base-300 rounded-box p-8">
            <.form
              for={%{}}
              id="totp_form"
              action={~p"/login/totp"}
              method="post"
              class="flex flex-col gap-6"
            >
              <input type="hidden" name="user_id" value={@user_id} />
              <input
                type="text"
                name="code"
                inputmode="numeric"
                autocomplete="one-time-code"
                placeholder="6-digit code"
                required
                class="input input-bordered w-full text-center font-mono tracking-widest bg-base-100"
              />
              <button type="submit" class="btn btn-primary min-w-full font-semibold">
                <.icon name={:lock} type={:outline} class="size-4" /> Verify
              </button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
