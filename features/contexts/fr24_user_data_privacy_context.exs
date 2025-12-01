defmodule FR24UserDataPrivacyContext do
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
    email = "privacy_" <> suffix <> "@example.com"
    password = "Password123!"

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "privacy_u_" <> suffix,
        "password" => password,
        "password_confirmation" => password,
        "name" => "Jane",
        "last_name" => "User",
        "email" => email,
        "birthdate" => "1991-01-01",
        "nationality" => "ID",
        "residence_address" => "Test Street",
        "phone_number" => "+620000000111"
      })

    {:ok, %{email: email, password: password, user: user}}
  end

  given_ ~r/^I am on the login page$/, fn state ->
    navigate_to("http://localhost:4002/users/login")
    {:ok, state}
  end

  given_ ~r/^I navigate to "([^"]+)"$/, fn state, %{matches: [path]} ->
    navigate_to("http://localhost:4002" <> path)
    {:ok, state}
  end

  given_ ~r/^I am logged in as an admin$/, fn state ->
    {:ok, admin} =
      Accounts.register_user(%{
        "username" => "privacy_admin",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Admin",
        "last_name" => "Test",
        "email" => "privacy_admin@example.com",
        "birthdate" => "1980-01-01",
        "nationality" => "ID",
        "residence_address" => "Admin Road",
        "phone_number" => "+620000000222",
        "role" => "admin"
      })

    navigate_to("http://localhost:4002/users/login")
    fill_field({:css, "input[name='session[email]']"}, admin.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})

    {:ok, Map.put(state, :admin, admin)}
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

  when_ ~r/^I visit the profile page$/, fn state ->
    navigate_to("http://localhost:4002/profile")
    {:ok, state}
  end

  ##########################################################################
  # THEN
  ##########################################################################

  then_ ~r/^I should be redirected back to the profile page$/, fn state ->
    assert String.ends_with?(current_url(), "/profile")
    {:ok, state}
  end

  then_ ~r/^I should be redirected back to the search page$/, fn state ->
    assert String.contains?(current_url(), "/search")
    {:ok, state}
  end

  then_ ~r/^I should see "([^"]+)"$/, fn state, %{matches: [text]} ->
    assert visible_page_text() =~ text
    {:ok, state}
  end
end
