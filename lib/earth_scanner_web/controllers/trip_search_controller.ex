defmodule EarthScannerWeb.TripSearchController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips
  alias EarthScanner.Searches

  # STEP 2A — render empty search form
  def new(conn, _params) do
    current_user = conn.assigns[:current_user]
    recent_searches = (current_user && Searches.get_recent_searches(current_user)) || []

    render(conn, :new, recent_searches: recent_searches)
  end

  # STEP 2B — basic validation for source & destination
  def index(conn, %{"source" => source, "destination" => destination} = params) do
    cond do
      source in [nil, ""] or destination in [nil, ""] ->
        conn
        |> put_flash(:error, "Source and destination are required")
        |> redirect(to: ~p"/search")

      true ->
        # Record the search if user is logged in
        current_user = conn.assigns[:current_user]

        if current_user do
          Searches.record_search(current_user, source, destination)
        end

        all_trips = Trips.search(params)

        # Pagination in-controller
        page =
          case params["page"] do
            p when is_binary(p) ->
              case Integer.parse(p) do
                {i, _} when i > 0 -> i
                _ -> 1
              end

            p when is_integer(p) and p > 0 ->
              p

            _ ->
              1
          end

        per_page =
          case params["per_page"] do
            p when is_binary(p) ->
              case Integer.parse(p) do
                {i, _} when i > 0 -> i
                _ -> 10
              end

            p when is_integer(p) and p > 0 ->
              p

            _ ->
              10
          end

        total = length(all_trips)
        offset = (page - 1) * per_page
        trips = Enum.slice(all_trips, offset, per_page) || []
        result = %{trips: trips, total: total, page: page, per_page: per_page}
        purchase_summary = Trips.purchase_summary_for_user(current_user)
        recent_searches = (current_user && Searches.get_recent_searches(current_user)) || []

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
          recent_searches: recent_searches,
          sold_out_trip_ids: sold_out_trip_ids,
          top_trips: top_trips,
          return_path: current_path(conn, conn.params)
        )
    end
  end

  # If params missing entirely
  def index(conn, _params) do
    conn
    |> put_flash(:error, "Source and destination are required")
    |> redirect(to: ~p"/search")
  end
end
