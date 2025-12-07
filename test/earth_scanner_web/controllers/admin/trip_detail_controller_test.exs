defmodule EarthScannerWeb.Admin.TripDetailControllerTest do
  use EarthScannerWeb.ConnCase

  alias EarthScanner.Trips
  alias EarthScanner.Accounts
  alias EarthScanner.Purchases.Purchase
  alias EarthScanner.Repo

  setup do
    {:ok, admin} = create_admin()
    # Use dates relative to now so tests don't break when run at different times
    departure_dt = DateTime.add(DateTime.utc_now(), 2 * 24 * 3600, :second)
    arrival_dt = DateTime.add(departure_dt, 6 * 3600, :second)
    date_str = Date.to_iso8601(Date.add(Date.utc_today(), 2))

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "picture_url" => "https://via.placeholder.com/150",
        "transport_mode" => "plane",
        "source_city" => "NYC",
        "destination_city" => "LA",
        "departure_time" => DateTime.to_iso8601(departure_dt),
        "arrival_time" => DateTime.to_iso8601(arrival_dt),
        "price" => "400.00",
        "co2_level" => "200",
        "available_tickets" => "150",
        "dates" => date_str
      })

    %{admin: admin, trip: trip}
  end

  describe "show/2 (FR-35)" do
    test "displays trip details for authorized admin", %{conn: conn, admin: admin, trip: trip} do
      conn = log_in_user(conn, admin)
      conn = get(conn, ~p"/admin/trips/#{trip.id}")

      assert html_response(conn, 200) =~ "NYC"
      assert html_response(conn, 200) =~ "LA"
      assert html_response(conn, 200) =~ "plane"
      assert html_response(conn, 200) =~ "$400.00"
    end

    test "redirects unauthorized admin", %{conn: conn, trip: trip} do
      {:ok, other_admin} = create_admin(%{username: "other", email: "other@test.com"})
      conn = log_in_user(conn, other_admin)
      conn = get(conn, ~p"/admin/trips/#{trip.id}")

      assert redirected_to(conn) == ~p"/admin/trips"
      assert get_flash(conn, :error) =~ "not authorized"
    end

    test "redirects non-admin users", %{conn: conn, trip: trip} do
      {:ok, regular_user} = create_regular_user()
      conn = log_in_user(conn, regular_user)
      conn = get(conn, ~p"/admin/trips/#{trip.id}")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "delete/2 (FR-33)" do
    test "deletes trip without sold tickets", %{conn: conn, admin: admin, trip: trip} do
      conn = log_in_user(conn, admin)
      conn = delete(conn, ~p"/admin/trips/#{trip.id}")

      assert redirected_to(conn) == ~p"/admin/trips"
      assert get_flash(conn, :info) =~ "deleted successfully"
      assert_raise Ecto.NoResultsError, fn -> Trips.get_trip!(trip.id) end
    end
  end

  describe "confirm_delete/2 (FR-33)" do
    test "shows confirmation page for trip with sold tickets", %{
      conn: conn,
      admin: admin,
      trip: trip
    } do
      {:ok, user} = create_regular_user()
      instance = hd(trip.instances)

      Repo.insert!(%Purchase{
        user_id: user.id,
        trip_instance_id: instance.id
      })

      conn = log_in_user(conn, admin)
      conn = get(conn, ~p"/admin/trips/#{trip.id}/confirm-delete")

      assert html_response(conn, 200) =~ "Confirm Trip Deletion"
      assert html_response(conn, 200) =~ "sold tickets"
    end
  end

  describe "force_delete/2 (FR-33)" do
    test "force deletes trip with sold tickets", %{conn: conn, admin: admin, trip: trip} do
      {:ok, user} = create_regular_user()
      instance = hd(trip.instances)

      Repo.insert!(%Purchase{
        user_id: user.id,
        trip_instance_id: instance.id
      })

      conn = log_in_user(conn, admin)
      conn = post(conn, ~p"/admin/trips/#{trip.id}/force-delete")

      assert redirected_to(conn) == ~p"/admin/trips"
      assert get_flash(conn, :info) =~ "deleted successfully"
      assert_raise Ecto.NoResultsError, fn -> Trips.get_trip!(trip.id) end
    end
  end

  # Helper functions
  defp create_admin(attrs \\ %{}) do
    default_attrs = %{
      username: "admin_test",
      password: "password123",
      password_confirmation: "password123",
      email: "admin_test@test.com",
      phone_number: "1234567890",
      role: "admin"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    changeset =
      EarthScanner.Accounts.User.admin_changeset(%EarthScanner.Accounts.User{}, merged_attrs)

    case EarthScanner.Repo.insert(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp create_regular_user(attrs \\ %{}) do
    default_attrs = %{
      username: "regular_test",
      password: "password123",
      password_confirmation: "password123",
      name: "Test",
      last_name: "User",
      email: "regular_test@test.com",
      birthdate: ~D[1995-05-15],
      nationality: "USA",
      residence_address: "456 Test Ave",
      phone_number: "9876543210"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    changeset =
      EarthScanner.Accounts.User.registration_changeset(
        %EarthScanner.Accounts.User{},
        merged_attrs
      )

    case EarthScanner.Repo.insert(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp log_in_user(conn, user) do
    conn
    |> init_test_session(%{})
    |> put_session(:user_id, user.id)
    |> EarthScannerWeb.FetchCurrentUser.call([])
  end
end
