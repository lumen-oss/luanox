defmodule LuxpkgsWeb.Schemas.ValidationError do
  @moduledoc """
  OpenAPI schema for validation error response
  """
  require OpenApiSpex

  def schema do
    %OpenApiSpex.Schema{
      title: "ValidationError",
      description: "Validation error with field-specific error messages",
      type: :object,
      properties: %{
        errors: %OpenApiSpex.Schema{
          type: :object,
          description: "Map of field names to error messages",
          additionalProperties: %OpenApiSpex.Schema{
            type: :array,
            items: %OpenApiSpex.Schema{type: :string}
          }
        }
      },
      required: [:errors]
    }
  end
end
