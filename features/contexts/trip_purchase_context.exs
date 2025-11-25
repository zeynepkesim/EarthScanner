defmodule TripPurchaseContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias Ecto.Changeset
  alias EarthScanner.{Accounts, Trips, Repo}
  alias Hound.Helpers.Cookie

  @base "http://localhost:4002"

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, state ->
    Hound.end_session()
    {:ok, state}
  end

  given_ ~r/^I am logged in as a normal user$/, fn state, _ ->
    suffix = :erlang.unique_integer([:positive]) |> Integer.to_string()
    email = "bdd_purchase_user_" <> suffix <> "@example.com"
    password = "Password123!"

    user =
      case Accounts.register_user(%{
             "username" => "purchase_user_" <> suffix,
             "password" => password,
             "password_confirmation" => password,
             "name" => "Jane",
             "last_name" => "Traveler",
             "email" => email,
             "birthdate" => "1995-03-03",
             "nationality" => "EE",
             "residence_address" => "Travel Street 10",
             "phone_number" => "+37255555555"
           }) do
        {:ok, user} ->
          user

        {:error, %Changeset{} = changeset} ->
          if Keyword.has_key?(changeset.errors, :email) do
            Accounts.get_user_by_email(email) ||
              raise "Unable to reuse existing user with email #{email}"
          else
            raise "User registration failed: #{inspect(changeset.errors)}"
          end
      end

    navigate_to(@base <> "/users/login")
    Process.sleep(500)
    fill_field({:css, "input[name='session[email]']"}, email)
    fill_field({:css, "input[name='session[password]']"}, password)
    submit_element({:id, "login-form"})
    Process.sleep(500)

    {:ok, Map.put(state, :user, user)}
  end

  given_ ~r/^I am not logged in$/, fn state, _ ->
    # Clear any leftover auth cookies and land on a neutral page
    Cookie.delete_cookies()
    navigate_to(@base <> "/trips")
    {:ok, Map.delete(state, :user)}
  end

  given_ ~r/^a future trip with available tickets exists$/, fn state, _ ->
    future_date = Date.utc_today() |> Date.add(7)

    admin = ensure_admin_user()

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "source_city" => "Tallinn",
        "destination_city" => "Helsinki",
        "departure_time" => DateTime.new!(future_date, ~T[09:00:00]),
        "arrival_time" => DateTime.new!(future_date, ~T[11:00:00]),
        "price" => "45.00",
        "available_tickets" => 15,
        "co2_level" => 120,
        "transport_mode" => "train",
        "dates" => Date.to_iso8601(future_date)
      })

    trip = Repo.preload(trip, :instances)

    {:ok, Map.merge(state, %{trip: trip})}
  end

  given_ ~r/^I have already purchased that trip date$/, fn %{user: user, trip: trip} = state, _ ->
    instance =
      trip.instances
      |> List.first()

    case Trips.purchase_trip_instance(user, instance.id) do
      {:ok, _purchase} ->
        {:ok, state}

      {:error, :already_purchased} ->
        {:ok, state}
    end
  end

  given_ ~r/^I have not purchased that trip date$/, fn state, _ ->
    {:ok, state}
  end

  given_ ~r/^that trip date has already passed$/, fn %{trip: trip} = state, _ ->
    past_date = Date.utc_today() |> Date.add(-1)

    instance =
      trip.instances
      |> List.first()

    instance
    |> Changeset.change(date: past_date)
    |> Repo.update!()

    {:ok, state}
  end

  when_ ~r/^I visit that trip's detail page$/, fn %{trip: trip} = state, _ ->
    navigate_to(@base <> "/trips/#{trip.id}")
    Process.sleep(1_000)
    {:ok, state}
  end

  when_ ~r/^I purchase the first available date$/, fn %{trip: trip} = state, _ ->
    submit_purchase_form(trip.id)
    {:ok, state}
  end

  when_ ~r/^I attempt to purchase the first available date$/, fn %{trip: trip} = state, _ ->
    submit_purchase_form(trip.id)
    {:ok, state}
  end

  when_ ~r/^I refund that trip purchase$/, fn %{trip: trip} = state, _ ->
    submit_refund_form(trip.id)
    {:ok, state}
  end

  then_ ~r/^I should see a purchase confirmation message$/, fn state, _ ->
    Process.sleep(800)
    text = visible_page_text()
    assert String.contains?(text, "Trip purchased")
    {:ok, state}
  end

  then_ ~r/^I should see a login required message$/, fn state, _ ->
    Process.sleep(800)
    text = visible_page_text()
    assert String.contains?(text, "Please log in to purchase trips.") ||
             String.contains?(text, "Log in")
    {:ok, state}
  end

  then_ ~r/^I should see an already purchased message$/, fn state, _ ->
    Process.sleep(800)
    text = visible_page_text()
    assert String.contains?(text, "You already purchased this trip.")
    {:ok, state}
  end

  then_ ~r/^I should see a refund confirmation message$/, fn state, _ ->
    # allow the browser a moment to complete the round-trip and render the flash
    Process.sleep(1200)
    text = visible_page_text()
    assert String.contains?(text, "Purchase returned.")
    {:ok, state}
  end

  then_ ~r/^I should see a past trip refund error message$/, fn state, _ ->
    Process.sleep(800)
    text = visible_page_text()
    assert String.contains?(text, "This trip date has passed and cannot be refunded.")
    {:ok, state}
  end

  then_ ~r/^I should be redirected to the trips page for past trips$/, fn state, _ ->
    Process.sleep(800)
    assert String.contains?(current_url(), "/trips")
    {:ok, state}
  end

  defp ensure_admin_user do
    suffix = :erlang.unique_integer([:positive]) |> Integer.to_string()
    email = "bdd_purchase_admin_" <> suffix <> "@example.com"
    password = "Password123!"

    admin =
      case Accounts.register_user(%{
             "username" => "purchase_admin_" <> suffix,
             "password" => password,
             "password_confirmation" => password,
             "name" => "Ticket",
             "last_name" => "Admin",
             "email" => email,
             "birthdate" => "1990-01-01",
             "nationality" => "EE",
             "residence_address" => "Admin Square 1",
             "phone_number" => "+37251111111"
           }) do
        {:ok, user} ->
          user

        {:error, %Changeset{} = changeset} ->
          if Keyword.has_key?(changeset.errors, :email) do
            Accounts.get_user_by_email(email) ||
              raise "Unable to reuse existing admin with email #{email}"
          else
            raise "Admin registration failed: #{inspect(changeset.errors)}"
          end
      end

    admin
    |> Changeset.change(role: "admin")
    |> Repo.update!()
  end

  defp submit_purchase_form(trip_id) do
    form =
      find_element(
        :xpath,
        "(//form[@action='/trips/#{trip_id}/purchase'])[1]"
      )

    submit_element(form)
    Process.sleep(800)
  end

  defp submit_refund_form(trip_id) do
    form =
      find_element(
        :xpath,
        "(//form[@action='/trips/#{trip_id}/purchase'][.//input[@name='_method' and @value='delete']])[1]"
      )

    submit_element(form)
    # allow a bit more time for the redirect and flash to appear in the browser
    Process.sleep(1200)
  end

  then_ ~r/^I should see the purchased badge on the trip page$/, fn state, _ ->
    Process.sleep(800)

    _ =
      find_element(
        :xpath,
        "//span[contains(@class,'bg-indigo-50') and normalize-space()='Purchased']"
      )

    {:ok, state}
  end

  then_ ~r/^I should not see the purchased badge on the trip page$/, fn state, _ ->
    Process.sleep(800)
    refute String.contains?(page_source(), "bg-indigo-50" <> ">Purchased")
    {:ok, state}
  end
end
