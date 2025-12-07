defmodule EarthScanner.Trips.FR09SortResultsTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip

  # ============================================================================
  # FR-09: SORT RESULTS
  # ============================================================================

  describe "search_future_trips_paginated/3 - FR-09: Sort by Price" do
    setup do
      admin = create_admin_user()
      now = DateTime.utc_now()

      {:ok, expensive} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
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
          "picture_url" => "https://via.placeholder.com/150",
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
          "picture_url" => "https://via.placeholder.com/150",
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
          "picture_url" => "https://via.placeholder.com/150",
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
          "picture_url" => "https://via.placeholder.com/150",
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
          "picture_url" => "https://via.placeholder.com/150",
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
          "picture_url" => "https://via.placeholder.com/150",
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
          "picture_url" => "https://via.placeholder.com/150",
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
          "picture_url" => "https://via.placeholder.com/150",
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
            "picture_url" => "https://via.placeholder.com/150",
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

      # Should have 3 trips (prices: 20, 25, 30, 35)
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
            "picture_url" => "https://via.placeholder.com/150",
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

      # Last item of page1 should have lower or equal price than first item of page2
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
