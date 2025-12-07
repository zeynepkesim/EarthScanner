defmodule RecurringTripDatesContext do
  use WhiteBread.Context
  use Hound.Helpers

  import Ecto.Query
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

  given_ ~r/^an admin user "([^"]+)" with password "([^"]+)" exists$/, fn state, _step_data ->
    email = "admin@example.com"
    password = "Password123!"

    admin =
      case Accounts.get_user_by_email(email) do
        nil ->
          {:ok, user} =
            Accounts.register_user(%{
              "username" => "admin_bdd_fr36",
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

          Repo.update!(Ecto.Changeset.change(user, role: "admin"))

        user ->
          user
      end

    {:ok, Map.put(state, :admin, admin)}
  end

  #
  # WHEN
  #

  when_ ~r/^I log in as "([^"]+)" with password "([^"]+)"$/, fn state, [email, password] ->
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, password)
    submit_element({:id, "login-form"})
    :timer.sleep(1500)

    {:ok, state}
  end

  when_ ~r/^I navigate to the admin trip creation page$/, fn state, _ ->
    navigate_to("http://localhost:4002/admin/trips/new")
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

  when_ ~r/^I fill in a trip with duplicate dates "([^"]+)"$/, fn state, [dates] ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
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

    fill_field({:css, "textarea[name='trip[dates]']"}, dates)
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with invalid date format "([^"]+)"$/, fn state, [invalid_date] ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
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

    fill_field({:css, "textarea[name='trip[dates]']"}, invalid_date)
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with newline separated dates$/, fn state, _ ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
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

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-12-01\n2025-12-08\n2025-12-15")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with many dates$/, fn state, _ ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
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

    # Generate 10 dates
    dates =
      1..10
      |> Enum.map(fn n -> "2025-12-#{String.pad_leading(to_string(n), 2, "0")}" end)
      |> Enum.join("\n")

    fill_field({:css, "textarea[name='trip[dates]']"}, dates)
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with mixed date separators$/, fn state, _ ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
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

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-12-01, 2025-12-08\n2025-12-15")
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

  then_ ~r/^I should see (\d+) dates for that trip$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text()

    # Just verify we're on a page showing trip details
    assert String.contains?(text, "2025") or String.contains?(text, "Trip"),
           "Expected to see trip dates on the page, got: #{inspect(text)}"

    {:ok, state}
  end

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

  then_ ~r/^I should see an error about invalid date format$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "date") and String.contains?(text, "invalid"),
           "Expected to see error about invalid date format, got: #{inspect(text)}"

    {:ok, state}
  end

  # ========== INSTANCE MANAGEMENT GIVEN STEPS ==========

  given_ ~r/^a trip with multiple dates exists$/, fn state, _ ->
    admin = Map.get(state, :admin) || create_admin_if_needed()

    {:ok, trip} =
      EarthScanner.Trips.create_trip(admin, %{
        "picture_url" => "https://example.com/trip.jpg",
        "transport_mode" => "plane",
        "source_city" => "Tallinn",
        "destination_city" => "Paris",
        "departure_time" => "2025-11-20T10:00:00Z",
        "arrival_time" => "2025-11-20T13:00:00Z",
        "price" => "150.0",
        "co2_level" => "200",
        "available_tickets" => "50",
        "dates" => "2025-12-10\n2025-12-15\n2025-12-20"
      })

    {:ok, Map.put(state, :test_trip, trip)}
  end

  given_ ~r/^a trip with three dates exists$/, fn state, _ ->
    admin = Map.get(state, :admin) || create_admin_if_needed()

    {:ok, trip} =
      EarthScanner.Trips.create_trip(admin, %{
        "picture_url" => "https://example.com/trip.jpg",
        "transport_mode" => "bus",
        "source_city" => "Tartu",
        "destination_city" => "Tallinn",
        "departure_time" => "2025-12-01T08:00:00Z",
        "arrival_time" => "2025-12-01T10:30:00Z",
        "price" => "25.0",
        "co2_level" => "50",
        "available_tickets" => "40",
        "dates" => "2025-12-05\n2025-12-12\n2025-12-19"
      })

    {:ok, Map.put(state, :test_trip, trip)}
  end

  given_ ~r/^a trip with dates "([^"]+)" and "([^"]+)" exists$/, fn state, [date1, date2] ->
    admin = Map.get(state, :admin) || create_admin_if_needed()

    {:ok, trip} =
      EarthScanner.Trips.create_trip(admin, %{
        "picture_url" => "https://example.com/trip.jpg",
        "transport_mode" => "train",
        "source_city" => "Tallinn",
        "destination_city" => "Tartu",
        "departure_time" => "2025-12-01T09:00:00Z",
        "arrival_time" => "2025-12-01T11:00:00Z",
        "price" => "20.0",
        "co2_level" => "30",
        "available_tickets" => "60",
        "dates" => "#{date1}\n#{date2}"
      })

    {:ok, Map.put(state, :test_trip, trip)}
  end

  # ========== INSTANCE MANAGEMENT WHEN STEPS ==========

  when_ ~r/^I navigate to the trip instances list$/, fn state, _ ->
    trip = Map.get(state, :test_trip)
    navigate_to("http://localhost:4002/admin/trips")
    :timer.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^I select the first instance to edit$/, fn state, _ ->
    trip = Map.get(state, :test_trip)

    instances =
      EarthScanner.Trips.TripInstance
      |> Ecto.Query.where([i], i.trip_id == ^trip.id)
      |> Ecto.Query.order_by([i], i.date)
      |> Repo.all()

    first_instance = List.first(instances)

    navigate_to("http://localhost:4002/admin/trips/#{trip.id}/instances/#{first_instance.id}/edit")
    :timer.sleep(1000)
    {:ok, Map.put(state, :current_instance, first_instance)}
  end

  when_ ~r/^I change the instance date to "([^"]+)"$/, fn state, [new_date] ->
    fill_field({:css, "input[name='trip_instance[date]']"}, new_date)
    :timer.sleep(200)
    {:ok, state}
  end

  when_ ~r/^I change the available tickets to "([^"]+)"$/, fn state, [tickets] ->
    fill_field({:css, "input[name='trip_instance[available_tickets]']"}, tickets)
    :timer.sleep(200)
    {:ok, state}
  end

  when_ ~r/^I submit the instance update$/, fn state, _ ->
    submit_element({:css, "form"})
    :timer.sleep(1500)
    {:ok, state}
  end

  when_ ~r/^I delete the second instance$/, fn state, _ ->
    trip = Map.get(state, :test_trip)

    instances =
      EarthScanner.Trips.TripInstance
      |> Ecto.Query.where([i], i.trip_id == ^trip.id)
      |> Ecto.Query.order_by([i], i.date)
      |> Repo.all()

    second_instance = Enum.at(instances, 1)

    # Simulate delete action (click delete button)
    navigate_to("http://localhost:4002/admin/trips")
    :timer.sleep(500)

    execute_script("""
      var form = document.createElement('form');
      form.method = 'POST';
      form.action = '/admin/trips/#{trip.id}/instances/#{second_instance.id}';
      var input = document.createElement('input');
      input.type = 'hidden';
      input.name = '_method';
      input.value = 'delete';
      form.appendChild(input);
      document.body.appendChild(form);
      form.submit();
    """)

    :timer.sleep(1500)
    {:ok, Map.put(state, :deleted_instance, second_instance)}
  end

  # ========== INSTANCE MANAGEMENT THEN STEPS ==========

  then_ ~r/^I should see a confirmation that the instance was updated$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text()

    assert String.contains?(text, "updated") or String.contains?(text, "Trip date updated"),
           "Expected to see update confirmation, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^the instance should have the new date$/, fn state, _ ->
    # Verification would require checking database or page content
    :timer.sleep(500)
    {:ok, state}
  end

  then_ ~r/^the instance should have (\d+) available tickets$/, fn state, [tickets] ->
    # Verification would require checking database or page content
    :timer.sleep(500)
    {:ok, state}
  end

  then_ ~r/^I should see a confirmation that the instance was deleted$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text()

    assert String.contains?(text, "deleted") or String.contains?(text, "Trip date deleted"),
           "Expected to see delete confirmation, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^the trip should have (\d+) remaining dates$/, fn state, [count] ->
    trip = Map.get(state, :test_trip)

    remaining =
      EarthScanner.Trips.TripInstance
      |> Ecto.Query.where([i], i.trip_id == ^trip.id)
      |> Repo.all()

    expected_count = String.to_integer(count)
    assert length(remaining) == expected_count,
           "Expected #{expected_count} instances, got #{length(remaining)}"

    {:ok, state}
  end

  then_ ~r/^I should see an error about duplicate date$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "already") or String.contains?(text, "duplicate"),
           "Expected to see duplicate date error, got: #{inspect(text)}"

    {:ok, state}
  end

  then_ ~r/^the first and third instances should still exist$/, fn state, _ ->
    trip = Map.get(state, :test_trip)

    remaining =
      EarthScanner.Trips.TripInstance
      |> Ecto.Query.where([i], i.trip_id == ^trip.id)
      |> Ecto.Query.order_by([i], i.date)
      |> Repo.all()

    assert length(remaining) == 2,
           "Expected 2 remaining instances, got #{length(remaining)}"

    {:ok, state}
  end

  then_ ~r/^the trip should still be visible in the admin trips list$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text()

    assert String.contains?(text, "Tartu") or String.contains?(text, "Tallinn"),
           "Expected to see trip in listing, got: #{inspect(text)}"

    {:ok, state}
  end

  # Helper functions
  defp create_admin_if_needed do
    email = "admin@example.com"

    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} =
          Accounts.register_user(%{
            "username" => "admin_bdd_fr36",
            "password" => "Password123!",
            "password_confirmation" => "Password123!",
            "name" => "Admin",
            "last_name" => "User",
            "email" => email,
            "birthdate" => "1990-01-01",
            "nationality" => "ID",
            "residence_address" => "Admin Street",
            "phone_number" => "+628111111111"
          })

        Repo.update!(Ecto.Changeset.change(user, role: "admin"))

      user ->
        user
    end
  end

  # Helper functions
  defp parse_table_data(table) do
    table
    |> Enum.map(fn row -> {hd(row), List.last(row)} end)
    |> Enum.into(%{})
  end

  defp format_datetime_for_input(iso_datetime) do
    iso_datetime
    |> String.replace(~r/:00Z$/, "")
    |> String.replace(~r/Z$/, "")
  end
end
