defmodule EarthScanner.TripsTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Trips.{Trip, TripInstance}
  alias EarthScanner.Accounts
  alias EarthScanner.Accounts.User

  defp admin_fixture(attrs \\ %{}) do
    {:ok, admin} =
      Accounts.register_user(
        Map.merge(
          %{
            "username" => "admin_user",
            "password" => "Password123!",
            "password_confirmation" => "Password123!",
            "name" => "Admin",
            "last_name" => "User",
            "email" => "admin@example.com",
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
      "dates" => "2025-11-21\n2025-11-28"
    }
  end

  describe "create_trip/2" do
    # FR-29
    test "creates a trip with duration and all required fields" do
      admin = admin_fixture()

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, valid_trip_attrs())

      assert trip.source_city == "Tallinn"
      assert trip.destination_city == "Paris"
      assert trip.transport_mode == "plane"
      assert trip.price == Decimal.new("150.0")
      assert trip.co2_level == 200
      assert trip.available_tickets == 50

      # FR-29: duration is computed (3 hours -> 180 minutes)
      assert trip.duration_minutes == 180
    end

    # FR-36
    test "creates instances for each given date, with their own ticket inventory" do
      admin = admin_fixture()

      {:ok, %Trip{} = trip} = Trips.create_trip(admin, valid_trip_attrs())

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      assert length(instances) == 2

      assert Enum.any?(instances, &(&1.date == ~D[2025-11-21] and &1.available_tickets == 50))
      assert Enum.any?(instances, &(&1.date == ~D[2025-11-28] and &1.available_tickets == 50))
    end

    # FR-29
    test "fails when arrival is before departure time" do
      admin = admin_fixture()

      bad_attrs =
        valid_trip_attrs()
        |> Map.put("arrival_time", "2025-11-20T08:00:00Z")

      assert {:error, changeset} = Trips.create_trip(admin, bad_attrs)
      assert "must be after departure time" in errors_on(changeset).arrival_time
    end

    # FR-36
    test "fails when no dates are provided" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("dates", "")

      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "at least one trip date is required" in errors_on(changeset).base
    end

    # FR-36
    test "fails when dates contain an invalid format" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("dates", "2025-11-21\ninvalid-date")

      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "invalid date: invalid-date" in errors_on(changeset).base
    end
  end

  describe "list_future_trips_for_admin/1" do
    # FR-29
    test "returns only trips for the given admin that have future instances" do
      admin1 = admin_fixture(%{"username" => "admin1", "email" => "admin1@example.com"})
      admin2 = admin_fixture(%{"username" => "admin2", "email" => "admin2@example.com"})

      {:ok, trip1} =
        Trips.create_trip(admin1, valid_trip_attrs() |> Map.put("dates", "2025-11-21"))

      {:ok, _trip2} =
        Trips.create_trip(admin2, valid_trip_attrs() |> Map.put("dates", "2025-11-22"))

      result = Trips.list_future_trips_for_admin(admin1)

      assert Enum.any?(result, &(&1.id == trip1.id))
      refute Enum.any?(result, &(&1.admin_id == admin2.id))
    end
  end
end
