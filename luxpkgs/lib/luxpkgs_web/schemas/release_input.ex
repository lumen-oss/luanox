defmodule LuxpkgsWeb.Schemas.ReleaseInput do
  @moduledoc """
  OpenAPI schema for Release creation input
  """
  require OpenApiSpex

  def schema do
    %OpenApiSpex.Schema{
      title: "ReleaseInput",
      description: "Input data for creating a new release",
      type: :object,
      properties: %{
        package: %OpenApiSpex.Schema{
          type: :string,
          description: "Package name for this release",
          example: "lua-cjson"
        },
        version: %OpenApiSpex.Schema{
          type: :string,
          description: "Semantic version string",
          example: "2.1.0"
        },
        rockspec: %OpenApiSpex.Schema{
          type: :string,
          format: :binary,
          description: "Rockspec file content"
        }
      },
      required: [:package, :version, :rockspec]
    }
  end
end
