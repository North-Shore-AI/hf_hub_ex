# Prompt 09: Webhooks API

## Context

You are implementing the Webhooks API for `hf_hub_ex`. Webhooks enable automated notifications when events occur on repositories.

**Prerequisites**: Prompts 01-02 must be completed.

## Required Reading

```
lib/hf_hub/http.ex
docs/20251231/webhooks/docs.md
```

## Task

Create `HfHub.Webhooks` module.

## Implementation

### Create `lib/hf_hub/webhooks.ex`

```elixir
defmodule HfHub.Webhooks do
  @moduledoc """
  Webhooks API for event notifications.
  """

  alias HfHub.{HTTP, Auth}
  alias HfHub.Webhooks.{WebhookInfo, WatchedItem}

  @type domain :: :repo | :discussion

  @spec list(keyword()) :: {:ok, [WebhookInfo.t()]} | {:error, term()}
  def list(opts \\ []) do
    token = opts[:token] || Auth.get_token()

    case HTTP.get("/api/settings/webhooks", token: token) do
      {:ok, webhooks} when is_list(webhooks) ->
        {:ok, Enum.map(webhooks, &WebhookInfo.from_response/1)}
      {:ok, %{"webhooks" => webhooks}} ->
        {:ok, Enum.map(webhooks, &WebhookInfo.from_response/1)}
      error -> error
    end
  end

  @spec get(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def get(webhook_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    case HTTP.get("/api/settings/webhooks/#{webhook_id}", token: token) do
      {:ok, response} -> {:ok, WebhookInfo.from_response(response)}
      error -> error
    end
  end

  @spec create(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def create(url, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    watched = opts[:watched] || []
    watched_payload = Enum.map(watched, fn
      {type, name} -> %{"type" => Atom.to_string(type), "name" => name}
      %{} = item -> item
    end)

    domains = opts[:domains] || [:repo]
    domains_payload = Enum.map(domains, &Atom.to_string/1)

    body = %{
      "url" => url,
      "watched" => watched_payload,
      "domains" => domains_payload,
      "secret" => opts[:secret]
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    case HTTP.post("/api/settings/webhooks", body, token: token) do
      {:ok, response} -> {:ok, WebhookInfo.from_response(response)}
      error -> error
    end
  end

  @spec update(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def update(webhook_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{}
    |> maybe_put(:url, opts[:url])
    |> maybe_put(:watched, format_watched(opts[:watched]))
    |> maybe_put(:domains, format_domains(opts[:domains]))
    |> maybe_put(:secret, opts[:secret])

    case HTTP.patch("/api/settings/webhooks/#{webhook_id}", body, token: token) do
      {:ok, response} -> {:ok, WebhookInfo.from_response(response)}
      error -> error
    end
  end

  @spec enable(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def enable(webhook_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    case HTTP.post("/api/settings/webhooks/#{webhook_id}/enable", nil, token: token) do
      {:ok, response} -> {:ok, WebhookInfo.from_response(response)}
      error -> error
    end
  end

  @spec disable(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def disable(webhook_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    case HTTP.post("/api/settings/webhooks/#{webhook_id}/disable", nil, token: token) do
      {:ok, response} -> {:ok, WebhookInfo.from_response(response)}
      error -> error
    end
  end

  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(webhook_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    HTTP.delete("/api/settings/webhooks/#{webhook_id}", token: token)
  end

  # Helpers
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp format_watched(nil), do: nil
  defp format_watched(watched) do
    Enum.map(watched, fn
      {type, name} -> %{"type" => Atom.to_string(type), "name" => name}
      item -> item
    end)
  end

  defp format_domains(nil), do: nil
  defp format_domains(domains), do: Enum.map(domains, &Atom.to_string/1)
end
```

### Create Data Structures

`lib/hf_hub/webhooks/webhook_info.ex`:
```elixir
defmodule HfHub.Webhooks.WebhookInfo do
  defstruct [:id, :url, :watched, :domains, :secret, :disabled, :created_at]

  def from_response(response) do
    %__MODULE__{
      id: response["id"],
      url: response["url"],
      watched: Enum.map(response["watched"] || [], &WatchedItem.from_response/1),
      domains: Enum.map(response["domains"] || [], &String.to_atom/1),
      secret: response["secret"],
      disabled: response["disabled"],
      created_at: parse_datetime(response["createdAt"])
    }
  end
end

defmodule HfHub.Webhooks.WatchedItem do
  defstruct [:type, :name]

  def from_response(response) do
    %__MODULE__{
      type: String.to_atom(response["type"]),
      name: response["name"]
    }
  end
end
```

## Test Requirements

Test CRUD and enable/disable operations.

## Changelog Entry

```markdown
### Added
- `HfHub.Webhooks` module
  - `list/1`, `get/2`, `create/2`, `update/2`, `delete/2`
  - `enable/2`, `disable/2`
```

## Completion Checklist

- [ ] `HfHub.Webhooks` module created
- [ ] Data structures created
- [ ] All operations implemented
- [ ] Tests pass
- [ ] Quality checks pass
- [ ] CHANGELOG updated
