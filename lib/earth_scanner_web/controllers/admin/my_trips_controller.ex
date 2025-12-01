defmodule EarthScannerWeb.Admin.MyTripsController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  # Router already has :require_admin in pipeline, no need to duplicate

  def index(conn, _params) do
    admin = conn.assigns.current_user

    all_trips = Trips.list_all_trips_for_admin(admin)
    future_trips = Trips.list_future_trips_for_admin(admin)
    past_trips = Trips.list_past_trips_by_admin(admin)

    render(conn, :index,
      all_trips: all_trips,
      future_trips: future_trips,
      past_trips: past_trips
    )
  end
end
