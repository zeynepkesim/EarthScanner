defmodule EarthScannerWeb.TripsController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  @doc """
  Public index of upcoming trips.
  """
  def index(conn, _params) do
    trips =
      Trips.search_future_trips("%", "%")
      |> Trips.preload_future_instances()

    purchase_summary = Trips.purchase_summary_for_user(conn.assigns[:current_user])

    render(conn, :index, trips: trips, purchase_summary: purchase_summary)
  end

  def show(conn, %{"id" => id}) do
    trip = id |> String.to_integer() |> Trips.get_public_trip!()
    purchase_summary = Trips.purchase_summary_for_user(conn.assigns[:current_user])

    render(conn, :show,
      trip: trip,
      purchase_summary: purchase_summary,
      return_path: ~p"/trips/#{trip.id}"
    )
  end
end
