defmodule ViewTripDetailsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Accounts, Trips, Repo}

  scenario_starting_state fn _state ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, _state ->
    Hound.end_session()
    :ok
  end

  # ========================================
  # GIVEN
  # ========================================

  given_ ~r/^an admin user exists and is logged in$/, fn _state ->
    unique_id = "#{:erlang.unique_integer([:positive])}_#{System.system_time(:microsecond)}"
    email = "admin_view_#{unique_id}@example.com"

    admin = case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.register_user(%{
          "username" => "admin_view_#{unique_id}",
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "name" => "Admin",
          "last_name" => "View",
          "email" => email,
          "birthdate" => "1990-01-01",
          "nationality" => "EE",
          "residence_address" => "Admin St",
          "phone_number" => "+3726777777"
        })
        Repo.update!(Ecto.Changeset.change(user, role: "admin"))
      user ->
        user
    end

    # Login
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)

    {:ok, %{admin: admin}}
  end

  given_ ~r/^a future trip exists owned by the admin$/, fn state ->
    admin = state.admin
    tomorrow = Date.add(Date.utc_today(), 1)

    {:ok, trip} = Trips.create_trip(admin, %{
      "source_city" => "Tallinn",
      "destination_city" => "Tartu",
      "departure_time" => DateTime.new!(tomorrow, ~T[10:00:00]),
      "arrival_time" => DateTime.new!(tomorrow, ~T[12:00:00]),
      "price" => "25.00",
      "available_tickets" => 50,
      "co2_level" => 100,
      "transport_mode" => "bus",
      "picture_url" => "https://pics.example.com/view-future.jpg",
      "dates" => Date.to_iso8601(tomorrow)
    })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^a past trip exists owned by the admin$/, fn state ->
    admin = state.admin
    yesterday = Date.add(Date.utc_today(), -1)

    {:ok, trip} = Trips.create_trip(admin, %{
      "source_city" => "Tallinn",
      "destination_city" => "Parnu",
      "departure_time" => DateTime.new!(yesterday, ~T[10:00:00]),
      "arrival_time" => DateTime.new!(yesterday, ~T[12:00:00]),
      "price" => "20.00",
      "available_tickets" => 30,
      "co2_level" => 80,
      "transport_mode" => "train",
      "picture_url" => "https://pics.example.com/view-past.jpg",
      "dates" => Date.to_iso8601(yesterday)
    })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^a future trip exists owned by another admin$/, fn state ->
    # Create another admin with unique ID
    unique = "#{:erlang.unique_integer([:positive])}_#{System.system_time(:microsecond)}"
    {:ok, other_admin} = Accounts.register_user(%{
      "username" => "other_admin_#{unique}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Other",
      "last_name" => "Admin",
      "email" => "other_admin_view_#{unique}@example.com",
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "Other St",
      "phone_number" => "+3726888888"
    })
    other_admin = Repo.update!(Ecto.Changeset.change(other_admin, role: "admin"))

    tomorrow = Date.add(Date.utc_today(), 1)
    {:ok, trip} = Trips.create_trip(other_admin, %{
      "source_city" => "Tallinn",
      "destination_city" => "Riga",
      "departure_time" => DateTime.new!(tomorrow, ~T[14:00:00]),
      "arrival_time" => DateTime.new!(tomorrow, ~T[16:00:00]),
      "price" => "30.00",
      "available_tickets" => 40,
      "co2_level" => 120,
      "transport_mode" => "plane",
      "picture_url" => "https://pics.example.com/view-other.jpg",
      "dates" => Date.to_iso8601(tomorrow)
    })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^a normal user is logged in$/, fn state ->
    # Logout current admin and login as normal user
    try do
      submit_element({:css, "form[action='/users/logout']"})
      :timer.sleep(1000)
    rescue
      _ -> :ok
    end

    unique_id = "#{:erlang.unique_integer([:positive])}_#{System.system_time(:microsecond)}"
    email = "normal_view_#{unique_id}@example.com"

    {:ok, user} = Accounts.register_user(%{
      "username" => "normal_view_#{unique_id}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Normal",
      "last_name" => "User",
      "email" => email,
      "birthdate" => "1995-01-01",
      "nationality" => "EE",
      "residence_address" => "Normal St",
      "phone_number" => "+3726999999"
    })

    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)

    {:ok, Map.put(state, :normal_user, user)}
  end

  given_ ~r/^I am logged out$/, fn state ->
    try do
      submit_element({:css, "form[action='/users/logout']"})
      :timer.sleep(1000)
    rescue
      _ -> :ok
    end
    {:ok, state}
  end

  # ========================================
  # WHEN
  # ========================================

  when_ ~r/^the admin visits the trip details page$/, fn state ->
    navigate_to("http://localhost:4002/admin/trips/#{state.trip.id}")
    :timer.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^the user visits the trip details page$/, fn state ->
    navigate_to("http://localhost:4002/admin/trips/#{state.trip.id}")
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^the admin tries to visit the trip details page$/, fn state ->
    navigate_to("http://localhost:4002/admin/trips/#{state.trip.id}")
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^the admin tries to view trip with ID 999999$/, fn state ->
    navigate_to("http://localhost:4002/admin/trips/999999")
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^an anonymous user tries to view a trip details page$/, fn state ->
    navigate_to("http://localhost:4002/admin/trips/1")
    :timer.sleep(2000)
    {:ok, state}
  end

  # ========================================
  # THEN - Literal string matchers first
  # ========================================

  then_ "the admin should see \"You are not authorized to view this trip.\"", fn state ->
    :timer.sleep(1000)
    page_text = visible_page_text()

    IO.puts("\n----- Looking for: You are not authorized to view this trip. -----")
    IO.puts(page_text)
    IO.puts("\n-----------------------------------------------\n")

    # Look for variations of the unauthorized message
    assert String.contains?(page_text, "not authorized") or
           String.contains?(page_text, "You are not authorized") or
           String.contains?(page_text, "unauthorized"),
      "Expected unauthorized message in page"

    {:ok, state}
  end

  then_ "the user should see \"You are not authorized\" or be redirected", fn state ->
    :timer.sleep(1000)
    page_text = visible_page_text()
    current = current_url()

    IO.puts("\n----- Checking user authorization -----")
    IO.puts("URL: #{current}")
    IO.puts("Page text snippet: #{String.slice(page_text, 0, 200)}")
    IO.puts("\n---------------------------------------\n")

    is_blocked = String.contains?(page_text, "not authorized") or
                String.contains?(page_text, "You are not authorized") or
                String.contains?(page_text, "unauthorized") or
                not String.contains?(current, "/admin/") or
                String.contains?(current, "/login")

    assert is_blocked, "User should be blocked from viewing admin trip"
    {:ok, state}
  end

  then_ "the admin should see \"Trip not found.\"", fn state ->
    :timer.sleep(1000)
    page_text = visible_page_text()

    IO.puts("\n----- Looking for: Trip not found. -----")
    IO.puts(page_text)
    IO.puts("\n-----------------------------------------------\n")

    assert String.contains?(page_text, "Trip not found") or
           String.contains?(page_text, "not found") or
           String.contains?(page_text, "does not exist"),
      "Expected 'Trip not found' message in page"

    {:ok, state}
  end

  # ========================================
  # THEN - Generic matchers
  # ========================================

  then_ ~r/^the admin should see all trip attributes displayed$/, fn state ->
    page_text = visible_page_text()
    trip = state.trip

    # Check for key trip attributes
    assert String.contains?(page_text, trip.source_city),
      "Should display source city"
    assert String.contains?(page_text, trip.destination_city),
      "Should display destination city"
    assert String.contains?(page_text, trip.transport_mode) or
           String.contains?(page_text, String.capitalize(trip.transport_mode)),
      "Should display transport mode"

    {:ok, state}
  end

  then_ ~r/^the admin should see the Edit button$/, fn state ->
    page_source = page_source()
    assert String.contains?(page_source, "Edit") or
           String.contains?(page_source, "edit"),
      "Should display Edit button"
    {:ok, state}
  end

  then_ ~r/^the admin should see the Delete button$/, fn state ->
    page_source = page_source()
    assert String.contains?(page_source, "Delete") or
           String.contains?(page_source, "delete"),
      "Should display Delete button"
    {:ok, state}
  end

  then_ ~r/^the admin should NOT see the Edit button$/, fn state ->
    page_source = page_source()
    # For past trips, edit button should not be present
    refute String.contains?(page_source, "Edit Trip") or
           String.contains?(page_source, "/edit"),
      "Should NOT display Edit button for past trips"
    {:ok, state}
  end

  then_ ~r/^the admin should NOT see the Delete button$/, fn state ->
    page_source = page_source()
    # For past trips, delete button should not be present
    refute String.contains?(page_source, "Delete Trip"),
      "Should NOT display Delete button for past trips"
    {:ok, state}
  end

  then_ ~r/^the admin should see read-only booking statistics$/, fn state ->
    page_text = visible_page_text()
    # Past trips should show booking stats
    assert String.contains?(page_text, "ticket") or
           String.contains?(page_text, "Ticket") or
           String.contains?(page_text, "booking") or
           String.contains?(page_text, "Booking"),
      "Should display booking statistics"
    {:ok, state}
  end

  then_ ~r/^they should be redirected to the login page$/, fn state ->
    :timer.sleep(1000)
    current = current_url()
    page_text = visible_page_text()

    is_login = String.contains?(current, "/login") or
               String.contains?(page_text, "Log in")

    assert is_login, "Should redirect to login"
    {:ok, state}
  end

  # Fallback regex patterns
  then_ ~r/^the admin should see "(.+)"$/, fn state, %{matches: [message]} ->
    :timer.sleep(1000)
    page_text = visible_page_text()

    IO.puts("\n----- Looking for (admin regex): #{message} -----")
    IO.puts(page_text)
    IO.puts("\n-----------------------------------------------\n")

    assert String.contains?(page_text, message) or
          String.contains?(String.downcase(page_text), String.downcase(message)),
      "Expected: #{message}"
    {:ok, state}
  end

  then_ ~r/^the user should see "([^"]+)"$/, fn state, %{matches: [message]} ->
    page_text = visible_page_text()
    current = current_url()

    IO.puts("\n----- Looking for (user regex): #{message} -----")
    IO.puts("URL: #{current}")
    IO.puts(page_text)
    IO.puts("\n-----------------------------------------------\n")

    # User should see unauthorized message or be redirected
    assert String.contains?(page_text, "not authorized") or
           String.contains?(page_text, message) or
           not String.contains?(current, "/admin/trips/#{state.trip.id}"),
      "Expected unauthorized access message"
    {:ok, state}
  end

  then_ ~r/^the user should see "([^"]+)" or be redirected$/, fn state, %{matches: [message]} ->
    :timer.sleep(1000)
    page_text = visible_page_text()
    current = current_url()

    is_blocked = String.contains?(page_text, message) or
                String.contains?(page_text, "not authorized") or
                not String.contains?(current, "/admin/") or
                String.contains?(current, "/login")

    assert is_blocked, "User should be blocked"
    {:ok, state}
  end

end
