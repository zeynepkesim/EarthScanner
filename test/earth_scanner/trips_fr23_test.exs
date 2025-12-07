defmodule EarthScanner.TripsFR23Test do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Repo
  alias EarthScanner.Accounts.User

  describe "get_trip_for_admin/2 enforces creator-only access (FR-23)" do
    test "returns {:ok, trip} for the creating admin and {:error, :unauthorized} for others" do
      # create first admin (creator)
      creator_attrs = %{
        username: "creator_admin",
        password: "password123",
        password_confirmation: "password123",
        email: "creator_admin@test.com",
        phone_number: "1231231234",
        role: "admin"
      }

      {:ok, creator} =
        %User{}
        |> User.admin_changeset(creator_attrs)
        |> Repo.insert()

      # create second admin (other)
      other_attrs = %{
        username: "other_admin",
        password: "password123",
        password_confirmation: "password123",
        email: "other_admin@test.com",
        phone_number: "4321432143",
        role: "admin"
      }

      {:ok, other_admin} =
        %User{}
        |> User.admin_changeset(other_attrs)
        |> Repo.insert()

      # create a trip by creator
      {:ok, trip} =
        Trips.create_trip(creator, %{
          "picture_url" => "https://via.placeholder.com/150",
          "transport_mode" => "bus",
          "source_city" => "CityA",
          "destination_city" => "CityB",
          "departure_time" => "2026-01-01T10:00:00Z",
          "arrival_time" => "2026-01-01T12:00:00Z",
          "price" => "25.00",
          "co2_level" => "50",
          "available_tickets" => "20",
          "dates" => "2026-01-01"
        })

      # creator should be authorized
      assert {:ok, returned} = Trips.get_trip_for_admin(trip.id, creator)
      assert returned.id == trip.id

      # other admin should be unauthorized
      assert {:error, :unauthorized} = Trips.get_trip_for_admin(trip.id, other_admin)
    end
  end
end
