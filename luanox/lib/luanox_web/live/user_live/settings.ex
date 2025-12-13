defmodule LuaNoxWeb.UserLive.Settings do
  use LuaNoxWeb, :live_view

  on_mount({LuaNoxWeb.UserAuth, :require_sudo_mode})

  def mount(_params, _session, socket) do
    # TODO: actually use a changeset or create the Phoenix.HTML.Form struct by hand
    {:ok, socket |> assign(:email_form, nil) |> assign(:username_form, nil)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="bg-base-100 border-b border-base-300">
        <div class="max-w-5xl mx-auto px-4 lg:px-6 py-4 lg:py-6">
          <div class="flex items-center gap-3">
            <div class="w-16 h-16 sm:w-20 sm:h-20 bg-primary/10 border-2 border-primary/20 rounded-full flex items-center justify-center flex-shrink-0">
              <.icon name={:user} type={:outline} class="w-10 h-10 sm:w-12 sm:h-12 text-primary" />
            </div>
            <div>
              <h1 class="text-xl sm:text-2xl font-semibold text-base-content">Settings</h1>
              <p class="text-sm sm:text-base text-base-content/70">
                Manage your profile and account preferences
              </p>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-5xl mx-auto px-4 lg:px-6 py-6 lg:py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Profile Card --%>
          <div class="lg:col-span-1">
            <div class="bg-base-200 border border-base-300 p-6 sticky top-6">
              <div class="text-center">
                <div class="avatar avatar-placeholder mb-4">
                  <div class="w-20 bg-primary/10 border-2 border-primary/20 rounded-full">
                    <span class="text-3xl font-bold text-primary">
                      {String.first(@current_scope.user.username)}
                    </span>
                  </div>
                </div>
                <h3 class="text-lg font-semibold text-base-content mb-1">
                  {@current_scope.user.username}
                </h3>
                <p class="text-sm text-base-content/60 mb-4">
                  {@current_scope.user.email}
                </p>
              </div>

              <div class="border-t border-base-300 pt-4 space-y-3">
                <div class="flex justify-between items-center">
                  <span class="text-sm text-base-content/60">Member since</span>
                  <span class="text-sm font-medium">August 2025</span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-sm text-base-content/60">Auth provider</span>
                  <span class="text-sm font-medium text-primary">GitHub</span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-sm text-base-content/60">Account type</span>
                  <span class="text-sm font-medium text-secondary">Standard</span>
                </div>
              </div>
            </div>
          </div>

          <%!-- Settings Sections --%>
          <div class="lg:col-span-2 space-y-4">
            <%!-- Account Section --%>
            <div class="collapse collapse-arrow bg-base-200 border border-base-300 !rounded-none">
              <input type="checkbox" checked />
              <div class="collapse-title flex items-center gap-3 px-4 sm:px-6">
                <.icon name={:user_circle} type={:outline} class="w-5 h-5 text-primary" />
                <div>
                  <h2 class="font-semibold text-base-content">Account</h2>
                  <p class="text-sm text-base-content/60">Personal information</p>
                </div>
              </div>
              <div class="collapse-content px-4 sm:px-6">
                <div class="space-y-6 pt-2">
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
            <div class="collapse collapse-arrow bg-base-200 border border-base-300 !rounded-none">
              <input type="checkbox" />
              <div class="collapse-title flex items-center gap-3 px-4 sm:px-6">
                <.icon name={:bell} type={:outline} class="w-5 h-5 text-primary" />
                <div>
                  <h2 class="font-semibold text-base-content">Notifications</h2>
                  <p class="text-sm text-base-content/60">Email and push preferences</p>
                </div>
              </div>
              <div class="collapse-content px-4 sm:px-6">
                <div class="space-y-6 pt-2">
                  <div class="flex items-center justify-between py-2">
                    <div>
                      <p class="text-sm font-medium text-base-content">Email Notifications</p>
                      <p class="text-xs text-base-content/60">Receive updates about your packages</p>
                    </div>
                    <input type="checkbox" class="toggle toggle-primary" checked />
                  </div>
                  <div class="flex items-center justify-between py-2">
                    <div>
                      <p class="text-sm font-medium text-base-content">Package Updates</p>
                      <p class="text-xs text-base-content/60">Get notified about new releases</p>
                    </div>
                    <input type="checkbox" class="toggle toggle-primary" checked />
                  </div>
                </div>
              </div>
            </div>

            <%!-- Advanced Section --%>
            <div class="collapse collapse-arrow bg-base-200 border border-base-300 !rounded-none">
              <input type="checkbox" />
              <div class="collapse-title flex items-center gap-3 px-4 sm:px-6">
                <.icon name={:settings} type={:outline} class="w-5 h-5 text-primary" />
                <div>
                  <h2 class="font-semibold text-base-content">Advanced Settings</h2>
                  <p class="text-sm text-base-content/60">Account management</p>
                </div>
              </div>
              <div class="collapse-content px-4 sm:px-6">
                <div class="space-y-6 pt-2">
                  <div class="bg-base-100 border border-base-300 rounded-sm p-4 sm:p-6 space-y-4">
                    <div class="flex items-center justify-between gap-3">
                      <div class="flex items-center gap-3">
                        <.icon name={:brand_github} type={:outline} class="w-5 h-5 text-success" />
                        <div>
                          <p class="text-sm font-medium text-base-content">GitHub Account</p>
                          <p class="text-xs text-base-content/60">Authentication provider</p>
                        </div>
                      </div>
                      <span class="badge badge-success badge-sm">Connected</span>
                    </div>
                  </div>
                  <div class="divider"></div>
                  <div class="flex flex-col sm:flex-row justify-end gap-2">
                    <button class="btn btn-neutral">
                      <.icon name={:refresh} type={:outline} class="w-4 h-4" /> Sync Profile
                    </button>
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
end
