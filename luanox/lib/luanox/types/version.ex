defmodule LuaNox.Types.Version do
  use Ecto.Type

  def type, do: :string

  def cast(version) when is_binary(version) do
    case Version.parse(version) do
      {:ok, version} -> {:ok, version}
      :error -> :error
    end
  end

  def cast(%Version{} = version), do: {:ok, version}
  def cast(_), do: :error

  def load(version) when is_binary(version) do
    case Version.parse(version) do
      {:ok, version} -> {:ok, version}
      :error -> :error
    end
  end

  def dump(%Version{} = version), do: {:ok, to_string(version)}
  def dump(version) when is_binary(version), do: {:ok, version}
  def dump(_), do: :error

  def embed_as(_), do: :self

  def equal?(term1, term2), do: term1 == term2
end
