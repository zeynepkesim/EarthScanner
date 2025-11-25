defmodule EarthScanner.Notifications.Fr27TripReminderNotificationsTest do
  use EarthScanner.DataCase, async: true

  alias EarthScanner.Trips
  alias EarthScanner.Accounts
  alias EarthScanner.Repo

  # FR-27 (Trip Reminder Notifications)
  defp admin_fixture do
    {:ok, admin} =
      Accounts.register_user(%{
        "username" => "admin_#{System.unique_integer([:positive])}",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Admin",
        "last_name" => "User",
        "email" => "admin_#{System.unique_integer([:positive])}@example.com",
        "birthdate" => "1990-01-01",
        "nationality" => "TR",
        "residence_address" => "Admin Street",
        "phone_number" => "+905551111111"
      })

    admin
  end

  defp user_fixture do
    {:ok, user} =
      Accounts.register_user(%{
        "username" => "user_#{System.unique_integer([:positive])}",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Normal",
        "last_name" => "User",
        "email" => "user_#{System.unique_integer([:positive])}@example.com",
        "birthdate" => "1995-01-01",
        "nationality" => "US",
        "residence_address" => "User Street",
        "phone_number" => "+12025550123"
      })

    user
  end

  @tag :skip
  test "FR-27: creates a reminder scheduled 24 hours before departure when a purchase is made" do
    admin = admin_fixture()
    user = user_fixture()

    # create a trip with a departure_time 72 hours from now and a single instance 3 days from today
    departure_dt = DateTime.add(DateTime.utc_now(), 72 * 3600, :second)
    arrival_dt = DateTime.add(departure_dt, 2 * 3600, :second)
    instance_date = Date.add(Date.utc_today(), 3)

    attrs = %{
      "transport_mode" => "plane",
      "source_city" => "Tallinn",
      "destination_city" => "Paris",
      "departure_time" => DateTime.to_iso8601(departure_dt),
      "arrival_time" => DateTime.to_iso8601(arrival_dt),
      "price" => "150.0",
      "co2_level" => "200",
      "available_tickets" => "10",
      "dates" => Date.to_iso8601(instance_date)
    }

    {:ok, trip} = Trips.create_trip(admin, attrs)
    # pick the created instance
    instance = List.first(trip.instances)

    # perform the purchase
    {:ok, _purchase} = Trips.purchase_trip_instance(user, instance.id)

    # Query the reminders table directly (Notifications context not yet implemented)
    reminder_scheduled =
      Repo.one(
        from r in "reminders",
          where: r.user_id == ^user.id and r.trip_instance_id == ^instance.id,
          select: r.scheduled_at
      )

    assert not is_nil(reminder_scheduled)

    # compute expected scheduled_at by combining the trip's departure time-of-day with the instance date,
    # then subtracting 24 hours
    {:ok, time} =
      Time.new(trip.departure_time.hour, trip.departure_time.minute, trip.departure_time.second)

    {:ok, expected_dt} = DateTime.new(instance.date, time, "Etc/UTC")
    expected_scheduled = DateTime.add(expected_dt, -24 * 3600, :second)

    scheduled_dt =
      case reminder_scheduled do
        %NaiveDateTime{} = ndt -> DateTime.from_naive!(ndt, "Etc/UTC")
        %DateTime{} = dt -> dt
        other -> flunk("unexpected scheduled value: #{inspect(other)}")
      end

    assert DateTime.diff(scheduled_dt, expected_scheduled) == 0
  end

  @tag :skip
  test "FR-27: delivers in-app notification when the user connects and a reminder is due" do
    assert true
  end

  @tag :skip
  test "FR-27: respects user opt-in/opt-out preference (no reminders created or delivered when opted-out)" do
    assert true
  end
end
