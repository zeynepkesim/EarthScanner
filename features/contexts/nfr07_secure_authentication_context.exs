defmodule NFR07SecureAuthenticationContext do
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

  given_ ~r/^a user exists$/, fn _state ->
    suffix = Integer.to_string(System.unique_integer([:positive]))
    email = "nfr07_" <> suffix <> "@example.com"
    password = "Password123!"

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "nfr07_user_" <> suffix,
        "password" => password,
        "password_confirmation" => password,
        "name" => "John",
        "last_name" => "Doe",
        "email" => email,
        "birthdate" => "1990-01-01",
        "nationality" => "ID",
        "residence_address" => "Street",
        "phone_number" => "+620000000000"
      })

    {:ok, %{email: email, password: password, user: user}}
  end

  given_ ~r/^I am on the login page$/, fn state ->
    navigate_to("http://localhost:4002/users/login")
    {:ok, state}
  end

  given_ ~r/^I am on the registration page$/, fn state ->
    navigate_to("http://localhost:4002/users/register")
    {:ok, state}
  end

  ##########################################################################
  # WHEN (login + registration)
  ##########################################################################

  when_ ~r/^I submit correct login credentials$/, fn state ->
    fill_field({:css, "input[name='session[email]']"}, state.email)
    fill_field({:css, "input[name='session[password]']"}, state.password)
    submit_element({:id, "login-form"})
    {:ok, state}
  end

  when_ ~r/^I submit a wrong password$/, fn state ->
    fill_field({:css, "input[name='session[email]']"}, state.email)
    fill_field({:css, "input[name='session[password]']"}, "Wrong123!")
    submit_element({:id, "login-form"})
    {:ok, state}
  end

  when_ ~r/^I attempt login with unknown email$/, fn state ->
    fill_field({:css, "input[name='session[email]']"}, "unknown@example.com")
    fill_field({:css, "input[name='session[password]']"}, "Whatever123!")
    submit_element({:id, "login-form"})
    {:ok, state}
  end

  when_ ~r/^I submit a registration with mismatched passwords$/, fn state ->
    fill_field({:css, "input[name='user[username]']"}, "bad_reg")
    fill_field({:css, "input[name='user[email]']"}, "bad_reg@example.com")
    fill_field({:css, "input[name='user[password]']"}, "Password123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "Mismatch456!")
    submit_element({:id, "registration-form"})
    {:ok, state}
  end

  when_ ~r/^I submit an invalid registration$/, fn state ->
    fill_field({:css, "input[name='user[username]']"}, "")
    fill_field({:css, "input[name='user[email]']"}, "invalid")
    submit_element({:id, "registration-form"})
    {:ok, state}
  end

  when_ ~r/^I click log out$/, fn state ->
    submit_element({:css, "form[action='/users/logout']"})
    {:ok, state}
  end

  ##########################################################################
  # THEN (assertions)
  ##########################################################################

  then_ ~r/^I should see the home page$/, fn state ->
    assert visible_page_text() =~ "Phoenix"
    {:ok, state}
  end

  then_ ~r/^I should see a login error$/, fn state ->
    assert visible_page_text() =~ "Invalid email or password"
    {:ok, state}
  end

  then_ ~r/^I should see the login page$/, fn state ->
    assert visible_page_text() =~ "Log in"
    {:ok, state}
  end

  then_ ~r/^I should see a registration error$/, fn state ->
    text = visible_page_text()
    assert String.contains?(text, "errors") or String.contains?(text, "Please fix")
    {:ok, state}
  end
end
