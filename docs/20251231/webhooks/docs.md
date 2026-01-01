# Webhooks API

## Overview

Webhooks enable automated notifications when events occur on HuggingFace Hub repositories.

## Python Reference

### Source File
`huggingface_hub/src/huggingface_hub/hf_api.py`

### Functions

#### create_webhook

```python
def create_webhook(
    url: str,
    *,
    watched: List[Dict[str, str]],  # [{"type": "model", "name": "user/repo"}]
    domains: Optional[List[str]] = None,  # ["repo", "discussion"]
    secret: Optional[str] = None,
    token: Optional[str] = None,
) -> WebhookInfo
```

**API Endpoint**: `POST /api/settings/webhooks`

**Request Body**:
```json
{
  "url": "https://example.com/webhook",
  "watched": [
    {"type": "model", "name": "bert-base-uncased"},
    {"type": "dataset", "name": "squad"}
  ],
  "domains": ["repo", "discussion"],
  "secret": "optional-secret"
}
```

---

#### list_webhooks

```python
def list_webhooks(
    *,
    token: Optional[str] = None,
) -> List[WebhookInfo]
```

**API Endpoint**: `GET /api/settings/webhooks`

---

#### get_webhook

```python
def get_webhook(
    webhook_id: str,
    *,
    token: Optional[str] = None,
) -> WebhookInfo
```

**API Endpoint**: `GET /api/settings/webhooks/{id}`

---

#### update_webhook

```python
def update_webhook(
    webhook_id: str,
    *,
    url: Optional[str] = None,
    watched: Optional[List[Dict[str, str]]] = None,
    domains: Optional[List[str]] = None,
    secret: Optional[str] = None,
    token: Optional[str] = None,
) -> WebhookInfo
```

**API Endpoint**: `PATCH /api/settings/webhooks/{id}`

---

#### enable_webhook

```python
def enable_webhook(
    webhook_id: str,
    *,
    token: Optional[str] = None,
) -> WebhookInfo
```

**API Endpoint**: `POST /api/settings/webhooks/{id}/enable`

---

#### disable_webhook

```python
def disable_webhook(
    webhook_id: str,
    *,
    token: Optional[str] = None,
) -> WebhookInfo
```

**API Endpoint**: `POST /api/settings/webhooks/{id}/disable`

---

#### delete_webhook

```python
def delete_webhook(
    webhook_id: str,
    *,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `DELETE /api/settings/webhooks/{id}`

---

## Elixir Implementation Spec

### Module: `HfHub.Webhooks`

```elixir
defmodule HfHub.Webhooks do
  @moduledoc """
  Webhooks API for event notifications.
  """

  alias HfHub.Webhooks.{WebhookInfo, WatchedItem}

  @type domain :: :repo | :discussion

  @doc """
  Lists all webhooks for the authenticated user.
  """
  @spec list(keyword()) :: {:ok, [WebhookInfo.t()]} | {:error, term()}
  def list(opts \\ [])

  @doc """
  Gets a webhook by ID.
  """
  @spec get(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def get(webhook_id, opts \\ [])

  @doc """
  Creates a new webhook.

  ## Options

  - `:watched` - List of repos to watch: `[{:model, "user/repo"}, {:dataset, "name"}]`
  - `:domains` - Event domains: `[:repo, :discussion]`
  - `:secret` - Webhook secret for signature verification
  - `:token` - Authentication token (required)

  ## Examples

      {:ok, webhook} = HfHub.Webhooks.create("https://example.com/hook",
        watched: [{:model, "bert-base-uncased"}],
        domains: [:repo],
        secret: "my-secret"
      )
  """
  @spec create(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def create(url, opts \\ [])

  @doc """
  Updates a webhook.
  """
  @spec update(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def update(webhook_id, opts \\ [])

  @doc """
  Enables a webhook.
  """
  @spec enable(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def enable(webhook_id, opts \\ [])

  @doc """
  Disables a webhook.
  """
  @spec disable(String.t(), keyword()) :: {:ok, WebhookInfo.t()} | {:error, term()}
  def disable(webhook_id, opts \\ [])

  @doc """
  Deletes a webhook.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(webhook_id, opts \\ [])
end
```

### Data Structures

```elixir
defmodule HfHub.Webhooks.WebhookInfo do
  defstruct [:id, :url, :watched, :domains, :secret, :disabled, :created_at]

  @type t :: %__MODULE__{
    id: String.t(),
    url: String.t(),
    watched: [HfHub.Webhooks.WatchedItem.t()],
    domains: [:repo | :discussion],
    secret: String.t() | nil,
    disabled: boolean(),
    created_at: DateTime.t()
  }
end

defmodule HfHub.Webhooks.WatchedItem do
  defstruct [:type, :name]

  @type t :: %__MODULE__{
    type: :model | :dataset | :space | :user | :org,
    name: String.t()
  }
end
```

---

## Test Scenarios

1. List webhooks
2. Get webhook by ID
3. Create webhook for single repo
4. Create webhook for multiple repos
5. Create with secret
6. Create with specific domains
7. Update URL
8. Update watched repos
9. Enable disabled webhook
10. Disable webhook
11. Delete webhook
12. Error: create without token
13. Error: invalid URL
