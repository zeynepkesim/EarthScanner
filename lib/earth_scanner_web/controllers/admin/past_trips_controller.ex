defmodule EarthScannerWeb.Admin.PastTripsController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  def index(conn, _params) do
    admin = conn.assigns.current_user
    excursions = Trips.list_past_trips_by_admin(admin)
    render(conn, :index, excursions: excursions)
  end

  def show(conn, %{"id" => id}) do
    trip = Trips.get_trip!(id)
    render(conn, :show, trip: trip)
  end
end
