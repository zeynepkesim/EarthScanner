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

  def confirm_delete(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "Please log in to continue")
        |> redirect(to: ~p"/users/login")

      user ->
        form = Phoenix.Component.to_form(%{}, as: :delete)
        render(conn, :confirm_delete, user: user, form: form)
    end
  end

  def delete(conn, %{"delete" => %{"password" => password, "confirm" => confirm}}) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "Please log in to continue")
        |> redirect(to: ~p"/users/login")

      user ->
        cond do
          confirm != "yes" ->
            conn
            |> put_flash(:error, "Please confirm account deletion.")
            |> redirect(to: ~p"/users/delete")

          true ->
            case EarthScanner.Accounts.delete_user(user, password) do
              {:ok, :deleted} ->
                # drop the entire session to ensure the user is logged out immediately
                conn
                |> configure_session(drop: true)
                |> put_flash(:info, "Your account has been deleted.")
                |> redirect(to: ~p"/")

              {:error, :invalid_password} ->
                conn
                |> put_flash(:error, "Invalid password.")
                |> redirect(to: ~p"/users/delete")

              {:error, _other} ->
                conn
                |> put_flash(:error, "Could not delete the account. Please try again.")
                |> redirect(to: ~p"/users/delete")
            end
        end
    end
  end
end
