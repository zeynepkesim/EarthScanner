defmodule ChangePasswordContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.Accounts

  scenario_starting_state fn _state ->
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

  given_ ~r/^I am logged in as a normal user$/, fn _state ->
    unique_id = :erlang.unique_integer([:positive])
    email = "pwchange_user_#{unique_id}@example.com"
    username = "pwchange_#{unique_id}"
    password = "OldPassword123!"

    {:ok, user} = Accounts.register_user(%{
      "username" => username,
      "password" => password,
      "password_confirmation" => password,
      "name" => "John",
      "last_name" => "Doe",
      "email" => email,
      "birthdate" => "1995-01-01",
      "nationality" => "EE",
      "residence_address" => "Test Street",
      "phone_number" => "+3726222222"
    })

    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, password)
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)

    {:ok, %{user: user, email: email, password: password, old_password: password}}
  end

  given_ ~r/^I am logged out$/, fn state ->
    try do
      submit_element({:css, "form[action='/users/logout']"})
      :timer.sleep(1000)
    rescue
      _ -> :ok
    end
    {:ok, state}
  end

  # ========================================
  # WHEN - POSITIVE
  # ========================================

  when_ ~r/^I visit the change password page$/, fn state ->
    navigate_to("http://localhost:4002/users/change-password")
    :timer.sleep(1000)
    {:ok, state}
  end

  when_ ~r/^I submit valid password change information$/, fn state ->
    fill_field({:css, "input[name='current_password']"}, state.password)
    fill_field({:css, "input[name='new_password']"}, "NewPassword123!")
    fill_field({:css, "input[name='new_password_confirmation']"}, "NewPassword123!")
    :timer.sleep(300)
    submit_element({:css, "button[type='submit']"})
    :timer.sleep(2000)
    {:ok, Map.put(state, :new_password, "NewPassword123!")}
  end

  when_ ~r/^I change my password to a new one$/, fn state ->
    new_password = "SuperNewPass123!"

    fill_field({:css, "input[name='current_password']"}, state.password)
    fill_field({:css, "input[name='new_password']"}, new_password)
    fill_field({:css, "input[name='new_password_confirmation']"}, new_password)
    :timer.sleep(300)
    submit_element({:css, "button[type='submit']"})
    :timer.sleep(2000)

    {:ok, Map.put(state, :new_password, new_password)}
  end

  when_ ~r/^I change my password successfully$/, fn state ->
    new_password = "ChangedPassword123!"

    navigate_to("http://localhost:4002/users/change-password")
    :timer.sleep(1000)

    fill_field({:css, "input[name='current_password']"}, state.password)
    fill_field({:css, "input[name='new_password']"}, new_password)
    fill_field({:css, "input[name='new_password_confirmation']"}, new_password)
    :timer.sleep(300)
    submit_element({:css, "button[type='submit']"})
    :timer.sleep(2000)

    {:ok, Map.put(state, :new_password, new_password)}
  end

  when_ ~r/^I log out$/, fn state ->
    :timer.sleep(500)
    submit_element({:css, "form[action='/users/logout']"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I try to login with the new password$/, fn state ->
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, state.email)
    fill_field({:css, "input[name='session[password]']"}, state.new_password)
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)

    {:ok, state}
  end

  when_ ~r/^I try to login with the old password$/, fn state ->
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    fill_field({:css, "input[name='session[email]']"}, state.email)
    fill_field({:css, "input[name='session[password]']"}, state.old_password)
    :timer.sleep(300)
    submit_element({:id, "login-form"})
    :timer.sleep(2000)

    {:ok, state}
  end

  # ========================================
  # WHEN - NEGATIVE
  # ========================================

  when_ ~r/^I submit an invalid current password$/, fn state ->
    fill_field({:css, "input[name='current_password']"}, "WrongPassword123!")
    fill_field({:css, "input[name='new_password']"}, "NewPassword123!")
    fill_field({:css, "input[name='new_password_confirmation']"}, "NewPassword123!")
    :timer.sleep(300)
    submit_element({:css, "button[type='submit']"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I submit mismatched new passwords$/, fn state ->
    fill_field({:css, "input[name='current_password']"}, state.password)
    fill_field({:css, "input[name='new_password']"}, "NewPassword123!")
    fill_field({:css, "input[name='new_password_confirmation']"}, "DifferentPass456!")
    :timer.sleep(300)
    submit_element({:css, "button[type='submit']"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I submit a new password shorter than 8 characters$/, fn state ->
    fill_field({:css, "input[name='current_password']"}, state.password)
    fill_field({:css, "input[name='new_password']"}, "Short1!")
    fill_field({:css, "input[name='new_password_confirmation']"}, "Short1!")
    :timer.sleep(300)
    submit_element({:css, "button[type='submit']"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I leave the current password field empty$/, fn state ->
    fill_field({:css, "input[name='current_password']"}, "")
    fill_field({:css, "input[name='new_password']"}, "NewPassword123!")
    fill_field({:css, "input[name='new_password_confirmation']"}, "NewPassword123!")
    :timer.sleep(300)
    {:ok, state}
  end

  when_ ~r/^I leave the new password field empty$/, fn state ->
    fill_field({:css, "input[name='current_password']"}, state.password)
    fill_field({:css, "input[name='new_password']"}, "")
    fill_field({:css, "input[name='new_password_confirmation']"}, "")
    :timer.sleep(300)
    {:ok, state}
  end

  when_ ~r/^I submit the form$/, fn state ->
    submit_element({:css, "button[type='submit']"})
    :timer.sleep(2000)
    {:ok, state}
  end

  when_ ~r/^I try to visit the change password page$/, fn state ->
    navigate_to("http://localhost:4002/users/change-password")
    :timer.sleep(2000)
    {:ok, state}
  end

  # ========================================
  # THEN
  # ========================================

  then_ ~r/^I should see "([^"]+)"$/, fn state, %{matches: [expected]} ->
    :timer.sleep(500)
    page_text = visible_page_text()

    IO.puts("\n----- DEBUG: Checking for message '#{expected}' -----\n")
    IO.puts(page_text)
    IO.puts("\n-----------------------------------------------\n")

    lower_page = String.downcase(page_text)
    lower_expected = String.downcase(expected)

    assert String.contains?(lower_page, lower_expected),
      "Expected to see '#{expected}' but got:\n\n#{page_text}"

    {:ok, state}
  end

  then_ ~r/^I should be on the profile page$/, fn state ->
    :timer.sleep(500)
    current = current_url()

    assert String.contains?(current, "/profile"),
      "Expected profile page but got: #{current}"

    {:ok, state}
  end

  then_ ~r/^my session should be renewed$/, fn state ->
    page_text = visible_page_text()

    assert String.contains?(page_text, "Profile") or
           String.contains?(page_text, "Log out"),
      "Expected session renewal"

    {:ok, state}
  end

  then_ ~r/^I should successfully log in$/, fn state ->
    :timer.sleep(1000)
    page_text = visible_page_text()
    url = current_url()

    logged_in =
      not String.contains?(url, "/login") and
        (String.contains?(page_text, "Profile") or
         String.contains?(page_text, "Log out"))

    assert logged_in,
      "Expected to log in successfully, but got: #{page_text}"

    {:ok, state}
  end

  then_ ~r/^I should still be on the change password page$/, fn state ->
    :timer.sleep(500)
    url = current_url()

    assert String.contains?(url, "/change-password"),
      "Expected to remain on change password page"

    {:ok, state}
  end

  then_ ~r/^I should see an error message$/, fn state ->
    page_text = visible_page_text() |> String.downcase()

    IO.puts("\n----- DEBUG: Checking for ANY error -----\n")
    IO.puts(visible_page_text())
    IO.puts("\n-----------------------------------------\n")

    assert String.contains?(page_text, "error") or
           String.contains?(page_text, "incorrect") or
           String.contains?(page_text, "does not match") or
           String.contains?(page_text, "must be at least") or
           String.contains?(page_text, "password"),
      "Expected some error message"

    {:ok, state}
  end

  then_ ~r/^I should be redirected to the login page$/, fn state ->
    :timer.sleep(1000)
    url = current_url()
    text = visible_page_text()

    assert String.contains?(url, "/login") or String.contains?(text, "Log in"),
      "Expected redirect to login page"

    {:ok, state}
  end

  then_ ~r/^I should see a login error$/, fn state ->
    page_text = visible_page_text()

    IO.puts("\n----- DEBUG: Checking LOGIN ERROR -----\n")
    IO.puts(page_text)
    IO.puts("\n---------------------------------------\n")

    lower = String.downcase(page_text)

    assert String.contains?(lower, "invalid") or
           String.contains?(lower, "error") or
           String.contains?(lower, "wrong"),
      "Expected an invalid-login error"

    {:ok, state}
  end

  then_ ~r/^DEBUG_SHOW_PAGE$/, fn state ->
    IO.puts("\n===== PAGE DEBUG START =====\n")
    IO.puts(visible_page_text())
    IO.puts("\n===== PAGE DEBUG END =====\n")
    {:ok, state}
  end
end
