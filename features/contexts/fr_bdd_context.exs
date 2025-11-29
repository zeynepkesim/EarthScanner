defmodule FRBDDContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Repo, Accounts}
  import Ecto.Query
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Searches.SearchHistory

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, _state ->
    Hound.end_session()
    :ok
  end

  given_ ~r/^a trip exists with source "(?<source>[^"]+)" destination "(?<destination>[^"]+)" transport "(?<transport>[^"]+)" duration_minutes (?<duration>\d+) price "(?<price>[^"]+)"$/, fn state, %{"source" => s, "destination" => d, "transport" => t, "duration" => duration, "price" => price} ->
    now = DateTime.utc_now()
    dt = DateTime.add(now, 86_400, :second)

    trip = %Trip{
      source_city: s,
      destination_city: d,
      transport_mode: t,
      departure_time: dt,
      arrival_time: DateTime.add(dt, 3600, :second),
      duration_minutes: String.to_integer(duration),
      price: Decimal.new(price),
      co2_level: 100,
      available_tickets: 10,
      admin_id: 1
    }

    Repo.insert!(trip)

    {:ok, state}
  end

  given_ ~r/^(?<count>\d+) similar trips exist for "(?<source>[^"]+)" to "(?<destination>[^"]+)"$/, fn state, %{"count" => count_s, "source" => s, "destination" => d} ->
    count = String.to_integer(count_s)
    now = DateTime.utc_now()
    dt = DateTime.add(now, 86_400, :second)

    for _ <- 1..count do
      Repo.insert!(%Trip{
        source_city: s,
        destination_city: d,
        transport_mode: "bus",
        departure_time: dt,
        arrival_time: DateTime.add(dt, 3600, :second),
        duration_minutes: 60,
        price: 20,
        co2_level: 100,
        available_tickets: 10,
        admin_id: 1
      })
    end

    {:ok, state}
  end

  when_ ~r/^I visit the trip page for the first trip$/, fn state, _ ->
    trip = Repo.one(from t in Trip, order_by: [asc: t.id], limit: 1)
    if trip do
      navigate_to("/trips/#{trip.id}")
      :timer.sleep(500)
      {:ok, Map.put(state, :trip, trip)}
    else
      {:error, "No trip found to visit"}
    end
  end

  when_ ~r/^I visit the trip page for id (?<id>\d+)$/, fn state, %{"id" => id_s} ->
    id = String.to_integer(id_s)
    navigate_to("/trips/#{id}")
    :timer.sleep(500)
    {:ok, state}
  end

  given_ ~r/^I have performed (?<count>\d+) searches$/, fn state, %{"count" => count_s} ->
    count = String.to_integer(count_s)
    # create a user
    unique_id = :erlang.unique_integer([:positive])
    email = "bdd_user_#{unique_id}@example.com"

    {:ok, user} = Accounts.register_user(%{
      "username" => "bdd_user_#{unique_id}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Jane",
      "last_name" => "Doe",
      "email" => email,
      "birthdate" => "1990-01-01",
      "nationality" => "ID",
      "residence_address" => "BDD Lane",
      "phone_number" => "+628000000000"
    })

    now = DateTime.utc_now()

    for i <- 1..count do
      Repo.insert!(%SearchHistory{
        source_city: "City#{i}",
        destination_city: "Dest#{i}",
        user_id: user.id,
        inserted_at: DateTime.add(now, -i, :second)
      })
    end

    # login the user in the browser
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    :timer.sleep(500)
    submit_element({:id, "login-form"})
    :timer.sleep(1000)

    {:ok, Map.put(state, :user, user)}
  end

  when_ ~r/^I visit the search page$/, fn state, _ ->
    navigate_to("/search")
    :timer.sleep(500)
    {:ok, state}
  end

  then_ ~r/^I should see the recommended price$/, fn state, _ ->
    page = visible_page_text()
    if String.contains?(page, "Recommended") or String.contains?(page, "recommended price") do
      {:ok, state}
    else
      {:error, "Recommended price not found on page"}
    end
  end

  then_ ~r/^I should not see a recommended price$/, fn state, _ ->
    page = visible_page_text()
    if String.contains?(page, "Recommended") or String.contains?(page, "recommended price") do
      {:error, "Unexpected recommended price found"}
    else
      {:ok, state}
    end
  end

  then_ ~r/^I should see the trip details$/, fn state, _ ->
    page = visible_page_text()
    if String.contains?(page, "Price:") or String.contains?(page, "Available tickets") or String.contains?(page, "CO₂") do
      {:ok, state}
    else
      {:error, "Trip details not visible"}
    end
  end

  then_ ~r/^I should see a 404 page$/, fn state, _ ->
    page = visible_page_text()
    if String.contains?(page, "404") or String.contains?(page, "Not Found") or String.contains?(page, "Page not found") do
      {:ok, state}
    else
      {:error, "Expected 404 page"}
    end
  end

  then_ ~r/^I should see similar trips$/, fn state, _ ->
    page = visible_page_text()
    if String.contains?(page, "Similar trips") or String.contains?(page, "You might also like") do
      {:ok, state}
    else
      {:error, "Similar trips section not found"}
    end
  end

  then_ ~r/^I should see the recent searches section$/, fn state, _ ->
    page = visible_page_text()
    if String.contains?(page, "Recent Searches") or String.contains?(page, "Recent searches") do
      {:ok, state}
    else
      {:error, "Recent Searches not present"}
    end
  end
end
