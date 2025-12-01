defmodule EarthScannerWeb.UserTripsControllerTest do
  use EarthScannerWeb.ConnCase, async: true

  alias EarthScanner.{Accounts, Trips, Repo}
  alias Ecto.Changeset

  describe "GET /my-trips" do
    test "redirects guests to the login form", %{conn: conn} do
      conn = get(conn, ~p"/my-trips")
      assert redirected_to(conn) == ~p"/users/login"
      assert get_flash(conn, :error) =~ "Please log in"
    end

    test "shows separate upcoming and past purchases for the logged-in user", %{conn: conn} do
      admin = admin_fixture()
      user = user_fixture()

      {:ok, future_trip} = Trips.create_trip(admin, future_trip_attrs())
      {:ok, past_trip} = Trips.create_trip(admin, past_trip_attrs())

      future_instance = hd(future_trip.instances)
      past_instance = hd(past_trip.instances)

      {:ok, _purchase} = Trips.purchase_trip_instance(user, future_instance.id)
      {:ok, _purchase} = Trips.purchase_trip_instance(user, past_instance.id)

      mark_instance_as_past(past_instance)

      conn = log_in(conn, user)
      conn = get(conn, ~p"/my-trips")

      html = html_response(conn, 200)
      assert html =~ "Upcoming trips"
      assert html =~ future_trip.source_city
      assert html =~ "Past trips"
      assert html =~ past_trip.source_city
    end

    test "cover the past tab toggle", %{conn: conn} do
      admin = admin_fixture()
      user = user_fixture()

      {:ok, past_trip} = Trips.create_trip(admin, past_trip_attrs())
      past_instance = hd(past_trip.instances)
      {:ok, _purchase} = Trips.purchase_trip_instance(user, past_instance.id)

      mark_instance_as_past(past_instance)

      conn = log_in(conn, user)
      conn = get(conn, ~p"/my-trips?tab=past")

      html = html_response(conn, 200)
      assert html =~ "Past trips"
      assert html =~ ~r/id=\"past-list\"[\s\S]*class=\"space-y-4 block\"/
    end
  end

  defp user_fixture(overrides \\ %{}) do
    unique = System.unique_integer([:positive]) |> Integer.to_string()

    base_attrs = %{
      "username" => "user_#{unique}",
      "password" => "Password123!",
      "password_confirmation" => "Password123!",
      "name" => "User",
      "last_name" => "Test",
      "email" => "user_#{unique}@example.com",
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "Test Street",
      "phone_number" => "+372#{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(base_attrs, overrides))
    user
  end

  defp admin_fixture do
    user = user_fixture()

    {:ok, admin} =
      user
      |> Ecto.Changeset.change(%{role: "admin"})
      |> Repo.update()

    admin
  end

  defp future_trip_attrs do
    departure = DateTime.add(DateTime.utc_now(), 3600, :second)

    %{
      "transport_mode" => "train",
      "source_city" => "Tallinn",
      "destination_city" => "Riga",
      "departure_time" => departure,
      "arrival_time" => DateTime.add(departure, 7200, :second),
      "price" => "100.00",
      "co2_level" => "80",
      "available_tickets" => "20",
      "dates" => Date.utc_today() |> Date.add(2) |> Date.to_iso8601()
    }
  end

  defp past_trip_attrs do
    departure = DateTime.add(DateTime.utc_now(), 5400, :second)

    %{
      "transport_mode" => "plane",
      "source_city" => "Paris",
      "destination_city" => "Berlin",
      "departure_time" => departure,
      "arrival_time" => DateTime.add(departure, 7200, :second),
      "price" => "150.00",
      "co2_level" => "120",
      "available_tickets" => "20",
      "dates" => Date.utc_today() |> Date.add(5) |> Date.to_iso8601()
    }
  end

  defp log_in(conn, user) do
    conn
    |> post(~p"/users/login", %{
      "session" => %{"email" => user.email, "password" => "Password123!"}
    })
    |> recycle()
  end

  defp mark_instance_as_past(instance) do
    past_date = Date.utc_today() |> Date.add(-3)

    instance
    |> Changeset.change(%{date: past_date})
    |> Repo.update!()
  end
end
