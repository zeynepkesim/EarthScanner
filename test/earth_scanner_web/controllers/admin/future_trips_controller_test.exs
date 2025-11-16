defmodule EarthScannerWeb.Admin.FutureTripsControllerTest do
  use EarthScannerWeb.ConnCase

  alias EarthScanner.Trips
  alias EarthScanner.Accounts

  defp admin_fixture(attrs \\ %{}) do
    unique_email = "admin_#{System.unique_integer([:positive])}@example.com"
    unique_username = "admin_user_#{System.unique_integer([:positive])}"

    {:ok, admin} =
      Accounts.register_user(
        Map.merge(
          %{
            "username" => unique_username,
            "password" => "Password123!",
            "password_confirmation" => "Password123!",
            "name" => "Admin",
            "last_name" => "User",
            "email" => unique_email,
            "birthdate" => "1990-01-01",
            "nationality" => "TR",
            "residence_address" => "Admin Street",
            "phone_number" => "+905551111111"
          },
          attrs
        )
      )

    alias EarthScanner.Repo
    admin = Ecto.Changeset.change(admin, role: "admin") |> Repo.update!()

    admin
  end

  defp base_trip_attrs do
    %{
      "picture_url" => "https://example.com/pic.jpg",
      "transport_mode" => "plane",
      "price" => "150.0",
      "co2_level" => "200",
      "available_tickets" => "50",
      "arrival_time" => "2025-11-20T13:00:00Z"
    }
  end

  test "FR-31: GET /admin/future-trips shows only admin's future trips and provides actions", %{conn: conn} do
    admin = admin_fixture(%{"username" => "admin1", "email" => "admin1@example.com"})
    other = admin_fixture(%{"username" => "adminG", "email" => "adming@example.com"})

    {:ok, _} =
      Trips.create_trip(admin, Map.merge(base_trip_attrs(), %{"departure_time" => "2030-01-01T10:00:00Z", "arrival_time" => "2030-01-01T13:00:00Z", "source_city" => "FutureA", "destination_city" => "DestA", "dates" => "2030-01-01"}))

    {:ok, _} =
      Trips.create_trip(admin, Map.merge(base_trip_attrs(), %{"departure_time" => "2031-06-01T10:00:00Z", "arrival_time" => "2031-06-01T13:00:00Z", "source_city" => "FutureB", "destination_city" => "DestB", "dates" => "2031-06-01"}))

    {:ok, _} =
      Trips.create_trip(other, Map.merge(base_trip_attrs(), %{"departure_time" => "2030-05-01T10:00:00Z", "arrival_time" => "2030-05-01T13:00:00Z", "source_city" => "OtherFuture", "destination_city" => "DestOther", "dates" => "2030-05-01"}))

    # simulate logged-in admin by setting session user_id
    conn = init_test_session(conn, user_id: admin.id)

    conn = get(conn, "/admin/future-trips")
    body = html_response(conn, 200)

    assert body =~ "FutureA" or body =~ "DestA"
    assert body =~ "FutureB" or body =~ "DestB"
    refute body =~ "OtherFuture" or body =~ "DestOther"

    # ensure actions exist: View, Edit, Delete (text-based check)
    assert body =~ "View"
    assert body =~ "Edit"
    assert body =~ "Delete"
  end

  test "FR-31: GET /admin/future-trips shows empty state when no future trips", %{conn: conn} do
    admin = admin_fixture(%{"username" => "adminEmptyFuture", "email" => "adminemptyfuture@example.com"})
    conn = init_test_session(conn, user_id: admin.id)

    conn = get(conn, "/admin/future-trips")
    body = html_response(conn, 200)

    assert body =~ "No future trips scheduled"
  end

  test "FR-31: GET /admin/future-trips/:id shows trip details", %{conn: conn} do
    admin = admin_fixture(%{"username" => "adminShowFuture", "email" => "adminshowfuture@example.com"})

    {:ok, trip} =
      Trips.create_trip(admin, Map.merge(base_trip_attrs(), %{"departure_time" => "2030-01-01T10:00:00Z", "arrival_time" => "2030-01-01T13:00:00Z", "source_city" => "FutureShowCity", "destination_city" => "FutureShowDest", "dates" => "2030-01-01"}))

    conn = init_test_session(conn, user_id: admin.id)
    conn = get(conn, "/admin/future-trips/#{trip.id}")
    body = html_response(conn, 200)

    assert body =~ "FutureShowCity"
    assert body =~ "FutureShowDest"
    assert body =~ "Trip Details"
    assert body =~ "$150.0"
    assert body =~ "Edit Trip"
    assert body =~ "Delete Trip"
  end

  test "FR-31: GET /admin/future-trips requires admin role", %{conn: conn} do
    # Create regular user (non-admin)
    {:ok, user} =
      Accounts.register_user(%{
        "username" => "regular_user_future",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Regular",
        "last_name" => "User",
        "email" => "regularfuture@example.com",
        "birthdate" => "1990-01-01",
        "nationality" => "TR",
        "residence_address" => "Regular Street",
        "phone_number" => "+905551111113"
      })

    conn = init_test_session(conn, user_id: user.id)
    conn = get(conn, "/admin/future-trips")

    # Should redirect or return 403/401
    assert conn.status in [302, 401, 403]
  end

  test "FR-31: GET /admin/future-trips orders trips by departure time ASC", %{conn: conn} do
    admin = admin_fixture(%{"username" => "adminOrderFuture", "email" => "adminorderfuture@example.com"})

    {:ok, trip1} =
      Trips.create_trip(admin, Map.merge(base_trip_attrs(), %{"departure_time" => "2035-01-01T10:00:00Z", "arrival_time" => "2035-01-01T13:00:00Z", "source_city" => "FarCity", "destination_city" => "DestFar", "dates" => "2035-01-01"}))

    {:ok, trip2} =
      Trips.create_trip(admin, Map.merge(base_trip_attrs(), %{"departure_time" => "2030-01-01T10:00:00Z", "arrival_time" => "2030-01-01T13:00:00Z", "source_city" => "SoonCity", "destination_city" => "DestSoon", "dates" => "2030-01-01"}))

    conn = init_test_session(conn, user_id: admin.id)
    conn = get(conn, "/admin/future-trips")
    body = html_response(conn, 200)

    # SoonCity should appear before FarCity (ASC order)
    soon_pos = :binary.match(body, "SoonCity") |> elem(0)
    far_pos = :binary.match(body, "FarCity") |> elem(0)

    assert soon_pos < far_pos
  end

  test "FR-31: GET /admin/future-trips shows navigation button to past trips", %{conn: conn} do
    admin = admin_fixture(%{"username" => "adminNav", "email" => "adminnav@example.com"})
    conn = init_test_session(conn, user_id: admin.id)

    conn = get(conn, "/admin/future-trips")
    body = html_response(conn, 200)

    assert body =~ "View Past Trips" or body =~ "/admin/past-trips"
  end
end
