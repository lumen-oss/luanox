defmodule LuxpkgsWeb.Schemas.Release do
  @moduledoc """
  OpenAPI schema for Release resources
  """
  require OpenApiSpex

  def schema do
    %OpenApiSpex.Schema{
      title: "Release",
      description: "A specific version release of a package",
      type: :object,
      properties: %{
        id: %OpenApiSpex.Schema{
          type: :integer,
          description: "Unique release identifier",
          example: 1
        },
        version: %OpenApiSpex.Schema{
          type: :string,
          description: "Semantic version string",
          example: "2.1.0",
          pattern: "^\\d+\\.\\d+\\.\\d+.*$"
        }
      },
      required: [:id, :version],
      example: %{
        "id" => 1,
        "version" => "2.1.0"
      }
    }
  end
end
