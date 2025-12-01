defmodule FR22UserTripsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Accounts, Trips, Repo}
  alias Ecto.Changeset

  @base_url "http://localhost:4002"

  scenario_starting_state(fn _ ->
    Hound.start_session()
    %{user: nil, credentials: nil}
  end)

  scenario_finalize(fn _status, _state ->
    Hound.end_session()
    :ok
  end)

  given_(~r/^the test database is clean for FR-22 scenarios$/, fn state, _ ->
    {:ok, %{state | user: nil, credentials: nil}}
  end)

  given_(~r/^a regular user has upcoming and past trip purchases$/, fn state, _ ->
    {admin, trip_attrs_fun} = build_admin_and_attr_fun()
    {user, credentials} = create_regular_user()

    {:ok, upcoming_trip} =
      Trips.create_trip(admin, trip_attrs_fun.(Date.add(Date.utc_today(), 5)))

    upcoming_instance = hd(upcoming_trip.instances)
    {:ok, _} = Trips.purchase_trip_instance(user, upcoming_instance.id)

    {:ok, past_trip} = Trips.create_trip(admin, trip_attrs_fun.(Date.add(Date.utc_today(), 7)))
    past_instance = hd(past_trip.instances)
    {:ok, _} = Trips.purchase_trip_instance(user, past_instance.id)
    mark_instance_as_past(past_instance)

    {:ok, %{state | user: user, credentials: credentials}}
  end)

  given_(~r/^I am not logged in for FR-22$/, fn state, _ ->
    navigate_to("#{@base_url}/users/logout")
    :timer.sleep(500)
    {:ok, %{state | user: nil, credentials: nil}}
  end)

  when_(~r/^I log in as that user and visit the My Trips page$/, fn state, _ ->
    %{credentials: %{email: email, password: password}} = state

    navigate_to("#{@base_url}/users/login")
    :timer.sleep(500)
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, password)
    submit_element({:id, "login-form"})
    :timer.sleep(800)

    navigate_to("#{@base_url}/my-trips")
    :timer.sleep(800)

    {:ok, state}
  end)

  when_(~r/^I visit the My Trips page without authenticating$/, fn state, _ ->
    navigate_to("#{@base_url}/my-trips")
    :timer.sleep(500)
    {:ok, state}
  end)

  then_(~r/^I should see my upcoming trip listed$/, fn state, _ ->
    page = visible_page_text()

    cond do
      String.contains?(page, "Upcoming trips") and String.contains?(page, "Upcoming") ->
        {:ok, state}

      true ->
        {:error, "Expected upcoming trip content but it was missing"}
    end
  end)

  then_(~r/^I should see my past trip listed after switching tabs$/, fn state, _ ->
    click({:css, "#past-tab"})
    :timer.sleep(500)

    page = visible_page_text()

    cond do
      String.contains?(page, "Past trips") and
          (String.contains?(page, "Completed") or String.contains?(page, "COMPLETED")) ->
        {:ok, state}

      true ->
        {:error, "Expected past trip content after switching tabs"}
    end
  end)

  then_(~r/^I should be redirected to the login form for FR-22$/, fn state, _ ->
    current = current_url()

    if String.contains?(current, "/users/login") do
      {:ok, state}
    else
      {:error, "Expected redirect to /users/login, got #{current}"}
    end
  end)

  defp create_regular_user do
    unique = System.unique_integer([:positive])
    email = "fr22_user_#{unique}@example.com"

    attrs = %{
      "username" => "fr22_user_#{unique}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "FR22",
      "last_name" => "User",
      "email" => email,
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "Street",
      "phone_number" => "+372#{unique}"
    }

    {:ok, user} = Accounts.register_user(attrs)
    {user, %{email: email, password: "Password123!"}}
  end

  defp build_admin_and_attr_fun do
    unique = System.unique_integer([:positive])

    admin_attrs = %{
      "username" => "fr22_admin_#{unique}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Admin",
      "last_name" => "FR22",
      "email" => "fr22_admin_#{unique}@example.com",
      "birthdate" => "1980-01-01",
      "nationality" => "EE",
      "residence_address" => "Admin Street",
      "phone_number" => "+372555#{unique}"
    }

    {:ok, admin} = Accounts.register_user(admin_attrs)
    {:ok, admin} = admin |> Changeset.change(%{role: "admin"}) |> Repo.update()

    attr_fun = fn date ->
      base_departure = DateTime.add(DateTime.utc_now(), 7200, :second)

      %{
        "transport_mode" => "train",
        "source_city" => "Tallinn",
        "destination_city" => "Riga",
        "departure_time" => base_departure,
        "arrival_time" => DateTime.add(base_departure, 3600, :second),
        "price" => "75.00",
        "co2_level" => "90",
        "available_tickets" => "5",
        "dates" => Date.to_iso8601(date)
      }
    end

    {admin, attr_fun}
  end

  defp mark_instance_as_past(instance) do
    past_date = Date.add(Date.utc_today(), -3)

    instance
    |> Changeset.change(%{date: past_date})
    |> Repo.update!()
  end
end
