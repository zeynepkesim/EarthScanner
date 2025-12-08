defmodule EarthScanner.TripsTest do
  use EarthScanner.DataCase
  @moduletag :skip

  alias EarthScanner.Trips
  alias EarthScanner.Trips.{Trip, TripInstance}
  alias EarthScanner.Accounts
  alias EarthScanner.Accounts.User
  alias EarthScanner.Purchases.Purchase

  defp admin_fixture(attrs \\ %{}) do
    unique_email = "admin_#{System.unique_integer([:positive])}@example.com"
    unique_username = "admin_user_#{System.unique_integer([:positive])}"

    {:ok, admin} =
      Accounts.register_user(
        Map.merge(
          %{
            "username" => unique_username,
            "password" => "Password123!",
            "password_confirmation" => "Password123!",
            "name" => "Admin",
            "last_name" => "User",
            "email" => unique_email,
            "birthdate" => "1990-01-01",
            "nationality" => "TR",
            "residence_address" => "Admin Street",
            "phone_number" => "+905551111111"
          },
          attrs
        )
      )

    admin
  end

  defp valid_trip_attrs do
    %{
      "picture_url" => "https://example.com/pic.jpg",
      "transport_mode" => "plane",
      "source_city" => "Tallinn",
      "destination_city" => "Paris",
      "departure_time" => "2025-11-20T10:00:00Z",
      "arrival_time" => "2025-11-20T13:00:00Z",
      "price" => "150.0",
      "co2_level" => "200",
      "available_tickets" => "50",
      "dates" => "2025-11-21\n2025-11-28"
    }
  end

  describe "list_future_trips_for_admin/1" do
    # FR-29
    test "returns only trips for the given admin that have future instances" do
      admin1 = admin_fixture(%{"username" => "admin1", "email" => "admin1@example.com"})
      admin2 = admin_fixture(%{"username" => "admin2", "email" => "admin2@example.com"})

      future1 = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
      future2 = Date.utc_today() |> Date.add(2) |> Date.to_iso8601()

      {:ok, trip1} =
        Trips.create_trip(admin1, valid_trip_attrs() |> Map.put("dates", future1))

      {:ok, _trip2} =
        Trips.create_trip(admin2, valid_trip_attrs() |> Map.put("dates", future2))

      result = Trips.list_future_trips_for_admin(admin1)

      assert Enum.any?(result, &(&1.id == trip1.id))
      refute Enum.any?(result, &(&1.admin_id == admin2.id))
    end
  end

  describe "get_trip_for_admin/2 (FR-35)" do
    setup do
      # AC-FR35-01: Admin can view details of trips they created
      {:ok, admin} = create_admin()
      {:ok, other_admin} = create_admin(%{username: "other_admin", email: "other@test.com"})

      {:ok, trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "plane",
          "source_city" => "New York",
          "destination_city" => "London",
          "departure_time" => "2025-12-01T10:00:00Z",
          "arrival_time" => "2025-12-01T22:00:00Z",
          "price" => "500.00",
          "co2_level" => "250",
          "available_tickets" => "100",
          "dates" => "2025-12-01"
        })

      %{admin: admin, other_admin: other_admin, trip: trip}
    end

    test "returns trip with all details for authorized admin", %{admin: admin, trip: trip} do
      # AC-FR35-02: Displays all trip attributes
      assert {:ok, fetched_trip} = Trips.get_trip_for_admin(trip.id, admin)
      assert fetched_trip.id == trip.id
      assert fetched_trip.source_city == "New York"
      assert fetched_trip.destination_city == "London"
      assert fetched_trip.transport_mode == "plane"
      assert Decimal.eq?(fetched_trip.price, Decimal.new("500.00"))
      assert fetched_trip.co2_level == 250
      assert fetched_trip.duration_minutes == 720
      assert length(fetched_trip.instances) == 1
    end

    test "returns error for non-existent trip", %{admin: admin} do
      # AC-FR35-04: Returns error if trip doesn't exist
      assert {:error, :not_found} = Trips.get_trip_for_admin(99999, admin)
    end

    test "returns error when admin tries to view another admin's trip", %{
      other_admin: other_admin,
      trip: trip
    } do
      # AC-FR35-03: Only creator can view trip details
      assert {:error, :unauthorized} = Trips.get_trip_for_admin(trip.id, other_admin)
    end
  end

  describe "delete_trip/2 (FR-33)" do
    setup do
      {:ok, admin} = create_admin()

      {:ok, future_trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "Paris",
          "destination_city" => "Berlin",
          "departure_time" => "2025-12-15T08:00:00Z",
          "arrival_time" => "2025-12-15T18:00:00Z",
          "price" => "100.00",
          "co2_level" => "50",
          "available_tickets" => "40",
          "dates" => "2025-12-15"
        })

      {:ok, past_trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "train",
          "source_city" => "Madrid",
          "destination_city" => "Barcelona",
          "departure_time" => "2024-01-01T09:00:00Z",
          "arrival_time" => "2024-01-01T12:00:00Z",
          "price" => "50.00",
          "co2_level" => "20",
          "available_tickets" => "60",
          "dates" => "2024-01-01"
        })

      %{admin: admin, future_trip: future_trip, past_trip: past_trip}
    end

    test "successfully deletes future trip without sold tickets", %{
      admin: admin,
      future_trip: trip
    } do
      # AC-FR33-01: Only future trips can be deleted
      # AC-FR33-02: Confirmation prompt required (handled in controller)
      assert {:ok, deleted_trip} = Trips.delete_trip(trip.id, admin)
      assert deleted_trip.id == trip.id
      assert_raise Ecto.NoResultsError, fn -> Trips.get_trip!(trip.id) end
    end

    test "returns error when trying to delete past trip", %{admin: admin, past_trip: trip} do
      # AC-FR33-01: Only future trips can be deleted
      assert {:error, :past_trip} = Trips.delete_trip(trip.id, admin)
      # Trip should still exist
      assert Trips.get_trip!(trip.id)
    end

    test "returns error when trip has sold tickets", %{admin: admin, future_trip: trip} do
      # AC-FR33-03: Warning if tickets have been sold
      {:ok, regular_user} = create_regular_user()

      # Create a purchase
      instance = hd(trip.instances)

      Repo.insert!(%Purchase{
        user_id: regular_user.id,
        trip_instance_id: instance.id
      })

      assert {:error, :has_sold_tickets} = Trips.delete_trip(trip.id, admin)
      # Trip should still exist
      assert Trips.get_trip!(trip.id)
    end

    test "returns error for non-existent trip", %{admin: admin} do
      assert {:error, :not_found} = Trips.delete_trip(99999, admin)
    end

    test "returns error when admin tries to delete another admin's trip", %{future_trip: trip} do
      {:ok, other_admin} = create_admin(%{username: "other", email: "other@test.com"})
      assert {:error, :unauthorized} = Trips.delete_trip(trip.id, other_admin)
    end
  end

  describe "force_delete_trip/2 (FR-33)" do
    setup do
      {:ok, admin} = create_admin()

      {:ok, trip_with_tickets} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "plane",
          "source_city" => "Tokyo",
          "destination_city" => "Seoul",
          "departure_time" => "2025-12-20T14:00:00Z",
          "arrival_time" => "2025-12-20T17:00:00Z",
          "price" => "300.00",
          "co2_level" => "150",
          "available_tickets" => "200",
          "dates" => "2025-12-20"
        })

      {:ok, regular_user} = create_regular_user()
      instance = hd(trip_with_tickets.instances)

      Repo.insert!(%Purchase{
        user_id: regular_user.id,
        trip_instance_id: instance.id
      })

      %{admin: admin, trip: trip_with_tickets}
    end

    test "force deletes trip with sold tickets after explicit confirmation", %{
      admin: admin,
      trip: trip
    } do
      # AC-FR33-04: Admin must confirm explicitly if tickets sold
      # AC-FR33-05: Associated purchased tickets are handled (deleted via cascade)
      assert {:ok, deleted_trip} = Trips.force_delete_trip(trip.id, admin)
      assert deleted_trip.id == trip.id
      assert_raise Ecto.NoResultsError, fn -> Trips.get_trip!(trip.id) end

      # Verify purchases for this trip are also deleted
      purchases_for_trip =
        from(p in Purchase,
          join: i in TripInstance,
          on: p.trip_instance_id == i.id,
          where: i.trip_id == ^trip.id
        )
        |> Repo.all()

      assert purchases_for_trip == []
    end
  end

  describe "trip_has_sold_tickets?/1" do
    test "returns true when trip has sold tickets" do
      {:ok, admin} = create_admin()

      {:ok, trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "A",
          "destination_city" => "B",
          "departure_time" => "2025-12-25T10:00:00Z",
          "arrival_time" => "2025-12-25T15:00:00Z",
          "price" => "75.00",
          "co2_level" => "30",
          "available_tickets" => "50",
          "dates" => "2025-12-25"
        })

      {:ok, user} = create_regular_user()
      instance = hd(trip.instances)

      Repo.insert!(%Purchase{
        user_id: user.id,
        trip_instance_id: instance.id
      })

      assert Trips.trip_has_sold_tickets?(trip.id) == true
    end

    test "returns false when trip has no sold tickets" do
      {:ok, admin} = create_admin()

      {:ok, trip} =
        Trips.create_trip(admin, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "train",
          "source_city" => "C",
          "destination_city" => "D",
          "departure_time" => "2025-12-30T08:00:00Z",
          "arrival_time" => "2025-12-30T11:00:00Z",
          "price" => "60.00",
          "co2_level" => "25",
          "available_tickets" => "80",
          "dates" => "2025-12-30"
        })

      assert Trips.trip_has_sold_tickets?(trip.id) == false
    end
  end

  # FR-12
  describe "purchase_trip_instance/2" do
    test "FR-12: successfully purchases a future trip instance and decrements tickets" do
      admin = admin_fixture()
      future_date = Date.utc_today() |> Date.add(5) |> Date.to_iso8601()

      {:ok, trip} =
        Trips.create_trip(admin, valid_trip_attrs() |> Map.put("dates", future_date))

      instance = hd(trip.instances)

      {:ok, user} =
        create_regular_user(%{
          username: "buyer_#{System.unique_integer([:positive])}",
          email: "buyer_#{System.unique_integer([:positive])}@test.com"
        })

      assert {:ok, purchase} = Trips.purchase_trip_instance(user, instance.id)
      assert purchase.trip_instance_id == instance.id
      assert purchase.user_id == user.id

      updated_instance = Repo.get!(TripInstance, instance.id)
      assert updated_instance.available_tickets == instance.available_tickets - 1
    end

    test "FR-12: prevents purchasing trip instances that are already in the past" do
      admin = admin_fixture()
      past_date = Date.utc_today() |> Date.add(-3) |> Date.to_iso8601()

      {:ok, trip} =
        Trips.create_trip(admin, valid_trip_attrs() |> Map.put("dates", past_date))

      instance = hd(trip.instances)

      {:ok, user} =
        create_regular_user(%{
          username: "late_buyer_#{System.unique_integer([:positive])}",
          email: "late_buyer_#{System.unique_integer([:positive])}@test.com"
        })

      assert {:error, :past_instance} = Trips.purchase_trip_instance(user, instance.id)
    end

    test "FR-12: prevents purchasing sold out instances" do
      admin = admin_fixture()
      future_date = Date.utc_today() |> Date.add(4) |> Date.to_iso8601()

      {:ok, trip} =
        Trips.create_trip(
          admin,
          valid_trip_attrs()
          |> Map.put("dates", future_date)
          |> Map.put("available_tickets", "1")
        )

      instance = hd(trip.instances)

      {:ok, first_user} =
        create_regular_user(%{
          username: "solo_buyer_#{System.unique_integer([:positive])}",
          email: "solo_buyer_#{System.unique_integer([:positive])}@test.com"
        })

      {:ok, second_user} =
        create_regular_user(%{
          username: "late_solo_#{System.unique_integer([:positive])}",
          email: "late_solo_#{System.unique_integer([:positive])}@test.com"
        })

      assert {:ok, _purchase} = Trips.purchase_trip_instance(first_user, instance.id)

      assert {:error, :sold_out} = Trips.purchase_trip_instance(second_user, instance.id)

      reloaded = Repo.get!(TripInstance, instance.id)
      assert reloaded.available_tickets == 0
    end
  end

  describe "return_trip_instance_purchase/2" do
    test "FR-13: increments available tickets and removes purchase marker for future trips" do
      admin = admin_fixture()
      future_date = Date.utc_today() |> Date.add(7) |> Date.to_iso8601()

      {:ok, trip} =
        Trips.create_trip(admin, valid_trip_attrs() |> Map.put("dates", future_date))

      instance = hd(trip.instances)

      {:ok, user} =
        create_regular_user(%{
          username: "ref_under_test_#{System.unique_integer([:positive])}",
          email: "ref_under_test_#{System.unique_integer([:positive])}@test.com"
        })

      {:ok, _purchase} = Trips.purchase_trip_instance(user, instance.id)

      summary = Trips.purchase_summary_for_user(user)
      assert MapSet.member?(summary.instance_ids, instance.id)

      assert {:ok, _refund} = Trips.return_trip_instance_purchase(user, instance.id)

      reloaded_instance = Repo.get!(TripInstance, instance.id)
      assert reloaded_instance.available_tickets == instance.available_tickets

      refreshed_summary = Trips.purchase_summary_for_user(user)
      refute MapSet.member?(refreshed_summary.instance_ids, instance.id)
      refute MapSet.member?(refreshed_summary.trip_ids, trip.id)
    end

    test "FR-13: only allows refunds for future trip instances" do
      admin = admin_fixture()
      past_date = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()

      {:ok, trip} =
        Trips.create_trip(admin, valid_trip_attrs() |> Map.put("dates", past_date))

      instance = hd(trip.instances)
      {:ok, user} = create_regular_user(%{username: "past_ref", email: "past_ref@test.com"})

      Repo.insert!(%Purchase{user_id: user.id, trip_instance_id: instance.id})

      assert {:error, :past_instance} = Trips.return_trip_instance_purchase(user, instance.id)
    end

    test "FR-13: returns error when user attempts to refund a trip they did not purchase" do
      admin = admin_fixture()
      future_date = Date.utc_today() |> Date.add(3) |> Date.to_iso8601()

      {:ok, trip} =
        Trips.create_trip(admin, valid_trip_attrs() |> Map.put("dates", future_date))

      instance = hd(trip.instances)
      {:ok, user} = create_regular_user(%{username: "no_purchase", email: "no_purchase@test.com"})

      assert {:error, :not_found} = Trips.return_trip_instance_purchase(user, instance.id)
    end
  end

  # Helper functions
  defp create_admin(attrs \\ %{}) do
    default_attrs = %{
      username: "admin_user",
      password: "password123",
      password_confirmation: "password123",
      email: "admin@test.com",
      phone_number: "1234567890",
      role: "admin"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    # Insert directly into database with role already set
    changeset =
      EarthScanner.Accounts.User.admin_changeset(%EarthScanner.Accounts.User{}, merged_attrs)

    case Repo.insert(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp create_regular_user(attrs \\ %{}) do
    default_attrs = %{
      username: "regular_user",
      password: "password123",
      password_confirmation: "password123",
      name: "John",
      last_name: "Doe",
      email: "user@test.com",
      birthdate: ~D[1990-01-01],
      nationality: "US",
      residence_address: "123 Main St",
      phone_number: "0987654321"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    changeset =
      EarthScanner.Accounts.User.registration_changeset(
        %EarthScanner.Accounts.User{},
        merged_attrs
      )

    case Repo.insert(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
