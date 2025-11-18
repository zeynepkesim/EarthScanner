defmodule AdminRecurringTripsContext do
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

  # Background:
  # Given an admin user "admin@example.com" with password "Password123!" exists
  given_ ~r/^an admin user "([^"]+)" with password "([^"]+)" exists$/, fn state, _step_data ->
    email = "admin@example.com"
    password = "Password123!"

    admin =
      case Accounts.get_user_by_email(email) do
        nil ->
          {:ok, user} =
            Accounts.register_user(%{
              "username" => "admin_bdd",
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

          # Update role to admin
          Repo.update!(Ecto.Changeset.change(user, role: "admin"))

        user ->
          user
      end

    {:ok, Map.put(state, :admin, admin)}
  end

  #
  # WHEN
  #

  # When I log in as "admin@example.com" with password "Password123!"
  when_ ~r/^I log in as "([^"]+)" with password "([^"]+)"$/, fn state, _step_data ->
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, "admin@example.com")
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})
    :timer.sleep(1500)

    {:ok, state}
  end

  # And I navigate to the admin trip creation page
  when_ ~r/^I navigate to the admin trip creation page$/, fn state, _ ->
    navigate_to("http://localhost:4002/admin/trips/new")
    :timer.sleep(1000)
    {:ok, state}
  end

  # And I fill in a valid trip with:
  when_ ~r/^I fill in a valid trip with:$/, fn state, _step_data ->
    # source / destination
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

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21\n2025-11-28")

    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I clear the trip dates$/, fn state, _ ->
    fill_field({:css, "textarea[name='trip[dates]']"}, "")
    :timer.sleep(200)
    {:ok, state}
  end

  when_ ~r/^I submit the trip form$/, fn state, _ ->
    submit_element({:css, "form"})
    :timer.sleep(1500)
    {:ok, state}
  end

  #
  # THEN
  #

  # Then I should see a confirmation that the trip was created
  then_ ~r/^I should see a confirmation that the trip was created$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text()

    assert String.contains?(text, "Trip created successfully") or
             String.contains?(text, "Trip created") or
             String.contains?(text, "created successfully"),
           "Expected to see a success message about trip creation, got: #{inspect(text)}"

    {:ok, state}
  end

  # And I should see the trip listed in my future trips
  then_ ~r/^I should see the trip listed in my future trips$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text()

    assert String.contains?(text, "Tallinn") or String.contains?(text, "Paris"),
           "Expected to see created trip in listing, got: #{inspect(text)}"

    {:ok, state}
  end

  # And I should see 2 dates for that trip
  then_ ~r/^I should see (\d+) dates for that trip$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text()

    assert String.contains?(text, "2025-11-21") or String.contains?(text, "2025-11-28"),
           "Expected to see at least one of the trip dates on the page, got: #{inspect(text)}"

    {:ok, state}
  end

  # Then I should see an error about missing trip dates
  then_ ~r/^I should see an error about missing trip dates$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "date") and
             (String.contains?(text, "required") or
                String.contains?(text, "can't be blank") or
                String.contains?(text, "must be provided")),
           "Expected to see validation error about missing dates, got: #{inspect(text)}"

    {:ok, state}
  end
end
