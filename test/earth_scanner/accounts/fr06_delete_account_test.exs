defmodule EarthScanner.Accounts.DeleteAccountTest do
  use EarthScanner.DataCase

  alias EarthScanner.Accounts
  alias EarthScanner.Accounts.User
  alias EarthScanner.Purchases.Purchase
  alias EarthScanner.Notifications.Notification
  alias EarthScanner.Accounts.PointLog
  alias EarthScanner.Trips

  describe "delete_user/2" do
    @password "secret123"
    @valid_attrs %{
      name: "John",
      last_name: "Doe",
      username: "johndoe",
      email: "john@example.com",
      password: @password,
      password_confirmation: @password,
      birthdate: ~D[1990-01-01],
      nationality: "US",
      residence_address: "123 Main St",
      phone_number: "+1234567890"
    }

    setup do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      {:ok, user: user}
    end

    test "deletes user and all associated data with correct password", %{user: user} do
      # Create associated data
      {:ok, _} =
        Repo.insert(%PointLog{
          user_id: user.id,
          change_amount: 10,
          reason: "Test",
          balance_after: 10
        })

      {:ok, _} =
        Repo.insert(%Notification{
          user_id: user.id,
          kind: "info",
          payload: %{},
          status: "pending"
        })

      # Create admin for trip
      unique_admin_email = "admin_#{System.unique_integer()}@example.com"

      {:ok, admin} =
        Accounts.create_admin(
          # Mock creator
          %User{role: "admin"},
          %{
            username: "admin_#{System.unique_integer()}",
            password: @password,
            password_confirmation: @password,
            email: unique_admin_email,
            phone_number: "+1231231234"
          }
        )

      # Setup for Purchase (needs a trip instance, which needs a trip)
      trip_attrs = %{
        picture_url: "https://example.com/trip.jpg",
        source_city: "NYC",
        destination_city: "LON",
        transport_mode: "plane",
        departure_time: ~U[2024-01-01 10:00:00Z],
        # 10 hours later
        arrival_time: ~U[2024-01-01 20:00:00Z],
        price: 100,
        co2_level: 100,
        available_tickets: 100,
        admin_id: admin.id
      }

      {:ok, saved_trip} =
        %EarthScanner.Trips.Trip{}
        |> EarthScanner.Trips.Trip.changeset(trip_attrs)
        |> Repo.insert()

      {:ok, trip_instance} =
        Repo.insert(%EarthScanner.Trips.TripInstance{
          trip_id: saved_trip.id,
          date: ~D[2024-01-01],
          available_tickets: 100
        })

      {:ok, _} =
        Repo.insert(%Purchase{
          user_id: user.id,
          trip_instance_id: trip_instance.id,
          points_earned: 0,
          points_redeemed: 0
        })

      assert {:ok, _} = Accounts.delete_user(user, @password)

      assert Repo.get(User, user.id) == nil
      assert Repo.aggregate(from(p in PointLog, where: p.user_id == ^user.id), :count, :id) == 0

      assert Repo.aggregate(from(n in Notification, where: n.user_id == ^user.id), :count, :id) ==
               0

      assert Repo.aggregate(from(p in Purchase, where: p.user_id == ^user.id), :count, :id) == 0
    end

    test "returns error with incorrect password", %{user: user} do
      assert {:error, :invalid_password} = Accounts.delete_user(user, "wrongpassword")
      assert Repo.get(User, user.id) != nil
    end

    test "deletes user with no associated data", %{user: user} do
      # Edge Case: User exists but has no points, purchases, or notifications
      assert {:ok, :deleted} = Accounts.delete_user(user, @password)
      assert Repo.get(User, user.id) == nil
    end

    test "raises StaleEntryError when deleting already deleted user", %{user: user} do
      # Edge Case: User was already deleted (race condition)
      # First delete successfully
      assert {:ok, :deleted} = Accounts.delete_user(user, @password)

      # Try to delete again with the same struct
      assert_raise Ecto.StaleEntryError, fn ->
        Accounts.delete_user(user, @password)
      end
    end
  end
end
