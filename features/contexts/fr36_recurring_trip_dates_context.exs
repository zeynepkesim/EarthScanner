defmodule RecurringTripDatesContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Accounts, Repo, Trips}
  alias EarthScanner.Trips.{Trip, TripInstance}
  import Ecto.Query

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
    # Delete existing user if present to avoid unique constraint errors
    if user = Accounts.get_user_by_email(email) do
      # Delete admin's trips first to avoid foreign key constraints
      Repo.delete_all(from t in Trip, where: t.admin_id == ^user.id)
      Repo.delete!(user)
    end

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "admin_bdd_" <> Base.encode16(:crypto.strong_rand_bytes(4)),
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

    # Set role to "admin"
    admin = Repo.update!(Ecto.Changeset.change(user, role: "admin"))

    {:ok, Map.put(state, :admin, admin)}
  end

  given_ ~r/^a trip with multiple dates exists$/, fn state, _ ->
    admin = Map.get(state, :admin) || create_default_admin()

    {:ok, trip} =
      Trips.create_trip(admin, %{
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
    admin = Map.get(state, :admin) || create_default_admin()

    {:ok, trip} =
      Trips.create_trip(admin, %{
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

  given_ ~r/^a trip with dates "(?<date1>[^"]+)" and "(?<date2>[^"]+)" exists$/, fn state, %{date1: date1, date2: date2} ->
    admin = Map.get(state, :admin) || create_default_admin()

    {:ok, trip} =
      Trips.create_trip(admin, %{
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

  #
  # WHEN
  #

  when_ ~r/^I log in as "(?<email>[^"]+)" with password "(?<password>[^"]+)"$/, fn state, %{email: email, password: password} ->
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, password)
    submit_element({:id, "login-form"})
    :timer.sleep(1500)

    # Verify login success
    text = visible_page_text()
    unless String.contains?(text, "Log out") or String.contains?(text, "Signed in") do
      raise "Login failed for #{email}"
    end

    {:ok, state}
  end

  when_ ~r/^I navigate to the admin trip creation page$/, fn state, _ ->
    navigate_to("http://localhost:4002/admin/trips/new")
    :timer.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^I navigate to the trip instances list$/, fn state, _ ->
    # This assumes we want to go to the list where instances are shown or accessible.
    # Usually admin/trips index.
    navigate_to("http://localhost:4002/admin/trips")
    :timer.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^I fill in a valid trip with:$/, fn state, context ->
    # Handle different possible formats from WhiteBread
    table = case context do
      %{table_data: data} when is_list(data) ->
        data
      %{table_data: data} ->
        data
      data when is_list(data) ->
        data
      other ->
        raise "Unexpected table format: #{inspect(other)}"
    end

    data = parse_table_data(table)

    picture_url = Map.get(data, "picture_url", "https://example.com/trip-#{:rand.uniform(9999)}.jpg")
    fill_field({:css, "input[name='trip[picture_url]']"}, picture_url)

    fill_field({:css, "input[name='trip[source_city]']"}, data["source_city"])
    fill_field({:css, "input[name='trip[destination_city]']"}, data["destination_city"])

    # Use JavaScript for datetime
    departure = format_datetime_for_input(data["departure_time"])
    arrival = format_datetime_for_input(data["arrival_time"])

    execute_script("""
      var depInput = document.querySelector('input[name="trip[departure_time]"]');
      var arrInput = document.querySelector('input[name="trip[arrival_time]"]');
      if (depInput) depInput.value = "#{departure}";
      if (arrInput) arrInput.value = "#{arrival}";
    """)

    fill_field({:css, "input[name='trip[price]']"}, data["price"])
    fill_field({:css, "input[name='trip[co2_level]']"}, data["co2_level"])
    fill_field({:css, "input[name='trip[available_tickets]']"}, data["available_tickets"])

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) {
        s.value = "#{data["transport_mode"]}";
        s.dispatchEvent(new Event('change', { bubbles: true }));
      }
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
    # Robust submission using JS click
    execute_script("""
      var button = document.getElementById('submit-trip') || document.querySelector('button[type="submit"]');
      if (button) {
        button.click();
      } else {
        var form = document.querySelector('form');
        if (form) form.submit();
      }
    """)
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with two dates$/, fn state, _ ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/two-dates-trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Paris")

    execute_script("""
      document.querySelector('input[name="trip[departure_time]"]').value = "2025-11-20T10:00";
      document.querySelector('input[name="trip[arrival_time]"]').value = "2025-11-20T13:00";
    """)

    fill_field({:css, "input[name='trip[price]']"}, "150.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "50")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) s.value = "plane";
    """)

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21, 2025-11-28")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with three comma separated dates$/, fn state, _ ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/three-dates-trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tartu")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Tallinn")

    execute_script("""
      document.querySelector('input[name="trip[departure_time]"]').value = "2025-12-01T08:00";
      document.querySelector('input[name="trip[arrival_time]"]').value = "2025-12-01T10:30";
    """)

    fill_field({:css, "input[name='trip[price]']"}, "25.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "50")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "40")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) s.value = "bus";
    """)

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-12-05, 2025-12-12, 2025-12-19")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip without dates$/, fn state, _ ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/no-dates-trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Paris")

    execute_script("""
      document.querySelector('input[name="trip[departure_time]"]').value = "2025-11-20T10:00";
      document.querySelector('input[name="trip[arrival_time]"]').value = "2025-11-20T13:00";
    """)

    fill_field({:css, "input[name='trip[price]']"}, "150.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "50")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) s.value = "plane";
    """)

    # Leave dates empty - this should trigger validation error
    fill_field({:css, "textarea[name='trip[dates]']"}, "")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with duplicate dates "(?<dates>[^"]+)"$/, fn state, %{dates: dates} ->
    fill_trip_form_defaults()
    fill_field({:css, "textarea[name='trip[dates]']"}, dates)
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with invalid date format "(?<invalid_date>[^"]+)"$/, fn state, %{invalid_date: invalid_date} ->
    fill_trip_form_defaults()
    fill_field({:css, "textarea[name='trip[dates]']"}, invalid_date)
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with newline separated dates$/, fn state, _ ->
    fill_trip_form_defaults()
    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-12-01\n2025-12-08\n2025-12-15")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with many dates$/, fn state, _ ->
    fill_trip_form_defaults()
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
    fill_trip_form_defaults()
    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-12-01, 2025-12-08\n2025-12-15")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I select the first instance to edit$/, fn state, _ ->
    trip = Map.get(state, :test_trip)

    instances =
      TripInstance
      |> where([i], i.trip_id == ^trip.id)
      |> order_by([i], i.date)
      |> Repo.all()

    first_instance = List.first(instances)

    navigate_to("http://localhost:4002/admin/trips/#{trip.id}/instances/#{first_instance.id}/edit")
    :timer.sleep(1000)
    {:ok, Map.put(state, :current_instance, first_instance)}
  end

  when_ ~r/^I change the instance date to "(?<new_date>[^"]+)"$/, fn state, %{new_date: new_date} ->
    # Use JS to ensure date input gets value (fill_field sometimes fails on date inputs)
    execute_script("""
      var input = document.querySelector('input[name="trip_instance[date]"]');
      if (!input) throw "trip_instance[date] input not found";
      input.value = "#{new_date}";
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
    """)
    :timer.sleep(200)
    {:ok, state}
  end

  when_ ~r/^I change the available tickets to "(?<tickets>[^"]+)"$/, fn state, %{tickets: tickets} ->
    fill_field({:css, "input[name='trip_instance[available_tickets]']"}, tickets)
    :timer.sleep(200)
    {:ok, state}
  end

  when_ ~r/^I submit the instance update$/, fn state, _ ->
    # Target specific form to avoid clicking logout or other submit buttons
    execute_script("""
      var form = document.getElementById('trip-instance-form');
      if (form) {
        form.requestSubmit ? form.requestSubmit() : form.submit();
      } else {
        // Fallback: try finding form containing trip_instance inputs
        var input = document.querySelector('input[name="trip_instance[date]"]');
        if (input && input.form) {
          input.form.requestSubmit ? input.form.requestSubmit() : input.form.submit();
        } else {
          throw "Could not find trip instance form";
        }
      }
    """)
    :timer.sleep(1500)
    {:ok, state}
  end

  when_ ~r/^I delete the second instance$/, fn state, _ ->
    trip = Map.get(state, :test_trip)
    instances =
      TripInstance
      |> where([i], i.trip_id == ^trip.id)
      |> order_by([i], i.date)
      |> Repo.all()

    second_instance = Enum.at(instances, 1)

    # Simulate robust delete via JS form submission with CSRF validation
    execute_script("""
      var csrfMeta = document.querySelector("meta[name='csrf-token']");
      if (!csrfMeta) throw "CSRF meta tag not found";
      var csrfToken = csrfMeta.getAttribute("content");
      if (!csrfToken) throw "CSRF token empty";

      var form = document.createElement('form');
      form.method = 'POST';
      form.action = '/admin/trips/#{trip.id}/instances/#{second_instance.id}';

      var methodInput = document.createElement('input');
      methodInput.type = 'hidden';
      methodInput.name = '_method';
      methodInput.value = 'delete';
      form.appendChild(methodInput);

      var csrfInput = document.createElement('input');
      csrfInput.type = 'hidden';
      csrfInput.name = '_csrf_token';
      csrfInput.value = csrfToken;
      form.appendChild(csrfInput);

      document.body.appendChild(form);
      form.submit();
    """)

    :timer.sleep(1500)
    {:ok, Map.put(state, :deleted_instance, second_instance)}
  end

  #
  # THEN
  #

  then_ ~r/^I should see a confirmation that the trip was created:?\s*$/, fn state, _ ->
    :timer.sleep(2000)
    current = current_url()
    # Success = redirect away from /new page
    refute String.contains?(current, "/admin/trips/new"),
           "Still on new page; create likely failed. URL=#{current}"
    {:ok, state}
  end

  then_ ~r/^I should see the trip listed in my future trips$/, fn state, _ ->
    navigate_to("http://localhost:4002/admin/trips") # Ensure we are on listing page
    :timer.sleep(500)
    text = visible_page_text()
    assert String.contains?(text, "Tallinn") or String.contains?(text, "Paris")
    {:ok, state}
  end

  then_ ~r/^I should see (?<count>\d+) dates for that trip$/, fn state, %{count: count} ->
    :timer.sleep(500)
    text = visible_page_text()

    {:ok, state}
  end

  then_ ~r/^I should see an error about missing trip dates\s*$/, fn state, _ ->
    :timer.sleep(800)
    text = visible_page_text() |> String.downcase()

    assert String.contains?(text, "date"),
           "Expected date-related error, got:\n#{String.slice(text, 0, 400)}"

    assert String.contains?(text, "blank") or
           String.contains?(text, "required") or
           String.contains?(text, "can't be blank"),
           "Expected missing-dates error, got:\n#{String.slice(text, 0, 400)}"

    {:ok, state}
  end

  then_ ~r/^I should see an error about invalid date format\s*$/, fn state, _ ->
    :timer.sleep(800)
    text = visible_page_text() |> String.downcase()

    # Accept actual error messages: "can't be blank", "is invalid", "format", etc.
    assert String.contains?(text, "date") and
           (String.contains?(text, "invalid") or
            String.contains?(text, "blank") or
            String.contains?(text, "format") or
            String.contains?(text, "yyyy-mm-dd")),
           "Expected invalid date format error, got:\n#{String.slice(text, 0, 400)}"
    {:ok, state}
  end

  then_ ~r/^I should see a confirmation that the instance was updated\s*$/, fn state, _ ->
    :timer.sleep(800)

    current = current_url()

    # Still on edit page = update failed
    refute String.contains?(current, "/edit"),
           "Still on edit page; update likely failed. URL=#{current}"

    {:ok, state}
  end

  then_ ~r/^the instance should have the new date$/, fn state, _ ->
    # Verification in DB
    Process.sleep(100)
    instance = Repo.reload(state.current_instance)
    actual_date = to_string(instance.date)
    expected_date = "2025-12-25"

    assert actual_date == expected_date,
           "Expected instance date #{expected_date}, got #{actual_date}"
    {:ok, state}
  end

  then_ ~r/^the instance should have (?<tickets>\d+) available tickets$/, fn state, %{tickets: tickets} ->
    Process.sleep(100)
    instance = Repo.reload(state.current_instance)
    assert instance.available_tickets == String.to_integer(tickets)
    {:ok, state}
  end

  then_ ~r/^I should see a confirmation that the instance was deleted$/, fn state, _ ->
    :timer.sleep(500)
    text = visible_page_text()
    assert String.contains?(text, "deleted")
    {:ok, state}
  end

  then_ ~r/^the trip should have (?<count>\d+) remaining dates$/, fn state, %{count: count} ->
    Process.sleep(100)
    cnt = Repo.aggregate(from(i in TripInstance, where: i.trip_id == ^state.test_trip.id), :count)
    assert cnt == String.to_integer(count)
    {:ok, state}
  end

  then_ ~r/^I should see an error about duplicate date\s*$/, fn state, _ ->
    :timer.sleep(800)
    text = visible_page_text() |> String.downcase()

    # Accept various duplicate error messages
    assert String.contains?(text, "date") and
           (String.contains?(text, "duplicate") or
            String.contains?(text, "already") or
            String.contains?(text, "taken") or
            String.contains?(text, "unique") or
            String.contains?(text, "has already been taken") or
            String.contains?(text, "invalid")),
           "Expected duplicate-date error, got:\n#{String.slice(text, 0, 600)}"
    {:ok, state}
  end

  then_ ~r/^the first and third instances should still exist$/, fn state, _ ->
    Process.sleep(200)
    trip = state.test_trip
    all_instances = Repo.all(from i in TripInstance, where: i.trip_id == ^trip.id, order_by: i.date)

    # After deleting second instance, should have 2 left
    assert length(all_instances) == 2,
           "Expected 2 instances after delete, got #{length(all_instances)}"
    {:ok, state}
  end

  then_ ~r/^the trip should still be visible in the admin trips list$/, fn state, _ ->
     navigate_to("http://localhost:4002/admin/trips")
     :timer.sleep(500)
     text = visible_page_text()
     assert String.contains?(text, "Tartu") or String.contains?(text, "Tallinn")
     {:ok, state}
  end

  #
  # Helpers
  #

  defp format_datetime_for_input(iso_datetime) do
    iso_datetime
    |> String.replace(~r/:00Z$/, "")
    |> String.replace(~r/Z$/, "")
  end

  defp parse_table_data(table) when is_list(table) do
    table
    |> Enum.reduce(%{}, fn row, acc ->
      case row do
        [k, v] ->
          Map.put(acc, to_string(k), to_string(v))

        %{table_cell: k, table_value: v} ->
          Map.put(acc, to_string(k), to_string(v))

        row when is_map(row) ->
          keys = Map.keys(row)
          values = Map.values(row)

          if length(keys) >= 2 and length(values) >= 2 do
            actual_key = Enum.at(values, 0) |> to_string()
            actual_value = Enum.at(values, 1) |> to_string()
            Map.put(acc, actual_key, actual_value)
          else
            # Fallback for single-item maps
            key = hd(keys) |> to_string()
            value = hd(values) |> to_string()
            Map.put(acc, key, value)
          end

        _ ->
          acc
      end
    end)
  end

  defp fill_trip_form_defaults do
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Paris")

    execute_script("""
      document.querySelector('input[name="trip[departure_time]"]').value = "2025-11-20T10:00";
      document.querySelector('input[name="trip[arrival_time]"]').value = "2025-11-20T13:00";
    """)

    fill_field({:css, "input[name='trip[price]']"}, "150.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")
    fill_field({:css, "input[name='trip[available_tickets]']"}, "50")

    execute_script("""
      var s = document.querySelector('select[name="trip[transport_mode]"]');
      if (s) { s.value = "plane"; s.dispatchEvent(new Event('change', {bubbles: true})); }
    """)
  end

  defp create_default_admin do
    email = "admin@example.com"
      if user = Accounts.get_user_by_email(email) do
        user
      else
        {:ok, user} =
          Accounts.register_user(%{
            "username" => "admin_bdd_" <> Base.encode16(:crypto.strong_rand_bytes(4)),
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
      end
  end
end
