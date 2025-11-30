defmodule EarthScannerWeb.Notifications.Fr27TripReminderNotificationsTestClean do
  use EarthScannerWeb.ConnCase, async: true

  alias EarthScanner.Trips
  alias EarthScanner.Repo

  setup %{conn: conn} do
    {:ok, admin} = create_admin()
    {:ok, user} = create_regular_user(%{username: "notif_user", email: "notif@test.com"})

    {:ok, conn: conn, admin: admin, user: user}
  end

  test "FR-27: shows reminder when user has a purchase within 24h", %{
    conn: conn,
    admin: admin,
    user: user
  } do
    departure_dt = DateTime.add(DateTime.utc_now(), 2 * 3600, :second)
    arrival_dt = DateTime.add(departure_dt, 2 * 3600, :second)

    attrs = %{
      "transport_mode" => "plane",
      "source_city" => "Tallinn",
      "destination_city" => "Paris",
      "departure_time" => DateTime.to_iso8601(departure_dt),
      "arrival_time" => DateTime.to_iso8601(arrival_dt),
      "price" => "150.0",
      "co2_level" => "200",
      "available_tickets" => "10",
      "dates" => Date.to_iso8601(Date.utc_today())
    }

    {:ok, trip} = Trips.create_trip(admin, attrs)
    instance = hd(trip.instances)

    assert {:ok, _purchase} = Trips.purchase_trip_instance(user, instance.id)

    conn = log_in_user(conn, user)
    conn = get(conn, "/notifications")

    body = html_response(conn, 200)
    assert body =~ "Reminder: departs within 24 hours"
    assert body =~ "Tallinn"
    assert body =~ "Paris"
  end

  test "FR-27: shows empty state when no due notifications", %{
    conn: conn,
    admin: admin,
    user: user
  } do
    departure_dt = DateTime.add(DateTime.utc_now(), 10 * 24 * 3600, :second)
    arrival_dt = DateTime.add(departure_dt, 2 * 3600, :second)

    attrs = %{
      "transport_mode" => "plane",
      "source_city" => "Madrid",
      "destination_city" => "Rome",
      "departure_time" => DateTime.to_iso8601(departure_dt),
      "arrival_time" => DateTime.to_iso8601(arrival_dt),
      "price" => "120.0",
      "co2_level" => "150",
      "available_tickets" => "10",
      "dates" => Date.to_iso8601(Date.add(Date.utc_today(), 10))
    }

    {:ok, trip} = Trips.create_trip(admin, attrs)
    instance = hd(trip.instances)

    assert {:ok, _purchase} = Trips.purchase_trip_instance(user, instance.id)

    conn = log_in_user(conn, user)
    conn = get(conn, "/notifications")

    body = html_response(conn, 200)
    assert body =~ "No notifications at this time."
  end

  # Helpers
  defp create_admin(), do: create_admin(%{})

  defp create_admin(attrs) do
    default_attrs = %{
      username: "admin_user",
      password: "password123",
      password_confirmation: "password123",
      email: "admin_user@test.com",
      phone_number: "1234567890",
      role: "admin"
    }

    merged = Map.merge(default_attrs, attrs)

    %EarthScanner.Accounts.User{}
    |> EarthScanner.Accounts.User.admin_changeset(merged)
    |> Repo.insert()
  end

  defp create_regular_user(), do: create_regular_user(%{})

  defp create_regular_user(attrs) do
    default_attrs = %{
      username: "regular_user",
      password: "password123",
      password_confirmation: "password123",
      name: "John",
      last_name: "Doe",
      email: "regular_user@test.com",
      birthdate: ~D[1990-01-01],
      nationality: "US",
      residence_address: "123 Main St",
      phone_number: "0987654321"
    }

    merged = Map.merge(default_attrs, attrs)

    %EarthScanner.Accounts.User{}
    |> EarthScanner.Accounts.User.registration_changeset(merged)
    |> Repo.insert()
  end

  defp log_in_user(conn, user) do
    conn
    |> init_test_session(%{})
    |> put_session(:user_id, user.id)
    |> EarthScannerWeb.FetchCurrentUser.call([])
  end
end
