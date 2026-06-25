defmodule LuaNoxWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  def render("no_query_string.json", _assigns) do
    %{errors: %{detail: "No query string provided"}}
  end

  def render("unauthorized.json", %{type: type, err: err}) do
    %{errors: %{detail: "Bearer token authentication failed (#{type}): #{to_string(err)}"}}
  end

  def render("forbidden.json", _assigns) do
    %{errors: %{detail: "You do not have permission to perform this action"}}
  end

  def render("invalid_rockspec.json", _assigns) do
    %{errors: %{detail: "The provided rockspec file is invalid"}}
  end

  def render("rate_limit_exceeded.json", %{retry_after: retry_after}) do
    %{
      errors: %{
        detail: "Rate limit exceeded. Try again in #{div(retry_after, 1000)} seconds."
      }
    }
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
