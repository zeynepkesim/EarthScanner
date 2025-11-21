defmodule EarthScanner.TripsSearchTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Trips.{Trip, TripInstance}
  alias EarthScanner.Accounts.User

  # ============================================================================
  # FR-07: SEARCH BY ROUTE
  # ============================================================================

  describe "search_future_trips/3 - FR-07: Search by Route (Basic)" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      # Create past trip (should NOT appear in results)
      {:ok, past_trip} =
        Trips.create_trip(admin, %{
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, -2, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, -1, :hour) |> DateTime.to_iso8601(),
          "price" => "10.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()
        })

      # Create future trips for Tallinn -> Tartu
      {:ok, future_trip_1} =
        Trips.create_trip(admin, %{
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 2, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 4, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "25",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(5) |> Date.to_iso8601()
        })

      {:ok, future_trip_2} =
        Trips.create_trip(admin, %{
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 7, :hour) |> DateTime.to_iso8601(),
          "price" => "12.00",
          "co2_level" => "22",
          "available_tickets" => "40",
          "dates" => Date.utc_today() |> Date.add(7) |> Date.to_iso8601()
        })

      # Create different route
      {:ok, different_route} =
        Trips.create_trip(admin, %{
          "transport_mode" => "bus",
          "source_city" => "Tartu",
          "destination_city" => "Pärnu",
          "departure_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 6, :hour) |> DateTime.to_iso8601(),
          "price" => "20.00",
          "co2_level" => "30",
          "available_tickets" => "30",
          "dates" => Date.utc_today() |> Date.add(6) |> Date.to_iso8601()
        })

      %{
        past_trip: past_trip,
        future_trip_1: future_trip_1,
        future_trip_2: future_trip_2,
        different_route: different_route
      }
    end

    # AC: Source and destination are required
    test "returns only future trips for valid source and destination", %{
      future_trip_1: trip1,
      future_trip_2: trip2
    } do
      results = Trips.search_future_trips("Tallinn", "Tartu")

      assert length(results) == 2
      assert Enum.any?(results, &(&1.id == trip1.id))
      assert Enum.any?(results, &(&1.id == trip2.id))
    end

    # AC: Only future trips (departure time > now) appear in results
    test "does not return past trips", %{past_trip: past} do
      results = Trips.search_future_trips("Tallinn", "Tartu")

      refute Enum.any?(results, &(&1.id == past.id))

      # Verify all returned trips are in the future
      refute Enum.any?(results, fn trip ->
               DateTime.compare(trip.departure_time, DateTime.utc_now()) == :lt
             end)
    end

    # AC: Returns empty list when no matching routes found
    test "returns empty list when no matching routes found" do
      results = Trips.search_future_trips("Helsinki", "Stockholm")

      assert results == []
    end

    # AC: Search is case-insensitive
    test "search is case-insensitive for source and destination" do
      results_lower = Trips.search_future_trips("tallinn", "tartu")
      results_upper = Trips.search_future_trips("TALLINN", "TARTU")
      results_mixed = Trips.search_future_trips("TaLLiNn", "TaRtU")

      assert length(results_lower) == 2
      assert length(results_upper) == 2
      assert length(results_mixed) == 2
    end

    # AC: Results are ordered by departure time (soonest first)
    test "returns trips ordered by departure time (soonest first)", %{
      future_trip_1: trip1,
      future_trip_2: trip2
    } do
      results = Trips.search_future_trips("Tallinn", "Tartu")

      assert length(results) == 2
      # First trip should depart earlier
      assert hd(results).id == trip1.id
      assert List.last(results).id == trip2.id
    end

    # AC: Does not return trips from different routes
    test "does not return trips from different routes", %{different_route: diff} do
      results = Trips.search_future_trips("Tallinn", "Tartu")

      refute Enum.any?(results, &(&1.id == diff.id))
    end
  end

  describe "search_future_trips_paginated/3 - FR-07: Pagination" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      # Create 12 future trips for pagination testing
      trips =
        for i <- 1..12 do
          {:ok, trip} =
            Trips.create_trip(admin, %{
              "transport_mode" => "bus",
              "source_city" => "Tallinn",
              "destination_city" => "Tartu",
              "departure_time" => DateTime.add(now, i, :hour) |> DateTime.to_iso8601(),
              "arrival_time" => DateTime.add(now, i + 2, :hour) |> DateTime.to_iso8601(),
              "price" => "#{10.0 + i}",
              "co2_level" => "#{20 + i}",
              "available_tickets" => "50",
              "dates" => Date.utc_today() |> Date.add(i) |> Date.to_iso8601()
            })

          trip
        end

      %{trips: trips}
    end

    # AC: Results are paginated
    test "returns paginated results with default page size of 5" do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{})

      assert result.total == 12
      assert result.page == 1
      assert result.per_page == 5
      assert length(result.trips) == 5
    end

    test "returns correct page of results" do
      page1 = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"page" => "1"})
      page2 = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"page" => "2"})
      page3 = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"page" => "3"})

      assert length(page1.trips) == 5
      assert length(page2.trips) == 5
      assert length(page3.trips) == 2

      # Ensure different pages return different trips
      page1_ids = Enum.map(page1.trips, & &1.id) |> MapSet.new()
      page2_ids = Enum.map(page2.trips, & &1.id) |> MapSet.new()

      assert MapSet.disjoint?(page1_ids, page2_ids)
    end

    test "respects custom per_page parameter" do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"per_page" => "3"})

      assert result.per_page == 3
      assert length(result.trips) == 3
    end

    test "returns correct total count across all pages" do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{})

      assert result.total == 12
    end

    test "handles last page with fewer items than per_page" do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "page" => "3",
          "per_page" => "5"
        })

      assert length(result.trips) == 2
      assert result.total == 12
    end

    test "returns empty trips list for page beyond available data" do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "page" => "100",
          "per_page" => "5"
        })

      assert result.trips == []
      assert result.total == 12
    end
  end

  # ============================================================================
  # FR-08: FILTER RESULTS
  # ============================================================================

  describe "search_future_trips_paginated/3 - FR-08: Filter by Price" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      {:ok, cheap_trip} =
        Trips.create_trip(admin, %{
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 1, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "price" => "10.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "duration_minutes" => "120",
          "dates" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
        })

      {:ok, medium_trip} =
        Trips.create_trip(admin, %{
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 2, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 4, :hour) |> DateTime.to_iso8601(),
          "price" => "25.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "duration_minutes" => "120",
          "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
        })

      {:ok, expensive_trip} =
        Trips.create_trip(admin, %{
          "transport_mode" => "plane",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "price" => "50.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "duration_minutes" => "120",
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
  # FR-09: SORT RESULTS
  # ============================================================================

  describe "search_future_trips_paginated/3 - FR-09: Sort by Price" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      {:ok, expensive} =
        Trips.create_trip(admin, %{
          "transport_mode" => "plane",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 1, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "price" => "50.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
        })

      {:ok, cheap} =
        Trips.create_trip(admin, %{
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 2, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 4, :hour) |> DateTime.to_iso8601(),
          "price" => "10.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
        })

      {:ok, medium} =
        Trips.create_trip(admin, %{
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "price" => "25.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(3) |> Date.to_iso8601()
        })

      %{expensive: expensive, cheap: cheap, medium: medium}
    end

    # AC: Each sortable field supports ascending order
    test "sorts by price ascending", %{cheap: cheap, medium: medium, expensive: expensive} do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"sort" => "price_asc"})

      assert length(result.trips) == 3
      [first, second, third] = result.trips
      assert first.id == cheap.id
      assert second.id == medium.id
      assert third.id == expensive.id

      # Verify the actual prices are in order
      assert Decimal.compare(first.price, second.price) == :lt
      assert Decimal.compare(second.price, third.price) == :lt
    end

    # AC: Each sortable field supports descending order
    test "sorts by price descending", %{cheap: cheap, medium: medium, expensive: expensive} do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"sort" => "price_desc"})

      assert length(result.trips) == 3
      [first, second, third] = result.trips
      assert first.id == expensive.id
      assert second.id == medium.id
      assert third.id == cheap.id

      # Verify the actual prices are in order
      assert Decimal.compare(first.price, second.price) == :gt
      assert Decimal.compare(second.price, third.price) == :gt
    end
  end

  describe "search_future_trips_paginated/3 - FR-09: Sort by CO2" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      {:ok, high_co2} =
        Trips.create_trip(admin, %{
          "transport_mode" => "plane",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 1, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "50",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
        })

      {:ok, low_co2} =
        Trips.create_trip(admin, %{
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 2, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 4, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "10",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
        })

      {:ok, medium_co2} =
        Trips.create_trip(admin, %{
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "25",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(3) |> Date.to_iso8601()
        })

      %{high: high_co2, low: low_co2, medium: medium_co2}
    end

    # AC: Each sortable field supports ascending order
    test "sorts by CO2 ascending", %{low: low, medium: medium, high: high} do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"sort" => "co2_asc"})

      assert length(result.trips) == 3
      [first, second, third] = result.trips
      assert first.id == low.id
      assert second.id == medium.id
      assert third.id == high.id

      # Verify the actual CO2 levels are in order
      assert first.co2_level < second.co2_level
      assert second.co2_level < third.co2_level
    end

    # AC: Each sortable field supports descending order
    test "sorts by CO2 descending", %{low: low, medium: medium, high: high} do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{"sort" => "co2_desc"})

      assert length(result.trips) == 3
      [first, second, third] = result.trips
      assert first.id == high.id
      assert second.id == medium.id
      assert third.id == low.id

      # Verify the actual CO2 levels are in order
      assert first.co2_level > second.co2_level
      assert second.co2_level > third.co2_level
    end
  end

  describe "search_future_trips_paginated/3 - FR-09: Sort by Duration" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      {:ok, long_trip} =
        Trips.create_trip(admin, %{
          "transport_mode" => "bus",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 1, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
        })

      {:ok, short_trip} =
        Trips.create_trip(admin, %{
          "transport_mode" => "plane",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 2, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
        })

      {:ok, medium_trip} =
        Trips.create_trip(admin, %{
          "transport_mode" => "train",
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => DateTime.add(now, 3, :hour) |> DateTime.to_iso8601(),
          "arrival_time" => DateTime.add(now, 5, :hour) |> DateTime.to_iso8601(),
          "price" => "15.00",
          "co2_level" => "20",
          "available_tickets" => "50",
          "dates" => Date.utc_today() |> Date.add(3) |> Date.to_iso8601()
        })

      %{long: long_trip, short: short_trip, medium: medium_trip}
    end

    # AC: Each sortable field supports ascending order
    test "sorts by duration ascending", %{short: short, medium: medium, long: long} do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "sort" => "duration_asc"
        })

      assert length(result.trips) == 3
      [first, second, third] = result.trips
      assert first.id == short.id
      assert second.id == medium.id
      assert third.id == long.id

      # Verify the actual durations are in order
      assert first.duration_minutes < second.duration_minutes
      assert second.duration_minutes < third.duration_minutes
    end

    # AC: Each sortable field supports descending order
    test "sorts by duration descending", %{short: short, medium: medium, long: long} do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "sort" => "duration_desc"
        })

      assert length(result.trips) == 3
      [first, second, third] = result.trips
      assert first.id == long.id
      assert second.id == medium.id
      assert third.id == short.id

      # Verify the actual durations are in order
      assert first.duration_minutes > second.duration_minutes
      assert second.duration_minutes > third.duration_minutes
    end
  end

  describe "search_future_trips_paginated/3 - FR-09: Sort with Filters" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      # Create diverse trips
      for i <- 1..5 do
        {:ok, _trip} =
          Trips.create_trip(admin, %{
            "transport_mode" => "bus",
            "source_city" => "Tallinn",
            "destination_city" => "Tartu",
            "departure_time" => DateTime.add(now, i, :hour) |> DateTime.to_iso8601(),
            "arrival_time" => DateTime.add(now, i + 2, :hour) |> DateTime.to_iso8601(),
            "price" => "#{10.0 + i * 5}",
            "co2_level" => "#{15 + i * 5}",
            "available_tickets" => "50",
            "dates" => Date.utc_today() |> Date.add(i) |> Date.to_iso8601()
          })
      end

      :ok
    end

    # AC: Sorting applies to the current filtered result set
    test "sorting applies to filtered results" do
      # Filter: price between 20 and 40
      filtered_and_sorted =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "min_price" => "20",
          "max_price" => "40",
          "sort" => "price_desc"
        })

      # Should have 3 trips (prices: 25, 30, 35)
      assert length(filtered_and_sorted.trips) > 0

      # Verify all results are within filter range
      assert Enum.all?(filtered_and_sorted.trips, fn trip ->
               Decimal.compare(trip.price, Decimal.new("20")) in [:gt, :eq] and
                 Decimal.compare(trip.price, Decimal.new("40")) in [:lt, :eq]
             end)

      # Verify they're sorted descending
      prices = Enum.map(filtered_and_sorted.trips, & &1.price)
      assert prices == Enum.sort(prices, {:desc, Decimal})
    end

    test "default sort by departure time when no sort parameter" do
      result = Trips.search_future_trips_paginated("Tallinn", "Tartu", %{})

      departure_times = Enum.map(result.trips, & &1.departure_time)

      # Verify they're sorted by departure time ascending
      assert departure_times == Enum.sort(departure_times, DateTime)
    end

    test "invalid sort parameter falls back to default sorting" do
      result =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "sort" => "invalid_sort"
        })

      # Should default to sorting by departure time
      departure_times = Enum.map(result.trips, & &1.departure_time)
      assert departure_times == Enum.sort(departure_times, DateTime)
    end
  end

  describe "search_future_trips_paginated/3 - FR-09: Sort with Pagination" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      # Create 10 trips with varying prices
      for i <- 1..10 do
        {:ok, _trip} =
          Trips.create_trip(admin, %{
            "transport_mode" => "bus",
            "source_city" => "Tallinn",
            "destination_city" => "Tartu",
            "departure_time" => DateTime.add(now, i, :hour) |> DateTime.to_iso8601(),
            "arrival_time" => DateTime.add(now, i + 2, :hour) |> DateTime.to_iso8601(),
            "price" => "#{100 - i * 5}",
            "co2_level" => "20",
            "available_tickets" => "50",
            "dates" => Date.utc_today() |> Date.add(i) |> Date.to_iso8601()
          })
      end

      :ok
    end

    # AC: Sorting works correctly with pagination
    test "sorting maintains consistency across pages" do
      page1 =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "page" => "1",
          "per_page" => "3",
          "sort" => "price_asc"
        })

      page2 =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "page" => "2",
          "per_page" => "3",
          "sort" => "price_asc"
        })

      # Last item of page1 should have lower price than first item of page2
      last_of_page1 = List.last(page1.trips)
      first_of_page2 = hd(page2.trips)

      assert Decimal.compare(last_of_page1.price, first_of_page2.price) in [:lt, :eq]
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
