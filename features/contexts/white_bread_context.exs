defmodule WhiteBreadContext do
  use WhiteBread.Context
  use Hound.Helpers

  # 1-arity: state
  scenario_starting_state fn state ->
    Hound.start_session()
    state
  end

  # 2-arity: status, state
  scenario_finalize fn _status, _state ->
    Hound.end_session()
    :ok
  end

  given_ ~r/^I am a visitor$/, fn state, _extra ->
    {:ok, state}
  end

  when_ ~r/^I visit the homepage$/, fn state, _extra ->
    navigate_to("http://localhost:4002/")
    {:ok, state}
  end

  then_ ~r/^I should see a Phoenix welcome message$/, fn state, _extra ->
    page_text = visible_page_text()
    assert String.contains?(page_text, "Phoenix")
    {:ok, state}
  end

  # Registration steps

  given_ ~r/^I am on the registration page$/, fn state, _extra ->
    navigate_to("http://localhost:4002/users/register")
    {:ok, state}
  end

  when_ ~r/^I submit a valid registration$/, fn state, _extra ->
    suffix = :erlang.unique_integer([:positive]) |> Integer.to_string()
    email = "bdd_" <> suffix <> "@example.com"
    username = "bdduser_" <> suffix
    password = "Password123!"

    # Fill fields
    fill_field({:css, "input[name='user[username]']"}, username)
    fill_field({:css, "input[name='user[name]']"}, "John")
    fill_field({:css, "input[name='user[last_name]']"}, "Doe")
    fill_field({:css, "input[name='user[email]']"}, email)
    fill_field({:css, "input[name='user[birthdate]']"}, "2000-01-01")
    fill_field({:css, "input[name='user[nationality]']"}, "ID")
    fill_field({:css, "input[name='user[residence_address]']"}, "Jalan Example 123")
    fill_field({:css, "input[name='user[phone_number]']"}, "+628123456789")
    fill_field({:css, "input[name='user[password]']"}, password)
    fill_field({:css, "input[name='user[password_confirmation]']"}, password)

    # Submit the form
    submit_element({:id, "registration-form"})

    {:ok, Map.put(state, :email, email)}
  end

  when_ ~r/^I submit a registration with mismatched passwords$/, fn state, _extra ->
    suffix = :erlang.unique_integer([:positive]) |> Integer.to_string()
    email = "bdd_mismatch_" <> suffix <> "@example.com"

    fill_field({:css, "input[name='user[username]']"}, "mismatch_" <> suffix)
    fill_field({:css, "input[name='user[name]']"}, "Jane")
    fill_field({:css, "input[name='user[last_name]']"}, "Doe")
    fill_field({:css, "input[name='user[email]']"}, email)
    fill_field({:css, "input[name='user[birthdate]']"}, "2001-02-03")
    fill_field({:css, "input[name='user[nationality]']"}, "ID")
    fill_field({:css, "input[name='user[residence_address]']"}, "Jl. Test 456")
    fill_field({:css, "input[name='user[phone_number]']"}, "+628111111111")
    fill_field({:css, "input[name='user[password]']"}, "Password123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "Different123!")

    submit_element({:id, "registration-form"})

    {:ok, state}
  end

  when_ ~r/^I submit an invalid registration$/, fn state, _extra ->
    # Intentionally leave most fields blank or invalid; only set a couple
    fill_field({:css, "input[name='user[username]']"}, "")
    fill_field({:css, "input[name='user[email]']"}, "not-an-email")

    submit_element({:id, "registration-form"})

    {:ok, state}
  end

  then_ ~r/^I should see the login page$/, fn state, _extra ->
    # After successful registration we redirect to /users/log-in and flash a message
    page_text = visible_page_text()
    assert String.contains?(page_text, "Log in")
    {:ok, state}
  end

  then_ ~r/^I should see a registration error$/, fn state, _extra ->
    page_text = visible_page_text()
    assert String.contains?(page_text, "Please fix the errors below and try again.")
    {:ok, state}
  end
end
