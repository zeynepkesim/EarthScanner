defmodule EarthScannerWeb.RequireAdmin do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = conn.assigns[:current_user]

    cond do
      is_nil(current_user) ->
        conn
        |> redirect(to: "/users/login")
        |> halt()

      current_user.role != "admin" ->
        conn
        |> put_flash(:error, "You are not authorized to access this page.")
        |> redirect(to: "/")
        |> halt()

      true ->
        conn
    end
  end
end
