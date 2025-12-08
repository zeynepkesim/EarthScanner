defmodule FR20RegularUserTripSearchContext do
  use WhiteBread.Context
  use Hound.Helpers

  @base "http://localhost:4002"

  alias EarthScanner.{Accounts, Repo, Trips}
  alias EarthScanner.Accounts.User

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

  given_ ~r/^a user exists$/, fn _ ->
    {:ok, user} = create_unique_user()
    {:ok, %{email: user.email, password: "Password123!", user: user}}
  end

  given_ ~r/^I am a visitor$/, fn state ->
    {:ok, state}
  end

  given_ ~r/^I am logged in as an admin$/, fn state ->
    admin = ensure_admin()

    navigate_to(@base <> "/users/login")
    fill_field({:css, "input[name='session[email]']"}, admin.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})

    {:ok, Map.put(state, :admin, admin)}
  end

  given_ ~r/^a set of future trips exist$/, fn state ->
    insert_future_trips()
    {:ok, state}
  end

  given_ ~r/^a set of future trips with various attributes exist$/, fn state ->
    insert_varied_future_trips()
    {:ok, state}
  end

  given_ ~r/^I am on the login page$/, fn state ->
    navigate_to(@base <> "/users/login")
    {:ok, state}
  end

  given_ ~r/^I am logged in as a regular user$/, fn state ->
    {:ok, user} = create_unique_user()

    navigate_to(@base <> "/users/login")
    fill_field({:css, "input[name='session[email]']"}, user.email)
    fill_field({:css, "input[name='session[password]']"}, "Password123!")
    submit_element({:id, "login-form"})

    {:ok, Map.put(state, :user, user)}
  end

  ##########################################################################
  # WHEN
  ##########################################################################

  when_ ~r/^I submit correct login credentials$/, fn state ->
    fill_field({:css, "input[name='session[email]']"}, state.email)
    fill_field({:css, "input[name='session[password]']"}, state.password)
    submit_element({:id, "login-form"})
    {:ok, state}
  end

  when_ ~r/^I visit the homepage$/, fn state ->
    navigate_to(@base <> "/")
    {:ok, state}
  end

  when_ ~r/^I search for trips from "(?<source>[^"]*)" to "(?<destination>[^"]*)"$/, fn state, %{source: src, destination: dst} ->
    navigate_to(@base <> "/search/results?" <> URI.encode_query(%{"source" => src, "destination" => dst}))
    {:ok, state}
  end

  when_ ~r/^I search for trips from "" to "(?<destination>[^"]+)"$/, fn state, %{destination: dst} ->
    navigate_to(@base <> "/search/results?" <> URI.encode_query(%{"source" => "", "destination" => dst}))
    {:ok, state}
  end

  when_ ~r/^I search for trips with special characters in source$/, fn state ->
    params = %{"source" => "T@rtu!", "destination" => "Tallinn"}
    navigate_to(@base <> "/search/results?" <> URI.encode_query(params))
    {:ok, state}
  end

  ##########################################################################
  # THEN
  ##########################################################################

  then_ ~r/^I should see a Phoenix welcome message$/, fn state ->
    text = visible_page_text()
    assert String.contains?(text, "Phoenix") or String.contains?(text, "EarthScanner") or
             String.contains?(text, "Welcome")
    {:ok, state}
  end

  then_ ~r/^I should see the search box on the homepage$/, fn state ->
    html = visible_page_text()
    assert String.contains?(html, "Search") or String.contains?(html, "source")
    {:ok, state}
  end

  then_ ~r/^I should not see the search box on the homepage$/, fn state ->
    html = visible_page_text()
    refute String.contains?(html, "Search")
    {:ok, state}
  end

  then_ ~r/^I should see at least 1 trip in the results$/, fn state ->
    assert visible_page_text() =~ "Mode:"
    {:ok, state}
  end

  then_ ~r/^I should be redirected back to the search page$/, fn state ->
    assert String.ends_with?(current_url(), "/search")
    {:ok, state}
  end

  then_ ~r/^I should not be able to access search results$/, fn state ->
    navigate_to(@base <> "/search/results?" <> URI.encode_query(%{"source" => "Tartu", "destination" => "Tallinn"}))
    :timer.sleep(500)

    current = current_url()
    page = visible_page_text()

    assert not String.contains?(current, "/search/results")

    assert String.contains?(page, "Admins cannot search trips") or
             String.contains?(page, "Please log in") or
             String.contains?(page, "Phoenix")

    {:ok, state}
  end

  then_ ~r/^the search should handle it gracefully without errors$/, fn state ->
    page = visible_page_text()
    refute String.contains?(page, "error")
    {:ok, state}
  end

  ##########################################################################
  # HELPERS
  ##########################################################################

  defp create_unique_user(attempts \\ 0)

  defp create_unique_user(3) do
    {:error, :could_not_create_user}
  end

  defp create_unique_user(attempts) do
    suffix = Integer.to_string(System.unique_integer([:positive]))
    email = "fr20_" <> suffix <> "@example.com"

    case Accounts.register_user(%{
           "username" => "fr20_u_" <> suffix,
           "password" => "Password123!",
           "password_confirmation" => "Password123!",
           "name" => "Test",
           "last_name" => "User",
           "email" => email,
           "birthdate" => "1999-01-01",
           "nationality" => "ID",
           "residence_address" => "Some St",
           "phone_number" => "+620000005555"
         }) do
      {:ok, user} -> {:ok, user}

      {:error, changeset} ->
        if Enum.any?(changeset.errors, fn {field, {msg, _}} -> field == :email and String.contains?(msg, "taken") end) do
          create_unique_user(attempts + 1)
        else
          {:error, changeset}
        end
    end
  end

  defp ensure_admin do
    case Accounts.get_user_by_email("fr20_admin@example.com") do
      %User{role: "admin"} = user ->
        user

      %User{} = user ->
        {:ok, updated} =
          user
          |> User.admin_changeset(%{
            username: user.username || "fr20_admin_" <> Integer.to_string(System.unique_integer([:positive])),
            password: "Password123!",
            password_confirmation: "Password123!",
            email: user.email,
            phone_number: user.phone_number || "+620000004444"
          })
          |> Repo.update()

        updated

      nil ->
        {:ok, admin} =
          %User{}
          |> User.admin_changeset(%{
            username: "fr20_admin_" <> Integer.to_string(System.unique_integer([:positive])),
            password: "Password123!",
            password_confirmation: "Password123!",
            email: "fr20_admin@example.com",
            phone_number: "+620000004444"
          })
          |> Repo.insert()

        admin
    end
  end

  defp insert_future_trips do
    _ = create_trip!(%{})
  end

  defp insert_varied_future_trips do
    base_dep = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(86_400, :second)

    _ =
      create_trip!(%{
        "transport_mode" => "bus",
        "departure_time" => base_dep,
        "arrival_time" => DateTime.add(base_dep, 3_600, :second),
        "price" => "15",
        "co2_level" => "90"
      })

    _ =
      create_trip!(%{
        "transport_mode" => "train",
        "price" => "40",
        "co2_level" => "60",
        "source_city" => "Tartu",
        "destination_city" => "Tallinn"
      })
  end

  defp create_trip!(attrs) do
    admin = ensure_admin()

    base_dep =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.add(86_400, :second)

    defaults = %{
      "transport_mode" => "bus",
      "source_city" => "Tartu",
      "destination_city" => "Tallinn",
      "departure_time" => base_dep,
      "arrival_time" => DateTime.add(base_dep, 5_400, :second),
      "price" => "25",
      "co2_level" => "100",
      "available_tickets" => "10",
      "dates" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
    }

    {:ok, trip} = Trips.create_trip(admin, Map.merge(defaults, attrs))
    trip
  end
end
