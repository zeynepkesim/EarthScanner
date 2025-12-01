defmodule EarthScannerWeb.ChangePasswordControllerTest do
  use EarthScannerWeb.ConnCase

  alias EarthScanner.Accounts

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "username" => "pwd_user",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "John",
        "last_name" => "Doe",
        "email" => "pwd_user@example.com",
        "birthdate" => "1995-01-01",
        "nationality" => "ID",
        "residence_address" => "Street 1",
        "phone_number" => "+11111111111"
      })

    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, conn: conn, user: user}
  end

  test "GET /users/change-password renders form", %{conn: conn} do
    conn = get(conn, "/users/change-password")
    assert html_response(conn, 200) =~ "Change Password"
  end

  test "POST /users/change-password with valid password updates password", %{conn: conn} do
    conn =
      post(conn, "/users/change-password", %{
        "current_password" => "Password123!",
        "new_password" => "NewPassword456!",
        "new_password_confirmation" => "NewPassword456!"
      })

    assert redirected_to(conn) == "/profile"
    assert get_flash(conn, :info) =~ "Password updated successfully"
  end

  test "POST /users/change-password with wrong current password shows error", %{conn: conn} do
    conn =
      post(conn, "/users/change-password", %{
        "current_password" => "Wrong999!",
        "new_password" => "NewPassword456!",
        "new_password_confirmation" => "NewPassword456!"
      })

    assert html_response(conn, 200) =~ "Current password is incorrect"
  end

  test "POST /users/change-password with mismatched confirmation shows error", %{conn: conn} do
    conn =
      post(conn, "/users/change-password", %{
        "current_password" => "Password123!",
        "new_password" => "NewPassword456!",
        "new_password_confirmation" => "Different789!"
      })

    assert html_response(conn, 200) =~ "Password confirmation does not match"
  end

  test "POST /users/change-password with too short password shows error", %{conn: conn} do
    conn =
      post(conn, "/users/change-password", %{
        "current_password" => "Password123!",
        "new_password" => "short",
        "new_password_confirmation" => "short"
      })

    assert html_response(conn, 200) =~ "Password must be at least 8 characters"
  end
end
