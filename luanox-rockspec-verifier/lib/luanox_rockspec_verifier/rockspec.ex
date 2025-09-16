defmodule LuanoxRockspecVerifier.Rockspec do
  def verify(rockspec, %{
        expected_name: expected_name,
        expected_version: expected_version
      }) do
    sandboxed_state = :luerl_sandbox.init()

    Regex.match?(~r/^[a-zA-Z0-9_\-]+$/, expected_name) and
      case :luerl_sandbox.run(
             rockspec,
             %{
               max_reductions: 500
               # max_time: ...
             },
             sandboxed_state
           ) do
        {:ok, _, state} ->
          with {:ok, %Version{}} <- Version.parse(expected_version),
               {:ok, "3.0", _} <- Luerl.get_table_keys_dec(state, ["rockspec_format"]),
               {:ok, ^expected_name, _} <-
                 Luerl.get_table_keys_dec(state, ["package"]),
               {:ok, ^expected_version, _} <-
                 Luerl.get_table_keys_dec(state, ["version"]),
               {:ok, source, _} <- Luerl.get_table_keys_dec(state, ["source"]),
               {:ok, build, _} <- Luerl.get_table_keys_dec(state, ["build"]) do
            {has_tag_or_hash, has_git_url} =
              Enum.reduce(source, {false, false}, fn
                {tag_or_hash, _}, {_, has_url} when tag_or_hash in ["tag", "hash"] ->
                  {true, has_url}

                {"url", "git+" <> _}, {has_tag, _} ->
                  {has_tag, true}

                {"url", "git://" <> _}, {has_tag, _} ->
                  {has_tag, true}

                _, acc ->
                  acc
              end)

            has_url =
              has_git_url or
                Enum.any?(source, fn
                  {"url", _} -> true
                  _ -> false
                end)

            ((has_tag_or_hash and has_git_url) or has_url) and
              Enum.any?(build, fn
                {"type", _} -> true
                _ -> false
              end)
          else
            _ -> false
          end

        {:error, _} ->
          false
      end
  end
end
