#FR-29 - Create Trip ,FR-36 - Recurring Trip Dates 
Feature: Admin creates a trip with recurring dates

  Background:
    Given an admin user "admin@example.com" with password "Password123!" exists

  @happy_path
  Scenario: Successful creation of a trip with two dates
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid trip with:
      | transport_mode      | plane                        |
      | source_city         | Tallinn                      |
      | destination_city    | Paris                        |
      | departure_time      | 2025-11-20T10:00:00Z         |
      | arrival_time        | 2025-11-20T13:00:00Z         |
      | price               | 150.0                        |
      | co2_level           | 200                          |
      | available_tickets   | 50                           |
      | dates               | 2025-11-21, 2025-11-28       |
    And I submit the trip form
    Then I should see a confirmation that the trip was created
    And I should see the trip listed in my future trips
    And I should see 2 dates for that trip

  @missing_dates
  Scenario: Failing to create a trip without dates
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid trip with:
      | transport_mode      | plane                        |
      | source_city         | Tallinn                      |
      | destination_city    | Paris                        |
      | departure_time      | 2025-11-20T10:00:00Z         |
      | arrival_time        | 2025-11-20T13:00:00Z         |
      | price               | 150.0                        |
      | co2_level           | 200                          |
      | available_tickets   | 50                           |
      | dates               |                              |
    And I clear the trip dates
    And I submit the trip form
    Then I should see an error about missing trip dates
