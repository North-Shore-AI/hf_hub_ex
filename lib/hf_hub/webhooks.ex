defmodule HfHub.Webhooks do
  @moduledoc """
  Webhooks API for event notifications on HuggingFace Hub.

  Webhooks enable automated notifications when events occur on repositories.

  ## Examples

      # List all webhooks
      {:ok, webhooks} = HfHub.Webhooks.list(token: "hf_xxx")

      # Get a specific webhook
      {:ok, webhook} = HfHub.Webhooks.get("webhook-id", token: "hf_xxx")

      # Create a new webhook
      {:ok, webhook} = HfHub.Webhooks.create("https://example.com/hook",
        watched: [{:model, "bert-base-uncased"}],
        domains: [:repo],
        token: "hf_xxx")

      # Enable/disable a webhook
      {:ok, webhook} = HfHub.Webhooks.enable("webhook-id", token: "hf_xxx")
      {:ok, webhook} = HfHub.Webhooks.disable("webhook-id", token: "hf_xxx")

      # Delete a webhook
      :ok = HfHub.Webhooks.delete("webhook-id", token: "hf_xxx")
  """

  alias HfHub.{Auth, HTTP}
  alias HfHub.Webhooks.WebhookInfo

  @type domain :: :repo | :discussion

  @doc """
  Lists all webhooks for the authenticated user.

  ## Options

    * `:token` - Authentication token (required)

  ## Examples

      {:ok, webhooks} = HfHub.Webhooks.list(token: "hf_xxx")
  """
  @spec list(keyword()) :: {:ok, [WebhookInfo.t()]} | {:error, term()}
  def list(opts \\ []) do
    token = opts[:token] || get_token()

    case HTTP.get("/api/settings/webhooks", token: token) do
      {:ok, webhooks} when is_list(webhooks) ->
        {:ok, Enum.map(webhooks, &WebhookInfo.from_response/1)}

      {:ok, %{"webhooks" => webhooks}} ->
        {:ok, Enum.map(webhooks, &WebhookInfo.from_response/1)}

      error ->
        error
    end
  end

  @doc """
  Gets a webhook by ID.

  ## Options

    * `:token` - Authentication token (required)

  ## Examples

      {:ok, webhook} = HfHub.Webhooks.get("webhook-id", token: "hf_xxx")
  """
  @spec get(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def get(webhook_id, opts \\ []) do
    token = opts[:token] || get_token()

    case HTTP.get("/api/settings/webhooks/#{webhook_id}", token: token) do
      {:ok, response} -> {:ok, WebhookInfo.from_response(response)}
      error -> error
    end
  end

  @doc """
  Creates a new webhook.

  ## Arguments

    * `url` - Webhook endpoint URL

  ## Options

    * `:watched` - List of repos to watch: `[{:model, "user/repo"}, {:dataset, "name"}]`
    * `:domains` - Event domains: `[:repo, :discussion]`
    * `:secret` - Webhook secret for signature verification
    * `:token` - Authentication token (required)

  ## Examples

      {:ok, webhook} = HfHub.Webhooks.create("https://example.com/hook",
        watched: [{:model, "bert-base-uncased"}],
        domains: [:repo],
        secret: "my-secret",
        token: "hf_xxx")

      {:ok, webhook} = HfHub.Webhooks.create("https://example.com/hook",
        watched: [{:model, "bert-base-uncased"}, {:dataset, "squad"}],
        domains: [:repo, :discussion],
        token: "hf_xxx")
  """
  @spec create(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def create(url, opts \\ []) do
    token = opts[:token] || get_token()

    watched = opts[:watched] || []
    watched_payload = format_watched(watched)

    domains = opts[:domains] || [:repo]
    domains_payload = format_domains(domains)

    body =
      %{"url" => url, "watched" => watched_payload, "domains" => domains_payload}
      |> maybe_put("secret", opts[:secret])

    case HTTP.post("/api/settings/webhooks", body, token: token) do
      {:ok, response} -> {:ok, WebhookInfo.from_response(response)}
      error -> error
    end
  end

  @doc """
  Updates a webhook.

  ## Options

    * `:url` - New webhook endpoint URL
    * `:watched` - New list of repos to watch
    * `:domains` - New event domains
    * `:secret` - New webhook secret
    * `:token` - Authentication token (required)

  ## Examples

      {:ok, webhook} = HfHub.Webhooks.update("webhook-id",
        url: "https://new-url.com/hook",
        token: "hf_xxx")

      {:ok, webhook} = HfHub.Webhooks.update("webhook-id",
        watched: [{:model, "gpt2"}],
        token: "hf_xxx")
  """
  @spec update(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def update(webhook_id, opts \\ []) do
    token = opts[:token] || get_token()

    body =
      %{}
      |> maybe_put("url", opts[:url])
      |> maybe_put("watched", format_watched_opt(opts[:watched]))
      |> maybe_put("domains", format_domains_opt(opts[:domains]))
      |> maybe_put("secret", opts[:secret])

    case HTTP.patch("/api/settings/webhooks/#{webhook_id}", body, token: token) do
      {:ok, response} -> {:ok, WebhookInfo.from_response(response)}
      error -> error
    end
  end

  @doc """
  Enables a webhook.

  ## Options

    * `:token` - Authentication token (required)

  ## Examples

      {:ok, webhook} = HfHub.Webhooks.enable("webhook-id", token: "hf_xxx")
  """
  @spec enable(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def enable(webhook_id, opts \\ []) do
    token = opts[:token] || get_token()

    case HTTP.post("/api/settings/webhooks/#{webhook_id}/enable", %{}, token: token) do
      {:ok, response} -> {:ok, WebhookInfo.from_response(response)}
      error -> error
    end
  end

  @doc """
  Disables a webhook.

  ## Options

    * `:token` - Authentication token (required)

  ## Examples

      {:ok, webhook} = HfHub.Webhooks.disable("webhook-id", token: "hf_xxx")
  """
  @spec disable(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def disable(webhook_id, opts \\ []) do
    token = opts[:token] || get_token()

    case HTTP.post("/api/settings/webhooks/#{webhook_id}/disable", %{}, token: token) do
      {:ok, response} -> {:ok, WebhookInfo.from_response(response)}
      error -> error
    end
  end

  @doc """
  Deletes a webhook.

  ## Options

    * `:missing_ok` - Don't error if webhook doesn't exist (default: false)
    * `:token` - Authentication token (required)

  ## Examples

      :ok = HfHub.Webhooks.delete("webhook-id", token: "hf_xxx")
      :ok = HfHub.Webhooks.delete("maybe-exists", missing_ok: true, token: "hf_xxx")
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(webhook_id, opts \\ []) do
    token = opts[:token] || get_token()
    missing_ok = Keyword.get(opts, :missing_ok, false)

    case HTTP.delete("/api/settings/webhooks/#{webhook_id}", token: token) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, :not_found} when missing_ok -> :ok
      error -> error
    end
  end

  # Private helpers

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp format_watched(watched) do
    Enum.map(watched, fn
      {type, name} -> %{"type" => Atom.to_string(type), "name" => name}
      %{"type" => _, "name" => _} = item -> item
      %{type: type, name: name} -> %{"type" => Atom.to_string(type), "name" => name}
    end)
  end

  defp format_watched_opt(nil), do: nil
  defp format_watched_opt(watched), do: format_watched(watched)

  defp format_domains(domains) do
    Enum.map(domains, &Atom.to_string/1)
  end

  defp format_domains_opt(nil), do: nil
  defp format_domains_opt(domains), do: format_domains(domains)

  defp get_token do
    case Auth.get_token() do
      {:ok, token} -> token
      _ -> nil
    end
  end
end
