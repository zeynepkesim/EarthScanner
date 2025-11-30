defmodule LoyaltyPointsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias Ecto.Changeset
  alias EarthScanner.{Accounts, Trips, Repo}
  alias Hound.Helpers.Cookie

  @base "http://localhost:4002"

  # ===================================================================
  # LOYALTY POINTS CONTEXT (FR-25 & FR-26)
  # ===================================================================
  #
  # This context implements the steps for the following scenarios:
  #
  # --- FR-25: Earn Loyalty Points ---
  # Positive:
  #   - "User earns points on standard purchase"
  #   - "User earns points on expensive trip"
  # Negative:
  #   - "No points earned on failed purchase (Sold Out)" (Uses "that trip is sold out" step)
  # Edge Cases:
  #   - "User earns 0 points on free trip"
  #
  # --- FR-26: Redeem Loyalty Points ---
  # Positive:
  #   - "User redeems points for partial discount" (Uses "I choose to redeem my points" step)
  #   - "User redeems points for full discount"
  # Negative:
  #   - "User with 0 points cannot get discount"
  # Edge Cases:
  #   - "User has exactly enough points for max discount"
  # ===================================================================

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

  when_ ~r/^I purchase a ticket$/, fn %{trip: trip} = state, _ ->
    submit_purchase_form(trip.id)
    {:ok, state}
  end

  # --- FR-26 Specific Steps (Redemption) ---

  when_ ~r/^I choose to redeem my points$/, fn state, _ ->
    # Click checkbox
    # Using name attribute
    click({:name, "redeem_points"})
    {:ok, state}
  end

  when_ ~r/^I confirm the purchase$/, fn %{trip: trip} = state, _ ->
    submit_purchase_form(trip.id)
    {:ok, state}
  end

  # --- Negative Scenario Steps ---

  given_ ~r/^that trip is sold out$/, fn %{trip: trip} = state, _ ->
    instance = hd(trip.instances)
    instance |> Changeset.change(available_tickets: 0) |> Repo.update!()
    {:ok, state}
  end

  when_ ~r/^I attempt to purchase a ticket$/, fn %{trip: trip} = state, _ ->
    submit_purchase_form(trip.id)
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

  then_ ~r/^my loyalty points balance should increase by (?<amount>\d+)$/, fn %{user: user} = state, %{amount: amount} ->
    reloaded_user = Repo.get!(Accounts.User, user.id)
    # user.loyalty_points is the OLD balance (from state)
    assert reloaded_user.loyalty_points == user.loyalty_points + String.to_integer(amount)
    {:ok, state}
  end

  # Helpers
  defp create_user(name) do
    suffix = System.unique_integer([:positive]) |> Integer.to_string()
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
      "dates" => future_date
    })
    Repo.preload(trip, :instances)
  end

  defp ensure_admin do
    suffix = System.unique_integer([:positive]) |> Integer.to_string()
    {:ok, user} = Accounts.register_user(%{
      "username" => "admin_#{suffix}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Admin",
      "last_name" => "User",
      "email" => "admin_#{suffix}@example.com",
      "phone_number" => "+1234567890"
    })
    user |> Changeset.change(role: "admin") |> Repo.update!()
  end

  defp submit_purchase_form(trip_id) do
    form = find_element(:xpath, "(//form[@action='/trips/#{trip_id}/purchase'])[1]")
    submit_element(form)
    Process.sleep(1000)
  end
end
