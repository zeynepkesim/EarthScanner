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

  test "GET /admin/future-trips shows only admin's future trips and provides actions", %{conn: conn} do
    admin = admin_fixture(%{"username" => "adminF", "email" => "adminf@example.com"})
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
end
