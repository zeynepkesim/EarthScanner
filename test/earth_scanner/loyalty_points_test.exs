defmodule EarthScanner.LoyaltyPointsTest do
  use EarthScanner.DataCase
  @moduletag :skip

  alias EarthScanner.{Accounts, Trips, Repo}
  alias EarthScanner.Accounts.{User, PointLog}
  alias EarthScanner.Trips.TripInstance
  alias EarthScanner.Purchases.Purchase

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

  describe "Loyalty Points (FR-25 & FR-26)" do
    # --- Positive Scenarios ---

    test "FR-25: User earns points on standard purchase" do
      admin = admin_fixture()
      # Price 100.0
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())
      instance = hd(trip.instances)
      user = create_regular_user()

      assert {:ok, purchase} = Trips.purchase_trip_instance(user, instance.id)

      # 100.0 price -> 100 points
      assert purchase.points_earned == 100
      assert purchase.points_redeemed == 0

      updated_user = Repo.get!(User, user.id)
      assert updated_user.loyalty_points == 100

      # NFR-09: Points Security & Integrity
      # Check audit log
      log = Repo.one!(PointLog)
      assert log.user_id == user.id
      assert log.change_amount == 100
      assert log.reason == "trip_purchase"
      assert log.balance_after == 100
    end

    test "FR-26: User redeems points for partial discount" do
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

      # NFR-09: Points Security & Integrity
      # Check audit log
      # Single log with net change: 50 (earned) - 500 (redeemed) = -450
      log = Repo.one!(PointLog)
      assert log.user_id == user.id
      assert log.change_amount == -450
      assert log.reason == "trip_purchase"
      assert log.balance_after == 50
    end

    test "FR-26: User redeems points for full discount" do
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
      # Check audit log
      log = Repo.one!(PointLog)
      assert log.user_id == user.id
      assert log.change_amount == -1000
      assert log.reason == "trip_purchase"
      assert log.balance_after == 1000
    end

    # --- NFR-09: Points Security & Integrity Tests ---

    # Positive Scenario: Point updates are atomic and audited
    test "NFR-09: Point updates are atomic and audited" do
      admin = admin_fixture()
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())
      instance = hd(trip.instances)
      user = create_regular_user()

      assert {:ok, _purchase} = Trips.purchase_trip_instance(user, instance.id)

      # Verify Log
      log = Repo.one!(PointLog)
      assert log.user_id == user.id
      assert log.change_amount == 100
      assert log.reason == "trip_purchase"
    end

    # Negative Scenario: Transaction rollback prevents partial updates
    test "NFR-09: Transaction rollback prevents partial updates" do
      admin = admin_fixture()
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())
      instance = hd(trip.instances)
      user = create_regular_user()

      # Simulate a failure by trying to purchase a sold-out trip (which fails validation)
      # First, make it sold out
      Ecto.Changeset.change(instance, available_tickets: 0) |> Repo.update!()

      assert {:error, :sold_out} = Trips.purchase_trip_instance(user, instance.id)

      # Verify NO points changed
      updated_user = Repo.get!(User, user.id)
      assert updated_user.loyalty_points == 0

      # Verify NO audit log created
      assert Repo.aggregate(PointLog, :count, :id) == 0
    end

    # Edge Case: Zero point change is still logged
    test "NFR-09: Zero point change is logged for audit trail" do
      admin = admin_fixture()
      user = create_regular_user()

      # If price is 0.1 (very cheap), earned is 0, redeemed is 0.
      free_trip_attrs = Map.merge(valid_trip_attrs(), %{"price" => 0.1})
      {:ok, free_trip} = Trips.create_trip(admin, free_trip_attrs)
      free_instance = hd(free_trip.instances)

      assert {:ok, _purchase} = Trips.purchase_trip_instance(user, free_instance.id)

      log =
        Repo.one!(
          from l in PointLog,
            where: l.user_id == ^user.id,
            order_by: [desc: l.inserted_at],
            limit: 1
        )

      assert log.change_amount == 0
      assert log.reason == "trip_purchase"
    end

    # --- Negative Scenarios ---

    test "FR-25: No points earned if purchase fails (Sold Out)" do
      admin = admin_fixture()
      # Create trip with valid tickets first
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())
      instance = hd(trip.instances)

      # Update instance to have 0 tickets
      {:ok, instance} =
        instance
        |> Ecto.Changeset.change(available_tickets: 0)
        |> Repo.update()

      user = create_regular_user()

      assert {:error, :sold_out} = Trips.purchase_trip_instance(user, instance.id)

      updated_user = Repo.get!(User, user.id)
      assert updated_user.loyalty_points == 0
    end

    test "FR-25: No points earned if purchase fails (Past Trip)" do
      admin = admin_fixture()
      # Create past trip manually to bypass validation if needed, or use helper
      # Here we use a past date string if the helper supports it, or manipulate DB
      past_date = Date.utc_today() |> Date.add(-5) |> Date.to_iso8601()
      attrs = valid_trip_attrs() |> Map.put("dates", past_date)

      # Note: create_trip might validate dates, but let's try.
      # If create_trip fails on past dates, we insert manually.
      # Based on previous context, create_trip allows creating past trips (for history).
      {:ok, trip} = Trips.create_trip(admin, attrs)
      instance = hd(trip.instances)
      user = create_regular_user()

      assert {:error, :past_instance} = Trips.purchase_trip_instance(user, instance.id)

      updated_user = Repo.get!(User, user.id)
      assert updated_user.loyalty_points == 0
    end

    test "FR-26: User with 0 points cannot get discount even if requested" do
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

    # --- Edge Cases ---

    test "FR-25: Free trip earns 0 points" do
      admin = admin_fixture()
      # Create valid trip first
      {:ok, trip} = Trips.create_trip(admin, valid_trip_attrs())

      # Force update price to 0.0 (bypassing standard validations if necessary for test)
      {:ok, trip} =
        trip
        |> Ecto.Changeset.change(price: Decimal.new("0.0"))
        |> Repo.update()

      instance = hd(trip.instances)
      user = create_regular_user()

      assert {:ok, purchase} = Trips.purchase_trip_instance(user, instance.id)

      assert purchase.points_earned == 0
      updated_user = Repo.get!(User, user.id)
      assert updated_user.loyalty_points == 0
    end

    test "FR-26: User has exactly enough points for max discount" do
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

    test "FR-26: User has points but chooses NOT to redeem" do
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

  defp set_points(user, points) do
    user
    |> Ecto.Changeset.change(loyalty_points: points)
    |> Repo.update!()
  end
end
