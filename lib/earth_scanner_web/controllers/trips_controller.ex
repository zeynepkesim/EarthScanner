defmodule EarthScannerWeb.TripsController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Trips.TripInstance
  alias EarthScanner.Repo
  import Ecto.Query

  plug :require_authenticated_user

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    # Get all future trips
    today = Date.utc_today()

    trips =
      from(t in Trip,
        join: i in TripInstance,
        on: i.trip_id == t.id and i.date >= ^today,
        distinct: true,
        order_by: [asc: t.departure_time]
      )
      |> Repo.all()
      |> Trips.preload_future_instances()

    purchase_summary = Trips.purchase_summary_for_user(current_user)

    render(conn, :index,
      trips: trips,
      purchase_summary: purchase_summary
    )
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    case Trips.get_trip_for_user(current_user, id) do
      {:ok, trip} ->
        trip = Trips.preload_future_instances(trip)
        purchase_summary = Trips.purchase_summary_for_user(current_user)
        similar_trips = Trips.find_similar_trips(trip)

        render(conn, :show,
          trip: trip,
          purchase_summary: purchase_summary,
          similar_trips: similar_trips,
          return_path: "/trips"
        )

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Trip not found")
        |> redirect(to: ~p"/trips")
        |> halt()

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You are not allowed to access this trip")
        |> redirect(to: ~p"/trips")
        |> halt()
    end
  end

  defp require_authenticated_user(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to view trips")
        |> redirect(to: ~p"/users/login")
        |> halt()

      _ ->
        conn
    end
  end
end
