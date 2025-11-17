defmodule EarthScannerWeb.TripInstanceController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

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

  # FR-36: edit a single instance
  def edit(conn, %{"trip_id" => trip_id, "id" => id}) do
    instance =
      Trips.get_trip_instance!(trip_id, id)
      |> EarthScanner.Repo.preload(:trip)

    changeset = EarthScanner.Trips.TripInstance.changeset(instance, %{})
    form = to_form(changeset)

    render(conn, :edit_instance, instance: instance, form: form)
  end

  def update(conn, %{"trip_id" => trip_id, "id" => id, "trip_instance" => params}) do
    instance =
      Trips.get_trip_instance!(trip_id, id)
      |> EarthScanner.Repo.preload(:trip)

    case Trips.update_trip_instance(instance, params) do
      {:ok, _instance} ->
        conn
        |> put_flash(:info, "Trip date updated.")
        |> redirect(to: ~p"/admin/trips")

      {:error, changeset} ->
        form = to_form(changeset)
        render(conn, :edit_instance, instance: instance, form: form)
    end
  end

  def delete(conn, %{"trip_id" => trip_id, "id" => id}) do
    instance = Trips.get_trip_instance!(trip_id, id)

    {:ok, _} = Trips.delete_trip_instance(instance)

    conn
    |> put_flash(:info, "Trip date deleted.")
    |> redirect(to: ~p"/admin/trips")
  end
end
