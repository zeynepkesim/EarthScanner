# FR-32: Admin can update trip information
defmodule AdminEditTripsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.Accounts
  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Repo

  @base "http://localhost:4002"

  #
  # SESSION
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
  # ADMIN EXISTS
  #
  given_ ~r/^an admin user "(?<email>[^\"]+)" with password "(?<password>[^\"]+)" exists$/,
  fn state, %{email: email, password: password} ->
    username = "bddadmin_" <> Base.encode16(:crypto.strong_rand_bytes(3))

    admin =
      case Accounts.get_user_by_email(email) do
        nil ->
          {:ok, user} =
            Accounts.register_user(%{
              "username" => username,
              "email" => email,
              "password" => password,
              "password_confirmation" => password,
              "name" => "BDD",
              "last_name" => "Admin",
              "birthdate" => "1990-01-01",
              "nationality" => "TR",
              "residence_address" => "Admin Street",
              "phone_number" => "+905551111111",
              "role" => "admin"
            })

          user

        user -> user
      end

    {:ok, Map.put(state, :admin, admin)}
  end

  # Support the feature's simple phrase: "Given a future trip exists"
  given_ ~r/^a future trip exists$/, fn state ->
    admin =
      Accounts.get_user_by_email("admin@example.com") ||
        (case Accounts.register_user(%{
               "username" => "admin",
               "password" => "Password123!",
               "password_confirmation" => "Password123!",
               "name" => "Admin",
               "last_name" => "User",
               "email" => "admin@example.com",
               "birthdate" => "1990-01-01",
               "nationality" => "ID",
               "residence_address" => "Admin Street",
               "phone_number" => "+628111111111",
               "role" => "admin"
             }) do
           {:ok, u} -> u
           {:error, _} -> Accounts.get_user_by_email("admin@example.com")
         end)

    {:ok, trip} = Trips.create_trip(admin, %{
      transport_mode: "plane",
      source_city: "Tallinn",
      destination_city: "Helsinki",
      departure_time: DateTime.utc_now() |> DateTime.add(86400, :second),
      arrival_time: DateTime.utc_now() |> DateTime.add(90000, :second),
      price: 10.0,
      co2_level: 100,
      available_tickets: 20
    })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^I am logged in as an admin$/, fn state, _ ->
  admin =
    case Accounts.get_user_by_email("admin@example.com") do
      nil ->
        {:ok, user} =
          Accounts.register_user(%{
            "username" => "admin",
            "password" => "Password123!",
            "password_confirmation" => "Password123!",
            "name" => "Admin",
            "last_name" => "User",
            "email" => "admin@example.com",
            "birthdate" => "1990-01-01",
            "nationality" => "ID",
            "residence_address" => "Admin Street",
            "phone_number" => "+628111111111",
            "role" => "admin"
          })

        user

      user ->
        user
    end

  navigate_to("http://localhost:4002/users/login")
  :timer.sleep(500)
  fill_field({:css, "input[name='session[email]']"}, "admin@example.com")
  fill_field({:css, "input[name='session[password]']"}, "Password123!")
  :timer.sleep(500)
  submit_element({:id, "login-form"})
  :timer.sleep(2000)

  {:ok, Map.put(state, :admin, admin)}
end

  #
  # TRIP FIXTURES
  #
  given_ ~r/^a future trip exists created by "(?<email>[^\"]+)"$/, fn state, %{email: email} ->
    admin =
      Accounts.get_user_by_email(email) ||
        Accounts.register_user(%{
          "username" => String.split(email, "@") |> List.first(),
          "email" => email,
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "name" => "Admin",
          "last_name" => "User",
          "birthdate" => "1990-01-01",
          "nationality" => "TR",
          "residence_address" => "Admin Street",
          "phone_number" => "+905551111111",
          "role" => "admin"
        }) |> elem(1)

    {:ok, trip} = Trips.create_trip(admin, %{
      transport_mode: "plane",
      source_city: "Tallinn",
      destination_city: "Helsinki",
      departure_time: DateTime.utc_now() |> DateTime.add(86400, :second),
      arrival_time: DateTime.utc_now() |> DateTime.add(90000, :second),
      price: 10.0,
      co2_level: 100,
      available_tickets: 20
    })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^a past trip exists$/, fn state ->
    admin = hd(Accounts.list_users()) # Берем любого существующего админа

    {:ok, trip} = Trips.create_trip(admin, %{
      transport_mode: "plane",
      source_city: "Tallinn",
      destination_city: "Riga",
      departure_time: DateTime.utc_now() |> DateTime.add(-86400, :second),
      arrival_time: DateTime.utc_now() |> DateTime.add(-82800, :second),
      price: 20.0,
      co2_level: 150,
      available_tickets: 10
    })

    {:ok, Map.put(state, :trip, trip)}
  end

  #
  # LOGIN
  #
  when_ ~r/^I log in as "(?<email>[^"]+)" with password "(?<password>[^"]+)"$/,
  fn state, %{email: email, password: password} ->
    navigate_to("#{@base}/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, password)
    :timer.sleep(500)

    submit_element({:id, "login-form"})
    :timer.sleep(2000)

    assert page_source() =~ "Dashboard"
    {:ok, state}
  end

  #
  # NAVIGATION
  #
  when_ ~r/^I navigate to the trip edit page for trip "(?<id>\d+)"$/,
  fn state, %{id: id} ->
    navigate_to("#{@base}/admin/trips/#{id}/edit")
    :timer.sleep(1000)
    assert current_url() =~ "/admin/trips/#{id}/edit"
    {:ok, state}
  end

  # Allow navigating to the trip edit page using the trip stored in state
  when_ ~r/^I navigate to the trip edit page for the future trip$/, fn state ->
    trip = Map.fetch!(state, :trip)
    navigate_to("#{@base}/admin/trips/#{trip.id}/edit")
    :timer.sleep(1000)
    assert current_url() =~ "/admin/trips/#{trip.id}/edit"
    {:ok, state}
  end

  #
  # UPDATE FORM
  #
  when_ ~r/^I update the trip with:$/, fn state, %{table: table} ->
    :timer.sleep(500)
    Enum.each(table, fn
        {"picture_url", v} -> fill_field({:name, "trip[picture_url]"}, v)
        {"transport_mode", v} -> fill_field({:name, "trip[transport_mode]"}, v)
        {"source_city", v} -> fill_field({:name, "trip[source_city]"}, v)
        {"destination_city", v} -> fill_field({:name, "trip[destination_city]"}, v)
        {"departure_time", v} -> fill_field({:name, "trip[departure_time]"}, v)
        {"arrival_time", v} -> fill_field({:name, "trip[arrival_time]"}, v)
        {"price", v} -> fill_field({:name, "trip[price]"}, v)
        {"co2_level", v} -> fill_field({:name, "trip[co2_level]"}, v)
        {"available_tickets", v} -> fill_field({:name, "trip[available_tickets]"}, v)
        _ -> :ok
      end)
    {:ok, state}
  end

  #
  # SUBMIT
  #
  when_ ~r/^I submit the trip update$/, fn state ->
    click({:css, "button[type=submit]"})
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I confirm the update$/, fn state ->
    click({:css, "button.confirm-update"})
    :timer.sleep(500)
    {:ok, state}
  end

  #
  # ASSERTIONS
  #
  then_ ~r/^I should see a confirmation that the trip was updated$/, fn state ->
    :timer.sleep(500)
    assert page_source() =~ "Trip updated"
    {:ok, state}
  end

  then_ ~r/^the updated data should appear immediately in the trip details page$/, fn state ->
    :timer.sleep(500)
    assert page_source() =~ "Paris"
    assert page_source() =~ "180"
    {:ok, state}
  end

  then_ ~r/^I should see that the trip is read-only$/, fn state ->
    :timer.sleep(500)
    assert page_source() =~ "Read-only"
    {:ok, state}
  end

  then_ ~r/^I should not be able to submit updates$/, fn state ->
    :timer.sleep(500)
    buttons = find_all_elements(:css, "button[type=submit]")
    assert length(buttons) == 0
    {:ok, state}
  end

  then_ ~r/^I should see an error saying "(?<msg>[^"]+)"$/, fn state, %{msg: msg} ->
    :timer.sleep(500)
    assert page_source() =~ msg
    {:ok, state}
  end

  then_ ~r/^I should see a warning about changing critical information$/, fn state ->
    :timer.sleep(500)
    assert page_source() =~ "Warning"
    {:ok, state}
  end

  then_ ~r/^I should be asked to confirm the change$/, fn state ->
    :timer.sleep(500)
    assert page_source() =~ "Confirm update"
    {:ok, state}
  end
end
