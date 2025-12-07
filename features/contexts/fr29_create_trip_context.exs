defmodule CreateTripContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Accounts, Repo}

  #
  # Scenario lifecycle
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
  # GIVEN
  #

  given_ ~r/^an admin user "(?<email>[^"]+)" with password "(?<password>[^"]+)" exists$/, fn state, %{email: email, password: password} ->
    # Delete existing user if present (avoid stale password from previous test runs)
    if user = Accounts.get_user_by_email(email) do
      # CRITICAL: Delete admin's trips first to avoid foreign key constraint
      import Ecto.Query
      Repo.delete_all(from t in EarthScanner.Trips.Trip, where: t.admin_id == ^user.id)
      # Now we can delete the user
      Repo.delete!(user)
    end

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "admin_bdd_fr29",
        "password" => password,
        "password_confirmation" => password,
        "name" => "Admin",
        "last_name" => "User",
        "email" => email,
        "birthdate" => "1990-01-01",
        "nationality" => "ID",
        "residence_address" => "Admin Street",
        "phone_number" => "+628111111111"
      })

    # Set role to "admin" (matches controller check: %{role: "admin"})
    admin = Repo.update!(Ecto.Changeset.change(user, role: "admin"))

    {:ok, Map.put(state, :admin, admin)}
  end

  given_ ~r/^a regular user "(?<email>[^"]+)" with password "(?<password>[^"]+)" exists$/, fn state, %{email: email, password: password} ->
    # Delete existing user if present (avoid stale password from previous test runs)
    if user = Accounts.get_user_by_email(email) do
      Repo.delete!(user)
    end

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "regular_user_bdd_fr29",
        "password" => password,
        "password_confirmation" => password,
        "name" => "Regular",
        "last_name" => "User",
        "email" => email,
        "birthdate" => "1995-05-15",
        "nationality" => "US",
        "residence_address" => "User Street",
        "phone_number" => "+15551234567"
      })

    {:ok, Map.put(state, :regular_user, user)}
  end

  #
  # WHEN
  #

  when_ ~r/^I log in as "(?<email>[^"]+)" with password "(?<password>[^"]+)"$/, fn state, %{email: email, password: password} ->
    navigate_to("http://127.0.0.1:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, password)
    submit_element({:id, "login-form"})
    :timer.sleep(1500)

    # CRITICAL: Verify login was successful (fail early)
    text = visible_page_text()
    current_page = current_url()

    unless String.contains?(text, "Log out") or String.contains?(text, "Signed in") or String.contains?(current_page, "/trips") do
      raise """
      Login appears to have failed!
      URL: #{current_page}
      Page contains: #{String.slice(text, 0, 300)}
      """
    end

    {:ok, state}
  end

  when_ ~r/^I navigate to the admin trip creation page$/, fn state, _ ->
    navigate_to("http://127.0.0.1:4002/admin/trips/new")
    :timer.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^I fill in a valid trip with:$/, fn state, %{table_data: table} ->
    data = parse_table_data(table)

    picture_url = Map.get(data, "picture_url", "https://example.com/trip.jpg")
    fill_field({:css, "input[name='trip[picture_url]']"}, picture_url)

    fill_field({:css, "input[name='trip[source_city]']"}, data["source_city"])
    fill_field({:css, "input[name='trip[destination_city]']"}, data["destination_city"])

    departure = format_datetime_for_input(data["departure_time"])
    arrival = format_datetime_for_input(data["arrival_time"])

    fill_field({:css, "input[name='trip[departure_time]']"}, departure)
    fill_field({:css, "input[name='trip[arrival_time]']"}, arrival)

    fill_field({:css, "input[name='trip[price]']"}, data["price"])
    fill_field({:css, "input[name='trip[co2_level]']"}, data["co2_level"])
    fill_field({:css, "input[name='trip[available_tickets]']"}, data["available_tickets"])

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) s.value = "#{data["transport_mode"]}";
    """)

    fill_field({:css, "textarea[name='trip[dates]']"}, data["dates"])

    :timer.sleep(500)
    {:ok, state}
  end

  when_ "I submit the trip form", fn state ->
    submit_element({:css, "form"})
    :timer.sleep(1500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with invalid transport mode "(?<mode>[^"]+)"$/, fn state, %{mode: mode} ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Paris")
    fill_field({:css, "input[name='trip[departure_time]']"}, "2025-11-20T10:00")
    fill_field({:css, "input[name='trip[arrival_time]']"}, "2025-11-20T13:00")
    fill_field({:css, "input[name='trip[price]']"}, "150.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "50")
    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) {
        var opt = document.createElement('option');
        opt.value = "#{mode}";
        opt.text = "#{mode}";
        s.appendChild(opt);
        s.value = "#{mode}";
      }
    """)

    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with negative price "(?<price>[^"]+)"$/, fn state, %{price: price} ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Paris")
    fill_field({:css, "input[name='trip[departure_time]']"}, "2025-11-20T10:00")
    fill_field({:css, "input[name='trip[arrival_time]']"}, "2025-11-20T13:00")
    fill_field({:css, "input[name='trip[price]']"}, price)
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "50")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) s.value = "plane";
    """)

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ "I fill in a trip with zero available tickets", fn state ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Paris")
    fill_field({:css, "input[name='trip[departure_time]']"}, "2025-11-20T10:00")
    fill_field({:css, "input[name='trip[arrival_time]']"}, "2025-11-20T13:00")
    fill_field({:css, "input[name='trip[price]']"}, "150.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "0")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) s.value = "plane";
    """)

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ "I fill in a trip with arrival before departure", fn state ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Paris")
    fill_field({:css, "input[name='trip[departure_time]']"}, "2025-11-20T13:00")
    fill_field({:css, "input[name='trip[arrival_time]']"}, "2025-11-20T10:00")
    fill_field({:css, "input[name='trip[price]']"}, "150.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "50")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) s.value = "plane";
    """)

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ "I fill in a trip without picture URL", fn state ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Paris")
    fill_field({:css, "input[name='trip[departure_time]']"}, "2025-11-20T10:00")
    fill_field({:css, "input[name='trip[arrival_time]']"}, "2025-11-20T13:00")
    fill_field({:css, "input[name='trip[price]']"}, "150.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "50")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) s.value = "plane";
    """)

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip without source city$/, fn state, _ ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Paris")
    fill_field({:css, "input[name='trip[departure_time]']"}, "2025-11-20T10:00")
    fill_field({:css, "input[name='trip[arrival_time]']"}, "2025-11-20T13:00")
    fill_field({:css, "input[name='trip[price]']"}, "150.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "50")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) s.value = "plane";
    """)

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip without destination city$/, fn state, _ ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    fill_field({:css, "input[name='trip[destination_city]']"}, "")
    fill_field({:css, "input[name='trip[departure_time]']"}, "2025-11-20T10:00")
    fill_field({:css, "input[name='trip[arrival_time]']"}, "2025-11-20T13:00")
    fill_field({:css, "input[name='trip[price]']"}, "150.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "50")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) s.value = "plane";
    """)

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21")
    :timer.sleep(500)
    {:ok, state}
  end

  #
  # THEN
  #

  then_ ~r/^I should see a confirmation that the trip was created$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text()

    assert String.contains?(text, "Trip created successfully") or
             String.contains?(text, "Trip created") or
             String.contains?(text, "created successfully"),
           "Expected to see a success message about trip creation, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^I should see the trip listed in my future trips$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text()

    assert String.contains?(text, "Tallinn") or String.contains?(text, "Paris"),
           "Expected to see created trip in listing, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^I should be redirected to the login page$/, fn state, _ ->
    :timer.sleep(1000)
    current_url = current_url()

    assert String.contains?(current_url, "/users/login") or
             String.contains?(current_url, "/login"),
           "Expected to be redirected to login page, but got: #{current_url}"

    {:ok, state}
  end

  then_ ~r/^I should see an access denied message$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "admin") or
             String.contains?(text, "access") or
             String.contains?(text, "denied") or
             String.contains?(text, "unauthorized"),
           "Expected to see access denied message, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^I should see an error about invalid transport mode$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "transport") or String.contains?(text, "invalid"),
           "Expected to see error about invalid transport mode, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^I should see an error about invalid price$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "price") and
             (String.contains?(text, "greater") or String.contains?(text, "positive")),
           "Expected to see error about invalid price, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^I should see an error about invalid available tickets$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "ticket") and String.contains?(text, "greater"),
           "Expected to see error about invalid tickets, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^I should see an error about invalid arrival time$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "arrival") and String.contains?(text, "after"),
           "Expected to see error about arrival time, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^I should see an error about missing picture URL$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "picture") or
             (String.contains?(text, "url") and String.contains?(text, "blank")),
           "Expected to see error about missing picture URL, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^I should see an error about missing source city$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "source") and String.contains?(text, "blank"),
           "Expected to see error about missing source city, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^I should see an error about missing destination city$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "destination") and String.contains?(text, "blank"),
           "Expected to see error about missing destination city, got: #{inspect(text)}"

    {:ok, state}
  end

  # Helper functions
  defp parse_table_data(table) when is_list(table) do
    # WhiteBread converts tables to list of maps where:
    # First row becomes keys, subsequent rows become values
    # Example: %{transport_mode: "source_city", plane: "Tallinn"}
    # We need to extract the SECOND value (column 2) as the actual value
    table
    |> Enum.map(fn row_map ->
      # Get all values from the map
      values = Map.values(row_map)
      # First value is the field name (from column 1)
      # Second value is the actual value (from column 2)
      if length(values) >= 2 do
        {Enum.at(values, 0), Enum.at(values, 1)}
      else
        # Fallback: if only one value, use it as both key and value
        val = hd(values)
        {val, val}
      end
    end)
    |> Enum.into(%{})
  end

  defp format_datetime_for_input(iso_datetime) do
    iso_datetime
    |> String.replace(~r/:00Z$/, "")
    |> String.replace(~r/Z$/, "")
  end
end
