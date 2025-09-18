defmodule LuaNoxWeb.PackageBox do
  use LuaNoxWeb, :html

  attr :name, :string, required: true
  attr :description, :string, default: ""
  attr :version, :string, default: "0.1.0"
  attr :download_count, :integer, default: 0

  def package(assigns) do
    ~H"""
    <.link navigate={~p"/package/#{@name}"} class="group">
      <div class="bg-base-100 border border-base-300 hover:border-primary/40 transition-colors duration-200 p-6">
        <div class="space-y-4">
          <div class="flex items-start justify-between">
            <h2 class="text-lg font-semibold text-base-content group-hover:text-primary transition-colors">
              {@name}
            </h2>
            <div class="bg-primary/10 text-primary border border-primary/20 px-2 py-1 text-xs font-mono">
              v{@version}
            </div>
          </div>

          <p class="text-base-content/70 text-sm leading-relaxed min-h-[3rem] line-clamp-2">
            {if @description != "", do: @description, else: "No description available"}
          </p>

          <div class="flex items-center justify-between pt-3 border-t border-base-300">
            <div class="flex items-center space-x-2 text-xs text-base-content/60">
              <.icon name={:download} type={:outline} class="w-3 h-3" />
              <span>{@download_count} downloads</span>
            </div>
            <div class="text-xs text-primary group-hover:text-primary/80 transition-colors">
              View Details →
            </div>
          </div>
        </div>
      </div>
    </.link>
    """
  end

  attr :packages, :map, required: true

  def packages(assigns) do
    ~H"""
    <div class="py-16 bg-base-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Featured Packages Section -->
        <div class="mb-16">
          <div class="text-center mb-12">
            <div class="flex items-center justify-center space-x-4 mb-6">
              <div class="w-8 h-px bg-primary"></div>
              <h2 class="text-3xl font-bold text-base-content">Featured Packages</h2>
              <div class="w-8 h-px bg-primary"></div>
            </div>
            <p class="text-base-content/70 max-w-2xl mx-auto">
              Discover the most popular and well-maintained packages in our ecosystem
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            <%= for %{name: name, summary: summary, releases: releases} <- Enum.take(@packages, 4) do %>
              <.package
                name={name}
                version={(List.last(releases) || %{version: "0.1.0"}) |> Map.get(:version)}
                download_count={Enum.sum(for r <- releases, do: r.download_count)}
                description={summary || ""}
              />
            <% end %>
          </div>
        </div>
        
    <!-- Most Recent Updates Section -->
        <div class="mb-16">
          <div class="text-center mb-12">
            <div class="flex items-center justify-center space-x-4 mb-6">
              <div class="w-8 h-px bg-secondary"></div>
              <h2 class="text-3xl font-bold text-base-content">Recent Updates</h2>
              <div class="w-8 h-px bg-secondary"></div>
            </div>
            <p class="text-base-content/70 max-w-2xl mx-auto">
              Stay up to date with the latest package releases and improvements
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            <%= for %{name: name, summary: summary, releases: releases} <- Enum.take(@packages, 4) do %>
              <.package
                name={name}
                version={(List.last(releases) || %{version: "0.1.0"}) |> Map.get(:version)}
                download_count={Enum.sum(for r <- releases, do: r.download_count)}
                description={summary || ""}
              />
            <% end %>
          </div>
        </div>
        
    <!-- Call to Action -->
        <div class="text-center">
          <div class="bg-base-100 border border-base-300 py-16 px-8">
            <h3 class="text-2xl font-bold text-base-content mb-4">
              Ready to explore more packages?
            </h3>
            <p class="text-base-content/70 mb-8 max-w-md mx-auto">
              Browse our complete collection of Lua packages and find the perfect tools for your project.
            </p>
            <.link
              navigate="/packages"
              class="bg-primary text-primary-content border border-primary hover:bg-primary/90 px-8 py-3 font-medium transition-colors inline-flex items-center"
            >
              <.icon name={:folder} type={:outline} class="w-5 h-5 mr-2" /> View All Packages
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
