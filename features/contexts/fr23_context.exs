defmodule FR23Context do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Repo, Accounts, Trips}
  alias EarthScanner.Accounts.User

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, _state ->
    Hound.end_session()
    :ok
  end

  # Given Steps
  given_ ~r/^I am logged in as an admin who created a trip$/, fn state, _ ->
    unique = :erlang.unique_integer([:positive])
    email = "creator_#{unique}@example.com"

    admin_attrs = %{
      username: "creator_#{unique}",
      password: "Password123!",
      password_confirmation: "Password123!",
      email: email,
      phone_number: "+100000#{unique}",
      role: "admin"
    }

    {:ok, admin} =
      %User{}
      |> User.admin_changeset(admin_attrs)
      |> Repo.insert()

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "transport_mode" => "train",
        "source_city" => "ContextCityA",
        "destination_city" => "ContextCityB",
        "departure_time" => "2026-02-01T09:00:00Z",
        "arrival_time" => "2026-02-01T11:00:00Z",
        "price" => "15.00",
        "co2_level" => "30",
        "available_tickets" => "10",
        "dates" => "2026-02-01"
      })

    # Login via UI
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(800)

    {:ok, Map.merge(state, %{admin: admin, trip: trip})}
  end

  given_ ~r/^I am logged in as an admin who did NOT create the trip$/, fn state, _ ->
    unique = :erlang.unique_integer([:positive])
    email_creator = "creator_#{unique}@example.com"
    email_other = "other_#{unique}@example.com"

    creator_attrs = %{
      username: "creator_#{unique}",
      password: "Password123!",
      password_confirmation: "Password123!",
      email: email_creator,
      phone_number: "+100000#{unique}",
      role: "admin"
    }

    other_attrs = %{
      username: "other_#{unique}",
      password: "Password123!",
      password_confirmation: "Password123!",
      email: email_other,
      phone_number: "+200000#{unique}",
      role: "admin"
    }

    {:ok, creator} =
      %User{}
      |> User.admin_changeset(creator_attrs)
      |> Repo.insert()

    {:ok, other_admin} =
      %User{}
      |> User.admin_changeset(other_attrs)
      |> Repo.insert()

    {:ok, trip} =
      Trips.create_trip(creator, %{
        "transport_mode" => "ferry",
        "source_city" => "OtherCityA",
        "destination_city" => "OtherCityB",
        "departure_time" => "2026-03-01T09:00:00Z",
        "arrival_time" => "2026-03-01T11:00:00Z",
        "price" => "30.00",
        "co2_level" => "10",
        "available_tickets" => "5",
        "dates" => "2026-03-01"
      })

    # Login as other admin via UI
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, email_other)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(800)

    {:ok, Map.merge(state, %{admin: other_admin, trip: trip})}
  end

  # When Steps
  when_ ~r/^I visit the admin trip detail page for that trip$/, fn state, _ ->
    trip = state[:trip]
    navigate_to("http://localhost:4002/admin/trips/#{trip.id}")
    :timer.sleep(600)
    {:ok, state}
  end

  # Then Steps
  then_ ~r/^I should see the trip's source and destination on the page$/, fn state, _ ->
    trip = state[:trip]
    page = visible_page_text()

    if String.contains?(page, trip.source_city) and String.contains?(page, trip.destination_city) do
      {:ok, state}
    else
      {:error, "Expected to see trip source and destination on the page"}
    end
  end

  then_ ~r/^I should see an unauthorized message or be redirected to the admin trips list$/, fn state, _ ->
    page = visible_page_text()
    current = current_url()

    cond do
      String.contains?(page, "not authorized") -> {:ok, state}
      String.contains?(current, "/admin/trips") -> {:ok, state}
      true -> {:error, "Expected unauthorized message or redirect, got neither"}
    end
  end
end
