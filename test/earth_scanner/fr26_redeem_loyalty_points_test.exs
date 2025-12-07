defmodule EarthScanner.RedeemLoyaltyPointsTest do
  use EarthScanner.DataCase

  alias EarthScanner.{Accounts, Trips, Repo}
  alias EarthScanner.Accounts.{User, PointLog}

  defp admin_fixture(attrs \\ %{}) do
    TripTestHelper.admin_fixture(attrs)
  end

  defp create_regular_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      "username" => "user_#{unique}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "John",
      "last_name" => "Doe",
      "email" => "user_#{unique}@test.com",
      "birthdate" => "1990-01-01",
      "nationality" => "US",
      "residence_address" => "123 Main St",
      "phone_number" => "+1234567890"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))
    user
  end

  defp set_points(user, points) do
    user
    |> Ecto.Changeset.change(loyalty_points: points)
    |> Repo.update!()
  end

  defp valid_trip_attrs do
    future_date = Date.utc_today() |> Date.add(10) |> Date.to_iso8601()

    %{
      "picture_url" => "https://example.com/pic.jpg",
      "transport_mode" => "plane",
      "source_city" => "Tallinn",
      "destination_city" => "Paris",
      "departure_time" => "2025-11-20T10:00:00Z",
      "arrival_time" => "2025-11-20T13:00:00Z",
      "price" => "100.0",
      "co2_level" => "200",
      "available_tickets" => "50",
      "dates" => future_date
    }
  end

  describe "FR-26 Redeem Loyalty Points" do
    test "User redeems points for partial discount" do
      admin = admin_fixture()
      # Price 100.0
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())
      instance = hd(trip.instances)

      # User has 500 points (worth 50.0 EUR discount)
      user = create_regular_user() |> set_points(500)

      assert {:ok, purchase} =
               Trips.purchase_trip_instance(user, instance.id, redeem_points: true)

      # Discount: 50.0. Final Price: 50.0.
      # Points Redeemed: 500.
      # Points Earned on remaining 50.0: 50.

      assert purchase.points_redeemed == 500
      assert purchase.points_earned == 50

      updated_user = Repo.get!(User, user.id)
      # 500 (start) - 500 (redeemed) + 50 (earned) = 50
      assert updated_user.loyalty_points == 50

      # NFR-09: Points Security & Integrity (Redemption Check)
      log = Repo.one!(from l in PointLog, where: l.user_id == ^user.id)
      assert log.change_amount == -450
      assert log.reason == "trip_purchase"
      assert log.balance_after == 50
    end

    test "User redeems points for full discount" do
      admin = admin_fixture()
      # Price 100.0
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())
      instance = hd(trip.instances)

      # User has 2000 points (worth 200.0 EUR, more than price)
      user = create_regular_user() |> set_points(2000)

      assert {:ok, purchase} =
               Trips.purchase_trip_instance(user, instance.id, redeem_points: true)

      # Discount: 100.0 (capped at price). Final Price: 0.0.
      # Points Redeemed: 1000 (100.0 * 10).
      # Points Earned on 0.0: 0.

      assert purchase.points_redeemed == 1000
      assert purchase.points_earned == 0

      updated_user = Repo.get!(User, user.id)
      # 2000 (start) - 1000 (redeemed) + 0 (earned) = 1000
      assert updated_user.loyalty_points == 1000

      # NFR-09: Points Security & Integrity
      log = Repo.one!(from l in PointLog, where: l.user_id == ^user.id)
      assert log.change_amount == -1000
      assert log.reason == "trip_purchase"
      assert log.balance_after == 1000
    end

    test "User with 0 points cannot get discount even if requested" do
      admin = admin_fixture()
      # Price 100.0
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())
      instance = hd(trip.instances)
      # 0 points
      user = create_regular_user()

      assert {:ok, purchase} =
               Trips.purchase_trip_instance(user, instance.id, redeem_points: true)

      assert purchase.points_redeemed == 0
      # Full price paid
      assert purchase.points_earned == 100

      updated_user = Repo.get!(User, user.id)
      assert updated_user.loyalty_points == 100
    end

    test "User has exactly enough points for max discount" do
      admin = admin_fixture()
      # Price 100.0
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())
      instance = hd(trip.instances)

      # Exact points needed: 1000
      user = create_regular_user() |> set_points(1000)

      assert {:ok, purchase} =
               Trips.purchase_trip_instance(user, instance.id, redeem_points: true)

      assert purchase.points_redeemed == 1000
      assert purchase.points_earned == 0

      updated_user = Repo.get!(User, user.id)
      assert updated_user.loyalty_points == 0
    end

    test "User has points but chooses NOT to redeem" do
      admin = admin_fixture()
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())
      instance = hd(trip.instances)

      user = create_regular_user() |> set_points(500)

      # redeem_points: false (default)
      assert {:ok, purchase} =
               Trips.purchase_trip_instance(user, instance.id, redeem_points: false)

      assert purchase.points_redeemed == 0
      assert purchase.points_earned == 100

      updated_user = Repo.get!(User, user.id)
      # 500 + 100
      assert updated_user.loyalty_points == 600
    end
  end
end
