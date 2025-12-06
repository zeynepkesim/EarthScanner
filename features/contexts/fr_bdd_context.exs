defmodule FRBDDContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Repo, Accounts}
  import Ecto.Query
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Searches.SearchHistory

  # Helper functions to safely parse captures
  defp safe_str(captures, key, default \\ "") do
    case Map.get(captures, key) do
      v when is_binary(v) -> v
      v when is_nil(v) -> default
      v -> to_string(v)
    end
  end

  defp safe_int(captures, key, default \\ 0) do
    case Map.get(captures, key) do
      v when is_integer(v) -> v
      v when is_binary(v) and v != "" ->
        case Integer.parse(v) do
          {i, _} -> i
          :error -> default
        end
      _ -> default
    end
  end

  defp safe_decimal(text, default_str \\ "0") do
    cond do
      is_binary(text) and text != "" ->
        try do
          Decimal.new(text)
        rescue
          _ -> Decimal.new(default_str)
        end
      is_nil(text) -> Decimal.new(default_str)
      true -> Decimal.new(to_string(text))
    end
  end

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, _state ->
    Hound.end_session()
    :ok
  end

  given_ ~r/^a trip exists with source "(?<source>[^"]+)" destination "(?<destination>[^"]+)" transport "(?<transport>[^"]+)" duration_minutes (?<duration>\d+) price "(?<price>[^"]+)"$/, fn state, captures ->
    s = safe_str(captures, "source")
    d = safe_str(captures, "destination")
    t = safe_str(captures, "transport")
    price_text = safe_str(captures, "price", "0")
    duration = safe_int(captures, "duration", 60)

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    dt = NaiveDateTime.add(now, 86_400, :second)

    trip = %Trip{
      source_city: s,
      destination_city: d,
      transport_mode: t,
      departure_time: dt,
      arrival_time: DateTime.add(dt, 3600, :second),
      duration_minutes: duration,
      price: safe_decimal(price_text, "0"),
      co2_level: 100,
      available_tickets: 10,
      admin_id: 1
    }

    Repo.insert!(trip)

    {:ok, state}
  end

  given_ ~r/^(?<count>\d+) similar trips exist for "(?<source>[^"]+)" to "(?<destination>[^"]+)"$/, fn state, captures ->
     count = safe_int(captures, "count", 0)

     s = safe_str(captures, "source")
     d = safe_str(captures, "destination")

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    dt = NaiveDateTime.add(now, 86_400, :second)

    if count > 0 do
      for _ <- 1..count do
        Repo.insert!(%Trip{
          source_city: s,
          destination_city: d,
          transport_mode: "bus",
          departure_time: dt,
          arrival_time: DateTime.add(dt, 3600, :second),
          duration_minutes: 60,
          price: Decimal.new("20"),
          co2_level: 100,
          available_tickets: 10,
          admin_id: 1
        })
      end
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

  when_ ~r/^I visit the trip page for id (?<id>\d+)$/, fn state, captures ->
     id = safe_int(captures, "id", 0)
    navigate_to("/trips/#{id}")
    :timer.sleep(500)
    {:ok, state}
  end

    given_ ~r/^I have performed (?<count>\d+) searches$/, fn state, captures ->
      count = safe_int(captures, "count", 0)
    # create a user with unique email to avoid constraint violations
    unique_id = :erlang.unique_integer([:positive])
    email = "bdd_user_#{unique_id}@example.com"

    user_result = Accounts.register_user(%{
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

    user = case user_result do
      {:ok, u} -> u
      {:error, changeset} ->
        raise "Failed to register user: #{inspect(changeset.errors)}"
    end

    now = NaiveDateTime.utc_now()

    if count > 0 do
      for i <- 1..count do
        Repo.insert!(%SearchHistory{
          source_city: "City#{i}",
          destination_city: "Dest#{i}",
          user_id: user.id,
          inserted_at: NaiveDateTime.add(now, -i, :second)
        })
      end
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
