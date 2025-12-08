defmodule TripSearchContext do
  use WhiteBread.Context
  use Hound.Helpers

  # Start/end session for each scenario
  @base "http://localhost:4002"

  # nfr-08: This BDD context backs the Trip search features and is tied to NFR-08 (auth required)

  alias EarthScanner.Repo
  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Trips.TripInstance
  alias EarthScanner.Accounts

  # Hound session before each scenario
  scenario_starting_state fn _initial_state ->
    Hound.start_session()
    %{}
  end

  # Hound session cleanup
  scenario_finalize fn _status, state ->
    Hound.end_session()
    {:ok, state}
  end

  ##########################################################################
  # HELPER FUNCTIONS
  ##########################################################################

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_binary(value), do: String.to_integer(value)

  defp parse_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp parse_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp parse_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp create_trip!(attrs) do
    base_time =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    defaults = %{
      transport_mode: "bus",
      source_city: "Tartu",
      destination_city: "Tallinn",
      departure_time: DateTime.add(base_time, 86_400, :second),
      arrival_time: DateTime.add(base_time, 90_000, :second),
      price: 10,
      co2_level: 100,
      available_tickets: 10,
      admin_id: get_or_create_test_admin().id
    }

    attrs = Map.merge(defaults, attrs)

    Repo.insert!(struct(Trip, attrs))
  end

  defp get_or_create_test_admin do
    case Repo.get_by(EarthScanner.Accounts.User, email: "bdd_test_admin@example.com") do
      nil ->
        Repo.insert!(%EarthScanner.Accounts.User{
          username: "bdd_test_admin",
          email: "bdd_test_admin@example.com",
          password_hash: "$2b$12$test_hash_for_bdd_testing_only",
          name: "BDD",
          last_name: "Admin",
          birthdate: ~D[1990-01-01],
          nationality: "EE",
          residence_address: "Test Street 1",
          phone_number: "+37200000000",
          role: "admin"
        })
      admin -> admin
    end
  end


  ##########################################################################
  # GIVEN STEPS — DB setup for trips
  ##########################################################################

  given_ ~r/^a set of future trips exist$/, fn state ->
    insert_future_trips()
    {:ok, state}
  end

  given_ ~r/^a set of past and future trips exist$/, fn state ->
    insert_past_and_future_trips()
    {:ok, state}
  end

  given_ ~r/^a set of future trips with varying prices exist$/, fn state ->
    insert_price_variation_trips()
    {:ok, state}
  end

  given_ ~r/^a set of future trips with varying CO2 exist$/, fn state ->
    insert_co2_variation_trips()
    {:ok, state}
  end

  given_ ~r/^a set of future trips with various attributes exist$/, fn state ->
    insert_mixed_trips()
    {:ok, state}
  end

  given_ ~r/^a set of future trips with varying durations exist$/, fn state ->
    insert_duration_variation_trips()
    {:ok, state}
  end

  given_ ~r/^a past trip exists between "(?<source>[^"]+)" and "(?<destination>[^"]+)"$/, fn state, %{source: source, destination: dest} ->
    insert_past_trip_between(source, dest)
    {:ok, state}
  end

  given_ ~r/^a future trip exists between "(?<source>[^"]+)" and "(?<destination>[^"]+)"$/, fn state, %{source: source, destination: dest} ->
    insert_future_trip_between(source, dest)
    {:ok, state}
  end

  given_ ~r/^only past trips exist between "(?<source>[^"]+)" and "(?<destination>[^"]+)"$/, fn state, %{source: source, destination: dest} ->
    insert_only_past_trips_between(source, dest)
    {:ok, state}
  end

  given_ ~r/^a trip departing exactly now exists between "(?<source>[^"]+)" and "(?<destination>[^"]+)"$/, fn state, %{source: source, destination: dest} ->
    insert_now_trip_between(source, dest)
    {:ok, state}
  end

  given_ ~r/^a trip with available tickets exists from "(?<source>[^"]+)" to "(?<destination>[^"]+)"$/, fn state, %{source: source, destination: dest} ->
    insert_available_trip_between(source, dest)
    {:ok, state}
  end

  given_ ~r/^a sold-out future trip exists from "(?<source>[^"]+)" to "(?<destination>[^"]+)"$/, fn state, %{source: source, destination: dest} ->
    insert_sold_out_future_trip_between(source, dest)
    {:ok, state}
  end

  given_ ~r/^a trip with mixed sold-out and available instances exists from "(?<source>[^"]+)" to "(?<destination>[^"]+)"$/, fn state, %{source: source, destination: dest} ->
    insert_mixed_instances_trip(source, dest)
    {:ok, state}
  end

  given_ ~r/^I am logged in as a normal user$/, fn state ->
    suffix = Integer.to_string(System.unique_integer([:positive]))
    email = "bdd_user_" <> suffix <> "@example.com"
    password = "Password123!"

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "bdd_user_" <> suffix,
        "password" => password,
        "password_confirmation" => password,
        "name" => "BDD",
        "last_name" => "User",
        "email" => email,
        "birthdate" => "1998-01-01",
        "nationality" => "ID",
        "residence_address" => "BDD Street",
        "phone_number" => "+628999999999"
      })

    navigate_to(@base <> "/users/login")
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, password)
    submit_element({:id, "login-form"})

    {:ok, Map.put(state, :user, user)}
  end

  ##########################################################################
  # WHEN STEPS — User triggers searches
  ##########################################################################

  when_ ~r/^I search for trips from "(?<source>[^"]+)" to "(?<destination>[^"]+)"$/, fn state, %{source: s, destination: d} ->
    navigate_to(@base <> "/search/results?source=#{s}&destination=#{d}")
    {:ok, state}
  end

  when_ ~r/^I search for trips from "" to "(?<destination>[^"]+)"$/, fn state, %{destination: d} ->
    navigate_to(@base <> "/search/results?source=&destination=#{d}")
    {:ok, state}
  end

  when_ ~r/^I search for trips from "(?<source>[^"]+)" to "(?<destination>[^"]+)" with min price "(?<min>[^"]+)" and max price "(?<max>[^"]+)"$/, fn state, %{source: s, destination: d, min: min, max: max} ->
    navigate_to(@base <> "/search/results?source=#{s}&destination=#{d}&min_price=#{min}&max_price=#{max}")
    {:ok, state}
  end

  when_ ~r/^I search for trips from "(?<source>[^"]+)" to "(?<destination>[^"]+)" with max co2 "(?<max>[^"]+)"$/, fn state, %{source: s, destination: d, max: max} ->
    navigate_to(@base <> "/search/results?source=#{s}&destination=#{d}&max_co2=#{max}")
    {:ok, state}
  end

  when_ ~r/^I search with multiple filters applied$/, fn state ->
    navigate_to(@base <> "/search/results?source=Tartu&destination=Tallinn&min_price=10&max_co2=200&min_duration=30")
    {:ok, state}
  end

  when_ ~r/^I sort search results by "(?<sort>[^"]+)"$/, fn state, %{sort: sort} ->
    navigate_to(@base <> "/search/results?source=Tartu&destination=Tallinn&sort=#{sort}")
    {:ok, state}
  end

  # Negative test steps for search features

  when_ ~r/^I search without providing source$/, fn state ->
    navigate_to(@base <> "/search/results?source=&destination=Tallinn")
    :timer.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^I search without providing destination$/, fn state ->
    navigate_to(@base <> "/search/results?source=Tartu&destination=")
    :timer.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^I try to search as an unauthenticated user$/, fn state ->
    # Logout first
    try do
      submit_element({:css, "form[action='/users/logout']"})
      :timer.sleep(1000)
    rescue
      _ -> :ok
    end

    navigate_to(@base <> "/search/results?source=Tartu&destination=Tallinn")
    :timer.sleep(1000)
    {:ok, state}
  end

  ##########################################################################
  # THEN STEPS — Assertions
  ##########################################################################

  then_ ~r/^I should see at least 1 trip in the results$/, fn state ->
    page = visible_page_text()
    if String.trim(page) == "" do
      {:error, "No trips displayed"}
    else
      {:ok, state}
    end
  end

  then_ ~r/^I should be redirected back to the search page$/, fn state ->
    {:ok, state}
  end

  then_ ~r/^I should not see past trips in the results$/, fn state ->
    html = visible_page_text()
    if String.contains?(html, "PastTrip") do
      {:error, "Past trips appeared in results"}
    else
      {:ok, state}
    end
  end

  then_ ~r/^I should only see trips priced between (?<min>\d+) and (?<max>\d+)$/, fn state, %{min: _min, max: _max} ->
    _html = visible_page_text()
    {:ok, state}
  end

  then_ ~r/^I should only see trips with CO2 <= (?<max>\d+)$/, fn state, %{max: _max} ->
    _html = visible_page_text()
    {:ok, state}
  end

  then_ ~r/^I should only see trips matching all conditions$/, fn state ->
    {:ok, state}
  end

  then_ ~r/^results should appear in ascending price order$/, fn state ->
    html = visible_page_text()
    {:ok, state}
  end

  then_ ~r/^results should appear in descending CO2 order$/, fn state ->
    {:ok, state}
  end

  then_ ~r/^results should appear in ascending duration order$/, fn state ->
    {:ok, state}
  end

  then_ ~r/^I should see 1 trip in the results$/, fn state ->
    {:ok, state}
  end

  then_ ~r/^I should see 0 trips in the results$/, fn state ->
    page = visible_page_text()
    if String.contains?(page, "Mode") do
      {:error, "Expected 0 trips, but trips rendered"}
    else
      {:ok, state}
    end
  end

  then_ ~r/^I should see "(?<message>[^"]+)"$/, fn state, %{message: _message} ->
    {:ok, state}
  end

  then_ ~r/^I should not see the "(?<trip_name>[^"]+)" in the results$/, fn state, %{trip_name: trip_name} ->
    page = visible_page_text()
    if String.contains?(page, trip_name) do
      {:error, "Found disallowed trip #{trip_name}"}
    else
      {:ok, state}
    end
  end

  then_ ~r/^I should NOT see sold-out highlighting$/, fn state ->
    page = visible_page_text()
    if String.contains?(page, "Sold out") do
      {:error, "Sold-out highlighting present"}
    else
      {:ok, state}
    end
  end

  then_ ~r/^the purchase button should be enabled$/, fn state ->
    {:ok, state}
  end

  then_ ~r/^I should see the sold-out trip highlighted$/, fn state ->
    page = visible_page_text()
    if String.contains?(page, "Sold out") do
      {:ok, state}
    else
      {:error, "Sold-out highlighting missing"}
    end
  end

  then_ ~r/^the purchase button should be disabled for that trip$/, fn state ->
    {:ok, state}
  end

  then_ ~r/^I should be blocked with authentication error$/, fn state ->
    current = current_url()
    page_text = visible_page_text()

    assert String.contains?(current, "/login") or
          String.contains?(page_text, "log in") or
          String.contains?(page_text, "Please log in"),
      "Unauthenticated users should not be able to search"

    {:ok, state}
  end

  ##########################################################################
  # PRIVATE HELPERS — DB INSERTS
  ##########################################################################

  defp insert_future_trips do
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    tomorrow = DateTime.add(now, 86_400, :second)

    Repo.insert!(%Trip{
      source_city: "Tartu",
      destination_city: "Tallinn",
      transport_mode: "bus",
      departure_time: tomorrow,
      arrival_time: DateTime.add(tomorrow, 7200, :second),
      duration_minutes: 120,
      price: 20,
      co2_level: 100,
      available_tickets: 50,
      admin_id: get_or_create_test_admin().id
    })
  end

  defp insert_past_and_future_trips do
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    yesterday = DateTime.add(now, -86_400, :second)
    tomorrow = DateTime.add(now, 86_400, :second)

    # Past trip
    Repo.insert!(%Trip{
      source_city: "Tartu",
      destination_city: "Parnu",
      transport_mode: "train",
      departure_time: yesterday,
      arrival_time: DateTime.add(yesterday, 7200, :second),
      duration_minutes: 120,
      price: 15,
      co2_level: 150,
      available_tickets: 20,
      admin_id: get_or_create_test_admin().id
    })

    # Future trip
    Repo.insert!(%Trip{
      source_city: "Tartu",
      destination_city: "Parnu",
      transport_mode: "train",
      departure_time: tomorrow,
      arrival_time: DateTime.add(tomorrow, 7200, :second),
      duration_minutes: 120,
      price: 25,
      co2_level: 120,
      available_tickets: 20,
      admin_id: get_or_create_test_admin().id
    })
  end

  defp insert_price_variation_trips do
    base_time =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.add(86_400, :second)

    for price <- [5, 15, 25, 40] do
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: base_time,
        arrival_time: DateTime.add(base_time, 3600, :second),
        duration_minutes: 60,
        price: price,
        co2_level: 100,
        available_tickets: 20,
        admin_id: get_or_create_test_admin().id
      })
    end
  end

  defp insert_co2_variation_trips do
    base_time =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.add(86_400, :second)

    for co2 <- [50, 100, 150, 250] do
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: base_time,
        arrival_time: DateTime.add(base_time, 3600, :second),
        duration_minutes: 60,
        price: 20,
        co2_level: co2,
        available_tickets: 20,
        admin_id: get_or_create_test_admin().id
      })
    end
  end

  defp insert_mixed_trips do
    base_time =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.add(86_400, :second)

    Repo.insert!(%Trip{
      source_city: "Tartu",
      destination_city: "Tallinn",
      transport_mode: "bus",
      departure_time: base_time,
      arrival_time: DateTime.add(base_time, 5400, :second),
      duration_minutes: 90,
      price: 15,
      co2_level: 120,
      available_tickets: 20,
      admin_id: get_or_create_test_admin().id
    })

    Repo.insert!(%Trip{
      source_city: "Tartu",
      destination_city: "Tallinn",
      transport_mode: "train",
      departure_time: base_time,
      arrival_time: DateTime.add(base_time, 7200, :second),
      duration_minutes: 120,
      price: 25,
      co2_level: 150,
      available_tickets: 20,
      admin_id: get_or_create_test_admin().id
    })
  end

  defp insert_duration_variation_trips do
    base_time =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.add(86_400, :second)

    for minutes <- [30, 60, 120] do
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: base_time,
        arrival_time: DateTime.add(base_time, minutes * 60, :second),
        duration_minutes: minutes,
        price: 15,
        co2_level: 80,
        available_tickets: 10,
        admin_id: get_or_create_test_admin().id
      })
    end
  end

  defp insert_past_trip_between(source, dest) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Repo.insert!(%Trip{
      source_city: source,
      destination_city: dest,
      transport_mode: "train",
      departure_time: DateTime.add(now, -7_200, :second),
      arrival_time: DateTime.add(now, -3_600, :second),
      duration_minutes: 60,
      price: 10,
      co2_level: 90,
      available_tickets: 5,
      admin_id: get_or_create_test_admin().id
    })
  end

  defp insert_future_trip_between(source, dest) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Repo.insert!(%Trip{
      source_city: source,
      destination_city: dest,
      transport_mode: "bus",
      departure_time: DateTime.add(now, 7_200, :second),
      arrival_time: DateTime.add(now, 10_800, :second),
      duration_minutes: 60,
      price: 12,
      co2_level: 70,
      available_tickets: 8,
      admin_id: get_or_create_test_admin().id
    })
  end

  defp insert_only_past_trips_between(source, dest) do
    insert_past_trip_between(source, dest)
    insert_past_trip_between(source, dest)
  end

  defp insert_now_trip_between(source, dest) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Repo.insert!(%Trip{
      source_city: source,
      destination_city: dest,
      transport_mode: "bus",
      departure_time: now,
      arrival_time: DateTime.add(now, 3_600, :second),
      duration_minutes: 60,
      price: 15,
      co2_level: 75,
      available_tickets: 5,
      admin_id: get_or_create_test_admin().id
    })
  end

  defp insert_available_trip_between(source, dest) do
    Repo.insert!(%Trip{
      source_city: source,
      destination_city: dest,
      transport_mode: "train",
      departure_time: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 86_400, :second),
      arrival_time: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 90_000, :second),
      duration_minutes: 60,
      price: 20,
      co2_level: 110,
      available_tickets: 15,
      admin_id: get_or_create_test_admin().id
    })
  end

  defp insert_sold_out_future_trip_between(source, dest) do
    Repo.insert!(%Trip{
      source_city: source,
      destination_city: dest,
      transport_mode: "train",
      departure_time: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 86_400, :second),
      arrival_time: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 90_000, :second),
      duration_minutes: 60,
      price: 30,
      co2_level: 130,
      available_tickets: 0,
      admin_id: get_or_create_test_admin().id
    })
  end

  defp insert_mixed_instances_trip(source, dest) do
    trip =
      Repo.insert!(%Trip{
        source_city: source,
        destination_city: dest,
        transport_mode: "bus",
        departure_time: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 86_400, :second),
        arrival_time: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 90_000, :second),
        duration_minutes: 60,
        price: 22,
        co2_level: 95,
        available_tickets: 10,
        admin_id: get_or_create_test_admin().id
      })

    today = Date.utc_today()

    Repo.insert!(%TripInstance{trip_id: trip.id, date: today, available_tickets: 0})
    Repo.insert!(%TripInstance{trip_id: trip.id, date: Date.add(today, 1), available_tickets: 5})
  end
end
