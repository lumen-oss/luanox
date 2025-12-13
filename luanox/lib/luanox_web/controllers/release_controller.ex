defmodule LuaNoxWeb.ReleaseController do
  use LuaNoxWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias LuaNox.Packages.Package
  alias LuaNox.Packages
  alias LuaNox.Packages.Release

  action_fallback(LuaNoxWeb.FallbackController)

  operation(:index,
    summary: "List package releases",
    description: "Get all releases for a specific package",
    parameters: [
      package: [
        in: :query,
        description: "Package name",
        type: :string,
        required: true,
        example: "lua-cjson"
      ]
    ],
    responses: %{
      200 =>
        {"Package releases", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             data: %OpenApiSpex.Schema{
               type: :array,
               items: %OpenApiSpex.Reference{"$ref": "#/components/schemas/Release"}
             }
           }
         }},
      404 =>
        {"Package not found", "application/json",
         %OpenApiSpex.Reference{"$ref": "#/components/schemas/Error"}}
    }
  )

  def index(conn, %{"package" => package_name}) when is_binary(package_name) do
    case Packages.get_package(package_name) do
      nil -> {:error, :not_found}
      package -> render(conn, :index, releases: package.releases)
    end
  end

  operation(:create,
    summary: "Create a new release",
    description: "Upload a new release for an existing package",
    request_body:
      {"Release data with rockspec file", "multipart/form-data",
       %OpenApiSpex.Reference{"$ref": "#/components/schemas/ReleaseInput"}},
    responses: %{
      201 =>
        {"Release created successfully", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             data: %OpenApiSpex.Reference{"$ref": "#/components/schemas/Release"}
           }
         }},
      404 =>
        {"Package not found", "application/json",
         %OpenApiSpex.Reference{"$ref": "#/components/schemas/Error"}},
      400 =>
        {"Invalid rockspec file", "application/json",
         %OpenApiSpex.Reference{"$ref": "#/components/schemas/Error"}},
      422 =>
        {"Validation errors", "application/json",
         %OpenApiSpex.Reference{"$ref": "#/components/schemas/ValidationError"}},
      401 =>
        {"Authentication required", "application/json",
         %OpenApiSpex.Reference{"$ref": "#/components/schemas/Error"}}
    },
    security: [%{"ApiKeyAuth" => []}]
  )

  def create(
        conn,
        %{
          "package" => package_name,
          "version" => _,
          "rockspec" => %Plug.Upload{} = rockspec
        } = release_params
      ) do
    if Path.extname(rockspec.filename) == ".rockspec" do
      case Packages.get_package(package_name) do
        nil ->
          {:error, :not_found}

        %Package{} = package ->
          case Packages.add_release(conn.assigns.current_scope, package, release_params) do
            {:ok, %Release{} = release} ->
              conn
              |> put_status(:created)
              |> put_resp_header("location", ~p"/api/releases/#{release.id}")
              |> render(:show, release: release)

            {:error, _} = ret ->
              ret
          end
      end
    else
      {:error, :invalid_rockspec}
    end
  end

  operation(:show,
    summary: "Download a release",
    description: "Download the rockspec file for a specific release",
    parameters: [
      id: [
        in: :path,
        description: "Release ID",
        type: :integer,
        required: true,
        example: 1
      ]
    ],
    responses: %{
      200 =>
        {"Rockspec file", "application/octet-stream",
         %OpenApiSpex.Schema{type: :string, format: :binary}},
      404 =>
        {"Release not found", "application/json",
         %OpenApiSpex.Reference{"$ref": "#/components/schemas/Error"}}
    }
  )

  def show(conn, %{"id" => id}) do
    case Packages.get_release(id) do
      nil ->
        {:error, :not_found}

      %Release{} = release ->
        full_file_path =
          Application.get_env(:luanox, :rockspec_storage) <> "/#{release.rockspec_path}"

        Packages.increment_release_download_count(release)

        conn
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"#{release.rockspec_path}\""
        )
        |> put_resp_content_type(MIME.from_path(full_file_path) || "application/octet-stream")
        |> send_file(200, full_file_path)
    end
  end
end
