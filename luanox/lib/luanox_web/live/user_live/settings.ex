defmodule LuaNoxWeb.UserLive.Settings do
  use LuaNoxWeb, :live_view

  on_mount({LuaNoxWeb.UserAuth, :require_sudo_mode})

  def mount(_params, _session, socket) do
    bio_count = (socket.assigns.current_scope.user.bio || "") |> String.length()

    {:ok,
     socket
     |> assign(:email_form, nil)
     |> assign(:username_form, nil)
     |> assign(:bio_count, bio_count)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="bg-base-100 border-b border-base-300">
        <div class="page-container max-w-5xl py-4 lg:py-6">
          <div class="flex items-center gap-3">
            <div class="w-16 h-16 sm:w-20 sm:h-20 bg-primary/10 border-2 border-primary/20 rounded-full flex items-center justify-center shrink-0">
              <.icon name={:user} type={:outline} class="w-10 h-10 sm:w-12 sm:h-12 text-primary" />
            </div>
            <div>
              <h1 class="text-2xl sm:text-3xl lg:text-4xl font-semibold text-base-content">Settings</h1>
              <p class="text-sm sm:text-base text-base-content/70">
                Manage your profile and account preferences
              </p>
            </div>
          </div>
        </div>
      </div>

      <div class="page-container max-w-5xl py-6 lg:py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Profile Card --%>
          <div class="lg:col-span-1">
            <div class="bg-base-200 border border-base-300 rounded-box p-6 sticky top-6">
              <div class="text-center">
                <%= if @current_scope.user.avatar_url do %>
                  <div class="avatar mb-4">
                    <div class="w-20 rounded-full">
                      <img src={@current_scope.user.avatar_url} alt={@current_scope.user.username} />
                    </div>
                  </div>
                <% else %>
                  <div class="avatar avatar-placeholder mb-4">
                    <div class="w-20 bg-primary/10 border-2 border-primary/20 rounded-full">
                      <span class="text-3xl font-bold text-primary">
                        {String.first(@current_scope.user.username)}
                      </span>
                    </div>
                  </div>
                <% end %>
                <h3 class="text-lg font-semibold text-base-content mb-1">
                  {@current_scope.user.username}
                </h3>
                <p class="text-sm text-base-content/70 mb-4">
                  {@current_scope.user.email}
                </p>
                <%= if @current_scope.user.bio do %>
                  <p class="text-sm text-base-content/80 mb-4">
                    {@current_scope.user.bio}
                  </p>
                <% end %>
              </div>

              <div class="border-t border-base-300 pt-4 space-y-3">
                <div class="flex justify-between items-center">
                  <span class="text-sm text-base-content/70">Member since</span>
                  <span class="text-sm font-medium">{member_since_date(
                    @current_scope.user.inserted_at
                  )}</span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-sm text-base-content/70">Auth provider</span>
                  <span class="text-sm font-medium text-primary">GitHub</span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-sm text-base-content/70">Account type</span>
                  <span class="text-sm font-medium text-secondary">Standard</span>
                </div>
              </div>
            </div>
          </div>

          <%!-- Settings Sections --%>
          <div class="lg:col-span-2 space-y-4">
            <%!-- Account Section --%>
            <div class="collapse collapse-arrow bg-base-200 border border-base-300">
              <input type="checkbox" checked />
              <div class="collapse-title flex items-center gap-3 px-4 sm:px-6">
                <.icon name={:user_circle} type={:outline} class="w-5 h-5 text-primary" />
                <div>
                  <h2 class="font-semibold text-base-content">Account</h2>
                  <p class="text-sm text-base-content/70">Personal information</p>
                </div>
              </div>
              <div class="collapse-content px-4 sm:px-6">
                <div class="space-y-6 pt-2">
                  <%!-- Bio Form --%>
                  <div>
                    <div class="flex items-center justify-between mb-2">
                      <label class="text-sm font-medium text-base-content/80 block">Bio</label>
                      <span
                        id="bio-count"
                        class="text-xs text-base-content/50 transition-colors duration-150"
                      >
                        {@bio_count}/160
                      </span>
                    </div>
                    <.form
                      for={%{}}
                      id="bio_form"
                      phx-submit="update_bio"
                      class="space-y-3"
                    >
                      <textarea
                        id="bio-input"
                        name="user[bio]"
                        rows="3"
                        maxlength="160"
                        phx-hook="CharacterCounter"
                        data-counter-target="bio-count"
                        data-counter-max="160"
                        placeholder="Tell people about yourself (max 160 characters)"
                        class="textarea textarea-bordered w-full"
                      >{@current_scope.user.bio}</textarea>
                      <button
                        type="submit"
                        class="btn btn-primary btn-sm w-full sm:w-auto"
                        phx-disable-with="Updating..."
                      >
                        <.icon name={:check} type={:outline} class="w-4 h-4" /> Save Changes
                      </button>
                    </.form>
                  </div>

                  <%!-- Email Form --%>
                  <div>
                    <label class="text-sm font-medium text-base-content/80 mb-2 block">
                      Email Address
                    </label>
                    <.form
                      for={@email_form}
                      id="email_form"
                      phx-submit="update_email"
                      class="space-y-3"
                    >
                      <input
                        type="email"
                        name="user-email"
                        placeholder={@current_scope.user.email}
                        class="input input-bordered w-full"
                        autocomplete="email"
                        required
                      />
                      <button
                        type="submit"
                        class="btn btn-primary btn-sm w-full sm:w-auto"
                        phx-disable-with="Updating..."
                      >
                        <.icon name={:check} type={:outline} class="w-4 h-4" /> Save Changes
                      </button>
                    </.form>
                  </div>

                  <%!-- Username Form --%>
                  <div>
                    <label class="text-sm font-medium text-base-content/80 mb-2 block">
                      Username
                    </label>
                    <.form
                      for={@username_form}
                      id="username_form"
                      phx-submit="update_username"
                      class="space-y-3"
                    >
                      <input
                        type="text"
                        name="user-name"
                        placeholder={@current_scope.user.username}
                        class="input input-bordered w-full"
                        autocomplete="username"
                        required
                      />
                      <button
                        type="submit"
                        class="btn btn-primary btn-sm w-full sm:w-auto"
                        phx-disable-with="Updating..."
                      >
                        <.icon name={:check} type={:outline} class="w-4 h-4" /> Save Changes
                      </button>
                    </.form>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Notifications Section --%>
            <div class="collapse collapse-arrow bg-base-200 border border-base-300">
              <input type="checkbox" />
              <div class="collapse-title flex items-center gap-3 px-4 sm:px-6">
                <.icon name={:bell} type={:outline} class="w-5 h-5 text-primary" />
                <div>
                  <h2 class="font-semibold text-base-content">Notifications</h2>
                  <p class="text-sm text-base-content/70">Email and push preferences</p>
                </div>
              </div>
              <div class="collapse-content px-4 sm:px-6">
                <div class="space-y-6 pt-2">
                  <div class="flex items-center justify-between py-2">
                    <div>
                      <p class="text-sm font-medium text-base-content">Email Notifications</p>
                      <p class="text-xs text-base-content/70">Receive updates about your packages</p>
                    </div>
                    <input type="checkbox" class="toggle toggle-primary" checked />
                  </div>
                  <div class="flex items-center justify-between py-2">
                    <div>
                      <p class="text-sm font-medium text-base-content">Package Updates</p>
                      <p class="text-xs text-base-content/70">Get notified about new releases</p>
                    </div>
                    <input type="checkbox" class="toggle toggle-primary" checked />
                  </div>
                </div>
              </div>
            </div>

            <%!-- Advanced Section --%>
            <div class="collapse collapse-arrow bg-base-200 border border-base-300">
              <input type="checkbox" />
              <div class="collapse-title flex items-center gap-3 px-4 sm:px-6">
                <.icon name={:settings} type={:outline} class="w-5 h-5 text-primary" />
                <div>
                  <h2 class="font-semibold text-base-content">Advanced Settings</h2>
                  <p class="text-sm text-base-content/70">Account management</p>
                </div>
              </div>
              <div class="collapse-content px-4 sm:px-6">
                <div class="space-y-6 pt-2">
                  <div class="bg-base-100 border border-base-300 rounded-md p-4 sm:p-6 space-y-4">
                    <div class="flex items-center justify-between gap-3">
                      <div class="flex items-center gap-3">
                        <.icon name={:brand_github} type={:outline} class="w-5 h-5 text-success" />
                        <div>
                          <p class="text-sm font-medium text-base-content">GitHub Account</p>
                          <p class="text-xs text-base-content/70">Authentication provider</p>
                        </div>
                      </div>
                      <span class="badge badge-success badge-sm">Connected</span>
                    </div>
                  </div>
                  <div class="divider"></div>
                  <div class="flex flex-col sm:flex-row justify-end gap-2">
                    <.link href={~p"/auth/github"} class="btn btn-neutral">
                      <.icon name={:refresh} type={:outline} class="w-4 h-4" /> Sync Profile
                    </.link>
                    <button
                      class="btn btn-error"
                      onclick="disable_account_modal.showModal()"
                    >
                      <.icon name={:trash} type={:outline} class="w-4 h-4" /> Disable Account
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <dialog id="disable_account_modal" class="modal">
        <div class="modal-box">
          <h3 class="text-lg font-bold text-base-content mb-4">Disable Account?</h3>
          <p class="text-sm text-base-content/80 mb-6">
            Disabling your account prevents you from creating or updating any packages. You can re-enable it at any time.
          </p>
          <div class="modal-action">
            <form method="dialog">
              <button class="btn btn-neutral btn-sm mr-3">Cancel</button>
            </form>
            <button class="btn btn-error btn-sm" phx-click="disable_account">
              <.icon name={:trash} type={:outline} class="w-4 h-4" /> Disable Account
            </button>
          </div>
        </div>
        <form method="dialog" class="modal-backdrop">
          <button>close</button>
        </form>
      </dialog>
    </Layouts.app>
    """
  end

  def handle_event("update_bio", %{"user" => %{"bio" => bio}}, socket) do
    user = socket.assigns.current_scope.user

    case LuaNox.Accounts.update_bio(user, bio) do
      {:ok, user} ->
        socket =
          if LuaNox.Accounts.User.strip_urls(bio) != bio do
            put_flash(
              socket,
              :info,
              "Bio saved, but links were removed. Links aren't allowed in bios."
            )
          else
            put_flash(socket, :info, "Bio updated successfully.")
          end

        {:noreply,
         socket
         |> assign(:current_scope, LuaNox.Accounts.Scope.for_user(user))
         |> assign(:bio_count, String.length(user.bio || ""))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update bio.")}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp member_since_date(%DateTime{} = date), do: Calendar.strftime(date, "%B %Y")
  defp member_since_date(%NaiveDateTime{} = date), do: Calendar.strftime(date, "%B %Y")
  defp member_since_date(_), do: "Unknown"
end
