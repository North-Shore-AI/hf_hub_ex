# Exclude live integration tests by default
# Run with: mix test --include live
ExUnit.start(exclude: [:live])
