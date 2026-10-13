defmodule LuxpkgsWeb.ApiSpec do
  alias OpenApiSpex.{Contact, Info, License, OpenApi, Paths, Server}
  alias LuxpkgsWeb.Router
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Server.from_endpoint(Endpoint)
        %Server{url: "http://localhost:4000", description: "Development server"},
        %Server{url: "https://luxpkgs.org", description: "Production server"}
      ],
      info: %Info{
        title: "Luxpkgs API",
        description: """
        Luxpkgs Package Repository API

        This API provides access to the Luxpkgs package repository, allowing users to:
        - Browse and search packages
        - Upload new packages and releases
        - Manage API keys and authentication
        - Download packages and rockspecs

        Authentication is handled via API tokens that can be generated in the user settings.
        """,
        version: "1.0.0",
        contact: %Contact{
          name: "Luxpkgs Support",
          url: "https://github.com/lumen-oss/luxpkgs"
        },
        license: %License{
          name: "MIT",
          url: "https://opensource.org/licenses/MIT"
        }
      },
      paths: Paths.from_router(Router),
      components: %OpenApiSpex.Components{
        schemas: %{
          "Package" => LuxpkgsWeb.Schemas.Package.schema(),
          "PackageMapValue" => LuxpkgsWeb.Schemas.Package.schema_map_value(),
          "PackageInput" => LuxpkgsWeb.Schemas.PackageInput.schema(),
          "Release" => LuxpkgsWeb.Schemas.Release.schema(),
          "ReleaseInput" => LuxpkgsWeb.Schemas.ReleaseInput.schema(),
          "User" => LuxpkgsWeb.Schemas.User.schema(),
          "Error" => LuxpkgsWeb.Schemas.Error.schema(),
          "ValidationError" => LuxpkgsWeb.Schemas.ValidationError.schema()
        },
        securitySchemes: %{
          "ApiKeyAuth" => %OpenApiSpex.SecurityScheme{
            type: "apiKey",
            name: "Authorization",
            in: "header",
            description: "API token for authentication. Format: Bearer <token>"
          }
        }
      },
      security: [
        %{"ApiKeyAuth" => []}
      ]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
