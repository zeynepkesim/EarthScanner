defmodule EarthScannerWeb.Admin.FutureTripsController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  def index(conn, _params) do
    admin = conn.assigns.current_user
    trips = Trips.list_future_trips_for_admin(admin)
    render(conn, :index, trips: trips)
  end

  def show(conn, %{"id" => id}) do
    trip = Trips.get_trip!(id)
    render(conn, :show, trip: trip)
  end
end
