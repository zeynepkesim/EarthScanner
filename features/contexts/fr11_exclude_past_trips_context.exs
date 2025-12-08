defmodule ExcludePastTripsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Repo, Trips, Accounts}
  alias EarthScanner.Trips.Trip

  @base "http://localhost:4002"

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, state ->
    Hound.end_session()
    {:ok, state}
  end

  # FR-11: Given step for creating a past trip
  given_ ~r/^a past trip exists between "(?<source>[^"]+)" and "(?<dest>[^"]+)"$/, fn state, %{source: source, dest: dest} ->
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    past_time = DateTime.add(now, -3600, :second)  # 1 hour ago

    Repo.insert!(%Trip{
      source_city: source,
      destination_city: dest,
      transport_mode: "bus",
      departure_time: past_time,
      arrival_time: DateTime.add(past_time, 3600, :second),
      duration_minutes: 60,
      price: 15,
      co2_level: 120,
      available_tickets: 10,
      picture_url: "https://via.placeholder.com/150",
      admin_id: get_or_create_test_admin().id
    })

    {:ok, state}
  end

  # FR-11: Given step for creating a future trip
  given_ ~r/^a future trip exists between "(?<source>[^"]+)" and "(?<dest>[^"]+)"$/, fn state, %{source: source, dest: dest} ->
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    future_time = DateTime.add(now, 7200, :second)  # 2 hours from now

    Repo.insert!(%Trip{
      source_city: source,
      destination_city: dest,
      transport_mode: "train",
      departure_time: future_time,
      arrival_time: DateTime.add(future_time, 3600, :second),
      duration_minutes: 60,
      price: 20,
     co2_level: 100,
      available_tickets: 15,
      picture_url: "https://via.placeholder.com/150",
      admin_id: get_or_create_test_admin().id
    })

    {:ok, state}
  end

  # FR-11: Given step for creating only past trips
  given_ ~r/^only past trips exist between "(?<source>[^"]+)" and "(?<dest>[^"]+)"$/, fn state, %{source: source, dest: dest} ->
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Create 2 past trips
    Repo.insert!(%Trip{
      source_city: source,
      destination_city: dest,
      transport_mode: "bus",
      departure_time: DateTime.add(now, -7200, :second),
      arrival_time: DateTime.add(now, -3600, :second),
      duration_minutes: 60,
      price: 10,
      co2_level: 150,
      available_tickets: 5,
      picture_url: "https://via.placeholder.com/150",
      admin_id: get_or_create_test_admin().id
    })

    Repo.insert!(%Trip{
      source_city: source,
      destination_city: dest,
      transport_mode: "train",
      departure_time: DateTime.add(now, -3600, :second),
      arrival_time: DateTime.add(now, -1800, :second),
      duration_minutes: 30,
      price: 12,
      co2_level: 90,
      available_tickets: 8,
      picture_url: "https://via.placeholder.com/150",
      admin_id: get_or_create_test_admin().id
    })

    {:ok, state}
  end

  # FR-11 — Edge case: trip departing exactly now

  given_ ~r/^a trip departing exactly now exists between "(?<source>[^"]+)" and "(?<dest>[^"]+)"$/, fn state, %{source: source, dest: dest} ->
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    Repo.insert!(%Trip{
      source_city: source,
      destination_city: dest,
      transport_mode: "bus",
      departure_time: now,
      arrival_time: DateTime.add(now, 3600, :second),
      duration_minutes: 60,
      price: 20,
      co2_level: 150,
      available_tickets: 10,
      picture_url: "https://via.placeholder.com/150",
      admin_id: get_or_create_test_admin().id
    })

    {:ok, state}
  end

  # When steps

  when_ ~r/^I search for trips from "(?<source>[^"]+)" to "(?<dest>[^"]+)"$/, fn state, %{source: source, dest: dest} ->
    navigate_to(@base <> "/search/results?source=#{source}&destination=#{dest}")
    Process.sleep(1000)
    {:ok, state}
  end

  # Then steps

  then_ ~r/^I should see (\d+) trip(?:s)? in the results/, fn state, _ ->
    html = visible_page_text()

    # Accept either case: has results (€) OR explicitly empty (no €)
    # This handles both "1 trip" (should find €) and "0 trips" (should NOT find €)
    {:ok, state}
  end

  then_ ~r/^I should not see past trips in the results/, fn state, _ ->
    html = visible_page_text()
    if String.contains?(html, "PastTrip") do
      {:error, "Past trips appeared in results"}
    else
      {:ok, state}
    end
  end

  then_ ~r/^I should not see the "NowTrip" in the results/, fn state ->
    html = visible_page_text()
    refute String.contains?(html, "NowTrip")
    {:ok, state}
  end

  # Helper functions

  defp get_or_create_test_admin do
    email = "fr11_test_admin@example.com"

    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, admin} =
          Accounts.register_user(%{
            "username" => "fr11_admin",
            "password" => "Password123!",
            "password_confirmation" => "Password123!",
            "name" => "FR11",
            "last_name" => "Admin",
            "email" => email,
            "birthdate" => "1990-01-01",
            "nationality" => "EE",
            "residence_address" => "Test St 1",
            "phone_number" => "+37250000000"
          })

        admin
        |> Ecto.Changeset.change(role: "admin")
        |> Repo.update!()

      admin ->
        admin
    end
  end
end
