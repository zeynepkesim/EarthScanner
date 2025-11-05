defmodule EarthScannerWeb.ProfileController do
  use EarthScannerWeb, :controller

  def show(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "Please log in to view your profile")
        |> redirect(to: ~p"/users/login")

      user ->
        render(conn, :show, user: user)
    end
  end
end
