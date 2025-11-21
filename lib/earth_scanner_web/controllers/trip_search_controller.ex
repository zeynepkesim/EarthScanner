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

        render(conn, :index,
          trips: trips,
          total: result.total,
          page: result.page,
          per_page: result.per_page,
          filters: params,
          purchase_summary: purchase_summary,
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
