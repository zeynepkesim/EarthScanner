defmodule EarthScanner.TripsPastTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Accounts
  alias EarthScanner.Repo

  # Fixture to create an admin user
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

    # Force role to "admin" for tests
    admin = Ecto.Changeset.change(admin, role: "admin") |> Repo.update!()
    admin
  end

  # Base attributes for trips
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

  # Test: list past trips returns only past trips for admin and sorted descending
  test "list_past_trips_by_admin/1 returns only past trips for the admin and sorted desc" do
    admin1 = admin_fixture(%{"username" => "admin1", "email" => "admin1@example.com"})
    admin2 = admin_fixture(%{"username" => "admin2", "email" => "admin2@example.com"})

    # Past trips for admin1
    {:ok, trip_old} =
      Trips.create_trip(
        admin1,
        Map.merge(base_trip_attrs(), %{
          "departure_time" => "2020-01-01T10:00:00Z",
          "source_city" => "OldTown",
          "destination_city" => "DestOld",
          "transport_mode" => "plane",
          "dates" => "2020-01-01"
        })
      )

    {:ok, trip_newer} =
      Trips.create_trip(
        admin1,
        Map.merge(base_trip_attrs(), %{
          "departure_time" => "2021-06-01T10:00:00Z",
          "source_city" => "NewTown",
          "destination_city" => "DestNew",
          "transport_mode" => "plane",
          "dates" => "2021-06-01"
        })
      )

    # Trip for another admin (should not appear)
    {:ok, _other} =
      Trips.create_trip(
        admin2,
        Map.merge(base_trip_attrs(), %{
          "departure_time" => "2020-05-01T10:00:00Z",
          "source_city" => "OtherTown",
          "destination_city" => "DestOther",
          "transport_mode" => "plane",
          "dates" => "2020-05-01"
        })
      )

    result = Trips.list_past_trips_by_admin(admin1)

    # Positive assertions: trips exist
    assert Enum.any?(result, &(&1.id == trip_old.id))
    assert Enum.any?(result, &(&1.id == trip_newer.id))

    # Negative assertions: no trips from other admins
    refute Enum.any?(result, &(&1.admin_id != admin1.id))

    # Ensure order: newest first
    departure_times = Enum.map(result, & &1.departure_time)

    # Using NaiveDateTime.compare because trips may be NaiveDateTime
    sorted_times =
      Enum.sort(departure_times, fn a, b ->
        NaiveDateTime.compare(a, b) != :lt
      end)

    assert departure_times == sorted_times
  end
end
