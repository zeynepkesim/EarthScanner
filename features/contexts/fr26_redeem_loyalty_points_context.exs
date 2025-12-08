defmodule RedeemLoyaltyPointsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias Ecto.Changeset
  alias EarthScanner.{Accounts, Trips, Repo}
  alias Hound.Helpers.Cookie
  import Ecto.Query

  @base "http://localhost:4002"

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, state ->
    Hound.end_session()
    {:ok, state}
  end

  # --- Shared Steps (Setup & Navigation) ---

  given_ ~r/^I am a registered user named "(?<name>[^"]+)"$/, fn state, %{name: name} ->
    user = create_user(name)
    {:ok, Map.put(state, :user, user)}
  end

  given_ ~r/^I am logged in$/, fn %{user: user} = state, _ ->
    login_user(user)
    {:ok, state}
  end

  given_ ~r/^there is a trip "(?<city>[^"]+)" costing (?<price>[^ ]+) EUR$/, fn state, %{city: city, price: price} ->
    trip = create_trip(city, price)
    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^I have (?<points>\d+) loyalty points$/, fn %{user: user} = state, %{points: points} ->
    user
    |> Changeset.change(loyalty_points: String.to_integer(points))
    |> Repo.update!()
    {:ok, state}
  end

  when_ ~r/^I search for "(?<city>[^"]+)"$/, fn state, %{city: city} ->
    navigate_to(@base <> "/trips?destination=#{city}")
    {:ok, state}
  end

  when_ ~r/^I view the trip details$/, fn %{trip: trip} = state, _ ->
    navigate_to(@base <> "/trips/#{trip.id}")
    {:ok, state}
  end



  when_ ~r/^I choose to redeem my points$/, fn state, _ ->
    # Small wait for UI
    Process.sleep(500)
    # Check the checkbox
    Hound.Helpers.Element.click({:css, "input[name='redeem_points']"})
    {:ok, state}
  end

  when_ ~r/^I attempt to redeem points$/, fn state ->
    # Check the checkbox and submit
    Hound.Helpers.Element.click({:css, "input[name='redeem_points']"})
    Hound.Helpers.Element.click({:css, "button[type='submit']"})
    # Handle the "Confirm purchase?" alert
    Hound.Helpers.Dialog.accept_dialog()
    {:ok, state}
  end

  # --- Verification Steps ---

  then_ ~r/^I should see "(?<message>[^"]+)"$/, fn state, %{message: message} ->
    Process.sleep(500)
    assert String.contains?(visible_page_text(), message)
    {:ok, state}
  end

  then_ ~r/^my loyalty points balance should be (?<points>\d+)$/, fn %{user: user} = state, %{points: points} ->
    reloaded_user = Repo.get!(Accounts.User, user.id)
    assert reloaded_user.loyalty_points == String.to_integer(points)
    {:ok, state}
  end

  # --- Audit Log Steps ---

  then_ ~r/^an audit log should exist for my point change$/, fn %{user: user} = state, _ ->
    log = Repo.one!(EarthScanner.Accounts.PointLog)
    assert log.user_id == user.id
    assert log.reason == "trip_purchase"
    {:ok, state}
  end

  then_ ~r/^an audit log should exist showing a decrease of (?<amount>\d+) points$/, fn %{user: user} = state, %{amount: amount} ->
    log = Repo.one!(EarthScanner.Accounts.PointLog)
    assert log.user_id == user.id
    expected_change = -String.to_integer(amount)
    assert log.change_amount == expected_change
    {:ok, state}
  end

  # Helpers
  defp create_user(name) do
    unique_num = System.unique_integer([:positive, :monotonic])
    suffix = Integer.to_string(unique_num) <> "_#{System.os_time(:nanosecond)}"
    email = "loyal_#{suffix}@example.com"
    password = "Password123!"
    {:ok, user} = Accounts.register_user(%{
      "username" => "loyal_#{suffix}",
      "password" => password,
      "password_confirmation" => password,
      "name" => name,
      "last_name" => "User",
      "email" => email,
      "birthdate" => "1990-01-01",
      "nationality" => "US",
      "residence_address" => "Address",
      "phone_number" => "+1234567890"
    })
    user
  end

  defp login_user(user) do
    navigate_to(@base <> "/users/login")
    fill_field({:css, "input[name='session[email]']"}, user.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})
  end

  defp create_trip(city, price) do
    admin = ensure_admin()
    future_date = Date.utc_today() |> Date.add(10) |> Date.to_iso8601()
    {:ok, trip} = Trips.create_trip(admin, %{
      "source_city" => "Tallinn",
      "destination_city" => city,
      "departure_time" => "2025-12-01T10:00:00Z",
      "arrival_time" => "2025-12-01T12:00:00Z",
      "price" => price,
      "co2_level" => 100,
      "available_tickets" => 10,
      "transport_mode" => "plane",
      "dates" => future_date,
      "picture_url" => "https://example.com/pic.jpg"
    })
    Repo.preload(trip, :instances)
  end

  defp ensure_admin do
    unique_num = System.unique_integer([:positive, :monotonic])
    suffix = Integer.to_string(unique_num) <> "_#{System.os_time(:nanosecond)}"
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
    user |> Changeset.change(role: "admin") |> Repo.update!()
  end

  when_ ~r/^I purchase a ticket.*$/, fn state ->
    # Small wait for UI to render instances
    Process.sleep(500)
    # Click the first available "Purchase ticket" button
    Hound.Helpers.Element.click({:css, "button[type='submit']"})
    # Handle the "Confirm purchase?" alert
    Hound.Helpers.Dialog.accept_dialog()
    {:ok, state}
  end
end
