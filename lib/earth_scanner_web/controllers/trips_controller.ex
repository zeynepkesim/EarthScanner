defmodule EarthScannerWeb.TripsController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  # Require authentication for all actions
  plug :require_authenticated_user

  def index(conn, _params) do
    # Show public trips listing
    # Implementation depends on your existing code
    render(conn, :index)
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    case Trips.get_trip_for_user(current_user, id) do
      {:ok, trip} ->
        # User is authorized to view this trip
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
