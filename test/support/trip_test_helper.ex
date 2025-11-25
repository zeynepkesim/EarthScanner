defmodule TripTestHelper do
  alias EarthScanner.Repo
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Accounts.User

  # Inserts a future trip with given attributes
  def create_trip(attrs \\ %{}) do
    base_time = DateTime.add(DateTime.utc_now(), 3600, :second)

    admin_id =
      case Map.get(attrs, :admin_id) || Map.get(attrs, "admin_id") do
        nil ->
          # create a throwaway admin for tests when none provided
          admin =
            %User{}
            |> User.admin_changeset(%{
              username: "test_admin_#{System.unique_integer([:positive])}",
              password: "Password123!",
              password_confirmation: "Password123!",
              email: "test_admin_#{System.unique_integer([:positive])}@example.com",
              phone_number: "+90000000000",
              role: "admin"
            })
            |> Repo.insert!()

          admin.id

        id ->
          id
      end

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
      admin_id: admin_id
    }

    %Trip{}
    |> Trip.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  def create_future_trips_with_varying_prices do
    Enum.map([5, 15, 30, 40], fn price ->
      create_trip(%{price: price})
    end)
  end

  def create_future_trips_with_varying_co2 do
    Enum.map([50, 120, 200, 300], fn co2 ->
      create_trip(%{co2_level: co2})
    end)
  end

  def create_future_trips_with_varying_durations do
    Enum.map([30, 60, 90], fn min ->
      base_time = DateTime.add(DateTime.utc_now(), 3600, :second)

      create_trip(%{
        departure_time: base_time,
        arrival_time: DateTime.add(base_time, min * 60, :second),
        duration_minutes: min
      })
    end)
  end

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
