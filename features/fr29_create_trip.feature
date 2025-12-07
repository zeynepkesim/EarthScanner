Feature: FR-29 Create Trip

  Context: CreateTripContext

  Background:
    Given an admin user "admin@example.com" with password "Password123!" exists
    Given a regular user "user@example.com" with password "Password123!" exists

  @happy_path @positive
  Scenario: Successful creation of a basic trip
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
      | dates               | 2025-11-21                   |
    And I submit the trip form
    Then I should see a confirmation that the trip was created
    And I should see the trip listed in my future trips

  @positive
  Scenario: Create trip with bus transport mode
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid trip with:
      | transport_mode      | bus                          |
      | source_city         | Tartu                        |
      | destination_city    | Tallinn                      |
      | departure_time      | 2025-12-01T08:00:00Z         |
      | arrival_time        | 2025-12-01T10:30:00Z         |
      | price               | 25.0                         |
      | co2_level           | 50                           |
      | available_tickets   | 40                           |
      | dates               | 2025-12-05                   |
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @positive
  Scenario: Create trip with train transport mode
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid trip with:
      | transport_mode      | train                        |
      | source_city         | Berlin                       |
      | destination_city    | Munich                       |
      | departure_time      | 2025-12-10T14:00:00Z         |
      | arrival_time        | 2025-12-10T18:00:00Z         |
      | price               | 80.0                         |
      | co2_level           | 30                           |
      | available_tickets   | 100                          |
      | dates               | 2025-12-15                   |
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @positive
  Scenario: Create trip with minimum valid values
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid trip with:
      | transport_mode      | bus                          |
      | source_city         | A                            |
      | destination_city    | B                            |
      | departure_time      | 2025-12-20T10:00:00Z         |
      | arrival_time        | 2025-12-20T10:01:00Z         |
      | price               | 0.01                         |
      | co2_level           | 0                            |
      | available_tickets   | 1                            |
      | dates               | 2025-12-25                   |
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @negative
  Scenario: Attempt to create trip without logging in
    When I navigate to the admin trip creation page
    Then I should be redirected to the login page

  @negative
  Scenario: Attempt to create trip as regular user
    When I log in as "user@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    Then I should see an access denied message

  @negative
  Scenario: Create trip with invalid transport mode
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with invalid transport mode "car"
    And I submit the trip form
    Then I should see an error about invalid transport mode

  @negative
  Scenario: Create trip with negative price
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with negative price "-50.0"
    And I submit the trip form
    Then I should see an error about invalid price

  @negative
  Scenario: Create trip with zero available tickets
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with zero available tickets
    And I submit the trip form
    Then I should see an error about invalid available tickets

  @negative
  Scenario: Create trip with arrival before departure
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with arrival before departure
    And I submit the trip form
    Then I should see an error about invalid arrival time

  @negative
  Scenario: Create trip without picture URL
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip without picture URL
    And I submit the trip form
    Then I should see an error about missing picture URL

  @negative
  Scenario: Create trip without source city
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip without source city
    And I submit the trip form
    Then I should see an error about missing source city

  @negative
  Scenario: Create trip without destination city
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip without destination city
    And I submit the trip form
    Then I should see an error about missing destination city

  @edge_case
  Scenario: Create trip with very long duration
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid trip with:
      | transport_mode      | plane                        |
      | source_city         | New York                     |
      | destination_city    | Sydney                       |
      | departure_time      | 2025-12-01T10:00:00Z         |
      | arrival_time        | 2025-12-03T10:00:00Z         |
      | price               | 1500.0                       |
      | co2_level           | 500                          |
      | available_tickets   | 200                          |
      | dates               | 2025-12-10                   |
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @edge_case
  Scenario: Create trip with special characters in city names
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid trip with:
      | transport_mode      | plane                        |
      | source_city         | São Paulo                    |
      | destination_city    | Zürich                       |
      | departure_time      | 2025-12-05T09:00:00Z         |
      | arrival_time        | 2025-12-05T21:00:00Z         |
      | price               | 800.0                        |
      | co2_level           | 300                          |
      | available_tickets   | 150                          |
      | dates               | 2025-12-10                   |
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @edge_case
  Scenario: Create trip with large values
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid trip with:
      | transport_mode      | plane                        |
      | source_city         | London                       |
      | destination_city    | Tokyo                        |
      | departure_time      | 2025-12-15T06:00:00Z         |
      | arrival_time        | 2025-12-15T18:00:00Z         |
      | price               | 9999.99                      |
      | co2_level           | 99999                        |
      | available_tickets   | 5000                         |
      | dates               | 2025-12-20                   |
    And I submit the trip form
    Then I should see a confirmation that the trip was created
