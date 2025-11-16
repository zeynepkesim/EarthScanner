defmodule EarthScannerWeb.Admin.PastTripsControllerTest do
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

  test "GET /admin/past-trips shows only admin's past trips", %{conn: conn} do
    admin = admin_fixture(%{"username" => "adminX", "email" => "adminx@example.com"})
    other = admin_fixture(%{"username" => "adminY", "email" => "adminy@example.com"})

    {:ok, _} =
      Trips.create_trip(admin, Map.merge(base_trip_attrs(), %{"departure_time" => "2020-01-01T10:00:00Z", "source_city" => "PastA", "destination_city" => "DestA", "dates" => "2020-01-01"}))

    {:ok, _} =
      Trips.create_trip(admin, Map.merge(base_trip_attrs(), %{"departure_time" => "2021-06-01T10:00:00Z", "source_city" => "PastB", "destination_city" => "DestB", "dates" => "2021-06-01"}))

    {:ok, _} =
      Trips.create_trip(other, Map.merge(base_trip_attrs(), %{"departure_time" => "2020-05-01T10:00:00Z", "source_city" => "OtherPast", "destination_city" => "DestOther", "dates" => "2020-05-01"}))

    # simulate logged-in admin by setting session user_id
    conn = init_test_session(conn, user_id: admin.id)

    conn = get(conn, "/admin/past-trips")
    body = html_response(conn, 200)

    assert body =~ "PastA" or body =~ "DestA"
    assert body =~ "PastB" or body =~ "DestB"
    refute body =~ "OtherPast" or body =~ "DestOther"
  end
end
