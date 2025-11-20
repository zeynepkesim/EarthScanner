# FR-32 Admin Edit Trip
defmodule AdminEditTripsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.Accounts
  alias EarthScanner.Trips
  alias EarthScanner.Repo
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Trips.TripInstance
  alias EarthScanner.Purchases.Purchase
  import Ecto.Changeset

  @base "http://localhost:4002"

  #
  # SESSION MANAGEMENT
  #
  scenario_starting_state fn state ->
    Hound.start_session()
    state
  end

  scenario_finalize fn _status, _state ->
    Hound.end_session()
    :ok
  end

  #
  # BACKGROUND
  #
  given_ ~r/^an admin user "([^"]+)" with password "([^"]+)" exists$/, fn state, _step_data ->
    email = "admin@example.com"
    password = "Password123!"

    admin =
      case Accounts.get_user_by_email(email) do
        nil ->
          {:ok, user} =
            Accounts.register_user(%{
              "username" => "admin_bdd_edit",
              "password" => password,
              "password_confirmation" => password,
              "name" => "Admin",
              "last_name" => "Edit",
              "email" => email,
              "birthdate" => "1990-01-01",
              "nationality" => "ID",
              "residence_address" => "Admin Street 1",
              "phone_number" => "+628111111111",
              "role" => "admin"
            })

          user

        user ->
          user
      end

    {:ok, Map.put(state, :admin, admin)}
  end

  #
  # TRIP FIXTURES
  #
  given_ ~r/^a future trip exists with id "([^"]+)" created by "([^"]+)"$/, fn state, %{matches: [id, email]} ->
    {:ok, trip} =
      Trips.upsert_trip(%{
        id: String.to_integer(id),
        creator_email: email,
        source_city: "Tallinn",
        destination_city: "Helsinki",
        departure_time: DateTime.utc_now() |> DateTime.add(3600 * 24, :second),
        arrival_time: DateTime.utc_now() |> DateTime.add(3600 * 25, :second),
        price: 10.0,
        co2_level: 100,
        available_tickets: 20
      })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^a past trip exists with id "([^"]+)"$/, fn state, %{matches: [id]} ->
    {:ok, trip} =
      Trips.upsert_trip(%{
        id: String.to_integer(id),
        source_city: "Tallinn",
        destination_city: "Riga",
        departure_time: DateTime.utc_now() |> DateTime.add(-3600 * 24, :second),
        arrival_time: DateTime.utc_now() |> DateTime.add(-3600 * 23, :second),
        price: 20.0,
        co2_level: 150,
        available_tickets: 10
      })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^a future trip exists with id "([^"]+)" and it has sold tickets$/, fn state, %{matches: [id]} ->
    {:ok, trip} =
      Trips.upsert_trip(%{
        id: String.to_integer(id),
        source_city: "Tallinn",
        destination_city: "Stockholm",
        departure_time: DateTime.utc_now() |> DateTime.add(3600 * 24, :second),
        arrival_time: DateTime.utc_now() |> DateTime.add(3600 * 25, :second),
        price: 50.0,
        co2_level: 300,
        available_tickets: 100,
        sold_tickets: 5
      })

    {:ok, Map.put(state, :trip, trip)}
  end

  #
  # LOGIN
  #
  when_ ~r/^I log in as "([^"]+)" with password "([^"]+)"$/, fn state, %{matches: [email, password]} ->
    navigate_to("#{@base}/login")

    fill_field({:id, "email"}, email)
    fill_field({:id, "password"}, password)
    click({:css, "button[type=submit]"})

    assert page_source() =~ "Dashboard"
    {:ok, state}
  end

  #
  # NAVIGATION
  #
  when_ ~r/^I navigate to the trip edit page for trip "([^"]+)"$/, fn state, %{matches: [id]} ->
    navigate_to("#{@base}/admin/trips/#{id}/edit")

    assert current_url() =~ "/admin/trips/#{id}"
    {:ok, state}
  end

  #
  # UPDATE TRIP WITH TABLE
  #
  when_ ~r/^I update the trip with:$/, fn state, %{table: table} ->
    Enum.each(table, fn
      {"picture_url", value} -> fill_field({:name, "trip[picture_url]"}, value)
      {"transport_mode", value} -> execute_script("""
       var s = document.querySelector('select[name="trip[transport_mode]"]');
       if (s) s.value = "#{value}";
      """)
      {"source_city", value} -> fill_field({:name, "trip[source_city]"}, value)
      {"destination_city", value} -> fill_field({:name, "trip[destination_city]"}, value)
      {"departure_time", value} -> fill_field({:name, "trip[departure_time]"}, value)
      {"arrival_time", value} -> fill_field({:name, "trip[arrival_time]"}, value)
      {"price", value} -> fill_field({:name, "trip[price]"}, value)
      {"co2_level", value} -> fill_field({:name, "trip[co2_level]"}, value)
      {"available_tickets", value} -> fill_field({:name, "trip[available_tickets]"}, value)
      _ -> :ok
    end)
    {:ok, state}
  end

  #
  # CHANGE ONE FIELD
  #
  when_ ~r/^I change the trip departure_time to "([^"]+)"$/, fn state, %{matches: [value]} ->
    fill_field({:name, "trip[departure_time]"}, value)
    {:ok, state}
  end

  #
  # SUBMIT UPDATE
  #
  when_ ~r/^I submit the trip update$/, fn state ->
    click({:css, "button[type=submit]"})
    {:ok, state}
  end

  #
  # CONFIRM WARNING
  #
  when_ ~r/^I confirm the update$/, fn state ->
    click({:css, "button.confirm-update"})
    {:ok, state}
  end

  #
  # ASSERTIONS
  #
  then_ ~r/^I should see a confirmation that the trip was updated$/, fn state ->
    assert page_source() =~ "Trip updated"
    {:ok, state}
  end

  then_ ~r/^the updated data should appear immediately in the trip details page$/, fn state ->
    assert page_source() =~ "Paris"
    assert page_source() =~ "180"
    {:ok, state}
  end

  then_ ~r/^I should see that the trip is read\-only$/, fn state ->
    assert page_source() =~ "Read-only"
    {:ok, state}
  end

  then_ ~r/^I should not be able to submit updates$/, fn state ->
    assert length(find_all_elements(:css, "button[type=submit]")) == 0
    {:ok, state}
  end

  then_ ~r/^I should see an error saying "([^"]+)"$/, fn state, %{matches: [msg]} ->
    assert page_source() =~ msg
    {:ok, state}
  end

  then_ ~r/^I should see a warning about changing critical information$/, fn state ->
    assert page_source() =~ "Warning"
    {:ok, state}
  end

  then_ ~r/^I should be asked to confirm the change$/, fn state ->
    assert page_source() =~ "Confirm update"
    {:ok, state}
  end
end
