defmodule LuxpkgsWeb.Schemas.User do
  @moduledoc """
  OpenAPI schema for User resources
  """
  require OpenApiSpex

  def schema do
    %OpenApiSpex.Schema{
      title: "User",
      description: "A user in the system",
      type: :object,
      properties: %{
        id: %OpenApiSpex.Schema{
          type: :integer,
          description: "Unique user identifier",
          example: 1
        },
        login: %OpenApiSpex.Schema{
          type: :string,
          description: "User login/username",
          example: "johndoe"
        },
        email: %OpenApiSpex.Schema{
          type: :string,
          format: :email,
          description: "User email address",
          example: "john@example.com"
        },
        name: %OpenApiSpex.Schema{
          type: :string,
          description: "User display name",
          example: "John Doe"
        },
        avatar_url: %OpenApiSpex.Schema{
          type: :string,
          format: :uri,
          description: "URL to user's avatar image",
          example: "https://avatars.githubusercontent.com/u/123456"
        }
      },
      required: [:id, :login],
      example: %{
        "id" => 1,
        "login" => "johndoe",
        "email" => "john@example.com",
        "name" => "John Doe",
        "avatar_url" => "https://avatars.githubusercontent.com/u/123456"
      }
    }
  end
end
