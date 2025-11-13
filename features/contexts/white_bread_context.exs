defmodule WhiteBreadContext do
  use WhiteBread.Context
  use Hound.Helpers
  alias EarthScanner.Accounts

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
    # After successful registration we redirect to /users/login and flash a message
    page_text = visible_page_text()
    assert String.contains?(page_text, "Log in")
    {:ok, state}
  end

  then_ ~r/^I should see a registration error$/, fn state, _extra ->
    page_text = visible_page_text()
    assert String.contains?(page_text, "Please fix the errors below and try again.")
    {:ok, state}
  end

  # --- Login steps ---

  given_ ~r/^a user exists$/, fn state, _extra ->
    suffix = Integer.to_string(System.unique_integer([:positive]))
    email = "login_bdd_" <> suffix <> "@example.com"
    password = "Password123!"

    {:ok, _user} =
      Accounts.register_user(%{
        "username" => "bdd_login_user_" <> suffix,
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

    {:ok, Map.merge(state, %{email: email, password: password})}
  end

  given_ ~r/^I am on the login page$/, fn state, _extra ->
    navigate_to("http://localhost:4002/users/login")
    {:ok, state}
  end

  when_ ~r/^I submit correct login credentials$/, fn state, _extra ->
    fill_field({:css, "input[name='session[email]']"}, state.email)
    fill_field({:css, "input[name='session[password]']"}, state.password)
    submit_element({:id, "login-form"})
    {:ok, state}
  end

  when_ ~r/^I submit a wrong password$/, fn state, _extra ->
    fill_field({:css, "input[name='session[email]']"}, state.email)
    fill_field({:css, "input[name='session[password]']"}, "Wrong123!")
    submit_element({:id, "login-form"})
    {:ok, state}
  end

  when_ ~r/^I attempt login with unknown email$/, fn state, _extra ->
    fill_field({:css, "input[name='session[email]']"}, "unknown_" <> Integer.to_string(System.unique_integer([:positive])) <> "@example.com")
    fill_field({:css, "input[name='session[password]']"}, "Whatever123!")
    submit_element({:id, "login-form"})
    {:ok, state}
  end

  when_ ~r/^I click log out$/, fn state, _extra ->
    # Submit the logout form present in the layout
    submit_element({:css, "form[action='/users/logout']"})
    {:ok, state}
  end

  then_ ~r/^I should see the home page$/, fn state, _extra ->
    page_text = visible_page_text()
    assert String.contains?(page_text, "Phoenix Framework")
    {:ok, state}
  end

  then_ ~r/^I should see a login error$/, fn state, _extra ->
    page_text = visible_page_text()
    assert String.contains?(page_text, "Invalid email or password")
    {:ok, state}
  end

  given_ ~r/^I navigate to the delete account page$/, fn state, _ ->
    navigate_to("http://localhost:4002/users/delete")
    {:ok, state}
  end

  when_ ~r/^I submit deletion with a wrong password$/, fn state, _ ->
    fill_field({:css, "input[name='delete[password]']"}, "Wrong123!")
    click({:css, "input[name='delete[confirm]']"})
    submit_element({:id, "delete-account-form"})
    {:ok, state}
  end

  then_ ~r/^I should see a delete error$/, fn state, _ ->
    text = visible_page_text()
    assert String.contains?(text, "Invalid password") or String.contains?(text, "Please confirm")
    {:ok, state}
  end

  when_ ~r/^I submit deletion with the correct password$/, fn state, _ ->
    # state.password is set in the login step
    fill_field({:css, "input[name='delete[password]']"}, state.password)
    click({:css, "input[name='delete[confirm]']"})
    submit_element({:id, "delete-account-form"})
    {:ok, state}
  end
  # --- ADMIN CREATION (FR-02) ---

  given_ ~r/^I am logged in as an admin$/, fn state, _ ->
    {:ok, admin} =
      EarthScanner.Accounts.register_user(%{
        "username" => "bdd_admin",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Admin",
        "last_name" => "BDD",
        "email" => "bdd_admin@example.com",
        "birthdate" => "1990-01-01",
        "nationality" => "ID",
        "residence_address" => "Admin Street 1",
        "phone_number" => "+628111111111",
        "role" => "admin"
      })

    navigate_to("http://localhost:4002/users/login")

    fill_field({:css, "input[name='session[email]']"}, admin.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})

    {:ok, Map.put(state, :admin, admin)}
  end

  when_ ~r/^I visit the admin creation page$/, fn state, _ ->
    navigate_to("http://localhost:4002/admin/users/new")
    {:ok, state}
  end

  when_ ~r/^I fill the admin creation form with valid data$/, fn state, _ ->
    fill_field({:css, "input[name='user[username]']"}, "new_admin_bdd")
    fill_field({:css, "input[name='user[email]']"}, "new_admin_bdd@example.com")
    fill_field({:css, "input[name='user[phone_number]']"}, "+628222222222")
    fill_field({:css, "input[name='user[password]']"}, "Password123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "Password123!")
    {:ok, state}
  end

  when_ ~r/^I submit the admin creation form$/, fn state, _ ->
    submit_element({:css, "form"})
    {:ok, state}
  end

  when_ ~r/^I submit the admin creation form with incomplete data$/, fn state, _ ->
    fill_field({:css, "input[name='user[email]']"}, "")
    submit_element({:css, "form"})
    {:ok, state}
  end

  then_ ~r/^I should see an admin creation error$/, fn state, _ ->
    text = visible_page_text()
    assert String.contains?(text, "error") or String.contains?(text, "can't be blank")
    {:ok, state}
  end

  then_ ~r/^I should see a success message "([^"]+)"$/, fn state, %{matches: [message]} ->
    text = visible_page_text()
    assert String.contains?(text, message)
    {:ok, state}
  end

  # --- CHANGE PASSWORD (FR-05) ---

  given_ ~r/^I am logged in as a normal user$/, fn state, _ ->
    {:ok, user} =
      EarthScanner.Accounts.register_user(%{
        "username" => "bdd_user_pw",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "John",
        "last_name" => "Doe",
        "email" => "bdd_user_pw@example.com",
        "birthdate" => "1998-01-01",
        "nationality" => "ID",
        "residence_address" => "BDD Street",
        "phone_number" => "+628999999999"
      })

    navigate_to("http://localhost:4002/users/login")

    fill_field({:css, "input[name='session[email]']"}, user.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})

    {:ok, Map.put(state, :user, user)}
  end

  when_ ~r/^I visit the change password page$/, fn state, _ ->
    navigate_to("http://localhost:4002/users/change-password")
    {:ok, state}
  end

  when_ ~r/^I submit valid password change information$/, fn state, _ ->
    fill_field({:css, "input[name='current_password']"}, "Password123!")
    fill_field({:css, "input[name='new_password']"}, "NewPassword456!")
    fill_field({:css, "input[name='new_password_confirmation']"}, "NewPassword456!")
    submit_element({:css, "form"})
    {:ok, state}
  end

  when_ ~r/^I submit an invalid current password$/, fn state, _ ->
    fill_field({:css, "input[name='current_password']"}, "Wrong123!")
    fill_field({:css, "input[name='new_password']"}, "NewPassword456!")
    fill_field({:css, "input[name='new_password_confirmation']"}, "NewPassword456!")
    submit_element({:css, "form"})
    {:ok, state}
  end

  then_ ~r/^I should see "([^"]+)"$/, fn state, %{matches: [expected]} ->
    text = visible_page_text()
    assert String.contains?(text, expected)
    {:ok, state}
  end
end
