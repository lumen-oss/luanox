defmodule LuaNoxWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use LuaNoxWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: LuaNoxWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: LuaNoxWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :no_query_string}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: LuaNoxWeb.ErrorJSON)
    |> render(:no_query_string)
  end

  def call(conn, {:error, :insufficient_permissions}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: LuaNoxWeb.ErrorJSON)
    |> render(:forbidden)
  end

  def call(conn, {:error, :invalid_rockspec}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: LuaNoxWeb.ErrorJSON)
    |> render(:invalid_rockspec)
  end

  def call(conn, {:error, :rate_limit_exceeded, retry_after}) do
    conn
    |> put_status(:too_many_requests)
    |> put_resp_header("retry-after", to_string(div(retry_after, 1000)))
    |> put_view(json: LuaNoxWeb.ErrorJSON)
    |> render(:rate_limit_exceeded, retry_after: retry_after)
  end

  # For guardian errors in the plug pipeline
  def auth_error(conn, {type, err}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: LuaNoxWeb.ErrorJSON)
    |> render(:unauthorized, type: type, err: err)
  end
end
