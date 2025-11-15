defmodule EarthScannerWeb.TripController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip

  plug :require_admin

  defp require_admin(conn, _opts) do
    case conn.assigns[:current_user] do
      %{role: "admin"} ->
        conn

      _ ->
        conn
        |> put_flash(:error, "You must be an admin to access this page.")
        |> redirect(to: ~p"/")
        |> halt()
    end
  end

  # FR-29: show admin's future trips
  def index(conn, _params) do
    admin = conn.assigns.current_user
    trips = Trips.list_future_trips_for_admin(admin)

    render(conn, :index, trips: trips)
  end

  def new(conn, _params) do
    changeset = Trip.changeset(%Trip{}, %{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"trip" => trip_params}) do
    admin = conn.assigns.current_user

    case Trips.create_trip(admin, trip_params) do
      {:ok, trip} ->
        conn
        |> put_flash(:info, "Trip created successfully.")
        |> redirect(to: ~p"/admin/trips")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
