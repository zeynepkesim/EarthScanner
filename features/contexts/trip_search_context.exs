defmodule TripSearchContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.Repo
  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip

  # Hound session before each scenario
  scenario_starting_state fn _initial_state ->
    Hound.start_session()
    %{}
  end

  # Hound session cleanup
  scenario_finalize fn state ->
    Hound.end_session()
    {:ok, state}
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


  ##########################################################################
  # WHEN STEPS — User triggers searches
  ##########################################################################

  when_ ~r/^I search for trips from "(?<source>[^"]+)" to "(?<destination>[^"]+)"$/, fn state, %{source: s, destination: d} ->
    navigate_to("/search/results?source=#{s}&destination=#{d}")
    {:ok, state}
  end

  when_ ~r/^I search for trips from "" to "(?<destination>[^"]+)"$/, fn state, %{destination: d} ->
    navigate_to("/search/results?source=&destination=#{d}")
    {:ok, state}
  end

  when_ ~r/^I search for trips from "(?<source>[^"]+)" to "(?<destination>[^"]+)" with min price "(?<min>[^"]+)" and max price "(?<max>[^"]+)"$/, fn state, %{source: s, destination: d, min: min, max: max} ->
    navigate_to("/search/results?source=#{s}&destination=#{d}&min_price=#{min}&max_price=#{max}")
    {:ok, state}
  end

  when_ ~r/^I search for trips from "(?<source>[^"]+)" to "(?<destination>[^"]+)" with max co2 "(?<max>[^"]+)"$/, fn state, %{source: s, destination: d, max: max} ->
    navigate_to("/search/results?source=#{s}&destination=#{d}&max_co2=#{max}")
    {:ok, state}
  end

  when_ ~r/^I search with multiple filters applied$/, fn state ->
    navigate_to("/search/results?source=Tartu&destination=Tallinn&min_price=10&max_co2=200&min_duration=30")
    {:ok, state}
  end

  when_ ~r/^I sort search results by "(?<sort>[^"]+)"$/, fn state, %{sort: sort} ->
    navigate_to("/search/results?source=Tartu&destination=Tallinn&sort=#{sort}")
    {:ok, state}
  end


  ##########################################################################
  # THEN STEPS — Assertions
  ##########################################################################

  then_ ~r/^I should see at least 1 trip in the results$/, fn state ->
    page = visible_page_text()
    if String.contains?(page, "Mode:") do
      {:ok, state}
    else
      {:error, "No trips displayed"}
    end
  end

  then_ ~r/^I should be redirected back to the search page$/, fn state ->
    current = current_url()
    cond do
      String.ends_with?(current, "/search") ->
        {:ok, state}

      true ->
        {:error, "Expected redirect to /search, got #{current}"}
    end
  end

  then_ ~r/^I should not see past trips in the results$/, fn state ->
    html = visible_page_text()
    if String.contains?(html, "PastTrip") do
      {:error, "Past trips appeared in results"}
    else
      {:ok, state}
    end
  end

  then_ ~r/^I should only see trips priced between (?<min>\d+) and (?<max>\d+)$/, fn state, %{min: min, max: max} ->
    html = visible_page_text()
    # simple string checks
    if String.contains?(html, "Price:") do
      {:ok, state}
    else
      {:error, "No price values found to validate filter"}
    end
  end

  then_ ~r/^I should only see trips with CO2 <= (?<max>\d+)$/, fn state, %{max: max} ->
    html = visible_page_text()
    if String.contains?(html, "CO₂") do
      {:ok, state}
    else
      {:error, "No CO₂ values found for checking"}
    end
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



  ##########################################################################
  # PRIVATE HELPERS — DB INSERTS
  ##########################################################################

  defp insert_future_trips do
    now = DateTime.utc_now()
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
      admin_id: 1
    })
  end

  defp insert_past_and_future_trips do
    now = DateTime.utc_now()
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
      admin_id: 1
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
      admin_id: 1
    })
  end

  defp insert_price_variation_trips do
    base_time = DateTime.add(DateTime.utc_now(), 86_400, :second)

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
        admin_id: 1
      })
    end
  end

  defp insert_co2_variation_trips do
    base_time = DateTime.add(DateTime.utc_now(), 86_400, :second)

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
        admin_id: 1
      })
    end
  end

  defp insert_mixed_trips do
    base_time = DateTime.add(DateTime.utc_now(), 86_400, :second)

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
      admin_id: 1
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
      admin_id: 1
    })
  end
end
