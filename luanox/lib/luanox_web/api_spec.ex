defmodule LuaNoxWeb.ApiSpec do
  alias OpenApiSpex.{Contact, Info, License, OpenApi, Paths, Server}
  alias LuaNoxWeb.Router
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Server.from_endpoint(Endpoint)
        %Server{url: "http://localhost:4000", description: "Development server"},
        %Server{url: "https://luanox.org", description: "Production server"}
      ],
      info: %Info{
        title: "LuaNox API",
        description: """
        LuaNox Package Repository API

        This API provides access to the LuaNox package repository, allowing users to:
        - Browse and search packages
        - Upload new packages and releases
        - Manage API keys and authentication
        - Download packages and rockspecs

        Authentication is handled via API tokens that can be generated in the user settings.
        """,
        version: "1.0.0",
        contact: %Contact{
          name: "LuaNox Support",
          url: "https://github.com/lumen-oss/luanox"
        },
        license: %License{
          name: "MIT",
          url: "https://opensource.org/licenses/MIT"
        }
      },
      paths: Paths.from_router(Router),
      components: %OpenApiSpex.Components{
        schemas: %{
          "Package" => LuaNoxWeb.Schemas.Package.schema(),
          "PackageInput" => LuaNoxWeb.Schemas.PackageInput.schema(),
          "Release" => LuaNoxWeb.Schemas.Release.schema(),
          "ReleaseInput" => LuaNoxWeb.Schemas.ReleaseInput.schema(),
          "User" => LuaNoxWeb.Schemas.User.schema(),
          "Error" => LuaNoxWeb.Schemas.Error.schema(),
          "ValidationError" => LuaNoxWeb.Schemas.ValidationError.schema()
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
