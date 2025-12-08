defmodule HighlightSoldOutTripsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Repo, Trips, Accounts}
  alias EarthScanner.Trips.{Trip, TripInstance}

  @base "http://localhost:4002"

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, state ->
    Hound.end_session()
    {:ok, state}
  end

  # FR-15: Login step (required for search page access)
  given_ ~r/^I am logged in as a normal user$/, fn state, _ ->
    # Create unique user for this test
    suffix = Integer.to_string(System.unique_integer([:positive]))
    email = "fr15user_#{suffix}@example.com"
    password = "Password123!"

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "fr15_u_#{suffix}",
        "password" => password,
        "password_confirmation" => password,
        "name" => "FR15",
        "last_name" => "User",
        "email" => email,
        "birthdate" => "1995-01-01",
        "nationality" => "EE",
        "residence_address" => "Test St",
        "phone_number" => "+37250000000"
      })

    navigate_to(@base <> "/users/login")
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, password)
    submit_element({:id, "login-form"})
    Process.sleep(500)  # Wait for login to complete

    {:ok, Map.put(state, :user, user)}
  end

  # FR-15: Given step for sold-out trip
  given_ ~r/^a sold-out future trip exists from "(?<source>[^"]+)" to "(?<dest>[^"]+)"$/, fn state, %{source: source, dest: dest} ->
    base_time =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.add(86_400, :second)

    trip =
      Repo.insert!(%Trip{
        source_city: source,
        destination_city: dest,
        transport_mode: "bus",
        departure_time: base_time,
        arrival_time: DateTime.add(base_time, 3600, :second),
        duration_minutes: 60,
        price: 30,
        co2_level: 200,
        available_tickets: 10,
        picture_url: "https://via.placeholder.com/150",
        admin_id: get_or_create_test_admin().id
      })

    # Sold-out instance (available_tickets = 0)
    Repo.insert!(%TripInstance{
      trip_id: trip.id,
      date: Date.add(Date.utc_today(), 1),
      available_tickets: 0
    })

    {:ok, state}
  end

  # FR-15: Given step for trip with available tickets
  given_ ~r/^a trip with available tickets exists from "(?<source>[^"]+)" to "(?<dest>[^"]+)"$/, fn state, %{source: source, dest: dest} ->
    base_time =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.add(86_400, :second)

    trip =
      Repo.insert!(%Trip{
        source_city: source,
        destination_city: dest,
        transport_mode: "train",
        departure_time: base_time,
        arrival_time: DateTime.add(base_time, 3600, :second),
        duration_minutes: 60,
        price: 25,
        co2_level: 100,
        available_tickets: 10,
        picture_url: "https://via.placeholder.com/150",
        admin_id: get_or_create_test_admin().id
      })

    # Instance with available tickets
    Repo.insert!(%TripInstance{
      trip_id: trip.id,
      date: Date.add(Date.utc_today(), 1),
      available_tickets: 5
    })

    {:ok, state}
  end

  # FR-15: Edge case - trip with SOME sold-out, SOME available instances
  given_ ~r/^a trip with mixed sold-out and available instances exists from "(?<source>[^"]+)" to "(?<dest>[^"]+)"$/, fn state, %{source: source, dest: dest} ->
    base_time =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.add(86_400, :second)

    trip =
      Repo.insert!(%Trip{
        source_city: source,
        destination_city: dest,
        transport_mode: "bus",
        departure_time: base_time,
        arrival_time: DateTime.add(base_time, 3600, :second),
        duration_minutes: 60,
        price: 28,
        co2_level: 130,
        available_tickets: 10,
        picture_url: "https://via.placeholder.com/150",
        admin_id: get_or_create_test_admin().id
      })

    # Create one sold-out instance
    Repo.insert!(%TripInstance{
      trip_id: trip.id,
      date: Date.add(Date.utc_today(), 1),
      available_tickets: 0
    })

    # Create one instance with available tickets
    Repo.insert!(%TripInstance{
      trip_id: trip.id,
      date: Date.add(Date.utc_today(), 2),
      available_tickets: 5
    })

    {:ok, state}
  end

  # When steps
  when_ ~r/^I search for trips from "(?<source>[^"]+)" to "(?<dest>[^"]+)"$/, fn state, %{source: source, dest: dest} ->
    navigate_to(@base <> "/search/results?source=#{source}&destination=#{dest}")
    Process.sleep(2000)  # Increased sleep for full page load
    {:ok, state}
  end

  # Then steps
  then_ ~r/^I should see the sold-out trip highlighted$/, fn state, _ ->
    html = visible_page_text()
    source_html = page_source()

    # First check if ANY trip appears
    has_trip = String.contains?(html, "Mode:") or String.contains?(html, "€")

    unless has_trip do
      {:error, "No trips in search results - trip not created or filtered out"}
    else
      # Now check for sold-out indicators
      has_message = String.contains?(html, "All future dates are sold out")
      has_button = String.contains?(source_html, "data-role=\"sold-out-button\"")
      has_soldout = String.contains?(html, "Sold out")

      if has_message or has_button or has_soldout do
        {:ok, state}
      else
        {:error, "Trip found but no sold-out indicators"}
      end
    end
  end

  then_ ~r/^the purchase button should be disabled for that trip$/, fn state, _ ->
    html = page_source()

    # Check for disabled button or sold-out message
    has_disabled = String.contains?(html, "data-role=\"sold-out-button\"")
    has_message = String.contains?(html, "All future dates are sold out")

    if has_disabled or has_message do
      {:ok, state}
    else
      {:error, "No disabled button or sold-out message found"}
    end
  end

  then_ ~r/^I should NOT see sold-out highlighting$/, fn state, _ ->
    html = visible_page_text()

    # Should NOT contain sold-out message
    if String.contains?(html, "All future dates are sold out.") do
      {:error, "Sold-out highlighting found but shouldn't be present"}
    else
      {:ok, state}
    end
  end

  then_ ~r/^the purchase button should be enabled$/, fn state, _ ->
    html = page_source()

    # Should NOT have sold-out button
    if String.contains?(html, "data-role=\"sold-out-button\"") do
      {:error, "Found disabled button but should be enabled"}
    else
      {:ok, state}
    end
  end

  # Helper functions
  defp get_or_create_test_admin do
    email = "fr15_test_admin@example.com"

    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, admin} =
          Accounts.register_user(%{
            "username" => "fr15_admin",
            "password" => "Password123!",
            "password_confirmation" => "Password123!",
            "name" => "FR15",
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
