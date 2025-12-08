defmodule NFR07SecureAuthenticationContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.Accounts

  scenario_starting_state fn _ ->
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

  given_ ~r/^a user exists$/, fn state ->
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
        "nationality" => "EE",
        "residence_address" => "Street 123",
        "phone_number" => "+3726000000"
      })

    {:ok, %{email: email, password: password, user: user}}
  end

  given_ ~r/^I am on the login page$/, fn state ->
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)
    {:ok, state}
  end

  given_ ~r/^I am on the registration page$/, fn state ->
    navigate_to("http://localhost:4002/users/register")
    :timer.sleep(500)
    {:ok, state}
  end

  # ========================================
  # WHEN (login + registration)
  # ========================================

  when_ ~r/^I submit correct login credentials$/, fn state ->
    fill_field({:css, "input[name='session[email]']"}, state.email)
    fill_field({:css, "input[name='session[password]']"}, state.password)
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I submit a wrong password$/, fn state ->
    fill_field({:css, "input[name='session[email]']"}, state.email)
    fill_field({:css, "input[name='session[password]']"}, "WrongPassword123!")
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I attempt login with unknown email$/, fn state ->
    fill_field({:css, "input[name='session[email]']"}, "unknown_nfr07@example.com")
    fill_field({:css, "input[name='session[password]']"}, "Whatever123!")
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I submit a registration with mismatched passwords$/, fn state ->
    unique = Integer.to_string(System.unique_integer([:positive]))

    fill_field({:css, "input[name='user[username]']"}, "mismatch_" <> unique)
    fill_field({:css, "input[name='user[email]']"}, "mismatch_" <> unique <> "@example.com")
    fill_field({:css, "input[name='user[password]']"}, "Password123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "DifferentPass456!")
    fill_field({:css, "input[name='user[name]']"}, "Test")
    fill_field({:css, "input[name='user[last_name]']"}, "User")
    fill_field({:css, "input[name='user[birthdate]']"}, "1990-01-01")
    fill_field({:css, "input[name='user[nationality]']"}, "EE")
    fill_field({:css, "input[name='user[residence_address]']"}, "Test St")
    fill_field({:css, "input[name='user[phone_number]']"}, "+3726111111")

    :timer.sleep(300)
    submit_element({:id, "registration-form"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I submit an invalid registration$/, fn state ->
    # Leave required fields empty
    fill_field({:css, "input[name='user[username]']"}, "")
    fill_field({:css, "input[name='user[email]']"}, "invalid-email")
    fill_field({:css, "input[name='user[password]']"}, "short")

    :timer.sleep(300)
    submit_element({:id, "registration-form"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I click log out$/, fn state ->
    :timer.sleep(500)
    submit_element({:css, "form[action='/users/logout']"})
    :timer.sleep(2000)
    {:ok, state}
  end

  # ========================================
  # THEN (assertions)
  # ========================================

  then_ ~r/^I should see the home page$/, fn state ->
    :timer.sleep(1000)
    page_text = visible_page_text()
    current = current_url()

    # Check if we're on home page - look for multiple indicators
    is_home = String.contains?(current, "localhost:4002/") and
              not String.contains?(current, "/login") and
              not String.contains?(current, "/register")

    # Also check for common home page text
    has_home_content = String.contains?(page_text, "Welcome") or
                       String.contains?(page_text, "Phoenix") or
                       String.contains?(page_text, "Profile") or
                       String.contains?(page_text, "Log out")

    assert is_home and has_home_content,
      "Expected to see home page but got URL: #{current} with text containing: #{String.slice(page_text, 0, 200)}"

    {:ok, state}
  end

  then_ ~r/^I should see a login error$/, fn state ->
    :timer.sleep(500)
    page_text = visible_page_text()

    assert String.contains?(page_text, "Invalid email or password") or
           String.contains?(page_text, "Invalid") or
           String.contains?(page_text, "error"),
      "Expected to see login error message"

    {:ok, state}
  end

  then_ ~r/^I should see the login page$/, fn state ->
    :timer.sleep(500)
    page_text = visible_page_text()
    current = current_url()

    assert (String.contains?(page_text, "Log in") or String.contains?(page_text, "Login")) and
           (String.contains?(current, "/login") or String.contains?(current, "/log_in")),
      "Expected to be on login page"

    {:ok, state}
  end

  then_ ~r/^I should see a registration error$/, fn state ->
    :timer.sleep(500)
    page_text = visible_page_text()

    assert String.contains?(page_text, "error") or
           String.contains?(page_text, "can't be blank") or
           String.contains?(page_text, "confirmation") or
           String.contains?(page_text, "too short") or
           String.contains?(page_text, "invalid"),
      "Expected to see registration error"

    {:ok, state}
  end
end
