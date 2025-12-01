defmodule EarthScannerWeb.UserTripsController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  def index(conn, params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "Please log in to view your trips.")
        |> redirect(to: ~p"/users/login")

      user ->
        tab = normalize_tab(params["tab"])
        partitions = Trips.partition_purchases_by_departure(user.id)

        render(conn, :index,
          page_title: "My Trips",
          tab: tab,
          upcoming_entries: partitions.upcoming,
          past_entries: partitions.past
        )
    end
  end

  defp normalize_tab("past"), do: "past"
  defp normalize_tab(_), do: "upcoming"
end
