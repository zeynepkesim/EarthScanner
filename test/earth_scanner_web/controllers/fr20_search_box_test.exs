defmodule EarthScannerWeb.FR20SearchBoxTest do
  use EarthScannerWeb.ConnCase, async: true

  alias EarthScanner.{Accounts, Trips}

  @moduletag :fr20

  # ----------------------------------------------------
  # Helpers
  # ----------------------------------------------------

  defp create_user(_) do
    email = "user_" <> Integer.to_string(:erlang.unique_integer([:positive])) <> "@example.com"
    password = "Password123!"

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "user_" <> Integer.to_string(:rand.uniform(1000)),
        "password" => password,
        "password_confirmation" => password,
        "name" => "User",
        "last_name" => "Test",
        "email" => email,
        "birthdate" => "1999-01-01",
        "nationality" => "ID",
        "residence_address" => "User St",
        "phone_number" => "+62#{:rand.uniform(999_999_999)}"
      })

    %{user: user, email: email, password: password}
  end

  defp create_admin(_) do
    email = "admin_" <> Integer.to_string(:erlang.unique_integer([:positive])) <> "@example.com"

    {:ok, admin} =
      Accounts.register_user(%{
        "username" => "admin_" <> Integer.to_string(:rand.uniform(1000)),
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Admin",
        "last_name" => "User",
        "email" => email,
        "birthdate" => "1985-01-01",
        "nationality" => "ID",
        "residence_address" => "Admin St",
        "phone_number" => "+62#{:rand.uniform(999_999_999)}",
        "role" => "admin"
      })

    %{user: admin, email: email, password: "Password123!"}
  end

  defp log_in(conn, email, password) do
    post(conn, "/users/login", session: %{"email" => email, "password" => password})
  end

  defp create_future_trip do
    # Create admin using the proper helper
    %{user: admin} = create_admin(nil)

    future_date = Date.add(Date.utc_today(), 1)
    departure = DateTime.utc_now() |> DateTime.add(3600, :second)
    arrival = DateTime.add(departure, 3600, :second)

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "picture_url" => "https://via.placeholder.com/150",
        "source_city" => "Tartu",
        "destination_city" => "Tallinn",
        "departure_time" => departure,
        "arrival_time" => arrival,
        "price" => 20,
        "available_tickets" => 5,
        "co2_level" => 100,
        "duration_minutes" => 120,
        "transport_mode" => "bus",
        "dates" => Date.to_iso8601(future_date)
      })

    trip
  end

  defp create_regular_user do
    create_user(nil)
  end

  # ----------------------------------------------------
  # UI: Search box visibility tests
  # ----------------------------------------------------

  test "regular user sees the search box on homepage", %{conn: conn} do
    %{email: email, password: password} = create_user(nil)

    conn = log_in(conn, email, password)
    conn = get(conn, "/")

    html = html_response(conn, 200)

    assert html =~ "Search Trips"
    assert html =~ "input"
    assert html =~ "name=\"source\""
    assert html =~ "name=\"destination\""
    assert html =~ "action=\"/search/results\""
  end

  test "visitor does NOT see the search box", %{conn: conn} do
    conn = get(conn, "/")
    html = html_response(conn, 200)

    refute html =~ "Search Trips"
    refute html =~ "name=\"source\""
    refute html =~ "name=\"destination\""
  end

  # ----------------------------------------------------
  # VALID SEARCH
  # ----------------------------------------------------

  test "search results show at least one trip", %{conn: conn} do
    %{email: email, password: password} = create_user(nil)
    _trip = create_future_trip()

    conn = log_in(conn, email, password)

    conn =
      get(conn, "/search/results", %{
        "source" => "Tartu",
        "destination" => "Tallinn"
      })

    html = html_response(conn, 200)
    assert html =~ "Mode:" or html =~ "Tartu" or html =~ "Tallinn"
  end

  # ----------------------------------------------------
  # NEGATIVE SEARCH CASES
  # ----------------------------------------------------

  test "empty source redirects back to /search", %{conn: conn} do
    %{email: email, password: password} = create_user(nil)
    conn = log_in(conn, email, password)

    conn =
      get(conn, "/search/results", %{
        "source" => "",
        "destination" => "Tallinn"
      })

    assert redirected_to(conn) == "/search"
  end

  test "empty destination redirects back to /search", %{conn: conn} do
    %{email: email, password: password} = create_user(nil)
    conn = log_in(conn, email, password)

    conn =
      get(conn, "/search/results", %{
        "source" => "Tartu",
        "destination" => ""
      })

    assert redirected_to(conn) == "/search"
  end

  test "missing parameters redirect back to /search", %{conn: conn} do
    %{email: email, password: password} = create_user(nil)
    conn = log_in(conn, email, password)

    conn = get(conn, "/search/results")
    assert redirected_to(conn) == "/search"
  end

  test "invalid city names return zero results safely", %{conn: conn} do
    %{email: email, password: password} = create_user(nil)

    conn = log_in(conn, email, password)

    conn =
      get(conn, "/search/results", %{
        "source" => "INVALIDCITY",
        "destination" => "FAKECITY"
      })

    html = html_response(conn, 200)
    refute html =~ "Mode:"
  end

  # ----------------------------------------------------
  # PAST TRIPS MUST NOT APPEAR
  # ----------------------------------------------------

  test "past trips do NOT appear in search results", %{conn: conn} do
    %{email: email, password: password} = create_regular_user()

    # Create admin to own the past trip
    %{user: admin} = create_admin(nil)

    # Create a past trip
    past_trip_date = Date.add(Date.utc_today(), -5)
    past_departure = DateTime.utc_now() |> DateTime.add(-3600 * 24 * 5, :second)
    past_arrival = DateTime.add(past_departure, 3600, :second)

    Trips.create_trip(admin, %{
      "picture_url" => "https://via.placeholder.com/150",
      "source_city" => "PastCity",
      "destination_city" => "FutureCity",
      "transport_mode" => "bus",
      "departure_time" => past_departure,
      "arrival_time" => past_arrival,
      "duration_minutes" => 60,
      "price" => 10,
      "co2_level" => 90,
      "available_tickets" => 3,
      "dates" => Date.to_iso8601(past_trip_date)
    })

    conn = log_in(conn, email, password)

    conn =
      get(conn, "/search/results", %{
        "source" => "PastCity",
        "destination" => "FutureCity"
      })

    html = html_response(conn, 200)
    refute html =~ "Mode:"
  end

  # ----------------------------------------------------
  # Unauthorized search behavior
  # ----------------------------------------------------

  test "visitor searching trips is redirected to login", %{conn: conn} do
    conn =
      get(conn, "/search/results", %{
        "source" => "Tartu",
        "destination" => "Tallinn"
      })

    assert redirected_to(conn) == "/users/login"
  end
end
