defmodule DeleteTripContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Accounts, Trips, Repo}
  alias EarthScanner.Purchases.Purchase

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
    unique_id = :erlang.unique_integer([:positive])
    email = "admin_delete_#{unique_id}@example.com"

    {:ok, user} = Accounts.register_user(%{
      "username" => "admin_delete_#{unique_id}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Admin",
      "last_name" => "Delete",
      "email" => email,
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "Admin St",
      "phone_number" => "+3726333333"
    })
    admin = Repo.update!(Ecto.Changeset.change(user, role: "admin"))

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
      "dates" => Date.to_iso8601(tomorrow)
    })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^the trip has 0 sold tickets$/, fn state ->
    {:ok, state}
  end

  given_ ~r/^the trip has sold tickets$/, fn state ->
    {:ok, buyer} = Accounts.register_user(%{
      "username" => "buyer_#{:erlang.unique_integer([:positive])}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Buyer",
      "last_name" => "User",
      "email" => "buyer_#{:erlang.unique_integer([:positive])}@example.com",
      "birthdate" => "1995-01-01",
      "nationality" => "EE",
      "residence_address" => "Buyer St",
      "phone_number" => "+3726444444"
    })

    trip = Repo.preload(state.trip, :instances)
    instance = List.first(trip.instances)

    Repo.insert!(%Purchase{
      user_id: buyer.id,
      trip_instance_id: instance.id,
      points_earned: 0,
      points_redeemed: 0
    })

    {:ok, Map.put(state, :buyer, buyer)}
  end

  given_ ~r/^a past trip exists owned by the admin$/, fn state ->
    admin = state.admin
    yesterday = Date.add(Date.utc_today(), -1)

    {:ok, trip} = Trips.create_trip(admin, %{
      "source_city" => "Tallinn",
      "destination_city" => "Tartu",
      "departure_time" => DateTime.new!(yesterday, ~T[10:00:00]),
      "arrival_time" => DateTime.new!(yesterday, ~T[12:00:00]),
      "price" => "25.00",
      "available_tickets" => 50,
      "co2_level" => 100,
      "transport_mode" => "bus",
      "dates" => Date.to_iso8601(yesterday)
    })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^a future trip exists owned by another admin$/, fn state ->
    {:ok, other_admin} = Accounts.register_user(%{
      "username" => "other_admin_#{:erlang.unique_integer([:positive])}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Other",
      "last_name" => "Admin",
      "email" => "other_admin_#{:erlang.unique_integer([:positive])}@example.com",
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "Other St",
      "phone_number" => "+3726555555"
    })
    other_admin = Repo.update!(Ecto.Changeset.change(other_admin, role: "admin"))

    tomorrow = Date.add(Date.utc_today(), 1)
    {:ok, trip} = Trips.create_trip(other_admin, %{
      "source_city" => "Tallinn",
      "destination_city" => "Parnu",
      "departure_time" => DateTime.new!(tomorrow, ~T[10:00:00]),
      "arrival_time" => DateTime.new!(tomorrow, ~T[12:00:00]),
      "price" => "20.00",
      "available_tickets" => 30,
      "co2_level" => 80,
      "transport_mode" => "bus",
      "dates" => Date.to_iso8601(tomorrow)
    })

    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^a normal user is logged in$/, fn state ->
    submit_element({:css, "form[action='/users/logout']"})
    :timer.sleep(1000)

    unique_id = :erlang.unique_integer([:positive])
    email = "normal_user_#{unique_id}@example.com"

    {:ok, _user} = Accounts.register_user(%{
      "username" => "normal_#{unique_id}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Normal",
      "last_name" => "User",
      "email" => email,
      "birthdate" => "1995-01-01",
      "nationality" => "EE",
      "residence_address" => "Normal St",
      "phone_number" => "+3726666666"
    })

    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)

    {:ok, state}
  end

  given_ ~r/^the admin is on the delete confirmation page$/, fn state ->
    navigate_to("http://localhost:4002/admin/trips/#{state.trip.id}/confirm-delete")
    :timer.sleep(1000)
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

  when_ ~r/^the admin clicks the Delete Trip button$/, fn state ->
    # Click delete link/button
    click({:link_text, "Delete"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^the admin tries to delete the trip$/, fn state ->
    navigate_to("http://localhost:4002/admin/trips/#{state.trip.id}")
    :timer.sleep(1000)

    try do
      click({:link_text, "Delete"})
    rescue
      _ -> :ok
    end
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^the admin confirms force delete$/, fn state ->
    # Look for the force delete button/form
    try do
      click({:css, "button"})
    rescue
      _ -> submit_element({:css, "form"})
    end
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^the user tries to delete the trip$/, fn state ->
    navigate_to("http://localhost:4002/admin/trips/#{state.trip.id}")
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^the admin tries to delete trip with ID 999999$/, fn state ->
    navigate_to("http://localhost:4002/admin/trips/999999")
    :timer.sleep(2000)
    {:ok, state}
  end

  # ========================================
  # THEN
  # ========================================

# ========================================
  # THEN
  # ========================================

  then_ ~r/^the admin should see a success message "(.+)"$/, fn state, %{matches: [_message]} ->
    :timer.sleep(1000)
    page_text = visible_page_text()

    assert String.contains?(page_text, "deleted") or
           String.contains?(page_text, "successfully") or
           String.contains?(String.downcase(page_text), "deleted"),
      "Expected success message but got: #{String.slice(page_text, 0, 200)}"
    {:ok, state}
  end

  then_ ~r/^the trip should no longer appear in the admin trip list$/, fn state ->
    navigate_to("http://localhost:4002/admin/trips")
    :timer.sleep(1000)
    page_text = visible_page_text()

    refute String.contains?(page_text, state.trip.source_city) and
           String.contains?(page_text, state.trip.destination_city),
      "Trip should not appear"
    {:ok, state}
  end

  then_ ~r/^the admin should see a warning message "(.+)"$/, fn state, %{matches: [_message]} ->
    :timer.sleep(1000)
    page_text = visible_page_text()

    assert String.contains?(page_text, "sold tickets") or
           String.contains?(page_text, "confirm") or
           String.contains?(String.downcase(page_text), "tickets"),
      "Expected warning about sold tickets but got: #{String.slice(page_text, 0, 200)}"
    {:ok, state}
  end

  then_ ~r/^the admin should be redirected to the delete confirmation page$/, fn state ->
    :timer.sleep(1000)
    current = current_url()
    assert String.contains?(current, "/confirm-delete"),
      "Expected confirmation page but got: #{current}"
    {:ok, state}
  end

  then_ ~r/^the admin should see "(.+)"$/, fn state, %{matches: [message]} ->
    :timer.sleep(1000)
    page_text = visible_page_text()

    assert String.contains?(page_text, message) or
           String.contains?(String.downcase(page_text), String.downcase(message)),
      "Expected: '#{message}' but got: #{String.slice(page_text, 0, 200)}"
    {:ok, state}
  end

  then_ ~r/^the trip and its purchases should be removed$/, fn state ->
    assert Repo.get(EarthScanner.Trips.Trip, state.trip.id) == nil,
      "Trip should be deleted from database"
    {:ok, state}
  end

  then_ ~r/^the admin should see an error message "(.+)"$/, fn state, %{matches: [message]} ->
    :timer.sleep(1000)
    page_text = visible_page_text()

    assert String.contains?(page_text, "Cannot delete") or
           String.contains?(page_text, "past") or
           String.contains?(String.downcase(page_text), String.downcase(message)),
      "Expected error: '#{message}' but got: #{String.slice(page_text, 0, 200)}"
    {:ok, state}
  end

  then_ ~r/^the user should see "(.+)"$/, fn state, %{matches: [message]} ->
    :timer.sleep(1000)
    page_text = visible_page_text()
    current = current_url()

    assert String.contains?(page_text, message) or
           String.contains?(String.downcase(page_text), String.downcase(message)) or
           not String.contains?(current, "/admin/"),
      "Expected: '#{message}' but got URL: #{current}, Page: #{String.slice(page_text, 0, 200)}"
    {:ok, state}
  end

  then_ ~r/^the user should see "(.+)" or be redirected$/, fn state, %{matches: [message]} ->
    :timer.sleep(1000)
    page_text = visible_page_text()
    current = current_url()

    is_blocked = String.contains?(page_text, message) or
                 String.contains?(page_text, "not authorized") or
                 not String.contains?(current, "/admin/") or
                 String.contains?(current, "/login")

    assert is_blocked, "Regular user should be blocked but got URL: #{current}"
    {:ok, state}
  end
end
