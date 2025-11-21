# FR-12, FR-13
defmodule EarthScannerWeb.TripPurchaseControllerTest do
  use EarthScannerWeb.ConnCase

  alias EarthScanner.Trips
  alias EarthScanner.Trips.TripInstance
  alias EarthScanner.Repo

  setup %{conn: conn} do
    {:ok, admin} = create_admin()

    future_date = Date.utc_today() |> Date.add(7) |> Date.to_iso8601()

    {:ok, trip} =
      Trips.create_trip(
        admin,
        %{
          "transport_mode" => "plane",
          "source_city" => "Tallinn",
          "destination_city" => "Paris",
          "departure_time" => "2025-12-01T10:00:00Z",
          "arrival_time" => "2025-12-01T16:00:00Z",
          "price" => "200.00",
          "co2_level" => "120",
          "available_tickets" => "1",
          "dates" => future_date
        }
      )

    {:ok, user} = create_regular_user(%{username: "purchase_user", email: "purchase@test.com"})

    {:ok, conn: conn, trip: trip, instance: hd(trip.instances), user: user}
  end

  test "FR-12: creates a purchase when tickets are available", %{conn: conn, trip: trip, instance: instance, user: user} do
    conn = log_in_user(conn, user)

    conn =
      post(conn, ~p"/trips/#{trip.id}/purchase", %{
        "trip_instance_id" => instance.id,
        "redirect_to" => "/search/results?source=Tallinn&destination=Paris"
      })

    assert redirected_to(conn) == "/search/results?source=Tallinn&destination=Paris"
    assert get_flash(conn, :info) =~ "Trip purchased"

    reloaded = Repo.get!(TripInstance, instance.id)
    assert reloaded.available_tickets == instance.available_tickets - 1
  end

  test "FR-12: returns an error flash when tickets are sold out", %{conn: conn, trip: trip, instance: instance} do
    {:ok, first_user} = create_regular_user(%{username: "soldout_a", email: "soldout_a@test.com"})
    {:ok, second_user} = create_regular_user(%{username: "soldout_b", email: "soldout_b@test.com"})

    assert {:ok, _purchase} = Trips.purchase_trip_instance(first_user, instance.id)

    conn = log_in_user(conn, second_user)

    conn =
      post(conn, ~p"/trips/#{trip.id}/purchase", %{
        "trip_instance_id" => instance.id,
        "redirect_to" => "/trips/#{trip.id}"
      })

    assert redirected_to(conn) == "/trips/#{trip.id}"
    assert get_flash(conn, :error) =~ "sold out"
  end

  test "FR-12: redirects guests to the login page", %{conn: conn, trip: trip, instance: instance} do
    conn =
      post(conn, ~p"/trips/#{trip.id}/purchase", %{
        "trip_instance_id" => instance.id,
        "redirect_to" => "/search"
      })

    assert redirected_to(conn) == ~p"/users/login"
  end

  test "FR-13: returns and refunds a future purchase", %{conn: conn, trip: trip, instance: instance, user: user} do
    conn = log_in_user(conn, user)

    conn =
      post(conn, ~p"/trips/#{trip.id}/purchase", %{
        "trip_instance_id" => instance.id,
        "redirect_to" => "/search"
      })

    assert get_flash(conn, :info) =~ "Trip purchased"

    refund_conn =
      delete(conn, ~p"/trips/#{trip.id}/purchase", %{
        "trip_instance_id" => instance.id,
        "redirect_to" => "/search"
      })

    assert redirected_to(refund_conn) == "/search"
    assert get_flash(refund_conn, :info) =~ "Purchase returned"

    reloaded = Repo.get!(TripInstance, instance.id)
    assert reloaded.available_tickets == instance.available_tickets
  end

  test "FR-13: prevents returning past purchases", %{conn: conn, trip: trip, instance: instance, user: user} do
    conn = log_in_user(conn, user)

    conn =
      post(conn, ~p"/trips/#{trip.id}/purchase", %{
        "trip_instance_id" => instance.id,
        "redirect_to" => "/search"
      })

    assert get_flash(conn, :info) =~ "Trip purchased"

    instance
    |> TripInstance.changeset(%{date: Date.utc_today() |> Date.add(-2)})
    |> Repo.update!()

    refund_conn =
      delete(conn, ~p"/trips/#{trip.id}/purchase", %{
        "trip_instance_id" => instance.id,
        "redirect_to" => "/search"
      })

    assert get_flash(refund_conn, :error) =~ "cannot be refunded"
  end

  defp create_admin(attrs \\ %{}) do
    default_attrs = %{
      username: "admin_user",
      password: "password123",
      password_confirmation: "password123",
      email: "admin_user@test.com",
      phone_number: "1234567890",
      role: "admin"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    %EarthScanner.Accounts.User{}
    |> EarthScanner.Accounts.User.admin_changeset(merged_attrs)
    |> Repo.insert()
  end

  defp create_regular_user(attrs \\ %{}) do
    default_attrs = %{
      username: "regular_user",
      password: "password123",
      password_confirmation: "password123",
      name: "John",
      last_name: "Doe",
      email: "regular_user@test.com",
      birthdate: ~D[1990-01-01],
      nationality: "US",
      residence_address: "123 Main St",
      phone_number: "0987654321"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    %EarthScanner.Accounts.User{}
    |> EarthScanner.Accounts.User.registration_changeset(merged_attrs)
    |> Repo.insert()
  end

  defp log_in_user(conn, user) do
    conn
    |> init_test_session(%{})
    |> put_session(:user_id, user.id)
    |> EarthScannerWeb.FetchCurrentUser.call([])
  end
end
