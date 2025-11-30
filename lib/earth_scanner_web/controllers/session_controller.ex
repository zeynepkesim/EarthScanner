defmodule EarthScannerWeb.SessionController do
  use EarthScannerWeb, :controller
  alias EarthScanner.Accounts

  def new(conn, _params) do
    form = Phoenix.Component.to_form(%{}, as: :session)
    render(conn, :new, form: form)
  end

  def create(conn, %{"session" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        # rotate session id to prevent fixation
        |> configure_session(renew: true)
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome back")
        |> redirect(to: ~p"/")

      {:error, _} ->
        render(conn, :new,
          form: Phoenix.Component.to_form(%{"email" => email}, as: :session),
          error: "Invalid email or password"
        )
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(renew: true)
    |> delete_session(:user_id)
    |> put_flash(:info, "Signed out successfully")
    |> redirect(to: ~p"/users/login")
  end

  # no departure helper here; notifications are shown on the notifications page
end
