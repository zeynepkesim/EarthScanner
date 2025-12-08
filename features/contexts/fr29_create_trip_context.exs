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

  when_ "I fill in a valid plane trip", fn state ->
    fill_trip_form(%{
      "picture_url" => "https://example.com/plane.jpg",
      "transport_mode" => "plane",
      "source_city" => "Tallinn",
      "destination_city" => "Paris",
      "departure_time" => "2025-11-20T10:00",
      "arrival_time" => "2025-11-20T13:00",
      "price" => "150.0",
      "co2_level" => "200",
      "available_tickets" => "50",
      "dates" => "2025-11-21"
    })
    {:ok, state}
  end

  when_ "I fill in a valid bus trip", fn state ->
    fill_trip_form(%{
      "picture_url" => "https://example.com/bus.jpg",
      "transport_mode" => "bus",
      "source_city" => "Tartu",
      "destination_city" => "Tallinn",
      "departure_time" => "2025-12-01T08:00",
      "arrival_time" => "2025-12-01T10:30",
      "price" => "25.0",
      "co2_level" => "50",
      "available_tickets" => "40",
      "dates" => "2025-12-05"
    })
    {:ok, state}
  end

  when_ "I fill in a valid train trip", fn state ->
    fill_trip_form(%{
      "picture_url" => "https://example.com/train.jpg",
      "transport_mode" => "train",
      "source_city" => "Berlin",
      "destination_city" => "Munich",
      "departure_time" => "2025-12-10T14:00",
      "arrival_time" => "2025-12-10T18:00",
      "price" => "80.0",
      "co2_level" => "30",
      "available_tickets" => "100",
      "dates" => "2025-12-15"
    })
    {:ok, state}
  end

  when_ "I fill in a trip with minimum values", fn state ->
    fill_trip_form(%{
      "picture_url" => "https://example.com/min.jpg",
      "transport_mode" => "bus",
      "source_city" => "A",
      "destination_city" => "B",
      "departure_time" => "2025-12-20T10:00",
      "arrival_time" => "2025-12-20T10:01",
      "price" => "0.01",
      "co2_level" => "0",
      "available_tickets" => "1",
      "dates" => "2025-12-25"
    })
    {:ok, state}
  end

  when_ "I fill in a trip with long duration", fn state ->
    fill_trip_form(%{
      "picture_url" => "https://example.com/long.jpg",
      "transport_mode" => "plane",
      "source_city" => "New York",
      "destination_city" => "Sydney",
      "departure_time" => "2025-12-01T10:00",
      "arrival_time" => "2025-12-03T10:00",
      "price" => "1500.0",
      "co2_level" => "500",
      "available_tickets" => "200",
      "dates" => "2025-12-10"
    })
    {:ok, state}
  end

  when_ "I fill in a trip with special city names", fn state ->
    fill_trip_form(%{
      "picture_url" => "https://example.com/special.jpg",
      "transport_mode" => "plane",
      "source_city" => "São Paulo",
      "destination_city" => "Zürich",
      "departure_time" => "2025-12-05T09:00",
      "arrival_time" => "2025-12-05T21:00",
      "price" => "800.0",
      "co2_level" => "300",
      "available_tickets" => "150",
      "dates" => "2025-12-10"
    })
    {:ok, state}
  end

  when_ "I fill in a trip with large values", fn state ->
    fill_trip_form(%{
      "picture_url" => "https://example.com/large.jpg",
      "transport_mode" => "plane",
      "source_city" => "London",
      "destination_city" => "Tokyo",
      "departure_time" => "2025-12-15T06:00",
      "arrival_time" => "2025-12-15T18:00",
      "price" => "9999.99",
      "co2_level" => "99999",
      "available_tickets" => "5000",
      "dates" => "2025-12-20"
    })
    {:ok, state}
  end


  when_ ~r/^I fill in a valid trip with:$/, fn state, %{table_data: table} ->
    data = parse_table_data(table)

    picture_url = Map.get(data, "picture_url", "https://example.com/trip-#{:rand.uniform(9999)}.jpg")
    fill_field({:css, "input[name='trip[picture_url]']"}, picture_url)

    fill_field({:css, "input[name='trip[source_city]']"}, data["source_city"])
    fill_field({:css, "input[name='trip[destination_city]']"}, data["destination_city"])

    # Format datetime properly for HTML datetime-local input
    departure = format_datetime_for_input(data["departure_time"])
    arrival = format_datetime_for_input(data["arrival_time"])

    # Use JavaScript for datetime - Hound's fill_field corrupts format
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

  when_ "I submit the trip form", fn state ->
    :timer.sleep(500)

    # Debug: Check ALL form field values before submit
    debug_output = execute_script("""
      var form = document.getElementById('trip-form');
      if (!form) return 'FORM NOT FOUND';

      var fields = {
        picture: form.querySelector('input[name="trip[picture_url]"]')?.value || 'EMPTY',
        transport: form.querySelector('select[name="trip[transport_mode]"]')?.value || 'EMPTY',
        source: form.querySelector('input[name="trip[source_city]"]')?.value || 'EMPTY',
        dest: form.querySelector('input[name="trip[destination_city]"]')?.value || 'EMPTY',
        dep_time: form.querySelector('input[name="trip[departure_time]"]')?.value || 'EMPTY',
        arr_time: form.querySelector('input[name="trip[arrival_time]"]')?.value || 'EMPTY',
        price: form.querySelector('input[name="trip[price]"]')?.value || 'EMPTY',
        co2: form.querySelector('input[name="trip[co2_level]"]')?.value || 'EMPTY',
        tickets: form.querySelector('input[name="trip[available_tickets]"]')?.value || 'EMPTY',
        dates: form.querySelector('textarea[name="trip[dates]"]')?.value || 'EMPTY'
      };

      return JSON.stringify(fields);
    """)

    IO.puts("DEBUG ALL FORM FIELDS: #{debug_output}")

    # CRITICAL: Click the submit button instead of calling form.submit()
    # This triggers ALL event handlers and validation properly
    result = execute_script("""
      var button = document.getElementById('submit-trip');
      if (button) {
        button.click();
        return 'CLICKED';
      }
      return 'BUTTON NOT FOUND';
    """)

    IO.puts("DEBUG SUBMIT RESULT: #{result}")

    # Wait for page transition - check if URL changed or flash message appeared
    :timer.sleep(2000)  # Increased wait time for server processing

    # Check if validation errors appeared on the form
    validation_errors = execute_script("""
      var errors = document.querySelectorAll('.text-red-600, .text-red-700, .text-red-800, .bg-red-100, [class*="error"]');
      if (errors.length > 0) {
        return Array.from(errors).map(e => e.textContent.trim()).join('; ');
      }
      return 'NO_ERRORS';
    """)

    unless validation_errors == "NO_ERRORS" do
      IO.puts("DEBUG VALIDATION ERRORS: #{validation_errors}")
    end

    # Check if we're still on the same page or redirected
    current_url = execute_script("return window.location.href;")
    IO.puts("DEBUG CURRENT URL AFTER SUBMIT: #{current_url}")

    :timer.sleep(500)  # Additional brief wait
    {:ok, state}
  end

  when_ ~r/^I fill in a trip with invalid transport mode "(?<mode>[^"]+)"$/, fn state, %{mode: mode} ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    fill_field({:css, "input[name='trip[destination_city]']"}, "Paris")
    # Use JavaScript for datetime
    execute_script("""
      document.querySelector('input[name="trip[departure_time]"]').value = "2025-11-20T10:00";
      document.querySelector('input[name="trip[arrival_time]"]').value = "2025-11-20T13:00";
    """)
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
    execute_script("""
      document.querySelector('input[name="trip[departure_time]"]').value = "2025-11-20T10:00";
      document.querySelector('input[name="trip[arrival_time]"]').value = "2025-11-20T13:00";
    """)

    # CRITICAL: Bypass browser number input sanitization for negative values
    # Browser won't accept negative values in type="number" inputs
    execute_script("""
      var priceInput = document.querySelector('input[name="trip[price]"]');
      priceInput.setAttribute('type', 'text');
      priceInput.value = "#{price}";
      priceInput.setAttribute('type', 'number');
    """)

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
    execute_script("""
      document.querySelector('input[name="trip[departure_time]"]').value = "2025-11-20T10:00";
      document.querySelector('input[name="trip[arrival_time]"]').value = "2025-11-20T13:00";
    """)
    fill_field({:css, "input[name='trip[price]']"}, "150.0")
    fill_field({:css, "input[name='trip[co2_level]']"}, "200")

    # Bypass number input sanitization for zero value
    execute_script("""
      var ticketsInput = document.querySelector('input[name="trip[available_tickets]"]');
      ticketsInput.setAttribute('type', 'text');
      ticketsInput.value = "0";
      ticketsInput.setAttribute('type', 'number');
    """)

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
    execute_script("""
      document.querySelector('input[name="trip[departure_time]"]').value = "2025-11-20T13:00";
      document.querySelector('input[name="trip[arrival_time]"]').value = "2025-11-20T10:00";
    """)
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

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip without source city$/, fn state, _ ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
    # Use JavaScript to properly clear the field
    execute_script("""
      document.querySelector('input[name="trip[source_city]"]').value = "";
    """)
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

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21")
    :timer.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I fill in a trip without destination city$/, fn state, _ ->
    fill_field({:css, "input[name='trip[picture_url]']"}, "https://example.com/trip.jpg")
    fill_field({:css, "input[name='trip[source_city]']"}, "Tallinn")
    # Use JavaScript to properly clear the field
    execute_script("""
      document.querySelector('input[name="trip[destination_city]"]').value = "";
    """)
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

    fill_field({:css, "textarea[name='trip[dates]']"}, "2025-11-21")
    :timer.sleep(500)
    {:ok, state}
  end

  #
  # THEN
  #

  then_ ~r/^I should see a confirmation that the trip was created$/, fn state, _ ->
    :timer.sleep(500)  # Brief wait for redirect to complete

    # Check if redirected to admin trips page (success indicator)
    current_url = execute_script("return window.location.href;")

    assert String.contains?(current_url, "/admin/trips") or String.contains?(current_url, "/admin/my-trips"),
           "Expected to be redirected to admin trips after creation, got URL: #{inspect(current_url)}"

    # Optionally also check for flash message or trip creation confirmation
    # Flash messages can be ephemeral, so URL redirect is primary success indicator

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

    assert (String.contains?(text, "transport") and String.contains?(text, "invalid")) or
             String.contains?(text, "is invalid"),
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

@trip_fields ~w(
  transport_mode source_city destination_city departure_time arrival_time
  price co2_level available_tickets dates picture_url
)

defp parse_table_data(table) when is_list(table) do
  known_fields =
    MapSet.new([
      "picture_url",
      "transport_mode",
      "source_city",
      "destination_city",
      "departure_time",
      "arrival_time",
      "price",
      "co2_level",
      "available_tickets",
      "dates"
    ])

  first = hd(table)
  keys = Map.keys(first)

  {field_key, value_key} =
    case Enum.find(keys, fn k ->
           Map.get(first, k) |> to_string() |> then(&MapSet.member?(known_fields, &1))
         end) do
      nil ->
        [k1, k2] = Enum.sort_by(keys, &to_string/1)
        {k1, k2}

      fk ->
        vk = Enum.find(keys, &(&1 != fk))
        {fk, vk}
    end

  table
  |> Enum.map(fn row ->
    field = Map.get(row, field_key) |> to_string()
    value = Map.get(row, value_key) |> to_string()
    {field, value}
  end)
  |> Enum.into(%{})
  end

  defp format_datetime_for_input(iso_datetime) do
    # Convert "2025-11-20T10:00:00Z" to "2025-11-20T10:00" for datetime-local input
    iso_datetime
    |> String.replace(~r/:\d{2}Z$/, "")  # Remove :00Z or :30Z etc
    |> String.replace(~r/Z$/, "")        # Remove trailing Z if no seconds
  end

  # Helper to fill trip form with data map
  defp fill_trip_form(data) do
    fill_field({:css, "input[name='trip[picture_url]']"}, data["picture_url"])
    fill_field({:css, "input[name='trip[source_city]']"}, data["source_city"])
    fill_field({:css, "input[name='trip[destination_city]']"}, data["destination_city"])

    # CRITICAL: Use JavaScript for datetime fields - Hound's fill_field corrupts datetime-local format
    # Bug: "2025-11-20T10:00" becomes "51120-02-20T10:00" with fill_field
    execute_script("""
      var depInput = document.querySelector('input[name="trip[departure_time]"]');
      var arrInput = document.querySelector('input[name="trip[arrival_time]"]');
      if (depInput) depInput.value = "#{data["departure_time"]}";
      if (arrInput) arrInput.value = "#{data["arrival_time"]}";
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
  end
end
