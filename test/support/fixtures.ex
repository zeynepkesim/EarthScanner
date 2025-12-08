defmodule EarthScanner.Fixtures do
  @moduledoc """
  Shared test helpers for creating users and other common fixtures.

  Use these in tests to avoid duplicated fixed emails / usernames which can
  cause unique-constraint failures when tests run concurrently or in CI.
  """

  alias EarthScanner.Accounts

  @doc "Generate a globally unique email for tests"
  def unique_email(prefix \\ "user") do
    id = System.unique_integer([:positive])
    "#{prefix}_#{id}@example.com"
  end

  @doc "Generate a unique username"
  def unique_username(prefix \\ "user") do
    "#{prefix}_#{System.unique_integer([:positive])}"
  end

  @doc "Create and register an admin user. Returns {:ok, user} or {:error, changeset}."
  def admin_fixture(attrs \\ %{}) do
    email = Map.get(attrs, "email") || unique_email("admin")
    username = Map.get(attrs, "username") || unique_username("admin_user")

    params =
      Map.merge(
        %{
          "username" => username,
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "name" => Map.get(attrs, "name", "Admin"),
          "last_name" => Map.get(attrs, "last_name", "User"),
          "email" => email,
          "birthdate" => Map.get(attrs, "birthdate", "1990-01-01"),
          "nationality" => Map.get(attrs, "nationality", "US"),
          "residence_address" => Map.get(attrs, "residence_address", "Test St"),
          "phone_number" => Map.get(attrs, "phone_number", "+10000000000"),
          "role" => "admin"
        },
        attrs
      )

    Accounts.register_user(params)
  end

  @doc "Create and register a regular user. Returns {:ok, user} or {:error, changeset}."
  def user_fixture(attrs \\ %{}) do
    email = Map.get(attrs, "email") || unique_email("user")
    username = Map.get(attrs, "username") || unique_username("user")

    params =
      Map.merge(
        %{
          "username" => username,
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "name" => Map.get(attrs, "name", "Test"),
          "last_name" => Map.get(attrs, "last_name", "User"),
          "email" => email,
          "birthdate" => Map.get(attrs, "birthdate", "1995-01-01"),
          "nationality" => Map.get(attrs, "nationality", "US"),
          "residence_address" => Map.get(attrs, "residence_address", "Test St"),
          "phone_number" => Map.get(attrs, "phone_number", "+10000000000")
        },
        attrs
      )

    Accounts.register_user(params)
  end
end
