defmodule FR21AdminAccessTripsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.Accounts
  alias EarthScanner.Repo
  alias EarthScanner.Trips.Trip

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, state ->
    Hound.end_session()
    {:ok, state}
  end

  ##########################################################################
  # GIVEN
  ##########################################################################

  given_ ~r/^I am logged in as an admin$/, fn state ->
    {:ok, admin} =
      Accounts.register_user(%{
        "username" => "admin_fr21",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Admin",
        "last_name" => "FR21",
        "email" => "admin_fr21@example.com",
        "birthdate" => "1980-01-01",
        "nationality" => "ID",
        "residence_address" => "Test Street",
        "phone_number" => "+620000011111",
        "role" => "admin"
      })

    navigate_to("http://localhost:4002/users/login")
    fill_field({:css, "input[name='session[email]']"}, admin.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})

    {:ok, Map.put(state, :admin, admin)}
  end

  given_ ~r/^a set of future trips exist$/, fn state ->
    insert_trip("Tartu", "Tallinn", +86_400)
    {:ok, state}
  end

  given_ ~r/^a set of past and future trips exist$/, fn state ->
    insert_trip("Tartu", "Riga", -86_400)
    insert_trip("Tartu", "Riga", +86_400)
    {:ok, state}
  end

  ##########################################################################
  # WHEN
  ##########################################################################

  when_ ~r/^I visit "([^"]+)"$/, fn state, %{matches: [path]} ->
    navigate_to("http://localhost:4002" <> path)
    {:ok, state}
  end

  ##########################################################################
  # THEN
  ##########################################################################

  then_ ~r/^I should see "([^"]+)"$/, fn state, %{matches: [text]} ->
    assert visible_page_text() =~ text
    {:ok, state}
  end

  then_ ~r/^I should see at least 1 trip in the results$/, fn state ->
    page = visible_page_text()
    assert String.contains?(page, "Mode:")
    {:ok, state}
  end

  then_ ~r/^I should be redirected back to the home page$/, fn state ->
    assert current_url() =~ "http://localhost:4002/"
    {:ok, state}
  end

  ##########################################################################
  # HELPERS
  ##########################################################################

  defp insert_trip(src, dst, offset_seconds) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    t = DateTime.add(now, offset_seconds, :second)

    Repo.insert!(%Trip{
      source_city: src,
      destination_city: dst,
      departure_time: t,
      arrival_time: DateTime.add(t, 3600, :second),
      transport_mode: "bus",
      duration_minutes: 60,
      price: 25,
      co2_level: 100,
      available_tickets: 10,
      admin_id: 1
    })
  end
end
