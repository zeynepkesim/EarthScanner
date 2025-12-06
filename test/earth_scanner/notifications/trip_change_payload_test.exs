defmodule EarthScanner.Notifications.TripChangePayloadTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Accounts
  alias EarthScanner.Notifications
  alias EarthScanner.Repo

  test "update_trip creates trip_change notification containing trip_name and route" do
    {:ok, admin} =
      Accounts.register_user(%{
        "username" => "admin_notify",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "email" => "admin_notify@example.com",
        "name" => "Admin",
        "last_name" => "Notify",
        "birthdate" => "1990-01-01",
        "nationality" => "EE",
        "residence_address" => "Admin St",
        "phone_number" => "+37200000005"
      })

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "user_notify",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "email" => "user_notify@example.com",
        "name" => "User",
        "last_name" => "Notify",
        "birthdate" => "1990-01-01",
        "nationality" => "EE",
        "residence_address" => "User St",
        "phone_number" => "+37200000006"
      })

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "transport_mode" => "bus",
        "source_city" => "CityA",
        "destination_city" => "CityB",
        "departure_time" => DateTime.add(DateTime.utc_now(), 3600, :second),
        "arrival_time" => DateTime.add(DateTime.utc_now(), 7200, :second),
        "price" => "20.0",
        "co2_level" => "10",
        "available_tickets" => "10",
        "dates" => Date.to_iso8601(Date.utc_today())
      })

    instance = hd(trip.instances)
    assert {:ok, _purchase} = Trips.purchase_trip_instance(user, instance.id)

    # trigger an update that changes co2_level
    {:ok, _trip, diff} = Trips.update_trip(trip, %{"co2_level" => 15})

    # fetch notifications for user and assert payload includes trip_name/from/to
    notifications = Notifications.list_for_user(user.id)
    assert length(notifications) >= 1

    found = Enum.find(notifications, fn n -> n.kind == "trip_change" end)
    assert found != nil

    payload = found.payload || %{}
    assert payload["trip_name"] != nil
    assert payload["from"] == "CityA"
    assert payload["to"] == "CityB"
    assert payload["diff"] != %{}
  end
end
