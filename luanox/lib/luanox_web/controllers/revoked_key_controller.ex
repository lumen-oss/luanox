defmodule LuaNoxWeb.RevokedKeyController do
  alias LuaNox.RevokedKeys
  use LuaNoxWeb, :controller
  use OpenApiSpex.ControllerSpecs

  action_fallback LuaNoxWeb.FallbackController

  operation :create,
    summary: "Revoke API key",
    description: "Revoke the current API token to invalidate it",
    responses: %{
      200 => {"API key revoked successfully", "text/plain", %OpenApiSpex.Schema{type: :string}},
      401 => {"Authentication required", "application/json", %OpenApiSpex.Reference{"$ref": "#/components/schemas/Error"}}
    },
    security: [%{"ApiKeyAuth" => []}]

  def create(conn, _attrs) do
    token = LuaNox.Guardian.Plug.current_token(conn)
    scope = LuaNox.Guardian.Plug.current_resource(conn)

    case RevokedKeys.create_revoked_key(scope, %{
           revoked_key: token
         }) do
      {:ok} ->
        send_resp(conn, :ok, "key revoked")

      {:error, _} = err ->
        err
    end
  end
end
