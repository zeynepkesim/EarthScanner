defmodule AdminTripsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Accounts, Trips, Repo}

  scenario_starting_state fn state ->
    Hound.start_session()
    state
  end

  scenario_finalize fn _status, _state ->
    Hound.end_session()
    :ok
  end

  # Given steps

  given_ ~r/^I am logged in as an admin$/, fn state, _ ->
    # Try to get existing admin or create a new one
    admin = case Accounts.get_user_by_email("admin@example.com") do
      nil ->
        {:ok, user} = Accounts.register_user(%{
          "username" => "admin",
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "name" => "Admin",
          "last_name" => "User",
          "email" => "admin@example.com",
          "birthdate" => "1990-01-01",
          "nationality" => "ID",
          "residence_address" => "Admin Street",
          "phone_number" => "+628111111111"
        })
        # Update role to admin
        Repo.update!(Ecto.Changeset.change(user, role: "admin"))
      user ->
        user
    end

    # Seed past and future trips for this admin
    past_date = Date.utc_today() |> Date.add(-7)
    future_date = Date.utc_today() |> Date.add(7)

    # Create a past trip with its date instance
    {:ok, _past_trip} = Trips.create_trip(admin, %{
      "source_city" => "Jakarta",
      "destination_city" => "Bali",
      "departure_time" => DateTime.new!(past_date, ~T[10:00:00]),
      "arrival_time" => DateTime.new!(past_date, ~T[12:00:00]),
      "price" => "150.00",
      "available_tickets" => 50,
      "co2_level" => 200,
      "transport_mode" => "plane",
      "picture_url" => "https://pics.example.com/admin-past.jpg",
      "dates" => Date.to_iso8601(past_date)
    })

    # Create a future trip with its date instance
    {:ok, _future_trip} = Trips.create_trip(admin, %{
      "source_city" => "Tallinn",
      "destination_city" => "Paris",
      "departure_time" => DateTime.new!(future_date, ~T[14:00:00]),
      "arrival_time" => DateTime.new!(future_date, ~T[16:00:00]),
      "price" => "200.00",
      "available_tickets" => 100,
      "co2_level" => 300,
      "transport_mode" => "plane",
      "picture_url" => "https://pics.example.com/admin-future.jpg",
      "dates" => Date.to_iso8601(future_date)
    })

    # Login
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, "admin@example.com")
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    :timer.sleep(500)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)

    {:ok, Map.put(state, :admin, admin)}
  end

  given_ ~r/^I am logged in as a normal user$/, fn state, _ ->
    # Use unique email for each test run
    unique_id = :erlang.unique_integer([:positive])
    email = "bdd_user_#{unique_id}@example.com"
    username = "bdd_user_#{unique_id}"

    {:ok, user} = Accounts.register_user(%{
      "username" => username,
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "John",
      "last_name" => "Doe",
      "email" => email,
      "birthdate" => "1998-01-01",
      "nationality" => "ID",
      "residence_address" => "BDD Street",
      "phone_number" => "+628999999999"
    })

    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    :timer.sleep(500)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)

    {:ok, Map.put(state, :user, user)}
  end

  # When steps

  when_ ~r/^I visit the past trips page$/, fn state, _ ->
    :timer.sleep(500)
    navigate_to("http://localhost:4002/admin/past-trips")
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I visit the future trips page$/, fn state, _ ->
    :timer.sleep(500)
    navigate_to("http://localhost:4002/admin/future-trips")
    :timer.sleep(2000)
    {:ok, state}
  end

  # Then steps

  then_ ~r/^I should see the past trips heading$/, fn state, _ ->
    :timer.sleep(500)
    page_text = page_source()

    assert page_text =~ "Past Trips" or page_text =~ "past trips" or page_text =~ "Past Excursions",
      "Expected to see 'Past Trips' heading on page"
    {:ok, state}
  end

  then_ ~r/^I should see the future trips heading$/, fn state, _ ->
    :timer.sleep(500)
    page_text = page_source()

    assert page_text =~ "Future Trips" or page_text =~ "future trips" or page_text =~ "Upcoming Trips",
      "Expected to see 'Future Trips' heading on page"
    {:ok, state}
  end

  then_ ~r/^I should see a past trip in the list$/, fn state, _ ->
    :timer.sleep(500)
    page_text = visible_page_text()

    # Check for the seeded past trip cities
    assert page_text =~ "Jakarta" or page_text =~ "Bali",
      "Expected to see past trip (Jakarta to Bali) on page"
    {:ok, state}
  end

  then_ ~r/^I should see a future trip in the list$/, fn state, _ ->
    :timer.sleep(500)
    page_text = visible_page_text()

    # Check for the seeded future trip cities
    assert page_text =~ "Tallinn" or page_text =~ "Paris",
      "Expected to see future trip (Tallinn to Paris) on page"
    {:ok, state}
  end

  then_ ~r/^I should see the login page$/, fn state, _extra ->
    # Check if redirected or access denied
    :timer.sleep(1000)
    page_text = visible_page_text()
    current = current_url()

    assert (String.contains?(page_text, "Log in") or
            String.contains?(page_text, "Sign in") or
            String.contains?(current, "/users/log_in") or
            String.contains?(current, "/users/login") or
            (String.contains?(current, "localhost:4002/") and not String.contains?(current, "/admin/"))),
      "Expected to be redirected away from admin page, but got URL: #{current}"
    {:ok, state}
  end
end
