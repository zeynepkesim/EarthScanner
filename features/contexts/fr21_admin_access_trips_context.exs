defmodule FR21AdminAccessTripsContext do
  use WhiteBread.Context
  use Hound.Helpers

  @base "http://localhost:4002"

  alias EarthScanner.{Accounts, Repo}
  alias EarthScanner.Accounts.User
  alias EarthScanner.Trips.Trip

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, state ->
    Hound.end_session()
    {:ok, state}
  end

  ##########################################################################
  # GIVEN
  ##########################################################################

  given_ ~r/^I am logged in as an admin$/, fn state ->
    admin = ensure_admin()

    navigate_to(@base <> "/users/login")
    fill_field({:css, "input[name='session[email]']"}, admin.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})

    {:ok, Map.put(state, :admin, admin)}
  end

  given_ ~r/^I am on the login page$/, fn state ->
    navigate_to(@base <> "/users/login")
    {:ok, state}
  end

  given_ ~r/^a user exists$/, fn state ->
    user = create_regular_user()
    {:ok, Map.put(state, :user, user)}
  end

  given_ ~r/^a set of future trips exist$/, fn state ->
    admin = Map.get(state, :admin) || ensure_admin()
    insert_trip("Tartu", "Tallinn", +86_400, admin.id)
    {:ok, Map.put(state, :admin, admin)}
  end

  given_ ~r/^a set of past and future trips exist$/, fn state ->
    admin = Map.get(state, :admin) || ensure_admin()
    insert_trip("Tartu", "Riga", -86_400, admin.id)
    insert_trip("Tartu", "Riga", +86_400, admin.id)
    {:ok, Map.put(state, :admin, admin)}
  end

  ##########################################################################
  # WHEN
  ##########################################################################

  when_ ~r/^I visit "\/admin\/my-trips"$/, fn state ->
    navigate_to(@base <> "/admin/my-trips")
    {:ok, state}
  end

  when_ ~r/I visit "([^"]+)"/, fn state, %{matches: [path]} ->
    navigate_to(@base <> path)
    {:ok, state}
  end

  when_ ~r/^I submit correct login credentials$/, fn state ->
    user = Map.fetch!(state, :user)

    fill_field({:css, "input[name='session[email]']"}, user.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})

    {:ok, state}
  end

  ##########################################################################
  # THEN
  ##########################################################################

  then_ ~r/^I should see "Future Trips"$/, fn state ->
    assert visible_page_text() =~ "Future Trips"
    {:ok, state}
  end

  then_ ~r/^I should see "Past Trips"$/, fn state ->
    assert visible_page_text() =~ "Past Trips"
    {:ok, state}
  end

  then_ ~r/^I should see "([^"]+)"$/, fn state, %{matches: [text]} ->
    assert visible_page_text() =~ text
    {:ok, state}
  end

  then_ ~r/^I should see at least 1 trip in the results$/, fn state ->
    page = visible_page_text()
    assert String.contains?(page, "Tartu")
    {:ok, state}
  end

  then_ ~r/^I should be redirected back to the home page$/, fn state ->
    assert current_url() =~ @base <> "/"
    {:ok, state}
  end

  ##########################################################################
  # HELPERS
  ##########################################################################

  defp insert_trip(src, dst, offset_seconds, admin_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    t = DateTime.add(now, offset_seconds, :second)

    Repo.insert!(%Trip{
      source_city: src,
      destination_city: dst,
      departure_time: t,
      arrival_time: DateTime.add(t, 3600, :second),
      transport_mode: "bus",
      duration_minutes: 60,
      price: 25,
      co2_level: 100,
      available_tickets: 10,
      admin_id: admin_id
    })
  end

  defp create_regular_user do
    suffix = Integer.to_string(System.unique_integer([:positive]))

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "fr21_user_" <> suffix,
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "FR21",
        "last_name" => "User",
        "email" => "fr21_user_" <> suffix <> "@example.com",
        "birthdate" => "1995-05-05",
        "nationality" => "ID",
        "residence_address" => "BDD Street",
        "phone_number" => "+628888888888"
      })

    user
  end

  defp ensure_admin do
    case Accounts.get_user_by_email("admin_fr21@example.com") do
      %User{role: "admin"} = admin -> admin

      %User{} = user ->
        {:ok, admin} =
          user
          |> User.admin_changeset(%{
            username: user.username || "admin_fr21_" <> Integer.to_string(System.unique_integer([:positive])),
            password: "Password123!",
            password_confirmation: "Password123!",
            email: user.email,
            phone_number: user.phone_number || "+620000011111"
          })
          |> Repo.update()

        admin

      nil ->
        create_admin_with_retry(0)
    end
  end

  defp create_admin_with_retry(3), do: raise "Could not create admin_fr21 after retries"

  defp create_admin_with_retry(attempt) do
    suffix = Integer.to_string(System.unique_integer([:positive]))
    email = "admin_fr21" <> if attempt == 0, do: "@example.com", else: "_" <> suffix <> "@example.com"
    username = "admin_fr21_" <> suffix

    case Accounts.register_user(%{
           "username" => username,
           "password" => "Password123!",
           "password_confirmation" => "Password123!",
           "name" => "Admin",
           "last_name" => "FR21",
           "email" => email,
           "birthdate" => "1980-01-01",
           "nationality" => "ID",
           "residence_address" => "Test Street",
           "phone_number" => "+620000011111",
           "role" => "admin"
         }) do
      {:ok, admin} -> admin
      {:error, changeset} ->
        if Enum.any?(changeset.errors, fn {field, {msg, _}} -> field == :email and String.contains?(msg, "taken") end) do
          create_admin_with_retry(attempt + 1)
        else
          raise "Failed to create admin_fr21: #{inspect(changeset.errors)}"
        end
    end
  end
end
