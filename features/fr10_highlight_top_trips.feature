Feature: FR-10 Highlight top trips
  As a user
  I want a special section showing the fastest, cheapest, and least-polluting trips
  So that I can quickly identify the best options

  Context: TripSearchContext

  Scenario: Top picks section shows fastest, cheapest and greenest trips
    Given a set of future trips for top picks exists between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should see the "Top Picks" section
    And I should see a "Fastest" top pick
    And I should see a "Cheapest" top pick
    And I should see a "Greenest" top pick
    And the top picks also appear in the main search results list
    And clicking on a top pick navigates to the trip detail page
