defmodule LuxpkgsWeb.Schemas.Error do
  @moduledoc """
  OpenAPI schema for error responses
  """
  require OpenApiSpex

  def schema do
    %OpenApiSpex.Schema{
      title: "Error",
      description: "Standard error response",
      type: :object,
      properties: %{
        error: %OpenApiSpex.Schema{
          type: :string,
          description: "Error message",
          example: "Resource not found"
        },
        details: %OpenApiSpex.Schema{
          type: :string,
          description: "Additional error details",
          example: "The requested package does not exist"
        }
      },
      required: [:error],
      example: %{
        "error" => "Resource not found",
        "details" => "The requested package does not exist"
      }
    }
  end
end
