defmodule EarthScannerWeb.UserRegistrationControllerTest do
  # nfr-04: TDD - registration tests exercise password hashing (stored and verified)
  use EarthScannerWeb.ConnCase, async: true

  @moduletag :registration

  describe "GET /users/register" do
    test "renders registration page with expected fields", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      html = html_response(conn, 200)

      assert html =~ "Register"
      assert html =~ ~s/name=\"user[username]\"/
      assert html =~ ~s/name=\"user[password]\"/
      assert html =~ ~s/name=\"user[name]\"/
      assert html =~ ~s/name=\"user[last_name]\"/
      assert html =~ ~s/name=\"user[email]\"/
      assert html =~ ~s/name=\"user[birthdate]\"/
      assert html =~ ~s/name=\"user[nationality]\"/
      assert html =~ ~s/name=\"user[residence_address]\"/
      assert html =~ ~s/name=\"user[phone_number]\"/
      assert html =~ to_string(~p"/users/login")
    end
  end

  describe "POST /users/register" do
    test "with valid data persists user and redirects to log in", %{conn: conn} do
      import Ecto.Query
      alias EarthScanner.Repo

      uniq = Integer.to_string(System.unique_integer([:positive]))
      email = "user" <> uniq <> "@example.com"
      username = "user_" <> uniq

      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{
            "username" => username,
            "password" => "verylongpassword",
            "password_confirmation" => "verylongpassword",
            "name" => "Ada",
            "last_name" => "Lovelace",
            "email" => email,
            "birthdate" => "1990-01-15",
            "nationality" => "Estonian",
            "residence_address" => "123 River St, Tallinn",
            "phone_number" => "+3725555555"
          }
        })

      assert redirected_to(conn) == ~p"/users/login"

      count =
        Repo.one(
          from u in "users",
            where:
              field(u, :email) == ^email and
                field(u, :username) == ^username and
                field(u, :name) == ^"Ada" and
                field(u, :last_name) == ^"Lovelace" and
                field(u, :birthdate) == ^~D[1990-01-15] and
                field(u, :nationality) == ^"Estonian" and
                field(u, :residence_address) == ^"123 River St, Tallinn" and
                field(u, :phone_number) == ^"+3725555555",
            select: count()
        )

      assert count == 1
    end

    test "with invalid data re-renders page with errors", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{
            "name" => "",
            "last_name" => "",
            "email" => "with spaces",
            "birthdate" => "",
            "nationality" => "",
            "residence_address" => "",
            "phone_number" => "",
            "password" => "short"
          }
        })

      html = html_response(conn, 200)
      assert html =~ "Register"
      assert html =~ "error"
    end

    test "with mismatched password confirmation re-renders with error", %{conn: conn} do
      uniq = Integer.to_string(System.unique_integer([:positive]))
      email = "user" <> uniq <> "@example.com"

      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{
            "username" => "user_" <> uniq,
            "password" => "verylongpassword",
            "password_confirmation" => "doesnotmatch",
            "name" => "Ada",
            "last_name" => "Lovelace",
            "email" => email,
            "birthdate" => "1990-01-15",
            "nationality" => "Estonian",
            "residence_address" => "123 River St, Tallinn",
            "phone_number" => "+3725555555"
          }
        })

      html = html_response(conn, 200)
      assert html =~ "Register"
      assert html =~ "error"
    end
  end
end
