defmodule LoginContext do
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

  # GIVEN
  given_ ~r/^a user exists$/, fn _state ->
    suffix = Integer.to_string(System.unique_integer([:positive]))
    email = "login_" <> suffix <> "@example.com"
    password = "Password123!"

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "login_user_" <> suffix,
        "password" => password,
        "password_confirmation" => password,
        "name" => "BDD",
        "last_name" => "User",
        "email" => email,
        "birthdate" => "1995-05-05",
        "nationality" => "ID",
        "residence_address" => "Jl. BDD 1",
        "phone_number" => "+628222222222"
      })

    {:ok, %{email: email, password: password, user: user}}
  end

  given_ ~r/^I am on the login page$/, fn state ->
    navigate_to("http://localhost:4002/users/login")
    {:ok, state}
  end

  # WHEN
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
    fill_field({:css, "input[name='session[email]']"}, "unknown_" <> Integer.to_string(System.unique_integer([:positive])) <> "@example.com")
    fill_field({:css, "input[name='session[password]']"}, "Whatever123!")
    submit_element({:id, "login-form"})
    {:ok, state}
  end

  when_ ~r/^I click log out$/, fn state ->
    submit_element({:css, "form[action='/users/logout']"})
    {:ok, state}
  end

  # THEN
  then_ ~r/^I should see the home page$/, fn state ->
    text = visible_page_text()
    assert String.contains?(text, "Phoenix") or String.contains?(text, "Welcome")
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
end
