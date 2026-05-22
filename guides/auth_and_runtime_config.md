# Authentication and runtime configuration

`hf_hub_ex` is a library: it does not read operating-system environment
variables directly from runtime modules. The host application owns that boundary
and passes configuration through options or application config.

## Recommended host setup

For an application or script, read secrets in `config/runtime.exs` or an
equivalent config provider:

```elixir
import Config

if token = System.get_env("HF_TOKEN") do
  config :hf_hub, token: token
end

cache_dir = System.get_env("HF_HUB_CACHE") || System.get_env("HF_HOME")
if cache_dir, do: config(:hf_hub, cache_dir: cache_dir)

case System.get_env("HF_HUB_OFFLINE") do
  value when value in ["1", "true", "TRUE", "yes", "YES"] ->
    config :hf_hub, offline: true

  _ ->
    :ok
end
```

For one-off IEx usage, passing `token:` explicitly is also fine:

```elixir
token = System.fetch_env!("HF_TOKEN")
{:ok, repo} = HfHub.Repo.create("my-org/my-dataset", repo_type: :dataset, token: token)
```

## Library defaults

- `HfHub.Auth.get_token/0` reads `Application.get_env(:hf_hub, :token)`.
- `HfHub.Config.cache_dir/0` reads `Application.get_env(:hf_hub, :cache_dir)`
  and defaults to `~/.cache/huggingface`.
- `HfHub.offline_mode?/0` reads `Application.get_env(:hf_hub, :offline)`.

## Local development

Use your preferred shell secret manager (`direnv`, a private wrapper script, or
your deployment platform's secret manager) to set `HF_TOKEN` before starting the
host app. Do not commit tokens to config files.
