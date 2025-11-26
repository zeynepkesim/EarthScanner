Feature: FR-16 View Trip Details
  As a user
  I want to view trip details

  Scenario: Positive - view existing trip
    Given a trip exists with source "Tartu" destination "Tallinn" transport "bus" duration_minutes 60 price "20.00"
    When I visit the trip page for the first trip
    Then I should see the trip details

  Scenario: Negative - visit non-existent trip
    When I visit the trip page for id 999999
    Then I should see a 404 page
