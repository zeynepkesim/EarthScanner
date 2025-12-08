defmodule EarthScanner.Trips.RecurringTripDatesTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Trips.{Trip, TripInstance}
  alias EarthScanner.Accounts
  import Ecto.Query

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

  defp valid_trip_attrs do
    tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
    next_week = Date.utc_today() |> Date.add(8) |> Date.to_iso8601()
    future_time = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
    # Ensure arrival is after departure
    arrival = DateTime.utc_now() |> DateTime.add(7200, :second) |> DateTime.to_iso8601()

    %{
      "picture_url" => "https://example.com/pic.jpg",
      "transport_mode" => "plane",
      "source_city" => "Tallinn",
      "destination_city" => "Paris",
      "departure_time" => future_time,
      "arrival_time" => arrival,
      "price" => "150.0",
      "co2_level" => "200",
      "available_tickets" => "50",
      "dates" => "#{tomorrow}\n#{next_week}"
    }
  end

  describe "FR-36: create_trip/2 - Recurring Trip Dates" do
    test "creates instances for each given date, with their own ticket inventory" do
      admin = admin_fixture()
      today = Date.utc_today()
      d1 = Date.add(today, 1)
      d2 = Date.add(today, 8)

      {:ok, %Trip{} = trip} = Trips.create_trip(admin, valid_trip_attrs())

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      assert length(instances) == 2

      assert Enum.any?(instances, &(&1.date == d1 and &1.available_tickets == 50))
      assert Enum.any?(instances, &(&1.date == d2 and &1.available_tickets == 50))
    end

    test "fails when no dates are provided" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("dates", "")

      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "at least one trip date is required" in errors_on(changeset).base
    end

    test "fails when dates contain an invalid format" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("dates", "2025-11-21\ninvalid-date")

      assert {:error, changeset} = Trips.create_trip(admin, attrs)
      assert "invalid date: invalid-date" in errors_on(changeset).base
    end

    test "successfully creates trip with single date" do
      admin = admin_fixture()
      today = Date.utc_today()
      d1 = Date.add(today, 1)
      attrs = valid_trip_attrs() |> Map.put("dates", "#{d1}")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      assert length(instances) == 1
      assert hd(instances).date == d1
    end

    test "successfully creates trip with comma-separated dates" do
      admin = admin_fixture()
      today = Date.utc_today()
      d1 = Date.add(today, 1)
      d2 = Date.add(today, 8)
      d3 = Date.add(today, 15)
      attrs = valid_trip_attrs() |> Map.put("dates", "#{d1}, #{d2}, #{d3}")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      assert length(instances) == 3
    end

    test "deduplicates duplicate dates" do
      admin = admin_fixture()
      today = Date.utc_today()
      d1 = Date.add(today, 1)
      d2 = Date.add(today, 8)

      attrs =
        valid_trip_attrs()
        |> Map.put("dates", "#{d1}\n#{d1}\n#{d2}")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      # Should only create 2 instances (duplicates removed)
      assert length(instances) == 2
    end

    test "successfully creates trip with many dates" do
      admin = admin_fixture()

      # Generate 30 future dates
      dates =
        1..30
        |> Enum.map(fn n ->
          Date.utc_today() |> Date.add(n) |> Date.to_iso8601()
        end)
        |> Enum.join("\n")

      attrs = valid_trip_attrs() |> Map.put("dates", dates)

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      assert length(instances) == 30
    end

    test "each instance has independent ticket inventory" do
      admin = admin_fixture()
      today = Date.utc_today()
      d1 = Date.add(today, 1)
      d2 = Date.add(today, 8)

      attrs =
        valid_trip_attrs()
        |> Map.put("dates", "#{d1}\n#{d2}")
        |> Map.put("available_tickets", "100")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      # Each instance should have its own inventory of 100 tickets
      assert Enum.all?(instances, &(&1.available_tickets == 100))
    end

    test "newline-separated dates are parsed correctly" do
      admin = admin_fixture()
      today = Date.utc_today()
      d1 = Date.add(today, 1)
      d2 = Date.add(today, 8)
      d3 = Date.add(today, 15)

      attrs =
        valid_trip_attrs()
        |> Map.put("dates", "#{d1}\n#{d2}\n#{d3}")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> order_by([i], i.date)
        |> Repo.all()

      assert length(instances) == 3
      assert Enum.at(instances, 0).date == d1
      assert Enum.at(instances, 1).date == d2
      assert Enum.at(instances, 2).date == d3
    end

    test "mixed comma and newline separators are handled" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("dates", "2025-11-21, 2025-11-28\n2025-12-05, 2025-12-12")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      assert length(instances) == 4
    end

    test "whitespace around dates is trimmed" do
      admin = admin_fixture()

      attrs =
        valid_trip_attrs()
        |> Map.put("dates", "  2025-11-21  ,  2025-11-28  ")

      assert {:ok, %Trip{} = trip} = Trips.create_trip(admin, attrs)

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      assert length(instances) == 2
    end
  end

  describe "FR-36: list_future_trips_for_admin/1" do
    test "returns only trips for the given admin that have future instances" do
      admin1 = admin_fixture(%{"username" => "admin1", "email" => "admin1@example.com"})
      admin2 = admin_fixture(%{"username" => "admin2", "email" => "admin2@example.com"})

      future1 = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
      future2 = Date.utc_today() |> Date.add(2) |> Date.to_iso8601()

      {:ok, trip1} =
        Trips.create_trip(admin1, valid_trip_attrs() |> Map.put("dates", future1))

      {:ok, _trip2} =
        Trips.create_trip(admin2, valid_trip_attrs() |> Map.put("dates", future2))

      result = Trips.list_future_trips_for_admin(admin1)

      assert Enum.any?(result, &(&1.id == trip1.id))
      refute Enum.any?(result, &(&1.admin_id == admin2.id))
    end
  end

  describe "FR-36: Instance Management - update_trip_instance/2" do
    test "successfully updates instance date" do
      admin = admin_fixture()
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())

      instance =
        TripInstance |> where([i], i.trip_id == ^trip.id) |> limit(1) |> Repo.one()

      new_date = ~D[2025-12-15]

      assert {:ok, updated} = Trips.update_trip_instance(instance, %{"date" => new_date})
      assert updated.date == new_date
      assert updated.trip_id == trip.id
    end

    test "successfully updates instance available_tickets" do
      admin = admin_fixture()
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())

      instance =
        TripInstance |> where([i], i.trip_id == ^trip.id) |> limit(1) |> Repo.one()

      assert {:ok, updated} = Trips.update_trip_instance(instance, %{"available_tickets" => 75})
      assert updated.available_tickets == 75
    end

    test "fails when updating to duplicate date for same trip" do
      admin = admin_fixture()
      today = Date.utc_today()
      d1 = Date.add(today, 1)
      d2 = Date.add(today, 8)

      {:ok, trip} =
        Trips.create_trip(
          admin,
          valid_trip_attrs() |> Map.put("dates", "#{d1}\n#{d2}")
        )

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> order_by([i], i.date)
        |> Repo.all()

      first_instance = List.first(instances)
      second_date = List.last(instances).date

      # Try to update first instance to second instance's date
      assert {:error, changeset} =
               Trips.update_trip_instance(first_instance, %{"date" => second_date})

      # Composite unique constraint error appears on date field
      errors = errors_on(changeset)
      assert "has already been taken" in (errors[:date] || [])
    end

    test "fails when updating to invalid date format" do
      admin = admin_fixture()
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())

      instance =
        TripInstance |> where([i], i.trip_id == ^trip.id) |> limit(1) |> Repo.one()

      assert {:error, changeset} = Trips.update_trip_instance(instance, %{"date" => "invalid"})
      assert "is invalid" in errors_on(changeset).date
    end

    test "fails when updating to negative available_tickets" do
      admin = admin_fixture()
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())

      instance =
        TripInstance |> where([i], i.trip_id == ^trip.id) |> limit(1) |> Repo.one()

      assert {:error, changeset} =
               Trips.update_trip_instance(instance, %{"available_tickets" => -10})

      assert "must be greater than or equal to 0" in errors_on(changeset).available_tickets
    end

    test "allows updating to zero available_tickets (sold out)" do
      admin = admin_fixture()
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())

      instance =
        TripInstance |> where([i], i.trip_id == ^trip.id) |> limit(1) |> Repo.one()

      assert {:ok, updated} = Trips.update_trip_instance(instance, %{"available_tickets" => 0})
      assert updated.available_tickets == 0
    end

    test "updating instance preserves trip relationship" do
      admin = admin_fixture()
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())

      instance =
        TripInstance |> where([i], i.trip_id == ^trip.id) |> limit(1) |> Repo.one()

      original_trip_id = instance.trip_id

      assert {:ok, updated} = Trips.update_trip_instance(instance, %{"available_tickets" => 25})
      assert updated.trip_id == original_trip_id
    end
  end

  describe "FR-36: Instance Management - delete_trip_instance/1" do
    test "successfully deletes a trip instance" do
      admin = admin_fixture()
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())

      instance =
        TripInstance |> where([i], i.trip_id == ^trip.id) |> limit(1) |> Repo.one()

      assert {:ok, _deleted} = Trips.delete_trip_instance(instance)

      # Verify instance is deleted
      refute Repo.get(TripInstance, instance.id)
    end

    test "deleting one instance doesn't affect other instances" do
      admin = admin_fixture()

      {:ok, trip} =
        Trips.create_trip(
          admin,
          valid_trip_attrs() |> Map.put("dates", "2025-11-21\n2025-11-28\n2025-12-05")
        )

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> order_by([i], i.date)
        |> Repo.all()

      assert length(instances) == 3

      # Delete the middle instance
      middle_instance = Enum.at(instances, 1)
      assert {:ok, _deleted} = Trips.delete_trip_instance(middle_instance)

      # Verify only 2 instances remain
      remaining =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      assert length(remaining) == 2
      refute Enum.any?(remaining, &(&1.id == middle_instance.id))
    end

    test "can delete all but one instance" do
      admin = admin_fixture()

      {:ok, trip} =
        Trips.create_trip(
          admin,
          valid_trip_attrs() |> Map.put("dates", "2025-11-21\n2025-11-28")
        )

      instances =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      assert length(instances) == 2

      # Delete first instance
      first_instance = List.first(instances)
      assert {:ok, _deleted} = Trips.delete_trip_instance(first_instance)

      # Verify one instance remains
      remaining =
        TripInstance
        |> where([i], i.trip_id == ^trip.id)
        |> Repo.all()

      assert length(remaining) == 1
    end

    test "deleting instance doesn't delete the trip" do
      admin = admin_fixture()

      {:ok, trip} =
        Trips.create_trip(
          admin,
          valid_trip_attrs() |> Map.put("dates", "2025-11-21\n2025-11-28")
        )

      instance =
        TripInstance |> where([i], i.trip_id == ^trip.id) |> limit(1) |> Repo.one()

      assert {:ok, _deleted} = Trips.delete_trip_instance(instance)

      # Verify trip still exists
      assert Repo.get(Trip, trip.id)
    end
  end

  describe "FR-36: Search with Preloaded Instances" do
    test "search_future_trips returns trips with preloaded future instances" do
      admin = admin_fixture()
      today = Date.utc_today()
      tomorrow = Date.add(today, 1)
      next_week = Date.add(today, 7)

      dates = "#{tomorrow}\n#{next_week}"
      attrs = valid_trip_attrs() |> Map.put("dates", dates)

      {:ok, trip} = Trips.create_trip(admin, attrs)

      # Ensure search matches the trip
      results = Trips.search_future_trips("Tallinn", "Paris")

      assert length(results) == 1
      found_trip = hd(results)
      assert found_trip.id == trip.id
      assert Ecto.assoc_loaded?(found_trip.instances)
      assert length(found_trip.instances) == 2
      assert Enum.at(found_trip.instances, 0).date == tomorrow
      assert Enum.at(found_trip.instances, 1).date == next_week
    end
  end
end
