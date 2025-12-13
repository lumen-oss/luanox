defmodule LuaNoxWeb.Schemas.Package do
  @moduledoc """
  OpenAPI schema for Package resources
  """
  require OpenApiSpex

  def schema do
    %OpenApiSpex.Schema{
      title: "Package",
      description: "A Lua package in the repository",
      type: :object,
      properties: %{
        name: %OpenApiSpex.Schema{
          type: :string,
          description: "Unique package name",
          example: "lua-cjson"
        },
        summary: %OpenApiSpex.Schema{
          type: :string,
          description: "Brief description of the package",
          example: "Fast JSON parsing and encoding support for Lua"
        },
        description: %OpenApiSpex.Schema{
          type: :string,
          description: "Detailed description of the package",
          example: "Lua CJSON is a fast JSON parsing and encoding support for Lua"
        },
        releases: %OpenApiSpex.Schema{
          type: :array,
          description: "List of package releases",
          items: %OpenApiSpex.Schema{
            type: :object,
            properties: %{
              id: %OpenApiSpex.Schema{type: :integer},
              version: %OpenApiSpex.Schema{type: :string}
            }
          }
        }
      },
      required: [:name, :summary],
      example: %{
        "name" => "lua-cjson",
        "summary" => "Fast JSON parsing and encoding support for Lua",
        "description" => "Lua CJSON is a fast JSON parsing and encoding support for Lua",
        "releases" => [
          %{
            "id" => 1,
            "version" => "2.1.0"
          }
        ]
      }
    }
  end

  def schema_map_value do
    %OpenApiSpex.Schema{
      title: "PackageMapValue",
      description: "Package data in search results (name is the key)",
      type: :object,
      properties: %{
        summary: %OpenApiSpex.Schema{
          type: :string,
          description: "Brief description of the package",
          example: "Fast JSON parsing and encoding support for Lua"
        },
        description: %OpenApiSpex.Schema{
          type: :string,
          description: "Detailed description of the package",
          example: "Lua CJSON is a fast JSON parsing and encoding support for Lua"
        },
        releases: %OpenApiSpex.Schema{
          type: :array,
          description: "List of package releases",
          items: %OpenApiSpex.Schema{
            type: :object,
            properties: %{
              id: %OpenApiSpex.Schema{type: :integer},
              version: %OpenApiSpex.Schema{type: :string}
            }
          }
        }
      },
      required: [:summary],
      example: %{
        "summary" => "Fast JSON parsing and encoding support for Lua",
        "description" => "Lua CJSON is a fast JSON parsing and encoding support for Lua",
        "releases" => [
          %{
            "id" => 1,
            "version" => "2.1.0"
          }
        ]
      }
    }
  end
end
