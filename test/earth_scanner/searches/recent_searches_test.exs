# FR-18: View Last Five Searches
defmodule EarthScanner.Searches.RecentSearchesTest do
  use EarthScanner.DataCase, async: true
  alias EarthScanner.Searches
  alias EarthScanner.Accounts

  describe "recent searches" do
    # FR-18: System stores and maintains only the last 5 searches per user
    test "records and retrieves up to 5 recent searches per user" do
      {:ok, user} =
        Accounts.register_user(%{
          "username" => "search_user_#{System.unique_integer([:positive])}",
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "name" => "Recent",
          "last_name" => "Searches",
          "email" => "recent_#{System.unique_integer([:positive])}@example.com",
          "birthdate" => "1990-01-01",
          "nationality" => "TR",
          "residence_address" => "Test St",
          "phone_number" => "+905551111111"
        })

      # Insert 6 searches, only last 5 should remain
      for i <- 1..6 do
        Searches.record_search(user, "City#{i}", "Dest#{i}")
      end

      recent = Searches.get_recent_searches(user)
      assert length(recent) == 5
      # Implementation returns most-recent-first; expect City6..City2
      assert Enum.map(recent, & &1.source_city) == ["City6", "City5", "City4", "City3", "City2"]
    end

    # FR-18: Each user has their own isolated search history
    test "searches are isolated per user" do
      {:ok, user1} =
        Accounts.register_user(%{
          "username" => "user1_#{System.unique_integer([:positive])}",
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "name" => "A",
          "last_name" => "B",
          "email" => "user1_#{System.unique_integer([:positive])}@example.com",
          "birthdate" => "1990-01-01",
          "nationality" => "TR",
          "residence_address" => "A",
          "phone_number" => "+905551111111"
        })

      {:ok, user2} =
        Accounts.register_user(%{
          "username" => "user2_#{System.unique_integer([:positive])}",
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "name" => "C",
          "last_name" => "D",
          "email" => "user2_#{System.unique_integer([:positive])}@example.com",
          "birthdate" => "1990-01-01",
          "nationality" => "TR",
          "residence_address" => "B",
          "phone_number" => "+905551111112"
        })

      Searches.record_search(user1, "A", "B")
      Searches.record_search(user2, "X", "Y")

      assert [%{source_city: "A", destination_city: "B"}] = Searches.get_recent_searches(user1)
      assert [%{source_city: "X", destination_city: "Y"}] = Searches.get_recent_searches(user2)
    end
  end
end
