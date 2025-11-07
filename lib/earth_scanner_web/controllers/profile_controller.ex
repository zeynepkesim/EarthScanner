defmodule EarthScannerWeb.ProfileController do
  use EarthScannerWeb, :controller
  alias EarthScanner.Accounts

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

  def edit(conn, _params) do
    user = conn.assigns.current_user
    changeset = Accounts.User.profile_changeset(user, %{})
    render(conn, :edit, form: Phoenix.Component.to_form(changeset), user: user)
  end

  def update(conn, %{"user" => user_params}) do
    user = conn.assigns[:current_user]

    case Accounts.update_user(user, user_params) do
      {:ok, updated_user} ->
        conn
        |> put_flash(:info, "Profile updated successfully")
        |> redirect(to: ~p"/profile")

      {:error, changeset} ->
        render(conn, :edit, form: Phoenix.Component.to_form(changeset), user: user)
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
                conn
                |> configure_session(renew: true)
                |> delete_session(:user_id)
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
