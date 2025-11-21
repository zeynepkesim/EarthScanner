# FR-12
defmodule EarthScannerWeb.TripsControllerTest do
  use EarthScannerWeb.ConnCase

  alias EarthScanner.Trips
  alias EarthScanner.Purchases.Purchase
  alias EarthScanner.Repo

  setup %{conn: conn} do
    {:ok, admin} = create_admin()

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "transport_mode" => "bus",
        "source_city" => "Tallinn",
        "destination_city" => "Vilnius",
        "departure_time" => "2025-12-01T08:00:00Z",
        "arrival_time" => "2025-12-01T12:30:00Z",
        "price" => "120.00",
        "co2_level" => "95",
        "available_tickets" => "3",
        "dates" => Date.utc_today() |> Date.add(8) |> Date.to_iso8601()
      })

    {:ok, user} = create_regular_user(%{username: "trip_viewer", email: "trip_viewer@test.com"})

    {:ok, conn: conn, trip: trip, instance: hd(trip.instances), user: user}
  end

  test "FR-12: shows trip details", %{conn: conn, trip: trip} do
    conn = get(conn, ~p"/trips/#{trip.id}")

    body = html_response(conn, 200)
    assert body =~ trip.source_city
    assert body =~ trip.destination_city
    assert body =~ "Available dates"
  end

  test "FR-12: marks purchased instances in the detail view", %{conn: conn, trip: trip, instance: instance, user: user} do
    Repo.insert!(%Purchase{user_id: user.id, trip_instance_id: instance.id})

    conn = log_in_user(conn, user)
    conn = get(conn, ~p"/trips/#{trip.id}")

    assert html_response(conn, 200) =~ "Purchased"
  end

  defp create_admin(attrs \\ %{}) do
    default_attrs = %{
      username: "admin_trip",
      password: "password123",
      password_confirmation: "password123",
      email: "admin_trip@test.com",
      phone_number: "1234567890",
      role: "admin"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    %EarthScanner.Accounts.User{}
    |> EarthScanner.Accounts.User.admin_changeset(merged_attrs)
    |> Repo.insert()
  end

  defp create_regular_user(attrs \\ %{}) do
    default_attrs = %{
      username: "regular_trip",
      password: "password123",
      password_confirmation: "password123",
      name: "Jess",
      last_name: "Doe",
      email: "regular_trip@test.com",
      birthdate: ~D[1993-03-03],
      nationality: "US",
      residence_address: "123 Main St",
      phone_number: "4444444444"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    %EarthScanner.Accounts.User{}
    |> EarthScanner.Accounts.User.registration_changeset(merged_attrs)
    |> Repo.insert()
  end

  defp log_in_user(conn, user) do
    conn
    |> init_test_session(%{})
    |> put_session(:user_id, user.id)
    |> EarthScannerWeb.FetchCurrentUser.call([])
  end
end
