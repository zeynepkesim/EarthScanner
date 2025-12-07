defmodule EarthScanner.Trips.FR08FilterResultsTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip

  # ============================================================================
  # FR-08: FILTER RESULTS
  # ============================================================================

  describe "search_future_trips_paginated/3 - FR-08: Filter by Price" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      {:ok, cheap_trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 1, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "price" => "10.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
        })

      {:ok, medium_trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 2, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 4, :hour) |> DateTime.to_iso8601(),
          "price" => "25.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
        })

      {:ok, expensive_trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "plane",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "price" => "50.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(3) |> Date.to_iso8601()
        })

      %{cheap: cheap_trip, medium: medium_trip, expensive: expensive_trip}
    end

    # AC: Each filter works independently - minimum price
    test "filters by minimum price", %{medium: medium, expensive: expensive} do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"min_price" => "20"})

      assert length(result.trips) == 2
      assert Enum.any?(result.trips, &(&1.id == medium.id))
      assert Enum.any?(result.trips, &(&1.id == expensive.id))

      # Verify all returned trips meet the criteria
      assert Enum.all?(result.trips, fn trip ->
               Decimal.compare(trip.price, Decimal.new("20")) in [:gt, :eq]
             end)
    end

    # AC: Each filter works independently - maximum price
    test "filters by maximum price", %{cheap: cheap, medium: medium} do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"max_price" => "30"})

      assert length(result.trips) == 2
      assert Enum.any?(result.trips, &(&1.id == cheap.id))
      assert Enum.any?(result.trips, &(&1.id == medium.id))

      # Verify all returned trips meet the criteria
      assert Enum.all?(result.trips, fn trip ->
               Decimal.compare(trip.price, Decimal.new("30")) in [:lt, :eq]
             end)
    end

    # AC: Supports numeric ranges (min–max)
    test "filters by price range (min and max combined)", %{medium: medium} do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_price" => "20",
          "max_price" => "30"
        })

      assert length(result.trips) == 1
      assert hd(result.trips).id == medium.id
    end

    # AC: Handles invalid filter values gracefully
    test "handles invalid price filter gracefully" do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"min_price" => "invalid"})

      # Should return all trips when filter is invalid
      assert length(result.trips) == 3
    end

    test "handles empty price filter" do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"min_price" => ""})

      # Should return all trips when filter is empty
      assert length(result.trips) == 3
    end
  end

  describe "search_future_trips_paginated/3 - FR-08: Filter by Duration" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      {:ok, short_trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 1, :hour) |> DateTime.to_iso8601(),
          "arrival_time" =>
            DateTime.add(now, 2, :hour) |> DateTime.add(30, :minute) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
        })

      {:ok, medium_trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 2, :hour) |> DateTime.to_iso8601(),
          "arrival_time" =>
            DateTime.add(now, 4, :hour) |> DateTime.add(30, :minute) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
        })

      {:ok, long_trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 7, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(3) |> Date.to_iso8601()
        })

      %{short: short_trip, medium: medium_trip, long: long_trip}
    end

    # AC: Each filter works independently - minimum duration
    test "filters by minimum duration", %{medium: medium, long: long} do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"min_duration" => "120"})

      assert length(result.trips) == 2
      assert Enum.any?(result.trips, &(&1.id == medium.id))
      assert Enum.any?(result.trips, &(&1.id == long.id))

      # Verify all returned trips meet the criteria
      assert Enum.all?(result.trips, &(&1.duration_minutes >= 120))
    end

    # AC: Each filter works independently - maximum duration
    test "filters by maximum duration", %{short: short, medium: medium} do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"max_duration" => "180"})

      assert length(result.trips) == 2
      assert Enum.any?(result.trips, &(&1.id == short.id))
      assert Enum.any?(result.trips, &(&1.id == medium.id))

      # Verify all returned trips meet the criteria
      assert Enum.all?(result.trips, &(&1.duration_minutes <= 180))
    end

    # AC: Supports numeric ranges (min–max)
    test "filters by duration range", %{medium: medium} do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_duration" => "120",
          "max_duration" => "180"
        })

      assert length(result.trips) == 1
      assert hd(result.trips).id == medium.id
    end
  end

  describe "search_future_trips_paginated/3 - FR-08: Filter by CO2 Level" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      {:ok, low_co2} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 1, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "10",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
        })

      {:ok, medium_co2} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 2, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 4, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "25",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
        })

      {:ok, high_co2} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "plane",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "50",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(3) |> Date.to_iso8601()
        })

      %{low: low_co2, medium: medium_co2, high: high_co2}
    end

    # AC: Each filter works independently - minimum CO2
    test "filters by minimum CO2 level", %{medium: medium, high: high} do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"min_co2" => "20"})

      assert length(result.trips) == 2
      assert Enum.any?(result.trips, &(&1.id == medium.id))
      assert Enum.any?(result.trips, &(&1.id == high.id))

      # Verify all returned trips meet the criteria
      assert Enum.all?(result.trips, &(&1.co2_level >= 20))
    end

    # AC: Each filter works independently - maximum CO2
    test "filters by maximum CO2 level", %{low: low, medium: medium} do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"max_co2" => "30"})

      assert length(result.trips) == 2
      assert Enum.any?(result.trips, &(&1.id == low.id))
      assert Enum.any?(result.trips, &(&1.id == medium.id))

      # Verify all returned trips meet the criteria
      assert Enum.all?(result.trips, &(&1.co2_level <= 30))
    end

    # AC: Supports numeric ranges (min–max)
    test "filters by CO2 range", %{medium: medium} do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_co2" => "20",
          "max_co2" => "30"
        })

      assert length(result.trips) == 1
      assert hd(result.trips).id == medium.id
    end
  end

  describe "search_future_trips_paginated/3 - FR-08: Filter by Departure Time" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      {:ok, early_departure} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 2, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 4, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
        })

      {:ok, mid_departure} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 12, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 14, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
        })

      {:ok, late_departure} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 24, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 26, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(3) |> Date.to_iso8601()
        })

      %{early: early_departure, mid: mid_departure, late: late_departure}
    end

    # AC: Supports time ranges (min–max)
    test "filters by minimum departure time", %{mid: mid, late: late} do
      min_time = DateTime.add(DateTime.utc_now(), 10, :hour) |> DateTime.to_iso8601()

      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_departure" => min_time
        })

      assert length(result.trips) == 2
      assert Enum.any?(result.trips, &(&1.id == mid.id))
      assert Enum.any?(result.trips, &(&1.id == late.id))
    end

    test "filters by maximum departure time", %{early: early, mid: mid} do
      max_time = DateTime.add(DateTime.utc_now(), 20, :hour) |> DateTime.to_iso8601()

      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "max_departure" => max_time
        })

      assert length(result.trips) == 2
      assert Enum.any?(result.trips, &(&1.id == early.id))
      assert Enum.any?(result.trips, &(&1.id == mid.id))
    end

    test "filters by departure time range", %{mid: mid} do
      min_time = DateTime.add(DateTime.utc_now(), 10, :hour) |> DateTime.to_iso8601()
      max_time = DateTime.add(DateTime.utc_now(), 20, :hour) |> DateTime.to_iso8601()

      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_departure" => min_time,
          "max_departure" => max_time
        })

      assert length(result.trips) == 1
      assert hd(result.trips).id == mid.id
    end

    test "handles invalid datetime format gracefully" do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_departure" => "invalid-date"
        })

      # Should return all trips when filter is invalid
      assert length(result.trips) == 3
    end
  end

  describe "search_future_trips_paginated/3 - FR-08: Filter by Arrival Time" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      {:ok, early_arrival} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 1, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
        })

      {:ok, mid_arrival} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 10, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 12, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
        })

      {:ok, late_arrival} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 22, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 24, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(3) |> Date.to_iso8601()
        })

      %{early: early_arrival, mid: mid_arrival, late: late_arrival}
    end

    # AC: Supports time ranges (min–max)
    test "filters by minimum arrival time", %{mid: mid, late: late} do
      min_time = DateTime.add(DateTime.utc_now(), 10, :hour) |> DateTime.to_iso8601()

      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_arrival" => min_time
        })

      assert length(result.trips) == 2
      assert Enum.any?(result.trips, &(&1.id == mid.id))
      assert Enum.any?(result.trips, &(&1.id == late.id))
    end

    test "filters by maximum arrival time", %{early: early, mid: mid} do
      max_time = DateTime.add(DateTime.utc_now(), 20, :hour) |> DateTime.to_iso8601()

      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "max_arrival" => max_time
        })

      assert length(result.trips) == 2
      assert Enum.any?(result.trips, &(&1.id == early.id))
      assert Enum.any?(result.trips, &(&1.id == mid.id))
    end

    test "filters by arrival time range", %{mid: mid} do
      min_time = DateTime.add(DateTime.utc_now(), 10, :hour) |> DateTime.to_iso8601()
      max_time = DateTime.add(DateTime.utc_now(), 20, :hour) |> DateTime.to_iso8601()

      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_arrival" => min_time,
          "max_arrival" => max_time
        })

      assert length(result.trips) == 1
      assert hd(result.trips).id == mid.id
    end
  end

  describe "search_future_trips_paginated/3 - FR-08: Combined Filters" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      # Trip matching all criteria
      {:ok, matching_trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 7, :hour) |> DateTime.to_iso8601(),
          "price" => "25.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
        })

      # Trip outside price range
      {:ok, wrong_price} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "plane",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 7, :hour) |> DateTime.to_iso8601(),
          "price" => "50.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(3) |> Date.to_iso8601()
        })

      # Trip outside duration range
      {:ok, wrong_duration} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 10, :hour) |> DateTime.to_iso8601(),
          "price" => "25.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(4) |> Date.to_iso8601()
        })

      %{matching: matching_trip, wrong_price: wrong_price, wrong_duration: wrong_duration}
    end

    # AC: Each filter can be combined with others
    test "applies multiple filters correctly", %{matching: matching} do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_price" => "20",
          "max_price" => "30",
          "max_duration" => "150",
          "max_co2" => "25"
        })

      assert length(result.trips) == 1
      assert hd(result.trips).id == matching.id
    end

    test "returns empty result when no trips match all filters" do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_price" => "100",
          "max_co2" => "5"
        })

      assert result.trips == []
      assert result.total == 0
    end

    # AC: Combining filters narrows down results progressively
    test "combining filters progressively narrows results" do
      # No filters
      all_results = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{})
      assert all_results.total == 3

      # One filter
      price_filtered =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_price" => "20"
        })

      assert price_filtered.total <= all_results.total

      # Two filters
      price_and_duration =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_price" => "20",
          "max_duration" => "150"
        })

      assert price_and_duration.total <= price_filtered.total
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp create_admin_user(attrs \\ %{}) do
    default_attrs = %{
      username: "admin_#{System.unique_integer([:positive])}",
      password: "password123",
      password_confirmation: "password123",
      email: "admin_#{System.unique_integer([:positive])}@test.com",
      phone_number: "1234567890",
      role: "admin"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    changeset =
      EarthScanner.Accounts.User.admin_changeset(%EarthScanner.Accounts.User{}, merged_attrs)

    {:ok, user} = Repo.insert(changeset)
    user
  end
end
