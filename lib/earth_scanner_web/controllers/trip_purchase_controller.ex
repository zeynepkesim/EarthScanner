defmodule EarthScannerWeb.TripPurchaseController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  def create(conn, %{"trip_id" => trip_id} = params) do
    redirect_to = Map.get(params, "redirect_to", ~p"/trips/#{trip_id}")
    redeem_points = Map.get(params, "redeem_points") == "true"

    with %{} = user <- conn.assigns[:current_user],
         {:ok, instance_id} <- parse_instance_id(params["trip_instance_id"]),
         {:ok, _purchase} <- Trips.purchase_trip_instance(user, instance_id, redeem_points: redeem_points) do
      conn
      |> put_flash(:info, "Trip purchased! See you on board.")
      |> redirect(to: redirect_to)
    else
      nil ->
        conn
        |> put_flash(:error, "Please log in to purchase trips.")
        |> redirect(to: ~p"/users/login")

      {:error, :invalid_instance} ->
        conn
        |> put_flash(:error, "Invalid trip selection.")
        |> redirect(to: redirect_to)

      {:error, :past_instance} ->
        conn
        |> put_flash(:error, "This trip is no longer available.")
        |> redirect(to: redirect_to)

      {:error, :sold_out} ->
        conn
        |> put_flash(:error, "This trip is sold out.")
        |> redirect(to: redirect_to)

      {:error, :already_purchased} ->
        conn
        |> put_flash(:info, "You already purchased this trip.")
        |> redirect(to: redirect_to)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Trip instance was not found.")
        |> redirect(to: redirect_to)

      {:error, _other} ->
        conn
        |> put_flash(:error, "We couldn't process your purchase. Please try again.")
        |> redirect(to: redirect_to)
    end
  end

  def delete(conn, %{"trip_id" => trip_id} = params) do
    redirect_to = Map.get(params, "redirect_to", ~p"/trips/#{trip_id}")

    with %{} = user <- conn.assigns[:current_user],
         {:ok, instance_id} <- parse_instance_id(params["trip_instance_id"]),
         {:ok, _} <- Trips.return_trip_instance_purchase(user, instance_id) do
      conn
      |> put_flash(:info, "Purchase returned.")
      |> redirect(to: redirect_to)
    else
      nil ->
        conn
        |> put_flash(:error, "Please log in to manage purchases.")
        |> redirect(to: ~p"/users/login")

      {:error, :invalid_instance} ->
        conn
        |> put_flash(:error, "Invalid trip selection.")
        |> redirect(to: redirect_to)

      {:error, :past_instance} ->
        conn
        |> put_flash(:error, "This trip date has passed and cannot be refunded.")
        |> redirect(to: redirect_to)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Purchase not found.")
        |> redirect(to: redirect_to)

      {:error, _other} ->
        conn
        |> put_flash(:error, "We couldn't process your refund. Please try again.")
        |> redirect(to: redirect_to)
    end
  end

  defp parse_instance_id(value) when is_integer(value), do: {:ok, value}

  defp parse_instance_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, _} -> {:ok, id}
      :error -> {:error, :invalid_instance}
    end
  end

  defp parse_instance_id(_), do: {:error, :invalid_instance}
end
