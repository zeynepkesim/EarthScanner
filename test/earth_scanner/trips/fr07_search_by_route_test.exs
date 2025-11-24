defmodule EarthScanner.Trips.FR07SearchByRouteTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip

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
      page1 =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "page" => "1",
          "per_page" => "5"
        })

      page2 =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "page" => "2",
          "per_page" => "5"
        })

      page3 =
        Trips.search_future_trips_paginated("Tallinn", "Tartu", %{
          "page" => "3",
          "per_page" => "5"
        })

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
