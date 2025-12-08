defmodule EarthScanner.Trips.CreateTripTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Accounts

  defp admin_fixture(attrs \\ %{}) do
    # Use UUID to ensure truly unique email (unique_integer can collide with same test seed)
    unique_suffix = Ecto.UUID.generate() |> String.slice(0, 8)
    unique_email = "admin_#{unique_suffix}@example.com"
    unique_username = "admin_user_#{unique_suffix}"

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

  defp valid_trip_attrs do
    %{
      "picture_url" => "https://example.com/pic.jpg",
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
  end

  describe "FR-29: create_trip/2 - Basic Trip Creation" do
    test "creates a trip with duration and all required fields" do
      admin = admin_fixture()

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, valid_trip_attrs())

      assert trip.source_city == "Tallinn"
      assert trip.destination_city == "Paris"
      assert trip.transport_mode == "plane"
      assert Decimal.eq?(trip.price, Decimal.new("150.0"))
      assert trip.co2_level == 200
      assert trip.available_tickets == 50

      # FR-29: duration is computed (3 hours -> 180 minutes)
      assert trip.duration_minutes == 180
    end

    test "fails when arrival is before departure time" do
      admin = admin_fixture()

      bad_attrs =
        valid_trip_attrs()
        |> Map.put("arrival_time", "2025-11-20T08:00:00Z")

      assert {:error, changeset} = Trips.create_trip(admin, bad_attrs)
      assert "must be after departure time" in errors_on(changeset).arrival_time
    end

    test "fails when picture_url is missing" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.delete("picture_url")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "can't be blank" in errors_on(changeset).picture_url
    end

    test "fails when price is 0" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.put("price", "0")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "must be greater than 0" in errors_on(changeset).price
    end

    test "fails when available_tickets is 0" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.put("available_tickets", "0")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "must be greater than 0" in errors_on(changeset).available_tickets
    end

    test "fails when transport_mode is invalid" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.put("transport_mode", "car")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "is invalid" in errors_on(changeset).transport_mode
    end

    test "fails when transport_mode is missing" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.delete("transport_mode")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "can't be blank" in errors_on(changeset).transport_mode
    end

    test "fails when source_city is missing" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.delete("source_city")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "can't be blank" in errors_on(changeset).source_city
    end

    test "fails when destination_city is missing" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.delete("destination_city")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "can't be blank" in errors_on(changeset).destination_city
    end

    test "fails when departure_time is missing" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.delete("departure_time")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "can't be blank" in errors_on(changeset).departure_time
    end

    test "fails when arrival_time is missing" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.delete("arrival_time")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "can't be blank" in errors_on(changeset).arrival_time
    end

    test "fails when price is missing" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.delete("price")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "can't be blank" in errors_on(changeset).price
    end

    test "fails when co2_level is missing" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.delete("co2_level")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "can't be blank" in errors_on(changeset).co2_level
    end

    test "fails when available_tickets is missing" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.delete("available_tickets")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "can't be blank" in errors_on(changeset).available_tickets
    end

    test "fails when price is negative" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.put("price", "-50.0")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "must be greater than 0" in errors_on(changeset).price
    end

    test "fails when co2_level is negative" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.put("co2_level", "-100")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "must be greater than or equal to 0" in errors_on(changeset).co2_level
    end

    test "fails when available_tickets is negative" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.put("available_tickets", "-10")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "must be greater than 0" in errors_on(changeset).available_tickets
    end

    test "fails when departure_time has invalid format" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.put("departure_time", "invalid-datetime")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "is invalid" in errors_on(changeset).departure_time
    end

    test "fails when arrival_time has invalid format" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.put("arrival_time", "not-a-datetime")
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "is invalid" in errors_on(changeset).arrival_time
    end

    test "successfully creates trip with very long duration (24+ hours)" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("departure_time", "2025-11-20T10:00:00Z")
        |> Map.put("arrival_time", "2025-11-22T10:00:00Z")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)
      # 48 hours = 2880 minutes
      assert trip.duration_minutes == 2880
    end

    test "successfully creates trip with very short duration (1 minute)" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("departure_time", "2025-11-20T10:00:00Z")
        |> Map.put("arrival_time", "2025-11-20T10:01:00Z")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)
      assert trip.duration_minutes == 1
    end

    test "fails when departure and arrival times are the same" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("departure_time", "2025-11-20T10:00:00Z")
        |> Map.put("arrival_time", "2025-11-20T10:00:00Z")

      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "must be after departure time" in errors_on(changeset).arrival_time
    end

    test "successfully creates trip with special characters in city names" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("source_city", "São Paulo")
        |> Map.put("destination_city", "Zürich")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)
      assert trip.source_city == "São Paulo"
      assert trip.destination_city == "Zürich"
    end

    test "successfully creates trip with all transport modes" do
      admin = admin_fixture()

      for mode <- ["plane", "bus", "train"] do
        attrs = valid_trip_attrs() |> Map.put("transport_mode", mode)
        assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)
        assert trip.transport_mode == mode
      end
    end

    test "successfully creates trip with minimum valid values" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("price", "0.01")
        |> Map.put("co2_level", "0")
        |> Map.put("available_tickets", "1")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)
      assert Decimal.eq?(trip.price, Decimal.new("0.01"))
      assert trip.co2_level == 0
      assert trip.available_tickets == 1
    end

    test "successfully creates trip with large values" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("price", "99999.99")
        |> Map.put("co2_level", "999999")
        |> Map.put("available_tickets", "10000")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)
      assert Decimal.eq?(trip.price, Decimal.new("99999.99"))
      assert trip.co2_level == 999_999
      assert trip.available_tickets == 10_000
    end

    test "successfully creates trip with empty picture_url string" do
      admin = admin_fixture()
      attrs = valid_trip_attrs() |> Map.put("picture_url", "")
      # Empty string should fail validation
      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "can't be blank" in errors_on(changeset).picture_url
    end

    test "computes recommended_price automatically based on transport mode and CO2" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("transport_mode", "plane")
        |> Map.put("co2_level", "200")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)
      # plane factor is 0.15, so 200 * 0.15 = 30.0
      assert Decimal.eq?(trip.recommended_price, Decimal.new("30.0"))
    end
  end
end
