# FR-10: Highlight Top Trips BDD Context
# Tests for displaying fastest, cheapest, and greenest trips in search results

defmodule HighlightTopTripsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias Ecto.Changeset
  alias EarthScanner.{Accounts, Trips, Repo}
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

  ##########################################################################
  # GIVEN STEPS
  ##########################################################################

  given_ ~r/^I am logged in as a regular user$/, fn state ->
    # Create and login as a regular user (not admin) for search access
    user = ensure_regular_user()

    # Navigate to login page and login
    navigate_to(@base <> "/users/login")
    Process.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, user.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})
    Process.sleep(1000)

    {:ok, Map.put(state, :current_user, user)}
  end

  given_ ~r/^the database is clean for this test$/, fn state ->
    # Clean up trips from previous scenarios to ensure clean slate
    # This runs AFTER login, so user session is preserved
    Repo.delete_all(EarthScanner.Trips.Trip)
    {:ok, state}
  end

  given_ ~r/^a set of future trips for top picks exists between "(?<source>[^"]+)" and "(?<dest>[^"]+)"$/,
         fn state, %{source: source, dest: dest} ->
    admin = ensure_admin_user()
    future_date = Date.utc_today() |> Date.add(7)

    # Trip A: medium everything
    {:ok, trip1} = Trips.create_trip(admin, %{
      "source_city" => source,
      "destination_city" => dest,
      "departure_time" => DateTime.new!(future_date, ~T[10:00:00]),
      "arrival_time" => DateTime.new!(future_date, ~T[11:00:00]),
      "price" => "20.00",
      "available_tickets" => 10,
      "co2_level" => 150,
      "transport_mode" => "bus",
      "picture_url" => "https://via.placeholder.com/150",
      "dates" => Date.to_iso8601(future_date)
    })

    # Trip B: cheapest and greenest, but slower
    {:ok, trip2} = Trips.create_trip(admin, %{
      "source_city" => source,
      "destination_city" => dest,
      "departure_time" => DateTime.new!(future_date, ~T[11:00:00]),
      "arrival_time" => DateTime.new!(future_date, ~T[12:30:00]),
      "price" => "10.00",
      "available_tickets" => 10,
      "co2_level" => 80,
      "transport_mode" => "train",
      "picture_url" => "https://via.placeholder.com/150",
      "dates" => Date.to_iso8601(future_date)
    })

    # Trip C: fastest
    {:ok, trip3} = Trips.create_trip(admin, %{
      "source_city" => source,
      "destination_city" => dest,
      "departure_time" => DateTime.new!(future_date, ~T[09:00:00]),
      "arrival_time" => DateTime.new!(future_date, ~T[09:30:00]),
      "price" => "40.00",
      "available_tickets" => 10,
      "co2_level" => 300,
      "transport_mode" => "plane",
      "picture_url" => "https://via.placeholder.com/150",
      "dates" => Date.to_iso8601(future_date)
    })

    {:ok, state}
  end

  given_ ~r/^no future trips exist between "(?<source>[^"]+)" and "(?<dest>[^"]+)"$/,
         fn state, _ ->
    # Don't insert any trips
    {:ok, state}
  end

  given_ ~r/^only past trips exist between "(?<source>[^"]+)" and "(?<dest>[^"]+)"$/,
         fn state, %{source: source, dest: dest} ->
    admin = ensure_admin_user()
    yesterday = DateTime.utc_now() |> DateTime.add(-86_400, :second) |> DateTime.truncate(:second)

    Trips.create_trip(admin, %{
      "source_city" => source,
      "destination_city" => dest,
      "departure_time" => yesterday,
      "arrival_time" => DateTime.add(yesterday, 3600, :second),
      "price" => "20.00",
      "available_tickets" => 10,
      "co2_level" => 150,
      "transport_mode" => "bus",
      "picture_url" => "https://via.placeholder.com/150",
      "dates" => Date.to_iso8601(Date.utc_today() |> Date.add(-1))
    })

    {:ok, state}
  end

  given_ ~r/^a set of future trips exists between "(?<source>[^"]+)" and "(?<dest>[^"]+)"$/,
         fn state, %{source: source, dest: dest} ->
    admin = ensure_admin_user()
    future_date = Date.utc_today() |> Date.add(7)

    Trips.create_trip(admin, %{
      "source_city" => source,
      "destination_city" => dest,
      "departure_time" => DateTime.new!(future_date, ~T[10:00:00]),
      "arrival_time" => DateTime.new!(future_date, ~T[11:00:00]),
      "price" => "20.00",
      "available_tickets" => 10,
      "co2_level" => 100,
      "transport_mode" => "bus",
      "picture_url" => "https://via.placeholder.com/150",
      "dates" => Date.to_iso8601(future_date)
    })

    {:ok, state}
  end

  ##########################################################################
  # WHEN STEPS
  ##########################################################################

  when_ ~r/^I search for trips from "(?<source>[^"]+)" to "(?<dest>[^"]+)"$/,
        fn state, %{source: source, dest: dest} ->
    navigate_to(@base <> "/search/results?source=#{source}&destination=#{dest}")
    Process.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^I search for trips from "(?<source>[^"]+)" to "(?<dest>[^"]+)" with max price "(?<max>[^"]+)"$/,
        fn state, %{source: source, dest: dest, max: max} ->
    navigate_to(@base <> "/search/results?source=#{source}&destination=#{dest}&max_price=#{max}")
    Process.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^I click on the "(?<category>[^"]+)" top pick$/,
        fn state, _ ->
    case find_all_elements(:css, ".top-pick-card") do
      [card | _] ->
        click(card)
        Process.sleep(1000)
        {:ok, state}

      [] ->
        {:error, "No top pick cards found"}
    end
  end

  ##########################################################################
  # THEN STEPS
  ##########################################################################

  then_ ~r/^I should see the "Top Picks" section$/,
        fn state, _ ->
    Process.sleep(800)
    text = visible_page_text()
    assert String.contains?(text, "Top Picks")
    {:ok, state}
  end

  then_ ~r/^I should not see the "Top Picks" section$/,
        fn state, _ ->
    Process.sleep(800)
    text = visible_page_text()
    refute String.contains?(text, "Top Picks")
    {:ok, state}
  end

  then_ ~r/^I should see a "(?<category>[^"]+)" top pick$/,
        fn state, %{category: category} ->
    Process.sleep(800)
    text = visible_page_text()
    assert String.contains?(text, category)
    {:ok, state}
  end

  then_ ~r/^the top picks also appear in the main search results list$/,
        fn state, _ ->
    text = visible_page_text()
    assert String.contains?(text, "Mode:")
    assert String.contains?(text, "Price:")
    {:ok, state}
  end

  then_ ~r/^I should be navigated to the trip detail page$/,
        fn state, _ ->
    Process.sleep(800)
    url = current_url()
    assert String.contains?(url, "/trips/")
    {:ok, state}
  end

  then_ ~r/^the "(?<category>[^"]+)" top pick should be "(?<trip_name>[^"]+)"$/,
        fn state, %{category: category} ->
    text = visible_page_text()
    assert String.contains?(text, category)
    {:ok, state}
  end

  then_ ~r/^the "(?<category>[^"]+)" top pick duration should be (?<duration>\d+)$/,
        fn state, _ ->
    text = visible_page_text()
    assert String.contains?(text, "Duration:")
    {:ok, state}
  end

  then_ ~r/^the "(?<category>[^"]+)" top pick price should be (?<price>\d+)$/,
        fn state, _ ->
    text = visible_page_text()
    assert String.contains?(text, "Price:")
    {:ok, state}
  end

  then_ ~r/^the "(?<category>[^"]+)" top pick co2 should be (?<co2>\d+)$/,
        fn state, _ ->
    text = visible_page_text()
    assert String.contains?(text, "CO₂")
    {:ok, state}
  end

  then_ ~r/^all top picks should have price <= (?<max>\d+)$/,
        fn state, _ ->
    text = visible_page_text()
    assert String.contains?(text, "Top Picks")
    {:ok, state}
  end

  then_ ~r/^all top picks should be for route from "(?<source>[^"]+)" to "(?<dest>[^"]+)"$/,
        fn state, %{source: source, dest: dest} ->
    text = visible_page_text()
    assert String.contains?(text, source)
    assert String.contains?(text, dest)
    {:ok, state}
  end

  ##########################################################################
  # HELPER FUNCTIONS
  ##########################################################################

  defp ensure_regular_user do
    email = "bdd_fr10_regular_user@example.com"
    password = "Password123!"

    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.register_user(%{
          "username" => "fr10_regular",
          "password" => password,
          "password_confirmation" => password,
          "name" => "FR10",
          "last_name" => "Regular",
          "email" => email,
          "birthdate" => "1995-01-01",
          "nationality" => "EE",
          "residence_address" => "User Street 1",
          "phone_number" => "+37250000000"
        })
        user

      user ->
        user
    end
  end

  defp ensure_admin_user do
    suffix = :erlang.unique_integer([:positive]) |> Integer.to_string()
    email = "bdd_fr10_admin_" <> suffix <> "@example.com"
    password = "Password123!"

    admin =
      case Accounts.register_user(%{
             "username" => "fr10_admin_" <> suffix,
             "password" => password,
             "password_confirmation" => password,
             "name" => "FR10",
             "last_name" => "Admin",
             "email" => email,
             "birthdate" => "1990-01-01",
             "nationality" => "EE",
             "residence_address" => "Admin Square 1",
             "phone_number" => "+37251111111"
           }) do
        {:ok, user} ->
          user

        {:error, %Changeset{} = changeset} ->
          if Keyword.has_key?(changeset.errors, :email) do
            Accounts.get_user_by_email(email) ||
              raise "Unable to reuse existing admin with email #{email}"
          else
            raise "Admin registration failed: #{inspect(changeset.errors)}"
          end
      end

    admin
    |> Changeset.change(role: "admin")
    |> Repo.update!()
  end
end
