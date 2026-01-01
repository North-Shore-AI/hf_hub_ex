# Prompt 01: HTTP Write Methods (POST, PUT, DELETE, PATCH)

## Context

You are implementing HTTP write methods for the `hf_hub_ex` Elixir library, a port of Python's `huggingface_hub`. The library currently only supports GET and HEAD requests. All subsequent features (repository management, uploads, etc.) depend on having write methods.

## Required Reading

**Read these files first:**
```
lib/hf_hub/http.ex           # Current HTTP implementation
lib/hf_hub/config.ex         # Configuration (endpoint, timeouts)
lib/hf_hub/auth.ex           # Token/auth header handling
lib/hf_hub/errors.ex         # Error types
test/hf_hub/http_test.exs    # Current HTTP tests
```

**Reference documentation:**
```
docs/20251231/gap-analysis/docs.md
docs/20251231/repo-management/docs.md
docs/20251231/upload-api/docs.md
```

## Task

Extend `HfHub.HTTP` to support POST, PUT, DELETE, and PATCH methods with JSON body support.

## Implementation Requirements

### 1. Add Functions to `HfHub.HTTP`

```elixir
@doc """
Performs a POST request with JSON body.

## Options
- `:token` - Authentication token
- `:headers` - Additional headers
- `:body` - Request body (will be JSON encoded)

## Examples

    {:ok, response} = HfHub.HTTP.post("/api/repos/create", %{name: "my-repo"}, token: token)
"""
@spec post(String.t(), map() | nil, keyword()) :: {:ok, map()} | {:error, term()}
def post(path, body \\ nil, opts \\ [])

@doc """
Performs a PUT request with JSON body.
"""
@spec put(String.t(), map() | nil, keyword()) :: {:ok, map()} | {:error, term()}
def put(path, body \\ nil, opts \\ [])

@doc """
Performs a PATCH request with JSON body.
"""
@spec patch(String.t(), map() | nil, keyword()) :: {:ok, map()} | {:error, term()}
def patch(path, body \\ nil, opts \\ [])

@doc """
Performs a DELETE request.

DELETE requests typically don't have a body but may return data.
"""
@spec delete(String.t(), keyword()) :: :ok | {:ok, map()} | {:error, term()}
def delete(path, opts \\ [])

@doc """
Performs a POST request expecting no response body.

Used for actions that return 200/204 with no content.
"""
@spec post_action(String.t(), map() | nil, keyword()) :: :ok | {:error, term()}
def post_action(path, body \\ nil, opts \\ [])
```

### 2. Implementation Details

- All write methods must include `Content-Type: application/json` header
- All write methods must include auth headers when token provided
- POST/PUT/PATCH must JSON-encode the body using Jason
- Handle response status codes:
  - 200, 201: Success with body
  - 204: Success no content
  - 400: Bad request (return error with message)
  - 401: Unauthorized
  - 403: Forbidden
  - 404: Not found
  - 409: Conflict
  - 422: Validation error
  - 5xx: Server error

### 3. Error Handling

Map HTTP errors to appropriate `HfHub.Errors` exceptions:
- 400 → `{:error, %HfHub.Errors.BadRequest{message: body}}`
- 401 → `{:error, :unauthorized}`
- 403 → `{:error, :forbidden}`
- 404 → `{:error, :not_found}`
- 409 → `{:error, {:conflict, body}}`
- 422 → `{:error, {:validation, body}}`
- 5xx → `{:error, {:server_error, status, body}}`

## Test Requirements (TDD)

Create tests in `test/hf_hub/http_test.exs` using Bypass:

```elixir
describe "post/3" do
  test "sends JSON body and returns decoded response"
  test "includes auth header when token provided"
  test "handles 201 created response"
  test "handles 400 bad request"
  test "handles 401 unauthorized"
  test "handles 409 conflict"
  test "handles 422 validation error"
  test "handles nil body"
end

describe "put/3" do
  test "sends JSON body"
  test "handles 200 response"
  test "handles 204 no content"
end

describe "patch/3" do
  test "sends partial update"
  test "handles 200 response"
end

describe "delete/2" do
  test "returns :ok on 204"
  test "returns {:ok, body} on 200 with body"
  test "handles 404 not found"
end

describe "post_action/3" do
  test "returns :ok on 200"
  test "returns :ok on 204"
end
```

## Quality Requirements

After implementation:
1. Run `mix test` - all tests must pass
2. Run `mix format` - code must be formatted
3. Run `mix credo --strict` - no warnings
4. Run `mix dialyzer` - no errors

## Changelog Entry

Add to `CHANGELOG.md` under `## [0.1.3] - Unreleased`:

```markdown
### Added
- `HfHub.HTTP.post/3` - POST requests with JSON body
- `HfHub.HTTP.put/3` - PUT requests with JSON body
- `HfHub.HTTP.patch/3` - PATCH requests with JSON body
- `HfHub.HTTP.delete/2` - DELETE requests
- `HfHub.HTTP.post_action/3` - POST requests expecting no response body
```

## README Update

No README update needed for internal HTTP methods.

## Completion Checklist

- [ ] `post/3` implemented with tests
- [ ] `put/3` implemented with tests
- [ ] `patch/3` implemented with tests
- [ ] `delete/2` implemented with tests
- [ ] `post_action/3` implemented with tests
- [ ] Error handling for all status codes
- [ ] `mix test` passes
- [ ] `mix format` passes
- [ ] `mix credo --strict` passes
- [ ] `mix dialyzer` passes
- [ ] CHANGELOG.md updated
