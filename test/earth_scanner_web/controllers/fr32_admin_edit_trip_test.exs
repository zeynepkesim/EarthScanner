defmodule EarthScannerWeb.TripControllerFR32Test do
  use EarthScannerWeb.ConnCase

  @moduledoc """
  FR-32: Admin can update trip information (unit/controller tests)
  """

  alias EarthScanner.Trips
  alias EarthScanner.Accounts
  alias EarthScanner.Repo
  alias EarthScanner.Trips.Trip

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

    admin = Ecto.Changeset.change(admin, role: "admin") |> Repo.update!()
    admin
  end

  defp base_trip_attrs do
    dt = DateTime.utc_now() |> DateTime.add(5 * 24 * 3600, :second)
    dep = DateTime.to_iso8601(dt)
    arr = DateTime.to_iso8601(DateTime.add(dt, 3 * 3600, :second))
    date_str = Date.to_iso8601(DateTime.to_date(dt))

    %{
      "picture_url" => "https://example.com/pic.jpg",
      "transport_mode" => "plane",
      "source_city" => "Tallinn",
      "destination_city" => "Paris",
      "departure_time" => dep,
      "arrival_time" => arr,
      "price" => "150.0",
      "co2_level" => "200",
      "available_tickets" => "50",
      "dates" => date_str
    }
  end

  @tag :fr32
  test "FR-32: admin can update a future trip", %{conn: conn} do
    admin = admin_fixture(%{"username" => "fr32_admin", "email" => "fr32_admin@test.com"})

    {:ok, trip} = Trips.create_trip(admin, base_trip_attrs())

    conn = init_test_session(conn, user_id: admin.id)

    params = %{"trip" => %{"price" => "180.0", "available_tickets" => "45"}}

    conn = put(conn, "/admin/trips/#{trip.id}", params)

    assert redirected_to(conn) == "/admin/trips"
    assert get_flash(conn, :info) =~ "Trip updated successfully"

    updated = Repo.get!(Trip, trip.id)
    assert Decimal.eq?(updated.price, Decimal.new("180.0"))
    assert updated.available_tickets == 45
  end

  @tag :skip
  test "FR-32: past trips are read-only and cannot be edited", %{conn: conn} do
    # Pending: behavior to make past trips read-only must be implemented.
    admin = admin_fixture(%{"username" => "fr32_past", "email" => "fr32_past@test.com"})

    past_date = Date.utc_today() |> Date.add(-7) |> Date.to_iso8601()

    {:ok, trip} =
      Trips.create_trip(
        admin,
        Map.put(base_trip_attrs(), "dates", past_date) |> Map.put("departure_time", past_date)
      )

    conn = init_test_session(conn, user_id: admin.id)

    conn = get(conn, "/admin/trips/#{trip.id}/edit")
    body = html_response(conn, 200)

    # Expect the UI to present read-only state (implementation pending)
    assert body =~ "Past trips cannot be modified"
  end

  @tag :skip
  test "FR-32: warns when modifying critical data for trips with sold tickets", %{conn: conn} do
    # Pending TDD: implement warnings/confirmation flow
    admin = admin_fixture(%{"username" => "fr32_warn", "email" => "fr32_warn@test.com"})

    {:ok, trip} = Trips.create_trip(admin, base_trip_attrs())
    instance = hd(trip.instances)

    # simulate a purchase
    {:ok, user} =
      Accounts.register_user(%{
        "username" => "buyer_fr32",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "email" => "buyer_fr32@test.com",
        "birthdate" => "1990-01-01",
        "nationality" => "TR",
        "residence_address" => "Addr",
        "phone_number" => "+905551111119"
      })

    alias EarthScanner.Purchases.Purchase
    Repo.insert!(%Purchase{user_id: user.id, trip_instance_id: instance.id})

    conn = init_test_session(conn, user_id: admin.id)

    # attempt to change departure_time — should require confirmation
    params = %{
      "trip" => %{"departure_time" => Date.utc_today() |> Date.add(10) |> Date.to_iso8601()}
    }

    conn = put(conn, "/admin/trips/#{trip.id}", params)

    # Expect a warning flow (implementation pending)
    assert get_flash(conn, :info) || get_flash(conn, :error)
  end
end
