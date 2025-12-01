defmodule FR27NotificationsContext do
  use WhiteBread.Context
  use Hound.Helpers

  alias EarthScanner.{Repo, Accounts, Trips}
  alias EarthScanner.Trips.Trip

  @base "http://localhost:4002"

  scenario_starting_state fn _ ->
    Hound.start_session()
    %{}
  end

  scenario_finalize fn _status, _state ->
    Hound.end_session()
    :ok
  end

  given_ ~r/^a trip is scheduled within the next 24 hours$/, fn state, _ ->
    admin = ensure_admin_user()

    # schedule within 2 hours from now
    dep_dt = DateTime.add(DateTime.utc_now(), 2 * 3600, :second)

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "transport_mode" => "bus",
        "source_city" => "CityA",
        "destination_city" => "CityB",
        "departure_time" => DateTime.to_iso8601(dep_dt),
        "arrival_time" => DateTime.to_iso8601(DateTime.add(dep_dt, 3600, :second)),
        "price" => "20.00",
        "co2_level" => "50",
        "available_tickets" => "10",
        "dates" => Date.utc_today() |> Date.to_iso8601()
      })

    trip = Repo.preload(trip, :instances)
    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^a trip is scheduled exactly 24 hours from now$/, fn state, _ ->
    admin = ensure_admin_user()

    # schedule exactly 24 hours from now
    dep_dt = DateTime.add(DateTime.utc_now(), 24 * 3600, :second)

    # instance date must be tomorrow so the departure datetime built from the trip's time
    # and the instance date matches exactly 24 hours from now
    tomorrow = Date.add(Date.utc_today(), 1)

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "transport_mode" => "bus",
        "source_city" => "EdgeCityA",
        "destination_city" => "EdgeCityB",
        "departure_time" => DateTime.to_iso8601(dep_dt),
        "arrival_time" => DateTime.to_iso8601(DateTime.add(dep_dt, 3600, :second)),
        "price" => "25.00",
        "co2_level" => "60",
        "available_tickets" => "10",
        "dates" => Date.to_iso8601(tomorrow)
      })

    trip = Repo.preload(trip, :instances)
    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^I am logged in as a normal user$/, fn state, _ ->
    suffix = :erlang.unique_integer([:positive]) |> Integer.to_string()
    email = "bdd_fr27_user_#{suffix}@example.com"
    password = "Password123!"
    user_to_use =
      case Accounts.get_user_by_email(email) do
        nil ->
          {:ok, user} =
            Accounts.register_user(%{
              "username" => "fr27_user_#{suffix}",
              "password" => password,
              "password_confirmation" => password,
              "name" => "FR27",
              "last_name" => "Tester",
              "email" => email,
              "birthdate" => "1990-01-01",
              "nationality" => "US",
              "residence_address" => "BDD St",
              "phone_number" => "123"
            })

          user

        user ->
          user
      end

    # perform browser login so session/cookies set for notifications page
    navigate_to(@base <> "/users/login")
    Process.sleep(300)
    fill_field({:css, "input[name='session[email]']"}, user_to_use.email)
    fill_field({:css, "input[name='session[password]']"}, password)
    submit_element({:id, "login-form"})
    Process.sleep(500)

    {:ok, Map.put(state, :user, user_to_use)}
  end

  given_ ~r/^I purchase that trip date$/, fn %{user: user, trip: trip} = state, _ ->
    instance = trip.instances |> List.first()

    case Trips.purchase_trip_instance(user, instance.id) do
      {:ok, _purchase} ->
        {:ok, state}

      {:error, :already_purchased} ->
        {:ok, state}

      other ->
        {:error, "Could not purchase: #{inspect(other)}"}
    end
  end

  when_ ~r/^I visit the notifications page$/, fn state, _ ->
    navigate_to(@base <> "/notifications")
    Process.sleep(500)
    {:ok, state}
  end

  then_ ~r/^I should see a reminder for the trip$/, fn %{trip: trip} = state, _ ->
    text = visible_page_text()
    if String.contains?(text, trip.source_city) and String.contains?(text, trip.destination_city) do
      {:ok, state}
    else
      {:error, "Reminder not found on notifications page"}
    end
  end

  then_ ~r/^I should not see a reminder for the trip$/, fn %{trip: trip} = state, _ ->
    text = visible_page_text()
    if String.contains?(text, trip.source_city) and String.contains?(text, trip.destination_city) do
      {:error, "Unexpected reminder found on notifications page"}
    else
      {:ok, state}
    end
  end

  given_ ~r/^a trip exists$/, fn state, _ ->
    admin = ensure_admin_user()

    dep_dt = DateTime.add(DateTime.utc_now(), 2 * 3600, :second)

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "transport_mode" => "bus",
        "source_city" => "CityX",
        "destination_city" => "CityY",
        "departure_time" => DateTime.to_iso8601(dep_dt),
        "arrival_time" => DateTime.to_iso8601(DateTime.add(dep_dt, 3600, :second)),
        "price" => "30.00",
        "co2_level" => "40",
        "available_tickets" => "5",
        "dates" => Date.utc_today() |> Date.to_iso8601()
      })

    trip = Repo.preload(trip, :instances)
    {:ok, Map.put(state, :trip, trip)}
  end

  given_ ~r/^a normal user has purchased a ticket for that trip$/, fn state, _ ->
    # reuse the existing login + purchase helpers by creating a user and purchasing
    suffix = :erlang.unique_integer([:positive]) |> Integer.to_string()
    email = "bdd_fr28_user_#{suffix}@example.com"
    password = "Password123!"

    user =
      case Accounts.get_user_by_email(email) do
        nil ->
          case Accounts.register_user(%{
                 "username" => "fr28_user_#{suffix}",
                 "password" => password,
                 "password_confirmation" => password,
                 "name" => "FR28",
                 "last_name" => "Tester",
                 "email" => email,
                 "birthdate" => "1990-01-01",
                 "nationality" => "US",
                 "residence_address" => "BDD St",
                 "phone_number" => "123"
               }) do
            {:ok, u} -> u
            {:error, changeset} ->
              # If registration failed due to unique constraint race, try to load the user
              case Accounts.get_user_by_email(email) do
                nil -> raise "Could not create or find user: #{inspect(changeset)}"
                existing -> existing
              end
          end

        existing ->
          existing
      end

    # purchase the first instance
    instance = state.trip.instances |> List.first()

    case Trips.purchase_trip_instance(user, instance.id) do
      {:ok, _purchase} ->
        {:ok, state |> Map.put(:user, user) |> Map.put(:user_password, password)}

      {:error, :already_purchased} ->
        {:ok, state |> Map.put(:user, user) |> Map.put(:user_password, password)}

      other ->
        {:error, "Could not purchase: #{inspect(other)}"}
    end
  end

  when_ ~r/^I am logged in as that normal user$/, fn %{user: user, user_password: password} = state, _ ->
    # perform browser login for the purchaser created earlier
    navigate_to(@base <> "/users/login")
    Process.sleep(300)
    fill_field({:css, "input[name='session[email]']"}, user.email)
    fill_field({:css, "input[name='session[password]']"}, password)
    submit_element({:id, "login-form"})
    Process.sleep(500)
    {:ok, state}
  end

  when_ ~r/^the admin updates the trip price to "?([^\"]+)"?$/, fn %{trip: trip} = state, extra ->
    # accept capture in multiple shapes WhiteBread may provide:
    # - %{matches: [price]}
    # - a plain list like [price]
    # - a map with key "price" or :price
    price =
      cond do
        is_map(extra) and Map.has_key?(extra, :matches) and is_list(extra.matches) and length(extra.matches) > 0 ->
          List.first(extra.matches)

        is_map(extra) and Map.has_key?(extra, "matches") and is_list(extra["matches"]) and length(extra["matches"]) > 0 ->
          List.first(extra["matches"])

        is_list(extra) and length(extra) > 0 ->
          List.first(extra)

        is_map(extra) and Map.has_key?(extra, "price") ->
          Map.get(extra, "price")

        is_map(extra) and Map.has_key?(extra, :price) ->
          Map.get(extra, :price)

        true ->
          case extra do
            [p] -> p
            _ -> ""
          end
      end

    # Normalize the captured price into a trimmed string; fail fast if missing
    price =
      cond do
        is_list(price) and length(price) > 0 -> List.first(price)
        is_map(price) and Map.has_key?(price, "price") -> Map.get(price, "price")
        is_map(price) and Map.has_key?(price, :price) -> Map.get(price, :price)
        true -> price
      end

    price = String.trim(to_string(price || ""))

    if price == "" do
      File.mkdir_p!("tmp")
      File.write!("tmp/bdd_admin_update_error.log", "Captured price was empty for admin update step. Raw extra: #{inspect(extra)}\n")
      raise "BDD admin update step failed: captured price is empty (details written to tmp/bdd_admin_update_error.log)"
    end

    # debug: write the trip struct and attrs we are about to use for update
    File.mkdir_p!("tmp")
    File.write!("tmp/bdd_admin_update_debug.log", "trip: #{inspect(trip, pretty: true)}\nattrs: #{inspect(%{"price" => price}, pretty: true)}\n")

    case Trips.update_trip(trip, %{"price" => price}) do
      {:ok, trip, _diff} ->
        {:ok, Map.put(state, :trip, trip)}

      {:error, reason} ->
        File.mkdir_p!("tmp")
        File.write!("tmp/bdd_admin_update_error.log", "Trip.update returned {:error, reason}:\n" <> inspect(reason, pretty: true))
        raise "Trip update failed during BDD admin step: #{inspect(reason)} (details written to tmp/bdd_admin_update_error.log)"

      other ->
        File.mkdir_p!("tmp")
        File.write!("tmp/bdd_admin_update_error.log", "Trip.update returned unexpected value:\n" <> inspect(other, pretty: true))
        raise "Trip.update returned unexpected value during BDD admin step: #{inspect(other)} (details written to tmp/bdd_admin_update_error.log)"
    end
  end
  # Support a step without an explicit price capture. Compute a new price by
  # increasing the current price by 5.00 (avoid hardcoding an absolute price
  # like '35.00' in the context). Persist the updated trip and store it in
  # the scenario state for downstream assertions.
  when_ ~r/^the admin updates the trip price$/, fn %{trip: trip} = state, _extra ->
    # compute new price = current price + 5.00
    current = trip.price || Decimal.new("0")
    new_price = Decimal.add(current, Decimal.new("5.00")) |> Decimal.to_string()

    File.mkdir_p!("tmp")
    File.write!("tmp/bdd_admin_update_debug.log", "trip: #{inspect(trip, pretty: true)}\nattrs: #{inspect(%{"price" => new_price}, pretty: true)}\n")

    case Trips.update_trip(trip, %{"price" => new_price}) do
      {:ok, trip, _diff} ->
        {:ok, Map.put(state, :trip, trip)}
    end
  end

  then_ ~r/^I should see a trip change notification mentioning the updated price$/, fn %{trip: trip} = state, _ ->
    navigate_to(@base <> "/notifications")
    Process.sleep(300)
    content = visible_page_text()

    # Use the stored, updated trip price for the assertion
    expected = trip.price |> to_string()

    if String.contains?(content, expected) do
      {:ok, state}
    else
      {:error, "Trip change notification with updated price #{expected} not visible on notifications page"}
    end
  end

  then_ ~r/^I should not see a trip change notification mentioning the updated price$/, fn %{trip: trip} = state, _ ->
    navigate_to(@base <> "/notifications")
    Process.sleep(300)
    content = visible_page_text()

    expected = trip.price |> to_string()

    if String.contains?(content, expected) do
      {:error, "Trip change notification with updated price #{expected} unexpectedly visible on notifications page"}
    else
      {:ok, state}
    end
  end

  defp ensure_admin_user do
    suffix = :erlang.unique_integer([:positive]) |> Integer.to_string()
    email = "bdd_fr27_admin_#{suffix}@example.com"
    password = "Password123!"
    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} =
          Accounts.register_user(%{
            "username" => "fr27_admin_#{suffix}",
            "password" => password,
            "password_confirmation" => password,
            "name" => "Admin",
            "last_name" => "Tester",
            "email" => email,
            "birthdate" => "1990-01-01",
            "nationality" => "US",
            "residence_address" => "Admin St",
            "phone_number" => "123"
          })

        user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()
        user

      user ->
        if user.role != "admin" do
          user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()
        end

        user
    end
  end
end
