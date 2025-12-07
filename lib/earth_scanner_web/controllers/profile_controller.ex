defmodule EarthScannerWeb.ProfileController do
  use EarthScannerWeb, :controller
  alias EarthScanner.Accounts

  def show(conn, params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "Please log in to view your profile")
        |> redirect(to: ~p"/users/login")

      user ->
        requested_id = params["user_id"]

        # ❗ Only allow current user's own profile — block any other user_id
        if requested_id && requested_id != "" && requested_id != Integer.to_string(user.id) do
          conn
          |> put_flash(:error, "Unauthorized access.")
          |> redirect(to: ~p"/profile")
        else
          render(conn, :show, user: user)
        end
    end
  end

  # --- Teammate's profile edit/update ---
  def edit(conn, _params) do
    user = conn.assigns.current_user
    changeset = Accounts.User.profile_changeset(user, %{})
    render(conn, :edit, form: Phoenix.Component.to_form(changeset), user: user)
  end

  def update(conn, %{"user" => user_params}) do
    user = conn.assigns[:current_user]

    case Accounts.update_user(user, user_params) do
      {:ok, _updated_user} ->
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

  # --- Your change-password feature ---
  def edit_password(conn, _params) do
    render(conn, :edit_password, changeset: %{})
  end

  def update_password(conn, %{
        "current_password" => current,
        "new_password" => new_pass,
        "new_password_confirmation" => confirm
      }) do
    user = conn.assigns.current_user

    case EarthScanner.Accounts.change_password(user, current, new_pass, confirm) do
      {:ok, _updated_user} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Password updated successfully")
        |> redirect(to: ~p"/profile")

      {:error, :invalid_current_password} ->
        render(conn, :edit_password, changeset: %{error: "Current password is incorrect"})

      {:error, :password_confirmation_mismatch} ->
        render(conn, :edit_password, changeset: %{error: "Password confirmation does not match"})

      {:error, :password_too_short} ->
        render(conn, :edit_password,
          changeset: %{error: "Password must be at least 8 characters"}
        )

      {:error, reason} ->
        render(conn, :edit_password,
          changeset: %{error: "Could not change password: #{inspect(reason)}"}
        )
    end
  end
end
