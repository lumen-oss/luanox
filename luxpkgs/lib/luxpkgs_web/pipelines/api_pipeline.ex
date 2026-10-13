defmodule LuxpkgsWeb.Pipelines.ApiPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :luxpkgs,
    module: Luxpkgs.Guardian,
    error_handler: LuxpkgsWeb.FallbackController

  @claims %{iss: "luxpkgs", aud: "luxpkgs", typ: "access"}

  plug LuxpkgsWeb.Pipelines.VerifyToken, claims: @claims
  plug Guardian.Plug.LoadResource, allow_blank: true
end
