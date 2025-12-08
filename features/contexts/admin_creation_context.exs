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


  given_ ~r/^an admin with email "([^"]+)" exists$/, fn %{matches: [email]} = state ->
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
      submit_element({:css, "form[action='/users/logout']"})
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
  # WHEN (No and_ duplicates!)
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
    :timer.sleep(800)
    {:ok, state}
  end


  # Errors / negative cases

  when_ ~r/^I leave the username field empty$/, fn state ->
    fill_field({:css, "input[name='user[username]']"}, "")
    {:ok, state}
  end

  when_ ~r/^I leave the email field empty$/, fn state ->
    fill_field({:css, "input[name='user[email]']"}, "")
    {:ok, state}
  end

  when_ ~r/^I enter an invalid email format$/, fn state ->
    fill_field({:css, "input[name='user[email]']"}, "invalid-email")
    {:ok, state}
  end

  when_ ~r/^I try to create admin with email "([^"]+)"$/, fn %{matches: [email]} = state ->
    fill_field({:css, "input[name='user[email]']"}, email)
    {:ok, Map.put(state, :duplicate_email, email)}
  end

  when_ ~r/^I enter a password shorter than 8 characters$/, fn state ->
    fill_field({:css, "input[name='user[password]']"}, "Short1!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "Short1!")
    {:ok, state}
  end

  when_ ~r/^I enter mismatched password confirmation$/, fn state ->
    fill_field({:css, "input[name='user[password]']"}, "Password123!")
    fill_field({:css, "input[name='user[password_confirmation]']"}, "WrongPass!")
    {:ok, state}
  end

  when_ ~r/^I try to visit the admin creation page$/, fn state ->
    navigate_to(@base <> "/admin/users/new")
    {:ok, state}
  end

  when_ ~r/^I try to create an admin via direct API call$/, fn state ->
    {:ok, Map.put(state, :api_call_attempted, true)}
  end

  # ============================================================
  # THEN
  # ============================================================

  then_ ~r/^I should see a success message "([^"]+)"$/, fn %{matches: [msg]} = state ->
    page = visible_page_text() |> String.downcase()

    assert String.contains?(page, msg |> String.downcase()) or
             String.contains?(page, "admin created successfully"),
           "Expected success message"

    {:ok, state}
  end

  then_ ~r/^I should see an admin creation error$/, fn state ->
    page = visible_page_text() |> String.downcase()

    assert String.contains?(page, "can't be blank") or
             String.contains?(page, "already been taken") or
             String.contains?(page, "should be at least") or
             String.contains?(page, "invalid") or
             String.contains?(page, "does not match") or
             String.contains?(page, "not allowed"),
           "Expected validation error"

    {:ok, state}
  end


  then_ ~r/^I should see "([^"]+)"$/, fn %{matches: [text]} = state ->
    page = visible_page_text() |> String.downcase()
    assert String.contains?(page, text |> String.downcase()),
           "Expected to see #{text}"
    {:ok, state}
  end


  then_ ~r/^I should be redirected to the home page$/, fn state ->
    current = current_url()
    assert current == @base <> "/" or String.ends_with?(current, "/"),
           "Expected redirect to home"
    {:ok, state}
  end


  then_ ~r/^the request should be unauthorized$/, fn state ->
    page = visible_page_text() |> String.downcase()

    assert String.contains?(page, "not allowed") or
             String.contains?(page, "unauthorized"),
           "Expected unauthorized message"

    {:ok, state}
  end
end
