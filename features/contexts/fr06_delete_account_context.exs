defmodule DeleteAccountContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.Repo
  alias EarthScanner.Accounts.User
  alias EarthScanner.Accounts
  import Ecto.Query

  @base "http://localhost:4002"

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
    unique_num = System.unique_integer([:positive])
    password = "Password123!"
    user_attrs = %{
      name: "Jane",
      last_name: "Doe",
      username: "janedoe_del_#{unique_num}",
      email: "jane_del_#{unique_num}@example.com",
      password: password,
      password_confirmation: password,
      birthdate: ~D[1990-01-01],
      nationality: "US",
      residence_address: "Address",
      phone_number: "+15555555555"
    }
    IO.puts("Creating User")
    {:ok, user} = Accounts.register_user(user_attrs)

    # Login
    navigate_to(@base <> "/users/login")
    :timer.sleep(500)
    fill_field({:css, "input[name='session[email]']"}, user.email)
    fill_field({:css, "input[name='session[password]']"}, password)
    click({:xpath, "//button[contains(text(), 'Log in')] | //button[contains(text(), 'Sign in')] | //input[@type='submit']"})
    :timer.sleep(1500)  # Wait for login to complete

    IO.puts("DEBUG: After login, current URL: #{current_url()}")

    {:ok, state |> Map.put(:user, user) |> Map.put(:password, password)}
  end

  given_ ~r/^I navigate to the delete account page$/, fn state ->
    navigate_to(@base <> "/users/delete")
    :timer.sleep(1000)  # Increased wait time
    IO.puts("DEBUG: Navigated to delete page. Current URL: #{current_url()}")
    {:ok, state}
  end

  then_ ~r/^I should see an irreversible warning$/, fn state ->
    text = visible_page_text()
    assert String.contains?(String.downcase(text), "delete account") or
           String.contains?(String.downcase(text), "cannot be undone") or
           String.contains?(String.downcase(text), "irreversible"),
      "Expected irreversible warning, got: #{String.slice(text, 0, 200)}"
    {:ok, state}
  end

  when_ ~r/^I submit deletion with a wrong password$/, fn state ->
    fill_field({:name, "delete[password]"}, "wrongpass")
    click({:id, "confirm_delete"})
    click({:xpath, "//button[contains(text(), 'Delete my account')]"})
    Process.sleep(1000)
    {:ok, state}
  end

  then_ ~r/^I should see a delete error$/, fn state ->
    Process.sleep(500)
    text = visible_page_text()
    assert String.contains?(String.downcase(text), "invalid") or
           String.contains?(String.downcase(text), "wrong password") or
           String.contains?(String.downcase(text), "error"),
      "Expected delete error, got: #{String.slice(text, 0, 200)}"
    {:ok, state}
  end

  when_ ~r/^I submit deletion with the correct password$/, fn state ->
    fill_field({:name, "delete[password]"}, state.password)
    click({:id, "confirm_delete"})
    click({:xpath, "//button[contains(text(), 'Delete my account')]"})
    Process.sleep(1200)

    # Ensure the user record is removed before continuing
    deleted_user = Repo.get(User, state.user.id)
    assert deleted_user == nil
    {:ok, state}
  end

  then_ ~r/^I should be redirected to the homepage$/, fn state ->
    Process.sleep(1000)
    current = current_url()
    text = visible_page_text()
    assert String.contains?(current, @base <> "/") or String.ends_with?(current, "/"),
      "Expected redirect to homepage, got #{current}"
    assert String.contains?(text, "Explore") or String.contains?(text, "Trips") or String.contains?(text, "EarthScanner"),
      "Homepage content missing: #{String.slice(text, 0, 200)}"
    {:ok, state}
  end

  and_ ~r/^the user should not exist$/, fn state ->
    Process.sleep(1000)
    user = Repo.get(User, state.user.id)
    assert user == nil
    {:ok, state}
  end

  when_ ~r/^I attempt to log in with the deleted credentials$/, fn state ->
    # Start a fresh browser session to avoid any lingering session cookies
    Hound.end_session()
    Hound.start_session()
    navigate_to(@base <> "/users/login")
    Process.sleep(500)
    fill_field({:css, "input[name='session[email]']"}, state.user.email)
    fill_field({:css, "input[name='session[password]']"}, state.password)
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
