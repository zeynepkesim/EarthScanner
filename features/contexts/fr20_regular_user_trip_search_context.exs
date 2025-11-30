defmodule FR20RegularUserTripSearchContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.Accounts

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

  given_ ~r/^a user exists$/, fn _ ->
    suffix = Integer.to_string(System.unique_integer([:positive]))
    email = "fr20_" <> suffix <> "@example.com"
    password = "Password123!"

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "fr20_u_" <> suffix,
        "password" => password,
        "password_confirmation" => password,
        "name" => "Test",
        "last_name" => "User",
        "email" => email,
        "birthdate" => "1999-01-01",
        "nationality" => "ID",
        "residence_address" => "Some St",
        "phone_number" => "+620000005555"
      })

    {:ok, %{email: email, password: password, user: user}}
  end

  given_ ~r/^I am a visitor$/, fn state ->
    {:ok, state}
  end

  given_ ~r/^I am logged in as an admin$/, fn state ->
    {:ok, admin} =
      Accounts.register_user(%{
        "username" => "fr20_admin",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Admin",
        "last_name" => "FR20",
        "email" => "fr20_admin@example.com",
        "birthdate" => "1980-01-01",
        "nationality" => "ID",
        "residence_address" => "Admin St",
        "phone_number" => "+620000004444",
        "role" => "admin"
      })

    navigate_to("http://localhost:4002/users/login")
    fill_field({:css, "input[name='session[email]']"}, admin.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})

    {:ok, Map.put(state, :admin, admin)}
  end

  given_ ~r/^a set of future trips exist$/, fn state ->
    navigate_to("http://localhost:4002") # UI only
    {:ok, state}
  end

  given_ ~r/^a set of future trips with various attributes exist$/, fn state ->
    navigate_to("http://localhost:4002")
    {:ok, state}
  end

  given_ ~r/^I am on the login page$/, fn state ->
    navigate_to("http://localhost:4002/users/login")
    {:ok, state}
  end

  ##########################################################################
  # WHEN
  ##########################################################################

  when_ ~r/^I submit correct login credentials$/, fn state ->
    fill_field({:css, "input[name='session[email]']"}, state.email)
    fill_field({:css, "input[name='session[password]']"}, state.password)
    submit_element({:id, "login-form"})
    {:ok, state}
  end

  when_ ~r/^I visit the homepage$/, fn state ->
    navigate_to("http://localhost:4002/")
    {:ok, state}
  end

  when_ ~r/^I search for trips from "([^"]*)" to "([^"]*)"$/, fn state, %{matches: [src, dst]} ->
    navigate_to("http://localhost:4002/search/results?source=#{src}&destination=#{dst}")
    {:ok, state}
  end

  when_ ~r/^I search for trips from "" to "([^"]+)"$/, fn state, %{matches: [dst]} ->
    navigate_to("http://localhost:4002/search/results?source=&destination=#{dst}")
    {:ok, state}
  end

  ##########################################################################
  # THEN
  ##########################################################################

  then_ ~r/^I should see the search box on the homepage$/, fn state ->
    html = visible_page_text()
    assert String.contains?(html, "Search") or String.contains?(html, "source")
    {:ok, state}
  end

  then_ ~r/^I should not see the search box on the homepage$/, fn state ->
    html = visible_page_text()
    refute String.contains?(html, "Search")
    {:ok, state}
  end

  then_ ~r/^I should see at least 1 trip in the results$/, fn state ->
    assert visible_page_text() =~ "Mode:"
    {:ok, state}
  end

  then_ ~r/^I should be redirected back to the search page$/, fn state ->
    assert String.ends_with?(current_url(), "/search")
    {:ok, state}
  end
end
