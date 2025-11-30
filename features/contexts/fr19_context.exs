defmodule FR19Context do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Repo, Accounts}

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, _state ->
    Hound.end_session()
    :ok
  end

  # Given Steps

  given_ ~r/^I am not logged in$/, fn state, _ ->
    # Simply navigate to homepage without session - user is already not logged in
    {:ok, state}
  end

  given_ ~r/^I am logged in as a regular user$/, fn state, _ ->
    unique_id = :erlang.unique_integer([:positive])
    email = "bdd_user_#{unique_id}@example.com"
    username = "bdd_user_#{unique_id}"

    {:ok, user} = Accounts.register_user(%{
      "username" => username,
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "BDD",
      "last_name" => "User",
      "email" => email,
      "birthdate" => "1990-01-01",
      "nationality" => "US",
      "residence_address" => "123 Test St",
      "phone_number" => "+1234567890"
    })

    # Navigate to login page
    navigate_to("http://localhost:4002/users/login")
    :timer.sleep(500)

    # Fill in login form
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    :timer.sleep(500)

    # Submit login form
    submit_element({:id, "login-form"})
    :timer.sleep(1000)

    {:ok, Map.put(state, :user, user)}
  end

  # When Steps

  when_ ~r/^I visit the home page$/, fn state, _ ->
    navigate_to("http://localhost:4002/")
    :timer.sleep(500)
    {:ok, state}
  end

  # Then Steps

  then_ ~r/^I should see login and register options$/, fn state, _ ->
    page = visible_page_text()
    if String.contains?(page, "Log In") and String.contains?(page, "Register") do
      {:ok, state}
    else
      {:error, "Expected to see login and register options"}
    end
  end

  then_ ~r/^I should see profile and logout options$/, fn state, _ ->
    page = visible_page_text()
    if String.contains?(page, "Profile") and String.contains?(page, "Log out") do
      {:ok, state}
    else
      {:error, "Expected to see profile and logout options"}
    end
  end

  then_ ~r/^I should not see profile in header$/, fn state, _ ->
    page = visible_page_text()
    if not String.contains?(page, "Profile") do
      {:ok, state}
    else
      {:error, "Unexpected Profile link found in header"}
    end
  end

  then_ ~r/^I should not see logout in header$/, fn state, _ ->
    page = visible_page_text()
    if not String.contains?(page, "Log out") do
      {:ok, state}
    else
      {:error, "Unexpected logout button found in header"}
    end
  end

  then_ ~r/^account section shows correct options for authenticated users$/, fn state, _ ->
    page = visible_page_text()
    if String.contains?(page, "Account") and String.contains?(page, "Account Details") do
      {:ok, state}
    else
      {:error, "Expected Account section with Account Details for authenticated user"}
    end
  end

  then_ ~r/^the page loads successfully$/, fn state, _ ->
    current = current_url()
    if String.contains?(current, "localhost") or String.contains?(current, "127.0.0.1") do
      {:ok, state}
    else
      {:error, "Page failed to load properly"}
    end
  end
end
