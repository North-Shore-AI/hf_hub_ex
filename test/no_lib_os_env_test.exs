defmodule HfHub.NoLibOsEnvTest do
  @moduledoc """
  Regression armor: no direct OS env API calls under `lib/**`.

  This library follows the Elixir runtime-configuration best practice of
  reading only from `Application.get_env/2`. Hosts that want the
  historical env-var shortcuts wire them in their own `config/runtime.exs`
  (the recommended snippet is in the `HfHub` moduledoc).

  This test scans every tracked Elixir source file under `lib/` for the
  forbidden token shapes. The check is intentionally textual; it catches
  the actual call shape we want to forbid. Moduledoc and inline comment
  lines that *describe* the rule (or that document the recommended
  `config/runtime.exs` snippet) are explicitly allow-listed.
  """

  use ExUnit.Case, async: true

  @forbidden ~w(
    System.get_env
    System.fetch_env
    System.fetch_env!
    System.put_env
    System.delete_env
  )

  test "no lib/** Elixir source calls direct OS env APIs" do
    hits =
      tracked_lib_files()
      |> Enum.flat_map(&forbidden_hits/1)

    assert hits == [],
           "Found direct OS env API call(s) under lib/**. Move env reads " <>
             "to the host's config/runtime.exs (or, for library knobs, " <>
             "expose an explicit option on the function being called). " <>
             "Hits:\n" <>
             Enum.map_join(hits, "\n", fn {p, t} -> "  #{p} -> #{t}" end)
  end

  defp tracked_lib_files do
    {out, 0} = System.cmd("git", ["ls-files", "lib/"])

    out
    |> String.split("\n", trim: true)
    |> Enum.filter(&(String.ends_with?(&1, ".ex") or String.ends_with?(&1, ".exs")))
  end

  defp forbidden_hits(path) do
    body = File.read!(path)
    lines = String.split(body, "\n")
    doc_blocks = find_doc_block_ranges(lines)

    Enum.flat_map(@forbidden, fn token ->
      lines
      |> Enum.with_index(1)
      |> Enum.filter(fn {line, idx} ->
        String.contains?(line, token) and
          not docstring_or_comment_line?(line, idx, doc_blocks)
      end)
      |> Enum.map(fn {_line, idx} -> {path, "#{token} (line #{idx})"} end)
    end)
  end

  # Identifies inclusive line ranges that are inside @moduledoc / @doc
  # triple-quoted strings. Inside these blocks, mentioning a forbidden
  # token is documentation (e.g. the recommended config/runtime.exs
  # snippet), not a call site.
  defp find_doc_block_ranges(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce({[], nil}, fn {line, idx}, {ranges, current_start} ->
      trimmed = String.trim(line)

      cond do
        # Opening triple-quote on a @moduledoc/@doc line
        is_nil(current_start) and
            (String.contains?(trimmed, "@moduledoc \"\"\"") or
               String.contains?(trimmed, "@doc \"\"\"")) ->
          {ranges, idx}

        # Closing triple-quote (lone """ on its own line)
        not is_nil(current_start) and trimmed == "\"\"\"" ->
          {[{current_start, idx} | ranges], nil}

        true ->
          {ranges, current_start}
      end
    end)
    |> elem(0)
  end

  defp docstring_or_comment_line?(line, idx, doc_blocks) do
    trimmed = String.trim_leading(line)

    cond do
      String.starts_with?(trimmed, "#") -> true
      String.contains?(line, "`System.") -> true
      Enum.any?(doc_blocks, fn {s, e} -> idx >= s and idx <= e end) -> true
      true -> false
    end
  end
end
