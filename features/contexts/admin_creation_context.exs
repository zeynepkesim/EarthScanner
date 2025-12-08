defmodule AdminCreationContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Accounts, Repo}
  @base "http://localhost:4002"

  # ============================================================
  # SCENARIO SETUP / CLEANUP
  # ============================================================

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status ->
    Hound.end_session()
    :ok
  end

  # ============================================================
  # GIVEN
  # ============================================================

  given_ ~r/^I am logged in as an admin$/, fn state ->
    unique = System.unique_integer([:positive])
    email = "admin_creator_#{unique}@example.com"

    admin =
      case Accounts.get_user_by_email(email) do
        nil ->
          {:ok, user} =
            Accounts.register_user(%{
              "username" => "admin_#{unique}",
              "password" => "Password123!",
              "password_confirmation" => "Password123!",
              "name" => "Admin",
              "last_name" => "Creator",
              "email" => email,
              "birthdate" => "1990-01-01",
              "nationality" => "EE",
              "residence_address" => "Admin St",
              "phone_number" => "+372600000"
            })

          Repo.update!(Ecto.Changeset.change(user, role: "admin"))

        user -> user
      end

    navigate_to(@base <> "/users/login")
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})
    :timer.sleep(800)

    {:ok, Map.put(state, :admin, admin)}
  end

  # For regex steps with captures, WhiteBread uses this pattern:
  # The captured value becomes part of the step definition itself

  given_ ~r/^an admin with email "duplicate@example.com" exists$/, fn state ->
    email = "duplicate@example.com"

    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} =
          Accounts.register_user(%{
            "username" => "dup_admin",
            "password" => "Password123!",
            "password_confirmation" => "Password123!",
            "name" => "Existing",
            "last_name" => "Admin",
            "email" => email,
            "birthdate" => "1990-01-01",
            "nationality" => "EE",
            "residence_address" => "Test St",
            "phone_number" => "+372699999"
          })

        Repo.update!(Ecto.Changeset.change(user, role: "admin"))

      _ -> :ok
    end

    {:ok, state}
  end

  given_ ~r/^I am logged out$/, fn state ->
    try do
      # Try to find and click logout button/link
      elements = find_all_elements(:css, "a[href*='logout'], button[type='submit']")
      logout_elements = Enum.filter(elements, fn el ->
        try do
          text = inner_text(el) |> String.downcase()
          String.contains?(text, "log out") or String.contains?(text, "logout")
        rescue
          _ -> false
        end
      end)

      if length(logout_elements) > 0 do
        click(hd(logout_elements))
        :timer.sleep(500)
      end
    rescue
      _ -> :ok
    end

    {:ok, state}
  end

  given_ ~r/^I am logged in as a regular user$/, fn state ->
    unique = System.unique_integer([:positive])
    email = "regular_#{unique}@example.com"

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "regular_#{unique}",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Regular",
        "last_name" => "User",
        "email" => email,
        "birthdate" => "1995-01-01",
        "nationality" => "EE",
        "residence_address" => "User St",
        "phone_number" => "+372688888"
      })

    navigate_to(@base <> "/users/login")
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})
    :timer.sleep(800)

    {:ok, Map.put(state, :regular_user, user)}
  end

  # ============================================================
  # WHEN
  # ============================================================

  when_ ~r/^I visit the admin creation page$/, fn state ->
    navigate_to(@base <> "/admin/users/new")
    :timer.sleep(600)
    {:ok, state}
  end

  when_ ~r/^I fill the admin creation form with valid data$/, fn state ->
    unique = System.unique_integer([:positive])
    email = "newadmin#{unique}@example.com"

    fill_field({:css, "input[name='user[username]']"}, "newadmin#{unique}")
    fill_field({:css, "input[name='user[email]']"}, email)
    fill_field({:css, "input[name='user[password]']"}, "AdminPass123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "AdminPass123!")
    fill_field({:css, "input[name='user[phone_number]']"}, "+372611111")

    {:ok, Map.merge(state, %{new_admin_email: email, new_admin_password: "AdminPass123!"})}
  end

  when_ ~r/^I submit the admin creation form$/, fn state ->
    submit_element({:css, "button[type='submit']"})
    :timer.sleep(1000)
    {:ok, state}
  end

  # Errors / negative cases

  when_ ~r/^I leave the username field empty$/, fn state ->
    unique = System.unique_integer([:positive])
    # Fill other required fields
    fill_field({:css, "input[name='user[email]']"}, "test#{unique}@example.com")
    fill_field({:css, "input[name='user[password]']"}, "Password123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "Password123!")
    fill_field({:css, "input[name='user[phone_number]']"}, "+372611111")
    # Leave username empty
    fill_field({:css, "input[name='user[username]']"}, "")
    {:ok, state}
  end

  when_ ~r/^I leave the email field empty$/, fn state ->
    unique = System.unique_integer([:positive])
    fill_field({:css, "input[name='user[username]']"}, "testuser#{unique}")
    fill_field({:css, "input[name='user[password]']"}, "Password123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "Password123!")
    fill_field({:css, "input[name='user[phone_number]']"}, "+372611111")
    fill_field({:css, "input[name='user[email]']"}, "")
    {:ok, state}
  end

  when_ ~r/^I enter an invalid email format$/, fn state ->
    unique = System.unique_integer([:positive])
    fill_field({:css, "input[name='user[username]']"}, "testuser#{unique}")
    fill_field({:css, "input[name='user[email]']"}, "invalid-email")
    fill_field({:css, "input[name='user[password]']"}, "Password123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "Password123!")
    fill_field({:css, "input[name='user[phone_number]']"}, "+372611111")
    {:ok, state}
  end

  when_ ~r/^I try to create admin with email "duplicate@example.com"$/, fn state ->
    email = "duplicate@example.com"
    unique = System.unique_integer([:positive])

    fill_field({:css, "input[name='user[username]']"}, "testuser#{unique}")
    fill_field({:css, "input[name='user[email]']"}, email)
    fill_field({:css, "input[name='user[password]']"}, "Password123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "Password123!")
    fill_field({:css, "input[name='user[phone_number]']"}, "+372611111")

    {:ok, Map.put(state, :duplicate_email, email)}
  end

  when_ ~r/^I enter a password shorter than 8 characters$/, fn state ->
    unique = System.unique_integer([:positive])
    fill_field({:css, "input[name='user[username]']"}, "testuser#{unique}")
    fill_field({:css, "input[name='user[email]']"}, "test#{unique}@example.com")
    fill_field({:css, "input[name='user[phone_number]']"}, "+372611111")
    fill_field({:css, "input[name='user[password]']"}, "Short1!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "Short1!")
    {:ok, state}
  end

  when_ ~r/^I enter mismatched password confirmation$/, fn state ->
    unique = System.unique_integer([:positive])
    fill_field({:css, "input[name='user[username]']"}, "testuser#{unique}")
    fill_field({:css, "input[name='user[email]']"}, "test#{unique}@example.com")
    fill_field({:css, "input[name='user[phone_number]']"}, "+372611111")
    fill_field({:css, "input[name='user[password]']"}, "Password123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "WrongPass!")
    {:ok, state}
  end

  when_ ~r/^I try to visit the admin creation page$/, fn state ->
    navigate_to(@base <> "/admin/users/new")
    :timer.sleep(800)
    {:ok, state}
  end

  when_ ~r/^I try to create an admin via direct API call$/, fn state ->
    # This simulates trying to POST without proper authorization
    # In a real scenario, we'd check if the page prevents this
    {:ok, Map.put(state, :api_call_attempted, true)}
  end

  # ============================================================
  # THEN - All with hardcoded values from feature file
  # ============================================================

  then_ ~r/^I should see a success message "Admin created successfully"$/, fn state ->
    :timer.sleep(800)

    page = visible_page_text() |> String.downcase()

    has_success = String.contains?(page, "admin created successfully") or
                  String.contains?(page, "admin created")

    assert has_success,
           "Expected success message 'Admin created successfully' but page contains: #{String.slice(page, 0, 300)}"

    {:ok, state}
  end

  then_ ~r/^the new admin should be able to log in$/, fn state ->
    # Logout current user
    try do
      elements = find_all_elements(:css, "a[href*='logout'], button[type='submit']")
      logout_elements = Enum.filter(elements, fn el ->
        try do
          text = inner_text(el) |> String.downcase()
          String.contains?(text, "log out") or String.contains?(text, "logout")
        rescue
          _ -> false
        end
      end)

      if length(logout_elements) > 0 do
        click(hd(logout_elements))
        :timer.sleep(500)
      end
    rescue
      _ -> :ok
    end

    # Try to login with new admin
    if Map.has_key?(state, :new_admin_email) do
      navigate_to(@base <> "/users/login")
      :timer.sleep(500)

      fill_field({:css, "input[name='session[email]']"}, state.new_admin_email)
      fill_field({:css, "input[name='session[password]']"}, state.new_admin_password)
      submit_element({:id, "login-form"})
      :timer.sleep(1000)

      # Verify login was successful (should not see login form)
      current = current_url()
      assert current != @base <> "/users/login",
             "New admin should be able to log in but stuck at: #{current}"
    end

    {:ok, state}
  end

  then_ ~r/^I should see an admin creation error$/, fn state ->
    :timer.sleep(800)
    page = visible_page_text() |> String.downcase()

    has_error = String.contains?(page, "can't be blank") or
                String.contains?(page, "already been taken") or
                String.contains?(page, "has already been taken") or
                String.contains?(page, "should be at least") or
                String.contains?(page, "must be at least") or
                String.contains?(page, "invalid") or
                String.contains?(page, "does not match") or
                String.contains?(page, "not allowed") or
                String.contains?(page, "error") or
                String.contains?(page, "problem")

    assert has_error, "Expected validation error but page contains: #{String.slice(page, 0, 300)}"

    {:ok, state}
  end

  # Create separate step definitions for each specific text check
  then_ ~r/^I should see "can't be blank"$/, fn state ->
    :timer.sleep(800)
    page = visible_page_text() |> String.downcase()

    assert String.contains?(page, "can't be blank"),
           "Expected to see \"can't be blank\" but page contains: #{String.slice(page, 0, 300)}"

    {:ok, state}
  end

  then_ ~r/^I should see "has already been taken"$/, fn state ->
    :timer.sleep(800)
    page = visible_page_text() |> String.downcase()

    assert String.contains?(page, "has already been taken") or String.contains?(page, "already been taken"),
           "Expected to see \"has already been taken\" but page contains: #{String.slice(page, 0, 300)}"

    {:ok, state}
  end

  then_ ~r/^I should see "does not match"$/, fn state ->
    :timer.sleep(800)
    page = visible_page_text() |> String.downcase()

    assert String.contains?(page, "does not match") or String.contains?(page, "doesn't match"),
           "Expected to see \"does not match\" but page contains: #{String.slice(page, 0, 300)}"

    {:ok, state}
  end

  then_ ~r/^I should see "Not allowed."$/, fn state ->
    :timer.sleep(800)
    page = visible_page_text() |> String.downcase()

    assert String.contains?(page, "not allowed") or
           String.contains?(page, "not authorized") or
           String.contains?(page, "you are not authorized"),
           "Expected to see \"Not allowed\" but page contains: #{String.slice(page, 0, 300)}"

    {:ok, state}
  end

  then_ ~r/^I should be redirected to the home page$/, fn state ->
    :timer.sleep(800)
    current = current_url()

    is_home = current == @base <> "/" or
              String.ends_with?(current, "/") or
              current == @base

    assert is_home, "Expected redirect to home but got: #{current}"

    {:ok, state}
  end

  then_ ~r/^the request should be unauthorized$/, fn state ->
    :timer.sleep(800)

    # Check if we're still at admin creation page or got redirected
    current = current_url()
    page = visible_page_text() |> String.downcase()

    # Should either be redirected away OR see an unauthorized message
    not_allowed = not String.contains?(current, "/admin/users/new") or
                  String.contains?(page, "not authorized") or
                  String.contains?(page, "not allowed") or
                  String.contains?(page, "unauthorized")

    assert not_allowed,
           "Expected unauthorized/redirect but at: #{current} with content: #{String.slice(page, 0, 200)}"

    {:ok, state}
  end
end
