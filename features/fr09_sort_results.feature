Feature: FR-09 Sort Results
  As a user
  I want to sort results by price, CO2, or duration
  So that I can view trips in my preferred order

  Context: TripSearchContext

  Scenario: Sort by price ascending
    Given a set of future trips with varying prices exist
    When I sort search results by "price_asc"
    Then results should appear in ascending price order

  Scenario: Sort by CO2 descending
    Given a set of future trips with varying CO2 exist
    When I sort search results by "co2_desc"
    Then results should appear in descending CO2 order

  Scenario: Sort by duration ascending
    Given a set of future trips with varying durations exist
    When I sort search results by "duration_asc"
    Then results should appear in ascending duration order
