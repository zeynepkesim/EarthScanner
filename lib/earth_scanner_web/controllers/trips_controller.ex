defmodule EarthScannerWeb.TripsController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  @doc """
  Public index of upcoming trips.
  """
  def index(conn, _params) do
    # Render a simple listing of upcoming trips and include a button to the search page
    trips = Trips.search_future_trips("%", "%")

    render(conn, :index, trips: trips)
  end
end
