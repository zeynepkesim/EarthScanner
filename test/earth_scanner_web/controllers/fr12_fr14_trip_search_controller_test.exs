# FR-12
# nfr-08: TDD - verifies authenticated search behavior (positive/negative)
defmodule EarthScannerWeb.TripSearchControllerTest do
  use EarthScannerWeb.ConnCase

  alias EarthScanner.Trips
  alias EarthScanner.Purchases.Purchase
  alias EarthScanner.Repo

  setup %{conn: conn} do
    {:ok, admin} = create_admin()

    {:ok, trip} =
      Trips.create_trip(admin, %{
        "transport_mode" => "train",
        "source_city" => "Tallinn",
        "destination_city" => "Riga",
        "departure_time" => "2025-11-10T09:00:00Z",
        "arrival_time" => "2025-11-10T12:00:00Z",
        "price" => "90.00",
        "co2_level" => "80",
        "available_tickets" => "5",
        "dates" => Date.utc_today() |> Date.add(10) |> Date.to_iso8601()
      })

    {:ok, user} = create_regular_user(%{username: "search_user", email: "search@test.com"})

    {:ok, conn: conn, trip: trip, instance: hd(trip.instances), user: user}
  end

  test "FR-12: marks previously purchased trips in the search results", %{
    conn: conn,
    trip: trip,
    instance: instance,
    user: user
  } do
    Repo.insert!(%Purchase{user_id: user.id, trip_instance_id: instance.id})

    conn = log_in_user(conn, user)

    conn =
      get(
        conn,
        ~p"/search/results?source=#{trip.source_city}&destination=#{trip.destination_city}"
      )

    html = html_response(conn, 200)
    assert html =~ "Purchased"
  end

  test "FR-14: shows purchased badge and legend for current user only", %{
    conn: conn,
    trip: trip,
    instance: instance,
    user: user
  } do
    Repo.insert!(%Purchase{user_id: user.id, trip_instance_id: instance.id})

    conn = log_in_user(conn, user)

    conn =
      get(
        conn,
        ~p"/search/results?source=#{trip.source_city}&destination=#{trip.destination_city}"
      )

    html = html_response(conn, 200)
    assert html =~ ~s(data-role="purchased-badge")
    assert html =~ ~s(id="search-results-legend")
  end

  test "FR-14: hides purchased badge for other users and guests", %{
    conn: conn,
    trip: trip,
    instance: instance,
    user: user
  } do
    Repo.insert!(%Purchase{user_id: user.id, trip_instance_id: instance.id})

    {:ok, other_user} =
      create_regular_user(%{username: "other_search_user", email: "other_search@test.com"})

    conn = log_in_user(conn, other_user)

    conn =
      get(
        conn,
        ~p"/search/results?source=#{trip.source_city}&destination=#{trip.destination_city}"
      )

    html = html_response(conn, 200)
    refute html =~ ~s(data-role="purchased-badge")

    guest_conn =
      get(
        build_conn(),
        ~p"/search/results?source=#{trip.source_city}&destination=#{trip.destination_city}"
      )

    # Guests are no longer allowed to perform searches (nfr-08)
    assert redirected_to(guest_conn) == ~p"/"
    assert get_flash(guest_conn, :error) =~ "Please log in"
  end

  defp create_admin(attrs \\ %{}) do
    default_attrs = %{
      username: "admin_search",
      password: "password123",
      password_confirmation: "password123",
      email: "admin_search@test.com",
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
      username: "regular_search",
      password: "password123",
      password_confirmation: "password123",
      name: "Jane",
      last_name: "Doe",
      email: "regular_search@test.com",
      birthdate: ~D[1992-02-02],
      nationality: "US",
      residence_address: "123 Main St",
      phone_number: "5555555555"
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
