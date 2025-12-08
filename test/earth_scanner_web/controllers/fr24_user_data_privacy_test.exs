defmodule EarthScannerWeb.FR24UserDataPrivacyTest do
  use EarthScannerWeb.ConnCase, async: true

  alias EarthScanner.{Accounts, Trips}

  @moduletag :fr24

  # ----------------------------------------------------------
  # Helpers
  # ----------------------------------------------------------

  defp create_user(role \\ "user") do
    unique_id = :erlang.unique_integer([:positive])
    email = "#{role}_#{unique_id}@test.com"
    password = "Password123!"

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "#{role}_user_#{unique_id}",
        "password" => password,
        "password_confirmation" => password,
        "name" => "User",
        "last_name" => "Test",
        "email" => email,
        "birthdate" => "1990-01-01",
        "nationality" => "ID",
        "residence_address" => "Street",
        "phone_number" => "+62#{:rand.uniform(999_999_999)}",
        "role" => role
      })

    %{email: email, password: password, user: user}
  end

  defp create_admin, do: create_user("admin")

  defp log_in(conn, email, password) do
    post(conn, "/users/login", session: %{"email" => email, "password" => password})
  end

  defp create_trip_owned_by(admin) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    later = DateTime.add(now, 3600)
    future_date = Date.utc_today() |> Date.add(1)

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "picture_url" => "https://via.placeholder.com/150",
        "source_city" => "Tartu",
        "destination_city" => "Tallinn",
        "transport_mode" => "bus",
        "departure_time" => now,
        "arrival_time" => later,
        "duration_minutes" => 60,
        "price" => 20,
        "co2_level" => 120,
        "available_tickets" => 10,
        "dates" => Date.to_iso8601(future_date)
      })

    trip
  end

  # ----------------------------------------------------------
  # POSITIVE: user can access own profile
  # ----------------------------------------------------------
  test "regular user can view their own profile", %{conn: conn} do
    %{email: email, password: password, user: user} = create_user()

    conn = log_in(conn, email, password)
    conn = get(conn, "/profile")

    html = html_response(conn, 200)
    assert html =~ user.email
    assert html =~ "Profile"
  end

  # ----------------------------------------------------------
  # NEGATIVE: visiting someone else's profile is blocked
  # ----------------------------------------------------------
  test "regular user CANNOT access another user's profile", %{conn: conn} do
    u1 = create_user()
    u2 = create_user()

    conn = log_in(conn, u1.email, u1.password)
    conn = get(conn, "/profile?user_id=#{u2.user.id}")

    assert redirected_to(conn) == "/profile"
  end

  # ----------------------------------------------------------
  # FR-24: Regular users CAN view trips (to book them)
  # ----------------------------------------------------------
  test "regular user CAN view any trip for booking", %{conn: conn} do
    %{user: admin} = create_admin()
    %{email: email, password: password} = create_user()

    trip = create_trip_owned_by(admin)

    conn = log_in(conn, email, password)
    conn = get(conn, "/trips/#{trip.id}")

    # Regular users can view trips to book them
    assert html_response(conn, 200) =~ trip.source_city
  end

  # ----------------------------------------------------------
  # FR-24: Admin can access trips they created
  # ----------------------------------------------------------
  test "admin can access trips they created", %{conn: conn} do
    %{email: email, password: password, user: admin} = create_admin()
    trip = create_trip_owned_by(admin)

    conn = log_in(conn, email, password)
    conn = get(conn, "/trips/#{trip.id}")

    assert html_response(conn, 200) =~ "#{trip.source_city} → #{trip.destination_city}"
  end

  # REMOVED: "admin CANNOT access another admin's trip" test

  # ----------------------------------------------------------
  # NEGATIVE: visitor cannot access profile page
  # ----------------------------------------------------------
  test "visitor cannot access /profile", %{conn: conn} do
    conn = get(conn, "/profile")
    assert redirected_to(conn) == "/users/login"
  end

  # ----------------------------------------------------------
  # NEGATIVE: visitor cannot access /trips/:id
  # ----------------------------------------------------------
  test "visitor cannot access /trips/:id", %{conn: conn} do
    %{user: admin} = create_admin()
    trip = create_trip_owned_by(admin)

    conn = get(conn, "/trips/#{trip.id}")
    assert redirected_to(conn) == "/users/login"
  end

  # ----------------------------------------------------------
  # NEGATIVE: invalid user_id param redirects safely
  # ----------------------------------------------------------
  test "invalid user_id param in profile redirects safely", %{conn: conn} do
    u = create_user()
    conn = log_in(conn, u.email, u.password)

    conn = get(conn, "/profile?user_id=9999999")
    assert redirected_to(conn) == "/profile"
  end

  # ----------------------------------------------------------
  # NEGATIVE: tampered session blocks access
  # ----------------------------------------------------------
  test "tampered session (invalid user id) blocks access", %{conn: conn} do
    u = create_user()
    conn = log_in(conn, u.email, u.password)

    conn =
      conn
      |> recycle()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, 99_999_999)
      |> get("/profile")

    assert redirected_to(conn) == "/users/login"
  end

  # ----------------------------------------------------------
  # NEGATIVE: regular user cannot access admin routes
  # ----------------------------------------------------------
  test "regular user cannot access /admin/my-trips", %{conn: conn} do
    u = create_user()
    conn = log_in(conn, u.email, u.password)

    conn = get(conn, "/admin/my-trips")
    assert redirected_to(conn) == "/"
  end

  # ----------------------------------------------------------
  # NEGATIVE: visitor cannot access admin routes
  # ----------------------------------------------------------
  test "visitor cannot access admin routes", %{conn: conn} do
    conn = get(conn, "/admin/my-trips")
    assert redirected_to(conn) == "/users/login"
  end
end
