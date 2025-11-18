defmodule EarthScannerWeb.TripController do
  use EarthScannerWeb, :controller
  import Phoenix.Component, only: [to_form: 1]

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

  # FR-29: show admin's all trips (past and future)
  def index(conn, _params) do
    admin = conn.assigns.current_user
    trips = Trips.list_all_trips_for_admin(admin)

    render(conn, :index, trips: trips)
  end

  

  def new(conn, _params) do
    changeset = Trip.changeset(%Trip{}, %{})
    render(conn, :new, form: to_form(changeset))
  end

  def create(conn, %{"trip" => trip_params}) do
    admin = conn.assigns.current_user

    case Trips.create_trip(admin, trip_params) do
      {:ok, _trip} ->
        conn
        |> put_flash(:info, "Trip created successfully.")
        |> redirect(to: ~p"/admin/trips")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, form: to_form(changeset))
    end
  end

  def edit(conn, %{"id" => id}) do
    trip = Trips.get_trip!(id)
    changeset = Trip.changeset(trip, %{})
    render(conn, :edit, form: to_form(changeset), trip: trip)
  end

  def update(conn, %{"id" => id, "trip" => trip_params}) do
    trip = Trips.get_trip!(id)

    case Trips.update_trip(trip, trip_params) do
      {:ok, _trip} ->
        conn
        |> put_flash(:info, "Trip updated successfully.")
        |> redirect(to: ~p"/admin/trips")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, form: to_form(changeset), trip: trip)
    end
  end

  def delete(conn, %{"id" => id}) do
    trip = Trips.get_trip!(id)
    {:ok, _} = Trips.delete_trip(trip)

    conn
    |> put_flash(:info, "Trip deleted successfully.")
    |> redirect(to: ~p"/admin/trips")
  end
end
