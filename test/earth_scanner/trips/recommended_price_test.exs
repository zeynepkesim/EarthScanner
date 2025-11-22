# FR-34: Recommended Price
defmodule EarthScanner.Trips.RecommendedPriceTest do
  use EarthScanner.DataCase, async: true
  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip

  describe "recommended price calculation" do
    # FR-34: System calculates recommended price based on CO2 level and transport mode
    test "recommended price is set on trip creation (plane)" do
      admin = insert_admin()

      attrs = %{
        "transport_mode" => "plane",
        "source_city" => "Tallinn",
        "destination_city" => "Paris",
        "departure_time" => "2025-11-20T10:00:00Z",
        "arrival_time" => "2025-11-20T13:00:00Z",
        "price" => "150.0",
        "co2_level" => "200",
        "available_tickets" => "50",
        "dates" => "2025-11-21"
      }

      {:ok, trip} = Trips.create_trip(admin, attrs)
      assert trip.recommended_price == Decimal.from_float(200 * 0.15)
    end

    # FR-34: Train transport applies correct recommended price factor
    test "recommended price is set on trip creation (train)" do
      admin = insert_admin()

      attrs = %{
        "transport_mode" => "train",
        "source_city" => "Tallinn",
        "destination_city" => "Riga",
        "departure_time" => "2025-11-20T10:00:00Z",
        "arrival_time" => "2025-11-20T13:00:00Z",
        "price" => "100.0",
        "co2_level" => "80",
        "available_tickets" => "30",
        "dates" => "2025-11-21"
      }

      {:ok, trip} = Trips.create_trip(admin, attrs)
      assert trip.recommended_price == Decimal.from_float(80 * 0.05)
    end

    # FR-34: Bus transport applies correct recommended price factor
    test "recommended price is set on trip creation (bus)" do
      admin = insert_admin()

      attrs = %{
        "transport_mode" => "bus",
        "source_city" => "Berlin",
        "destination_city" => "Prague",
        "departure_time" => "2025-11-20T10:00:00Z",
        "arrival_time" => "2025-11-20T13:00:00Z",
        "price" => "60.0",
        "co2_level" => "50",
        "available_tickets" => "20",
        "dates" => "2025-11-21"
      }

      {:ok, trip} = Trips.create_trip(admin, attrs)
      assert trip.recommended_price == Decimal.from_float(50 * 0.07)
    end
  end

  defp insert_admin do
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
end
