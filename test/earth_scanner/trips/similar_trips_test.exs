defmodule EarthScanner.Trips.SimilarTripsTest do
  use EarthScanner.DataCase, async: true
  @moduletag :skip
  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip

  defp admin_fixture do
    {:ok, admin} =
      EarthScanner.Accounts.register_user(%{
        "username" => "admin_#{System.unique_integer([:positive])}",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Admin",
        "last_name" => "User",
        "email" => "admin_#{System.unique_integer([:positive])}@example.com",
        "birthdate" => "1990-01-01",
        "nationality" => "TR",
        "residence_address" => "Admin Street",
        "phone_number" => "+905551111111"
      })

    admin
  end

  describe "similar trips" do
    # FR-17: System finds and displays up to 5 similar trips matching city and price
    test "find_similar_trips returns up to 5 similar trips by city and price" do
      admin = admin_fixture()

      attrs = %{
        "transport_mode" => "plane",
        "source_city" => "Tallinn",
        "destination_city" => "Paris",
        "departure_time" => "2026-11-20T10:00:00Z",
        "arrival_time" => "2026-11-20T13:00:00Z",
        "price" => "100.0",
        "co2_level" => "200",
        "available_tickets" => "50",
        "dates" => "2026-11-21"
      }

      {:ok, trip} = Trips.create_trip(admin, attrs)

      # Insert 6 similar trips (should only return 5)
      for i <- 1..6 do
        Trips.create_trip(
          admin,
          Map.merge(attrs, %{"price" => "#{100 + i}", "dates" => "2026-11-2#{i}"})
        )
      end

      similar = Trips.find_similar_trips(trip)
      assert length(similar) == 5

      assert Enum.all?(similar, fn t ->
               t.source_city == "Tallinn" and t.destination_city == "Paris"
             end)
    end

    # FR-17: System returns empty list when no similar trips exist
    test "find_similar_trips returns [] if no matches" do
      admin = admin_fixture()

      attrs = %{
        "transport_mode" => "plane",
        "source_city" => "Tallinn",
        "destination_city" => "Paris",
        "departure_time" => "2025-11-20T10:00:00Z",
        "arrival_time" => "2025-11-20T13:00:00Z",
        "price" => "100.0",
        "co2_level" => "200",
        "available_tickets" => "50",
        "dates" => "2025-11-21"
      }

      {:ok, trip} = Trips.create_trip(admin, attrs)
      # No other trips
      assert Trips.find_similar_trips(trip) == []
    end
  end
end
