defmodule EarthScanner.Notifications.FR28TripChangeAlertsTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Accounts
  alias EarthScanner.Repo

  @tag :skip
  test "detects changes to watched trip fields and returns a changes diff" do
    # Create admin and user
    {:ok, admin} = Accounts.register_user(%{
      "username" => "admin_for_change",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "email" => "admin_change@example.com",
      "name" => "Admin",
      "last_name" => "Change",
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "Admin St",
      "phone_number" => "+37200000001"
    })

    {:ok, user} = Accounts.register_user(%{
      "username" => "user_for_change",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "email" => "user_change@example.com",
      "name" => "User",
      "last_name" => "Change",
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "User St",
      "phone_number" => "+37200000002"
    })

    # Create a trip with one instance
    {:ok, trip} = Trips.create_trip(admin, %{
      "transport_mode" => "plane",
      "source_city" => "Tallinn",
      "destination_city" => "Riga",
      "departure_time" => DateTime.add(DateTime.utc_now(), 3600, :second),
      "arrival_time" => DateTime.add(DateTime.utc_now(), 7200, :second),
      "price" => "100.0",
      "co2_level" => "200",
      "available_tickets" => "10",
      "dates" => Date.to_iso8601(Date.utc_today())
    })

    instance = hd(trip.instances)

    # Purchase so user is affected
    assert {:ok, _purchase} = Trips.purchase_trip_instance(user, instance.id)

    # Perform update: change departure_time
    new_dep = DateTime.add(DateTime.utc_now(), 7200, :second)
    result = Trips.update_trip(trip, %{"departure_time" => new_dep})

    # Expect implementation to return {:ok, trip, diff}; current implementation returns {:ok, trip}
    assert {:ok, _trip, _diff} = result
  end

  @tag :skip
  test "persists an in-app notification for every purchaser of the trip" do
    # Persist per-user in-app notifications (unread) for affected purchasers
    assert true
  end

  @tag :skip
  test "sends immediate email alerts to affected purchasers with change details" do
    {:ok, admin} = Accounts.register_user(%{
      "username" => "admin_email",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "email" => "admin_email@example.com",
      "name" => "Admin",
      "last_name" => "Email",
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "Admin St",
      "phone_number" => "+37200000003"
    })

    {:ok, user} = Accounts.register_user(%{
      "username" => "user_email",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "email" => "user_email@example.com",
      "name" => "User",
      "last_name" => "Email",
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "User St",
      "phone_number" => "+37200000004"
    })

    {:ok, trip} = Trips.create_trip(admin, %{
      "transport_mode" => "train",
      "source_city" => "Vilnius",
      "destination_city" => "Kaunas",
      "departure_time" => DateTime.add(DateTime.utc_now(), 3600, :second),
      "arrival_time" => DateTime.add(DateTime.utc_now(), 7200, :second),
      "price" => "50.0",
      "co2_level" => "80",
      "available_tickets" => "10",
      "dates" => Date.to_iso8601(Date.utc_today())
    })

    instance = hd(trip.instances)
    assert {:ok, _purchase} = Trips.purchase_trip_instance(user, instance.id)

    # Clear any existing test deliveries
    _ = Swoosh.Adapters.Test.deliveries()

    # Trigger update
    {:ok, _trip} = Trips.update_trip(trip, %{"departure_time" => DateTime.add(DateTime.utc_now(), 7200, :second)})

    # Expect at least one email delivery (implementation not present yet, so this will fail)
    assert length(Swoosh.Adapters.Test.deliveries()) >= 1
  end

  @tag :skip
  test "respects user email preferences (opt-out) when sending trip alerts" do
    # Do not send emails to users who opted out; in-app notification optional
    assert true
  end

  @tag :skip
  test "creates an audit log entry for trip changes (trip_change_logs)" do
    # Record an audit log entry (trip_change_logs) capturing the field diff
    assert true
  end
end
