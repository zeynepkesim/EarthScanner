defmodule EarthScannerWeb.TripSearchController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  # STEP 2A — render empty search form
  def new(conn, _params) do
    render(conn, :new)
  end

  # STEP 2B — basic validation for source & destination
  def index(conn, %{"source" => source, "destination" => destination} = params) do
    cond do
      source in [nil, ""] or destination in [nil, ""] ->
        conn
        |> put_flash(:error, "Source and destination are required")
        |> redirect(to: ~p"/search")

      true ->
        result = Trips.search_future_trips_paginated(source, destination, params)
        trips = Trips.preload_future_instances(result.trips)
        purchase_summary = Trips.purchase_summary_for_user(conn.assigns[:current_user])

        # FR-15: compute sold-out trip ids for highlighting in the view
        sold_out_trip_ids =
          trips
          |> Enum.filter(fn trip ->
            trip.instances != [] and
              Enum.all?(trip.instances, fn instance -> instance.available_tickets <= 0 end)
          end)
          |> Enum.map(& &1.id)
          |> MapSet.new()

        # FR-10: compute top trips (fastest, cheapest, greenest)
        top_trips = Trips.compute_top_trips(trips)

        render(conn, :index,
          trips: trips,
          total: result.total,
          page: result.page,
          per_page: result.per_page,
          filters: params,
          purchase_summary: purchase_summary,
          sold_out_trip_ids: sold_out_trip_ids,
          top_trips: top_trips,
          return_path: current_path(conn, conn.params)
        )

        # render(conn, :index, trips: trips, filters: params)
    end
  end

  # If params missing entirely
  def index(conn, _params) do
    conn
    |> put_flash(:error, "Source and destination are required")
    |> redirect(to: ~p"/search")
  end
end
