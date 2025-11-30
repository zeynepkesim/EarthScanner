defmodule EarthScanner.AccessibilityTest do
  use EarthScanner.DataCase
  import Phoenix.ConnTest

  @endpoint EarthScannerWeb.Endpoint

  describe "NFR-03: Accessibility Attributes" do
    # NFR-03: Positive Scenario - ARIA labels exist
    test "sort select has proper ARIA labels" do
      conn = build_conn()
      conn = get(conn, "/search/results?source=Tallinn&destination=Tartu")

      html = html_response(conn, 200)

      # Check for sort select with ARIA labels
      assert html =~ ~r/id="sort-select"/
      assert html =~ ~r/aria-label="Sort trips by different criteria"/
      assert html =~ ~r/aria-describedby="sort-description"/
    end

    # NFR-03: Positive Scenario - Filter badges have ARIA labels
    test "filter removal links have ARIA labels" do
      conn = build_conn()
      conn = get(conn, "/search/results?source=Tallinn&destination=Tartu&max_price=100")

      html = html_response(conn, 200)

      # Check for ARIA labels on filter removal
      assert html =~ ~r/aria-label="Remove filter:/
      assert html =~ ~r/role="button"/
    end

    # NFR-03: Positive Scenario - Top picks have ARIA labels
    test "top picks have descriptive ARIA labels" do
      # Create test data
      admin = TripTestHelper.admin_fixture()
      future_date = Date.utc_today() |> Date.add(10) |> Date.to_iso8601()

      {:ok, _trip} =
        EarthScanner.Trips.create_trip(admin, %{
          "source_city" => "Tallinn",
          "destination_city" => "Tartu",
          "departure_time" => "2025-12-01T10:00:00Z",
          "arrival_time" => "2025-12-01T12:00:00Z",
          "price" => 50.0,
          "co2_level" => 100,
          "available_tickets" => 10,
          "transport_mode" => "bus",
          "dates" => future_date
        })

      conn = build_conn()
      conn = get(conn, "/search/results?source=Tallinn&destination=Tartu")

      html = html_response(conn, 200)

      # Check for ARIA labels on top picks
      assert html =~ ~r/aria-label=".*trip:.*Tallinn.*Tartu/
    end

    # NFR-03: Negative Scenario - Missing ARIA labels would fail
    test "page structure includes accessibility regions" do
      conn = build_conn()
      conn = get(conn, "/search/results?source=Tallinn&destination=Tartu&max_price=100")

      html = html_response(conn, 200)

      # Check for role="region" on important sections
      assert html =~ ~r/role="region"/
      assert html =~ ~r/aria-label="Active filters"/
    end

    # NFR-03: Edge Case - Screen reader text exists
    test "screen reader only text is present for descriptions" do
      conn = build_conn()
      conn = get(conn, "/search/results?source=Tallinn&destination=Tartu")

      html = html_response(conn, 200)

      # Check for sr-only class
      assert html =~ ~r/class="sr-only"/
      assert html =~ "Choose how to sort the trip results"
    end
  end
end
