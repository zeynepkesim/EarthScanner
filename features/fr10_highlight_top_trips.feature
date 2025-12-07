Feature: FR-10 Highlight top trips
  As a user
  I want a special section showing the fastest, cheapest, and least-polluting trips
  So that I can quickly identify the best options

  Context: HighlightTopTripsContext

  Background:
    Given I am logged in as a regular user
    And the database is clean for this test

  # Positive Scenarios

  Scenario: Top picks section displays all three categories
    Given a set of future trips for top picks exists between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should see the "Top Picks" section
    And I should see a "Fastest" top pick
    And I should see a "Cheapest" top pick
    And I should see a "Greenest" top pick

  Scenario: Top picks also appear in main search results
    Given a set of future trips for top picks exists between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then the top picks also appear in the main search results list

  Scenario: Clicking on a top pick navigates to trip detail page
    Given a set of future trips for top picks exists between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    And I click on the "Fastest" top pick
    Then I should be navigated to the trip detail page

  # Negative Scenarios

  Scenario: No top picks section when no trips are available
    Given no future trips exist between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should not see the "Top Picks" section

  Scenario: No top picks section when only past trips exist
    Given only past trips exist between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should not see the "Top Picks" section

  # Edge Cases

  Scenario: Top picks update when filters are applied
    Given a set of future trips for top picks exists between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn" with max price "20"
    Then I should see the "Top Picks" section
    And all top picks should have price <= 20

  Scenario: Top picks respect search route parameters  
    Given a set of future trips exists between "Tartu" and "Tallinn"
    And a set of future trips exists between "Tartu" and "Pärnu"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should see the "Top Picks" section
    And all top picks should be for route from "Tartu" to "Tallinn"
