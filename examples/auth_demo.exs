#!/usr/bin/env elixir
#
# Example: Authentication with HuggingFace Hub
#
# Run with: HF_TOKEN=hf_xxx mix run examples/auth_demo.exs
#
# This example demonstrates:
# - Setting and getting auth tokens
# - Validating tokens with the API
# - Getting user information via whoami
#

IO.puts("\n=== HfHub Authentication Demo ===\n")

# Check if HF_TOKEN is set
case System.get_env("HF_TOKEN") do
  nil ->
    IO.puts("No HF_TOKEN environment variable found.")
    IO.puts("Set it with: export HF_TOKEN=hf_your_token")
    IO.puts("\nDemo will proceed with unauthenticated mode...\n")

    # Demonstrate token validation
    IO.puts("Token format validation:")
    IO.puts("  'hf_validtoken123' -> #{inspect(HfHub.Auth.validate_token("hf_validtoken123"))}")
    IO.puts("  'bad_token' -> #{inspect(HfHub.Auth.validate_token("bad_token"))}")
    IO.puts("  'hf_short' -> #{inspect(HfHub.Auth.validate_token("hf_short"))}")

  token ->
    IO.puts("Found HF_TOKEN in environment.\n")

    # Login with token validation
    IO.puts("Logging in with API validation...")

    case HfHub.Auth.login(token: token, validate: true) do
      :ok ->
        IO.puts("Login successful!\n")

        # Get user info
        case HfHub.Auth.whoami() do
          {:ok, user} ->
            IO.puts("User Information:")
            IO.puts("  Username: #{user.username}")
            IO.puts("  Email: #{user.email || "(not set)"}")
            IO.puts("  Full Name: #{user.fullname || "(not set)"}")
            IO.puts("  Organizations: #{Enum.join(user.organizations, ", ") || "(none)"}")

          {:error, reason} ->
            IO.puts("Error getting user info: #{inspect(reason)}")
        end

        # Demonstrate authenticated download
        IO.puts("\nTesting authenticated download...")

        case HfHub.Download.hf_hub_download(
               repo_id: "bert-base-uncased",
               filename: "config.json"
             ) do
          {:ok, path} ->
            IO.puts("Downloaded to: #{path}")

          {:error, reason} ->
            IO.puts("Download error: #{inspect(reason)}")
        end

        # Logout
        IO.puts("\nLogging out...")
        :ok = HfHub.Auth.logout()
        IO.puts("Token cleared: #{inspect(HfHub.Auth.get_token())}")

      {:error, reason} ->
        IO.puts("Login failed: #{inspect(reason)}")
        IO.puts("Check that your token is valid and has the necessary permissions.")
    end
end

IO.puts("\n=== Demo Complete ===\n")
