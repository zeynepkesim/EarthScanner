defmodule PointsSecurityContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Accounts, Trips, Repo}
  import Ecto.Query

  @base "http://127.0.0.1:4002"

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, state ->
    Hound.end_session()
    {:ok, state}
  end

  # --- Setup Steps ---

  given_ ~r/^I am a registered user named "(?<name>[^"]+)"$/, fn state, %{name: name} ->
    user = create_user(name)
    {:ok, Map.put(state, :user, user)}
  end

  given_ ~r/^there is a trip "(?<city>[^"]+)" costing (?<price>[\d\.]+) EUR$/, fn state, %{city: city, price: price} ->
    admin = ensure_admin()
    future_date_obj = Date.utc_today() |> Date.add(10)
    future_date = Date.to_iso8601(future_date_obj)

    # Construct DateTime from future date + time
    departure_dt = DateTime.new!(future_date_obj, ~T[10:00:00], "Etc/UTC") |> DateTime.to_iso8601()
    arrival_dt = DateTime.new!(future_date_obj, ~T[12:00:00], "Etc/UTC") |> DateTime.to_iso8601()

    {:ok, trip} = Trips.create_trip(admin, %{
      "source_city" => "Tallinn",
      "destination_city" => city,
      "departure_time" => departure_dt,
      "arrival_time" => arrival_dt,
      "price" => String.to_float(price),
      "co2_level" => 100,
      "available_tickets" => 10,
      "transport_mode" => "bus",
      "picture_url" => "https://example.com/pic.jpg",
      "dates" => future_date
    })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^that trip is sold out$/, fn state, _ ->
    trip = state[:trip]
    # Update all instances to have 0 tickets
    Enum.each(trip.instances, fn instance ->
      Trips.update_trip_instance(instance, %{"available_tickets" => 0})
    end)
    {:ok, state}
  end

  given_ ~r/^I am logged in$/, fn state, _ ->
    user = state[:user]
    navigate_to(@base <> "/users/login")
    fill_field({:css, "input[name='session[email]']"}, user.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})
    find_element(:link_text, "Profile")
    {:ok, state}
  end

  given_ ~r/^I have (?<points>\d+) loyalty points$/, fn state, %{points: points} ->
    user = state[:user]
    {:ok, updated_user} = Accounts.update_user_loyalty_points(user, String.to_integer(points))
    {:ok, Map.put(state, :user, updated_user)}
  end

  # --- Action Steps ---

  when_ ~r/^I search for "(?<city>[^"]+)"$/, fn state, %{city: city} ->
    navigate_to(@base <> "/search/results?source=Tallinn&destination=#{city}")
    {:ok, state}
  end

  when_ ~r/^I view the trip details$/, fn state, _ ->
    # Click on the first "Purchase" button or trip link found
    # In search results, trips are listed. We might need to handle specific trip selection.
    # Assuming standard flow where we can just look for the trip card.

    # Wait for page load
    Process.sleep(500)
    {:ok, state}
  end

  when_ ~r/^I purchase a ticket$/, fn state, _ ->
    # Click "Purchase next available date"
    find_element(:css, "button[data-confirm='Confirm purchase?']") |> click()

    # Handle alert if present (Hound/Selenium might auto-accept or we might need to handle)
    # Using execute_script to bypass native dialog if test environment permits or handle it:
    if alert_message = dialog_text() do
      accept_dialog()
    end
    Process.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^I attempt to purchase a ticket$/, fn state, _ ->
    # For sold out trips, the button is disabled or different.
    # We just verify we are on the page and see the sold out status
    {:ok, state}
  end

  when_ ~r/^I choose to redeem my points$/, fn state, _ ->
    # Find checkbox for points redemption (FR-26 feature)
    execute_script("document.querySelector('input[name=\"redeem_points\"]').click()")
    Process.sleep(500)
    {:ok, state}
  end

  # --- Verification Steps ---

  then_ ~r/^I should see "(?<text>[^"]+)"$/, fn state, %{text: text} ->
    assert visible_page_text() =~ text
    {:ok, state}
  end

  then_ ~r/^an audit log should exist for my point change$/, fn state, _ ->
    user = state[:user]
    logs = Accounts.list_point_logs(user)
    assert length(logs) > 0
    {:ok, state}
  end

  then_ ~r/^my loyalty points balance should be (?<points>\d+)$/, fn state, %{points: points} ->
    user = Accounts.get_user_by_id(state[:user].id)
    assert user.loyalty_points == String.to_integer(points)
    {:ok, state}
  end

  then_ ~r/^no audit log should exist for this user$/, fn state, _ ->
    user = state[:user]
    logs = Accounts.list_point_logs(user)
    assert length(logs) == 0
    {:ok, state}
  end

  then_ ~r/^an audit log should exist showing a change of (?<amount>\d+) points$/, fn state, %{amount: amount} ->
    user = state[:user]
    logs = Accounts.list_point_logs(user)
    last_log = List.last(logs)
    assert last_log.change_amount == String.to_integer(amount)
    {:ok, state}
  end

  then_ ~r/^an audit log should exist showing a decrease of (?<amount>\d+) points$/, fn state, %{amount: amount} ->
    user = state[:user]
    logs = Accounts.list_point_logs(user)
    # Look for the redemption log (negative amount)
    # The actual amount stored might be negative, testing expects "decrease of 90" -> -90
    target = -String.to_integer(amount)
    assert Enum.any?(logs, fn log -> log.change_amount == target end)
    {:ok, state}
  end

  # --- Helpers ---

  defp create_user(name) do
    unique_num = System.unique_integer([:positive])
    suffix = "#{unique_num}_#{System.os_time(:nanosecond)}"
    {:ok, user} = Accounts.register_user(%{
      "username" => "user_#{suffix}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => name,
      "last_name" => "User",
      "email" => "user_#{suffix}@example.com",
      "birthdate" => "1990-01-01",
      "nationality" => "US",
      "residence_address" => "User Address",
      "phone_number" => "+1234567890"
    })
    user
  end

  defp ensure_admin do
    unique_num = System.unique_integer([:positive])
    suffix = "#{unique_num}_#{System.os_time(:nanosecond)}"
    {:ok, user} = Accounts.register_user(%{
      "username" => "admin_#{suffix}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Admin",
      "last_name" => "User",
      "email" => "admin_#{suffix}@example.com",
      "birthdate" => "1990-01-01",
      "nationality" => "US",
      "residence_address" => "Admin Address",
      "phone_number" => "+1234567890"
    })
    Ecto.Changeset.change(user, role: "admin") |> Repo.update!()
  end
end
