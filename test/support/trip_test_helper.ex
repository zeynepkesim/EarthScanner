defmodule TripTestHelper do
  @moduledoc """
  Helper functions for inserting Trip records and related data in tests.
  """

  alias EarthScanner.Repo
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Accounts

  # Creates and returns an admin user that can own trips in tests.
  def admin_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive]) |> Integer.to_string()

    base_attrs = %{
      "username" => "test_admin_#{unique}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "Admin",
      "last_name" => "Test",
      "email" => "test_admin_#{unique}@example.com",
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "Admin Street 1",
      "phone_number" => "+37211111111",
      "role" => "admin"
    }

    attrs = Map.merge(base_attrs, attrs)
    {:ok, admin} = Accounts.register_user(attrs)
    admin
  end

  # Inserts a future trip with optional overrides, ensuring it belongs to a valid admin.
  def create_trip(attrs \\ %{}) do
    base_time = DateTime.add(DateTime.utc_now(), 3600, :second)

    defaults = %{
      source_city: "Tartu",
      destination_city: "Tallinn",
      transport_mode: "bus",
      departure_time: base_time,
      arrival_time: DateTime.add(base_time, 7200, :second),
      duration_minutes: 120,
      price: 20,
      co2_level: 100,
      available_tickets: 50,
      admin_id: 1
    }

    # Do not pass the :admin struct itself into the changeset.
    attrs =
      attrs
      |> Map.drop([:admin, "admin"])

    %Trip{}
    |> Trip.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # Inserts several future trips with different prices.
  def create_future_trips_with_varying_prices do
    Enum.map([5, 15, 30, 40], fn price ->
      create_trip(%{price: price})
    end)
  end

  # Inserts several future trips with different CO2 levels.
  def create_future_trips_with_varying_co2 do
    Enum.map([50, 120, 200, 300], fn co2 ->
      create_trip(%{co2_level: co2})
    end)
  end

  # Inserts several future trips with different durations.
  def create_future_trips_with_varying_durations do
    Enum.map([30, 60, 90], fn minutes ->
      base_time = DateTime.add(DateTime.utc_now(), 3600, :second)

      create_trip(%{
        departure_time: base_time,
        arrival_time: DateTime.add(base_time, minutes * 60, :second),
        duration_minutes: minutes
      })
    end)
  end

  # Inserts one past and one future trip relative to current time.
  def create_past_and_future_trips do
    now = DateTime.utc_now()
    past = DateTime.add(now, -3600, :second)
    future = DateTime.add(now, 3600, :second)

    # Past trip
    create_trip(%{
      departure_time: past,
      arrival_time: DateTime.add(past, 3600, :second)
    })

    # Future trip
    create_trip(%{
      departure_time: future,
      arrival_time: DateTime.add(future, 3600, :second)
    })
  end
end
