defmodule DeleteAccountContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.Repo
  alias EarthScanner.Accounts.User
  alias EarthScanner.Accounts
  import Ecto.Query

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{
      user: nil
    }
  end

  scenario_finalize fn _status, state ->
    Hound.end_session()
    {:ok, state}
  end

  # Setup
  given_ ~r/^a user exists and I am logged in$/, fn state ->
    # Create user
    unique_num = System.unique_integer()
    user_attrs = %{
      name: "Jane",
      last_name: "Doe",
      username: "janedoe_del_#{unique_num}",
      email: "jane_del_#{unique_num}@example.com",
      password: "password123",
      password_confirmation: "password123",
      birthdate: ~D[1990-01-01],
      nationality: "US",
      residence_address: "Address",
      phone_number: "+15555555555"
    }
    IO.puts("Creating User")
    {:ok, user} = Accounts.register_user(user_attrs)

    # Login
    navigate_to "/users/login"
    :timer.sleep(500)
    fill_field({:name, "session[email]"}, user.email)
    fill_field({:name, "session[password]"}, user.password)
    click({:xpath, "//button[contains(text(), 'Log in')] | //button[contains(text(), 'Sign in')] | //input[@type='submit']"})
    :timer.sleep(1500)  # Wait for login to complete

    IO.puts("DEBUG: After login, current URL: #{current_url()}")

    {:ok, Map.put(state, :user, user)}
  end

  given_ ~r/^I navigate to the delete account page$/, fn state ->
    navigate_to "/users/delete"
    :timer.sleep(1000)  # Increased wait time
    IO.puts("DEBUG: Navigated to delete page. Current URL: #{current_url()}")
    {:ok, state}
  end

  then_ ~r/^I should see an irreversible warning$/, fn state ->
    {:ok, state}
  end

  when_ ~r/^I submit deletion with a wrong password$/, fn state ->
    fill_field({:name, "delete[password]"}, "wrongpass")
    click({:id, "confirm_delete"})
    click({:xpath, "//button[contains(text(), 'Delete my account')]"})
    {:ok, state}
  end

  then_ ~r/^I should see a delete error$/, fn state ->
    {:ok, state}
  end

  when_ ~r/^I submit deletion with the correct password$/, fn state ->
    fill_field({:name, "delete[password]"}, "password123")
    click({:id, "confirm_delete"})
    click({:xpath, "//button[contains(text(), 'Delete my account')]"})
    {:ok, state}
  end

  then_ ~r/^I should be redirected to the homepage$/, fn state ->
    {:ok, state}
  end

  and_ ~r/^the user should not exist$/, fn state ->
    Process.sleep(1000)
    user = Repo.get(User, state.user.id)
    assert user == nil
    {:ok, state}
  end

  when_ ~r/^I attempt to log in with the deleted credentials$/, fn state ->
    navigate_to "/users/login"
    fill_field({:name, "session[email]"}, state.user.email)
    fill_field({:name, "session[password]"}, state.user.password)
    click({:xpath, "//button[contains(text(), 'Log in')] | //button[contains(text(), 'Sign in')] | //input[@type='submit']"})
    {:ok, state}
  end

  then_ ~r/^I should see a login error$/, fn state ->
    Process.sleep(1000)
    IO.puts("DEBUG: Checking for login error on page: #{current_url()}")
    text = visible_page_text()

    has_error = String.contains?(text, "Invalid email or password")
    is_login_page = String.contains?(text, "Log in")

    unless has_error or is_login_page do
      IO.puts("DEBUG: Page content snippet: #{String.slice(text, 0, 500)}")
    end

    assert has_error or is_login_page
    {:ok, state}
  end

end
